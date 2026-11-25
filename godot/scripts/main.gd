extends Node

## The game: it makes the systems (the camp's state, the world, the rooms, the HUD, the
## night, the PC) and runs its flow: the title, a new camp, a load, pause, game over. The
## work of each part is in its own script; main keeps the parts and one-line facades
## others call it by (AGENTS.md "Project layout": what lives where).

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
const LANG = preload("res://scripts/lang.gd")
const INTERACTION_CONTROLLER_SCRIPT = preload("res://scripts/interaction_controller.gd")
const SILENT_MAN_BRAIN_SCRIPT = preload("res://scripts/enemies/silent_man_brain.gd")
const TOURIST_BRAIN_SCRIPT = preload("res://scripts/enemies/tourist_brain.gd")
const GIRL_BRAIN_SCRIPT = preload("res://scripts/enemies/girl_brain.gd")
const STALKER_BRAIN_SCRIPT = preload("res://scripts/enemies/stalker_brain.gd")
## Which enemy a guest archetype brings: one guest of that kind turns into it for the
## night; if it gets you, that guest is gone by morning. The Antlered Man (stalker) is the
## boss of a camp packed too full (scripts/night/night_roll.gd: pick_turned_guest,
## claim_turned_guests, ANTLERED_GUESTS).
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
const PAUSE_KEYS_SCRIPT = preload("res://scripts/ui/pause_keys.gd")
var _hurt_fx: CanvasLayer
const TITLE_STAGE = preload("res://scripts/ui/title/title_stage.gd")
const TITLE_CAMP = preload("res://scripts/ui/title/title_camp.gd")
const LAND_WARMUP = preload("res://scripts/town/land_warmup.gd")
const INSTANCE = preload("res://scripts/instance/instance.gd")
const SCREEN_INPUT = preload("res://scripts/instance/screen_input.gd")
const LOCAL_CLIENT = preload("res://scripts/instance/local_client.gd")
const MIXER = preload("res://scripts/audio/mixer.gd")
const PAGE = preload("res://scripts/web/page.gd")
const UNDO_HUB = preload("res://scripts/web/undo_hub.gd")
const PAD_INPUT = preload("res://scripts/input/pad.gd")
const START_DISSOLVE = preload("res://scripts/ui/door_transition.gd")
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
## The evening before a bad night (W19/W27, 4. 11.): its silences and wrong far sounds.
const EVENING_SCRIPT = preload("res://scripts/night/evening_unease.gd")
var _evening: Node
const CORN_HUNT_SCRIPT = preload("res://scripts/corn_hunt.gd")
const WEEK_REPORT_SCREEN_SCRIPT = preload("res://scripts/ui/week_report_screen.gd")
const BREAKER_PANEL_SCRIPT = preload("res://scripts/breaker_panel.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const LIMINAL_WINDOW = preload("res://scripts/debug/liminal_window.gd")
const MAIN_MENU_SCRIPT = preload("res://scripts/ui/main_menu.gd")
const PAUSE_MENU_SCRIPT = preload("res://scripts/ui/pause_menu.gd")
const GAME_OVER_SCREEN_SCRIPT = preload("res://scripts/ui/game_over_screen.gd")
const BOOT_SCREEN_SCRIPT = preload("res://scripts/ui/boot_screen.gd")
## Wardens and their camps (worlds): which camp's saves are played.
const PROFILES = preload("res://scripts/profiles.gd")
## The seed NEW CAMP asked for (0: a new one), used by the next generation.
var _pending_world_seed := 0
const MENU_THEME_PATH := "res://assets/music/title.mp3"
## On the web the menu's theme plays in the browser, off the engine's one thread (scripts/audio/long_player.gd).
const LONG_PLAYER = preload("res://scripts/audio/long_player.gd")
const MENU_THEME_VOLUME_DB := -2.5
const SAVE_VERSION := 3
const AUTOSAVE_INTERVAL_SEC := 60.0
const WINDOW_TITLE := "Cursed Camp Manager Simulator"

## The instance's screen (scripts/instance/instance.gd screen_of): everything this warden
## sees is drawn into it, the world's view and the UI; one player: the whole window.
@onready var _screen: SubViewport = $Seat1/Screen
@onready var _sub_viewport_container: SubViewportContainer = $Seat1/Screen/SubViewportContainer
@onready var _world_3d: Node3D = $Seat1/Screen/SubViewportContainer/SubViewport/World3D
@onready var world_environment: WorldEnvironment = $Seat1/Screen/SubViewportContainer/SubViewport/World3D/WorldEnvironment
@onready var sun: DirectionalLight3D = $Seat1/Screen/SubViewportContainer/SubViewport/World3D/Sun
@onready var fallback_camera: Camera3D = $Seat1/Screen/SubViewportContainer/SubViewport/World3D/FallbackCamera

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
## The title screen's stage: the office at dusk (scripts/ui/title/title_stage.gd).
var _title_stage: Node
var _pending_loaded_player_state: Dictionary = {}
var _loaded_away := false
var _pending_loaded_crt_state: Dictionary = {}
var _last_known_crt_desktop_state: Dictionary = {}
var _boot_screen: CanvasLayer
var _player_health: int = PLAYER_MAX_HEALTH
const GATE_BULB_ON_HOUR := 18.75
const GATE_BULB_OFF_HOUR := 6.25
var _gate_bulb_on := false
var _blood_fx: Node
var _game_over_active: bool = false
## The game clock's pace against its usual (1): town_trip.gd slows it while a warden
## rides the bus through the real land.
var clock_scale := 1.0
## The demo's end (scripts/demo/demo_end.gd): it stops the clock on the morning after.
const DEMO_END = preload("res://scripts/demo/demo_end.gd")
var _demo_end: RefCounted = DEMO_END.new(self)


## How fast the clock runs now: the bus ride's pace, nothing once the demo is over.
func clock_pace() -> float:
	return 0.0 if _demo_end.holds_clock() else clock_scale
var _game_over_reason: String = GAME_OVER_REASON_DEATH
var _game_over_screen: CanvasLayer
## The night forecast's debug window (scripts/debug/liminal_window.gd), made when asked for.
var _liminal_window: CanvasLayer
var _active_enemy_brain: RefCounted
var _active_enemy_brain_id: String = ""
var _enemy_brains: Array = []
var _senses = THREAT_SENSES_SCRIPT.new()
## The night's director (scripts/night/night_director.gd) and its hands (director_effects.gd).
var _director = preload("res://scripts/night/night_director.gd").new()
var _director_fx: Node
## The camp's own music, not the radio's (scripts/audio/music_director.gd).
var _music_director: Node
var _caretaker: Node
## The camp's PA poles playing the reception's radio (scripts/audio/pa_horns.gd, 24. 11.).
var _pa_horns: Node
## The workers' hours on the sites going up (scripts/camp/construction_works.gd, 25. 11.).
var _construction: Node
## The van's boxes on the pallet by the barrier (scripts/business/delivery_pallet.gd, 25. 11.).
var _pallet: Node3D
## The stakes at the edge of a sandbox camp's land (scripts/camp/plot_stakes.gd, 25. 11.).
var _plot_stakes: Node3D
## A camp's goals and score kept up (scripts/camp/goal_watch.gd, 25. 11.).
var _goal_watch: Node
var _pending_director: Dictionary = {}
## The lost and found and its classifieds (scripts/bazaar.gd).
var _bazaar = preload("res://scripts/bazaar.gd").new()
var _pending_bazaar: Dictionary = {}
## The camp on Atlas (scripts/reviews/goggle.gd): the reviews in public, the rating, the
## blueprints it opens in Builder 98.
var _goggle = preload("res://scripts/reviews/goggle.gd").new()
var _pending_goggle: Dictionary = {}
var _goggle_fresh := true
## Builder 98's Graphs: what each day ended with (scripts/builder/day_graph.gd).
var _day_graph = preload("res://scripts/builder/day_graph.gd").new()
var _pending_graph: Dictionary = {}
var _night_jobs: Node
## The warden's palmtop (scripts/pda/pda.gd, 24. 11.: instead of the TAB site plan and the
## belt pager).
var _pda: Node
const PDA_SCRIPT = preload("res://scripts/pda/pda.gd")
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
var _lamp_flashlight_active: bool = false
var _lamp_grid_power_available: bool = true
var _billing: RefCounted = ELECTRICITY_BILLING_SCRIPT.new()


## Main is the main of its instance (scripts/instance/instance.gd): what is under it finds
## it by INSTANCE.main_of(self), and the instance's co-op side, camp state, events, guests
## and mail by INSTANCE.coop/core/bus/guests/mail(self).

func _enter_tree() -> void:
	add_to_group(INSTANCE.MAIN_GROUP)


## A split screen's second warden (scripts/instance/local_client.gd): this main is a co-op
## client in the host's program. The window, its scale and the warden's profile are the
## host's; once up it calls the host on 127.0.0.1 instead of showing the title.
var local_client := false
## The second warden while it plays here (scripts/instance/local_client.gd).
var _local_client: Node


## A second pad's Menu out in the camp (scripts/input/pad.gd join_handler): the second warden
## joins this camp as a co-op client in this program; true when it did.
func _on_second_pad(device: int) -> bool:
	if local_client or (_local_client != null and is_instance_valid(_local_client)):
		return false
	if not _gameplay_started or _menu_mode or _game_over_active or INSTANCE.coop(self).is_client():
		return false
	_local_client = LOCAL_CLIENT.start(self, device)
	return _local_client != null


func _ready() -> void:
	if not local_client:
		# config/name stays "icloud ccs2": it names the user:// folder that holds saves.
		DisplayServer.window_set_title(WINDOW_TITLE)
		_apply_integer_canvas_scale()
		get_tree().root.size_changed.connect(_apply_integer_canvas_scale)
	# Main's input heard inside its screen, first there (scripts/instance/screen_input.gd).
	var heard := SCREEN_INPUT.new()
	heard.name = "MainInput"
	heard.main = self
	_screen.add_child(heard)
	_screen.move_child(heard, 0)
	# A second pad's Menu out in the camp: the second warden (a split screen).
	var pad := PAD_INPUT.node()
	if pad != null and not local_client:
		pad.join_handler = _on_second_pad
	_screen.add_child(HandCursor.new())
	# On the web (UNDO.games) a lost focus is a click on the hub's bar: the game pauses when the
	# page is hidden instead (scripts/web/undo_hub.gd).
	var hub := UNDO_HUB.node()
	if hub != null and not local_client:
		pause_on_focus_loss = false
		hub.page_hidden.connect(_on_page_hidden)
	_show_startup_loading_screen()
	await get_tree().process_frame
	# The warden and the camp played last (scripts/profiles.gd): their saves are the
	# menu's camp and CONTINUE.
	if not local_client:
		PROFILES.boot()
	await _bootstrap_runtime()
	_hide_startup_loading_screen()
	_startup_bootstrap_complete = true
	_enter_main_menu()
	if local_client:
		_coop_camp.on_menu_join("127.0.0.1")
	else:
		# The web page's card goes once the title has drawn (scripts/web/page.gd).
		for i in 3:
			await get_tree().process_frame
		PAGE.ready()


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
	_screen.add_child(_boot_screen)


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
	if not local_client:
		PAGE.step(text, progress)
	await get_tree().process_frame
	await get_tree().process_frame


func _bootstrap_runtime() -> void:
	await _boot_step("Waking the camp", 0.05)
	# The land's and the buses' pictures and sounds read on the loader's threads while the
	# boot and the title are up (scripts/town/land_warmup.gd): a new camp's first frames.
	_screen.add_child(LAND_WARMUP.new())
	time_system = TIME_SYSTEM_SCRIPT.new(INSTANCE.core(self).get_state())
	time_system.owner_node = self
	weather_system = WEATHER_SYSTEM_SCRIPT.new()
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)
	visual_module = VISUAL_MODULE_SCRIPT.new()
	_screen.add_child(visual_module)

	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	_ensure_input_actions()
	# The one debug menu, on L (scripts/ui/debug_menu.gd): debug builds only.
	if OS.is_debug_build():
		var dm = preload("res://scripts/ui/debug_menu.gd").new()
		dm.name = "DebugMenu"
		dm.main = self
		_screen.add_child(dm)
	await _boot_step("Tuning the radio", 0.15)
	_setup_audio()

	if time_system:
		var day_tick_cb := Callable(self, "_on_day_tick")
		if not INSTANCE.bus(self).day_tick.is_connected(day_tick_cb):
			INSTANCE.bus(self).day_tick.connect(day_tick_cb)
	if INSTANCE.bus(self).has_signal("night_tick"):
		var night_tick_cb := Callable(_night_roll, "on_night_tick")
		if not INSTANCE.bus(self).night_tick.is_connected(night_tick_cb):
			INSTANCE.bus(self).night_tick.connect(night_tick_cb)
	if INSTANCE.bus(self).has_signal("state_changed"):
		var state_changed_cb := Callable(self, "_on_eventbus_state_changed")
		if not INSTANCE.bus(self).state_changed.is_connected(state_changed_cb):
			INSTANCE.bus(self).state_changed.connect(state_changed_cb)

	await _boot_step("Opening the office", 0.3)
	_bind_or_create_managers()
	_bind_billing()
	_title_stage = TITLE_STAGE.new()
	_title_stage.name = "TitleStage"
	_screen.add_child(_title_stage)
	_title_stage.setup(self)
	_setup_weather_visuals_module()
	RETRO_RENDER.register(_sub_viewport_container)
	get_viewport().size_changed.connect(func() -> void: RETRO_RENDER.refresh_all(get_tree()))
	await _boot_step("Growing the woods", 0.45)
	await _generate_grid_world_stepped()
	await _boot_step("Raking the paths", 0.85)
	_structures.rebuild_cells()
	_setup_guest_agents()
	_setup_god_cursor()
	fallback_camera.current = true
	# The office now, behind the boot's bar: the title screen is the office at dusk.
	await _boot_step("Furnishing the rooms", 0.87)
	_ensure_interior_manager()
	if _interior_manager.has_method("office_jobs"):
		for job: Callable in _interior_manager.office_jobs():
			job.call()
			await get_tree().process_frame
	await _boot_step("Lighting the lamps", 0.9)

	if _weather_visuals != null:
		_weather_visuals.update_state(_time_state, _time_of_day_hours, _weather_state)
		_weather_visuals.setup_celestial_bodies()
		_weather_visuals.setup_weather_particles()
		_weather_visuals.setup_static_lighting()
	if visual_module != null and visual_module.has_method("setup_enemy_fx"):
		visual_module.setup_enemy_fx(ENEMY_DISTORTION_SHADER)

	_day_index = INSTANCE.core(self).get_day()
	_sync_runtime_state_from_systems(true)
	_ensure_pause_menu()


