extends "res://tools/shot_driver.gd"

## The core loop's holes (the audit of 6. 11.), each one played: the checklist's bill, the
## corn stand for its food step, a room made up early, Mirek's letter thrown away, a broken
## lamp and the old cabin bulldozed, a guest storming off, deleted letters, the line at the
## desk, a camp loaded in the dark, the left button on a door, the torch by day. Windowed
## (the click needs the world's viewport). Lines "SMYCKA ...", "SMYCKA: PASS".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/smycka_check.tscn -- --out=DIR [--part=hands]
## --part=hands: what only the hands can tell: the made bed by day, the catalogue's grey line, the
## stand's Z report, the left button at the fire, E and Space on the far shore.
## --part=books: every page of every place's books as shots (with --lang=cs for the Czech).

const C := "get_tree().root.get_node('SmyckaCheck')"

var fails := 0


func _ok(what: String, good: bool, more := "") -> void:
	print("SMYCKA %s %s %s" % ["ok  " if good else "FAIL", what, more])
	if not good:
		fails += 1


func qm() -> Node:
	return _main.get("_quest_manager")


## The checklist put on the step `id`, as if the ones before it were done.
func to_step(id: String) -> void:
	var steps: Array = qm().get("STEPS")
	for i in steps.size():
		if str(steps[i]["id"]) == id:
			qm().set("_index", i)
			return


func bill() -> void:
	to_step("pay_bill")
	var billing = _main.get("_billing")
	billing.bills.append({"id": "test_bill", "amount": 10, "due_day": 9, "status": "unpaid"})
	CoreRoot.actions.add_money(100)
	var paid: Dictionary = _main.call("request_pay_electricity_bill", "test_bill")
	_ok("the bill paid moves the checklist on", bool(paid.get("ok", false)) and qm().current_step_id() != "pay_bill", str(qm().current_step_id()))


func corn() -> void:
	to_step("feed_guests")
	_ok("a corn stand is food", bool(qm().call("_is_satisfied", "feed_guests")))


func room_early() -> void:
	var gm = get_node("/root/GuestManager")
	to_step("make_up_room")
	qm().set("_flags", {"booking_accepted": true})
	var rows: Array = gm.get_arrivals()
	var ready := false
	if not rows.is_empty():
		ready = bool(qm().call("_arrivals_rooms_ready"))
	print("SMYCKA arrivals %d, rooms ready %s" % [rows.size(), str(ready)])


func letter_gone() -> void:
	to_step("accept_booking")
	var em = get_node("/root/EmailManager")
	var before := 0
	for m in em.inbox:
		if str(m.get("task_id", "")) == "accept_booking":
			before += 1
			m["_actioned"] = true
	qm().set("_rebook_t", 1000.0)
	qm().call("_keep_first_booking")
	var after := 0
	for m in em.inbox:
		if str(m.get("task_id", "")) == "accept_booking":
			after += 1
	_ok("Mirek writes again", after == before + 1 or (not (get_node("/root/GuestManager").get_arrivals() as Array).is_empty()), "%d -> %d" % [before, after])


func bulldoze() -> void:
	var state = CoreRoot.get_state()
	var key: String = _main.call("ruined_cabin_key")
	_ok("the old cabin is there", key != "", key)
	var parts := key.split(":")
	var at := Vector2i(int(parts[0]), int(parts[1]))
	CoreRoot.actions.remove_building(at)
	_ok("its failure went with it", not state.failures.has(key))
	_ok("no old cabin to mend", str(_main.call("ruined_cabin_key")) == "")
	_ok("fix_cabin is done", bool(qm().call("_is_satisfied", "fix_cabin")))
	_ok("clean_cabin is done", bool(qm().call("_is_satisfied", "clean_cabin")))


