extends "res://scripts/enemies/enemy_base.gd"
class_name SilentManBrain

## The Silent Man, the hatter (spawned by Quiet Guy guests). Rule: do not stand still in
## the dark.
##
## The loop, all of it audible so a hit can be understood afterwards:
## 1. In the dark, footsteps on the gravel behind you, every couple of seconds. Each set
##    is a little closer: a full step when you stand still, half when you walk; running
##    puts you ahead of him. Under a lamp he does not come nearer.
## 2. Turn round and put light on him (the flashlight, or a lamp he is standing in) and
##    he is there for a moment, then gone into the bushes; the footsteps start again far
##    behind you a little later.
## 3. If he reaches your back he whispers at your ear. You have about a second: turn
##    round or get away. If you do not, he hurts you and is gone for a while.
##
## He has a real position (the sprite stands there, lit only by your light), so the HUD
## face and the insects (threat_senses.gd) track the same place you hear.

const SPRITE := "res://assets/textury/npc/hrot1.png"
const SFX_STEPS := "res://assets/sfx/npc/silent_steps.mp3"
const SFX_WHISPER := "res://assets/sfx/npc/silent_whisper.mp3"
const SFX_AWAY := "res://assets/sfx/npc/silent_away.mp3"
const SFX_TWIG := "res://assets/sfx/npc/twig_snap.mp3"

const START_DIST := 14.0
const NECK_DIST := 1.6
const DARK_LIGHT := 0.35
const RUN_SPEED := 4.2

var _dist := START_DIST
var _step_gain := 1.6
var _step_interval := 2.2
var _grace := 1.2
var _damage := 16
var _next_step := 0.0
var _resume_at := 0.0
var _neck_until := -1.0
var _neck_from := Vector3.ZERO
var _last_player_pos := Vector3.INF
var _speed := 0.0
var _hits := 0
var _drive_offs := 0
var _peek_until := 0.0
## Seen: he stays where the light found him until then, and only then is gone.
var _vanish_at := -1.0


func get_enemy_id() -> String:
	return "silent_man"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_step_gain = lerpf(1.3, 2.2, t)
	_step_interval = lerpf(2.6, 1.6, t)
	_grace = lerpf(1.4, 1.0, t)
	_damage = int(lerpf(14.0, 24.0, t))
	_body = _make_body(SPRITE, 1.85)
	_reset_far(_rng.randf_range(3.0, 6.0))
	_peek_until = 0.0


func _on_tick(dt: float) -> void:
	_track_speed(dt)
	if _vanish_at > 0.0:
		_body.visible = true
		if _elapsed >= _vanish_at:
			_vanish_at = -1.0
			_reset_far(_rng.randf_range(4.0, 8.0))
		return
	var head := _body.global_position + Vector3(0, 1.5, 0)
	# Caught in the light: there for a beat, then gone.
	if _elapsed >= _resume_at and _is_lit_and_seen(head):
		_driven_off()
		return
	if _neck_until > 0.0:
		_tick_neck()
		return
	if _elapsed < _resume_at:
		_body.visible = _elapsed < _peek_until
		return
	_body.visible = true
	if _elapsed >= _next_step:
		_next_step = _elapsed + _step_interval * _rng.randf_range(0.85, 1.15)
		_step()


func _step() -> void:
	var in_light := _lamp_light_at(_player_pos()) >= DARK_LIGHT
	if in_light:
		# He waits where the light ends; now and then a twig gives him away.
		if _rng.randf() < 0.35:
			_sound(SFX_TWIG, _body.global_position + Vector3(0, 0.2, 0), -4.0, _rng.randf_range(0.9, 1.1), 30.0)
		return
	if _speed > RUN_SPEED:
		_dist = minf(START_DIST, _dist + 1.0)
	elif _speed > 0.6:
		_dist -= _step_gain * 0.5
	else:
		_dist -= _step_gain
	_dist = maxf(NECK_DIST, _dist)
	_place_behind(_dist)
	_sound(SFX_STEPS, _body.global_position + Vector3(0, 0.3, 0), lerpf(-10.0, 0.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.94, 1.04), 34.0)
	_announce("Footsteps on the gravel behind you. They stop when you stop.")
	if _dist <= NECK_DIST + 0.01:
		_neck_until = _elapsed + _grace
		_neck_from = _player_pos()
		_sound(SFX_WHISPER, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.35, 2.0, 1.0, 8.0)


## Right behind you: turn round or get away, now.
func _tick_neck() -> void:
	var head := _body.global_position + Vector3(0, 1.5, 0)
	if _is_seen(head, 6.0) or _player_pos().distance_to(_neck_from) > 1.8:
		_neck_until = -1.0
		_driven_off()
		return
	if _elapsed >= _neck_until:
		_neck_until = -1.0
		_hits += 1
		_hurt(_damage)
		_reset_far(_rng.randf_range(12.0, 18.0))


func _driven_off() -> void:
	_drive_offs += 1
	_sound(SFX_AWAY, _body.global_position + Vector3(0, 0.6, 0), -2.0, _rng.randf_range(0.95, 1.05), 36.0)
	_vanish_at = _elapsed + 0.45


func _reset_far(pause: float) -> void:
	_dist = START_DIST
	_resume_at = _elapsed + pause
	_next_step = _resume_at + _step_interval
	# Out of sight, somewhere behind you.
	var p := _point_from_player(_dist, 180.0 + _rng.randf_range(-50.0, 50.0))
	if p != Vector3.INF:
		_body.global_position = p


## Closes in on you along the line from where he stands, so turning round finds him.
func _place_behind(dist: float) -> void:
	var from := _body.global_position
	var to := _player_pos()
	var dir := Vector3(from.x - to.x, 0.0, from.z - to.z)
	if dir.length_squared() < 0.01:
		dir = -_forward_flat()
	var p := _ground(to + dir.normalized() * dist)
	if p != Vector3.INF:
		_body.global_position = p


func _is_lit_and_seen(head: Vector3) -> bool:
	if not _is_seen(head, 0.0):
		return false
	return _in_flashlight(head) or _lamp_light_at(_body.global_position) >= DARK_LIGHT


func _track_speed(dt: float) -> void:
	var p := _player_pos()
	if _last_player_pos != Vector3.INF and dt > 0.0:
		var flat := Vector2(p.x - _last_player_pos.x, p.z - _last_player_pos.z).length() / dt
		_speed = lerpf(_speed, flat, clampf(dt * 6.0, 0.0, 1.0))
	_last_player_pos = p


func get_debug_snapshot() -> Dictionary:
	return {
		"distance": snappedf(_dist, 0.1),
		"neck": _neck_until > 0.0,
		"paused": _elapsed < _resume_at,
		"hits": _hits,
		"driven_off": _drive_offs,
		"player_speed": snappedf(_speed, 0.1),
	}
