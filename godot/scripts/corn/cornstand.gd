extends Node

## The corn stands while the game runs (core/systems/corn_rules.gd has the numbers;
## DESIGN.md §7b "The corn stand"), the pub's taproom.gd made for the stand. One node for
## the game, made with the businesses (business_runtime), a record per stand ("x:y" key):
##   pot      the cobs boiling: [{id, t (seconds in the water), slot}]
##   bowl     husked cobs waiting for the pot
##   served   what went over the counter for whom: ticket id -> {at, stars, amount}
## The orders are worked out each time from whoever the guest simulation has at the stand
## (corn_rules.tickets_for), so every machine has the same ones; only what was served is
## told. Co-op (up to four): every change is an op (`act`) applied at once and sent to
## everyone (Coop.send_place "corn"); the pot's cobs count their own seconds on every
## machine. The host does the hands' work and keeps the stand in the books for the save
## (actions.biz_keep "corn").

const RULES := preload("res://core/systems/corn_rules.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const BIZ_RULES := preload("res://core/systems/business_rules.gd")

## A record changed (key, what: "pot", "bowl", "served").
signal changed(key: String, what: String)
## A cob went over the counter (key, ticket id, its record).
signal handed(key: String, tid: String, rec: Dictionary)

var _sites: Dictionary = {}
var _acc := 0.0
var _save_due: Dictionary = {}
var _asked_snap := false
var _state_id := 0
var _made := 0
var _crew_t: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "CornStands"
	add_to_group("cornstands")
	# Coop.send_place("corn", ...) finds it here.
	add_to_group("places_corn")
	_rng.randomize()


## The game's stands node, made under the businesses (or the root) when first asked for.
static func of(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var c := tree.get_first_node_in_group("cornstands")
	if c != null:
		return c
	var parent: Node = tree.get_first_node_in_group("businesses")
	if parent == null:
		parent = tree.root
	c = load("res://scripts/corn/cornstand.gd").new()
	parent.add_child(c)
	return c


# ── the record ───────────────────────────────────────────────────────────────

func site(key: String) -> Dictionary:
	if not _sites.has(key):
		_sites[key] = _fresh(key)
	return _sites[key]


func _fresh(key: String) -> Dictionary:
	var books := BUSINESS.site(key)
	var saved: Dictionary = books.get("corn", {}) if books.get("corn", {}) is Dictionary else {}
	var pot: Array = []
	for c in saved.get("pot", []):
		if c is Dictionary:
			pot.append({"id": str(c.get("id", "")), "t": float(c.get("t", 0.0)), "slot": int(c.get("slot", 0))})
	return {"pot": pot, "bowl": int(saved.get("bowl", 0)), "served": {}}


func pot(key: String) -> Array:
	return site(key)["pot"]


func bowl(key: String) -> int:
	return int(site(key)["bowl"])


## Places in the pot (the bigger pot, gear: twice as many).
func places(key: String) -> int:
	return RULES.POT_PLACES_BIG if BUSINESS.has_gear(key, "pot") else RULES.POT_PLACES


## Leaves on a cob to pull (the husking table, gear: fewer).
func leaves(key: String) -> int:
	return RULES.LEAVES_TABLE if BUSINESS.has_gear(key, "table") else RULES.LEAVES


## A free place in the pot (-1 none).
func free_slot(key: String) -> int:
	var used := {}
	for c in pot(key):
		used[int(c["slot"])] = true
	for i in places(key):
		if not used.has(i):
			return i
	return -1


## A new cob's id, nobody else's (this machine's number and its count).
func new_id() -> String:
	_made += 1
	var me: int = multiplayer.get_unique_id() if multiplayer != null and multiplayer.has_multiplayer_peer() else 1
	return "%d-%d" % [me, _made]


# ── orders ───────────────────────────────────────────────────────────────────

static func now_min() -> int:
	if GuestManager == null:
		return 0
	return int(GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute))


## Open orders at `key`, oldest first: [{id, visit, member, kind (cob, tea, limo),
## guest_id, name, arch, salt, price, since, age}]; `only` "cob" or "drink" keeps those.
## What is off the books' menu is not ordered (the drinks), nor anything after last orders.
func tickets(key: String, only := "") -> Array:
	var out: Array = []
	var now := now_min()
	var served: Dictionary = site(key)["served"]
	var books := BUSINESS.site(key)
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		for t in RULES.tickets_for(visit, int(v.get("figures", 1)), int(v.get("arrive", now)), served, now):
			if only == "cob" and str(t["kind"]) != "cob":
				continue
			if only == "drink" and str(t["kind"]) == "cob":
				continue
			if str(t["kind"]) != "cob" and not BIZ_RULES.menu_on("corn", books, str(t["kind"])):
				continue
			if not BUSINESS.takes_orders_at(key, int(t["since"])):
				continue
			t["visit"] = visit
			t["guest_id"] = int(v["id"])
			t["name"] = str(v["name"])
			t["arch"] = str(v["archetype"])
			out.append(t)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["since"]) < int(b["since"]) or (int(a["since"]) == int(b["since"]) and str(a["id"]) < str(b["id"])))
	return out


