extends "res://tools/shot_driver.gd"

## The second monitor (scripts/reception/post_delivery.gd, os_shell's second screen,
## building_interior's A/D): the order paid, the van on the clock, the postman across
## the counter, the slip signed, the monitor on the desk, the two screens and the swap,
## the keys for the screen you look at, the PC's record through a save, the postman who
## gives up at closing time and comes back the next morning.
##   godot --headless --path godot res://tools/post_check.tscn

var _fails: Array = []


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"],
		["call", "_on_menu_new_camp", ["PostCheck", 4242, false, true, {"threats": false, "weather": false, "events": false, "wear": false, "money": 1000}]],
		["wait_gameplay"], ["wait", 2.0],
		["eval", "debug_jump_to(2, 9.0)"], ["wait", 1.0],
		["mine", "_sit"], ["wait", 15.0],
		["mine", "_c_order"], ["wait", 1.2],
		["mine", "_c_arrive"], ["wait", 1.2],
		["mine", "_c_arriving"], ["wait", 1.2],
		["mine", "_c_at_desk"], ["wait", 1.2],
		["mine", "_c_sign"], ["wait", 2.2],
		["mine", "_c_dual"], ["wait", 2.0],
		["mine", "_c_screens"], ["wait", 1.0],
		["mine", "_c_save"], ["wait", 3.5],
		["mine", "_c_missed"], ["wait", 1.2],
		["mine", "_c_missed2"], ["wait", 2.5],
		["mine", "_c_end"],
	]


func _run_step(step: Array) -> void:
	if str(step[0]) == "mine":
		call(str(step[1]))
		return
	super._run_step(step)


func _ok(cond: bool, what: String) -> void:
	print("POST_CHECK ", "ok   " if cond else "FAIL ", what)
	if not cond:
		_fails.append(what)


func _bi():
	return _main._interior_manager._building_interior


func _post():
	return _bi()._post


func _shell():
	return _bi()._crt_ui


func _now() -> float:
	return _main._now_abs_minutes_float()


func _sit() -> void:
	var bi = _bi()
	if not bi.visible:
		_main._interior_manager.handle_structure_interact(_main._find_reception_structure())
		await get_tree().create_timer(3.0).timeout
	bi.enter_crt_view()


func _c_order() -> void:
	var m0: int = CoreRoot.get_money()
	_ok(_post().stage() == "", "no order in a new camp")
	_ok(_post().order(), "the order is taken")
	_ok(CoreRoot.get_money() == m0 - _post().PRICE, "the set is paid (%d -> %d)" % [m0, CoreRoot.get_money()])
	_ok(not _post().order(), "a second order is refused")
	var d: Dictionary = _post().state()
	var h := fmod(float(d["due"]), 1440.0) / 60.0
	_ok(_post().stage() == "ordered" and h >= _post().HOURS_FROM and h <= _post().HOURS_TO, "it comes in the post's hours (%.2f)" % h)


func _c_arrive() -> void:
	var d: Dictionary = _post().state()
	d["due"] = _now()
	_post()._set_state(d)


func _c_arriving() -> void:
	_ok(_post().stage() == "arriving", "the van comes when due (%s)" % _post().stage())
	_ok(_post()._van != null and _post()._van.visible, "the van is on the road")
	_ok(_post()._path_len > 5.0, "a way from the van to the office door (%.1f m)" % _post()._path_len)
	# On to the end of his walk.
	var d: Dictionary = _post().state()
	d["t0"] = _now() - 500.0
	_post()._set_state(d)


func _c_at_desk() -> void:
	_ok(_post().stage() == "at_desk", "he reaches the counter (%s)" % _post().stage())
	_ok(_post()._desk_man != null and _post()._desk_man.visible, "the postman stands across the counter")
	var hb = _bi()._extras.hot.get("postman", {}).get("body", null)
	_ok(hb != null and hb.collision_layer == 1, "he can be clicked")
	_ok(not _bi()._dual, "no second monitor before the signature")