func _start_gameplay_runtime() -> void:
	if _gameplay_started:
		return
	_stop_active_enemy_brain()
	_menu_mode = false
	_gameplay_started = true
	_hub_playing(true)
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
	_hud_manager.quiet_pager(3.0)
	_bind_or_create_managers()

	if legacy_ui_adapter == null:
		legacy_ui_adapter = LEGACY_UI_ADAPTER_SCRIPT.new()
		legacy_ui_adapter.name = "LegacyUIAdapter"
		_screen.add_child(legacy_ui_adapter)

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
	if _sandbox or INSTANCE.coop(self).is_client():
		_quest_manager.stop()
		return
	_quest_manager.import_state(data)


func _setup_quest_manager() -> void:
	if _quest_manager == null or not is_instance_valid(_quest_manager):
		_quest_manager = QUEST_MANAGER_SCRIPT.new()
		_screen.add_child(_quest_manager)
	_quest_manager.setup(self)
	if _pending_quest_state_loaded:
		_import_quests(_pending_quest_state)
		_pending_quest_state.clear()
		_pending_quest_state_loaded = false


## Night work: the director and the distribution board (scripts/night_jobs.gd).
func _setup_pda() -> void:
	if _pda == null or not is_instance_valid(_pda):
		_pda = PDA_SCRIPT.new()
		_pda.name = "Pda"
		_screen.add_child(_pda)
		_pda.setup(self)


func _setup_night_jobs() -> void:
	_setup_pda()
	if _night_jobs == null or not is_instance_valid(_night_jobs):
		_night_jobs = NIGHT_JOBS_SCRIPT.new()
		_night_jobs.name = "NightJobs"
		_screen.add_child(_night_jobs)
		_night_jobs.setup(self)
		_night_jobs.changed.connect(_on_night_jobs_changed)
		INSTANCE.bus(self).building_failed.connect(func(_c, _t): _sync_dark_lamps())
		INSTANCE.bus(self).building_serviced.connect(func(_c, _t, _b, _cost): _sync_dark_lamps())
	if _breaker_panel == null or not is_instance_valid(_breaker_panel):
		_breaker_panel = BREAKER_PANEL_SCRIPT.new()
		_breaker_panel.name = "BreakerPanel"
		_screen.add_child(_breaker_panel)
		_breaker_panel.fixed.connect(func(fault: int):
			# The boy's board done: he is back in the tent by morning.
			if _night_jobs.boy_tier_at("breaker") > 0:
				for b in _enemy_brains:
					if b != null and b.has_method("boy_found"):
						b.boy_found()
			_night_jobs.on_breaker_fixed(fault)
			if INSTANCE.coop(self).is_client():
				INSTANCE.coop(self).send_request("breaker", [fault])
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
			INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		)
	if _interior_manager != null:
		_interior_manager.structure_interact_override = Callable(self, "_on_structure_interact_override")
	if not _pending_night_jobs.is_empty():
		_night_jobs.import_state(_pending_night_jobs)
		_pending_night_jobs.clear()
	if _day_events == null or not is_instance_valid(_day_events):
		_day_events = DAY_EVENTS_SCRIPT.new()
		_day_events.name = "DayEvents"
		_screen.add_child(_day_events)
		_day_events.setup(self)
	if not _pending_day_events.is_empty():
		_day_events.import_state(_pending_day_events)
		_pending_day_events.clear()
	if _week_ledger == null or not is_instance_valid(_week_ledger):
		_week_ledger = WEEK_LEDGER_SCRIPT.new()
		_week_ledger.name = "WeekLedger"
		_screen.add_child(_week_ledger)
		_week_ledger.reset(int(INSTANCE.core(self).get_state().money) if INSTANCE.core(self).get_state() != null else 0)
	if not _pending_week_ledger.is_empty():
		_week_ledger.import_state(_pending_week_ledger)
		_pending_week_ledger.clear()
	if _omens == null or not is_instance_valid(_omens):
		_omens = OMENS_SCRIPT.new()
		_omens.name = "Omens"
		_screen.add_child(_omens)
		_omens.setup(self)
	if _evening == null or not is_instance_valid(_evening):
		_evening = EVENING_SCRIPT.new()
		_evening.name = "EveningUnease"
		_screen.add_child(_evening)
		_evening.setup(self)
	if not _pending_omens.is_empty():
		_omens.import_state(_pending_omens)
		_pending_omens.clear()
	if _director_fx == null or not is_instance_valid(_director_fx):
		_director_fx = preload("res://scripts/night/director_effects.gd").new()
		_director_fx.name = "DirectorEffects"
		_screen.add_child(_director_fx)
		_director_fx.setup(self, _director)
	if not _pending_director.is_empty():
		_director.import_state(_pending_director)
		_pending_director.clear()
	if not _pending_bazaar.is_empty():
		_bazaar.import_state(_pending_bazaar)
		_pending_bazaar.clear()
	_online.setup_goggle()
	if not INSTANCE.bus(self).guest_state_changed.is_connected(_online.on_guest_state):
		INSTANCE.bus(self).guest_state_changed.connect(_online.on_guest_state)
	if _lake_trip == null or not is_instance_valid(_lake_trip):
		_lake_trip = LAKE_TRIP_SCRIPT.new()
		_lake_trip.name = "LakeTrip"
		_screen.add_child(_lake_trip)
		_lake_trip.setup(self)
	if _warden_play == null or not is_instance_valid(_warden_play):
		_warden_play = WARDEN_PLAY_SCRIPT.new()
		_warden_play.name = "WardenPlay"
		_screen.add_child(_warden_play)
		_warden_play.setup(self)
	if camp_office == null or not is_instance_valid(camp_office):
		camp_office = CAMP_OFFICE_SCRIPT.new()
		camp_office.name = "CampOffice"
		_screen.add_child(camp_office)
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
		_hud_manager.push_pager("Pager: Vera came in on the first bus. The district at eight. Books on the desk.", 2)
	if _week_ledger.is_due(_day_index, _time_of_day_hours):
		_show_week_report()


## What the night director sees, and what the omens and the caretaker read of the camp
## (scripts/night/director_feed.gd).
const DIRECTOR_FEED = preload("res://scripts/night/director_feed.gd")
var _night_feed: RefCounted = DIRECTOR_FEED.new(self)


func _tick_director() -> void:
	_night_feed.tick()


func _director_context() -> Dictionary:
	return _night_feed.context()


func caretaker_context() -> Dictionary:
	return _night_feed.caretaker_context()


func _omen_context() -> Dictionary:
	return _night_feed.omen_context()


## The evening before the night (scripts/night/evening_unease.gd), read off the warden:
## how hard tonight presses, whether they are at something, running, in a room, the office.
func _tick_evening() -> void:
	if _evening == null or not is_instance_valid(_evening) or _game_over_active or _player == null or not is_instance_valid(_player) or not camp_rule("threats"):
		return
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var si = _interior_manager.get("_service_interior") if _interior_manager != null else null
	var busy := false
	if bi != null:
		busy = bool(bi.get("_crt_active"))
		var dr = bi.get("_desk_room")
		if dr != null and dr.has_method("is_open") and bool(dr.is_open()):
			busy = true
	if si != null and si.has_method("_station_open") and str(si.call("_station_open")) != "":
		busy = true
	var v: Vector3 = (_player as CharacterBody3D).velocity if _player is CharacterBody3D else Vector3.ZERO
	var ctx := {
		"pressure": OMENS_SCRIPT.pressure(_omen_context()),
		"quiet": _day_index <= QUIET_NIGHTS,
		"busy": busy or get_tree().paused,
		"running": Vector2(v.x, v.z).length() > 4.2,
		"indoors": _is_any_interior_open(),
		"in_office": bi != null and bool(bi.get("visible")),
		"player_pos": _player.global_position,
	}
	var abs_minute := (maxi(1, _day_index) - 1) * 1440 + int(round(_time_of_day_hours * 60.0))
	_evening.tick(get_process_delta_time(), abs_minute, ctx)


## Those who came to the desk unbooked at night and were written in (checkin_desk.gd).
func _desk_strangers_admitted() -> int:
	var bi = _interior_manager._building_interior if _interior_manager != null and _interior_manager.get("_building_interior") != null else null
	return int(bi.desk_strangers_admitted()) if bi != null and bi.has_method("desk_strangers_admitted") else 0


