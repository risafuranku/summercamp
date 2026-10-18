extends Node

## Out of the camp and down the road: the barrier you can raise yourself
## (scripts/camp_gate.gd), the road through the forest to the bus stop
## (scripts/town/road_south.gd) with its timetable (timetable_closeup.gd, the times from
## bus_timetable.gd), the line 380 bus (bus_model.gd outside, bus_ride.gd inside) and
## Lesna at the other end (town_lesna.gd, built the first time you go).
##
## The buses run by the clock, whoever watches: at each stop a bus comes in, stands with
## its door open (half an hour at the camp: the end of the line) and goes. Click it while
## it stands to get on. Only the bus going your way takes you: in Lesna the one to the
## camp (the one to Hlubocany is not yours). Miss the last one and you stay in Lesna.
## A bus with you on it waits for you to sit down or get off.
##
## Things out there are clicked like the camp's buildings: they carry a building_type
## ("trip_*", "town_*") and InteriorManager hands them here (interact, hint_for). The
## close-ups and the ride count as rooms (is_open): the HUD and the camp's controls step
## aside. Created and owned by InteriorManager.

const TIMES = preload("res://scripts/town/bus_timetable.gd")
const TIMETABLE_CLOSEUP = preload("res://scripts/town/timetable_closeup.gd")
const BUS_MODEL = preload("res://scripts/town/bus_model.gd")
const BUS_RIDE = preload("res://scripts/town/bus_ride.gd")
const TOWN = preload("res://scripts/town/town_lesna.gd")
const POCKETS = preload("res://scripts/town/pockets.gd")
const SHOP = preload("res://scripts/town/shop_closeup.gd")
const PUB = preload("res://scripts/town/pub_closeup.gd")
## The Jednota and the pub in 3D; their card and machine are close-ups over it.
const TOWN_ROOM = preload("res://scripts/town/town_room.gd")
var _room
const SFX_TOWN := "res://assets/sfx/town/"
## Opening hours (game hours): the Jednota, the pub, the kiosk; rooms at the motel from.
const HOURS := {"jednota": [7.0, 17.0], "pub": [10.0, 23.0], "kiosk": [6.0, 21.0]}
const MOTEL_FROM := 19.0
const DRIVER_LINES := [
	"Machine's inside. I don't do change.",
	"Twenty years on the 380. I never once saw anybody get off at your camp after dark.",
	"Five minutes. Then I go, with you or without you.",
	"The works bus? Not mine. Nobody's, if you ask me.",
]
const MOTEL_PRICE := 15
const MEMORIAL := "1914 - 1918, nine names. 1939 - 1945, four. Under them a newer brass plate, screwed on crooked: CERNE JEZERO 1994. No names. Somebody keeps it polished."
const CHAPEL := "Locked. A card in the window: mass at nine on Sundays, the bell at noon and at six. Under it, in pencil: and at three in the morning, but that is not us."
## How long a bus takes to come in to a stop and to go (game hours).
const IN_HOURS := 0.22
const OUT_HOURS := 0.3
## The Hlubocany bus stops in Lesna this long.
const THROUGH_STAND := 0.08
## How long you are counted as in Lesna once you are this far from the camp (m).
const AWAY_DIST := 1500.0

var _im: Node
var _timetable
var _ride
var _town
var _camp_bus
var _town_bus
## The works bus after midnight (one for the camp's road, one for Lesna's).
var _works_camp
var _works_town
## A bus kept standing past its time (you are on it) or put on just for you (you got off
## it): stop -> {"mode": "hold"|"drop", "t": seconds, "pose", "leave"}.
var _special: Dictionary = {}
var _boarding_stop := ""
var _driver_line := 0
var pockets
var _shop
var _pub
var _ambience: AudioStreamPlayer
var _bell: AudioStreamPlayer3D
var _bell_rung := -1
var _sleep_layer: CanvasLayer
var _sleep_rect: ColorRect
var _sleeping := false
var _sleep_fade := 0.0
var _night := false
var _night_poll := 0.0
## Each stop's runs for the day (paths and poses), made once per road / town.
var _runs: Dictionary = {}


