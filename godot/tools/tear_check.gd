extends "res://tools/shot_driver.gd"

## The tent the granny slit (the user 4. 11.: "from outside you cannot see in through the
## hole; inside it shows the camp only after a beat"): a tent built, its accommodation marked
## torn (carnage_pending), seen from behind (the room in the hole), then from inside facing it.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/tear_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('TearCheck')"


func _tent() -> Node3D:
	for c in _main.get("building_manager").get_node("Structures").get_children():
		if str(c.get_meta("building_type", "")).begins_with("tent"):
			return c
	return null


func tear() -> String:
	var t := _tent()
	var at: Vector2i = t.get_meta("grid_origin")
	var key := "%d:%d" % [at.x, at.y]
	var st = CoreRoot.get_state()
	var acc: Dictionary = st.accommodation_states.get(key, {})
	var mess: Dictionary = acc.get("mess", {}) if acc.get("mess", {}) is Dictionary else {}
	mess["carnage_pending"] = true
	acc["mess"] = mess
	st.accommodation_states[key] = acc
	_main.get("building_manager").call("_refresh_tent_tear", t, key)
	return "torn %s: %s" % [key, str(t.find_child("TentTear", true, false) != null)]


func behind(dist: float) -> String:
	var t := _tent()
	var back := -t.global_basis.z.normalized()
	var p: Node3D = _main.get("_player")
	p.global_position = t.global_position + back * dist + Vector3(0, 0.2, 0)
	p.look_at(t.global_position + Vector3(0, 0.6, 0))
	return "behind %.1f" % dist


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.5], ["key", "Escape"], ["wait", 4.0],
		["money", 9000], ["clear", 8, 5, 6, 5], ["build", "tent_1", 9, 6, 0], ["prep_all"], ["wait", 1.0],
		["eval", C + ".tear()"], ["wait", 0.5],
		["eval", C + ".behind(3.2)"], ["wait", 1.5], ["shot", "t1_behind"],
		["eval", C + ".behind(6.0)"], ["wait", 1.5], ["shot", "t2_behind_far"],
	]