func _show_week_report() -> void:
	if _week_report_screen != null:
		return
	_week_ledger.closed = true
	_week_report_screen = WEEK_REPORT_SCREEN_SCRIPT.new()
	_week_report_screen.setup(_week_ledger.report(INSTANCE.core(self).get_state(), _camp_value()))
	_week_report_screen.stay_requested.connect(_on_week_report_stay)
	_week_report_screen.main_menu_requested.connect(_on_week_report_menu)
	_screen.add_child(_week_report_screen)
	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(false)
	get_tree().paused = true
	# The other wardens read the same page (they stood in a stopped camp with nothing to read).
	INSTANCE.coop(self).send_fact("books", [_week_report_screen.report_data()])


## What stands in the camp, at what it costs to build (the month's books: what was put into the
## camp is not money lost).
func _camp_value() -> int:
	var state = INSTANCE.core(self).get_state()
	if state == null or state.grid == null or economy_manager == null:
		return 0
	var total := 0
	for c in state.grid.cells:
		var cell: Dictionary = state.grid.cells[c]
		if cell.get("root_coord", c) == c:
			total += int(economy_manager.get_cost(str(cell.get("type", ""))))
	return total


func _close_week_report() -> void:
	if _week_report_screen != null:
		_week_report_screen.queue_free()
		_week_report_screen = null
	get_tree().paused = false


## The other warden's copy of the books: the host says whether the camp goes on.
func _coop_show_books(report: Dictionary) -> void:
	if _week_report_screen != null:
		return
	_week_report_screen = WEEK_REPORT_SCREEN_SCRIPT.new()
	_week_report_screen.setup(report)
	_week_report_screen.follower = true
	_week_report_screen.main_menu_requested.connect(_on_week_report_menu)
	_screen.add_child(_week_report_screen)
	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(false)


func _coop_books_closed() -> void:
	if _week_report_screen == null:
		return
	_week_report_screen.queue_free()
	_week_report_screen = null
	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(true)
	if not _is_any_interior_open():
		INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Stay on: the week is closed, the camp runs on with no end (sandbox from here).
func _on_week_report_stay() -> void:
	INSTANCE.coop(self).send_fact("books_shut", [])
	_close_week_report()
	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(true)
	if not _is_any_interior_open():
		INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _hud_manager != null:
		_hud_manager.push_status("Vera took the noon bus back to town. \"You know the way,\" she said.", 1)


func _on_week_report_menu() -> void:
	_close_week_report()
	_enter_main_menu()


## The morning the goods came by themselves (a sandbox camp with no day events).
var _goods_day := 0


func _tick_day_events() -> void:
	if _day_events != null and not camp_rule("events") and INSTANCE.coop(self).sim_here() and _gameplay_started and _day_index != _goods_day and _time_of_day_hours >= 8.0:
		# No delivery van to sign for without them: what was ordered and paid comes all the same.
		_goods_day = _day_index
		if INSTANCE.core(self).actions != null:
			INSTANCE.core(self).actions.biz_receive(_day_index)
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
	var state = INSTANCE.core(self).get_state()
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
		INSTANCE.core(self).failure_system._trigger_failure(key, "sewer", coord)
		state.failures[key]["night"] = true
		if _hud_manager != null:
			_hud_manager.push_pager("Pager: Sewer leaking. The sewer hatch: crawl in.", 2)
		return


func _on_night_jobs_changed() -> void:
	var powered := _is_grid_powered()
	_note_grid_power(powered)
	if GuestManager != null and INSTANCE.guests(self).has_method("set_camp_power_available"):
		INSTANCE.guests(self).set_camp_power_available(powered)
	_apply_time_from_clock(true, false)
	_sync_dark_lamps()


## The moment the camp goes dark it makes the sound of it (power_out.mp3).
func _note_grid_power(powered: bool) -> void:
	if _grid_was_powered and not powered and _audio_manager != null and _audio_manager.has_method("play_power_out"):
		_audio_manager.play_power_out()
	_grid_was_powered = powered


func _is_grid_powered() -> bool:
	if INSTANCE.coop(self).is_client():
		return _coop_powered
	return not _billing.power_cut_active and not (_night_jobs != null and _night_jobs.breaker_tripped)


## Tools: where the lamps are (the shot driver's Expression cannot reach autoloads).
func _count_lamps_debug() -> Array:
	return INSTANCE.core(self).get_state().grid.lamp_coords()


func _cell_debug(x: int, y: int) -> Dictionary:
	return INSTANCE.core(self).get_state().grid.cells.get(Vector2i(x, y), {})


## Lamps dark for their own reasons: a lamp breakdown, or the circuit left off.
func _sync_dark_lamps() -> void:
	if building_manager == null or not building_manager.has_method("set_broken_lamps"):
		return
	var state = INSTANCE.core(self).get_state()
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
func _on_structure_interact_override(_structure: Node3D) -> bool:
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
		_screen.add_child(_corn_rustle)
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
		_screen.add_child(_maintenance)
	_maintenance.setup(_world_3d, building_manager, Callable(self, "_get_player_camera"), _hud_manager)
	if INSTANCE.core(self).failure_system != null:
		INSTANCE.core(self).failure_system.enabled = camp_rule("wear")


## Camp Status > Upkeep (CRT) reads and acts through these.
func get_upkeep_snapshot() -> Dictionary:
	if _maintenance == null:
		return {}
	return _maintenance.get_upkeep_snapshot()


func request_maintenance_crew() -> Dictionary:
	if _maintenance == null:
		return {"ok": false, "reason": "unavailable"}
	if INSTANCE.coop(self).is_client():
		# The crew is the host's to send (and pay): asked for from here.
		var snap: Dictionary = _maintenance.get_upkeep_snapshot()
		if bool(snap.get("night", false)):
			return {"ok": false, "reason": "night"}
		if int(snap.get("crew_jobs", 0)) <= 0:
			return {"ok": false, "reason": "nothing_to_do"}
		if INSTANCE.core(self).get_money() < int(snap.get("crew_cost", 0)):
			return {"ok": false, "reason": "insufficient_funds", "amount": int(snap.get("crew_cost", 0))}
		INSTANCE.coop(self).send_request("crew", [])
		return {"ok": true, "jobs": int(snap.get("crew_jobs", 0)), "amount": int(snap.get("crew_cost", 0))}
	return _maintenance.request_maintenance_crew()


## The crew to one building (Builder's map). In co-op asked of the host.
func request_maintenance_crew_at(coord: Vector2i) -> Dictionary:
	if _maintenance == null:
		return {"ok": false, "reason": "unavailable"}
	if INSTANCE.coop(self).is_client():
		if INSTANCE.core(self).is_night():
			return {"ok": false, "reason": "night"}
		INSTANCE.coop(self).send_request("crew_at", [coord])
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
	var guest: Dictionary = _guest_agents.find_guest_in_view(cam, INTERACT_DISTANCE + 0.8)
	# Who stands at the corn stand is there to be served: E is the stand's (the user 5. 11.:
	# with customers at it there was only "talk to" and no way behind the counter).
	var act: Dictionary = guest.get("activity", {})
	if str(act.get("target_type", "")) == "corn_stand" and int(act.get("arrive", 0)) <= int(guest.get("now_abs", 0)):
		return {}
	return guest


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
			_hud_manager.push_status("%s: \"%s\"" % [entry.get("name", ""), tr(str(entry.get("text", "")))])
		break


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
		_screen.add_child(_weather_visuals)
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
	_screen.add_child(_hud_manager)
	_hud_manager.setup_interaction_hint()
	_hud_manager.setup_money_hud()
	_hud_manager.setup_weather_hud()
	_hud_manager.setup_time_hud()
	_hud_manager.set_camera_provider(Callable(self, "_get_player_camera"))
	_sync_hud_health()
	_sync_liminal_forecast_hud(true)


func _setup_interior_manager() -> void:
	_ensure_interior_manager()
	if _interior_manager.has_method("setup_all"):
		_interior_manager.setup_all()


func _ensure_interior_manager() -> void:
	_bind_or_create_managers()
	if legacy_ui_adapter == null:
		legacy_ui_adapter = LEGACY_UI_ADAPTER_SCRIPT.new()
		legacy_ui_adapter.name = "LegacyUIAdapter"
		_screen.add_child(legacy_ui_adapter)
	if _interior_manager == null:
		_interior_manager = INTERIOR_MANAGER_SCRIPT.new()
		_interior_manager.name = "InteriorManager"
		_screen.add_child(_interior_manager)
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


func _setup_interaction_controller() -> void:
	if _interaction_controller == null:
		_interaction_controller = INTERACTION_CONTROLLER_SCRIPT.new()
		_interaction_controller.name = "InteractionController"
		_screen.add_child(_interaction_controller)
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
		_season_look.indoors = _is_any_interior_open()
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
		_season_look.wind = (_weather_visuals.wind_dir if _weather_visuals != null else Vector2(0.94, 0.34)) * w
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
	var sim: bool = INSTANCE.coop(self).sim_here()
	if time_system and sim:
		# Slower while a warden rides the 380 through the real land (town_trip.gd):
		# its thirteen minutes take the real road's five.
		time_system.process(delta * clock_pace())
	elif time_system and INSTANCE.coop(self).is_client() and _gameplay_started and not _menu_mode:
		_coop_camp.run_clock(delta)
	if weather_system and sim and not camp_rule("weather"):
		if weather_system.current_weather != WEATHER_CLEAR:
			weather_system.set_weather(WEATHER_CLEAR)
	elif weather_system and sim:
		var state = INSTANCE.core(self).get_state()
		if state != null:
			weather_system.set_anomaly_pressure(float(state.hrotfaktor))
		weather_system.season_day = _day_index
		weather_system.process(delta * clock_pace() * BALANCE_CONFIG.GAME_MINUTES_PER_SECOND, _time_of_day_hours)
	_sync_runtime_state_from_systems()
	_sync_season()
	if sim:
		_online.tick_blueprint_guests(delta)
		_online.tick_ads(delta)
	# The storm on its way (the host's, in co-op): the sky, the wind and the far thunder.
	var build: float = (weather_system.storm_build() if weather_system != null and camp_rule("weather") else 0.0) if sim else _coop_storm_build
	if _audio_manager != null:
		_audio_manager.set("storm_build", 0.0 if is_snowing() else build)
		_audio_manager.set("season_day", _day_index)
	if _weather_visuals != null:
		_weather_visuals.storm_build = build
		_weather_visuals.update_state(_time_state, _time_of_day_hours, _weather_state)
		_weather_visuals.update_frame(delta)

	if _menu_mode:
		_title_stage.update(delta)
		return

	if sim:
		_process_electricity_runtime(delta)

	if _liminal_window != null:
		_liminal_window.tick(delta)

	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(not _is_any_interior_open(), true)
	_coop_camp.tick_down(delta)
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
	if _caretaker != null:
		_caretaker.tick(delta)
	if _pa_horns != null:
		_pa_horns.tick(delta)
	_sync_hud_player_meters()
	# Who is coming, at the gate, the day's and the night's jobs: on the HUD of both machines
	# (the other's from the host's pulse).
	_poll_arrivals(delta)
	if sim:
		_tick_night_jobs()
		_tick_week_ledger()
		_poll_guest_quotes(delta)
	_tick_evening()
	# The other warden's machine sees its own omens (they are only signs near you).
	if not sim and _omens != null and not _game_over_active and _player != null and is_instance_valid(_player) and camp_rule("threats"):
		var omen_minute := (maxi(1, _day_index) - 1) * 1440 + int(round(_time_of_day_hours * 60.0))
		_omens.tick(get_process_delta_time(), omen_minute, not _is_any_interior_open() and not get_tree().paused, _player.global_position, _omen_context())
	# The other warden's machine too: the host's day events shown and done from here
	# (day_events.coop_follow), the lamps' signs and hold R (what it does goes to the host).
	if _day_events != null:
		_day_events.coop_follow = INSTANCE.coop(self).is_client()
	_tick_day_events()
	if _maintenance != null:
		_maintenance.tick(delta, not _is_any_interior_open() and not _game_over_active)
	_demo_end.tick(delta)
	if visual_module != null and visual_module.has_method("sync_enemy_distortion_fx"):
		visual_module.sync_enemy_distortion_fx(_time_state)
	if sim:
		_tick_autosave(delta)


