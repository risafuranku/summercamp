extends Node

## The bistros' kitchens while the game runs (core/systems/bistro_rules.gd has the
## numbers; DESIGN.md §7b the idea). One node for the game (made by business_runtime),
## a record per bistro ("x:y" key) of what is in it right now:
##   prep    what is ready on the trays and racks: raw chips and breaded slices from the
##           cellar, fried cheese and chips off the stove, dumpling slices off the board
##   pan     the frying pan's places: a breaded slice each {bad, down, t: [side a, side b]}
##   basket  the chip basket {st: up / down, t: seconds down, n: portions in it}
##   pot     the goulash pot {level, heat 0..1, catch 0..1}
##   loaf    the dumpling loaf on the board {left: slices still on it}
##   plates  {clean, dirty}
##   grill   the grill's places on the kitchen island: a sausage each {down, t: [a, b]}
##   soup    the soup of the day's pot at the bufet {level}
##   hatch   plates rung out at the pass, waiting on the floor's counter to be taken to
##           their table (the brief of 21. 10.: "the kitchen cooks and plates, the floor
##           serves"): [{tid, parts, cook}]
##   served  tickets served: id -> {dish, at (game minute), parts}
## The prepared goods bought dearer in the books (cut chips, breaded cheese) go onto the
## trays by themselves, as if the cellar had done them (the cellar is optional).
## The stove and the pot go on cooking whether anybody is at them or not: a slice left in
## the pan burns, the pot left unstirred catches on the bottom (the room's marks say so).
##
## Tickets are not kept: they are worked out each time from whoever the guest simulation
## has sitting in the bistro (bistro_rules.tickets_for), so every machine in co-op has
## the same ones; only what was served is told.
##
## Co-op (up to four): everything done here is an op (`act`) applied at once and sent to
## everyone (Coop.send_kitchen); counts go as changes, a pan place or the pot as its whole
## new state, so the machines agree however the ops cross. The host also holds the guests
## in their seats while their food is coming (guest_life.visit_holds), sends back the
## plates they ate from, and keeps the trays' counts in the books for the save
## (actions.biz_kitchen). A machine that joins asks the host for the kitchens as they are.

const RULES := preload("res://core/systems/bistro_rules.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const BIZ_RULES := preload("res://core/systems/business_rules.gd")
const CREW_PLACES := preload("res://scripts/business/crew_places.gd")

## A station's state changed (key, what: "prep", "pan", "pot", "served"...).
signal changed(key: String, what: String)
## A plate went out (key, ticket id, judgement): the dining room shows it land.
signal plate_out(key: String, tid: String, verdict: Dictionary)

var _sites: Dictionary = {}
var _acc := 0.0
var _save_due: Dictionary = {}
## Host: visits whose plates went back to the sink already (ticket id -> true).
var _cleared: Dictionary = {}
## The joining machine asked the host for the kitchens.
var _asked_snap := false
## Whose camp the kitchens are of (CoreRoot's state object).
var _state_id := 0
## Smoke from the pot that caught (key -> seconds left), for the room.
var burnt_flash: Dictionary = {}


func _ready() -> void:
	name = "Kitchens"
	add_to_group("kitchens")
	if not EventBus.guest_state_changed.is_connected(_on_guest_state):
		EventBus.guest_state_changed.connect(_on_guest_state)


static func of(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("kitchens") if tree != null else null


# ── the record ───────────────────────────────────────────────────────────────

func site(key: String) -> Dictionary:
	if not _sites.has(key):
		_sites[key] = _fresh(key)
	return _sites[key]


func has_site(key: String) -> bool:
	return _sites.has(key)


func _fresh(key: String) -> Dictionary:
	var saved: Dictionary = BUSINESS.site(key).get("kitchen", {}) if BUSINESS.site(key).get("kitchen", {}) is Dictionary else {}
	var prep := {"chips_raw": 0, "cheese_raw": 0, "cheese_bad": 0, "cheese": 0, "fries": 0, "dumpling": 0, "sausage": 0}
	for k in (saved.get("prep", {}) as Dictionary):
		if prep.has(k):
			prep[k] = int(saved["prep"][k])
	var pans: Array = []
	for i in pan_slots(key):
		pans.append({})
	var grill: Array = []
	for i in RULES.GRILL_SLOTS:
		grill.append({})
	return {
		"prep": prep,
		# How good each thing on the trays is (0..1), oldest first, as they were made.
		"q": {},
		"pan": pans,
		"basket": {"st": "up", "t": 0.0, "n": 0},
		"pot": {"level": int(saved.get("pot", 6)), "heat": 1.0, "catch": 0.0},
		"loaf": {"left": int(saved.get("loaf", 0))},
		"plates": {"clean": int(saved.get("clean", RULES.PLATES)), "dirty": int(saved.get("dirty", 0))},
		"grill": grill,
		"soup": {"level": int(saved.get("soup", 8))},
		"hatch": [],
		# The dishwasher (gear): plates in it and the seconds left.
		"washer": {"n": int(saved.get("washer_n", 0)), "t": float(saved.get("washer_t", 0.0))},
		"served": {},
		# PROTOTYP 540 in the cellar (bistro_rules proto_*): the night a sack lay in front
		# of it, the night it was fed, the day its tray had meat in it, the last morning the
		# camp woke without somebody (-1 never).
		"proto": {"sack": int(saved.get("proto_sack", -1)), "fed": int(saved.get("proto_fed", -1)),
			"tray": int(saved.get("proto_tray", -1)), "taken": int(saved.get("proto_taken", -1))},
	}


# ── the gear (business_rules GEAR "rest") ────────────────────────────────────

static func gear(key: String, id: String) -> bool:
	return BUSINESS.has_gear(key, id)


## Places in the pan: a fourth with the heavy pan.
static func pan_slots(key: String) -> int:
	return RULES.PAN_SLOTS + (1 if gear(key, "pan") else 0)


## Portions of chips a basket takes: two baskets' worth with the second one.
static func basket_portions(key: String) -> int:
	return RULES.BASKET_PORTIONS * (2 if gear(key, "basket2") else 1)


## What the pot holds: twenty with the big pot.
static func pot_cap(key: String) -> int:
	return 20 if gear(key, "pot") else RULES.POT_CAP


## Seconds of the dishwasher's run.
const WASHER_SEC := 25.0


## The gear bought since the kitchen was set up: the pan's fourth place.
func _fit_gear(key: String) -> void:
	var pans: Array = site(key)["pan"]
	while pans.size() < pan_slots(key):
		pans.append({})


func prep(key: String, item: String) -> int:
	return int((site(key)["prep"] as Dictionary).get(item, 0))


func plates(key: String) -> Dictionary:
	return site(key)["plates"]


# ── tickets ──────────────────────────────────────────────────────────────────

## The game's clock in minutes (GuestManager's), for the tickets' ages.
static func now_min() -> int:
	if GuestManager == null:
		return 0
	return int(GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute))


## The ticket clock (gear): the guests see their order is up and wait longer (their
## tickets age three quarters as fast).
static func patience_k(key: String) -> float:
	return 0.75 if gear(key, "clock") else 1.0


## Open tickets at `key`, oldest first: [{id, visit, member, guest_id, name, arch, dish,
## parts, price, since, age}]. Nobody served by a hand; not served yet; up once they
## have read the menu. `where`: "pass" (the plates), "bufet" (the soup, the bottles),
## "" all of them.
## Open tickets at `key`, oldest first; `where`: "pass" (the plates still to be made),
## "bufet" (the soup of the day), "floor" (the plates on the hatch and the bottles),
## "" all. What is off the books' menu is never ordered: they pick the next dish they like
## that is on (the bottles: no bottle). Nothing after last orders.
func tickets(key: String, where := "") -> Array:
	var out: Array = []
	var now := now_min()
	var served: Dictionary = site(key)["served"]
	var books := BUSINESS.site(key)
	var hatched := hatched_ids(key)
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		var figures := int(v.get("figures", 1))
		# A hand behind the counter served the lot (business_runtime._hand_serves).
		if int(ORDERS._served.get(visit, 0)) >= figures and not _any_served(served, visit):
			continue
		var since := int(v.get("arrive", now)) + RULES.ORDER_DELAY
		if now < since:
			continue
		for t in RULES.tickets_for(visit, str(v["archetype"]), figures):
			if served.has(str(t["id"])):
				continue
			if not BIZ_RULES.menu_on("rest", books, str(t["dish"])):
				if RULES.DRINKS.has(str(t["dish"])):
					continue
				t = RULES.instead(t, func(d: String) -> bool: return BIZ_RULES.menu_on("rest", books, d))
			if not BUSINESS.takes_orders_at(key, since + int(t["member"])):
				continue
			var dish := str(t["dish"])
			var on_hatch := hatched.has(str(t["id"]))
			match where:
				"pass":
					if RULES.at_bufet(dish) or on_hatch:
						continue
				"bufet":
					if dish != "soup":
						continue
				"floor":
					if not (RULES.DRINKS.has(dish) or on_hatch):
						continue
			t["hatched"] = on_hatch
			t["visit"] = visit
			t["guest_id"] = int(v["id"])
			t["name"] = str(v["name"])
			t["arch"] = str(v["archetype"])
			t["since"] = since + int(t["member"])
			t["age"] = int(maxi(0, now - int(t["since"])) * patience_k(key))
			out.append(t)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["since"]) < int(b["since"]) or (int(a["since"]) == int(b["since"]) and str(a["id"]) < str(b["id"])))
	return out


