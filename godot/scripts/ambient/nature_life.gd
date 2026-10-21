extends Node

## The country round the camp by the hour and the place (made by weather_visuals.gd beside
## far_life.gd), the day's half of what the crickets, the frogs and the owl are at night
## (ElevenLabs, assets/sfx/nature/):
##   - the dawn chorus (4:45-8:30), loudest by the trees, gone by the meadow's middle;
##   - birds now and then in the trees by day (8:00-18:30), near the trees;
##   - grasshoppers in the meadow at the warm of the day (10:00-17:30), out in the open
##     away from the trees; fewer as the autumn goes on, none in the last third;
##   - a crow from a tree, ducks out on the lake when you are near the water, each now
##     and then (no woodpecker: the user 21. 10., "it sounds wrong").
## Rain and the storm drown it all and fog halves the birds. It is on the night insects'
## bus, so a presence hushes it like the crickets (audio_manager.set_insect_hush), and a
## room muffles it like the rest of the outside. Each machine hears its own.

const SFX := "res://assets/sfx/nature/"
const BUS := "NightInsects"
const BUS_FALLBACK := "OutdoorAmbience"
const SILENT_DB := -60.0
## Loops: file, its loudness at full (dB).
const LOOPS := {
	"dawn": ["dawn_chorus.mp3", -9.0],
	"birds": ["day_birds.mp3", -12.0],
	"hoppers": ["grasshoppers.mp3", -15.0],
}

var player_getter: Callable

var _loops: Dictionary = {}       # name -> AudioStreamPlayer
var _level: Dictionary = {}       # name -> 0..1 now
var _shots: Array = []
var _next_shot := 0
var _shot_t := 20.0
var _near_t := 0.0
var _tree_d := 30.0               # how far the nearest tree is (looked up every 2 s)
var _lake_at := Vector3.INF
var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}


func _ready() -> void:
	name = "NatureLife"
	_rng.randomize()
	var bus := BUS if AudioServer.get_bus_index(BUS) >= 0 else BUS_FALLBACK
	for k in LOOPS:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = SILENT_DB
		var st = _stream(str(LOOPS[k][0]))
		if st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			(st as AudioStreamMP3).loop = true
		p.stream = st
		add_child(p)
		_loops[k] = p
		_level[k] = 0.0
	for i in 2:
		var s := AudioStreamPlayer3D.new()
		s.bus = bus
		s.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		s.max_distance = 200.0
		add_child(s)
		_shots.append(s)


func _stream(file: String) -> AudioStream:
	if not _streams.has(file):
		_streams[file] = load(SFX + file) if ResourceLoader.exists(SFX + file) else null
	return _streams[file]


func _process(delta: float) -> void:
	var player: Node3D = player_getter.call() if player_getter.is_valid() else null
	var main := get_tree().current_scene
	if player == null or main == null or main.get("_time_of_day_hours") == null:
		return
	var hour := float(main.get("_time_of_day_hours"))
	var day := int(main.get("_day_index")) if main.get("_day_index") != null else 1
	var w := int(main.get("_weather_state")) if main.get("_weather_state") != null else 0
	var here := player.global_position
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = 2.0
		_tree_d = _nearest_tree(here)
		if _lake_at == Vector3.INF:
			_lake_at = _find_lake(main)
	var autumn := Season.progress(day, hour)
	var want := wants(hour, w, autumn, _tree_d)
	for k in _loops:
		_level[k] = move_toward(float(_level[k]), float(want[k]), delta * 0.08)
		var p: AudioStreamPlayer = _loops[k]
		var lv := float(_level[k])
		if lv <= 0.01:
			if p.playing:
				p.stop()
			continue
		p.volume_db = float(LOOPS[k][1]) + linear_to_db(lv)
		if not p.playing and p.stream != null:
			p.play(_rng.randf() * 5.0)
	_shot_t -= delta
	if _shot_t <= 0.0:
		_shot_t = _rng.randf_range(18.0, 45.0)
		_one_shot(hour, w, here)


