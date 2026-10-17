extends CanvasLayer

const INTERIOR_BARREL_SHADER = preload("res://materials/interior_barrel_post.gdshader")
const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
## Reception surfaces by node name (exact names first, then prefixes): [camp texture,
## metres per repeat]. "" = not built (replaced by a prop or a picture, see _build_room).
const RECEPTION_EXACT := {
	"Floor": ["parquet", 0.9], "Ceiling": ["ceiling_board", 1.0], "CeilingTrim": ["planks_dark", 0.6],
	"Desk": ["veneer_dark", 0.7], "DeskTop": ["veneer_dark", 0.7], "DeskDrawerA": ["veneer_dark", 0.5], "DeskDrawerB": ["veneer_dark", 0.5],
	"Counter": ["pub_panel", 1.0], "CounterTop": ["veneer_dark", 0.8],
	"ShelfA": ["knotty_pine", 0.5], "ShelfB": ["knotty_pine", 0.5],
	"BackDoorFrame": ["planks_dark", 0.6], "DoorFrame": ["planks_dark", 0.6],
	"BackDoorLeaf": ["door_wood", 2.04], "DoorLeaf": ["door_wood", 2.02],
	"WindowSill": ["knotty_pine", 0.5],
}
const RECEPTION_PREFIX := {
	"FloorTile": "", "FloorScatter": "", "FilingCab": "", "FilingDrawer": "", "FilingHandle": "",
	"PosterFrame": "", "PosterPaper": "", "PosterTear": "", "PosterHang": "",
	"Wall": ["knotty_pine", 1.2], "WindowFrame": ["knotty_pine", 0.5], "WindowMullion": ["knotty_pine", 0.5],
}
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_TORCH = preload("res://scripts/ui/interior_torch.gd")
## Your torch, in here when it is dark: it shines where the cursor points.
var _torch: Node
const RECEPTION_EXTRAS = preload("res://scripts/reception/reception_extras.gd")
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
## The radio going wrong with the night (scripts/radio/radio_dread.gd): layers on top of
## the songs, the song bus, and how the songs bend.
const RADIO_DREAD_SCRIPT = preload("res://scripts/radio/radio_dread.gd")
## How often the NIGHT RISK forecast is re-read for the radio (it walks every guest).
const RADIO_DREAD_RISK_POLL_SEC: float = 3.0
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
## The reception (2026-10-16 brief): you stand behind the counter facing the room and
## the front door; the computer is on the low desk to your left, the key board on the
## wall to your right. The PC corner was built under the window; PC_OFFSET carries it.
const RECEPTION_CAM_POS := Vector3(0.0, 1.5, 1.15)
const ENTRY_YAW_DEG := 36.0
const PC_OFFSET := Vector3(-1.94, 0.0, 1.68)
const RL = preload("res://scripts/reception/reception_layout.gd")
const CURTAIN = preload("res://scripts/reception/curtain.gd")
## The monitor turned a little toward where you stand at the counter (playtest
## 2026-10-17), about its own middle; the seat in front of it turns with it.
const CRT_YAW_DEG := 18.0
const CRT_PIVOT := Vector3(0.24, 1.35, -1.53)
const CRT_SEAT_ROT := Vector3(0.0, 0.3141593, 0.0)   # CRT_YAW_DEG in radians
const DESK_ROOM = preload("res://scripts/reception/desk_room.gd")
const RADIO_CLICK_CENTER_LOCAL := Vector3(-0.10, 0.92, -1.52) + PC_OFFSET
const RADIO_CLICK_SIZE := Vector3(0.46, 0.42, 0.38)
const NOTEBOOK_CLICK_CENTER_LOCAL := Vector3(-0.12, 1.0, 0.34)
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
const CRT_SCREEN_QUAD_SIZE := Vector2(0.48, 0.36)
const CRT_SCREEN_LOCAL_POS := Vector3(0.0, 0.056, 0.356)
## The tube's barrel (materials/crt_glass.gdshader, crt_sharp.gdshader): the picture
## bends with the glass; _crt_barrel() is the same, for the mouse.
const CRT_CURVE := 0.16
## How far the middle of the glass bows out toward you, metres (crt_glass.gdshader).
const CRT_BULGE := 0.024

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _interior_camera: Camera3D
var _room_root: Node3D
var _crt_body: StaticBody3D
var _crt_screen: MeshInstance3D
var _room_environment: Environment
var _ceiling_light: OmniLight3D
var _desk_lamp: OmniLight3D
var _sun_beam: SpotLight3D
var _office_curtain
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
## The monitor picture redrawn crisp over the low-res room while you sit at it.
var _crt_sharp: Control
## The overlay's mesh: the bulged glass, a grid of points projected through the room
## camera (window pixels), their glass UVs, two triangles a cell.
var _crt_sharp_pts := PackedVector2Array()
var _crt_sharp_uvs := PackedVector2Array()
var _crt_sharp_cols := PackedColorArray()
var _crt_sharp_idx := PackedInt32Array()
const CRT_SHARP_GRID := Vector2i(16, 12)
var _crt_sharp_layer: CanvasLayer
var _daylight_factor: float = 0.0
var _sunlight_color: Color = Color(1.0, 0.95, 0.84)
var _crt_glow_target_color: Color = Color(0.62, 0.78, 1.0)
var _crt_glow_target_energy: float = 0.0
var _crt_glow_sample_timer: float = 0.0

# CRT 3D State
var _crt_viewport: SubViewport
var _exit_hint: Control
## The same band at the PC: "Stand up".
var _stand_hint: Control
var _crt_ui: Control
var _crt_active: bool = false
var _camera_tween: Tween
var _initial_cam_pos: Vector3
var _initial_cam_rot: Vector3
var _initial_cam_fov: float = 54.0
var _idle_cam_base_rot: Vector3 = Vector3.ZERO
## In the office, away from the screen: all the way round, the room is there behind you
## too (the door you came in by, the coat hooks); playtest: "I can't turn right round".
var _look = INTERIOR_LOOK.new(180.0, 30.0, 38.0)
var _desk_room
## The phone, the noticeboard, the door to the back room and the room behind it.
var _extras
var _crt_orbit_anchor_pos: Vector3 = Vector3.ZERO
var _crt_orbit_anchor_offset: Vector3 = Vector3.ZERO
var _crt_orbit_pivot: Vector3 = Vector3.ZERO
var _crt_orbit_enabled: bool = false
var _crt_look_back_cam_pos: Vector3 = Vector3(0.02, 1.36, -0.16)
var _crt_look_back_cam_rot: Vector3 = Vector3(-0.034, PI, 0.0)
var _crt_look_back_hold_time: float = 0.0
var _crt_look_back_armed: bool = false
var _crt_look_back_active: bool = false

var _crt_view_cam_pos: Vector3 = Vector3(0.24, 1.37, -0.24) + PC_OFFSET
var _crt_full_cam_pos: Vector3 = Vector3(0.28, 1.35, -0.34) + PC_OFFSET
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
var _dread: Node
var _dread_risk: float = 0.0
var _dread_risk_poll: float = 0.0
var _radio_main_ref: Node
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
	# Under the HUD (65), whose messages show over a room.
	layer = 60
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
	var out: Dictionary = (state_any as Dictionary).duplicate(true) if state_any is Dictionary else _pending_crt_desktop_state.duplicate(true)
	if _desk_room != null:
		out["checkin_desk"] = _desk_room.export_state()
	return out


func import_crt_desktop_state(state: Dictionary) -> void:
	_pending_crt_desktop_state = state.duplicate(true)
	if _desk_room != null and state.get("checkin_desk", null) is Dictionary:
		_desk_room.import_state(state["checkin_desk"])
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
	RETRO_RENDER.apply_to(_viewport_container)
	_sync_crt_viewport_to_window()
	_set_crt_viewport_live(true)
	if _extras != null:
		_extras.reset_to_office()
	_interior_camera.rotation = Vector3(deg_to_rad(-9.0), 0.0, 0.0)
	_interior_camera.position = RECEPTION_CAM_POS
	_interior_camera.current = true

	_initial_cam_pos = _interior_camera.position
	_initial_cam_rot = _interior_camera.rotation
	_initial_cam_fov = _interior_camera.fov
	_idle_cam_base_rot = _initial_cam_rot
	_look.reset()
	# In through the door and round behind the counter: the head already turned toward
	# the PC (it is ~60 degrees to the left of straight on), the counter still in view.
	_look.yaw_deg = ENTRY_YAW_DEG
	_capture_crt_orbit_anchor()
	_apply_room_time_profile()
	_collect_radio_tracks()
	_rebuild_radio_tracks_for_time(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_interior() -> void:
	if _camera_tween != null:
		_camera_tween.kill()
	if _extras != null:
		_extras.reset_to_office()
	if _desk_room != null:
		_desk_room.on_left_office()
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
	_update_crt_sharp()
	if _extras != null:
		_extras.tick_ring(delta)
	if not visible:
		return
	_update_window_portal()
	if _interior_camera != null:
		_update_torch(delta)
	_update_crt_monitor_light(delta)
	# Spin fan blades
	if _fan_pivot != null:
		_fan_spin += delta * 380.0
		# Drawn in steps (10 a second), like the rest of the old machinery.
		_fan_pivot.rotation_degrees.z = floorf(_fan_spin / 38.0) * 38.0
	if _interior_camera == null:
		return
	if _crt_active:
		# Seated means the computer is in use (the screen saver keys off it).
		if _crt_ui != null and _crt_ui.has_method("is_open") and not _crt_ui.is_open():
			_crt_ui.open_panel()
		if _stand_hint == null:
			_stand_hint = INTERIOR_LOOK.make_exit_hint(self, "Stand up")
		INTERIOR_LOOK.update_exit_hint(_stand_hint, get_viewport(), delta, _crt_stand_zone())
		if _exit_hint != null:
			_exit_hint.modulate.a = 0.0
		_update_crt_look_back_hold(delta)
		if _is_camera_tween_running():
			return
		if _crt_look_back_active:
			return
		_apply_crt_mouse_orbit(delta)
		return
	if _desk_room != null:
		_desk_room.process(delta, _extras == null or not _extras.in_back_room())
	if _is_camera_tween_running():
		return
	if _desk_room != null and _desk_room.is_open():
		return
	if _extras != null and _extras.process(delta, _hour_now()):
		_update_exit_hint_only(delta)
		return
	if _stand_hint != null:
		_stand_hint.modulate.a = 0.0
	_update_office_hover()
	_apply_idle_mouse_look(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta, not _crt_active)


func _update_exit_hint_only(delta: float) -> void:
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
	var allowed: bool = _extras == null or not _extras.is_modal()
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta, allowed)


