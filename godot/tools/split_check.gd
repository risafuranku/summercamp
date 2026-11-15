extends "res://tools/shot_driver.gd"

## The split screen (TODO.md SPLITSCREEN, scripts/seats/seats.gd), stage S3: two pads on
## one machine. Pad 0 is the window's warden's; pad 1's Menu out in the camp makes seat 2:
## its warden beside, the window split down the middle; each pad walks, turns and lights
## only its own warden; pad 1's Menu held leaves and the window is whole again. Prints
## "SPLIT ok|FAIL ..." and "SPLIT: PASS".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/split_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('SplitCheck')"

var _fails := 0
var _mark: Dictionary = {}


func _ready() -> void:
	super._ready()
	name = "SplitCheck"
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 6.0],
		["eval", "_interior_manager.close_everything(true)"], ["wait", 1.5],
		# Pad 0 touched: the window's warden has a pad.
		["pad_button", 0, JOY_BUTTON_X], ["wait", 0.5],
		["eval", C + ".check('one seat before', _seats.count() == 1)"],
		["pad_button", 1, JOY_BUTTON_START], ["wait", 1.5],
		["eval", C + ".check_joined()"], ["wait", 0.5], ["eval", C + ".check_huds()"], ["shot", "sp0_joined"],
		# Pad 1 walks its own warden only.
		["eval", C + ".mark()"], ["pad_axis", 1, JOY_AXIS_LEFT_Y, -1.0], ["wait", 1.0], ["pad_axis", 1, JOY_AXIS_LEFT_Y, 0.0], ["wait", 0.3],
		["eval", C + ".check_moved(2, true)"], ["eval", C + ".check_moved(1, false)"], ["shot", "sp1_two_walked"],
		# Pad 1 turns its own head only.
		["eval", C + ".mark()"], ["pad_axis", 1, JOY_AXIS_RIGHT_X, 1.0], ["wait", 0.5], ["pad_axis", 1, JOY_AXIS_RIGHT_X, 0.0], ["wait", 0.2],
		["eval", C + ".check_turned(2, true)"], ["eval", C + ".check_turned(1, false)"],
		# Pad 0 walks the window's warden only.
		["eval", C + ".mark()"], ["pad_axis", 0, JOY_AXIS_LEFT_Y, -1.0], ["wait", 1.0], ["pad_axis", 0, JOY_AXIS_LEFT_Y, 0.0], ["wait", 0.3],
		["eval", C + ".check_moved(1, true)"], ["eval", C + ".check_moved(2, false)"],
		# Y on pad 1: its torch, not yours.
		["eval", C + ".mark()"], ["pad_button", 1, JOY_BUTTON_Y], ["wait", 0.5],
		["eval", C + ".check_torch()"], ["shot", "sp2_torch"],
		# Each sees the other: the two a few steps apart, face to face.
		["eval", C + ".face_each_other()"], ["wait", 0.6], ["eval", C + ".check_figures()"], ["shot", "sp0b_facing"],
		# Menu held on pad 1: seat 2 leaves.
		["pad_button", 1, JOY_BUTTON_START, 2.0], ["wait", 2.6],
		["eval", C + ".check_left()"], ["shot", "sp3_left"],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]


func _run_step(step: Array) -> void:
	match str(step[0]):
		"pad_axis":
			var m := InputEventJoypadMotion.new()
			m.device = int(step[1])
			m.axis = int(step[2])
			m.axis_value = float(step[3])
			Input.parse_input_event(m)
		"pad_button":
			var b := InputEventJoypadButton.new()
			b.device = int(step[1])
			b.button_index = int(step[2])
			b.pressed = true
			Input.parse_input_event(b)
			get_tree().create_timer(float(step[3]) if step.size() > 3 else 0.15).timeout.connect(func() -> void:
				var up := b.duplicate() as InputEventJoypadButton
				up.pressed = false
				Input.parse_input_event(up))
		_:
			super._run_step(step)


