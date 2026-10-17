extends Node

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const GRID_MANAGER_SCRIPT = preload("res://scripts/grid_manager.gd")
const BUILDING_MANAGER_SCRIPT = preload("res://scripts/building_manager.gd")
const WORLD_GENERATOR_SCRIPT = preload("res://scripts/world_generator.gd")
const ECONOMY_MANAGER_SCRIPT = preload("res://scripts/economy_manager.gd")
const AUDIO_MANAGER_SCRIPT = preload("res://scripts/audio_manager.gd")
const ENEMY_DISTORTION_SHADER = preload("res://materials/enemy_noise_distortion.gdshader")
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const UTILITY_REPAIR_MINIGAME_SCRIPT = preload("res://scripts/utility_repair_minigame.gd")
const SEWER_PIPE_MINIGAME_SCRIPT = preload("res://scripts/sewer_pipe_minigame.gd")
const INTERIOR_MANAGER_SCRIPT = preload("res://scripts/interior_manager.gd")
const INTERACTION_CONTROLLER_SCRIPT = preload("res://scripts/interaction_controller.gd")
const SILENT_MAN_BRAIN_SCRIPT = preload("res://scripts/enemies/silent_man_brain.gd")
const TOURIST_BRAIN_SCRIPT = preload("res://scripts/enemies/tourist_brain.gd")
const GIRL_BRAIN_SCRIPT = preload("res://scripts/enemies/girl_brain.gd")
const STALKER_BRAIN_SCRIPT = preload("res://scripts/enemies/stalker_brain.gd")
## Which enemy a guest archetype brings. Two or more different ones in one night also
## bring the Antlered Man (stalker), the price of a camp booked without thought.
const ENEMY_FOR_ARCHETYPE := {
	"quiet_guy": SILENT_MAN_BRAIN_SCRIPT,
	"drunk": TOURIST_BRAIN_SCRIPT,
	"cheap_chick": GIRL_BRAIN_SCRIPT,
	"tramp": preload("res://scripts/enemies/whistler_brain.gd"),
	"family": preload("res://scripts/enemies/child_brain.gd"),
	"picker": preload("res://scripts/enemies/basket_brain.gd"),
}
const VISUAL_MODULE_SCRIPT = preload("res://modules/visual/visual_module.gd")
const LEGACY_UI_ADAPTER_SCRIPT = preload("res://modules/adapters/legacy_ui_adapter.gd")
const TIME_SYSTEM_SCRIPT = preload("res://core/systems/time_system.gd")
const WEATHER_SYSTEM_SCRIPT = preload("res://core/systems/weather_system.gd")
const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")
const WEATHER_VISUALS_SCRIPT = preload("res://scripts/weather_visuals.gd")
const HUD_MANAGER_SCRIPT = preload("res://scripts/hud_manager.gd")
const GUEST_AGENTS_SCRIPT = preload("res://scripts/guest_agents.gd")
const QUEST_MANAGER_SCRIPT = preload("res://scripts/quest_manager.gd")
const MAINTENANCE_CONTROLLER_SCRIPT = preload("res://scripts/maintenance_controller.gd")
const BLOOD_FX_SCRIPT = preload("res://scripts/blood_fx.gd")
const MENU_FLYTHROUGH_SCRIPT = preload("res://scripts/menu_flythrough.gd")
const SAVE_CODEC = preload("res://scripts/save_codec.gd")
const ELECTRICITY_BILLING_SCRIPT = preload("res://scripts/electricity_billing.gd")
const THREAT_SENSES_SCRIPT = preload("res://scripts/threat_senses.gd")
const NIGHT_JOBS_SCRIPT = preload("res://scripts/night_jobs.gd")
const CAMP_OFFICE_SCRIPT = preload("res://scripts/reception/camp_office.gd")
const LAKE_TRIP_SCRIPT = preload("res://scripts/lake/lake_trip.gd")
## Nights with nothing out there (and no night jobs): the first one.
const QUIET_NIGHTS := 1
const DAY_EVENTS_SCRIPT = preload("res://scripts/day_events.gd")
const WEEK_LEDGER_SCRIPT = preload("res://scripts/week_ledger.gd")
const SEASON_LOOK_SCRIPT = preload("res://scripts/season_look.gd")
const OMENS_SCRIPT = preload("res://scripts/omens.gd")
const CORN_HUNT_SCRIPT = preload("res://scripts/corn_hunt.gd")
const WEEK_REPORT_SCREEN_SCRIPT = preload("res://scripts/ui/week_report_screen.gd")
const BREAKER_PANEL_SCRIPT = preload("res://scripts/breaker_panel.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const MAIN_MENU_SCRIPT = preload("res://scripts/ui/main_menu.gd")
const PAUSE_MENU_SCRIPT = preload("res://scripts/ui/pause_menu.gd")
const GAME_OVER_SCREEN_SCRIPT = preload("res://scripts/ui/game_over_screen.gd")
const BOOT_SCREEN_SCRIPT = preload("res://scripts/ui/boot_screen.gd")
const MENU_THEME_PATH := "res://assets/sfx/ost/ambience3A.mp3"
const MENU_THEME_VOLUME_DB := -5.0
const SAVE_VERSION := 3
const AUTOSAVE_INTERVAL_SEC := 60.0
const WINDOW_TITLE := "Cursed Camp Manager Simulator"

@onready var _sub_viewport_container: SubViewportContainer = $SubViewportContainer
@onready var _world_3d: Node3D = $SubViewportContainer/SubViewport/World3D
@onready var world_environment: WorldEnvironment = $SubViewportContainer/SubViewport/World3D/WorldEnvironment
@onready var sun: DirectionalLight3D = $SubViewportContainer/SubViewport/World3D/Sun
@onready var fallback_camera: Camera3D = $SubViewportContainer/SubViewport/World3D/FallbackCamera

var _player: CharacterBody3D
var grid_manager: Node3D
var building_manager: Node3D
var world_generator: Node3D
var economy_manager: Node
const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const WEATHER_CLEAR: int = 0
const WEATHER_WINDY: int = 1
const WEATHER_FOG: int = 2
const WEATHER_LIGHT_RAIN: int = 3
const WEATHER_RAIN: int = 4
const WEATHER_STORM: int = 5
const WEATHER_EVENT: int = 6
const WEATHER_STATE_COUNT: int = 7
const UTILITY_REPAIRS_ENABLED: bool = false
const SEWER_PIPE_REPAIR_ENABLED: bool = true
const DEBUG_TIME_STEP_HOURS: float = 1.0
const PLAYER_MAX_HEALTH: int = 100
const DEBUG_DAMAGE_AMOUNT: int = 25
const DEBUG_MONEY_AMOUNT: int = 500
const DAMAGE_TIER_SMALL: int = 0
const DAMAGE_TIER_MEDIUM: int = 1
const DAMAGE_TIER_LARGE: int = 2
const DAMAGE_TIER_MEGA: int = 3
const DAMAGE_TIER_LETHAL: int = 4
const LAMP_FLASHLIGHT_START_HOUR: float = 19.5
const GAME_OVER_FALL_DELAY_FALLBACK_SEC: float = 1.2
const GAME_OVER_REASON_DEATH := "death"
const GAME_OVER_REASON_UPS := "ups_power_loss"
const INTERACT_DISTANCE: float = 3.4
const FIRST_PERSON_CAMERA_FAR: float = 1000.0
const LIMINAL_ARCHETYPE_QUIET_GUY := "quiet_guy"
var _time_state: int = TIME_DAY
var _time_of_day_hours: float = 9.0
var _day_index: int = 1
var _weather_state: int = WEATHER_CLEAR
var _utility_repair_minigame
var _sewer_pipe_minigame
var _texture_style
var _audio_manager
var _grid_was_powered := true
## Tools (shot driver): an unattended window loses focus all the time.
var pause_on_focus_loss := true

# New Systems
var time_system
var weather_system
var visual_module: Node
var legacy_ui_adapter: Node
var _startup_bootstrap_complete: bool = false
var _hud_manager: Node
var _weather_visuals: Node
var _interior_manager: Node
var _interaction_controller: Node
var _guest_agents: Node3D
var _quest_manager: Node
var _maintenance: Node
var _pending_quest_state: Dictionary = {}
var _pending_quest_state_loaded: bool = false
var _guest_quote_timer: float = 0.0
var _guest_quotes_shown: Dictionary = {}
var _menu_mode: bool = true
var _gameplay_started: bool = false
var _autosave_elapsed: float = 0.0
var _active_save_path: String = ""
var _menu_music_player: AudioStreamPlayer
var _menu_music_retry_pending: bool = false
var _main_menu: CanvasLayer
var _pause_menu: CanvasLayer
var _pause_prev_mouse := Input.MOUSE_MODE_CAPTURED
var _menu_flythrough: Node
var _pending_loaded_player_state: Dictionary = {}
var _pending_loaded_crt_state: Dictionary = {}
var _last_known_crt_desktop_state: Dictionary = {}
var _boot_screen: CanvasLayer
var _player_health: int = PLAYER_MAX_HEALTH
var _blood_fx: Node
var _game_over_active: bool = false
var _game_over_reason: String = GAME_OVER_REASON_DEATH
var _game_over_screen: CanvasLayer
var _liminal_forecast_snapshot: Dictionary = {}
var _liminal_forecast_hud_level: int = 0
var _liminal_forecast_rng := RandomNumberGenerator.new()
var _liminal_night_roll_snapshot: Dictionary = {}
var _liminal_spawn_history: Array[Dictionary] = []
var _liminal_virtual_enemy_count: int = 0
var _liminal_last_despawn_day: int = 0
var _liminal_last_despawn_count: int = 0
var _liminal_last_rolled_night_id: int = -99999
var _liminal_debug_layer: CanvasLayer
var _liminal_debug_panel: PanelContainer
var _liminal_debug_text: RichTextLabel
var _liminal_debug_visible: bool = false
var _liminal_debug_refresh_accum: float = 0.0
var _active_enemy_brain: RefCounted
var _active_enemy_brain_id: String = ""
var _enemy_brains: Array = []
var _senses = THREAT_SENSES_SCRIPT.new()
## The night's director (scripts/night/night_director.gd) and its hands (director_effects.gd).
var _director = preload("res://scripts/night/night_director.gd").new()
var _director_fx: Node
var _pending_director: Dictionary = {}
## The lost and found and its classifieds (scripts/bazaar.gd).
var _bazaar = preload("res://scripts/bazaar.gd").new()
var _pending_bazaar: Dictionary = {}
var _director_was_inside := false
var _night_jobs: Node
var _paper_map: Node
const PAPER_MAP_SCRIPT = preload("res://scripts/paper_map.gd")
var _breaker_panel: CanvasLayer
var _pending_night_jobs: Dictionary = {}
var _day_events: Node
var _pending_day_events: Dictionary = {}
var _week_ledger: Node
## The autumn on the camp (scripts/season_look.gd).
var _season_look: Node3D
var _pending_week_ledger: Dictionary = {}
var _week_report_screen: CanvasLayer
var _omens: Node
var _corn_hunt: Node
var _corn_job: Dictionary = {}
var _pending_omens: Dictionary = {}
## The office side of the reception: sleeping, the phone's consequences, the shed key.
var camp_office: Node
## Across the lake in the keeper's boat (scripts/lake/lake_trip.gd).
var _lake_trip: Node
var _pending_camp_office: Dictionary = {}
var _still_seconds: float = 0.0
var _still_last_pos: Vector3 = Vector3.INF
var _active_enemy_spawned_this_night: int = 0
var _lamp_flashlight_active: bool = false
var _lamp_grid_power_available: bool = true
var _billing: RefCounted = ELECTRICITY_BILLING_SCRIPT.new()


func _ready() -> void:
	# config/name stays "icloud ccs2": it names the user:// folder that holds saves.
	DisplayServer.window_set_title(WINDOW_TITLE)
	_apply_integer_canvas_scale()
	get_tree().root.size_changed.connect(_apply_integer_canvas_scale)
	add_child(HandCursor.new())
	_liminal_forecast_rng.randomize()
	_show_startup_loading_screen()
	await get_tree().process_frame
	await _bootstrap_runtime()
	_hide_startup_loading_screen()
	_startup_bootstrap_complete = true
	_enter_main_menu()


## The 2D layer (HUD, menus) is pixel art and must be scaled by whole numbers. The
## project stretches canvas_items from a 1280x720 base, which on a 1080p screen is a
## blurry 1.5x. Instead the logical size is chosen so the scale is always an integer and
## the window is still filled: 1080p -> 1920x1080 at 1x, 1440p -> 1280x720 at 2x,
## 4K -> 1280x720 at 3x. (The engine's own "integer" scale mode letterboxes instead.)
func _apply_integer_canvas_scale() -> void:
	var root := get_tree().root
	var win := root.size
	if win.x <= 0 or win.y <= 0:
		return
	var base := Vector2(1280.0, 720.0)
	var k := maxi(1, int(floor(minf(float(win.x) / base.x, float(win.y) / base.y))))
	var logical := Vector2i(int(ceil(float(win.x) / float(k))), int(ceil(float(win.y) / float(k))))
	if root.content_scale_size != logical:
		root.content_scale_size = logical


func _show_startup_loading_screen() -> void:
	if _boot_screen != null:
		return
	_boot_screen = BOOT_SCREEN_SCRIPT.new()
	add_child(_boot_screen)


func _hide_startup_loading_screen() -> void:
	if _boot_screen == null:
		return
	_boot_screen.queue_free()
	_boot_screen = null


func _bootstrap_runtime() -> void:
	time_system = TIME_SYSTEM_SCRIPT.new(CoreRoot.get_state())
	weather_system = WEATHER_SYSTEM_SCRIPT.new()
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)
	visual_module = VISUAL_MODULE_SCRIPT.new()
	add_child(visual_module)

	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	_ensure_input_actions()
	_setup_audio()

	if time_system:
		var day_tick_cb := Callable(self, "_on_day_tick")
		if not EventBus.day_tick.is_connected(day_tick_cb):
			EventBus.day_tick.connect(day_tick_cb)
	if EventBus.has_signal("night_tick"):
		var night_tick_cb := Callable(self, "_on_night_tick")
		if not EventBus.night_tick.is_connected(night_tick_cb):
			EventBus.night_tick.connect(night_tick_cb)
	if EventBus.has_signal("state_changed"):
		var state_changed_cb := Callable(self, "_on_eventbus_state_changed")
		if not EventBus.state_changed.is_connected(state_changed_cb):
			EventBus.state_changed.connect(state_changed_cb)

	_bind_or_create_managers()
	_bind_billing()
	_menu_flythrough = MENU_FLYTHROUGH_SCRIPT.new()
	_menu_flythrough.name = "MenuFlythrough"
	add_child(_menu_flythrough)
	_menu_flythrough.setup(fallback_camera, grid_manager, building_manager)
	_setup_weather_visuals_module()
	RETRO_RENDER.register(_sub_viewport_container)
	get_viewport().size_changed.connect(func() -> void: RETRO_RENDER.refresh_all(get_tree()))
	_generate_grid_world()
	_rebuild_core_cells_from_visual_structures()
	_setup_guest_agents()
	fallback_camera.current = true

	if _weather_visuals != null:
		_weather_visuals.update_state(_time_state, _time_of_day_hours, _weather_state)
		_weather_visuals.setup_celestial_bodies()
		_weather_visuals.setup_weather_particles()
		_weather_visuals.setup_static_lighting()
	if visual_module != null and visual_module.has_method("setup_enemy_fx"):
		visual_module.setup_enemy_fx(ENEMY_DISTORTION_SHADER)

	_day_index = CoreRoot.get_day()
	_sync_runtime_state_from_systems(true)
	_ensure_pause_menu()


func _start_gameplay_runtime() -> void:
	if _gameplay_started:
		return
	_stop_active_enemy_brain()
	_menu_mode = false
	_gameplay_started = true
	_game_over_active = false
	_game_over_reason = GAME_OVER_REASON_DEATH
	_clear_game_over_screen()
	_clear_blood_fx()
	_set_player_health(PLAYER_MAX_HEALTH, false)
	# Weather runs in play too (it used to be menu-only, leaving the whole weather
	# subsystem unseen in a real session). Transitions crossfade in WeatherVisuals.
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)
	_ensure_hud_manager()
	_bind_or_create_managers()

	if legacy_ui_adapter == null:
		legacy_ui_adapter = LEGACY_UI_ADAPTER_SCRIPT.new()
		legacy_ui_adapter.name = "LegacyUIAdapter"
		add_child(legacy_ui_adapter)

	_setup_interior_manager()
	_setup_interaction_controller()
	_setup_quest_manager()
	_setup_maintenance()
	_setup_night_jobs()
	_apply_pending_crt_desktop_state()
	if SEWER_PIPE_REPAIR_ENABLED:
		_setup_sewer_pipe_minigame()
	if UTILITY_REPAIRS_ENABLED:
		_setup_utility_repair_minigame()
	_spawn_player()
	# setup() is called again during player spawn rebind; enforce CRT state once more.
	_apply_pending_crt_desktop_state()
	call_deferred("_reapply_crt_desktop_state_next_frame")
	_apply_pending_loaded_player_state()
	_reset_player_damage_feedback()
	_refresh_electricity_power_cut_state(true)
	_sync_runtime_state_from_systems(true)
	_autosave_elapsed = 0.0


func _reapply_crt_desktop_state_next_frame() -> void:
	await get_tree().process_frame
	if not _gameplay_started:
		return
	_apply_pending_crt_desktop_state()


func _setup_quest_manager() -> void:
	if _quest_manager == null or not is_instance_valid(_quest_manager):
		_quest_manager = QUEST_MANAGER_SCRIPT.new()
		add_child(_quest_manager)
	_quest_manager.setup(self)
	if _pending_quest_state_loaded:
		_quest_manager.import_state(_pending_quest_state)
		_pending_quest_state.clear()
		_pending_quest_state_loaded = false


## Night work: the director and the distribution board (scripts/night_jobs.gd).
func _setup_paper_map() -> void:
	if _paper_map == null or not is_instance_valid(_paper_map):
		_paper_map = PAPER_MAP_SCRIPT.new()
		_paper_map.name = "PaperMap"
		add_child(_paper_map)
		_paper_map.setup(self)


func _setup_night_jobs() -> void:
	_setup_paper_map()
	if _night_jobs == null or not is_instance_valid(_night_jobs):
		_night_jobs = NIGHT_JOBS_SCRIPT.new()
		_night_jobs.name = "NightJobs"
		add_child(_night_jobs)
		_night_jobs.setup(self)
		_night_jobs.changed.connect(_on_night_jobs_changed)
		EventBus.building_failed.connect(func(_c, _t): _sync_dark_lamps())
		EventBus.building_serviced.connect(func(_c, _t, _b, _cost): _sync_dark_lamps())
	if _breaker_panel == null or not is_instance_valid(_breaker_panel):
		_breaker_panel = BREAKER_PANEL_SCRIPT.new()
		_breaker_panel.name = "BreakerPanel"
		add_child(_breaker_panel)
		_breaker_panel.fixed.connect(func(fault: int): _night_jobs.on_breaker_fixed(fault))
		_breaker_panel.closed.connect(func():
			if _breaker_panel.was_fixed() and _hud_manager != null:
				_hud_manager.push_status("Power back on. The breaker job is done.", 1)
			if _breaker_from_shed:
				_breaker_from_shed = false
				var shed = _interior_manager.get("_service_interior") if _interior_manager != null else null
				if shed != null and shed.has_method("on_breaker_board_closed"):
					shed.on_breaker_board_closed()
				return
			if _player != null and _player.has_method("set_controls_enabled"):
				_player.set_controls_enabled(true)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		)
	if _interior_manager != null:
		_interior_manager.structure_interact_override = Callable(self, "_on_structure_interact_override")
	if not _pending_night_jobs.is_empty():
		_night_jobs.import_state(_pending_night_jobs)
		_pending_night_jobs.clear()
	if _day_events == null or not is_instance_valid(_day_events):
		_day_events = DAY_EVENTS_SCRIPT.new()
		_day_events.name = "DayEvents"
		add_child(_day_events)
		_day_events.setup(self)
	if not _pending_day_events.is_empty():
		_day_events.import_state(_pending_day_events)
		_pending_day_events.clear()
	if _week_ledger == null or not is_instance_valid(_week_ledger):
		_week_ledger = WEEK_LEDGER_SCRIPT.new()
		_week_ledger.name = "WeekLedger"
		add_child(_week_ledger)
		_week_ledger.reset(int(CoreRoot.get_state().money) if CoreRoot.get_state() != null else 0)
	if not _pending_week_ledger.is_empty():
		_week_ledger.import_state(_pending_week_ledger)
		_pending_week_ledger.clear()
	if _omens == null or not is_instance_valid(_omens):
		_omens = OMENS_SCRIPT.new()
		_omens.name = "Omens"
		add_child(_omens)
		_omens.setup(self)
	if not _pending_omens.is_empty():
		_omens.import_state(_pending_omens)
		_pending_omens.clear()
	if _director_fx == null or not is_instance_valid(_director_fx):
		_director_fx = preload("res://scripts/night/director_effects.gd").new()
		_director_fx.name = "DirectorEffects"
		add_child(_director_fx)
		_director_fx.setup(self, _director)
	if not _pending_director.is_empty():
		_director.import_state(_pending_director)
		_pending_director.clear()
	if not _pending_bazaar.is_empty():
		_bazaar.import_state(_pending_bazaar)
		_pending_bazaar.clear()
	if not EventBus.guest_state_changed.is_connected(_on_guest_state_for_bazaar):
		EventBus.guest_state_changed.connect(_on_guest_state_for_bazaar)
	if _lake_trip == null or not is_instance_valid(_lake_trip):
		_lake_trip = LAKE_TRIP_SCRIPT.new()
		_lake_trip.name = "LakeTrip"
		add_child(_lake_trip)
		_lake_trip.setup(self)
	if camp_office == null or not is_instance_valid(camp_office):
		camp_office = CAMP_OFFICE_SCRIPT.new()
		camp_office.name = "CampOffice"
		add_child(camp_office)
		camp_office.setup(self)
	if not _pending_camp_office.is_empty():
		camp_office.import_state(_pending_camp_office)
		_pending_camp_office.clear()