func setup(interior_manager: Node) -> void:
	_im = interior_manager
	if pockets == null:
		pockets = POCKETS.new()
		add_child(pockets)
		pockets.allowed = _pockets_allowed
		pockets.on_smoked = func():
			var p := _player()
			if p != null:
				p.set("stamina", 1.0)
				p.set("_stamina_locked", false)
				_say("That's better.")


## Smoking and drinking: out in the world, playing, nothing open.
func _pockets_allowed() -> bool:
	var main := _main()
	if main == null or get_tree().paused:
		return false
	if not bool(main.get("_gameplay_started")) or bool(main.get("_menu_mode")):
		return false
	if main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open")):
		return false
	return not is_open() and not _sleeping


func _main() -> Node:
	return get_tree().current_scene if get_tree() != null else null


func _player() -> Node3D:
	var main := _main()
	return main.get("_player") as Node3D if main != null else null


func hour() -> float:
	var main := _main()
	if main != null and main.get("_time_of_day_hours") != null:
		return float(main.get("_time_of_day_hours"))
	return 12.0


func _gate() -> Node:
	return get_tree().get_first_node_in_group("camp_gate")


func _road() -> Node:
	return get_tree().get_first_node_in_group("road_south")


func _worldgen() -> Node:
	var main := _main()
	return main.get("world_generator") if main != null else null


## In Lesna (or anywhere far from the camp): the night leaves you alone there.
func away() -> bool:
	var p := _player()
	return p != null and _town != null and p.global_position.distance_to(TOWN.ORIGIN) < AWAY_DIST


# ── clicking things out there ────────────────────────────────────────────────

func handles(building_type: String) -> bool:
	return building_type.begins_with("trip_") or building_type.begins_with("town_")


func hint_for(structure: Node3D) -> String:
	match str(structure.get_meta("building_type", "")):
		"trip_barrier":
			var gate := _gate()
			return "" if gate != null and gate.is_raised() else "Raise the barrier"
		"trip_timetable":
			return "Read the timetable"
		"trip_bus":
			return "Get on the bus"
		"town_npc":
			return "Talk to %s" % (_town.spots["people"].name_of(str(structure.get_meta("who", ""))) if _town != null else "them")
		"town_read":
			return "Read the memorial"
		"town_pump":
			var job = _town.spots["job"] if _town != null else null
			if job != null and job.waiting_at(int(structure.get_meta("pump", 0))):
				return "Fill the car"
			if job != null and not job.on and _open("kiosk"):
				return "Ask Lojza for work"
			return ""
		"town_door":
			match str(structure.get_meta("door", "")):
				"jednota":
					return "Go into the Jednota" if _open("jednota") else "Read the note on the door"
				"pub":
					return "Go into the pub" if _open("pub") else "Knock"
				"motel":
					return "Ask for a room"
				"kiosk":
					return "Knock on the kiosk window"
				"chapel":
					return "Try the chapel door"
	return ""


func _open(place: String) -> bool:
	var h := hour()
	var oh: Array = HOURS.get(place, [0.0, 24.0])
	return h >= float(oh[0]) and h < float(oh[1])


func interact(structure: Node3D) -> void:
	match str(structure.get_meta("building_type", "")):
		"trip_barrier":
			var gate := _gate()
			if gate != null and not gate.is_raised():
				gate.open_for_player()
				Coop.send_sync("gate", [])
		"trip_timetable":
			_open_timetable(str(structure.get_meta("stop", "camp")))
		"trip_bus":
			_board(str(structure.get_meta("stop", "camp")))
		"town_npc":
			var who := str(structure.get_meta("who", ""))
			if who == "driver":
				_quote("Driver", DRIVER_LINES[_driver_line % DRIVER_LINES.size()])
				_driver_line += 1
				return
			if who == "lojza" and _open("kiosk") and not _town.spots["job"].on:
				_start_job()
				return
			var said: Array = _town.spots["people"].talk(who, hour())
			_quote(str(said[0]), str(said[1]))
		"town_read":
			_say(MEMORIAL)
		"town_pump":
			var job = _town.spots["job"]
			var pump := int(structure.get_meta("pump", 0))
			if not _open("kiosk"):
				_quote("Lojza", "Come back when I have got cars. Mornings are best, the Tatra is gone by then.")
			elif job.waiting_at(pump):
				_set_player_controls(false)
				job.serve(pump)
			elif not job.on:
				_start_job()
			else:
				_quote("Lojza", "Wait for one. They come.")
		"town_door":
			_door(str(structure.get_meta("door", "")))


