extends RefCounted

## Line 380 as it runs (the user 4. 11., V14: "everything has to be real: no porting the
## warden off the map into an imaginary bus for the ride; you can walk to town, and
## walking along the bus's way you see it go by with whoever rides it sat inside; you see
## them get on and get off"). One bus a round, the whole of its way, put where it is by
## the game's clock alone, so every machine has it in the same place:
##   in from Lstibor at the land's end, Liblice's stop on the far side (for the camp),
##   Pristoupim's request stop, down to the camp, round the loop to the shelter, where it
##   stands (the end of the line); then back up: Pristoupim, Liblice by the green, and on
##   east out of the land.
## The clock runs as ever while it goes (the user's call, 4. 11.): the road takes what it
## takes at a Karosa's pace; where it stands and till when is the timetable's
## (bus_timetable.gd: the camp's times are the anchors, the rest is how long the road
## takes). It waits longer for somebody getting on or hurrying to it (`hold`), and pulls
## in at Pristoupim only for somebody: waiting by the pole, ringing for it, a ticket
## there, a villager getting off (`request`, the round's own dice).
## How it drives (the bends, the villages, pulling in and away) is worked out once per
## stretch (`_simulate`) with the kinematics bus_ride.gd drove with.
## town_trip.gd owns it: builds it with the camp's road, asks where each round is, puts
## the buses there.

const TIMES = preload("res://scripts/town/bus_timetable.gd")
const GEO = preload("res://scripts/geo/geo_data.gd")

## m/s the road allows: road 12, the villages, the open road between, the camp's own.
const SPEED := {"road12": 24.0, "village": 13.5, "open": 19.0, "camp": 10.0}
const CRUISE_MAX := 22.0
const ACCEL := 2.4
const BRAKE := 2.2
## Real seconds in a game hour (balance_config: 1.25 game minutes a second).
const SEC_PER_HOUR := 48.0
## The least it stands wherever it stops (game hours): the door, a step in or out.
const MIN_STAND := 2.0 / 60.0
## How far before a stop it must know it is to stop there (the braking and a margin).
const DECIDE_M := 160.0

## Its way, end to end: the points, the speed the road allows at each, the distance to each.
var pts := PackedVector3Array()
var lim := PackedFloat32Array()
var along := PackedFloat32Array()
## Where on its way each place is: "start" (the land's end east of Liblice, coming in),
## "l_down" (Liblice, the stop for the camp), "p_down", "camp", "p_up", "l_up" (Liblice by
## the green, going on), "end" (out of the land).
var stop_at := {}
## What happens to the rounds under way, by round key ("day:i"): {"h": {stop: extra game
## hours it waits there}, "p_up" / "p_down": why it pulls in at Pristoupim}. The host's in
## co-op (town_trip.gd syncs it).
var live := {}

var _built_for := 0
var _legs := {}
var _env := PackedFloat32Array()
var _plans := {}
var _plans_ver := -1
var _ver := 0


