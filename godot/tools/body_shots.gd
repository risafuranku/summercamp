extends "res://tools/shot_driver.gd"

## The body's hands (scripts/ui/hands.gd, reach_hand.gd): the hand going out to a door
## and a switch by day; the torch hand shivering with cold on a snowy night, then
## trembling with something close. Quick runs of shots show the motion.
##   godot --path godot --resolution 1280x720 res://tools/body_shots.tscn -- --out=<dir>

const R := "get_tree().get_first_node_in_group('hands').get_node('ReachHand')"


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
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["wait", 2.0],
		["eval", R + ".reach('grab')"]]
	s.append_array(_burst("a_grab", 9, 0.083))
	s.append_array([["wait", 0.6], ["eval", R + ".reach('press')"]])
	s.append_array(_burst("b_press", 7, 0.083))
	s.append_array([["eval", "debug_jump_to(28, 23.0)"], ["eval", "weather_system.set_weather(4)"], ["wait", 6.0],
		["eval", "get_tree().get_first_node_in_group('hands').get('cold')"]])
	s.append_array(_burst("c_cold", 12, 0.083))
	s.append_array([["call", "debug_spawn_enemy", ["silent_man", 3]], ["wait", 4.0],
		["eval", "get_tree().get_first_node_in_group('hands').get('fear')"]])
	s.append_array(_burst("d_fear", 12, 0.083))
	s.append_array([["eval", R + ".reach('grab')"]])
	s.append_array(_burst("e_grab_torch", 8, 0.083))
	_steps = s
