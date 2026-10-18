extends Node

## The camp's businesses running (core/systems/business_rules.gd has the numbers):
##   - every pub, bistro, Jednota and corn stand that stands has its books
##     (GameState.biz, made by actions.biz_site);
##   - the guests the simulation sends in (GuestManager's visits) want their basket: with
##     a hand behind the counter it is sold from the shelves on its own (most of the time),
##     without one they wait for you to serve them in the counter's game (scripts/food/*,
##     which sell through sell() below), and go away unserved if you do not;
##   - nothing on the shelf, nothing sold: they go away grumbling;
##   - at the turn of the day the hands are paid and the day's books closed;
##   - orders are due the morning after: the van comes (scripts/day_events.gd asks
##     due_today()), and what is signed for goes on the shelves.
##
## Made by InteriorManager.setup() (root of the camp's interiors), one per game.

const RULES := preload("res://core/systems/business_rules.gd")
const ORDERS := preload("res://scripts/food/orders.gd")

signal changed

var _t := 0.0
var _day := -1
## Visits seen: visit id -> {key, served (by a hand), end}
var _visits: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Who sits waiting with nobody behind the counter: key -> [visitor], and the visits
## already told on the feed.
var _waiting: Dictionary = {}
var _told: Dictionary = {}


func _ready() -> void:
	name = "Businesses"
	add_to_group("businesses")
	_rng.randomize()


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0:
		return
	_t = 0.0
	if CoreRoot == null or CoreRoot.actions == null or CoreRoot.get_state() == null:
		return
	var sites := _live_sites()
	_watch_waiting(sites)
	# In co-op the host runs the camp.
	if not Coop.sim_here():
		return
	CoreRoot.actions.biz_prune(sites.keys())
	for key in sites:
		CoreRoot.actions.biz_site(key, sites[key])
	_watch_visits(sites)
	_hands_work()
	var day := CoreRoot.get_day()
	if _day < 0:
		_day = day
	elif day != _day:
		_day = day
		var wages: int = CoreRoot.actions.biz_close_day()
		if wages > 0:
			_say("Wages paid to the hands: -$%d." % wages)
	changed.emit()


## The business buildings standing now: "x:y" -> building type.
func _live_sites() -> Dictionary:
	var out := {}
	var grid = CoreRoot.get_state().grid
	if grid == null:
		return out
	for coord in grid.cells:
		var data: Dictionary = grid.cells[coord]
		var t := str(data.get("type", ""))
		if not RULES.is_business(t):
			continue
		var rc = data.get("root_coord", coord)
		var key := "%d:%d" % [int(rc.x), int(rc.y)]
		out[key] = t
	return out


func _watch_visits(sites: Dictionary) -> void:
	if GuestManager == null:
		return
	var now := {}
	for key in sites:
		for v in ORDERS.visitors(key):
			now[str(v["visit"])] = true
			if _visits.has(str(v["visit"])):
				continue
			var kind := RULES.kind_of(str(sites[key]))
			var rec := {"key": key, "kind": kind, "v": v, "served": false}
			_visits[str(v["visit"])] = rec
			var site: Dictionary = CoreRoot.get_state().biz["sites"].get(key, {})
			if bool(site.get("staff", false)):
				_hand_serves(rec)
	# Gone: anybody nobody served went away hungry (or thirsty).
	for id in _visits.keys():
		if now.has(id):
			continue
		var rec: Dictionary = _visits[id]
		_visits.erase(id)
		var by_hand := int(ORDERS._served.get(id, 0)) > 0
		if not rec["served"] and not by_hand:
			CoreRoot.actions.biz_lost(str(rec["key"]))
			var v: Dictionary = rec["v"]
			ORDERS.mood(int(v["id"]), -3.0, _complaint(str(rec["kind"])))


## Guests sitting in a business with nobody behind its counter: a line on the feed when
## somebody new comes in, and the HUD's rows (hud_rows) while they wait. Both machines
## in co-op: the guests' visits come with the host's pulse.
func _watch_waiting(sites: Dictionary) -> void:
	_waiting.clear()
	var live := {}
	for key in sites:
		if bool(site(key).get("staff", false)):
			continue
		var fresh := false
		for v in ORDERS.visitors(key):
			var id := str(v["visit"])
			live[id] = true
			if ORDERS.served(key, id):
				continue
			if not _waiting.has(key):
				_waiting[key] = []
			_waiting[key].append(v)
			if not _told.has(id):
				_told[id] = true
				fresh = true
		if fresh:
			var waiting: Array = _waiting[key]
			_say(_waiting_line(RULES.kind_of(str(sites[key])), waiting), 2, "biz_wait:" + key)
	for id in _told.keys():
		if not live.has(id):
			_told.erase(id)


func _waiting_line(kind: String, waiting: Array) -> String:
	var who := str(waiting[0].get("name", "A guest")) if waiting.size() == 1 else "%d guests" % waiting.size()
	var verb := "is" if waiting.size() == 1 else "are"
	match kind:
		"pub":
			return "%s %s at the bar in the pub. Nobody behind it." % [who, verb]
		"rest":
			return "%s %s sitting in the bistro. Nobody to take the order." % [who, verb]
		"vecerka":
			return "%s %s at the Jednota till. Nobody there." % [who, verb]
		"corn":
			return "%s %s waiting at the corn stand." % [who, verb]
	return "%s %s waiting to be served." % [who, verb]


## HUD rows for the guests waiting to be served: [{title, where}].
func hud_rows() -> Array:
	var rows: Array = []
	for key in _waiting:
		var waiting: Array = _waiting[key]
		var kind := str(site(key).get("kind", ""))
		var title := str((RULES.KINDS.get(kind, {}) as Dictionary).get("name", "Business"))
		rows.append({"title": "%s: %d waiting" % [title, waiting.size()], "where": "serve them at the counter"})
	return rows


