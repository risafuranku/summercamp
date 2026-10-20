extends Node

## Old Vondra runs you up to the camp in his Skoda 120 once she goes (hamlet_trip.gd: ask
## him by day after he has paid). The real road, like the 380's: out of his yard down the
## dusty track, onto road 12, past the Liblice masts, up the camp's lane to its stop
## (scripts/geo/). You sit beside him: his dash (karosa.py skoda_dash.png), the windscreen
## pillars, his wheel, and him at it from your side (Grok vondra_driving.png); his Czech
## on the way (bus_talk.tsv vd*), the engine's idle pitched up with the speed. The game's
## clock slows so it takes some six minutes. In at a door's dither, out at the stop.
## The car itself is the garage's (hamlet_podlesi.car_root): it drives the road and is
## back in the garage when you are out.

signal finished

const GEO = preload("res://scripts/geo/geo_data.gd")
const BALANCE = preload("res://core/balance/balance_config.gd")
const TEX := "res://assets/textury/town/"
const SFX := "res://assets/sfx/hamlet/"
const TALK := "res://assets/sfx/bus/talk/"
## Speeds (m/s): on the track, on the road; how hard it speeds up and brakes.
const TRACK_V := 6.5
const ROAD_V := 17.0
const ACCEL := 2.0
const BRAKE := 2.4
## How long the game's clock runs over the drive (minutes).
const GAME_MINUTES := 6.0
## In the car's frame (its front is -x, the driver on +z): your eye, his seat.
const EYE := Vector3(0.05, 1.18, -0.36)
const DRIVER := Vector3(0.12, 0.52, 0.36)

var trip
var place
var clock_scale := 1.0

var _car: Node3D
var _home_parent: Node
var _home_xf := Transform3D()
var _inside: Node3D
var _cam: Camera3D
var _path := PackedVector3Array()
var _dist := PackedFloat32Array()
var _track_len := 0.0
var _s := 0.0
var _v := 0.0
var _on := false
var _end_t := -1.0
var _said: Dictionary = {}
var _engine: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _rock_t := 0.0


func is_driving() -> bool:
	return _on


func eye() -> Vector3:
	return _car.global_position if _on and _car != null else Vector3.INF


func start() -> void:
	if _on or place == null or place.get("car_root") == null:
		return
	_car = place.car_root
	_build_path()
	if _path.size() < 2:
		return
	_on = true
	_s = 0.0
	_v = 0.0
	_end_t = -1.0
	_said.clear()
	var im = trip.get("_im")
	if im != null and im.has_method("_door_transition"):
		im._door_transition(true)
	trip._set_player_controls(false)
	# The car off its blocks in the garage onto the road, you in it.
	_home_parent = _car.get_parent()
	_home_xf = _car.transform
	var world: Node = place.get_parent()
	_car.reparent(world)
	_place_car()
	_build_inside()
	# Main picks the camera every frame: park this one where it looks (its debug_camera).
	var main = trip._main()
	if main != null:
		main.set("debug_camera", _cam)
	_cam.make_current()
	var vondra = place.get("vondra")
	if vondra != null:
		(vondra as Node3D).visible = false
	_engine = AudioStreamPlayer.new()
	add_child(_engine)
	var idle: AudioStream = load(SFX + "car_idle.mp3") if ResourceLoader.exists(SFX + "car_idle.mp3") else null
	if idle is AudioStreamMP3:
		(idle as AudioStreamMP3).loop = true
	_engine.stream = idle
	_engine.volume_db = -8.0
	_engine.play()
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	clock_scale = clampf(GAME_MINUTES / maxf(30.0, expected_seconds()) / BALANCE.GAME_MINUTES_PER_SECOND, 0.01, 1.0)


## The real seconds the drive takes at its speeds.
func expected_seconds() -> float:
	if _dist.is_empty():
		return 60.0
	return _track_len / TRACK_V + (_dist[_dist.size() - 1] - _track_len) / (ROAD_V * 0.85) + 8.0


