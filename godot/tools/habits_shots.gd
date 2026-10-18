extends "res://tools/shot_driver.gd"

## The cigarette and the bottle (scripts/town/pockets.gd, scripts/habits/): every stage
## driven by the real keys, outdoors by day and night and in a room.
##   godot --path godot --resolution 1280x720 res://tools/habits_shots.tscn -- --out=<dir>

const P := "_interior_manager.town_trip().pockets"


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, 10.5)"], ["wait", 1.5],
		["eval", "_interior_manager.town_trip().inventory.add_item('cigs')"],
		["eval", "_interior_manager.town_trip().inventory.add_item('beer')"],
		["eval", "_interior_manager.town_trip().inventory.add_item('beer')"],
		["eval", P + ".cig.set('debug_catch', true)"],
		["shot", "h00_day"],
		["key", "C"], ["wait", 0.35], ["shot", "h01_pack"],
		["wait", 1.0], ["shot", "h02_lighter"],
		["keyhold", "C", true], ["wait", 0.25], ["shot", "h03_flame"],
		["wait", 1.1], ["keyhold", "C", false], ["wait", 0.1], ["shot", "h04_lit"],
		["wait", 0.9], ["shot", "h05_hold"],
		["keyhold", "C", true], ["wait", 0.9], ["shot", "h06_drag"],
		["keyhold", "C", false], ["wait", 0.25], ["shot", "h07_exhale"], ["wait", 0.7], ["shot", "h08_smoke"],
		["eval", P + ".cig.set('ash', 0.25)"], ["wait", 0.3], ["shot", "h09_ash"],
		["key", "B"], ["wait", 0.8], ["shot", "h10_bottle"],
		["keyhold", "B", true], ["wait", 0.4], ["shot", "h11_opening"], ["wait", 1.3], ["keyhold", "B", false], ["wait", 0.2], ["shot", "h12_open"],
		["keyhold", "B", true], ["wait", 0.9], ["shot", "h13_drink"], ["keyhold", "B", false], ["wait", 0.5],
		["eval", P + ".world.get('_hands')"],
		["eval", "get_tree().get_first_node_in_group('hands').get('light')"],
		["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 0.25], ["shot", "h14_thrown_butt"],
		["wait", 0.8], ["shot", "h15_butt_landed"],
		# Night: the torch, the bottle (torch to the left hand, the cigarette in the mouth).
		["eval", "debug_jump_to(1, 22.5)"], ["wait", 2.5],
		["eval", "get_tree().get_first_node_in_group('hands').get('light')"], ["shot", "h20_night_bottle"],
		# Work in the right hand: the torch goes to the left one, and back after.
		["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 1.5], ["shot", "h16_night_torch"],
		["eval", "_hud_manager.set_work_progress('BAGGING rubbish', 0.4)"], ["wait", 0.5], ["shot", "h17_work_switch"],
		["wait", 1.2], ["shot", "h18_work_bag_torch_left"],
		["eval", "_hud_manager.clear_work_progress()"], ["wait", 1.6], ["shot", "h19_torch_back"],
		["key", "B"], ["wait", 1.6], ["shot", "h19b_bottle_torch_left"],
		["eval", P + ".debug_rects()"], ["eval", P + "._can_act()"], ["eval", P + "._blocked()"], ["eval", P + ".allowed.call()"], ["eval", "_interior_manager.town_trip().inventory.items"],
		["key", "C"], ["wait", 2.0], ["keyhold", "C", true], ["wait", 1.3], ["keyhold", "C", false], ["wait", 1.2], ["shot", "h21_night_cig_mouth"],
		["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 1.0],
		["shot", "h22_night_torch_left"],
		["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 1.2], ["shot", "h23_night_torch_back"],
		["key", "C"], ["wait", 1.6], ["keyhold", "C", true], ["wait", 0.3], ["shot", "h24_night_flame"], ["wait", 1.0], ["keyhold", "C", false], ["wait", 1.2], ["shot", "h25_night_hold"],
	]
