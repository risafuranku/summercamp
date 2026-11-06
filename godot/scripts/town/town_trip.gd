extends Node

## Out of the camp and down the road: the barrier you can raise yourself
## (scripts/camp_gate.gd), the road through the forest to the bus stop
## (scripts/town/road_south.gd) with its timetable (timetable_closeup.gd, the times from
## bus_timetable.gd), the line 380 bus (bus_model.gd outside, bus_ride.gd inside) and
## Lesna at the other end (town_lesna.gd, built the first time you go) with old Vondra's
## farm at its south end; on the way the request stop at Pristoupim, only its poles in
## the fields (hamlet_trip.gd: "ham_*" things, its bus, the farm and the Skoda).
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
## station) stands with its centre this far up the road past the stop, its street along
## the route's (tools/geo/design_world.py keeps the road straight there).
const LIBLICE_PAST_STOP := 110.0
## Old Vondra's farm (hamlet_podlesi.gd): its track leaves the street this far past the
## stop, on the side the bus from the camp lets you off (tools/geo/design_world.py lays
## its gardens there).
const FARM_PAST_STOP := 25.0
## The real land is built round you (geo_world.gd); the village, and the farm with the
## request stop's poles, when you come this near them.
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
## The motel's plan (motel_plan.gd): its rooms, which are taken tonight, six, the bell at
## three, the guest in the car park.
const MOTEL_PLAN = preload("res://scripts/town/motel_plan.gd")
const TOWN_PLACES = preload("res://scripts/town/town_places.gd")
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
## Pristoupim's stop and Vondra's farm (hamlet_trip.gd): its place, bus and the Skoda.
var _hamlet
## The works bus after midnight (one for the camp's road, one for Lesna's).
var _works_camp
var _works_town
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
## A night slept in number four: the key stays in its door when you go out in the morning.
var _motel_slept := false
## The guest from the camp standing in the motel's car park some nights (gone for the
## night once you came near and looked away: that night's index).
var _watcher: Node3D
var _watcher_fig
var _watcher_gone := -999
const DOOM_FIGURE = preload("res://scripts/figures/doom_figure.gd")
## The night the bell rang at three (its index).
var _bell3_night := -999
## Number four's night (motel_night.gd): what woke you (the host weighs it, the others hear
## of it), the night it is counted for, how often, what, hours since; the bell's own wake.
const MOTEL_NIGHT = preload("res://scripts/town/motel_night.gd")
const CAMP_OFFICE = preload("res://scripts/reception/camp_office.gd")
var _wake_kind := ""
var _wakes_night := -999
var _wakes := 0
var _wake_had: Array = []
var _since_wake_h := 0.0
var _bell3_woke := -999
var _wake_rng := RandomNumberGenerator.new()
## Debug (tools/shot_driver.gd): what wakes you at the night's first step in four; true:
## nothing does.
var debug_force_wake := ""
var debug_quiet := false
var _night := false
var _night_poll := 0.0
## Line 380 (bus_line.gd, the user 4. 11., V14: one real bus in the one world, no ride in
## a bus of its own off the map): one bus a round where the clock puts it, the whole of
## its way; the ones near you (or carrying anybody) drawn, the spare ones built with the
## land (none is built on the road: no hitch as one comes round the bend).
const BUS_LINE = preload("res://scripts/town/bus_line.gd")
var line = BUS_LINE.new()
var _line_buses: Dictionary = {}
var _spare_buses: Array = []
var _spares_for := 0
## Each drawn round's stop last frame ("" going): to hear it pull in and away.
var _line_was: Dictionary = {}
## The round you ride: its key, day and round, the line's stop you got on at.
var _ride_key := ""
var _ride_day := 0
var _ride_round: Dictionary = {}
var _ride_from := ""
## The other wardens on a round's bus seen from outside it: peer id -> figure.
var _rider_figs: Dictionary = {}
var _rider_poses: Dictionary = {}
## A round's bus is drawn this near you (m), or whenever somebody rides it.
const LINE_SEE_M := 1300.0
## Who it waits for: somebody this near its door (m) and coming at it (m/s), at most this
## much longer (game hours; for somebody on board not yet sat, as long as it takes).
## Standing about by it (or just off it) keeps nobody.
const HURRY_M := 40.0
const HURRY_SPEED := 0.9
const HURRY_MAX := 0.4
## How far each warden was from each standing bus's door, and when (to tell coming at it).
var _door_dist: Dictionary = {}
## How near the spot by Pristoupim's pole (where its door stops) somebody waits for it to
## pull in (m): the poles stand on either side of the road, a round stops only for its own.
const POLE_WAIT_M := 8.0
## The stops' names on the buses' meta and the timetables, and the line's.
const UI_OF := {"camp": "camp", "l_down": "town", "l_up": "town_through", "p_up": "hamlet_town", "p_down": "hamlet_camp"}
const LINE_OF := {"camp": "camp", "town": "l_down", "town_through": "l_up", "hamlet_town": "p_up", "hamlet_camp": "p_down"}
## Where a ride from each stop gets you off: Liblice from the camp side, the camp from
## Liblice's.
const RIDE_TO := {"camp": "l_up", "l_down": "camp", "p_up": "l_up", "p_down": "camp"}


func setup(interior_manager: Node) -> void:
	_im = interior_manager
	if get_node_or_null("TownPlaces") == null:
		var places = TOWN_PLACES.new()
		places.name = "TownPlaces"
		places.trip = self
		add_child(places)
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
	# Not Main as the current scene (a check's own scene): null, not a bool.
	if main.get("_gameplay_started") != true or main.get("_menu_mode") == true:
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
	# On the bus you are where the bus is.
	var at: Vector3 = _ride_bus.global_position if _riding_now() else p.global_position
	return Vector2(at.x, at.z).length() > AWAY_DIST


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
			var door_id := str(structure.get_meta("door", ""))
			match door_id:
				"jednota":
					return "Go into the Jednota" if _open("jednota") else "Read the note on the door"
				"pub":
					return "Go into the pub" if _open("pub") else "Knock"
				"motel":
					return "Ask for a room"
				"kiosk":
					return "Knock on the kiosk window"
				"wc":
					return "Go to the toilet"
				"chapel":
					return "Go into the chapel"
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
			# Never locked, day or night (the user, 4. 11.): at night the candles burn
			# inside (chapel_view.gd).
			_open_room("chapel")
		"wc":
			# Round the side of the kiosk, never locked.
			_open_room("wc")


