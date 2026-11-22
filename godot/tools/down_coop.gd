extends "res://tools/coop_check.gd"

## A warden knocked down at night, seen by the other (scripts/coop/remote_player.gd: the
## torch they had on lies lit in the grass beside them, the way to find them in the dark).
## The other warden lies down with the torch on; the host looks from 4, 10 and 18 m; lines
## "DOWN_TAG" for tools/down_coop.py, shots down_<m>.png.
##   python godot/tools/down_coop.py [OUT_DIR]

const DOWN_PORT := 24993


func _ready() -> void:
	super._ready()
	var open := [["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0]]
	if _role == "host":
		_steps = [["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0]]
		_steps.append_array(open)
		_steps.append_array([["coop_signal", "host_up"], ["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"],
			["eval", "time_system.set_time_hours(22.5)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 3.0],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_night"], ["coop_wait_file", "client_lit"], ["wait", 2.0],
			["back_off", 8.0, 1.0], ["wait", 1.0], ["shot", "stand_8_dark"], ["torch", true], ["coop_signal", "host_saw_stand"], ["coop_wait_file", "client_down"], ["wait", 2.0]])
		for d in [4.0, 10.0, 18.0]:
			_steps.append_array([["back_off", d, 1.0], ["wait", 1.0], ["down_see", "%d" % int(d)], ["shot", "down_%d" % int(d)]])
		# From where their torch points (its bulb toward you) and from behind it.
		_steps.append_array([["back_off", 12.0, 0.0], ["wait", 1.0], ["shot", "down_12_front"], ["back_off", 12.0, 2.0], ["wait", 1.0], ["shot", "down_12_behind"],
			# Their torch alone (yours off): what you go by.
			["torch", false], ["back_off", 12.0, 1.0], ["wait", 1.0], ["shot", "down_12_dark"], ["back_off", 25.0, 0.0], ["wait", 1.0], ["shot", "down_25_front_dark"], ["back_off", 12.0, 2.0], ["wait", 1.0], ["shot", "down_12_behind_dark"]])
		_steps.append_array([["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"]])
	else:
		_steps = [["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]], ["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0]]
		_steps.append_array(open)
		_steps.append_array([["coop_signal", "client_ready"], ["coop_wait_file", "host_night"], ["wait", 1.0],
			["coop_place", 14, 14, -1.0], ["torch", true], ["wait", 1.0], ["eval", "_player.is_flashlight_active()"], ["eval", "_player.get_flashlight_aim()"],
			["coop_signal", "client_lit"], ["coop_wait_file", "host_saw_stand"],
			["eval", "_coop_camp.come_to()"], ["wait", 1.5], ["eval", "_player.is_flashlight_active()"], ["eval", "_player.get_flashlight_aim()"], ["eval", "_player.torch_switch"], ["eval", "_player.flashlight_battery"],
			["coop_signal", "client_down"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"]])


func _run_step(step: Array) -> void:
	match str(step[0]):
		"coop_port":
			Coop.port = DOWN_PORT
		"coop_join":
			_main.call("_on_menu_coop_join", "%s:%d" % [str(step[1]), DOWN_PORT])
		"back_off":
			# Stand `d` m from the other warden, facing them: from the side (1), in front of
			# where they lie facing (0), behind them (2).
			var other: Node3D = Coop.remote_figure()
			var me: Node3D = _main.get("_player")
			if other == null or me == null:
				return
			var ids: Array = Coop.others()
			var yaw := float(Coop.state_of(int(ids[0])).get("y", 0.0)) if not ids.is_empty() else 0.0
			var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var from: Vector3 = [fwd, Vector3(fwd.z, 0.0, -fwd.x), -fwd][int(step[2])]
			var at: Vector3 = other.global_position + from.normalized() * float(step[1])
			me.global_position = Vector3(at.x, me.global_position.y + 0.3, at.z)
			var to := other.global_position - me.global_position
			me.rotation.y = atan2(-to.x, -to.z)
			me.set("_pitch", -0.12)
			me.set("_pitch_target", -0.12)
		"down_see":
			var ids: Array = Coop.others()
			var st: Dictionary = Coop.state_of(int(ids[0])) if not ids.is_empty() else {}
			var fig = Coop.remote_figure()
			var beam = fig.get("_beam") if fig != null else null
			print("DOWN_TAG %s dn=%s t=%s beam=%s" % [str(step[1]), str(st.get("dn", false)).to_lower(), str(st.get("t", false)).to_lower(), str(beam != null and (beam as Node3D).visible).to_lower()])
			if beam != null:
				print("DOWN_BEAM %s at %s fwd %s in_tree %s vis_tree %s fig %s" % [str(step[1]), str((beam as Node3D).global_position), str(-(beam as Node3D).global_basis.z), str((beam as Node3D).is_inside_tree()), str((beam as Node3D).is_visible_in_tree()), str(fig.global_position)])
		_:
			super._run_step(step)
