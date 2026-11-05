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
		"stand":
			_steps = _stand()
		"marks":
			_steps = _marks()
		"wc":
			_steps = _wc()


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


## Guests in the queue at the corn stand (Y5): looking at one of them, E is the stand's.
func _stand() -> Array:
	var look := "['Y guest', _find_guest_in_view().get('name', ''), 'hint', _interaction_controller.build_hint_text(INTERACT_DISTANCE, false)]"
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 90000], ["clear", 4, 9, 8, 7],
		["build", "corn_stand", 6, 11, 0], ["build", "cabin_1", 9, 10, 0], ["build", "cabin_1", 9, 13, 0], ["wait", 1.0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["eval", "['Y sent', debug_send_guests_to('corn_stand', 240)]"], ["wait", 6.0],
		["eval", "set('debug_camera', null)"],
		["door_front", "corn_stand", 1.0], ["wait", 0.4],
		["eval", look], ["shot", "stand_front"],
		["eval", "['Y guests at', _guest_agents.get_visible_guest_positions().size()]"]]
	for k in 8:
		s += [["eval", "_player.rotate_y(0.35)"], ["wait", 0.15], ["eval", look]]
	s += [["eval", "get_tree().quit()"]]
	return s


## The marks over the rooms that want doing (Y22): how high over each kind of lodging.
func _marks() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 900000], ["clear", 4, 9, 14, 7],
		["build", "tent_1", 5, 10, 0], ["build", "tent_2", 8, 10, 0], ["build", "tent_3", 11, 10, 0], ["build", "cabin_1", 14, 10, 0], ["build", "caravan_1", 5, 13, 0], ["wait", 3.0]]
	for ty in ["tent_1", "tent_2", "tent_3", "cabin_1", "caravan_1"]:
		s += [["eval", "['Y mark', '%s', debug_structure_of_type('%s').get_node('RoomMarker').position, debug_structure_of_type('%s').global_position.y]" % [ty, ty, ty]]]
	# A tent somebody slept in keeps its night's light (window_lights: range 3.2 m, hidden by
	# day), and the mark went by the light's reach.
	s += [["eval", "debug_structure_of_type('tent_1').add_child(ClassDB.instantiate('OmniLight3D'))"], ["wait", 1.6],
		["eval", "['Y mark over a tent with a light', debug_structure_of_type('tent_1').get_node('RoomMarker').position]"],
		["eval", "get_tree().quit()"]]
	return s


## Each toilet its own (Y7, Y21): one bowl dirty, the hint at each door and the plates on the
## right; the goods running out on a plate of their own (Y11).
func _wc() -> Array:
	var st := "get_tree().root.get_node('CoreRoot').get_state()"
	var wc := "debug_structure_of_type('toilet_block')"
	var cell := st + ".grid.cells[" + wc + ".get_meta('grid_origin')]"
	var hint := "['Y hint', _interaction_controller.build_hint_text(INTERACT_DISTANCE, false), 'door', _interior_manager._toilet_door_of(" + wc + ")]"
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 90000], ["clear", 4, 9, 8, 7],
		["build", "toilet_block", 5, 10, 0], ["build", "corn_stand", 9, 10, 0], ["build", "pub", 5, 13, 0], ["wait", 1.5],
		["eval", cell + ".set('maint_r', 1.0)"], ["eval", cell + ".set('maint_l', 0.4)"], ["eval", cell + ".set('maintenance', 0.4)"],
		["eval", st + ".biz['sites'].values()[0]['stock'].set('cobs', 2)"], ["eval", st + ".biz['sites'].values()[1]['stock'].set('beer', 0)"], ["wait", 2.5],
		["eval", "_trouble_rows(_interior_manager.business)"],
		["eval", "['Y widths', _hud_manager._trouble_strip.font.get_string_size('KUKUŘIČNÉ KLASY', 0, -1, 8).x, _hud_manager._trouble_strip.font.get_string_size('OVOCE A ZELENINA', 0, -1, 8).x, _hud_manager._trouble_strip.font.get_string_size('KONZERVY POLÉVKY', 0, -1, 8).x, _hud_manager._trouble_strip.font.get_string_size('WC 2 PRAVÝ', 0, -1, 8).x]"],
		["eval", "set('debug_camera', null)"], ["door_front", "toilet_block", 1.4], ["wait", 0.5],
		["eval", "_player.look_at(" + wc + ".find_child('Door0', true, false).global_position, Vector3(0, 1, 0))"], ["wait", 0.4], ["eval", hint], ["shot", "wc_door0"],
		["eval", "_player.look_at(" + wc + ".find_child('Door1', true, false).global_position, Vector3(0, 1, 0))"], ["wait", 0.4], ["eval", hint], ["shot", "wc_door1"],
		["eval", cell + ".set('maint_r', 0.2)"], ["eval", cell + ".set('maintenance', 0.2)"], ["wait", 1.0], ["eval", hint],
		["eval", cell + ".set('maint_l', 1.0)"], ["eval", cell + ".set('maintenance', 0.2)"], ["wait", 2.5], ["eval", "_trouble_rows(_interior_manager.business)"], ["eval", hint], ["shot", "wc_right_only"],
		["eval", "get_tree().quit()"]]
	return s


## Space stands you up from the PC (Y15), and not from a line you are typing in.
func _pc() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["wait", 4.0], ["eval", "['Y at the PC', " + BI + "._crt_active]"], ["key", "SPACE"], ["wait", 1.5], ["eval", "['Y after Space', " + BI + "._crt_active]"], ["eval", "get_tree().quit()"]]
	return s
