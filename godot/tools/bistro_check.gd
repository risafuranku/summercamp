extends SceneTree

## The bistro's rules (core/systems/bistro_rules.gd), pure:
##   godot --headless --path godot --script res://tools/bistro_check.gd
## Tickets are the same for the same visit on every machine, one per person; a plate is
## judged right, short or wrong; the stove and the peeler go raw, done, burnt in order.

const RULES := preload("res://core/systems/bistro_rules.gd")

var _fails := 0


func _init() -> void:
	# The same visit, the same tickets (co-op machines write them each on their own).
	var a := RULES.tickets_for("12@600", "family", 4)
	var b := RULES.tickets_for("12@600", "family", 4)
	_check(a == b, "tickets are deterministic")
	_check(a.size() == 4, "one ticket per person (got %d)" % a.size())
	var ids := {}
	for t in a:
		ids[str(t["id"])] = true
		_check(RULES.DISHES.has(str(t["dish"])), "a known dish: %s" % t["dish"])
	_check(ids.size() == 4, "ticket ids are their own")
	# Over many visits every dish turns up, and goulash sometimes comes big or with onion.
	var seen := {}
	var big := 0
	var onion := 0
	for i in 400:
		for t in RULES.tickets_for("%d@%d" % [i, i * 7], ["drunk", "tramp", "quiet_guy", "cheap_chick", "picker", "family"][i % 6], 1):
			seen[str(t["dish"])] = true
			if int((t["parts"] as Dictionary).get("dumpling", 0)) == 6:
				big += 1
			if (t["parts"] as Dictionary).has("onion"):
				onion += 1
	_check(seen.size() == 3, "all three dishes ordered (%s)" % [seen.keys()])
	_check(big > 10 and onion > 10, "big goulash %d, with onion %d" % [big, onion])
	# Judging.
	var want := {"goulash": 1, "dumpling": 4}
	var right: Dictionary = RULES.judge({"goulash": 1, "dumpling": 4}, want, 10)
	_check(bool(right["ok"]) and int(right["stars"]) == 3 and int(right["tip"]) == 4, "a right plate quickly: 3 stars, tip 4 (%s)" % right)
	var short: Dictionary = RULES.judge({"goulash": 1, "dumpling": 2}, want, 10)
	_check(bool(short["ok"]) and float(short["accuracy"]) < 1.0 and int(short["stars"]) <= 2, "two dumplings short: served, fewer stars (%s)" % short)
	var wrong: Dictionary = RULES.judge({"cheese": 1, "fries": 1}, want, 10)
	_check(not bool(wrong["ok"]), "somebody else's dish comes back")
	var slow: Dictionary = RULES.judge({"goulash": 1, "dumpling": 4}, want, RULES.PATIENCE_LATE + 30)
	_check(bool(slow["ok"]) and float(slow["speed"]) == 0.0 and int(slow["tip"]) < 4, "late: no speed (%s)" % slow)
	_check(RULES.main_of({}) == "", "an empty plate is nothing")
	# The stove, the peeler, the patience bands go in order.
	_check(RULES.cheese_side(0.0) == 0 and RULES.cheese_side(RULES.CHEESE_GOLD) == 1 and RULES.cheese_side(RULES.CHEESE_BURNT) == 2, "a side: raw, golden, burnt")
	_check(RULES.cheese_side(RULES.CHEESE_BURNT_BAD, true) == 2 and RULES.cheese_side(RULES.CHEESE_BURNT_BAD, false) == 1, "badly breaded burns sooner")
	_check(RULES.fries_state(0.0) == 0 and RULES.fries_state(RULES.FRIES_GOLD) == 1 and RULES.fries_state(RULES.FRIES_BURNT) == 2, "chips: pale, golden, burnt")
	_check(RULES.peel_state(0.0) == 0 and RULES.peel_state(RULES.PEEL_DONE) == 1 and RULES.peel_state(RULES.PEEL_OVER) == 2, "the peeler: skins, peeled, marbles")
	_check(RULES.patience_band(0) == 0 and RULES.patience_band(RULES.PATIENCE_OK) == 1 and RULES.patience_band(RULES.PATIENCE_LATE) == 2, "patience: green, amber, red")
	print("BISTRO CHECK: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("  FAIL ", what)
