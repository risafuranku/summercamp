extends Node
## GuestManager -- simplified stay runtime.
##
## Assignment/waiting status flows were removed.
## Accepting a customer booking now immediately checks in the guest group,
## reserves beds and starts stay countdown + rolling income.

const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")

const STATUS_ACTIVE := "active"
const STATUS_SLEEP := "sleep"

const MINUTES_PER_DAY := 1440.0
const MAX_GUEST_REVIEW_HISTORY := 48
const MAX_GUEST_TRANSACTION_HISTORY := 96

const ARCHETYPE_QUIET_GUY := "quiet_guy"
const ARCHETYPE_DRUNK := "drunk"
const ARCHETYPE_CHEAP_CHICK := "cheap_chick"
const ARCHETYPE_ALIASES := {
	"quietguy": ARCHETYPE_QUIET_GUY,
	"quiet_guy": ARCHETYPE_QUIET_GUY,
	"quiet guy": ARCHETYPE_QUIET_GUY,
	"drunk": ARCHETYPE_DRUNK,
	"cheapchick": ARCHETYPE_CHEAP_CHICK,
	"cheap_chick": ARCHETYPE_CHEAP_CHICK,
	"cheap chick": ARCHETYPE_CHEAP_CHICK,
}
const GUEST_SPRITE_PATHS := {
	ARCHETYPE_QUIET_GUY: "res://assets/textury/npc/host1.png",
	ARCHETYPE_DRUNK: "res://assets/textury/npc/host2.png",
	ARCHETYPE_CHEAP_CHICK: "res://assets/textury/npc/host3.png",
}

const LIMINAL_FORECAST_SAFE_COUNT := 3
const LIMINAL_FORECAST_STEP_GUESTS := 6
const LIMINAL_FORECAST_FIRST_STAGE_OFFSET := 3
const LIMINAL_FORECAST_GUARANTEED_OFFSET := 21
const LIMINAL_FORECAST_LOOP_GUESTS := LIMINAL_FORECAST_STEP_GUESTS * 4

const LIMINAL_CHANCE_TIER_NONE := "none"
const LIMINAL_CHANCE_TIER_TINY := "tiny"
const LIMINAL_CHANCE_TIER_SMALL := "small"
const LIMINAL_CHANCE_TIER_MEDIUM := "medium"
const LIMINAL_CHANCE_TIER_LARGE := "large"

const LIMINAL_ARCHETYPE_ORDER := [
	ARCHETYPE_QUIET_GUY,
	ARCHETYPE_DRUNK,
	ARCHETYPE_CHEAP_CHICK,
]

const LIMINAL_ARCHETYPE_LABELS := {
	ARCHETYPE_QUIET_GUY: "Quiet Guy",
	ARCHETYPE_DRUNK: "Drunk",
	ARCHETYPE_CHEAP_CHICK: "Cheap Chick",
}

const LIMINAL_CHANCE_RANGES := {
	LIMINAL_CHANCE_TIER_TINY: Vector2(0.12, 0.18),
	LIMINAL_CHANCE_TIER_SMALL: Vector2(0.20, 0.32),
	LIMINAL_CHANCE_TIER_MEDIUM: Vector2(0.36, 0.56),
	LIMINAL_CHANCE_TIER_LARGE: Vector2(0.62, 0.86),
}

const LIMINAL_HUD_EXPECTED_THRESHOLDS := [0.10, 0.30, 0.58, 0.95]

const DEFAULT_DAILY_INCOME_BY_ARCHETYPE := {
	ARCHETYPE_QUIET_GUY: 70,
	ARCHETYPE_DRUNK: 120,
	ARCHETYPE_CHEAP_CHICK: 190,
}

const DEFAULT_TROUBLE_TIME_BY_ARCHETYPE := {
	ARCHETYPE_QUIET_GUY: "22:40",
	ARCHETYPE_DRUNK: "00:30",
	ARCHETYPE_CHEAP_CHICK: "02:20",
}

const REVIEW_POSITIVE := [
	"Great stay. Quiet enough and staff was helpful.",
	"Everything worked and the camp felt organized.",
	"Would book again, smooth check-in and solid facilities.",
]

const REVIEW_NEUTRAL := [
	"Stay was fine overall. Nothing major to report.",
	"Average experience, some noise but manageable.",
	"Could be cleaner, but service was acceptable.",
]

const REVIEW_NEGATIVE := [
	"Rough stay. Noise and issues during the night.",
	"Service needs improvement before we return.",
	"Not ideal this time. Camp felt chaotic.",
]

var _rng := RandomNumberGenerator.new()
var _last_tick_signature: String = ""
var _last_guest_overview: Dictionary = {}
var _last_known_day: int = 1
var _last_known_hour: int = 9
var _last_known_minute: int = 0
var _last_income_abs_minute: int = -1


func _ready() -> void:
	_rng.randomize()
	_ensure_guest_state_defaults()
	_last_known_day = max(1, CoreRoot.get_day())
	_last_income_abs_minute = -1

	if EventBus.has_signal("customer_booking_confirmed"):
		var confirm_cb := Callable(self, "_on_customer_booking_confirmed")
		if not EventBus.customer_booking_confirmed.is_connected(confirm_cb):
			EventBus.customer_booking_confirmed.connect(confirm_cb)

	if EventBus.has_signal("time_tick"):
		var tick_cb := Callable(self, "_on_time_tick")
		if not EventBus.time_tick.is_connected(tick_cb):
			EventBus.time_tick.connect(tick_cb)

	_ensure_guest_lodging_assignments()
	_sync_accommodation_states_from_guests(false)
	_emit_guest_overview_state(true)


func export_runtime_state() -> Dictionary:
	return {
		"last_tick_signature": str(_last_tick_signature),
		"last_known_day": max(1, int(_last_known_day)),
		"last_known_hour": clampi(int(_last_known_hour), 0, 23),
		"last_known_minute": clampi(int(_last_known_minute), 0, 59),
		"last_income_abs_minute": int(_last_income_abs_minute),
	}


func import_runtime_state(data: Dictionary) -> void:
	_ensure_guest_state_defaults()
	if data.is_empty():
		reset_runtime_state()
		return

	_last_known_day = max(1, int(data.get("last_known_day", CoreRoot.get_day())))
	_last_known_hour = clampi(int(data.get("last_known_hour", 9)), 0, 23)
	_last_known_minute = clampi(int(data.get("last_known_minute", 0)), 0, 59)
	var fallback_abs := _absolute_minutes(_last_known_day, _last_known_hour, _last_known_minute)
	_last_income_abs_minute = int(data.get("last_income_abs_minute", fallback_abs))
	if _last_income_abs_minute < 0:
		_last_income_abs_minute = fallback_abs
	_last_tick_signature = str(data.get("last_tick_signature", _runtime_signature()))
	if _last_tick_signature.is_empty():
		_last_tick_signature = _runtime_signature()

	_ensure_guest_lodging_assignments()
	_sync_accommodation_states_from_guests(false)
	_emit_guest_overview_state(true)


