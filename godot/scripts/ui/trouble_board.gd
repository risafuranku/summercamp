extends RefCounted

## What the HUD's plates on the right list (hud_manager.set_troubles; out of main.gd
## 15. 11.): the camp's troubles in one list. A lodging somebody is on the way to first,
## the day's open events with their time running out, the night's open jobs, the
## businesses with guests waiting, the office's letters and bills, the people only to know
## about (away, owed, gone), the housework (lodgings, toilets and showers, a spent lamp,
## a woodpile run low), the goods running out. mark_taken() then says who is seeing to
## each and orders them: waiting for somebody, only to know, somebody coming, seen to.
## The same on every co-op machine (all of it is the host's state). main.gd asks for it
## twice a second (_poll_arrivals).

const STAFF_RULES_M = preload("res://core/systems/staff_rules.gd")
const CREW_PLACES_M = preload("res://scripts/business/crew_places.gd")
const BIZ_RULES_M = preload("res://core/systems/business_rules.gd")
const BIZ_RUNTIME_M = preload("res://scripts/business/business_runtime.gd")
const WORK_RULES = preload("res://core/systems/maintenance_rules.gd")
const WORK_BLOCK_DIRTY: float = WORK_RULES.DIRTY_AT
## A business's kind as its plate's picture and word.
const TROUBLE_KIND := {"rest": "rest", "pub": "pub", "vecerka": "vecerka", "corn": "stand"}
const TROUBLE_WORD := {"rest": "Bistro", "pub": "Pub", "vecerka": "Jednota", "corn": "Corn"}

var main: Node


func _init(main_node: Node) -> void:
	main = main_node


## Who has which job on now (STAFF_RULES.taken: "room:<key>", "ev:<id>", "room:desk"...).
func taken() -> Dictionary:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or not (state.biz is Dictionary):
		return {}
	var staff = (state.biz as Dictionary).get("staff", {})
	return STAFF_RULES_M.taken(staff) if staff is Dictionary else {}


## What is seen to: who has it on the row ("who": a hand's slug; "@" another warden at the
## counter; "~" no one yet but somebody on shift is set to it: Richard's P30, "which will be
## seen to and which I can go to"), those plates after the ones still waiting for somebody,
## and the ones only to know about (a face: somebody away, gone, owed) between the two.
func mark_taken(rows: Array) -> Array:
	var held := taken()
	var state = CoreRoot.get_state() if CoreRoot != null else null
	var staff = (state.biz as Dictionary).get("staff", {}) if state != null and state.biz is Dictionary else {}
	var free: Array = []
	var told: Array = []
	var coming: Array = []
	var seen_to: Array = []
	for row_any in rows:
		var r: Dictionary = row_any
		var id := str(r.get("id", ""))
		var who := ""
		match str(r.get("cat", "")):
			"day":
				who = str(held.get("ev:" + id.substr(1), ""))
			"work":
				var key := id.substr(1)
				who = str(held.get("room:" + key, ""))
				if who == "":
					# A block's ("x:y", its halves "x:yl"): the hand cleans it all.
					var block := key.rstrip("lr")
					who = str(held.get("room:block:" + block, ""))
			"biz":
				var site_key := id.substr(1)
				var t := "corn" if str(r.get("kind", "")) == "corn" else "service"
				if not CREW_PLACES_M.wardens_at(main.get_tree(), site_key, t).is_empty():
					who = "@"
		if who == "" and str(r.get("fix", "")) != "":
			who = str(held.get("room:fix:" + str(r["fix"]), ""))
		if who == "" and str(r.get("job", "")) != "" and staff is Dictionary and STAFF_RULES_M.covered(staff, str(r["job"]), main._time_of_day_hours, main._day_index):
			who = "~"
		if who == "~":
			r["who"] = who
			coming.append(r)
		elif who != "":
			r["who"] = who
			seen_to.append(r)
		elif r.has("face"):
			told.append(r)
		else:
			free.append(r)
	return free + told + coming + seen_to


## The camp's troubles for the HUD's plates (scripts/ui/trouble_strip.gd): the day's open
## events with their time running out, the night's open jobs, the businesses with guests
## waiting and how many. The same on every co-op machine (all three are the host's).