# ── doing things: ops ────────────────────────────────────────────────────────

## Do `op` here and tell the others. ops:
##   husked [n]          cobs husked into the bowl (n < 0: taken back out)
##   in [id, slot]       a cob from the bowl into the pot
##   out [id]            a cob out of the pot (onto the board, or thrown away)
##   served [tid, rec]   a cob over the counter
func act(key: String, op: String, args: Array) -> void:
	_apply(key, op, args)
	if Coop.is_active() and Coop.has_method("send_place"):
		Coop.send_place("corn", key, op, args)


func _apply(key: String, op: String, args: Array) -> void:
	var s := site(key)
	match op:
		"husked":
			s["bowl"] = maxi(0, int(s["bowl"]) + int(args[0]))
			_save_due[key] = true
		"in":
			s["bowl"] = maxi(0, int(s["bowl"]) - 1)
			s["pot"].append({"id": str(args[0]), "t": 0.0, "slot": int(args[1])})
			_save_due[key] = true
		"out":
			var keep: Array = []
			for c in s["pot"]:
				if str(c["id"]) != str(args[0]):
					keep.append(c)
			s["pot"] = keep
			_save_due[key] = true
		"served":
			var rec: Dictionary = (args[1] as Dictionary).duplicate(true)
			s["served"][str(args[0])] = rec
			handed.emit(key, str(args[0]), rec)
		"snap":
			var got: Dictionary = args[0]
			s["bowl"] = int(got.get("bowl", s["bowl"]))
			s["pot"] = (got.get("pot", []) as Array).duplicate(true)
			for tid in (got.get("served", {}) as Dictionary):
				s["served"][tid] = got["served"][tid]
	changed.emit(key, op)


## From another machine (Coop.send_place "corn").
func coop_place(key: String, op: String, args: Array) -> void:
	if op == "hello":
		if Coop.is_host():
			for k in _sites:
				Coop.send_place("corn", str(k), "snap", [_snapshot(str(k))])
		return
	_apply(key, op, args)


func _snapshot(key: String) -> Dictionary:
	var s := site(key)
	return {"pot": s["pot"], "bowl": s["bowl"], "served": s["served"]}


