extends RefCounted

## The camp by its departments, for the first page of CampStat 98 (Richard 8. 11.: from
## being there alone to the whole camp running by itself and "I only help out when needed",
## and "I must be told about everything, by notifications, or the more complex things by
## visiting the businesses or on the PC; think of something clever and simple"). One row a
## department: who runs it (somebody, or You), how it stands, the button that sees to it.
## You read off it what still hangs on you; a camp with a full crew is a green column.
## Read off what is there, nothing kept. Rows: {dept, who ([names], empty: you), state,
## level (RUNS, YOURS, WRONG), btn, act, on}.

const STAFF := preload("res://core/systems/staff_rules.gd")
const BIZ := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const MAINT := preload("res://core/systems/maintenance_rules.gd")
const LANG := preload("res://scripts/lang.gd")

const RUNS := 0
const YOURS := 1
const WRONG := 2


## Who of the staffroom's hands is set to `job` and works here (today or from tomorrow).
static func _hands(crew: Array, job: String, also_desk := false) -> Array:
	var out: Array = []
	for p in crew:
		if not STAFF.does(p, job) or (job != "desk" and not also_desk and STAFF.does(p, "desk")):
			continue
		out.append(str((p as Dictionary).get("name", "")))
	return out


static func _row(dept: String, who: Array, state: String, wrong: bool, btn := "", act := "", on := true) -> Dictionary:
	var level := RUNS if not who.is_empty() else YOURS
	if wrong:
		level = WRONG
	return {"dept": dept, "who": who, "state": state, "level": level, "btn": btn, "act": act, "on": on}


