extends "res://tools/coop_check.gd"

## To bed for two (scripts/reception/camp_office.gd, sleep_sequence.gd, lodge_bed.gd): a host
## and a joining copy lie down in every order and every kind of bed, and the night has to
## pass for both on the first try, each of them with their eyes shut through it and both up
## in the morning (the user 9. 11.: "sleeping in co-op still does not work reliably at
## the first go"). Each round writes SLEEP_TAG lines for tools/sleep_coop.py.
##   round 1  tents: the host lies down, the other a few seconds after;
##   round 2  tents: the other first, the host after;
##   round 3  the room behind the office (the host) and a tent (the other last);
##   round 4  something out there tonight, then gone: nobody's eyes shut while it is.
##
##   python godot/tools/sleep_coop.py [OUT_DIR]

const SLEEP_PORT := 24997
const BI := "_interior_manager._building_interior"
const LB := "_interior_manager.lodge_bed"
const UP := "not camp_office.in_bed() and not _interior_manager.lodge_bed._sleep.is_running() and not _interior_manager._building_interior._extras.sleep.is_running()"
const TENT := "_interior_manager._tent_interior.close_tent()"
var _went_dark := false


func _process(delta: float) -> void:
	super._process(delta)
	var off = _main.get("camp_office") if _main != null else null
	if off != null and off.has_method("in_bed") and off.in_bed():
		var seq = _seq()
		if seq != null and seq.eyes_shut():
			_went_dark = true


func _seq():
	var lb = _main.get("_interior_manager").get("lodge_bed")
	if lb != null and lb.get("_sleep") != null and lb.get("_sleep").is_running():
		return lb.get("_sleep")
	return _main.get("_interior_manager").get("_building_interior").get("_extras").get("sleep")


## One round: `first` lies down, the other three seconds after.
func _round(n: int, first_is_host: bool, office_bed: bool) -> Array:
	var r := "r%d_" % n
	var mine_first: bool = first_is_host == (_role == "host")
	var go_to_bed: Array
	var mine: String = "host" if _role == "host" else "client"
	var other: String = "client" if _role == "host" else "host"
	if office_bed and _role == "host":
		go_to_bed = [["coop_open_office"], ["wait", 1.5], ["eval", BI + "._extras.go_back_room()"], ["wait", 3.0], ["coop_signal", r + mine + "_there"], ["coop_wait_file", r + other + "_there"]]
	else:
		var at := [13, 16] if _role == "host" else [15, 16]
		go_to_bed = [["open_room", at[0], at[1]], ["wait", 2.0], ["coop_signal", r + mine + "_there"], ["coop_wait_file", r + other + "_there"]]
	var lie: Array = [["fn_dark", false], ["eval", (BI + "._extras._try_sleep()") if office_bed and _role == "host" else (LB + "._try_sleep()")]]
	var steps: Array = []
	if _role == "host":
		steps.append(["eval", "debug_jump_to(%d, 21.0)" % n])
		steps.append(["wait", 1.0])
		steps.append(["coop_signal", r + "night"])
	else:
		steps.append(["coop_wait_file", r + "night"])
		steps.append(["wait", 1.0])
	steps.append_array(go_to_bed)
	if mine_first:
		steps.append_array(lie)
		steps.append(["wait", 3.0])
		steps.append(["coop_signal", r + "first_lay"])
	else:
		steps.append(["coop_wait_file", r + "first_lay"])
		steps.append_array(lie)
	steps.append(["until", UP, 45.0])
	steps.append(["sleep_see", r + "up"])
	steps.append(["coop_signal", r + mine + "_up"])
	steps.append(["coop_wait_file", r + other + "_up"])
	if office_bed and _role == "host":
		steps.append(["eval", BI + ".close_interior()"])
	else:
		steps.append(["eval", TENT])
	steps.append(["wait", 1.5])
	return steps


## Something out there (the host's): nobody's eyes shut; gone, the night passes.
func _round_kept(n: int) -> Array:
	var r := "r%d_" % n
	var mine: String = "host" if _role == "host" else "client"
	var other: String = "client" if _role == "host" else "host"
	var at := [13, 16] if _role == "host" else [15, 16]
	var steps: Array = []
	if _role == "host":
		steps.append_array([["eval", "debug_jump_to(%d, 21.0)" % n], ["wait", 1.0], ["call", "debug_spawn_enemy", ["silent_man", 3]], ["wait", 1.0], ["coop_signal", r + "night"]])
	else:
		steps.append_array([["coop_wait_file", r + "night"], ["wait", 1.0]])
	steps.append_array([["open_room", at[0], at[1]], ["wait", 2.0], ["coop_signal", r + mine + "_there"], ["coop_wait_file", r + other + "_there"]])
	steps.append_array([["fn_dark", false], ["eval", LB + "._try_sleep()"], ["wait", 13.0], ["sleep_see", r + "awake"]])
	if _role == "host":
		steps.append_array([["call", "_stop_active_enemy_brain", []], ["wait", 0.5], ["coop_signal", r + "gone"]])
	else:
		steps.append(["coop_wait_file", r + "gone"])
	steps.append_array([["until", UP, 45.0], ["sleep_see", r + "up"], ["coop_signal", r + mine + "_up"], ["coop_wait_file", r + other + "_up"], ["eval", TENT], ["wait", 1.5]])
	return steps


func _ready() -> void:
	super._ready()
	var open := [["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0]]
	if _role == "host":
		_steps = [["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0]]
		_steps.append_array(open)
		_steps.append_array([["money", 9000], ["clear", 12, 15, 6, 4], ["build", "tent_1", 13, 16, 0], ["build", "tent_1", 15, 16, 0], ["wait", 2.0],
			["coop_signal", "host_up"], ["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0]])
	else:
		_steps = [["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]], ["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0]]
		_steps.append_array(open)
		_steps.append_array([["coop_signal", "client_ready"], ["wait", 1.0]])
	_steps.append_array(_round(1, true, false))
	_steps.append_array(_round(2, false, false))
	_steps.append_array(_round(3, true, true))
	_steps.append_array(_round_kept(4))
	if _role == "host":
		_steps.append_array([["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"]])
	else:
		_steps.append_array([["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"]])


func _run_step(step: Array) -> void:
	match str(step[0]):
		"coop_port":
			Coop.port = SLEEP_PORT
		"coop_join":
			_main.call("_on_menu_coop_join", "%s:%d" % [str(step[1]), SLEEP_PORT])
		"fn_dark":
			_went_dark = bool(step[1])
		"sleep_see":
			var off = _main.get("camp_office")
			var seq = _seq()
			print("SLEEP_TAG [\"SLEEP %s %s\", %.2f, %s, %s, %s, %d]" % [_role, str(step[1]), float(_main.get("_time_of_day_hours")), str(bool(off.in_bed())).to_lower(), str(seq != null and seq.is_running()).to_lower(), str(_went_dark).to_lower(), int(_main.get("_day_index"))])
		_:
			super._run_step(step)
