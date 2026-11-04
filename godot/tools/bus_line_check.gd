extends "res://tools/shot_driver.gd"

## Line 380 as one bus a round on the clock (V14, scripts/town/bus_line.gd): how long
## each stretch of its way takes (the numbers bus_timetable.gd prints), that no round
## ever jumps through a day, then a ride: on at the camp, it goes at its time, Liblice is
## built before it gets there, off at the door of the very bus, which stands there and
## goes on. Lines "BUSLINE ...", "BUSLINE FAIL ...", "BUSLINE: PASS".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/bus_line_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('BusLineCheck')"
const TT := "_interior_manager._town_trip"
const LINE = preload("res://scripts/town/bus_line.gd")
const TIMES = preload("res://scripts/town/bus_timetable.gd")

var fails := 0
var _was_stand := {}
var _town_before := false
var _bus_key := ""
var _bus_at_off := Vector3.ZERO


func _fail(what: String) -> void:
	fails += 1
	print("BUSLINE FAIL " + what)


func pl() -> Node3D:
	return _main.get("_player")


func trip():
	return _main.get("_interior_manager").get("_town_trip")


func legs() -> void:
	var line = LINE.new()
	var ok: bool = line.build(trip()._road())
	print("BUSLINE built=%s length=%.0f stops=%s" % [str(ok), line.length(), str(line.stop_at)])
	for pair in [["start", "l_down"], ["l_down", "p_down"], ["p_down", "camp"], ["l_down", "camp"], ["camp", "p_up"], ["p_up", "l_up"], ["camp", "l_up"], ["l_up", "end"]]:
		var h: float = line.hours(pair[0], pair[1])
		print("BUSLINE leg %s>%s %.3f h = %d min (%.0f s)" % [pair[0], pair[1], h, roundi(h * 60.0), h * 48.0])
	var want := {"RIDE_HOURS": line.hours("camp", "l_up"), "RIDE_DOWN_HOURS": line.hours("l_down", "camp"),
		"TO_PRISTOUPIM": line.hours("camp", "p_up"), "FROM_LIBLICE_PRISTOUPIM": line.hours("l_down", "p_down")}
	var have := {"RIDE_HOURS": TIMES.RIDE_HOURS, "RIDE_DOWN_HOURS": TIMES.RIDE_DOWN_HOURS,
		"TO_PRISTOUPIM": TIMES.TO_PRISTOUPIM, "FROM_LIBLICE_PRISTOUPIM": TIMES.FROM_LIBLICE_PRISTOUPIM}
	for k in want:
		print("BUSLINE timetable %s printed %.3f driven %.3f" % [k, float(have[k]), float(want[k])])
		if absf(float(have[k]) - float(want[k])) > 3.0 / 60.0:
			_fail("%s: the timetable says %.3f h, the road takes %.3f h" % [k, float(have[k]), float(want[k])])
	# Through two days every round moves on smoothly: never further in a step than a bus
	# goes, never back, and it stands at the camp when the poles say.
	var last := {}
	var step := 1.0 / 60.0
	var at := 24.0
	while at < 72.0:
		for e in line.on_road(at):
			var st: Dictionary = e["st"]
			var key := str(st["key"])
			var p: Vector3 = line.pose_at(float(st["s"])).origin
			if last.has(key):
				var d: float = (last[key] as Vector3).distance_to(p)
				if d > LINE.CRUISE_MAX * step * LINE.SEC_PER_HOUR * 1.15 + 1.0:
					_fail("round %s jumped %.1f m at %.2f" % [key, d, at])
			last[key] = p
			var stand := str(st.get("stand", ""))
			if stand != str(_was_stand.get(key, "")):
				_was_stand[key] = stand
				if stand != "":
					print("BUSLINE round %s stands at %s at %s" % [key, stand, TIMES.hm(fposmod(at, 24.0))])
		at += step
	# The camp's poles: each line round stands at the camp when it says it leaves.
	for i in TIMES.CAMP_LEAVE.size():
		var r: Dictionary = LINE.rounds()[i]
		var st2: Dictionary = line.state(2, r, 48.0 + float(TIMES.CAMP_LEAVE[i]) - 1.0 / 60.0)
		if str(st2.get("stand", "")) != "camp":
			_fail("round %d is not at the camp a minute before %s: %s" % [i, TIMES.hm(TIMES.CAMP_LEAVE[i]), str(st2)])


