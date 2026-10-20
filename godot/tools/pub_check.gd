extends Node

## Headless check for the pub (DESIGN.md §7b "the pub"; scripts/pub/taproom.gd, its
## stations scripts/pub/*_station.gd, core/systems/pub_rules.gd).
##
##   godot --headless --path godot res://tools/pub_check.tscn
##
## Run as a SCENE (CoreRoot / EventBus autoloads). Asserts:
## - a pub's tap from the books: sixteen clean mugs, the keg on the line, tapped today;
## - the orders come from the guests in it, the same ones every time;
## - a good pour served (Papa's score): three stars and a tip, on the tab (no money yet, a
##   mark on the mat), a mug off the board, a pint off the keg and the books, the shift's
##   tally; a poor one fewer stars;
## - the bill: asked for when their time is up, no more rounds then; short change is
##   refused, the right change takes the marks' money (and the round sum with a tip);
##   the bill counted at the tap as a player does it; one nobody came for is left on
##   the bar by a happy guest;
## - the fun (pub_fun.gd): the LUCKY 7 keeps a house edge and pays three sevens, a dart in
##   the bull is fifty and one in the treble twenty sixty, two aces win at cards; the
##   guests have their go (the machine's take in the till, their darts in the board); a
##   warden's game of cards moves the stake; the three stations build;
## - the keg on the line goes flat after three days (six with the keg cooler); what is
##   left in it thrown out is the books' waste;
## - the hands: the tap's pours the oldest beer ordered, the bar's a shot or a kofola,
##   the washer's washes a mug, the cellar's changes a spent or flat keg and sets the
##   gas; the glass washer (gear) washes the lot;
## - the stations as a player works them (their debug hooks): a mug poured and served at
##   the tap, a shot at the bottles, a mug scrubbed clean at the sink, the head taken off
##   and screwed back on in the cellar.

