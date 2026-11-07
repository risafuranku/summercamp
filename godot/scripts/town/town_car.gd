extends RefCounted

## A car of the village's: its own pictures on a hull that fits them (Grok, town/car_*.png), the
## roof and the bonnet in the paint of its doors, the nose to -Z. (On the road the cars were bare
## coloured boxes with a cube for a head, the parked ones had a bare bonnet and roof, their wheels
## 19 cm off the ground, and the motel's were pictures that turned after you.)
##   var car: Node3D = TOWN_CAR.make(Color(...), "car_side")

const TEX := "res://assets/textury/town/"
const LENGTH := 4.2
const WIDTH := 1.58
const HIGH := 1.45


static func make(tint := Color.WHITE, side := "car_side") -> Node3D:
	var car := Node3D.new()
	car.name = "Car"
	var paint := _picture(TEX + "car_paint.png", tint)
	if paint != null:
		paint.uv1_triplanar = true
		paint.uv1_world_triplanar = false
		paint.uv1_scale = Vector3(0.7, 0.7, 0.7)
	# The body to the waist and the cabin over it, inside the picture's outline.
	_box(car, Vector3(WIDTH - 0.04, 0.6, LENGTH - 0.14), Vector3(0, 0.53, 0), paint)
	_box(car, Vector3(WIDTH - 0.2, 0.42, 2.1), Vector3(0, 1.04, 0.12), paint)
	var pic := _picture(TEX + side + ".png", tint)
	if pic != null:
		_quad(car, Vector2(LENGTH, HIGH), Vector3(WIDTH * 0.5 + 0.01, HIGH * 0.5, 0), PI * 0.5, pic)
		# The far side: the same picture the other way round.
		var other := pic.duplicate() as StandardMaterial3D
		other.uv1_scale = Vector3(-1, 1, 1)
		other.uv1_offset = Vector3(1, 0, 0)
		_quad(car, Vector2(LENGTH, HIGH), Vector3(-WIDTH * 0.5 - 0.01, HIGH * 0.5, 0), -PI * 0.5, other)
	# The nose and the tail: the lower part of the pictures; their windscreens on the cabin.
	var nose := _picture(TEX + "car_front.png", tint)
	if nose != null:
		_band(car, nose, 0.42, 1.0, Vector2(WIDTH, 0.76), Vector3(0, 0.46, -LENGTH * 0.5 - 0.01), PI)
		_band(car, nose, 0.0, 0.42, Vector2(WIDTH - 0.22, 0.42), Vector3(0, 1.04, -0.94), PI)
	var tail := _picture(TEX + "car_back.png", tint)
	if tail != null:
		_band(car, tail, 0.42, 1.0, Vector2(WIDTH, 0.76), Vector3(0, 0.46, LENGTH * 0.5 + 0.01), 0.0)
		_band(car, tail, 0.0, 0.42, Vector2(WIDTH - 0.22, 0.42), Vector3(0, 1.04, 1.18), 0.0)
	return car


## A solid hull under it, for a car that stands.
static func parked(car: Node3D) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(WIDTH, HIGH, LENGTH)
	cs.shape = bx
	sb.add_child(cs)
	sb.position = Vector3(0, HIGH * 0.5, 0)
	car.add_child(sb)


static func _picture(path: String, tint: Color) -> StandardMaterial3D:
	if not ResourceLoader.exists(path):
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)


static func _quad(parent: Node3D, size: Vector2, at: Vector3, yaw: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = at
	mi.rotation.y = yaw
	mi.material_override = mat
	mi.set_meta("retro_pull", 0.002)
	parent.add_child(mi)


## Rows `from`..`to` (0 the top, 1 the bottom) of a picture on a quad.
static func _band(parent: Node3D, pic: StandardMaterial3D, from: float, to: float, size: Vector2, at: Vector3, yaw: float) -> void:
	var m := pic.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(1, to - from, 1)
	m.uv1_offset = Vector3(0, from, 0)
	_quad(parent, size, at, yaw, m)