func _hour_now() -> float:
	var main := _resolve_main_runtime_host()
	return float(main.get("_time_of_day_hours")) if main != null else 12.0


## The office's own clickables (the radio, the light switch, the screen): the gloved
## finger and the glint, like the extras'. The way out behind you: the flat hand.
func _update_office_hover() -> void:
	if _extras == null or _extras.hovered() != "":
		return
	var vp := get_viewport()
	if INTERIOR_LOOK.in_exit_zone(vp):
		HandCursor.want(HandCursor.WALK)
		return
	var m := vp.get_mouse_position()
	var meshes: Array = []
	if _is_mouse_over_radio(m):
		for n in ["RadioBody", "RadioSpeaker", "RadioDial", "RadioAntenna", "RadioSet"]:
			var node := _room_root.get_node_or_null(n)
			if node != null:
				meshes.append(node)
	else:
		var hit := _raycast_room(m)
		var collider = hit.get("collider", null) as Node
		if collider != null and _node_has_click_type(collider, "office_light_switch") and _office_light_switch_mesh != null:
			meshes.append(_office_light_switch_mesh)
		elif _crt_screen != null and _map_mouse_to_crt(m, false) != Vector2.INF:
			HandCursor.want(HandCursor.POINT)
	if not meshes.is_empty():
		HandCursor.want(HandCursor.POINT)
	_extras.glint.show_on(meshes)


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
	_camera_tween.tween_property(_interior_camera, "rotation", _crt_rest_rot(_crt_full_cam_pos), CRT_LOOK_BACK_TRANSITION_SEC)
	_camera_tween.tween_property(_interior_camera, "fov", CRT_READY_FOV, CRT_LOOK_BACK_TRANSITION_SEC)
	_camera_tween.finished.connect(func():
		if not _crt_active:
			return
		_capture_crt_orbit_anchor()
		if not _crt_look_back_active:
			_crt_orbit_enabled = true
	)


