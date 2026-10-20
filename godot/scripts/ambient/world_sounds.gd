extends Node3D

## The camp's own sounds, from where they come from (ElevenLabs, assets/sfx/world/), on the
## outdoor bus (so a room muffles them like the rest of the outside):
##   - every lit lamp post buzzes, close under it (the nearest few);
##   - the generator thrums in its shed while the camp has power;
##   - the lake laps at the jetty, and at night the frogs start along the shore;
##   - in the wind the trees round you rustle and creak, a gust sweeps across now and then
##     (more and harder in a storm);
##   - the flagpole's rope clanks against the pole in the wind, the harder it blows the
##     more often;
##   - the toilet and the shower block: a tap drips, and at night (while there is power)
##     the fluorescent tube inside buzzes;
##   - after the rain, while the ground is still wet, water drips off the eaves of the
##     buildings near you, slower as it dries;
##   - in the rain, by what it falls on: it drums on the tin roofs of the buildings near
##     you and patters on the tents' canvas, hisses on the lake by the jetty, crackles in
##     the trees over you.
## Made by weather_visuals.gd in the camp's world, like the rain.

const SFX := "res://assets/sfx/world/"
const BUS := "OutdoorAmbience"
const LAMP_HUMS := 4
## The rooms' drip (room_weather.gd), off the eaves after the rain here; the rain on a
## tent's canvas (room_weather.gd's too), from outside here.
const DRIP := "res://assets/sfx/weather/roof_drip.mp3"
const RAIN_CANVAS := "res://assets/sfx/weather/rain_canvas.mp3"

var player_getter: Callable

var _lamps: Dictionary = {}        # lamp instance id -> AudioStreamPlayer3D
var _gens: Dictionary = {}         # generator instance id -> AudioStreamPlayer3D
var _flags: Dictionary = {}        # flagpole instance id -> {player, t}
var _washrooms: Dictionary = {}    # block instance id -> {tube, drip}
var _eaves: Array = []             # one-shot players for the drips after the rain
var _rain_spots: Array = []        # the rain on the nearest roofs and canvas
var _rain_lake: AudioStreamPlayer3D
var _rain_trees: AudioStreamPlayer3D
var _eaves_t := 2.0
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
			var bt := str(c.get_meta("building_type", ""))
			var id := c.get_instance_id()
			if bt == "power_generator" and not _gens.has(id):
				_gens[id] = _loop_player(c as Node3D, "generator_thrum.mp3", Vector3(0, 1.0, 0), 3.0, 32.0)
			elif bt == "flagpole" and not _flags.has(id):
				var fp := AudioStreamPlayer3D.new()
				fp.bus = BUS
				fp.unit_size = 4.0
				fp.max_distance = 40.0
				fp.position = Vector3(0, 4.5, 0)
				(c as Node3D).add_child(fp)
				_flags[id] = {"player": fp, "t": _rng.randf_range(1.0, 4.0)}
			elif (bt == "toilet_block" or bt == "shower_block") and not _washrooms.has(id):
				_washrooms[id] = {"tube": _loop_player(c as Node3D, "tube_buzz.mp3", Vector3(0, 2.0, 0), 1.0, 10.0),
					"drip": _loop_player(c as Node3D, "tap_drip.mp3", Vector3(0, 1.0, 0), 0.8, 8.0)}
	if _lake == null or not is_instance_valid(_lake):
		# The jetty's body sits at the lake's origin: its deck is where the jetty is.
		var jetty := root.find_child("Jetty", true, false) as Node3D
		var deck: Node3D = jetty.get_node_or_null("Deck") as Node3D if jetty != null else null
		if deck != null:
			var at := deck.position
			_lake = _loop_player(jetty, "lake_lapping.mp3", at + Vector3(0, -0.1, 4.0), 4.0, 30.0)
			_rain_lake = _loop_player(jetty, "rain_lake.mp3", at + Vector3(0, 0.2, 8.0), 6.0, 40.0)
			_frogs = _loop_player(jetty, "frogs_night.mp3", at + Vector3(-12.0, -0.1, 2.0), 8.0, 70.0)


