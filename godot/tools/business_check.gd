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
## - the day's close pays the hands' wages and rolls the books, a week of history kept;
## - the goods go off by their lots (the oldest first), are thrown out as waste;
## - gear is bought once; one order for every place brings one van;
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
	var lojza := RULES.person("lojza", "pub")
	_expect(a.biz_hire(key, lojza, 3), "a hand taken on")
	_expect(str(site["crew"][0]["role"]) == "tap" and str(site["crew"][0]["shift"]) == "day", "at the front job, by day")
	var m1: int = state.money
	var wages: int = int(a.biz_close_day(3)["wages"])
	_expect(wages == int(lojza["wage"]) and state.money == m1 - wages, "the wage is paid (%d)" % wages)
	_expect(int(site["yesterday"]["takings"]) == 5 and int(site["today"]["takings"]) == 0, "the books roll over")
	a.biz_fire(key, "lojza")
	_expect(int(a.biz_close_day(4)["wages"]) == 0, "no wage with nobody")
	for i in 8:
		a.biz_close_day()

	# The lots of a good: the oldest sold first (nothing goes off: the user 7. 11.).
	state.grid.occupy_cell(Vector2i(8, 8), "vecerka", "vecerka_8_8", Vector2i(8, 8))
	var shop: Dictionary = a.biz_site("8:8", "vecerka")
	shop["stock"]["roll"] = 0
	shop["lots"]["roll"] = []
	_expect(a.biz_order("8:8", {"roll": 1}, 10), "rolls ordered")
	a.biz_receive(10)
	_expect(int(shop["stock"]["roll"]) == 60 and (shop["lots"]["roll"] as Array).size() == 1, "the rolls in, one lot (%s)" % str(shop["lots"]["roll"]))
	_expect(a.biz_take("8:8", {"roll": 10}) and int(shop["lots"]["roll"][0][0]) == 50, "the oldest lot sold first")
	state.money = 5000
	_expect(a.biz_buy_gear("8:8", "pallet"), "gear bought")
	_expect(not a.biz_buy_gear("8:8", "pallet"), "gear is bought once")

	# One order for every place: one van.
	var m2: int = state.money
	_expect(a.biz_order_all({"8:8": {"milk": 1}, key: {"rum": 1}}, 14), "one order for two places")
	var both := RULES.goods_cost("vecerka", {"milk": 1}) + RULES.goods_cost("pub", {"rum": 1}) + RULES.DELIVERY_FEE
	_expect(m2 - state.money == both, "one van's fee for the lot (%d, %d)" % [m2 - state.money, both])

	# A hand not paid two days leaves.
	_expect(a.biz_hire("8:8", RULES.person("zdenka", "vecerka"), 14), "Zdenka taken on")
	state.money = 0
	var c1: Dictionary = a.biz_close_day(14)
	_expect((shop["crew"] as Array).size() == 1 and int(shop["crew"][0]["unpaid"]) == 1, "a day unpaid: still there, owed")
	var c2: Dictionary = a.biz_close_day(15)
	_expect((shop["crew"] as Array).is_empty() and (c2["left"] as Array).has("Zdenka"), "two days unpaid: gone (%s)" % str(c2))
	state.money = 1000
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

	# The money (8. 11.): what a place's day made and cost, the wages before the close, what a
	# good goes through in a day, the shelves filled up, the camp's own book.
	state.grid.cells.clear()
	a.biz_prune([])
	state.biz["orders"] = []
	state.biz.erase("camp")
	state.money = 50000
	state.grid.occupy_cell(Vector2i(12, 12), "pub", "pub_12_12", Vector2i(12, 12))
	var ms: Dictionary = a.biz_site("12:12", "pub")
	ms["history"] = []
	var hand := RULES.person("lojza", "pub")
	_expect(a.biz_hire("12:12", hand, 20), "a hand for the money's pub")
	_expect(BUSINESS.sell("12:12", {"beer": 12}, 60), "a day's sale")
	var cost_used := int(round(RULES.unit_cost("pub", "beer") * 12))
	var wage_due := int(hand["wage"])
	var so_far := RULES.day_money(ms["today"])
	_expect(int(so_far["takings"]) == 60 and int(so_far["goods"]) == cost_used and int(so_far["wages"]) == 0, "the day so far (%s)" % str(so_far))
	var live := RULES.today_money(ms, 20)
	_expect(int(live["wages"]) == wage_due and int(live["profit"]) == 60 - cost_used - wage_due, "today counts the wage it will pay (%s)" % str(live))
	_expect(int((ms["today"]["used"] as Dictionary).get("beer", 0)) == 12, "what was used is written")
	var fee_due: int = a.van_fee(21)
	_expect(fee_due > 0 and a.biz_order("12:12", {"rum": 1}, 21), "an order")
	_expect(int(ms["today"].get("van", 0)) == fee_due, "the van's fee goes on the place's day")
	a.biz_add_order("12:12", {"rum": 1}, RULES.goods_cost("pub", {"rum": 1}) + 10, 30)
	_expect(int(ms["today"].get("van", 0)) == fee_due + 10, "the other warden's order: its van too")
	a.biz_short("12:12", 7)
	_expect(int(ms["today"].get("short_money", 0)) == 7, "what went missing is written")
	a.note_camp("lodging", 300)
	a.note_camp("power", 40)
	a.note_camp("invest", 1000)
	var left_here := 60 - cost_used - wage_due - fee_due - 10 - 7
	var c_today := RULES.camp_day(state.biz, 0, 20)
	_expect(int(c_today["income"]) == 360 and int(c_today["invest"]) == 1000, "the camp's day, what came in (%s)" % str(c_today))
	_expect(int(c_today["profit"]) == 300 - 40 + left_here, "the camp's day: what is left, the investment apart (%s)" % str(c_today))
	_expect(int((c_today["places"] as Dictionary)["12:12"]) == left_here, "the place by what it left")
	var told: Array = []
	a.biz_remote = func(kind: String, args: Array) -> void: told.append([kind, args])
	a.note_camp("repairs", 5)
	a.biz_remote = Callable()
	_expect(told.size() == 1 and str(told[0][0]) == "camp" and str(told[0][1][0]) == "repairs" and int(told[0][1][1]) == 5, "the other warden's goes to the host's book")
	a.biz_close_day(20)
	_expect(int(ms["yesterday"].get("wages", -1)) == wage_due, "the close writes the wages")
	_expect(int((ms["total"] as Dictionary).get("profit", 0)) == left_here, "the place's whole run (%s)" % str(ms["total"]))
	var c_closed := RULES.camp_day(state.biz, 1)
	_expect(int(c_closed["lodging"]) == 300 and int(c_closed["wages"]) == wage_due and int(c_closed["cash"]) == state.money, "the camp's closed day (%s)" % str(c_closed))
	_expect(int(RULES.camp_day(state.biz, 0)["lodging"]) == 0, "a new day in the camp's book")
	_expect(is_equal_approx(RULES.use_per_day(ms, "beer"), 12.0), "what a good goes through in a day (%.2f)" % RULES.use_per_day(ms, "beer"))
	ms["stock"]["beer"] = 24
	_expect(RULES.days_left(ms, "beer") == 2, "the shelf lasts two days (%d)" % RULES.days_left(ms, "beer"))
	_expect(RULES.days_left(ms, "kofola") == -1, "nothing known of a good nobody bought")
	_expect(int(RULES.fill_order("pub", ms, {}).get("beer", 0)) >= 1, "filled up for a few days")
	ms["stock"]["beer"] = RULES.cap_of("pub", "beer", ms)
	_expect(not RULES.fill_order("pub", ms, {}).has("beer"), "a full shelf is left alone")

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
