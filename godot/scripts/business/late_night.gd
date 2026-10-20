extends Node

## The night inside a business open late (DESIGN.md §7b, the evening shift): after 20:00
## the place is lit and open while the night goes on outside, and some of it gets in.
## Played by the night's director: the higher its tension (main._director), the more:
##   the tubes     buzz, and now and then flicker in steps
##   the radio     static creeps under the room (the dining room, the bar)
##   the cellar    something scrapes or knocks under the floor
##   the breaker   the lights go out for a few seconds, once a shift at most, and come back
##   a guest       one more at a table than came in, facing away, still, two small pale
##                 eyes in the dark of the face; gone at a flicker, or when you look at it
##                 a moment (a fast scare, rare: once a shift at most)
## Nothing here hurts; the warden in a place at night is still in the night's rules
## outside it. Made by scripts/service_interior.gd while you are in a place on its late
## shift; it is told the room and how to dim it.

const SFX_HUM := "res://assets/sfx/power/power_hum.mp3"
const SFX_FIZZ := "res://assets/sfx/director/lamp_fizz.mp3"
const SFX_STATIC := "res://assets/sfx/radio/nightnoise.mp3"
const SFX_TRIP := "res://assets/sfx/power/main_trip.mp3"
const SFX_BACK := "res://assets/sfx/power/power_back.mp3"
const SFX_BELOW := ["res://assets/sfx/director/wall_brush.mp3", "res://assets/sfx/director/knock.mp3", "res://assets/sfx/director/wet_steps.mp3"]
const FIGURES := ["res://assets/textury/npc/host1_sit.png", "res://assets/textury/npc/host2_sit.png", "res://assets/textury/npc/host_pensioner_sit.png", "res://assets/textury/npc/host_tramp_sit.png"]
const STEP := 1.0 / 12.0

## -> 0..1, the director's tension.
var tension_of: Callable
## (level 0..1) -> the room's light at that level (1 back to normal).
var dim: Callable
## -> Node3D: the room you are in (for the figure), and -> Array of [position, face] free
## seats in it.
var room_of: Callable
var seats_of: Callable
## -> Camera3D (to know when the figure is looked at).
var camera_of: Callable
## The place's room the static plays in ("dining", "main"): -> bool.
var front_room: Callable

var _t := 0.0
var _next := 10.0
var _flick := -1.0
var _dark := -1.0
var _broke := false
var _figure: Node3D
var _figure_t := 0.0
var _looked := 0.0
var _had_figure := false
var _hum: AudioStreamPlayer
var _static: AudioStreamPlayer
var _one: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_hum = _loop(SFX_HUM, -40.0)
	_static = _loop(SFX_STATIC, -60.0)
	_one = AudioStreamPlayer.new()
	add_child(_one)


