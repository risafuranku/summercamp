extends "res://tools/shot_driver.gd"

## The night as you meet it and the month's end (the audit of 6. 11.), each hole played: the
## Antlered Man seen after a night begun indoors and lost at a door, the window that cannot
## hit you at the PC, the PC on its UPS with the bill unpaid, the boy's job with you sat in
## the office, the granny's bulbs back with the morning, a catch that holds you, the boy's
## game over at dawn, a job left for days counted once, the books, the day after the month,
## your health in a save, the black gone after the bite. Windowed. Run with its own APPDATA
## (it saves). Lines "NOC ...", "NOC: PASS".
##   APPDATA=<dir> godot --path godot --audio-driver Dummy --resolution 1366x768 res://tools/noc_check.tscn -- --out=DIR [--lang=cs]

const C := "get_tree().root.get_node('NocCheck')"

var fails := 0


func _ok(what: String, good: bool, more := "") -> void:
	print("NOC %s %s %s" % ["ok  " if good else "FAIL", what, more])
	if not good:
		fails += 1


func brain():
	var list: Array = _main.get("_enemy_brains")
	return list[0] if not list.is_empty() else null


func room() -> Node:
	return _main.get("_interior_manager").get("_building_interior")


func office_in() -> void:
	_main.get("_interior_manager").call("handle_structure_interact", _main.call("debug_structure_of_type", "main_building"))


# ── the Antlered Man ─────────────────────────────────────────────────────────

func stalker_hidden() -> void:
	var b = brain()
	print("NOC stalker indoors: body shown %s" % str((b.get("_body") as Node3D).visible))


func stalker_seen() -> void:
	var b = brain()
	_ok("the Antlered Man is there to be seen after a night begun indoors", (b.get("_body") as Node3D).visible)
	b.set("_charging", true)


func stalker_lost() -> void:
	_ok("a door loses him", not bool(brain().get("_charging")))


# ── the window at the PC ─────────────────────────────────────────────────────

func windows_at_pc() -> void:
	var ws: Array = _main.get("_interior_manager").call("photo_windows")
	var worst := -2.0
	for w in ws:
		worst = maxf(worst, float(w.get("facing", 0.0)))
	_ok("at the PC no window is looked at", not ws.is_empty() and worst < 0.0, "%d windows, %.2f" % [ws.size(), worst])


func windows_in_room() -> void:
	var ws: Array = _main.get("_interior_manager").call("photo_windows")
	var best := -2.0
	for w in ws:
		best = maxf(best, float(w.get("facing", 0.0)))
	_ok("in the room the windows count again", not ws.is_empty() and best > -1.0, "%.2f" % best)


# ── the bill unpaid ──────────────────────────────────────────────────────────

func bill_overdue() -> void:
	var billing = _main.get("_billing")
	billing.bills.append({"id": "noc_bill", "amount": 10, "due_day": 0, "status": "unpaid"})
	CoreRoot.actions.add_money(100)


func pc_on() -> void:
	var billing = _main.get("_billing")
	var os: Node = room().get("_crt_ui")
	_ok("the mains are cut", bool(billing.power_cut_active))
	_ok("the UPS is running", bool(billing.ups_active), "%.0f s" % float(billing.ups_seconds_left))
	# Boot: OFF 0, SAFE_OFF 7, DESKTOP 5.
	var st := int(os.get("_state"))
	print("NOC pc state %d" % st)
	_ok("the PC runs on it", st != 0 and st != 7, str(st))


func pay() -> void:
	var paid: Dictionary = _main.call("request_pay_electricity_bill", "noc_bill")
	_ok("the bill can be paid from the PC", bool(paid.get("ok", false)), str(paid))


func paid_back() -> void:
	var billing = _main.get("_billing")
	_ok("the power is back", not bool(billing.power_cut_active) and not bool(billing.ups_active))


# ── the boy ──────────────────────────────────────────────────────────────────

