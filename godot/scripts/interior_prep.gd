extends RefCounted

## Room preparation for one interior (tent, cabin): which props are the mess and which
## the tidy version of each task, the collision bodies the cursor finds them by, and
## the InteriorTasks overlay that does the hovering and holding.
##
## The interior builds its props with the helpers here, registers them per task, then
## calls `setup_tasks()`. InteriorManager feeds `set_room()` with
## GuestManager.get_room_state(key) and listens to `task_completed`.

signal task_completed(task_id: String)

const INTERIOR_TASKS = preload("res://scripts/interior_tasks.gd")
const ROOM_RULES = preload("res://core/systems/room_rules.gd")
const CAMP_TEX := "res://assets/textury/camp/"

var tasks
var _nodes: Dictionary = {}   # task id -> {body, mess: [Node3D], tidy: [Node3D]}


func register(task_id: String, body: StaticBody3D, mess: Array, tidy: Array) -> void:
	_nodes[task_id] = {"body": body, "mess": mess, "tidy": tidy}


## Creates the overlay on `host` (the interior's CanvasLayer) for the rules of `kind`.
func setup_tasks(host: Node, camera: Camera3D, viewport: SubViewport, kind: String) -> void:
	tasks = INTERIOR_TASKS.new()
	host.add_child(tasks)
	tasks.setup(camera, viewport)
	tasks.task_completed.connect(func(id: String): task_completed.emit(id))
	for t in ROOM_RULES.TASKS.get(kind, []):
		var id := str(t["id"])
		if not _nodes.has(id):
			continue
		var meshes: Array = []
		for n in _nodes[id]["mess"]:
			_collect_meshes(n, meshes)
		tasks.add_target(t, _nodes[id]["body"], meshes)


## Undone tasks show their mess; done ones (or a ready / occupied room) the tidy props.
func set_room(room: Dictionary) -> void:
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
