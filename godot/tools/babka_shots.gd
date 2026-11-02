extends "res://tools/shot_driver.gd"

## The mushroom granny's night (scripts/enemies/basket_brain.gd, DESIGN.md §5a.4): out
## there coming for you, stopped and looking, at a lamp's edge; you hidden in the office
## while she goes from lodging to lodging; out again; the morning, and the carnage inside
## a lodging she ate in.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/babka_shots.tscn -- --out=<dir>


func granny():
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "basket":
			return b
	return null


func state() -> Dictionary:
	var g = granny()
	return g.get_debug_snapshot() if g != null else {}


## The warden under the camp's first lit lamp, looking out of its light.
func under_lamp() -> String:
	var bm = _main.get("building_manager")
	var lamps: Array = bm.lit_lamp_positions() if bm != null else []
	if lamps.is_empty():
		return "no lamp lit"
	var at: Vector3 = lamps[0]
	var p: Node3D = _main.get("_player")
	_main.set("debug_camera", null)
	p.global_position = Vector3(at.x + 1.2, p.global_position.y, at.z + 1.2)
	var g = granny()
	if g != null and g.get("_body") != null:
		var b: Vector3 = g._body.global_position
		p.look_at(Vector3(b.x, p.global_position.y, b.z))
	return "under the lamp at %s" % str(at)


## The warden at the door of a lodging she ate in, the lodging opened (the carnage).
func into_carnage() -> String:
	var keys: Array = []
	for k in CoreRoot.get_state().accommodation_states:
		var m = (CoreRoot.get_state().accommodation_states[k] as Dictionary).get("mess", {})
		if m is Dictionary and bool((m as Dictionary).get("carnage", false)):
			keys.append(str(k))
	if keys.is_empty():
		return "no carnage"
	var root = _main.get("building_manager").get_node_or_null("Structures")
	for child in root.get_children():
		var o = child.get_meta("grid_origin", null)
		if o is Vector2i and "%d:%d" % [o.x, o.y] == keys[0]:
			var im = _main.get("_interior_manager")
			var t := str(child.get_meta("building_type", ""))
			_main.set("debug_camera", null)
			_main.get("_player").global_position = (child as Node3D).global_position + Vector3(0, 0, 3.0)
			if t.contains("tent"):
				im._on_tent_interact(child)
			elif t.contains("caravan"):
				im._on_caravan_interact(child)
			else:
				im._on_cabin_interact(child)
			return "%s (%s)" % [keys[0], t]
	return "no structure for %s" % keys[0]


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
		["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
		["eval", "get_tree().root.get_node('BabkaShots').state()"],
		["look_at_enemy"], ["enemy_dist"], ["wait", 0.3], ["shot", "b0_far"],
		["wait", 3.0], ["look_at_enemy"], ["enemy_dist"], ["shot", "b1_coming"],
		["eval", "get_tree().root.get_node('BabkaShots').granny()._set_phase('look', 3.0)"], ["wait", 0.6], ["look_at_enemy"], ["shot", "b2_look"],
		# Under a lamp: she stops at its edge and reaches up for the bulb.
		["eval", "get_tree().root.get_node('BabkaShots').under_lamp()"], ["wait", 6.0],
		["eval", "get_tree().root.get_node('BabkaShots').state()"], ["look_at_enemy"], ["shot", "b3_lamp_edge"],
		["wait", 3.0], ["eval", "get_tree().root.get_node('BabkaShots').state()"], ["look_at_enemy"], ["shot", "b4_lamp_out"],
		# Hidden in the office: she goes for the guests.
		["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 18.0],
		["eval", "[get_tree().root.get_node('BabkaShots').state(), _interior_manager._building_interior._dread._relay_on]"], ["shot", "b5_office"],
		["wait", 30.0], ["eval", "get_tree().root.get_node('BabkaShots').state()"],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.5],
		["eval", "get_tree().root.get_node('BabkaShots').state()"], ["look_at_enemy"], ["shot", "b6_out_again"],
		# The morning: who is gone, and what is left in there.
		["eval", "debug_jump_to(3, 6.6)"], ["wait", 3.0], ["shot", "b7_morning"],
		["eval", "EmailManager._scheduled_mails.size()"],
		["eval", "get_tree().root.get_node('BabkaShots').into_carnage()"], ["wait", 2.5], ["shot", "b8_carnage"],
	]
