extends Node

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const ORDERS_SERVED = preload("res://scripts/food/orders.gd")
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
const BUS_TIMES = preload("res://scripts/town/bus_timetable.gd")
const INTERACTION_CONTROLLER_SCRIPT = preload("res://scripts/interaction_controller.gd")
const SILENT_MAN_BRAIN_SCRIPT = preload("res://scripts/enemies/silent_man_brain.gd")
const TOURIST_BRAIN_SCRIPT = preload("res://scripts/enemies/tourist_brain.gd")
const GIRL_BRAIN_SCRIPT = preload("res://scripts/enemies/girl_brain.gd")
const STALKER_BRAIN_SCRIPT = preload("res://scripts/enemies/stalker_brain.gd")
## Which enemy a guest archetype brings: one guest of that kind turns into it for the
## night (`_pick_turned_guest`); if it gets you, that guest is gone by morning
## (`_claim_turned_guests`). The Antlered Man (stalker) is the boss of a camp packed too
## full: he comes on top when three kinds turn in one night, or the camp holds
## ANTLERED_GUESTS guests or more (`_antlered_comes`).
const ENEMY_FOR_ARCHETYPE := {
	"quiet_guy": SILENT_MAN_BRAIN_SCRIPT,
	"drunk": TOURIST_BRAIN_SCRIPT,
	"cheap_chick": GIRL_BRAIN_SCRIPT,
	"tramp": preload("res://scripts/enemies/whistler_brain.gd"),
	# The family's boy, out where the night's work is (corn, the board, the pipes).
	"family": preload("res://scripts/enemies/boy_brain.gd"),
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
## Being hurt on the screen and in the ears (the red flash, blood on the lens, your cry,
## the heart and the breath, the limp and the blackouts when low).
const HURT_FX_SCRIPT = preload("res://scripts/ui/hurt_fx.gd")
var _hurt_fx: CanvasLayer
const MENU_FLYTHROUGH_SCRIPT = preload("res://scripts/menu_flythrough.gd")
const SAVE_CODEC = preload("res://scripts/save_codec.gd")
const ELECTRICITY_BILLING_SCRIPT = preload("res://scripts/electricity_billing.gd")
const THREAT_SENSES_SCRIPT = preload("res://scripts/threat_senses.gd")
const NIGHT_JOBS_SCRIPT = preload("res://scripts/night_jobs.gd")
const CAMP_OFFICE_SCRIPT = preload("res://scripts/reception/camp_office.gd")
const LAKE_TRIP_SCRIPT = preload("res://scripts/lake/lake_trip.gd")
## The warden in the attractions (by the fire, the swing, the slide, the court).
const WARDEN_PLAY_SCRIPT = preload("res://scripts/attractions/warden_play.gd")
var _warden_play: Node
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
## Wardens and their camps (worlds): which camp's saves are played.
const PROFILES = preload("res://scripts/profiles.gd")
## The seed NEW CAMP asked for (0: a new one), used by the next generation.
var _pending_world_seed := 0
const MENU_THEME_PATH := "res://assets/music/title.mp3"
const MENU_THEME_VOLUME_DB := -2.5
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
## The camp's lamps and the torch from seven (half past was late in the dusk: playtest 18. 10.).
const LAMP_FLASHLIGHT_START_HOUR: float = 19.0
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
## The giant pointer over the camp that brings down what the Builder builds (theatre only).
var _god_cursor: Node3D
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
## The game clock's pace against its usual (1): town_trip.gd slows it while a warden
## rides the bus through the real land.
var clock_scale := 1.0
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
## The camp's own music, not the radio's (scripts/audio/music_director.gd).
var _music_director: Node
var _pending_director: Dictionary = {}
## The lost and found and its classifieds (scripts/bazaar.gd).
var _bazaar = preload("res://scripts/bazaar.gd").new()
var _pending_bazaar: Dictionary = {}
## The camp on Goggle (scripts/reviews/goggle.gd): the reviews in public, the rating, the
## blueprints it opens in Builder 98.
var _goggle = preload("res://scripts/reviews/goggle.gd").new()
var _pending_goggle: Dictionary = {}
var _goggle_fresh := true
## Builder 98's Graphs: what each day ended with (scripts/builder/day_graph.gd).
var _day_graph = preload("res://scripts/builder/day_graph.gd").new()
var _pending_graph: Dictionary = {}
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
## The bag and the trip from a save loaded before the trip is made (a load from the title
## screen right after starting the game: it was skipped, and the bag came up with only the
## torch, the shed key gone; playtest 25. 10.).
var _pending_town_trip: Dictionary = {}
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
	# The warden and the camp played last (scripts/profiles.gd): their saves are the
	# menu's camp and CONTINUE.
	PROFILES.boot()
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


## One step of the boot on the boot screen (its bar and line), and a frame for it to be
## drawn: the whole boot in one frame froze the title after the splash (playtest 18. 10.).
func _boot_step(text: String, progress: float) -> void:
	if _boot_screen != null and _boot_screen.has_method("set_status"):
		_boot_screen.set_status(text, progress)
	await get_tree().process_frame
	await get_tree().process_frame


func _bootstrap_runtime() -> void:
	await _boot_step("Waking the camp", 0.05)
	time_system = TIME_SYSTEM_SCRIPT.new(CoreRoot.get_state())
	weather_system = WEATHER_SYSTEM_SCRIPT.new()
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)
	visual_module = VISUAL_MODULE_SCRIPT.new()
	add_child(visual_module)

	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	_ensure_input_actions()
	# The one debug menu, on L (scripts/ui/debug_menu.gd): debug builds only.
	if OS.is_debug_build():
		var dm = preload("res://scripts/ui/debug_menu.gd").new()
		dm.name = "DebugMenu"
		dm.main = self
		add_child(dm)
	await _boot_step("Tuning the radio", 0.15)
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

	await _boot_step("Opening the office", 0.3)
	_bind_or_create_managers()
	_bind_billing()
	_menu_flythrough = MENU_FLYTHROUGH_SCRIPT.new()
	_menu_flythrough.name = "MenuFlythrough"
	add_child(_menu_flythrough)
	_menu_flythrough.setup(fallback_camera, grid_manager, building_manager)
	_setup_weather_visuals_module()
	RETRO_RENDER.register(_sub_viewport_container)
	get_viewport().size_changed.connect(func() -> void: RETRO_RENDER.refresh_all(get_tree()))
	await _boot_step("Growing the woods", 0.45)
	await _generate_grid_world_stepped()
	await _boot_step("Raking the paths", 0.85)
	_rebuild_core_cells_from_visual_structures()
	_setup_guest_agents()
	_setup_god_cursor()
	fallback_camera.current = true
	await _boot_step("Lighting the lamps", 0.9)

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
	_set_hud_shown(true)
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


## Vera's checklist from a save (or the host's camp). A sandbox camp never had one going
## (a new one does not start it): loading it must not start it either, nor on the other
## warden's machine, where its rewards would be paid a second time.
func _import_quests(data: Dictionary) -> void:
	if _sandbox or Coop.is_client():
		_quest_manager.stop()
		return
	_quest_manager.import_state(data)


func _setup_quest_manager() -> void:
	if _quest_manager == null or not is_instance_valid(_quest_manager):
		_quest_manager = QUEST_MANAGER_SCRIPT.new()
		add_child(_quest_manager)
	_quest_manager.setup(self)
	if _pending_quest_state_loaded:
		_import_quests(_pending_quest_state)
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
		_breaker_panel.fixed.connect(func(fault: int):
			# The boy's board done: he is back in the tent by morning.
			if _night_jobs.boy_tier_at("breaker") > 0:
				for b in _enemy_brains:
					if b != null and b.has_method("boy_found"):
						b.boy_found()
			_night_jobs.on_breaker_fixed(fault)
			if Coop.is_client():
				Coop.send_request("breaker", [fault])
		)
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
	_setup_goggle()
	if not EventBus.guest_state_changed.is_connected(_on_guest_state_for_bazaar):
		EventBus.guest_state_changed.connect(_on_guest_state_for_bazaar)
	if _lake_trip == null or not is_instance_valid(_lake_trip):
		_lake_trip = LAKE_TRIP_SCRIPT.new()
		_lake_trip.name = "LakeTrip"
		add_child(_lake_trip)
		_lake_trip.setup(self)
	if _warden_play == null or not is_instance_valid(_warden_play):
		_warden_play = WARDEN_PLAY_SCRIPT.new()
		_warden_play.name = "WardenPlay"
		add_child(_warden_play)
		_warden_play.setup(self)
	if camp_office == null or not is_instance_valid(camp_office):
		camp_office = CAMP_OFFICE_SCRIPT.new()
		camp_office.name = "CampOffice"
		add_child(camp_office)
		camp_office.setup(self)
	if not _pending_camp_office.is_empty():
		camp_office.import_state(_pending_camp_office)
		_pending_camp_office.clear()


## Day 31, the inspection: the pager in the morning, the books at 08:00 (scripts/week_ledger.gd).
func _tick_week_ledger() -> void:
	if _omens != null and not _game_over_active and _player != null and is_instance_valid(_player) and camp_rule("threats"):
		var minute_of_day := int(round(_time_of_day_hours * 60.0))
		var abs_minute := (maxi(1, _day_index) - 1) * 1440 + minute_of_day
		var outdoors := not _is_any_interior_open() and not get_tree().paused
		_omens.tick(get_process_delta_time(), abs_minute, outdoors, _player.global_position, _omen_context())
		_tick_director()
	# A sandbox camp has no month to end (no inspection, no books).
	if _week_ledger == null or _game_over_active or _week_report_screen != null or _sandbox:
		return
	if _week_ledger.should_page(_day_index, _time_of_day_hours) and _hud_manager != null:
		_hud_manager.push_status("Pager: Vera came in on the first bus. The district at eight. Books on the desk.", 2)
	if _week_ledger.is_due(_day_index, _time_of_day_hours):
		_show_week_report()


## The night director: what it sees of the night and of you, then what it does.
func _tick_director() -> void:
	if _director == null or _director_fx == null or get_tree().paused:
		return
	var ctx := _director_context()
	# Co-op: the night presses on one warden at a time (scripts/coop/coop_night.gd); what
	# it does to another happens on their machine, and to those with them too.
	var target := "host"
	if Coop.is_host() and Coop.has_partner() and _coop_night != null:
		target = _coop_night.director_target()
		if target != "host":
			ctx = _director_context_other(ctx, _coop_night.peer_of(target))
	var id: String = _director.tick(get_process_delta_time(), ctx)
	if id != "" and target != "host":
		var peer: int = _coop_night.peer_of(target)
		Coop.send_night_event("fx", [id], peer)
		for with_them in _coop_night.near(target):
			if int(with_them) == 1:
				_director_fx.run(id, _director_context())
			elif int(with_them) != peer:
				Coop.send_night_event("fx", [id], int(with_them))
		_director.watch(id, ctx["pos"])
		return
	if id != "":
		var at: Vector3 = _director_fx.run(id, ctx)
		_director.watch(id, at)
		if Coop.is_host() and Coop.has_partner() and _coop_night != null:
			for with_you in _coop_night.near("host"):
				Coop.send_night_event("fx", [id], int(with_you))
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
		# A run of things may end in the breaker going (night_director.RUNS).
		"can_trip": _night_jobs != null and _night_jobs.has_method("can_trip_breaker") and _night_jobs.can_trip_breaker(),
	}


var _dir_slow: Dictionary = {}
var _dir_slow_at := 0
var _coop_dir_other_inside := false


## Co-op: the night's context as another warden (`peer`) is in it (where they are, in the
## light or the dark, walking), the camp's side as it is.
func _director_context_other(ctx: Dictionary, peer: int) -> Dictionary:
	var s: Dictionary = Coop.state_of(peer)
	var room: Dictionary = s.get("room", {})
	var pos: Vector3 = s.get("p", Vector3.ZERO)
	var place := "out_dark"
	if s.has("boat") or s.has("boat_at") or s.has("ride"):
		place = "lake"
	elif str(room.get("t", "")) == "office":
		place = "back_room" if str(room.get("s", "")) == "back" else "office"
	elif bool(s.get("in", false)):
		place = "room"
	elif building_manager != null and float(building_manager.get_light_level_at(pos)) > 0.2:
		place = "out_lit"
	var inside := place == "office" or place == "back_room"
	var out := ctx.duplicate()
	out["place"] = place
	out["pos"] = pos
	out["walking"] = float(s.get("v", 0.0)) > 0.8
	out["lamp_near"] = place == "out_lit"
	out["haunted_near"] = _day_events != null and place.begins_with("out") and _day_events.haunted_near(pos, 14.0) != Vector3.INF
	out["looking_at_window"] = false
	out["hunter_near_m"] = 99.0
	out["entering"] = inside and not _coop_dir_other_inside
	_coop_dir_other_inside = inside
	return out


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
	if _away_in_town():
		return "away"
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
	if _day_events == null or not camp_rule("events"):
		return
	var minute_of_day := _clock_minutes_from_hours(_time_of_day_hours)
	var abs_minute := (maxi(1, _day_index) - 1) * 1440 + minute_of_day
	var can_act := not _is_any_interior_open() and not get_tree().paused
	_day_events.tick(get_process_delta_time(), abs_minute, _time_state != TIME_NIGHT, _day_index, can_act)


func _tick_night_jobs() -> void:
	if _night_jobs == null:
		return
	if not camp_rule("wear") and _test_night != TEST_SEWER:
		return
	var minute_of_day := _clock_minutes_from_hours(_time_of_day_hours)
	var abs_minute := (maxi(1, _day_index) - 1) * 1440 + minute_of_day
	var night_index := _day_index if minute_of_day >= 12 * 60 else _day_index - 1
	_night_jobs.tick(abs_minute, _time_state == TIME_NIGHT, night_index)
	if _test_night == TEST_SEWER:
		_tick_test_sewer()


## The sewer test night (main_menu.TEST_NIGHTS "sewer"): no thing out, the camp's sewer
## breaks a moment after it is mended, over and over, for the pipes minigame.
const TEST_SEWER := "sewer"
const TEST_SEWER_REBREAK_SEC := 2.0
var _test_sewer_wait := 0.0
## The hatch built by the test camp's toilets (the camp may have its own far off too).
var _test_sewer_at := Vector2i(-1, -1)


func _tick_test_sewer() -> void:
	if _sewer_pipe_minigame != null and _sewer_pipe_minigame.is_open():
		_test_sewer_wait = TEST_SEWER_REBREAK_SEC
		return
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return
	var coords: Array = state.grid.cells.keys()
	if state.grid.cells.has(_test_sewer_at):
		coords.push_front(_test_sewer_at)
	for coord in coords:
		var cell: Dictionary = state.grid.cells[coord]
		if str(cell.get("type", "")) != "sewer" or cell.get("root_coord", coord) != coord:
			continue
		var key := "%d:%d" % [coord.x, coord.y]
		if state.failures.has(key):
			return
		_test_sewer_wait -= get_process_delta_time()
		if _test_sewer_wait > 0.0:
			return
		_test_sewer_wait = TEST_SEWER_REBREAK_SEC
		CoreRoot.failure_system._trigger_failure(key, "sewer", coord)
		state.failures[key]["night"] = true
		if _hud_manager != null:
			_hud_manager.push_status("Pager: Sewer leaking. The sewer hatch: crawl in.", 2)
		return


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
	if Coop.is_client():
		return _coop_powered
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
	# The family's boy in the switch room tonight: the board is his game.
	_breaker_panel.open(_night_jobs.breaker_fault(), _night_jobs.boy_tier_at("breaker"))


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
	# Somebody waiting to be served in a business: pointed to like the day's jobs.
	var biz = _interior_manager.get("business") if _interior_manager != null else null
	if day.is_empty() and biz != null and biz.has_method("waypoint"):
		day = biz.waypoint(_player.global_position, grid_manager)
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
		CoreRoot.failure_system.enabled = camp_rule("wear")


## Camp Status > Upkeep (CRT) reads and acts through these.
func get_upkeep_snapshot() -> Dictionary:
	if _maintenance == null:
		return {}
	return _maintenance.get_upkeep_snapshot()


func request_maintenance_crew() -> Dictionary:
	if _maintenance == null:
		return {"ok": false, "reason": "unavailable"}
	if Coop.is_client():
		# The crew is the host's to send (and pay): asked for from here.
		var snap: Dictionary = _maintenance.get_upkeep_snapshot()
		if bool(snap.get("night", false)):
			return {"ok": false, "reason": "night"}
		if int(snap.get("crew_jobs", 0)) <= 0:
			return {"ok": false, "reason": "nothing_to_do"}
		if CoreRoot.get_money() < int(snap.get("crew_cost", 0)):
			return {"ok": false, "reason": "insufficient_funds", "amount": int(snap.get("crew_cost", 0))}
		Coop.send_request("crew", [])
		return {"ok": true, "jobs": int(snap.get("crew_jobs", 0)), "amount": int(snap.get("crew_cost", 0))}
	return _maintenance.request_maintenance_crew()


## The crew to one building (Builder's map). In co-op asked of the host.
func request_maintenance_crew_at(coord: Vector2i) -> Dictionary:
	if _maintenance == null:
		return {"ok": false, "reason": "unavailable"}
	if Coop.is_client():
		if CoreRoot.is_night():
			return {"ok": false, "reason": "night"}
		Coop.send_request("crew_at", [coord])
		return {"ok": true, "jobs": 1, "amount": 0}
	return _maintenance.request_crew_at(coord)


func _setup_guest_agents() -> void:
	if _guest_agents != null and is_instance_valid(_guest_agents):
		return
	_guest_agents = GUEST_AGENTS_SCRIPT.new()
	_world_3d.add_child(_guest_agents)
	_guest_agents.setup(grid_manager, Callable(self, "_now_abs_minutes_float"))


