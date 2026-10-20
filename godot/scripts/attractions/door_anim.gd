extends RefCounted

## The doors guests walk in and out by (guest_agents.gd): the building's door leaf (a box
## named Door, Door0, DoorLeaf in the model) is hung on a hinge at its left edge the first
## time anyone uses it, swings inward while someone goes through and shuts after them, in
## steps like everything else (12 a second), with some weight to it: it swings open fast
## and slows as it opens, swings back faster and faster, knocks on the frame and jumps back
## a hair; its hinges creak as it opens and it shuts with a thud and the latch (ElevenLabs,
## sfx/world/door_*; the warden's own door, open_now, shuts quiet: the room has played its
## door). A building without a door leaf (a tent) has none to swing: people duck in under
## the flap (the agents squash the sprite).

const FPS := 12.0
## Out toward you (the buildings are solid boxes: swung in, the leaf vanished into the
## wall); behind it a dark doorway shows while it stands open.
const OPEN_DEG := -82.0
const SPEED_DEG := 420.0
## Opening: this much of the way left goes each second (it slows as it opens).
const OPEN_EASE := 10.0
## The jump back off the frame when it shuts.
const REBOUND_DEG := -5.0
const CREAKS := ["res://assets/sfx/world/door_creak_a.mp3", "res://assets/sfx/world/door_creak_b.mp3"]
const SHUTS := ["res://assets/sfx/world/door_shut_a.mp3", "res://assets/sfx/world/door_shut_b.mp3"]

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
	var doors := find_doors(structure)
	return doors[0] if not doors.is_empty() else null


## Every door leaf of the building (the outhouse has two, M and Z).
static func find_doors(structure: Node3D) -> Array:
	var out: Array = []
	if structure == null:
		return out
	for name in ["DoorLeaf", "Door", "Door?"]:
		for m in structure.find_children(name, "MeshInstance3D", true, false):
			if (m as MeshInstance3D).mesh is BoxMesh and not out.has(m):
				out.append(m)
	return out


## Where to stand to go in: {outside, inside, door (or null), duck} in world space. Outside
## is a step in front of the door, inside a step behind it; `pick` chooses among several
## doors (or tents on one pitch). Without a door leaf: the tent's flap (TentFlap in the
## model: you duck in there, `duck`), else the middle of the building's front (+Z of its
## model, turned with it).
static func entry_points(structure: Node3D, pick := 0) -> Dictionary:
	if structure == null:
		return {}
	var doors := find_doors(structure)
	var door: MeshInstance3D = doors[absi(pick) % doors.size()] if not doors.is_empty() else null
	var centre: Vector3
	var normal: Vector3
	var flaps: Array = structure.find_children("TentFlap", "MeshInstance3D", true, false) if door == null else []
	if door != null and _doors.has(door.get_instance_id()):
		centre = _doors[door.get_instance_id()]["centre_global"]
		normal = (_doors[door.get_instance_id()]["base_global"] as Basis).z
	elif door != null:
		centre = door.global_position
		normal = door.global_basis.z
	elif not flaps.is_empty():
		var flap: Node3D = flaps[absi(pick) % flaps.size()]
		centre = flap.global_position
		normal = flap.global_basis.z
	else:
		# (get_meta with a null default still complains when the key is missing.)
		var size: Vector3 = structure.get_meta("model_size") if structure.has_meta("model_size") and structure.get_meta("model_size") is Vector3 else Vector3(2, 2, 2)
		normal = structure.global_basis.z
		centre = structure.global_position + normal.normalized() * size.z * 0.5
	normal.y = 0.0
	normal = normal.normalized() if normal.length() > 0.01 else Vector3.BACK
	var ground := Vector3(centre.x, structure.global_position.y, centre.z)
	return {"outside": ground + normal * 0.7, "inside": ground - normal * 0.55, "door": door, "duck": door == null and not flaps.is_empty()}


## Open `door` now and keep it open for `seconds`.
static func open(door: MeshInstance3D, seconds: float = 1.6) -> void:
	if door == null or not is_instance_valid(door):
		return
	var id := door.get_instance_id()
	if not _doors.has(id):
		if not _hang(door):
			return
	_doors[id]["open_until"] = _clock + seconds
	_doors[id]["quiet"] = false


