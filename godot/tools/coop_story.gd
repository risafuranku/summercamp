extends "res://tools/coop_check.gd"

## A story camp for two (the Q&A of 15. 11.: "the story in co-op too"; run with --demo for
## the demo's end): the host makes a story camp for co-op, the other warden joins. Vera's
## checklist is the host's and shows on both; the joining warden reads her mail and patches
## the old cabin, and the checklist moves on both machines. Then the host's clock jumps to
## the morning after day 3: the clock stops on both, the grandson's mail comes to both, the
## joining warden reads it and "Vera's" answer, and at the PC gets the trial's nag. Each
## prints STORY_TAG {json} for tools/coop_story.py.
##   godot --path godot res://tools/coop_story.tscn -- --role=host --out=DIR --demo

const EM := "get_node('/root/EmailManager')"


func _see(tag: String) -> Array:
	return ["story_see", tag]


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0],
			["call", "_on_menu_new_camp", ["Story", 4242, true, false, {}]], ["wait_gameplay"], ["wait", 1.5],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], _see("start"),
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 2.0], _see("joined"), ["coop_signal", "host_joined"],
			["coop_wait_file", "client_read"], ["wait", 1.5], _see("read"), ["coop_signal", "host_read"],
			["coop_wait_file", "client_fixed"], ["wait", 1.5], _see("fixed"),
			["eval", "debug_jump_to(4, 7.15)"], ["wait", 4.0], _see("day4"), ["coop_signal", "host_day4"],
			["coop_wait_file", "client_nag"], ["wait", 1.0], _see("end"),
			["coop_signal", "host_done"], ["coop_wait_file", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], _see("joined"),
			["coop_signal", "client_in"], ["coop_wait_file", "host_joined"],
			["eval", "%s.mark_read(%s.find_mail('task_id', 'read_vera'))" % [EM, EM]], ["wait", 3.0], _see("read"), ["coop_signal", "client_read"],
			["coop_wait_file", "host_read"], ["story_patch_cabin"], ["wait", 3.0], _see("fixed"), ["coop_signal", "client_fixed"],
			["coop_wait_file", "host_day4"], ["wait", 2.0], _see("day4"),
			["eval", "%s.mark_read(%s.find_mail('demo_end', 'sister'))" % [EM, EM]], ["wait", 9.0], _see("answer"),
			["eval", "_interior_manager.open_startup_crt_view()"], ["wait", 4.0],
			["eval", "%s.mark_read(%s.find_mail('demo_end', 'answer'))" % [EM, EM]], ["wait", 5.0], _see("nag"), ["shot", "c_nag"],
			["coop_signal", "client_nag"], ["coop_wait_file", "host_done"], ["wait", 1.0],
			["coop_signal", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	match str(step[0]):
		"story_see":
			_story_see(str(step[1]))
		"story_patch_cabin":
			# The old cabin patched up from this machine, as the R hold does it
			# (maintenance_controller: the host services it).
			var key := str(_main._ruin.key)
			if key != "":
				var parts := key.split(":")
				Coop.send_request("service", [Vector2i(int(parts[0]), int(parts[1])), 0])
		_:
			super._run_step(step)


func _story_see(tag: String) -> void:
	var em = get_node("/root/EmailManager")
	var qm = _main.get("_quest_manager")
	var hud = _main.get("_hud_manager")
	var demo_mails: Array = []
	for m in em.inbox:
		if str(m.get("demo_end", "")) != "":
			demo_mails.append("%s:%s" % [str(m["demo_end"]), "read" if bool(m.get("_read", false)) else "new"])
	var d := {
		"role": _role, "tag": tag, "day": int(_main._day_index), "hour": snappedf(float(_main._time_of_day_hours), 0.001),
		"sandbox": bool(_main._sandbox), "step": str(qm.current_step_id()) if qm != null else "",
		"following": bool(qm.get("_following")) if qm != null else false,
		"objective": str((hud.get("_objective") as Dictionary).get("text", "")) if hud != null else "",
		"vera": not em.find_mail("task_id", "read_vera").is_empty(),
		"vera_read": bool(em.find_mail("task_id", "read_vera").get("_read", false)),
		"ruin_broken": str(_main._ruin.key) != "" and CoreRoot.get_state().failures.has(str(_main._ruin.key)),
		"pace": float(_main.clock_pace()), "over": bool(_main._demo_end.over()),
		"demo": demo_mails, "pc_open": bool(_main._is_crt_desktop_active()),
		"nag": _main._demo_end.get("_nag") != null,
	}
	print("STORY_TAG " + JSON.stringify(d))
