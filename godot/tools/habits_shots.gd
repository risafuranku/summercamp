extends "res://tools/shot_driver.gd"

## The cigarette and the bottle (scripts/town/pockets.gd, scripts/habits/) and the hands
## (scripts/ui/hands.gd): every stage driven by the real keys, outdoors by day and night,
## with the tools in the right hand, and in a room. Quick runs of shots show the motion.
##   godot --path godot --resolution 1280x720 res://tools/habits_shots.tscn -- --out=<dir>

const P := "_interior_manager.town_trip().pockets"
const INV := "_interior_manager.town_trip().inventory"


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
		["eval", "debug_jump_to(1, 10.5)"], ["wait", 4.0],
		["eval", INV + ".add_item('cigs')"], ["eval", INV + ".add_item('beer')"], ["eval", INV + ".add_item('beer')"],
		["eval", INV + ".add_item('beer')"],
		["eval", P + ".cig.set('debug_catch', true)"],
		# The pack: two taps, up to the mouth, the lighter.
		["key", "C"], ["wait", 0.05],
	]
	s.append_array(_burst("a_pack", 10, 0.1))
	s.append_array([["wait", 0.3], ["shot", "a_lighter"],
		["keyhold", "C", true]])
	s.append_array(_burst("b_flame", 8, 0.1))
	s.append_array([["wait", 0.5], ["keyhold", "C", false]])
	s.append_array(_burst("c_lit", 6, 0.1))
	s.append_array([["wait", 1.0], ["shot", "d_hold"],
		["keyhold", "C", true]])
	s.append_array(_burst("e_drag", 5, 0.1))
	s.append_array([["keyhold", "C", false]])
	s.append_array(_burst("f_exhale", 8, 0.12))
	s.append_array([["eval", P + ".cig.set('ash', 0.25)"], ["wait", 0.3], ["shot", "g_ash"],
		["key", "X"]])
	s.append_array(_burst("g_tap", 4, 0.08))
	# The bottle: out, shaken, levered open, foam, a drink.
	s.append_array([["key", "B"], ["wait", 0.7], ["shot", "h_bottle"], ["eval", P + ".bottle.set('shake', 0.9)"],
		["keyhold", "B", true]])
	s.append_array(_burst("i_opening", 14, 0.1))
	s.append_array([["keyhold", "B", false]])
	s.append_array(_burst("j_foam", 6, 0.12))
	s.append_array([["wait", 2.6], ["keyhold", "B", true]])
	s.append_array(_burst("k_drink", 8, 0.12))
	s.append_array([["keyhold", "B", false], ["wait", 0.5], ["shot", "k_after"],
		# Throw the butt, then the bottle.
		["keyhold", "X", true], ["wait", 0.5], ["keyhold", "X", false]])
	s.append_array(_burst("l_flick", 4, 0.08))
	s.append_array([["wait", 1.2], ["keyhold", "X", true], ["wait", 0.5], ["keyhold", "X", false]])
	s.append_array(_burst("m_throw", 5, 0.1))
	# Night: the torch; the tools in the right hand send it to the left.
	s.append_array([["eval", "debug_jump_to(1, 22.5)"], ["wait", 3.0], ["shot", "n_night_torch"],
		["eval", "_hud_manager.set_work_progress('BAGGING rubbish', 0.4)"], ["wait", 1.6], ["shot", "o_bag"],
		["eval", "_hud_manager.clear_work_progress()"], ["wait", 0.8],
		["eval", "_hud_manager.set_work_progress('REPAIRING lamp', 0.4)"], ["wait", 1.6], ["shot", "o_wrench"],
		["eval", "_hud_manager.clear_work_progress()"], ["wait", 1.6], ["shot", "o_torch_back"],
		["key", "B"], ["wait", 1.4], ["shot", "p_bottle_torch_left"],
		["key", "C"], ["wait", 1.4], ["keyhold", "C", true], ["wait", 1.3], ["keyhold", "C", false], ["wait", 1.4], ["shot", "p_lighting_dark"],
		["wait", 1.5], ["shot", "p_cig_mouth"],
		["keyhold", "X", true], ["wait", 0.5], ["keyhold", "X", false], ["wait", 1.0],
		["keyhold", "X", true], ["wait", 0.5], ["keyhold", "X", false], ["wait", 1.4], ["shot", "p_torch_right"],
		# A room: a cabin, by day, smoking in it.
		["eval", "debug_jump_to(2, 11.0)"], ["wait", 2.0],
		["money", 90000], ["clear", 16, 3, 4, 4], ["build", "cabin_1", 17, 4, 0], ["wait", 0.5], ["prep_all"], ["wait", 0.5],
		["open_room", 17, 4], ["wait", 1.5], ["shot", "q_room"],
		["key", "C"], ["wait", 1.4], ["keyhold", "C", true], ["wait", 1.4], ["keyhold", "C", false], ["wait", 1.2], ["shot", "q_room_hold"],
		["keyhold", "C", true], ["wait", 0.9], ["keyhold", "C", false], ["wait", 0.4], ["shot", "q_room_exhale"],
		["wait", 1.5], ["shot", "q_room_haze"],
		["eval", P + ".debug_rects()"],
	])
	_steps = s
