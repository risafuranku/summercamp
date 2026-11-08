extends "res://tools/shot_driver.gd"

## The camp run without you (Richard 8. 11.: "when I have plenty of staff the whole camp
## should run by itself and I only help out now and then"): a whole camp built and staffed
## at the start, then days on a fast clock with nobody at the keys. An hourly line of what
## stands and what has piled up, a day's sums; "PROVOZ ..." lines.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/provoz_check.tscn -- --out=DIR [--days=4] [--speed=24] [--hands=full|none] [--accept=1] [--verbose]
## --accept=1: this script answers every letter as the player would; the default leaves the
## post to whoever is at the desk.

const C := "get_tree().root.get_node('ProvozCheck')"
const BRT := preload("res://core/systems/business_rules.gd")
const STAFF := preload("res://core/systems/staff_rules.gd")

var _days := 4
var _speed := 24.0
var _hands := "full"
var _accept := false
## --verbose: every three hours each guest's needs and what they are at, the bistro's kitchen.
var _verbose := false
## --money: at 11:00 on the last day every book and every office program, with the days' real
## numbers in them; "PROVOZ money" lines say what the camp's own book holds each night.
var _money := false
var _last_hour := -1
var _start_day := 1
var _running := false
var _day_stats: Dictionary = {}
var _keys: Dictionary = {}


func _stat(k: String, n := 1) -> void:
	_day_stats[k] = int(_day_stats.get(k, 0)) + n


func camp() -> void:
	var g: Vector2i = _main.get("world_generator").gate_tile()
	for y0 in range(4, 19, 5):
		for x0 in range(g.x - 13, g.x + 12, 5):
			EventBus.RequestDemolish.emit(Rect2i(x0, y0, 5, 5))
	for y in range(5, 19):
		EventBus.RequestBuild.emit("path", Vector2i(g.x, y), 0)
	for x in range(g.x - 13, g.x + 12):
		if x != g.x:
			EventBus.RequestBuild.emit("path", Vector2i(x, 8), 0)
			EventBus.RequestBuild.emit("path", Vector2i(x, 14), 0)
	var plan := [
		["lamp_post", Vector2i(g.x + 1, 6)],
		["tent_1", Vector2i(g.x - 2, 6)], ["tent_1", Vector2i(g.x - 4, 6)], ["tent_1", Vector2i(g.x - 6, 6)], ["tent_1", Vector2i(g.x - 8, 6)],
		["tent_1", Vector2i(g.x - 2, 9)], ["tent_1", Vector2i(g.x - 4, 9)],
		["cabin_1", Vector2i(g.x + 2, 6)], ["cabin_1", Vector2i(g.x + 5, 6)], ["cabin_1", Vector2i(g.x + 8, 6)],
		["caravan_1", Vector2i(g.x + 2, 9)], ["caravan_1", Vector2i(g.x + 5, 9)],
		["toilet_block", Vector2i(g.x - 10, 6)], ["toilet_block", Vector2i(g.x + 11, 7)],
		["shower_block", Vector2i(g.x - 11, 6)], ["shower_block", Vector2i(g.x + 11, 9)],
		["corn_stand", Vector2i(g.x - 2, 12)],
		["pub", Vector2i(g.x - 6, 12)],
		["restaurant", Vector2i(g.x + 2, 12)],
		["vecerka", Vector2i(g.x + 5, 11)],
		["staffroom", Vector2i(g.x - 10, 12)],
		["bonfire", Vector2i(g.x - 12, 9)],
		["lamp_post", Vector2i(g.x - 5, 8 - 1)], ["lamp_post", Vector2i(g.x + 5, 15)],
	]
	for item in plan:
		EventBus.RequestBuild.emit(str(item[0]), item[1], 0)
	print("PROVOZ camp asked for")