func reset_runtime_state() -> void:
	_ensure_guest_state_defaults()
	_last_tick_signature = ""
	_last_guest_overview.clear()
	_last_known_day = max(1, CoreRoot.get_day())
	_last_known_hour = 9
	_last_known_minute = 0
	_last_income_abs_minute = -1
	_ensure_guest_lodging_assignments()
	_sync_accommodation_states_from_guests(false)
	_emit_guest_overview_state(true)


func _runtime_signature() -> String:
	return "%d:%02d:%02d" % [_last_known_day, _last_known_hour, _last_known_minute]


func _on_time_tick(hour: int, minute: int) -> void:
	_last_known_day = max(1, CoreRoot.get_day())
	_last_known_hour = clampi(hour, 0, 23)
	_last_known_minute = clampi(minute, 0, 59)

	var signature = _runtime_signature()
	if signature == _last_tick_signature:
		return
	var first_tick = _last_tick_signature.is_empty()
	_last_tick_signature = signature

	_ensure_guest_state_defaults()
	var now_abs = _absolute_minutes(_last_known_day, _last_known_hour, _last_known_minute)
	if first_tick or _last_income_abs_minute < 0:
		_last_income_abs_minute = now_abs
	var elapsed_minutes = now_abs - _last_income_abs_minute
	if elapsed_minutes < 0:
		elapsed_minutes = 0
	var changed := false
	changed = _update_stay_states(_last_known_day, _last_known_hour, _last_known_minute) or changed
	if elapsed_minutes > 0:
		changed = _process_income_minutes(elapsed_minutes) or changed
	changed = _ensure_guest_lodging_assignments() or changed
	changed = _sync_accommodation_states_from_guests() or changed
	_last_income_abs_minute = now_abs
	_emit_guest_overview_state(changed)


func can_accept_booking(mail: Dictionary) -> bool:
	if mail.is_empty():
		return false
	var requested_beds = max(1, int(mail.get("guests", mail.get("party_size", 1))))
	var metrics = get_bed_metrics()
	var free_beds = max(0, int(metrics.get("free", 0)))
	return requested_beds <= free_beds


func _on_customer_booking_confirmed(mail: Dictionary) -> void:
	if mail.is_empty():
		return
	if not can_accept_booking(mail):
		return

	_ensure_guest_state_defaults()
	var state = CoreRoot.get_state()
	if state == null:
		return

	var now_day = max(1, _last_known_day)
	var now_minute_of_day = _last_known_hour * 60 + _last_known_minute
	var now_abs = _absolute_minutes(now_day, _last_known_hour, _last_known_minute)

	var stay_nights = max(1, int(mail.get("nights", mail.get("stay_nights", 1))))
	var beds_used = max(1, int(mail.get("guests", mail.get("party_size", 1))))
	var archetype = _normalize_archetype(str(mail.get("archetype", ARCHETYPE_QUIET_GUY)))
	var difficulty = clampi(int(mail.get("difficulty", _default_difficulty_for_archetype(archetype))), 1, 5)

	var daily_income = int(mail.get("daily_total", 0))
	if daily_income <= 0:
		daily_income = _estimate_daily_income(archetype, beds_used)

	var booking_name = str(mail.get("guest_name", _extract_sender_name(mail))).strip_edges()
	if booking_name.is_empty():
		booking_name = _extract_sender_name(mail)

	var checkout_abs = now_abs + stay_nights * 1440
	var checkout_parts = _from_absolute_minutes(checkout_abs)
	var night_trouble_time = str(mail.get("night_trouble_time", _default_trouble_time_for_archetype(archetype))).strip_edges()
	var night_trouble_minute = _parse_time_to_minutes(night_trouble_time, _parse_time_to_minutes(_default_trouble_time_for_archetype(archetype), 0))

	var guest_id = int(state.next_guest_id)
	state.next_guest_id += 1

	var guest := {
		"id": guest_id,
		"name": booking_name,
		"status": STATUS_ACTIVE,
		"archetype": archetype,
		"booking_difficulty": difficulty,
		"beds_used": beds_used,
		"party_size": beds_used,
		"stay_nights": stay_nights,
		"checkin_day": now_day,
		"checkin_minute_of_day": now_minute_of_day,
		"checkout_abs_minute": checkout_abs,
		"checkout_day": int(checkout_parts.get("day", now_day + stay_nights)),
		"checkout_minute_of_day": int(checkout_parts.get("minute_of_day", now_minute_of_day)),
		"daily_income": daily_income,
		"income_fraction": 0.0,
		"income_paid_total": 0,
		"expected_total_payout": daily_income * stay_nights,
		"night_trouble_minute_of_day": night_trouble_minute,
		"night_trouble_last_night_id": -999999,
		"mail_subject": str(mail.get("subject", "")),
		"mail_from": str(mail.get("from", "")),
		"lodging_slots": [],
	}

	state.guests.append(guest)
	_ensure_guest_lodging_assignments()
	_sync_accommodation_states_from_guests(false)
	var created_guest = _get_guest_by_id(guest_id)
	if created_guest.is_empty():
		created_guest = guest
	if EventBus.has_signal("guest_created"):
		EventBus.guest_created.emit(created_guest.duplicate(true))

	_emit_guest_overview_state(true)


func _update_stay_states(day: int, hour: int, minute: int) -> bool:
	var state = CoreRoot.get_state()
	if state == null:
		return false

	var changed := false
	var now_abs = _absolute_minutes(day, hour, minute)
	var minute_of_day = hour * 60 + minute

	for i in range(state.guests.size() - 1, -1, -1):
		var guest_any = state.guests[i]
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", STATUS_ACTIVE)).to_lower().strip_edges()
		if status != STATUS_ACTIVE and status != STATUS_SLEEP:
			guest["status"] = STATUS_ACTIVE
			status = STATUS_ACTIVE
			changed = true

		var target_status = STATUS_SLEEP if _is_night_time(hour, minute) else STATUS_ACTIVE
		if status != target_status:
			if _set_guest_status(guest, target_status, day, minute_of_day):
				changed = true

		if _maybe_trigger_night_trouble(guest, day, hour, minute):
			changed = true

		var checkout_abs = int(guest.get("checkout_abs_minute", now_abs + 1))
		if now_abs >= checkout_abs:
			_process_guest_departure(guest, day, hour, minute)
			state.guests.remove_at(i)
			changed = true
			continue

		state.guests[i] = guest

	return changed