func _any_served(served: Dictionary, visit: String) -> bool:
	for tid in served:
		if str(tid).begins_with(visit + "#"):
			return true
	return false


## The plate in front of `visit`'s person `member` ({} none yet): served here, or by a
## hand (what they would have ordered).
func plate_for(key: String, visit: String, member: int, figures: int, archetype: String) -> Dictionary:
	var served: Dictionary = site(key)["served"]
	var tid := "%s#%d" % [visit, member]
	if served.has(tid):
		return served[tid]
	if int(ORDERS._served.get(visit, 0)) >= figures and not _any_served(served, visit):
		for t in RULES.tickets_for(visit, archetype, figures):
			if int(t["member"]) == member:
				return {"dish": str(t["dish"]), "parts": t["parts"], "hand": true}
	return {}


## The open ticket of `visit`'s person `member` ({} none): the bubble over their head.
func ticket_of(key: String, visit: String, member: int) -> Dictionary:
	for t in tickets(key):
		if str(t["visit"]) == visit and int(t["member"]) == member:
			return t
	return {}


# ── doing things: ops ────────────────────────────────────────────────────────

## Do `op` here and tell the others. ops:
##   prep [item, delta]         a tray or rack count
##   pan [slot, state]          a place in the pan ({} empty)
##   basket [state]
##   pot [state]
##   loaf [state]
##   plates [clean delta, dirty delta]
##   served [ticket id, record]
##   proto [fields]                    the cellar's machine (sack, fed, tray, taken)
##   grill [slot, state]        a place on the grill ({} empty)
##   soup [state]               the bufet's soup pot
func act(key: String, op: String, args: Array) -> void:
	_apply(key, op, args)
	if Coop.is_active():
		Coop.send_kitchen(key, op, args)


func _apply(key: String, op: String, args: Array) -> void:
	var s := site(key)
	match op:
		"prep":
			var item := str(args[0])
			var p: Dictionary = s["prep"]
			var before := int(p.get(item, 0))
			p[item] = maxi(0, before + int(args[1]))
			# The things' qualities: new ones at the back, used ones off the front.
			var ql: Array = (s["q"] as Dictionary).get(item, [])
			while ql.size() < before:
				ql.push_front(1.0)
			var dq := int(args[1])
			if dq > 0:
				var given: Array = args[2] if args.size() > 2 and args[2] is Array else []
				for i in dq:
					ql.append(float(given[i]) if i < given.size() else 1.0)
			elif dq < 0:
				for i in mini(-dq, ql.size()):
					ql.pop_front()
			while ql.size() > int(p[item]):
				ql.pop_front()
			s["q"][item] = ql
			_note_save(key)
		"pan":
			var slot := int(args[0])
			if slot >= 0 and slot < (s["pan"] as Array).size():
				s["pan"][slot] = (args[1] as Dictionary).duplicate(true)
		"basket":
			s["basket"] = (args[0] as Dictionary).duplicate(true)
		"grill":
			var gslot := int(args[0])
			if gslot >= 0 and gslot < (s["grill"] as Array).size():
				s["grill"][gslot] = (args[1] as Dictionary).duplicate(true)
		"soup":
			s["soup"] = (args[0] as Dictionary).duplicate(true)
			_note_save(key)
		"pot":
			s["pot"] = (args[0] as Dictionary).duplicate(true)
			_note_save(key)
		"loaf":
			s["loaf"] = (args[0] as Dictionary).duplicate(true)
			_note_save(key)
		"plates":
			var pl: Dictionary = s["plates"]
			pl["clean"] = maxi(0, int(pl["clean"]) + int(args[0]))
			pl["dirty"] = maxi(0, int(pl["dirty"]) + int(args[1]))
			_note_save(key)
		"washer":
			s["washer"] = (args[0] as Dictionary).duplicate(true)
			_note_save(key)
		"proto":
			(s["proto"] as Dictionary).merge(args[0] as Dictionary, true)
			_note_save(key)
		"served":
			var rec: Dictionary = (args[1] as Dictionary).duplicate(true)
			s["served"][str(args[0])] = rec
			_unhatch(s, str(args[0]))
			# Out of the hatch, on whichever machine served it.
			plate_out.emit(key, str(args[0]), rec)
		"hatch":
			# A plate rung out at the pass onto the floor's counter.
			_unhatch(s, str(args[0]))
			(s["hatch"] as Array).append({"tid": str(args[0]), "parts": (args[1] as Dictionary).duplicate(), "cook": float(args[2])})
		"unhatch":
			_unhatch(s, str(args[0]))
		"snap":
			var got: Dictionary = args[0]
			for k in ["prep", "q", "pan", "basket", "pot", "loaf", "plates", "washer", "proto", "grill", "soup", "hatch"]:
				if got.has(k):
					s[k] = (got[k] as Dictionary).duplicate(true) if got[k] is Dictionary else (got[k] as Array).duplicate(true)
			for tid in (got.get("served", {}) as Dictionary):
				s["served"][tid] = got["served"][tid]
	changed.emit(key, op)


