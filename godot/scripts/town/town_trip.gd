extends Node

## Out of the camp and down the road: the barrier you can raise yourself
## (scripts/camp_gate.gd), the road through the forest to the bus stop
## (scripts/town/road_south.gd) with its timetable (timetable_closeup.gd, the times from
## bus_timetable.gd), the line 380 bus (bus_model.gd outside, bus_ride.gd inside) and
## Lesna at the other end (town_lesna.gd, built the first time you go); on the way the
## request stop for Podlesi and its hamlet (hamlet_trip.gd: "ham_*" things, its bus).
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
const MASTS = preload("res://scripts/town/liblice_masts.gd")
const HAMLET = preload("res://scripts/town/hamlet_trip.gd")
const TICKET_MACHINE = preload("res://scripts/town/ticket_machine.gd")
const MACHINE_CLOSEUP = preload("res://scripts/town/ticket_machine_closeup.gd")
const GEO = preload("res://scripts/geo/geo_data.gd")
const BALANCE = preload("res://core/balance/balance_config.gd")
const GEO_WORLD = preload("res://scripts/geo/geo_world.gd")
## The game's Liblice (town_lesna.gd: the Jednota, the pub, the green, the motel, the
## station) stands with its centre this far up Bylanska past the stop, its street along
## the real one.
const LIBLICE_PAST_STOP := 213.0
## The real land is built round you (geo_world.gd); the village and the farm when you
## come this near them.
const TOWN_NEAR := 1200.0
const HAMLET_NEAR := 900.0
const HAMLET_PLACE = preload("res://scripts/town/hamlet_podlesi.gd")
const POCKETS = preload("res://scripts/town/pockets.gd")
const INVENTORY = preload("res://scripts/ui/inventory.gd")
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
## His voice for each (tools/audiogen/bus_talk.tsv d_out*), from the bus's door.
const DRIVER_VOICE := ["d_out1", "d_out2", "d_out3", "d_out4"]
const MOTEL_PRICE := 15
## Ten litres for Vondra's can at Liblice's pumps.
const CAN_PRICE := 4
const LOJZA_LINES := [
	"Work? Grab a nozzle. Green's Natural, yellow's Special, black's diesel. Mix them up and I mix you up.",
	"Paid by the car, and they tip if you stop it right on the money.",
	"That Tatra comes through at night sometimes, no plates, never pays. I just fill it. You would too.",
	"Everything off the twelve stops here. The ones going up to your camp fill up like they are not coming back.",
]
const LOJZA_NIGHT := "Closed. Go to bed."
const MEMORIAL := "1914 - 1918, nine names. 1939 - 1945, four. Under them a newer brass plate, screwed on crooked: CERNE JEZERO 1994. No names. Somebody keeps it polished."
const CHAPEL := "Locked. A card in the window: mass at nine on Sundays, the bell at noon and at six. Under it, in pencil: and at three in the morning, but that is not us."
## How long a bus takes to come in to a stop and to go (game hours).
const IN_HOURS := 0.22
const OUT_HOURS := 0.3
## The Lstibor bus stops in Liblice this long.
const THROUGH_STAND := 0.08
## Out of the camp: this far from its middle (m) the night leaves you alone (the stop is
## ~200 m off, Pristoupim 2 km, Liblice 2.9 km: scripts/geo/).
const AWAY_DIST := 420.0

var _im: Node
var _timetable
## The stop's ticket machine close up, and where the last ticket from it is for (the
## ride stops at Podlesi by itself for one to PODLESI).
var _machine
var _bought_to := ""
var _ride
var _town
var _masts
## Podlesi (hamlet_trip.gd): its place, bus and the Skoda.
var _hamlet
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
var _lojza_line := 0
var pockets
## The warden's bag (scripts/ui/inventory.gd): what is bought here goes into it.
var inventory
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
	if _hamlet == null:
		_hamlet = HAMLET.new()
		_hamlet.trip = self
		add_child(_hamlet)
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
	if inventory == null:
		inventory = INVENTORY.new()
		add_child(inventory)
		inventory.pockets = pockets
		inventory.trip = self
		pockets.bag = inventory


## Smoking and drinking: playing, on your feet (outdoors, in a room, in Lesna's places);
## pockets.gd itself keeps the hands down at the PC, in close-ups, the boat and such.
## Not on the bus (the driver will not have it) nor at the pump.
func _pockets_allowed() -> bool:
	var main := _main()
	if main == null or get_tree().paused:
		return false
	if not bool(main.get("_gameplay_started")) or bool(main.get("_menu_mode")):
		return false
	if (_ride != null and _ride.is_open()) or (_job() != null and _job().is_open()):
		return false
	if (_timetable != null and _timetable.visible) or (_machine != null and _machine.visible):
		return false
	return not _sleeping


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
	if p == null:
		return false
	return Vector2(p.global_position.x, p.global_position.z).length() > AWAY_DIST


# ── clicking things out there ────────────────────────────────────────────────

func handles(building_type: String) -> bool:
	return building_type.begins_with("trip_") or building_type.begins_with("town_") or building_type.begins_with("ham_")


