extends Node

## The camp's businesses running (core/systems/business_rules.gd has the numbers):
##   - every pub, bistro, Jednota and corn stand that stands has its books
##     (GameState.biz, made by actions.biz_site);
##   - the guests the simulation sends in (GuestManager's visits) want their basket: with
##     the front job covered (a hand at the pub's tap, the Jednota's till, the stand's
##     counter) it is sold from the shelves on its own (most of the time); the bistro's
##     hands work its kitchen instead, each at their job (kitchen.gd crew_tick). Without
##     anybody they wait for you to serve them, and go away unserved if you do not;
##   - nothing on the shelf, nothing sold: they go away grumbling;
##   - the hands come in for their shift (or do not: a note on the door), work, now and
##     then take something that is not theirs (the dishonest ones), and are paid at the
##     day's close for the shift they did; two days unpaid and they leave;
##   - the morning: what has been on the shelves too long goes off (it has to be thrown
##     out); orders are due the morning after: the van comes (scripts/day_events.gd asks
##     due_today()), and what is signed for goes on the shelves;
##   - the place shuts at 20:00, or at 23:00 when it is open late: the shift's Z report
##     comes out of the till (`zreport`).
##
## Made by InteriorManager.setup() (root of the camp's interiors), one per game.

const RULES := preload("res://core/systems/business_rules.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
## The bistros' kitchens: the trays, the stove, the pot, the tickets (loaded, not
## preloaded: the kitchen preloads this script).
const KITCHEN_PATH := "res://scripts/bistro/kitchen.gd"
const TAPROOM_PATH := "res://scripts/pub/taproom.gd"
const CORNSTAND_PATH := "res://scripts/corn/cornstand.gd"
const JEDNOTA_PATH := "res://scripts/jednota/jednota.gd"
## The day shift's first hour.
const OPEN_HOUR := 7

signal changed
## A place shut for the day: its Z report (actions.biz_close_shift).
signal zreport(key: String, report: Dictionary)
## Last orders at a place (half an hour before it shuts).
signal last_call(key: String)

var _t := 0.0
var _day := -1
## Visits seen: visit id -> {key, served (by a hand), end}
var _visits: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Who sits waiting with nobody behind the counter: key -> [visitor], and the visits
## already told on the feed.
var _waiting: Dictionary = {}
var _told: Dictionary = {}
## Each place's shift as it was last second: "day", "late" or "closed".
var _shift_was: Dictionary = {}


func _ready() -> void:
	name = "Businesses"
	add_to_group("businesses")
	_rng.randomize()
	add_child(load(KITCHEN_PATH).new())
	# The pubs' bars: their hands pour whether anybody is in the pub or not.
	add_child(load(TAPROOM_PATH).new())
	# The corn stands (one may have made it already: a stand built before this).
	if get_tree().get_first_node_in_group("cornstands") == null:
		add_child(load(CORNSTAND_PATH).new())
	# The Jednotas: their guests take their baskets, their hands work, nobody watching.
	if get_tree().get_first_node_in_group("jednotas") == null:
		add_child(load(JEDNOTA_PATH).new())


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
	var day := CoreRoot.get_day()
	if _day < 0:
		_day = day
	elif day != _day:
		_new_day(_day, day)
		_day = day
	_watch_shifts(sites)
	_watch_late(sites)
	_watch_crew(sites)
	_watch_visits(sites)
	_hands_work()
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


# ── the day ──────────────────────────────────────────────────────────────────

## Midnight passed: the hands are paid for yesterday (the dishonest ones first help
## themselves), what was left owed; then the morning: who comes in today, what went off,
## and whatever the one who was not on the books did in the night.
func _new_day(was: int, day: int) -> void:
	var act = CoreRoot.actions
	for key in (CoreRoot.get_state().biz.get("sites", {}) as Dictionary):
		_thieves(str(key), was)
	var closed: Dictionary = act.biz_close_day(was)
	if int(closed.get("wages", 0)) > 0:
		_say("Wages paid to the hands: -$%d." % int(closed["wages"]))
	for who in closed.get("left", []):
		_say("%s has left. Two days without pay." % str(who), 2)
	for key in (CoreRoot.get_state().biz.get("sites", {}) as Dictionary):
		_attendance(str(key), day)
		_night_hand(str(key))
	var off: Array = act.biz_spoil(day)
	var by_site := {}
	for o in off:
		by_site[str(o["key"])] = (by_site.get(str(o["key"]), []) as Array) + [str(o["good"])]
	for key in by_site:
		var kind := str(site(key).get("kind", ""))
		var names: Array = []
		for g in by_site[key]:
			names.append(str((RULES.goods(kind).get(g, {}) as Dictionary).get("label", g)).to_lower())
		_say("%s: the %s went off. Throw it out." % [_place_name(kind), ", ".join(names)], 1, "biz_off:" + str(key))


## Who of a place's hands does not come in today (a note on the door). The two nobody
## remembers are never away.
func _attendance(key: String, day: int) -> void:
	var s := site(key)
	for p in s.get("crew", []):
		if str(p.get("strange", "")) != "":
			continue
		var h := absi(hash("%s|%s|%d" % [key, str(p.get("slug", "")), day])) % 1000
		var chance := 50 + (40 if str(p.get("temper", "")) == "sour" else 0) + (30 if int(p.get("speed", 1)) == 0 else 0)
		if h < chance:
			CoreRoot.actions.biz_crew_note(key, str(p.get("slug", "")), {"absent": day})
			_say("%s did not come in to the %s today. A note on the door." % [str(p.get("name", "A hand")), _place_name(str(s.get("kind", ""))).to_lower()], 1)


## A dishonest hand who worked yesterday helps themselves now and then: money from the
## till or something off the shelf. Never said; the books show it short.
func _thieves(key: String, day: int) -> void:
	var s := site(key)
	for p in s.get("crew", []):
		if bool(p.get("honest", true)) or int(p.get("absent", -1)) == day:
			continue
		var h := absi(hash("%s|%s|t%d" % [key, str(p.get("slug", "")), day]))
		if h % 2 != 0:
			continue
		if (h / 2) % 2 == 0:
			CoreRoot.actions.biz_short(key, 2 + (h / 4) % 5)
		else:
			var goods: Array = []
			for g in (s.get("stock", {}) as Dictionary):
				if int(s["stock"][g]) >= 2:
					goods.append(g)
			if not goods.is_empty():
				CoreRoot.actions.biz_short(key, 0, str(goods[(h / 4) % goods.size()]), 1 + (h / 8) % 2)


## The one who has worked here before washes up in the night when the place was shut
## (nobody had a key); the morning finds it done.
func _night_hand(key: String) -> void:
	var s := site(key)
	if bool(s.get("late", false)):
		return
	for p in s.get("crew", []):
		if str(p.get("strange", "")) != "night":
			continue
		var did := false
		if str(s.get("kind", "")) == "rest":
			var k = get_tree().get_first_node_in_group("kitchens")
			if k != null:
				var pl: Dictionary = k.plates(key)
				if int(pl["dirty"]) > 0:
					k.act(key, "plates", [int(pl["dirty"]), -int(pl["dirty"])])
					did = true
		if not (s.get("spoiled", {}) as Dictionary).is_empty():
			# Thrown out, and not in the books as waste.
			s["spoiled"] = {}
			did = true
		if did:
			_say("Somebody washed up at the %s overnight. Nobody had a key." % _place_name(str(s.get("kind", ""))).to_lower(), 0)
		return


# ── the shift ────────────────────────────────────────────────────────────────

## The shift a place is on now: "day" (7 to 20), "late" (20 to 23 when it is open late) or
## "closed".
static func shift_now(s: Dictionary) -> String:
	var h := int(GuestManager._last_known_hour) if GuestManager != null else 12
	if h >= OPEN_HOUR and h < RULES.DAY_CLOSE:
		return "day"
	if h >= RULES.DAY_CLOSE and h < RULES.LATE_CLOSE and bool(s.get("late", false)):
		return "late"
	return "closed"


## A place shutting (the day shift over with no late one, or the late one over): its Z
## report, and who of the hands worked today is owed for it tonight.
func _watch_shifts(sites: Dictionary) -> void:
	for key in sites:
		var s := site(key)
		if s.is_empty():
			continue
		var now := shift_now(s)
		var was := str(_shift_was.get(key, now))
		_shift_was[key] = now
		_watch_last_call(key, s)
		if now == "closed" and _closing.has(key):
			# Shut, but who ordered before last orders is still waiting: the Z report when
			# the last of them is served or gone (an hour and a half at most).
			var c: Dictionary = _closing[key]
			if open_orders(key) > 0 and _abs_now() - int(c["at"]) < 90:
				continue
			_closing.erase(key)
			was = str(c["was"])
		elif now == was or now != "closed":
			continue
		elif open_orders(key) > 0:
			_closing[key] = {"was": was, "at": _abs_now()}
			continue
		var wages := 0
		for p in s.get("crew", []):
			if int(p.get("absent", -1)) != CoreRoot.get_day():
				wages += RULES.shift_pay(p)
		var z: Dictionary = CoreRoot.actions.biz_close_shift(key, wages, CoreRoot.get_day(), was == "late")
		if int(z.get("orders", 0)) > 0 or int(z.get("takings", 0)) > 0:
			_say("%s shut for the day. The Z report is in the books." % _place_name(str(s.get("kind", ""))), 0, "biz_z:" + str(key))
			zreport.emit(key, z)


## Places shut whose last orders are still being served: key -> {was (the shift that
## ended), at (the game minute it shut)}; places whose last orders were called today.
var _closing: Dictionary = {}
var _called: Dictionary = {}


## Last orders (the brief of 21. 10.): the bell and a line in the feed when the time comes;
## the frame at a station rings its own bell (station_hud).
func _watch_last_call(key: String, s: Dictionary) -> void:
	var day := CoreRoot.get_day()
	var left := to_last_orders(key)
	if left > 0 or left < -30 or int(_called.get(key, -1)) == day or shift_now(s) == "closed":
		return
	_called[key] = day
	last_call.emit(key)
	_say("%s: last orders. Who has ordered still gets served." % _place_name(str(s.get("kind", ""))), 0, "biz_last:" + str(key))


static func _abs_now() -> int:
	if GuestManager == null:
		return 0
	return int(GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute))


