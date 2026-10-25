extends CanvasLayer

const INTERIOR_BARREL_SHADER = preload("res://materials/interior_barrel_post.gdshader")
const ROOM_WEATHER = preload("res://scripts/ambient/room_weather.gd")
const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
## Reception surfaces by node name (exact names first, then prefixes): [camp texture,
## metres per repeat]. "" = not built (replaced by a prop or a picture, see _build_room).
const RECEPTION_EXACT := {
	"Floor": ["parquet", 0.9], "Ceiling": ["ceiling_pine", 0.9],
	"Desk": ["veneer_dark", 0.7], "DeskTop": ["veneer_dark", 0.7], "DeskDrawerA": ["veneer_dark", 0.5], "DeskDrawerB": ["veneer_dark", 0.5],
	"Counter": ["pub_panel", 1.0], "CounterTop": ["veneer_dark", 0.8],
	"ShelfA": ["knotty_pine", 0.5], "ShelfB": ["knotty_pine", 0.5],
	"BackDoorFrame": ["planks_dark", 0.6], "DoorFrame": ["planks_dark", 0.6],
	"BackDoorLeaf": ["door_wood", 2.04], "DoorLeaf": ["door_wood", 2.02],
	"WindowSill": ["knotty_pine", 0.5],
}
const RECEPTION_PREFIX := {
	"FloorTile": "", "FloorScatter": "", "FilingCab": "", "FilingDrawer": "", "FilingHandle": "",
	# Replaced by office_dressing.gd (Grok faces and sprites); the old pine trim was a
	# second, lower ceiling over the whole room.
	"CeilingTrim": "", "CeilingFixture": "", "Calendar": "", "Plant": "", "BackWallCoat": "",
	"BackWallHanger": "", "BackWallHook": "",
	"PosterFrame": "", "PosterPaper": "", "PosterTear": "", "PosterHang": "",
	"Wall": ["knotty_pine", 1.2], "WindowFrame": ["knotty_pine", 0.5], "WindowMullion": ["knotty_pine", 0.5],
}
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
## Camera moves in steps, twelve a second (sitting down, standing up, looking round).
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_TORCH = preload("res://scripts/ui/interior_torch.gd")
## Your torch, in here when it is dark: it shines where the cursor points.
var _torch: Node
const RECEPTION_EXTRAS = preload("res://scripts/reception/reception_extras.gd")
const OFFICE_DRESSING = preload("res://scripts/reception/office_dressing.gd")
var _dressing
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
## Outside, the radio is a positional source in the reception, heard through its walls:
## by the building a muffled tune (quieter than in the room, its highs gone), across the
## nearer field a faint one you can walk toward in the dark (the user 21. 10.: "by the
## reception you hear the radio from inside a little"). Muffled by the distance filter
## below and the radio's own bus (radio_dread: its night low-pass).
const RADIO_OUTDOOR_VOLUME_DB: float = -14.0
const RADIO_OUTDOOR_UNIT_SIZE: float = 3.0
const RADIO_OUTDOOR_MAX_DISTANCE: float = 40.0
const RADIO_OUTDOOR_HEIGHT: float = 1.4
const RADIO_OUTDOOR_FILTER_HZ: float = 1200.0
const RADIO_OUTDOOR_FILTER_DB: float = -24.0
const WORLD_SOUNDS := preload("res://scripts/ambient/world_sounds.gd")
## The station that does not exist (DESIGN §2): late at night, once at most, from day 2,
## the radio drifts onto a frequency with a music-box phrase and a row of pips. Count
## them: one for each guest in the camp, and one more.
const STATION_INTRO := "res://assets/sfx/uncanny/station_intro.mp3"
const STATION_PIP := "res://assets/sfx/uncanny/station_pip.mp3"
const STATION_PIP5 := "res://assets/sfx/uncanny/station_pip5.mp3"
const STATION_OUTRO := "res://assets/sfx/uncanny/station_outro.mp3"
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
## "Prani a pozdravy" opens with "it is just half past twelve": kept out of the shuffle, it
## is the station's programme from 0:30, on the clock: on air only for as long as it runs
## from 0:30 at the clock's pace, and tuned into mid-way at the point it has reached (the
## user 21. 10.: "it played in the morning sometimes; it must never be heard at any other
## time than it would be had it started at half past twelve"). Not after the night skip,
## not after a load, not from the start at one o'clock.
const RADIO_GREETINGS_FILENAME := "night_pranipozdravy.mp3"
const RADIO_GREETINGS_PATH := "res://assets/sfx/radio/night_pranipozdravy.mp3"
const RADIO_GREETINGS_HOUR := 0.5
## Off the end by this much it is over (no cutting back in for its last seconds).
const RADIO_GREETINGS_TAIL_SEC := 6.0
## Further than this from where the clock says, it is put back there.
const RADIO_GREETINGS_DRIFT_SEC := 3.0
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
const OFFICE_FOV := 68.0
const ENTRY_YAW_DEG := 36.0
const PC_OFFSET := Vector3(-1.94, 0.0, 1.68)
const RL = preload("res://scripts/reception/reception_layout.gd")
const CURTAIN = preload("res://scripts/reception/curtain.gd")
## The monitor turned a little toward where you stand at the counter (playtest
## 2026-10-17), about its own middle; the seat in front of it turns with it.
const CRT_YAW_DEG := 18.0
const CRT_PIVOT := Vector3(0.24, 1.35, -1.53)
const CRT_SEAT_ROT := Vector3(0.0, 0.3141593, 0.0)   # CRT_YAW_DEG in radians
## The second monitor (bought on the web, brought by the post: scripts/reception/
## post_delivery.gd): a used 15-inch on a stack of phone books right of the first, turned
## to the chair; the radio moves up on top of it. PC-corner space like CRT_PIVOT.
const MON2_PIVOT := Vector3(1.02, 1.335, -1.42)
const MON2_YAW_DEG := -17.0
const MON2_SCALE := 0.84
const POST_DELIVERY = preload("res://scripts/reception/post_delivery.gd")
const DESK_ROOM = preload("res://scripts/reception/desk_room.gd")
## The radio stands on the right end of the desk, clear of the monitor (its click box once
## lay over the monitor's left side: a click on the monitor switched the radio off).
const RADIO_AT := Vector3(1.12, 0.82, -1.6)
const RADIO_CLICK_CENTER_LOCAL := RADIO_AT + Vector3(0.0, 0.11, 0.0) + PC_OFFSET
const RADIO_CLICK_SIZE := Vector3(0.38, 0.26, 0.2)
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
## Closed by walking out of the front door: InteriorManager's dither keeps coming closer.
var walked_out := false
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
## At the PC, where you look (the user 21. 10.: D once looks right, A back): 0 the
## first monitor, 1 the second one, or without it out of the office window.
var _crt_look := 0
var _dual := false
var _post
var _crt2_root: Node3D
var _crt2_screen: MeshInstance3D
var _crt2_full_cam_pos := Vector3.ZERO
var _crt2_view_cam_pos := Vector3.ZERO
var _radio_set: Node3D
var _radio_click_center: Vector3 = RADIO_CLICK_CENTER_LOCAL
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
	_post = POST_DELIVERY.new()
	_post.name = "PostDelivery"
	add_child(_post)
	_post.setup(self)
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
	# The lights, the lamps and the curtains as you left them, kept with the save (a load
	# switched everything back on: playtest 25. 10., "remember the lights, the curtains").
	var office := coop_office_state()
	if not office.is_empty():
		out["office"] = office
	return out


## Co-op: the office PC as the other machine must have it too (scripts/os98/os_shell.gd
## coop_pc_state; before the PC was first switched on here, what it was loaded with).
func coop_pc_state() -> Dictionary:
	if _crt_ui != null and is_instance_valid(_crt_ui) and _crt_ui.has_method("coop_pc_state"):
		return _crt_ui.coop_pc_state()
	var out := _pending_crt_desktop_state.duplicate(true)
	out.erase("checkin_desk")
	out.erase("monitor_powered")
	return out


func coop_take_pc_state(state: Dictionary) -> void:
	if _crt_ui != null and is_instance_valid(_crt_ui) and _crt_ui.has_method("coop_take_pc"):
		_crt_ui.coop_take_pc(state)
		return
	for k in state.keys():
		_pending_crt_desktop_state[k] = state[k]
	_pending_crt_desktop_state["os"] = "okna98"


func import_crt_desktop_state(state: Dictionary) -> void:
	_pending_crt_desktop_state = state.duplicate(true)
	_pending_crt_desktop_state.erase("office")
	if _desk_room != null and state.get("checkin_desk", null) is Dictionary:
		_desk_room.import_state(state["checkin_desk"])
	if state.get("office", null) is Dictionary:
		coop_take_office_state(state["office"])
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


## Main pushes the power with every sync of the clock: only a change fades the room. (Each
## push set the lamps up to full and faded them down again, so with the power out the office
## kept lighting up, seen through its windows from the camp: playtest 25. 10.)
func set_grid_power_available(power_available: bool) -> void:
	if power_available == _grid_power_available:
		return
	_grid_power_available = power_available
	_sync_desk_lamp_look()
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
		# Its own 3D sounds (the tube's buzz, the TV, the night's knocks) only while you are in.
		_viewport.audio_listener_enable_3d = true
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
	# The room's own eye (left at the PC's 35 when the room was shut from the PC).
	_interior_camera.fov = OFFICE_FOV
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


## In by the front door on foot (interior_manager walked the warden up to it): the room
## opens as ever, then its eye starts in the doorway where the camp's was and walks in
## behind the counter (reception_extras.come_in_front).
func open_interior_walk_in() -> void:
	open_interior()
	if _extras != null and _extras.has_method("come_in_front"):
		_extras.come_in_front(_initial_cam_pos, _initial_cam_rot + Vector3(0.0, deg_to_rad(ENTRY_YAW_DEG), 0.0), _initial_cam_fov)


