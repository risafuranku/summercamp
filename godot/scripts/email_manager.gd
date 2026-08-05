extends Node
## EmailManager -- runtime mailbox generator.
##
## - Generates customer emails each in-game hour based on hrotfaktor + capacity + occupied beds.
## - Spreads deliveries continuously across the following hour.
## - Keeps spam as extra noise mail (not counted as customer demand).

signal email_received(email: Dictionary)
signal customer_booking_confirmed(email: Dictionary)
signal customer_booking_rejected(email: Dictionary)
signal unread_count_changed(count: int)

const MAIL_TYPE_CUSTOMER := "customer"
const MAIL_TYPE_SPAM := "spam"

const ARCHETYPE_QUIET_GUY := "quiet_guy"
const ARCHETYPE_DRUNK := "drunk"
const ARCHETYPE_CHEAP_CHICK := "cheap_chick"

const MAX_CUSTOMER_EMAILS_PER_HOUR := 9
const MAX_SPAM_EMAILS_PER_HOUR := 4

const CUSTOMER_ARCHETYPES: Dictionary = {
	ARCHETYPE_QUIET_GUY: {
		"label": "Quiet Guy",
		"difficulty": 1,
		"daily_pay": 70,
		"party_min": 1,
		"party_max": 1,
		"stay_min": 1,
		"stay_max": 2,
		"night_trouble_time": "22:40",
	},
	ARCHETYPE_DRUNK: {
		"label": "Drunk",
		"difficulty": 3,
		"daily_pay": 120,
		"party_min": 1,
		"party_max": 2,
		"stay_min": 1,
		"stay_max": 3,
		"night_trouble_time": "00:30",
	},
	ARCHETYPE_CHEAP_CHICK: {
		"label": "Cheap Chick",
		"difficulty": 5,
		"daily_pay": 190,
		"party_min": 2,
		"party_max": 3,
		"stay_min": 2,
		"stay_max": 4,
		"night_trouble_time": "02:20",
	},
}

const FIRST_NAMES_QUIET: Array[String] = [
	"Milan", "Viktor", "Roman", "Daniel", "Petr", "Ondrej", "Adam", "Marek"
]
const FIRST_NAMES_DRUNK: Array[String] = [
	"Radek", "Kuba", "Jarda", "Lukas", "Misa", "Boris", "Patrik", "Tomas"
]
const FIRST_NAMES_CHEAP: Array[String] = [
	"Sarka", "Lenka", "Michaela", "Karolina", "Sona", "Nela", "Bara", "Klara"
]
const LAST_NAMES: Array[String] = [
	"Novak", "Krizek", "Urban", "Bartos", "Kral", "Dvorak", "Janda", "Simek", "Blaha", "Nemec"
]
const MAIL_DOMAINS: Array[String] = [
	"mail.cz", "postbox.eu", "campmail.net", "atlas.cz", "chatmail.cz"
]

const SPAM_SENDERS: Array[String] = [
	"NoFace Media <ads@noface.media>",
	"Storm Warranty Dept <warranty@stormfix.market>",
	"GigaHealth Drips <clinic@gigahealth-market.cc>",
	"Lucky Barrel Lottery <jackpot@barrel-lotto.win>",
	"Night Signal Shop <promo@night-signal.net>",
	"SUPER DEAL BOT <deals@ultra-camp.biz>",
]

const SPAM_SUBJECTS: Array[String] = [
	"Generator warranty expired yesterday",
	"YOUR CAMP WON A FREE BARREL",
	"Delete fatigue in 3 minutes",
	"Mandatory hydration compliance",
	"LIMITED OFFER: SELF-HEATING PILLOW",
	"Infrared crow repellent bundle",
]

const SPAM_BODIES: Array[String] = [
	"Renew now to avoid legal thunder and paperwork.\n\nCLICK HERE NOW: http://totally-safe-link.invalid/",
	"Winner ID: CAMP-9981.\n\nPay handling fee and receive one mystery barrel.",
	"Our intern verified this personally on one shift.\n\nWorks best if never removed.",
	"Your camp appears vitamin-deficient from orbit telemetry.\n\nStart subscription now.",
	"Buy two pillows and get one pocket fog machine free.\n\nPerfect for suspicious cabins.",
	"Device emits ultrasonic tones that birds and inspectors hate.",
]

