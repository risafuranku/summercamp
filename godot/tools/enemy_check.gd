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
const WHISTLER := preload("res://scripts/enemies/whistler_brain.gd")
const CHILD := preload("res://scripts/enemies/child_brain.gd")
const BASKET := preload("res://scripts/enemies/basket_brain.gd")
const GIRL := preload("res://scripts/enemies/girl_brain.gd")
const EYES := preload("res://scripts/enemies/enemy_eyes.gd")


class FakePlayer:
	extends CharacterBody3D
	var torch := false
	## The granny's cut ankle slows it (basket_brain.gd LIMP_MULT).
	var held_speed_mult := 1.0

	func is_flashlight_active() -> bool:
		return torch


class FakeLamps:
	extends Node
	var lit_center := Vector3.INF
	var radius := 4.0
	var darkened := 0

	func get_light_level_at(p: Vector3) -> float:
		if lit_center == Vector3.INF:
			return 0.0
		return 1.0 if Vector2(p.x - lit_center.x, p.z - lit_center.z).length() < radius else 0.0

	func lit_lamp_positions() -> Array:
		return [] if lit_center == Vector3.INF else [lit_center]

	func darken_lamp_near(p: Vector3, r: float, _seconds: float) -> Vector3:
		if lit_center == Vector3.INF or Vector2(p.x - lit_center.x, p.z - lit_center.z).length() > r:
			return Vector3.INF
		var at := lit_center
		lit_center = Vector3.INF
		darkened += 1
		return at