## A cob goes over the counter for order `t`: judged (corn_rules.judge) into Papa's score,
## sold (the butter off the shelf, the money the camp's), the guest's mood and their
## review's line. Returns the verdict with its amount, tip, stars; {ok: false, notes} when
## they hand it back (nothing sold), {ok: false, why: "butter"} when the butter ran out.
func serve(key: String, t: Dictionary, cook: float, butter: float, salt: int, by_hand := false) -> Dictionary:
	var v: Dictionary = RULES.judge(cook, butter, salt, int(t["salt"]), int(t["age"]))
	if not bool(v["ok"]):
		ORDERS.mood(int(t["guest_id"]), -1.0, "The corn at the camp stand was awful.")
		return v
	var pts := BIZ_RULES.score(float(v["speed"]), float(v["build"]), float(v["cook"]))
	var r := BIZ_RULES.reward(pts, int(t["price"]))
	var amount := int(round((int(t["price"]) + int(r["tip"])) * BUSINESS.price_k(key)))
	var needs := {"butter": 1} if butter > 0.05 else {}
	if not BUSINESS.sell(key, needs, amount):
		return {"ok": false, "why": "butter", "notes": []}
	v["score"] = pts
	v["tip"] = int(r["tip"])
	v["stars"] = int(r["stars"])
	v["amount"] = amount
	ORDERS.note_served({"id": int(t["guest_id"]), "visit": str(t["visit"])})
	var thought := _thought(v)
	ORDERS.mood(int(t["guest_id"]), float(r["mood"]) + (BUSINESS.hand_mood(key, "counter") if by_hand else 0.0), thought)
	ORDERS.note_meal(int(t["guest_id"]), thought, pts)
	act(key, "served", [str(t["id"]), {"at": now_min(), "stars": int(v["stars"]), "amount": amount}])
	if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_score"):
		CoreRoot.actions.biz_score(key, {"score": pts, "tip": int(v["tip"]), "what": "Corn", "who": str(t.get("name", "")), "hand": by_hand})
	return v


## A drink goes over the counter for slip `t`: `made` (tea, limo), how full, the bag tied;
## judged (corn_rules.judge_drink) and sold like a cob (its good off the shelf). The
## verdict as serve's; {ok: false, why: "empty"} when the barrel or the bottles ran dry.
func serve_drink(key: String, t: Dictionary, made: String, fill: float, tied: bool, by_hand := false) -> Dictionary:
	var want := str(t.get("kind", "tea"))
	var v: Dictionary = RULES.judge_drink(made, fill, tied, want, int(t["age"]))
	if not bool(v["ok"]):
		ORDERS.mood(int(t["guest_id"]), -0.5, "")
		return v
	var pts := BIZ_RULES.score(float(v["speed"]), float(v["build"]))
	var r := BIZ_RULES.reward(pts, int(t["price"]))
	var amount := int(round((int(t["price"]) + int(r["tip"])) * BUSINESS.price_k(key)))
	var good := str(RULES.DRINKS.get(made, {}).get("good", made))
	if not BUSINESS.sell(key, {good: 1}, amount):
		return {"ok": false, "why": "empty", "notes": []}
	v["score"] = pts
	v["tip"] = int(r["tip"])
	v["stars"] = int(r["stars"])
	v["amount"] = amount
	ORDERS.note_served({"id": int(t["guest_id"]), "visit": str(t["visit"])})
	ORDERS.mood(int(t["guest_id"]), float(r["mood"]) * 0.5 + (BUSINESS.hand_mood(key, "drinks") if by_hand else 0.0), "")
	act(key, "served", [str(t["id"]), {"at": now_min(), "stars": int(v["stars"]), "amount": amount}])
	if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_score"):
		CoreRoot.actions.biz_score(key, {"score": pts, "tip": int(v["tip"]), "what": str(RULES.DRINKS[made]["label"]), "who": str(t.get("name", "")), "hand": by_hand})
	return v


