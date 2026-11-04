extends "res://tools/coop_check.gd"

## Co-op Girl check (tools/coop_girl.py): a night with two wardens, the Girl
## (scripts/enemies/girl_brain.gd) hunting the joining one:
##   - they look away from her while the host's torch is on her: she does not move (no
##     step, not suddenly behind them: another warden's torch holds her as theirs does);
##   - the host looks away too: now she comes;
##   - they turn to her with their torch: her stage on their screen, the cold in their
##     torch (the drain held on their machine), the presence in their ears, her
##     interference from where she was and the set catching its picture as they find her;
##     the host's screen and ears have none of it all night.
## Each side prints what it has seen ("COOP GIRL <role>: ...").
##
##   godot --path godot res://tools/coop_girl.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"
var _gl = null
var _mark := Vector3.INF
var _saw := {}


func _ready() -> void:
	super._ready()
	RenderingServer.frame_pre_draw.connect(_look)
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0],
			["coop_place", 12, 14, -1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			["eval", "time_system.set_time_hours(21.6)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 4.0],
			["coop_signal", "host_night"], ["coop_wait_file", "client_night"],
			["eval", "_set_player_health(100)"], ["gl_spawn"], ["wait", 1.0],
			# 9 m in front of them; they look away; the host's torch on her.
			["gl_place", 9.0], ["coop_signal", "host_placed"], ["coop_wait_file", "client_away"],
			["gl_host_look", true], ["wait", 1.0], ["gl_mark"], ["wait", 6.0], ["gl_report", "held"], ["shot", "h1_held"],
			# The host looks away too.
			["gl_host_look", false], ["gl_mark"], ["wait", 4.0], ["gl_report", "free"],
			# They turn to her with their torch.
			["gl_place", 7.0], ["coop_signal", "host_face"], ["coop_wait_file", "client_faced"], ["wait", 0.3], ["gl_report", "faced"],
			["coop_signal", "host_faced_seen"], ["coop_wait_file", "client_done"],
			["gl_report", "host_end"],
			["eval", "_stop_active_enemy_brain()"], ["wait", 1.0],
			["coop_signal", "host_day2_done"], ["coop_wait", "partner_gone"], ["wait", 1.0],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0],
			["coop_place", 14, 14, 1.0], ["wait", 1.5], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_night"], ["coop_wait", "night"], ["wait", 2.0], ["eval", "_set_player_health(100)"],
			["gl_torch"], ["gl_report", "start"], ["coop_signal", "client_night"],
			["coop_wait_file", "host_placed"], ["coop_wait", "her_copy"], ["gl_face", false], ["wait", 0.5], ["coop_signal", "client_away"],
			["coop_wait_file", "host_face"], ["coop_wait", "her_copy"], ["gl_face", true], ["wait", 2.0], ["gl_report", "faced_here"], ["shot", "c1_faced"],
			["coop_signal", "client_faced"],
			["coop_wait_file", "host_faced_seen"], ["wait", 0.3], ["coop_signal", "client_done"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


func _condition_met(what: String) -> bool:
	if what == "her_copy":
		if Time.get_ticks_msec() > _coop_wait_deadline:
			print("COOP CHECK %s: gave up waiting for %s" % [_role, what])
			get_tree().quit(1)
			return false
		var her := _her_body()
		return her != null and (her as Node3D).visible
	return super._condition_met(what)


## Every frame as it is drawn: the most of the presence and dread on this screen, her
## pictures shown here (the host's enemies' copies).
func _look() -> void:
	if _main == null or not is_instance_valid(_main) or not _main.is_inside_tree():
		return
	var fx: Node = _main.get_tree().root.get_node_or_null("NightmareFX")
	if fx != null:
		_saw["presence"] = maxf(float(_saw.get("presence", 0.0)), float(fx.get("_presence")))
		_saw["dread"] = maxf(float(_saw.get("dread", 0.0)), float(fx.get("_dread")))
		_saw["jam"] = maxf(float(_saw.get("jam", 0.0)), float(fx.get("_jam")))
		if float(fx.get("_lock_t")) >= 0.0:
			_saw["lock"] = true
	var night = _main.get("_coop_night")
	if night != null:
		var shown := 0
		for v in (night.get("_mirror") as Dictionary).values():
			if is_instance_valid(v) and v is Sprite3D and (v as Sprite3D).visible:
				shown += 1
		_saw["mirror"] = maxi(int(_saw.get("mirror", 0)), shown)
	var pl = _main.get("_player")
	if pl != null:
		_saw["drain"] = maxf(float(_saw.get("drain", 0.0)), float(pl.get("flashlight_drain_boost")))


## Her body as this machine draws it: the brain's on the host, its copy here.
func _her_body() -> Node3D:
	if _gl != null:
		return _gl.get("_body")
	var night = _main.get("_coop_night")
	var best: Sprite3D = null
	if night != null:
		for v in (night.get("_mirror") as Dictionary).values():
			if is_instance_valid(v) and v is Sprite3D and (v as Sprite3D).texture != null:
				var s := v as Sprite3D
				if best == null or s.texture.get_height() * s.pixel_size > best.texture.get_height() * best.pixel_size:
					best = s
	return best


func _face(me: Node3D, at: Vector3, toward: bool) -> void:
	var to := at - me.global_position
	to.y = 0.0
	if not toward:
		to = -to
	me.rotation.y = atan2(-to.x, -to.z)
	var cam: Camera3D = me.get_node_or_null("Head/Camera3D")
	if cam != null:
		cam.rotation.x = 0.0


func _run_step(step: Array) -> void:
	var night = _main.get("_coop_night") if _main != null else null
	match str(step[0]):
		"gl_spawn":
			# Only her tonight, on the other warden, and she stays on them.
			_main.call("_stop_active_enemy_brain")
			_main.call("debug_spawn_enemy", "girl", 3)
			_gl = (_main.get("_enemy_brains") as Array).back()
			night.call("_aim", _gl, "other")
			night.set("_retarget_t", 9999.0)
		"gl_place":
			# `step[1]` m in front of the other warden, stalking, far from any lamp.
			var proxy: Node3D = night.call("proxy")
			var cam: Camera3D = proxy.get_node("Head/Camera3D")
			var fwd := -cam.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var want: Vector3 = proxy.global_position + fwd * float(step[1])
			var at: Vector3 = _gl.call("_stand", want)
			var body: Node3D = _gl.get("_body")
			body.global_position = at if at != Vector3.INF else want
			body.visible = true
			_gl.set("_phase", 1)
			_gl.set("_unseen_for", 0.0)
			_gl.set("_away_for", 0.0)
			_gl.set("_moved_unseen", true)
			_gl.call("_set_look", false, float(step[1]))
		"gl_host_look":
			var me: Node3D = _main.get("_player")
			if not bool(me.call("is_flashlight_active")):
				me.call("toggle_flashlight")
			var body: Node3D = _gl.get("_body")
			_face(me, body.global_position, bool(step[1]))
		"gl_torch":
			var me2: Node3D = _main.get("_player")
			if not bool(me2.call("is_flashlight_active")):
				me2.call("toggle_flashlight")
		"gl_face":
			var her := _her_body()
			if her == null:
				print("COOP GIRL %s: no copy of her here to face" % _role)
				return
			_face(_main.get("_player"), her.global_position, bool(step[1]))
		"gl_mark":
			_mark = (_gl.get("_body") as Node3D).global_position
		"gl_report":
			var moved := "-"
			var dist := -1.0
			var held := "-"
			var phase := -1
			if _gl != null:
				var body2: Node3D = _gl.get("_body")
				moved = str(_mark != Vector3.INF and body2.global_position.distance_to(_mark) > 0.3)
				dist = float(_gl.call("_distance_to_player", body2.global_position))
				held = str(_gl.get("_held"))
				phase = int(_gl.get("_phase"))
			print("COOP GIRL %s: %s moved=%s dist=%.1f held=%s phase=%d presence=%.2f dread=%.2f mirror=%d drain=%.1f torch=%s hp=%d jam=%.2f lock=%s" % [
				_role, str(step[1]), moved, dist, held, phase, float(_saw.get("presence", 0.0)), float(_saw.get("dread", 0.0)),
				int(_saw.get("mirror", 0)), float(_saw.get("drain", 0.0)), bool((_main.get("_player") as Node).call("is_flashlight_active")),
				int(_main.get("_player_health")), float(_saw.get("jam", 0.0)), _saw.get("lock", false)])
			# The host's screen is never the hunted one here: what it saw is kept to the end.
			if _role != "host":
				_saw.clear()
		_:
			super._run_step(step)
