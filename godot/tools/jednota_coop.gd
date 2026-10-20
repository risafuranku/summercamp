extends "res://tools/coop_check.gd"

## The Jednota for two (DESIGN.md §7b "The Jednota", For four): a host and a joining copy on
## this machine (run by tools/jednota_coop.py). Both go into the Jednota; the host steps up
## to the till and serves the first in the queue right: the other machine has them served
## too, sees the host at the till and is refused it. The other warden goes into the
## storeroom, makes up a box onto the trolley and shelves it in the shop: the host's
## trolley and rack have it. Then the host steps away and the other warden serves the next
## one at the till: the host has them served.
## Each side's evals are tagged ["JED <role> <tag>", ...] in its log for the runner.
##   godot --path godot res://tools/jednota_coop.tscn -- --role=host --out=DIR

const SI := "_interior_manager._service_interior"
const J := "get_tree().get_first_node_in_group('jednotas')"
const KEY := SI + "._upkeep_key"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 40000], ["clear", 4, 4, 16, 12], ["build", "vecerka", 6, 6, 0],
			["build", "cabin_1", 5, 12, 0], ["build", "cabin_1", 9, 12, 0], ["build", "tent_1", 13, 12, 0], ["build", "tent_1", 15, 12, 0], ["wait", 1.0],
			["coop_place", 8, 10, 1.0], ["coop_signal", "host_up"],
			["coop_wait_file", "client_joined"], ["wait", 2.0],
			["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
			["prep_all"], ["book", "Pepa", "drunk", 1, 3], ["prep_all"], ["book", "Kaja", "cheap_chick", 1, 3],
			["hours", 0.4], ["checkin"], ["hours", 2.0], ["wait", 3.0],
			["eval", "debug_send_guests_to('vecerka', 300)"], ["wait", 2.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('vecerka'))"], ["wait", 3.0],
			["eval", J + ".debug_pick_all(" + KEY + ")"], ["wait", 1.0],
			["coop_signal", "host_in_shop"], ["coop_wait_file", "client_in_shop"], ["wait", 2.0],
			["eval", SI + "._open_station('till')"], ["wait", 1.5],
			["eval", "['JED host tickets', " + J + ".tickets(" + KEY + ").size()]"],
			["eval", "['JED host serve', " + SI + "._stations['till'].debug_serve_right()]"], ["wait", 2.0], ["shot", "jh1_till_served"],
			["eval", "['JED host served', " + J + ".site(" + KEY + ")['served'].size(), " + J + ".tickets(" + KEY + ").size()]"],
			["coop_signal", "host_served"], ["coop_wait_file", "client_boxed"], ["wait", 2.0],
			["eval", "['JED host after_client', " + J + ".debug_counts(" + KEY + ")]"],
			["eval", SI + "._stations['till'].close_station()"], ["wait", 1.0], ["shot", "jh2_shop"],
			# A fresh queue for the other warden's turn at the till.
			["eval", "debug_send_guests_to('vecerka', 300)"], ["wait", 1.0],
			["eval", J + ".debug_pick_all(" + KEY + ")"], ["wait", 1.0],
			["eval", "['JED host queue_again', " + J + ".tickets(" + KEY + ").size()]"],
			["coop_signal", "host_left_till"], ["coop_wait_file", "client_served"], ["wait", 3.0],
			["eval", "['JED host after_till', " + J + ".site(" + KEY + ")['served'].size(), " + J + ".tickets(" + KEY + ").size()]"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 8, 10, -1.0], ["coop_signal", "client_joined"],
			["coop_wait_file", "host_in_shop"], ["wait", 1.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('vecerka'))"], ["wait", 3.0],
			["coop_signal", "client_in_shop"], ["coop_wait_file", "host_served"], ["wait", 2.0],
			["eval", "['JED client served', " + J + ".site(" + KEY + ")['served'].size(), " + J + ".tickets(" + KEY + ").size()]"],
			["eval", "['JED client taken', (" + SI + "._bistro_taken())]"],
			["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 1.0], ["shot", "jc1_host_at_till"],
			# The till is the host's: refused. The storeroom and the shelves are free.
			["eval", SI + "._open_station('till')"], ["wait", 0.5],
			["eval", "['JED client till_open', " + SI + "._station_open()]"],
			["eval", SI + "._go_door('s_store')"], ["wait", 3.0],
			["eval", SI + "._open_station('store')"], ["wait", 1.0],
			["eval", "['JED client good', " + J + ".debug_good_with_room(" + KEY + ")]"],
			["eval", "['JED client box', " + SI + "._stations['store'].debug_box(" + J + ".debug_good_with_room(" + KEY + "))]"], ["wait", 1.0], ["shot", "jc2_store"],
			["eval", SI + "._stations['store'].close_station()"], ["wait", 0.8],
			["eval", SI + "._go_door('st_shop')"], ["wait", 3.0],
			["eval", SI + "._open_station('shelves')"], ["wait", 1.0],
			["eval", "['JED client shelved', " + SI + "._stations['shelves'].debug_shelve(" + SI + "._stations['store'].last_good)]"], ["wait", 1.0], ["shot", "jc3_shelves"],
			["eval", "['JED client counts', " + J + ".debug_counts(" + KEY + ")]"],
			["eval", SI + "._stations['shelves'].close_station()"], ["wait", 0.8],
			["coop_signal", "client_boxed"], ["coop_wait_file", "host_left_till"], ["wait", 2.0],
			["eval", SI + "._open_station('till')"], ["wait", 1.5],
			["eval", "['JED client serve', " + SI + "._stations['till'].debug_serve_right()]"], ["wait", 2.0], ["shot", "jc4_till"],
			["eval", "['JED client after_till', " + J + ".site(" + KEY + ")['served'].size(), " + J + ".tickets(" + KEY + ").size()]"],
			["coop_signal", "client_served"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