## Open `door` at once, no swing (the warden stepping out through it: a leaf still
## swinging out would pass through his eye), and keep it open for `seconds`.
static func open_now(door: MeshInstance3D, seconds: float = 1.6) -> void:
	open(door, seconds)
	if door == null or not _doors.has(door.get_instance_id()):
		return
	var d: Dictionary = _doors[door.get_instance_id()]
	d["angle"] = OPEN_DEG
	d["quiet"] = true
	(d["pivot"] as Node3D).basis = (d["base"] as Basis) * Basis(Vector3.UP, deg_to_rad(OPEN_DEG))
	if is_instance_valid(d.get("hole", null)):
		(d["hole"] as Node3D).visible = true


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
	# What is fixed on the leaf (the handle, the wired glass, the heart, the M / Z plaque)
	# goes round with it, or it stays hanging in the air when the door opens.
	var fittings: Array = []
	var to_leaf := door.transform.affine_inverse()
	for c in parent.get_children():
		if c == door or not (c is MeshInstance3D or c is Label3D):
			continue
		var at: Vector3 = to_leaf * (c as Node3D).position
		if absf(at.x) > box.size.x * 0.5 or absf(at.y) > box.size.y * 0.5 or absf(at.z) > 0.12:
			continue
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var s: Vector3 = ((c as MeshInstance3D).mesh as BoxMesh).size
			if s.x >= box.size.x * 0.9 or s.y >= box.size.y * 0.9:
				continue
		fittings.append(c)
	parent.remove_child(door)
	pivot.add_child(door)
	door.transform = Transform3D(Basis(), Vector3(box.size.x * 0.5, 0, 0))
	for f in fittings:
		(f as Node3D).reparent(door, true)
	# Its creak and its thud, from the door.
	var snd := AudioStreamPlayer3D.new()
	snd.name = door.name + "Sound"
	snd.bus = "OutdoorAmbience" if AudioServer.get_bus_index("OutdoorAmbience") >= 0 else "Master"
	snd.unit_size = 2.0
	snd.max_distance = 16.0
	snd.position = pivot.position
	parent.add_child(snd)
	_doors[door.get_instance_id()] = {"door": door, "pivot": pivot, "hole": hole, "snd": snd, "base": pivot.basis, "base_global": base_global, "centre_global": centre_global, "angle": 0.0, "open_until": -1.0, "speed": 0.0, "bounced": false, "quiet": false}
	return true


static var _streams: Dictionary = {}


static func _sound(d: Dictionary, paths: Array, db: float) -> void:
	var snd = d.get("snd", null)
	if snd == null or not is_instance_valid(snd):
		return
	var path: String = paths[randi() % paths.size()]
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	if _streams[path] == null:
		return
	(snd as AudioStreamPlayer3D).stream = _streams[path]
	(snd as AudioStreamPlayer3D).volume_db = db + randf_range(-2.0, 1.0)
	(snd as AudioStreamPlayer3D).pitch_scale = randf_range(0.92, 1.08)
	(snd as AudioStreamPlayer3D).play()


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
		if not is_instance_valid(d["pivot"]):
			gone.append(id)
			continue
		var pivot: Node3D = d["pivot"]
		var want := OPEN_DEG if _clock < float(d["open_until"]) else 0.0
		var a0 := float(d["angle"])
		var a := a0
		if want != 0.0:
			# Opening: fast, slowing as it goes; its hinges creak as it starts.
			if absf(a0) < 0.5 and not bool(d.get("quiet", false)):
				_sound(d, CREAKS, -15.0)
			d["bounced"] = false
			d["speed"] = 0.0
			a = a0 + (want - a0) * (1.0 - exp(-OPEN_EASE * step))
			if absf(want - a) < 0.5:
				a = want
		elif a0 < 0.0:
			# Shutting: faster and faster till it knocks on the frame and jumps back.
			d["speed"] = minf(float(d.get("speed", 0.0)) + 900.0 * step, SPEED_DEG * 1.6)
			a = minf(0.0, a0 + float(d["speed"]) * step)
			if a >= 0.0 and not bool(d.get("bounced", false)):
				d["bounced"] = true
				d["speed"] = 60.0
				a = REBOUND_DEG
				if not bool(d.get("quiet", false)):
					_sound(d, SHUTS, -12.0)
		if a != a0:
			d["angle"] = a
			pivot.basis = (d["base"] as Basis) * Basis(Vector3.UP, deg_to_rad(a))
			if is_instance_valid(d.get("hole", null)):
				(d["hole"] as Node3D).visible = absf(a) > 4.0
	for id in gone:
		_doors.erase(id)
