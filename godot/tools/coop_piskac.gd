extends "res://tools/coop_check.gd"

## Co-op check of the Whistler (tools/coop_piskac.py; DESIGN §5a.3): he hunts the joining
## warden. Their machine hears his song while he plays and the hush is on them; the song
## stopped dead is stopped dead there (it played out to the end of its file for up to 14 s);
## his strike is on their screen and hurts them, nothing of it on the host's. Each prints what
## it sees ("COOP PISKAC <role>: ...").
##
##   godot --path godot res://tools/coop_piskac.tscn -- --role=host --out=DIR

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
			# He is out, after the other warden, playing a little way off, listening.
			["eval", "debug_spawn_enemy('whistler', 3)"], ["eval", "_director.ever.merge({'whistler_met': true})"], ["wait", 0.5],
			["eval", "_coop_night._aim(" + G + ", 'other')"], ["wait", 0.5],
			["eval", "get_tree().root.get_node('CoopPiskac').play_near()"], ["wait", 1.5],
			["piskac_report", "play_other"], ["coop_signal", "host_play"], ["coop_wait_file", "client_play_seen"],
			# The song stopped dead.
			["eval", G + "._enter('gap', 30.0)"], ["wait", 0.1], ["piskac_report", "gap_other"], ["coop_signal", "host_gap"], ["coop_wait_file", "client_gap_seen"],
			# The strike.
			["eval", "get_tree().root.get_node('CoopPiskac').strike_now()"], ["coop_signal", "host_strike"], ["wait", 3.4],
			["piskac_report", "struck_other"], ["coop_signal", "host_struck"], ["coop_wait_file", "client_struck_seen"],
			["eval", "_stop_active_enemy_brain()"], ["wait", 1.0],
			["coop_signal", "host_day2_done"], ["coop_wait", "partner_gone"], ["wait", 1.0],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["coop_place", 14, 14, -1.0], ["wait", 1.5], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_night"], ["coop_wait", "night"], ["wait", 2.0], ["coop_signal", "client_night"],
			["coop_wait_file", "host_play"], ["wait", 0.5], ["piskac_report", "play_here"], ["coop_signal", "client_play_seen"],
			["coop_wait_file", "host_gap"], ["wait", 0.7], ["piskac_report", "gap_here"], ["coop_signal", "client_gap_seen"],
			["coop_wait_file", "host_strike"], ["wait", 1.0], ["piskac_report", "strike_here"], ["shot", "c1_string"],
			["coop_wait_file", "host_struck"], ["wait", 0.3], ["piskac_report", "struck_here"], ["coop_signal", "client_struck_seen"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


## Him a little way off the other warden, playing and listening, the first notes over.
func play_near() -> String:
	var b = _main.get("_enemy_brains").back()
	var proxies: Dictionary = _main.get("_coop_night").get("_proxies")
	var body: Node3D = proxies.values()[0]["body"]
	b.set("_pos", b._stand(body.global_position - body.global_transform.basis.z * 10.0))
	b._enter("play", 60.0)
	b.set("_grace", 0.0)
	b.set("_pos", b._stand(body.global_position - body.global_transform.basis.z * 10.0))
	return "playing at %.1f m" % body.global_position.distance_to(b.get("_pos"))


func strike_now() -> String:
	var b = _main.get("_enemy_brains").back()
	var proxies: Dictionary = _main.get("_coop_night").get("_proxies")
	var body: Node3D = proxies.values()[0]["body"]
	b.set("_pos", body.global_position - body.global_transform.basis.z * 1.0)
	b._start_strike()
	return "strike"


func _run_step(step: Array) -> void:
	if str(step[0]) != "piskac_report":
		super._run_step(step)
		return
	var fx: Node = _main.get_tree().root.get_node_or_null("NightmareFX")
	var hush := float(fx.get("_hush")) if fx != null and fx.get("_hush") != null else -1.0
	var over: Variant = fx.get("_over") if fx != null else null
	var songs := 0
	var night = _main.get("_coop_night")
	if night != null:
		var m: Dictionary = night.get("_mirror")
		for k in m:
			var v = m[k]
			# (The song is the one looped MP3 of his there; its looped copy has no path to read.)
			if v is AudioStreamPlayer3D and is_instance_valid(v) and (v as AudioStreamPlayer3D).playing and (v as AudioStreamPlayer3D).stream is AudioStreamMP3 and ((v as AudioStreamPlayer3D).stream as AudioStreamMP3).loop:
				songs += 1
	var phase := ""
	var brains: Array = _main.get("_enemy_brains")
	if not brains.is_empty() and brains.back() != null and brains.back().has_method("get_debug_snapshot"):
		phase = str(brains.back().get_debug_snapshot().get("phase", ""))
	print("COOP PISKAC %s: %s songs=%d hush=%.2f over=%s hp=%d phase=%s" % [_role, str(step[1]), songs, hush,
		str(over != null and (over as CanvasItem).visible), int(_main.get("_player_health")), phase])
