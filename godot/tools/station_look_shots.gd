extends "res://tools/shot_driver.gd"

## Looking about from a station (station3d.gd LOOK_*): the corn stand's counter straight,
## then the head turned left and right out over the camp; the tabs in the order of the work.
## Debug tooling only.
##   godot --path godot res://tools/station_look_shots.tscn -- --out=<dir>

const IM := "_interior_manager"
const SV := "_interior_manager._corn_stand"


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 40000], ["clear", 5, 5, 15, 12], ["build", "corn_stand", 11, 11, 0],
		["build", "cabin_1", 6, 8, 0], ["build", "tent_1", 13, 8, 0],
		["eval", "_player.set('global_position', debug_structure_of_type('corn_stand').global_position + Vector3(0, 0.4, 3.0))"],
		["eval", IM + "._on_corn_stand_interact(debug_structure_of_type('corn_stand'))"], ["wait", 1.5],
		["eval", SV + "._tabs()"],
		["eval", SV + "._switch('counter')"], ["wait", 1.0], ["shot", "k0_counter"],
		["eval", SV + "._stations['counter']._look.set('yaw_deg', 75.0)"], ["wait", 0.3], ["shot", "k1_look_left"],
		["eval", SV + "._stations['counter']._look.set('yaw_deg', -150.0)"], ["wait", 0.3], ["shot", "k2_look_back"],
		["eval", SV + "._switch('husk')"], ["wait", 1.0], ["shot", "k3_husk_straight"],
	]
