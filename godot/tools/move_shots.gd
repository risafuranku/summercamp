extends "res://tools/shot_driver.gd"

## The body in the world (DESIGN §9c, TODO "POHYB, KAMERA, INTERAKCE"): measures and
## pictures of how you move, look and touch things. The numbers go to <out>/measure.json
## and the log as "MOVE MEASURE ..." lines; the pictures as PNGs.
##   godot --path godot --resolution 1280x720 res://tools/move_shots.tscn -- --out=<dir> [--part=measure|shots|all]
##
## measure: from rest to full speed and from full speed to a stop when the key is let go
## (time and metres), turning back (W to S), sprinting the same, how far the eye looks up
## and down (degrees of the camera itself), the FOV; frames a second in the full test camp
## in the evening (the businesses' camp: ~40 guests) and among the forest's trees.

var _part := "all"
var _free_cabin := Vector2i(-1, -1)
var _results: Dictionary = {}


func _ready() -> void:
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--part="):
			_part = arg.get_slice("=", 1)
	var s: Array = [
		["wait_menu"], ["call", "_start_test_businesses", []], ["wait_gameplay"], ["wait", 3.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["wait", 2.0],
	]
	if _part in ["measure", "all"]:
		s.append_array([
			["open_ground"], ["wait", 1.0],
			["measure_move", "walk"], ["measure_move", "sprint"], ["measure_turn"],
			["measure_look"],
			["eval", "debug_jump_to(1, 19.6)"], ["wait", 4.0], ["to_camp_middle"], ["wait", 2.0],
			["measure_fps", "camp_evening", 6.0],
			["to_forest"], ["wait", 2.0], ["measure_fps", "forest", 6.0],
			["save_measure"],
		])
	if _part in ["shots", "all"]:
		s.append_array([
			["eval", "debug_jump_to(1, 11.0)"], ["wait", 2.0], ["open_ground"], ["wait", 1.0],
			["shot", "s0_level"],
			["look", -90.0], ["wait", 0.8], ["shot", "s1_down"],
			["look", 90.0], ["wait", 0.8], ["shot", "s2_up"],
			["look", 0.0], ["wait", 0.6],
			# Away and stop: a run of frames as the key goes and as it is let go.
			["press", "move_forward"],
		])
		s.append_array(_burst("s3_start", 5, 0.08))
		s.append_array([["wait", 0.8], ["release", "move_forward"]])
		s.append_array(_burst("s4_stop", 6, 0.08))
		s.append_array([
			["to_forest"], ["wait", 1.5], ["shot", "s5_forest"], ["look", 70.0], ["wait", 0.8], ["shot", "s6_crowns"], ["look", 0.0],
			["press", "move_forward"], ["wait", 1.2], ["shot", "s7_forest_walk"], ["release", "move_forward"],
			["open_ground"], ["wait", 1.0], ["press", "move_forward"], ["wait", 1.0], ["shot", "s8_meadow_walk"], ["release", "move_forward"],
			["look", -60.0], ["wait", 0.6], ["press", "move_forward"], ["wait", 0.6], ["shot", "s9_meadow_feet"], ["release", "move_forward"], ["look", 0.0],
			["free_cabin"], ["wait", 2.0], ["to_cabin_door"], ["wait", 1.0], ["shot", "sa_cabin"], ["key", "E"],
		])
		s.append_array(_burst("sb_enter", 10, 0.08))
		s.append_array([["wait", 1.0], ["shot", "sc_inside"]])
	if _part in ["body", "all"]:
		s.append_array([
			# Out of any room the shots before left open (the pause menu's Go outside).
			["eval", "_on_pause_leave_requested()"], ["wait", 1.5],
			["eval", "debug_jump_to(1, 11.0)"], ["wait", 2.0], ["open_ground"], ["wait", 1.0],
			# Your boots: standing, then walking (a frame per footstep), the grass round them.
			["look", -75.0], ["wait", 0.8], ["shot", "b0_feet"],
			["press", "move_forward"],
		])
		s.append_array(_burst("b1_feet_walk", 6, 0.1))
		s.append_array([["release", "move_forward"], ["look", -30.0], ["wait", 0.5],
			# Crouched, then on your belly crawling.
			["stance", 1], ["wait", 0.8], ["shot", "b2_crouch"], ["stance", 2], ["wait", 0.8], ["look", 0.0], ["wait", 0.3], ["shot", "b3_prone"],
			["press", "move_forward"]])
		s.append_array(_burst("b4_crawl", 5, 0.15))
		s.append_array([["release", "move_forward"], ["stance", 0], ["wait", 0.8],
			# A bottle by the fire: picked up, thrown.
			["to_prop", "can"], ["wait", 1.0], ["key", "E"], ["wait", 0.6], ["shot", "b4c_can_held"], ["key", "E"], ["wait", 0.6],
			["to_prop", "bottle"], ["wait", 1.0], ["shot", "b5_bottle_aim"], ["eval", "_hud_manager.get('_hint_text')"], ["key", "E"], ["wait", 0.6], ["shot", "b6_bottle_held"],
			["look", 10.0], ["wait", 0.3], ["click"]])
		s.append_array(_burst("b7_throw", 6, 0.08))
		s.append_array([["wait", 1.5], ["shot", "b8_landed"],
			# Into the lake's shallows.
			["to_lake"], ["wait", 1.0], ["look", -45.0], ["press", "move_forward"]])
		s.append_array(_burst("b9_wade", 6, 0.12))
		s.append_array([["release", "move_forward"], ["look", 0.0],
			# Options: View and body.
			["key", "Escape"], ["wait", 0.6], ["eval", "_pause_menu._show('options')"], ["wait", 0.4], ["shot", "ba_config"],
			["eval", "_pause_menu._options.set('section', 'body')"], ["eval", "_pause_menu._options.build()"], ["wait", 0.4], ["shot", "bb_body_options"],
			["key", "Escape"], ["wait", 0.3], ["key", "Escape"], ["wait", 0.3], ["key", "Escape"], ["wait", 0.5],
		])
	_steps = s


func _burst(name: String, n: int, dt: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(["shot", "%s_%d" % [name, i]])
		out.append(["wait", dt])
	return out


func _player() -> CharacterBody3D:
	return _main.get("_player") as CharacterBody3D


func _run_step(step: Array) -> void:
	match str(step[0]):
		"press":
			Input.action_press(str(step[1]))
		"release":
			Input.action_release(str(step[1]))
		"look":
			# The eye to `deg` (up +), within the controller's own limits.
			var p := _player()
			if p != null:
				var lim: Vector2 = _look_limits(p)
				p.set("_pitch_target", clampf(deg_to_rad(float(step[1])), -lim.x, lim.y))
		"open_ground":
			_put_on_open_ground()
		"to_forest":
			_put_in_forest()
		"to_camp_middle":
			_put_mid_camp()
		"to_cabin_door":
			_put_at_cabin()
		"stance":
			var pl := _player()
			if pl != null:
				pl.call("set_stance", int(step[1]))
		"click":
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			Input.parse_input_event(ev)
			var ev2 := InputEventMouseButton.new()
			ev2.button_index = MOUSE_BUTTON_LEFT
			ev2.pressed = false
			Input.parse_input_event(ev2)
		"to_prop":
			# Two steps from a small thing of that kind, looking at it.
			var carry := get_tree().get_first_node_in_group("carry")
			var nudge = carry.get("nudge") if carry != null else null
			if nudge != null:
				for pr in nudge.props_near(Vector3.ZERO, 9999.0):
					if str(pr["kind"]) == str(step[1]):
						var at: Vector3 = pr["pos"]
						var from := at + Vector3(1.4, 0.0, 0.0)
						_put(from - Vector3(0, 0.35, 0), PI * 0.5)
						var cam := _player().get_node("Head/Camera3D") as Camera3D
						var lim: Vector2 = _look_limits(_player())
						var down := atan2(1.2, 1.4)
						_player().set("_pitch_target", -down)
						_player().set("_pitch", -down)
						break
		"to_lake":
			var lake := _main.find_child("CampLake", true, false)
			if lake != null:
				var spots: Array = lake.duck_spots()
				if not spots.is_empty():
					var at: Vector3 = spots[0]
					_put(Vector3(at.x, 0.0, at.z - 1.0), PI)
		"free_cabin":
			# An empty cabin of our own by the open ground (the test camp's are let).
			var wg = _main.get("world_generator")
			var g: Vector2i = wg.gate_tile() if wg != null else Vector2i(12, 0)
			EventBus.RequestDemolish.emit(Rect2i(g.x + 8, 2, 5, 5))
			EventBus.RequestBuild.emit("cabin_1", Vector2i(g.x + 9, 3), 0)
			_free_cabin = Vector2i(g.x + 9, 3)
		"measure_move":
			_wait_left = 999.0
			_measure_move(str(step[1]))
		"measure_turn":
			_wait_left = 999.0
			_measure_turn()
		"measure_look":
			_wait_left = 999.0
			_measure_look()
		"measure_fps":
			_wait_left = 999.0
			_measure_fps(str(step[1]), float(step[2]))
		"save_measure":
			var f := FileAccess.open(_out_dir.path_join("measure.json"), FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(_results, "\t"))
			print("MOVE MEASURE ALL %s" % JSON.stringify(_results))
		_:
			super._run_step(step)


## Up (y) and down (x) limits in radians, as the controller has them.
func _look_limits(p: Node) -> Vector2:
	if p.has_method("look_limits"):
		return p.call("look_limits")
	return Vector2(deg_to_rad(float(p.get("look_down_limit_degrees"))), deg_to_rad(float(p.get("vertical_look_limit_degrees"))))


func _speed(p: CharacterBody3D) -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _measure_move(kind: String) -> void:
	var p := _player()
	_put_on_open_ground()
	for i in 20:
		await get_tree().physics_frame
	if kind == "sprint":
		Input.action_press("move_sprint")
	Input.action_press("move_forward")
	var t := 0.0
	var start_pos := p.global_position
	var top := float(p.get("sprint_speed") if kind == "sprint" else p.get("move_speed"))
	var t95 := -1.0
	var d95 := 0.0
	while t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t95 < 0.0 and _speed(p) >= top * 0.95:
			t95 = t
			d95 = Vector2(p.global_position.x - start_pos.x, p.global_position.z - start_pos.z).length()
	var v_held := _speed(p)
	Input.action_release("move_forward")
	Input.action_release("move_sprint")
	var at := p.global_position
	var ts := 0.0
	while _speed(p) > 0.05 and ts < 3.0:
		await get_tree().physics_frame
		ts += get_physics_process_delta_time()
	var dist := Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
	_results[kind] = {"top_speed": snappedf(v_held, 0.01), "to_95pct_s": snappedf(t95, 0.01), "to_95pct_m": snappedf(d95, 0.01), "stop_s": snappedf(ts, 0.01), "stop_m": snappedf(dist, 0.01)}
	print("MOVE MEASURE %s %s" % [kind, JSON.stringify(_results[kind])])
	_wait_left = 0.5


## Full speed forwards, then the back key: how long until you go the other way at speed.
func _measure_turn() -> void:
	var p := _player()
	_put_on_open_ground()
	for i in 20:
		await get_tree().physics_frame
	Input.action_press("move_forward")
	for i in 90:
		await get_tree().physics_frame
	var fwd := -p.global_basis.z
	Input.action_release("move_forward")
	Input.action_press("move_backward")
	var t := 0.0
	var t95 := -1.0
	var top := float(p.get("move_speed"))
	while t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var along := Vector3(p.velocity.x, 0, p.velocity.z).dot(fwd)
		if t95 < 0.0 and along <= -top * 0.95:
			t95 = t
	Input.action_release("move_backward")
	_results["reverse"] = {"to_95pct_s": snappedf(t95, 0.01)}
	print("MOVE MEASURE reverse %s" % JSON.stringify(_results["reverse"]))
	_wait_left = 0.5


func _measure_look() -> void:
	var p := _player()
	var cam := p.get_node("Head/Camera3D") as Camera3D
	var lim := _look_limits(p)
	var out := {}
	for dir in ["up", "down"]:
		p.set("_pitch_target", lim.y if dir == "up" else -lim.x)
		for i in 60:
			await get_tree().physics_frame
		out[dir + "_limit_deg"] = snappedf(rad_to_deg(lim.y if dir == "up" else lim.x), 0.1)
		# The middle of the picture: the eye's turn and Build's shift of the picture.
		out[dir + "_eye_deg"] = snappedf(absf(rad_to_deg(cam.global_rotation.x + float(p.get("_shift") if p.get("_shift") != null else 0.0))), 0.1)
		out[dir + "_turn_deg"] = snappedf(absf(rad_to_deg(cam.global_rotation.x)), 0.1)
	p.set("_pitch_target", 0.0)
	for i in 30:
		await get_tree().physics_frame
	out["fov_deg"] = snappedf(cam.fov, 0.1)
	_results["look"] = out
	print("MOVE MEASURE look %s" % JSON.stringify(out))
	_wait_left = 0.2


func _measure_fps(label: String, seconds: float) -> void:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	var p := _player()
	# Walk about while it counts (a still camera hides the cost of what moves past).
	Input.action_press("move_forward")
	while float(Time.get_ticks_usec() - t0) / 1e6 < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
		if frames % 40 == 0 and p != null:
			p.rotate_y(0.9)
	Input.action_release("move_forward")
	var secs := float(Time.get_ticks_usec() - t0) / 1e6
	var guests := 0
	var ga = _main.get("_guest_agents")
	if ga != null and ga.get("_parties") != null:
		for party in (ga.get("_parties") as Dictionary).values():
			guests += (party.get("members", []) as Array).size()
	_results["fps_" + label] = {"fps": snappedf(frames / secs, 0.1), "worst_frame_ms": snappedf(worst, 0.1), "guests": guests, "size": str(get_viewport().get_visible_rect().size)}
	print("MOVE MEASURE fps_%s %s" % [label, JSON.stringify(_results["fps_" + label])])
	_wait_left = 0.2


# ── places ────────────────────────────────────────────────────────────────────

func _put(at: Vector3, yaw: float) -> void:
	var p := _player()
	if p == null:
		return
	p.global_position = at + Vector3.UP * 0.2
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO
	p.set("_pitch_target", 0.0)


## A piece of meadow with nothing in front: east of the gate's path, looking north.
func _put_on_open_ground() -> void:
	var wg = _main.get("world_generator")
	var g: Vector2i = wg.gate_tile() if wg != null else Vector2i(12, 0)
	var gm = _main.get("grid_manager")
	var at := Vector3(float(g.x) * 1.4 + 4.0, 0.0, 2.0)
	if gm != null and gm.has_method("grid_to_world"):
		at = gm.grid_to_world(Vector2i(g.x + 10, 16))
	_put(Vector3(at.x, 0.0, at.z), 0.0)


func _put_mid_camp() -> void:
	var wg = _main.get("world_generator")
	var g: Vector2i = wg.gate_tile() if wg != null else Vector2i(12, 0)
	var gm = _main.get("grid_manager")
	if gm != null and gm.has_method("grid_to_world"):
		var at: Vector3 = gm.grid_to_world(Vector2i(g.x, 10))
		_put(Vector3(at.x, 0.0, at.z), PI)


## Among the trees of the forest round the camp: the tree furthest from the camp's middle
## that still has five others within eight metres.
func _put_in_forest() -> void:
	var trees := get_tree().get_nodes_in_group("trees")
	var best: Node3D = null
	var best_d := -1.0
	var mid := Vector3.ZERO
	for t in trees:
		if not (t is Node3D) or (t as Node).is_in_group("corn"):
			continue
		var tp := (t as Node3D).global_position
		var d := Vector2(tp.x, tp.z).length()
		if d < best_d or d > 140.0:
			continue
		var near := 0
		for u in trees:
			if u != t and u is Node3D and not (u as Node).is_in_group("corn") and (u as Node3D).global_position.distance_to(tp) < 8.0:
				near += 1
				if near >= 5:
					break
		if near >= 5:
			best = t
			best_d = d
	if best != null:
		var tp := best.global_position
		var out := Vector3(tp.x, 0, tp.z).normalized()
		_put(tp - out * 1.5 + Vector3(0.9, 0, 0), atan2(out.x, out.z))


func _put_at_cabin() -> void:
	var bm = _main.get("building_manager")
	var root: Node = bm.get_node_or_null("Structures") if bm != null else null
	if root == null:
		return
	for c in root.get_children():
		if c is Node3D and str(c.get_meta("building_type", "")).begins_with("cabin") and (_free_cabin.x < 0 or c.get_meta("grid_origin", Vector2i(-9, -9)) == _free_cabin):
			var way: Dictionary = load("res://scripts/attractions/door_anim.gd").entry_points(c, 0)
			if way.is_empty():
				continue
			var outside: Vector3 = way["outside"]
			var inside: Vector3 = way["inside"]
			var dir := (inside - outside)
			dir.y = 0.0
			dir = dir.normalized()
			_put(outside - dir * 1.2, atan2(-dir.x, -dir.z))
			return