var _failures: Array[String] = []
var _damage := 0
var _player: CharacterBody3D
var _camera: Camera3D
var _lamps := FakeLamps.new()
## Read by the Basket Man (it walks only in the small hours).
var _time_of_day_hours := 3.5


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
	var max_press := 0.0
	var lesson_seen := false
	var lesson_hurt := false
	for i in 30 * 90:
		s.tick(1.0 / 30.0)
		max_press = maxf(max_press, float(s._press))
		if s._neck_until > 0.0:
			neck_seen = true
		if s._lesson:
			lesson_seen = true
			lesson_hurt = lesson_hurt or _damage > 0
		if _damage > 0 and first_hit_at < 0.0:
			first_hit_at = i / 30.0
			break
	print("ENEMY CHECK: silent man first hit at %.1f s, %s" % [first_hit_at, s.get_debug_snapshot()])
	_expect(first_hit_at > 6.0, "silent man: the first hit comes only after an audible approach (at %.1f s)" % first_hit_at)
	_expect(neck_seen, "silent man: a whisper at the neck precedes the hit")
	# The first meeting in a camp teaches: he turns you round to him and does not bite.
	_expect(lesson_seen and not lesson_hurt, "silent man: the first catch is the lesson, without a bite (seen %s, hurt %s)" % [lesson_seen, lesson_hurt])
	# Standing in the dark while he comes, you feel it build.
	_expect(max_press > 0.5, "silent man: the sixth sense builds in the dark (max %.2f)" % max_press)
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

	# ── The Girl ──
	# Keeping her in the torch: she holds, however long, and no eyes but hers.
	_damage = 0
	(_player as FakePlayer).torch = true
	var g = _start(GIRL)
	var eyes_max := 0
	for i in 30 * 90:
		if g._body.visible:
			_face(g._body.global_position + Vector3(0, 1.4, 0))
		g.tick(1.0 / 30.0)
		eyes_max = maxi(eyes_max, g._root.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == g.ENEMY_EYES).size())
	print("ENEMY CHECK: girl, kept in the torch: dmg %d, phase %d, dist %.1f, eyes %d" % [_damage, g._phase, g._distance_to_player(g._body.global_position), eyes_max])
	_expect(_damage == 0, "girl: holding her in the torch keeps you safe (took %d)" % _damage)
	_expect(eyes_max <= 1, "girl: the only eyes out there are hers (%d pairs)" % eyes_max)
	g.stop_night()
	# Back to her, torch off: she comes, strikes; after it the view is straight again,
	# you can move, she is gone for a while.
	_damage = 0
	(_player as FakePlayer).torch = false
	g = _start(GIRL)
	var struck := false
	var after_ok := false
	for i in 30 * 150:
		if g._body.visible and g._phase != 2:
			_face(_player.global_position * 2.0 - g._body.global_position)
		g.tick(1.0 / 30.0)
		if g._phase == 2:
			struck = true
		elif struck:
			after_ok = absf(_camera.rotation.z) < 0.01 and absf(_camera.rotation.x) < 0.01 and g._phase == 3
			break
	print("ENEMY CHECK: girl, back turned: dmg %d, struck %s, after %s, cam %s" % [_damage, struck, after_ok, _camera.rotation])
	_expect(struck and _damage > 0, "girl: turning your back on her in the dark gets you caught (took %d)" % _damage)
	_expect(after_ok, "girl: after her strike the view is level again and she is gone")
	g.stop_night()
	_camera.rotation = Vector3.ZERO
	# Under a lamp: never hurt; she goes round the edge of its light to your back, herself.
	_damage = 0
	_lamps.lit_center = _player.global_position
	g = _start(GIRL)
	var went_round := false
	for i in 30 * 40:
		g.tick(1.0 / 30.0)
		went_round = went_round or g._round_done
	print("ENEMY CHECK: girl, under a lamp: dmg %d, went round %s" % [_damage, went_round])
	_expect(_damage == 0, "girl: under a lamp you are safe (took %d)" % _damage)
	_expect(went_round, "girl: under a lamp she goes round to your back")
	g.stop_night()
	_lamps.lit_center = Vector3.INF
	# Nothing of hers stays in the world after the night.
	await get_tree().process_frame
	var left := 0
	for n in find_children("*", "Node3D", true, false):
		if n.get_script() == EYES:
			left += 1
	_expect(left == 0, "girl: no eyes left in the world after the night (%d)" % left)

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

	# ── Whistler ──
	# Walking towards the tune in the dark: it takes you.
	_damage = 0
	var w = _start(WHISTLER)
	for i in 30 * 90:
		w.tick(1.0 / 30.0)
		if w._source != Vector3.INF:
			var to: Vector3 = w._source - _player.global_position
			to.y = 0.0
			if to.length() > 0.5:
				_player.global_position += to.normalized() * 2.5 / 30.0
	print("ENEMY CHECK: whistler, following the tune: dmg %d" % _damage)
	_expect(_damage > 0, "whistler: following the whistling into the dark hurts")
	w.stop_night()
	# Standing still (or under a lamp): never hurt.
	for lit in [false, true]:
		_damage = 0
		_lamps.lit_center = Vector3.ZERO if lit else Vector3.INF
		w = _start(WHISTLER)
		for i in 30 * 120:
			w.tick(1.0 / 30.0)
		print("ENEMY CHECK: whistler, staying put (lamp %s): dmg %d" % [lit, _damage])
		_expect(_damage == 0, "whistler: not going to it keeps you safe (lamp %s, took %d)" % [lit, _damage])
		w.stop_night()
	_lamps.lit_center = Vector3.INF

	# ── Extra Child ──
	# Torch on it: it runs at you. Torch off, looking at it: nothing happens.
	for torch in [true, false]:
		_damage = 0
		var fp := _player as FakePlayer
		fp.torch = torch
		var c = _start(CHILD)
		for i in 30 * 30:
			c.tick(1.0 / 30.0)
			if c._body.visible:
				_face(c._body.global_position)
		print("ENEMY CHECK: child, torch %s: dmg %d" % [torch, _damage])
		if torch:
			_expect(_damage > 0, "child: shining the torch on it makes it come for you")
		else:
			_expect(_damage == 0, "child: torch off, it leaves you alone (took %d)" % _damage)
		c.stop_night()
	(_player as FakePlayer).torch = false

	# ── The mushroom granny (reworked 2. 11.) ──
	# She always comes: stand still in the dark and she is on you.
	_damage = 0
	var bk = _start(BASKET)
	bk.soon = true
	var caught_at := -1.0
	for i in 30 * 30:
		bk.tick(1.0 / 30.0)
		if _damage > 0 and caught_at < 0.0:
			caught_at = float(i) / 30.0
	print("ENEMY CHECK: granny, standing still: dmg %d at %.1f s, limp %.2f" % [_damage, caught_at, (_player as FakePlayer).held_speed_mult])
	_expect(_damage > 0, "granny: standing still in the dark she gets you")
	# (No limp after her any more, the user 4. 11., W29.)
	_expect(is_equal_approx((_player as FakePlayer).held_speed_mult, 1.0), "granny: her catch leaves you limping (W29: it must not)")
	bk.stop_night()
	(_player as FakePlayer).held_speed_mult = 1.0
	# Walk away from her, and freeze while she stands up and looks: she never gets you.
	# Walk on while she looks and she comes at a run.
	for freeze in [true, false]:
		_damage = 0
		bk = _start(BASKET)
		bk.soon = true
		# Out, and near: she sees you move from here.
		bk.tick(1.0 / 30.0)
		bk._body.global_position = Vector3(0, 0, -12)
		var lunged := false
		var away := Vector3(0, 0, 1)
		for i in 30 * 40:
			var looking: bool = str(bk._phase) in ["look", "stare"]
			lunged = lunged or str(bk._phase) == "lunge"
			if not (freeze and looking) and str(bk._phase) != "away":
				var her: Vector3 = bk._body.global_position
				away = (_player.global_position - her)
				away.y = 0.0
				away = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
				_player.global_position += away * 3.9 / 30.0
			bk.tick(1.0 / 30.0)
		print("ENEMY CHECK: granny, walking away, freezing %s: dmg %d, lunged %s" % [freeze, _damage, lunged])
		if freeze:
			_expect(_damage == 0, "granny: walking on and freezing when she looks keeps you safe (took %d)" % _damage)
		else:
			_expect(lunged, "granny: moving while she looks brings her at a run")
		bk.stop_night()
	# In a lamp's light: she never steps in, she reaches up and puts it out, then comes.
	_damage = 0
	_lamps.lit_center = Vector3(0, 0, 0)
	_lamps.darkened = 0
	bk = _start(BASKET)
	bk.soon = true
	var stepped_in := false
	var dmg_lit := 0
	for i in 30 * 40:
		bk.tick(1.0 / 30.0)
		if _lamps.lit_center != Vector3.INF:
			dmg_lit = _damage
			var b: Vector3 = bk._body.global_position
			if bk._body.visible and Vector2(b.x, b.z).length() < _lamps.radius - 0.3:
				stepped_in = true
	print("ENEMY CHECK: granny, under a lamp: in the light %s, lamps out %d, dmg in light %d, after %d" % [stepped_in, _lamps.darkened, dmg_lit, _damage])
	_expect(not stepped_in, "granny: she never steps into a lamp's light")
	_expect(dmg_lit == 0, "granny: under a lit lamp she cannot cut you")
	_expect(_lamps.darkened >= 1, "granny: she puts out the lamp you stand under")
	_expect(_damage > 0, "granny: once the lamp is out and you stay, she gets you")
	bk.stop_night()
	_lamps.lit_center = Vector3.INF
	(_player as FakePlayer).held_speed_mult = 1.0

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
	box.size = Vector3(600, 1, 600)
	shape.shape = box
	ground.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	add_child(ground)
	add_child(_lamps)
	_player = FakePlayer.new()
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
