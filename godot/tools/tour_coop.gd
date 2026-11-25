extends "res://tools/coop_check.gd"

## The week's tour for two (email_manager.offer_tour, 25. 11.): the host's camp with beds sends
## the travel agency's letter; it is in the other machine's CampMail too, that warden accepts it
## there (the booking made in the host's camp), the party is in both machines' books coming on
## the 380, and when its run is in, at the barrier on both.
## Tagged "TOUR_TAG [tag, tour letters in the inbox, the party's size, status, arrival]" for
## tools/tour_coop.py.
##   godot --path godot res://tools/tour_coop.tscn -- --role=host --out=DIR


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["money", 60000], ["clear", 4, 4, 18, 12],
			["build", "cabin_1", 5, 5, 0], ["build", "cabin_1", 8, 5, 0], ["build", "cabin_1", 11, 5, 0], ["build", "cabin_1", 14, 5, 0],
			["build", "cabin_1", 5, 9, 0], ["build", "cabin_1", 8, 9, 0], ["build", "cabin_1", 11, 9, 0], ["build", "cabin_1", 14, 9, 0],
			["wait", 1.0], ["prep_all"], ["eval", "debug_jump_to(3, 10.0)"], ["wait", 0.5],
			["eval", "time_system.set('game_hours_per_real_second', 0.0)"],
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 2.0],
			["eval", "_week_offers.send('tour', _day_index, int(_time_of_day_hours))"],
			["eval", "get_node('/root/EmailManager')._deliver_due_mails(9999999)"], ["wait", 3.0], ["tour_tag", "host_mail"],
			["coop_signal", "host_mail"], ["coop_wait_file", "client_accepted"], ["wait", 3.0], ["tour_tag", "host_booked"],
			["eval", "debug_jump_to(3, 13.6)"], ["eval", "time_system.set('game_hours_per_real_second', 0.02)"], ["wait", 4.0], ["tour_tag", "host_gate"],
			["coop_signal", "host_gate"], ["coop_wait_file", "client_ended"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["coop_signal", "client_in"],
			["coop_wait_file", "host_mail"], ["wait", 3.0], ["tour_tag", "client_mail"],
			["mail_accept", "by_bus", true], ["wait", 3.0], ["tour_tag", "client_booked"], ["coop_signal", "client_accepted"],
			["coop_wait_file", "host_gate"], ["wait", 3.0], ["tour_tag", "client_gate"],
			["coop_signal", "client_ended"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	if str(step[0]) == "tour_tag":
		var letters := 0
		for m in EmailManager.inbox:
			if bool((m as Dictionary).get("by_bus", false)):
				letters += 1
		var party := {}
		for g in CoreRoot.get_state().guests:
			if g is Dictionary and int(g.get("party_size", 0)) >= 8:
				party = g
		print("TOUR_TAG %s" % JSON.stringify([str(step[1]), letters, int(party.get("party_size", 0)), str(party.get("status", "")), int(party.get("arrival_abs", -1))]))
		return
	super._run_step(step)
