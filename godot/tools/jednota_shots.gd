extends "res://tools/shot_driver.gd"

## The Jednota (DESIGN.md §7b): the building in the camp, the shop and the storeroom, each
## station worked where it stands, with guests in. Debug tooling only.
##   godot --path godot res://tools/jednota_shots.tscn -- --out=<dir> [--size=1280x720]

const SI := "_interior_manager._service_interior"
const J := "get_tree().get_first_node_in_group('jednotas')"


func _st(id: String) -> String:
	return SI + "._stations['%s']" % id


func _ready() -> void:
	super._ready()
	# --size=1280x720: the window that size whatever the settings say (both resolutions).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var wh := arg.get_slice("=", 1).split("x")
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 40000], ["clear", 4, 4, 16, 12], ["build", "vecerka", 6, 6, 0],
		["build", "cabin_1", 5, 12, 0], ["build", "cabin_1", 9, 12, 0], ["build", "tent_1", 13, 12, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["prep_all"], ["book", "Kaja", "cheap_chick", 1, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["player", 7, 13, 0.0], ["wait", 2.0], ["shot", "j00_outside"],
		["eval", "debug_send_guests_to('vecerka', 240)"], ["wait", 1.0],
		["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('vecerka'))"], ["wait", 4.0],
		["eval", J + ".debug_pick_all(" + SI + "._upkeep_key)"], ["wait", 3.0],
		["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 1.0], ["shot", "j01_shop"],
		["eval", SI + "._look.set('yaw_deg', 50.0)"], ["wait", 0.6], ["shot", "j02_shop_r"],
		["eval", SI + "._look.set('yaw_deg', -50.0)"], ["wait", 0.6], ["shot", "j03_shop_l"],
		["eval", SI + "._look.set('yaw_deg', 0.0)"],
		["eval", SI + "._open_station('till')"], ["wait", 1.2], ["shot", "j04_till"],
		["eval", _st("till") + ".debug_click('item:0')"], ["wait", 0.15], ["shot", "j05_till_ring"],
		["eval", _st("till") + ".debug_click('item:1')"], ["eval", _st("till") + ".debug_click('item:2')"],
		["eval", _st("till") + ".debug_click('item:3')"], ["eval", _st("till") + ".debug_click('item:4')"], ["wait", 0.8], ["shot", "j06_till_paid"],
		["eval", _st("till") + ".debug_click('paid')"], ["eval", _st("till") + ".debug_click('c:2')"], ["eval", _st("till") + ".debug_click('c:5')"],
		["wait", 0.4], ["shot", "j07_till_change"],
		["eval", SI + "._switch_station('shelves')"], ["wait", 1.2], ["shot", "j08_shelves"],
		["eval", J + ".make_box(" + SI + "._upkeep_key, 'beer')"], ["eval", J + ".make_box(" + SI + "._upkeep_key, 'roll')"],
		["eval", J + ".make_box(" + SI + "._upkeep_key, 'milk')"], ["wait", 0.5], ["shot", "j09_shelves_trolley"],
		["eval", J + ".debug_set_shelf(" + SI + "._upkeep_key, 'milk', 2)"],
		["eval", _st("shelves") + ".debug_shelve('milk')"], ["wait", 1.0], ["shot", "j10_shelves_shelved"],
		["eval", _st("shelves") + ".close_station()"], ["wait", 0.8], ["shot", "j11_shop_marks"],
		["eval", SI + "._go_door('s_store')"], ["wait", 3.0], ["shot", "j12_store"],
		["eval", SI + "._look.set('yaw_deg', 50.0)"], ["wait", 0.6], ["shot", "j13_store_r"],
		["eval", SI + "._look.set('yaw_deg', -50.0)"], ["wait", 0.6], ["shot", "j14_store_l"],
		["eval", SI + "._look.set('yaw_deg', 0.0)"],
		["eval", SI + "._open_station('store')"], ["wait", 1.2], ["shot", "j15_store_table"],
		["eval", _st("store") + ".debug_click('carton:bread')"], ["wait", 0.6], ["shot", "j16_store_carton"],
		["eval", _st("store") + ".debug_box('salami')"], ["wait", 0.6], ["shot", "j17_store_trolley"],
		["eval", _st("store") + ".close_station()"], ["wait", 0.8],
		["eval", SI + "._go_door('st_shop')"], ["wait", 3.0], ["shot", "j18_shop_after"],
		["eval", "debug_jump_to(1, 21.6)"], ["wait", 3.0], ["shot", "j19_shop_night"],
	]