func storm() -> void:
	var state = CoreRoot.get_state()
	var g: Dictionary = {}
	for guest in state.guests:
		if str(guest.get("status", "")) == "active" and str((guest.get("activity", {}) as Dictionary).get("kind", "")) != "leave":
			g = guest
			break
	if g.is_empty():
		_ok("a guest to upset", false)
		return
	g["mood"] = 5.0
	g["unhappy_minutes"] = 100000
	g["storming_off"] = false
	print("SMYCKA storm: %s, %s" % [str(g.get("name")), str((g.get("activity", {}) as Dictionary).get("kind", ""))])
	storm_id = int(g.get("id", -1))


var storm_id := -1


func storm_after() -> void:
	var state = CoreRoot.get_state()
	var kind := "gone"
	for guest in state.guests:
		if int(guest.get("id", -2)) == storm_id:
			kind = str((guest.get("activity", {}) as Dictionary).get("kind", ""))
	_ok("the upset guest really goes", kind == "leave" or kind == "gone", kind)


func mail() -> void:
	var em = get_node("/root/EmailManager")
	var base: int = em.call("_count_unactioned_customer_mails")
	em.inbox.append({"type": "customer", "from": "x", "subject": "x", "guests": 1, "_folder": "deleted", "_actioned": false, "_runtime_id": 987654})
	var with_deleted: int = em.call("_count_unactioned_customer_mails")
	em.inbox.pop_back()
	_ok("a deleted letter holds nothing back", with_deleted == base, "%d, %d" % [base, with_deleted])


func queue() -> void:
	var gm = get_node("/root/GuestManager")
	var state = CoreRoot.get_state()
	var a := {"id": 90001, "status": "waiting", "gate_since_abs": 100, "name": "First"}
	var b := {"id": 90002, "status": "waiting", "gate_since_abs": 200, "name": "Second"}
	state.guests.append(a)
	state.guests.append(b)
	gm.call("_update_arrivals", 201)
	_ok("first at the desk, first in line", int(a.get("gate_queue_index", -1)) < int(b.get("gate_queue_index", -1)), "%d, %d" % [int(a.get("gate_queue_index", -1)), int(b.get("gate_queue_index", -1))])
	state.guests.erase(a)
	state.guests.erase(b)


func night_load() -> void:
	_main.set("_liminal_last_rolled_night_id", -99999)
	var before := int(_main.get("_liminal_last_rolled_night_id"))
	_main.call("debug_jump_to", 4, 23.0)
	_main.set("_liminal_last_rolled_night_id", -99999)
	_main.call("_stop_active_enemy_brain")
	_main.call("_resume_night_after_load")
	_ok("a night loaded goes on", int(_main.get("_liminal_last_rolled_night_id")) == 4, "night %d (was %d), %d out" % [int(_main.get("_liminal_last_rolled_night_id")), before, (_main.get("_enemy_brains") as Array).size()])


func click_door() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = get_viewport().get_visible_rect().size * 0.5
	ev.global_position = ev.position
	print("SMYCKA click: hint %s, mouse mode %d" % [str(_main.get("_hud_manager").get("_hint_text")), Input.get_mouse_mode()])
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)


func door_opened() -> void:
	var opened := bool(_main.call("_is_any_interior_open")) or str(_main.get("_interior_manager").get("through").get("_state")) != ""
	_ok("the left button opens a door", opened)


func torch_day() -> void:
	var p: Node = _main.get("_player")
	var chose: bool = p.get("_flashlight_user_chose_off")
	var want: bool = p.get("_flashlight_user_enabled")
	p.call("toggle_flashlight")
	_ok("the torch by day keeps its state", bool(p.get("_flashlight_user_chose_off")) == chose and bool(p.get("_flashlight_user_enabled")) == want)


func hand_click(at := Vector2(-1, -1)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at if at.x >= 0.0 else get_viewport().get_visible_rect().size * 0.5
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)