## Out of the yard and down the track (the hamlet's frame), then the route to the camp:
## road 12 west, the camp's lane, its stop (as the 380 comes in).
func _build_path() -> void:
	_path = PackedVector3Array()
	for p in [Vector3(16.0, 0, 128.0), Vector3(9.0, 0, 121.0), Vector3(1.5, 0, 112.0), Vector3(0.5, 0, 100.0), Vector3(-2.5, 0, 70.0), Vector3(4.0, 0, 34.0), Vector3(1.2, 0, 10.0), Vector3(0.0, 0, 3.0)]:
		_path.append(place.w(p))
	_track_len = 0.0
	for i in range(1, _path.size()):
		_track_len += _path[i].distance_to(_path[i - 1])
	var s_p := GEO.stop_s("pristoupim")
	for p in GEO.line_path(s_p - 2.0, 62.0, 1.6, 4.0):
		if _path[_path.size() - 1].distance_to(p) > 0.6:
			_path.append(p)
	var road = trip._road()
	if road != null and road.has_method("bus_arrive_path"):
		for p in road.bus_arrive_path():
			if _path[_path.size() - 1].distance_to(p) > 0.6:
				_path.append(p)
	_dist = PackedFloat32Array()
	_dist.resize(_path.size())
	var acc := 0.0
	for i in _path.size():
		if i > 0:
			acc += _path[i].distance_to(_path[i - 1])
		_dist[i] = acc


func _point(d: float) -> Vector3:
	d = clampf(d, 0.0, _dist[_dist.size() - 1])
	for i in range(1, _path.size()):
		if _dist[i] >= d:
			var t := (d - _dist[i - 1]) / maxf(0.001, _dist[i] - _dist[i - 1])
			return _path[i - 1].lerp(_path[i], t)
	return _path[_path.size() - 1]


func _place_car() -> void:
	var p := _point(_s)
	var ahead := _point(_s + 3.0) - _point(_s - 1.5)
	ahead.y = 0.0
	if ahead.length() < 0.01:
		ahead = -_car.global_transform.basis.x
	ahead = ahead.normalized()
	# The car's front is its -x.
	var x := -ahead
	var z := x.cross(Vector3.UP)
	_rock_t += get_process_delta_time()
	var rock := sin(floorf(_rock_t * 12.0) * 0.8) * 0.004 * minf(1.0, _v / 6.0)
	_car.global_transform = Transform3D(Basis(x, Vector3.UP, z).rotated(ahead, rock), p)


func _process(delta: float) -> void:
	if not _on:
		return
	var total := _dist[_dist.size() - 1]
	var left := total - _s
	if _end_t < 0.0:
		var want := TRACK_V if _s < _track_len else ROAD_V
		# Slow for the end of the track and for the stop.
		if _s < _track_len:
			want = minf(want, sqrt(2.0 * BRAKE * maxf(0.0, _track_len - _s)) + 4.0)
		want = minf(want, sqrt(2.0 * BRAKE * maxf(0.0, left)))
		_v = move_toward(_v, want, (ACCEL if want > _v else BRAKE) * delta)
		_s = minf(total, _s + _v * delta)
		if left < 0.3 and _v < 0.3:
			_end_t = 0.0
			_line("vd5")
	else:
		_end_t += delta
		if _end_t > 3.6:
			_finish()
			return
	_place_car()
	if _engine != null:
		_engine.pitch_scale = 0.85 + clampf(_v / ROAD_V, 0.0, 1.0) * 0.75
	# His lines on the way: as she pulls off, on the twelve, by the masts, near the end.
	var frac := _s / maxf(1.0, total)
	if _s > 4.0:
		_line("vd1")
	if _s > _track_len + 300.0:
		_line("vd2")
	if frac > 0.55:
		_line("vd3")
	if frac > 0.84:
		_line("vd4")


func _line(key: String) -> void:
	if _said.has(key):
		return
	if _voice != null and _voice.playing and key != "vd5":
		return
	_said[key] = true
	var en := ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(TALK + "talk.json")) if FileAccess.file_exists(TALK + "talk.json") else null
	if data is Dictionary:
		var lines: Array = (data as Dictionary).get("scenes", {}).get(key, [])
		if not lines.is_empty():
			en = str(lines[0]["en"])
	var path := TALK + key + "_1.mp3"
	if ResourceLoader.exists(path) and _voice != null:
		_voice.stream = load(path)
		_voice.volume_db = -2.0
		_voice.play()
	if en != "":
		trip._quote("Vondra", en)


