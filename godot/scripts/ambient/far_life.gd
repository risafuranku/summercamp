extends Node3D

## Life far off, by the hour (made by weather_visuals.gd in the camp's world, like the world
## sounds): what the camp hears of its guests and of the country round it, never close
## (ElevenLabs, assets/sfx/far/):
##   - the evening (18:00-23:30): voices and laughter from the fire, or from the lodgings,
##     while there are guests about;
##   - the day (9:00-18:00): children at play somewhere across the meadow while a family
##     is staying;
##   - the night: a farm dog barking beyond the fields, now and then a car on a road, a
##     train's horn far off; by day a car now and then;
##   - the village's bell at noon and at six, far off to the north-west.
## Each is placed well away from you in its own direction (the camp's own 22 m on, the
## country's 45-120 m) on the night insects' bus, so a presence at night silences it with
## the crickets (audio_manager.set_insect_hush), and a room muffles it like the rest of
## the outside. Each machine hears its own (none of it is the camp's state).

const SFX := "res://assets/sfx/far/"
const BUS := "NightInsects"
const BUS_FALLBACK := "OutdoorAmbience"
## Where the village lies from the camp (the bell).
const VILLAGE_DIR := Vector3(-0.7, 0.0, -0.7)

var player_getter: Callable

var _players: Array = []
var _next_player := 0
var _t := 12.0
var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}
var _rung := {}                   # "day:hour" -> true: the bell rung for it


func _ready() -> void:
	name = "FarLife"
	_rng.randomize()
	var bus := BUS if AudioServer.get_bus_index(BUS) >= 0 else BUS_FALLBACK
	for i in 3:
		var p := AudioStreamPlayer3D.new()
		p.bus = bus
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.max_distance = 400.0
		add_child(p)
		_players.append(p)


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
	var here := player.global_position
	_bell(day, hour, here)
	_t -= delta
	if _t > 0.0:
		return
	_t = _rng.randf_range(25.0, 70.0)
	var w := int(main.get("_weather_state")) if main.get("_weather_state") != null else 0
	# Heavy rain and the storm drown it (and keep people in).
	if w >= 4:
		return
	var night := hour >= 21.0 or hour < 5.0
	var pick: Array = []          # [file, weight]
	var guests := _guests()
	if hour >= 18.0 and hour < 23.5 and int(guests["about"]) > 0:
		pick.append(["chatter.mp3", 3.0])
	if hour >= 9.0 and hour < 18.0 and bool(guests["family"]):
		pick.append(["kids.mp3", 2.0])
	if night:
		pick.append(["dog.mp3", 2.0])
		pick.append(["car.mp3", 1.0])
		pick.append(["train.mp3", 0.6])
	elif hour >= 6.0:
		pick.append(["car.mp3", 0.6])
	if pick.is_empty():
		return
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
	var at := _where(file, here, main)
	if at == Vector3.INF:
		return
	_play(file, at, here)


## Where it comes from: the camp's own sounds from the fire or a lodging well away from
## you, the country's from beyond the fields.
func _where(file: String, here: Vector3, main: Node) -> Vector3:
	if file == "chatter.mp3":
		var spots: Array = []
		var bm = main.get("building_manager")
		var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
		if structures != null:
			for c in structures.get_children():
				var bt := str(c.get_meta("building_type", ""))
				if bt == "bonfire" or bt.begins_with("cabin") or bt.begins_with("caravan") or bt.begins_with("tent") or bt == "pub":
					var p := (c as Node3D).global_position
					if p.distance_to(here) >= 22.0:
						spots.append(p + Vector3(0, 1.2, 0))
		return spots[_rng.randi() % spots.size()] if not spots.is_empty() else Vector3.INF
	var a := _rng.randf() * TAU
	var d := 45.0
	match file:
		"kids.mp3":
			d = _rng.randf_range(30.0, 45.0)
		"dog.mp3":
			d = _rng.randf_range(70.0, 110.0)
		"car.mp3":
			d = _rng.randf_range(60.0, 90.0)
		"train.mp3":
			d = 120.0
	return here + Vector3(cos(a), 0.0, sin(a)) * d + Vector3(0, 2.0, 0)


func _play(file: String, at: Vector3, here: Vector3) -> void:
	var p: AudioStreamPlayer3D = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _stream(file)
	if p.stream == null:
		return
	p.global_position = at
	# Far, but heard: the distance's fall-off a fifth of the way.
	var dist := at.distance_to(here)
	p.unit_size = dist / 5.0
	p.volume_db = {"chatter.mp3": -8.0, "kids.mp3": -9.0, "dog.mp3": -10.0, "car.mp3": -12.0, "train.mp3": -9.0, "bell.mp3": -8.0}.get(file, -10.0) + _rng.randf_range(-2.0, 1.0)
	p.pitch_scale = _rng.randf_range(0.95, 1.04)
	p.play()


## The village's bell: at noon and at six, once each day.
func _bell(day: int, hour: float, here: Vector3) -> void:
	for at_h in [12.0, 18.0]:
		var key := "%d:%d" % [day, int(at_h)]
		if hour >= at_h and hour < at_h + 0.1 and not _rung.has(key):
			_rung[key] = true
			_play("bell.mp3", here + VILLAGE_DIR.normalized() * 140.0 + Vector3(0, 8.0, 0), here)


## How many guests are about (awake, outside their lodging) and whether a family stays.
func _guests() -> Dictionary:
	var about := 0
	var family := false
	if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			if str(g.get("archetype", "")) == "family":
				family = true
			var act: Dictionary = g.get("activity", {}) if g.get("activity", {}) is Dictionary else {}
			if not (str(act.get("kind", "")) in ["sleep", "rest", "leave", "wait_gate"]):
				about += 1
	return {"about": about, "family": family}