## In through the door: the room in 3D (scripts/town/town_room.gd), the frame of the
## village breaking up into it.
func _open_room(which: String) -> void:
	if _room == null:
		_room = TOWN_ROOM.new()
		add_child(_room)
		_room.set_modal_check(func(): return (_shop != null and _shop.visible) or (_pub != null and _pub.visible))
		_room.can_buy = func(item: String) -> bool: return inventory == null or inventory.room_for(item)
		_room.bought.connect(func(item: String):
			if inventory != null:
				inventory.add_item(item)
		)
		_room.drank.connect(func(): pockets.drunk += 1.0)
		_room.wants_closeup.connect(_room_closeup)
		_room.candle_lit.connect(func(count: int): Coop.send_place("town", "chapel", "candles", [count]))
		_room.closed.connect(func():
			_door_fx(false)
			_after_room(str(_room.place))
			_on_closeup_closed())
	_door_fx(true)
	_set_player_controls(false)
	_room.motel_block = _town.spots.get("motel_block") if _town != null else null
	_room.place_anchor = _town.spots.get(which) as Node3D if _town != null and _town.spots.get(which) is Node3D else null
	_room.place_shell = _town.spots.get(which + "_shell") as Node3D if _town != null and _town.spots.get(which + "_shell") is Node3D else null
	_room.motel_keys = _keys_on_board(_night_index(hour()))
	_room.open(which, hour())


func _room_closeup(kind: String) -> void:
	if kind == "motel_room" and _town != null and _town.spots.has("motel_block"):
		# Mr Simek at the desk.
		desk_talk()
		return
	if kind == "sleep":
		_sleep_in_room()
		return
	if kind == "bell":
		_ring_bell_now()
		return
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


# ── the motel (motel_plan.gd, motel_block.gd, motel_view.gd) ─────────────────

## The night a game hour belongs to (it begins at noon), as main counts days.
func _night_index(h: float) -> int:
	var main := _main()
	var day := int(main.get("_day_index")) if main != null and main.get("_day_index") != null else 1
	return day if h >= 12.0 else day - 1


func _motel_block() -> Node3D:
	if _town == null:
		return null
	var b = _town.spots.get("motel_block")
	return b as Node3D if b != null and is_instance_valid(b) else null


func _has_motel_key() -> bool:
	return inventory != null and inventory.has("key_motel")


## The room taken for the night: by you (your key) or by a warden with you (the corridor's
## door opens for whoever is with them, the desk has a spare). 0 none.
var motel_room_n := 0
var _party_room := 0
## Where each warden last went in the corridor (Coop "walk"), id -> spot.
var _mate_spots: Dictionary = {}


## The room your key opens (a key in the bag from a save before this game's session: four).
func _key_room() -> int:
	return motel_room_n if motel_room_n > 0 else MOTEL_PLAN.YOURS


## The keys on Simek's board: the rooms he lets, but the one taken.
func _keys_on_board(_night: int) -> Array:
	var out: Array = []
	for n in MOTEL_PLAN.LETS:
		if int(n) != _party_room:
			out.append(int(n))
	return out


func mate_spot(id: int) -> String:
	return str(_mate_spots.get(id, "lobby"))


## May you go in at room `n`'s door: your key to it, or another warden in there.
func may_enter(n: int) -> bool:
	if _has_motel_key() and _key_room() == n:
		return true
	for id in Coop.others():
		if str(Coop.state_of(id).get("tr", "")) == "motel_room:%d" % n:
			return true
	return false


