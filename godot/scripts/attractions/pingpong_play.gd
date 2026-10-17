extends Node3D

## The ping-pong table in use (building_models._pingpong): two players at the ends hit
## the ball across: off the bat, one bounce on the far half, onto the other bat, and back
## (tok, tik, tok). Now and then a miss: the ball bounces off the end and the one who
## missed fetches it, then serves. One player alone bounces the ball on the bat; the
## rest stand at the side and wait their turn. Stepped at 12 frames a second.

const POSES = preload("res://scripts/attractions/poses.gd")
const FPS := 12.0
const SFX_TOK := "res://assets/sfx/life/ball_kick.mp3"
const END_X := 1.62
const BAT_Y := 0.98
const MISS_CHANCE := 0.12

var guests_here := 0

var _slot_of: Dictionary = {}
var _seen: Dictionary = {}
var _clock := 0.0
var _acc := 0.0
var _ball: MeshInstance3D
var _bats: Array = []
var _top := 0.76
## The ball's flight: from, to, apex height, start time, duration, kind ("hit", "bounce",
## "miss", "fetch", "solo", "rest"), who hit it (slot) and who it goes to.
var _shot := {"kind": "rest", "from": Vector3.ZERO, "to": Vector3.ZERO, "apex": 0.0, "t0": 0.0, "dur": 1.0, "to_slot": 0}
var _hit_at: Dictionary = {}      # slot -> clock of their last hit (the swing of the arm)
var _audio: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("attraction")
	_rng.randomize()
	call_deferred("_setup")


func _setup() -> void:
	var r := get_parent()
	_ball = r.get_node_or_null("Ball") as MeshInstance3D
	for i in 2:
		var b := r.get_node_or_null("Bat%d" % i) as Node3D
		if b != null:
			_bats.append(b)
	_top = float(r.get_meta("table_top", 0.76))
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 4.0
	_audio.max_distance = 25.0
	add_child(_audio)


func covers_tile(tile: Vector2i) -> bool:
	var r: Node = get_parent()
	while r != null and not r.has_meta("grid_origin"):
		r = r.get_parent()
	if r == null:
		return false
	var o: Vector2i = r.get_meta("grid_origin")
	var fp_any = r.get_meta("grid_footprint", Vector2i.ONE)
	var fp: Vector2i = fp_any if fp_any is Vector2i else Vector2i.ONE
	return tile.x >= o.x and tile.y >= o.y and tile.x < o.x + fp.x and tile.y < o.y + fp.y


func pose_member(guest_id: int, i: int, _n: int, member: Node3D, sprite: Sprite3D, info: Dictionary, _t: float) -> bool:
	var key := guest_id * 10 + i
	if not _slot_of.has(key):
		var taken := _slot_of.values()
		var slot := 0
		while taken.has(slot):
			slot += 1
		_slot_of[key] = slot
	_seen[key] = _clock
	var slot_now := int(_slot_of[key])
	var parent := get_parent() as Node3D
	var at := Vector3.ZERO
	if slot_now < 2:
		var side := -1.0 if slot_now == 0 else 1.0
		at = Vector3(side * (END_X + 0.25), 0, 0.0)
		# Chasing the ball after a miss: the fetcher goes to it and comes back.
		if str(_shot["kind"]) == "fetch" and int(_shot["to_slot"]) == slot_now:
			var k := clampf((_clock - float(_shot["t0"])) / float(_shot["dur"]), 0.0, 1.0)
			var lost: Vector3 = _shot["from"]
			lost.y = 0.0
			at = at.lerp(lost, k * 2.0) if k < 0.5 else lost.lerp(at, (k - 0.5) * 2.0)
		var since := _clock - float(_hit_at.get(slot_now, -9.0))
		if since < 0.2:
			at.y += sin(since / 0.2 * PI) * 0.04
	else:
		var k2 := slot_now - 2
		at = Vector3(-0.6 + float(k2) * 0.6, 0, 1.15)
	member.global_position = parent.to_global(at)
	member.set_meta("marker_drop", 0.0)
	POSES.set_pose(sprite, str(info.get("sprite_path", "")), "")
	if sprite != null:
		sprite.flip_h = slot_now == 1
		sprite.rotation.z = 0.0
	return true


func _occupied(slot: int) -> bool:
	return _slot_of.values().has(slot)


