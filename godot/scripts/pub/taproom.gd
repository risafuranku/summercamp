extends Node

## The pubs' bars while the game runs (core/systems/pub_rules.gd has the numbers; DESIGN.md
## §7b the idea), the bistro's kitchen.gd made for the pub. One node for the game, made
## the first time a pub needs it (of()), a record per pub ("x:y" key) of what is in it:
##   served  what was poured for whom: ticket id -> {drink, at (game minute), stars, amount,
##           tip}; a settled bill: "<visit>#bill" -> {bill: true, at, kept, over, left}
##   mugs    {clean, dirty}: every beer goes out in a clean mug and comes back dirty when
##           it has been drunk
##   keg     the keg on the line in the cellar: {line (pints left in it), coupled (the
##           head on it), pallet ("full", "empty" spent, "none" rolled off), gas 0..1}
##   pints   pints drawn since the gas last crept down a notch
##   fun     the pub's games as they stand (pub_fun.gd): slot {id, seed, who, name} (the
##           last game on the LUCKY 7), darts {at: [[x, y] x3], total, name} (the last turn
##           in the board), guest {name, total} (the last guest's turn: what to beat),
##           played {visit: true} (who has had their go this visit)
## The orders are not kept: they are worked out each time from whoever the guest
## simulation has in the pub and what was served (pub_rules.tickets_for), so every
## machine in co-op has the same ones; only what was served is told. Nothing is paid as
## it is poured: it goes on their tab (a mark on the mat) and the bill is settled when
## they go (pub_rules.bill_for, settle): the money comes in then.
##
## Co-op (up to four): everything done here is an op (`act`) applied at once and sent to
## everyone (Coop.send_taproom); counts go as changes, the keg as its whole new state.
## The host sends the mugs back dirty when they have been drunk, does a hand's work and
## keeps the keg and the mugs in the books for the save (actions.biz_tap). A machine
## that joins asks the host for the bars as they are.

