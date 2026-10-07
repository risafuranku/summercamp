extends CharacterBody3D

const YAW_SENSITIVITY_FACTOR := 2.0

@export var move_speed: float = 3.9
@export var sprint_speed: float = 5.2
@export var jump_velocity: float = 4.4
@export var gravity: float = 26.0
@export var mouse_sensitivity: float = 0.0012
@export var invert_vertical_look: bool = false
@export var vertical_look_sensitivity_multiplier: float = 0.85
@export var vertical_look_limit_degrees: float = 14.0
@export var vertical_look_snap_degrees: float = 1.4
@export var vertical_look_smoothing: float = 14.0
@export var pseudo_pitch_vertical_shift: float = 0.045
@export var pseudo_pitch_forward_shift: float = 0.018
@export var pseudo_pitch_rotation_mix: float = 0.72
@export var pseudo_pitch_screen_shift: float = 0.085
@export var pseudo_pitch_fov_shift: float = 1.0
@export var ground_acceleration: float = 11.0
@export var ground_deceleration: float = 8.0
@export var air_acceleration: float = 2.2
@export var camera_fov: float = 49.0
@export var camera_far: float = 1000.0
@export var camera_near: float = 0.08
@export var bob_frequency: float = 7.8
@export var bob_vertical: float = 0.08
@export var bob_horizontal: float = 0.05
@export var bob_smoothing: float = 12.0
@export var bob_snap_step: float = 0.012
@export var bob_snap_blend: float = 0.38
@export var base_tilt_amount: float = 0.035
@export var rotation_tilt_amount: float = 0.045
@export var tilt_smoothing: float = 4.0
@export var step_kick_strength: float = 0.028
@export var step_kick_decay: float = 9.0
@export var handheld_look_strength: float = 0.00022
@export var handheld_return: float = 10.0
@export var handheld_idle_strength: float = 0.012
@export var flashlight_energy: float = 3.5
@export var flashlight_range: float = 22.0
@export var flashlight_angle: float = 38.0
@export var flashlight_attenuation: float = 0.7
@export var flashlight_cast_shadows: bool = false
@export var flashlight_fill_energy: float = 0.5
@export var flashlight_fill_range: float = 6.0
@export var flashlight_flicker_strength: float = 0.04
@export var flashlight_flicker_speed: float = 14.0
@export var footstep_motion_attack: float = 6.6
@export var footstep_motion_release: float = 4.3
@export var footstep_stride_min: float = 0.14
@export var footstep_stride_max: float = 1.22
@export var footstep_pitch_idle: float = 0.985
@export var footstep_pitch_run: float = 1.03
@export var footstep_pitch_response: float = 0.80
@export var footstep_pitch_deadzone: float = 0.16
@export var footstep_pitch_lerp_speed: float = 8.0
@export var footstep_pitch_return_speed: float = 14.0
@export var footstep_surface_blend_speed: float = 6.5
@export var footstep_loop_gain: float = 0.48

const FOOTSTEP_GRASS_PATH := "res://assets/sfx/grassfootsteps.mp3"
const FOOTSTEP_GRAVEL_PATH := "res://assets/sfx/gravelfootsteps.mp3"
const FOOTSTEP_SILENT_DB := -80.0
const FOOTSTEP_MIN_AUDIBLE_SPEED := 0.14
const FOOTSTEP_MIN_AUDIBLE_RATIO := 0.06
const DAMAGE_TIER_SMALL: int = 0
const DAMAGE_TIER_MEDIUM: int = 1
const DAMAGE_TIER_LARGE: int = 2
const DAMAGE_TIER_MEGA: int = 3
const DAMAGE_TIER_LETHAL: int = 4
const DAMAGE_TIER_ALPHA := [0.12, 0.22, 0.34, 0.50, 0.72]
const DAMAGE_TIER_SHAKE := [0.010, 0.020, 0.032, 0.048, 0.070]
const DAMAGE_TIER_FOV_PUSH := [0.4, 0.9, 1.6, 2.5, 4.2]
const DAMAGE_TIER_HIT_KICK := [0.018, 0.032, 0.050, 0.072, 0.105]
const DEATH_FALL_DURATION: float = 0.96
const DEATH_FALL_HOLD_SEC: float = 1.08
const FOOTSTEP_SURFACE_SAMPLE_OFFSETS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(0.24, 0.22),
	Vector2(-0.24, 0.22),
	Vector2(0.24, -0.22),
	Vector2(-0.24, -0.22)
]

