extends "res://tools/shot_driver.gd"

## The camp's look through a day (24. 11., the environment pass: "totálně nejlepší
## environment"): one view over the camp toward the lake, from dawn to night, then fog, rain
## and the storm at noon, to compare the light, the sky, the fog and the palette.
##   godot --path godot --resolution 1280x720 res://tools/env_shots.tscn -- --out=<dir>


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["money", 90000], ["clear", 10, 10, 9, 9], ["wait", 0.5],
		["build", "path", 12, 11, 0], ["build", "path", 12, 12, 0], ["build", "path", 12, 13, 0], ["build", "path", 12, 14, 0],
		["build", "lamp_post", 12, 12, 0], ["build", "tent_1", 14, 12, 0], ["build", "cabin_1", 14, 15, 0], ["build", "bonfire", 10, 13, 0],
		["eval", "weather_system.set_auto_cycle_enabled(false)"], ["eval", "weather_system.set_weather(0)"], ["wait", 1.5],
		["player", 12, 18, 180.0],
		["eval", "debug_jump_to(1, 6.2)"], ["wait", 4.0], ["shot", "e1_dawn"],
		["eval", "debug_jump_to(1, 9.0)"], ["wait", 4.0], ["shot", "e2_morning"],
		["eval", "debug_jump_to(1, 13.0)"], ["wait", 4.0], ["shot", "e3_noon"],
		["eval", "debug_jump_to(1, 17.5)"], ["wait", 4.0], ["shot", "e4_afternoon"],
		["eval", "debug_jump_to(1, 19.0)"], ["wait", 4.0], ["shot", "e5_golden"],
		["eval", "debug_jump_to(1, 20.2)"], ["wait", 4.0], ["shot", "e6_dusk"],
		["eval", "debug_jump_to(1, 23.0)"], ["wait", 4.0], ["shot", "e7_night"],
		["eval", "debug_jump_to(2, 13.0)"], ["eval", "weather_system.set_weather(2)"], ["wait", 75.0], ["shot", "e8_fog"],
		["eval", "weather_system.set_weather(4)"], ["wait", 75.0], ["shot", "e9_rain"],
	]
	# --part=twilight: only the dawn and the dusk, half an hour apart.
	if OS.get_cmdline_user_args().has("--part=twilight"):
		var cut: Array = _steps.slice(0, 21)
		for hh in [5.4, 5.9, 6.2, 6.5, 18.9, 19.15, 19.5, 20.1]:
			cut.append(["eval", "debug_jump_to(1, %.2f)" % hh])
			cut.append(["wait", 4.0])
			cut.append(["shot", "t_%04d" % int(hh * 100.0)])
		_steps = cut
