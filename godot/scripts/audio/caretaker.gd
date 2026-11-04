extends Node

## The song at the end of the world (the user, 4. 11.: "not only the pitch, reverb and echo
## too, the full The Caretaker feeling when you hide at night from the bogeymen").
##
## Hidden indoors at night with something out there, the worse the night and the longer it
## lasts, the more an old song comes to you from nowhere: no sound of the camp, the memory
## of one. A phrase of it, over and over, like a needle that cannot leave its groove, each
## turn a little slower and further off, in an enormous empty hall, the surface of the
## record close under it. Then a gap with only the hall in it, then another phrase, shorter.
## At the end the song is hardly more than what is left in the hall.
##
## `level` 0-1 is static: radio_dread reads it, the set in the room goes the same way, and
## with the set playing beside you this one keeps quiet (switched off, it does not). Each
## machine its own: what a warden hears in hiding the other does not. main ticks it.

const BUS := "Caretaker"
const DIR := "res://assets/sfx/radio/"
const SONGS := ["night_motif", "night_tancovacka2", "goodvibes_song", "night_vypinac", "night_tatinek"]
const CRACKLE := "res://assets/sfx/motel/record_crackle.ogg"
## How long it takes to come all the way, and to go.
const RISE_SEC := 70.0
const FALL_SEC := 12.0
## One turn of the groove into the next.
const XFADE := 0.7
const SILENT_DB := -70.0

static var level := 0.0

var main: Node
## >= 0 pins it (tools/caretaker_demo.gd).
var debug_level := -1.0

var _target := 0.0
var _poll := 0.0
var _rng := RandomNumberGenerator.new()
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _now: AudioStreamPlayer
var _gain_a := 0.0
var _gain_b := 0.0
var _crackle: AudioStreamPlayer
var _low: AudioEffectLowPassFilter
var _hall: AudioEffectReverb
var _echo: AudioEffectDelay
var _stream: AudioStream
var _phrase_at := 0.0
var _phrase_len := 6.0
var _turns := 0
var _turn_t := 0.0
var _pitch := 1.0
var _fade := 1.0
var _gap := 2.0
var _quiet := false


func _ready() -> void:
	_rng.randomize()
	level = 0.0
	_ensure_bus()
	_a = _player("CaretakerA", BUS)
	_b = _player("CaretakerB", BUS)
	_crackle = _player("CaretakerSurface", "Master")
	if ResourceLoader.exists(CRACKLE):
		var s = load(CRACKLE)
		if s is AudioStreamOggVorbis:
			s = (s as AudioStreamOggVorbis).duplicate()
			s.loop = true
		_crackle.stream = s


