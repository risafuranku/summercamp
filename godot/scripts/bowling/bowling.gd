extends Node

## The camp's bowling alleys while the game runs (the user 21. 10.: real ten-pin in the
## concrete hall with KUŽELKY on the roof): one node for the game (of()), a record per
## alley ("x:y" key) of what goes on in it, so it goes on whether you are inside or not;
## the hall (scripts/bowling/bowling_interior.gd, its lanes scripts/bowling/lane.gd, its
## stations desk_station.gd and pit_station.gd) only shows it and works it:
##   desk     the parties at the counter waiting for their shoes and a lane, in the order
##            they came in: [{visit, at (seconds on this node's clock), sizes: [shoe
##            sizes, one a head]}]; who gave up waiting and left: `gone`
##   checked  visit -> {lane (-1: waiting at a table for one), sizes (the pairs they got)}
##   lanes    four: {visit, name, members: [{name, skill, balls: [], last}], turn,
##            standing (ten bools), set ("" the pins are up, "sweep" the deadwood off,
##            "rack" all ten: waiting for the pinsetter), ready (when the next ball can go
##            once the pins are up), wait (seconds the pins have waited; minus while the
##            ball is still on its way and the pins falling), seq (balls bowled: the hall
##            plays each new one), last {member, entry, res, seed, before}}
##   shoes    the shelf: {size: pairs}; `back`: the pairs handed back, waiting to be
##            sprayed and shelved ([size])
##   machine  the pinsetting machine's jam: {jam ("" running, else what is caught in its
##            gears), since, lane}
##   bufet    the snack bar's orders from the lanes, oldest first: [{id, visit, lane, name,
##            guest, items: ["beer", "hotdog"...], at}] (bufet_station.gd makes them up; a
##            lane's record keeps what it was brought, `snacks`, for the bench)
## Money: a game and a pair of shoes a head, paid at the counter (actions.biz_sale). Who
## sets the pins: by hand, the pinsetter (a hand with the job "pins" on shift), else you in
## the pit (pit_station.gd: the deadwood off, the pins on their spots, the ball back);
## nobody, the lane waits and its party grumbles. With the machine from the books (the user,
## 21. 10.: "a machine you buy in the books that now and then needs mending: gears in the
## cellar, eerie and morbidly creepy; then a fake Brunswick that runs like clockwork"): the
## Stavomat S-12 sets every lane by itself and now and then something gets caught in its
## gears and every lane stands until it is freed in the cellar (cellar_station.gd; a hand
## on "pins" goes down and does it slowly); the Brnoswick A-2 is quicker and never jams.
## A warden can bowl too (the user, 21. 10.: "the player plays a game of bowling"): a free
## lane taken (`take_lane`: its visit "w:<who>"), nobody bowls it for them; their balls come
## from bowling_interior.gd's swing, worked out where they were thrown and sent as an op
## (`warden_ball`), the pins set by themselves after a moment (or by the machine).
## The snack bar: now and then a party on its lane wants something (KINDS["bowl"] wants:
## a beer, a Kofola, a hot dog...), of what is on the menu and on the shelf; made up at the
## bar and taken over, paid with the goods off the books (BUSINESS.sell); left too long they
## give up on it and grumble. A hand on "bufet" does it for you.
## Stepped on its own clock in seconds, like the hall's animations it schedules for.
## Co-op: the host simulates (the balls, the hands, the machine, who gives up); what a
## warden does at a station is an op (`act`: checkin, set, shelve, unjam) applied at once and
## sent to everyone (Coop.send_place "bowl"); after a change the host sends the alley as it
## stands ("snap").

const RULES := preload("res://core/systems/bowling_rules.gd")
const BIZ_RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const LANES := 4
## What the counter takes: a game on a lane a head, the shoes a pair.
const GAME_PRICE := 3
const SHOES_PRICE := 1
## Seconds: a ball from the bench to the pins falling (the hall's walk, hold and fall; the
## roll is the ball's own share), and between a party's balls once the pins are up.
const BALL_SEC := 3.2
const ROLL_SHARE := 0.62
const PAUSE_SEC := Vector2(1.0, 2.2)
## The counter's patience (seconds waiting): calm, getting cross, gone.
const DESK_OK := 25.0
const DESK_LATE := 45.0
const DESK_GONE := 75.0
## The pins' patience (seconds a lane has waited for them).
const PINS_OK := 8.0
const PINS_LATE := 16.0
const PINS_GONE := 28.0
## The shoe shelf: the sizes and how many pairs of each a new alley has.
const SIZES := [34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]
const PAIRS_EACH := 2
## A hand on the counter sprays and shelves a pair handed back in this many seconds.
const SHELVE_SEC := 4.0
const SKILL := {"drunk": 0.25, "tramp": 0.35, "quiet_guy": 0.6, "cheap_chick": 0.4, "picker": 0.5, "family": 0.3}
## The machines: how long after the pins are down a lane's are set again, how long its own
## cycle takes in the hall (the next ball waits for it), the Stavomat's chance of jamming
## on a set and what gets caught in its gears (by how often).
const MACHINE_SEC := 3.0
const BRNOSWICK_SEC := 1.6
const CYCLE_SEC := {"machine": 2.1, "brnoswick": 1.4}
const MACHINE_JAM := 0.035
const JAMS := {"pin": 30, "rag": 25, "shoe": 20, "hair": 15, "rat": 10}
## A warden's lane: its pins set by themselves this long after they fell (no machine).
const WARDEN_SET_SEC := 2.0
## A ball thrown by a warden: the pins are down this long after the roll (no walk up).
const QUICK_SEC := 1.6
## A hand on "pins" frees a jam in this many seconds, by their speed.
const FIX_SEC := [42.0, 30.0, 20.0]
## The snack bar: how long a party on its lane goes between orders (seconds, about), the
## bar's patience, what an order can have (the menu's items) and which good each is sold by.
const BUFET_EVERY := Vector2(50.0, 120.0)
const BUFET_OK := 20.0
const BUFET_LATE := 40.0
const BUFET_GONE := 70.0
const BUFET_ITEMS := ["beer", "kofola", "hotdog", "crisps", "pickled", "tatranka"]
const BUFET_GOOD := {"hotdog": "sausage"}
## The goods' wants (KINDS) as the menu's items.
const WANT_ITEM := {"sausage": "hotdog"}
## The others of a party on the board (the first is the guest's own name): a family's by
## their place in it (the father, the boy, the mother, a girl), anyone else's friends.
const FAMILY_NAMES := [["Dad", "Kuba", "Mum", "Terka"], ["Dad", "Péťa", "Mum", "Áďa"]]
const FRIENDS := ["Franta", "Jarda", "Mirek", "Honza", "Věra", "Hanka", "Lenka", "Zdeněk", "Karel", "Míla"]

