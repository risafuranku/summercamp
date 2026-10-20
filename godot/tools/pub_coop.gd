extends "res://tools/coop_check.gd"

## The pub for two (DESIGN.md §7b "the pub", For four): a host and a joining copy on this
## machine (run by tools/pub_coop.py). Both go into the pub; the host steps up to the tap,
## pours a beer right and serves it: the other machine has it served too, sees the host
## at the tap and is refused it. The other warden washes a mug at the sink and goes down
## to take the head off the keg: the host's bar has the clean mug and the tap is off.
## Each side's evals are tagged ["PUB <role> <tag>", ...] in its log for the runner.
##   godot --path godot res://tools/pub_coop.tscn -- --role=host --out=DIR

const SI := "_interior_manager._service_interior"
const TR := "get_tree().get_first_node_in_group('taprooms')"
const KEY := SI + "._upkeep_key"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 40000], ["clear", 5, 5, 15, 10], ["build", "pub", 6, 6, 0],
			["build", "cabin_1", 6, 11, 0], ["build", "cabin_1", 9, 11, 0], ["wait", 1.0],
			["coop_place", 8, 9, 1.0], ["coop_signal", "host_up"],
			["coop_wait_file", "client_joined"], ["wait", 2.0],
			["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Tramp", "tramp", 1, 3],
			["hours", 0.4], ["checkin"], ["hours", 2.0], ["wait", 3.0],
			["eval", "debug_send_guests_to('pub', 300)"], ["wait", 4.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 3.0],
			["coop_signal", "host_in_pub"], ["coop_wait_file", "client_in_pub"], ["wait", 2.0],
			["eval", SI + "._open_station('tap')"], ["wait", 1.5],
			["eval", "['PUB host tickets', " + TR + ".tickets(" + KEY + ").size()]"],
			["eval", SI + "._stations['tap'].debug_pour_right()"], ["wait", 0.3],
			["eval", SI + "._stations['tap'].debug_click('mug')"], ["wait", 2.0], ["shot", "ph1_tap_served"],
			["eval", "['PUB host served', " + TR + ".site(" + KEY + ")['served'].size(), " + TR + ".tickets(" + KEY + ").size()]"],
			["coop_signal", "host_poured"], ["coop_wait_file", "client_done"], ["wait", 2.0],
			["eval", "['PUB host after_client', " + TR + ".mugs(" + KEY + ")['clean'], " + TR + ".keg(" + KEY + ")['coupled']]"],
			["eval", SI + "._stations['tap'].close_station()"], ["wait", 0.8], ["shot", "ph2_bar"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 8, 9, -1.0], ["coop_signal", "client_joined"],
			["coop_wait_file", "host_in_pub"], ["wait", 1.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 3.0],
			["coop_signal", "client_in_pub"], ["coop_wait_file", "host_poured"], ["wait", 2.0],
			["eval", "['PUB client served', " + TR + ".site(" + KEY + ")['served'].size(), " + TR + ".tickets(" + KEY + ").size()]"],
			["eval", "['PUB client taken', (" + SI + "._bistro_taken())]"],
			["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 1.0], ["shot", "pc1_host_at_tap"],
			# The tap is the host's: refused. The sink is free.
			["eval", SI + "._open_station('tap')"], ["wait", 0.5],
			["eval", "['PUB client tap_open', " + SI + "._station_open()]"],
			["eval", SI + "._open_station('wash')"], ["wait", 1.0],
			["eval", TR + ".act(" + KEY + ", 'mugs', [0, 2])"], ["wait", 0.5],
			["eval", SI + "._stations['wash'].debug_wash_one()"], ["wait", 0.5],
			["eval", "['PUB client mugs', " + TR + ".mugs(" + KEY + ")['clean']]"], ["shot", "pc2_wash"],
			["eval", SI + "._stations['wash'].close_station()"], ["wait", 0.8],
			["eval", SI + "._go_door('p_cellar')"], ["wait", 3.0],
			["eval", SI + "._open_station('keg')"], ["wait", 1.0],
			["eval", SI + "._stations['keg'].debug_click('coupler')"], ["wait", 1.0], ["shot", "pc3_keg_off"],
			["eval", "['PUB client keg', " + TR + ".keg(" + KEY + ")['coupled']]"],
			["coop_signal", "client_done"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