## The left button is E out in the camp, as the controls page says. A click never reaches
## _unhandled_input here (the world's viewport container takes it): the hand went out to the
## door and nothing came of it. What takes a click of its own (carrying, the seats) has it
## first and marks it handled.
## Main's input comes through its screen (scripts/instance/screen_input.gd, made in _ready),
## heard where it was before the screen.
func screen_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if INSTANCE.input(self).get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or not _gameplay_started or _menu_mode or _game_over_active or get_tree().paused:
		return
	if _is_any_interior_open() or _in_attraction() or (_lake_trip != null and _lake_trip.is_active()):
		return
	if _hud_manager != null and str(_hud_manager.get("_hint_text")).strip_edges() != "":
		_try_interact()


func screen_unhandled_input(event: InputEvent) -> void:
	if not _startup_bootstrap_complete:
		return
	if _menu_mode:
		return
	if _game_over_active:
		return
	# Esc gets here when nothing else took it: rooms, the PC, jobs and close-ups leave by
	# it (the user, 4. 11.), so this is the pause menu out in the camp. P and F10 open it
	# anywhere (PauseKeys).
	if event.is_action_pressed("ui_cancel"):
		# The pause menu up and its own Esc not taken (a sub-page takes it): back to the game
		# (playtest 24. 11.: "ESC mě nevrátí z pause menu zpět do hry"; it tried to open it again).
		if _pause_menu != null and _pause_menu.is_open():
			_close_pause_menu(true)
		else:
			_open_pause_menu()
		_screen.set_input_as_handled()
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

	_day_index = max(1, INSTANCE.core(self).get_day())

	var minute_changed = _clock_minutes_from_hours(previous_hour) != _clock_minutes_from_hours(_time_of_day_hours)
	var time_changed = force or minute_changed or (previous_time_state != _time_state)
	var weather_changed = previous_weather != _weather_state
	var day_changed = previous_day != _day_index

	if time_changed:
		var force_sky_snap = force or (absf(_time_of_day_hours - previous_hour) >= (DEBUG_TIME_STEP_HOURS - 0.001))
		var state_transition = force or (previous_time_state != _time_state)
		_apply_time_from_clock(state_transition, force_sky_snap)
		# The gatehouse bulb is on as it gets dark, whatever the game's state says (it waited
		# for the night to begin, the user 4. 11.), till it is light.
		var gate_dark: bool = _time_of_day_hours >= GATE_BULB_ON_HOUR or _time_of_day_hours < GATE_BULB_OFF_HOUR
		if force or gate_dark != _gate_bulb_on:
			var gate := get_tree().get_first_node_in_group("camp_gate")
			if gate != null:
				_gate_bulb_on = gate_dark
				gate.set_night(gate_dark)
		if previous_time_state == TIME_NIGHT and _time_state == TIME_DAY:
			_on_day_phase_started()
		if previous_time_state != TIME_NIGHT and _time_state == TIME_NIGHT and _day_events != null and INSTANCE.coop(self).sim_here() and camp_rule("events"):
			_day_events.on_night()
		# On every warden's machine (the joining one has no enemy of its own to start it). At
		# dusk if you are out (the world is drawn then): the frame the night begins has its
		# things to make and its card to open.
		if previous_time_state == TIME_DAY and _time_state == TIME_EVENING and _gameplay_started and not _is_any_interior_open():
			_prewarm_hurt()
		if previous_time_state != TIME_NIGHT and _time_state == TIME_NIGHT and _gameplay_started:
			_prewarm_hurt()

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
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
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
		# (Saved out in the village or on the road: there, not back at the gate.)
		if pos_valid and grid_manager != null and not _loaded_away:
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
	# (Hurt, saved and loaded was a hundred again.)
	if _pending_loaded_player_state.has("health"):
		_set_player_health(clampi(int(_pending_loaded_player_state["health"]), 1, PLAYER_MAX_HEALTH), false)
	_loaded_away = false
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
	# (The day first: its gauge fills up from where the night left the cell.)
	if _player.has_method("is_torch_night"):
		_hud_manager.set_light_day(not bool(_player.is_torch_night()))
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
	# A joining machine runs no brains: the host's enemies, where the host says they are.
	var brains: Array = _enemy_brains
	if brains.is_empty() and _coop_night != null and INSTANCE.coop(self).is_active() and not INSTANCE.coop(self).is_host():
		brains = [_coop_night]
	_senses.update(
		delta,
		brains if outside_at_night else [],
		_player.get_node_or_null("Head/Camera3D") as Camera3D if _player != null and is_instance_valid(_player) else null,
		_day_index if outside_at_night else -1,
		_still_seconds
	)
	if _audio_manager != null and _audio_manager.has_method("set_insect_hush"):
		var corn_hush: float = float(_corn_hunt.hush) if _corn_hunt != null and is_instance_valid(_corn_hunt) else 0.0
		var dir_hush: float = _director.hush() if _director != null and (_time_of_day_hours >= 21.0 or _time_of_day_hours < 5.5) else 0.0
		if _director_fx != null:
			dir_hush = maxf(dir_hush, float(_director_fx.extra_hush))
		var evening_hold: float = float(_evening.hold) if _evening != null and is_instance_valid(_evening) else 0.0
		_audio_manager.set_insect_hush(maxf(maxf(maxf(maxf(_senses.hush, _omens.hush if _omens != null else 0.0), corn_hush), dir_hush), evening_hold))
		if _audio_manager.has_method("set_world_hold"):
			_audio_manager.set_world_hold(evening_hold)
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
		INSTANCE.bus(self).guest_at_desk.connect(_on_guest_at_desk)
		INSTANCE.bus(self).guest_checked_in.connect(_on_guest_checked_in)
		INSTANCE.bus(self).guest_gave_up.connect(_on_guest_gave_up)
		INSTANCE.bus(self).room_prepared.connect(_on_room_prepared)
	if _first_stand_up_pending and not _is_any_interior_open() and _hud_manager != null:
		_first_stand_up_pending = false
		_hud_manager.show_banner("THE CAMP", Season.date_long(_day_index).to_upper(), RETRO_UI.C_AMBER, 4.0)
	_arrivals_poll -= delta
	if _arrivals_poll > 0.0 or _hud_manager == null:
		return
	_arrivals_poll = 0.5
	if not INSTANCE.coop(self).sim_here():
		# The host's guests by the host's clock (GuestManager keeps no time of its own here).
		INSTANCE.guests(self)._on_time_tick(int(_time_of_day_hours), int(fposmod(_time_of_day_hours, 1.0) * 60.0))
	var arrivals: Array = INSTANCE.guests(self).get_arrivals()
	# Who is at the desk has the guests at the counter (the same mark as the jobs' plates).
	var at_desk := str(_troubles.taken().get("room:desk", ""))
	if at_desk != "":
		for r in arrivals:
			if bool((r as Dictionary).get("at_gate", false)):
				(r as Dictionary)["who"] = at_desk
	_hud_manager.set_arrivals(arrivals)
	# The post on its way with what you ordered (reception/post_delivery.gd).
	var bi_p = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var post_p = bi_p.get("_post") if bi_p != null else null
	if _hud_manager.has_method("set_post"):
		_hud_manager.set_post(post_p.hud_row() if post_p != null and post_p.has_method("hud_row") else {})
	# The wholesaler's van on its way with the businesses' orders, likewise.
	if _hud_manager.has_method("set_van"):
		var abs_now := (maxi(1, _day_index) - 1) * 1440 + _clock_minutes_from_hours(_time_of_day_hours)
		var van_row: Dictionary = _day_events.van_hud_row(abs_now) if _day_events != null and camp_rule("events") else {}
		if van_row.has("ev"):
			van_row["who"] = str(_troubles.taken().get("ev:%d" % int(van_row["ev"]), ""))
		_hud_manager.set_van(van_row)
	var state_now = INSTANCE.core(self).get_state()
	if _hud_manager.has_method("set_shift_bands") and state_now != null and state_now.biz is Dictionary:
		_hud_manager.set_shift_bands(STAFF_RULES_M.day_bands(state_now.biz, _day_index, float(BIZ_RULES_M.LATE_CLOSE)))
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
		_hud_manager.set_troubles(_troubles.mark_taken(_troubles.rows(biz)))


const STAFF_RULES_M = preload("res://core/systems/staff_rules.gd")
const BIZ_RULES_M = preload("res://core/systems/business_rules.gd")
## What the HUD's plates on the right list (scripts/ui/trouble_board.gd).
const TROUBLE_BOARD = preload("res://scripts/ui/trouble_board.gd")
var _troubles: RefCounted = TROUBLE_BOARD.new(self)


## A party at the counter (its figure in through the reception's door), not at the barrier
## (Richard 24. 11.: „posuň to až když budou fakt na recepci“): the pager, with the rooms
## still not made up.
func _on_guest_at_desk(guest_id: int) -> void:
	if _hud_manager == null:
		return
	var row := {}
	for r in INSTANCE.guests(self).get_desk_queue():
		if int((r as Dictionary).get("id", -2)) == guest_id:
			row = r
			break
	if row.is_empty():
		return
	var rooms: Array = row.get("rooms", [])
	var not_ready: Array[String] = []
	for r in rooms:
		if not bool((r as Dictionary).get("ready", false)):
			not_ready.append(str((r as Dictionary).get("label", "")))
	var line := "%s is at reception." % str(row.get("name", "A guest"))
	if not not_ready.is_empty():
		line += " %s not ready." % ", ".join(not_ready)
	_hud_manager.push_pager(line, 2 if not not_ready.is_empty() else 0, "arrivals")


func _on_guest_checked_in(guest: Dictionary) -> void:
	if _hud_manager != null:
		_hud_manager.push_status("%s checked in." % str(guest.get("name", "A guest")), 1, "arrivals")


func _on_guest_gave_up(row: Dictionary) -> void:
	if _hud_manager != null:
		_hud_manager.push_pager("%s gave up waiting at reception and drove off." % str(row.get("name", "A guest")), 3, "arrivals")


func _on_room_prepared(key: String) -> void:
	if _hud_manager != null:
		_hud_manager.push_status("%s is ready." % INSTANCE.guests(self).room_label(key), 1, "rooms")


func _sync_hud_health() -> void:
	if _hud_manager == null or not _hud_manager.has_method("set_health_ratio"):
		return
	var ratio := float(_player_health) / float(PLAYER_MAX_HEALTH)
	_hud_manager.set_health_ratio(clampf(ratio, 0.0, 1.0))


