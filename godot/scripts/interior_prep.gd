extends RefCounted

## Room preparation for one interior (tent, cabin, toilet / shower block): which props
## are the mess and which the tidy version of each task, the collision bodies the
## cursor finds them by, and the InteriorTasks overlay that does the hovering and holding.
##
## The bed is registered once with its messy and tidy props. Everything else is the
## mess of the day (core/systems/mess_rules.gd): the interior registers named spots
## (`add_spot`), and each time the room's list changes the props for that list are
## built at those spots (`build_mess`), so the bottles are somewhere else every time.
##
## InteriorManager feeds `set_room()` with GuestManager.get_room_state(key) and listens
## to `task_completed`.

signal task_completed(task_id: String)

const INTERIOR_TASKS = preload("res://scripts/interior_tasks.gd")
const ROOM_RULES = preload("res://core/systems/room_rules.gd")
const CAMP_TEX := "res://assets/textury/camp/"

var tasks
var _nodes: Dictionary = {}   # task id -> {body, mess: [Node3D], tidy: [Node3D]}
var _spots: Dictionary = {}   # spot id -> {parent, pos, yaw, vertical}
var _built: Array = []        # nodes built for the current mess
var _signature := ""


func register(task_id: String, body: StaticBody3D, mess: Array, tidy: Array) -> void:
	_nodes[task_id] = {"body": body, "mess": mess, "tidy": tidy}


## A place the mess can be: on the floor (`vertical` false: props lie at `pos`) or on a
## wall facing `yaw` (stains, writing).
func add_spot(spot_id: String, parent: Node3D, pos: Vector3, yaw: float = 0.0, vertical: bool = false) -> void:
	_spots[spot_id] = {"parent": parent, "pos": pos, "yaw": yaw, "vertical": vertical}


## Creates the overlay on `host` (the interior's CanvasLayer). Targets follow the room.
func setup_tasks(host: Node, camera: Camera3D, viewport: SubViewport, _kind: String = "") -> void:
	tasks = INTERIOR_TASKS.new()
	host.add_child(tasks)
	tasks.setup(camera, viewport)
	tasks.task_completed.connect(func(id: String): task_completed.emit(id))


## Undone tasks show their mess; done ones (or a ready / occupied room) the tidy props.
func set_room(room: Dictionary) -> void:
	_rebuild_if_changed(room.get("tasks", []))
	var done: Array = room.get("done", [])
	var tidy_all := str(room.get("status", "")) == ROOM_RULES.STATUS_READY or bool(room.get("occupied", false))
	for task_id in _nodes.keys():
		var tidy := tidy_all or done.has(task_id)
		for n in _nodes[task_id]["mess"]:
			if is_instance_valid(n):
				n.visible = not tidy
		for n in _nodes[task_id]["tidy"]:
			if is_instance_valid(n):
				n.visible = tidy
	if tasks != null:
		tasks.set_room(room)


func _rebuild_if_changed(list: Array) -> void:
	var sig := ",".join(list.map(func(t): return "%s:%s" % [t.get("id", ""), t.get("mess", "")]))
	if sig == _signature and tasks != null and not list.is_empty():
		return
	_signature = sig
	for n in _built:
		if is_instance_valid(n):
			n.queue_free()
	_built.clear()
	for id in _nodes.keys():
		if _nodes[id].get("dynamic", false):
			_nodes.erase(id)
	if tasks != null:
		tasks.clear_targets()
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = sig.hash()
	for t in list:
		var id := str(t.get("id", ""))
		if _nodes.has(id) and not _nodes[id].get("dynamic", false):
			if tasks != null:
				var meshes: Array = []
				for n in _nodes[id]["mess"]:
					_collect_meshes(n, meshes)
				tasks.add_target(t, _nodes[id]["body"], meshes)
			continue
		var spot: Dictionary = _spots.get(str(t.get("spot", id)), {})
		if spot.is_empty():
			continue
		var built := build_mess(spot["parent"], spot["pos"], str(t.get("mess", "papers")), seed_rng, float(spot["yaw"]), bool(spot["vertical"]))
		var root: Node3D = built["root"]
		var b: StaticBody3D = built["body"]
		_built.append(root)
		_built.append(b)
		_nodes[id] = {"body": b, "mess": [root], "tidy": [], "dynamic": true}
		if tasks != null:
			var meshes2: Array = []
			_collect_meshes(root, meshes2)
			tasks.add_target(t, b, meshes2)


