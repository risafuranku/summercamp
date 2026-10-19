extends "res://tools/coop_check.gd"

## The cigarette and the bottle for two (scripts/town/pockets.gd, scripts/habits/): a host
## and a joining copy on this machine (tools/habits_coop.py), each driving its own keys,
## waiting for the other by files in the out dir. Pictures from both sides:
##   - the other warden lights up, draws on it, holds it (their figure's poses);
##   - at night their ember from close, 8 m and 25 m off (seen through the dark and fog);
##   - the host's lit cigarette held to the other's waiting in their mouth lights it;
##   - the host holds C by the other: a cigarette from the pack into their bag;
##   - both with an open bottle, face to face: B knocks them together;
##   - the host taps X by the other: the bottle goes into their hand.

const P := "_interior_manager.town_trip().pockets"
const INV := "_interior_manager.town_trip().inventory"


func _ready() -> void:
	super._ready()
	var common := [
		["eval", INV + ".add_item('cigs')"], ["eval", INV + ".add_item('beer')"], ["eval", INV + ".add_item('beer')"],
		["eval", P + ".cig.set('debug_catch', true)"],
	]
	if _role == "host":
		var s: Array = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 9000], ["clear", 11, 12, 5, 5], ["wait", 1.0],
			["eval", "debug_jump_to(1, 11.0)"], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"]]
		s.append_array(common)
		s.append_array([
			["hb_close", 3.0], ["wait", 1.0], ["shot", "h01_other_idle"], ["coop_signal", "host_watch"],
			["coop_wait_file", "client_pack"], ["wait", 0.3], ["shot", "h02_other_pack"],
			["coop_wait_file", "client_lighting"], ["wait", 0.4], ["shot", "h03_other_lighting"],
			["coop_wait_file", "client_dragging"], ["wait", 0.3], ["shot", "h04_other_drag"],
			["coop_wait_file", "client_holding"], ["wait", 1.0], ["shot", "h05_other_holds"],
			["coop_wait_file", "client_drinking"], ["wait", 0.4], ["shot", "h06_other_drinks"],
			["coop_wait_file", "client_bottle"], ["wait", 0.8], ["shot", "h07_other_bottle"],
			# Night: their ember, near and far.
			["eval", "debug_jump_to(1, 22.6)"], ["wait", 3.0], ["coop_signal", "host_night"],
			["coop_wait_file", "client_lit_night"], ["wait", 1.0],
			["eval", "_player.set('_flashlight_user_enabled', false)"], ["eval", "_player._refresh_flashlight_state()"],
			["hb_close", 3.0], ["wait", 0.8], ["shot", "h10_ember_3m"],
			["hb_close", 8.0], ["wait", 0.8], ["shot", "h11_ember_8m"],
			["hb_close", 25.0], ["wait", 0.8], ["shot", "h12_ember_25m"],
			["coop_signal", "host_far"], ["coop_wait_file", "client_drag_night"], ["wait", 0.3], ["shot", "h13_ember_25m_drag"],
			["eval", "_player.set('_flashlight_user_enabled', true)"], ["eval", "_player._refresh_flashlight_state()"],
			# A light for the other's cigarette from the host's.
			["hb_close", 1.2], ["wait", 0.6], ["key", "C"], ["wait", 1.4], ["keyhold", "C", true], ["wait", 1.4], ["keyhold", "C", false], ["wait", 1.5],
			["coop_signal", "host_lit_for_light"], ["coop_wait_file", "client_waits_light"], ["hb_close", 1.2], ["wait", 0.5],
			["keyhold", "C", true], ["wait", 0.6], ["shot", "h20_giving_light"], ["wait", 0.6], ["keyhold", "C", false],
			["coop_signal", "host_gave_light"], ["coop_wait_file", "client_got_light"], ["wait", 0.5],
			# One from the pack for the other: throw away the host's own first.
			["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 1.0],
			["hb_close", 1.2], ["wait", 0.5], ["keyhold", "C", true], ["wait", 0.7], ["shot", "h21_offer"], ["keyhold", "C", false], ["wait", 0.6],
			["coop_signal", "host_offered"], ["coop_wait_file", "client_offer_seen"],
			# Bottles: both open one, face to face, knock them.
			["key", "B"], ["wait", 0.8], ["keyhold", "B", true], ["wait", 1.6], ["keyhold", "B", false], ["wait", 3.0],
			["coop_signal", "host_bottle_open"], ["coop_wait_file", "client_bottle_open"],
			["hb_close", 1.1], ["wait", 0.6], ["key", "B"], ["wait", 0.15], ["shot", "h22_clink"], ["wait", 0.6],
			["coop_signal", "host_clinked"], ["coop_wait_file", "client_clink_seen"],
			# The host's bottle into the other's hand (theirs set down first).
			["coop_wait_file", "client_hand_free"], ["hb_close", 1.1], ["wait", 0.4], ["key", "X"], ["wait", 1.0], ["shot", "h23_handed"],
			["coop_signal", "host_handed"], ["coop_wait_file", "client_got_bottle"],
			["eval", P + ".debug_rects()"],
			["coop_signal", "host_day2_done"], ["wait", 3.0], ["coop_leave"], ["wait", 1.0],
		])
		_steps = s
	else:
		var c: Array = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]], ["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"],
			["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager.close_everything()"], ["wait", 1.0],
			["coop_place", 12, 16, -1.0], ["coop_wait", "partner_seen"]]
		c.append_array(common)
		c.append_array([
			["coop_face_partner"], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_watch"], ["coop_face_partner"],
			["key", "C"], ["wait", 0.35], ["coop_signal", "client_pack"], ["wait", 1.2],
			["keyhold", "C", true], ["wait", 0.3], ["coop_signal", "client_lighting"], ["wait", 1.4], ["keyhold", "C", false], ["wait", 1.2],
			["keyhold", "C", true], ["wait", 0.3], ["coop_signal", "client_dragging"], ["wait", 1.0], ["keyhold", "C", false], ["wait", 0.8],
			["coop_signal", "client_holding"], ["wait", 2.0],
			# Throw it, then a bottle: open it, drink, hold it.
			["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 1.0],
			["key", "B"], ["wait", 0.8], ["keyhold", "B", true], ["wait", 1.6], ["keyhold", "B", false], ["wait", 3.0],
			["keyhold", "B", true], ["wait", 0.4], ["coop_signal", "client_drinking"], ["wait", 1.0], ["keyhold", "B", false], ["wait", 0.6],
			["coop_signal", "client_bottle"], ["wait", 2.0],
			["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 1.0],
			# Night: light one and hold it for the host to see from afar, then a drag.
			["coop_wait_file", "host_night"], ["eval", INV + ".add_item('cigs')"],
			["key", "C"], ["wait", 1.4], ["keyhold", "C", true], ["wait", 1.4], ["keyhold", "C", false], ["wait", 1.4],
			["coop_signal", "client_lit_night"], ["coop_wait_file", "host_far"],
			["keyhold", "C", true], ["wait", 0.3], ["coop_signal", "client_drag_night"], ["wait", 1.0], ["keyhold", "C", false],
			["shot", "c13_host_far_away"],
			# Throw it; a new one in the mouth, no flame: wait for the host's light.
			["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 1.0],
			["eval", P + ".cig.set('debug_catch', false)"],
			["coop_wait_file", "host_lit_for_light"], ["coop_face_partner"],
			["key", "C"], ["wait", 1.4], ["coop_signal", "client_waits_light"], ["shot", "c19_waiting_light"],
			["coop_wait_file", "host_gave_light"], ["wait", 0.6], ["shot", "c20_got_light"],
			["eval", P + ".debug_rects()"], ["coop_signal", "client_got_light"],
			["keyhold", "X", true], ["wait", 0.6], ["keyhold", "X", false], ["wait", 1.0],
			["coop_wait_file", "host_offered"], ["eval", INV + ".items"], ["shot", "c21_offered"], ["coop_signal", "client_offer_seen"],
			# A bottle to knock against the host's.
			["key", "B"], ["wait", 0.8], ["keyhold", "B", true], ["wait", 1.6], ["keyhold", "B", false], ["wait", 3.0],
			["coop_face_partner"], ["coop_signal", "client_bottle_open"],
			["coop_wait_file", "host_clinked"], ["wait", 0.1], ["shot", "c22_clink"], ["coop_signal", "client_clink_seen"],
			["key", "X"], ["wait", 1.0], ["coop_face_partner"], ["coop_signal", "client_hand_free"],
			["coop_wait_file", "host_handed"], ["wait", 1.0], ["shot", "c23_got_bottle"], ["eval", P + ".debug_rects()"],
			["coop_signal", "client_got_bottle"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		])
		_steps = c


func _run_step(step: Array) -> void:
	match str(step[0]):
		"hb_close":
			# Stand `step[1]` m from the other warden, facing them.
			var fig: Node3D = Coop.remote_figure()
			var me: Node3D = _main.get("_player")
			if fig == null or me == null:
				print("HABITS COOP %s: no other warden" % _role)
				return
			var away := me.global_position - fig.global_position
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3(0, 0, 1)
			me.global_position = fig.global_position + away.normalized() * float(step[1]) + Vector3(0, 0.4, 0)
			var to := fig.global_position - me.global_position
			me.rotation.y = atan2(-to.x, -to.z)
			print("HABITS COOP %s %.1f m from the other" % [_role, float(step[1])])
		_:
			super._run_step(step)