const RULES := preload("res://core/systems/pub_rules.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const BIZ_RULES := preload("res://core/systems/business_rules.gd")
const FUN := preload("res://core/systems/pub_fun.gd")
const CREW_PLACES := preload("res://scripts/business/crew_places.gd")
## Days a keg keeps on the line before it is flat (twice as long with the keg cooler).
const KEG_DAYS := 3

## A record changed (key, what: "served", "mugs", "keg").
signal changed(key: String, what: String)
## A drink went out (key, ticket id, its record): the room shows it land.
signal poured(key: String, tid: String, rec: Dictionary)

var _sites: Dictionary = {}
var _acc := 0.0
var _save_due: Dictionary = {}
## Host: the mugs already sent back to the washer (ticket id -> true).
var _returned: Dictionary = {}
var _asked_snap := false
var _state_id := 0


func _ready() -> void:
	name = "Taprooms"
	add_to_group("taprooms")


## The game's taproom node, made under the businesses (or the root) when first asked for.
static func of(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var t := tree.get_first_node_in_group("taprooms")
	if t != null:
		return t
	var parent: Node = tree.get_first_node_in_group("businesses")
	if parent == null:
		parent = tree.root
	t = load("res://scripts/pub/taproom.gd").new()
	parent.add_child(t)
	return t


# ── the record ───────────────────────────────────────────────────────────────

func site(key: String) -> Dictionary:
	if not _sites.has(key):
		_sites[key] = _fresh(key)
	return _sites[key]


func _fresh(key: String) -> Dictionary:
	var books := BUSINESS.site(key)
	var saved: Dictionary = books.get("tap", {}) if books.get("tap", {}) is Dictionary else {}
	# The mugs the old washer kept in the books (site.glasses) carry over.
	var old: Dictionary = books.get("glasses", {}) if books.get("glasses", {}) is Dictionary else {}
	var beer := maxi(0, BUSINESS.stock_of(key, "beer"))
	return {
		"served": {},
		"mugs": {"clean": int(saved.get("clean", old.get("clean", RULES.MUGS))), "dirty": int(saved.get("dirty", old.get("dirty", 0)))},
		"keg": {"line": int(saved.get("line", mini(RULES.KEG_PINTS, beer))), "coupled": bool(saved.get("coupled", true)),
			"pallet": str(saved.get("pallet", "full")), "gas": float(saved.get("gas", RULES.GAS_START)),
			"tapped": int(saved.get("tapped", CoreRoot.get_day() if CoreRoot != null else 1))},
		"pints": int(saved.get("pints", 0)),
		"fun": {"slot": {}, "darts": {}, "guest": {}, "played": {}},
	}


func mugs(key: String) -> Dictionary:
	return site(key)["mugs"]


func keg(key: String) -> Dictionary:
	return site(key)["keg"]


## Full kegs standing in the cellar besides the one on the line (the books' beer).
func spares(key: String) -> int:
	var k := keg(key)
	var on_line := int(k["line"]) if str(k["pallet"]) == "full" else 0
	return maxi(0, ceili(float(maxi(0, BUSINESS.stock_of(key, "beer")) - on_line) / float(RULES.KEG_PINTS)))


## Why the tap gives nothing ("" it pours): the keg spent or off the line, no beer; or
## "flat": it pours, but the keg has been on the line too long (no head, poor beer).
func tap_trouble(key: String) -> String:
	var k := keg(key)
	if BUSINESS.stock_of(key, "beer") == 0:
		return "dry"
	if str(k["pallet"]) != "full" or int(k["line"]) <= 0:
		return "empty"
	if not bool(k["coupled"]):
		return "off"
	if is_flat(key):
		return "flat"
	return ""


## The keg on the line has gone flat (KEG_DAYS since it was tapped, twice that with the
## keg cooler).
func is_flat(key: String) -> bool:
	var k := keg(key)
	if str(k["pallet"]) != "full" or not CoreRoot:
		return false
	var days := KEG_DAYS * (2 if BUSINESS.has_gear(key, "cooler") else 1)
	return CoreRoot.get_day() - int(k.get("tapped", CoreRoot.get_day())) >= days


## What is left in a flat keg goes down the drain (the books: waste).
func waste_keg(key: String) -> void:
	var n := mini(int(keg(key)["line"]), maxi(0, BUSINESS.stock_of(key, "beer")))
	if n > 0 and CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_waste"):
		CoreRoot.actions.biz_waste(key, {"beer": n})


# ── orders ───────────────────────────────────────────────────────────────────

static func now_min() -> int:
	if GuestManager == null:
		return 0
	return int(GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute))


## Open orders at `key`, oldest first: [{id, visit, member, round, guest_id, name, arch,
## drink, price, since, age}]. Nobody a hand served; one per person at a time.
func tickets(key: String) -> Array:
	var out: Array = []
	var now := now_min()
	var served: Dictionary = site(key)["served"]
	var books := BUSINESS.site(key)
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		# A hand behind the bar served the lot (business_runtime._hand_serves).
		if int(ORDERS._served.get(visit, 0)) > 0 and not _any_served(served, visit):
			continue
		# Asking for the bill: no more rounds.
		if served.has(visit + "#bill") or now >= int(v.get("arrive", now)) + RULES.stay(str(v["archetype"])) - RULES.BILL_LEAD:
			continue
		for t in RULES.tickets_for(visit, str(v["archetype"]), int(v.get("figures", 1)), int(v.get("arrive", now)), served, now):
			# Nothing new after last orders (the brief of 21. 10.).
			if not BUSINESS.takes_orders_at(key, int(t["since"])):
				continue
			# Off the books' menu: they have a beer instead (the beer is never off).
			if not BIZ_RULES.menu_on("pub", books, str(t["drink"])):
				t["drink"] = "hladinka"
				t["price"] = int(RULES.DRINKS["hladinka"]["price"])
			t["visit"] = visit
			t["guest_id"] = int(v["id"])
			t["name"] = str(v["name"])
			t["arch"] = str(v["archetype"])
			out.append(t)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["since"]) < int(b["since"]) or (int(a["since"]) == int(b["since"]) and str(a["id"]) < str(b["id"])))
	return out


## The bills asked for at `key`, oldest first: [{id, kind "bill", visit, guest_id, name,
## counts, total, make_it, note, since, age}] (pub_rules.bill_for).
func bills(key: String) -> Array:
	var out: Array = []
	var now := now_min()
	var served: Dictionary = site(key)["served"]
	for v in ORDERS.visitors(key):
		var b := RULES.bill_for(str(v["visit"]), str(v["archetype"]), int(v.get("figures", 1)), int(v.get("arrive", now)), served, now)
		if b.is_empty():
			continue
		b["guest_id"] = int(v["id"])
		b["name"] = str(v["name"])
		b["arch"] = str(v["archetype"])
		out.append(b)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["since"]) < int(b["since"]))
	return out


## The bill of `visit` ({} none asked for).
func bill_of(key: String, visit: String) -> Dictionary:
	for b in bills(key):
		if str(b["visit"]) == visit:
			return b
	return {}


