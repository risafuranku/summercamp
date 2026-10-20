extends Node

## Headless check for the businesses' hands (DESIGN.md §7b, the hands;
## core/systems/business_rules.gd, actions biz_*, scripts/business/business_runtime.gd,
## the bistro's kitchen at work: scripts/bistro/kitchen.gd crew).
##
##   godot --headless --path godot res://tools/staff_check.tscn
##
## Run as a SCENE (CoreRoot / EventBus autoloads). Asserts:
## - a person's ways are the same every time in a camp; the wage follows them (the quick
##   and the pleasant dearer, a thief a little cheaper, the two strange ones cheap);
## - three ask at a place each day, the same on every machine, nobody already working;
##   the two strange ones turn up now and then;
## - an old save's one hand becomes a person at the front job;
## - who works now: the shift and who came in today; the front job covered = staffed;
## - about one hand in twenty stays away a day, the strange ones never;
## - a dishonest hand leaves the books short now and then, an honest one never;
## - the kitchen's hands: the cellar fills the trays, the stove turns and racks a slice
##   (golden: good quality), the sink washes up, the pass plates a ready ticket.

const RULES = preload("res://core/systems/business_rules.gd")
const BUSINESS = preload("res://scripts/business/business_runtime.gd")
const KITCHEN = preload("res://scripts/bistro/kitchen.gd")
const BISTRO = preload("res://core/systems/bistro_rules.gd")

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	var a = CoreRoot.actions
	state.grid.cells.clear()
	state.biz = {}
	state.money = 5000

	# Ways and wages.
	_expect(RULES.traits("pepa", "rest", 7) == RULES.traits("pepa", "rest", 7), "a person's ways are fixed in a camp")
	var quick_warm := RULES.wage("rest", 2, true, "warm")
	var slow_sour := RULES.wage("rest", 0, true, "sour")
	_expect(quick_warm > RULES.wage("rest", 1, true, "flat") and slow_sour < RULES.wage("rest", 1, true, "flat"), "the quick and pleasant dearer, the slow and sour cheaper")
	_expect(RULES.wage("rest", 1, false, "flat") < RULES.wage("rest", 1, true, "flat"), "a thief asks a little less")
	var jar := RULES.traits("jaromir", "rest", 7)
	_expect(str(jar["strange"]) == "night" and int(jar["speed"]) == 2 and bool(jar["honest"]) and int(jar["wage"]) < RULES.wage("rest", 2, true, "warm"), "the strange one is good and cheap (%s)" % str(jar))

	# Applicants.
	var ap1 := RULES.applicants("rest", "4:4", 5, [], 7)
	var ap2 := RULES.applicants("rest", "4:4", 5, [], 7)
	_expect(ap1 == ap2 and ap1.size() == 3, "three ask, the same on every machine (%d)" % ap1.size())
	var slugs := {}
	for p in ap1:
		slugs[str(p["slug"])] = true
		_expect((RULES.PEOPLE[str(p["slug"])]["asks"] as Array).has("rest"), "%s asks at a bistro" % str(p["slug"]))
	_expect(slugs.size() == 3, "three different people")
	var ap3 := RULES.applicants("rest", "4:4", 5, ["pepa", "hanka", "dvorakova"], 7)
	for p in ap3:
		_expect(not (str(p["slug"]) in ["pepa", "hanka", "dvorakova"]), "nobody already working asks (%s)" % str(p["slug"]))
	var strange := 0
	for d in 60:
		for p in RULES.applicants("vecerka", "8:8", d, [], 3):
			if str(p["strange"]) != "":
				strange += 1
	_expect(strange >= 6 and strange <= 30, "the strange ones turn up now and then (%d in 60 days)" % strange)

	# An old save's hand.
	state.grid.occupy_cell(Vector2i(4, 4), "restaurant", "restaurant_4_4", Vector2i(4, 4))
	state.biz = {"sites": {"4:4": {"kind": "rest", "stock": {"goulash": 12, "cheese": 10, "potatoes": 20, "dumplings": 15}, "staff": true, "staff_name": "Pepa", "since_day": 2,
		"today": RULES.empty_day(), "yesterday": RULES.empty_day()}}, "orders": [], "licences": []}
	var site: Dictionary = a.biz_site("4:4", "restaurant")
	_expect((site["crew"] as Array).size() == 1 and str(site["crew"][0]["slug"]) == "pepa" and str(site["crew"][0]["role"]) == "pass", "the old hand is Pepa at the pass (%s)" % str(site.get("crew", [])))
	_expect(int(site["lots"]["cheese"][0][0]) == 10, "the old shelves become a lot")

	# Who works now.
	GuestManager._last_known_hour = 10
	_expect(BUSINESS.shift_now(site) == "day", "ten in the morning: the day shift")
	_expect(BUSINESS.crew_now("4:4").size() == 1, "Pepa is in")
	a.biz_crew_note("4:4", "pepa", {"absent": CoreRoot.get_day()})
	_expect(BUSINESS.crew_now("4:4").is_empty(), "away today: not in")
	a.biz_crew_note("4:4", "pepa", {"absent": -1})
	GuestManager._last_known_hour = 21
	_expect(BUSINESS.shift_now(site) == "closed" and BUSINESS.crew_now("4:4").is_empty(), "nine at night, not open late: shut")
	a.biz_set_late("4:4", true)
	_expect(BUSINESS.shift_now(site) == "late" and BUSINESS.crew_now("4:4").is_empty(), "open late: the late shift (Pepa works days)")
	a.biz_set_job("4:4", "pepa", "pass", "late")
	_expect(BUSINESS.crew_now("4:4").size() == 1, "Pepa on the late shift")
	a.biz_set_job("4:4", "pepa", "pass", "day")
	a.biz_set_late("4:4", false)
	GuestManager._last_known_hour = 10

	# Away now and then; the strange ones never.
	var rt = BUSINESS.new()
	add_child(rt)
	for slug in ["hanka", "dvorakova", "marta"]:
		a.biz_hire("4:4", RULES.person(slug, "rest"), 1)
	var away := {}
	for d in range(100, 400):
		for p in site["crew"]:
			p["absent"] = -1
		rt._attendance("4:4", d)
		for p in site["crew"]:
			if int(p.get("absent", -1)) == d:
				away[str(p["slug"])] = int(away.get(str(p["slug"]), 0)) + 1
	_expect(int(away.get("marta", 0)) == 0, "Marta is never away")
	var normal := int(away.get("pepa", 0)) + int(away.get("hanka", 0)) + int(away.get("dvorakova", 0))
	_expect(normal >= 15 and normal <= 120, "the others now and then (%d in 900 shifts)" % normal)
	for p in site["crew"]:
		p["absent"] = -1

	# A dishonest hand leaves the books short; an honest one never.
	for p in site["crew"]:
		p["honest"] = str(p["slug"]) != "hanka"
	var short := 0
	for d in range(500, 540):
		site["today"]["short"] = 0
		rt._thieves("4:4", d)
		short += int(site["today"]["short"])
	_expect(short > 0, "the books come up short now and then (%d)" % short)
	for p in site["crew"]:
		p["honest"] = true
	site["today"]["short"] = 0
	for d in range(600, 640):
		rt._thieves("4:4", d)
	_expect(int(site["today"]["short"]) == 0, "honest hands take nothing")

	# The kitchen's hands at work.
	var k: KITCHEN = get_tree().get_first_node_in_group("kitchens")
	if k == null:
		k = KITCHEN.new()
		add_child(k)
	var ks := k.site("4:4")
	_expect(k._crew_cellar("4:4", false) and k.prep("4:4", "chips_raw") == 1, "the cellar cuts chips")
	k.act("4:4", "prep", ["cheese_raw", 1])
	k.act("4:4", "prep", ["chips_raw", -k.prep("4:4", "chips_raw")])
	_expect(k._crew_stove("4:4", false), "the stove lays a slice")
	var slot: Dictionary = ks["pan"][0]
	_expect(not slot.is_empty(), "a slice in the pan")
	slot["t"] = [BISTRO.CHEESE_GOLD + 3.0, 0.0]
	_expect(k._crew_stove("4:4", false) and int(ks["pan"][0]["down"]) == 1, "golden underneath: turned")
	ks["pan"][0]["t"] = [BISTRO.CHEESE_GOLD + 3.0, BISTRO.CHEESE_GOLD + 3.0]
	_expect(k._crew_stove("4:4", false) and k.prep("4:4", "cheese") == 1, "golden both sides: racked")
	var q: Array = (ks["q"] as Dictionary).get("cheese", [])
	_expect(q.size() == 1 and float(q[0]) > 0.9, "a slice from the middle of the window is good (%s)" % str(q))
	k.act("4:4", "plates", [0, 2])
	var clean0 := int(k.plates("4:4")["clean"])
	_expect(k._crew_sink("4:4", false) and int(k.plates("4:4")["clean"]) == clean0 + 1, "the sink washes a plate")

	print("")
	if _failures.is_empty():
		print("STAFF CHECK: PASS")
		get_tree().quit(0)
	else:
		print("STAFF CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