## The camp's side of the walk in: where the warden's body stands so his eye is in the
## room's doorway (reception_extras.FRONT_STEP_IN), facing in; {} without the camp.
func walk_in_handoff() -> Dictionary:
	var head := _player_ref.get_node_or_null("Head") as Node3D if _player_ref != null else null
	if head == null or _room_root == null:
		return {}
	var at: Vector3 = RECEPTION_EXTRAS.FRONT_STEP_IN
	var p := walk_out_pose(Vector3(at.x, walk_out_eye_y(at, at.y), at.z))
	if p.is_empty():
		return {}
	return {"to": (p["pos"] as Vector3) - Vector3(0.0, head.position.y, 0.0), "dir": -(p["dir"] as Vector3)}


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
		_viewport.audio_listener_enable_3d = false
	_set_window_view_live(false)
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	_update_inview(delta)
	_update_radio_mix(delta)
	_tick_radio_greetings()
	_tick_music_duck(delta)
	_update_crt_sharp()
	_coop_screen_tick(delta)
	if _extras != null:
		_extras.tick_ring(delta)
	if not visible:
		# Shut, the window still looks out now and then, so coming back in it does not
		# show the weather and the hour of when you left (it did for a moment).
		_window_refresh_t -= delta
		if _window_refresh_t <= 0.0 and _window_vp != null and _place_window_camera():
			_window_refresh_t = 1.0
			_window_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	_tick_photo_flash(get_process_delta_time())
	_update_window_portal()
	if _interior_camera != null:
		_update_torch(delta)
	_update_crt_monitor_light(delta)
	if _dressing != null:
		_dressing.update(delta, _hour_now(), _office_lights_on and _grid_power_available)
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
		_desk_room.process(delta, _extras == null or not _extras.away())
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
		elif collider != null and _node_has_click_type(collider, "crt_power"):
			HandCursor.want(HandCursor.POINT)
		elif _crt_screen != null and (_map_mouse_to_screen(m, _crt_screen, false) != Vector2.INF or (_dual and _map_mouse_to_screen(m, _crt2_screen, false) != Vector2.INF)):
			HandCursor.want(HandCursor.POINT)
	if not meshes.is_empty():
		HandCursor.want(HandCursor.POINT)
	_extras.glint.show_on(meshes)


func _is_camera_tween_running() -> bool:
	# Valid till it finishes: a move held for a steady frame (CAM_MOVE.hold) is paused
	# but under way.
	return _camera_tween != null and is_instance_valid(_camera_tween) and _camera_tween.is_valid()


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
	_camera_tween = CAM_MOVE.move(self, _interior_camera, {"position": _crt_look_back_cam_pos, "rotation": _crt_look_back_cam_rot, "fov": CRT_LOOK_BACK_FOV}, CRT_LOOK_BACK_TRANSITION_SEC, Tween.TRANS_SINE, Tween.EASE_OUT)


func _exit_crt_look_back() -> void:
	if _interior_camera == null:
		_reset_crt_look_back_state()
		return
	_crt_look_back_active = false
	_crt_orbit_enabled = false
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = CAM_MOVE.move(self, _interior_camera, {"position": _crt_seat_pos(), "rotation": _crt_rest_rot(_crt_seat_pos()), "fov": CRT_READY_FOV}, CRT_LOOK_BACK_TRANSITION_SEC, Tween.TRANS_SINE, Tween.EASE_OUT)
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
	var scr := _look_screen()
	if scr != null and is_instance_valid(scr):
		return scr.global_transform.origin
	if _crt_body != null and is_instance_valid(_crt_body):
		return _crt_body.global_transform.origin
	return _crt_orbit_anchor_pos + Vector3(0.0, 0.0, -0.4)





# ── co-op: over the shoulder (scripts/coop/coop.gd) ──────────────────────────

## The screen as sent to the other warden: half size (they see it from the counter).
const COOP_SCREEN_SIZE := Vector2i(320, 240)
const COOP_SCREEN_QUALITY := 0.7
## Their picture is dropped this long after the last one came (they got up, or a frame
## was lost on the way and no more come).
const COOP_SCREEN_HOLD := 0.8
var _coop_screen_tex: ImageTexture
var _coop_screen_left := 0.0


## Your screen while you sit at the PC, as a JPEG ({} when not at it).
func coop_screen_frame() -> PackedByteArray:
	if not _crt_active or _crt_viewport == null:
		return PackedByteArray()
	return coop_screen_frame_any()


