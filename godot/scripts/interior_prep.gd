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
var _room_key := ""
var _was_tidy: Dictionary = {}   # task id -> tidy last time


## Stepped (8 a second) shrink, then hidden; a little cloud where it was.
func _poof_out(n: Node3D) -> void:
	var rest := n.scale
	var tw := n.create_tween()
	for k in [0.8, 0.55, 0.25]:
		tw.tween_callback(func(): n.scale = rest * k)
		tw.tween_interval(0.125)
	tw.tween_callback(func():
		n.visible = false
		n.scale = rest)
	_puff(n)


## Stepped pop: small, a touch too big, settled.
func _pop_in(n: Node3D) -> void:
	var rest := n.scale
	n.visible = true
	n.scale = rest * 0.4
	var tw := n.create_tween()
	for k in [0.75, 1.12, 1.0]:
		tw.tween_interval(0.125)
		tw.tween_callback(func(): n.scale = rest * k)


func _puff(n: Node3D) -> void:
	var parent := n.get_parent() as Node3D
	if parent == null:
		return
	var at := n.position
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.78, 0.7, 0.8)
	var bits: Array[MeshInstance3D] = []
	for i in 6:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.06
		b.mesh = bm
		b.material_override = mat
		b.position = at + Vector3(randf_range(-0.12, 0.12), 0.05, randf_range(-0.12, 0.12))
		parent.add_child(b)
		bits.append(b)
	var tw := parent.create_tween()
	for f in 5:
		tw.tween_interval(0.1)
		tw.tween_callback(func():
			for b in bits:
				if is_instance_valid(b):
					b.position += Vector3(randf_range(-0.03, 0.03), 0.06, randf_range(-0.03, 0.03))
					b.scale *= 1.15
			mat.albedo_color.a = maxf(0.0, mat.albedo_color.a - 0.16))
	tw.tween_callback(func():
		for b in bits:
			if is_instance_valid(b):
				b.queue_free())


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
## A task done just now (it was untidy a moment ago, same room) is animated: the mess
## shrinks away in three steps with a puff of dust, the tidy thing pops up in three.
func set_room(room: Dictionary) -> void:
	var key := str(room.get("key", ""))
	var same_room := key == _room_key
	_room_key = key
	_rebuild_if_changed(room.get("tasks", []))
	var done: Array = room.get("done", [])
	var tidy_all := str(room.get("status", "")) == ROOM_RULES.STATUS_READY or bool(room.get("occupied", false))
	for task_id in _nodes.keys():
		var tidy := tidy_all or done.has(task_id)
		var just_now: bool = same_room and tidy and _was_tidy.get(task_id, true) == false
		_was_tidy[task_id] = tidy
		for n in _nodes[task_id]["mess"]:
			if not is_instance_valid(n):
				continue
			if just_now and n.visible:
				_poof_out(n)
			else:
				n.visible = not tidy
		for n in _nodes[task_id]["tidy"]:
			if not is_instance_valid(n):
				continue
			if just_now and not n.visible:
				_pop_in(n)
			else:
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
		# Most mess is a Build-style floor sprite from Grok (assets/textury/mess), with a
		# real 3D thing or two standing up out of it so it has depth.
		"bottles":
			decal(root, "litter_bottles", 0.56, Vector3(0, 0.004, 0), rng.randf() * TAU)
			bottle(root, Vector3(_j(rng, 0.14), 0.13, _j(rng, 0.14)), false, rng.randf() * TAU)
		"cans":
			decal(root, "litter_cans", 0.46, Vector3(0, 0.004, 0), rng.randf() * TAU)
			can(root, Vector3(_j(rng, 0.16), 0.06, _j(rng, 0.16)), false, Color(0.7, 0.12, 0.1), rng.randf() * TAU)
		"papers":
			decal(root, "litter_wrappers", 0.48, Vector3(0, 0.004, 0), rng.randf() * TAU)
		"butts":
			decal(root, "litter_butts", 0.42, Vector3(0, 0.004, 0), rng.randf() * TAU)
		"food":
			decal(root, "litter_food", 0.42, Vector3(0, 0.004, 0), rng.randf() * TAU)
		"clothes":
			decal(root, "litter_clothes", 0.56, Vector3(0, 0.004, 0), rng.randf() * TAU)
		"mud":
			decal(root, "dirt_footprints", 0.78, Vector3(0, 0.004, 0), rng.randf() * TAU)
			size = Vector3(0.7, 0.12, 0.7)
			body_pos = pos + Vector3(0, 0.04, 0)
		"sand":
			for i in 3:
				box(root, Vector3(_j(rng, 0.18), 0.005 + i * 0.001, _j(rng, 0.18)), Vector3(rng.randf_range(0.18, 0.32), 0.005, rng.randf_range(0.14, 0.26)), flat(Color(0.82, 0.72, 0.5)), Vector3(0, rng.randf() * TAU, 0))
		"vomit":
			decal(root, "dirt_vomit", 0.56, Vector3(0, 0.005, 0), rng.randf() * TAU, false, true)
		"piss":
			decal(root, "dirt_piss", 0.62, Vector3(0, 0.004, 0), rng.randf() * TAU, false, true)
			size = Vector3(0.7, 0.12, 0.7)
		"poop":
			decal(root, "dirt_poop", 0.6, Vector3(0, 0.005, 0), rng.randf() * TAU)
			size = Vector3(0.6, 0.15, 0.6)
		"wads":
			decal(root, "litter_toiletpaper", 0.46, Vector3(0, 0.004, 0), rng.randf() * TAU)
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
			decal(root, "dirt_grime", 0.34, Vector3(0, 0.012, 0), rng.randf() * TAU)
			decal(root, "dirt_grime", 0.18, Vector3(0.0, -0.16, 0.205), 0.0, true)
			decal(root, "dirt_piss", 0.5, Vector3(_j(rng, 0.08), -pos.y + 0.048, 0.36), rng.randf() * TAU, false, true)
			size = Vector3(0.6, 0.75, 0.7)
			body_pos = pos + Vector3(0, -0.2, 0.1)
		"sink_grime":
			decal(root, "dirt_grime", 0.3, Vector3(0, 0.012, 0), rng.randf() * TAU)
			box(root, Vector3(_j(rng, 0.06), 0.014, _j(rng, 0.04)), Vector3(0.1, 0.006, 0.02), flat(Color(0.08, 0.06, 0.05)), Vector3(0, rng.randf() * TAU, 0))
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
			decal(root, "litter_toiletpaper", 0.42, Vector3(0, 0.004, 0), rng.randf() * TAU)
		"shower_mould":
			# On a wall: `pos` is on the surface, the props face +Z of the root.
			decal(root, "dirt_mould", rng.randf_range(0.6, 0.8), Vector3(_j(rng, 0.15), rng.randf_range(0.2, 0.6), 0.012), 0.0, true)
			decal(root, "dirt_mould", rng.randf_range(0.3, 0.45), Vector3(_j(rng, 0.25), rng.randf_range(-0.05, 0.9), 0.014), 0.0, true)
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
			decal(root, "dirt_grime", 0.3, Vector3(0, 0.014, 0), rng.randf() * TAU)
			# The plunger left for you.
			_cylinder(root, Vector3(0.36, -pos.y + 0.34, 0.3), 0.012, 0.012, 0.6, false, flat(Color(0.55, 0.4, 0.22)), 0.0)
			_cylinder(root, Vector3(0.36, -pos.y + 0.03, 0.3), 0.05, 0.07, 0.06, false, flat(Color(0.6, 0.12, 0.1)), 0.0)
			size = Vector3(0.7, 0.8, 0.8)
			body_pos = pos + Vector3(0, -0.2, 0.15)
		"slop":
			# `pos` is the rim of the bucket: the lid off on the floor beside it, and what
			# is inside, nearly to the top.
			# (The cabin floor is 0.05 up; the spot is the rim, 0.33 above the floor.)
			var floor_y := -0.33
			_cylinder(root, Vector3(0, -0.005, 0), 0.15, 0.15, 0.006, false, _wet(Color(0.28, 0.22, 0.08, 0.95)), 0.0)
			_cylinder(root, Vector3(0.28, floor_y + 0.012, 0.06), 0.17, 0.17, 0.02, false, flat(Color(0.86, 0.84, 0.78)), 0.0)
			box(root, Vector3(_j(rng, 0.1) - 0.05, floor_y + 0.004, 0.22), Vector3(0.3, 0.006, 0.22), _wet(Color(0.3, 0.26, 0.1, 0.7)), Vector3(0, _j(rng, 0.6), 0))
			size = Vector3(0.5, 0.45, 0.5)
			body_pos = pos + Vector3(0, -0.15, 0)
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


