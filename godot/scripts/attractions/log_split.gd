extends Node

## Splitting logs for the fire at its chopping block (playtest 13. 11.: "the splitting is
## there, but I wanted it interactive, like serving"). E at the block with the axe in it
## (campfire.warden_offer "chop", warden_play) and you stand over it, the axe in your hands,
## a round of pine up on the block:
##   hold the left button   the axe goes up over your shoulder, higher the longer you hold
##   let go                 it comes down where you look (the crosshair on the round)
##     square and hard       the round bursts in two, the halves fly off either side, chips,
##                           a log onto the woodpile (campfire.split_one), the next round set up
##     off its middle        the blade glances off the edge: a chip, the round rocks, falls off
##                           the block and is set up again
##     too soft              the blade bites and sticks: the next swing lifts the round on it
##                           and slams it down, and that splits it if it goes up high enough
##   W A S D, the right button or Esc   you put the axe back in the block
## The pile full (campfire.WOODPILE_LOGS), the last round splits and you are done. Simple
## models of the game's own wood (the woodpile's bark and ends) and the block's axe in your
## hands; stepped like the fire (12 a second) where things fly. Co-op: each split goes
## through the host (warden_play: "chop").

const K = preload("res://scripts/interior_kit.gd")
const SPLIT_WOOD = preload("res://scripts/attractions/split_wood.gd")
const SFX := "res://assets/sfx/life/"
## The round: its radius and height on the block.
const ROUND_R := 0.12
const ROUND_H := 0.34
## How long a full raise takes; how strong a swing must be to split, to split from a stuck
## blade; how far off the middle (a share of the radius) still splits clean.
const RAISE_SEC := 0.62
const SPLIT_MIN := 0.38
const STUCK_MIN := 0.55
const SQUARE_K := 0.72
const SWING_SEC := 0.13
## Where you aim, at most this far off the round's middle on the block (m).
const AIM_R := 0.34
const NEXT_ROUND_SEC := 0.55
const EYE_BACK := 0.62
const EYE_UP := 1.12

var warden: Node
var _att: Node3D
var _cam: Camera3D
var _top := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _base := Basis()
var _eye := Vector3.ZERO
var _axe: Node3D
var _world_axe: Node3D
var _round: Node3D
var _round_mats: Array = []
var _bits: Array = []        # flying pieces: {node, v, w, t, land}
var _charge := 0.0
var _holding := false
var _swing_t := -1.0
var _swing_charge := 0.0
var _stuck := false
var _next_round_t := -1.0
var _rock_t := -1.0
var _shake := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func is_open() -> bool:
	return _att != null


## Over `att`'s block (the campfire's), the axe out of it into your hands.
func open(att: Node3D) -> bool:
	if att == null or not att.has_method("block_top"):
		return false
	_att = att
	_rng.randomize()
	_top = att.block_top()
	var p := _player()
	var from := (p.global_position - _top) if p != null else Vector3(0, 0, 1)
	from.y = 0.0
	from = from.normalized() if from.length() > 0.05 else Vector3(0, 0, 1)
	_eye = _top + from * EYE_BACK + Vector3(0, EYE_UP, 0)
	_base = Basis.looking_at((_top - _eye).normalized(), Vector3.UP)
	_yaw = 0.0
	_pitch = 0.0
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "LogSplitCam"
		_cam.fov = 60.0
		_cam.near = 0.04
		_cam.far = 1000.0
		_world().add_child(_cam)
	_cam.global_transform = Transform3D(_base, _eye)
	_cam.current = true
	_world_axe = att.get_parent().get_node_or_null("Axe") as Node3D
	if _world_axe != null:
		_world_axe.visible = false
	_round_mats = _wood_mats()
	_make_axe()
	_charge = 0.0
	_holding = false
	_swing_t = -1.0
	_stuck = false
	_set_round()
	if p != null and p.has_method("set_controls_enabled"):
		p.set_controls_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	return true


