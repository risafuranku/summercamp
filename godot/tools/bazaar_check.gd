extends SceneTree

## Headless check of the lost and found and its classifieds (scripts/bazaar.gd): about a
## third of the parties leave something (families more), never two of the same in the
## box; an ad put up sells from the next morning on and within a few days, at its value;
## the red shoe comes no earlier than its day, sells for a dollar and is back the morning
## after; the state survives a save (JSON turns its numbers into floats).
##
##   godot --headless --path godot --script res://tools/bazaar_check.gd

const BAZAAR := preload("res://scripts/bazaar.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	print("")
	if _failures.is_empty():
		print("BAZAAR CHECK: PASS")
		quit(0)
	else:
		print("BAZAAR CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_failures.append(msg)


func _run() -> void:
	# How often things stay behind.
	var b = BAZAAR.new(7)
	var left := 0
	var fam := 0
	for i in 400:
		if not b.on_checkout("Pepa", "Cabin 10:6", 2, "drunk").is_empty():
			left += 1
		b.reset()
	for i in 400:
		if not b.on_checkout("Novak family", "Cabin 13:6", 2, "family").is_empty():
			fam += 1
		b.reset()
	print("BAZAAR CHECK: left behind %d/400, families %d/400" % [left, fam])
	_expect(left > 100 and left < 180, "parties left something %d times in 400 (want about a third)" % left)
	_expect(fam > left, "families did not leave more behind (%d vs %d)" % [fam, left])

	# Never two of the same in the box.
	b = BAZAAR.new(8)
	for i in 300:
		b.on_checkout("G%d" % i, "Tent 16:6", 3)
	var shorts := {}
	for it in b.in_box():
		_expect(not shorts.has(it["short"]), "two of %s in the box" % it["short"])
		shorts[it["short"]] = true
	_expect(b.in_box().size() == BAZAAR.ITEMS.size(), "the box did not fill with one of each (%d)" % b.in_box().size())

	# Put up, then sold from the next morning on, within four days, at its value.
	var days_to_sell: Array = []
	for seed in range(20, 60):
		b = BAZAAR.new(seed)
		var it: Dictionary = {}
		while it.is_empty():
			it = b.on_checkout("Pepa", "Cabin 10:6", 3)
		_expect(b.list(int(it["id"]), 3), "could not put up a thing from the box")
		_expect(not b.list(int(it["id"]), 3), "the same thing went up twice")
		_expect(b.in_box().is_empty() and b.listed().size() == 1, "an ad up is still in the box")
		var same: Dictionary = b.settle(3)
		_expect(same["sold"].is_empty(), "an ad sold the day it went up")
		for d in range(4, 9):
			var r: Dictionary = b.settle(d)
			if not r["sold"].is_empty():
				days_to_sell.append(d - 3)
				_expect(int(r["sold"][0]["price"]) == int(it["value"]), "sold for %d, worth %d" % [int(r["sold"][0]["price"]), int(it["value"])])
				break
	print("BAZAAR CHECK: days to sell %s" % str(days_to_sell))
	_expect(days_to_sell.size() == 40, "%d of 40 ads never sold in five days" % (40 - days_to_sell.size()))
	for n in days_to_sell:
		_expect(int(n) <= 4, "an ad took %d days to sell" % int(n))
	_expect(days_to_sell.count(1) > 10, "too few ads sold the first morning (%d of 40)" % days_to_sell.count(1))

	# Things not put up never sell.
	b = BAZAAR.new(61)
	b.on_checkout("A", "x", 1)
	b.on_checkout("B", "y", 1)
	b.on_checkout("C", "z", 1)
	var kept: int = b.in_box().size()
	for d in range(2, 6):
		_expect(b.settle(d)["sold"].is_empty(), "something sold that was never put up")
	_expect(b.in_box().size() >= kept, "the box lost things nobody sold")

	# The shoe: not before its day; once; a dollar; back the next morning.
	var first_day: Array = []
	for seed in range(100, 130):
		b = BAZAAR.new(seed)
		var shoe: Dictionary = {}
		for d in range(1, 30):
			var r: Dictionary = b.settle(d)
			if not r["found"].is_empty():
				_expect(d >= BAZAAR.SHOE_FROM_DAY, "the shoe came on day %d" % d)
				_expect(shoe.is_empty(), "the shoe came twice")
				shoe = r["found"][0]
				first_day.append(d)
		if shoe.is_empty():
			continue
		var d0: int = int(first_day.back())
		_expect(b.list(int(shoe["id"]), d0), "the shoe could not be put up")
		var r1: Dictionary = b.settle(d0 + 1)
		_expect(r1["sold"].size() == 1 and int(r1["sold"][0]["price"]) == 1, "the shoe did not sell for a dollar the next morning")
		var r2: Dictionary = b.settle(d0 + 2)
		_expect(r2["back"].size() == 1, "the shoe was not back in the box the morning after")
		_expect(b.in_box().any(func(i): return bool(i.get("uncanny", false))), "the shoe is not in the box again")
		_expect(b.settle(d0 + 3)["back"].is_empty(), "the shoe came back twice from one sale")
	print("BAZAAR CHECK: the shoe on %d of 30 games, first days %s" % [first_day.size(), str(first_day.slice(0, 8))])
	_expect(first_day.size() >= 20, "the shoe came in only %d of 30 month-long games" % first_day.size())

	# A save: through JSON and back.
	b = BAZAAR.new(200)
	var a: Dictionary = {}
	while a.is_empty():
		a = b.on_checkout("Vlasta", "Tent 16:6", 4)
	b.list(int(a["id"]), 4)
	var c: Dictionary = {}
	while c.is_empty():
		c = b.on_checkout("Lojza", "Cabin 13:6", 4)
	var saved = JSON.parse_string(JSON.stringify(b.export_state()))
	var b2 = BAZAAR.new(201)
	b2.import_state(saved)
	_expect(b2.listed().size() == 1 and int(b2.listed()[0]["id"]) == int(a["id"]), "the ad up did not survive a save")
	_expect(b2.in_box().size() == 1 and str(b2.in_box()[0]["from"]) == "Lojza", "the box did not survive a save")
	var nxt: Dictionary = {}
	while nxt.is_empty():
		nxt = b2.on_checkout("Mirek", "Tent 16:6", 5)
	_expect(int(nxt["id"]) > int(c["id"]), "ids started again after a save")
	_expect(b2.list(int(c["id"]), 5), "a loaded thing could not be put up (id type after JSON)")