var _pitch: float = 0.0
var _pitch_target: float = 0.0
var _head: Node3D
var _camera: Camera3D
var _base_head_pos: Vector3 = Vector3(0.0, 1.55, 0.0)
var _bob_time: float = 0.0
var _bob_offset: Vector3 = Vector3.ZERO
var _prev_step_wave: float = 0.0
var _step_kick: float = 0.0
var _mouse_impact: Vector2 = Vector2.ZERO
var _current_tilt: float = 0.0
var _idle_noise_time: float = 0.0
var _flashlight: SpotLight3D
var _flashlight_fill: OmniLight3D
var _flashlight_allowed: bool = false
var _flashlight_user_enabled: bool = true
var _flashlight_active: bool = false
var _flashlight_flicker_time: float = 0.0
var _grid_manager: Node
var _footstep_grass_player: AudioStreamPlayer
var _footstep_gravel_player: AudioStreamPlayer
var _footstep_motion_ratio: float = 0.0
var _footstep_surface_mix: float = 0.0
var _footstep_target_surface_mix: float = 0.0
var _footstep_pitch_scale: float = 1.0
var _damage_rng := RandomNumberGenerator.new()
var _damage_overlay_layer: CanvasLayer
var _damage_overlay_tint: ColorRect
var _damage_overlay_noise: TextureRect
var _damage_overlay_alpha: float = 0.0
var _damage_overlay_decay_speed: float = 0.0
var _damage_shake_intensity: float = 0.0
var _damage_shake_decay_speed: float = 9.0
var _damage_fov_push: float = 0.0
var _damage_flicker_time: float = 0.0
var _death_fall_active: bool = false
var _death_fall_tween: Tween
var controls_enabled: bool = true

func _ready() -> void:
	name = "Player"
	_damage_rng.randomize()
	ensure_runtime_setup()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func ensure_runtime_setup() -> void:
	_ensure_input_actions()
	_ensure_body()
	_ensure_camera()
	_ensure_damage_overlay()
	_remove_barrel_overlay_if_present()
	_ensure_footstep_audio()
	reset_damage_feedback_state()


func _ensure_body() -> void:
	var collider = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null:
		collider = CollisionShape3D.new()
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.2
		collider.shape = capsule
		collider.position = Vector3(0.0, 0.95, 0.0)
		add_child(collider)

	_head = get_node_or_null("Head") as Node3D
	if _head == null:
		_head = Node3D.new()
		_head.name = "Head"
		_head.position = _base_head_pos
		add_child(_head)
	else:
		_base_head_pos = _head.position


func _ensure_camera() -> void:
	if _head == null:
		return

	var camera = _head.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		_head.add_child(camera)
	_camera = camera
	camera.fov = camera_fov
	camera.far = camera_far
	camera.near = camera_near
	camera.current = true
	_ensure_flashlight()


func _remove_barrel_overlay_if_present() -> void:
	var layer = get_node_or_null("BarrelLayer")
	if layer != null:
		layer.queue_free()