const CUSTOMER_SUBJECT_VARIANTS: Array[String] = [
	"Booking request: %s / %d beds / %d night(s)",
	"Need place tonight: %s / %d beds / %d night(s)",
	"Camp booking: %s (%d beds, %d nights)",
]

const MAIL_TO_ADDRESS := "camp.reception@camp.local"

## All delivered emails, newest last.
var inbox: Array[Dictionary] = []

var _scheduled_mails: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _next_runtime_mail_id: int = 1
var _last_tick_signature: String = ""
var _last_hourly_roll_signature: String = ""


func _ready() -> void:
	_rng.randomize()
	reset_runtime(false)
	if EventBus.has_signal("time_tick"):
		var tick_cb := Callable(self, "_on_time_tick")
		if not EventBus.time_tick.is_connected(tick_cb):
			EventBus.time_tick.connect(tick_cb)


func reset_runtime(clear_inbox: bool = true) -> void:
	_scheduled_mails.clear()
	_last_tick_signature = ""
	_last_hourly_roll_signature = ""
	_next_runtime_mail_id = 1
	if clear_inbox:
		inbox.clear()
	unread_count_changed.emit(get_unread_count())


func push_system_mail(seed_data: Dictionary) -> Dictionary:
	var mail := _new_mail_dict(seed_data)
	var mail_type := str(mail.get("type", "system")).to_lower().strip_edges()
	if mail_type.is_empty():
		mail_type = "system"
	mail["type"] = mail_type
	mail["sender"] = str(mail.get("sender", mail.get("from", "System"))).strip_edges()
	mail["from"] = str(mail.get("from", mail.get("sender", "System"))).strip_edges()
	if str(mail.get("from", "")).is_empty():
		mail["from"] = "System"
	if str(mail.get("sender", "")).is_empty():
		mail["sender"] = str(mail.get("from", "System"))
	mail["subject"] = str(mail.get("subject", "(no subject)")).strip_edges()
	if str(mail.get("subject", "")).is_empty():
		mail["subject"] = "(no subject)"
	mail["body"] = str(mail.get("body", "")).strip_edges()
	var fallback_day := 1
	if CoreRoot != null and CoreRoot.has_method("get_day"):
		fallback_day = max(1, int(CoreRoot.get_day()))
	mail["day"] = max(1, int(mail.get("day", fallback_day)))
	var raw_time := str(mail.get("time", "00:00")).strip_edges()
	mail["time"] = raw_time if not raw_time.is_empty() else "00:00"
	mail["_delivered"] = true
	inbox.append(mail)
	email_received.emit(mail)
	if EventBus.has_signal("email_received"):
		EventBus.email_received.emit(mail)
	unread_count_changed.emit(get_unread_count())
	return mail


func export_runtime_state() -> Dictionary:
	return {
		"inbox": _sanitize_mail_array(inbox),
		"scheduled_mails": _sanitize_scheduled_mail_array(_scheduled_mails),
		"next_runtime_mail_id": max(1, int(_next_runtime_mail_id)),
		"last_tick_signature": str(_last_tick_signature),
		"last_hourly_roll_signature": str(_last_hourly_roll_signature),
	}


func import_runtime_state(data: Dictionary) -> void:
	reset_runtime(true)
	if data.is_empty():
		return

	inbox = _sanitize_mail_array(data.get("inbox", []))
	_scheduled_mails = _sanitize_scheduled_mail_array(data.get("scheduled_mails", []))
	_last_tick_signature = str(data.get("last_tick_signature", ""))
	_last_hourly_roll_signature = str(data.get("last_hourly_roll_signature", ""))

	var max_seen_id: int = _max_runtime_mail_id(inbox, _scheduled_mails)
	var loaded_next_id: int = maxi(1, int(data.get("next_runtime_mail_id", max_seen_id + 1)))
	_next_runtime_mail_id = maxi(loaded_next_id, max_seen_id + 1)
	unread_count_changed.emit(get_unread_count())