func staff() -> void:
	var a = CoreRoot.actions
	var day: int = CoreRoot.get_day()
	var built := {}
	for c in CoreRoot.get_state().grid.cells:
		var d: Dictionary = CoreRoot.get_state().grid.cells[c]
		if d.get("root_coord", c) == c:
			built[str(d.get("type", ""))] = int(built.get(str(d.get("type", "")), 0)) + 1
	print("PROVOZ built ", built)
	CoreRoot.apply_changes({"money": 60000})
	if _hands != "full":
		return
	var taken: Array = []
	var biz = _main.get("_interior_manager").get("business")
	biz._process(2.0)
	var live: Dictionary = biz._live_sites()
	for key in live:
		a.biz_site(key, live[key])
		var kind: String = BRT.kind_of(str(live[key]))
		_keys[key] = kind
		var roles: Array = BRT.ROLES.get(kind, [])
		var want: int = {"corn": 1, "pub": 2, "rest": 3, "vecerka": 2}.get(kind, 1)
		for i in want:
			var p := _person(kind, taken)
			if p.is_empty():
				break
			p["role"] = str(roles[i][0])
			a.biz_hire(key, p, day - 1)
		# Well stocked from the start.
		print("PROVOZ site %s %s crew %s" % [key, kind, str(CoreRoot.get_state().biz["sites"][key]["crew"].map(func(x): return "%s/%s" % [x["slug"], x["role"]]))])
	a.staff_add_gear("locker")
	a.staff_add_gear("locker")
	a.staff_add_gear("armchair")
	var names := ["hanka", "dvorakova", "mirek", "zdenka", "ivan"]
	for i in names.size():
		if taken.has(names[i]):
			continue
		var p := BRT.person(names[i], "staff", 0)
		p["jobs"] = STAFF.default_jobs()
		a.staff_hire(p, day - 1)
		taken.append(names[i])
	var crew: Array = a.staff_state().get("crew", [])
	if not crew.is_empty():
		a.staff_set_job(str(crew[0]["slug"]), "desk", true)
	print("PROVOZ staff ", crew.map(func(x): return x["slug"]))


func _person(kind: String, taken: Array) -> Dictionary:
	for slug in BRT.PEOPLE:
		if taken.has(slug) or str(BRT.PEOPLE[slug].get("strange", "")) != "" or slug in ["hanka", "dvorakova", "mirek", "zdenka", "ivan"]:
			continue
		if (BRT.PEOPLE[slug]["asks"] as Array).has(kind):
			taken.append(slug)
			return BRT.person(slug, kind, 0)
	for slug in BRT.PEOPLE:
		if not taken.has(slug) and str(BRT.PEOPLE[slug].get("strange", "")) == "" and not (slug in ["hanka", "dvorakova", "mirek", "zdenka", "ivan"]):
			taken.append(slug)
			return BRT.person(slug, kind, 0)
	return {}


func go() -> void:
	_start_day = int(_main.get("_day_index"))
	_running = true
	Engine.time_scale = _speed
	EventBus.guest_gave_up.connect(func(_r): _stat("gave_up"))
	EventBus.guest_checked_in.connect(func(_r): _stat("checked_in"))
	EventBus.customer_booking_confirmed.connect(func(_r): _stat("booked"))
	EventBus.guest_review_posted.connect(func(r):
		_stat("reviews")
		_stat("stars", int(r.get("rating", 0)))
		print("PROVOZ review %d mood %.0f %s: %s" % [int(r.get("rating", 0)), float(r.get("mood", 0.0)), str(r.get("archetype", "")), str(r.get("text", ""))]))
	var hud = _main.get("_hud_manager")
	if hud != null and hud.has_signal("status_pushed"):
		pass


func _plates() -> Array:
	var biz = _main.get("_interior_manager").get("business")
	var rows: Array = _main.call("_mark_taken", _main.call("_trouble_rows", biz))
	return rows.map(func(r): return "%s%s" % [str(r.get("word", "")), "(%s)" % str(r["who"]) if r.has("who") else ""])


