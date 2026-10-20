extends "res://tools/shot_driver.gd"

## The Silent Man's worse catches (scripts/enemies/silent_man_brain.gd): each forced in
## turn ("cross", "inside", "eyes"), shot through. Debug tooling only.
##   godot --path godot --resolution 1280x720 res://tools/silentman_shots.tscn -- --out=<dir>

const B := "_active_enemy_brain"


func _catch(kind: String, n: int) -> Array:
	var out: Array = [["eval", B + "._start_catch('%s')" % kind]]
	for i in n:
		out.append(["wait", 0.25])
		out.append(["shot", "%s_%02d" % [kind, i]])
	out.append(["wait", 4.0])
	return out


func _ready() -> void:
	super._ready()
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["player", 12, 12, 0.0], ["hours", 14.5], ["wait", 2.0],
		["call", "debug_spawn_enemy", ["silent_man", 3]], ["wait", 2.0],
	]
	s.append_array(_catch("cross", 9))
	s.append_array(_catch("inside", 12))
	s.append_array(_catch("eyes", 11))
	s.append_array([["eval", "_player_health"]])
	_steps = s
