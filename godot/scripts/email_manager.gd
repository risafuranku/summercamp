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
## Co-op, the other warden's machine: the host's mail came in changed (read, answered,
## deleted, new): the open CampMail redraws (scripts/os98/os_shell.gd).
signal coop_synced

const MAIL_TYPE_CUSTOMER := "customer"
const MAIL_TYPE_SPAM := "spam"

const ARCHETYPE_QUIET_GUY := "quiet_guy"
const ARCHETYPE_DRUNK := "drunk"
const ARCHETYPE_CHEAP_CHICK := "cheap_chick"
const ARCHETYPE_TRAMP := "tramp"
const ARCHETYPE_FAMILY := "family"
const ARCHETYPE_PICKER := "picker"


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
	ARCHETYPE_TRAMP: {
		"label": "Tramps",
		"difficulty": 2,
		"daily_pay": 55,
		"party_min": 2,
		"party_max": 4,
		"stay_min": 2,
		"stay_max": 4,
		"night_trouble_time": "23:30",
	},
	ARCHETYPE_FAMILY: {
		"label": "Family",
		"difficulty": 4,
		"daily_pay": 150,
		"party_min": 3,
		"party_max": 4,
		"stay_min": 2,
		"stay_max": 5,
		"night_trouble_time": "01:30",
	},
	ARCHETYPE_PICKER: {
		"label": "Mushroom Pickers",
		"difficulty": 3,
		"daily_pay": 90,
		"party_min": 1,
		"party_max": 2,
		"stay_min": 2,
		"stay_max": 4,
		"night_trouble_time": "04:10",
	},
}

## What they write. %s placeholders: beds, nights, arrival time, name. The archetype
## shows in how they write, not in a label; the booking card has the numbers.
## Where they would like to sleep, as a P.S. in their own voice (the tastes are
## GuestNeedsSystem.LODGING_TASTE: the key you give at the desk is what they get).
const LODGING_WISHES := {
	ARCHETYPE_QUIET_GUY: ["A cabin would be best. Somewhere I cannot hear the others.", "Not a tent, if it can be helped. I sleep badly under canvas."],
	ARCHETYPE_DRUNK: ["a caravan with a fridge would be MINT", "we sleep anywhere honestly. just not next to any grannies"],
	ARCHETYPE_CHEAP_CHICK: ["A room with its OWN shower pleeease!!", "Please not a tent, we are not animals :D", "Is the caravan with the little lights free??"],
	ARCHETYPE_TRAMP: ["A tent is fine. The more canvas the better.", "No need for walls. A tent near the fire."],
	ARCHETYPE_FAMILY: ["The children are begging for a caravan with bunk beds.", "Somewhere warm for the kids, please, not a tent."],
	ARCHETYPE_PICKER: ["A proper cabin, please. My back cannot do a tent any more.", "Somewhere quiet, away from any young men. We go to bed at eight."],
}