func _process(delta: float) -> void:
	super._process(delta)
	if not _running or _main == null:
		return
	if _main.has_method("_set_player_health") and int(_main.get("_player_health")) < 60:
		_main.call("_set_player_health", 100, false)
	var ts = _main.get("time_system")
	var h := int(float(ts.get("time_of_day_hours")))
	var day := int(_main.get("_day_index"))
	if h == _last_hour:
		return
	_last_hour = h
	var st = CoreRoot.get_state()
	var counts := {"expected": 0, "waiting": 0, "active": 0, "other": 0}
	for g in st.guests:
		var s := str((g as Dictionary).get("status", ""))
		if counts.has(s):
			counts[s] += 1
		else:
			counts["other"] += 1
	var dirty := 0
	var ready := 0
	for key in st.accommodation_states:
		var rs: Dictionary = GuestManager.get_room_state(str(key))
		if bool(rs.get("occupied", false)):
			continue
		if str(rs.get("status", "")) == "ready":
			ready += 1
		else:
			dirty += 1
	var unread: int = EmailManager.get_unread_count()
	var acts: Dictionary = (st.biz.get("staff", {}) as Dictionary).get("act", {})
	var doing: Array = []
	for slug in acts:
		var a: Dictionary = acts[slug]
		var what := str(a.get("what", (a.get("next", {}) as Dictionary).get("what", "")))
		doing.append("%s:%s%s" % [str(slug).substr(0, 3), str(a.get("do", "")), ("/" + what) if what != "" else ""])
	var bill_snap: Dictionary = _main.call("get_electricity_ui_snapshot") if _main.has_method("get_electricity_ui_snapshot") else {}
	print("PROVOZ d%d %02d:00 $%d mail %d exp %d wait %d act %d free r/d %d/%d bills %s plates %s | %s" % [day, h, int(st.money), unread, counts["expected"], counts["waiting"], counts["active"], ready, dirty,
		str(bill_snap.get("unpaid_count", "?")), str(_plates()), " ".join(doing)])
	if _verbose and h % 3 == 0 and h >= 9 and h <= 21:
		for g5 in st.guests:
			var g6: Dictionary = g5
			if str(g6.get("status", "")) != "active":
				continue
			var nd: Dictionary = g6.get("needs", {})
			var ac: Dictionary = g6.get("activity", {})
			print("PROVOZ guest %d %02d %s mood %.0f hunger %.0f thirst %.0f bladder %.0f hygiene %.0f fun %.0f energy %.0f | %s %s %s" % [day, h, str(g6.get("archetype", "")), float(g6.get("mood", 0.0)), float(nd.get("hunger", -1.0)), float(nd.get("thirst", -1.0)), float(nd.get("bladder", -1.0)), float(nd.get("hygiene", -1.0)), float(nd.get("fun", -1.0)), float(nd.get("energy", -1.0)), str(ac.get("kind", "")), str(ac.get("target_type", "")), "id%d start %d arrive %d end %d now %d" % [int(g6.get("id", 0)), int(ac.get("start", 0)), int(ac.get("arrive", 0)), int(ac.get("end", 0)), (day - 1) * 1440 + h * 60]])
		var k2 = get_tree().get_first_node_in_group("kitchens")
		if k2 != null:
			for key4 in st.biz["sites"]:
				if str(st.biz["sites"][key4].get("kind", "")) == "rest":
					var ks: Dictionary = k2.site(key4)
					print("PROVOZ kitchen %d %02d pass %d floor %d bufet %d places %s plates %s pot %s holds %s visitors %d trays cheese %d fries %d rawc %d rawf %d" % [day, h, k2.tickets(key4, "pass").size(), k2.tickets(key4, "floor").size(), k2.tickets(key4, "bufet").size(), str(k2.crew_places(key4)), str(k2.plates(key4)), str(ks["pot"]), "", preload("res://scripts/food/orders.gd").visitors(key4).size(), k2.prep(key4, "cheese"), k2.prep(key4, "fries"), k2.prep(key4, "cheese_raw"), k2.prep(key4, "chips_raw")])
	if _money and day == _start_day + _days - 1 and h == 11:
		_money_pictures()
		return
	if not _money and _shots_at.has("%d:%d" % [day - _start_day, h]):
		_pictures("d%d_%02d" % [day, h])
	if not _money and _pc_at.has("%d:%d" % [day - _start_day, h]):
		_pc_pictures("d%d_%02d" % [day, h])
	if h == 23:
		var biz: Dictionary = st.biz
		var low: Array = []
		for key in biz["sites"]:
			var s2: Dictionary = biz["sites"][key]
			var kind: String = str(s2.get("kind", ""))
			for g2 in s2.get("stock", {}):
				if BRT.is_low(kind, g2, int(s2["stock"][g2])):
					low.append("%s:%s=%d" % [kind, g2, int(s2["stock"][g2])])
		var sold: Array = []
		for key3 in biz["sites"]:
			var s3: Dictionary = biz["sites"][key3]
			sold.append("%s %d sold $%d lost %d" % [str(s3.get("kind", "")), int((s3["today"] as Dictionary).get("sold", 0)), int((s3["today"] as Dictionary).get("takings", 0)), int((s3["today"] as Dictionary).get("lost", 0))])
		print("PROVOZ day %d places %s" % [day, str(sold)])
		print("PROVOZ day %d sums %s low %s orders %d" % [day, str(_day_stats), str(low), (biz.get("orders", []) as Array).size()])
		print("PROVOZ money %d cash %d %s" % [day, int(st.money), str(BRT.camp_day(biz, 0))])
		_day_stats = {}
	if day >= _start_day + _days and h >= 7:
		_running = false
		Engine.time_scale = 1.0
		print("PROVOZ: done")
		get_tree().quit()


