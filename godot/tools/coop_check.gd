extends "res://tools/shot_driver.gd"

## Co-op harness (scripts/coop/coop.gd): two copies of the game on this machine, one
## hosting a sandbox camp, one joining it on 127.0.0.1. They wait for each other by what
## happens (files in the out dir: host_up, client_ready, ...), not by the clock: a camp
## takes the joining copy tens of seconds to build here. On the way:
##   - the joining warden's own look (warden 2, jacket 4) is what the host sees;
##   - each sees the other in a clearing by day, and by their torch at night;
##   - a tent the host builds after the join stands in the other camp too;
##   - both go into the old cabin: each sees the other in it; the joining warden's job
##     (held, a figure at it in the host's room) is done in the host's camp, the host's
##     (the other sees them at it) comes back to the other room;
##   - both go into the new tent: each sees the other lying on their belly in it;
##   - the joining warden rows out: the boat goes on the host's lake with them in it;
##   - the host sits at the PC: the other, in the office, sees its screen over their shoulder;
##   - at night both go to the room behind the office: the host lies down first and the
##     night does not pass; the other lies down too and both wake in the morning.
## Each writes what its camp looks like (seed, buildings, trees, terrain, clock, rooms)
## for tools/coop_check.py to compare.
##
##   godot --path godot res://tools/coop_check.tscn -- --role=host --out=DIR
##   godot --path godot res://tools/coop_check.tscn -- --role=client --out=DIR

const PORT := 24990
const WAIT_MS := 150000
const ROOM := Vector2i(10, 2)
const CLIENT_LOOK := [2, 4]
var _role := "host"
var _coop_wait_deadline := 0
var _wait_file := ""
var _task_id := ""
var _row_left := 0.0


