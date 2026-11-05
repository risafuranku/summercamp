extends "res://tools/onesun_check.gd"

## The playtest of 5. 11., afternoon (TODO Y1-Y24): each point reproduced and checked in the
## game. --y=<part>. Lines "Y ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/y_check.tscn -- --out=DIR --y=builder

const UI := "_interior_manager._building_interior._crt_ui"
const MAP := "debug_builder_map()"
const BI := "_interior_manager._building_interior"
const BOOT: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0]]


func say(text: String) -> void:
	print("Y ", text)


func _ready() -> void:
	super._ready()
	var y := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--y="):
			y = str(a).substr(4)
	match y:
		"builder":
			_steps = _builder()
		"pc":
			_steps = _pc()
		"torch":
			_steps = _torch()
		"trees":
			_steps = _trees()


## R turns what you are about to build, with the pointer anywhere (Y14).
func _builder() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "debug_jump_to(1, 11.0)"], ["money", 90000],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", UI + ".open_app('builder') != null"], ["wait", 4.5],
		["eval", "debug_close_msgboxes()"], ["wait", 0.5],
		["eval", MAP + ".set_selected_building('cabin_1')"], ["wait", 0.5], ["eval", "['Y rot before', " + MAP + "._rotation_steps]"],
		["key", "R"], ["wait", 0.4], ["eval", "['Y rot after R', " + MAP + "._rotation_steps]"],
		["key", "R"], ["wait", 0.4], ["eval", "['Y rot after R R', " + MAP + "._rotation_steps]"],
		["crt_screen", "builder_r"], ["eval", "get_tree().quit()"]]
	return s


## The torch by F in rain and storm, by day (Y6): it does not come on by itself, stays on
## after the rain till you switch it off, F sleeps in the dry; every switch heard (Y3).
func _torch() -> Array:
	var look := func(what: String) -> Array:
		return ["eval", "['Y %s', 'on', _player.is_flashlight_active(), 'click', _player.get_node_or_null('TorchClick') != null and _player.get_node('TorchClick').playing]" % what]
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.5],
		["eval", "debug_jump_to(1, 11.0)"], ["eval", "_player.set('torch_carried', true)"], ["wait", 0.5],
		look.call("day dry"), ["key", "F"], ["wait", 0.05], look.call("day dry F"),
		["eval", "weather_system.set_weather(4)"], ["eval", "_set_weather_state(4)"], ["wait", 0.5], look.call("day rain, by itself"),
		["key", "F"], ["wait", 0.05], look.call("day rain F"), ["wait", 0.8], ["key", "F"], ["wait", 0.05], look.call("day rain F F"), ["wait", 0.8],
		["key", "F"], ["wait", 0.05], look.call("day rain F F F"), ["wait", 0.8],
		["eval", "weather_system.set_weather(5)"], ["eval", "_set_weather_state(5)"], ["wait", 0.5], look.call("storm, kept on"),
		["eval", "weather_system.set_weather(0)"], ["eval", "_set_weather_state(0)"], ["wait", 0.5], look.call("rain over, kept on"),
		["key", "F"], ["wait", 0.05], look.call("rain over F off"), ["wait", 0.8], ["key", "F"], ["wait", 0.05], look.call("dry again F sleeps"),
		["eval", "weather_system.set_weather(5)"], ["eval", "_set_weather_state(5)"], ["wait", 0.5], look.call("storm by day, by itself"),
		["key", "F"], ["wait", 0.3], ["shot", "storm_day_torch"],
		["eval", "debug_jump_to(1, 20.5)"], ["wait", 1.0], look.call("evening storm"),
		["eval", "weather_system.set_weather(0)"], ["eval", "_set_weather_state(0)"], ["wait", 0.5], look.call("evening dry"),
		["eval", "debug_jump_to(2, 7.5)"], ["wait", 1.0], look.call("morning dry, out by itself"),
		["eval", "get_tree().quit()"]]
	return s


## Both kinds of tree planted (Y14): on the ground, on the Builder's map, in the catalogue.
func _trees() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 90000], ["clear", 12, 10, 8, 5],
		["build", "tree_spruce", 13, 11, 0], ["build", "tree_birch", 15, 11, 0], ["build", "tree_birch", 17, 11, 0], ["build", "tree_spruce", 19, 11, 0], ["wait", 1.0],
		["eval", "['Y money', CoreRoot.get_money()]"],
		["player", 16, 14, 0.0], ["wait", 0.5], ["shot", "trees_ground_a"], ["player", 16, 14, 180.0], ["wait", 0.5], ["shot", "trees_ground_b"],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", UI + ".open_app('builder') != null"], ["wait", 4.5],
		["eval", "debug_close_msgboxes()"], ["wait", 0.5], ["crt_screen", "trees_map"],
		["eval", UI + ".app_of('builder')._module._open_category('decor')"], ["wait", 0.4], ["crt_screen", "trees_catalogue"],
		["eval", MAP + ".focus_camp(2.6)"], ["wait", 0.5], ["crt_screen", "trees_zoom"], ["eval", MAP + ".set_selected_building('tree_birch')"], ["wait", 0.5], ["crt_screen", "trees_ghost"],
		["eval", "get_tree().quit()"]]
	return s


## Space stands you up from the PC (Y15), and not from a line you are typing in.
func _pc() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["wait", 4.0], ["eval", "['Y at the PC', " + BI + "._crt_active]"], ["key", "SPACE"], ["wait", 1.5], ["eval", "['Y after Space', " + BI + "._crt_active]"], ["eval", "get_tree().quit()"]]
	return s