const PUB := preload("res://core/systems/pub_rules.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const TAPROOM := preload("res://scripts/pub/taproom.gd")
const FUN := preload("res://core/systems/pub_fun.gd")
const KEY := "6:6"

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	var a = CoreRoot.actions
	state.grid.cells.clear()
	state.biz = {}
	state.money = 5000
	state.day = 3
	GuestManager._last_known_day = 3
	GuestManager._last_known_hour = 18
	GuestManager._last_known_minute = 0
	state.grid.occupy_cell(Vector2i(6, 6), "pub", "pub_6_6", Vector2i(6, 6))
	var site: Dictionary = a.biz_site(KEY, "pub")
	_expect(not site.is_empty() and str(site["kind"]) == "pub", "a pub's books")
	var beer0 := int(site["stock"]["beer"])

	var tr = TAPROOM.of(get_tree())
	_expect(tr != null, "the taproom is there")
	var s: Dictionary = tr.site(KEY)
	_expect(int(s["mugs"]["clean"]) == PUB.MUGS and int(s["mugs"]["dirty"]) == 0, "sixteen clean mugs")
	_expect(int(s["keg"]["line"]) == mini(PUB.KEG_PINTS, beer0) and str(s["keg"]["pallet"]) == "full" and bool(s["keg"]["coupled"]), "the keg on the line from the books (%s)" % str(s["keg"]))
	_expect(int(s["keg"]["tapped"]) == 3, "tapped today")
	_expect(tr.tap_trouble(KEY) == "", "the tap pours")

	# Guests in the pub: their orders.
	var now: int = TAPROOM.now_min()
	var guests: Array = []
	for i in 10:
		guests.append({"id": 900 + i, "name": "Guest%d Test" % i, "archetype": ["drunk", "tramp", "quiet_guy", "cheap_chick", "family"][i % 5],
			"status": "active", "party_size": 1, "mood": 60.0, "needs": {},
			"activity": {"kind": "visit", "target_key": KEY, "start": now - 12, "arrive": now - 12, "end": now + 300}})
	state.guests.clear()
	for g in guests:
		state.guests.append(g)
	var tix: Array = tr.tickets(KEY)
	_expect(tix.size() == 10, "one order each (%d)" % tix.size())
	_expect(tix == tr.tickets(KEY), "the same orders every time")
	var tap_t := {}
	var bar_t := {}
	for t in tix:
		if PUB.kind(str(t["drink"])) == "tap" and tap_t.is_empty():
			tap_t = t
		elif PUB.kind(str(t["drink"])) == "bar" and bar_t.is_empty():
			bar_t = t
	_expect(not tap_t.is_empty() and not bar_t.is_empty(), "beer and shots ordered")

	# A good pour.
	var drink := str(tap_t["drink"])
	var want := float(PUB.DRINKS[drink]["beer"])
	var v: Dictionary = PUB.judge_pour(drink, want, 0.96 - want, 0.0, int(tap_t["age"]))
	_expect(bool(v["ok"]) and float(v["accuracy"]) > 0.95, "a right %s judged right (%s)" % [drink, str(v)])
	var money0: int = state.money
	var verdict: Dictionary = tr.serve(KEY, tap_t, v)
	_expect(bool(verdict.get("ok", false)), "served")
	_expect(int(verdict["stars"]) == 3 and int(verdict["tip"]) > 0, "three stars and a tip (%s)" % str(verdict))
	_expect(state.money == money0 and bool(verdict.get("tab", false)), "on the tab: nothing in the till yet")
	_expect(int(PUB.tab_of(str(tap_t["visit"]), tr.site(KEY)["served"])["n"]) == 1, "a mark on their mat")
	_expect(int(site["stock"]["beer"]) == beer0 - 1, "a pint off the books")
	_expect(int(tr.mugs(KEY)["clean"]) == PUB.MUGS - 1, "a mug off the board")
	_expect(int(tr.keg(KEY)["line"]) == mini(PUB.KEG_PINTS, beer0) - 1, "a pint off the keg")
	_expect(int(site["shift"]["orders"]) == 1 and int(site["shift"]["tips"]) == int(verdict["tip"]), "the shift's tally (%s)" % str(site["shift"]))
	_expect(tr.tickets(KEY).size() == 9, "that order is off the rail")
	# A poor one.
	var poor: Dictionary = PUB.judge_pour("hladinka", 0.4, 0.2, 0.15, 70)
	_expect(not bool(poor["ok"]) or float(poor["accuracy"]) < 0.6, "half a mug of foam is no hladinka (%s)" % str(poor))

	# Flat: three days on the line, six with the cooler; what is left goes down the drain.
	tr.set_keg(KEY, {"tapped": 0})
	_expect(tr.tap_trouble(KEY) == "flat", "three days on the line: flat")
	a.biz_add_gear(KEY, "cooler")
	_expect(tr.tap_trouble(KEY) == "", "with the keg cooler it keeps")
	site["gear"] = []
	var line := int(tr.keg(KEY)["line"])
	var stock := int(site["stock"]["beer"])
	var waste0 := int(site["today"]["waste"])
	tr.waste_keg(KEY)
	_expect(int(site["stock"]["beer"]) == stock - line and int(site["today"]["waste"]) == waste0 + line, "the flat keg is waste (%d pints)" % line)

	# The hands.
	GuestManager._last_known_hour = 18
	for slug_role in [["pepa", "cellar"], ["hanka", "wash"], ["lojza", "tap"], ["mirek", "bar"]]:
		var p := RULES.person(str(slug_role[0]), "pub")
		p["role"] = str(slug_role[1])
		p["shift"] = "day"
		a.biz_hire(KEY, p, 1)
	_expect(BUSINESS.crew_now(KEY).size() == 4, "four hands in (%d)" % BUSINESS.crew_now(KEY).size())
	var cellar: Dictionary = BUSINESS.crew_now(KEY)[0]
	# The cellar: the flat keg's left-overs thrown out, a full one on, coupled, tapped today.
	a.biz_receive(3)
	site["stock"]["beer"] = 120
	site["lots"]["beer"] = [[120, 3]]
	tr.set_keg(KEY, {"tapped": 0, "line": 10})
	_expect(tr._crew_cellar(KEY), "the cellar's hand changes the flat keg")
	var k: Dictionary = tr.keg(KEY)
	_expect(str(k["pallet"]) == "full" and bool(k["coupled"]) and int(k["tapped"]) == 3 and int(k["line"]) == PUB.KEG_PINTS, "a fresh keg on (%s)" % str(k))
	_expect(int(site["stock"]["beer"]) == 110, "the flat one's ten pints thrown out (%d)" % int(site["stock"]["beer"]))
	tr.set_keg(KEY, {"gas": 0.1})
	_expect(tr._crew_cellar(KEY) and absf(float(tr.keg(KEY)["gas"]) - PUB.GAS_START) < 0.001, "the gas set right")
	tr.set_keg(KEY, {"pallet": "empty", "line": 0})
	_expect(tr._crew_cellar(KEY) and str(tr.keg(KEY)["pallet"]) == "full", "a spent keg changed")
	# The washer.
	tr.act(KEY, "mugs", [0, 3])
	var clean0 := int(tr.mugs(KEY)["clean"])
	_expect(tr._crew_wash(KEY, false) and int(tr.mugs(KEY)["clean"]) == clean0 + 1 and int(tr.mugs(KEY)["dirty"]) == 2, "the washer washes a mug")
	# The tap and the bar pour the oldest order of their kind, a fair pour.
	var n_tap := 0
	var n_bar := 0
	for t in tr.tickets(KEY):
		if PUB.kind(str(t["drink"])) == "tap":
			n_tap += 1
		else:
			n_bar += 1
	_expect(n_tap > 0 and n_bar > 0, "beer and shots still wanted (%d, %d)" % [n_tap, n_bar])
	var lojza: Dictionary = {}
	var mirek: Dictionary = {}
	for p in BUSINESS.crew_now(KEY):
		if str(p["role"]) == "tap":
			lojza = p
		elif str(p["role"]) == "bar":
			mirek = p
	if n_tap > 0:
		_expect(tr._crew_pour(KEY, lojza, "tap", false, 1), "the tap's hand pours a beer")
	if n_bar > 0:
		_expect(tr._crew_pour(KEY, mirek, "bar", false, 1), "the bar's hand pours a shot")
	var after: int = tr.tickets(KEY).size()
	_expect(after == n_tap + n_bar - (1 if n_tap > 0 else 0) - (1 if n_bar > 0 else 0), "their orders off the rail (%d)" % after)
	_expect(int(site["shift"]["by_hands"]) >= 1, "the hands' pours in the tally")
	# The glass washer washes the lot.
	tr.act(KEY, "mugs", [0, 4])
	a.biz_add_gear(KEY, "glasswasher")
	tr._glasswasher(KEY)
	_expect(int(tr.mugs(KEY)["dirty"]) == 0, "the glass washer leaves no dirty mug")
	site["gear"] = []
	site["crew"] = []

	# The stations as a player works them.
	var room := Node3D.new()
	add_child(room)
	var st := {}
	for id in ["tap", "back", "wash", "keg", "slot", "darts", "cards"]:
		var v3: Node3D = load("res://scripts/pub/%s_station.gd" % id).new()
		var surf: Dictionary = load("res://scripts/pub/pub_layout.gd").SURFACES[id]
		v3.set("building_key", KEY)
		v3.set("station", id)
		v3.set("surf_at", surf["at"])
		v3.set("surf_size", surf["size"])
		v3.set("surf_yaw", float(surf["yaw"]))
		v3.set("surf_flat", bool(surf["flat"]))
		v3.set("state", tr)
		room.add_child(v3)
		st[id] = v3
	await get_tree().process_frame
	# The tap: a mug under it, a hladinka poured, over the bar.
	var before: int = tr.tickets(KEY).size()
	var clean1 := int(tr.mugs(KEY)["clean"])
	var tap_open := 0
	for t in tr.tickets(KEY):
		if PUB.kind(str(t["drink"])) == "tap":
			tap_open += 1
	_expect(tap_open > 0, "a beer still wanted for the tap")
	if tap_open > 0:
		var td := ""
		for t in tr.tickets(KEY):
			if PUB.kind(str(t["drink"])) == "tap":
				td = str(t["drink"])
				break
		var wb := float(PUB.DRINKS[td]["beer"])
		st["tap"].debug_pour(wb, 0.96 - wb)
		st["tap"].debug_click("mug")
		_expect(tr.tickets(KEY).size() == before - 1 and int(tr.mugs(KEY)["clean"]) == clean1 - 1, "the tap: a mug poured and served")
	# The bottles: a shot to the line, over the bar.
	var bar_drink := ""
	for t in tr.tickets(KEY):
		if PUB.kind(str(t["drink"])) == "bar":
			bar_drink = str(t["drink"])
			break
	_expect(bar_drink != "", "a shot still wanted for the bottles")
	if bar_drink != "":
		var b0: int = tr.tickets(KEY).size()
		var line_at := PUB.LINE_TALL if bool(PUB.DRINKS[bar_drink].get("tall", false)) else PUB.LINE_SHOT
		st["back"].debug_pour(bar_drink, line_at)
		st["back"].debug_click("glass")
		_expect(tr.tickets(KEY).size() == b0 - 1, "the bottles: a %s poured to the line and served" % bar_drink)
	# The sink: a dirty mug into the water, scrubbed, onto the board.
	tr.act(KEY, "mugs", [0, 2])
	var c2 := int(tr.mugs(KEY)["clean"])
	st["wash"].debug_wash_one()
	_expect(int(tr.mugs(KEY)["clean"]) == c2 + 1, "the sink: a mug washed")
	# The cellar: the head off, a beat, back on.
	st["keg"].debug_click("coupler")
	_expect(not bool(tr.keg(KEY)["coupled"]) and tr.tap_trouble(KEY) == "off", "the head off the keg: the tap is dry")
	st["keg"].debug_click("coupler_on")
	_expect(bool(tr.keg(KEY)["coupled"]) and tr.tap_trouble(KEY) == "", "the head back on: it pours")
	# The second tap's gear makes the tap's beer come faster; the coupler the head.
	_expect(RULES.gear_list("pub").has("tap2") and RULES.gear_list("pub").has("coupler"), "the pub's gear")

	# The fun.
	var edge := FUN.house_edge()
	_expect(edge > 0.05 and edge < 0.45, "the LUCKY 7 keeps a house edge (%.2f)" % edge)
	_expect(FUN.payout(["seven", "seven", "seven"]) == int(FUN.PAY_THREE["seven"]) and FUN.payout(["lemon", "bell", "plum"]) == 0, "three sevens pay, a mixed line does not")
	_expect(FUN.dart_score(Vector2.ZERO) == 50 and FUN.dart_score(Vector2(0, -0.6)) == 60 and FUN.dart_score(Vector2(0, -1.2)) == 0, "the bull, the treble twenty, off the board")
	_expect(FUN.result(["ace", "ace"], ["10", "ace"]) == 1 and FUN.result(["10", "9", "8"], ["7"]) == -1, "two aces win; over twenty-one loses")
	_expect(FUN.pack(7).size() == 32 and FUN.pack(7) == FUN.pack(7), "the same shuffled pack for a game")
	var takings0 := int(site["today"]["takings"])
	var hour0: int = GuestManager._last_known_hour
	GuestManager._last_known_hour = hour0 + 1
	tr._guests_play(KEY, TAPROOM.now_min())
	var played: Dictionary = tr.fun(KEY)["played"]
	_expect(not played.is_empty(), "the guests have their go (%d)" % played.size())
	var any_slot := false
	for k2 in played:
		any_slot = any_slot or str(k2).ends_with(":slot")
	if any_slot:
		_expect(int(site["today"]["takings"]) > takings0 and not (tr.fun(KEY)["slot"] as Dictionary).is_empty(), "what they fed the LUCKY 7 is in the till")
	GuestManager._last_known_hour = hour0
	var m_cards: int = state.money
	tr.cards_done(KEY, 900, 1)
	_expect(state.money == m_cards + FUN.STAKE, "a game of cards won: their stake in the till")
	tr.cards_done(KEY, 900, -1)
	_expect(state.money == m_cards, "and lost: yours to them")
	st["slot"].debug_pull()
	_expect(not (tr.fun(KEY)["slot"] as Dictionary).is_empty() and str(tr.fun(KEY)["slot"]["who"]) == "you", "the lever pulled: a game")
	for i in 3:
		st["darts"].debug_throw(Vector2(0, -0.6))
	_expect(int(tr.fun(KEY)["darts"].get("total", 0)) == 180, "three in the treble twenty: one hundred and eighty")
	_expect(st["cards"].debug_game(["ace", "ace"], ["10", "9"]) == 1, "oko at the table")

	# The tab and the bill: their time is up (the clock on three hours), the bills asked for.
	GuestManager._last_known_hour = 21
	var bills: Array = tr.bills(KEY)
	_expect(not bills.is_empty(), "bills asked for when their time is up (%d)" % bills.size())
	_expect(tr.tickets(KEY).is_empty(), "no more rounds while they pay (%d)" % tr.tickets(KEY).size())
	if not bills.is_empty():
		var b: Dictionary = bills[0]
		var tab: Dictionary = PUB.tab_of(str(b["visit"]), tr.site(KEY)["served"])
		_expect(int(b["total"]) == int(tab["total"]) and int(b["total"]) > 0, "the bill is the marks (%s)" % str(b["counts"]))
		var due := PUB.change_due(b)
		var m0: int = state.money
		if due > 0:
			var short: Dictionary = tr.settle(KEY, b, due - 1)
			_expect(not bool(short["ok"]) and state.money == m0, "short change refused")
		var ok: Dictionary = tr.settle(KEY, b, due)
		_expect(bool(ok["ok"]) and state.money == m0 + PUB.to_pay(b), "the right change: the bill's money in the till (%d)" % (state.money - m0))
		_expect(tr.bill_of(KEY, str(b["visit"])).is_empty(), "that bill settled")
	# The bill at the tap, as a player counts it: the note taken, the change, handed over.
	var at_tap: Array = tr.bills(KEY)
	if not at_tap.is_empty():
		var b2: Dictionary = at_tap[0]
		var spot = st["tap"].get("_bill")
		spot.call("pick", b2)
		var m1: int = state.money
		spot.call("press", "bill:mat")
		var due2 := PUB.change_due(b2)
		for coin in [10, 5, 2, 1]:
			while int(spot.call("given_sum")) + coin <= due2:
				spot.call("press", "bill:%d" % coin)
		if int(b2["note"]) > 0:
			spot.call("press", "bill:mat")
		_expect(tr.bill_of(KEY, str(b2["visit"])).is_empty() and state.money == m1 + PUB.to_pay(b2), "the bill counted at the tap (%d)" % (state.money - m1))
	# One nobody comes for: left on the bar by a guest who liked it.
	var left: Array = tr.bills(KEY)
	if not left.is_empty():
		var b3: Dictionary = left[0]
		GuestManager._last_known_hour = 23
		var m2: int = state.money
		tr._bills_waiting(KEY, TAPROOM.now_min())
		var rec: Dictionary = tr.site(KEY)["served"].get(str(b3["id"]), {})
		_expect(bool(rec.get("left", false)), "an unpaid bill is settled by itself (%s)" % str(rec))
		_expect(state.money == m2 + int(rec.get("kept", 0)), "what was left on the bar is in the till")

	print("")
	if _failures.is_empty():
		print("PUB CHECK: PASS")
		get_tree().quit(0)
	else:
		print("PUB CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