func rows(biz) -> Array:
	var rows: Array = []
	var abs_minute: int = (maxi(1, main._day_index) - 1) * 1440 + main._clock_minutes_from_hours(main._time_of_day_hours)
	# A lodging somebody is on the way to before anything else.
	var work := work_rows()
	for r in work:
		if (r as Dictionary).has("wanted"):
			rows.append(r)
	if main._day_events != null and main.camp_rule("events"):
		for ev in main._day_events.open_events():
			# (The van has its own plate over these: set_van.)
			if str(ev.get("kind", "")) == "delivery":
				continue
			var span := float(int(ev.get("deadline", 0)) - int(ev.get("at", 0)))
			var left := clampf(float(int(ev.get("deadline", 0)) - abs_minute) / span, 0.0, 1.0) if span > 0.0 else -1.0
			var day_row := {"id": "d%s" % str(ev.get("id", "")), "kind": str(ev.get("kind", "")), "word": str(ev.get("short", "")), "cat": "day", "left": left}
			if not STAFF_RULES_M.LATE_KINDS.has(str(ev.get("kind", ""))):
				day_row["job"] = str(ev.get("kind", ""))
			rows.append(day_row)
	if main._night_jobs != null:
		for job in main._night_jobs.open_jobs():
			if str(job.get("kind", "")) == "toilet":
				# The bowl by the name its plates have.
				var jc: Array = job.get("coord", [0, 0])
				var wcs: Array = _wc_blocks()
				job["short"] = _wc_word("r", _wc_no(wcs, Vector2i(int(jc[0]), int(jc[1]))))
			var night_row := {"id": "n%s@%d" % [str(job.get("kind", "")), int(job.get("at", 0))], "kind": str(job.get("kind", "")), "word": str(job.get("short", "")), "cat": "night", "left": -1.0}
			# What a hand can put right in the morning (the sewer and the board are not).
			if str(job.get("kind", "")) in ["lamp", "toilet", "frozen"] and job.get("coord", []) is Array and (job["coord"] as Array).size() == 2:
				night_row["job"] = "repairs"
				night_row["fix"] = "%d:%d" % [int(job["coord"][0]), int(job["coord"][1])]
			elif str(job.get("kind", "")) == "breaker":
				night_row["job"] = "repairs"
				night_row["fix"] = "breaker"
			rows.append(night_row)
	if biz != null and biz.has_method("waiting_sites"):
		for site in biz.waiting_sites():
			var kind := str(biz.site(str(site["key"])).get("kind", ""))
			rows.append({"id": "b%s" % str(site["key"]), "kind": str(TROUBLE_KIND.get(kind, "pub")), "word": str(TROUBLE_WORD.get(kind, "Guests")), "cat": "biz", "left": -1.0, "n": int(site["n"])})
	rows.append_array(_office_rows())
	rows.append_array(_people_rows())
	for r in work:
		if not (r as Dictionary).has("wanted"):
			rows.append(r)
	if biz != null and biz.has_method("_live_sites"):
		rows.append_array(_stock_rows(biz))
	return rows


## The office's own (Richard 8. 11.: "I must be told about everything"): the booking letters
## nobody has answered, the electricity coming due. Neither with somebody at the desk to
## see to them: it is the letters' plate that goes, not the letters.
func _office_rows() -> Array:
	var rows: Array = []
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or not (state.biz is Dictionary):
		return rows
	var crew: Array = ((state.biz as Dictionary).get("staff", {}) as Dictionary).get("crew", [])
	var desk := false
	var letters := false
	for p in crew:
		if STAFF_RULES_M.does(p, "desk") and int((p as Dictionary).get("since", 0)) <= main._day_index:
			desk = true
			letters = letters or STAFF_RULES_M.does(p, "letters")
	if not letters and EmailManager != null:
		var n := 0
		for m in EmailManager.inbox:
			if m is Dictionary and EmailManager._is_customer_mail(m) and not bool(m.get("_actioned", false)):
				n += 1
		if n > 0:
			rows.append({"id": "mletters", "kind": "mail", "word": "Bookings", "cat": "desk", "left": -1.0, "n": n})
	if not desk and main._billing != null:
		var soonest := 99
		var due := 0
		for b in main._billing.bills:
			if b is Dictionary and str((b as Dictionary).get("status", "unpaid")).to_lower() != "paid":
				due += 1
				soonest = mini(soonest, int(main._billing.days_left_until_due(int((b as Dictionary).get("due_day", main._day_index)))))
		if due > 0 and soonest <= 1:
			rows.append({"id": "ebill", "kind": "bill", "word": "Electricity", "cat": "desk", "left": 0.0 if soonest < 0 else clampf(float(soonest + 1) / 3.0, 0.0, 1.0), "n": due})
	return rows


