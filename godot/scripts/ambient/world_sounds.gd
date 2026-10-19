extends Node3D

## The camp's own sounds, from where they come from (ElevenLabs, assets/sfx/world/), on the
## outdoor bus (so a room muffles them like the rest of the outside):
##   - every lit lamp post buzzes, close under it (the nearest few);
##   - the generator thrums in its shed while the camp has power;
##   - the lake laps at the jetty, and at night the frogs start along the shore;
##   - in the wind the trees round you rustle and creak, a gust sweeps across now and then
##     (more and harder in a storm).
## Made by weather_visuals.gd in the camp's world, like the rain.

const SFX := "res://assets/sfx/world/"
const BUS := "OutdoorAmbience"
const LAMP_HUMS := 4

var player_getter: Callable

var _lamps: Dictionary = {}        # lamp instance id -> AudioStreamPlayer3D
var _gens: Dictionary = {}         # generator instance id -> AudioStreamPlayer3D
var _lake: AudioStreamPlayer3D
var _frogs: AudioStreamPlayer3D
var _wind: Array = []              # one-shot players for the trees and the gusts
var _wind_next := 0
var _gust_t := 6.0
var _scan_t := 0.0
var _poll_t := 0.0
var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}


func _ready() -> void:
	name = "WorldSounds"
	_rng.randomize()
	for i in 3:
		var p := AudioStreamPlayer3D.new()
		p.bus = BUS
		p.unit_size = 10.0
		p.max_distance = 70.0
		add_child(p)
		_wind.append(p)


func _stream(file: String, loop: bool) -> AudioStream:
	var key := file + ("#loop" if loop else "")
	if not _streams.has(key):
		var st = load(SFX + file) if ResourceLoader.exists(SFX + file) else null
		if loop and st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			(st as AudioStreamMP3).loop = true
		_streams[key] = st
	return _streams[key]


func _loop_player(parent: Node3D, file: String, at: Vector3, unit: float, max_d: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = BUS
	p.stream = _stream(file, true)
	p.unit_size = unit
	p.max_distance = max_d
	p.position = at
	p.volume_db = -80.0
	parent.add_child(p)
	return p


func _process(delta: float) -> void:
	var player: Node3D = player_getter.call() if player_getter.is_valid() else null
	if player == null:
		return
	var here := player.global_position
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 3.0
		_scan(here)
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 0.5
		_poll(here)
	_trees(delta, here)


## New lamps, generators and the jetty within earshot get their sound.
func _scan(here: Vector3) -> void:
	for n in get_tree().get_nodes_in_group("lamp_posts"):
		var lamp := n as Node3D
		if lamp == null or _lamps.has(lamp.get_instance_id()):
			continue
		if lamp.global_position.distance_to(here) > 40.0:
			continue
		_lamps[lamp.get_instance_id()] = _loop_player(lamp, "lamp_buzz.mp3", Vector3(0, 2.3, 0), 1.2, 12.0)
	var root := get_tree().current_scene
	if root == null:
		return
	var bm = root.get("building_manager")
	var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
	if structures != null:
		for c in structures.get_children():
			if str(c.get_meta("building_type", "")) != "power_generator" or _gens.has(c.get_instance_id()):
				continue
			_gens[c.get_instance_id()] = _loop_player(c as Node3D, "generator_thrum.mp3", Vector3(0, 1.0, 0), 3.0, 32.0)
	if _lake == null or not is_instance_valid(_lake):
		var jetty := root.find_child("Jetty", true, false) as Node3D
		if jetty != null:
			_lake = _loop_player(jetty, "lake_lapping.mp3", Vector3(0, 0.3, 4.0), 4.0, 30.0)
			_frogs = _loop_player(jetty, "frogs_night.mp3", Vector3(-12.0, 0.3, 2.0), 8.0, 70.0)


## What plays now: the lit lamps nearest you, the generator if there is power, the lake,
## the frogs at night.
func _poll(here: Vector3) -> void:
	var main := get_tree().current_scene
	var hour: float = float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 12.0
	var night := hour >= 20.5 or hour < 5.0
	# Lamps: the few nearest that are lit.
	var lit: Array = []
	for id in _lamps.keys():
		var p: AudioStreamPlayer3D = _lamps[id]
		if not is_instance_valid(p):
			_lamps.erase(id)
			continue
		var lamp := p.get_parent() as Node3D
		var on := false
		for l in lamp.find_children("*", "Light3D", true, false):
			if (l as Light3D).visible and (l as Light3D).light_energy > 0.05:
				on = true
				break
		if on:
			lit.append([lamp.global_position.distance_to(here), p])
		else:
			_set_loop(p, false, -80.0)
	lit.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for k in lit.size():
		_set_loop(lit[k][1], k < LAMP_HUMS, -16.0)
	# The generator, while the camp has power.
	var powered: bool = main == null or not main.has_method("_is_grid_powered") or bool(main.call("_is_grid_powered"))
	for id in _gens.keys():
		var g: AudioStreamPlayer3D = _gens[id]
		if not is_instance_valid(g):
			_gens.erase(id)
			continue
		_set_loop(g, powered, -10.0)
	if _lake != null and is_instance_valid(_lake):
		_set_loop(_lake, true, -12.0)
	if _frogs != null and is_instance_valid(_frogs):
		var day := int(main.get("_day_index")) if main != null and main.get("_day_index") != null else 1
		# Gone quiet in the last cold nights.
		_set_loop(_frogs, night and day < 24, -13.0)


func _set_loop(p: AudioStreamPlayer3D, on: bool, db: float) -> void:
	if p.stream == null:
		return
	if on:
		if not p.playing:
			p.play(_rng.randf() * 4.0)
		p.volume_db = db
	elif p.playing:
		p.stop()


## The trees round you in the wind: a rustle, a creak, a gust sweeping across.
func _trees(delta: float, here: Vector3) -> void:
	var main := get_tree().current_scene
	var w := int(main.get("_weather_state")) if main != null and main.get("_weather_state") != null else 0
	var wind: float = float({1: 0.8, 3: 0.35, 4: 0.55, 5: 1.0}.get(w, 0.12))
	# A wind that picks up does not wait out the calm's long pause.
	_gust_t = minf(_gust_t - delta, 14.0 / maxf(0.25, wind))
	if _gust_t > 0.0:
		return
	_gust_t = _rng.randf_range(5.0, 14.0) / maxf(0.25, wind)
	if wind < 0.3 and _rng.randf() < 0.6:
		return
	var roll := _rng.randf()
	var file := "trees_rustle.mp3"
	if wind >= 0.75 and roll < 0.35:
		file = "tree_creak.mp3"
	elif wind >= 0.5 and roll > 0.8:
		file = "wind_gust.mp3"
	var p: AudioStreamPlayer3D = _wind[_wind_next]
	_wind_next = (_wind_next + 1) % _wind.size()
	p.stream = _stream(file, false)
	if p.stream == null:
		return
	var a := _rng.randf() * TAU
	p.global_position = here + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(7.0, 16.0) + Vector3(0, 6.0, 0)
	p.volume_db = lerpf(-16.0, -6.0, clampf(wind, 0.0, 1.0)) + _rng.randf_range(-2.0, 1.0)
	p.pitch_scale = _rng.randf_range(0.92, 1.08)
	p.play()