## Lojza's shift: cars come in off the road until you walk off or he shuts at nine.
func _start_job() -> void:
	var job = _town.spots["job"]
	if not job.paid.is_connected(_on_job_paid):
		job.paid.connect(_on_job_paid)
		job._closeup_closed_hook = _on_closeup_closed
	job.start_shift()
	_quote("Lojza", "Right. Cars come in, you fill them. Green Natural, yellow Special, black diesel. Two dollars a car and whatever they tip. Mix them up and it is ten off you.")


func _on_job_paid(amount: int, _line: String) -> void:
	if amount != 0:
		_say(("+$%d" % amount) if amount > 0 else ("-$%d" % -amount))


func _quote(who: String, text: String) -> void:
	var main := _main()
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("show_quote"):
		hud.show_quote(who, text, 70.0)


func _door(which: String) -> void:
	match which:
		"jednota":
			if not _open("jednota"):
				_say("A card on the glass: JEDNOTA LESNA 42. Mon - Fri 7 - 17, Sat 7 - 11. Batteries sold out.")
				return
			_open_room("jednota")
		"pub":
			if not _open("pub"):
				_quote("Mr Kubat", "Shut. I do not open after eleven, whoever knocks.")
				return
			_open_room("pub")
		"motel":
			_open_room("motel")
		"kiosk":
			if not _open("kiosk"):
				_say("The kiosk window is dark. Oil cans, maps, a calendar with a car on it.")
				return
			_open_room("kiosk")
		"chapel":
			# Open by day; locked, with its card, in the evening and the night.
			if hour() >= 8.0 and hour() < 18.0:
				_open_room("chapel")
			else:
				_say(CHAPEL)


## In through the door: the room in 3D (scripts/town/town_room.gd), the frame of the
## village breaking up into it.
func _open_room(which: String) -> void:
	if _room == null:
		_room = TOWN_ROOM.new()
		add_child(_room)
		_room.set_modal_check(func(): return (_shop != null and _shop.visible) or (_pub != null and _pub.visible))
		_room.bought.connect(func(item: String):
			if item == "cigs":
				pockets.cigarettes += 20
			elif item == "beer":
				pockets.beers += 1
		)
		_room.drank.connect(func(): pockets.drunk += 1.0)
		_room.wants_closeup.connect(_room_closeup)
		_room.closed.connect(func():
			_door_fx(false)
			_on_closeup_closed())
	_door_fx(true)
	_set_player_controls(false)
	_room.open(which, hour())


func _room_closeup(kind: String) -> void:
	if kind == "motel_room":
		# Mr Simek's rooms: the lobby gives way to the night (the motel's own rules).
		var h := hour()
		if h >= 6.0 and h < MOTEL_FROM:
			_room.say("Mr Simek", "Rooms from seven in the evening. Sit on the bench if you are tired.")
			return
		if CoreRoot.get_money() < MOTEL_PRICE:
			_room.say("Mr Simek", "Fifteen dollars. The bench by the pond is free.")
			return
		_room.close()
		_motel()
		return
	if kind == "card":
		if _shop == null:
			_shop = SHOP.new()
			add_child(_shop)
			_shop.closed.connect(_back_to_room)
		_shop.open_card()
	elif kind == "slot":
		if _pub == null:
			_pub = PUB.new()
			add_child(_pub)
			_pub.closed.connect(_back_to_room)
		_pub.open_slot()


func _back_to_room() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if (_room != null and _room.is_open()) else Input.MOUSE_MODE_CAPTURED)


func _door_fx(going_in: bool) -> void:
	var im := get_parent()
	if im != null and im.has_method("_door_transition"):
		im._door_transition(going_in)