func _on_eventbus_state_changed(changes: Dictionary) -> void:
	if changes.is_empty():
		return
	if changes.has("guests"):
		_structures.sync_guest_counts()
		_sync_liminal_forecast_hud()


## The night's roll and the things it sends (scripts/night/night_roll.gd).
const NIGHT_ROLL = preload("res://scripts/night/night_roll.gd")
const NIGHT_SWELL = preload("res://core/systems/night_swell.gd")
const PLOT_RULES = preload("res://core/systems/plot_rules.gd")
var _night_roll: RefCounted = NIGHT_ROLL.new(self)


func _sync_liminal_forecast_hud(force: bool = false) -> void:
	_night_roll.sync_forecast(force)


func _enemy_hour() -> float:
	return _time_of_day_hours


# ── the corn (night job, scripts/corn_hunt.gd) ───────────────────────────────

const CORN_WANDERERS := ["drunk", "family", "tramp", "picker"]


func _corn_field() -> Node:
	return find_child("CornField", true, false)


func _corn_wanderers() -> Array:
	var out: Array = []
	if GuestManager == null:
		return out
	for g in INSTANCE.guests(self).get_guest_life_snapshot():
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
	_screen.add_child(hunt)
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
		INSTANCE.guests(self).apply_guest_event(int(hunt.guest_id), 15.0, "You came for me. In the dark. Thank you.")
		if _hud_manager != null:
			_hud_manager.push_status("%s is back in the camp, shaking. (mood +15)" % who, 1)
	else:
		INSTANCE.guests(self).apply_guest_event(int(hunt.guest_id), -18.0, "Nobody came. Something stood by me all night.")
		if _hud_manager != null:
			_hud_manager.push_status("At first light %s walked out of the corn alone. They won't say what they saw." % who, 3)
	hunt.queue_free()


func _tick_active_enemy_brain(delta: float) -> void:
	for brain in _enemy_brains:
		if brain != null and brain.has_method("tick"):
			brain.tick(delta)
	for i in range(_dawn_leaving.size() - 1, -1, -1):
		if _dawn_leaving[i].dawn_tick(delta):
			_dawn_leaving.remove_at(i)


func _stop_active_enemy_brain() -> void:
	for brain in _enemy_brains + _dawn_leaving:
		if brain != null and brain.has_method("stop_night"):
			brain.stop_night()
	_dawn_leaving.clear()
	_enemy_brains.clear()
	_senses.reset()
	_active_enemy_brain = null
	_active_enemy_brain_id = ""


## The night's end: its sounds go, and what you are looking at stays as it stands until you look
## away (all stopped in one frame at 6:30 they went out under your eyes, the Photographer with
## his hum). Whatever is on you goes at once, with its hold (`leave_at_dawn`).
var _dawn_leaving: Array = []


func _enemies_leave_at_dawn() -> void:
	var stay: Array = []
	for brain in _enemy_brains:
		if brain != null and brain.has_method("leave_at_dawn") and brain.leave_at_dawn():
			stay.append(brain)
	for brain in stay:
		_enemy_brains.erase(brain)
	_stop_active_enemy_brain()
	_dawn_leaving = stay


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
	if not INSTANCE.coop(self).sim_here():
		# The other warden's machine: only what dawn does to you.
		if _player != null and _player.has_method("recharge_flashlight"):
			_player.recharge_flashlight()
		return
	_night_roll.claim_turned_guests()
	_enemies_leave_at_dawn()
	if _director_fx != null:
		_director_fx.clear()
	# The bazaar's buyers called in the night: what sold is paid at dawn.
	_online.settle_bazaar()
	_online.settle_goggle()
	if _night_jobs != null:
		if _week_ledger != null:
			_week_ledger.note_jobs_left(_night_jobs.take_left_count())
		_night_jobs.on_dawn()
	if _player != null and _player.has_method("recharge_flashlight"):
		_player.recharge_flashlight()
	# (Wounds do not mend by the morning any more: they mend slowly through the day
	# (_tick_day_regen), or with a first-aid box. The user 4. 11.)
	var removed_scene_enemies = _despawn_all_runtime_enemies()
	var removed_virtual: int = _night_roll.virtual_count
	_night_roll.virtual_count = 0
	_night_roll.spawned_this_night = 0
	_night_roll.last_despawn_count = removed_scene_enemies + removed_virtual
	_night_roll.last_despawn_day = _day_index
	_refresh_liminal_debug_window()
	# The camp as the day starts: where a death goes back to.
	call_deferred("_write_morning_save")


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
	if _liminal_window == null:
		_liminal_window = LIMINAL_WINDOW.new(self)
		_screen.add_child(_liminal_window)
	_liminal_window.toggle()


func _refresh_liminal_debug_window() -> void:
	if _liminal_window != null:
		_liminal_window.refresh()


func _hide_liminal_debug_window() -> void:
	if _liminal_window != null:
		_liminal_window.show_window(false)


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
## hurt; at night only the first-aid cabinets (scripts/aid_cabinet.gd: the store's, the
## staffroom's, one go each a morning).
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


## A first-aid cabinet's lot taken (scripts/aid_cabinet.gd).
func heal_player(amount: int) -> void:
	if amount <= 0 or _game_over_active:
		return
	_set_player_health(_player_health + amount, false)


## Something to mend (a cabinet invites a click only then).
func player_hurt() -> bool:
	return _player_health < PLAYER_MAX_HEALTH and _player_health > 0 and not _coop_down


func damage_player(amount: int) -> void:
	if amount <= 0 or _coop_down:
		return
	# The night's blows as hard as the camp's nights are (a sandbox camp's setup).
	amount = NIGHT_SWELL.hit(amount, night_severity())
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
		_screen.add_child(_hurt_fx)
	_hurt_fx.hit(damage_amount, tier, fatal_hit)
	if _player != null and _player.has_method("play_damage_feedback"):
		_player.play_damage_feedback(tier, damage_amount, fatal_hit)
	_spawn_blood_damage_fx(tier, fatal_hit)


func _reset_player_damage_feedback() -> void:
	if _hurt_fx != null and is_instance_valid(_hurt_fx):
		_hurt_fx.clear()
	if _player != null and _player.has_method("reset_damage_feedback_state"):
		_player.reset_damage_feedback_state()


func _trigger_game_over(reason: String = GAME_OVER_REASON_DEATH) -> void:
	if _game_over_active:
		return
	# Co-op: the camp goes on for the other warden; you come to by the office.
	if reason == GAME_OVER_REASON_DEATH and INSTANCE.coop(self).has_partner():
		_coop_camp.come_to()
		return
	_stop_active_enemy_brain()
	_game_over_active = true
	_game_over_reason = reason
	_hide_liminal_debug_window()
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
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_game_over_screen()


func _spawn_blood_damage_fx(tier: int, fatal_hit: bool) -> void:
	if _world_3d == null or not _gameplay_started or _menu_mode:
		return
	_ensure_blood_fx()
	_blood_fx.spawn(tier, fatal_hit)


func _ensure_blood_fx() -> void:
	if _blood_fx == null:
		_blood_fx = BLOOD_FX_SCRIPT.new()
		_blood_fx.name = "BloodFx"
		_screen.add_child(_blood_fx)
		_blood_fx.setup(_world_3d, Callable(self, "_get_player_camera"), Callable(self, "_get_player_ref"))


## The night's first enemy: the hurt on the screen, its sounds, the blood and the night's
## own layer made now and their shaders compiled, not at the first scare or hit (cold, the
## girl's strike, bite and the blood landing each cost a 76-132 ms frame; measured 4. 11.
## with tools/holka_shots.tscn --part=hitch). Once a session.
var _hurt_warmed := false


func _prewarm_hurt() -> void:
	if _hurt_warmed or _world_3d == null:
		return
	_hurt_warmed = true
	if _hurt_fx == null or not is_instance_valid(_hurt_fx):
		_hurt_fx = HURT_FX_SCRIPT.new()
		_hurt_fx.set("main", self)
		_screen.add_child(_hurt_fx)
	_hurt_fx.prewarm()
	_ensure_blood_fx()
	_blood_fx.prewarm()


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
	var state = INSTANCE.core(self).get_state()
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
	_screen.add_child(_game_over_screen)


func _clear_game_over_screen() -> void:
	if _game_over_screen == null:
		return
	_game_over_screen.queue_free()
	_game_over_screen = null


func _on_game_over_load_save_pressed() -> void:
	_game_over_active = false
	_clear_game_over_screen()
	var shared = INSTANCE.coop(self).is_active()
	# That day's morning (the night after midnight is still the day before's: the latest
	# morning up to today), or the last save when the camp has none yet.
	var morning := SaveManager.morning_for(_day_index)
	_enter_main_menu()
	if shared:
		_main_menu.show_page("load")
		return
	if morning != "":
		await _on_menu_load_requested(morning)
		return
	await _on_menu_continue_pressed()


func _on_game_over_main_menu_pressed() -> void:
	_game_over_active = false
	_clear_game_over_screen()
	_enter_main_menu()


func _bind_or_create_managers() -> void:
	grid_manager = _resolve_manager_node("GridManager", GRID_MANAGER_SCRIPT, "initialize_grid")
	building_manager = _resolve_manager_node("BuildingManager", BUILDING_MANAGER_SCRIPT, "setup")
	world_generator = _resolve_manager_node("WorldGenerator", WORLD_GENERATOR_SCRIPT, "generate_world")

	var existing_econ = _screen.get_node_or_null("EconomyManager")
	if existing_econ != null and existing_econ.has_method("get_money"):
		economy_manager = existing_econ
	else:
		if existing_econ != null:
			remove_child(existing_econ)
			existing_econ.queue_free()
		economy_manager = ECONOMY_MANAGER_SCRIPT.new()
		economy_manager.name = "EconomyManager"
		_screen.add_child(economy_manager)
	if _hud_manager != null and _hud_manager.has_method("on_money_changed"):
		var cb = Callable(_hud_manager, "on_money_changed")
		# Canonical money flow is emitted by GameActions via EventBus.
		if INSTANCE.bus(self).has_signal("money_changed") and not INSTANCE.bus(self).money_changed.is_connected(cb):
			INSTANCE.bus(self).money_changed.connect(cb)
		# Legacy compatibility fallback.
		if economy_manager.has_signal("money_changed") and not economy_manager.money_changed.is_connected(cb):
			economy_manager.money_changed.connect(cb)
		_hud_manager.on_money_changed(INSTANCE.core(self).get_money())


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


## A new camp's land a step at a time, the loading screen saying which: in one go the bar
## stood still for a second.
func _generate_new_camp() -> void:
	if grid_manager == null or building_manager == null or world_generator == null:
		_generate_grid_world()
		return
	grid_manager.initialize_grid(Vector2i(28, 28), 4.0)
	building_manager.setup(grid_manager)
	world_generator.setup(grid_manager, building_manager)
	world_generator.world_seed = _pending_world_seed
	_pending_world_seed = 0
	await world_generator.generate_world_stepped(_menu_step)
	if world_generator.get_node_or_null("Terrain") == null:
		push_error("World generation failed: Terrain node was not created.")
		world_generator.create_emergency_ground(_world_3d)


## The rooms built behind the loading bar, one at a time: all at once as the game started,
## the bar stood still for a second and more. (Nothing to do when they stand already: the
## second camp of a run. The start's own setup_all finds them and goes on.)
func _furnish_rooms_stepped() -> void:
	_ensure_interior_manager()
	if not _interior_manager.has_method("room_jobs"):
		return
	for job: Callable in _interior_manager.room_jobs():
		await _menu_step("Furnishing the rooms", 0.0)
		job.call()


