extends Node3D

## The way into the camp: a gravel road out of the forest, a gap in the south fence
## beside the reception, a wooden gatehouse (vratnice) and a striped boom barrier.
##
## Booked guests arrive by the road and wait outside the barrier (guest_agents.gd puts
## them at `waiting_spot(i)`); when GuestManager lets a party in, the barrier goes up
## for a few seconds and comes down behind them. The player cannot leave the camp this
## way: an invisible wall stands in the gap.
##
## Built by world_generator.gd. Everything here is generated geometry with the
## camp textures (assets/textury/camp/), falling back to the old texture set.

const TEX_DIR := "res://assets/textury/camp/"
const SFX_LIFT := "res://assets/sfx/gate/barrier_lift.mp3"
const SFX_DROP := "res://assets/sfx/gate/barrier_drop.mp3"
const SFX_CAR := "res://assets/sfx/gate/car_arrive.mp3"
const SFX_HELLO := "res://assets/sfx/gate/gate_hello.mp3"

const ROAD_LENGTH := 120.0
const ROAD_WIDTH := 4.4
const ARM_LENGTH := 4.3
const ARM_HEIGHT := 1.0
const OPEN_DEG := 82.0
const OPEN_HOLD_SEC := 6.0

var gap_center_x: float = 0.0
var fence_z: float = 0.0
var _arm_pivot: Node3D
var _arm_tween: Tween
var _close_timer: SceneTreeTimer
var _booth_light: OmniLight3D
var _texture_style
var _is_open := false


## `gate_world`: the centre of the gate tile; `fence_z_world`: the south fence line.
func build(gate_world: Vector3, fence_z_world: float, texture_style) -> void:
	_texture_style = texture_style
	gap_center_x = gate_world.x
	fence_z = fence_z_world
	name = "CampGate"
	_build_road()
	_build_barrier()
	_build_booth()
	_build_sign()
	_build_player_block()
	if EventBus.has_signal("guest_checked_in"):
		EventBus.guest_checked_in.connect(func(_g): open_briefly())
	if EventBus.has_signal("guest_at_gate"):
		EventBus.guest_at_gate.connect(func(_g): _on_guest_at_gate())


## Where the i-th waiting party stands: on the road, outside the barrier, in a line.
func waiting_spot(i: int) -> Vector3:
	return Vector3(gap_center_x + (0.6 if i % 2 == 0 else -0.6), 0.0, fence_z - 3.2 - float(i) * 1.7)


func set_night(night: bool) -> void:
	if _booth_light != null:
		_booth_light.visible = night


func open_briefly() -> void:
	if not _is_open:
		_is_open = true
		_swing(OPEN_DEG, 1.6)
		_sound(SFX_LIFT, _arm_pivot.global_position, -2.0)
	_close_timer = get_tree().create_timer(OPEN_HOLD_SEC)
	var timer := _close_timer
	timer.timeout.connect(func():
		if timer != _close_timer or not is_inside_tree():
			return
		_is_open = false
		_swing(0.0, 1.1)
		_sound(SFX_DROP, _arm_pivot.global_position, -2.0)
	)


func _on_guest_at_gate() -> void:
	_sound(SFX_CAR, Vector3(gap_center_x, 0.5, fence_z - 22.0), 0.0, 60.0)
	get_tree().create_timer(5.5).timeout.connect(func():
		if is_inside_tree():
			_sound(SFX_HELLO, waiting_spot(0) + Vector3(0, 1.6, 0), -3.0, 45.0)
	)


func _swing(deg: float, seconds: float) -> void:
	if _arm_tween != null and _arm_tween.is_valid():
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arm_tween.tween_property(_arm_pivot, "rotation:z", deg_to_rad(-deg), seconds)


# ── geometry ──────────────────────────────────────────────────────────────────

func _build_road() -> void:
	# Two straight stretches with a slight bend, so the road disappears into the trees.
	var mat := _material("gravel_road.png", "road", Color(0.62, 0.58, 0.5))
	var a := Vector3(gap_center_x, 0.03, fence_z + 1.0)
	var b := Vector3(gap_center_x + 2.0, 0.03, fence_z - 45.0)
	var c := Vector3(gap_center_x + 14.0, 0.03, fence_z - ROAD_LENGTH)
	_road_segment(a, b, mat)
	_road_segment(b, c, mat)
	# The verge: darker trodden ground either side of the gate.
	var verge_mat := _material("gravel_road.png", "road", Color(0.42, 0.40, 0.34))
	var verge := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ROAD_WIDTH * 3.2, 9.0)
	verge.mesh = plane
	verge.position = Vector3(gap_center_x, 0.02, fence_z - 3.0)
	verge.material_override = verge_mat
	add_child(verge)


