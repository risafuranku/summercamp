extends Node

## The number of every tent, cabin and caravan where you can see it in the camp: a board
## on a stake in front of a tent with the number painted on, and on a cabin or a caravan
## an enamel plate by the door (blue with a white rim and a white number, the Czech
## house-number kind). The numbers are the lodgings' own (GuestManager: T1 T2 / C1 / V1
## on the key fobs and the plan; the plate shows the number). Polled once a second, so a
## new build, an upgrade (the structure is rebuilt) or a renumbering shows by itself.
## Where the sign goes is the model's: meta "number_plate" (a local Transform3D) on
## cabins and caravans (building_models.gd), a stake in front of tents.

const FONT := preload("res://assets/fonts/silkscreen.fnt")
const POLL := 1.0
const CAMP := "res://assets/textury/camp/"
## In front of a tent, beside its door (inside the 4 m tile for every tent level).
const TENT_STAKE := Vector3(0.62, 0.0, 1.6)

var _acc := POLL
var _wood: StandardMaterial3D
var _board: StandardMaterial3D
var _enamel: StandardMaterial3D
var _rim: StandardMaterial3D


func _process(delta: float) -> void:
	_acc += delta
	if _acc < POLL or GuestManager == null:
		return
	_acc = 0.0
	var seen := {}
	for group in ["tents", "cabins", "housing"]:
		for n in get_tree().get_nodes_in_group(group):
			if n is Node3D and not seen.has(n.get_instance_id()):
				seen[n.get_instance_id()] = true
				_sync(n as Node3D)


func _sync(s: Node3D) -> void:
	var kind: String = GuestManager.lodging_kind(str(s.get_meta("building_type", "")))
	var o = s.get_meta("grid_origin", null)
	if kind.is_empty() or not (o is Vector2i):
		return
	var no: int = GuestManager.room_number("%d:%d" % [(o as Vector2i).x, (o as Vector2i).y])
	var sign := s.get_node_or_null("NumberSign") as Node3D
	if no <= 0:
		if sign != null:
			sign.visible = false
		return
	if sign == null:
		sign = _make_stake(s) if kind == "tent" else _make_plate(s)
	sign.visible = true
	if int(sign.get_meta("no", -1)) != no:
		sign.set_meta("no", no)
		var label := sign.find_child("Number", true, false) as Label3D
		if label != null:
			label.text = str(no)


## A tent's: a pine board on a stake, the number in dark paint, leaning a little.
func _make_stake(s: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "NumberSign"
	root.position = TENT_STAKE
	root.rotation = Vector3(0.0, -0.25, 0.05)
	s.add_child(root)
	_box(root, Vector3(0.06, 0.74, 0.06), Vector3(0, 0.37, 0), _wood_mat())
	_box(root, Vector3(0.46, 0.34, 0.03), Vector3(0, 0.74, 0.03), _wood_mat())
	_box(root, Vector3(0.4, 0.28, 0.032), Vector3(0, 0.74, 0.036), _board_mat())
	var label := _label(Color(0.16, 0.1, 0.06), 0.03)
	label.position = Vector3(0, 0.735, 0.054)
	root.add_child(label)
	return root


## A cabin's or a caravan's: the enamel plate by the door.
func _make_plate(s: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "NumberSign"
	var at = s.get_meta("number_plate", null)
	root.transform = at if at is Transform3D else Transform3D(Basis(), Vector3(0.8, 1.6, 1.0))
	s.add_child(root)
	_box(root, Vector3(0.36, 0.28, 0.015), Vector3(0, 0, 0), _rim_mat())
	_box(root, Vector3(0.32, 0.24, 0.02), Vector3(0, 0, 0.004), _enamel_mat())
	var label := _label(Color(0.96, 0.96, 0.92), 0.024)
	label.position = Vector3(0, -0.008, 0.016)
	root.add_child(label)
	return root


func _label(col: Color, px: float) -> Label3D:
	var l := Label3D.new()
	l.name = "Number"
	l.font = FONT
	l.font_size = 8
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	return l


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


func _tex_mat(file: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if ResourceLoader.exists(CAMP + file):
		m.albedo_texture = load(CAMP + file)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(2.0, 2.0, 2.0)
	m.albedo_color = tint
	return m


func _wood_mat() -> StandardMaterial3D:
	if _wood == null:
		_wood = _tex_mat("planks_dark.png", Color(0.8, 0.7, 0.6))
	return _wood


## The painted face of the board: plain cream, so the number reads from the path.
func _board_mat() -> StandardMaterial3D:
	if _board == null:
		_board = StandardMaterial3D.new()
		_board.albedo_color = Color(0.86, 0.8, 0.64)
		_board.roughness = 1.0
	return _board


func _enamel_mat() -> StandardMaterial3D:
	if _enamel == null:
		_enamel = StandardMaterial3D.new()
		_enamel.albedo_color = Color(0.14, 0.27, 0.6)
		_enamel.roughness = 0.4
	return _enamel


func _rim_mat() -> StandardMaterial3D:
	if _rim == null:
		_rim = StandardMaterial3D.new()
		_rim.albedo_color = Color(0.94, 0.94, 0.9)
		_rim.roughness = 0.4
	return _rim
