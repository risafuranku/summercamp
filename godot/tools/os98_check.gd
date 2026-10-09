extends Control

## The camp computer (scripts/os98/) on its own: boot, every program, every web page,
## the modem, a download, the setup wizard, Builder's night lock, saving and loading.
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


func _windows() -> Array:
	return _shell._windows.get_children().filter(func(w): return not w.is_queued_for_deletion())


func _app(app_id: String):
	for w in _windows():
		if w.app_id == app_id:
			return w.content.get_child(0) if w.content.get_child_count() > 0 else null
	return null


func _close_all() -> void:
	for w in _windows():
		_shell._close_window(w)
	await _frames()


func _run() -> void:
	# Boot: BIOS, splash, desktop.
	_shell.open_panel()
	await _wait(1.0)
	await _shot("bios")
	await _wait(3.2)
	await _shot("splash")
	var t := 0.0
	while not _shell.is_desktop_ready() and t < 10.0:
		await _wait(0.25)
		t += 0.25
	_expect(_shell.is_desktop_ready(), "the computer did not boot to the desktop")
	await _wait(1.2)
	await _close_all()
	await _shot("desktop")

	# What is there from the start, and what is not.
	_expect(not _shell._is_program_unlocked("builder"), "Builder is installed before it was downloaded")
	_expect(_shell.open_app("builder") == null, "Builder opened without being installed")
	await _close_all()
	for id in ["mycomputer", "bin", "mail", "notepad", "mines", "imageview"]:
		var w = _shell.open_app(id, {"file": "README.TXT"} if id == "notepad" else ({"file": "IMG0043.JPG"} if id == "imageview" else {}))
		_expect(w != null, "%s did not open" % id)
		await _frames(3)
		await _shot("app_" + id)
		await _close_all()
	_shell.open_app("folder", {"path": "C:\\VERA"})
	await _frames(3)
	await _shot("folder_vera")
	await _close_all()

	# Every text file on the disk has text.
	for f in _shell.FILES.TEXTS:
		_expect(not _shell.FILES.text_of(f).is_empty(), "%s is empty" % f)

	# The web: the modem first.
	_shell.open_app("browser")
	await _frames(3)
	var br = _app("browser")
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
			if not target.begins_with("download://") and not WEB.PAGES.has(target) and not target in ["volny.cz/~blatna", "volny.cz/~zamek"]:
				_failures.append("page %s links to missing %s" % [key, target])
	for key in ["stavitel98.cz", "cerne-jezero.cz/guestbook", "kuryr-hlubocany.cz/1987", "volny.cz/~strasidla", "hostinec-u-jezera.cz"]:
		br._show(key)
		await _frames(3)
		await _shot("web_" + key.replace("/", "_").replace("~", ""))
	br.navigate("builder")
	await _wait(2.4)
	_expect(br._page.get_parsed_text().find("Stavitel") >= 0, "searching 'builder' does not find Stavitel")
	br.navigate("www.nowhere.cz")
	await _wait(2.4)
	_expect(br._page.get_parsed_text().find("cannot be displayed") >= 0, "an unknown address does not give the error page")

	# Download Builder from the web, then install it with its setup program.
	_shell.start_download("BLDR98SW.EXE", "http://www.stavitel98.cz")
	await _frames(3)
	var dl = _app("download")
	_expect(dl != null, "no download window")
	await _wait(1.5)
	await _shot("download")
	if dl != null:
		dl._got = dl._kb
		await _frames(3)
		await _shot("download_done")
	_expect(_shell.downloads().has("BLDR98SW.EXE"), "the download did not land in C:\\DOWNLOAD")
	await _close_all()
	_shell.open_file("C:\\DOWNLOAD", "BLDR98SW.EXE")
	await _frames(3)
	var su = _app("setup")
	_expect(su != null, "the setup program did not start")
	if su != null:
		await _shot("setup_welcome")
		su._go(1)
		await _frames(2)
		_expect(su._next.disabled, "setup lets you past the licence without agreeing")
		await _shot("setup_licence")
		su._agree = true
		su._go(2)
		await _frames(2)
		su._go(3)
		await _wait(1.0)
		await _shot("setup_copying")
		su._copy_t = 100.0
		await _frames(3)
		await _shot("setup_done")
	_expect(_shell._is_program_unlocked("builder"), "Builder is not installed after setup")
	_expect(_installed.has("builder"), "program_installed was not emitted for Builder")
	_expect(_shell.bin_items().has("BLDR98SW.EXE"), "the setup file did not go to the Recycle Bin")
	await _close_all()

	# Builder by day, not at night.
	_shell.set_is_day(true)
	_expect(_shell.open_app("builder") != null, "Builder does not open by day")
	await _frames(4)
	var bm = _app("builder")._module if _app("builder") != null else null
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
	await _shot("builder")
	_shell.set_is_day(false)
	await _frames(2)
	_expect(_app("builder") == null, "Builder stays open at night")
	_expect(_shell.open_app("builder") == null, "Builder opens at night")
	await _close_all()
	_shell.set_is_day(true)

	# CampStat and GuestRack.
	_shell._on_program_installed("camp_status")
	_shell._on_program_installed("guestrack")
	_shell.open_app("camp_status")
	await _frames(3)
	var cs = _app("camp_status")
	_expect(cs != null, "CampStat did not open")
	if cs != null:
		for i in cs.TABS.size():
			cs._tabs.current_tab = i
			await _frames(2)
			var p: RichTextLabel = cs._pages[str(cs.TABS[i][0])]
			_expect(p.get_parsed_text().length() > 20, "CampStat tab %s is empty" % cs.TABS[i][0])
			await _shot("campstat_" + str(cs.TABS[i][0]))
	await _close_all()
	_shell.open_app("guestrack")
	await _frames(3)
	_expect(_app("guestrack") != null, "GuestRack did not open")
	await _shot("guestrack")
	await _close_all()
	await _shot("desktop_installed")

	# Save and load keep what was installed and what is in the bin.
	var saved: Dictionary = _shell.export_persistent_state()
	_shell.import_persistent_state({})
	_expect(not _shell._is_program_unlocked("builder"), "a new game keeps Builder")
	_shell.import_persistent_state(saved)
	_expect(_shell._is_program_unlocked("builder") and _shell._is_program_unlocked("camp_status"), "loading lost installed programs")
	_expect(_shell.bin_items().has("BLDR98SW.EXE"), "loading lost the Recycle Bin")
	# An old save from the previous computer only carries the unlock registry.
	_shell.import_persistent_state({"unlock_registry": {"builder": true}})
	_expect(_shell._is_program_unlocked("builder") and _shell.bin_items().has("DOPIS.TXT"), "an old save does not load cleanly")

	# The mail list: a log stamped a day later sorts after its own day.
	_shell.import_persistent_state(saved)
	_shell.open_panel()
	t = 0.0
	while not _shell.is_desktop_ready() and t < 10.0:
		await _wait(0.25)
		t += 0.25
	_shell.open_app("mail")
	await _frames(2)
	var mail = _app("mail")
	if mail != null:
		var night_log := {"day": 4, "time": "03:00", "stamp_day_offset": 1}
		_expect(mail._date_label(night_log) == "Day 5  03:00", "night log label: %s" % mail._date_label(night_log))
		_expect(mail._sort_key(night_log) > mail._sort_key({"day": 4, "time": "23:59"}), "a night log does not sort after its own day")

	print("")
	if _failures.is_empty():
		print("OS98 CHECK: PASS")
		get_tree().quit(0)
	else:
		print("OS98 CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)