func is_busy() -> bool:
	return tasks != null and tasks.is_busy()


func play_room_ready() -> void:
	if tasks != null:
		tasks.play_room_ready()


func _collect_meshes(n: Node, out: Array) -> void:
	if n == null:
		return
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


# ── the mess, by kind ─────────────────────────────────────────────────────────

## Things written on toilet doors. Mostly what you would expect; some not.
const DOOR_WRITING := [
	"PEPA WAS HERE 94", "SPARTA PRAHA", "KAREL + JANA", "NO PAPER AGAIN",
	"DONT DRINK THE TAP", "COUNT THE KIDS", "HE WHISTLES AT NIGHT", "VERA KNOWS",
	"WHO LOCKED STALL 3", "TRAMP SE NEVZDAVA", "AHOJ", "STAND STILL WHEN IT PASSES",
]


## Builds the props for one mess `kind` at `pos` under `parent`, plus the body the
## cursor finds it by. {root: Node3D, body: StaticBody3D}
static func build_mess(parent: Node3D, pos: Vector3, kind: String, rng: RandomNumberGenerator, yaw := 0.0, vertical := false) -> Dictionary:
	var root := Node3D.new()
	root.name = "Mess_%s" % kind
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var size := Vector3(0.5, 0.22, 0.5)
	var body_pos := pos + Vector3(0, size.y * 0.5 - 0.02, 0)
	match kind:
		"bottles":
			for i in rng.randi_range(2, 4):
				bottle(root, Vector3(_j(rng, 0.2), 0.0 if i % 2 else 0.13, _j(rng, 0.2)), i % 2 == 1, rng.randf() * TAU)
		"cans":
			var cols := [Color(0.7, 0.12, 0.1), Color(0.75, 0.72, 0.68), Color(0.15, 0.35, 0.7), Color(0.85, 0.7, 0.2)]
			for i in rng.randi_range(3, 5):
				can(root, Vector3(_j(rng, 0.22), 0.035, _j(rng, 0.22)), rng.randf() < 0.7, cols[i % cols.size()], rng.randf() * TAU)
		"papers":
			for i in rng.randi_range(3, 5):
				paper(root, Vector3(_j(rng, 0.22), 0.03, _j(rng, 0.22)), rng.randf() * TAU)
		"butts":
			box(root, Vector3(0, 0.006, 0), Vector3(0.36, 0.006, 0.3), flat(Color(0.5, 0.48, 0.45)), Vector3(0, _j(rng, 1.0), 0))
			for i in rng.randi_range(6, 10):
				_cylinder(root, Vector3(_j(rng, 0.16), 0.012, _j(rng, 0.14)), 0.007, 0.007, 0.045, true, flat(Color(0.9, 0.86, 0.74) if i % 3 else Color(0.8, 0.5, 0.2)), rng.randf() * TAU)
		"food":
			_cylinder(root, Vector3(0, 0.012, 0), 0.13, 0.11, 0.025, false, flat(Color(0.88, 0.86, 0.8)), 0.0)
			box(root, Vector3(_j(rng, 0.02), 0.03, _j(rng, 0.02)), Vector3(0.14, 0.03, 0.12), flat(Color(0.42, 0.22, 0.1)), Vector3(0, _j(rng, 1.0), 0))
			box(root, Vector3(0.16, 0.012, 0.05), Vector3(0.02, 0.01, 0.16), flat(Color(0.7, 0.7, 0.72)), Vector3(0, _j(rng, 1.0), 0))
			box(root, Vector3(-0.18, 0.004, 0.12), Vector3(0.12, 0.004, 0.09), flat(Color(0.38, 0.2, 0.08)), Vector3(0, _j(rng, 1.0), 0))
		"clothes":
			var shirt := [Color(0.2, 0.3, 0.6), Color(0.7, 0.2, 0.2), Color(0.85, 0.85, 0.8)]
			box(root, Vector3(0, 0.02, 0), Vector3(0.42, 0.03, 0.34), flat(shirt[rng.randi_range(0, 2)]), Vector3(_j(rng, 0.1), _j(rng, 1.2), _j(rng, 0.1)))
			box(root, Vector3(0.22, 0.02, 0.16), Vector3(0.08, 0.03, 0.22), flat(Color(0.9, 0.9, 0.86)), Vector3(0, _j(rng, 1.0), 0))
			box(root, Vector3(0.28, 0.02, 0.05), Vector3(0.08, 0.03, 0.2), flat(Color(0.88, 0.88, 0.84)), Vector3(0, _j(rng, 1.0), 0))
		"mud":
			var a := rng.randf() * TAU
			for i in 4:
				var p := Vector3(cos(a), 0, sin(a)) * (float(i) * 0.16 - 0.24) + Vector3(0.05 * (1 if i % 2 else -1), 0.006, 0)
				box(root, p, Vector3(0.09, 0.006, 0.2), flat(Color(0.42, 0.3, 0.16)), Vector3(0, -a + PI * 0.5, 0))
			size = Vector3(0.7, 0.12, 0.7)
			body_pos = pos + Vector3(0, 0.04, 0)
		"sand":
			for i in 3:
				box(root, Vector3(_j(rng, 0.18), 0.005 + i * 0.001, _j(rng, 0.18)), Vector3(rng.randf_range(0.18, 0.32), 0.005, rng.randf_range(0.14, 0.26)), flat(Color(0.82, 0.72, 0.5)), Vector3(0, rng.randf() * TAU, 0))
		"vomit":
			for i in 3:
				box(root, Vector3(_j(rng, 0.12), 0.006 + i * 0.002, _j(rng, 0.12)), Vector3(rng.randf_range(0.14, 0.26), 0.008, rng.randf_range(0.12, 0.22)), flat(Color(0.6, 0.58, 0.28)), Vector3(0, rng.randf() * TAU, 0))
		"mushrooms":
			box(root, Vector3(0, 0.004, 0), Vector3(0.36, 0.004, 0.28), flat(Color(0.8, 0.78, 0.7)), Vector3(0, _j(rng, 0.6), 0))
			for i in rng.randi_range(4, 6):
				var mp := Vector3(_j(rng, 0.13), 0.02, _j(rng, 0.11))
				var rotten := rng.randf() < 0.5
				_cylinder(root, mp, 0.012, 0.016, 0.04, true, flat(Color(0.85, 0.8, 0.7)), rng.randf() * TAU)
				box(root, mp + Vector3(0.03, 0.02, 0), Vector3(0.06, 0.03, 0.06), flat(Color(0.22, 0.2, 0.12) if rotten else Color(0.5, 0.3, 0.14)), Vector3(0, rng.randf() * TAU, 0.3))
		"toys":
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.14
			sm.radial_segments = 8
			sm.rings = 4
			ball.mesh = sm
			ball.position = Vector3(_j(rng, 0.15), 0.07, _j(rng, 0.15))
			ball.material_override = flat(Color(0.85, 0.15, 0.12))
			root.add_child(ball)
			box(root, Vector3(_j(rng, 0.15), 0.03, _j(rng, 0.15)), Vector3(0.12, 0.05, 0.06), flat(Color(0.2, 0.5, 0.85)), Vector3(0, rng.randf() * TAU, 0))
			# A teddy bear, face down.
			var bear := Vector3(_j(rng, 0.12), 0.05, _j(rng, 0.12))
			box(root, bear, Vector3(0.12, 0.08, 0.16), flat(Color(0.5, 0.34, 0.2)), Vector3(0, 0.4, 0))
			box(root, bear + Vector3(0.05, 0.0, 0.11), Vector3(0.09, 0.07, 0.08), flat(Color(0.5, 0.34, 0.2)), Vector3(0, 0.4, 0))
		"ash":
			box(root, Vector3(0, 0.006, 0), Vector3(0.34, 0.006, 0.3), flat(Color(0.24, 0.23, 0.22)), Vector3(0, _j(rng, 1.0), 0))
			box(root, Vector3(_j(rng, 0.06), 0.02, _j(rng, 0.06)), Vector3(0.3, 0.03, 0.03), flat(Color(0.12, 0.1, 0.08)), Vector3(0, rng.randf() * TAU, 0))
			for i in 3:
				_cylinder(root, Vector3(_j(rng, 0.2), 0.01, _j(rng, 0.2)), 0.006, 0.006, 0.18, true, flat(Color(0.6, 0.6, 0.62)), rng.randf() * TAU)
		"sawdust":
			for i in 3:
				box(root, Vector3(_j(rng, 0.16), 0.005, _j(rng, 0.16)), Vector3(rng.randf_range(0.16, 0.3), 0.006, rng.randf_range(0.12, 0.22)), flat(Color(0.86, 0.74, 0.5)), Vector3(0, rng.randf() * TAU, 0))
			for i in 2:
				box(root, Vector3(_j(rng, 0.2), 0.02, _j(rng, 0.2)), Vector3(0.22, 0.03, 0.06), flat(Color(0.62, 0.46, 0.28)), Vector3(0, rng.randf() * TAU, 0))
		"toilet_grime":
			# `pos` is the top of the bowl; the stain runs down its front onto the floor.
			var dirt := flat(Color(0.3, 0.22, 0.1))
			box(root, Vector3(0, 0.0, 0), Vector3(0.36, 0.02, 0.36), dirt, Vector3(0, _j(rng, 0.4), 0))
			box(root, Vector3(0.0, -0.14, 0.2), Vector3(0.26, 0.16, 0.02), dirt)
			box(root, Vector3(_j(rng, 0.1), -pos.y + 0.006, 0.32), Vector3(0.4, 0.008, 0.3), flat(Color(0.34, 0.3, 0.14)), Vector3(0, _j(rng, 0.6), 0))
			size = Vector3(0.6, 0.75, 0.7)
			body_pos = pos + Vector3(0, -0.2, 0.1)
		"sink_grime":
			box(root, Vector3(0, 0.0, 0), Vector3(0.34, 0.02, 0.22), flat(Color(0.4, 0.42, 0.3)))
			box(root, Vector3(_j(rng, 0.06), 0.012, _j(rng, 0.04)), Vector3(0.1, 0.006, 0.02), flat(Color(0.08, 0.06, 0.05)), Vector3(0, rng.randf() * TAU, 0))
			size = Vector3(0.5, 0.3, 0.4)
			body_pos = pos
		"hair":
			box(root, Vector3(0, 0.004, 0), Vector3(0.2, 0.004, 0.2), flat(Color(0.25, 0.27, 0.28)))
			for i in 7:
				box(root, Vector3(_j(rng, 0.05), 0.01 + i * 0.002, _j(rng, 0.05)), Vector3(0.12, 0.006, 0.008), flat(Color(0.07, 0.05, 0.04)), Vector3(0, rng.randf() * TAU, _j(rng, 0.3)))
			size = Vector3(0.4, 0.15, 0.4)
		"puddle":
			for i in 3:
				box(root, Vector3(_j(rng, 0.2), 0.004 + i * 0.001, _j(rng, 0.2)), Vector3(rng.randf_range(0.24, 0.42), 0.004, rng.randf_range(0.2, 0.36)), _wet(Color(0.18, 0.24, 0.28, 0.6)), Vector3(0, rng.randf() * TAU, 0))
			size = Vector3(0.7, 0.12, 0.7)
			body_pos = pos + Vector3(0, 0.04, 0)
		"paper_out":
			_cylinder(root, Vector3(_j(rng, 0.1), 0.03, _j(rng, 0.1)), 0.03, 0.03, 0.1, true, flat(Color(0.62, 0.5, 0.34)), rng.randf() * TAU)
			for i in 3:
				paper(root, Vector3(_j(rng, 0.2), 0.02, _j(rng, 0.2)), rng.randf() * TAU)
		"shower_mould":
			# On a wall: `pos` is on the surface, the props face +Z of the root.
			for i in rng.randi_range(4, 7):
				box(root, Vector3(_j(rng, 0.3), rng.randf_range(-0.1, 0.9), 0.01), Vector3(rng.randf_range(0.06, 0.2), rng.randf_range(0.04, 0.16), 0.008), flat(Color(0.1, 0.16, 0.1)))
			size = Vector3(0.8, 1.2, 0.2)
			body_pos = pos + Vector3(0, 0.4, 0)
		"graffiti":
			var lbl := Label3D.new()
			lbl.text = str(DOOR_WRITING[rng.randi_range(0, DOOR_WRITING.size() - 1)])
			lbl.font_size = 22
			lbl.pixel_size = 0.004
			lbl.outline_size = 0
			lbl.modulate = Color(0.08, 0.06, 0.06, 0.92) if rng.randf() < 0.7 else Color(0.5, 0.06, 0.04, 0.9)
			lbl.position = Vector3(0, 0, 0.012)
			lbl.rotation.z = _j(rng, 0.15)
			lbl.width = 140
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			root.add_child(lbl)
			# A scribble under it, so the highlight has something to light.
			box(root, Vector3(0, -0.12, 0.006), Vector3(0.36, 0.02, 0.004), flat(Color(0.12, 0.1, 0.1)), Vector3(0, 0, _j(rng, 0.3)))
			size = Vector3(0.6, 0.6, 0.1)
			body_pos = pos
		"blocked":
			# `pos` is the top of the bowl, like toilet_grime.
			box(root, Vector3(0, 0.0, 0), Vector3(0.38, 0.02, 0.4), _wet(Color(0.32, 0.26, 0.12, 0.85)))
			box(root, Vector3(0, -pos.y + 0.006, 0.36), Vector3(0.5, 0.006, 0.5), _wet(Color(0.32, 0.26, 0.12, 0.7)))
			# The plunger left for you.
			_cylinder(root, Vector3(0.36, -pos.y + 0.34, 0.3), 0.012, 0.012, 0.6, false, flat(Color(0.55, 0.4, 0.22)), 0.0)
			_cylinder(root, Vector3(0.36, -pos.y + 0.03, 0.3), 0.05, 0.07, 0.06, false, flat(Color(0.6, 0.12, 0.1)), 0.0)
			size = Vector3(0.7, 0.8, 0.8)
			body_pos = pos + Vector3(0, -0.2, 0.15)
		"showerhead":
			_cylinder(root, Vector3(0.1, 0.03, 0.1), 0.05, 0.07, 0.05, true, flat(Color(0.7, 0.74, 0.8)), 0.6)
			box(root, Vector3(0, 0.004, 0), Vector3(0.5, 0.004, 0.44), _wet(Color(0.2, 0.26, 0.3, 0.6)))
			size = Vector3(0.7, 0.3, 0.7)
		_:
			paper(root, Vector3.ZERO, 0.0)
	var b := StaticBody3D.new()
	b.name = "MessBody_%s" % kind
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	b.add_child(shape)
	b.position = body_pos
	b.rotation.y = yaw
	parent.add_child(b)
	return {"root": root, "body": b}