func hint_for(structure: Node3D) -> String:
	if str(structure.get_meta("building_type", "")).begins_with("ham_"):
		return _hamlet.hint_for(structure)
	match str(structure.get_meta("building_type", "")):
		"trip_barrier":
			var gate := _gate()
			return "Lower the barrier" if gate != null and gate.is_raised() else "Raise the barrier"
		"trip_timetable":
			return "Read the timetable"
		"trip_ticket_machine":
			return "Buy a ticket"
		"trip_bus":
			return "Get on the bus"
		"town_npc":
			return "Talk to %s" % (_town.spots["people"].name_of(str(structure.get_meta("who", ""))) if _town != null else "them")
		"town_read":
			return "Read the memorial"
		"town_bench":
			return "" if _seated_on != null else "Sit down"
		"town_pump":
			return "Fill the petrol can" if _hamlet != null and str(_hamlet.state["has"]["canister"]) == "empty" else "Look at the pump"
		"trip_pump":
			var job = _job()
			if job != null and job.waiting_at(int(structure.get_meta("pump", 0))):
				return "Fill the car"
			if job != null and not job.on and _open("kiosk"):
				return "Ask Lojza for work"
			return ""
		"trip_lojza":
			return "Talk to Lojza"
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
	if str(structure.get_meta("building_type", "")).begins_with("ham_"):
		_hamlet.interact(structure)
		return
	match str(structure.get_meta("building_type", "")):
		"trip_barrier":
			var gate := _gate()
			if gate == null:
				return
			if not gate.is_raised():
				gate.open_for_player()
				Coop.send_sync("gate", ["up"])
				return
			var why: String = gate.close_for_player()
			if why.is_empty():
				Coop.send_sync("gate", ["down"])
			else:
				_say(why)
		"trip_timetable":
			_open_timetable(str(structure.get_meta("stop", "camp")))
		"trip_ticket_machine":
			_open_machine(str(structure.get_meta("stop", "camp")))
		"trip_bus":
			_board(str(structure.get_meta("stop", "camp")))
		"town_npc":
			var who := str(structure.get_meta("who", ""))
			if who == "driver":
				var k := _driver_line % DRIVER_LINES.size()
				_quote("Driver", DRIVER_LINES[k])
				_driver_voice(str(DRIVER_VOICE[k]), structure)
				_driver_line += 1
				return
			var said: Array = _town.spots["people"].talk(who, hour())
			_quote(str(said[0]), str(said[1]))
		"town_read":
			_say(MEMORIAL)
		"town_bench":
			_sit(structure)
		"town_pump":
			_fill_can()
		"trip_lojza":
			var job = _job()
			if job != null and _open("kiosk") and not job.on:
				_start_job()
			elif not _open("kiosk"):
				_quote("Lojza", LOJZA_NIGHT)
			else:
				_quote("Lojza", LOJZA_LINES[_lojza_line % LOJZA_LINES.size()])
				_lojza_line += 1
		"trip_pump":
			var job = _job()
			if job == null:
				return
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


## The driver's Czech (bus_talk.tsv "d_*") from where he is: his bus (or what was clicked).
func _driver_voice(key: String, near: Node) -> void:
	var path := "res://assets/sfx/bus/talk/%s_1.mp3" % key
	if not ResourceLoader.exists(path):
		return
	var bus: Node = near
	while bus != null and not bus.has_method("play"):
		bus = bus.get_parent()
	if bus != null:
		bus.play(path, -2.0)


## Lojza's job is at the Benzina by the camp's turn off road 12 (geo_world.gd); Liblice's
## is only for filling up.
func _job():
	return _geo.pump_job if _geo != null and is_instance_valid(_geo) else null


## Liblice's Benzina: self-service, pay at the kiosk window. Only your petrol can (from
## Vondra's garage) wants filling.
func _fill_can() -> void:
	var has: Dictionary = _hamlet.state["has"] if _hamlet != null else {}
	match str(has.get("canister", "")):
		"empty":
			if not _open("kiosk"):
				_say("The pump is locked for the night. A card on it: 6 - 21.")
			elif CoreRoot.get_money() < CAN_PRICE or not CoreRoot.actions.spend_money(CAN_PRICE):
				_say("Ten litres of Natural is $%d at the kiosk window. You have not got it." % CAN_PRICE)
			else:
				has["canister"] = "full"
				_say("Ten litres of Natural into the can, $%d through the kiosk window. It smells of the whole of 1985." % CAN_PRICE)
		"full":
			_say("The can is full already.")
		_:
			_say("Self-service: fill up, then pay at the kiosk window. You have nothing to fill.")


## Lojza's shift: cars come in off the road until you walk off or he shuts at nine.
func _start_job() -> void:
	var job = _job()
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
				_say("A card on the glass: JEDNOTA U MARKŮ, LIBLICE 42. Mon - Fri 7 - 17, Sat 7 - 11. Batteries sold out.")
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
		_room.can_buy = func(item: String) -> bool: return inventory == null or inventory.room_for(item)
		_room.bought.connect(func(item: String):
			if inventory != null and item in ["cigs", "beer", "card"]:
				inventory.add_item(item)
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
		scratch_card()
	elif kind == "slot":
		if _pub == null:
			_pub = PUB.new()
			add_child(_pub)
			_pub.closed.connect(_back_to_room)
		_pub.open_slot()


func _back_to_room() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if (_room != null and _room.is_open()) else Input.MOUSE_MODE_CAPTURED)
	if _card_from_bag:
		_card_from_bag = false
		_set_player_controls(true)


