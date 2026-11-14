extends RefCounted

## The camp you inherit is not new: the old cabin by the office, shut since last summer, rotten
## (its condition at the bottom, broken until it is patched up with R) and filthy inside
## (GuestManager.make_room_derelict). It is the first job and the lesson in how a room
## works (quest steps fix_cabin, clean_cabin). The key of its room, "" if there is none.
## (Out of main.gd 15. 11.: main places it in a new story camp, keeps `key` in the save and
## answers ruined_cabin_key() / debug_repair_ruined() with it.)

const CONDITION := 0.06

var main: Node
## The key of its room ("x:y"), "" if there is none.
var key := ""


func _init(main_node: Node) -> void:
	main = main_node


func key_now() -> String:
	# Bulldozed (Builder is yours from the first mail): nothing left to mend or clean, the
	# checklist's steps about it are done, not waiting for good.
	if not key.is_empty():
		var parts := key.split(":")
		var state = CoreRoot.get_state()
		if state != null and state.grid != null and state.grid.is_cell_free(Vector2i(int(parts[0]), int(parts[1]))):
			return ""
	return key


## Shot driver: patch the old cabin up as hold R would (no charge).
func debug_repair() -> bool:
	if key.is_empty():
		return false
	var parts := key.split(":")
	return CoreRoot.actions.service_building(Vector2i(int(parts[0]), int(parts[1])), 0)


func place() -> void:
	key = ""
	if main.grid_manager == null or CoreRoot == null or CoreRoot.get_state() == null:
		return
	var office := Vector2i(-1, -1)
	var structures_root: Node = main.building_manager.get_node_or_null("Structures") if main.building_manager != null else null
	if structures_root != null:
		for c in structures_root.get_children():
			if str(c.get_meta("building_type", "")) == "main_building":
				office = c.get_meta("grid_origin", Vector2i(-1, -1))
	if office.x < 0:
		return
	var fp := Vector2i(2, 2)
	var state = CoreRoot.get_state()
	for off in [Vector2i(-3, 1), Vector2i(3, 1), Vector2i(-3, 3), Vector2i(3, 3), Vector2i(-4, 0), Vector2i(4, 0), Vector2i(-3, 5), Vector2i(3, 5)]:
		var at: Vector2i = office + off
		if not _clear_trees_for(at, fp):
			continue
		if not state.grid.can_place_footprint(at, fp):
			continue
		var money_before: int = CoreRoot.get_money()
		EventBus.RequestBuild.emit("cabin_1", at, 0)
		if str((state.grid.cells.get(at, {}) as Dictionary).get("type", "")) != "cabin_1":
			continue
		# It was already here: what the build charged goes back.
		CoreRoot.actions.add_money(money_before - CoreRoot.get_money())
		var inst := str((state.grid.cells[at] as Dictionary).get("id", ""))
		for c2 in state.grid.cells.keys():
			var cell: Dictionary = state.grid.cells[c2]
			if str(cell.get("id", "")) == inst:
				cell["maintenance"] = CONDITION
				state.grid.cells[c2] = cell
		var room_key := "%d:%d" % [at.x, at.y]
		state.failures[room_key] = {"type": "cabin_1", "coord": at, "since_day": 1, "repair_progress": 0.0, "derelict": true}
		if structures_root != null and main.building_manager.has_method("set_structure_condition"):
			for c3 in structures_root.get_children():
				if c3.get_meta("grid_origin", Vector2i(-99, -99)) == at:
					main.building_manager.set_structure_condition(c3, CONDITION)
		if GuestManager != null and GuestManager.has_method("make_room_derelict"):
			GuestManager.make_room_derelict(room_key)
		key = room_key
		dress()
		return


func _structure() -> Node3D:
	if key.is_empty() or main.building_manager == null:
		return null
	var parts := key.split(":")
	var at := Vector2i(int(parts[0]), int(parts[1]))
	var root: Node = main.building_manager.get_node_or_null("Structures")
	if root == null:
		return null
	for c in root.get_children():
		if c.get_meta("grid_origin", Vector2i(-99, -99)) == at:
			return c as Node3D
	return null