## The bed of a room made up, clicked by day: an answer, not silence.
func bed_click() -> void:
	var lb = _main.get("_interior_manager").get("lodge_bed")
	var it = lb.get("_it")
	if it == null or lb.get("_body") == null:
		_ok("a room with a bed is open", false)
		return
	var cam: Camera3D = lb.get("_cam")
	var vp: SubViewport = it.get("_viewport")
	var body: Node3D = lb.get("_body")
	var p := cam.unproject_position(body.global_position)
	var screen := get_viewport().get_visible_rect().size
	var at := Vector2(p.x / vp.size.x * screen.x, p.y / vp.size.y * screen.y)
	print("SMYCKA bed at %s, made %s, in view %s, refusal %s" % [str(at), str(lb.call("_bed_made")), str(cam.is_position_in_frustum(body.global_position)), str(lb.call("_refusal"))])
	feed_mark = (_main.get("_hud_manager").get("_feed") as Array).size()
	hand_click(at)


var feed_mark := 0


func bed_said() -> void:
	var feed: Array = _main.get("_hud_manager").get("_feed")
	var said := str((feed.back() as Dictionary).get("text", "")) if not feed.is_empty() else ""
	print("SMYCKA said: %s" % said)
	_ok("a made bed answers by day", said.find("daylight") >= 0 or said.find("dni") >= 0 or feed.size() > feed_mark, said)


func catalogue() -> void:
	var im = _main.get("_interior_manager")
	im.set("_pending_upgrade_context", {"new_type": "tent_2"})
	im.call("_open_upgrade_menu", "Tent: Upgrade", "Tent -> Bigger tent", "$100", true)
	var menu = im.get("_building_upgrade_menu")
	print("SMYCKA catalogue: %s" % str(menu.get("_cost_text")))
	_ok("the catalogue says why it is grey", str(menu.get("_cost_text")).find("20") >= 0 or str(menu.get("_cost_text")).find("10") >= 0, str(menu.get("_cost_text")))
	_ok("in Czech too", TranslationServer.get_locale().begins_with("en") or str(menu.get("_cost_text")).find("UPGRADE AT") < 0, str(menu.get("_cost_text")))


func catalogue_shut() -> void:
	_main.get("_interior_manager").get("_building_upgrade_menu").call("close_menu")


func z_stand() -> void:
	var view = _main.get("_interior_manager").get("_corn_stand")
	var key := str(view.get("building_key"))
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	var site: Dictionary = sites.get(key, {})
	(site["shift"] as Dictionary)["orders"] = 12
	(site["shift"] as Dictionary)["score"] = 900
	CoreRoot.actions.biz_close_shift(key, 0, 1, false)
	view.call("_open_books")
	view.get("_ledger").call("_clicked", "tab:books")


func z_click() -> void:
	var l = _main.get("_interior_manager").get("_corn_stand").get("_ledger")
	var ids: Array = []
	for h in l.call("_hotspots"):
		ids.append(str(h.get("id", "")))
	_ok("the stand's books have the report", "zreport" in ids)
	l.call("_clicked", "zreport")


func z_open() -> void:
	var l = _main.get("_interior_manager").get("_corn_stand").get("_ledger")
	var z = l.get("_zreport")
	_ok("the report opens over the stand's books", z != null and bool(z.get("visible")))


func z_shut() -> void:
	var view = _main.get("_interior_manager").get("_corn_stand")
	view.get("_ledger").get("_zreport").call("close_view")


func z_after() -> void:
	_ok("back behind the stand", bool(_main.get("_interior_manager").get("_corn_stand").get("_open")))


func far_shore() -> void:
	var lt = _main.get("_lake_trip")
	_ok("on the far shore", int(lt.get("_state")) == 2, "state %d, moving %s, hint %s" % [int(lt.get("_state")), str(lt.get("_moving")), str(lt.call("active_hint"))])
	_ok("it says the way back", str(lt.call("active_hint")) != "")


