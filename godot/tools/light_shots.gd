extends "res://tools/shot_driver.gd"

## The world's light (scripts/retro_materials.gd): the same few views by day, at dusk,
## at night under lamp posts and with the torch, and in a cabin, to compare looks.
##   godot --path godot --resolution 1280x720 res://tools/light_shots.tscn -- --out=<dir>


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["money", 90000], ["clear", 10, 10, 9, 9], ["wait", 0.5],
		["build", "path", 12, 11, 0], ["build", "path", 12, 12, 0], ["build", "path", 12, 13, 0], ["build", "path", 12, 14, 0], ["build", "path", 12, 15, 0],
		["build", "lamp_post", 12, 12, 0], ["build", "lamp_post", 12, 15, 0],
		["build", "tent_1", 14, 12, 0], ["build", "cabin_1", 14, 15, 0], ["build", "bonfire", 10, 13, 0], ["wait", 1.5],
		["player", 12, 18, 180.0], ["eval", "debug_jump_to(1, 11.0)"], ["wait", 3.0], ["shot", "l1_day"],
		["eval", "debug_jump_to(1, 19.4)"], ["wait", 4.0], ["shot", "l2_dusk"],
		["eval", "debug_jump_to(1, 22.6)"], ["wait", 4.0], ["shot", "l3_night_lamps"],
		["player", 13, 13, 90.0], ["wait", 1.5], ["shot", "l4_night_torch_tent"],
		["player", 12, 16, 180.0], ["wait", 1.5], ["shot", "l5_night_under_lamp"],
		["prep_all"], ["open_room", 14, 15], ["wait", 2.0], ["shot", "l6_cabin_night"],
	]