var _card_from_bag := false


## A Rychla kacka out of the bag, wherever you are: up close to scratch.
func scratch_card() -> void:
	if _shop == null:
		_shop = SHOP.new()
		add_child(_shop)
		_shop.closed.connect(_back_to_room)
	_card_from_bag = not (_room != null and _room.is_open())
	if _card_from_bag:
		_set_player_controls(false)
	_shop.open_card()


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


func _open_machine(stop: String) -> void:
	if _machine == null:
		_machine = MACHINE_CLOSEUP.new()
		add_child(_machine)
		_machine.closed.connect(_on_closeup_closed)
		_machine.ticket_taken.connect(func(to: String): _bought_to = to)
	_machine.stop = stop
	_set_player_controls(false)
	_machine.open_view()


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
	return (_timetable != null and _timetable.visible) or (_machine != null and _machine.visible) \
		or (_ride != null and _ride.is_open()) \
		or (_shop != null and _shop.visible) or (_pub != null and _pub.visible) \
		or (_room != null and _room.is_open()) \
		or (_job() != null and _job().is_open()) \
		or (_hamlet != null and _hamlet.is_open())


func close_interior() -> void:
	if _timetable != null and _timetable.visible:
		_timetable.close_view()
	if _machine != null and _machine.visible:
		_machine.close_view()
	if _ride != null and _ride.is_open():
		_ride.close_interior()
	if _shop != null and _shop.visible:
		_shop.close_view()
	if _pub != null and _pub.visible:
		_pub.close_view()
	if _room != null and _room.is_open():
		_room.close()
	if _job() != null and _job().is_open():
		_job().close()
	if _hamlet != null:
		_hamlet.close()


func set_time_state(_state: int) -> void:
	pass


# ── the buses ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Co-op: the other wardens in the same place in Lesna stand there with you.
	if _room != null and _room.is_open():
		var here: Array = []
		for id in Coop.others():
			if str(Coop.state_of(id).get("tr", "")) == str(_room.place):
				here.append(int(id))
		_room.coop_mates(here)
	var road := _road()
	if road == null:
		return
	_ensure_country()
	_update_seated()
	_update_ride_clock()
	var me := _player()
	if _geo != null and is_instance_valid(_geo) and me != null:
		var eye := _eye_for_geo(me)
		_geo.update(eye)
		# The village and the hamlet come when you get near, or when Builder's 3D view
		# goes to look at them.
		var near_eye := me.global_position if _builder_eye() == Vector3.INF else eye
		if _town == null and near_eye.distance_to(TOWN.ORIGIN) < TOWN_NEAR:
			_ensure_town()
		if near_eye.distance_to(HAMLET_PLACE.HAMLET_ORIGIN) < HAMLET_NEAR:
			_hamlet.ensure()
	if _masts != null and is_instance_valid(_masts):
		# The world's camera is in main's SubViewport, not ours: the player's eye.
		var eye := _player()
		if eye != null:
			_masts.update_view(_eye_for_geo(eye) + Vector3(0, 1.6, 0))
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
		if _geo != null and is_instance_valid(_geo):
			_geo.set_hour(h)
		_update_masts()
		_hamlet.tick_hour(h, _night)
		if _town != null:
			_town.set_night(_night)
			_town.set_hour(h)
			if _town_bus != null:
				_town_bus.set_night(_night)
	_coop_hold("camp", _camp_bus)
	_coop_hold_hamlet()
	_run_stop("camp", _camp_bus, delta, h)
	_update_mate_bus(delta)
	_hamlet.update(h, delta)
	_run_works(h, delta)
	if _town != null:
		_coop_hold("town", _town_bus)
		_run_stop("town", _town_bus, delta, h)
		_town.spots["people"].update(h, delta)
		_town.spots["station_cars"].traffic = _open("kiosk")
	_watch_job(h)
	_update_village_sound(h)
	_update_sleep(delta)


## The transmitter's masts over the fields by Lesna (liblice_masts.gd): in the world from
## the start, so their lamps show from the camp too.
func _update_masts() -> void:
	var main := _main()
	if main == null:
		return
	if _masts == null or not is_instance_valid(_masts):
		var world: Node = main.get("_world_3d")
		if world == null:
			return
		_masts = MASTS.new()
		world.add_child(_masts)
		_masts.position = Vector3.ZERO
		_masts.build()
	_masts.set_night(_night)
	var env_node = main.get("world_environment")
	var p := _player()
	if env_node != null and p != null:
		_masts.update_haze((env_node as WorldEnvironment).environment, p.global_position)