func _process_income_minutes(elapsed_minutes: int) -> bool:
	if elapsed_minutes <= 0:
		return false
	var state = CoreRoot.get_state()
	if state == null:
		return false

	var total_income := 0
	var any_change := false

	for i in range(state.guests.size()):
		var guest_any = state.guests[i]
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", STATUS_ACTIVE)).to_lower().strip_edges()
		if status != STATUS_ACTIVE and status != STATUS_SLEEP:
			continue

		var daily_income = max(1, int(guest.get("daily_income", 1)))
		var fraction = float(guest.get("income_fraction", 0.0))
		var payout_float = fraction + (float(daily_income) * float(elapsed_minutes) / MINUTES_PER_DAY)
		var payout = int(floor(payout_float))
		guest["income_fraction"] = payout_float - float(payout)
		if payout > 0:
			guest["income_paid_total"] = int(guest.get("income_paid_total", 0)) + payout
			total_income += payout
			if EventBus.has_signal("guest_payment_received"):
				EventBus.guest_payment_received.emit(payout, int(guest.get("id", -1)))

		state.guests[i] = guest
		any_change = true

	if total_income > 0:
		if CoreRoot.actions != null and CoreRoot.actions.has_method("add_money"):
			CoreRoot.actions.add_money(total_income)
		elif CoreRoot != null and CoreRoot.has_method("apply_changes") and CoreRoot.has_method("get_money"):
			CoreRoot.apply_changes({"money": CoreRoot.get_money() + total_income})

	return any_change


func _process_guest_departure(guest: Dictionary, day: int, _hour: int, _minute: int) -> void:
	var state = CoreRoot.get_state()
	if state == null:
		return

	var expected_total = max(0, int(guest.get("expected_total_payout", 0)))
	if expected_total <= 0:
		var fallback_daily = max(1, int(guest.get("daily_income", 1)))
		expected_total = fallback_daily * max(1, int(guest.get("stay_nights", 1)))
	var already_paid = max(0, int(guest.get("income_paid_total", 0)))
	var settlement = max(0, expected_total - already_paid)

	if settlement > 0:
		if CoreRoot.actions != null and CoreRoot.actions.has_method("add_money"):
			CoreRoot.actions.add_money(settlement)
		elif CoreRoot != null and CoreRoot.has_method("apply_changes") and CoreRoot.has_method("get_money"):
			CoreRoot.apply_changes({"money": CoreRoot.get_money() + settlement})
		if EventBus.has_signal("guest_payment_received"):
			EventBus.guest_payment_received.emit(settlement, int(guest.get("id", -1)))

	var tx = {
		"guest_id": int(guest.get("id", -1)),
		"name": str(guest.get("name", "Guest")),
		"day": day,
		"amount": settlement,
		"type": "guest_checkout_settlement",
	}
	state.guest_transactions.append(tx)
	_trim_array_history(state.guest_transactions, MAX_GUEST_TRANSACTION_HISTORY)

	var review = _build_review_for_guest(guest, day)
	state.guest_reviews.append(review)
	_trim_array_history(state.guest_reviews, MAX_GUEST_REVIEW_HISTORY)
	if EventBus.has_signal("guest_review_posted"):
		EventBus.guest_review_posted.emit(review)

	if EventBus.has_signal("guest_state_changed"):
		EventBus.guest_state_changed.emit(int(guest.get("id", -1)), str(guest.get("status", STATUS_ACTIVE)), "departed")


func _set_guest_status(guest: Dictionary, new_status: String, day: int, minute_of_day: int) -> bool:
	var old_status = str(guest.get("status", ""))
	if old_status == new_status:
		return false
	guest["status"] = new_status
	guest["last_state_day"] = day
	guest["last_state_minute_of_day"] = minute_of_day
	if EventBus.has_signal("guest_state_changed"):
		EventBus.guest_state_changed.emit(int(guest.get("id", -1)), old_status, new_status)
	return true


func _maybe_trigger_night_trouble(guest: Dictionary, day: int, hour: int, minute: int) -> bool:
	var night_id = _current_night_id(day, hour, minute)
	if night_id < 1:
		return false

	var trouble_minute = int(guest.get("night_trouble_minute_of_day", -1))
	if trouble_minute < 0:
		return false

	var last_night_id = int(guest.get("night_trouble_last_night_id", -999999))
	if last_night_id == night_id:
		return false

	var trigger_abs = _absolute_minutes_for_night_event(night_id, trouble_minute)
	var now_abs = _absolute_minutes(day, hour, minute)
	if now_abs < trigger_abs:
		return false

	guest["night_trouble_last_night_id"] = night_id

	var state = CoreRoot.get_state()
	if state != null and CoreRoot != null and CoreRoot.has_method("apply_changes"):
		var difficulty = clampi(int(guest.get("booking_difficulty", 1)), 1, 5)
		var sat_penalty = 0.35 + float(difficulty) * 0.30
		var karma_penalty = 0.18 + float(difficulty) * 0.16
		var hrot_boost = 0.03 + float(difficulty) * 0.03
		CoreRoot.apply_changes({
			"satisfaction": clampf(float(state.satisfaction) - sat_penalty, 0.0, 100.0),
			"karma": float(state.karma) - karma_penalty,
			"hrotfaktor": clampf(float(state.hrotfaktor) + hrot_boost, 0.0, 1.0),
		})
	return true


func _current_night_id(day: int, hour: int, minute: int) -> int:
	var now_minute = hour * 60 + minute
	var night_start = int(float(BALANCE_CONFIG.NIGHT_START_HOUR) * 60.0)
	var day_start = int(float(BALANCE_CONFIG.DAY_START_HOUR) * 60.0)
	if now_minute >= night_start:
		return day
	if now_minute < day_start:
		return day - 1
	return -1


func _absolute_minutes_for_night_event(night_id: int, minute_of_day: int) -> int:
	var night_start = int(float(BALANCE_CONFIG.NIGHT_START_HOUR) * 60.0)
	if minute_of_day >= night_start:
		return _absolute_minutes_from_day_minute(night_id, minute_of_day)
	return _absolute_minutes_from_day_minute(night_id + 1, minute_of_day)


func _estimate_daily_income(archetype: String, beds_used: int) -> int:
	var canonical = _normalize_archetype(archetype)
	var base = int(DEFAULT_DAILY_INCOME_BY_ARCHETYPE.get(canonical, DEFAULT_DAILY_INCOME_BY_ARCHETYPE[ARCHETYPE_QUIET_GUY]))
	return max(30, base * max(1, beds_used))