func _road_segment(from: Vector3, to: Vector3, mat: Material) -> void:
	# Solid under the road, so anything placed on it (a parked car, a tool) stands.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROAD_WIDTH + 6.0, 1.0, from.distance_to(to) + 1.0)
	shape.shape = box
	body.position = (from + to) * 0.5 + Vector3(0, -0.5, 0)
	body.rotation.y = atan2(to.x - from.x, to.z - from.z)
	body.add_child(shape)
	add_child(body)
	var seg := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var length := from.distance_to(to)
	plane.size = Vector2(ROAD_WIDTH, length + 1.0)
	seg.mesh = plane
	seg.position = (from + to) * 0.5
	seg.rotation.y = atan2(to.x - from.x, to.z - from.z)
	var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(1.0, length / ROAD_WIDTH, 1.0)
	seg.material_override = m
	seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seg)


func _build_barrier() -> void:
	var post_x := gap_center_x - 2.25
	var post_mat := _paint(Color(0.18, 0.2, 0.18))
	_box(Vector3(post_x, 0.55, fence_z), Vector3(0.28, 1.1, 0.28), post_mat)
	# Counterweight box behind the pivot, like the real ones.
	_box(Vector3(post_x - 0.45, ARM_HEIGHT, fence_z), Vector3(0.55, 0.32, 0.3), _paint(Color(0.3, 0.3, 0.28)))
	_box(Vector3(gap_center_x + 2.3, 0.4, fence_z), Vector3(0.18, 0.8, 0.18), post_mat)
	_box(Vector3(gap_center_x + 2.3, 0.82, fence_z), Vector3(0.3, 0.06, 0.24), post_mat)
	_arm_pivot = Node3D.new()
	_arm_pivot.name = "BarrierPivot"
	_arm_pivot.position = Vector3(post_x, ARM_HEIGHT, fence_z)
	add_child(_arm_pivot)
	var arm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(ARM_LENGTH, 0.12, 0.1)
	arm.mesh = box
	arm.position = Vector3(ARM_LENGTH * 0.5, 0.0, 0.0)
	var stripes := StandardMaterial3D.new()
	stripes.albedo_texture = _stripe_texture()
	stripes.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stripes.uv1_scale = Vector3(1.0, 1.0, 1.0)
	stripes.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	arm.material_override = stripes
	_arm_pivot.add_child(arm)


