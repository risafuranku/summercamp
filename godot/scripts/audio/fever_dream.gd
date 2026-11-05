extends Node

## Running for your life it gets into your head (the user 5. 11.: "the flashing faces out,
## they spoil the tension. Sound instead: when you are already running, a screaming in your
## ears, voices, bangs, a schizo fever dream that gets right into your brain"). No picture.
## The ears ring, louder the worse it is; splinters of the night's voices and blows you feel
## more than hear, a side at a time, quicker and quicker (tools/audiogen/fever_dream.py,
## assets/sfx/fever/). nightmare_fx owns it and says how bad it is each frame: only the
## hunted warden's machine. Heard over the muffled world (nightmare_fx._update_muffle).

const DIR := "res://assets/sfx/fever/"
const VOICES := 12
const THUDS := 6
const BUS := "Fever"
const LEFT := "FeverL"
const RIGHT := "FeverR"
## How hard a side is panned.
const PAN := 0.85
## The ears at nothing and at the worst.
const RING_DB := Vector2(-52.0, -13.0)
const SHARD_DB := Vector2(-20.0, -7.0)
## Seconds between splinters at the first of it and at the worst.
const EVERY := Vector2(2.8, 0.42)
## Below this nothing is said, the ears only.
const SHARDS_FROM := 0.14
## How often a splinter is a blow.
const THUD_SHARE := 0.28

var _level := 0.0
var _next := 0.0
var _ring: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
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
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.name = "FeverShard%d" % i
		p.bus = LEFT if i % 2 == 0 else RIGHT
		add_child(p)
		_players.append(p)
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
	if _level < SHARDS_FROM:
		_next = minf(_next, 0.5)
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = lerpf(EVERY.x, EVERY.y, _level) * _rng.randf_range(0.6, 1.5)
	_shard()


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
		p.pitch_scale = _rng.randf_range(0.86, 1.14)
		p.volume_db = lerpf(SHARD_DB.x, SHARD_DB.y, _level) + _rng.randf_range(-3.0, 1.0)
		p.play()
		return


func stop_all() -> void:
	_level = 0.0
	if _ring != null:
		_ring.stop()
	for p in _players:
		p.stop()