func _ready() -> void:
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.get_slice("=", 1)
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			# A clearing in the middle of the camp, cut before the other copy joins (so
			# its camp has it too), where the two can see each other.
			["money", 9000], ["clear", 11, 12, 5, 5], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			["coop_face_partner"], ["wait", 1.0], ["shot", "h1_sees_other"],
			["coop_fingerprint", "host"],
			# Built after the join: the other camp gets it too.
			["build", "tent_1", 13, 16, 0], ["wait", 2.0], ["coop_fingerprint", "host_built"], ["coop_signal", "host_built"],
			# Into the old cabin together.
			["open_room", ROOM.x, ROOM.y], ["wait", 1.5], ["coop_signal", "host_in_room"],
			["coop_wait_file", "client_in_room"], ["wait", 2.0], ["shot", "h2_room_sees_other"],
			["coop_wait_file", "client_working"], ["wait", 0.8], ["shot", "h3_other_at_work"], ["coop_fingerprint", "host_sees_work"],
			["coop_wait_file", "client_task_done"], ["wait", 2.0],
			["coop_pick_task", ""], ["wait", 0.6], ["lmb", true], ["wait", 0.3], ["coop_note_job"], ["coop_signal", "host_working"], ["wait", 6.3], ["lmb", false], ["wait", 1.0],
			["coop_fingerprint", "host_room"], ["coop_signal", "host_task_done"],
			["eval", "_interior_manager._cabin_interior.close_cabin()"], ["wait", 1.0],
			# Into the new tent together.
			["open_room", 13, 16], ["wait", 1.5], ["coop_signal", "host_in_tent"],
			["coop_wait_file", "client_in_tent"], ["wait", 2.0], ["shot", "h3t_tent_other"], ["coop_fingerprint", "host_tent"], ["coop_signal", "host_tent_seen"],
			["coop_wait_file", "client_tent_seen"], ["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 1.0],
			# The joining warden rows out; the host watches from the jetty.
			["coop_at_boat"], ["coop_wait_file", "client_rowing"], ["wait", 0.4], ["shot", "h4_other_rowing"], ["coop_fingerprint", "host_rowing"],
			["wait", 3.0], ["shot", "h4b_other_rows_away"],
			["coop_wait_file", "client_rowed"],
			# At the PC, the other warden looking over the shoulder.
			["coop_open_office"], ["wait", 1.5], ["eval", "_interior_manager._building_interior.enter_crt_view()"], ["wait", 2.0],
			["coop_signal", "host_at_pc"], ["coop_wait_file", "client_saw_pc"], ["shot", "h8_at_pc"],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["wait", 1.0],
			["eval", "time_system.set_time_hours(21.6)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 4.0],
			["coop_face_partner"], ["wait", 1.5], ["shot", "h5_night_other_torch"],
			["coop_fingerprint", "host_night"],
			# To bed: alone, the night does not pass; with the other one in bed too, it does.
			["coop_open_office"], ["wait", 1.5], ["eval", "_interior_manager._building_interior._extras.go_back_room()"], ["wait", 3.0],
			["coop_signal", "host_in_back"], ["coop_wait_file", "client_in_back"], ["wait", 1.5], ["shot", "h7_back_room_other"],
			["eval", "_interior_manager._building_interior._extras._try_sleep()"], ["wait", 8.0], ["coop_fingerprint", "host_waiting"],
			["coop_signal", "host_in_bed"], ["coop_wait", "morning"], ["wait", 1.0], ["coop_fingerprint", "host_morning"],
			["coop_wait", "partner_gone"], ["wait", 1.5], ["shot", "h6_other_went_home"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["eval", "_main_menu.show_page('coop')"], ["wait", 1.0], ["shot", "c0_coop_page"],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["coop_fingerprint", "client"],
			["coop_place", 14, 14, -1.0], ["wait", 1.5],
			["coop_face_partner"], ["wait", 1.0], ["shot", "c1_sees_host"],
			["coop_signal", "client_ready"],
			["coop_wait_file", "host_built"], ["wait", 2.0], ["coop_fingerprint", "client_built"],
			["coop_wait_file", "host_in_room"], ["open_room", ROOM.x, ROOM.y], ["wait", 1.5], ["coop_signal", "client_in_room"],
			["wait", 2.0], ["shot", "c2_room_sees_host"],
			["coop_pick_task", ""], ["wait", 0.6], ["lmb", true], ["wait", 0.3], ["coop_note_job"], ["coop_signal", "client_working"], ["wait", 6.3], ["lmb", false],
			["wait", 1.0], ["coop_signal", "client_task_done"],
			["coop_wait_file", "host_working"], ["wait", 0.5], ["coop_aim_partner_job"], ["wait", 0.6], ["shot", "c3_host_at_work"],
			["coop_wait_file", "host_task_done"], ["wait", 2.0], ["shot", "c4_room_after_host"], ["coop_fingerprint", "client_room"],
			["eval", "_interior_manager._cabin_interior.close_cabin()"], ["wait", 1.0],
			["coop_wait_file", "host_in_tent"], ["open_room", 13, 16], ["wait", 1.5], ["coop_signal", "client_in_tent"],
			["wait", 2.0], ["shot", "c4t_tent_host"], ["coop_fingerprint", "client_tent"], ["coop_signal", "client_tent_seen"],
			["coop_wait_file", "host_tent_seen"], ["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 1.0],
			["eval", "_lake_trip._start_rowing('far')"], ["coop_row", 12.0], ["wait", 3.0], ["coop_signal", "client_rowing"], ["wait", 12.0],
			["eval", "_lake_trip.return_home()"], ["wait", 1.5], ["coop_signal", "client_rowed"],
			["coop_wait_file", "host_at_pc"], ["coop_open_office"], ["wait", 3.0], ["shot", "c7_over_the_shoulder"], ["coop_fingerprint", "client_shoulder"],
			["coop_signal", "client_saw_pc"], ["wait", 1.0], ["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 14, 14, -1.0], ["wait", 1.0],
			["coop_wait", "night"], ["wait", 3.0],
			["coop_face_partner"], ["wait", 1.5], ["shot", "c5_night_host_torch"],
			["coop_fingerprint", "client_night"],
			["coop_wait_file", "host_in_back"], ["coop_open_office"], ["wait", 1.5], ["eval", "_interior_manager._building_interior._extras.go_back_room()"], ["wait", 3.0],
			["coop_signal", "client_in_back"], ["wait", 1.5], ["shot", "c6_back_room_host"],
			["coop_wait_file", "host_in_bed"], ["eval", "_interior_manager._building_interior._extras._try_sleep()"],
			["coop_wait", "morning"], ["wait", 1.0], ["coop_fingerprint", "client_morning"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


func _condition_met(what: String) -> bool:
	if what in ["partner_seen", "partner_gone", "night", "morning", "host_done", "file"] and Time.get_ticks_msec() > _coop_wait_deadline:
		print("COOP CHECK %s: gave up waiting for %s %s" % [_role, what, _wait_file])
		get_tree().quit(1)
		return false
	match what:
		"partner_seen":
			var other: Node3D = Coop.remote_figure()
			return other != null and other.visible
		"partner_gone":
			return not Coop.has_partner()
		"night":
			var h := float(_main.get("_time_of_day_hours"))
			return h >= 21.0 or h < 5.0
		"morning":
			# Up again after the night went by.
			var h2 := float(_main.get("_time_of_day_hours"))
			var office = _main.get("camp_office")
			return h2 >= 6.4 and h2 < 12.0 and office != null and not office.in_bed()
		"host_done":
			# The host has its morning: the joining copy may hang up.
			return FileAccess.file_exists(_out_dir.path_join("host_morning.json"))
		"file":
			return FileAccess.file_exists(_out_dir.path_join(_wait_file))
	return super._condition_met(what)


func _process(delta: float) -> void:
	super._process(delta)
	if _row_left > 0.0:
		_row_left -= delta
		var trip = _main.get("_lake_trip") if _main != null else null
		if trip != null:
			trip.set("_speed", 2.4)


func _run_step(step: Array) -> void:
	match str(step[0]):
		"coop_port":
			Coop.port = PORT
		"coop_look":
			Coop.set_my_look(int(step[1]), int(step[2]))
		"coop_join":
			_main.call("_on_menu_coop_join", "%s:%d" % [str(step[1]), PORT])
		"coop_wait":
			_waiting_for = str(step[1])
			_coop_wait_deadline = Time.get_ticks_msec() + WAIT_MS
		"coop_wait_file":
			_wait_file = str(step[1])
			_waiting_for = "file"
			_coop_wait_deadline = Time.get_ticks_msec() + WAIT_MS
		"coop_signal":
			FileAccess.open(_out_dir.path_join(str(step[1])), FileAccess.WRITE).store_string(_role)
		"coop_leave":
			Coop.leave()
		"coop_place":
			# Stand on a tile (its centre), facing along x (+1 east, -1 west).
			var me3: Node3D = _main.get("_player")
			var gm = _main.get("grid_manager")
			if me3 != null and gm != null:
				me3.global_position = gm.grid_to_world(Vector2i(int(step[1]), int(step[2]))) + Vector3(0.0, 0.6, 0.0)
				me3.rotation.y = atan2(-float(step[3]), 0.0)
		"coop_face_partner":
			# Turn to the other warden (yaw only), standing back a little if too close.
			var other: Node3D = Coop.remote_figure()
			var me: Node3D = _main.get("_player")
			if other == null or me == null:
				print("COOP CHECK: no other warden to face (%s)" % _role)
				return
			var to := other.global_position - me.global_position
			to.y = 0.0
			if to.length() < 3.5:
				me.global_position -= to.normalized() * (3.5 - to.length())
				to = other.global_position - me.global_position
				to.y = 0.0
			me.rotation.y = atan2(-to.x, -to.z)
			print("COOP CHECK %s faces the other warden at %s (%.1f m)" % [_role, other.global_position, to.length()])
		"coop_pick_task":
			# A job in the open cabin: `step[1]` if given, else the longest mess job not
			# done yet (here or by the other warden); made slow (6 s) so the other copy
			# can see it being done, and looked at.
			var cab = _main.get("_interior_manager").get("_cabin_interior")
			var tasks = cab.get("_prep").tasks
			var pick := str(step[1])
			var acc_done: Array = CoreRoot.get_state().accommodation_states.get("%d:%d" % [ROOM.x, ROOM.y], {}).get("prep_done", [])
			if pick == "" or not tasks._targets.has(pick):
				var best := -1.0
				for id in tasks._targets.keys():
					var t: Dictionary = tasks._targets[id]
					if str(id) == "bed" or bool(t.get("done", false)) or acc_done.has(str(id)) or _near_done(tasks, str(id), acc_done):
						continue
					var sec := float(t.get("seconds", 1.0)) + (1.0 if str(t.get("verb", "")) in ["Mopping", "Sweeping"] else 0.0)
					if sec > best:
						best = sec
						pick = str(id)
			_task_id = pick
			if tasks._targets.has(pick):
				tasks._targets[pick]["seconds"] = 6.0
			print("COOP CHECK %s works on %s (%s)" % [_role, pick, tasks._targets.get(pick, {}).get("verb", "?")])
			super._run_step(["aim_task", "_cabin_interior", pick])
		"coop_row":
			_row_left = float(step[1])
		"coop_open_office":
			# Into the office building through the real interaction path.
			var bm2 = _main.get("building_manager")
			for c in bm2.get_node("Structures").get_children():
				if str(c.get_meta("building_type", "")) == "main_building":
					_main.get("_interior_manager").handle_structure_interact(c)
					break
		"coop_note_job":
			# The job under the hands (the aim can land on another mess lying in front).
			var tasks2 = _main.get("_interior_manager").get("_cabin_interior").get("_prep").tasks
			var held := str(tasks2.working_on())
			if held != _task_id:
				print("COOP CHECK %s: the hands are on %s, not %s" % [_role, held, _task_id])
				if tasks2._targets.has(held):
					tasks2._targets[held]["seconds"] = 6.0
			_task_id = held
		"coop_aim_partner_job":
			# Look at the job the other warden is doing in this room (their figure is at it).
			var job := str((Coop.partner_state.get("room", {}) as Dictionary).get("w", ""))
			print("COOP CHECK %s looks at the other warden's job %s" % [_role, job])
			if job != "":
				super._run_step(["aim_task", "_cabin_interior", job])
		"coop_at_boat":
			# On the camp jetty behind the boat, looking out over the lake.
			var lake = get_tree().root.find_child("CampLake", true, false)
			var me4: Node3D = _main.get("_player")
			if lake != null and me4 != null:
				var home: Transform3D = lake.get("boat_home")
				me4.global_position = (lake as Node3D).global_transform * home.origin + Vector3(-1.4, 0.9, -4.0)
				me4.rotation.y = PI
		"coop_fingerprint":
			_write_fingerprint(str(step[1]))
		_:
			super._run_step(step)


## A job lying by one already done (its mess would be in front of it, or it behind).
static func _near_done(tasks, id: String, acc_done: Array) -> bool:
	var body = tasks._targets[id].get("body")
	if body == null or not is_instance_valid(body):
		return false
	for other in tasks._targets.keys():
		if str(other) == id or not (bool(tasks._targets[other].get("done", false)) or acc_done.has(str(other))):
			continue
		var ob = tasks._targets[other].get("body")
		if ob != null and is_instance_valid(ob) and (ob as Node3D).global_position.distance_to((body as Node3D).global_position) < 0.6:
			return true
	return false


## How far the camp's boat is from its place at the jetty (m).
func _boat_from_home() -> float:
	var lake = get_tree().root.find_child("CampLake", true, false)
	if lake == null or lake.get("boat") == null:
		return -1.0
	var home: Transform3D = lake.get("boat_home")
	return ((lake as Node3D).global_transform * home.origin).distance_to((lake.get("boat") as Node3D).global_position)


## A node's name without Godot's per-process counter (@MeshInstance3D@3614).
static func _stable_name(n: Node) -> String:
	var s := str(n.name)
	return n.get_class() if s.begins_with("@") else s


## The camp's derelict buildings (the old cabin of a new camp) and its rooms' derelict mess.
func _derelict_keys() -> Array:
	var out: Array = []
	var state = CoreRoot.get_state()
	for k in state.failures.keys():
		if bool((state.failures[k] as Dictionary).get("derelict", false)):
			out.append("failure %s" % k)
	for k2 in state.accommodation_states.keys():
		var mess = (state.accommodation_states[k2] as Dictionary).get("mess", {})
		if mess is Dictionary and bool((mess as Dictionary).get("derelict", false)):
			out.append("mess %s" % k2)
	out.sort()
	return out


## The other warden's figure in the room this one is in: its pose, "" when none.
func _room_figure() -> String:
	var im = _main.get("_interior_manager")
	var fig = im.get("_coop_fig") if im != null else null
	if fig == null or not is_instance_valid(fig) or not (fig as Node3D).visible:
		return ""
	return str(fig.get("pose"))


## What this machine's camp is: enough to tell two camps apart.
func _write_fingerprint(tag: String) -> void:
	var wg = _main.get("world_generator")
	var bm = _main.get("building_manager")
	var structures: Array = []
	var root: Node = bm.get_node_or_null("Structures") if bm != null else null
	if root != null:
		for c in root.get_children():
			structures.append("%s@%s r%d" % [str(c.get_meta("building_type", "")), str(c.get_meta("grid_origin", Vector2i.ZERO)), int(c.get_meta("build_rotation", 0))])
	structures.sort()
	var nature: Array = []
	for e in wg.nature_snapshot():
		nature.append("%s:%d:%d" % [e["k"], e["x"], e["y"]])
	nature.sort()
	var trees: Array = []
	var nat: Node = wg.get_node_or_null("Nature")
	if nat != null:
		for n in nat.get_children():
			if n is Node3D:
				var t := (n as Node3D)
				trees.append("%s %.2f,%.2f,%.2f,%.2f" % [_stable_name(t), t.global_position.x, t.global_position.z, t.rotation.y, t.scale.x])
	trees.sort()
	var terrain: Array = []
	var ter: Node = wg.get_node_or_null("Terrain")
	if ter != null:
		for n in ter.find_children("*", "Node3D", true, false):
			var t2 := n as Node3D
			if t2.is_inside_tree():
				terrain.append("%s %.2f,%.2f,%.2f" % [_stable_name(t2), t2.global_position.x, t2.global_position.y, t2.global_position.z])
	terrain.sort()
	var room_key := "%d:%d" % [ROOM.x, ROOM.y]
	var acc: Dictionary = CoreRoot.get_state().accommodation_states.get(room_key, {})
	var done: Array = (acc.get("prep_done", []) as Array).duplicate()
	done.sort()
	var other: Node3D = Coop.remote_figure()
	var fp := {
		"tag": tag,
		"role": _role,
		"seed": int(wg.world_seed),
		"structures": structures,
		"nature": nature,
		"trees": trees,
		"terrain": terrain,
		"beds": int(GuestManager.get_bed_metrics().get("capacity", -1)),
		"derelict": _derelict_keys(),
		"money": int(CoreRoot.get_money()),
		"day": int(CoreRoot.get_day()),
		"hour": float(_main.get("_time_of_day_hours")),
		"host_clock": float(Coop.last_clock.get("h", -1.0)),
		"weather": int(_main.get("_weather_state")),
		"sandbox": bool(_main.get("_sandbox")),
		"partner": Coop.has_partner(),
		"partner_look": [int(Coop.partner_look.get("m", -1)), int(Coop.partner_look.get("c", -1))],
		"my_look": [int(Coop.my_look()["m"]), int(Coop.my_look()["c"])],
		"other_visible": other != null and other.visible,
		"other_at": str(other.global_position) if other != null else "",
		"me_at": str((_main.get("_player") as Node3D).global_position) if _main.get("_player") != null else "",
		"room_done": done,
		"boat_from_home": _boat_from_home(),
		"other_pose": str(other.get("pose")) if other != null else "",
		"room_figure": _room_figure(),
		"coop_screen": float(_main.get("_interior_manager").get("_building_interior").get("_coop_screen_left")) > 0.0,
		"in_bed": _main.get("camp_office") != null and bool(_main.get("camp_office").in_bed()),
		"room_status": str(acc.get("status", "")),
		"task": _task_id,
	}
	var f := FileAccess.open(_out_dir.path_join("%s.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(fp, "\t"))
	f.close()
	print("COOP CHECK fingerprint %s: seed %d, %d structures, %d trees, hour %.2f, room %s %s" % [tag, fp["seed"], structures.size(), trees.size(), fp["hour"], fp["room_status"], str(done)])