## A room for the night at the motel: from seven in the evening, fifteen dollars; you sleep
## through to the morning (the camp's night goes on without you) and wake by the motel.
func _motel() -> void:
	var h := hour()
	if h >= 6.0 and h < MOTEL_FROM:
		_quote("Mr Simek", "Rooms from seven in the evening. Sit on the bench if you are tired.")
		return
	if CoreRoot.get_money() < MOTEL_PRICE or not CoreRoot.actions.spend_money(MOTEL_PRICE):
		_quote("Mr Simek", "Fifteen dollars. The bench by the pond is free.")
		return
	var office = _main().get("camp_office") if _main() != null else null
	if office == null or not office.has_method("start_sleep"):
		return
	_quote("Mr Simek", "Number four. Lock it twice.")
	var a := AudioStreamPlayer.new()
	add_child(a)
	a.stream = load(SFX_TOWN + "motel_key.mp3")
	a.play()
	a.finished.connect(a.queue_free)
	_ensure_sleep_layer()
	_sleeping = true
	_sleep_fade = 0.0
	_set_player_controls(false)
	office.start_sleep()


func _open_timetable(stop: String) -> void:
	if _timetable == null:
		_timetable = TIMETABLE_CLOSEUP.new()
		_timetable.hour_provider = hour
		add_child(_timetable)
		_timetable.closed.connect(_on_closeup_closed)
	_timetable.stop = stop
	_set_player_controls(false)
	_timetable.open_view()


func _on_closeup_closed() -> void:
	_set_player_controls(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _set_player_controls(on: bool) -> void:
	var player = _player()
	if player != null and player.has_method("set_controls_enabled"):
		player.set_controls_enabled(on)


func _say(text: String) -> void:
	var main := _main()
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("push_status"):
		hud.push_status(text, 0)


## A close-up or the bus of ours is open (InteriorManager counts it as a room).
func is_open() -> bool:
	return (_timetable != null and _timetable.visible) or (_ride != null and _ride.is_open()) \
		or (_shop != null and _shop.visible) or (_pub != null and _pub.visible) \
		or (_room != null and _room.is_open()) \
		or (_town != null and _town.spots["job"].is_open())


func close_interior() -> void:
	if _timetable != null and _timetable.visible:
		_timetable.close_view()
	if _ride != null and _ride.is_open():
		_ride.close_interior()
	if _shop != null and _shop.visible:
		_shop.close_view()
	if _pub != null and _pub.visible:
		_pub.close_view()
	if _room != null and _room.is_open():
		_room.close()
	if _town != null and _town.spots["job"].is_open():
		_town.spots["job"].close()


func set_time_state(_state: int) -> void:
	pass


# ── the buses ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Co-op: the other warden in the same place in Lesna stands there with you.
	if _room != null and _room.is_open():
		_room.coop_mate(Coop.has_partner() and str(Coop.partner_state.get("tr", "")) == str(_room.place))
	var road := _road()
	if road == null:
		return
	if _camp_bus == null or not is_instance_valid(_camp_bus):
		# A new game builds a new road (and the old bus went with the old one).
		_runs.erase("camp")
		_special.erase("camp")
		_camp_bus = BUS_MODEL.new()
		_camp_bus.name = "Bus380Camp"
		road.add_child(_camp_bus)
		_camp_bus.set_stop("camp")
		_camp_bus.set_running(false)
	var h := hour()
	_night_poll -= delta
	if _night_poll <= 0.0:
		_night_poll = 1.0
		_night = h >= 19.0 or h < 6.0
		_camp_bus.set_night(_night)
		if _town != null:
			_town.set_night(_night)
			_town.set_hour(h)
			if _town_bus != null:
				_town_bus.set_night(_night)
	_coop_hold("camp", _camp_bus)
	_run_stop("camp", _camp_bus, delta, h)
	_run_works(h, delta)
	if _town != null:
		_coop_hold("town", _town_bus)
		_run_stop("town", _town_bus, delta, h)
		_town.spots["people"].update(h, delta)
		_watch_job(h)
	_update_village_sound(h)
	_update_sleep(delta)


## The shift ends when you walk off from the station or at nine.
func _watch_job(h: float) -> void:
	var job = _town.spots["job"]
	if not job.on:
		return
	var p := _player()
	var far: bool = p == null or p.global_position.distance_to(_town.w(Vector3(48.0, 0, 13.0))) > 32.0
	if far or not _open("kiosk"):
		_quote("Lojza", job.end_shift())


## In Lesna: the village around you (birds and a far dog by day, a lamp's hum and the
## dogs by night) and the chapel bell at noon and six.
func _update_village_sound(h: float) -> void:
	var here := away()
	if _ambience == null:
		_ambience = AudioStreamPlayer.new()
		_ambience.volume_db = -16.0
		add_child(_ambience)
	var want := ""
	if here:
		want = "village_night.mp3" if (h >= 20.0 or h < 5.5) else "village_day.mp3"
	if want == "":
		if _ambience.playing:
			_ambience.stop()
	elif _ambience.stream == null or _ambience.stream.resource_path != SFX_TOWN + want or not _ambience.playing:
		var st = load(SFX_TOWN + want)
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_ambience.stream = st
		_ambience.play()
	if not here or _town == null:
		return
	var hh := int(floorf(h))
	if (hh == 12 or hh == 18) and h - float(hh) < 0.1 and _bell_rung != hh:
		_bell_rung = hh
		if _bell == null:
			_bell = AudioStreamPlayer3D.new()
			_bell.stream = load(SFX_TOWN + "chapel_bell.mp3")
			_bell.unit_size = 30.0
			_bell.max_distance = 300.0
			_town.add_child(_bell)
			_bell.position = Vector3(-28.0, 9.0, -24.5)
		_bell.play()


func _ensure_sleep_layer() -> void:
	if _sleep_layer != null:
		return
	_sleep_layer = CanvasLayer.new()
	_sleep_layer.layer = 118
	add_child(_sleep_layer)
	_sleep_rect = ColorRect.new()
	_sleep_rect.color = Color(0, 0, 0, 0)
	_sleep_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sleep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleep_layer.add_child(_sleep_rect)


## The night in number four: black (in steps) while the clock runs on, then the morning.
func _update_sleep(delta: float) -> void:
	if _sleep_rect == null:
		return
	var office = _main().get("camp_office") if _main() != null else null
	if _sleeping:
		_sleep_fade = minf(1.0, _sleep_fade + delta * 1.5)
		if office != null and not office.is_sleeping_through() and _sleep_fade >= 1.0:
			_sleeping = false
			if _town != null:
				_put_player(Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), _town.w(Vector3(-27.0, 0.15, 8.0))))
			_set_player_controls(true)
			_say("Morning. The radiator knocked all night. Twice it knocked back.")
	else:
		_sleep_fade = maxf(0.0, _sleep_fade - delta * 0.8)
	_sleep_rect.color.a = floorf(_sleep_fade * 6.0) / 6.0