func give_ticket() -> void:
	var ride = trip().get("_ride")
	ride.set("_ticket", {"punched": true, "to": "LIBLICE", "kind": "adult", "price": 2, "at": "6:00"})


func probe(tag: String) -> void:
	var t = trip()
	var ride = t.get("_ride")
	var bus = t.get("_ride_bus")
	var town = t.get("_town")
	var p: Vector3 = pl().global_position
	print("BUSLINE %s hour=%.2f ride_open=%s state=%s key=%s s=%.0f v=%.1f stand=%s bus=%s town=%s player=%s" % [tag, float(_main.get("_time_of_day_hours")),
		str(ride != null and ride.is_open()), str(ride.get("_state") if ride != null else -1), str(t.get("_ride_key")),
		float(ride.get("_travelled")) if ride != null else -1.0, float(ride.get("_speed")) if ride != null else -1.0,
		str(ride.get("_line_stand")) if ride != null else "-", str(bus.global_position if bus != null else Vector3.INF), str(town != null), str(p)])


func boarded() -> void:
	_bus_key = str(trip().get("_ride_key"))
	if _bus_key == "":
		_fail("did not get on the bus at the camp")


func near_town() -> void:
	_town_before = trip().get("_town") != null


func arrived() -> void:
	var t = trip()
	if not _town_before:
		_fail("Liblice was not built before the bus got there")
	var bus = t.get("_line_buses").get(_bus_key)
	if bus == null or not bus.visible:
		_fail("the bus you came on is not there after you got off")
		return
	var d: float = (bus as Node3D).global_position.distance_to(pl().global_position)
	_bus_at_off = (bus as Node3D).global_position
	print("BUSLINE off: %.1f m from the bus you came on (door side), clock %.2f" % [d, float(_main.get("_time_of_day_hours"))])
	if d > 7.5:
		_fail("got off %.1f m from the bus" % d)
	if not bool(t.call("_riding_now")) == false:
		_fail("still riding after getting off")


func look_at_bus() -> void:
	var bus = trip().get("_line_buses").get(_bus_key)
	if bus != null:
		pl().look_at(Vector3((bus as Node3D).global_position.x, pl().global_position.y, (bus as Node3D).global_position.z), Vector3.UP)


func bus_gone() -> void:
	var bus = trip().get("_line_buses").get(_bus_key)
	var there: bool = bus != null and (bus as Node3D).visible and (bus as Node3D).global_position.distance_to(_bus_at_off) < 3.0
	print("BUSLINE after it stood: the bus %s (%.0f m on)" % ["still where it stood" if there else "gone on", (bus as Node3D).global_position.distance_to(_bus_at_off) if bus != null else -1.0])
	if there:
		_fail("the bus you came on still stands by you after its time")


func at_camp_stop() -> void:
	var road = trip()._road()
	pl().global_position = road.wait_spot().origin
	var bus = trip().bus_at("camp")
	if bus != null:
		pl().look_at(Vector3((bus as Node3D).global_position.x, pl().global_position.y, (bus as Node3D).global_position.z), Vector3.UP)


## The STOP button once on the way: the round pulls in at Pristoupim and you are off there.
func press_stop() -> void:
	var ride = trip().get("_ride")
	ride.call("_press_stop")
	print("BUSLINE STOP pressed: who=%s live=%s" % [str(ride.get("_stop_who")), str(trip().get("line").get("live"))])


func off_at_pole() -> void:
	var t = trip()
	var ride = t.get("_ride")
	print("BUSLINE off at the pole? where=%s hamlet built=%s" % [str(ride.get("arrived_where")), str(t.get("_hamlet").is_built())])
	if str(ride.get("arrived_where")) != "hamlet":
		_fail("STOP pressed but not let off at Pristoupim (%s)" % str(ride.get("arrived_where")))
	var line = t.get("line")
	var pole: Vector3 = line.point_at(float(line.stop_at["p_up"]))
	var d := pole.distance_to(pl().global_position)
	print("BUSLINE off %.1f m from Pristoupim's stand" % d)
	if d > 14.0:
		_fail("off %.1f m from Pristoupim" % d)