func _loop(path: String, db: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.volume_db = db
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		a.stream = st
		a.autoplay = false
	add_child(a)
	if a.stream != null:
		a.play()
	return a


func _play(path: String, db: float, pitch := 1.0) -> void:
	if not ResourceLoader.exists(path):
		return
	_one.stream = load(path)
	_one.volume_db = db
	_one.pitch_scale = pitch
	_one.play()


func _tension() -> float:
	return clampf(float(tension_of.call()), 0.0, 1.0) if tension_of.is_valid() else 0.3


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	var k := _tension()
	# The tubes' buzz and the static, by the tension (in steps).
	_hum.volume_db = move_toward(_hum.volume_db, -26.0 + k * 10.0, delta * 8.0)
	var front := bool(front_room.call()) if front_room.is_valid() else true
	_static.volume_db = move_toward(_static.volume_db, (-30.0 + k * 12.0) if front and k > 0.3 else -60.0, delta * 6.0)
	if _dark >= 0.0:
		_dark -= delta
		if _dark < 0.0:
			_set_dim(1.0)
			_play(SFX_BACK, -12.0)
		return
	if _flick >= 0.0:
		_flick += delta
		var step := int(_flick / STEP)
		_set_dim([0.25, 1.0, 0.1, 0.8, 0.0, 1.0, 0.4, 1.0][mini(step, 7)])
		if step >= 8:
			_flick = -1.0
			_set_dim(1.0)
		if _figure != null and step == 4:
			_drop_figure()
	_watch_figure(delta)
	_next -= delta
	if _next > 0.0:
		return
	_next = lerpf(40.0, 12.0, k) * _rng.randf_range(0.7, 1.3)
	if _rng.randf() > 0.25 + k * 0.6:
		return
	var roll := _rng.randf()
	if k > 0.6 and not _broke and roll < 0.18:
		# The breaker: dark for a few seconds, once a shift.
		_broke = true
		_dark = _rng.randf_range(4.0, 7.0)
		_set_dim(0.0)
		_play(SFX_TRIP, -6.0)
	elif k > 0.5 and not _had_figure and front and roll < 0.32:
		_place_figure()
	elif k > 0.35 and roll < 0.6:
		_play(SFX_BELOW[_rng.randi() % SFX_BELOW.size()], -16.0 + k * 4.0, _rng.randf_range(0.85, 1.0))
	elif k > 0.15:
		_flick = 0.0
		_play(SFX_FIZZ, -10.0)


func _set_dim(level: float) -> void:
	if dim.is_valid():
		dim.call(level)


## One more at a table than came in: dark, still, two small pale eyes, facing away.
func _place_figure() -> void:
	var seats: Array = seats_of.call() if seats_of.is_valid() else []
	var room: Node3D = room_of.call() if room_of.is_valid() else null
	if seats.is_empty() or room == null:
		return
	_had_figure = true
	var seat: Array = seats[_rng.randi() % seats.size()]
	var f := Node3D.new()
	f.name = "LateFigure"
	var spr := Sprite3D.new()
	var path: String = FIGURES[_rng.randi() % FIGURES.size()]
	if not ResourceLoader.exists(path):
		return
	spr.texture = load(path)
	spr.pixel_size = 1.74 / 128.0
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = true
	# Turned away: the back of a figure is its own picture dark (they keep their colours,
	# the light does not reach them).
	spr.modulate = Color(0.16, 0.14, 0.14)
	spr.flip_h = true
	spr.offset = Vector2(0, spr.texture.get_height() * 0.5)
	f.add_child(spr)
	# The eyes: two pale points where the face would be, not lit, not shining.
	for dx in [-0.035, 0.035]:
		var e := Sprite3D.new()
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.82, 0.8, 0.74))
		e.texture = ImageTexture.create_from_image(img)
		e.pixel_size = 0.014
		e.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		e.shaded = false
		e.position = Vector3(dx, 1.06, 0.06)
		f.add_child(e)
	f.position = seat[0]
	room.add_child(f)
	_figure = f
	_figure_t = 0.0
	_looked = 0.0


## Looked at for a moment (or left too long): gone, the tubes stutter.
func _watch_figure(delta: float) -> void:
	if _figure == null or not is_instance_valid(_figure):
		_figure = null
		return
	_figure_t += delta
	var cam: Camera3D = camera_of.call() if camera_of.is_valid() else null
	if cam != null and not cam.is_position_behind(_figure.global_position + Vector3(0, 1.0, 0)):
		var to := (_figure.global_position + Vector3(0, 1.0, 0) - cam.global_position).normalized()
		if (-cam.global_basis.z).dot(to) > 0.94:
			_looked += delta
	if _looked > 1.2 or _figure_t > 14.0:
		_flick = 0.0
		_play(SFX_FIZZ, -6.0, 0.8)


func _drop_figure() -> void:
	if _figure != null and is_instance_valid(_figure):
		_figure.queue_free()
	_figure = null


func _exit_tree() -> void:
	_drop_figure()
	_set_dim(1.0)