## Day 8: the pager in the morning, Vera's report at 08:00 (scripts/week_ledger.gd).
func _tick_week_ledger() -> void:
	if _omens != null and not _game_over_active and _player != null and is_instance_valid(_player):
		var minute_of_day := int(round(_time_of_day_hours * 60.0))
		var abs_minute := (maxi(1, _day_index) - 1) * 1440 + minute_of_day
		var outdoors := not _is_any_interior_open() and not get_tree().paused
		_omens.tick(get_process_delta_time(), abs_minute, outdoors, _player.global_position, _omen_context())
		_tick_director()
	if _week_ledger == null or _game_over_active or _week_report_screen != null:
		return
	if _week_ledger.should_page(_day_index, _time_of_day_hours) and _hud_manager != null:
		_hud_manager.push_status("Pager: Vera's train gets in at eight. Leave the books on the desk.", 2)
	if _week_ledger.is_due(_day_index, _time_of_day_hours):
		_show_week_report()


## The night director: what it sees of the night and of you, then what it does.
func _tick_director() -> void:
	if _director == null or _director_fx == null or get_tree().paused:
		return
	var ctx := _director_context()
	var id: String = _director.tick(get_process_delta_time(), ctx)
	if id != "":
		var at: Vector3 = _director_fx.run(id, ctx)
		_director.watch(id, at)
		# The log names the guest who stood outside.
		if id == "guest_out" and not _director.log.is_empty():
			if at == Vector3.INF:
				_director.log.pop_back()
			else:
				_director.log.back()["who"] = str(_director_fx.guest_seen.get("name", "A guest"))


func _director_context() -> Dictionary:
	var hour := _time_of_day_hours
	var night := hour >= 21.0 or hour < 5.5
	# The camp's side (guests, pressure) changes slowly: twice a second is plenty.
	var now := Time.get_ticks_msec()
	if now - _dir_slow_at > 500 or _dir_slow.is_empty():
		_dir_slow_at = now
		_dir_slow = _director_slow_context()
	var base: Dictionary = _dir_slow["base"]
	var place := _director_place()
	var inside := place == "office" or place == "back_room"
	var entering := inside and not _director_was_inside
	_director_was_inside = inside or place == "modal"
	var pos: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	var vel: Vector3 = _player.velocity if _player != null else Vector3.ZERO
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var curtain = bi.get("_office_curtain") if bi != null else null
	var by_arch: Dictionary = _dir_slow["by_arch"]
	return {
		"night": night and _gameplay_started and not _game_over_active,
		"quiet": _day_index <= QUIET_NIGHTS,
		"hour": hour,
		"place": place,
		"pos": pos,
		"pressure": float(_dir_slow["pressure"]),
		"guests_by_arch": by_arch,
		"sleepers": _dir_slow.get("sleepers", []),
		"guest_sleeping": not (_dir_slow.get("sleepers", []) as Array).is_empty(),
		"admitted": int(base.get("admitted", 0)),
		"hunting": int(base.get("hunting", 0)),
		"hunter_near_m": float(_senses.nearest),
		"dark": bool(base.get("dark", false)),
		"lamp_near": building_manager != null and float(building_manager.get_light_level_at(pos)) > 0.2,
		"haunted_near": _day_events != null and place.begins_with("out") and _day_events.haunted_near(pos, 14.0) != Vector3.INF,
		"walking": Vector2(vel.x, vel.z).length() > 0.8,
		"window_open": curtain == null or float(curtain.get("open")) > 0.5,
		"looking_at_window": bi != null and bi.has_method("is_looking_at_window") and bi.is_looking_at_window(),
		"entering": entering,
	}


var _dir_slow: Dictionary = {}
var _dir_slow_at := 0


func _director_slow_context() -> Dictionary:
	var base := _omen_context()
	var by_arch := {}
	var sleepers: Array = []
	# Everyone checked in, awake or asleep: at night they are all "sleep".
	for g in CoreRoot.get_state().guests:
		if g is Dictionary and str((g as Dictionary).get("status", "")) in ["active", "sleep"]:
			var a := str((g as Dictionary).get("archetype", ""))
			by_arch[a] = int(by_arch.get(a, 0)) + 1
			if str((g as Dictionary).get("status", "")) == "sleep":
				sleepers.append({"id": int(g.get("id", -1)), "name": str(g.get("name", "")), "sprite_path": GuestManager._sprite_path_for_archetype(a)})
	return {"base": base, "by_arch": by_arch, "sleepers": sleepers, "pressure": OMENS_SCRIPT.pressure(base)}


## Where you are, for the director: office, back_room, out_lit, out_dark, or somewhere
## it leaves alone (modal: a close-up or the desk; job; lake; room: a guest's room).
func _director_place() -> String:
	if _lake_trip != null and _lake_trip.is_active():
		return "lake"
	if (_sewer_pipe_minigame != null and _sewer_pipe_minigame.is_open()) or (_utility_repair_minigame != null and _utility_repair_minigame.is_open()):
		return "job"
	if _breaker_panel != null and is_instance_valid(_breaker_panel) and _breaker_panel.visible:
		return "job"
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi != null and bi.is_open():
		var ex = bi.get("_extras")
		if ex != null and ex.is_modal():
			return "modal"
		return "back_room" if ex != null and ex.in_back_room() else "office"
	if _is_any_interior_open():
		return "room"
	var pos: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	return "out_lit" if building_manager != null and float(building_manager.get_light_level_at(pos)) > 0.2 else "out_dark"


## What the night presses on the camp with, for scripts/omens.gd.
func _omen_context() -> Dictionary:
	var mood: Dictionary = GuestManager.get_camp_mood_summary() if GuestManager != null and GuestManager.has_method("get_camp_mood_summary") else {}
	var hunting := 0
	for b in _enemy_brains:
		if b != null:
			hunting += 1
	return {
		"guests": int(mood.get("guests", 0)),
		"unhappy": int(mood.get("unhappy", 0)),
		"kinds_seen": _week_ledger.kinds_seen() if _week_ledger != null else 0,
		"nights_visited": _week_ledger.nights_visited() if _week_ledger != null else 0,
		"hunting": hunting,
		"dark": not _is_grid_powered(),
		"admitted": _desk_strangers_admitted(),
	}


## Those who came to the desk unbooked at night and were written in (checkin_desk.gd).
func _desk_strangers_admitted() -> int:
	var bi = _interior_manager._building_interior if _interior_manager != null and _interior_manager.get("_building_interior") != null else null
	return int(bi.desk_strangers_admitted()) if bi != null and bi.has_method("desk_strangers_admitted") else 0


func _show_week_report() -> void:
	if _week_report_screen != null:
		return
	_week_ledger.closed = true
	_week_report_screen = WEEK_REPORT_SCREEN_SCRIPT.new()
	_week_report_screen.setup(_week_ledger.report(CoreRoot.get_state()))
	_week_report_screen.stay_requested.connect(_on_week_report_stay)
	_week_report_screen.main_menu_requested.connect(_on_week_report_menu)
	add_child(_week_report_screen)
	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(false)
	get_tree().paused = true


func _close_week_report() -> void:
	if _week_report_screen != null:
		_week_report_screen.queue_free()
		_week_report_screen = null
	get_tree().paused = false


## Stay on: the week is closed, the camp runs on with no end (sandbox from here).
func _on_week_report_stay() -> void:
	_close_week_report()
	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(true)
	if not _is_any_interior_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _hud_manager != null:
		_hud_manager.push_status("Vera took the noon bus back to town. \"You know the way,\" she said.", 1)


func _on_week_report_menu() -> void:
	_close_week_report()
	_enter_main_menu()


func _tick_day_events() -> void:
	if _day_events == null:
		return
	var minute_of_day := _clock_minutes_from_hours(_time_of_day_hours)
	var abs_minute := (maxi(1, _day_index) - 1) * 1440 + minute_of_day
	var can_act := not _is_any_interior_open() and not get_tree().paused
	_day_events.tick(get_process_delta_time(), abs_minute, _time_state != TIME_NIGHT, _day_index, can_act)


func _tick_night_jobs() -> void:
	if _night_jobs == null:
		return
	var minute_of_day := _clock_minutes_from_hours(_time_of_day_hours)
	var abs_minute := (maxi(1, _day_index) - 1) * 1440 + minute_of_day
	var night_index := _day_index if minute_of_day >= 12 * 60 else _day_index - 1
	_night_jobs.tick(abs_minute, _time_state == TIME_NIGHT, night_index)


func _on_night_jobs_changed() -> void:
	var powered := _is_grid_powered()
	_note_grid_power(powered)
	if GuestManager != null and GuestManager.has_method("set_camp_power_available"):
		GuestManager.set_camp_power_available(powered)
	_apply_time_from_clock(true, false)
	_sync_dark_lamps()


## The moment the camp goes dark it makes the sound of it (power_out.mp3).
func _note_grid_power(powered: bool) -> void:
	if _grid_was_powered and not powered and _audio_manager != null and _audio_manager.has_method("play_power_out"):
		_audio_manager.play_power_out()
	_grid_was_powered = powered


func _is_grid_powered() -> bool:
	return not _billing.power_cut_active and not (_night_jobs != null and _night_jobs.breaker_tripped)


## Tools: where the lamps are (the shot driver's Expression cannot reach autoloads).
func _count_lamps_debug() -> Array:
	return CoreRoot.get_state().grid.lamp_coords()


func _cell_debug(x: int, y: int) -> Dictionary:
	return CoreRoot.get_state().grid.cells.get(Vector2i(x, y), {})


## Lamps dark for their own reasons: a lamp breakdown, or the circuit left off.
func _sync_dark_lamps() -> void:
	if building_manager == null or not building_manager.has_method("set_broken_lamps"):
		return
	var state = CoreRoot.get_state()
	var dark: Array = []
	var all_lamps: Array = []
	for coord in state.grid.lamp_coords():
		all_lamps.append("%d:%d" % [coord.x, coord.y])
	for key in state.failures.keys():
		if str(state.failures[key].get("type", "")) == "lamp_post":
			dark.append(str(key))
	if _night_jobs != null:
		dark.append_array(_night_jobs.extra_dark_lamps(all_lamps, int(grid_manager.grid_height)))
	building_manager.set_broken_lamps(dark)


## The generator shed is entered like any interior now: the distribution board is in
## its switch room (scripts/shed/generator_shed.gd), which calls open_breaker_board().
func _on_structure_interact_override(structure: Node3D) -> bool:
	# A guest waiting for you to look round their cabin (day_events "someone").
	if _day_events != null and structure != null and structure.has_meta("grid_origin"):
		var o = structure.get_meta("grid_origin")
		if o is Vector2i and _day_events.on_knock(o):
			return true
	return false


var _breaker_from_shed := false


## The board's close-up, from the shed's switch room.
func open_breaker_board() -> void:
	if _night_jobs == null or not _night_jobs.breaker_tripped:
		if _hud_manager != null:
			var dead: int = _night_jobs.dead_circuit if _night_jobs != null else -1
			_hud_manager.push_status("Every breaker is up and the main holds." if dead < 0 else "The main holds. One circuit stays down until Novotny has looked at it.", 1)
		return
	_breaker_from_shed = true
	_breaker_panel.open(_night_jobs.breaker_fault())


var _corn_rustle: AudioStreamPlayer
var _corn_rustle_t := 0.0