func close() -> void:
	if _att == null:
		return
	if _world_axe != null and is_instance_valid(_world_axe):
		_world_axe.visible = true
	for b in _bits:
		if is_instance_valid(b["node"]):
			(b["node"] as Node).queue_free()
	_bits.clear()
	if _round != null and is_instance_valid(_round):
		_round.queue_free()
	_round = null
	if _axe != null and is_instance_valid(_axe):
		_axe.queue_free()
	_axe = null
	if _cam != null:
		_cam.current = false
	var p := _player()
	if p != null and is_instance_valid(p):
		# Facing the way you looked.
		var f := -_cam.global_basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			p.rotation.y = atan2(-f.x, -f.z)
	_att = null
	var main = warden.get("main") if warden != null else null
	if main != null and main.has_method("_sync_active_camera"):
		main._sync_active_camera()


## Till your first swing in a session: what the button does here (then it is known).
static var _swung := false


func hint() -> String:
	return "" if _swung else "[LMB] Swing"


func _process(delta: float) -> void:
	if _att == null:
		return
	if not is_instance_valid(_att):
		close()
		return
	_t += delta
	if _holding:
		_charge = minf(1.0, _charge + delta / RAISE_SEC)
	if _swing_t >= 0.0:
		_swing_t += delta
		if _swing_t >= SWING_SEC:
			_swing_t = -1.0
			_land()
	if _next_round_t >= 0.0:
		_next_round_t -= delta
		if _next_round_t < 0.0:
			_set_round()
	_tick_rock(delta)
	_tick_bits(delta)
	_pose_axe()
	_shake = maxf(0.0, _shake - delta * 4.0)
	var jolt := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * 0.012 * _shake
	_cam.global_transform = Transform3D(_look_basis(), _eye + jolt)


func _input(event: InputEvent) -> void:
	if _att == null or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens := GameSettings.get_mouse_sensitivity() if GameSettings != null else 1.0
		_yaw -= event.relative.x * 0.0018 * sens
		_pitch -= event.relative.y * 0.0016 * sens
		_clamp_aim()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed:
			if _swing_t < 0.0 and _next_round_t < 0.0 and _rock_t < 0.0 and _round != null:
				_holding = true
				_charge = 0.0
		elif _holding:
			_holding = false
			_swing()
		return
	if (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT) or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		get_viewport().set_input_as_handled()
		close()


func _look_basis() -> Basis:
	return Basis(Vector3.UP, _yaw) * _base * Basis(Vector3.RIGHT, _pitch)


## Where the crosshair falls on the block's top plane (world).
func _aim_point() -> Vector3:
	var b := _look_basis()
	var dir := -b.z
	if absf(dir.y) < 0.05:
		return _top
	var k := (_top.y + 0.0 - _eye.y) / dir.y
	return _eye + dir * maxf(0.0, k)


## Not off the round's neighbourhood: the look held within AIM_R of its middle.
func _clamp_aim() -> void:
	for _i in 6:
		var a := _aim_point()
		var off := Vector2(a.x - _top.x, a.z - _top.z)
		if off.length() <= AIM_R:
			return
		_yaw *= 0.85
		_pitch *= 0.85


# ── the swing ────────────────────────────────────────────────────────────────

func _swing() -> void:
	_swung = true
	_swing_charge = _charge
	_swing_t = 0.0
	_play("split_whoosh.mp3", lerpf(-14.0, -6.0, _charge), _rng.randf_range(0.92, 1.06))


## The blade comes down: where, how hard.
func _land() -> void:
	if _round == null:
		return
	var at := _aim_point()
	var off := Vector2(at.x - _top.x, at.z - _top.z).length() / ROUND_R
	var hard := _swing_charge
	_charge = 0.0
	if _stuck:
		# Lifted on the blade and slammed down.
		if hard >= STUCK_MIN:
			_split(hard)
		else:
			_play("split_stick.mp3", -6.0, 0.85)
			_shake = 0.5
		return
	if off > 1.25:
		# Into the block beside it.
		_play("split_stick.mp3", -9.0, 1.1)
		_shake = 0.35
		return
	if off > SQUARE_K:
		_glance(at)
		return
	if hard < SPLIT_MIN:
		_bite = _strike_point()
		_stuck = true
		_play("split_stick.mp3", -4.0, _rng.randf_range(0.95, 1.05))
		_shake = 0.6
		return
	_split(hard)


