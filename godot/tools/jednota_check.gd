extends Node

## Headless check for the Jednota (DESIGN.md §7b "The Jednota"; scripts/jednota/jednota.gd,
## its stations scripts/jednota/*_station.gd, core/systems/jednota_rules.gd).
##
##   godot --headless --path godot res://tools/jednota_check.tscn
##
## Run as a SCENE (CoreRoot / EventBus autoloads). Asserts:
## - the rules: every good has its place on the rack, a guest's basket is the same every
##   time and as big as their kind takes, they pay with the right money or a note over
##   it, the change judged (short: count again; too much: they keep it);
## - the shop from the books: the rack filled from the stock, the rest in the storeroom;
## - the guests: looked round, they take their baskets off the rack and queue in order;
##   kept in the shop while they queue (the visit holds); too long in the queue and they
##   give up, their things back on the rack;
## - the till: the right change (Papa's score, the tip, three stars, the money, the
##   goods off the books), short and they stay, too much and it costs;
## - the storeroom and the rack: a box made up off the stock onto the trolley, onto its
##   place as far as there is room; what went off is off the rack too;
## - the hands: the till's serves the first in the queue (not while a warden is at the
##   till), the shelves' fill the emptiest place, the storeroom's throws out what went off
##   and makes up boxes;
## - the stations as a player works them (their debug hooks): a basket rung up and the
##   right change given at the till, a box shelved, a carton cut, priced and onto the
##   trolley;
## - it pays: the building is three by three and dear ($1500-2000), and a busy camp's
##   day (25 baskets, three hands) pays it and the licence back within a fortnight
##   (jednota_rules.day_model), a quiet one (8) does not;
## - its Build model stands (building_models "vecerka").