## A bill settled: `given` the change counted out (judged against what is due), the money
## in the till (what they paid less the change), their mood. Returns the verdict: {ok,
## kept, over, short, accuracy, speed, score, stars, tip}; not ok when the change was
## short (they say so and wait).
func settle(key: String, b: Dictionary, given: int, by_hand := false) -> Dictionary:
	var due := RULES.change_due(b)
	var v := RULES.judge_change(given, due, int(b.get("age", 0)))
	if not bool(v["ok"]):
		return v
	var to_pay := RULES.to_pay(b)
	var kept := to_pay - int(v["over"])
	var pts := BIZ_RULES.score(float(v["speed"]), float(v["accuracy"]))
	var r := BIZ_RULES.reward(pts, to_pay)
	v["score"] = pts
	v["stars"] = int(r["stars"])
	v["tip"] = maxi(0, to_pay - int(b.get("total", 0)))
	v["kept"] = kept
	v["amount"] = kept
	v["build"] = float(v["accuracy"])
	_take_money(key, kept, by_hand)
	act(key, "served", [str(b["id"]), {"bill": true, "at": now_min(), "kept": kept, "over": int(v["over"]), "left": false}])
	ORDERS.mood(int(b.get("guest_id", -1)), 0.5 if int(v["over"]) == 0 else 0.2, "")
	if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_score"):
		CoreRoot.actions.biz_score(key, {"score": pts, "tip": 0, "what": "The bill", "who": str(b.get("name", "")), "hand": by_hand})
	return v


## The money for a tab into the till (the books' takings; a sale of nothing).
func _take_money(key: String, amount: int, by_hand: bool) -> void:
	if amount <= 0 or CoreRoot == null or CoreRoot.actions == null:
		return
	if (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).has(key):
		CoreRoot.actions.biz_sale(key, amount, 0, by_hand)
	else:
		ORDERS.pay(amount)


func _any_served(served: Dictionary, visit: String) -> bool:
	for tid in served:
		if str(tid).begins_with(visit + "#"):
			return true
	return false


## The open order of `visit`'s person `member` ({} none): the bubble over their head.
func ticket_of(key: String, visit: String, member: int) -> Dictionary:
	for t in tickets(key):
		if str(t["visit"]) == visit and int(t["member"]) == member:
			return t
	return {}


## What `visit`'s person `member` has in front of them now ({} nothing): the last drink
## poured for them while they are still drinking it, or a hand's beer.
func glass_of(key: String, visit: String, member: int) -> Dictionary:
	var served: Dictionary = site(key)["served"]
	var now := now_min()
	var best := {}
	for tid in served:
		if not str(tid).begins_with("%s#%d/" % [visit, member]):
			continue
		var rec: Dictionary = served[tid]
		if now - int(rec.get("at", 0)) < RULES.DRINK_MINUTES and int(rec.get("at", 0)) >= int(best.get("at", -1)):
			best = rec
	if best.is_empty() and int(ORDERS._served.get(visit, 0)) > 0 and not _any_served(served, visit):
		return {"drink": "hladinka", "hand": true}
	return best


## Strokes on `visit`'s person `member`'s beer mat (what they have had).
func strokes(key: String, visit: String, member: int) -> int:
	var n := 0
	for tid in site(key)["served"]:
		if str(tid).begins_with("%s#%d/" % [visit, member]):
			n += 1
	return n


# ── doing things: ops ────────────────────────────────────────────────────────

## Do `op` here and tell the others. ops:
##   served [ticket id, record]
##   mugs [clean delta, dirty delta]
##   keg [state]
##   pints [delta]
func act(key: String, op: String, args: Array) -> void:
	_apply(key, op, args)
	if Coop.is_active() and Coop.has_method("send_taproom"):
		Coop.send_taproom(key, op, args)