static func _j(rng: RandomNumberGenerator, r: float) -> float:
	return rng.randf_range(-r, r)


static func _wet(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	return m


# ── prop helpers ──────────────────────────────────────────────────────────────

static func body(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	b.position = pos
	b.add_child(shape)
	parent.add_child(b)
	return b


static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	parent.add_child(m)
	return m


static func can(parent: Node3D, pos: Vector3, lying: bool, color: Color, yaw := 0.0) -> MeshInstance3D:
	return _cylinder(parent, pos, 0.032, 0.032, 0.12, lying, flat(color), yaw)


static func bottle(parent: Node3D, pos: Vector3, lying: bool, yaw := 0.0) -> MeshInstance3D:
	return _cylinder(parent, pos, 0.018, 0.038, 0.26, lying, flat(Color(0.22, 0.34, 0.16)), yaw)


static func paper(parent: Node3D, pos: Vector3, yaw := 0.0) -> MeshInstance3D:
	return box(parent, pos, Vector3(0.07, 0.05, 0.06), flat(Color(0.86, 0.84, 0.76)), Vector3(0.6, yaw, 0.3))


static func _cylinder(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, lying: bool, mat: Material, yaw: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = height
	cyl.radial_segments = 8
	m.mesh = cyl
	m.position = pos + (Vector3(0, -height * 0.5 + bottom, 0) if lying else Vector3.ZERO)
	if lying:
		m.rotation = Vector3(0, yaw, PI * 0.5)
	m.material_override = mat
	parent.add_child(m)
	return m


static func flat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


static func camp_material(file: String, tint: Color = Color(1, 1, 1), uv := Vector3.ONE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	mat.uv1_scale = uv
	if ResourceLoader.exists(CAMP_TEX + file):
		mat.albedo_texture = load(CAMP_TEX + file)
	mat.albedo_color = tint
	return mat