func _menu_step(text: String, _progress: float) -> void:
	if _title_stage != null:
		_title_stage.let_go()
	if _main_menu != null:
		_main_menu.show_loading(text)
	await get_tree().process_frame
	await get_tree().process_frame


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
	# Nothing is paid for a building standing: only the guests pay, the businesses earn
	# what they sell (Richard 24. 11., docs/DESIGN.md §7). The flat earnings a day are gone.
	INSTANCE.bus(self).day_advanced.emit(_day_index, 0)
	if EmailManager != null and INSTANCE.mail(self).has_method("settle_reputation"):
		INSTANCE.mail(self).settle_reputation()
	if _hud_manager != null: _hud_manager.update_time(_time_of_day_string(), _day_index)
	_sync_liminal_forecast_hud()
	_refresh_liminal_debug_window()
	_emit_state_update()


## The camp on the office PC's web: Atlas, the Bazaar, the day graphs
## (scripts/reviews/camp_online.gd).
const CAMP_ONLINE = preload("res://scripts/reviews/camp_online.gd")
var _online: RefCounted = CAMP_ONLINE.new(self)


func atlas_hour() -> int:
	return _online.atlas_hour()


func atlas_buy_ad(kind: String, days: int) -> Dictionary:
	return _online.atlas_buy_ad(kind, days)


func goggle_remove(id: int) -> Dictionary:
	return _online.goggle_remove(id)


func goggle_reply(id: int, kind: String) -> void:
	_online.goggle_reply(id, kind)


func goggle_mail_replied(guest_id: int, reply_id: String) -> void:
	_online.goggle_mail_replied(guest_id, reply_id)


func bazaar_list(id: int) -> bool:
	return _online.bazaar_list(id)


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
		# Out in the camp the lamps go and that is all you know: the clock has started.
		if _cut and _gameplay_started and _hud_manager != null:
			_hud_manager.push_pager("Pager: CampGrid cut the mains, the bill is overdue. The UPS holds six minutes.", 2)
		_note_grid_power(_is_grid_powered())
		if GuestManager != null and INSTANCE.guests(self).has_method("set_camp_power_available"):
			INSTANCE.guests(self).set_camp_power_available(_is_grid_powered())
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
	if INSTANCE.coop(self).is_client():
		# The bills are the host's: paid there (the money with its till); gone from the
		# list here at once, the pulse brings the rest.
		for i in _billing.bills.size():
			var bill: Dictionary = _billing.bills[i]
			if str(bill.get("id", "")) != bill_id.strip_edges():
				continue
			var amount := maxi(0, int(bill.get("amount", 0)))
			if str(bill.get("status", "unpaid")) == "paid":
				return {"ok": false, "reason": "already_paid"}
			if INSTANCE.core(self).get_money() < amount:
				return {"ok": false, "reason": "insufficient_funds", "amount": amount}
			_billing.bills.remove_at(i)
			INSTANCE.coop(self).send_request("pay_bill", [bill_id.strip_edges()])
			return {"ok": true, "amount": amount}
		return {"ok": false, "reason": "not_found"}
	var paid: Dictionary = _billing.pay(bill_id)
	if bool(paid.get("ok", false)) and _quest_manager != null:
		_quest_manager.notify("bill_paid")
	return paid


## The hour as the sky has it (weather_visuals._season_hour): what lights lamps goes by this.
func season_hour() -> float:
	return _weather_visuals._season_hour(_time_of_day_hours) if _weather_visuals != null else _time_of_day_hours


func _apply_time_from_clock(force_interior_sync: bool = false, force_sky_snap: bool = false) -> void:
	var state_changed = force_interior_sync
	var is_night = (_time_state == TIME_NIGHT)
	# By the sky's clock: in October it darkens earlier than the hour says (the sky was at night
	# at 18:22 with the lamps and the torch still off till seven).
	var lamp_and_flashlight_active = _is_hour_in_window(season_hour(), LAMP_FLASHLIGHT_START_HOUR, float(BALANCE_CONFIG.DAY_START_HOUR))
	var grid_power_available = _is_grid_powered()
	if INSTANCE.core(self).is_night() != is_night:
		INSTANCE.core(self).apply_changes({"is_night": is_night})
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
		if _player != null and _player.has_method("set_torch_night"):
			# The night the torch's cell is spent in (by day it has no end: playtest 14. 11.).
			_player.set_torch_night(lamp_and_flashlight_active and not _menu_mode)
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
	if GuestManager != null and INSTANCE.guests(self).has_method("set_camp_weather"):
		INSTANCE.guests(self).set_camp_weather(_weather_state)
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
		_screen.add_child(_music_director)
	if _caretaker == null or not is_instance_valid(_caretaker):
		_caretaker = preload("res://scripts/audio/caretaker.gd").new()
		_caretaker.name = "Caretaker"
		_caretaker.main = self
		_screen.add_child(_caretaker)
	if _pa_horns == null or not is_instance_valid(_pa_horns):
		_pa_horns = preload("res://scripts/audio/pa_horns.gd").new()
		_pa_horns.name = "PaHorns"
		_pa_horns.main = self
		_screen.add_child(_pa_horns)
	if _construction == null or not is_instance_valid(_construction):
		_construction = preload("res://scripts/camp/construction_works.gd").new()
		_construction.name = "ConstructionWorks"
		_construction.main = self
		_screen.add_child(_construction)
	if (_pallet == null or not is_instance_valid(_pallet)) and _world_3d != null:
		_pallet = preload("res://scripts/business/delivery_pallet.gd").new()
		_pallet.name = "DeliveryPallet"
		_pallet.main = self
		_world_3d.add_child(_pallet)
	if (_plot_stakes == null or not is_instance_valid(_plot_stakes)) and _world_3d != null:
		_plot_stakes = preload("res://scripts/camp/plot_stakes.gd").new()
		_plot_stakes.main = self
		_world_3d.add_child(_plot_stakes)
	if _goal_watch == null or not is_instance_valid(_goal_watch):
		_goal_watch = preload("res://scripts/camp/goal_watch.gd").new()
		_goal_watch.name = "GoalWatch"
		_goal_watch.main = self
		_screen.add_child(_goal_watch)


func _try_interact() -> void:
	if _pause_menu != null and _pause_menu.is_open() or _coop_down or _enemy_holding_player():
		return
	if _coop_camp.partner_down_near():
		_coop_camp.lift_partner()
		return
	if _interior_manager != null and not _is_any_interior_open() and _interior_manager.tent_zip_use():
		return
	if INSTANCE.coop(self).is_client():
		_coop_camp.client_interact()
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
	_player.set_controls_enabled(not _is_any_interior_open() and not (_lake_trip != null and _lake_trip.is_active()) and not _coop_camp.menu_up() and not _in_attraction() and not _coop_down and not _enemy_holding_player())
	# In a room the torch is in the room's eye's hand (player_controller.in_room, hold_torch); not
	# behind the title screen (it lit the menu's camp after Quit to menu: playtest 21. 10.).
	_player.in_room = _is_any_interior_open()
	_player.torch_usable = not _menu_mode


## A catch playing out, its close-up, its black: your legs and hands are not yours till it ends.
## (The lock above gave them back the next frame, and a door opened in the middle of one froze it
## over the room.)
func _enemy_holding_player() -> bool:
	for b in _enemy_brains:
		if b != null and b.has_method("holds_player") and bool(b.holds_player()):
			return true
	return false


## Sat by the fire, on the swing, at the net... (scripts/attractions/warden_play.gd).
func _in_attraction() -> bool:
	return _warden_play != null and is_instance_valid(_warden_play) and _warden_play.is_active()

## The torch hand at the bottom right while the torch is on outdoors (scripts/ui/torch_hand.gd).
var _torch_hand: CanvasLayer
## The numbers on the tents, cabins and caravans (scripts/lodging_signs.gd).
var _lodging_signs: Node


## The old cabin a story camp starts with (scripts/camp/ruined_cabin.gd).
const RUINED_CABIN = preload("res://scripts/camp/ruined_cabin.gd")
var _ruin: RefCounted = RUINED_CABIN.new(self)


## Its room's key, "" when there is none or it was bulldozed (the checklist asks).
func ruined_cabin_key() -> String:
	return _ruin.key_now()


func _update_torch_hand() -> void:
	if not INSTANCE.bus(self).building_serviced.is_connected(_ruin.on_serviced):
		INSTANCE.bus(self).building_serviced.connect(_ruin.on_serviced)
	if _lodging_signs == null or not is_instance_valid(_lodging_signs):
		_lodging_signs = load("res://scripts/lodging_signs.gd").new()
		_lodging_signs.name = "LodgingSigns"
		_screen.add_child(_lodging_signs)
	if _torch_hand == null or not is_instance_valid(_torch_hand):
		_torch_hand = load("res://scripts/ui/torch_hand.gd").new()
		_torch_hand.name = "TorchHand"
		_screen.add_child(_torch_hand)
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
	if _coop_camp.partner_down_near():
		_hud_manager.set_hint_text(LANG.f("[E] Get %s up", [INSTANCE.coop(self).name_of(_coop_camp.down_near_id)]))
		return
	# Something in your hands, or a small thing under the crosshair (scripts/ambient/carry.gd:
	# it takes its own E and click, on either machine).
	var carry := get_tree().get_first_node_in_group("carry")
	if carry != null and str(carry.hint()) != "":
		_hud_manager.set_hint_text(str(carry.hint()))
		return
	var zip := ""
	if _interior_manager != null and not _is_any_interior_open():
		zip = str(_interior_manager.tent_zip_hint())
	if zip != "":
		_hud_manager.set_hint_text("[E] %s" % tr(zip))
		return
	if INSTANCE.coop(self).is_client():
		_hud_manager.set_hint_text(_coop_camp.client_hint())
		return
	# (Walking up to a door or out of one: the keys are not yours.)
	if _is_any_interior_open() or (_interior_manager != null and _interior_manager.stepping_out()):
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
			_hud_manager.set_hint_text(LANG.f("[E] Check in %s", [str(guest_in_view.get("name", "guest"))]))
		else:
			_hud_manager.set_hint_text(LANG.f("[E] Talk to %s", [str(guest_in_view.get("name", "guest"))]))
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


## A room of the camp's own, the kind the night comes to the windows of: not the pipes, a
## job out on the map, Liblice, the road or the bus.
func in_camp_room() -> bool:
	if _away_in_town():
		return false
	if (_sewer_pipe_minigame != null and _sewer_pipe_minigame.is_open()) or (_utility_repair_minigame != null and _utility_repair_minigame.is_open()):
		return false
	var trip = _interior_manager.town_trip() if _interior_manager != null and _interior_manager.has_method("town_trip") else null
	if trip != null and bool(trip.is_open()):
		return false
	return _is_any_interior_open()


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
	_screen.add_child(_sewer_pipe_minigame)
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
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(false)


func _setup_utility_repair_minigame() -> void:
	_utility_repair_minigame = UTILITY_REPAIR_MINIGAME_SCRIPT.new()
	_utility_repair_minigame.name = "UtilityRepairMinigame"
	_screen.add_child(_utility_repair_minigame)
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
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(false)


