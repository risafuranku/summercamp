extends SceneTree

## Headless check of the camp on Goggle (scripts/reviews/goggle.gd): a new camp's page
## has last summer's reviews and a low rating, only the first blueprints open; good
## guests' reviews raise the rating and open the next tier (and it stays open); a review
## booked for removal is gone the next morning (or, caught, stays and flags the page with
## the rating down), each removal dearer than the one before; an apology may bring a
## star by the morning; the state survives a save (JSON turns its numbers into floats).
##
##   godot --headless --path godot --script res://tools/goggle_check.gd

const GOGGLE := preload("res://scripts/reviews/goggle.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	print("")
	if _failures.is_empty():
		print("GOGGLE CHECK: PASS")
		quit(0)
	else:
		print("GOGGLE CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_failures.append(msg)


func _guest(name: String, stars: int, day: int, id: int) -> Dictionary:
	return {"name": name, "archetype": "family", "rating": stars, "text": "x", "day": day, "stay_nights": 2, "guest_id": id}


func _run() -> void:
	var g = GOGGLE.new(7)
	g.reset(7)
	_expect(g.count() == GOGGLE.OLD_REVIEWS.size(), "a new camp's page has %d old reviews, not %d" % [GOGGLE.OLD_REVIEWS.size(), g.count()])
	var start: float = g.rating(1)
	print("start rating %.1f (%d)" % [start, g.count()])
	_expect(start > 1.5 and start < 3.0, "the old page should rate it low (2-3), it is %.1f" % start)
	_expect(g.tier == 0, "only the first blueprints open on a new camp (tier %d)" % g.tier)
	_expect(g.unlocked("tent_1") and g.unlocked("pub") and not g.unlocked("lake_slide") and not g.unlocked("upgrade:2"), "the first tier opens tents and the pub, not the slide or upgrades")
	# Good guests.
	for i in 20:
		g.add_guest_review(_guest("G%d" % i, 5, 2 + i / 4, 100 + i), 2)
	var opened: int = g.check_tier(8)
	print("after 20 good: %.1f (%d), tier %d" % [g.rating(8), g.count(), g.tier])
	_expect(g.rating(8) > 4.0, "twenty five-star reviews should lift it over 4 (%.1f)" % g.rating(8))
	_expect(opened >= 2 and g.unlocked("playground") and g.unlocked("upgrade:2"), "the good reviews should open the playground and the upgrades (tier %d)" % g.tier)
	# A tier stays open when the rating falls back.
	var tier_before: int = g.tier
	for i in 30:
		g.add_guest_review(_guest("B%d" % i, 1, 9, 200 + i), 9)
	g.check_tier(9)
	_expect(g.tier == tier_before, "a tier once open stays open (%d -> %d)" % [tier_before, g.tier])
	# Removal: dearer each time, gone by the morning (or caught).
	var bad: Array = g.shown().filter(func(e): return int(e["stars"]) == 1 and not bool(e["old"]))
	var c1: int = g.removal_cost()
	_expect(g.request_removal(int(bad[0]["id"]), 9), "a bad review can be booked for removal")
	var c2: int = g.removal_cost()
	_expect(c2 > c1, "the second removal costs more (%d, %d)" % [c1, c2])
	_expect(not g.request_removal(int(bad[0]["id"]), 9), "the same review cannot be booked twice")
	var n_before: int = g.count()
	var r: Dictionary = g.settle(10)
	_expect((r["removed"] as Array).size() + (r["caught"] as Array).size() == 1, "the booked removal is settled the next morning")
	if not (r["removed"] as Array).is_empty():
		_expect(g.count() == n_before - 1, "a removed review is off the page")
	_expect(g.settle(10)["removed"].is_empty(), "a morning is settled once")
	# Caught: flagged, the rating down for the days of the flag.
	var g2 = GOGGLE.new(3)
	g2.reset(3)
	var caught := 0
	for i in 40:
		var e: Dictionary = g2.add_guest_review(_guest("C%d" % i, 2, 2, 300 + i), 2)
		g2.request_removal(int(e["id"]), 2 + i)
		var rr: Dictionary = g2.settle(3 + i)
		if not (rr["caught"] as Array).is_empty():
			caught += 1
			var d := 3 + i
			_expect(g2.flagged(d), "a caught removal flags the page")
			_expect(g2.rating(d) <= snappedf(g2.average(), 0.1), "a flagged page rates lower")
			break
	_expect(caught == 1, "Goggle catches a removal sooner or later")
	# An apology may bring a star.
	var g3 = GOGGLE.new(11)
	g3.reset(11)
	var edited := 0
	for i in 30:
		var e: Dictionary = g3.add_guest_review(_guest("A%d" % i, 1, 2, 400 + i), 2)
		g3.reply(int(e["id"]), "sorry", 2)
	edited = (g3.settle(3)["edited"] as Array).size()
	print("apologies: %d of 30 edited" % edited)
	_expect(edited > 3 and edited < 25, "some apologies bring a star, not all (%d of 30)" % edited)
	# The save.
	var saved = JSON.parse_string(JSON.stringify(g.export_state()))
	var g4 = GOGGLE.new(1)
	g4.import_state(saved)
	_expect(g4.count() == g.count() and is_equal_approx(g4.rating(10), g.rating(10)) and g4.tier == g.tier and g4.removal_cost() == g.removal_cost(), "the page survives a save")
