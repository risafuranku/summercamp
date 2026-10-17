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
## A bus kept standing past its time (you are on it) or put on just for you (you got off
## it): stop -> {"mode": "hold"|"drop", "t": seconds, "pose", "leave"}.
var _special: Dictionary = {}
var _boarding_stop := ""
var _night := false
var _night_poll := 0.0
## Each stop's runs for the day (paths and poses), made once per road / town.
var _runs: Dictionary = {}


func setup(interior_manager: Node) -> void:
	_im = interior_manager


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
	return ""


func interact(structure: Node3D) -> void:
	match str(structure.get_meta("building_type", "")):
		"trip_barrier":
			var gate := _gate()
			if gate != null and not gate.is_raised():
				gate.open_for_player()
		"trip_timetable":
			_open_timetable(str(structure.get_meta("stop", "camp")))
		"trip_bus":
			_board(str(structure.get_meta("stop", "camp")))


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
	return (_timetable != null and _timetable.visible) or (_ride != null and _ride.is_open())


func close_interior() -> void:
	if _timetable != null and _timetable.visible:
		_timetable.close_view()
	if _ride != null and _ride.is_open():
		_ride.close_interior()


func set_time_state(_state: int) -> void:
	pass


# ── the buses ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
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
		_night = h >= 20.0 or h < 6.0
		_camp_bus.set_night(_night)
		if _town != null:
			_town.set_night(_night)
			if _town_bus != null:
				_town_bus.set_night(_night)
	_run_stop("camp", _camp_bus, delta, h)
	if _town != null:
		_run_stop("town", _town_bus, delta, h)


## What the bus at `stop` does at hour `h`: where it is, its door, its speed.
func _run_stop(stop: String, bus: Node3D, delta: float, h: float) -> void:
	var sp: Dictionary = _special.get(stop, {})
	if not sp.is_empty():
		_run_special(stop, bus, sp, delta)
		return
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
			bus.play("res://assets/sfx/bus/arrive.mp3", 0.0)
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
			bus.play("res://assets/sfx/bus/depart.mp3", 0.0)


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
					bus.play("res://assets/sfx/bus/depart.mp3", 0.0)
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
	if from == "camp":
		_ensure_town()
		_put_player(_town.arrive_spot())
		# The bus you came on stands a moment by the square and goes on to Hlubocany.
		_special["town"] = {"mode": "drop", "t": 0.0, "pose": _town.bus_pose("to_hlub"), "leave": _town.bus_leave_path("to_hlub"), "dest": "HLUBOCANY", "stop_id": "town_through"}
	else:
		var road := _road()
		_put_player(road.wait_spot())
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
	return {"in_town": away()}


func import_state(d: Dictionary) -> void:
	# Saved in Lesna: Lesna is there again (the player's position is the game's).
	if bool(d.get("in_town", false)):
		_ensure_town()
