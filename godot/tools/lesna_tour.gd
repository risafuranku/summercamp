extends "res://tools/shot_driver.gd"

## A walk round Lesna for screenshots: the street both ways (the masts at its end), the
## Jednota, the pub, the green, the gabled houses, the motel, the barn, the fire station,
## then the same at night. Uses the shot driver's steps (tools/shot_driver.gd):
##
##   godot --path godot --resolution 1280x720 res://tools/lesna_tour.tscn -- --out=<dir>

const TT := "_interior_manager.town_trip()"


func _at(x: float, z: float, yaw: float, shot: String) -> Array:
	return [
		["eval", "_player.set('global_position', %s._town.w(Vector3(%f, 0.2, %f)))" % [TT, x, z]],
		["eval", "_player.set('rotation', Vector3(0, %f, 0))" % yaw], ["wait", 1.2], ["shot", shot],
	]


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.5],
		["eval", "get_viewport().warp_mouse(Vector2(640, 360))"],
		["eval", "%s._ensure_town()" % TT],
		["eval", "%s._put_player(%s._town.arrive_spot())" % [TT, TT]], ["wait", 2.0], ["shot", "a0_arrive"],
	]
	# yaw: 0 looks north (-z), PI south (+z), PI/2 west (-x), -PI/2 east (+x).
	for s in [
		[0.0, 2.0, 1.5708, "a1_street_west"], [10.0, 1.5, -1.5708, "a2_street_east"],
		[-6.0, -2.0, 0.0, "a3_jednota"], [16.0, -2.0, 0.0, "a4_pub"],
		[8.0, -3.0, 3.1416, "a5_green"], [-4.0, 5.0, 2.6, "a6_zvonicka"],
		[-50.0, 1.5, 0.2, "a7_gables_north"], [-56.0, -1.5, 2.9, "a8_gables_south"],
		[-24.0, 3.0, 3.1416, "a9_motel"], [48.0, 3.0, 3.1416, "b0_station"],
		[12.0, 20.0, 3.1416, "b1_barn"], [-62.0, 1.8, 1.4, "b2_village_sign"],
		[42.0, -2.5, 0.35, "b3_east_houses"], [-20.0, 14.0, -0.6, "b4_green_back"],
		[-24.0, -3.0, 3.1416, "b5_motel_far"], [-28.0, -11.0, 0.0, "b6_chapel"], [31.0, -2.0, 0.0, "b7_kostka"],
		[22.0, 4.0, 2.7, "b8_green_far"], [52.0, -2.0, 0.0, "b9_gate"],
		[37.0, 18.0, 3.1416, "c0_firehouse"], [5.0, -1.0, 0.0, "c1_yard_gate"], [31.0, 1.0, 0.0, "c2_kostka"],
	]:
		_steps.append_array(_at(s[0], s[1], s[2], s[3]))
	_steps.append_array([["hours", 12.0], ["wait", 4.0]])
	for s in [
		[0.0, 2.0, 1.5708, "n0_street_west"], [8.0, -3.0, 3.1416, "n1_green"],
		[-24.0, -3.0, 3.1416, "n2_motel"], [16.0, -2.0, 0.0, "n3_pub"], [-50.0, 1.5, 0.2, "n4_gables"],
	]:
		_steps.append_array(_at(s[0], s[1], s[2], s[3]))
	_steps.append(["eval", "get_tree().quit()"])