## The minute of the day now (the game's clock).
static func minute_now() -> int:
	if GuestManager == null:
		return 12 * 60
	return int(GuestManager._last_known_hour) * 60 + int(GuestManager._last_known_minute)


## Whether a place takes an order put up at absolute game minute `abs_min`: from the
## day's opening to last orders (the late shift's when it is open late).
static func takes_orders_at(key: String, abs_min: int) -> bool:
	var s := site(key)
	if s.is_empty():
		return true
	var mod := posmod(abs_min, 1440)
	return mod >= OPEN_HOUR * 60 and mod < RULES.last_orders_at(bool(s.get("late", false)))


## Game minutes to last orders now (0 or less: past them).
static func to_last_orders(key: String) -> int:
	return RULES.last_orders_at(bool(site(key).get("late", false))) - minute_now()


## The orders open at a place now (its tickets on the rail), whoever's they are.
func open_orders(key: String) -> int:
	var node: Node = null
	match str(site(key).get("kind", "")):
		"rest":
			node = get_tree().get_first_node_in_group("kitchens")
		"pub":
			node = get_tree().get_first_node_in_group("taprooms")
		"corn":
			node = get_tree().get_first_node_in_group("cornstands")
		"vecerka":
			node = get_tree().get_first_node_in_group("jednotas")
	if node == null or not node.has_method("tickets"):
		return 0
	return (node.call("tickets", key) as Array).size()


