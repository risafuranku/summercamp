extends CanvasLayer

const INTERIOR_BARREL_SHADER = preload("res://materials/interior_barrel_post.gdshader")
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const CRT_UI_SCENE = preload("res://scripts/os98/os_shell.gd")
## The camp computer runs at 640x480, like it did.
const CRT_RESOLUTION := Vector2i(640, 480)

const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)
const RADIO_INTERIOR_VOLUME_DB: float = -11.0
const RADIO_OUTSIDE_NEAR_VOLUME_DB: float = -12.5
const RADIO_OUTSIDE_SILENT_DB: float = -80.0
const RADIO_OUTSIDE_NEAR_DISTANCE: float = 2.70
const RADIO_OUTSIDE_FAR_DISTANCE: float = 16.70
const RADIO_VOLUME_LERP_SPEED: float = 1.15
const RADIO_BUS_NAME := "Radio"
## Outside, the radio is a positional source in the reception: across the field it is a
## faint, muffled tune you can walk toward in the dark.
const RADIO_OUTDOOR_VOLUME_DB: float = -3.0
const RADIO_OUTDOOR_UNIT_SIZE: float = 4.0
const RADIO_OUTDOOR_MAX_DISTANCE: float = 75.0
const RADIO_OUTDOOR_HEIGHT: float = 1.4
## The station that does not exist (DESIGN §2): late at night, once at most, from day 2,
## the radio drifts onto a frequency with a music-box phrase and a row of pips. Count
## them: one for each guest in the camp, and one more.
const STATION_INTRO := "res://assets/sfx/uncanny/station_intro.wav"
const STATION_PIP := "res://assets/sfx/uncanny/station_pip.wav"
const STATION_PIP5 := "res://assets/sfx/uncanny/station_pip5.wav"
const STATION_OUTRO := "res://assets/sfx/uncanny/station_outro.wav"
const STATION_CHANCE_PER_TRACK: float = 0.14
const RADIO_EXCLUDED_FILENAME := "pinknoise.mp3"
const RADIO_NIGHT_TRACK_PREFIX := "night"
const RADIO_INFRAVRANY_FILENAME := "song_infravrany.mp3"
const RADIO_CURSED_INFRAVRANY_FILENAME := "song_cursedinfravrany.mp3"
const RADIO_CURSED_INFRAVRANY_CHANCE: float = 0.1
const RADIO_NIGHT_TRACK_WEIGHT_AT_NIGHT: int = 2
const RADIO_PITCH_BASE: float = 0.97
const RADIO_WOW_RATE_HZ: float = 0.34
const RADIO_WOW_DEPTH: float = 0.0050
const RADIO_FLUTTER_RATE_HZ: float = 6.4
const RADIO_FLUTTER_DEPTH: float = 0.0018
const RADIO_DROPOUT_INTERVAL_MIN: float = 11.0
const RADIO_DROPOUT_INTERVAL_MAX: float = 24.0
const RADIO_DROPOUT_DURATION_MIN: float = 0.06
const RADIO_DROPOUT_DURATION_MAX: float = 0.16
const RADIO_DROPOUT_ATTENUATION_DB: float = -4.5
const RADIO_NIGHT_TRACK_VOLUME_OFFSET_DB: float = -8.0
const RADIO_POWER_OFF_VOLUME_DB: float = -80.0
const RADIO_POWER_TOGGLE_FADE_SEC: float = 0.5
const RADIO_CLICK_CENTER_LOCAL := Vector3(-0.10, 0.92, -1.52)
const RADIO_CLICK_SIZE := Vector3(0.46, 0.42, 0.38)
const NOTEBOOK_CLICK_CENTER_LOCAL := Vector3(-0.94, 1.02, 0.34)
const NOTEBOOK_CLICK_SIZE := Vector3(0.70, 0.22, 0.50)
const CRT_ENTER_FOV: float = 41.0
const CRT_READY_FOV: float = 35.0
const CRT_LOOK_BACK_HOLD_SEC: float = 0.5
const CRT_LOOK_BACK_TRANSITION_SEC: float = 0.24
const CRT_LOOK_BACK_FOV: float = 36.8
const CRT_ORBIT_YAW_DEG: float = 2.6
const CRT_ORBIT_PITCH_DEG: float = 1.9
const CRT_ORBIT_ROLL_DEG: float = 0.34
const CRT_ORBIT_RESPONSE_POWER: float = 1.25
const CRT_ORBIT_LERP: float = 6.0
const CRT_GLOW_NEAR_DISTANCE: float = 0.62
const CRT_GLOW_FAR_DISTANCE: float = 2.20
const CRT_GLOW_NEAR_ENERGY_MULT: float = 0.03
const CRT_GLOW_FAR_ENERGY_MULT: float = 1.00
const CRT_GLOW_NEAR_RANGE: float = 0.42
const CRT_GLOW_FAR_RANGE: float = 3.20
const CRT_GLOW_ACTIVE_ENERGY_MULT: float = 0.44
const CRT_GLOW_ACTIVE_MAX_RANGE: float = 0.86
const CRT_GLOW_DISTANCE_CURVE_POWER: float = 1.85
const CRT_SCREEN_EMISSION_NEAR: float = 0.24
const CRT_SCREEN_EMISSION_FAR: float = 1.06
const CRT_SCREEN_EMISSION_ACTIVE_MULT: float = 0.72
## 4:3, the shape of the 640x480 picture.
const CRT_SCREEN_QUAD_SIZE := Vector2(0.50, 0.375)
const CRT_SCREEN_LOCAL_POS := Vector3(0.0, 0.02, 0.356)

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _interior_camera: Camera3D
var _room_root: Node3D
var _crt_body: StaticBody3D
var _crt_screen: MeshInstance3D
var _room_environment: Environment
var _ceiling_light: OmniLight3D
var _desk_lamp: OmniLight3D
var _window_light: OmniLight3D
var _crt_glow_light: OmniLight3D
var _office_lights_on: bool = true
var _grid_power_available: bool = true
var _office_light_tween: Tween
var _office_light_switch_body: StaticBody3D
var _office_light_switch_mesh: MeshInstance3D
var _office_switch_tex_on: Texture2D
var _office_switch_tex_off: Texture2D
var _office_wall_tex_default: Texture2D
var _office_wall_tex_dim: Texture2D
var _office_wall_tex_near: Texture2D
var _office_wall_meshes: Array[MeshInstance3D] = []
var _office_near_light_wall_meshes: Array[MeshInstance3D] = []
var _is_day_mode: bool = true
var _time_state: int = TIME_DAY
var _barrel_overlay: ColorRect
var _daylight_factor: float = 0.0
var _sunlight_color: Color = Color(1.0, 0.95, 0.84)
var _crt_glow_target_color: Color = Color(0.62, 0.78, 1.0)
var _crt_glow_target_energy: float = 0.0
var _crt_glow_sample_timer: float = 0.0

# CRT 3D State
var _crt_viewport: SubViewport
var _exit_hint: Control
var _crt_ui: Control
var _crt_active: bool = false
var _camera_tween: Tween
var _initial_cam_pos: Vector3
var _initial_cam_rot: Vector3
var _initial_cam_fov: float = 54.0
var _idle_cam_base_rot: Vector3 = Vector3.ZERO
## In the office, away from the screen: turn your head around the room, not out of it.
var _look = INTERIOR_LOOK.new(70.0, 22.0, 30.0)
var _crt_orbit_anchor_pos: Vector3 = Vector3.ZERO
var _crt_orbit_anchor_offset: Vector3 = Vector3.ZERO
var _crt_orbit_pivot: Vector3 = Vector3.ZERO
var _crt_orbit_enabled: bool = false
var _crt_look_back_cam_pos: Vector3 = Vector3(0.02, 1.36, -0.16)
var _crt_look_back_cam_rot: Vector3 = Vector3(-0.034, PI, 0.0)
var _crt_look_back_hold_time: float = 0.0
var _crt_look_back_armed: bool = false
var _crt_look_back_active: bool = false

var _crt_view_cam_pos: Vector3 = Vector3(0.24, 1.37, -0.24)
var _crt_full_cam_pos: Vector3 = Vector3(0.28, 1.35, -0.34)
var _grid_manager
var _building_manager
var _legacy_ui_adapter
var _texture_style
var _player_ref: Node3D
var _main_building_ref: Node3D
var _pending_crt_desktop_state: Dictionary = {}

# Radio
var _radio_player: AudioStreamPlayer
var _radio_tracks: Array[AudioStream] = []
var _radio_tracks_is_night: Array[bool] = []
var _radio_tracks_paths: Array[String] = []
var _radio_tracks_all: Array[AudioStream] = []
var _radio_tracks_all_is_night: Array[bool] = []
var _radio_tracks_all_paths: Array[String] = []
var _radio_index: int = 0
var _radio_load_paths: Array[String] = []
var _radio_loaded: bool = false
var _radio_power_on: bool = true
var _radio_power_transition_time_left: float = 0.0
var _radio_current_track_is_night: bool = false
var _radio_last_played_path: String = ""
var _radio_cursed_infravrany_path: String = ""
var _radio_stream_by_path: Dictionary = {}
var _radio_rng := RandomNumberGenerator.new()
var _radio_wow_phase: float = 0.0
var _radio_flutter_phase: float = 0.0
var _radio_dropout_timer: float = 0.0
var _radio_dropout_remaining: float = 0.0
var _radio_dropout_duration: float = 0.0
var _radio_power_click_body: StaticBody3D
var _radio_outdoor: AudioStreamPlayer3D
var _station_heard_day: int = -1
var _reception_notebook_click_body: StaticBody3D

# Window / outdoor scene
var _window_quad: MeshInstance3D
var _window_outdoor_sky: MeshInstance3D
var _weather_state: int = 0

# Fan pivot (for spinning blades)
var _fan_pivot: Node3D
var _fan_spin: float = 0.0


func _ready() -> void:
	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	layer = 85
	visible = false
	var root_viewport := get_viewport()
	if root_viewport != null:
		var cb := Callable(self, "_on_root_viewport_size_changed")
		if not root_viewport.size_changed.is_connected(cb):
			root_viewport.size_changed.connect(cb)
	_build_viewport()
	_sync_interior_viewport_to_window()
	_build_crt_viewport() # Build CRT internal UI
	_build_room()
	_configure_crt_ui()
	_setup_radio_character()
	_setup_radio()
	call_deferred("_collect_radio_tracks")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_on_root_viewport_size_changed()


func _on_root_viewport_size_changed() -> void:
	_sync_interior_viewport_to_window()
	_sync_crt_viewport_to_window()

func setup(grid_mgr, building_mgr, ui_adapter = null, player_ref: Node3D = null) -> void:
	_grid_manager = grid_mgr
	_building_manager = building_mgr
	_legacy_ui_adapter = ui_adapter
	_player_ref = player_ref
	_main_building_ref = null
	_configure_crt_ui()


func export_crt_desktop_state() -> Dictionary:
	if _crt_ui == null or not is_instance_valid(_crt_ui):
		return _pending_crt_desktop_state.duplicate(true)
	if not _crt_ui.has_method("export_persistent_state"):
		return _pending_crt_desktop_state.duplicate(true)
	var state_any = _crt_ui.call("export_persistent_state")
	if state_any is Dictionary:
		return (state_any as Dictionary).duplicate(true)
	return _pending_crt_desktop_state.duplicate(true)


func import_crt_desktop_state(state: Dictionary) -> void:
	_pending_crt_desktop_state = state.duplicate(true)
	_apply_pending_crt_desktop_state()


func _apply_pending_crt_desktop_state() -> void:
	if _crt_ui == null or not is_instance_valid(_crt_ui):
		return
	if not _crt_ui.has_method("import_persistent_state"):
		_pending_crt_desktop_state.clear()
		return
	_crt_ui.call("import_persistent_state", _pending_crt_desktop_state.duplicate(true))
	_pending_crt_desktop_state.clear()


func is_open() -> bool:
	return visible


func is_crt_view_active() -> bool:
	return visible and _crt_active


func set_is_day(is_day: bool) -> void:
	_time_state = TIME_DAY if is_day else TIME_NIGHT
	_is_day_mode = is_day
	_apply_room_time_profile()
	_rebuild_radio_tracks_for_time(false)
	if _crt_ui != null and _crt_ui.has_method("set_is_day"):
		_crt_ui.set_is_day(is_day)


func set_time_state(new_state: int) -> void:
	_time_state = int(clamp(new_state, TIME_DAY, TIME_NIGHT))
	_is_day_mode = (_time_state != TIME_NIGHT)
	_apply_room_time_profile()
	_rebuild_radio_tracks_for_time(false)
	if _crt_ui != null and _crt_ui.has_method("set_is_day"):
		_crt_ui.set_is_day(_time_state != TIME_NIGHT)


func set_daylight_profile(daylight_factor: float, sun_color: Color, _ambient_color: Color, _ambient_energy: float) -> void:
	_daylight_factor = clampf(daylight_factor, 0.0, 1.0)
	_sunlight_color = sun_color
	_apply_room_time_profile()


func set_grid_power_available(power_available: bool) -> void:
	_grid_power_available = power_available
	_apply_room_time_profile(true)