func _setup_god_cursor() -> void:
	if _god_cursor != null and is_instance_valid(_god_cursor):
		return
	_god_cursor = preload("res://scripts/god/god_cursor.gd").new()
	_world_3d.add_child(_god_cursor)
	_god_cursor.setup(self, grid_manager)


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

	# Co-op: the other warden's machine runs no clock or weather of its own (the host's
	# come in, coop_apply_clock), nor anything below that changes the camp.
	var sim: bool = Coop.sim_here()
	if time_system and sim:
		# Slower while a warden rides the 380 through the real land (town_trip.gd):
		# its thirteen minutes take the real road's five.
		time_system.process(delta * clock_scale)
	if weather_system and sim and not camp_rule("weather"):
		if weather_system.current_weather != WEATHER_CLEAR:
			weather_system.set_weather(WEATHER_CLEAR)
	elif weather_system and sim:
		var state = CoreRoot.get_state()
		if state != null:
			weather_system.set_anomaly_pressure(float(state.hrotfaktor))
		weather_system.season_day = _day_index
		weather_system.process(delta * clock_scale * BALANCE_CONFIG.GAME_MINUTES_PER_SECOND, _time_of_day_hours)
	_sync_runtime_state_from_systems()
	_sync_season()
	if sim:
		_tick_blueprint_guests(delta)
	# The storm on its way (the host's, in co-op): the sky, the wind and the far thunder.
	var build: float = (weather_system.storm_build() if weather_system != null and camp_rule("weather") else 0.0) if sim else _coop_storm_build
	if _audio_manager != null:
		_audio_manager.set("storm_build", 0.0 if is_snowing() else build)
	if _weather_visuals != null:
		_weather_visuals.storm_build = build
		_weather_visuals.update_state(_time_state, _time_of_day_hours, _weather_state)
		_weather_visuals.update_frame(delta)

	if _menu_mode:
		_menu_flythrough.update(delta)
		return

	if sim:
		_process_electricity_runtime(delta)

	if _liminal_debug_visible:
		_liminal_debug_refresh_accum += maxf(delta, 0.0)
		if _liminal_debug_refresh_accum >= 0.35:
			_liminal_debug_refresh_accum = 0.0
			_refresh_liminal_debug_window()

	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(not _is_any_interior_open(), true)
	_tick_coop_down(delta)
	_update_player_control_lock()
	if not _is_any_interior_open() and not (_lake_trip != null and _lake_trip.is_active()) and not _in_attraction():
		_sync_active_camera()
	_update_interaction_hint()
	_update_torch_hand()
	_tick_day_regen(delta)
	if _audio_manager != null and _audio_manager.has_method("process_runtime"):
		_audio_manager.process_runtime(
			delta,
			_audio_weather(),
			_is_audio_interior_active(),
			_should_play_rain_inside_loop(),
			_is_service_sewer_audio_active()
		)
	if sim:
		_tick_active_enemy_brain(delta)
	_update_corn_wading(delta)
	_update_threat_senses(delta)
	if _music_director != null:
		_music_director.tick(delta)
	_sync_hud_player_meters()
	# Who is coming, at the gate, the day's and the night's jobs: on the HUD of both machines
	# (the other's from the host's pulse).
	_poll_arrivals(delta)
	if sim:
		_tick_night_jobs()
		_tick_week_ledger()
		_poll_guest_quotes(delta)
	# The other warden's machine sees its own omens (they are only signs near you).
	if not sim and _omens != null and not _game_over_active and _player != null and is_instance_valid(_player) and camp_rule("threats"):
		var omen_minute := (maxi(1, _day_index) - 1) * 1440 + int(round(_time_of_day_hours * 60.0))
		_omens.tick(get_process_delta_time(), omen_minute, not _is_any_interior_open() and not get_tree().paused, _player.global_position, _omen_context())
	# The other warden's machine too: the host's day events shown and done from here
	# (day_events.coop_follow), the lamps' signs and hold R (what it does goes to the host).
	if _day_events != null:
		_day_events.coop_follow = Coop.is_client()
	_tick_day_events()
	if _maintenance != null:
		_maintenance.tick(delta, not _is_any_interior_open() and not _game_over_active)
	if visual_module != null and visual_module.has_method("sync_enemy_distortion_fx"):
		visual_module.sync_enemy_distortion_fx(_time_state)
	if sim:
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

	# The debug keys are all in the one debug menu now (L, scripts/ui/debug_menu.gd).

	# Block all gameplay input while any UI is open.
	if _is_any_interior_open():
		return

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
				gate.set_night(_time_state == TIME_NIGHT or _time_of_day_hours >= LAMP_FLASHLIGHT_START_HOUR)
		if previous_time_state == TIME_NIGHT and _time_state == TIME_DAY:
			_on_day_phase_started()
		if previous_time_state != TIME_NIGHT and _time_state == TIME_NIGHT and _day_events != null and Coop.sim_here() and camp_rule("events"):
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
		if not _pending_town_trip.is_empty() and _interior_manager.town_trip() != null:
			_interior_manager.town_trip().import_state(_pending_town_trip)
			_pending_town_trip.clear()
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

	# No debug bindings: the debug menu (L, debug builds only) has them all, so a key
	# pressed by chance skips no hours and hands out no money (the user 20. 10.).
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
	if not Coop.sim_here():
		# The host's guests by the host's clock (GuestManager keeps no time of its own here).
		GuestManager._on_time_tick(int(_time_of_day_hours), int(fposmod(_time_of_day_hours, 1.0) * 60.0))
	_hud_manager.set_arrivals(GuestManager.get_arrivals())
	# The post on its way with what you ordered (reception/post_delivery.gd).
	var bi_p = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var post_p = bi_p.get("_post") if bi_p != null else null
	if _hud_manager.has_method("set_post"):
		_hud_manager.set_post(post_p.hud_row() if post_p != null and post_p.has_method("hud_row") else {})
	var day_rows: Array = _day_events.hud_rows() if _day_events != null else []
	var biz = _interior_manager.get("business") if _interior_manager != null else null
	var serve_rows: Array = []
	if biz != null:
		serve_rows = biz.hud_rows()
		if _hud_manager.has_method("set_serving"):
			_hud_manager.set_serving(int(biz.waiting_total()))
	# Guests waiting for an order are on the list by night too (the pub is open late).
	if not (day_rows + serve_rows).is_empty() and _time_state != TIME_NIGHT:
		_hud_manager.set_jobs(day_rows + serve_rows, "TODAY")
	elif _night_jobs != null:
		_hud_manager.set_jobs(serve_rows + _night_jobs.hud_rows())
	if _hud_manager.has_method("set_troubles"):
		_hud_manager.set_troubles(_trouble_rows(biz))


## The camp's troubles for the HUD's plates (scripts/ui/trouble_strip.gd): the day's open
## events with their time running out, the night's open jobs, the businesses with guests
## waiting and how many. The same on every co-op machine (all three are the host's).
const TROUBLE_KIND := {"rest": "rest", "pub": "pub", "vecerka": "vecerka", "corn": "stand"}
const TROUBLE_WORD := {"rest": "Bistro", "pub": "Pub", "vecerka": "Jednota", "corn": "Corn"}


func _trouble_rows(biz) -> Array:
	var rows: Array = []
	var abs_minute := (maxi(1, _day_index) - 1) * 1440 + _clock_minutes_from_hours(_time_of_day_hours)
	if _day_events != null and camp_rule("events"):
		for ev in _day_events.open_events():
			var span := float(int(ev.get("deadline", 0)) - int(ev.get("at", 0)))
			var left := clampf(float(int(ev.get("deadline", 0)) - abs_minute) / span, 0.0, 1.0) if span > 0.0 else -1.0
			rows.append({"id": "d%s" % str(ev.get("id", "")), "kind": str(ev.get("kind", "")), "word": str(ev.get("short", "")), "cat": "day", "left": left})
	if _night_jobs != null:
		for job in _night_jobs.open_jobs():
			rows.append({"id": "n%s@%d" % [str(job.get("kind", "")), int(job.get("at", 0))], "kind": str(job.get("kind", "")), "word": str(job.get("short", "")), "cat": "night", "left": -1.0})
	if biz != null and biz.has_method("waiting_sites"):
		for site in biz.waiting_sites():
			var kind := str(biz.site(str(site["key"])).get("kind", ""))
			rows.append({"id": "b%s" % str(site["key"]), "kind": str(TROUBLE_KIND.get(kind, "pub")), "word": str(TROUBLE_WORD.get(kind, "Guests")), "cat": "biz", "left": -1.0, "n": int(site["n"])})
	rows.append_array(_work_rows())
	return rows


## The camp's housework as plates too (playtest 25. 10.: "an unswept or unmade tent, cabin
## and so on as a notification with an icon on the right; the showers have no notice they
## want cleaning"): each empty lodging that is dirty (the broom) or not made up (the
## linen), each toilet and shower block worn into wanting a clean (as its own room's list
## has it: mess_rules.block_tasks) or broken.
const WORK_BLOCK_DIRTY := 0.7


func _work_rows() -> Array:
	var rows: Array = []
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or GuestManager == null:
		return rows
	for key in state.accommodation_states.keys():
		var rs: Dictionary = GuestManager.get_room_state(str(key))
		if rs.is_empty() or bool(rs.get("occupied", false)):
			continue
		var st := str(rs.get("status", ""))
		if st != "dirty" and st != "unprepared":
			continue
		var kind := GuestManager.lodging_kind(str(rs.get("building_type", "")))
		var no: int = GuestManager.room_number(str(key))
		var word := tr(kind.capitalize()) + (" %d" % no if no > 0 else "")
		rows.append({"id": "w%s" % str(key), "kind": "clean" if st == "dirty" else "bed", "word": word, "cat": "work", "left": -1.0})
	for coord in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[coord]
		var t := str(cell.get("type", ""))
		if (t != "toilet_block" and t != "shower_block") or cell.get("root_coord", coord) != coord:
			continue
		var bkey := "%d:%d" % [coord.x, coord.y]
		if float(cell.get("maintenance", 1.0)) >= WORK_BLOCK_DIRTY and not state.failures.has(bkey):
			continue
		rows.append({"id": "w%s" % bkey, "kind": "toilet" if t == "toilet_block" else "shower", "word": tr("Toilets") if t == "toilet_block" else tr("Showers"), "cat": "work", "left": -1.0})
	return rows


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
	if GuestManager == null or not GuestManager.has_method("get_liminal_forecast_data") or not camp_rule("threats"):
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
	if not _gameplay_started or _menu_mode or _game_over_active or not Coop.sim_here():
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
	# with them. You read the mail, plan tomorrow and go to bed (DESIGN §3). A sandbox
	# camp can have every night quiet.
	if night_index <= QUIET_NIGHTS or not camp_rule("threats"):
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
		var turned := entry.duplicate()
		turned["guest"] = _pick_turned_guest(str(entry.get("archetype", "")))
		_start_enemy_brain(script, night_index, difficulty, turned)
		# More Quiet Guys turned, more Silent Men (playtest 25. 10.: "more of them = you have
		# to choose whom to light"), each one of them, up to three.
		if script == SILENT_MAN_BRAIN_SCRIPT and spawned >= 2:
			var taken: Array = [int((turned["guest"] as Dictionary).get("id", -1))]
			for nth in range(1, mini(spawned, SILENT_MEN_MAX)):
				var more := entry.duplicate()
				more["nth"] = nth
				more["guest"] = _pick_turned_guest(str(entry.get("archetype", "")), taken)
				taken.append(int((more["guest"] as Dictionary).get("id", -1)))
				_start_enemy_brain(script, night_index, difficulty, more)
		total_spawned += spawned
		kinds += 1
	if _antlered_comes(kinds):
		_start_enemy_brain(STALKER_BRAIN_SCRIPT, night_index, mini(5, worst + 1), {})
	_active_enemy_spawned_this_night = total_spawned
	var claimed_virtual = mini(total_spawned, _liminal_virtual_enemy_count)
	_liminal_virtual_enemy_count = maxi(0, _liminal_virtual_enemy_count - claimed_virtual)


## The boss night: three kinds turned at once, or a camp this full.
const ANTLERED_GUESTS := 16
## Silent Men at once at most (one for each Quiet Guy turned).
const SILENT_MEN_MAX := 3


func _antlered_comes(kinds_turned: int) -> bool:
	if kinds_turned >= 3:
		return true
	var guests := 0
	for g in CoreRoot.get_state().guests:
		if g is Dictionary and str((g as Dictionary).get("status", "")) in ["active", "sleep"]:
			guests += 1
	return kinds_turned >= 1 and guests >= ANTLERED_GUESTS


## The guest of `archetype` who turns tonight: one of them in the camp, by chance
## ({id, name}; empty when none is there, as in a debug spawn).
func _pick_turned_guest(archetype: String, not_these: Array = []) -> Dictionary:
	var pool: Array = []
	for g in CoreRoot.get_state().guests:
		if not (g is Dictionary) or not_these.has(int((g as Dictionary).get("id", -1))):
			continue
		if str((g as Dictionary).get("archetype", "")) == archetype and str((g as Dictionary).get("status", "")) in ["active", "sleep"]:
			pool.append(g)
	if pool.is_empty():
		return {}
	var g: Dictionary = pool[_liminal_forecast_rng.randi() % pool.size()]
	return {"id": int(g.get("id", -1)), "name": str(g.get("name", ""))}


## Dawn: every guest whose turned self got you in the night is gone (their things go to
## the lost and found, their bed was not slept in).
func _claim_turned_guests() -> void:
	_claim_rings()
	for brain in _enemy_brains:
		if brain == null or brain.get("claimed") != true:
			continue
		var entry = brain.get("_night_entry")
		var guest: Dictionary = (entry as Dictionary).get("guest", {}) if entry is Dictionary else {}
		var id := int(guest.get("id", -1))
		if id < 0:
			continue
		if GuestManager.vanish_guest(id) and _hud_manager != null:
			_hud_manager.push_status("Morning: %s is gone. The bed was not slept in." % str(guest.get("name", "a guest")), 2)


## Dawn: the mushroom granny's rings closed round a lodging (basket_brain.gd): its
## guests wake sick, and on a heavy night one of them is gone.
func _claim_rings() -> void:
	for brain in _enemy_brains:
		if brain == null or not brain.has_method("closed_ring_lodgings"):
			continue
		var keys: Array = brain.closed_ring_lodgings()
		if keys.is_empty():
			continue
		var taken := false
		for g in GuestManager.get_guest_life_snapshot():
			var c = g.get("lodging", Vector2i(-1, -1))
			if not (c is Vector2i) or not keys.has("%d:%d" % [c.x, c.y]):
				continue
			var id := int(g.get("id", -1))
			if int(brain.get("_difficulty")) >= 4 and not taken and GuestManager.vanish_guest(id):
				taken = true
				if _hud_manager != null:
					_hud_manager.push_status("Morning: %s is gone. A ring of mushrooms round the door." % str(g.get("name", "a guest")), 2)
				continue
			GuestManager.apply_guest_event(id, -22.0, "I dreamt something was growing out of my mouth. There are mushrooms round the door.")


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
## The night things' lines (enemy_base._announce/_feed) are not shown: no text tells
## you what is out there or what just happened (Richard, 20. 10.: it kills the vibe).
## The sounds, the eyes and the sixth sense say it. Kept for the log only.
var last_enemy_line := ""


func _on_enemy_notice(text: String) -> void:
	last_enemy_line = text


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


## The corn is there for the boy to be lost in (scripts/enemies/boy_brain.gd).
func corn_field_ready() -> bool:
	return _corn_field() != null


func corn_hunt_possible() -> bool:
	return _corn_field() != null and not _corn_wanderers().is_empty()


func corn_gate_world() -> Vector3:
	var corn := _corn_field()
	return Vector3(corn.fence_x, 0.0, corn.gate_z) if corn != null else Vector3.INF


## The boy in the corn from behind (his back to you, hiding).
const CORN_BOY_SPRITE := "res://assets/textury/npc/boy_back.png"


func start_corn_hunt(job: Dictionary) -> bool:
	var corn := _corn_field()
	var guests := _corn_wanderers()
	# The family's boy (boy_brain.gd): it is him in there, not a guest.
	if job.has("boy") and corn != null:
		var of: Dictionary = job.get("boy_of", {})
		guests = [{"id": int(of.get("id", -1)), "name": "The boy", "boy": int(job["boy"]),
			"sprite_path": CORN_BOY_SPRITE if ResourceLoader.exists(CORN_BOY_SPRITE) else "res://assets/textury/npc/enemy_child.png"}]
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
	job["title"] = "A child is lost in the corn" if job.has("boy") else "%s is lost in the corn" % str(guest.get("name", "Someone"))
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
	if int(hunt.get("boy")) > 0:
		# The boy: out, he is back in the tent by morning; not, the family is gone at dawn
		# (boy_brain claimed).
		if rescued:
			_corn_job["rescued"] = true
			for b in _enemy_brains:
				if b != null and b.has_method("boy_found"):
					b.boy_found()
		hunt.queue_free()
		return
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
## Shot driver: the Builder 98 window's module (catalogue, toolbar), or null.
func debug_builder_module() -> Node:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var ui = bi.get("_crt_ui") if bi != null else null
	if ui == null:
		return null
	for n in ui.find_children("*", "Control", true, false):
		if n.get_script() == load("res://scripts/builder_module.gd"):
			return n
	return null


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
	if ui == null or not ui.has_method("close_message_boxes"):
		return 0
	return int(ui.close_message_boxes())


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
	# The office's lights off, the back room's lamp off (kept with the save).
	_interior_manager._building_interior.coop_take_office_state({"lights": false, "lamp": false})


func debug_saved_bits() -> Array:
	var os = _interior_manager._building_interior.get("_crt_ui")
	var office: Dictionary = _interior_manager._building_interior.coop_office_state()
	return [int(_director.ever.get("knock", 0)), _director.last_log.duplicate(true), snappedf(EmailManager.reputation, 0.01), _day_events.haunted.duplicate(),
		os.get_meta("datapunch_nights", {}) if os != null else "no os", {"lights": office.get("lights"), "lamp": office.get("lamp")}]