func _split(hard: float) -> void:
	var was_stuck := _stuck
	_stuck = false
	_play("split_crack.mp3", lerpf(-6.0, 0.0, hard), lerpf(0.95, 1.12, hard) * _rng.randf_range(0.97, 1.03))
	_shake = 0.6 + hard * 0.6
	var side := (_look_basis().x * Vector3(1, 0, 1)).normalized()
	var r := _round
	_round = null
	if r != null and is_instance_valid(r):
		r.queue_free()
	var force := lerpf(1.6, 3.2, hard) * (0.8 if was_stuck else 1.0)
	for s in [-1.0, 1.0]:
		var half := _half_mesh(s)
		half.global_position = _top + Vector3(0, ROUND_H * 0.5, 0) + side * s * ROUND_R * 0.5
		half.global_basis = Basis(Vector3.UP, atan2(side.x, side.z) - PI * 0.5)
		_bits.append({"node": half, "v": side * s * force + Vector3(0, lerpf(1.2, 2.2, hard), 0), "w": Vector3(0, 0, -s * lerpf(6.0, 11.0, hard)), "t": 0.0, "land": false})
	for i in 4:
		_chip(_top + Vector3(0, ROUND_H, 0), hard)
	var full := false
	if _att.has_method("split_one"):
		full = _logs_full_after_split()
	_next_round_t = NEXT_ROUND_SEC if not full else -1.0
	if full:
		# The pile is full: the axe back in the block after a beat.
		get_tree().create_timer(1.2).timeout.connect(close)


func _logs_full_after_split() -> bool:
	if Coop.is_client():
		Coop.send_play("chop", [warden.att_id(_att)])
		return int(_att.get("logs_left")) + 1 >= int(_att.get("WOODPILE_LOGS"))
	if _att.split_one() and Coop.has_partner():
		Coop.send_play("chop", [warden.att_id(_att)])
	return int(_att.get("logs_left")) >= int(_att.get("WOODPILE_LOGS"))


## Off the edge: a chip off it, the round rocks and goes over off the block.
func _glance(at: Vector3) -> void:
	_play("split_stick.mp3", -10.0, 1.25)
	_chip(at + Vector3(0, ROUND_H, 0), 0.5)
	_shake = 0.3
	_rock_t = 0.0


func _tick_rock(delta: float) -> void:
	if _rock_t < 0.0 or _round == null:
		return
	_rock_t += delta
	var k := floorf(_rock_t * 12.0) / 12.0
	if k < 0.35:
		_round.rotation.z = sin(k * 30.0) * 0.12 * (1.0 - k / 0.35)
		return
	# Over and off.
	_round.rotation.z = minf(PI * 0.5, (k - 0.35) * 6.0)
	_round.global_position.y = _top.y - minf(0.42, maxf(0.0, (k - 0.5) * 2.4))
	if k >= 0.75:
		_round.queue_free()
		_round = null
		_rock_t = -1.0
		_next_round_t = NEXT_ROUND_SEC