func _apply(key: String, op: String, args: Array) -> void:
	var s := site(key)
	match op:
		"served":
			var rec: Dictionary = (args[1] as Dictionary).duplicate(true)
			s["served"][str(args[0])] = rec
			poured.emit(key, str(args[0]), rec)
		"mugs":
			var m: Dictionary = s["mugs"]
			m["clean"] = maxi(0, int(m["clean"]) + int(args[0]))
			m["dirty"] = maxi(0, int(m["dirty"]) + int(args[1]))
			_save_due[key] = true
		"keg":
			s["keg"] = (args[0] as Dictionary).duplicate(true)
			_save_due[key] = true
		"pints":
			s["pints"] = maxi(0, int(s["pints"]) + int(args[0]))
		"slot":
			s["fun"]["slot"] = (args[0] as Dictionary).duplicate(true)
		"darts":
			s["fun"]["darts"] = (args[0] as Dictionary).duplicate(true)
			if str(args[0].get("name", "")) != "you":
				s["fun"]["guest"] = {"name": str(args[0]["name"]), "total": int(args[0].get("total", 0))}
		"played":
			s["fun"]["played"][str(args[0])] = true
		"snap":
			var got: Dictionary = args[0]
			for k in ["mugs", "keg"]:
				if got.has(k):
					s[k] = (got[k] as Dictionary).duplicate(true)
			s["pints"] = int(got.get("pints", s["pints"]))
			for tid in (got.get("served", {}) as Dictionary):
				s["served"][tid] = got["served"][tid]
	changed.emit(key, op)


## From another machine (Coop.send_taproom).
func coop_taproom(key: String, op: String, args: Array) -> void:
	if op == "hello":
		if Coop.is_host():
			for k in _sites:
				Coop.send_taproom(str(k), "snap", [_snapshot(str(k))])
		return
	_apply(key, op, args)


func _snapshot(key: String) -> Dictionary:
	var s := site(key)
	return {"served": s["served"], "mugs": s["mugs"], "keg": s["keg"], "pints": s["pints"]}


# ── the fun (pub_fun.gd) ─────────────────────────────────────────────────────

func fun(key: String) -> Dictionary:
	return site(key)["fun"]


## A game on the LUCKY 7 (`who`: "you", or a guest's name): the reels spin on every
## machine for everyone in the pub.
func slot_play(key: String, seed: int, who: String) -> void:
	_slots += 1
	act(key, "slot", [{"id": "%d-%d" % [multiplayer.get_unique_id() if multiplayer != null and multiplayer.has_multiplayer_peer() else 1, _slots], "seed": seed, "who": who}])


var _slots := 0


## A warden's game done (slot_station.gd): three sevens and the pub cheers.
func slot_done(key: String, spin: Dictionary) -> void:
	var reels := FUN.spin(int(spin.get("seed", 0)))
	if FUN.payout(reels) < int(FUN.PAY_THREE["seven"]):
		return
	for v in ORDERS.visitors(key):
		ORDERS.mood(int(v["id"]), 1.0, "The warden hit three sevens on the LUCKY 7. The whole pub cheered.")
	_feed("Three sevens on the LUCKY 7! The whole pub is cheering.")


## A warden's turn of darts done (darts_station.gd): against the last guest's in the
## board. Returns {name, theirs}; the guest liked the game either way.
func darts_done(key: String, at: Array, total: int) -> Dictionary:
	var d: Dictionary = fun(key).get("guest", {})
	var out := {"name": "", "theirs": 0}
	for v in ORDERS.visitors(key):
		if str(v["name"]) == str(d.get("name", "")):
			out = {"name": ORDERS.first_name(str(v["name"])), "theirs": int(d.get("total", 0))}
			ORDERS.mood(int(v["id"]), 0.5, "Played darts with the warden at the pub.")
			break
	var pts: Array = []
	for a in at:
		pts.append([float((a as Vector2).x), float((a as Vector2).y)])
	act(key, "darts", [{"at": pts, "total": total, "name": "you"}])
	return out


## A warden's game of cards with a guest done: `r` 1 you won (their stake into the
## till), -1 they won (yours to them, and they like you better), 0 a draw.
func cards_done(key: String, guest_id: int, r: int) -> void:
	if r > 0:
		_take_money(key, FUN.STAKE, true)
		ORDERS.mood(guest_id, 0.2, "Lost two dollars to the warden at cards. Good game.")
	elif r < 0:
		if CoreRoot != null and CoreRoot.actions != null:
			CoreRoot.actions.spend_money(FUN.STAKE)
		ORDERS.mood(guest_id, 1.0, "Won two dollars off the warden at cards.")


## Host, once a second: the guests have their go at the LUCKY 7 and the darts, once a
## visit each, when their minute comes (pub_fun by kind): what they feed the machine is
## the pub's takings, and they like the pub better for it.
const SLOT_ODDS := {"drunk": 0.75, "tramp": 0.5, "cheap_chick": 0.4, "quiet_guy": 0.2, "picker": 0.1, "family": 0.15}
const DARTS_ODDS := {"drunk": 0.5, "tramp": 0.4, "cheap_chick": 0.3, "quiet_guy": 0.2, "picker": 0.1, "family": 0.5}