## Out at the camp's stop: the dither, you on the slab, the car home in the garage.
func _finish() -> void:
	_on = false
	var im = trip.get("_im")
	if im != null and im.has_method("_door_transition"):
		im._door_transition(false)
	var road = trip._road()
	if road != null and road.has_method("wait_spot"):
		trip._put_player(road.wait_spot())
	var main = trip._main()
	if main != null and main.get("debug_camera") == _cam:
		main.set("debug_camera", null)
	if _inside != null and is_instance_valid(_inside):
		_inside.queue_free()
	_inside = null
	if _car != null and is_instance_valid(_car) and _home_parent != null and is_instance_valid(_home_parent):
		_car.reparent(_home_parent)
		_car.transform = _home_xf
	var vondra = place.get("vondra") if place != null else null
	if vondra != null and is_instance_valid(vondra):
		(vondra as Node3D).visible = true
	for p in [_engine, _voice]:
		if p != null and is_instance_valid(p):
			p.queue_free()
	_engine = null
	_voice = null
	clock_scale = 1.0
	trip._set_player_controls(true)
	finished.emit()


# ── inside the Skoda ─────────────────────────────────────────────────────────

func _build_inside() -> void:
	_inside = Node3D.new()
	_inside.name = "SkodaInside"
	_car.add_child(_inside)
	var plastic := _mat("", Color(0.22, 0.22, 0.21))
	var trim := _mat("", Color(0.5, 0.52, 0.42))
	var cloth := _mat("", Color(0.36, 0.3, 0.24))
	var liner := _mat("", Color(0.62, 0.6, 0.54))
	# The dash under the windscreen, its face to you.
	_box(Vector3(-0.92, 0.88, 0.0), Vector3(0.42, 0.28, 1.5), plastic)
	var dash := _mat(TEX + "skoda_dash.png", Color(1, 1, 1))
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.4, 0.34)
	q.mesh = qm
	q.material_override = dash
	q.position = Vector3(-0.705, 0.86, 0.0)
	q.rotation = Vector3(0, PI * 0.5, 0)
	_inside.add_child(q)
	# The windscreen's frame (open: the road through it), the roof, the doors, the seats.
	for z in [-0.74, 0.74]:
		var pillar := _box(Vector3(-0.98, 1.3, z), Vector3(0.07, 0.62, 0.07), trim)
		pillar.rotation.z = deg_to_rad(-34.0)
		_box(Vector3(0.0, 0.72, z * 1.04), Vector3(1.9, 0.62, 0.06), trim)
		_box(Vector3(0.0, 1.03, z * 1.04), Vector3(1.9, 0.04, 0.09), plastic)
		_box(Vector3(0.65, 1.32, z * 1.04), Vector3(0.08, 0.58, 0.08), trim)
	_box(Vector3(-0.2, 1.6, 0.0), Vector3(2.0, 0.05, 1.56), liner)
	_box(Vector3(-1.12, 1.56, 0.0), Vector3(0.12, 0.06, 1.56), trim)
	for z in [-0.36, 0.36]:
		_box(Vector3(0.42, 0.45, z), Vector3(0.5, 0.12, 0.5), cloth)
		_box(Vector3(0.68, 0.82, z), Vector3(0.12, 0.66, 0.5), cloth)
	# His wheel: thin, black, on its column.
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.195
	torus.rings = 18
	torus.ring_segments = 6
	wheel.mesh = torus
	wheel.material_override = _mat("", Color(0.06, 0.06, 0.06))
	# Where his fists are in the picture.
	wheel.position = Vector3(-0.27, 0.86, 0.36)
	# Its axis up and back toward him: the rim's top leans to the windscreen.
	wheel.rotation = Vector3(0, 0, deg_to_rad(-62.0))
	_inside.add_child(wheel)
	_box(Vector3(-0.52, 0.8, 0.36), Vector3(0.44, 0.05, 0.05), _mat("", Color(0.1, 0.1, 0.1))).rotation.z = deg_to_rad(12.0)
	# Him at it, seen from your seat (his right side).
	var drv := TEX + "vondra_driving.png"
	if ResourceLoader.exists(drv):
		var s := Sprite3D.new()
		s.texture = load(drv)
		var h := float(s.texture.get_height())
		s.pixel_size = 0.92 / h
		s.offset = Vector2(0.0, h * 0.5)
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		s.position = DRIVER
		# Facing you: the picture's plane across the car, its right toward the front.
		s.rotation.y = PI
		_inside.add_child(s)
	_cam = Camera3D.new()
	_cam.position = EYE
	# Ahead, a little turned toward him: his arm and his wheel at the left of the view.
	_cam.rotation = Vector3(deg_to_rad(-7.0), PI * 0.5 + 0.42, 0.0)
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 1000.0
	_inside.add_child(_cam)


func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	_inside.add_child(mi)
	return mi


func _mat(path: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	return m