func _apply_idle_mouse_look(delta: float) -> void:
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
	_interior_camera.rotation = _idle_cam_base_rot + offset


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
	# The room in the game's low resolution like the world (the OS screen is laid over it
	# sharp, see _update_crt_sharp).
	RETRO_RENDER.register(_viewport_container)

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
	_interior_camera.position = RECEPTION_CAM_POS
	_interior_camera.fov = 68.0
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
	_desk_lamp.position = Vector3(0.5, 1.26, -1.20) + PC_OFFSET
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
	_window_light.omni_range = 5.6
	_window_light.omni_attenuation = 1.4
	_window_light.shadow_enabled = false
	_room_root.add_child(_window_light)
	# The sun through the glass: a spot outside the window shining in and down, with
	# shadows (the cross of the window on the floor and the counter).
	_sun_beam = SpotLight3D.new()
	_sun_beam.name = "SunBeam"
	_sun_beam.position = RL.OFFICE_WINDOW_CENTER + Vector3(0.6, 1.4, -2.2)
	_sun_beam.look_at_from_position(_sun_beam.position, Vector3(-0.2, 0.4, 0.4), Vector3.UP)
	_sun_beam.spot_range = 9.0
	_sun_beam.spot_angle = 34.0
	_sun_beam.spot_attenuation = 0.6
	_sun_beam.shadow_enabled = true
	_sun_beam.light_energy = 0.0
	_room_root.add_child(_sun_beam)

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
	_add_box(_room_root, "WallFrontRight",  Vector3( 0.925, 1.4, -2.55), Vector3(0.65, 2.8, 0.1), Color(0.66, 0.50, 0.36))
	_add_box(_room_root, "WallFrontRightB", Vector3( 2.35, 1.4, -2.55), Vector3(0.30, 2.8, 0.1), Color(0.66, 0.50, 0.36))
	_add_box(_room_root, "WallFrontDoorTop", Vector3( 1.725, 2.45, -2.55), Vector3(0.95, 0.7, 0.1), Color(0.66, 0.50, 0.36))
	_add_box(_room_root, "FrontDoorFrameL", Vector3( 1.22, 1.05, -2.52), Vector3(0.06, 2.10, 0.14), Color(0.20, 0.14, 0.10))
	_add_box(_room_root, "FrontDoorFrameR", Vector3( 2.23, 1.05, -2.52), Vector3(0.06, 2.10, 0.14), Color(0.20, 0.14, 0.10))
	_add_box(_room_root, "FrontDoorFrameT", Vector3( 1.725, 2.12, -2.52), Vector3(1.07, 0.06, 0.14), Color(0.20, 0.14, 0.10))
	# Beyond the door: the step and the camp, lit by the day (the window's view).
	_add_box(_room_root, "FrontStep", Vector3(1.725, -0.02, -3.1), Vector3(1.2, 0.08, 1.1), Color(0.46, 0.44, 0.40))
	_add_box(_room_root, "FrontPorchL", Vector3(1.15, 1.2, -3.1), Vector3(0.06, 2.6, 1.1), Color(0.40, 0.32, 0.24))
	_add_box(_room_root, "FrontPorchR", Vector3(2.30, 1.2, -3.1), Vector3(0.06, 2.6, 1.1), Color(0.40, 0.32, 0.24))
	_add_box(_room_root, "FrontPorchTop", Vector3(1.725, 2.4, -3.1), Vector3(1.2, 0.06, 1.1), Color(0.40, 0.32, 0.24))
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

	# ── THE PC CORNER: the old work desk, the computer, the fan and the radio, on the
	# low desk at the left end of the counter (PC_OFFSET from where they were made).
	var pc_root := Node3D.new()
	pc_root.name = "PCCorner"
	pc_root.position = PC_OFFSET
	_room_root.add_child(pc_root)
	# ── CRT WORKDESK (shifted right, x+0.5) ───────────────────────────────────
	_add_box(pc_root, "Desk",    Vector3(0.5, 0.38, -1.36), Vector3(1.80, 0.76, 0.74), Color(0.38, 0.26, 0.16))
	_add_box(pc_root, "DeskTop", Vector3(0.5, 0.79, -1.36), Vector3(1.92, 0.06, 0.84), Color(0.56, 0.42, 0.28), true)
	_add_box(pc_root, "DeskDrawerA", Vector3(0.04, 0.52, -0.96), Vector3(0.52, 0.18, 0.04), Color(0.34, 0.24, 0.16))
	_add_box(pc_root, "DeskDrawerB", Vector3(0.82, 0.52, -0.96), Vector3(0.52, 0.18, 0.04), Color(0.34, 0.24, 0.16))
	_add_box(pc_root, "DrawerHandleA", Vector3(0.04, 0.52, -0.93), Vector3(0.10, 0.04, 0.03), Color(0.64, 0.56, 0.42))
	_add_box(pc_root, "DrawerHandleB", Vector3(0.82, 0.52, -0.93), Vector3(0.10, 0.04, 0.03), Color(0.64, 0.56, 0.42))
	# Cup / ashtray on desk
	_add_box(pc_root, "DeskCup", Vector3(1.20, 0.90, -0.98), Vector3(0.08, 0.14, 0.08), Color(0.50, 0.26, 0.18))
	_build_desk_lamp(pc_root)

	# ── RETRO COMPUTER SETUP (monitor + tower + keyboard + mouse) ─────────────
	var pc_shell_col := Color(0.80, 0.75, 0.63)
	var pc_shell_dark_col := Color(0.66, 0.62, 0.52)
	var pc_panel_col := Color(0.88, 0.84, 0.72)
	var pc_charcoal_col := Color(0.14, 0.14, 0.14)

	_crt_body = StaticBody3D.new()
	_crt_body.name = "CRTMonitor"
	_crt_body.position = CRT_PIVOT
	_crt_body.rotation_degrees.y = CRT_YAW_DEG
	pc_root.add_child(_crt_body)
	_crt_view_cam_pos = _crt_seat(Vector3(0.24, 1.37, -0.24))
	_crt_full_cam_pos = _crt_seat(Vector3(0.28, 1.35, -0.34))

	_build_monitor_boxes()
	var crt_col = CollisionShape3D.new()
	var crt_shape = BoxShape3D.new()
	crt_shape.size = Vector3(0.86, 0.64, 0.66)
	crt_col.shape = crt_shape
	_crt_body.add_child(crt_col)

	_crt_screen = MeshInstance3D.new()
	_crt_screen.name = "CRTScreen"
	var scr_mesh = QuadMesh.new()
	scr_mesh.size = CRT_SCREEN_QUAD_SIZE
	# Subdivided: the glass bows out (materials/crt_glass.gdshader).
	scr_mesh.subdivide_width = 16
	scr_mesh.subdivide_depth = 12
	_crt_screen.mesh = scr_mesh
	_crt_screen.position = CRT_SCREEN_LOCAL_POS
	# The picture tube: the OS picture behind curved glass, unshaded (what the computer
	# draws is not lit, and burnt white, by the room), the room caught in the glass.
	var scr_mat := ShaderMaterial.new()
	scr_mat.shader = load("res://materials/crt_glass.gdshader")
	scr_mat.set_shader_parameter("curve", CRT_CURVE)
	scr_mat.set_shader_parameter("bulge", CRT_BULGE)
	if _crt_viewport:
		scr_mat.set_shader_parameter("screen_tex", _crt_viewport.get_texture())
	else:
		scr_mat.set_shader_parameter("powered", 0.0)
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

	# The tower, the keyboard and the mouse: Build-engine style, plain boxes in the
	# yellowed plastic, the detail on the faces (Grok textures, assets/textury/camp).
	var K := INTERIOR_KIT
	var plastic := K.surface("plastic", 0.35)
	# A desktop case under the monitor, as the 90s had them (the tower beside it stood
	# between the screen and the counter once the monitor was turned toward you).
	var case_root := Node3D.new()
	case_root.name = "PCCase"
	case_root.position = Vector3(0.24, 0.0, -1.5)
	case_root.rotation_degrees.y = CRT_YAW_DEG
	pc_root.add_child(case_root)
	K.slab(case_root, Vector3(0.66, 0.15, 0.5), Vector3(0, 0.895, 0), plastic, "PCTower")
	var bay := K.surface("plastic", 0.35, Color(0.78, 0.74, 0.62))
	K.slab(case_root, Vector3(0.2, 0.05, 0.012), Vector3(-0.17, 0.92, 0.251), bay, "PCDriveBay")
	K.slab(case_root, Vector3(0.14, 0.012, 0.014), Vector3(-0.17, 0.92, 0.256), K.surface("plastic", 0.2, Color(0.12, 0.12, 0.12)), "PCFloppySlot")
	K.slab(case_root, Vector3(0.2, 0.05, 0.012), Vector3(0.06, 0.92, 0.251), bay, "PCCdBay")
	K.slab(case_root, Vector3(0.02, 0.012, 0.014), Vector3(0.27, 0.92, 0.256), K.surface("plastic", 0.2, Color(0.2, 0.85, 0.3)), "PCPowerLed")
	K.slab(case_root, Vector3(0.05, 0.035, 0.016), Vector3(0.27, 0.885, 0.256), K.surface("plastic", 0.2, Color(0.6, 0.56, 0.48)), "PCPowerButton")
	K.slab(pc_root, Vector3(0.56, 0.03, 0.19), Vector3(0.26, 0.837, -1.0), plastic, "Keyboard")
	_face(pc_root, "keyboard", Vector2(0.54, 0.17), Vector3(0.26, 0.853, -1.0), 0.0, true)
	K.slab(pc_root, Vector3(0.06, 0.026, 0.10), Vector3(0.74, 0.835, -1.0), plastic, "Mouse")
	K.slab(pc_root, Vector3(0.22, 0.004, 0.19), Vector3(0.74, 0.822, -1.0), K.surface("blanket_grey", 0.4, Color(0.25, 0.3, 0.45)), "MousePad")
	# Cables
	_add_cable_polyline(
		pc_root,
		"PCCableMonitorToTower",
		PackedVector3Array([
			Vector3(0.24, 1.18, -1.84),
			Vector3(0.30, 1.0, -1.86),
			Vector3(0.36, 0.92, -1.76)
		]),
		0.010,
		Color(0.66, 0.68, 0.70)
	)
	_add_cable_polyline(
		pc_root,
		"PCCableKeyboardToTower",
		PackedVector3Array([
			Vector3(0.48, 0.87, -1.10),
			Vector3(0.52, 0.86, -1.2),
			Vector3(0.5, 0.88, -1.3)
		]),
		0.008,
		Color(0.70, 0.70, 0.72)
	)
	_add_cable_polyline(
		pc_root,
		"PCCableMouse",
		PackedVector3Array([
			Vector3(0.70, 0.87, -1.08),
			Vector3(0.66, 0.86, -1.2),
			Vector3(0.56, 0.88, -1.3)
		]),
		0.007,
		Color(0.74, 0.74, 0.76)
	)

	# ── DESK FAN (shifted right +0.5) ─────────────────────────────────────────
	_add_box(pc_root, "FanBase", Vector3(1.12, 0.86, -1.54), Vector3(0.14, 0.04, 0.14), Color(0.62, 0.60, 0.52))
	_add_box(pc_root, "FanStem", Vector3(1.12, 0.94, -1.54), Vector3(0.04, 0.14, 0.04), Color(0.56, 0.54, 0.48))
	_add_box(pc_root, "FanCage", Vector3(1.12, 1.06, -1.54), Vector3(0.22, 0.22, 0.10), Color(0.54, 0.52, 0.44))
	# Spinning blade pivot
	_fan_pivot = Node3D.new()
	_fan_pivot.name = "FanBladePivot"
	_fan_pivot.position = Vector3(1.12, 1.06, -1.52)
	pc_root.add_child(_fan_pivot)
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
	_add_box(pc_root, "RadioBody",    Vector3(-0.10, 0.88, -1.54), Vector3(0.26, 0.14, 0.12), Color(0.58, 0.54, 0.46))
	_add_box(pc_root, "RadioSpeaker", Vector3(-0.10, 0.88, -1.48), Vector3(0.10, 0.08, 0.02), Color(0.26, 0.24, 0.20))
	_add_box(pc_root, "RadioDial",    Vector3(-0.01, 0.90, -1.48), Vector3(0.06, 0.04, 0.02), Color(0.20, 0.36, 0.60))
	_add_box(pc_root, "RadioAntenna", Vector3(-0.03, 0.98, -1.54), Vector3(0.02, 0.22, 0.02), Color(0.66, 0.64, 0.54))

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
	_add_box(_room_root, "ShelfA",   Vector3(2.24, 1.84, -1.02), Vector3(0.28, 0.04, 0.74), Color(0.44, 0.30, 0.18))
	_add_box(_room_root, "ShelfB",   Vector3(2.24, 2.22, -1.02), Vector3(0.28, 0.04, 0.74), Color(0.44, 0.30, 0.18))
	_add_box(_room_root, "BinderA",  Vector3(2.24, 1.96, -0.70), Vector3(0.20, 0.22, 0.06), Color(0.28, 0.18, 0.52))
	_add_box(_room_root, "BinderB",  Vector3(2.24, 1.96, -0.92), Vector3(0.20, 0.22, 0.06), Color(0.52, 0.18, 0.18))
	_add_box(_room_root, "BinderC",  Vector3(2.24, 1.96, -1.12), Vector3(0.20, 0.22, 0.06), Color(0.18, 0.36, 0.18))
	_add_box(_room_root, "ShelfBook",Vector3(2.24, 2.32, -1.18), Vector3(0.20, 0.20, 0.08), Color(0.62, 0.50, 0.26))

	# ── THE COUNTER: across the room in front of you, the guests on the far side;
	# its left end steps down to the PC desk, its right end leaves a gap to the wall.
	_add_box(_room_root, "Counter",    Vector3(0.56, 0.45, 0.20), Vector3(2.08, 0.90, 0.60), Color(0.40, 0.28, 0.16))
	_add_box(_room_root, "CounterTop", Vector3(0.56, 0.93, 0.18), Vector3(2.20, 0.06, 0.74), Color(0.56, 0.42, 0.28), true)
	_add_box(_room_root, "CounterKick", Vector3(0.56, 0.06, -0.12), Vector3(2.08, 0.12, 0.04), Color(0.22, 0.14, 0.08))
	_add_box(_room_root, "CounterPaper1", Vector3(0.40, 0.965, 0.40), Vector3(0.24, 0.008, 0.18), Color(0.86, 0.84, 0.76))
	# The bench by the window for whoever waits second.
	_add_box(_room_root, "WaitBench", Vector3(-1.05, 0.44, -2.18), Vector3(1.3, 0.06, 0.36), Color(0.44, 0.30, 0.18))
	_add_box(_room_root, "WaitBenchLegL", Vector3(-1.6, 0.21, -2.18), Vector3(0.06, 0.42, 0.30), Color(0.30, 0.20, 0.12))
	_add_box(_room_root, "WaitBenchLegR", Vector3(-0.5, 0.21, -2.18), Vector3(0.06, 0.42, 0.30), Color(0.30, 0.20, 0.12))
	_add_box(_room_root, "CounterPhone",  Vector3(1.20, 1.00, 0.36), Vector3(0.36, 0.10, 0.24), Color(0.68, 0.64, 0.54))
	_add_box(_room_root, "CounterPhoneHandle", Vector3(1.20, 1.08, 0.36), Vector3(0.30, 0.06, 0.10), Color(0.70, 0.66, 0.56))
	_create_reception_notebook()

	# ── DOOR (left wall) ──────────────────────────────────────────────────────
	_add_box(_room_root, "DoorFrame",  Vector3(-2.48, 1.10, 1.28), Vector3(0.06, 2.20, 1.12), Color(0.20, 0.14, 0.10))
	_add_box(_room_root, "DoorLeaf",   Vector3(-2.43, 1.05, 1.28), Vector3(0.06, 2.02, 0.98), Color(0.32, 0.22, 0.14))
	_add_box(_room_root, "DoorHandle", Vector3(-2.36, 0.92, 0.84), Vector3(0.04, 0.06, 0.08), Color(0.74, 0.62, 0.40))

	# ── PROPS AND PICTURES (tools/blender, assets/textury/camp) ───────────────
	K.prop(_room_root, "filing_cabinet", Vector3(2.2, 0.05, -1.1), -90.0)
	# The key board on the wall to your right, behind the counter.
	K.picture(_room_root, "key_rack", Vector2(0.72, 0.405), Vector3(2.47, 1.52, 0.95), -90.0, "KeyRack")
	K.picture(_room_root, "poster_mushrooms", Vector2(0.44, 0.58), Vector3(-2.47, 1.56, -0.9), 90.0, "PosterA")

	K.picture(_room_root, "picture_deer", Vector2(0.48, 0.64), Vector3(-1.26, 1.56, 2.47), 180.0, "PosterC")
	K.slab(_room_root, Vector3(1.6, 0.012, 1.1), Vector3(0.3, 0.056, -1.35), K.surface("rug", 1.6), "Rug")

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

	_extras = RECEPTION_EXTRAS.new()
	_extras.build(self, _room_root, _interior_camera)
	_office_curtain = _extras.office_curtain
	# The back room's window view, now that the back room is there.
	if _extras.back != null and _extras.back.window_quad != null:
		var bm := _make_portal("BackWindowView", BACK_VIEW_SIZE)
		_back_vp = bm[0]
		_back_cam = bm[1]
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.albedo_texture = _back_vp.get_texture()
		qm.albedo_color = Color(0.95, 0.96, 0.95)
		_extras.back.window_quad.material_override = qm
	_desk_room = DESK_ROOM.new()
	_desk_room.build(self, _extras, _room_root)


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
	# The container stretches the viewport (stretch_shrink from RetroRender): setting the
	# size by hand only warned and was ignored.
	if _viewport_container != null and _viewport_container.stretch:
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


