extends "res://tools/coop_check.gd"

## The other warden in the office, as you see them (playtest 24. 11.: P12 their picture at the
## counter too high, P7 to the PC through the counter, P8 the PC taken: over their shoulder).
## Both wardens in the office; the joining one stands, sits down at the check-in desk, gets up
## and goes to the PC from it, then from where they stood; the host watches, a picture at each
## (and a run of them as they go to the PC), then clicks the PC they sit at. Tagged
## "OFFICE_FIG [tag, shown, pose, x, y, z]" (the figure in the room's own space).
##   godot --path godot res://tools/office_figs_coop.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"
const DR := BI + "._desk_room"


func _ready() -> void:
	super._ready()
	if _role == "host":
		var steps: Array = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0],
			["eval", "[" + BI + "._initial_cam_pos, " + BI + "._initial_cam_rot]"],
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 1.5],
			["fig_tag", "standing"], ["yaw", 0.0], ["shot", "o1_standing_y0"], ["yaw", -45.0], ["shot", "o1_standing_yr"], ["yaw", 45.0], ["shot", "o1_standing_yl"],
			["coop_signal", "host_saw_standing"], ["coop_wait_file", "client_at_desk"], ["wait", 1.5],
			["fig_tag", "at_desk"], ["yaw", 0.0], ["shot", "o2_desk_y0"], ["yaw", -45.0], ["shot", "o2_desk_yr"], ["yaw", -70.0], ["shot", "o2_desk_yr2"],
			["yaw", 30.0], ["coop_signal", "host_saw_desk"], ["coop_wait_file", "client_to_pc"],
		]
		for i in 14:
			steps.append_array([["wait", 0.15], ["fig_tag", "to_pc_%d" % i], ["shot", "o3_to_pc_%d" % i]])
		steps.append_array([
			["wait", 1.5], ["yaw", 62.0], ["fig_tag", "at_pc"], ["shot", "o4_at_pc"],
			["eval", BI + ".go_to_pc(0)"], ["wait", 1.2], ["eval", "['SHOULDER', " + BI + ".is_over_shoulder()]"], ["shot", "o5_shoulder"],
			["key", "Escape"], ["wait", 1.0], ["eval", "['SHOULDER_AFTER_ESC', " + BI + ".is_over_shoulder()]"], ["shot", "o5b_back"],
			["coop_signal", "host_saw_pc"], ["coop_wait_file", "client_up_again"], ["wait", 1.0], ["yaw", 30.0],
			["coop_signal", "host_watch_again"], ["coop_wait_file", "client_to_pc2"],
		])
		for i in 8:
			steps.append_array([["wait", 0.15], ["fig_tag", "to_pc2_%d" % i], ["shot", "o6_to_pc2_%d" % i]])
		steps.append_array([["wait", 1.0], ["coop_signal", "host_done"], ["coop_wait_file", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"]])
		_steps = steps
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._on_crt_interact()"], ["wait", 4.0],
			["coop_signal", "client_in"], ["coop_wait_file", "host_saw_standing"],
			["eval", BI + ".open_checkin_desk()"], ["wait", 2.4], ["coop_signal", "client_at_desk"],
			["coop_wait_file", "host_saw_desk"],
			# Turned to the PC at the desk, its screen clicked (desk_room: _to_pc, the desk shut).
			["eval", DR + ".set('_to_pc', 0)"], ["eval", DR + ".desk.close_desk()"], ["coop_signal", "client_to_pc"],
			["coop_wait_file", "host_saw_pc"],
			["eval", BI + "._exit_crt_view()"], ["wait", 2.5], ["coop_signal", "client_up_again"],
			["coop_wait_file", "host_watch_again"],
			["eval", BI + ".go_to_pc(0)"], ["coop_signal", "client_to_pc2"],
			["coop_wait_file", "host_done"], ["coop_signal", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	match str(step[0]):
		"yaw":
			var bi = _main._interior_manager._building_interior
			bi._look.set("yaw_deg", float(step[1]))
			bi._look.set("pitch_deg", -6.0)
			await get_tree().create_timer(0.6).timeout
		"fig_tag":
			var im = _main._interior_manager
			var root: Node3D = im._building_interior._room_root
			var out := "none"
			for e in (im.get("_coop_figs") as Dictionary).values():
				var fig = (e as Dictionary).get("fig")
				if fig != null and is_instance_valid(fig):
					var at: Vector3 = root.global_transform.affine_inverse() * (fig as Node3D).global_position
					out = "%s, \"%s\", %.2f, %.2f, %.2f, %s" % [str(fig.visible).to_lower(), str(fig.get("pose")), at.x, at.y, at.z, str(fig.walking_way()).to_lower()]
			print("OFFICE_FIG [\"%s\", %s]" % [str(step[1]), out])
		_:
			super._run_step(step)
