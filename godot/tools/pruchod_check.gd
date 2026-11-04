extends "res://tools/shot_driver.gd"

## A first day and night played as a new warden would (the polish pass of 4. 11.): the
## title, a new camp at the desk, Vera's mail and Builder, a tent and the toilets, up from
## the desk and out into the camp, a walk, the first guests, the evening, the PC's lock,
## the quiet first night, the second night with a thing out, the morning. A picture at
## every turn and the worst frame of each stretch ("PRUCHOD frames <tag> worst N ms,
## >50 ms: n, >100 ms: n, fps a"). Lines "PRUCHOD ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/pruchod_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('PruchodCheck')"

var _worst := 0.0
var _over50 := 0
var _over100 := 0
var _frames := 0
var _since := 0
var _last_us := 0
var _watch := false
var _tag := ""


func pl() -> Node3D:
	return _main.get("_player")


## The worst frame of a stretch of play (no jolt as anything comes the first time).
func watch(on: bool, tag := "") -> void:
	if on:
		_watch = true
		_tag = tag
		_worst = 0.0
		_over50 = 0
		_over100 = 0
		_frames = 0
		_since = Time.get_ticks_usec()
		_last_us = _since
		return
	_watch = false
	var secs := float(Time.get_ticks_usec() - _since) / 1000000.0
	print("PRUCHOD frames %s worst %.0f ms, >50 ms: %d, >100 ms: %d, fps %.0f over %.1f s" % [
		_tag, _worst / 1000.0, _over50, _over100, float(_frames) / maxf(secs, 0.001), secs])


func _frame() -> void:
	var now := Time.get_ticks_usec()
	if _watch and _last_us > 0:
		var d := float(now - _last_us)
		_worst = maxf(_worst, d)
		_frames += 1
		if d > 50000.0:
			_over50 += 1
		if d > 100000.0:
			_over100 += 1
	_last_us = now


## Where the warden is and what is open (one line).
func probe(tag: String) -> void:
	var p := pl()
	var im = _main.get("_interior_manager")
	var bi = im.get("_building_interior") if im != null else null
	var open := false
	if bi != null and bi.has_method("is_open"):
		open = bool(bi.call("is_open"))
	var hour := float(_main.get("time_system").get("time_of_day_hours")) if _main.get("time_system") != null else -1.0
	print("PRUCHOD %s: day %s %02d:%02d at %s, reception open %s, money %s, mouse %s" % [tag, str(_main.get("_day_index")),
		int(hour), int(fposmod(hour, 1.0) * 60.0), str(p.global_position.snapped(Vector3.ONE * 0.1)) if p != null else "-",
		str(open), str(CoreRoot.state.money) if CoreRoot.state != null else "-", ["free", "hidden (the PC draws its own)", "captured", "confined"][int(Input.mouse_mode) % 4]])


## Turn the warden to face a point on the grid (x, y tiles).
func face_tile(x: int, y: int) -> void:
	var gm = _main.get("grid_manager")
	var p := pl()
	if gm == null or p == null:
		return
	var to: Vector3 = gm.call("grid_to_world", Vector2i(x, y)) - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)


