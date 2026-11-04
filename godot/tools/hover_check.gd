extends "res://tools/shot_driver.gd"

## The glints under the pointer (the user 4. 11.: "the hovers clip badly at the corn, the
## reception's bench and curtains have none, check them everywhere"): in the reception, from
## behind the counter and from the bench, the pointer put on each thing you can use; prints
## what it says is under it and whether the thing glints ("HOVER ..."), with --out a picture
## of each. Run alone: the pointer is the machine's own.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/hover_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('HoverCheck')"
const IDS := ["bench", "curtain", "board", "phone", "door", "store_door", "front_door", "desklamp"]


func point_at(id: String) -> String:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var ex = bi.get("_extras")
	var hot: Dictionary = ex.get("hot")
	if not hot.has(id):
		return "HOVER %s: no such thing" % id
	var body: Node3D = hot[id]["body"]
	var cam: Camera3D = bi.get("_interior_camera")
	cam.get_parent()
	var vp: SubViewport = bi.get("_viewport")
	var p := cam.unproject_position(body.global_position)
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var vs: Vector2 = Vector2(vp.size) if vp != null else win
	Input.warp_mouse(p / vs * win)
	return "pointer on %s at %s" % [id, p / vs]


func report(id: String, where: String) -> String:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var ex = bi.get("_extras")
	var hot: Dictionary = ex.get("hot")
	var glints := 0
	if hot.has(id):
		for m in hot[id]["meshes"]:
			if m is MeshInstance3D and is_instance_valid(m) and (m as MeshInstance3D).material_overlay != null:
				glints += 1
	var line := "HOVER %s from %s: under=%s glinting=%d/%d" % [id, where, ex.call("hovered"), glints, (hot[id]["meshes"] as Array).size() if hot.has(id) else 0]
	print(line)
	return line


func _ready() -> void:
	super._ready()
	var steps: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.6],
	]
	for id in IDS:
		steps.append_array([["eval", C + ".point_at('%s')" % id], ["wait", 0.3], ["eval", C + ".report('%s', 'office')" % id], ["shot", "office_%s" % id]])
	steps.append_array([["eval", "_interior_manager._building_interior._extras.go_bench()"], ["wait", 4.0]])
	for id in IDS:
		steps.append_array([["eval", C + ".point_at('%s')" % id], ["wait", 0.3], ["eval", C + ".report('%s', 'bench')" % id], ["shot", "bench_%s" % id]])
	# The curtain drawn from the bench (the user 4. 11.: "standing at the window I cannot").
	steps.append_array([["eval", C + ".point_at('curtain')"], ["wait", 0.4], ["eval", "_interior_manager._building_interior._extras.hovered()"],
		["eval", "_interior_manager._building_interior._extras.click()"], ["wait", 1.2], ["eval", "_interior_manager._building_interior._extras.office_curtain.target"], ["shot", "bench_drawn"]])
	_steps = steps