func open_interior() -> void:
	if _interior_camera == null:
		return
	_crt_active = false
	_crt_orbit_enabled = false
	_reset_crt_look_back_state()
	if _camera_tween != null:
		_camera_tween.kill()

	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_set_window_view_live(true)
	_update_window_texture()
	visible = true
	_sync_interior_viewport_to_window()
	_sync_crt_viewport_to_window()
	_set_crt_viewport_live(true)
	_interior_camera.rotation = Vector3(deg_to_rad(-9.0), 0.0, 0.0)
	_interior_camera.position = Vector3(0.0, 1.4, 1.6) # Reset pos
	_interior_camera.current = true

	_initial_cam_pos = _interior_camera.position
	_initial_cam_rot = _interior_camera.rotation
	_initial_cam_fov = _interior_camera.fov
	_idle_cam_base_rot = _initial_cam_rot
	_look.reset()
	_capture_crt_orbit_anchor()
	_apply_room_time_profile()
	_collect_radio_tracks()
	_rebuild_radio_tracks_for_time(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_interior() -> void:
	if _camera_tween != null:
		_camera_tween.kill()
	_crt_active = false
	_crt_orbit_enabled = false
	_reset_crt_look_back_state()
	_set_crt_viewport_live(false)
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_set_window_view_live(false)
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	_update_radio_mix(delta)
	if not visible:
		return
	_update_crt_monitor_light(delta)
	# Spin fan blades
	if _fan_pivot != null:
		_fan_spin += delta * 380.0
		_fan_pivot.rotation_degrees.z = _fan_spin
	if _interior_camera == null:
		return
	if _crt_active:
		_update_crt_look_back_hold(delta)
		if _is_camera_tween_running():
			return
		if _crt_look_back_active:
			return
		_apply_crt_mouse_orbit(delta)
		return
	if _is_camera_tween_running():
		return
	_apply_idle_mouse_look(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta, not _crt_active)


func _is_camera_tween_running() -> bool:
	return _camera_tween != null and is_instance_valid(_camera_tween) and _camera_tween.is_running()


func _reset_crt_look_back_state() -> void:
	_crt_look_back_hold_time = 0.0
	_crt_look_back_armed = false
	_crt_look_back_active = false


func _is_crt_text_input_focused() -> bool:
	if _crt_viewport == null:
		return false
	var focused: Control = _crt_viewport.gui_get_focus_owner()
	if focused == null:
		return false
	return focused is LineEdit or focused is TextEdit or focused is CodeEdit


func _update_crt_look_back_hold(delta: float) -> void:
	if not _crt_active:
		_reset_crt_look_back_state()
		return
	var look_back_pressed := false
	if not look_back_pressed:
		_crt_look_back_armed = false
		_crt_look_back_hold_time = 0.0
		if _crt_look_back_active:
			_exit_crt_look_back()
		return
	if _crt_look_back_active:
		return
	if not _crt_look_back_armed:
		_crt_look_back_armed = true
		_crt_look_back_hold_time = 0.0
	if _is_camera_tween_running():
		return
	_crt_look_back_hold_time += delta
	if _crt_look_back_hold_time < CRT_LOOK_BACK_HOLD_SEC:
		return
	_crt_look_back_armed = false
	_crt_look_back_hold_time = 0.0
	_enter_crt_look_back()


func _handle_crt_look_back_key(_event: InputEventKey) -> bool:
	# Turning round at the PC by holding S is gone (playtest): S is just a letter there.
	return false


func _is_crt_look_back_pressed_now() -> bool:
	if Input.is_physical_key_pressed(KEY_S):
		return true
	if Input.is_key_pressed(KEY_S):
		return true
	return Input.is_action_pressed("move_backward")


func _is_crt_look_back_key_event(event: InputEventKey) -> bool:
	if event == null:
		return false
	if event.physical_keycode == KEY_S:
		return true
	if event.keycode == KEY_S:
		return true
	if event.key_label == KEY_S:
		return true
	if event.unicode != 0:
		var as_text := char(event.unicode).to_lower()
		if as_text == "s":
			return true
	return false


func _enter_crt_look_back() -> void:
	if not _crt_active or _interior_camera == null or _crt_look_back_active:
		return
	_crt_look_back_active = true
	_crt_orbit_enabled = false
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_property(_interior_camera, "position", _crt_look_back_cam_pos, CRT_LOOK_BACK_TRANSITION_SEC)
	_camera_tween.tween_property(_interior_camera, "rotation", _crt_look_back_cam_rot, CRT_LOOK_BACK_TRANSITION_SEC)
	_camera_tween.tween_property(_interior_camera, "fov", CRT_LOOK_BACK_FOV, CRT_LOOK_BACK_TRANSITION_SEC)


func _exit_crt_look_back() -> void:
	if _interior_camera == null:
		_reset_crt_look_back_state()
		return
	_crt_look_back_active = false
	_crt_orbit_enabled = false
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_property(_interior_camera, "position", _crt_full_cam_pos, CRT_LOOK_BACK_TRANSITION_SEC)
	_camera_tween.tween_property(_interior_camera, "rotation", Vector3.ZERO, CRT_LOOK_BACK_TRANSITION_SEC)
	_camera_tween.tween_property(_interior_camera, "fov", CRT_READY_FOV, CRT_LOOK_BACK_TRANSITION_SEC)
	_camera_tween.finished.connect(func():
		if not _crt_active:
			return
		_capture_crt_orbit_anchor()
		if not _crt_look_back_active:
			_crt_orbit_enabled = true
	)


func _apply_idle_mouse_look(delta: float) -> void:
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.key_axis())
	_interior_camera.rotation = _interior_camera.rotation.lerp(_idle_cam_base_rot + offset, clampf(delta * 12.0, 0.0, 1.0))


func _apply_crt_mouse_orbit(delta: float) -> void:
	if not _crt_orbit_enabled or _interior_camera == null:
		return
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var raw_nx = clampf(((mouse_pos.x / screen_size.x) - 0.5) * 2.0, -1.0, 1.0)
	var raw_ny = clampf(((mouse_pos.y / screen_size.y) - 0.5) * 2.0, -1.0, 1.0)
	var nx = sign(raw_nx) * pow(absf(raw_nx), CRT_ORBIT_RESPONSE_POWER)
	var ny = sign(raw_ny) * pow(absf(raw_ny), CRT_ORBIT_RESPONSE_POWER)

	var yaw = deg_to_rad(-nx * CRT_ORBIT_YAW_DEG)
	var pitch = deg_to_rad(-ny * CRT_ORBIT_PITCH_DEG)
	var orbit_basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var target_pos = _crt_orbit_pivot + (orbit_basis * _crt_orbit_anchor_offset)

	var look_transform = Transform3D(Basis.IDENTITY, target_pos).looking_at(_crt_orbit_pivot, Vector3.UP)
	var target_rot = look_transform.basis.get_euler()
	target_rot.z += deg_to_rad(nx * CRT_ORBIT_ROLL_DEG)
	var blend = clampf(delta * CRT_ORBIT_LERP, 0.0, 1.0)
	_interior_camera.position = _interior_camera.position.lerp(target_pos, blend)
	_interior_camera.rotation = _interior_camera.rotation.lerp(target_rot, blend)


func _capture_crt_orbit_anchor() -> void:
	if _interior_camera == null:
		return
	_crt_orbit_anchor_pos = _interior_camera.position
	_crt_orbit_pivot = _get_crt_orbit_pivot()
	_crt_orbit_anchor_offset = _crt_orbit_anchor_pos - _crt_orbit_pivot
	if _crt_orbit_anchor_offset.length() < 0.001:
		_crt_orbit_anchor_offset = Vector3(0.0, 0.0, 0.4)


func _get_crt_orbit_pivot() -> Vector3:
	if _crt_screen != null and is_instance_valid(_crt_screen):
		return _crt_screen.global_transform.origin
	if _crt_body != null and is_instance_valid(_crt_body):
		return _crt_body.global_transform.origin
	return _crt_orbit_anchor_pos + Vector3(0.0, 0.0, -0.4)





func _try_click_crt(event: InputEventMouseButton) -> void:
	if _interior_camera == null or _crt_screen == null or _crt_viewport == null:
		return
	# Strict hit test: only the real CRT screen quad is clickable.
	var vp_pos = _map_mouse_to_crt(event.position, false)
	if vp_pos != Vector2.INF:
		enter_crt_view()


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "InteriorViewportContainer"
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP

	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "InteriorViewport"
	_viewport.own_world_3d = true
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.handle_input_locally = false
	_viewport.physics_object_picking = true
	_viewport.transparent_bg = false
	_viewport_container.add_child(_viewport)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.66, 0.70, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.80)
	env.ambient_light_energy = 1.06
	env.fog_enabled = false
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.78, 0.82, 0.84)
	env.fog_density = 0.004
	_room_environment = env

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	# Interior-only barrel/fisheye post effect.
	_barrel_overlay = ColorRect.new()
	_barrel_overlay.name = "InteriorBarrelOverlay"
	_barrel_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barrel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barrel_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	var barrel_mat = ShaderMaterial.new()
	barrel_mat.shader = INTERIOR_BARREL_SHADER
	barrel_mat.set_shader_parameter("barrel_strength", 0.0)
	barrel_mat.set_shader_parameter("vignette_strength", 0.0)
	barrel_mat.set_shader_parameter("chroma_shift", 0.0)
	_barrel_overlay.material = barrel_mat
	_barrel_overlay.visible = false
	add_child(_barrel_overlay)


