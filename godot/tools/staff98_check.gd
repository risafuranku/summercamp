extends "res://tools/shot_driver.gd"

## The staff as one (TODO W3): Personal 98's pages with hands at a pub, a corn stand and in
## the staffroom; somebody taken on today in only tomorrow; a staffroom hand cleaning a
## dirty toilet block; one at the reception checking in a party that waits there. Lines
## "STAFF98 ..." and pictures of the PC.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/staff98_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('Staff98Check')"
const BRT := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const SRULES := preload("res://core/systems/staff_rules.gd")
const B := "_interior_manager._building_interior._crt_ui"


func key_of(t: String) -> String:
	var st = CoreRoot.get_state()
	for k in st.biz.get("sites", {}):
		if str(st.biz["sites"][k].get("kind", "")) == t:
			return str(k)
	return ""


func block() -> Vector2i:
	var st = CoreRoot.get_state()
	for c in st.grid.cells:
		var cell: Dictionary = st.grid.cells[c]
		if str(cell.get("type", "")) == "toilet_block" and cell.get("root_coord", c) == c:
			return c
	return Vector2i(-1, -1)


func setup_camp() -> void:
	var a = CoreRoot.actions
	for k in ["pub", "corn", "staff", "rest"]:
		a.biz_grant_licence(k)
	var day := CoreRoot.get_day()
	var seed := BUSINESS.camp_seed()
	# Working already: Lojza at the pub, Klara at the stand; Marta and Ivan in the staffroom
	# (Ivan at the desk). Taken on today: Pepa for the pub, in tomorrow.
	a.staff_buy_gear("locker")
	a.staff_buy_gear("locker")
	a.biz_hire(key_of("pub"), BRT.person("lojza", "pub", seed), day)
	a.biz_hire(key_of("corn"), BRT.person("klara", "corn", seed), day)
	a.staff_hire(BRT.person("marta", "staff", seed), day)
	var ivan := BRT.person("ivan", "staff", seed)
	a.staff_hire(ivan, day)
	a.staff_set_job("ivan", "desk", true)
	a.biz_hire(key_of("pub"), BRT.person("pepa", "pub", seed), day + 1)
	report("setup")


func report(tag: String) -> void:
	var st = CoreRoot.get_state()
	var pub := key_of("pub")
	var names: Array = BUSINESS.crew_now(pub).map(func(p): return str(p.get("name", "")))
	var acts: Dictionary = (st.biz.get("staff", {}) as Dictionary).get("act", {})
	var doing := {}
	for s in acts:
		doing[s] = "%s/%s" % [str(acts[s].get("do", "")), str(acts[s].get("what", acts[s].get("next", {}).get("what", "")))]
	var b := block()
	var waiting := 0
	var inside := 0
	for g in st.guests:
		if str(g.get("status", "")) == "waiting":
			waiting += 1
		elif str(g.get("status", "")) in ["active", "checked_in"]:
			inside += 1
	var log: Array = (st.biz.get("staff", {}) as Dictionary).get("log", [])
	print("STAFF98 %s day=%d hour=%.2f pub_now=%s staff_acts=%s block_maint=%.2f waiting=%d in=%d last_log=%s" % [tag, CoreRoot.get_day(), float(_main.get("_time_of_day_hours")),
		str(names), str(doing), float(st.grid.cells.get(b, {}).get("maintenance", -1.0)), waiting, inside, str(log.slice(maxi(0, log.size() - 3)).map(func(e): return str(e.get("text", ""))))])


## The party booked as if it had reached the barrier a while ago (the bus ride left out).
func force_waiting() -> void:
	var st = CoreRoot.get_state()
	var now_abs: int = GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute)
	for i in st.guests.size():
		var g: Dictionary = st.guests[i]
		print("STAFF98 guest %s status=%s" % [str(g.get("name", "")), str(g.get("status", ""))])
		if str(g.get("status", "")) == "expected":
			g["status"] = "waiting"
			g["gate_since_abs"] = now_abs - 10
			st.guests[i] = g


func types() -> void:
	var st = CoreRoot.get_state()
	var seen := {}
	for c in st.grid.cells:
		var cell: Dictionary = st.grid.cells[c]
		if cell.get("root_coord", c) == c and str(cell.get("type", "")) != "path":
			seen[str(cell.get("type", ""))] = int(seen.get(str(cell.get("type", "")), 0)) + 1
	print("STAFF98 built ", seen)


func dirty_block() -> void:
	var st = CoreRoot.get_state()
	var b := block()
	for c in st.grid.cells:
		if st.grid.cells[c].get("root_coord", c) == b:
			st.grid.cells[c]["maintenance"] = 0.4


func app_page(p: String) -> void:
	var shops = _main.get("_interior_manager").get("_building_interior").get("_crt_ui").app_of("shops")
	for k in shops.get("_subs"):
		var page = shops.get("_subs")[k]
		for c in page.find_children("*", "Control", true, false):
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("staff_app.gd"):
				c.set("_page", p)
				c.queue_redraw()


func _ready() -> void:
	super._ready()
	_steps = [
		["auto_checkin", false],
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 90000], ["clear", 5, 5, 15, 10], ["build", "pub", 6, 6, 0], ["build", "cabin_1", 6, 11, 0], ["build", "cabin_1", 9, 11, 0],
		["clear", 14, 4, 10, 16], ["build", "corn_stand", 15, 5, 0], ["build", "staffroom", 15, 9, 0], ["build", "toilet_block", 15, 14, 0], ["wait", 2.0],
		["eval", C + ".types()"],
		["eval", C + ".setup_camp()"], ["wait", 1.0],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["eval", B + ".open_app('shops', {'program': 'staff_app'}) != null"], ["wait", 2.0],
		["eval", B + ".install_program('staff_app', false)"], ["wait", 9.0],
		["eval", B + ".app_of('shops')._switch('staff_app')"], ["wait", 1.5], ["crt_screen", "p0_staff"],
		["eval", C + ".app_page('hire')"], ["wait", 1.0], ["crt_screen", "p1_hire"],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", C + ".report('today')"],
		["eval", "debug_jump_to(2, 9.0)"], ["wait", 2.0],
		["eval", C + ".report('tomorrow')"],
		["eval", C + ".dirty_block()"],
		["prep_all"], ["book", "Novak family", "family", 3, 2], ["wait", 1.0], ["eval", C + ".force_waiting()"], ["timescale", 4.0],
	]
	for i in 24:
		_steps.append(["wait", 2.0])
		_steps.append(["eval", C + ".report('t%d')" % i])
	_steps.append(["timescale", 1.0])
	_steps.append(["eval", "get_tree().quit()"])