## The way round for the camp's road (`road`: road_south.gd). False when the land's data
## is not there.
func build(road) -> bool:
	if road == null or not is_instance_valid(road):
		return false
	if _built_for == road.get_instance_id() and pts.size() > 1:
		return true
	var s_end := GEO.route_length()
	var s_l := GEO.stop_s("liblice")
	var s_p := GEO.stop_s("pristoupim")
	if s_end <= 60.0 or s_l <= 0.0 or s_p <= 0.0:
		return false
	pts = PackedVector3Array()
	lim = PackedFloat32Array()
	_legs.clear()
	_plans.clear()
	# Down: in from the land's end past Liblice and Pristoupim to the camp's road, down it,
	# round the loop to the shelter.
	_line(s_end, 60.0)
	var down_to := pts.size()
	_add(road.bus_arrive_path(), SPEED["camp"])
	var camp_i := pts.size() - 1
	# Up: out of the loop, up to road 12, on to Liblice and out of the land.
	_add(road.bus_leave_path(), SPEED["camp"])
	var up_from := pts.size()
	_line(60.0, s_end)
	along.resize(pts.size())
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		along[i] = acc
	# Slower in the bends: what a bus can take round a curve that tight.
	for i in range(1, pts.size() - 1):
		var a := pts[maxi(0, i - 3)]
		var b := pts[i]
		var c := pts[mini(pts.size() - 1, i + 3)]
		var ang := (b - a).normalized().angle_to((c - b).normalized())
		if ang > 0.02:
			var radius := (a.distance_to(b) + b.distance_to(c)) / ang
			lim[i] = minf(lim[i], maxf(4.0, sqrt(1.7 * radius)))
	stop_at = {
		"start": 0.0,
		"l_down": _nearest(GEO.at(s_l - 4.0, -1.6)["p"], 0, down_to),
		"p_down": _nearest(GEO.at(s_p - 5.0, -1.6)["p"], 0, down_to),
		"camp": along[camp_i],
		"p_up": _nearest(GEO.at(s_p + 5.0, 1.6)["p"], up_from, pts.size()),
		"l_up": _nearest(GEO.at(s_l + 4.0, 1.6)["p"], up_from, pts.size()),
		"end": along[along.size() - 1],
	}
	_build_envelope()
	_built_for = road.get_instance_id()
	return true


func is_built() -> bool:
	return pts.size() > 1


func _line(s0: float, s1: float) -> void:
	var r12a := GEO.mark_s("main_from")
	var r12b := GEO.mark_s("main_to")
	var s_p := GEO.stop_s("pristoupim")
	var s_l := GEO.stop_s("liblice")
	var line := GEO.line_path(s0, s1, 1.6)
	for k in line.size():
		var s := lerpf(s0, s1, float(k) / float(maxi(1, line.size() - 1)))
		var v: float = SPEED["open"]
		if s > r12a + 15.0 and s < r12b - 25.0:
			v = SPEED["road12"]
		elif absf(s - s_p) < 140.0 or s > s_l - 120.0:
			v = SPEED["village"]
		_push(line[k], v)


func _add(more: PackedVector3Array, v: float) -> void:
	for p in more:
		_push(p, v)


func _push(p: Vector3, v: float) -> void:
	if pts.size() > 0 and pts[pts.size() - 1].distance_to(p) < 0.5:
		return
	pts.append(p)
	lim.append(v)


func _nearest(p: Vector3, from: int, to: int) -> float:
	var best := 1e12
	var at := 0.0
	for i in range(from, mini(to, pts.size())):
		var d := pts[i].distance_squared_to(p)
		if d < best:
			best = d
			at = along[i]
	return at


# ── where it is on its way ───────────────────────────────────────────────────

func length() -> float:
	return along[along.size() - 1] if along.size() > 0 else 0.0


func point_at(s: float) -> Vector3:
	if pts.size() < 2:
		return Vector3.ZERO
	s = clampf(s, 0.0, length())
	var i := clampi(along.bsearch(s) - 1, 0, pts.size() - 2)
	var seg := maxf(0.001, along[i + 1] - along[i])
	return pts[i].lerp(pts[i + 1], (s - along[i]) / seg)


## The bus `s` metres along: where, and facing the way it goes (eased over a few metres
## either side so it turns, not snaps).
func pose_at(s: float) -> Transform3D:
	var p := point_at(s)
	var dir := point_at(s + 3.0) - point_at(s - 3.0)
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	return Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), p)


func limit_at(s: float) -> float:
	if lim.is_empty():
		return 14.0
	var i := clampi(along.bsearch(s) - 1, 0, lim.size() - 1)
	return lim[i]


# ── how it drives a stretch ──────────────────────────────────────────────────

## The fastest it may go at each metre so it can still brake for every slower bit ahead.
func _build_envelope() -> void:
	var n := int(ceil(length())) + 2
	_env.resize(n)
	_env[n - 1] = limit_at(length())
	for k in range(n - 2, -1, -1):
		_env[k] = minf(limit_at(float(k)), sqrt(_env[k + 1] * _env[k + 1] + 2.0 * BRAKE))


