extends "res://tools/coop_check.gd"

## The bistro for two (DESIGN.md §7b "The bistro", For four): a host and a joining copy
## on this machine (run by tools/bistro_coop.py). Both go into the bistro's kitchen; the
## host puts two slices in the pan: the other machine's pan has them too, and the host
## stands at the stove there; the stove is the host's while they are at it (the other's
## click is refused). The other warden fries a slice and tops up the pot: the host's
## kitchen has it. A plate rung out at the host's pass lands on both machines (the
## ticket gone, the plate on the table). Each side's evals of its kitchen are tagged
## ["BISTRO <role> <tag>", ...] in its log for the runner to compare.
##   godot --path godot res://tools/bistro_coop.tscn -- --role=host --out=DIR

const SI := "_interior_manager._service_interior"
const KS := "get_tree().get_first_node_in_group('kitchens')"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 40000], ["clear", 5, 5, 15, 10], ["build", "restaurant", 6, 6, 0],
			["build", "cabin_1", 6, 11, 0], ["build", "cabin_1", 9, 11, 0], ["wait", 1.0],
			["coop_place", 8, 9, 1.0], ["coop_signal", "host_up"],
			["coop_wait_file", "client_joined"], ["wait", 2.0],
			["prep_all"], ["book", "Novak family", "family", 3, 3], ["prep_all"], ["book", "Pepa", "drunk", 1, 3],
			["hours", 0.4], ["checkin"], ["hours", 2.0], ["wait", 3.0],
			["eval", "debug_send_guests_to('restaurant', 300)"], ["wait", 4.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('restaurant'))"], ["wait", 3.0],
			["eval", SI + "._go_door('d_kitchen')"], ["wait", 3.0],
			["coop_signal", "host_in_kitchen"], ["coop_wait_file", "client_in_kitchen"], ["wait", 2.0],
			["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['cheese_raw', 3])"],
			["eval", SI + "._open_station('stove')"], ["wait", 1.0],
			["eval", SI + "._stations['stove'].debug_lay()"], ["eval", SI + "._stations['stove'].debug_lay()"], ["wait", 2.0],
			["eval", "['BISTRO host cooking', (" + KS + ".site(" + SI + "._upkeep_key)['pan'])]"],
			["coop_signal", "host_cooking"], ["coop_wait_file", "client_cooked"], ["wait", 2.0],
			["eval", "['BISTRO host after_client', (" + KS + ".site(" + SI + "._upkeep_key)['prep']), " + KS + ".site(" + SI + "._upkeep_key)['pot']['level']]"],
			# A plate out of the hatch: the first ticket, built right.
			["eval", SI + "._stations['stove'].close_station()"], ["wait", 0.5],
			["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['cheese', 2])"],
			["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['fries', 2])"],
			["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['dumpling', 8])"],
			["eval", SI + "._open_station('pass')"], ["wait", 1.0],
			["eval", "['BISTRO host tickets', " + KS + ".tickets(" + SI + "._upkeep_key).size()]"],
			["eval", SI + "._stations['pass'].debug_build_picked()"], ["wait", 0.3],
			["eval", SI + "._stations['pass'].debug_click('bell')"], ["wait", 1.0],
			# The bell puts it on the hatch; the floor takes it to the table (the brief of 21. 10.).
			["eval", SI + "._stations['floor'].debug_serve_first()"], ["wait", 2.0], ["shot", "bh1_pass_served"],
			["eval", "['BISTRO host served', " + KS + ".site(" + SI + "._upkeep_key)['served'].size(), " + KS + ".tickets(" + SI + "._upkeep_key).size()]"],
			["coop_signal", "host_served"], ["coop_wait_file", "client_done"], ["wait", 1.0],
			["eval", SI + "._stations['pass'].close_station()"], ["wait", 0.5], ["shot", "bh2_kitchen"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 8, 9, -1.0], ["coop_signal", "client_joined"],
			["coop_wait_file", "host_in_kitchen"], ["wait", 1.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('restaurant'))"], ["wait", 3.0],
			["eval", SI + "._go_door('d_kitchen')"], ["wait", 3.0],
			["coop_signal", "client_in_kitchen"], ["coop_wait_file", "host_cooking"], ["wait", 2.0],
			["eval", "['BISTRO client cooking', (" + KS + ".site(" + SI + "._upkeep_key)['pan'])]"],
			["eval", "['BISTRO client taken', (" + SI + "._bistro_taken())]"],
			["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 1.0], ["shot", "bc1_host_at_stove"],
			# The stove is the host's: refused. The pot is free.
			["eval", SI + "._open_station('stove')"], ["wait", 0.5],
			["eval", "['BISTRO client stove_open', " + SI + "._station_open()]"],
			["eval", SI + "._open_station('pot')"], ["wait", 1.0],
			["eval", SI + "._stations['pot'].debug_click('tins')"], ["wait", 0.5],
			["eval", "['BISTRO client pot', " + KS + ".site(" + SI + "._upkeep_key)['pot']['level']]"],
			["eval", SI + "._stations['pot'].close_station()"], ["wait", 0.5],
			["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['chips_raw', 2])"], ["wait", 1.0],
			["coop_signal", "client_cooked"], ["coop_wait_file", "host_served"], ["wait", 2.0],
			["eval", "['BISTRO client served', " + KS + ".site(" + SI + "._upkeep_key)['served'].size(), " + KS + ".tickets(" + SI + "._upkeep_key).size()]"],
			["eval", SI + "._go_door('k_dining')"], ["wait", 3.0], ["shot", "bc2_dining_plate"],
			["coop_signal", "client_done"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