## `instant`: a new game starts already seated, the monitor filling the view from the
## first frame (no fly-in from the room view).
func enter_crt_view(instant: bool = false) -> void:
	if _crt_active: return
	# Sitting down at it wakes the screen saver, as touching the mouse would.
	if _crt_ui != null and _crt_ui.has_method("extras") and _crt_ui.extras() != null:
		_crt_ui.extras().poke()
	_reset_crt_look_back_state()
	_crt_active = true
	_look.reset()
	_crt_orbit_enabled = true
	_sync_crt_viewport_to_window()
	_set_crt_viewport_live(true)

	if _camera_tween: _camera_tween.kill()
	if instant:
		_interior_camera.position = _crt_full_cam_pos
		_interior_camera.rotation = _crt_rest_rot(_crt_full_cam_pos)
		_interior_camera.fov = CRT_READY_FOV
		_capture_crt_orbit_anchor()
		if _crt_ui:
			_crt_ui.open_panel()
		return
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.set_trans(Tween.TRANS_CUBIC)

	# Target: Front of CRT (approx dist 0.5m so screen fits nice)
	# Screen Z global: -0.535.
	# Target Z: 0.1
	_crt_orbit_enabled = false
	_camera_tween.tween_property(_interior_camera, "position", _crt_view_cam_pos, 1.2)
	_camera_tween.tween_property(_interior_camera, "rotation", _crt_rest_rot(_crt_view_cam_pos), 1.2)
	_camera_tween.tween_property(_interior_camera, "fov", CRT_ENTER_FOV, 1.2)
	_camera_tween.finished.connect(func():
		if not _crt_active:
			return
		_capture_crt_orbit_anchor()
		_crt_orbit_enabled = true
	)

	if _crt_ui:
		_crt_ui.open_panel()


func _exit_crt_view() -> void:
	if not _crt_active: return
	_crt_leaning = false
	_crt_active = false
	_crt_orbit_enabled = false
	_reset_crt_look_back_state()
	# The OS hides the system cursor while you use it (it draws its own); standing up
	# gives the room its cursor back (and open_panel hides it again when you sit down).
	if _crt_ui != null and _crt_ui.has_method("close_panel"):
		_crt_ui.close_panel()

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
	# The close-ups, the sleep and the walk through the door handle their own input.
	if _extras != null and _extras.is_modal():
		return
	if _desk_room != null and _desk_room.is_open():
		return

	# Esc is the pause menu's (main), here as everywhere.
	if event.is_action_pressed("ui_cancel"):
		return

	if _crt_active:
		# The pointer pushed down past the monitor: the band to stand up by.
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
				and _crt_stand_zone():
			_exit_crt_view()
			get_viewport().set_input_as_handled()
			return
		# At the keyboard: whatever you touch wakes the screen saver, even with the
		# pointer off the screen.
		if (event is InputEventMouseMotion or event is InputEventKey or event is InputEventMouseButton) and _crt_ui != null and _crt_ui.has_method("extras") and _crt_ui.extras() != null:
			var was_saving: bool = _crt_ui.extras().is_saving()
			_crt_ui.extras().poke()
			# The click that wakes it does nothing else.
			if was_saving and (event is InputEventMouseButton or event is InputEventKey):
				get_viewport().set_input_as_handled()
				return
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
			# Not typing into the machine: S stands you up, D (held) leans you out to
			# look through the office window.
			if not _crt_typing():
				if key_event.physical_keycode == KEY_S and key_event.pressed and not key_event.echo:
					_crt_lean(false, true)
					_exit_crt_view()
					get_viewport().set_input_as_handled()
					return
				if key_event.physical_keycode == KEY_D:
					if not key_event.echo:
						_crt_lean(key_event.pressed)
					get_viewport().set_input_as_handled()
					return
			# The keyboard under your fingers: a clack per key (the shell's own sound).
			if key_event.pressed and not key_event.echo and _crt_ui != null and _crt_ui.has_method("play"):
				_crt_ui.play("key", randf_range(-17.0, -13.0))
			_crt_viewport.push_input(key_event, true)
			get_viewport().set_input_as_handled()
			return

	if INTERIOR_LOOK.is_exit_event(event, get_viewport()):
		if _extras == null or not _extras.handle_exit():
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
		if _extras != null and _extras.click():
			get_viewport().set_input_as_handled()
			return
		if _extras != null and _extras.in_back_room():
			get_viewport().set_input_as_handled()
			return
		if _try_click_room(mouse_event):
			get_viewport().set_input_as_handled()
			return
		_try_click_crt(mouse_event)
		get_viewport().set_input_as_handled()


## Someone is typing into the machine (a text field has the focus): keys are letters.
func _crt_typing() -> bool:
	if _crt_viewport == null:
		return false
	var f := _crt_viewport.gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


## The seated pose looking straight at the screen from `pos` (what the mouse orbit keeps
## at its centre).
func _crt_rest_rot(pos: Vector3) -> Vector3:
	var pivot := _get_crt_orbit_pivot()
	if _room_root != null and _interior_camera != null and _interior_camera.get_parent() is Node3D:
		pivot = (_interior_camera.get_parent() as Node3D).to_local(pivot)
	if pos.distance_to(pivot) < 0.01:
		return CRT_SEAT_ROT
	return Transform3D(Basis(), pos).looking_at(pivot, Vector3.UP).basis.get_euler()


var _crt_leaning := false


## D at the PC: lean out to the right, past the monitor, and look out of the office
## window; let go and you are back at the screen.
func _crt_lean(on: bool, instant := false) -> void:
	if on == _crt_leaning or not _crt_active or _interior_camera == null:
		return
	_crt_leaning = on
	_crt_orbit_enabled = false
	if _camera_tween != null:
		_camera_tween.kill()
	if instant:
		return
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	if on:
		var pos := _crt_full_cam_pos + Vector3(0.46, 0.08, -0.12)
		var rot := Transform3D(Basis(), pos).looking_at(WINDOW_CENTER + Vector3(0, -0.12, 0), Vector3.UP).basis.get_euler()
		_camera_tween.tween_property(_interior_camera, "position", pos, 0.55)
		_camera_tween.tween_property(_interior_camera, "rotation", rot, 0.55)
		_camera_tween.tween_property(_interior_camera, "fov", 44.0, 0.55)
	else:
		_camera_tween.tween_property(_interior_camera, "position", _crt_full_cam_pos, 0.45)
		_camera_tween.tween_property(_interior_camera, "rotation", _crt_rest_rot(_crt_full_cam_pos), 0.45)
		_camera_tween.tween_property(_interior_camera, "fov", CRT_READY_FOV, 0.45)
		_camera_tween.finished.connect(func():
			if not _crt_active or _crt_leaning:
				return
			_capture_crt_orbit_anchor()
			_crt_orbit_enabled = true
		)


## At the PC: the pointer below the monitor, in the bottom band (the OS cursor stops at
## the screen's edge, the real one goes on): clicking there stands you up.
## A point in front of the monitor (PC-corner space, as it was made facing straight
## ahead) turned with it: room space.
func _crt_seat(p: Vector3) -> Vector3:
	return PC_OFFSET + CRT_PIVOT + (p - CRT_PIVOT).rotated(Vector3.UP, deg_to_rad(CRT_YAW_DEG))


func _crt_stand_zone() -> bool:
	if not _crt_active or _is_camera_tween_running() or _crt_look_back_active:
		return false
	var vp := get_viewport()
	if not INTERIOR_LOOK.in_exit_zone(vp):
		return false
	return _map_mouse_to_crt(vp.get_mouse_position(), false) == Vector2.INF


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