func _cruise(s: float, end_s: float, stops: bool) -> float:
	var k := clampi(int(s), 0, _env.size() - 1)
	var v := minf(CRUISE_MAX, _env[k])
	if stops:
		v = minf(v, sqrt(2.0 * BRAKE * maxf(0.0, end_s - s - 0.2)) + 0.5)
	return v


## From `a` to `b` (stops ids): time, distance and speed every tenth of a second; standing
## at `a`, standing at `b` (or still going at the land's end).
func _leg(a: String, b: String) -> Dictionary:
	var key := a + ">" + b
	if _legs.has(key):
		return _legs[key]
	var s_a: float = stop_at.get(a, 0.0)
	var s_b: float = stop_at.get(b, length())
	var stops := b != "end"
	var dt := 0.1
	var s := s_a
	var v := 0.0
	var t := 0.0
	var ts := PackedFloat32Array([0.0])
	var ss := PackedFloat32Array([s_a])
	var vs := PackedFloat32Array([0.0])
	var guard := 0
	while s < s_b - 0.02 and guard < 60000:
		guard += 1
		var want := _cruise(s, s_b, stops)
		v = move_toward(v, want, (ACCEL if want > v else BRAKE) * dt)
		s += v * dt
		t += dt
		if stops and s_b - s < 0.35 and v < 1.0:
			s = s_b
			v = 0.0
		ts.append(t)
		ss.append(minf(s, s_b))
		vs.append(v)
	var leg := {"t": ts, "s": ss, "v": vs, "dur": t}
	_legs[key] = leg
	return leg


## A stretch's length in game hours.
func hours(a: String, b: String) -> float:
	return float(_leg(a, b)["dur"]) / SEC_PER_HOUR


## Distance and speed `secs` into a stretch.
func _leg_at(leg: Dictionary, secs: float) -> Vector2:
	var ts: PackedFloat32Array = leg["t"]
	var ss: PackedFloat32Array = leg["s"]
	var vs: PackedFloat32Array = leg["v"]
	if secs <= 0.0:
		return Vector2(ss[0], vs[0])
	if secs >= ts[ts.size() - 1]:
		return Vector2(ss[ss.size() - 1], vs[vs.size() - 1])
	var i := clampi(ts.bsearch(secs) - 1, 0, ts.size() - 2)
	var f := (secs - ts[i]) / maxf(0.0001, ts[i + 1] - ts[i])
	return Vector2(lerpf(ss[i], ss[i + 1], f), lerpf(vs[i], vs[i + 1], f))


# ── the rounds of a day ──────────────────────────────────────────────────────

## Each bus's round, by the timetable: the line's (down from Liblice at `l_out`, at the
## camp from `camp_in` to `camp_out`, on from Liblice at `l_on`) and the hands' works
## runs (SLUZEBNI: no Pristoupim, nobody else on).
static func rounds() -> Array:
	var out: Array = []
	for i in TIMES.CAMP_LEAVE.size():
		out.append({"i": i, "l_out": float(TIMES.TOWN_LEAVE[i]), "camp_out": float(TIMES.CAMP_LEAVE[i]),
			"l_on": float(TIMES.TOWN_THROUGH[i]) + TIMES.THROUGH_STAND, "staff": false})
	for j in TIMES.STAFF_LEAVE.size():
		out.append({"i": 10 + j, "l_out": float(TIMES.STAFF_ARRIVE[j]) - TIMES.RIDE_DOWN_HOURS, "camp_out": float(TIMES.STAFF_LEAVE[j]),
			"l_on": float(TIMES.STAFF_LEAVE[j]) + TIMES.RIDE_HOURS + TIMES.THROUGH_STAND, "staff": true})
	return out


static func key_of(day: int, r: Dictionary) -> String:
	return "%d:%d" % [day, int(r["i"])]


