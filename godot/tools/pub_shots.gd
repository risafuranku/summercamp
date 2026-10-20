extends "res://tools/shot_driver.gd"

## The pub (DESIGN.md §7b): the bar room, the cellar, each station worked where it stands
## in the room and worked a little, with guests in. Debug tooling only.
##   godot --path godot --resolution 1280x720 res://tools/pub_shots.tscn -- --out=<dir>

const SI := "_interior_manager._service_interior"
const TR := "get_tree().get_first_node_in_group('taprooms')"


func _st(id: String) -> String:
	return SI + "._stations['%s']" % id


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 40000], ["clear", 5, 5, 15, 10], ["build", "pub", 6, 6, 0],
		["build", "cabin_1", 6, 11, 0], ["build", "cabin_1", 9, 11, 0], ["build", "tent_1", 12, 11, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["eval", "debug_send_guests_to('pub', 240)"], ["wait", 1.0],
		["player", 7, 9, 180.0], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 4.0],
		["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 1.0], ["shot", "p01_bar"],
		["eval", SI + "._look.set('yaw_deg', 50.0)"], ["wait", 0.6], ["shot", "p02_bar_r"],
		["eval", SI + "._look.set('yaw_deg', -50.0)"], ["wait", 0.6], ["shot", "p03_bar_l"],
		["eval", SI + "._look.set('yaw_deg', 0.0)"],
		["eval", TR + ".tickets(" + SI + "._upkeep_key).size()"],
		["eval", SI + "._open_station('tap')"], ["wait", 1.0], ["shot", "p04_tap"],
		["eval", _st("tap") + ".debug_pour_right()"], ["wait", 0.4], ["shot", "p05_tap_poured"],
		["eval", _st("tap") + ".debug_click('mug')"], ["wait", 0.2], ["shot", "p06_tap_served"],
		["eval", SI + "._switch_station('back')"], ["wait", 1.0], ["shot", "p07_back"],
		["eval", _st("back") + ".debug_pour('rum', 0.6)"], ["wait", 0.3], ["shot", "p08_back_pour"],
		["eval", SI + "._switch_station('wash')"], ["wait", 1.0],
		["eval", TR + ".act(" + SI + "._upkeep_key, 'mugs', [0, 3])"],
		["eval", _st("wash") + ".debug_into_water()"], ["wait", 0.3], ["shot", "p09_wash"],
		["eval", _st("wash") + ".close_station()"], ["wait", 0.8], ["shot", "p10_bar_marks"],
		["eval", SI + "._go_door('p_cellar')"], ["wait", 3.0], ["shot", "p11_cellar"],
		["eval", SI + "._look.set('yaw_deg', 50.0)"], ["wait", 0.6], ["shot", "p12_cellar_r"],
		["eval", SI + "._look.set('yaw_deg', -50.0)"], ["wait", 0.6], ["shot", "p13_cellar_l"],
		["eval", SI + "._look.set('yaw_deg', 0.0)"],
		["eval", SI + "._open_station('keg')"], ["wait", 1.0], ["shot", "p14_keg"],
		["eval", _st("keg") + ".debug_click('coupler')"], ["wait", 0.3], ["shot", "p15_keg_off"],
		["eval", _st("keg") + ".debug_click('coupler_on')"],
		["eval", _st("keg") + ".close_station()"], ["wait", 0.8],
		["eval", SI + "._go_door('pc_main')"], ["wait", 3.0], ["shot", "p16_bar_after"],
		["eval", "debug_jump_to(1, 21.6)"], ["wait", 3.0], ["shot", "p17_bar_night"],
	]