## The monitor, crisp: the whole game (this room included) is drawn small and scaled up
## for the chunky look, which smears the computer's text. So the OS picture is drawn a
## second time in the full-resolution window (a layer just under the HUD), laid exactly
## over the 3D screen: its four corners projected through the room camera and scaled
## from the small render to the window. The tube around it stays chunky.
func _ensure_crt_sharp() -> void:
	if _crt_sharp != null and is_instance_valid(_crt_sharp):
		return
	_crt_sharp_layer = CanvasLayer.new()
	_crt_sharp_layer.name = "CrtSharpLayer"
	_crt_sharp_layer.layer = 64
	get_tree().root.add_child(_crt_sharp_layer)
	_crt_sharp = Control.new()
	_crt_sharp.name = "CrtSharp"
	_crt_sharp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_sharp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt_sharp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crt_sharp.draw.connect(_draw_crt_sharp)
	var gx := CRT_SHARP_GRID.x
	var gy := CRT_SHARP_GRID.y
	_crt_sharp_pts.resize((gx + 1) * (gy + 1))
	_crt_sharp_uvs.resize((gx + 1) * (gy + 1))
	_crt_sharp_cols.resize((gx + 1) * (gy + 1))
	_crt_sharp_cols.fill(Color.WHITE)
	for j in gy + 1:
		for i in gx + 1:
			_crt_sharp_uvs[j * (gx + 1) + i] = Vector2(float(i) / gx, float(j) / gy)
	for j in gy:
		for i in gx:
			var a := j * (gx + 1) + i
			_crt_sharp_idx.append_array(PackedInt32Array([a, a + 1, a + gx + 1, a + 1, a + gx + 2, a + gx + 1]))
	var sharp_mat := ShaderMaterial.new()
	sharp_mat.shader = load("res://materials/crt_sharp.gdshader")
	_crt_sharp.material = sharp_mat
	_crt_sharp.visible = false
	_crt_sharp_layer.add_child(_crt_sharp)


func _update_crt_sharp() -> void:
	var show := visible and is_inside_tree() and _crt_active and _crt_screen != null and _crt_viewport != null and _interior_camera != null and _viewport != null
	if not show:
		if _crt_sharp != null and is_instance_valid(_crt_sharp):
			_crt_sharp.visible = false
		return
	_ensure_crt_sharp()
	# The OS picture laid on the tube as the tube really lies in view: every grid point
	# of the bulged glass (as crt_glass.gdshader pushes it out) through the room camera,
	# scaled from the small render to the window. A rectangle round the corners did not
	# follow the perspective and the desktop spilled past the glass at the sides
	# (playtest 2026-10-17: "the start menu and taskbar are all scattered").
	var quad := _crt_screen.mesh as QuadMesh
	var window := get_tree().root.get_visible_rect().size
	var render := _interior_camera.get_viewport().get_visible_rect().size
	var xf := _crt_screen.global_transform
	var gx := CRT_SHARP_GRID.x
	var lo_y := INF
	var hi_y := -INF
	for k in _crt_sharp_uvs.size():
		var uv: Vector2 = _crt_sharp_uvs[k]
		var q := (uv - Vector2(0.5, 0.5)) * 2.0
		var w := 1.0 - clampf(q.dot(q) * 0.5, 0.0, 1.0)
		var world := xf * Vector3((uv.x - 0.5) * quad.size.x, (0.5 - uv.y) * quad.size.y, CRT_BULGE * w)
		if _interior_camera.is_position_behind(world):
			_crt_sharp.visible = false
			return
		var pt := _interior_camera.unproject_position(world) / render * window
		_crt_sharp_pts[k] = pt
		lo_y = minf(lo_y, pt.y)
		hi_y = maxf(hi_y, pt.y)
	# Fade in as the monitor fills the view (sharp when you are at it).
	var fill := (hi_y - lo_y) / maxf(1.0, window.y)
	(_crt_sharp.material as ShaderMaterial).set_shader_parameter("fade", clampf((fill - 0.18) / 0.22, 0.0, 1.0))
	_crt_sharp.visible = true
	_crt_sharp.queue_redraw()


func _draw_crt_sharp() -> void:
	if _crt_viewport == null or _crt_sharp_idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(_crt_sharp.get_canvas_item(), _crt_sharp_idx, _crt_sharp_pts, _crt_sharp_cols, _crt_sharp_uvs, PackedInt32Array(), PackedFloat32Array(), _crt_viewport.get_texture().get_rid())


func _exit_tree() -> void:
	if _crt_sharp_layer != null and is_instance_valid(_crt_sharp_layer):
		_crt_sharp_layer.queue_free()


## Shot driver: a point on the OS screen (CRT viewport pixels) to the game window, through
## the curved glass (inverts the barrel by a few steps of fixed-point iteration).
func debug_crt_to_window(p: Vector2) -> Vector2:
	if _crt_sharp == null or _crt_sharp_pts.is_empty():
		return Vector2(-1, -1)
	var target := p / Vector2(CRT_RESOLUTION)
	var g := target
	for i in 8:
		g += target - _crt_barrel(g)
	# Bilinear on the projected grid.
	var gx := CRT_SHARP_GRID.x
	var gy := CRT_SHARP_GRID.y
	var fx := clampf(g.x * gx, 0.0, gx - 0.001)
	var fy := clampf(g.y * gy, 0.0, gy - 0.001)
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	var a: Vector2 = _crt_sharp_pts[iy * (gx + 1) + ix]
	var b: Vector2 = _crt_sharp_pts[iy * (gx + 1) + ix + 1]
	var c: Vector2 = _crt_sharp_pts[(iy + 1) * (gx + 1) + ix]
	var d: Vector2 = _crt_sharp_pts[(iy + 1) * (gx + 1) + ix + 1]
	return a.lerp(b, tx).lerp(c.lerp(d, tx), ty)


## The glass point (0..1) to the picture point: the barrel the tube shaders draw with.
static func _crt_barrel(uv: Vector2) -> Vector2:
	var c := uv - Vector2(0.5, 0.5)
	var d := c.dot(c)
	return Vector2(0.5, 0.5) + c * (1.0 + CRT_CURVE * d) / (1.0 + CRT_CURVE * 0.25)


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
				var uv := _crt_barrel(Vector2((local_hit.x / quad.size.x) + 0.5, 0.5 - (local_hit.y / quad.size.y)))
				if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
					return Vector2.INF if not allow_fallback else Vector2(clampf(uv.x, 0.0, 1.0) * vp_size.x, clampf(uv.y, 0.0, 1.0) * vp_size.y)
				return Vector2(uv.x * vp_size.x, uv.y * vp_size.y)

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
	# The desktop is up: lean in to it, slowly, to the pose the mouse orbit keeps (it used
	# to snap there in 0.4 s to a fixed angle the orbit then pulled away from: a jerk).
	_crt_orbit_enabled = false
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_property(_interior_camera, "position", _crt_full_cam_pos, 1.1)
	_camera_tween.tween_property(_interior_camera, "rotation", _crt_rest_rot(_crt_full_cam_pos), 1.1)
	_camera_tween.tween_property(_interior_camera, "fov", CRT_READY_FOV, 1.1)
	_camera_tween.finished.connect(func():
		if not _crt_active:
			return
		_capture_crt_orbit_anchor()
		_crt_orbit_enabled = true
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
		_room_environment.ambient_light_energy = _tri(d, 0.05, 0.62, 1.42)
		_room_environment.fog_light_color = _tri(d, Color(0.14, 0.18, 0.24), Color(0.34, 0.28, 0.30), Color(0.78, 0.82, 0.84))
		_room_environment.fog_density = _tri(d, 0.014, 0.010, 0.004)
	if _ceiling_light != null:
		_ceiling_light.light_color = _tri(d, Color(0.66, 0.72, 0.90), Color(0.92, 0.76, 0.64), Color(1.0, 0.96, 0.86))
		_ceiling_light.light_energy = _tri(d, 0.08, 0.88, 1.88)
	if _desk_lamp != null:
		_desk_lamp.light_energy = _tri(d, 0.9, 0.8, 0.7)
		_desk_lamp.light_color = Color(1.0, 0.86, 0.6)
		_desk_lamp.omni_range = 2.8
	if _window_light != null:
		_window_light.light_color = _tri(d, Color(0.54, 0.60, 0.84), Color(0.84, 0.66, 0.54), Color(0.98, 0.98, 0.92))
		_window_light.light_energy = _tri(d, 0.01, 0.34, 1.1)

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
	# Daylight through the window: a beam from outside (the cross of the window in it),
	# as strong as the day and as wide as the curtains are open.
	if _sun_beam != null:
		var open: float = _office_curtain.open if _office_curtain != null else 1.0
		_sun_beam.light_color = _sunlight_color.lerp(Color(1.0, 0.97, 0.9), 0.4)
		_sun_beam.light_energy = 3.2 * daylight * daylight * lerpf(0.06, 1.0, open)
	if _room_environment != null and _office_curtain != null:
		_room_environment.ambient_light_energy *= lerpf(0.55, 1.0, _office_curtain.open) if daylight > 0.3 else 1.0
	_sync_reception_glass()
	_apply_manual_office_light_profile(animated)
	_update_window_texture()


## The window is a portal into the real camp (playtest 2026-10-17: "it looks like a
## monitor with a camera feed"). The office room sits in its own little world; the camp
## is outside it. The room is laid over the reception building in the camp (its front
## wall on the building's front, the window just outside the facade), and every frame a
## camera in the camp stands where your eye would be on that overlay, looking straight
## out through the window, with an off-axis frustum whose near plane is exactly the
## window's rectangle. What it renders, put on the window quad, is what you would see
## through glass from where you stand: parallax as you lean, the guests walking up to
## the door, the lamps at night.
const WINDOW_CENTER := Vector3(-0.4, 1.68, -2.51)
const ROOM_DOOR_X := 1.72
const WINDOW_SIZE := Vector2(1.86, 1.38)
const WINDOW_VIEW_SIZE := Vector2i(496, 368)
var _window_vp: SubViewport
var _window_cam: Camera3D
## Room space -> camp space: basis (the room's axes in the camp) and origin.
var _portal_xform := Transform3D.IDENTITY
var _portal_ok := false


func _setup_window_view() -> void:
	if _window_vp != null:
		return
	var made := _make_portal("WindowView", WINDOW_VIEW_SIZE)
	_window_vp = made[0]
	_window_cam = made[1]
	for n in ["OutdoorGround", "OutdoorCeiling", "OutdoorWallL", "OutdoorWallR", "OutdoorBushL", "OutdoorBushR", "OutdoorBushR2", "OutdoorGravelStrip0", "OutdoorGravelStrip1", "OutdoorGravelStrip2", "OutdoorSkyBg"]:
		var node := _room_root.get_node_or_null(n)
		if node != null:
			node.visible = false


## A window's view: its own viewport into the camp's world (given by hand: this room is
## not inside the world's viewport) and an off-axis camera that does not see the window
## glass of the building it stands in (building_models.GLASS_LAYER).
func _make_portal(n: String, px: Vector2i) -> Array:
	var vp := SubViewport.new()
	vp.name = n
	vp.size = px
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.cull_mask = 0xFFFFF & ~(1 << 19)
	vp.add_child(cam)
	_bind_window_world(vp)
	return [vp, cam]


func _bind_window_world(vp: SubViewport = null) -> void:
	for v in ([vp] if vp != null else [_window_vp, _back_vp]):
		if v == null:
			continue
		var main := _resolve_main_runtime_host()
		var w3d = main.get("_world_3d") if main != null else null
		if w3d is Node3D and (w3d as Node3D).is_inside_tree():
			(v as SubViewport).world_3d = (w3d as Node3D).get_world_3d()


## The back room's window (ReceptionLayout.BACK_WINDOW_*): out over the gate lane.
const BACK_VIEW_SIZE := Vector2i(320, 288)
var _back_vp: SubViewport
var _back_cam: Camera3D


## The window's own frame in room space: origin at its middle, -Z out through it.
static func _portal_frame(center: Vector3, outward: Vector3) -> Transform3D:
	var z := -outward.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), center)


