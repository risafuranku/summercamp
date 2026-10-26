extends SceneTree

## Headless check of the night director (scripts/night/night_director.gd): it keeps
## quiet by day and on the quiet night, never acts where it must not (close-ups, jobs,
## the lake) or while a hunter is close, spends its budget (no event twice in a row, the
## big ones followed by a breather), fits the events to where you are, leans to the
## archetypes in the camp, and minds how you play.
##
##   godot --headless --path godot --script res://tools/director_check.gd

const DIRECTOR := preload("res://scripts/night/night_director.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	print("")
	if _failures.is_empty():
		print("DIRECTOR CHECK: PASS")
		quit(0)
	else:
		print("DIRECTOR CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_failures.append(msg)


func _ctx(hour: float, place: String, extra := {}) -> Dictionary:
	var c := {"night": hour >= 21.0 or hour < 5.5, "quiet": false, "hour": hour, "place": place, "pos": Vector3.ZERO,
		"pressure": 3.0, "guests_by_arch": {"drunk": 2, "quiet_guy": 1, "family": 1}, "admitted": 0, "hunting": 1,
		"hunter_near_m": INF, "dark": false, "lamp_near": true, "walking": true, "window_open": true,
		"looking_at_window": false, "entering": false, "can_trip": true}
	c.merge(extra, true)
	return c


## Runs `seconds` of night (hour from 22 to 4 over the span), place by `place_of(t)`.
func _night(d, seconds: float, place_of: Callable, extra := {}) -> Array:
	var fired: Array = []
	var t := 0.0
	var dt := 0.25
	while t < seconds:
		var hour := fmod(22.0 + t / seconds * 6.0, 24.0)
		var id: String = d.tick(dt, _ctx(hour, str(place_of.call(t)), extra))
		if id != "":
			fired.append({"id": id, "t": t, "cost": float(DIRECTOR.EVENTS[id]["cost"]), "place": str(place_of.call(t)), "run": str(d.last_reason).ends_with("in a run")})
		t += dt
	return fired


func _run() -> void:
	# By day: nothing.
	var d = DIRECTOR.new(11)
	d.begin_night(3)
	var day := 0
	for i in 400:
		if d.tick(0.25, _ctx(14.0, "out_dark")) != "":
			day += 1
	_expect(day == 0 and d.state == DIRECTOR.State.DORMANT, "the director acted by day")

	# The quiet first night: nothing.
	d = DIRECTOR.new(12)
	d.begin_night(1)
	var q := _night(d, 420.0, func(_t): return "out_dark", {"quiet": true})
	_expect(q.is_empty(), "something happened on the quiet night (%d)" % q.size())

	# A busy night, in and out of the office: some things, never too much, spent right.
	var counts := []
	var runs := 0
	for seed in [21, 22, 23, 24, 25]:
		d = DIRECTOR.new(seed)
		d.begin_night(5)
		var f := _night(d, 420.0, func(t): return "office" if int(t / 60.0) % 2 == 0 else "out_dark")
		counts.append(f.size())
		print("  seed %d: %s" % [seed, ", ".join(f.map(func(e): return "%s@%d" % [e["id"], int(e["t"])]))])
		for i in range(1, f.size()):
			_expect(f[i]["id"] != f[i - 1]["id"], "the same event twice in a row (%s, seed %d)" % [f[i]["id"], seed])
			if bool(f[i]["run"]):
				# A run's beat: close behind the one before it, within the run's gap.
				runs += 1
				var gap := float(f[i]["t"]) - float(f[i - 1]["t"])
				_expect(gap >= DIRECTOR.RUN_GAP.x - 0.3 and gap <= DIRECTOR.RUN_GAP.y + 0.3, "a run's beat %.1f s after the one before (seed %d)" % [gap, seed])
			elif f[i]["id"] != "room_changed":
				_expect(float(f[i]["t"]) - float(f[i - 1]["t"]) >= 14.0, "two things within %.0f s (seed %d)" % [float(f[i]["t"]) - float(f[i - 1]["t"]), seed])
			if float(f[i - 1]["cost"]) >= DIRECTOR.BIG_COST:
				_expect(float(f[i]["t"]) - float(f[i - 1]["t"]) >= DIRECTOR.RECOVERY_SECONDS.x - 0.5, "no breather after %s (seed %d)" % [f[i - 1]["id"], seed])
		var trips := 0
		for e in f:
			var places: Array = DIRECTOR.EVENTS[e["id"]]["places"]
			if bool(e["run"]):
				_expect((DIRECTOR.RUNS.get(e["place"], []) as Array).has(e["id"]), "%s in a run in the %s" % [e["id"], e["place"]])
			else:
				_expect(places.has(e["place"]) or places.has("entering"), "%s happened in the %s" % [e["id"], e["place"]])
			if e["id"] == "breaker_trip":
				trips += 1
		_expect(trips <= 1, "the breaker went %d times in a night (seed %d)" % [trips, seed])
		_expect(d.budget >= -0.001, "the budget went below zero (seed %d)" % seed)
	print("DIRECTOR CHECK: busy nights fired %s, %d of it in runs" % [str(counts), runs])
	_expect(runs > 0, "no run of things close together in five busy nights")
	for c in counts:
		_expect(c >= 3 and c <= 16, "a busy night fired %d things (want 3-16)" % c)

	# A near-empty camp, you in the office all night: a few small things, nothing big.
	var small := []
	for seed in [91, 92, 93, 94]:
		d = DIRECTOR.new(seed)
		d.begin_night(5)
		var fq := _night(d, 420.0, func(_t): return "office", {"pressure": 0.4, "guests_by_arch": {"quiet_guy": 1}, "hunting": 0, "lamp_near": false, "walking": false})
		small.append(fq.size())
		for e in fq:
			_expect(float(e["cost"]) < DIRECTOR.BIG_COST, "an empty camp got a big event (%s)" % e["id"])
	print("DIRECTOR CHECK: empty camp, office all night: %s" % str(small))
	for c in small:
		_expect(c >= 1 and c <= 7, "an empty camp hiding in the office got %d things (want 1-7)" % c)

	# A sleeping guest standing outside: rare (a night in three or so over a week), once a
	# night at most, after midnight, never without someone asleep in the camp.
	var outs := 0
	for seed in [101, 102, 103, 104]:
		for sleeping in [true, false]:
			d = DIRECTOR.new(seed)
			for night in range(2, 9):
				d.begin_night(night)
				var fg := _night(d, 420.0, func(_t): return "out_dark", {"pressure": 1.6, "guests_by_arch": {"drunk": 2, "quiet_guy": 1}, "walking": true, "guest_sleeping": sleeping})
				var n := 0
				for e in fg:
					if str(e["id"]) == "guest_out":
						n += 1
						var hr := fmod(22.0 + float(e["t"]) / 420.0 * 6.0, 24.0)
						_expect(hr < 4.5, "a guest stood outside at %.1f h (want 0-4:30)" % hr)
				_expect(n <= 1, "a guest stood outside %d times in one night" % n)
				_expect(sleeping or n == 0, "a guest stood outside with nobody asleep")
				outs += n
	print("DIRECTOR CHECK: a guest outside on %d of 28 mimic nights" % outs)
	_expect(outs >= 3 and outs <= 14, "a guest stood outside on %d of 28 nights (want 3-14)" % outs)

	# Where it must not: close-ups, jobs, the lake, a guest's room.
	for place in ["modal", "job", "lake", "room"]:
		d = DIRECTOR.new(31)
		d.begin_night(5)
		var f2 := _night(d, 300.0, func(_t): return place)
		_expect(f2.is_empty(), "the director acted in the %s (%d)" % [place, f2.size()])

	# A hunter close by: it backs off.
	d = DIRECTOR.new(41)
	d.begin_night(5)
	var f3 := _night(d, 300.0, func(_t): return "out_dark", {"hunter_near_m": 6.0})
	_expect(f3.is_empty() and d.state == DIRECTOR.State.CONFRONTATION, "the director acted during a confrontation")

	# Only drinkers and girls in the camp: mostly the mimic's work.
	var mimic := 0
	var all := 0
	for seed in [51, 52, 53, 54, 55, 56]:
		d = DIRECTOR.new(seed)
		d.begin_night(5)
		var f4 := _night(d, 420.0, func(t): return "office" if int(t / 45.0) % 2 == 0 else "out_lit", {"guests_by_arch": {"drunk": 3, "cheap_chick": 2}, "hunting": 0})
		for e in f4:
			all += 1
			if (DIRECTOR.EVENTS[e["id"]]["arch"] as Array).has(DIRECTOR.A.MIMIC):
				mimic += 1
	print("DIRECTOR CHECK: mimic camp %d of %d events were the mimic's" % [mimic, all])
	_expect(all > 0 and float(mimic) / float(all) >= 0.5, "a camp of drinkers did not lean to the mimic (%d of %d)" % [mimic, all])

	# You keep looking out of the window: the window events fade.
	d = DIRECTOR.new(61)
	d.begin_night(5)
	d.state = DIRECTOR.State.ESCALATION
	d.budget = 14.0
	d.arch_weights = [1.0, 0.5, 0.5, 0.5]
	var before: Dictionary = d.candidates(_ctx(1.0, "office"))
	d.window_looks = 60.0
	var after: Dictionary = d.candidates(_ctx(1.0, "office"))
	_expect(before.has("figure_window") and after.has("figure_window") and float(after["figure_window"]) < float(before["figure_window"]) * 0.5, "watching the window did not move things elsewhere")

	# Ignored cues raise the tension.
	var a = DIRECTOR.new(71)
	var b = DIRECTOR.new(71)
	a.begin_night(5)
	b.begin_night(5)
	b.ignored = 4
	for i in 1400:
		a.tick(0.25, _ctx(23.5, "out_dark"))
		b.tick(0.25, _ctx(23.5, "out_dark"))
	_expect(b.tension > a.tension + 0.05, "ignoring things did not raise the tension (%.2f vs %.2f)" % [b.tension, a.tension])

	# Remembered across nights.
	d = DIRECTOR.new(81)
	d.ever = {"knock": 3}
	var d2 = DIRECTOR.new(82)
	d2.import_state(JSON.parse_string(JSON.stringify(d.export_state())))
	_expect(int(d2.ever.get("knock", 0)) == 3, "the director forgot across a save")
