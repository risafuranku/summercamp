extends "res://tools/coop_check.gd"

## The god cursor for two (scripts/god/god_cursor.gd), two copies on this machine
## (tools/god_coop.py): the host sits at its PC and builds in Builder 98 (a cabin, a line
## of path, a bulldozed wood); the joining warden stands outside and watches it come down
## from the sky; then the joining warden builds from its own PC and the host, outside now,
## watches that. Runs of shots from both sides.

const MAP := "debug_builder_map()"
const UI := "_interior_manager._building_interior._crt_ui"
const GOD := "_god_cursor"


func _burst(name: String, n: int, dt: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(["shot", "%s_%02d" % [name, i]])
		out.append(["wait", dt])
	return out


## Into the PC with Builder 98 open on it (as the warden would sit down to it).
func _to_builder() -> Array:
	return [["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", UI + ".open_app('builder') != null"], ["wait", 4.5], ["eval", "debug_close_msgboxes()"], ["wait", 0.5]]


## Builds as the Builder sends them (the map's own request), each a frame apart.
func _builds() -> Array:
	var b: Array = [["eval", MAP + "._send_build_request('cabin_1', Vector2i(8, 7), 1)"], ["wait", 0.3]]
	for x in range(7, 13):
		b.append(["coop_build_at", "path", x, 5])
	b.append_array([["wait", 0.3], ["eval", MAP + "._send_demolish_request(Rect2i(17, 6, 3, 3))"], ["wait", 0.5]])
	return b


func _ready() -> void:
	super._ready()
	if _role == "host":
		var s: Array = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["eval", "debug_jump_to(1, 11.0)"], ["money", 90000], ["clear", 5, 3, 10, 12], ["wait", 1.5],
			["coop_place", 10, 16, 1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"]]
		# The host builds at its PC: queued here while it sits there, on the other's sky now.
		s.append_array(_to_builder())
		s.append_array(_builds())
		s.append_array([["eval", "[%s.busy(), %s._queue.size()]" % [GOD, GOD]], ["coop_signal", "host_built"],
			["coop_wait_file", "client_watched"],
			# Standing up from the PC: the host's own queue comes down now (outside to see it).
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 0.5],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.5],
			["coop_place", 10, 16, 1.0],
			["god_look", 9, 7, 14.0]])
		s.append_array(_burst("h_own", 30, 0.25))
		s.append_array([["coop_signal", "host_outside"], ["coop_wait_file", "client_built"], ["god_look", 13, 10, 14.0]])
		s.append_array(_burst("h_other", 40, 0.25))
		s.append_array([["eval", "[%s.busy(), %s._vis]" % [GOD, GOD]], ["coop_signal", "host_done"], ["wait", 2.0]])
		_steps = s
	else:
		var c: Array = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]], ["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"],
			["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager.close_everything()"], ["wait", 1.0],
			["coop_place", 9, 16, -1.0], ["coop_wait", "partner_seen"], ["god_look", 9, 7, 14.0], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_built"]]
		c.append_array(_burst("c_host_builds", 48, 0.25))
		c.append_array([["eval", "[%s.busy(), %s._queue.size()]" % [GOD, GOD]], ["coop_signal", "client_watched"],
			["coop_wait_file", "host_outside"]])
		c.append_array(_to_builder())
		c.append_array([["eval", MAP + "._send_build_request('pub', Vector2i(12, 9), 2)"], ["wait", 1.5], ["coop_signal", "client_built"],
			["coop_wait_file", "host_done"], ["wait", 1.0]])
		_steps = c


## A port of its own: the other co-op checks may be running beside it.
const GOD_PORT := 24993


func _run_step(step: Array) -> void:
	if str(step[0]) == "coop_port":
		Coop.port = GOD_PORT
		return
	if str(step[0]) == "coop_join":
		_main.call("_on_menu_coop_join", "%s:%d" % [str(step[1]), GOD_PORT])
		return
	if str(step[0]) == "god_look":
		# The warden's eyes on a spot of the camp ([1], [2]), [3] m up: the sky over it.
		var me: Node3D = _main.get("_player")
		var gm = _main.get("grid_manager")
		if me != null and gm != null:
			var at: Vector3 = gm.grid_to_world(Vector2i(int(step[1]), int(step[2])))
			var to := at - me.global_position
			to.y = 0.0
			me.rotation.y = atan2(-to.x, -to.z)
			var up := atan2(float(step[3]), maxf(1.0, to.length()))
			me.set("_pitch_target", up)
			me.set("_pitch", up)
		return
	super._run_step(step)