func debug_save_and_reload() -> String:
	var path := request_manual_save("Roundtrip")
	_director.ever.clear()
	_director.last_log = []
	EmailManager.reputation = 0.0
	_day_events.haunted.clear()
	var os = _interior_manager._building_interior.get("_crt_ui")
	if os != null:
		os.set_meta("datapunch_nights", {})
	_interior_manager._building_interior.coop_take_office_state({"lights": true, "lamp": true})
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
func debug_send_guests_to(building_type: String, minutes: int = 120, walk := false) -> int:
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
		var act: Dictionary = life._make_activity("visit", here, life._door_tile(f, here), now if walk else now - 20, minutes, "fun", f)
		if not walk:
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
			n.select_page(id)


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


## Tools: the frames a second now (the shot driver's eval cannot reach Engine).
func debug_fps() -> float:
	return Engine.get_frames_per_second()


## Tools: today's first applicant taken on at the staffroom (its slug, "" none).
func debug_hire_hand() -> String:
	var app: Array = load("res://core/systems/staff_rules.gd").applicants(_day_index, [], 7)
	if app.is_empty() or CoreRoot.actions == null or not CoreRoot.actions.staff_hire(app[0], _day_index):
		return ""
	return str(app[0].get("slug", ""))


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
		# A second of the same (the Silent Men): its own name for the night's picture.
		var nth := 0
		for b in _enemy_brains:
			if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == enemy_id:
				nth += 1
		_start_enemy_brain(scripts[enemy_id], _day_index, difficulty, {"nth": nth} if nth > 0 else {})


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
	if _away_in_town():
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	return true


## In Lesna (scripts/town/town_trip.gd): the camp's night does not follow you there.
func _away_in_town() -> bool:
	var trip = _interior_manager.town_trip() if _interior_manager != null and _interior_manager.has_method("town_trip") else null
	return trip != null and bool(trip.away())


func _on_day_phase_started() -> void:
	if not _gameplay_started or _menu_mode:
		return
	if not Coop.sim_here():
		# The other warden's machine: only what dawn does to you.
		if _player != null and _player.has_method("recharge_flashlight"):
			_player.recharge_flashlight()
		return
	_claim_turned_guests()
	_stop_active_enemy_brain()
	if _director_fx != null:
		_director_fx.clear()
	# The bazaar's buyers called in the night: what sold is paid at dawn.
	_settle_bazaar()
	_settle_goggle()
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
	if damage_amount > 0:
		_regen_wait = DAY_REGEN_WAIT
	if damage_amount > 0 and _gameplay_started and not _menu_mode:
		var fatal_hit := _player_health <= 0
		_emit_player_damage_feedback(damage_amount, fatal_hit)
	if allow_game_over and _player_health <= 0:
		_trigger_game_over(GAME_OVER_REASON_DEATH)


## By day the wounds mend slowly (playtest 25. 10.: "a slow regeneration of HP by day"):
## DAY_REGEN_PER_SEC health a second, once DAY_REGEN_WAIT seconds have gone by without a
## hurt; at night only the morning mends them (the first-aid box at dawn).
const DAY_REGEN_PER_SEC := 0.12
const DAY_REGEN_WAIT := 25.0
var _regen_wait := 0.0
var _regen_acc := 0.0


func _tick_day_regen(delta: float) -> void:
	if _game_over_active or _menu_mode or not _gameplay_started or _player_health >= PLAYER_MAX_HEALTH or _player_health <= 0:
		_regen_acc = 0.0
		return
	if _time_state != TIME_DAY:
		return
	_regen_wait = maxf(0.0, _regen_wait - delta)
	if _regen_wait > 0.0:
		return
	_regen_acc += delta * DAY_REGEN_PER_SEC
	if _regen_acc >= 1.0:
		var n := int(_regen_acc)
		_regen_acc -= float(n)
		_set_player_health(_player_health + n, false)


func damage_player(amount: int) -> void:
	if amount <= 0 or _coop_down:
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
	if _hurt_fx == null or not is_instance_valid(_hurt_fx):
		_hurt_fx = HURT_FX_SCRIPT.new()
		_hurt_fx.set("main", self)
		add_child(_hurt_fx)
	_hurt_fx.hit(damage_amount, tier, fatal_hit)
	if _player != null and _player.has_method("play_damage_feedback"):
		_player.play_damage_feedback(tier, damage_amount, fatal_hit)
	_spawn_blood_damage_fx(tier, fatal_hit)


func _reset_player_damage_feedback() -> void:
	if _hurt_fx != null and is_instance_valid(_hurt_fx):
		_hurt_fx.clear()
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
	# Co-op: the camp goes on for the other warden; you come to by the office.
	if reason == GAME_OVER_REASON_DEATH and Coop.has_partner():
		_coop_come_to()
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


## _generate_grid_world for the boot: the generator's steps with the boot screen's bar
## between them (world_generator.generate_world_stepped).
func _generate_grid_world_stepped() -> void:
	if grid_manager == null or building_manager == null or world_generator == null:
		_generate_grid_world()
		return
	grid_manager.initialize_grid(Vector2i(28, 28), 4.0)
	building_manager.setup(grid_manager)
	world_generator.setup(grid_manager, building_manager)
	world_generator.world_seed = 0
	# The texture pack first, a batch a frame (texture_style.gd, shared by everything).
	if _texture_style != null and _texture_style.has_method("ensure_loaded_stepped"):
		await _texture_style.ensure_loaded_stepped(_boot_step, 0.45, 0.62)
	await world_generator.generate_world_stepped(_boot_step)
	if world_generator.get_node_or_null("Terrain") == null:
		push_error("World generation failed: Terrain node was not created.")
		world_generator.create_emergency_ground(_world_3d)


func _generate_grid_world() -> void:
	if grid_manager == null or building_manager == null or world_generator == null:
		push_error("Grid world init failed: one or more managers are missing.")
		world_generator.create_emergency_ground(_world_3d)
		return

	grid_manager.initialize_grid(Vector2i(28, 28), 4.0)
	building_manager.setup(grid_manager)
	world_generator.setup(grid_manager, building_manager)
	# A fresh camp: the seed asked for on NEW CAMP, or a new one (world_generator.world_seed).
	world_generator.world_seed = _pending_world_seed
	_pending_world_seed = 0
	world_generator.generate_world()

	if world_generator.get_node_or_null("Terrain") == null:
		push_error("World generation failed: Terrain node was not created.")
		world_generator.create_emergency_ground(_world_3d)


## Tools (screenshot driver) may park a camera here to look at the camp from outside;
## old Vondra's Skoda (town/skoda_ride.gd) parks its passenger seat's here for the drive.
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
		# Its FOV is the player's own (the warden's Options, wider in a run): until 21. 10.
		# it was set back to 56 here every frame.
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
	if new_state != "departed" or not _gameplay_started or CoreRoot.get_state() == null or not Coop.sim_here():
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


# ── Goggle (scripts/reviews/goggle.gd, the PC's Reviews tab) ──────────────────

## At the start of play: a new camp's page (last summer's reviews), a loaded one's, or a
## save from before Goggle (its guests' reviews put up again).
func _setup_goggle() -> void:
	if not _pending_goggle.is_empty():
		_goggle.import_state(_pending_goggle)
		_pending_goggle.clear()
	elif _goggle_fresh:
		_goggle.reset(world_generator.world_seed if world_generator != null else 0)
		var state = CoreRoot.get_state()
		if state != null:
			for r in state.guest_reviews:
				if r is Dictionary:
					_goggle.add_guest_review(r, _day_index)
		_goggle.check_tier(_day_index)
	if not _pending_graph.is_empty():
		_day_graph.import_state(_pending_graph)
		_pending_graph.clear()
	elif _goggle_fresh:
		_day_graph.reset()
	_goggle_fresh = false
	if not EventBus.guest_review_posted.is_connected(_on_review_for_goggle):
		EventBus.guest_review_posted.connect(_on_review_for_goggle)


func _on_review_for_goggle(review: Dictionary) -> void:
	if not _gameplay_started or not Coop.sim_here() or not (review is Dictionary):
		return
	_goggle.add_guest_review(review, _day_index)
	_announce_goggle_tier(_goggle.check_tier(_day_index))


func _announce_goggle_tier(opened: int) -> void:
	if opened < 1 or _hud_manager == null:
		return
	_hud_manager.push_status("%d guests in the camp. Builder 98 has new blueprints." % int(_goggle.TIERS[opened]["guests"]), 1)


## Builder 98's blueprints open by the guests in the camp at once (goggle.check_guests;
## 10, 20, 30...), not by the rating (Richard, 20. 10.). Counted every two seconds.
var _blueprint_guests_t := 0.0


func _tick_blueprint_guests(delta: float) -> void:
	if not _gameplay_started or _menu_mode or GuestManager == null:
		return
	_blueprint_guests_t -= delta
	if _blueprint_guests_t > 0.0:
		return
	_blueprint_guests_t = 2.0
	_announce_goggle_tier(_goggle.check_guests(guests_in_camp()))


## People staying in the camp now (each party's size; not the ones still at the gate).
func guests_in_camp() -> int:
	var n := 0
	if GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			if g is Dictionary and str(g.get("status", "")) in ["active", "sleep"]:
				n += int(g.get("party_size", 1))
	return n


## The morning: SpotlessName's removals done (or caught), the apologies answered.
func _settle_goggle() -> void:
	_record_day_graph(_day_index - 1)
	var r: Dictionary = _goggle.settle(_day_index)
	if _hud_manager != null:
		for e in r["removed"]:
			_hud_manager.push_status("SpotlessName Ltd: %s's review is gone." % str(e["name"]), 1)
		for e in r["caught"]:
			_hud_manager.push_status("Goggle caught the removal of %s's review. It stays, and so does the fee." % str(e["name"]), 2)
		for e in r["edited"]:
			_hud_manager.push_status("Goggle: %s added a star to their review." % str(e["name"]), 1)
	_announce_goggle_tier(int(r["tier"]))


## Reviews tab: have a review taken down by the morning. {ok, cost, reason}.
func goggle_remove(id: int) -> Dictionary:
	var cost: int = _goggle.removal_cost()
	if CoreRoot.get_money() < cost:
		return {"ok": false, "reason": "money", "cost": cost}
	if Coop.is_client():
		# The host's page; the fee goes with the till.
		CoreRoot.actions.spend_money(cost)
		var e: Dictionary = _goggle.by_id(id)
		if not e.is_empty():
			e["removing"] = _day_index
		Coop.send_request("goggle_remove", [id])
		return {"ok": true, "cost": cost}
	if not _goggle.request_removal(id, _day_index):
		return {"ok": false, "reason": "no", "cost": cost}
	CoreRoot.actions.spend_money(cost)
	return {"ok": true, "cost": cost}


## The day that ended, for Builder 98's Graphs: the cash, the people staying, their mood,
## the rating it had.
func _record_day_graph(day: int) -> void:
	if day < 1:
		return
	var people := 0
	var mood := 0.0
	if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			if g is Dictionary:
				people += int(g.get("party_size", 1))
	if GuestManager != null and GuestManager.has_method("get_camp_mood_summary"):
		mood = float((GuestManager.get_camp_mood_summary() as Dictionary).get("avg_mood", 0.0))
	# The businesses' takings of the day that closed (each site's "yesterday" by now).
	var takings := {}
	var st = CoreRoot.get_state()
	var sites: Dictionary = st.biz.get("sites", {}) if st != null and st.biz is Dictionary else {}
	for key in sites:
		var site: Dictionary = sites[key] if sites[key] is Dictionary else {}
		var kind := str(site.get("kind", ""))
		if kind != "":
			takings[kind] = int(takings.get(kind, 0)) + int((site.get("yesterday", {}) as Dictionary).get("takings", 0))
	_day_graph.record(day, CoreRoot.get_money(), people, mood, _goggle.rating(day), takings)


## Reviews tab: answer a review as the owner ("sorry" / "weather"). The guest book's mail
## of the same review is answered with it (its effect on the bookings).
func goggle_reply(id: int, kind: String) -> void:
	var e: Dictionary = _goggle.by_id(id)
	if e.is_empty():
		return
	if Coop.is_client():
		e["reply"] = kind
		e["reply_day"] = _day_index
		Coop.send_request("goggle_reply", [id, kind])
		return
	if not _goggle.reply(id, kind, _day_index):
		return
	if EmailManager != null and EmailManager.has_method("reply_to_review") and int(e["guest_id"]) >= 0:
		for m in EmailManager.inbox:
			if m is Dictionary and str(m.get("type", "")) == "review" and int((m.get("review", {}) as Dictionary).get("guest_id", -2)) == int(e["guest_id"]):
				EmailManager.reply_to_review(m, "sorry" if kind == "sorry" else "defend")
				break


## The guest book mail answered in CampMail: the same review on Goggle has the answer.
func goggle_mail_replied(guest_id: int, reply_id: String) -> void:
	if guest_id < 0:
		return
	for e in _goggle.reviews:
		if int(e["guest_id"]) == guest_id and str(e["reply"]) == "":
			_goggle.reply(int(e["id"]), {"sorry": "sorry", "thank": "thanks"}.get(reply_id, "weather"), _day_index)
			return


## Builder 98: may this be built (or this upgrade bought) at the camp's rating?
func goggle_unlocked(item: String) -> bool:
	return _goggle.unlocked(item)


## The bazaar page's "put it up" link (browser).
func bazaar_list(id: int) -> bool:
	# Co-op: the host's lost and found (the pulse brings it back as the host has it).
	if Coop.is_client():
		Coop.send_request("bazaar_list", [id])
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
	if Coop.is_client():
		# The bills are the host's: paid there (the money with its till); gone from the
		# list here at once, the pulse brings the rest.
		for i in _billing.bills.size():
			var bill: Dictionary = _billing.bills[i]
			if str(bill.get("id", "")) != bill_id.strip_edges():
				continue
			var amount := maxi(0, int(bill.get("amount", 0)))
			if str(bill.get("status", "unpaid")) == "paid":
				return {"ok": false, "reason": "already_paid"}
			if CoreRoot.get_money() < amount:
				return {"ok": false, "reason": "insufficient_funds", "amount": amount}
			_billing.bills.remove_at(i)
			Coop.send_request("pay_bill", [bill_id.strip_edges()])
			return {"ok": true, "amount": amount}
		return {"ok": false, "reason": "not_found"}
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
			# Not behind the title screen (it lit the menu's camp after Quit to menu: playtest 21. 10.).
			_player.set_flashlight_allowed(lamp_and_flashlight_active and not _menu_mode)
		if building_manager != null and building_manager.has_method("set_lamps_active"):
			building_manager.set_lamps_active(lamp_and_flashlight_active and grid_power_available)
	if _interior_manager != null and _interior_manager.has_method("set_grid_power_available"):
		_interior_manager.set_grid_power_available(grid_power_available)
	if _audio_manager != null and _audio_manager.has_method("refresh_ambient_audio"):
		# Ambient windows (crickets, birds) depend on hour-of-day, not only day/evening/night state.
		_audio_manager.refresh_ambient_audio(_time_of_day_hours, _gameplay_started)
	# The evening's one old piece only where the camp's own music is missing.
	var own_music: bool = _music_director != null and _music_director.has_music()
	if not own_music and _audio_manager != null and _audio_manager.has_method("try_roll_evening_ambient_music") and _audio_manager.has_method("get_ambient_music_trigger_hour"):
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
	# No line in the feed for it: the player sees the weather change (the user 30. 10.).


func _setup_audio() -> void:
	if _audio_manager != null and is_instance_valid(_audio_manager):
		_audio_manager.queue_free()
	_audio_manager = AUDIO_MANAGER_SCRIPT.new()
	_audio_manager.name = "AudioManager"
	_world_3d.add_child(_audio_manager)
	if _audio_manager.has_method("setup_audio"):
		_audio_manager.setup_audio()
	if _music_director == null or not is_instance_valid(_music_director):
		_music_director = preload("res://scripts/audio/music_director.gd").new()
		_music_director.name = "MusicDirector"
		_music_director.main = self
		add_child(_music_director)


func _try_interact() -> void:
	if _pause_menu != null and _pause_menu.is_open() or _coop_down:
		return
	if _coop_partner_down_near():
		_coop_lift_partner()
		return
	if Coop.is_client():
		_coop_client_interact()
		return
	if _lake_trip != null and not _is_any_interior_open() and _lake_trip.try_interact():
		return
	if _in_attraction() and _warden_play.try_interact():
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
	if _warden_play != null and not _is_any_interior_open() and _warden_play.try_interact():
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
	_player.set_controls_enabled(not _is_any_interior_open() and not (_lake_trip != null and _lake_trip.is_active()) and not _coop_menu_up() and not _in_attraction() and not _coop_down)


## Sat by the fire, on the swing, at the net... (scripts/attractions/warden_play.gd).
func _in_attraction() -> bool:
	return _warden_play != null and is_instance_valid(_warden_play) and _warden_play.is_active()

## The torch hand at the bottom right while the torch is on outdoors (scripts/ui/torch_hand.gd).
var _torch_hand: CanvasLayer
## The numbers on the tents, cabins and caravans (scripts/lodging_signs.gd).
var _lodging_signs: Node


## The camp you inherit is not new: the old cabin by the office, shut since last summer, rotten
## (its condition at the bottom, broken until it is patched up with R) and filthy inside
## (GuestManager.make_room_derelict). It is the first job and the lesson in how a room
## works (quest steps fix_cabin, clean_cabin). The key of its room, "" if there is none.
var _ruined_cabin_key := ""
const RUINED_CABIN_CONDITION := 0.06


func ruined_cabin_key() -> String:
	return _ruined_cabin_key


