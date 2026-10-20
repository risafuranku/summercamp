extends Node

## Headless check for the businesses' polish (the brief of 20. 10., "podniky"; DESIGN.md
## §7b): what was added across the four places and their shared systems.
##
##   godot --headless --path godot res://tools/podniky_check.tscn
##
## Run as a SCENE (CoreRoot / EventBus autoloads). Asserts:
## - the guests' thirst: it falls by day, their own water at the lodging tops it up to a
##   point, the businesses fill it by the ladder (corn < pub < bistro), the Jednota's bag
##   keeps their needs up for days and is used up; the evening rush sends them sooner;
## - the corn stand's drinks: a drink slip beside the cob's, a cup of tea poured to the
##   line and handed over (the tea off the books), a short one sent back; the drinks'
##   hand pours the oldest;
## - the bistro: a sausage on the grill, turned, brown both sides onto the rack, plated at
##   the pass with mustard and bread; the soup of the day and a bottle at the bufet; the
##   grill's and the bufet's hands;
## - the Jednota: the new goods on the rack (cards, magazines, rum) and the cigarettes
##   behind the till; the deli counter's orders, a slice off the piece (a kilo off the
##   books when it runs out), a parcel cut to the weight into the basket and its price in
##   the bill, a short one refused; the deli's hand;
## - the shared: the Z report's mark and advice, the goods' cost in it, a warm hand's
##   serve cheers more than a sour one's.

