extends "res://scripts/enemies/enemy_base.gd"

## The Photographer (the Tourist; spawned by Drunk guests). Rule: never look at him
## when the flash goes.
##
## A readable cycle, every step announced by its own sound from where he stands:
## 1. MOVE: he takes up a new spot somewhere around you (15-25 m; closer each round),
##    never straight in front of you. A film-advance ratchet says where.
## 2. FRAME: a small red focus lamp blinks there in the dark and the autofocus beeps,
##    faster and faster, then the flash capacitor whines (~3 s in all, shorter on hard
##    nights). That is your time to turn away or get something solid between you.
## 3. FLASH: the whole place lights up from his direction (you see where he was even
##    with your back to him). If he was in your view, with a clear line, he has your
##    picture: damage and a white blast. Either way he moves on; after a hit he backs
##    off instead of following you round.
## Up close (walking into him) he does not bother with the camera.

const SPRITE := "res://assets/textury/npc/enemy_tourist.png"
const SFX_WHINE := "res://assets/sfx/npc/flash_whine.wav"
const SFX_SHUTTER := "res://assets/sfx/npc/shutter.wav"
const SFX_ADVANCE := "res://assets/sfx/npc/photo_advance.mp3"
const SFX_BEEP := "res://assets/sfx/npc/af_beep.wav"
const GRAB_DISTANCE := 2.6

enum Phase { MOVE, FRAME, COOLDOWN }

var _phase := Phase.MOVE
var _phase_end := 0.0
var _frame_seconds := 3.0
var _next_beep := 0.0
var _whine_started := false
var _dist := 22.0
var _min_dist := 10.0
var _flash: OmniLight3D
var _flash_t := 0.0
var _af_lamp: OmniLight3D
var _af_dot: MeshInstance3D
var _photo_damage := 12
var _grab_damage := 30
var _shots := 0
var _hits := 0


func get_enemy_id() -> String:
	return "tourist"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_photo_damage = int(lerpf(10.0, 18.0, t))
	_grab_damage = int(lerpf(26.0, 38.0, t))
	_frame_seconds = lerpf(3.4, 2.2, t)
	_dist = lerpf(24.0, 18.0, t)
	_min_dist = lerpf(12.0, 8.0, t)
	_body = _make_body(SPRITE, 1.9)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.92, 0.95, 1.0)
	_flash.omni_range = 30.0
	_flash.omni_attenuation = 0.8
	_flash.light_energy = 0.0
	_flash.shadow_enabled = true
	_root.add_child(_flash)
	# The red autofocus-assist lamp: the one thing you can see of him in the dark.
	_af_lamp = OmniLight3D.new()
	_af_lamp.light_color = Color(1.0, 0.1, 0.05)
	_af_lamp.omni_range = 1.4
	_af_lamp.light_energy = 0.0
	_root.add_child(_af_lamp)
	_af_dot = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	_af_dot.mesh = sphere
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(1.0, 0.15, 0.1)
	_af_dot.material_override = dot_mat
	_af_dot.visible = false
	_root.add_child(_af_dot)
	# A soft red glow round it, so it reads at 20 m on a low-res screen.
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	glow.mesh = quad
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.albedo_texture = _glow_texture()
	glow_mat.albedo_color = Color(1.0, 0.2, 0.1, 0.9)
	glow.material_override = glow_mat
	_af_dot.add_child(glow)
	_enter_move(_rng.randf_range(4.0, 8.0))


func _on_tick(dt: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		# A hard white pop that falls off over a third of a second.
		_flash.light_energy = 40.0 * pow(_flash_t / 0.35, 2.0)
	_body.visible = true
	if _distance_to_player(_body.global_position) < GRAB_DISTANCE:
		_grab()
		return
	match _phase:
		Phase.MOVE:
			if _elapsed >= _phase_end:
				_enter_frame()
		Phase.FRAME:
			_tick_frame()
		Phase.COOLDOWN:
			if _elapsed >= _phase_end:
				_enter_move(_rng.randf_range(8.0, 14.0))


func _enter_move(wait: float) -> void:
	_phase = Phase.MOVE
	_phase_end = _elapsed + wait
	_set_af(false)
	_relocate()
	_sound(SFX_ADVANCE, _head(), 0.0, _rng.randf_range(0.95, 1.05), 40.0)


func _enter_frame() -> void:
	_phase = Phase.FRAME
	_phase_end = _elapsed + _frame_seconds
	_next_beep = _elapsed
	_whine_started = false
	_announce("A red light blinks between the trees. Beep... beep... Do not look at the flash.")


func _tick_frame() -> void:
	var left := _phase_end - _elapsed
	var progress := 1.0 - left / _frame_seconds
	# The beeps speed up as he settles the focus; the red lamp blinks with them.
	if _elapsed >= _next_beep:
		_next_beep = _elapsed + lerpf(0.6, 0.12, progress)
		_sound(SFX_BEEP, _head(), -2.0, 1.0, 40.0)
		_set_af(true)
	elif _elapsed > _next_beep - lerpf(0.45, 0.06, progress):
		_set_af(false)
	if not _whine_started and left <= 1.2:
		_whine_started = true
		_sound(SFX_WHINE, _head(), 2.0, 1.0, 48.0)
	if left <= 0.0:
		_fire()


func _fire() -> void:
	_set_af(false)
	_shots += 1
	var head := _head()
	_flash.global_position = head + Vector3(0, 0.3, 0)
	_flash_t = 0.35
	_sound(SFX_SHUTTER, head, 4.0, _rng.randf_range(0.95, 1.05), 48.0)
	if _is_seen(head, 4.0):
		_hits += 1
		_hurt(_photo_damage)
		# He has his picture: he backs off rather than following you round.
		_dist = minf(26.0, _dist + 4.0)
	else:
		_dist = maxf(_min_dist, _dist - 3.0)
	_phase = Phase.COOLDOWN
	_phase_end = _elapsed + _rng.randf_range(1.2, 2.2)


func _grab() -> void:
	_hurt(_grab_damage)
	_sound(SFX_SHUTTER, _player_pos() + Vector3(0, 1.6, 0), 6.0, 0.7)
	_dist = 24.0
	_enter_move(_rng.randf_range(5.0, 8.0))


## A new spot to the side or behind (never straight ahead, never where he just was).
func _relocate() -> void:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	for _i in 10:
		var ang := side * _rng.randf_range(70.0, 170.0)
		var p := _point_from_player(_dist, ang)
		if p == Vector3.INF:
			continue
		if _body.global_position.distance_to(p) < 6.0:
			continue
		_body.global_position = p
		return


func _head() -> Vector3:
	return _body.global_position + Vector3(0, 1.6, 0)


func _set_af(on: bool) -> void:
	_af_lamp.global_position = _head() + Vector3(0, 0.05, 0)
	_af_lamp.light_energy = 2.4 if on else 0.0
	_af_dot.global_position = _head() + Vector3(0, 0.05, 0)
	_af_dot.visible = on


func _glow_texture() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(img)


func get_debug_snapshot() -> Dictionary:
	return {
		"phase": ["move", "frame", "cooldown"][_phase],
		"distance": snappedf(_distance_to_player(_body.global_position), 0.1),
		"shots": _shots,
		"hits": _hits,
	}
