extends "res://tools/shot_driver.gd"

## The bistro (DESIGN.md §7b): the dining room, the kitchen, the cellar, each station full
## screen and worked a little, with guests in. Debug tooling only.
##   godot --path godot --resolution 1280x720 res://tools/bistro_shots.tscn -- --out=<dir>

const SI := "_interior_manager._service_interior"
const KS := "get_tree().get_first_node_in_group('kitchens')"


func _st(id: String) -> String:
	return SI + "._stations['%s']" % id


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 40000], ["clear", 5, 5, 15, 10], ["build", "restaurant", 6, 6, 0],
		["build", "cabin_1", 6, 11, 0], ["build", "cabin_1", 9, 11, 0], ["build", "tent_1", 12, 11, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["eval", "debug_send_guests_to('restaurant', 240)"], ["wait", 1.0],
		["player", 7, 9, 180.0], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('restaurant'))"], ["wait", 4.0],
		["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 1.0], ["shot", "b01_dining"],
		["eval", SI + "._look.set('yaw_deg', 50.0)"], ["wait", 0.6], ["shot", "b02_dining_r"],
		["eval", SI + "._look.set('yaw_deg', -50.0)"], ["wait", 0.6], ["shot", "b03_dining_l"],
		["eval", SI + "._look.set('yaw_deg', 0.0)"],
		["eval", KS + ".tickets(" + SI + "._upkeep_key).size()"],
		["eval", SI + "._go_door('d_kitchen')"], ["wait", 3.0], ["shot", "b04_kitchen"],
		["eval", SI + "._look.set('yaw_deg', 50.0)"], ["wait", 0.6], ["shot", "b05_kitchen_r"],
		["eval", SI + "._look.set('yaw_deg', -50.0)"], ["wait", 0.6], ["shot", "b06_kitchen_l"],
		["eval", SI + "._look.set('yaw_deg', 0.0)"],
		# Trays filled as if the cellar had been worked.
		["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['cheese_raw', 4])"],
		["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['chips_raw', 6])"],
		["eval", SI + "._open_station('stove')"], ["wait", 1.0],
		["eval", _st("stove") + "._press('tray')"], ["eval", _st("stove") + "._press('tray')"], ["eval", _st("stove") + "._press('bucket')"], ["eval", _st("stove") + "._press('basket')"],
		["wait", 3.5], ["shot", "b07_stove"],
		["eval", _st("stove") + "._press('slot:0')"], ["wait", 7.0], ["shot", "b08_stove_later"],
		["eval", _st("stove") + "._press('slot:0')"], ["eval", _st("stove") + "._press('slot:1')"], ["eval", _st("stove") + "._press('basket')"], ["wait", 0.5], ["shot", "b09_stove_done"],
		["eval", _st("stove") + ".switch_to.emit('pot')"], ["wait", 1.0],
		["eval", _st("pot") + "._press('steamer')"], ["eval", _st("pot") + "._press('loaf')"], ["eval", _st("pot") + "._press('loaf')"], ["wait", 0.3], ["shot", "b10_pot"],
		["eval", _st("pot") + ".switch_to.emit('pass')"], ["wait", 1.0], ["shot", "b11_pass"],
		["eval", _st("pass") + "._press('stack')"], ["eval", _st("pass") + "._press('cheese')"], ["eval", _st("pass") + "._press('fries')"], ["eval", _st("pass") + "._press('tartar')"],
		["wait", 0.4], ["shot", "b12_pass_plate"],
		["eval", _st("pass") + "._press('bell')"], ["wait", 0.2], ["shot", "b13_pass_bell"], ["wait", 1.0], ["shot", "b14_pass_after"],
		["eval", _st("pass") + ".switch_to.emit('sink')"], ["wait", 1.0],
		["eval", KS + ".act(" + SI + "._upkeep_key, 'plates', [0, 3])"],
		["eval", _st("sink") + "._press('pile')"], ["wait", 0.3], ["shot", "b15_sink"],
		["eval", _st("sink") + ".close_view()"], ["wait", 0.8], ["shot", "b16_kitchen_marks"],
		["eval", SI + "._go_door('k_cellar')"], ["wait", 3.0], ["shot", "b17_cellar"],
		["eval", SI + "._look.set('yaw_deg', 50.0)"], ["wait", 0.6], ["shot", "b18_cellar_r"],
		["eval", SI + "._look.set('yaw_deg', -50.0)"], ["wait", 0.6], ["shot", "b19_cellar_l"],
		["eval", SI + "._look.set('yaw_deg', 0.0)"],
		["eval", SI + "._open_station('potatoes')"], ["wait", 1.0],
		["eval", _st("potatoes") + "._press('sack')"], ["eval", _st("potatoes") + "._press('switch')"], ["wait", 2.0], ["shot", "b20_potatoes"],
		["eval", _st("potatoes") + ".switch_to.emit('breading')"], ["wait", 1.0],
		["eval", _st("breading") + "._press('block')"], ["eval", _st("breading") + "._press('bowl:0')"], ["wait", 0.2], ["shot", "b21_breading"],
		["eval", _st("breading") + ".close_view()"], ["wait", 0.6],
		["eval", SI + "._open_station('machine')"], ["wait", 1.0], ["shot", "b22_machine"],
		["eval", _st("machine") + ".close_view()"], ["wait", 0.6],
		["eval", SI + "._go_door('c_kitchen')"], ["wait", 3.0],
		["eval", SI + "._go_door('k_dining')"], ["wait", 3.0], ["shot", "b23_dining_after"],
		["eval", "debug_jump_to(1, 21.6)"], ["wait", 3.0], ["shot", "b24_dining_night"],
	]
