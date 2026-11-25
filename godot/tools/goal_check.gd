extends Node

## Headless check for a sandbox camp's goals and score (core/systems/goal_rules.gd, Richard
## 25. 11. „Vybereš si je při založení“): one to three goals kept from what is chosen, how far a
## goal is by the camp's numbers, the score, the nights in a row without a lost guest (one lost
## starts again, the best kept), a goal met once, and the camp's numbers as goal_watch reads
## them (guests at once, lodgings, places, the stars).
##
##   godot --headless --path godot res://tools/goal_check.tscn

const RULES := preload("res://core/systems/goal_rules.gd")
const WATCH := preload("res://scripts/camp/goal_watch.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_expect(RULES.chosen(["guests", "nope", "money", "guests", "safe", "stars"]) == ["guests", "money", "safe"], "three at most, known ones, once each")
	_expect(is_equal_approx(RULES.progress("guests", {"peak": 25}), 0.5) and RULES.met("guests", {"peak": 50}) and not RULES.met("guests", {"peak": 49}), "fifty guests at once: half at 25, met at 50")
	_expect(RULES.met("money", {"money": 10000}) and is_equal_approx(RULES.progress("stars", {"stars": 3.0}), 0.75), "the till, the stars")
	_expect(RULES.score({}, 2) == 2000 and RULES.score({"peak": 10, "days": 4}, 0) == 220, "the score (%d)" % RULES.score({"peak": 10, "days": 4}, 0))

	var st = CoreRoot.get_state()
	var act = CoreRoot.actions
	act.set_goals(["safe", "guests"])
	_expect(st.goals["chosen"] == ["safe", "guests"] and (st.goals["done"] as Dictionary).is_empty(), "a camp made with two goals")
	act.goals_night(false)
	act.goals_night(false)
	act.goals_night(false)
	_expect(int(st.goals["safe"]) == 3 and int(st.goals["safe_best"]) == 3, "three nights without a lost guest")
	act.goals_night(true)
	_expect(int(st.goals["safe"]) == 0 and int(st.goals["safe_best"]) == 3, "a guest lost: from nought again, the best kept")
	act.goals_note(12)
	act.goals_note(7)
	_expect(int(st.goals["peak"]) == 12, "the most guests at once kept")
	_expect(act.goal_done("guests", 9) and not act.goal_done("guests", 10) and int(st.goals["done"]["guests"]) == 9, "a goal met once, on its day")

	# The camp's numbers as the watch reads them.
	st.grid.init_dimensions(28, 28, 4.0)
	st.grid.cells.clear()
	st.grid.occupy_cell(Vector2i(2, 2), "tent_1", "a", Vector2i(2, 2))
	for c in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		st.grid.occupy_cell(c, "cabin_1", "b", Vector2i(4, 4), Vector2i(2, 2))
	st.grid.occupy_cell(Vector2i(8, 8), "path", "c", Vector2i(8, 8))
	st.guests = [{"status": "active", "party_size": 4}, {"status": "sleep", "party_size": 2}, {"status": "departed", "party_size": 9}] as Array[Dictionary]
	st.guest_reviews = [{"rating": 5}, {"rating": 3}] as Array[Dictionary]
	st.biz = {"sites": {"1:1": {}, "2:2": {}}, "orders": [], "licences": []}
	var w = WATCH.new()
	var n: Dictionary = w.numbers()
	_expect(int(n["peak"]) == 12 and int(n["lodgings"]) == 2 and int(n["places"]) == 2 and is_equal_approx(float(n["stars"]), 4.0), "the numbers: %s" % [n])
	st.goals["peak"] = 0
	_expect(int(w.numbers()["peak"]) == 6, "guests in the camp now: six (%s)" % [w.numbers()["peak"]])
	w.free()

	if _failures.is_empty():
		print("GOAL CHECK: PASS")
	else:
		print("GOAL CHECK: FAIL")
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