## How many wait to be served at `key` now (nobody behind its counter).
func waiting_at(key: String) -> int:
	return (_waiting.get(key, []) as Array).size()


## Everybody waiting to be served, all the businesses together (the HUD).
func waiting_total() -> int:
	var n := 0
	for k in _waiting:
		n += (_waiting[k] as Array).size()
	return n


## The nearest business with somebody waiting to be served (the HUD's waypoint): {position,
## label}, or {}.
func waypoint(from: Vector3, grid_manager) -> Dictionary:
	var best := {}
	var best_d := INF
	if grid_manager == null:
		return best
	for key in _waiting:
		if (_waiting[key] as Array).is_empty():
			continue
		var parts := str(key).split(":")
		if parts.size() < 2:
			continue
		var p: Vector3 = grid_manager.grid_to_world(Vector2i(int(parts[0]), int(parts[1])))
		var d := from.distance_to(p)
		if d < best_d:
			best_d = d
			var kind := str(site(key).get("kind", ""))
			best = {"position": p + Vector3(0, 3.0, 0), "label": {"pub": "PUB", "rest": "BISTRO", "vecerka": "JEDNOTA", "corn": "CORN"}.get(kind, "SERVE")}
	return best


## What the hands do between customers: the barman washes up, the cook fries ahead.
func _hands_work() -> void:
	for key in CoreRoot.get_state().biz["sites"]:
		var s: Dictionary = CoreRoot.get_state().biz["sites"][key]
		if not bool(s.get("staff", false)):
			continue
		if s.has("glasses"):
			s["glasses"]["clean"] = int(s["glasses"]["clean"]) + int(s["glasses"]["dirty"])
			s["glasses"]["dirty"] = 0
		if s.has("prep"):
			for part in ["cheese", "fries"]:
				var good := "cheese" if part == "cheese" else "potatoes"
				s["prep"][part] = mini(4, int(s["stock"].get(good, 0)))


## The hand behind the counter serves the visit what it wants, if it is on the shelf.
func _hand_serves(rec: Dictionary) -> void:
	var v: Dictionary = rec["v"]
	var kind: String = rec["kind"]
	if _rng.randf() > RULES.HAND_SERVES:
		return
	var appetite := ORDERS.left_for(v, kind if kind != "corn" else "corn")
	var b := RULES.basket(kind, maxi(1, appetite), _rng.randf())
	var needs := RULES.needs_for(kind, b)
	var key: String = rec["key"]
	if not CoreRoot.actions.biz_take(key, needs):
		# Whatever there is of it, then.
		var part := {}
		var stock: Dictionary = CoreRoot.get_state().biz["sites"][key]["stock"]
		for g in b:
			var n := mini(int(b[g]), int(stock.get(g, 0)))
			if n > 0:
				part[g] = n
		needs = RULES.needs_for(kind, part)
		if part.is_empty() or not CoreRoot.actions.biz_take(key, needs):
			return
		b = part
	var units := 0
	for g in b:
		units += int(b[g])
	CoreRoot.actions.biz_sale(key, RULES.basket_price(kind, b), units, false)
	rec["served"] = true
	for i in units:
		ORDERS.note_served(v)


func _complaint(kind: String) -> String:
	match kind:
		"pub":
			return "Stood at the bar and nobody came."
		"rest":
			return "Sat in the bistro an hour. No food."
		"vecerka":
			return "The shop was open and nobody at the till."
		"corn":
			return "The corn stand. Nobody there."
	return "Nobody served us."


func _say(text: String, kind := 0, group := "") -> void:
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("push_status"):
		hud.push_status(text, kind, group)


# ── for the counter games, the desks and the programs ────────────────────────

## A sale made by hand in a counter game: off the shelf, into the till. False (nothing
## sold) when the shelf is short: the tap runs dry, the pot is empty.
static func sell(key: String, needs: Dictionary, amount: int, credit := true) -> bool:
	if CoreRoot == null or CoreRoot.actions == null or key == "":
		return true
	if not (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).has(key):
		return true
	if not CoreRoot.actions.biz_take(key, needs):
		return false
	var units := 0
	for g in needs:
		units += int(needs[g])
	CoreRoot.actions.biz_sale(key, amount, units, true, credit)
	return true


## How much of `good` is on the shelf at `key` (-1 when the site has no books yet).
static func stock_of(key: String, good: String) -> int:
	if CoreRoot == null or CoreRoot.get_state() == null:
		return -1
	var site: Dictionary = (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).get(key, {})
	if site.is_empty():
		return -1
	return int(site["stock"].get(good, 0))


static func site(key: String) -> Dictionary:
	if CoreRoot == null or CoreRoot.get_state() == null:
		return {}
	return (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).get(key, {})


## Units of `good` already on order for `key`.
static func on_order(key: String, good: String) -> int:
	var n := 0
	var site_rec := site(key)
	if site_rec.is_empty():
		return 0
	var pack := int((RULES.goods(str(site_rec["kind"])).get(good, {}) as Dictionary).get("pack", 1))
	for o in CoreRoot.get_state().biz.get("orders", []):
		if str(o.get("key", "")) == key:
			n += int((o["goods"] as Dictionary).get(good, 0)) * pack
	return n


## Orders the van brings today (the day events make the van come for them).
static func due_today() -> bool:
	if CoreRoot == null or CoreRoot.get_state() == null:
		return false
	var day := CoreRoot.get_day()
	for o in CoreRoot.get_state().biz.get("orders", []):
		if int(o.get("due_day", 0)) <= day:
			return true
	return false
