extends Node

## Headless check of the mail cadence (scripts/email_manager.gd): camps of one tent to
## thirty beds through three days of hourly rolls, every booking answered at once and the
## party in its beds till it leaves, 200 times each (2. 11.: a big camp stayed empty);
## a half-empty camp's week of letters, the spam and the night's false alarms; and what
## Atlas's advertising adds (the camp's page as main has it, `_goggle` here).
##
##   godot --headless --path godot res://tools/mail_check.tscn

const RUNS := 200

var _failures: Array[String] = []
var _rng := RandomNumberGenerator.new()
## The camp on Atlas while the advertising is measured (EmailManager._atlas() reads the
## scene's `_goggle`, as main has it); null the rest of the time.
var _goggle = null


func _ready() -> void:
	var em = EmailManager
	_rng.seed = 1101
	var camps := {
		"one tent": _lodgings(1, 0),
		"four beds": _lodgings(2, 1),
		"ten beds": _lodgings(6, 2),
		"thirty beds": _lodgings(14, 8),
	}
	var letters_d1 := {}
	for camp_name in camps:
		var lodgings: Array = camps[camp_name]
		var beds := 0
		for b in lodgings:
			beds += int(b)
		var held := [0.0, 0.0, 0.0]
		var letters := [0.0, 0.0, 0.0]
		for run in RUNS:
			var days := _camp_days(em, lodgings, 3)
			for d in 3:
				letters[d] += float(days[d][0]) / RUNS
				held[d] += float(days[d][1]) / RUNS
		letters_d1[camp_name] = letters[0]
		print("MAIL CHECK: %-11s letters a day %.1f %.1f %.1f, beds taken at 20:00 %.1f %.1f %.1f of %d" % [
			camp_name, letters[0], letters[1], letters[2], held[0], held[1], held[2], beds])
		if camp_name == "thirty beds":
			if held[0] < 0.6 * beds:
				_failures.append("thirty beds: %.1f taken on the first evening, want 18 or more" % held[0])
			if held[1] < 0.8 * beds:
				_failures.append("thirty beds: %.1f taken on the second evening, want 24 or more" % held[1])
		if camp_name == "ten beds" and held[0] < 6.0:
			_failures.append("ten beds: %.1f taken on the first evening, want 6 or more" % held[0])
		if camp_name == "one tent" and letters[0] > 3.5:
			_failures.append("one tent: %.1f letters on day 1, want a calm 1-3" % letters[0])
	if float(letters_d1["thirty beds"]) < 2.5 * float(letters_d1["four beds"]):
		_failures.append("thirty beds draw %.1f letters on day 1, four beds %.1f: more beds should bring more" % [letters_d1["thirty beds"], letters_d1["four beds"]])

	# A camp kept half empty for a week: the letters build up; spam; the night's alarms.
	var bookings := []
	var spam := []
	bookings.resize(8)
	spam.resize(8)
	bookings.fill(0)
	spam.fill(0)
	var alarms_per_night := {}
	var day_alarms := 0
	for run in RUNS:
		em._false_alarm_night = -1
		for day in range(1, 8):
			for hour in 24:
				var n: int = em._roll_customer_mail_count({"capacity": 10, "free": 5}, day, hour)
				bookings[day] += n
				if (hour < 7 or hour > 20) and n > 0:
					_failures.append("booking at %02d:00" % hour)
				if em._roll_spam(day, hour):
					spam[day] += 1
				if em._roll_night_false_alarm(day, hour):
					var night: int = day if hour >= 22 else day - 1
					var key := "%d:%d" % [run, night]
					alarms_per_night[key] = int(alarms_per_night.get(key, 0)) + 1
					if hour > 4 and hour < 22:
						day_alarms += 1
	for key in alarms_per_night:
		if int(alarms_per_night[key]) > 1:
			_failures.append("night %s had %d false alarms" % [key, alarms_per_night[key]])
			break
	if day_alarms > 0:
		_failures.append("%d false alarms in daytime" % day_alarms)
	var line := "MAIL CHECK: five of ten beds free, letters a day"
	for day in range(1, 8):
		line += " d%d=%.1f" % [day, float(bookings[day]) / RUNS]
	print(line)
	print("MAIL CHECK: spam/day d1=%.1f d7=%.1f, false alarms on %.0f%% of nights" % [
		float(spam[1]) / RUNS, float(spam[7]) / RUNS, 100.0 * alarms_per_night.size() / float(RUNS * 6)])
	var d1 := float(bookings[1]) / RUNS
	var d7 := float(bookings[7]) / RUNS
	if d7 <= d1 * 1.4:
		_failures.append("day 7 bookings %.1f do not build up from day 1 (%.1f)" % [d7, d1])
	if float(spam[7]) / RUNS > 3.0:
		_failures.append("too much spam on day 7")

	# Atlas's advertising: the front page's banner brings half as many letters again, the
	# three kinds together nearly twice as many; nothing before it was paid for.
	_goggle = load("res://scripts/reviews/goggle.gd").new(5)
	var plain := _letters_a_day(em, 2)
	_goggle.buy_ad("front", 7, 2 * 24)
	var front := _letters_a_day(em, 2)
	_goggle.buy_ad("listing", 7, 2 * 24)
	_goggle.buy_ad("travel", 7, 2 * 24)
	var all3 := _letters_a_day(em, 2)
	var before := _letters_a_day(em, 1)
	_goggle = null
	print("MAIL CHECK: thirty free beds, letters on day 2: %.1f; the front page's banner %.1f; all three %.1f (day 1, before them: %.1f)" % [plain, front, all3, before])
	if front < plain * 1.35 or front > plain * 1.65:
		_failures.append("the front page's banner: %.1f letters for %.1f, want about half as many again" % [front, plain])
	if all3 < plain * 1.75:
		_failures.append("all three campaigns: %.1f letters for %.1f, want nearly twice as many" % [all3, plain])

	# A fast clock steps over :00 (a frame passes minutes): that hour is rolled all the same,
	# two missed ones too; a jump of the clock by half a day rolls none of what it skipped.
	var today := maxi(1, int(CoreRoot.get_day()))
	em._last_hourly_roll_signature = "%d:09" % today
	em._last_tick_signature = ""
	em._on_time_tick(10, 3)
	if em._last_hourly_roll_signature != "%d:10" % today:
		_failures.append("10:00 stepped over: rolled up to %s" % em._last_hourly_roll_signature)
	em._on_time_tick(12, 1)
	if em._last_hourly_roll_signature != "%d:12" % today:
		_failures.append("11:00 and 12:00 stepped over: rolled up to %s" % em._last_hourly_roll_signature)
	var letters_before: int = em._scheduled_mails.size()
	em._on_time_tick(23, 30)
	if em._last_hourly_roll_signature != "%d:23" % today or em._scheduled_mails.size() - letters_before > 1:
		_failures.append("a jump to 23:30 rolled the hours between (%s, %d letters)" % [em._last_hourly_roll_signature, em._scheduled_mails.size() - letters_before])
	print("MAIL CHECK: the hour's roll with :00 stepped over: %s" % ("ok" if _failures.is_empty() else "see below"))
	print("")
	if _failures.is_empty():
		print("MAIL CHECK: PASS")
		get_tree().quit(0)
	else:
		print("MAIL CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures.slice(0, 10):
			print("  - " + f)
		get_tree().quit(1)


## Booking letters a day on `day` to a camp of thirty beds all free, every run.
func _letters_a_day(em, day: int) -> float:
	var n := 0
	for run in RUNS:
		for hour in 24:
			n += int(em._roll_customer_mail_count({"capacity": 30, "free": 30}, day, hour))
	return float(n) / RUNS


## `tents` one-bed tents and `cabins` two-bed cabins, as beds a lodging.
func _lodgings(tents: int, cabins: int) -> Array:
	var out := []
	for i in tents:
		out.append(1)
	for i in cabins:
		out.append(2)
	return out


## Letters a day and beds taken at 20:00, for `days` days: every booking that fits is
## taken at once (biggest lodgings first) and the party holds them till 10:00 of its last day.
func _camp_days(em, lodgings: Array, days: int) -> Array:
	var held := []
	held.resize(lodgings.size())
	held.fill(0)
	var leaves := {}
	var next_id := 1
	var out := []
	for day in range(1, days + 1):
		var letters := 0
		var taken_evening := 0
		for hour in 24:
			var now := (day - 1) * 1440 + hour * 60
			for gid in leaves.keys():
				if int(leaves[gid]) <= now:
					for i in held.size():
						if int(held[i]) == int(gid):
							held[i] = 0
					leaves.erase(gid)
			var free := 0
			var cap := 0
			for i in lodgings.size():
				cap += int(lodgings[i])
				if int(held[i]) == 0:
					free += int(lodgings[i])
			if hour == 20:
				taken_evening = cap - free
			var n: int = em._roll_customer_mail_count({"capacity": cap, "free": free}, day, hour)
			if n <= 0:
				continue
			letters += n
			for arch in em._roll_archetype_batch(n, 0.3, day):
				var cfg: Dictionary = em.CUSTOMER_ARCHETYPES[arch]
				var party := _rng.randi_range(int(cfg["party_min"]), int(cfg["party_max"]))
				var stay := _rng.randi_range(int(cfg["stay_min"]), int(cfg["stay_max"]))
				if _take(lodgings, held, next_id, party):
					leaves[next_id] = (day - 1 + stay) * 1440 + 600
					next_id += 1
		out.append([letters, taken_evening])
	return out


func _take(lodgings: Array, held: Array, guest_id: int, party: int) -> bool:
	var free_idx := []
	for i in lodgings.size():
		if int(held[i]) == 0:
			free_idx.append(i)
	free_idx.sort_custom(func(a, b): return int(lodgings[a]) > int(lodgings[b]))
	var got := []
	var beds := 0
	for i in free_idx:
		if beds >= party:
			break
		got.append(i)
		beds += int(lodgings[i])
	if beds < party:
		return false
	for i in got:
		held[i] = guest_id
	return true