func _build_room() -> void:
	_room_root = Node3D.new()
	_room_root.name = "Room"
	_viewport.add_child(_room_root)
	_office_wall_meshes.clear()
	_office_near_light_wall_meshes.clear()
	_office_light_switch_body = null
	_office_light_switch_mesh = null
	_office_lights_on = true
	_fan_pivot = null
	_window_quad = null
	_window_outdoor_sky = null
	_radio_power_click_body = null
	_reception_notebook_click_body = null

	# ── CAMERA ────────────────────────────────────────────────────────────────
	_interior_camera = Camera3D.new()
	_interior_camera.name = "InteriorCamera"
	_interior_camera.position = Vector3(0.0, 1.4, 1.6)
	_interior_camera.fov = 58.0
	_interior_camera.near = 0.05
	_interior_camera.far = 22.0
	_interior_camera.current = true
	_room_root.add_child(_interior_camera)

	_build_crt_viewport()

	# ── LIGHTS ────────────────────────────────────────────────────────────────
	_ceiling_light = OmniLight3D.new()
	_ceiling_light.name = "CeilingLight"
	_ceiling_light.position = Vector3(0.0, 2.50, 0.2)
	_ceiling_light.light_color = Color(0.98, 0.94, 0.84)
	_ceiling_light.light_energy = 1.88
	_ceiling_light.omni_range = 6.5
	_ceiling_light.omni_attenuation = 1.4
	_ceiling_light.shadow_enabled = true
	_room_root.add_child(_ceiling_light)

	_desk_lamp = OmniLight3D.new()
	_desk_lamp.name = "DeskLamp"
	_desk_lamp.position = Vector3(0.5, 1.26, -1.20)
	_desk_lamp.light_color = Color(0.90, 0.94, 0.76)
	_desk_lamp.light_energy = 0.44
	_desk_lamp.omni_range = 2.4
	_desk_lamp.omni_attenuation = 1.8
	_desk_lamp.shadow_enabled = false
	_room_root.add_child(_desk_lamp)

	_window_light = OmniLight3D.new()
	_window_light.name = "WindowLight"
	_window_light.position = Vector3(-0.4, 1.90, -2.00)
	_window_light.light_color = Color(0.94, 0.95, 0.88)
	_window_light.light_energy = 0.56
	_window_light.omni_range = 4.2
	_window_light.omni_attenuation = 1.4
	_window_light.shadow_enabled = false
	_room_root.add_child(_window_light)

	# ── FLOOR ─────────────────────────────────────────────────────────────────
	_add_box(_room_root, "Floor", Vector3(0.0, 0.0, 0.0), Vector3(5.0, 0.1, 5.0), Color(0.44, 0.32, 0.22))
	for xi in range(-2, 3):
		_add_box(_room_root, "FloorTileX%d" % xi, Vector3(float(xi), 0.056, 0.0), Vector3(0.02, 0.008, 5.0), Color(0.16, 0.14, 0.12))
	for zi in range(-2, 3):
		_add_box(_room_root, "FloorTileZ%d" % zi, Vector3(0.0, 0.056, float(zi)), Vector3(5.0, 0.008, 0.02), Color(0.16, 0.14, 0.12))
	_add_box(_room_root, "FloorScatter26_A", Vector3(-1.40, 0.062, 0.40), Vector3(0.24, 0.004, 0.14), Color(0.70, 0.68, 0.62))
	_add_box(_room_root, "FloorScatter27_A", Vector3(1.20, 0.062, -0.60), Vector3(0.18, 0.004, 0.12), Color(0.68, 0.66, 0.60))
	_add_box(_room_root, "FloorScatter26_B", Vector3(0.50, 0.062, 0.90), Vector3(0.16, 0.004, 0.10), Color(0.72, 0.70, 0.64))
	_add_box(_room_root, "FloorScatter27_B", Vector3(-0.80, 0.062, -0.30), Vector3(0.20, 0.004, 0.08), Color(0.66, 0.64, 0.58))

	# ── CEILING ────────────────────────────────────────────────────────────────
	_add_box(_room_root, "Ceiling", Vector3(0.0, 2.8, 0.0), Vector3(5.0, 0.1, 5.0), Color(0.60, 0.54, 0.46))
	_add_box(_room_root, "CeilingTrim", Vector3(0.0, 2.70, 0.0), Vector3(5.2, 0.06, 5.2), Color(0.52, 0.44, 0.38))
	_add_box(_room_root, "CeilingFixture", Vector3(0.0, 2.72, 0.2), Vector3(0.40, 0.04, 0.40), Color(0.86, 0.84, 0.76))
	_add_box(_room_root, "CeilingFixtureGlass", Vector3(0.0, 2.68, 0.2), Vector3(0.32, 0.02, 0.32), Color(0.94, 0.94, 0.88))

	# ── SOLID WALLS ────────────────────────────────────────────────────────────
	_add_box(_room_root, "WallBack", Vector3(0.0, 1.4, 2.55), Vector3(5.0, 2.8, 0.1), Color(0.62, 0.48, 0.34))
	_add_box(_room_root, "WallLeft", Vector3(-2.55, 1.4, 0.0), Vector3(0.1, 2.8, 5.0), Color(0.64, 0.48, 0.34))
	_add_box(_room_root, "WallRight", Vector3(2.55, 1.4, 0.0), Vector3(0.1, 2.8, 5.0), Color(0.64, 0.48, 0.34))

	# ── FRONT WALL — broken around window opening (x: -1.4..0.6, y: 0.95..2.40) ──
	_add_box(_room_root, "WallFrontLeft",   Vector3(-1.95, 1.4, -2.55), Vector3(1.10, 2.8, 0.1), Color(0.66, 0.50, 0.36))
	_add_box(_room_root, "WallFrontRight",  Vector3( 1.55, 1.4, -2.55), Vector3(1.90, 2.8, 0.1), Color(0.66, 0.50, 0.36))
	_add_box(_room_root, "WallFrontBottom", Vector3(-0.4, 0.475, -2.55), Vector3(2.00, 0.95, 0.1), Color(0.66, 0.50, 0.36))
	_add_box(_room_root, "WallFrontTop",    Vector3(-0.4, 2.575, -2.55), Vector3(2.00, 0.45, 0.1), Color(0.66, 0.50, 0.36))

	# ── WINDOW FRAME (front wall, shifted left, center x=-0.4) ─────────────────
	_add_box(_room_root, "WindowFrameTop",    Vector3(-0.4,  2.40, -2.50), Vector3(2.20, 0.08, 0.12), Color(0.78, 0.78, 0.74))
	_add_box(_room_root, "WindowFrameBottom", Vector3(-0.4,  0.95, -2.50), Vector3(2.20, 0.08, 0.12), Color(0.78, 0.78, 0.74))
	_add_box(_room_root, "WindowFrameLeft",   Vector3(-1.40, 1.68, -2.50), Vector3(0.08, 1.40, 0.12), Color(0.78, 0.78, 0.74))
	_add_box(_room_root, "WindowFrameRight",  Vector3( 0.60, 1.68, -2.50), Vector3(0.08, 1.40, 0.12), Color(0.78, 0.78, 0.74))
	_add_box(_room_root, "WindowSill",        Vector3(-0.4,  0.96, -2.42), Vector3(2.08, 0.06, 0.20), Color(0.84, 0.84, 0.80))
	# Mullion cross
	_add_box(_room_root, "WindowMullionV", Vector3(-0.4, 1.68, -2.50), Vector3(0.06, 1.30, 0.08), Color(0.66, 0.66, 0.62))
	_add_box(_room_root, "WindowMullionH", Vector3(-0.4, 1.68, -2.50), Vector3(2.00, 0.06, 0.08), Color(0.66, 0.66, 0.62))
	# Window glass quad — sky view (QuadMesh default normal is +Z, faces camera)
	_window_quad = MeshInstance3D.new()
	_window_quad.name = "WindowView"
	var wq = QuadMesh.new()
	wq.size = Vector2(1.86, 1.38)
	_window_quad.mesh = wq
	_window_quad.position = Vector3(-0.4, 1.68, -2.51)
	_room_root.add_child(_window_quad)
	_setup_window_view()
	_update_window_texture()

	# ── FAKE OUTDOOR SCENE (past the front wall, aligned to shifted window) ───
	_add_box(_room_root, "OutdoorGround",  Vector3(-0.4,  -0.04, -4.2), Vector3(2.10, 0.08, 4.0), Color(0.44, 0.42, 0.38))
	_add_box(_room_root, "OutdoorCeiling", Vector3(-0.4,   2.44, -4.2), Vector3(2.10, 0.08, 4.0), Color(0.54, 0.44, 0.34))
	_add_box(_room_root, "OutdoorWallL",   Vector3(-1.44,  1.20, -4.2), Vector3(0.08, 2.50, 4.0), Color(0.56, 0.44, 0.34))
	_add_box(_room_root, "OutdoorWallR",   Vector3( 0.64,  1.20, -4.2), Vector3(0.08, 2.50, 4.0), Color(0.56, 0.44, 0.34))
	# Gravel/pavement detail strips
	for si in range(3):
		_add_box(_room_root, "OutdoorGravelStrip%d" % si, Vector3(float(si) * 0.40 - 0.80, 0.05, -4.2), Vector3(0.34, 0.008, 4.0), Color(0.50, 0.48, 0.44))
	# Distant shrubs / dead vegetation
	_add_box(_room_root, "OutdoorBushL",  Vector3(-1.00, 0.24, -5.2), Vector3(0.56, 0.48, 0.56), Color(0.30, 0.32, 0.22))
	_add_box(_room_root, "OutdoorBushR",  Vector3( 0.18, 0.20, -4.8), Vector3(0.42, 0.40, 0.42), Color(0.28, 0.30, 0.20))
	_add_box(_room_root, "OutdoorBushR2", Vector3( 0.22, 0.12, -5.6), Vector3(0.30, 0.24, 0.30), Color(0.26, 0.28, 0.18))
	# Far background (sky/fog quad)
	_window_outdoor_sky = MeshInstance3D.new()
	_window_outdoor_sky.name = "OutdoorSkyBg"
	var sky_quad_mesh = QuadMesh.new()
	sky_quad_mesh.size = Vector2(2.20, 2.60)
	_window_outdoor_sky.mesh = sky_quad_mesh
	_window_outdoor_sky.position = Vector3(-0.4, 1.26, -6.2)
	var sky_bg_mat = StandardMaterial3D.new()
	sky_bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_bg_mat.albedo_color = Color(0.68, 0.72, 0.64)
	sky_bg_mat.emission_enabled = true
	sky_bg_mat.emission = Color(0.68, 0.72, 0.64)
	sky_bg_mat.emission_energy_multiplier = 0.55
	sky_bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_window_outdoor_sky.material_override = sky_bg_mat
	_room_root.add_child(_window_outdoor_sky)

	# ── CRT WORKDESK (shifted right, x+0.5) ───────────────────────────────────
	_add_box(_room_root, "Desk",    Vector3(0.5, 0.38, -1.36), Vector3(1.80, 0.76, 0.74), Color(0.38, 0.26, 0.16))
	_add_box(_room_root, "DeskTop", Vector3(0.5, 0.79, -1.36), Vector3(1.92, 0.06, 0.84), Color(0.56, 0.42, 0.28), true)
	_add_box(_room_root, "DeskDrawerA", Vector3(0.04, 0.52, -0.96), Vector3(0.52, 0.18, 0.04), Color(0.34, 0.24, 0.16))
	_add_box(_room_root, "DeskDrawerB", Vector3(0.82, 0.52, -0.96), Vector3(0.52, 0.18, 0.04), Color(0.34, 0.24, 0.16))
	_add_box(_room_root, "DrawerHandleA", Vector3(0.04, 0.52, -0.93), Vector3(0.10, 0.04, 0.03), Color(0.64, 0.56, 0.42))
	_add_box(_room_root, "DrawerHandleB", Vector3(0.82, 0.52, -0.93), Vector3(0.10, 0.04, 0.03), Color(0.64, 0.56, 0.42))
	# Cup / ashtray on desk
	_add_box(_room_root, "DeskCup", Vector3(1.20, 0.90, -0.98), Vector3(0.08, 0.14, 0.08), Color(0.50, 0.26, 0.18))

	# ── RETRO COMPUTER SETUP (monitor + tower + keyboard + mouse) ─────────────
	var pc_shell_col := Color(0.80, 0.75, 0.63)
	var pc_shell_dark_col := Color(0.66, 0.62, 0.52)
	var pc_panel_col := Color(0.88, 0.84, 0.72)
	var pc_charcoal_col := Color(0.14, 0.14, 0.14)

	_crt_body = StaticBody3D.new()
	_crt_body.name = "CRTMonitor"
	_crt_body.position = Vector3(0.24, 1.35, -1.53)
	_room_root.add_child(_crt_body)

	var crt_case = MeshInstance3D.new()
	crt_case.name = "CRTCase"
	var crt_case_box = BoxMesh.new()
	crt_case_box.size = Vector3(0.82, 0.60, 0.62)
	crt_case.mesh = crt_case_box
	crt_case.material_override = _make_psx_material(pc_shell_col, 26.0, 5.0, 0.01, "plastic")
	_crt_body.add_child(crt_case)

	var crt_top_cap = MeshInstance3D.new()
	crt_top_cap.name = "CRTTopCap"
	var crt_top_mesh = BoxMesh.new()
	crt_top_mesh.size = Vector3(0.80, 0.05, 0.56)
	crt_top_cap.mesh = crt_top_mesh
	crt_top_cap.position = Vector3(0.0, 0.28, -0.02)
	crt_top_cap.material_override = _make_psx_material(pc_shell_dark_col, 24.0, 4.0, 0.0, "plastic")
	_crt_body.add_child(crt_top_cap)

	var crt_front = MeshInstance3D.new()
	crt_front.name = "CRTFrontFrame"
	var crt_front_mesh = BoxMesh.new()
	crt_front_mesh.size = Vector3(0.72, 0.53, 0.11)
	crt_front.mesh = crt_front_mesh
	crt_front.position = Vector3(0.0, 0.02, 0.258)
	crt_front.material_override = _make_psx_material(pc_shell_col.lightened(0.08), 26.0, 5.0, 0.0, "plastic")
	_crt_body.add_child(crt_front)

	var crt_inner = MeshInstance3D.new()
	crt_inner.name = "CRTInnerFrame"
	var crt_inner_mesh = BoxMesh.new()
	crt_inner_mesh.size = Vector3(0.61, 0.46, 0.07)
	crt_inner.mesh = crt_inner_mesh
	crt_inner.position = Vector3(0.0, 0.02, 0.292)
	crt_inner.material_override = _make_psx_material(pc_panel_col, 22.0, 4.0, 0.0, "plastic")
	_crt_body.add_child(crt_inner)

	var crt_bezel_dark = MeshInstance3D.new()
	crt_bezel_dark.name = "CRTBezelDark"
	var crt_bezel_mesh = BoxMesh.new()
	crt_bezel_mesh.size = Vector3(0.54, 0.41, 0.03)
	crt_bezel_dark.mesh = crt_bezel_mesh
	crt_bezel_dark.position = Vector3(0.0, 0.02, 0.336)
	crt_bezel_dark.material_override = _make_psx_material(pc_charcoal_col, 16.0, 3.0, 0.0, "plastic")
	_crt_body.add_child(crt_bezel_dark)

	var crt_col = CollisionShape3D.new()
	var crt_shape = BoxShape3D.new()
	crt_shape.size = Vector3(0.86, 0.64, 0.66)
	crt_col.shape = crt_shape
	_crt_body.add_child(crt_col)

	_crt_screen = MeshInstance3D.new()
	_crt_screen.name = "CRTScreen"
	var scr_mesh = QuadMesh.new()
	scr_mesh.size = CRT_SCREEN_QUAD_SIZE
	_crt_screen.mesh = scr_mesh
	_crt_screen.position = CRT_SCREEN_LOCAL_POS
	var scr_mat = StandardMaterial3D.new()
	if _crt_viewport:
		var tex = _crt_viewport.get_texture()
		# Unshaded: the picture is what the computer draws, not lit (and burnt white)
		# by the room. Readable mail beats a glowing screen.
		scr_mat.albedo_texture = tex
		scr_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		scr_mat.albedo_color = Color(0.94, 0.94, 0.92)
	else:
		scr_mat.albedo_color = Color(0.08, 0.10, 0.13)
		scr_mat.emission_enabled = true
		scr_mat.emission = Color(0.08, 0.14, 0.28)
		scr_mat.emission_energy_multiplier = 1.08
	scr_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crt_screen.material_override = scr_mat
	_crt_body.add_child(_crt_screen)

	_crt_glow_light = OmniLight3D.new()
	_crt_glow_light.name = "CRTGlowLight"
	_crt_glow_light.position = Vector3(0.0, 0.02, 0.46)
	_crt_glow_light.light_color = _crt_glow_target_color
	_crt_glow_light.light_energy = 0.0
	_crt_glow_light.omni_range = 3.0
	_crt_glow_light.omni_attenuation = 2.0
	_crt_glow_light.shadow_enabled = false
	_crt_body.add_child(_crt_glow_light)

	var crt_power_led = MeshInstance3D.new()
	crt_power_led.name = "CRTPowerLed"
	var crt_led_mesh = BoxMesh.new()
	crt_led_mesh.size = Vector3(0.014, 0.014, 0.010)
	crt_power_led.mesh = crt_led_mesh
	crt_power_led.position = Vector3(0.32, -0.18, 0.336)
	crt_power_led.material_override = _make_psx_material(Color(0.36, 0.74, 0.36), 0.0, 0.0, 0.0, "plastic")
	_crt_body.add_child(crt_power_led)

	for bi in range(3):
		var crt_button = MeshInstance3D.new()
		crt_button.name = "CRTButton%d" % bi
		var crt_btn_mesh = BoxMesh.new()
		crt_btn_mesh.size = Vector3(0.028, 0.010, 0.016)
		crt_button.mesh = crt_btn_mesh
		crt_button.position = Vector3(0.26 - float(bi) * 0.038, -0.18, 0.336)
		crt_button.material_override = _make_psx_material(pc_shell_dark_col.darkened(0.10), 0.0, 0.0, 0.0, "plastic")
		_crt_body.add_child(crt_button)

	var crt_stand_neck = MeshInstance3D.new()
	crt_stand_neck.name = "CRTStandNeck"
	var stand_neck_mesh = BoxMesh.new()
	stand_neck_mesh.size = Vector3(0.18, 0.11, 0.22)
	crt_stand_neck.mesh = stand_neck_mesh
	crt_stand_neck.position = Vector3(0.0, -0.33, -0.01)
	crt_stand_neck.material_override = _make_psx_material(pc_shell_dark_col, 24.0, 4.0, 0.0, "plastic")
	_crt_body.add_child(crt_stand_neck)

	var crt_stand_foot = MeshInstance3D.new()
	crt_stand_foot.name = "CRTStandFoot"
	var stand_foot_mesh = BoxMesh.new()
	stand_foot_mesh.size = Vector3(0.40, 0.05, 0.30)
	crt_stand_foot.mesh = stand_foot_mesh
	crt_stand_foot.position = Vector3(0.0, -0.40, -0.01)
	crt_stand_foot.material_override = _make_psx_material(pc_shell_dark_col.lightened(0.06), 24.0, 4.0, 0.0, "plastic")
	_crt_body.add_child(crt_stand_foot)

	for vi in range(5):
		var vent = MeshInstance3D.new()
		vent.name = "CRTVent%d" % vi
		var vb = BoxMesh.new()
		vb.size = Vector3(0.60, 0.012, 0.18)
		vent.mesh = vb
		vent.position = Vector3(0.0, 0.20 + float(vi) * 0.028, -0.10)
		vent.material_override = _make_psx_material(Color(0.22, 0.22, 0.20), 0.0, 0.0, 0.0, "")
		_crt_body.add_child(vent)

	# Desktop tower (to the right of monitor)
	_add_box(_room_root, "PCTowerCase", Vector3(0.90, 1.20, -1.45), Vector3(0.36, 0.86, 0.56), pc_shell_col)
	_add_box(_room_root, "PCTowerFrontPanel", Vector3(0.90, 1.20, -1.16), Vector3(0.32, 0.80, 0.05), pc_panel_col)
	_add_box(_room_root, "PCTowerTopLip", Vector3(0.90, 1.62, -1.44), Vector3(0.34, 0.04, 0.52), pc_shell_dark_col)
	_add_box(_room_root, "PCTowerDriveTop", Vector3(0.90, 1.45, -1.13), Vector3(0.24, 0.08, 0.02), Color(0.28, 0.28, 0.28))
	_add_box(_room_root, "PCTowerDriveMid", Vector3(0.90, 1.33, -1.13), Vector3(0.24, 0.10, 0.02), Color(0.24, 0.24, 0.24))
	_add_box(_room_root, "PCTowerBay", Vector3(0.90, 1.20, -1.13), Vector3(0.24, 0.11, 0.02), Color(0.20, 0.20, 0.20))
	_add_box(_room_root, "PCTowerBadge", Vector3(0.90, 0.97, -1.12), Vector3(0.11, 0.04, 0.01), Color(0.58, 0.60, 0.66))
	_add_box(_room_root, "PCTowerPowerBtn", Vector3(0.90, 0.88, -1.12), Vector3(0.05, 0.03, 0.01), Color(0.16, 0.16, 0.16))

	# Keyboard (full-size with numpad)
	_add_box(_room_root, "KeyboardBase", Vector3(0.26, 0.862, -1.00), Vector3(0.70, 0.024, 0.23), Color(0.82, 0.80, 0.70))
	_add_box(_room_root, "KeyboardTopSlope", Vector3(0.26, 0.876, -1.08), Vector3(0.70, 0.010, 0.05), Color(0.76, 0.74, 0.66))
	_add_box(_room_root, "KeyboardKeyRow1", Vector3(0.15, 0.877, -0.93), Vector3(0.42, 0.010, 0.024), Color(0.20, 0.20, 0.20))
	_add_box(_room_root, "KeyboardKeyRow2", Vector3(0.15, 0.877, -0.98), Vector3(0.40, 0.010, 0.024), Color(0.20, 0.20, 0.20))
	_add_box(_room_root, "KeyboardKeyRow3", Vector3(0.15, 0.877, -1.03), Vector3(0.38, 0.010, 0.024), Color(0.20, 0.20, 0.20))
	_add_box(_room_root, "KeyboardNumpad", Vector3(0.50, 0.877, -0.99), Vector3(0.16, 0.010, 0.15), Color(0.20, 0.20, 0.20))
	_add_box(_room_root, "KeyboardSpacebar", Vector3(0.13, 0.878, -1.08), Vector3(0.24, 0.010, 0.024), Color(0.16, 0.16, 0.16))

	# Mouse
	_add_box(_room_root, "MouseBody", Vector3(0.70, 0.867, -1.00), Vector3(0.11, 0.022, 0.15), Color(0.84, 0.82, 0.74))
	_add_box(_room_root, "MouseButtons", Vector3(0.70, 0.878, -0.96), Vector3(0.08, 0.008, 0.05), Color(0.72, 0.70, 0.63))
	_add_box(_room_root, "MouseWheel", Vector3(0.70, 0.879, -1.00), Vector3(0.014, 0.010, 0.018), Color(0.16, 0.16, 0.16))

	# Cables
	_add_cable_polyline(
		_room_root,
		"PCCableMonitorToTower",
		PackedVector3Array([
			Vector3(0.24, 1.18, -1.84),
			Vector3(0.54, 1.02, -1.88),
			Vector3(0.90, 0.99, -1.72)
		]),
		0.010,
		Color(0.66, 0.68, 0.70)
	)
	_add_cable_polyline(
		_room_root,
		"PCCableKeyboardToTower",
		PackedVector3Array([
			Vector3(0.48, 0.87, -1.10),
			Vector3(0.62, 0.89, -1.18),
			Vector3(0.88, 0.96, -1.22)
		]),
		0.008,
		Color(0.70, 0.70, 0.72)
	)
	_add_cable_polyline(
		_room_root,
		"PCCableMouse",
		PackedVector3Array([
			Vector3(0.70, 0.87, -1.08),
			Vector3(0.76, 0.89, -1.18),
			Vector3(0.86, 0.95, -1.24)
		]),
		0.007,
		Color(0.74, 0.74, 0.76)
	)

	# ── DESK FAN (shifted right +0.5) ─────────────────────────────────────────
	_add_box(_room_root, "FanBase", Vector3(1.12, 0.86, -1.54), Vector3(0.14, 0.04, 0.14), Color(0.62, 0.60, 0.52))
	_add_box(_room_root, "FanStem", Vector3(1.12, 0.94, -1.54), Vector3(0.04, 0.14, 0.04), Color(0.56, 0.54, 0.48))
	_add_box(_room_root, "FanCage", Vector3(1.12, 1.06, -1.54), Vector3(0.22, 0.22, 0.10), Color(0.54, 0.52, 0.44))
	# Spinning blade pivot
	_fan_pivot = Node3D.new()
	_fan_pivot.name = "FanBladePivot"
	_fan_pivot.position = Vector3(1.12, 1.06, -1.52)
	_room_root.add_child(_fan_pivot)
	var blade_a = MeshInstance3D.new()
	blade_a.name = "BladeA"
	var ba = BoxMesh.new(); ba.size = Vector3(0.17, 0.028, 0.038)
	blade_a.mesh = ba
	blade_a.material_override = _make_psx_material(Color(0.46, 0.46, 0.40), 0.0, 0.0, 0.0, "")
	_fan_pivot.add_child(blade_a)
	var blade_b = MeshInstance3D.new()
	blade_b.name = "BladeB"
	var bb = BoxMesh.new(); bb.size = Vector3(0.028, 0.17, 0.038)
	blade_b.mesh = bb
	blade_b.material_override = _make_psx_material(Color(0.46, 0.46, 0.40), 0.0, 0.0, 0.0, "")
	_fan_pivot.add_child(blade_b)

	# ── RADIO (shifted right +0.5) ────────────────────────────────────────────
	_add_box(_room_root, "RadioBody",    Vector3(-0.10, 0.88, -1.54), Vector3(0.26, 0.14, 0.12), Color(0.58, 0.54, 0.46))
	_add_box(_room_root, "RadioSpeaker", Vector3(-0.10, 0.88, -1.48), Vector3(0.10, 0.08, 0.02), Color(0.26, 0.24, 0.20))
	_add_box(_room_root, "RadioDial",    Vector3(-0.01, 0.90, -1.48), Vector3(0.06, 0.04, 0.02), Color(0.20, 0.36, 0.60))
	_add_box(_room_root, "RadioAntenna", Vector3(-0.03, 0.98, -1.54), Vector3(0.02, 0.22, 0.02), Color(0.66, 0.64, 0.54))
	_create_radio_power_click_body()

	# ── DEAD DRIED PLANTS (shifted with window: x-0.4) ────────────────────────
	# Left of window
	_add_box(_room_root, "PlantPotL",   Vector3(-1.26, 0.10, -2.12), Vector3(0.22, 0.20, 0.22), Color(0.42, 0.26, 0.14))
	_add_box(_room_root, "PlantStemL1", Vector3(-1.26, 0.38, -2.12), Vector3(0.04, 0.32, 0.04), Color(0.40, 0.30, 0.18))
	_add_box(_room_root, "PlantStemL2", Vector3(-1.18, 0.56, -2.14), Vector3(0.03, 0.22, 0.03), Color(0.38, 0.28, 0.16))
	_add_box(_room_root, "PlantLeafL1", Vector3(-1.14, 0.58, -2.12), Vector3(0.18, 0.05, 0.05), Color(0.46, 0.36, 0.16))
	_add_box(_room_root, "PlantLeafL2", Vector3(-1.34, 0.64, -2.16), Vector3(0.14, 0.04, 0.05), Color(0.44, 0.34, 0.14))
	_add_box(_room_root, "PlantLeafL3", Vector3(-1.26, 0.70, -2.08), Vector3(0.06, 0.16, 0.03), Color(0.42, 0.32, 0.14))
	# Right of window
	_add_box(_room_root, "PlantPotR",   Vector3(0.44, 0.10, -2.12), Vector3(0.22, 0.20, 0.22), Color(0.42, 0.26, 0.14))
	_add_box(_room_root, "PlantStemR1", Vector3(0.44, 0.36, -2.12), Vector3(0.04, 0.28, 0.04), Color(0.40, 0.30, 0.18))
	_add_box(_room_root, "PlantLeafR1", Vector3(0.52, 0.50, -2.10), Vector3(0.16, 0.04, 0.04), Color(0.46, 0.36, 0.16))
	_add_box(_room_root, "PlantLeafR2", Vector3(0.36, 0.56, -2.16), Vector3(0.14, 0.04, 0.05), Color(0.44, 0.34, 0.14))

	# ── TORN POSTERS ──────────────────────────────────────────────────────────
	# Left wall
	_add_box(_room_root, "PosterFrameA",  Vector3(-2.50, 1.56, -0.90), Vector3(0.06, 0.64, 0.44), Color(0.28, 0.20, 0.12))
	_add_box(_room_root, "PosterPaperA",  Vector3(-2.47, 1.56, -0.90), Vector3(0.04, 0.52, 0.36), Color(0.88, 0.82, 0.70))
	_add_box(_room_root, "PosterTearA",   Vector3(-2.46, 1.82, -0.74), Vector3(0.03, 0.08, 0.18), Color(0.88, 0.82, 0.70))
	# Right wall
	_add_box(_room_root, "PosterFrameB",  Vector3(2.50, 1.60, -0.40), Vector3(0.06, 0.56, 0.38), Color(0.28, 0.20, 0.12))
	_add_box(_room_root, "PosterPaperB",  Vector3(2.47, 1.60, -0.40), Vector3(0.04, 0.46, 0.30), Color(0.74, 0.78, 0.82))
	_add_box(_room_root, "PosterHangB",   Vector3(2.46, 1.36, -0.40), Vector3(0.03, 0.12, 0.26), Color(0.74, 0.78, 0.82))
	# Back wall (used for over-shoulder check when player holds S in CRT view).
	_add_box(_room_root, "BackDoorFrame",  Vector3(0.0, 1.12, 2.50), Vector3(1.14, 2.24, 0.06), Color(0.20, 0.14, 0.10))
	_add_box(_room_root, "BackDoorLeaf",   Vector3(0.0, 1.08, 2.46), Vector3(0.96, 2.04, 0.04), Color(0.34, 0.24, 0.14))
	_add_box(_room_root, "BackDoorHandle", Vector3(0.34, 0.98, 2.43), Vector3(0.07, 0.05, 0.04), Color(0.72, 0.62, 0.40))

	_add_box(_room_root, "PosterFrameC", Vector3(-1.26, 1.56, 2.50), Vector3(0.54, 0.70, 0.06), Color(0.28, 0.20, 0.12))
	_add_box(_room_root, "PosterPaperC", Vector3(-1.26, 1.56, 2.47), Vector3(0.44, 0.58, 0.04), Color(0.84, 0.72, 0.58))
	_add_box(_room_root, "PosterTearC",  Vector3(-1.12, 1.84, 2.46), Vector3(0.16, 0.10, 0.03), Color(0.84, 0.72, 0.58))

	_add_box(_room_root, "BackWallHangerRail", Vector3(1.36, 1.88, 2.48), Vector3(0.34, 0.04, 0.06), Color(0.48, 0.34, 0.20))
	_add_box(_room_root, "BackWallHookA",      Vector3(1.26, 1.80, 2.45), Vector3(0.04, 0.12, 0.03), Color(0.64, 0.62, 0.54))
	_add_box(_room_root, "BackWallHookB",      Vector3(1.44, 1.80, 2.45), Vector3(0.04, 0.12, 0.03), Color(0.64, 0.62, 0.54))
	_add_box(_room_root, "BackWallCoatBody",   Vector3(1.36, 1.42, 2.45), Vector3(0.38, 0.72, 0.06), Color(0.20, 0.24, 0.34))
	_add_box(_room_root, "BackWallCoatSleeveL",Vector3(1.20, 1.44, 2.44), Vector3(0.16, 0.34, 0.05), Color(0.18, 0.22, 0.30))
	_add_box(_room_root, "BackWallCoatSleeveR",Vector3(1.52, 1.44, 2.44), Vector3(0.16, 0.34, 0.05), Color(0.18, 0.22, 0.30))
	_add_box(_room_root, "BackWallCoatCollar", Vector3(1.36, 1.78, 2.44), Vector3(0.24, 0.10, 0.05), Color(0.24, 0.30, 0.40))

	# ── CALENDAR (left wall, near front) ──────────────────────────────────────
	_add_box(_room_root, "Calendar",      Vector3(-2.49, 1.64, -1.56), Vector3(0.02, 0.56, 0.44), Color(0.78, 0.86, 0.94))
	_add_box(_room_root, "CalendarHeader",Vector3(-2.48, 1.86, -1.56), Vector3(0.02, 0.08, 0.43), Color(0.18, 0.34, 0.62))
	_add_box(_room_root, "CalendarBind",  Vector3(-2.48, 1.93, -1.56), Vector3(0.03, 0.03, 0.36), Color(0.56, 0.56, 0.58))

	# ── FILING CABINET (right wall) ───────────────────────────────────────────
	_add_box(_room_root, "FilingCab",     Vector3(2.18, 0.72, -1.10), Vector3(0.52, 1.44, 0.60), Color(0.60, 0.58, 0.52))
	_add_box(_room_root, "FilingDrawer1", Vector3(2.18, 1.10, -0.79), Vector3(0.46, 0.28, 0.04), Color(0.52, 0.50, 0.44))
	_add_box(_room_root, "FilingDrawer2", Vector3(2.18, 0.72, -0.79), Vector3(0.46, 0.28, 0.04), Color(0.52, 0.50, 0.44))
	_add_box(_room_root, "FilingDrawer3", Vector3(2.18, 0.34, -0.79), Vector3(0.46, 0.28, 0.04), Color(0.52, 0.50, 0.44))
	_add_box(_room_root, "FilingHandle1", Vector3(2.18, 1.10, -0.76), Vector3(0.14, 0.04, 0.04), Color(0.70, 0.66, 0.54))
	_add_box(_room_root, "FilingHandle2", Vector3(2.18, 0.72, -0.76), Vector3(0.14, 0.04, 0.04), Color(0.70, 0.66, 0.54))
	_add_box(_room_root, "FilingHandle3", Vector3(2.18, 0.34, -0.76), Vector3(0.14, 0.04, 0.04), Color(0.70, 0.66, 0.54))

	# ── WALL SHELVES (right wall, above cabinet) ───────────────────────────────
	_add_box(_room_root, "ShelfA",   Vector3(2.24, 1.84, -1.62), Vector3(0.28, 0.04, 0.74), Color(0.44, 0.30, 0.18))
	_add_box(_room_root, "ShelfB",   Vector3(2.24, 2.22, -1.62), Vector3(0.28, 0.04, 0.74), Color(0.44, 0.30, 0.18))
	_add_box(_room_root, "BinderA",  Vector3(2.24, 1.96, -1.30), Vector3(0.20, 0.22, 0.06), Color(0.28, 0.18, 0.52))
	_add_box(_room_root, "BinderB",  Vector3(2.24, 1.96, -1.52), Vector3(0.20, 0.22, 0.06), Color(0.52, 0.18, 0.18))
	_add_box(_room_root, "BinderC",  Vector3(2.24, 1.96, -1.72), Vector3(0.20, 0.22, 0.06), Color(0.18, 0.36, 0.18))
	_add_box(_room_root, "ShelfBook",Vector3(2.24, 2.32, -1.78), Vector3(0.20, 0.20, 0.08), Color(0.62, 0.50, 0.26))

	# ── RECEPTION COUNTER (between camera and desk — dusty, barely used) ──────
	_add_box(_room_root, "Counter",    Vector3(0.10, 0.45, 0.48), Vector3(3.10, 0.90, 0.70), Color(0.40, 0.28, 0.16))
	_add_box(_room_root, "CounterTop", Vector3(0.10, 0.93, 0.44), Vector3(3.20, 0.06, 0.78), Color(0.56, 0.42, 0.28), true)
	_add_box(_room_root, "CounterPaper1", Vector3(-0.50, 0.97, 0.32), Vector3(0.28, 0.008, 0.20), Color(0.86, 0.84, 0.76))
	_add_box(_room_root, "CounterPaper2", Vector3(-0.24, 0.97, 0.40), Vector3(0.22, 0.008, 0.16), Color(0.88, 0.86, 0.76))
	_add_box(_room_root, "CounterPhone",  Vector3(1.20, 1.00, 0.36), Vector3(0.36, 0.10, 0.24), Color(0.68, 0.64, 0.54))
	_add_box(_room_root, "CounterPhoneHandle", Vector3(1.20, 1.08, 0.36), Vector3(0.30, 0.06, 0.10), Color(0.70, 0.66, 0.56))
	_create_reception_notebook()

	# ── DOOR (left wall) ──────────────────────────────────────────────────────
	_add_box(_room_root, "DoorFrame",  Vector3(-2.48, 1.10, 1.28), Vector3(0.06, 2.20, 1.12), Color(0.20, 0.14, 0.10))
	_add_box(_room_root, "DoorLeaf",   Vector3(-2.43, 1.05, 1.28), Vector3(0.06, 2.02, 0.98), Color(0.32, 0.22, 0.14))
	_add_box(_room_root, "DoorHandle", Vector3(-2.36, 0.92, 0.84), Vector3(0.04, 0.06, 0.08), Color(0.74, 0.62, 0.40))

	# ── LIGHT SWITCH + DOOR HINT ──────────────────────────────────────────────
	_setup_office_light_system()
	_apply_room_time_profile()

	var door_hint = Label3D.new()
	door_hint.name = "DoorHint"
	door_hint.text = ""
	door_hint.font_size = 28
	door_hint.modulate = Color(0.9, 0.85, 0.6, 0.8)
	door_hint.position = Vector3(-2.38, 2.10, 1.28)
	door_hint.rotation = Vector3(0.0, PI * 0.5, 0.0)
	_room_root.add_child(door_hint)