static func _unhatch(s: Dictionary, tid: String) -> void:
	var keep: Array = []
	for h in s.get("hatch", []):
		if str(h["tid"]) != tid:
			keep.append(h)
	s["hatch"] = keep


## The plates waiting on the hatch: [{tid, parts, cook}], oldest first.
func hatch(key: String) -> Array:
	return site(key).get("hatch", [])


func hatched_ids(key: String) -> Dictionary:
	var out := {}
	for h in hatch(key):
		out[str(h["tid"])] = h
	return out


## A plate off the pass onto the hatch: right for the ticket (the dish and its counts
## judged now, the wait when it reaches the table) or sent back to the cook.
## Returns the judgement ({ok: false, notes} when it is not what they ordered).
func to_hatch(key: String, t: Dictionary, parts: Dictionary, cook := -1.0) -> Dictionary:
	var verdict: Dictionary = RULES.judge(parts, t["parts"], int(t.get("age", 0)))
	if not bool(verdict["ok"]):
		return verdict
	act(key, "hatch", [str(t["id"]), parts, cook])
	return verdict


## The plate of ticket `t` off the hatch to its table: judged (the build, the cooking, the
## wait till now) into the money, the tip, the stars (serve).
func serve_hatch(key: String, t: Dictionary, hand := "") -> Dictionary:
	var h: Dictionary = hatched_ids(key).get(str(t["id"]), {})
	if h.is_empty():
		return {"ok": false, "why": "none"}
	var v := serve(key, t, h["parts"], float(h["cook"]), hand)
	if bool(v.get("ok", false)):
		act(key, "unhatch", [str(t["id"])])
	return v


## From another machine (Coop.send_kitchen).
func coop_kitchen(key: String, op: String, args: Array) -> void:
	if op == "hello":
		# Somebody new: the kitchens as they are here (the host's are the ones).
		if Coop.is_host():
			for k in _sites:
				Coop.send_kitchen(str(k), "snap", [_snapshot(str(k))])
		return
	_apply(key, op, args)


func _snapshot(key: String) -> Dictionary:
	var s := site(key)
	return {"prep": s["prep"], "q": s["q"], "pan": s["pan"], "basket": s["basket"], "pot": s["pot"], "loaf": s["loaf"], "plates": s["plates"], "washer": s["washer"], "served": s["served"], "proto": s["proto"], "grill": s["grill"], "soup": s["soup"], "hatch": s.get("hatch", [])}


## Takes `n` of `item` off a tray; false when there is not that much.
func take(key: String, item: String, n := 1) -> bool:
	if prep(key, item) < n:
		return false
	act(key, "prep", [item, -n])
	return true


## Takes `n` of `item` off a tray and says how good they were ([] when there is not that
## much).
func take_q(key: String, item: String, n := 1) -> Array:
	if prep(key, item) < n:
		return []
	var ql: Array = (site(key)["q"] as Dictionary).get(item, [])
	var out: Array = []
	for i in n:
		out.append(float(ql[i]) if i < ql.size() else 1.0)
	act(key, "prep", [item, -n])
	return out


## How good a fried slice is off the pan: each side golden through the window, best in the
## middle of it (half at its edges, nothing raw or black), a badly breaded one poorer.
static func slice_quality(slot: Dictionary) -> float:
	var bad := bool(slot.get("bad", false))
	var burnt := RULES.CHEESE_BURNT_BAD if bad else RULES.CHEESE_BURNT
	var q := 0.0
	for t in slot.get("t", [0.0, 0.0]):
		q += _window_q(float(t), RULES.CHEESE_GOLD, burnt)
	q *= 0.5
	return q * (0.75 if bad else 1.0)


## A sausage off the grill: both sides brown, best in the middle of the window.
static func sausage_quality(slot: Dictionary) -> float:
	var q := 0.0
	for t in slot.get("t", [0.0, 0.0]):
		q += _window_q(float(t), RULES.GRILL_GOLD, RULES.GRILL_BURNT)
	return q * 0.5


## Chips out of the oil after `t` seconds.
static func fries_quality(t: float) -> float:
	return _window_q(t, RULES.FRIES_GOLD, RULES.FRIES_BURNT)


static func _window_q(t: float, gold: float, burnt: float) -> float:
	if t < gold or t >= burnt:
		return 0.0
	var mid := (gold + burnt) * 0.5
	return clampf(1.0 - absf(t - mid) / ((burnt - gold) * 0.5) * 0.5, 0.0, 1.0)


## The goulash as it is ladled: hot (back on the boil) and not catching on the bottom.
static func goulash_quality(pot: Dictionary) -> float:
	var q := 1.0 if float(pot.get("heat", 1.0)) >= 0.9 else 0.8
	return clampf(q - float(pot.get("catch", 0.0)) * 0.45, 0.0, 1.0)


## Room on a tray or rack for `n` more of `item`.
func room_for(key: String, item: String, n := 1) -> bool:
	return prep(key, item) + n <= int(RULES.PREP_CAP.get(item, 99))


