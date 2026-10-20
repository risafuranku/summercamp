extends "res://tools/shot_driver.gd"

## Dirty toilets and showers stink where you can see it (scripts/stink_fx.gd), and the
## plates over the guests' heads (guest_agents.gd MARKER_NEEDS), by day and by night.
##   godot --path godot --resolution 1280x720 res://tools/stink_shots.tscn -- --out=<dir>


## A run of shots `dt` apart named <name>_0.. (motion read off a contact sheet).
func _burst(name: String, n: int, dt: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(["shot", "%s_%d" % [name, i]])
		out.append(["wait", dt])
	return out


## Every guest in the camp badly needs `need` (the plate over their head says which).
func need_low(need: String) -> void:
	for g in CoreRoot.get_state().guests:
		if g is Dictionary and (g as Dictionary).get("needs", null) is Dictionary:
			g["needs"][need] = 6.0


## Stands the warden `dist` metres off the first guest out in the open, looking at them.
func aim_at_guest(dist: float) -> String:
	_main.set("debug_camera", null)
	var agents = _main.get("_guest_agents")
	var player: Node3D = _main.get("_player")
	for g in CoreRoot.get_state().guests:
		var at: Vector3 = agents.guest_world_position(int(g.get("id", -1)))
		if at == Vector3.INF:
			continue
		var from := at + Vector3(dist * 0.6, 0.0, dist * 0.8)
		player.global_position = Vector3(from.x, player.global_position.y, from.z)
		player.look_at(Vector3(at.x, player.global_position.y, at.z))
		return "%s at %s" % [str(g.get("name", "")), str(at)]
	return "nobody in the open"


func _ready() -> void:
	super._ready()
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, 11.0)"], ["wait", 3.0],
		["money", 20000], ["clear", 12, 3, 9, 8],
		["build", "toilet_block", 13, 4, 0], ["build", "shower_block", 17, 4, 0],
		["build", "tent_1", 19, 9, 0], ["build", "cabin_1", 12, 9, 0], ["wait", 0.6],
		# The toilets filthy, the showers getting there.
		["condition", 13, 4, 0.06], ["condition", 17, 4, 0.36], ["wait", 1.2],
		["eval", "[get_node('/root/CoreRoot').get_state().grid.cells.get(Vector2i(13, 4), {}).get('type'), get_node('/root/CoreRoot').get_state().grid.cells.get(Vector2i(17, 4), {}).get('type'), _maintenance._stink._blocks.keys()]"],
		["view", 13, 4, 5, 1, 10.0, 0.0], ["wait", 1.0],
	]
	s.append_array(_burst("s0_day", 4, 0.3))
	s.append_array([
		["view", 13, 4, 1, 1, 5.0, 20.0], ["wait", 0.8], ["shot", "s1_toilet"],
		["view", 17, 4, 1, 1, 6.0, -15.0], ["wait", 0.8], ["shot", "s1_showers"],
		["player", 13, 6, 0.0], ["eval", "_player.rotate_y(PI)"], ["wait", 0.8],
		["eval", "_hud_manager._hint_label.text if _hud_manager.get('_hint_label') != null else ''"],
		["shot", "s1_toilet_door"],
		# Cleaned: the stink goes.
		["condition", 13, 4, 1.0], ["wait", 1.2], ["view", 13, 4, 1, 1, 5.0, 20.0], ["wait", 0.8], ["shot", "s2_toilet_clean"],
		["condition", 13, 4, 0.06],
		# Guests: a plate with what they need over their heads.
		["prep_all"], ["book", "Novak family", "family", 3, 2, 0], ["book", "Pepa", "drunk", 1, 2, 0], ["hours", 0.05], ["checkin"], ["wait", 1.0],
		["hours", 0.2], ["wait", 1.0],
		["eval", "get_tree().root.get_node('StinkShots').need_low('bladder')"], ["wait", 1.0],
		["eval", "get_tree().root.get_node('StinkShots').aim_at_guest(5.0)"], ["wait", 0.6], ["shot", "s3_need_wc"],
		["eval", "get_tree().root.get_node('StinkShots').need_low('hunger')"], ["wait", 0.8],
		["eval", "get_tree().root.get_node('StinkShots').aim_at_guest(5.0)"], ["wait", 0.6], ["shot", "s4_need_food"],
		# Evening and night: the stink does not glow.
		["eval", "debug_jump_to(1, 19.6)"], ["wait", 3.0],
		["view", 13, 4, 5, 1, 10.0, 0.0], ["wait", 1.0], ["shot", "s5_dusk"],
		["eval", "debug_jump_to(1, 23.0)"], ["wait", 3.0],
		["view", 13, 4, 5, 1, 10.0, 0.0], ["wait", 1.0], ["shot", "s6_night"],
		["gm", "get_camp_mood_summary"],
	])
	_steps = s
