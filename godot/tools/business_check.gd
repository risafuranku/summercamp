extends Node

## Headless check for the businesses (core/systems/business_rules.gd, actions biz_*).
##
##   godot --headless --path godot res://tools/business_check.tscn
##
## Run as a SCENE (CoreRoot / EventBus autoloads). Asserts:
## - a pub's books are made with the shelves stocked, and go when the pub goes;
## - an order is paid when sent, refused without the cash, refused past the shelf space;
## - the van unloads what is due (capped by the shelves), postponed when not signed for;
## - a sale takes the goods and rings up the money; short shelves sell nothing;
## - the day's close pays the hand's wage and rolls the books, a week of history kept;
## - the pub, bistro, Jednota and corn stand earn no flat daily income any more;
## - the licence for a PC program is bought once.

const RULES = preload("res://core/systems/business_rules.gd")
const BUSINESS = preload("res://scripts/business/business_runtime.gd")

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	var a = CoreRoot.actions
	state.grid.cells.clear()
	state.biz = {}
	state.money = 1000

	var key := "4:4"
	CoreRoot.get_state().grid.occupy_cell(Vector2i(4, 4), "pub", "pub_4_4", Vector2i(4, 4))
	var site: Dictionary = a.biz_site(key, "pub")
	_expect(not site.is_empty() and str(site["kind"]) == "pub", "a pub gets its books")
	_expect(int(site["stock"]["beer"]) == int(RULES.goods("pub")["beer"]["start"]), "the shelves start stocked")

	# An order: two kegs of beer, a box of rum.
	var cost := RULES.order_cost("pub", {"beer": 2, "rum": 1})
	_expect(cost == 2 * 60 + 26 + RULES.DELIVERY_FEE, "the order costs the packs and the van (%d)" % cost)
	_expect(a.biz_order(key, {"beer": 2, "rum": 1}, 5), "the order goes")
	_expect(state.money == 1000 - cost, "the order is paid when sent")
	_expect(BUSINESS.on_order(key, "beer") == 100, "two kegs on order (%d)" % BUSINESS.on_order(key, "beer"))
	_expect(RULES.room_for("pub", "beer", int(site["stock"]["beer"]), BUSINESS.on_order(key, "beer")) == 0, "no room for a third keg")
	state.money = 5
	_expect(not a.biz_order(key, {"kofola": 1}, 5), "no order without the cash")
	_expect(state.biz["orders"].size() == 1, "nothing was ordered then")
	state.money = 1000

	# The van: not due yet, then postponed, then unloaded.
	_expect(a.biz_receive(4) == 0, "nothing unloaded before it is due")
	a.biz_postpone(5)
	_expect(int(state.biz["orders"][0]["due_day"]) == 6, "missed, it comes the next day")
	_expect(a.biz_receive(6) == 1, "the van unloads the order")
	_expect(int(site["stock"]["beer"]) == 140 and int(site["stock"]["rum"]) == 30, "on the shelves (beer %d, rum %d)" % [int(site["stock"]["beer"]), int(site["stock"]["rum"])])

	# Selling by hand: off the shelf, into the till.
	var m0: int = state.money
	_expect(BUSINESS.sell(key, {"beer": 1}, 5), "a pint sold")
	_expect(int(site["stock"]["beer"]) == 139 and state.money == m0 + 5, "a pint off, five dollars in")
	_expect(int(site["today"]["by_hand"]) == 1 and int(site["today"]["takings"]) == 5, "the books count it")
	site["stock"]["kofola"] = 0
	_expect(not BUSINESS.sell(key, {"kofola": 1}, 2), "nothing sold off an empty shelf")
	_expect(state.money == m0 + 5, "and no money for it")

	# A hand, the wage at the day's end.
	_expect(a.biz_hire(key, "Lojza", 3), "a hand taken on")
	var m1: int = state.money
	var wages: int = a.biz_close_day()
	_expect(wages == int(RULES.info("pub")["wage"]) and state.money == m1 - wages, "the wage is paid (%d)" % wages)
	_expect(int(site["yesterday"]["takings"]) == 5 and int(site["today"]["takings"]) == 0, "the books roll over")
	a.biz_fire(key)
	_expect(a.biz_close_day() == 0, "no wage with nobody")
	for i in 8:
		a.biz_close_day()
	_expect((site.get("history", []) as Array).size() == 7, "a week of history kept for the charts (%d)" % (site.get("history", []) as Array).size())

	# The baskets are sensible.
	var b := RULES.basket("rest", 3, 0.42)
	var n := 0
	for g in b:
		n += int(b[g])
	_expect(n == 3, "a basket of three dishes (%s)" % str(b))
	_expect(RULES.needs_for("rest", {"goulash": 2}).get("dumplings", 0) == 2, "goulash comes with dumplings")

	# No flat income for the businesses.
	var econ = load("res://scripts/economy_manager.gd").new()
	add_child(econ)
	_expect(econ.calculate_day_income() == 0, "a pub alone earns nothing flat a day")

	# The pub goes, its books go.
	state.grid.cells.clear()
	a.biz_prune([])
	_expect(not (state.biz["sites"] as Dictionary).has(key), "the books go with the pub")

	# The licence.
	state.money = 500
	_expect(a.biz_buy_licence("pub") and state.money == 500 - int(RULES.info("pub")["licence"]), "the licence is bought")
	_expect(a.biz_buy_licence("pub") and state.money == 500 - int(RULES.info("pub")["licence"]), "and only paid once")

	print("")
	if _failures.is_empty():
		print("BUSINESS CHECK: PASS")
		get_tree().quit(0)
	else:
		print("BUSINESS CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
