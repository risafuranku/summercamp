extends Node3D

## The other warden as you see them in the camp (co-op, scripts/coop/coop.gd): a sprite
## like the guests' (Grok, front view, assets/textury/npc/warden_*.png) with the same
## stepped walk (bob, sway, the flip of a step), a blob shadow, the torch in their hand
## lighting where they look, and their steps on the grass. Fed with what the other
## machine sends about fifteen times a second and drawn a tenth of a second behind,
## between the two states either side, so they walk instead of jumping. Gone while they
## are in a room, at the PC or on the bus (their "in" flag).

const SPRITE_HEIGHT_M := 1.74
## The guests' walk cycle (scripts/guest_agents.gd), so the two look alike.
const ANIM_FPS := 8.0
const WALK_BOB_HZ := 2.6
## Drawn this far behind the newest state (seconds).
const DELAY := 0.1
## Further than this between two states is a jump (a door, the bus): no sliding.
const SNAP_DIST := 6.0
const FOOTSTEPS := "res://assets/sfx/grassfootsteps.mp3"

var _sprite: Sprite3D
var _shadow: MeshInstance3D
var _beam: SpotLight3D
var _halo: SpotLight3D
var _lens: Sprite3D
var _steps: AudioStreamPlayer3D
var _buf: Array = []          # [{at: seconds, s: state}]
var _time := 0.0
var _speed := 0.0
var _ready_once := false


func setup(look_path: String) -> void:
	name = "OtherWarden"
	add_to_group("coop_remote_player")
	var tex: Texture2D = load(look_path) if ResourceLoader.exists(look_path) else null
	_sprite = Sprite3D.new()
	_sprite.name = "Sprite"
	_sprite.texture = tex
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.double_sided = true
	if tex != null:
		_sprite.pixel_size = SPRITE_HEIGHT_M / float(tex.get_height())
		_sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
	add_child(_sprite)
	_shadow = MeshInstance3D.new()
	_shadow.name = "BlobShadow"
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 0.42)
	q.orientation = PlaneMesh.FACE_Y
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.0, 0.0, 0.0, 0.42)
	q.material = sm
	_shadow.mesh = q
	_shadow.position = Vector3(0.0, 0.03, 0.0)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	# Their torch: the same beam and halo as yours (player_controller.gd), a little
	# weaker seen from outside, and the bulb itself when it points your way.
	_beam = SpotLight3D.new()
	_beam.name = "TorchBeam"
	_beam.light_color = Color(1.0, 0.94, 0.82)
	_beam.light_energy = 2.4
	_beam.spot_range = 16.0
	_beam.spot_angle = 19.0
	_beam.spot_attenuation = 0.95
	_beam.shadow_enabled = false
	_beam.visible = false
	add_child(_beam)
	_halo = SpotLight3D.new()
	_halo.name = "TorchHalo"
	_halo.light_color = Color(1.0, 0.92, 0.8)
	_halo.light_energy = 0.34
	_halo.spot_range = 7.0
	_halo.spot_angle = 34.0
	_halo.shadow_enabled = false
	_halo.visible = false
	add_child(_halo)
	_lens = Sprite3D.new()
	_lens.name = "TorchLens"
	_lens.texture = _lens_texture()
	_lens.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lens.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_lens.shaded = false
	_lens.transparent = true
	_lens.pixel_size = 0.02
	_lens.no_depth_test = false
	_lens.visible = false
	add_child(_lens)
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "Steps"
	var st: AudioStream = load(FOOTSTEPS) if ResourceLoader.exists(FOOTSTEPS) else null
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	_steps.stream = st
	_steps.unit_size = 3.0
	_steps.max_distance = 26.0
	_steps.volume_db = -80.0
	_steps.position = Vector3(0.0, 0.2, 0.0)
	add_child(_steps)
	visible = false


## A small round glow, drawn once: the bulb of the torch seen from in front.
static func _lens_texture() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x - 3.5, y - 3.5).length()
			var a := clampf(1.0 - d / 4.0, 0.0, 1.0)
			# Stepped, like the game's other glows (no smooth bloom).
			a = floorf(a * 4.0) / 4.0
			img.set_pixel(x, y, Color(1.0, 0.95, 0.8, a))
	return ImageTexture.create_from_image(img)