func _guests_play(key: String, now: int) -> void:
	var f: Dictionary = fun(key)
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		var arch := str(v["archetype"])
		var h := absi(hash(visit + ":fun"))
		# Their go comes a while after they sit down, at a minute of their own.
		var at := int(v.get("arrive", now)) + 6 + h % 30
		if now < at:
			continue
		if not f["played"].has(visit + ":slot") and float(h % 100) / 100.0 < float(SLOT_ODDS.get(arch, 0.2)):
			act(key, "played", [visit + ":slot"])
			var games := 4 + h % 9
			var take := maxi(1, int(round(float(games * FUN.COIN) * maxf(0.2, FUN.house_edge()))))
			slot_play(key, h, str(v["name"]))
			_take_money(key, take, false)
			ORDERS.mood(int(v["id"]), 0.5, "")
		elif not f["played"].has(visit + ":darts") and float((h / 100) % 100) / 100.0 < float(DARTS_ODDS.get(arch, 0.2)) and now >= at + 10:
			act(key, "played", [visit + ":darts"])
			var darts := FUN.guest_turn(arch, h)
			var total := 0
			var pts: Array = []
			for d in darts:
				total += FUN.dart_score(d)
				pts.append([float(d.x), float(d.y)])
			act(key, "darts", [{"at": pts, "total": total, "name": str(v["name"])}])
			ORDERS.mood(int(v["id"]), 0.4, "")


## Sets the keg's state (a copy changed by `edit`).
func set_keg(key: String, edit: Dictionary) -> void:
	var k := keg(key).duplicate(true)
	for f in edit:
		k[f] = edit[f]
	act(key, "keg", [k])


## A drink goes out for order `t`: judged already (`verdict`, ok), sold (the money is the
## camp's, the books count it), the guest's mood, a mug off the rack for a beer and a
## pint off the keg. Returns the verdict with its amount; {ok: false, why} when the
## shelf is short.
func serve(key: String, t: Dictionary, verdict: Dictionary) -> Dictionary:
	var drink := str(t["drink"])
	var good := str(RULES.DRINKS[drink]["good"])
	# Papa's: the score from the pour and the wait, the tip and the stars from it.
	var pts := BIZ_RULES.score(float(verdict.get("speed", 1.0)), float(verdict.get("accuracy", 1.0)))
	var r := BIZ_RULES.reward(pts, int(t["price"]))
	verdict["score"] = pts
	verdict["tip"] = int(r["tip"])
	verdict["stars"] = int(r["stars"])
	verdict["mood"] = float(r["mood"])
	# On the tab: the goods off the shelf now, the money when they pay (the mark's price).
	var amount := int(round(float(RULES.TAB[RULES.tab_class(drink)]["price"]) * BUSINESS.price_k(key)))
	if not BUSINESS.sell(key, {good: 1}, 0):
		return {"ok": false, "why": "dry"}
	verdict["amount"] = amount
	verdict["tab"] = true
	var v := {"id": int(t["guest_id"]), "visit": str(t["visit"])}
	ORDERS.note_served(v)
	var hand := BUSINESS.hand_mood(key, "tap" if RULES.kind(drink) == "tap" else "bar") if bool(verdict.get("hand", false)) else 0.0
	ORDERS.mood(int(t["guest_id"]), float(verdict.get("mood", 0.0)) + hand, _thought(drink, verdict))
	if RULES.kind(drink) == "tap":
		act(key, "mugs", [-1, 0])
		var k := keg(key).duplicate(true)
		k["line"] = maxi(0, int(k["line"]) - 1)
		if int(k["line"]) == 0:
			k["pallet"] = "empty"
		if int(site(key)["pints"]) + 1 >= int(RULES.GAS_LEAK):
			k["gas"] = maxf(0.0, float(k["gas"]) - 0.05)
			act(key, "pints", [-int(site(key)["pints"])])
		else:
			act(key, "pints", [1])
		act(key, "keg", [k])
	act(key, "served", [str(t["id"]), {"drink": drink, "at": now_min(), "stars": int(verdict.get("stars", 0)), "amount": amount, "tip": int(verdict.get("tip", 0))}])
	ORDERS.note_meal(int(t["guest_id"]), _thought(drink, verdict), pts)
	if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_score"):
		CoreRoot.actions.biz_score(key, {"score": pts, "tip": int(verdict["tip"]), "what": RULES.label(drink), "who": str(t.get("name", "")), "hand": bool(verdict.get("hand", false))})
	return verdict