func _default_difficulty_for_archetype(archetype: String) -> int:
	match _normalize_archetype(archetype):
		ARCHETYPE_DRUNK:
			return 3
		ARCHETYPE_CHEAP_CHICK:
			return 5
		_:
			return 1


func _default_trouble_time_for_archetype(archetype: String) -> String:
	var canonical = _normalize_archetype(archetype)
	return str(DEFAULT_TROUBLE_TIME_BY_ARCHETYPE.get(canonical, DEFAULT_TROUBLE_TIME_BY_ARCHETYPE[ARCHETYPE_QUIET_GUY]))


func _ensure_guest_state_defaults() -> void:
	var state = CoreRoot.get_state()
	if state == null:
		return
	if state.guests == null:
		state.guests = []
	if state.accommodation_states == null:
		state.accommodation_states = {}
	if state.guest_reviews == null:
		state.guest_reviews = []
	if state.guest_transactions == null:
		state.guest_transactions = []
	if int(state.next_guest_id) <= 0:
		state.next_guest_id = 1


func get_bed_metrics() -> Dictionary:
	_ensure_guest_state_defaults()
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return {
			"capacity": 0,
			"occupied": 0,
			"free": 0,
			"occupied_ratio": 0.0,
		}

	var seen_entries: Dictionary = {}
	var capacity_total := 0
	for coord_any in state.grid.cells.keys():
		if not (coord_any is Vector2i):
			continue
		var coord: Vector2i = coord_any
		var data_any = state.grid.cells[coord_any]
		if not (data_any is Dictionary):
			continue
		var data: Dictionary = data_any
		var building_type = str(data.get("type", "")).strip_edges()
		if building_type.is_empty():
			continue
		var cap = _capacity_for_building_type(building_type)
		if cap <= 0:
			continue
		var root_any = data.get("root_coord", coord)
		var root_coord = root_any if root_any is Vector2i else coord
		var instance_id = str(data.get("id", "")).strip_edges()
		var unique_key = "id:%s" % instance_id if not instance_id.is_empty() else "root:%s:%s" % [_coord_key(root_coord), building_type]
		if seen_entries.has(unique_key):
			continue
		seen_entries[unique_key] = true
		capacity_total += cap

	var occupied_beds := 0
	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", STATUS_ACTIVE)).to_lower().strip_edges()
		if status != STATUS_ACTIVE and status != STATUS_SLEEP:
			continue
		occupied_beds += max(1, int(guest.get("beds_used", guest.get("party_size", 1))))

	occupied_beds = clampi(occupied_beds, 0, capacity_total)
	var ratio = 0.0 if capacity_total <= 0 else clampf(float(occupied_beds) / float(capacity_total), 0.0, 1.0)
	return {
		"capacity": capacity_total,
		"occupied": occupied_beds,
		"free": max(0, capacity_total - occupied_beds),
		"occupied_ratio": ratio,
	}


func _capacity_for_building_type(building_type: String) -> int:
	var t = building_type.to_lower().strip_edges()
	if t.begins_with("tent"):
		return 1
	if t.begins_with("cabin"):
		return 2
	return 0


func _emit_guest_overview_state(force: bool = false) -> void:
	var overview = _build_guest_overview()
	if not force and overview == _last_guest_overview:
		return
	_last_guest_overview = overview
	if EventBus.has_signal("state_changed"):
		EventBus.state_changed.emit({"guests": overview})


func _build_guest_overview() -> Dictionary:
	var state = CoreRoot.get_state()
	if state == null:
		return {}

	var active_count := 0
	var sleeping_count := 0
	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var status = str((guest_any as Dictionary).get("status", STATUS_ACTIVE)).to_lower().strip_edges()
		if status == STATUS_SLEEP:
			sleeping_count += 1
		else:
			active_count += 1

	var beds = get_bed_metrics()
	return {
		"total": int(state.guests.size()),
		"active": active_count,
		"sleep": sleeping_count,
		"capacity": int(beds.get("capacity", 0)),
		"occupied": int(beds.get("occupied", 0)),
		"free": int(beds.get("free", 0)),
		"reviews": int(state.guest_reviews.size()),
	}


func get_liminal_forecast_data() -> Dictionary:
	_ensure_guest_state_defaults()
	var state = CoreRoot.get_state()
	if state == null:
		return {
			"ok": false,
			"error": "Liminal forecast unavailable.",
		}

	var archetype_counts = _collect_active_archetype_counts()
	var entries: Array = []
	var expected_total := 0.0
	var guaranteed_total := 0
	var pressure_archetype_count := 0

	for archetype in LIMINAL_ARCHETYPE_ORDER:
		var count = int(archetype_counts.get(archetype, 0))
		var entry = _evaluate_liminal_archetype_pressure(archetype, count)
		entries.append(entry)
		expected_total += float(entry.get("expected_spawns", 0.0))
		guaranteed_total += int(entry.get("guaranteed_spawns", 0))
		if int(entry.get("over_safe", 0)) > 0:
			pressure_archetype_count += 1

	var hud_level = _resolve_liminal_hud_level(expected_total)
	return {
		"ok": true,
		"safe_count": LIMINAL_FORECAST_SAFE_COUNT,
		"step_size": LIMINAL_FORECAST_STEP_GUESTS,
		"loop_size": LIMINAL_FORECAST_LOOP_GUESTS,
		"totals": {
			"guests": int(state.guests.size()),
			"expected_spawns": expected_total,
			"guaranteed_spawns": guaranteed_total,
			"pressure_archetypes": pressure_archetype_count,
		},
		"archetypes": entries,
		"hud_level": hud_level,
	}


## What accepting a booking would do to liminal pressure for its archetype.
##
## This is the game's central trade (DESIGN.md): income now, spawn odds tonight.
## CampMail shows it at the moment of decision so the player is taking a known risk
## rather than being ambushed by one.
func get_liminal_booking_impact(archetype: String, party_size: int) -> Dictionary:
	_ensure_guest_state_defaults()
	var normalized := _normalize_archetype(archetype)
	var counts := _collect_active_archetype_counts()
	var current := int(counts.get(normalized, 0))
	var after := current + maxi(1, party_size)
	return {
		"archetype": normalized,
		"label": str(LIMINAL_ARCHETYPE_LABELS.get(normalized, normalized)),
		"safe_count": LIMINAL_FORECAST_SAFE_COUNT,
		"current_count": current,
		"after_count": after,
		"current": _evaluate_liminal_archetype_pressure(normalized, current),
		"after": _evaluate_liminal_archetype_pressure(normalized, after),
	}