## The shift ends when you walk off from the station or at nine.
func _watch_job(_h: float) -> void:
	var job = _job()
	if job == null or not job.on:
		return
	var p := _player()
	var far: bool = p == null or p.global_position.distance_to(_geo.benzina_at) > 32.0
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
	# Along road 12 past the camp's turn, eastwards (scripts/geo/).
	var r12a := GEO.s_near(Vector3(26.0, 0, -335.0))
	_pass(_works_camp, GEO.line_path(r12a - 160.0, r12a + 700.0, 1.6, 10.0), fposmod(h - (TIMES.WORKS_CAMP - WORKS_HOURS * 0.5), 24.0) / WORKS_HOURS, delta)
	if _town != null:
		if _works_town == null or not is_instance_valid(_works_town):
			_works_town = BUS_MODEL.new()
			_works_town.name = "Bus380WorksLesna"
			_town.add_child(_works_town)
			_works_town.destination = "SLUZEBNI"
			_works_town.set_running(false)
		var s_l := GEO.stop_s("liblice")
		var path := GEO.line_path(s_l - 300.0, s_l + 520.0, 1.6, 10.0)
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
			runs.append({"arrive": TIMES.CAMP_ARRIVE[i], "leave": TIMES.CAMP_LEAVE[i], "in": road.bus_arrive_path(), "out": road.bus_leave_path(), "pose": road.bus_stop_pose(), "dest": "LIBLICE", "stop_id": "camp"})
	else:
		for i in TIMES.TOWN_ARRIVE.size():
			runs.append({"arrive": TIMES.TOWN_ARRIVE[i], "leave": TIMES.TOWN_LEAVE[i], "in": _town.bus_arrive_path("to_camp"), "out": _town.bus_leave_path("to_camp"), "pose": _town.bus_pose("to_camp"), "dest": "KEMP", "stop_id": "town"})
		for t in TIMES.TOWN_THROUGH:
			runs.append({"arrive": t, "leave": float(t) + THROUGH_STAND, "in": _town.bus_arrive_path("to_hlub"), "out": _town.bus_leave_path("to_hlub"), "pose": _town.bus_pose("to_hlub"), "dest": "LSTIBOR", "stop_id": "town_through"})
	return runs


## A bus held at the stop for you, or let off for you: by real seconds, not the clock.
func _run_special(stop: String, bus: Node3D, sp: Dictionary, delta: float) -> void:
	sp["t"] = float(sp.get("t", 0.0)) + delta
	bus.set_driver_out(false)
	if not bus.visible:
		bus.set_running(true)
		bus.destination = str(sp.get("dest", "LIBLICE"))
		bus.set_stop(str(sp.get("stop_id", stop)))
	match str(sp["mode"]):
		"ride":
			bus.set_running(false)
			return
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

## Another warden on the bus at `stop_id` (not yet gone): it stands for them here too.
## When it goes with them and not you, it goes from here as well.
func _coop_hold(stop_id: String, bus: Node3D) -> void:
	if bus == null or not Coop.has_partner():
		return
	var theirs := false
	var aboard := false
	for id in Coop.others():
		var mate = Coop.state_of(id).get("bus", {})
		var m: Dictionary = mate if mate is Dictionary else {}
		if not m.is_empty() and str(m.get("st", "")) == stop_id:
			theirs = true
			aboard = aboard or not bool(m.get("go", false))
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
			_special[stop_id] = {"mode": "drop", "t": 2.6, "pose": sp["pose"], "leave": out, "dest": sp["dest"], "stop_id": stop_id, "mate": true}
		else:
			_special.erase(stop_id)


## Co-op: another warden aboard at Pristoupim's pole and not gone: the bus there stands for
## them here too; gone with them (and not you), it pulls away.
var _hamlet_mate_hold := ""


func _coop_hold_hamlet() -> void:
	if _hamlet == null or not Coop.has_partner() or not _hamlet.is_built():
		return
	var aboard := ""
	var gone := ""
	for id in Coop.others():
		var b = Coop.state_of(id).get("bus", {})
		var m: Dictionary = b if b is Dictionary else {}
		var st := str(m.get("st", ""))
		if st.begins_with("hamlet"):
			if bool(m.get("go", false)):
				gone = st
			else:
				aboard = st
	var mine: bool = _ride != null and _ride.is_open() and _boarding_stop.begins_with("hamlet")
	if aboard != "" and not mine:
		_hamlet.hold(aboard)
		_hamlet_mate_hold = aboard
	elif _hamlet_mate_hold != "" and not mine:
		_hamlet.release()
		if gone != "":
			_hamlet.drop(gone == "hamlet_town")
		_hamlet_mate_hold = ""