func _thought(v: Dictionary) -> String:
	if int(v.get("stars", 0)) >= 3:
		return "The corn at the camp stand is the best thing here."
	if float(v.get("cook", 1.0)) < 0.5:
		return "The corn at the stand was hard, or gone to mush."
	if float(v.get("speed", 1.0)) < 0.3:
		return "Waited forever for a cob of corn."
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
		_save_due.clear()
		_asked_snap = false
	# The water boils on every machine alike.
	for key in _sites:
		for c in _sites[key]["pot"]:
			c["t"] = float(c["t"]) + delta
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	if Coop.is_client() and not _asked_snap and Coop.has_method("send_place"):
		_asked_snap = true
		Coop.send_place("corn", "", "hello", [])
	if not Coop.sim_here():
		return
	var holds := {}
	for key in _stand_sites():
		var crew: Array = BUSINESS.crew_now(key)
		if not crew.is_empty():
			_crew_work(key, crew)
		if _save_due.has(key):
			_save_due.erase(key)
			_save(key)
		# Who has ordered waits for it to the end of their patience, past their visit's
		# time and past the closing hour (the brief of 21. 10.: "they do not walk off
		# under your hands").
		for t in tickets(key):
			var gid := int(t["guest_id"])
			holds[gid] = maxi(int(holds.get(gid, -1)), int(t["since"]) + RULES.raw_gone())
	ORDERS.set_holds("corn", holds)


func _stand_sites() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	for key in sites:
		if str((sites[key] as Dictionary).get("kind", "")) == "corn":
			out.append(str(key))
	return out


## The pot and the bowl into the books (they are saved with the camp).
func _save(key: String) -> void:
	if CoreRoot == null or CoreRoot.actions == null or not CoreRoot.actions.has_method("biz_keep"):
		return
	var s := site(key)
	CoreRoot.actions.biz_keep(key, "corn", {"pot": s["pot"], "bowl": int(s["bowl"])})


## The hands at the stand (DESIGN.md §7b, the hands), one piece of work at a time as their
## speed allows; now and then one goes wrong:
##   husk     takes a cob from the crate and husks it into the bowl (a cob dropped now
##            and then)
##   counter  puts husked cobs in the pot, takes a done one out, butters and salts it to
##            the order (the salt off now and then) and hands it over; a soft one they
##            throw away
## The hands work beside you as another warden would (the user 25. 10.: "let me work
## together with him like another player: he takes stations, I can go anywhere and come
## first, he is always where he is needed and where I am not"): each to their own job's
## station unless a warden is at it (you come first), then to the free station that most
## wants doing (the bowl running low, cobs waiting at the counter, drinks ordered), never
## two to one; with nothing wanted, aside. Worked out the same way on every machine (the
## wardens' stations are in their room states, the orders and the bowl are the stand's
## own records), so the figures stand where the work is done.
const STATIONS := ["husk", "counter", "drinks"]


## slug -> the station that hand works now ("" aside), at `key`.
func crew_places(key: String) -> Dictionary:
	var out := {}
	var crew: Array = BUSINESS.crew_now(key)
	if crew.is_empty():
		return out
	var busy := warden_stations(key)
	var taken := {}
	var wanting: Array = []
	for p in crew:
		var own := str(p.get("role", ""))
		if STATIONS.has(own) and not busy.has(own) and not taken.has(own):
			taken[own] = true
			out[str(p.get("slug", ""))] = own
		else:
			wanting.append(p)
	for p in wanting:
		var best := ""
		var best_need := 0.0
		for st in STATIONS:
			if busy.has(st) or taken.has(st):
				continue
			var need := station_need(key, st)
			if need > best_need:
				best_need = need
				best = st
		if best != "":
			taken[best] = true
		out[str(p.get("slug", ""))] = best
	return out


## The stations wardens are at here: this machine's open one and the others' rooms.
func warden_stations(key: String) -> Array:
	var out: Array = []
	var sv = get_tree().get_first_node_in_group("corn_stand_view") if is_inside_tree() else null
	if sv != null and is_instance_valid(sv) and str(sv.get("building_key")) == key and sv.has_method("_station_open"):
		var open := str(sv.call("_station_open"))
		if open != "":
			out.append(open)
	if Coop.is_active():
		for pid in Coop.others():
			var room: Dictionary = Coop.state_of(pid).get("room", {})
			if str(room.get("k", "")) == key and str(room.get("t", "")) == "corn":
				out.append(str(room.get("w", "")))
	return out