## What plays now: the lit lamps nearest you, the generator if there is power, the lake,
## the frogs at night.
func _poll(here: Vector3) -> void:
	var main := get_tree().current_scene
	var hour: float = float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 12.0
	var night := hour >= 20.5 or hour < 5.0
	# Lamps: the few nearest that are lit.
	var lit: Array = []
	for id in _lamps.keys():
		var p = _lamps[id]
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
		# Untyped first: a generator taken down since is a freed instance, and assigning
		# that to a typed variable is an error before is_instance_valid can look at it.
		var g = _gens[id]
		if not is_instance_valid(g):
			_gens.erase(id)
			continue
		_set_loop(g, powered, -10.0)
	for id in _washrooms.keys():
		var wr: Dictionary = _washrooms[id]
		if not is_instance_valid(wr["tube"]):
			_washrooms.erase(id)
			continue
		_set_loop(wr["tube"], night and powered, -18.0)
		_set_loop(wr["drip"], true, -22.0)
	_rain_by_surface(here, main)
	if _lake != null and is_instance_valid(_lake):
		_set_loop(_lake, true, -12.0)
	if _frogs != null and is_instance_valid(_frogs):
		var day := int(main.get("_day_index")) if main != null and main.get("_day_index") != null else 1
		# Gone quiet in the last cold nights.
		_set_loop(_frogs, night and day < 24, -13.0)


## The rain by what it falls on: the tin roofs and the tents' canvas of the three buildings
## nearest you, the lake by the jetty, the nearest tree over you.
func _rain_by_surface(here: Vector3, main: Node) -> void:
	var w := int(main.get("_weather_state")) if main != null and main.get("_weather_state") != null else 0
	var sl = main.get("_season_look") if main != null else null
	var snowing: bool = sl != null and sl.has_method("is_snowing") and bool(sl.is_snowing())
	var raining := w >= 3 and w <= 5 and not snowing
	var db: float = float({3: -17.0, 4: -11.0, 5: -8.0}.get(w, -80.0))
	if _rain_spots.is_empty():
		for i in 3:
			var rp := AudioStreamPlayer3D.new()
			rp.bus = BUS
			rp.unit_size = 3.0
			rp.max_distance = 22.0
			add_child(rp)
			_rain_spots.append(rp)
	var near: Array = []
	if raining:
		var bm = main.get("building_manager")
		var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
		if structures != null:
			for c in structures.get_children():
				var bt := str(c.get_meta("building_type", ""))
				if bt == "" or bt in ["path", "lamp_post", "flagpole", "bench", "gnome", "flower_bed", "picnic_table", "bonfire", "sports_field", "hammock"]:
					continue
				var d := (c as Node3D).global_position.distance_to(here)
				if d < 18.0:
					near.append([d, c, bt])
		near.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for i in _rain_spots.size():
		var rp: AudioStreamPlayer3D = _rain_spots[i]
		if i >= near.size():
			if rp.playing:
				rp.stop()
			continue
		var path := RAIN_CANVAS if str(near[i][2]).begins_with("tent") else SFX + "rain_tin.mp3"
		var st := _loop_stream(path)
		if rp.stream != st:
			rp.stream = st
			rp.stop()
		rp.global_position = (near[i][1] as Node3D).global_position + Vector3(0, 2.4, 0)
		if st != null and not rp.playing:
			rp.play(_rng.randf() * 4.0)
		rp.volume_db = db
	if _rain_lake != null and is_instance_valid(_rain_lake):
		_set_loop(_rain_lake, raining, db + 1.0)
	# The trees: the nearest within twelve metres.
	if _rain_trees == null:
		_rain_trees = AudioStreamPlayer3D.new()
		_rain_trees.bus = BUS
		_rain_trees.unit_size = 4.0
		_rain_trees.max_distance = 24.0
		_rain_trees.stream = _stream("rain_leaves.mp3", true)
		add_child(_rain_trees)
	var tree_at := Vector3.INF
	if raining:
		var best := 12.0
		for t in get_tree().get_nodes_in_group("trees"):
			var tp := (t as Node3D).global_position if t is Node3D else Vector3.INF
			var td := Vector2(tp.x - here.x, tp.z - here.z).length()
			if td < best:
				best = td
				tree_at = tp
	if tree_at != Vector3.INF:
		_rain_trees.global_position = tree_at + Vector3(0, 4.0, 0)
	_set_loop(_rain_trees, tree_at != Vector3.INF, db - 2.0)