func _build_crt_viewport() -> void:
	if _crt_viewport != null: return
	_crt_viewport = SubViewport.new()
	_crt_viewport.name = "CRTViewport"
	_crt_viewport.size = CRT_RESOLUTION
	_crt_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_crt_viewport.handle_input_locally = true
	_crt_viewport.gui_disable_input = false
	add_child(_crt_viewport)

	_crt_ui = CRT_UI_SCENE.new()
	_crt_ui.name = "CRTScannerUI"
	_crt_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt_ui.offset_left = 0.0
	_crt_ui.offset_top = 0.0
	_crt_ui.offset_right = 0.0
	_crt_ui.offset_bottom = 0.0
	_crt_viewport.add_child(_crt_ui)
	_configure_crt_ui()


func _set_crt_viewport_live(active: bool) -> void:
	if active:
		_sync_crt_viewport_to_window()
	if _crt_viewport != null:
		_crt_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		)


func _sync_interior_viewport_to_window() -> void:
	if _viewport == null:
		return
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	_viewport.size = Vector2i(
		max(INTERIOR_RENDER_MIN_SIZE.x, int(screen_size.x)),
		max(INTERIOR_RENDER_MIN_SIZE.y, int(screen_size.y))
	)


func _sync_crt_viewport_to_window() -> void:
	if _crt_viewport == null:
		return
	_crt_viewport.size = CRT_RESOLUTION
	if _crt_ui != null:
		_crt_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		_crt_ui.offset_left = 0.0
		_crt_ui.offset_top = 0.0
		_crt_ui.offset_right = 0.0
		_crt_ui.offset_bottom = 0.0


