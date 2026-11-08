extends "res://tools/coop_check.gd"

## Co-op check of the mushroom granny (tools/coop_babka.py; DESIGN §5a.4): she hunts the
## warden who is outside (the joining one), who sees her and has her spores on their
## screen; her catch hurts them and leaves them limping. (The guests she eats while you
## hide: tools/babka_shots.tscn, one machine.) Each prints what it sees ("COOP BABKA
## <role>: ...").
##
##   godot --path godot res://tools/coop_babka.tscn -- --role=host --out=DIR [--case=inside]
## `--case=inside`: both wardens hidden in the office with guests in three tents: she
## eats on the host's camp, and the other warden hears it on their office radio too.

const G := "_enemy_brains.back()"


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--case=inside"):
		_steps = _inside_steps()
		return
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			["eval", "time_system.set_time_hours(21.6)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 4.0],
			["coop_signal", "host_night"], ["coop_wait_file", "client_night"],
			# She is out, after the other warden: close to them, coming.
			# (The camp has met her: the first catch in a camp only looks, basket_brain._met.)
			["eval", "debug_spawn_enemy('basket', 3)"], ["eval", G + ".set('soon', true)"], ["eval", "_director.ever.merge({'granny_met': true})"], ["wait", 1.0],
			["eval", "_coop_night._aim(" + G + ", 'other')"], ["wait", 0.5],
			["eval", G + "._body.set('global_position', _coop_night._proxies.values()[0]['body'].global_position - _coop_night._proxies.values()[0]['body'].global_transform.basis.z * 4.0)"],
			["wait", 1.5], ["babka_report", "near_other"], ["coop_signal", "host_near"],
			["coop_wait_file", "client_near_seen"],
			# Her catch on them (then she is stopped: one is enough to see).
			["eval", G + "._start_strike()"], ["wait", 2.6], ["babka_report", "struck_other"],
			["eval", G + ".set('_fed_until', 9999.0)"], ["coop_signal", "host_struck"],
			["coop_wait_file", "client_struck_seen"], ["eval", "_stop_active_enemy_brain()"], ["wait", 1.0],
			["coop_signal", "host_day2_done"], ["coop_wait", "partner_gone"], ["wait", 1.0],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["coop_place", 14, 14, -1.0], ["wait", 1.5], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_night"], ["coop_wait", "night"], ["wait", 2.0], ["coop_signal", "client_night"],
			["coop_wait_file", "host_near"], ["wait", 0.8], ["babka_report", "near_here"], ["shot", "c1_near"], ["coop_signal", "client_near_seen"],
			["coop_wait_file", "host_struck"], ["wait", 0.3], ["babka_report", "struck_here"], ["shot", "c2_struck"], ["coop_signal", "client_struck_seen"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


## The radio here ever relaying her meal since the night began (the other warden's).
var _relay_seen := false
## Her hunt's beat heard on this machine (chase_music.gd through remote_fx on the other's).
var _chase_seen := false


func _process(delta: float) -> void:
	super._process(delta)
	var nfx: Node = get_tree().root.get_node_or_null("NightmareFX")
	var ch = nfx.get("_chase") if nfx != null else null
	if ch != null and ch.playing() and str(ch.get("_src")) == "basket":
		_chase_seen = true
	var im = _main.get("_interior_manager") if _main != null else null
	var bi = im.get("_building_interior") if im != null else null
	var dread = bi.get("_dread") if bi != null else null
	if dread != null and bool(dread.get("_relay_on")):
		_relay_seen = true


## Three parties let in (an Expression cannot reach the autoloads): where they lodge.
func check_in_guests() -> String:
	for party in [["Novak", "quiet_guy", 1], ["Pepa", "drunk", 2], ["Mrs Benesova", "picker", 1]]:
		GuestManager.debug_check_in_party(str(party[0]), str(party[1]), int(party[2]), 3)
	var lodged := {}
	for g in GuestManager.get_guest_life_snapshot():
		var c = g.get("lodging", Vector2i(-1, -1))
		if c is Vector2i and (c as Vector2i).x >= 0:
			lodged["%d:%d" % [c.x, c.y]] = true
	var tents := 0
	for c in _main.get("building_manager").get_node("Structures").get_children():
		if str(c.get_meta("building_type", "")).contains("tent"):
			tents += 1
	return "GUESTS lodged in %s (%d tents)" % [str(lodged.keys()), tents]


func _inside_steps() -> Array:
	if _role == "host":
		return [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			# Guests for her: three tents and three parties in them (the co-op camp has none).
			["build", "tent_1", 13, 16, 0], ["build", "tent_1", 15, 16, 0], ["build", "tent_1", 17, 16, 0], ["wait", 2.0],
			["prep_all"], ["eval", "get_tree().root.get_node('CoopBabka').check_in_guests()"],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			["eval", "time_system.set_time_hours(21.6)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 4.0],
			["coop_signal", "host_night"], ["coop_wait_file", "client_night"],
			# Both in the office: she is out and goes for the guests.
			["eval", "_interior_manager._building_interior.open_interior()"], ["coop_wait_file", "client_inside"],
			["eval", "debug_spawn_enemy('basket', 3)"], ["eval", G + ".set('soon', true)"],
			["wait", 40.0], ["babka_report", "inside_host_40"], ["wait", 35.0], ["babka_report", "inside_host"], ["coop_signal", "host_ate"],
			["coop_wait_file", "client_heard"], ["eval", "_stop_active_enemy_brain()"], ["wait", 1.0],
			["coop_signal", "host_day2_done"], ["coop_wait", "partner_gone"], ["wait", 1.0],
		]
	return [
		["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
		["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
		["coop_place", 14, 14, -1.0], ["wait", 1.5], ["coop_signal", "client_ready"],
		["coop_wait_file", "host_night"], ["coop_wait", "night"], ["wait", 2.0], ["coop_signal", "client_night"],
		["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 1.0], ["coop_signal", "client_inside"],
		["coop_wait_file", "host_ate"], ["babka_report", "inside_client"], ["coop_signal", "client_heard"],
		["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
	]


func _run_step(step: Array) -> void:
	if str(step[0]) != "babka_report":
		super._run_step(step)
		return
	var fx: Node = _main.get_tree().root.get_node_or_null("NightmareFX")
	var spores := float(fx.get("_spores")) if fx != null and fx.get("_spores") != null else -1.0
	var shown := 0
	var night = _main.get("_coop_night")
	if night != null:
		var m: Dictionary = night.get("_mirror")
		for k in m:
			var v = m[k]
			if v is Sprite3D and is_instance_valid(v) and (v as Sprite3D).visible:
				shown += 1
	var p: Node = _main.get("_player")
	var phase := ""
	var eaten := -1
	var brains: Array = _main.get("_enemy_brains")
	if not brains.is_empty() and brains.back() != null and brains.back().has_method("get_debug_snapshot"):
		var snap: Dictionary = brains.back().get_debug_snapshot()
		phase = str(snap.get("phase", ""))
		eaten = int(snap.get("eaten", -1))
	var limp := 1.0
	if p != null and p.get("held_speed_mult") != null:
		limp = float(p.get("held_speed_mult"))
	print("COOP BABKA %s: %s spores=%.2f mirror_shown=%d hp=%d limp=%.2f phase=%s eaten=%d relay_seen=%s chase_seen=%s" % [_role, str(step[1]), spores, shown,
		int(_main.get("_player_health")), limp, phase, eaten, str(_relay_seen), str(_chase_seen)])
