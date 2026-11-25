extends Node

## Headless check for a sandbox camp's offer of the week, the tour (core/systems/offer_rules.gd,
## scripts/camp/week_offers.gd, email_manager.offer_tour; Richard 25. 11. „Jednou týdně“, „Velká
## parta za lepší cenu“): its day the week's 2nd to 6th, due once a week in office hours; a
## tour's size for the free beds; the agency's letter (8-15 of one kind, 2-4 nights, half as much
## again a head, the 380's time, in Czech too); the party booked from it comes on the 380; the
## week's offer sent by week_offers once, only in a sandbox with its events on.
##
##   godot --headless --path godot res://tools/offer_check.tscn

const RULES := preload("res://core/systems/offer_rules.gd")
const TIMES := preload("res://scripts/town/bus_timetable.gd")
const GM := preload("res://scripts/guest_manager.gd")
const WEEK := preload("res://scripts/camp/week_offers.gd")
const LANG_F := preload("res://scripts/lang.gd")
const SEED := 1234

var _failures: Array[String] = []


func _ready() -> void:
	# The rules.
	var days_ok := true
	for w in 30:
		var d := RULES.day_of(w, SEED)
		if d < w * 7 + 2 or d > w * 7 + 6 or d != RULES.day_of(w, SEED):
			days_ok = false
	_expect(days_ok, "the offer's day: the week's 2nd to 6th, the same for a seed")
	_expect(RULES.week_of(1) == 0 and RULES.week_of(7) == 0 and RULES.week_of(8) == 1, "the weeks")
	var d0 := RULES.day_of(0, SEED)
	_expect(RULES.due(d0, 9, SEED, {}) == "" and RULES.due(d0, 10, SEED, {}) == "tour" and RULES.due(d0, 18, SEED, {}) == "", "due from ten on its day, in office hours")
	_expect(RULES.due(d0 - 1, 12, SEED, {}) == "" and RULES.due(7, 12, SEED, {}) == "tour", "not before its day, till the week is out")
	_expect(RULES.due(d0, 12, SEED, {"0": "tour"}) == "" and RULES.due(8 + 6, 12, SEED, {"0": "tour"}) == "tour", "once a week")
	_expect(RULES.tour_size(7, 0.5) == 0 and RULES.tour_size(8, 0.99) == 8 and RULES.tour_size(40, 0.0) == 8 and RULES.tour_size(40, 0.999) == 15 and RULES.tour_size(11, 0.999) == 11, "a tour's size for the free beds")

	# The 380 at the camp.
	var t := TIMES.next_camp_arrival(9 * 60, 8 * 60, 19 * 60 + 30)
	_expect(t == 9 * 60 + 42, "at nine: the 9:42 (%d)" % t)
	t = TIMES.next_camp_arrival(19 * 60, 8 * 60, 19 * 60 + 30)
	_expect(t == 1440 + 9 * 60 + 42, "after the last: tomorrow's 9:42 (%d)" % t)
	_expect(GM.bus_run(12 * 60 + 30) == 18 * 60 + 37, "booked at 12:30: the 18:37 (%d)" % GM.bus_run(12 * 60 + 30))

	# A camp with beds.
	var st = CoreRoot.get_state()
	st.grid.init_dimensions(28, 28, 4.0)
	st.grid.cells.clear()
	st.guests.clear()
	var cap: int = GuestManager._capacity_for_building_type("cabin_1")
	var beds := 0
	var i := 0
	while beds < 20 and cap > 0:
		var o := Vector2i(2 + (i % 6) * 3, 2 + (i / 6) * 3)
		for c in [o, o + Vector2i(1, 0), o + Vector2i(0, 1), o + Vector2i(1, 1)]:
			st.grid.occupy_cell(c, "cabin_1", "cab%d" % i, o, Vector2i(2, 2))
		beds += cap
		i += 1
	var free := int(GuestManager.get_bed_metrics()["free"])
	_expect(free >= 15, "the camp's free beds (%d)" % free)

	# The agency's letter.
	var em = EmailManager
	em.reset_runtime(true)
	_expect(em.offer_tour(3, 10), "a tour offered with %d beds free" % free)
	_expect(em._scheduled_mails.size() == 1, "one letter on its way (%d)" % em._scheduled_mails.size())
	var mail: Dictionary = em._scheduled_mails[0]["mail"] if not em._scheduled_mails.is_empty() else {}
	var size := int(mail.get("guests", 0))
	_expect(size >= 8 and size <= mini(15, free) and int(mail.get("nights", 0)) >= 2 and int(mail.get("nights", 0)) <= 4, "8-15 of them, 2-4 nights (%d, %d)" % [size, int(mail.get("nights", 0))])
	_expect(bool(mail.get("by_bus", false)) and str(mail.get("tour", "")) != "" and bool(mail.get("tempting", false)) and str(mail.get("from", "")).begins_with("CK Pohoda Tour"), "from the agency, on the 380, gold on the card")
	var base := int((em.CUSTOMER_ARCHETYPES[str(mail.get("archetype", "quiet_guy"))] as Dictionary).get("daily_pay", 80)) * size
	var want := float(base) * RULES.TOUR_PAY
	_expect(absf(float(mail.get("daily_total", 0)) - want) <= maxf(8.0, want * 0.18) + 1.0, "half as much again a head (%d against %d)" % [int(mail.get("daily_total", 0)), int(want)])
	_expect(str(mail.get("body", "")).contains("13:12"), "the letter: the 380 at 13:12 (%s)" % str(mail.get("body", "")).substr(0, 120))
	_expect(str(mail.get("subject", "")).begins_with("Group trip: "), "the subject (%s)" % mail.get("subject", ""))
	LANG_F.apply("cs")
	var cs_body := tr(str(mail.get("body", "")))
	var cs_subject := tr(str(mail.get("subject", "")))
	LANG_F.apply("en")
	_expect(cs_body.begins_with("Vážení") and cs_body.contains("13:12") and cs_subject.begins_with("Zájezd: ") and not cs_subject.contains("Group"), "in Czech: %s / %s" % [cs_subject, cs_body.substr(0, 80)])

	# Booked: they come on the 380.
	GuestManager._last_known_day = 3
	GuestManager._last_known_hour = 10
	GuestManager._last_known_minute = 30
	GuestManager._on_customer_booking_confirmed(mail)
	var g: Dictionary = st.guests[st.guests.size() - 1] if not st.guests.is_empty() else {}
	var at := 2 * 1440 + 13 * 60 + 12 + GM.BUS_WALK_MIN
	_expect(int(g.get("party_size", 0)) == size and int(g.get("arrival_abs", 0)) == at, "booked at 10:30: at the barrier at 13:16 (%d, %d)" % [int(g.get("arrival_abs", 0)), at])

	# The week's offer sent once, a sandbox's with its events on.
	st.guests.clear()
	st.offers = {}
	em.reset_runtime(true)
	var main := _fake_main(true, true, d0)
	add_child(main)
	var w = WEEK.new()
	w.main = main
	add_child(w)
	CoreRoot.apply_changes({"day": d0})
	w._process(10.0)
	_expect(em._scheduled_mails.size() == 1 and str(CoreRoot.actions.offers_done().get("0", "")) == "tour", "the week's tour sent and marked (%d, %s)" % [em._scheduled_mails.size(), CoreRoot.actions.offers_done()])
	main.set("_time_of_day_hours", 11.2)
	w._process(10.0)
	_expect(em._scheduled_mails.size() == 1, "and not again that week")
	st.offers = {}
	em.reset_runtime(true)
	main.set("_rules_events", false)
	main.set("_time_of_day_hours", 12.2)
	w._process(10.0)
	_expect(em._scheduled_mails.is_empty(), "nothing with the camp's events off")
	main.set("_rules_events", true)
	main.set("_sandbox", false)
	main.set("_time_of_day_hours", 13.2)
	w._process(10.0)
	_expect(em._scheduled_mails.is_empty(), "nothing in the story camp")
	w.free()
	main.free()

	if _failures.is_empty():
		print("OFFER CHECK: PASS")
	else:
		print("OFFER CHECK: FAIL")
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


## What week_offers asks of main.
func _fake_main(sandbox: bool, events: bool, _day: int) -> Node:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar _gameplay_started := true\nvar _menu_mode := false\nvar _sandbox := true\nvar _rules_events := true\nvar _time_of_day_hours := 10.2\nvar world_generator: Node\nfunc camp_rule(id: String) -> bool:\n\treturn _rules_events if id == \"events\" else true\n"
	s.reload()
	var m := Node.new()
	m.set_script(s)
	m.set("_sandbox", sandbox)
	m.set("_rules_events", events)
	var wg := GDScript.new()
	wg.source_code = "extends Node\nvar world_seed := %d\n" % SEED
	wg.reload()
	var gen := Node.new()
	gen.set_script(wg)
	m.add_child(gen)
	m.set("world_generator", gen)
	return m


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
