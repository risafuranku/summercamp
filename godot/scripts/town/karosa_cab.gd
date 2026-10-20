extends RefCounted

## The Karosa SM 11's driver's place, built the same for the bus seen from outside
## (bus_model.gd, through its door and windscreen) and for the ride's cabin
## (bus_ride.gd), after the photo (playtest 20. 10.): the seat on its sprung pedestal,
## brown leatherette with the yellow cloth in the seat and the back, the dark headrest on
## two posts; the big wheel lying almost flat on its column; the black dashboard with the
## dials facing him; the long gear stick out of the floor in its rubber boot; the grey
## bent tube between him and the steps; two pedals. In the bus's frame: front is -z, the
## door side +x, `floor_y` the floor's height. The driver himself is the caller's.
##
## Kept clear of the door's leaves (their sweep is the steps' first tread, x > 0.92) and
## of the aisle (x > -0.15).

const TEX := "res://assets/textury/town/"
## Where he sits (x, z) and the height of the seat's top over the floor.
const SEAT := Vector2(-0.62, -4.35)
const SEAT_TOP := 0.46
## The front wall inside (z), the dashboard's back edge.
const FRONT := -5.34
const DASH_BACK := -4.9
const WHEEL := Vector3(-0.62, 0.98, -4.74)
const RAIL_X := -0.17
const STICK := Vector2(-0.28, -4.64)


