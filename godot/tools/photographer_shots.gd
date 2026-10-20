extends "res://tools/shot_driver.gd"

## The Photographer (scripts/enemies/tourist_brain.gd): outdoors (walking about humming,
## framing, the flash, the blast when you look), then at the cabin's window with the
## curtain open and drawn, then at the reception's. Debug tooling only.
##   godot --path godot --resolution 1280x720 res://tools/photographer_shots.tscn -- --out=<dir>

const B := "_active_enemy_brain"


func _burst(name: String, n: int, dt: float, look := false) -> Array:
	var out: Array = []
	for i in n:
		if look:
			out.append(["look_at_enemy"])
		out.append(["shot", "%s_%d" % [name, i]])
		out.append(["eval", B + ".get_debug_snapshot()"])
		out.append(["wait", dt])
	return out


func _ready() -> void:
	super._ready()
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["money", 20000], ["clear", 9, 6, 5, 5], ["build", "cabin_1", 10, 7, 0], ["wait", 1.0],
		["player", 12, 12, 0.0], ["hours", 13.0], ["wait", 3.0],
		["call", "debug_spawn_enemy", ["tourist", 3]], ["wait", 1.5],
		["eval", "_player_health"],
		["look_at_enemy"], ["wait", 0.3],
	]
	s.append_array(_burst("o_watch", 10, 1.0, true))
	s.append_array([["eval", "_player_health"],
		["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('cabin_1'))"], ["wait", 2.0],
		["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"],
		["eval", "_interior_manager.photo_windows()"]])
	s.append_array(_burst("c_open", 12, 1.0))
	s.append_array([["eval", "_player_health"],
		["eval", "_interior_manager._cabin_interior.take_curtains([false, false, false, false])"], ["wait", 1.5]])
	s.append_array(_burst("c_shut", 10, 1.0))
	s.append_array([["eval", "_player_health"]])
	_steps = s