func _c_sign() -> void:
	_bi()._exit_crt_view()
	_ok(_bi().dressing_click("postman"), "a click on him opens the slip")
	_ok(_post().is_closeup_open(), "the slip is open")
	var c = _post()._closeup
	c._strokes = [PackedVector2Array([Vector2(100, 166), Vector2(140, 170), Vector2(180, 164)])]
	c._ink = 90.0
	c._wait = 0.05
	await get_tree().create_timer(1.4).timeout
	_ok(c._phase == "parcel", "signed: the parcel is pushed over (%s)" % c._phase)
	c._clicked("parcel")


func _c_dual() -> void:
	_ok(_post().stage() == "delivered", "the parcel is signed for")
	_ok(_bi()._dual and _shell().is_dual(), "the second monitor is on the desk and the PC knows it")
	_ok(_bi()._crt_viewport.size == Vector2i(1280, 480), "the PC draws two screens (%s)" % str(_bi()._crt_viewport.size))
	_ok(_bi()._radio_set.position.y > 1.5, "the radio has gone up on the second monitor")
	_ok(not _post()._desk_man.visible, "the postman has gone from the counter")
	_bi().enter_crt_view()


func _c_screens() -> void:
	var bi = _bi()
	var sh = _shell()
	_ok(sh._tab != "" and sh._tab2 != "" and sh._tab != sh._tab2, "a program on each screen (%s / %s)" % [sh._tab, sh._tab2])
	bi._crt_turn(1)
	_ok(sh.screen() == 1 and bi._look_screen() == bi._crt2_screen, "D turns to the second monitor")
	var on1: String = sh._tab
	var on2: String = sh._tab2
	sh._select_tab("files")
	_ok(sh._tab2 == "files" and sh._tab == on1, "a tab picked looking right opens on the right (%s / %s)" % [sh._tab, sh._tab2])
	sh._select_tab(on1)
	_ok(sh._tab2 == on1 and sh._tab == "files", "picking the other screen's program swaps them (%s / %s)" % [sh._tab, sh._tab2])
	var right_page: Control = sh._pages[sh._tab2]
	var left_page: Control = sh._pages[sh._tab]
	_ok(right_page.visible and left_page.visible and right_page.position.x == 640.0 and left_page.position.x == 0.0, "both pages up, side by side")
	_ok(sh.keys_for(right_page) and not sh.keys_for(left_page), "the keys are the right screen's")
	bi._crt_turn(0)
	_ok(sh.screen() == 0 and sh.keys_for(left_page) and not sh.keys_for(right_page), "A back: the keys are the left screen's")
	_ok(on2 != "", "the second screen had a program of its own")


func _c_save() -> void:
	var pc: Dictionary = _bi().export_crt_desktop_state()
	_ok(str(pc.get("store", {}).get("post", {}).get("stage", "")) == "delivered", "the order is in the PC's record")
	_ok(str(pc.get("tab2", "")) != "", "the second screen's program is kept")
	_bi()._exit_crt_view()
	# Another camp: no monitor; this one back: the monitor again.
	_bi().import_crt_desktop_state({})
	await get_tree().create_timer(1.2).timeout
	_ok(not _bi()._dual and not _shell().is_dual(), "a camp without the order has one monitor")
	_bi().import_crt_desktop_state(pc)
	await get_tree().create_timer(1.2).timeout
	_ok(_bi()._dual and _shell().is_dual(), "loaded, the second monitor is back")


func _c_missed() -> void:
	_main.debug_jump_to(3, 19.2)
	_post()._set_state({"stage": "at_desk", "t0": _now(), "no": 500})


func _c_missed2() -> void:
	_ok(_post().stage() == "missed", "at closing time he gives up (%s)" % _post().stage())
	var d: Dictionary = _post().state()
	d["t0"] = _now() - 500.0
	_post()._set_state(d)
	await get_tree().create_timer(1.2).timeout
	d = _post().state()
	var h := fmod(float(d.get("due", 0.0)), 1440.0) / 60.0
	_ok(_post().stage() == "ordered" and float(d["due"]) > _now() and h >= _post().HOURS_FROM and h <= _post().HOURS_TO, "he comes again the next morning (%.2f)" % h)
	_ok(not _bi()._dual, "no monitor while it is not signed for")


func _c_end() -> void:
	print("POST_CHECK ", "PASS" if _fails.is_empty() else "FAIL %s" % str(_fails))
	get_tree().quit()