## In Liblice at the stop for the camp, looking at the bus there.
func at_town_stop() -> void:
	var t = trip()
	t.call("_ensure_town")
	pl().global_position = t.get("_town").wait_spot().origin
	var bus = t.bus_at("town")
	if bus != null:
		pl().look_at(Vector3((bus as Node3D).global_position.x, pl().global_position.y, (bus as Node3D).global_position.z), Vector3.UP)


func off_at_camp() -> void:
	var t = trip()
	var line = t.get("line")
	var stand: Vector3 = line.point_at(float(line.stop_at["camp"]))
	var d := stand.distance_to(pl().global_position)
	print("BUSLINE off at the camp %.1f m from where the bus stands, clock %.2f" % [d, float(_main.get("_time_of_day_hours"))])
	if d > 9.0:
		_fail("off %.1f m from the camp's stand" % d)


var _walk_at := 0.0


## A warden by road 12 as a round goes by: when it passes the spot, and you there.
func walker() -> void:
	var t = trip()
	var line = t.get("line")
	var r: Dictionary = LINE.rounds()[1]
	var spot_s := float(line.stop_at["camp"]) + 900.0
	var day := 3
	var at := float(day) * 24.0 + float(TIMES.CAMP_LEAVE[1])
	while at < float(day) * 24.0 + float(TIMES.CAMP_LEAVE[1]) + 2.0:
		var st: Dictionary = line.state(day, r, at)
		if not st.is_empty() and float(st.get("s", 0.0)) >= spot_s:
			break
		at += 0.5 / 60.0
	_walk_at = at
	var p: Vector3 = line.point_at(spot_s)
	var ahead: Vector3 = line.point_at(spot_s - 60.0)
	var side := (ahead - p).cross(Vector3.UP).normalized()
	pl().global_position = p + side * 9.0 + Vector3(0, 0.3, 0)
	pl().look_at(Vector3(ahead.x, pl().global_position.y, ahead.z), Vector3.UP)
	print("BUSLINE walker by road 12 at %s, round 1 due there at %s" % [str(pl().global_position), TIMES.hm(fposmod(at, 24.0))])


func walker_jump() -> void:
	_main.call("debug_jump_to", 3, fposmod(_walk_at, 24.0) - 0.35)


func walker_sees(tag: String) -> void:
	var t = trip()
	var nearest := 1e9
	for k in t.get("_line_buses").keys():
		var b = t.get("_line_buses")[k]
		if b != null and (b as Node3D).visible:
			nearest = minf(nearest, (b as Node3D).global_position.distance_to(pl().global_position))
	print("BUSLINE walker %s: nearest bus %.0f m" % [tag, nearest])


var _worst := 0.0
var _last_us := 0
var _watch := false


## The worst frame while the bus goes (no jolt as the land and the village come).
func watch(on: bool, tag := "") -> void:
	_watch = on
	_last_us = Time.get_ticks_usec()
	if on:
		_worst = 0.0
	else:
		print("BUSLINE worst frame %s %.0f ms" % [tag, _worst / 1000.0])
		if _worst > 120000.0:
			_fail("a %.0f ms frame on the way (%s)" % [_worst / 1000.0, tag])


func _frame() -> void:
	var now := Time.get_ticks_usec()
	if _watch and _last_us > 0:
		_worst = maxf(_worst, float(now - _last_us))
	_last_us = now


