extends Node3D

## The sports field in use (made by building_models._sports(); the guests visiting it
## are placed and posed here through pose_member(), like at the campfire). It is a
## nohejbal court, the Czech camp game: foot volleyball over a low net.
##   one guest       keeps the ball up on their own, knee, foot, knee
##   two or more     split either side of the net and kick it over; it may bounce once;
##                   now and then it is missed, rolls off, and the nearest one fetches it
## The ball is a real thing on the pitch: at rest in the middle when nobody plays. The
## corner flags stir in the wind. Stepped at 12 frames a second like the rest of the
## camp; the kicks and the cheers are assets/sfx/life (ball_kick, goal_cheer).

const POSES = preload("res://scripts/attractions/poses.gd")
const FPS := 12.0
const SFX_KICK := "res://assets/sfx/life/ball_kick.mp3"
const SFX_CHEER := "res://assets/sfx/life/goal_cheer.mp3"
const BALL_R := 0.11
const NET_TOP := 1.08
const FLIGHT := 1.15          # seconds over the net
const MISS_CHANCE := 0.16

var guests_here := 0

## member key -> {side: -1/1, slot: int, node: Node3D (weak), sprite}
var _players: Dictionary = {}
var _seen: Dictionary = {}
var _clock := 0.0
var _acc := 0.0
var _rng := RandomNumberGenerator.new()

var _ball: MeshInstance3D
var _flags: Array = []
var _half := Vector2(3.4, 1.5)    # half the court (x along the pitch, z across)
var _rest := Vector3.ZERO

## The rally: the ball flies from `from` to `to` (local), started at `t0`, landing at
## `t0 + dur`; `kind` is "over" (a kick over the net), "bounce" (the hop before the
## return), "roll" (a miss rolling away), "fetch" (carried back), "juggle", "rest".
var _shot := {"kind": "rest", "from": Vector3.ZERO, "to": Vector3.ZERO, "t0": 0.0, "dur": 1.0, "by": -1, "next": -1}
var _kick_at: Dictionary = {}     # member key -> clock of their last kick (the hop)
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("attraction")
	_rng.randomize()
	call_deferred("_setup")


func _setup() -> void:
	var r := get_parent()
	_ball = r.get_node_or_null("Ball") as MeshInstance3D
	for n in r.get_children():
		if str(n.name).begins_with("CornerFlag"):
			_flags.append(n)
	if r.has_meta("court_half"):
		_half = r.get_meta("court_half")
	_rest = Vector3(0.6, BALL_R, 0.3)
	if _ball != null:
		_ball.position = _rest
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 6.0
	_audio.max_distance = 40.0
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


## A guest of a party playing: where they stand on their side of the net, turned to the
## ball, a hop when they kick it. Always true (there is room for everyone on a court).
func pose_member(guest_id: int, i: int, _n: int, member: Node3D, sprite: Sprite3D, info: Dictionary, _t: float) -> bool:
	var key := guest_id * 10 + i
	if not _players.has(key):
		_players[key] = {"side": _pick_side(), "slot": _players.size()}
	_seen[key] = _clock
	var p: Dictionary = _players[key]
	p["node"] = weakref(member)
	var spot := _spot_of(key)
	# After a missed ball: the fetcher walks to it, then dribbles it back.
	if str(_shot["kind"]) == "fetch" and int(_shot["by"]) == key:
		var k := clampf((_clock - float(_shot["t0"])) / maxf(0.01, float(_shot["dur"])), 0.0, 1.0)
		var at_ball: Vector3 = (_shot["from"] as Vector3) + Vector3(0.25 * signf(spot.x), 0, 0.1)
		at_ball.y = 0.0
		spot = spot.lerp(at_ball, k * 2.0) if k < 0.5 else at_ball.lerp(spot, (k - 0.5) * 2.0)
	var hop := 0.0
	var since := _clock - float(_kick_at.get(key, -10.0))
	if since < 0.25:
		hop = sin(since / 0.25 * PI) * 0.12
	member.global_position = to_global(Vector3(spot.x, hop, spot.z))
	member.set_meta("marker_drop", 0.0)
	POSES.set_pose(sprite, str(info.get("sprite_path", "")), "")
	if sprite != null:
		# Facing the ball: flip toward it; a lean into the kick.
		var to_ball := _ball_pos() - spot
		sprite.flip_h = to_ball.x < 0.0 if absf(to_ball.x) > 0.05 else sprite.flip_h
		sprite.rotation.z = (-0.12 if not sprite.flip_h else 0.12) * clampf(1.0 - since / 0.3, 0.0, 1.0)
	return true