func _player(id: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = id
	p.bus = bus
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _ensure_bus() -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		i = AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 170.0
		AudioServer.add_bus_effect(i, hp)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 2600.0
		AudioServer.add_bus_effect(i, lp)
		var echo := AudioEffectDelay.new()
		echo.dry = 1.0
		echo.tap1_active = true
		echo.tap1_delay_ms = 460.0
		echo.tap2_active = true
		echo.tap2_delay_ms = 790.0
		echo.tap2_level_db = -24.0
		echo.feedback_active = true
		echo.feedback_delay_ms = 460.0
		echo.feedback_lowpass = 1200.0
		AudioServer.add_bus_effect(i, echo)
		var hall := AudioEffectReverb.new()
		hall.spread = 1.0
		hall.hipass = 0.1
		AudioServer.add_bus_effect(i, hall)
	for k in AudioServer.get_bus_effect_count(i):
		var fx := AudioServer.get_bus_effect(i, k)
		if fx is AudioEffectLowPassFilter:
			_low = fx
		elif fx is AudioEffectDelay:
			_echo = fx
		elif fx is AudioEffectReverb:
			_hall = fx


## How far it should have gone by now: hidden, and with something to hide from.
func _want() -> float:
	_quiet = false
	if debug_level >= 0.0:
		return debug_level
	if main == null or not main.has_method("caretaker_context"):
		return 0.0
	var c: Dictionary = main.caretaker_context()
	if not bool(c.get("night", false)) or bool(c.get("quiet", false)):
		return 0.0
	var hidden := 0.0
	match str(c.get("place", "")):
		"office", "back_room", "room", "modal":
			hidden = 1.0
		"out_dark":
			# Keeping still in the dark is hiding too, a little.
			hidden = 0.0 if bool(c.get("walking", false)) else 0.45
	var dread := float(c.get("dread", 0.0))
	var tension := float(c.get("tension", 0.0))
	var near := clampf((32.0 - float(c.get("near_m", INF))) / 24.0, 0.0, 1.0)
	_quiet = bool(c.get("set_beside", false))
	var threat := maxf(maxf(dread, tension), near)
	return hidden * smoothstep(0.1, 0.4, threat) * clampf(0.3 + dread * 1.1 + tension * 0.7 + near * 0.6, 0.0, 1.0)


func tick(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_target = _want()
	level = move_toward(level, _target, delta / (RISE_SEC if _target > level else FALL_SEC))
	if level <= 0.0 and _gain_a <= 0.0 and _gain_b <= 0.0 and not _crackle.playing:
		return
	_apply_fx()
	_tick_phrase(delta)
	_mix(delta)


func _apply_fx() -> void:
	if _low == null:
		return
	_low.cutoff_hz = lerpf(2600.0, 1000.0, level)
	_hall.room_size = lerpf(0.8, 0.97, level)
	_hall.damping = lerpf(0.55, 0.85, level)
	_hall.wet = lerpf(0.5, 0.9, level)
	_hall.dry = lerpf(0.55, 0.12, level)
	_hall.predelay_msec = lerpf(70.0, 190.0, level)
	_hall.predelay_feedback = lerpf(0.2, 0.5, level)
	_echo.tap1_level_db = lerpf(-20.0, -9.0, level)
	_echo.feedback_level_db = lerpf(-20.0, -9.0, level)


func _tick_phrase(delta: float) -> void:
	if level < 0.05 or _quiet:
		_now = null
		_gap = maxf(_gap, 1.0)
		return
	if _gap > 0.0:
		_gap -= delta
		if _gap <= 0.0:
			_new_phrase()
		return
	_turn_t += delta
	if _turn_t >= _phrase_len / _pitch - XFADE:
		_next_turn()


## Somewhere in one of the songs: longer the less far it has gone, slower the further.
func _new_phrase() -> void:
	var path := DIR + str(SONGS[_rng.randi() % SONGS.size()]) + ".mp3"
	if not ResourceLoader.exists(path):
		_gap = 2.0
		return
	_stream = load(path)
	var length: float = _stream.get_length()
	_phrase_len = lerpf(_rng.randf_range(7.0, 11.0), _rng.randf_range(1.6, 3.4), level)
	_phrase_at = _rng.randf_range(length * 0.08, maxf(length * 0.08, length * 0.85 - _phrase_len))
	_turns = _rng.randi_range(3, 5) + int(level * 7.0)
	_pitch = lerpf(0.98, 0.82, level) + _rng.randf_range(-0.01, 0.01)
	_fade = 1.0
	_start_turn()


func _start_turn() -> void:
	var next := _b if _now == _a else _a
	next.stream = _stream
	next.pitch_scale = _pitch
	next.play(_phrase_at)
	_now = next
	_turn_t = 0.0


## The needle back in the groove, a little slower, a little further off; or it lets go.
func _next_turn() -> void:
	_turns -= 1
	if _turns <= 0:
		_now = null
		_gap = _rng.randf_range(lerpf(9.0, 3.0, level), lerpf(22.0, 9.0, level))
		return
	_pitch -= 0.003 + 0.008 * level
	_fade *= 0.94
	_start_turn()


func _mix(delta: float) -> void:
	var base := lerpf(-31.0, -13.0, pow(level, 0.8))
	_gain_a = move_toward(_gain_a, _fade if _now == _a else 0.0, delta / XFADE)
	_gain_b = move_toward(_gain_b, _fade if _now == _b else 0.0, delta / XFADE)
	_a.volume_db = base + linear_to_db(_gain_a) if _gain_a > 0.002 else SILENT_DB
	_b.volume_db = base + linear_to_db(_gain_b) if _gain_b > 0.002 else SILENT_DB
	if _gain_a <= 0.002 and _a.playing and _now != _a:
		_a.stop()
	if _gain_b <= 0.002 and _b.playing and _now != _b:
		_b.stop()
	# The surface of the record, close, as long as there is any of this.
	if level > 0.05:
		if not _crackle.playing and _crackle.stream != null:
			_crackle.play()
		_crackle.volume_db = lerpf(-42.0, -25.0, level)
	elif _crackle.playing:
		_crackle.stop()
