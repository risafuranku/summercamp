extends "res://tools/shot_driver.gd"

## The businesses' polish (DESIGN.md §7b "The businesses' polish"), looked at: the pub's bill
## at the tap, the LUCKY 7, darts and cards; the bistro's grill, a klobasa plate at the
## pass, the bufet's soup and a bottle opened; the Jednota's deli counter and the till with
## a pack of cigarettes; each with your hand at it, frames at twelve a second where
## something moves. Debug tooling only.
##   godot --path godot res://tools/podniky_shots.tscn -- --out=<dir> --part=pub|bistro|jednota [--size=1280x720]

const SI := "_interior_manager._service_interior"
const TR := "get_tree().get_first_node_in_group('taprooms')"
const KI := "get_tree().get_first_node_in_group('kitchens')"
const JE := "get_tree().get_first_node_in_group('jednotas')"
const F := 1.0 / 12.0


func _st(id: String) -> String:
	return SI + "._stations['%s']" % id


func _to(id: String, x: float, y: float, lift := 0.0) -> Array:
	return ["eval", _st(id) + ".debug_mouse_to(Vector2(%s, %s), %s)" % [x, y, lift]]


func _camp(building: String, x: int, y: int) -> Array:
	return [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 60000], ["clear", 4, 4, 16, 12], ["build", building, x, y, 0],
		["build", "cabin_1", 5, 12, 0], ["build", "cabin_1", 8, 12, 0], ["build", "cabin_1", 11, 12, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["eval", "debug_send_guests_to('%s', 400)" % building], ["wait", 2.0],
		["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('%s'))" % building], ["wait", 4.0],
		["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 1.0],
	]


func _ready() -> void:
	super._ready()
	var part := "pub"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var wh := arg.get_slice("=", 1).split("x")
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		elif arg.begins_with("--part="):
			part = arg.get_slice("=", 1)
	match part:
		"pub":
			_steps = _camp("pub", 6, 6) + [
				["shot", "u01_bar"],
				["eval", SI + "._look.set('yaw_deg', -45.0)"], ["wait", 0.6], ["shot", "u02_fun_corner"], ["eval", SI + "._look.set('yaw_deg', 0.0)"],
				# The tap: a round on the mats, the pencil's mark.
				["eval", SI + "._open_station('tap')"], ["wait", 1.0], ["shot", "u03_tap"],
				["eval", _st("tap") + ".debug_pour_right()"], ["eval", _st("tap") + ".debug_click('mug')"], ["wait", F], ["shot", "u04a_mark"], ["wait", F * 2], ["shot", "u04b_mark"], ["wait", 0.4], ["shot", "u04c_card"],
				["eval", TR + ".debug_pour_some(" + SI + "._upkeep_key, 5)"],
				["eval", _st("tap") + ".close_station()"], ["wait", 0.6],
				# Their time is up: the bills.
				["hours", 0.4], ["wait", 1.0],
				["eval", "[" + TR + ".bills(" + SI + "._upkeep_key).size(), " + TR + ".bills(" + SI + "._upkeep_key)]"],
				["eval", SI + "._open_station('tap')"], ["wait", 1.2], _to("tap", 420, 110, 0.01), ["wait", 0.3], ["shot", "u05_bill"],
				["eval", _st("tap") + ".debug_click('bill:mat')"], _to("tap", 500, 225, 0.01), ["wait", 0.3], ["shot", "u06_wallet"],
				["eval", _st("tap") + ".debug_click('bill:5')"], ["eval", _st("tap") + ".debug_click('bill:2')"], ["wait", 0.3], ["shot", "u07_change"],
				["eval", _st("tap") + ".close_station()"], ["wait", 0.6],
				# The LUCKY 7.
				["eval", SI + "._open_station('slot')"], ["wait", 1.2], _to("slot", 590, 110), ["wait", 0.3], ["shot", "u08_slot"],
				["eval", _st("slot") + ".debug_pull()"], ["wait", F * 3], ["shot", "u09a_reels"], ["wait", F * 3], ["shot", "u09b_reels"],
				["wait", 1.6], ["shot", "u09c_stopped"],
				["eval", _st("slot") + ".close_station()"], ["wait", 0.6],
				# Darts.
				["eval", SI + "._open_station('darts')"], ["wait", 1.2], _to("darts", 320, 160), ["wait", 0.3], ["shot", "u10_darts"],
				["eval", _st("darts") + ".debug_throw(Vector2(0.05, -0.6))"], ["eval", _st("darts") + ".debug_throw(Vector2(0.3, 0.2))"], ["wait", 0.2],
				["eval", _st("darts") + ".debug_throw(Vector2(-0.02, 0.01))"], ["wait", 0.4], ["shot", "u11_darts_three"],
				["eval", _st("darts") + ".close_station()"], ["wait", 0.6],
				# Cards.
				["eval", SI + "._open_station('cards')"], ["wait", 1.2], _to("cards", 120, 180), ["wait", 0.3], ["shot", "u12_cards"],
				["eval", _st("cards") + ".debug_click('pack')"], ["eval", _st("cards") + ".debug_click('pack')"], ["wait", 0.4], ["shot", "u13_cards_dealt"],
				["eval", _st("cards") + ".bar_button('stand')"], ["wait", 0.5], ["shot", "u14_cards_end"],
				["eval", _st("cards") + ".close_station()"], ["wait", 0.8], ["shot", "u15_bar_after"],
			]
		"bistro":
			_steps = _camp("restaurant", 6, 6) + [
				["shot", "b01_dining"],
				["eval", SI + "._look.set('yaw_deg', 50.0)"], ["wait", 0.6], ["shot", "b02_bufet_side"], ["eval", SI + "._look.set('yaw_deg', 0.0)"],
				# The bufet: a bowl of soup, a bottle opened (the cap flying, lying).
				["eval", SI + "._open_station('bufet')"], ["wait", 1.2], _to("bufet", 130, 150), ["wait", 0.3], ["shot", "b03_bufet"],
				["eval", _st("bufet") + ".debug_click('stack')"], ["eval", _st("bufet") + ".debug_click('pot')"], ["eval", _st("bufet") + ".debug_click('pot')"], ["wait", 0.3], ["shot", "b04_soup"],
				["eval", _st("bufet") + ".debug_click('bowl')"], ["wait", 0.5], ["shot", "b05_soup_card"],
				["eval", _st("bufet") + ".debug_click('crate_kofola')"], _to("bufet", 500, 250, 0.2), ["wait", 0.3], ["shot", "b06_bottle"],
				["eval", _st("bufet") + ".debug_pop()"], ["wait", F * 2], ["shot", "b07a_cap"], ["wait", F * 2], ["shot", "b07b_cap"], ["wait", 0.5], ["shot", "b07c_cap_down"],
				["eval", _st("bufet") + ".close_station()"], ["wait", 0.6],
				# The kitchen: the grill, a klobasa at the pass.
				["eval", SI + "._go_door('d_kitchen')"], ["wait", 3.0], ["shot", "b08_kitchen"],
				["eval", SI + "._open_station('grill')"], ["wait", 1.2], _to("grill", 82, 200), ["wait", 0.3], ["shot", "b09_grill"],
				["eval", _st("grill") + ".debug_click('tray')"], ["eval", _st("grill") + ".debug_click('tray')"], ["eval", _st("grill") + ".debug_click('tray')"],
				["eval", _st("grill") + ".debug_cook(8.0)"], _to("grill", 250, 150, 0.02), ["wait", 0.3], ["shot", "b10_grill_on"],
				["eval", _st("grill") + ".press()"], ["wait", F], ["shot", "b11a_turn"], ["eval", _st("grill") + ".release()"], ["wait", F * 2], ["shot", "b11b_turn"],
				["eval", _st("grill") + ".debug_cook(16.0)"], ["wait", 0.5], ["shot", "b12_burning"],
				["eval", _st("grill") + ".debug_cook(8.0)"], ["eval", _st("grill") + ".debug_click('slot:1')"], ["eval", _st("grill") + ".debug_cook(8.0)"], ["eval", _st("grill") + ".debug_click('slot:1')"],
				["wait", 0.4], ["shot", "b13_rack"],
				["eval", _st("grill") + ".close_station()"], ["wait", 0.6],
				["eval", SI + "._open_station('pass')"], ["wait", 1.2], ["shot", "b14_pass"],
				["eval", _st("pass") + ".debug_click('stack')"], ["eval", _st("pass") + ".debug_click('sausage')"], ["eval", _st("pass") + ".debug_click('mustard')"], ["eval", _st("pass") + ".debug_click('bread')"],
				["wait", 0.4], ["shot", "b15_klobasa"],
				["eval", _st("pass") + ".close_station()"], ["wait", 0.6], ["shot", "b16_kitchen_after"],
			]
		"jednota":
			_steps = _camp("vecerka", 6, 6) + [
				["shot", "j01_shop"],
				["eval", SI + "._look.set('yaw_deg', 45.0)"], ["wait", 0.6], ["shot", "j02_counters"], ["eval", SI + "._look.set('yaw_deg', 0.0)"],
				["eval", JE + "._host_second(" + SI + "._upkeep_key)"], ["wait", 0.5],
				["eval", JE + ".debug_deli_order(" + SI + "._upkeep_key, 'salami', 150)"],
				["eval", JE + ".debug_deli_order(" + SI + "._upkeep_key, 'cheese', 200)"],
				["eval", "[" + JE + ".deli_tickets(" + SI + "._upkeep_key).size()]"],
				["eval", SI + "._open_station('deli')"], ["wait", 1.2], _to("deli", 112, 176, 0.02), ["wait", 0.3], ["shot", "j03_deli"],
				["eval", _st("deli") + ".press()"], ["wait", F], ["shot", "j04a_cut"], ["eval", _st("deli") + ".release()"], ["wait", F * 2], ["shot", "j04b_cut"],
				["eval", _st("deli") + ".debug_cut_to_want()"], _to("deli", 320, 150, 0.02), ["wait", 0.3], ["shot", "j05_scale"],
				["eval", _st("deli") + ".debug_click('wrap')"], _to("deli", 320, 150, 0.04), ["wait", 0.3], ["shot", "j06_parcel"],
				["eval", _st("deli") + ".debug_click('give')"], ["wait", 0.5], ["shot", "j07_card"],
				["eval", _st("deli") + ".close_station()"], ["wait", 0.6],
				["eval", "debug_jump_to(1, 15.5)"], ["wait", 2.0], ["eval", JE + "._host_second(" + SI + "._upkeep_key)"], ["wait", 0.5],
				["eval", SI + "._open_station('till')"], ["wait", 1.2], _to("till", 598, 320, 0.02), ["wait", 0.3], ["shot", "j08_till_cigs"],
				["eval", _st("till") + ".debug_click('cigs')"], ["wait", 0.3], ["shot", "j09_till_after"],
				["eval", _st("till") + ".close_station()"], ["wait", 0.6], ["shot", "j10_shop_after"],
			]