## The screen as it stands, and the plan on TAB.
func _pictures(tag: String) -> void:
	var was := _speed
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join("hud_%s.png" % tag))
	_main.get("_paper_map").set("force_open", true)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join("map_%s.png" % tag))
	_main.get("_paper_map").set("force_open", false)
	Engine.time_scale = was


var _shots_at := {"1:14": true, "2:10": true}
var _pc_at := {"2:12": true}


## The office PC's own screen, sat down at it: the first page of CampStat and its Log.
func _pc_pictures(tag: String) -> void:
	Engine.time_scale = 1.0
	var im = _main.get("_interior_manager")
	im.call("open_startup_crt_view")
	await get_tree().create_timer(9.0).timeout
	var bi = im.get("_building_interior")
	var crt = bi.get("_crt_ui")
	var app = null
	for i in 60:
		crt.open_app("camp_status")
		app = crt.app_of("camp_status")
		if app != null:
			break
		await get_tree().create_timer(0.5).timeout
	if app == null:
		print("PROVOZ no CampStat")
		bi.close_interior()
		Engine.time_scale = _speed
		return
	await get_tree().create_timer(1.0).timeout
	for page in ["today", "log"]:
		app.select_page(page)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		crt.get_viewport().get_texture().get_image().save_png(_out_dir.path_join("pc_%s_%s.png" % [tag, page]))
	bi.close_interior()
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = _speed


func _pc_app(script_name: String) -> Control:
	for n in get_tree().root.find_children("*", "Control", true, false):
		var sc = n.get_script()
		if sc != null and str(sc.resource_path).ends_with(script_name) and (n as Control).is_visible_in_tree():
			return n
	return null


func _pc_shot(crt, name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	crt.get_viewport().get_texture().get_image().save_png(_out_dir.path_join("pc_%s.png" % name))


## Every book and office program after a few real days (--money).
func _money_pictures() -> void:
	_running = false
	Engine.time_scale = 1.0
	var im = _main.get("_interior_manager")
	im.call("open_startup_crt_view")
	await get_tree().create_timer(9.0).timeout
	var bi = im.get("_building_interior")
	var crt = bi.get("_crt_ui")
	var app = null
	for i in 60:
		crt.open_app("camp_status")
		app = crt.app_of("camp_status")
		if app != null:
			break
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.0).timeout
	app.select_page("money")
	await _pc_shot(crt, "money_campstat")
	for prog in ["staff_app", "pub_app", "bistro_app", "shop_app", "corn_app"]:
		EventBus.program_installed.emit(prog)
	await get_tree().create_timer(0.5).timeout
	for prog2 in ["pub_app", "bistro_app", "shop_app", "corn_app"]:
		crt.open_app(prog2)
		await get_tree().create_timer(1.5).timeout
		var a2 := _pc_app("business_app.gd")
		if a2 == null:
			print("PROVOZ no app ", prog2)
			continue
		for page in ["stock", "books"]:
			a2.set("_page", page)
			a2.queue_redraw()
			await _pc_shot(crt, "%s_%s" % [prog2, page])
		a2.set("_page", "order")
		a2.call("_click", "fill")
		a2.queue_redraw()
		await _pc_shot(crt, "%s_order" % prog2)
		print("PROVOZ fill %s %s" % [prog2, str(a2.get("_order"))])
		a2.set("_order", {})
	crt.open_app("staff_app")
	await get_tree().create_timer(1.5).timeout
	var st_app := _pc_app("staff_app.gd")
	if st_app != null:
		await _pc_shot(crt, "staff_first")
		for e in st_app.call("_everyone"):
			if str(e["at"]) != "staff":
				st_app.set("_pick", str((e["p"] as Dictionary).get("slug", "")))
				st_app.queue_redraw()
				break
		await _pc_shot(crt, "staff_place_hand")
	bi.close_interior()
	await get_tree().create_timer(2.0).timeout
	# The books on the counters.
	var biz = im.get("business")
	var building := {"corn": "corn_stand", "pub": "pub", "rest": "restaurant", "vecerka": "vecerka"}
	var sites: Dictionary = CoreRoot.get_state().biz["sites"]
	for key in biz._live_sites():
		var kind := str((sites[key] as Dictionary).get("kind", ""))
		if not building.has(kind):
			continue
		var book: CanvasLayer = load("res://scripts/business/ledger_closeup.gd").new()
		add_child(book)
		book.layer = 98
		book.call("open_for", key, building[kind], "goods")
		await get_tree().create_timer(1.0).timeout
		for page2 in ["goods", "staff", "books"]:
			book.call("_clicked", "tab:" + page2)
			await get_tree().create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out_dir.path_join("book_%s_%s.png" % [kind, page2]))
		var hands: Array = (sites[key] as Dictionary).get("crew", [])
		if not hands.is_empty():
			book.call("_clicked", "tab:staff")
			book.call("_clicked", "crew:" + str((hands[0] as Dictionary).get("slug", "")))
			await get_tree().create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out_dir.path_join("book_%s_card.png" % kind))
		book.call("close_view")
		await get_tree().create_timer(0.8).timeout
	print("PROVOZ: done")
	get_tree().quit()