func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var look_scale := 1.0
		var invert := invert_vertical_look
		if GameSettings != null:
			look_scale = GameSettings.get_mouse_sensitivity()
			invert = invert != GameSettings.get_invert_mouse_y()
		# Yaw used to be applied twice by accident; the doubled speed is what the game
		# was tuned with, so it is kept as an explicit factor.
		rotate_y(-event.relative.x * mouse_sensitivity * YAW_SENSITIVITY_FACTOR * look_scale)
		var pitch_input = -event.relative.y
		if invert:
			pitch_input = -pitch_input
		
		# Add rotational tilt target based on mouse input
		_current_tilt = lerp(_current_tilt, clamp(event.relative.x * rotation_tilt_amount, -0.1, 0.1), 0.15)
		
		_pitch_target += pitch_input * mouse_sensitivity * vertical_look_sensitivity_multiplier * look_scale
		_pitch_target = clamp(_pitch_target, -deg_to_rad(vertical_look_limit_degrees), deg_to_rad(vertical_look_limit_degrees))
		_mouse_impact += Vector2(0.0, -event.relative.x) * handheld_look_strength
		_mouse_impact.y = clamp(_mouse_impact.y, -0.08, 0.08)

	if event.is_action_pressed("toggle_flashlight"):
		_flashlight_user_enabled = not _flashlight_user_enabled
		_refresh_flashlight_state()

	# Esc is the pause menu (main.gd), which releases and recaptures the mouse.
	# A click recaptures it if something else (alt-tab, a closed window) let it go.
	var click := event as InputEventMouseButton
	if click != null and click.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_deceleration * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		if not _death_fall_active:
			_update_head_motion(delta)
		_update_flashlight_effect(delta)
		_update_damage_visuals(delta)
		return

	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var local_dir = Vector3(input_vec.x, 0.0, input_vec.y)
	var move_dir = (global_transform.basis * local_dir).normalized()
	var current_speed = sprint_speed if Input.is_action_pressed("move_sprint") else move_speed
	var target_x = move_dir.x * current_speed
	var target_z = move_dir.z * current_speed
	var accel = air_acceleration if not is_on_floor() else ground_acceleration
	var decel = max(1.0, ground_deceleration)

	if move_dir.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, target_x, accel * delta)
		velocity.z = move_toward(velocity.z, target_z, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("move_jump"):
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0

	move_and_slide()
	if not _death_fall_active:
		_update_head_motion(delta)
	_update_flashlight_effect(delta)
	_update_damage_visuals(delta)


func _ensure_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_backward", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_jump", KEY_SPACE)
	_add_key_action("move_sprint", KEY_SHIFT)
	_add_key_action("toggle_flashlight", KEY_UNKNOWN) # Flashlight is automatic now
	_add_key_action("toggle_interior_light", KEY_L)


func _add_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var key_event = InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not controls_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_force_footstep_silence(true)


func set_grid_manager(grid_manager: Node) -> void:
	_grid_manager = grid_manager


func set_flashlight_allowed(allowed: bool) -> void:
	_flashlight_allowed = allowed
	if _flashlight_allowed:
		_flashlight_user_enabled = true
	_refresh_flashlight_state()


func is_flashlight_active() -> bool:
	return _flashlight_active


func play_damage_feedback(tier: int, _damage_amount: int, fatal: bool = false) -> void:
	var clamped_tier = clampi(tier, DAMAGE_TIER_SMALL, DAMAGE_TIER_LETHAL)
	_damage_overlay_alpha = maxf(_damage_overlay_alpha, float(DAMAGE_TIER_ALPHA[clamped_tier]))
	_damage_overlay_decay_speed = lerpf(1.2, 0.20, float(clamped_tier) / float(DAMAGE_TIER_LETHAL))
	_damage_shake_intensity = maxf(_damage_shake_intensity, float(DAMAGE_TIER_SHAKE[clamped_tier]))
	_damage_shake_decay_speed = lerpf(8.2, 1.2, float(clamped_tier) / float(DAMAGE_TIER_LETHAL))
	_damage_fov_push = maxf(_damage_fov_push, float(DAMAGE_TIER_FOV_PUSH[clamped_tier]))
	_damage_flicker_time = 0.0

	var kick = float(DAMAGE_TIER_HIT_KICK[clamped_tier])
	_mouse_impact.x += _damage_rng.randf_range(-kick, kick)
	_mouse_impact.y += _damage_rng.randf_range(-kick, kick)
	_mouse_impact.x = clampf(_mouse_impact.x, -0.18, 0.18)
	_mouse_impact.y = clampf(_mouse_impact.y, -0.16, 0.16)
	_current_tilt += _damage_rng.randf_range(-kick * 0.8, kick * 0.8)
	_current_tilt = clampf(_current_tilt, -0.16, 0.16)

	if fatal:
		_damage_overlay_alpha = maxf(_damage_overlay_alpha, 0.82)
		_damage_overlay_decay_speed = 0.14
		_damage_shake_intensity = maxf(_damage_shake_intensity, 0.075)
		_damage_shake_decay_speed = 0.85
		_damage_fov_push = maxf(_damage_fov_push, 4.8)

	_sync_damage_overlay_visual()