## Co-op: the other warden's bus on the road, where their ride says it is (15 times a
## second, eased between). It takes over from the stop's bus pulling away with them; not
## while you ride (you are on it, or on your own).
func _update_mate_bus(delta: float) -> void:
	var want: Dictionary = {}
	if Coop.has_partner() and not _riding_now():
		for id in Coop.others():
			var b = Coop.state_of(id).get("bus", {})
			if b is Dictionary and (b as Dictionary).has("bt"):
				want = b
				break
	if want.is_empty() and not debug_mate.is_empty():
		want = debug_mate
	if want.is_empty():
		if _mate_bus != null and is_instance_valid(_mate_bus) and _mate_bus.visible:
			_mate_bus.set_running(false)
		return
	if _mate_bus == null or not is_instance_valid(_mate_bus):
		_mate_bus = BUS_MODEL.new()
		_mate_bus.name = "Bus380Mate"
		(_geo if _geo != null and is_instance_valid(_geo) else self).add_child(_mate_bus)
		_mate_bus.set_running(false)
	var t: Array = want["bt"]
	var target := Transform3D(Basis(Vector3.UP, float(t[3])), Vector3(float(t[0]), float(t[1]), float(t[2])))
	if not _mate_bus.visible:
		_mate_bus.set_running(true)
		_mate_bus.global_transform = target
		_mate_bus.destination = str(want.get("d", GEO.TOWN.to_upper()))
		_mate_bus.set_night(_night)
		_mate_bus_night = _night
		# The stop's bus that pulled away with them: this one is it now.
		var st := str(want.get("st", ""))
		var sp: Dictionary = _special.get(st, {})
		if bool(sp.get("mate", false)):
			_special.erase(st)
			var stop_bus = _camp_bus if st == "camp" else (_town_bus if st == "town" else null)
			if stop_bus != null and is_instance_valid(stop_bus):
				stop_bus.set_running(false)
	else:
		var k := clampf(delta * 10.0, 0.0, 1.0)
		var cur: Transform3D = _mate_bus.global_transform
		_mate_bus.global_transform = Transform3D(cur.basis.orthonormalized().slerp(target.basis, k), cur.origin.lerp(target.origin, k))
	_mate_bus.set_speed(float(want.get("v", 0.0)))
	if _mate_bus_night != _night:
		_mate_bus_night = _night
		_mate_bus.set_night(_night)


## Runs that went early with the other warden: no bus at that stop till their time is up.
var _coop_gone: Dictionary = {}


## Co-op: where you are on a bus, for the other machine.
func coop_state() -> Dictionary:
	return _ride.coop_state() if _ride != null else {}


## Co-op: Pristoupim's job (hamlet_trip.gd), for main's sync "hamlet".
func coop_hamlet() -> Dictionary:
	return _hamlet.shared() if _hamlet != null else {}


func coop_take_hamlet(d: Dictionary) -> void:
	if _hamlet != null:
		_hamlet.take_shared(d)


## Co-op: the place in Lesna you are in ("pub", "jednota"...), "" outside them.
func coop_place() -> String:
	return str(_room.place) if _room != null and _room.is_open() else ""


# ── getting on, the ride, getting off ────────────────────────────────────────

func _board(stop_id: String) -> void:
	if stop_id == "town_through":
		_say("Driver: \"Lstibor. Yours is the other side, to the camp.\"")
		_driver_voice("d_lstibor", _town_bus)
		return
	var at_hamlet := stop_id.begins_with("hamlet")
	var bus = _hamlet.bus_for(stop_id) if at_hamlet else (_camp_bus if stop_id == "camp" else _town_bus)
	if bus == null or not bus.is_door_open():
		return
	_boarding_stop = stop_id
	# The bus waits while you are on it.
	if at_hamlet:
		_hamlet.hold(stop_id)
	else:
		_special[stop_id] = {"mode": "hold", "t": 0.0, "pose": bus.global_transform, "dest": bus.destination, "stop_id": stop_id}
	if _ride == null:
		_ride = BUS_RIDE.new()
		add_child(_ride)
		_ride.arrived.connect(_on_ride_arrived)
		_ride.left_bus.connect(_on_left_bus)
	_ride.worldgen = _worldgen()
	_ride.stop_pos = bus.global_position
	_ride.bought_to = _bought_to
	_ride_road(stop_id, bus)
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(true)
	_set_player_controls(false)
	var ws = _main().get("weather_system") if _main() != null else null
	var fog := 1.0 if ws != null and int(ws.get("current_weather")) == 2 else 0.0
	var rain: bool = ws != null and ws.has_method("is_raining") and ws.is_raining()
	_ride.open_ride(stop_id, hour(), fog, rain)


## The road this ride takes (scripts/geo/): from the bus where it stands to where you
## will get off, in its lane, the speed the road allows at each point; the ride bus
## put where the stop's bus stood, which steps out of the way.
const RIDE_SPEED := {"road12": 19.5, "village": 12.0, "open": 15.5, "camp": 8.5}


