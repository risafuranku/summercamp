extends Control

## The camp computer (scripts/os98/) on its own: the boot, the panel and its tabs (keys
## 1-9, the badges, a program kept running behind another), the one-click installs,
## Builder's night licence, every web page, Files, Jobs (DataPunch, KlikBanka, SectiTo),
## Games, Shops, saving and loading.
##
##   godot --headless --path godot res://tools/os98_check.tscn
##   godot --path godot res://tools/os98_check.tscn -- --shots=<dir>   (screenshots)

const SHELL = preload("res://scripts/os98/os_shell.gd")
const WEB = preload("res://scripts/os98/web_pages.gd")

var _failures: Array[String] = []
var _vp: SubViewport
var _shell
var _shots := ""
var _installed: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
	var box := SubViewportContainer.new()
	box.size = Vector2(640, 480)
	add_child(box)
	_vp = SubViewport.new()
	_vp.size = Vector2i(640, 480)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(_vp)
	_shell = SHELL.new()
	_shell.size = Vector2(640, 480)
	_vp.add_child(_shell)
	_shell.setup(null, null, null, self)
	EventBus.program_installed.connect(func(id): _installed.append(id))
	_run.call_deferred()


# Stand-ins for main.gd, so CampStat has something to show.
func get_electricity_ui_snapshot() -> Dictionary:
	return {
		"day": 3, "time": "14:20", "rate_per_kwh": 0.42, "base_fee": 12, "daily_kwh_total": 38.5,
		"daily_cost_energy": 16, "daily_cost_total": 28, "unpaid_count": 1, "overdue_count": 1,
		"unpaid_total": 31, "overdue_total": 25, "bill_grace_days": 3, "bill_issue_hour": 20,
		"consumption_lines": [{"label": "Lamp post", "coord": Vector2i(4, 7), "power_units": 2, "kwh_per_day": 4.8, "cost_per_day": 2},
			{"label": "Cabin", "coord": Vector2i(12, 3), "power_units": 6, "kwh_per_day": 14.4, "cost_per_day": 6}],
		"bills": [{"id": "b1", "service_day": 1, "issued_day": 2, "due_day": 5, "amount": 25, "kwh_total": 30.0, "status": "unpaid", "is_overdue": true, "days_left": -1},
			{"id": "b2", "service_day": 2, "issued_day": 3, "due_day": 6, "amount": 31, "kwh_total": 36.0, "status": "unpaid", "is_overdue": false, "days_left": 3}],
	}


func get_upkeep_snapshot() -> Dictionary:
	return {"rows": [{"label": "Shower block", "condition": 0.0, "broken": true, "cost": 40}, {"label": "Tent 4:7", "condition": 0.62, "cost": 8}], "crew_jobs": 2, "crew_cost": 96, "night": false}


func _time_of_day_string() -> String:
	return "14:20"


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_shots.path_join("os98_%s.png" % name))


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_failures.append(msg)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	_vp.push_input(e)
	var up := e.duplicate()
	up.pressed = false
	_vp.push_input(up)


func _install(id: String) -> void:
	_shell.begin_install(id)
	var t := 0.0
	while not _shell._is_program_unlocked(id) and t < 6.0:
		await _wait(0.2)
		t += 0.2