func play_death_fall() -> float:
	if _death_fall_active:
		return DEATH_FALL_DURATION + DEATH_FALL_HOLD_SEC
	_death_fall_active = true
	_force_footstep_silence(true)
	if _death_fall_tween != null and is_instance_valid(_death_fall_tween):
		_death_fall_tween.kill()

	play_damage_feedback(DAMAGE_TIER_LETHAL, 999, true)
	_mouse_impact = Vector2.ZERO
	_current_tilt = 0.0
	_pitch = 0.0
	_pitch_target = 0.0

	if _head != null:
		_death_fall_tween = create_tween()
		_death_fall_tween.set_parallel(true)
		_death_fall_tween.set_trans(Tween.TRANS_CUBIC)
		_death_fall_tween.set_ease(Tween.EASE_IN)
		var head_target_pos = _base_head_pos + Vector3(-0.20, -1.30, 0.58)
		var head_target_rot = Vector3(deg_to_rad(83.0), deg_to_rad(-8.0), deg_to_rad(-68.0))
		_death_fall_tween.tween_property(_head, "position", head_target_pos, DEATH_FALL_DURATION)
		_death_fall_tween.tween_property(_head, "rotation", head_target_rot, DEATH_FALL_DURATION)
		_death_fall_tween.tween_property(self, "rotation:z", deg_to_rad(-14.0), DEATH_FALL_DURATION)
		if _camera != null:
			_death_fall_tween.tween_property(_camera, "fov", camera_fov + 14.0, DEATH_FALL_DURATION)

	return DEATH_FALL_DURATION + DEATH_FALL_HOLD_SEC


func reset_damage_feedback_state(clear_overlay: bool = false) -> void:
	if _death_fall_tween != null and is_instance_valid(_death_fall_tween):
		_death_fall_tween.kill()
	_death_fall_tween = null
	_death_fall_active = false
	_damage_overlay_alpha = 0.0
	_damage_overlay_decay_speed = 0.0
	_damage_shake_intensity = 0.0
	_damage_shake_decay_speed = 9.0
	_damage_fov_push = 0.0
	_damage_flicker_time = 0.0
	_mouse_impact = Vector2.ZERO
	_current_tilt = 0.0
	_pitch = 0.0
	_pitch_target = 0.0

	if _head != null:
		_head.position = _base_head_pos
		_head.rotation = Vector3.ZERO
	if _camera != null:
		_camera.fov = camera_fov
	rotation.z = 0.0

	if clear_overlay:
		if _damage_overlay_layer != null and is_instance_valid(_damage_overlay_layer):
			_damage_overlay_layer.queue_free()
		_damage_overlay_layer = null
		_damage_overlay_tint = null
		_damage_overlay_noise = null
		return

	_sync_damage_overlay_visual()


func _ensure_damage_overlay() -> void:
	if _damage_overlay_layer == null or not is_instance_valid(_damage_overlay_layer):
		_damage_overlay_layer = CanvasLayer.new()
		_damage_overlay_layer.name = "DamageOverlayLayer"
		_damage_overlay_layer.layer = 160
		add_child(_damage_overlay_layer)

	var root := _damage_overlay_layer.get_node_or_null("Root") as Control
	if root == null:
		root = Control.new()
		root.name = "Root"
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_damage_overlay_layer.add_child(root)

	_damage_overlay_tint = root.get_node_or_null("DamageTint") as ColorRect
	if _damage_overlay_tint == null:
		_damage_overlay_tint = ColorRect.new()
		_damage_overlay_tint.name = "DamageTint"
		_damage_overlay_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		_damage_overlay_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_damage_overlay_tint.color = Color(0.58, 0.03, 0.03, 0.0)
		root.add_child(_damage_overlay_tint)

	_damage_overlay_noise = root.get_node_or_null("DamageNoise") as TextureRect
	if _damage_overlay_noise == null:
		_damage_overlay_noise = TextureRect.new()
		_damage_overlay_noise.name = "DamageNoise"
		_damage_overlay_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
		_damage_overlay_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_damage_overlay_noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_damage_overlay_noise.stretch_mode = TextureRect.STRETCH_TILE
		_damage_overlay_noise.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_damage_overlay_noise.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_damage_overlay_noise.texture = _build_damage_noise_texture()
		_damage_overlay_noise.modulate = Color(0.76, 0.08, 0.08, 0.0)
		root.add_child(_damage_overlay_noise)

	_sync_damage_overlay_visual()


func _build_damage_noise_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var local_rng := RandomNumberGenerator.new()
	local_rng.randomize()
	for y in range(64):
		for x in range(64):
			var edge = absf(float(x - 32)) / 32.0 + absf(float(y - 32)) / 32.0
			var chance = clampf(0.22 + (edge * 0.32), 0.0, 0.86)
			if local_rng.randf() > chance:
				continue
			var dark = local_rng.randf_range(0.10, 0.32)
			var alpha = local_rng.randf_range(0.12, 0.86)
			img.set_pixel(x, y, Color(0.66 - dark, 0.04, 0.04, alpha))
	return ImageTexture.create_from_image(img)