## What the bus at `stop` does at hour `h`: where it is, its door, its speed.
func _run_stop(stop: String, bus: Node3D, delta: float, h: float) -> void:
	var sp: Dictionary = _special.get(stop, {})
	if not sp.is_empty():
		_run_special(stop, bus, sp, delta)
		return
	if _coop_gone.has(stop):
		if h < float(_coop_gone[stop]) and h > float(_coop_gone[stop]) - 3.0:
			bus.set_running(false)
			return
		_coop_gone.erase(stop)
	var plan := _plan(stop, h)
	if plan.is_empty():
		if bus.visible:
			bus.set_running(false)
			bus.open_door(false)
		return
	var path: PackedVector3Array = plan["path"]
	var k: float = plan["k"]
	var arriving: bool = plan["mode"] == "in"
	var standing: bool = plan["mode"] == "stand"
	if not bus.visible:
		bus.set_running(true)
		bus.destination = plan["dest"]
		bus.set_stop(plan["stop_id"])
		if arriving:
			bus.play("res://assets/sfx/bus/arrive.mp3", -10.0)
	# The driver smokes outside while it stands at the end of the line (the camp) or in
	# Lesna before going up to the camp.
	bus.set_driver_out(standing and plan["stop_id"] != "town_through")
	if standing:
		bus.global_transform = plan["pose"]
		bus.set_speed(0.0)
		bus.open_door(true)
		return
	# In: slowing to the stop; out: picking up speed.
	var e := 1.0 - (1.0 - k) * (1.0 - k) if arriving else k * k
	var was: Vector3 = bus.global_position
	_place_on(bus, path, e)
	bus.set_speed(was.distance_to(bus.global_position) / maxf(delta, 0.001))
	if not arriving:
		if bus.is_door_open():
			bus.open_door(false)
			bus.play("res://assets/sfx/bus/depart.mp3", -5.0)