func _one_shot(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var a := AudioStreamPlayer.new()
	a.stream = load(path)
	a.volume_db = db
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


## Simek's line for a key off his board, the money for it; after that it is yours.
const KEY_LINES := {
	2: "Two. The hunters' room. The stove works. Twelve dollars.",
	4: "Four. Best mattress we have. Fifteen dollars.",
	9: "Nine. The apartment. Twenty-five dollars. There is a fridge.",
	11: "Eleven. Ten dollars. Mr Hora has not been back for his things.",
}
const KEY_TAKEN := {
	2: "Number two. Lock it twice.",
	4: "Number four. Lock it twice.",
	9: "Number nine. Lock it twice.",
	11: "Number eleven. Lock it twice.",
}
const KEY_SPARE := {
	2: "Your friend has got two. There is a spare.",
	4: "Your friend has got four. Two beds. The spare.",
	9: "Your friend has got nine. The spare.",
	11: "Your friend has got eleven. The spare.",
}


## Simek speaking: to you, and for whoever else is at the reception to see.
func _simek(text: String) -> void:
	_room.say("Mr Simek", text)
	Coop.send_place("town", "motel", "say", [text])


## The key of room `n` shown to Simek: he says what it is and what it costs.
func key_line(n: int) -> void:
	var h := hour()
	if h >= 6.0 and h < MOTEL_FROM:
		_simek("Rooms from seven in the evening. Sit on the bench if you are tired.")
		return
	_simek(str(KEY_LINES.get(n, "")))


## At the counter: from seven; the money, and room `n`'s key goes into your bag. With a
## warden already in a room: the spare to that one. Returns whether it went.
func rent(n: int) -> bool:
	var h := hour()
	if h >= 6.0 and h < MOTEL_FROM:
		_simek("Rooms from seven in the evening. Sit on the bench if you are tired.")
		return false
	if _has_motel_key():
		_simek(str(KEY_TAKEN.get(_key_room(), "")))
		return false
	if inventory != null and not inventory.room_for("key_motel"):
		_simek("And where will you put the key? Empty your pockets first.")
		return false
	var price := int(MOTEL_PLAN.LETS.get(n, MOTEL_PRICE))
	var spare := _party_room > 0
	if spare:
		n = _party_room
		price = 0
	if price > 0 and (CoreRoot.get_money() < price or not CoreRoot.actions.spend_money(price)):
		_simek("That money is not on the counter. The bench by the pond is free.")
		return false
	if price > 0:
		_one_shot("res://assets/sfx/jednota/coin.mp3", -8.0)
	if inventory != null:
		inventory.add_item("key_motel")
	motel_room_n = n
	_party_room = n
	_one_shot(SFX_TOWN + "motel_key.mp3", -4.0)
	if _room != null and _room.has_method("take_key"):
		_room.take_key(n)
	_simek(str((KEY_SPARE if spare else KEY_TAKEN).get(n, "")))
	Coop.send_place("town", "motel", "book", [n])
	_update_motel(h)
	return true


## The desk: the spare to the room the other warden took; else he points at the board.
func desk_talk() -> void:
	if _party_room > 0 and not _has_motel_key():
		rent(_party_room)
		return
	if _has_motel_key():
		_simek(str(KEY_TAKEN.get(_key_room(), "")))
		return
	_simek("Keys are on the board. Take your pick.")


## Lying in four at night: the night passes (camp_office, both wardens in bed in co-op).
func _sleep_in_room() -> void:
	var office = _main().get("camp_office") if _main() != null else null
	if office == null or not office.has_method("start_sleep"):
		return
	_ensure_sleep_layer()
	_sleeping = true
	_sleep_fade = 0.0
	office.start_sleep()


## Out of a room: not in bed any more; out of it after a night there, the key is left in
## its door and the room is free again.
func left_motel_room() -> void:
	var office = _main().get("camp_office") if _main() != null else null
	if office != null and office.has_method("in_bed") and office.in_bed() and office.has_method("cancel_sleep"):
		office.cancel_sleep()
	if _motel_slept:
		_motel_slept = false
		if inventory != null:
			inventory.remove_item("key_motel")
		motel_room_n = 0
		_party_room = 0
		Coop.send_place("town", "motel", "book", [0])
	_update_motel(hour())


func _after_room(place: String) -> void:
	if place == "motel_room":
		left_motel_room()


## Every second: the motel's rooms as they are (yours lit while a warden is in it awake
## with a light on), the keys on the board, the guest in the car park.
func _update_motel(h: float) -> void:
	var block := _motel_block()
	if block == null:
		return
	var night := _night_index(h)
	var awake := {}
	if _room != null and _room.is_open() and str(_room.place) == "motel_room" and not _sleeping:
		var v = _room.get("_view")
		if v != null and v.lit():
			awake[int(_room.motel_n)] = true
	for id in Coop.others():
		var st: Dictionary = Coop.state_of(id)
		var tr := str(st.get("tr", ""))
		if tr.begins_with("motel_room:") and not bool(st.get("z", false)):
			awake[int(tr.substr(11))] = true
	block.awake_in = awake
	block.keys_on_board = _keys_on_board(night)
	block.set_state(h, night)
	_update_watcher(block, h, night)


## The guest who left the camp, in the car park looking up the road to it, some nights
## (motel_plan.carpark_watch): the last one to leave, as they looked. Once you have come
## near and looked away, gone for the night. Never explained.
func _update_watcher(block: Node3D, h: float, night: int) -> void:
	var win: Array = MOTEL_PLAN.carpark_watch(night)
	var hrs := h if h >= 12.0 else h + 24.0
	var want := not win.is_empty() and hrs >= float(win[0]) and hrs < float(win[1]) and night != _watcher_gone
	var path := _last_departed_sprite() if want else ""
	if path == "":
		want = false
	if not want:
		if _watcher != null and is_instance_valid(_watcher):
			_watcher.queue_free()
		_watcher = null
		_watcher_fig = null
		return
	if _watcher == null or not is_instance_valid(_watcher):
		var t: Texture2D = load(path)
		var sp := Sprite3D.new()
		sp.name = "CarParkGuest"
		sp.texture = t
		sp.pixel_size = 1.72 / float(t.get_height())
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = true
		sp.offset = Vector2(0, t.get_height() * 0.5)
		sp.modulate = Color(0.72, 0.72, 0.76)
		block.add_child(sp)
		# By the car park's edge, its back to the motel, looking towards the camp (the
		# world's middle): seen from eight sides as the guests are (doom_figure.gd).
		sp.position = Vector3(3.5, 0.0, MOTEL_PLAN.FRONT_Z - 5.2)
		_watcher = sp
		_watcher_fig = null
		var data: Dictionary = DOOM_FIGURE.set_for(path)
		if not data.is_empty():
			_watcher_fig = DOOM_FIGURE.new(sp, data, 1.74)
			_watcher_fig.face(-sp.global_position)
	var p := _player()
	if p == null:
		return
	var d := p.global_position.distance_to(_watcher.global_position)
	if d < 10.0:
		# Looked away from: gone.
		var cam := p.get_viewport().get_camera_3d() if p.get_viewport() != null else null
		var seen := cam != null and cam.is_position_in_frustum(_watcher.global_position + Vector3(0, 1.0, 0))
		if not seen:
			_watcher_gone = night
			_watcher.queue_free()
			_watcher = null
			_watcher_fig = null


## The picture of the last guest to leave the camp (its reviews keep who they were).
func _last_departed_sprite() -> String:
	var gm = get_node_or_null("/root/GuestManager")
	var st = CoreRoot.get("state")
	if gm == null or st == null:
		return ""
	var reviews = st.get("guest_reviews")
	if not (reviews is Array) or (reviews as Array).is_empty():
		return ""
	var last = (reviews as Array)[-1]
	var arch := str((last as Dictionary).get("archetype", "")) if last is Dictionary else ""
	if arch == "" or not gm.has_method("_sprite_path_for_archetype"):
		return ""
	var path := str(gm._sprite_path_for_archetype(arch))
	return path if ResourceLoader.exists(path) else ""


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
			if str(Coop.state_of(id).get("tr", "")) == coop_place():
				here.append(int(id))
		_room.coop_mates(here)
	var road := _road()
	if road == null:
		return
	# The land made this frame: the rest from the next (a new camp's first frames).
	if _ensure_country():
		return
	_update_seated()
	_update_ride_clock()
	var me := _player()
	if _geo != null and is_instance_valid(_geo) and me != null:
		var eye := _eye_for_geo(me)
		_geo.update(eye)
		# The village, the farm and the request stop come when you get near, or when
		# Builder's 3D view goes to look at them.
		var near_eye := me.global_position if _builder_eye() == Vector3.INF and not _riding_now() else eye
		if _town == null and near_eye.distance_to(TOWN.ORIGIN) < TOWN_NEAR:
			_ensure_town()
		if near_eye.distance_to(HAMLET_PLACE.HAMLET_ORIGIN) < HAMLET_NEAR or near_eye.distance_to(HAMLET_PLACE.STOP_ORIGIN) < HAMLET_NEAR:
			_hamlet.ensure()
	if _masts != null and is_instance_valid(_masts):
		# The world's camera is in main's SubViewport, not ours: the player's eye.
		var eye := _player()
		if eye != null:
			_masts.update_view(_eye_for_geo(eye) + Vector3(0, 1.6, 0))
	var h := hour()
	_night_poll -= delta
	if _night_poll <= 0.0:
		_night_poll = 1.0
		_night = h >= 19.0 or h < 6.0
		# Every 380 on the road lights up at dusk and stays lit till the morning: the
		# stop's, the ones passing, the other warden's, the one you ride (the user 4. 11.:
		# "the bus has no lights, in the evening you cannot see it going along the road").
		get_tree().call_group("bus_380", "set_night", _bus_lights(h))
		if _riding_now():
			_ride.set_time(h, 0.0, _raining_now())
		if _geo != null and is_instance_valid(_geo):
			_geo.set_hour(h)
		_update_masts()
		_hamlet.tick_hour(h, _night)
		if _town != null:
			_town.set_night(_night)
			_town.set_hour(h)
			_update_motel(h)
	_run_line()
	_hamlet.update(h, delta)
	_run_works(h, delta)
	if _town != null:
		_town.spots["people"].update(h, delta)
		_town.spots["street"].update(h, delta)
		_town.spots["station_cars"].traffic = _open("kiosk")
	_watch_job(h)
	_update_village_sound(h)
	_update_sleep(delta)
	if _watcher_fig != null and _watcher != null and is_instance_valid(_watcher) and me != null and me.get_viewport() != null:
		var eye_cam := me.get_viewport().get_camera_3d()
		if eye_cam != null:
			_watcher_fig.show(eye_cam.global_position)


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
		# From the eye that sees them: on the bus the bus, not the body left at the stop
		# (the guys went all but clear passing right by them, the user 4. 11.).
		_masts.update_haze((env_node as WorldEnvironment).environment, _eye_for_geo(p))


## The 380's lamps: on from a little before sunset (weather_visuals.SUNSET_HOUR 18.5) to
## a little after sunrise (6.5).
static func _bus_lights(h: float) -> bool:
	return h >= 18.25 or h < 6.75


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
	var three := hh == 3 and h - float(hh) < 0.1 and _bell3_night != _night_index(h) and MOTEL_PLAN.bell_at_three(_night_index(h))
	if three:
		_bell3_night = _night_index(h)
	if ((hh == 12 or hh == 18) and h - float(hh) < 0.1 and _bell_rung != hh) or three:
		_bell_rung = hh
		if _bell == null:
			_bell = AudioStreamPlayer3D.new()
			_bell.stream = load(SFX_TOWN + "chapel_bell.mp3")
			_bell.unit_size = 30.0
			_bell.max_distance = 300.0
			_town.add_child(_bell)
			_bell.position = Vector3(-28.0, 9.0, -24.5)
		_bell.play()


func _in_four() -> bool:
	return _room != null and _room.is_open() and str(_room.place) == "motel_room"


## The host's (or your own) night in four, a step of the clock: what wakes you, if
## anything (motel_night.gd), then the night stops for everybody and the room plays it.
## In co-op only with every warden asleep in four (getting up stops the night for all).
func _motel_night(office, delta: float) -> void:
	if Coop.is_client():
		return
	for id in Coop.others():
		if str(Coop.state_of(id).get("tr", "")) != coop_place():
			return
	var h := hour()
	var night := _night_index(h)
	if _wakes_night != night:
		_wakes_night = night
		_wakes = 0
		_wake_had = []
		_since_wake_h = 0.0
	var dt := delta * CAMP_OFFICE.SLEEP_RATE
	_since_wake_h += dt
	var kind := debug_force_wake
	debug_force_wake = ""
	if debug_quiet and kind == "":
		return
	# The bell at three, the nights it rings: it wakes you, mostly.
	if h >= 3.0 and h < 3.0 + dt * 1.5 + 0.05 and MOTEL_PLAN.bell_at_three(night) and _bell3_woke != night:
		_bell3_woke = night
		if _wake_rng.randf() < 0.75:
			kind = "bell"
	if kind == "":
		var hrs := h if h >= 12.0 else h + 24.0
		var win: Array = MOTEL_PLAN.carpark_watch(night)
		var ctx := {
			"hour": h, "sanity": _sanity_now(), "six": MOTEL_PLAN.six_lit(night, h), "rain": _raining_now(),
			"watch": not win.is_empty() and hrs >= float(win[0]) and hrs < float(win[1]) and night != _watcher_gone,
			"woken": _wakes, "since": _since_wake_h, "taken": MOTEL_PLAN.taken(night), "had": _wake_had,
			"sides": MOTEL_PLAN.beside(int(_room.motel_n)), "above": MOTEL_PLAN.above(int(_room.motel_n)),
		}
		var lam := MOTEL_NIGHT.hazard(ctx)
		if lam > 0.0 and _wake_rng.randf() < 1.0 - exp(-lam * dt):
			kind = MOTEL_NIGHT.pick(ctx, _wake_rng)
	if kind == "":
		return
	_wakes += 1
	_wake_had.append(kind)
	_since_wake_h = 0.0
	_wake_kind = kind
	if kind == "bell":
		_bell3_night = night
		_ring_bell_now()
	Coop.send_place("town", "motel", "wake", [kind])
	office.cancel_sleep()
	# The eyes were shut (however briefly): they open on it.
	_sleep_fade = 1.0


## The hidden sanity of the host's warden (coop_night.gd), 0..100.
func _sanity_now() -> float:
	var main := _main()
	var night = main.get("_coop_night") if main != null else null
	if night == null or not is_instance_valid(night):
		return 100.0
	var s = night.get("sanity")
	return float((s as Dictionary).get("host", 100.0)) if s is Dictionary else 100.0


func _raining_now() -> bool:
	var main := _main()
	var ws = main.get("weather_system") if main != null else null
	var w := int(ws.get("current_weather")) if ws != null else 0
	return w >= 3 and w <= 5


## Debug (tools/shot_driver.gd): the night in four stopped now by `kind`, as the host's
## clock would (for two machines too).
func debug_motel_wake(kind: String) -> void:
	_wake_kind = kind
	if kind == "bell":
		_ring_bell_now()
	Coop.send_place("town", "motel", "wake", [kind])
	var office = _main().get("camp_office") if _main() != null else null
	if office != null and office.has_method("cancel_sleep"):
		office.cancel_sleep()


## Somebody pulled the chapel's rope: the bell over the village, a few strokes.
func _ring_bell_now() -> void:
	if _town == null:
		return
	if _bell == null:
		_bell = AudioStreamPlayer3D.new()
		_bell.stream = load(SFX_TOWN + "chapel_bell.mp3")
		_bell.unit_size = 30.0
		_bell.max_distance = 300.0
		_town.add_child(_bell)
		_bell.position = Vector3(-28.0, 9.0, -24.5)
	_bell.play()


## The other wardens' doings in Liblice's places (Coop.send_place "town", through
## town_places.gd): the chapel's candles burning.
func coop_town_place(key: String, op: String, data: Array) -> void:
	if key == "motel" and op == "book" and not data.is_empty():
		# A warden took a key off the board (0: gave it back in the morning).
		var n := int(data[0])
		_party_room = n
		if n == 0 and motel_room_n != 0 and not _in_four():
			motel_room_n = 0
		if n > 0 and _room != null and _room.is_open() and str(_room.place) == "motel":
			_room.take_key(n)
			_room.set("_npc_nod", 0.6)
			_one_shot(SFX_TOWN + "motel_key.mp3", -9.0)
		_update_motel(hour())
		return
	if key == "motel" and op == "say" and not data.is_empty():
		# What Simek told the other warden at the counter.
		if _room != null and _room.is_open() and str(_room.place) == "motel":
			_room.say("Mr Simek", str(data[0]))
			_room.set("_npc_nod", 0.5)
		return
	if key == "motel" and op == "walk" and not data.is_empty():
		var who := int(Coop.get("sender"))
		_mate_spots[who] = str(data[0])
		if _room != null and _room.is_open():
			var here = _room.get("_view")
			if here != null and here.has_method("mate_walk"):
				here.mate_walk(who, str(data[0]))
		return
	if key == "motel" and op == "room" and data.size() >= 2:
		# What a warden switched in the room you are both in.
		if _in_four() and int(_room.motel_n) == int(data[0]):
			var v = _room.get("_view")
			if v != null and v.has_method("take_state"):
				v.take_state(data[1])
		return
	if key == "motel" and op == "wake" and not data.is_empty():
		# The host's night in four stopped: what woke them wakes you too.
		var kind := str(data[0])
		if kind == "bell":
			_ring_bell_now()
		if _sleeping and _in_four():
			# Up off the pillow here too, now (this machine may not have seen the night
			# begin yet: the host's clock stopped at its first step).
			_wake_kind = kind
			var office = _main().get("camp_office") if _main() != null else null
			if office != null and office.has_method("cancel_sleep"):
				office.cancel_sleep()
			_sleep_fade = 1.0
		elif _in_four():
			_room.woken_now(kind)
		return
	if key == "chapel" and op == "candles" and not data.is_empty():
		var n := int(data[0])
		if _room == null:
			return
		var had := int(_room.get("_candles"))
		_room.set("_candles", maxi(had, n))
		var v = _room.get("_view")
		if _room.is_open() and str(_room.place) == "chapel" and v != null and v.has_method("add_flame"):
			for i in maxi(0, n - v.flames.size()):
				v.add_flame()


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
		# In co-op whoever lies down first lies there with the room (the TV, the lamp)
		# till the other is in bed too; the black comes when the night does.
		var dark: bool = not Coop.has_partner() or office == null or office.night_begun()
		if dark:
			_sleep_fade = minf(1.0, _sleep_fade + delta * 1.5)
			# Eyes shut: the room's windows need not draw the village.
			if _sleep_fade >= 1.0 and _room != null and _room.is_open():
				_room.set_asleep(true)
		# Number four's night, weighed as it passes: something may wake you (the eyes shut
		# all the same before they open on it).
		if office != null and office.is_fast_forwarding() and _in_four():
			_motel_night(office, delta)
		if office != null and not office.is_sleeping_through() and _sleep_fade >= 1.0:
			_sleeping = false
			if _in_four():
				_room.set_asleep(false)
				var h := hour()
				if h >= 12.0 or h < CAMP_OFFICE.WAKE_HOUR - 0.3:
					# Still the night: something woke you (or the other warden got up).
					_room.woken_now(_wake_kind)
					_wake_kind = ""
					return
				# The morning in number four, in the bed you went to sleep in.
				_motel_slept = true
				_room.morning_now(h)
				return
			if _town != null:
				_put_player(Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), _town.w(Vector3(-27.0, 0.15, 8.0))))
			_set_player_controls(true)
	else:
		_sleep_fade = maxf(0.0, _sleep_fade - delta * 0.8)
	_sleep_rect.color.a = floorf(_sleep_fade * 6.0) / 6.0