func _set_round() -> void:
	if _att == null:
		return
	if int(_att.get("logs_left")) >= int(_att.get("WOODPILE_LOGS")):
		close()
		return
	_round = Node3D.new()
	_round.name = "SplitRound"
	_world().add_child(_round)
	_round.global_position = _top
	_round.rotation.y = _rng.randf() * TAU
	var c := CylinderMesh.new()
	c.top_radius = ROUND_R * _rng.randf_range(0.92, 1.05)
	c.bottom_radius = c.top_radius
	c.height = ROUND_H
	c.radial_segments = 10
	c.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = c
	m.position = Vector3(0, ROUND_H * 0.5, 0)
	m.material_override = _round_mats[0]
	_round.add_child(m)
	for y: float in [0.0, ROUND_H]:
		var e := CylinderMesh.new()
		e.top_radius = c.top_radius - 0.004
		e.bottom_radius = e.top_radius
		e.height = 0.006
		e.radial_segments = 10
		var em := MeshInstance3D.new()
		em.mesh = e
		em.position = Vector3(0, y + (0.002 if y > 0.0 else -0.002), 0)
		em.material_override = _round_mats[1]
		_round.add_child(em)
	_play("split_set.mp3", -8.0, _rng.randf_range(0.95, 1.05))


## Half a round, its flat face toward -X / +X (`s`): the woodpile's own piece (split_wood.gd).
func _half_mesh(s: float) -> Node3D:
	var n := SPLIT_WOOD.half(ROUND_R, ROUND_H, s, _round_mats[0], _round_mats[1])
	_world().add_child(n)
	return n


func _chip(at: Vector3, hard: float) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(_rng.randf_range(0.03, 0.07), 0.012, _rng.randf_range(0.015, 0.03))
	b.mesh = bm
	b.material_override = _round_mats[1]
	_world().add_child(b)
	b.global_position = at
	var ang := _rng.randf() * TAU
	_bits.append({"node": b, "v": Vector3(cos(ang), 0, sin(ang)) * _rng.randf_range(0.8, 2.0) * (0.6 + hard) + Vector3(0, _rng.randf_range(1.0, 2.6), 0),
		"w": Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12), 0), "t": 0.0, "land": false, "chip": true})


## The pieces in flight, in steps: up, over, down onto the grass, a moment there, gone.
func _tick_bits(delta: float) -> void:
	var ground := _top.y - 0.42
	for b in _bits:
		var n: Node3D = b["node"]
		if not is_instance_valid(n):
			continue
		b["t"] = float(b["t"]) + delta
		if not bool(b["land"]):
			b["v"] = (b["v"] as Vector3) + Vector3(0, -9.0, 0) * delta
			n.global_position += (b["v"] as Vector3) * delta
			n.rotation += (b["w"] as Vector3) * delta
			if n.global_position.y <= ground + 0.03:
				n.global_position.y = ground + 0.03
				b["land"] = true
				b["t"] = 0.0
				if not b.has("chip"):
					n.rotation = Vector3(0, n.rotation.y, PI * 0.5 * signf(n.rotation.z if absf(n.rotation.z) > 0.01 else 1.0))
					_play_at("split_land.mp3", n.global_position, -10.0, _rng.randf_range(0.9, 1.1))
	# Gone a while after landing (the split ones are on the pile already).
	for b in _bits.duplicate():
		if bool(b["land"]) and float(b["t"]) > (0.8 if b.has("chip") else 1.6):
			if is_instance_valid(b["node"]):
				(b["node"] as Node).queue_free()
			_bits.erase(b)


# ── the axe in your hands ────────────────────────────────────────────────────