func _ride_road(stop_id: String, bus: Node3D) -> void:
	var road := _road()
	var s_p := GEO.stop_s("pristoupim")
	var s_l := GEO.stop_s("liblice")
	var pts := PackedVector3Array()
	var lim := PackedFloat32Array()
	var hamlet_at := Vector3.INF
	match stop_id:
		"camp":
			_append(pts, lim, road.bus_leave_path(), -1.0)
			_append_line(pts, lim, 60.0, s_l + 4.0)
			hamlet_at = GEO.at(s_p + 5.0, 1.6)["p"]
		"hamlet_town":
			_append_line(pts, lim, s_p + 5.0, s_l + 4.0)
		"town":
			_append_line(pts, lim, s_l - 4.0, 60.0)
			_append(pts, lim, road.bus_arrive_path(), -1.0)
			hamlet_at = GEO.at(s_p - 5.0, -1.6)["p"]
		"hamlet_camp":
			_append_line(pts, lim, s_p - 5.0, 60.0)
			_append(pts, lim, road.bus_arrive_path(), -1.0)
	# Slower in the bends: what a bus can take round a curve of that radius.
	for i in range(1, pts.size() - 1):
		var a := pts[maxi(0, i - 3)]
		var b := pts[i]
		var c := pts[mini(pts.size() - 1, i + 3)]
		var ang := (b - a).normalized().angle_to((c - b).normalized())
		if ang > 0.02:
			var radius := (a.distance_to(b) + b.distance_to(c)) / ang
			lim[i] = minf(lim[i], maxf(4.0, sqrt(1.7 * radius)))
	_ride.path = pts
	_ride.path_limits = lim
	_ride.path_hamlet = -1.0
	if hamlet_at != Vector3.INF:
		var acc := 0.0
		var best := 1e9
		for i in pts.size():
			if i > 0:
				acc += pts[i].distance_to(pts[i - 1])
			var d := pts[i].distance_to(hamlet_at)
			if d < best:
				best = d
				_ride.path_hamlet = acc
	if _ride_bus == null or not is_instance_valid(_ride_bus):
		_ride_bus = BUS_MODEL.new()
		_ride_bus.name = "Bus380Ride"
		_geo.add_child(_ride_bus)
	_ride_bus.set_running(true)
	_ride_bus.set_inside_visible(false)
	_ride_bus.destination = bus.destination
	_ride_bus.set_night(_night)
	_ride_bus.set_driver_out(false)
	_ride_bus.global_transform = bus.global_transform
	_ride_bus.open_door(true, true)
	_ride.ride_bus = _ride_bus
	# The stop's own bus steps out (the ride's stands where it stood).
	if stop_id.begins_with("hamlet"):
		_hamlet.riding = true
	else:
		_special[stop_id]["mode"] = "ride"


func _append(pts: PackedVector3Array, lim: PackedFloat32Array, more: PackedVector3Array, speed: float) -> void:
	for p in more:
		if pts.size() > 0 and pts[pts.size() - 1].distance_to(p) < 0.5:
			continue
		pts.append(p)
		lim.append(speed if speed > 0.0 else float(RIDE_SPEED["camp"]))


## The real route from `s0` to `s1` in the bus's lane, with the speed each stretch
## allows: road 12 between the camp's junction and Pristoupim's, the villages, the open
## road between.
func _append_line(pts: PackedVector3Array, lim: PackedFloat32Array, s0: float, s1: float) -> void:
	var r12a := GEO.s_near(Vector3(26.0, 0, -335.0))
	var r12b := GEO.s_near(Vector3(2228.0, 0, 17.0))
	var s_p := GEO.stop_s("pristoupim")
	var s_l := GEO.stop_s("liblice")
	var line := GEO.line_path(s0, s1, 1.6)
	for k in line.size():
		var s := lerpf(s0, s1, float(k) / float(maxi(1, line.size() - 1)))
		var v: float = RIDE_SPEED["open"]
		if s > r12a + 15.0 and s < r12b - 25.0:
			v = RIDE_SPEED["road12"]
		elif absf(s - s_p) < 160.0 or s > s_l - 260.0:
			v = RIDE_SPEED["village"]
		if pts.size() > 0 and pts[pts.size() - 1].distance_to(line[k]) < 0.5:
			continue
		pts.append(line[k])
		lim.append(v)


func _on_left_bus() -> void:
	# Back out at the door: the bus goes on with its own time.
	_special.erase(_boarding_stop)
	_end_ride_bus()
	if _boarding_stop.begins_with("hamlet"):
		_hamlet.release()
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(false)
	_set_player_controls(true)


## The ride's bus goes; the stop's buses are themselves again, the clock its pace.
func _end_ride_bus() -> void:
	if _ride_bus != null and is_instance_valid(_ride_bus):
		_ride_bus.set_running(false)
	if _hamlet != null:
		_hamlet.riding = false
	var main := _main()
	if main != null:
		main.set("clock_scale", 1.0)
	if _ride != null:
		_ride.clock_scale = 1.0


func _on_ride_arrived() -> void:
	var from := _boarding_stop
	var towards_town := from == "camp" or from == "hamlet_town"
	_special.erase(from)
	# The run you rode is gone from where you got on (it left with you, early).
	if from == "camp" or from == "town":
		var run := _plan(from, hour())
		if not run.is_empty():
			_coop_gone[from] = float(run.get("leave", hour())) + OUT_HOURS
	_end_ride_bus()
	if from.begins_with("hamlet"):
		_hamlet.release()
	else:
		var bus = _camp_bus if from == "camp" else _town_bus
		if bus != null:
			bus.set_running(false)
			bus.set_driver_out(false)
	# Co-op: off the same bus, the other warden steps down beside the first.
	var beside := Vector3(1.1, 0.0, 0.0) if Coop.is_client() else Vector3.ZERO
	if _ride != null and str(_ride.arrived_where) == "hamlet":
		# Off at Podlesi's request stop: the bus stands a moment and goes on its way.
		_hamlet.ensure()
		_put_player(_hamlet.arrive_spot(towards_town).translated(beside))
		_hamlet.drop(towards_town)
	elif towards_town:
		_ensure_town()
		_put_player(_town.arrive_spot().translated(beside))
		# The bus you came on stands a moment by the square and goes on to Hlubocany.
		_special["town"] = {"mode": "drop", "t": 0.0, "pose": _town.bus_pose("to_hlub"), "leave": _town.bus_leave_path("to_hlub"), "dest": "LSTIBOR", "stop_id": "town_through"}
	else:
		var road := _road()
		_put_player(road.wait_spot().translated(beside))
		# The end of the line: it stands, then turns in the loop and goes back.
		_special["camp"] = {"mode": "drop", "t": -14.0, "pose": road.bus_stop_pose(), "leave": road.bus_leave_path(), "dest": "LIBLICE", "stop_id": "camp"}
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(false)
	_set_player_controls(true)


