extends RefCounted

## The camp's buildings and the grid's cells kept in step (out of main.gd 15. 11.): the
## buildings stand as nodes under BuildingManager's Structures (each with its type, origin,
## footprint, turn and condition as metas); the camp's state (CoreRoot grid.cells) is
## built again from them (rebuild_cells: a lamp or a bench on a path belongs to the path's
## cell), the office and a sewer put back if a loaded camp has none (ensure_landmarks), and
## how many guests each lodging holds written onto it for its windows (sync_guest_counts).

const INSTANCE = preload("res://scripts/instance/instance.gd")
var main: Node


func _init(main_node: Node) -> void:
	main = main_node


func ensure_landmarks() -> void:
	if main.building_manager == null or main.grid_manager == null:
		return
	if not has_type("main_building"):
		_place_reception()
	if main.world_generator != null and main.world_generator.has_method("place_starter_path"):
		main.world_generator.place_starter_path()
	if not has_type("sewer"):
		if main.world_generator != null and main.world_generator.has_method("place_sewer_landmark"):
			main.world_generator.place_sewer_landmark()
		else:
			_place_sewer()


func has_type(building_id: String) -> bool:
	if main.building_manager == null:
		return false
	var structures_root: Node = main.building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return false
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		if str(structure.get_meta("building_type", "")) == building_id:
			return true
	return false


func _place_reception() -> bool:
	if main.building_manager == null or main.grid_manager == null:
		return false
	if not main.building_manager.has_method("place_main_building"):
		return false
	var footprint := Vector2i(2, 2)
	var center_x := int(floor(float(main.grid_manager.grid_width - footprint.x) * 0.5))
	var candidates: Array[Vector2i] = [
		Vector2i(center_x, 1),
		Vector2i(center_x, 0),
		Vector2i(center_x - 1, 0),
		Vector2i(center_x + 1, 0),
		Vector2i(center_x, 1),
		Vector2i(center_x - 1, 1),
		Vector2i(center_x + 1, 1),
		Vector2i(center_x, 2)
	]
	for candidate in candidates:
		if candidate.x < 0 or candidate.y < 0:
			continue
		if candidate.x + footprint.x > main.grid_manager.grid_width:
			continue
		if candidate.y + footprint.y > main.grid_manager.grid_height:
			continue
		if main.building_manager.place_main_building(candidate, footprint):
			return true

	var max_y: int = int(min(8, max(1, main.grid_manager.grid_height - footprint.y)))
	var min_x: int = int(max(0, center_x - 5))
	var max_x: int = int(min(main.grid_manager.grid_width - footprint.x, center_x + 5))
	for y in range(0, max_y + 1):
		for x in range(min_x, max_x + 1):
			if main.building_manager.place_main_building(Vector2i(x, y), footprint):
				return true
	return false


func _place_sewer() -> bool:
	if main.building_manager == null or main.grid_manager == null:
		return false
	var center_x := int(floor(float(main.grid_manager.grid_width) / 2.0))
	var base_y: int = int(max(0, main.grid_manager.grid_height - 3))
	var offsets := [0, 2, -2, 4, -4, 6, -6]
	for offset in offsets:
		var x := clampi(center_x + int(offset), 0, main.grid_manager.grid_width - 1)
		var ys := [base_y, max(0, base_y - 1)]
		for y in ys:
			var coord := Vector2i(x, int(y))
			if not main.grid_manager.is_in_bounds(coord):
				continue
			var tile = main.grid_manager.get_tile(coord)
			if tile == null or tile.occupied:
				continue
			if tile.tile_type != main.grid_manager.TILE_GRASS:
				continue
			if main.building_manager.place_building_at(coord, "sewer"):
				return true
	return false


func root_at(origin: Vector2i) -> Node3D:
	if main.grid_manager == null:
		return null
	var tile = main.grid_manager.get_tile(origin)
	if tile == null or tile.occupant == null:
		return null
	var current = tile.occupant as Node
	while current != null:
		if current is Node3D and current.has_meta("grid_origin"):
			return current as Node3D
		current = current.get_parent()
	return null


func rebuild_cells() -> void:
	if main.building_manager == null:
		return
	var state = INSTANCE.core(main).get_state()
	if state == null or state.grid == null:
		return
	state.grid.cells.clear()
	var structures_root: Node = main.building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return
	var next_id := 1
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		var building_id := str(structure.get_meta("building_type", "")).strip_edges()
		if building_id.is_empty():
			continue
		# A lamp standing on a path tile belongs to the path (cell["lamp"], below): written
		# over the cell it made the path vanish for the Builder and the guests (playtest
		# 2026-10-17: "lamps destroy the path under them at a crossing").
		if structure.has_meta("on_path"):
			continue
		var origin_any = structure.get_meta("grid_origin", Vector2i.ZERO)
		var footprint_any = structure.get_meta("grid_footprint", Vector2i.ONE)
		var origin := origin_any as Vector2i if origin_any is Vector2i else Vector2i.ZERO
		var footprint := footprint_any as Vector2i if footprint_any is Vector2i else Vector2i.ONE
		var condition := clampf(float(structure.get_meta("condition", 1.0)), 0.0, 1.0)
		var instance_id := "structure_%d" % next_id
		next_id += 1
		for oy in range(footprint.y):
			for ox in range(footprint.x):
				var coord := origin + Vector2i(ox, oy)
				if not state.grid.is_in_bounds(coord):
					continue
				state.grid.occupy_cell(coord, building_id, instance_id, origin, footprint)
				var cell = state.grid.cells.get(coord, {})
				if cell is Dictionary:
					var cell_dict := cell as Dictionary
					cell_dict["maintenance"] = condition
					state.grid.cells[coord] = cell_dict
	for child in structures_root.get_children():
		if child is Node3D and child.has_meta("on_path"):
			var o = child.get_meta("grid_origin", Vector2i.ZERO)
			if state.grid.cells.has(o):
				# A bench on a path keeps its turn (the edge it stands at).
				if str(child.get_meta("building_type", "")) == "bench":
					state.grid.cells[o]["bench"] = int(child.get_meta("build_rotation", 0))
				else:
					state.grid.cells[o]["lamp"] = true


## GuestManager owns the room states (status, preparation, who is in it). This only
## mirrors how many checked-in guests each lodging holds onto its 3D structure, for the
## lights in the windows and the interiors. (It used to rebuild the states itself and
## overwrote room preparation with a legacy "clean".)
func sync_guest_counts() -> void:
	if main.building_manager == null or GuestManager == null:
		return
	var structures_root: Node = main.building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return
	var states: Dictionary = INSTANCE.guests(main).get_accommodation_states()
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		var origin_any = structure.get_meta("grid_origin", Vector2i.ZERO)
		var origin := origin_any as Vector2i if origin_any is Vector2i else Vector2i.ZERO
		var acc: Dictionary = states.get(main.SAVE_CODEC.coord_to_key(origin), {})
		var present := int(acc.get("occupied", 0))
		structure.set_meta("guest_count", present)
		structure.set_meta("has_guest", present > 0)
