extends Node3D

## The ping-pong table in use (building_models._pingpong): two players at the ends hit
## the ball across: off the bat, one bounce on the far half, onto the other bat, and back
## (tok, tik, tok). Now and then a miss: the ball bounces off the end and the one who
## missed fetches it, then serves. One player alone bounces the ball on the bat; the
## rest stand at the side and wait their turn. Stepped at 12 frames a second.

const WARDEN_PLAY = preload("res://scripts/attractions/warden_play.gd")
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
var _bat_drawn: Dictionary = {}   # slot -> its player's sprite holds the bat
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
	# At an end: the bat in hand (drawn in the sprite; the table's own bat then stays out
	# of sight, except for the warden whose eyes these are: warden_play.gd).
	var base := str(info.get("sprite_path", ""))
	POSES.set_pose(sprite, base, "bat" if slot_now < 2 else "")
	if slot_now < 2:
		var mine := key == WARDEN_PLAY.local_key()
		_bat_drawn[slot_now] = POSES.has_pose(base, "bat") and not mine
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
	guests_here = _seen.keys().filter(func(k): return int(k) >= 0).size()
	# Co-op: the host's game, followed here (coop_take_shot).
	if not Coop.is_client():
		_play()
	if _ball != null:
		_ball.position = _ball_pos()
	# The bats are in the players' hands while they play, on the table when not.
	for i in _bats.size():
		var b := _bats[i] as Node3D
		var side := -1.0 if i == 0 else 1.0
		b.visible = not (_occupied(i) and bool(_bat_drawn.get(i, false)))
		if _key_at(i) == WARDEN_PLAY.local_key():
			# Yours: in your hand before your eyes, swung at each hit.
			var sw := clampf(1.0 - (_clock - float(_hit_at.get(i, -9.0))) / 0.25, 0.0, 1.0)
			b.position = Vector3(side * (END_X - 0.28 - 0.25 * sw), BAT_Y + 0.22, 0.3 - 0.3 * sw)
			b.rotation = Vector3(PI * 0.5 - 0.5, 0, side * (0.3 + sw))
		elif _occupied(i):
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
			# A warden misses only by their own hand (the bounce below).
			if _key_at(to) >= 0 and _rng.randf() < MISS_CHANCE:
				var lost := Vector3(side2 * (END_X + 1.2), 0.03, _rng.randf_range(-0.8, 0.8))
				_launch("miss", _shot["to"], lost, 0.35, 0.55, to, to)
			else:
				_launch("bounce", _shot["to"], Vector3(side2 * (END_X - 0.05), BAT_Y, 0.12), 0.2, 0.3, to, to)
			_tok(1.6)
		"bounce":
			var at := int(_shot["to_slot"])
			var wk := _key_at(at)
			if wk < 0 and not _swung(wk, float(_shot["dur"]) + 0.15):
				# Not hit: a moment's grace, then past the bat and off the end.
				if _clock < float(_shot["t0"]) + float(_shot["dur"]) + 0.2:
					return
				var side4 := -1.0 if at == 0 else 1.0
				_launch("miss", _shot["to"], Vector3(side4 * (END_X + 1.2), 0.03, _rng.randf_range(-0.8, 0.8)), 0.35, 0.55, at, at)
				return
			_press.erase(wk)
			_hit(at)
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
	# Co-op: the other machine's ball goes as this one.
	if Coop.is_host() and Coop.has_partner():
		var wp := get_tree().get_first_node_in_group("warden_play")
		if wp != null:
			var out := _shot.duplicate()
			out["t0"] = 0.0
			wp.shot_out(self, out, _slot_of.duplicate())


func _tok(pitch: float) -> void:
	if _audio == null or not ResourceLoader.exists(SFX_TOK):
		return
	_audio.stream = load(SFX_TOK)
	_audio.volume_db = -22.0
	_audio.pitch_scale = pitch * _rng.randf_range(1.6, 1.9)
	_audio.global_position = (get_parent() as Node3D).to_global(_ball_pos())
	_audio.play()


# ── a warden at the table (scripts/attractions/warden_play.gd) ───────────────

## Warden key -> when they last swung the bat (LMB).
var _press: Dictionary = {}


func _swung(key: int, within: float) -> bool:
	return _clock - float(_press.get(key, -99.0)) <= within


## Who has `slot` (0 when nobody: no warden).
func _key_at(slot: int) -> int:
	for k in _slot_of.keys():
		if int(_slot_of[k]) == slot:
			return int(k)
	return 0


func _end_global(slot: int) -> Vector3:
	var side := -1.0 if slot == 0 else 1.0
	return (get_parent() as Node3D).to_global(Vector3(side * (END_X + 0.25), 0, 0.0))


func warden_offer(at: Vector3) -> Dictionary:
	var c := (get_parent() as Node3D).global_position
	var d := Vector2(at.x - c.x, at.z - c.z).length()
	return {"verb": "Play ping-pong", "act": "join", "d": d} if d < 2.6 else {}


## The free end nearer you, or a turn to wait at the side.
func warden_join(key: int, at: Vector3) -> bool:
	var slot := -1
	for s2 in 2:
		if not _occupied(s2) and (slot < 0 or _end_global(s2).distance_to(at) < _end_global(slot).distance_to(at)):
			slot = s2
	if slot < 0:
		slot = 2
		while _occupied(slot):
			slot += 1
	_slot_of[key] = slot
	_seen[key] = _clock
	return true


func warden_slot(key: int) -> int:
	return int(_slot_of.get(key, -1))


func warden_force(key: int, slot: int, _x: Dictionary) -> void:
	if slot < 0 or int(_slot_of.get(key, -1)) == slot:
		return
	for k in _slot_of.keys():
		if int(_slot_of[k]) == slot and k != key:
			_slot_of.erase(k)
	_slot_of[key] = slot
	_seen[key] = _clock


func warden_leave(key: int) -> void:
	_slot_of.erase(key)
	_seen.erase(key)
	_press.erase(key)


func warden_focus(key: int) -> Vector3:
	if int(_slot_of.get(key, 9)) >= 2:
		return (get_parent() as Node3D).to_global(_ball_pos())
	return (get_parent() as Node3D).to_global(_ball_pos().lerp(Vector3(0, _top, 0), 0.4))


func warden_press(key: int) -> String:
	_press[key] = _clock
	return "hit"


func warden_pose(key: int, base: String) -> String:
	return "bat" if int(_slot_of.get(key, 9)) < 2 else base


func warden_hint(key: int) -> String:
	var mine := int(_slot_of.get(key, 9))
	var kind := str(_shot["kind"])
	if mine < 2 and int(_shot["to_slot"]) == mine and (kind == "hit" or kind == "bounce"):
		return "[LMB] Hit"
	return ""


## Co-op: the game is the host's; the other machine only follows.
func coop_follows() -> bool:
	return true


## The host's ball, a new flight: here as there (who stands where, the bat's swing,
## the tok).
func coop_take_shot(shot: Dictionary, roster: Dictionary) -> void:
	for k in roster.keys():
		if _slot_of.has(int(k)) and int(k) >= 0:
			_slot_of[int(k)] = int(roster[k])
	_shot = shot.duplicate()
	_shot["t0"] = _clock - float(shot.get("t0", 0.0))
	match str(_shot["kind"]):
		"hit":
			_hit_at[1 - int(_shot["to_slot"])] = _clock
			_tok(1.25)
		"bounce", "miss":
			_tok(1.6)
		"solo":
			_tok(0.9)
