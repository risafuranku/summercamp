extends "res://tools/coop_check.gd"

## Co-op scare check (tools/coop_scare.py): a night with two wardens, and a scare that
## must be one warden's alone (DESIGN §12, coop_night._is_private):
##   - the Girl strikes the joining warden: on their machine her strike is on the screen
##     (the close-up, the hands, the turned view); on the host's, where the host stands
##     looking at them, there is nothing of her;
##   - she strikes the host: the host has it; the joining machine shows nothing of her.
## Each prints what it sees ("COOP SCARE <role>: ...") for the .py to judge.
##
##   godot --path godot res://tools/coop_scare.tscn -- --role=host --out=DIR

const G := "_enemy_brains.back()"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			["eval", "time_system.set_time_hours(21.6)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 4.0],
			["coop_signal", "host_night"], ["coop_wait_file", "client_night"],
			# The Girl on the other warden: right in front of them, and her strike.
			["eval", "_set_player_health(100)"],
			["eval", "debug_spawn_enemy('girl', 3)"], ["wait", 1.0], ["eval", "_coop_night._aim(" + G + ", 'other')"], ["wait", 0.5],
			["eval", G + "._body.set('global_position', _coop_night._proxies.values()[0]['body'].global_position - _coop_night._proxies.values()[0]['body'].global_transform.basis.z * 1.4)"],
			["eval", G + "._body.set('visible', true)"], ["eval", G + "._start_strike()"],
			["coop_face_partner"], ["wait", 0.8],
			["scare_report", "strike_on_other"], ["shot", "h1_other_struck"], ["coop_signal", "host_strike"],
			["coop_wait_file", "client_struck_seen"], ["wait", 4.5],
			["eval", "_stop_active_enemy_brain()"], ["wait", 1.5],
			# The Girl on the host.
			["eval", "debug_spawn_enemy('girl', 3)"], ["wait", 1.0], ["eval", "_coop_night._aim(" + G + ", 'host')"], ["wait", 0.5],
			["eval", G + "._body.set('global_position', _player.global_position - _player.global_transform.basis.z * 1.4)"],
			["eval", G + "._body.set('visible', true)"], ["eval", G + "._start_strike()"], ["wait", 0.8],
			["scare_report", "strike_on_host"], ["shot", "h2_host_struck"], ["coop_signal", "host_strike2"],
			["coop_wait_file", "client_strike2_seen"], ["wait", 4.5],
			["eval", "_stop_active_enemy_brain()"], ["wait", 1.0],
			["coop_signal", "host_day2_done"], ["coop_wait", "partner_gone"], ["wait", 1.0],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["coop_place", 14, 14, -1.0], ["wait", 1.5], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_night"], ["coop_wait", "night"], ["wait", 2.0], ["coop_signal", "client_night"],
			["coop_wait_file", "host_strike"], ["wait", 0.1],
			["scare_report", "struck_here"], ["shot", "c1_struck"], ["coop_signal", "client_struck_seen"],
			["wait", 2.3], ["scare_report", "struck_after"], ["shot", "c2_struck_after"],
			["wait", 0.35], ["scare_report", "struck_after2"], ["shot", "c2b_struck_after"],
			["coop_wait_file", "host_strike2"], ["coop_face_partner"], ["wait", 0.3],
			["scare_report", "host_struck_seen_from_here"], ["shot", "c3_host_struck"], ["coop_signal", "client_strike2_seen"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


func _run_step(step: Array) -> void:
	if str(step[0]) != "scare_report":
		super._run_step(step)
		return
	var fx: Node = _main.get_tree().root.get_node_or_null("NightmareFX")
	var close := false
	var over := false
	if fx != null:
		close = bool(fx.get("_close").visible)
		over = bool(fx.get("_over").visible)
	var night = _main.get("_coop_night")
	var shown := 0
	var what: Array = []
	if night != null:
		var m: Dictionary = night.get("_mirror")
		for k in m:
			var v = m[k]
			if v is Sprite3D and is_instance_valid(v):
				what.append("%s:%s:%s" % [str(k).get_slice("/", 1), (v as Sprite3D).visible, (v as Sprite3D).texture != null])
				if (v as Sprite3D).visible:
					shown += 1
		print("COOP SCARE %s mirror: %s" % [_role, what])
	var brains: Array = _main.get("_enemy_brains")
	var root_seen := false
	var private_now := false
	var st := -1.0
	var el := -1.0
	if not brains.is_empty() and brains.back() != null:
		st = float(brains.back().get("_strike_t"))
		el = float(brains.back().get("_elapsed"))
		var r: Node3D = brains.back().get("_root")
		root_seen = r != null and is_instance_valid(r) and r.visible
		private_now = bool(brains.back().call("is_private_now"))
	var cam: Camera3D = (_main.get("_player") as Node).get_node_or_null("Head/Camera3D")
	print("COOP SCARE %s: %s close=%s over=%s mirror_shown=%d enemy_root_seen=%s private=%s roll=%.2f strike_t=%.2f elapsed=%.1f night=%s" % [_role, str(step[1]), close, over, shown, root_seen, private_now, cam.rotation.z if cam != null else 0.0, st, el, _main.call("_is_enemy_night_active")])
