extends "res://tools/coop_check.gd"

## The corn stand for two (DESIGN.md §7b "The corn stand", For four): a host and a joining
## copy on this machine (run by tools/stand_coop.py). The host steps behind the stand (the
## counter), puts a husked cob in the pot, boils it, dresses it and hands it over: the
## other machine has it served too. The other warden comes behind the stand: the counter
## is the host's (they get the husking instead), they husk a cob into the bowl: the host's
## bowl has it.
## Each side's evals are tagged ["STAND <role> <tag>", ...] in its log for the runner.
##   godot --path godot res://tools/stand_coop.tscn -- --role=host --out=DIR

const SV := "_interior_manager._corn_stand"
const CS := "get_tree().get_first_node_in_group('cornstands')"
const KEY := SV + ".building_key"
const STRUCT := "debug_structure_of_type('corn_stand')"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 40000], ["clear", 5, 5, 15, 12], ["build", "corn_stand", 11, 11, 0],
			["build", "cabin_1", 6, 8, 0], ["build", "cabin_1", 9, 8, 0], ["wait", 1.0],
			["coop_place", 8, 9, 1.0], ["coop_signal", "host_up"],
			["coop_wait_file", "client_joined"], ["wait", 2.0],
			["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
			["hours", 0.4], ["checkin"], ["hours", 2.0], ["wait", 5.0],
			["eval", "debug_send_guests_to('corn_stand', 300)"], ["wait", 2.0],
			["eval", "debug_send_guests_to('corn_stand', 300)"], ["wait", 4.0],
			["eval", "_interior_manager._on_corn_stand_interact(" + STRUCT + ")"], ["wait", 2.0],
			["coop_signal", "host_at_stand"], ["coop_wait_file", "client_at_stand"], ["wait", 2.0],
			["eval", CS + ".act(" + KEY + ", 'husked', [1])"],
			["eval", SV + "._stations['counter'].debug_click('pot')"],
			["eval", CS + ".debug_boil(" + KEY + ", 10.0)"],
			["eval", SV + "._stations['counter'].debug_take_first()"],
			["eval", SV + "._stations['counter'].debug_dress_right()"],
			["eval", "['STAND host tickets', " + CS + ".tickets(" + KEY + ").size()]"],
			["eval", SV + "._stations['counter'].debug_click('hand')"], ["wait", 2.0], ["shot", "sh1_served"],
			["eval", "['STAND host served', " + CS + ".site(" + KEY + ")['served'].size(), " + CS + ".tickets(" + KEY + ").size()]"],
			["coop_signal", "host_served"], ["coop_wait_file", "client_done"], ["wait", 2.0],
			["eval", "['STAND host after_client', " + CS + ".bowl(" + KEY + ")]"],
			["eval", SV + ".close_view()"], ["wait", 1.0], ["shot", "sh2_out"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 8, 9, -1.0], ["coop_signal", "client_joined"],
			["coop_wait_file", "host_at_stand"], ["wait", 2.0],
			["eval", "_interior_manager._on_corn_stand_interact(" + STRUCT + ")"], ["wait", 2.0],
			["eval", "['STAND client taken', (" + SV + "._taken())]"],
			["eval", "['STAND client open', " + SV + "._station_open()]"],
			["coop_signal", "client_at_stand"], ["coop_wait_file", "host_served"], ["wait", 2.0],
			["eval", "['STAND client served', " + CS + ".site(" + KEY + ")['served'].size(), " + CS + ".tickets(" + KEY + ").size()]"],
			["eval", SV + "._stations['husk'].debug_click('crate')"],
			["eval", SV + "._stations['husk'].debug_husk()"],
			["eval", SV + "._stations['husk'].debug_click('cob')"], ["wait", 1.0], ["shot", "sc1_husk"],
			["eval", "['STAND client bowl', " + CS + ".bowl(" + KEY + ")]"],
			["coop_signal", "client_done"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