## One state from the other machine: {p: Vector3, y: yaw, d: torch direction, t: torch
## on, v: speed, in: inside something}.
func push_state(s: Dictionary) -> void:
	_buf.append({"at": Time.get_ticks_msec() / 1000.0, "s": s})
	while _buf.size() > 16:
		_buf.pop_front()


func _process(delta: float) -> void:
	_time += delta
	if _buf.is_empty():
		visible = false
		return
	var now := Time.get_ticks_msec() / 1000.0 - DELAY
	var a: Dictionary = _buf[0]
	var b: Dictionary = _buf[_buf.size() - 1]
	for i in range(_buf.size() - 1):
		if float(_buf[i]["at"]) <= now and float(_buf[i + 1]["at"]) >= now:
			a = _buf[i]
			b = _buf[i + 1]
			break
	var sa: Dictionary = a["s"]
	var sb: Dictionary = b["s"]
	var pa: Vector3 = sa.get("p", global_position)
	var pb: Vector3 = sb.get("p", pa)
	var span := float(b["at"]) - float(a["at"])
	var f := clampf((now - float(a["at"])) / span, 0.0, 1.0) if span > 0.0001 else 1.0
	if pa.distance_to(pb) > SNAP_DIST:
		f = 1.0
	var inside := bool(sb.get("in", false))
	visible = not inside
	global_position = pa.lerp(pb, f) if _ready_once else pb
	_ready_once = true
	_speed = lerpf(_speed, float(sb.get("v", 0.0)), clampf(delta * 10.0, 0.0, 1.0))
	_animate()
	_aim_torch(sb, inside)
	_update_steps(inside)


## The guests' walk: steps at ANIM_FPS, a bob, a sway, the flip on each step.
func _animate() -> void:
	if _sprite == null:
		return
	if _speed > 0.4:
		var phase := floorf(_time * ANIM_FPS) / ANIM_FPS * WALK_BOB_HZ * TAU * clampf(_speed / 3.9, 0.7, 1.4)
		_sprite.position.y = absf(sin(phase)) * 0.06
		_sprite.flip_h = sin(phase * 0.5) > 0.0
		_sprite.rotation.z = sin(phase) * 0.04
	else:
		_sprite.position.y = 0.0
		_sprite.rotation.z = sin(floorf(_time * ANIM_FPS) / ANIM_FPS * 0.8) * 0.01


func _aim_torch(s: Dictionary, inside: bool) -> void:
	var on := bool(s.get("t", false)) and not inside
	_beam.visible = on
	_halo.visible = on
	_lens.visible = false
	if not on:
		return
	var dir: Vector3 = s.get("d", Vector3.FORWARD)
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	# The torch in their right hand, a little in front of them at chest height.
	var yaw := float(s.get("y", 0.0))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var hand := Vector3(0.0, 1.2, 0.0) + right * 0.28 + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 0.2
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var xf := Transform3D(Basis.looking_at(dir, up), hand)
	_beam.transform = xf
	_halo.transform = xf
	# The bulb shows when the beam comes your way.
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		var to_cam := (cam.global_position - (global_position + hand)).normalized()
		if dir.dot(to_cam) > 0.55:
			_lens.visible = true
			_lens.position = hand + dir * 0.12
			_lens.modulate.a = clampf((dir.dot(to_cam) - 0.55) / 0.3, 0.3, 1.0)


func _update_steps(inside: bool) -> void:
	if _steps == null or _steps.stream == null:
		return
	var walking := _speed > 0.4 and not inside
	if walking and not _steps.playing:
		_steps.play()
	_steps.volume_db = lerpf(-24.0, -4.0, clampf(_speed / 5.2, 0.0, 1.0)) if walking else -80.0
	_steps.pitch_scale = lerpf(0.95, 1.08, clampf(_speed / 5.2, 0.0, 1.0))
	if not walking and _steps.playing and _steps.volume_db <= -79.0:
		_steps.stop()