func _on_repair_completed(coord: Vector2i, _building_type: String) -> void:
	# Co-op: mended in the host's camp (the breakdown goes with the next pulse).
	if INSTANCE.coop(self).is_client():
		INSTANCE.coop(self).send_request("repair", [coord])
	elif economy_manager != null and economy_manager.has_method("add_repair_progress"):
		economy_manager.add_repair_progress(coord, 1.0)
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(true)
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_repair_cancelled() -> void:
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(true)
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


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

	var current_money = INSTANCE.core(self).get_money()

	INSTANCE.bus(self).state_changed.emit({
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
		"liminal_forecast": _night_roll.forecast.duplicate(true),
	})


func _enter_main_menu() -> void:
	_close_week_report()
	# Leaving a co-op camp closes the line (the other warden goes back to their menu).
	INSTANCE.coop(self).leave()
	# Whatever room, job or close-up was open is shut, or it stays under the menu taking
	# clicks (playtest 18. 10.: cleaning a tent behind the title screen).
	_leave_everything(true)
	_stop_active_enemy_brain()
	if INSTANCE.core(self).failure_system != null:
		INSTANCE.core(self).failure_system.enabled = false
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
	_hide_liminal_debug_window()
	_night_roll.reset()
	if _hud_manager != null and _hud_manager.has_method("set_liminal_forecast_count"):
		_hud_manager.set_liminal_forecast_count(0)
	_menu_mode = true
	_gameplay_started = false
	_hub_playing(false)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_torch_night"):
		_player.set_torch_night(false)
		_player.set("torch_switch", false)
	_pending_loaded_player_state.clear()
	_pending_loaded_crt_state.clear()
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)
	_close_pause_menu(false)
	_set_hud_shown(false)
	_ensure_main_menu()
	_load_preview_world_for_menu()
	_main_menu.open()
	_start_menu_music()
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


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
	# A game is coming: the title lets go of its dusk (it set the hour back every frame).
	if _title_stage != null:
		_title_stage.let_go()
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
	_screen.add_child(_main_menu)
	_main_menu.continue_requested.connect(_on_menu_continue_pressed)
	_main_menu.new_game_requested.connect(_on_menu_new_game_pressed)
	_main_menu.new_camp_requested.connect(_on_menu_new_camp)
	_main_menu.load_requested.connect(_on_menu_load_requested)
	_main_menu.quit_requested.connect(func() -> void: get_tree().quit())
	_main_menu.coop_host_requested.connect(_on_menu_coop_host)
	_main_menu.coop_host_saved_requested.connect(_on_menu_coop_host_saved)
	_main_menu.coop_join_requested.connect(_on_menu_coop_join)
	_main_menu.test_night_requested.connect(_on_menu_test_night)
	_coop_camp.wire()


func _on_menu_load_requested(path: String) -> void:
	var started := Time.get_ticks_msec()
	await _show_menu_loading_for("Loading save file...")
	if not _start_loaded_game_from_path(path):
		await _hide_menu_loading_after(started, 180)
		return
	await _hide_menu_loading_after(started, 520, false)
	_start_game_from_menu()
	_night_roll.resume_after_load.call_deferred()


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
	_night_roll.resume_after_load.call_deferred()


## A new camp for the tools (screenshot driver, harnesses): not one of the warden's camps
## (its autosaves go to the old folder, user://saves).
func _on_menu_new_game_pressed() -> void:
	PROFILES.detach()
	await _start_new_camp(false)


## NEW CAMP (main menu, or the co-op page's Host a new camp): a camp of the warden's,
## named, its world from `seed` (0: a new one).
func _on_menu_new_camp(camp_name: String, seed: int, coop: bool, sandbox: bool, rules: Dictionary) -> void:
	if coop and not INSTANCE.coop(self).host():
		if _main_menu != null:
			_main_menu.show_coop_notice("Port %d is taken." % INSTANCE.coop(self).port)
		return
	await _start_new_camp(sandbox, "", camp_name, seed, coop, rules)


## The title's secret L page: test nights, the bus, the businesses' camp, the content reel
## (scripts/debug/test_camps.gd). `_test_night`: the camp being made is a test night's.
const TEST_CAMPS = preload("res://scripts/debug/test_camps.gd")
var _test_camps: RefCounted = TEST_CAMPS.new(self)
var _test_night := ""


func _on_menu_test_night(enemy_id: String) -> void:
	await _test_camps.start(enemy_id)


## Shot driver and tools: the test camp's small camp built in the camp there is.
func _build_test_camp(enemy_id: String) -> void:
	_test_camps.build_camp(enemy_id)


## A fresh camp. `sandbox`: no month, no checklist and no story mails, the programs
## already on the PC, `rules` its switches (CAMP_RULES). Co-op camps are either.
## `test_enemy`: a test night's camp (`_on_menu_test_night`), not opened at the desk.
func _start_new_camp(sandbox: bool, test_enemy: String = "", camp_name: String = "", seed: int = 0, coop: bool = false, rules: Dictionary = {}) -> void:
	var started := Time.get_ticks_msec()
	await _show_menu_loading_for("Generating a fresh camp...")
	_snapshot.reset_for_new_game()
	_sandbox = sandbox
	_camp_rules = CAMP_RULES.merged(rules, true) if sandbox else CAMP_RULES.duplicate()
	if int(_camp_rules.get("money", 0)) > 0:
		INSTANCE.core(self).apply_changes({"money": int(_camp_rules["money"])})
		if _week_ledger != null:
			_week_ledger.reset(int(_camp_rules["money"]))
	_test_night = test_enemy
	_pending_world_seed = seed
	await _generate_new_camp()
	# A sandbox's land: the plot it starts on (core/systems/plot_rules.gd), the rest bought.
	if sandbox and grid_manager != null and world_generator != null:
		var grid := Vector2i(int(grid_manager.grid_width), int(grid_manager.grid_height))
		INSTANCE.core(self).actions.set_plot(PLOT_RULES.start(int(_camp_rules.get("plot", 2)), grid, world_generator.gate_tile().x))
	# A sandbox's goals, chosen on its form (core/systems/goal_rules.gd).
	if sandbox:
		INSTANCE.core(self).actions.set_goals(_camp_rules.get("goals", []) if _camp_rules.get("goals", []) is Array else [])
	# The warden's new camp (scripts/profiles.gd), its saves from now on (a test night's
	# camp and the tools' are nobody's).
	if test_enemy.is_empty() and camp_name != "":
		PROFILES.create_camp(camp_name, world_generator.world_seed, sandbox, coop)
	_refresh_camp_sign()
	_structures.rebuild_cells()
	# The camp's old cabin, shut since last summer: the campaign's start, not a sandbox's
	# (there you build from a clean camp: the user 20. 10.).
	if sandbox:
		_ruin.key = ""
	else:
		_ruin.place()
	if time_system != null and time_system.has_method("set_time_hours"):
		time_system.set_time_hours(9.0)
	if weather_system != null and weather_system.has_method("set_weather"):
		weather_system.set_weather(WEATHER_CLEAR)
	_sync_runtime_state_from_systems(true)
	await _furnish_rooms_stepped()
	await _hide_menu_loading_after(started, 520, false)
	_pending_quest_state_loaded = false
	if sandbox:
		_pending_loaded_crt_state = {"unlock_registry": {"builder": true, "camp_status": true, "guestrack": true, "datapunch": true}}
	# (A test night's camp is not opened at the desk.)
	_start_game_from_menu(test_enemy.is_empty())
	# The first morning: where a death on the first nights goes back to.
	call_deferred("_write_morning_save")
	if _week_ledger != null:
		_week_ledger.start_built = _camp_value()
	# A sandbox camp has no story: no mails from Vera or Nela, no checklist. The district
	# writes how a camp starts, and the first booking comes once a bed is free.
	if not sandbox and _quest_manager != null:
		_quest_manager.begin_new_game()
	elif sandbox and test_enemy.is_empty() and EmailManager != null:
		INSTANCE.mail(self).sandbox_start(time_system.get_time_string() if time_system != null and time_system.has_method("get_time_string") else "09:00")
	# A new game always opens on the same song (Radio Jedna).
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi != null and bi.has_method("queue_first_radio_track"):
		bi.queue_first_radio_track()


# ── co-op (scripts/coop/coop.gd) ────────────────────────────────────────────

## A sandbox camp (DESIGN.md §12): no month and no checklist. A co-op camp may be either
## (the story's mails and checklist are the host's: quest_manager.coop_state).
var _sandbox := false
## A sandbox camp's switches (NEW CAMP): the night's things (brains, director, omens),
## weather (off: always clear), day events, breakdowns (wear and the night's jobs), the
## starting till (0: the usual). A story camp has them all on. Saved as "rules".
## "nights": how bad they are when they come (0 quiet, 1 usual, 2 bad: night_swell.SEVERITY_*;
## 25. 11.), a story camp's usual.
## "plot": the land a sandbox camp starts on (0 small, 1 middle, 2 the whole camp:
## plot_rules.SIZES; 25. 11.). "goals": the ones chosen (goal_rules.GOALS ids).
const CAMP_RULES := {"threats": true, "weather": true, "events": true, "wear": true, "money": 0, "nights": 1, "plot": 2, "goals": []}
var _camp_rules: Dictionary = CAMP_RULES.duplicate()


func camp_rule(id: String) -> bool:
	return bool(_camp_rules.get(id, true))


## How bad the nights are (0 quiet, 1 usual, 2 bad).
func night_severity() -> int:
	return clampi(int(_camp_rules.get("nights", 1)), 0, 2)
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
	if INSTANCE.coop(self).is_client() and _coop_camp_name != "":
		return _coop_camp_name
	if PROFILES.camp_id == "":
		return _coop_camp_name
	return str(PROFILES.camp_info(PROFILES.camp_id).get("name", ""))


## A new name for the camp: the profile's (the host's), the board, the other machine's.
func set_camp_name(n: String, from_peer := false) -> void:
	n = n.strip_edges().left(CAMP_NAME_MAX)
	if n == "":
		return
	if INSTANCE.coop(self).is_client() or PROFILES.camp_id == "":
		_coop_camp_name = n
	else:
		PROFILES.rename_camp(PROFILES.camp_id, n)
	_refresh_camp_sign()
	if not from_peer and INSTANCE.coop(self).is_active():
		INSTANCE.coop(self).send_sync("camp_name", [n])


func _refresh_camp_sign() -> void:
	# (All of them: the menu's board, on its way out, still stood first in the group.)
	get_tree().call_group("camp_gate", "set_camp_name", camp_name())


## E on the board by the gate: the board up close, its name painted anew.
func open_camp_sign() -> void:
	if _sign_paint != null and is_instance_valid(_sign_paint):
		return
	_sign_paint = SIGN_PAINT.new()
	_screen.add_child(_sign_paint)
	_sign_paint.open(camp_name())
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(false)
	_sign_paint.painted.connect(func(n: String): set_camp_name(n))
	_sign_paint.closed.connect(func():
		if _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled"):
			_player.set_controls_enabled(true))
## The camp for two (scripts/coop/coop_camp.gd): what the host sends and the others do
## again, the clocks, a warden down, the menu's co-op. The Coop autoload talks to main
## through coop_* below; the night for two (_coop_night) and whether you are down
## (_coop_down) stay here, read all over.
const COOP_CAMP = preload("res://scripts/coop/coop_camp.gd")
var _coop_camp: RefCounted = COOP_CAMP.new(self)
const COOP_NIGHT_SCRIPT = preload("res://scripts/coop/coop_night.gd")
var _coop_night: Node
var _coop_down := false


func _on_menu_coop_host() -> void:
	await _coop_camp.on_menu_host()