## The PC's picture as a JPEG, whoever sits at it (here, or at the staffroom's laptop:
## scripts/staff/laptop_view.gd).
func coop_screen_frame_any() -> PackedByteArray:
	if _crt_viewport == null:
		return PackedByteArray()
	var img := _crt_viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return PackedByteArray()
	# Two monitors: both screens, side by side, each at the half size.
	img.resize(COOP_SCREEN_SIZE.x * (2 if _dual else 1), COOP_SCREEN_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return img.save_jpg_to_buffer(COOP_SCREEN_QUALITY)


## The other warden's screen on your PC (you are not at it yourself).
func coop_show_screen(frame: PackedByteArray) -> void:
	if _crt_active or _crt_screen == null:
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(frame) != OK:
		return
	if _coop_screen_tex == null or _coop_screen_tex.get_size() != Vector2(img.get_size()):
		_coop_screen_tex = ImageTexture.create_from_image(img)
	else:
		_coop_screen_tex.update(img)
	var two := img.get_width() >= img.get_height() * 2
	for k in 2:
		var scr: MeshInstance3D = _crt_screen if k == 0 else _crt2_screen
		var mat := scr.material_override as ShaderMaterial if scr != null else null
		if mat != null:
			mat.set_shader_parameter("screen_tex", _coop_screen_tex)
			mat.set_shader_parameter("uv_rect", Vector4(0.5 * k, 0.0, 0.5, 1.0) if two else Vector4(0.0, 0.0, 1.0, 1.0))
	_coop_screen_left = COOP_SCREEN_HOLD


func _coop_screen_tick(delta: float) -> void:
	if _coop_screen_left <= 0.0:
		return
	_coop_screen_left -= delta
	if _coop_screen_left <= 0.0 or _crt_active:
		coop_end_screen()


## Your own PC's picture back on its screen.
func coop_end_screen() -> void:
	_coop_screen_left = 0.0
	for k in 2:
		var scr: MeshInstance3D = _crt_screen if k == 0 else _crt2_screen
		var mat := scr.material_override as ShaderMaterial if scr != null else null
		if mat != null and _crt_viewport != null:
			mat.set_shader_parameter("screen_tex", _crt_viewport.get_texture())
			mat.set_shader_parameter("uv_rect", _screen_uv_rect(k == 1))


func _try_click_crt(event: InputEventMouseButton) -> void:
	if _interior_camera == null or _crt_screen == null or _crt_viewport == null:
		return
	# Strict hit test: only the real CRT screen quads are clickable; the second monitor's
	# sits you down turned to it.
	var look := 1 if _dual and _map_mouse_to_screen(event.position, _crt2_screen, false) != Vector2.INF else 0
	var vp_pos = _map_mouse_to_screen(event.position, _crt_screen, false) if look == 0 else Vector2.ZERO
	if vp_pos != Vector2.INF:
		# Co-op: one at the PC at a time (the others look over their shoulder).
		for id in Coop.others():
			var theirs: Dictionary = Coop.state_of(id).get("room", {})
			if str(theirs.get("t", "")) == "office" and str(theirs.get("w", "")) == "pc":
				if _extras != null:
					_extras.coop_refuse("pc")
				return
		enter_crt_view(false, look)


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
	# The flat ambient lit every wall the same, corners and all (playtest 18. 10.: "ugly
	# lighting on the walls"): occlusion darkens the corners, the skirting, under the
	# desk and the shelves, a little of the lamps' light too.
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.6
	env.ssao_power = 1.6
	env.ssao_detail = 0.4
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.9
	env.ssao_light_affect = 0.35
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
	_ceiling_light.omni_range = 8.5
	_ceiling_light.omni_attenuation = 0.9
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
	# The light over the room: a fluorescent tube fitting (the old round fixture is gone).
	_build_fluorescent()

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
	# The camp looking in through the office window does not see these (they stand
	# outside the room's front wall, in the way at a slant: the user 21. 10.).
	for n in ["FrontStep", "FrontPorchL", "FrontPorchR", "FrontPorchTop"]:
		var porch := _room_root.get_node_or_null(n)
		if porch != null:
			_hide_from_camp(porch)
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
	# The weather at the window (scripts/ambient/room_weather.gd): rain on the glass,
	# lightning through it, the office creaking in the gusts.
	var rw = ROOM_WEATHER.new()
	rw.is_open = func(): return visible
	_room_root.add_child(rw)
	rw.add_window(_window_quad)

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
	# The window is a real view of the camp now (_setup_window_view): the old painted
	# scene behind it goes. It was hidden before it was built, so it stayed, and from the
	# camp at a slant its beige walls covered the office's window (the user 21. 10.).
	for n in ["OutdoorGround", "OutdoorCeiling", "OutdoorWallL", "OutdoorWallR", "OutdoorBushL", "OutdoorBushR", "OutdoorBushR2", "OutdoorGravelStrip0", "OutdoorGravelStrip1", "OutdoorGravelStrip2", "OutdoorSkyBg"]:
		var outdoor := _room_root.get_node_or_null(n)
		if outdoor != null:
			outdoor.visible = false

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
	# The warden's enamel mug (Grok, camp/desk_mug.png; a plain box until it is there).
	if not _desk_cutout(pc_root, "desk_mug", Vector2(0.11, 0.12), Vector3(1.20, 0.83, -0.98), "DeskCup"):
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
	_build_monitor_switch()
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

	# No desk fan: the radio stands where it was (RADIO_AT), and its boxes stuck out of the
	# set as the "untextured cuboids round the PC" (the user 20. 10.); it is October.

	_build_radio(pc_root)

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
	_setup_door_view()
	_dressing = OFFICE_DRESSING.new()
	_dressing.build(_room_root)
	for id in _dressing.hot.keys():
		_extras.hot[id] = _dressing.hot[id]


func _build_crt_viewport() -> void:
	if _crt_viewport != null: return
	_crt_viewport = SubViewport.new()
	_crt_viewport.name = "CRTViewport"
	_crt_viewport.size = CRT_RESOLUTION
	_crt_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_crt_viewport.handle_input_locally = true
	_crt_viewport.gui_disable_input = false
	# Menus, submenus and tooltips open inside the monitor (not embedded they went to the
	# game's own window at the screen's coordinates: off the monitor, the user 21. 10.).
	_crt_viewport.gui_embed_subwindows = true
	add_child(_crt_viewport)

	_crt_ui = CRT_UI_SCENE.new()
	_crt_ui.name = "CRTScannerUI"
	_crt_ui.position = Vector2.ZERO
	_crt_ui.size = Vector2(CRT_RESOLUTION)
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
	# With the second monitor its screen is drawn beside the first (os_shell.gd).
	_crt_viewport.size = Vector2i(CRT_RESOLUTION.x * (2 if _dual else 1), CRT_RESOLUTION.y)
	if _crt_ui != null:
		_crt_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_crt_ui.position = Vector2.ZERO
		_crt_ui.size = Vector2(CRT_RESOLUTION)


## `instant`: a new game starts already seated, the monitor filling the view from the
## first frame (no fly-in from the room view).
## Sitting down at the PC and getting up (playtest 20. 10.: "the move to the computer is
## too slow": it was 1.2 s in, then 1.1 s leaning to the screen, 0.8 s out).
const CRT_SIT_SEC := 0.5
const CRT_LEAN_IN_SEC := 0.4
const CRT_STAND_SEC := 0.45


func enter_crt_view(instant: bool = false, look := 0) -> void:
	if _crt_active: return
	_crt_look = look if _dual else 0
	if _crt_ui != null and _crt_ui.has_method("set_screen"):
		_crt_ui.set_screen(_crt_look)
	if not _monitor_on:
		_toggle_monitor()
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
		_interior_camera.position = _crt_seat_pos()
		_interior_camera.rotation = _crt_rest_rot(_crt_seat_pos())
		_interior_camera.fov = CRT_READY_FOV
		_capture_crt_orbit_anchor()
		if _crt_ui:
			_crt_ui.open_panel()
		return
	# Target: Front of CRT (approx dist 0.5m so screen fits nice)
	# Screen Z global: -0.535.
	# Target Z: 0.1
	_crt_orbit_enabled = false
	var approach := _crt_seat_pos(false)
	_camera_tween = CAM_MOVE.move(self, _interior_camera, {"position": approach, "rotation": _crt_rest_rot(approach), "fov": CRT_ENTER_FOV}, CRT_SIT_SEC, Tween.TRANS_CUBIC, Tween.EASE_OUT)
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
	_crt_look = 0
	if _crt_ui != null and _crt_ui.has_method("set_screen"):
		_crt_ui.set_screen(0)
	if _crt_ui != null:
		_crt_ui.set_meta("look_away", false)
		# Up from the desk, the camera's legs go back in (the next sitting starts with S).
		var b = _crt_ui.get_meta("builder_walk", null)
		if b != null and is_instance_valid(b):
			b.call("end_walk")
	_crt_active = false
	_crt_orbit_enabled = false
	_reset_crt_look_back_state()
	# The OS hides the system cursor while you use it (it draws its own); standing up
	# gives the room its cursor back (and open_panel hides it again when you sit down).
	if _crt_ui != null and _crt_ui.has_method("close_panel"):
		_crt_ui.close_panel()

	if _camera_tween: _camera_tween.kill()
	_camera_tween = CAM_MOVE.move(self, _interior_camera, {"position": _initial_cam_pos, "rotation": _initial_cam_rot, "fov": _initial_cam_fov}, CRT_STAND_SEC, Tween.TRANS_CUBIC, Tween.EASE_OUT)


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
			# Not typing into the machine: E turns your head (to the second monitor, or out
			# of the office window) and back again (the user, 21. 10.: "E right, E left";
			# A and D were it). S stands you up, unless Builder has the camera on WASD and
			# it is the screen you look at (builder_module.walk_keys).
			if not _crt_typing():
				if key_event.physical_keycode == KEY_E:
					if key_event.pressed and not key_event.echo:
						_crt_turn(1 - _crt_look)
					get_viewport().set_input_as_handled()
					return
				if key_event.physical_keycode == KEY_S and key_event.pressed and not key_event.echo and not _crt_keys_taken():
					_exit_crt_view()
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
		if _extras != null and _extras.away():
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


## Builder's camera on WASD (its legged camera button), on the screen you look at: the
## left hand is on the map, S does not stand you up.
func _crt_keys_taken() -> bool:
	var b = _crt_ui.get_meta("builder_walk", null) if _crt_ui != null else null
	return b != null and is_instance_valid(b) and bool(b.call("walk_keys"))


## E at the PC: one press turns you, the next back (it was D held to lean out, then A/D,
## playtest 21. 10.). Right is the second monitor once it is on the desk, the office
## window before that.
func _crt_turn(to: int) -> void:
	if to == _crt_look or not _crt_active or _interior_camera == null:
		return
	_crt_look = to
	# Out of the window no program has the keys (Builder's WASD camera neither).
	if _crt_ui != null:
		_crt_ui.set_meta("look_away", to == 1 and not _dual)
	_crt_orbit_enabled = false
	if _crt_ui != null and _crt_ui.has_method("set_screen"):
		_crt_ui.set_screen(to if _dual else 0)
	if _camera_tween != null:
		_camera_tween.kill()
	if to == 1 and not _dual:
		var pos := _crt_full_cam_pos + Vector3(0.46, 0.08, -0.12)
		var rot := Transform3D(Basis(), pos).looking_at(WINDOW_CENTER + Vector3(0, -0.12, 0), Vector3.UP).basis.get_euler()
		_camera_tween = CAM_MOVE.move(self, _interior_camera, {"position": pos, "rotation": rot, "fov": 44.0}, 0.55, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		return
	var seat := _crt_seat_pos()
	# The chair rolls the half metre along the desk and the head turns with it.
	_camera_tween = CAM_MOVE.move(self, _interior_camera, {"position": seat, "rotation": _crt_rest_rot(seat), "fov": CRT_READY_FOV}, 0.42, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_camera_tween.finished.connect(func():
		if not _crt_active or _crt_look != to:
			return
		_capture_crt_orbit_anchor()
		_crt_orbit_enabled = true
	)


## Where the eye is, sat at the monitor you look at (`full`: leant in to it; else where
## you first sit down).
func _crt_seat_pos(full := true) -> Vector3:
	if _crt_look == 1 and _dual:
		return _crt2_full_cam_pos if full else _crt2_view_cam_pos
	return _crt_full_cam_pos if full else _crt_view_cam_pos


## The glass you look at: the second monitor's, the first's, or none (out of the window).
func _look_screen() -> MeshInstance3D:
	if _crt_look == 1:
		return _crt2_screen if _dual else null
	return _crt_screen


## Where the screen you look at is in the CRT picture (the second is drawn right of it).
func _look_origin() -> Vector2:
	return Vector2(CRT_RESOLUTION.x, 0) if _crt_look == 1 and _dual else Vector2.ZERO


## The part of the CRT picture a monitor shows (the shaders' uv_rect).
func _screen_uv_rect(second: bool) -> Vector4:
	if not _dual:
		return Vector4(0.0, 0.0, 1.0, 1.0)
	return Vector4(0.5 if second else 0.0, 0.0, 0.5, 1.0)


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
	if _interior_camera == null or _look_screen() == null or _crt_viewport == null:
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
	var screen_mesh := _look_screen()
	var show := visible and is_inside_tree() and _crt_active and screen_mesh != null and _crt_viewport != null and _interior_camera != null and _viewport != null
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
	var quad := screen_mesh.mesh as QuadMesh
	var window := get_tree().root.get_visible_rect().size
	var render := _interior_camera.get_viewport().get_visible_rect().size
	var xf := screen_mesh.global_transform
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
	(_crt_sharp.material as ShaderMaterial).set_shader_parameter("uv_rect", _screen_uv_rect(_crt_look == 1))
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
	var target := (p - _look_origin()) / Vector2(CRT_RESOLUTION)
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


## The mouse on the screen you look at, in CRT picture pixels (the second monitor's are
## right of the first's); INF off it.
func _map_mouse_to_crt(mouse_pos: Vector2, allow_fallback: bool = true) -> Vector2:
	var scr := _look_screen()
	if scr == null:
		return Vector2.INF
	var p := _map_mouse_to_screen(mouse_pos, scr, allow_fallback)
	return p if p == Vector2.INF else p + _look_origin()


func _map_mouse_to_screen(mouse_pos: Vector2, screen_mesh: MeshInstance3D, allow_fallback: bool = true) -> Vector2:
	var vp_size := Vector2(CRT_RESOLUTION)
	if _crt_viewport == null or screen_mesh == null:
		return Vector2.INF
	# Primary mapping: actual raycast against the CRT mesh in 3D.
	var local_mouse = _to_interior_viewport_pos(mouse_pos)
	var ray_origin = _interior_camera.project_ray_origin(local_mouse)
	var ray_dir = _interior_camera.project_ray_normal(local_mouse)
	var screen_transform = screen_mesh.global_transform
	var plane_normal = screen_transform.basis.z.normalized()
	var plane = Plane(plane_normal, plane_normal.dot(screen_transform.origin))
	var intersect = plane.intersects_ray(ray_origin, ray_dir)
	if intersect != null:
		var local_hit = screen_mesh.to_local(intersect)
		var quad = screen_mesh.mesh as QuadMesh
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
	return Vector2(float(CRT_RESOLUTION.x) / screen_size.x, float(CRT_RESOLUTION.y) / screen_size.y)


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
	# (Turned to the office window: you stay looking out.)
	if not _crt_active or _look_screen() == null:
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
	_camera_tween = CAM_MOVE.move(self, _interior_camera, {"position": _crt_seat_pos(), "rotation": _crt_rest_rot(_crt_seat_pos()), "fov": CRT_READY_FOV}, CRT_LEAN_IN_SEC, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
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


## The camp's daylight factor tops out near 0.6 on an autumn noon and sits round 0.25
## in the morning and the evening; the office is lit as if 0.6 were full day (playtest
## 17. 10.: "terrible dark by day, total darkness morning and evening").
const OFFICE_DAY_AT := 0.58


## The day through the window by the weather (main's states: 1 windy, 2 fog, 3 light
## rain, 4 rain, 5 storm): how much of it comes in.
const WEATHER_DAY_K := {1: 0.94, 2: 0.76, 3: 0.68, 4: 0.54, 5: 0.36}


func _apply_room_time_profile(animated: bool = false) -> void:
	var d := clampf(_daylight_factor / OFFICE_DAY_AT, 0.0, 1.0)
	if _room_environment != null:
		_room_environment.background_color = _tri(d, Color(0.08, 0.10, 0.14), Color(0.24, 0.20, 0.22), Color(0.66, 0.70, 0.74))
		_room_environment.ambient_light_color = _tri(d, Color(0.22, 0.26, 0.34), Color(0.48, 0.40, 0.42), Color(0.82, 0.84, 0.80))
		_room_environment.ambient_light_energy = _tri(d, 0.12, 0.86, 1.8)
		_room_environment.fog_light_color = _tri(d, Color(0.14, 0.18, 0.24), Color(0.34, 0.28, 0.30), Color(0.78, 0.82, 0.84))
		_room_environment.fog_density = _tri(d, 0.014, 0.010, 0.004)
	if _ceiling_light != null:
		# The tube's cold white, which the evening and the day only warm a little.
		_ceiling_light.light_color = _tri(d, Color(0.86, 0.92, 1.0), Color(0.94, 0.92, 0.9), Color(1.0, 0.98, 0.92))
		_ceiling_light.light_energy = _tri(d, 2.5, 2.2, 1.88)
	if _desk_lamp != null:
		_desk_lamp.light_energy = _tri(d, 0.9, 0.8, 0.7)
		_desk_lamp.light_color = Color(1.0, 0.86, 0.6)
		_desk_lamp.omni_range = 2.8
	if _window_light != null:
		_window_light.light_color = _tri(d, Color(0.54, 0.60, 0.84), Color(0.84, 0.66, 0.54), Color(0.98, 0.98, 0.92))
		_window_light.light_energy = _tri(d, 0.01, 0.34, 1.6)

	var daylight = d
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
	# The weather outside is the room's too (playtest 25. 10.: "the reception's light does
	# not match the weather"): the camp's daylight tops out at noon well before the room's
	# full day, so a rain hardly showed; an overcast, rainy or stormy day comes in grey and
	# dim through the window, the sun's beam all but gone in a storm.
	var wk: float = WEATHER_DAY_K.get(_weather_state, 1.0)
	if wk < 1.0 and daylight > 0.0:
		var grey: float = (1.0 - wk) * daylight
		var cloud := Color(0.6, 0.64, 0.7)
		if _room_environment != null:
			_room_environment.ambient_light_energy *= lerpf(1.0, wk, daylight)
			_room_environment.ambient_light_color = _room_environment.ambient_light_color.lerp(cloud, grey)
			_room_environment.background_color = _room_environment.background_color.lerp(cloud * 0.6, grey)
		if _window_light != null:
			_window_light.light_energy *= wk
			_window_light.light_color = _window_light.light_color.lerp(cloud, grey * 1.4)
		if _sun_beam != null:
			_sun_beam.light_energy *= wk * wk * wk
	if _room_environment != null and _office_curtain != null:
		_room_environment.ambient_light_energy *= lerpf(0.55, 1.0, _office_curtain.open) if daylight > 0.3 else 1.0
	# The tubes on: their cold light is everywhere in a small room (the walls, the
	# ceiling, under the desk), not only where the lamp's cone falls; more so the darker
	# it is outside. Off (the switch by the door) or no power: only what else there is.
	if _room_environment != null and _office_lights_on and _grid_power_available:
		var fill := lerpf(0.55, 0.12, daylight)
		_room_environment.ambient_light_color = _room_environment.ambient_light_color.lerp(Color(0.82, 0.88, 0.96), lerpf(0.6, 0.1, daylight))
		_room_environment.ambient_light_energy = maxf(_room_environment.ambient_light_energy, fill)
	_sync_reception_glass()
	_apply_manual_office_light_profile(animated)
	_sync_desk_lamp_look()
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
var _window_refresh_t := 0.0
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
	for v in ([vp] if vp != null else [_window_vp, _back_vp, _door_vp]):
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

## The front doorway (in the window wall, x 1.25..2.2): open, the camp is beyond it
## (a guest coming in, the warden walking out), not the room's empty sky. Unlike the
## windows it is seen from right up close, so its view is the room's own eye put in the
## camp (the camp building has its doorway at the same place), as big as the room's
## picture, and the doorway shows it where it falls on the screen.
const DOOR_VIEW_CENTER := Vector3(1.725, 1.05, -2.6)
const DOOR_VIEW_SIZE_M := Vector2(0.95, 2.1)
const DOOR_VIEW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D view : source_color, filter_nearest;
void fragment() {
	ALBEDO = texture(view, SCREEN_UV).rgb;
}
"""
var _door_vp: SubViewport
var _door_cam: Camera3D
var _door_quad: MeshInstance3D


func _setup_door_view() -> void:
	var made := _make_portal("FrontDoorView", Vector2i(320, 240))
	_door_vp = made[0]
	_door_cam = made[1]
	_door_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_door_quad = MeshInstance3D.new()
	_door_quad.name = "FrontDoorView"
	var q := QuadMesh.new()
	q.size = DOOR_VIEW_SIZE_M
	_door_quad.mesh = q
	var sh := Shader.new()
	sh.code = DOOR_VIEW_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("view", _door_vp.get_texture())
	_door_quad.material_override = m
	_door_quad.position = DOOR_VIEW_CENTER
	_door_quad.visible = false
	_room_root.add_child(_door_quad)


## The doorway's view: the room's eye, mapped into the camp, at the room picture's size.
func _aim_door_view(eye_room: Vector3) -> bool:
	if _viewport == null or _room_root == null:
		return false
	# Only from in front of the doorway (the walk out hands over to the camp before it).
	if eye_room.z < DOOR_VIEW_CENTER.z + 0.02:
		return false
	if _door_vp.size != _viewport.size:
		_door_vp.size = _viewport.size
	var local := _room_root.global_transform.affine_inverse() * _interior_camera.global_transform
	_door_cam.global_transform = Transform3D(_portal_xform.basis * local.basis, _portal_xform * local.origin)
	_door_cam.fov = _interior_camera.fov
	_door_cam.keep_aspect = _interior_camera.keep_aspect
	_door_cam.near = _interior_camera.near
	_door_cam.far = 260.0
	return true


## Walked out by the front door: where the warden is in the camp (a room point on the
## porch, mapped like the portals) and which way he is going, or {} without the camp.
func walk_out_pose(room_point: Vector3) -> Dictionary:
	if not _portal_ok and not _place_window_camera():
		return {}
	var dir := _portal_xform.basis * Vector3(0, 0, -1)
	dir.y = 0.0
	return {"pos": _portal_xform * room_point, "dir": dir.normalized()}


## Where the warden's walk out ends in the camp (room space, off the porch's step).
const WALK_OUT_LAND := Vector3(1.72, 0.0, -3.7)


## The camp's side of the walk out, as body positions: from under the room's eye as it
## is now to standing at WALK_OUT_LAND, and the way out; {} without the camp.
func walk_out_handoff() -> Dictionary:
	var head := _player_ref.get_node_or_null("Head") as Node3D if _player_ref != null else null
	if head == null or _interior_camera == null or _room_root == null:
		return {}
	var eye := _room_root.to_local(_interior_camera.global_position)
	var a := walk_out_pose(eye)
	if a.is_empty():
		return {}
	var b := walk_out_pose(Vector3(WALK_OUT_LAND.x, walk_out_eye_y(WALK_OUT_LAND, eye.y), WALK_OUT_LAND.z))
	var lift := Vector3(0.0, head.position.y, 0.0)
	return {"from": (a["pos"] as Vector3) - lift, "to": (b["pos"] as Vector3) - lift, "dir": a["dir"]}


## How high (room y) the camp's eye is with the warden standing at a room point out
## there: the ground under it, his body's height over the ground where he stands now,
## his head. The walk out comes down to it, so the camp's view goes on at the same height.
func walk_out_eye_y(room_point: Vector3, fallback: float) -> float:
	var pose := walk_out_pose(Vector3(room_point.x, 0.0, room_point.z))
	if pose.is_empty() or _player_ref == null or not _player_ref.is_inside_tree():
		return fallback
	var floor_y: float = (pose["pos"] as Vector3).y
	var there := _camp_ground_y(pose["pos"])
	var here := _camp_ground_y(_player_ref.global_position)
	var head := _player_ref.get_node_or_null("Head") as Node3D
	if is_nan(there) or is_nan(here) or head == null:
		return fallback
	return there + (_player_ref.global_position.y - here) + head.position.y - floor_y


func _camp_ground_y(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.0, 0), p + Vector3(0, -3.0, 0))
	q.exclude = [(_player_ref as CollisionObject3D).get_rid()] if _player_ref is CollisionObject3D else []
	var hit := _player_ref.get_world_3d().direct_space_state.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else NAN


func _front_door_open() -> bool:
	var pivot: Node3D = _desk_room.front_door() if _desk_room != null else null
	return pivot != null and absf(pivot.rotation_degrees.y) > 1.0


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
	# On the way back from the back room (and with its door open) the office window comes
	# into view before you stand in the office: it was off till the walk ended, and showed
	# the night's picture through the morning.
	var office_on: bool = not in_back or not _extras.in_back_room() or _extras._walking() or _extras.back_door_open()
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
	if _door_cam != null:
		var door_on: bool = not (_extras != null and _extras.in_back_room()) and _front_door_open()
		door_on = door_on and _aim_door_view(eye_room)
		_door_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if door_on else SubViewport.UPDATE_DISABLED
		_door_quad.visible = door_on


## The office building's windows for whatever is outside at night (the Photographer,
## scripts/enemies/tourist_brain.gd): the office window and the back room's, each with
## where it is in the camp, which way it faces, how squarely you look at it and its
## curtain. Only those of the part you are in (from the back room, the office's too
## while its door is open).
func photo_windows() -> Array:
	var out: Array = []
	if not _portal_ok and not _place_window_camera():
		return out
	if _room_root == null or _interior_camera == null:
		return out
	var in_back: bool = _extras != null and _extras.in_back_room()
	var specs: Array = []
	if not in_back or _extras.back_door_open():
		specs.append([WINDOW_CENTER, Vector3(0, 0, -1), _office_curtain])
	if in_back:
		specs.append([RL.BACK_WINDOW_CENTER, Vector3(-1, 0, 0), _extras.back.curtain if _extras != null else null])
	for sp in specs:
		var c: Vector3 = sp[0]
		var o: Vector3 = sp[1]
		var cur = sp[2]
		var at := _room_root.global_transform * c
		var to := (at - _interior_camera.global_position).normalized()
		out.append({"pos": _portal_xform * c, "out": (_portal_xform.basis * o).normalized(),
			"facing": (-_interior_camera.global_transform.basis.z).dot(to),
			"open": float(cur.open) if cur != null else 1.0,
			"flash": _photo_flash.bind(c, o, cur),
			"room_world": _viewport.find_world_3d() if _viewport != null else null,
			"glass": at, "eye": _interior_camera.global_position,
			# Your eye out in the camp (where the window's camera stands).
			"view": _portal_xform * (_room_root.global_transform.affine_inverse() * _interior_camera.global_position)})
	return out


## The flash through a window: a cold light popping in the room (the drawn curtain lets
## a little through), the glass white for a moment.
var _photo_light: OmniLight3D
var _photo_t := 0.0


func _photo_flash(c: Vector3, o: Vector3, cur) -> void:
	if _room_root == null:
		return
	if _photo_light == null or not is_instance_valid(_photo_light) or _photo_light.get_parent() != _room_root:
		_photo_light = OmniLight3D.new()
		_photo_light.name = "PhotoFlash"
		_photo_light.light_color = Color(0.9, 0.94, 1.0)
		_photo_light.omni_range = 7.0
		_photo_light.shadow_enabled = true
		_room_root.add_child(_photo_light)
	_photo_light.position = c - o * 0.4
	var through := lerpf(0.15, 1.0, float(cur.open)) if cur != null else 1.0
	_photo_light.set_meta("peak", 10.0 * through)
	_photo_t = 0.45


func _tick_photo_flash(delta: float) -> void:
	if _photo_light == null or not is_instance_valid(_photo_light):
		return
	_photo_t = maxf(0.0, _photo_t - delta)
	_photo_light.light_energy = float(_photo_light.get_meta("peak", 0.0)) * pow(_photo_t / 0.45, 1.6)


func _set_window_view_live(on: bool) -> void:
	if _window_vp == null:
		return
	if on and not _place_window_camera():
		on = false
	_window_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on and _back_vp != null:
		_back_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not on and _door_vp != null:
		_door_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_door_quad.visible = false
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


# ── the office from the camp, through its windows ────────────────────────────

## The reception's windows seen from outside (the user 21. 10.: "they have no depth, they
## are not 3D"): the office itself, the same room you sit in, drawn from where you stand
## in the camp by a camera in the room's own world (the camp's eye carried through
## ReceptionLayout's room-to-building mapping), and the panes show it at their own screen
## pixels (materials/window_into.gdshader). Its lamps, the curtains, the glow of the PC
## and whoever is at it are the room's. Only near and with a pane turned to you; farther
## off the panes are dark glass that warms with the lamps at night (_glow_glass).
const INVIEW_RANGE := 42.0
## What shows the office from the camp: its window, the back room's, and the front doorway
## while the door stands open (building_models.reception: door_way).
const PANES := ["office_glass", "back_glass", "door_way"]
## What lies over the room's own windows from inside (the camp's view, the rain on the
## glass, the doorway's view): the camera from outside does not see it.
const INVIEW_HIDE_LAYER := 1 << 17
var _inview_vp: SubViewport
var _inview_cam: Camera3D
var _inview_light_t := 0.0
var _inview_live := false
var _inview_reception: Node3D


func _update_inview(delta: float) -> void:
	var cam: Camera3D = null
	var on := false
	if not visible and _room_root != null:
		if _glass_cache.is_empty() or not is_instance_valid(_glass_cache.get("office_glass")):
			_sync_reception_glass()
		var main := _resolve_main_runtime_host()
		var w3d = main.get("_world_3d") if main != null else null
		if w3d is Node3D and (w3d as Node3D).is_inside_tree():
			cam = (w3d as Node3D).get_viewport().get_camera_3d()
		if _inview_reception == null or not is_instance_valid(_inview_reception):
			var scene := get_tree().current_scene
			_inview_reception = scene.find_child("MainBuilding", true, false) as Node3D if scene != null else null
		if cam != null and _inview_reception != null and not _glass_cache.is_empty():
			for k in PANES:
				var g = _glass_cache.get(k)
				if g is MeshInstance3D and is_instance_valid(g) and (g as MeshInstance3D).is_visible_in_tree():
					var to_eye: Vector3 = cam.global_position - (g as MeshInstance3D).global_position
					if to_eye.length() < INVIEW_RANGE and _pane_faces(g, to_eye):
						on = true
	if on != _inview_live:
		_inview_live = on
		_ensure_inview()
		for k in PANES:
			var g = _glass_cache.get(k)
			if g is MeshInstance3D and is_instance_valid(g):
				var sm := (g as MeshInstance3D).material_override as ShaderMaterial
				if sm != null:
					sm.set_shader_parameter("live", 1.0 if on else 0.0)
	# The other wardens in the office, seen from the camp (interior_manager).
	var im = get_parent()
	if im != null and im.has_method("_coop_office_from_camp"):
		im._coop_office_from_camp(delta)
	if _inview_vp == null:
		return
	_inview_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		return
	# The room goes on while you are not in it: a curtain drawn (here or by the other
	# warden), the back room's set and lamp.
	if _extras != null and _extras.tick_unseen(delta, _hour_now()):
		_apply_room_time_profile()
	# The camp's eye in the room: camp -> the building's local space -> the room's.
	# (The model's own node, the panes' parent: the structure's origin is off the ground.)
	var shell := (_glass_cache.get("office_glass") as Node3D).get_parent() as Node3D
	var to_room: Transform3D = _room_root.global_transform * RL.room_to_local().affine_inverse() * shell.global_transform.affine_inverse()
	_inview_cam.global_transform = to_room * cam.global_transform
	_inview_cam.fov = cam.fov
	_inview_cam.keep_aspect = cam.keep_aspect
	# The camp's eye looking up or down is Build's shift of the picture (a moved frustum,
	# player_controller._apply_projection): the panes' picture must be shifted the same.
	# (Its near plane is its own: the frustum scaled to it.)
	_inview_cam.projection = cam.projection
	var nk := _inview_cam.near / maxf(cam.near, 0.001)
	_inview_cam.size = cam.size * nk
	_inview_cam.frustum_offset = cam.frustum_offset * nk
	var px := Vector2i(cam.get_viewport().get_visible_rect().size)
	if _inview_vp.size != px and px.x > 0:
		_inview_vp.size = px
	# The room's light while it is shut follows the camp's hour (it is kept up only while
	# you are in it).
	_inview_light_t -= delta
	if _inview_light_t <= 0.0:
		_inview_light_t = 0.5
		var ll: Array = im.get("_last_light") if im != null and im.get("_last_light") != null else []
		if ll.size() >= 4:
			set_daylight_profile(ll[0], ll[1], ll[2], ll[3])
		var bright := 1.0 if _time_state == TIME_NIGHT else (0.8 if _time_state == TIME_EVENING else 0.6)
		for k in PANES:
			var g = _glass_cache.get(k)
			if g is MeshInstance3D and is_instance_valid(g) and (g as MeshInstance3D).material_override is ShaderMaterial:
				((g as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("bright", bright)


static func _pane_faces(g: MeshInstance3D, to_eye: Vector3) -> bool:
	# The glass is a thin box: its thinnest axis is the way it faces.
	var bm := g.mesh as BoxMesh
	var axis := Vector3.FORWARD
	if bm != null:
		var s := bm.size
		axis = Vector3.RIGHT if s.x < s.y and s.x < s.z else (Vector3.UP if s.y < s.z else Vector3.BACK)
	var n := (g.global_basis * axis).normalized()
	return absf(n.dot(to_eye.normalized())) > 0.12


func _ensure_inview() -> void:
	if _inview_vp != null or _viewport == null:
		return
	_inview_vp = SubViewport.new()
	_inview_vp.name = "OfficeFromCamp"
	_inview_vp.size = Vector2i(426, 240)
	_inview_vp.world_3d = _viewport.find_world_3d()
	_inview_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_inview_vp)
	_inview_cam = Camera3D.new()
	_inview_cam.near = 0.05
	_inview_cam.far = 80.0
	_inview_cam.cull_mask = 0xFFFFF & ~INVIEW_HIDE_LAYER
	_inview_vp.add_child(_inview_cam)
	# The room's own window views and their rain are for the inside only.
	# So is the room's own front door: from the camp the camp building's leaf is the door,
	# and open it shows the room through the doorway, not this one shut across it.
	for n in [_window_quad, _window_outdoor_sky, _door_quad, (_extras.back.window_quad if _extras != null and _extras.back != null else null), (_desk_room.front_door() if _desk_room != null else null)]:
		if n is Node3D:
			_hide_from_camp(n)
	var shader: Shader = load("res://materials/window_into.gdshader")
	for k in PANES:
		var g = _glass_cache.get(k)
		if g is MeshInstance3D and is_instance_valid(g):
			var sm := ShaderMaterial.new()
			sm.shader = shader
			sm.set_shader_parameter("room_tex", _inview_vp.get_texture())
			if k == "door_way":
				# No glass in a doorway: the room as it is, and dark far off.
				sm.set_shader_parameter("tint", Vector3.ONE)
				sm.set_shader_parameter("sheen", 0.0)
				sm.set_shader_parameter("glass", Vector3(0.035, 0.03, 0.025))
			(g as MeshInstance3D).material_override = sm
	_sync_reception_glass()


static func _hide_from_camp(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = INVIEW_HIDE_LAYER
	for c in n.get_children():
		_hide_from_camp(c)


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
	var way = _glass_cache.get("door_way")
	if way is MeshInstance3D and is_instance_valid(way) and (way as MeshInstance3D).material_override is ShaderMaterial:
		_glow_glass(way, night * power * office_lit * 0.6)
	var back_lit := 0.0
	var back_open := 0.0
	if _extras != null and _extras.back != null:
		back_lit = (0.7 if _extras.back.lamp_on else 0.0) + (0.25 if _extras.back.tv_on else 0.0)
		back_open = _extras.back.curtain.open if _extras.back.curtain != null else 0.0
	_glow_glass(_glass_cache.get("back_glass"), night * power * back_lit * lerpf(0.3, 1.0, back_open))


static func _glow_glass(g, amount: float) -> void:
	if g == null or not is_instance_valid(g):
		return
	var sm := (g as MeshInstance3D).material_override as ShaderMaterial
	if sm != null:
		sm.set_shader_parameter("glow", clampf(amount, 0.0, 1.0))
		return
	var m := (g as MeshInstance3D).material_override as StandardMaterial3D
	if m == null:
		return
	m.emission_energy_multiplier = 1.4 * amount
	# A pane with the room's picture (building_models._glass) shows the room lit; a plain
	# one turns warm all over.
	var pic := 0.2 if m.emission_texture != null else 1.0
	m.albedo_color = Color(0.16, 0.2, 0.24).lerp(Color(0.5, 0.4, 0.26), clampf(amount, 0.0, 1.0) * pic)


func set_weather_state(weather: int) -> void:
	var was := _weather_state
	_weather_state = weather
	_update_window_texture()
	if was != weather:
		_apply_room_time_profile(true)


func _setup_office_light_system() -> void:
	_office_switch_tex_on = _pick_office_texture("interior_switch_on", Color(0.84, 0.80, 0.68))
	_office_switch_tex_off = _pick_office_texture("interior_switch_off", Color(0.68, 0.64, 0.58))
	_office_wall_tex_default = _pick_office_texture("office_wall", Color(0.66, 0.50, 0.36))
	_office_wall_tex_dim = _pick_office_texture("office_wall_dim", Color(0.40, 0.34, 0.30))
	_office_wall_tex_near = _pick_office_texture("office_wall_near_light", Color(0.52, 0.44, 0.38))
	_create_office_light_switch()
	_apply_office_switch_visual()
	_apply_office_wall_texture_state()


# ── the radio and the monitor's switch ───────────────────────────────────────

## The radio: a brown Tesla portable from the eighties on the right end of the desk, a
## Build-engine box with its faces painted (Grok: camp/radio_front, radio_side), a
## chrome carrying handle and a telescopic aerial. Click it to switch it on or off.
func _build_radio(pc_root: Node3D) -> void:
	var K := INTERIOR_KIT
	var set_root := Node3D.new()
	set_root.name = "RadioSet"
	set_root.position = pc_root.position + RADIO_AT
	_radio_set = set_root
	# Turned between the counter and the chair: its front seen from both.
	set_root.rotation_degrees.y = 8.0
	_room_root.add_child(set_root)
	var w := 0.34
	var h := 0.2
	var d := 0.11
	var side := K.surface("radio_side", 0.2) if ResourceLoader.exists("res://assets/textury/camp/radio_side.png") else K.surface("plastic", 0.3, Color(0.36, 0.24, 0.16))
	K.slab(set_root, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), side, "RadioBody")
	var front := _face(set_root, "radio_front", Vector2(w - 0.004, h - 0.004), Vector3(0.0, h * 0.5, d * 0.5 + 0.002), 0.0)
	front.name = "RadioSpeaker"
	var chrome := K.surface("galvanized", 0.3, Color(0.86, 0.86, 0.84))
	# The handle: two posts and the grip across the top.
	K.slab(set_root, Vector3(0.016, 0.05, 0.02), Vector3(-w * 0.38, h + 0.025, 0.0), chrome, "RadioHandleL")
	K.slab(set_root, Vector3(0.016, 0.05, 0.02), Vector3(w * 0.38, h + 0.025, 0.0), chrome, "RadioHandleR")
	K.slab(set_root, Vector3(w * 0.8, 0.016, 0.026), Vector3(0.0, h + 0.05, 0.0), K.surface("plastic", 0.2, Color(0.12, 0.1, 0.08)), "RadioGrip")
	# The aerial, pulled out and leaning back.
	var ant := K.slab(set_root, Vector3(0.008, 0.42, 0.008), Vector3(w * 0.42, h + 0.2, -0.03), chrome, "RadioAntenna")
	ant.rotation_degrees.z = -18.0
	ant.rotation_degrees.x = -10.0
	_create_radio_power_click_body()


## The monitor's power: a button and its lamp on the bezel's lower right. Off, the
## picture goes and the screen stops lighting the room (for a dark office at night); the
## computer underneath runs on. Sitting down at it switches it back on.
var _monitor_on := true
var _monitor_led_mat: StandardMaterial3D


func _build_monitor_switch() -> void:
	if _crt_body == null:
		return
	var K := INTERIOR_KIT
	var at := Vector3(0.29, -0.24, 0.352)
	K.slab(_crt_body, Vector3(0.05, 0.028, 0.014), at, K.surface("plastic", 0.2, Color(0.7, 0.66, 0.56)), "CRTPowerButton")
	var led := MeshInstance3D.new()
	led.name = "CRTPowerLed"
	var lm := BoxMesh.new()
	lm.size = Vector3(0.012, 0.012, 0.01)
	led.mesh = lm
	_monitor_led_mat = StandardMaterial3D.new()
	_monitor_led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_monitor_led_mat.albedo_color = Color(0.3, 1.0, 0.35)
	led.material_override = _monitor_led_mat
	led.position = at + Vector3(-0.055, 0.0, 0.004)
	_crt_body.add_child(led)
	var body := StaticBody3D.new()
	body.name = "CRTPowerClick"
	body.set_meta("interior_click_type", "crt_power")
	body.position = at + Vector3(-0.02, 0.0, 0.02)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.12, 0.07, 0.05)
	cs.shape = bs
	body.add_child(cs)
	_crt_body.add_child(body)


func _toggle_monitor() -> void:
	_monitor_on = not _monitor_on
	var mat := _crt_screen.material_override as ShaderMaterial if _crt_screen != null else null
	if mat != null:
		mat.set_shader_parameter("powered", 1.0 if _monitor_on else 0.0)
	var mat2 := _crt2_screen.material_override as ShaderMaterial if _crt2_screen != null else null
	if mat2 != null:
		mat2.set_shader_parameter("powered", 1.0 if _monitor_on else 0.0)
	if _monitor_led_mat != null:
		_monitor_led_mat.albedo_color = Color(0.3, 1.0, 0.35) if _monitor_on else Color(0.16, 0.2, 0.16)
	_play_click_sfx("res://assets/sfx/desk/crt_power_on.mp3" if _monitor_on else "res://assets/sfx/desk/crt_power_off.mp3")


var _click_sfx: AudioStreamPlayer


func _play_click_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	if _click_sfx == null or not is_instance_valid(_click_sfx):
		_click_sfx = AudioStreamPlayer.new()
		_click_sfx.volume_db = -6.0
		add_child(_click_sfx)
	_click_sfx.stream = load(path)
	_click_sfx.play()


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
	# By the front door as you come in (between the window and the door), not by the PC.
	switch_body.position = Vector3(0.93, 1.22, -2.46)
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
## A picture standing on the desk (camp/<tex>.png, turned to you as Build's sprites were),
## `pos` its foot; false (nothing made) if the picture is not there.
func _desk_cutout(parent: Node3D, tex: String, size: Vector2, pos: Vector3, node_name: String) -> bool:
	if not ResourceLoader.exists(INTERIOR_KIT.TEX + tex + ".png"):
		return false
	var mi := INTERIOR_KIT.cutout(parent, tex, size, pos, 0.0, true, node_name)
	mi.material_override = (mi.material_override as StandardMaterial3D).duplicate()
	return true


## In front of the PC, at the desk's front left by the keyboard (it stood back beside the
## monitor; playtest 19. 10.: "lampičku u kompu dát před komp, ne za něj").
const DESK_LAMP_AT := Vector3(-0.2, 0.82, -1.02)
var _desk_lamp_on := true
var _desk_lamp_shade: MeshInstance3D
var _desk_lamp_body: StaticBody3D


func _build_desk_lamp(pc_root: Node3D) -> void:
	var at := DESK_LAMP_AT
	# The lamp as a picture (Grok, camp/desk_lamp.png), lit by its own glow; the boxes if
	# the picture is not there.
	if _desk_cutout(pc_root, "desk_lamp", Vector2(0.38, 0.4), at, "DeskLampSprite"):
		_desk_lamp_shade = pc_root.get_node_or_null("DeskLampSprite") as MeshInstance3D
		# Not lit by its own bulb a hand away (that burnt it white): as bright as it is.
		(_desk_lamp_shade.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
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
		for n in ["DeskLampSprite", "DeskLampFoot", "DeskLampStem", "DeskLampShade", "DeskLampShadeLip", "DeskLampButton"]:
			var m := pc.get_node_or_null(n)
			if m != null:
				out.append(m)
	return out


func toggle_desk_lamp(sound := true) -> void:
	_desk_lamp_on = not _desk_lamp_on
	if sound:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/backroom/lamp_click.mp3") if ResourceLoader.exists("res://assets/sfx/backroom/lamp_click.mp3") else null
		p.volume_db = -6.0
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
	_sync_desk_lamp_look()
	_apply_room_time_profile(true)


## The lamp's picture: lit, as bright as it is (its own bulb a hand away burnt it white);
## off or with the power gone, as dark as the room round it (it was a dimmer picture
## glowing on its own in the dark: playtest 25. 10.). Kept up by _apply_room_time_profile.
func _sync_desk_lamp_look() -> void:
	if _desk_lamp_shade == null:
		return
	var m := _desk_lamp_shade.material_override as StandardMaterial3D
	if m == null:
		return
	var lit := _desk_lamp_on and _grid_power_available
	if _desk_lamp_shade.name == "DeskLampSprite":
		var room := 0.0
		if _room_environment != null:
			room = _room_environment.ambient_light_energy * 0.42
		if _office_lights_on and _grid_power_available:
			room += 0.4
		var v := clampf(0.06 + room, 0.06, 0.9)
		m.albedo_color = Color(0.92, 0.92, 0.88) if lit else Color(v, v, v * 1.02)
	else:
		m.emission_enabled = lit
		m.emission = Color(0.25, 0.7, 0.35)
		m.emission_energy_multiplier = 0.35


## Co-op: the office's lights, curtains and set, the same on both machines (main polls
## this and sends it when it changes, Coop.send_sync "office").
func coop_office_state() -> Dictionary:
	if _extras == null:
		return {}
	var back = _extras.back
	return {
		"lights": _office_lights_on, "desk": _desk_lamp_on,
		"oc": _office_curtain.is_open() if _office_curtain != null else true,
		"bc": back.curtain.is_open() if back != null and back.curtain != null else false,
		"lamp": bool(back.lamp_on) if back != null else true,
		"tv": bool(back.tv_on) if back != null else true,
		"bulb": bool(_extras.store.bulb_on) if _extras.store != null else false,
	}


## The other warden switched or drew something: the same here (heard only if you are in).
func coop_take_office_state(d: Dictionary) -> void:
	if _extras == null or d.is_empty():
		return
	var here := is_open()
	var back = _extras.back
	if d.has("lights") and bool(d["lights"]) != _office_lights_on:
		_toggle_office_lights()
	if d.has("desk") and bool(d["desk"]) != _desk_lamp_on:
		toggle_desk_lamp(here)
	if d.has("oc") and _office_curtain != null and bool(d["oc"]) != _office_curtain.is_open():
		_office_curtain.set_open(bool(d["oc"]), not here)
		_apply_room_time_profile()
	if back != null:
		if d.has("bc") and back.curtain != null and bool(d["bc"]) != back.curtain.is_open():
			back.curtain.set_open(bool(d["bc"]), not here)
		if d.has("lamp") and bool(d["lamp"]) != bool(back.lamp_on):
			back.set_lamp(bool(d["lamp"]))
			if here:
				back._play("lamp_click.mp3", -6.0)
		if d.has("tv") and bool(d["tv"]) != bool(back.tv_on):
			back._set_tv(bool(d["tv"]), here)
	if d.has("bulb") and _extras.store != null and bool(d["bulb"]) != bool(_extras.store.bulb_on):
		_extras.store.set_bulb(bool(d["bulb"]), here)


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
	if _extras != null and _extras.away():
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


# -- co-op: one radio for both -----------------------------------------------------

## What is on the host's set now (a song by its file, the station's pips, the night's
## broadcast by its pieces), counted so a new piece is a new number.
var _radio_now: Dictionary = {}
var _radio_now_n := 0
var _coop_radio_n := -1


func _radio_on_air(kind: String, id) -> void:
	_radio_now_n += 1
	_radio_now = {"k": kind, "id": id}


## For the other machine (main._coop_sync_things "radio", the host only): the switch,
## the piece and where in it (in 4 s steps, so it is sent when that moves on).
func coop_radio_state() -> Dictionary:
	var pos := _radio_player.get_playback_position() if _radio_player != null and _radio_player.playing else 0.0
	return {"on": _radio_power_on, "k": str(_radio_now.get("k", "")), "id": _radio_now.get("id", ""), "n": _radio_now_n, "pos": floorf(pos / 4.0) * 4.0}


## The other machine: the host's set, here (the same piece from the same place; nudged
## back into step if it drifts).
func coop_take_radio(d: Dictionary) -> void:
	if d.is_empty():
		return
	if bool(d.get("on", true)) != _radio_power_on:
		_toggle_radio_power()
	if _radio_player == null:
		_create_radio_player()
	if _radio_player == null:
		return
	var pos := float(d.get("pos", 0.0))
	var n := int(d.get("n", 0))
	if n != _coop_radio_n:
		_coop_radio_n = n
		var kind := str(d.get("k", ""))
		var stream: AudioStream = null
		match kind:
			"song":
				var path := str(d.get("id", ""))
				stream = _radio_stream_by_path.get(path, null)
				if stream == null and ResourceLoader.exists(path):
					stream = load(path)
				_radio_last_played_path = path
				var at := _radio_tracks_all_paths.find(path)
				_radio_current_track_is_night = at >= 0 and at < _radio_tracks_all_is_night.size() and bool(_radio_tracks_all_is_night[at])
			"station":
				stream = build_station_stream(int(d.get("id", 1)))
				_radio_last_played_path = ""
				_radio_current_track_is_night = false
			"interlude":
				var desc = d.get("id", [])
				stream = _dread.coop_play_interlude(desc if desc is Array else []) if _dread != null else null
				_radio_last_played_path = ""
				_radio_current_track_is_night = false
		if stream == null:
			return
		_radio_player.stream = stream
		_radio_player.play(minf(pos + 0.3, maxf(0.0, stream.get_length() - 0.5)))
		_radio_now = {"k": kind, "id": d.get("id", "")}
	elif _radio_player.playing:
		var here := _radio_player.get_playback_position()
		if here < pos - 0.6 or here > pos + 4.9:
			_radio_player.seek(pos + 0.3)


## The host: the other warden switched the set (Coop request "radio").
func coop_set_radio_power(on: bool) -> void:
	if on != _radio_power_on:
		_toggle_radio_power()


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
	# The switch by the door is the tube's alone: off is off, and the day through the
	# window and the desk lamp on its own switch are as they were (playtest 25. 10.: off at
	# night a ring of light stayed round the tube, 14 % of it; by day it took the daylight
	# down to a fifth). The tube's fill of the room is _apply_room_time_profile's, only
	# while it is on. With the power gone the lamps go too, the day does not.
	if not _office_lights_on:
		ceiling_target = 0.0
	if not _grid_power_available:
		ceiling_target = 0.0
		desk_target = 0.0
	var tubes_on := _office_lights_on and _grid_power_available
	if animated and tubes_on and not _fluoro_lit:
		# A tube comes on as tubes do: a blink, dark, two blinks, then on.
		_fluoro_flicker(ceiling_target)
		ceiling_target = -1.0
	else:
		_set_fluoro(tubes_on)
	if animated:
		if _office_light_tween != null and is_instance_valid(_office_light_tween):
			_office_light_tween.kill()
		_office_light_tween = create_tween()
		_office_light_tween.set_parallel(true)
		_office_light_tween.set_ease(Tween.EASE_IN_OUT)
		_office_light_tween.set_trans(Tween.TRANS_SINE)
		if _room_environment != null:
			_office_light_tween.tween_property(_room_environment, "ambient_light_energy", ambient_target, 0.68)
		if _ceiling_light != null and ceiling_target >= 0.0:
			_office_light_tween.tween_property(_ceiling_light, "light_energy", ceiling_target, 0.68)
		if _desk_lamp != null:
			_office_light_tween.tween_property(_desk_lamp, "light_energy", desk_target, 0.68)
		if _window_light != null:
			_office_light_tween.tween_property(_window_light, "light_energy", window_target, 0.68)
		return
	if _room_environment != null:
		_room_environment.ambient_light_energy = ambient_target
	if _ceiling_light != null and ceiling_target >= 0.0:
		_ceiling_light.light_energy = ceiling_target
	if _desk_lamp != null:
		_desk_lamp.light_energy = desk_target
	if _window_light != null:
		_window_light.light_energy = window_target


# ── the fluorescent tube light over the room ─────────────────────────────────
# Two tubes in a galvanised housing on the ceiling (the ceiling light's own source:
# _ceiling_light), on the main switch by the front door: lit, they glow cold white and
# hum; off (or the power gone), grey glass.

var _fluoro_mat: StandardMaterial3D
var _fluoro_hum: AudioStreamPlayer3D
var _fluoro_lit := true
var _fluoro_tween: Tween


func _build_fluorescent() -> void:
	var K := INTERIOR_KIT
	var at := Vector3(0.0, 2.72, 0.2)
	# No shadows from it: the light is just under it, and it would black out the ceiling.
	var housing: MeshInstance3D = K.slab(_room_root, Vector3(1.34, 0.06, 0.24), at, K.surface("galvanized", 1.4), "FluoroHousing")
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-0.66, 0.66]:
		var end: MeshInstance3D = K.slab(_room_root, Vector3(0.04, 0.05, 0.2), at + Vector3(x, -0.04, 0.0), K.surface("galvanized", 1.4), "FluoroEnd")
		end.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fluoro_mat = StandardMaterial3D.new()
	_fluoro_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fluoro_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for z in [-0.055, 0.055]:
		var tube := MeshInstance3D.new()
		tube.name = "FluoroTube"
		var bm := BoxMesh.new()
		bm.size = Vector3(1.26, 0.032, 0.032)
		tube.mesh = bm
		tube.material_override = _fluoro_mat
		tube.position = at + Vector3(0.0, -0.05, z)
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_room_root.add_child(tube)
	if ResourceLoader.exists("res://assets/sfx/world/lamp_buzz.mp3"):
		_fluoro_hum = AudioStreamPlayer3D.new()
		var st: AudioStream = load("res://assets/sfx/world/lamp_buzz.mp3")
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_fluoro_hum.stream = st
		_fluoro_hum.volume_db = -26.0
		_fluoro_hum.unit_size = 2.0
		_fluoro_hum.max_distance = 8.0
		_fluoro_hum.position = at
		_room_root.add_child(_fluoro_hum)
	_fluoro_lit = false
	_set_fluoro(true)


func _set_fluoro(lit: bool) -> void:
	if _fluoro_tween != null and is_instance_valid(_fluoro_tween) and _fluoro_tween.is_running():
		return
	_fluoro_glow(lit)


func _fluoro_glow(lit: bool) -> void:
	_fluoro_lit = lit
	if _fluoro_mat != null:
		_fluoro_mat.albedo_color = Color(0.94, 0.97, 1.0) if lit else Color(0.46, 0.47, 0.46)
	if _fluoro_hum != null and is_instance_valid(_fluoro_hum) and _fluoro_hum.is_inside_tree():
		if lit and not _fluoro_hum.playing:
			_fluoro_hum.play()
		elif not lit and _fluoro_hum.playing:
			_fluoro_hum.stop()


## Blink, dark, blink, blink, on (in the game's own steps), the room's light with it.
func _fluoro_flicker(energy: float) -> void:
	if _fluoro_tween != null and is_instance_valid(_fluoro_tween):
		_fluoro_tween.kill()
	_fluoro_tween = create_tween()
	for step in [[true, 0.06], [false, 0.16], [true, 0.05], [false, 0.09], [true, 0.04], [false, 0.22], [true, 0.0]]:
		var on: bool = step[0]
		_fluoro_tween.tween_callback(func() -> void:
			_fluoro_glow(on)
			if _ceiling_light != null:
				_ceiling_light.light_energy = energy if on else energy * 0.08)
		if float(step[1]) > 0.0:
			_fluoro_tween.tween_interval(float(step[1]))


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
	# Co-op: the other machine's set plays what the host's does (coop_take_radio).
	if Coop.is_client():
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
			_radio_on_air("song", RADIO_FIRST_TRACK)
			return
	if _try_play_station():
		return
	var interlude: AudioStream = _dread.take_interlude() if _dread != null else null
	if interlude != null:
		_radio_current_track_is_night = false
		_radio_last_played_path = ""
		_radio_player.stream = interlude
		_radio_player.play()
		_radio_on_air("interlude", _dread.interlude_desc())
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
	_radio_on_air("song", resolved_path)
	_radio_index = (selected_index + 1) % track_count


## In the reception the evening's music steps back for the radio (it played over it, the
## user 20. 10.): nearly gone with the radio on, a little lower with it off.
func _tick_music_duck(delta: float) -> void:
	var main := _resolve_main_runtime_host()
	var am = main.get("_audio_manager") if main != null else null
	if am == null or not am.has_method("set_ambient_music_duck"):
		return
	var target := 0.0
	if visible:
		target = -20.0 if _radio_power_on and _grid_power_available else -6.0
	am.set_ambient_music_duck(target, delta)


func _tick_radio_greetings() -> void:
	# The host's (or a lone warden's) set: the other machine follows it (coop_take_radio).
	if _radio_player == null or Coop.is_client():
		return
	var on_air := _radio_last_played_path == RADIO_GREETINGS_PATH and _radio_player.playing
	var at := _greetings_at(_hour_now())
	if at < 0.0:
		if on_air:
			# Its time is over (the clock jumped past it: the night skip, a load).
			_play_radio_next()
		return
	if on_air:
		if absf(_radio_player.get_playback_position() - at) > RADIO_GREETINGS_DRIFT_SEC:
			_radio_player.seek(at)
		return
	var s := _greetings_stream()
	if s == null or at > s.get_length() - RADIO_GREETINGS_TAIL_SEC:
		return
	_radio_current_track_is_night = true
	_radio_player.stream = s
	_radio_player.play(at)
	_radio_last_played_path = RADIO_GREETINGS_PATH
	_radio_on_air("song", RADIO_GREETINGS_PATH)


func _greetings_stream() -> AudioStream:
	var s: AudioStream = _radio_stream_by_path.get(RADIO_GREETINGS_PATH, null)
	if s == null and ResourceLoader.exists(RADIO_GREETINGS_PATH):
		s = load(RADIO_GREETINGS_PATH)
		_radio_stream_by_path[RADIO_GREETINGS_PATH] = s
	return s


## Seconds into the programme at `hour` had it gone on air at 0:30 (the clock's pace,
## BalanceConfig.GAME_MINUTES_PER_SECOND); -1 outside it.
func _greetings_at(hour: float) -> float:
	if hour < RADIO_GREETINGS_HOUR:
		return -1.0
	var s := _greetings_stream()
	if s == null:
		return -1.0
	var sec := (hour - RADIO_GREETINGS_HOUR) * 60.0 / BalanceConfig.GAME_MINUTES_PER_SECOND
	return sec if sec < s.get_length() else -1.0


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
	_radio_on_air("station", _count_guests_in_camp() + 1)
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
		if _is_radio_cursed_infravrany_path(path) or path.get_file().to_lower() == RADIO_GREETINGS_FILENAME:
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


## Asleep in the back room (the eyes shut while the night passes; co-op: on each machine
## its own warden's): the radio goes quiet as the eyes close (the user 21. 10.: "it played
## on right through the time skip"), and in the morning it is on another song.
var _radio_sleep_k := 0.0
var _radio_was_asleep := false
const RADIO_SLEEP_FADE_SEC := 1.0


func _eyes_shut() -> bool:
	var seq = _extras.get("sleep") if _extras != null else null
	if seq != null and seq.is_running() and seq.eyes_closing():
		return true
	# Or in a tent's, cabin's or caravan's bed (scripts/lodge_bed.gd, InteriorManager's).
	var lb = get_parent().get("lodge_bed") if get_parent() != null else null
	return lb != null and is_instance_valid(lb) and lb.has_method("eyes_shut") and bool(lb.eyes_shut())


func _update_radio_mix(delta: float) -> void:
	_ensure_radio_playback()
	var asleep := _eyes_shut()
	_radio_sleep_k = move_toward(_radio_sleep_k, 1.0 if asleep else 0.0, delta / RADIO_SLEEP_FADE_SEC)
	if _radio_was_asleep and not asleep:
		# Hours have gone by: not the same song where it was.
		_play_radio_next()
	_radio_was_asleep = asleep
	var target_db = _compute_radio_target_db()
	var character_db = _compute_radio_character_volume_offset(delta)
	character_db += linear_to_db(maxf(1.0 - _radio_sleep_k, 0.0001))
	var night_track_db = RADIO_NIGHT_TRACK_VOLUME_OFFSET_DB if _radio_current_track_is_night else 0.0
	if _dread != null:
		var sleep_db := linear_to_db(maxf(1.0 - _radio_sleep_k, 0.0001))
		_dread.update(
			delta, _radio_dread_context(delta),
			(target_db + sleep_db) if visible else RADIO_OUTSIDE_SILENT_DB,
			RADIO_OUTSIDE_SILENT_DB if visible else RADIO_OUTDOOR_VOLUME_DB,
			_radio_power_on and _grid_power_available, _resolve_main_building_node()
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
	# A blackout takes the radio with it (it played on through one: the user 20. 10.).
	if not _radio_power_on or not _grid_power_available:
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
		# Through the reception's walls, then the radio's own bus (its night's moods).
		_radio_outdoor.bus = WORLD_SOUNDS.wall_bus(RADIO_DREAD_SCRIPT.MUSIC_BUS)
		_radio_outdoor.unit_size = RADIO_OUTDOOR_UNIT_SIZE
		_radio_outdoor.max_distance = RADIO_OUTDOOR_MAX_DISTANCE
		_radio_outdoor.attenuation_filter_cutoff_hz = RADIO_OUTDOOR_FILTER_HZ
		_radio_outdoor.attenuation_filter_db = RADIO_OUTDOOR_FILTER_DB
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
	# The monitor's own power button (before the radio's box, which is forgiving).
	var hit0 = _raycast_room(event.position)
	var c0 = hit0.get("collider", null) as Node
	if c0 != null and _node_has_click_type(c0, "crt_power"):
		_toggle_monitor()
		return true
	# AABB hotspots take priority over the physics raycast: the props are small and
	# the collider mesh is easy to miss, so the box test is the forgiving path.
	if _is_mouse_over_radio(event.position):
		_toggle_radio_power()
		_play_click_sfx("res://assets/sfx/desk/radio_switch.mp3")
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
		# Co-op: the set is the host's; it switches there and comes back so.
		if Coop.is_client():
			Coop.send_request("radio", [_radio_power_on])
		return true
	if _node_has_click_type(collider, "reception_notebook"):
		open_checkin_desk()
		return true
	return false


## The desk close-up: the register, the keys, whoever is at the counter.
func open_checkin_desk() -> void:
	if _extras != null and _extras._partner_at_desk():
		_extras.coop_refuse("desk_busy")
		return
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
	var center_global = _room_root.to_global(_radio_click_center)
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
	if not visible or _crt_viewport == null or not _monitor_on:
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
## The second monitor on the desk or not (scripts/reception/post_delivery.gd asks every
## half second from the PC's own record, so a load, a new camp and the other warden's
## signature all come through here).
func set_second_monitor(on: bool) -> void:
	if on == _dual or _room_root == null:
		return
	_dual = on
	if on:
		_build_second_monitor()
	elif _crt2_root != null:
		_crt2_root.queue_free()
		_crt2_root = null
		_crt2_screen = null
		if _crt_look == 1:
			_crt_turn(0)
	_sync_crt_viewport_to_window()
	var mat := _crt_screen.material_override as ShaderMaterial if _crt_screen != null else null
	if mat != null:
		mat.set_shader_parameter("uv_rect", _screen_uv_rect(false))
	_place_radio()
	if _crt_ui != null and _crt_ui.has_method("set_dual"):
		_crt_ui.set_dual(on)


func has_second_monitor() -> bool:
	return _dual


## A used 15-inch in the same yellowed plastic, a shade greyer, on three phone books so
## its picture comes up level with the first's; the same tube glass, showing the right
## half of the CRT picture.
func _build_second_monitor() -> void:
	var pc_root := _room_root.get_node_or_null("PCCorner") as Node3D
	if pc_root == null:
		return
	var yaw := deg_to_rad(MON2_YAW_DEG)
	_crt2_root = Node3D.new()
	_crt2_root.name = "SecondMonitor"
	pc_root.add_child(_crt2_root)
	var mon := Node3D.new()
	mon.name = "CRTMonitor2"
	mon.position = MON2_PIVOT
	mon.rotation.y = yaw
	mon.scale = Vector3.ONE * MON2_SCALE
	_crt2_root.add_child(mon)
	_build_monitor_boxes(mon, Color(0.9, 0.9, 0.94))
	var body := StaticBody3D.new()
	body.name = "CRTMonitor2Body"
	body.position = MON2_PIVOT
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.86, 0.64, 0.66) * MON2_SCALE
	cs.shape = bs
	body.add_child(cs)
	_crt2_root.add_child(body)
	_crt2_screen = MeshInstance3D.new()
	_crt2_screen.name = "CRTScreen2"
	var scr_mesh := QuadMesh.new()
	scr_mesh.size = CRT_SCREEN_QUAD_SIZE
	scr_mesh.subdivide_width = 16
	scr_mesh.subdivide_depth = 12
	_crt2_screen.mesh = scr_mesh
	_crt2_screen.position = CRT_SCREEN_LOCAL_POS
	var scr_mat := ShaderMaterial.new()
	scr_mat.shader = load("res://materials/crt_glass.gdshader")
	scr_mat.set_shader_parameter("curve", CRT_CURVE)
	scr_mat.set_shader_parameter("bulge", CRT_BULGE)
	scr_mat.set_shader_parameter("screen_tex", _crt_viewport.get_texture())
	scr_mat.set_shader_parameter("uv_rect", Vector4(0.5, 0.0, 0.5, 1.0))
	scr_mat.set_shader_parameter("powered", 1.0 if _monitor_on else 0.0)
	_crt2_screen.material_override = scr_mat
	mon.add_child(_crt2_screen)
	# The phone books under its foot (the foot's underside is 0.40 below the pivot).
	var desk_top := 0.82
	var foot_y := MON2_PIVOT.y - 0.40 * MON2_SCALE
	var h := foot_y - desk_top
	var books := Node3D.new()
	books.name = "PhoneBooks"
	books.position = MON2_PIVOT + Vector3(0.0, 0.0, 0.06 * MON2_SCALE).rotated(Vector3.UP, yaw)
	books.position.y = desk_top
	books.rotation.y = yaw
	_crt2_root.add_child(books)
	var K := INTERIOR_KIT
	K.slab(books, Vector3(0.46, h, 0.34), Vector3(0.0, h * 0.5, 0.0), K.surface("cardboard", 0.4, Color(0.92, 0.84, 0.5)), "PhoneBookStack")
	_face(books, "phonebooks", Vector2(0.46, h), Vector3(0.0, h * 0.5, 0.171), 0.0)
	_face(books, "phonebooks", Vector2(0.34, h), Vector3(0.231, h * 0.5, 0.0), 90.0)
	# The seat in front of it: as far from its glass as from the first's (it is smaller,
	# so a little nearer), sat as at the first.
	var to_seat := Vector3(0.03, 0.0, 1.19 * MON2_SCALE + 0.05).rotated(Vector3.UP, yaw)
	_crt2_full_cam_pos = PC_OFFSET + MON2_PIVOT + to_seat + Vector3(0.0, 0.02, 0.0)
	_crt2_view_cam_pos = _crt2_full_cam_pos + to_seat.normalized() * 0.1 + Vector3(0.0, 0.02, 0.0)


## The radio on the desk's right end, or up on the second monitor once that stands there.
func _place_radio() -> void:
	if _radio_set == null:
		return
	if _dual:
		var yaw := deg_to_rad(MON2_YAW_DEG)
		_radio_set.position = PC_OFFSET + MON2_PIVOT + (Vector3(0.0, 0.28, 0.06) * MON2_SCALE).rotated(Vector3.UP, yaw)
		_radio_set.rotation_degrees.y = MON2_YAW_DEG
	else:
		_radio_set.position = PC_OFFSET + RADIO_AT
		_radio_set.rotation_degrees.y = 8.0
	_radio_click_center = _radio_set.position + Vector3(0.0, 0.11, 0.0)
	if _radio_power_click_body != null and is_instance_valid(_radio_power_click_body):
		_radio_power_click_body.position = _radio_click_center


func _build_monitor_boxes(body: Node3D = null, tint := Color.WHITE) -> void:
	var first := body == null
	if first:
		body = _crt_body
	var K := INTERIOR_KIT
	var plastic := K.surface("plastic", 0.35, tint)
	var vents := K.surface("monitor_side", 0.4, tint) if ResourceLoader.exists("res://assets/textury/camp/monitor_side.png") else K.surface("monitor_back", 0.4, tint)
	K.slab(body, Vector3(0.80, 0.60, 0.06), Vector3(0.0, 0.02, 0.32), plastic, "CRTFront")
	var front := _face(body, "monitor_front", Vector2(0.80, 0.60), Vector3(0.0, 0.02, 0.351), 0.0)
	(front.material_override as StandardMaterial3D).albedo_color = tint
	K.slab(body, Vector3(0.72, 0.52, 0.34), Vector3(0.0, 0.02, 0.12), vents, "CRTBody")
	K.slab(body, Vector3(0.46, 0.36, 0.26), Vector3(0.0, 0.02, -0.18), vents, "CRTBack")
	K.slab(body, Vector3(0.18, 0.08, 0.20), Vector3(0.0, -0.32, 0.06), plastic, "CRTNeck")
	K.slab(body, Vector3(0.40, 0.04, 0.32), Vector3(0.0, -0.38, 0.06), plastic, "CRTFoot")
	if first:
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
	if _extras != null and _extras.where == "store":
		return _extras.store.is_dark(_daylight_factor, _grid_power_available)
	return _time_state != TIME_DAY and not _crt_active and (not _office_lights_on or not _grid_power_available)


## The stove and whatever else office_dressing.gd makes clickable (reception_extras asks).
func dressing_click(id: String) -> bool:
	# The postman across the counter with the second monitor (post_delivery.gd).
	if id == "postman":
		return _post != null and _post.click_postman()
	return _dressing != null and _dressing.click(id)