## Builds it under `parent`; `mats` caches materials by name (the caller's, so a lit-up
## night can reach them). Returns {"parts": meshes for a hover glint, "seat": Node3D,
## "dash_face": MeshInstance3D}.
static func build(parent: Node3D, floor_y: float, mats: Dictionary) -> Dictionary:
	var parts: Array = []
	var leather := _mat(mats, "cab_leather", TEX + "karosa_leather.png", Color(0.62, 0.42, 0.32), Vector2(2, 2))
	var cloth := _mat(mats, "cab_cloth", TEX + "karosa_cloth.png", Color(1, 1, 1), Vector2(3, 3))
	var dark := _mat(mats, "cab_dark", "", Color(0.16, 0.16, 0.17))
	var black := _mat(mats, "cab_black", "", Color(0.07, 0.07, 0.075))
	var grey := _mat(mats, "cab_grey", "", Color(0.62, 0.62, 0.6))
	var chrome := _mat(mats, "cab_chrome", "", Color(0.74, 0.75, 0.76))
	var rubber := _mat(mats, "cab_rubber", "", Color(0.05, 0.05, 0.05))
	var y := floor_y

	# The dashboard: a black body across the driver's half, its face sloped up to him.
	var dash_w := 1.36
	var dash_cx := -0.52
	_box(parent, Vector3(dash_cx, y + 0.42, (FRONT + DASH_BACK) * 0.5), Vector3(dash_w, 0.84, DASH_BACK - FRONT), dark)
	_box(parent, Vector3(dash_cx, y + 0.86, FRONT + 0.16), Vector3(dash_w, 0.06, 0.34), black)
	var face := _quad(parent, Vector3(dash_cx, y + 0.86, DASH_BACK - 0.01), Vector2(1.3, 0.42),
		Vector3(deg_to_rad(-38.0), 0, 0), _mat(mats, "cab_dash", TEX + "karosa_dash.png", Color(0.3, 0.3, 0.3), Vector2.ONE))
	parts.append(face)
	# On the door side only a low cover over the door's works, in front of the steps.
	_box(parent, Vector3(0.52, y + 0.3, FRONT + 0.14), Vector3(1.38, 0.6, 0.28), dark)

	# The wheel: a thin black rim lying almost flat, three spokes, the hub, the column.
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	wheel.position = Vector3(WHEEL.x, y + WHEEL.y, WHEEL.z)
	wheel.rotation.x = deg_to_rad(22.0)
	parent.add_child(wheel)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.205
	torus.outer_radius = 0.235
	torus.rings = 20
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = black
	wheel.add_child(rim)
	parts.append(rim)
	for k in 3:
		var a := TAU * float(k) / 3.0 + PI * 0.5
		var spoke := _box(wheel, Vector3(cos(a), 0, sin(a)) * 0.11, Vector3(0.21, 0.018, 0.03), black)
		spoke.rotation.y = -a
	_cyl(wheel, Vector3.ZERO, 0.045, 0.05, black, Vector3.ZERO)
	# The column: from under the hub down and forward into the dash.
	var col_from := Vector3(WHEEL.x, y + WHEEL.y - 0.04, WHEEL.z - 0.02)
	var col_to := Vector3(WHEEL.x, y + 0.15, DASH_BACK - 0.02)
	_rod(parent, col_from, col_to, 0.032, dark)
	_rod(parent, col_from.lerp(col_to, 0.55), col_to, 0.055, black)

	# The seat on its pedestal with the rubber bellows.
	var seat := Node3D.new()
	seat.name = "DriverSeat"
	seat.position = Vector3(SEAT.x, y, SEAT.y)
	parent.add_child(seat)
	_box(seat, Vector3(0, 0.12, 0), Vector3(0.36, 0.24, 0.36), dark)
	_box(seat, Vector3(0, 0.29, 0), Vector3(0.3, 0.1, 0.3), rubber)
	parts.append(_box(seat, Vector3(0, SEAT_TOP - 0.06, -0.01), Vector3(0.5, 0.12, 0.48), leather))
	var sq := _quad(seat, Vector3(0, SEAT_TOP + 0.002, -0.03), Vector2(0.36, 0.36), Vector3(-PI * 0.5, 0, 0), cloth)
	parts.append(sq)
	# The back, leaning back a little: leatherette round, the cloth in the middle.
	var back := Node3D.new()
	back.position = Vector3(0, SEAT_TOP, 0.22)
	back.rotation.x = deg_to_rad(12.0)
	seat.add_child(back)
	parts.append(_box(back, Vector3(0, 0.32, 0), Vector3(0.5, 0.62, 0.1), leather))
	parts.append(_quad(back, Vector3(0, 0.3, -0.052), Vector2(0.34, 0.46), Vector3(0, PI, 0), cloth))
	# The headrest on two chrome posts.
	for x in [-0.07, 0.07]:
		_box(back, Vector3(x, 0.68, 0.0), Vector3(0.016, 0.1, 0.016), chrome)
	parts.append(_box(back, Vector3(0, 0.8, 0.0), Vector3(0.26, 0.16, 0.08), _mat(mats, "cab_headrest", "", Color(0.24, 0.24, 0.25))))

	# The gear stick: a plate, the boot, the long rod leaning back, the black knob.
	var base := Vector3(STICK.x, y, STICK.y)
	_box(parent, base + Vector3(0, 0.01, 0), Vector3(0.16, 0.02, 0.16), grey)
	_cyl(parent, base + Vector3(0, 0.07, 0), 0.03, 0.07, rubber, Vector3.ZERO, 0.12)
	var top := base + Vector3(0, 0.86, 0.1)
	_rod(parent, base + Vector3(0, 0.1, 0), top, 0.012, grey)
	var knob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.035
	ball.height = 0.07
	ball.radial_segments = 8
	ball.rings = 4
	knob.mesh = ball
	knob.material_override = black
	knob.position = top
	parent.add_child(knob)
	parts.append(knob)

	# The grey tube between his seat and the steps: up from the floor, forward, down.
	var r0 := Vector3(RAIL_X, y, -3.98)
	var r1 := Vector3(RAIL_X, y + 0.86, -3.98)
	var r2 := Vector3(RAIL_X, y + 0.86, -4.6)
	var r3 := Vector3(RAIL_X, y + 0.3, -4.82)
	for seg in [[r0, r1], [r1, r2], [r2, r3]]:
		_rod(parent, seg[0], seg[1], 0.022, grey)
	# Two pedals under the dash.
	for x in [-0.72, -0.5]:
		var p := _box(parent, Vector3(x, y + 0.1, DASH_BACK + 0.06), Vector3(0.09, 0.03, 0.18), rubber)
		p.rotation.x = deg_to_rad(35.0)
	return {"parts": parts, "seat": seat, "dash_face": face}


static func _mat(mats: Dictionary, key: String, tex: String, tint: Color, uv := Vector2.ONE) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if tex != "" and ResourceLoader.exists(tex):
		m.albedo_texture = load(tex)
		m.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	m.emission_enabled = true
	m.emission = Color(0, 0, 0)
	mats[key] = m
	return m


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _quad(parent: Node3D, pos: Vector3, size: Vector2, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, pos: Vector3, r_top: float, r_low: float, mat: Material, rot: Vector3, h := 0.04) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_low
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A round rod from `a` to `b`.
static func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 6
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	parent.add_child(mi)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	return mi
