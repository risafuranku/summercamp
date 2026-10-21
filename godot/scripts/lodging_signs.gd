extends Node

## The number of every tent, cabin and caravan where you can see it in the camp: a board
## on a stake in front of a tent with the number painted on, and on a cabin or a caravan
## an enamel plate by the door (blue with a white rim and a white number, the Czech
## house-number kind). The numbers are the lodgings' own (GuestManager: T1 T2 / C1 / V1
## on the key fobs and the plan; the plate shows the number). Polled once a second, so a
## new build, an upgrade (the structure is rebuilt) or a renumbering shows by itself.
## Where the sign goes is the model's: meta "number_plate" (a local Transform3D) on
## cabins and caravans (building_models.gd), a stake in front of tents.
## Over an empty room that wants doing, a marker floats like the upkeep's warning
## triangles (Grok world/sign_clean.png, a broom: to clean; world/sign_bed.png, the linen:
## to make up), bobbing in steps, so you see from outside which ones need you without
## the map (the user 20. 10.). None over a ready or a taken room.

const FONT := preload("res://assets/fonts/silkscreen.fnt")
const POLL := 1.0
const CAMP := "res://assets/textury/camp/"
## In front of a tent, beside its door (inside the 4 m tile for every tent level).
const TENT_STAKE := Vector3(0.62, 0.0, 1.6)
const SIGN_CLEAN := "res://assets/textury/world/sign_clean.png"
const SIGN_BED := "res://assets/textury/world/sign_bed.png"
## The marker's size (20 px pictures: about 0.7 m, near the upkeep triangle's) and how far over the roof.
const SIGN_PX := 0.034
## (Lower from 21. 10.: they floated too high over the roofs.)
const SIGN_OVER := 0.4

var _acc := POLL
var _wood: StandardMaterial3D
var _board: StandardMaterial3D
var _enamel: StandardMaterial3D
var _rim: StandardMaterial3D
var _sign_tex: Dictionary = {}   # "dirty" / "unprepared" -> Texture2D
var _bob_t := 0.0
var _markers: Array = []         # Sprite3D, for the bob


func _process(delta: float) -> void:
	_bob(delta)
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
	var key := "%d:%d" % [(o as Vector2i).x, (o as Vector2i).y]
	_sync_marker(s, key)
	var no: int = GuestManager.room_number(key)
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


## The marker over a room that wants doing (empty and dirty, or not made up).
func _sync_marker(s: Node3D, key: String) -> void:
	var rs: Dictionary = GuestManager.get_room_state(key)
	var want := ""
	if not rs.is_empty() and not bool(rs.get("occupied", false)):
		var st := str(rs.get("status", ""))
		if st == "dirty" or st == "unprepared":
			want = st
	var m := s.get_node_or_null("RoomMarker") as Sprite3D
	if want == "":
		if m != null:
			m.visible = false
		return
	var tex := _marker_tex(want)
	if tex == null:
		return
	if m == null:
		m = Sprite3D.new()
		m.name = "RoomMarker"
		m.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		m.shaded = false
		m.pixel_size = SIGN_PX
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.add_child(m)
		_markers.append(m)
	# Over the roof, in the middle of the footprint (higher if the upkeep's warning is
	# there for the same building, so they do not cover each other).
	var top := _top_of(s)
	var st2 = CoreRoot.get_state() if CoreRoot != null else null
	var warned: bool = st2 != null and st2.failures.has(key)
	m.set_meta("base", s.to_local(Vector3(top.x, top.y + SIGN_OVER + (0.95 if warned else 0.0), top.z)))
	m.texture = tex
	m.visible = true


func _marker_tex(kind: String) -> Texture2D:
	if not _sign_tex.has(kind):
		var path := SIGN_CLEAN if kind == "dirty" else SIGN_BED
		_sign_tex[kind] = load(path) if ResourceLoader.exists(path) else null
	return _sign_tex[kind]


## The top middle of the building (its meshes' box; not the markers' own sprites, nor
## the thin things over the roof, an aerial or a chimney, which lifted the marker high).
func _top_of(s: Node3D) -> Vector3:
	var out := AABB()
	var first := true
	var stack: Array = [s]
	while not stack.is_empty():
		var n = stack.pop_back()
		var vi := n as VisualInstance3D
		if vi != null and not (vi is Sprite3D) and not (vi is Label3D):
			var box: AABB = vi.global_transform * vi.get_aabb()
			if box.size.x > 0.6 or box.size.z > 0.6:
				out = box if first else out.merge(box)
				first = false
		for c in n.get_children():
			if c.name != "NumberSign":
				stack.append(c)
	if first:
		return s.global_position + Vector3(0, 2.5, 0)
	return Vector3(out.get_center().x, out.end.y, out.get_center().z)


## Up and down a hand's breadth, in steps, like the rest of the Build sprites.
func _bob(delta: float) -> void:
	_bob_t += delta
	var y := floorf(sin(_bob_t * 2.2) * 3.0) / 3.0 * 0.06
	for i in range(_markers.size() - 1, -1, -1):
		# A demolished lodging's marker is freed: checked before the typed assignment.
		if not is_instance_valid(_markers[i]):
			_markers.remove_at(i)
			continue
		var m: Sprite3D = _markers[i]
		if m.visible:
			m.position = (m.get_meta("base", Vector3.ZERO) as Vector3) + Vector3(0, y, 0)


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