func _collect_active_archetype_counts() -> Dictionary:
	var counts := {}
	for archetype in LIMINAL_ARCHETYPE_ORDER:
		counts[archetype] = 0

	var state = CoreRoot.get_state()
	if state == null:
		return counts

	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", STATUS_ACTIVE)).to_lower().strip_edges()
		if status != STATUS_ACTIVE and status != STATUS_SLEEP:
			continue
		var archetype = _normalize_archetype(str(guest.get("archetype", ARCHETYPE_QUIET_GUY)))
		counts[archetype] = int(counts.get(archetype, 0)) + 1
	return counts


func _evaluate_liminal_archetype_pressure(archetype: String, count: int) -> Dictionary:
	var safe_count = LIMINAL_FORECAST_SAFE_COUNT
	var over_safe = max(0, count - safe_count)
	var guaranteed_spawns := 0
	var guaranteed_threshold = safe_count + LIMINAL_FORECAST_GUARANTEED_OFFSET
	if count >= guaranteed_threshold:
		guaranteed_spawns = 1 + int(floor(float(count - guaranteed_threshold) / float(LIMINAL_FORECAST_LOOP_GUESTS)))

	var next_small_at = safe_count + LIMINAL_FORECAST_FIRST_STAGE_OFFSET + (guaranteed_spawns * LIMINAL_FORECAST_LOOP_GUESTS)
	var next_medium_at = next_small_at + LIMINAL_FORECAST_STEP_GUESTS
	var next_large_at = next_small_at + (LIMINAL_FORECAST_STEP_GUESTS * 2)
	var next_guaranteed_at = next_small_at + (LIMINAL_FORECAST_STEP_GUESTS * 3)

	var chance_tier = LIMINAL_CHANCE_TIER_NONE
	var chance_probability := 0.0
	if count < next_small_at:
		if guaranteed_spawns == 0 and over_safe > 0:
			chance_tier = LIMINAL_CHANCE_TIER_TINY
			chance_probability = _sample_liminal_tier_probability(LIMINAL_CHANCE_TIER_TINY, count - (safe_count + 1), max(1, LIMINAL_FORECAST_FIRST_STAGE_OFFSET - 2))
	elif count < next_medium_at:
		chance_tier = LIMINAL_CHANCE_TIER_SMALL
		chance_probability = _sample_liminal_tier_probability(LIMINAL_CHANCE_TIER_SMALL, count - next_small_at, LIMINAL_FORECAST_STEP_GUESTS - 1)
	elif count < next_large_at:
		chance_tier = LIMINAL_CHANCE_TIER_MEDIUM
		chance_probability = _sample_liminal_tier_probability(LIMINAL_CHANCE_TIER_MEDIUM, count - next_medium_at, LIMINAL_FORECAST_STEP_GUESTS - 1)
	elif count < next_guaranteed_at:
		chance_tier = LIMINAL_CHANCE_TIER_LARGE
		chance_probability = _sample_liminal_tier_probability(LIMINAL_CHANCE_TIER_LARGE, count - next_large_at, LIMINAL_FORECAST_STEP_GUESTS - 1)

	var expected_spawns = float(guaranteed_spawns) + chance_probability
	return {
		"archetype": archetype,
		"label": str(LIMINAL_ARCHETYPE_LABELS.get(archetype, archetype)),
		"count": count,
		"safe_count": safe_count,
		"over_safe": over_safe,
		"guaranteed_spawns": guaranteed_spawns,
		"chance_tier": chance_tier,
		"chance_probability": chance_probability,
		"expected_spawns": expected_spawns,
		"next_thresholds": {
			"small_at": next_small_at,
			"medium_at": next_medium_at,
			"large_at": next_large_at,
			"guaranteed_at": next_guaranteed_at,
		},
	}


func _sample_liminal_tier_probability(tier: String, stage_offset: int, stage_span: int) -> float:
	var range_any = LIMINAL_CHANCE_RANGES.get(tier, Vector2.ZERO)
	var chance_range: Vector2 = range_any if range_any is Vector2 else Vector2.ZERO
	var t = clampf(float(stage_offset) / float(max(1, stage_span)), 0.0, 1.0)
	return clampf(lerpf(chance_range.x, chance_range.y, t), 0.0, 1.0)


func _resolve_liminal_hud_level(expected_spawns: float) -> int:
	var value = maxf(0.0, expected_spawns)
	if value < float(LIMINAL_HUD_EXPECTED_THRESHOLDS[0]):
		return 0
	if value < float(LIMINAL_HUD_EXPECTED_THRESHOLDS[1]):
		return 1
	if value < float(LIMINAL_HUD_EXPECTED_THRESHOLDS[2]):
		return 2
	if value < float(LIMINAL_HUD_EXPECTED_THRESHOLDS[3]):
		return 3
	return 4


func get_guestrack_overview_data() -> Dictionary:
	_ensure_guest_state_defaults()
	_ensure_guest_lodging_assignments()
	_sync_accommodation_states_from_guests(false)
	var state = CoreRoot.get_state()
	if state == null:
		return {
			"ok": false,
			"error": "GuestRack unavailable.",
		}

	var day = max(1, _last_known_day)
	var hour = clampi(_last_known_hour, 0, 23)
	var minute = clampi(_last_known_minute, 0, 59)
	var now_abs = _absolute_minutes(day, hour, minute)
	var overview = _build_guest_overview()
	var guests: Array = []

	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var checkout_abs = int(guest.get("checkout_abs_minute", now_abs))
		var remain = max(0, checkout_abs - now_abs)
		guests.append({
			"id": int(guest.get("id", -1)),
			"name": str(guest.get("name", "Guest")),
			"archetype": _normalize_archetype(str(guest.get("archetype", ARCHETYPE_QUIET_GUY))),
			"status": str(guest.get("status", STATUS_ACTIVE)),
			"beds_used": max(1, int(guest.get("beds_used", 1))),
			"daily_income": max(1, int(guest.get("daily_income", 1))),
			"checkout_abs_minute": checkout_abs,
			"remaining_minutes": remain,
			"remaining_label": _format_duration(remain),
		})

	guests.sort_custom(func(a, b):
		var da = a if a is Dictionary else {}
		var db = b if b is Dictionary else {}
		var checkout_a = int(da.get("checkout_abs_minute", 0))
		var checkout_b = int(db.get("checkout_abs_minute", 0))
		if checkout_a == checkout_b:
			return int(da.get("id", 0)) < int(db.get("id", 0))
		return checkout_a < checkout_b
	)

	return {
		"ok": true,
		"day": day,
		"hour": hour,
		"minute": minute,
		"overview": overview,
		"guests": guests,
		"liminal_forecast": get_liminal_forecast_data(),
	}


