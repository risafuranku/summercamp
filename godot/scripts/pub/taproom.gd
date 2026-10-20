extends Node

## The pubs' bars while the game runs (core/systems/pub_rules.gd has the numbers; DESIGN.md
## §7b the idea), the bistro's kitchen.gd made for the pub. One node for the game, made
## the first time a pub needs it (of()), a record per pub ("x:y" key) of what is in it:
##   served  what was poured for whom: ticket id -> {drink, at (game minute), stars, amount}
##   mugs    {clean, dirty}: every beer goes out in a clean mug and comes back dirty when
##           it has been drunk
##   keg     the keg on the line in the cellar: {line (pints left in it), coupled (the
##           head on it), pallet ("full", "empty" spent, "none" rolled off), gas 0..1}
##   pints   pints drawn since the gas last crept down a notch
## The orders are not kept: they are worked out each time from whoever the guest
## simulation has in the pub and what was served (pub_rules.tickets_for), so every
## machine in co-op has the same ones; only what was served is told.
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
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		# A hand behind the bar served the lot (business_runtime._hand_serves).
		if int(ORDERS._served.get(visit, 0)) > 0 and not _any_served(served, visit):
			continue
		for t in RULES.tickets_for(visit, str(v["archetype"]), int(v.get("figures", 1)), int(v.get("arrive", now)), served, now):
			t["visit"] = visit
			t["guest_id"] = int(v["id"])
			t["name"] = str(v["name"])
			t["arch"] = str(v["archetype"])
			out.append(t)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["since"]) < int(b["since"]) or (int(a["since"]) == int(b["since"]) and str(a["id"]) < str(b["id"])))
	return out


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
	var amount := int(round((int(t["price"]) + int(verdict.get("tip", 0))) * BUSINESS.price_k(key)))
	if not BUSINESS.sell(key, {good: 1}, amount):
		return {"ok": false, "why": "dry"}
	verdict["amount"] = amount
	var v := {"id": int(t["guest_id"]), "visit": str(t["visit"])}
	ORDERS.note_served(v)
	ORDERS.mood(int(t["guest_id"]), float(verdict.get("mood", 0.0)), _thought(drink, verdict))
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
	act(key, "served", [str(t["id"]), {"drink": drink, "at": now_min(), "stars": int(verdict.get("stars", 0)), "amount": amount}])
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
	var sid: int = st.get_instance_id() if st != null else 0
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
		var crew: Array = BUSINESS.crew_now(key)
		if not crew.is_empty():
			_crew_work(key, crew)
		elif BUSINESS.has_gear(key, "glasswasher"):
			_glasswasher(key)
		if _save_due.has(key):
			_save_due.erase(key)
			_save(key)


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


## The hands at the pub, each at their job (DESIGN.md §7b, the hands), one piece of work
## at a time as their speed allows; now and then one goes wrong (a pour short or over,
## a mug dropped, the gas left wrong):
##   tap     pours the oldest beer ordered (a fair pour, never a perfect one)
##   bar     pours the shots and the kofola
##   wash    washes the mugs (the glass washer, bought, does it alone)
##   cellar  changes a spent or flat keg and sets the gas right
var _crew_t: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _crew_work(key: String, crew: Array) -> void:
	if BUSINESS.has_gear(key, "glasswasher"):
		_glasswasher(key)
	for p in crew:
		var id := key + "/" + str(p.get("slug", ""))
		var left := float(_crew_t.get(id, 0.0)) - 1.0
		if left > 0.0:
			_crew_t[id] = left
			continue
		var speed := clampi(int(p.get("speed", 1)), 0, 2)
		var slip := _rng.randf() < float(BIZ_RULES.SPEED_SLIP[speed]) + (0.05 if str(p.get("temper", "")) == "sour" else 0.0)
		var did := false
		match str(p.get("role", "")):
			"tap":
				did = _crew_pour(key, p, "tap", slip, speed)
			"bar":
				did = _crew_pour(key, p, "bar", slip, speed)
			"wash":
				did = _crew_wash(key, slip)
			"cellar":
				did = _crew_cellar(key)
		# Two taps (gear): the tap's hand draws two at once.
		if did and str(p.get("role", "")) == "tap" and BUSINESS.has_gear(key, "tap2"):
			_crew_pour(key, p, "tap", slip, speed)
		var k := 0.7 if str(p.get("role", "")) in ["tap", "bar"] else 1.0
		# The quick coupler (gear): a keg changed in a moment.
		if str(p.get("role", "")) == "cellar" and BUSINESS.has_gear(key, "coupler"):
			k = 0.4
		_crew_t[id] = float(BIZ_RULES.SPEED_SEC[speed]) * k if did else 1.0


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