func _thought(drink: String, verdict: Dictionary) -> String:
	if int(verdict.get("stars", 0)) >= 3:
		return "The camp pub pours a proper %s." % RULES.label(drink).to_lower()
	if float(verdict.get("speed", 1.0)) < 0.3:
		return "Waited forever for a beer."
	if float(verdict.get("accuracy", 1.0)) < 0.6:
		return "The beer here is poured by a child." if RULES.kind(drink) == "tap" else "They fill the shots by half at the camp pub."
	return ""


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
		_returned.clear()
		_save_due.clear()
		_asked_snap = false
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	if Coop.is_client() and not _asked_snap and Coop.has_method("send_taproom"):
		_asked_snap = true
		Coop.send_taproom("", "hello", [])
	if not Coop.sim_here():
		return
	_host_second()


## Host, once a second: the mugs drunk come back to the washer, the keg follows the books
## (a keg cannot hold more than the cellar has), a hand's work, the save.
func _host_second() -> void:
	var now := now_min()
	for key in _pub_sites():
		var s := site(key)
		var served: Dictionary = s["served"]
		var here := {}
		for v in ORDERS.visitors(key):
			here[str(v["visit"])] = true
		for tid in served:
			if _returned.has(tid) or RULES.kind(str(served[tid].get("drink", ""))) != "tap":
				continue
			var visit := str(tid).get_slice("#", 0)
			if now - int(served[tid].get("at", now)) >= RULES.DRINK_MINUTES or not here.has(visit):
				_returned[tid] = true
				act(key, "mugs", [0, 1])
		var k: Dictionary = s["keg"]
		var beer := maxi(0, BUSINESS.stock_of(key, "beer"))
		if int(k["line"]) > beer:
			set_keg(key, {"line": beer, "pallet": "empty" if beer == 0 else str(k["pallet"])})
		_bills_waiting(key, now)
		_guests_play(key, now)
		var crew: Array = BUSINESS.crew_now(key)
		if not crew.is_empty():
			_crew_work(key, crew)
		elif BUSINESS.has_gear(key, "glasswasher"):
			_glasswasher(key)
		if _save_due.has(key):
			_save_due.erase(key)
			_save(key)


## Host: the guests with a tab open are kept in the pub till it is settled (orders
## .set_holds "pub"); a bill nobody comes for in BILL_WAIT is left on the bar as the right
## money by a guest who liked it here, and by one who did not, not at all.
var _holds: Dictionary = {}


func _bills_waiting(key: String, now: int) -> void:
	var served: Dictionary = site(key)["served"]
	var holds := {}
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		if served.has(visit + "#bill"):
			continue
		var tab := RULES.tab_of(visit, served)
		if int(tab["n"]) <= 0:
			continue
		holds[int(v["id"])] = int(v.get("arrive", now)) + RULES.stay(str(v["archetype"])) + RULES.BILL_WAIT + 2
	# Who has ordered waits for it to the end of their patience, past closing.
	for t in tickets(key):
		holds[int(t["guest_id"])] = maxi(int(holds.get(int(t["guest_id"]), -1)), int(t["since"]) + RULES.PATIENCE_GONE)
	for b in bills(key):
		holds[int(b["guest_id"])] = int(b["since"]) + RULES.BILL_WAIT + 2
		if int(b["age"]) < RULES.BILL_WAIT:
			continue
		var stars := _stars_of(served, str(b["visit"]))
		var left := stars >= 1.8
		var kept := int(b["total"]) if left else 0
		_take_money(key, kept, false)
		act(key, "served", [str(b["id"]), {"bill": true, "at": now, "kept": kept, "over": 0, "left": true}])
		var who := ORDERS.first_name(str(b.get("name", "A guest")))
		_feed("%s left the money for their tab on the bar." % who if left else "%s walked out of the pub without paying." % who)
		if not left:
			ORDERS.mood(int(b["guest_id"]), -1.0, "Nobody came to take my money at the pub.")
		holds.erase(int(b["guest_id"]))
	_holds[key] = holds
	var all := {}
	for k in _holds:
		for gid in _holds[k]:
			all[gid] = maxi(int(all.get(gid, -1)), int(_holds[k][gid]))
	ORDERS.set_holds("pub", all)


func _stars_of(served: Dictionary, visit: String) -> float:
	var n := 0
	var sum := 0
	for tid in served:
		if str(tid).begins_with(visit + "#") and not str(tid).ends_with("#bill"):
			n += 1
			sum += int((served[tid] as Dictionary).get("stars", 1))
	return float(sum) / float(maxi(1, n))