## A run of good orders at a place (Papa's combo, this machine's): key -> how many in a
## row went out with three stars. A poor one or one sent back ends it.
static var _combo: Dictionary = {}


static func note_order(key: String, stars: int, ok: bool) -> int:
	var c := int(_combo.get(key, 0))
	c = c + 1 if ok and stars >= 3 else 0
	_combo[key] = c
	return c


static func combo(key: String) -> int:
	return int(_combo.get(key, 0))


## The places open late tonight: the guests may go out to them in the evening
## (guest_life.late_keys), and the forecast says so (the HUD's NIGHT RISK footer, a line
## in the feed in the afternoon).
var _late_told := -1


func _watch_late(sites: Dictionary) -> void:
	var keys: Array = []
	var names: Array = []
	for key in sites:
		var s := site(key)
		if bool(s.get("late", false)):
			keys.append(str(key))
			var n := _place_name(str(s.get("kind", ""))).to_upper()
			if not names.has(n):
				names.append(n)
	var life = GuestManager.get("_life") if GuestManager != null else null
	if life != null and "late_keys" in life:
		life.late_keys = keys
	if life != null and "order_hours" in life:
		var hours := {}
		for key in sites:
			hours[str(key)] = [OPEN_HOUR * 60, RULES.last_orders_at(bool(site(key).get("late", false)))]
		life.order_hours = hours
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	var h := int(GuestManager._last_known_hour) if GuestManager != null else 12
	if hud != null and hud.has_method("set_open_late"):
		hud.set_open_late(str(names[0]) if not names.is_empty() and h >= 14 and h < RULES.LATE_CLOSE else "")
	if not names.is_empty() and h >= 17 and _late_told != CoreRoot.get_day():
		_late_told = CoreRoot.get_day()
		_say("Open late tonight: %s. The night will come into it." % ", ".join(names).to_lower(), 1, "biz_late")