func enter_crt_view() -> void:
	if _crt_active: return
	_reset_crt_look_back_state()
	_crt_active = true
	_look.reset()
	_crt_orbit_enabled = true
	_sync_crt_viewport_to_window()
	_set_crt_viewport_live(true)

	if _camera_tween: _camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.set_trans(Tween.TRANS_CUBIC)

	# Target: Front of CRT (approx dist 0.5m so screen fits nice)
	# Screen Z global: -0.535.
	# Target Z: 0.1
	_camera_tween.tween_property(_interior_camera, "position", _crt_view_cam_pos, 1.2)
	_camera_tween.tween_property(_interior_camera, "rotation", Vector3(0.0, 0.0, 0.0), 1.2)
	_camera_tween.tween_property(_interior_camera, "fov", CRT_ENTER_FOV, 1.2)
	_camera_tween.finished.connect(func():
		if not _crt_active:
			return
		_capture_crt_orbit_anchor()
	)

	if _crt_ui:
		_crt_ui.open_panel()


func _exit_crt_view() -> void:
	if not _crt_active: return
	_crt_active = false
	_crt_orbit_enabled = false
	_reset_crt_look_back_state()

	if _camera_tween: _camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.set_trans(Tween.TRANS_CUBIC)

	_camera_tween.tween_property(_interior_camera, "position", _initial_cam_pos, 0.8)
	_camera_tween.tween_property(_interior_camera, "rotation", _initial_cam_rot, 0.8)
	_camera_tween.tween_property(_interior_camera, "fov", _initial_cam_fov, 0.8)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		if _crt_active:
			_exit_crt_view()
			get_viewport().set_input_as_handled()
			return
		close_interior()
		get_viewport().set_input_as_handled()
		return

	if _crt_active:
		# Forward input to CRT Viewport
		if event is InputEventMouse:
			_forward_input_to_crt(event)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if _handle_crt_look_back_key(key_event):
				get_viewport().set_input_as_handled()
				return
			_crt_viewport.push_input(key_event, true)
			get_viewport().set_input_as_handled()
			return

	if INTERIOR_LOOK.is_exit_event(event, get_viewport()):
		close_interior()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_L:
			_toggle_office_lights()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event = event as InputEventMouseButton
		if _try_click_room(mouse_event):
			get_viewport().set_input_as_handled()
			return
		_try_click_crt(mouse_event)
		get_viewport().set_input_as_handled()


func _forward_input_to_crt(event: InputEventMouse) -> void:
	if _interior_camera == null or _crt_screen == null or _crt_viewport == null:
		return
	var vp_pos = _map_mouse_to_crt(event.position, false)
	if vp_pos == Vector2.INF:
		return

	var new_ev = event.duplicate()
	new_ev.position = vp_pos
	new_ev.global_position = vp_pos
	if new_ev is InputEventMouseMotion:
		var rel_scale = _get_main_to_crt_scale()
		new_ev.relative = Vector2(event.relative.x * rel_scale.x, event.relative.y * rel_scale.y)
	_crt_viewport.push_input(new_ev, true)


func _map_mouse_to_crt(mouse_pos: Vector2, allow_fallback: bool = true) -> Vector2:
	var vp_size = _crt_viewport.size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return Vector2.INF
	# Primary mapping: actual raycast against the CRT mesh in 3D.
	var local_mouse = _to_interior_viewport_pos(mouse_pos)
	var ray_origin = _interior_camera.project_ray_origin(local_mouse)
	var ray_dir = _interior_camera.project_ray_normal(local_mouse)
	var screen_transform = _crt_screen.global_transform
	var plane_normal = screen_transform.basis.z.normalized()
	var plane = Plane(plane_normal, plane_normal.dot(screen_transform.origin))
	var intersect = plane.intersects_ray(ray_origin, ray_dir)
	if intersect != null:
		var local_hit = _crt_screen.to_local(intersect)
		var quad = _crt_screen.mesh as QuadMesh
		if quad != null and quad.size.x > 0.0 and quad.size.y > 0.0:
			var half_w = quad.size.x * 0.5
			var half_h = quad.size.y * 0.5
			if local_hit.x >= -half_w and local_hit.x <= half_w and local_hit.y >= -half_h and local_hit.y <= half_h:
				var uv_x = (local_hit.x / quad.size.x) + 0.5
				var uv_y = 0.5 - (local_hit.y / quad.size.y)
				return Vector2(uv_x * vp_size.x, uv_y * vp_size.y)

	if not allow_fallback:
		return Vector2.INF

	# Fallback mapping: when camera/framing drifts, map full screen directly to CRT viewport.
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return Vector2.INF
	var norm_x = clamp(mouse_pos.x / screen_size.x, 0.0, 1.0)
	var norm_y = clamp(mouse_pos.y / screen_size.y, 0.0, 1.0)
	return Vector2(norm_x * vp_size.x, norm_y * vp_size.y)


func _to_interior_viewport_pos(mouse_pos: Vector2) -> Vector2:
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or _viewport == null:
		return Vector2.ZERO
	var ix = clamp(mouse_pos.x / screen_size.x, 0.0, 1.0) * float(_viewport.size.x)
	var iy = clamp(mouse_pos.y / screen_size.y, 0.0, 1.0) * float(_viewport.size.y)
	return Vector2(ix, iy)


func _get_main_to_crt_scale() -> Vector2:
	if _crt_viewport == null:
		return Vector2.ONE
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(float(_crt_viewport.size.x) / screen_size.x, float(_crt_viewport.size.y) / screen_size.y)


func _configure_crt_ui() -> void:
	if _crt_ui == null:
		return
	if _crt_ui.has_method("setup"):
		_crt_ui.setup(_grid_manager, _building_manager, _legacy_ui_adapter, self)
	if _crt_ui.has_signal("desktop_ready"):
		var cb = Callable(self, "_on_crt_desktop_ready")
		if not _crt_ui.desktop_ready.is_connected(cb):
			_crt_ui.desktop_ready.connect(cb)
	_apply_pending_crt_desktop_state()


func _on_crt_desktop_ready() -> void:
	if not _crt_active:
		return
	_focus_crt_full()


func _focus_crt_full() -> void:
	if _interior_camera == null:
		return
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_tween.tween_property(_interior_camera, "position", _crt_full_cam_pos, 0.42)
	_camera_tween.tween_property(_interior_camera, "rotation", Vector3(0.0, 0.0, 0.0), 0.42)
	_camera_tween.tween_property(_interior_camera, "fov", CRT_READY_FOV, 0.42)
	_camera_tween.finished.connect(func():
		if not _crt_active:
			return
		_capture_crt_orbit_anchor()
	)


## Night -> evening -> day by the daylight factor (0..1), so the room changes as the
## light outside does, not in three jumps.
func _tri(d: float, night, evening, day):
	if d < 0.5:
		return lerp(night, evening, d * 2.0)
	return lerp(evening, day, (d - 0.5) * 2.0)


func _apply_room_time_profile(animated: bool = false) -> void:
	var d := clampf(_daylight_factor, 0.0, 1.0)
	if _room_environment != null:
		_room_environment.background_color = _tri(d, Color(0.08, 0.10, 0.14), Color(0.24, 0.20, 0.22), Color(0.66, 0.70, 0.74))
		_room_environment.ambient_light_color = _tri(d, Color(0.22, 0.26, 0.34), Color(0.48, 0.40, 0.42), Color(0.82, 0.84, 0.80))
		_room_environment.ambient_light_energy = _tri(d, 0.05, 0.54, 1.06)
		_room_environment.fog_light_color = _tri(d, Color(0.14, 0.18, 0.24), Color(0.34, 0.28, 0.30), Color(0.78, 0.82, 0.84))
		_room_environment.fog_density = _tri(d, 0.014, 0.010, 0.004)
	if _ceiling_light != null:
		_ceiling_light.light_color = _tri(d, Color(0.66, 0.72, 0.90), Color(0.92, 0.76, 0.64), Color(1.0, 0.96, 0.86))
		_ceiling_light.light_energy = _tri(d, 0.08, 0.88, 1.88)
	if _desk_lamp != null:
		_desk_lamp.light_energy = _tri(d, 0.02, 0.44, 0.70)
	if _window_light != null:
		_window_light.light_color = _tri(d, Color(0.54, 0.60, 0.84), Color(0.84, 0.66, 0.54), Color(0.98, 0.98, 0.92))
		_window_light.light_energy = _tri(d, 0.01, 0.24, 0.56)

	var daylight = clampf(_daylight_factor, 0.0, 1.0)
	var sun_tint = _sunlight_color.lerp(Color(1.0, 0.96, 0.90), 0.25)
	if _room_environment != null:
		_room_environment.ambient_light_color = _room_environment.ambient_light_color.lerp(sun_tint, 0.20 * daylight)
		_room_environment.ambient_light_energy = lerpf(_room_environment.ambient_light_energy * 0.80, _room_environment.ambient_light_energy * 1.16, daylight)
	if _ceiling_light != null:
		_ceiling_light.light_color = _ceiling_light.light_color.lerp(sun_tint, 0.14 * daylight)
		_ceiling_light.light_energy = lerpf(_ceiling_light.light_energy * 0.86, _ceiling_light.light_energy * 1.10, daylight)
	if _window_light != null:
		_window_light.light_color = _window_light.light_color.lerp(sun_tint, 0.32 * daylight)
		_window_light.light_energy = lerpf(_window_light.light_energy * 0.68, _window_light.light_energy * 1.28, daylight)
	if _desk_lamp != null:
		_desk_lamp.light_energy = max(_desk_lamp.light_energy, lerpf(0.01, 0.04, 1.0 - daylight))
	_apply_manual_office_light_profile(animated)
	_update_window_texture()


## A camera in the real camp, at the reception's front wall, looking out across the
## site: what you see through the window from the desk is what is out there (the
## guests, the lamps, and whatever walks between them at night).
const WINDOW_VIEW_SIZE := Vector2i(320, 240)
var _window_vp: SubViewport
var _window_cam: Camera3D


func _setup_window_view() -> void:
	if _window_vp != null:
		return
	_window_vp = SubViewport.new()
	_window_vp.name = "WindowView"
	_window_vp.size = WINDOW_VIEW_SIZE
	_window_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# No own world: it sees the camp's world, as the player outside does.
	add_child(_window_vp)
	_window_cam = Camera3D.new()
	_window_cam.fov = 62.0
	_window_cam.far = 220.0
	_window_vp.add_child(_window_cam)
	for n in ["OutdoorGround", "OutdoorCeiling", "OutdoorWallL", "OutdoorWallR", "OutdoorBushL", "OutdoorBushR", "OutdoorBushR2", "OutdoorGravelStrip0", "OutdoorGravelStrip1", "OutdoorGravelStrip2"]:
		var node := _room_root.get_node_or_null(n)
		if node != null:
			node.visible = false


func _place_window_camera() -> bool:
	if _window_cam == null:
		return false
	var scene := get_tree().current_scene if get_tree() != null else null
	var reception: Node3D = scene.find_child("MainBuilding", true, false) as Node3D if scene != null else null
	if reception == null:
		return false
	var grid = scene.get("grid_manager")
	var center: Vector3 = grid.get_map_center_world() if grid != null and grid.has_method("get_map_center_world") else Vector3.ZERO
	var base := reception.global_position
	var out := center - base
	out.y = 0.0
	out = out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	var eye := base + out * 4.0
	eye.y = 1.55
	_window_cam.global_position = eye
	_window_cam.look_at(eye + out * 10.0 + Vector3(0, -0.6, 0), Vector3.UP)
	return true


func _set_window_view_live(on: bool) -> void:
	if _window_vp == null:
		return
	if on and not _place_window_camera():
		on = false
	_window_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if _window_quad != null:
		var mat := _window_quad.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_texture = _window_vp.get_texture() if on else null


func _update_window_texture() -> void:
	if _window_quad == null and _window_outdoor_sky == null:
		return
	# Glass tint and outdoor sky color per time + weather
	var glass_color: Color
	var sky_color: Color
	var sky_emission: Color
	var sky_energy: float
	match _time_state:
		TIME_DAY:
			glass_color = Color(0.70, 0.80, 0.92, 1.0)
			sky_color = Color(0.56, 0.68, 0.82)
			sky_emission = Color(0.56, 0.68, 0.82)
			sky_energy = 0.80
		TIME_EVENING:
			glass_color = Color(0.84, 0.62, 0.46, 1.0)
			sky_color = Color(0.68, 0.42, 0.28)
			sky_emission = Color(0.72, 0.48, 0.32)
			sky_energy = 0.55
		_: # NIGHT
			glass_color = Color(0.18, 0.22, 0.38, 1.0)
			sky_color = Color(0.08, 0.10, 0.20)
			sky_emission = Color(0.10, 0.12, 0.24)
			sky_energy = 0.20
	# Weather modifiers
	match _weather_state:
		2: # FOG
			sky_color = sky_color.lerp(Color(0.62, 0.62, 0.62), 0.60)
			sky_emission = sky_emission.lerp(Color(0.60, 0.60, 0.60), 0.60)
			sky_energy *= 0.55
		3, 4: # LIGHT_RAIN, RAIN
			sky_color = sky_color.lerp(Color(0.42, 0.44, 0.48), 0.44)
			sky_emission = sky_emission.lerp(Color(0.42, 0.44, 0.48), 0.44)
			sky_energy *= 0.68
		5: # STORM
			sky_color = sky_color.lerp(Color(0.28, 0.30, 0.36), 0.70)
			sky_emission = sky_emission.lerp(Color(0.28, 0.30, 0.36), 0.70)
			sky_energy *= 0.40
	if _window_quad != null:
		var mat = _window_quad.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_window_quad.material_override = mat
		if mat.albedo_texture != null:
			# The real view: dirty glass, a touch of the room's colour.
			mat.albedo_color = Color(0.86, 0.88, 0.86).lerp(glass_color, 0.12)
			mat.emission_enabled = false
		else:
			mat.albedo_color = glass_color
			mat.emission_enabled = true
			mat.emission = glass_color
			mat.emission_energy_multiplier = sky_energy * 0.30
	if _window_outdoor_sky != null:
		var sky_mat = _window_outdoor_sky.material_override as StandardMaterial3D
		if sky_mat == null:
			sky_mat = StandardMaterial3D.new()
			sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sky_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_window_outdoor_sky.material_override = sky_mat
		sky_mat.albedo_color = sky_color
		sky_mat.emission_enabled = true
		sky_mat.emission = sky_emission
		sky_mat.emission_energy_multiplier = sky_energy


func set_weather_state(weather: int) -> void:
	_weather_state = weather
	_update_window_texture()


func _setup_office_light_system() -> void:
	_office_switch_tex_on = _pick_office_texture("interior_switch_on", Color(0.84, 0.80, 0.68))
	_office_switch_tex_off = _pick_office_texture("interior_switch_off", Color(0.68, 0.64, 0.58))
	_office_wall_tex_default = _pick_office_texture("office_wall", Color(0.66, 0.50, 0.36))
	_office_wall_tex_dim = _pick_office_texture("office_wall_dim", Color(0.40, 0.34, 0.30))
	_office_wall_tex_near = _pick_office_texture("office_wall_near_light", Color(0.52, 0.44, 0.38))
	_create_office_light_switch()
	_apply_office_switch_visual()
	_apply_office_wall_texture_state()