## What the bus at `stop` does at hour `h`: where it is, its door, its speed.
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
	var r12a := GEO.mark_s("main_from")
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


# ── line 380: the rounds on the road ─────────────────────────────────────────

## Game hours since the first day began (the line's clock).
func abs_hour() -> float:
	return float(CoreRoot.get_day()) * 24.0 + hour()


## Puts every round near you where the clock has it: on the road, standing at a stop
## with its door open (clickable), the driver out for a smoke at the end of the line; the
## one you ride carries your cabin. Who the rounds wait and pull in for (_line_keep).
func _run_line() -> void:
	var road := _road()
	if road == null or not line.build(road):
		return
	_prewarm_buses()
	_take_host_line()
	var at := abs_hour()
	var eye := _eye_for_geo(_player()) if _player() != null else Vector3.ZERO
	var entries: Array = line.on_road(at)
	var seen := {}
	for e in entries:
		var st: Dictionary = e["st"]
		var key := str(st["key"])
		var xf: Transform3D = line.pose_at(float(st["s"]))
		var mine := key == _ride_key and _ride_bus != null
		if not mine and not _anyone_on(key) and xf.origin.distance_to(eye) > LINE_SEE_M:
			continue
		seen[key] = true
		var bus = _line_bus(key)
		_show_round(bus, key, e, xf)
		if mine and _ride != null and _ride.is_open():
			_ride.feed_line(_line_feed(st))
	for key in _line_buses.keys():
		if not seen.has(key):
			_park_bus(str(key))
	# The round you were on is off the road (the clock jumped): off where you are going.
	if _ride_key != "" and _ride != null and _ride.is_open() and not seen.has(_ride_key):
		_ride._shut()
		_on_ride_arrived()
	_line_keep(entries, at)
	_update_rider_figs()
	line.forget_before(int(floor(at / 24.0)))


