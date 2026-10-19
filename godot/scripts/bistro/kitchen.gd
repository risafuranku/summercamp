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
	for i in RULES.PAN_SLOTS:
		pans.append({})
	return {
		"prep": prep,
		"pan": pans,
		"basket": {"st": "up", "t": 0.0, "n": 0},
		"pot": {"level": int(saved.get("pot", 6)), "heat": 1.0, "catch": 0.0},
		"loaf": {"left": int(saved.get("loaf", 0))},
		"plates": {"clean": int(saved.get("clean", RULES.PLATES)), "dirty": int(saved.get("dirty", 0))},
		"served": {},
	}


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
			t["age"] = maxi(0, now - int(t["since"]))
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
			p[item] = maxi(0, int(p.get(item, 0)) + int(args[1]))
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
		"served":
			var rec: Dictionary = (args[1] as Dictionary).duplicate(true)
			s["served"][str(args[0])] = rec
			# Out of the hatch, on whichever machine served it.
			plate_out.emit(key, str(args[0]), rec)
		"snap":
			var got: Dictionary = args[0]
			for k in ["prep", "pan", "basket", "pot", "loaf", "plates"]:
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
	return {"prep": s["prep"], "pan": s["pan"], "basket": s["basket"], "pot": s["pot"], "loaf": s["loaf"], "plates": s["plates"], "served": s["served"]}


## Takes `n` of `item` off a tray; false when there is not that much.
func take(key: String, item: String, n := 1) -> bool:
	if prep(key, item) < n:
		return false
	act(key, "prep", [item, -n])
	return true


## Room on a tray or rack for `n` more of `item`.
func room_for(key: String, item: String, n := 1) -> bool:
	return prep(key, item) + n <= int(RULES.PREP_CAP.get(item, 99))


## The plate goes out through the hatch for ticket `t`: judged, sold (the money is
## the camp's, the books count it), the guest's mood, the plate off the stack. Returns
## the judgement ({ok: false}: not theirs, it comes back).
func serve(key: String, t: Dictionary, parts: Dictionary) -> Dictionary:
	var verdict: Dictionary = RULES.judge(parts, t["parts"], int(t.get("age", 0)))
	if not bool(verdict["ok"]):
		return verdict
	var amount := int(t["price"]) + int(verdict["tip"])
	verdict["amount"] = amount
	BUSINESS.sell(key, {}, amount)
	var v := {"id": int(t["guest_id"]), "visit": str(t["visit"])}
	ORDERS.note_served(v)
	ORDERS.mood(int(t["guest_id"]), float(verdict["mood"]), _thought(verdict))
	act(key, "served", [str(t["id"]), {"dish": str(t["dish"]), "at": now_min(), "parts": parts, "stars": int(verdict["stars"]), "amount": amount}])
	return verdict


func _thought(verdict: Dictionary) -> String:
	if int(verdict["stars"]) >= 3:
		return "The bistro is quick and the food is hot."
	if float(verdict["speed"]) < 0.3:
		return "Waited an age for my dinner."
	if float(verdict["accuracy"]) < 0.7:
		return "They got my order wrong at the bistro."
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
	for slot in s["pan"]:
		if (slot as Dictionary).is_empty():
			continue
		var d := int(slot["down"])
		slot["t"][d] = float(slot["t"][d]) + delta
	var b: Dictionary = s["basket"]
	if str(b["st"]) == "down":
		b["t"] = float(b["t"]) + delta
	var pot: Dictionary = s["pot"]
	if int(pot["level"]) > 0:
		pot["heat"] = minf(1.0, float(pot["heat"]) + delta / RULES.POT_HEAT_SEC)
		pot["catch"] = float(pot["catch"]) + delta / RULES.POT_CATCH_SEC
		if float(pot["catch"]) >= 1.0:
			# Caught on the bottom: the burnt layer goes in the bin.
			pot["catch"] = 0.0
			pot["level"] = maxi(0, int(pot["level"]) - RULES.POT_BURN_LOSS)
			burnt_flash[key] = 3.0
			changed.emit(key, "pot")
	else:
		pot["catch"] = 0.0


## Host, once a second: the guests kept in their seats while their food is coming and
## while they eat; the plates they finished with to the sink; the save; the hand's work.
func _host_second() -> void:
	var now := now_min()
	var holds: Dictionary = {}
	for key in _rest_sites():
		var s := site(key)
		var served: Dictionary = s["served"]
		var staff := bool(BUSINESS.site(key).get("staff", false))
		if staff:
			_hand_work(key)
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
					hold = maxi(hold, since + int(t["member"]) + RULES.PATIENCE_GONE)
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
	var life = GuestManager.get("_life") if GuestManager != null else null
	if life != null and "visit_holds" in life:
		life.visit_holds = holds


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
		"loaf": int(s["loaf"].get("left", 0)), "clean": int(s["plates"]["clean"]), "dirty": int(s["plates"]["dirty"])})


## A hand in the kitchen keeps the trays full and the pot topped up, from the shelves,
## and washes up (they serve the guests themselves: business_runtime._hand_serves).
func _hand_work(key: String) -> void:
	var s := site(key)
	var want := {"cheese": 2, "fries": 2, "dumpling": 8}
	var from := {"cheese": "cheese", "fries": "potatoes", "dumpling": "dumplings"}
	for item in want:
		var short: int = int(want[item]) - prep(key, item)
		if short <= 0:
			continue
		var units := short if item != "dumpling" else ceili(short / 4.0)
		var have: int = maxi(0, BUSINESS.stock_of(key, str(from[item])))
		units = mini(units, have)
		if units <= 0 or CoreRoot.actions == null or not CoreRoot.actions.biz_take(key, {str(from[item]): units}):
			continue
		act(key, "prep", [item, units if item != "dumpling" else units * 4])
	var pot: Dictionary = s["pot"]
	if int(pot["level"]) < 4:
		var g := mini(RULES.POT_REFILL, maxi(0, BUSINESS.stock_of(key, "goulash")))
		if g > 0 and CoreRoot.actions.biz_take(key, {"goulash": g}):
			act(key, "pot", [{"level": int(pot["level"]) + g, "heat": 1.0, "catch": 0.0}])
	elif float(pot["catch"]) > 0.5:
		act(key, "pot", [{"level": int(pot["level"]), "heat": float(pot["heat"]), "catch": 0.0}])
	var pl: Dictionary = s["plates"]
	if int(pl["dirty"]) > 0:
		act(key, "plates", [int(pl["dirty"]), -int(pl["dirty"])])


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
