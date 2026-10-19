extends Node

## Podlesi and what happens there (the place itself: hamlet_podlesi.gd). Owned by
## town_trip.gd, which hands it the "ham_*" clicks, its ride's arrivals and the buses'
## clock:
##   - built the first time you get off the 380 at the request stop (STOP in the bus,
##     or a ticket to Podlesi), in the same world far off;
##   - its bus: the 380 passing both ways by the timetable (bus_timetable.hamlet_*),
##     pulling in only for somebody waiting by the pole, else straight through; it
##     stands for you while you are on it; it lets you off and goes on;
##   - old Vondra and his Skoda (car_closeup.gd): the petrol can in the garage, the
##     Babetta's tank by the ruin to siphon, the Trabant's battery, the stockings on the
##     line for a fan belt, the hammer in the chopping block for the starter; get it
##     going and he pays.
## Saved with the game (export_state / import_state). Co-op: not shared yet.

const PLACE = preload("res://scripts/town/hamlet_podlesi.gd")
const BUS_MODEL = preload("res://scripts/town/bus_model.gd")
const TIMES = preload("res://scripts/town/bus_timetable.gd")
const CAR = preload("res://scripts/town/car_closeup.gd")
const SFX := "res://assets/sfx/hamlet/"
## The bus coming in to the pole, standing, going (game hours).
const IN_HOURS := 0.16
const STAND := 0.06
const OUT_HOURS := 0.2
## How near the pole you must stand for the bus to pull in (m).
const WAIT_DIST := 14.0
const PAY := 50
const AWAY_DIST := 1500.0

## town_trip.gd
var trip
var place
var bus
var state := {
	"has": {"battery": false, "stockings": false, "hammer": false, "canister": ""},
	"car": {"battery": false, "red": false, "black": false, "belt": [], "fuel": 0.0, "unstuck": false, "clicks": 0, "running": false},
	"taken": [], "talked": false, "paid": false,
}
var _closeup
var _hold := ""
var _drop: Dictionary = {}
var _decided: Dictionary = {}
var _amb: AudioStreamPlayer
var _idle: AudioStreamPlayer3D
var _night := false


func is_built() -> bool:
	return place != null and is_instance_valid(place)


func ensure() -> void:
	if is_built():
		return
	var main: Node = trip._main()
	var world: Node = main.get("_world_3d") if main != null and main.get("_world_3d") != null else main
	place = PLACE.new()
	world.add_child(place)
	place.build(trip._worldgen())
	place.set_night(_night)
	bus = BUS_MODEL.new()
	bus.name = "Bus380Podlesi"
	place.add_child(bus)
	bus.set_running(false)
	bus.set_night(_night)
	for what in state.get("taken", []):
		place.take(str(what))
	if bool(state["car"].get("running", false)):
		_engine_on()


func near(pos: Vector3) -> bool:
	return is_built() and pos.distance_to(PLACE.HAMLET_ORIGIN) < AWAY_DIST


func arrive_spot(towards_town: bool) -> Transform3D:
	return place.hamlet_arrive_spot(towards_town)


func bus_for(stop_id: String):
	return bus if is_built() and stop_id.begins_with("hamlet") else null


## You are on the bus at the pole: it stands for you.
func hold(stop_id: String) -> void:
	_hold = stop_id


func release() -> void:
	_hold = ""
	if bus != null:
		bus.set_running(false)


## You have just got off here: it stands a moment, then goes on its way.
func drop(towards_town: bool) -> void:
	_drop = {"towards": towards_town, "t": 0.0}


# ── every frame, every second ───────────────────────────────────────────────

func update(h: float, delta: float) -> void:
	if not is_built():
		return
	_update_bus(h, delta)
	_update_sound()


func tick_hour(h: float, night: bool) -> void:
	_night = night
	if not is_built():
		return
	place.set_night(night)
	place.set_hour(h)
	bus.set_night(night)


func _update_bus(h: float, delta: float) -> void:
	if _hold != "":
		var towards := _hold == "hamlet_town"
		_show(towards, _hold)
		bus.global_transform = place.hamlet_bus_pose(towards)
		bus.set_speed(0.0)
		bus.open_door(true)
		return
	if not _drop.is_empty():
		_drop["t"] = float(_drop["t"]) + delta
		var towards2: bool = _drop["towards"]
		_show(towards2, "hamlet_town" if towards2 else "hamlet_camp")
		var t := float(_drop["t"])
		if t < 2.6:
			bus.global_transform = place.hamlet_bus_pose(towards2)
			bus.set_speed(0.0)
			bus.open_door(true)
		else:
			var k := clampf((t - 2.6) / 9.0, 0.0, 1.0)
			if bus.is_door_open():
				bus.open_door(false)
				bus.play("res://assets/sfx/bus/depart.mp3", -5.0)
			var was: Vector3 = bus.global_position
			trip._place_on(bus, place.hamlet_out_path(towards2), k * k)
			bus.set_speed(was.distance_to(bus.global_position) / maxf(delta, 0.001))
			if k >= 1.0:
				_drop = {}
				bus.set_running(false)
		return
	var day := int(CoreRoot.get_day()) if CoreRoot != null else 1
	for stop_id in ["hamlet_town", "hamlet_camp"]:
		var towards3: bool = stop_id == "hamlet_town"
		var times: Array = TIMES.hamlet_to_town() if towards3 else TIMES.hamlet_to_camp()
		for i in times.size():
			var tt: float = times[i]
			if h < tt - IN_HOURS or h > tt + STAND + OUT_HOURS:
				continue
			var key := "%s|%d|%d" % [stop_id, day, i]
			if not _decided.has(key):
				_decided[key] = _waiting(towards3)
			_run(towards3, stop_id, tt, h, bool(_decided[key]), delta)
			return
	if bus.visible:
		bus.set_running(false)
		bus.open_door(false)


