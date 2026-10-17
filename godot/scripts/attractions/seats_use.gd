extends Node3D

## Guests using a bench, the picnic table or the hammock (building_models._bench /
## _picnic / _hammock): each member of a visiting party gets one of the model's places
## (meta "seats": [{pos, face, pose, lift?, sway?}], local to the model) and sits there,
## seated sprites on the floor just in front of the seat (scripts/attractions/poses.gd).
## At the table they eat and take a pull of beer by turns; in the hammock they sway with
## it. When every place is taken the rest stand about as before (pose_member false).
## Stepped at 12 frames a second like the rest of the camp.

const POSES = preload("res://scripts/attractions/poses.gd")
const FPS := 12.0

var guests_here := 0

var _seats: Array = []
var _seat_of: Dictionary = {}     # member key -> seat index
var _seen: Dictionary = {}
var _clock := 0.0
var _acc := 0.0
var _sway: Node3D


func _ready() -> void:
	add_to_group("attraction")
	call_deferred("_setup")


func _setup() -> void:
	var r := get_parent()
	_seats = r.get_meta("seats", [])
	for s in _seats:
		var sway_name := str((s as Dictionary).get("sway", ""))
		if sway_name != "":
			_sway = r.get_node_or_null(sway_name) as Node3D


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


func pose_member(guest_id: int, i: int, _n: int, member: Node3D, sprite: Sprite3D, info: Dictionary, t: float) -> bool:
	if _seats.is_empty():
		return false
	var key := guest_id * 10 + i
	if not _seat_of.has(key):
		var taken := _seat_of.values()
		var free := -1
		for k in _seats.size():
			var idx := (k + guest_id) % _seats.size()
			if not taken.has(idx):
				free = idx
				break
		if free < 0:
			return false
		_seat_of[key] = free
	_seen[key] = _clock
	var seat: Dictionary = _seats[int(_seat_of[key])]
	var pos: Vector3 = seat["pos"]
	pos.y += float(seat.get("lift", 0.0))
	var parent := get_parent() as Node3D
	if _sway != null and str(seat.get("sway", "")) != "":
		# Carried by the hammock: the seat turns about the line between the posts.
		pos = _sway.position + _sway.basis * (pos - _sway.position)
	member.global_position = parent.to_global(pos)
	member.set_meta("marker_drop", -0.42)
	var pose := str(seat.get("pose", "sit"))
	if pose == "eat":
		# A bite, a pull at the beer, a sit and a chat, each in its own time.
		var beat := fmod(floorf(t * 8.0) / 8.0 + float(key) * 2.3, 9.0)
		pose = "eat" if beat < 2.0 else ("drink" if beat < 3.2 else "sit")
	POSES.set_pose(sprite, str(info.get("sprite_path", "")), pose)
	if sprite != null:
		sprite.rotation.z = 0.0
	return true


func _process(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	for key in _seen.keys():
		if _clock - float(_seen[key]) > 1.0:
			_seen.erase(key)
			_seat_of.erase(key)
	guests_here = _seen.size()
	if _sway != null:
		# A lazy swing with somebody in it; barely a stir in the wind without.
		var amp := 0.1 if guests_here > 0 else 0.025
		_sway.rotation.x = sin(_clock * 1.1) * amp