## The hand at the reception, looked at: from your place behind the counter and turned to
## the keys, at the desk yourself, from the camp through the window (--part=office).
func desk_scene() -> void:
	var g: Vector2i = _main.get("world_generator").gate_tile()
	var a = CoreRoot.actions
	EventBus.RequestDemolish.emit(Rect2i(g.x - 6, 4, 5, 5))
	EventBus.RequestBuild.emit("staffroom", Vector2i(g.x - 5, 5), 0)
	EventBus.RequestBuild.emit("tent_1", Vector2i(g.x - 2, 5), 0)
	CoreRoot.apply_changes({"money": 20000})


func desk_hand() -> void:
	var a = CoreRoot.actions
	var day: int = CoreRoot.get_day()
	var p := BRT.person("hanka", "staff", 0)
	p["jobs"] = STAFF.default_jobs()
	a.staff_hire(p, day - 1)
	a.staff_set_job("hanka", "desk", true)
	var sr = get_tree().get_first_node_in_group("staff_runtime")
	var now: float = _main.call("_now_abs_minutes_float")
	var at: Array = [0.0, 0.0, 0.0]
	var d: Vector3 = sr.call("_desk")
	if d != Vector3.INF:
		at = [d.x, d.y, d.z]
	a.staff_act("hanka", {"do": "work", "what": "desk", "room": "desk", "at": at, "t0": now, "t1": now + 9999.0, "each": 5.0, "last": now})
	print("PROVOZ desk hand ", _main.get("_interior_manager").get("_building_interior").get("_desk_room").desk_hand())


func look(deg: float) -> String:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var look_ = bi.get("_look")
	look_.yaw_deg = deg
	return str(look_.yaw_deg)


## The staffroom's books and a stand's order page, Personal 98 (--part=books --lang=cs).
var _book: CanvasLayer


func books_camp() -> void:
	var g: Vector2i = _main.get("world_generator").gate_tile()
	var a = CoreRoot.actions
	EventBus.RequestDemolish.emit(Rect2i(g.x - 6, 4, 5, 5))
	EventBus.RequestBuild.emit("staffroom", Vector2i(g.x - 5, 5), 0)
	EventBus.RequestBuild.emit("corn_stand", Vector2i(g.x - 2, 5), 0)
	CoreRoot.apply_changes({"money": 20000})


func books_crew() -> void:
	var a = CoreRoot.actions
	var day: int = CoreRoot.get_day()
	for n in ["hanka", "mirek"]:
		var p := BRT.person(n, "staff", 0)
		p["jobs"] = STAFF.default_jobs()
		a.staff_add_gear("locker")
		a.staff_hire(p, day)
	a.staff_set_job("hanka", "desk", true)
	var biz = _main.get("_interior_manager").get("business")
	biz._process(2.0)
	for key in biz._live_sites():
		a.biz_hire(key, BRT.person("franta", "corn", 0), day)
	a.biz_grant_licence("staff")


func staff_book() -> void:
	_book = load("res://scripts/staff/staff_ledger.gd").new()
	add_child(_book)
	_book.layer = 98
	_book.call("open_view")