func get_guestrack_text() -> String:
	var data = get_guestrack_overview_data()
	if not bool(data.get("ok", false)):
		return str(data.get("error", "GuestRack unavailable."))

	var day = int(data.get("day", 1))
	var hour = clampi(int(data.get("hour", 0)), 0, 23)
	var minute = clampi(int(data.get("minute", 0)), 0, 59)
	var overview_any = data.get("overview", {})
	var overview: Dictionary = overview_any if overview_any is Dictionary else {}

	var lines: Array[String] = []
	lines.append("GuestRack v0.3 (instant check-in mode)")
	lines.append("Day %d  %02d:%02d" % [day, hour, minute])
	lines.append("Beds capacity:%d  occupied:%d  free:%d" % [
		int(overview.get("capacity", 0)),
		int(overview.get("occupied", 0)),
		int(overview.get("free", 0)),
	])
	lines.append("----------------------------------------")

	var guests_any = data.get("guests", [])
	var guests_sorted: Array = guests_any if guests_any is Array else []
	if guests_sorted.is_empty():
		lines.append("No active stays.")
		return "\n".join(lines)

	for guest_any in guests_sorted:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		lines.append(
			"#%d %s | %s | beds:%d | income/day:$%d | left:%s" % [
				int(guest.get("id", -1)),
				str(guest.get("name", "Guest")),
				str(guest.get("archetype", ARCHETYPE_QUIET_GUY)),
				max(1, int(guest.get("beds_used", 1))),
				max(1, int(guest.get("daily_income", 1))),
				str(guest.get("remaining_label", "0m")),
			]
		)

	return "\n".join(lines)


func get_recent_reviews(limit: int = 6) -> Array:
	var state = CoreRoot.get_state()
	if state == null:
		return []
	var max_items = max(0, limit)
	var out: Array = []
	for i in range(state.guest_reviews.size() - 1, -1, -1):
		out.append(state.guest_reviews[i])
		if out.size() >= max_items:
			break
	return out


func get_accommodation_guest_visuals_by_coord(coord: Vector2i) -> Array:
	_ensure_guest_state_defaults()
	_ensure_guest_lodging_assignments()
	var accommodations = _collect_current_accommodations()
	var slot_lookup = _build_guest_slot_lookup(accommodations)
	var acc_key = _coord_key(coord)
	if not slot_lookup.has(acc_key):
		return []
	var entries_any = slot_lookup[acc_key]
	var entries: Array = entries_any if entries_any is Array else []
	return entries.duplicate(true)


func get_accommodation_states() -> Dictionary:
	_ensure_guest_lodging_assignments()
	_sync_accommodation_states_from_guests(false)
	var state = CoreRoot.get_state()
	if state == null or not (state.accommodation_states is Dictionary):
		return {}
	return (state.accommodation_states as Dictionary).duplicate(true)


func _is_guest_in_stay_status(status: String) -> bool:
	return status == STATUS_ACTIVE or status == STATUS_SLEEP


func _normalize_archetype(raw: String) -> String:
	var normalized = raw.to_lower().strip_edges()
	if normalized.is_empty():
		return ARCHETYPE_QUIET_GUY
	normalized = normalized.replace("-", "_")
	if ARCHETYPE_ALIASES.has(normalized):
		return str(ARCHETYPE_ALIASES[normalized])
	if normalized == ARCHETYPE_QUIET_GUY or normalized == ARCHETYPE_DRUNK or normalized == ARCHETYPE_CHEAP_CHICK:
		return normalized
	return ARCHETYPE_QUIET_GUY


func _sprite_path_for_archetype(archetype: String) -> String:
	var canonical = _normalize_archetype(archetype)
	return str(GUEST_SPRITE_PATHS.get(canonical, GUEST_SPRITE_PATHS[ARCHETYPE_QUIET_GUY]))


func _canonical_accommodation_building_type(building_type: String) -> String:
	var normalized = building_type.strip_edges().to_lower()
	if normalized == "tent":
		return "tent_1"
	if normalized == "cabin":
		return "cabin_1"
	return normalized


func _collect_current_accommodations() -> Dictionary:
	var out: Dictionary = {}
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return out

	var seen_roots: Dictionary = {}
	for coord_any in state.grid.cells.keys():
		if not (coord_any is Vector2i):
			continue
		var coord: Vector2i = coord_any
		var data_any = state.grid.cells[coord_any]
		if not (data_any is Dictionary):
			continue
		var data: Dictionary = data_any
		var building_type = _canonical_accommodation_building_type(str(data.get("type", "")))
		var cap = _capacity_for_building_type(building_type)
		if cap <= 0:
			continue
		var root_any = data.get("root_coord", coord)
		var root_coord = root_any if root_any is Vector2i else coord
		var key = _coord_key(root_coord)
		if seen_roots.has(key):
			continue
		seen_roots[key] = true
		out[key] = {
			"key": key,
			"coord": root_coord,
			"building_type": building_type,
			"capacity": cap,
		}
	return out


func _get_guest_by_id(guest_id: int) -> Dictionary:
	var state = CoreRoot.get_state()
	if state == null:
		return {}
	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		if int(guest.get("id", -1)) == guest_id:
			return guest
	return {}


func _ensure_guest_lodging_assignments() -> bool:
	var state = CoreRoot.get_state()
	if state == null:
		return false

	var accommodations = _collect_current_accommodations()
	var occupancy: Dictionary = {}
	var changed := false

	# Pass 1: keep currently valid, non-overlapping slots.
	for i in range(state.guests.size()):
		var guest_any = state.guests[i]
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", STATUS_ACTIVE)).to_lower().strip_edges()
		var current_slots_any = guest.get("lodging_slots", [])
		var current_slots: Array = current_slots_any if current_slots_any is Array else []
		var filtered_slots: Array = []

		if _is_guest_in_stay_status(status):
			var desired = max(1, int(guest.get("beds_used", guest.get("party_size", 1))))
			for slot_any in current_slots:
				if not (slot_any is Dictionary):
					continue
				var slot = _normalize_guest_slot(slot_any as Dictionary, accommodations)
				if slot.is_empty():
					continue
				var acc_key = str(slot.get("accommodation_key", ""))
				var slot_index = int(slot.get("slot_index", -1))
				if _is_slot_taken(occupancy, acc_key, slot_index):
					continue
				_mark_slot_taken(occupancy, acc_key, slot_index)
				filtered_slots.append(slot)
				if filtered_slots.size() >= desired:
					break
		if current_slots != filtered_slots:
			guest["lodging_slots"] = filtered_slots
			state.guests[i] = guest
			changed = true
		else:
			state.guests[i] = guest

	# Pass 2: allocate missing slots while keeping current placements stable.
	for i in range(state.guests.size()):
		var guest_any = state.guests[i]
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", STATUS_ACTIVE)).to_lower().strip_edges()
		if not _is_guest_in_stay_status(status):
			continue

		var desired = max(1, int(guest.get("beds_used", guest.get("party_size", 1))))
		var slots_any = guest.get("lodging_slots", [])
		var slots: Array = slots_any if slots_any is Array else []
		var missing = max(0, desired - slots.size())
		if missing <= 0:
			continue

		var preferred_keys: Array = []
		for slot_any in slots:
			if slot_any is Dictionary:
				var key = str((slot_any as Dictionary).get("accommodation_key", "")).strip_edges()
				if not key.is_empty() and not preferred_keys.has(key):
					preferred_keys.append(key)

		var added_slots = _allocate_free_lodging_slots(missing, accommodations, occupancy, preferred_keys)
		if added_slots.is_empty():
			continue
		slots.append_array(added_slots)
		guest["lodging_slots"] = slots
		state.guests[i] = guest
		changed = true

	return changed