func _sanitize_mail_array(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for mail_any in value:
		var safe_mail := _sanitize_mail_dict(mail_any)
		if safe_mail.is_empty():
			continue
		out.append(safe_mail)
	return out


func _sanitize_scheduled_mail_array(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for entry_any in value:
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var safe_mail := _sanitize_mail_dict(entry.get("mail", {}))
		if safe_mail.is_empty():
			continue
		safe_mail["_delivered"] = false
		out.append({
			"deliver_abs": max(0, int(entry.get("deliver_abs", 0))),
			"mail": safe_mail,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("deliver_abs", 0)) < int(b.get("deliver_abs", 0))
	)
	return out


func _sanitize_mail_dict(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var mail := (value as Dictionary).duplicate(true)
	var mail_type := str(mail.get("type", "")).to_lower().strip_edges()
	if mail_type.is_empty():
		mail_type = MAIL_TYPE_SPAM if bool(mail.get("_is_extra_spam", false)) else MAIL_TYPE_CUSTOMER
	mail["type"] = mail_type
	mail["_runtime_id"] = max(1, int(mail.get("_runtime_id", 1)))
	mail["_delivered"] = bool(mail.get("_delivered", false))
	mail["_read"] = bool(mail.get("_read", false))
	mail["_actioned"] = bool(mail.get("_actioned", false))
	mail["day"] = max(1, int(mail.get("day", 1)))
	mail["time"] = str(mail.get("time", "00:00"))
	return mail


func _max_runtime_mail_id(inbox_items: Array[Dictionary], scheduled_items: Array[Dictionary]) -> int:
	var max_id := 0
	for mail in inbox_items:
		max_id = max(max_id, int(mail.get("_runtime_id", 0)))
	for entry in scheduled_items:
		var mail_any = entry.get("mail", {})
		if mail_any is Dictionary:
			max_id = max(max_id, int((mail_any as Dictionary).get("_runtime_id", 0)))
	return max_id


func _on_time_tick(hour: int, minute: int) -> void:
	var day: int = max(1, int(CoreRoot.get_day()))
	var safe_hour := clampi(hour, 0, 23)
	var safe_minute := clampi(minute, 0, 59)
	var tick_signature = "%d:%02d:%02d" % [day, safe_hour, safe_minute]
	if tick_signature == _last_tick_signature:
		return
	_last_tick_signature = tick_signature

	var now_abs = _absolute_minutes(day, safe_hour, safe_minute)
	_deliver_due_mails(now_abs)

	if safe_minute == 0:
		var roll_signature = "%d:%02d" % [day, safe_hour]
		if roll_signature != _last_hourly_roll_signature:
			_last_hourly_roll_signature = roll_signature
			_run_hourly_roll(day, safe_hour, now_abs)


func _run_hourly_roll(day: int, hour: int, base_abs: int) -> void:
	var bed_metrics = _collect_bed_metrics()
	var hrotfaktor = _refresh_hrotfaktor(bed_metrics)
	var intensity = _roll_intensity(bed_metrics, hrotfaktor)

	var customer_count = _roll_customer_mail_count(bed_metrics, hrotfaktor)
	if customer_count > 0:
		var archetypes = _roll_archetype_batch(customer_count, intensity)
		var offsets = _spread_offsets(customer_count, 2, 58)
		for i in range(customer_count):
			var archetype_id = archetypes[i] if i < archetypes.size() else ARCHETYPE_QUIET_GUY
			var mail = _build_customer_mail(archetype_id, day, hour)
			var deliver_abs = base_abs + offsets[i]
			_schedule_mail_abs(deliver_abs, mail)

	var spam_count = _roll_spam_mail_count(bed_metrics, hrotfaktor)
	if spam_count > 0:
		var spam_offsets = _spread_offsets(spam_count, 1, 58)
		for i in range(spam_count):
			var spam_mail = _build_spam_mail(day, hour)
			_schedule_mail_abs(base_abs + spam_offsets[i], spam_mail)


func _collect_bed_metrics() -> Dictionary:
	if GuestManager != null and GuestManager.has_method("get_bed_metrics"):
		var metrics_any = GuestManager.get_bed_metrics()
		if metrics_any is Dictionary:
			var metrics: Dictionary = metrics_any
			if metrics.has("capacity") and metrics.has("occupied"):
				var capacity = max(0, int(metrics.get("capacity", 0)))
				var occupied = clampi(int(metrics.get("occupied", 0)), 0, capacity)
				var occupancy_ratio = 0.0 if capacity <= 0 else clampf(float(occupied) / float(capacity), 0.0, 1.0)
				return {
					"capacity": capacity,
					"occupied": occupied,
					"free": max(0, capacity - occupied),
					"occupied_ratio": occupancy_ratio,
				}

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
		var root_any = data.get("root_coord", coord)
		var root_coord = root_any if root_any is Vector2i else coord
		var instance_id = str(data.get("id", "")).strip_edges()
		var unique_key = "id:%s" % instance_id if not instance_id.is_empty() else "root:%s:%s" % [_coord_key(root_coord), building_type]
		if seen_entries.has(unique_key):
			continue
		seen_entries[unique_key] = true
		capacity_total += _capacity_for_building_type(building_type)

	var occupied_beds := 0
	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", "active")).to_lower().strip_edges()
		if status != "active" and status != "sleep":
			continue
		occupied_beds += max(1, int(guest.get("beds_used", guest.get("party_size", 1))))

	var capped_occupied = clampi(occupied_beds, 0, capacity_total)
	var occupied_ratio = 0.0 if capacity_total <= 0 else clampf(float(capped_occupied) / float(capacity_total), 0.0, 1.0)
	return {
		"capacity": capacity_total,
		"occupied": capped_occupied,
		"free": max(0, capacity_total - capped_occupied),
		"occupied_ratio": occupied_ratio,
	}


func _capacity_for_building_type(building_type: String) -> int:
	var t = building_type.to_lower().strip_edges()
	if t.begins_with("tent"):
		return 1
	if t.begins_with("cabin"):
		return 2
	return 0


func _refresh_hrotfaktor(bed_metrics: Dictionary) -> float:
	var state = CoreRoot.get_state()
	if state == null:
		return 0.0

	var current_hrot = clampf(float(state.hrotfaktor), 0.0, 1.0)
	var capacity = max(0, int(bed_metrics.get("capacity", 0)))
	var occupied_ratio = clampf(float(bed_metrics.get("occupied_ratio", 0.0)), 0.0, 1.0)
	var capacity_factor = clampf(float(capacity) / 24.0, 0.0, 1.0)
	var difficulty_pressure = _active_guest_difficulty_pressure()
	var inbox_pressure = clampf(float(_count_unactioned_customer_mails()) / 12.0, 0.0, 1.0)

	var target_hrot = clampf(
		0.12 + occupied_ratio * 0.32 + capacity_factor * 0.20 + difficulty_pressure * 0.28 + inbox_pressure * 0.08,
		0.0,
		1.0
	)
	var next_hrot = clampf(lerpf(current_hrot, target_hrot, 0.52), 0.0, 1.0)
	if absf(next_hrot - current_hrot) > 0.004 and CoreRoot != null and CoreRoot.has_method("apply_changes"):
		CoreRoot.apply_changes({"hrotfaktor": next_hrot})
	return next_hrot


func _active_guest_difficulty_pressure() -> float:
	var state = CoreRoot.get_state()
	if state == null:
		return 0.0
	var sum_norm := 0.0
	var count := 0
	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var status = str(guest.get("status", "active")).to_lower().strip_edges()
		if status != "active" and status != "sleep":
			continue
		var diff = clampi(int(guest.get("booking_difficulty", guest.get("difficulty", 1))), 1, 5)
		sum_norm += float(diff - 1) / 4.0
		count += 1
	if count <= 0:
		return 0.0
	return clampf(sum_norm / float(count), 0.0, 1.0)


func _count_unactioned_customer_mails() -> int:
	var count := 0
	for mail in inbox:
		if _is_customer_mail(mail) and not bool(mail.get("_actioned", false)):
			count += 1
	return count


func _roll_intensity(bed_metrics: Dictionary, hrotfaktor: float) -> float:
	var capacity = max(0, int(bed_metrics.get("capacity", 0)))
	var occupancy = clampf(float(bed_metrics.get("occupied_ratio", 0.0)), 0.0, 1.0)
	var cap_factor = clampf(float(capacity) / 20.0, 0.0, 1.0)
	return clampf(cap_factor * 0.35 + occupancy * 0.35 + clampf(hrotfaktor, 0.0, 1.0) * 0.30, 0.0, 1.0)


func _roll_customer_mail_count(bed_metrics: Dictionary, hrotfaktor: float) -> int:
	var capacity = max(0, int(bed_metrics.get("capacity", 0)))
	if capacity <= 0:
		return 0
	var occupancy = clampf(float(bed_metrics.get("occupied_ratio", 0.0)), 0.0, 1.0)
	var intensity = _roll_intensity(bed_metrics, hrotfaktor)
	var soft_cap = clampi(int(round(1.0 + float(capacity) * 0.35)), 1, MAX_CUSTOMER_EMAILS_PER_HOUR)
	var base_count = int(round(lerpf(1.0, float(soft_cap), intensity)))
	var noisy_count = base_count + _rng.randi_range(-1, 2)
	if occupancy > 0.90:
		noisy_count -= 1
	if capacity <= 2:
		noisy_count = min(noisy_count, 2)
	return clampi(noisy_count, 0, soft_cap)


func _roll_spam_mail_count(bed_metrics: Dictionary, hrotfaktor: float) -> int:
	var capacity = max(0, int(bed_metrics.get("capacity", 0)))
	if capacity <= 0:
		return 0
	var intensity = _roll_intensity(bed_metrics, hrotfaktor)
	var base = int(round(lerpf(0.0, float(MAX_SPAM_EMAILS_PER_HOUR - 1), 0.25 + intensity * 0.75)))
	base += _rng.randi_range(0, 1)
	return clampi(base, 0, MAX_SPAM_EMAILS_PER_HOUR)


func _roll_archetype_batch(count: int, intensity: float) -> Array[String]:
	var out: Array[String] = []
	if count <= 0:
		return out

	var archetype_ids: Array[String] = [ARCHETYPE_QUIET_GUY, ARCHETYPE_DRUNK, ARCHETYPE_CHEAP_CHICK]
	var weights: Dictionary = {
		ARCHETYPE_QUIET_GUY: clampf(lerpf(0.72, 0.20, intensity), 0.18, 0.80),
		ARCHETYPE_DRUNK: clampf(lerpf(0.22, 0.36, intensity), 0.14, 0.48),
		ARCHETYPE_CHEAP_CHICK: clampf(lerpf(0.06, 0.44, intensity), 0.02, 0.55),
	}
	var counts: Dictionary = {
		ARCHETYPE_QUIET_GUY: 0,
		ARCHETYPE_DRUNK: 0,
		ARCHETYPE_CHEAP_CHICK: 0,
	}
	var max_share = maxi(1, int(ceil(float(count) * 0.62)))

	for _i in range(count):
		var pick = _pick_weighted_archetype(archetype_ids, weights)
		if int(counts.get(pick, 0)) >= max_share:
			pick = _pick_lowest_count_archetype(archetype_ids, counts)
		counts[pick] = int(counts.get(pick, 0)) + 1
		out.append(pick)

	out.shuffle()
	return out


func _pick_weighted_archetype(archetypes: Array[String], weights: Dictionary) -> String:
	var total_weight := 0.0
	for id in archetypes:
		total_weight += maxf(0.0, float(weights.get(id, 0.0)))
	if total_weight <= 0.0:
		return archetypes[0]

	var roll = _rng.randf() * total_weight
	var cursor := 0.0
	for id in archetypes:
		cursor += maxf(0.0, float(weights.get(id, 0.0)))
		if roll <= cursor:
			return id
	return archetypes[archetypes.size() - 1]


func _pick_lowest_count_archetype(archetypes: Array[String], counts: Dictionary) -> String:
	var best = archetypes[0]
	var best_count = int(counts.get(best, 0))
	for id in archetypes:
		var c = int(counts.get(id, 0))
		if c < best_count:
			best = id
			best_count = c
	return best


func _spread_offsets(count: int, min_offset: int, max_offset: int) -> Array[int]:
	var out: Array[int] = []
	if count <= 0:
		return out
	var safe_min = mini(min_offset, max_offset)
	var safe_max = maxi(min_offset, max_offset)
	var pool: Array[int] = []
	for offset in range(safe_min, safe_max + 1):
		pool.append(offset)
	for i in range(pool.size() - 1, 0, -1):
		var j = _rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	for i in range(count):
		if i < pool.size():
			out.append(pool[i])
		else:
			out.append(_rng.randi_range(safe_min, safe_max))
	out.sort()
	return out


func _build_customer_mail(archetype_id: String, day: int, hour: int) -> Dictionary:
	var cfg_any = CUSTOMER_ARCHETYPES.get(archetype_id, CUSTOMER_ARCHETYPES[ARCHETYPE_QUIET_GUY])
	var cfg: Dictionary = cfg_any if cfg_any is Dictionary else CUSTOMER_ARCHETYPES[ARCHETYPE_QUIET_GUY]

	var party_min = max(1, int(cfg.get("party_min", 1)))
	var party_max = max(party_min, int(cfg.get("party_max", party_min)))
	var party_size = _rng.randi_range(party_min, party_max)
	var stay_min = max(1, int(cfg.get("stay_min", 1)))
	var stay_max = max(stay_min, int(cfg.get("stay_max", stay_min)))
	var stay_nights = _rng.randi_range(stay_min, stay_max)
	var difficulty = clampi(int(cfg.get("difficulty", 1)), 1, 5)
	var night_trouble_time = str(cfg.get("night_trouble_time", "00:30"))

	var lead_name = _random_guest_name(archetype_id)
	var guest_names = _build_guest_name_list(lead_name, party_size, archetype_id)
	var sender = "%s <%s@%s>" % [lead_name, _slugify_name(lead_name), _pick_random(MAIL_DOMAINS)]
	var arrival_time = _roll_arrival_time(archetype_id)

	var base_daily_pay = max(25, int(cfg.get("daily_pay", 80))) * party_size
	var variance = maxi(8, int(round(float(base_daily_pay) * 0.18)))
	var daily_total = max(30, base_daily_pay + _rng.randi_range(-variance, variance))

	var subject_template = _pick_random(CUSTOMER_SUBJECT_VARIANTS)
	var archetype_label = str(cfg.get("label", "Customer"))
	var subject = subject_template % [archetype_label, party_size, stay_nights]

	var body_lines: Array[String] = []
	body_lines.append("Hello reception,")
	body_lines.append("")
	body_lines.append("Need %d bed(s) for %d night(s)." % [party_size, stay_nights])
	body_lines.append("Archetype: %s" % archetype_label)
	body_lines.append("Arrival: %s" % arrival_time)
	body_lines.append("Total payment per day: $%d" % daily_total)
	body_lines.append("Night trouble window: around %s" % night_trouble_time)
	body_lines.append("")
	body_lines.append("Accept or refuse.")
	body_lines.append("")
	body_lines.append("- %s" % lead_name)

	return _new_mail_dict({
		"sender": sender,
		"from": sender,
		"subject": subject,
		"body": "\n".join(body_lines),
		"day": day,
		"time": "%02d:00" % clampi(hour, 0, 23),
		"type": MAIL_TYPE_CUSTOMER,
		"archetype": archetype_id,
		"difficulty": difficulty,
		"guests": party_size,
		"party_size": party_size,
		"nights": stay_nights,
		"stay_nights": stay_nights,
		"arrival_time": arrival_time,
		"daily_total": daily_total,
		"night_trouble_time": night_trouble_time,
		"guest_name": lead_name,
		"guest_names": guest_names,
	})


func _build_spam_mail(day: int, hour: int) -> Dictionary:
	var sender = _pick_random(SPAM_SENDERS)
	var subject = _pick_random(SPAM_SUBJECTS)
	var body = _pick_random(SPAM_BODIES)
	return _new_mail_dict({
		"sender": sender,
		"from": sender,
		"subject": subject,
		"body": body,
		"day": day,
		"time": "%02d:00" % clampi(hour, 0, 23),
		"type": MAIL_TYPE_SPAM,
		"_is_extra_spam": true,
	})


func _new_mail_dict(seed_data: Dictionary) -> Dictionary:
	var mail = seed_data.duplicate(true)
	mail["_runtime_id"] = _next_runtime_mail_id
	_next_runtime_mail_id += 1
	mail["_delivered"] = false
	mail["_read"] = false
	mail["_actioned"] = false
	return mail


func _schedule_mail_abs(deliver_abs: int, mail: Dictionary) -> void:
	var parts = _from_absolute_minutes(deliver_abs)
	mail["day"] = int(parts.get("day", 1))
	mail["time"] = "%02d:%02d" % [int(parts.get("hour", 0)), int(parts.get("minute", 0))]
	_scheduled_mails.append({
		"deliver_abs": deliver_abs,
		"mail": mail,
	})
	_scheduled_mails.sort_custom(func(a, b):
		var da = int((a as Dictionary).get("deliver_abs", 0))
		var db = int((b as Dictionary).get("deliver_abs", 0))
		return da < db
	)


func _deliver_due_mails(now_abs: int) -> void:
	if _scheduled_mails.is_empty():
		return
	var delivered_any := false
	var pending: Array[Dictionary] = []
	for entry_any in _scheduled_mails:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var deliver_abs = int(entry.get("deliver_abs", 0))
		var mail_any = entry.get("mail", {})
		if deliver_abs <= now_abs:
			if mail_any is Dictionary:
				var mail: Dictionary = mail_any
				if not bool(mail.get("_delivered", false)):
					mail["_delivered"] = true
					inbox.append(mail)
					email_received.emit(mail)
					if EventBus.has_signal("email_received"):
						EventBus.email_received.emit(mail)
					delivered_any = true
		else:
			pending.append(entry)
	_scheduled_mails = pending
	if delivered_any:
		unread_count_changed.emit(get_unread_count())


func _random_guest_name(archetype_id: String) -> String:
	var first_pool = FIRST_NAMES_QUIET
	if archetype_id == ARCHETYPE_DRUNK:
		first_pool = FIRST_NAMES_DRUNK
	elif archetype_id == ARCHETYPE_CHEAP_CHICK:
		first_pool = FIRST_NAMES_CHEAP
	return "%s %s" % [_pick_random(first_pool), _pick_random(LAST_NAMES)]


func _build_guest_name_list(lead_name: String, party_size: int, archetype_id: String) -> Array:
	var names: Array = [lead_name]
	while names.size() < party_size:
		var candidate = _random_guest_name(archetype_id)
		if names.has(candidate):
			candidate = "%s #%d" % [candidate, names.size() + 1]
		names.append(candidate)
	return names


func _roll_arrival_time(archetype_id: String) -> String:
	var minute = 12 * 60
	match archetype_id:
		ARCHETYPE_QUIET_GUY:
			minute = _rng.randi_range(10 * 60, 18 * 60 + 10)
		ARCHETYPE_DRUNK:
			minute = _rng.randi_range(17 * 60, 23 * 60 + 20)
		ARCHETYPE_CHEAP_CHICK:
			minute = _rng.randi_range(19 * 60, 23 * 60 + 50)
		_:
			minute = _rng.randi_range(11 * 60, 21 * 60)
	minute = clampi(minute, 0, (24 * 60) - 1)
	return "%02d:%02d" % [int(floor(float(minute) / 60.0)), int(minute % 60)]


func _slugify_name(value: String) -> String:
	var out = value.to_lower().strip_edges().replace(" ", ".")
	while out.contains(".."):
		out = out.replace("..", ".")
	return out


func _pick_random(items: Array[String]) -> String:
	if items.is_empty():
		return ""
	if items.size() == 1:
		return items[0]
	return items[_rng.randi_range(0, items.size() - 1)]


func _absolute_minutes(day: int, hour: int, minute: int) -> int:
	var safe_day = max(1, day)
	var safe_hour = clampi(hour, 0, 23)
	var safe_minute = clampi(minute, 0, 59)
	return (safe_day - 1) * 1440 + safe_hour * 60 + safe_minute


func _from_absolute_minutes(total_minutes: int) -> Dictionary:
	var safe = max(0, total_minutes)
	var day = int(floor(float(safe) / 1440.0)) + 1
	var minute_of_day = safe % 1440
	return {
		"day": day,
		"hour": int(floor(float(minute_of_day) / 60.0)),
		"minute": int(minute_of_day % 60),
	}


func _coord_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]


func get_customer_panel_data(mail: Dictionary) -> Dictionary:
	if not _is_customer_mail(mail):
		return {}
	var archetype_id = str(mail.get("archetype", ARCHETYPE_QUIET_GUY)).strip_edges()
	var cfg_any = CUSTOMER_ARCHETYPES.get(archetype_id, CUSTOMER_ARCHETYPES[ARCHETYPE_QUIET_GUY])
	var cfg: Dictionary = cfg_any if cfg_any is Dictionary else {}
	return {
		"guest_name": str(mail.get("guest_name", _extract_sender_name(mail))).strip_edges(),
		"party_size": max(1, int(mail.get("party_size", mail.get("guests", 1)))),
		"stay_nights": max(1, int(mail.get("stay_nights", mail.get("nights", 1)))),
		"arrival_time": str(mail.get("arrival_time", "10:00")).strip_edges(),
		"difficulty": clampi(int(mail.get("difficulty", cfg.get("difficulty", 1))), 1, 5),
		"archetype": archetype_id,
		"archetype_label": str(cfg.get("label", archetype_id)),
		"daily_total": max(0, int(mail.get("daily_total", 0))),
		"night_trouble_time": str(mail.get("night_trouble_time", cfg.get("night_trouble_time", "00:30"))).strip_edges(),
	}


func _extract_sender_name(mail: Dictionary) -> String:
	var sender = str(mail.get("sender", mail.get("from", "Guest"))).strip_edges()
	if sender.contains("<"):
		sender = sender.split("<")[0].strip_edges()
	if sender.is_empty():
		sender = "Guest"
	return sender


func get_unread_count() -> int:
	var count: int = 0
	for mail in inbox:
		if not bool(mail.get("_read", false)):
			count += 1
	return count


func mark_read(mail: Dictionary) -> void:
	if not bool(mail.get("_read", false)):
		mail["_read"] = true
		unread_count_changed.emit(get_unread_count())


func can_accept_customer_booking(mail: Dictionary) -> bool:
	if not _is_customer_mail(mail):
		return false
	if GuestManager != null and GuestManager.has_method("can_accept_booking"):
		return bool(GuestManager.can_accept_booking(mail))
	var bed_metrics = _collect_bed_metrics()
	var free_beds = max(0, int(bed_metrics.get("free", 0)))
	var requested_beds = max(1, int(mail.get("guests", mail.get("party_size", 1))))
	return requested_beds <= free_beds


func confirm_customer_booking(mail: Dictionary) -> bool:
	if not _is_customer_mail(mail):
		return false
	if bool(mail.get("_actioned", false)):
		return false
	if not can_accept_customer_booking(mail):
		return false

	mail["_actioned"] = true
	customer_booking_confirmed.emit(mail)
	if EventBus.has_signal("customer_booking_confirmed"):
		EventBus.customer_booking_confirmed.emit(mail)
	return true


func reject_customer_booking(mail: Dictionary) -> void:
	if mail.is_empty():
		return
	mail["_actioned"] = true
	customer_booking_rejected.emit(mail)
	if EventBus.has_signal("customer_booking_rejected"):
		EventBus.customer_booking_rejected.emit(mail)
	if inbox.has(mail):
		inbox.erase(mail)
	unread_count_changed.emit(get_unread_count())


func _is_customer_mail(mail: Dictionary) -> bool:
	var mail_type = str(mail.get("type", "")).to_lower().strip_edges()
	return mail_type == MAIL_TYPE_CUSTOMER or mail_type == "guest"
