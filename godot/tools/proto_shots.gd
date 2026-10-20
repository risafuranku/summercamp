extends "res://tools/shot_driver.gd"

## PROTOTYP 540 in the bistro's cellar (DESIGN.md §7b "The bistro"): awake at night with a
## sack in front of it, the sack lifted in, the machine running, the tray in the morning.
## Debug tooling only.
##   godot --path godot res://tools/proto_shots.tscn -- --out=<dir> [--size=1280x720]

const SI := "_interior_manager._service_interior"
const KS := "get_tree().get_first_node_in_group('kitchens')"


func _st(id: String) -> String:
	return SI + "._stations['%s']" % id


func _ready() -> void:
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var wh := arg.get_slice("=", 1).split("x")
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 40000], ["clear", 5, 5, 15, 10], ["build", "restaurant", 6, 6, 0],
		["build", "cabin_1", 6, 11, 0], ["wait", 1.0],
		["player", 7, 9, 180.0], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('restaurant'))"], ["wait", 4.0],
		["eval", SI + "._go_door('d_kitchen')"], ["wait", 3.0],
		["eval", SI + "._go_door('k_cellar')"], ["wait", 3.0],
		["eval", "debug_jump_to(2, 22.5)"], ["wait", 3.0],
		["eval", KS + ".debug_proto_sack(" + SI + "._upkeep_key)"], ["wait", 1.0],
		["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 1.0],
		["eval", SI + "._look.set('yaw_deg', -40.0)"], ["wait", 0.8], ["shot", "x01_cellar_night"],
		["eval", SI + "._look.set('yaw_deg', 0.0)"],
		["eval", SI + "._open_station('machine')"], ["wait", 1.2], ["shot", "x02_machine_sack"],
		["eval", _st("machine") + "._press('sack')"], ["eval", _st("machine") + ".set('_lift', 0.8)"], ["wait", 0.2], ["shot", "x03_lifting"],
		["eval", _st("machine") + ".debug_feed()"], ["eval", _st("machine") + "._tick(2.0)"], ["wait", 1.5], ["shot", "x04_running"],
		["eval", _st("machine") + ".close_station()"], ["wait", 1.0], ["shot", "x05_cellar_running"],
		["eval", "debug_jump_to(3, 7.5)"], ["wait", 4.0],
		["eval", SI + "._open_station('machine')"], ["wait", 1.2], ["shot", "x06_machine_morning"],
		["eval", _st("machine") + "._press('tray')"], ["wait", 0.3], ["shot", "x07_tray"],
	]