func _feed(text: String) -> void:
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("push_status"):
		hud.push_status(text, 0, "pub_bill")


func _pub_sites() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	for key in sites:
		if str((sites[key] as Dictionary).get("kind", "")) == "pub":
			out.append(str(key))
	return out


## The keg, the gas and the mugs into the books (they are saved with the camp).
func _save(key: String) -> void:
	if CoreRoot == null or CoreRoot.actions == null or not CoreRoot.actions.has_method("biz_tap"):
		return
	var s := site(key)
	var k: Dictionary = s["keg"]
	CoreRoot.actions.biz_tap(key, {"line": int(k["line"]), "coupled": bool(k["coupled"]), "pallet": str(k["pallet"]),
		"gas": float(k["gas"]), "clean": int(s["mugs"]["clean"]), "dirty": int(s["mugs"]["dirty"]), "pints": int(s["pints"]),
		"tapped": int(k.get("tapped", 0))})


## The hands at the pub (DESIGN.md §7b, the hands), one piece of work at a time as their
## speed allows; now and then one goes wrong (a pour short or over, a mug dropped, the gas
## left wrong). Each works a station (crew_places: their own job's, or beside you where it
## is wanted while you are at theirs):
##   tap     pours the oldest beer ordered (a fair pour, never a perfect one), takes bills
##   back    pours the shots and the kofola, takes bills
##   wash    washes the mugs (the glass washer, bought, does it alone)
##   keg     changes a spent or flat keg and sets the gas right
var _crew_t: Dictionary = {}
var _rng := RandomNumberGenerator.new()
const ROLE_AT := {"tap": "tap", "bar": "back", "wash": "wash", "cellar": "keg"}
const CREW_STATIONS := ["tap", "back", "keg", "wash"]


## slug -> the station that hand works now ("" aside), at `key`.
func crew_places(key: String) -> Dictionary:
	var crew: Array = BUSINESS.crew_now(key)
	if crew.is_empty():
		return {}
	var busy: Array = CREW_PLACES.wardens_at(get_tree(), key, "service") if is_inside_tree() else []
	return CREW_PLACES.places(crew, ROLE_AT, CREW_STATIONS, busy, func(st: String) -> float: return station_need(key, st))


## How much a station of the pub wants doing now (0 nothing): beers and drinks ordered and
## bills waiting at the bar, dirty mugs (the more the fewer clean), a keg to change.
func station_need(key: String, st: String) -> float:
	var n_bills := bills(key).size()
	match st:
		"tap", "back":
			var n := 0
			if st == "back" or (tap_trouble(key) in ["", "flat"] and int(mugs(key)["clean"]) > 0):
				for t in tickets(key):
					if RULES.kind(str(t["drink"])) == ("tap" if st == "tap" else "bar"):
						n += 1
			return (0.5 + 0.25 * float(n) if n > 0 else 0.0) + 0.4 * float(n_bills)
		"wash":
			if BUSINESS.has_gear(key, "glasswasher"):
				return 0.0
			var m: Dictionary = mugs(key)
			if int(m["dirty"]) <= 0:
				return 0.0
			return minf(1.0, 0.15 * float(m["dirty"])) + (0.6 if int(m["clean"]) <= 0 else 0.0)
		"keg":
			var k: Dictionary = keg(key)
			if BUSINESS.stock_of(key, "beer") > 0 and (str(k["pallet"]) != "full" or int(k["line"]) <= 0 or is_flat(key)):
				return 1.2
			if float(k["gas"]) < RULES.GAS_LOW or float(k["gas"]) > RULES.GAS_HIGH:
				return 0.8
	return 0.0


func _crew_work(key: String, crew: Array) -> void:
	if BUSINESS.has_gear(key, "glasswasher"):
		_glasswasher(key)
	var places := crew_places(key)
	for p in crew:
		var id := key + "/" + str(p.get("slug", ""))
		var left := float(_crew_t.get(id, 0.0)) - 1.0
		if left > 0.0:
			_crew_t[id] = left
			continue
		var speed := clampi(int(p.get("speed", 1)), 0, 2)
		var slip := _rng.randf() < float(BIZ_RULES.SPEED_SLIP[speed]) + (0.05 if str(p.get("temper", "")) == "sour" else 0.0)
		var did := false
		var at := str(places.get(str(p.get("slug", "")), ""))
		match at:
			"tap":
				did = _crew_bill(key, slip) or _crew_pour(key, p, "tap", slip, speed)
			"back":
				did = _crew_bill(key, slip) or _crew_pour(key, p, "bar", slip, speed)
			"wash":
				did = _crew_wash(key, slip)
			"keg":
				did = _crew_cellar(key)
		# Two taps (gear): the tap's hand draws two at once.
		if did and at == "tap" and BUSINESS.has_gear(key, "tap2"):
			_crew_pour(key, p, "tap", slip, speed)
		var k := 0.7 if at in ["tap", "back"] else 1.0
		# The quick coupler (gear): a keg changed in a moment.
		if at == "keg" and BUSINESS.has_gear(key, "coupler"):
			k = 0.4
		_crew_t[id] = float(BIZ_RULES.SPEED_SEC[speed]) * k if did else 1.0


