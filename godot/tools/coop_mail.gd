extends "res://tools/coop_check.gd"

## Mail in a camp hosted from a save (playtest 14. 11., co-op): a warden's single-player
## sandbox camp, saved on day 2, then hosted for two (_on_menu_coop_host_saved) and
## joined. The host's clock runs on: the bookings must keep coming on both machines.
## Each prints ["MAIL <role> <tag>", day, hour, inbox, scheduled, beds free] for
## tools/coop_mail.py.
##   godot --path godot res://tools/coop_mail.tscn -- --role=host --out=DIR

const EM := "get_node('/root/EmailManager')"


func _see(tag: String) -> Array:
	return ["mail_see", tag]


func _ready() -> void:
	super._ready()
	var save := OS.get_environment("COOP_MAIL_SAVE")
	if _role == "host" and save != "":
		# A warden's own save (a copy in this copy's APPDATA): hosted as it is.
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0],
			["eval", "_on_menu_coop_host_saved('%s')" % save], ["wait_gameplay"], ["wait", 1.5],
			["eval", "_interior_manager._building_interior.close_interior()"], _see("solo"), _see("hosted"),
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 2.0], _see("joined"),
			["eval", "time_system.set('game_hours_per_real_second', 0.4)"],
		]
		for i in 14:
			_steps.append_array([["wait", 6.0], _see("run%d" % (i + 1))])
		_steps.append_array([_see("run2"), ["coop_signal", "host_done"], ["coop_wait_file", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"]])
	elif _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0],
			["call", "_on_menu_new_camp", ["Mail", 4242, false, true, {}]], ["wait_gameplay"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["money", 9000],
			["clear", 7, 3, 7, 5], ["build", "tent_1", 8, 5, 0], ["build", "tent_1", 10, 5, 0], ["build", "cabin_1", 12, 5, 0], ["prep_all"], ["wait", 0.5],
			["eval", "time_system.set('game_hours_per_real_second', 0.5)"], ["wait", 24.0], _see("solo"),
			["call", "request_manual_save", ["check"]], ["wait", 0.5],
			["call", "_enter_main_menu", []], ["wait_menu"], ["wait", 1.0],
			["eval", "_on_menu_coop_host_saved(get_node('/root/SaveManager').get_latest_save_path())"], ["wait_gameplay"], ["wait", 1.5],
			["eval", "_interior_manager._building_interior.close_interior()"], _see("hosted"),
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 2.0], _see("joined"),
			["eval", "time_system.set('game_hours_per_real_second', 0.5)"], ["wait", 15.0], _see("run1"), ["wait", 15.0], _see("run2"),
			["coop_signal", "host_done"], ["coop_wait_file", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior.close_interior()"], _see("joined"),
			["coop_signal", "client_in"], ["coop_wait_file", "host_done"], ["wait", 1.0], _see("end"),
			["coop_signal", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	if str(step[0]) != "mail_see":
		super._run_step(step)
		return
	var em = get_node("/root/EmailManager")
	var beds: Dictionary = get_node("/root/GuestManager").get_bed_metrics()
	print("MAIL_TAG [\"MAIL %s %s\", %d, %.2f, %d, %d, %d, %d, \"%s\"]" % [_role, str(step[1]), CoreRoot.get_day(), float(_main.get("_time_of_day_hours")), em.inbox.size(), em._scheduled_mails.size(), int(beds.get("free", 0)), CoreRoot.get_money(), em._last_hourly_roll_signature])
