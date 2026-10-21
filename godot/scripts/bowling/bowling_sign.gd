extends Node3D

## The bowling alley's neon KUŽELKY and its coloured bulbs (building_models._bowling): out
## by day (dull red glass on its brackets), on with the camp's lamps (BuildingManager
## `_lamps_active`: dusk, and the power on). A neon tube starts with a stutter, hums while
## it burns (bowling/neon_hum.mp3, close by), and every so often it catches and cuts out
## for a moment with a crackle (neon_flicker.mp3). Steps twelve a second, like the camp's
## other machinery.

const HUM := "res://assets/sfx/bowling/neon_hum.mp3"
const CRACKLE := "res://assets/sfx/bowling/neon_flicker.mp3"
const STEP := 1.0 / 12.0
const NEON_ENERGY := 3.6
const LIGHT_ENERGY := 2.4
const BULB_ENERGY := 1.4

var neon: StandardMaterial3D
var bulbs: Array = []           # StandardMaterial3D, one a colour
var light: OmniLight3D
var _hum: AudioStreamPlayer3D
var _crackle: AudioStreamPlayer3D
var _acc := 0.0
var _on := false
var _stutter: Array = []        # levels still to step through (a start or a catch)
var _next_catch := 30.0
var _rng := RandomNumberGenerator.new()


func setup(p_neon: StandardMaterial3D, p_bulbs: Array, p_light: OmniLight3D) -> void:
	neon = p_neon
	bulbs = p_bulbs
	light = p_light
	_rng.seed = hash(str(get_instance_id()))
	_next_catch = _rng.randf_range(20.0, 60.0)
	_hum = _player(HUM, true)
	_crackle = _player(CRACKLE, false)
	_apply(0.0)


func _player(path: String, loop: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if ResourceLoader.exists(path):
		var s = load(path)
		if loop and s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			(s as AudioStreamMP3).loop = true
		p.stream = s
	p.unit_size = 2.5
	p.max_distance = 22.0
	p.bus = "OutdoorAmbience" if AudioServer.get_bus_index("OutdoorAmbience") >= 0 else "Master"
	add_child(p)
	return p


func _process(delta: float) -> void:
	_acc += delta
	if _acc < STEP:
		return
	var dt := _acc
	_acc = 0.0
	var want := _lamps_on()
	if want != _on:
		_on = want
		_stutter.clear()
		if _on:
			# A cold tube: it catches two or three times before it holds.
			for i in _rng.randi_range(2, 4):
				_stutter.append_array([1.0, 0.0, 0.0] if _rng.randf() < 0.6 else [0.6, 0.0])
			_play_crackle()
	var level := 1.0 if _on else 0.0
	if not _stutter.is_empty():
		level = float(_stutter.pop_front())
	elif _on:
		_next_catch -= dt
		if _next_catch <= 0.0:
			_next_catch = _rng.randf_range(25.0, 80.0)
			for i in _rng.randi_range(3, 9):
				_stutter.append(0.0 if _rng.randf() < 0.55 else _rng.randf_range(0.4, 1.0))
			_play_crackle()
	_apply(level)


func _apply(level: float) -> void:
	if neon != null:
		neon.emission_energy_multiplier = NEON_ENERGY * level
	if light != null:
		light.light_energy = LIGHT_ENERGY * level
		light.visible = level > 0.01
	for b in bulbs:
		(b as StandardMaterial3D).emission_energy_multiplier = BULB_ENERGY if _on else 0.0
	if _hum != null and _hum.stream != null:
		if _on and not _hum.playing:
			_hum.play(_rng.randf() * 2.0)
		elif not _on and _hum.playing:
			_hum.stop()
		_hum.volume_db = lerpf(-30.0, -14.0, level)


func _play_crackle() -> void:
	if _crackle != null and _crackle.stream != null:
		_crackle.volume_db = -12.0
		_crackle.pitch_scale = _rng.randf_range(0.92, 1.08)
		_crackle.play()


## The camp's lamps (dusk, the power on): BuildingManager's own flag.
func _lamps_on() -> bool:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var bm = scene.get("building_manager") if scene != null else null
	return bm != null and bool(bm.get("_lamps_active"))