func _ready() -> void:
	super._ready()
	get_tree().process_frame.connect(_frame)
	_steps = [
		["wait", 0.4], ["shot", "a0_loading"],
		["eval", C + ".watch(true, 'boot to the title')"],
		["wait_menu"], ["eval", C + ".watch(false)"], ["wait", 2.5], ["shot", "a1_menu"],
		# A new camp: at the desk with the PC.
		["eval", C + ".watch(true, 'new camp')"],
		["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"],
		["wait", 0.3], ["shot", "b0_start_03"], ["wait", 1.2], ["shot", "b1_start_15"],
		["wait", 3.0], ["shot", "b2_start_45"], ["wait", 6.0], ["shot", "b3_start_105"],
		["eval", C + ".watch(false)"], ["eval", C + ".probe('at the desk')"],
		["eval", "_quest_manager.current_step_id()"],
		["mail_read", "task_id", "read_vera"], ["wait", 1.5], ["shot", "c0_vera_read"],
		["eval", "_quest_manager.current_step_id()"],
		["eval", C + ".watch(true, 'builder')"],
		["signal", "program_installed", "builder"], ["wait", 2.5], ["shot", "c1_builder"],
		["money", 5000], ["clear", 16, 3, 4, 4], ["build", "tent_1", 17, 4, 0], ["wait", 1.5], ["shot", "c2_tent_built"],
		["build", "toilet_block", 19, 4, 0], ["wait", 1.5], ["shot", "c3_toilets"],
		["eval", C + ".watch(false)"],
		["eval", "_quest_manager.current_step_id()"],
		["mail_accept", "task_id", "accept_booking"], ["wait", 1.0], ["shot", "c4_booking"],
		["eval", "_quest_manager.current_step_id()"],
		# Up from the desk, the room, then out.
		["eval", C + ".watch(true, 'up from the desk')"],
		["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.5], ["shot", "d0_stood_up"],
		["eval", C + ".watch(false)"],
		["eval", C + ".watch(true, 'out into the camp')"],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0], ["shot", "e0_outside"],
		["eval", C + ".probe('outside')"],
		["keyhold", "W", true], ["wait", 3.0], ["keyhold", "W", false], ["wait", 0.3], ["shot", "e1_walked"],
		["eval", "_player.rotate_y(PI * 0.5)"], ["wait", 0.8], ["shot", "e2_left"],
		["eval", "_player.rotate_y(PI)"], ["wait", 0.8], ["shot", "e3_right"],
		["eval", C + ".watch(false)"],
		# The tent made up, the first guests by the bus.
		["prep_all"], ["eval", C + ".probe('made up')"],
		["eval", C + ".watch(true, 'guests come')"],
		["timescale", 3.0], ["wait", 12.0], ["shot", "f0_later"], ["eval", C + ".probe('later')"],
		["wait", 12.0], ["shot", "f1_later2"],
		["timescale", 1.0],
		["eval", C + ".watch(false)"],
		# The evening and the PC's lock.
		["eval", "debug_jump_to(1, 19.4)"], ["wait", 2.0], ["eval", C + ".watch(true, 'evening')"],
		["wait", 3.0], ["shot", "g0_evening"], ["eval", C + ".probe('evening')"],
		["eval", "debug_jump_to(1, 19.95)"], ["wait", 6.0], ["shot", "g1_lock"],
		["eval", C + ".watch(false)"],
		["eval", C + ".watch(true, 'first night')"],
		["eval", "debug_jump_to(1, 21.5)"], ["wait", 3.0], ["shot", "h0_night1"],
		["eval", "_player.rotate_y(PI)"], ["wait", 1.5], ["shot", "h1_night1_back"],
		["eval", C + ".watch(false)"],
		# The second night with a thing out.
		["eval", "debug_jump_to(2, 20.2)"], ["wait", 3.0],
		["eval", C + ".watch(true, 'second night')"],
		["eval", "debug_spawn_enemy('silent_man', 3)"], ["wait", 6.0], ["look_at_enemy"], ["wait", 0.5], ["shot", "i0_thing"],
		["enemy_dist"], ["wait", 8.0], ["look_at_enemy"], ["wait", 0.3], ["shot", "i1_thing_later"], ["enemy_dist"],
		["eval", C + ".watch(false)"],
		# The morning.
		["eval", "_stop_active_enemy_brain()"],
		["eval", "debug_jump_to(3, 6.6)"], ["wait", 3.0], ["eval", C + ".watch(true, 'morning')"],
		["wait", 3.0], ["shot", "j0_morning"], ["eval", C + ".probe('morning')"],
		["eval", C + ".watch(false)"],
		["eval", "get_tree().quit()"],
	]
