extends "res://tools/shot_driver.gd"

## The god cursor (scripts/god/god_cursor.gd) seen from the camp: a line of path tiles
## coming down one after another, a cabin and a pub in their parts, a bulldozed wood
## pressed flat; runs of shots a twelfth of a second apart from a warden's eye height,
## by day, in the fog and at dusk; one from the office window.
##   godot --path godot --resolution 1280x720 res://tools/god_shots.tscn -- --out=<dir> [--part=day|fog|dusk|window]

const GOD := "_god_cursor"

var _part := "day"


func _burst(name: String, n: int, dt: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(["shot", "%s_%02d" % [name, i]])
		out.append(["wait", dt])
	return out


func _ready() -> void:
	super._ready()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			_part = a.substr(7)
	var hour: float = {"day": 11.0, "fog": 8.0, "dusk": 18.6, "window": 11.0}.get(_part, 11.0)
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, %.2f)" % hour], ["money", 90000],
		["clear", 4, 3, 14, 15], ["wait", 1.2],
	]
	if _part == "fog":
		s.append_array([["eval", "weather_system.set_weather(2)"], ["wait", 45.0]])
	s.append_array([
		["eval", GOD + ".set('debug_force', true)"],
		["god_eye", 11, 17, 11, 7, 14.0], ["wait", 1.0],
	])
	if _part == "window":
		s.append_array([["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 6.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.5]])
	# A path line, a cabin, a pub; then a wood bulldozed.
	for x in range(7, 15):
		s.append(["build", "path", x, 5, 0])
	s.append_array([["build", "cabin_1", 8, 7, 0], ["build", "pub", 12, 7, 1], ["wait", 0.05]])
	s.append_array(_burst("a_path", 40, 1.0 / 12.0))
	s.append_array(_burst("b_cabin", 48, 1.0 / 12.0))
	s.append_array(_burst("c_pub", 48, 1.0 / 12.0))
	s.append_array([["wait", 2.0], ["shot", "d_after"], ["clear", 19, 6, 4, 4], ["wait", 0.05]])
	s.append_array(_burst("e_wreck", 36, 1.0 / 12.0))
	s.append_array([["wait", 4.0], ["shot", "f_idle"], ["eval", "[" + GOD + ".busy(), " + GOD + "._vis]"]])
	_steps = s


func _run_step(step: Array) -> void:
	if str(step[0]) == "god_eye":
		# A warden's eye on the ground at grid ([1], [2]) looking at grid ([3], [4]),
		# [5] metres up.
		if _part == "window":
			return
		var gm = _main.get("grid_manager")
		var world3d: Node3D = _main.get("_world_3d")
		var cam := Camera3D.new()
		world3d.add_child(cam)
		cam.fov = 56.0
		cam.far = 900.0
		var from: Vector3 = gm.grid_to_world(Vector2i(int(step[1]), int(step[2]))) + Vector3(0, 1.7, 0)
		var at: Vector3 = gm.grid_to_world(Vector2i(int(step[3]), int(step[4]))) + Vector3(0, float(step[5]), 0)
		cam.global_position = from
		cam.look_at(at, Vector3.UP)
		var old = _main.get("debug_camera")
		if old != null and is_instance_valid(old):
			old.queue_free()
		_main.set("debug_camera", cam)
		return
	super._run_step(step)
