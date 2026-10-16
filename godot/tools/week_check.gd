extends SceneTree

## Headless check of the week's books (scripts/week_ledger.gd). No autoloads, so:
##
##   godot --headless --path godot --script res://tools/week_check.gd
##
## Asserts: the report is due only from 08:00 on day 31 (a month: core/systems/season.gd) and once; the pager fires once;
## a profitable well-reviewed quiet week grades "good", a broke hurt one "poor"; the
## breakfast count is right only when nothing came; export/import keeps everything.

const LEDGER := preload("res://scripts/week_ledger.gd")


class FakeState:
	var money := 0
	var guest_reviews: Array = []
	var guests: Array = []


func _init() -> void:
	var failures: Array[String] = []

	var l = LEDGER.new()
	l.reset(850)
	var rd: int = LEDGER.RETURN_DAY
	if rd != 31:
		failures.append("Vera is not back after a month (day %d)" % rd)
	if l.is_due(rd - 1, 23.9) or l.is_due(rd, 7.9) or l.is_due(8, 9.0):
		failures.append("report due before 08:00 on day 31")
	if not l.is_due(rd, 8.0) or not l.is_due(rd + 1, 3.0):
		failures.append("report not due on day 31 08:00 / later")
	if not l.should_page(rd, 6.5) or l.should_page(rd, 7.0):
		failures.append("pager should fire exactly once")
	l.closed = true
	if l.is_due(rd, 9.0):
		failures.append("report due again after it was shown")

	# A good week: +2000, 4.2 stars, nothing came.
	var good = LEDGER.new()
	good.reset(850)
	var st := FakeState.new()
	st.money = 5850
	for i in 10:
		st.guest_reviews.append({"rating": 4 if i % 5 else 5})
	var r: Dictionary = good.report(st)
	if str(r["grade"]) != "good":
		failures.append("good week graded %s" % r["grade"])
	if not str(r["coda"]).contains("10 in the book, 10 at breakfast"):
		failures.append("quiet week coda: %s" % r["coda"])

	# A poor week: broke, bad reviews, hurt, jobs left, the Antlered Man.
	var bad = LEDGER.new()
	bad.reset(850)
	var st2 := FakeState.new()
	st2.money = 120
	for i in 6:
		st2.guest_reviews.append({"rating": 1 + i % 2})
	st2.guest_reviews.append({"rating": 1, "gave_up": true})
	for i in 7:
		bad.note_hit(20)
	bad.note_jobs_left(3)
	bad.note_enemy("silent_man", 3)
	bad.note_enemy("stalker", 3)
	bad.note_enemy("silent_man", 3)
	var r2: Dictionary = bad.report(st2)
	if str(r2["grade"]) != "poor":
		failures.append("poor week graded %s" % r2["grade"])
	if not str(r2["coda"]).contains("6 in the book, 7 at breakfast"):
		failures.append("visited week coda: %s" % r2["coda"])
	var came := ""
	for row in r2["rows"]:
		if str(row[0]) == "What came":
			came = str(row[1])
	if came != "the Silent Man, the Antlered Man":
		failures.append("what came: '%s' (one night, each once)" % came)

	var copy = LEDGER.new()
	copy.import_state(bad.export_state())
	if JSON.stringify(copy.report(st2)) != JSON.stringify(r2):
		failures.append("export/import changes the report")

	print("WEEK CHECK: good=%s poor=%s" % [r["grade"], r2["grade"]])
	for f in failures:
		print("WEEK CHECK FAIL: " + f)
	print("WEEK CHECK: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