## The stop's machine: a ticket for the 380 into the bag (punch it on the bus).
func _buy_ticket() -> void:
	if inventory != null and not inventory.room_for("ticket"):
		_say("No room in the bag for a ticket.")
		return
	if CoreRoot.get_money() < TICKET_MACHINE.PRICE or not CoreRoot.actions.spend_money(TICKET_MACHINE.PRICE):
		_say("Two dollars. You have not got two dollars.")
		return
	var a := AudioStreamPlayer.new()
	a.stream = load("res://assets/sfx/bus/ticket_print.mp3")
	a.volume_db = -6.0
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
	if inventory != null:
		inventory.add_item("ticket")
	_bought_to = ""
	_say("A ticket for the 380. Punch it on the bus, in the orange box.")


## On a bench: down onto it looking the way it faces, the eye lower, the mouse still
## looks round; walking (or E) gets you up again (_process).
var _seated_on: Node3D
var _seated_head := Vector3.ZERO
var _seated_ms := 0


func _sit(seat: Node3D) -> void:
	var p := _player()
	if p == null or _seated_on != null or not ("seated" in p):
		return
	var bench := seat.get_parent() as Node3D
	var feet := bench.global_transform * Vector3(0, 0, 0.12)
	p.global_position = Vector3(feet.x, p.global_position.y, feet.z)
	p.rotation = Vector3(0, bench.global_rotation.y + PI, 0)
	p.set("seated", true)
	_seated_head = p.get("_base_head_pos")
	p.set("_base_head_pos", _seated_head - Vector3(0, 0.5, 0))
	_seated_on = bench
	_seated_ms = Time.get_ticks_msec()


func _update_seated() -> void:
	if _seated_on == null:
		return
	var p := _player()
	var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_backward").length() > 0.2
	var again := Input.is_action_just_pressed("interact") and Time.get_ticks_msec() - _seated_ms > 400
	if p == null or moving or again or not is_instance_valid(_seated_on) or is_open():
		if p != null:
			p.set("seated", false)
			p.set("_base_head_pos", _seated_head)
			if is_instance_valid(_seated_on):
				var out := _seated_on.global_transform * Vector3(0, 0, 0.75)
				p.global_position = Vector3(out.x, p.global_position.y, out.z)
		_seated_on = null


func _put_player(xf: Transform3D) -> void:
	var p := _player()
	if p == null:
		return
	p.global_position = xf.origin
	var fwd := -xf.basis.z
	p.rotation = Vector3(0, atan2(-fwd.x, -fwd.z), 0)
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO


## The real land round the camp (scripts/geo/geo_world.gd), made once for each new camp
## road; it says where the two places stand.
var _geo
var _country_road_id := 0
## The bus you ride (bus_model.gd): it carries bus_ride.gd's cabin along the real road;
## the stops' own buses step out of the way for it and take over where you get off.
var _ride_bus
## Co-op: the bus the other warden rides, on this machine (their ride's "bt").
var _mate_bus
var _mate_bus_night := false
## Tests only (tools): a ride state as if from the other machine, for the mate bus.
var debug_mate := {}


## The real land round the camp (scripts/geo/): built once per camp (a new game makes a
## new road and with it the land again); Liblice's centre and the farm at Pristoupim set
## in it first, their ground cleared of the real houses.
func _ensure_country() -> void:
	var road := _road()
	if road == null or (_geo != null and is_instance_valid(_geo) and _country_road_id == road.get_instance_id()):
		return
	if _geo != null and is_instance_valid(_geo):
		_geo.queue_free()
	_place_towns()
	var main := _main()
	var world: Node = main.get("_world_3d") if main != null and main.get("_world_3d") != null else main
	_geo = GEO_WORLD.new()
	world.add_child(_geo)
	_geo.build(_worldgen())
	for poly in _clearings():
		_geo.clear_area(poly)
	_country_road_id = road.get_instance_id()
	if _masts != null and is_instance_valid(_masts):
		_masts.position = Vector3.ZERO