## What a guest pays, more in the evening (the late shift's prices).
static func price_k(key: String) -> float:
	return 1.25 if shift_now(site(key)) == "late" else 1.0


## Who of a place's hands is working now (on this shift, came in today): the crew records.
static func crew_now(key: String) -> Array:
	var s := site(key)
	var out: Array = []
	if s.is_empty():
		return out
	var now := shift_now(s)
	if now == "closed":
		return out
	var day := CoreRoot.get_day() if CoreRoot != null else 0
	for p in s.get("crew", []):
		if str(p.get("shift", "day")) == now and int(p.get("absent", -1)) != day:
			out.append(p)
	return out


## What the hand at `role` (on now) does to the mood of a guest they serve (the brief of
## 20. 10.: "a sour one is cheaper and worse"): a warm one cheers them a little, a sour
## one puts them off; nobody there, 0.
static func hand_mood(key: String, role: String) -> float:
	for p in crew_now(key):
		if str(p.get("role", "")) == role:
			return float(RULES.TEMPER_MOOD.get(str(p.get("temper", "flat")), 0.0))
	return 0.0


## The front job covered now (the place serves without you): the books say so.
func _watch_crew(sites: Dictionary) -> void:
	for key in sites:
		var s := site(key)
		if s.is_empty():
			continue
		var front := RULES.front(str(s.get("kind", "")))
		var who := ""
		for p in crew_now(key):
			if str(p.get("role", "")) == front:
				who = str(p.get("name", ""))
				break
		if (who != "") != bool(s.get("staff", false)) or who != str(s.get("staff_name", "")):
			CoreRoot.actions.biz_staffed(key, who != "", who)


static func has_gear(key: String, id: String) -> bool:
	return RULES.has_gear(site(key), id)


## The camp's own dice for its people (their ways are the same every time in a camp).
static func camp_seed() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var main: Node = tree.current_scene if tree != null else null
	var wg = main.get("world_generator") if main != null else null
	if wg != null and wg.get("world_seed") != null:
		return int(wg.world_seed)
	return 0


