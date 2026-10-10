extends "res://scripts/enemies/enemy_base.gd"

## The Extra Child (spawned by Families).
##
## A child stands among the tents with its back to you, humming. It is not one of the
## guests' children; count them. It does nothing as long as nobody looks at it with a
## light. Put the torch on it and it stops humming, turns its head, and runs at you,
## shrieking. The counter is the opposite of the Girl's: torch off, walk past, do not
## shine it on the child. It moves to another spot every so often.

const SPRITE := "res://assets/textury/npc/enemy_child.png"
const SFX_HUM := "res://assets/sfx/npc/child_hum.mp3"
const SFX_SCREAM := "res://assets/sfx/npc/child_scream.mp3"
const LIT_LIMIT := 0.9
const RUN_SPEED := 6.5
const REACH := 1.6

var _lit := 0.0
var _running := false
var _hit := 28
var _hum_t := 3.0
var _move_t := 40.0
var _gone_until := 0.0


func get_enemy_id() -> String:
	return "child"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_hit = int(lerpf(22.0, 38.0, t))
	_body = _make_body(SPRITE, 1.15)
	_appear()


func _appear() -> void:
	for _i in 16:
		var p := _point_from_player(_rng.randf_range(10.0, 16.0), _rng.randf_range(-70.0, 70.0))
		if p != Vector3.INF:
			_place_body(p)
			return
	_body.visible = false


func _on_tick(dt: float) -> void:
	if _elapsed < _gone_until:
		_body.visible = false
		return
	if not _body.visible:
		_appear()
	var pos := _body.global_position
	if _running:
		var to := _player_pos() - pos
		to.y = 0.0
		if to.length() <= REACH:
			_hurt(_hit)
			_running = false
			_body.visible = false
			_gone_until = _elapsed + _rng.randf_range(35.0, 55.0)
			return
		var p := _ground(pos + to.normalized() * RUN_SPEED * dt)
		if p != Vector3.INF:
			_body.global_position = p
		return
	_hum_t -= dt
	if _hum_t <= 0.0:
		_hum_t = _rng.randf_range(6.0, 10.0)
		_sound(SFX_HUM, pos + Vector3(0, 1.0, 0), -4.0, _rng.randf_range(0.95, 1.05), 26.0)
		_announce("A child is humming somewhere between the tents. Not one of ours.")
	_move_t -= dt
	if _move_t <= 0.0 and not _is_seen(pos + Vector3(0, 0.8, 0)):
		_move_t = _rng.randf_range(35.0, 55.0)
		_appear()
	if _in_flashlight(pos + Vector3(0, 0.8, 0)) and _is_seen(pos + Vector3(0, 0.8, 0)):
		_lit += dt
		if _lit >= LIT_LIMIT:
			_running = true
			_lit = 0.0
			_sound(SFX_SCREAM, pos + Vector3(0, 1.0, 0), 4.0, 1.0, 40.0)
	else:
		_lit = maxf(0.0, _lit - dt)