func verdict() -> void:
	print("BUSLINE: %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))


func _ready() -> void:
	super._ready()
	get_tree().process_frame.connect(_frame)
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", C + ".legs()"],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		# The first round stands at the camp from 5:3x; on it at 6:02, it goes at 6:10.
		["eval", "debug_jump_to(2, 6.03)"], ["wait", 1.5],
		["eval", C + ".at_camp_stop()"], ["wait", 1.0],
		["until", TT + ".bus_at('camp') != null and " + TT + ".bus_at('camp').is_door_open()", 20.0],
		["eval", C + ".at_camp_stop()"], ["wait", 0.4], ["eval", C + ".probe('at the stop')"], ["shot", "a0_bus_at_stop"],
		["eval", TT + "._board('camp')"], ["wait", 1.5], ["eval", C + ".boarded()"],
		["eval", C + ".give_ticket()"], ["eval", TT + "._ride._try_sit(" + TT + "._ride.first_free_seat(0))"], ["wait", 3.0],
		["eval", C + ".probe('sat')"], ["shot", "a1_sat"],
		["until", TT + "._ride._state == 3", 30.0], ["eval", C + ".probe('going')"], ["eval", C + ".watch(true)"],
		["wait", 30.0], ["eval", C + ".watch(false, 'up to road 12')"], ["eval", C + ".probe('on road 12')"], ["shot", "a2_ride"],
		["wait", 40.0], ["eval", C + ".probe('past Pristoupim')"], ["shot", "a3_ride"], ["eval", C + ".watch(true)"],
		["until", TT + "._ride._travelled > " + TT + ".line.stop_at['l_up'] - 200.0", 120.0], ["eval", C + ".near_town()"], ["eval", C + ".probe('near Liblice')"],
		["until", TT + "._ride._line_stand != ''", 90.0], ["eval", C + ".watch(false, 'into Liblice')"],
		["until", TT + "._ride.is_open() == false", 90.0], ["wait", 1.0],
		["eval", C + ".probe('off')"], ["eval", C + ".arrived()"], ["eval", C + ".look_at_bus()"], ["wait", 0.5], ["shot", "a4_off_by_the_bus"],
		["wait", 6.0], ["eval", C + ".probe('it goes on')"], ["eval", C + ".bus_gone()"], ["shot", "a5_it_goes_on"],
		# B: on at the camp, STOP on the way, off at Pristoupim.
		["eval", "debug_jump_to(3, 10.1)"], ["wait", 1.5], ["eval", C + ".at_camp_stop()"], ["wait", 1.0],
		["until", TT + ".bus_at('camp') != null and " + TT + ".bus_at('camp').is_door_open()", 20.0], ["shot", "b0_bus_at_camp"],
		["eval", TT + "._board('camp')"], ["wait", 1.5], ["eval", C + ".boarded()"],
		["eval", C + ".give_ticket()"], ["eval", TT + "._ride._try_sit(" + TT + "._ride.first_free_seat(0))"], ["wait", 3.0],
		["until", TT + "._ride._state == 3", 30.0], ["wait", 8.0], ["eval", C + ".press_stop()"],
		["until", TT + "._ride.is_open() == false", 150.0], ["wait", 1.0], ["eval", C + ".probe('off at the pole')"], ["eval", C + ".off_at_pole()"],
		["eval", C + ".look_at_bus()"], ["wait", 0.4], ["shot", "b1_off_at_pristoupim"],
		# C: Liblice to the camp.
		["eval", "debug_jump_to(3, 15.62)"], ["wait", 1.5], ["eval", C + ".at_town_stop()"], ["wait", 1.0],
		["until", TT + ".bus_at('town') != null and " + TT + ".bus_at('town').is_door_open()", 20.0], ["shot", "c0_bus_in_liblice"],
		["eval", TT + "._board('town')"], ["wait", 1.5], ["eval", C + ".boarded()"],
		["eval", C + ".give_ticket()"], ["eval", TT + "._ride._try_sit(" + TT + "._ride.first_free_seat(0))"], ["wait", 3.0],
		["until", TT + "._ride._state == 3", 30.0], ["eval", C + ".probe('down')"],
		["until", TT + "._ride.is_open() == false", 200.0], ["wait", 1.0], ["eval", C + ".probe('off at the camp')"], ["eval", C + ".off_at_camp()"],
		["eval", C + ".look_at_bus()"], ["wait", 0.4], ["shot", "c1_off_at_camp"],
		# D: by road 12 as a round goes by.
		["eval", C + ".walker()"], ["eval", C + ".walker_jump()"], ["wait", 1.0], ["eval", C + ".walker()"],
		["wait", 9.0], ["eval", C + ".walker_sees('before')"], ["shot", "d0_coming"],
		["wait", 5.0], ["eval", C + ".walker_sees('passing')"], ["shot", "d1_passing"],
		["eval", C + ".verdict()"],
		["eval", "get_tree().quit()"],
	]