func _line_feed(st: Dictionary) -> Dictionary:
	var out := st.duplicate()
	out["to_s"] = float(line.stop_at.get(str(st.get("to", "")), -1.0))
	return out


## Spare buses built with the land, so none is built where it is seen: one a frame (three
## at once were a frame of their own as a new camp began).
const SPARE_BUSES := 3


func _prewarm_buses() -> void:
	if _geo == null or not is_instance_valid(_geo):
		return
	if _spares_for != _geo.get_instance_id():
		_spares_for = _geo.get_instance_id()
		_line_buses.clear()
		_spare_buses.clear()
		_line_was.clear()
	if _spare_buses.size() + _line_buses.size() < SPARE_BUSES:
		_spare_buses.append(_new_bus())


func _new_bus() -> Node3D:
	var bus = BUS_MODEL.new()
	bus.name = "Bus380"
	(_geo if _geo != null and is_instance_valid(_geo) else self).add_child(bus)
	bus.set_running(false)
	return bus


func _line_bus(key: String) -> Node3D:
	var bus = _line_buses.get(key)
	if bus != null and is_instance_valid(bus):
		return bus
	while not _spare_buses.is_empty() and (bus == null or not is_instance_valid(bus)):
		bus = _spare_buses.pop_back()
	if bus == null or not is_instance_valid(bus):
		bus = _new_bus()
	_line_buses[key] = bus
	_line_was.erase(key)
	return bus