## The plate goes out through the hatch for ticket `t`: judged Papa's way (the wait, the
## build against the ticket, the cooking: `cook` 0..1 the food's own quality, -1 none),
## sold (the money is the camp's, the books count it and the shift's tally), the
## guest's mood and a line for their review, the plate off the stack. `hand`: a hand
## served it (their name). Returns the judgement ({ok: false}: not theirs, it comes back).
func serve(key: String, t: Dictionary, parts: Dictionary, cook := -1.0, hand := "") -> Dictionary:
	var verdict: Dictionary = RULES.judge(parts, t["parts"], int(t.get("age", 0)))
	if not bool(verdict["ok"]):
		return verdict
	var pts := BIZ_RULES.score(float(verdict["speed"]), float(verdict["accuracy"]), cook)
	var r := BIZ_RULES.reward(pts, int(t["price"]))
	verdict["score"] = pts
	verdict["cook"] = cook
	verdict["stars"] = int(r["stars"])
	verdict["tip"] = int(r["tip"])
	verdict["mood"] = float(r["mood"])
	var amount := int(round((int(t["price"]) + int(verdict["tip"])) * BUSINESS.price_k(key)))
	verdict["amount"] = amount
	# A bottle off the shelf; the rest came off the shelves as it was made.
	var needs := {}
	if RULES.DRINKS.has(str(t["dish"])):
		needs[str(RULES.DRINKS[str(t["dish"])]["good"])] = 1
	if not BUSINESS.sell(key, needs, amount):
		return {"ok": false, "why": "dry", "accuracy": 0.0, "speed": 0.0, "tip": 0, "stars": 0, "mood": 0.0}
	var v := {"id": int(t["guest_id"]), "visit": str(t["visit"])}
	ORDERS.note_served(v)
	var line := _review_line(str(t["dish"]), verdict)
	var role := "bufet" if RULES.at_bufet(str(t["dish"])) else "pass"
	ORDERS.mood(int(t["guest_id"]), float(verdict["mood"]) + (BUSINESS.hand_mood(key, role) if hand != "" else 0.0), line)
	ORDERS.note_meal(int(t["guest_id"]), line, pts)
	act(key, "served", [str(t["id"]), {"dish": str(t["dish"]), "at": now_min(), "parts": parts, "stars": int(verdict["stars"]), "amount": amount, "score": pts}])
	if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_score"):
		CoreRoot.actions.biz_score(key, {"score": pts, "tip": int(verdict["tip"]), "what": RULES.dish_label(str(t["dish"])), "who": str(t.get("name", "")), "hand": hand != ""})
	return verdict


## What the guest says of it (their thought, and a line their review can use).
func _review_line(dish: String, verdict: Dictionary) -> String:
	var cook := float(verdict.get("cook", -1.0))
	if float(verdict["speed"]) <= 0.0:
		return "Waited forever for my food at the bistro."
	if float(verdict["accuracy"]) < 0.7:
		return "The bistro got my order wrong."
	if cook >= 0.0 and cook < 0.45:
		match dish:
			"goulash":
				return "The goulash was burnt at the bottom."
			"smazak":
				return "The fried cheese was greasy and half raw."
			"sausage":
				return "The sausage at the bistro was black on one side and raw on the other."
			"soup":
				return "The soup of the day was lukewarm."
			_:
				return "The chips were pale and limp."
	if int(verdict.get("score", 0)) >= 92:
		match dish:
			"goulash":
				return "The goulash was like my grandmother's."
			"smazak":
				return "The fried cheese was perfect."
			"sausage":
				return "A proper klobasa off the grill, with mustard and bread."
			"soup":
				return "The soup of the day was like at a wedding."
			"kofola", "malinovka":
				return ""
			_:
				return "Proper chips at the bistro. Golden."
	if int(verdict.get("stars", 0)) >= 3:
		return "The bistro is quick and the food is hot."
	return ""


# ── time ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# Another camp (a new game, a load, a co-op camp arriving): its own kitchens.
	var st = CoreRoot.get_state() if CoreRoot != null else null
	# The state object may stay the same from camp to camp: the books' stamp does not
	# (actions._biz).
	var sid: int = (st.get_instance_id() + int((st.biz as Dictionary).get("stamp", 0))) if st != null and st.biz is Dictionary else 0
	if sid != _state_id:
		_state_id = sid
		_sites.clear()
		_cleared.clear()
		_save_due.clear()
		_asked_snap = false
	for key in _sites:
		_cook(str(key), delta)
	for k in burnt_flash.keys():
		burnt_flash[k] = float(burnt_flash[k]) - delta
		if float(burnt_flash[k]) <= 0.0:
			burnt_flash.erase(k)
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	if Coop.is_client() and not _asked_snap:
		_asked_snap = true
		Coop.send_kitchen("", "hello", [])
	if not Coop.sim_here():
		return
	_host_second()


## The stove and the pot, every frame, on every machine alike.
func _cook(key: String, delta: float) -> void:
	var s: Dictionary = _sites[key]
	# The heavy pan fries slower and more evenly: the golden lasts longer.
	var pan_dt := delta * (0.8 if gear(key, "pan") else 1.0)
	for slot in s["pan"]:
		if (slot as Dictionary).is_empty():
			continue
		var d := int(slot["down"])
		slot["t"][d] = float(slot["t"][d]) + pan_dt
	var b: Dictionary = s["basket"]
	if str(b["st"]) == "down":
		b["t"] = float(b["t"]) + delta
	for gs in s["grill"]:
		if (gs as Dictionary).is_empty():
			continue
		var gd := int(gs["down"])
		gs["t"][gd] = float(gs["t"][gd]) + delta
	var pot: Dictionary = s["pot"]
	if int(pot["level"]) > 0:
		pot["heat"] = minf(1.0, float(pot["heat"]) + delta / RULES.POT_HEAT_SEC)
		pot["catch"] = float(pot["catch"]) + delta / (RULES.POT_CATCH_SEC * (1.5 if gear(key, "pot") else 1.0))
		if float(pot["catch"]) >= 1.0:
			# Caught on the bottom: the burnt layer goes in the bin.
			pot["catch"] = 0.0
			pot["level"] = maxi(0, int(pot["level"]) - RULES.POT_BURN_LOSS)
			burnt_flash[key] = 3.0
			changed.emit(key, "pot")
	else:
		pot["catch"] = 0.0
	# Fried food going cold on the shelf (not under the heat lamp): a tenth of its
	# quality every half minute, never below half.
	if not gear(key, "lamp"):
		for item in ["cheese", "fries"]:
			var ql: Array = (s["q"] as Dictionary).get(item, [])
			for i in ql.size():
				ql[i] = maxf(0.5, float(ql[i]) - delta / 300.0)
	var w: Dictionary = s["washer"]
	if int(w.get("n", 0)) > 0:
		w["t"] = maxf(0.0, float(w["t"]) - delta)