const MESS_TEX := "res://assets/textury/mess/"
static var _decal_mats: Dictionary = {}


## A floor sprite of mess (Build-engine style flat sprite): `file` in assets/textury/mess,
## `width` metres across, lying on the floor (or on a wall facing +Z: `vertical`). Wet
## ones (sick, piss) catch a little light. Its hover look is the same picture glowing
## (meta "hl_material", swapped in by interior_tasks), not a box round it.
static func decal(parent: Node3D, file: String, width: float, pos: Vector3, yaw := 0.0, vertical := false, wet := false) -> MeshInstance3D:
	var path := MESS_TEX + file + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var mi := MeshInstance3D.new()
	mi.name = "Decal_" + file
	var q := QuadMesh.new()
	var aspect := float(tex.get_height()) / float(tex.get_width()) if tex != null else 1.0
	q.size = Vector2(width, width * aspect)
	if not vertical:
		q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var key := "%s|%s" % [file, wet]
	if not _decal_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.25 if wet else 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX if wet else BaseMaterial3D.SPECULAR_DISABLED
		var hl := m.duplicate() as StandardMaterial3D
		hl.emission_enabled = true
		hl.emission = Color(1.0, 0.85, 0.5)
		hl.emission_energy_multiplier = 0.35
		hl.emission_texture = tex
		_decal_mats[key] = [m, hl]
	mi.material_override = _decal_mats[key][0]
	mi.set_meta("hl_material", _decal_mats[key][1])
	mi.set_meta("base_material", _decal_mats[key][0])
	# Room floors sit at 0.05 with rugs just above; the spots are given at 0.04.
	mi.position = pos + (Vector3.ZERO if vertical else Vector3(0, 0.022, 0))
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


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