## Shot driver: patch the old cabin up as hold R would (no charge).
func debug_repair_ruined() -> bool:
	if _ruined_cabin_key.is_empty():
		return false
	var parts := _ruined_cabin_key.split(":")
	return CoreRoot.actions.service_building(Vector2i(int(parts[0]), int(parts[1])), 0)


func _place_ruined_cabin() -> void:
	_ruined_cabin_key = ""
	if grid_manager == null or CoreRoot == null or CoreRoot.get_state() == null:
		return
	var office := Vector2i(-1, -1)
	var structures_root := building_manager.get_node_or_null("Structures") if building_manager != null else null
	if structures_root != null:
		for c in structures_root.get_children():
			if str(c.get_meta("building_type", "")) == "main_building":
				office = c.get_meta("grid_origin", Vector2i(-1, -1))
	if office.x < 0:
		return
	var fp := Vector2i(2, 2)
	var state = CoreRoot.get_state()
	for off in [Vector2i(-3, 1), Vector2i(3, 1), Vector2i(-3, 3), Vector2i(3, 3), Vector2i(-4, 0), Vector2i(4, 0), Vector2i(-3, 5), Vector2i(3, 5)]:
		var at: Vector2i = office + off
		if not _clear_trees_for(at, fp):
			continue
		if not state.grid.can_place_footprint(at, fp):
			continue
		var money_before: int = CoreRoot.get_money()
		EventBus.RequestBuild.emit("cabin_1", at, 0)
		if str((state.grid.cells.get(at, {}) as Dictionary).get("type", "")) != "cabin_1":
			continue
		# It was already here: what the build charged goes back.
		CoreRoot.actions.add_money(money_before - CoreRoot.get_money())
		var inst := str((state.grid.cells[at] as Dictionary).get("id", ""))
		for c2 in state.grid.cells.keys():
			var cell: Dictionary = state.grid.cells[c2]
			if str(cell.get("id", "")) == inst:
				cell["maintenance"] = RUINED_CABIN_CONDITION
				state.grid.cells[c2] = cell
		var key := "%d:%d" % [at.x, at.y]
		state.failures[key] = {"type": "cabin_1", "coord": at, "since_day": 1, "repair_progress": 0.0, "derelict": true}
		if structures_root != null and building_manager.has_method("set_structure_condition"):
			for c3 in structures_root.get_children():
				if c3.get_meta("grid_origin", Vector2i(-99, -99)) == at:
					building_manager.set_structure_condition(c3, RUINED_CABIN_CONDITION)
		if GuestManager != null and GuestManager.has_method("make_room_derelict"):
			GuestManager.make_room_derelict(key)
		_ruined_cabin_key = key
		_dress_ruined_cabin()
		return


func _ruined_structure() -> Node3D:
	if _ruined_cabin_key.is_empty() or building_manager == null:
		return null
	var parts := _ruined_cabin_key.split(":")
	var at := Vector2i(int(parts[0]), int(parts[1]))
	var root := building_manager.get_node_or_null("Structures")
	if root == null:
		return null
	for c in root.get_children():
		if c.get_meta("grid_origin", Vector2i(-99, -99)) == at:
			return c as Node3D
	return null


## While it is still broken: boards nailed over the windows and across the door, weeds
## up the walls, sheets off the roof lying in the grass. Gone when it is patched up.
func _dress_ruined_cabin() -> void:
	var cabin := _ruined_structure()
	if cabin == null or cabin.get_node_or_null("Ruin") != null:
		return
	if not CoreRoot.get_state().failures.has(_ruined_cabin_key):
		return
	var ws: Vector3 = cabin.get_meta("wall_size", Vector3(6.24, 2.8, 6.24))
	var front := ws.z * 0.5
	var ruin := Node3D.new()
	ruin.name = "Ruin"
	cabin.add_child(ruin)
	var plank := StandardMaterial3D.new()
	plank.albedo_texture = load("res://assets/textury/camp/planks_dark.png")
	plank.albedo_color = Color(0.7, 0.62, 0.52)
	plank.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plank.uv1_triplanar = true
	var weed := StandardMaterial3D.new()
	weed.albedo_color = Color(0.26, 0.36, 0.16)
	var sheet := StandardMaterial3D.new()
	sheet.albedo_texture = load("res://assets/textury/camp/corrugated_roof.png")
	sheet.albedo_color = Color(0.6, 0.5, 0.42)
	sheet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sheet.uv1_triplanar = true
	var boards: Array = []
	# Over the front windows where the cabin's plan has them (scripts/cabin_layout.gd).
	var CL = load("res://scripts/cabin_layout.gd")
	var win_y: float = CL.MODEL_FLOOR + CL.SILL_MID
	for x: float in [-CL.FRONT_WIN_X, CL.FRONT_WIN_X]:
		boards.append([Vector3(0.9, 0.12, 0.04), Vector3(x, win_y + 0.1, front + 0.07), 0.32])
		boards.append([Vector3(0.9, 0.12, 0.04), Vector3(x, win_y - 0.12, front + 0.08), -0.28])
	boards.append([Vector3(1.15, 0.15, 0.05), Vector3(0, 1.25, front + 0.09), 0.18])
	boards.append([Vector3(1.15, 0.15, 0.05), Vector3(0, 0.7, front + 0.1), -0.22])
	for b in boards:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[0]
		m.mesh = bm
		m.material_override = plank
		m.position = b[1]
		m.rotation.z = float(b[2])
		ruin.add_child(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = _ruined_cabin_key.hash()
	for i in 26:
		var side := rng.randi_range(0, 3)
		var t := rng.randf_range(-0.5, 0.5)
		var at := Vector3(t * ws.x, 0, front + 0.12) if side == 0 else (Vector3(t * ws.x, 0, -front - 0.12) if side == 1 else Vector3((ws.x * 0.5 + 0.12) * (1.0 if side == 2 else -1.0), 0, t * ws.z))
		var h := rng.randf_range(0.25, 0.7)
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.07, h, 0.07)
		w.mesh = wm
		w.material_override = weed
		w.position = at + Vector3(0, h * 0.5, 0)
		w.rotation.z = rng.randf_range(-0.3, 0.3)
		ruin.add_child(w)
	for i in 2:
		var sm := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(1.4, 0.03, 0.8)
		sm.mesh = sb
		sm.material_override = sheet
		sm.position = Vector3(-1.2 + i * 2.6, 0.04 + i * 0.03, front + 1.1 + i * 0.3)
		sm.rotation = Vector3(0.05, 0.6 - i * 1.1, 0.08)
		ruin.add_child(sm)


## Patched up (hold R): the boards come off, the weeds are pulled, the sheets go back.
func _on_building_serviced_for_ruin(root: Vector2i, _type: String, _was_broken: bool, _cost: int) -> void:
	if _ruined_cabin_key.is_empty() or "%d:%d" % [root.x, root.y] != _ruined_cabin_key:
		return
	var cabin := _ruined_structure()
	var ruin := cabin.get_node_or_null("Ruin") if cabin != null else null
	if ruin != null:
		ruin.queue_free()


## The trees (and corn) standing where the old cabin goes: grown in round it since the
## camp shut. False when something else is in the way (a building, the path, the lake).
func _clear_trees_for(origin: Vector2i, fp: Vector2i) -> bool:
	for y in fp.y:
		for x in fp.x:
			var c := origin + Vector2i(x, y)
			if not grid_manager.is_in_bounds(c):
				return false
			var tile = grid_manager.get_tile(c)
			if tile == null or tile.tile_type != grid_manager.TILE_GRASS:
				return false
			var occ = tile.occupant
			if occ != null and is_instance_valid(occ):
				var n: Node = occ
				while n != null and not n.has_meta("grid_origin"):
					n = n.get_parent()
				if n != null:
					return false
	for y in fp.y:
		for x in fp.x:
			var c2 := origin + Vector2i(x, y)
			var tile2 = grid_manager.get_tile(c2)
			if tile2 != null and tile2.occupant != null and is_instance_valid(tile2.occupant):
				(tile2.occupant as Node).queue_free()
			grid_manager.set_tile_occupied(c2, false, null)
	return true


func _update_torch_hand() -> void:
	if not EventBus.building_serviced.is_connected(_on_building_serviced_for_ruin):
		EventBus.building_serviced.connect(_on_building_serviced_for_ruin)
	if _lodging_signs == null or not is_instance_valid(_lodging_signs):
		_lodging_signs = load("res://scripts/lodging_signs.gd").new()
		_lodging_signs.name = "LodgingSigns"
		add_child(_lodging_signs)
	if _torch_hand == null or not is_instance_valid(_torch_hand):
		_torch_hand = load("res://scripts/ui/torch_hand.gd").new()
		_torch_hand.name = "TorchHand"
		add_child(_torch_hand)
	var on: bool = _gameplay_started and not _menu_mode and _player != null and _player.has_method("is_flashlight_active") \
		and bool(_player.is_flashlight_active()) and not _is_any_interior_open() \
		and not (_lake_trip != null and _lake_trip.is_active()) and not get_tree().paused and not _in_attraction() \
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
	if _coop_down:
		_hud_manager.set_hint_text("")
		return
	if _coop_partner_down_near():
		_hud_manager.set_hint_text("[E] Get %s up" % Coop.name_of(_coop_down_near_id))
		return
	# Something in your hands, or a small thing under the crosshair (scripts/ambient/carry.gd:
	# it takes its own E and click, on either machine).
	var carry := get_tree().get_first_node_in_group("carry")
	if carry != null and str(carry.hint()) != "":
		_hud_manager.set_hint_text(str(carry.hint()))
		return
	if Coop.is_client():
		_hud_manager.set_hint_text(_coop_client_hint())
		return
	if _is_any_interior_open():
		_hud_manager.set_hint_text("")
		return
	if _corn_hunt != null and is_instance_valid(_corn_hunt) and str(_corn_hunt.hint()) != "":
		_hud_manager.set_hint_text(str(_corn_hunt.hint()))
		return
	# A night thing's own line (the granny's basket within reach).
	for b in _enemy_brains:
		if b != null and b.has_method("hint") and str(b.hint()) != "":
			_hud_manager.set_hint_text(str(b.hint()))
			return
	var lake_hint: String = _lake_trip.hint() if _lake_trip != null else ""
	if _lake_trip != null and _lake_trip.is_active():
		# In the boat: the oars at first, the way out by the jetty (lake_trip.active_hint).
		_hud_manager.set_hint_text(str(_lake_trip.active_hint()) if _lake_trip.has_method("active_hint") else "")
		return
	if not lake_hint.is_empty():
		_hud_manager.set_hint_text(lake_hint)
		return
	if _in_attraction():
		_hud_manager.set_hint_text(str(_warden_play.hint()))
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
	var play_hint: String = _warden_play.hint() if _warden_play != null else ""
	if not play_hint.is_empty():
		_hud_manager.set_hint_text(play_hint)
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
	# Co-op: mended in the host's camp (the breakdown goes with the next pulse).
	if Coop.is_client():
		Coop.send_request("repair", [coord])
	elif economy_manager != null and economy_manager.has_method("add_repair_progress"):
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
	# Leaving a co-op camp closes the line (the other warden goes back to their menu).
	Coop.leave()
	# Whatever room, job or close-up was open is shut, or it stays under the menu taking
	# clicks (playtest 18. 10.: cleaning a tent behind the title screen).
	_leave_everything(true)
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
	if _player != null and is_instance_valid(_player) and _player.has_method("set_flashlight_allowed"):
		_player.set_flashlight_allowed(false)
	_pending_loaded_player_state.clear()
	_pending_loaded_crt_state.clear()
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)
	_close_pause_menu(false)
	_set_hud_shown(false)
	_ensure_main_menu()
	_load_preview_world_for_menu()
	_main_menu.open()
	_menu_flythrough.rebuild()
	_start_menu_music()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## The game's HUD off behind the main menu (it stayed over the title after Quit to menu),
## and the same layers back when a game starts.
var _hud_hidden: Array = []


func _set_hud_shown(on: bool) -> void:
	if _hud_manager == null or not is_instance_valid(_hud_manager):
		return
	if not on:
		for layer in _hud_manager.find_children("*", "CanvasLayer", true, false):
			if (layer as CanvasLayer).visible:
				(layer as CanvasLayer).visible = false
				_hud_hidden.append(layer)
		return
	for layer in _hud_hidden:
		if is_instance_valid(layer):
			(layer as CanvasLayer).visible = true
	_hud_hidden.clear()


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
	_main_menu.new_camp_requested.connect(_on_menu_new_camp)
	_main_menu.load_requested.connect(_on_menu_load_requested)
	_main_menu.quit_requested.connect(func() -> void: get_tree().quit())
	_main_menu.coop_host_requested.connect(_on_menu_coop_host)
	_main_menu.coop_host_saved_requested.connect(_on_menu_coop_host_saved)
	_main_menu.coop_join_requested.connect(_on_menu_coop_join)
	_main_menu.test_night_requested.connect(_on_menu_test_night)
	_wire_coop()


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
	PROFILES.activate_for_save(path)
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


## A new camp for the tools (screenshot driver, harnesses): not one of the warden's camps
## (its autosaves go to the old folder, user://saves).
func _on_menu_new_game_pressed() -> void:
	PROFILES.detach()
	await _start_new_camp(false)


## NEW CAMP (main menu, or the co-op page's Host a new camp): a camp of the warden's,
## named, its world from `seed` (0: a new one).
func _on_menu_new_camp(camp_name: String, seed: int, coop: bool, sandbox: bool, rules: Dictionary) -> void:
	if coop and not Coop.host():
		if _main_menu != null:
			_main_menu.show_coop_notice("Port %d is taken." % Coop.port)
		return
	await _start_new_camp(sandbox or coop, "", camp_name, seed, coop, rules)


## The main menu's secret test nights (L): a fresh sandbox camp with a small camp built in
## it and guests of the kind that brings the thing (`_build_test_camp`), the clock on the
## second night at 20:00 and the chosen thing already out (`debug_spawn_enemy` ids).
## Nothing is saved.
var _test_night := ""


func _on_menu_test_night(enemy_id: String) -> void:
	if enemy_id == "content":
		await _start_content_reel()
		return
	if enemy_id == "bus":
		await _start_test_bus()
		return
	if enemy_id == TEST_BUSINESSES:
		await _start_test_businesses()
		return
	await _start_new_camp(true, enemy_id)
	for _i in 60:
		if not _menu_mode:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_build_test_camp(enemy_id)
	await get_tree().process_frame
	# The jump runs the night's start (its roll stops every brain), so the thing comes after;
	# a test night after a test night is the same night 2 again.
	_stop_active_enemy_brain()
	_liminal_last_rolled_night_id = -99999
	debug_jump_to(2, BALANCE_CONFIG.NIGHT_START_HOUR)
	if enemy_id == TEST_SEWER:
		_test_sewer_wait = 0.0
		if _player != null and is_instance_valid(_player):
			_player.rotate_y(PI)
		if _hud_manager != null:
			_hud_manager.push_status("Test night: the sewer breaks again whenever it is mended.", 2)
		return
	# The boy at his worst (heavy: in the pipes both him and the raccoon).
	debug_spawn_enemy(enemy_id, 4 if enemy_id == "child" else 3)
	# It is one of the test camp's guests, turned (gone in the morning if it gets you).
	if not _enemy_brains.is_empty():
		var nb = _enemy_brains.back()
		var ne: Dictionary = nb.get("_night_entry")
		ne["guest"] = _pick_turned_guest(str(TEST_NIGHT_GUESTS.get(enemy_id, "")))
		# The boy's job at once, not an hour into the night; his places in turn.
		if nb.get("soon") != null:
			nb.set("soon", true)
		# The granny is out whatever the hour (she keeps to the small hours).
		if nb.get("soon") != null and enemy_id == "basket":
			nb.set("soon", true)
		if nb.has_method("force_place"):
			var where: String = TEST_BOY_PLACES[_test_boy_turn % TEST_BOY_PLACES.size()]
			_test_boy_turn += 1
			nb.force_place(where)
			enemy_id = "child_" + where
	# The spawn faces the office wall (a new camp starts at the desk): turn to the camp.
	if _player != null and is_instance_valid(_player):
		_player.rotate_y(PI)
	var label := enemy_id
	for entry in MAIN_MENU_SCRIPT.TEST_NIGHTS:
		if str(entry["id"]) == enemy_id:
			label = str(entry["text"])
	if _hud_manager != null:
		if enemy_id.begins_with("child_"):
			_hud_manager.push_status(str({"child_corn": "Test night: the boy is lost in the corn.",
				"child_breaker": "Test night: the boy is at the generator's board.",
				"child_sewer": "Test night: the boy is down the sewer."}.get(enemy_id, "")), 2)
		else:
			_hud_manager.push_status("Test night: the %s is out." % label, 2)


## The bus test (L, "Bus to Liblice"): a fresh sandbox camp by day, the warden at the
## camp's stop with money in the pocket just as the 13:50 comes up the road; from there
## everything as in the game (the ticket machine, the ride, the request stop at Podlesi,
## Lesna, the way back). Nothing is saved.
func _start_test_bus() -> void:
	await _start_new_camp(true, "bus")
	for _i in 60:
		if not _menu_mode:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	CoreRoot.actions.add_money(300)
	# A few seconds before it pulls up (it comes in over town_trip.IN_HOURS).
	debug_jump_to(1, BUS_TIMES.CAMP_ARRIVE[1] - 0.17)
	var trip = _interior_manager.town_trip() if _interior_manager != null else null
	if trip != null and trip.has_method("_put_player") and trip._road() != null:
		trip._put_player(trip._road().wait_spot())
	if _hud_manager != null:
		_hud_manager.push_status("Test: the 380 is coming up the road. Ticket from the yellow machine by the stop, punch it on board.", 2)