func _create_radio_power_click_body() -> void:
	if _room_root == null:
		return
	if _radio_power_click_body != null and is_instance_valid(_radio_power_click_body):
		return
	var radio_body = StaticBody3D.new()
	radio_body.name = "RadioPowerClickBody"
	radio_body.position = RADIO_CLICK_CENTER_LOCAL
	radio_body.set_meta("interior_click_type", "radio_power_toggle")
	var radio_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = RADIO_CLICK_SIZE
	radio_shape.shape = box_shape
	radio_body.add_child(radio_shape)
	_room_root.add_child(radio_body)
	_radio_power_click_body = radio_body


func _create_reception_notebook() -> void:
	if _room_root == null:
		return
	if _reception_notebook_click_body != null and is_instance_valid(_reception_notebook_click_body):
		return

	var notebook_root = Node3D.new()
	notebook_root.name = "ReceptionNotebook"
	notebook_root.position = Vector3(-0.94, 0.98, 0.34)
	notebook_root.rotation = Vector3(deg_to_rad(2.0), deg_to_rad(32.0), deg_to_rad(-8.0))
	_room_root.add_child(notebook_root)

	var cover = MeshInstance3D.new()
	cover.name = "NotebookCover"
	var cover_mesh = BoxMesh.new()
	cover_mesh.size = Vector3(0.34, 0.02, 0.24)
	cover.mesh = cover_mesh
	cover.material_override = _make_psx_material(Color(0.18, 0.30, 0.38), 18.0, 4.0, 0.01, "office_wood")
	notebook_root.add_child(cover)

	var pages = MeshInstance3D.new()
	pages.name = "NotebookPages"
	var pages_mesh = BoxMesh.new()
	pages_mesh.size = Vector3(0.30, 0.015, 0.20)
	pages.mesh = pages_mesh
	pages.position = Vector3(0.0, 0.011, 0.0)
	pages.material_override = _make_psx_material(Color(0.88, 0.86, 0.76), 8.0, 2.0, 0.01, "decor_paper")
	notebook_root.add_child(pages)

	var spine = MeshInstance3D.new()
	spine.name = "NotebookSpine"
	var spine_mesh = BoxMesh.new()
	spine_mesh.size = Vector3(0.028, 0.026, 0.24)
	spine.mesh = spine_mesh
	spine.position = Vector3(-0.154, 0.003, 0.0)
	spine.material_override = _make_psx_material(Color(0.14, 0.18, 0.22), 16.0, 4.0, 0.01, "decor_wood")
	notebook_root.add_child(spine)

	var click_body = StaticBody3D.new()
	click_body.name = "ReceptionNotebookClickBody"
	click_body.position = NOTEBOOK_CLICK_CENTER_LOCAL
	# Reserved interaction slot: the reception desk UI was cut with the assignment
	# system. `_try_click_room()` has no handler for it, so the click falls through.
	click_body.set_meta("interior_click_type", "reception_notebook")
	var click_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = NOTEBOOK_CLICK_SIZE
	click_shape.shape = box_shape
	click_body.add_child(click_shape)
	_room_root.add_child(click_body)
	_reception_notebook_click_body = click_body


func _pick_office_texture(category: String, base_color: Color) -> Texture2D:
	if _texture_style == null:
		return null
	return _texture_style.pick_texture(category, base_color)


func _create_office_light_switch() -> void:
	if _room_root == null:
		return
	var switch_body = StaticBody3D.new()
	switch_body.name = "OfficeLightSwitch"
	switch_body.position = Vector3(-2.38, 1.18, 0.62)
	switch_body.rotation = Vector3(0.0, PI * 0.5, 0.0)
	switch_body.set_meta("interior_click_type", "office_light_switch")
	var switch_mesh = MeshInstance3D.new()
	switch_mesh.name = "SwitchVisual"
	var switch_box = BoxMesh.new()
	switch_box.size = Vector3(0.08, 0.32, 0.20)
	switch_mesh.mesh = switch_box
	var switch_mat := StandardMaterial3D.new()
	switch_mat.albedo_color = Color(0.82, 0.78, 0.66, 1.0)
	switch_mat.roughness = 0.96
	switch_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	switch_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	switch_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	switch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	switch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	switch_mat.emission_enabled = true
	switch_mat.emission = Color(0.16, 0.14, 0.10, 1.0)
	switch_mesh.material_override = switch_mat
	switch_body.add_child(switch_mesh)
	var switch_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.22, 0.46, 0.28)
	switch_shape.shape = box_shape
	switch_body.add_child(switch_shape)
	_room_root.add_child(switch_body)
	_office_light_switch_body = switch_body
	_office_light_switch_mesh = switch_mesh


func _apply_office_switch_visual() -> void:
	if _office_light_switch_mesh == null:
		return
	var switch_mat = _office_light_switch_mesh.material_override as StandardMaterial3D
	if switch_mat == null:
		return
	var wanted_tex: Texture2D = _office_switch_tex_on if _office_lights_on else _office_switch_tex_off
	if wanted_tex != null:
		switch_mat.albedo_texture = wanted_tex
		switch_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		return
	switch_mat.albedo_texture = null
	switch_mat.albedo_color = Color(0.84, 0.80, 0.66, 1.0) if _office_lights_on else Color(0.58, 0.56, 0.52, 1.0)


func _is_near_light_wall_node(node_name: String) -> bool:
	var n = node_name.to_lower()
	return n.contains("ceiling") or n.contains("walltrim") or n.contains("wallright")


func _apply_office_wall_texture_state() -> void:
	if _office_wall_meshes.is_empty():
		return
	for mesh in _office_wall_meshes:
		if mesh == null:
			continue
		var mat = mesh.material_override as StandardMaterial3D
		if mat == null:
			continue
		var wanted_tex: Texture2D = _office_wall_tex_default
		if not _office_lights_on:
			wanted_tex = _office_wall_tex_dim if _office_wall_tex_dim != null else _office_wall_tex_default
			if _office_near_light_wall_meshes.has(mesh) and _office_wall_tex_near != null:
				wanted_tex = _office_wall_tex_near
		if wanted_tex != null:
			mat.albedo_texture = wanted_tex
			mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)


func _toggle_office_lights() -> void:
	_office_lights_on = not _office_lights_on
	_apply_office_switch_visual()
	_apply_office_wall_texture_state()
	_apply_room_time_profile(true)


func _toggle_radio_power() -> void:
	_radio_power_on = not _radio_power_on
	_radio_power_transition_time_left = RADIO_POWER_TOGGLE_FADE_SEC


func _apply_manual_office_light_profile(animated: bool) -> void:
	var ambient_target = _room_environment.ambient_light_energy if _room_environment != null else 0.0
	var ceiling_target = _ceiling_light.light_energy if _ceiling_light != null else 0.0
	var desk_target = _desk_lamp.light_energy if _desk_lamp != null else 0.0
	var window_target = _window_light.light_energy if _window_light != null else 0.0
	if not _office_lights_on:
		ambient_target *= 0.62
		ceiling_target *= 0.14
		desk_target *= 0.12
		window_target *= 0.18
	if not _grid_power_available:
		ambient_target *= 0.34
		ceiling_target = 0.0
		desk_target = 0.0
		window_target *= 0.28
	if animated:
		if _office_light_tween != null and is_instance_valid(_office_light_tween):
			_office_light_tween.kill()
		_office_light_tween = create_tween()
		_office_light_tween.set_parallel(true)
		_office_light_tween.set_ease(Tween.EASE_IN_OUT)
		_office_light_tween.set_trans(Tween.TRANS_SINE)
		if _room_environment != null:
			_office_light_tween.tween_property(_room_environment, "ambient_light_energy", ambient_target, 0.68)
		if _ceiling_light != null:
			_office_light_tween.tween_property(_ceiling_light, "light_energy", ceiling_target, 0.68)
		if _desk_lamp != null:
			_office_light_tween.tween_property(_desk_lamp, "light_energy", desk_target, 0.68)
		if _window_light != null:
			_office_light_tween.tween_property(_window_light, "light_energy", window_target, 0.68)
		return
	if _room_environment != null:
		_room_environment.ambient_light_energy = ambient_target
	if _ceiling_light != null:
		_ceiling_light.light_energy = ceiling_target
	if _desk_lamp != null:
		_desk_lamp.light_energy = desk_target
	if _window_light != null:
		_window_light.light_energy = window_target


func _resolve_main_runtime_host() -> Node:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor.has_method("get_electricity_ui_snapshot"):
			return cursor
		cursor = cursor.get_parent()
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	var main = tree.root.get_node_or_null("Main")
	if main != null and main.has_method("get_electricity_ui_snapshot"):
		return main
	return null


func get_electricity_ui_snapshot() -> Dictionary:
	var host := _resolve_main_runtime_host()
	if host == null or not host.has_method("get_electricity_ui_snapshot"):
		return {}
	var snapshot_any = host.call("get_electricity_ui_snapshot")
	if snapshot_any is Dictionary:
		return (snapshot_any as Dictionary).duplicate(true)
	return {}


func request_pay_electricity_bill(bill_id: String) -> Dictionary:
	var host := _resolve_main_runtime_host()
	if host == null or not host.has_method("request_pay_electricity_bill"):
		return {"ok": false, "reason": "runtime_missing"}
	var result_any = host.call("request_pay_electricity_bill", bill_id)
	if result_any is Dictionary:
		return (result_any as Dictionary).duplicate(true)
	return {"ok": false, "reason": "invalid_result"}


func _setup_radio_character() -> void:
	_radio_rng.randomize()
	_radio_wow_phase = _radio_rng.randf_range(0.0, TAU)
	_radio_flutter_phase = _radio_rng.randf_range(0.0, TAU)
	_schedule_radio_dropout()


func _schedule_radio_dropout() -> void:
	_radio_dropout_timer = _radio_rng.randf_range(RADIO_DROPOUT_INTERVAL_MIN, RADIO_DROPOUT_INTERVAL_MAX)
	_radio_dropout_remaining = 0.0
	_radio_dropout_duration = 0.0


func _ensure_radio_bus() -> void:
	var bus_index = AudioServer.get_bus_index(RADIO_BUS_NAME)
	if bus_index == -1:
		bus_index = AudioServer.get_bus_count()
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, RADIO_BUS_NAME)
	AudioServer.set_bus_send(bus_index, "Master")
	_ensure_radio_bus_effects(bus_index)


func _ensure_radio_bus_effects(bus_index: int) -> void:
	var has_eq: bool = false
	var has_low_pass: bool = false
	var has_high_pass: bool = false
	var effect_count = AudioServer.get_bus_effect_count(bus_index)
	for i in range(effect_count):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectEQ6:
			has_eq = true
		elif effect is AudioEffectLowPassFilter:
			has_low_pass = true
		elif effect is AudioEffectHighPassFilter:
			has_high_pass = true
	if not has_eq:
		var eq := AudioEffectEQ6.new()
		eq.set_band_gain_db(0, -18.0)
		eq.set_band_gain_db(1, -10.0)
		eq.set_band_gain_db(2, -3.0)
		eq.set_band_gain_db(3, 1.6)
		eq.set_band_gain_db(4, 0.8)
		eq.set_band_gain_db(5, -8.0)
		AudioServer.add_bus_effect(bus_index, eq, AudioServer.get_bus_effect_count(bus_index))
	if not has_high_pass:
		var high_pass := AudioEffectHighPassFilter.new()
		high_pass.cutoff_hz = 175.0
		high_pass.resonance = 0.65
		AudioServer.add_bus_effect(bus_index, high_pass, AudioServer.get_bus_effect_count(bus_index))
	if not has_low_pass:
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = 4050.0
		low_pass.resonance = 0.75
		AudioServer.add_bus_effect(bus_index, low_pass, AudioServer.get_bus_effect_count(bus_index))


func _setup_radio() -> void:
	_ensure_radio_bus()
	_radio_load_paths = _collect_audio_paths_in_dir("res://assets/sfx/radio")
	_radio_load_paths = _filter_radio_load_paths(_radio_load_paths)
	if _radio_load_paths.is_empty():
		push_warning("Radio: no music tracks configured in res://assets/sfx/radio/")
	for path in _radio_load_paths:
		ResourceLoader.load_threaded_request(path, "AudioStream", false)


func _collect_radio_tracks() -> void:
	if _radio_loaded:
		return
	_radio_loaded = true
	_radio_tracks.clear()
	_radio_tracks_paths.clear()
	_radio_tracks_all.clear()
	_radio_tracks_all_is_night.clear()
	_radio_tracks_all_paths.clear()
	_radio_stream_by_path.clear()
	_radio_cursed_infravrany_path = ""
	for path in _radio_load_paths:
		var status := ResourceLoader.load_threaded_get_status(path)
		var stream: AudioStream
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			stream = ResourceLoader.load_threaded_get(path) as AudioStream
		if stream == null:
			stream = _load_radio_stream(path)
		if stream != null:
			_radio_tracks_all.append(stream)
			_radio_tracks_all_is_night.append(_is_radio_night_path(path))
			_radio_tracks_all_paths.append(path)
			_radio_stream_by_path[path] = stream
			if _is_radio_cursed_infravrany_path(path):
				_radio_cursed_infravrany_path = path
	print("Radio: loaded %d music tracks" % _radio_tracks_all.size())
	if _radio_tracks_all.is_empty():
		push_warning("Radio: no music tracks loaded — check res://assets/sfx/radio/")
		return
	_rebuild_radio_tracks_for_time(true)
	_create_radio_player()


func _create_radio_player() -> void:
	if _radio_player != null and is_instance_valid(_radio_player):
		return
	_radio_player = _create_radio_layer_player("RadioPlayer", RADIO_PITCH_BASE)
	_radio_player.finished.connect(_on_radio_finished)
	call_deferred("_play_radio_next")


