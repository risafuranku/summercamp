extends SceneTree

## Things moving in steps (scripts/ambient/step_motion.gd; the user 5. 11.): a hanging sign
## swings from its top edge, a loose door is still in a calm and knocked about in a gale (its
## heart with it), a flap goes through its poses, a kick runs out and leaves it where it
## was, something moved by hand is where it stays, nothing far from the eye moves, and it all
## goes twelve steps a second at most.
##   godot --headless --path godot --audio-driver Dummy --script res://tools/steps_check.gd

const SM = preload("res://scripts/ambient/step_motion.gd")

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("  ", "ok   " if ok else "FAIL ", what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("steps_check")
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	var sign := Node3D.new()
	sign.position = Vector3(0, 2.7, -5)
	world.add_child(sign)
	var door := Node3D.new()
	door.position = Vector3(2, 1, -5)
	world.add_child(door)
	var heart := Node3D.new()
	heart.position = Vector3(2, 1.6, -4.99)
	world.add_child(heart)
	var flap := Node3D.new()
	flap.position = Vector3(-2, 0, -5)
	world.add_child(flap)
	var far := Node3D.new()
	far.position = Vector3(0, 0, -400)
	world.add_child(far)
	await process_frame
	SM.attach(sign, "swing", Vector3.RIGHT, 0.3, {"pivot": Vector3(0, 0.8, 0)})
	SM.attach(door, "rattle", Vector3.UP, 0.01, {"shift": Vector3(0, 0, 0.007), "from": 0.8, "with": [heart]})
	SM.attach(flap, "flap", Vector3.RIGHT, 0.1)
	SM.attach(far, "swing", Vector3.RIGHT, 0.3)
	await process_frame
	var sm = root.get_node_or_null(SM.NODE_NAME)
	_check(sm != null, "one node for the world")
	if sm == null:
		_done()
		return
	var door0: Transform3D = door.transform
	var heart0: Transform3D = heart.transform
	var sign_top := sign.global_transform * Vector3(0, 0.8, 0)
	# A still day.
	sm.debug_wind = 0.15
	var moved_door := false
	var sign_moved := false
	for i in 40:
		await create_timer(1.0 / 12.0).timeout
		moved_door = moved_door or not door.transform.is_equal_approx(door0)
		sign_moved = sign_moved or not sign.transform.basis.is_equal_approx(Basis())
	_check(not moved_door, "a still day: the door quiet in its frame")
	_check(sign_moved, "a still day: the sign never quite still")
	_check((sign.global_transform * Vector3(0, 0.8, 0)).distance_to(sign_top) < 0.001, "the sign hangs from its top edge (it does not move)")
	# A gale.
	sm.debug_wind = 1.6
	var door_moves := 0
	var heart_with := true
	var max_sign := 0.0
	var poses := {}
	var changes := 0
	var last := Transform3D()
	var t0 := Time.get_ticks_msec()
	var frames := 0
	for i in 120:
		await process_frame
		frames += 1
		if not door.transform.is_equal_approx(door0):
			door_moves += 1
			# The heart cut in it goes with it.
			var d := door.transform * door0.affine_inverse()
			heart_with = heart_with and (d * heart0).is_equal_approx(heart.transform)
		max_sign = maxf(max_sign, absf(sign.rotation.x))
		poses[snappedf(flap.rotation.x, 0.001)] = true
		if not sign.transform.is_equal_approx(last):
			changes += 1
			last = sign.transform
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	_check(door_moves > 0, "a gale: the door knocked about in its frame (%d frames of %d)" % [door_moves, frames])
	_check(heart_with, "and the heart cut in it with it")
	_check(max_sign > 0.12, "the sign swings far in a gale (%.2f rad)" % max_sign)
	_check(poses.size() >= 2 and poses.size() <= 4, "the flap goes through its poses (%d)" % poses.size())
	_check(float(changes) / maxf(secs, 0.01) <= 13.5, "in steps: the sign moved %.1f times a second" % (float(changes) / maxf(secs, 0.01)))
	_check(far.transform.basis.is_equal_approx(Basis()), "nothing far from the eye moves")
	# Opened by hand: that is where it is now.
	sm.debug_wind = 0.15
	await create_timer(0.6).timeout
	door.rotation.y = 1.2
	var opened: Transform3D = door.transform
	await create_timer(0.5).timeout
	_check(door.transform.is_equal_approx(opened), "opened by hand it stays open")
	# A kick: a bounce, and back where it was.
	var arm := Node3D.new()
	world.add_child(arm)
	arm.position = Vector3(0, 1, -6)
	await process_frame
	SM.kick(arm, Vector3(0, 0, 1), [0.05, 0.0, 0.02, 0.0])
	var peak := 0.0
	for i in 20:
		await create_timer(1.0 / 12.0).timeout
		peak = maxf(peak, arm.rotation.z)
	_check(peak > 0.04 and absf(arm.rotation.z) < 0.0001, "a kick bounces it and leaves it as it was (peak %.3f)" % peak)
	# The Karosa's dials: their needles real (the picture has none painted any more).
	var CAB = load("res://scripts/town/karosa_cab.gd")
	var cab_root := Node3D.new()
	world.add_child(cab_root)
	var cab: Dictionary = CAB.build(cab_root, 0.0, {})
	var nd: Array = cab.get("needles", [])
	_check(nd.size() == 2, "the dash has its two needles")
	if nd.size() == 2:
		CAB.set_needles(nd, 0.0, 0.0)
		var rest := (nd[0] as Node3D).rotation.z
		CAB.set_needles(nd, 50.0 / 3.6, 0.0)
		_check(absf(rest - deg_to_rad(220.0)) < 0.06 and absf((nd[0] as Node3D).rotation.z - PI * 0.5) < 0.06, "the speed needle: at rest on nought, straight up at 50 km/h (%.2f, %.2f rad)" % [rest, (nd[0] as Node3D).rotation.z])
		_check(absf(fmod((nd[0] as Node3D).rotation.z, deg_to_rad(3.0))) < 0.001 or absf(fmod((nd[0] as Node3D).rotation.z, deg_to_rad(3.0)) - deg_to_rad(3.0)) < 0.001, "in whole steps of the scale")
	var img := (load("res://assets/textury/town/karosa_dash.png") as Texture2D).get_image()
	var red := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.7 and c.g < 0.5 and c.b < 0.3 and y > 20 and y < 50 and x > 80 and x < 145:
				red += 1
	_check(red == 0, "no needles painted on the dials (%d red pixels)" % red)
	_done()


func _done() -> void:
	print("steps_check: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails > 0 else 0)
