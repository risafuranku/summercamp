extends Node

## Headless check for the corn stand (DESIGN.md §7b "The corn stand"; core/systems/
## corn_rules.gd, scripts/corn/cornstand.gd, its stations scripts/corn/*_station.gd).
##
##   godot --headless --path godot res://tools/stand_check.tscn
##
## Run as a SCENE (CoreRoot / EventBus autoloads). Asserts:
## - the rules: a cob is done at DONE_AT, soft from OVER_AT; the salt each guest wants is
##   the same every time; a hard, a soft, an unbuttered cob is handed back, a right one
##   is three stars;
## - the stand from the books: an empty pot and bowl; husked cobs into the bowl, a cob
##   into the pot (a place each, three; six with the bigger pot), out again;
## - the orders come from the guests at the stand, one cob each;
## - a right cob served (Papa's score): the price and a tip, a knob of butter off the
##   books, the order off the rail, the shift's tally; a hard one handed back;
## - the hands: the husk's takes a cob from the crate into the bowl, the counter's puts
##   it in the pot, takes it out done and hands it over;
## - the stations as a player works them (their debug hooks): a cob from the crate, its
##   leaves pulled (four; two with the husking table), into the bowl; into the pot, out
##   onto the board, buttered, salted, wrapped, over the counter.

