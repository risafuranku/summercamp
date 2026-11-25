extends "res://tools/coop_check.gd"

## The voice for two (scripts/coop/voice.gd, playtest 24. 11.: „když držim V, kliknutím
## přepínám jestli mluvim lokálně nebo do vysílačky, když jí mám v inventáři“): both have the
## walkie in the bag once the game for two is on; the joining warden holds V (their own voice,
## "local"), lets go; holds it and clicks (the walkie), lets go; holds it again (still the
## walkie). The host prints what it heard (its voice's receivers by "id:kind"). Each side
## tags ["VOICE <role> <tag>", what]. No microphone here (the Dummy driver): the packets that
## start and end a go are what goes over. Last the megaphone (25. 11.): the host has three PA
## poles, the joining warden talks into the megaphone and the host hears it out of the three
## horns nearest (voice "pa_players", PA_HORNS.NEAREST), each at its pole.
##   godot --path godot res://tools/voice_coop.tscn -- --role=host --out=DIR

const INVENTORY = preload("res://scripts/ui/inventory.gd")


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["coop_signal", "host_up"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			["voice_tag", "walkie"],
			["coop_signal", "host_listening"], ["coop_wait_file", "client_local_done"], ["wait", 1.0], ["voice_tag", "heard_local"],
			["coop_signal", "host_heard_local"], ["coop_wait_file", "client_radio_done"], ["wait", 1.0], ["voice_tag", "heard_radio"],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 5000], ["clear", 8, 8, 12, 8], ["build", "pa_pole", 10, 10, 0], ["build", "pa_pole", 14, 10, 0], ["build", "pa_pole", 18, 10, 0], ["build", "pa_pole", 10, 14, 0],
			["player", 13, 12, 0.0], ["wait", 1.5],
			["coop_signal", "host_poles"], ["coop_wait_file", "client_mega_on"], ["wait", 0.6], ["mega_tag", "heard_mega"],
			["coop_signal", "host_done"], ["coop_wait_file", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 4.0],
			["voice_tag", "walkie"], ["coop_signal", "client_ready"], ["coop_wait_file", "host_listening"],
			["v", true], ["wait", 0.6], ["voice_tag", "v_held"], ["v", false], ["wait", 0.4], ["voice_tag", "v_let_go"],
			["coop_signal", "client_local_done"], ["coop_wait_file", "host_heard_local"],
			["v", true], ["wait", 0.5], ["click"], ["wait", 0.5], ["voice_tag", "v_clicked"], ["v", false], ["wait", 0.4],
			["v", true], ["wait", 0.5], ["voice_tag", "v_again"], ["v", false], ["wait", 0.4],
			["coop_signal", "client_radio_done"], ["coop_wait_file", "host_poles"],
			["give_mega"], ["mega", true], ["wait", 0.4], ["coop_signal", "client_mega_on"], ["wait", 1.6], ["mega", false],
			["coop_wait_file", "host_done"],
			["coop_signal", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	match str(step[0]):
		"v":
			if bool(step[1]):
				Input.action_press("radio_talk")
			else:
				Input.action_release("radio_talk")
		"mega":
			if bool(step[1]):
				Input.action_press("megaphone_talk")
			else:
				Input.action_release("megaphone_talk")
		"give_mega":
			var bag0 = INVENTORY.find(get_tree())
			if bag0 != null:
				bag0.add_item("megaphone")
		"mega_tag":
			# The megaphone's receivers here and their horns: how many are up (-3 dB) at a horn each.
			var v2 = Coop.voice
			var out := []
			for k in (v2.get("_rx") as Dictionary):
				var rx: Dictionary = v2.get("_rx")[k]
				if not bool(rx.get("mega", false)):
					continue
				# (No microphone here: no frames, so they stand at their horns, loud, and silent.)
				var at := {}
				for p in rx.get("pa_players", []):
					if is_instance_valid(p) and (p as AudioStreamPlayer3D).volume_db > -10.0:
						at[str((p as Node3D).global_position.snapped(Vector3.ONE * 0.5))] = true
				var on := at.size()
				out.append([str(k), (rx.get("pa_players", []) as Array).size(), on])
			print("VOICE_TAG [\"VOICE %s %s\", \"%s\"]" % [_role, str(step[1]), str(out)])
		"click":
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Vector2(DisplayServer.window_get_size()) * 0.5
			Input.parse_input_event(ev)
			var up := ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
		"voice_tag":
			var v = Coop.voice
			var bag = INVENTORY.find(get_tree())
			var what := "walkie=%s sending=%s mode=%s rx=%s" % [str(bag != null and bag.has("walkie")).to_lower(), str(v.get("_sending")), str(v.get("_v_mode")), str((v.get("_rx") as Dictionary).keys())]
			print("VOICE_TAG [\"VOICE %s %s\", \"%s\"]" % [_role, str(step[1]), what])
		_:
			super._run_step(step)