func _create_radio_layer_player(player_name: String, pitch_scale: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = RADIO_BUS_NAME
	player.volume_db = RADIO_OUTSIDE_SILENT_DB
	player.pitch_scale = pitch_scale
	add_child(player)
	return player


func _play_radio_next() -> void:
	if _radio_player == null:
		return
	if _try_play_station():
		return
	if _radio_tracks.is_empty():
		_rebuild_radio_tracks_for_time(false)
	if _radio_tracks.is_empty():
		_radio_current_track_is_night = false
		return
	var track_count = _radio_tracks.size()
	_radio_index = _radio_index % track_count
	var selected_index = _select_radio_track_index(_radio_index)
	var base_track = _radio_tracks[selected_index]
	var base_is_night = _radio_tracks_is_night[selected_index] if selected_index < _radio_tracks_is_night.size() else false
	var base_path = _radio_tracks_paths[selected_index] if selected_index < _radio_tracks_paths.size() else ""
	var playback = _resolve_radio_playback_track(base_track, base_path, base_is_night)
	var resolved_stream = playback.get("stream", base_track) as AudioStream
	if resolved_stream == null:
		resolved_stream = base_track
	var resolved_path = String(playback.get("path", base_path))
	var resolved_is_night = bool(playback.get("is_night", base_is_night))
	_radio_current_track_is_night = resolved_is_night
	_radio_player.stream = resolved_stream
	_radio_player.play()
	_radio_last_played_path = resolved_path
	_radio_index = (selected_index + 1) % track_count


func _try_play_station() -> bool:
	if _time_state != TIME_NIGHT:
		return false
	var day := int(CoreRoot.get_day()) if CoreRoot != null else 1
	if day < 2 or _station_heard_day == day:
		return false
	if _radio_rng.randf() > STATION_CHANCE_PER_TRACK:
		return false
	var playlist := build_station_stream(_count_guests_in_camp() + 1)
	if playlist == null:
		return false
	_station_heard_day = day
	_radio_current_track_is_night = false
	_radio_last_played_path = ""
	_radio_player.stream = playlist
	_radio_player.play()
	return true


## The station as one stream: intro, `pips` pips (a longer pause after every fifth),
## outro. Static so the debug/shot tooling can play it.
static func build_station_stream(pips: int) -> AudioStream:
	var intro := load(STATION_INTRO) as AudioStream
	var pip := load(STATION_PIP) as AudioStream
	var pip5 := load(STATION_PIP5) as AudioStream
	var outro := load(STATION_OUTRO) as AudioStream
	if intro == null or pip == null or pip5 == null or outro == null:
		return null
	var list: Array[AudioStream] = [intro]
	# AudioStreamPlaylist holds 64 streams; two are the intro and outro.
	for i in clampi(pips, 1, AudioStreamPlaylist.MAX_STREAMS - 2):
		list.append(pip5 if (i + 1) % 5 == 0 else pip)
	list.append(outro)
	var playlist := AudioStreamPlaylist.new()
	playlist.loop = false
	playlist.fade_time = 0.0
	playlist.stream_count = list.size()
	for i in list.size():
		playlist.set_list_stream(i, list[i])
	return playlist


## Debug/screenshot entry: tune to the station now.
func debug_play_station() -> void:
	_ensure_radio_playback()
	if _radio_player == null:
		return
	var playlist := build_station_stream(_count_guests_in_camp() + 1)
	if playlist != null:
		_radio_player.stream = playlist
		_radio_player.play()


func _count_guests_in_camp() -> int:
	if CoreRoot == null or CoreRoot.get_state() == null:
		return 0
	return int(CoreRoot.get_state().guests.size())


func _on_radio_finished() -> void:
	if _radio_tracks.is_empty():
		return
	if _radio_index == 0:
		_shuffle_radio_playlist()
	_play_radio_next()


func _select_radio_track_index(start_index: int) -> int:
	var track_count = _radio_tracks.size()
	if track_count <= 1:
		return 0
	var start = start_index % track_count
	if _radio_last_played_path.is_empty():
		return start
	for offset in range(track_count):
		var idx = (start + offset) % track_count
		var path = _radio_tracks_paths[idx] if idx < _radio_tracks_paths.size() else ""
		if path.is_empty() or path != _radio_last_played_path:
			return idx
	return start


func _resolve_radio_playback_track(base_stream: AudioStream, base_path: String, base_is_night: bool) -> Dictionary:
	var resolved_stream: AudioStream = base_stream
	var resolved_path := base_path
	var resolved_is_night := base_is_night
	if _is_radio_infravrany_path(base_path) and not _radio_cursed_infravrany_path.is_empty():
		var cursed_stream = _radio_stream_by_path.get(_radio_cursed_infravrany_path, null) as AudioStream
		if cursed_stream != null and _radio_rng.randf() < RADIO_CURSED_INFRAVRANY_CHANCE:
			resolved_stream = cursed_stream
			resolved_path = _radio_cursed_infravrany_path
			resolved_is_night = _is_radio_night_path(_radio_cursed_infravrany_path)
	if not _radio_last_played_path.is_empty() and resolved_path == _radio_last_played_path and base_path != resolved_path:
		resolved_stream = base_stream
		resolved_path = base_path
		resolved_is_night = base_is_night
	return {
		"stream": resolved_stream,
		"path": resolved_path,
		"is_night": resolved_is_night
	}


func _filter_radio_load_paths(paths: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	var excluded_name = RADIO_EXCLUDED_FILENAME.to_lower()
	for path in paths:
		if path.get_file().to_lower() == excluded_name:
			continue
		filtered.append(path)
	return filtered


func _is_radio_night_path(path: String) -> bool:
	return path.get_file().to_lower().begins_with(RADIO_NIGHT_TRACK_PREFIX)


func _is_radio_infravrany_path(path: String) -> bool:
	return path.get_file().to_lower() == RADIO_INFRAVRANY_FILENAME


func _is_radio_cursed_infravrany_path(path: String) -> bool:
	return path.get_file().to_lower() == RADIO_CURSED_INFRAVRANY_FILENAME


func _rebuild_radio_tracks_for_time(restart_playback: bool) -> void:
	_radio_tracks.clear()
	_radio_tracks_is_night.clear()
	_radio_tracks_paths.clear()
	var use_night_playlist = (_time_state == TIME_NIGHT)
	var track_count = mini(_radio_tracks_all.size(), mini(_radio_tracks_all_is_night.size(), _radio_tracks_all_paths.size()))
	for i in range(track_count):
		var path = _radio_tracks_all_paths[i]
		if _is_radio_cursed_infravrany_path(path):
			continue
		var is_night_track = _radio_tracks_all_is_night[i]
		# Day: play only regular tracks. Night: play both, but NIGHT* tracks are weighted.
		if not use_night_playlist and is_night_track:
			continue
		var weight = RADIO_NIGHT_TRACK_WEIGHT_AT_NIGHT if (use_night_playlist and is_night_track) else 1
		for _w in range(weight):
			_radio_tracks.append(_radio_tracks_all[i])
			_radio_tracks_is_night.append(is_night_track)
			_radio_tracks_paths.append(path)
	_radio_index = 0
	if _radio_tracks.is_empty():
		_radio_current_track_is_night = false
		_radio_last_played_path = ""
		if _radio_player != null and restart_playback:
			_radio_player.stop()
		return
	_shuffle_radio_playlist()
	if _radio_player == null:
		return
	var has_current_track = _radio_player.stream != null and _radio_tracks.has(_radio_player.stream)
	if restart_playback:
		_play_radio_next()
		return
	if not has_current_track and not _radio_player.playing:
		_play_radio_next()


func _shuffle_radio_playlist() -> void:
	if _radio_tracks.size() <= 1:
		return
	var indices: Array[int] = []
	for i in range(_radio_tracks.size()):
		indices.append(i)
	for i in range(indices.size() - 1, 0, -1):
		var j = _radio_rng.randi_range(0, i)
		var temp = indices[i]
		indices[i] = indices[j]
		indices[j] = temp
	var shuffled_tracks: Array[AudioStream] = []
	var shuffled_is_night: Array[bool] = []
	var shuffled_paths: Array[String] = []
	for idx in indices:
		shuffled_tracks.append(_radio_tracks[idx])
		shuffled_is_night.append(_radio_tracks_is_night[idx])
		var path = _radio_tracks_paths[idx] if idx < _radio_tracks_paths.size() else ""
		shuffled_paths.append(path)
	_radio_tracks = shuffled_tracks
	_radio_tracks_is_night = shuffled_is_night
	_radio_tracks_paths = shuffled_paths


func _collect_audio_paths_in_dir(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result
	var normalized_dir = dir_path.trim_suffix("/")
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		var lower = file_name.to_lower()
		if not (lower.ends_with(".mp3") or lower.ends_with(".wav") or lower.ends_with(".ogg")):
			continue
		result.append("%s/%s" % [normalized_dir, file_name])
	dir.list_dir_end()
	result.sort()
	return result


func _load_radio_stream(res_path: String) -> AudioStream:
	var stream = load(res_path) as AudioStream
	if stream != null:
		return stream
	if res_path.get_extension().to_lower() != "mp3":
		return null
	var abs_path = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var bytes = FileAccess.get_file_as_bytes(abs_path)
	if bytes.is_empty():
		return null
	var mp3 := AudioStreamMP3.new()
	mp3.data = bytes
	return mp3


func _update_radio_mix(delta: float) -> void:
	_ensure_radio_playback()
	var target_db = _compute_radio_target_db()
	var character_db = _compute_radio_character_volume_offset(delta)
	var night_track_db = RADIO_NIGHT_TRACK_VOLUME_OFFSET_DB if _radio_current_track_is_night else 0.0
	var final_target_db = target_db + character_db + night_track_db
	if not _radio_power_on:
		final_target_db = RADIO_POWER_OFF_VOLUME_DB
	# Indoors the radio is in your ear; outdoors it is a place (the reception), heard
	# through the positional mirror below, and the flat player only keeps the playlist.
	var outdoor_db: float = RADIO_OUTDOOR_VOLUME_DB + character_db + night_track_db
	if visible:
		outdoor_db = RADIO_OUTSIDE_SILENT_DB
	else:
		final_target_db = RADIO_OUTSIDE_SILENT_DB
	if not _radio_power_on:
		final_target_db = RADIO_POWER_OFF_VOLUME_DB
		outdoor_db = RADIO_POWER_OFF_VOLUME_DB
	_sync_radio_outdoor(outdoor_db, delta)
	if _radio_power_transition_time_left > 0.0:
		_apply_radio_layer_volume_for_duration(_radio_player, final_target_db, delta, _radio_power_transition_time_left)
		_radio_power_transition_time_left = max(0.0, _radio_power_transition_time_left - delta)
		return
	_apply_radio_layer_volume(_radio_player, final_target_db, delta)


## Keeps a positional copy of the radio at the reception, playing the same stream at
## the same position and pitch as the flat player.
func _sync_radio_outdoor(target_db: float, delta: float) -> void:
	var building := _resolve_main_building_node()
	if _radio_player == null or building == null or not is_instance_valid(building) or not building.is_inside_tree():
		if _radio_outdoor != null and _radio_outdoor.playing:
			_radio_outdoor.stop()
		return
	if _radio_outdoor == null or not is_instance_valid(_radio_outdoor):
		_radio_outdoor = AudioStreamPlayer3D.new()
		_radio_outdoor.name = "RadioOutdoor"
		_radio_outdoor.bus = RADIO_BUS_NAME
		_radio_outdoor.unit_size = RADIO_OUTDOOR_UNIT_SIZE
		_radio_outdoor.max_distance = RADIO_OUTDOOR_MAX_DISTANCE
		_radio_outdoor.attenuation_filter_cutoff_hz = 2600.0
		_radio_outdoor.attenuation_filter_db = -14.0
		_radio_outdoor.volume_db = RADIO_OUTSIDE_SILENT_DB
		building.add_child(_radio_outdoor)
	elif _radio_outdoor.get_parent() != building:
		_radio_outdoor.reparent(building, false)
	_radio_outdoor.position = Vector3(0.0, RADIO_OUTDOOR_HEIGHT, 0.0)
	_radio_outdoor.volume_db = move_toward(_radio_outdoor.volume_db, target_db, maxf(delta, 0.016) * RADIO_VOLUME_LERP_SPEED * 20.0)
	# It keeps playing while muted (indoors): a playlist cannot be joined mid-way.
	if not _radio_player.playing or _radio_player.stream == null:
		if _radio_outdoor.playing:
			_radio_outdoor.stop()
		return
	_radio_outdoor.pitch_scale = _radio_player.pitch_scale
	var src_pos := _radio_player.get_playback_position()
	if _radio_outdoor.stream != _radio_player.stream or not _radio_outdoor.playing:
		_radio_outdoor.stream = _radio_player.stream
		_radio_outdoor.play(src_pos)
	elif not (_radio_player.stream is AudioStreamPlaylist) and absf(_radio_outdoor.get_playback_position() - src_pos) > 0.25:
		_radio_outdoor.seek(src_pos)


func _ensure_radio_playback() -> void:
	if not _radio_loaded:
		_collect_radio_tracks()
	if _radio_tracks.is_empty() and not _radio_tracks_all.is_empty():
		_rebuild_radio_tracks_for_time(false)
	if _radio_player == null and not _radio_tracks.is_empty():
		_create_radio_player()
	if _radio_player != null and not _radio_player.playing and not _radio_tracks.is_empty():
		_play_radio_next()


func _compute_radio_target_db() -> float:
	if visible:
		return RADIO_INTERIOR_VOLUME_DB
	var distance = _distance_to_main_building()
	if not is_finite(distance):
		distance = RADIO_OUTSIDE_FAR_DISTANCE + 0.01
	if distance <= RADIO_OUTSIDE_NEAR_DISTANCE:
		return RADIO_OUTSIDE_NEAR_VOLUME_DB
	if distance >= RADIO_OUTSIDE_FAR_DISTANCE:
		return RADIO_OUTSIDE_SILENT_DB
	var t = (distance - RADIO_OUTSIDE_NEAR_DISTANCE) / max(0.001, RADIO_OUTSIDE_FAR_DISTANCE - RADIO_OUTSIDE_NEAR_DISTANCE)
	var t_clamped = clampf(t, 0.0, 1.0)
	# Smooth near-to-far rolloff over a short walking range.
	var eased = t_clamped * t_clamped * (3.0 - (2.0 * t_clamped))
	return lerpf(RADIO_OUTSIDE_NEAR_VOLUME_DB, RADIO_OUTSIDE_SILENT_DB, eased)


func get_radio_notification_volume_db() -> float:
	# Keep desktop email pings on the same audible falloff curve as the radio.
	return _compute_radio_target_db()


func _apply_radio_layer_volume(player: AudioStreamPlayer, target_db: float, delta: float) -> void:
	if player == null:
		return
	player.volume_db = move_toward(player.volume_db, target_db, max(delta, 0.016) * RADIO_VOLUME_LERP_SPEED * 20.0)


func _apply_radio_layer_volume_for_duration(
	player: AudioStreamPlayer,
	target_db: float,
	delta: float,
	seconds_left: float
) -> void:
	if player == null:
		return
	var remaining = max(seconds_left, 0.001)
	var step = absf(target_db - player.volume_db) * (max(delta, 0.0) / remaining)
	player.volume_db = move_toward(player.volume_db, target_db, step)


func _compute_radio_character_volume_offset(delta: float) -> float:
	_update_radio_character_pitch(delta)
	if _radio_player == null or not _radio_player.playing:
		return 0.0
	if _radio_dropout_remaining > 0.0:
		_radio_dropout_remaining = max(0.0, _radio_dropout_remaining - delta)
		var progress = 1.0 - (_radio_dropout_remaining / max(0.001, _radio_dropout_duration))
		var envelope = sin(progress * PI)
		return RADIO_DROPOUT_ATTENUATION_DB * envelope
	_radio_dropout_timer -= delta
	if _radio_dropout_timer <= 0.0:
		_radio_dropout_duration = _radio_rng.randf_range(RADIO_DROPOUT_DURATION_MIN, RADIO_DROPOUT_DURATION_MAX)
		_radio_dropout_remaining = _radio_dropout_duration
		_radio_dropout_timer = _radio_rng.randf_range(RADIO_DROPOUT_INTERVAL_MIN, RADIO_DROPOUT_INTERVAL_MAX)
	return 0.0


func _update_radio_character_pitch(delta: float) -> void:
	if _radio_player == null:
		return
	_radio_wow_phase = fmod(_radio_wow_phase + TAU * RADIO_WOW_RATE_HZ * delta, TAU)
	_radio_flutter_phase = fmod(_radio_flutter_phase + TAU * RADIO_FLUTTER_RATE_HZ * delta, TAU)
	var wow = sin(_radio_wow_phase) * RADIO_WOW_DEPTH
	var flutter = (
		sin(_radio_flutter_phase) * RADIO_FLUTTER_DEPTH
		+ sin(_radio_flutter_phase * 1.93 + 0.82) * (RADIO_FLUTTER_DEPTH * 0.45)
	)
	_radio_player.pitch_scale = clampf(RADIO_PITCH_BASE + wow + flutter, 0.93, 1.02)


func _distance_to_main_building() -> float:
	var main_building = _resolve_main_building_node()
	var listener_pos = _resolve_radio_listener_position()
	# The reception is rebuilt on load/new game; for a frame the old node can be out of
	# the tree, and asking it for a transform then is an engine error.
	if main_building == null or not is_instance_valid(main_building) or not main_building.is_inside_tree() or not is_finite(listener_pos.x):
		return RADIO_OUTSIDE_FAR_DISTANCE + 0.01
	var shape_node = main_building.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var box_shape = shape_node.shape as BoxShape3D if shape_node != null else null
	if box_shape != null:
		var local = main_building.to_local(listener_pos)
		var half = box_shape.size * 0.5
		var dx = max(absf(local.x) - half.x, 0.0)
		var dy = max(absf(local.y) - half.y, 0.0)
		var dz = max(absf(local.z) - half.z, 0.0)
		return sqrt(dx * dx + dy * dy + dz * dz)
	return listener_pos.distance_to(main_building.global_position)


func _resolve_radio_listener_position() -> Vector3:
	if _player_ref != null and is_instance_valid(_player_ref):
		return _player_ref.global_position
	var scene_root = get_tree().current_scene
	var fallback_player = _find_node3d_by_name(scene_root, "Player")
	if fallback_player == null:
		fallback_player = _find_node3d_by_name_fragment(scene_root, "player")
	if fallback_player != null:
		_player_ref = fallback_player
		return _player_ref.global_position
	var active_camera = get_viewport().get_camera_3d()
	if active_camera != null:
		return active_camera.global_position
	return Vector3(INF, INF, INF)


func _resolve_main_building_node() -> Node3D:
	if _main_building_ref != null and is_instance_valid(_main_building_ref):
		return _main_building_ref
	if _building_manager == null:
		_building_manager = _find_node_by_name(get_tree().current_scene, "BuildingManager")
	var candidate = _find_main_building_in_branch(_building_manager)
	if candidate == null:
		var scene_root = get_tree().current_scene
		candidate = _find_main_building_in_branch(scene_root)
	if candidate != null:
		_main_building_ref = candidate
		return _main_building_ref
	return null


func _find_main_building_in_branch(root: Node) -> Node3D:
	if root == null:
		return null
	var stack: Array[Node] = []
	stack.append(root)
	while not stack.is_empty():
		var node = stack.pop_back()
		var node3d = node as Node3D
		if node3d != null:
			var building_type = str(node3d.get_meta("building_type", ""))
			if building_type == "main_building":
				return node3d
			var lower_name = node3d.name.to_lower()
			if (
				lower_name == "mainbuilding"
				or lower_name.begins_with("mainbuilding")
				or lower_name == "main_building"
				or lower_name.begins_with("main_building")
			):
				return node3d
		for child in node.get_children():
			stack.append(child)
	return null


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root == null or target_name.is_empty():
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.name == target_name:
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func _find_node3d_by_name(root: Node, target_name: String) -> Node3D:
	var found = _find_node_by_name(root, target_name)
	return found as Node3D


func _find_node3d_by_name_fragment(root: Node, fragment: String) -> Node3D:
	if root == null or fragment.is_empty():
		return null
	var needle = fragment.to_lower()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		var node3d = node as Node3D
		if node3d != null and node3d.name.to_lower().contains(needle):
			return node3d
		for child in node.get_children():
			stack.append(child)
	return null


func _try_click_room(event: InputEventMouseButton) -> bool:
	# AABB hotspots take priority over the physics raycast: the props are small and
	# the collider mesh is easy to miss, so the box test is the forgiving path.
	if _is_mouse_over_radio(event.position):
		_toggle_radio_power()
		return true

	var hit = _raycast_room(event.position)
	var collider = hit.get("collider", null) as Node
	if collider == null:
		return false

	if _node_has_click_type(collider, "office_light_switch"):
		_toggle_office_lights()
		return true
	if _node_has_click_type(collider, "radio_power_toggle"):
		_toggle_radio_power()
		return true
	return false


func _node_has_click_type(node: Node, click_type: String) -> bool:
	var current = node
	while current != null:
		if str(current.get_meta("interior_click_type", "")) == click_type:
			return true
		current = current.get_parent()
	return false


func _raycast_room(mouse_pos: Vector2) -> Dictionary:
	if _interior_camera == null or _viewport == null:
		return {}
	var world = _viewport.get_world_3d()
	if world == null:
		return {}
	var local_mouse = _to_interior_viewport_pos(mouse_pos)
	var ray_origin = _interior_camera.project_ray_origin(local_mouse)
	var ray_dir = _interior_camera.project_ray_normal(local_mouse)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_dir * 24.0))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_ray(query)


func _is_mouse_over_radio(mouse_pos: Vector2) -> bool:
	if _interior_camera == null or _room_root == null:
		return false
	var local_mouse = _to_interior_viewport_pos(mouse_pos)
	var ray_origin = _interior_camera.project_ray_origin(local_mouse)
	var ray_dir = _interior_camera.project_ray_normal(local_mouse)
	var center_global = _room_root.to_global(RADIO_CLICK_CENTER_LOCAL)
	var half_extents = RADIO_CLICK_SIZE * 0.5
	return _ray_intersects_aabb(ray_origin, ray_dir, center_global, half_extents)


func _ray_intersects_aabb(ray_origin: Vector3, ray_dir: Vector3, box_center: Vector3, half_extents: Vector3) -> bool:
	var min_b = box_center - half_extents
	var max_b = box_center + half_extents
	var t_min = -INF
	var t_max = INF
	var origins = [ray_origin.x, ray_origin.y, ray_origin.z]
	var directions = [ray_dir.x, ray_dir.y, ray_dir.z]
	var mins = [min_b.x, min_b.y, min_b.z]
	var maxs = [max_b.x, max_b.y, max_b.z]
	for i in range(3):
		var origin = origins[i]
		var direction = directions[i]
		var min_axis = mins[i]
		var max_axis = maxs[i]
		if absf(direction) < 0.00001:
			if origin < min_axis or origin > max_axis:
				return false
			continue
		var inv = 1.0 / direction
		var t1 = (min_axis - origin) * inv
		var t2 = (max_axis - origin) * inv
		if t1 > t2:
			var temp = t1
			t1 = t2
			t2 = temp
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_max < t_min:
			return false
	return t_max >= maxf(t_min, 0.0)


func _update_crt_monitor_light(delta: float) -> void:
	if _crt_glow_light == null:
		return
	if not visible or _crt_viewport == null:
		_crt_glow_light.light_energy = lerpf(_crt_glow_light.light_energy, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		return

	_crt_glow_sample_timer += max(delta, 0.0)
	if _crt_glow_sample_timer >= 0.12:
		_crt_glow_sample_timer = 0.0
		var sample_color = _sample_crt_average_color()
		var luma = (sample_color.r * 0.2126) + (sample_color.g * 0.7152) + (sample_color.b * 0.0722)
		_crt_glow_target_color = sample_color.lerp(Color(1.0, 1.0, 1.0), 0.06)
		var base_energy = 0.55
		match _time_state:
			TIME_DAY:
				base_energy = 0.45
			TIME_EVENING:
				base_energy = 0.78
			_:
				base_energy = 1.10
		_crt_glow_target_energy = clampf(base_energy + (luma * 1.6), 0.0, 2.3)

	var distance_mix := 1.0
	var range_target := CRT_GLOW_FAR_RANGE
	if _interior_camera != null and _crt_screen != null and is_instance_valid(_crt_screen):
		var cam_pos := _interior_camera.global_transform.origin
		var screen_pos := _crt_screen.global_transform.origin
		var screen_dist := cam_pos.distance_to(screen_pos)
		distance_mix = clampf(inverse_lerp(CRT_GLOW_NEAR_DISTANCE, CRT_GLOW_FAR_DISTANCE, screen_dist), 0.0, 1.0)
	var distance_curve := pow(distance_mix, CRT_GLOW_DISTANCE_CURVE_POWER)
	range_target = lerpf(CRT_GLOW_NEAR_RANGE, CRT_GLOW_FAR_RANGE, distance_curve)
	var energy_target := clampf(
		_crt_glow_target_energy * lerpf(CRT_GLOW_NEAR_ENERGY_MULT, CRT_GLOW_FAR_ENERGY_MULT, distance_curve),
		0.0,
		2.3
	)
	if _crt_active:
		energy_target *= CRT_GLOW_ACTIVE_ENERGY_MULT
		range_target = minf(range_target, CRT_GLOW_ACTIVE_MAX_RANGE)

	var blend = clampf(delta * 7.0, 0.0, 1.0)
	_crt_glow_light.light_color = _crt_glow_light.light_color.lerp(_crt_glow_target_color, blend)
	_crt_glow_light.light_energy = lerpf(_crt_glow_light.light_energy, energy_target, blend)
	_crt_glow_light.omni_range = lerpf(_crt_glow_light.omni_range, range_target, clampf(delta * 5.0, 0.0, 1.0))
	if _crt_screen != null and is_instance_valid(_crt_screen):
		var screen_mat := _crt_screen.material_override as StandardMaterial3D
		if screen_mat != null and screen_mat.emission_enabled:
			var emission_target := lerpf(CRT_SCREEN_EMISSION_NEAR, CRT_SCREEN_EMISSION_FAR, distance_curve)
			if _crt_active:
				emission_target *= CRT_SCREEN_EMISSION_ACTIVE_MULT
			screen_mat.emission_energy_multiplier = lerpf(
				screen_mat.emission_energy_multiplier,
				emission_target,
				clampf(delta * 6.0, 0.0, 1.0)
			)


func _sample_crt_average_color() -> Color:
	if DisplayServer.get_name() == "headless":
		return Color(0.62, 0.78, 1.0, 1.0)
	if _crt_viewport == null:
		return Color(0.62, 0.78, 1.0, 1.0)
	var tex = _crt_viewport.get_texture()
	if tex == null:
		return Color(0.62, 0.78, 1.0, 1.0)
	var image = tex.get_image()
	if image == null or image.is_empty():
		return Color(0.62, 0.78, 1.0, 1.0)
	var w = image.get_width()
	var h = image.get_height()
	if w <= 0 or h <= 0:
		return Color(0.62, 0.78, 1.0, 1.0)

	var sample_uvs = [
		Vector2(0.50, 0.50),
		Vector2(0.24, 0.28),
		Vector2(0.76, 0.30),
		Vector2(0.22, 0.74),
		Vector2(0.78, 0.72),
		Vector2(0.50, 0.18),
		Vector2(0.50, 0.84),
	]
	var accum = Color(0.0, 0.0, 0.0, 0.0)
	for uv in sample_uvs:
		var x = clampi(int(round(uv.x * float(w - 1))), 0, w - 1)
		var y = clampi(int(round(uv.y * float(h - 1))), 0, h - 1)
		accum += image.get_pixel(x, y)
	var inv_count = 1.0 / float(sample_uvs.size())
	var avg = accum * inv_count
	return Color(
		clampf(pow(avg.r, 0.90), 0.0, 1.0),
		clampf(pow(avg.g, 0.90), 0.0, 1.0),
		clampf(pow(avg.b, 0.90), 0.0, 1.0),
		1.0
	)


func _make_psx_material(base_color: Color, _snap: float = 18.0, _steps: float = 5.0, _wobble_strength: float = 0.01, texture_category: String = "") -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# "plastic": the computer's own casing, smooth, no texture from the pack.
	if _texture_style != null and texture_category != "plastic":
		var category = texture_category if texture_category != "" else "generic"
		var tex = _texture_style.pick_texture(category, base_color)
		if tex != null:
			mat.albedo_texture = tex
			mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	return mat


func _add_box(parent: Node, name_str: String, pos: Vector3, size: Vector3, color: Color, use_triplanar: bool = false) -> void:
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = name_str
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	var uv_scale = Vector3(max(1.0, size.x * 1.5), 1.0, max(1.0, size.z * 1.5))
	var category = _category_for_node(name_str, color)
	var mat = _make_psx_material(color, 18.0, 5.0, 0.01, category)
	var base_mat := mat as BaseMaterial3D
	if base_mat != null:
		if use_triplanar:
			base_mat.uv1_triplanar = true
			base_mat.uv1_scale = Vector3(1.5, 1.5, 1.5)
		else:
			base_mat.uv1_scale = uv_scale
	mesh_inst.material_override = mat
	if category == "office_wall":
		_office_wall_meshes.append(mesh_inst)
		if _is_near_light_wall_node(name_str):
			_office_near_light_wall_meshes.append(mesh_inst)
	parent.add_child(mesh_inst)


func _add_cable_polyline(parent: Node3D, name_prefix: String, points: PackedVector3Array, radius: float, color: Color) -> void:
	if parent == null or points.size() < 2:
		return
	for i in range(points.size() - 1):
		_add_cable_segment(parent, "%s_%d" % [name_prefix, i], points[i], points[i + 1], radius, color)


func _add_cable_segment(parent: Node3D, name_str: String, from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var direction := to - from
	var seg_len := direction.length()
	if seg_len <= 0.001:
		return
	var cable = MeshInstance3D.new()
	cable.name = name_str
	var cable_mesh := CylinderMesh.new()
	cable_mesh.top_radius = radius
	cable_mesh.bottom_radius = radius
	cable_mesh.height = seg_len
	cable_mesh.radial_segments = 6
	cable.mesh = cable_mesh
	var up := direction / seg_len
	var helper := Vector3.FORWARD
	if absf(up.dot(helper)) > 0.96:
		helper = Vector3.RIGHT
	var right := helper.cross(up).normalized()
	var forward := up.cross(right).normalized()
	cable.transform = Transform3D(Basis(right, up, forward), (from + to) * 0.5)
	cable.material_override = _make_psx_material(color, 14.0, 3.0, 0.0, "office_pc_light")
	parent.add_child(cable)


func _category_for_node(node_name: String, base_color: Color) -> String:
	var n = node_name.to_lower()
	if n.contains("floorscatter26"):
		return "office_floor_scatter_26"
	if n.contains("floorscatter27"):
		return "office_floor_scatter_27"
	if n.contains("calendar"):
		return "office_calendar"
	if n.contains("counter") and n.contains("top"):
		return "office_tabletop"
	if n.contains("keyboard") or n.contains("crt") or n.contains("tower") or n.contains("mouse"):
		return "office_pc_light"
	if n.contains("drawer"):
		return "office_drawer"
	if n.contains("shelf"):
		return "office_shelf"
	if n.contains("outdoor"):
		if n.contains("ground") or n.contains("gravel"):
			return "floor"
		return "stone"
	if n.contains("floor"):
		return "floor"
	if n.contains("wall") or n.contains("ceiling"):
		return "office_wall"
	if n.contains("fan") or n.contains("blade"):
		return "decor_metal"
	if n.contains("radio"):
		return "decor_metal"
	if n.contains("filing") or n.contains("binder"):
		return "decor_metal"
	if n.contains("chair"):
		return "office_wood"
	if n.contains("counter") or n.contains("crate"):
		return "office_wood"
	if n.contains("door") or n.contains("frame"):
		return "decor_wood"
	if n.contains("hang"):
		return "decor_paper"
	if n.contains("paper"):
		return "decor_paper"
	if n.contains("plant") or n.contains("leaf") or n.contains("stem") or n.contains("pot"):
		return "foliage"
	if n.contains("window"):
		return "glass"
	if n.contains("phone") or n.contains("hook"):
		return "decor_metal"
	if base_color.s < 0.20 and base_color.v > 0.62:
		return "stone"
	return "decor_wood"
