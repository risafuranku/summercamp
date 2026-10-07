extends "res://scripts/enemies/enemy_base.gd"

## The Antlered Man. Not tied to one archetype: he comes when two or more of them
## spawned the same night (main.gd), which is what makes a lazily booked camp lethal.
##
## He walks the fence line outside the camp, slowly, heavy footfalls you can hear
## across the field. If you are near the fence in the dark, he stops, turns, and runs
## at you, faster than you can sprint for long. Lamp light, or getting indoors, makes
## him lose interest. A hit from him takes nearly half your health.

const SPRITE := "res://assets/textury/npc/stalker_small.png"
const SFX_THUMP := "res://assets/sfx/npc/thump.wav"
const WALK_SPEED := 2.0
const NOTICE_RANGE := 14.0
const GIVE_UP_LIGHT := 0.25
const HIT_RANGE := 1.8

var _perimeter: Array[Vector3] = []
var _seg: int = 0
var _seg_t: float = 0.0
var _charging: bool = false
var _charge_speed: float = 5.6
var _hit: int = 45
var _step_t: float = 0.0
var _rest_until: float = 0.0


func get_enemy_id() -> String:
	return "stalker"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_charge_speed = lerpf(5.2, 6.4, t)
	_hit = int(lerpf(40.0, 55.0, t))
	_body = _make_body(SPRITE, 2.35)
	_build_perimeter()
	if _perimeter.size() >= 2:
		_seg = _rng.randi_range(0, _perimeter.size() - 1)
		_place_body(_perimeter[_seg])


func _build_perimeter() -> void:
	if _grid_manager == null or not _grid_manager.has_method("get_map_size_world"):
		return
	var c: Vector3 = _grid_manager.get_map_center_world()
	var s: Vector2 = _grid_manager.get_map_size_world()
	var hx := s.x * 0.5 + 3.0
	var hz := s.y * 0.5 + 3.0
	for p in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
		_perimeter.append(Vector3(c.x + p.x, 0.0, c.z + p.z))


func _on_tick(dt: float) -> void:
	if _perimeter.size() < 2 or _elapsed < _rest_until:
		return
	var pos := _body.global_position
	var player := _player_pos()
	var light := _lamp_light_at(player)
	if _charging:
		if light > GIVE_UP_LIGHT:
			_charging = false
			_announce("Something big stopped at the edge of the light.")
		else:
			var to := Vector3(player.x - pos.x, 0, player.z - pos.z)
			if to.length() <= HIT_RANGE:
				_hurt(_hit)
				_charging = false
				_rest_until = _elapsed + 25.0
				_body.global_position = _perimeter[_seg]
				return
			_move(to.normalized() * _charge_speed * dt, 0.28, dt)
			return
	# Patrol the fence line.
	var a: Vector3 = _perimeter[_seg]
	var b: Vector3 = _perimeter[(_seg + 1) % _perimeter.size()]
	var seg_len := a.distance_to(b)
	_seg_t += WALK_SPEED * dt / maxf(seg_len, 0.1)
	if _seg_t >= 1.0:
		_seg_t = 0.0
		_seg = (_seg + 1) % _perimeter.size()
	var target := a.lerp(b, _seg_t)
	_body.global_position = Vector3(target.x, pos.y, target.z)
	_footsteps(dt, 0.9)
	if _distance_to_player(pos) < NOTICE_RANGE and light <= GIVE_UP_LIGHT and _rng.randf() < dt * 0.6:
		_charging = true
		_announce("Heavy footsteps along the fence. They stopped. Now they are coming.")


func _move(step: Vector3, step_interval: float, dt: float) -> void:
	var p := _ground(_body.global_position + step)
	if p != Vector3.INF:
		_body.global_position = p
	_footsteps(dt, step_interval)


func _footsteps(dt: float, interval: float) -> void:
	_step_t -= dt
	if _step_t <= 0.0:
		_step_t = interval
		_sound(SFX_THUMP, _body.global_position, -2.0, _rng.randf_range(0.85, 1.0), 45.0)