## Those asking for work at `key` today (the books' STAFF page, the PC's).
static func applicants(key: String) -> Array:
	var s := site(key)
	if s.is_empty():
		return []
	var taken: Array = []
	for p in s.get("crew", []):
		taken.append(str(p.get("slug", "")))
	# Nobody asks at two places at once: whoever works anywhere in the camp is not asking.
	if CoreRoot != null and CoreRoot.get_state() != null:
		for k in CoreRoot.get_state().biz.get("sites", {}):
			for p in CoreRoot.get_state().biz["sites"][k].get("crew", []):
				taken.append(str(p.get("slug", "")))
	return RULES.applicants(str(s["kind"]), key, CoreRoot.get_day(), taken, camp_seed())


## The photo of a person (os98/photos/<slug>.png); the one whose face will not hold still
## has a different one every other day.
static func photo_of(slug: String) -> String:
	if slug == "marta" and CoreRoot != null:
		var v := (CoreRoot.get_day() / 2) % 3
		return "marta" if v == 0 else "marta%d" % (v + 1)
	return slug


# ── the guests ───────────────────────────────────────────────────────────────

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
			var s: Dictionary = CoreRoot.get_state().biz["sites"].get(key, {})
			# The bistro's hands work its kitchen ticket by ticket (kitchen.gd), the pub's
			# pour at its bar order by order (taproom.gd), the stand's husk and boil
			# (cornstand.gd), the Jednota's stock its rack and ring its till (jednota.gd).
			if bool(s.get("staff", false)) and not (kind in ["rest", "pub", "corn", "vecerka"]):
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
			return "%s %s sitting in the bistro. Nobody in the kitchen." % [who, verb]
		"vecerka":
			return "%s %s at the Jednota till. Nobody there." % [who, verb]
		"corn":
			return "%s %s waiting at the corn stand." % [who, verb]
	return "%s %s waiting to be served." % [who, verb]


func _place_name(kind: String) -> String:
	return str((RULES.KINDS.get(kind, {}) as Dictionary).get("name", "Business"))


## HUD rows for the guests waiting to be served: [{title, where}].
func hud_rows() -> Array:
	var rows: Array = []
	for s in waiting_sites():
		var cook := str(site(str(s["key"])).get("kind", "")) == "rest"
		rows.append({"title": "%s: %d waiting for %s" % [s["title"], int(s["n"]), "their food" if cook else "an order"], "where": "cook for them in the kitchen" if cook else "serve them at the counter"})
	return rows


## Where somebody waits to be served (the HUD's list, the paper site plan's circles):
## [{key, coord: [x, y], title, n}].
func waiting_sites() -> Array:
	var out: Array = []
	for key in _waiting:
		var n := (_waiting[key] as Array).size()
		var parts := str(key).split(":")
		if n <= 0 or parts.size() < 2:
			continue
		var kind := str(site(key).get("kind", ""))
		out.append({"key": str(key), "coord": [int(parts[0]), int(parts[1])], "n": n,
			"title": _place_name(kind)})
	return out


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


## What the hands do between customers: the barman washes up (the old washer's mugs).
func _hands_work() -> void:
	for key in CoreRoot.get_state().biz["sites"]:
		var s: Dictionary = CoreRoot.get_state().biz["sites"][key]
		if not bool(s.get("staff", false)):
			continue
		if s.has("glasses"):
			s["glasses"]["clean"] = int(s["glasses"]["clean"]) + int(s["glasses"]["dirty"])
			s["glasses"]["dirty"] = 0


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
	CoreRoot.actions.biz_sale(key, int(round(RULES.basket_price(kind, b) * price_k(key))), units, false)
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
	var s: Dictionary = (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).get(key, {})
	if s.is_empty():
		return -1
	return int(s["stock"].get(good, 0))


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


# ── debug (tools/staff_check.gd, the shot scenes) ────────────────────────────

## Takes `slug` on at `key` for `role` and `shift` (as the books would).
func debug_hire(key: String, slug: String, role := "", shift := "day") -> bool:
	var s := site(key)
	if s.is_empty():
		return false
	var p := RULES.person(slug, str(s["kind"]), camp_seed())
	if role != "":
		p["role"] = role
	p["shift"] = shift
	return CoreRoot.actions.biz_hire(key, p, CoreRoot.get_day())
