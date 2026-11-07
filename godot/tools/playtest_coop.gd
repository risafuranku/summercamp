extends "res://tools/coop_check.gd"

## What the playtest of 7. 11. found wrong between two machines, played: the board by the gate
## says the host's name on the other machine and takes a click there (P5), the clock runs on
## its own there, every frame (P34), one toilet dirty is one plate (P16), the radio is the same
## song within a moment (P7), the guest at the counter is seen from outside while the other
## warden checks them in (P1). Lines "PLAYCOOP <what> <json>" for tools/playtest_coop.py.
##   python godot/tools/playtest_coop.py [OUT_DIR]

const BI := "_interior_manager._building_interior"
const NAME := "Kemp U Hrachu"
const C := "get_tree().current_scene.get_node('/root/ShotDriver')"


func say(what: String, data) -> void:
	print("PLAYCOOP %s %s" % [what, JSON.stringify(data)])


## The host: a name, one toilet dirty and the other clean, a guest at the counter.
func host_stage() -> void:
	_main.set_camp_name(NAME)
	var st = CoreRoot.get_state()
	for coord in st.grid.cells.keys():
		var cell: Dictionary = st.grid.cells[coord]
		if str(cell.get("type", "")) == "toilet_block" and cell.get("root_coord", coord) == coord:
			cell["maint_l"] = 0.3
			cell["maint_r"] = 1.0
			cell["maintenance"] = 0.3
	say("host_stage", {"name": _main.camp_name()})


func sign_row() -> void:
	var gate = get_tree().get_first_node_in_group("camp_gate")
	var lab = gate.get("_sign_label") if gate != null else null
	var hits := 0
	for n in get_tree().get_nodes_in_group("camp_gate"):
		if (n as Node).is_queued_for_deletion():
			continue
		var l = n.get("_sign_label")
		if l != null and str(l.text).contains(NAME.to_upper()):
			hits += 1
	say("sign", {"name": _main.camp_name(), "text": str(lab.text) if lab != null else "", "hits": hits})


func plates() -> void:
	var rows: Array = _main._work_rows()
	var wc: Array = []
	for r in rows:
		if str(r.get("kind", "")) == "toilet":
			wc.append(str(r.get("word", "")))
	say("plates", wc)


func clock_run() -> void:
	var seen := {}
	var t0 := Time.get_ticks_msec()
	var from := float(_main.get("_time_of_day_hours"))
	for i in 40:
		await get_tree().process_frame
		seen[snappedf(float(_main.get("_time_of_day_hours")), 0.00001)] = true
	var dt := float(Time.get_ticks_msec() - t0) / 1000.0
	say("clock", {"distinct": seen.size(), "frames": 40, "sec": dt, "hours": float(_main.get("_time_of_day_hours")) - from})


func radio() -> void:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var p = bi.get("_radio_player")
	say("radio", {"on": bi.get("_radio_power_on"), "path": bi.get("_radio_last_played_path"), "pos": p.get_playback_position() if p != null and p.playing else -1.0,
		"at": Time.get_unix_time_from_system()})


func desk() -> void:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var dr = bi.get("_desk_room")
	var q: Array = GuestManager.get_desk_queue()
	var st = CoreRoot.get_state()
	say("desk", {"queue": q.size(), "front": dr.get("_front").visible, "open": dr.is_open(), "visible": bi.visible, "live": bi.get("_inview_live"),
		"guests": st.guests.map(func(g): return [g.get("id"), g.get("status"), g.get("gate_queue_index", -1)]) if st != null else []})


## The corn stand's bulb goes by the one clock (P7: the other machine's hour stood still).
func bulb() -> void:
	var on: Array = []
	for n in get_tree().root.find_children("StandBulb", "OmniLight3D", true, false):
		on.append((n as OmniLight3D).visible)
	say("bulb", {"on": on, "hour": float(_main.call("season_hour"))})


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 0.5], ["eval", BI + ".close_interior()"], ["wait", 1.0],
			["eval", "debug_jump_to(1, 11.0)"], ["wait", 1.0],
			["money", 90000], ["clear", 16, 3, 9, 6], ["build", "toilet_block", 17, 4, 0], ["build", "tent_1", 21, 4, 0], ["build", "corn_stand", 19, 7, 0], ["wait", 1.0], ["prep_all"],
			["auto_checkin", false], ["book", "Pepa", "drunk", 1, 2, 0],
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 1.0],
			["eval", "get_node('/root/ShotDriver').host_stage()"], ["wait", 3.0], ["coop_signal", "host_staged"],
			["coop_wait_file", "client_saw"], ["wait", 0.5],
			["hours", 0.3], ["wait", 22.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('main_building'))"], ["wait", 4.0],
			["eval", BI + "._desk_room._step_up()"], ["wait", 3.0],
			["eval", "get_node('/root/ShotDriver').desk()"], ["coop_signal", "host_at_desk"],
			["eval", "get_node('/root/ShotDriver').radio()"], ["coop_wait_file", "client_saw_desk"],
			["eval", "debug_jump_to(1, 18.0)"], ["wait", 2.5], ["eval", "get_node('/root/ShotDriver').bulb()"], ["coop_signal", "host_evening"],
			["coop_wait_file", "client_evening"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["auto_checkin", false],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 2.0],
			["coop_signal", "client_in"], ["coop_wait_file", "host_staged"], ["wait", 2.5],
			["eval", "get_node('/root/ShotDriver').sign_row()"], ["eval", "get_node('/root/ShotDriver').plates()"],
			["eval", "get_node('/root/ShotDriver').clock_run()"], ["wait", 1.5],
			["coop_signal", "client_saw"],
			["coop_wait_file", "host_at_desk"], ["wait", 1.5],
			["win_front", "office_glass", 2.6], ["wait", 1.5],
			["eval", "get_node('/root/ShotDriver').desk()"], ["eval", "get_node('/root/ShotDriver').radio()"], ["shot", "c_desk"],
			["coop_signal", "client_saw_desk"],
			["coop_wait_file", "host_evening"], ["wait", 2.5], ["eval", "get_node('/root/ShotDriver').bulb()"], ["coop_signal", "client_evening"],
			["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	match str(step[0]):
		"win_front":
			var bi = _main._interior_manager._building_interior
			bi._sync_reception_glass()
			var g: MeshInstance3D = bi._glass_cache.get(str(step[1]))
			var s := (g.mesh as BoxMesh).size
			var axis := Vector3.RIGHT if s.x < s.y and s.x < s.z else Vector3.BACK
			var n := (g.global_basis * axis).normalized()
			var shell := g.get_parent() as Node3D
			if (g.global_position + n - shell.global_position).length() < (g.global_position - n - shell.global_position).length():
				n = -n
			var eye := g.global_position + n * float(step[2])
			var p: Node3D = _main._player
			p.global_position = eye - Vector3(0, 1.6, 0)
			p.look_at(Vector3(g.global_position.x, p.global_position.y, g.global_position.z), Vector3.UP)
		_:
			super._run_step(step)