## The works bus (the timetable's "+"): lit inside, SLUZEBNI on its board, past the camp
## stop a little after midnight without slowing, on up the road towards the camp and
## round the bend, and through Lesna at 23:46 towards the dam. It stops for nobody.
const WORKS_HOURS := 0.24


func _run_works(h: float, delta: float) -> void:
	var road := _road()
	if _works_camp == null or not is_instance_valid(_works_camp):
		_works_camp = BUS_MODEL.new()
		_works_camp.name = "Bus380Works"
		road.add_child(_works_camp)
		_works_camp.destination = "SLUZEBNI"
		_works_camp.set_running(false)
	_pass(_works_camp, road.works_bus_path(), fposmod(h - (TIMES.WORKS_CAMP - WORKS_HOURS * 0.5), 24.0) / WORKS_HOURS, delta)
	if _town != null:
		if _works_town == null or not is_instance_valid(_works_town):
			_works_town = BUS_MODEL.new()
			_works_town.name = "Bus380WorksLesna"
			_town.add_child(_works_town)
			_works_town.destination = "SLUZEBNI"
			_works_town.set_running(false)
		var path := PackedVector3Array([_town.w(Vector3(-150.0, 0, 1.6)), _town.w(Vector3(160.0, 0, 1.6))])
		_pass(_works_town, path, fposmod(h - (TIMES.WORKS_TOWN - WORKS_HOURS * 0.5), 24.0) / WORKS_HOURS, delta)


func _pass(bus: Node3D, path: PackedVector3Array, k: float, delta: float) -> void:
	if k < 0.0 or k > 1.0:
		if bus.visible:
			bus.set_running(false)
		return
	if not bus.visible:
		bus.set_running(true)
		bus.set_night(true)
		bus.open_door(false)
	var was: Vector3 = bus.global_position
	_place_on(bus, path, k)
	bus.set_speed(was.distance_to(bus.global_position) / maxf(delta, 0.001))


## {} or {mode: "in"|"stand"|"out", k (0..1 along the path), path, pose, dest, stop_id}.
func _plan(stop: String, h: float) -> Dictionary:
	if not _runs.has(stop):
		_runs[stop] = _make_runs(stop)
	for r in _runs[stop]:
		var a: float = r["arrive"]
		var l: float = r["leave"]
		if h >= a - IN_HOURS and h < a:
			var o: Dictionary = r.duplicate()
			o["mode"] = "in"
			o["k"] = (h - (a - IN_HOURS)) / IN_HOURS
			o["path"] = r["in"]
			return o
		if h >= a and h < l:
			var o2: Dictionary = r.duplicate()
			o2["mode"] = "stand"
			o2["k"] = 0.0
			o2["path"] = r["in"]
			return o2
		if h >= l and h < l + OUT_HOURS:
			var o3: Dictionary = r.duplicate()
			o3["mode"] = "out"
			o3["k"] = (h - l) / OUT_HOURS
			o3["path"] = r["out"]
			return o3
	return {}


func _make_runs(stop: String) -> Array:
	var runs: Array = []
	if stop == "camp":
		var road := _road()
		for i in TIMES.CAMP_ARRIVE.size():
			runs.append({"arrive": TIMES.CAMP_ARRIVE[i], "leave": TIMES.CAMP_LEAVE[i], "in": road.bus_arrive_path(), "out": road.bus_leave_path(), "pose": road.bus_stop_pose(), "dest": "LESNA", "stop_id": "camp"})
	else:
		for i in TIMES.TOWN_ARRIVE.size():
			runs.append({"arrive": TIMES.TOWN_ARRIVE[i], "leave": TIMES.TOWN_LEAVE[i], "in": _town.bus_arrive_path("to_camp"), "out": _town.bus_leave_path("to_camp"), "pose": _town.bus_pose("to_camp"), "dest": "KEMP", "stop_id": "town"})
		for t in TIMES.TOWN_THROUGH:
			runs.append({"arrive": t, "leave": float(t) + THROUGH_STAND, "in": _town.bus_arrive_path("to_hlub"), "out": _town.bus_leave_path("to_hlub"), "pose": _town.bus_pose("to_hlub"), "dest": "HLUBOCANY", "stop_id": "town_through"})
	return runs