func _process(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	for key in _seen.keys():
		if _clock - float(_seen[key]) > 1.0:
			_seen.erase(key)
			_slot_of.erase(key)
	guests_here = _seen.size()
	_play()
	if _ball != null:
		_ball.position = _ball_pos()
	# The bats are in the players' hands while they play, on the table when not.
	for i in _bats.size():
		var b := _bats[i] as Node3D
		var side := -1.0 if i == 0 else 1.0
		if _occupied(i):
			b.position = Vector3(side * (END_X - 0.05), BAT_Y - 0.05, 0.12)
			b.rotation = Vector3(PI * 0.5, 0, side * 0.3)
		else:
			b.position = Vector3(side * 0.9, _top + 0.01, 0.4 * side)
			b.rotation = Vector3.ZERO


func _ball_pos() -> Vector3:
	var kind := str(_shot["kind"])
	if kind == "rest":
		return Vector3(0.3, _top + 0.025, 0.1)
	var k := clampf((_clock - float(_shot["t0"])) / maxf(0.01, float(_shot["dur"])), 0.0, 1.0)
	var a: Vector3 = _shot["from"]
	var b: Vector3 = _shot["to"]
	var p := a.lerp(b, k)
	if kind == "fetch":
		p = a if k < 0.5 else a.lerp(b, (k - 0.5) * 2.0)
		return p
	p.y = lerpf(a.y, b.y, k) + sin(k * PI) * float(_shot["apex"])
	return p


func _play() -> void:
	var kind := str(_shot["kind"])
	var done := _clock >= float(_shot["t0"]) + float(_shot["dur"])
	var both := _occupied(0) and _occupied(1)
	var one := _occupied(0) or _occupied(1)
	if not one:
		_shot["kind"] = "rest"
		return
	if kind != "rest" and not done:
		return
	if not both:
		# Alone: up off the bat and down again.
		var s := 0 if _occupied(0) else 1
		var side := -1.0 if s == 0 else 1.0
		var bat := Vector3(side * (END_X - 0.05), BAT_Y, 0.12)
		_launch("solo", bat, bat, 0.32, 0.55, s, s)
		_tok(0.9)
		return
	match kind:
		"hit":
			# Landed on the far half: on to the bat at that end.
			var to := int(_shot["to_slot"])
			var side2 := -1.0 if to == 0 else 1.0
			if _rng.randf() < MISS_CHANCE:
				var lost := Vector3(side2 * (END_X + 1.2), 0.03, _rng.randf_range(-0.8, 0.8))
				_launch("miss", _shot["to"], lost, 0.35, 0.55, to, to)
			else:
				_launch("bounce", _shot["to"], Vector3(side2 * (END_X - 0.05), BAT_Y, 0.12), 0.2, 0.3, to, to)
			_tok(1.6)
		"bounce":
			_hit(int(_shot["to_slot"]))
		"miss":
			var who := int(_shot["to_slot"])
			var side3 := -1.0 if who == 0 else 1.0
			_launch("fetch", _shot["to"], Vector3(side3 * (END_X - 0.05), BAT_Y, 0.12), 0.0, 2.2, who, who)
		"fetch":
			_hit(int(_shot["to_slot"]))
		_:
			_hit(0)


## `slot` hits it across: the bounce on the far half.
func _hit(slot: int) -> void:
	var side := -1.0 if slot == 0 else 1.0
	var from := Vector3(side * (END_X - 0.05), BAT_Y, 0.12)
	var land := Vector3(-side * _rng.randf_range(0.4, 1.1), _top + 0.025, _rng.randf_range(-0.55, 0.55))
	_hit_at[slot] = _clock
	_launch("hit", from, land, 0.28, _rng.randf_range(0.42, 0.55), slot, 1 - slot)
	_tok(1.25)


func _launch(kind: String, from: Vector3, to: Vector3, apex: float, dur: float, _by: int, to_slot: int) -> void:
	_shot = {"kind": kind, "from": from, "to": to, "apex": apex, "t0": _clock, "dur": dur, "to_slot": to_slot}


func _tok(pitch: float) -> void:
	if _audio == null or not ResourceLoader.exists(SFX_TOK):
		return
	_audio.stream = load(SFX_TOK)
	_audio.volume_db = -22.0
	_audio.pitch_scale = pitch * _rng.randf_range(1.6, 1.9)
	_audio.global_position = (get_parent() as Node3D).to_global(_ball_pos())
	_audio.play()