func _park_bus(key: String) -> void:
	var bus = _line_buses.get(key)
	_line_buses.erase(key)
	_line_was.erase(key)
	if bus != null and is_instance_valid(bus):
		bus.set_running(false)
		bus.open_door(false, true)
		bus.set_driver_out(false)
		bus.set_inside_visible(true)
		_spare_buses.append(bus)


## The bus standing at a stop now (the timetables' name for it: "camp", "town"...), or null.
func bus_at(ui_stop: String) -> Node3D:
	var e := _round_at(str(LINE_OF.get(ui_stop, ui_stop)))
	return _line_buses.get(str(e["st"]["key"])) if not e.is_empty() else null


func _round_at(stop: String) -> Dictionary:
	for e in line.on_road(abs_hour()):
		if str((e["st"] as Dictionary).get("stand", "")) == stop:
			return e
	return {}


func _show_round(bus: Node3D, key: String, e: Dictionary, xf: Transform3D) -> void:
	var st: Dictionary = e["st"]
	var r: Dictionary = e["r"]
	var stand := str(st.get("stand", ""))
	var was := str(_line_was.get(key, "?"))
	if not bus.visible:
		bus.set_running(true)
		bus.set_night(_bus_lights(hour()))
	bus.set_inside_visible(key != _ride_key)
	var board := "SLUZEBNI" if bool(r.get("staff", false)) else _board_text(float(st["s"]), stand)
	if str(bus.destination) != board:
		bus.destination = board
	bus.global_transform = xf
	bus.set_speed(float(st.get("v", 0.0)))
	if bus.has_method("set_steer"):
		bus.set_steer(line.steer_at(float(st["s"])))
	if stand != "":
		bus.set_stop(str(UI_OF.get(stand, stand)))
		# The doors open once it stands, shut a moment before it goes.
		bus.open_door(float(st.get("since", 0.0)) > 0.4 / 60.0 and float(st.get("left", 0.0)) > 1.5 / 60.0)
		# The driver smokes at the end of the line while there is time for it.
		bus.set_driver_out(stand == "camp" and key != _ride_key and float(st.get("since", 0.0)) > 3.0 / 60.0 and float(st.get("left", 0.0)) > 5.0 / 60.0)
		if was == "":
			bus.play("res://assets/sfx/bus/arrive.mp3", -10.0)
	else:
		bus.set_driver_out(false)
		bus.open_door(false, true)
		if was != "" and was != "?":
			bus.play("res://assets/sfx/bus/depart.mp3", -5.0)
	_line_was[key] = stand


## The destination board: coming down KEMP, at the camp and up to Liblice LIBLICE, on
## from there LSTIBOR.
func _board_text(s: float, stand: String) -> String:
	if stand == "camp" or (s > float(line.stop_at["camp"]) and s < float(line.stop_at["l_up"])):
		return GEO.TOWN.to_upper()
	if s >= float(line.stop_at["l_up"]):
		return "LSTIBOR"
	return "KEMP"


## Anybody (another warden) on that round's bus.
func _anyone_on(key: String) -> bool:
	for id in Coop.others():
		var b = Coop.state_of(id).get("bus", {})
		if b is Dictionary and str((b as Dictionary).get("rk", "")) == key:
			return true
	return false


## Who the rounds wait and pull in for: you (or the other warden) on board and not yet
## sat down, or getting off; somebody hurrying for a bus standing at a stop (a while);
## somebody waiting by Pristoupim's pole as a round comes up to it. The host decides for
## everybody in co-op (its rounds go to the other machine: coop_line), the other machine
## for itself till the host's word comes back (_take_host_line).
func _line_keep(entries: Array, at: float) -> void:
	var wardens: Array = []
	var me := _player()
	var now := Time.get_ticks_msec()
	if me != null:
		var mine: Dictionary = _ride.coop_state() if _ride != null and _ride.is_open() else {}
		wardens.append({"id": 0, "p": me.global_position, "in": _ride != null and _ride.is_open(), "bus": mine})
	if not Coop.is_client():
		for id in Coop.others():
			var st: Dictionary = Coop.state_of(id)
			var b = st.get("bus", {})
			wardens.append({"id": int(id), "p": st.get("p", Vector3.INF), "in": bool(st.get("in", false)), "bus": b if b is Dictionary else {}})
	for e in entries:
		var st2: Dictionary = e["st"]
		var key := str(st2["key"])
		var day := int(e["day"])
		var r: Dictionary = e["r"]
		var stand := str(st2.get("stand", ""))
		if stand != "":
			if float(st2.get("left", 1.0)) > 3.0 / 60.0:
				continue
			var keep := false
			var hurry := false
			var door: Vector3 = (_door_out(line.pose_at(float(st2["s"])))).origin
			for w in wardens:
				var b2: Dictionary = w["bus"]
				if str(b2.get("rk", "")) == key and (int(b2.get("s", -1)) < 0 or str(b2.get("off", "")) != ""):
					keep = true
				var p: Vector3 = w["p"]
				if b2.is_empty() and not bool(w["in"]) and p != Vector3.INF:
					var dk := "%d|%s" % [int(w["id"]), key]
					var dist := Vector2(p.x - door.x, p.z - door.z).length()
					var prev: Array = _door_dist.get(dk, [dist, now])
					_door_dist[dk] = [dist, now]
					var secs := float(now - int(prev[1])) / 1000.0
					if dist < HURRY_M and secs > 0.0 and secs < 1.0 and (float(prev[0]) - dist) / secs > HURRY_SPEED:
						hurry = true
			var held: float = float((line.live.get(key, {}) as Dictionary).get("h", {}).get(stand, 0.0))
			if keep or (hurry and held < HURRY_MAX):
				line.hold(day, r, stand, at)
			continue
		# Coming up to Pristoupim: somebody waiting by its pole, or asked for on board.
		var to := str(st2.get("to", ""))
		for pole in ["p_up", "p_down"]:
			var ahead := float(line.stop_at[pole]) - float(st2["s"])
			if ahead < 0.0 or ahead > 900.0 or line.serves(day, r, pole):
				continue
			var pole_at: Vector3 = _door_out(line.pose_at(float(line.stop_at[pole]))).origin
			for w in wardens:
				var b3: Dictionary = w["bus"]
				if str(b3.get("rk", "")) == key and str(b3.get("rq", "")) == pole:
					line.request(day, r, pole, "mate", at)
					break
				var p2: Vector3 = w["p"]
				if b3.is_empty() and not bool(w["in"]) and p2 != Vector3.INF and Vector2(p2.x - pole_at.x, p2.z - pole_at.z).length() < POLE_WAIT_M:
					line.request(day, r, pole, "wait", at)
					break
		if to == "":
			pass


