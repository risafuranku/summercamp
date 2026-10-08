extends Node3D

## Headless check that the night enemies keep their rules (DESIGN.md §5): every hit must
## be avoidable by doing what the tells say.
##
##   godot --headless --path godot res://tools/enemy_check.tscn
##
## A flat ground, a player body with a camera, a fake lamp field, and the real brains
## ticked at 30 Hz.

const SILENT := preload("res://scripts/enemies/silent_man_brain.gd")
const PHOTO := preload("res://scripts/enemies/tourist_brain.gd")


class FakeLamps:
	extends Node
	var lit_center := Vector3.INF
	var radius := 4.0

	func get_light_level_at(p: Vector3) -> float:
		if lit_center == Vector3.INF:
			return 0.0
		return 1.0 if Vector2(p.x - lit_center.x, p.z - lit_center.z).length() < radius else 0.0


var _failures: Array[String] = []
var _damage := 0
var _player: CharacterBody3D
var _camera: Camera3D
var _lamps := FakeLamps.new()


func _ready() -> void:
	_build_world()
	await get_tree().physics_frame
	await get_tree().physics_frame

	# ── Silent Man ──
	# Standing still in the dark, back turned: steps come closer, then the whisper, then
	# (only then) the hit.
	var s = _start(SILENT)
	var first_hit_at := -1.0
	var neck_seen := false
	for i in 30 * 60:
		s.tick(1.0 / 30.0)
		if s._neck_until > 0.0:
			neck_seen = true
		if _damage > 0 and first_hit_at < 0.0:
			first_hit_at = i / 30.0
			break
	print("ENEMY CHECK: silent man first hit at %.1f s, %s" % [first_hit_at, s.get_debug_snapshot()])
	_expect(first_hit_at > 6.0, "silent man: the first hit comes only after an audible approach (at %.1f s)" % first_hit_at)
	_expect(neck_seen, "silent man: a whisper at the neck precedes the hit")
	s.stop_night()

	# Turning round at the whisper drives him off: no damage, ever.
	_damage = 0
	s = _start(SILENT)
	for i in 30 * 90:
		s.tick(1.0 / 30.0)
		if s._neck_until > 0.0:
			_face(s._body.global_position)
		else:
			_face(_player.global_position + Vector3(0, 0, -10))
	print("ENEMY CHECK: silent man while turning round: dmg %d, %s" % [_damage, s.get_debug_snapshot()])
	_expect(_damage == 0, "silent man: turning round at the whisper always saves you (took %d)" % _damage)
	_expect(int(s.get_debug_snapshot()["driven_off"]) > 0, "silent man: and drives him off")
	s.stop_night()

	# Under a lamp he does not come nearer.
	_damage = 0
	_lamps.lit_center = _player.global_position
	s = _start(SILENT)
	for i in 30 * 60:
		s.tick(1.0 / 30.0)
	_expect(_damage == 0 and float(s.get_debug_snapshot()["distance"]) >= 13.9, "silent man: never approaches under a lamp (dist %s, dmg %d)" % [s.get_debug_snapshot()["distance"], _damage])
	_lamps.lit_center = Vector3.INF
	s.stop_night()

	# ── Photographer ──
	# Turning your back on every flash: never hurt.
	_damage = 0
	var p = _start(PHOTO)
	var min_frame := 99.0
	var frame_started := -1.0
	for i in 30 * 120:
		p.tick(1.0 / 30.0)
		var away: Vector3 = _player.global_position * 2.0 - p._body.global_position
		if p._phase == p.Phase.FRAME:
			if frame_started < 0.0:
				frame_started = i / 30.0
			# A careful player turns away during the frame.
			_face(away)
		else:
			if frame_started >= 0.0:
				min_frame = minf(min_frame, i / 30.0 - frame_started)
				frame_started = -1.0
			_face(p._body.global_position)
	print("ENEMY CHECK: photographer, careful player: dmg %d, min warning %.1f s, %s" % [_damage, min_frame, p.get_debug_snapshot()])
	_expect(_damage == 0, "photographer: turning away from every flash keeps you safe (took %d)" % _damage)
	_expect(int(p.get_debug_snapshot()["shots"]) >= 4, "photographer: he keeps shooting (%d shots)" % int(p.get_debug_snapshot()["shots"]))
	_expect(min_frame >= 2.0, "photographer: at least 2 s of warning before a flash (%.1f s)" % min_frame)
	p.stop_night()

	# Staring at him: hurt, but he backs off rather than chaining hits.
	_damage = 0
	p = _start(PHOTO)
	var hits_in_a_row := 0
	for i in 30 * 120:
		p.tick(1.0 / 30.0)
		_face(p._body.global_position)
	var snap: Dictionary = p.get_debug_snapshot()
	print("ENEMY CHECK: photographer, staring player: dmg %d, %s" % [_damage, snap])
	_expect(int(snap["hits"]) >= 1, "photographer: looking at the flash hurts")
	_expect(float(snap["distance"]) >= 8.0, "photographer: never ends up in your face (%.1f m)" % float(snap["distance"]))
	p.stop_night()

	print("")
	if _failures.is_empty():
		print("ENEMY CHECK: PASS")
		get_tree().quit(0)
	else:
		print("ENEMY CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _start(script: Script):
	var b = script.new()
	_player.global_position = Vector3(0, 0, 0)
	_face(Vector3(0, 0, -10))
	b.start_night(1234, 3, {
		"world_root": self,
		"player": _player,
		"building_manager": _lamps,
		"damage_callable": func(n): _damage += int(n),
		"is_night_callable": func(): return true,
		"allow_actions_callable": func(): return true,
		"notify_callable": func(_t): pass,
	})
	return b


func _face(target: Vector3) -> void:
	var to := target - _player.global_position
	_player.rotation.y = atan2(-to.x, -to.z)


func _build_world() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	ground.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	add_child(ground)
	add_child(_lamps)
	_player = CharacterBody3D.new()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	_player.add_child(col)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.6, 0)
	_player.add_child(head)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 70.0
	head.add_child(_camera)
	add_child(_player)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
