extends "res://tools/shot_driver.gd"

## Co-op harness (scripts/coop/coop.gd): two copies of the game on this machine, one
## hosting a sandbox camp, one joining it on 127.0.0.1, each taking pictures of the
## other warden and writing what its camp looks like (seed, buildings, every tree, the
## terrain, the clock) for tools/coop_check.py to compare. The two wait for each other
## by what happens (the other is on the line, in sight, it is night, they hung up), not
## by the clock: a camp takes the joining copy tens of seconds to build here.
##
##   godot --path godot res://tools/coop_check.tscn -- --role=host --out=DIR
##   godot --path godot res://tools/coop_check.tscn -- --role=client --out=DIR
## (coop_check.py runs both and reads DIR/host.json, DIR/client.json, ..._night.json).

const PORT := 24990
const WAIT_MS := 150000
var _role := "host"
var _coop_wait_deadline := 0


func _ready() -> void:
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.get_slice("=", 1)
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			# A clearing in the middle of the camp, cut before the other copy joins (so
			# its camp has it too), where the two can see each other.
			["money", 9000], ["clear", 11, 12, 5, 5], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["coop_up"],
			["coop_wait", "partner_seen"], ["coop_wait", "partner_ready"], ["wait", 1.0],
			["coop_face_partner"], ["wait", 1.0], ["shot", "h1_sees_other"],
			["coop_fingerprint", "host"],
			["eval", "time_system.set_time_hours(21.6)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 4.0],
			["coop_face_partner"], ["wait", 1.5], ["shot", "h2_night_other_torch"],
			["coop_fingerprint", "host_night"],
			["coop_wait", "partner_gone"], ["wait", 1.5], ["shot", "h3_other_went_home"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["eval", "_main_menu.show_page('coop')"], ["wait", 1.0], ["shot", "c0_coop_page"],
			["coop_wait", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["coop_fingerprint", "client"],
			["coop_place", 14, 14, -1.0], ["wait", 1.5],
			["coop_face_partner"], ["wait", 1.0], ["shot", "c1_sees_host"],
			["coop_ready"],
			["coop_wait", "night"], ["wait", 3.0],
			["coop_face_partner"], ["wait", 1.5], ["shot", "c2_night_host_torch"],
			["coop_fingerprint", "client_night"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


func _condition_met(what: String) -> bool:
	if what in ["partner_seen", "partner_ready", "partner_gone", "night", "host_up", "host_done"] and Time.get_ticks_msec() > _coop_wait_deadline:
		print("COOP CHECK %s: gave up waiting for %s" % [_role, what])
		get_tree().quit(1)
		return false
	match what:
		"partner_seen":
			var other: Node3D = Coop.remote_figure()
			return other != null and other.visible
		"partner_ready":
			# The joining copy has its pictures and says so (it stops by the shelter).
			return FileAccess.file_exists(_out_dir.path_join("client_ready"))
		"partner_gone":
			return not Coop.has_partner()
		"night":
			var h := float(_main.get("_time_of_day_hours"))
			return h >= 21.0 or h < 5.0
		"host_done":
			# The host has its night picture: the joining copy may hang up.
			return FileAccess.file_exists(_out_dir.path_join("host_night.json"))
		"host_up":
			# The host's copy boots slowly: call once its camp is open.
			return FileAccess.file_exists(_out_dir.path_join("host_up"))
	return super._condition_met(what)


func _run_step(step: Array) -> void:
	match str(step[0]):
		"coop_port":
			Coop.port = PORT
		"coop_join":
			_main.call("_on_menu_coop_join", "%s:%d" % [str(step[1]), PORT])
		"coop_wait":
			_waiting_for = str(step[1])
			_coop_wait_deadline = Time.get_ticks_msec() + WAIT_MS
		"coop_place":
			# Stand on a tile (its centre), facing along x (+1 east, -1 west).
			var me3: Node3D = _main.get("_player")
			var gm = _main.get("grid_manager")
			if me3 != null and gm != null:
				me3.global_position = gm.grid_to_world(Vector2i(int(step[1]), int(step[2]))) + Vector3(0.0, 0.6, 0.0)
				me3.rotation.y = atan2(-float(step[3]), 0.0)
		"coop_up":
			FileAccess.open(_out_dir.path_join("host_up"), FileAccess.WRITE).store_string("up")
		"coop_ready":
			FileAccess.open(_out_dir.path_join("client_ready"), FileAccess.WRITE).store_string("ready")
		"coop_leave":
			Coop.leave()
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
		"coop_walk":
			# Step the warden along the ground (dx, dz in metres), as if walked.
			var me2: Node3D = _main.get("_player")
			if me2 != null:
				me2.global_position += Vector3(float(step[1]), 0.0, float(step[2]))
		"coop_fingerprint":
			_write_fingerprint(str(step[1]))
		_:
			super._run_step(step)


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
		"other_visible": other != null and other.visible,
		"other_at": str(other.global_position) if other != null else "",
		"me_at": str((_main.get("_player") as Node3D).global_position) if _main.get("_player") != null else "",
	}
	var f := FileAccess.open(_out_dir.path_join("%s.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(fp, "\t"))
	f.close()
	print("COOP CHECK fingerprint %s: seed %d, %d structures, %d nature, %d trees, terrain %d, hour %.2f" % [tag, fp["seed"], structures.size(), nature.size(), trees.size(), terrain.size(), fp["hour"]])