func rowing(what: String) -> void:
	var lt = _main.get("_lake_trip")
	_ok(what + " rows back", int(lt.get("_state")) == 1, "state %d" % int(lt.get("_state")))


func fire_state() -> void:
	var wp = _main.get("_warden_play")
	fire_was = str(wp.call("coop_state"))
	print("SMYCKA at the fire: %s" % fire_was)
	_ok("sat down at the fire", bool(wp.call("is_active")))


var fire_was := ""


func fire_after() -> void:
	var now := str(_main.get("_warden_play").call("coop_state"))
	print("SMYCKA after the click: %s" % now)
	_ok("the left button acts at the fire", now != fire_was, now)


func to_fire() -> void:
	var wp = _main.get("_warden_play")
	var att: Node3D = wp.call("find_att", "11,12")
	if att == null:
		_ok("a fire to sit at", false)
		return
	if not att.call("is_lit"):
		att.call("add_log")
	(_main.get("_player") as Node3D).global_position = att.global_position + Vector3(0.0, 0.4, 2.4)
	for _try in 3:
		if not wp.call("is_active"):
			wp.call("try_interact")


func hand_steps() -> Array:
	var lake := "_lake_trip._lake_node()"
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0],
		["eval", "_build_test_camp('')"], ["wait", 2.0],
		["money", 9000], ["clear", 11, 12, 6, 6], ["build", "bonfire", 11, 12, 0], ["build", "corn_stand", 15, 15, 0], ["build", "tent_1", 13, 16, 0], ["wait", 1.0], ["prep_all"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["wait", 1.0],
		# The bed by day, the catalogue.
		["open_room", 13, 16], ["wait", 3.0], ["eval", C + ".bed_click()"], ["wait", 0.8], ["shot", "bed_day"], ["eval", C + ".bed_said()"],
		["eval", C + ".catalogue()"], ["wait", 0.6], ["shot", "catalogue"], ["eval", C + ".catalogue_shut()"], ["wait", 0.5],
		["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 2.0],
		# The stand's Z report.
		["eval", "_interior_manager._on_corn_stand_interact(debug_structure_of_type('corn_stand'))"], ["wait", 2.0],
		["eval", C + ".z_stand()"], ["wait", 1.2], ["shot", "z_books"], ["eval", C + ".z_click()"], ["wait", 1.5], ["eval", C + ".z_open()"], ["shot", "z_report"],
		["eval", C + ".z_shut()"], ["wait", 1.0], ["eval", C + ".z_after()"], ["shot", "z_after"],
		["eval", "_interior_manager._corn_stand.close_view()"], ["wait", 1.5],
		# The left button at the fire.
		["eval", C + ".to_fire()"], ["wait", 1.5], ["eval", C + ".fire_state()"], ["eval", C + ".hand_click()"], ["wait", 1.5], ["eval", C + ".fire_after()"], ["shot", "fire"],
		["eval", "_warden_play.leave()"], ["wait", 1.0],
	]
	# The far shore, twice: E, then Space.
	for k in ["E", "Space"]:
		s.append_array([
			["eval", "_player.set('global_position', " + lake + ".boat_home.origin + Vector3(-1.6, 0.6, 0.6))"],
			["eval", "_lake_trip.hint()"], ["eval", "_lake_trip.try_interact()"], ["wait", 2.0],
			["eval", lake + ".boat.set('global_position', " + lake + ".far_jetty_end + Vector3(1.0, -0.48, -9.0))"],
			["eval", "_lake_trip.set('_yaw', 0.0)"], ["keyhold", "W", true], ["wait", 2.5], ["keyhold", "W", false], ["wait", 7.0],
			["eval", C + ".far_shore()"], ["shot", "far_" + k], ["key", k], ["wait", 1.0], ["eval", C + ".rowing('%s')" % k],
			["eval", "_lake_trip.return_home()"], ["wait", 2.0],
		])
	s.append_array([["eval", C + ".verdict()"], ["eval", "get_tree().quit()"]])
	return s


## Every page of a place's books, for the eye (a line under the stamp or the pencil).
var book: CanvasLayer


func book_open(kind: String) -> void:
	if book == null:
		book = load("res://scripts/business/ledger_closeup.gd").new()
		add_child(book)
		book.layer = 98
	# (Its cell alone: a site goes when its building does, and these books need no walls.)
	var at := Vector2i(27, kind.length())
	CoreRoot.get_state().grid.occupy_cell(at, kind, "book_" + kind, at, Vector2i.ONE)
	book.call("open_for", "%d:%d" % [at.x, at.y], kind, "menu")


func book_page(page: String) -> void:
	book.call("_clicked", "tab:" + page)


func book_sheet() -> void:
	book.call("_clicked", "sheet")


func book_shut() -> void:
	book.call("close_view")


func book_steps() -> Array:
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0],
		["eval", "_build_test_camp('')"], ["wait", 2.0],
	]
	for kind in ["corn_stand", "pub", "restaurant", "vecerka", "bowling"]:
		s.append_array([["eval", C + ".book_open('%s')" % kind], ["wait", 1.0]])
		for page in ["goods", "menu", "staff", "gear", "books"]:
			s.append_array([["eval", C + ".book_page('%s')" % page], ["wait", 0.25], ["shot", "%s_%s" % [kind, page]]])
			if page == "goods":
				s.append_array([["eval", C + ".book_sheet()"], ["wait", 0.25], ["shot", "%s_%s2" % [kind, page]], ["eval", C + ".book_sheet()"]])
		s.append_array([["eval", C + ".book_shut()"], ["wait", 0.8]])
	# Builder's Help > Keys, as long as the Czech makes it.
	s.append_array([
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior._crt_ui.open_app('builder') != null"], ["wait", 4.5],
		["eval", "debug_close_msgboxes()"], ["wait", 0.5], ["eval", C + ".builder_keys()"], ["wait", 1.0], ["shot", "builder_keys"],
		["eval", "get_tree().quit()"]])
	return s