func _show(towards: bool, stop_id: String) -> void:
	if not bus.visible:
		bus.set_running(true)
		bus.destination = "LESNA" if towards else "KEMP"
		bus.set_stop(stop_id)
		bus.set_night(_night)


## One run past the turn: in to the pole for somebody waiting, or straight through.
func _run(towards: bool, stop_id: String, t: float, h: float, stops: bool, delta: float) -> void:
	var fresh: bool = not bus.visible
	_show(towards, stop_id)
	var was: Vector3 = bus.global_position
	if stops:
		if h < t:
			if fresh:
				bus.play("res://assets/sfx/bus/arrive.mp3", -10.0)
			var k := (h - (t - IN_HOURS)) / IN_HOURS
			trip._place_on(bus, place.hamlet_in_path(towards), 1.0 - (1.0 - k) * (1.0 - k))
		elif h < t + STAND:
			bus.global_transform = place.hamlet_bus_pose(towards)
			bus.set_speed(0.0)
			bus.open_door(true)
			return
		else:
			var k2 := (h - t - STAND) / OUT_HOURS
			if bus.is_door_open():
				bus.open_door(false)
				bus.play("res://assets/sfx/bus/depart.mp3", -5.0)
			trip._place_on(bus, place.hamlet_out_path(towards), k2 * k2)
	else:
		var path: PackedVector3Array = place.hamlet_in_path(towards)
		path.append_array(place.hamlet_out_path(towards))
		trip._place_on(bus, path, (h - (t - IN_HOURS)) / (IN_HOURS + STAND + OUT_HOURS))
	bus.set_speed(was.distance_to(bus.global_position) / maxf(delta, 0.001))


## Somebody (you) by the pole on that side as the bus comes.
func _waiting(towards: bool) -> bool:
	var p: Node3D = trip._player()
	if p == null:
		return false
	var pole: Vector3 = place.w(PLACE.POLE_TOWN if towards else PLACE.POLE_CAMP)
	return p.global_position.distance_to(pole) < WAIT_DIST


## The hamlet's day or night round you, and the Skoda ticking over once it runs.
func _update_sound() -> void:
	if _amb == null:
		_amb = AudioStreamPlayer.new()
		add_child(_amb)
	var p: Node3D = trip._player()
	var close: bool = p != null and p.global_position.distance_to(place.w(Vector3(0, 0, 70))) < 260.0 and not trip.is_open()
	var want := SFX + ("hamlet_night.mp3" if _night else "hamlet_day.mp3")
	if close and ResourceLoader.exists(want):
		if not _amb.playing or _amb.stream == null or _amb.stream.resource_path != want:
			var st: AudioStream = load(want)
			if st is AudioStreamMP3:
				(st as AudioStreamMP3).loop = true
			_amb.stream = st
			_amb.volume_db = -12.0
			_amb.play()
	elif _amb.playing:
		_amb.stop()


# ── clicking things ─────────────────────────────────────────────────────────

func hint_for(structure: Node3D) -> String:
	var has: Dictionary = state["has"]
	match str(structure.get_meta("building_type", "")):
		"ham_timetable":
			return "Read the timetable"
		"ham_npc":
			return "Talk to Mr Vondra"
		"ham_car":
			return "Look at the Skoda"
		"ham_canister":
			return "Take the petrol can"
		"ham_moped":
			return "Siphon the petrol" if str(has["canister"]) == "empty" else "Look at the Babetta"
		"ham_wreck":
			return "Look at the Trabant" if state["taken"].has("battery") else "Take the battery"
		"ham_stockings":
			return "Take the stockings"
		"ham_hammer":
			return "Take the hammer"
		"ham_ruin":
			return "Look into the ruin"
	return ""


