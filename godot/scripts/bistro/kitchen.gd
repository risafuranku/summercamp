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
##   served  tickets served: id -> {dish, at (game minute), parts}
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
	var prep := {"chips_raw": 0, "cheese_raw": 0, "cheese_bad": 0, "cheese": 0, "fries": 0, "dumpling": 0}
	for k in (saved.get("prep", {}) as Dictionary):
		if prep.has(k):
			prep[k] = int(saved["prep"][k])
	var pans: Array = []
	for i in pan_slots(key):
		pans.append({})
	return {
		"prep": prep,
		# How good each thing on the trays is (0..1), oldest first, as they were made.
		"q": {},
		"pan": pans,
		"basket": {"st": "up", "t": 0.0, "n": 0},
		"pot": {"level": int(saved.get("pot", 6)), "heat": 1.0, "catch": 0.0},
		"loaf": {"left": int(saved.get("loaf", 0))},
		"plates": {"clean": int(saved.get("clean", RULES.PLATES)), "dirty": int(saved.get("dirty", 0))},
		# The dishwasher (gear): plates in it and the seconds left.
		"washer": {"n": int(saved.get("washer_n", 0)), "t": float(saved.get("washer_t", 0.0))},
		"served": {},
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
## have read the menu.
func tickets(key: String) -> Array:
	var out: Array = []
	var now := now_min()
	var served: Dictionary = site(key)["served"]
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
		"served":
			var rec: Dictionary = (args[1] as Dictionary).duplicate(true)
			s["served"][str(args[0])] = rec
			# Out of the hatch, on whichever machine served it.
			plate_out.emit(key, str(args[0]), rec)
		"snap":
			var got: Dictionary = args[0]
			for k in ["prep", "q", "pan", "basket", "pot", "loaf", "plates", "washer"]:
				if got.has(k):
					s[k] = (got[k] as Dictionary).duplicate(true) if got[k] is Dictionary else (got[k] as Array).duplicate(true)
			for tid in (got.get("served", {}) as Dictionary):
				s["served"][tid] = got["served"][tid]
	changed.emit(key, op)


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
	return {"prep": s["prep"], "q": s["q"], "pan": s["pan"], "basket": s["basket"], "pot": s["pot"], "loaf": s["loaf"], "plates": s["plates"], "washer": s["washer"], "served": s["served"]}


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
	BUSINESS.sell(key, {}, amount)
	var v := {"id": int(t["guest_id"]), "visit": str(t["visit"])}
	ORDERS.note_served(v)
	var line := _review_line(str(t["dish"]), verdict)
	ORDERS.mood(int(t["guest_id"]), float(verdict["mood"]), line)
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
			_:
				return "The chips were pale and limp."
	if int(verdict.get("score", 0)) >= 92:
		match dish:
			"goulash":
				return "The goulash was like my grandmother's."
			"smazak":
				return "The fried cheese was perfect."
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
	var sid: int = st.get_instance_id() if st != null else 0
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
						act(key, "plates", [0, 1])
				elif int(ORDERS._served.get(visit, 0)) < figures:
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
				act(key, "plates", [0, 1])
		if _save_due.has(key):
			_save_due.erase(key)
			_save(key)
	# The Jednota keeps its own (orders.set_holds merges them).
	ORDERS.set_holds("rest", holds)


func _rest_sites() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	for key in sites:
		if str((sites[key] as Dictionary).get("kind", "")) == "rest":
			out.append(str(key))
	return out


func _note_save(key: String) -> void:
	_save_due[key] = true


## The trays, the pot and the plates into the books (they are saved with the camp).
func _save(key: String) -> void:
	if CoreRoot == null or CoreRoot.actions == null or not CoreRoot.actions.has_method("biz_kitchen"):
		return
	var s := site(key)
	CoreRoot.actions.biz_kitchen(key, {"prep": (s["prep"] as Dictionary).duplicate(), "pot": int(s["pot"]["level"]),
		"loaf": int(s["loaf"].get("left", 0)), "clean": int(s["plates"]["clean"]), "dirty": int(s["plates"]["dirty"]),
		"washer_n": int(s["washer"].get("n", 0)), "washer_t": float(s["washer"].get("t", 0.0))})


## The hands in the kitchen, each at their job (DESIGN.md §7b, the hands), one piece of
## work at a time as their speed allows; now and then one goes wrong (a slice left to burn,
## a badly breaded one, six dumplings for four, a plate dropped):
##   cellar  raw chips and breaded slices onto the trays, off the shelves
##   stove   turns the slices, racks the golden ones, bins the black ones, minds the
##           basket and the pot
##   pass    plates the oldest ticket it has everything ready for, and sends it out
##   sink    washes the dirty plates
## A warden at the same station works alongside them (the stove's slices are the same).
## Seconds till each hand's next piece of work: "key/slug" -> seconds.
var _crew_t: Dictionary = {}


func _crew_work(key: String, crew: Array) -> void:
	for p in crew:
		var id := key + "/" + str(p.get("slug", ""))
		var left := float(_crew_t.get(id, 0.0)) - 1.0
		if left > 0.0:
			_crew_t[id] = left
			continue
		var speed := clampi(int(p.get("speed", 1)), 0, 2)
		var slip := randf() < float(BIZ_RULES.SPEED_SLIP[speed]) + (0.05 if str(p.get("temper", "")) == "sour" else 0.0)
		var did := false
		match str(p.get("role", "")):
			"cellar":
				did = _crew_cellar(key, slip)
			"stove":
				did = _crew_stove(key, slip)
			"pass":
				did = _crew_pass(key, p, slip)
			"sink":
				did = _crew_sink(key, slip)
		_crew_t[id] = float(BIZ_RULES.SPEED_SEC[speed]) if did else 1.0


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
func _crew_pass(key: String, p: Dictionary, slip: bool) -> bool:
	if int(plates(key)["clean"]) <= 0:
		return false
	var pot: Dictionary = site(key)["pot"]
	for t in tickets(key):
		var want: Dictionary = t["parts"]
		var ok := true
		for part in want:
			var n := int(want[part])
			match str(part):
				"goulash":
					ok = ok and int(pot["level"]) >= n and float(pot["heat"]) >= 0.6
				"cheese", "fries", "dumpling":
					ok = ok and prep(key, str(part)) >= n
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
				"cheese", "fries":
					qs.append_array(take_q(key, str(part), n2))
				"dumpling":
					take(key, "dumpling", n2)
		act(key, "plates", [-1, 0])
		if slip:
			# Not quite: the dumplings miscounted, or the tartar forgotten.
			if parts.has("dumpling"):
				parts["dumpling"] = maxi(2, int(parts["dumpling"]) + (2 if randf() < 0.5 else -2))
			elif parts.has("tartar"):
				parts.erase("tartar")
		var cook := -1.0
		if not qs.is_empty():
			cook = 0.0
			for q in qs:
				cook += float(q)
			cook /= float(qs.size())
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
