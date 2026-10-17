extends Node3D

## The line 380 bus from outside: a Karosa as Build would have it, a textured box on
## four wheels (Grok faces in assets/textury/town/bus_*.png, composed by
## tools/artgen/town_art.py). Its front is -Z. The doors are on its right (+X); the
## front one opens (a dark gap, the leaves folded back in two steps) with a hiss.
## At night the windows glow from the strip lights inside and the headlights and the
## destination board are on. Wheels turn and the body rocks a little while it moves,
## in steps. town_trip.gd moves it along the roads and sets what it shows.
##
## It is solid (you walk round it) and, while its door is open, clickable
## (building_type "trip_bus", meta "stop" = which stop it stands at).

const TEX := "res://assets/textury/town/"
const SFX := "res://assets/sfx/bus/"
const LENGTH := 10.2
const WIDTH := 2.5
const BODY_LOW := 0.35
const BODY_HIGH := 3.0
const WHEEL_R := 0.5
## Where the wheels are along the bus (z), and the front door (z range), from the art.
const AXLES := [-3.6, 3.75]
const DOOR_Z := Vector2(-3.95, -3.2)
const DOOR_Y := Vector2(0.4, 2.55)

var destination := "LESNA" : set = _set_destination
var _sides: Array[StandardMaterial3D] = []
var _wheels: Array[MeshInstance3D] = []
var _door_gap: MeshInstance3D
var _door_leaves: Array[MeshInstance3D] = []
var _door_open := 0.0          # 0 shut .. 1 open
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
## The sides' materials with their window masks, made once.
static var _side_cache: Dictionary = {}


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


func open_door(open: bool) -> void:
	if open == (_door_target > 0.5):
		return
	_door_target = 1.0 if open else 0.0
	play(SFX + ("door_open.mp3" if open else "door_close.mp3"), -2.0)
	if _click != null:
		if open:
			_click.set_meta("building_type", "trip_bus")
		else:
			_click.remove_meta("building_type")


## How fast it goes (m/s): turns the wheels and rocks the body.
func set_speed(v: float) -> void:
	_speed = v


func set_night(night: bool) -> void:
	_night = night
	for m in _sides:
		m.emission = Color(1.0, 0.82, 0.5) * (0.9 if night else 0.0)
	for m in _lamps:
		m.emission = Color(1.0, 0.92, 0.7) * (2.4 if night else 0.2)
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
	# The door folds open (or shut) in two steps.
	_door_open = move_toward(_door_open, _door_target, delta * 2.4)
	var step := floorf(_door_open * 2.0) / 2.0
	if _door_gap != null:
		_door_gap.visible = step > 0.0
		for i in _door_leaves.size():
			var leaf := _door_leaves[i]
			var w := (DOOR_Z.y - DOOR_Z.x) * 0.5
			var side := -1.0 if i == 0 else 1.0
			leaf.scale.x = 1.0 - 0.75 * step
			leaf.position.z = (DOOR_Z.x + DOOR_Z.y) * 0.5 + side * w * (0.5 + 0.375 * step)
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


# ── the model ────────────────────────────────────────────────────────────────