func _run() -> void:
	# Boot: BIOS, the maker, Okna, the panel. (About seven seconds.)
	_shell.open_panel()
	await _wait(1.0)
	await _shot("bios")
	await _wait(2.6)
	await _shot("splash")
	var t := 0.0
	while not _shell.is_desktop_ready() and t < 10.0:
		await _wait(0.25)
		t += 0.25
	_expect(_shell.is_desktop_ready(), "the computer did not boot to the panel")
	_expect(t < 8.0, "the boot took %.1f s (want it short)" % (t + 3.6))
	await _wait(0.6)
	_shell.close_message_boxes()
	_expect(_shell.current_tab() != "", "no tab is shown after the boot")
	await _shot("panel")
	_shell._open_start_menu()
	await _frames(3)
	await _shot("start_menu")
	_shell._close_start_menu()

	# The tabs: every one opens by its key; a program keeps running behind another.
	for i in _shell.TABS.size():
		_key(KEY_1 + i if i < 9 else KEY_0)
		await _frames(3)
		_expect(_shell.current_tab() == str(_shell.TABS[i][0]), "key %d did not show %s (shows %s)" % [i + 1, _shell.TABS[i][0], _shell.current_tab()])
		await _shot("tab_%d_%s" % [i + 1, _shell.TABS[i][0]])
	_shell.close_message_boxes()
	var cs_before = _shell.app_of("camp_status")
	_key(KEY_4)
	await _frames(2)
	_key(KEY_2)
	await _frames(2)
	_expect(cs_before != null and _shell.app_of("camp_status") == cs_before, "CampStat was started again on switching back (should keep running)")
	# A text field takes the digits: no switching while you type.
	_shell.open_app("files")
	await _frames(2)
	_shell._open_run_dialog()
	await _frames(3)
	_key(KEY_3)
	await _frames(2)
	_expect(_shell.current_tab() == "files", "a digit typed into Run switched the tab")
	_shell._close_dialogs()
	await _frames(2)

	# What is there from the start, and what is not.
	_expect(not _shell._is_program_unlocked("builder"), "Builder is installed before it was downloaded")
	_expect(_shell._is_program_unlocked("camp_status"), "CampStat is not there from the start")
	_expect(_shell.open_app("builder") == null, "Builder opened without being installed")
	_expect(_shell.current_tab() == "builder", "the Builder tab did not come forward to offer the install")
	await _shot("builder_not_installed")

	# One click installs it there and then.
	_shell.begin_install("builder")
	await _wait(1.4)
	await _shot("builder_installing")
	t = 0.0
	while not _shell._is_program_unlocked("builder") and t < 6.0:
		await _wait(0.2)
		t += 0.2
	_expect(_shell._is_program_unlocked("builder"), "Builder is not installed after the one-click install")
	_expect(_installed.has("builder"), "program_installed was not emitted for Builder")
	_expect(_shell.bin_items().has("BLDR98SW.EXE"), "the setup file did not go to the Recycle Bin")
	await _frames(4)
	_shell.close_message_boxes()

	# Builder by day, covered at night, the same plan in the morning.
	_shell.set_is_day(true)
	_expect(_shell.open_app("builder") != null, "Builder does not open by day")
	await _frames(4)
	var ba = _shell.app_of("builder")
	var bm = ba._module if ba != null else null
	_expect(bm != null, "Builder has no planner inside")
	if bm != null:
		bm._open_category("housing")
		await _frames(2)
		_expect(bm._cards.get_child_count() == 3, "the Housing catalogue has %d cards, want 3" % bm._cards.get_child_count())
		_expect(bm._cost("tent_1") > 0, "the tent has no price")
		bm._select("cabin_1")
		_expect(bm._map_panel.selected_building == "cabin_1", "choosing a card does not arm the map")
		_expect(bm._status_cost.text.find("$") >= 0, "the status bar does not show the price")
		bm._select("")
		bm._open_category("")
		_expect(not bm._catalogue.visible, "the catalogue stays open")
	await _wait(2.6)
	_shell.close_message_boxes()
	await _shot("builder")
	_shell.set_is_day(false)
	await _frames(3)
	_expect(_shell.open_app("builder") == null, "Builder opens at night")
	var page = _shell._pages.get("builder")
	_expect(page != null and page.cover != null and str(page.cover.get_meta("kind", "")) == "licence", "Builder has no licence cover at night")
	await _shot("builder_night")
	_shell.set_is_day(true)
	await _frames(3)
	_expect(_shell.open_app("builder") != null and _shell.app_of("builder") == ba, "Builder did not come back as it was in the morning")

	# CampStat and GuestRack.
	_shell.open_app("camp_status")
	await _frames(3)
	var cs = _shell.app_of("camp_status")
	_expect(cs != null, "CampStat did not open")
	if cs != null:
		for i in cs.TABS.size():
			cs.select_page(str(cs.TABS[i][0]))
			await _frames(3)
			_expect(cs.drawn_chars > 20, "CampStat page %s is empty" % cs.TABS[i][0])
			await _shot("campstat_" + str(cs.TABS[i][0]))
	_shell._on_program_installed("guestrack")
	_expect(_shell.open_app("guestrack") != null, "GuestRack did not open")
	await _frames(3)
	await _shot("guestrack")

	# Files: Vera's documents, a text read in place, a letter out of the bin.
	_shell.open_app("vera")
	await _frames(3)
	var fa = _shell.app_of("files")
	_expect(fa != null and _shell.current_tab() == "files", "Documents did not open the Files tab")
	for f in _shell.FILES.TEXTS:
		_expect(not _shell.FILES.text_of(f).is_empty(), "%s is empty" % f)
	if fa != null:
		fa._select_file("README.TXT")
		await _frames(2)
		_expect(fa._text.visible and fa._text.get_parsed_text().find("CAMPMAIL") >= 0, "README.TXT is not shown in Files")
		await _shot("files_readme")
		fa.reopen({"path": "BIN"})
		fa._select_file("DOPIS.TXT")
		await _frames(2)
		await _shot("files_bin")
		fa._restore_file()
		await _frames(2)
		_expect(not _shell.bin_items().has("DOPIS.TXT") and _shell.list_dir("C:\\VERA").has("DOPIS.TXT"), "restoring from the bin did not put DOPIS.TXT back")
		_expect(fa._text.visible and fa._text.get_parsed_text().find("Vero") >= 0, "the restored letter is not shown")

	# The screen saver comes on when nobody touches it, and the slightest move wakes it
	# (playtest 2026-10-16: it would not go away).
	var ex = _shell.extras()
	var old_wait: float = ex.saver_wait
	ex.saver_wait = 0.3
	await _wait(0.6)
	_expect(not ex.is_saving(), "the screen saver comes on while somebody sits at the computer")
	_shell.close_panel()
	await _wait(0.6)
	_expect(ex.is_saving(), "the screen saver does not come on at an empty desk")
	_shell.open_panel()
	var mv := InputEventMouseMotion.new()
	mv.position = _shell._mouse + Vector2(0.2, 0)
	mv.relative = Vector2(0.2, 0)
	_shell._input(mv)
	_expect(not ex.is_saving(), "a slow mouse move does not wake the screen saver")
	ex.saver_wait = old_wait
	ex.poke()

	# The web: the modem first.
	_shell.open_app("browser")
	await _frames(3)
	var br = _shell.app_of("browser")
	_expect(br != null and br._dial.visible, "the browser did not offer to dial")
	await _shot("dialer")
	br._start_dial()
	await _wait(8.2)
	_expect(_shell.is_online(), "the modem did not connect")
	await _wait(1.6)
	await _shot("web_portal")
	# Every page renders, with no shorthand left over and no dead internal link.
	for key in WEB.PAGES:
		br._show(key)
		await _frames()
		var txt: String = br._page.get_parsed_text()
		_expect(txt.length() > 80, "page %s is nearly empty" % key)
		_expect(txt.find("{") < 0 and txt.find("[url") < 0 and txt.find("[/") < 0, "page %s has unexpanded markup" % key)
		var body: String = br._expand(str(WEB.PAGES[key]["body"]), "#000000", key)
		var re := RegEx.new()
		re.compile("\\[url=([^\\]]+)\\]")
		for m in re.search_all(body):
			var target: String = m.get_string(1)
			# download://, licence:// and the like are the browser's own actions.
			if target.find("://") < 0 and not target.begins_with("search?") and not WEB.PAGES.has(target) and not target in ["volny.cz/~blatna", "volny.cz/~zamek"]:
				_failures.append("page %s links to missing %s" % [key, target])
			if target.begins_with("download://") and _shell.installer_of(target.trim_prefix("download://")) == "":
				_failures.append("page %s offers %s, which installs nothing" % [key, target])
	for key in ["stavitel98.cz", "cerne-jezero.cz/guestbook", "kuryr-hlubocany.cz/1987", "volny.cz/~strasidla", "hostinec-u-jezera.cz", "povodi-hlubocany.cz", "bohemia-online.cz/weather", "bohemia-online.cz/hry", "bohemia-online.cz/prace", "bohemia-online.cz/chat", "kuryr-hlubocany.cz/dnes", "tv.bohemia-online.cz", "obec-lesna.cz", "agrostroj-hlubocany.cz", "bohemia-online.cz"]:
		if WEB.PAGES.has(key):
			br._show(key)
			await _wait(3.0 if _shots != "" else 0.1)
			await _shot("web_" + key.replace("/", "_").replace("~", ""))
	br.navigate("builder")
	await _wait(2.4)
	_expect(br._page.get_parsed_text().find("Stavitel") >= 0, "searching 'builder' does not find Stavitel")
	br.navigate("www.nowhere.cz")
	await _wait(2.4)
	_expect(br._page.get_parsed_text().find("cannot be displayed") >= 0, "an unknown address does not give the error page")
	# A download link on a page installs on its tab.
	_shell.start_download("DATAPNCH.EXE", "http://www.kuryr-hlubocany.cz")
	await _frames(2)
	_expect(_shell.current_tab() == "jobs", "DATAPNCH.EXE from the web did not bring up the Jobs tab")
	await _wait(0.6)
	await _shot("jobs_installing")
	t = 0.0
	while not _shell._is_program_unlocked("datapunch") and t < 6.0:
		await _wait(0.2)
		t += 0.2
	_expect(_shell._is_program_unlocked("datapunch"), "DataPunch did not install from its link")

	# Jobs: DataPunch types the old register, paid per card.
	_shell.open_app("datapunch")
	await _frames(3)
	var jobs = _shell.app_of("jobs")
	var dp = jobs.current_app() if jobs != null else null
	_expect(dp != null and dp.has_method("_file"), "DataPunch did not open on the Jobs tab")
	if dp != null and dp.has_method("_file"):
		var money0: int = CoreRoot.get_state().money
		for i in dp.FIELDS.size():
			(dp._inputs[i] as LineEdit).text = str(dp._cur[dp.FIELDS[i]])
		dp._file()
		_expect(CoreRoot.get_state().money == money0 + dp.RATE, "a perfect card did not pay the rate (%d -> %d)" % [money0, CoreRoot.get_state().money])
		for i in dp.FIELDS.size():
			(dp._inputs[i] as LineEdit).text = "XXXXXXXXXX"
		var money1: int = CoreRoot.get_state().money
		dp._file()
		_expect(CoreRoot.get_state().money == money1, "a card full of mistakes was paid")
		await _frames(2)
		await _shot("datapunch")
		while dp._done_tonight() < dp.NIGHT_LIMIT:
			dp._add_done(1)
		var money2: int = CoreRoot.get_state().money
		for i in dp.FIELDS.size():
			(dp._inputs[i] as LineEdit).text = str(dp._cur[dp.FIELDS[i]])
		dp._file()
		_expect(CoreRoot.get_state().money == money2, "the office paid past its nightly limit")
	# KlikBanka: a shift, an advert confirmed, a scam clicked.
	await _install("adclick")
	_shell.open_app("adclick")
	await _frames(3)
	var ad = jobs.current_app() if jobs != null else null
	_expect(ad != null and ad.has_method("_begin"), "KlikBanka did not open")
	if ad != null and ad.has_method("_begin"):
		await _shot("adclick_idle")
		ad._begin()
		await _wait(2.5)
		await _shot("adclick_shift")
		ad._pops.clear()
		var r := Rect2(Vector2(20, 20), ad.POP)
		ad._pops.append({"t": 0.0, "rect": r, "shake": 0.0, "kind": "ad", "title": "Kofola", "head": "KOFOLA", "body": "x", "btn": "OK", "life": 9.0})
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = ad._btn_rect(r).get_center()
		ad._area_input(click)
		_expect(ad._ok == 1, "confirming an advert did not count")
		ad._pops.append({"t": 0.0, "rect": r, "shake": 0.0, "kind": "scam", "title": "X", "head": "WON", "body": "x", "btn": "CLAIM!", "life": 9.0})
		ad._area_input(click)
		_expect(ad._bad == 1 and ad._pops.size() >= 2, "clicking a prize was not a mistake (or brought no more of them)")
		var money3: int = CoreRoot.get_state().money
		ad._ok = 5
		ad._end()
		_expect(CoreRoot.get_state().money == money3 + 3, "the shift paid %d, want 3 (5 adverts - 2 for a mistake)" % (CoreRoot.get_state().money - money3))
		await _frames(2)
		await _shot("adclick_done")
	# SectiTo: count right, paid 3.
	await _install("census")
	_shell.open_app("census")
	await _frames(3)
	var ce = jobs.current_app() if jobs != null else null
	_expect(ce != null and ce.has_method("_new_photo"), "SectiTo did not open")
	if ce != null and ce.has_method("_new_photo"):
		ce._new_photo()
		await _frames(3)
		await _shot("census_photo")
		var money4: int = CoreRoot.get_state().money
		ce._input.text = str(ce._answer)
		ce._submit()
		_expect(CoreRoot.get_state().money == money4 + ce.PAY, "the right count was not paid")
		await _frames(2)
		await _shot("census_shown")

	# Games: on the machine already (they were Vera's), with the old names on the tables.
	_shell.open_app("mines")
	await _frames(3)
	var games = _shell.app_of("games")
	_expect(games != null and games.current_app() != null, "Mines did not open on the Games tab")
	await _shot("games_mines")
	for g in ["mosquito", "hike", "pexeso"]:
		_expect(_shell._is_program_unlocked(g), "%s is not on the machine from the start" % g)
		_expect(str(_shell.scores(g)[0][0]) == "Vera", "%s's table does not start with the old scores" % g)
		_shell.open_app(g)
		await _frames(3)
		var ga = games.current_app() if games != null else null
		_expect(ga != null, "%s did not open" % g)
		await _shot("game_" + g)
	# A result goes on the table in its place, under the warden's name.
	var rank: int = _shell.add_score("pexeso", 12)
	_expect(rank == 0 and int(_shell.scores("pexeso")[0][1]) == 12 and _shell.scores("pexeso").size() == 5, "a best Pexeso game did not go to the top of the table")
	_expect(_shell.add_score("mines", 999) == -1, "a slow Mines game got onto the Best Times")
	_shell.open_app("mosquito")
	await _frames(2)
	var mo = games.current_app()
	if mo != null and mo.has_method("_begin"):
		mo._begin()
		mo._add_bug(0.0)
		var hit := InputEventMouseButton.new()
		hit.button_index = MOUSE_BUTTON_LEFT
		hit.pressed = true
		hit.position = mo._bugs[0]["p"]
		mo._gui_input(hit)
		_expect(mo._score == 1, "swatting a mosquito did not count")
		await _wait(2.0)
		await _shot("game_mosquito_play")
	_shell.open_app("pexeso")
	await _frames(2)
	var px = games.current_app()
	_expect(px != null and px._cards.size() == 24, "Pexeso did not deal 24 cards")
	_shell.open_app("hike")
	await _frames(2)
	var hk = games.current_app()
	if hk != null and hk.has_method("_begin"):
		hk._begin()
		await _wait(1.0)
		_expect(hk._state == "play" or hk._state == "over", "the hike did not start")
		await _shot("game_hike_play")

	# Shops: without a licence the tab says where to get one.
	_shell.open_app("pub_app")
	await _frames(3)
	_expect(_shell.current_tab() == "shops", "Hostinsky 98 did not bring up the Shops tab")
	await _shot("shops")

	# Save and load keep what was installed, the bin, the scores and the tab.
	_shell.open_app("guestrack")
	var saved: Dictionary = _shell.export_persistent_state()
	_expect(str(saved.get("tab", "")) == "guestrack", "the save does not keep the open tab")
	_shell.import_persistent_state({})
	_expect(not _shell._is_program_unlocked("builder"), "a new game keeps Builder")
	_expect(int(_shell.scores("pexeso")[0][1]) == 19, "a new game keeps the last camp's high scores")
	_shell.import_persistent_state(saved)
	_expect(_shell._is_program_unlocked("builder") and _shell._is_program_unlocked("camp_status") and _shell._is_program_unlocked("census"), "loading lost installed programs")
	_expect(_shell.bin_items().has("BLDR98SW.EXE"), "loading lost the Recycle Bin")
	_expect(int(_shell.scores("pexeso")[0][1]) == 12, "loading lost the high scores")
	# An old save from the previous computer only carries the unlock registry.
	_shell.import_persistent_state({"unlock_registry": {"builder": true}})
	_expect(_shell._is_program_unlocked("builder") and _shell.bin_items().has("DOPIS.TXT"), "an old save does not load cleanly")

	# The mail list after a reboot: a log stamped a day later sorts after its own day.
	_shell.import_persistent_state(saved)
	_shell.open_panel()
	t = 0.0
	while not _shell.is_desktop_ready() and t < 12.0:
		await _wait(0.25)
		t += 0.25
	_expect(_shell.current_tab() == "guestrack" or _shell.current_tab() == "mail", "the panel did not come back on the saved tab (or the mail)")
	_shell.open_app("mail")
	var mail = null
	t = 0.0
	while mail == null and t < 5.0:
		await _wait(0.25)
		t += 0.25
		mail = _shell.app_of("mail")
	_expect(mail != null, "CampMail did not open after a reboot")
	if mail != null:
		var night_log := {"day": 4, "time": "03:00", "stamp_day_offset": 1}
		_expect(mail._date_label(night_log) == "Wed 23.9.  03:00", "night log label: %s" % mail._date_label(night_log))
		# Delete goes to Deleted Items, then away; a reply lands in Sent Items.
		var probe := {"from": "Test <t@t.cz>", "subject": "probe", "body": "x", "day": 2, "time": "10:00", "type": "spam", "_runtime_id": 99999, "image": "spam_chain", "attachment": "ANDEL.GIF"}
		EmailManager.inbox.append(probe)
		mail.refresh()
		mail._show_message(probe)
		await _frames(2)
		await _shot("mail_spam")
		mail._delete_current()
		_expect(str(probe.get("_folder", "")) == "deleted", "Delete does not move to Deleted Items")
		EmailManager.delete_mail(probe)
		_expect(not EmailManager.inbox.has(probe), "a deleted message cannot be deleted for good")
		var sent_before: int = EmailManager.sent.size()
		mail._open_compose("Vera <vera@post.cz>", "Re: test", "hello")
		await _frames(2)
		await _shot("mail_compose")
		mail._send()
		_expect(EmailManager.sent.size() == sent_before + 1, "a sent message is not in Sent Items")
		_expect(mail._sort_key(night_log) > mail._sort_key({"day": 4, "time": "23:59"}), "a night log does not sort after its own day")
	# The guest book: a review comes as an entry to answer; the answer moves the camp's name.
	EmailManager.reputation = 0.0
	EmailManager._on_review_posted({"rating": 1, "name": "Pepa Novak", "text": "Filthy toilets.", "day": 3, "stay_nights": 2})
	var entry: Dictionary = EmailManager.inbox.back()
	_expect(str(entry.get("type", "")) == "review", "a review did not arrive as a guest book entry")
	var mail2 = _shell.app_of("mail")
	if mail2 != null:
		mail2.refresh()
		mail2._show_message(entry)
		await _frames(2)
		await _shot("mail_review")
		mail2._answer_review("sorry")
		_expect(EmailManager.reputation > 0.03, "apologising for a one-star stay did not help (%.3f)" % EmailManager.reputation)
		_expect(EmailManager.reply_to_review(entry, "defend") == 0.0, "an entry could be answered twice")

	print("")
	if _failures.is_empty():
		print("OS98 CHECK: PASS")
		get_tree().quit(0)
	else:
		print("OS98 CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)