func boy_at() -> void:
	var b = brain()
	b.call("force_place", "breaker")


func boy_job() -> void:
	_ok("his job comes with you sat in the office", bool(_main.get("_night_jobs").call("boy_job_open")))


func boy_dawn() -> void:
	var nj = _main.get("_night_jobs")
	var jobs: Array = nj.get("_jobs")
	jobs.clear()
	jobs.append({"kind": "breaker", "state": "open", "boy": 2, "boy_of": {}, "at": 0, "coord": [0, 0], "title": "x"})
	_ok("his game at the board tonight", int(nj.call("boy_tier_at", "breaker")) == 2)
	nj.call("on_dawn")
	_ok("over at dawn", int(nj.call("boy_tier_at", "breaker")) == 0)
	_ok("the job is still there", (nj.call("open_jobs") as Array).size() == 1)
	var once := int(nj.call("take_left_count"))
	var twice := int(nj.call("take_left_count"))
	_ok("a job left for days counts once", once == 1 and twice == 0, "%d, %d" % [once, twice])
	jobs.clear()
	nj.set("breaker_tripped", false)


# ── the granny's bulbs ───────────────────────────────────────────────────────

var lit_before := 0


func lamp_dark() -> void:
	var bm = _main.get("building_manager")
	var lamps: Array = bm.call("lit_lamp_positions")
	lit_before = lamps.size()
	if lamps.is_empty():
		_ok("a lamp for her", false)
		return
	var at: Vector3 = bm.call("darken_lamp_near", lamps[0], 2.0, 3600.0)
	(brain().get("bulbs") as Array).append(at)
	print("NOC lamps %d, dark now %d" % [lit_before, (bm.call("lit_lamp_positions") as Array).size()])


func lamp_back() -> void:
	var now := (_main.get("building_manager").call("lit_lamp_positions") as Array).size()
	_ok("her bulbs are back with the morning", now == lit_before, "%d of %d" % [now, lit_before])


# ── a catch holds you ────────────────────────────────────────────────────────

func catch() -> void:
	var b = brain()
	b.set("_lesson", false)
	b.set("_first", false)
	b.call("_start_catch", "ear")


func held() -> void:
	var p: Node = _main.get("_player")
	_ok("the catch holds you", bool(_main.call("_enemy_holding_player")) and not bool(p.get("controls_enabled")))
	print("NOC hint at the door: %s" % str(_main.get("_hud_manager").get("_hint_text")))
	_main.call("_try_interact")


func not_through() -> void:
	_ok("no door in the middle of it", not bool(_main.call("_is_any_interior_open")))


func let_go() -> void:
	_ok("let go at its end", not bool(_main.call("_enemy_holding_player")) and bool(_main.get("_player").get("controls_enabled")))


# ── the month ────────────────────────────────────────────────────────────────

func banner(day: int) -> String:
	var hud: Node = _main.get("_hud_manager")
	hud.set("_day", day)
	hud.call("_announce_phase", int(hud.get("PHASE_DAY")))
	return str(hud.get("_banner_title_text"))


func month_days() -> void:
	var last := banner(30)
	var after := banner(31)
	_ok("the last day has its count, the day after has none", last.find("30") >= 0 and after.find("30") < 0, "%s, %s" % [last, after])


func report_shut() -> void:
	_main.call("_close_week_report")
	_main.get("_week_ledger").set("closed", false)
	_main.get("_hud_manager").call("set_world_hud_visible", true)


func value() -> void:
	var ledger: Node = _main.get("_week_ledger")
	var now := int(_main.call("_camp_value"))
	print("NOC camp value %d, at the start %d" % [now, int(ledger.get("start_built"))])
	_ok("what stands is counted", now > 0)


# ── your health in a save ────────────────────────────────────────────────────

func hurt_save() -> void:
	_main.call("_set_player_health", 40, false)
	_main.call("debug_save_and_reload")


