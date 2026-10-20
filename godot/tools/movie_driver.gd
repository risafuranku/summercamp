extends "res://tools/shot_driver.gd"

## Short films of the businesses' work for --write-movie (agent C's brief: the camera going
## to a station, frying, pulling a beer, the till, the machine in the bistro's cellar).
## The setup runs first and is cut off afterwards: the steps ["mark", "start"] and
## ["mark", "end"] write the frame numbers to <out>/<movie>.marks, and
## tools/movie_cut.py keeps only what is between them. Debug tooling only.
##
##   godot --path godot --write-movie <out>/<movie>.avi --fixed-fps 30 res://tools/movie_driver.tscn -- --movie=<movie> --out=<out> [--size=1280x720]
##   python tools/movie_cut.py <out>/<movie>.avi
## Movies: till (the Jednota), fry (the bistro's stove), tap (the pub), proto (PROTOTYP 540).

const SI := "_interior_manager._service_interior"
const KS := "get_tree().get_first_node_in_group('kitchens')"
const TR := "get_tree().get_first_node_in_group('taprooms')"
const J := "get_tree().get_first_node_in_group('jednotas')"

var _movie := "till"
var _marks: Array = []


func _st(id: String) -> String:
	return SI + "._stations['%s']" % id


func _ready() -> void:
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--movie="):
			_movie = arg.get_slice("=", 1)
		elif arg.begins_with("--size="):
			var wh := arg.get_slice("=", 1).split("x")
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	var setup := [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 0.5],
		["eval", "_interior_manager._building_interior.close_interior()"], ["money", 40000],
	]
	var guests := [
		["build", "cabin_1", 5, 12, 0], ["build", "cabin_1", 9, 12, 0], ["build", "tent_1", 13, 12, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 2.0],
	]
	var aim := ["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.62))"]
	match _movie:
		"till":
			_steps = setup + [["clear", 4, 4, 16, 12], ["build", "vecerka", 6, 6, 0]] + guests + [
				["eval", "debug_send_guests_to('vecerka', 240)"], ["wait", 0.5],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('vecerka'))"], ["wait", 2.0],
				["eval", J + ".debug_pick_all(" + SI + "._upkeep_key)"], aim, ["wait", 1.0],
				["mark", "start"], ["wait", 1.5],
				["eval", SI + "._open_station('till')"], ["wait", 1.5],
				["eval", _st("till") + ".debug_click('item:0')"], ["wait", 0.6],
				["eval", _st("till") + ".debug_click('item:1')"], ["wait", 0.6],
				["eval", _st("till") + ".debug_click('item:2')"], ["wait", 0.6],
				["eval", _st("till") + ".debug_click('item:3')"], ["wait", 0.6],
				["eval", _st("till") + ".debug_click('item:4')"], ["wait", 1.2],
				["eval", _st("till") + ".debug_click('paid')"], ["wait", 1.0],
				["eval", _st("till") + ".debug_next_coin()"], ["wait", 0.5],
				["eval", _st("till") + ".debug_next_coin()"], ["wait", 0.5],
				["eval", _st("till") + ".debug_next_coin()"], ["wait", 0.5],
				["eval", _st("till") + ".debug_next_coin()"], ["wait", 0.8],
				["eval", _st("till") + ".bar_button('give')"], ["wait", 2.5],
				["eval", _st("till") + ".close_station()"], ["wait", 1.5],
				["mark", "end"],
			]
		"fry":
			_steps = setup + [["clear", 5, 5, 15, 10], ["build", "restaurant", 6, 6, 0]] + guests + [
				["eval", "debug_send_guests_to('restaurant', 240)"], ["wait", 0.5],
				["player", 7, 9, 180.0], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('restaurant'))"], ["wait", 2.0],
				["eval", SI + "._go_door('d_kitchen')"], ["wait", 3.0],
				["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['cheese_raw', 4])"],
				["eval", KS + ".act(" + SI + "._upkeep_key, 'prep', ['chips_raw', 6])"], aim,
				["mark", "start"], ["wait", 1.0],
				["eval", SI + "._open_station('stove')"], ["wait", 1.5],
				["eval", _st("stove") + ".debug_lay()"], ["wait", 0.6], ["eval", _st("stove") + ".debug_lay()"], ["wait", 0.6],
				["eval", _st("stove") + ".debug_click('bucket')"], ["wait", 0.6], ["eval", _st("stove") + ".debug_click('basket')"], ["wait", 6.0],
				["eval", _st("stove") + ".debug_click('slot:0')"], ["wait", 0.5], ["eval", _st("stove") + ".debug_click('slot:1')"], ["wait", 6.0],
				["eval", _st("stove") + ".debug_click('slot:0')"], ["wait", 0.5], ["eval", _st("stove") + ".debug_click('slot:1')"], ["wait", 0.5],
				["eval", _st("stove") + ".debug_click('basket')"], ["wait", 2.0],
				["eval", _st("stove") + ".close_station()"], ["wait", 1.5],
				["mark", "end"],
			]
		"tap":
			_steps = setup + [["clear", 5, 5, 15, 10], ["build", "pub", 6, 6, 0]] + guests + [
				["eval", "debug_send_guests_to('pub', 240)"], ["wait", 0.5],
				["player", 7, 9, 180.0], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 3.0], aim,
				["mark", "start"], ["wait", 1.0],
				["eval", SI + "._open_station('tap')"], ["wait", 1.5],
				["eval", _st("tap") + ".debug_pour_right()"], ["wait", 2.5],
				["eval", _st("tap") + ".debug_click('mug')"], ["wait", 2.0],
				["eval", SI + "._switch_station('back')"], ["wait", 1.5],
				["eval", _st("back") + ".debug_pour('rum', 0.6)"], ["wait", 2.0],
				["eval", _st("back") + ".close_station()"], ["wait", 1.5],
				["mark", "end"],
			]
		"proto":
			_steps = setup + [["clear", 5, 5, 15, 10], ["build", "restaurant", 6, 6, 0], ["build", "cabin_1", 6, 11, 0], ["wait", 0.5],
				["player", 7, 9, 180.0], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('restaurant'))"], ["wait", 2.0],
				["eval", SI + "._go_door('d_kitchen')"], ["wait", 3.0],
				["eval", SI + "._go_door('k_cellar')"], ["wait", 3.0],
				["eval", "debug_jump_to(2, 22.5)"], ["wait", 2.0],
				["eval", KS + ".debug_proto_sack(" + SI + "._upkeep_key)"], aim, ["wait", 1.0],
				["mark", "start"], ["wait", 1.0],
				["eval", SI + "._open_station('machine')"], ["wait", 2.0],
				["eval", _st("machine") + "._press('sack')"], ["wait", 6.0],
				["eval", _st("machine") + ".close_station()"], ["wait", 3.0],
				["mark", "end"],
			]


func _run_step(step: Array) -> void:
	if str(step[0]) == "mark":
		_marks.append("%s %d" % [str(step[1]), Engine.get_frames_drawn()])
		var f := FileAccess.open(_out_dir.path_join(_movie + ".marks"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_marks) + "\n")
		print("MOVIE MARK %s %d" % [str(step[1]), Engine.get_frames_drawn()])
		return
	super._run_step(step)
