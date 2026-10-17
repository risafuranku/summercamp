extends Node3D

## The playground in use (building_models._playground): the first two of the visitors
## go on the swings, which then really swing (a pendulum on its chains, pushed now and
## then, creaking at the bottom of the arc); the next two on the seesaw, which tips
## between them (one alone sits on the low end and waits); the rest stand round the
## sandpit and watch. Empty, the swings stir in the wind and the seesaw rests on one end.

const POSES = preload("res://scripts/attractions/poses.gd")
const FPS := 12.0
const SFX_CREAK := "res://assets/sfx/life/ladder_creak.mp3"

var guests_here := 0

var _swings: Array = []           # [Node3D pivots]
var _amp: Array = [0.0, 0.0]
var _phase: Array = [0.0, 1.7]
var _seesaw: Node3D
var _drop := 1.72
var _slot_of: Dictionary = {}     # member key -> slot (0,1 swings; 2,3 seesaw; 4.. standing)
var _seen: Dictionary = {}
var _clock := 0.0
var _acc := 0.0
var _last_sign: Array = [0.0, 0.0]
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("attraction")
	call_deferred("_setup")


func _setup() -> void:
	var r := get_parent()
	for i in 2:
		var s := r.get_node_or_null("Swing%d" % i) as Node3D
		if s != null:
			_swings.append(s)
	_seesaw = r.get_node_or_null("Seesaw") as Node3D
	_drop = float(r.get_meta("swing_seat_drop", 1.72))
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 5.0
	_audio.max_distance = 30.0
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
	var pose := "sit"
	if slot_now < 2 and slot_now < _swings.size():
		# On the seat, carried round the arc (the sprite's seat line is 0.45 m up it).
		var sw: Node3D = _swings[slot_now]
		var seat := sw.global_transform * Vector3(0, -_drop, 0.04)
		member.global_position = seat - Vector3(0, 0.45, 0)
	elif slot_now < 4 and _seesaw != null:
		var end := -1.0 if slot_now == 2 else 1.0
		var at := _seesaw.global_transform * Vector3(end * 1.0, 0.03, 0.04)
		member.global_position = at - Vector3(0, 0.45, 0)
	else:
		# Watching from the sandpit's edge.
		pose = ""
		var k := slot_now - 4
		var spot := Vector3(0.6 + float(k % 3) * 0.5, 0, -0.35 - floorf(float(k) / 3.0) * 0.4)
		member.global_position = parent.to_global(spot)
	member.set_meta("marker_drop", -0.42 if pose == "sit" else 0.0)
	POSES.set_pose(sprite, str(info.get("sprite_path", "")), pose)
	if sprite != null:
		sprite.rotation.z = 0.0
	return true


func _occupied(slot: int) -> bool:
	return _slot_of.values().has(slot)


func _process(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var step := _acc
	_acc = 0.0
	for key in _seen.keys():
		if _clock - float(_seen[key]) > 1.0:
			_seen.erase(key)
			_slot_of.erase(key)
	guests_here = _seen.size()
	# The swings: a pendulum (about 2.4 rad/s on 1.7 m of chain), pushed up when ridden.
	var w := sqrt(9.81 / maxf(0.5, _drop))
	for i in _swings.size():
		var want := 0.55 if _occupied(i) else 0.03
		_amp[i] = move_toward(float(_amp[i]), want, step * (0.25 if want > float(_amp[i]) else 0.12))
		var a := float(_amp[i]) * sin(_clock * w + float(_phase[i]))
		(_swings[i] as Node3D).rotation.x = a
		var sgn := signf(a)
		if sgn != float(_last_sign[i]) and float(_amp[i]) > 0.3 and randf() < 0.5:
			_creak((_swings[i] as Node3D).global_position)
		_last_sign[i] = sgn
	# The seesaw: tipping between two, down on the side of one, at rest on its end.
	if _seesaw != null:
		var target := -0.2
		if _occupied(2) and _occupied(3):
			target = sin(_clock * 1.7) * 0.22
		elif _occupied(3):
			target = 0.2
		_seesaw.rotation.z = move_toward(_seesaw.rotation.z, target, step * 0.9)


func _creak(at: Vector3) -> void:
	if _audio == null or not ResourceLoader.exists(SFX_CREAK):
		return
	_audio.stream = load(SFX_CREAK)
	_audio.volume_db = -20.0
	_audio.pitch_scale = randf_range(1.4, 1.7)
	_audio.global_position = at
	_audio.play()