## Host, once a second: the guests kept in their seats while their food is coming and
## while they eat; the plates they finished with to the sink; the save; the hand's work.
func _host_second() -> void:
	var now := now_min()
	var holds: Dictionary = {}
	for key in _rest_sites():
		_fit_gear(key)
		var s := site(key)
		var served: Dictionary = s["served"]
		var w: Dictionary = s["washer"]
		if int(w.get("n", 0)) > 0 and float(w.get("t", 0.0)) <= 0.0:
			# The dishwasher's run is over: the plates out clean.
			act(key, "plates", [int(w["n"]), 0])
			act(key, "washer", [{"n": 0, "t": 0.0}])
		var crew: Array = BUSINESS.crew_now(key)
		if not crew.is_empty():
			_crew_work(key, crew)
		_prepared(key)
		_proto(key)
		for v in ORDERS.visitors(key):
			var visit := str(v["visit"])
			var gid := int(v["id"])
			var figures := int(v.get("figures", 1))
			var since := int(v.get("arrive", now)) + RULES.ORDER_DELAY
			var hold := -1
			for t in RULES.tickets_for(visit, str(v["archetype"]), figures):
				var tid := str(t["id"])
				if served.has(tid):
					var done := int(served[tid].get("at", now)) + RULES.EAT_MINUTES
					hold = maxi(hold, done)
					if now >= done and not _cleared.has(tid):
						_cleared[tid] = true
						# A plate or a bowl back to the sink (a bottle goes in the crate).
						if not RULES.DRINKS.has(str(served[tid].get("dish", ""))):
							act(key, "plates", [0, 1])
				elif int(ORDERS._served.get(visit, 0)) < figures and BUSINESS.takes_orders_at(key, since + int(t["member"])):
					hold = maxi(hold, since + int(t["member"]) + int(RULES.PATIENCE_GONE / patience_k(key)))
			if hold > now:
				holds[gid] = hold
		# Plates of visits gone before they finished: back to the sink all the same.
		for tid in served.keys():
			if _cleared.has(tid):
				continue
			var visit := str(tid).get_slice("#", 0)
			var here := false
			for v in ORDERS.visitors(key):
				if str(v["visit"]) == visit:
					here = true
					break
			if not here:
				_cleared[tid] = true
				if not RULES.DRINKS.has(str(served[tid].get("dish", ""))):
					act(key, "plates", [0, 1])
		if _save_due.has(key):
			_save_due.erase(key)
			_save(key)
	# The Jednota keeps its own (orders.set_holds merges them).
	ORDERS.set_holds("rest", holds)


## The prepared goods bought in the books (the cellar skipped): cut chips and breaded
## cheese go onto the cellar's trays as they are wanted, as the cellar's hand would.
func _prepared(key: String) -> void:
	for pair in [["chips_cut", "chips_raw", 6], ["cheese_breaded", "cheese_raw", 4]]:
		var good := str(pair[0])
		var tray := str(pair[1])
		if prep(key, tray) < int(pair[2]) and room_for(key, tray) and BUSINESS.stock_of(key, good) > 0:
			if CoreRoot.actions.biz_take(key, {good: 1}):
				act(key, "prep", [tray, 1])


func _rest_sites() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	for key in sites:
		if str((sites[key] as Dictionary).get("kind", "")) == "rest":
			out.append(str(key))
	return out


## PROTOTYP 540, the host's, once a second (DESIGN.md §7b "The bistro"): awake, on one of
## its nights a sack lies in front of it; the morning after it was fed, its tray holds
## meat for twenty goulashes, in the stock as a lot of today's (actions.biz_gift). A sack
## nobody lifted is gone in the morning. The hands never go near it.
func _proto(key: String) -> void:
	if GuestManager == null:
		return
	var p: Dictionary = site(key)["proto"]
	var day := maxi(1, int(GuestManager._last_known_day))
	var hour := int(GuestManager._last_known_hour)
	var late := BUSINESS.shift_now(BUSINESS.site(key)) == "late"
	var night := RULES.proto_night(day, hour)
	if RULES.proto_awake(hour, late):
		if int(p["sack"]) < night and int(p["fed"]) < night and RULES.proto_sack(key, night, int(p["taken"]) == night):
			act(key, "proto", [{"sack": night}])
	elif hour >= 6 and hour < 20 and int(p["fed"]) == day - 1 and int(p["tray"]) < day:
		act(key, "proto", [{"tray": day}])
		if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_gift"):
			CoreRoot.actions.biz_gift(key, {"goulash": RULES.PROTO_MEAT})


## Tonight's sack there now (tools/proto_shots.gd).
func debug_proto_sack(key: String) -> void:
	var day := maxi(1, int(GuestManager._last_known_day)) if GuestManager != null else 1
	var hour := int(GuestManager._last_known_hour) if GuestManager != null else 22
	act(key, "proto", [{"taken": RULES.proto_night(day, hour)}])
	_proto(key)


## Fed tonight: the sack into its hopper (from the machine's station, either warden).
func proto_feed(key: String) -> void:
	var day := maxi(1, int(GuestManager._last_known_day)) if GuestManager != null else 1
	var hour := int(GuestManager._last_known_hour) if GuestManager != null else 22
	act(key, "proto", [{"fed": RULES.proto_night(day, hour)}])


## The machine's state for the station: {awake, sack (lies there now), fed (tonight),
## running, meat (in the tray now)}.
func proto_state(key: String) -> Dictionary:
	var p: Dictionary = site(key)["proto"]
	var day := maxi(1, int(GuestManager._last_known_day)) if GuestManager != null else 1
	var hour := int(GuestManager._last_known_hour) if GuestManager != null else 12
	var late := BUSINESS.shift_now(BUSINESS.site(key)) == "late"
	var awake := RULES.proto_awake(hour, late)
	var night := RULES.proto_night(day, hour)
	var fed := int(p["fed"]) == night
	return {"awake": awake, "sack": awake and int(p["sack"]) == night and not fed, "fed": fed, "running": awake and fed,
		"meat": not awake and int(p["tray"]) == day}


## A guest gone at dawn (the night took them; main._claim_turned_guests) or before it: the
## machine's next night has its sack. The host's.
func _on_guest_state(_id: int, _old: String, new_state: String) -> void:
	if new_state != "departed" or GuestManager == null or not Coop.sim_here():
		return
	var hour := int(GuestManager._last_known_hour)
	if hour < 3 or hour >= 8:
		return
	var day := maxi(1, int(GuestManager._last_known_day))
	for key in _rest_sites():
		act(str(key), "proto", [{"taken": day}])


func _note_save(key: String) -> void:
	_save_due[key] = true


## The trays, the pot and the plates into the books (they are saved with the camp).
func _save(key: String) -> void:
	if CoreRoot == null or CoreRoot.actions == null or not CoreRoot.actions.has_method("biz_kitchen"):
		return
	var s := site(key)
	CoreRoot.actions.biz_kitchen(key, {"prep": (s["prep"] as Dictionary).duplicate(), "pot": int(s["pot"]["level"]),
		"loaf": int(s["loaf"].get("left", 0)), "clean": int(s["plates"]["clean"]), "dirty": int(s["plates"]["dirty"]),
		"washer_n": int(s["washer"].get("n", 0)), "washer_t": float(s["washer"].get("t", 0.0)),
		"proto_sack": int(s["proto"]["sack"]), "proto_fed": int(s["proto"]["fed"]), "proto_tray": int(s["proto"]["tray"]),
		"proto_taken": int(s["proto"]["taken"]), "soup": int(s["soup"]["level"])})