## A bus held at the stop for you, or let off for you: by real seconds, not the clock.
func _run_special(stop: String, bus: Node3D, sp: Dictionary, delta: float) -> void:
	sp["t"] = float(sp.get("t", 0.0)) + delta
	bus.set_driver_out(false)
	if not bus.visible:
		bus.set_running(true)
		bus.destination = str(sp.get("dest", "LESNA"))
		bus.set_stop(str(sp.get("stop_id", stop)))
	match str(sp["mode"]):
		"hold":
			bus.global_transform = sp["pose"]
			bus.set_speed(0.0)
			bus.open_door(true)
		"drop":
			# You have just got off: it stands a moment, then goes.
			var t := float(sp["t"])
			if t < 2.6:
				bus.global_transform = sp["pose"]
				bus.set_speed(0.0)
				bus.open_door(true)
			else:
				var k := clampf((t - 2.6) / 9.0, 0.0, 1.0)
				if bus.is_door_open():
					bus.open_door(false)
					bus.play("res://assets/sfx/bus/depart.mp3", -5.0)
				var was: Vector3 = bus.global_position
				_place_on(bus, sp["leave"], k * k)
				bus.set_speed(was.distance_to(bus.global_position) / maxf(delta, 0.001))
				if k >= 1.0:
					_special.erase(stop)
					bus.set_running(false)


## Puts the bus at fraction `e` of the way along `path`, facing along it.
func _place_on(bus: Node3D, path: PackedVector3Array, e: float) -> void:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var want := clampf(e, 0.0, 1.0) * total
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if want <= seg or i == path.size() - 2:
			var f := clampf(want / maxf(seg, 0.001), 0.0, 1.0)
			var pos := path[i].lerp(path[i + 1], f)
			var dir := (path[i + 1] - path[i]).normalized()
			if dir.length() > 0.01:
				bus.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), pos)
			return
		want -= seg


# ── co-op: one bus for two wardens ───────────────────────────────────────────

## The other warden on the bus at `stop_id` (not yet gone): it stands for them here too.
## When it goes with them and not you, it goes from here as well.
func _coop_hold(stop_id: String, bus: Node3D) -> void:
	if bus == null or not Coop.has_partner():
		return
	var mate = Coop.partner_state.get("bus", {})
	var m: Dictionary = mate if mate is Dictionary else {}
	var theirs := not m.is_empty() and str(m.get("st", "")) == stop_id
	var aboard := theirs and not bool(m.get("go", false))
	var mine: bool = _ride != null and _ride.is_open() and _boarding_stop == stop_id
	var sp: Dictionary = _special.get(stop_id, {})
	if aboard and sp.is_empty() and bus.visible and bus.is_door_open():
		_special[stop_id] = {"mode": "hold", "t": 0.0, "pose": bus.global_transform, "dest": bus.destination, "stop_id": stop_id, "coop": true}
	elif not aboard and bool(sp.get("coop", false)) and not mine:
		if theirs:
			# Gone with them: it pulls away from the stop, and that run is over here too.
			var out: PackedVector3Array = _road().bus_leave_path() if stop_id == "camp" else _town.bus_leave_path("to_camp")
			var run := _plan(stop_id, hour())
			_coop_gone[stop_id] = float(run.get("leave", hour())) + OUT_HOURS
			_special[stop_id] = {"mode": "drop", "t": 2.6, "pose": sp["pose"], "leave": out, "dest": sp["dest"], "stop_id": stop_id}
		else:
			_special.erase(stop_id)


## Runs that went early with the other warden: no bus at that stop till their time is up.
var _coop_gone: Dictionary = {}


## Co-op: where you are on a bus, for the other machine.
func coop_state() -> Dictionary:
	return _ride.coop_state() if _ride != null else {}