func _build_booth() -> void:
	# A 2.2 x 2.2 m plank hut on the east side of the road, its window on the road.
	var x := gap_center_x + 4.4
	var z := fence_z - 1.8
	var root := Node3D.new()
	root.name = "Gatehouse"
	root.position = Vector3(x, 0.0, z)
	add_child(root)
	var walls := _material("planks_grey.png", "wood", Color(0.6, 0.58, 0.52))
	var w := 2.2
	var h := 2.3
	var t := 0.1
	_box_in(root, Vector3(0, h * 0.5, -w * 0.5), Vector3(w, h, t), walls)
	_box_in(root, Vector3(w * 0.5, h * 0.5, 0), Vector3(t, h, w), walls)
	# Road side: wall under and over a wide window.
	_box_in(root, Vector3(-w * 0.5, 0.5, 0), Vector3(t, 1.0, w), walls)
	_box_in(root, Vector3(-w * 0.5, h - 0.25, 0), Vector3(t, 0.5, w), walls)
	_box_in(root, Vector3(-w * 0.5, 1.4, 0.95), Vector3(t, 0.8, 0.3), walls)
	_box_in(root, Vector3(-w * 0.5, 1.4, -0.95), Vector3(t, 0.8, 0.3), walls)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.12, 0.14, 0.13, 0.75)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_box_in(root, Vector3(-w * 0.5, 1.4, 0), Vector3(0.03, 0.8, 1.6), glass)
	# Front (camp side) with a door.
	var door := _material("door_wood.png", "wood", Color(0.45, 0.32, 0.22))
	_box_in(root, Vector3(-0.55, h * 0.5, w * 0.5), Vector3(1.1, h, t), walls)
	_box_in(root, Vector3(0.55, 1.0, w * 0.5), Vector3(0.9, 2.0, t + 0.02), door)
	_box_in(root, Vector3(0.55, 2.15, w * 0.5), Vector3(1.1, 0.3, t), walls)
	_box_in(root, Vector3(0, 0.03, 0), Vector3(w, 0.06, w), _paint(Color(0.25, 0.22, 0.2)))
	# A sloping roof overhanging the window.
	var roof := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(w + 0.9, 0.08, w + 0.5)
	roof.mesh = roof_box
	roof.position = Vector3(-0.2, h + 0.18, 0)
	roof.rotation.z = deg_to_rad(-9.0)
	roof.material_override = _material("corrugated_roof.png", "roof", Color(0.55, 0.55, 0.52))
	root.add_child(roof)
	# Inside: a chair back and a desk lamp glow you can see through the window.
	_box_in(root, Vector3(0.2, 0.75, 0), Vector3(0.5, 0.05, 1.4), _paint(Color(0.35, 0.26, 0.18)))
	_box_in(root, Vector3(0.6, 0.6, 0.2), Vector3(0.05, 0.6, 0.45), _paint(Color(0.22, 0.2, 0.18)))
	# A bare bulb over the window, lit at night.
	_booth_light = OmniLight3D.new()
	_booth_light.position = Vector3(-w * 0.5 - 0.3, h - 0.1, 0)
	_booth_light.light_color = Color(1.0, 0.82, 0.55)
	_booth_light.light_energy = 1.4
	_booth_light.omni_range = 7.0
	_booth_light.visible = false
	root.add_child(_booth_light)
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.06
	bulb_mesh.height = 0.12
	bulb.mesh = bulb_mesh
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.9, 0.7)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.8, 0.5)
	bulb.material_override = bulb_mat
	bulb.position = _booth_light.position
	root.add_child(bulb)
	# Solid for the player.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, w)
	shape.shape = box
	shape.position = Vector3(0, h * 0.5, 0)
	body.add_child(shape)
	root.add_child(body)


func _build_sign() -> void:
	var x := gap_center_x - 3.6
	var z := fence_z - 2.6
	var post := _paint(Color(0.3, 0.24, 0.18))
	_box(Vector3(x - 0.7, 1.0, z), Vector3(0.09, 2.0, 0.09), post)
	_box(Vector3(x + 0.7, 1.0, z), Vector3(0.09, 2.0, 0.09), post)
	_box(Vector3(x, 1.7, z), Vector3(1.7, 0.6, 0.05), _material("planks_grey.png", "wood", Color(0.55, 0.52, 0.46)))
	var label := Label3D.new()
	label.text = "CAMP\nRECEPTION - STOP"
	label.font = load("res://assets/fonts/jersey10.fnt")
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color(0.1, 0.08, 0.06)
	label.outline_size = 0
	label.position = Vector3(x, 1.72, z - 0.035)
	label.rotation.y = PI
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(label)


func _build_player_block() -> void:
	var body := StaticBody3D.new()
	body.name = "GateBlock"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.6, 3.0, 0.3)
	shape.shape = box
	body.position = Vector3(gap_center_x, 1.5, fence_z - 0.2)
	body.add_child(shape)
	add_child(body)


# ── helpers ───────────────────────────────────────────────────────────────────

func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return _box_in(self, pos, size, mat)


func _box_in(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


func _paint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


func _material(file: String, fallback_category: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	var tex: Texture2D = null
	if ResourceLoader.exists(TEX_DIR + file):
		tex = load(TEX_DIR + file) as Texture2D
	elif _texture_style != null:
		tex = _texture_style.pick_texture(fallback_category, tint)
	if tex != null:
		m.albedo_texture = tex
		m.albedo_color = Color(1, 1, 1)
	else:
		m.albedo_color = tint
	return m


func _stripe_texture() -> Texture2D:
	var img := Image.create(32, 2, false, Image.FORMAT_RGB8)
	for x in 32:
		var red := (x / 4) % 2 == 0
		var c := Color(0.78, 0.12, 0.1) if red else Color(0.92, 0.9, 0.84)
		img.set_pixel(x, 0, c)
		img.set_pixel(x, 1, c.darkened(0.15))
	return ImageTexture.create_from_image(img)


func _sound(path: String, at: Vector3, volume_db: float, max_distance: float = 40.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 4.0
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