## The hands in the kitchen (DESIGN.md §7b, the hands), one piece of work at a time as
## their speed allows; now and then one goes wrong (a slice left to burn, a badly breaded
## one, six dumplings for four, a plate dropped). Each works a station (crew_places: their
## own job's, or beside you where it is wanted while you are at theirs):
##   potatoes  raw chips and breaded slices onto the trays, off the shelves (the cellar's)
##   stove     turns the slices, racks the golden ones, bins the black ones, minds the
##             basket and the pot
##   pass      plates the oldest ticket it has everything ready for, and sends it out
##   sink      washes the dirty plates
##   grill     puts sausages on, turns them, racks the brown ones, bins the black ones
##   bufet     ladles the soup of the day and opens the bottles over the counter
##   floor     takes the plates off the hatch to the tables, opens the bottles
## Seconds till each hand's next piece of work: "key/slug" -> seconds.
var _crew_t: Dictionary = {}
const ROLE_AT := {"pass": "pass", "floor": "floor", "stove": "stove", "cellar": "potatoes", "sink": "sink", "grill": "grill", "bufet": "bufet"}
## Where a hand may go to help, the guests' end first (a tie goes to who waits at a table).
const CREW_STATIONS := ["floor", "pass", "bufet", "grill", "stove", "potatoes", "sink"]


## slug -> the station that hand works now ("" aside), at `key`.
func crew_places(key: String) -> Dictionary:
	var crew: Array = BUSINESS.crew_now(key)
	if crew.is_empty():
		return {}
	return CREW_PLACES.places(crew, ROLE_AT, CREW_STATIONS, _wardens_at(key), func(st: String) -> float: return station_need(key, st))


func _wardens_at(key: String) -> Array:
	return CREW_PLACES.wardens_at(get_tree(), key, "service") if is_inside_tree() else []


## How much a station of the bistro wants doing now (0 nothing): plates waiting on the
## hatch and bottles wanted, tickets to plate, the soup, sausages and slices wanted that
## are not on the rack or the fire yet, the trays of the cellar low, dirty plates.
func station_need(key: String, st: String) -> float:
	var s := site(key)
	match st:
		"floor":
			var n := 0.0
			for t in tickets(key, "floor"):
				n += 0.6 if bool(t.get("hatched", false)) else 0.3
			return n
		"pass":
			var n_pass := tickets(key, "pass").size()
			return 0.0 if n_pass == 0 or int(plates(key)["clean"]) <= 0 else 0.4 + 0.2 * float(n_pass)
		"bufet":
			var n_soup := tickets(key, "bufet").size()
			var low := 0.3 if int(s["soup"]["level"]) < 3 and BUSINESS.stock_of(key, "soup") > 0 and n_soup > 0 else 0.0
			return (0.4 * float(n_soup) if int(s["soup"]["level"]) > 0 else 0.0) + low
		"grill":
			var on := 0
			for slot in s["grill"]:
				if not (slot as Dictionary).is_empty():
					on += 1
			return 0.35 * float(on) + 0.3 * float(maxi(0, _wanted(key, "sausage") - prep(key, "sausage") - on))
		"stove":
			var cooking := 0
			for slot in s["pan"]:
				if not (slot as Dictionary).is_empty():
					cooking += 1
			var b: Dictionary = s["basket"]
			var frying := int(b["n"]) if str(b["st"]) == "down" else 0
			var need := 0.35 * float(cooking) + (0.4 if str(b["st"]) == "down" else 0.0)
			need += 0.3 * float(maxi(0, _wanted(key, "cheese") - prep(key, "cheese") - cooking))
			need += 0.3 * float(maxi(0, _wanted(key, "fries") - prep(key, "fries") - frying))
			if _wanted(key, "goulash") > 0 and int(s["pot"]["level"]) < 2 and BUSINESS.stock_of(key, "goulash") > 0:
				need += 0.3
			return need
		"potatoes":
			var need2 := 0.0
			if prep(key, "chips_raw") < 6 and BUSINESS.stock_of(key, "potatoes") > 0:
				need2 += 0.1 + 0.05 * float(6 - prep(key, "chips_raw"))
			if prep(key, "cheese_raw") + prep(key, "cheese_bad") < 4 and BUSINESS.stock_of(key, "cheese") > 0:
				need2 += 0.1 + 0.05 * float(4 - prep(key, "cheese_raw") - prep(key, "cheese_bad"))
			return need2
		"sink":
			var pl: Dictionary = plates(key)
			if int(pl["dirty"]) <= 0:
				return 0.0
			return minf(1.0, 0.12 * float(pl["dirty"])) + (0.6 if int(pl["clean"]) <= 0 else 0.0)
	return 0.0


## How many of `part` the tickets at the pass want.
func _wanted(key: String, part: String) -> int:
	var n := 0
	for t in tickets(key, "pass"):
		n += int((t["parts"] as Dictionary).get(part, 0))
	return n


## Somebody minds the floor: a hand works it now, or a warden is at it (the pass then
## puts the plates on the hatch for them; nobody, and the pass's hand carries them out).
func _floor_minded(key: String, places: Dictionary) -> bool:
	return places.values().has("floor") or _wardens_at(key).has("floor")


func _crew_work(key: String, crew: Array) -> void:
	var places := crew_places(key)
	var floor_minded := _floor_minded(key, places)
	for p in crew:
		var id := key + "/" + str(p.get("slug", ""))
		var left := float(_crew_t.get(id, 0.0)) - 1.0
		if left > 0.0:
			_crew_t[id] = left
			continue
		var speed := clampi(int(p.get("speed", 1)), 0, 2)
		var slip := randf() < float(BIZ_RULES.SPEED_SLIP[speed]) + (0.05 if str(p.get("temper", "")) == "sour" else 0.0)
		var did := false
		match str(places.get(str(p.get("slug", "")), "")):
			"potatoes":
				did = _crew_cellar(key, slip)
			"stove":
				did = _crew_stove(key, slip)
			"pass":
				did = _crew_pass(key, p, slip, floor_minded)
			"sink":
				did = _crew_sink(key, slip)
			"grill":
				did = _crew_grill(key, slip)
			"bufet":
				did = _crew_bufet(key, p, slip, floor_minded)
			"floor":
				did = _crew_floor(key, p, slip)
		_crew_t[id] = float(BIZ_RULES.SPEED_SEC[speed]) if did else 1.0


func _has_role(crew: Array, role: String) -> bool:
	for p in crew:
		if str(p.get("role", "")) == role:
			return true
	return false


