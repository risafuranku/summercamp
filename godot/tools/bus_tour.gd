extends "res://tools/shot_driver.gd"

## The bus test from the menu (L, "Bus to Lesna") played through for screenshots: the
## camp stop as the 380 comes, a ticket from the stop's machine, on board, punched in the
## orange box, the ride, STOP for Podlesi, the ruin, the turn,
## the hamlet, Vondra, the parts picked up, the Skoda mended in its close-up, Podlesi at
## night, the bus back to the camp from the request stop (a ticket from the driver).
##
##   godot --path godot --resolution 1280x720 res://tools/bus_tour.tscn -- --out=<dir>

const TT := "_interior_manager.town_trip()"
const H := "_interior_manager.town_trip()._hamlet"


func _at(x: float, z: float, yaw: float, shot: String) -> Array:
	return [
		["eval", "_player.set('global_position', %s.place.w(Vector3(%f, 0.2, %f)))" % [H, x, z]],
		["eval", "_player.set('rotation', Vector3(0, %f + %s.place.rotation.y, 0))" % [yaw, H]], ["wait", 1.2], ["shot", shot],
	]


func _thing(what: String, sprite := true) -> Array:
	var node := "%s.place.things['%s']%s" % [H, what, ".get_meta('body')" if sprite else ""]
	return [["eval", "%s.interact(%s)" % [H, node]], ["wait", 0.6]]


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["eval", "_on_menu_test_night('bus')"], ["wait_gameplay"], ["wait", 3.0],
		["eval", "get_viewport().warp_mouse(Vector2(640, 360))"], ["shot", "s0_stop"],
		["eval", "%s._open_machine('camp')" % TT], ["wait", 0.6],
		["eval", "%s._machine._clicked('row:0')" % TT], ["wait", 0.3], ["shot", "m0_machine_fare"],
		["eval", "%s._machine._clicked('coin')" % TT], ["eval", "%s._machine._start_print()" % TT], ["wait", 0.7], ["shot", "m1_machine_printing"],
		["wait", 1.2], ["shot", "m2_machine_ticket_out"],
		["eval", "%s._machine._clicked('ticket')" % TT], ["wait", 0.3], ["eval", "%s._machine.close_view()" % TT], ["wait", 0.5],
		["until", "%s._camp_bus.is_door_open()" % TT, 40.0], ["wait", 1.0],
		["eval", "_player.look_at(%s._camp_bus.global_position)" % TT], ["wait", 0.5], ["shot", "s1_bus"],
		["eval", "%s._board('camp')" % TT], ["wait", 2.5], ["shot", "s2_inside"],
		["eval", "%s._ride._punch()" % TT], ["wait", 0.6], ["eval", "%s._ride._punch_view._clicked('ticket')" % TT], ["wait", 0.3], ["shot", "p0_punch_in"],
		["wait", 0.5], ["shot", "p1_punch_cvak"], ["wait", 1.2], ["shot", "p2_punched"],
		["eval", "%s._ride._punch_view.close_view()" % TT], ["wait", 0.5], ["shot", "s2b_punched"], ["eval", "%s._ride._try_sit(%s._ride.first_free_seat(0))" % [TT, TT]],
		["wait", 8.0], ["shot", "s3_ride"],
		["eval", "%s._ride._press_stop()" % TT], ["wait", 1.0], ["shot", "s4_stop_pressed"],
		["eval", "%s._ride._look.set('yaw_deg', 60.0)" % TT], ["wait", 10.0], ["shot", "s5_ride_left"],
		["eval", "%s._ride._look.set('yaw_deg', -60.0)" % TT], ["wait", 4.0], ["shot", "s6_ride_right"],
		["wait", 4.0], ["shot", "s7_ride_right2"],
		["until", "%s._ride.is_open() == false" % TT, 320.0], ["wait", 2.0], ["shot", "h0_arrive"],
		["eval", "%s.state" % H],
	]
	for s in [[2.0, 8.0, 3.1416, "h1_turn"], [-62.0, 3.0, 0.5, "h2_ruin"], [0.0, 108.0, 3.1416, "h3_square"],
			[18.0, 127.0, 3.1416, "h4_garage"], [9.0, 122.0, -2.3, "h5_vondra"], [-24.0, 116.0, 1.2, "h6_wreck"]]:
		_steps.append_array(_at(s[0], s[1], s[2], s[3]))
	_steps.append_array([["eval", "%s.interact(%s.place.things['vondra'])" % [H, H]], ["wait", 1.0], ["shot", "h7_talk"]])
	for what in ["canister", "moped", "wreck", "stockings", "hammer"]:
		_steps.append_array(_thing(what))
	_steps.append_array([
		["eval", "%s.state" % H],
		["eval", "%s._open_car()" % H], ["wait", 1.0], ["shot", "c0_engine"],
		["eval", "%s._closeup._clicked('key')" % H], ["wait", 0.5],
		["eval", "%s._closeup._clicked('tray')" % H], ["eval", "%s._closeup._clicked('red')" % H], ["eval", "%s._closeup._clicked('black')" % H],
		["eval", "%s._closeup._clicked('key')" % H], ["eval", "%s._closeup._clicked('key')" % H], ["wait", 0.5], ["shot", "c1_clicks"],
		["eval", "%s._closeup._clicked('pulley:0')" % H], ["eval", "%s._closeup._clicked('pulley:2')" % H], ["eval", "%s._closeup._clicked('pulley:3')" % H], ["eval", "%s._closeup._clicked('pulley:1')" % H],
		["eval", "%s._closeup._clicked('starter')" % H],
		["eval", "%s.state['car'].merge({'fuel': 1.0}, true)" % H], ["eval", "%s.state['has'].merge({'canister': 'empty'}, true)" % H],
		["wait", 0.5], ["shot", "c2_parts_in"],
		["eval", "%s._closeup._clicked('key')" % H], ["wait", 1.5], ["shot", "c3_running"],
		["eval", "%s._closeup.close_view()" % H], ["wait", 3.0],
		["eval", "%s.state" % H],
	])
	_steps.append_array(_at(18.0, 125.0, 3.1416, "h8_garage_running"))
	_steps.append_array([["hours", 5.0], ["wait", 3.0]])
	_steps.append_array(_at(0.0, 108.0, 3.1416, "n0_square_night"))
	# The bus back to the camp from the request stop: wait by the pole for it.
	_steps.append_array([
		["eval", "_player.set('global_position', %s.place.w(Vector3(-7.0, 0.2, -6.0)))" % H],
		["eval", "time_system.set_time_hours(%s.TIMES.hamlet_to_camp()[2] - 0.2)" % H], ["wait", 1.0],
		["until", "%s.bus.is_door_open()" % H, 40.0], ["wait", 0.5],
		["eval", "_player.look_at(%s.bus.global_position)" % H], ["wait", 0.5], ["shot", "b0_bus_back"],
		["eval", "%s._board('hamlet_camp')" % TT], ["wait", 2.0], ["shot", "b1_inside_back"],
		["eval", "%s._ride._click('driver')" % TT], ["eval", "%s._ride._punch()" % TT], ["wait", 0.6],
		["eval", "%s._ride._punch_view._clicked('ticket')" % TT], ["wait", 2.0], ["eval", "%s._ride._punch_view.close_view()" % TT], ["wait", 0.5],
		["eval", "%s._ride._try_sit(%s._ride.first_free_seat(5))" % [TT, TT]],
		["until", "%s._ride.is_open() == false" % TT, 320.0], ["wait", 2.0], ["shot", "k0_back_at_camp"],
		["eval", "get_tree().quit()"],
	])