## The people, only to know about: their face and a word. Away today, walked out over
## their pay (today), owed. Neutral words: they come out the same for anybody.
func _people_rows() -> Array:
	var rows: Array = []
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or not (state.biz is Dictionary):
		return rows
	var biz: Dictionary = state.biz
	var people: Array = []
	for key in biz.get("sites", {}):
		people.append_array(((biz["sites"] as Dictionary)[key] as Dictionary).get("crew", []))
	people.append_array((biz.get("staff", {}) as Dictionary).get("crew", []))
	for p_any in people:
		var p: Dictionary = p_any
		var slug := str(p.get("slug", ""))
		if int(p.get("absent", -1)) == main._day_index:
			rows.append({"id": "a" + slug, "kind": "someone", "face": slug, "word": "Away", "cat": "people", "left": -1.0})
		elif int(p.get("owed", 0)) > 0:
			rows.append({"id": "o" + slug, "kind": "wages", "face": slug, "word": "Owed", "cat": "people", "left": -1.0})
	for g_any in biz.get("gone", []):
		var g: Dictionary = g_any
		if int(g.get("day", -1)) == main._day_index:
			rows.append({"id": "g" + str(g.get("slug", "")), "kind": "someone", "face": str(g.get("slug", "")), "word": "Resigned", "cat": "people", "left": -1.0})
	return rows


## What is running out at the businesses (the user 4. 11.: "the game does not tell me in
## any way that the goods at the businesses are running out or gone. What about a
## notification on the right?"): a plate for each place with something low on its shelves
## (BusinessRules.is_low: red on its desk and in its program) and not on the van: the
## place's picture, the worst of it named, the bar what is left of it (empty and blinking:
## none).


func _stock_rows(biz) -> Array:
	var rows: Array = []
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or not (state.biz is Dictionary):
		return rows
	var sites: Dictionary = (state.biz as Dictionary).get("sites", {})
	var live: Dictionary = biz._live_sites()
	for key in live:
		var s: Dictionary = sites.get(key, {})
		if s.is_empty():
			continue
		var kind := str(s.get("kind", ""))
		var gd: Dictionary = BIZ_RULES_M.goods(kind)
		var worst := ""
		var worst_k := 2.0
		for g in gd:
			# (The ready-made extras nobody has to keep: none on the shelf to start with.)
			if int((gd[g] as Dictionary).get("start", 0)) <= 0:
				continue
			var n := int((s.get("stock", {}) as Dictionary).get(g, 0))
			if not BIZ_RULES_M.is_low(kind, g, n) or BIZ_RUNTIME_M.on_order(str(key), g) > 0:
				continue
			var k := float(n) / maxf(1.0, float(int((gd[g] as Dictionary).get("pack", 1)) / 2))
			if k < worst_k:
				worst_k = k
				worst = g
		if worst != "":
			rows.append({"id": "s%s" % str(key), "kind": str(TROUBLE_KIND.get(kind, "pub")), "word": str((gd[worst] as Dictionary).get("label", "")), "cat": "stock", "left": clampf(worst_k, 0.0, 1.0)})
	return rows


## The camp's housework as plates too (playtest 25. 10.: "an unswept or unmade tent, cabin
## and so on as a notification with an icon on the right; the showers have no notice they
## want cleaning"): each empty lodging that is dirty (the broom) or not made up (the
## linen), each toilet and shower block worn into wanting a clean (as its own room's list
## has it: mess_rules.block_tasks) or broken.