## Puts a window's camera where the eye is, mapped into the camp, the window its near plane.
func _aim_portal(cam: Camera3D, frame: Transform3D, size: Vector2, eye_room: Vector3) -> bool:
	var e := frame.affine_inverse() * eye_room
	if e.z < 0.05:
		return false
	cam.global_transform = Transform3D(_portal_xform.basis * frame.basis, _portal_xform * eye_room)
	cam.set_frustum(size.y, Vector2(-e.x, -e.y), e.z, e.z + 260.0)
	return true


## Where the room lies in the camp: over the reception building, its window wall on the
## building's front (the side with the door, the camp side).
func _place_window_camera() -> bool:
	if _window_cam == null:
		return false
	if _window_vp != null and _window_vp.world_3d == null:
		_bind_window_world()
	var scene := get_tree().current_scene if get_tree() != null else null
	var reception: Node3D = scene.find_child("MainBuilding", true, false) as Node3D if scene != null else null
	if reception == null:
		return false
	# The building is made from the rooms' plan: the room lies in it exactly.
	var shell := reception.get_node_or_null("Shell") as Node3D
	if shell != null:
		_portal_xform = shell.global_transform * RL.room_to_local()
		_portal_ok = true
		_update_window_portal()
		return true
	var base := reception.global_position
	var door: Vector3 = scene.call("get_reception_door_position") if scene.has_method("get_reception_door_position") else Vector3.INF
	var front := (door - base) if door != Vector3.INF else Vector3(0, 0, 1)
	front.y = 0.0
	front = front.normalized() if front.length() > 0.1 else Vector3(0, 0, 1)
	# How far the facade is from the middle of the building.
	var half_depth := 3.6
	for c in reception.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var bs := ((c as CollisionShape3D).shape as BoxShape3D).size
			half_depth = absf(front.x) * bs.x * 0.5 + absf(front.z) * bs.z * 0.5
			break
	# The room's -Z (out of the window) is the building's front; up is up.
	var z_axis := -front
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	var basis := Basis(x_axis, Vector3.UP, z_axis)
	var ground := Vector3(base.x, 0.0, base.z)
	# The window's plane a hand outside the facade, so the building itself is behind it.
	var origin := ground + front * (half_depth + 0.06) - basis * Vector3(0, 0, WINDOW_CENTER.z)
	# Sideways: the room's front door (x = 1.72) on the building's door, so the window
	# looks past the porch, not into it.
	if door != Vector3.INF:
		var lateral := (door - base).dot(x_axis)
		origin += x_axis * (lateral - ROOM_DOOR_X)
	_portal_xform = Transform3D(basis, origin)
	_portal_ok = true
	_update_window_portal()
	return true


## Every frame while the room is open: the eye moved (looking about, walking to the PC).
func _update_window_portal() -> void:
	if not _portal_ok or _window_cam == null or _interior_camera == null:
		return
	var eye_room := _room_root.to_local(_interior_camera.global_position) if _room_root != null else _interior_camera.position
	var in_back: bool = _extras != null and (_extras.in_back_room() or _extras._walking())
	# Only the window you can see, and only while its curtains let anything through.
	var office_on: bool = not in_back or not _extras.in_back_room()
	if _office_curtain != null and _office_curtain.open < 0.02:
		office_on = false
	office_on = office_on and _aim_portal(_window_cam, _portal_frame(WINDOW_CENTER, Vector3(0, 0, -1)), WINDOW_SIZE, eye_room)
	_window_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if office_on else SubViewport.UPDATE_DISABLED
	if _back_cam != null:
		var back_on: bool = in_back
		var bc = _extras.back.curtain if _extras != null else null
		if bc != null and bc.open < 0.02:
			back_on = false
		back_on = back_on and _aim_portal(_back_cam, _portal_frame(RL.BACK_WINDOW_CENTER, Vector3(-1, 0, 0)), RL.BACK_WINDOW_SIZE, eye_room)
		_back_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if back_on else SubViewport.UPDATE_DISABLED


func _set_window_view_live(on: bool) -> void:
	if _window_vp == null:
		return
	if on and not _place_window_camera():
		on = false
	_window_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on and _back_vp != null:
		_back_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
			# The real view: old glass, a touch of the room's colour.
			mat.albedo_color = Color(0.96, 0.97, 0.96).lerp(glass_color, 0.08)
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


var _glass_cache: Dictionary = {}


## The office window and the back room's, seen from the camp: dark glass by day, the
## lamp-light at night when someone has the lights on, dimmer behind drawn curtains.
func _sync_reception_glass() -> void:
	if _glass_cache.is_empty() or not is_instance_valid(_glass_cache.get("office_glass")):
		var scene := get_tree().current_scene if is_inside_tree() else null
		var reception: Node = scene.find_child("MainBuilding", true, false) if scene != null else null
		if reception == null or not reception.has_meta("reception_glass"):
			return
		_glass_cache = reception.get_meta("reception_glass")
	# The time of day, not the daylight (that is only kept up while the room is open).
	var night := 1.0 if _time_state == TIME_NIGHT else (0.45 if _time_state == TIME_EVENING else 0.0)
	var power := 1.0 if _grid_power_available else 0.0
	var office_lit := (0.8 if _office_lights_on else 0.0) + (0.35 if _desk_lamp_on else 0.0)
	var office_open: float = _office_curtain.open if _office_curtain != null else 1.0
	_glow_glass(_glass_cache.get("office_glass"), night * power * office_lit * lerpf(0.45, 1.0, office_open))
	var back_lit := 0.0
	var back_open := 0.0
	if _extras != null and _extras.back != null:
		back_lit = (0.7 if _extras.back.lamp_on else 0.0) + (0.25 if _extras.back.tv_on else 0.0)
		back_open = _extras.back.curtain.open if _extras.back.curtain != null else 0.0
	_glow_glass(_glass_cache.get("back_glass"), night * power * back_lit * lerpf(0.3, 1.0, back_open))


static func _glow_glass(g, amount: float) -> void:
	if g == null or not is_instance_valid(g):
		return
	var m := (g as MeshInstance3D).material_override as StandardMaterial3D
	if m == null:
		return
	m.emission_energy_multiplier = 1.4 * amount
	m.albedo_color = Color(0.16, 0.2, 0.24).lerp(Color(0.5, 0.4, 0.26), clampf(amount, 0.0, 1.0))


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
	notebook_root.position = Vector3(-0.12, 0.965, 0.34)
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


## The green banker's lamp at the left end of the PC desk: click it (or the switch on
## its foot) and it goes off and on, with the click of the button.
const DESK_LAMP_AT := Vector3(-0.28, 0.82, -1.22)
var _desk_lamp_on := true
var _desk_lamp_shade: MeshInstance3D
var _desk_lamp_body: StaticBody3D