func _update_damage_visuals(delta: float) -> void:
	if _damage_overlay_alpha > 0.0:
		_damage_overlay_alpha = move_toward(_damage_overlay_alpha, 0.0, maxf(0.02, _damage_overlay_decay_speed) * delta)
	if _damage_shake_intensity > 0.0:
		_damage_shake_intensity = move_toward(_damage_shake_intensity, 0.0, maxf(0.1, _damage_shake_decay_speed) * delta)
	if _damage_fov_push > 0.0:
		_damage_fov_push = move_toward(_damage_fov_push, 0.0, 4.8 * delta)

	if _damage_overlay_alpha > 0.001:
		_damage_flicker_time += delta * (7.0 + (_damage_shake_intensity * 120.0))
		if _damage_overlay_noise != null:
			var flicker = 0.62 + (sin(_damage_flicker_time * 2.6) * 0.18) + (sin(_damage_flicker_time * 5.1) * 0.12)
			_damage_overlay_noise.modulate.a = clampf(_damage_overlay_alpha * flicker, 0.0, 1.0)
			_damage_overlay_noise.position = Vector2(
				sin(_damage_flicker_time * 1.7) * 18.0,
				cos(_damage_flicker_time * 2.3) * 12.0
			)
	else:
		_damage_flicker_time = 0.0

	if _death_fall_active and _damage_overlay_alpha < 0.18:
		_damage_overlay_alpha = 0.18

	_sync_damage_overlay_visual()


func _sync_damage_overlay_visual() -> void:
	if _damage_overlay_layer == null or not is_instance_valid(_damage_overlay_layer):
		return
	if _damage_overlay_tint != null:
		_damage_overlay_tint.color = Color(0.58, 0.03, 0.03, clampf(_damage_overlay_alpha, 0.0, 1.0))
	if _damage_overlay_noise != null and _damage_overlay_alpha <= 0.001:
		_damage_overlay_noise.modulate.a = 0.0


