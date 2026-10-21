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
	# The neck round a corner (in front of you, 6 m) and the ceiling over you; in a clearing
	# cut for it (each new game grows its trees elsewhere: a trunk was in the way).
	s.append_array([
		["money", 99999], ["clear", 9, 5, 8, 11], ["wait", 1.0],
		["player", 12, 15, 0.0], ["eval", "_player.get_node('Head').set('rotation', Vector3.ZERO)"], ["wait", 0.2],
		["eval", B + ".set('_lurking', true)"],
		["eval", B + "._show_neck(_player.global_position - _player.global_transform.basis.z * 6.0, _player.global_position - _player.global_transform.basis.z * 6.0 + _player.global_transform.basis.x * 1.5)"],
		["wait", 0.1], ["shot", "neck_0"],
		["eval", B + "._show_neck(_player.global_position - _player.global_transform.basis.z * 6.0, _player.global_position - _player.global_transform.basis.z * 6.0 - _player.global_transform.basis.x * 1.5)"],
		["wait", 0.1], ["shot", "neck_1"], ["eval", B + ".set('_lurking', false)"],
		# (In the game three frames; held here long enough for a picture.)
		["eval", B + "._fx().subliminal(" + B + "._t('res://assets/textury/npc/sm_ceiling.png'), 40, 1.0, Color(0.5, 0.45, 0.45))"],
		["wait", 0.1], ["shot", "ceil_0"], ["wait", 2.0]])
	s.append_array(_catch("cross", 9))
	s.append_array(_catch("inside", 12))
	s.append_array(_catch("eyes", 11))
	s.append_array([["eval", "_player_health"]])
	_steps = s
