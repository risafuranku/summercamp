extends Node

## Headless check of bookings, arrivals at the barrier and room preparation
## (GuestManager + core/systems/room_rules.gd).
##
##   godot --headless --path godot res://tools/arrival_check.tscn

const ROOM_RULES := preload("res://core/systems/room_rules.gd")
const SAVE_CODEC := preload("res://scripts/save_codec.gd")

var _failures: Array[String] = []
var _day := 1
var _hour := 9
var _minute := 0
var _at_gate: Array = []
var _checked_in: Array = []
var _gave_up: Array = []
var _prepared: Array = []


func _ready() -> void:
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	state.grid.cells.clear()
	state.guests.clear()
	state.guest_reviews.clear()
	state.accommodation_states.clear()
	state.day = 1
	GuestManager.reset_runtime_state()
	EventBus.guest_at_gate.connect(func(g): _at_gate.append(g))
	EventBus.guest_checked_in.connect(func(g): _checked_in.append(g))
	EventBus.guest_gave_up.connect(func(g): _gave_up.append(g))
	EventBus.room_prepared.connect(func(k): _prepared.append(k))
	_run_minutes(1)

	_place("tent_1", Vector2i(6, 6))
	_place("tent_1", Vector2i(8, 6))
	_run_minutes(1)
	var room: Dictionary = GuestManager.get_room_state("6:6")
	_expect(str(room.get("status", "")) == ROOM_RULES.STATUS_UNPREPARED, "a new tent starts unprepared (%s)" % room.get("status", "?"))
	_expect((room.get("remaining", []) as Array).size() == 2, "a tent has two tasks")

	# Booking: on the road, beds reserved, nobody in the camp yet.
	_book("Pepa", "drunk", 1, 1, 30)
	var arrivals: Array = GuestManager.get_arrivals()
	_expect(arrivals.size() == 1 and not bool(arrivals[0]["at_gate"]), "the booked party is on the way")
	_expect(arrivals.size() == 1 and int(arrivals[0]["minutes"]) == 30, "arrives in 30 minutes")
	_expect(arrivals.size() == 1 and (arrivals[0]["rooms"] as Array).size() == 1 and not bool(arrivals[0]["rooms"][0]["ready"]), "its room is named and not ready")
	_expect(GuestManager.get_guest_life_snapshot().is_empty(), "nobody is in the camp before arriving")
	_expect(int(GuestManager.get_bed_metrics().get("free", -1)) == 1, "the booking holds a bed")

	# At the barrier.
	_run_minutes(30)
	_expect(_at_gate.size() == 1, "reaching the barrier is announced")
	var snap: Array = GuestManager.get_guest_life_snapshot()
	_expect(snap.size() == 1 and str(snap[0]["activity"].get("kind", "")) == "wait_gate", "the party stands at the barrier")
	_run_minutes(50)
	_expect(_checked_in.is_empty(), "nobody is let in while the room is not ready")
	_expect(str(GuestManager.get_guest_life_snapshot()[0]["thought"]).contains("barrier"), "a long wait is complained about")

	# Checking in by hand is refused while the room is not made up.
	var pepa_id := int(GuestManager.get_arrivals()[0]["id"])
	var refused: Dictionary = GuestManager.request_check_in(pepa_id)
	_expect(not bool(refused.get("ok", true)) and str(refused.get("reason", "")) == "room_not_ready", "check-in is refused while the room is not ready")

	# Make the room up: still nobody goes in until the player checks them in.
	var key := str(arrivals[0]["rooms"][0]["key"])
	for t in GuestManager.get_room_state(key).get("tasks", []):
		GuestManager.complete_room_task(key, str(t["id"]))
	_expect(_prepared.has(key), "the room is announced ready")
	_expect(_checked_in.is_empty(), "nobody walks in by themselves")
	_expect(bool(GuestManager.request_check_in(pepa_id).get("ok", false)), "the player checks the party in")
	_expect(_checked_in.size() == 1, "the waiting party is let in once checked in")
	snap = GuestManager.get_guest_life_snapshot()
	_expect(snap.size() == 1 and str(snap[0]["activity"].get("kind", "")) == "arrive", "and walks in from the gate")
	_expect(snap.size() == 1 and float(snap[0]["mood"]) < 60.0, "an 80-minute wait sours the mood (%.0f)" % float(snap[0]["mood"]) if snap.size() == 1 else "")

	# A second party for the second, unprepared tent: left at the barrier, it gives up.
	_book("Mirek", "quiet_guy", 1, 1, 0)
	_run_minutes(ROOM_RULES.TASKS.size() + GuestManager.GATE_GIVE_UP_MINUTES + 2)
	_expect(_gave_up.size() == 1, "a party left at the barrier gives up")
	var gave_up_review := false
	for r in CoreRoot.get_state().guest_reviews:
		if bool((r as Dictionary).get("gave_up", false)) and int(r.get("rating", 0)) == 1:
			gave_up_review = true
	_expect(gave_up_review, "and leaves a one-star review")
	_expect(int(GuestManager.get_bed_metrics().get("free", -1)) == 1, "its bed is free again")

	# Pepa checks out after one night: the tent needs making up again.
	_run_minutes(24 * 60)
	room = GuestManager.get_room_state(key)
	_expect(str(room.get("status", "")) == ROOM_RULES.STATUS_DIRTY, "the tent is dirty after the guests leave (%s)" % room.get("status", "?"))
	_expect((room.get("done", []) as Array).is_empty(), "and every task is to do again")

	# Old saves said "clean": those rooms load as ready.
	var legacy: Dictionary = SAVE_CODEC.deserialize_accommodation_states({"1:1": {"status": "clean", "building_type": "tent_1", "capacity": 1, "guest_ids": []}})
	_expect(str(legacy["1:1"]["status"]) == ROOM_RULES.STATUS_READY, "a legacy clean room loads as ready")

	print("")
	if _failures.is_empty():
		print("ARRIVAL CHECK: PASS")
		get_tree().quit(0)
	else:
		print("ARRIVAL CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _place(type: String, origin: Vector2i) -> void:
	CoreRoot.get_state().grid.occupy_cell(origin, type, "%s_%d_%d" % [type, origin.x, origin.y], origin)


func _book(guest_name: String, archetype: String, party: int, nights: int, arrival_minutes: int) -> void:
	EventBus.customer_booking_confirmed.emit({
		"guest_name": guest_name,
		"archetype": archetype,
		"guests": party,
		"nights": nights,
		"from": "%s <x@y>" % guest_name,
		"arrival_minutes": arrival_minutes,
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
