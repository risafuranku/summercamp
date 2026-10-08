extends Node

## Headless check for the guest needs / mood / activity simulation.
##
##   godot --headless --path godot res://tools/guest_sim_check.tscn
##
## Builds a small camp straight into CoreRoot's grid (no 3D), books guests through the
## real EventBus path, runs the minute clock for several in-game days and asserts the
## simulation does sensible things: facilities get visited, moods stay in range, broken
## toilets hurt, and departures write reviews. Run as a SCENE (autoloads required).

var _failures: Array[String] = []
var _day := 1
var _hour := 9
var _minute := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	state.grid.cells.clear()
	state.guests.clear()
	state.guest_reviews.clear()
	state.failures.clear()
	state.day = 1
	GuestManager.reset_runtime_state()

	_place("cabin_2", Vector2i(4, 6), Vector2i(2, 2))
	_place("cabin_2", Vector2i(8, 6), Vector2i(2, 2))
	_place("tent_3", Vector2i(12, 6))
	_place("tent_2", Vector2i(13, 6))
	_place("toilet_block", Vector2i(7, 9))
	_place("shower_block", Vector2i(8, 9))
	_place("restaurant", Vector2i(11, 10), Vector2i(2, 2))
	_place("pub", Vector2i(4, 10), Vector2i(2, 2))
	_place("bonfire", Vector2i(9, 13))
	_place("lake_slide", Vector2i(12, 16), Vector2i(2, 1))
	_place("sewer", Vector2i(2, 16))
	_place("lamp_post", Vector2i(9, 8))

	var beds: Dictionary = GuestManager.get_bed_metrics()
	_expect(int(beds.get("capacity", 0)) == 3 + 3 + 3 + 2, "bed capacity reads BuildingDef capacity (got %d)" % int(beds.get("capacity", 0)))

	_prepare_all_rooms()
	_book("Novak family", "quiet_guy", 3, 3)
	_book("Pepa & Franta", "drunk", 2, 2)
	_book("Kristýna", "cheap_chick", 1, 2)
	_book("Mirek", "drunk", 1, 1)
	_run_minutes(1)

	var snap: Array = GuestManager.get_guest_life_snapshot()
	_expect(snap.size() == 4, "4 guest parties checked in (got %d)" % snap.size())
	for g in snap:
		_expect(str((g as Dictionary).get("activity", {}).get("kind", "")) == "arrive", "new guest starts by walking in from the gate")

	# Day 1 09:00 -> day 2 18:00 with everything working. On the way, sample how many
	# guests are out in the open in daytime: the camp should feel half empty.
	var samples := 0
	var outdoors := 0
	var away_seen := false
	for chunk in 33 * 6:
		_run_minutes(10)
		if _hour < 8 or _hour >= 19:
			continue
		var now := (_day - 1) * 1440 + _hour * 60 + _minute
		for g in GuestManager.get_guest_life_snapshot():
			var act: Dictionary = (g as Dictionary).get("activity", {})
			samples += 1
			if _is_out_in_the_open(act, now):
				outdoors += 1
			if str(act.get("kind", "")) == "away":
				away_seen = true
	var share := float(outdoors) / maxf(1.0, float(samples))
	print("daytime share of guests out in the open: %.0f%%" % (share * 100.0))
	_expect(share < 0.45, "the camp should feel half empty by day (%.0f%% outdoors)" % (share * 100.0))
	_expect(away_seen, "idle guests sometimes leave the camp by an exit")
	var summary: Dictionary = GuestManager.get_camp_mood_summary()
	print("after 33h: ", _fmt_summary(summary))
	var visits := 0
	var kinds := {}
	for g in GuestManager.get_guest_life_snapshot():
		var gd: Dictionary = g
		for need in gd.get("needs", {}).keys():
			var v := float(gd["needs"][need])
			_expect(v >= 0.0 and v <= 100.0, "need %s in range" % need)
		print("  %-14s %-11s mood %5.1f %-9s act=%-9s worst=%s  \"%s\"" % [
			gd["name"], gd["archetype"], float(gd["mood"]), gd["mood_label"],
			str(gd["activity"].get("kind", "-")), str(gd["worst_need"].get("label", "")), gd["thought"]])
	var state2 = CoreRoot.get_state()
	for g_any in state2.guests:
		visits += int((g_any as Dictionary).get("visits", 0))
	_expect(visits >= 8, "guests visited facilities (visits=%d)" % visits)
	_expect(float(summary.get("avg_mood", 0.0)) > 45.0, "well-equipped camp keeps guests at least okay (avg %.1f)" % float(summary.get("avg_mood", 0.0)))

	# Break the sewer: toilets + showers close camp-wide.
	state2.failures["2:16"] = {"type": "sewer", "coord": Vector2i(2, 16), "since_day": state2.day, "repair_progress": 0.0}
	var closed := 0
	GuestManager._life.refresh_world(state2, CoreRoot.registry)
	for f in GuestManager.get_facility_status():
		if str(f.get("reason", "")) == "no_sewer":
			closed += 1
	_expect(closed == 2, "sewer failure closes toilets and showers (closed=%d)" % closed)
	var mood_before := float(GuestManager.get_camp_mood_summary().get("avg_mood", 0.0))
	_run_minutes(10 * 60)
	var mood_after := float(GuestManager.get_camp_mood_summary().get("avg_mood", 0.0))
	print("sewer broken 10h: mood %.1f -> %.1f" % [mood_before, mood_after])
	_expect(mood_after < mood_before, "broken sewer lowers mood")
	var saw_complaint := false
	for t in GuestManager.get_camp_mood_summary().get("thoughts", []):
		var text := str((t as Dictionary).get("text", ""))
		if text.contains("sewer") or text.contains("bushes") or text.contains("toilet"):
			saw_complaint = true
	_expect(saw_complaint, "guests complain about the toilets")
	state2.failures.clear()

	# Run until everyone has checked out.
	_run_minutes(4 * 24 * 60)
	_expect(CoreRoot.get_state().guests.is_empty(), "all guests checked out (left %d)" % CoreRoot.get_state().guests.size())
	var reviews: Array = CoreRoot.get_state().guest_reviews
	_expect(reviews.size() >= 4, "every departure wrote a review (%d)" % reviews.size())
	for r in reviews:
		print("  review %s: %d* mood %.0f  %s" % [r.get("name", "?"), int(r.get("rating", 0)), float(r.get("mood", 0)), r.get("text", "")])

	# A bare camp (beds, nothing else) should make guests miserable enough to leave early.
	CoreRoot.get_state().grid.cells.clear()
	CoreRoot.get_state().guest_reviews.clear()
	_place("tent_3", Vector2i(6, 6))
	_place("tent_3", Vector2i(7, 6))
	_prepare_all_rooms()
	_book("Unlucky Pair", "cheap_chick", 2, 4)
	_run_minutes(30 * 60)
	var bare: Dictionary = GuestManager.get_camp_mood_summary()
	print("bare camp 30h: ", _fmt_summary(bare))
	var stormed := false
	for r in CoreRoot.get_state().guest_reviews:
		if bool((r as Dictionary).get("stormed_off", false)):
			stormed = true
			print("  storm-off review: %d* %s" % [int(r.get("rating", 0)), r.get("text", "")])
	_expect(stormed or float(bare.get("avg_mood", 100.0)) < 35.0, "a camp with nothing in it makes guests miserable")

	print("")
	if _failures.is_empty():
		print("GUEST SIM CHECK: PASS")
		get_tree().quit(0)
	else:
		print("GUEST SIM CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _place(type: String, origin: Vector2i, footprint: Vector2i = Vector2i.ONE) -> void:
	var state = CoreRoot.get_state()
	var id := "%s_%d_%d" % [type, origin.x, origin.y]
	for y in footprint.y:
		for x in footprint.x:
			state.grid.occupy_cell(origin + Vector2i(x, y), type, id, origin)


func _book(guest_name: String, archetype: String, party: int, nights: int) -> void:
	EventBus.customer_booking_confirmed.emit({
		"guest_name": guest_name,
		"archetype": archetype,
		"guests": party,
		"nights": nights,
		"from": "%s <x@y>" % guest_name,
		"arrival_minutes": 0,
	})


## Rooms start unprepared now: make every one up, as the player would.
func _prepare_all_rooms() -> void:
	for key in GuestManager.get_accommodation_states().keys():
		var room: Dictionary = GuestManager.get_room_state(str(key))
		for t in room.get("tasks", []):
			GuestManager.complete_room_task(str(key), str(t["id"]))


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


## Mirrors guest_agents.gd: walking, or dwelling somewhere visible.
func _is_out_in_the_open(act: Dictionary, now: int) -> bool:
	if act.is_empty():
		return false
	if now < int(act.get("arrive", now)):
		return true
	var kind := str(act.get("kind", ""))
	if bool(act.get("queued", false)):
		return true
	if kind == "visit":
		return ["bonfire", "sports_field", "lake_slide"].has(str(act.get("target_type", "")))
	return kind in ["wander", "linger", "bushes", "night_out"]


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _fmt_summary(s: Dictionary) -> String:
	return "guests=%d avg_mood=%.1f (%s) unhappy=%d top_need=%s" % [
		int(s.get("guests", 0)), float(s.get("avg_mood", 0.0)), str(s.get("mood_label", "")),
		int(s.get("unhappy", 0)), str(s.get("top_need_label", ""))]
