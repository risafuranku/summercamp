extends Node

## Headless check of the day's events (scripts/day_events.gd): a few are planned each
## day, they fit the camp (no lost boy without a family), left alone they cost moods and
## money, sorted they help.
##
##   godot --headless --path godot res://tools/dayevents_check.tscn

const DAY_EVENTS := preload("res://scripts/day_events.gd")

var _failures: Array[String] = []
var _day := 1
var _hour := 7
var _minute := 0
var _events


func _ready() -> void:
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	state.grid.cells.clear()
	state.guests.clear()
	state.guest_reviews.clear()
	state.accommodation_states.clear()
	state.day = 1
	state.money = 1000
	GuestManager.reset_runtime_state()
	_place("cabin_2", Vector2i(6, 6))
	_place("cabin_2", Vector2i(9, 6))
	_place("tent_3", Vector2i(12, 6))
	_place("restaurant", Vector2i(6, 10))
	_place("bonfire", Vector2i(10, 12))
	_place("path", Vector2i(8, 9))
	_place("path", Vector2i(8, 10))
	_run_minutes(1)
	for key in GuestManager.get_accommodation_states().keys():
		for t in GuestManager.get_room_state(str(key)).get("tasks", []):
			GuestManager.complete_room_task(str(key), str(t["id"]))
	_book("Novak family", "family", 3, 3)
	_book("Kojot", "tramp", 2, 3)
	_book("Vlasta Kral", "picker", 1, 3)
	_run_minutes(1)
	for g in CoreRoot.get_state().guests:
		GuestManager.request_check_in(int(g.get("id", -1)))
	_events = DAY_EVENTS.new()
	add_child(_events)
	_events.setup(self)

	# Day 1, nobody does anything: everything planned opens and then is lost.
	var mood_before := _avg_mood()
	_run_day_events(7 * 60, 21 * 60)
	var kinds := {}
	var failed := 0
	for ev in _events._events:
		kinds[str(ev["kind"])] = true
		if str(ev["state"]) == "failed":
			failed += 1
	print("DAYEVENTS CHECK: day 1 kinds %s, failed %d, mood %.1f -> %.1f" % [kinds.keys(), failed, mood_before, _avg_mood()])
	_expect(_events._events.size() >= 2, "at least two events on day 1 (%d)" % _events._events.size())
	_expect(failed == _events._events.size(), "left alone, every event is lost by night (%d of %d)" % [failed, _events._events.size()])
	_expect(_avg_mood() < mood_before - 3.0, "ignored events sour the guests (%.1f -> %.1f)" % [mood_before, _avg_mood()])

	# Many days: the families' and the noisy mix's events show up; none for absent kinds.
	var seen := {}
	for d in 6:
		_events._planned_day = -1
		_events._events.clear()
		_events._plan(10 + d, (10 + d - 1) * 1440 + 7 * 60)
		for ev in _events._events:
			seen[str(ev["kind"])] = true
	print("DAYEVENTS CHECK: kinds over a week: %s" % [seen.keys()])
	_expect(seen.has("lost_kid"), "a family in camp: sometimes the boy goes missing")
	_expect(seen.has("noise"), "tramps next to pickers: sometimes a noise complaint")
	_expect(seen.has("raccoons") or seen.has("delivery"), "a bistro: raccoons or the delivery van")

	# Sorting one out helps: the lost boy found pays a tip and cheers the family.
	_events._events.clear()
	var ev: Dictionary = _events.debug_start("lost_kid")
	_expect(not ev.is_empty() and str(ev["state"]) == "open", "a lost boy can be started")
	var money_before := int(CoreRoot.get_state().money)
	var fam_before := _avg_mood(["family"])
	_events._resolve(ev)
	_expect(str(ev["state"]) == "done", "found: the event is done")
	_expect(int(CoreRoot.get_state().money) > money_before, "the parents tip")
	_expect(_avg_mood(["family"]) > fam_before, "and are happier (%.1f -> %.1f)" % [fam_before, _avg_mood(["family"])])

	# The noise complaint is settled by talking to the loud party.
	var noise: Dictionary = _events.debug_start("noise")
	_expect(not noise.is_empty(), "a noise complaint can be started")
	if not noise.is_empty():
		_events.on_talked_to({"id": int(noise["guest_id"]), "name": "Kojot"})
		_expect(str(noise["state"]) == "done", "talking to the loud party settles it")

	# Save / load keeps what is open.
	_events._events.clear()
	var open: Dictionary = _events.debug_start("raccoons")
	var data: Dictionary = JSON.parse_string(JSON.stringify(_events.export_state()))
	_events.import_state(data)
	_expect(_events.open_events().size() == 1 and str(_events.open_events()[0]["kind"]) == "raccoons", "open events survive save/load")

	print("")
	if _failures.is_empty():
		print("DAYEVENTS CHECK: PASS")
		get_tree().quit(0)
	else:
		print("DAYEVENTS CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _run_day_events(from_minute: int, to_minute: int) -> void:
	for m in range(from_minute, to_minute):
		var abs_m := (_day - 1) * 1440 + m
		_events.tick(0.016, abs_m, m < 20 * 60, _day, false)
		if m == 20 * 60:
			_events.on_night()


func _avg_mood(archetypes: Array = []) -> float:
	var total := 0.0
	var n := 0
	for g in CoreRoot.get_state().guests:
		if not archetypes.is_empty() and not archetypes.has(str(g.get("archetype", ""))):
			continue
		total += float(g.get("mood", 0.0))
		n += 1
	return total / maxf(1.0, float(n))


func _place(type: String, origin: Vector2i) -> void:
	CoreRoot.get_state().grid.occupy_cell(origin, type, "%s_%d_%d" % [type, origin.x, origin.y], origin)


func _book(guest_name: String, archetype: String, party: int, nights: int) -> void:
	EventBus.customer_booking_confirmed.emit({
		"guest_name": guest_name,
		"archetype": archetype,
		"guests": party,
		"nights": nights,
		"from": "%s <x@y>" % guest_name,
		"arrival_minutes": 0,
	})


func _run_minutes(total: int) -> void:
	for i in total:
		_minute += 1
		if _minute >= 60:
			_minute = 0
			_hour += 1
			if _hour >= 24:
				_hour = 0
				_day += 1
				CoreRoot.get_state().day = _day
		EventBus.time_tick.emit(_hour, _minute)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