func _build() -> void:
	var h := BODY_HIGH - BODY_LOW
	var mid_y := BODY_LOW + h * 0.5
	# The sides: the door side on the right (+X), its front at the art's right edge.
	var right := _side_material("bus_side_doors.png")
	var left := _side_material("bus_side.png")
	_quad(_body, Vector3(WIDTH * 0.5, mid_y, 0), Vector2(LENGTH, h), Vector3(0, PI * 0.5, 0), right)
	_quad(_body, Vector3(-WIDTH * 0.5, mid_y, 0), Vector2(LENGTH, h), Vector3(0, -PI * 0.5, 0), left)
	_quad(_body, Vector3(0, mid_y, -LENGTH * 0.5), Vector2(WIDTH, h), Vector3(0, PI, 0), _tex_material("bus_front.png", Color(0.85, 0.8, 0.7)))
	_quad(_body, Vector3(0, mid_y, LENGTH * 0.5), Vector2(WIDTH, h), Vector3.ZERO, _tex_material("bus_back.png", Color(0.85, 0.8, 0.7)))
	# Roof, its vents, the dark underside.
	_box(_body, Vector3(0, BODY_HIGH + 0.03, 0), Vector3(WIDTH - 0.02, 0.06, LENGTH - 0.02), _paint(Color(0.66, 0.64, 0.58)))
	for z in [-2.5, 1.5]:
		_box(_body, Vector3(0, BODY_HIGH + 0.11, z), Vector3(0.8, 0.1, 0.9), _paint(Color(0.5, 0.5, 0.48)))
	_box(_body, Vector3(0, BODY_LOW - 0.08, 0), Vector3(WIDTH - 0.1, 0.16, LENGTH - 0.3), _paint(Color(0.08, 0.08, 0.08)))
	# The door: a dark gap and two leaves that fold back.
	var dz := (DOOR_Z.x + DOOR_Z.y) * 0.5
	var dh := DOOR_Y.y - DOOR_Y.x
	_door_gap = _quad(_body, Vector3(WIDTH * 0.5 + 0.004, DOOR_Y.x + dh * 0.5, dz), Vector2(DOOR_Z.y - DOOR_Z.x, dh), Vector3(0, PI * 0.5, 0), _paint(Color(0.05, 0.05, 0.05)))
	_door_gap.visible = false
	for i in 2:
		var leaf := _quad(_body, Vector3(WIDTH * 0.5 + 0.008, DOOR_Y.x + dh * 0.5, dz), Vector2((DOOR_Z.y - DOOR_Z.x) * 0.5, dh), Vector3(0, PI * 0.5, 0), _paint(Color(0.55, 0.16, 0.12)))
		_door_leaves.append(leaf)
		# A glass panel in each leaf.
		var glass := _quad(leaf, Vector3(0, 0.25, 0.002), Vector2(0.22, dh * 0.5), Vector3.ZERO, _paint(Color(0.16, 0.18, 0.18)))
		glass.name = "Glass"
	# Wheels: dark octagons with a hub.
	var tyre := _paint(Color(0.07, 0.07, 0.07))
	var hub := _paint(Color(0.45, 0.45, 0.42))
	for z in AXLES:
		for side in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = WHEEL_R
			cyl.bottom_radius = WHEEL_R
			cyl.height = 0.32
			cyl.radial_segments = 8
			cyl.rings = 1
			w.mesh = cyl
			w.material_override = tyre
			var holder := Node3D.new()
			holder.position = Vector3(side * (WIDTH * 0.5 - 0.22), WHEEL_R, float(z))
			holder.rotation.z = PI * 0.5
			add_child(holder)
			holder.add_child(w)
			for face in [-0.17, 0.17]:
				_box(w, Vector3(0, face, 0), Vector3(0.36, 0.02, 0.36), hub)
			_wheels.append(w)
	# Lamps: headlights (and their beams at night), tail lights.
	for x in [-0.82, 0.82]:
		var head := StandardMaterial3D.new()
		head.albedo_color = Color(0.9, 0.88, 0.8)
		head.emission_enabled = true
		_lamps.append(head)
		_quad(_body, Vector3(x, BODY_LOW + 0.55, -LENGTH * 0.5 - 0.01), Vector2(0.2, 0.2), Vector3(0, PI, 0), head)
		var tail := StandardMaterial3D.new()
		tail.albedo_color = Color(0.6, 0.06, 0.04)
		tail.emission_enabled = true
		tail.emission = Color(0.9, 0.08, 0.04) * 0.6
		_quad(_body, Vector3(x * 1.1, BODY_LOW + 0.65, LENGTH * 0.5 + 0.01), Vector2(0.14, 0.14), Vector3.ZERO, tail)
	_beam = SpotLight3D.new()
	_beam.light_color = Color(1.0, 0.9, 0.7)
	_beam.light_energy = 2.2
	_beam.spot_range = 26.0
	_beam.spot_angle = 30.0
	_beam.position = Vector3(0, BODY_LOW + 0.6, -LENGTH * 0.5 - 0.2)
	_beam.rotation.x = deg_to_rad(-6.0)
	_beam.visible = false
	_body.add_child(_beam)
	# The destination board above the windscreen.
	_board = Label3D.new()
	_board.font = load("res://assets/fonts/jersey10.fnt")
	_board.font_size = 32
	_board.pixel_size = 0.004
	_board.outline_size = 0
	_board.modulate = Color(0.9, 0.62, 0.2)
	_board.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_board.position = Vector3(0, BODY_HIGH - 0.24, -LENGTH * 0.5 - 0.02)
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


## A side: the art, and at night the windows lit from inside (an emission mask made from
## the art: the glass in the top part of the side).
func _side_material(file: String) -> StandardMaterial3D:
	if _side_cache.has(file):
		var cached := (_side_cache[file] as StandardMaterial3D).duplicate() as StandardMaterial3D
		_sides.append(cached)
		return cached
	var m := _tex_material(file, Color(0.8, 0.7, 0.6))
	if m.albedo_texture != null:
		var img := m.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		var mask := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8)
		var glass_to := int(img.get_height() * 0.36)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				var lum := (c.r + c.g + c.b) / 3.0
				var sat := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
				var lit := y > 4 and y < glass_to and lum < 0.5 and sat < 0.12
				mask.set_pixel(x, y, Color(1, 1, 1) if lit else Color(0, 0, 0))
		m.emission_enabled = true
		# Multiply: the mask only says where the colour may show (add would light it always).
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = ImageTexture.create_from_image(mask)
		m.emission = Color(0, 0, 0)
	_side_cache[file] = m
	var own := m.duplicate() as StandardMaterial3D
	_sides.append(own)
	return own


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