func _build_desk_lamp(pc_root: Node3D) -> void:
	var at := DESK_LAMP_AT
	_add_box(pc_root, "DeskLampFoot", at + Vector3(0, 0.015, 0), Vector3(0.2, 0.03, 0.14), Color(0.62, 0.5, 0.26))
	_add_box(pc_root, "DeskLampStem", at + Vector3(0, 0.17, 0.02), Vector3(0.025, 0.3, 0.025), Color(0.66, 0.54, 0.3))
	_add_box(pc_root, "DeskLampButton", at + Vector3(0.06, 0.04, -0.03), Vector3(0.03, 0.02, 0.03), Color(0.2, 0.18, 0.16))
	_add_box(pc_root, "DeskLampShade", at + Vector3(0, 0.33, 0.06), Vector3(0.3, 0.07, 0.15), Color(0.16, 0.42, 0.24))
	_desk_lamp_shade = pc_root.get_node_or_null("DeskLampShade") as MeshInstance3D
	# The brass lip under the shade, clear of its bottom face (they used to share it: flicker).
	_add_box(pc_root, "DeskLampShadeLip", at + Vector3(0, 0.284, 0.06), Vector3(0.32, 0.012, 0.17), Color(0.66, 0.54, 0.3))
	_desk_lamp_body = StaticBody3D.new()
	_desk_lamp_body.name = "DeskLampHot"
	_desk_lamp_body.set_meta("extra_hot", "desklamp")
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.34, 0.42, 0.24)
	cs.shape = bx
	_desk_lamp_body.add_child(cs)
	_desk_lamp_body.position = at + Vector3(0, 0.2, 0.03)
	pc_root.add_child(_desk_lamp_body)
	if _desk_lamp != null:
		_desk_lamp.position = PC_OFFSET + at + Vector3(0, 0.26, 0.12)


func desk_lamp_meshes() -> Array:
	var out: Array = []
	var pc := _room_root.get_node_or_null("PCCorner") if _room_root != null else null
	if pc != null:
		for n in ["DeskLampFoot", "DeskLampStem", "DeskLampShade", "DeskLampShadeLip", "DeskLampButton"]:
			var m := pc.get_node_or_null(n)
			if m != null:
				out.append(m)
	return out


func toggle_desk_lamp() -> void:
	_desk_lamp_on = not _desk_lamp_on
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/sfx/backroom/lamp_click.wav") if ResourceLoader.exists("res://assets/sfx/backroom/lamp_click.wav") else null
	p.volume_db = -6.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	if _desk_lamp_shade != null:
		var m := _desk_lamp_shade.material_override as StandardMaterial3D
		if m != null:
			m.emission_enabled = _desk_lamp_on
			m.emission = Color(0.25, 0.7, 0.35)
			m.emission_energy_multiplier = 0.35
	_apply_room_time_profile(true)


## The night director (scripts/night/director_effects.gd): a sound somewhere in the
## office's own space (the door, the window, the back room's wall), heard from the room.
func play_room_sound(path: String, room_pos: Vector3, db := 0.0) -> void:
	if _room_root == null or not ResourceLoader.exists(path):
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(path)
	s.volume_db = db
	s.unit_size = 3.5
	s.max_distance = 14.0
	_room_root.add_child(s)
	s.position = room_pos
	s.finished.connect(s.queue_free)
	s.play()


## The night director: the radio worse for a while (it hears something on the frequency).
func nudge_radio_dread(amount: float, seconds: float) -> void:
	if _dread != null and _dread.has_method("nudge"):
		_dread.nudge(amount, seconds)


## The night director: while you were out, something here changed. One thing, the most
## noticeable that is still as you left it; always one you can put back.
func disturb_office() -> String:
	# Sometimes a thing is not where it was: the cup on the PC desk is on the window sill.
	var pc := _room_root.get_node_or_null("PCCorner") if _room_root != null else null
	var cup := pc.get_node_or_null("DeskCup") as Node3D if pc != null else null
	if cup != null and not cup.has_meta("home") and randf() < 0.45:
		cup.set_meta("home", cup.position)
		cup.global_position = _room_root.to_global(Vector3(-0.9, 1.06, -2.38))
		return "cup"
	if _office_curtain != null and _office_curtain.is_open():
		_office_curtain.set_open(false, true)
		_apply_room_time_profile()
		return "curtain"
	if _office_lights_on:
		_toggle_office_lights()
		return "lights"
	if _radio_power_on:
		_toggle_radio_power()
		return "radio"
	if _desk_lamp_on:
		toggle_desk_lamp()
		return "lamp"
	return ""


## Dawn: what the night moved goes back where it was (the curtain, lights, radio and
## lamp are the player's to put back, and stay as they are).
func undo_disturbances() -> void:
	var pc := _room_root.get_node_or_null("PCCorner") if _room_root != null else null
	var cup := pc.get_node_or_null("DeskCup") as Node3D if pc != null else null
	if cup != null and cup.has_meta("home"):
		cup.position = cup.get_meta("home")
		cup.remove_meta("home")


## Looking out of the office window (from the counter, more or less straight at it).
func is_looking_at_window() -> bool:
	if not visible or _crt_active or _interior_camera == null or _room_root == null:
		return false
	if _extras != null and _extras.in_back_room():
		return false
	var eye := _room_root.to_local(_interior_camera.global_position)
	var fwd := _room_root.global_transform.basis.inverse() * (-_interior_camera.global_transform.basis.z)
	var to_win := (WINDOW_CENTER - eye).normalized()
	return fwd.normalized().dot(to_win) > 0.93


## Somebody rings the office (the night, a guest, ...): see reception_extras.start_incoming.
func ring_phone(call: Dictionary, rings := 8, done := Callable()) -> void:
	if _extras != null:
		_extras.start_incoming(call, rings, done)


var _bell_outdoor: AudioStreamPlayer3D


## The bell heard from the camp, through the walls.
func ring_outdoor() -> void:
	var building := _resolve_main_building_node()
	if building == null or not is_instance_valid(building):
		return
	if _bell_outdoor == null or not is_instance_valid(_bell_outdoor):
		_bell_outdoor = AudioStreamPlayer3D.new()
		_bell_outdoor.name = "PhoneBellOutdoor"
		_bell_outdoor.unit_size = 5.0
		_bell_outdoor.max_distance = 45.0
		_bell_outdoor.attenuation_filter_cutoff_hz = 2400.0
		_bell_outdoor.attenuation_filter_db = -12.0
		_bell_outdoor.volume_db = -6.0
		if ResourceLoader.exists("res://assets/sfx/phone/bell.mp3"):
			_bell_outdoor.stream = load("res://assets/sfx/phone/bell.mp3")
		building.add_child(_bell_outdoor)
	if visible:
		return
	_bell_outdoor.play()


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
	if not _desk_lamp_on:
		desk_target = 0.0
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
	if _dread == null:
		_dread = RADIO_DREAD_SCRIPT.new()
		_dread.name = "RadioDread"
		add_child(_dread)
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
	if _dread != null:
		_dread.bind_music(_radio_player)
		_dread.set_tracks(_radio_tracks_all)
	call_deferred("_play_radio_next")