func hurt_loaded() -> void:
	_ok("hurt and loaded is still hurt", int(_main.get("_player_health")) == 40, str(_main.get("_player_health")))


# ── the bite ─────────────────────────────────────────────────────────────────

var the_fx: Node


func bite() -> void:
	var b = brain()
	the_fx = b.call("_fx")
	b.set("_lesson", false)
	b.set("_first", false)
	_main.call("_set_player_health", 1, false)
	b.call("_start_catch", "bite")


func after_bite() -> void:
	var black: ColorRect = the_fx.get("_black")
	_ok("the bite ends the game", bool(_main.get("_game_over_active")))
	_ok("no black left over it", not black.visible, "alpha %.2f" % black.color.a)


## The books with everything on them: all seven came, the longest count, in three grades.
func report_full(grade: String) -> void:
	var ledger: Node = _main.get("_week_ledger")
	for id in ["silent_man", "tourist", "girl", "whistler", "child", "basket", "stalker"]:
		for night in 3:
			ledger.call("note_enemy", id, night)
	for i in 7:
		ledger.call("note_hit", 10)
	ledger.call("note_jobs_left", 3)
	var state = CoreRoot.get_state()
	state.guest_reviews.clear()
	var rating := {"good": 5, "fair": 3, "poor": 1}[grade] as int
	for i in 14:
		state.guest_reviews.append({"rating": rating, "stormed_off": i == 1})
	state.money = int(ledger.get("start_money")) + (9000 if grade == "good" else (500 if grade == "fair" else -300))
	_main.call("_show_week_report")


func report_measure() -> void:
	var scr: Node = _main.get("_week_report_screen")
	var root: Control = scr.get("_root")
	var box: VBoxContainer = root.get_child(1)
	var list: Control = scr.get("_list")
	var screen := get_viewport().get_visible_rect().size
	var need := box.get_combined_minimum_size().y
	var room := screen.y - float(scr.get("_scale")) * 6.0 - list.size.y
	print("NOC report %dx%d scale %d: needs %.0f of %.0f, top %.0f, list from %.0f" % [int(screen.x), int(screen.y), int(scr.get("_scale")), need, room, box.global_position.y, list.global_position.y])
	_ok("the books fit the screen", need <= room and box.global_position.y >= 0.0, "%.0f of %.0f" % [need, room])


## A poor month has one way on, and it ends the run.
func report_one_way() -> void:
	var scr: Node = _main.get("_week_report_screen")
	_ok("a poor month has no Stay on", (scr.get("_list").get("items") as Array).size() == 1, str(scr.get("_list").get("items")))
	scr.call("_take_the_bus")


func report_ended() -> void:
	_ok("the bus ends the run at the title", bool(_main.get("_menu_mode")) and _main.get("_week_report_screen") == null)
	_ok("nothing stopped the game after it", not get_tree().paused)


## The other warden's copy: there, staying on is not theirs to say, and the host's closes it.
func report_follower() -> void:
	_main.call("_coop_show_books", {"grade": "fair", "rows": [], "verdict": "v", "coda": "c"})


func report_follower_read() -> void:
	var scr: Node = _main.get("_week_report_screen")
	_ok("the other warden reads the books without Stay on", bool(scr.get("follower")) and (scr.get("_list").get("items") as Array).size() == 1)
	_main.call("_coop_books_closed")
	_ok("the host's Stay on closes them", _main.get("_week_report_screen") == null)