## The businesses' test camp (the title screen's L page, "Businesses"; the user 21. 10.:
## "every business, the corn, the pub, the bistro, the Jednota, and lots of people, to try
## the minigames"): a fresh camp at mid-morning, the four on paths up from the gate (each
## stocked as a new place is), tents and cabins round them full, the guests already hungry
## and thirsty, every blueprint open. Built through the real builder; what does not fit
## this camp's trees and lake is left out.
const TEST_BUSINESSES := "podniky"


## The content reel (the title screen's L page): the businesses' camp, then a day of its
## best scenes, L for the next (scripts/content_reel.gd).
func _start_content_reel() -> void:
	await _start_test_businesses(true)
	var reel = load("res://scripts/content_reel.gd").new()
	reel.name = "ContentReel"
	get_tree().root.add_child(reel)
	reel.start(self)


func _start_test_businesses(quiet := false) -> void:
	await _start_new_camp(true, TEST_BUSINESSES)
	for _i in 60:
		if not _menu_mode:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	debug_jump_to(1, 10.5)
	CoreRoot.actions.add_money(60000)
	var g: Vector2i = world_generator.gate_tile() if world_generator != null and world_generator.has_method("gate_tile") else Vector2i(12, 0)
	for x0 in range(g.x - 9, g.x + 9, 5):
		for y0 in range(4, 19, 5):
			EventBus.RequestDemolish.emit(Rect2i(x0, y0, 5, 5))
	for y in range(4, 18):
		EventBus.RequestBuild.emit("path", Vector2i(g.x, y), 0)
	for x in range(g.x - 8, g.x + 9):
		if x != g.x:
			EventBus.RequestBuild.emit("path", Vector2i(x, 8), 0)
			EventBus.RequestBuild.emit("path", Vector2i(x, 13), 0)
	var plan := [
		["corn_stand", Vector2i(g.x + 1, 6)], ["pub", Vector2i(g.x + 1, 9)], ["restaurant", Vector2i(g.x + 4, 9)], ["vecerka", Vector2i(g.x - 4, 9)],
		["toilet_block", Vector2i(g.x + 3, 6)], ["shower_block", Vector2i(g.x + 4, 6)], ["toilet_block", Vector2i(g.x - 1, 12)],
		["picnic_table", Vector2i(g.x + 2, 5)], ["picnic_table", Vector2i(g.x + 7, 9)], ["picnic_table", Vector2i(g.x + 7, 10)], ["bonfire", Vector2i(g.x + 7, 6)],
		["lamp_post", Vector2i(g.x - 1, 7)], ["lamp_post", Vector2i(g.x + 1, 12)], ["lamp_post", Vector2i(g.x - 6, 7)], ["lamp_post", Vector2i(g.x + 6, 12)],
		["cabin_1", Vector2i(g.x - 8, 14)], ["cabin_1", Vector2i(g.x - 5, 14)], ["cabin_1", Vector2i(g.x + 2, 14)], ["cabin_1", Vector2i(g.x + 5, 14)],
	]
	for x in [g.x - 2, g.x - 3, g.x - 5, g.x - 6, g.x - 7]:
		plan.append(["tent_1", Vector2i(x, 5)])
		plan.append(["tent_1", Vector2i(x, 6)])
	for x in [g.x - 3, g.x - 5, g.x - 7, g.x + 3, g.x + 5]:
		plan.append(["tent_1", Vector2i(x, 12)])
	_goggle.check_guests(99)
	for item in plan:
		EventBus.RequestBuild.emit(str(item[0]), item[1], 0)
	# Lodgings go up a level only as upgrades (a couple to a tent, a family to a cabin).
	for item in plan:
		if str(item[0]) in ["tent_1", "cabin_1"] and _interior_manager != null:
			_interior_manager.map_upgrade(item[1], str(item[0]))
	var parties := [["Novak", "quiet_guy", 2], ["Pepa", "drunk", 2], ["Lojza", "drunk", 2], ["Kristyna", "cheap_chick", 2], ["Denisa", "cheap_chick", 2],
		["Bobr", "tramp", 2], ["Svoboda family", "family", 3], ["Kral family", "family", 3], ["Mr Prochazka", "picker", 2], ["Dvorak", "quiet_guy", 2],
		["Kecal", "tramp", 2], ["Mrs Benesova", "picker", 2], ["Horak family", "family", 3], ["Vesely", "drunk", 2], ["Marek", "drunk", 2], ["Jana", "cheap_chick", 2],
		["Fiala family", "family", 3], ["Zeman", "quiet_guy", 2]]
	for p in parties:
		GuestManager.debug_check_in_party(str(p[0]), str(p[1]), int(p[2]), 3)
	GuestManager.debug_want_food(55.0, 85.0)
	# On the path just in from the gate, the businesses ahead.
	if _player != null and is_instance_valid(_player) and grid_manager != null:
		_player.global_position = grid_manager.grid_to_world(Vector2i(g.x, 5)) + Vector3(0, 0.2, 0)
		_player.rotation.y = PI
	if _hud_manager != null and not quiet:
		_hud_manager.push_status("Test: every business open and a full camp. The work is at their stations.", 2)


## Which guests bring which test night's thing (main_menu.TEST_NIGHTS ids).
## The boy's test night takes his places in turn (corn, board, pipes).
const TEST_BOY_PLACES := ["corn", "breaker", "sewer"]
static var _test_boy_turn := 0
const TEST_NIGHT_GUESTS := {"silent_man": "quiet_guy", "tourist": "drunk", "girl": "cheap_chick", "whistler": "tramp", "child": "family", "basket": "picker"}


## A test night's camp (playtest 18. 10.: "not an empty map"): north of the office a path
## up from the gate with a cross path, lamps along them, tents, a cabin, the toilets, a
## fire; then the guests of the kind that brings the thing, let in at once (and one of
## another kind, so the camp is not only them). Built through the real builder; what does
## not fit this camp's trees and lake is just left out.
func _build_test_camp(enemy_id: String) -> void:
	if world_generator == null or not world_generator.has_method("gate_tile"):
		return
	CoreRoot.actions.add_money(60000)
	var g: Vector2i = world_generator.gate_tile()
	for r in [Rect2i(g.x - 7, 4, 5, 5), Rect2i(g.x - 2, 4, 5, 5), Rect2i(g.x + 3, 4, 5, 5), Rect2i(g.x - 7, 9, 5, 5), Rect2i(g.x - 2, 9, 5, 5), Rect2i(g.x + 3, 9, 5, 5)]:
		EventBus.RequestDemolish.emit(r)
	for y in range(5, 13):
		EventBus.RequestBuild.emit("path", Vector2i(g.x, y), 0)
	for x in range(g.x - 6, g.x + 7):
		if x != g.x:
			EventBus.RequestBuild.emit("path", Vector2i(x, 8), 0)
	var plan := [
		["lamp_post", Vector2i(g.x, 6)], ["lamp_post", Vector2i(g.x - 5, 8)], ["lamp_post", Vector2i(g.x + 5, 8)], ["lamp_post", Vector2i(g.x, 12)],
		["tent_1", Vector2i(g.x - 5, 5)], ["tent_1", Vector2i(g.x - 3, 5)], ["tent_1", Vector2i(g.x - 5, 10)], ["tent_1", Vector2i(g.x - 3, 10)],
		["cabin_1", Vector2i(g.x + 2, 5)], ["cabin_1", Vector2i(g.x + 2, 10)],
		["toilet_block", Vector2i(g.x + 5, 5)], ["bonfire", Vector2i(g.x + 5, 10)], ["picnic_table", Vector2i(g.x - 2, 12)],
	]
	if enemy_id == TEST_SEWER:
		_test_sewer_at = Vector2i(g.x + 6, 5)
		plan.append(["sewer", _test_sewer_at])
	for item in plan:
		EventBus.RequestBuild.emit(str(item[0]), item[1], 0)
	var arch := str(TEST_NIGHT_GUESTS.get(enemy_id, ""))
	if arch.is_empty():
		return
	var names := {"quiet_guy": ["Novak", "Dvorak"], "drunk": ["Pepa", "Lojza"], "cheap_chick": ["Kristyna", "Denisa"], "tramp": ["Bobr", "Kecal"], "family": ["Svoboda family", "Kral family"], "picker": ["Mr Prochazka", "Mrs Benesova"]}
	for n in names.get(arch, ["Guest"]):
		GuestManager.debug_check_in_party(str(n), arch, 1, 3)
	GuestManager.debug_check_in_party("Mr Vesely", "quiet_guy" if arch != "quiet_guy" else "drunk", 1, 3)


## A fresh camp. `sandbox`: no month, no checklist and no story mails, the programs
## already on the PC, `rules` its switches (CAMP_RULES; co-op camps are sandbox camps).
## `test_enemy`: a test night's camp (`_on_menu_test_night`), not opened at the desk.
func _start_new_camp(sandbox: bool, test_enemy: String = "", camp_name: String = "", seed: int = 0, coop: bool = false, rules: Dictionary = {}) -> void:
	var started := Time.get_ticks_msec()
	await _show_menu_loading_for("Generating a fresh camp...")
	_reset_state_for_new_game()
	_sandbox = sandbox
	_camp_rules = CAMP_RULES.merged(rules, true) if sandbox else CAMP_RULES.duplicate()
	if int(_camp_rules.get("money", 0)) > 0:
		CoreRoot.apply_changes({"money": int(_camp_rules["money"])})
		if _week_ledger != null:
			_week_ledger.reset(int(_camp_rules["money"]))
	_test_night = test_enemy
	_pending_world_seed = seed
	_generate_grid_world()
	# The warden's new camp (scripts/profiles.gd), its saves from now on (a test night's
	# camp and the tools' are nobody's).
	if test_enemy.is_empty() and camp_name != "":
		PROFILES.create_camp(camp_name, world_generator.world_seed, sandbox, coop)
	_refresh_camp_sign()
	_rebuild_core_cells_from_visual_structures()
	# The camp's old cabin, shut since last summer: the campaign's start, not a sandbox's
	# (there you build from a clean camp: the user 20. 10.).
	if sandbox:
		_ruined_cabin_key = ""
	else:
		_place_ruined_cabin()
	if time_system != null and time_system.has_method("set_time_hours"):
		time_system.set_time_hours(9.0)
	if weather_system != null and weather_system.has_method("set_weather"):
		weather_system.set_weather(WEATHER_CLEAR)
	_sync_runtime_state_from_systems(true)
	await _hide_menu_loading_after(started, 520, false)
	_pending_quest_state_loaded = false
	if sandbox:
		_pending_loaded_crt_state = {"unlock_registry": {"builder": true, "camp_status": true, "guestrack": true, "datapunch": true}}
	_start_game_from_menu()
	# A sandbox camp has no story: no mails from Vera or Nela, no checklist. The district
	# writes how a camp starts, and the first booking comes once a bed is free.
	if not sandbox and _quest_manager != null:
		_quest_manager.begin_new_game()
	elif sandbox and test_enemy.is_empty() and EmailManager != null:
		EmailManager.sandbox_start(time_system.get_time_string() if time_system != null and time_system.has_method("get_time_string") else "09:00")
	# A new game always opens on the same song (Radio Jedna).
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi != null and bi.has_method("queue_first_radio_track"):
		bi.queue_first_radio_track()
	if not test_enemy.is_empty():
		return
	# A new week starts at the desk: the first part of the game is the computer, and
	# getting up from it is something you find out you can do.
	get_tree().create_timer(0.25).timeout.connect(func():
		if _interior_manager != null and _gameplay_started:
			_interior_manager.open_startup_crt_view()
			_first_stand_up_pending = true
	)


# ── co-op (scripts/coop/coop.gd) ────────────────────────────────────────────

## A sandbox camp (DESIGN.md §12): no month and no checklist. Co-op camps are sandbox.
var _sandbox := false
## A sandbox camp's switches (NEW CAMP): the night's things (brains, director, omens),
## weather (off: always clear), day events, breakdowns (wear and the night's jobs), the
## starting till (0: the usual). A story camp has them all on. Saved as "rules".
const CAMP_RULES := {"threats": true, "weather": true, "events": true, "wear": true, "money": 0}
var _camp_rules: Dictionary = CAMP_RULES.duplicate()


func camp_rule(id: String) -> bool:
	return bool(_camp_rules.get(id, true))
## The other warden's machine: whether the host's camp has power (its lamps follow).
var _coop_powered := true
## The host's storm on its way (coop_clock "sb"), 0..1.
var _coop_storm_build := 0.0
## The host's camp's name (its board by the gate) on the other warden's machine; a camp
## that is nobody's (the tools') keeps its own here.
var _coop_camp_name := ""
const CAMP_NAME_MAX := 24
const SIGN_PAINT := preload("res://scripts/ui/sign_paint.gd")
var _sign_paint: CanvasLayer


## The camp's name, painted on the board by the gate (playtest 25. 10.: "change the camp's
## name with E on the sign before the camp"): the profile's camp's; the host's in co-op.
func camp_name() -> String:
	if Coop.is_client() and _coop_camp_name != "":
		return _coop_camp_name
	if PROFILES.camp_id == "":
		return _coop_camp_name
	return str(PROFILES.camp_info(PROFILES.camp_id).get("name", ""))


## A new name for the camp: the profile's (the host's), the board, the other machine's.
func set_camp_name(n: String, from_peer := false) -> void:
	n = n.strip_edges().left(CAMP_NAME_MAX)
	if n == "":
		return
	if Coop.is_client() or PROFILES.camp_id == "":
		_coop_camp_name = n
	else:
		PROFILES.rename_camp(PROFILES.camp_id, n)
	_refresh_camp_sign()
	if not from_peer and Coop.is_active():
		Coop.send_sync("camp_name", [n])


func _refresh_camp_sign() -> void:
	var gate := get_tree().get_first_node_in_group("camp_gate")
	if gate != null and gate.has_method("set_camp_name"):
		gate.set_camp_name(camp_name())


## E on the board by the gate: the board up close, its name painted anew.
func open_camp_sign() -> void:
	if _sign_paint != null and is_instance_valid(_sign_paint):
		return
	_sign_paint = SIGN_PAINT.new()
	get_tree().root.add_child(_sign_paint)
	_sign_paint.open(camp_name())
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(false)
	_sign_paint.painted.connect(func(n: String): set_camp_name(n))
	_sign_paint.closed.connect(func():
		if _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled"):
			_player.set_controls_enabled(true))
var _coop_wired := false


func _wire_coop() -> void:
	if _coop_wired:
		return
	_coop_wired = true
	_ensure_coop_night()
	Coop.world_arrived.connect(_on_coop_world_arrived)
	Coop.join_failed.connect(_on_coop_join_failed)
	Coop.session_ended.connect(_on_coop_session_ended)
	Coop.warden_joined.connect(_on_coop_peer_joined)
	Coop.warden_left.connect(_on_coop_peer_left)
	Coop.warden_moved.connect(_on_coop_partner_moved)
	Coop.partner_look_changed.connect(func(_look: Dictionary) -> void:
		if _interior_manager != null and _interior_manager.has_method("coop_partner_look"):
			_interior_manager.coop_partner_look({}, 0)
	)
	# The host's camp is the camp: what is built, cleared, repaired and how its rooms
	# stand goes to the other machine (which does it again, coop_apply_fact).
	EventBus.BuildConfirmed.connect(func(t: String, at: Vector2i, rot: int) -> void:
		if Coop.is_host():
			Coop.send_fact("build", [t, at, rot])
	)
	EventBus.DemolishConfirmed.connect(func(rect: Rect2i, _n: int, _fee: int, _refund: int) -> void:
		if Coop.is_host():
			Coop.send_fact("demolish", [rect])
	)
	EventBus.building_serviced.connect(func(at: Vector2i, _t: String, _broken: bool, _cost: int) -> void:
		if Coop.is_host():
			Coop.send_fact("service", [at])
	)
	EventBus.room_task_done.connect(func(key: String, _task: String) -> void: _coop_send_room(key))
	EventBus.accommodation_state_changed.connect(func(key: String, _status: String, _n: int) -> void: _coop_send_room(key))


## The pause menu is up in a co-op camp (the world goes on; you just stand there).
func _coop_menu_up() -> bool:
	return Coop.is_active() and _pause_menu != null and _pause_menu.is_open()


## Host: a new sandbox camp, open to one more warden.
func _on_menu_coop_host() -> void:
	if not Coop.host():
		if _main_menu != null:
			_main_menu.show_coop_notice("Port %d is taken." % Coop.port)
		return
	await _start_new_camp(true)


## Host the camp last hosted for two (its newest save), for the other warden to join.
func _on_menu_coop_host_saved(path: String) -> void:
	# A story camp is one warden's (its mails, checklist and month are not for two).
	if str(SaveManager.read_save(path).get("mode", "")) != "sandbox":
		if _main_menu != null:
			_main_menu.show_coop_notice("A story camp cannot be hosted. Only sandbox camps are for two.")
		return
	if not Coop.host():
		if _main_menu != null:
			_main_menu.show_coop_notice("Port %d is taken." % Coop.port)
		return
	var started := Time.get_ticks_msec()
	await _show_menu_loading_for("Opening the camp...")
	if not _start_loaded_game_from_path(path):
		Coop.leave()
		await _hide_menu_loading_after(started, 180)
		if _main_menu != null:
			_main_menu.show_coop_notice("That camp would not open.")
		return
	await _hide_menu_loading_after(started, 520, false)
	_start_game_from_menu()


## Join: call the camp at `address`; it comes back as world_arrived or join_failed.
func _on_menu_coop_join(address: String) -> void:
	if _main_menu != null:
		_main_menu.show_loading("Calling the camp...")
	Coop.join(address)


func _on_coop_join_failed(reason: String) -> void:
	if _main_menu != null:
		_main_menu.hide_loading()
		_main_menu.show_coop_notice(reason)


