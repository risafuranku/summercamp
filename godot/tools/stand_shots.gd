extends "res://tools/shot_driver.gd"

## The corn stand (DESIGN.md §7b "The corn stand"): behind its counter out in the camp,
## the husking, the counter and the drinks worked a little with your gloved hand at each
## (its frames twelve a second), a cob boiled, dressed and handed over (Papa's slip), a
## cup of tea and a bag of lemonade, the queue out into the camp in the evening rush.
## Debug tooling only.
##   godot --path godot res://tools/stand_shots.tscn -- --out=<dir> [--size=1280x720]

const IM := "_interior_manager"
const SV := "_interior_manager._corn_stand"
const F := 1.0 / 12.0


func _st(id: String) -> String:
	return SV + "._stations['%s']" % id


## The mouse onto a point of station `id`'s counter (design px), `lift` metres over it.
func _to(id: String, x: float, y: float, lift := 0.0) -> Array:
	return ["eval", _st(id) + ".debug_mouse_to(Vector2(%s, %s), %s)" % [x, y, lift]]


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
		["money", 40000], ["clear", 5, 5, 15, 12], ["build", "corn_stand", 11, 11, 0],
		["build", "cabin_1", 6, 8, 0], ["build", "cabin_1", 9, 8, 0], ["build", "tent_1", 13, 8, 0], ["build", "tent_1", 15, 8, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["prep_all"], ["book", "Kaja", "cheap_chick", 2, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["eval", "debug_send_guests_to('corn_stand', 240)"], ["wait", 2.0],
		["eval", "debug_send_guests_to('corn_stand', 240)"], ["wait", 4.0],
		["eval", "_player.set('global_position', debug_structure_of_type('corn_stand').global_position + Vector3(0, 0.4, 3.0))"],
		["eval", "_player.set('rotation', Vector3(0, 0, 0))"], ["wait", 1.0], ["shot", "s00_front"],
		["eval", IM + "._on_corn_stand_interact(debug_structure_of_type('corn_stand'))"], ["wait", 1.5],
		_to("counter", 95, 150), ["wait", 0.5], ["shot", "s01_counter"],
		# The husking: a cob from the crate, a leaf pulled in the gloved fist, frame by frame.
		["eval", SV + "._switch('husk')"], ["wait", 1.0], _to("husk", 90, 140), ["wait", 0.4], ["shot", "s02_husk"],
		["eval", _st("husk") + ".debug_click('crate')"], _to("husk", 320, 196, 0.035), ["wait", 0.4], ["shot", "s03_husk_cob"],
		["eval", _st("husk") + ".press()"], ["wait", F], ["shot", "s04a_pull"], ["wait", F], ["shot", "s04b_pull"],
		_to("husk", 320, 140, 0.035), ["wait", F], ["shot", "s04c_pull"], ["eval", _st("husk") + ".release()"], ["wait", F], ["shot", "s04d_pull"],
		["eval", _st("husk") + ".debug_husk()"], ["eval", _st("husk") + ".debug_click('cob')"],
		["eval", _st("husk") + ".debug_click('crate')"], ["eval", _st("husk") + ".debug_husk()"], ["eval", _st("husk") + ".debug_click('cob')"],
		["wait", 0.4], ["shot", "s05_bowl"],
		# The counter: into the pot with the tongs, out when golden, buttered, salted.
		["eval", SV + "._switch('counter')"], ["wait", 1.0],
		["eval", _st("counter") + ".debug_click('pot')"], ["eval", _st("counter") + ".debug_click('pot')"], _to("counter", 95, 160), ["wait", 1.0], ["shot", "s06_pot_in"],
		["wait", 10.0], ["shot", "s07_pot_done"],
		["eval", _st("counter") + ".press()"], ["wait", F * 2], ["shot", "s08a_tongs"], ["eval", _st("counter") + ".release()"], ["wait", F * 3], ["shot", "s08b_board"],
		_to("counter", 262, 182, 0.04), ["wait", 0.3], ["eval", _st("counter") + ".press()"], ["wait", F], ["shot", "s09a_brush"],
		_to("counter", 290, 182, 0.04), ["wait", F], ["shot", "s09b_brush"], _to("counter", 318, 182, 0.04), ["wait", F], ["shot", "s09c_brush"],
		["eval", _st("counter") + ".release()"],
		["eval", _st("counter") + ".debug_dress_right()"],
		_to("counter", 472, 150), ["wait", 0.3], ["shot", "s10a_salt"],
		["eval", _st("counter") + ".debug_click('hand')"], ["wait", 0.2], ["shot", "s10b_served"], ["wait", 0.5], ["shot", "s10c_card"],
		# The drinks: a cup under the barrel's tap, the tea running; a bag of lemonade.
		["eval", SV + "._switch('drinks')"], ["wait", 1.0], _to("drinks", 60, 140), ["wait", 0.4], ["shot", "s11_drinks"],
		["eval", _st("drinks") + ".debug_click('cups')"], _to("drinks", 214, 120), ["wait", 0.3],
		["eval", _st("drinks") + ".debug_hold(true)"], ["wait", 1.2], ["shot", "s12a_tea_running"], ["wait", 0.9], ["shot", "s12b_tea_line"],
		["eval", _st("drinks") + ".debug_hold(false)"],
		["eval", _st("drinks") + ".debug_click('drink')"], ["wait", 0.5], ["shot", "s12c_tea_card"],
		["eval", _st("drinks") + ".debug_click('bags')"], _to("drinks", 458, 110), ["wait", 0.3],
		["eval", _st("drinks") + ".debug_hold(true)"], ["wait", 1.0], ["shot", "s13a_limo_pour"], ["wait", 0.8],
		["eval", _st("drinks") + ".debug_hold(false)"], ["eval", _st("drinks") + ".debug_click('straws')"], ["wait", 0.3], ["shot", "s13b_limo_tied"],
		["eval", SV + ".close_view()"], ["wait", 1.0], ["shot", "s14_back_out"],
		# The evening rush: everybody out for supper, the queue out into the camp.
		["eval", "debug_jump_to(1, 18.4)"], ["wait", 3.0],
		["eval", "debug_send_guests_to('corn_stand', 240)"], ["wait", 2.0], ["eval", "debug_send_guests_to('corn_stand', 240)"], ["wait", 4.0],
		["eval", "_player.set('global_position', debug_structure_of_type('corn_stand').global_position + Vector3(4.5, 0.4, 7.0))"],
		["eval", "_player.set('rotation', Vector3(0, deg_to_rad(35.0), 0))"], ["wait", 1.0], ["shot", "s15_rush_queue"],
		["eval", IM + "._on_corn_stand_interact(debug_structure_of_type('corn_stand'))"], ["wait", 1.5],
		["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.2))"], ["wait", 0.5], ["shot", "s16_rush_counter"],
		["eval", SV + ".close_view()"], ["wait", 0.5],
		["eval", "debug_jump_to(1, 21.6)"], ["wait", 3.0],
		["eval", IM + "._on_corn_stand_interact(debug_structure_of_type('corn_stand'))"], ["wait", 1.5], ["shot", "s17_night"],
	]