const CORN := preload("res://core/systems/corn_rules.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const CORNSTAND := preload("res://scripts/corn/cornstand.gd")
const LAYOUT := preload("res://scripts/corn/stand_layout.gd")
const KEY := "11:11"

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# The rules.
	_expect(CORN.stage(0.0) == 0 and CORN.stage(CORN.DONE_AT + 0.1) == 1 and CORN.stage(CORN.OVER_AT + CORN.MUSH_SPAN * 0.5) == 2, "pale, done, soft in order")
	_expect(CORN.salt_wish("5@100", 0) == CORN.salt_wish("5@100", 0), "the salt wished is the same every time")
	var right: Dictionary = CORN.judge(1.0, 1.0, 2, 2, 3)
	_expect(bool(right["ok"]) and float(right["build"]) == 1.0 and float(right["cook"]) == 1.0, "a right cob is right (%s)" % str(right))
	_expect(not bool(CORN.judge(0.3, 1.0, 2, 2, 3)["ok"]), "a hard one is handed back")
	_expect(not bool(CORN.judge(1.9, 1.0, 2, 2, 3)["ok"]), "a soft one is handed back")
	_expect(float(CORN.judge(1.0, 0.0, 2, 2, 3)["build"]) < 0.6, "no butter is a poor cob")
	_expect(float(CORN.judge(1.0, 1.0, 3, 0, 3)["build"]) < 0.5, "three shakes for NO SALT is a poor cob")

	var state = CoreRoot.get_state()
	var a = CoreRoot.actions
	state.grid.cells.clear()
	state.biz = {}
	state.money = 5000
	state.day = 3
	GuestManager._last_known_day = 3
	GuestManager._last_known_hour = 13
	GuestManager._last_known_minute = 0
	state.grid.occupy_cell(Vector2i(11, 11), "corn_stand", "corn_stand_11_11", Vector2i(11, 11))
	var site: Dictionary = a.biz_site(KEY, "corn_stand")
	_expect(not site.is_empty() and str(site["kind"]) == "corn", "a stand's books")
	var stand = CORNSTAND.of(get_tree())
	_expect(stand != null, "the stands' node is there")
	_expect(stand.pot(KEY).is_empty() and int(stand.bowl(KEY)) == 0, "an empty pot and bowl")
	stand.act(KEY, "husked", [4])
	_expect(int(stand.bowl(KEY)) == 4, "four husked into the bowl")
	for i in 3:
		stand.act(KEY, "in", [stand.new_id(), stand.free_slot(KEY)])
	_expect(stand.pot(KEY).size() == 3 and int(stand.bowl(KEY)) == 1 and stand.free_slot(KEY) == -1, "three in the pot, the pot full")
	a.biz_add_gear(KEY, "pot")
	_expect(stand.free_slot(KEY) == 3, "the bigger pot has room")
	site["gear"] = []
	for c in stand.pot(KEY).duplicate():
		stand.act(KEY, "out", [str(c["id"])])
	_expect(stand.pot(KEY).is_empty(), "taken out again")

	# Guests at the stand: their orders.
	var now: int = CORNSTAND.now_min()
	state.guests.clear()
	for i in 6:
		state.guests.append({"id": 700 + i, "name": "Corn%d Guest" % i, "archetype": ["family", "picker", "drunk"][i % 3], "status": "active",
			"party_size": 1, "mood": 60.0, "needs": {},
			"activity": {"kind": "visit", "target_key": KEY, "start": now - 8, "arrive": now - 8, "end": now + 300}})
	var tix: Array = stand.tickets(KEY)
	_expect(tix.size() >= 6, "an order each (%d)" % tix.size())
	_expect(tix == stand.tickets(KEY), "the same orders every time")
	# A right cob.
	var t: Dictionary = tix[0]
	var money0: int = state.money
	var butter0 := BUSINESS.stock_of(KEY, "butter")
	var v: Dictionary = stand.serve(KEY, t, 1.0, 1.0, int(t["salt"]))
	_expect(bool(v.get("ok", false)) and int(v["stars"]) == 3 and int(v["tip"]) > 0, "a right cob: three stars and a tip (%s)" % str(v))
	_expect(state.money == money0 + int(v["amount"]), "the money in the cash box")
	_expect(BUSINESS.stock_of(KEY, "butter") == butter0 - 1, "a knob of butter off the books")
	_expect(stand.tickets(KEY).size() == tix.size() - 1, "that order is off the rail")
	_expect(int(site["shift"]["orders"]) == 1, "the shift's tally")
	var hard: Dictionary = stand.serve(KEY, stand.tickets(KEY)[0], 0.3, 1.0, 1)
	_expect(not bool(hard.get("ok", true)) and stand.tickets(KEY).size() == tix.size() - 1, "a hard one handed back, the order still up")

	# The hands.
	for slug_role in [["pepicek", "husk"], ["klara", "counter"]]:
		var p := RULES.person(str(slug_role[0]), "corn")
		p["role"] = str(slug_role[1])
		p["shift"] = "day"
		a.biz_hire(KEY, p, 1)
	_expect(BUSINESS.crew_now(KEY).size() == 2, "two hands in")
	var cobs0 := BUSINESS.stock_of(KEY, "cobs")
	var bowl0 := int(stand.bowl(KEY))
	_expect(stand._crew_husk(KEY, false) and int(stand.bowl(KEY)) == bowl0 + 1 and BUSINESS.stock_of(KEY, "cobs") == cobs0 - 1, "the husk's hand: a cob from the crate into the bowl")
	_expect(stand._crew_counter(KEY, false) and stand.pot(KEY).size() == 1, "the counter's hand: into the pot")
	stand.pot(KEY)[0]["t"] = CORN.DONE_AT + 0.5
	var open0: int = stand.tickets(KEY).size()
	_expect(stand._crew_counter(KEY, false) and stand.pot(KEY).is_empty() and stand.tickets(KEY).size() == open0 - 1, "the counter's hand: out done, over the counter")
	_expect(int(site["shift"]["by_hands"]) >= 1, "the hands' cobs in the tally")
	site["crew"] = []

	# The stations as a player works them.
	var root := Node3D.new()
	add_child(root)
	var st := {}
	for id in LAYOUT.STATIONS:
		var surf: Dictionary = LAYOUT.SURFACES[id]
		var v3: Node3D = load(str(LAYOUT.STATIONS[id]["script"])).new()
		v3.set("building_key", KEY)
		v3.set("station", str(id))
		v3.set("surf_at", surf["at"])
		v3.set("surf_size", surf["size"])
		v3.set("surf_yaw", float(surf["yaw"]))
		v3.set("surf_flat", bool(surf["flat"]))
		v3.set("state", stand)
		root.add_child(v3)
		st[id] = v3
	await get_tree().process_frame
	var husk: Node = st["husk"]
	var counter: Node = st["counter"]
	var cobs1 := BUSINESS.stock_of(KEY, "cobs")
	husk.debug_click("crate")
	_expect(BUSINESS.stock_of(KEY, "cobs") == cobs1 - 1 and int(husk.get("_cob")["leaves"]) == CORN.LEAVES, "a cob from the crate, four leaves on it")
	husk.debug_pull()
	_expect(int(husk.get("_cob")["leaves"]) == CORN.LEAVES - 1, "a pull takes a leaf off")
	husk.debug_husk()
	var b1 := int(stand.bowl(KEY))
	husk.debug_click("cob")
	_expect(int(stand.bowl(KEY)) == b1 + 1 and (husk.get("_cob") as Dictionary).is_empty(), "husked: into the bowl")
	a.biz_add_gear(KEY, "table")
	husk.debug_click("crate")
	_expect(int(husk.get("_cob")["leaves"]) == CORN.LEAVES_TABLE, "the husking table: two leaves")
	site["gear"] = []
	husk.debug_husk()
	husk.debug_click("cob")
	# The counter: into the pot, out done, dressed, over the counter.
	counter.debug_click("pot")
	_expect(stand.pot(KEY).size() == 1, "the counter: a cob into the pot")
	stand.pot(KEY)[0]["t"] = CORN.DONE_AT + 1.0
	counter.debug_take_first()
	_expect(stand.pot(KEY).is_empty() and not (counter.get("_board") as Dictionary).is_empty(), "out onto the board")
	counter.debug_dress_right()
	var before: int = stand.tickets(KEY).size()
	counter.debug_click("hand")
	_expect(stand.tickets(KEY).size() == before - 1 and (counter.get("_board") as Dictionary).is_empty(), "over the counter: served")

	print("")
	if _failures.is_empty():
		print("STAND CHECK: PASS")
		get_tree().quit(0)
	else:
		print("STAND CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