## How loud each loop wants to be (0..1) at this hour, in this weather, this far into the
## autumn (0..1), this far from the nearest tree (m). Static for the world check.
static func wants(hour: float, weather: int, autumn: float, tree_d: float) -> Dictionary:
	var out := {"dawn": 0.0, "birds": 0.0, "hoppers": 0.0}
	# 3 light rain, 4 rain, 5 storm: nothing sings.
	if weather >= 3:
		return out
	var by_trees := clampf(1.0 - (tree_d - 6.0) / 30.0, 0.15, 1.0)
	var open := clampf((tree_d - 4.0) / 10.0, 0.0, 1.0)
	var fog := 0.5 if weather == 2 else 1.0
	# Up 4:45-5:45, full till 7:15, gone by 8:30.
	var dawn := clampf((hour - 4.75), 0.0, 1.0) * clampf((8.5 - hour) / 1.25, 0.0, 1.0)
	out["dawn"] = dawn * by_trees * fog * lerpf(1.0, 0.55, autumn)
	var day := clampf((hour - 7.5) / 1.0, 0.0, 1.0) * clampf((18.5 - hour) / 1.0, 0.0, 1.0)
	out["birds"] = day * by_trees * fog * 0.8
	var warm := clampf((hour - 10.0) / 1.5, 0.0, 1.0) * clampf((17.5 - hour) / 1.5, 0.0, 1.0)
	out["hoppers"] = warm * open * clampf(1.0 - autumn * 1.5, 0.0, 1.0) * (0.6 if weather == 2 else 1.0)
	return out


func _one_shot(hour: float, weather: int, here: Vector3) -> void:
	if weather >= 3 or hour < 6.0 or hour > 19.0:
		return
	var pick: Array = [["crow.mp3", 1.0]]
	var near_lake := _lake_at != Vector3.INF and Vector2(_lake_at.x - here.x, _lake_at.z - here.z).length() < 60.0
	if near_lake:
		pick.append(["ducks_a.mp3" if _rng.randf() < 0.5 else "ducks_b.mp3", 2.0])
	var total := 0.0
	for e in pick:
		total += float(e[1])
	var r := _rng.randf() * total
	var file := str(pick[0][0])
	for e in pick:
		r -= float(e[1])
		if r <= 0.0:
			file = str(e[0])
			break
	var at := here
	if file.begins_with("ducks"):
		# Out on the water (the jetty's deck runs out over it toward +Z).
		at = _lake_at + Vector3(_rng.randf_range(-20.0, 20.0), 0.2, _rng.randf_range(10.0, 35.0))
	else:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(20.0, 40.0)
		at = here + Vector3(cos(a), 0, sin(a)) * d + Vector3(0, 6.0, 0)
	var s: AudioStreamPlayer3D = _shots[_next_shot]
	_next_shot = (_next_shot + 1) % _shots.size()
	s.stream = _stream(file)
	if s.stream == null:
		return
	s.global_position = at
	var dist := at.distance_to(here)
	s.unit_size = dist / 4.0
	s.volume_db = {"crow.mp3": -11.0, "ducks_a.mp3": -10.0, "ducks_b.mp3": -10.0}.get(file, -9.0) + _rng.randf_range(-2.0, 1.0)
	s.pitch_scale = _rng.randf_range(0.95, 1.05)
	s.play()


func _nearest_tree(here: Vector3) -> float:
	var best := 999.0
	for t in get_tree().get_nodes_in_group("trees"):
		if t is Node3D:
			var p := (t as Node3D).global_position
			best = minf(best, Vector2(p.x - here.x, p.z - here.z).length())
	return best


func _find_lake(main: Node) -> Vector3:
	var jetty := main.find_child("Jetty", true, false) as Node3D
	var deck: Node3D = jetty.get_node_or_null("Deck") as Node3D if jetty != null else null
	return deck.global_position if deck != null else Vector3.INF
