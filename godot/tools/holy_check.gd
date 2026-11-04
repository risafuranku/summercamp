extends "res://tools/shot_driver.gd"

## What is still a bare colour in a room (the user 4. 11.: "everything textured"): every
## mesh of the reception (office, back room, store) with no picture on it, by name and size
## ("HOLE ..."). Run windowed: godot --path godot --audio-driver Dummy --resolution 1280x720
## res://tools/holy_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('HolyCheck')"


func dump() -> String:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var root: Node = bi.get("_room_root")
	var n := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var mat := mi.material_override
		if mat == null and mi.mesh.get_surface_count() > 0:
			mat = mi.mesh.surface_get_material(0)
		var bare := true
		if mat is StandardMaterial3D:
			bare = (mat as StandardMaterial3D).albedo_texture == null
		elif mat is ShaderMaterial:
			bare = false
		if bare:
			var box := mi.get_aabb().size
			print("HOLE %s size=(%.2f %.2f %.2f) under=%s" % [mi.name, box.x, box.y, box.z, mi.get_parent().name])
			n += 1
	return "HOLE total %d" % n


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
		["eval", C + ".dump()"], ["eval", "get_tree().quit()"],
	]