## Pushing through the camp's own corn: slower, and the stalks rustle round you.
func _update_corn_wading(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or grid_manager == null:
		return
	var in_corn := false
	var c: Vector2i = grid_manager.world_to_grid(_player.global_position)
	var tile = grid_manager.get_tile(c) if grid_manager.is_in_bounds(c) else null
	if tile != null and tile.occupant != null and is_instance_valid(tile.occupant) and (tile.occupant as Node).is_in_group("corn"):
		in_corn = true
	_player.set("terrain_speed_mult", 0.62 if in_corn else 1.0)
	var moving: bool = in_corn and _player is CharacterBody3D and (_player as CharacterBody3D).velocity.length() > 0.6
	if _corn_rustle == null:
		_corn_rustle = AudioStreamPlayer.new()
		_corn_rustle.volume_db = -9.0
		var path := "res://assets/sfx/world/corn_rustle.mp3"
		if ResourceLoader.exists(path):
			_corn_rustle.stream = load(path)
		add_child(_corn_rustle)
	_corn_rustle_t -= delta
	if moving and _corn_rustle_t <= 0.0 and _corn_rustle.stream != null:
		_corn_rustle_t = randf_range(0.45, 0.8)
		_corn_rustle.pitch_scale = randf_range(0.85, 1.15)
		_corn_rustle.play()


## For the HUD waypoint: the nearest open night job.
func night_job_waypoint() -> Dictionary:
	if _player == null or not is_instance_valid(_player):
		return {}
	var best: Dictionary = _night_jobs.waypoint(_player.global_position) if _night_jobs != null else {}
	var day: Dictionary = _day_events.waypoint(_player.global_position) if _day_events != null else {}
	if best.is_empty():
		return day
	if not day.is_empty() and _player.global_position.distance_to(day["position"]) < _player.global_position.distance_to(best["position"]):
		return day
	return best


func _setup_maintenance() -> void:
	if _maintenance == null or not is_instance_valid(_maintenance):
		_maintenance = MAINTENANCE_CONTROLLER_SCRIPT.new()
		_maintenance.name = "MaintenanceController"
		add_child(_maintenance)
	_maintenance.setup(_world_3d, building_manager, Callable(self, "_get_player_camera"), _hud_manager)
	if CoreRoot.failure_system != null:
		CoreRoot.failure_system.enabled = true


## Camp Status > Upkeep (CRT) reads and acts through these.
func get_upkeep_snapshot() -> Dictionary:
	if _maintenance == null:
		return {}
	return _maintenance.get_upkeep_snapshot()


func request_maintenance_crew() -> Dictionary:
	if _maintenance == null:
		return {"ok": false, "reason": "unavailable"}
	return _maintenance.request_maintenance_crew()


func _setup_guest_agents() -> void:
	if _guest_agents != null and is_instance_valid(_guest_agents):
		return
	_guest_agents = GUEST_AGENTS_SCRIPT.new()
	_world_3d.add_child(_guest_agents)
	_guest_agents.setup(grid_manager, Callable(self, "_now_abs_minutes_float"))


## Absolute game time in minutes (day 1 00:00 = 0), with the fractional minute.
func _now_abs_minutes_float() -> float:
	return float(maxi(1, _day_index) - 1) * 1440.0 + _time_of_day_hours * 60.0


func _find_guest_in_view() -> Dictionary:
	if _guest_agents == null or _is_any_interior_open():
		return {}
	var cam := _get_player_camera()
	if cam == null:
		return {}
	return _guest_agents.find_guest_in_view(cam, INTERACT_DISTANCE + 0.8)


## Duke3D-style quote line: what guests near the player just said shows in the HUD
## message feed once per utterance.
func _poll_guest_quotes(delta: float) -> void:
	_guest_quote_timer -= delta
	if _guest_quote_timer > 0.0:
		return
	_guest_quote_timer = 0.5
	if _guest_agents == null or _hud_manager == null or _player == null or _is_any_interior_open():
		return
	var lines: Array = _guest_agents.nearby_thoughts(_player.global_position, 9.0, 6)
	for entry_any in lines:
		var entry: Dictionary = entry_any
		var key := str(entry.get("key", ""))
		if _guest_quotes_shown.has(key):
			continue
		_guest_quotes_shown[key] = true
		if _guest_quotes_shown.size() > 200:
			_guest_quotes_shown.clear()
		if _hud_manager.has_method("show_quote"):
			_hud_manager.show_quote(str(entry.get("name", "")), str(entry.get("text", "")), float(entry.get("mood", 60.0)))
		else:
			_hud_manager.push_status("%s: \"%s\"" % [entry.get("name", ""), entry.get("text", "")])
		break


## Checking a party in at the barrier, by hand: the room has to be made up first.
func _check_in_guest(info: Dictionary) -> void:
	var res: Dictionary = GuestManager.request_check_in(int(info.get("id", -1)))
	var name_text := str(info.get("name", "Guest"))
	if _hud_manager == null:
		return
	if bool(res.get("ok", false)):
		var rooms: Array = []
		for r in res.get("rooms", []):
			rooms.append(str(r.get("label", "")))
		_hud_manager.push_status("Checked in: %s -> %s" % [name_text, ", ".join(rooms)])
		return
	if str(res.get("reason", "")) == "room_not_ready":
		var todo: Array = []
		for r in res.get("rooms", []):
			if not bool(r.get("ready", false)):
				todo.append(str(r.get("label", "")))
		_hud_manager.push_status("%s: \"Our room is not ready.\" Make up %s first." % [name_text, ", ".join(todo)])


func _talk_to_guest(info: Dictionary) -> void:
	if _quest_manager != null:
		_quest_manager.notify("talked_to_guest", info)
	if _day_events != null:
		_day_events.on_talked_to(info)
	if _hud_manager == null:
		return
	var name_text := str(info.get("name", "Guest"))
	var thought := str(info.get("thought", "")).strip_edges()
	if thought.is_empty():
		thought = "Nice evening." if _time_state != TIME_DAY else "Just looking around."
	var worst: Dictionary = info.get("worst_need", {})
	var need_line := ""
	if not worst.is_empty() and float(worst.get("value", 100.0)) < 55.0:
		need_line = "  [needs %s]" % str(worst.get("label", "")).to_lower()
	var line := "%s (%s): \"%s\"%s" % [name_text, str(info.get("mood_label", "")), thought, need_line]
	if _hud_manager.has_method("show_guest_card"):
		_hud_manager.show_guest_card(info)
	else:
		_hud_manager.push_status(line)


func _setup_weather_visuals_module() -> void:
	if _weather_visuals == null:
		_weather_visuals = WEATHER_VISUALS_SCRIPT.new()
		_weather_visuals.name = "WeatherVisuals"
		add_child(_weather_visuals)
	_weather_visuals.setup(
		world_environment,
		sun,
		_world_3d,
		null,
		Callable(self, "_get_player_ref"),
		fallback_camera,
		_audio_manager,
		grid_manager
	)
	if _season_look == null or not is_instance_valid(_season_look):
		_season_look = SEASON_LOOK_SCRIPT.new()
		_world_3d.add_child(_season_look)
		_season_look.setup(func(): return _player if _player != null else fallback_camera)


func _ensure_hud_manager() -> void:
	if _hud_manager != null:
		_sync_hud_health()
		_sync_liminal_forecast_hud(true)
		return
	_hud_manager = HUD_MANAGER_SCRIPT.new()
	_hud_manager.name = "HudManager"
	add_child(_hud_manager)
	_hud_manager.setup_interaction_hint()
	_hud_manager.setup_money_hud()
	_hud_manager.setup_weather_hud()
	_hud_manager.setup_time_hud()
	_hud_manager.set_camera_provider(Callable(self, "_get_player_camera"))
	_sync_hud_health()
	_sync_liminal_forecast_hud(true)


func _setup_interior_manager() -> void:
	if _interior_manager == null:
		_interior_manager = INTERIOR_MANAGER_SCRIPT.new()
		_interior_manager.name = "InteriorManager"
		add_child(_interior_manager)
		if _interior_manager.has_signal("service_repair_requested"):
			_interior_manager.service_repair_requested.connect(_on_service_repair_requested)
		if _interior_manager.has_signal("notice"):
			_interior_manager.notice.connect(func(text: String, kind: int) -> void:
				if _hud_manager != null:
					_hud_manager.push_status(text, kind)
			)
	if not _interior_manager.has_method("setup"):
		return
	_interior_manager.setup(
		_world_3d,
		_player,
		grid_manager,
		building_manager,
		legacy_ui_adapter,
		_audio_manager,
		economy_manager
	)
	if _interior_manager.has_method("setup_all"):
		_interior_manager.setup_all()


func _setup_interaction_controller() -> void:
	if _interaction_controller == null:
		_interaction_controller = INTERACTION_CONTROLLER_SCRIPT.new()
		_interaction_controller.name = "InteractionController"
		add_child(_interaction_controller)
	if _interaction_controller.has_method("setup"):
		_interaction_controller.setup(
			_world_3d,
			Callable(self, "_get_player_ref"),
			_interior_manager,
			building_manager,
			economy_manager
		)
	elif _interaction_controller.has_method("update_refs"):
		_interaction_controller.update_refs(_interior_manager, building_manager, economy_manager)


func _get_player_ref() -> Node:
	return _player


## The calendar into everything that shows the autumn (core/systems/season.gd).
func _sync_season() -> void:
	if _weather_visuals != null:
		_weather_visuals.season_day = _day_index
	if _season_look != null:
		_season_look.day = _day_index
		_season_look.hour = _time_of_day_hours
		var p := 0
		match _weather_state:
			WEATHER_LIGHT_RAIN:
				p = 1
			WEATHER_RAIN:
				p = 2
			WEATHER_STORM:
				p = 3
		_season_look.precip = p
		var w := 0.15
		match _weather_state:
			WEATHER_WINDY:
				w = 0.8
			WEATHER_RAIN:
				w = 0.5
			WEATHER_STORM:
				w = 1.4
		_season_look.wind = Vector2(0.94, 0.34) * w
	if _hud_manager != null:
		_hud_manager.snowing = is_snowing()


func is_snowing() -> bool:
	return _season_look != null and _season_look.is_snowing()


## Snow falls silently: the rain loops give way to the wind.
func _audio_weather() -> int:
	if not is_snowing():
		return _weather_state
	return WEATHER_WINDY if _weather_state == WEATHER_STORM or _weather_state == WEATHER_RAIN else WEATHER_CLEAR


func _process(delta: float) -> void:
	if not _startup_bootstrap_complete:
		return

	if _game_over_active:
		if _hud_manager != null:
			_hud_manager.set_world_hud_visible(false)
		return

	if time_system:
		time_system.process(delta)
	if weather_system:
		var state = CoreRoot.get_state()
		if state != null:
			weather_system.set_anomaly_pressure(float(state.hrotfaktor))
		weather_system.season_day = _day_index
		weather_system.process(delta * BALANCE_CONFIG.GAME_MINUTES_PER_SECOND, _time_of_day_hours)
	_sync_runtime_state_from_systems()
	_sync_season()
	if _weather_visuals != null:
		_weather_visuals.update_state(_time_state, _time_of_day_hours, _weather_state)
		_weather_visuals.update_frame(delta)

	if _menu_mode:
		_menu_flythrough.update(delta)
		return

	_process_electricity_runtime(delta)

	if _liminal_debug_visible:
		_liminal_debug_refresh_accum += maxf(delta, 0.0)
		if _liminal_debug_refresh_accum >= 0.35:
			_liminal_debug_refresh_accum = 0.0
			_refresh_liminal_debug_window()

	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(not _is_any_interior_open(), true)
	_update_player_control_lock()
	if not _is_any_interior_open() and not (_lake_trip != null and _lake_trip.is_active()):
		_sync_active_camera()
	_update_interaction_hint()
	_update_torch_hand()
	if _audio_manager != null and _audio_manager.has_method("process_runtime"):
		_audio_manager.process_runtime(
			delta,
			_audio_weather(),
			_is_audio_interior_active(),
			_should_play_rain_inside_loop(),
			_is_service_sewer_audio_active()
		)
	_tick_active_enemy_brain(delta)
	_update_corn_wading(delta)
	_update_threat_senses(delta)
	_sync_hud_player_meters()
	_poll_arrivals(delta)
	_tick_night_jobs()
	_tick_day_events()
	_tick_week_ledger()
	if _maintenance != null:
		_maintenance.tick(delta, not _is_any_interior_open() and not _game_over_active)
	_poll_guest_quotes(delta)
	if visual_module != null and visual_module.has_method("sync_enemy_distortion_fx"):
		visual_module.sync_enemy_distortion_fx(_time_state)
	_tick_autosave(delta)



func _unhandled_input(event: InputEvent) -> void:
	if not _startup_bootstrap_complete:
		return
	if _menu_mode:
		return
	if _game_over_active:
		return
	# Esc is always the pause menu (playtest 2026-10-17), indoors, at the PC, in a
	# close-up or a job: nothing else uses it. Leaving is S or the way out.
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	# Debug actions only exist in debug builds (see _ensure_input_actions).
	# Querying an unregistered action would push an InputMap error every frame.
	if OS.is_debug_build():
		if event.is_action_pressed("debug_damage_player"):
			_debug_damage_player()
			return

		if event.is_action_pressed("debug_add_money"):
			_debug_add_money()
			return

		if event.is_action_pressed("toggle_liminal_debug"):
			_toggle_liminal_debug_window()
			return

	# Block all gameplay input while any UI is open.
	if _is_any_interior_open():
		return

	if OS.is_debug_build():
		if event.is_action_pressed("toggle_day_night"):
			time_system.step_time_hours(DEBUG_TIME_STEP_HOURS)
			_sync_runtime_state_from_systems(true)

		if event.is_action_pressed("toggle_weather"):
			var next = (_weather_state + 1) % WEATHER_STATE_COUNT
			weather_system.set_weather(next)
			_sync_runtime_state_from_systems()

	if event.is_action_pressed("interact"):
		_try_interact()




func _clock_minutes_from_hours(hour_value: float) -> int:
	var normalized = fposmod(hour_value, 24.0)
	if normalized < 0.0:
		normalized += 24.0
	return int(floor(normalized * 60.0))


func _is_hour_in_window(hour_value: float, start_hour: float, end_hour: float) -> bool:
	var now = fposmod(hour_value, 24.0)
	if now < 0.0:
		now += 24.0
	var start = fposmod(start_hour, 24.0)
	if start < 0.0:
		start += 24.0
	var end = fposmod(end_hour, 24.0)
	if end < 0.0:
		end += 24.0
	if is_equal_approx(start, end):
		return true
	if start < end:
		return now >= start and now < end
	return now >= start or now < end


func _sync_runtime_state_from_systems(force: bool = false) -> void:
	var previous_hour = _time_of_day_hours
	var previous_time_state = _time_state
	var previous_weather = _weather_state
	var previous_day = _day_index

	if time_system:
		_time_of_day_hours = time_system.time_of_day_hours
		_time_state = time_system.time_state
	if weather_system:
		_weather_state = weather_system.current_weather

	_day_index = max(1, CoreRoot.get_day())

	var minute_changed = _clock_minutes_from_hours(previous_hour) != _clock_minutes_from_hours(_time_of_day_hours)
	var time_changed = force or minute_changed or (previous_time_state != _time_state)
	var weather_changed = previous_weather != _weather_state
	var day_changed = previous_day != _day_index

	if time_changed:
		var force_sky_snap = force or (absf(_time_of_day_hours - previous_hour) >= (DEBUG_TIME_STEP_HOURS - 0.001))
		var state_transition = force or (previous_time_state != _time_state)
		_apply_time_from_clock(state_transition, force_sky_snap)
		if state_transition:
			var gate := get_tree().get_first_node_in_group("camp_gate")
			if gate != null:
				# The gatehouse bulb is on from the evening lamps (19:30) to dawn.
				gate.set_night(_time_state == TIME_NIGHT or _time_of_day_hours >= 19.5)
		if previous_time_state == TIME_NIGHT and _time_state == TIME_DAY:
			_on_day_phase_started()
		if previous_time_state != TIME_NIGHT and _time_state == TIME_NIGHT and _day_events != null:
			_day_events.on_night()

	if weather_changed:
		_set_weather_state(_weather_state)
	elif force and _hud_manager != null:
		_hud_manager.update_weather(_weather_state)
	elif day_changed and not time_changed:
		if _hud_manager != null: _hud_manager.update_time(_time_of_day_string(), _day_index)

	if force or day_changed or time_changed:
		_sync_liminal_forecast_hud(force)

	if force or time_changed or weather_changed or day_changed:
		_emit_state_update()


func _spawn_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		_player = null
	_player = PLAYER_SCRIPT.new()
	if grid_manager != null and _player.has_method("set_grid_manager"):
		_player.set_grid_manager(grid_manager)
	if _player.has_method("ensure_runtime_setup"):
		_player.ensure_runtime_setup()
	if grid_manager != null and grid_manager.has_method("is_in_bounds") and grid_manager.has_method("grid_to_world"):
		var spawn_coord = world_generator.find_player_spawn_coord() if world_generator != null else Vector2i(10, 4)
		_player.position = grid_manager.grid_to_world(spawn_coord) + Vector3(0.0, 2.0, 0.0)
	else:
		_player.position = Vector3(0.0, 2.0, 0.0)
	_world_3d.add_child(_player)
	_face_player_toward_reception()
	if _interior_manager != null and _interior_manager.has_method("setup"):
		_interior_manager.setup(
			_world_3d,
			_player,
			grid_manager,
			building_manager,
			legacy_ui_adapter,
			_audio_manager,
			economy_manager
		)
	if _interaction_controller != null and _interaction_controller.has_method("setup"):
		_interaction_controller.setup(
			_world_3d,
			Callable(self, "_get_player_ref"),
			_interior_manager,
			building_manager,
			economy_manager
		)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	call_deferred("_sync_active_camera")


## New sessions start looking at the reception door (the first objective), not at
## whatever tree happened to be north of the spawn tile.
func _face_player_toward_reception() -> void:
	var door := get_reception_door_position()
	if _player == null or door == Vector3.INF:
		return
	var reception := _find_reception_structure()
	var out_dir := reception.global_transform.basis.z.normalized() if reception != null else Vector3(0, 0, 1)
	out_dir.y = 0.0
	_player.global_position = door + out_dir.normalized() * 5.0 + Vector3(0.0, 0.3, 0.0)
	var look := door - _player.global_position
	_player.rotation.y = atan2(-look.x, -look.z)


func _find_reception_structure() -> Node3D:
	if building_manager == null:
		return null
	var root := building_manager.get_node_or_null("Structures")
	if root == null:
		return null
	for child in root.get_children():
		var n := child as Node3D
		if n != null and str(n.get_meta("building_type", "")) == "main_building":
			return n
	return null


## World position of the reception door at ground level (Vector3.INF if missing).
func get_reception_door_position() -> Vector3:
	var reception := _find_reception_structure()
	if reception == null:
		return Vector3.INF
	var door := reception.get_node_or_null("Door") as Node3D
	var pos := door.global_position if door != null else reception.global_position
	pos.y = 0.0
	return pos


func _apply_pending_loaded_player_state() -> void:
	if _player == null or not is_instance_valid(_player):
		_pending_loaded_player_state.clear()
		return
	if _pending_loaded_player_state.is_empty():
		return

	var pos_any = _pending_loaded_player_state.get("position", {})
	if pos_any is Dictionary:
		var pos_dict := pos_any as Dictionary
		var loaded_pos := Vector3(
			float(pos_dict.get("x", _player.global_position.x)),
			float(pos_dict.get("y", _player.global_position.y)),
			float(pos_dict.get("z", _player.global_position.z))
		)
		var pos_valid := (
			not is_nan(loaded_pos.x) and not is_inf(loaded_pos.x)
			and not is_nan(loaded_pos.y) and not is_inf(loaded_pos.y)
			and not is_nan(loaded_pos.z) and not is_inf(loaded_pos.z)
		)
		if pos_valid and grid_manager != null:
			var map_center: Vector3 = grid_manager.get_map_center_world()
			var map_size: Vector2 = grid_manager.get_map_size_world()
			var max_dx := (map_size.x * 0.5) + 6.0
			var max_dz := (map_size.y * 0.5) + 6.0
			if absf(loaded_pos.x - map_center.x) > max_dx or absf(loaded_pos.z - map_center.z) > max_dz:
				pos_valid = false
		if pos_valid:
			_player.global_position = loaded_pos
	var loaded_yaw := float(_pending_loaded_player_state.get("yaw", _player.rotation.y))
	if not is_nan(loaded_yaw) and not is_inf(loaded_yaw):
		_player.rotation.y = loaded_yaw
	_pending_loaded_player_state.clear()


func _ensure_input_actions() -> void:
	_add_key_action("interact", KEY_E)
	_add_mouse_button_action("interact", MOUSE_BUTTON_LEFT)

	# Debug-only bindings. In a release build these must not exist: a player probing
	# the keyboard to discover controls would otherwise skip hours (T/U), reroll the
	# weather (Y), hand themselves money (K) or damage themselves (P).
	if OS.is_debug_build():
		_add_key_action("toggle_day_night", KEY_T)
		_add_key_action("toggle_day_night", KEY_U)
		_add_key_action("toggle_weather", KEY_Y)
		_add_key_action("debug_damage_player", KEY_P)
		_add_key_action("debug_add_money", KEY_K)
		_add_key_action("toggle_liminal_debug", KEY_L)
	_add_key_action("service_room_prev", KEY_A)
	_add_key_action("service_room_next", KEY_D)
	# Service interiors poll these on every key; an unregistered action is an engine
	# error per event, so they always exist (R only acts where something is broken).
	_add_key_action("service_repair", KEY_R)
	_add_key_action("service_kitchen_variant", KEY_P)
	_add_key_action("service_secret_room", KEY_S)
	_add_key_action("maintain", KEY_R)


func _add_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return

	var event = InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _add_mouse_button_action(action_name: String, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventMouseButton and existing_event.button_index == button_index:
			return

	var event = InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func _sync_hud_player_meters() -> void:
	if _hud_manager == null or _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("get_stamina_ratio"):
		_hud_manager.set_stamina_ratio(_player.get_stamina_ratio())
	if _player.has_method("get_flashlight_battery"):
		_hud_manager.set_light_ratio(_player.get_flashlight_battery())


## The night through the player's skin: insects fall silent near a presence, the HUD
## face widens its eyes and glances toward what you are not looking at.
func _update_threat_senses(delta: float) -> void:
	var outside_at_night := _time_state == TIME_NIGHT and not _is_any_interior_open() and not _game_over_active
	if _player != null and is_instance_valid(_player):
		var p := _player.global_position
		if p.distance_to(_still_last_pos) > 0.05:
			_still_last_pos = p
			_still_seconds = 0.0
		else:
			_still_seconds += maxf(delta, 0.0)
	_senses.update(
		delta,
		_enemy_brains if outside_at_night else [],
		_player.get_node_or_null("Head/Camera3D") as Camera3D if _player != null and is_instance_valid(_player) else null,
		_day_index if outside_at_night else -1,
		_still_seconds
	)
	if _audio_manager != null and _audio_manager.has_method("set_insect_hush"):
		var corn_hush: float = float(_corn_hunt.hush) if _corn_hunt != null and is_instance_valid(_corn_hunt) else 0.0
		var dir_hush: float = _director.hush() if _director != null and (_time_of_day_hours >= 21.0 or _time_of_day_hours < 5.5) else 0.0
		if _director_fx != null:
			dir_hush = maxf(dir_hush, float(_director_fx.extra_hush))
		_audio_manager.set_insect_hush(maxf(maxf(maxf(_senses.hush, _omens.hush if _omens != null else 0.0), corn_hush), dir_hush))
	if _hud_manager != null:
		_hud_manager.set_fear(_senses.fear)
		_hud_manager.set_face_gaze(_senses.gaze)


## The first time you leave the desk in a new game, the camp gets a title card.
var _first_stand_up_pending: bool = false
var _arrivals_poll: float = 0.0
var _arrival_events_bound: bool = false


## The arrivals panel, and a feed line (plus a sound) for each step of an arrival.
func _poll_arrivals(delta: float) -> void:
	if not _arrival_events_bound:
		_arrival_events_bound = true
		EventBus.guest_at_gate.connect(_on_guest_at_gate)
		EventBus.guest_checked_in.connect(_on_guest_checked_in)
		EventBus.guest_gave_up.connect(_on_guest_gave_up)
		EventBus.room_prepared.connect(_on_room_prepared)
	if _first_stand_up_pending and not _is_any_interior_open() and _hud_manager != null:
		_first_stand_up_pending = false
		_hud_manager.show_banner("THE CAMP", Season.date_long(_day_index).to_upper(), RETRO_UI.C_AMBER, 4.0)
	_arrivals_poll -= delta
	if _arrivals_poll > 0.0 or _hud_manager == null:
		return
	_arrivals_poll = 0.5
	_hud_manager.set_arrivals(GuestManager.get_arrivals())
	var day_rows: Array = _day_events.hud_rows() if _day_events != null else []
	if not day_rows.is_empty() and _time_state != TIME_NIGHT:
		_hud_manager.set_jobs(day_rows, "TODAY")
	elif _night_jobs != null:
		_hud_manager.set_jobs(_night_jobs.hud_rows())


func _on_guest_at_gate(row: Dictionary) -> void:
	if _hud_manager == null:
		return
	var rooms: Array = row.get("rooms", [])
	var not_ready: Array[String] = []
	for r in rooms:
		if not bool((r as Dictionary).get("ready", false)):
			not_ready.append(str((r as Dictionary).get("label", "")))
	var line := "%s is at reception." % str(row.get("name", "A guest"))
	if not not_ready.is_empty():
		line += " %s not ready." % ", ".join(not_ready)
	_hud_manager.push_status(line, 2 if not not_ready.is_empty() else 0, "arrivals")


func _on_guest_checked_in(guest: Dictionary) -> void:
	if _hud_manager != null:
		_hud_manager.push_status("%s checked in." % str(guest.get("name", "A guest")), 1, "arrivals")


func _on_guest_gave_up(row: Dictionary) -> void:
	if _hud_manager != null:
		_hud_manager.push_status("%s gave up waiting at reception and drove off." % str(row.get("name", "A guest")), 3, "arrivals")


func _on_room_prepared(key: String) -> void:
	if _hud_manager != null:
		_hud_manager.push_status("%s is ready." % GuestManager.room_label(key), 1, "rooms")


func _sync_hud_health() -> void:
	if _hud_manager == null or not _hud_manager.has_method("set_health_ratio"):
		return
	var ratio := float(_player_health) / float(PLAYER_MAX_HEALTH)
	_hud_manager.set_health_ratio(clampf(ratio, 0.0, 1.0))


func _on_eventbus_state_changed(changes: Dictionary) -> void:
	if changes.is_empty():
		return
	if changes.has("guests"):
		_sync_guest_accommodation_state()
		_sync_liminal_forecast_hud()


func _sync_liminal_forecast_hud(force: bool = false) -> void:
	if GuestManager == null or not GuestManager.has_method("get_liminal_forecast_data"):
		if force or not _liminal_forecast_snapshot.is_empty():
			_liminal_forecast_snapshot.clear()
			_liminal_forecast_hud_level = 0
			if _hud_manager != null and _hud_manager.has_method("set_liminal_forecast_count"):
				_hud_manager.set_liminal_forecast_count(0)
			_refresh_liminal_debug_window()
		return

	var payload_any = GuestManager.call("get_liminal_forecast_data")
	if not (payload_any is Dictionary):
		return
	var payload: Dictionary = payload_any
	var hud_level := clampi(int(payload.get("hud_level", 0)), 0, 4)
	if not force and payload == _liminal_forecast_snapshot and hud_level == _liminal_forecast_hud_level:
		return

	_liminal_forecast_snapshot = payload.duplicate(true)
	_liminal_forecast_hud_level = hud_level
	if _hud_manager != null and _hud_manager.has_method("set_liminal_forecast"):
		_hud_manager.set_liminal_forecast(payload)
	elif _hud_manager != null and _hud_manager.has_method("set_liminal_forecast_count"):
		_hud_manager.set_liminal_forecast_count(_liminal_forecast_hud_level)
	_refresh_liminal_debug_window()


func _on_night_tick(night_index: int) -> void:
	if not _gameplay_started or _menu_mode or _game_over_active:
		return
	if night_index == _liminal_last_rolled_night_id:
		return
	_sync_liminal_forecast_hud(true)
	_roll_liminal_night_spawn_snapshot(night_index)
	_activate_runtime_enemy_for_night(night_index)
	if _director != null:
		_director.begin_night(night_index)
	_refresh_liminal_debug_window()


func _roll_liminal_night_spawn_snapshot(night_index: int) -> void:
	var forecast: Dictionary = _liminal_forecast_snapshot.duplicate(true)
	if forecast.is_empty():
		_sync_liminal_forecast_hud(true)
		forecast = _liminal_forecast_snapshot.duplicate(true)

	var totals_any = forecast.get("totals", {})
	var totals: Dictionary = totals_any if totals_any is Dictionary else {}
	var entries_any = forecast.get("archetypes", [])
	var entries: Array = entries_any if entries_any is Array else []
	var rolled_entries: Array[Dictionary] = []
	var total_spawned := 0
	var total_guaranteed := 0
	var total_chance_spawns := 0
	var total_chance_checks := 0

	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var guaranteed = max(0, int(entry.get("guaranteed_spawns", 0)))
		var chance_probability = clampf(float(entry.get("chance_probability", 0.0)), 0.0, 1.0)
		var chance_roll := -1.0
		var chance_success := false
		var chance_spawn := 0
		if chance_probability > 0.0001:
			total_chance_checks += 1
			chance_roll = _liminal_forecast_rng.randf()
			chance_success = chance_roll <= chance_probability
			chance_spawn = 1 if chance_success else 0
			if chance_success:
				total_chance_spawns += 1
		var spawned = guaranteed + chance_spawn
		total_spawned += spawned
		total_guaranteed += guaranteed
		rolled_entries.append({
			"archetype": str(entry.get("archetype", "")),
			"label": str(entry.get("label", "Unknown")),
			"guest_count": int(entry.get("count", 0)),
			"expected_spawns": float(entry.get("expected_spawns", 0.0)),
			"chance_tier": str(entry.get("chance_tier", "none")),
			"chance_probability": chance_probability,
			"chance_roll": chance_roll,
			"chance_success": chance_success,
			"guaranteed_spawns": guaranteed,
			"spawned": spawned,
		})

	_liminal_night_roll_snapshot = {
		"night_id": night_index,
		"rolled_day": _day_index,
		"rolled_time": _time_of_day_string(),
		"expected_total": float(totals.get("expected_spawns", 0.0)),
		"spawned_total": total_spawned,
		"spawned_guaranteed": total_guaranteed,
		"spawned_from_chance": total_chance_spawns,
		"chance_checks": total_chance_checks,
		"entries": rolled_entries,
	}
	_liminal_virtual_enemy_count += total_spawned
	_liminal_last_rolled_night_id = night_index
	_liminal_spawn_history.append(_liminal_night_roll_snapshot.duplicate(true))
	while _liminal_spawn_history.size() > 8:
		_liminal_spawn_history.remove_at(0)


func _activate_runtime_enemy_for_night(night_index: int) -> void:
	_stop_active_enemy_brain()
	# The first night is quiet: nobody has been in the camp long enough to bring anything
	# with them. You read the mail, plan tomorrow and go to bed (DESIGN §3).
	if night_index <= QUIET_NIGHTS:
		_active_enemy_spawned_this_night = 0
		return
	var entries_any = _liminal_night_roll_snapshot.get("entries", [])
	var entries: Array = entries_any if entries_any is Array else []
	var total_spawned := 0
	var kinds := 0
	var worst := 1
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var spawned := int(entry.get("spawned", 0))
		var script = ENEMY_FOR_ARCHETYPE.get(str(entry.get("archetype", "")), null)
		if spawned <= 0 or script == null:
			continue
		var difficulty := maxi(_resolve_silent_man_difficulty(entry), _night_difficulty_floor())
		worst = maxi(worst, difficulty)
		_start_enemy_brain(script, night_index, difficulty, entry)
		total_spawned += spawned
		kinds += 1
	if kinds >= 2:
		_start_enemy_brain(STALKER_BRAIN_SCRIPT, night_index, mini(5, worst + kinds - 1), {})
	_active_enemy_spawned_this_night = total_spawned
	var claimed_virtual = mini(total_spawned, _liminal_virtual_enemy_count)
	_liminal_virtual_enemy_count = maxi(0, _liminal_virtual_enemy_count - claimed_virtual)


## What has come before comes back harder: every third night something came for the
## camp raises the floor (state, not the calendar).
func _night_difficulty_floor() -> int:
	var visited: int = _week_ledger.nights_visited() if _week_ledger != null else 0
	return clampi(1 + visited / 3, 1, 3)


func _resolve_silent_man_difficulty(entry: Dictionary) -> int:
	var guest_count = max(0, int(entry.get("guest_count", 0)))
	var chance_tier = str(entry.get("chance_tier", "none"))
	var spawned = max(0, int(entry.get("spawned", 0)))
	var difficulty := 1
	if guest_count >= 24:
		difficulty = 5
	elif guest_count >= 18:
		difficulty = 4
	elif guest_count >= 12:
		difficulty = 3
	elif guest_count >= 6:
		difficulty = 2
	if chance_tier == "medium":
		difficulty = maxi(difficulty, 3)
	elif chance_tier == "large":
		difficulty = maxi(difficulty, 4)
	if spawned >= 2:
		difficulty = mini(5, difficulty + 1)
	return clampi(difficulty, 1, 5)


func _start_enemy_brain(script: Script, night_index: int, difficulty: int, night_entry: Dictionary) -> void:
	var brain = script.new()
	if brain == null:
		return
	var seed = int(_liminal_forecast_rng.randi()) ^ (night_index * 7919) ^ (_day_index * 104729) ^ int(Time.get_ticks_msec()) ^ _enemy_brains.size()
	var refs := {
		"world_root": _world_3d,
		"player": _player,
		"grid_manager": grid_manager,
		"building_manager": building_manager,
		"audio_manager": _audio_manager,
		"damage_callable": Callable(self, "damage_player"),
		"is_night_callable": Callable(self, "_is_enemy_night_active"),
		"allow_actions_callable": Callable(self, "_can_enemy_runtime_actions"),
		"notify_callable": Callable(self, "_on_enemy_notice"),
		"night_entry": night_entry.duplicate(true),
	}
	if brain.has_method("start_night"):
		brain.start_night(seed, difficulty, refs)
	_enemy_brains.append(brain)
	if _week_ledger != null and brain.has_method("get_enemy_id"):
		_week_ledger.note_enemy(str(brain.get_enemy_id()), night_index)
	if _active_enemy_brain == null:
		_active_enemy_brain = brain
		_active_enemy_brain_id = str(brain.get_enemy_id()) if brain.has_method("get_enemy_id") else "?"


## An enemy's first sign of the night, as one feed line.
func _on_enemy_notice(text: String) -> void:
	if _hud_manager != null:
		_hud_manager.push_status(text, 2)


# ── the corn (night job, scripts/corn_hunt.gd) ───────────────────────────────

const CORN_WANDERERS := ["drunk", "family", "tramp", "picker"]


func _corn_field() -> Node:
	return find_child("CornField", true, false)


func _corn_wanderers() -> Array:
	var out: Array = []
	if GuestManager == null:
		return out
	for g in GuestManager.get_guest_life_snapshot():
		if CORN_WANDERERS.has(str(g.get("archetype", ""))) and str(g.get("status", "")) in ["active", "sleep"]:
			out.append(g)
	return out


func corn_hunt_possible() -> bool:
	return _corn_field() != null and not _corn_wanderers().is_empty()


func corn_gate_world() -> Vector3:
	var corn := _corn_field()
	return Vector3(corn.fence_x, 0.0, corn.gate_z) if corn != null else Vector3.INF


func start_corn_hunt(job: Dictionary) -> bool:
	var corn := _corn_field()
	var guests := _corn_wanderers()
	if corn == null or guests.is_empty():
		return false
	end_corn_hunt()
	var guest: Dictionary = guests[randi_range(0, guests.size() - 1)]
	var hunt := CORN_HUNT_SCRIPT.new()
	hunt.name = "CornHunt"
	add_child(hunt)
	if not hunt.setup(self, corn, guest):
		hunt.queue_free()
		return false
	_corn_hunt = hunt
	_corn_job = job
	job["guest_id"] = int(guest.get("id", -1))
	job["title"] = "%s is lost in the corn" % str(guest.get("name", "Someone"))
	hunt.finished.connect(_on_corn_hunt_finished)
	return true


func end_corn_hunt() -> void:
	if _corn_hunt != null and is_instance_valid(_corn_hunt):
		_corn_hunt.abandon()


func _on_corn_hunt_finished(rescued: bool) -> void:
	var hunt := _corn_hunt
	_corn_hunt = null
	if hunt == null:
		return
	var who := str(hunt.guest_name)
	if rescued:
		_corn_job["rescued"] = true
		GuestManager.apply_guest_event(int(hunt.guest_id), 15.0, "You came for me. In the dark. Thank you.")
		if _hud_manager != null:
			_hud_manager.push_status("%s is back in the camp, shaking. (mood +15)" % who, 1)
	else:
		GuestManager.apply_guest_event(int(hunt.guest_id), -18.0, "Nobody came. Something stood by me all night.")
		if _hud_manager != null:
			_hud_manager.push_status("At first light %s walked out of the corn alone. They won't say what they saw." % who, 3)
	hunt.queue_free()


## Debug/test entry: stand `dx` metres east of the wicket gate into the corn (negative:
## west, in the corn), facing west.
func debug_goto_corn_gate(dx: float) -> void:
	var corn = find_child("CornField", true, false)
	if corn == null or _player == null:
		return
	_player.global_position = Vector3(corn.fence_x + dx, 0.3, corn.gate_z)
	_player.rotation.y = deg_to_rad(90.0)


## Debug/test entry: stand on the maze path `dist` tiles before `at` (along the way from
## the entrance), facing it.
func debug_corn_face(at: Vector3, dist: float) -> void:
	var corn := _corn_field()
	if corn == null or _player == null:
		return
	var path: Array = corn.path_between(corn.entrance, corn.world_tile(at))
	var stand: Vector3 = corn.tile_world(path[maxi(0, path.size() - 1 - int(dist))]) if not path.is_empty() else at + Vector3(2, 0, 0)
	_player.global_position = stand + Vector3(0, 0.3, 0)
	var to := at - stand
	_player.rotation.y = atan2(-to.x, -to.z)


## Debug/test entry: stand at a spot of the corn walk: "exit" (the maze's far way out,
## facing west), "strip" (on the strip under the wires, facing the hut), "hut" (at its
## door). Returns where.
func debug_corn_spot(which: String) -> Vector3:
	var corn = find_child("CornField", true, false)
	if corn == null or _player == null:
		return Vector3.INF
	var p: Vector3
	var look: Vector3
	match which:
		"exit":
			p = corn.tile_world(corn.exit_tile) + Vector3(-0.2, 0, 0)
			look = p + Vector3(-10, 0, 0)
		"strip":
			p = Vector3(corn.line_x + 5.0, 0, corn.tile_world(corn.exit_tile).z)
			look = corn.booth_door
		_:
			p = corn.booth_door + Vector3(2.5, 0, 1.5)
			look = corn.booth_door
	_player.global_position = p + Vector3(0, 0.3, 0)
	var to := look - p
	_player.rotation.y = atan2(-to.x, -to.z)
	return p


func debug_player_y() -> float:
	return _player.global_position.y if _player != null else 0.0


## Debug/test entry: a camera high over the maze, looking down.
func debug_corn_overview() -> void:
	var corn = find_child("CornField", true, false)
	if corn == null:
		return
	var cam := Camera3D.new()
	_world_3d.add_child(cam)
	cam.fov = 62.0
	var c: Vector2 = corn.maze_rect.get_center()
	cam.global_position = Vector3(c.x + 16.0, 38.0, c.y)
	cam.look_at(Vector3(c.x, 0.0, c.y), Vector3.UP)
	if debug_camera != null and is_instance_valid(debug_camera):
		debug_camera.queue_free()
	debug_camera = cam


## Debug/test entry: a camera high over a grid tile, looking down at it (shot driver).
func debug_overview_tile(tile: Vector2i, height: float = 26.0) -> void:
	var cam := Camera3D.new()
	_world_3d.add_child(cam)
	cam.fov = 62.0
	var c: Vector3 = grid_manager.grid_to_world(tile)
	cam.global_position = Vector3(c.x, height, c.z - height * 0.45)
	cam.look_at(Vector3(c.x, 0.0, c.z), Vector3.UP)
	if debug_camera != null and is_instance_valid(debug_camera):
		debug_camera.queue_free()
	debug_camera = cam


## Debug/test entry: the render style (GameSettings is an autoload the shot driver can't reach).
func debug_render_preset(preset: String) -> void:
	GameSettings.set_retro_preset(preset, false)


## Debug/test entry: the first structure of a building type (e.g. the pre-placed generator).
## Tools: frame timing (ms) and fps, for the performance scenarios.
## Shot driver: what stands in the camp within r metres of the reception window's view.
func debug_near_window(r: float = 4.0) -> Array:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi == null:
		return []
	var xf: Transform3D = bi.get("_portal_xform")
	var at: Vector3 = xf * Vector3(-0.4, 1.0, -4.0)
	var out := []
	for n in find_children("*", "Node3D", true, false):
		var n3 := n as Node3D
		if n3.is_visible_in_tree() and (n3 is MeshInstance3D or n3 is StaticBody3D) and n3.global_position.distance_to(at) < r:
			out.append("%s<%s> %s" % [n3.name, n3.get_parent().name, n3.global_position.snapped(Vector3.ONE * 0.1)])
	return [at, out.slice(0, 30)]


## Shot driver: press and release a key through the real input path.
func debug_tap_key(key: int) -> void:
	for pressed in [true, false]:
		Input.parse_input_event(debug_key_event(key, pressed))


## Shot driver: the pointer mode (0 visible, 1 hidden, 2 captured).
func debug_mouse_mode() -> int:
	return Input.mouse_mode


## Shot driver: 2D drawn inside the small world view (it is scaled up with it).
func debug_world_2d() -> Array:
	var out := []
	var svc := get_node_or_null("SubViewportContainer")
	if svc == null:
		return out
	for n in svc.find_children("*", "CanvasItem", true, false):
		if n is Control or n is Node2D:
			var par := n.get_parent()
			if par is Control or par is Node2D:
				continue
			out.append(str(n.get_path()).replace("/root/Main/SubViewportContainer/SubViewport/", ""))
	for n in svc.find_children("*", "CanvasLayer", true, false):
		out.append("LAYER " + str(n.get_path()).replace("/root/Main/SubViewportContainer/SubViewport/", ""))
	return out


## Shot driver: hold or let go of the left button where the mouse is.
func debug_press_mouse(pressed: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = pressed
	b.position = get_viewport().get_mouse_position()
	b.global_position = b.position
	Input.parse_input_event(b)


## Shot driver: the mouse over a room task's mess (its first visible mesh).
func debug_aim_task(tasks: Node, task_id: String) -> Vector2:
	var t: Dictionary = tasks.get("_targets").get(task_id, {})
	if t.is_empty():
		return Vector2(-1, -1)
	var at: Vector3 = (t["body"] as Node3D).global_position
	for mm in t["meshes"]:
		if mm is MeshInstance3D and is_instance_valid(mm) and (mm as Node3D).is_visible_in_tree():
			at = (mm as Node3D).global_position
			break
	var cam: Camera3D = tasks.get("_camera")
	var p := debug_screen_of_cam(cam, at)
	get_viewport().warp_mouse(p)
	return p


## Shot driver: start a day event and say where its props stand ([pos, cell, what is
## on that cell]).
func debug_event_spot(kind: String) -> Array:
	var ev: Dictionary = _day_events.debug_start(kind)
	if ev.is_empty():
		return ["no event"]
	var pos: Vector3 = _day_events._event_pos(ev)
	var cell: Vector2i = grid_manager.world_to_grid(pos)
	var tile = grid_manager.get_tile(cell)
	var what := "free"
	if tile != null and tile.occupied and tile.occupant != null:
		what = str(tile.occupant.get_meta("building_type", tile.occupant.name))
	return [pos, cell, what, ev.get("coord")]


## Shot driver: the open Builder's map panel (or null).
func debug_builder_map() -> Node:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var ui = bi.get("_crt_ui") if bi != null else null
	if ui == null:
		return null
	for n in ui.find_children("*", "Control", true, false):
		if n.get_script() == load("res://scripts/crt_map_panel.gd"):
			return n
	return null


## Shot driver: close the OS's message boxes (the shareware nag).
func debug_close_msgboxes() -> int:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var ui = bi.get("_crt_ui") if bi != null else null
	if ui == null:
		return 0
	var n := 0
	for w in ui.get("_windows").get_children():
		if str(w.get("app_id")) == "msg":
			ui.call("_close_window", w) if ui.has_method("_close_window") else w.queue_free()
			n += 1
	return n


## Shot driver: the mouse over a Builder cell (the OS draws the map on the monitor).
func debug_mouse_to_builder_cell(cell: Vector2i) -> Vector2:
	var m := debug_builder_map()
	var bi = _interior_manager.get("_building_interior")
	if m == null or bi == null:
		return Vector2(-1, -1)
	var local: Vector2 = m.call("_cell_iso", Vector2(cell))
	var crt_pos: Vector2 = (m as Control).get_global_transform() * local
	var win: Vector2 = bi.call("debug_crt_to_window", crt_pos)
	get_viewport().warp_mouse(win)
	return win


## Shot driver: the till, and what the state says stands on a cell (autoloads are out of
## the driver's reach).
func debug_money() -> int:
	return int(CoreRoot.get_state().money)


func debug_cell_type(c: Vector2i) -> String:
	return str((CoreRoot.get_state().grid.cells.get(c, {}) as Dictionary).get("type", "-"))


## Shot driver: one line of how the night stands (time, director, place, health).
func debug_director_line() -> String:
	var sn: Dictionary = _director.snapshot()
	var last := ""
	if not (sn["recent"] as Array).is_empty():
		last = str((sn["recent"] as Array).back()["id"])
	var aw: Array = _director.arch_weights
	return "%s %s t=%.2f b=%.1f place=%s last=%s hp=%d hunters=%d near=%.0f p=%.2f arch=[%.2f %.2f %.2f %.2f] guests=%s" % [_time_of_day_string(), sn["state"], sn["tension"], sn["budget"], _director_place(), last, int(_player_health), _enemy_brains.size(), float(_senses.nearest),
		float(_dir_slow.get("pressure", 0.0)), aw[0], aw[1], aw[2], aw[3], str(_dir_slow.get("by_arch", {}))]


## Shot driver: how many guests are in the camp, and set the day.
func debug_guest_count() -> int:
	return GuestManager.get_guest_life_snapshot().size()


func debug_guest_statuses() -> Array:
	var out: Array = []
	for g in CoreRoot.get_state().guests:
		if g is Dictionary:
			out.append([str(g.get("name", "")), str(g.get("status", "")), str(g.get("archetype", "")), int(g.get("party_size", 0))])
	return out


## What stands on these grid cells (the visual occupants), for blocked builds.
func debug_occupants(coords: Array) -> Array:
	var out: Array = []
	var g = CoreRoot.get_state().grid
	for c in coords:
		var o = g.occupants.get(c, null)
		out.append(str((o as Node).get_path()).right(70) + ":" + str((o as Node).get_child(0).name if (o as Node).get_child_count() > 0 else "") if o is Node else "-")
	return out


## Shot driver: move the player `frac` of the way to a node under the world (on the ground).
func debug_player_toward(node_name: String, frac: float) -> float:
	var n := _world_3d.get_node_or_null(node_name) as Node3D
	if n == null or _player == null:
		return -1.0
	var to := n.global_position
	to.y = _player.global_position.y
	_player.global_position = _player.global_position.lerp(to, frac)
	return _player.global_position.distance_to(to)


## Shot driver, save round trip: mark the newer state (the director's memory and log, the
## reputation, a reported cabin, DataPunch's nights), save, scramble it in memory, and load
## the save through the main menu as a player would. `debug_saved_bits` reads it back.
func debug_mark_saved_bits() -> void:
	_director.ever["knock"] = 3
	_director.last_log = [{"time": "01:12", "id": "guest_out", "who": "Pepa"}]
	EmailManager.reputation = 0.17
	_day_events.haunted["10:6"] = 3
	var os = _interior_manager._building_interior.get("_crt_ui")
	if os != null:
		os.set_meta("datapunch_nights", {"3": 12})


func debug_saved_bits() -> Array:
	var os = _interior_manager._building_interior.get("_crt_ui")
	return [int(_director.ever.get("knock", 0)), _director.last_log.duplicate(true), snappedf(EmailManager.reputation, 0.01), _day_events.haunted.duplicate(),
		os.get_meta("datapunch_nights", {}) if os != null else "no os"]


func debug_save_and_reload() -> String:
	var path := request_manual_save("Roundtrip")
	_director.ever.clear()
	_director.last_log = []
	EmailManager.reputation = 0.0
	_day_events.haunted.clear()
	var os = _interior_manager._building_interior.get("_crt_ui")
	if os != null:
		os.set_meta("datapunch_nights", {})
	_enter_main_menu()
	_on_menu_load_requested(path)
	return path


## Shot driver, the bazaar: things in the lost and found, the browser on a page, a link.
func debug_bazaar_fill(n: int) -> int:
	var guard := 0
	while _bazaar.in_box().size() < n and guard < 200:
		_bazaar.on_checkout(["Pepa", "Vlasta", "Novak family"][guard % 3], ["Cabin 10:6", "Tent 16:6", "Cabin 13:6"][guard % 3], _day_index)
		guard += 1
	return _bazaar.in_box().size()


var _debug_browser: Control = null


func debug_browser(url: String) -> bool:
	var w = _interior_manager._building_interior._crt_ui.open_app("browser")
	if w == null or w.content.get_child_count() == 0:
		return false
	_debug_browser = w.content.get_child(0)
	_debug_browser.navigate(url)
	return true


func debug_browser_link(target: String) -> void:
	if _debug_browser != null:
		_debug_browser._on_link(target)


func debug_bazaar() -> Array:
	return [_bazaar.in_box().map(func(i): return [i["id"], i["short"]]), _bazaar.listed().map(func(i): return i["short"]), _bazaar.sold().map(func(i): return [i["short"], i["price"]]), int(CoreRoot.get_state().money)]


## Shot driver: interior meshes whose box corners land in a screen rect of `cam`
## (fractions of the screen), with their global AABB, to hunt z-fighting.
func debug_meshes_in_rect(cam: Camera3D, rect: Rect2, root: Node) -> Array:
	var out: Array = []
	var vp := cam.get_viewport()
	var size := vp.get_visible_rect().size
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if not m.is_visible_in_tree():
			continue
		var bb := m.global_transform * m.get_aabb()
		var hit := false
		for i in 8:
			var c := bb.get_endpoint(i)
			if cam.is_position_behind(c):
				continue
			var sp := cam.unproject_position(c) / size
			if rect.has_point(sp):
				hit = true
				break
		if hit:
			out.append([str(m.get_path()).right(60), bb.position.snapped(Vector3.ONE * 0.001), bb.size.snapped(Vector3.ONE * 0.001)])
	return out


## Shot driver: a node's mesh children, names and global centres (model debugging).
func debug_parts(n: Node) -> Array:
	var out: Array = []
	if n == null:
		return out
	for m in n.find_children("*", "VisualInstance3D", true, false):
		var v := m as VisualInstance3D
		out.append([str(v.name), (v as Node3D).global_position.snapped(Vector3.ONE * 0.01), v.visible])
	return out


## Shot driver: every checked-in party goes to the first `building_type` now and stays
## `minutes` there (the sim's own visit activity, already arrived).
func debug_send_guests_to(building_type: String, minutes: int = 120) -> int:
	var life = GuestManager.get("_life")
	if life == null:
		return 0
	life.refresh_world(CoreRoot.get_state(), CoreRoot.registry)
	var fs: Array = (life.get("_facilities") as Array).filter(func(f): return str(f["type"]) == building_type)
	if fs.is_empty():
		return 0
	var f: Dictionary = fs[0]
	var now: int = GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute)
	var n := 0
	var state = CoreRoot.get_state()
	for i in state.guests.size():
		var g: Dictionary = state.guests[i]
		if not str(g.get("status", "")) in ["active", "sleep"]:
			continue
		var here: Vector2i = life._parse_key(str(g.get("tile", "")))
		var act: Dictionary = life._make_activity("visit", here, life._door_tile(f, here), now - 20, minutes, "fun", f)
		act["arrive"] = now - 1
		act["end"] = now + minutes
		g["activity"] = act
		g["status"] = "active"
		state.guests[i] = g
		n += 1
	return n


func debug_guest_thoughts() -> Array:
	var out: Array = []
	for g in CoreRoot.get_state().guests:
		if g is Dictionary:
			out.append([str(g.get("name", "")), str(g.get("thought", ""))])
	return out


func debug_set_day(day: int) -> void:
	CoreRoot.apply_changes({"day": maxi(1, day)})
	_sync_runtime_state_from_systems(true)


## Shot driver: play a director event now, as the director would ([where, place]).
func debug_director(id: String) -> Array:
	var ctx := _director_context()
	var at: Vector3 = _director_fx.run(id, ctx)
	return [at, ctx.get("place", "")]


## Shot driver: CampStat on one of its tabs.
func debug_campstat_tab(id: String) -> void:
	var bi = _interior_manager.get("_building_interior")
	var ui = bi.get("_crt_ui") if bi != null else null
	if ui == null:
		return
	for n in ui.find_children("*", "Control", true, false):
		if n.get_script() == load("res://scripts/os98/apps/campstat_app.gd"):
			for i in n.TABS.size():
				if str(n.TABS[i][0]) == id:
					n._tabs.current_tab = i
			n.refresh()


## Shot driver: a key press or release for Input.parse_input_event.
func debug_key_event(key: int, pressed: bool) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = key
	k.physical_keycode = key
	k.pressed = pressed
	return k


## Shot driver: a real click (press and release) at a window point.
func debug_click_at(x: float, y: float, button := MOUSE_BUTTON_LEFT) -> void:
	get_viewport().warp_mouse(Vector2(x, y))
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = button
		b.pressed = pressed
		b.position = Vector2(x, y)
		b.global_position = b.position
		Input.parse_input_event(b)


## Shot driver: the Control under the mouse (what eats a click), as a path.
func debug_hovered_control() -> String:
	var c := get_viewport().gui_get_hovered_control()
	return str(c.get_path()) if c != null else "<none>"


## Shot driver: where a 3D point is on the window through a camera that may render
## into the small retro viewport.
func debug_screen_of_cam(cam: Camera3D, p: Vector3) -> Vector2:
	if cam == null:
		return Vector2(-1, -1)
	var own := cam.get_viewport().get_visible_rect().size
	return cam.unproject_position(p) * get_viewport().get_visible_rect().size / own


## Shot driver: where a 3D point is on the window through the current camera.
func debug_screen_of(p: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(p) if cam != null else Vector2(-1, -1)


func debug_perf() -> Array:
	return [Engine.get_frames_per_second(), snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01), snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


## Tools: real input through the whole pipeline (a small mouse move, a click, a key).
func debug_input(kind: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	match kind:
		"move":
			var m := InputEventMouseMotion.new()
			m.position = vp * 0.5 + Vector2(randf_range(-3, 3), 1)
			m.global_position = m.position
			m.relative = Vector2(1.5, 0.5)
			Input.parse_input_event(m)
		"click":
			for pressed in [true, false]:
				var b := InputEventMouseButton.new()
				b.button_index = MOUSE_BUTTON_LEFT
				b.pressed = pressed
				b.position = vp * 0.5
				b.global_position = b.position
				Input.parse_input_event(b)
		"key":
			for pressed in [true, false]:
				var k := InputEventKey.new()
				k.physical_keycode = KEY_SHIFT
				k.keycode = KEY_SHIFT
				k.pressed = pressed
				Input.parse_input_event(k)


## Parties on the way or at reception, and who waits at the desk (shot driver).
func debug_arrivals() -> Array:
	return [GuestManager.get_arrivals(), GuestManager.get_desk_queue().size(), GuestManager.get_key_board()]


## What the core grid holds at these cells, and the money (shot driver).
func debug_cells(coords: Array) -> Array:
	var out: Array = []
	for c in coords:
		out.append(str(CoreRoot.get_state().grid.get_cell_data(c).get("type", "-")))
	out.append(CoreRoot.get_money())
	return out


## The bulldozer over a rect, as the Builder would (shot driver, harnesses).
func debug_demolish_rect(rect: Rect2i) -> void:
	EventBus.RequestDemolish.emit(rect)


func debug_structure_of_type(building_type: String) -> Node3D:
	var root = building_manager.get_node_or_null("Structures") if building_manager != null else null
	if root == null:
		return null
	for child in root.get_children():
		if str(child.get_meta("building_type", "")) == building_type:
			return child
	return null


## Debug/test entry: put the clock on `day` at `hours` (no nights are played in between).
func debug_jump_to(day: int, hours: float) -> void:
	CoreRoot.apply_changes({"day": maxi(1, day)})
	if time_system != null:
		time_system.set_time_hours(hours)
	_sync_runtime_state_from_systems(true)


## Debug/test entry: start one enemy now regardless of the night roll.
func debug_spawn_enemy(enemy_id: String, difficulty: int = 3) -> void:
	var scripts := {"silent_man": SILENT_MAN_BRAIN_SCRIPT, "tourist": TOURIST_BRAIN_SCRIPT, "girl": GIRL_BRAIN_SCRIPT, "stalker": STALKER_BRAIN_SCRIPT,
		"whistler": ENEMY_FOR_ARCHETYPE["tramp"], "child": ENEMY_FOR_ARCHETYPE["family"], "basket": ENEMY_FOR_ARCHETYPE["picker"]}
	if scripts.has(enemy_id):
		_start_enemy_brain(scripts[enemy_id], _day_index, difficulty, {})


func _tick_active_enemy_brain(delta: float) -> void:
	for brain in _enemy_brains:
		if brain != null and brain.has_method("tick"):
			brain.tick(delta)


func _stop_active_enemy_brain() -> void:
	for brain in _enemy_brains:
		if brain != null and brain.has_method("stop_night"):
			brain.stop_night()
	_enemy_brains.clear()
	_senses.reset()
	_active_enemy_brain = null
	_active_enemy_brain_id = ""


func _is_enemy_night_active() -> bool:
	return _gameplay_started and not _menu_mode and not _game_over_active and _time_state == TIME_NIGHT


func _can_enemy_runtime_actions() -> bool:
	if not _is_enemy_night_active():
		return false
	if _is_any_interior_open():
		return false
	if _lake_trip != null and _lake_trip.is_active():
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	return true


func _on_day_phase_started() -> void:
	if not _gameplay_started or _menu_mode:
		return
	_stop_active_enemy_brain()
	if _director_fx != null:
		_director_fx.clear()
	# The bazaar's buyers called in the night: what sold is paid at dawn.
	_settle_bazaar()
	if _night_jobs != null:
		if _week_ledger != null:
			_week_ledger.note_jobs_left(_night_jobs.open_jobs().size())
		_night_jobs.on_dawn()
	if _player != null and _player.has_method("recharge_flashlight"):
		_player.recharge_flashlight()
	# A night survived: you slept it off (or didn't sleep at all). Wounds mend by morning.
	if _player_health < PLAYER_MAX_HEALTH and not _game_over_active:
		_set_player_health(PLAYER_MAX_HEALTH, false)
		if _hud_manager != null:
			_hud_manager.push_status("Morning. You patched yourself up with Vera's first-aid box.", 1)
	var removed_scene_enemies = _despawn_all_runtime_enemies()
	var removed_virtual = _liminal_virtual_enemy_count
	_liminal_virtual_enemy_count = 0
	_active_enemy_spawned_this_night = 0
	_liminal_last_despawn_count = removed_scene_enemies + removed_virtual
	_liminal_last_despawn_day = _day_index
	_refresh_liminal_debug_window()


func _despawn_all_runtime_enemies() -> int:
	if get_tree() == null:
		return 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var removed := 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var node := enemy as Node
		if node == null:
			continue
		node.queue_free()
		removed += 1
	if removed > 0 and visual_module != null and visual_module.has_method("setup_enemy_fx"):
		visual_module.setup_enemy_fx(ENEMY_DISTORTION_SHADER)
	return removed


func _toggle_liminal_debug_window() -> void:
	_set_liminal_debug_window_visible(not _liminal_debug_visible)


func _set_liminal_debug_window_visible(visible: bool) -> void:
	_liminal_debug_visible = visible
	_liminal_debug_refresh_accum = 0.0
	if not _liminal_debug_visible:
		if _liminal_debug_layer != null:
			_liminal_debug_layer.visible = false
		return
	_ensure_liminal_debug_window()
	if _liminal_debug_layer != null:
		_liminal_debug_layer.visible = true
	_refresh_liminal_debug_window()


func _ensure_liminal_debug_window() -> void:
	if _liminal_debug_layer != null:
		return
	_liminal_debug_layer = CanvasLayer.new()
	_liminal_debug_layer.name = "LiminalDebugLayer"
	_liminal_debug_layer.layer = 90
	add_child(_liminal_debug_layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_liminal_debug_layer.add_child(root)

	_liminal_debug_panel = PanelContainer.new()
	_liminal_debug_panel.name = "LiminalDebugPanel"
	_liminal_debug_panel.anchor_left = 0.0
	_liminal_debug_panel.anchor_top = 0.0
	_liminal_debug_panel.anchor_right = 0.0
	_liminal_debug_panel.anchor_bottom = 0.0
	_liminal_debug_panel.offset_left = 14.0
	_liminal_debug_panel.offset_top = 14.0
	_liminal_debug_panel.offset_right = 640.0
	_liminal_debug_panel.offset_bottom = 420.0
	_liminal_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_liminal_debug_panel.add_theme_stylebox_override("panel", RETRO_UI.flat_box(Color(0.05, 0.05, 0.05, 0.84), Color(0.52, 0.10, 0.10, 0.95), 2, 1, 3))
	root.add_child(_liminal_debug_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_liminal_debug_panel.add_child(margin)

	_liminal_debug_text = RichTextLabel.new()
	_liminal_debug_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_liminal_debug_text.bbcode_enabled = false
	_liminal_debug_text.scroll_active = true
	_liminal_debug_text.fit_content = false
	_liminal_debug_text.selection_enabled = false
	_liminal_debug_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_liminal_debug_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_liminal_debug_text.add_theme_font_size_override("normal_font_size", 14)
	_liminal_debug_text.add_theme_color_override("default_color", Color(0.94, 0.94, 0.94, 1.0))
	margin.add_child(_liminal_debug_text)

	_liminal_debug_layer.visible = _liminal_debug_visible


func _refresh_liminal_debug_window() -> void:
	if _liminal_debug_text == null:
		return
	var lines: Array[String] = []
	var state_name := "day"
	match _time_state:
		TIME_EVENING:
			state_name = "evening"
		TIME_NIGHT:
			state_name = "night"
		_:
			state_name = "day"
	lines.append("Liminal Forecast Debug [L]")
	lines.append("Day %d | %s | phase=%s" % [_day_index, _time_of_day_string(), state_name])

	var forecast: Dictionary = _liminal_forecast_snapshot
	if forecast.is_empty():
		lines.append("")
		lines.append("Forecast: unavailable")
	else:
		var totals_any = forecast.get("totals", {})
		var totals: Dictionary = totals_any if totals_any is Dictionary else {}
		lines.append("")
		lines.append("Forecast Summary:")
		lines.append("Guests=%d | expected transforms=%.2f | guaranteed=%d | pressure archetypes=%d | HUD=%d/4" % [
			int(totals.get("guests", 0)),
			float(totals.get("expected_spawns", 0.0)),
			int(totals.get("guaranteed_spawns", 0)),
			int(totals.get("pressure_archetypes", 0)),
			_liminal_forecast_hud_level,
		])
		lines.append("Archetypes:")
		var entries_any = forecast.get("archetypes", [])
		var entries: Array = entries_any if entries_any is Array else []
		for entry_any in entries:
			if not (entry_any is Dictionary):
				continue
			var entry: Dictionary = entry_any
			var label = str(entry.get("label", "Unknown"))
			var count = int(entry.get("count", 0))
			var over_safe = int(entry.get("over_safe", 0))
			var expected = float(entry.get("expected_spawns", 0.0))
			var guaranteed = int(entry.get("guaranteed_spawns", 0))
			var chance_probability = clampf(float(entry.get("chance_probability", 0.0)), 0.0, 1.0)
			var chance_tier = str(entry.get("chance_tier", "none"))
			lines.append("- %s | guests=%d (+%d over safe) | should transform=%.2f | guaranteed=%d | chance=%d%% (%s)" % [
				label,
				count,
				over_safe,
				expected,
				guaranteed,
				int(round(chance_probability * 100.0)),
				chance_tier,
			])

	lines.append("")
	lines.append("Night Roll:")
	if _liminal_night_roll_snapshot.is_empty():
		lines.append("No night roll yet.")
	else:
		lines.append("Night #%d at %s | spawned=%d (guaranteed=%d + chance=%d/%d) | expected=%.2f" % [
			int(_liminal_night_roll_snapshot.get("night_id", 0)),
			str(_liminal_night_roll_snapshot.get("rolled_time", "--:--")),
			int(_liminal_night_roll_snapshot.get("spawned_total", 0)),
			int(_liminal_night_roll_snapshot.get("spawned_guaranteed", 0)),
			int(_liminal_night_roll_snapshot.get("spawned_from_chance", 0)),
			int(_liminal_night_roll_snapshot.get("chance_checks", 0)),
			float(_liminal_night_roll_snapshot.get("expected_total", 0.0)),
		])
		var rolled_entries_any = _liminal_night_roll_snapshot.get("entries", [])
		var rolled_entries: Array = rolled_entries_any if rolled_entries_any is Array else []
		for rolled_any in rolled_entries:
			if not (rolled_any is Dictionary):
				continue
			var rolled: Dictionary = rolled_any
			var roll_value = float(rolled.get("chance_roll", -1.0))
			var roll_text = "-" if roll_value < 0.0 else "%.3f" % roll_value
			lines.append("- %s | spawned=%d | guaranteed=%d | chance=%d%% | roll=%s" % [
				str(rolled.get("label", "Unknown")),
				int(rolled.get("spawned", 0)),
				int(rolled.get("guaranteed_spawns", 0)),
				int(round(clampf(float(rolled.get("chance_probability", 0.0)), 0.0, 1.0) * 100.0)),
				roll_text,
			])
		if not _liminal_spawn_history.is_empty():
			lines.append("Recent nights:")
			for i in range(_liminal_spawn_history.size() - 1, maxi(_liminal_spawn_history.size() - 4, -1), -1):
				var hist = _liminal_spawn_history[i]
				lines.append("- night #%d: spawned %d (expected %.2f)" % [
					int(hist.get("night_id", 0)),
					int(hist.get("spawned_total", 0)),
					float(hist.get("expected_total", 0.0)),
				])

	var active_enemy_count := 0
	if get_tree() != null:
		active_enemy_count = get_tree().get_nodes_in_group("enemies").size()
	lines.append("")
	lines.append("Runtime Enemies Active=%d (virtual=%d, scene=%d)" % [
		_liminal_virtual_enemy_count + active_enemy_count,
		_liminal_virtual_enemy_count,
		active_enemy_count,
	])
	lines.append("Runtime target this night (quiet guy): %d" % _active_enemy_spawned_this_night)
	if _active_enemy_brain != null and is_instance_valid(_active_enemy_brain) and _active_enemy_brain.has_method("get_debug_snapshot"):
		var snap_any = _active_enemy_brain.get_debug_snapshot()
		var snap: Dictionary = snap_any if snap_any is Dictionary else {}
		var state_label = str(snap.get("state", "unknown"))
		lines.append("Active brain: %s | state=%s" % [_active_enemy_brain_id, state_label])
		lines.append("- scares=%d (recent=%d) | peeks=%d | attack_hits=%d" % [
			int(snap.get("successful_scares", 0)),
			int(snap.get("recent_successes", 0)),
			int(snap.get("close_peeks", 0)),
			int(snap.get("damage_hits", 0)),
		])
		lines.append("- footsteps=%d | visual_spawns=%d | entity_visible=%s" % [
			int(snap.get("footstep_bursts", 0)),
			int(snap.get("visual_spawns", 0)),
			str(bool(snap.get("entity_visible", false))),
		])
	if _liminal_last_despawn_day > 0:
		lines.append("Last day-start despawn: day %d -> removed %d enemies" % [_liminal_last_despawn_day, _liminal_last_despawn_count])

	_liminal_debug_text.text = "\n".join(lines)


func _set_player_health(value: int, allow_game_over: bool = true) -> void:
	var previous_health := _player_health
	_player_health = clampi(value, 0, PLAYER_MAX_HEALTH)
	_sync_hud_health()
	var damage_amount: int = maxi(0, previous_health - _player_health)
	if damage_amount > 0 and _gameplay_started and not _menu_mode:
		var fatal_hit := _player_health <= 0
		_emit_player_damage_feedback(damage_amount, fatal_hit)
	if allow_game_over and _player_health <= 0:
		_trigger_game_over(GAME_OVER_REASON_DEATH)


func damage_player(amount: int) -> void:
	if amount <= 0:
		return
	if _week_ledger != null:
		_week_ledger.note_hit(amount)
	_set_player_health(_player_health - amount)


func _resolve_damage_tier(damage_amount: int, fatal_hit: bool) -> int:
	if fatal_hit:
		return DAMAGE_TIER_LETHAL
	if damage_amount >= 48:
		return DAMAGE_TIER_MEGA
	if damage_amount >= 28:
		return DAMAGE_TIER_LARGE
	if damage_amount >= 14:
		return DAMAGE_TIER_MEDIUM
	return DAMAGE_TIER_SMALL


func _emit_player_damage_feedback(damage_amount: int, fatal_hit: bool) -> void:
	var tier := _resolve_damage_tier(damage_amount, fatal_hit)
	if _player != null and _player.has_method("play_damage_feedback"):
		_player.play_damage_feedback(tier, damage_amount, fatal_hit)
	_spawn_blood_damage_fx(tier, fatal_hit)


func _reset_player_damage_feedback() -> void:
	if _player != null and _player.has_method("reset_damage_feedback_state"):
		_player.reset_damage_feedback_state()


func _debug_damage_player() -> void:
	if not _gameplay_started or _menu_mode or _game_over_active:
		return
	damage_player(DEBUG_DAMAGE_AMOUNT)


func _debug_add_money() -> void:
	if not _gameplay_started or _menu_mode or _game_over_active:
		return
	if CoreRoot == null or CoreRoot.actions == null or not CoreRoot.actions.has_method("add_money"):
		return
	CoreRoot.actions.add_money(DEBUG_MONEY_AMOUNT)
	_refresh_liminal_debug_window()


func _trigger_game_over(reason: String = GAME_OVER_REASON_DEATH) -> void:
	if _game_over_active:
		return
	_stop_active_enemy_brain()
	_game_over_active = true
	_game_over_reason = reason
	_set_liminal_debug_window_visible(false)
	var delay_sec := GAME_OVER_FALL_DELAY_FALLBACK_SEC
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(false)
	if _player != null and _player.has_method("play_death_fall"):
		delay_sec = maxf(0.0, float(_player.play_death_fall()))
	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(false)
		_hud_manager.set_hint_text("")
	call_deferred("_finalize_game_over_sequence", delay_sec)


func _finalize_game_over_sequence(delay_sec: float) -> void:
	if delay_sec > 0.001:
		await get_tree().create_timer(delay_sec).timeout
	if not _game_over_active:
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_game_over_screen()


func _spawn_blood_damage_fx(tier: int, fatal_hit: bool) -> void:
	if _world_3d == null or not _gameplay_started or _menu_mode:
		return
	if _blood_fx == null:
		_blood_fx = BLOOD_FX_SCRIPT.new()
		_blood_fx.name = "BloodFx"
		add_child(_blood_fx)
		_blood_fx.setup(_world_3d, Callable(self, "_get_player_camera"), Callable(self, "_get_player_ref"))
	_blood_fx.spawn(tier, fatal_hit)


func _clear_blood_fx() -> void:
	if _blood_fx != null:
		_blood_fx.clear()


func _get_player_camera() -> Camera3D:
	if _player == null:
		return null
	return _player.get_node_or_null("Head/Camera3D") as Camera3D


func _show_game_over_screen() -> void:
	if _game_over_screen != null:
		return
	var title := "YOU DIED"
	var reason := "You collapsed in the dark. Something was standing over you."
	if _game_over_reason == GAME_OVER_REASON_UPS:
		title = "POWER LOST"
		reason = "The UPS ran dry. The camp went dark, and so did you."
	var state = CoreRoot.get_state()
	var hosted := 0
	var money := 0
	if state != null:
		hosted = (state.guest_reviews as Array).size() + (state.guests as Array).size()
		money = int(state.money)
	var stats := "Survived to day %d   $%d in the till   %d guests hosted" % [maxi(1, _day_index), money, hosted]
	_game_over_screen = GAME_OVER_SCREEN_SCRIPT.new()
	_game_over_screen.setup(title, reason, stats, SaveManager.has_saves())
	_game_over_screen.load_last_requested.connect(_on_game_over_load_save_pressed)
	_game_over_screen.main_menu_requested.connect(_on_game_over_main_menu_pressed)
	add_child(_game_over_screen)


func _clear_game_over_screen() -> void:
	if _game_over_screen == null:
		return
	_game_over_screen.queue_free()
	_game_over_screen = null


func _on_game_over_load_save_pressed() -> void:
	_game_over_active = false
	_clear_game_over_screen()
	_enter_main_menu()
	_main_menu.show_page("load")


func _on_game_over_main_menu_pressed() -> void:
	_game_over_active = false
	_clear_game_over_screen()
	_enter_main_menu()


func _bind_or_create_managers() -> void:
	grid_manager = _resolve_manager_node("GridManager", GRID_MANAGER_SCRIPT, "initialize_grid")
	building_manager = _resolve_manager_node("BuildingManager", BUILDING_MANAGER_SCRIPT, "setup")
	world_generator = _resolve_manager_node("WorldGenerator", WORLD_GENERATOR_SCRIPT, "generate_world")

	var existing_econ = get_node_or_null("EconomyManager")
	if existing_econ != null and existing_econ.has_method("get_money"):
		economy_manager = existing_econ
	else:
		if existing_econ != null:
			remove_child(existing_econ)
			existing_econ.queue_free()
		economy_manager = ECONOMY_MANAGER_SCRIPT.new()
		economy_manager.name = "EconomyManager"
		add_child(economy_manager)
	if _hud_manager != null and _hud_manager.has_method("on_money_changed"):
		var cb = Callable(_hud_manager, "on_money_changed")
		# Canonical money flow is emitted by GameActions via EventBus.
		if EventBus.has_signal("money_changed") and not EventBus.money_changed.is_connected(cb):
			EventBus.money_changed.connect(cb)
		# Legacy compatibility fallback.
		if economy_manager.has_signal("money_changed") and not economy_manager.money_changed.is_connected(cb):
			economy_manager.money_changed.connect(cb)
		_hud_manager.on_money_changed(CoreRoot.get_money())


func _resolve_manager_node(node_name: String, script_ref: Script, required_method: String) -> Node3D:
	var existing: Node = _world_3d.get_node_or_null(node_name)
	if existing != null and existing.has_method(required_method):
		return existing as Node3D

	if existing != null:
		_world_3d.remove_child(existing)
		existing.queue_free()

	var created: Node3D = script_ref.new()
	created.name = node_name
	_world_3d.add_child(created)
	return created


func _generate_grid_world() -> void:
	if grid_manager == null or building_manager == null or world_generator == null:
		push_error("Grid world init failed: one or more managers are missing.")
		world_generator.create_emergency_ground(_world_3d)
		return

	grid_manager.initialize_grid(Vector2i(28, 28), 4.0)
	building_manager.setup(grid_manager)
	world_generator.setup(grid_manager, building_manager)
	world_generator.generate_world()

	if world_generator.get_node_or_null("Terrain") == null:
		push_error("World generation failed: Terrain node was not created.")
		world_generator.create_emergency_ground(_world_3d)


## Tools (screenshot driver) may park a camera here to look at the camp from outside.
var debug_camera: Camera3D


func _sync_active_camera() -> void:
	if debug_camera != null and is_instance_valid(debug_camera):
		debug_camera.current = true
		return
	if _player == null:
		fallback_camera.current = true
		return

	var player_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	if player_camera != null:
		player_camera.current = true
		player_camera.far = FIRST_PERSON_CAMERA_FAR
		player_camera.near = 0.08
		player_camera.fov = 56.0
		fallback_camera.current = false
	else:
		fallback_camera.current = true


func _on_day_tick(day_index: int) -> void:
	_day_index = max(1, day_index)
	var income := 0
	if economy_manager != null and economy_manager.has_method("calculate_day_income"):
		income = int(economy_manager.calculate_day_income())
	if income != 0 and CoreRoot.actions != null and CoreRoot.actions.has_method("add_money"):
		CoreRoot.actions.add_money(income)
	EventBus.day_advanced.emit(_day_index, income)
	if EmailManager != null and EmailManager.has_method("settle_reputation"):
		EmailManager.settle_reputation()
	if _hud_manager != null: _hud_manager.update_time(_time_of_day_string(), _day_index)
	_sync_liminal_forecast_hud()
	_refresh_liminal_debug_window()
	_emit_state_update()


## A party checked out: what they left behind goes to the lost and found.
func _on_guest_state_for_bazaar(guest_id: int, _old: String, new_state: String) -> void:
	if new_state != "departed" or not _gameplay_started or CoreRoot.get_state() == null:
		return
	for g in CoreRoot.get_state().guests:
		if g is Dictionary and int((g as Dictionary).get("id", -1)) == guest_id:
			var where := ""
			if _day_events != null:
				var c: Vector2i = _day_events._lodging_of(g)
				if c.x >= 0:
					where = "%s %d:%d" % [_day_events._label_at(c).capitalize(), c.x, c.y]
			var it: Dictionary = _bazaar.on_checkout(str(g.get("name", "")), where, _day_index, str(g.get("archetype", "")))
			if not it.is_empty() and _hud_manager != null:
				_hud_manager.push_status("Left behind%s by %s: %s." % [(" in " + where) if where != "" else "", str(it["from"]), str(it["name"])])
			return


## The morning: what sold on the bazaar is paid; the lost and found has its say.
func _settle_bazaar() -> void:
	var r: Dictionary = _bazaar.settle(_day_index)
	for it in r["sold"]:
		if CoreRoot.actions != null and int(it["price"]) > 0:
			CoreRoot.actions.add_money(int(it["price"]))
		if _hud_manager != null:
			if bool(it.get("uncanny", false)):
				_hud_manager.push_status("Bazaar: the red shoe sold for $1. The buyer left no name.", 2)
			else:
				_hud_manager.push_status("Bazaar: the %s sold. $%d." % [str(it["short"]).to_lower(), int(it["price"])], 1)
	if _hud_manager != null:
		for it in r["back"]:
			_hud_manager.push_status("The red shoe is in the lost and found again.", 2)
		for it in r["found"]:
			_hud_manager.push_status("In the lost and found this morning: %s. Nobody left it." % str(it["name"]), 2)


## The bazaar page's "put it up" link (browser).
func bazaar_list(id: int) -> bool:
	return _bazaar.list(id, _day_index)


func _process_electricity_runtime(delta: float) -> void:
	if not _gameplay_started or _menu_mode:
		return
	_sync_billing_clock()
	_billing.tick(delta)


func _sync_billing_clock() -> void:
	_billing.set_clock(_day_index, _clock_minutes_from_hours(_time_of_day_hours))


## Billing signals: wired once in _bootstrap_runtime.
func _bind_billing() -> void:
	_billing.setup(economy_manager)
	_billing.state_changed.connect(_emit_state_update)
	_billing.power_cut_changed.connect(func(_cut: bool) -> void:
		_note_grid_power(_is_grid_powered())
		if GuestManager != null and GuestManager.has_method("set_camp_power_available"):
			GuestManager.set_camp_power_available(_is_grid_powered())
		_apply_time_from_clock(true, false)
	)
	_billing.ups_expired.connect(func() -> void:
		if not _game_over_active:
			_trigger_game_over(GAME_OVER_REASON_UPS)
	)


func _refresh_electricity_power_cut_state(force_apply: bool = false) -> void:
	_sync_billing_clock()
	_billing.refresh_power_cut(force_apply)


func _count_overdue_electricity_bills() -> int:
	return _billing.count_overdue()


## CRT Camp Status reads billing through these two (it resolves Main as its host).
func get_electricity_ui_snapshot() -> Dictionary:
	_sync_billing_clock()
	return _billing.ui_snapshot(_time_of_day_string())


func request_pay_electricity_bill(bill_id: String) -> Dictionary:
	_sync_billing_clock()
	return _billing.pay(bill_id)


func _apply_time_from_clock(force_interior_sync: bool = false, force_sky_snap: bool = false) -> void:
	var state_changed = force_interior_sync
	var is_night = (_time_state == TIME_NIGHT)
	var lamp_and_flashlight_active = _is_hour_in_window(_time_of_day_hours, LAMP_FLASHLIGHT_START_HOUR, float(BALANCE_CONFIG.DAY_START_HOUR))
	var grid_power_available = _is_grid_powered()
	if CoreRoot.is_night() != is_night:
		CoreRoot.apply_changes({"is_night": is_night})
	# Night no longer throws you out of the office: only the Builder locks (its licence),
	# mail, the web and the phone work, and the room behind the office is where you
	# sleep (scripts/reception/camp_office.gd).
	if _weather_visuals != null:
		_weather_visuals.update_state(_time_state, _time_of_day_hours, _weather_state)
		_weather_visuals.apply_time_from_clock(force_sky_snap)
	if state_changed:
		if _interior_manager != null and _interior_manager.has_method("sync_time"):
			_interior_manager.sync_time(_time_state)
	var lamp_phase_changed = force_interior_sync \
		or (lamp_and_flashlight_active != _lamp_flashlight_active) \
		or (grid_power_available != _lamp_grid_power_available)
	if lamp_phase_changed:
		_lamp_flashlight_active = lamp_and_flashlight_active
		_lamp_grid_power_available = grid_power_available
		if _player != null and _player.has_method("set_flashlight_allowed"):
			_player.set_flashlight_allowed(lamp_and_flashlight_active)
		if building_manager != null and building_manager.has_method("set_lamps_active"):
			building_manager.set_lamps_active(lamp_and_flashlight_active and grid_power_available)
	if _interior_manager != null and _interior_manager.has_method("set_grid_power_available"):
		_interior_manager.set_grid_power_available(grid_power_available)
	if _audio_manager != null and _audio_manager.has_method("refresh_ambient_audio"):
		# Ambient windows (crickets, birds) depend on hour-of-day, not only day/evening/night state.
		_audio_manager.refresh_ambient_audio(_time_of_day_hours, _gameplay_started)
	if _audio_manager != null and _audio_manager.has_method("try_roll_evening_ambient_music") and _audio_manager.has_method("get_ambient_music_trigger_hour"):
		if _time_of_day_hours >= _audio_manager.get_ambient_music_trigger_hour():
			_audio_manager.try_roll_evening_ambient_music(_day_index, _time_of_day_string())
	var env = world_environment.environment
	if env != null and _weather_visuals != null:
		var daylight_factor = _weather_visuals.compute_daylight_factor()
		if _interior_manager != null and _interior_manager.has_method("apply_dynamic_lighting"):
			_interior_manager.apply_dynamic_lighting(daylight_factor, sun.light_color, env.ambient_light_color, env.ambient_light_energy)
	if _weather_visuals != null:
		_weather_visuals.update_celestial_bodies()
	if _hud_manager != null: _hud_manager.update_time(_time_of_day_string(), _day_index)


func _set_weather_state(new_state: int) -> void:
	_weather_state = clampi(new_state, WEATHER_CLEAR, WEATHER_EVENT)
	if _weather_visuals != null:
		_weather_visuals.update_state(_time_state, _time_of_day_hours, _weather_state)
		_weather_visuals.apply_weather_profile()
	if _hud_manager != null:
		_hud_manager.update_weather(_weather_state)
	if _audio_manager != null and _audio_manager.has_method("process_runtime"):
		_audio_manager.process_runtime(
			0.0,
			_audio_weather(),
			_is_audio_interior_active(),
			_should_play_rain_inside_loop(),
			_is_service_sewer_audio_active()
		)
	if _interior_manager != null and _interior_manager.has_method("sync_weather"):
		_interior_manager.sync_weather(_weather_state)
	if GuestManager != null and GuestManager.has_method("set_camp_weather"):
		GuestManager.set_camp_weather(_weather_state)
	_announce_weather(_weather_state)


const WEATHER_ANNOUNCEMENTS := {
	WEATHER_CLEAR: ["The sky clears.", 1],
	WEATHER_WINDY: ["The wind picks up.", 0],
	WEATHER_FOG: ["Fog is rolling in off the lake.", 2],
	WEATHER_LIGHT_RAIN: ["It starts to drizzle. The bonfire is out.", 2],
	WEATHER_RAIN: ["Rain. Outdoor attractions are closed until it stops.", 2],
	WEATHER_STORM: ["A storm breaks over the camp.", 3],
	WEATHER_EVENT: ["The air turns red. That is not weather.", 3],
}
var _last_announced_weather: int = -1


## One feed line per weather change during play, so the HUD readout is never the only
## sign that the rules (closed attractions) just changed.
func _announce_weather(state: int) -> void:
	if state == _last_announced_weather:
		return
	if (state == WEATHER_LIGHT_RAIN or state == WEATHER_RAIN or state == WEATHER_STORM) and Season.precip_is_snow(_day_index, _time_of_day_hours):
		_last_announced_weather = state
		if _hud_manager != null:
			_hud_manager.push_status(["Snowflakes. The first ones settle on the path.", "It is snowing. The path is going white.", "A blizzard. You can barely see the lights."][state - WEATHER_LIGHT_RAIN], 2)
		return
	var first := _last_announced_weather < 0
	_last_announced_weather = state
	if first or _menu_mode or not _gameplay_started or _hud_manager == null:
		return
	var entry: Array = WEATHER_ANNOUNCEMENTS.get(state, [])
	if entry.is_empty():
		return
	_hud_manager.push_status(str(entry[0]), int(entry[1]), "weather")


func _setup_audio() -> void:
	if _audio_manager != null and is_instance_valid(_audio_manager):
		_audio_manager.queue_free()
	_audio_manager = AUDIO_MANAGER_SCRIPT.new()
	_audio_manager.name = "AudioManager"
	_world_3d.add_child(_audio_manager)
	if _audio_manager.has_method("setup_audio"):
		_audio_manager.setup_audio()


func _try_interact() -> void:
	if _lake_trip != null and not _is_any_interior_open() and _lake_trip.try_interact():
		return
	if _day_events != null and not _is_any_interior_open() and _day_events.try_interact():
		return
	var corn := _corn_field()
	if corn != null and corn.has_method("try_interact") and _player != null and not _is_any_interior_open():
		var said: String = corn.try_interact(_player.global_position)
		if said != "":
			if _hud_manager != null:
				_hud_manager.push_status(said, 0)
			return
	var guest_in_view := _find_guest_in_view()
	if not guest_in_view.is_empty():
		if str(guest_in_view.get("status", "")) == "waiting":
			# Check-in is at the desk inside (scripts/reception/checkin_desk.gd).
			if _hud_manager != null:
				_hud_manager.push_status("%s: \"We are waiting for the desk. Is anyone in there?\"" % str(guest_in_view.get("name", "Guest")), 0, "arrivals")
		else:
			_talk_to_guest(guest_in_view)
		return
	if _interaction_controller == null or not _interaction_controller.has_method("resolve_interaction"):
		return
	var interaction = _interaction_controller.resolve_interaction(INTERACT_DISTANCE, UTILITY_REPAIRS_ENABLED)
	if interaction.is_empty():
		return
	var interaction_type = str(interaction.get("type", ""))
	if interaction_type == "repair":
		_open_utility_repair(
			interaction.get("coord", Vector2i.ZERO),
			str(interaction.get("building_type", ""))
		)
		return
	if interaction_type != "structure":
		return
	var structure = interaction.get("structure") as Node3D
	_handle_structure_interior_interact(structure)


func _handle_structure_interior_interact(structure: Node3D) -> void:
	if structure == null or _interior_manager == null:
		return
	if _interior_manager.has_method("handle_structure_interact"):
		_interior_manager.handle_structure_interact(structure)


func _on_service_repair_requested(coord: Vector2i, building_type: String) -> void:
	if _is_sewer_repair_building_type(building_type):
		if not SEWER_PIPE_REPAIR_ENABLED:
			return
		_open_sewer_pipe_repair(coord, building_type)
		return
	if not UTILITY_REPAIRS_ENABLED:
		return
	if economy_manager == null or not economy_manager.has_method("has_failed_utility_at"):
		return
	if not economy_manager.has_failed_utility_at(coord):
		return
	_open_utility_repair(coord, building_type)


func _is_crt_desktop_active() -> bool:
	if _interior_manager == null or not _interior_manager.has_method("is_crt_desktop_active"):
		return false
	return bool(_interior_manager.is_crt_desktop_active())


func _is_structure_interior_open() -> bool:
	if _interior_manager == null or not _interior_manager.has_method("is_structure_open"):
		return false
	return bool(_interior_manager.is_structure_open())

func _update_player_control_lock() -> void:
	if _player == null or not _player.has_method("set_controls_enabled"):
		return
	_player.set_controls_enabled(not _is_any_interior_open() and not (_lake_trip != null and _lake_trip.is_active()))

## The torch hand at the bottom right while the torch is on outdoors (scripts/ui/torch_hand.gd).
var _torch_hand: CanvasLayer


func _update_torch_hand() -> void:
	if _torch_hand == null or not is_instance_valid(_torch_hand):
		_torch_hand = load("res://scripts/ui/torch_hand.gd").new()
		_torch_hand.name = "TorchHand"
		add_child(_torch_hand)
	var on: bool = _gameplay_started and not _menu_mode and _player != null and _player.has_method("is_flashlight_active") \
		and bool(_player.is_flashlight_active()) and not _is_any_interior_open() \
		and not (_lake_trip != null and _lake_trip.is_active()) and not get_tree().paused \
		and not (_sewer_pipe_minigame != null and _sewer_pipe_minigame.is_open())
	_torch_hand.show_torch(on)
	if not on:
		return
	_torch_hand.set("bar_px", float(_hud_manager.get_bar_height_px()) if _hud_manager != null and _hud_manager.has_method("get_bar_height_px") else 0.0)
	_torch_hand.set("lag", _player.get_beam_lag() if _player.has_method("get_beam_lag") else Vector2.ZERO)
	var b: Vector3 = _player.get("_bob_offset") if _player.get("_bob_offset") is Vector3 else Vector3.ZERO
	_torch_hand.set("bob", Vector2(b.x * 90.0, -b.y * 140.0))
	_torch_hand.set("dim", _player.has_method("get_flashlight_battery") and float(_player.get_flashlight_battery()) < 0.15)


func _update_interaction_hint() -> void:
	if _hud_manager == null:
		return
	if _is_any_interior_open():
		_hud_manager.set_hint_text("")
		return
	if _corn_hunt != null and is_instance_valid(_corn_hunt) and str(_corn_hunt.hint()) != "":
		_hud_manager.set_hint_text(str(_corn_hunt.hint()))
		return
	var lake_hint: String = _lake_trip.hint() if _lake_trip != null else ""
	if _lake_trip != null and _lake_trip.is_active():
		_hud_manager.set_hint_text("")
		return
	if not lake_hint.is_empty():
		_hud_manager.set_hint_text(lake_hint)
		return
	var day_hint: String = _day_events.hint() if _day_events != null else ""
	if not day_hint.is_empty():
		_hud_manager.set_hint_text(day_hint)
		return
	var guest_in_view := _find_guest_in_view()
	if not guest_in_view.is_empty():
		if str(guest_in_view.get("status", "")) == "waiting":
			_hud_manager.set_hint_text("[E] Check in %s" % str(guest_in_view.get("name", "guest")))
		else:
			_hud_manager.set_hint_text("[E] Talk to %s" % str(guest_in_view.get("name", "guest")))
		return
	if _interaction_controller == null or not _interaction_controller.has_method("build_hint_text"):
		_hud_manager.set_hint_text("")
		return
	var hint := str(_interaction_controller.build_hint_text(INTERACT_DISTANCE, UTILITY_REPAIRS_ENABLED))
	if _maintenance != null:
		var upkeep: String = _maintenance.hint_for_view(not hint.is_empty())
		if not upkeep.is_empty():
			hint = upkeep if hint.is_empty() else "%s   %s" % [hint, upkeep]
	_hud_manager.set_hint_text(hint)


func _is_any_interior_open() -> bool:
	if _is_structure_interior_open():
		return true
	if _sewer_pipe_minigame != null and _sewer_pipe_minigame.is_open():
		return true
	if _utility_repair_minigame != null and _utility_repair_minigame.is_open():
		return true
	if _interior_manager != null and _interior_manager.has_method("is_any_open") and _interior_manager.is_any_open():
		return true
	return false


func _is_audio_interior_active() -> bool:
	if _is_structure_interior_open():
		return true
	if _sewer_pipe_minigame != null and _sewer_pipe_minigame.is_open():
		return true
	if _utility_repair_minigame != null and _utility_repair_minigame.is_open():
		return true
	return false


func _is_raining_weather_active() -> bool:
	return (
		_weather_state == WEATHER_LIGHT_RAIN
		or _weather_state == WEATHER_RAIN
		or _weather_state == WEATHER_STORM
	)


func _should_play_rain_inside_loop() -> bool:
	if not _is_raining_weather_active():
		return false
	if not _is_structure_interior_open():
		return false
	if _interior_manager != null:
		if _interior_manager.has_method("is_service_sewer_profile_active") and _interior_manager.is_service_sewer_profile_active():
			return false
		if _interior_manager.has_method("is_service_restaurant_basement_active") and _interior_manager.is_service_restaurant_basement_active():
			return false
	return true


func _is_service_sewer_interior_active() -> bool:
	if _interior_manager == null:
		return false
	if _interior_manager.has_method("is_service_sewer_profile_active"):
		return bool(_interior_manager.is_service_sewer_profile_active())
	return false


func _is_service_sewer_audio_active() -> bool:
	if _sewer_pipe_minigame != null and _sewer_pipe_minigame.is_open():
		return true
	return _is_service_sewer_interior_active()


func _setup_sewer_pipe_minigame() -> void:
	if _sewer_pipe_minigame != null and is_instance_valid(_sewer_pipe_minigame):
		return
	_sewer_pipe_minigame = SEWER_PIPE_MINIGAME_SCRIPT.new()
	_sewer_pipe_minigame.name = "SewerPipeMinigame"
	add_child(_sewer_pipe_minigame)
	if _sewer_pipe_minigame.has_signal("repair_completed"):
		_sewer_pipe_minigame.repair_completed.connect(_on_repair_completed)
	if _sewer_pipe_minigame.has_signal("repair_cancelled"):
		_sewer_pipe_minigame.repair_cancelled.connect(_on_repair_cancelled)
	if _sewer_pipe_minigame.has_signal("player_hurt"):
		_sewer_pipe_minigame.player_hurt.connect(damage_player)


func _is_sewer_repair_building_type(building_type: String) -> bool:
	return building_type == "sewer"


func _open_sewer_pipe_repair(coord: Vector2i, building_type: String) -> void:
	if not SEWER_PIPE_REPAIR_ENABLED:
		return
	if _sewer_pipe_minigame == null:
		return
	if _sewer_pipe_minigame.is_open():
		return
	_sewer_pipe_minigame.open_repair(coord, building_type, "Sewer")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(false)


func _setup_utility_repair_minigame() -> void:
	_utility_repair_minigame = UTILITY_REPAIR_MINIGAME_SCRIPT.new()
	_utility_repair_minigame.name = "UtilityRepairMinigame"
	add_child(_utility_repair_minigame)
	if _utility_repair_minigame.has_signal("repair_completed"):
		_utility_repair_minigame.repair_completed.connect(_on_repair_completed)
	if _utility_repair_minigame.has_signal("repair_cancelled"):
		_utility_repair_minigame.repair_cancelled.connect(_on_repair_cancelled)


func _open_utility_repair(coord: Vector2i, building_type: String) -> void:
	if not UTILITY_REPAIRS_ENABLED:
		return
	if _utility_repair_minigame == null:
		return
	if _utility_repair_minigame.is_open():
		return
	var label = building_type
	if economy_manager != null and economy_manager.has_method("get_label"):
		label = str(economy_manager.get_label(building_type))
	_utility_repair_minigame.open_repair(coord, building_type, label)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(false)


func _on_repair_completed(coord: Vector2i, _building_type: String) -> void:
	if economy_manager != null and economy_manager.has_method("add_repair_progress"):
		economy_manager.add_repair_progress(coord, 1.0)
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_repair_cancelled() -> void:
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _time_of_day_string() -> String:
	if time_system:
		return time_system.get_time_string()
	# Fallback
	var h = int(_time_of_day_hours)
	var m = int((_time_of_day_hours - h) * 60.0)
	return "%02d:%02d" % [h, m]


func _emit_state_update() -> void:
	_sync_liminal_forecast_hud()
	var weather_name = "clear"
	match _weather_state:
		WEATHER_WINDY: weather_name = "windy"
		WEATHER_FOG: weather_name = "fog"
		WEATHER_LIGHT_RAIN: weather_name = "rain"
		WEATHER_RAIN: weather_name = "heavy_rain"
		WEATHER_STORM: weather_name = "storm"
		WEATHER_EVENT: weather_name = "event"

	var current_money = CoreRoot.get_money()

	EventBus.state_changed.emit({
		"time": {
			"day": _day_index,
			"hour": _time_of_day_hours,
			"state": _time_state,
			"string": _time_of_day_string(),
			"is_night": _time_state == TIME_NIGHT
		},
		"weather": weather_name,
		"money": current_money,
		"electricity": {
			"power_cut_active": _billing.power_cut_active,
			"ups_active": _billing.ups_active and _billing.power_cut_active,
			"ups_seconds_left": _billing.ups_seconds_left,
			"overdue_count": _count_overdue_electricity_bills(),
		},
		"liminal_forecast": _liminal_forecast_snapshot.duplicate(true),
	})


func _enter_main_menu() -> void:
	_stop_active_enemy_brain()
	if CoreRoot.failure_system != null:
		CoreRoot.failure_system.enabled = false
	if _maintenance != null:
		_maintenance.stop()
	if _quest_manager != null:
		_quest_manager.stop()
	_clear_game_over_screen()
	_game_over_active = false
	_game_over_reason = GAME_OVER_REASON_DEATH
	_billing.ups_active = false
	_billing.ups_seconds_left = _billing.UPS_DURATION_SEC
	_clear_blood_fx()
	_reset_player_damage_feedback()
	_set_player_health(PLAYER_MAX_HEALTH, false)
	_set_liminal_debug_window_visible(false)
	_liminal_forecast_snapshot.clear()
	_liminal_forecast_hud_level = 0
	_liminal_night_roll_snapshot.clear()
	_liminal_spawn_history.clear()
	_liminal_virtual_enemy_count = 0
	_liminal_last_despawn_day = 0
	_liminal_last_despawn_count = 0
	_liminal_last_rolled_night_id = -99999
	_active_enemy_spawned_this_night = 0
	if _hud_manager != null and _hud_manager.has_method("set_liminal_forecast_count"):
		_hud_manager.set_liminal_forecast_count(0)
	_menu_mode = true
	_gameplay_started = false
	_pending_loaded_player_state.clear()
	_pending_loaded_crt_state.clear()
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)
	_close_pause_menu(false)
	_ensure_main_menu()
	_load_preview_world_for_menu()
	_main_menu.open()
	_menu_flythrough.rebuild()
	_start_menu_music()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _show_menu_loading_for(label: String) -> void:
	if _main_menu != null:
		_main_menu.show_loading(label)
	await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout


func _hide_menu_loading_after(start_msec: int, minimum_visible_msec: int = 520, hide_after: bool = true) -> void:
	var elapsed := Time.get_ticks_msec() - start_msec
	if elapsed < minimum_visible_msec:
		await get_tree().create_timer(float(minimum_visible_msec - elapsed) / 1000.0).timeout
	if hide_after and _main_menu != null:
		_main_menu.hide_loading()


func _ensure_main_menu() -> void:
	if _main_menu != null:
		return
	_main_menu = MAIN_MENU_SCRIPT.new()
	add_child(_main_menu)
	_main_menu.continue_requested.connect(_on_menu_continue_pressed)
	_main_menu.new_game_requested.connect(_on_menu_new_game_pressed)
	_main_menu.load_requested.connect(_on_menu_load_requested)
	_main_menu.quit_requested.connect(func() -> void: get_tree().quit())


func _on_menu_load_requested(path: String) -> void:
	var started := Time.get_ticks_msec()
	await _show_menu_loading_for("Loading save file...")
	if not _start_loaded_game_from_path(path):
		await _hide_menu_loading_after(started, 180)
		return
	await _hide_menu_loading_after(started, 520, false)
	_start_game_from_menu()


func _start_loaded_game_from_path(path: String) -> bool:
	if path.is_empty():
		return false
	var snapshot := SaveManager.read_save(path)
	if snapshot.is_empty():
		push_warning("Failed to load selected save.")
		return false
	if not _apply_save_snapshot(snapshot, false):
		push_warning("Save data is invalid or incompatible.")
		return false
	_active_save_path = path
	return true


func _on_menu_continue_pressed() -> void:
	var started := Time.get_ticks_msec()
	await _show_menu_loading_for("Resuming your last save...")
	var latest := SaveManager.get_latest_save_path()
	if latest.is_empty():
		await _hide_menu_loading_after(started, 160)
		push_warning("No save found for Continue.")
		return
	var snapshot := SaveManager.read_save(latest)
	if snapshot.is_empty():
		await _hide_menu_loading_after(started, 200)
		push_warning("Failed to open latest save.")
		return
	if not _apply_save_snapshot(snapshot, false):
		await _hide_menu_loading_after(started, 220)
		push_warning("Latest save could not be loaded.")
		return
	_active_save_path = latest
	await _hide_menu_loading_after(started, 520, false)
	_start_game_from_menu()


func _on_menu_new_game_pressed() -> void:
	var started := Time.get_ticks_msec()
	await _show_menu_loading_for("Generating a fresh camp...")
	_reset_state_for_new_game()
	_generate_grid_world()
	_rebuild_core_cells_from_visual_structures()
	if time_system != null and time_system.has_method("set_time_hours"):
		time_system.set_time_hours(9.0)
	if weather_system != null and weather_system.has_method("set_weather"):
		weather_system.set_weather(WEATHER_CLEAR)
	_sync_runtime_state_from_systems(true)
	await _hide_menu_loading_after(started, 520, false)
	_pending_quest_state_loaded = false
	_start_game_from_menu()
	if _quest_manager != null:
		_quest_manager.begin_new_game()
	# A new game always opens on the same song (Radio Jedna).
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi != null and bi.has_method("queue_first_radio_track"):
		bi.queue_first_radio_track()
	# A new week starts at the desk: the first part of the game is the computer, and
	# getting up from it is something you find out you can do.
	get_tree().create_timer(0.25).timeout.connect(func():
		if _interior_manager != null and _gameplay_started:
			_interior_manager.open_startup_crt_view()
			_first_stand_up_pending = true
	)


func _start_game_from_menu() -> void:
	_stop_menu_music()
	if _main_menu != null:
		_main_menu.close()
	_start_gameplay_runtime()
	call_deferred("_ensure_runtime_started_after_menu_load")
	call_deferred("_write_startup_autosave")


func _ensure_runtime_started_after_menu_load() -> void:
	await get_tree().process_frame
	if not _gameplay_started:
		return
	_menu_mode = false
	if _main_menu != null:
		_main_menu.close()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player == null or not is_instance_valid(_player):
		_spawn_player()
		_apply_pending_loaded_player_state()
	_sync_active_camera()


func _write_startup_autosave() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _gameplay_started:
		return
	_write_autosave("Autosave")


func _load_preview_world_for_menu() -> void:
	_active_save_path = ""
	var latest := SaveManager.get_latest_save_path()
	if latest.is_empty():
		_reset_state_for_new_game()
		_generate_grid_world()
		_prune_preview_to_reception_only()
		_rebuild_core_cells_from_visual_structures()
		_menu_flythrough.rebuild()
		return
	var snapshot := SaveManager.read_save(latest)
	if snapshot.is_empty() or not _apply_save_snapshot(snapshot, true):
		_reset_state_for_new_game()
		_generate_grid_world()
		_prune_preview_to_reception_only()
		_rebuild_core_cells_from_visual_structures()
		_menu_flythrough.rebuild()
		return
	_active_save_path = latest
	_menu_flythrough.rebuild()


func _start_menu_music() -> void:
	if _menu_music_player == null:
		_menu_music_player = AudioStreamPlayer.new()
		_menu_music_player.name = "MenuMusic"
		_menu_music_player.bus = "Master"
		_menu_music_player.volume_db = MENU_THEME_VOLUME_DB
		add_child(_menu_music_player)
	if _menu_music_player.playing:
		return
	if not ResourceLoader.exists(MENU_THEME_PATH):
		push_warning("Menu theme missing: %s" % MENU_THEME_PATH)
		return
	var stream = load(MENU_THEME_PATH) as AudioStream
	if stream == null:
		push_warning("Menu theme failed to load: %s" % MENU_THEME_PATH)
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
	elif stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		mp3.loop = true
	_menu_music_player.stream = stream
	_menu_music_player.stop()
	_menu_music_player.seek(0.0)
	_menu_music_player.stream_paused = false
	_menu_music_player.play()
	if not _menu_music_player.playing and not _menu_music_retry_pending:
		_menu_music_retry_pending = true
		call_deferred("_retry_menu_music_start")


func _stop_menu_music() -> void:
	if _menu_music_player != null:
		if _menu_music_player.playing:
			_menu_music_player.stop()
		# Drop the stream reference too. Holding it kept ambience3A.mp3 alive past
		# shutdown, which surfaced as "resources still in use at exit".
		_menu_music_player.stream = null
	_menu_music_retry_pending = false


func _retry_menu_music_start() -> void:
	_menu_music_retry_pending = false
	if not _menu_mode:
		return
	if _menu_music_player == null or _menu_music_player.stream == null:
		return
	if _menu_music_player.playing:
		return
	_menu_music_player.stream_paused = false
	_menu_music_player.play()
	if not _menu_music_player.playing:
		push_warning("Menu theme playback did not start: %s" % MENU_THEME_PATH)


func _tick_autosave(delta: float) -> void:
	if not _gameplay_started:
		return
	_autosave_elapsed += maxf(delta, 0.0)
	if _autosave_elapsed < AUTOSAVE_INTERVAL_SEC:
		return
	_autosave_elapsed = 0.0
	_write_autosave("Autosave")


func request_manual_save(slot_name: String = "") -> String:
	if not _gameplay_started:
		push_warning("Manual save ignored: gameplay is not active.")
		return ""
	var resolved_slot := slot_name.strip_edges()
	if resolved_slot.is_empty():
		resolved_slot = "Manual Save"
	var snapshot := _build_save_snapshot(resolved_slot, "manual")
	if snapshot.is_empty():
		push_warning("Manual save failed: snapshot is empty.")
		return ""
	var path := SaveManager.write_save(snapshot, resolved_slot, "manual")
	if path.is_empty():
		push_warning("Manual save failed: write operation returned empty path.")
		return ""
	_active_save_path = path
	return path


func _write_autosave(slot_name: String) -> void:
	var snapshot := _build_save_snapshot(slot_name, "autosave")
	if snapshot.is_empty():
		return
	var path := SaveManager.write_save(snapshot, slot_name, "autosave")
	if not path.is_empty():
		_active_save_path = path


func _build_save_snapshot(slot_name: String, kind: String) -> Dictionary:
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return {}
	_sync_guest_accommodation_state()

	var tile_types: Array[Dictionary] = []
	for key_any in state.grid.tile_types.keys():
		if not (key_any is Vector2i):
			continue
		var coord := key_any as Vector2i
		tile_types.append({
			"x": coord.x,
			"y": coord.y,
			"type": int(state.grid.tile_types[key_any])
		})

	var buildings := _collect_structure_snapshot_entries()
	var crt_desktop_state := _collect_crt_desktop_snapshot()
	var email_runtime_state := _collect_email_runtime_snapshot()
	var guest_runtime_state := _collect_guest_runtime_snapshot()
	var snapshot := {
		"save_version": SAVE_VERSION,
		"meta": {
			"slot_name": slot_name,
			"kind": kind,
			"created_unix": int(Time.get_unix_time_from_system())
		},
		"state": {
			"money": int(state.money),
			"day": int(state.day),
			"is_night": bool(state.is_night),
			"karma": float(state.karma),
			"satisfaction": float(state.satisfaction),
			"hrotfaktor": float(state.hrotfaktor),
			"energy_load": float(state.energy_load),
			"infra_load": float(state.infra_load),
			"guests": SAVE_CODEC.serialize_guests(state.guests),
			"accommodation_states": SAVE_CODEC.serialize_accommodation_states(state.accommodation_states),
			"failures": SAVE_CODEC.serialize_failures(state.failures),
			"guest_reviews": SAVE_CODEC.duplicate_dict_array(state.guest_reviews),
			"guest_transactions": SAVE_CODEC.duplicate_dict_array(state.guest_transactions),
			"next_guest_id": max(1, int(state.next_guest_id)),
			"electricity": _billing.export_state()
		},
		"runtime": {
			"time_of_day_hours": _time_of_day_hours,
			"time_state": _time_state,
			"weather_state": _weather_state,
			"day_index": _day_index
		},
		"grid": {
			"width": int(state.grid.grid_width),
			"height": int(state.grid.grid_height),
			"tile_size": float(state.grid.tile_size),
			"tile_types": tile_types,
			"buildings": buildings
		},
		"crt_desktop": crt_desktop_state,
		"email_runtime": email_runtime_state,
		"guest_runtime": guest_runtime_state,
		"quests": _quest_manager.export_state() if _quest_manager != null else {},
		"night_jobs": _night_jobs.export_state() if _night_jobs != null else {},
		"day_events": _day_events.export_state() if _day_events != null else {},
		"week_ledger": _week_ledger.export_state() if _week_ledger != null else {},
		"omens": _omens.export_state() if _omens != null else {},
		"director": _director.export_state() if _director != null else {},
		"bazaar": _bazaar.export_state(),
		"camp_office": camp_office.export_state() if camp_office != null else {},
	}
	if _player != null and is_instance_valid(_player):
		snapshot["player"] = {
			"position": {
				"x": _player.global_position.x,
				"y": _player.global_position.y,
				"z": _player.global_position.z
			},
			"yaw": _player.rotation.y
		}
	return snapshot


func _collect_crt_desktop_snapshot() -> Dictionary:
	var captured: Dictionary = {}
	if _interior_manager != null and _interior_manager.has_method("export_crt_desktop_state"):
		var data_any = _interior_manager.export_crt_desktop_state()
		if data_any is Dictionary:
			captured = (data_any as Dictionary).duplicate(true)
	if captured.is_empty():
		if not _pending_loaded_crt_state.is_empty():
			captured = _pending_loaded_crt_state.duplicate(true)
		elif not _last_known_crt_desktop_state.is_empty():
			captured = _last_known_crt_desktop_state.duplicate(true)
	if not captured.is_empty():
		_last_known_crt_desktop_state = captured.duplicate(true)
	return captured


func _collect_email_runtime_snapshot() -> Dictionary:
	if EmailManager == null or not EmailManager.has_method("export_runtime_state"):
		return {}
	var data_any = EmailManager.export_runtime_state()
	if data_any is Dictionary:
		return (data_any as Dictionary).duplicate(true)
	return {}


func _collect_guest_runtime_snapshot() -> Dictionary:
	if GuestManager == null or not GuestManager.has_method("export_runtime_state"):
		return {}
	var data_any = GuestManager.export_runtime_state()
	if data_any is Dictionary:
		return (data_any as Dictionary).duplicate(true)
	return {}


func _apply_pending_crt_desktop_state() -> void:
	var payload: Dictionary = _pending_loaded_crt_state.duplicate(true)
	if payload.is_empty() and not _last_known_crt_desktop_state.is_empty():
		payload = _last_known_crt_desktop_state.duplicate(true)
	if payload.is_empty():
		_pending_loaded_crt_state.clear()
		return
	if _interior_manager == null or not _interior_manager.has_method("import_crt_desktop_state"):
		# Keep pending state for the next setup pass if InteriorManager is not ready yet.
		_pending_loaded_crt_state = payload.duplicate(true)
		return
	_interior_manager.import_crt_desktop_state(payload.duplicate(true))
	_last_known_crt_desktop_state = payload.duplicate(true)
	_pending_loaded_crt_state.clear()


func _collect_structure_snapshot_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if building_manager == null:
		return out
	var structures_root := building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return out
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		var building_id := str(structure.get_meta("building_type", "")).strip_edges()
		if building_id.is_empty():
			continue
		if structure.has_meta("on_path"):
			continue
		var origin_any = structure.get_meta("grid_origin", Vector2i.ZERO)
		var footprint_any = structure.get_meta("grid_footprint", Vector2i.ONE)
		var origin := origin_any as Vector2i if origin_any is Vector2i else Vector2i.ZERO
		var footprint := footprint_any as Vector2i if footprint_any is Vector2i else Vector2i.ONE
		out.append({
			"building_id": building_id,
			"origin": {"x": origin.x, "y": origin.y},
			"footprint": {"x": footprint.x, "y": footprint.y},
			"rotation": int(structure.get_meta("build_rotation", 0)),
			"condition": float(structure.get_meta("condition", 1.0)),
			"is_permanent": bool(structure.get_meta("is_permanent", false))
		})
	return out


func _apply_save_snapshot(snapshot: Dictionary, preview_only: bool) -> bool:
	if snapshot.is_empty():
		return false
	var grid_data_any = snapshot.get("grid", {})
	if not (grid_data_any is Dictionary):
		return false
	var grid_data := grid_data_any as Dictionary
	var width: int = max(6, int(grid_data.get("width", 28)))
	var height: int = max(6, int(grid_data.get("height", 28)))
	var tile_size: float = maxf(0.5, float(grid_data.get("tile_size", 4.0)))

	if grid_manager == null or building_manager == null or world_generator == null:
		return false
	grid_manager.initialize_grid(Vector2i(width, height), tile_size)
	building_manager.setup(grid_manager)
	world_generator.setup(grid_manager, building_manager)
	if world_generator.has_method("generate_base_world"):
		world_generator.generate_base_world(false, false)
	else:
		_generate_grid_world()

	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return false
	state.grid.cells.clear()
	state.grid.tile_types.clear()
	state.grid.occupants.clear()

	grid_manager.reset_tiles(grid_manager.TILE_GRASS)
	var tile_types_any = grid_data.get("tile_types", [])
	if tile_types_any is Array:
		for entry_any in tile_types_any:
			if not (entry_any is Dictionary):
				continue
			var entry := entry_any as Dictionary
			var coord := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
			if not grid_manager.is_in_bounds(coord):
				continue
			grid_manager.set_tile_type(coord, int(entry.get("type", 0)))

	var buildings_any = grid_data.get("buildings", [])
	var buildings: Array = []
	if buildings_any is Array:
		buildings = (buildings_any as Array).duplicate()
	buildings.sort_custom(func(a: Variant, b: Variant) -> bool:
		var aa := a as Dictionary
		var bb := b as Dictionary
		var aid := str(aa.get("building_id", ""))
		var bid := str(bb.get("building_id", ""))
		if aid == "main_building" and bid != "main_building":
			return true
		if aid != "main_building" and bid == "main_building":
			return false
		# Paths before lamps: a lamp saved on a path needs its path first.
		if aid == "path" and bid == "lamp_post":
			return true
		if aid == "lamp_post" and bid == "path":
			return false
		return aid < bid
	)

	for entry_any in buildings:
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var building_id := str(entry.get("building_id", "")).strip_edges()
		if building_id.is_empty():
			continue
		var origin_dict_any = entry.get("origin", {})
		var origin_dict := origin_dict_any as Dictionary if origin_dict_any is Dictionary else {}
		var origin := Vector2i(int(origin_dict.get("x", 0)), int(origin_dict.get("y", 0)))
		var rotation := int(entry.get("rotation", 0))
		building_manager.place_building_at_visual_only(origin, building_id, rotation)
		var root := _find_structure_root_at(origin)
		if root == null:
			continue
		var condition := clampf(float(entry.get("condition", 1.0)), 0.0, 1.0)
		if building_manager.has_method("set_structure_condition"):
			building_manager.set_structure_condition(root, condition)
		else:
			root.set_meta("condition", condition)
		if bool(entry.get("is_permanent", false)):
			root.set_meta("is_permanent", true)

	_ensure_loaded_world_landmarks()

	if world_generator.has_method("populate_trees"):
		world_generator.populate_trees()

	_rebuild_core_cells_from_visual_structures()
	var crt_any = snapshot.get("crt_desktop", {})
	var loaded_crt_state: Dictionary = {}
	if crt_any is Dictionary:
		loaded_crt_state = (crt_any as Dictionary).duplicate(true)
	if not loaded_crt_state.is_empty():
		_last_known_crt_desktop_state = loaded_crt_state.duplicate(true)

	if preview_only:
		_pending_loaded_player_state.clear()
		_pending_loaded_crt_state.clear()
	else:
		var player_any = snapshot.get("player", {})
		if player_any is Dictionary:
			_pending_loaded_player_state = (player_any as Dictionary).duplicate(true)
		else:
			_pending_loaded_player_state.clear()
		if not loaded_crt_state.is_empty():
			_pending_loaded_crt_state = loaded_crt_state.duplicate(true)
		elif not _last_known_crt_desktop_state.is_empty():
			_pending_loaded_crt_state = _last_known_crt_desktop_state.duplicate(true)
		else:
			_pending_loaded_crt_state.clear()

	var state_data_any = snapshot.get("state", {})
	if state_data_any is Dictionary:
		var state_data := state_data_any as Dictionary
		CoreRoot.apply_changes({
			"money": int(state_data.get("money", CoreRoot.get_money())),
			"day": max(1, int(state_data.get("day", CoreRoot.get_day()))),
			"is_night": bool(state_data.get("is_night", CoreRoot.is_night())),
			"karma": float(state_data.get("karma", state.karma)),
			"satisfaction": float(state_data.get("satisfaction", state.satisfaction)),
			"hrotfaktor": float(state_data.get("hrotfaktor", state.hrotfaktor)),
			"energy_load": float(state_data.get("energy_load", state.energy_load)),
			"infra_load": float(state_data.get("infra_load", state.infra_load)),
			"guests": SAVE_CODEC.deserialize_guests(state_data.get("guests", [])),
			"accommodation_states": SAVE_CODEC.deserialize_accommodation_states(state_data.get("accommodation_states", {})),
			"failures": SAVE_CODEC.deserialize_failures(state_data.get("failures", {})),
			"guest_reviews": SAVE_CODEC.duplicate_dict_array(state_data.get("guest_reviews", [])),
			"guest_transactions": SAVE_CODEC.duplicate_dict_array(state_data.get("guest_transactions", [])),
			"next_guest_id": max(1, int(state_data.get("next_guest_id", 1)))
		})
		var electricity_any = state_data.get("electricity", {})
		_billing.import_state(electricity_any if electricity_any is Dictionary else {}, _day_index, preview_only)
		_refresh_electricity_power_cut_state(true)
	else:
		_billing.reset(_day_index)
		_refresh_electricity_power_cut_state(true)

	var runtime_any = snapshot.get("runtime", {})
	if runtime_any is Dictionary:
		var runtime := runtime_any as Dictionary
		if time_system != null and time_system.has_method("set_time_hours"):
			time_system.set_time_hours(float(runtime.get("time_of_day_hours", 9.0)))
		if weather_system != null and weather_system.has_method("set_weather"):
			weather_system.set_weather(int(runtime.get("weather_state", WEATHER_CLEAR)))

	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)
	if not preview_only:
		var jobs_any = snapshot.get("night_jobs", {})
		_pending_night_jobs = (jobs_any as Dictionary).duplicate(true) if jobs_any is Dictionary else {}
		if _night_jobs != null and _gameplay_started:
			_night_jobs.import_state(_pending_night_jobs)
			_pending_night_jobs.clear()
		var office_any = snapshot.get("camp_office", {})
		_pending_camp_office = (office_any as Dictionary).duplicate(true) if office_any is Dictionary else {}
		if camp_office != null and _gameplay_started:
			camp_office.import_state(_pending_camp_office)
			_pending_camp_office.clear()
		var day_any = snapshot.get("day_events", {})
		_pending_day_events = (day_any as Dictionary).duplicate(true) if day_any is Dictionary else {}
		if _day_events != null and _gameplay_started:
			_day_events.import_state(_pending_day_events)
			_pending_day_events.clear()
		var week_any = snapshot.get("week_ledger", {})
		_pending_week_ledger = (week_any as Dictionary).duplicate(true) if week_any is Dictionary else {}
		if _pending_week_ledger.is_empty():
			# Saves from before the ledger: the week is counted from the load on.
			_pending_week_ledger = {"start_money": int(CoreRoot.get_state().money) if CoreRoot.get_state() != null else 0}
		if _week_ledger != null and _gameplay_started:
			_week_ledger.import_state(_pending_week_ledger)
			_pending_week_ledger.clear()
		var dir_any = snapshot.get("director", {})
		_pending_director = (dir_any as Dictionary).duplicate(true) if dir_any is Dictionary else {}
		if _director != null and _gameplay_started:
			_director.import_state(_pending_director)
			_pending_director.clear()
		var baz_any = snapshot.get("bazaar", {})
		_bazaar.reset()
		_pending_bazaar = (baz_any as Dictionary).duplicate(true) if baz_any is Dictionary else {}
		if _gameplay_started:
			_bazaar.import_state(_pending_bazaar)
			_pending_bazaar.clear()
		var omens_any = snapshot.get("omens", {})
		_pending_omens = (omens_any as Dictionary).duplicate(true) if omens_any is Dictionary else {}
		if _omens != null and _gameplay_started:
			_omens.import_state(_pending_omens)
			_pending_omens.clear()
		var quests_any = snapshot.get("quests", {})
		_pending_quest_state = (quests_any as Dictionary).duplicate(true) if quests_any is Dictionary else {}
		_pending_quest_state_loaded = true
		if _quest_manager != null and _gameplay_started:
			_quest_manager.import_state(_pending_quest_state)
			_pending_quest_state_loaded = false
	var email_runtime_any = snapshot.get("email_runtime", {})
	if email_runtime_any is Dictionary and EmailManager != null and EmailManager.has_method("import_runtime_state"):
		EmailManager.import_runtime_state((email_runtime_any as Dictionary).duplicate(true))
	elif EmailManager != null and EmailManager.has_method("reset_runtime"):
		EmailManager.reset_runtime(not preview_only)
	var guest_runtime_any = snapshot.get("guest_runtime", {})
	if guest_runtime_any is Dictionary and GuestManager != null and GuestManager.has_method("import_runtime_state"):
		GuestManager.import_runtime_state((guest_runtime_any as Dictionary).duplicate(true))
	elif GuestManager != null:
		if GuestManager.has_method("reset_runtime_state"):
			GuestManager.reset_runtime_state()
		elif GuestManager.has_method("import_runtime_state"):
			GuestManager.import_runtime_state({})
	_sync_guest_accommodation_state()
	_sync_runtime_state_from_systems(true)
	return true


func _ensure_loaded_world_landmarks() -> void:
	if building_manager == null or grid_manager == null:
		return
	if not _has_structure_type("main_building"):
		_place_default_reception_landmark()
	if world_generator != null and world_generator.has_method("place_starter_path"):
		world_generator.place_starter_path()
	if not _has_structure_type("sewer"):
		if world_generator != null and world_generator.has_method("place_sewer_landmark"):
			world_generator.place_sewer_landmark()
		else:
			_place_default_sewer_landmark_fallback()


func _has_structure_type(building_id: String) -> bool:
	if building_manager == null:
		return false
	var structures_root := building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return false
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		if str(structure.get_meta("building_type", "")) == building_id:
			return true
	return false


func _place_default_reception_landmark() -> bool:
	if building_manager == null or grid_manager == null:
		return false
	if not building_manager.has_method("place_main_building"):
		return false
	var footprint := Vector2i(2, 2)
	var center_x := int(floor(float(grid_manager.grid_width - footprint.x) * 0.5))
	var candidates: Array[Vector2i] = [
		Vector2i(center_x, 1),
		Vector2i(center_x, 0),
		Vector2i(center_x - 1, 0),
		Vector2i(center_x + 1, 0),
		Vector2i(center_x, 1),
		Vector2i(center_x - 1, 1),
		Vector2i(center_x + 1, 1),
		Vector2i(center_x, 2)
	]
	for candidate in candidates:
		if candidate.x < 0 or candidate.y < 0:
			continue
		if candidate.x + footprint.x > grid_manager.grid_width:
			continue
		if candidate.y + footprint.y > grid_manager.grid_height:
			continue
		if building_manager.place_main_building(candidate, footprint):
			return true

	var max_y: int = int(min(8, max(1, grid_manager.grid_height - footprint.y)))
	var min_x: int = int(max(0, center_x - 5))
	var max_x: int = int(min(grid_manager.grid_width - footprint.x, center_x + 5))
	for y in range(0, max_y + 1):
		for x in range(min_x, max_x + 1):
			if building_manager.place_main_building(Vector2i(x, y), footprint):
				return true
	return false


func _place_default_sewer_landmark_fallback() -> bool:
	if building_manager == null or grid_manager == null:
		return false
	var center_x := int(floor(float(grid_manager.grid_width) / 2.0))
	var base_y: int = int(max(0, grid_manager.grid_height - 3))
	var offsets := [0, 2, -2, 4, -4, 6, -6]
	for offset in offsets:
		var x := clampi(center_x + int(offset), 0, grid_manager.grid_width - 1)
		var ys := [base_y, max(0, base_y - 1)]
		for y in ys:
			var coord := Vector2i(x, int(y))
			if not grid_manager.is_in_bounds(coord):
				continue
			var tile = grid_manager.get_tile(coord)
			if tile == null or tile.occupied:
				continue
			if tile.tile_type != grid_manager.TILE_GRASS:
				continue
			if building_manager.place_building_at(coord, "sewer"):
				return true
	return false


func _find_structure_root_at(origin: Vector2i) -> Node3D:
	if grid_manager == null:
		return null
	var tile = grid_manager.get_tile(origin)
	if tile == null or tile.occupant == null:
		return null
	var current = tile.occupant as Node
	while current != null:
		if current is Node3D and current.has_meta("grid_origin"):
			return current as Node3D
		current = current.get_parent()
	return null


func _rebuild_core_cells_from_visual_structures() -> void:
	if building_manager == null:
		return
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return
	state.grid.cells.clear()
	var structures_root := building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return
	var next_id := 1
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		var building_id := str(structure.get_meta("building_type", "")).strip_edges()
		if building_id.is_empty():
			continue
		# A lamp standing on a path tile belongs to the path (cell["lamp"], below): written
		# over the cell it made the path vanish for the Builder and the guests (playtest
		# 2026-10-17: "lamps destroy the path under them at a crossing").
		if structure.has_meta("on_path"):
			continue
		var origin_any = structure.get_meta("grid_origin", Vector2i.ZERO)
		var footprint_any = structure.get_meta("grid_footprint", Vector2i.ONE)
		var origin := origin_any as Vector2i if origin_any is Vector2i else Vector2i.ZERO
		var footprint := footprint_any as Vector2i if footprint_any is Vector2i else Vector2i.ONE
		var condition := clampf(float(structure.get_meta("condition", 1.0)), 0.0, 1.0)
		var instance_id := "structure_%d" % next_id
		next_id += 1
		for oy in range(footprint.y):
			for ox in range(footprint.x):
				var coord := origin + Vector2i(ox, oy)
				if not state.grid.is_in_bounds(coord):
					continue
				state.grid.occupy_cell(coord, building_id, instance_id, origin)
				var cell = state.grid.cells.get(coord, {})
				if cell is Dictionary:
					var cell_dict := cell as Dictionary
					cell_dict["maintenance"] = condition
					state.grid.cells[coord] = cell_dict
	for child in structures_root.get_children():
		if child is Node3D and child.has_meta("on_path"):
			var o = child.get_meta("grid_origin", Vector2i.ZERO)
			if state.grid.cells.has(o):
				state.grid.cells[o]["lamp"] = true


## GuestManager owns the room states (status, preparation, who is in it). This only
## mirrors how many checked-in guests each lodging holds onto its 3D structure, for the
## lights in the windows and the interiors. (It used to rebuild the states itself and
## overwrote room preparation with a legacy "clean".)
func _sync_guest_accommodation_state() -> void:
	if building_manager == null or GuestManager == null:
		return
	var structures_root := building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return
	var states: Dictionary = GuestManager.get_accommodation_states()
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		var origin_any = structure.get_meta("grid_origin", Vector2i.ZERO)
		var origin := origin_any as Vector2i if origin_any is Vector2i else Vector2i.ZERO
		var acc: Dictionary = states.get(SAVE_CODEC.coord_to_key(origin), {})
		var present := int(acc.get("occupied", 0))
		structure.set_meta("guest_count", present)
		structure.set_meta("has_guest", present > 0)


func _reset_state_for_new_game() -> void:
	_pending_loaded_player_state.clear()
	_pending_night_jobs.clear()
	if _night_jobs != null:
		_night_jobs.reset()
	_pending_camp_office.clear()
	if camp_office != null:
		camp_office.reset()
	_pending_day_events.clear()
	if _day_events != null:
		_day_events.reset()
	_pending_loaded_crt_state.clear()
	_last_known_crt_desktop_state.clear()
	_billing.reset(1)
	_lamp_grid_power_available = true
	_active_save_path = ""
	_clear_blood_fx()
	var state = CoreRoot.get_state()
	if state == null:
		return
	_pending_week_ledger.clear()
	if _week_ledger != null:
		_week_ledger.reset(BALANCE_CONFIG.STARTING_MONEY)
	_pending_omens.clear()
	if _omens != null:
		_omens.reset()
	if _director != null:
		_director.begin_night(-1)
		_director.ever.clear()
		# Not the last game's night on CampStat's NIGHT page.
		_director.last_log.clear()
	_pending_bazaar.clear()
	_bazaar.reset()
	if _director_fx != null:
		_director_fx.clear()
	CoreRoot.apply_changes({
		"money": BALANCE_CONFIG.STARTING_MONEY,
		"day": 1,
		"is_night": false,
		"karma": 0.0,
		"satisfaction": 50.0,
		"hrotfaktor": 0.0,
		"energy_load": 0.0,
		"infra_load": 0.0
	})
	if state.grid != null:
		state.grid.cells.clear()
		state.grid.tile_types.clear()
		state.grid.occupants.clear()
	state.failures.clear()
	state.guests.clear()
	state.accommodation_states.clear()
	state.guest_reviews.clear()
	state.guest_transactions.clear()
	state.next_guest_id = 1
	if EmailManager != null and EmailManager.has_method("reset_runtime"):
		EmailManager.reset_runtime(true)
	if GuestManager != null and GuestManager.has_method("reset_runtime_state"):
		GuestManager.reset_runtime_state()
	if _guest_agents != null:
		_guest_agents.clear_agents()
	if time_system != null and time_system.has_method("set_time_hours"):
		time_system.set_time_hours(9.0)
	if weather_system != null and weather_system.has_method("set_weather"):
		weather_system.set_weather(WEATHER_CLEAR)
	_day_index = 1
	_time_of_day_hours = 9.0
	_time_state = TIME_DAY
	_weather_state = WEATHER_CLEAR


func _prune_preview_to_reception_only() -> void:
	if building_manager == null:
		return
	var structures_root := building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return
	var to_remove: Array[Node3D] = []
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		if str(structure.get_meta("building_type", "")) == "power_generator":
			to_remove.append(structure)
	for structure in to_remove:
		if building_manager.has_method("remove_structure"):
			building_manager.remove_structure(structure)
		else:
			structure.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _gameplay_started:
			_write_autosave("Autosave")
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Alt-tab during the night should not cost the player their life.
		if pause_on_focus_loss and _can_pause_now():
			_open_pause_menu()


func _can_pause_now() -> bool:
	return (
		_startup_bootstrap_complete
		and _gameplay_started
		and not _menu_mode
		and not _game_over_active
		and _week_report_screen == null
		and (_pause_menu == null or not _pause_menu.is_open())
	)


func _open_pause_menu() -> void:
	if not _can_pause_now():
		return
	_ensure_pause_menu()
	# Resume gives back the pointer as it was (free in a room, hidden at the PC,
	# captured outdoors).
	_pause_prev_mouse = Input.mouse_mode
	_pause_menu.open(_pause_info_line(), _leave_label())
	get_tree().paused = true


## What the pause menu's way out says, or "" when you are already outdoors.
func _leave_label() -> String:
	if _lake_trip != null and is_instance_valid(_lake_trip) and _lake_trip.has_method("is_active") and _lake_trip.is_active():
		return "Row back to camp"
	if _is_any_interior_open() or (_breaker_panel != null and is_instance_valid(_breaker_panel) and _breaker_panel.visible):
		return "Go outside"
	return ""


## The pause menu's way out: whatever room, close-up or job you are in ends the way its
## own exit would, and you stand in the camp again. There is always a way back.
func _on_pause_leave_requested() -> void:
	_close_pause_menu(false)
	if _sewer_pipe_minigame != null and _sewer_pipe_minigame.has_method("abort") and _sewer_pipe_minigame.is_open():
		_sewer_pipe_minigame.abort()
	if _utility_repair_minigame != null and _utility_repair_minigame.has_method("abort") and _utility_repair_minigame.is_open():
		_utility_repair_minigame.abort()
	if _breaker_panel != null and is_instance_valid(_breaker_panel) and _breaker_panel.visible:
		_breaker_panel.close()
	if _lake_trip != null and is_instance_valid(_lake_trip) and _lake_trip.has_method("return_home") and _lake_trip.is_active():
		_lake_trip.return_home()
	if _interior_manager != null and _interior_manager.has_method("close_everything"):
		_interior_manager.close_everything()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Built once at bootstrap so it is ready (and laid out) long before the first Esc.
func _ensure_pause_menu() -> void:
	if _pause_menu != null:
		return
	_pause_menu = PAUSE_MENU_SCRIPT.new()
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(func() -> void: _close_pause_menu(true))
	_pause_menu.save_requested.connect(_on_pause_save_requested)
	_pause_menu.quit_to_title_requested.connect(_on_pause_quit_requested)
	_pause_menu.leave_requested.connect(_on_pause_leave_requested)


func _close_pause_menu(recapture_mouse: bool) -> void:
	if _pause_menu == null or not _pause_menu.is_open():
		return
	_pause_menu.close()
	get_tree().paused = false
	if recapture_mouse:
		Input.set_mouse_mode(_pause_prev_mouse)


func _pause_info_line() -> String:
	var line := "DAY %d   %s" % [maxi(1, _day_index), _time_of_day_string()]
	var saved := _last_save_unix()
	if saved > 0:
		var ago := int(Time.get_unix_time_from_system()) - saved
		if ago < 90:
			line += "   SAVED JUST NOW"
		elif ago < 3600:
			line += "   SAVED %d MIN AGO" % (ago / 60)
		else:
			line += "   SAVED %d H AGO" % (ago / 3600)
	return line


func _last_save_unix() -> int:
	if _active_save_path.is_empty():
		return 0
	return int(FileAccess.get_modified_time(_active_save_path))


func _on_pause_save_requested() -> void:
	var path := request_manual_save()
	if path.is_empty():
		_pause_menu.set_info("SAVE FAILED")
		return
	_pause_menu.set_info(_pause_info_line())
	if _hud_manager != null:
		_hud_manager.push_status("Game saved.", 1)


func _on_pause_quit_requested() -> void:
	_write_autosave("Autosave")
	_close_pause_menu(false)
	_enter_main_menu()


func _exit_tree() -> void:
	_stop_menu_music()
	if _menu_music_player != null and is_instance_valid(_menu_music_player):
		# free(), not queue_free(): on quit the deferred queue may never be flushed,
		# which leaves the MP3 stream alive and trips the resource-leak check at exit.
		_menu_music_player.free()
	_menu_music_player = null
	_stop_active_enemy_brain()
