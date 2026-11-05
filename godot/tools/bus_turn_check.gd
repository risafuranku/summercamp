extends SceneTree

## How the 380 takes a bend (scripts/town/bus_line.gd pose_at; the user 5. 11.: "it turns
## about its own middle, buses do not work like that"): on a lane with a right-angle bend,
## its front axle keeps to the lane, the back axle cuts the bend inside, on the straights its
## middle is where it always was, and it turns smoothly. Writes the poses for a drawing.
##   godot --headless --path godot --script res://tools/bus_turn_check.gd -- [--out=<json>]

const LINE = preload("res://scripts/town/bus_line.gd")

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("  ", "ok   " if ok else "FAIL ", what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("bus_turn_check")
	var l = LINE.new()
	# 60 m north (-z), a quarter circle of 14 m turning right (east, +x), 60 m east.
	var pts := PackedVector3Array()
	for i in 61:
		pts.append(Vector3(0, 0, -float(i)))
	for k in range(1, 31):
		var a := float(k) / 30.0 * PI * 0.5
		pts.append(Vector3(14.0 - 14.0 * cos(a), 0, -60.0 - 14.0 * sin(a)))
	for i in range(1, 61):
		pts.append(Vector3(14.0 + float(i), 0, -74.0))
	l.pts = pts
	l.along.resize(pts.size())
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		l.along[i] = acc
	l._build_rear()
	var total: float = l.length()
	# On the straight before the bend its middle is on the lane where it was.
	var xf: Transform3D = l.pose_at(30.0)
	_check(xf.origin.distance_to(l.point_at(30.0)) < 0.05 and (-xf.basis.z).distance_to(Vector3(0, 0, -1)) < 0.01, "on a straight: its middle on the lane, facing along it")
	var front_off := 0.0
	var rear_in := 0.0
	var mid_in := 0.0
	var max_turn := 0.0
	var prev_yaw := INF
	var poses: Array = []
	var s := 40.0
	while s < total - 10.0:
		var t: Transform3D = l.pose_at(s)
		var fwd := -t.basis.z
		var front := t.origin + fwd * LINE.FRONT_AXLE
		var rear := t.origin - fwd * (LINE.WHEELBASE - LINE.FRONT_AXLE)
		front_off = maxf(front_off, _off_lane(front))
		# Inside the bend: nearer its centre (14, -60) than the lane's 14 m.
		if s > 62.0 and s < 95.0:
			rear_in = maxf(rear_in, 14.0 - Vector2(rear.x - 14.0, rear.z + 60.0).length())
			mid_in = maxf(mid_in, 14.0 - Vector2(t.origin.x - 14.0, t.origin.z + 60.0).length())
		var yaw := atan2(-fwd.x, -fwd.z)
		if prev_yaw != INF:
			max_turn = maxf(max_turn, absf(wrapf(yaw - prev_yaw, -PI, PI)) / 0.25)
		prev_yaw = yaw
		poses.append([s, t.origin.x, t.origin.z, fwd.x, fwd.z])
		s += 0.25
	_check(front_off < 0.15, "its front axle keeps to the lane through the bend (off by %.2f m at most)" % front_off)
	_check(rear_in > 0.6, "its back axle cuts the bend inside (%.2f m in)" % rear_in)
	_check(mid_in > 0.2, "its middle is not on the lane in the bend: it does not turn about it (%.2f m in)" % mid_in)
	_check(max_turn < 1.0 / 14.0 * 1.6, "it turns smoothly (at most %.3f rad a metre, the bend's %.3f)" % [max_turn, 1.0 / 14.0])
	var after: Transform3D = l.pose_at(total - 20.0)
	_check((-after.basis.z).distance_to(Vector3(1, 0, 0)) < 0.02, "straight again after the bend, facing along the lane")
	_check(l.steer_at(75.0) < -0.2 and absf(l.steer_at(30.0)) < 0.01, "its front wheels turned into the bend (%.2f rad, right is -), straight on the straight" % l.steer_at(75.0))
	# A stop just past the bend (as the camp's shelter is): it pulls in straight, no snap.
	var l2 = LINE.new()
	l2.pts = l.pts
	l2.along = l.along
	l2.stop_at = {"start": 0.0, "kerb": 92.0, "end": total}
	l2._build_rear()
	var at_kerb: Transform3D = l2.pose_at(92.0)
	var lane_dir: Vector3 = (l2.point_at(95.0) - l2.point_at(89.0)).normalized()
	var askew := rad_to_deg((-at_kerb.basis.z).angle_to(lane_dir))
	var jerk := 0.0
	var py := INF
	var q := 70.0
	while q <= 110.0:
		var f2 := -(l2.pose_at(q) as Transform3D).basis.z
		var y2 := atan2(-f2.x, -f2.z)
		if py != INF:
			jerk = maxf(jerk, rad_to_deg(absf(wrapf(y2 - py, -PI, PI))))
		py = y2
		q += 0.25
	_check(askew < 1.0, "a stop just past the bend: it stands straight at the kerb (%.2f deg askew)" % askew)
	_check(jerk < 2.5, "and straightens without a snap (at most %.2f deg a quarter metre)" % jerk)
	# The bus itself in a bend, twelve steps a second: his wheel goes round, the body leans
	# out of the bend; back straight, both come back.
	var bus = load("res://scripts/town/bus_model.gd").new()
	root.add_child(bus)
	await process_frame
	var wheel: Node3D = bus.get("_steer_wheel")
	var flat: Basis = wheel.basis if wheel != null else Basis()
	bus.set_speed(10.0)
	bus.set_steer(0.3)
	await create_timer(1.2).timeout
	_check(wheel != null and absf(float(bus.steer_shown()) - 0.3) < 0.01 and not wheel.basis.is_equal_approx(flat), "in a left bend his wheel goes round (%.2f rad of 0.30 after 1.2 s)" % float(bus.steer_shown()))
	_check(float(bus.lean()) > 0.02 and absf(float(bus.get("_body").rotation.z) + float(bus.lean())) < 0.01, "and the body leans out of it (%.3f rad, to the right)" % float(bus.lean()))
	bus.set_steer(0.0)
	await create_timer(1.2).timeout
	_check(absf(float(bus.steer_shown())) < 0.01 and absf(float(bus.lean())) < 0.002, "straight again: the wheel back, upright")
	bus.queue_free()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"lane": _lane_xy(pts), "poses": poses}))
	print("bus_turn_check: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails > 0 else 0)


func _off_lane(p: Vector3) -> float:
	if p.z > -60.0:
		return absf(p.x)
	if p.x > 14.0:
		return absf(p.z + 74.0)
	return absf(Vector2(p.x - 14.0, p.z + 60.0).length() - 14.0)


func _lane_xy(pts: PackedVector3Array) -> Array:
	var out: Array = []
	for p in pts:
		out.append([p.x, p.z])
	return out
