extends "res://tools/shot_driver.gd"

## The Photographer's worse half (scripts/enemies/tourist_brain.gd): a picture of you
## outdoors, the broken neck, the run at you from behind, the last picture. Debug only.
##   godot --path godot --resolution 1280x720 res://tools/photographer_worse_shots.tscn -- --out=<dir>

const B := "_active_enemy_brain"


func _burst(name: String, n: int, dt: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(["shot", "%s_%02d" % [name, i]])
		out.append(["eval", B + ".get_debug_snapshot()"])
		out.append(["wait", dt])
	return out


func _ready() -> void:
	super._ready()
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["player", 12, 12, 0.0], ["hours", 13.0], ["wait", 3.0],
		["call", "debug_spawn_enemy", ["tourist", 3]], ["wait", 2.0],
		["look_at_enemy"], ["wait", 0.3],
		["eval", B + "._picture_of_you(" + B + "._head(), null)"],
	]
	s.append_array(_burst("pic", 6, 0.6))
	s.append_array([["eval", B + ".set('_hits', 2)"], ["eval", B + "._set_pose('neck')"], ["look_at_enemy"], ["wait", 0.3]])
	s.append_array(_burst("neck", 2, 0.5))
	s.append_array([["eval", B + ".set('_hits', 3)"], ["eval", B + "._enter_rush()"]])
	s.append_array(_burst("rush", 10, 0.25))
	s.append_array([["wait", 4.0], ["eval", "_player_health"], ["look_at_enemy"],
		["eval", B + "._kill(" + B + "._head())"]])
	s.append_array(_burst("kill", 22, 0.25))
	s.append_array([["eval", "_player_health"]])
	_steps = s