func _make_axe() -> void:
	_axe = Node3D.new()
	_axe.name = "HeldAxe"
	_cam.add_child(_axe)
	var handle := K.slab(_axe, Vector3(0.036, 0.7, 0.03), Vector3(0, 0.35, 0), K.surface("veneer_dark", 0.4, Color(0.95, 0.8, 0.62)), "Handle")
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := K.slab(_axe, Vector3(0.05, 0.1, 0.17), Vector3(0, 0.68, 0.05), K.surface("galvanized", 0.25, Color(0.62, 0.62, 0.64)), "Head")
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var edge := K.slab(_axe, Vector3(0.052, 0.11, 0.025), Vector3(0, 0.68, 0.145), K.surface("galvanized", 0.25, Color(0.86, 0.86, 0.88)), "Edge")
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The axe's pose: at rest low at the right, its head in view, up over the shoulder with the
## hold, down with its edge where you aim in the swing (stuck: in the round, the round hanging
## on it as you lift it).
func _pose_axe() -> void:
	if _axe == null:
		return
	var rest := Transform3D(Basis.from_euler(Vector3(-0.6, -0.35, -0.5)), Vector3(0.3, -0.42, -0.5))
	var up := Transform3D(Basis.from_euler(Vector3(1.25, 0.15, 0.2)), Vector3(0.2, -0.28, -0.2))
	var down := _cam.global_transform.affine_inverse() * _edge_at(_strike_point())
	var xf: Transform3D
	if _swing_t >= 0.0:
		var k := clampf(_swing_t / SWING_SEC, 0.0, 1.0)
		xf = up.interpolate_with(down, k * k)
	elif _stuck:
		xf = down.interpolate_with(up, _charge * 0.85)
	else:
		var breathe := sin(_t * 1.6) * 0.01
		xf = rest.interpolate_with(up, _charge)
		xf.origin.y += breathe
	_axe.transform = xf
	if _round == null or _rock_t >= 0.0 or _next_round_t >= 0.0:
		return
	if _stuck:
		# On the blade: its top where the edge is.
		var head: Vector3 = _axe.global_transform * Vector3(0, HEAD_Y, 0.12)
		_round.global_position = head - Vector3(0, ROUND_H * 0.92, 0)
	else:
		_round.global_position = _top


## Where the edge comes down: on the round's top where you aim (the stuck blade stays where
## it bit).
var _bite := Vector3.ZERO


func _strike_point() -> Vector3:
	if _stuck:
		return _bite
	var a := _aim_point()
	return Vector3(a.x, _top.y + ROUND_H - 0.03, a.z)


## The axe placed with its edge at `p` (world): the handle back toward your hands, the edge
## down into it.
const HEAD_Y := 0.68


func _edge_at(p: Vector3) -> Transform3D:
	var grip := _cam.global_transform * Vector3(0.1, -0.42, -0.25)
	var y := (p - grip).normalized()
	var z := Vector3.DOWN - y * Vector3.DOWN.dot(y)
	z = z.normalized() if z.length() > 0.01 else -_cam.global_basis.z
	var x := y.cross(z).normalized()
	var origin := p - y * HEAD_Y - z * 0.13
	return Transform3D(Basis(x, y, z), origin)


# ── helpers ──────────────────────────────────────────────────────────────────

## The woodpile's own bark and ends (building_models._bonfire), else plain wood.
func _wood_mats() -> Array:
	var bark: Material = null
	var ends: Material = null
	var root := _att.get_parent()
	for c in root.get_children():
		if str(c.name).begins_with("PileLog"):
			var lg := c.find_child("Log", true, false) as MeshInstance3D
			var en := c.find_child("End", true, false) as MeshInstance3D
			if lg != null:
				bark = lg.material_override
			if en != null:
				ends = en.material_override
			break
	if bark == null:
		bark = K.surface("veneer_dark", 0.4, Color(0.5, 0.38, 0.26))
	if ends == null:
		ends = K.surface("veneer_dark", 0.2, Color(0.9, 0.78, 0.56))
	return [bark, ends]


func _play(file: String, db: float, pitch: float) -> void:
	_play_at(file, _top + Vector3(0, 0.4, 0), db, pitch)


func _play_at(file: String, at: Vector3, db: float, pitch: float) -> void:
	if not ResourceLoader.exists(SFX + file):
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = load(SFX + file)
	a.volume_db = db
	a.pitch_scale = pitch
	a.unit_size = 4.0
	a.max_distance = 30.0
	_world().add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)


func _world() -> Node:
	var main = warden.get("main") if warden != null else null
	var w = main.get("_world_3d") if main != null else null
	return w if w != null else (main if main != null else get_tree().current_scene)


func _player() -> Node3D:
	var main = warden.get("main") if warden != null else null
	return main.get("_player") as Node3D if main != null else null