func staff_book_pick(slug: String) -> void:
	_book.call("_clicked", "crew:" + slug)


func staff_book_shut() -> void:
	_book.call("close_view")


func pick_hand() -> void:
	for n in get_tree().root.find_children("*", "Control", true, false):
		var sc = n.get_script()
		if sc != null and str(sc.resource_path).ends_with("staff_app.gd"):
			n.set("_pick", "hanka")
			(n as Control).queue_redraw()


func corn_licence() -> void:
	CoreRoot.actions.biz_grant_licence("corn")


func order_page() -> void:
	for n in get_tree().root.find_children("*", "Control", true, false):
		var sc = n.get_script()
		if sc != null and str(sc.resource_path).ends_with("business_app.gd") and (n as Control).is_visible_in_tree():
			n.set("_page", "order")
			(n as Control).queue_redraw()


func order_book() -> void:
	var biz = _main.get("_interior_manager").get("business")
	var key: String = biz._live_sites().keys()[0]
	_book = load("res://scripts/business/ledger_closeup.gd").new()
	add_child(_book)
	_book.layer = 98
	_book.call("open_for", key, "corn_stand", "order")


func order_book_card() -> void:
	_book.call("_clicked", "tab:staff")
	_book.call("_clicked", "crew:franta")


## Every kind of plate at once (--part=plates --lang=cs): the words as they fit.
func plates_camp() -> void:
	var g: Vector2i = _main.get("world_generator").gate_tile()
	EventBus.RequestDemolish.emit(Rect2i(g.x - 6, 4, 5, 5))
	EventBus.RequestDemolish.emit(Rect2i(g.x + 1, 4, 5, 5))
	EventBus.RequestBuild.emit("staffroom", Vector2i(g.x - 5, 5), 0)
	EventBus.RequestBuild.emit("corn_stand", Vector2i(g.x - 2, 5), 0)
	EventBus.RequestBuild.emit("tent_1", Vector2i(g.x + 2, 5), 0)
	EventBus.RequestBuild.emit("tent_1", Vector2i(g.x + 4, 5), 0)
	EventBus.RequestBuild.emit("toilet_block", Vector2i(g.x + 2, 7), 0)
	EventBus.RequestBuild.emit("lamp_post", Vector2i(g.x + 4, 7), 0)
	CoreRoot.apply_changes({"money": 20000})