## The floor (the brief of 21. 10.: a hand for every room): the oldest plate on the hatch
## to its table, else the oldest bottle wanted opened and served.
func _crew_floor(key: String, p: Dictionary, _slip: bool) -> bool:
	for t in tickets(key, "floor"):
		if bool(t.get("hatched", false)):
			serve_hatch(key, t, str(p.get("name", "")))
			return true
	for t in tickets(key, "floor"):
		var dish := str(t["dish"])
		if not RULES.DRINKS.has(dish):
			continue
		if BUSINESS.stock_of(key, str(RULES.DRINKS[dish]["good"])) <= 0:
			continue
		serve(key, t, {dish: 1}, -1.0, str(p.get("name", "")))
		return true
	return false


## The grill: the black ones off into the bin, the brown ones turned or onto the rack, a
## new one on while sausages are wanted.
func _crew_grill(key: String, slip: bool) -> bool:
	var g: Array = site(key)["grill"]
	var on := 0
	for i in g.size():
		var slot: Dictionary = g[i]
		if slot.is_empty():
			continue
		on += 1
		var d := RULES.sausage_side(float(slot["t"][int(slot["down"])]))
		var u := RULES.sausage_side(float(slot["t"][1 - int(slot["down"])]))
		if d == 2 or u == 2:
			act(key, "grill", [i, {}])
			return true
		if d == 1 and u == 1:
			if room_for(key, "sausage"):
				act(key, "grill", [i, {}])
				act(key, "prep", ["sausage", 1, [sausage_quality(slot)]])
				return true
		elif d == 1 and not slip:
			var turned := slot.duplicate(true)
			turned["down"] = 1 - int(slot["down"])
			act(key, "grill", [i, turned])
			return true
	var wanted := 0
	for t in tickets(key, "pass"):
		wanted += int((t["parts"] as Dictionary).get("sausage", 0))
	if prep(key, "sausage") + on < mini(3, wanted + 1) and BUSINESS.stock_of(key, "sausage") > 0:
		for i in g.size():
			if (g[i] as Dictionary).is_empty() and CoreRoot.actions.biz_take(key, {"sausage": 1}):
				act(key, "grill", [i, {"down": 0, "t": [0.0, 0.0]}])
				return true
	return false


## The bufet: the oldest soup wanted, over the counter (the soup pot topped up from the
## tins when it runs low); the bottles too while nobody minds the floor.
func _crew_bufet(key: String, p: Dictionary, slip: bool, floor_hand := false) -> bool:
	var soup: Dictionary = site(key)["soup"]
	if int(soup["level"]) < 3 and BUSINESS.stock_of(key, "soup") > 0:
		var n := mini(RULES.SOUP_REFILL, BUSINESS.stock_of(key, "soup"))
		if CoreRoot.actions.biz_take(key, {"soup": n}):
			act(key, "soup", [{"level": int(soup["level"]) + n}])
			return true
	for t in tickets(key, "bufet") + ([] if floor_hand else tickets(key, "floor").filter(func(x) -> bool: return RULES.DRINKS.has(str(x["dish"])))):
		var dish := str(t["dish"])
		if dish == "soup":
			if int(soup["level"]) <= 0 or int(plates(key)["clean"]) <= 0:
				continue
			act(key, "soup", [{"level": int(soup["level"]) - 1}])
			act(key, "plates", [-1, 0])
			serve(key, t, {"soup": 1}, 0.75 if slip else 0.9, str(p.get("name", "")))
			return true
		var good := str(RULES.DRINKS[dish]["good"])
		if BUSINESS.stock_of(key, good) <= 0:
			continue
		serve(key, t, {dish: 1}, -1.0, str(p.get("name", "")))
		return true
	return false


func _crew_cellar(key: String, slip: bool) -> bool:
	if prep(key, "chips_raw") < 6 and room_for(key, "chips_raw") and BUSINESS.stock_of(key, "potatoes") > 0:
		if CoreRoot.actions.biz_take(key, {"potatoes": 1}):
			act(key, "prep", ["chips_raw", 1])
			return true
	var raw := prep(key, "cheese_raw") + prep(key, "cheese_bad")
	if raw < 4 and room_for(key, "cheese_raw", 1 + prep(key, "cheese_bad")) and BUSINESS.stock_of(key, "cheese") > 0:
		if CoreRoot.actions.biz_take(key, {"cheese": 1}):
			act(key, "prep", ["cheese_bad" if slip else "cheese_raw", 1])
			return true
	return false


func _crew_stove(key: String, slip: bool) -> bool:
	var s := site(key)
	var pans: Array = s["pan"]
	var cooking := 0
	for i in pans.size():
		var slot: Dictionary = pans[i]
		if slot.is_empty():
			continue
		cooking += 1
		var bad := bool(slot.get("bad", false))
		var d := RULES.cheese_side(float(slot["t"][int(slot["down"])]), bad)
		var u := RULES.cheese_side(float(slot["t"][1 - int(slot["down"])]), bad)
		if d == 2 or u == 2:
			act(key, "pan", [i, {}])
			return true
		if d == 1 and u == 1:
			if room_for(key, "cheese"):
				var q := slice_quality(slot)
				act(key, "pan", [i, {}])
				act(key, "prep", ["cheese", 1, [q]])
				return true
		elif d == 1:
			if slip:
				return false
			var turned := slot.duplicate(true)
			turned["down"] = 1 - int(slot["down"])
			act(key, "pan", [i, turned])
			return true
	var b: Dictionary = s["basket"]
	if str(b["st"]) == "down":
		var fs := RULES.fries_state(float(b["t"]))
		if fs == 2:
			act(key, "basket", [{"st": "up", "t": 0.0, "n": 0}])
			return true
		if fs == 1 and not slip:
			var n := mini(int(b["n"]), int(RULES.PREP_CAP["fries"]) - prep(key, "fries"))
			if n > 0:
				var qs: Array = []
				for k in n:
					qs.append(fries_quality(float(b["t"])))
				act(key, "basket", [{"st": "up", "t": 0.0, "n": 0}])
				act(key, "prep", ["fries", n, qs])
				return true
	elif int(b["n"]) > 0:
		var down := (b as Dictionary).duplicate()
		down["st"] = "down"
		act(key, "basket", [down])
		return true
	elif prep(key, "fries") < 3 and prep(key, "chips_raw") > 0:
		var n2 := mini(basket_portions(key), prep(key, "chips_raw"))
		act(key, "prep", ["chips_raw", -n2])
		act(key, "basket", [{"st": "down", "t": 0.0, "n": n2}])
		return true
	if prep(key, "cheese") + cooking < 3:
		for i in pans.size():
			if not (pans[i] as Dictionary).is_empty():
				continue
			var bad2 := false
			if not take(key, "cheese_raw"):
				if not take(key, "cheese_bad"):
					break
				bad2 = true
			act(key, "pan", [i, {"bad": bad2, "down": 0, "t": [0.0, 0.0]}])
			return true
	var pot: Dictionary = s["pot"]
	if int(pot["level"]) > 0 and float(pot["catch"]) > 0.5:
		act(key, "pot", [{"level": int(pot["level"]), "heat": float(pot["heat"]), "catch": 0.0}])
		return true
	if int(pot["level"]) < 4:
		var g := mini(RULES.POT_REFILL, maxi(0, BUSINESS.stock_of(key, "goulash")))
		if g > 0 and CoreRoot.actions.biz_take(key, {"goulash": g}):
			act(key, "pot", [{"level": int(pot["level"]) + g, "heat": clampf(float(pot["heat"]) * float(pot["level"]) / float(int(pot["level"]) + g), 0.0, 1.0) * 0.6, "catch": 0.0}])
			return true
	return false


