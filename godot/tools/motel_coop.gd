extends "res://tools/coop_check.gd"

## Liblice for two (motel_view.gd, chapel_view.gd, town_trip.gd): a host and a joining copy.
## First both go into the Jednota, the pub and the kiosk in turn (jednota_view.gd,
## pub_view.gd, kiosk_view.gd) and each sees the other standing there.
## In the chapel the host lights two candles and the other sees them burn; in the evening
## both take number four (the host's key, then the spare), the host lies down, the other
## sees him in the second bed, lies down too; a knock wakes both in the night (the host's
## night stops, the other's with it), both lie down again and wake in the room in the
## morning. Each side prints what it sees, tagged
## ["MOTEL <role> <tag>", hour, place, figures seen, sleepers, flames, key] for
## tools/motel_coop.py, and takes a picture.
##   godot --path godot res://tools/motel_coop.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"
const TT := "_interior_manager.town_trip()"


func _ready() -> void:
	super._ready()
	var into_town := [
		["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0],
		["eval", TT + "._ensure_town()"], ["wait", 2.0],
		["eval", TT + "._put_player(" + TT + "._town.arrive_spot())"], ["wait", 2.0],
	]
	var take_four := [
		["eval", TT + "._open_room('motel')"], ["wait", 1.5], ["eval", TT + "._room._clicked('desk')"], ["wait", 1.0],
		["eval", TT + "._room.close()"], ["wait", 1.0],
		["eval", TT + "._motel_door(4)"], ["wait", 2.5],
	]
	# The shops: the host goes in first, the other follows, both look, both come out.
	var shops := []
	for p in ["jednota", "pub", "kiosk"]:
		if _role == "host":
			shops.append_array([
				["eval", TT + "._open_room('" + p + "')"], ["wait", 2.0], ["coop_signal", "host_" + p], ["coop_wait_file", "client_" + p],
				["wait", 2.0], ["motel_see", p + "_mate"], ["shot", "host_" + p],
				["coop_signal", "host_saw_" + p], ["coop_wait_file", "client_saw_" + p],
				["eval", TT + "._room.close()"], ["wait", 1.0],
			])
		else:
			shops.append_array([
				["coop_wait_file", "host_" + p], ["eval", TT + "._open_room('" + p + "')"], ["wait", 2.0], ["coop_signal", "client_" + p],
				["coop_wait_file", "host_saw_" + p], ["wait", 0.5], ["motel_see", p + "_mate"], ["shot", "client_" + p],
				["coop_signal", "client_saw_" + p], ["eval", TT + "._room.close()"], ["wait", 1.0],
			])
	if _role == "host":
		_steps = [["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "debug_jump_to(1, 10.0)"]]
		_steps.append_array(into_town)
		_steps.append_array([["coop_signal", "host_up"], ["coop_wait_file", "client_in_town"]])
		_steps.append_array(shops)
		_steps.append_array([
			["eval", TT + "._open_room('chapel')"], ["wait", 2.0], ["coop_signal", "host_chapel"], ["coop_wait_file", "client_chapel"],
			["eval", TT + "._room._clicked('candles')"], ["wait", 3.0], ["eval", TT + "._room._clicked('candles')"], ["wait", 1.5],
			["motel_see", "candles_lit"], ["coop_signal", "host_lit"], ["coop_wait_file", "client_saw_candles"],
			["eval", TT + "._room.close()"], ["wait", 1.0],
			["eval", "debug_jump_to(1, 19.6)"], ["wait", 2.0],
		])
		_steps.append_array(take_four)
		_steps.append_array([
			["coop_signal", "host_in4"], ["coop_wait_file", "client_in4"], ["wait", 2.5],
			["motel_see", "mate_in_room"], ["shot", "host_mate"],
			# Something wakes them in the night (motel_night.gd: here the first step, a knock).
			["eval", TT + ".set('debug_force_wake', 'knock')"],
			["eval", TT + "._room._clicked('bed')"], ["wait", 2.5], ["motel_see", "lying_alone"], ["shot", "host_lying"],
			["coop_signal", "host_bed"],
			["coop_wait_file", "client_bed"], ["wait", 7.0], ["motel_see", "woken"], ["shot", "host_woken"],
			["coop_signal", "host_woken"], ["coop_wait_file", "client_woken"],
			["eval", TT + ".set('debug_quiet', true)"], ["eval", TT + "._room._clicked('bed')"], ["wait", 1.0], ["coop_signal", "host_bed2"],
			["coop_wait", "morning"], ["wait", 1.5], ["motel_see", "morning"], ["shot", "host_morning"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		])
	else:
		_steps = [["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0]]
		_steps.append_array(into_town)
		_steps.append_array([["coop_signal", "client_in_town"]])
		_steps.append_array(shops)
		_steps.append_array([
			["coop_wait_file", "host_chapel"],
			["eval", TT + "._open_room('chapel')"], ["wait", 2.0], ["coop_signal", "client_chapel"],
			["coop_wait_file", "host_lit"], ["wait", 2.5],
			["eval", TT + "._room.set('_base_rot', Vector3(-0.17, -1.66, 0))"], ["wait", 0.8],
			["motel_see", "candles"], ["shot", "client_candles"], ["coop_signal", "client_saw_candles"],
			["eval", TT + "._room.close()"], ["wait", 1.0],
			["coop_wait_file", "host_in4"], ["wait", 2.0],
		])
		_steps.append_array(take_four)
		_steps.append_array([
			["coop_signal", "client_in4"], ["coop_wait_file", "host_bed"], ["wait", 3.0],
			["eval", TT + "._room.set('_base_rot', Vector3(-0.3, 3.0, 0))"], ["wait", 0.8],
			["motel_see", "mate_asleep"], ["shot", "client_mate_asleep"],
			["eval", TT + "._room._clicked('bed')"], ["wait", 2.0], ["coop_signal", "client_bed"],
			["coop_wait_file", "host_woken"], ["wait", 1.0], ["motel_see", "woken"], ["shot", "client_woken"], ["coop_signal", "client_woken"],
			["coop_wait_file", "host_bed2"], ["eval", TT + "._room._clicked('bed')"], ["wait", 1.0],
			["coop_wait", "morning"], ["wait", 1.5], ["motel_see", "morning"], ["shot", "client_morning"],
			["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		])


func _run_step(step: Array) -> void:
	match str(step[0]):
		"motel_see":
			var trip = _main._interior_manager.town_trip()
			var room = trip.get("_room")
			var place := ""
			var figs := 0
			var sleepers := 0
			var flames := 0
			if room != null and room.is_open():
				place = str(room.place)
				for f in (room.get("_mates") as Dictionary).values():
					if f != null and is_instance_valid(f) and f.visible:
						figs += 1
				var v = room.get("_view")
				if v != null:
					if v.get("_sleepers") != null:
						sleepers = (v.get("_sleepers") as Dictionary).size()
					if v.get("flames") != null:
						flames = (v.get("flames") as Array).size()
			var key: bool = trip._has_motel_key()
			var ev := ""
			if room != null and room.is_open() and room.get("_view") != null and room.get("_view").get("event") != null:
				ev = str(room.get("_view").get("event"))
			print("MOTEL_TAG [\"MOTEL %s %s\", %.2f, \"%s\", %d, %d, %d, %s, \"%s\"]" % [_role, str(step[1]), float(_main.get("_time_of_day_hours")), place, figs, sleepers, flames, str(key).to_lower(), ev])
		_:
			super._run_step(step)
