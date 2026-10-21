extends "res://tools/coop_check.gd"

## The reception's windows for two (building_interior._update_inview, interior_manager.
## _coop_office_from_camp): the host in the office, the other warden outside at its
## windows. The host sits at the PC, goes into the back room, then draws the office's
## curtain and puts its lights out; the joining side, looking in, prints what it sees,
## tagged ["WINDOW client <tag>", figures seen, curtain open, lights on] for
## tools/window_coop.py, and takes a picture of each.
##   godot --path godot res://tools/window_coop.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "debug_jump_to(2, 20.6)"], ["wait", 1.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0],
			["coop_signal", "host_up"], ["coop_wait_file", "client_out"], ["wait", 1.0],
			["eval", BI + ".enter_crt_view()"], ["wait", 3.0],
			["coop_signal", "host_at_pc"], ["coop_wait_file", "client_saw_pc"],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0],
			["eval", BI + "._extras.go_back_room()"], ["wait", 3.5],
			["coop_signal", "host_in_back"], ["coop_wait_file", "client_saw_back"],
			["eval", BI + "._extras.go_office()"], ["wait", 3.0],
			["eval", BI + "._office_curtain.toggle()"], ["wait", 2.5],
			["coop_signal", "host_curtain"], ["coop_wait_file", "client_saw_curtain"],
			["eval", BI + "._office_curtain.toggle()"], ["wait", 2.0],
			["eval", BI + "._toggle_office_lights()"], ["eval", BI + ".toggle_desk_lamp(false)"], ["wait", 2.0],
			["coop_signal", "host_dark"], ["coop_wait_file", "client_saw_dark"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 4.0],
			["win_front", "office_glass", 2.6], ["wait", 1.0], ["coop_signal", "client_out"],
			["coop_wait_file", "host_at_pc"], ["wait", 2.0], ["win_front", "office_glass", 2.6], ["wait", 1.0],
			["win_see", "pc"], ["shot", "wc_pc"], ["coop_signal", "client_saw_pc"],
			["coop_wait_file", "host_in_back"], ["wait", 2.0], ["win_front", "back_glass", 2.2], ["wait", 1.5],
			["win_see", "back"], ["shot", "wc_back"], ["coop_signal", "client_saw_back"],
			["coop_wait_file", "host_curtain"], ["wait", 2.0], ["win_front", "office_glass", 2.6], ["wait", 1.5],
			["win_see", "curtain"], ["shot", "wc_curtain"], ["coop_signal", "client_saw_curtain"],
			["coop_wait_file", "host_dark"], ["wait", 2.0], ["win_front", "office_glass", 2.6], ["wait", 1.5],
			["win_see", "dark"], ["shot", "wc_dark"], ["coop_signal", "client_saw_dark"],
			["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	match str(step[0]):
		"win_front":
			var bi = _main._interior_manager._building_interior
			bi._sync_reception_glass()
			var g: MeshInstance3D = bi._glass_cache.get(str(step[1]))
			if g == null:
				print("WINDOW no glass")
				return
			var s := (g.mesh as BoxMesh).size
			var axis := Vector3.RIGHT if s.x < s.y and s.x < s.z else Vector3.BACK
			var n := (g.global_basis * axis).normalized()
			# Out of the building, not into it.
			var door: Vector3 = _main.get_reception_door_position()
			var shell := g.get_parent() as Node3D
			if (g.global_position + n - shell.global_position).length() < (g.global_position - n - shell.global_position).length():
				n = -n
			var eye := g.global_position + n * float(step[2])
			var p: Node3D = _main._player
			p.global_position = eye - Vector3(0, 1.6, 0)
			p.look_at(Vector3(g.global_position.x, p.global_position.y, g.global_position.z), Vector3.UP)
			var head := p.get_node_or_null("Head") as Node3D
			if head != null:
				head.rotation.x = 0.0
		"win_see":
			var bi = _main._interior_manager._building_interior
			var figs: Array = []
			for f in (_main._interior_manager._office_figs as Dictionary).values():
				if f != null and is_instance_valid(f) and f.visible:
					figs.append(str(f.get("_pose")) if f.get("_pose") != null else "fig")
			print("WINDOW_TAG [\"WINDOW %s %s\", %d, %s, %s, %s]" % [_role, str(step[1]), figs.size(), str(bi._office_curtain.is_open()).to_lower(), str(bi._office_lights_on).to_lower(), str(bi._inview_live).to_lower()])
		_:
			super._run_step(step)