func _allocate_free_lodging_slots(
	count: int,
	accommodations: Dictionary,
	occupancy: Dictionary,
	preferred_keys: Array = []
) -> Array:
	var wanted = max(0, count)
	if wanted <= 0 or accommodations.is_empty():
		return []

	var preferred_lookup: Dictionary = {}
	for key_any in preferred_keys:
		var key = str(key_any)
		if not key.is_empty():
			preferred_lookup[key] = true

	var candidates: Array = []
	for key_any in accommodations.keys():
		var key = str(key_any)
		var acc_any = accommodations[key]
		if not (acc_any is Dictionary):
			continue
		var acc: Dictionary = acc_any
		var cap = max(1, int(acc.get("capacity", 1)))
		var used = _used_slots_for_key(occupancy, key)
		var free = max(0, cap - used)
		if free <= 0:
			continue
		candidates.append({
			"key": key,
			"coord": acc.get("coord", Vector2i.ZERO),
			"building_type": str(acc.get("building_type", "")),
			"capacity": cap,
			"used": used,
			"free": free,
			"preferred": 1 if preferred_lookup.has(key) else 0,
		})

	candidates.sort_custom(func(a, b):
		var da = a if a is Dictionary else {}
		var db = b if b is Dictionary else {}
		var preferred_a = int(da.get("preferred", 0))
		var preferred_b = int(db.get("preferred", 0))
		if preferred_a != preferred_b:
			return preferred_a > preferred_b
		var used_a = int(da.get("used", 0))
		var used_b = int(db.get("used", 0))
		if (used_a > 0) != (used_b > 0):
			return used_a > 0
		var free_a = int(da.get("free", 0))
		var free_b = int(db.get("free", 0))
		if free_a != free_b:
			return free_a > free_b
		var cap_a = int(da.get("capacity", 0))
		var cap_b = int(db.get("capacity", 0))
		if cap_a != cap_b:
			return cap_a > cap_b
		return str(da.get("key", "")) < str(db.get("key", ""))
	)

	var out: Array = []
	for candidate_any in candidates:
		if not (candidate_any is Dictionary):
			continue
		var candidate: Dictionary = candidate_any
		var key = str(candidate.get("key", ""))
		var cap = max(1, int(candidate.get("capacity", 1)))
		for slot_index in range(cap):
			if _is_slot_taken(occupancy, key, slot_index):
				continue
			_mark_slot_taken(occupancy, key, slot_index)
			out.append({
				"accommodation_key": key,
				"coord": candidate.get("coord", Vector2i.ZERO),
				"building_type": str(candidate.get("building_type", "")),
				"slot_index": slot_index,
			})
			if out.size() >= wanted:
				return out
	return out


func _is_slot_taken(occupancy: Dictionary, acc_key: String, slot_index: int) -> bool:
	if not occupancy.has(acc_key):
		return false
	var slots_any = occupancy[acc_key]
	if not (slots_any is Dictionary):
		return false
	return (slots_any as Dictionary).has(slot_index)


func _mark_slot_taken(occupancy: Dictionary, acc_key: String, slot_index: int) -> void:
	if not occupancy.has(acc_key) or not (occupancy[acc_key] is Dictionary):
		occupancy[acc_key] = {}
	var slots: Dictionary = occupancy[acc_key]
	slots[slot_index] = true
	occupancy[acc_key] = slots


func _used_slots_for_key(occupancy: Dictionary, acc_key: String) -> int:
	if not occupancy.has(acc_key):
		return 0
	var slots_any = occupancy[acc_key]
	if not (slots_any is Dictionary):
		return 0
	return (slots_any as Dictionary).size()


func _normalize_guest_slot(slot: Dictionary, accommodations: Dictionary) -> Dictionary:
	var acc_key = str(slot.get("accommodation_key", "")).strip_edges()
	var coord_any = slot.get("coord", null)
	var coord = coord_any if coord_any is Vector2i else Vector2i.ZERO
	if acc_key.is_empty() and coord_any is Vector2i:
		acc_key = _coord_key(coord)
	if acc_key.is_empty():
		return {}
	if not accommodations.has(acc_key):
		return {}
	var acc_any = accommodations[acc_key]
	if not (acc_any is Dictionary):
		return {}
	var acc: Dictionary = acc_any
	var cap = max(1, int(acc.get("capacity", 1)))
	var slot_index = int(slot.get("slot_index", 0))
	if slot_index < 0 or slot_index >= cap:
		return {}
	return {
		"accommodation_key": acc_key,
		"coord": acc.get("coord", Vector2i.ZERO),
		"building_type": str(acc.get("building_type", "")),
		"slot_index": slot_index,
	}