## The round's way through the day, in absolute game hours (day * 24 + hour): stretches
## driven ({"k": "drive", "a", "b", "t0", "t1"}) and stops stood at ({"k": "stand",
## "stop", "t0", "t1"}), in order.
func plan(day: int, r: Dictionary) -> Array:
	var key := key_of(day, r)
	if _plans_ver != _ver:
		_plans.clear()
		_plans_ver = _ver
	if _plans.has(key):
		return _plans[key]
	var lv: Dictionary = live.get(key, {})
	var holds: Dictionary = lv.get("h", {})
	var base := float(day) * 24.0
	var segs: Array = []
	var p_down := serves(day, r, "p_down")
	var p_up := serves(day, r, "p_up")
	var t := base + float(r["l_out"]) - TIMES.TOWN_STAND - hours("start", "l_down")
	t = _drive(segs, "start", "l_down", t)
	t = _stand(segs, "l_down", t, base + float(r["l_out"]), holds)
	if p_down:
		t = _drive(segs, "l_down", "p_down", t)
		t = _stand(segs, "p_down", t, t + TIMES.HAMLET_STAND, holds)
		t = _drive(segs, "p_down", "camp", t)
	else:
		t = _drive(segs, "l_down", "camp", t)
	t = _stand(segs, "camp", t, base + float(r["camp_out"]), holds)
	if p_up:
		t = _drive(segs, "camp", "p_up", t)
		t = _stand(segs, "p_up", t, t + TIMES.HAMLET_STAND, holds)
		t = _drive(segs, "p_up", "l_up", t)
	else:
		t = _drive(segs, "camp", "l_up", t)
	t = _stand(segs, "l_up", t, base + float(r["l_on"]), holds)
	_drive(segs, "l_up", "end", t)
	_plans[key] = segs
	return segs


func _drive(segs: Array, a: String, b: String, t: float) -> float:
	var d := hours(a, b)
	segs.append({"k": "drive", "a": a, "b": b, "t0": t, "t1": t + d})
	return t + d


func _stand(segs: Array, stop: String, arrive: float, leave: float, holds: Dictionary) -> float:
	var go := maxf(leave, arrive + MIN_STAND) + float(holds.get(stop, 0.0))
	segs.append({"k": "stand", "stop": stop, "t0": arrive, "t1": go})
	return go


## Where the round is at absolute hour `at`: {} when it is not on the road; else
## {"s", "v", "stand" (the stop it stands at, or ""), "to" (where it is going next),
## "left" (game hours till it goes, standing), "key"}.
func state(day: int, r: Dictionary, at: float) -> Dictionary:
	var segs := plan(day, r)
	if segs.is_empty() or at < float(segs[0]["t0"]) or at >= float(segs[segs.size() - 1]["t1"]):
		return {}
	for sg in segs:
		if at >= float(sg["t1"]):
			continue
		if str(sg["k"]) == "stand":
			return {"s": float(stop_at[str(sg["stop"])]), "v": 0.0, "stand": str(sg["stop"]), "to": str(sg["stop"]),
				"left": float(sg["t1"]) - at, "since": at - float(sg["t0"]), "key": key_of(day, r)}
		var sv := _leg_at(_leg(str(sg["a"]), str(sg["b"])), (at - float(sg["t0"])) * SEC_PER_HOUR)
		return {"s": sv.x, "v": sv.y, "stand": "", "to": str(sg["b"]), "from": str(sg["a"]), "key": key_of(day, r)}
	return {}


## The rounds on the road at absolute hour `at` (today's and the ones from yesterday
## still out): [{"day", "r", "st"}].
func on_road(at: float) -> Array:
	var out: Array = []
	if not is_built():
		return out
	var today := int(floor(at / 24.0))
	for day in [today - 1, today]:
		for r in rounds():
			var st := state(day, r, at)
			if not st.is_empty():
				out.append({"day": day, "r": r, "st": st})
	return out


# ── who it stops for ─────────────────────────────────────────────────────────