## `snap`: the electricity's (CampStat has it), `upkeep`: main's, `forecast`: the night's.
static func rows(main: Node, snap: Dictionary, upkeep: Dictionary, forecast: Dictionary) -> Array:
	var out: Array = []
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or not (state.biz is Dictionary) or GuestManager == null:
		return out
	var biz: Dictionary = state.biz
	var crew: Array = (biz.get("staff", {}) as Dictionary).get("crew", [])
	# Somebody to take on: with no staffroom to put them in, that first.
	var has_room := false
	var blocks := 0
	for coord in state.grid.cells.keys():
		var c: Dictionary = state.grid.cells[coord]
		if c.get("root_coord", coord) != coord:
			continue
		has_room = has_room or str(c.get("type", "")) == "staffroom"
		if str(c.get("type", "")) in ["toilet_block", "shower_block"]:
			blocks += 1
	var hire := [LANG.f("Hire"), "tab://staff_app"] if has_room else [LANG.f("Staffroom"), "tab://builder"]

	# The reception.
	var at_desk := 0
	var coming := 0
	for r in GuestManager.get_arrivals():
		if bool((r as Dictionary).get("at_gate", false)):
			at_desk += 1
		else:
			coming += 1
	var desk := _hands(crew, "desk")
	var line := LANG.f("%d at the desk", at_desk) if at_desk > 0 else (LANG.f("%d on the way", coming) if coming > 0 else LANG.f("Nobody waiting"))
	var row := _row(LANG.f("Reception"), desk, line, at_desk > 0 and desk.is_empty())
	if at_desk + coming > 0:
		row["btn"] = "GuestRack"
		row["act"] = "tab://guestrack"
	elif desk.is_empty():
		row["btn"] = hire[0]
		row["act"] = hire[1]
	out.append(row)

	# The letters.
	var letters := 0
	if EmailManager != null:
		for m in EmailManager.inbox:
			if m is Dictionary and EmailManager._is_customer_mail(m) and not bool((m as Dictionary).get("_actioned", false)):
				letters += 1
	var writers: Array = []
	for n in desk:
		for p in crew:
			if str((p as Dictionary).get("name", "")) == str(n) and STAFF.does(p, "letters"):
				writers.append(n)
	row = _row(LANG.f("Bookings"), writers, LANG.f("%d letters", letters) if letters > 0 else LANG.f("No letters"), letters > 0 and writers.is_empty())
	if letters > 0:
		row["btn"] = "CampMail"
		row["act"] = "tab://mail"
	out.append(row)

	# The lodgings.
	var to_do: Array = []
	var keys: Array = state.accommodation_states.keys()
	keys.sort()
	for key in keys:
		var rs: Dictionary = GuestManager.get_room_state(str(key))
		if not rs.is_empty() and str(rs.get("status", "")) != "ready" and not bool(rs.get("occupied", false)):
			to_do.append(str(key))
	var housekeepers := _hands(crew, "rooms")
	row = _row(LANG.f("Accommodation"), housekeepers, LANG.f("%d to make up", to_do.size()) if not to_do.is_empty() else LANG.f("All made up"), not to_do.is_empty() and housekeepers.is_empty())
	if not to_do.is_empty():
		row["btn"] = LANG.f("Show")
		row["act"] = "map://%s" % to_do[0]
	elif housekeepers.is_empty():
		row["btn"] = hire[0]
		row["act"] = hire[1]
	out.append(row)

	# The toilets and the showers.
	var dirty := 0
	var first_block := ""
	for coord in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[coord]
		if str(cell.get("type", "")) in ["toilet_block", "shower_block"] and cell.get("root_coord", coord) == coord and float(cell.get("maintenance", 1.0)) < MAINT.DIRTY_AT:
			dirty += 1
			first_block = "%d:%d" % [coord.x, coord.y]
	var cleaners := _hands(crew, "blocks")
	if blocks > 0:
		row = _row(LANG.f("Toilets and showers"), cleaners, LANG.f("%d to clean", dirty) if dirty > 0 else LANG.f("All clean"), dirty > 0 and cleaners.is_empty())
		if dirty > 0:
			row["btn"] = LANG.f("Show")
			row["act"] = "map://%s" % first_block
		out.append(row)

	# What is out of order.
	var broken := 0
	for u in upkeep.get("rows", []):
		if u is Dictionary and bool((u as Dictionary).get("broken", false)):
			broken += 1
	var worn := int(upkeep.get("crew_jobs", 0))
	var menders := _hands(crew, "repairs")
	var fix_line := LANG.f("%d out of order", broken) if broken > 0 else (LANG.f("%d lamps burning low", worn) if worn > 0 else LANG.f("In order"))
	row = _row(LANG.f("Repairs"), menders, fix_line, broken > 0 and menders.is_empty())
	if worn > 0:
		row["btn"] = LANG.f("Crew $%d", int(upkeep.get("crew_cost", 0)))
		row["act"] = "crew://all"
		row["on"] = not bool(upkeep.get("night", false))
	out.append(row)

	# Round the camp: the rubbish, the raccoons, a branch, the boy, the noise.
	var open_ev := 0
	var de = main.get("_day_events") if main != null else null
	if de != null:
		for ev in de.open_events():
			if str((ev as Dictionary).get("kind", "")) != "delivery":
				open_ev += 1
	var porters := _hands(crew, "litter")
	out.append(_row(LANG.f("Round the camp"), porters, LANG.f("%d to see to", open_ev) if open_ev > 0 else LANG.f("Quiet"), open_ev > 0 and porters.is_empty()))

	# The goods.
	var sites: Dictionary = biz.get("sites", {})
	var low := ""
	var low_auto := true
	var runtime = main.get("_interior_manager").get("business") if main != null and main.get("_interior_manager") != null else null
	var live: Dictionary = runtime._live_sites() if runtime != null and runtime.has_method("_live_sites") else {}
	var site_keys: Array = live.keys()
	site_keys.sort()
	for key in site_keys:
		var s: Dictionary = sites.get(key, {})
		var kind := str(s.get("kind", ""))
		for g in BIZ.goods(kind):
			if BIZ.kept(kind, g) and BIZ.is_low(kind, g, int((s.get("stock", {}) as Dictionary).get(g, 0))) and BUSINESS.on_order(str(key), g) <= 0:
				if low == "":
					low = LANG.f(str((BIZ.goods(kind)[g] as Dictionary).get("label", "")))
				low_auto = low_auto and BIZ.orders_itself(s)
	var orders: Array = biz.get("orders", [])
	var carriers := _hands(crew, "delivery")
	if not site_keys.is_empty():
		var goods_line := LANG.f("Low: %s", low) if low != "" else (LANG.f("Van on the way") if not orders.is_empty() else LANG.f("Shelves full"))
		out.append(_row(LANG.f("Goods"), carriers, goods_line, low != "" and not low_auto, LANG.f("Order"), "tab://shops"))

	# The places, each with who is on now.
	for key in site_keys:
		var s: Dictionary = sites.get(key, {})
		var kind := str(s.get("kind", ""))
		var name := LANG.f(str((BIZ.KINDS.get(kind, {}) as Dictionary).get("name", "Business")))
		var on_now: Array = BUSINESS.crew_now(str(key))
		var books: Array = s.get("crew", [])
		var names: Array = []
		for p in (on_now if not on_now.is_empty() else books):
			names.append(str((p as Dictionary).get("name", "")))
		var shut := BUSINESS.shift_now(s) == "closed"
		var waiting: int = runtime.waiting_at(str(key)) if runtime != null else 0
		var how := LANG.f("Closed") if shut else (LANG.f("%d waiting", waiting) if waiting > 0 else LANG.f("$%d today", int((s.get("today", {}) as Dictionary).get("takings", 0))))
		# On the books and nobody in (away today, or on their way): it is on you for now.
		if not shut and on_now.is_empty() and not books.is_empty():
			names = []
			if waiting == 0:
				how = LANG.f("Nobody in today")
		row = _row(name, names, how, waiting > 0)
		if books.is_empty():
			row["btn"] = hire[0]
			row["act"] = hire[1]
		else:
			row["btn"] = LANG.f("Show")
			row["act"] = "map://%s" % str(key)
		out.append(row)

	# The electricity.
	var unpaid := int(snap.get("unpaid_total", 0))
	var overdue := int(snap.get("overdue_count", 0))
	var payers := _hands(crew, "desk")
	row = _row(LANG.f("Electricity"), payers, LANG.f("$%d to pay", unpaid) if unpaid > 0 else LANG.f("Paid"), overdue > 0 or bool(snap.get("power_cut_active", false)))
	if unpaid > 0:
		row["btn"] = LANG.f("Pay all $%d", unpaid)
		row["act"] = "payall://"
	out.append(row)

	# Tonight: the night is always yours.
	var tot: Dictionary = forecast.get("totals", {}) if forecast.get("totals", {}) is Dictionary else {}
	var certain := int(tot.get("guaranteed_spawns", 0))
	var expected := float(tot.get("expected_spawns", 0.0))
	if main == null or not main.has_method("camp_rule") or bool(main.camp_rule("threats")):
		row = _row(LANG.f("Tonight"), [], LANG.f("Something is coming") if certain > 0 else (LANG.f("May not be quiet") if expected > 0.3 else LANG.f("Quiet")), certain > 0)
		row["btn"] = LANG.f("Night")
		row["act"] = "page://night"
		out.append(row)
	return out


## Up to two names and how many more.
static func names_short(who: Array) -> String:
	if who.is_empty():
		return ""
	var head: Array = []
	for i in mini(1, who.size()):
		head.append(str(who[i]).replace("Mrs ", ""))
	var text := ", ".join(head)
	return text if who.size() <= 1 else "%s +%d" % [text, who.size() - 1]