func interact(structure: Node3D) -> void:
	var has: Dictionary = state["has"]
	match str(structure.get_meta("building_type", "")):
		"ham_timetable":
			trip._open_timetable("hamlet")
		"ham_npc":
			_talk()
		"ham_car":
			_open_car()
		"ham_canister":
			has["canister"] = "empty"
			_take("canister", "An empty petrol can. It sloshes with nothing.")
		"ham_moped":
			match str(has["canister"]):
				"empty":
					has["canister"] = "full"
					_sfx("siphon.mp3")
					trip._say("A suck on the hose, a mouthful of Babetta, and the can is full. Mostly.")
				"full":
					trip._say("The can is full already.")
				_:
					trip._say("The Babetta's tank sloshes. Half full, after all these years. You need something to put it in.")
		"ham_wreck":
			if state["taken"].has("battery"):
				trip._say("The Trabant, on its blocks. Mice live in it now.")
			else:
				has["battery"] = true
				state["taken"].append("battery")
				_sfx("pick_up.mp3")
				trip._say("The Trabant's battery, from under a mouse nest. Heavy. Is there anything left in it?")
		"ham_stockings":
			has["stockings"] = true
			_take("stockings", "A pair of stockings off the line. Beige. Nobody is coming for them.")
		"ham_hammer":
			has["hammer"] = true
			_take("hammer", "The hammer from the block. The handle is warm, as if somebody just put it down.")
		"ham_ruin":
			_sfx("ruin_creak.mp3")
			trip._say("The Hronek place. Empty since 1974. The door is gone. The dark inside is not.")


func _take(what: String, line: String) -> void:
	place.take(what)
	if not state["taken"].has(what):
		state["taken"].append(what)
	_sfx("pick_up.mp3")
	trip._say(line)


func _sfx(name: String) -> void:
	if not ResourceLoader.exists(SFX + name):
		return
	var a := AudioStreamPlayer.new()
	a.stream = load(SFX + name)
	a.volume_db = -6.0
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


## Old Vondra: the job, then a hint for what is still missing, then his thanks.
func _talk() -> void:
	var car: Dictionary = state["car"]
	var has: Dictionary = state["has"]
	if bool(car["running"]):
		if not bool(state["paid"]):
			_pay()
		else:
			trip._quote("Vondra", "Like a sewing machine full of nails. And when you go back up to that camp: not the last bus. The one before.")
		return
	if not bool(state["talked"]):
		state["talked"] = true
		trip._quote("Vondra", "You got off here? Nobody gets off here. That is my Skoda in the garage. She has not gone since my boy went to Germany. Get her going and there is fifty in it for you. Parts? Everything here is parts.")
		return
	if not bool(car["battery"]) and not bool(has["battery"]):
		trip._quote("Vondra", "The battery is as dead as Brezhnev. The Trabant behind my house still has one.")
	elif float(car["fuel"]) < 0.5 and str(has["canister"]) != "full":
		trip._quote("Vondra", "Petrol? The Babetta by the Hronek ruin, up at the road. Her tank never emptied. The can is by the wall in the garage.")
	elif (car["belt"] as Array).size() < 4 and not bool(has["stockings"]):
		trip._quote("Vondra", "The fan belt went in ninety-one. Marie, God rest her, always said a stocking will do. There are some on the line.")
	elif not bool(car["unstuck"]) and not bool(has["hammer"]):
		trip._quote("Vondra", "If she only clicks, you hit the starter. The hammer is in the block by the woodpile.")
	else:
		trip._quote("Vondra", "Well? Go on. The key is in her.")


func _pay() -> void:
	state["paid"] = true
	CoreRoot.actions.add_money(PAY)
	trip._quote("Vondra", "Listen to her! Here, fifty, as I said. And when you go back up to that camp: not the last bus. The one before.")
	trip._say("+$%d" % PAY)


func _open_car() -> void:
	if _closeup == null:
		_closeup = CAR.new()
		add_child(_closeup)
		_closeup.closed.connect(trip._on_closeup_closed)
		_closeup.started.connect(func():
			_engine_on()
			if not bool(state["paid"]):
				get_tree().create_timer(2.5).timeout.connect(_pay)
		)
	_closeup.state = state
	trip._set_player_controls(false)
	_closeup.open_view()


## The Skoda ticking over in the garage: its idle and its black smoke.
func _engine_on() -> void:
	if not is_built():
		return
	place.car_running(true)
	if _idle == null and ResourceLoader.exists(SFX + "car_idle.mp3"):
		_idle = AudioStreamPlayer3D.new()
		var st: AudioStream = load(SFX + "car_idle.mp3")
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_idle.stream = st
		_idle.unit_size = 4.0
		_idle.max_distance = 40.0
		place.add_child(_idle)
		_idle.position = place.spots["garage"].position
		_idle.play()


func is_open() -> bool:
	return _closeup != null and _closeup.visible


func close() -> void:
	if _closeup != null and _closeup.visible:
		_closeup.close_view()


# ── saved with the game ──────────────────────────────────────────────────────

func export_state() -> Dictionary:
	var d := state.duplicate(true)
	d["built"] = is_built()
	return d


func import_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	for k in ["has", "car"]:
		if d.get(k) is Dictionary:
			(state[k] as Dictionary).merge(d[k], true)
	state["taken"] = (d.get("taken", []) as Array).duplicate()
	state["talked"] = bool(d.get("talked", false))
	state["paid"] = bool(d.get("paid", false))
	if bool(d.get("built", false)):
		ensure()
