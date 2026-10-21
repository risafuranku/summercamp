extends SceneTree

## Headless check of Builder 98's own bits (DESIGN §5j) that are logic, not pictures:
## the Graphs' days (scripts/builder/day_graph.gd: recorded, two weeks back, today live,
## takings by kind, the save) and the shareware (scripts/builder/shareware.gd: the nag's
## rhythm, the key that comes by mail, Mega gnome locked till then, the cheats typed on
## the map).
##
##   godot --headless --path godot --script res://tools/builder98_check.gd

const DAY_GRAPH := preload("res://scripts/builder/day_graph.gd")
const SHAREWARE_PATH := "res://scripts/builder/shareware.gd"

var _failures: Array[String] = []


func _init() -> void:
	_graphs()
	if ResourceLoader.exists(SHAREWARE_PATH):
		_shareware(load(SHAREWARE_PATH))
	print("")
	if _failures.is_empty():
		print("BUILDER98 CHECK: PASS")
		quit(0)
	else:
		print("BUILDER98 CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_failures.append(msg)


func _graphs() -> void:
	var g = DAY_GRAPH.new()
	for d in range(1, 21):
		g.record(d, 1000 + d * 10, d % 6, 40.0 + d, 2.0 + d * 0.1, {"pub": d * 5})
	var s: Array = g.series("money", 20, 9999)
	_expect(s.size() == DAY_GRAPH.DAYS, "the graphs go back %d days, not %d" % [DAY_GRAPH.DAYS, s.size()])
	_expect(int(s[0][0]) == 20 - DAY_GRAPH.DAYS + 1 and int(s.back()[0]) == 20, "the days run from two weeks ago to today (%s .. %s)" % [s[0][0], s.back()[0]])
	_expect(int(s.back()[1]) == 9999, "today's point is the live one (%s)" % str(s.back()[1]))
	_expect(int(s[0][1]) == 1000 + (20 - DAY_GRAPH.DAYS + 1) * 10, "a recorded day keeps its cash (%s)" % str(s[0][1]))
	var t: Array = g.series("takings:pub", 20)
	_expect(int(t[3][1]) == int(t[3][0]) * 5, "the pub's takings by day (%s)" % str(t[3]))
	_expect(g.series("takings:rest", 20)[3][1] == null, "a business with no takings that day has no point")
	_expect(g.days.size() <= DAY_GRAPH.DAYS + 3, "old days are let go (%d kept)" % g.days.size())
	var early: Array = g.series("guests", 3)
	_expect(early.size() == 3, "on day 3 there are three days to draw (%d)" % early.size())
	var saved = JSON.parse_string(JSON.stringify(g.export_state()))
	var g2 = DAY_GRAPH.new()
	g2.import_state(saved)
	_expect(g2.series("money", 20) == g.series("money", 20) and g2.series("takings:pub", 20) == g.series("takings:pub", 20) and g2.series("rating", 20) == g.series("rating", 20), "the days survive a save")


func _shareware(SW) -> void:
	var sw = SW.new()
	sw.reset(4242)
	_expect(not sw.registered and not sw.unlocked("mega_gnome"), "a new copy is unregistered, the Mega gnome locked")
	var nags := 0
	for i in 40:
		if sw.note_build():
			nags += 1
	_expect(nags >= 2 and nags <= 5, "the nag comes after about ten builds, then now and then (%d in 40)" % nags)
	var key: String = sw.order(3)
	_expect(key != "" and sw.ordered_day == 3, "an order gives a key to come by mail (%s)" % key)
	_expect(not sw.key_arrived(3, 20.0) and not sw.key_arrived(4, 8.0), "no key filled in before its mail comes (day 4, 08:10)")
	_expect(sw.key_arrived(4, 8.2) and sw.key_arrived(6, 0.5), "the key filled in once its mail has come")
	_expect(not sw.register("WRONG-KEY"), "a wrong key does not register it")
	_expect(sw.register(key.to_lower()), "the key from the mail registers it (any case)")
	_expect(sw.registered and sw.unlocked("mega_gnome") and not sw.note_build(), "registered: no nag, the Mega gnome open")
	var c = SW.new()
	c.reset(1)
	var got := ""
	for ch in "xxBOHEMIA":
		var r: String = c.type_key(ch)
		if r != "":
			got = r
	_expect(got == "BOHEMIA", "BOHEMIA typed on the map is a cheat (%s)" % got)
	_expect(c.type_key("Q") == "", "one letter is not a cheat")
	var saved = JSON.parse_string(JSON.stringify(sw.export_state()))
	var sw2 = SW.new()
	sw2.import_state(saved)
	_expect(sw2.registered == sw.registered and sw2.builds == sw.builds and sw2.key == sw.key, "the shareware state survives a save")