func _update_head_motion(delta: float) -> void:
	if _head == null:
		return
	if _death_fall_active:
		return

	var pitch_target = _snap_pitch(_pitch_target)
	_pitch = lerp(_pitch, pitch_target, clamp(delta * vertical_look_smoothing, 0.0, 1.0))

	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < FOOTSTEP_MIN_AUDIBLE_SPEED:
		horizontal_speed = 0.0
	var target_motion_ratio = 0.0
	if is_on_floor():
		target_motion_ratio = clamp(horizontal_speed / max(sprint_speed, 0.001), 0.0, 1.2)
	var motion_response = footstep_motion_attack if target_motion_ratio > _footstep_motion_ratio else footstep_motion_release
	_footstep_motion_ratio = move_toward(
		_footstep_motion_ratio,
		target_motion_ratio,
		max(0.01, motion_response) * delta
	)

	var stride_ratio = clamp(_footstep_motion_ratio, 0.0, 1.0)
	var stride_rate = lerp(footstep_stride_min, footstep_stride_max, stride_ratio)
	if not is_on_floor():
		stride_rate = footstep_stride_min
	_bob_time += delta * bob_frequency * max(0.01, stride_rate)

	var step_wave = sin(_bob_time)
	if is_on_floor() and _footstep_motion_ratio > 0.05:
		if (_prev_step_wave < 0.0 and step_wave >= 0.0) or (_prev_step_wave >= 0.0 and step_wave < 0.0):
			_step_kick = min(_step_kick + 1.0, 1.0)
	_prev_step_wave = step_wave
	_step_kick = move_toward(_step_kick, 0.0, step_kick_decay * delta)

	var bob_ratio = clamp(_footstep_motion_ratio, 0.0, 1.2)
	var bob_x = sin(_bob_time * 0.5) * bob_horizontal * bob_ratio
	var smooth_y = (1.0 - abs(cos(_bob_time))) * bob_vertical * bob_ratio
	var snapped_y = floor(smooth_y / max(bob_snap_step, 0.0001)) * bob_snap_step
	var bob_y = lerp(smooth_y, snapped_y, bob_snap_blend) - (_step_kick * step_kick_strength * bob_ratio)

	_idle_noise_time += delta * (1.8 + (bob_ratio * 2.2))
	var idle_roll = sin(_idle_noise_time * 1.7) * handheld_idle_strength
	var idle_pitch = cos(_idle_noise_time * 1.3) * handheld_idle_strength * 0.65

	_update_footstep_loop(delta, _footstep_motion_ratio, is_on_floor())

	_mouse_impact = _mouse_impact.move_toward(Vector2.ZERO, handheld_return * delta)
	var target_offset = Vector3(bob_x, bob_y, 0.0)
	_bob_offset = _bob_offset.lerp(target_offset, clamp(delta * bob_smoothing, 0.0, 1.0))
	var pitch_limit = max(deg_to_rad(vertical_look_limit_degrees), 0.0001)
	var pitch_ratio = clamp(_pitch / pitch_limit, -1.0, 1.0)
	var pseudo_offset = Vector3(0.0, -pitch_ratio * pseudo_pitch_vertical_shift, abs(pitch_ratio) * pseudo_pitch_forward_shift)
	var damage_pos_jitter := Vector3.ZERO
	var damage_rot_jitter := Vector2.ZERO
	if _damage_shake_intensity > 0.0001:
		damage_pos_jitter = Vector3(
			_damage_rng.randf_range(-0.20, 0.20),
			_damage_rng.randf_range(-0.24, 0.18),
			_damage_rng.randf_range(-0.12, 0.12)
		) * _damage_shake_intensity
		damage_rot_jitter = Vector2(
			_damage_rng.randf_range(-0.9, 0.9),
			_damage_rng.randf_range(-0.8, 0.8)
		) * _damage_shake_intensity
	_head.position = _base_head_pos + _bob_offset + pseudo_offset + damage_pos_jitter
	var visual_pitch = _pitch * clamp(pseudo_pitch_rotation_mix, 0.0, 1.0)
	var jitter_roll = sin(_idle_noise_time * 2.4) * handheld_idle_strength * 0.4
	var jitter_pitch = cos(_idle_noise_time * 2.1) * handheld_idle_strength * 0.4
	
	_head.rotation.x = visual_pitch + _mouse_impact.x + idle_pitch + jitter_pitch + damage_rot_jitter.x
	
	# Apply dynamic tilt
	var input_tilt = Input.get_axis("move_right", "move_left") * base_tilt_amount * bob_ratio
	_current_tilt = lerp(_current_tilt, input_tilt, delta * tilt_smoothing)
	_head.rotation.z = _mouse_impact.y + idle_roll + jitter_roll + _current_tilt + damage_rot_jitter.y
	if _camera != null:
		var target_fov = camera_fov + (abs(pitch_ratio) * pseudo_pitch_fov_shift) + _damage_fov_push
		_camera.fov = lerp(_camera.fov, target_fov, clamp(delta * 9.0, 0.0, 1.0))


func _snap_pitch(value: float) -> float:
	if vertical_look_snap_degrees <= 0.0:
		return value
	var step = deg_to_rad(vertical_look_snap_degrees)
	return round(value / step) * step


func _ensure_flashlight() -> void:
	if _head == null:
		return

	# Remove legacy ground fill if it exists from a previous run.
	var old_ground_fill = _head.get_node_or_null("FlashlightGroundFill")
	if old_ground_fill != null:
		old_ground_fill.queue_free()

	# Tight cone SpotLight3D — the actual flashlight beam.
	_flashlight = _head.get_node_or_null("Flashlight") as SpotLight3D
	if _flashlight == null:
		_flashlight = SpotLight3D.new()
		_flashlight.name = "Flashlight"
		_head.add_child(_flashlight)
	_flashlight.position = Vector3(0.18, -0.08, -0.22)
	_flashlight.rotation = Vector3(deg_to_rad(-25.0), 0.0, 0.0)
	_flashlight.light_color = Color(1.0, 0.92, 0.78)
	_flashlight.light_energy = flashlight_energy
	_flashlight.light_cull_mask = 1048575
	_flashlight.spot_range = flashlight_range
	_flashlight.spot_angle = flashlight_angle
	_flashlight.spot_attenuation = flashlight_attenuation
	_flashlight.shadow_enabled = flashlight_cast_shadows

	# Tiny near-player fill so the immediate area isn't pitch black.
	_flashlight_fill = _head.get_node_or_null("FlashlightFill") as OmniLight3D
	if _flashlight_fill == null:
		_flashlight_fill = OmniLight3D.new()
		_flashlight_fill.name = "FlashlightFill"
		_head.add_child(_flashlight_fill)
	_flashlight_fill.position = Vector3(0.0, -0.05, -0.1)
	_flashlight_fill.light_color = Color(1.0, 0.94, 0.82)
	_flashlight_fill.light_energy = flashlight_fill_energy
	_flashlight_fill.light_cull_mask = 1048575
	_flashlight_fill.omni_range = flashlight_fill_range
	_flashlight_fill.omni_attenuation = 2.2
	_flashlight_fill.shadow_enabled = false

	_refresh_flashlight_state()