const BOOKING_LETTERS := {
	ARCHETYPE_QUIET_GUY: [
		"Good day,\n\nI would like a bed for %d person(s), %d night(s). I arrive around %s by bus. I need nothing special. A quiet place, if you have one.\n\nThank you.\n%s",
		"Hello,\n\n%d bed(s), %d night(s). Arrival about %s. I will not be any trouble.\n\n%s",
	],
	ARCHETYPE_DRUNK: [
		"AHOJ CAMP!!!\n\nwe are %d lads, %d nights, arriving %s-ish (depends on the pub in Lesna). is the beer cold? is there a pub? if no pub we bring our own. NA ZDRAVI\n\n%s",
		"hi\n\nneed %d beds for %d nights. coming around %s. do you have a pub. asking for a friend. the friend is me.\n\n%s",
	],
	ARCHETYPE_CHEAP_CHICK: [
		"Hiii :)\n\n%d of us, %d nights, we arrive at %s. Is there a slide? A shower with hot water?? We heard the lake is SO pretty at night.\n\nkisses, %s",
		"Hello reception,\n\nGirls weekend!! %d beds, %d nights, arriving %s. Cheapest you have please, we are students.\n\n%s",
	],
	ARCHETYPE_TRAMP: [
		"Ahoj,\n\nwe are %d from the Vlci stopa tramp settlement. %d nights, coming %s on foot from the station. We bring our own kotlik and guitars. Tent is fine, ground is fine. Is there a fire pit?\n\nTRAMP SE NEVZDAVA - %s",
		"Hello camp,\n\n%d tramps, %d nights. Arriving around %s, depends on the trains. We sing until late, we warn you honestly. Kamarade, keep us a spot by the fire.\n\n%s",
	],
	ARCHETYPE_FAMILY: [
		"Dear camp,\n\nwe are a family of %d (two kids, 6 and 9) looking for %d nights. We arrive by Skoda around %s. Is it safe for children? Is there a playground or a field? Our boy wanders off, is the lake fenced?\n\nKind regards, %s",
		"Hello,\n\nFamily holiday: %d people, %d nights, arrival about %s. The kids want the slide and my wife wants a clean shower. I want a beer and quiet. Thank you.\n\n%s",
	],
	ARCHETYPE_PICKER: [
		"Good day,\n\nWe are pensioners, %d person(s), %d nights. We arrive at %s. We go out for mushrooms very early (four o'clock), so we ask for a quiet place away from the young people. Are the boletes growing this year?\n\nRespectfully, %s",
		"Dear Sir or Madam,\n\n%d bed(s), %d nights, arrival at %s. We pick mushrooms. We will be gone before you wake up and back by noon. We bring our own knife and basket.\n\n%s",
	],
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
## Tramps go by their settlement nicknames.
const FIRST_NAMES_TRAMP: Array[String] = [
	"Sedy Vlk", "Kojot", "Bobr", "Rambo", "Sumak", "Vrba", "Dlouhej", "Bizon"
]
const FIRST_NAMES_FAMILY: Array[String] = [
	"Jiri", "Pavel", "Martin", "Jana", "Petra", "Ivana", "Josef", "Hana"
]
const FIRST_NAMES_PICKER: Array[String] = [
	"Bohumil", "Jaroslava", "Vlasta", "Zdenek", "Ludmila", "Miroslav", "Bozena", "Karel"
]
const LAST_NAMES: Array[String] = [
	"Novak", "Krizek", "Urban", "Bartos", "Kral", "Dvorak", "Janda", "Simek", "Blaha", "Nemec"
]
const MAIL_DOMAINS: Array[String] = [
	"mail.cz", "postbox.eu", "campmail.net", "atlas.cz", "chatmail.cz"
]

## Spam is the period kind: dial-up offers, chain letters, prizes, miracle cures, local
## shops. Each one hangs together (sender, subject, body, the picture it carries), the
## way the real ones did. `image`: a GIF-ish picture in assets/textury/mail/ shown in the
## message; `attachment`: the file name CampMail shows for it.
const SPAM_MAILS: Array[Dictionary] = [
	{"from": "Lucky Draw Office <office@lucky-draw.com>", "subject": "CONGRATULATIONS!!! You have been selected", "image": "spam_lottery", "attachment": "WINNER.GIF",
		"body": "Dear Friend,\n\nYour e-mail address was drawn in our INTERNATIONAL DRAW of 1998. You have won US$ 25 000 (twenty five thousand dollars).\n\nTo claim your prize send the handling fee of 1 900 Kc by postal order to the address below. Do not tell anyone until the prize arrives, for security reasons.\n\nYours faithfully,\nMr. A. Wellington, Claims Office"},
	{"from": "Mobil Zdarma <akce@mobil-zdarma.cz>", "subject": "FREE mobile phone for the first 100 !!!", "image": "spam_phone", "attachment": "TELEFON.GIF",
		"body": "Be reachable everywhere - even at the lake!\n\nThe first 100 people to reply get a GSM mobile phone FREE with a 24-month contract. Coverage in 94 % of the country.\n\nReply with your name and address. Offer valid while stocks last."},
	{"from": "Natura Vital <info@naturavital.com>", "subject": "Lose 10 kg in 10 days - doctors are amazed", "image": "spam_pills", "attachment": "VITAL.GIF",
		"body": "NO DIETS. NO EXERCISE.\n\nThe secret of the Tibetan monks, now in tablets. 100 % natural. Thousands of satisfied customers in Bohemia and Moravia.\n\nOne month's course only 990 Kc + postage. Money back guarantee."},
	{"from": "Jana Dvorakova <jana.d@post.cz>", "subject": "FW: FW: FW: FW: send this to 10 people", "image": "spam_chain", "attachment": "ANDEL.GIF",
		"body": "> > > > This letter has been around the world nine times. Send it to ten people within four days and good luck will come to you.\n> > > >\n> > > > A man in Ostrava laughed at it and did not send it. He lost his job.\n> > > > A woman in Tabor sent it the same day and won a car.\n> > > >\n> > > > DO NOT BREAK THE CHAIN."},
	{"from": "Seznamka DUO <duo@seznamka-duo.cz>", "subject": "Lonely evenings? Someone in your district is waiting", "image": "spam_dating", "attachment": "DUO.GIF",
		"body": "Ladies and gentlemen from the Hlubocany district are looking for company.\n\nCall our line 0900 12 34 56 (35 Kc a minute) and leave your message after the tone.\n\nSomeone near you is waiting tonight."},
	{"from": "Bohemia Online <info@bohemia-online.cz>", "subject": "Internet 33.6k now with 10 free hours",
		"body": "Dear customer,\n\nconnect from home or office at 33,600 baud. The first ten hours each month are free. Installation diskette by post within 14 days.\n\nBohemia Online - your way into the Internet"},
	{"from": "Autoservis Krejci <servis.krejci@quick.cz>", "subject": "Winter tyres - order now",
		"body": "Winter tyres, all sizes, at last year's price. Fitting while you wait. Do not get caught by the first snow.\n\nAutoservis Krejci, Lesna 7. Closed on Sundays."},
	{"from": "Reality Vysocina <nabidky@reality-vys.cz>", "subject": "Recreational cottage for sale, quiet area",
		"body": "Cottage near the reservoir, own well, electricity, quiet area, no neighbours. The previous owners left in a hurry, furniture included.\n\nSerious offers only."},
	{"from": "Kancelarske potreby <obchod@kancpotreby.cz>", "subject": "Toner, paper, diskettes - price list", "attachment": "CENIK98.TXT",
		"body": "Price list for autumn 1998 attached. Diskettes 3.5\" HD box of 10. Toner for most printers. We deliver to the whole district."},
]

## The mail that wakes you at night: it looks like trouble and is not. At most one a
## night, so the HUD ping in the dark always means "go and look".
const NIGHT_FALSE_ALARMS: Array[Dictionary] = [
	{"from": "CampGrid Alarm Relay <alarm@campgrid.local>", "subject": "ALARM: ZONE 3", "body": "Zone 3 contact open.

This was a scheduled test of the alarm relay. No action is required."},
	{"from": "CampGrid Energy <billing@campgrid.local>", "subject": "Supply interruption notice", "body": "Planned maintenance on the line to your site is postponed.

Your supply will not be interrupted tonight."},
	{"from": "District Office <registry@okres.local>", "subject": "URGENT: occupancy record", "body": "Automated reminder: occupancy records may be submitted at any time during the season. There is no deadline."},
	{"from": "Nela <nela@chatmail.cz>", "subject": "are you awake", "body": "sorry, wrong button. go back to sleep"},
	{"from": "CampNet Ops <ops@campnet.local>", "subject": "Intrusion report", "body": "Automated report:
- Perimeter sensor 2: triggered
- Cause: animal (probable)

Ticket closed."},
]

const CUSTOMER_SUBJECT_VARIANTS: Array[String] = [
	"Booking request: %s / %d beds / %d night(s)",
	"Need place tonight: %s / %d beds / %d night(s)",
	"Camp booking: %s (%d beds, %d nights)",
]

const MAIL_TO_ADDRESS := "camp.reception@camp.local"

## All delivered emails, newest last. `_folder` "deleted" puts one in Deleted Items.
var inbox: Array[Dictionary] = []
## What the player wrote (CampMail's Sent Items): {to, subject, body, day, time}.
var sent: Array[Dictionary] = []

var _scheduled_mails: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _next_runtime_mail_id: int = 1
var _last_tick_signature: String = ""
var _last_hourly_roll_signature: String = ""


## The camp's name on the internet (-0.25 .. 0.25): how the guest book reads to people
## deciding where to book. Answered entries move it (reply_to_review); it settles back
## toward nothing a little every morning. More of it, more booking letters.
var reputation := 0.0

## The guest book's replies: three ways to answer an entry. Which is right depends on
## the entry (stars): `fits` is what it does to the reputation for low / middle / high.
const REVIEW_REPLIES := [
	{"id": "thank", "label": "Thank them", "text": "Thank you for staying with us. We hope to see you again next summer! - the camp team", "fits": [0.005, 0.02, 0.03]},
	{"id": "sorry", "label": "Apologise", "text": "We are sorry your stay was not what it should have been. We have looked into it and it is being put right. - the camp team", "fits": [0.045, 0.025, -0.005]},
	{"id": "defend", "label": "Set them straight", "text": "Other guests had no problems at all. Perhaps a campsite is not for you. - the management", "fits": [-0.06, -0.03, -0.02]},
]


func _ready() -> void:
	if EventBus.has_signal("guest_review_posted") and not EventBus.guest_review_posted.is_connected(_on_review_posted):
		EventBus.guest_review_posted.connect(_on_review_posted)
	_rng.randomize()
	reset_runtime(false)
	if EventBus.has_signal("time_tick"):
		var tick_cb := Callable(self, "_on_time_tick")
		if not EventBus.time_tick.is_connected(tick_cb):
			EventBus.time_tick.connect(tick_cb)


func reset_runtime(clear_inbox: bool = true) -> void:
	reputation = 0.0
	_first_booking_due = false
	_scheduled_mails.clear()
	_last_tick_signature = ""
	_last_hourly_roll_signature = ""
	_next_runtime_mail_id = 1
	_coop_mail_hash = 0
	if clear_inbox:
		inbox.clear()
		sent.clear()
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


## Schedules a mail for its own "day"/"time" fields (story pool, quest follow-ups).
## Mails due in the past are delivered on the next minute tick.
func schedule_pool_mail(seed_data: Dictionary) -> void:
	var mail := _new_mail_dict(seed_data)
	var day: int = max(1, int(mail.get("day", 1)))
	var parts := str(mail.get("time", "09:00")).split(":")
	var hour := clampi(int(parts[0]) if parts.size() > 0 else 9, 0, 23)
	var minute := clampi(int(parts[1]) if parts.size() > 1 else 0, 0, 59)
	if str(mail.get("sender", "")).is_empty():
		mail["sender"] = str(mail.get("from", "System"))
	_schedule_mail_abs(_absolute_minutes(day, hour, minute), mail)


## Loads data/pools/emails/story/*.json into the schedule. Mails whose subject is in
## `skip_subjects` are left out (the questline delivers those itself).
## The story's mails (data/pools/emails/story). A sandbox camp (no month) leaves out the
## ones about the deadline ("campaign": true).
func load_story_pool(skip_subjects: Array = [], sandbox := false) -> int:
	var count := 0
	var dir := DirAccess.open("res://data/pools/emails/story/")
	if dir == null:
		return 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://data/pools/emails/story/" + file_name)
		var parsed = JSON.parse_string(text)
		if not (parsed is Array):
			continue
		for entry_any in parsed:
			if not (entry_any is Dictionary):
				continue
			var entry: Dictionary = entry_any
			if skip_subjects.has(str(entry.get("subject", ""))):
				continue
			if sandbox and bool(entry.get("campaign", false)):
				continue
			var seed := entry.duplicate(true)
			seed["type"] = "story"
			schedule_pool_mail(seed)
			count += 1
	return count


## First inbox mail carrying `key` == `value` (e.g. "task_id").
func find_mail(key: String, value: Variant) -> Dictionary:
	for mail in inbox:
		if mail.get(key, null) == value:
			return mail
	return {}


func export_runtime_state() -> Dictionary:
	return {
		"inbox": _sanitize_mail_array(inbox),
		"sent": sent.duplicate(true),
		"scheduled_mails": _sanitize_scheduled_mail_array(_scheduled_mails),
		"next_runtime_mail_id": max(1, int(_next_runtime_mail_id)),
		"last_tick_signature": str(_last_tick_signature),
		"last_hourly_roll_signature": str(_last_hourly_roll_signature),
		"false_alarm_night": _false_alarm_night,
		"reputation": reputation,
		"first_booking_due": _first_booking_due,
	}


func import_runtime_state(data: Dictionary) -> void:
	reset_runtime(true)
	if data.is_empty():
		return

	inbox = _sanitize_mail_array(data.get("inbox", []))
	sent.clear()
	for m in (data.get("sent", []) if data.get("sent", []) is Array else []):
		if m is Dictionary:
			sent.append(m)
	_scheduled_mails = _sanitize_scheduled_mail_array(data.get("scheduled_mails", []))
	_last_tick_signature = str(data.get("last_tick_signature", ""))
	_last_hourly_roll_signature = str(data.get("last_hourly_roll_signature", ""))
	_false_alarm_night = int(data.get("false_alarm_night", -1))
	reputation = clampf(float(data.get("reputation", 0.0)), -0.25, 0.25)
	_first_booking_due = bool(data.get("first_booking_due", false))

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

	# Co-op: the mail comes to the host's machine.
	if not Coop.sim_here():
		return
	var now_abs = _absolute_minutes(day, safe_hour, safe_minute)
	_deliver_due_mails(now_abs)
	if _first_booking_due:
		_try_first_booking(day, safe_hour, now_abs)

	if safe_minute == 0:
		var roll_signature = "%d:%02d" % [day, safe_hour]
		if roll_signature != _last_hourly_roll_signature:
			_last_hourly_roll_signature = roll_signature
			_run_hourly_roll(day, safe_hour, now_abs)


## A sandbox camp (co-op camps too) has no checklist and no story: one mail from the
## district says how a camp starts, and the first booking does not wait on the dice.
var _first_booking_due := false

const SANDBOX_START_MAIL := {
	"from": "District Office Hlubocany <kempy@okres-hlubocany.cz>",
	"subject": "Opening of the camp",
	"body": "Dear operator,\n\nThe camp is entered in the district register and may take guests. Booking letters will come to this mailbox; accept or refuse them here.\n\nA booking can only be accepted when there is a free bed for the whole party. Put up a tent or a cabin in Builder 98 (bulldoze the trees first), or patch up the old cabin by the office: walk up to it and hold R, then clean it out and make up the bed. The camp goes on the booking lists as soon as a bed stands.\n\nGuests also need a toilet, food and a made-up room. When a party reaches the barrier, check them in at the reception desk.\n\nHold TAB outdoors for the site plan and the jobs waiting.\n\nDistrict Office Hlubocany\nTourism department",
}


## A new sandbox camp: the district's mail now, the first booking once a bed is free.
func sandbox_start(time_str: String) -> void:
	_first_booking_due = true
	var mail := SANDBOX_START_MAIL.duplicate(true)
	mail["type"] = "system"
	mail["time"] = time_str
	push_system_mail(mail)


## In office hours with a free bed and no booking waiting: a quiet guest (one bed) writes
## within half an hour. A booking that came by the dice first does instead.
func _try_first_booking(day: int, hour: int, now_abs: int) -> void:
	if hour < BOOKING_FIRST_HOUR or hour > BOOKING_LAST_HOUR:
		return
	if _count_unactioned_customer_mails() + _count_scheduled_customer_mails() > 0:
		_first_booking_due = false
		return
	if int(_collect_bed_metrics().get("free", 0)) <= 0:
		return
	_first_booking_due = false
	_schedule_mail_abs(now_abs + _rng.randi_range(8, 25), _build_customer_mail(ARCHETYPE_QUIET_GUY, day, hour))


## The hourly mail roll. The inbox used to take up to nine bookings and four spam mails
## an hour; now the camp is slow to be found: bookings come in office hours, more
## likely as the week goes on and the more beds stand empty, never more than a few
## waiting at once. Spam is occasional. At night at most one false alarm.
func _run_hourly_roll(day: int, hour: int, base_abs: int) -> void:
	var bed_metrics = _collect_bed_metrics()
	var hrotfaktor = _refresh_hrotfaktor(bed_metrics)
	var intensity = _roll_intensity(bed_metrics, hrotfaktor)

	var customer_count = _roll_customer_mail_count(bed_metrics, day, hour, intensity)
	if customer_count > 0:
		var archetypes = _roll_archetype_batch(customer_count, intensity, day)
		var offsets = _spread_offsets(customer_count, 2, 58)
		for i in range(customer_count):
			var archetype_id = archetypes[i] if i < archetypes.size() else ARCHETYPE_QUIET_GUY
			var mail = _build_customer_mail(archetype_id, day, hour)
			_schedule_mail_abs(base_abs + offsets[i], mail)

	if _roll_spam(day, hour):
		_schedule_mail_abs(base_abs + _rng.randi_range(1, 58), _build_spam_mail(day, hour))

	if _roll_night_false_alarm(day, hour):
		_schedule_mail_abs(base_abs + _rng.randi_range(5, 55), _build_night_false_alarm(day, hour))


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


const BOOKING_FIRST_HOUR := 7
const BOOKING_LAST_HOUR := 20
const NIGHT_ALARM_FIRST_HOUR := 22
const NIGHT_ALARM_LAST_HOUR := 4
var _false_alarm_night: int = -1


func _roll_customer_mail_count(bed_metrics: Dictionary, day: int, hour: int, intensity: float) -> int:
	var capacity = max(0, int(bed_metrics.get("capacity", 0)))
	if capacity <= 0 or hour < BOOKING_FIRST_HOUR or hour > BOOKING_LAST_HOUR:
		return 0
	var waiting := _count_unactioned_customer_mails() + _count_scheduled_customer_mails()
	if waiting >= clampi(1 + day, 2, 6):
		return 0
	var free_ratio := float(bed_metrics.get("free", 0)) / float(capacity)
	var chance := clampf(0.14 + 0.07 * float(day - 1) + 0.18 * free_ratio + 0.4 * reputation, 0.06, 0.72)
	var count := 1 if _rng.randf() < chance else 0
	if count > 0 and day >= 3 and _rng.randf() < 0.25 * intensity:
		count += 1
	return count


func _roll_spam(day: int, hour: int) -> bool:
	if hour < BOOKING_FIRST_HOUR or hour > BOOKING_LAST_HOUR:
		return false
	return _rng.randf() < clampf(0.05 + 0.015 * float(day), 0.05, 0.16)


func _roll_night_false_alarm(day: int, hour: int) -> bool:
	if day < 2 or not (hour >= NIGHT_ALARM_FIRST_HOUR or hour <= NIGHT_ALARM_LAST_HOUR):
		return false
	# The night belongs to the evening it started on.
	var night := day if hour >= NIGHT_ALARM_FIRST_HOUR else day - 1
	if _false_alarm_night == night:
		return false
	# ~7% an hour over seven night hours: about two nights in five.
	if _rng.randf() > 0.07:
		return false
	_false_alarm_night = night
	return true


func _build_night_false_alarm(day: int, hour: int) -> Dictionary:
	var pick: Dictionary = NIGHT_FALSE_ALARMS[_rng.randi_range(0, NIGHT_FALSE_ALARMS.size() - 1)]
	return _new_mail_dict({
		"sender": pick["from"],
		"from": pick["from"],
		"subject": pick["subject"],
		"body": pick["body"],
		"day": day,
		"time": "%02d:00" % clampi(hour, 0, 23),
		"type": "system",
	})


func _count_scheduled_customer_mails() -> int:
	var count := 0
	for entry in _scheduled_mails:
		var mail_any = (entry as Dictionary).get("mail", {})
		if mail_any is Dictionary and _is_customer_mail(mail_any):
			count += 1
	return count


func _roll_archetype_batch(count: int, intensity: float, day: int = 1) -> Array[String]:
	var out: Array[String] = []
	if count <= 0:
		return out

	var archetype_ids: Array[String] = [ARCHETYPE_QUIET_GUY, ARCHETYPE_DRUNK, ARCHETYPE_CHEAP_CHICK, ARCHETYPE_TRAMP, ARCHETYPE_FAMILY, ARCHETYPE_PICKER]
	var weights: Dictionary = {
		ARCHETYPE_QUIET_GUY: clampf(lerpf(0.55, 0.14, intensity), 0.12, 0.60),
		ARCHETYPE_DRUNK: clampf(lerpf(0.16, 0.24, intensity), 0.10, 0.34),
		ARCHETYPE_CHEAP_CHICK: clampf(lerpf(0.04, 0.26, intensity), 0.02, 0.36),
		ARCHETYPE_TRAMP: clampf(lerpf(0.14, 0.18, intensity), 0.08, 0.26),
		ARCHETYPE_FAMILY: clampf(lerpf(0.05, 0.22, intensity), 0.03, 0.30),
		ARCHETYPE_PICKER: clampf(lerpf(0.10, 0.16, intensity), 0.06, 0.22),
	}
	# Who comes in the autumn (core/systems/season.gd): the families stop after the
	# school year starts, the mushroom pickers come in the wet weeks, the party girls
	# thin out, the tramps and the loners stay on into the cold.
	var p := Season.progress(day)
	weights[ARCHETYPE_FAMILY] = float(weights[ARCHETYPE_FAMILY]) * lerpf(1.0, 0.2, p)
	weights[ARCHETYPE_PICKER] = float(weights[ARCHETYPE_PICKER]) * (0.7 + 1.8 * exp(-pow((p - 0.4) / 0.2, 2.0)))
	weights[ARCHETYPE_CHEAP_CHICK] = float(weights[ARCHETYPE_CHEAP_CHICK]) * lerpf(1.0, 0.35, p)
	weights[ARCHETYPE_TRAMP] = float(weights[ARCHETYPE_TRAMP]) * lerpf(0.8, 1.6, p)
	weights[ARCHETYPE_QUIET_GUY] = float(weights[ARCHETYPE_QUIET_GUY]) * lerpf(1.0, 1.3, p)
	var counts: Dictionary = {}
	for id in archetype_ids:
		counts[id] = 0
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

	var letters: Array = BOOKING_LETTERS.get(archetype_id, BOOKING_LETTERS[ARCHETYPE_QUIET_GUY])
	var letter := str(letters[_rng.randi_range(0, letters.size() - 1)]) % [party_size, stay_nights, arrival_time, lead_name]
	var wishes: Array = LODGING_WISHES.get(archetype_id, [])
	if not wishes.is_empty() and _rng.randf() < 0.75:
		letter += "\n\nP.S. " + str(wishes[_rng.randi_range(0, wishes.size() - 1)])

	return _new_mail_dict({
		"sender": sender,
		"from": sender,
		"subject": subject,
		"body": letter,
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
	var pick: Dictionary = SPAM_MAILS[_rng.randi_range(0, SPAM_MAILS.size() - 1)]
	return _new_mail_dict({
		"sender": pick["from"],
		"from": pick["from"],
		"subject": pick["subject"],
		"body": pick["body"],
		"image": str(pick.get("image", "")),
		"attachment": str(pick.get("attachment", "")),
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
	elif archetype_id == ARCHETYPE_TRAMP:
		return "%s" % _pick_random(FIRST_NAMES_TRAMP)
	elif archetype_id == ARCHETYPE_FAMILY:
		first_pool = FIRST_NAMES_FAMILY
	elif archetype_id == ARCHETYPE_PICKER:
		first_pool = FIRST_NAMES_PICKER
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
		ARCHETYPE_TRAMP:
			minute = _rng.randi_range(15 * 60, 21 * 60)
		ARCHETYPE_FAMILY:
			minute = _rng.randi_range(10 * 60, 16 * 60)
		ARCHETYPE_PICKER:
			minute = _rng.randi_range(9 * 60, 14 * 60)
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


# ── co-op: the mail is the host's (scripts/coop/coop.gd) ─────────────────────

var _coop_mail_hash := 0


## The other warden's machine: the host's mail as it now is (main.coop_apply_pulse, every
## time the camp changed: only a changed mail is taken). A mail that was not here before
## lands as it does at the host (CampMail's chime, the tray, the open window), except the
## first time (the mail that came with the camp).
func coop_take(mail: Dictionary) -> void:
	var h := hash(var_to_bytes(mail))
	if h == _coop_mail_hash:
		return
	var first := _coop_mail_hash == 0
	_coop_mail_hash = h
	var known := {}
	for m in inbox:
		known[int(m.get("_runtime_id", -1))] = true
	inbox = _sanitize_mail_array(mail.get("inbox", []))
	sent.clear()
	for m in (mail.get("sent", []) if mail.get("sent", []) is Array else []):
		if m is Dictionary:
			sent.append(m)
	reputation = float(mail.get("rep", reputation))
	unread_count_changed.emit(get_unread_count())
	if not first:
		for m in inbox:
			if not known.has(int(m.get("_runtime_id", -1))) and str(m.get("_folder", "inbox")) == "inbox":
				email_received.emit(m)
	coop_synced.emit()


## The other warden's machine: what was done to a mail goes to the host too (it is done
## here at once, and the host's mail comes back). True when it went.
func _coop_send(what: String, mail: Dictionary, extra: Array = []) -> bool:
	if not Coop.is_client():
		return false
	Coop.send_request("mail", [what, int(mail.get("_runtime_id", -1))] + extra)
	return true


## The host: what the other warden did to a mail ([what, mail id, ...]).
func coop_do(data: Array) -> void:
	var what := str(data[0])
	if what == "send":
		send_mail(str(data[2]), str(data[3]), str(data[4]), int(data[5]), str(data[6]))
		return
	var mail := find_mail("_runtime_id", int(data[1]))
	if mail.is_empty():
		return
	match what:
		"read":
			mark_read(mail)
		"delete":
			delete_mail(mail)
		"confirm":
			confirm_customer_booking(mail)
		"reject":
			reject_customer_booking(mail)
		"reply":
			reply_to_review(mail, str(data[2]))


func get_unread_count() -> int:
	var count: int = 0
	for mail in inbox:
		if not bool(mail.get("_read", false)) and str(mail.get("_folder", "inbox")) != "deleted":
			count += 1
	return count


## CampMail's Delete: into Deleted Items, and from there gone for good.
func delete_mail(mail: Dictionary) -> void:
	_coop_send("delete", mail)
	if str(mail.get("_folder", "inbox")) == "deleted":
		for i in inbox.size():
			if int(inbox[i].get("_runtime_id", -1)) == int(mail.get("_runtime_id", -2)):
				inbox.remove_at(i)
				break
	else:
		mail["_folder"] = "deleted"
	unread_count_changed.emit(get_unread_count())


## A message the player sends (CampMail's New / Reply / Forward).
## A guest's review arrives as a guest book entry to answer (EventBus.guest_review_posted).
func _on_review_posted(review: Dictionary) -> void:
	var stars := clampi(int(review.get("rating", 3)), 1, 5)
	var day := maxi(1, int(review.get("day", CoreRoot.get_day() if CoreRoot != null and CoreRoot.has_method("get_day") else 1)))
	var star_txt := "*".repeat(stars) + "-".repeat(5 - stars)
	push_system_mail({
		"type": "review",
		"from": "Guest book <guestbook@cerne-jezero.cz>",
		"subject": "New guest book entry [%s] %s" % [star_txt, str(review.get("name", "a guest"))],
		"body": "A new entry was written in the guest book at cerne-jezero.cz:\n\n> %s\n> - %s, %d night%s\n\nEntries without a reply stay at the top of the page." % [str(review.get("text", "")), str(review.get("name", "a guest")), int(review.get("stay_nights", 1)), "" if int(review.get("stay_nights", 1)) == 1 else "s"],
		"review": {"rating": stars, "name": str(review.get("name", "")), "guest_id": int(review.get("guest_id", -1))},
		"day": day,
		"time": _clock_now(),
	})


func _clock_now() -> String:
	# The last minute tick ("day:hh:mm") is the mail clock.
	var parts := _last_tick_signature.split(":")
	if parts.size() == 3:
		return "%s:%s" % [parts[1].lpad(2, "0"), parts[2]]
	return "10:00"


## Answers a guest book entry with one of REVIEW_REPLIES: the reply goes in Sent Items
## and the camp's name moves. Returns the change (0 if it was answered already).
func reply_to_review(mail: Dictionary, reply_id: String) -> float:
	if bool(mail.get("_actioned", false)):
		return 0.0
	if _coop_send("reply", mail, [reply_id]):
		mail["_actioned"] = true
		mail["reply"] = reply_id
		return 0.0
	var r: Dictionary = mail.get("review", {})
	var stars := int(r.get("rating", 3))
	var band := 0 if stars <= 2 else (2 if stars >= 4 else 1)
	for opt in REVIEW_REPLIES:
		if str(opt["id"]) == reply_id:
			var change := float((opt["fits"] as Array)[band])
			reputation = clampf(reputation + change, -0.25, 0.25)
			mail["_actioned"] = true
			mail["reply"] = reply_id
			send_mail("guestbook@cerne-jezero.cz", "Re: " + str(mail.get("subject", "")), str(opt["text"]), int(mail.get("day", 1)), _clock_now())
			return change
	return 0.0


## Every morning the internet forgets a little.
func settle_reputation() -> void:
	reputation *= 0.9


func send_mail(to: String, subject: String, body: String, day: int, time: String) -> void:
	if Coop.is_client():
		Coop.send_request("mail", ["send", -1, to, subject, body, day, time])
	sent.append({"to": to, "subject": subject, "body": body, "day": day, "time": time})


func mark_read(mail: Dictionary) -> void:
	if not bool(mail.get("_read", false)):
		_coop_send("read", mail)
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
	# Co-op: the booking is made in the host's camp (its guest comes back with the pulse).
	if _coop_send("confirm", mail):
		mail["_actioned"] = true
		return true

	mail["_actioned"] = true
	customer_booking_confirmed.emit(mail)
	if EventBus.has_signal("customer_booking_confirmed"):
		EventBus.customer_booking_confirmed.emit(mail)
	return true


func reject_customer_booking(mail: Dictionary) -> void:
	if mail.is_empty():
		return
	if _coop_send("reject", mail):
		mail["_actioned"] = true
		if inbox.has(mail):
			inbox.erase(mail)
		unread_count_changed.emit(get_unread_count())
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