func check(what: String, ok: bool) -> void:
	print("SPLIT %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _body(seat: int) -> Node3D:
	if seat == 1:
		return _main.get("_player")
	return _main.get("_seats").two.get("body")


func check_joined() -> void:
	var seats = _main.get("_seats")
	check("pad 1's Menu makes seat 2", seats.count() == 2)
	if seats.count() != 2:
		return
	var one := _main.get_node("Seat1") as Control
	var box: Control = seats.two["box"]
	var w := float(get_viewport().get_visible_rect().size.x)
	check("seat 1's screen the left half (%.0f of %.0f)" % [one.size.x, w], absf(one.size.x - w * 0.5) < 4.0)
	check("seat 2's screen the right half (at %.0f)" % box.position.x, absf(box.position.x - w * 0.5) < 4.0)
	var body: Node3D = seats.two["body"]
	_mark["start"] = _body(1).global_transform
	check("seat 2's warden beside (%.1f m)" % body.global_position.distance_to(_body(1).global_position), body.global_position.distance_to(_body(1).global_position) < 3.0)
	check("seat 2 sees through its own eye", (seats.two["eye"] as Camera3D).current)
	check("the window's warden keeps its eye", (_body(1).get_node("Head/Camera3D") as Camera3D).current)
	check("the pause menu stayed shut", _main.get("_pause_menu") == null or not _main.get("_pause_menu").is_open())


## Both wardens a few steps apart, each looking at the other.
func face_each_other() -> void:
	var b1 := _body(1)
	var b2 := _body(2)
	# Where warden 1 started (in front of the reception, open ground behind).
	var start: Transform3D = _mark["start"]
	b1.global_position = start.origin
	b2.global_position = start.origin + start.basis.z.normalized() * 4.0
	for pair in [[b1, b2], [b2, b1]]:
		var d: Vector3 = (pair[1] as Node3D).global_position - (pair[0] as Node3D).global_position
		(pair[0] as Node3D).rotation.y = atan2(-d.x, -d.z)


## Back to back (each walks away from the other: the two bodies bump).
func face_apart() -> void:
	_body(1).rotation.y += PI
	_body(2).rotation.y += PI


func check_figures() -> void:
	var figs: Array = _main.get("_seats").two.get("figs", [])
	check("two figures", figs.size() == 2)
	if figs.size() != 2:
		return
	for i in 2:
		var f: Node3D = figs[i]
		var b := _body(i + 1)
		check("warden %d's figure where they stand (%.2f m, shown %s)" % [i + 1, f.global_position.distance_to(b.global_position), f.visible], f.visible and f.global_position.distance_to(b.global_position) < 0.6)
	var cam1 := _body(1).get_node("Head/Camera3D") as Camera3D
	var eye2: Camera3D = _main.get("_seats").two["eye"]
	check("your eye leaves your figure out, sees seat 2's", (cam1.cull_mask & (1 << 10)) == 0 and (cam1.cull_mask & (1 << 12)) != 0)
	check("seat 2's eye leaves its figure out, sees yours", (eye2.cull_mask & (1 << 12)) == 0 and (eye2.cull_mask & (1 << 10)) != 0)


## Each seat's bar: its own HEALTH and STAMINA, the camp's cells once across the TV, and
## the whole of it inside its half.
func check_huds() -> void:
	var hud1 = _main.get("_hud_manager")
	var hud2 = _main.get("_seats").two.get("hud")
	check("seat 2 has its own HUD", hud2 != null and is_instance_valid(hud2))
	if hud2 == null:
		return
	for pair in [[hud1, ["health", "stamina", "cash", "clock"], 1], [hud2, ["health", "stamina", "guests", "mail", "risk"], 2]]:
		var cells: Dictionary = pair[0].get("_cells")
		var shown: Array = []
		var right := 0.0
		for id in cells:
			var c: Control = cells[id]
			if c.is_visible_in_tree():
				shown.append(id)
				right = maxf(right, c.get_global_rect().end.x)
		shown.sort()
		var want: Array = (pair[1] as Array).duplicate()
		want.sort()
		var w := float((pair[0] as Node).get_viewport().get_visible_rect().size.x)
		check("seat %d's bar: %s (its right end %.0f of %.0f)" % [pair[2], shown, right, w], shown == want and right <= w)


func mark() -> void:
	for s in [1, 2]:
		var b := _body(s)
		_mark[s] = [b.global_position, b.rotation.y, bool(b.get("torch_switch"))]


func check_moved(seat: int, should: bool) -> void:
	var d: float = ((_body(seat).global_position - (_mark[seat][0] as Vector3)) * Vector3(1, 0, 1)).length()
	check("warden %d %s (%.2f m)" % [seat, "walks" if should else "stays", d], (d > 1.0) if should else (d < 0.2))


func check_turned(seat: int, should: bool) -> void:
	var d := absf(wrapf(_body(seat).rotation.y - float(_mark[seat][1]), -PI, PI))
	check("warden %d %s (%.2f rad)" % [seat, "turns" if should else "keeps its head", d], (d > 0.3) if should else (d < 0.02))


func check_torch() -> void:
	check("pad 1's Y lights warden 2's torch", bool(_body(2).get("torch_switch")) != bool(_mark[2][2]))
	check("and not warden 1's", bool(_body(1).get("torch_switch")) == bool(_mark[1][2]))


func check_left() -> void:
	var seats = _main.get("_seats")
	check("pad 1's Menu held leaves", seats.count() == 1)
	var one := _main.get_node("Seat1") as Control
	check("the window whole again (%.0f)" % one.size.x, absf(one.size.x - float(get_viewport().get_visible_rect().size.x)) < 4.0)
	var cells: Dictionary = _main.get("_hud_manager").get("_cells")
	var n := 0
	for id in cells:
		if (cells[id] as Control).visible:
			n += 1
	check("your bar whole again (%d cells)" % n, n == cells.size())


func verdict() -> void:
	print("SPLIT: %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
