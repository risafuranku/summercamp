extends Node

## The camp's Jednotas while the game runs (core/systems/jednota_rules.gd has the numbers;
## DESIGN.md §7b "The Jednota"), the pub's taproom.gd made for the shop. One node for the
## game, made with the businesses (business_runtime), a record per shop ("x:y" key):
##   shelf    what is on the rack, a place each good (units)
##   trolley  what is made up in boxes on the cage trolley, waiting for the rack (units)
##   picked   who has taken their basket off the rack and is in the queue for the till:
##            visit -> {items, at (game minute), short (what they found gone)}
##   served   who went out with their bag: visit -> {at, stars, amount}
##   gone     who gave up in the queue (their things back on the rack): visit -> true
##   rung     what of the first one's basket has been rung up: visit -> [index, ...]
##   mat      the change counted out onto the mat for them: visit -> [coin or note, ...]
##   till_by  the wardens at the till now (its hand stands aside): who -> since (ms, here)
##   deli     the deli counter's orders: visit -> {good, want (grams), since, done (grams
##            wrapped and handed over, 0 not yet), gone (went on without it)}
##   cut      what is left of the salami, the cheese and the loaf cut into (grams): a new
##            kilo comes off the books when it runs out
## The books' stock is everything the shop has (the storeroom, the trolley, the rack and the
## baskets); a thing comes off it when it is sold at the till. What is left in the
## storeroom is the stock less the rest (backroom()).
## Co-op (up to four): every change is an op (`act`) applied at once and sent to everyone
## (Coop.send_place "vecerka"). The host has the guests take their baskets, gives up those
## who wait too long, does the hands' work and keeps the rack and the trolley in the books
## for the save (actions.biz_keep "jednota").