## How much a station wants doing now (0 nothing).
func station_need(key: String, st: String) -> float:
	match st:
		"husk":
			if BUSINESS.stock_of(key, "cobs") <= 0:
				return 0.0
			return maxf(0.0, float(8 - bowl(key)) / 8.0)
		"counter":
			var cobs := tickets(key, "cob").size()
			return 0.0 if cobs == 0 else 0.5 + 0.25 * float(cobs) + (0.5 if not pot(key).is_empty() else 0.0)
		"drinks":
			return 0.4 * float(tickets(key, "drink").size())
	return 0.0


func _crew_work(key: String, crew: Array) -> void:
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
			"husk":
				did = _crew_husk(key, slip)
			"counter":
				did = _crew_counter(key, slip)
				# Nothing for the pot: a drink meanwhile, unless somebody is on the drinks.
				if not did and not places.values().has("drinks") and not warden_stations(key).has("drinks"):
					did = _crew_drink(key, slip)
			"drinks":
				did = _crew_drink(key, slip)
		var k := 1.0
		if at == "husk" and BUSINESS.has_gear(key, "table"):
			k = 0.6
		_crew_t[id] = float(BIZ_RULES.SPEED_SEC[speed]) * k if did else 1.0


func _has_role(crew: Array, role: String) -> bool:
	for p in crew:
		if str(p.get("role", "")) == role:
			return true
	return false


## The hand at the drinks pours the oldest drink slip (a little short or over when it
## slips).
func _crew_drink(key: String, slip: bool) -> bool:
	var open := tickets(key, "drink")
	if open.is_empty():
		return false
	var t: Dictionary = open[0]
	var fill := _rng.randf_range(0.84, 0.95)
	if slip:
		fill = _rng.randf_range(0.6, 1.05)
	var v := serve_drink(key, t, str(t["kind"]), fill, true, true)
	return bool(v.get("ok", false)) or str(v.get("why", "")) != "empty"


func _crew_husk(key: String, slip: bool) -> bool:
	if bowl(key) >= 8 or BUSINESS.stock_of(key, "cobs") <= 0:
		return false
	if CoreRoot == null or CoreRoot.actions == null or not CoreRoot.actions.biz_take(key, {"cobs": 1}):
		return false
	if slip and _rng.randf() < 0.3:
		# Dropped in the dirt.
		return true
	act(key, "husked", [1])
	return true


func _crew_counter(key: String, slip: bool) -> bool:
	var open := tickets(key, "cob")
	# A done one out to whoever waits longest; a soft one thrown away.
	for c in pot(key):
		var stage := RULES.stage(float(c["t"]))
		if stage == 2:
			act(key, "out", [str(c["id"])])
			return true
		if stage == 1 and not open.is_empty():
			act(key, "out", [str(c["id"])])
			var t: Dictionary = open[0]
			var salt := int(t["salt"])
			if slip:
				salt = clampi(salt + (1 if _rng.randf() < 0.5 else -1), 0, 3)
			var butter := 0.9 if BUSINESS.stock_of(key, "butter") != 0 else 0.0
			serve(key, t, RULES.cook_of(float(c["t"])), butter, salt, true)
			return true
	# Into the pot, as many as are wanted (and one ahead).
	var in_pot := pot(key).size()
	if bowl(key) > 0 and free_slot(key) >= 0 and in_pot < open.size() + 1:
		act(key, "in", [new_id(), free_slot(key)])
		return true
	return false


# ── debug (tools/stand_check.gd, tools/stand_coop.gd) ────────────────────────

## Every cob in the pot `t` seconds in the water.
func debug_boil(key: String, t: float) -> void:
	for c in pot(key):
		c["t"] = t