## Whether the round pulls in at Pristoupim (`stop` "p_up" / "p_down"): asked for, or the
## round's own dice (a villager off, by day). The works runs never.
func serves(day: int, r: Dictionary, stop: String) -> bool:
	if bool(r.get("staff", false)):
		return false
	var lv: Dictionary = live.get(key_of(day, r), {})
	if str(lv.get(stop, "")) != "":
		return true
	return why(day, r, stop) != ""


## Why it pulls in there by itself: "rider" (somebody on board gets off), or "".
func why(day: int, r: Dictionary, stop: String) -> String:
	var lv: Dictionary = live.get(key_of(day, r), {})
	if str(lv.get(stop, "")) != "":
		return str(lv[stop])
	var h := float(r["l_out"]) if stop == "p_down" else float(r["camp_out"])
	if h < 7.0 or h > 18.5:
		return ""
	return "rider" if _hash01(day * 31 + int(r["i"]) * 7 + (1 if stop == "p_up" else 2)) < 0.3 else ""


## Asks the round to pull in at Pristoupim (`why`: "you", "wait", "mate", "board"):
## "ok", "already", "late" (too near to stop now) or "past".
func request(day: int, r: Dictionary, stop: String, why_s: String, at: float) -> String:
	if bool(r.get("staff", false)):
		return "past"
	if serves(day, r, stop):
		var lv0: Dictionary = live.get(key_of(day, r), {})
		if str(lv0.get(stop, "")) == "":
			lv0[stop] = why_s
			live[key_of(day, r)] = lv0
		return "already"
	var st := state(day, r, at)
	var s_stop: float = stop_at.get(stop, -1.0)
	if st.is_empty() or s_stop < 0.0:
		return "past"
	# Each way passes its own pole once: before it on its way, or not at all.
	var going_up := stop == "p_up"
	var s_now: float = st["s"]
	var on_its_side := (s_now < float(stop_at["camp"])) != going_up
	if not on_its_side or s_now > s_stop:
		return "past"
	if s_stop - s_now < DECIDE_M:
		return "late"
	var lv: Dictionary = live.get(key_of(day, r), {})
	lv[stop] = why_s
	live[key_of(day, r)] = lv
	_ver += 1
	return "ok"


## Keeps the round standing at `stop` a little longer (somebody getting on, or hurrying
## for it): its going pushed on to just after `at`.
func hold(day: int, r: Dictionary, stop: String, at: float) -> void:
	var key := key_of(day, r)
	var lv: Dictionary = live.get(key, {})
	var holds: Dictionary = lv.get("h", {})
	var was := float(holds.get(stop, 0.0))
	holds.erase(stop)
	lv["h"] = holds
	live[key] = lv
	_ver += 1
	var segs := plan(day, r)
	var base_go := -1.0
	for sg in segs:
		if str(sg["k"]) == "stand" and str(sg["stop"]) == stop:
			base_go = float(sg["t1"])
			break
	if base_go < 0.0:
		holds[stop] = was
		_ver += 1
		return
	# (Two minutes on: its doors stay open while it waits, town_trip shuts them 1.5 before.)
	holds[stop] = maxf(was, at + 2.0 / 60.0 - base_go)
	lv["h"] = holds
	live[key] = lv
	_ver += 1


## The host's rounds in co-op (town_trip.gd): theirs is what happens.
func take_live(d: Dictionary) -> void:
	if d.hash() == live.hash():
		return
	live = d.duplicate(true)
	_ver += 1


## Drops the rounds long gone (a day's worth back).
func forget_before(day: int) -> void:
	var gone: Array = []
	for k in live.keys():
		if int(str(k).get_slice(":", 0)) < day - 1:
			gone.append(k)
	for k in gone:
		live.erase(k)
	if not gone.is_empty():
		_ver += 1


static func _hash01(n: int) -> float:
	var x := (n * 73856093) ^ 19349663
	x = (x ^ (x >> 13)) * 1274126177
	return float(posmod(x ^ (x >> 16), 10007)) / 10007.0