func _refresh_flashlight_state() -> void:
	_flashlight_active = _flashlight_allowed and _flashlight_user_enabled
	if _flashlight != null:
		_flashlight.visible = _flashlight_active
		_flashlight.light_energy = flashlight_energy if _flashlight_active else 0.0
	if _flashlight_fill != null:
		_flashlight_fill.visible = _flashlight_active
		_flashlight_fill.light_energy = flashlight_fill_energy if _flashlight_active else 0.0


func _update_flashlight_effect(delta: float) -> void:
	if _flashlight == null or not _flashlight_active:
		return

	_flashlight_flicker_time += delta * flashlight_flicker_speed
	var flicker = 1.0
	flicker += sin(_flashlight_flicker_time * 1.0) * flashlight_flicker_strength
	flicker += sin(_flashlight_flicker_time * 2.3) * flashlight_flicker_strength * 0.45
	flicker = clamp(flicker, 0.88, 1.12)

	_flashlight.light_energy = flashlight_energy * flicker
	if _flashlight_fill != null:
		_flashlight_fill.light_energy = flashlight_fill_energy * (0.95 + ((flicker - 1.0) * 0.3))


func _ensure_footstep_audio() -> void:
	if _footstep_grass_player == null:
		_footstep_grass_player = AudioStreamPlayer.new()
		_footstep_grass_player.name = "FootstepGrassLoop"
		_footstep_grass_player.volume_db = FOOTSTEP_SILENT_DB
		add_child(_footstep_grass_player)
	if _footstep_gravel_player == null:
		_footstep_gravel_player = AudioStreamPlayer.new()
		_footstep_gravel_player.name = "FootstepGravelLoop"
		_footstep_gravel_player.volume_db = FOOTSTEP_SILENT_DB
		add_child(_footstep_gravel_player)

	_footstep_grass_player.stream = _load_footstep_loop_stream(FOOTSTEP_GRASS_PATH)
	_footstep_gravel_player.stream = _load_footstep_loop_stream(FOOTSTEP_GRAVEL_PATH)
	_ensure_footstep_loops_running()
	_apply_surface_loop_volumes(0.0, _footstep_surface_mix)


func _load_footstep_loop_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream = load(path) as AudioStream
	if stream == null:
		return null
	_set_stream_looping(stream, true)
	return stream


