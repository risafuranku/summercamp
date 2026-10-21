extends "res://tools/shot_driver.gd"

## The rowing boat end to end (scripts/lake/lake_trip.gd, boat_rig.gd): the boat tied up,
## getting in, a run of shots through the strokes, looking round from the seat (an oar in
## the water, the swirls it leaves, down into the boat), turning on the spot, backing water,
## knocked off the shore, a storm, coming alongside the keeper's jetty by itself, the far
## shore, rowing back and climbing out, and the lantern after dark.
##   godot --path godot --resolution 1280x720 res://tools/boat_shots.tscn -- --out=<dir> [--lang=cs]

const LT := "_lake_trip"
const LAKE := "_lake_trip._lake_node()"


## A run of shots `dt` apart named <name>_0.. (motion read off a contact sheet).
func _burst(name: String, n: int, dt: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(["shot", "%s_%d" % [name, i]])
		out.append(["wait", dt])
	return out


func _ready() -> void:
	super._ready()
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, 10.5)"], ["wait", 3.0],
		# On the jetty by the boat: the oars laid in, the hull riding the swell.
		["eval", "_player.set('global_position', " + LAKE + ".boat_home.origin + Vector3(-1.4, 0.9, -4.0))"],
		["eval", "_player.set('rotation', Vector3(0.0, PI, 0.0))"],
		["wait", 1.5], ["shot", "a0_moored"],
		["eval", "_player.set('global_position', " + LAKE + ".boat_home.origin + Vector3(-1.6, 0.6, 0.6))"],
		["eval", LT + ".hint()"], ["eval", LT + ".try_interact()"],
	]
	s.append_array(_burst("b_getin", 6, 0.15))
	s.append_array([["wait", 0.6], ["shot", "b_seated"], ["eval", LT + ".active_hint()"], ["keyhold", "W", true]])
	s.append_array(_burst("c_stroke", 16, 0.075))
	s.append_array([["wait", 2.0], ["shot", "d_out"],
		["eval", LT + ".set('_head_yaw', 1.3)"], ["wait", 0.5], ["shot", "e_look_left"],
		["eval", LT + ".set('_head_yaw', -1.6)"], ["wait", 0.5], ["shot", "e_look_right"],
		["eval", LT + ".set('_head_yaw', 0.0)"], ["eval", LT + ".set('_head_pitch', -0.7)"], ["wait", 0.5], ["shot", "e_look_down"],
		["eval", LT + ".set('_head_pitch', -0.16)"], ["wait", 0.4], ["keyhold", "W", false], ["wait", 2.0], ["shot", "g_glide"],
		["keyhold", "A", true]])
	s.append_array(_burst("h_turn", 4, 0.4))
	s.append_array([["keyhold", "A", false], ["eval", "[" + LT + "._yaw, " + LT + "._yaw_rate, " + LT + "._speed]"],
		["keyhold", "S", true], ["wait", 2.5], ["shot", "i_back"], ["keyhold", "S", false], ["eval", "[" + LT + "._speed]"],
		# Into the camp's shore: knocked back.
		["eval", LAKE + ".boat.set('global_position', " + LAKE + ".boat_home.origin + Vector3(8.0, 0.0, 0.8))"],
		["eval", LT + ".set('_yaw', PI)"], ["eval", LT + ".set('_speed', 2.2)"], ["wait", 2.5], ["shot", "j_after_bump"],
		["eval", "[" + LAKE + ".boat.global_position, " + LT + "._speed]"],
		# The storm on the water.
		["eval", LAKE + ".boat.set('global_position', " + LAKE + ".boat_home.origin + Vector3(0.0, 0.0, 14.0))"],
		["eval", "weather_system.set_weather(5)"], ["wait", 10.0], ["keyhold", "W", true], ["wait", 1.5], ["shot", "k_storm"], ["keyhold", "W", false],
		["eval", "weather_system.set_weather(0)"], ["wait", 6.0],
		# Up to the keeper's jetty: a little off it, rowing in; alongside by itself.
		["eval", LAKE + ".boat.set('global_position', " + LAKE + ".far_jetty_end + Vector3(1.0, -0.48, -9.0))"],
		["eval", LT + ".set('_yaw', 0.0)"], ["keyhold", "W", true], ["wait", 2.5], ["keyhold", "W", false]])
	s.append_array(_burst("l_dock", 8, 0.4))
	s.append_array([["wait", 2.0], ["shot", "m_far"], ["eval", "[" + LT + "._state]"],
		["eval", LT + "._look.set('yaw_deg', 160.0)"], ["wait", 0.8], ["shot", "n_far_boat"],
		["eval", LT + "._look.set('yaw_deg', 0.0)"], ["wait", 0.5],
		# Back: down into the boat, off the keeper's jetty, home and out.
		["eval", LT + "._start_rowing('camp')"]])
	s.append_array(_burst("o_off", 6, 0.15))
	s.append_array([["wait", 1.0],
		["eval", LAKE + ".boat.set('global_position', " + LAKE + ".boat_home.origin + Vector3(0.0, 0.0, 7.5))"],
		["eval", LT + ".set('_yaw', PI)"], ["eval", LT + ".set('_left_home', true)"],
		["keyhold", "W", true], ["wait", 2.0], ["keyhold", "W", false]])
	s.append_array(_burst("p_home", 10, 0.35))
	s.append_array([["wait", 2.0], ["shot", "q_after"],
		["eval", "[" + LT + ".is_active(), _player.global_position, " + LAKE + ".boat.global_position]"],
		# After dark: the lantern on the stem.
		["eval", "debug_jump_to(1, 21.0)"], ["wait", 3.0],
		["eval", "_player.set('global_position', " + LAKE + ".boat_home.origin + Vector3(-1.6, 0.6, 0.6))"],
		["eval", LT + ".try_interact()"], ["wait", 1.5], ["keyhold", "W", true], ["wait", 4.0], ["keyhold", "W", false], ["shot", "r_night"],
		["eval", LT + ".set('_head_pitch', -0.55)"], ["wait", 0.5], ["shot", "r_night_down"],
		["eval", LT + ".return_home()"], ["wait", 1.0], ["shot", "s_home_night"],
	])
	_steps = s
