extends SceneTree

## The bowling rules (core/systems/bowling_rules.gd): the card's arithmetic (300, all
## spares, open frames, a game under way), the ball's way and its way back, and the deck:
## the pocket strikes most of the time, a ball on the nose leaves splits more often, the
## gutter takes nothing, the same ball the same pins.
##   godot --headless --path godot --script res://tools/bowling_check.gd

const R := preload("res://core/systems/bowling_rules.gd")
var _fails: Array = []


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


func _init() -> void:
	var c := R.card([10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10])
	_expect(int(c["total"]) == 300 and bool(c["done"]), "a perfect game is 300 (%s)" % c["total"])
	var spares: Array = []
	for i in 10:
		spares.append_array([5, 5])
	spares.append(5)
	c = R.card(spares)
	_expect(int(c["total"]) == 150 and bool(c["done"]), "all 5-spares and a 5 is 150 (%s)" % c["total"])
	var open: Array = []
	for i in 10:
		open.append_array([9, 0])
	c = R.card(open)
	_expect(int(c["total"]) == 90 and bool(c["done"]), "nine and a miss ten times is 90 (%s)" % c["total"])
	c = R.card([10, 3])
	_expect(int(c["frames"][0]["total"]) == -1 and int(c["frame"]) == 1 and int(c["ball"]) == 1, "a strike waits for its bonus (%s)" % [c["frames"][0]])
	_expect(not bool(c["done"]), "a game under way is not done")
	c = R.card([7, 3, 4, 2])
	_expect(int(c["frames"][0]["total"]) == 14 and int(c["frames"][1]["total"]) == 20, "a spare takes the next ball (%s)" % [c["frames"]])
	_expect(str(c["frames"][0]["marks"]) == str(["7", "/"]), "a spare is marked / (%s)" % [c["frames"][0]["marks"]])
	# The tenth frame: a strike earns two more balls, an open frame none.
	var t10: Array = []
	for i in 9:
		t10.append_array([0, 0])
	c = R.card(t10 + [10, 10, 10])
	_expect(int(c["total"]) == 30 and bool(c["done"]), "three strikes in the tenth is 30 (%s)" % c["total"])
	c = R.card(t10 + [3, 4])
	_expect(int(c["total"]) == 7 and bool(c["done"]), "an open tenth ends the game (%s)" % c["total"])
	c = R.card(t10 + [6, 4])
	_expect(not bool(c["done"]) and int(c["ball"]) == 2, "a spare in the tenth earns a third ball")
	# The way down and back.
	var back := R.to_entry(0.065, -0.06, 7.5, -0.6)
	var fwd := R.roll(float(back["x0"]), float(back["aim"]), float(back["speed0"]), -0.6)
	_expect(not bool(fwd["gutter"]) and absf(float(fwd["x"]) - 0.065) < 0.03, "roll() of to_entry() comes back to the pocket (%s)" % fwd["x"])
	var gut := R.roll(0.4, 0.05, 7.0, 0.0)
	_expect(bool(gut["gutter"]), "a ball aimed off the lane finds the gutter")
	# The deck.
	var all_up := [true, true, true, true, true, true, true, true, true, true]
	var strikes := 0
	var nose := 0
	var n := 200
	for i in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var pocket := {"x": 0.065 + rng.randfn(0.0, 0.012), "angle": -0.06 + rng.randfn(0.0, 0.006), "speed": 7.6}
		if (R.strike(pocket, all_up, i)["down"] as Array).size() == 10:
			strikes += 1
		var head := {"x": rng.randfn(0.0, 0.01), "angle": rng.randfn(0.0, 0.005), "speed": 7.6}
		if (R.strike(head, all_up, i)["down"] as Array).size() == 10:
			nose += 1
	print("BOWLING CHECK: pocket strikes %d/%d, on the nose %d/%d" % [strikes, n, nose, n])
	_expect(strikes > n * 0.45, "the pocket strikes most of the time (%d/%d)" % [strikes, n])
	_expect(nose < strikes, "on the nose strikes less than the pocket (%d vs %d)" % [nose, strikes])
	_expect((R.strike({"gutter": true}, all_up, 1)["down"] as Array).is_empty(), "the gutter takes nothing")
	var e := {"x": 0.03, "angle": -0.03, "speed": 7.0}
	_expect(str(R.strike(e, all_up, 7)["down"]) == str(R.strike(e, all_up, 7)["down"]), "the same ball takes the same pins")
	# A light ball into a lone 10 pin.
	var ten := [false, false, false, false, false, false, false, false, false, true]
	var spots := R.pin_spots()
	var r10 := R.strike({"x": (spots[9] as Vector2).x - 0.05, "angle": 0.0, "speed": 6.0}, ten, 3)
	_expect((r10["down"] as Array) == [10], "a ball into the lone 10 pin takes it (%s)" % [r10["down"]])
	if _fails.is_empty():
		print("BOWLING CHECK: PASS")
	else:
		print("BOWLING CHECK: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("  - " + f)
	quit()
