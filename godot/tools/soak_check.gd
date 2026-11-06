extends "res://tools/shot_driver.gd"

## Three days and nights of a camp with every kind of guest, the clock fast (the polish
## pass of 4. 11.): every system at once, as a long session plays, the warden kept alive.
## An hourly line "SOAK day d hh:00 money, guests, things out, fps", a picture at noon,
## dusk and midnight; then grep the log for SCRIPT ERROR. Lines "SOAK ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/soak_check.tscn -- --out=DIR [--days=3] [--speed=12]

const C := "get_tree().root.get_node('SoakCheck')"
const KINDS := ["quiet_guy", "drunk", "cheap_chick", "tramp", "family", "picker"]

var _days := 3
var _speed := 12.0
var _last_hour := -1
var _start_day := 1
var _frames := 0
var _since := 0
var _worst := 0.0
var _last_us := 0
var _running := false


var _real_from := 0
var _real_frames := 0
var _real_worst := 0.0


func pl() -> Node3D:
	return _main.get("_player")


func camp() -> void:
	_main.call("_build_test_camp", "")
	var gm = get_node_or_null("/root/GuestManager")
	var n := 0
	for k in KINDS:
		for i in 2:
			n += 1
			gm.call("debug_check_in_party", "%s %d" % [k, i], k, 1 + (i % 2), _days + 1)
	print("SOAK camp built, %d parties in" % n)


func go() -> void:
	_start_day = int(_main.get("_day_index"))
	_running = true
	_since = Time.get_ticks_usec()
	_last_us = _since
	Engine.time_scale = _speed


func _process(delta: float) -> void:
	super._process(delta)
	if not _running or _main == null:
		return
	var now := Time.get_ticks_usec()
	_worst = maxf(_worst, float(now - _last_us))
	if _real_from > 0:
		_real_frames += 1
		_real_worst = maxf(_real_worst, float(now - _last_us))
		if now - _real_from > 3000000:
			print("SOAK cost day %d: at the real speed %.0f fps, worst %.0f ms" % [int(_main.get("_day_index")), float(_real_frames) / (float(now - _real_from) / 1000000.0), _real_worst / 1000.0])
			_real_from = 0
			Engine.time_scale = _speed
	_last_us = now
	_frames += 1
	var p := pl()
	if p != null and _main.has_method("_set_player_health") and int(_main.get("_player_health")) < 60:
		_main.call("_set_player_health", 100, false)
	var ts = _main.get("time_system")
	var h := int(float(ts.get("time_of_day_hours")))
	var day := int(_main.get("_day_index"))
	if h == _last_hour:
		return
	_last_hour = h
	var secs := float(now - _since) / 1000000.0
	var brains: Array = _main.get("_enemy_brains")
	var ids := []
	for b in brains:
		if b != null and b.has_method("get_enemy_id"):
			ids.append(str(b.get_enemy_id()))
	var gm = get_node_or_null("/root/GuestManager")
	var beds: Dictionary = gm.call("get_bed_metrics") if gm != null and gm.has_method("get_bed_metrics") else {}
	print("SOAK day %d %02d:00 money %s, in camp %s, things %s, fps %.0f, worst frame %.0f ms" % [day, h, str(CoreRoot.state.money),
		str(beds.get("in_camp", beds.get("occupied", "?"))), str(ids), float(_frames) / maxf(secs, 0.01), _worst / 1000.0])
	_frames = 0
	_worst = 0.0
	_since = now
	if h in [12, 19, 0]:
		_shot_now("soak_d%d_%02d" % [day, h])
	if h == 12:
		_costs(day)
		# Three seconds of it at the real speed: a fast clock runs every fixed step twelve
		# times a frame, the fps above say little about a player's.
		_real_from = Time.get_ticks_usec()
		_real_frames = 0
		_real_worst = 0.0
		Engine.time_scale = 1.0
	if day >= _start_day + _days and h >= 7:
		_running = false
		Engine.time_scale = 1.0
		print("SOAK: done")
		get_tree().quit()


## What has grown: at noon every day the engine's counts and each node's own frame, biggest
## first ("SOAK cost ...", the fps falling day by day means something piles up).
func _costs(day: int) -> void:
	print("SOAK cost day %d: objects %d, nodes %d, draws %d, primitives %d, bodies %d, video %.0f MB" % [day, int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	var vps: Array = [get_tree().root]
	vps.append_array(get_tree().root.find_children("*", "SubViewport", true, false))
	for v in vps:
		var vp := v as Viewport
		var rid := vp.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		var mode := int(vp.get("render_target_update_mode")) if vp is SubViewport else -1
		var draws := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var shadow := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var prim := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		if mode != 0 and draws + shadow > 0:
			print("SOAK cost day %d: view %s mode %d draws %d shadows %d primitives %d cpu %.1f gpu %.1f" % [day, str(vp.get_path()).right(46), mode, draws, shadow, prim,
				RenderingServer.viewport_get_measured_render_time_cpu(rid), RenderingServer.viewport_get_measured_render_time_gpu(rid)])
	var rows: Array = []
	var total := 0
	for n in get_tree().root.find_children("*", "Node", true, false):
		var node := n as Node
		if node == self or node.get_script() == null:
			continue
		var us := 0
		if node.is_processing() and node.has_method("_process"):
			var t0 := Time.get_ticks_usec()
			node.call("_process", 0.02)
			us += Time.get_ticks_usec() - t0
		if node.is_physics_processing() and node.has_method("_physics_process"):
			var t1 := Time.get_ticks_usec()
			node.call("_physics_process", 0.0166)
			us += Time.get_ticks_usec() - t1
		if us > 0:
			rows.append([us, str(node.name), (node.get_script() as Script).resource_path.get_file()])
			total += us
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("SOAK cost day %d: game code %.1f ms in %d nodes" % [day, float(total) / 1000.0, rows.size()])
	for i in mini(rows.size(), 8):
		print("SOAK cost day %d: %.2f ms %s (%s)" % [day, float(rows[i][0]) / 1000.0, rows[i][1], rows[i][2]])


func _shot_now(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out_dir.path_join(name + ".png"))


func _ready() -> void:
	super._ready()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			_days = int(a.substr(7))
		elif a.begins_with("--speed="):
			_speed = float(a.substr(8))
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", C + ".camp()"], ["prep_all"], ["wait", 2.0],
		["player", 10, 9, 180.0],
		["eval", C + ".go()"],
		# Held here till the days are done (_process quits).
		["wait", 1000000.0],
	]