func _loop_stream(path: String) -> AudioStream:
	if not _streams.has(path):
		var st = load(path) if ResourceLoader.exists(path) else null
		if st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			(st as AudioStreamMP3).loop = true
		_streams[path] = st
	return _streams[path]


## After the rain: drips off the eaves of the buildings near you while the ground is wet.
func _after_rain(delta: float, here: Vector3, w: int) -> void:
	_eaves_t -= delta
	if _eaves_t > 0.0:
		return
	var main := get_tree().current_scene
	var sl = main.get("_season_look") if main != null else null
	var wet: float = float(sl.get("wet")) if sl != null and sl.get("wet") != null else 0.0
	_eaves_t = lerpf(6.0, 1.2, clampf((wet - 0.2) / 0.6, 0.0, 1.0)) * _rng.randf_range(0.7, 1.3)
	# While it rains the rain covers it; dry, nothing drips.
	if w >= 3 or wet < 0.2:
		return
	var bm = main.get("building_manager")
	var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
	if structures == null:
		return
	var near: Array = []
	for c in structures.get_children():
		var bt := str(c.get_meta("building_type", ""))
		if bt == "" or bt == "path" or bt == "lamp_post" or bt == "flagpole":
			continue
		var d := (c as Node3D).global_position.distance_to(here)
		if d < 16.0:
			near.append([d, c])
	if near.is_empty():
		return
	near.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var b3: Node3D = near[_rng.randi() % mini(3, near.size())][1]
	if _eaves.is_empty():
		for i in 2:
			var ep := AudioStreamPlayer3D.new()
			ep.bus = BUS
			ep.unit_size = 1.5
			ep.max_distance = 16.0
			add_child(ep)
			_eaves.append(ep)
	var p: AudioStreamPlayer3D = _eaves[_rng.randi() % _eaves.size()]
	if not _streams.has(DRIP):
		_streams[DRIP] = load(DRIP) if ResourceLoader.exists(DRIP) else null
	p.stream = _streams[DRIP]
	if p.stream == null:
		return
	var a := _rng.randf() * TAU
	p.global_position = b3.global_position + Vector3(cos(a) * 2.0, 2.2, sin(a) * 2.0)
	p.volume_db = lerpf(-22.0, -12.0, clampf(wet, 0.0, 1.0)) + _rng.randf_range(-2.0, 1.0)
	p.pitch_scale = _rng.randf_range(0.9, 1.1)
	p.play()


## The flag's rope clanking on its pole: more often the harder it blows, hardly in a calm.
func _flagpoles(delta: float, wind: float) -> void:
	for id in _flags.keys():
		var f: Dictionary = _flags[id]
		var p: AudioStreamPlayer3D = f["player"]
		if not is_instance_valid(p):
			_flags.erase(id)
			continue
		f["t"] = float(f["t"]) - delta
		if float(f["t"]) > 0.0:
			continue
		f["t"] = _rng.randf_range(2.0, 7.0) / maxf(0.15, wind)
		if wind < 0.3 and _rng.randf() < 0.7:
			continue
		p.stream = _stream("flag_clank_a.mp3" if _rng.randf() < 0.5 else "flag_clank_b.mp3", false)
		if p.stream == null:
			continue
		p.volume_db = lerpf(-20.0, -9.0, clampf(wind, 0.0, 1.0)) + _rng.randf_range(-2.0, 1.0)
		p.pitch_scale = _rng.randf_range(0.94, 1.06)
		p.play()


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
	_flagpoles(delta, wind)
	_after_rain(delta, here, w)
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
