extends Node3D

## The line 380 bus from outside: a Karosa SM 11 in the CSAD's white and yellow (the
## photo, playtest 20. 10.), drawn to the metre by tools/artgen/karosa.py
## (assets/textury/town/karosa_*.png) and built here round the holes it leaves: the front
## door, the windscreen, the wheel arches. Its front is -Z, the doors on its right (+X):
## the front door ahead of the front wheel, the back one behind the rear wheel (shut,
## painted).
##
## The front door is a real opening with its jambs: two leaves of two glazed panels each
## fold in on their hinges at the jambs with a hiss, the outer panel swinging in and the
## inner one folding back so its edge runs along the door line (a pneumatic start, a
## cushioned end). Behind it the steps up, the yellow pole with the orange punch, the
## grey tube by the driver; through the door and the windscreen you see in: the driver at
## his wheel (karosa_cab.gd: his seat, wheel, dashboard and gear stick as in the photo),
## the tan seats, lit at night. Mirrors on their arms, bumpers, plates, the 380 card
## behind the windscreen.
## At night the windows glow from inside and the headlights and the destination board are
## on. Wheels turn and the body rocks a little while it moves, in steps. town_trip.gd moves
## it along the roads and sets what it shows.
##
## It is solid (you walk round it) and, while its door is open, clickable
## (building_type "trip_bus", meta "stop" = which stop it stands at).

const CAB = preload("res://scripts/town/karosa_cab.gd")
const TEX := "res://assets/textury/town/"
const SFX := "res://assets/sfx/bus/"
## Its measures (tools/artgen/karosa.py draws to the same; keep them in step).
const LENGTH := 10.8
const WIDTH := 2.5
const BODY_LOW := 0.4
const BODY_HIGH := 3.0
const ROOF_TOP := 3.12
const WHEEL_R := 0.5
const ARCH_R := 0.62
## Where the wheels are along the bus (z), the front door (z from its front jamb to its
## back one, y from its sill to its top), the windscreen (y).
const AXLES := [-3.0, 2.3]
const DOOR_Z := Vector2(-5.02, -4.0)
const DOOR_Y := Vector2(0.4, 2.64)
const WINDSCREEN_Y := Vector2(1.38, 2.84)
const WINDOW_Y := Vector2(1.62, 2.64)
const PLATE := "JIA 38-80"
## The door: seconds to fold open (or shut), and how far the outer panels swing in.
const DOOR_TIME := 0.85
const DOOR_ANGLE := 0.47 * PI
## The floor inside, the ceiling, the steps (their tops and how far in each goes).
const FLOOR_Y := 0.78
const CEIL_Y := 2.78
const STEP_1 := Vector2(0.4, 0.92)
const STEP_2 := Vector2(0.59, 0.62)

var destination := "LIBLICE" : set = _set_destination
var _sides: Array[StandardMaterial3D] = []
var _wheels: Array[Node3D] = []
## Per leaf: {hinge (at the jamb), joint (between its two panels), d (+1 the front jamb's)}.
var _door_leaves: Array = []
var _door_open := 0.0          # 0 shut .. 1 open (time, eased into the angle)
var _door_target := 0.0
var _board: Label3D
var _lamps: Array[StandardMaterial3D] = []
var _beam: SpotLight3D
var _click: StaticBody3D
var _body: Node3D
var _idle: AudioStreamPlayer3D
var _one: AudioStreamPlayer3D
var _speed := 0.0
var _wheel_turn := 0.0
var _night := false
## The driver at his wheel (his back, or his front when you look in from ahead), and his
## smoke on his break.
var _driver: Sprite3D
var _driver_back: Texture2D
var _driver_front: Texture2D
var _smoking := false
## The inside's materials (lit at night) and the light over the steps.
var _inside_mats: Dictionary = {}
var _inside: Node3D
var _lamp_in: OmniLight3D
var _puffs: Array[Sprite3D] = []
var _puff_t := 0.0
var _glass: StandardMaterial3D


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_build()
	_idle = AudioStreamPlayer3D.new()
	_idle.stream = _loop(load(SFX + "idle.mp3") if ResourceLoader.exists(SFX + "idle.mp3") else null)
	_idle.unit_size = 6.0
	_idle.max_distance = 70.0
	_idle.volume_db = -6.0
	_idle.position = Vector3(0, 1.0, LENGTH * 0.4)
	add_child(_idle)
	_one = AudioStreamPlayer3D.new()
	_one.unit_size = 8.0
	_one.max_distance = 120.0
	_one.position = Vector3(WIDTH * 0.5, 1.4, (DOOR_Z.x + DOOR_Z.y) * 0.5)
	add_child(_one)


# ── what it shows ────────────────────────────────────────────────────────────