func verdict() -> void:
	print("NOC: %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))


func _ready() -> void:
	super._ready()
	if "--part=report" in OS.get_cmdline_user_args():
		var s: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.5]]
		for g in ["good", "fair", "poor"]:
			s.append_array([["eval", C + ".report_full('%s')" % g], ["wait", 1.0], ["eval", C + ".report_measure()"], ["shot", "report_" + g], ["eval", C + ".report_shut()"], ["wait", 0.4]])
		s.append_array([["eval", C + ".report_follower()"], ["wait", 0.6], ["eval", C + ".report_follower_read()"], ["wait", 0.4]])
		s.append_array([["eval", C + ".report_full('poor')"], ["wait", 1.0], ["eval", C + ".report_one_way()"], ["wait", 3.4], ["eval", C + ".report_ended()"]])
		s.append_array([["eval", C + ".verdict()"], ["eval", "get_tree().quit()"]])
		_steps = s
		return
	var close := ["eval", "_interior_manager._building_interior.close_interior()"]
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		close, ["wait", 2.0], ["eval", "_build_test_camp('')"], ["wait", 2.0], ["eval", C + ".value()"],
		["eval", "debug_jump_to(1, 21.0)"], ["wait", 2.0],
		# He starts the night with you at the PC; then the door between you.
		["eval", C + ".office_in()"], ["wait", 2.0], ["eval", "debug_spawn_enemy('stalker', 3)"], ["wait", 1.5], ["eval", C + ".stalker_hidden()"],
		close, ["wait", 1.5], ["eval", C + ".stalker_seen()"], ["eval", C + ".office_in()"], ["wait", 1.5], close, ["wait", 0.5], ["eval", C + ".stalker_lost()"],
		["eval", "_stop_active_enemy_brain()"], ["wait", 0.5],
		# The office: the windows, the bill.
		["eval", C + ".office_in()"], ["wait", 1.5], ["eval", "_interior_manager._building_interior.enter_crt_view()"], ["wait", 1.5], ["eval", C + ".windows_at_pc()"],
		["eval", C + ".bill_overdue()"], ["wait", 7.0], ["eval", C + ".pc_on()"], ["shot", "ups"], ["eval", C + ".pay()"], ["wait", 1.0], ["eval", C + ".paid_back()"],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.5], ["eval", C + ".windows_in_room()"],
		# The boy, you still in the office.
		["eval", "debug_spawn_enemy('child', 3)"], ["eval", C + ".boy_at()"], ["wait", 1.0], ["eval", C + ".boy_job()"], ["eval", "_stop_active_enemy_brain()"], ["wait", 0.5],
		close, ["wait", 1.5], ["eval", C + ".boy_dawn()"],
		# The granny's bulb.
		["eval", "debug_spawn_enemy('basket', 3)"], ["wait", 1.0], ["eval", C + ".lamp_dark()"], ["eval", "_stop_active_enemy_brain()"], ["wait", 0.5], ["eval", C + ".lamp_back()"],
		# A catch, in front of the office door.
		["door_front", "main_building", 1.2], ["wait", 1.0], ["eval", "debug_spawn_enemy('silent_man', 3)"], ["wait", 0.5], ["eval", C + ".catch()"], ["wait", 0.4],
		["eval", C + ".held()"], ["wait", 0.6], ["eval", C + ".not_through()"], ["wait", 3.5], ["eval", C + ".let_go()"], ["eval", "_stop_active_enemy_brain()"], ["wait", 0.5],
		# The month.
		["eval", C + ".month_days()"], ["eval", "_show_week_report()"], ["wait", 1.5], ["shot", "books"], ["eval", C + ".report_shut()"], ["wait", 1.0],
		# Hurt, saved, loaded.
		["eval", C + ".hurt_save()"], ["wait", 2.0], ["wait_gameplay"], ["wait", 6.0], ["eval", C + ".hurt_loaded()"],
		# The bite, at night, out of doors.
		close, ["wait", 1.5], ["eval", "debug_jump_to(1, 22.0)"], ["wait", 1.0], ["eval", "debug_spawn_enemy('silent_man', 3)"], ["wait", 0.5], ["eval", C + ".bite()"], ["wait", 3.5],
		["eval", C + ".after_bite()"], ["shot", "after_bite"],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]