func _on_menu_coop_host_saved(path: String) -> void:
	await _coop_camp.on_menu_host_saved(path)


func _on_menu_coop_join(address: String) -> void:
	await _coop_camp.on_menu_join(address)


func coop_lifted(who: int = 0) -> void:
	_coop_camp.lifted(who)


func coop_camp_pulse() -> Dictionary:
	return _coop_camp.camp_pulse()


func coop_apply_pulse(p: Dictionary) -> void:
	_coop_camp.apply_pulse(p)


func coop_sync_poll() -> void:
	_coop_camp.sync_poll()


func coop_sync(kind: String, data: Array) -> void:
	_coop_camp.sync(kind, data)


func coop_screen_frame() -> PackedByteArray:
	return _coop_camp.screen_frame()


func coop_show_screen(frame: PackedByteArray) -> void:
	_coop_camp.show_screen(frame)


func coop_door(key: String, pick: int, seconds: float) -> void:
	_coop_camp.door(key, pick, seconds)


func coop_room_task(key: String, task_id: String) -> void:
	_coop_camp.room_task(key, task_id)


func coop_room_state(key: String, acc: Dictionary) -> void:
	_coop_camp.room_state(key, acc)


func coop_apply_fact(kind: String, data: Array) -> void:
	_coop_camp.apply_fact(kind, data)


func coop_request(kind: String, data: Array) -> void:
	_coop_camp.request(kind, data)


func coop_world_snapshot() -> Dictionary:
	return _coop_camp.world_snapshot()


func coop_world_root() -> Node3D:
	return _coop_camp.world_root()


func coop_local_warden() -> Dictionary:
	return _coop_camp.local_warden()


func coop_clock() -> Dictionary:
	return _coop_camp.clock()


func coop_apply_clock(c: Dictionary) -> void:
	_coop_camp.apply_clock(c)


## From the loading card into the game through the doors' own dissolve: the first frames of
## a camp are long (the rooms set up, their first drawing) and stand behind the still,
## which then breaks up smoothly (the polish pass of 4. 11.: the desk jolted three times as
## the PC came on; door_transition moves on by a thirtieth of a second at most a frame).
var _start_dissolve: CanvasLayer


func _play_start_dissolve() -> void:
	if _start_dissolve == null:
		_start_dissolve = START_DISSOLVE.new()
		_screen.add_child(_start_dissolve)
	_start_dissolve.play(true)


## `open_desk`: a new camp, which starts at the desk.
func _start_game_from_menu(open_desk := false) -> void:
	# The office is the game's again (the title held it at dusk with the tube off).
	_title_stage.close()
	_stop_menu_music()
	_revealing = true
	_start_gameplay_runtime()
	call_deferred("_ensure_runtime_started_after_menu_load")
	call_deferred("_write_startup_autosave")
	_reveal_game(open_desk)


## Frames drawn under the loading card before it goes: the camp from the warden's eye,
## then (a new camp) the desk. The first sight of each compiled 12-41 pipelines on screen:
## frames of 250-650 ms as the start dissolved and again on first going out
## (tools/trhnuti_check --part=start, 15. 11.). Drawn under the card they are ready.
const REVEAL_WARM_FRAMES := 4
## The card is still up over a started game (tools wait for it: shot_driver "gameplay").
var _revealing := false


func _reveal_game(open_desk: bool) -> void:
	# (One more: the warden is made a frame on, _ensure_runtime_started_after_menu_load.)
	for i in REVEAL_WARM_FRAMES + 1:
		await get_tree().process_frame
	# The camp all round, from where the warden stands: what any first step out shows.
	if _player != null and is_instance_valid(_player) and _gameplay_started:
		var keep: Transform3D = _player.global_transform
		for k in 4:
			_player.rotate_y(PI * 0.5)
			await get_tree().process_frame
			await get_tree().process_frame
		if _player != null and is_instance_valid(_player):
			_player.global_transform = keep
	# A new week starts at the desk: the first part of the game is the computer, and
	# getting up from it is something you find out you can do. The desk is what the
	# start's dissolve opens on.
	if open_desk and _interior_manager != null and _gameplay_started:
		_interior_manager.open_startup_crt_view()
		_first_stand_up_pending = true
		for i in REVEAL_WARM_FRAMES:
			await get_tree().process_frame
	_revealing = false
	if not _gameplay_started:
		return
	_play_start_dissolve()
	if _main_menu != null:
		_main_menu.close()


func _ensure_runtime_started_after_menu_load() -> void:
	await get_tree().process_frame
	if not _gameplay_started:
		return
	_menu_mode = false
	if _main_menu != null and not _revealing:
		_main_menu.close()
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player == null or not is_instance_valid(_player):
		_spawn_player()
		_apply_pending_loaded_player_state()
	_sync_active_camera()


func _write_startup_autosave() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _gameplay_started or not INSTANCE.coop(self).sim_here():
		return
	_write_autosave("Autosave")


## The title's world: always the showcase camp (scripts/ui/title/title_camp.gd, playtest
## 14. 11.), never the player's; the office at dusk over it (title_stage.gd).
func _load_preview_world_for_menu() -> void:
	_active_save_path = ""
	_snapshot.reset_for_new_game()
	_pending_world_seed = TITLE_CAMP.SEED
	_generate_grid_world()
	_prune_preview_to_reception_only()
	TITLE_CAMP.build(self)
	_structures.rebuild_cells()
	TITLE_CAMP.light(self)
	_title_stage.open()


func _start_menu_music() -> void:
	if _menu_music_player == null:
		_menu_music_player = LONG_PLAYER.make(MENU_THEME_PATH, true)
		if _menu_music_player == null:
			_menu_music_player = AudioStreamPlayer.new()
		_menu_music_player.name = "MenuMusic"
		_menu_music_player.bus = MIXER.MUSIC
		_menu_music_player.volume_db = MENU_THEME_VOLUME_DB
		_screen.add_child(_menu_music_player)
	if _menu_music_player.playing:
		return
	if _menu_music_player.get_script() == LONG_PLAYER:
		_menu_music_player.play()
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
		# shutdown, which surfaced as "resources still in use at exit". (The browser's
		# player holds only its silent stream.)
		if _menu_music_player.get_script() != LONG_PLAYER:
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


## The camp at the start of a day (at dawn, and when a camp is made): the game over's "Back
## to the morning" (TODO.md "DEMO AND STEAM": losing goes back to that day's morning).
func _write_morning_save() -> void:
	if not _gameplay_started or not INSTANCE.coop(self).sim_here() or not _test_night.is_empty():
		return
	var snapshot := _build_save_snapshot("Morning", "morning")
	if snapshot.is_empty():
		return
	var path := SaveManager.write_save(snapshot, "Morning", "morning")
	if not path.is_empty():
		_after_save(snapshot)


func _write_autosave(slot_name: String) -> void:
	# The other warden's machine holds the host's camp, not its own: nothing to save.
	# A test night's camp is thrown away.
	if not INSTANCE.coop(self).sim_here() or not _test_night.is_empty():
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


## A camp as a save holds it, both ways (scripts/save/camp_snapshot.gd).
const CAMP_SNAPSHOT = preload("res://scripts/save/camp_snapshot.gd")
var _snapshot: RefCounted = CAMP_SNAPSHOT.new(self)


func _build_save_snapshot(slot_name: String, kind: String) -> Dictionary:
	return _snapshot.build(slot_name, kind)


func _apply_save_snapshot(snapshot: Dictionary, preview_only: bool) -> bool:
	return _snapshot.apply(snapshot, preview_only)


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


## The camp's buildings and the grid's cells kept in step (scripts/camp/camp_structures.gd).
const CAMP_STRUCTURES = preload("res://scripts/camp/camp_structures.gd")
var _structures: RefCounted = CAMP_STRUCTURES.new(self)


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
		if _gameplay_started and INSTANCE.coop(self).sim_here():
			_write_autosave("Autosave")
		INSTANCE.coop(self).leave()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Alt-tab during the night should not cost the player their life (in co-op the
		# night goes on regardless: no pause).
		if pause_on_focus_loss and _can_pause_now() and not INSTANCE.coop(self).is_active():
			_open_pause_menu()


## The web page hidden (another tab, the window down): paused as alt-tab pauses on a PC.
func _on_page_hidden(hidden: bool) -> void:
	if hidden and _can_pause_now() and not INSTANCE.coop(self).is_active():
		_open_pause_menu()


## UNDO.games counts the time played while a camp is in play (web only).
func _hub_playing(on: bool) -> void:
	var hub := UNDO_HUB.node()
	if hub != null and not local_client:
		hub.set_playing(on)


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
	_pause_prev_mouse = INSTANCE.input(self).mouse_mode
	_pause_menu.open(_pause_info_line())
	# In co-op the camp goes on for the other warden: the menu is only over your view.
	get_tree().paused = not INSTANCE.coop(self).is_active()


## P or F10 (PauseKeys, first to hear any key): the menu in a room or a job too, where Esc
## leaves. P is a letter while you sit at a computer; F10 is not.
func pause_key(key: int) -> bool:
	if key == KEY_P and _keyboard_taken():
		return false
	if _pause_menu != null and _pause_menu.is_open():
		_close_pause_menu(true)
		return true
	if not _can_pause_now():
		return false
	_open_pause_menu()
	return true


func _keyboard_taken() -> bool:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi != null and bool(bi.get("_crt_active")):
		return true
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


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
	_screen.add_child(_pause_menu)
	_pause_menu.resume_requested.connect(func() -> void: _close_pause_menu(true))
	_pause_menu.save_requested.connect(_on_pause_save_requested)
	_pause_menu.quit_to_title_requested.connect(_on_pause_quit_requested)
	var keys := PAUSE_KEYS_SCRIPT.new()
	keys.set("main", self)
	_screen.add_child.call_deferred(keys)


func _close_pause_menu(recapture_mouse: bool) -> void:
	if _pause_menu == null or not _pause_menu.is_open():
		return
	_pause_menu.close()
	get_tree().paused = false
	if recapture_mouse:
		INSTANCE.input(self).set_mouse_mode(_pause_prev_mouse)


## Each piece looked up on its own: put together first, the lookup found the first piece
## only (playtest 1. 11.: "DEN 2   03:15   WITH GRIMROOT").
func _pause_info_line() -> String:
	var line := LANG.f("DAY %d   %s", [maxi(1, _day_index), _time_of_day_string()])
	var saved := _last_save_unix()
	if saved > 0:
		var ago := int(Time.get_unix_time_from_system()) - saved
		if ago < 90:
			line += LANG.f("   SAVED JUST NOW")
		elif ago < 3600:
			line += LANG.f("   SAVED %d MIN AGO", [ago / 60])
		else:
			line += LANG.f("   SAVED %d H AGO", [ago / 3600])
	# Co-op: who you are with, or (the host alone) where the other can call in.
	if INSTANCE.coop(self).has_partner():
		line += LANG.f("   WITH %s", [_coop_camp.names_said().to_upper()])
	elif INSTANCE.coop(self).is_host():
		var here: Array[String] = INSTANCE.coop(self).local_addresses()
		if not here.is_empty():
			line += LANG.f("   OPEN AT %s", [here[0]])
	return line


func _last_save_unix() -> int:
	if _active_save_path.is_empty():
		return 0
	return int(FileAccess.get_modified_time(_active_save_path))


func _on_pause_save_requested() -> void:
	var path := request_manual_save()
	if path.is_empty():
		_pause_menu.set_info(LANG.t("SAVE FAILED"))
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
