extends "res://tools/coop_check.gd"

## Co-op Photographer check (tools/coop_photo.py): a night with two wardens, the
## Photographer (scripts/enemies/tourist_brain.gd) on the joining one, everything he does
## to them on their machine alone (coop_night._is_private, remote_fx, _on_ext):
##   - a picture of them out in the open: the white, the polaroid of them on their
##     screen; on the host's nothing;
##   - he runs at their back: the host does not see him go;
##   - at their window (they are in the office): the host does not see him there, they
##     do; the shot through it, their polaroid from the glass;
##   - the last picture (them at 10): his lens-face, their face developing, down.
## Each side prints what it has seen since its last report ("COOP PHOTO <role>: ...").
##
##   godot --path godot res://tools/coop_photo.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"
var _ph = null
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
			["eval", "_set_player_health(100)"], ["ph_spawn"], ["wait", 1.0],
			# A picture of them, out in the open.
			["ph_before", 6.0], ["wait", 0.3], ["ph_fire"], ["wait", 0.4],
			["ph_report", "shot_other"], ["shot", "h1_shot_other"], ["coop_signal", "host_shot"],
			["coop_wait_file", "client_shot_seen"], ["wait", 2.0],
			# At their back.
			["ph_rush"], ["wait", 0.5], ["ph_report", "rush_other"], ["shot", "h2_rush_other"], ["coop_signal", "host_rush"],
			["coop_wait_file", "client_rush_seen"], ["wait", 2.0],
			# At their window.
			["coop_signal", "host_window_go"], ["coop_wait_file", "client_in_office"], ["wait", 1.0],
			["coop_wait", "ph_window"], ["wait", 0.5],
			["ph_report", "window_other"], ["shot", "h3_window_other"], ["coop_signal", "host_window"],
			["coop_wait_file", "client_window_seen"],
			["ph_fire_window"], ["wait", 1.5], ["ph_report", "window_shot_other"], ["coop_signal", "host_window_shot"],
			["coop_wait_file", "client_window_shot_seen"], ["wait", 1.0],
			# The last one.
			["ph_out"], ["coop_signal", "host_last_go"], ["coop_wait_file", "client_last_ready"], ["wait", 1.0],
			["ph_before", 6.0], ["wait", 0.3], ["ph_fire"], ["wait", 0.6], ["ph_report", "last_other"], ["shot", "h4_last_other"],
			["coop_signal", "host_last"], ["coop_wait_file", "client_last_seen"], ["wait", 1.0],
			["ph_report", "host_end"],
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
			["ph_report", "start"], ["coop_signal", "client_night"],
			["coop_wait_file", "host_shot"], ["wait", 1.0], ["ph_report", "shot_here"], ["shot", "c1_shot_here"], ["coop_signal", "client_shot_seen"],
			["coop_wait_file", "host_rush"], ["wait", 0.2], ["ph_report", "rush_here"], ["shot", "c2_rush_here"], ["coop_signal", "client_rush_seen"],
			["coop_wait_file", "host_window_go"], ["coop_open_office"], ["wait", 2.0], ["coop_signal", "client_in_office"],
			["coop_wait_file", "host_window"], ["wait", 0.3], ["ph_report", "window_here"], ["shot", "c3_window_here"], ["coop_signal", "client_window_seen"],
			["coop_wait_file", "host_window_shot"], ["wait", 1.2], ["ph_report", "window_shot_here"], ["shot", "c3b_window_shot_here"], ["coop_signal", "client_window_shot_seen"],
			["coop_wait_file", "host_last_go"], ["eval", BI + ".close_interior()"], ["wait", 1.0], ["coop_place", 14, 14, 1.0],
			["eval", "_set_player_health(10)"], ["wait", 1.0], ["ph_report", "last_ready"], ["coop_signal", "client_last_ready"],
			["coop_wait_file", "host_last"], ["wait", 1.6], ["ph_report", "last_here"], ["shot", "c4_last_here"],
			["wait", 4.5], ["ph_report", "last_after"], ["shot", "c4b_last_after"], ["coop_signal", "client_last_seen"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


func _condition_met(what: String) -> bool:
	if what == "ph_window":
		if Time.get_ticks_msec() > _coop_wait_deadline:
			print("COOP CHECK %s: gave up waiting for %s" % [_role, what])
			get_tree().quit(1)
			return false
		return _ph != null and not (_ph.get("_win") as Dictionary).is_empty()
	return super._condition_met(what)


## What each screen shows, every frame as it is drawn, until the next report: the white,
## a close-up, a polaroid (the last one's big), the host's enemies shown here; on the
## host, the Photographer seen while he is the other's alone.
func _look() -> void:
	if _main == null or not is_instance_valid(_main) or not _main.is_inside_tree():
		return
	var fx: Node = _main.get_tree().root.get_node_or_null("NightmareFX")
	if fx != null:
		if bool(fx.get("_white").visible):
			_saw["white"] = true
		if bool(fx.get("_close").visible):
			_saw["close"] = true
	for pol in [_ph.get("_polaroid") if _ph != null else null, (_main.get("_coop_night") as Node).get("_polaroid") if _main.get("_coop_night") != null else null]:
		if pol != null and is_instance_valid(pol) and bool(pol.call("showing")):
			_saw["photo"] = true
			if bool(pol.get("_big")):
				_saw["big"] = true
	var night = _main.get("_coop_night")
	if night != null:
		var shown := 0
		for v in (night.get("_mirror") as Dictionary).values():
			if v is Sprite3D and is_instance_valid(v) and (v as Sprite3D).visible:
				shown += 1
		_saw["mirror"] = maxi(int(_saw.get("mirror", 0)), shown)
	if _ph != null:
		var r = _ph.get("_root")
		if r != null and is_instance_valid(r) and (r as Node3D).visible and bool(_ph.call("is_private_now")):
			_saw["leak"] = true


func _run_step(step: Array) -> void:
	var night = _main.get("_coop_night") if _main != null else null
	match str(step[0]):
		"ph_spawn":
			# Only him tonight, on the other warden, and he stays on them.
			_main.call("_stop_active_enemy_brain")
			_main.call("debug_spawn_enemy", "tourist", 3)
			_ph = (_main.get("_enemy_brains") as Array).back()
			night.call("_aim", _ph, "other")
			night.set("_retarget_t", 9999.0)
		"ph_before":
			# Stood `step[1]` m in front of the other warden, a little to one side.
			var proxy: Node3D = night.call("proxy")
			var cam: Camera3D = proxy.get_node("Head/Camera3D")
			var fwd := -cam.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var p: Vector3 = proxy.global_position + fwd * float(step[1]) + fwd.cross(Vector3.UP) * 1.2
			var g: Vector3 = _ph.call("_ground", p)
			(_ph.get("_body") as Node3D).global_position = g if g != Vector3.INF else p
			_ph.set("_phase", 2)
			_ph.set("_phase_end", float(_ph.get("_elapsed")) + 60.0)
		"ph_fire":
			_ph.call("_fire")
		"ph_rush":
			_ph.set("_hits", 3)
			_ph.call("_enter_rush")
		"ph_fire_window":
			# The shot through their window, as if they looked at it with the curtain open.
			var w: Dictionary = (_ph.get("_win") as Dictionary).duplicate()
			w["open"] = 1.0
			w["facing"] = 1.0
			_ph.call("_fire_through", w)
		"ph_out":
			_ph.set("_win", {})
		"ph_report":
			var root = _ph.get("_root") if _ph != null else null
			var snap: Dictionary = _ph.call("get_debug_snapshot") if _ph != null else {}
			var who := str(night.get("_targets").get(_ph.get_instance_id(), "-")) if _ph != null and night != null else "-"
			print("COOP PHOTO %s: %s white=%s close=%s photo=%s big=%s mirror=%d leak=%s root_seen=%s private=%s hit=%s hits=%s phase=%s window=%s quarry=%s hp=%d down=%s" % [
				_role, str(step[1]), _saw.get("white", false), _saw.get("close", false), _saw.get("photo", false), _saw.get("big", false),
				int(_saw.get("mirror", 0)), _saw.get("leak", false),
				root != null and is_instance_valid(root) and (root as Node3D).visible, _ph != null and bool(_ph.call("is_private_now")),
				_ph.get("_hit_last") if _ph != null else "-", snap.get("hits", "-"), snap.get("phase", "-"), snap.get("window", "-"), who,
				int(_main.get("_player_health")), bool(_main.get("_coop_down"))])
			# The host's screen is never the hunted one here: what it saw is kept to the end.
			if _role != "host":
				_saw.clear()
		_:
			super._run_step(step)