const RULES := preload("res://core/systems/jednota_rules.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const BIZ_RULES := preload("res://core/systems/business_rules.gd")

## A record changed (key, what: "shelf", "trolley", "picked", "served", "gone").
signal changed(key: String, what: String)
## A guest went out with their bag (key, visit, its record).
signal handed(key: String, visit: String, rec: Dictionary)

var _sites: Dictionary = {}
var _acc := 0.0
var _save_due: Dictionary = {}
var _asked_snap := false
var _state_id := 0
var _crew_t: Dictionary = {}
## The visits each shop keeps this second (orders.set_holds): key -> {guest id: minute}.
var _holds: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Jednotas"
	add_to_group("jednotas")
	# Coop.send_place("vecerka", ...) finds it here.
	add_to_group("places_vecerka")
	_rng.randomize()


## The game's Jednotas node, made under the businesses (or the root) when first asked for.
static func of(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var j := tree.get_first_node_in_group("jednotas")
	if j != null:
		return j
	var parent: Node = tree.get_first_node_in_group("businesses")
	if parent == null:
		parent = tree.root
	j = load("res://scripts/jednota/jednota.gd").new()
	parent.add_child(j)
	return j


# ── the record ───────────────────────────────────────────────────────────────

func site(key: String) -> Dictionary:
	if not _sites.has(key):
		_sites[key] = _fresh(key)
	return _sites[key]


## From the books: the rack and the trolley as they were saved, or the rack filled from
## the stock (the shop opens with full shelves).
func _fresh(key: String) -> Dictionary:
	var books := BUSINESS.site(key)
	var saved: Dictionary = books.get("jednota", {}) if books.get("jednota", {}) is Dictionary else {}
	var shelf := {}
	var trolley := {}
	var racks := BIZ_RULES.has_gear(books, "racks")
	for g in RULES.all_goods():
		var stock := maxi(0, int((books.get("stock", {}) as Dictionary).get(g, 0)))
		if saved.has("shelf"):
			shelf[g] = mini(int((saved["shelf"] as Dictionary).get(g, 0)), stock)
			trolley[g] = mini(int((saved.get("trolley", {}) as Dictionary).get(g, 0)), stock - int(shelf[g]))
		else:
			shelf[g] = mini(RULES.slot_cap(racks), stock)
			trolley[g] = 0
	return {"shelf": shelf, "trolley": trolley, "picked": {}, "served": {}, "gone": {}, "rung": {}, "mat": {}, "till_by": {},
		"deli": {}, "cut": (saved.get("cut", {}) as Dictionary).duplicate() if saved.get("cut", {}) is Dictionary else {}}


func shelf(key: String) -> Dictionary:
	return site(key)["shelf"]


func trolley(key: String) -> Dictionary:
	return site(key)["trolley"]


func cap(key: String) -> int:
	return RULES.slot_cap(BUSINESS.has_gear(key, "racks"))


## Units of `good` in baskets now (taken off the rack, not yet paid for).
func in_baskets(key: String, good: String) -> int:
	var s := site(key)
	var n := 0
	for visit in s["picked"]:
		if s["served"].has(visit) or s["gone"].has(visit):
			continue
		for g in (s["picked"][visit]["items"] as Array):
			if str(g) == good:
				n += 1
	return n


## What of `good` is left in the storeroom (not on the rack, the trolley or in a basket).
func backroom(key: String, good: String) -> int:
	var stock := maxi(0, BUSINESS.stock_of(key, good))
	return maxi(0, stock - int(shelf(key).get(good, 0)) - int(trolley(key).get(good, 0)) - in_baskets(key, good))


# ── the queue ────────────────────────────────────────────────────────────────

static func now_min() -> int:
	if GuestManager == null:
		return 0
	return int(GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute))


## The queue at the till, the first first: [{id (visit), visit, guest_id, name, arch, items,
## total, paid, due, since, age}].
func tickets(key: String) -> Array:
	var out: Array = []
	var s := site(key)
	var now := now_min()
	var names := {}
	for v in ORDERS.visitors(key):
		names[str(v["visit"])] = v
	for visit in s["picked"]:
		if s["served"].has(visit) or s["gone"].has(visit):
			continue
		var p: Dictionary = s["picked"][visit]
		var items: Array = p["items"]
		if items.is_empty():
			continue
		var v: Dictionary = names.get(visit, {})
		var total := RULES.total_of(items)
		var paid := RULES.pay_with(total, str(visit))
		out.append({"id": str(visit), "visit": str(visit), "guest_id": int(v.get("id", int(str(visit).get_slice("@", 0)))),
			"name": str(v.get("name", p.get("name", "A guest"))), "arch": str(v.get("archetype", "")), "items": items.duplicate(),
			"total": total, "paid": paid, "due": RULES.change_due(total, paid), "since": int(p["at"]), "age": now - int(p["at"]),
			"rung": (s["rung"].get(visit, []) as Array).duplicate(), "mat": (s["mat"].get(visit, []) as Array).duplicate()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["since"]) < int(b["since"]) or (int(a["since"]) == int(b["since"]) and str(a["id"]) < str(b["id"])))
	return out


# ── doing things: ops ────────────────────────────────────────────────────────

## Do `op` here and tell the others. ops:
##   shelf [good, delta]            the rack
##   trolley [good, delta]          the trolley
##   picked [visit, items, short, name]  a basket taken off the rack (the rack less it)
##   gone [visit]                   gave up: their things back on the rack
##   served [visit, rec]            paid and out
##   ring [visit, index]            a thing of their basket rung up
##   mat [visit, pieces]            the change on the mat now
##   till [who, on]                 a warden stepped up to the till or away
##   deli [visit, rec]              a deli order as it stands now
##   cut [good, grams]              what is left of the piece being cut
##   parcel [visit, item]           a parcel from the deli into a basket already picked
func act(key: String, op: String, args: Array) -> void:
	_apply(key, op, args)
	if Coop.is_active() and Coop.has_method("send_place"):
		Coop.send_place("vecerka", key, op, args)


func _apply(key: String, op: String, args: Array) -> void:
	var s := site(key)
	match op:
		"shelf":
			s["shelf"][str(args[0])] = maxi(0, int(s["shelf"].get(str(args[0]), 0)) + int(args[1]))
			_save_due[key] = true
		"trolley":
			s["trolley"][str(args[0])] = maxi(0, int(s["trolley"].get(str(args[0]), 0)) + int(args[1]))
			_save_due[key] = true
		"picked":
			var items: Array = (args[1] as Array).duplicate()
			s["picked"][str(args[0])] = {"items": items, "at": now_min(), "short": int(args[2]), "name": str(args[3]) if args.size() > 3 else ""}
			for g in items:
				# Off the rack (a parcel was cut, the cigarettes are behind the till).
				if s["shelf"].has(str(g)):
					s["shelf"][str(g)] = maxi(0, int(s["shelf"][str(g)]) - 1)
			_save_due[key] = true
		"gone":
			var visit := str(args[0])
			if s["picked"].has(visit) and not s["served"].has(visit) and not s["gone"].has(visit):
				for g in (s["picked"][visit]["items"] as Array):
					if s["shelf"].has(str(g)):
						s["shelf"][str(g)] = int(s["shelf"][str(g)]) + 1
			s["gone"][visit] = true
			_save_due[key] = true
		"served":
			var rec: Dictionary = (args[1] as Dictionary).duplicate(true)
			s["served"][str(args[0])] = rec
			s["rung"].erase(str(args[0]))
			s["mat"].erase(str(args[0]))
			handed.emit(key, str(args[0]), rec)
		"ring":
			var rung: Array = s["rung"].get(str(args[0]), [])
			if not rung.has(int(args[1])):
				rung.append(int(args[1]))
			s["rung"][str(args[0])] = rung
		"mat":
			s["mat"][str(args[0])] = (args[1] as Array).duplicate()
		"deli":
			s["deli"][str(args[0])] = (args[1] as Dictionary).duplicate(true)
		"cut":
			s["cut"][str(args[0])] = float(args[1])
			_save_due[key] = true
		"parcel":
			var pv := str(args[0])
			if s["picked"].has(pv) and not s["served"].has(pv):
				(s["picked"][pv]["items"] as Array).append(str(args[1]))
		"till":
			if bool(args[1]):
				s["till_by"][str(args[0])] = Time.get_ticks_msec()
			else:
				s["till_by"].erase(str(args[0]))
		"snap":
			var got: Dictionary = args[0]
			for k in ["shelf", "trolley", "picked", "served", "gone", "rung", "mat", "deli", "cut"]:
				if got.has(k):
					s[k] = (got[k] as Dictionary).duplicate(true)
	changed.emit(key, op)


## From another machine (Coop.send_place "vecerka").
func coop_place(key: String, op: String, args: Array) -> void:
	if op == "hello":
		if Coop.is_host():
			for k in _sites:
				Coop.send_place("vecerka", str(k), "snap", [_snapshot(str(k))])
		return
	_apply(key, op, args)


func _snapshot(key: String) -> Dictionary:
	var s := site(key)
	return {"shelf": s["shelf"], "trolley": s["trolley"], "picked": s["picked"], "served": s["served"], "gone": s["gone"], "rung": s["rung"], "mat": s["mat"], "deli": s["deli"], "cut": s["cut"]}


# ── the deli counter ─────────────────────────────────────────────────────────

## The deli orders waiting, the oldest first: [{id (visit), visit, guest_id, name, good,
## want, since, age}].
func deli_tickets(key: String) -> Array:
	var out: Array = []
	var s := site(key)
	var now := now_min()
	var names := {}
	for v in ORDERS.visitors(key):
		names[str(v["visit"])] = v
	for visit in s["deli"]:
		var d: Dictionary = s["deli"][visit]
		if int(d.get("done", 0)) > 0 or bool(d.get("gone", false)) or not names.has(visit) or s["served"].has(visit) or s["gone"].has(visit):
			continue
		var v: Dictionary = names[visit]
		out.append({"id": str(visit), "visit": str(visit), "guest_id": int(v["id"]), "name": str(v["name"]), "arch": str(v["archetype"]),
			"good": str(d["good"]), "want": int(d["want"]), "since": int(d["since"]), "age": now - int(d["since"]), "kind": "deli"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["since"]) < int(b["since"]))
	return out


## A slice off the piece of `good` (grams): the piece cut into is less by it; a new kilo
## off the books when it has run out. 0 when there is no more.
func cut_slice(key: String, good: String, grams: float) -> float:
	var left := float(site(key)["cut"].get(good, 0.0))
	if left < grams:
		var books := str(RULES.DELI[good]["good"])
		if BUSINESS.stock_of(key, books) == 0:
			return 0.0
		if CoreRoot != null and CoreRoot.actions != null and BUSINESS.stock_of(key, books) > 0 and not CoreRoot.actions.biz_take(key, {books: 1}):
			return 0.0
		left += 1000.0
	act(key, "cut", [good, left - grams])
	return grams


## The parcel for deli order `t` handed over: judged by its weight (jednota_rules
## judge_deli); into their basket (the money at the till, by the weight). The verdict;
## {ok: false, notes} when it is short or not wrapped.
func deli_serve(key: String, t: Dictionary, grams: float, wrapped: bool, by_hand := false) -> Dictionary:
	var v: Dictionary = RULES.judge_deli(grams, int(t["want"]), wrapped, int(t["age"]))
	if not bool(v["ok"]):
		return v
	var pts := BIZ_RULES.score(float(v["speed"]), float(v["accuracy"]))
	var r := BIZ_RULES.reward(pts, RULES.deli_price(str(t["good"]), grams))
	v["score"] = pts
	v["stars"] = int(r["stars"])
	v["tip"] = 0
	v["amount"] = RULES.deli_price(str(t["good"]), grams)
	v["build"] = float(v["accuracy"])
	var visit := str(t["visit"])
	var rec: Dictionary = (site(key)["deli"].get(visit, {}) as Dictionary).duplicate()
	rec["done"] = int(round(grams))
	act(key, "deli", [visit, rec])
	var item := RULES.parcel(str(t["good"]), int(round(grams)))
	if site(key)["picked"].has(visit):
		act(key, "parcel", [visit, item])
	ORDERS.mood(int(t["guest_id"]), float(r["mood"]) * 0.5 + (BUSINESS.hand_mood(key, "deli") if by_hand else 0.0), "")
	if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_score"):
		CoreRoot.actions.biz_score(key, {"score": pts, "tip": 0, "what": str(RULES.DELI[str(t["good"])]["label"]), "who": str(t.get("name", "")), "hand": by_hand})
	return v


## Whether a warden is at the till now (its hand leaves the first in the queue to them).
func till_held(key: String) -> bool:
	var by: Dictionary = site(key)["till_by"]
	for who in by.keys():
		if Time.get_ticks_msec() - int(by[who]) > 9000:
			by.erase(who)
	return not by.is_empty()


## A box of `good` made up in the storeroom and put on the trolley (as much as the
## storeroom has, up to a box): the units moved, 0 when there is none.
func make_box(key: String, good: String) -> int:
	var n := mini(RULES.BOX, backroom(key, good))
	if n > 0:
		act(key, "trolley", [good, n])
	return n


## A box of `good` off the trolley onto its place on the rack (as much as the place takes):
## the units moved.
func shelve(key: String, good: String) -> int:
	var room := cap(key) - int(shelf(key).get(good, 0))
	var n := mini(mini(RULES.BOX, int(trolley(key).get(good, 0))), room)
	if n > 0:
		act(key, "trolley", [good, -n])
		act(key, "shelf", [good, n])
	return n


## The guest at the till pays and goes out with their bag: the change counted out (`given`)
## judged against what is due (jednota_rules.judge) into Papa's score, the things sold off
## the books, the money the camp's (less what went out in change too much), the guest's
## mood and their review's line. Returns the verdict with its amount, tip, stars; {ok:
## false, short} when the change is short (they say so; count again).
func serve(key: String, t: Dictionary, given: int, by_hand := false) -> Dictionary:
	var v: Dictionary = RULES.judge(given, int(t["due"]), int(t["age"]))
	if not bool(v["ok"]):
		return v
	var pts := BIZ_RULES.score(float(v["speed"]), float(v["accuracy"]))
	var r := BIZ_RULES.reward(pts, int(t["total"]))
	var amount := maxi(0, int(round((int(t["total"]) + int(r["tip"])) * BUSINESS.price_k(key))) - int(v["over"]))
	var needs := {}
	for g in (t["items"] as Array):
		# A deli parcel came off the books as it was cut.
		if RULES.is_parcel(str(g)):
			continue
		needs[str(g)] = int(needs.get(str(g), 0)) + 1
	if not BUSINESS.sell(key, needs, amount):
		# The books have it less than the basket (the rack had more than the stock):
		# sell what there is.
		var part := {}
		for g in needs:
			var have := maxi(0, BUSINESS.stock_of(key, str(g)))
			if have > 0:
				part[g] = mini(have, int(needs[g]))
		BUSINESS.sell(key, part, amount)
	v["score"] = pts
	v["tip"] = int(r["tip"])
	v["stars"] = int(r["stars"])
	v["amount"] = amount
	ORDERS.note_served({"id": int(t["guest_id"]), "visit": str(t["visit"])})
	# The guests love it: the camp's own Jednota.
	var thought := _thought(v, int(site(key)["picked"].get(str(t["visit"]), {}).get("short", 0)))
	ORDERS.mood(int(t["guest_id"]), float(r["mood"]) + 2.0, thought)
	ORDERS.note_meal(int(t["guest_id"]), thought, pts)
	act(key, "served", [str(t["visit"]), {"at": now_min(), "stars": int(v["stars"]), "amount": amount}])
	if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_score"):
		CoreRoot.actions.biz_score(key, {"score": pts, "tip": int(v["tip"]), "what": "Shopping", "who": str(t.get("name", "")), "hand": by_hand})
	return v


func _thought(v: Dictionary, short: int) -> String:
	if short > 0:
		return "The camp's Jednota had half of it sold out."
	if int(v.get("stars", 0)) >= 3:
		return "The camp has its own Jednota. Fresh rolls every morning."
	if float(v.get("speed", 1.0)) < 0.3:
		return "Queued forever at the Jednota's till."
	return "A Jednota in a camp! Like being a child again."


# ── time ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var st = CoreRoot.get_state() if CoreRoot != null else null
	# The state object may stay the same from camp to camp: the books' stamp does not
	# (actions._biz).
	var sid: int = (st.get_instance_id() + int((st.biz as Dictionary).get("stamp", 0))) if st != null and st.biz is Dictionary else 0
	if sid != _state_id:
		_state_id = sid
		_sites.clear()
		_save_due.clear()
		_asked_snap = false
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	if Coop.is_client() and not _asked_snap and Coop.has_method("send_place"):
		_asked_snap = true
		Coop.send_place("vecerka", "", "hello", [])
	if not Coop.sim_here():
		return
	_holds.clear()
	for key in _shop_sites():
		_host_second(key)
		if _save_due.has(key):
			_save_due.erase(key)
			_save(key)
	var all := {}
	for key in _holds:
		all.merge(_holds[key], true)
	ORDERS.set_holds("vecerka", all)


func _shop_sites() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	for key in sites:
		if str((sites[key] as Dictionary).get("kind", "")) == "vecerka":
			out.append(str(key))
	return out


## Host, once a second: those who have looked round take their baskets off the rack; those
## who waited too long (or went) give up, their things back on the rack; the hands work.
func _host_second(key: String) -> void:
	var s := site(key)
	var now := now_min()
	_fit_stock(key)
	var here := {}
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		here[visit] = true
		if s["picked"].has(visit) or s["gone"].has(visit) or s["served"].has(visit):
			continue
		# Something to be cut at the deli counter for some (asked as they come in; they shop
		# meanwhile, and the parcel goes in their basket when it is handed over).
		var wish: Dictionary = RULES.deli_wish(visit, str(v.get("archetype", "")))
		if not BIZ_RULES.menu_on("vecerka", BUSINESS.site(key), "deli"):
			wish = {}
		if not wish.is_empty() and not s["deli"].has(visit):
			var w := wish.duplicate()
			w["since"] = int(v.get("arrive", now)) + 2
			w["done"] = 0
			act(key, "deli", [visit, w])
		var dl: Dictionary = s["deli"].get(visit, {})
		if now < int(v.get("arrive", now)) + RULES.BROWSE:
			continue
		# Off the rack into the basket: what is there of what they came for (and on sale:
		# the books' MENU is the shop's range).
		var books := BUSINESS.site(key)
		var want: Array = RULES.basket_for(visit, str(v.get("archetype", ""))).filter(func(g) -> bool: return BIZ_RULES.menu_on("vecerka", books, str(g)))
		var shelf_now: Dictionary = (s["shelf"] as Dictionary).duplicate()
		var got: Array = []
		var short := 0
		var behind := {}
		for g in want:
			if str(g) in RULES.BEHIND:
				# Behind the till: asked for there, while the books have it.
				var free := BUSINESS.stock_of(key, str(g)) - in_baskets(key, str(g)) - int(behind.get(str(g), 0))
				if free > 0:
					behind[str(g)] = int(behind.get(str(g), 0)) + 1
					got.append(str(g))
				else:
					short += 1
			elif int(shelf_now.get(str(g), 0)) > 0:
				shelf_now[str(g)] = int(shelf_now[str(g)]) - 1
				got.append(str(g))
			else:
				short += 1
		if int(dl.get("done", 0)) > 0:
			got.append(RULES.parcel(str(dl["good"]), int(dl["done"])))
		act(key, "picked", [visit, got, short, str(v.get("name", ""))])
		if got.is_empty():
			# Nothing they wanted on the rack: out with nothing.
			act(key, "gone", [visit])
			ORDERS.mood(int(v["id"]), -2.0, "The camp's Jednota had nothing on its shelves.")
	# Deli orders nobody cut in time, or of those who have paid and gone: off the rail.
	for visit in (s["deli"] as Dictionary).keys():
		var d: Dictionary = s["deli"][visit]
		if int(d.get("done", 0)) > 0 or bool(d.get("gone", false)):
			continue
		if now - int(d["since"]) >= RULES.DELI_WAIT or s["served"].has(visit) or s["gone"].has(visit) or not here.has(visit):
			var gone := d.duplicate()
			gone["gone"] = true
			act(key, "deli", [visit, gone])
			if here.has(visit) and not s["served"].has(visit):
				ORDERS.mood(int(str(visit).get_slice("@", 0)), -1.0, "Nobody at the deli counter in the Jednota.")
	for visit in (s["picked"] as Dictionary).keys():
		if s["served"].has(visit) or s["gone"].has(visit):
			continue
		var p: Dictionary = s["picked"][visit]
		if not here.has(visit) or now - int(p["at"]) >= RULES.PATIENCE_GONE:
			# Their things back on the rack; the books count them lost and they grumble
			# as they go (business_runtime._watch_visits: nobody served them).
			act(key, "gone", [visit])
	var crew: Array = BUSINESS.crew_now(key)
	if not crew.is_empty():
		_crew_work(key, crew)
	# Looking round and in the queue they stay past their time; paid, they go.
	var holds := {}
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		if s["served"].has(visit) or s["gone"].has(visit):
			continue
		if s["picked"].has(visit):
			holds[int(v["id"])] = int(s["picked"][visit]["at"]) + RULES.PATIENCE_GONE
		else:
			holds[int(v["id"])] = int(v.get("arrive", now)) + RULES.BROWSE + 1
	_holds[key] = holds


## What went off in the night is out of the books' stock (actions.biz_spoil; it waits in
## the books' spoiled till thrown out): the rack has that much less (the oldest are there),
## then the trolley.
func _fit_stock(key: String) -> void:
	for g in RULES.all_goods():
		var over := int(shelf(key).get(g, 0)) + int(trolley(key).get(g, 0)) + in_baskets(key, g) - maxi(0, BUSINESS.stock_of(key, g))
		if over <= 0:
			continue
		var off_shelf := mini(over, int(shelf(key).get(g, 0)))
		if off_shelf > 0:
			act(key, "shelf", [g, -off_shelf])
		var off_trolley := mini(over - off_shelf, int(trolley(key).get(g, 0)))
		if off_trolley > 0:
			act(key, "trolley", [g, -off_trolley])


## The rack and the trolley into the books (they are saved with the camp).
func _save(key: String) -> void:
	if CoreRoot == null or CoreRoot.actions == null or not CoreRoot.actions.has_method("biz_keep"):
		return
	var s := site(key)
	CoreRoot.actions.biz_keep(key, "jednota", {"shelf": s["shelf"], "trolley": s["trolley"], "cut": s["cut"]})


## The hands at the Jednota (DESIGN.md §7b, the hands), one piece of work at a time as their
## speed allows; now and then one goes wrong:
##   till, till2  the first in the queue (the second till, gear: the second in it too); the
##                change counted right, or a coin over now and then
##   shelves      a box off the trolley onto the emptiest place it has a box for (one
##                dropped now and then: broken)
##   store        a box made up for the place that will run out first; what went off
##                thrown out (the pallet truck, gear: twice as quick)
##   deli         cuts the oldest deli order to about its weight and wraps it
func _crew_work(key: String, crew: Array) -> void:
	for p in crew:
		var id := key + "/" + str(p.get("slug", ""))
		var left := float(_crew_t.get(id, 0.0)) - 1.0
		if left > 0.0:
			_crew_t[id] = left
			continue
		var speed := clampi(int(p.get("speed", 1)), 0, 2)
		var slip := _rng.randf() < float(BIZ_RULES.SPEED_SLIP[speed]) + (0.05 if str(p.get("temper", "")) == "sour" else 0.0)
		var did := false
		var role := str(p.get("role", ""))
		match role:
			"till":
				# A warden at the till: the hand leaves it to them.
				did = not till_held(key) and _crew_till(key, 0, slip, speed)
			"till2":
				did = BUSINESS.has_gear(key, "till2") and _crew_till(key, 1, slip, speed)
			"shelves":
				did = _crew_shelves(key, slip)
			"store":
				did = _crew_store(key)
			"deli":
				did = _crew_deli(key, slip)
		var k := 1.0
		if role == "store" and BUSINESS.has_gear(key, "pallet"):
			k = 0.5
		elif role.begins_with("till"):
			k = 0.8
		_crew_t[id] = float(BIZ_RULES.SPEED_SEC[speed]) * k if did else 1.0


## The deli's hand cuts the oldest order: a little over, mostly; well off now and then.
func _crew_deli(key: String, slip: bool) -> bool:
	var open := deli_tickets(key)
	if open.is_empty():
		return false
	var t: Dictionary = open[0]
	var want := float(t["want"])
	var grams := want * _rng.randf_range(1.0, 1.08)
	if slip:
		grams = want * _rng.randf_range(1.12, 1.3)
	var got := 0.0
	var slice := float(RULES.DELI[str(t["good"])]["slice"])
	while got < grams:
		var c := cut_slice(key, str(t["good"]), slice)
		if c <= 0.0:
			break
		got += c
	if got <= 0.0:
		return false
	deli_serve(key, t, got, true, true)
	return true


func _crew_till(key: String, place: int, slip: bool, _speed: int) -> bool:
	var q := tickets(key)
	if q.size() <= place:
		return false
	var t: Dictionary = q[place]
	var given := int(t["due"])
	if slip and given > 0:
		given += 1 + _rng.randi() % 2
	serve(key, t, given, true)
	return true


func _crew_shelves(key: String, slip: bool) -> bool:
	var best := ""
	var best_fill := 999
	for g in RULES.all_goods():
		if int(trolley(key).get(g, 0)) <= 0:
			continue
		var fill := int(shelf(key).get(g, 0))
		if fill < cap(key) and fill < best_fill:
			best = g
			best_fill = fill
	if best == "":
		return false
	if slip and _rng.randf() < 0.3:
		# A box dropped: what was in it broken.
		var n := mini(2, int(trolley(key)[best]))
		act(key, "trolley", [best, -n])
		if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_waste"):
			CoreRoot.actions.biz_waste(key, {best: n})
		return true
	return shelve(key, best) > 0


func _crew_store(key: String) -> bool:
	var books := BUSINESS.site(key)
	var spoiled := 0
	for g in (books.get("spoiled", {}) as Dictionary):
		spoiled += int(books["spoiled"][g])
	if spoiled > 0 and CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_bin(key)
		return true
	var best := ""
	var best_have := 999
	for g in RULES.all_goods():
		if backroom(key, g) <= 0 or int(trolley(key).get(g, 0)) >= RULES.BOX:
			continue
		var have := int(shelf(key).get(g, 0)) + int(trolley(key).get(g, 0))
		if have < best_have:
			best = g
			best_have = have
	if best == "" or best_have >= cap(key) + RULES.BOX:
		return false
	return make_box(key, best) > 0


# ── debug (tools/jednota_check.gd, tools/jednota_shots.gd, podniky_coop.gd) ──

## A good the storeroom has a box of and the rack has room for ("" none).
func debug_good_with_room(key: String) -> String:
	for g in RULES.all_goods():
		if backroom(key, g) >= RULES.BOX and int(shelf(key).get(g, 0)) <= cap(key) - 2:
			return g
	for g in RULES.all_goods():
		if backroom(key, g) >= RULES.BOX:
			act(key, "shelf", [g, -mini(3, int(shelf(key).get(g, 0)))])
			return g
	return ""


## The units of the rack and of the trolley: [rack, trolley].
func debug_counts(key: String) -> Array:
	var r := 0
	var t := 0
	for g in RULES.all_goods():
		r += int(shelf(key).get(g, 0))
		t += int(trolley(key).get(g, 0))
	return [r, t]


## `good` on the rack set to `n` (the rest stays in the storeroom).
func debug_set_shelf(key: String, good: String, n: int) -> void:
	act(key, "shelf", [good, n - int(shelf(key).get(good, 0))])


## Everyone looking round has looked round: their baskets taken now.
func debug_pick_all(key: String) -> void:
	var s := site(key)
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		if not (s["picked"].has(visit) or s["gone"].has(visit) or s["served"].has(visit)):
			var range_of := BUSINESS.site(key)
			var want: Array = RULES.basket_for(visit, str(v.get("archetype", ""))).filter(func(g) -> bool: return BIZ_RULES.menu_on("vecerka", range_of, str(g)))
			var got: Array = []
			var shelf_now: Dictionary = (s["shelf"] as Dictionary).duplicate()
			var short := 0
			for g in want:
				if int(shelf_now.get(str(g), 0)) > 0:
					shelf_now[str(g)] = int(shelf_now[str(g)]) - 1
					got.append(str(g))
				else:
					short += 1
			act(key, "picked", [visit, got, short, str(v.get("name", ""))])


## The oldest deli order cut to its weight, wrapped and handed over: true when there was
## one.
func debug_deli_first(key: String) -> bool:
	var open := deli_tickets(key)
	if open.is_empty():
		return false
	var t: Dictionary = open[0]
	return bool(deli_serve(key, t, float(t["want"]), true).get("ok", false))


## A deli order for the first one in the shop who has none (the shot drivers): `good`,
## `want` grams.
func debug_deli_order(key: String, good: String, want: int) -> bool:
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		if site(key)["deli"].has(visit) and not bool(site(key)["deli"][visit].get("gone", false)):
			continue
		act(key, "deli", [visit, {"good": good, "want": want, "since": now_min(), "done": 0}])
		return true
	return false