func builder_keys() -> void:
	var module := load("res://scripts/builder_module.gd")
	for n in get_tree().root.find_children("*", "Control", true, false):
		if n.get_script() == module:
			n.call("_menu", "Keys")
			return


func verdict() -> void:
	print("SMYCKA: %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))


func _ready() -> void:
	super._ready()
	if "--part=hands" in OS.get_cmdline_user_args():
		_steps = hand_steps()
		return
	if "--part=books" in OS.get_cmdline_user_args():
		_steps = book_steps()
		return
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0],
		["eval", C + ".letter_gone()"], ["eval", C + ".bulldoze()"], ["wait", 0.5],
		["eval", "_build_test_camp('')"], ["wait", 2.0],
		["clear", 14, 14, 4, 4], ["build", "corn_stand", 15, 15, 0], ["wait", 1.0],
		["gm", "debug_check_in_party", "Pepa", "drunk", 2, 3], ["gm", "debug_check_in_party", "Mirek", "quiet_guy", 1, 3], ["wait", 3.0],
		["eval", "debug_jump_to(1, 11.0)"], ["wait", 1.0],
		["eval", C + ".bill()"], ["eval", C + ".corn()"], ["eval", C + ".room_early()"], ["eval", C + ".mail()"], ["eval", C + ".queue()"],
		["eval", C + ".storm()"], ["timescale", 8.0], ["wait", 2.0], ["timescale", 1.0], ["eval", C + ".storm_after()"],
		["eval", C + ".torch_day()"],
		["eval", "debug_jump_to(1, 11.5)"], ["wait", 1.0], ["door_front", "main_building", 1.2], ["wait", 1.2],
		["eval", C + ".click_door()"], ["wait", 2.5], ["eval", C + ".door_opened()"],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.5],
		["eval", C + ".night_load()"], ["wait", 1.0],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]
