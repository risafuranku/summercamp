extends Node

## The hunt's own beat (the user 5. 11.: "cut parts of the rhythmic chaos into loops for
## chases and peaks, only for some specific enemies"). Loops cut out of Richard's hells on
## their own beat, a hit at both ends (tools: _sc/mesto/tools/find_loops.py and cut_loops.py;
## assets/sfx/chase/*.ogg, looped by their import):
##   basket    the Granny's hunt: the groove of peklo_chaosrhytmic (116 bpm); the nearer she
##             is the more of its harder half (a second loop of the same length, in step).
##             When she stops dead to straighten up and look, so does the music: the silence
##             is the warning to keep still. It comes back on a hit when she comes on.
##   stalker   the Antlered Man's charge: the brass band screaming (peklo_otevrikolena).
##   whistler  the Whistler's rush: the densest of the chaos; when he gets to where he heard
##             you it stops dead and he listens.
## nightmare_fx owns it: a brain calls fx.set_chase(id, level) each tick it runs at you
## (0..1; below 0 cuts it dead). Only the hunted warden's machine (remote_fx in co-op).

const LOOPS := {
	"basket": ["res://assets/sfx/chase/granny_a.ogg", "res://assets/sfx/chase/granny_b.ogg"],
	"stalker": ["res://assets/sfx/chase/antler.ogg"],
	"whistler": ["res://assets/sfx/chase/whistler.ogg"],
}
const BUS := "Chase"
## At full (the loops are -21 LUFS).
const TOP_DB := 2.0
const SILENT_DB := -70.0
## Out of a quiet stretch it fades this fast (s); cut dead at once.
const FADE_OUT := 0.45

var _want := {}
var _src := ""
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _level := 0.0
var _near := 0.0
var _cut := false
var _streams := {}


func _ready() -> void:
	_ensure_bus()
	_a = _player("ChaseA")
	_b = _player("ChaseB")
	# Loaded now: the first chase must not wait on its file.
	for k in LOOPS:
		for path in LOOPS[k]:
			if ResourceLoader.exists(path):
				_streams[path] = load(path)


func _player(id: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = id
	p.bus = BUS
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "AmbientMusic" if AudioServer.get_bus_index("AmbientMusic") >= 0 else "Master")


## Each tick from a brain: how hard it runs at you; `near` 0..1 brings in the harder loop.
func want(source: String, level: float, near := 0.0) -> void:
	var w: Array = _want.get(source, [-2.0, 0.0])
	if level > float(w[0]):
		_want[source] = [level, near]


func playing() -> bool:
	return _src != "" and _a.playing


func tick(delta: float) -> void:
	var best := ""
	var lv := 0.0
	var near := 0.0
	var cut := false
	for k in _want:
		var w: Array = _want[k]
		if float(w[0]) < 0.0 and k == _src:
			cut = true
		if float(w[0]) > lv:
			best = k
			lv = float(w[0])
			near = float(w[1])
	_want.clear()
	if cut and lv <= 0.0:
		_stop()
		return
	if best != "" and (best != _src or not _a.playing) and LOOPS.has(best):
		_start(best)
	if _src == "":
		return
	# In at once, on the loop's first hit; out quickly.
	_level = lv if lv > _level else move_toward(_level, lv, delta / FADE_OUT)
	# Its harder half in quickly as it closes, out slowly.
	_near = move_toward(_near, near, delta * (6.0 if near > _near else 1.2))
	if _level <= 0.001:
		_stop()
		return
	var g := _level
	var two := _b.stream != null
	_a.volume_db = TOP_DB + linear_to_db(maxf(g * (1.0 - 0.55 * _near if two else 1.0), 0.0001))
	if two:
		_b.volume_db = TOP_DB + linear_to_db(maxf(g * _near, 0.0001))


func _start(source: String) -> void:
	_src = source
	var list: Array = LOOPS[source]
	_a.stream = _streams.get(list[0])
	_b.stream = _streams.get(list[1]) if list.size() > 1 else null
	_level = 0.0
	_near = 0.0
	if _a.stream == null:
		_src = ""
		return
	_a.volume_db = SILENT_DB
	_a.play()
	if _b.stream != null:
		_b.volume_db = SILENT_DB
		_b.play()


func _stop() -> void:
	_src = ""
	_level = 0.0
	_a.stop()
	_b.stop()
	_a.volume_db = SILENT_DB
	_b.volume_db = SILENT_DB