## The host's camp has come down the line: it is loaded like a save, and nothing in it
## runs here (sim_here() is false): the host's clock, weather and power drive it.
func _on_coop_world_arrived(snapshot: Dictionary) -> void:
	if not _apply_save_snapshot(snapshot, false):
		Coop.leave()
		_on_coop_join_failed("The camp came through garbled.")
		return
	_active_save_path = ""
	_coop_powered = true
	_coop_till_shown = -1
	_coop_till_seq = 0
	_coop_till_pending.clear()
	_start_game_from_menu()
	if CoreRoot.failure_system != null:
		CoreRoot.failure_system.enabled = false
	_coop_forward_builds(true)
	call_deferred("_coop_flush_facts")
	# Who is about: once they have all said who they are (their hellos come a moment after).
	await get_tree().create_timer(2.0).timeout
	if _hud_manager != null and Coop.has_partner():
		_hud_manager.push_status("You came in by the barrier. %s %s about." % [_coop_names_said(), "is" if Coop.wardens.size() == 1 else "are"], 1)


func _on_coop_session_ended(reason: String) -> void:
	_coop_forward_builds(false)
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_remote = Callable()
	if _gameplay_started:
		_close_pause_menu(false)
		_enter_main_menu()
	if _main_menu != null:
		_main_menu.hide_loading()
		_main_menu.show_coop_notice(reason)


func _on_coop_peer_joined(id: int) -> void:
	# A new line: their till changes are numbered from one again.
	_coop_till_acked.erase(id)
	_coop_sync_last.clear()
	# Their name comes with their hello, a moment after the line opens.
	await get_tree().create_timer(1.0).timeout
	if _hud_manager != null and Coop.wardens.has(id):
		_hud_manager.push_status("%s came in by the barrier." % Coop.name_of(id), 1)
	# The office, the PC, the register... sent once more as they finish loading the camp:
	# what came while they were still loading was dropped there, and it is sent again only
	# when it changes (a PC on at the host stayed off for them: playtest 21. 10.).
	for wait in [4.0, 8.0, 16.0]:
		await get_tree().create_timer(wait).timeout
		if not Coop.wardens.has(id):
			return
		_coop_sync_last.clear()


func _on_coop_peer_left(id: int) -> void:
	if _hud_manager != null:
		_hud_manager.push_status("%s has gone home." % Coop.name_of(id), 1)
	_on_coop_partner_moved(id, {})
	_coop_partner_was.erase(id)


## Where another warden is (each state of theirs): the boat where they have it, their
## figure in the room you are in if they are in it; the door they go in or out by swings;
## when they lie down, you hear of it.
const COOP_DOOR_ANIM = preload("res://scripts/attractions/door_anim.gd")
## Per warden (peer id): {in: indoors, room: the room they were last in, bed: lying down}.
var _coop_partner_was: Dictionary = {}


func _on_coop_partner_moved(id: int, s: Dictionary) -> void:
	if not _coop_partner_was.has(id):
		_coop_partner_was[id] = {"in": false, "room": "", "bed": false}
	var was: Dictionary = _coop_partner_was[id]
	var room_info: Dictionary = s.get("room", {})
	var inside := bool(s.get("in", false))
	if inside != bool(was["in"]) and not s.is_empty():
		_coop_swing_door(str(room_info.get("k", "")) if inside else str(was["room"]))
	was["in"] = inside
	if inside and room_info.has("k"):
		was["room"] = str(room_info["k"])
	var in_bed := bool(s.get("z", false))
	if in_bed and not bool(was["bed"]) and _hud_manager != null:
		_hud_manager.push_status("%s has turned in." % Coop.name_of(id), 1)
	was["bed"] = in_bed
	if _lake_trip != null and _lake_trip.has_method("coop_mirror_boat"):
		# One boat: whoever of the others has it (rowing, or tied up on the far shore).
		var rower := 0
		for oid in Coop.others():
			var os: Dictionary = Coop.state_of(oid)
			if os.has("boat") or os.has("boat_at"):
				rower = int(oid)
		var rs: Dictionary = Coop.state_of(rower) if rower != 0 else {}
		_lake_trip.coop_mirror_boat(rs.get("boat", rs.get("boat_at", null)), rs.has("boat_at"), rower, rs.get("rp", []))
	if _interior_manager != null and _interior_manager.has_method("coop_partner"):
		var room: Dictionary = s.get("room", {})
		if bool(s.get("z", false)) and not room.is_empty():
			# Under the blanket: not standing about the room.
			room = room.duplicate()
			room["b"] = true
		_interior_manager.coop_partner(room, id)


## Co-op: knocked down, not dead. You fall and lie where you fell (the other warden sees
## you lying there: warden state "dn"); the night leaves you be. They get you up with E,
## or, nobody coming, you come to on the office step a while later, sore.
const COOP_COME_TO_HEALTH := 35
const COOP_DOWN_WAIT := 90.0
var _coop_down := false
var _coop_down_left := 0.0


func _coop_come_to() -> void:
	if _player == null or not is_instance_valid(_player) or _coop_down:
		return
	_coop_down = true
	_coop_down_left = COOP_DOWN_WAIT
	if _warden_play != null and _warden_play.is_active():
		_warden_play.leave()
	if _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(false)
	if _player.has_method("play_death_fall"):
		_player.play_death_fall()
	if _hud_manager != null:
		_hud_manager.push_status("You go down. The grass is cold against your face.", 2)


func _tick_coop_down(delta: float) -> void:
	if not _coop_down:
		return
	_coop_down_left -= delta
	if _coop_down_left <= 0.0 or not Coop.has_partner():
		_coop_get_up(false)


## Up again: helped (where you lie) or alone (on the office step, much later).
func _coop_get_up(helped: bool) -> void:
	if not _coop_down or _player == null or not is_instance_valid(_player):
		return
	_coop_down = false
	if not helped and grid_manager != null and world_generator != null and world_generator.has_method("find_player_spawn_coord"):
		_player.global_position = grid_manager.grid_to_world(world_generator.find_player_spawn_coord()) + Vector3(1.6, 1.0, 0.6)
	if _player.has_method("reset_damage_feedback_state"):
		_player.reset_damage_feedback_state(false)
	_set_player_health(COOP_COME_TO_HEALTH, false)
	if _hud_manager != null:
		if helped:
			_hud_manager.push_status("%s hauls you up by the jacket. \"Come on. Not here.\"" % Coop.sender_name(), 1)
		else:
			_hud_manager.push_status("You come to on the office step. You don't remember getting here.", 2)


## Another warden lying near you (knocked down): E gets them up (the nearest of them).
var _coop_down_near_id := 0


func _coop_partner_down_near() -> bool:
	_coop_down_near_id = 0
	if _player == null or not is_instance_valid(_player):
		return false
	var best := 2.2
	for id in Coop.others():
		if not bool(Coop.state_of(id).get("dn", false)):
			continue
		var fig := Coop.figure_of(id)
		if fig == null or not fig.visible:
			continue
		var d := Vector2(fig.global_position.x - _player.global_position.x, fig.global_position.z - _player.global_position.z).length()
		if d < best:
			best = d
			_coop_down_near_id = int(id)
	return _coop_down_near_id != 0


func _coop_lift_partner() -> void:
	# Every machine hears it; only the one lying there gets up (coop_lifted).
	Coop.send_play("lift", [_coop_down_near_id])
	if _hud_manager != null:
		_hud_manager.push_status("You get %s up. They are shaking." % Coop.name_of(_coop_down_near_id), 1)


## The other wardens' names as said: "Jana", "Jana and Pepa", "Jana, Pepa and Bara".
func _coop_names_said() -> String:
	var names: Array = []
	for id in Coop.others():
		names.append(Coop.name_of(id))
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + str(names[-1])


func _coop_biz_change(kind: String, a: Array) -> void:
	var act = CoreRoot.actions if CoreRoot != null else null
	if act == null or a.is_empty():
		return
	match kind:
		"take":
			act.biz_take(str(a[0]), a[1])
		"sale":
			act.biz_sale(str(a[0]), int(a[1]), int(a[2]), bool(a[3]), false)
		"lost":
			act.biz_lost(str(a[0]))
		"order":
			act.biz_add_order(str(a[0]), a[1], int(a[2]), int(a[3]))
		"hire":
			if a.size() > 2 and a[1] is Dictionary:
				act.biz_hire(str(a[0]), a[1], int(a[2]))
		"fire":
			act.biz_fire(str(a[0]), str(a[1]) if a.size() > 1 else "")
		"bin":
			act.biz_bin(str(a[0]))
		"waste":
			act.biz_waste(str(a[0]), a[1])
		"gear":
			act.biz_add_gear(str(a[0]), str(a[1]))
		"licence":
			act.biz_grant_licence(str(a[0]))
		"job":
			act.biz_set_job(str(a[0]), str(a[1]), str(a[2]), str(a[3]))
		"late":
			act.biz_set_late(str(a[0]), bool(a[1]))
		"menu":
			act.biz_set_menu(str(a[0]), str(a[1]), bool(a[2]))
		"score":
			act.biz_score(str(a[0]), a[1])
		# The staffroom's hands (actions.staff_*).
		"s_hire":
			if a[0] is Dictionary:
				act.staff_hire(a[0], int(a[1]) if a.size() > 1 else CoreRoot.get_day())
		"s_fire":
			act.staff_fire(str(a[0]))
		"s_job":
			if a.size() > 2:
				act.staff_set_job(str(a[0]), str(a[1]), bool(a[2]))
		"s_gear":
			act.staff_add_gear(str(a[0]))


## The other machine: the other warden got you up.
func coop_lifted(who: int = 0) -> void:
	if who != 0 and who != multiplayer.get_unique_id():
		return
	_coop_get_up(true)


## The night for two: enemies hunt either warden, the other machine sees them
## (scripts/coop/coop_night.gd).
const COOP_NIGHT_SCRIPT = preload("res://scripts/coop/coop_night.gd")
var _coop_night: Node


func _ensure_coop_night() -> void:
	if _coop_night != null and is_instance_valid(_coop_night):
		return
	_coop_night = COOP_NIGHT_SCRIPT.new()
	_coop_night.name = "CoopNight"
	_coop_night.main = self
	add_child(_coop_night)


## The host: what of the camp changes by itself, for the other machine once a second
## (Coop sends it when it changed): the guests and their plans (the agents act them out
## there too), breakdowns, the buildings' condition (the lamps), the rooms, the mail, the
## shed key, the day's events and the night's faults that put lamps out.
func coop_camp_pulse() -> Dictionary:
	var state = CoreRoot.get_state()
	if state == null:
		return {}
	var maint := {}
	for coord in state.grid.cells.keys():
		var cell = state.grid.cells[coord]
		if cell is Dictionary and (cell as Dictionary).has("maintenance"):
			maint[coord] = float(cell["maintenance"])
	var mail: Dictionary = {}
	if EmailManager != null:
		mail = {"inbox": EmailManager.inbox, "sent": EmailManager.sent, "rep": EmailManager.reputation}
	var key: bool = camp_office != null and is_instance_valid(camp_office) and camp_office.has_shed_key
	var day: Dictionary = _day_events.export_state() if _day_events != null else {}
	# The night's faults that put lamps out (the breaker, a dead circuit).
	var nj := {"bt": bool(_night_jobs.breaker_tripped), "dc": int(_night_jobs.dead_circuit), "jobs": _night_jobs.coop_jobs()} if _night_jobs != null else {}
	# The back office (CampStat, the bazaar): the reviews, the takings, the bills, the
	# lost and found.
	var books := {"rev": state.guest_reviews, "tx": state.guest_transactions, "sat": float(state.satisfaction), "karma": float(state.karma),
		"hrot": float(state.hrotfaktor), "elec": _billing.export_state(), "baz": _bazaar.export_state(), "gog": _goggle.export_state()}
	return {"guests": state.guests, "failures": state.failures, "maint": maint, "rooms": state.accommodation_states, "mail": mail, "shed_key": key, "day": day, "nj": nj, "biz": state.biz, "books": books}


var _coop_day_hash := 0

## The other machine's till: the host's, plus what was spent or taken here and not yet
## counted there (each change goes to the host numbered; its clock says how far it got).
var _coop_till_shown := -1
var _coop_till_seq := 0
var _coop_till_pending: Array = []      # [[seq, delta]]
## The host: the last of the other warden's till changes it has counted.
var _coop_till_acked: Dictionary = {}     # peer id -> the last change counted


func _coop_follow_till(host_money: int, acked: int) -> void:
	var state = CoreRoot.get_state()
	if _coop_till_shown >= 0:
		var here := int(state.money) - _coop_till_shown
		if here != 0:
			_coop_till_seq += 1
			_coop_till_pending.append([_coop_till_seq, here])
			Coop.send_request("till", [_coop_till_seq, here])
	_coop_till_pending = _coop_till_pending.filter(func(p): return int(p[0]) > acked)
	var shown := host_money
	for p in _coop_till_pending:
		shown += int(p[1])
	if int(state.money) != shown:
		CoreRoot.apply_changes({"money": shown})
	_coop_till_shown = shown


## The other warden's machine: the host's camp as it now is (coop_camp_pulse).
func coop_apply_pulse(p: Dictionary) -> void:
	if not Coop.is_client() or not _gameplay_started or _menu_mode:
		return
	var state = CoreRoot.get_state()
	if state == null:
		return
	var was := {}
	for g in state.guests:
		if g is Dictionary:
			was[int(g.get("id", -1))] = g
	state.guests = (p.get("guests", []) as Array).duplicate(true)
	_coop_tell_arrivals(was)
	state.failures = (p.get("failures", {}) as Dictionary).duplicate(true)
	var rooms: Dictionary = p.get("rooms", {})
	if not rooms.is_empty():
		state.accommodation_states = rooms.duplicate(true)
	var maint: Dictionary = p.get("maint", {})
	for coord in maint.keys():
		if state.grid.cells.has(coord) and state.grid.cells[coord] is Dictionary:
			state.grid.cells[coord]["maintenance"] = float(maint[coord])
	if GuestManager != null and GuestManager.has_method("_emit_guest_overview_state"):
		GuestManager._emit_guest_overview_state(true)
	# The businesses' books are the host's (what is on the shelves, the orders, the hands);
	# what is done to them here goes there.
	if CoreRoot.actions != null and not CoreRoot.actions.biz_remote.is_valid():
		CoreRoot.actions.biz_remote = func(kind: String, args: Array) -> void:
			if Coop.is_client():
				Coop.send_request("biz", [kind, args])
	if p.get("biz", null) is Dictionary and not (p["biz"] as Dictionary).is_empty():
		state.biz = (p["biz"] as Dictionary).duplicate(true)
	var nj: Dictionary = p.get("nj", {})
	if _night_jobs != null and not nj.is_empty():
		_night_jobs.breaker_tripped = bool(nj.get("bt", false))
		_night_jobs.dead_circuit = int(nj.get("dc", -1))
		# Tonight's jobs, the host's: listed, paged and pointed to here too.
		_night_jobs.coop_take(nj.get("jobs", []))
	_sync_dark_lamps()
	if camp_office != null and is_instance_valid(camp_office):
		camp_office.has_shed_key = bool(p.get("shed_key", camp_office.has_shed_key))
	# The day's events: only when they changed (bringing them in builds their props anew).
	var day: Dictionary = p.get("day", {})
	var day_hash := hash(var_to_bytes(day))
	if _day_events != null and day_hash != _coop_day_hash:
		_coop_day_hash = day_hash
		_day_events.import_state(day)
	var mail: Dictionary = p.get("mail", {})
	if not mail.is_empty() and EmailManager != null and EmailManager.has_method("coop_take"):
		EmailManager.coop_take(mail)
	# The back office is the host's: CampStat's reviews, takings and bills, the bazaar.
	var books: Dictionary = p.get("books", {})
	if not books.is_empty():
		state.guest_reviews = (books.get("rev", []) as Array).duplicate(true)
		state.guest_transactions = (books.get("tx", []) as Array).duplicate(true)
		state.satisfaction = float(books.get("sat", state.satisfaction))
		state.karma = float(books.get("karma", state.karma))
		state.hrotfaktor = float(books.get("hrot", state.hrotfaktor))
		if books.get("elec", null) is Dictionary:
			_billing.import_state(books["elec"], _day_index, false)
		if books.get("baz", null) is Dictionary:
			_bazaar.import_state(books["baz"])
		if books.get("gog", null) is Dictionary:
			_goggle.import_state(books["gog"])


## The other warden's machine: a party reached the barrier, was let in or gave up in the
## host's camp. GuestManager only signals it where it simulates, so here the barrier
## stayed down (the party walked through it), and no line, car or hello came: the same
## signals, from the change of status in the pulse. `was`: id -> the guest before it.
func _coop_tell_arrivals(was: Dictionary) -> void:
	if GuestManager == null or not GuestManager.has_method("_arrival_row"):
		return
	var now_abs: int = GuestManager._absolute_minutes(maxi(1, _day_index), int(_time_of_day_hours), int(fposmod(_time_of_day_hours, 1.0) * 60.0))
	var still := {}
	for g in CoreRoot.get_state().guests:
		if not (g is Dictionary):
			continue
		var id := int(g.get("id", -1))
		still[id] = true
		var before := str((was[id] as Dictionary).get("status", "")) if was.has(id) else "expected"
		var now := str(g.get("status", ""))
		if before == now:
			continue
		if now == "waiting" and before != "waiting":
			EventBus.guest_at_gate.emit(GuestManager._arrival_row(g, now_abs))
		elif before == "waiting" and now == "active":
			EventBus.guest_checked_in.emit((g as Dictionary).duplicate(true))
	# Waiting at reception for the full time and gone from the list: they gave up and drove
	# off (sooner, the host turned them away at the desk).
	for id in was.keys():
		var old: Dictionary = was[id]
		if str(old.get("status", "")) == "waiting" and not still.has(id) \
				and now_abs - int(old.get("gate_since_abs", now_abs)) >= GuestManager.GATE_GIVE_UP_MINUTES - 2:
			EventBus.guest_gave_up.emit(GuestManager._arrival_row(old, now_abs))