## While you (or the other warden) ride, the clock runs so the ride takes the
## timetable's minutes: thirteen of them for the real road's five or so.
func _update_ride_clock() -> void:
	var main := _main()
	if main == null:
		return
	var scale := 1.0
	if _ride != null and _ride.is_open() and _ride.is_riding():
		if _ride.clock_scale >= 0.999:
			var minutes := TIMES.RIDE_HOURS * 60.0
			if _boarding_stop.begins_with("hamlet"):
				minutes = (TIMES.RIDE_HOURS - TIMES.TO_PRISTOUPIM) * 60.0 if _boarding_stop == "hamlet_town" else TIMES.TO_PRISTOUPIM * 60.0
			_ride.clock_scale = clampf(minutes / maxf(30.0, _ride.expected_seconds()) / BALANCE.GAME_MINUTES_PER_SECOND, 0.01, 1.0)
		scale = _ride.clock_scale
	elif _hamlet != null and _hamlet.driving():
		scale = _hamlet.drive_clock()
	elif Coop.has_partner() and Coop.is_host():
		for id in Coop.others():
			var b = Coop.state_of(id).get("bus", {})
			if b is Dictionary and bool((b as Dictionary).get("go", false)):
				scale = minf(scale, float((b as Dictionary).get("cs", 1.0)))
	main.set("clock_scale", scale)


## Where the land is built round: you, the bus you ride, or what Builder's 3D view looks
## at (scripts/builder/map3d.gd: free to roam the whole map from the PC).
func _eye_for_geo(me: Node3D) -> Vector3:
	var b := _builder_eye()
	if b != Vector3.INF:
		return b
	if _riding_now():
		return _ride_bus.global_position
	# In old Vondra's Skoda (hamlet_trip.gd, skoda_ride.gd).
	if _hamlet != null and _hamlet.driving():
		return _hamlet.drive_eye()
	return me.global_position


func _builder_eye() -> Vector3:
	var v := get_tree().get_first_node_in_group("builder_3d") if get_tree() != null else null
	return v.call("geo_eye") if v != null else Vector3.INF


func _riding_now() -> bool:
	return _ride != null and _ride.is_open() and _ride_bus != null and is_instance_valid(_ride_bus) and _ride_bus.visible


## The game's village in the real Liblice, its street along Bylanska past the stop, and
## the farm at the Pristoupim stop, its road along 1131 (both frames: local +x along the
## way the bus goes).
func _place_towns() -> void:
	TOWN.GEO_MODE = true
	var c: Dictionary = GEO.at(GEO.stop_s("liblice") + LIBLICE_PAST_STOP)
	var d: Vector3 = c["dir"]
	TOWN.ORIGIN = c["p"]
	TOWN.YAW = atan2(-d.z, d.x)
	var h: Dictionary = GEO.stop_point("pristoupim")
	var hd: Vector3 = h["dir"]
	HAMLET_PLACE.HAMLET_ORIGIN = h["p"]
	HAMLET_PLACE.HAMLET_YAW = atan2(-hd.z, hd.x)


## The game's own places in the real land (world xz): Liblice's centre and its stop, the
## farm at Pristoupim with its track, the ruin by the road, its stop poles.
func _clearings() -> Array:
	var out: Array = []
	var tb := Basis(Vector3.UP, TOWN.YAW)
	var stop_p: Vector3 = GEO.stop_point("liblice")["p"]
	var stop_local := tb.inverse() * (stop_p - TOWN.ORIGIN)
	out.append(_rect_poly(Rect2(-82.0, -62.0, 166.0, 112.0), TOWN.ORIGIN, tb))
	out.append(_rect_poly(Rect2(stop_local.x - 14.0, -10.0, 28.0, 20.0), TOWN.ORIGIN, tb))
	var hb := Basis(Vector3.UP, HAMLET_PLACE.HAMLET_YAW)
	for r in [Rect2(-46.0, 5.0, 92.0, 152.0), Rect2(-84.0, -18.0, 28.0, 16.0), Rect2(-12.0, -9.0, 24.0, 18.0)]:
		out.append(_rect_poly(r, HAMLET_PLACE.HAMLET_ORIGIN, hb))
	return out


func _rect_poly(r: Rect2, origin: Vector3, b: Basis) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var p: Vector3 = origin + b * Vector3(c.x, 0, c.y)
		out.append(Vector2(p.x, p.z))
	return out


func _ensure_town() -> void:
	_ensure_country()
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
	return {"in_town": away(), "inventory": inventory.export_state() if inventory != null else {},
		"hamlet": _hamlet.export_state() if _hamlet != null else {}}


func import_state(d: Dictionary) -> void:
	_ensure_country()
	# Saved in Lesna: Lesna is there again (the player's position is the game's).
	if bool(d.get("in_town", false)):
		_ensure_town()
	if _hamlet != null and d.get("hamlet") is Dictionary:
		_hamlet.import_state(d["hamlet"])
	if inventory == null:
		return
	var inv = d.get("inventory", null)
	if inv is Dictionary:
		inventory.import_state(inv, Coop.is_client())
	elif not Coop.is_client():
		# From before the bag: the counts of cigarettes and bottles, into it.
		inventory.import_state({}, false)
		var cigs := int(d.get("cigarettes", 0))
		while cigs > 0:
			inventory.add_item("cigs", mini(cigs, 20))
			cigs -= 20
		for i in int(d.get("beers", 0)):
			inventory.add_item("beer")