## The oldest ticket it has everything ready for, plated and sent out.
func _crew_pass(key: String, p: Dictionary, slip: bool, floor_minded := false) -> bool:
	# Nobody on the floor: what waits on the hatch goes out first (the pass's hand carries).
	if not floor_minded:
		for t in tickets(key, "floor"):
			if bool(t.get("hatched", false)):
				serve_hatch(key, t, str(p.get("name", "")))
				return true
	if int(plates(key)["clean"]) <= 0:
		return false
	var pot: Dictionary = site(key)["pot"]
	for t in tickets(key, "pass"):
		var want: Dictionary = t["parts"]
		var ok := true
		for part in want:
			var n := int(want[part])
			match str(part):
				"goulash":
					ok = ok and int(pot["level"]) >= n and float(pot["heat"]) >= 0.6
				"cheese", "fries", "dumpling", "sausage":
					ok = ok and prep(key, str(part)) >= n
				"bread":
					ok = ok and BUSINESS.stock_of(key, "bread") >= n
		if not ok:
			continue
		var parts: Dictionary = want.duplicate()
		var qs: Array = []
		for part in want:
			var n2 := int(want[part])
			match str(part):
				"goulash":
					var p2: Dictionary = (site(key)["pot"] as Dictionary).duplicate()
					qs.append(goulash_quality(p2))
					p2["level"] = int(p2["level"]) - n2
					act(key, "pot", [p2])
				"cheese", "fries", "sausage":
					qs.append_array(take_q(key, str(part), n2))
				"dumpling":
					take(key, "dumpling", n2)
				"bread":
					CoreRoot.actions.biz_take(key, {"bread": n2})
		act(key, "plates", [-1, 0])
		if slip:
			# Not quite: the dumplings miscounted, or the tartar forgotten.
			if parts.has("dumpling"):
				parts["dumpling"] = maxi(2, int(parts["dumpling"]) + (2 if randf() < 0.5 else -2))
			elif parts.has("tartar"):
				parts.erase("tartar")
			elif parts.has("mustard"):
				parts.erase("mustard")
		var cook := -1.0
		if not qs.is_empty():
			cook = 0.0
			for q in qs:
				cook += float(q)
			cook /= float(qs.size())
		# Somebody on the floor takes it out from the hatch; without them the pass's hand
		# carries it out as before.
		if floor_minded:
			to_hatch(key, t, parts, cook)
		else:
			serve(key, t, parts, cook, str(p.get("name", "")))
		return true
	return false


func _crew_sink(key: String, slip: bool) -> bool:
	var pl: Dictionary = plates(key)
	if int(pl["dirty"]) <= 0:
		return false
	if gear(key, "washer") and int(site(key)["washer"].get("n", 0)) == 0 and int(pl["dirty"]) >= 3:
		load_washer(key)
		return true
	# Now and then one slips out of their hands (a plate fewer for good).
	if slip and randf() < 0.3:
		act(key, "plates", [0, -1])
	else:
		act(key, "plates", [1, -1])
	return true


## The dirty plates into the dishwasher: out clean when its run is over.
func load_washer(key: String) -> int:
	var n := int(plates(key)["dirty"])
	if n <= 0 or int(site(key)["washer"].get("n", 0)) > 0:
		return 0
	act(key, "plates", [0, -n])
	act(key, "washer", [{"n": n, "t": WASHER_SEC}])
	return n


## Today's plates out of the hatch at `key`: {plates, stars (average), money}.
func today(key: String) -> Dictionary:
	var day := now_min() / 1440
	var n := 0
	var stars := 0
	var money := 0
	for rec in (site(key)["served"] as Dictionary).values():
		if int((rec as Dictionary).get("at", -1)) / 1440 != day or bool(rec.get("hand", false)):
			continue
		n += 1
		stars += int(rec.get("stars", 0))
		money += int(rec.get("amount", 0))
	return {"plates": n, "stars": float(stars) / float(maxi(1, n)), "money": money}


# ── what the room shows ──────────────────────────────────────────────────────

## The grill's state for the marks: {burning, ready, cooking} as the stove's.
func grill_state(key: String) -> Dictionary:
	var out := {"burning": false, "ready": false, "cooking": false}
	for slot in site(key)["grill"]:
		if (slot as Dictionary).is_empty():
			continue
		out["cooking"] = true
		var d := RULES.sausage_side(float(slot["t"][int(slot["down"])]))
		var u := RULES.sausage_side(float(slot["t"][1 - int(slot["down"])]))
		if d == 2 or u == 2:
			out["burning"] = true
		elif d == 1:
			out["ready"] = true
	return out


## The stove's state for the marks: {burning: a slice or the chips going black, ready:
## something golden waiting to come out, cooking: anything in the oil}.
func stove_state(key: String) -> Dictionary:
	var s := site(key)
	var out := {"burning": false, "ready": false, "cooking": false}
	for slot in s["pan"]:
		if (slot as Dictionary).is_empty():
			continue
		out["cooking"] = true
		var bad := bool(slot.get("bad", false))
		var down := RULES.cheese_side(float(slot["t"][int(slot["down"])]), bad)
		var up := RULES.cheese_side(float(slot["t"][1 - int(slot["down"])]), bad)
		if down == 2 or up == 2:
			out["burning"] = true
		elif down == 1:
			out["ready"] = true
	var b: Dictionary = s["basket"]
	if str(b["st"]) == "down":
		out["cooking"] = true
		var st := RULES.fries_state(float(b["t"]))
		if st == 2:
			out["burning"] = true
		elif st == 1:
			out["ready"] = true
	return out


# ── debug (tools/podniky_coop.gd) ────────────────────────────────────────────

## The oldest bufet ticket served as it should be (a bowl of soup, a bottle): true when
## there was one.
func debug_serve_first_bufet(key: String) -> bool:
	for t in tickets(key, "bufet") + tickets(key, "floor").filter(func(x) -> bool: return RULES.DRINKS.has(str(x["dish"]))):
		var dish := str(t["dish"])
		if dish == "soup":
			act(key, "plates", [-1, 0])
			return bool(serve(key, t, {"soup": 1}, 1.0).get("ok", false))
		return bool(serve(key, t, {dish: 1}, -1.0).get("ok", false))
	return false