## A hand behind the bar takes the oldest bill: counts the marks and gives the change
## (a coin or two over now and then).
func _crew_bill(key: String, slip: bool) -> bool:
	var open := bills(key)
	if open.is_empty():
		return false
	var b: Dictionary = open[0]
	var due := RULES.change_due(b)
	var given := due + (_rng.randi_range(1, 2) if slip and due > 0 else 0)
	settle(key, b, given, true)
	return true


## The oldest order of the kind poured, judged as a fair pour by a hand.
func _crew_pour(key: String, p: Dictionary, kind_of: String, slip: bool, speed: int) -> bool:
	if kind_of == "tap" and (tap_trouble(key) not in ["", "flat"] or int(mugs(key)["clean"]) <= 0):
		return false
	for t in tickets(key):
		var drink := str(t["drink"])
		if RULES.kind(drink) != kind_of:
			continue
		var acc := 0.62 + 0.12 * float(speed) + _rng.randf_range(-0.05, 0.08)
		if slip:
			acc -= 0.35
		if kind_of == "tap" and is_flat(key):
			acc *= 0.6
		var speed_k := 1.0 if int(t["age"]) < RULES.PATIENCE_OK * 0.6 else (0.6 if int(t["age"]) < RULES.PATIENCE_OK else (0.3 if int(t["age"]) < RULES.PATIENCE_LATE else 0.0))
		var v := {"ok": true, "accuracy": clampf(acc, 0.1, 0.95), "speed": speed_k, "hand": true}
		var verdict: Dictionary = serve(key, t, v)
		return bool(verdict.get("ok", false))
	return false


func _crew_wash(key: String, slip: bool) -> bool:
	var m: Dictionary = mugs(key)
	if int(m["dirty"]) <= 0:
		return false
	# Now and then one slips out of their hands.
	if slip and _rng.randf() < 0.3:
		act(key, "mugs", [0, -1])
	else:
		act(key, "mugs", [1, -1])
	return true


func _crew_cellar(key: String) -> bool:
	var k: Dictionary = keg(key)
	var beer := maxi(0, BUSINESS.stock_of(key, "beer"))
	if (str(k["pallet"]) != "full" or int(k["line"]) <= 0 or is_flat(key)) and beer > 0:
		if is_flat(key):
			waste_keg(key)
			beer = maxi(0, BUSINESS.stock_of(key, "beer"))
			if beer <= 0:
				set_keg(key, {"pallet": "none", "line": 0})
				return true
		set_keg(key, {"pallet": "full", "line": mini(RULES.KEG_PINTS, beer), "coupled": true, "gas": RULES.GAS_START, "tapped": CoreRoot.get_day()})
		return true
	if float(k["gas"]) < RULES.GAS_LOW or float(k["gas"]) > RULES.GAS_HIGH:
		set_keg(key, {"gas": RULES.GAS_START})
		return true
	return false


## The glass washer (gear): the dirty mugs come out clean by themselves.
func _glasswasher(key: String) -> void:
	var m: Dictionary = mugs(key)
	if int(m["dirty"]) > 0:
		act(key, "mugs", [int(m["dirty"]), -int(m["dirty"])])


# ── debug (tools/podniky_coop.gd) ────────────────────────────────────────────

## The oldest bill settled with the right change (as a player counts it): true when
## there was one.
func debug_settle_first(key: String) -> bool:
	var open := bills(key)
	if open.is_empty():
		return false
	return bool(settle(key, open[0], RULES.change_due(open[0]))["ok"])


## A fair pour for the oldest orders (`n` of them), as the tap's hand would.
func debug_pour_some(key: String, n: int) -> int:
	var done := 0
	for t in tickets(key):
		if done >= n:
			break
		if bool(serve(key, t, {"ok": true, "accuracy": 0.9, "speed": 1.0}).get("ok", false)):
			done += 1
	return done
