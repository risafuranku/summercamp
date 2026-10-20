extends "res://tools/shot_driver.gd"

## The corn stand (DESIGN.md §7b "The corn stand"): behind its counter out in the camp,
## the husking and the counter worked a little, a cob boiled, dressed and handed over,
## with guests in front of it. Debug tooling only.
##   godot --path godot --resolution 1280x720 res://tools/stand_shots.tscn -- --out=<dir>

const IM := "_interior_manager"
const SV := "_interior_manager._corn_stand"


func _st(id: String) -> String:
	return SV + "._stations['%s']" % id


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 40000], ["clear", 5, 5, 15, 12], ["build", "corn_stand", 11, 11, 0],
		["build", "cabin_1", 6, 8, 0], ["build", "cabin_1", 9, 8, 0], ["build", "tent_1", 13, 8, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["eval", "debug_send_guests_to('corn_stand', 240)"], ["wait", 2.0],
		["eval", "debug_send_guests_to('corn_stand', 240)"], ["wait", 4.0],
		["eval", "_player.set('global_position', debug_structure_of_type('corn_stand').global_position + Vector3(0, 0.4, 3.0))"],
		["eval", "_player.set('rotation', Vector3(0, 0, 0))"], ["wait", 1.0], ["shot", "s00_front"],
		["eval", IM + "._on_corn_stand_interact(debug_structure_of_type('corn_stand'))"], ["wait", 1.5],
		["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"], ["wait", 0.5], ["shot", "s01_counter"],
		["eval", SV + "._switch('husk')"], ["wait", 1.0], ["shot", "s02_husk"],
		["eval", _st("husk") + ".debug_click('crate')"], ["wait", 0.4], ["shot", "s03_husk_cob"],
		["eval", _st("husk") + ".debug_pull()"], ["wait", 0.15], ["shot", "s04_leaf"],
		["eval", _st("husk") + ".debug_husk()"], ["eval", _st("husk") + ".debug_click('cob')"],
		["eval", _st("husk") + ".debug_click('crate')"], ["eval", _st("husk") + ".debug_husk()"], ["eval", _st("husk") + ".debug_click('cob')"],
		["wait", 0.4], ["shot", "s05_bowl"],
		["eval", SV + "._switch('counter')"], ["wait", 1.0],
		["eval", _st("counter") + ".debug_click('pot')"], ["eval", _st("counter") + ".debug_click('pot')"], ["wait", 1.0], ["shot", "s06_pot_in"],
		["wait", 10.0], ["shot", "s07_pot_done"],
		["eval", _st("counter") + ".debug_take_first()"], ["wait", 0.3], ["shot", "s08_board"],
		["eval", _st("counter") + ".debug_dress_right()"], ["wait", 0.3], ["shot", "s09_dressed"],
		["eval", _st("counter") + ".debug_click('hand')"], ["wait", 0.6], ["shot", "s10_served"],
		["eval", SV + ".close_view()"], ["wait", 1.0], ["shot", "s11_back_out"],
		["eval", "debug_jump_to(1, 21.6)"], ["wait", 3.0],
		["eval", IM + "._on_corn_stand_interact(debug_structure_of_type('corn_stand'))"], ["wait", 1.5], ["shot", "s12_night"],
	]
