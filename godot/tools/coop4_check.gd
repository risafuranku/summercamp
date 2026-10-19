extends "res://tools/coop_check.gd"

## Co-op for four (scripts/coop/coop.gd): a host and three joining copies of the game on
## this machine (roles host, c1, c2, c3), waiting on each other by files in the out dir as
## coop_check.gd does. On the way:
##   - each joining warden comes with the next figure (their place on the line) and a
##     jacket of their own: everyone sees the other three, four different wardens;
##   - two of them spend in town: the host's till pays both, each counted once;
##   - at night the host lies down in the back room, two others where they are: the night
##     does not pass while the fourth is up; it lies down too and all wake in the morning.
## tools/coop4_check.py compares what each wrote.
##
##   godot --path godot res://tools/coop4_check.tscn -- --role=host|c1|c2|c3 --out=DIR

const JACKETS := {"c1": 3, "c2": 5, "c3": 6}
const SPOTS := {"host": [12, 14], "c1": [13, 14], "c2": [12, 15], "c3": [13, 15]}
const SPEND := {"c1": 30, "c2": 50}


func _ready() -> void:
	super._ready()
	var spot: Array = SPOTS.get(_role, [12, 14])
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 9000], ["clear", 11, 12, 5, 5], ["wait", 1.0],
			["coop_place", spot[0], spot[1], 1.0], ["coop_signal", "host_up"],
			["coop_wait", "all_seen"], ["wait", 2.0], ["shot", "q1_host_sees_three"], ["coop_fingerprint", "host_seen"], ["coop_signal", "host_seen"],
			["coop_wait_file", "c1_spent"], ["coop_wait_file", "c2_spent"], ["wait", 3.0], ["coop_fingerprint", "host_till"], ["coop_signal", "host_till"],
			# The night: the host turns in in the back room first.
			["eval", "debug_jump_to(1, 22.6)"], ["wait", 3.0],
			["coop_open_office"], ["wait", 1.5], ["eval", "_interior_manager._building_interior._extras.go_back_room()"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._extras._try_sleep()"], ["wait", 6.0], ["coop_signal", "host_in_bed"],
			["coop_wait_file", "c1_in_bed"], ["coop_wait_file", "c2_in_bed"], ["wait", 4.0], ["coop_fingerprint", "host_waiting"], ["coop_signal", "host_waiting"],
			["coop_wait", "morning"], ["wait", 1.0], ["coop_fingerprint", "host_morning"],
			["coop_wait_file", "c1_morning"], ["coop_wait_file", "c2_morning"], ["coop_wait_file", "c3_morning"], ["coop_signal", "host_day2_done"],
			["coop_wait", "partner_gone"], ["wait", 1.0],
		]
	else:
		var r := _role
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look_slot", int(JACKETS.get(r, 0))],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["coop_place", spot[0], spot[1], 1.0],
			["coop_wait", "all_seen"], ["wait", 2.0], ["shot", "q1_%s_sees_three" % r], ["coop_fingerprint", "%s_seen" % r], ["coop_signal", "%s_seen" % r],
			["coop_wait_file", "host_seen"],
		]
		if SPEND.has(r):
			_steps.append_array([["coop_spend", int(SPEND[r])], ["wait", 2.0], ["coop_signal", "%s_spent" % r]])
		_steps.append_array([["coop_wait_file", "host_till"], ["coop_wait_file", "host_in_bed"]])
		if r == "c3":
			# The last one up: the night waits for them.
			_steps.append_array([["coop_wait_file", "host_waiting"], ["eval", "camp_office.lie_down()"], ["coop_signal", "c3_in_bed"]])
		else:
			_steps.append_array([["eval", "camp_office.lie_down()"], ["coop_signal", "%s_in_bed" % r]])
		_steps.append_array([
			["coop_wait", "morning"], ["wait", 1.0], ["coop_fingerprint", "%s_morning" % r], ["coop_signal", "%s_morning" % r],
			["coop_wait_file", "host_day2_done"], ["coop_leave"], ["wait", 2.0],
		])


func _condition_met(what: String) -> bool:
	if what == "all_seen":
		if Time.get_ticks_msec() > _coop_wait_deadline:
			print("COOP CHECK %s: gave up waiting for all_seen (%d of 3)" % [_role, Coop.figures().size()])
			get_tree().quit(1)
			return false
		if Coop.others().size() < 3:
			return false
		for f in Coop.figures():
			if not (f as Node3D).visible:
				return false
		return Coop.figures().size() == 3
	return super._condition_met(what)


## Its own port: coop_check.gd may be running beside it.
const PORT4 := 24994


func _run_step(step: Array) -> void:
	if str(step[0]) == "coop_port":
		Coop.port = PORT4
		return
	if str(step[0]) == "coop_join":
		_main.call("_on_menu_coop_join", "%s:%d" % [str(step[1]), PORT4])
		return
	if str(step[0]) == "coop_look_slot":
		# The figure of their place on the line (they all share this machine's warden), a
		# jacket of their own.
		Coop.look_model = -1
		Coop.look_color = int(step[1])
		Coop.set("_look_override", true)
		return
	if str(step[0]) == "coop_wait" and str(step[1]) == "all_seen":
		_waiting_for = "all_seen"
		_coop_wait_deadline = Time.get_ticks_msec() + WAIT_MS * 2
		return
	super._run_step(step)
