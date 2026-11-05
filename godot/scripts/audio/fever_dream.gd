extends Node

## Running for your life it gets into your head (the user 5. 11.: "the flashing faces out,
## they spoil the tension. Sound instead: when you are already running, a screaming in your
## ears, voices, bangs, a schizo fever dream that gets right into your brain"). No picture.
## The ears ring, louder the worse it is; splinters of the night's voices and blows you feel
## more than hear, a side at a time, quicker and quicker (tools/audiogen/fever_dream.py,
## assets/sfx/fever/). And they are heard, not played (the user 5. 11.: "more effects, reverbs,
## it sounds too little like hearing things and too much like playback"): each comes up out
## of nothing and stays in its own far hall, stretched, backwards, caught on a syllable, and
## here over all of it a space with no walls you could find, more of it the worse it is, and
## no pitch that holds still. nightmare_fx owns it and says how bad it is each frame: only
## the hunted warden's machine. Heard over the muffled world (nightmare_fx._update_muffle).

const DIR := "res://assets/sfx/fever/"
const VOICES := 12
const THUDS := 6
const BUS := "Fever"
const LEFT := "FeverL"
const RIGHT := "FeverR"
## How hard a side is panned (the sounds are in stereo themselves, their halls round you).
const PAN := 0.55
## The ears at nothing and at the worst.
const RING_DB := Vector2(-52.0, -13.0)
const SHARD_DB := Vector2(-26.0, -11.0)
## Seconds between splinters at the first of it and at the worst (they are long now, and
## lie over each other).
const EVERY := Vector2(3.4, 0.85)
const SHARD_PLAYERS := 6
## The space: how much of it at the first of it and at the worst.
const WET := Vector2(0.28, 0.62)
## No pitch holds still: how far a splinter wanders, how quickly.
const WANDER := 0.035
const WANDER_HZ := Vector2(0.15, 0.5)
## Below this nothing is said, the ears only.
const SHARDS_FROM := 0.14
## How often a splinter is a blow.
const THUD_SHARE := 0.28

var _level := 0.0
var _next := 0.0
var _ring: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
## Each player's pitch to wander round, how quickly, where it is in that.
var _wander: Array = []
var _verb: AudioEffectReverb
var _voices: Array = []
var _thuds: Array = []
var _side := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_buses()
	_ring = AudioStreamPlayer.new()
	_ring.name = "FeverRing"
	_ring.bus = BUS
	_ring.volume_db = RING_DB.x
	if ResourceLoader.exists(DIR + "ring.ogg"):
		_ring.stream = load(DIR + "ring.ogg")
	add_child(_ring)
	for i in SHARD_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.name = "FeverShard%d" % i
		p.bus = LEFT if i % 2 == 0 else RIGHT
		add_child(p)
		_players.append(p)
		_wander.append({"pitch": 1.0, "hz": 0.3, "at": 0.0})
	# Loaded now: the first splinter must not wait on its file.
	for i in VOICES:
		var path := DIR + "voice_%02d.ogg" % (i + 1)
		if ResourceLoader.exists(path):
			_voices.append(load(path))
	for i in THUDS:
		var path := DIR + "thud_%02d.ogg" % (i + 1)
		if ResourceLoader.exists(path):
			_thuds.append(load(path))


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
		var phaser := AudioEffectPhaser.new()
		phaser.range_min_hz = 220.0
		phaser.range_max_hz = 1800.0
		phaser.rate_hz = 0.13
		phaser.feedback = 0.45
		phaser.depth = 0.7
		AudioServer.add_bus_effect(i, phaser)
		var verb := AudioEffectReverb.new()
		verb.predelay_msec = 45.0
		verb.room_size = 0.92
		verb.damping = 0.55
		verb.spread = 1.0
		verb.hipass = 0.12
		verb.dry = 0.75
		verb.wet = WET.x
		AudioServer.add_bus_effect(i, verb)
	var bus := AudioServer.get_bus_index(BUS)
	for e in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, e) is AudioEffectReverb:
			_verb = AudioServer.get_bus_effect(bus, e)
	for side in [[LEFT, -PAN], [RIGHT, PAN]]:
		if AudioServer.get_bus_index(str(side[0])) >= 0:
			continue
		var k := AudioServer.bus_count
		AudioServer.add_bus(k)
		AudioServer.set_bus_name(k, str(side[0]))
		AudioServer.set_bus_send(k, BUS)
		var pan := AudioEffectPanner.new()
		pan.pan = float(side[1])
		AudioServer.add_bus_effect(k, pan)


## How far gone you are now (0..1): the world's muffle gives way to it.
func amount() -> float:
	return _level


## Each frame from nightmare_fx: `want` 0 nothing .. 1 running with it at your neck.
func tick(delta: float, want: float) -> void:
	_level = move_toward(_level, clampf(want, 0.0, 1.0), delta * (0.9 if want > _level else 0.4))
	if _ring.stream != null:
		if _level > 0.01 and not _ring.playing:
			_ring.play()
		elif _level <= 0.01 and _ring.playing:
			_ring.stop()
		_ring.volume_db = lerpf(RING_DB.x, RING_DB.y, sqrt(_level))
	if _verb != null:
		_verb.wet = lerpf(WET.x, WET.y, _level)
	_tick_wander(delta)
	if _level < SHARDS_FROM:
		_next = minf(_next, 0.5)
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = lerpf(EVERY.x, EVERY.y, _level) * _rng.randf_range(0.6, 1.5)
	_shard()


func _tick_wander(delta: float) -> void:
	for i in _players.size():
		var p := _players[i]
		if not p.playing:
			continue
		var w: Dictionary = _wander[i]
		w["at"] = float(w["at"]) + delta * float(w["hz"]) * TAU
		p.pitch_scale = float(w["pitch"]) * (1.0 + WANDER * sin(float(w["at"])))


func _shard() -> void:
	var pool: Array = _thuds if _rng.randf() < THUD_SHARE and not _thuds.is_empty() else _voices
	if pool.is_empty():
		return
	# From the other side than the last, mostly: it goes from ear to ear.
	if _rng.randf() < 0.8:
		_side = 1 - _side
	for i in range(_side, _players.size(), 2):
		var p := _players[i]
		if p.playing:
			continue
		p.stream = pool[_rng.randi() % pool.size()]
		_wander[i] = {"pitch": _rng.randf_range(0.86, 1.14), "hz": _rng.randf_range(WANDER_HZ.x, WANDER_HZ.y), "at": _rng.randf_range(0.0, TAU)}
		p.pitch_scale = float(_wander[i]["pitch"])
		p.volume_db = lerpf(SHARD_DB.x, SHARD_DB.y, _level) + _rng.randf_range(-3.0, 1.0)
		p.play()
		return


func stop_all() -> void:
	_level = 0.0
	if _ring != null:
		_ring.stop()
	for p in _players:
		p.stop()