func set_running(on: bool) -> void:
	visible = on
	if _click != null:
		_click.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		for c in _click.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).set_deferred("disabled", not on)
	if on and not _idle.playing and _idle.stream != null:
		_idle.play()
	elif not on:
		_idle.stop()


func is_door_open() -> bool:
	return _door_open > 0.99


## The inside seen through the door and the windscreen: hidden while bus_ride.gd's cabin
## rides in it (the door's leaves stay: the cabin uses these).
func set_inside_visible(on: bool) -> void:
	if _inside != null:
		_inside.visible = on


func open_door(open: bool, quiet := false) -> void:
	if open == (_door_target > 0.5):
		return
	_door_target = 1.0 if open else 0.0
	if not quiet:
		play(SFX + ("door_open.mp3" if open else "door_close.mp3"), -2.0)
	if _click != null:
		if open:
			_click.set_meta("building_type", "trip_bus")
		else:
			_click.remove_meta("building_type")


## How far open the door is now (0 shut .. 1 open), for the cabin's sounds and glints.
func door_amount() -> float:
	return _door_open


## The meshes of the door's panels (the cabin lights them up under the mouse).
func door_meshes() -> Array:
	var out: Array = []
	for leaf in _door_leaves:
		for n in [leaf["hinge"], leaf["joint"]]:
			for c in (n as Node3D).get_children():
				if c is MeshInstance3D:
					out.append(c)
	return out


## How fast it goes (m/s): turns the wheels and rocks the body.
func set_speed(v: float) -> void:
	_speed = v


func set_night(night: bool) -> void:
	_night = night
	for m in _sides:
		m.emission = Color(1.0, 0.82, 0.5) * (0.9 if night else 0.0)
	for m in _lamps:
		m.emission = Color(1.0, 0.92, 0.7) * (2.4 if night else 0.2)
	for m in _inside_mats.values():
		(m as StandardMaterial3D).emission = Color(1.0, 0.86, 0.6) * (0.22 if night else 0.0)
	if _lamp_in != null:
		_lamp_in.visible = night
	if _beam != null:
		_beam.visible = night
	if _board != null:
		_board.modulate = Color(1.0, 0.72, 0.22) if night else Color(0.9, 0.62, 0.2)


