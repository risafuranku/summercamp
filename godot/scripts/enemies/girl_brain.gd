extends "res://scripts/enemies/enemy_base.gd"

## The Girl (spawned by Cheap Chick guests).
##
## She stands at the edge of the dark, facing you, and never moves while you look at
## her. Look away for long enough and she is closer. Holding her in the flashlight
## keeps her still but the battery drains several times faster and the static rises.
## She will not step into lamp light: lamp posts are the safe ground the player built
## during the day. Reach you, and she takes a lot of health and is gone for a while.

const SPRITE := "res://assets/textury/npc/enemy_girl.png"
const SFX_STATIC := "res://assets/sfx/npc/static_loop.wav"
const SFX_HUM := "res://assets/sfx/npc/hum_loop.wav"
const LAMP_SAFE := 0.22
const REACH := 2.2

var _unseen_for: float = 0.0
var _step_after: float = 2.6
var _step: Vector2 = Vector2(2.0, 3.5)
var _hit: int = 34
var _gone_until: float = 0.0
var _static: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D


func get_enemy_id() -> String:
	return "girl"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_step_after = lerpf(3.8, 2.2, t)
	_step = Vector2(lerpf(1.3, 2.2, t), lerpf(2.4, 3.6, t))
	_hit = int(lerpf(30.0, 45.0, t))
	_body = _make_body(SPRITE, 1.72)
	_static = _loop(SFX_STATIC, -40.0)
	_hum = _loop(SFX_HUM, -40.0)
	_appear(_rng.randf_range(16.0, 20.0))


func _on_stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set("flashlight_drain_boost", 0.0)


func _on_tick(dt: float) -> void:
	if _elapsed < _gone_until:
		_body.visible = false
		_set_audio(0.0)
		return
	if not _body.visible:
		_appear(_rng.randf_range(15.0, 19.0))
	var head := _body.global_position + Vector3(0, 1.4, 0)
	var d := _distance_to_player(_body.global_position)
	var seen := _is_seen(head, -6.0)
	var lit := _in_flashlight(head)
	if seen and lit:
		# Holding her in the beam: she freezes, the battery pays for it.
		_player.set("flashlight_drain_boost", 5.0)
		_unseen_for = 0.0
		_announce("Someone is standing at the edge of the light. She hasn't moved.")
	elif seen:
		_unseen_for = maxf(0.0, _unseen_for - dt * 0.5)
	else:
		_unseen_for += dt
	if _unseen_for >= _step_after:
		_unseen_for = 0.0
		_advance()
		d = _distance_to_player(_body.global_position)
	# The closer she is, the louder the hiss and the hum; you hear her before you see.
	_set_audio(clampf(1.0 - d / 18.0, 0.0, 1.0))
	if d < REACH:
		_hurt(_hit)
		_gone_until = _elapsed + _rng.randf_range(18.0, 30.0)
		_body.visible = false


func _advance() -> void:
	var from := _body.global_position
	var to_player := _player_pos() - from
	to_player.y = 0.0
	var dist := to_player.length()
	var step := minf(_rng.randf_range(_step.x, _step.y), maxf(0.0, dist - 0.5))
	var sideways := to_player.normalized().cross(Vector3.UP) * _rng.randf_range(-1.2, 1.2)
	var target := _ground(from + to_player.normalized() * step + sideways)
	if target == Vector3.INF:
		return
	# Lamp light is a wall to her. Standing in it, the player is unreachable.
	if _lamp_light_at(target) > LAMP_SAFE:
		return
	_body.global_position = target


## Somewhere roughly behind the player at `dist`, never in lamp light.
func _appear(dist: float) -> void:
	for _i in 12:
		var p := _point_from_player(dist, _rng.randf_range(120.0, 240.0))
		if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
			continue
		_place_body(p)
		return
	_body.visible = false


func _set_audio(near: float) -> void:
	for a in [_static, _hum]:
		if a != null and is_instance_valid(a):
			a.global_position = _body.global_position + Vector3(0, 1.3, 0)
	if _static != null:
		_static.volume_db = lerpf(-40.0, -4.0, near)
	if _hum != null:
		_hum.volume_db = lerpf(-40.0, -8.0, near * near)