func _create_radio_layer_player(player_name: String, pitch_scale: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = RADIO_DREAD_SCRIPT.MUSIC_BUS
	player.volume_db = RADIO_OUTSIDE_SILENT_DB
	player.pitch_scale = pitch_scale
	add_child(player)
	return player


## A new game opens with this song on the radio (playtest 2026-10-17).
const RADIO_FIRST_TRACK := "res://assets/sfx/radio/radiojedna.mp3"
var _radio_first_pending := false


## Main, at the start of a new game: the radio starts on RADIO_FIRST_TRACK.
func queue_first_radio_track() -> void:
	_radio_first_pending = true
	if _radio_player != null and is_instance_valid(_radio_player):
		_play_radio_next()


func _play_radio_next() -> void:
	if _radio_player == null:
		return
	if _radio_first_pending:
		_radio_first_pending = false
		var first: AudioStream = _radio_stream_by_path.get(RADIO_FIRST_TRACK, null)
		if first == null and ResourceLoader.exists(RADIO_FIRST_TRACK):
			first = load(RADIO_FIRST_TRACK)
		if first != null:
			_radio_current_track_is_night = false
			_radio_player.stream = first
			_radio_player.play()
			_radio_last_played_path = RADIO_FIRST_TRACK
			return
	if _try_play_station():
		return
	var interlude: AudioStream = _dread.take_interlude() if _dread != null else null
	if interlude != null:
		_radio_current_track_is_night = false
		_radio_last_played_path = ""
		_radio_player.stream = interlude
		_radio_player.play()
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
	if _dread != null:
		_dread.update(
			delta, _radio_dread_context(delta),
			target_db if visible else RADIO_OUTSIDE_SILENT_DB,
			RADIO_OUTSIDE_SILENT_DB if visible else RADIO_OUTDOOR_VOLUME_DB,
			_radio_power_on, _resolve_main_building_node()
		)
		character_db += linear_to_db(maxf(float(_dread.music_gain), 0.0001))
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
		_radio_outdoor.bus = RADIO_DREAD_SCRIPT.MUSIC_BUS
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
		var depth_scale: float = _dread.dropout_depth_scale() if _dread != null else 1.0
		return RADIO_DROPOUT_ATTENUATION_DB * depth_scale * envelope
	_radio_dropout_timer -= delta
	if _radio_dropout_timer <= 0.0:
		var interval_scale: float = _dread.dropout_interval_scale() if _dread != null else 1.0
		_radio_dropout_duration = _radio_rng.randf_range(RADIO_DROPOUT_DURATION_MIN, RADIO_DROPOUT_DURATION_MAX)
		_radio_dropout_remaining = _radio_dropout_duration
		_radio_dropout_timer = _radio_rng.randf_range(RADIO_DROPOUT_INTERVAL_MIN, RADIO_DROPOUT_INTERVAL_MAX) * interval_scale
	return 0.0


func _update_radio_character_pitch(delta: float) -> void:
	if _radio_player == null:
		return
	_radio_wow_phase = fmod(_radio_wow_phase + TAU * RADIO_WOW_RATE_HZ * delta, TAU)
	_radio_flutter_phase = fmod(_radio_flutter_phase + TAU * RADIO_FLUTTER_RATE_HZ * delta, TAU)
	var wobble: float = _dread.wobble_scale if _dread != null else 1.0
	var sag: float = _dread.pitch_offset if _dread != null else 0.0
	var wow = sin(_radio_wow_phase) * RADIO_WOW_DEPTH * wobble
	var flutter = (
		sin(_radio_flutter_phase) * RADIO_FLUTTER_DEPTH
		+ sin(_radio_flutter_phase * 1.93 + 0.82) * (RADIO_FLUTTER_DEPTH * 0.45)
	) * wobble
	_radio_player.pitch_scale = clampf(RADIO_PITCH_BASE + wow + flutter + sag, 0.72, 1.03)


## What the radio reads off the night: the NIGHT RISK lamps (re-read every few seconds),
## the clock, who is out tonight and how close the nearest of them is to the player.
func _radio_dread_context(delta: float) -> Dictionary:
	_dread_risk_poll -= delta
	if _dread_risk_poll <= 0.0:
		_dread_risk_poll = RADIO_DREAD_RISK_POLL_SEC
		var forecast = GuestManager.get_liminal_forecast_data() if GuestManager != null and GuestManager.has_method("get_liminal_forecast_data") else {}
		_dread_risk = clampf(float((forecast as Dictionary).get("hud_level", 0)) / 4.0, 0.0, 1.0) if forecast is Dictionary else 0.0
	var night := _time_state == TIME_NIGHT
	var main := _resolve_main_for_radio()
	var hours_any = main.get("_time_of_day_hours") if main != null else null
	var hours: float = float(hours_any) if hours_any != null else (1.0 if night else 12.0)
	var tonight: Array = []
	var nearest := INF
	var brains_any = main.get("_enemy_brains") if main != null else null
	if brains_any is Array:
		var listener := _resolve_radio_listener_position()
		for brain in brains_any:
			if brain == null or (brain is Object and not is_instance_valid(brain)):
				continue
			if brain.get("_night_active") == false:
				continue
			if brain.has_method("get_enemy_id"):
				tonight.append(str(brain.get_enemy_id()))
			if brain.has_method("get_presence") and is_finite(listener.x):
				var p: Dictionary = brain.get_presence()
				if p.has("position"):
					nearest = minf(nearest, listener.distance_to(p["position"]))
	return {
		"risk": _dread_risk,
		"hours": hours,
		"night": night,
		"day": int(CoreRoot.get_day()) if CoreRoot != null else 1,
		"tonight": tonight,
		"nearest": nearest,
		"guests": _count_guests_in_camp(),
	}


## Main is an ancestor (main > InteriorManager > here); the shot driver hosts Main
## below its own scene, so the current scene is not always it.
func _resolve_main_for_radio() -> Node:
	if _radio_main_ref != null and is_instance_valid(_radio_main_ref):
		return _radio_main_ref
	var n: Node = get_parent()
	while n != null:
		if n.get("_enemy_brains") != null:
			_radio_main_ref = n
			return n
		n = n.get_parent()
	return get_tree().current_scene if get_tree() != null else null


## Debug/screenshot entry: pin the radio's dread (-1 lets the night decide again).
func debug_set_radio_dread(value: float) -> void:
	if _dread != null:
		_dread.debug_override = value


func get_radio_dread() -> float:
	return float(_dread.dread) if _dread != null else 0.0


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
	if _node_has_click_type(collider, "reception_notebook"):
		open_checkin_desk()
		return true
	return false


## The desk close-up: the register, the keys, whoever is at the counter.
func open_checkin_desk() -> void:
	if _desk_room != null:
		_desk_room.open()


func is_desk_open() -> bool:
	return _desk_room != null and _desk_room.is_open()


## How many who were not booked you let in (main hands it to the omens).
func desk_strangers_admitted() -> int:
	return int(_desk_room.admitted) if _desk_room != null else 0


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
	var world = _viewport.find_world_3d()
	if world == null:
		return {}
	var local_mouse = _to_interior_viewport_pos(mouse_pos)
	var ray_origin = _interior_camera.project_ray_origin(local_mouse)
	var ray_dir = _interior_camera.project_ray_normal(local_mouse)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_dir * 24.0))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_ray(query)


## Tools: what a click on this point of the room (room coordinates) would hit.
func debug_hit_at(room_point: Vector3) -> String:
	var vp_pos := _interior_camera.unproject_position(_room_root.to_global(room_point))
	var ray_origin = _interior_camera.project_ray_origin(vp_pos)
	var ray_dir = _interior_camera.project_ray_normal(vp_pos)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_dir * 24.0))
	var hit: Dictionary = _viewport.find_world_3d().direct_space_state.intersect_ray(query)
	var n = hit.get("collider", null) as Node
	return str(n.get_path()) if n != null else "-"


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
	var spec = RECEPTION_EXACT.get(name_str, null)
	if spec == null:
		for prefix in RECEPTION_PREFIX.keys():
			if name_str.begins_with(prefix):
				spec = RECEPTION_PREFIX[prefix]
				break
	if spec is String:
		return
	if spec is Array:
		var kit_mesh := INTERIOR_KIT.slab(parent, size, pos, INTERIOR_KIT.surface(str(spec[0]), float(spec[1])), name_str)
		kit_mesh.material_override = (kit_mesh.material_override as StandardMaterial3D).duplicate()
		return
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = name_str
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	var uv_scale = Vector3(max(1.0, size.x * 1.5), 1.0, max(1.0, size.z * 1.5))
	var category = _category_for_node(name_str, color)
	# Small things not in the surface maps get their own flat colour (Build-style sprites
	# of a single shade) rather than a random texture from the old pack.
	var mat = _make_psx_material(color, 18.0, 5.0, 0.01, "plastic" if category != "office_wall" else category)
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


## The monitor, Build-engine style: a front slab carrying the painted bezel (buttons,
## lamp, the maker's plate), the body with its vents, the tube's back, the foot. The
## screen quad sits 5 mm in front of the bezel's black glass.
func _build_monitor_boxes() -> void:
	var K := INTERIOR_KIT
	var plastic := K.surface("plastic", 0.35)
	var vents := K.surface("monitor_side", 0.4) if ResourceLoader.exists("res://assets/textury/camp/monitor_side.png") else K.surface("monitor_back", 0.4)
	K.slab(_crt_body, Vector3(0.80, 0.60, 0.06), Vector3(0.0, 0.02, 0.32), plastic, "CRTFront")
	_face(_crt_body, "monitor_front", Vector2(0.80, 0.60), Vector3(0.0, 0.02, 0.351), 0.0)
	K.slab(_crt_body, Vector3(0.72, 0.52, 0.34), Vector3(0.0, 0.02, 0.12), vents, "CRTBody")
	K.slab(_crt_body, Vector3(0.46, 0.36, 0.26), Vector3(0.0, 0.02, -0.18), vents, "CRTBack")
	K.slab(_crt_body, Vector3(0.18, 0.08, 0.20), Vector3(0.0, -0.32, 0.06), plastic, "CRTNeck")
	K.slab(_crt_body, Vector3(0.40, 0.04, 0.32), Vector3(0.0, -0.38, 0.06), plastic, "CRTFoot")
	_add_monitor_badge()


## A textured face (assets/textury/camp/<tex>.png) on a box: the Build way of detail.
func _face(parent: Node3D, tex: String, size: Vector2, pos: Vector3, yaw_deg: float, top := false) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	q.name = "Face_" + tex
	var qm := QuadMesh.new()
	qm.size = size
	if top:
		qm.orientation = PlaneMesh.FACE_Y
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	var path := "res://assets/textury/camp/%s.png" % tex
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	else:
		m.albedo_texture = load("res://assets/textury/camp/plastic.png") if ResourceLoader.exists("res://assets/textury/camp/plastic.png") else null
	q.material_override = m
	q.position = pos
	q.rotation_degrees.y = yaw_deg
	parent.add_child(q)
	return q


## The maker's badge under the screen: CAMPTRONICS in chrome letters on a dark plate.
func _add_monitor_badge() -> void:
	var tex_path := "res://assets/textury/camp/badge_camptronics.png"
	var q := MeshInstance3D.new()
	q.name = "MonitorBadge"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.15, 0.024)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
	else:
		m.albedo_color = Color(0.2, 0.2, 0.22)
	m.roughness = 0.4
	q.material_override = m
	q.position = Vector3(0.0, 0.02 - 0.19, 0.353)
	_crt_body.add_child(q)


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


## The torch comes on in here by itself when the room is dark (if it is on, F).
func _update_torch(delta: float) -> void:
	if _torch == null:
		_torch = INTERIOR_TORCH.new()
		_torch.name = "Torch"
		add_child(_torch)
		_torch.setup(_interior_camera, _viewport, _interior_camera.get_parent() as Node3D, layer)
	_torch.update(delta, room_is_dark())


## After dusk with the office light off or no power; not while you sit at the PC.
func room_is_dark() -> bool:
	return _time_state != TIME_DAY and not _crt_active and (not _office_lights_on or not _grid_power_available)