## What both machines keep alike, sent when it changes here (Coop.send_sync): the
## office's lights, curtains and set; the desk's register and key hooks. The joining
## machine first takes the host's (it sends only what it changes itself).
var _coop_sync_last: Dictionary = {}


func _coop_sync_things() -> Dictionary:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi == null:
		return {}
	var out := {}
	if bi.has_method("coop_office_state"):
		out["office"] = bi.coop_office_state()
	var desk = bi.get("_desk_room")
	if desk != null and desk.has_method("coop_register"):
		out["register"] = desk.coop_register()
	# The office PC: what is installed, downloaded, binned, on the wallpaper (both ways).
	if bi.has_method("coop_pc_state"):
		out["pc"] = bi.coop_pc_state()
	# The radio is the host's: its set plays on the other machine too.
	if Coop.is_host() and bi.has_method("coop_radio_state"):
		out["radio"] = bi.coop_radio_state()
	# Who has been served what in the businesses (the host serves too: the mug lands on
	# their table on the other machine, and they stop waiting there).
	if Coop.is_host():
		out["served"] = ORDERS_SERVED._served.duplicate()
	# Pristoupim's job (hamlet_trip.gd): one for everyone, merged forwards both ways.
	var trip = _interior_manager.get("_town_trip") if _interior_manager != null else null
	if trip != null and trip.has_method("coop_hamlet"):
		out["hamlet"] = trip.coop_hamlet()
	# The camp's music: the host's piece; the client's being out and about (for the host's
	# choosing when a piece comes in).
	if _music_director != null:
		out["music"] = _music_director.coop_state()
	return out


func coop_sync_poll() -> void:
	if not _gameplay_started or _menu_mode:
		return
	var things := _coop_sync_things()
	for kind in things.keys():
		var h := hash(var_to_bytes(things[kind]))
		if not _coop_sync_last.has(kind) and Coop.is_client():
			_coop_sync_last[kind] = h
			continue
		if int(_coop_sync_last.get(kind, 0)) != h:
			_coop_sync_last[kind] = h
			Coop.send_sync(kind, [things[kind]])


func coop_sync(kind: String, data: Array) -> void:
	if not _gameplay_started or _menu_mode:
		return
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	match kind:
		"office":
			if bi != null and bi.has_method("coop_take_office_state"):
				bi.coop_take_office_state(data[0])
		"pc":
			if bi != null and bi.has_method("coop_take_pc_state"):
				bi.coop_take_pc_state(data[0])
		"radio":
			if Coop.is_client() and bi != null and bi.has_method("coop_take_radio"):
				bi.coop_take_radio(data[0])
			return
		"music":
			if _music_director != null:
				_music_director.coop_take(data[0])
			return
		"served":
			if Coop.is_client():
				var got: Dictionary = data[0]
				for v in got:
					ORDERS_SERVED._served[v] = maxi(int(ORDERS_SERVED._served.get(v, 0)), int(got[v]))
			return
		"register":
			var desk = bi.get("_desk_room") if bi != null else null
			if desk != null and desk.has_method("coop_take_register"):
				desk.coop_take_register(data[0])
		"hamlet":
			var trip = _interior_manager.get("_town_trip") if _interior_manager != null else null
			if trip != null and trip.has_method("coop_take_hamlet") and data.size() > 0 and data[0] is Dictionary:
				trip.coop_take_hamlet(data[0])
				_coop_sync_last["hamlet"] = hash(var_to_bytes(trip.coop_hamlet()))
			return
		"camp_name":
			if not data.is_empty():
				set_camp_name(str(data[0]), true)
			return
		"gate":
			var gate = get_tree().get_first_node_in_group("camp_gate")
			if gate == null:
				return
			if not data.is_empty() and str(data[0]) == "down":
				gate.close_for_player()
			else:
				gate.open_for_player()
			return
	# Not sent back as it came; the register goes back if it merged with rows written here.
	var now := _coop_sync_things()
	if kind in ["office", "pc"] and now.has(kind):
		_coop_sync_last[kind] = hash(var_to_bytes(now[kind]))
	elif kind == "register":
		_coop_sync_last[kind] = hash(var_to_bytes(data[0]))


## Over the shoulder: your PC screen for the other machine while you sit at it and the
## other warden is in the office (InteriorManager has the picture), else nothing.
func coop_screen_frame() -> PackedByteArray:
	if _interior_manager == null or not _interior_manager.has_method("coop_room"):
		return PackedByteArray()
	var mine: Dictionary = _interior_manager.coop_room()
	if str(mine.get("w", "")) == "laptop":
		# At the staffroom's laptop (scripts/staff/laptop_view.gd): for whoever is in its
		# room with you.
		for id in Coop.others():
			var th: Dictionary = Coop.state_of(id).get("room", {})
			if str(th.get("k", "")) == str(mine.get("k", "")) and str(th.get("s", "")) == str(mine.get("s", "")) and str(th.get("w", "")) != "laptop":
				var bi_l = _interior_manager.get("_building_interior")
				return bi_l.coop_screen_frame_any() if bi_l != null else PackedByteArray()
		return PackedByteArray()
	if str(mine.get("t", "")) != "office" or str(mine.get("w", "")) != "pc":
		return PackedByteArray()
	# Someone in the office to look over your shoulder.
	var watched := false
	for id in Coop.others():
		var theirs: Dictionary = Coop.state_of(id).get("room", {})
		# Anywhere in the office building (from the back room's doorway too: one space).
		if str(theirs.get("t", "")) == "office" and str(theirs.get("w", "")) != "pc":
			watched = true
	if not watched:
		return PackedByteArray()
	var bi = _interior_manager.get("_building_interior")
	return bi.coop_screen_frame() if bi != null and bi.has_method("coop_screen_frame") else PackedByteArray()


## The other warden's screen, on your office's PC.
func coop_show_screen(frame: PackedByteArray) -> void:
	# In the staffroom: the frame is from its laptop.
	var si = _interior_manager.get("_service_interior") if _interior_manager != null else null
	if si != null and si.has_method("coop_show_laptop") and si.is_open():
		si.coop_show_laptop(frame)
		return
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi != null and bi.has_method("coop_show_screen") and bi.is_open():
		bi.coop_show_screen(frame)


## The door of the building with room key `key` ("x:y", or "office") opens and shuts.
func _coop_swing_door(key: String) -> void:
	var st: Node3D = null
	if key == "office":
		st = debug_structure_of_type("main_building")
	elif key.contains(":"):
		var parts := key.split(":")
		st = COOP_DOOR_ANIM.structure_at(Vector2i(int(parts[0]), int(parts[1])))
	if st == null:
		return
	var door := COOP_DOOR_ANIM.find_door(st)
	if door != null:
		COOP_DOOR_ANIM.open(door, 1.4)


## The host: a room's state as it is now, to the other machine.
func _coop_send_room(key: String) -> void:
	if not Coop.is_host() or not Coop.has_partner():
		return
	var state = CoreRoot.get_state()
	if state != null and state.accommodation_states.has(key):
		Coop.send_room_state(key, (state.accommodation_states[key] as Dictionary).duplicate(true))


## The host: the other warden finished a job in a room; it is done in the real camp (and
## the room goes back to them, _coop_send_room).
func coop_room_task(key: String, task_id: String) -> void:
	if not Coop.is_host() or GuestManager == null:
		return
	GuestManager.complete_room_task(key, task_id)
	if _interior_manager != null and _interior_manager.has_method("coop_refresh_room"):
		_interior_manager.coop_refresh_room(key)


## What the host has done since you joined, kept until your camp is built (it came
## with the snapshot only up to the moment it was sent).
var _coop_facts: Array = []


## The other warden's machine: the host's room as it is now.
func coop_room_state(key: String, acc: Dictionary) -> void:
	if not Coop.is_client():
		return
	if not _gameplay_started or _menu_mode:
		_coop_facts.append(["room", [key, acc]])
		return
	CoreRoot.get_state().accommodation_states[key] = acc.duplicate(true)
	if _interior_manager != null and _interior_manager.has_method("coop_refresh_room"):
		_interior_manager.coop_refresh_room(key)


## The other warden's machine: what the host did to the camp, done again here (the
## till is the host's: it is put back as it was).
func coop_apply_fact(kind: String, data: Array) -> void:
	if not Coop.is_client():
		return
	if not _gameplay_started or _menu_mode:
		_coop_facts.append([kind, data])
		return
	if kind == "room":
		coop_room_state(str(data[0]), data[1])
		return
	var state = CoreRoot.get_state()
	var keep := int(state.money)
	state.money = 1 << 30
	match kind:
		# Straight to the builder (the joining machine's own requests go to the host).
		# The host built it at its PC: the god cursor brings it down here too.
		"build":
			_god_from_peer(true)
			CoreRoot.builder_authority._on_request_build(str(data[0]), data[1], int(data[2]))
			_god_from_peer(false)
		"demolish":
			_god_from_peer(true)
			CoreRoot.builder_authority._on_request_demolish(data[0])
			_god_from_peer(false)
		"build_rejected":
			EventBus.BuildRejected.emit(str(data[0]), data[1], int(data[2]), str(data[3]))
		"demolish_rejected":
			EventBus.DemolishRejected.emit(data[0], str(data[1]))
		"upgrade":
			if _interior_manager != null:
				_interior_manager._handle_replace_upgrade(data[0], str(data[1]), str(data[2]), 0)
		"service":
			CoreRoot.actions.service_building(data[0], 0)
	state.money = keep
	EventBus.money_changed.emit(keep)


## The host: what the other warden's hands ask of the camp (Coop.send_request). Done
## here as if done here; a build or demolition turned down goes back to them.
func coop_request(kind: String, data: Array) -> void:
	if not Coop.is_host() or not _gameplay_started:
		return
	match kind:
		"served":
			var visit := str(data[0])
			ORDERS_SERVED._served[visit] = int(ORDERS_SERVED._served.get(visit, 0)) + 1
		"meal":
			# What the other warden served, for the guest's review (scripts/food/orders.gd).
			if GuestManager != null and GuestManager.has_method("note_meal") and data.size() >= 3:
				GuestManager.note_meal(int(data[0]), str(data[1]), int(data[2]))
		"build":
			var turned: Array = []
			var cb := func(t: String, at: Vector2i, rot: int, reason: String) -> void: turned.append([t, at, rot, reason])
			EventBus.BuildRejected.connect(cb)
			_god_from_peer(true)
			EventBus.RequestBuild.emit(str(data[0]), data[1], int(data[2]))
			_god_from_peer(false)
			EventBus.BuildRejected.disconnect(cb)
			if not turned.is_empty():
				Coop.send_fact("build_rejected", turned[0])
		"demolish":
			var turned2: Array = []
			var cb2 := func(rect: Rect2i, reason: String) -> void: turned2.append([rect, reason])
			EventBus.DemolishRejected.connect(cb2)
			_god_from_peer(true)
			EventBus.RequestDemolish.emit(data[0])
			_god_from_peer(false)
			EventBus.DemolishRejected.disconnect(cb2)
			if not turned2.is_empty():
				Coop.send_fact("demolish_rejected", turned2[0])
		"money":
			CoreRoot.actions.add_money(int(data[0]))
		"till":
			# Spent or taken on the other machine (the town, the pub, the pump...).
			var seq := int(data[0])
			if seq > int(_coop_till_acked.get(Coop.sender, 0)):
				_coop_till_acked[Coop.sender] = seq
				var delta := int(data[1])
				if delta >= 0:
					CoreRoot.actions.add_money(delta)
				else:
					CoreRoot.actions.spend_money(mini(-delta, CoreRoot.get_money()))
		"service":
			CoreRoot.actions.service_building(data[0], int(data[1]))
		"upgrade":
			if _interior_manager != null and data[0] is Dictionary:
				_interior_manager.coop_upgrade(data[0])
		"day_event":
			if _day_events != null:
				_day_events.coop_resolve(int(data[0]))
		"biz":
			# The other warden's hands on the businesses' books (actions.biz_remote there);
			# the money came with their till.
			_coop_biz_change(str(data[0]), data[1] if data.size() > 1 and data[1] is Array else [])
		"radio":
			# The other warden switched the office radio: the set is the host's.
			var bi_r = _interior_manager.get("_building_interior") if _interior_manager != null else null
			if bi_r != null and bi_r.has_method("coop_set_radio_power"):
				bi_r.coop_set_radio_power(bool(data[0]))
		"corn_take":
			# The other warden leads them out: they follow the stand-in.
			if _corn_hunt != null and is_instance_valid(_corn_hunt) and _coop_night != null and _coop_night.proxy(Coop.sender) != null:
				_corn_hunt.coop_take(_coop_night.proxy(Coop.sender))
		"repair":
			if economy_manager != null and economy_manager.has_method("add_repair_progress"):
				economy_manager.add_repair_progress(data[0], 1.0)
		"breaker":
			if _night_jobs != null:
				_night_jobs.on_breaker_fixed(int(data[0]))
		"checkin":
			GuestManager.request_check_in(int(data[0]))
		"refuse":
			GuestManager.refuse_at_desk(int(data[0]))
		"phone":
			if camp_office != null:
				camp_office.on_phone_effect(str(data[0]), str(data[1]))
		"shed_key":
			if camp_office != null:
				camp_office.take_shed_key()
		"mail":
			if EmailManager != null and EmailManager.has_method("coop_do"):
				EmailManager.coop_do(data)
		"pay_bill":
			request_pay_electricity_bill(str(data[0]))
		"crew":
			request_maintenance_crew()
		"crew_at":
			request_maintenance_crew_at(data[0])
		"bazaar_list":
			bazaar_list(int(data[0]))
		"goggle_remove":
			# Paid on their machine (the till brings it).
			_goggle.request_removal(int(data[0]), _day_index)
		"goggle_reply":
			goggle_reply(int(data[0]), str(data[1]))
		"builder98_mail":
			# Builder 98 on the other machine: its registration key or the district's
			# letter comes in the host's mail (the other machine gets it from there).
			if EmailManager != null and EmailManager.has_method("schedule_pool_mail"):
				EmailManager.schedule_pool_mail(preload("res://scripts/builder/shareware.gd").mail_for(str(data[0]), str(data[1]), _day_index))


## A build or demolition from another warden's PC: the god cursor stages it here too.
func _god_from_peer(on: bool) -> void:
	if _god_cursor != null and is_instance_valid(_god_cursor):
		_god_cursor.from_peer = on


## The other warden's machine builds nothing of its own accord: what its Builder asks
## goes to the host (and comes back as a fact). Off again outside co-op.
var _coop_build_forwarding := false


func _coop_forward_builds(on: bool) -> void:
	var auth = CoreRoot.builder_authority
	if auth == null or on == _coop_build_forwarding:
		return
	_coop_build_forwarding = on
	var b := Callable(auth, "_on_request_build")
	var d := Callable(auth, "_on_request_demolish")
	var fb := Callable(self, "_coop_send_build")
	var fd := Callable(self, "_coop_send_demolish")
	if on:
		if EventBus.RequestBuild.is_connected(b):
			EventBus.RequestBuild.disconnect(b)
		if EventBus.RequestDemolish.is_connected(d):
			EventBus.RequestDemolish.disconnect(d)
		EventBus.RequestBuild.connect(fb)
		EventBus.RequestDemolish.connect(fd)
	else:
		if EventBus.RequestBuild.is_connected(fb):
			EventBus.RequestBuild.disconnect(fb)
		if EventBus.RequestDemolish.is_connected(fd):
			EventBus.RequestDemolish.disconnect(fd)
		auth._connect_event_bus()


func _coop_send_build(t: String, at: Vector2i, rot: int) -> void:
	if not Coop.is_client():
		# Left the co-op camp without the end being heard: the builder is ours again.
		_coop_forward_builds(false)
		CoreRoot.builder_authority._on_request_build(t, at, rot)
		return
	Coop.send_request("build", [t, at, rot])


func _coop_send_demolish(rect: Rect2i) -> void:
	if not Coop.is_client():
		_coop_forward_builds(false)
		CoreRoot.builder_authority._on_request_demolish(rect)
		return
	Coop.send_request("demolish", [rect])


func _coop_flush_facts() -> void:
	var queued := _coop_facts.duplicate()
	_coop_facts.clear()
	for f in queued:
		coop_apply_fact(str(f[0]), f[1])


## The other warden's hands, so far: the boat, the rooms (tents, cabins, caravans), to be
## in them and to clean them (the jobs go to the host), and the office building, to be
## in it and to sleep (its PC, phone, board and check-ins stay the host's). The rest
## stays the host's until the next stages.
func _coop_client_interact() -> void:
	if _lake_trip != null and not _is_any_interior_open() and _lake_trip.try_interact():
		return
	if _in_attraction() and _warden_play.try_interact():
		return
	# The guest lost in the corn (the host's): take them by the arm.
	if _coop_corn_guest_near() != null:
		Coop.send_request("corn_take", [])
		if _hud_manager != null:
			_hud_manager.push_status("They grab your sleeve. \"Get me out of here.\"", 1)
		return
	# The day's events (the host's, shown here): sorted out through the host.
	if _day_events != null and not _is_any_interior_open() and _day_events.try_interact():
		return
	# A guest: a word with them (a noise complaint settles through the host too).
	if not _is_any_interior_open():
		var guest_in_view := _find_guest_in_view()
		if not guest_in_view.is_empty():
			if str(guest_in_view.get("status", "")) == "waiting":
				if _hud_manager != null:
					_hud_manager.push_status("%s: \"We are waiting for the desk. Is anyone in there?\"" % str(guest_in_view.get("name", "Guest")), 0, "arrivals")
			else:
				_talk_to_guest(guest_in_view)
			return
	# The attractions: in them on this machine, seen in them on the host's.
	if _warden_play != null and not _is_any_interior_open() and _warden_play.try_interact():
		return
	var st := _coop_client_room_target()
	if st != null:
		_handle_structure_interior_interact(st)


