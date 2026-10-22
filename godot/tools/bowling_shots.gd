extends "res://tools/shot_driver.gd"

## The bowling alley (scripts/bowling/): the hall with guests in, the shoe counter and the
## pit worked where they stand, the lanes bowling. Debug tooling only.
##   godot --path godot res://tools/bowling_shots.tscn -- --out=<dir> [--size=1280x720]

const BI := "_interior_manager._bowling_interior"
const BW := "get_tree().get_first_node_in_group('bowlings')"


func _st(id: String) -> String:
	return BI + "._stations['%s']" % id


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
		["money", 40000], ["clear", 4, 4, 16, 12], ["build", "bowling", 6, 5, 0],
		["build", "cabin_1", 5, 12, 0], ["build", "cabin_1", 9, 12, 0], ["build", "tent_1", 13, 12, 0], ["build", "tent_1", 15, 12, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["prep_all"], ["book", "Kaja", "cheap_chick", 1, 3], ["prep_all"], ["book", "Bobr", "tramp", 1, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 4.0],
		["eval", "debug_send_guests_to('bowling', 240)"], ["wait", 1.0],
		["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('bowling'))"], ["wait", 3.0],
		["n_state"], ["shot", "b01_desk"],
		["eval", _st("desk") + ".debug_serve_right()"], ["wait", 0.5], ["shot", "b02_desk_served"],
		["eval", _st("desk") + ".debug_click('cubby:47')"], ["wait", 0.5], ["shot", "b03_desk_wrong"],
		["eval", _st("desk") + ".debug_click('slot:0')"], ["wait", 0.3],
		["desk_all"], ["wait", 1.0], ["shot", "b04_desk_empty"], ["n_state"],
		["eval", BI + "._switch_station('pit_a')"], ["wait", 1.5], ["shot", "b05_pit"],
		["until", BW + ".pins_waiting(" + BI + ".key, 0) or " + BW + ".pins_waiting(" + BI + ".key, 1)", 40.0], ["wait", 0.4],
		["n_state"], ["shot", "b06_pit_waiting"],
		["pit_step"], ["wait", 0.3], ["shot", "b07_pit_hand"],
		["pit_finish"], ["wait", 0.6], ["shot", "b08_pit_done"],
		["until", "(" + BW + ".lane(" + BI + ".key, 0)['set'] == 'rack' and " + BW + ".pins_waiting(" + BI + ".key, 0)) or (" + BW + ".lane(" + BI + ".key, 1)['set'] == 'rack' and " + BW + ".pins_waiting(" + BI + ".key, 1))", 45.0],
		["wait", 0.3], ["n_state"], ["shot", "b08a_pit_rack"],
		["pit_step"], ["wait", 0.4], ["shot", "b08b_pit_rack_hand"],
		["pit_finish"], ["wait", 0.6], ["shot", "b08c_pit_rack_done"],
		["eval", _st("pit_a") + ".close_station()"], ["wait", 1.2], ["shot", "b09_hall"],
		["eval", BI + "._go('lane0')"], ["wait", 3.0], ["shot", "b10_lane0"],
		["wait", 2.5], ["shot", "b11_lane0_later"],
		["eval", BI + "._interior_camera.set('position', Vector3(-1.71, 2.25, 3.2))"], ["wait", 0.3], ["shot", "b11b_boards"],
		["eval", BI + "._go('hall')"], ["wait", 1.0],
		["eval", BI + "._open_station('pit_b')"], ["wait", 6.0], ["shot", "b12_pit_b"], ["n_state"],
	]


## The lanes of the pit open now that wait for their pins (the record's index).
func _waiting(st: Node) -> Array:
	var out: Array = []
	var bw := get_tree().get_first_node_in_group("bowlings")
	var key := str(st.get("building_key"))
	for v in st.get("lanes"):
		var li := int(v.get("index"))
		if bw.pins_waiting(key, li):
			out.append(li)
	return out


## The hall (bowling_interior.gd), null before the camp is up.
func _bi() -> Node:
	var im = _main.get("_interior_manager") if _main != null and is_instance_valid(_main) else null
	return im.get("_bowling_interior") if im != null else null


func _run_step(step: Array) -> void:
	if not (str(step[0]) in ["n_state", "desk_all", "pit_step", "pit_finish"]):
		super._run_step(step)
		return
	var bi = _bi()
	if bi == null:
		print("BOWL SHOTS: no hall")
		return
	match str(step[0]):
		"n_state":
			var bw := get_tree().get_first_node_in_group("bowlings")
			if bw == null or bi == null:
				print("BOWL SHOTS: no bowling")
				return
			var s: Dictionary = bw.site(str(bi.key))
			print("BOWL SHOTS: desk %s" % [(s["desk"] as Array).map(func(d): return "%s %s" % [d["visit"], d["sizes"]])])
			print("BOWL SHOTS: checked %s back %s" % [s["checked"].keys(), s["back"]])
			for i in 4:
				var l: Dictionary = s["lanes"][i]
				print("BOWL SHOTS: lane%d %s set=%s wait=%.1f seq=%d up=%d" % [i, l["name"], l["set"], float(l["wait"]), int(l["seq"]), (l["standing"] as Array).count(true)])
				var board: Label3D = bi._lanes[i].get("_board")
				print("BOWL SHOTS:   board %s at %s vis %s" % [JSON.stringify(board.text), board.global_position, board.is_visible_in_tree()])
		"desk_all":
			var desk = bi._stations["desk"]
			var n := 0
			while not (desk.call("first") as Dictionary).is_empty() and n < 8:
				desk.call("debug_serve_right")
				n += 1
			print("BOWL SHOTS: served %d at the counter" % n)
		"pit_step":
			# The ball back and one pin taken into the hand (or the first deadwood off).
			var pit = bi._stations["pit_a"]
			var w := _waiting(pit)
			if w.is_empty():
				print("BOWL SHOTS: nothing waits in the pit")
				return
			var li: int = w[0]
			var v = pit.call("_view_of", li)
			if v.ball_in_pit():
				pit.call("_press", "ball:%d" % li)
			for k in 10:
				if v.pin_where(k) in ["deck", "pit"]:
					pit.call("_press", "pin:%d:%d" % [li, k])
					break
			print("BOWL SHOTS: pit lane%d %s" % [li, str(get_tree().get_first_node_in_group("bowlings").lane(str(bi.key), li)["set"])])
		"pit_finish":
			var pit2 = bi._stations["pit_a"]
			for li in _waiting(pit2):
				print("BOWL SHOTS: pit lane%d done in %d clicks" % [li, int(pit2.call("debug_work", li))])
				# A pin in the hand from the step before: onto the first empty spot.
				var v2 = pit2.call("_view_of", li)
				for s in 10:
					if v2.spot_taken(s) < 0 and not (pit2.get("_carry") as Array).is_empty():
						pit2.call("_press", "spot:%d:%d" % [li, s])
				pit2.call("debug_work", li)