## The ride asks the round you are on to pull in at Pristoupim (bus_ride._line_ask).
func line_ask(pole: String, who: String) -> String:
	if _ride_key == "":
		return "past"
	return line.request(_ride_day, _ride_round, pole, who, abs_hour())


## Co-op: the host's rounds (what they wait and pull in for), for the other machine.
func coop_line() -> Dictionary:
	if not Coop.has_partner() or Coop.is_client():
		return {}
	return line.live


## The other machine: the host's rounds, with what this one asked for itself and the
## host has not taken in yet (it only ever adds: longer waits, more stops).
func _take_host_line() -> void:
	if not Coop.is_client():
		return
	for id in Coop.others():
		var ln = Coop.state_of(id).get("ln", null)
		if not (ln is Dictionary):
			continue
		var merged: Dictionary = (ln as Dictionary).duplicate(true)
		for k in line.live.keys():
			var mine: Dictionary = line.live[k]
			var theirs: Dictionary = merged.get(k, {})
			for pole in ["p_up", "p_down"]:
				if str(mine.get(pole, "")) != "" and str(theirs.get(pole, "")) == "":
					theirs[pole] = mine[pole]
			var hm: Dictionary = (theirs.get("h", {}) as Dictionary).duplicate()
			var mh: Dictionary = mine.get("h", {})
			for stp in mh.keys():
				hm[stp] = maxf(float(hm.get(stp, 0.0)), float(mh[stp]))
			theirs["h"] = hm
			merged[k] = theirs
		line.take_live(merged)
		return


## The other wardens on a round's bus, seen from outside it: in their seat (or standing
## by the driver while they get their ticket) behind the windows.
func _update_rider_figs() -> void:
	var want := {}
	for id in Coop.others():
		var b = Coop.state_of(id).get("bus", {})
		if not (b is Dictionary) or str((b as Dictionary).get("rk", "")) == "":
			continue
		var key := str(b["rk"])
		# (On it with them, your cabin shows them.)
		if key == _ride_key and _ride != null and _ride.is_open():
			continue
		var bus = _line_buses.get(key)
		if bus == null or not is_instance_valid(bus) or not bus.visible:
			continue
		want[int(id)] = [bus, b]
	for id in _rider_figs.keys():
		if not want.has(id) and is_instance_valid(_rider_figs[id]):
			(_rider_figs[id] as Node3D).visible = false
	for id in want.keys():
		var bus: Node3D = want[id][0]
		var b: Dictionary = want[id][1]
		var fig: Sprite3D = _rider_figs.get(id)
		if fig == null or not is_instance_valid(fig):
			fig = Sprite3D.new()
			fig.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			fig.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			fig.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			fig.shaded = true
			_rider_figs[id] = fig
			_rider_poses[id] = ""
		if fig.get_parent() != bus:
			if fig.get_parent() != null:
				fig.get_parent().remove_child(fig)
			bus.add_child(fig)
		var seat := int(b.get("s", -1))
		var pose := "sit" if seat >= 0 and seat < BUS_RIDE.SEATS.size() else "stand"
		var look: Dictionary = Coop.look_of(id)
		var pk := "%s|%d|%d" % [pose, int(look.get("m", 1)), int(look.get("c", 0))]
		if pk != str(_rider_poses.get(id, "")):
			_rider_poses[id] = pk
			fig.texture = BUS_RIDE.LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), pose)
		var h := float(fig.texture.get_height()) if fig.texture != null else 96.0
		if pose == "sit":
			var sv: Vector2 = BUS_RIDE.SEATS[seat]
			fig.pixel_size = BUS_RIDE.SIT_TALL / h
			fig.offset = Vector2(0.0, h * 0.5)
			fig.position = Vector3(sv.x, BUS_MODEL.FLOOR_Y + BUS_RIDE.SEAT_TOP - BUS_RIDE.SIT_LINE * BUS_RIDE.SIT_TALL, sv.y - BUS_RIDE.SIT_FORWARD)
		else:
			fig.pixel_size = 1.62 / h
			fig.offset = Vector2(0.0, h * 0.5)
			fig.position = Vector3(0.25, BUS_MODEL.FLOOR_Y, -3.5)
		fig.visible = true


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
	if _room == null or not _room.is_open():
		return ""
	if str(_room.place) == "motel_room":
		return "motel_room:%d" % int(_room.motel_n)
	return str(_room.place)


# ── getting on, the ride, getting off ────────────────────────────────────────

func _board(stop_id: String) -> void:
	if stop_id == "town_through":
		_say("Driver: \"Lstibor. Yours is the other side, to the camp.\"")
		_driver_voice("d_lstibor", bus_at("town_through"))
		return
	var at_stop := str(LINE_OF.get(stop_id, ""))
	var e := _round_at(at_stop)
	if e.is_empty():
		return
	var key := str(e["st"]["key"])
	var bus = _line_buses.get(key)
	if bus == null or not is_instance_valid(bus) or not bus.is_door_open():
		return
	var r: Dictionary = e["r"]
	# The hands' works run takes nobody but them.
	if bool(r.get("staff", false)):
		_say(tr("Driver: \"Staff only. Yours is the 380.\""))
		return
	_boarding_stop = stop_id
	_ride_key = key
	_ride_day = int(e["day"])
	_ride_round = r
	_ride_from = at_stop
	if _ride == null:
		_ride = BUS_RIDE.new()
		add_child(_ride)
		_ride.arrived.connect(_on_ride_arrived)
		_ride.left_bus.connect(_on_left_bus)
	_ride.worldgen = _worldgen()
	_ride.stop_pos = bus.global_position
	_ride.bought_to = _bought_to
	# The round's own bus carries the cabin (bus_line.gd): it goes when its time comes.
	_ride.line_mode = true
	_ride.line_to = str(RIDE_TO.get(at_stop, "l_up"))
	_ride.run_key = key
	_ride.line_request = line_ask
	_ride.line_why = func(pole: String) -> String: return line.why(_ride_day, _ride_round, pole)
	_ride.path = line.pts
	_ride.path_limits = line.lim
	_ride.path_hamlet = float(line.stop_at.get("p_up" if _ride.line_to == "l_up" else "p_down", -1.0))
	_ride.ride_bus = bus
	_ride_bus = bus
	bus.set_inside_visible(false)
	bus.set_driver_out(false)
	_ride.feed_line(_line_feed(e["st"]))
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(true)
	# What it goes past and to is built now, under the step in (not with a jolt on the way).
	_hamlet.ensure()
	if _ride.line_to == "l_up":
		_ensure_town()
	_set_player_controls(false)
	var ws = _main().get("weather_system") if _main() != null else null
	var fog := 1.0 if ws != null and int(ws.get("current_weather")) == 2 else 0.0
	var rain: bool = ws != null and ws.has_method("is_raining") and ws.is_raining()
	_ride.open_ride(stop_id, hour(), fog, rain)