const NEEDS := preload("res://core/systems/guest_needs_system.gd")
const CORN := preload("res://core/systems/corn_rules.gd")
const BISTRO := preload("res://core/systems/bistro_rules.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const CORNSTAND := preload("res://scripts/corn/cornstand.gd")
const KITCHEN := preload("res://scripts/bistro/kitchen.gd")
const JEDNOTA := preload("res://scripts/jednota/jednota.gd")
const JRULES := preload("res://core/systems/jednota_rules.gd")
const CORN_KEY := "11:11"
const REST_KEY := "4:4"
const SHOP_KEY := "14:4"

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_needs()
	var state = CoreRoot.get_state()
	var a = CoreRoot.actions
	state.grid.cells.clear()
	state.biz = {}
	state.money = 5000
	state.day = 3
	GuestManager._last_known_day = 3
	GuestManager._last_known_hour = 13
	GuestManager._last_known_minute = 0
	state.grid.occupy_cell(Vector2i(11, 11), "corn_stand", "corn_stand_11_11", Vector2i(11, 11))
	state.grid.occupy_cell(Vector2i(4, 4), "restaurant", "restaurant_4_4", Vector2i(4, 4))
	state.grid.occupy_cell(Vector2i(14, 4), "vecerka", "vecerka_14_4", Vector2i(14, 4))
	a.biz_site(CORN_KEY, "corn_stand")
	a.biz_site(REST_KEY, "restaurant")
	a.biz_site(SHOP_KEY, "vecerka")
	await _corn(state, a)
	await _bistro(state, a)
	await _jednota(state, a)
	_shared(state, a)
	print("")
	if _failures.is_empty():
		print("PODNIKY CHECK: PASS")
		get_tree().quit(0)
	else:
		print("PODNIKY CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


# ── the guests' needs ────────────────────────────────────────────────────────

func _needs() -> void:
	var n := {"energy": 80.0, "hunger": 80.0, "thirst": 80.0, "bladder": 80.0, "hygiene": 80.0, "fun": 80.0, "safety": 80.0}
	var after: Dictionary = NEEDS.decay_needs(n, "drunk", 120.0, {})
	_expect(float(after["thirst"]) < 80.0 - 20.0, "thirst falls by day (%.1f)" % float(after["thirst"]))
	var dry := n.duplicate()
	dry["thirst"] = 20.0
	var home: Dictionary = NEEDS.decay_needs(dry, "quiet_guy", 200.0, {"sleeping": true})
	_expect(float(home["thirst"]) > 30.0 and float(home["thirst"]) <= NEEDS.HOME_WATER + 0.01, "their own water at the lodging, up to a point (%.1f)" % float(home["thirst"]))
	var corn := NEEDS.apply_facility(dry, {"thirst": 25.0}, "family", "corn_stand")
	var pub := NEEDS.apply_facility(dry, {"thirst": 60.0}, "family", "pub")
	_expect(float(pub["thirst"]) > float(corn["thirst"]), "the pub's drink is more than the stand's")
	# The Jednota's bag: keeps them going, and is used up.
	var bag := NEEDS.add_stash({}, "vecerka")
	_expect(float(bag.get("hunger", 0.0)) > 0.0 and float(bag.get("thirst", 0.0)) > 0.0 and float(bag.get("hygiene", 0.0)) > 0.0, "a basket from the Jednota in the bag (%s)" % str(bag))
	var low := n.duplicate()
	low["hunger"] = 30.0
	var used: Array = NEEDS.use_stash(low, bag, 60.0)
	_expect(float(used[0]["hunger"]) > 30.0 and float(used[1].get("hunger", 0.0)) < float(bag["hunger"]), "the bag tops hunger up and empties")
	var full: Array = NEEDS.use_stash(n, bag, 60.0)
	_expect(float(full[1].get("hunger", 0.0)) == float(bag["hunger"]), "a full guest leaves the bag alone")
	# The rush: at seven in the evening a guest still three quarters fed goes for supper.
	var fed := n.duplicate()
	fed["hunger"] = 75.0
	var fac := [{"key": "4:4", "coord": Vector2i(4, 4), "type": "restaurant", "label": "Bistro", "services": {"hunger": 95.0, "thirst": 55.0}, "capacity": 8, "use_minutes": 40, "working": true, "condition": 1.0}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var noon: Dictionary = NEEDS.pick_goal(fed, "quiet_guy", fac, Vector2i(1, 1), {}, rng, 12.0)
	rng.seed = 7
	var rush: Dictionary = NEEDS.pick_goal(fed, "quiet_guy", fac, Vector2i(1, 1), {}, rng, 19.0)
	_expect(str(noon.get("kind", "")) != "visit" or str(noon.get("need", "")) != "hunger", "at noon three quarters fed is fed (%s)" % str(noon))
	_expect(str(rush.get("kind", "")) == "visit", "at seven they go for supper (%s)" % str(rush))


# ── the corn stand's drinks ──────────────────────────────────────────────────

func _corn(state, a) -> void:
	var stand = CORNSTAND.of(get_tree())
	var now: int = CORNSTAND.now_min()
	var guests: Array = []
	for i in 6:
		guests.append({"id": 700 + i, "name": "Corn%d Test" % i, "archetype": ["family", "drunk", "picker"][i % 3], "status": "active",
			"needs": NEEDS.default_needs(null), "party_size": 1, "activity": {"kind": "visit", "target_key": CORN_KEY, "start": now - 20, "arrive": now - 20, "end": now + 300}})
	state.guests.clear()
	for g in guests:
		state.guests.append(g)
	var drinks: Array = stand.tickets(CORN_KEY, "drink")
	var cobs: Array = stand.tickets(CORN_KEY, "cob")
	_expect(not drinks.is_empty() and cobs.size() >= 6, "drink slips beside the cobs (%d drinks, %d cobs)" % [drinks.size(), cobs.size()])
	var site: Dictionary = BUSINESS.site(CORN_KEY)
	_expect(int(site["stock"].get("tea", 0)) > 0 and int(site["stock"].get("limo", 0)) > 0, "a new stand has tea and lemonade")
	if drinks.is_empty():
		return
	var t: Dictionary = drinks[0]
	var kind := str(t["kind"])
	var short: Dictionary = stand.serve_drink(CORN_KEY, t, kind, 0.3, true)
	_expect(not bool(short["ok"]), "half a cup is sent back")
	var g0 := int(site["stock"][kind])
	var m0: int = state.money
	var ok: Dictionary = stand.serve_drink(CORN_KEY, t, kind, 0.9, true)
	_expect(bool(ok["ok"]) and int(site["stock"][kind]) == g0 - 1 and state.money > m0, "a drink to the line served: off the books, the money in (%s)" % str(ok))
	_expect(stand.tickets(CORN_KEY, "drink").size() == drinks.size() - 1, "that slip off the rail")
	if drinks.size() > 1:
		var t2: Dictionary = drinks[1]
		var wrong := "limo" if str(t2["kind"]) == "tea" else "tea"
		_expect(not bool(stand.serve_drink(CORN_KEY, t2, wrong, 0.9, true)["ok"]), "the wrong drink is sent back")
		if str(t2["kind"]) == "limo":
			_expect(not bool(stand.serve_drink(CORN_KEY, t2, "limo", 0.9, false)["ok"]), "an open bag is sent back")
	# The drinks' hand.
	var p := RULES.person("klara", "corn")
	p["role"] = "drinks"
	p["shift"] = "day"
	a.biz_hire(CORN_KEY, p, 1)
	var before: int = stand.tickets(CORN_KEY, "drink").size()
	if before > 0:
		_expect(stand._crew_drink(CORN_KEY, false), "the drinks' hand pours one")
		_expect(stand.tickets(CORN_KEY, "drink").size() == before - 1, "its slip off the rail")
	site["crew"] = []
	# The station as a player works it.
	var st: Node3D = load("res://scripts/corn/drinks_station.gd").new()
	var surf: Dictionary = load("res://scripts/corn/stand_layout.gd").SURFACES["drinks"]
	st.set("building_key", CORN_KEY)
	st.set("station", "drinks")
	st.set("surf_at", surf["at"])
	st.set("surf_size", surf["size"])
	st.set("surf_yaw", float(surf["yaw"]))
	st.set("state", stand)
	add_child(st)
	await get_tree().process_frame
	var left: Array = stand.tickets(CORN_KEY, "drink")
	if not left.is_empty():
		var want := str(left[0]["kind"])
		st.call("debug_click", "cups" if want == "tea" else "bags")
		st.call("debug_pour", 1.0 / float(CORN.DRINKS[want]["rate"]) * 0.88)
		if want == "limo":
			st.call("debug_click", "straws")
		st.call("debug_click", "drink")
		_expect(stand.tickets(CORN_KEY, "drink").size() == left.size() - 1, "the drinks station: a %s poured and handed over" % want)
	st.queue_free()
	state.guests.clear()


# ── the bistro's grill and bufet ─────────────────────────────────────────────

func _bistro(state, a) -> void:
	var k = KITCHEN.of(get_tree())
	if k == null:
		k = KITCHEN.new()
		get_tree().root.add_child(k)
		await get_tree().process_frame
	var now: int = KITCHEN.now_min()
	var guests: Array = []
	for i in 12:
		guests.append({"id": 800 + i, "name": "Rest%d Test" % i, "archetype": ["drunk", "tramp", "family", "picker"][i % 4], "status": "active",
			"needs": NEEDS.default_needs(null), "party_size": 1, "activity": {"kind": "visit", "target_key": REST_KEY, "start": now - 30, "arrive": now - 30, "end": now + 300}})
	state.guests.clear()
	for g in guests:
		state.guests.append(g)
	var all: Array = k.tickets(REST_KEY)
	var pass_t: Array = k.tickets(REST_KEY, "pass")
	var bufet: Array = k.tickets(REST_KEY, "bufet")
	_expect(pass_t.size() + bufet.size() == all.size() and not bufet.is_empty(), "the tickets split between the pass and the bufet (%d, %d)" % [pass_t.size(), bufet.size()])
	# The grill: on, cooked, turned, cooked, onto the rack.
	var stock0 := BUSINESS.stock_of(REST_KEY, "sausage")
	_expect(stock0 > 0, "sausages in the books (%d)" % stock0)
	var grill: Node3D = _station("grill", k)
	await get_tree().process_frame
	grill.call("debug_click", "tray")
	_expect(BUSINESS.stock_of(REST_KEY, "sausage") == stock0 - 1 and not (k.site(REST_KEY)["grill"][0] as Dictionary).is_empty(), "a sausage onto the grill")
	grill.call("debug_cook", BISTRO.GRILL_GOLD + 1.0)
	grill.call("debug_click", "slot:0")
	_expect(int(k.site(REST_KEY)["grill"][0]["down"]) == 1, "turned over")
	grill.call("debug_cook", BISTRO.GRILL_GOLD + 1.0)
	grill.call("debug_click", "slot:0")
	_expect(k.prep(REST_KEY, "sausage") == 1 and (k.site(REST_KEY)["grill"][0] as Dictionary).is_empty(), "brown both sides: onto the rack")
	grill.queue_free()
	# The pass: a sausage plate for a sausage ticket.
	var sausage_t := {}
	for t in pass_t:
		if str(t["dish"]) == "sausage":
			sausage_t = t
			break
	if not sausage_t.is_empty():
		var v: Dictionary = k.serve(REST_KEY, sausage_t, {"sausage": 1, "mustard": 1, "bread": 1}, 0.9)
		_expect(bool(v["ok"]) and int(v["stars"]) >= 2, "a sausage with mustard and bread out of the hatch (%s)" % str(v))
	# The bufet: the soup of the day, a bottle.
	var bst: Node3D = _station("bufet", k)
	await get_tree().process_frame
	var soup_t := {}
	var drink_t := {}
	for t in k.tickets(REST_KEY, "bufet"):
		if str(t["dish"]) == "soup" and soup_t.is_empty():
			soup_t = t
		elif BISTRO.DRINKS.has(str(t["dish"])) and drink_t.is_empty():
			drink_t = t
	if not soup_t.is_empty():
		var n0: int = k.tickets(REST_KEY, "bufet").size()
		var level0 := int(k.site(REST_KEY)["soup"]["level"])
		bst.call("debug_click", "stack")
		bst.call("debug_click", "pot")
		bst.call("debug_click", "pot")
		bst.call("debug_click", "bowl")
		_expect(k.tickets(REST_KEY, "bufet").size() <= n0 - 1 and int(k.site(REST_KEY)["soup"]["level"]) == level0 - 1, "a bowl of the soup of the day over the counter")
	if not drink_t.is_empty():
		var kind := str(drink_t["dish"])
		var b0 := BUSINESS.stock_of(REST_KEY, kind)
		bst.set("picked", str(drink_t["id"]))
		bst.call("debug_click", "crate_" + kind)
		bst.call("debug_pop")
		_expect(bool(bst.get("_bottle").get("open", false)), "the cap off the bottle")
		bst.call("debug_click", "bottle")
		_expect(BUSINESS.stock_of(REST_KEY, kind) == b0 - 1 and k.site(REST_KEY)["served"].has(str(drink_t["id"])), "a %s opened and served" % kind)
	bst.queue_free()
	# The hands at the grill and the bufet.
	for role_slug in [["grill", "pepa"], ["bufet", "hanka"]]:
		var p := RULES.person(str(role_slug[1]), "rest")
		p["role"] = str(role_slug[0])
		p["shift"] = "day"
		a.biz_hire(REST_KEY, p, 1)
	_expect(k._crew_grill(REST_KEY, false), "the grill's hand puts a sausage on")
	var left: int = k.tickets(REST_KEY, "bufet").size()
	if left > 0:
		_expect(k._crew_bufet(REST_KEY, {"name": "Hanka"}, false), "the bufet's hand serves a soup or a bottle")
	BUSINESS.site(REST_KEY)["crew"] = []
	state.guests.clear()


func _station(id: String, k) -> Node3D:
	var st: Node3D = load("res://scripts/bistro/%s_station.gd" % id).new()
	var surf: Dictionary = load("res://scripts/bistro/bistro_layout.gd").SURFACES[id]
	st.set("building_key", REST_KEY)
	st.set("station", id)
	st.set("surf_at", surf["at"])
	st.set("surf_size", surf["size"])
	st.set("surf_yaw", float(surf["yaw"]))
	st.set("surf_flat", bool(surf["flat"]))
	st.set("state", k)
	add_child(st)
	return st


# ── the Jednota ──────────────────────────────────────────────────────────────

func _jednota(state, a) -> void:
	var shop = JEDNOTA.of(get_tree())
	_expect(JRULES.slot_of("cards")[0] >= 0 and JRULES.slot_of("rum")[0] >= 0 and JRULES.BEHIND.has("cigs"), "cards and rum on the rack, cigarettes behind the till")
	var books: Dictionary = BUSINESS.site(SHOP_KEY)
	_expect(int(books["stock"].get("deli_salami", 0)) > 0 and int(books["stock"].get("cigs", 0)) > 0, "a new Jednota has deli goods and cigarettes")
	var now: int = JEDNOTA.now_min()
	var guests: Array = []
	var wishes := 0
	for i in 14:
		var arch: String = ["tramp", "picker", "family", "drunk"][i % 4]
		var visit := "%d@%d" % [900 + i, now - 6]
		if not JRULES.deli_wish(visit, arch).is_empty():
			wishes += 1
		guests.append({"id": 900 + i, "name": "Shop%d Test" % i, "archetype": arch, "status": "active",
			"needs": NEEDS.default_needs(null), "party_size": 1, "activity": {"kind": "visit", "target_key": SHOP_KEY, "start": now - 6, "arrive": now - 6, "end": now + 300}})
	_expect(wishes > 0, "some come for the deli (%d)" % wishes)
	state.guests.clear()
	for g in guests:
		state.guests.append(g)
	shop._host_second(SHOP_KEY)
	var deli: Array = shop.deli_tickets(SHOP_KEY)
	_expect(deli.size() == wishes, "their orders at the deli counter (%d)" % deli.size())
	if deli.is_empty():
		return
	var t: Dictionary = deli[0]
	var good := str(t["good"])
	var kg0 := BUSINESS.stock_of(SHOP_KEY, str(JRULES.DELI[good]["good"]))
	var got: float = shop.cut_slice(SHOP_KEY, good, 50.0)
	_expect(got == 50.0 and BUSINESS.stock_of(SHOP_KEY, str(JRULES.DELI[good]["good"])) == kg0 - 1, "the first slice opens a kilo off the books")
	_expect(not bool(shop.deli_serve(SHOP_KEY, t, float(t["want"]) * 0.7, true)["ok"]), "a short parcel is refused")
	_expect(not bool(shop.deli_serve(SHOP_KEY, t, float(t["want"]), false)["ok"]), "an unwrapped one too")
	var v: Dictionary = shop.deli_serve(SHOP_KEY, t, float(t["want"]) * 1.02, true)
	_expect(bool(v["ok"]) and float(v["accuracy"]) == 1.0, "cut to the weight: right (%s)" % str(v))
	_expect(shop.deli_tickets(SHOP_KEY).size() == deli.size() - 1, "that order off the rail")
	# Their basket: the parcel in it, priced by its weight.
	GuestManager._last_known_minute = 10
	shop._host_second(SHOP_KEY)
	var mine := {}
	for q in shop.tickets(SHOP_KEY):
		if str(q["visit"]) == str(t["visit"]):
			mine = q
	var has_parcel := false
	for item in (mine.get("items", []) as Array):
		has_parcel = has_parcel or JRULES.is_parcel(str(item))
	_expect(has_parcel and int(mine.get("total", 0)) >= JRULES.deli_price(good, float(t["want"])), "the parcel in their basket, its price in the bill (%s)" % str(mine.get("items", [])))
	# The deli's hand.
	var p := RULES.person("zdenka", "vecerka")
	p["role"] = "deli"
	p["shift"] = "day"
	a.biz_hire(SHOP_KEY, p, 1)
	var left: int = shop.deli_tickets(SHOP_KEY).size()
	if left > 0:
		_expect(shop._crew_deli(SHOP_KEY, false) and shop.deli_tickets(SHOP_KEY).size() == left - 1, "the deli's hand cuts and wraps one")
	BUSINESS.site(SHOP_KEY)["crew"] = []
	GuestManager._last_known_minute = 0
	state.guests.clear()


# ── the shared systems ───────────────────────────────────────────────────────

func _shared(_state, a) -> void:
	var z := {"orders": 10, "score": 920, "lost": 0, "takings": 120, "wages": 30, "cost": 40.0, "waste": 0, "worst": {"what": "Corn"}}
	var g := RULES.day_grade(z)
	_expect(str(g["grade"]) == "A", "a good shift is an A (%s)" % str(g))
	var bad := RULES.day_grade({"orders": 4, "score": 200, "lost": 8, "takings": 10, "wages": 60, "cost": 5.0})
	_expect(str(bad["grade"]) in ["D", "E"] and str(bad["advice"]).contains("unserved"), "many went away: a low mark, and hands for the rush (%s)" % str(bad))
	var site: Dictionary = BUSINESS.site(CORN_KEY)
	_expect(float(site["today"].get("cost", 0.0)) > 0.0, "the goods used cost something (%.1f)" % float(site["today"].get("cost", 0.0)))
	var zr: Dictionary = a.biz_close_shift(CORN_KEY, 15, 3, false)
	_expect(zr.has("grade") and str(zr.get("advice", "")) != "" and zr.has("cost"), "the Z report has its mark and advice (%s)" % str(zr.get("grade", "")))
	_expect(float(RULES.TEMPER_MOOD["warm"]) > float(RULES.TEMPER_MOOD["sour"]), "a warm hand cheers more than a sour one")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
