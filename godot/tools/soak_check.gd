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
	if day >= _start_day + _days and h >= 7:
		_running = false
		Engine.time_scale = 1.0
		print("SOAK: done")
		get_tree().quit()


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