const JRULES := preload("res://core/systems/jednota_rules.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const JEDNOTA := preload("res://scripts/jednota/jednota.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const LAYOUT := preload("res://scripts/jednota/jednota_layout.gd")
const MODELS := preload("res://scripts/building_models.gd")
const KEY := "8:8"

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	var a = CoreRoot.actions
	state.grid.cells.clear()
	state.biz = {}
	state.money = 5000
	state.day = 3
	GuestManager._last_known_day = 3
	GuestManager._last_known_hour = 10
	GuestManager._last_known_minute = 0
	state.grid.occupy_cell(Vector2i(8, 8), "vecerka", "vecerka_8_8", Vector2i(8, 8))
	var site: Dictionary = a.biz_site(KEY, "vecerka")
	_expect(not site.is_empty() and str(site["kind"]) == "vecerka", "a Jednota's books")

	# The rules.
	var all: Array = JRULES.all_goods()
	var uniq := {}
	for g in all:
		uniq[g] = true
		var at: Array = JRULES.slot_of(str(g))
		_expect(int(at[0]) >= 0, "%s has its place on the rack" % g)
	_expect(all.size() == 10 and uniq.size() == 10, "ten goods on the rack, each once")
	for g in JRULES.goods():
		_expect(uniq.has(g), "%s is on the planogram" % g)
	for arch in JRULES.TASTE:
		var b1: Array = JRULES.basket_for("77@123", str(arch))
		var span: Array = JRULES.HOW_MANY[arch]
		_expect(b1 == JRULES.basket_for("77@123", str(arch)), "%s's basket the same every time" % arch)
		_expect(b1.size() >= int(span[0]) and b1.size() <= int(span[1]), "%s's basket as big as they take (%d)" % [arch, b1.size()])
	var right_money := 0
	for i in 40:
		var total := 1 + i
		var paid := JRULES.pay_with(total, "%d@5" % i)
		if paid == 0:
			right_money += 1
		else:
			_expect(paid > total, "a note over %d (%d)" % [total, paid])
	_expect(right_money > 0 and right_money < 40, "some pay the right money (%d of 40)" % right_money)
	var short: Dictionary = JRULES.judge(3, 7, 2)
	_expect(not bool(short["ok"]) and int(short["short"]) == 4, "short change: count again")
	var exact: Dictionary = JRULES.judge(7, 7, 2)
	_expect(bool(exact["ok"]) and float(exact["accuracy"]) == 1.0 and float(exact["speed"]) == 1.0, "the right change, quick")
	var over: Dictionary = JRULES.judge(9, 7, 20)
	_expect(bool(over["ok"]) and int(over["over"]) == 2 and float(over["accuracy"]) < 1.0 and float(over["speed"]) < 1.0, "too much, slow")

	# The shop from the books.
	var j = JEDNOTA.of(get_tree())
	_expect(j != null, "the Jednota is there")
	j.set_process(false)
	var cap: int = j.cap(KEY)
	_expect(cap == JRULES.SLOT_CAP, "six a place")
	for g in all:
		var stock := int(site["stock"].get(g, 0))
		_expect(int(j.shelf(KEY)[g]) == mini(cap, stock), "%s on the rack from the books" % g)
		_expect(j.backroom(KEY, str(g)) == stock - int(j.shelf(KEY)[g]), "the rest of the %s in the storeroom" % g)

	# Guests come in, look round, take their baskets.
	var now: int = JEDNOTA.now_min()
	var archs := ["drunk", "tramp", "quiet_guy", "cheap_chick", "picker", "family"]
	state.guests.clear()
	for i in 6:
		state.guests.append({"id": 700 + i, "name": "Shopper%d Test" % i, "archetype": archs[i], "status": "active", "party_size": 1,
			"mood": 60.0, "needs": {}, "activity": {"kind": "visit", "target_key": KEY, "start": now - 20 + i, "arrive": now - 20 + i, "end": now + 300}})
	var shelf0: Dictionary = (j.shelf(KEY) as Dictionary).duplicate()
	j._host_second(KEY)
	var q: Array = j.tickets(KEY)
	_expect(q.size() >= 5, "they queue with their baskets (%d)" % q.size())
	var taken := 0
	for t in q:
		taken += (t["items"] as Array).size()
	var on_rack := 0
	var was := 0
	for g in all:
		on_rack += int(j.shelf(KEY)[g])
		was += int(shelf0[g])
	_expect(was - on_rack == taken, "their baskets off the rack (%d)" % taken)
	_expect(q == j.tickets(KEY), "the same queue every time")
	var ordered := true
	for i in range(1, q.size()):
		ordered = ordered and int(q[i - 1]["since"]) <= int(q[i]["since"])
	_expect(ordered, "the queue in the order they came")
	_expect((j._holds.get(KEY, {}) as Dictionary).size() >= q.size(), "kept in the shop while they queue")
	var hold := int((j._holds[KEY] as Dictionary).get(int(q[0]["guest_id"]), 0))
	_expect(hold == int(q[0]["since"]) + JRULES.PATIENCE_GONE, "as long as their patience (%d)" % hold)

	# The till: the right change.
	var t0: Dictionary = q[0]
	var money0: int = state.money
	var stock0: Dictionary = (site["stock"] as Dictionary).duplicate()
	var v: Dictionary = j.serve(KEY, t0, int(t0["due"]))
	_expect(bool(v.get("ok", false)) and int(v["stars"]) == 3 and int(v["tip"]) > 0, "the right change quick: three stars and a tip (%s)" % str(v))
	_expect(state.money == money0 + int(v["amount"]) and int(v["amount"]) == int(t0["total"]) + int(v["tip"]), "the money in the till")
	var sold := 0
	for g in all:
		sold += int(stock0.get(g, 0)) - int(site["stock"].get(g, 0))
	_expect(sold == (t0["items"] as Array).size(), "the basket off the books (%d)" % sold)
	_expect(j.tickets(KEY).size() == q.size() - 1, "they are out of the queue")
	_expect(int(site["shift"]["orders"]) == 1, "the shift's tally")
	# Short, then too much.
	var t1: Dictionary = j.tickets(KEY)[0]
	if int(t1["due"]) > 0:
		var vs: Dictionary = j.serve(KEY, t1, int(t1["due"]) - 1)
		_expect(not bool(vs["ok"]) and j.tickets(KEY).size() == q.size() - 1, "short: they stay at the till")
	var vo: Dictionary = j.serve(KEY, t1, int(t1["due"]) + 2)
	_expect(bool(vo["ok"]) and int(vo["over"]) == 2 and int(vo["amount"]) == int(t1["total"]) + int(vo["tip"]) - 2, "too much: it costs (%s)" % str(vo))
	# Too long in the queue: their things back on the rack.
	var t2: Dictionary = j.tickets(KEY)[0]
	var visit2 := str(t2["visit"])
	j.site(KEY)["picked"][visit2]["at"] = now - JRULES.PATIENCE_GONE - 1
	var rack2 := 0
	for g in all:
		rack2 += int(j.shelf(KEY)[g])
	j._host_second(KEY)
	var rack3 := 0
	for g in all:
		rack3 += int(j.shelf(KEY)[g])
	_expect(j.site(KEY)["gone"].has(visit2) and rack3 == rack2 + (t2["items"] as Array).size(), "tired of the queue: gone, their things back on the rack")

	# The storeroom and the rack.
	var g0 := ""
	for g in all:
		if j.backroom(KEY, str(g)) >= JRULES.BOX and int(j.shelf(KEY)[g]) < cap:
			g0 = str(g)
			break
	_expect(g0 != "", "something to box up")
	if g0 != "":
		var back0: int = j.backroom(KEY, g0)
		_expect(j.make_box(KEY, g0) == JRULES.BOX and int(j.trolley(KEY)[g0]) == JRULES.BOX and j.backroom(KEY, g0) == back0 - JRULES.BOX, "a box of %s onto the trolley" % g0)
		var room: int = cap - int(j.shelf(KEY)[g0])
		var moved: int = j.shelve(KEY, g0)
		_expect(moved == mini(JRULES.BOX, room) and int(j.shelf(KEY)[g0]) <= cap, "onto its place as far as there is room (%d)" % moved)
	# What went off is off the rack.
	site["stock"]["bread"] = maxi(0, int(site["stock"]["bread"]) - 4)
	site["spoiled"]["bread"] = 4
	j._fit_stock(KEY)
	_expect(int(j.shelf(KEY)["bread"]) + int(j.trolley(KEY)["bread"]) + j.in_baskets(KEY, "bread") <= int(site["stock"]["bread"]), "what went off is off the rack")

	# The hands.
	for slug_role in [["novakova", "till"], ["zdenka", "shelves"], ["ivan", "store"]]:
		var p := RULES.person(str(slug_role[0]), "vecerka")
		p["role"] = str(slug_role[1])
		p["shift"] = "day"
		a.biz_hire(KEY, p, 3)
	var crew: Array = BUSINESS.crew_now(KEY)
	_expect(crew.size() == 3, "three hands in (%d)" % crew.size())
	var q4: int = j.tickets(KEY).size()
	_expect(q4 > 0, "somebody still in the queue")
	j.act(KEY, "till", ["warden", true])
	j._crew_t.clear()
	j._crew_work(KEY, [crew[0]])
	_expect(j.tickets(KEY).size() == q4, "a warden at the till: its hand leaves it")
	j.act(KEY, "till", ["warden", false])
	j._crew_t.clear()
	var by0 := int(site["shift"]["by_hands"])
	j._crew_work(KEY, [crew[0]])
	_expect(j.tickets(KEY).size() == q4 - 1 and int(site["shift"]["by_hands"]) == by0 + 1, "the till's hand serves the first")
	# The storeroom's: what went off thrown out, then a box made up.
	j._crew_t.clear()
	j._crew_work(KEY, [crew[2]])
	_expect((site["spoiled"] as Dictionary).is_empty(), "the storeroom's hand throws out what went off")
	var tr0 := 0
	for g in all:
		tr0 += int(j.trolley(KEY)[g])
	j._crew_t.clear()
	j._crew_work(KEY, [crew[2]])
	var tr1 := 0
	for g in all:
		tr1 += int(j.trolley(KEY)[g])
	_expect(tr1 > tr0, "the storeroom's hand makes up a box (%d -> %d)" % [tr0, tr1])
	# The shelves': a box onto the emptiest place it has one for.
	var rack4 := 0
	for g in all:
		rack4 += int(j.shelf(KEY)[g])
	j._crew_t.clear()
	j._crew_work(KEY, [crew[1]])
	var rack5 := 0
	for g in all:
		rack5 += int(j.shelf(KEY)[g])
	_expect(rack5 > rack4, "the shelves' hand fills a place (%d -> %d)" % [rack4, rack5])
	site["crew"] = []

	# The stations as a player works them.
	var room_node := Node3D.new()
	add_child(room_node)
	var st := {}
	for id in ["till", "shelves", "store"]:
		var v3: Node3D = load("res://scripts/jednota/%s_station.gd" % id).new()
		var surf: Dictionary = LAYOUT.SURFACES[id]
		v3.set("building_key", KEY)
		v3.set("station", id)
		v3.set("surf_at", surf["at"])
		v3.set("surf_size", surf["size"])
		v3.set("surf_yaw", float(surf["yaw"]))
		v3.set("surf_flat", bool(surf["flat"]))
		v3.set("cam_side", float(surf.get("cam_side", 0.0)))
		v3.set("state", j)
		room_node.add_child(v3)
		st[id] = v3
	await get_tree().process_frame
	# More guests for the till.
	now = JEDNOTA.now_min()
	for i in 3:
		state.guests.append({"id": 760 + i, "name": "Late%d Test" % i, "archetype": archs[i + 2], "status": "active", "party_size": 1,
			"mood": 60.0, "needs": {}, "activity": {"kind": "visit", "target_key": KEY, "start": now - 15 - i, "arrive": now - 15 - i, "end": now + 300}})
	j._host_second(KEY)
	var q6: int = j.tickets(KEY).size()
	_expect(q6 > 0, "a queue at the till")
	if q6 > 0:
		var money6: int = state.money
		var vt: Dictionary = st["till"].debug_serve_right()
		_expect(bool(vt.get("ok", false)) and j.tickets(KEY).size() == q6 - 1 and state.money > money6, "the till: rung up, the money taken, the right change given (%s)" % str(vt))
	var g1 := ""
	for g in all:
		if j.backroom(KEY, str(g)) >= JRULES.BOX and int(j.shelf(KEY)[g]) <= cap - 2:
			g1 = str(g)
			break
	_expect(g1 != "", "a good the rack has room for and the storeroom has")
	if g1 != "":
		var boxed: int = st["store"].debug_box(g1)
		_expect(boxed == JRULES.BOX, "the storeroom: a carton of %s cut, priced and onto the trolley (%d)" % [g1, boxed])
		var up: int = st["shelves"].debug_shelve(g1)
		_expect(up > 0, "the shelves: the box onto its place (%d)" % up)
	_expect(RULES.gear_list("vecerka").has("till2") and RULES.gear_list("vecerka").has("racks"), "the Jednota's gear")

	# It pays.
	var def = CoreRoot.registry.get_def(&"vecerka") if CoreRoot.registry != null else null
	_expect(def != null, "the Jednota is in the catalogue")
	if def != null:
		_expect(def.footprint == Vector2i(3, 3), "three by three (%s)" % str(def.footprint))
		_expect(int(def.cost) >= 1500 and int(def.cost) <= 2000, "dear: $%d" % int(def.cost))
		var price := int(def.cost) + int(RULES.KINDS["vecerka"]["licence"])
		var wages := 3 * RULES.wage("vecerka", 1, true, "flat")
		var busy: Dictionary = JRULES.day_model(25, wages, 1)
		var quiet: Dictionary = JRULES.day_model(8, wages, 1)
		var days := int(ceil(float(price) / float(maxi(1, int(busy["net"]))))) if int(busy["net"]) > 0 else 999
		print("JEDNOTA PAYS: $%d with the licence; a busy day %s -> %d days; a quiet day %s" % [price, str(busy), days, str(quiet)])
		_expect(int(busy["net"]) > 0 and days <= 14, "a busy camp pays it back within a fortnight (%d days)" % days)
		_expect(int(quiet["net"]) * 14 < price, "a quiet one does not")

	# Its Build model.
	_expect(MODELS.has_model("vecerka"), "the Jednota has a Build model")
	var models = MODELS.new()
	var mroot := Node3D.new()
	add_child(mroot)
	var info: Dictionary = models.build("vecerka", mroot, 4.0, Vector2i(3, 3))
	_expect((info.get("size", Vector3.ZERO) as Vector3).x >= 7.0 and mroot.get_child_count() > 10, "its model stands (%s)" % str(info.get("size", "")))

	print("")
	if _failures.is_empty():
		print("JEDNOTA CHECK: PASS")
		get_tree().quit(0)
	else:
		print("JEDNOTA CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