## Co-op: the place in Lesna you are in ("pub", "jednota"...), "" outside them.
func coop_place() -> String:
	return str(_room.place) if _room != null and _room.is_open() else ""


# ── getting on, the ride, getting off ────────────────────────────────────────

func _board(stop_id: String) -> void:
	if stop_id == "town_through":
		_say("Driver: \"Hlubocany. Yours is the other side, to the camp.\"")
		return
	var bus = _camp_bus if stop_id == "camp" else _town_bus
	if bus == null or not bus.is_door_open():
		return
	_boarding_stop = stop_id
	# The bus waits while you are on it.
	_special[stop_id] = {"mode": "hold", "t": 0.0, "pose": bus.global_transform, "dest": bus.destination, "stop_id": stop_id}
	if _ride == null:
		_ride = BUS_RIDE.new()
		add_child(_ride)
		_ride.arrived.connect(_on_ride_arrived)
		_ride.left_bus.connect(_on_left_bus)
	_ride.worldgen = _worldgen()
	_ride.stop_pos = bus.global_position
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(true)
	_set_player_controls(false)
	var ws = _main().get("weather_system") if _main() != null else null
	var fog := 1.0 if ws != null and int(ws.get("current_weather")) == 2 else 0.0
	var rain: bool = ws != null and ws.has_method("is_raining") and ws.is_raining()
	_ride.open_ride(stop_id, hour(), fog, rain)


func _on_left_bus() -> void:
	# Back out at the door: the bus goes on with its own time.
	_special.erase(_boarding_stop)
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(false)
	_set_player_controls(true)


func _on_ride_arrived() -> void:
	var from := _boarding_stop
	_special.erase(from)
	var bus = _camp_bus if from == "camp" else _town_bus
	if bus != null:
		bus.set_running(false)
		bus.set_driver_out(false)
	# Co-op: off the same bus, the other warden steps down beside the first.
	var beside := Vector3(1.1, 0.0, 0.0) if Coop.is_client() else Vector3.ZERO
	if from == "camp":
		_ensure_town()
		_put_player(_town.arrive_spot().translated(beside))
		# The bus you came on stands a moment by the square and goes on to Hlubocany.
		_special["town"] = {"mode": "drop", "t": 0.0, "pose": _town.bus_pose("to_hlub"), "leave": _town.bus_leave_path("to_hlub"), "dest": "HLUBOCANY", "stop_id": "town_through"}
	else:
		var road := _road()
		_put_player(road.wait_spot().translated(beside))
		# The end of the line: it stands, then turns in the loop and goes back.
		_special["camp"] = {"mode": "drop", "t": -14.0, "pose": road.bus_stop_pose(), "leave": road.bus_leave_path(), "dest": "LESNA", "stop_id": "camp"}
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(false)
	_set_player_controls(true)


func _put_player(xf: Transform3D) -> void:
	var p := _player()
	if p == null:
		return
	p.global_position = xf.origin
	var fwd := -xf.basis.z
	p.rotation = Vector3(0, atan2(-fwd.x, -fwd.z), 0)
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO


func _ensure_town() -> void:
	if _town != null:
		return
	_town = TOWN.new()
	var main := _main()
	var world: Node = main.get("_world_3d") if main != null and main.get("_world_3d") != null else main
	world.add_child(_town)
	_town.build(_worldgen())
	_town.set_night(_night)
	_town_bus = BUS_MODEL.new()
	_town_bus.name = "Bus380Lesna"
	_town.add_child(_town_bus)
	_town_bus.set_running(false)
	_town_bus.set_night(_night)


# ── saved with the game ──────────────────────────────────────────────────────

func export_state() -> Dictionary:
	return {"in_town": away(), "cigarettes": pockets.cigarettes if pockets != null else 0, "beers": pockets.beers if pockets != null else 0}


func import_state(d: Dictionary) -> void:
	# Saved in Lesna: Lesna is there again (the player's position is the game's).
	if bool(d.get("in_town", false)):
		_ensure_town()
	if pockets != null:
		pockets.cigarettes = int(d.get("cigarettes", 0))
		pockets.beers = int(d.get("beers", 0))