func work_rows() -> Array:
	var rows: Array = []
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or GuestManager == null:
		return rows
	# Who is coming for which lodging (key -> minutes till they are here, 0 at the desk): its
	# plate has their time under its word and goes to the top (Richard 8. 11.).
	var wanted := {}
	for row_any in GuestManager.get_arrivals():
		var row: Dictionary = row_any
		var mins := 0 if bool(row.get("at_gate", false)) else int(row.get("minutes", 0))
		for room_any in row.get("rooms", []):
			var room_key := str((room_any as Dictionary).get("key", ""))
			if mins < int(wanted.get(room_key, 1 << 20)):
				wanted[room_key] = mins
	var keys: Array = state.accommodation_states.keys()
	keys.sort_custom(func(a, b): return int(wanted.get(str(a), 1 << 20)) < int(wanted.get(str(b), 1 << 20)))
	for key in keys:
		var rs: Dictionary = GuestManager.get_room_state(str(key))
		if rs.is_empty() or bool(rs.get("occupied", false)):
			continue
		var st := str(rs.get("status", ""))
		if st != "dirty" and st != "unprepared":
			continue
		var kind := GuestManager.lodging_kind(str(rs.get("building_type", "")))
		var no: int = GuestManager.room_number(str(key))
		var word := tr(kind.capitalize()) + (" %d" % no if no > 0 else "")
		var r2 := {"id": "w%s" % str(key), "kind": "clean" if st == "dirty" else "bed", "word": word, "cat": "work", "left": -1.0, "job": "rooms"}
		if wanted.has(str(key)):
			r2["wanted"] = true
			r2["left"] = clampf(float(int(wanted[str(key)])) / float(STAFF_RULES_M.WANTED_WITHIN_MIN), 0.0, 1.0)
		rows.append(r2)
	var wcs: Array = _wc_blocks()
	for coord in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[coord]
		var t := str(cell.get("type", ""))
		if (t != "toilet_block" and t != "shower_block") or cell.get("root_coord", coord) != coord:
			continue
		var bkey := "%d:%d" % [coord.x, coord.y]
		var broken: bool = state.failures.has(bkey)
		if t == "toilet_block":
			# A plate for each toilet, the one that is dirty (the user 5. 11.: "both toilets
			# dirty", and only the one was); the one a breakdown is in (the right-hand bowl:
			# mess_rules.BLOCK_BREAKDOWN) has one too, and only the one: the night's own when
			# it is a night's job (7. 11.: "as if there were two kinds of toilet plate").
			var paged := _job_on(coord)
			for side in WORK_RULES.SIDES:
				var blocked: bool = broken and side == "r"
				if paged and side == "r":
					continue
				if blocked or WORK_RULES.side_condition(cell, side) < WORK_BLOCK_DIRTY:
					var wc_row := {"id": "w%s%s" % [bkey, side], "kind": "toilet", "word": _wc_word(side, _wc_no(wcs, coord)), "cat": "work", "left": -1.0, "job": "repairs" if blocked else "blocks"}
					if blocked:
						wc_row["fix"] = bkey
					rows.append(wc_row)
			continue
		elif float(cell.get("maintenance", 1.0)) >= WORK_BLOCK_DIRTY and not broken:
			continue
		var sh_row := {"id": "w%s" % bkey, "kind": "shower", "word": tr("Showers"), "cat": "work", "left": -1.0, "job": "repairs" if broken else "blocks"}
		if broken:
			sh_row["fix"] = bkey
		rows.append(sh_row)
	# A lamp gone out by itself (its bulb spent; the night's own have their night plate).
	for fkey in state.failures.keys():
		var f: Dictionary = state.failures[fkey]
		if str(f.get("type", "")) != "lamp_post" or bool(f.get("night", false)):
			continue
		rows.append({"id": "l%s" % str(fkey), "kind": "lamp", "word": "Lamp", "cat": "day", "left": -1.0, "job": "repairs", "fix": str(fkey)})
	# A bonfire's woodpile run low (playtest 14. 11.: the guests feed the fire from it): what is
	# left of it on the plate, split at the block or by a hand with Firewood.
	for f in main.get_tree().get_nodes_in_group("campfire"):
		if int(f.WOODPILE_LOGS) - int(f.logs_left) < STAFF_RULES_M.WOOD_LOW:
			continue
		rows.append({"id": "f%s" % str(f.site_key()), "kind": "wood", "word": tr("Firewood"), "cat": "work", "left": float(f.logs_left) / float(f.WOODPILE_LOGS), "job": "wood"})
	return rows


## Tonight's job open on this block?
func _job_on(coord: Vector2i) -> bool:
	if main._night_jobs == null:
		return false
	for job in main._night_jobs.open_jobs():
		var c = job.get("coord", [])
		if c is Array and (c as Array).size() == 2 and Vector2i(int(c[0]), int(c[1])) == coord:
			return true
	return false


## The block's number on its plates, 0 with only the one.
func _wc_no(wcs: Array, coord: Vector2i) -> int:
	return wcs.find(coord) + 1 if wcs.size() > 1 else 0


func _wc_blocks() -> Array:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	var out: Array = []
	if state == null:
		return out
	for coord in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[coord]
		if str(cell.get("type", "")) == "toilet_block" and cell.get("root_coord", coord) == coord:
			out.append(coord)
	out.sort()
	return out


## A toilet's name on its plate: its side, with `no` the block's number when there are more.
func _wc_word(side: String, no: int) -> String:
	if no > 0:
		return tr("WC %d left" if side == "l" else "WC %d right") % no
	return tr("WC left" if side == "l" else "WC right")
