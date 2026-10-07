extends "res://scripts/enemies/enemy_base.gd"

## The Tourist (spawned by Drunk guests).
##
## Somewhere out in the camp a camera flash charges (a rising whine, ~1.2 s) and fires.
## If the player is LOOKING at him when it fires, he has his picture: damage, a white
## blast, and he is suddenly much closer for the next shot. If the player looked away,
## the flash lights up an empty field and he wanders off to a new spot.
## The tell is the whine; the counter is turning your back to it. Up close (under
## GRAB_DISTANCE) he does not bother with the camera.

const SPRITE := "res://assets/textury/npc/enemy_tourist.png"
const SFX_WHINE := "res://assets/sfx/npc/flash_whine.wav"
const SFX_SHUTTER := "res://assets/sfx/npc/shutter.wav"
const GRAB_DISTANCE := 2.6

var _next_shot: float = 0.0
var _charging: bool = false
var _fire_at: float = 0.0
var _dist: float = 20.0
var _flash: OmniLight3D
var _flash_t: float = 0.0
var _visible_until: float = 0.0
var _photo_damage: int = 12
var _grab_damage: int = 30
var _interval := Vector2(7.0, 11.0)


func get_enemy_id() -> String:
	return "tourist"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_photo_damage = int(lerpf(10.0, 18.0, t))
	_grab_damage = int(lerpf(26.0, 38.0, t))
	_interval = Vector2(lerpf(9.0, 5.5, t), lerpf(13.0, 8.0, t))
	_dist = lerpf(22.0, 16.0, t)
	_body = _make_body(SPRITE, 1.9)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.92, 0.95, 1.0)
	_flash.omni_range = 14.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	_root.add_child(_flash)
	_relocate(_dist, true)
	_next_shot = _rng.randf_range(4.0, 8.0)


func _on_tick(dt: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		_flash.light_energy = 16.0 * (_flash_t / 0.18)
	var d := _distance_to_player(_body.global_position)
	if d < GRAB_DISTANCE:
		_grab()
		return
	if _charging:
		if _elapsed >= _fire_at:
			_fire()
		return
	_body.visible = _elapsed < _visible_until or _in_flashlight(_body.global_position + Vector3(0, 1.2, 0))
	if _elapsed >= _next_shot:
		_charging = true
		_fire_at = _elapsed + 1.25
		_sound(SFX_WHINE, _body.global_position + Vector3(0, 1.5, 0), 2.0, 1.0, 48.0)
		_announce("Somewhere in the trees, a camera flash is charging.")


func _fire() -> void:
	_charging = false
	var head := _body.global_position + Vector3(0, 1.6, 0)
	_flash.global_position = head + Vector3(0, 0.3, 0)
	_flash_t = 0.18
	_sound(SFX_SHUTTER, head, 4.0, _rng.randf_range(0.95, 1.05), 48.0)
	_body.visible = true
	_visible_until = _elapsed + 0.35
	if _is_seen(head, 4.0):
		_hurt(_photo_damage)
		_dist = maxf(GRAB_DISTANCE + 1.5, _dist * 0.55)
		# Next time he is where you are looking.
		_relocate(_dist, false)
	else:
		_dist = minf(26.0, _dist + 2.0)
		_relocate(_dist, true)
	_next_shot = _elapsed + _rng.randf_range(_interval.x, _interval.y)


func _grab() -> void:
	_hurt(_grab_damage)
	_sound(SFX_SHUTTER, _player_pos() + Vector3(0, 1.6, 0), 6.0, 0.7)
	_dist = 24.0
	_relocate(_dist, true)
	_next_shot = _elapsed + _interval.y


## Behind or beside the player when `out_of_view`, otherwise in front.
func _relocate(dist: float, out_of_view: bool) -> void:
	for _i in 8:
		var ang := _rng.randf_range(100.0, 260.0) if out_of_view else _rng.randf_range(-25.0, 25.0)
		var p := _point_from_player(dist, ang)
		if p == Vector3.INF:
			continue
		_body.global_position = p
		return