func _set_stream_looping(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = should_loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED


func _ensure_footstep_loops_running() -> void:
	if _footstep_grass_player == null or _footstep_gravel_player == null:
		return
	var sync_pos := 0.0
	if _footstep_grass_player.playing:
		sync_pos = _footstep_grass_player.get_playback_position()
	elif _footstep_gravel_player.playing:
		sync_pos = _footstep_gravel_player.get_playback_position()

	if _footstep_grass_player.stream != null and not _footstep_grass_player.playing:
		_footstep_grass_player.play(sync_pos)
	if _footstep_gravel_player.stream != null and not _footstep_gravel_player.playing:
		_footstep_gravel_player.play(sync_pos)


func _update_footstep_loop(delta: float, motion_ratio: float, is_grounded: bool) -> void:
	if _footstep_grass_player == null or _footstep_gravel_player == null:
		return

	var movement_ratio = clamp(motion_ratio, 0.0, 1.0)
	if movement_ratio < FOOTSTEP_MIN_AUDIBLE_RATIO:
		movement_ratio = 0.0
	if not is_grounded:
		movement_ratio = move_toward(movement_ratio, 0.0, delta * 8.0)
	if movement_ratio <= 0.0:
		_force_footstep_silence(true)
		return

	_ensure_footstep_loops_running()

	_footstep_target_surface_mix = _sample_gravel_surface_mix()
	_footstep_surface_mix = move_toward(
		_footstep_surface_mix,
		_footstep_target_surface_mix,
		max(0.01, footstep_surface_blend_speed) * delta
	)

	var normalized_pitch_ratio = clamp(
		(movement_ratio - footstep_pitch_deadzone) / max(0.001, 1.0 - footstep_pitch_deadzone),
		0.0,
		1.0
	)
	var pitch_t = pow(normalized_pitch_ratio, max(0.01, footstep_pitch_response))
	var target_pitch_scale = 1.0 if normalized_pitch_ratio <= 0.0 else lerp(footstep_pitch_idle, footstep_pitch_run, pitch_t)
	var pitch_step_speed = footstep_pitch_return_speed if target_pitch_scale < _footstep_pitch_scale else footstep_pitch_lerp_speed
	_footstep_pitch_scale = move_toward(
		_footstep_pitch_scale,
		target_pitch_scale,
		max(0.01, pitch_step_speed) * delta
	)
	_footstep_grass_player.pitch_scale = _footstep_pitch_scale
	_footstep_gravel_player.pitch_scale = _footstep_pitch_scale

	var loudness = pow(movement_ratio, 0.78)
	var linear_gain = clamp(footstep_loop_gain * loudness, 0.0, 1.0)
	_apply_surface_loop_volumes(linear_gain, _footstep_surface_mix)


func _apply_surface_loop_volumes(base_gain_linear: float, gravel_mix: float) -> void:
	if _footstep_grass_player == null or _footstep_gravel_player == null:
		return
	var mix = clamp(gravel_mix, 0.0, 1.0)
	var grass_weight = cos(mix * PI * 0.5)
	var gravel_weight = sin(mix * PI * 0.5)
	_set_loop_volume_linear(_footstep_grass_player, base_gain_linear * grass_weight)
	_set_loop_volume_linear(_footstep_gravel_player, base_gain_linear * gravel_weight)


func _set_loop_volume_linear(player: AudioStreamPlayer, linear_gain: float) -> void:
	if player == null:
		return
	if linear_gain <= 0.00005:
		player.volume_db = FOOTSTEP_SILENT_DB
		return
	player.volume_db = clamp(linear_to_db(linear_gain), FOOTSTEP_SILENT_DB, 2.0)


func _force_footstep_silence(stop_playback: bool = false) -> void:
	if _footstep_grass_player != null:
		_footstep_grass_player.volume_db = FOOTSTEP_SILENT_DB
		if stop_playback and _footstep_grass_player.playing:
			_footstep_grass_player.stop()
	if _footstep_gravel_player != null:
		_footstep_gravel_player.volume_db = FOOTSTEP_SILENT_DB
		if stop_playback and _footstep_gravel_player.playing:
			_footstep_gravel_player.stop()


func _sample_gravel_surface_mix() -> float:
	if _grid_manager == null:
		return 0.0
	var gravel_samples = 0
	var sample_count = FOOTSTEP_SURFACE_SAMPLE_OFFSETS.size()
	if sample_count <= 0:
		return 0.0
	for offset in FOOTSTEP_SURFACE_SAMPLE_OFFSETS:
		var sample_pos = global_position + Vector3(offset.x, 0.0, offset.y)
		if _is_gravel_surface_at_world(sample_pos):
			gravel_samples += 1
	return float(gravel_samples) / float(sample_count)


func _is_gravel_surface_at_world(world_pos: Vector3) -> bool:
	if _grid_manager == null:
		return false
	if not _grid_manager.has_method("world_to_grid"):
		return false
	if not _grid_manager.has_method("is_in_bounds"):
		return false
	if not _grid_manager.has_method("get_tile"):
		return false

	var coord = _grid_manager.world_to_grid(world_pos)
	if not _grid_manager.is_in_bounds(coord):
		return false
	var tile = _grid_manager.get_tile(coord)
	return _tile_is_path_surface(tile)


func _tile_is_path_surface(tile) -> bool:
	if tile == null:
		return false
	if not bool(tile.occupied):
		return false
	var occupant = tile.occupant
	if occupant == null:
		return false
	if occupant is Node and (occupant as Node).is_in_group("paths"):
		return true
	if occupant is Object and occupant.has_meta("building_type"):
		return str(occupant.get_meta("building_type", "")) == "path"
	return false