func play(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	_one.stream = load(path)
	_one.volume_db = db
	_one.play()


## His break while the bus stands at the end of the line: he smokes at his wheel, the
## smoke going out of his window (he stays in his seat, where you see him through the
## door from the stop).
func set_driver_out(out: bool) -> void:
	_smoking = out
	if not out:
		for p in _puffs:
			p.visible = false


func set_stop(stop: String) -> void:
	if _click != null:
		_click.set_meta("stop", stop)


func _set_destination(text: String) -> void:
	destination = text
	if _board != null:
		_board.text = "380  " + text


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible:
		return
	# The door: a pneumatic push, quick off the mark and cushioned at the end. Each
	# leaf's outer panel swings in on its hinge, the inner one folds back so its free
	# edge runs along the door line.
	if _door_open != _door_target:
		_door_open = move_toward(_door_open, _door_target, delta / DOOR_TIME)
		_fold(_door_open)
	# Wheels and a rocking body, twelve steps a second.
	_wheel_turn += _speed * delta / WHEEL_R
	var tick := floorf(Time.get_ticks_msec() / 83.0)
	for wheel in _wheels:
		wheel.rotation.y = floorf(_wheel_turn / (TAU / 16.0)) * (TAU / 16.0)
	var rock := 0.0
	if _speed > 0.3:
		rock = sin(tick * 0.9) * 0.006 * minf(1.0, _speed / 8.0)
	else:
		# Idling: the engine shakes it a hair.
		rock = (0.002 if int(tick) % 2 == 0 else -0.002)
	_body.rotation.z = rock
	_idle.pitch_scale = 1.0 + minf(0.5, _speed / 20.0)
	_face_driver()
	# His smoke: a puff every couple of seconds, drifting out of his open window and up,
	# in steps.
	if _smoking and _driver != null:
		_puff_t += delta
		for i in _puffs.size():
			var age := fmod(_puff_t + float(i) * 0.6, 2.4)
			var p := _puffs[i]
			p.visible = age < 1.8
			var ps := floorf(age * 12.0) / 12.0
			p.position = Vector3(-0.9 - ps * 0.9, FLOOR_Y + 1.3 + ps * 0.8, CAB.SEAT.y - 0.1 + ps * 0.3)
			p.scale = Vector3.ONE * (0.6 + ps * 1.2)
			p.modulate.a = clampf(1.0 - ps / 1.8, 0.0, 1.0)


func _fold(k: float) -> void:
	# Smoothstep: the air's push and the cushion at the end of the stroke.
	var a := k * k * (3.0 - 2.0 * k) * DOOR_ANGLE
	for leaf in _door_leaves:
		var d: float = leaf["d"]
		(leaf["hinge"] as Node3D).rotation.y = -d * a
		(leaf["joint"] as Node3D).rotation.y = d * 2.0 * a


## His back to you, or his front when you look in from ahead of him.
func _face_driver() -> void:
	if _driver == null or _driver_front == null or not _driver.is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var local := _body.to_local(cam.global_position)
	var front := local.z < _driver.position.z - 0.3
	var want := _driver_front if front else _driver_back
	if _driver.texture != want:
		_driver.texture = want
		_driver.offset = _driver_offset(want)


# ── the model ────────────────────────────────────────────────────────────────

func _build() -> void:
	var h := BODY_HIGH - BODY_LOW
	var mid_y := BODY_LOW + h * 0.5
	# The sides (holes for the door and the arches in their art), the front (a hole for
	# the windscreen), the back.
	_quad(_body, Vector3(WIDTH * 0.5, mid_y, 0), Vector2(LENGTH, h), Vector3(0, PI * 0.5, 0), _side_material("karosa_side_r"))
	_quad(_body, Vector3(-WIDTH * 0.5, mid_y, 0), Vector2(LENGTH, h), Vector3(0, -PI * 0.5, 0), _side_material("karosa_side_l"))
	_quad(_body, Vector3(0, mid_y, -LENGTH * 0.5), Vector2(WIDTH, h), Vector3(0, PI, 0), _cut_material("karosa_front.png", Color(0.9, 0.88, 0.8)))
	_quad(_body, Vector3(0, mid_y, LENGTH * 0.5), Vector2(WIDTH, h), Vector3.ZERO, _cut_material("karosa_back.png", Color(0.9, 0.88, 0.8)))
	_glass = _paint(Color(0.32, 0.38, 0.42, 0.34))
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass.roughness = 0.2
	_glass.metallic_specular = 0.6
	_glass.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	# The roof: white, its edges rounded down to the sides, the vents, the dark underside.
	var roof := _paint(Color(0.84, 0.83, 0.78))
	_box(_body, Vector3(0, (BODY_HIGH + ROOF_TOP) * 0.5, 0), Vector3(WIDTH - 0.2, ROOF_TOP - BODY_HIGH, LENGTH), roof)
	for side in [-1.0, 1.0]:
		var edge := _box(_body, Vector3(side * (WIDTH * 0.5 - 0.07), BODY_HIGH + 0.05, 0), Vector3(0.17, 0.05, LENGTH), roof)
		edge.rotation.z = side * deg_to_rad(-38.0)
	for z in [-2.6, 1.4]:
		_box(_body, Vector3(0, ROOF_TOP + 0.05, z), Vector3(0.8, 0.1, 0.9), _paint(Color(0.62, 0.62, 0.6)))
	_box(_body, Vector3(0, BODY_LOW - 0.06, 0), Vector3(WIDTH - 0.1, 0.12, LENGTH - 0.3), _paint(Color(0.07, 0.07, 0.07)))
	_build_glass()
	_build_door()
	_build_inside()
	_build_wheels()
	_dress()
	# Lamps: headlights (and their beams at night), tail lights.
	for x in [-1.0, 1.0]:
		var head := StandardMaterial3D.new()
		head.albedo_color = Color(0.92, 0.9, 0.82)
		head.emission_enabled = true
		_lamps.append(head)
		_cyl(_body, Vector3(x * (WIDTH * 0.5 - 0.34), 0.83, -LENGTH * 0.5 - 0.012), 0.075, 0.02, head, Vector3(PI * 0.5, 0, 0))
		for k in 3:
			var tail := StandardMaterial3D.new()
			tail.albedo_color = Color(0.62, 0.08, 0.05) if k != 1 else Color(0.7, 0.4, 0.08)
			tail.emission_enabled = true
			tail.emission = (Color(0.9, 0.08, 0.04) if k != 1 else Color(0.5, 0.25, 0.02)) * 0.6
			_cyl(_body, Vector3(x * (WIDTH * 0.5 - 0.17), 0.9 + k * 0.22, LENGTH * 0.5 + 0.012), 0.06, 0.02, tail, Vector3(PI * 0.5, 0, 0))
	_beam = SpotLight3D.new()
	_beam.light_color = Color(1.0, 0.9, 0.7)
	_beam.light_energy = 2.2
	_beam.spot_range = 26.0
	_beam.spot_angle = 30.0
	_beam.position = Vector3(0, 0.85, -LENGTH * 0.5 - 0.2)
	_beam.rotation.x = deg_to_rad(-6.0)
	_beam.visible = false
	_body.add_child(_beam)
	# The destination board behind the top of the windscreen, on the door's half.
	_box(_body, Vector3(0.6, WINDSCREEN_Y.y - 0.13, -LENGTH * 0.5 + 0.1), Vector3(1.08, 0.22, 0.06), _paint(Color(0.05, 0.05, 0.05)))
	_board = Label3D.new()
	_board.font = load("res://assets/fonts/jersey10.fnt")
	_board.font_size = 32
	_board.pixel_size = 0.004
	_board.outline_size = 0
	_board.modulate = Color(0.9, 0.62, 0.2)
	_board.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_board.double_sided = false
	_board.position = Vector3(0.6, WINDSCREEN_Y.y - 0.13, -LENGTH * 0.5 + 0.065)
	_board.rotation.y = PI
	_body.add_child(_board)
	_set_destination(destination)
	# Solid, and clickable while the door is open.
	_click = StaticBody3D.new()
	_click.name = "BusBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, BODY_HIGH, LENGTH)
	shape.shape = box
	shape.position = Vector3(0, BODY_HIGH * 0.5, 0)
	_click.add_child(shape)
	add_child(_click)


## The windscreen's two panes on their pillar, the wipers parked under them.
func _build_glass() -> void:
	var z := -LENGTH * 0.5 + 0.02
	var hy := WINDSCREEN_Y.y - WINDSCREEN_Y.x
	for side in [-1.0, 1.0]:
		_quad(_body, Vector3(side * WIDTH * 0.25, WINDSCREEN_Y.x + hy * 0.5, z), Vector2(WIDTH * 0.5 - 0.1, hy), Vector3(0, PI, 0), _glass)
		var wiper := _box(_body, Vector3(side * WIDTH * 0.25 + 0.1, WINDSCREEN_Y.x + 0.14, -LENGTH * 0.5 - 0.02), Vector3(0.62, 0.02, 0.02), _paint(Color(0.06, 0.06, 0.06)))
		wiper.rotation.z = deg_to_rad(8.0) * side
	_box(_body, Vector3(0, WINDSCREEN_Y.x + hy * 0.5, z), Vector3(0.05, hy, 0.04), _paint(Color(0.08, 0.08, 0.08)))


## The front door: its jambs and head (the opening's depth), and the two leaves of two
## panels each: a steel frame round the glass, the yellow kick panel, rubber on the
## meeting edges.
func _build_door() -> void:
	var dw := DOOR_Z.y - DOOR_Z.x
	var pw := dw * 0.25
	var bottom := DOOR_Y.x + 0.04
	var ph := DOOR_Y.y - bottom - 0.02
	var x := WIDTH * 0.5 - 0.035
	var rubber := _paint(Color(0.05, 0.05, 0.05))
	var jamb := _paint(Color(0.18, 0.18, 0.18))
	for z in [DOOR_Z.x - 0.015, DOOR_Z.y + 0.015]:
		_box(_body, Vector3(WIDTH * 0.5 - 0.07, (DOOR_Y.x + DOOR_Y.y) * 0.5, z), Vector3(0.14, DOOR_Y.y - DOOR_Y.x, 0.03), jamb)
	_box(_body, Vector3(WIDTH * 0.5 - 0.07, DOOR_Y.y + 0.015, (DOOR_Z.x + DOOR_Z.y) * 0.5), Vector3(0.14, 0.03, dw + 0.06), jamb)
	var frame := StandardMaterial3D.new()
	frame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	frame.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	frame.roughness = 1.0
	frame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	frame.alpha_scissor_threshold = 0.5
	frame.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(TEX + "karosa_door_panel.png"):
		frame.albedo_texture = load(TEX + "karosa_door_panel.png")
	else:
		frame.albedo_color = Color(0.8, 0.8, 0.76)
	var glass_y := Vector2(1.06, DOOR_Y.y - 0.05)
	for d in [1.0, -1.0]:
		var hinge := Node3D.new()
		hinge.name = "DoorHinge"
		hinge.position = Vector3(x, bottom, DOOR_Z.x if d > 0.0 else DOOR_Z.y)
		_body.add_child(hinge)
		var joint := Node3D.new()
		joint.position = Vector3(0, 0, d * pw)
		hinge.add_child(joint)
		for holder in [hinge, joint]:
			var mid := Vector3(0, ph * 0.5, d * pw * 0.5)
			_quad(holder, mid, Vector2(pw - 0.006, ph), Vector3(0, PI * 0.5, 0), frame)
			_quad(holder, Vector3(0, (glass_y.x + glass_y.y) * 0.5 - bottom, d * pw * 0.5), Vector2(pw - 0.06, glass_y.y - glass_y.x), Vector3(0, PI * 0.5, 0), _glass)
			# The rubber on the panel's free edge (the leaves meet on it, shut).
			_box(holder, Vector3(0, ph * 0.5, d * (pw - 0.006)), Vector3(0.03, ph, 0.012), rubber)
		_door_leaves.append({"hinge": hinge, "joint": joint, "d": d})
	_fold(0.0)


## The wheels: tyres, the silver rims with their nuts, the dark wells round them.
func _build_wheels() -> void:
	var tyre := _paint(Color(0.06, 0.06, 0.06))
	var rim := _paint(Color(0.62, 0.63, 0.62))
	var hub := _paint(Color(0.3, 0.3, 0.3))
	var well := _paint(Color(0.04, 0.04, 0.04))
	well.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hump := _tex_material("bus_floor.png", Color(0.3, 0.3, 0.3))
	hump.albedo_color = Color(0.34, 0.34, 0.33)
	for z in AXLES:
		for side in [-1.0, 1.0]:
			# The well: its inner wall and its top (what you see round the tyre).
			_quad(_body, Vector3(side * (WIDTH * 0.5 - 0.42), FLOOR_Y * 0.5, float(z)), Vector2(ARCH_R * 2.0, FLOOR_Y), Vector3(0, side * PI * 0.5, 0), well)
			var holder := Node3D.new()
			holder.position = Vector3(side * (WIDTH * 0.5 - 0.17), WHEEL_R, float(z))
			holder.rotation.z = PI * 0.5
			add_child(holder)
			var w := Node3D.new()
			holder.add_child(w)
			_cyl(w, Vector3.ZERO, WHEEL_R, 0.28, tyre, Vector3.ZERO, 12)
			# The rim on the outer face (the holder's +y is the bus's -x).
			var out: float = -side
			_cyl(w, Vector3(0, out * 0.142, 0), 0.3, 0.012, rim, Vector3.ZERO, 12)
			_cyl(w, Vector3(0, out * 0.152, 0), 0.1, 0.012, hub, Vector3.ZERO, 8)
			for k in 6:
				var a := TAU * float(k) / 6.0
				_box(w, Vector3(cos(a) * 0.17, out * 0.152, sin(a) * 0.17), Vector3(0.03, 0.02, 0.03), hub)
			_wheels.append(w)
		# Over the wheels: the arch's housing, a hump under the seats inside (grey ribbed
		# rubber like the floor; its dark underside is what shows round the tyre).
		# Thin walls, hollow: through the arch you still see the whole tyre.
		for side in [-1.0, 1.0]:
			var hx: float = side * (WIDTH * 0.5 - 0.24)
			var hl := ARCH_R * 2.0 + 0.04
			var hh := WHEEL_Y_TOP - FLOOR_Y
			_box(_body, Vector3(hx, WHEEL_Y_TOP - 0.01, float(z)), Vector3(0.4, 0.02, hl), hump)
			_box(_body, Vector3(hx - side * 0.2, FLOOR_Y + hh * 0.5, float(z)), Vector3(0.02, hh, hl), hump)
			for e in [-1.0, 1.0]:
				_box(_body, Vector3(hx, FLOOR_Y + hh * 0.5, float(z) + e * hl * 0.5), Vector3(0.4, hh, 0.02), hump)


const WHEEL_Y_TOP := 1.1


## The inside, for what the open door and the windscreen show: the floor up two steps,
## the inner walls (the door side round the doorway), the ceiling, the back from inside,
## the tan seats, the yellow pole by the door with the orange punch box on it, the
## driver's place (karosa_cab.gd) and the driver. Dark, lit by the strip lights at night
## (set_night).
func _build_inside() -> void:
	var before := _body.get_child_count()
	var inner := WIDTH * 0.5 - 0.04
	var front_z := -LENGTH * 0.5 + 0.06
	var back_z := LENGTH * 0.5 - 0.06
	var wall := _inside_mat("in_wall", "bus_wall.png", Color(0.7, 0.68, 0.62), Vector2(4.0, 1.0))
	var floor_m := _inside_mat("in_floor", "bus_floor.png", Color(0.46, 0.46, 0.44), Vector2(2.0, 8.0))
	var ceil_m := _inside_mat("in_ceiling", "bus_ceiling.png", Color(0.82, 0.8, 0.72), Vector2(2.0, 8.0))
	var dark_glass := _paint(Color(0.12, 0.14, 0.16))
	# The floor: the slab, beside the stairwell in front of and behind the door, the two
	# treads in the doorway with their worn yellow nosing.
	var edge := BODY_LOW - 0.05
	_box(_body, Vector3((-inner + STEP_2.y) * 0.5, (edge + FLOOR_Y) * 0.5, 0), Vector3(inner + STEP_2.y, FLOOR_Y - edge, LENGTH - 0.12), floor_m)
	for zr in [Vector2(front_z, DOOR_Z.x - 0.03), Vector2(DOOR_Z.y + 0.03, back_z)]:
		_box(_body, Vector3((STEP_2.y + inner) * 0.5, (edge + FLOOR_Y) * 0.5, (zr.x + zr.y) * 0.5), Vector3(inner - STEP_2.y, FLOOR_Y - edge, zr.y - zr.x), floor_m)
	var dz := (DOOR_Z.x + DOOR_Z.y) * 0.5
	var dw := DOOR_Z.y - DOOR_Z.x
	var tread := _paint(Color(0.2, 0.2, 0.19))
	var nosing := _paint(Color(0.7, 0.58, 0.2))
	_box(_body, Vector3((STEP_1.y + inner) * 0.5, (edge + STEP_1.x) * 0.5, dz), Vector3(inner - STEP_1.y, STEP_1.x - edge, dw + 0.06), tread)
	_box(_body, Vector3((STEP_2.y + STEP_1.y) * 0.5, (edge + STEP_2.x) * 0.5, dz), Vector3(STEP_1.y - STEP_2.y, STEP_2.x - edge, dw + 0.06), tread)
	_box(_body, Vector3(inner - 0.02, STEP_1.x + 0.006, dz), Vector3(0.04, 0.012, dw), nosing)
	_box(_body, Vector3(STEP_1.y - 0.02, STEP_2.x + 0.006, dz), Vector3(0.04, 0.012, dw), nosing)
	_box(_body, Vector3(STEP_2.y - 0.02, FLOOR_Y + 0.006, dz), Vector3(0.04, 0.012, dw), nosing)
	# Walls from inside: the panel under the windows, the windows (dark), the strip above.
	for side in [-1.0, 1.0]:
		var spans: Array = [Vector2(-LENGTH * 0.5, LENGTH * 0.5)]
		if side > 0.0:
			spans = [Vector2(-LENGTH * 0.5, DOOR_Z.x - 0.03), Vector2(DOOR_Z.y + 0.03, LENGTH * 0.5)]
		for sp in spans:
			var span: Vector2 = sp
			var mid := (span.x + span.y) * 0.5
			var span_len := span.y - span.x
			var rot := Vector3(0, -PI * 0.5 * side, 0)
			_quad(_body, Vector3(side * inner, (FLOOR_Y + WINDOW_Y.x) * 0.5, mid), Vector2(span_len, WINDOW_Y.x - FLOOR_Y), rot, wall)
			_quad(_body, Vector3(side * inner, (WINDOW_Y.x + WINDOW_Y.y) * 0.5, mid), Vector2(span_len, WINDOW_Y.y - WINDOW_Y.x), rot, dark_glass)
			_quad(_body, Vector3(side * inner, (WINDOW_Y.y + CEIL_Y) * 0.5, mid), Vector2(span_len, CEIL_Y - WINDOW_Y.y), rot, wall)
	# Over the doorway, the ceiling, the front under the windscreen, the back.
	_quad(_body, Vector3(inner, (DOOR_Y.y + CEIL_Y) * 0.5 + 0.02, dz), Vector2(dw + 0.06, CEIL_Y - DOOR_Y.y), Vector3(0, -PI * 0.5, 0), wall)
	_quad(_body, Vector3(0, CEIL_Y, 0), Vector2(WIDTH - 0.08, LENGTH - 0.08), Vector3(PI * 0.5, 0, 0), ceil_m)
	_quad(_body, Vector3(0, (FLOOR_Y + WINDSCREEN_Y.x) * 0.5, front_z - 0.02), Vector2(WIDTH - 0.08, WINDSCREEN_Y.x - FLOOR_Y), Vector3.ZERO, wall)
	_quad(_body, Vector3(0, (FLOOR_Y + CEIL_Y) * 0.5, back_z), Vector2(WIDTH - 0.08, CEIL_Y - FLOOR_Y), Vector3(0, PI, 0), wall)
	# The driver's place, as in the photo.
	CAB.build(_body, FLOOR_Y, _inside_mats)
	# The tan seats down both sides as the cabin has them (bus_ride.SEATS): none by the
	# steps, none from the back door on.
	for i in 8:
		var z := -2.5 + 0.9 * float(i)
		_seat(Vector3(-0.68, FLOOR_Y, z))
		if z < 2.5:
			_seat(Vector3(0.68, FLOOR_Y, z))
	# The yellow pole at the top of the steps and the orange punch on it, facing the door.
	var pole := _paint(Color(0.82, 0.64, 0.16))
	var pole_at := Vector3(STEP_2.y - 0.08, 0, DOOR_Z.y + 0.1)
	_box(_body, Vector3(pole_at.x, (FLOOR_Y + CEIL_Y) * 0.5, pole_at.z), Vector3(0.04, CEIL_Y - FLOOR_Y, 0.04), pole)
	_box(_body, Vector3(pole_at.x, FLOOR_Y + 1.45, pole_at.z - 0.04), Vector3(0.12, 0.3, 0.1), _paint(Color(0.86, 0.44, 0.1)))
	var punch_tex: Texture2D = load(TEX + "validator.png") if ResourceLoader.exists(TEX + "validator.png") else null
	if punch_tex != null:
		var pm := _paint(Color.WHITE)
		pm.albedo_texture = punch_tex
		pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_quad(_body, Vector3(pole_at.x + 0.065, FLOOR_Y + 1.45, pole_at.z - 0.04), Vector2(0.14, 0.3), Vector3(0, PI * 0.5, 0), pm)
	_driver_inside()
	# The strip light over the steps at night.
	_lamp_in = OmniLight3D.new()
	_lamp_in.light_color = Color(1.0, 0.88, 0.66)
	_lamp_in.light_energy = 1.1
	_lamp_in.omni_range = 4.5
	_lamp_in.position = Vector3(0.3, CEIL_Y - 0.15, -4.0)
	_lamp_in.visible = false
	_body.add_child(_lamp_in)
	# All of it under one node, hidden while the ride's own cabin is in the bus.
	_inside = Node3D.new()
	_inside.name = "Inside"
	var made: Array = []
	for i in range(before, _body.get_child_count()):
		made.append(_body.get_child(i))
	_body.add_child(_inside)
	for n in made:
		_body.remove_child(n)
		_inside.add_child(n)


## A double seat: the tan cushion, the back (its cloth and the white cover over its top
## seen from behind), the chrome grip, the leg to the aisle.
func _seat(at: Vector3) -> void:
	var cloth := _inside_mat("in_seat", "karosa_seat_cloth.png", Color(1, 1, 1), Vector2(4.0, 2.0))
	var edge := _inside_mat("in_seat_edge", "", Color(0.36, 0.24, 0.16), Vector2.ONE)
	var back_t := _inside_mat("in_seat_back", "karosa_seat_back.png", Color(1, 1, 1), Vector2.ONE)
	back_t.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_box(_body, at + Vector3(0, 0.44, 0), Vector3(0.84, 0.1, 0.44), cloth)
	_box(_body, at + Vector3(0, 0.78, 0.22), Vector3(0.84, 0.6, 0.06), edge)
	_quad(_body, at + Vector3(0, 0.78, 0.252), Vector2(0.84, 0.62), Vector3.ZERO, back_t)
	_quad(_body, at + Vector3(0, 0.78, 0.188), Vector2(0.78, 0.56), Vector3(0, PI, 0), cloth)
	_box(_body, at + Vector3(0, 1.1, 0.22), Vector3(0.7, 0.035, 0.035), _paint(Color(0.72, 0.73, 0.74)))
	_box(_body, at + Vector3(-signf(at.x) * 0.36, 0.2, 0), Vector3(0.05, 0.4, 0.05), _paint(Color(0.4, 0.4, 0.4)))


func _inside_mat(key: String, file: String, tint: Color, uv: Vector2) -> StandardMaterial3D:
	if _inside_mats.has(key):
		return _inside_mats[key]
	var m := _paint(tint)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if file != "" and ResourceLoader.exists(TEX + file):
		m.albedo_texture = load(TEX + file)
		m.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	m.emission_enabled = true
	m.emission = Color(0, 0, 0)
	_inside_mats[key] = m
	return m


## The driver in his seat (karosa_cab.gd's): Grok's man without a seat, his back or his
## front as you look; his smoke when he is on his break.
func _driver_inside() -> void:
	var back_p := TEX + "bus_driver_seated.png"
	var front_p := TEX + "bus_driver_seated_front.png"
	if not ResourceLoader.exists(back_p):
		return
	_driver_back = load(back_p)
	_driver_front = load(front_p) if ResourceLoader.exists(front_p) else null
	_driver = Sprite3D.new()
	_driver.name = "Driver"
	_driver.texture = _driver_back
	# Hips to the cap's top, sitting.
	var h := 0.96
	_driver.pixel_size = h / float(_driver_back.get_height())
	_driver.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_driver.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_driver.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_driver.shaded = true
	_driver.offset = _driver_offset(_driver_back)
	_driver.position = Vector3(CAB.SEAT.x, FLOOR_Y + CAB.SEAT_TOP + h * 0.5 - 0.02, CAB.SEAT.y - 0.04)
	_body.add_child(_driver)
	for k in 4:
		var puff := Sprite3D.new()
		var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
		for y in 6:
			for x in 6:
				var d := Vector2(x - 2.5, y - 2.5).length()
				if d < 2.8 and (x + y) % 2 == 0 or d < 1.6:
					img.set_pixel(x, y, Color(0.86, 0.86, 0.84, 0.7))
		puff.texture = ImageTexture.create_from_image(img)
		puff.pixel_size = 0.04
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		puff.visible = false
		_body.add_child(puff)
		_puffs.append(puff)


## The sprite's own middle is his body, not the picture's (his arms reach out to one
## side): centre the body over the seat.
func _driver_offset(t: Texture2D) -> Vector2:
	if t == null:
		return Vector2.ZERO
	var img := t.get_image()
	if img == null:
		return Vector2.ZERO
	if img.is_compressed():
		img.decompress()
	# The body: the opaque columns in the lowest third (below the arms).
	var w := img.get_width()
	var hgt := img.get_height()
	var lo := w
	var hi := 0
	for y in range(int(hgt * 0.8), hgt):
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	if hi <= lo:
		return Vector2.ZERO
	return Vector2(w * 0.5 - (lo + hi) * 0.5, 0)


## What a box with a picture on it lacks: the bumpers, the mirrors out on their arms at
## the front corners, the plates, the line's card in the windscreen on the door side.
func _dress() -> void:
	var yellow := _paint(Color(0.82, 0.7, 0.4))
	var black := _paint(Color(0.07, 0.07, 0.07))
	var steel := _paint(Color(0.32, 0.33, 0.32))
	for zf in [-1.0, 1.0]:
		var bz: float = zf * (LENGTH * 0.5 + 0.05)
		_box(_body, Vector3(0, 0.53, bz), Vector3(WIDTH - 0.36, 0.22, 0.1), yellow)
		for x in [-1.0, 1.0]:
			_box(_body, Vector3(x * (WIDTH * 0.5 - 0.09), 0.53, bz), Vector3(0.2, 0.22, 0.1), black)
		var plate := _quad(_body, Vector3(0, 0.53, zf * (LENGTH * 0.5 + 0.102)), Vector2(0.52, 0.12), Vector3(0, 0.0 if zf > 0.0 else PI, 0), _paint(Color(0.88, 0.88, 0.84)))
		var num := Label3D.new()
		num.text = PLATE
		num.font = load("res://assets/fonts/jersey10.fnt")
		num.font_size = 32
		num.pixel_size = 0.0028
		num.outline_size = 0
		num.modulate = Color(0.08, 0.08, 0.1)
		num.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		num.double_sided = false
		num.position = Vector3(0, 0, 0.004)
		plate.add_child(num)
	for x in [-1.0, 1.0]:
		# The arm forward from the roof's corner and down, the mirror hanging off its end.
		_box(_body, Vector3(x * (WIDTH * 0.5 + 0.04), BODY_HIGH - 0.12, -LENGTH * 0.5 - 0.14), Vector3(0.035, 0.035, 0.32), steel)
		_box(_body, Vector3(x * (WIDTH * 0.5 + 0.1), BODY_HIGH - 0.32, -LENGTH * 0.5 - 0.3), Vector3(0.035, 0.42, 0.035), steel)
		_box(_body, Vector3(x * (WIDTH * 0.5 + 0.12), BODY_HIGH - 0.66, -LENGTH * 0.5 - 0.3), Vector3(0.22, 0.36, 0.05), black)
	var card := _quad(_body, Vector3(WIDTH * 0.5 - 0.42, WINDSCREEN_Y.x + 0.16, -LENGTH * 0.5 + 0.05), Vector2(0.34, 0.22), Vector3(0, PI, 0), _paint(Color(0.9, 0.9, 0.86)))
	var line := Label3D.new()
	line.text = "380"
	line.font = load("res://assets/fonts/jersey10.fnt")
	line.font_size = 32
	line.pixel_size = 0.006
	line.outline_size = 0
	line.modulate = Color(0.06, 0.06, 0.08)
	line.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	line.double_sided = false
	line.position = Vector3(0, 0, 0.004)
	card.add_child(line)


## A side: its art (holes where the door and the arches are), and at night the windows
## lit from inside (karosa.py's mask of the windows, multiplied).
func _side_material(file: String) -> StandardMaterial3D:
	var m := _cut_material(file + ".png", Color(0.9, 0.88, 0.8))
	var lit := TEX + file + "_lit.png"
	if ResourceLoader.exists(lit):
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = load(lit)
		m.emission = Color(0, 0, 0)
	_sides.append(m)
	return m


func _cut_material(file: String, fallback: Color) -> StandardMaterial3D:
	var m := _tex_material(file, fallback)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	return m


func _loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


func _quad(parent: Node3D, pos: Vector3, size: Vector2, rot: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	parent.add_child(m)
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot: Vector3, segments := 10) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	m.mesh = c
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	parent.add_child(m)
	return m


func _paint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


func _tex_material(file: String, fallback: Color) -> StandardMaterial3D:
	var m := _paint(fallback)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(TEX + file):
		m.albedo_texture = load(TEX + file)
		m.albedo_color = Color.WHITE
	return m