func _on_left_bus() -> void:
	# Back out of its door before it went: beside it at the stop.
	var bus = _ride_bus
	_end_ride_bus()
	if bus != null and is_instance_valid(bus):
		_put_player(_door_out(bus.global_transform))
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(false)
	_set_player_controls(true)


## Off the round's bus: its inside shows again (the cabin is gone), the clock as ever.
func _end_ride_bus() -> void:
	if _ride_bus != null and is_instance_valid(_ride_bus):
		_ride_bus.set_inside_visible(true)
	_ride_bus = null
	_ride_key = ""
	_ride_round = {}
	_ride_from = ""
	var main := _main()
	if main != null:
		main.set("clock_scale", 1.0)
	if _ride != null:
		_ride.clock_scale = 1.0


## Off where the bus stands (the user 4. 11.: "I see them get off"): down its steps and
## out of its door, beside it, the bus there as it is; it goes on by the clock. The
## village (or Vondra's farm and the pole) are there already (built as it came near).
func _on_ride_arrived() -> void:
	var bus = _ride_bus
	var to := str(_ride.line_to) if _ride != null else ""
	var where := str(_ride.arrived_where) if _ride != null else ""
	var spot := Transform3D()
	var have_spot := false
	if bus != null and is_instance_valid(bus) and bus.visible:
		spot = _door_out(bus.global_transform)
		have_spot = true
	_end_ride_bus()
	if where == "hamlet":
		_hamlet.ensure()
	elif to == "l_up" or where == "l_up" or where == "l_down":
		_ensure_town()
	if not have_spot:
		# (Off the road altogether, the clock jumped: at the stop it was going to.)
		if where == "hamlet":
			spot = _hamlet.arrive_spot(to == "l_up")
		elif to == "camp":
			spot = _road().wait_spot()
		else:
			spot = _town.arrive_spot()
	# Co-op: the other warden steps down a pace further along.
	if Coop.is_client():
		spot.origin += spot.basis.x * 0.9
	_put_player(spot)
	if _im != null and _im.has_method("_door_transition"):
		_im._door_transition(false)
	_set_player_controls(true)


## Just outside a bus's front door (on its right, bus_model.gd), turned out and a little
## forward, the way you step down.
func _door_out(bus_xf: Transform3D) -> Transform3D:
	var mid: float = (BUS_MODEL.DOOR_Z.x + BUS_MODEL.DOOR_Z.y) * 0.5
	var p: Vector3 = bus_xf * Vector3(BUS_MODEL.WIDTH * 0.5 + 0.85, 0.15, mid)
	var face: Vector3 = bus_xf.basis * Vector3(1.0, 0.0, -0.35)
	face.y = 0.0
	return Transform3D(Basis.looking_at(face.normalized(), Vector3.UP), p)


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
## The bus you ride: the round's own (bus_line.gd), carrying bus_ride.gd's cabin.
var _ride_bus


## The real land round the camp (scripts/geo/): built once per camp (a new game makes a
## new road and with it the land again); Liblice's centre, Vondra's farm and the poles at
## Pristoupim set in it first, their ground cleared of the real houses.
func _ensure_country() -> bool:
	var road := _road()
	if road == null or (_geo != null and is_instance_valid(_geo) and _country_road_id == road.get_instance_id()):
		return false
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
	return true


## The clock runs as ever on the bus (the user, 4. 11.); only old Vondra's Skoda still
## has its own (hamlet_trip.gd).
func _update_ride_clock() -> void:
	var main := _main()
	if main == null:
		return
	var scale := 1.0
	if _hamlet != null and _hamlet.driving():
		scale = _hamlet.drive_clock()
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


## The game's village in the real Liblice, its street along Bylanska past the stop; old
## Vondra's farm at its south end, its track off the street just past the stop; the
## request stop at Pristoupim out in the fields (all frames: local +x along the way the
## bus goes to Liblice).
func _place_towns() -> void:
	TOWN.GEO_MODE = true
	var c: Dictionary = GEO.at(GEO.stop_s("liblice") + LIBLICE_PAST_STOP)
	var d: Vector3 = c["dir"]
	TOWN.ORIGIN = c["p"]
	TOWN.YAW = atan2(-d.z, d.x)
	var f: Dictionary = GEO.at(GEO.stop_s("liblice") + FARM_PAST_STOP)
	var fd: Vector3 = f["dir"]
	HAMLET_PLACE.HAMLET_ORIGIN = f["p"]
	HAMLET_PLACE.HAMLET_YAW = atan2(-fd.z, fd.x)
	var h: Dictionary = GEO.stop_point("pristoupim")
	var hd: Vector3 = h["dir"]
	HAMLET_PLACE.STOP_ORIGIN = h["p"]
	HAMLET_PLACE.STOP_YAW = atan2(-hd.z, hd.x)


## The game's own places in the real land (world xz): Liblice's centre and its stop,
## Vondra's farm with its track and the ruin by the road, the poles at Pristoupim.
func _clearings() -> Array:
	var out: Array = []
	var tb := Basis(Vector3.UP, TOWN.YAW)
	var stop_p: Vector3 = GEO.stop_point("liblice")["p"]
	var stop_local := tb.inverse() * (stop_p - TOWN.ORIGIN)
	out.append(_rect_poly(Rect2(-82.0, -72.0, 166.0, 122.0), TOWN.ORIGIN, tb))
	out.append(_rect_poly(Rect2(stop_local.x - 14.0, -10.0, 28.0, 20.0), TOWN.ORIGIN, tb))
	# Down from the sign past the stop to the street, both sides (town_lesna._south_end).
	out.append(_rect_poly(Rect2(stop_local.x - 62.0, -34.0, 92.0, 68.0), TOWN.ORIGIN, tb))
	var hb := Basis(Vector3.UP, HAMLET_PLACE.HAMLET_YAW)
	for r in [Rect2(-46.0, 5.0, 92.0, 152.0), Rect2(-84.0, -18.0, 28.0, 16.0)]:
		out.append(_rect_poly(r, HAMLET_PLACE.HAMLET_ORIGIN, hb))
	out.append(_rect_poly(Rect2(-12.0, -9.0, 24.0, 18.0), HAMLET_PLACE.STOP_ORIGIN, Basis(Vector3.UP, HAMLET_PLACE.STOP_YAW)))
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