func _coop_client_hint() -> String:
	if _is_any_interior_open():
		return ""
	if _in_attraction():
		return str(_warden_play.hint())
	if _coop_corn_guest_near() != null:
		return "[E] Take them by the arm"
	var day_hint: String = _day_events.hint() if _day_events != null else ""
	if not day_hint.is_empty():
		return day_hint
	var guest_in_view := _find_guest_in_view()
	if not guest_in_view.is_empty():
		return ("[E] Check in %s" if str(guest_in_view.get("status", "")) == "waiting" else "[E] Talk to %s") % str(guest_in_view.get("name", "guest"))
	var h: String = _lake_trip.hint() if _lake_trip != null else ""
	if h.is_empty() and _warden_play != null:
		h = str(_warden_play.hint())
	if h.is_empty() and _coop_client_room_target() != null and _interaction_controller.has_method("build_hint_text"):
		h = str(_interaction_controller.build_hint_text(INTERACT_DISTANCE, false))
	return h


func _coop_corn_guest_near() -> Node3D:
	if _coop_night == null or _player == null or not is_instance_valid(_player):
		return null
	return _coop_night.tagged_near("corn_guest", _player.global_position, 1.8)


func _coop_client_room_target() -> Node3D:
	if _interaction_controller == null or not _interaction_controller.has_method("resolve_interaction"):
		return null
	var hit: Dictionary = _interaction_controller.resolve_interaction(INTERACT_DISTANCE, false)
	if str(hit.get("type", "")) != "structure":
		return null
	var st := hit.get("structure") as Node3D
	if st == null:
		return null
	var t := str(st.get_meta("building_type", ""))
	if t.begins_with("tent_") or t.begins_with("cabin") or t.begins_with("caravan_") or t == "main_building" or t == "corn_stand":
		return st
	# Out of the camp (the barrier, the bus, Lesna): each machine's own (town_trip.gd),
	# the barrier sent over.
	if t.begins_with("trip_") or t.begins_with("town_"):
		return st
	# The toilets, showers, pub, shed and the rest: in to look and to clean and mend (what
	# that does goes to the host).
	if _interior_manager != null and _interior_manager.has_method("_is_supported_service_building_type") and _interior_manager._is_supported_service_building_type(t):
		return st
	return null


## The camp for the other warden (Coop sends it when they join): the save snapshot,
## with them standing a step from where a new day starts, facing the office.
func coop_world_snapshot() -> Dictionary:
	var snap := _build_save_snapshot("Co-op", "coop")
	snap.erase("player")
	if grid_manager != null and world_generator != null and world_generator.has_method("find_player_spawn_coord"):
		var at: Vector3 = grid_manager.grid_to_world(world_generator.find_player_spawn_coord()) + Vector3(1.6, 1.0, 0.6)
		snap["player"] = {"position": {"x": at.x, "y": at.y, "z": at.z}}
	return snap


## Where the other warden's figure stands (the camp's 3D world), or null outside a game.
func coop_world_root() -> Node3D:
	return _world_3d if _gameplay_started and not _menu_mode else null


## What the other machine needs to draw you (Coop sends it ~15 times a second): where
## you stand and face, the torch and where it points, how fast you go, whether you are
## inside something (a room, the PC, the bus, the boat) and so out of sight.
func coop_local_warden() -> Dictionary:
	if not _gameplay_started or _menu_mode or _player == null or not is_instance_valid(_player):
		return {}
	var aim: Dictionary = _player.get_flashlight_aim() if _player.has_method("get_flashlight_aim") else {}
	var s := {
		"p": _player.global_position,
		"y": _player.rotation.y,
		"t": not aim.is_empty(),
		"d": aim.get("dir", -_player.global_basis.z),
		"v": Vector2(_player.velocity.x, _player.velocity.z).length(),
		"in": _is_any_interior_open() or (_lake_trip != null and _lake_trip.is_active()),
	}
	# On the lake: in the boat (it rows where you row), or across on the keeper's jetty.
	var lake: Dictionary = _lake_trip.coop_state() if _lake_trip != null and _lake_trip.has_method("coop_state") else {}
	if lake.has("boat") or lake.has("ride"):
		var key := "boat" if lake.has("boat") else "ride"
		s[key] = lake[key]
		# Your oars' strokes: their boat strokes as yours does (boat_rig.gd).
		if lake.has("rp"):
			s["rp"] = lake["rp"]
		s["p"] = (lake[key] as Transform3D).origin
		s["in"] = false
		s["t"] = false
	elif lake.has("shore"):
		s["p"] = lake["shore"]
		if bool(lake.get("fish", false)):
			s["act"] = "fish"
		if lake.has("boat_at"):
			s["boat_at"] = lake["boat_at"]
		s["in"] = false
		s["t"] = false
		s["v"] = 0.0
	# In a room: which, which part of it and the job your hands are on.
	var room: Dictionary = _interior_manager.coop_room() if _interior_manager != null and _interior_manager.has_method("coop_room") else {}
	if not room.is_empty():
		s["room"] = room
	# At night in a room: its windows (where in the camp, which way, the curtain, how
	# squarely you look at it), for the host's Photographer to come to (tourist_brain.gd).
	if bool(s["in"]) and _is_enemy_night_active() and _interior_manager != null and _interior_manager.has_method("photo_windows"):
		var pw: Array = []
		for w in _interior_manager.photo_windows():
			pw.append([(w["pos"] as Vector3).snapped(Vector3.ONE * 0.01), (w["out"] as Vector3).snapped(Vector3.ONE * 0.01),
				snappedf(float(w.get("open", 1.0)), 0.05), snappedf(float(w.get("facing", 0.0)), 0.05)])
		if not pw.is_empty():
			s["pw"] = pw
	# Your health, for the host's enemies to know a hit will be your last (their kills).
	s["hp"] = _player_health
	# On a bus (one bus for both: town_trip.gd, bus_ride.gd).
	var trip = _interior_manager.get("_town_trip") if _interior_manager != null else null
	var bus: Dictionary = trip.coop_state() if trip != null and trip.has_method("coop_state") else {}
	if not bus.is_empty():
		s["bus"] = bus
	# In a place in Lesna (the pub, the Jednota...): the other sees you there with them.
	var town_place: String = trip.coop_place() if trip != null and trip.has_method("coop_place") else ""
	if town_place != "":
		s["tr"] = town_place
	# Down the sewer's pipes: where, for the other warden down there too (pipe_mate.gd).
	if _sewer_pipe_minigame != null and _sewer_pipe_minigame.is_open() and _sewer_pipe_minigame.has_method("coop_pipe_state"):
		var pipe: Dictionary = _sewer_pipe_minigame.coop_pipe_state()
		if not pipe.is_empty():
			s["pipe"] = pipe
	# In an attraction: the other machine places you in it (scripts/attractions/warden_play.gd).
	var att: Dictionary = _warden_play.coop_state() if _warden_play != null and is_instance_valid(_warden_play) else {}
	if not att.is_empty():
		s["att"] = att
	# Behind the corn stand: stood behind its counter at the pot (the close-up hides you).
	var corn = _interior_manager.get("_corn_stand") if _interior_manager != null else null
	if corn != null and is_instance_valid(corn) and corn.visible:
		var stand = corn.get("_stand")
		if stand != null and is_instance_valid(stand):
			s["p"] = (stand as Node3D).global_transform * Vector3(0.0, 0.0, -0.85)
			s["in"] = false
			s["t"] = false
			s["v"] = 0.0
			s["act"] = "cook"
	# Crouched or on your belly, or something carried in your arms (player_controller
	# stance, scripts/ambient/carry.gd): the other machine draws that pose.
	if not s.has("act") and _player != null and not bool(s.get("in", false)):
		var stance := int(_player.get("stance")) if _player.get("stance") != null else 0
		var carry := get_tree().get_first_node_in_group("carry")
		var carried: String = carry.coop_pose() if carry != null else ""
		if carry != null and str(carry.coop_held()) != "":
			s["cr"] = str(carry.coop_held())
		if stance == 2:
			s["act"] = "prone"
		elif stance == 1:
			s["act"] = "crouch"
		elif carried != "":
			s["act"] = carried
	# At work out in the camp: holding R at something, a branch sawn, rubbish bagged.
	if not s.has("act"):
		var chore: String = _day_events.coop_work() if _day_events != null and _day_events.has_method("coop_work") else ""
		if chore != "":
			s["act"] = chore
		elif _maintenance != null and _maintenance.has_method("coop_working") and _maintenance.coop_working():
			s["act"] = "fix"
	# Knocked down, lying there.
	if _coop_down:
		s["dn"] = true
		s["t"] = false
	# In bed (the night passes only when both are: camp_office.gd).
	if camp_office != null and is_instance_valid(camp_office) and camp_office.in_bed():
		s["z"] = true
	return s


## The host's clock, weather, power and till for the other machine.
func coop_clock() -> Dictionary:
	var state = CoreRoot.get_state()
	var night_passing: bool = camp_office != null and is_instance_valid(camp_office) and camp_office.is_fast_forwarding()
	var c := {"d": _day_index, "h": _time_of_day_hours, "w": _weather_state, "pw": _is_grid_powered(), "m": int(state.money) if state != null else 0, "sl": night_passing, "mq": _coop_till_acked}
	var build: float = weather_system.storm_build() if weather_system != null else 0.0
	if build > 0.0:
		c["sb"] = snappedf(build, 0.01)
	if _coop_night != null:
		c["sn"] = _coop_night.sanity_by_peer()
	return c


## The other warden's machine sets its day, sky, weather, lamps and till by the host's.
func coop_apply_clock(c: Dictionary) -> void:
	if not Coop.is_client() or not _gameplay_started or _menu_mode:
		return
	var state = CoreRoot.get_state()
	if state != null:
		var day := maxi(1, int(c.get("d", _day_index)))
		if int(state.day) != day:
			state.day = day
		var acked = c.get("mq", {})
		_coop_follow_till(int(c.get("m", state.money)), int((acked as Dictionary).get(multiplayer.get_unique_id(), 0)) if acked is Dictionary else 0)
	if time_system != null:
		time_system.set_time_hours(float(c.get("h", _time_of_day_hours)))
	if _coop_night != null and c.get("sn") is Dictionary and (c["sn"] as Dictionary).has(multiplayer.get_unique_id()):
		_coop_night.take_own_sanity(float(c["sn"][multiplayer.get_unique_id()]))
	var w := int(c.get("w", _weather_state))
	if weather_system != null and w != _weather_state:
		weather_system.set_weather(w)
	_coop_storm_build = float(c.get("sb", 0.0))
	var pw := bool(c.get("pw", true))
	if pw != _coop_powered:
		_coop_powered = pw
		_note_grid_power(pw)
		_apply_time_from_clock(true, false)
	_sync_runtime_state_from_systems()


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
	if not _gameplay_started or not Coop.sim_here():
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
	if not _gameplay_started or not _test_night.is_empty():
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
	_after_save(snapshot)
	_active_save_path = path
	return path


func _write_autosave(slot_name: String) -> void:
	# The other warden's machine holds the host's camp, not its own: nothing to save.
	# A test night's camp is thrown away.
	if not Coop.sim_here() or not _test_night.is_empty():
		return
	var snapshot := _build_save_snapshot(slot_name, "autosave")
	if snapshot.is_empty():
		return
	var path := SaveManager.write_save(snapshot, slot_name, "autosave")
	if not path.is_empty():
		_active_save_path = path
		_after_save(snapshot)


## The camp's card and picture for its tile on LOAD CAMP (scripts/profiles.gd).
func _after_save(snapshot: Dictionary) -> void:
	PROFILES.after_save(snapshot)
	var vp := _sub_viewport_container.get_child(0) as SubViewport if _sub_viewport_container != null and _sub_viewport_container.get_child_count() > 0 else null
	if vp != null and not _is_any_interior_open():
		PROFILES.save_thumbnail(vp.get_texture().get_image())


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
			"created_unix": int(Time.get_unix_time_from_system()),
			"camp_name": camp_name(),
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
			"biz": (state.biz as Dictionary).duplicate(true),
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
			"buildings": buildings,
			"seed": world_generator.world_seed if world_generator != null else 0,
			"nature": world_generator.nature_snapshot() if world_generator != null and world_generator.has_method("nature_snapshot") else []
		},
		"mode": "sandbox" if _sandbox else "campaign",
		"rules": _camp_rules.duplicate(),
		"coop": Coop.is_host(),
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
		"goggle": _goggle.export_state(),
		"graph": _day_graph.export_state(),
		"ruined_cabin": _ruined_cabin_key,
		"camp_office": camp_office.export_state() if camp_office != null else {},
		"town_trip": _interior_manager.town_trip().export_state() if _interior_manager != null and _interior_manager.has_method("town_trip") and _interior_manager.town_trip() != null else {},
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
	if not preview_only:
		_test_night = ""
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
	# The camp's own seed: the same lake, fences, corn and horizon as when it was saved
	# (and as on the host's machine in co-op). Old saves have none: a new one is drawn.
	world_generator.world_seed = int(grid_data.get("seed", 0))
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

	# The trees and the corn where they stood (what was cleared stays cleared); saves
	# from before they were kept grow a new wood.
	var nature_any = grid_data.get("nature", null)
	if nature_any is Array and world_generator.has_method("restore_nature"):
		world_generator.restore_nature(nature_any as Array)
	elif world_generator.has_method("populate_trees"):
		world_generator.populate_trees()
	_sandbox = str(snapshot.get("mode", "")) == "sandbox"
	var rules_any = snapshot.get("rules", {})
	_camp_rules = CAMP_RULES.merged(rules_any if rules_any is Dictionary and _sandbox else {}, true)

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

	# The host's camp's name for the board by the gate (co-op).
	var meta_any = snapshot.get("meta", {})
	if not preview_only and meta_any is Dictionary and Coop.is_client():
		_coop_camp_name = str((meta_any as Dictionary).get("camp_name", ""))
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
			"next_guest_id": max(1, int(state_data.get("next_guest_id", 1))),
			"biz": (state_data.get("biz", {}) as Dictionary).duplicate(true) if state_data.get("biz", {}) is Dictionary else {}
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
		var trip_any = snapshot.get("town_trip", {})
		if trip_any is Dictionary and _interior_manager != null and _interior_manager.has_method("town_trip") and _interior_manager.town_trip() != null:
			_interior_manager.town_trip().import_state(trip_any)
		elif trip_any is Dictionary:
			_pending_town_trip = (trip_any as Dictionary).duplicate(true)
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
		_ruined_cabin_key = str(snapshot.get("ruined_cabin", ""))
		call_deferred("_dress_ruined_cabin")
		var gog_any = snapshot.get("goggle", {})
		_pending_goggle = (gog_any as Dictionary).duplicate(true) if gog_any is Dictionary else {}
		var graph_any = snapshot.get("graph", {})
		_pending_graph = (graph_any as Dictionary).duplicate(true) if graph_any is Dictionary else {}
		_goggle_fresh = true
		if _gameplay_started:
			_setup_goggle()
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
			_import_quests(_pending_quest_state)
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
	if not preview_only:
		_refresh_camp_sign()
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
				state.grid.occupy_cell(coord, building_id, instance_id, origin, footprint)
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
	_sandbox = false
	_camp_rules = CAMP_RULES.duplicate()
	_pending_loaded_player_state.clear()
	_pending_night_jobs.clear()
	if _night_jobs != null:
		_night_jobs.reset()
	_pending_camp_office.clear()
	_pending_town_trip.clear()
	if camp_office != null:
		camp_office.reset()
	_pending_day_events.clear()
	if _day_events != null:
		_day_events.reset()
	# The bag: the torch again, nothing on the ground (scripts/ui/inventory.gd).
	var trip = _interior_manager.town_trip() if _interior_manager != null and _interior_manager.has_method("town_trip") else null
	if trip != null and trip.get("inventory") != null:
		trip.inventory.new_camp()
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
	_pending_goggle.clear()
	_pending_graph.clear()
	_goggle_fresh = true
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
	# The businesses' books too (the menu's preview of the last save left them in: its
	# places, stock, orders and licences); actions._biz starts them anew with a new stamp.
	state.biz = {}
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
		if _gameplay_started and Coop.sim_here():
			_write_autosave("Autosave")
		Coop.leave()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Alt-tab during the night should not cost the player their life (in co-op the
		# night goes on regardless: no pause).
		if pause_on_focus_loss and _can_pause_now() and not Coop.is_active():
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
	# In co-op the camp goes on for the other warden: the menu is only over your view.
	get_tree().paused = not Coop.is_active()


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
	_leave_everything(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## `silent`: back to the main menu, nothing to walk out of and no door to hear.
func _leave_everything(silent: bool) -> void:
	if _sewer_pipe_minigame != null and _sewer_pipe_minigame.has_method("abort") and _sewer_pipe_minigame.is_open():
		_sewer_pipe_minigame.abort()
	if _utility_repair_minigame != null and _utility_repair_minigame.has_method("abort") and _utility_repair_minigame.is_open():
		_utility_repair_minigame.abort()
	if _breaker_panel != null and is_instance_valid(_breaker_panel) and _breaker_panel.visible:
		_breaker_panel.close()
	if _lake_trip != null and is_instance_valid(_lake_trip) and _lake_trip.has_method("return_home") and _lake_trip.is_active():
		_lake_trip.return_home()
	if _interior_manager != null and _interior_manager.has_method("close_everything"):
		_interior_manager.close_everything(silent)
	if _god_cursor != null and is_instance_valid(_god_cursor):
		_god_cursor.finish_all()


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
	# Co-op: who you are with, or (the host alone) where the other can call in.
	if Coop.has_partner():
		line += "   WITH %s" % _coop_names_said().to_upper()
	elif Coop.is_host():
		var here: Array[String] = Coop.local_addresses()
		if not here.is_empty():
			line += "   OPEN AT %s" % here[0]
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