## While it is still broken: boards nailed over the windows and across the door, weeds
## up the walls, sheets off the roof lying in the grass. Gone when it is patched up.
func dress() -> void:
	var cabin := _structure()
	if cabin == null or cabin.get_node_or_null("Ruin") != null:
		return
	if not CoreRoot.get_state().failures.has(key):
		return
	var ws: Vector3 = cabin.get_meta("wall_size", Vector3(6.24, 2.8, 6.24))
	var front := ws.z * 0.5
	var ruin := Node3D.new()
	ruin.name = "Ruin"
	cabin.add_child(ruin)
	var plank := StandardMaterial3D.new()
	plank.albedo_texture = load("res://assets/textury/camp/planks_dark.png")
	plank.albedo_color = Color(0.7, 0.62, 0.52)
	plank.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plank.uv1_triplanar = true
	var weed := StandardMaterial3D.new()
	weed.albedo_color = Color(0.26, 0.36, 0.16)
	var sheet := StandardMaterial3D.new()
	sheet.albedo_texture = load("res://assets/textury/camp/corrugated_roof.png")
	sheet.albedo_color = Color(0.6, 0.5, 0.42)
	sheet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sheet.uv1_triplanar = true
	var boards: Array = []
	# Over the front windows where the cabin's plan has them (scripts/cabin_layout.gd).
	var CL = load("res://scripts/cabin_layout.gd")
	var win_y: float = CL.MODEL_FLOOR + CL.SILL_MID
	for x: float in [-CL.FRONT_WIN_X, CL.FRONT_WIN_X]:
		boards.append([Vector3(0.9, 0.12, 0.04), Vector3(x, win_y + 0.1, front + 0.07), 0.32])
		boards.append([Vector3(0.9, 0.12, 0.04), Vector3(x, win_y - 0.12, front + 0.08), -0.28])
	boards.append([Vector3(1.15, 0.15, 0.05), Vector3(0, 1.25, front + 0.09), 0.18])
	boards.append([Vector3(1.15, 0.15, 0.05), Vector3(0, 0.7, front + 0.1), -0.22])
	for b in boards:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[0]
		m.mesh = bm
		m.material_override = plank
		m.position = b[1]
		m.rotation.z = float(b[2])
		ruin.add_child(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	for i in 26:
		var side := rng.randi_range(0, 3)
		var t := rng.randf_range(-0.5, 0.5)
		var at := Vector3(t * ws.x, 0, front + 0.12) if side == 0 else (Vector3(t * ws.x, 0, -front - 0.12) if side == 1 else Vector3((ws.x * 0.5 + 0.12) * (1.0 if side == 2 else -1.0), 0, t * ws.z))
		var h := rng.randf_range(0.25, 0.7)
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.07, h, 0.07)
		w.mesh = wm
		w.material_override = weed
		w.position = at + Vector3(0, h * 0.5, 0)
		w.rotation.z = rng.randf_range(-0.3, 0.3)
		ruin.add_child(w)
	for i in 2:
		var sm := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(1.4, 0.03, 0.8)
		sm.mesh = sb
		sm.material_override = sheet
		sm.position = Vector3(-1.2 + i * 2.6, 0.04 + i * 0.03, front + 1.1 + i * 0.3)
		sm.rotation = Vector3(0.05, 0.6 - i * 1.1, 0.08)
		ruin.add_child(sm)


## Patched up (hold R): the boards come off, the weeds are pulled, the sheets go back.
func on_serviced(root: Vector2i, _type: String, _was_broken: bool, _cost: int) -> void:
	if key.is_empty() or "%d:%d" % [root.x, root.y] != key:
		return
	var cabin := _structure()
	var ruin := cabin.get_node_or_null("Ruin") if cabin != null else null
	if ruin != null:
		ruin.queue_free()


## The trees (and corn) standing where the old cabin goes: grown in round it since the
## camp shut. False when something else is in the way (a building, the path, the lake).
func _clear_trees_for(origin: Vector2i, fp: Vector2i) -> bool:
	for y in fp.y:
		for x in fp.x:
			var c := origin + Vector2i(x, y)
			if not main.grid_manager.is_in_bounds(c):
				return false
			var tile = main.grid_manager.get_tile(c)
			if tile == null or tile.tile_type != main.grid_manager.TILE_GRASS:
				return false
			var occ = tile.occupant
			if occ != null and is_instance_valid(occ):
				var n: Node = occ
				while n != null and not n.has_meta("grid_origin"):
					n = n.get_parent()
				if n != null:
					return false
	for y in fp.y:
		for x in fp.x:
			var c2 := origin + Vector2i(x, y)
			var tile2 = main.grid_manager.get_tile(c2)
			if tile2 != null and tile2.occupant != null and is_instance_valid(tile2.occupant):
				(tile2.occupant as Node).queue_free()
			main.grid_manager.set_tile_occupied(c2, false, null)
	return true
