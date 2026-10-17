extends RefCounted

## The doors guests walk in and out by (guest_agents.gd): the building's door leaf (a box
## named Door, Door0, DoorLeaf in the model) is hung on a hinge at its left edge the first
## time anyone uses it, swings inward while someone goes through and shuts after them, in
## steps like everything else (12 a second). A building without a door leaf (a tent) has
## none to swing: people crouch in under the flap (the agents sink the sprite).

const FPS := 12.0
## Out toward you (the buildings are solid boxes: swung in, the leaf vanished into the
## wall); behind it a dark doorway shows while it stands open.
const OPEN_DEG := -82.0
const SPEED_DEG := 420.0

## door instance id -> {door, pivot, base: Basis, angle, open_until}
static var _doors: Dictionary = {}
static var _acc := 0.0
static var _clock := 0.0


## The structure (a node tagged with building_type) on a grid tile, or null.
static func structure_at(tile: Vector2i) -> Node3D:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or state.grid == null:
		return null
	var n = state.grid.occupants.get(tile, null)
	while n != null and n is Node and not (n as Node).has_meta("building_type"):
		n = (n as Node).get_parent()
	return n as Node3D if n is Node3D else null


static func find_door(structure: Node3D) -> MeshInstance3D:
	if structure == null:
		return null
	for name in ["DoorLeaf", "Door", "Door0"]:
		for m in structure.find_children(name, "MeshInstance3D", true, false):
			if (m as MeshInstance3D).mesh is BoxMesh:
				return m as MeshInstance3D
	return null


## Where to stand to go in: {outside, inside, door (or null)} in world space. Outside is a
## step in front of the door, inside a step behind it. Without a door leaf: the middle of
## the building's front (+Z of its model, turned with it).
static func entry_points(structure: Node3D) -> Dictionary:
	if structure == null:
		return {}
	var door := find_door(structure)
	var centre: Vector3
	var normal: Vector3
	if door != null and _doors.has(door.get_instance_id()):
		centre = _doors[door.get_instance_id()]["centre_global"]
		normal = (_doors[door.get_instance_id()]["base_global"] as Basis).z
	elif door != null:
		centre = door.global_position
		normal = door.global_basis.z
	else:
		var size: Vector3 = structure.get_meta("model_size", Vector3(2, 2, 2)) if structure.get_meta("model_size", null) is Vector3 else Vector3(2, 2, 2)
		normal = structure.global_basis.z
		centre = structure.global_position + normal.normalized() * size.z * 0.5
	normal.y = 0.0
	normal = normal.normalized() if normal.length() > 0.01 else Vector3.BACK
	var ground := Vector3(centre.x, structure.global_position.y, centre.z)
	return {"outside": ground + normal * 0.7, "inside": ground - normal * 0.55, "door": door}


## Open `door` now and keep it open for `seconds`.
static func open(door: MeshInstance3D, seconds: float = 1.6) -> void:
	if door == null or not is_instance_valid(door):
		return
	var id := door.get_instance_id()
	if not _doors.has(id):
		if not _hang(door):
			return
	_doors[id]["open_until"] = _clock + seconds


static func _hang(door: MeshInstance3D) -> bool:
	var parent := door.get_parent() as Node3D
	var box := door.mesh as BoxMesh
	if parent == null or box == null:
		return false
	var base_global := door.global_basis
	var centre_global := door.global_position
	var pivot := Node3D.new()
	pivot.name = door.name + "Hinge"
	pivot.transform = Transform3D(door.basis, door.position - door.basis.x * box.size.x * 0.5)
	parent.add_child(pivot)
	var hole := MeshInstance3D.new()
	hole.name = door.name + "Way"
	var q := QuadMesh.new()
	q.size = Vector2(box.size.x * 0.96, box.size.y * 0.98)
	hole.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.035, 0.03, 0.025)
	hole.material_override = m
	# In the leaf's plane, a hair out: in front of the frame the models put behind it.
	hole.transform = Transform3D(door.basis, door.position + door.basis.z * 0.004)
	hole.visible = false
	parent.add_child(hole)
	parent.remove_child(door)
	pivot.add_child(door)
	door.transform = Transform3D(Basis(), Vector3(box.size.x * 0.5, 0, 0))
	_doors[door.get_instance_id()] = {"door": door, "pivot": pivot, "hole": hole, "base": pivot.basis, "base_global": base_global, "centre_global": centre_global, "angle": 0.0, "open_until": -1.0}
	return true


static func tick(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var step := _acc
	_acc = 0.0
	var gone: Array = []
	for id in _doors.keys():
		var d: Dictionary = _doors[id]
		var pivot: Node3D = d["pivot"]
		if pivot == null or not is_instance_valid(pivot):
			gone.append(id)
			continue
		var want := OPEN_DEG if _clock < float(d["open_until"]) else 0.0
		var a := move_toward(float(d["angle"]), want, SPEED_DEG * step)
		if a != float(d["angle"]):
			d["angle"] = a
			pivot.basis = (d["base"] as Basis) * Basis(Vector3.UP, deg_to_rad(a))
			var hole: Node3D = d.get("hole", null)
			if hole != null and is_instance_valid(hole):
				hole.visible = absf(a) > 4.0
	for id in gone:
		_doors.erase(id)
