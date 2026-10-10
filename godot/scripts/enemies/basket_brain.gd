extends "res://scripts/enemies/enemy_base.gd"

## The Basket Man (spawned by Mushroom Pickers).
##
## Before dawn something comes out of the woods with a creaking wicker basket and walks
## the camp slowly, looking for mushrooms, or for something. It sees only movement.
## While it is near, every step you take is seen: keep moving and it turns and comes
## for you, quickly. Stand still (or crouch in a doorway) and it passes you by. Tell:
## the creak of the basket and the scrape of a little knife, getting closer.

const SPRITE := "res://assets/textury/npc/enemy_basket.png"
const SFX_CREAK := "res://assets/sfx/npc/basket_creak.mp3"
const WALK := 1.1
const CHASE := 4.8
const SEE_RANGE := 16.0
## Seconds of moving in its sight before it comes for you.
const NOTICE := 1.4
const REACH := 1.8
## It only walks in the small hours.
const FROM_HOUR := 2.5
const TO_HOUR := 6.0

var _target := Vector3.INF
var _noticed := 0.0
var _chasing := false
var _creak_t := 0.0
var _hit := 35
var _rest_until := 0.0


func get_enemy_id() -> String:
	return "basket"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_hit = int(lerpf(30.0, 45.0, t))
	_body = _make_body(SPRITE, 1.9)
	_body.visible = false


func _hour() -> float:
	var main := _world_root.get_tree().current_scene if _world_root != null else null
	return float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 0.0


func _on_tick(dt: float) -> void:
	var h := _hour()
	if h < FROM_HOUR or h > TO_HOUR or _elapsed < _rest_until:
		_body.visible = false
		return
	if not _body.visible:
		# Out of the trees, somewhere ahead of you at a distance.
		var p := _point_from_player(_rng.randf_range(18.0, 24.0), _rng.randf_range(-60.0, 60.0))
		if p == Vector3.INF:
			return
		_place_body(p)
		_target = _point_from_player(8.0, 0.0)
		_announce("A basket creaking out of the trees. Something picking, at this hour.")
	var pos := _body.global_position
	var d := _distance_to_player(pos)
	_creak_t -= dt
	if _creak_t <= 0.0:
		_creak_t = 2.2 if not _chasing else 0.9
		_sound(SFX_CREAK, pos + Vector3(0, 1.0, 0), -2.0, _rng.randf_range(0.9, 1.05), 30.0)
	var moving := _player != null and Vector2(_player.velocity.x, _player.velocity.z).length() > 0.4
	if d < SEE_RANGE and moving:
		_noticed += dt
	else:
		_noticed = maxf(0.0, _noticed - dt * 0.7)
	if _noticed >= NOTICE:
		_chasing = true
	if _chasing and not moving and d > 4.0:
		# You froze in time: it lost you.
		_chasing = false
		_noticed = 0.0
	var goal := _player_pos() if _chasing else _target
	var to := goal - pos
	to.y = 0.0
	if _chasing and to.length() <= REACH:
		_hurt(_hit)
		_chasing = false
		_body.visible = false
		_rest_until = _elapsed + 50.0
		return
	if not _chasing and to.length() < 1.0:
		_target = _point_from_player(_rng.randf_range(6.0, 14.0), _rng.randf_range(0.0, 360.0))
		return
	var step := to.normalized() * (CHASE if _chasing else WALK) * dt
	var np := _ground(pos + step)
	if np != Vector3.INF:
		_body.global_position = np