func _build_guest_slot_lookup(accommodations: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var state = CoreRoot.get_state()
	if state == null:
		return out

	var used_slots: Dictionary = {}
	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", STATUS_ACTIVE)).to_lower().strip_edges()
		if not _is_guest_in_stay_status(status):
			continue
		var guest_id = int(guest.get("id", -1))
		var archetype = _normalize_archetype(str(guest.get("archetype", ARCHETYPE_QUIET_GUY)))
		var sprite_path = _sprite_path_for_archetype(archetype)
		var guest_name = str(guest.get("name", "Guest"))
		var slots_any = guest.get("lodging_slots", [])
		var slots: Array = slots_any if slots_any is Array else []
		for slot_any in slots:
			if not (slot_any is Dictionary):
				continue
			var normalized = _normalize_guest_slot(slot_any as Dictionary, accommodations)
			if normalized.is_empty():
				continue
			var acc_key = str(normalized.get("accommodation_key", ""))
			var slot_index = int(normalized.get("slot_index", -1))
			if _is_slot_taken(used_slots, acc_key, slot_index):
				continue
			_mark_slot_taken(used_slots, acc_key, slot_index)
			if not out.has(acc_key):
				out[acc_key] = []
			var list_any = out[acc_key]
			var list: Array = list_any if list_any is Array else []
			list.append({
				"guest_id": guest_id,
				"guest_name": guest_name,
				"archetype": archetype,
				"sprite_path": sprite_path,
				"slot_index": slot_index,
			})
			out[acc_key] = list

	for key_any in out.keys():
		var key = str(key_any)
		var entries_any = out[key]
		if not (entries_any is Array):
			continue
		var entries: Array = entries_any
		entries.sort_custom(func(a, b):
			var da = a if a is Dictionary else {}
			var db = b if b is Dictionary else {}
			var slot_a = int(da.get("slot_index", 0))
			var slot_b = int(db.get("slot_index", 0))
			if slot_a == slot_b:
				return int(da.get("guest_id", 0)) < int(db.get("guest_id", 0))
			return slot_a < slot_b
		)
		out[key] = entries

	return out


func _sync_accommodation_states_from_guests(emit_signals: bool = true) -> bool:
	var state = CoreRoot.get_state()
	if state == null:
		return false
	if state.accommodation_states == null or not (state.accommodation_states is Dictionary):
		state.accommodation_states = {}

	var previous: Dictionary = state.accommodation_states
	var accommodations = _collect_current_accommodations()
	var slot_lookup = _build_guest_slot_lookup(accommodations)
	var next: Dictionary = {}

	for key_any in accommodations.keys():
		var key = str(key_any)
		var acc_any = accommodations[key]
		if not (acc_any is Dictionary):
			continue
		var acc: Dictionary = acc_any
		var prev_any = previous.get(key, {})
		var prev: Dictionary = prev_any if prev_any is Dictionary else {}
		var slots_any = slot_lookup.get(key, [])
		var slots: Array = slots_any if slots_any is Array else []
		var guest_ids: Array = []
		for slot_any in slots:
			if slot_any is Dictionary:
				guest_ids.append(int((slot_any as Dictionary).get("guest_id", -1)))
		next[key] = {
			"key": key,
			"coord": acc.get("coord", Vector2i.ZERO),
			"root_coord": acc.get("coord", Vector2i.ZERO),
			"building_type": str(acc.get("building_type", "")),
			"capacity": int(acc.get("capacity", 1)),
			"status": str(prev.get("status", "clean")),
			"guest_ids": guest_ids,
			"guest_slots": slots.duplicate(true),
		}

	var changed := false
	var changed_keys: Array = []
	for key_any in next.keys():
		var key = str(key_any)
		if not previous.has(key) or previous[key] != next[key]:
			changed = true
			changed_keys.append(key)
	for key_any in previous.keys():
		var key = str(key_any)
		if not next.has(key):
			changed = true
			changed_keys.append(key)

	state.accommodation_states = next

	if emit_signals and changed and EventBus.has_signal("accommodation_state_changed"):
		for key_any in changed_keys:
			var key = str(key_any)
			if next.has(key):
				var acc_any = next[key]
				if acc_any is Dictionary:
					var acc: Dictionary = acc_any
					var guest_ids_any = acc.get("guest_ids", [])
					var guest_ids: Array = guest_ids_any if guest_ids_any is Array else []
					EventBus.accommodation_state_changed.emit(key, str(acc.get("status", "clean")), guest_ids.size())
			else:
				EventBus.accommodation_state_changed.emit(key, "removed", 0)

	return changed


func _build_review_for_guest(guest: Dictionary, day: int) -> Dictionary:
	var sat = 50.0
	var state = CoreRoot.get_state()
	if state != null:
		sat = float(state.satisfaction)
	var rating_base = int(round(clampf(sat, 0.0, 100.0) / 25.0))
	var rating = clampi(rating_base + _rng.randi_range(-1, 1), 1, 5)

	var text_pool = REVIEW_NEUTRAL
	if rating >= 4:
		text_pool = REVIEW_POSITIVE
	elif rating <= 2:
		text_pool = REVIEW_NEGATIVE
	var review_text = text_pool[_rng.randi_range(0, text_pool.size() - 1)]

	return {
		"guest_id": int(guest.get("id", -1)),
		"name": str(guest.get("name", "Guest")),
		"rating": rating,
		"text": review_text,
		"day": day,
		"stay_nights": int(guest.get("stay_nights", 1)),
	}


func _extract_sender_name(mail: Dictionary) -> String:
	var sender = str(mail.get("from", "Guest"))
	var name_only = sender
	if sender.contains("<"):
		name_only = sender.split("<")[0]
	name_only = name_only.strip_edges()
	if name_only.is_empty():
		name_only = "Guest"
	return name_only


func _parse_time_to_minutes(raw: String, fallback_minutes: int) -> int:
	var normalized = raw.strip_edges()
	if normalized.is_empty():
		return fallback_minutes
	var parts = normalized.split(":")
	if parts.size() < 2:
		return fallback_minutes
	var h = clampi(int(parts[0]), 0, 23)
	var m = clampi(int(parts[1]), 0, 59)
	return h * 60 + m


func _is_night_time(hour: int, minute: int) -> bool:
	var t = float(hour) + (float(minute) / 60.0)
	return t >= float(BALANCE_CONFIG.NIGHT_START_HOUR) or t < float(BALANCE_CONFIG.DAY_START_HOUR)


func _absolute_minutes(day: int, hour: int, minute: int) -> int:
	return _absolute_minutes_from_day_minute(day, hour * 60 + minute)


func _absolute_minutes_from_day_minute(day: int, minute_of_day: int) -> int:
	var d = max(1, day)
	return (d - 1) * 1440 + clampi(minute_of_day, 0, 1439)


func _from_absolute_minutes(total_minutes: int) -> Dictionary:
	var safe = max(0, total_minutes)
	var day = int(floor(float(safe) / 1440.0)) + 1
	var minute_of_day = safe % 1440
	return {
		"day": day,
		"minute_of_day": minute_of_day,
		"hour": int(floor(float(minute_of_day) / 60.0)),
		"minute": int(minute_of_day % 60),
	}


func _format_duration(total_minutes: int) -> String:
	var value = max(0, total_minutes)
	var days = int(floor(float(value) / 1440.0))
	var hours = int(floor(float(value % 1440) / 60.0))
	var minutes = int(value % 60)
	if days > 0:
		return "%dd %02dh %02dm" % [days, hours, minutes]
	if hours > 0:
		return "%02dh %02dm" % [hours, minutes]
	return "%dm" % minutes


func _coord_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]


func _trim_array_history(target: Array, limit: int) -> void:
	var max_len = max(0, limit)
	while target.size() > max_len:
		target.remove_at(0)