## A record changed (key, what: "desk", "shoes", "lane<i>", "snap").
signal changed(key: String, what: String)

var _sites: Dictionary = {}
var _clock := 0.0
var _acc := 0.0
var _hand_busy: Dictionary = {}     # key -> {role: seconds left on the current job}
var _dirty: Dictionary = {}
var _asked_snap := false
var _state_id := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Bowlings"
	add_to_group("bowlings")
	# Coop.send_place("bowl", ...) finds it here.
	add_to_group("places_bowl")
	_rng.randomize()


## The game's bowling node, made under the businesses (or the root) when first asked for.
static func of(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var b := tree.get_first_node_in_group("bowlings")
	if b != null:
		return b
	var n: Node = load("res://scripts/bowling/bowling.gd").new()
	var biz := tree.get_first_node_in_group("businesses")
	(biz if biz != null else tree.root).add_child(n)
	return n


func site(key: String) -> Dictionary:
	if not _sites.has(key):
		_sites[key] = _fresh()
	return _sites[key]


func _fresh() -> Dictionary:
	var lanes: Array = []
	for i in LANES:
		lanes.append(_empty_lane())
	var shelf := {}
	for s in SIZES:
		shelf[s] = PAIRS_EACH
	return {"desk": [], "gone": {}, "checked": {}, "lanes": lanes, "grumbled": {}, "shoes": shelf, "back": [],
		"machine": {"jam": "", "since": 0.0, "lane": -1}, "bufet": [], "next_order": {}, "order_n": 0}


func _empty_lane() -> Dictionary:
	return {"visit": "", "name": "", "members": [], "turn": 0, "standing": RULES._all_up(), "set": "", "ready": 0.0,
		"wait": 0.0, "seq": 0, "last": {}, "snacks": []}


func now() -> float:
	return _clock


func _touch(key: String, what: String) -> void:
	_dirty[key] = true
	changed.emit(key, what)


func _process(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc < 0.25:
		return
	var dt := _acc
	_acc = 0.0
	var st = CoreRoot.get_state() if CoreRoot != null else null
	# A new camp (the books' stamp changes with it): the alleys start afresh.
	var sid: int = (st.get_instance_id() + int((st.biz as Dictionary).get("stamp", 0))) if st != null and st.biz is Dictionary else 0
	if sid != _state_id:
		_state_id = sid
		_sites.clear()
		_hand_busy.clear()
		_asked_snap = false
	if Coop.is_client():
		if not _asked_snap and Coop.has_method("send_place"):
			_asked_snap = true
			Coop.send_place("bowl", "", "hello", [])
		# The pins' wait goes on here too (the host's snap puts it right).
		for key in _sites:
			for lane in site(str(key))["lanes"]:
				if str(lane["set"]) != "":
					lane["wait"] = float(lane["wait"]) + dt
		return
	for key in _bowling_keys():
		_tick(key, dt)
	if Coop.is_active() and Coop.has_method("send_place"):
		for key in _dirty:
			Coop.send_place("bowl", str(key), "snap", [_snapshot(str(key))])
	_dirty.clear()


## The camp's bowling alleys (their keys).
func _bowling_keys() -> Array:
	var out: Array = []
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or state.grid == null:
		return out
	for c in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[c]
		if str(cell.get("type", "")) == "bowling" and cell.get("root_coord", c) == c:
			out.append("%d:%d" % [c.x, c.y])
	return out


func _tick(key: String, dt: float) -> void:
	var s := site(key)
	_watch_visitors(key, s)
	_hands(key, s, dt)
	_machine(key, s)
	_bufet(key, s)
	for i in LANES:
		_tick_lane(key, s, i, dt)


# ── the ops (every machine) ──────────────────────────────────────────────────

## A change made here, applied at once and sent to the other machines:
##   checkin [visit, lane, pairs, name, archetype, figures]   the party has its shoes
##   set [lane, machine]            the pins of the lane are up again (by the machine:
##                                  its cycle in the hall before the next ball)
##   shelve [index]                 a pair handed back went back on its shelf
##   unjam []                       the machine was freed in the cellar
##   jam [what, lane]               the machine jammed (the host's)
##   bufet_done [id, items]         a snack bar order taken over (what was on the tray)
##   wtake [lane, who, name]        a warden took a free lane to bowl
##   wleave [lane, who]             and left it
##   wball [lane, entry, res, seed] their ball (worked out where it was thrown)
func act(key: String, op: String, args: Array) -> void:
	_apply(key, op, args)
	if Coop.is_active() and Coop.has_method("send_place"):
		Coop.send_place("bowl", key, op, args)


func _apply(key: String, op: String, args: Array) -> void:
	var s := site(key)
	match op:
		"checkin":
			var visit := str(args[0])
			var at := _in_desk(s, visit)
			if at >= 0:
				(s["desk"] as Array).remove_at(at)
			var pairs: Array = (args[2] as Array).duplicate()
			if not s["checked"].has(visit):
				for p in pairs:
					s["shoes"][int(p)] = maxi(0, int(s["shoes"].get(int(p), 0)) - 1)
			s["checked"][visit] = {"lane": -1, "sizes": pairs}
			var li := int(args[1])
			if li < 0 or li >= LANES or str(s["lanes"][li]["visit"]) != "":
				li = free_lane(key)
			if li >= 0:
				_seat_party(key, s, visit, {"name": str(args[3]), "archetype": str(args[4]), "figures": int(args[5])}, li)
			_touch(key, "desk")
		"set":
			_put_up(key, s, int(args[0]), str(args[1]) if args.size() > 1 else "")
		"jam":
			s["machine"] = {"jam": str(args[0]), "since": _clock, "lane": int(args[1])}
			_touch(key, "machine")
		"wtake":
			var li := int(args[0])
			if li >= 0 and li < LANES and str(s["lanes"][li]["visit"]) == "":
				var lane := _empty_lane()
				lane["visit"] = "w:" + str(args[1])
				lane["name"] = str(args[2])
				lane["members"] = [{"name": str(args[2]), "skill": 0.0, "balls": [], "last": -1}]
				lane["ready"] = _clock
				s["lanes"][li] = lane
				_touch(key, "lane%d" % li)
		"wleave":
			var li2 := int(args[0])
			if li2 >= 0 and li2 < LANES and str(s["lanes"][li2]["visit"]) == "w:" + str(args[1]):
				s["lanes"][li2] = _empty_lane()
				_touch(key, "lane%d" % li2)
		"wball":
			var li3 := int(args[0])
			if li3 >= 0 and li3 < LANES and is_warden_lane(s["lanes"][li3]) and str(s["lanes"][li3]["set"]) == "":
				_record_ball(key, s, li3, 0, args[1], args[2], int(args[3]), true)
		"bufet_done":
			var orders: Array = s["bufet"]
			for i in range(orders.size() - 1, -1, -1):
				var o: Dictionary = orders[i]
				if str(o["id"]) != str(args[0]):
					continue
				orders.remove_at(i)
				var li := int(o.get("lane", -1))
				if li >= 0 and li < LANES and str(s["lanes"][li]["visit"]) == str(o["visit"]):
					var sn: Array = (s["lanes"][li].get("snacks", []) as Array) + (args[1] as Array)
					s["lanes"][li]["snacks"] = sn.slice(maxi(0, sn.size() - 4))
					_touch(key, "lane%d" % li)
			_touch(key, "bufet")
		"unjam":
			if str(s["machine"].get("jam", "")) != "":
				s["machine"] = {"jam": "", "since": _clock, "lane": -1}
				_touch(key, "machine")
		"shelve":
			var back: Array = s["back"]
			if not back.is_empty():
				var idx := clampi(int(args[0]), 0, back.size() - 1)
				var size := int(back[idx])
				back.remove_at(idx)
				s["shoes"][size] = int(s["shoes"].get(size, 0)) + 1
				_touch(key, "shoes")
		"snap":
			var got: Dictionary = args[0]
			_clock = maxf(_clock, float(got.get("now", _clock)))
			for k in ["desk", "gone", "checked", "lanes", "shoes", "back", "machine", "bufet"]:
				if got.has(k):
					s[k] = got[k].duplicate(true)
			changed.emit(key, "snap")


## From another machine (Coop.send_place "bowl").
func coop_place(key: String, op: String, args: Array) -> void:
	if op == "hello":
		if Coop.is_host():
			for k in _sites:
				Coop.send_place("bowl", str(k), "snap", [_snapshot(str(k))])
		return
	_apply(key, op, args)


func _snapshot(key: String) -> Dictionary:
	var s := site(key)
	return {"now": _clock, "desk": s["desk"], "gone": s["gone"], "checked": s["checked"], "lanes": s["lanes"], "shoes": s["shoes"], "back": s["back"],
		"machine": s["machine"], "bufet": s["bufet"]}


# ── the counter ──────────────────────────────────────────────────────────────

## New visitors queue at the counter; one whose patience ran out goes; those whose visit
## is over leave their lane and hand their shoes back.
func _watch_visitors(key: String, s: Dictionary) -> void:
	var here := {}
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		here[visit] = v
		if s["checked"].has(visit) or s["gone"].has(visit) or _in_desk(s, visit) >= 0:
			continue
		(s["desk"] as Array).append({"visit": visit, "at": _clock, "sizes": _sizes_for(v)})
		_touch(key, "desk")
	for i in range((s["desk"] as Array).size() - 1, -1, -1):
		var d: Dictionary = s["desk"][i]
		var visit := str(d["visit"])
		if not here.has(visit):
			(s["desk"] as Array).remove_at(i)
			_touch(key, "desk")
		elif _clock - float(d["at"]) > DESK_GONE:
			(s["desk"] as Array).remove_at(i)
			s["gone"][visit] = true
			ORDERS.mood(int((here[visit] as Dictionary).get("id", 0)), -6.0, "Stood at the bowling counter. Nobody came.")
			_touch(key, "desk")
	for visit in s["gone"].keys():
		if not here.has(visit):
			s["gone"].erase(visit)
	for visit in s["checked"].keys():
		if here.has(visit):
			continue
		var c: Dictionary = s["checked"][visit]
		s["checked"].erase(visit)
		# The shoes come back over the counter.
		for size in c.get("sizes", []):
			(s["back"] as Array).append(int(size))
		var li := int(c.get("lane", -1))
		if li >= 0 and str(s["lanes"][li]["visit"]) == visit:
			s["lanes"][li] = _empty_lane()
			_touch(key, "lane%d" % li)
		_touch(key, "shoes")
	# Lanes free: to whoever has waited longest after checking in.
	for visit in s["checked"].keys():
		if int(s["checked"][visit].get("lane", -1)) >= 0:
			continue
		var li := free_lane(key)
		if li < 0:
			break
		_seat_party(key, s, visit, here.get(visit, {}), li)


func _in_desk(s: Dictionary, visit: String) -> int:
	for i in (s["desk"] as Array).size():
		if str(s["desk"][i]["visit"]) == visit:
			return i
	return -1


## A shoe size a head of a party (the same for the same visit on every machine): a family
## figure is a father and his boy.
func _sizes_for(v: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(v.get("visit", ""))) ^ 0x5F3
	var out: Array = []
	var arch := str(v.get("archetype", ""))
	var n := maxi(1, int(v.get("figures", 1)))
	for k in n:
		match arch:
			"family":
				out.append(rng.randi_range(41, 46) if k % 2 == 0 else rng.randi_range(34, 37))
			"cheap_chick":
				out.append(rng.randi_range(37, 40))
			"picker":
				out.append(rng.randi_range(37, 43))
			_:
				out.append(rng.randi_range(40, 46))
	return out


func free_lane(key: String) -> int:
	var s := site(key)
	for i in LANES:
		if str(s["lanes"][i]["visit"]) == "":
			return i
	return -1


## The counter's orders, oldest first: {id (the visit), name, archetype, figures, sizes,
## age (seconds), left, band, guest} for the frame's rail.
func desk_tickets(key: String) -> Array:
	var s := site(key)
	var by := {}
	for v in ORDERS.visitors(key):
		by[str(v["visit"])] = v
	var out: Array = []
	for d in s["desk"]:
		var v: Dictionary = by.get(str(d["visit"]), {})
		if v.is_empty():
			continue
		var age := _clock - float(d["at"])
		var band := 0 if age < DESK_OK else (1 if age < DESK_LATE else 2)
		out.append({"id": str(d["visit"]), "visit": str(d["visit"]), "name": str(v.get("name", "Guest")), "archetype": str(v.get("archetype", "")),
			"figures": int(v.get("figures", 1)), "sizes": (d["sizes"] as Array).duplicate(), "age": age,
			"left": 1.0 - clampf(age / DESK_GONE, 0.0, 1.0), "band": band, "guest": int(v.get("id", 0))})
	return out


## The party is given its shoes (`pairs`: the sizes handed over, one a head; none: a hand
## takes the nearest off the shelf) and lane `li` (-1: the first free), and pays: by you
## at the counter, or by the hand on it. Returns {amount, heads, wrong (pairs not their
## size), lane, guest} or {} when it could not be done.
func check_in(key: String, visit: String, by_hand: bool, li := -1, pairs: Array = []) -> Dictionary:
	var s := site(key)
	var at := _in_desk(s, visit)
	if at < 0:
		return {}
	var v: Dictionary = {}
	for x in ORDERS.visitors(key):
		if str(x["visit"]) == visit:
			v = x
	if v.is_empty():
		return {}
	var sizes: Array = s["desk"][at]["sizes"]
	if pairs.is_empty():
		pairs = _pairs_from_shelf(s, sizes)
	var wrong := 0
	for k in sizes.size():
		if k >= pairs.size() or int(pairs[k]) != int(sizes[k]):
			wrong += 1
	var heads := sizes.size()
	var amount := int(round(float(heads * (GAME_PRICE + SHOES_PRICE)) * BUSINESS.price_k(key)))
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_site(key, "bowling")
		CoreRoot.actions.biz_sale(key, amount, heads, by_hand)
	ORDERS.note_served(v)
	if BUSINESS.has_gear(key, "scoreboard"):
		ORDERS.mood(int(v.get("id", 0)), 2.0, "The scores up on screens over the lanes, like abroad.")
	if li < 0 or li >= LANES or str(s["lanes"][li]["visit"]) != "":
		li = free_lane(key)
	act(key, "checkin", [visit, li, pairs, str(v.get("name", "Guest")), str(v.get("archetype", "")), int(v.get("figures", 1))])
	return {"amount": amount, "heads": heads, "wrong": wrong, "lane": li, "guest": int(v.get("id", 0)), "name": str(v.get("name", ""))}


## The nearest size there is on the shelf for each head (the hand's pick; the shelf
## itself loses them when the check-in is applied).
func _pairs_from_shelf(s: Dictionary, sizes: Array) -> Array:
	var left: Dictionary = (s["shoes"] as Dictionary).duplicate()
	var out: Array = []
	for want in sizes:
		var best := int(want)
		for d in [0, 1, -1, 2, -2, 3, -3]:
			var size: int = int(want) + int(d)
			if int(left.get(size, 0)) > 0:
				best = size
				break
		left[best] = maxi(0, int(left.get(best, 0)) - 1)
		out.append(best)
	return out


## The shelf (size -> pairs) and the pairs handed back waiting.
func shelf(key: String) -> Dictionary:
	return site(key)["shoes"]


func returned(key: String) -> Array:
	return site(key)["back"]


## A pair handed back is sprayed (dried, with the shoe dryer) and goes back on its shelf.
## Returns its size (-1 nothing there).
func shelve_returned(key: String, idx := 0) -> int:
	var back: Array = site(key)["back"]
	if back.is_empty():
		return -1
	idx = clampi(idx, 0, back.size() - 1)
	var size := int(back[idx])
	if CoreRoot != null and CoreRoot.actions != null and not BUSINESS.has_gear(key, "dryer"):
		CoreRoot.actions.biz_take(key, {"spray": 1})
	act(key, "shelve", [idx])
	return size


func _seat_party(key: String, s: Dictionary, visit: String, v: Dictionary, li: int) -> void:
	if not s["checked"].has(visit):
		return
	s["checked"][visit]["lane"] = li
	var arch := str(v.get("archetype", ""))
	var full := str(v.get("name", "Guest"))
	var n: int = maxi(1, int(v.get("figures", 1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(visit)
	var members: Array = []
	var first := full.split(" ")[0]
	var names: Array = FAMILY_NAMES[absi(hash(visit)) % FAMILY_NAMES.size()] if arch == "family" else []
	for k in n:
		var nm := first
		if arch == "family":
			nm = str(names[k % names.size()])
		elif k > 0:
			nm = str(FRIENDS[(absi(hash(visit)) + k * 3) % FRIENDS.size()])
		members.append({"name": nm, "skill": clampf(float(SKILL.get(arch, 0.4)) + rng.randf_range(-0.15, 0.15), 0.05, 0.95), "balls": [], "last": -1})
	var lane := _empty_lane()
	lane["visit"] = visit
	lane["name"] = full
	lane["members"] = members
	lane["ready"] = _clock + 5.0
	s["lanes"][li] = lane
	_touch(key, "lane%d" % li)


# ── the lanes ────────────────────────────────────────────────────────────────

func _tick_lane(key: String, s: Dictionary, i: int, dt: float) -> void:
	var lane: Dictionary = s["lanes"][i]
	if str(lane["visit"]) == "":
		return
	if is_warden_lane(lane):
		# Nobody bowls it for them; its pins stand again by themselves (or by the machine).
		if str(lane["set"]) != "":
			lane["wait"] = float(lane["wait"]) + dt
			if machine_of(key) == "" and float(lane["wait"]) >= WARDEN_SET_SEC:
				set_pins(key, i)
		return
	if str(lane["set"]) != "":
		lane["wait"] = float(lane["wait"]) + dt
		if float(lane["wait"]) > PINS_GONE and not s["grumbled"].has(str(lane["visit"])):
			s["grumbled"][str(lane["visit"])] = true
			_grumble(key, lane)
		return
	if _clock < float(lane["ready"]):
		return
	_bowl(key, s, i)


## The next ball on lane `i`: who bowls, where it goes, what it takes.
func _bowl(key: String, s: Dictionary, i: int) -> void:
	var lane: Dictionary = s["lanes"][i]
	var members: Array = lane["members"]
	var mi := int(lane["turn"]) % members.size()
	var m: Dictionary = members[mi]
	var seed := hash("%s/%d" % [str(lane["visit"]), int(lane["seq"])])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var b := RULES.guest_ball(float(m["skill"]), lane["standing"], rng)
	var entry: Dictionary
	if bool(b["gutter"]):
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		entry = RULES.roll(side * 0.12, side * 0.035, float(b["speed"]), 0.0)
		if not bool(entry["gutter"]):
			entry = RULES.roll(side * 0.3, side * 0.06, float(b["speed"]), 0.0)
	else:
		var back := RULES.to_entry(float(b["x"]), float(b["angle"]), float(b["speed"]), float(b["hook"]))
		entry = RULES.roll(float(back["x0"]), float(back["aim"]), float(back["speed0"]), float(b["hook"]))
	var res: Dictionary = {"down": [], "falls": {}, "wobbled": []}
	if not bool(entry["gutter"]):
		res = RULES.strike(entry, lane["standing"], seed)
	_record_ball(key, s, i, mi, entry, res, seed, false)


## A ball on lane `i` by member `mi` counted: the pins it took, the card, whose turn, what
## the pinsetter must do, when the pins lie still (`quick`: a warden's, thrown from the line
## without the walk up).
func _record_ball(key: String, s: Dictionary, i: int, mi: int, entry: Dictionary, res: Dictionary, seed: int, quick: bool) -> void:
	var lane: Dictionary = s["lanes"][i]
	var members: Array = lane["members"]
	var m: Dictionary = members[mi]
	var before := 0
	for up in lane["standing"]:
		if up:
			before += 1
	for n in res["down"]:
		lane["standing"][int(n) - 1] = false
	(m["balls"] as Array).append((res["down"] as Array).size())
	var card := RULES.card(m["balls"])
	lane["seq"] = int(lane["seq"]) + 1
	lane["last"] = {"member": mi, "entry": entry, "res": res, "seed": seed, "before": before, "quick": quick}
	var frame_over := int(card["ball"]) == 0 or bool(card["done"])
	if frame_over:
		lane["turn"] = int(lane["turn"]) + 1
		lane["set"] = "rack"
		var all_done := true
		for mm in members:
			if not bool(RULES.card(mm["balls"])["done"]):
				all_done = false
		if all_done:
			# A whole game done: its score on the board, a new card.
			for mm in members:
				mm["last"] = int(RULES.card(mm["balls"])["total"])
				mm["balls"] = []
	else:
		# The tenth frame racks again after a strike or a spare.
		var fresh := true
		for up in card["standing"]:
			if not up:
				fresh = false
		lane["set"] = "rack" if fresh else "sweep"
	lane["wait"] = -(float(entry["t"]) * ROLL_SHARE + (QUICK_SEC if quick else BALL_SEC))
	_touch(key, "lane%d" % i)


# ── a warden on a lane ───────────────────────────────────────────────────────

static func is_warden_lane(lane: Dictionary) -> bool:
	return str(lane.get("visit", "")).begins_with("w:")


## Free lane `li` taken by warden `who` ("me" alone, the peer's id in co-op).
func take_lane(key: String, li: int, who: String, name: String) -> bool:
	if li < 0 or li >= LANES or str(site(key)["lanes"][li]["visit"]) != "":
		return false
	act(key, "wtake", [li, who, name])
	return true


func leave_lane(key: String, li: int, who: String) -> void:
	act(key, "wleave", [li, who])


## The warden's ball on lane `li`: let go at `x0` on the foul line, at `aim`, `speed`, with
## `hook` (BowlingRules.roll), what it takes worked out here and sent. Returns the ball's
## {entry, res} ({} when the pins are not up yet).
func warden_ball(key: String, li: int, x0: float, aim: float, speed: float, hook: float) -> Dictionary:
	var lane: Dictionary = site(key)["lanes"][li]
	if not is_warden_lane(lane) or str(lane["set"]) != "":
		return {}
	var seed := hash("%s/%d" % [str(lane["visit"]), int(lane["seq"])])
	var entry := RULES.roll(x0, aim, speed, hook)
	var res: Dictionary = {"down": [], "falls": {}, "wobbled": []}
	if not bool(entry["gutter"]):
		res = RULES.strike(entry, lane["standing"], seed)
	act(key, "wball", [li, entry, res, seed])
	return {"entry": entry, "res": res}


## The pins on lane `i` are set again (by you in the pit, by the hand, by `machine`).
func set_pins(key: String, i: int, machine := "") -> void:
	if str(site(key)["lanes"][i]["set"]) != "":
		act(key, "set", [i, machine])


func _put_up(key: String, s: Dictionary, i: int, machine := "") -> void:
	var lane: Dictionary = s["lanes"][clampi(i, 0, LANES - 1)]
	if str(lane["set"]) == "":
		return
	if str(lane["set"]) == "rack":
		lane["standing"] = RULES._all_up()
	lane["set"] = ""
	lane["wait"] = 0.0
	lane["ready"] = _clock + _rng.randf_range(PAUSE_SEC.x, PAUSE_SEC.y) + float(CYCLE_SEC.get(machine, 0.0))
	s["grumbled"].erase(str(lane["visit"]))
	_touch(key, "lane%d" % i)


## The pins of lane `i` wait for the pinsetter (the ball is down and they lie still).
func pins_waiting(key: String, i: int) -> bool:
	var lane: Dictionary = site(key)["lanes"][i]
	return str(lane["visit"]) != "" and str(lane["set"]) != "" and float(lane["wait"]) >= 0.0


## The pit's orders: the lanes whose pins wait, longest first: {id ("lane<i>"), lane,
## name (the party's), set, age, left, band}.
func pit_tickets(key: String, lanes: Array = [0, 1, 2, 3]) -> Array:
	var s := site(key)
	var out: Array = []
	for i in lanes:
		if not pins_waiting(key, int(i)):
			continue
		var lane: Dictionary = s["lanes"][int(i)]
		var age := float(lane["wait"])
		out.append({"id": "lane%d" % int(i), "lane": int(i), "name": str(lane["name"]), "set": str(lane["set"]), "age": age,
			"left": 1.0 - clampf(age / PINS_GONE, 0.0, 1.0), "band": 0 if age < PINS_OK else (1 if age < PINS_LATE else 2)})
	out.sort_custom(func(a, b): return float(a["age"]) > float(b["age"]))
	return out


func lane(key: String, i: int) -> Dictionary:
	return site(key)["lanes"][clampi(i, 0, LANES - 1)]


## Whoever is on shift at `role` (a crew record), {} nobody.
func hand_at(key: String, role: String) -> Dictionary:
	for p in BUSINESS.crew_now(key):
		if str(p.get("role", "")) == role:
			return p
	return {}


## The hands on shift: the counter's checks the parties in and shelves the shoes handed
## back, the pinsetter sets the pins one lane after another, each at their own speed.
func _hands(key: String, s: Dictionary, dt: float) -> void:
	var crew: Array = BUSINESS.crew_now(key)
	var busy: Dictionary = _hand_busy.get(key, {})
	for p in crew:
		var role := str(p.get("role", ""))
		var speed := clampi(int(p.get("speed", 1)), 0, 2)
		var left := float(busy.get(role, 0.0)) - dt
		if left > 0.0:
			busy[role] = left
			continue
		busy[role] = 0.0
		match role:
			"desk":
				if not (s["desk"] as Array).is_empty():
					if not check_in(key, str(s["desk"][0]["visit"]), false).is_empty():
						busy[role] = float(BIZ_RULES.SPEED_SEC[speed])
				elif not (s["back"] as Array).is_empty():
					shelve_returned(key)
					busy[role] = SHELVE_SEC * (1.5 - 0.25 * float(speed))
			"pins":
				var mach := machine_of(key)
				if mach == "":
					for i in LANES:
						if pins_waiting(key, i):
							set_pins(key, i)
							busy[role] = float(BIZ_RULES.SPEED_SEC[speed]) * 0.6
							break
				elif jammed(key):
					# Down to the cellar: freed when the time is up (it starts counting now).
					if not busy.has("fixing"):
						busy["fixing"] = float(FIX_SEC[speed])
					busy["fixing"] = float(busy["fixing"]) - dt
					if float(busy["fixing"]) <= 0.0:
						busy.erase("fixing")
						act(key, "unjam", [])
						_feed("%s freed the pinsetter in the cellar." % first_name(str(p.get("name", ""))))
			"bufet":
				# The oldest order made up and taken over, at their own speed.
				var orders: Array = s["bufet"]
				if not orders.is_empty():
					var o: Dictionary = orders[0]
					serve_bufet(key, str(o["id"]), (o["items"] as Array).duplicate(), 0.75, false)
					busy[role] = float(BIZ_RULES.SPEED_SEC[speed]) * (0.7 + 0.3 * float((o["items"] as Array).size()))
	if not jammed(key):
		busy.erase("fixing")
	_hand_busy[key] = busy


static func first_name(full: String) -> String:
	var parts := full.split(" ")
	return parts[0] if parts.size() > 0 else full


# ── the snack bar ────────────────────────────────────────────────────────────

## What the bar can make now: on the menu and on the shelf (BIZ_RULES.menu, menu_on).
func bufet_menu(key: String) -> Array:
	var out: Array = []
	var site_rec: Dictionary = BUSINESS.site(key)
	if site_rec.is_empty():
		return out
	var can: Dictionary = BIZ_RULES.menu("bowl", site_rec.get("stock", {}))
	for item in BUFET_ITEMS:
		if bool(can.get(item, false)) and BIZ_RULES.menu_on("bowl", site_rec, str(item)):
			out.append(item)
	return out


## What one of `item` costs (its good's price).
static func bufet_price(item: String) -> int:
	var good := str(BUFET_GOOD.get(item, item))
	return int((BIZ_RULES.goods("bowl").get(good, {}) as Dictionary).get("price", 0))


## The goods `items` take off the shelf (RECIPES["bowl"]).
static func bufet_needs(items: Array) -> Dictionary:
	var needs := {}
	var rec: Dictionary = BIZ_RULES.RECIPES.get("bowl", {})
	for item in items:
		var r: Dictionary = rec.get(str(item), {str(item): 1})
		for g in r:
			needs[g] = int(needs.get(g, 0)) + int(r[g])
	return needs


## The bar's orders, oldest first: {id, visit, lane, name, guest, items, age, left, band}.
func bufet_tickets(key: String) -> Array:
	var out: Array = []
	for o in site(key)["bufet"]:
		var d: Dictionary = (o as Dictionary).duplicate()
		var age := _clock - float(o["at"])
		d["age"] = age
		d["left"] = 1.0 - clampf(age / BUFET_GONE, 0.0, 1.0)
		d["band"] = 0 if age < BUFET_OK else (1 if age < BUFET_LATE else 2)
		out.append(d)
	return out


## The parties on their lanes order now and then; who waited too long gives up on it.
func _bufet(key: String, s: Dictionary) -> void:
	var orders: Array = s["bufet"]
	var next: Dictionary = s["next_order"]
	for i in range(orders.size() - 1, -1, -1):
		var o: Dictionary = orders[i]
		if _clock - float(o["at"]) > BUFET_GONE:
			orders.remove_at(i)
			ORDERS.mood(int(o.get("guest", 0)), -3.0, "Waited at the lane for something from the snack bar. It never came.")
			_touch(key, "bufet")
	var menu := bufet_menu(key)
	var by := {}
	for v in ORDERS.visitors(key):
		by[str(v["visit"])] = v
	for li in LANES:
		var lane: Dictionary = s["lanes"][li]
		var visit := str(lane["visit"])
		if visit == "" or is_warden_lane(lane):
			continue
		if not next.has(visit):
			next[visit] = _clock + _rng.randf_range(BUFET_EVERY.x * 0.3, BUFET_EVERY.x)
			continue
		if _clock < float(next[visit]):
			continue
		next[visit] = _clock + _rng.randf_range(BUFET_EVERY.x, BUFET_EVERY.y)
		if menu.is_empty():
			continue
		var open := false
		for o in orders:
			open = open or str(o["visit"]) == visit
		if open:
			continue
		var n := mini(_rng.randi_range(1, 3), maxi(1, (lane["members"] as Array).size()))
		var items: Array = []
		for k in n:
			items.append(_want_of(menu))
		s["order_n"] = int(s["order_n"]) + 1
		orders.append({"id": "b%d" % int(s["order_n"]), "visit": visit, "lane": li, "name": str(lane["name"]),
			"guest": int((by.get(visit, {}) as Dictionary).get("id", 0)), "items": items, "at": _clock})
		_touch(key, "bufet")
	for visit in next.keys():
		var here := false
		for lane in s["lanes"]:
			here = here or str(lane["visit"]) == str(visit)
		if not here:
			next.erase(visit)


## One thing a guest wants of what the bar has (by the place's wants).
func _want_of(menu: Array) -> String:
	var wants: Dictionary = BIZ_RULES.info("bowl").get("wants", {})
	var total := 0.0
	for g in wants:
		if menu.has(str(WANT_ITEM.get(g, g))):
			total += float(wants[g])
	if total <= 0.0:
		return str(menu[_rng.randi() % menu.size()])
	var r := _rng.randf() * total
	for g in wants:
		var item := str(WANT_ITEM.get(g, g))
		if not menu.has(item):
			continue
		r -= float(wants[g])
		if r <= 0.0:
			return item
	return str(menu[0])


## Order `id` taken over with `built` on the tray (the drinks poured `quality` 0..1): they
## pay for what they wanted and got, the goods come off the books. Returns {ok, amount,
## fit, speed, order} or {ok: false, short} when the shelf has not got it.
func serve_bufet(key: String, id: String, built: Array, quality: float, by_hand: bool) -> Dictionary:
	var order: Dictionary = {}
	for o in site(key)["bufet"]:
		if str(o["id"]) == id:
			order = o
	if order.is_empty():
		return {}
	var want: Array = (order["items"] as Array).duplicate()
	var got: Array = []
	var extra := 0
	for item in built:
		var at := want.find(item)
		if at >= 0:
			want.remove_at(at)
			got.append(item)
		else:
			extra += 1
	var fit := clampf((float(got.size()) - 0.5 * float(extra)) / float(maxi(1, (order["items"] as Array).size())), 0.0, 1.0)
	var price := 0
	for item in got:
		price += bufet_price(str(item))
	var amount := int(round(float(price) * BUSINESS.price_k(key)))
	if not BUSINESS.sell(key, bufet_needs(built), amount):
		return {"ok": false, "short": true}
	var age := _clock - float(order["at"])
	act(key, "bufet_done", [id, got])
	var speed := 1.0 - clampf((age - 5.0) / (BUFET_GONE - 5.0), 0.0, 1.0)
	var pts := BIZ_RULES.score(speed, fit * clampf(quality, 0.0, 1.0))
	ORDERS.mood(int(order.get("guest", 0)), -2.0 + float(pts) / 100.0 * 5.0, "A cold beer brought over to the lane. That's a bowling alley." if pts >= 70 else "The snack bar got the order wrong.")
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_score(key, {"score": pts, "tip": 0, "what": "Snack bar", "who": str(order.get("name", "")), "hand": not by_hand})
	return {"ok": true, "amount": amount, "fit": fit, "speed": speed, "score": pts, "order": order}


# ── the machine ──────────────────────────────────────────────────────────────

## The pinsetter from the books: "brnoswick", "machine" (the Stavomat) or "" (by hand).
func machine_of(key: String) -> String:
	if BUSINESS.has_gear(key, "brnoswick"):
		return "brnoswick"
	if BUSINESS.has_gear(key, "machine"):
		return "machine"
	return ""


## The Stavomat stands with something in its gears.
func jammed(key: String) -> bool:
	return str(site(key)["machine"].get("jam", "")) != "" and machine_of(key) == "machine"


## What is caught and since when: {jam, since, lane}.
func jam_of(key: String) -> Dictionary:
	return site(key)["machine"]


## Freed in the cellar (the station's lever).
func unjam(key: String) -> void:
	if str(site(key)["machine"].get("jam", "")) != "":
		act(key, "unjam", [])


## The machine sets each lane whose pins have lain long enough; the Stavomat now and then
## catches something in its gears instead, and then every lane waits.
func _machine(key: String, s: Dictionary) -> void:
	var mach := machine_of(key)
	if mach == "" or jammed(key):
		return
	var need := BRNOSWICK_SEC if mach == "brnoswick" else MACHINE_SEC
	for i in LANES:
		if not pins_waiting(key, i) or float(s["lanes"][i]["wait"]) < need:
			continue
		if mach == "machine" and _rng.randf() < MACHINE_JAM:
			act(key, "jam", [_pick_jam(), i])
			_feed("The pinsetter has jammed. Every lane is standing.")
			return
		set_pins(key, i, mach)


func _pick_jam() -> String:
	var total := 0
	for k in JAMS:
		total += int(JAMS[k])
	var r := _rng.randi_range(1, total)
	for k in JAMS:
		r -= int(JAMS[k])
		if r <= 0:
			return str(k)
	return "rag"


func _grumble(key: String, lane: Dictionary) -> void:
	var who := str(lane.get("name", "A guest")).split(" ")[0]
	_feed("%s at the bowling: the pins are not being set. Nobody in the pit." % who)
	for v in ORDERS.visitors(key):
		if str(v["visit"]) == str(lane["visit"]):
			ORDERS.mood(int(v["id"]), -4.0, "Stood at the lane. Nobody set up the pins.")


func _feed(text: String) -> void:
	var main := get_tree().current_scene
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("push_status"):
		hud.push_status(text, 1, "bowling_feed")