func plates_state() -> void:
	var a = CoreRoot.actions
	var st = CoreRoot.get_state()
	var day: int = CoreRoot.get_day()
	var biz = _main.get("_interior_manager").get("business")
	biz._process(2.0)
	var key: String = biz._live_sites().keys()[0]
	var p1 := BRT.person("franta", "corn", 0)
	a.biz_hire(key, p1, day - 1)
	a.biz_crew_note(key, "franta", {"absent": day})
	var p2 := BRT.person("mirek", "staff", 0)
	p2["jobs"] = STAFF.default_jobs()
	a.staff_hire(p2, day - 1)
	a.staff_note("mirek", {"owed": 40})
	st.biz["gone"] = [{"slug": "hanka", "name": "Hanka", "day": day}]
	for i in 3:
		EmailManager.inbox.append({"type": "customer", "guest_name": "Novak %d" % i, "guests": 1, "nights": 1, "archetype": "quiet_guy", "from": "n@x", "subject": "s", "_delivered": true})
	_main.get("_billing").bills.append({"id": "E1", "amount": 123, "status": "unpaid", "due_day": day, "service_day": day - 1})
	for coord in st.grid.lamp_coords():
		CoreRoot.failure_system._trigger_failure("%d:%d" % [coord.x, coord.y], "lamp_post", coord)
		break
	# A lodging somebody is on the road to, not made up; a dirty toilet; a guest at the desk.
	var keys: Array = st.accommodation_states.keys()
	for k in keys:
		st.accommodation_states[k]["status"] = "dirty"
	for c in st.grid.cells:
		if str(st.grid.cells[c].get("type", "")) == "toilet_block":
			st.grid.cells[c]["maintenance"] = 0.3
	print("PROVOZ plates ", _plates())


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--part=plates"):
		_steps = [
			["wait_menu"], ["call", "_on_menu_new_camp", ["Provoz", 4242, false, true, {"threats": false, "weather": false, "events": false, "wear": false, "money": 100000}]], ["wait_gameplay"], ["wait", 2.0],
			["auto_checkin", false], ["auto_accept", false],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["eval", C + ".plates_camp()"], ["wait", 6.0],
			["book", "Karel Benes", "quiet_guy", 1, 2, 90], ["wait", 1.0],
			["eval", C + ".plates_state()"], ["wait", 2.5], ["shot", "p1_plates"],
			["eval", "get_tree().quit()"],
		]
		return
	if OS.get_cmdline_user_args().has("--part=books"):
		_steps = [
			["wait_menu"], ["call", "_on_menu_new_camp", ["Provoz", 4242, false, true, {"threats": false, "weather": false, "events": false, "wear": false, "money": 100000}]], ["wait_gameplay"], ["wait", 2.0],
			["auto_checkin", false], ["auto_accept", false],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["eval", C + ".books_camp()"], ["wait", 6.0], ["eval", C + ".books_crew()"], ["wait", 1.0],
			["eval", C + ".staff_book()"], ["wait", 1.0], ["eval", C + ".staff_book_pick('hanka')"], ["wait", 0.4], ["shot", "b1_staff_book"],
			["eval", C + ".staff_book_shut()"], ["wait", 0.8],
			["eval", C + ".order_book()"], ["wait", 1.0], ["shot", "b2_order_book"],
			["eval", C + ".order_book_card()"], ["wait", 0.6], ["shot", "b2b_card"], ["eval", C + ".staff_book_shut()"], ["wait", 0.8],
			["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
			["signal", "program_installed", "staff_app"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior._crt_ui.open_app('staff_app') != null"], ["wait", 2.0],
			["eval", C + ".pick_hand()"], ["wait", 0.6],
			["crt_screen", "b3_personal"],
			["eval", "_interior_manager._building_interior._crt_ui.open_app('camp_status') != null"], ["wait", 2.0],
			["crt_screen", "b4_today"],
			["eval", C + ".corn_licence()"], ["signal", "program_installed", "corn_app"], ["wait", 0.5],
			["eval", "_interior_manager._building_interior._crt_ui.open_app('corn_app') != null"], ["wait", 1.5],
			["eval", C + ".order_page()"], ["wait", 0.8], ["crt_screen", "b5_order_program"],
			["eval", "get_tree().quit()"],
		]
		return
	if OS.get_cmdline_user_args().has("--part=office"):
		_steps = [
			["wait_menu"], ["call", "_on_menu_new_camp", ["Provoz", 4242, false, true, {"threats": false, "weather": false, "events": false, "wear": false, "money": 100000}]], ["wait_gameplay"], ["wait", 2.0],
			["auto_checkin", false], ["auto_accept", false],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["eval", C + ".desk_scene()"], ["wait", 6.0], ["prep_all"], ["wait", 1.0],
			["book", "Karel Benes", "quiet_guy", 1, 2, 0], ["wait", 2.0],
			["eval", C + ".desk_hand()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 2.5],
			["shot", "o1_as_you_come_in"],
			["eval", C + ".look(0.0)"], ["wait", 0.6], ["shot", "o2_straight"],
			["eval", C + ".look(-40.0)"], ["wait", 0.6], ["shot", "o3_right"],
			["eval", C + ".look(-70.0)"], ["wait", 0.6], ["shot", "o4_keys"],
			["book", "Jan Novak", "quiet_guy", 1, 1, 0], ["wait", 0.8],
			["eval", "_interior_manager._building_interior._desk_room.open()"], ["wait", 2.0], ["shot", "o5_at_the_desk_yourself"],
		]
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			_days = int(a.substr(7))
		elif a.begins_with("--speed="):
			_speed = float(a.substr(8))
		elif a.begins_with("--hands="):
			_hands = a.substr(8)
		elif a.begins_with("--accept="):
			_accept = a.substr(9) == "1"
		elif a == "--verbose":
			_verbose = true
		elif a == "--money":
			_money = true
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_camp", ["Provoz", 4242, false, true, {"threats": false, "weather": true, "events": true, "wear": true, "money": 100000}]], ["wait_gameplay"], ["wait", 2.0],
		["auto_checkin", false], ["auto_accept", _accept],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", C + ".camp()"], ["wait", 12.0], ["eval", C + ".staff()"], ["prep_all"], ["wait", 2.0],
		["player", 10, 9, 180.0],
		["eval", C + ".go()"],
		["wait", 1000000.0],
	]
