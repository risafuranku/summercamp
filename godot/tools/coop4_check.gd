extends "res://tools/coop_check.gd"

## Co-op for four (scripts/coop/coop.gd): a host and three joining copies of the game on
## this machine (roles host, c1, c2, c3), waiting on each other by files in the out dir as
## coop_check.gd does. On the way:
##   - each joining warden comes with the next figure (their place on the line) and a
##     jacket of their own: everyone sees the other three, four different wardens;
##   - two of them spend in town: the host's till pays both, each counted once;
##   - all four round the host's new fire: each sees the other three sat at it;
##   - all four in the old cabin: each sees the other three standing about in it;
##   - all four down the sewer's pipes: each sees the other three lying in them, and the
##     ones behind the first crawl into boots;
##   - at night the host lies down in the back room, two others where they are: the night
##     does not pass while the fourth is up; it lies down too and all wake in the morning;
##   - the next day all four take the 13:20 to Lesna: three get on and sit, the host sits
##     last but one, and the bus waits for the fourth buying a ticket; then all four ride
##     it and get off in Lesna, and at the bar of U Jezera each sees the other three;
##   - the fourth goes home: the other three play on, their figure gone.
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
			# The fire, built after the joins (the others' camps get it too): all four round it.
			["build", "bonfire", 11, 12, 0], ["wait", 2.0], ["coop_signal", "host_built"],
		] + _together(spot) + [
			["coop_signal", "host_together_done"],
			# The night: the host turns in in the back room first.
			["eval", "debug_jump_to(1, 22.6)"], ["wait", 3.0],
			["coop_open_office"], ["wait", 1.5], ["eval", "_interior_manager._building_interior._extras.go_back_room()"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._extras._try_sleep()"], ["wait", 6.0], ["coop_signal", "host_in_bed"],
			["coop_wait_file", "c1_in_bed"], ["coop_wait_file", "c2_in_bed"], ["wait", 4.0], ["coop_fingerprint", "host_waiting"], ["coop_signal", "host_waiting"],
			["coop_wait", "morning"], ["wait", 1.0], ["coop_fingerprint", "host_morning"],
			["coop_wait_file", "c1_morning"], ["coop_wait_file", "c2_morning"], ["coop_wait_file", "c3_morning"],
		] + _to_lesna() + [
			["coop_signal", "host_morning_seen"], ["coop_wait_file", "c3_gone"], ["wait", 3.0], ["coop_fingerprint", "host_after_c3"],
			["coop_signal", "host_after_c3"], ["coop_wait_file", "c1_after_c3"], ["coop_wait_file", "c2_after_c3"], ["coop_signal", "host_day2_done"],
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
		_steps.append_array([["coop_wait_file", "host_till"], ["coop_wait_file", "host_built"], ["wait", 2.0]])
		_steps.append_array(_together(spot))
		_steps.append_array([["coop_wait_file", "host_in_bed"]])
		if r == "c3":
			# The last one up: the night waits for them.
			_steps.append_array([["coop_wait_file", "host_waiting"], ["eval", "camp_office.lie_down()"], ["coop_signal", "c3_in_bed"]])
		else:
			_steps.append_array([["eval", "camp_office.lie_down()"], ["coop_signal", "%s_in_bed" % r]])
		_steps.append_array([
			["coop_wait", "morning"], ["wait", 1.0], ["coop_fingerprint", "%s_morning" % r], ["coop_signal", "%s_morning" % r]])
		_steps.append_array(_to_lesna())
		_steps.append_array([["coop_wait_file", "host_morning_seen"]])
		if r == "c3":
			# Home first: the others play on without them.
			_steps.append_array([["coop_leave"], ["wait", 1.0], ["coop_signal", "c3_gone"]])
		else:
			_steps.append_array([["coop_wait_file", "host_after_c3"], ["wait", 1.0], ["coop_fingerprint", "%s_after_c3" % r], ["coop_signal", "%s_after_c3" % r],
				["coop_wait_file", "host_day2_done"], ["coop_leave"], ["wait", 2.0]])


## Round the fire, in the old cabin, down the pipes: all four, each waiting for the rest
## (files <role>_<scene>), seen and written down, then out again.
func _together(spot: Array) -> Array:
	var r := _role
	var angle := {"host": 0.0, "c1": 90.0, "c2": 180.0, "c3": 270.0}
	var out: Array = []
	for scene in ["fire", "room", "pipes"]:
		match scene:
			"fire":
				out.append_array([["coop_fire_at", float(angle.get(r, 0.0))], ["wait", 1.0]])
			"room":
				out.append_array([["open_room", ROOM.x, ROOM.y], ["wait", 2.0]])
			"pipes":
				out.append_array([
					["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('sewer'))"], ["wait", 2.0],
					["eval", "_interior_manager._service_interior._try_request_service_repair()"], ["wait", 2.0],
					["eval", "_sewer_pipe_minigame.set('_intro_t', 99.0)"], ["wait", 1.0]])
		out.append(["coop_signal", "%s_%s_in" % [r, scene]])
		for other in ["host", "c1", "c2", "c3"]:
			if other != r:
				out.append(["coop_wait_file", "%s_%s_in" % [other, scene]])
		out.append(["wait", 2.5])
		if scene == "pipes":
			# The host crawls on first; the rest after them, into their boots.
			if r == "host":
				out.append_array([["eval", "_sewer_pipe_minigame._forward()"], ["wait", 7.0], ["coop_signal", "host_crawled"]])
			else:
				out.append_array([["coop_wait_file", "host_crawled"], ["wait", 1.0], ["eval", "_sewer_pipe_minigame._forward()"], ["wait", 1.0]])
		out.append_array([["shot", "q2_%s_%s" % [r, scene]], ["coop_fingerprint", "%s_%s" % [r, scene]], ["coop_signal", "%s_%s_seen" % [r, scene]]])
		for other in ["host", "c1", "c2", "c3"]:
			if other != r:
				out.append(["coop_wait_file", "%s_%s_seen" % [other, scene]])
		match scene:
			"fire":
				out.append(["eval", "_warden_play.leave()"])
			"room":
				out.append(["eval", "_interior_manager._cabin_interior.close_cabin()"])
			"pipes":
				out.append(["eval", "_sewer_pipe_minigame.abort()"])
		out.append_array([["wait", 1.5], ["coop_place", spot[0], spot[1], 1.0], ["wait", 0.5]])
	return out


## The 13:20 to Lesna for all four, and a beer at U Jezera.
func _to_lesna() -> Array:
	var r := _role
	var seat := {"host": 1, "c1": 6, "c2": 9, "c3": 12}
	var out: Array = [["eval", "_interior_manager._building_interior.close_interior()"], ["eval", "_interior_manager._tent_interior.close_tent()"],
		["wait", 1.0], ["coop4_to_stop"], ["wait", 1.0]]
	var board := [["eval", "_interior_manager._town_trip._board('camp')"], ["wait", 1.0]]
	var sit := [["coop_ticket"], ["eval", "_interior_manager._town_trip._ride._try_sit(%d)" % int(seat[r])], ["wait", 1.0]]
	match r:
		"host":
			out.append_array([["eval", "debug_jump_to(2, 13.42)"], ["wait", 3.0], ["coop_signal", "host_bus_here"], ["coop_wait_file", "c3_aboard"]])
			out.append_array(board + sit)
			out.append_array([["wait", 3.0], ["shot", "q3_host_bus_waits"], ["coop_fingerprint", "host_bus_wait"], ["coop_signal", "host_sat"]])
		"c1":
			out.append_array([["coop_wait_file", "host_bus_here"]] + board + sit + [["coop_signal", "c1_sat"]])
		"c2":
			out.append_array([["coop_wait_file", "c1_sat"]] + board + sit + [["coop_signal", "c2_sat"]])
		"c3":
			# Aboard, but buying a ticket last: the bus waits for them.
			out.append_array([["coop_wait_file", "c2_sat"]] + board + [["coop_signal", "c3_aboard"], ["coop_wait_file", "host_sat"], ["wait", 2.0]] + sit + [["coop_signal", "c3_sat"]])
	# Once the last one sits, it goes: riding with all four.
	if r != "c3":
		out.append(["coop_wait_file", "c3_sat"])
	out.append_array([["wait", 4.0], ["coop_fingerprint", "%s_bus_ride" % r], ["shot", "q3_%s_riding" % r],
		["coop_wait", "in_town"], ["wait", 2.0], ["coop_fingerprint", "%s_town" % r], ["coop_signal", "%s_town" % r]])
	for other in ["host", "c1", "c2", "c3"]:
		if other != r:
			out.append(["coop_wait_file", "%s_town" % other])
	out.append_array([["eval", "_interior_manager._town_trip._open_room('pub')"], ["wait", 1.5], ["coop_signal", "%s_in_pub" % r]])
	for other in ["host", "c1", "c2", "c3"]:
		if other != r:
			out.append(["coop_wait_file", "%s_in_pub" % other])
	out.append_array([["wait", 2.0], ["shot", "q4_%s_pub" % r], ["coop_fingerprint", "%s_pub" % r], ["coop_signal", "%s_pub_seen" % r]])
	for other in ["host", "c1", "c2", "c3"]:
		if other != r:
			out.append(["coop_wait_file", "%s_pub_seen" % other])
	return out


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
	if str(step[0]) == "coop4_to_stop":
		# To the camp stop, side by side along the kerb.
		var trip = _main.get("_interior_manager").get("_town_trip")
		var spot: Transform3D = trip._road().wait_spot()
		var nth := ["host", "c1", "c2", "c3"].find(_role)
		trip._put_player(spot.translated(Vector3(1.2 * float(nth), 0.0, 0.0)))
		return
	if str(step[0]) == "coop_fire_at":
		# Round the fire from your own side (degrees round it), and sat at it.
		var wp = _main.get("_warden_play")
		var att: Node3D = wp.find_att("11,12")
		var me: Node3D = _main.get("_player")
		if att != null and me != null:
			var a := deg_to_rad(float(step[1]))
			me.global_position = att.global_position + Vector3(cos(a) * 2.4, 0.4, sin(a) * 2.4)
			# Sat down (E by the woodpile would put a log on instead).
			if not wp.is_active():
				wp._join(att)
		return
	if str(step[0]) == "coop_wait" and str(step[1]) == "all_seen":
		_waiting_for = "all_seen"
		_coop_wait_deadline = Time.get_ticks_msec() + WAIT_MS * 2
		return
	super._run_step(step)
