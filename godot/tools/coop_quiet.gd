extends "res://tools/coop_check.gd"

## Co-op Silent Man check (tools/coop_quiet.py): a night with two wardens, the Silent Man
## (scripts/enemies/silent_man_brain.gd) on the joining one, every scare of his theirs
## alone (coop_night._is_private, remote_fx):
##   - a catch at their ear: the close-up and the turned view on their screen; on the
##     host's, looking at them, nothing of him;
##   - at their neck, holding them: his hands over their shoulder, they move at half
##     speed; the host does not see him there;
##   - their torch on him: he comes apart in the dither on their screen (not just gone);
##     the host sees nothing of it;
##   - his neck round a corner: theirs to see, not the host's;
##   - a catch at the host's ear: the host's; the joining machine shows nothing of him.
## Each side prints what it has seen since its last report ("COOP QUIET <role>: ...").
##
##   godot --path godot res://tools/coop_quiet.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"
var _sm = null
var _saw := {}


func _ready() -> void:
	super._ready()
	RenderingServer.frame_pre_draw.connect(_look)
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			["eval", "time_system.set_time_hours(21.6)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 4.0],
			["coop_signal", "host_night"], ["coop_wait_file", "client_night"],
			["eval", "_set_player_health(100)"], ["sm_spawn", "other"], ["wait", 1.0], ["coop_face_partner"], ["sm_report", "start"],
			# A catch at their ear, the host looking at them.
			["sm_behind", -1.4], ["sm_catch", "ear"], ["wait", 0.8],
			["sm_report", "strike_other"], ["shot", "h1_strike_other"], ["coop_signal", "host_strike"],
			["coop_wait_file", "client_strike_seen"], ["wait", 3.0], ["sm_report", "strike_other_end"],
			# At their neck, holding them (the host turned away: his torch on him would drive
			# him off, watching their back; what the host's machine shows does not hang on it).
			["sm_spawn", "other"], ["wait", 1.0], ["coop_face_partner"], ["eval", "_player.rotate_y(3.14159)"], ["wait", 0.3], ["sm_neck"], ["wait", 0.6],
			["sm_report", "neck_other"], ["shot", "h2_neck_other"], ["coop_signal", "host_neck"],
			["coop_wait_file", "client_neck_seen"], ["wait", 4.0], ["sm_report", "neck_other_end"],
			# Their torch on him: he comes apart.
			["sm_spawn", "other"], ["wait", 1.0], ["coop_face_partner"], ["sm_behind", 3.0], ["wait", 0.3], ["sm_call", "_driven_off"],
			["coop_signal", "host_lit"], ["wait", 1.2], ["sm_report", "lit_other"], ["shot", "h3_lit_other"],
			["coop_wait_file", "client_lit_seen"], ["wait", 1.0],
			# His neck round a corner, theirs.
			["sm_spawn", "other"], ["wait", 1.0], ["coop_face_partner"], ["sm_peek"], ["coop_signal", "host_peek"], ["wait", 0.6],
			["sm_report", "peek_other"], ["shot", "h4_peek_other"], ["coop_wait_file", "client_peek_seen"], ["wait", 1.0],
			# A catch at the host's ear.
			["sm_spawn", "host"], ["wait", 1.0], ["sm_behind", -1.4], ["sm_catch", "ear"], ["wait", 0.8],
			["sm_report", "strike_host"], ["shot", "h5_strike_host"], ["coop_signal", "host_strike2"],
			["coop_wait_file", "client_strike2_seen"], ["wait", 3.0],
			["eval", "_stop_active_enemy_brain()"], ["wait", 1.0],
			["coop_signal", "host_day2_done"], ["coop_wait", "partner_gone"], ["wait", 1.0],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0],
			["coop_place", 15, 14, 1.0], ["wait", 1.5], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_night"], ["coop_wait", "night"], ["wait", 2.0], ["eval", "_set_player_health(100)"],
			["sm_report", "start"], ["coop_signal", "client_night"],
			["coop_wait_file", "host_strike"], ["wait", 0.6], ["sm_report", "strike_here"], ["shot", "c1_strike_here"],
			["wait", 1.6], ["sm_report", "strike_after"], ["shot", "c1b_strike_after"], ["coop_signal", "client_strike_seen"],
			["coop_wait_file", "host_neck"], ["wait", 0.4], ["sm_report", "neck_here"], ["shot", "c2_neck_here"], ["coop_signal", "client_neck_seen"],
			["coop_wait_file", "host_lit"], ["wait", 1.4], ["sm_report", "lit_here"], ["shot", "c3_lit_here"], ["coop_signal", "client_lit_seen"],
			["coop_wait_file", "host_peek"], ["wait", 0.5], ["sm_report", "peek_here"], ["shot", "c4_peek_here"], ["coop_signal", "client_peek_seen"],
			["coop_wait_file", "host_strike2"], ["sm_clear"], ["coop_face_partner"], ["wait", 0.5],
			["sm_report", "host_struck_seen_from_here"], ["shot", "c5_host_struck"], ["coop_signal", "client_strike2_seen"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


## What each screen shows, every frame as it is drawn, until the next report: a close-up,
## the most of the host's enemies shown here, him coming apart, his long neck, the view
## rolled, held back; on the host, him seen while he is the other's alone (a leak).
func _look() -> void:
	if _main == null or not is_instance_valid(_main) or not _main.is_inside_tree():
		return
	var fx: Node = _main.get_tree().root.get_node_or_null("NightmareFX")
	if fx != null and bool(fx.get("_close").visible):
		_saw["close"] = true
	var night = _main.get("_coop_night")
	if night != null:
		var shown := 0
		for v in (night.get("_mirror") as Dictionary).values():
			if not (v is Sprite3D) or not is_instance_valid(v) or not (v as Sprite3D).visible or (v as Sprite3D).texture == null:
				continue
			shown += 1
			var tex: Texture2D = (v as Sprite3D).texture
			if tex.has_meta("fx_src") and str((tex.get_meta("fx_src") as Dictionary).get("proc", "")) == "dissolve":
				_saw["dissolve"] = true
			var src := tex.resource_path if tex.resource_path != "" else str((tex.get_meta("fx_src", {}) as Dictionary).get("src", ""))
			if src.contains("neck"):
				_saw["neck"] = true
		_saw["mirror"] = maxi(int(_saw.get("mirror", 0)), shown)
	var me = _main.get("_player")
	if me != null and is_instance_valid(me):
		if float(me.get("held_speed_mult")) < 0.9:
			_saw["slow"] = true
		var cam: Camera3D = (me as Node).get_node_or_null("Head/Camera3D")
		if cam != null:
			_saw["roll"] = maxf(float(_saw.get("roll", 0.0)), absf(cam.rotation.z))
	if _sm != null and is_instance_valid(_sm) and night != null:
		var r = _sm.get("_root")
		var quarry := str((night.get("_targets") as Dictionary).get(_sm.get_instance_id(), "host"))
		if quarry != "host" and r != null and is_instance_valid(r) and (r as Node3D).visible and bool(_sm.call("is_private_now")):
			_saw["leak"] = true
		if bool(_sm.call("is_private_now")):
			_saw["private"] = true


func _run_step(step: Array) -> void:
	var night = _main.get("_coop_night") if _main != null else null
	match str(step[0]):
		"sm_spawn":
			# Only him tonight, on `step[1]`, and he stays on them.
			_main.call("_stop_active_enemy_brain")
			_main.call("debug_spawn_enemy", "silent_man", 3)
			_sm = (_main.get("_enemy_brains") as Array).back()
			night.call("_aim", _sm, str(step[1]))
			night.set("_retarget_t", 9999.0)
			# Met already: no first meeting, no lesson in place of the catch.
			_sm.set("_first", false)
			_sm.set("_revealed", true)
		"sm_behind":
			# `step[1]` m in front of his quarry (behind them when negative), out of a lurk.
			var q: Node3D = _sm.get("_player")
			var cam: Camera3D = q.get_node("Head/Camera3D")
			var fwd := -cam.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var p: Vector3 = q.global_position + fwd * float(step[1])
			var g: Vector3 = _sm.call("_ground", p)
			var body: Node3D = _sm.get("_body")
			body.global_position = g if g != Vector3.INF else p
			body.visible = true
			_sm.set("_lurking", false)
			_sm.set("_staring", false)
			_sm.set("_dist", absf(float(step[1])))
			_sm.set("_resume_at", 0.0)
		"sm_clear":
			_saw.clear()
		"sm_catch":
			_sm.call("_start_catch", str(step[1]))
		"sm_call":
			_sm.call(str(step[1]))
		"sm_neck":
			# Right at their neck, the hold on: turn round or get away.
			_run_step(["sm_behind", -1.6])
			_sm.set("_neck_from", (_sm.get("_player") as Node3D).global_position)
			_sm.set("_neck_until", float(_sm.get("_elapsed")) + 2.5)
			_sm.call("_start_hold")
		"sm_peek":
			# Round his corner 8 m off to the side; only his neck comes round it.
			var q2: Node3D = _sm.get("_player")
			var cam2: Camera3D = q2.get_node("Head/Camera3D")
			var right := cam2.global_transform.basis.x
			right.y = 0.0
			var fwd2 := -cam2.global_transform.basis.z
			fwd2.y = 0.0
			var at: Vector3 = q2.global_position + fwd2.normalized() * 8.0
			_sm.set("_lurking", true)
			_sm.set("_staring", false)
			_sm.set("_lurk_spot", at + right.normalized() * 0.8)
			_sm.set("_resume_at", float(_sm.get("_elapsed")) + 6.0)
			_sm.set("_peek_t", 2.0)
			(_sm.get("_body") as Node3D).visible = true
			_sm.call("_show_neck", at, at + right.normalized() * 0.8)
		"sm_report":
			var root = _sm.get("_root") if _sm != null and is_instance_valid(_sm) else null
			var who := str(night.get("_targets").get(_sm.get_instance_id(), "-")) if _sm != null and is_instance_valid(_sm) and night != null else "-"
			var seq: Dictionary = _sm.get("_seq") if _sm != null and is_instance_valid(_sm) else {}
			print("COOP QUIET %s: %s close=%s mirror=%d dissolve=%s neck=%s slow=%s roll=%.2f leak=%s private=%s root_seen=%s quarry=%s seq=%s neck_until=%s vanish=%s hp=%d" % [
				_role, str(step[1]), _saw.get("close", false), int(_saw.get("mirror", 0)), _saw.get("dissolve", false), _saw.get("neck", false),
				_saw.get("slow", false), float(_saw.get("roll", 0.0)), _saw.get("leak", false), _saw.get("private", false),
				root != null and is_instance_valid(root) and (root as Node3D).visible, who, str(seq.get("kind", "-")),
				"%.1f" % float(_sm.get("_neck_until")) if _sm != null and is_instance_valid(_sm) else "-",
				"%.1f" % float(_sm.get("_vanish_at")) if _sm != null and is_instance_valid(_sm) else "-",
				int(_main.get("_player_health"))])
			_saw.clear()
		_:
			super._run_step(step)