func _pick_side() -> int:
	var a := 0
	var b := 0
	for p in _players.values():
		if int(p["side"]) < 0:
			a += 1
		else:
			b += 1
	return -1 if a <= b else 1


## Where player `key` waits: spread across their half, a step back from the net.
func _spot_of(key: int) -> Vector3:
	var p: Dictionary = _players[key]
	var side := int(p["side"])
	var mates: Array = []
	for k in _players.keys():
		if int(_players[k]["side"]) == side:
			mates.append(k)
	mates.sort()
	var idx := mates.find(key)
	var n := mates.size()
	if _players.size() == 1:
		return Vector3(-0.9, 0, 0.2)
	var z := 0.0 if n == 1 else lerpf(-_half.y * 0.6, _half.y * 0.6, float(idx) / float(n - 1))
	var x := float(side) * (_half.x * 0.5 + (0.3 if idx % 2 == 0 else -0.25))
	return Vector3(x, 0, z)


func _process(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	for key in _seen.keys():
		if _clock - float(_seen[key]) > 1.0:
			_seen.erase(key)
			_players.erase(key)
	guests_here = _seen.size()
	_wave_flags()
	_rally()
	if _ball != null:
		var at := _ball_pos()
		_ball.position = at
		# It rolls and spins as it goes.
		_ball.rotation.z -= 0.6
		_ball.rotation.x += 0.35


## Where the ball is now (local), from the shot in flight.
func _ball_pos() -> Vector3:
	var kind := str(_shot["kind"])
	if kind == "rest":
		return _rest
	var k := clampf((_clock - float(_shot["t0"])) / maxf(0.01, float(_shot["dur"])), 0.0, 1.0)
	var a: Vector3 = _shot["from"]
	var b: Vector3 = _shot["to"]
	var p := a.lerp(b, k)
	match kind:
		"over":
			p.y = lerpf(a.y, b.y, k) + sin(k * PI) * (NET_TOP + 0.9)
		"bounce":
			p.y = BALL_R + sin(k * PI) * 0.55
		"fetch":
			p = a if k < 0.5 else a.lerp(b, (k - 0.5) * 2.0)
			p.y = BALL_R
		"juggle":
			p.y = lerpf(a.y, b.y, k) + sin(k * PI) * 0.9
		_:
			p.y = BALL_R
	return p


func _rally() -> void:
	var keys := _players.keys()
	if keys.is_empty():
		if str(_shot["kind"]) != "rest":
			_rest = Vector3(_ball_pos().x, BALL_R, _ball_pos().z)
			_shot["kind"] = "rest"
		return
	var kind := str(_shot["kind"])
	var done := _clock >= float(_shot["t0"]) + float(_shot["dur"])
	if kind != "rest" and not done:
		return
	if keys.size() == 1:
		_juggle(int(keys[0]))
		return
	match kind:
		"over":
			# Landed by the one it was for: a bounce, or straight back if they volley it.
			var to := int(_shot["next"])
			if not _players.has(to):
				_serve(keys)
			elif _rng.randf() < MISS_CHANCE:
				var away := (_shot["to"] as Vector3) + Vector3(float(_players[to]["side"]) * 1.6, 0, _rng.randf_range(-1.0, 1.0))
				away.x = clampf(away.x, -_half.x - 0.8, _half.x + 0.8)
				_launch("roll", _shot["to"], away, 1.4, to, to)
			elif _rng.randf() < 0.5:
				_launch("bounce", _shot["to"], _foot_of(to), 0.5, to, to)
			else:
				_kick(to, keys)
		"bounce":
			var by := int(_shot["by"])
			if _players.has(by):
				_kick(by, keys)
			else:
				_serve(keys)
		"roll":
			# The one who missed it walks after it and brings it back to serve.
			var who := int(_shot["by"])
			if _players.has(who):
				var stop: Vector3 = _shot["to"]
				_launch("fetch", stop, _foot_of(who), 0.8 + stop.distance_to(_foot_of(who)) * 0.7, who, who)
				_cheer()
			else:
				_serve(keys)
		"fetch":
			var w := int(_shot["by"])
			if _players.has(w):
				_kick(w, keys)
			else:
				_serve(keys)
		_:
			_serve(keys)


func _serve(keys: Array) -> void:
	var by := int(keys[_rng.randi() % keys.size()])
	var at := _ball_pos()
	at.y = BALL_R
	_launch("fetch", at, _foot_of(by), 0.8 + at.distance_to(_foot_of(by)) * 0.7, by, by)


## `by` kicks it over the net to somebody on the other side.
func _kick(by: int, keys: Array) -> void:
	var side := int(_players[by]["side"])
	var other: Array = []
	for k in keys:
		if int(_players[k]["side"]) != side:
			other.append(k)
	if other.is_empty():
		# Everyone on one side (one left, the others went home): they swap over.
		_players[by]["side"] = -side
		_juggle(by)
		return
	var to := int(other[_rng.randi() % other.size()])
	_kick_at[by] = _clock
	_play(SFX_KICK, -8.0, _rng.randf_range(0.9, 1.1))
	_launch("over", _foot_of(by) + Vector3(0, 0.25, 0), _foot_of(to) + Vector3(0, 0.25, 0), FLIGHT + _rng.randf_range(-0.15, 0.2), by, to)


func _juggle(by: int) -> void:
	_kick_at[by] = _clock
	_play(SFX_KICK, -14.0, _rng.randf_range(1.1, 1.3))
	var f := _foot_of(by) + Vector3(0, 0.25, 0)
	_launch("juggle", f, f + Vector3(_rng.randf_range(-0.08, 0.08), 0, _rng.randf_range(-0.08, 0.08)), 0.7, by, by)


func _launch(kind: String, from: Vector3, to: Vector3, dur: float, by: int, next: int) -> void:
	_shot = {"kind": kind, "from": from, "to": to, "t0": _clock, "dur": dur, "by": by, "next": next}


## In front of their feet, toward the net.
func _foot_of(key: int) -> Vector3:
	var s := _spot_of(key)
	return Vector3(s.x - signf(s.x) * 0.3, BALL_R, s.z + 0.12)


func _cheer() -> void:
	if _players.size() >= 3 and _rng.randf() < 0.6:
		_play(SFX_CHEER, -14.0, 1.0)


func _wave_flags() -> void:
	for i in _flags.size():
		var f := _flags[i] as Node3D
		var cloth := f.get_node_or_null("Cloth") as Node3D
		if cloth != null:
			cloth.rotation.y = sin(_clock * 2.3 + float(i) * 1.7) * 0.5
			cloth.scale.x = 0.85 + 0.15 * sin(_clock * 4.1 + float(i))


func _play(path: String, db: float, pitch: float) -> void:
	if _audio == null or not ResourceLoader.exists(path):
		return
	_audio.stream = load(path)
	_audio.volume_db = db
	_audio.pitch_scale = pitch
	_audio.global_position = to_global(_ball_pos())
	_audio.play()
