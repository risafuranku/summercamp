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
const VISUAL_MODULE_SCRIPT = preload("res://modules/visual/visual_module.gd")
const LEGACY_UI_ADAPTER_SCRIPT = preload("res://modules/adapters/legacy_ui_adapter.gd")
const TIME_SYSTEM_SCRIPT = preload("res://core/systems/time_system.gd")
const WEATHER_SYSTEM_SCRIPT = preload("res://core/systems/weather_system.gd")
const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")
const WEATHER_VISUALS_SCRIPT = preload("res://scripts/weather_visuals.gd")
const HUD_MANAGER_SCRIPT = preload("res://scripts/hud_manager.gd")
const GUEST_AGENTS_SCRIPT = preload("res://scripts/guest_agents.gd")
const QUEST_MANAGER_SCRIPT = preload("res://scripts/quest_manager.gd")
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
const MENU_FPV_SPEED := 9.2
const MENU_FPV_HEIGHT := 2.9
const MENU_FPV_LOOK_HEIGHT := 2.8
const MENU_FPV_BOB_AMPLITUDE := 0.22
const MENU_FPV_BANK_MAX_RAD := 0.16
const MENU_FPV_DRIFT_STRENGTH := 1.25
const MENU_FPV_LOOK_AHEAD := 0.18
const MENU_FPV_STEER_LERP := 3.2
const MENU_FPV_REFRESH_SEC := 9.0

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
const DAMAGE_BLOOD_CHUNK_COUNTS := [6, 12, 18, 28, 40]
const DAMAGE_BLOOD_SPREAD := [0.30, 0.45, 0.62, 0.86, 1.08]
const DAMAGE_BLOOD_FADE_DELAY_SEC: float = 180.0
const DAMAGE_BLOOD_FADE_DURATION_SEC: float = 34.0
const DAMAGE_BLOOD_RAY_DISTANCE: float = 11.5
const DAMAGE_BLOOD_CHUNK_SPEED_MIN: float = 12.0
const DAMAGE_BLOOD_CHUNK_SPEED_MAX: float = 24.0
const DAMAGE_BLOOD_PROJECTILE_GRAVITY: float = 34.0
const DAMAGE_BLOOD_PROJECTILE_DRAG: float = 1.15
const DAMAGE_BLOOD_PROJECTILE_LIFETIME_SEC: float = 1.35
const DAMAGE_BLOOD_SPAWN_BUDGET_PER_FRAME: int = 8
const DAMAGE_BLOOD_MAX_DECALS: int = 260
const LAMP_FLASHLIGHT_START_HOUR: float = 19.5
const GAME_OVER_FALL_DELAY_FALLBACK_SEC: float = 1.2
const GAME_OVER_REASON_DEATH := "death"
const GAME_OVER_REASON_UPS := "ups_power_loss"
const INTERACT_DISTANCE: float = 3.4
const FIRST_PERSON_CAMERA_FAR: float = 1000.0
const LIMINAL_ARCHETYPE_QUIET_GUY := "quiet_guy"
const ELECTRICITY_BILL_ISSUE_HOUR: int = BALANCE_CONFIG.NIGHT_START_HOUR
const ELECTRICITY_BILL_ISSUE_MINUTE: int = 0
const ELECTRICITY_BILL_GRACE_DAYS: int = 3
const ELECTRICITY_PRICE_PER_KWH: float = 2.2
const ELECTRICITY_KWH_PER_POWER_UNIT: float = 3.0
const ELECTRICITY_DAILY_BASE_FEE: int = 12
const ELECTRICITY_UPS_DURATION_SEC: float = 360.0
const ELECTRICITY_BILL_NOTICE_SENDER := "CampGrid Energy Billing <billing@campgrid.local>"
const ELECTRICITY_BILL_NOTICE_TEMPLATES: Array[Dictionary] = [
	{
		"subject": "Electricity invoice {bill_id} issued - due Day {due_day}",
		"body": "Hello reception,\n\nYour electricity invoice {bill_id} for service day {service_day} is now posted.\nAmount due: {amount_usd}.\nPayment deadline: Day {due_day} before {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Payment reminder: {amount_usd} due for {bill_id}",
		"body": "Billing notice,\n\nWe generated invoice {bill_id}.\nOutstanding amount: {amount_usd}.\nPlease settle by Day {due_day} before {issue_time} to avoid interruption.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Camp power account update - invoice {bill_id}",
		"body": "Reception team,\n\nService day {service_day} usage has been billed under {bill_id}.\nTotal due now: {amount_usd}.\nDue date: Day {due_day} ({grace_days}-day window).\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Billing alert: Day {service_day} electricity charge ready",
		"body": "Automated advisory,\n\nInvoice {bill_id} is available in your camp account.\nAmount: {amount_usd}.\nPlease pay before Day {due_day} at {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Utility invoice {bill_id} now open",
		"body": "Hello,\n\nA new utility invoice has been posted.\nInvoice ID: {bill_id}\nAmount due: {amount_usd}\nDeadline: Day {due_day} before {issue_time}\n\nCampGrid Energy Billing",
	},
	{
		"subject": "CampGrid notice: electricity due on Day {due_day}",
		"body": "Reception,\n\nThis is a scheduled evening billing notice.\nInvoice {bill_id} totals {amount_usd} for service day {service_day}.\nPlease process payment no later than Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Invoice queued: {bill_id} ({amount_usd})",
		"body": "System message,\n\nInvoice {bill_id} was queued to your mailbox.\nCurrent amount payable: {amount_usd}.\nGrace period ends on Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Evening utility statement - {bill_id}",
		"body": "Hello reception,\n\nYour evening electricity statement has been finalized.\nReference: {bill_id}\nService day: {service_day}\nDue amount: {amount_usd}\nPay by Day {due_day} before {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Action required: settle electricity invoice {bill_id}",
		"body": "Camp operations,\n\nPlease review and pay invoice {bill_id}.\nBalance due: {amount_usd}.\nDeadline for payment: Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Grid account billing event - {bill_id}",
		"body": "Automated account event,\n\nElectricity billing for day {service_day} has posted.\nInvoice number: {bill_id}\nAmount due: {amount_usd}\nPayment due: Day {due_day} ({issue_time}).\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Power service invoice posted ({bill_id})",
		"body": "Reception desk,\n\nWe posted a new power service invoice.\nID: {bill_id}\nTotal: {amount_usd}\nPlease settle before Day {due_day} to keep account current.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Outstanding utility balance notice: {amount_usd}",
		"body": "Reminder,\n\nInvoice {bill_id} entered unpaid status.\nAmount currently due: {amount_usd}.\nLast day to pay without penalty: Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Service day {service_day} consumption invoiced",
		"body": "Hello,\n\nConsumption for service day {service_day} has been converted to invoice {bill_id}.\nBalance: {amount_usd}.\nDue date: Day {due_day} before {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Camp energy billing cycle closed - invoice ready",
		"body": "Operations update,\n\nThe latest billing cycle is closed.\nInvoice: {bill_id}\nAmount due: {amount_usd}\nGrace period: {grace_days} day(s), ending Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Notice of payable electricity charges ({bill_id})",
		"body": "Reception,\n\nThis notice confirms payable electricity charges.\nInvoice ID: {bill_id}\nService day: {service_day}\nTotal due: {amount_usd}\nPayment deadline: Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Invoice {bill_id}: utility payment window active",
		"body": "Billing center notice,\n\nYour payment window is now active for invoice {bill_id}.\nAmount: {amount_usd}.\nPlease complete payment by Day {due_day} at {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "CampGrid account message - new electricity amount due",
		"body": "Hello camp reception,\n\nA new electricity amount is due under invoice {bill_id}.\nCurrent balance: {amount_usd}.\nPlease pay by Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Utility debt prevention reminder ({bill_id})",
		"body": "Preventive reminder,\n\nInvoice {bill_id} is pending in your account.\nTotal due: {amount_usd}.\nSettle by Day {due_day} to avoid overdue status.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Electricity ledger entry created for Day {service_day}",
		"body": "Ledger update,\n\nA new ledger entry has been created as invoice {bill_id}.\nPayable amount: {amount_usd}.\nDue on Day {due_day} before {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Final evening notice: invoice {bill_id} awaiting payment",
		"body": "Evening dispatch,\n\nInvoice {bill_id} was added to your unpaid list.\nAmount due now: {amount_usd}.\nDeadline remains Day {due_day}.\n\nCampGrid Energy Billing",
	},
]
var _time_state: int = TIME_DAY
var _time_of_day_hours: float = 9.0
var _day_index: int = 1
var _weather_state: int = WEATHER_CLEAR
var _utility_repair_minigame
var _sewer_pipe_minigame
var _texture_style
var _audio_manager

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
var _menu_flythrough_points: Array[Vector3] = []
var _menu_flythrough_segment: int = 0
var _menu_flythrough_segment_t: float = 0.0
var _menu_flythrough_refresh: float = 0.0
var _menu_camera_heading: Vector3 = Vector3.FORWARD
var _menu_camera_bank: float = 0.0
var _pending_loaded_player_state: Dictionary = {}
var _pending_loaded_crt_state: Dictionary = {}
var _last_known_crt_desktop_state: Dictionary = {}
var _boot_screen: CanvasLayer
var _player_health: int = PLAYER_MAX_HEALTH
var _blood_fx_root: Node3D
var _blood_decal_nodes: Array[Node3D] = []
var _active_blood_projectiles: Array[Dictionary] = []
var _pending_blood_projectiles: Array[Dictionary] = []
var _blood_texture_cache: Texture2D
var _blood_chunk_material_cache: StandardMaterial3D
var _blood_decal_material_cache: StandardMaterial3D
var _blood_rng := RandomNumberGenerator.new()
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
var _active_enemy_spawned_this_night: int = 0
var _lamp_flashlight_active: bool = false
var _lamp_grid_power_available: bool = true
var _electricity_bills: Array[Dictionary] = []
var _electricity_last_billed_service_day: int = 0
var _electricity_notice_template_cursor: int = 0
var _electricity_power_cut_active: bool = false
var _electricity_ups_active: bool = false
var _electricity_ups_seconds_left: float = ELECTRICITY_UPS_DURATION_SEC


func _ready() -> void:
	# config/name stays "icloud ccs2": it names the user:// folder that holds saves.
	DisplayServer.window_set_title(WINDOW_TITLE)
	_apply_integer_canvas_scale()
	get_tree().root.size_changed.connect(_apply_integer_canvas_scale)
	_blood_rng.randomize()
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
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(false)
	_ensure_hud_manager()
	_bind_or_create_managers()

	if legacy_ui_adapter == null:
		legacy_ui_adapter = LEGACY_UI_ADAPTER_SCRIPT.new()
		legacy_ui_adapter.name = "LegacyUIAdapter"
		add_child(legacy_ui_adapter)

	_setup_interior_manager()
	_setup_interaction_controller()
	_setup_quest_manager()
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


func _talk_to_guest(info: Dictionary) -> void:
	if _quest_manager != null:
		_quest_manager.notify("talked_to_guest", info)
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
		weather_system.process(delta)
	_sync_runtime_state_from_systems()
	if _weather_visuals != null:
		_weather_visuals.update_state(_time_state, _time_of_day_hours, _weather_state)
		_weather_visuals.update_frame(delta)

	if _menu_mode:
		_update_menu_cinematic_camera(delta)
		return

	_process_electricity_runtime(delta)

	if _liminal_debug_visible:
		_liminal_debug_refresh_accum += maxf(delta, 0.0)
		if _liminal_debug_refresh_accum >= 0.35:
			_liminal_debug_refresh_accum = 0.0
			_refresh_liminal_debug_window()

	if _hud_manager != null:
		_hud_manager.set_world_hud_visible(not _is_any_interior_open())
	_update_player_control_lock()
	if not _is_any_interior_open():
		_sync_active_camera()
	_update_interaction_hint()
	if _audio_manager != null and _audio_manager.has_method("process_runtime"):
		_audio_manager.process_runtime(
			delta,
			_weather_state,
			_is_audio_interior_active(),
			_should_play_rain_inside_loop(),
			_is_service_sewer_audio_active()
		)
	_tick_active_enemy_brain(delta)
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
	# Layered Esc handling: interiors and the CRT consume Esc in their own _input;
	# whatever reaches here is first-person play, where Esc pauses.
	if event.is_action_pressed("ui_cancel"):
		if not _is_any_interior_open():
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
		if previous_time_state == TIME_NIGHT and _time_state == TIME_DAY:
			_on_day_phase_started()

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
	if UTILITY_REPAIRS_ENABLED:
		_add_key_action("service_repair", KEY_R)
	_add_key_action("service_secret_room", KEY_S)


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
	var entries_any = _liminal_night_roll_snapshot.get("entries", [])
	var entries: Array = entries_any if entries_any is Array else []
	var quiet_entry: Dictionary = {}
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		if str(entry.get("archetype", "")) != LIMINAL_ARCHETYPE_QUIET_GUY:
			continue
		quiet_entry = entry
		break

	var spawned = int(quiet_entry.get("spawned", 0))
	_active_enemy_spawned_this_night = spawned
	if spawned <= 0:
		_stop_active_enemy_brain()
		return

	var claimed_virtual = mini(spawned, _liminal_virtual_enemy_count)
	_liminal_virtual_enemy_count = maxi(0, _liminal_virtual_enemy_count - claimed_virtual)
	var difficulty = _resolve_silent_man_difficulty(quiet_entry)
	_start_silent_man_brain(night_index, difficulty, quiet_entry)


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


func _start_silent_man_brain(night_index: int, difficulty: int, night_entry: Dictionary) -> void:
	_stop_active_enemy_brain()
	var brain = SILENT_MAN_BRAIN_SCRIPT.new()
	if brain == null:
		return
	var seed = int(_liminal_forecast_rng.randi()) ^ (night_index * 7919) ^ (_day_index * 104729) ^ int(Time.get_ticks_msec())
	var refs := {
		"world_root": _world_3d,
		"player": _player,
		"grid_manager": grid_manager,
		"building_manager": building_manager,
		"audio_manager": _audio_manager,
		"damage_callable": Callable(self, "damage_player"),
		"is_night_callable": Callable(self, "_is_enemy_night_active"),
		"allow_actions_callable": Callable(self, "_can_enemy_runtime_actions"),
		"night_entry": night_entry.duplicate(true),
	}
	if brain.has_method("start_night"):
		brain.start_night(seed, difficulty, refs)
	_active_enemy_brain = brain
	_active_enemy_brain_id = "silent_man"


func _tick_active_enemy_brain(delta: float) -> void:
	if _active_enemy_brain == null:
		return
	if not is_instance_valid(_active_enemy_brain):
		_active_enemy_brain = null
		_active_enemy_brain_id = ""
		return
	if _active_enemy_brain.has_method("tick"):
		_active_enemy_brain.tick(delta)


func _stop_active_enemy_brain() -> void:
	if _active_enemy_brain == null:
		_active_enemy_brain_id = ""
		return
	if is_instance_valid(_active_enemy_brain) and _active_enemy_brain.has_method("stop_night"):
		_active_enemy_brain.stop_night()
	_active_enemy_brain = null
	_active_enemy_brain_id = ""


func _is_enemy_night_active() -> bool:
	return _gameplay_started and not _menu_mode and not _game_over_active and _time_state == TIME_NIGHT


func _can_enemy_runtime_actions() -> bool:
	if not _is_enemy_night_active():
		return false
	if _is_any_interior_open():
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	return true


func _on_day_phase_started() -> void:
	if not _gameplay_started or _menu_mode:
		return
	_stop_active_enemy_brain()
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
	var camera := _get_player_camera()
	if camera == null:
		return
	_ensure_blood_fx_root()
	var tier_idx = clampi(tier, DAMAGE_TIER_SMALL, DAMAGE_TIER_LETHAL)
	var chunk_count = int(DAMAGE_BLOOD_CHUNK_COUNTS[tier_idx])
	if fatal_hit:
		chunk_count += 10
	for _i in range(chunk_count):
		_spawn_single_blood_chunk(camera, tier_idx)


func _spawn_single_blood_chunk(camera: Camera3D, tier_idx: int) -> void:
	if _blood_fx_root == null or not is_instance_valid(_blood_fx_root):
		return
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var spread := float(DAMAGE_BLOOD_SPREAD[tier_idx])
	var direction = (
		forward * _blood_rng.randf_range(0.35, 1.0)
		+ right * _blood_rng.randf_range(-spread, spread)
		+ up * _blood_rng.randf_range(-0.38, 0.54 + spread * 0.2)
	).normalized()
	if direction.length_squared() < 0.0001:
		direction = forward

	var origin = camera.global_transform.origin + forward * 0.18 + up * -0.05
	var hit = _raycast_blood_target(origin, direction)
	var target_pos = origin + direction * _blood_rng.randf_range(2.4, 4.8)
	var target_normal = Vector3.UP
	if not hit.is_empty():
		target_pos = hit.get("position", target_pos)
		var hit_normal_any = hit.get("normal", Vector3.UP)
		if hit_normal_any is Vector3:
			target_normal = (hit_normal_any as Vector3).normalized()
		if target_normal.length_squared() < 0.0001:
			target_normal = Vector3.UP

	var chunk_root := Node3D.new()
	chunk_root.name = "BloodChunk"
	chunk_root.global_position = origin
	_blood_fx_root.add_child(chunk_root)

	var chunk_mesh := MeshInstance3D.new()
	var chunk_box := BoxMesh.new()
	var chunk_size = _blood_rng.randf_range(0.010, 0.028) * (1.0 + float(tier_idx) * 0.20)
	chunk_box.size = Vector3.ONE * chunk_size
	chunk_mesh.mesh = chunk_box
	chunk_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_mesh.material_override = _make_blood_chunk_material()
	chunk_root.add_child(chunk_mesh)

	var speed = _blood_rng.randf_range(DAMAGE_BLOOD_CHUNK_SPEED_MIN, DAMAGE_BLOOD_CHUNK_SPEED_MAX)
	var duration = clampf(origin.distance_to(target_pos) / maxf(speed, 0.01), 0.08, 0.34)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(chunk_root, "global_position", target_pos, duration)
	tween.finished.connect(func():
		if not is_instance_valid(chunk_root):
			return
		_spawn_blood_decal(target_pos, target_normal, tier_idx)
		chunk_root.queue_free()
	)


func _raycast_blood_target(origin: Vector3, direction: Vector3) -> Dictionary:
	if _world_3d == null or _world_3d.get_world_3d() == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * DAMAGE_BLOOD_RAY_DISTANCE)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude: Array = []
	if _player != null and is_instance_valid(_player):
		exclude.append(_player.get_rid())
	query.exclude = exclude
	return _world_3d.get_world_3d().direct_space_state.intersect_ray(query)


func _spawn_blood_decal(hit_pos: Vector3, normal: Vector3, tier_idx: int) -> void:
	if _blood_fx_root == null or not is_instance_valid(_blood_fx_root):
		return
	_cleanup_blood_decal_refs()
	while _blood_decal_nodes.size() >= DAMAGE_BLOOD_MAX_DECALS:
		var oldest = _blood_decal_nodes.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

	var n = normal.normalized()
	if n.length_squared() < 0.0001:
		n = Vector3.UP

	var decal_root := Node3D.new()
	decal_root.name = "BloodDecal"
	decal_root.global_position = hit_pos + n * 0.012
	var up_hint := Vector3.UP
	if absf(n.dot(up_hint)) > 0.94:
		up_hint = Vector3.FORWARD
	decal_root.look_at(decal_root.global_position + n, up_hint, true)
	decal_root.rotate_object_local(Vector3.FORWARD, _blood_rng.randf_range(-PI, PI))
	_blood_fx_root.add_child(decal_root)

	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var base_size = 0.12 + (float(tier_idx) * 0.07)
	var sx = base_size * _blood_rng.randf_range(0.72, 1.36)
	var sy = base_size * _blood_rng.randf_range(0.64, 1.28)
	quad.size = Vector2(sx, sy)
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var decal_mat := _make_blood_decal_material()
	var decal_alpha := _blood_rng.randf_range(0.74, 1.0)
	if decal_mat != null:
		var decal_col = decal_mat.albedo_color
		decal_col.a = decal_alpha
		decal_mat.albedo_color = decal_col
	mesh.material_override = decal_mat
	mesh.transparency = 0.0
	decal_root.add_child(mesh)
	_blood_decal_nodes.append(decal_root)

	var fade_tween = decal_root.create_tween()
	fade_tween.tween_interval(DAMAGE_BLOOD_FADE_DELAY_SEC)
	fade_tween.tween_property(mesh, "transparency", 1.0, DAMAGE_BLOOD_FADE_DURATION_SEC)
	fade_tween.finished.connect(func():
		if is_instance_valid(decal_root):
			decal_root.queue_free()
	)


func _ensure_blood_fx_root() -> void:
	if _world_3d == null:
		return
	if _blood_fx_root != null and is_instance_valid(_blood_fx_root):
		return
	_blood_fx_root = Node3D.new()
	_blood_fx_root.name = "BloodFxRoot"
	_world_3d.add_child(_blood_fx_root)


func _clear_blood_fx() -> void:
	_blood_decal_nodes.clear()
	if _blood_fx_root != null and is_instance_valid(_blood_fx_root):
		_blood_fx_root.queue_free()
	_blood_fx_root = null


func _cleanup_blood_decal_refs() -> void:
	var live: Array[Node3D] = []
	for decal in _blood_decal_nodes:
		if decal != null and is_instance_valid(decal):
			live.append(decal)
	_blood_decal_nodes = live


func _make_blood_chunk_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.62, 0.04, 0.04, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _make_blood_decal_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _get_or_create_blood_texture()
	mat.albedo_color = Color(0.72, 0.05, 0.05, 0.98)
	mat.emission_enabled = true
	mat.emission = Color(0.24, 0.0, 0.0, 1.0)
	mat.emission_energy_multiplier = 0.26
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _get_or_create_blood_texture() -> Texture2D:
	if _blood_texture_cache != null:
		return _blood_texture_cache
	_blood_texture_cache = _build_pixel_blood_texture()
	return _blood_texture_cache


func _build_pixel_blood_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var local_rng := RandomNumberGenerator.new()
	local_rng.randomize()
	var center := Vector2(15.5, 15.5)
	for y in range(32):
		for x in range(32):
			var p := Vector2(float(x), float(y))
			var dist = p.distance_to(center) / 16.0
			var threshold = 0.28 + local_rng.randf_range(0.0, 0.62)
			if dist > threshold:
				continue
			if local_rng.randf() < 0.18 and dist > 0.35:
				continue
			var shade = local_rng.randf_range(0.0, 0.22)
			var alpha = clampf(1.0 - dist + local_rng.randf_range(-0.16, 0.22), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.78 - shade, 0.03, 0.03, alpha))
	return ImageTexture.create_from_image(img)


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


func _sync_active_camera() -> void:
	if _player == null:
		fallback_camera.current = true
		return

	var player_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	if player_camera != null:
		player_camera.current = true
		player_camera.far = FIRST_PERSON_CAMERA_FAR
		player_camera.near = 0.08
		player_camera.fov = 44.0
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
	if _hud_manager != null: _hud_manager.update_time(_time_of_day_string(), _day_index)
	_sync_liminal_forecast_hud()
	_refresh_liminal_debug_window()
	_emit_state_update()


func _process_electricity_runtime(delta: float) -> void:
	if not _gameplay_started or _menu_mode:
		return
	_issue_pending_electricity_bills()
	_refresh_electricity_power_cut_state()
	if _electricity_power_cut_active:
		if not _electricity_ups_active:
			_electricity_ups_active = true
			_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC
		_electricity_ups_seconds_left = maxf(0.0, _electricity_ups_seconds_left - maxf(delta, 0.0))
		if _electricity_ups_seconds_left <= 0.0 and not _game_over_active:
			_trigger_game_over(GAME_OVER_REASON_UPS)
		return
	if _electricity_ups_active or _electricity_ups_seconds_left < ELECTRICITY_UPS_DURATION_SEC:
		_electricity_ups_active = false
		_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC


func _issue_pending_electricity_bills() -> void:
	var minute_of_day := _clock_minutes_from_hours(_time_of_day_hours)
	var issue_minute := _electricity_issue_minute_of_day()
	if minute_of_day < issue_minute:
		return
	var target_service_day := _day_index - 1
	while _electricity_last_billed_service_day < target_service_day:
		var service_day := _electricity_last_billed_service_day + 1
		if service_day <= 0:
			_electricity_last_billed_service_day = service_day
			continue
		_create_electricity_bill_for_day(service_day)
		_electricity_last_billed_service_day = service_day
		_emit_state_update()


func _electricity_issue_minute_of_day() -> int:
	return (ELECTRICITY_BILL_ISSUE_HOUR * 60) + ELECTRICITY_BILL_ISSUE_MINUTE


func _electricity_days_left_until_due(due_day: int) -> int:
	var days_left := due_day - _day_index
	if days_left == 0:
		var minute_of_day := _clock_minutes_from_hours(_time_of_day_hours)
		if minute_of_day >= _electricity_issue_minute_of_day():
			return -1
	return days_left


func _create_electricity_bill_for_day(service_day: int) -> void:
	var lines := _collect_electricity_consumption_lines()
	var total_kwh := 0.0
	var energy_charge := 0
	var bill_lines: Array[Dictionary] = []
	for line in lines:
		total_kwh += float(line.get("kwh_per_day", 0.0))
		energy_charge += int(line.get("cost_per_day", 0))
		var power_units := int(line.get("power_units", 0))
		if power_units <= 0:
			continue
		bill_lines.append({
			"building_type": str(line.get("building_type", "")),
			"label": str(line.get("label", "Unknown")),
			"coord": _coord_to_save_dict(line.get("coord", Vector2i.ZERO)),
			"power_units": power_units,
			"kwh_per_day": snappedf(float(line.get("kwh_per_day", 0.0)), 0.1),
			"cost_per_day": int(line.get("cost_per_day", 0)),
		})
	var base_fee := ELECTRICITY_DAILY_BASE_FEE if total_kwh > 0.001 else 0
	var total_amount: int = maxi(0, energy_charge + base_fee)
	var issue_time := "%02d:%02d" % [ELECTRICITY_BILL_ISSUE_HOUR, ELECTRICITY_BILL_ISSUE_MINUTE]
	var issued_day := _day_index
	var bill := {
		"id": "elec_day_%d" % service_day,
		"service_day": service_day,
		"issued_day": issued_day,
		"issued_time": issue_time,
		"due_day": issued_day + ELECTRICITY_BILL_GRACE_DAYS,
		"status": "unpaid",
		"amount": total_amount,
		"rate_per_kwh": ELECTRICITY_PRICE_PER_KWH,
		"base_fee": base_fee,
		"kwh_total": snappedf(total_kwh, 0.1),
		"line_items": bill_lines,
	}
	_electricity_bills.append(bill)
	_queue_electricity_due_notice_email(bill)


func _queue_electricity_due_notice_email(bill: Dictionary) -> void:
	if EmailManager == null or not EmailManager.has_method("push_system_mail"):
		return
	var template := _next_electricity_notice_template()
	if template.is_empty():
		return
	var issue_day: int = maxi(1, int(bill.get("issued_day", _day_index)))
	var service_day: int = maxi(1, int(bill.get("service_day", issue_day)))
	var due_day: int = maxi(issue_day, int(bill.get("due_day", issue_day + ELECTRICITY_BILL_GRACE_DAYS)))
	var issue_time := str(bill.get("issued_time", "%02d:%02d" % [ELECTRICITY_BILL_ISSUE_HOUR, ELECTRICITY_BILL_ISSUE_MINUTE])).strip_edges()
	if issue_time.is_empty():
		issue_time = "%02d:%02d" % [ELECTRICITY_BILL_ISSUE_HOUR, ELECTRICITY_BILL_ISSUE_MINUTE]
	var amount := maxi(0, int(bill.get("amount", 0)))
	var bill_id := str(bill.get("id", "elec_day_%d" % service_day)).strip_edges()
	var placeholders := {
		"bill_id": bill_id,
		"service_day": str(service_day),
		"issued_day": str(issue_day),
		"issue_time": issue_time,
		"due_day": str(due_day),
		"grace_days": str(ELECTRICITY_BILL_GRACE_DAYS),
		"amount": str(amount),
		"amount_usd": "$%d" % amount,
	}
	var subject_template := str(template.get("subject", "Electricity invoice {bill_id} issued"))
	var body_template := str(template.get("body", "Invoice {bill_id} is due on Day {due_day}."))
	EmailManager.push_system_mail({
		"sender": ELECTRICITY_BILL_NOTICE_SENDER,
		"from": ELECTRICITY_BILL_NOTICE_SENDER,
		"subject": _format_electricity_notice_template(subject_template, placeholders),
		"body": _format_electricity_notice_template(body_template, placeholders),
		"day": issue_day,
		"time": issue_time,
		"type": "system",
		"category": "electricity_billing",
		"bill_id": bill_id,
		"amount": amount,
		"due_day": due_day,
	})


func _next_electricity_notice_template() -> Dictionary:
	if ELECTRICITY_BILL_NOTICE_TEMPLATES.is_empty():
		return {}
	_electricity_notice_template_cursor = _coerce_electricity_notice_cursor(_electricity_notice_template_cursor)
	var template_any = ELECTRICITY_BILL_NOTICE_TEMPLATES[_electricity_notice_template_cursor]
	_electricity_notice_template_cursor = _coerce_electricity_notice_cursor(_electricity_notice_template_cursor + 1)
	if template_any is Dictionary:
		return (template_any as Dictionary).duplicate(true)
	return {}


func _coerce_electricity_notice_cursor(value: int) -> int:
	var template_count := ELECTRICITY_BILL_NOTICE_TEMPLATES.size()
	if template_count <= 0:
		return 0
	return posmod(value, template_count)


func _format_electricity_notice_template(template_text: String, placeholders: Dictionary) -> String:
	var out := template_text
	for key_any in placeholders.keys():
		var key := str(key_any).strip_edges()
		if key.is_empty():
			continue
		out = out.replace("{%s}" % key, str(placeholders.get(key_any, "")))
	return out


func _collect_electricity_consumption_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if economy_manager == null or not economy_manager.has_method("get_power_draw_breakdown"):
		return lines
	var raw_any = economy_manager.get_power_draw_breakdown()
	if not (raw_any is Array):
		return lines
	var raw_lines := raw_any as Array
	for line_any in raw_lines:
		if not (line_any is Dictionary):
			continue
		var raw_line := line_any as Dictionary
		var power_units: int = maxi(0, int(raw_line.get("power_use", 0)))
		if power_units <= 0:
			continue
		var kwh := float(power_units) * ELECTRICITY_KWH_PER_POWER_UNIT
		var cost := int(round(kwh * ELECTRICITY_PRICE_PER_KWH))
		lines.append({
			"building_type": str(raw_line.get("type", "")),
			"label": str(raw_line.get("label", "Unknown")),
			"coord": _coord_from_variant(raw_line.get("coord", Vector2i.ZERO), Vector2i.ZERO),
			"power_units": power_units,
			"kwh_per_day": snappedf(kwh, 0.1),
			"cost_per_day": cost,
		})
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap = int(a.get("power_units", 0))
		var bp = int(b.get("power_units", 0))
		if ap == bp:
			return str(a.get("label", "")) < str(b.get("label", ""))
		return ap > bp
	)
	return lines


func _refresh_electricity_power_cut_state(force_apply: bool = false) -> void:
	var now_cut := _has_overdue_electricity_bill()
	var changed := now_cut != _electricity_power_cut_active
	_electricity_power_cut_active = now_cut
	if _electricity_power_cut_active:
		if changed:
			_electricity_ups_active = true
			_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC
	else:
		_electricity_ups_active = false
		_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC
	if changed or force_apply:
		if GuestManager != null and GuestManager.has_method("set_camp_power_available"):
			GuestManager.set_camp_power_available(not _electricity_power_cut_active)
		_apply_time_from_clock(true, false)
		_emit_state_update()


func _has_overdue_electricity_bill() -> bool:
	for bill_any in _electricity_bills:
		if not (bill_any is Dictionary):
			continue
		var bill := bill_any as Dictionary
		if str(bill.get("status", "unpaid")) == "paid":
			continue
		var due_day := int(bill.get("due_day", _day_index))
		if _electricity_days_left_until_due(due_day) < 0:
			return true
	return false


func _count_overdue_electricity_bills() -> int:
	var count := 0
	for bill_any in _electricity_bills:
		if not (bill_any is Dictionary):
			continue
		var bill := bill_any as Dictionary
		if str(bill.get("status", "unpaid")) == "paid":
			continue
		var due_day := int(bill.get("due_day", _day_index))
		if _electricity_days_left_until_due(due_day) < 0:
			count += 1
	return count


func get_electricity_ui_snapshot() -> Dictionary:
	var lines := _collect_electricity_consumption_lines()
	var total_kwh := 0.0
	var energy_charge := 0
	for line in lines:
		total_kwh += float(line.get("kwh_per_day", 0.0))
		energy_charge += int(line.get("cost_per_day", 0))
	var base_fee := ELECTRICITY_DAILY_BASE_FEE if total_kwh > 0.001 else 0
	var daily_total_cost: int = maxi(0, energy_charge + base_fee)

	var bills: Array[Dictionary] = []
	var unpaid_total := 0
	var overdue_total := 0
	var unpaid_count := 0
	var overdue_count := 0
	for i in range(_electricity_bills.size() - 1, -1, -1):
		var bill_any = _electricity_bills[i]
		if not (bill_any is Dictionary):
			continue
		var bill := bill_any as Dictionary
		var status := str(bill.get("status", "unpaid")).to_lower().strip_edges()
		if status == "paid":
			continue
		var amount: int = maxi(0, int(bill.get("amount", 0)))
		var due_day := int(bill.get("due_day", _day_index))
		var days_left := _electricity_days_left_until_due(due_day)
		var is_overdue := days_left < 0
		unpaid_total += amount
		unpaid_count += 1
		if is_overdue:
			overdue_total += amount
			overdue_count += 1
		bills.append({
			"id": str(bill.get("id", "")),
			"service_day": int(bill.get("service_day", 0)),
			"issued_day": int(bill.get("issued_day", 0)),
			"issued_time": str(bill.get("issued_time", "%02d:%02d" % [ELECTRICITY_BILL_ISSUE_HOUR, ELECTRICITY_BILL_ISSUE_MINUTE])),
			"due_day": due_day,
			"status": status,
			"amount": amount,
			"kwh_total": snappedf(float(bill.get("kwh_total", 0.0)), 0.1),
			"days_left": days_left,
			"is_overdue": is_overdue,
			"line_items": _duplicate_dict_array(bill.get("line_items", [])),
		})

	return {
		"day": _day_index,
		"time": _time_of_day_string(),
		"rate_per_kwh": ELECTRICITY_PRICE_PER_KWH,
		"kwh_per_power_unit": ELECTRICITY_KWH_PER_POWER_UNIT,
		"base_fee": base_fee,
		"daily_kwh_total": snappedf(total_kwh, 0.1),
		"daily_cost_energy": energy_charge,
		"daily_cost_total": daily_total_cost,
		"consumption_lines": lines,
		"bills": bills,
		"unpaid_total": unpaid_total,
		"overdue_total": overdue_total,
		"unpaid_count": unpaid_count,
		"overdue_count": overdue_count,
		"power_cut_active": _electricity_power_cut_active,
		"ups_active": _electricity_ups_active and _electricity_power_cut_active,
		"ups_seconds_left": snappedf(_electricity_ups_seconds_left, 0.1),
		"bill_grace_days": ELECTRICITY_BILL_GRACE_DAYS,
		"bill_issue_hour": ELECTRICITY_BILL_ISSUE_HOUR,
		"bill_issue_minute": ELECTRICITY_BILL_ISSUE_MINUTE,
	}


func request_pay_electricity_bill(bill_id: String) -> Dictionary:
	var trimmed_id := bill_id.strip_edges()
	if trimmed_id.is_empty():
		return {"ok": false, "reason": "invalid_bill"}
	for i in _electricity_bills.size():
		var bill_any = _electricity_bills[i]
		if not (bill_any is Dictionary):
			continue
		var bill := bill_any as Dictionary
		if str(bill.get("id", "")) != trimmed_id:
			continue
		if str(bill.get("status", "unpaid")) == "paid":
			return {"ok": false, "reason": "already_paid"}
		var amount: int = maxi(0, int(bill.get("amount", 0)))
		if amount > 0:
			if CoreRoot.actions == null or not CoreRoot.actions.has_method("spend_money"):
				return {"ok": false, "reason": "money_system_missing"}
			if not CoreRoot.actions.spend_money(amount):
				return {"ok": false, "reason": "insufficient_funds", "amount": amount}
		_electricity_bills.remove_at(i)
		_refresh_electricity_power_cut_state(true)
		return {"ok": true, "amount": amount}
	return {"ok": false, "reason": "not_found"}


func _apply_time_from_clock(force_interior_sync: bool = false, force_sky_snap: bool = false) -> void:
	var state_changed = force_interior_sync
	var is_night = (_time_state == TIME_NIGHT)
	var lamp_and_flashlight_active = _is_hour_in_window(_time_of_day_hours, LAMP_FLASHLIGHT_START_HOUR, float(BALANCE_CONFIG.DAY_START_HOUR))
	var grid_power_available = not _electricity_power_cut_active
	if CoreRoot.is_night() != is_night:
		CoreRoot.apply_changes({"is_night": is_night})
	if state_changed and _time_state == TIME_NIGHT:
		if _interior_manager != null and _interior_manager.has_method("close_main_interior_if_open"):
			_interior_manager.close_main_interior_if_open()
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
			_weather_state,
			_is_audio_interior_active(),
			_should_play_rain_inside_loop(),
			_is_service_sewer_audio_active()
		)
	if _interior_manager != null and _interior_manager.has_method("sync_weather"):
		_interior_manager.sync_weather(_weather_state)
	print("Weather state -> %d" % _weather_state)


func _setup_audio() -> void:
	if _audio_manager != null and is_instance_valid(_audio_manager):
		_audio_manager.queue_free()
	_audio_manager = AUDIO_MANAGER_SCRIPT.new()
	_audio_manager.name = "AudioManager"
	_world_3d.add_child(_audio_manager)
	if _audio_manager.has_method("setup_audio"):
		_audio_manager.setup_audio()


func _try_interact() -> void:
	var guest_in_view := _find_guest_in_view()
	if not guest_in_view.is_empty():
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
	_player.set_controls_enabled(not _is_any_interior_open())

func _update_interaction_hint() -> void:
	if _hud_manager == null:
		return
	if _is_any_interior_open():
		_hud_manager.set_hint_text("")
		return
	var guest_in_view := _find_guest_in_view()
	if not guest_in_view.is_empty():
		_hud_manager.set_hint_text("[E] Talk to %s" % str(guest_in_view.get("name", "guest")))
		return
	if _interaction_controller == null or not _interaction_controller.has_method("build_hint_text"):
		_hud_manager.set_hint_text("")
		return
	_hud_manager.set_hint_text(_interaction_controller.build_hint_text(INTERACT_DISTANCE, UTILITY_REPAIRS_ENABLED))


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
			"power_cut_active": _electricity_power_cut_active,
			"ups_active": _electricity_ups_active and _electricity_power_cut_active,
			"ups_seconds_left": _electricity_ups_seconds_left,
			"overdue_count": _count_overdue_electricity_bills(),
		},
		"liminal_forecast": _liminal_forecast_snapshot.duplicate(true),
	})


func _enter_main_menu() -> void:
	_stop_active_enemy_brain()
	if _quest_manager != null:
		_quest_manager.stop()
	_clear_game_over_screen()
	_game_over_active = false
	_game_over_reason = GAME_OVER_REASON_DEATH
	_electricity_ups_active = false
	_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC
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
	_rebuild_menu_flythrough_path()
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
		_rebuild_menu_flythrough_path()
		return
	var snapshot := SaveManager.read_save(latest)
	if snapshot.is_empty() or not _apply_save_snapshot(snapshot, true):
		_reset_state_for_new_game()
		_generate_grid_world()
		_prune_preview_to_reception_only()
		_rebuild_core_cells_from_visual_structures()
		_rebuild_menu_flythrough_path()
		return
	_active_save_path = latest
	_rebuild_menu_flythrough_path()


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


func _update_menu_cinematic_camera(delta: float) -> void:
	if fallback_camera == null or grid_manager == null:
		return
	fallback_camera.current = true
	fallback_camera.fov = move_toward(fallback_camera.fov, 63.0, maxf(7.0 * delta, 0.0))

	_menu_flythrough_refresh -= maxf(delta, 0.0)
	if _menu_flythrough_points.size() < 2 or _menu_flythrough_refresh <= 0.0:
		_rebuild_menu_flythrough_path()

	if _menu_flythrough_points.size() < 2:
		var center: Vector3 = grid_manager.get_map_center_world()
		fallback_camera.global_position = center + Vector3(0.0, MENU_FPV_HEIGHT + 0.4, -12.0)
		fallback_camera.look_at(center + Vector3(0.0, MENU_FPV_LOOK_HEIGHT, 0.0), Vector3.UP)
		return

	var point_count := _menu_flythrough_points.size()
	var from_idx := clampi(_menu_flythrough_segment, 0, point_count - 1)
	var p0 := _menu_flythrough_points[(from_idx - 1 + point_count) % point_count]
	var p1 := _menu_flythrough_points[from_idx]
	var p2 := _menu_flythrough_points[(from_idx + 1) % point_count]
	var p3 := _menu_flythrough_points[(from_idx + 2) % point_count]
	var segment_len := maxf(p1.distance_to(p2), 1.0)
	_menu_flythrough_segment_t += (MENU_FPV_SPEED / segment_len) * maxf(delta, 0.0)
	while _menu_flythrough_segment_t >= 1.0:
		_menu_flythrough_segment_t -= 1.0
		_menu_flythrough_segment = (_menu_flythrough_segment + 1) % point_count
		from_idx = clampi(_menu_flythrough_segment, 0, point_count - 1)
		p0 = _menu_flythrough_points[(from_idx - 1 + point_count) % point_count]
		p1 = _menu_flythrough_points[from_idx]
		p2 = _menu_flythrough_points[(from_idx + 1) % point_count]
		p3 = _menu_flythrough_points[(from_idx + 2) % point_count]

	var t := _menu_flythrough_segment_t
	var flat_pos := _menu_catmull_position(p0, p1, p2, p3, t)
	var tangent := _menu_catmull_tangent(p0, p1, p2, p3, t)
	var forward_flat := Vector3(tangent.x, 0.0, tangent.z).normalized()
	if forward_flat.length_squared() < 0.001:
		forward_flat = _menu_camera_heading
	else:
		_menu_camera_heading = _menu_camera_heading.slerp(forward_flat, clampf(delta * MENU_FPV_STEER_LERP, 0.0, 1.0)).normalized()
		forward_flat = _menu_camera_heading

	var tangent_ahead := _menu_catmull_tangent(p0, p1, p2, p3, minf(1.0, t + 0.06))
	var ahead_dir := Vector3(tangent_ahead.x, 0.0, tangent_ahead.z).normalized()
	var turn := clampf(forward_flat.cross(ahead_dir).y * 3.2, -1.0, 1.0)
	var target_bank := -turn * MENU_FPV_BANK_MAX_RAD
	_menu_camera_bank = lerpf(_menu_camera_bank, target_bank, clampf(delta * 2.9, 0.0, 1.0))

	var right := forward_flat.cross(Vector3.UP).normalized()
	var drift := right * (_menu_camera_bank * MENU_FPV_DRIFT_STRENGTH)
	var bob := sin((Time.get_ticks_msec() * 0.001) * 1.35 + float(_menu_flythrough_segment) * 0.58) * MENU_FPV_BOB_AMPLITUDE
	var cam_pos := Vector3(flat_pos.x, MENU_FPV_HEIGHT + bob, flat_pos.z) + drift
	fallback_camera.global_position = cam_pos

	var look_t := minf(1.0, t + MENU_FPV_LOOK_AHEAD)
	var look_flat := _menu_catmull_position(p0, p1, p2, p3, look_t)
	var look_pos := Vector3(look_flat.x, MENU_FPV_LOOK_HEIGHT + bob * 0.16, look_flat.z) + (right * (_menu_camera_bank * 0.75))
	fallback_camera.look_at(look_pos, Vector3.UP)
	fallback_camera.rotation.z = lerpf(fallback_camera.rotation.z, _menu_camera_bank, clampf(delta * 4.4, 0.0, 1.0))


func _menu_catmull_position(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var tt := t * t
	var ttt := tt * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * tt
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * ttt
	)


func _menu_catmull_tangent(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var tt := t * t
	return 0.5 * (
		(-p0 + p2)
		+ (4.0 * p0 - 10.0 * p1 + 8.0 * p2 - 2.0 * p3) * t
		+ (-3.0 * p0 + 9.0 * p1 - 9.0 * p2 + 3.0 * p3) * tt
	)


func _rebuild_menu_flythrough_path() -> void:
	if grid_manager == null:
		_menu_flythrough_points.clear()
		return
	var center: Vector3 = grid_manager.get_map_center_world()
	var map_size: Vector2 = grid_manager.get_map_size_world()
	var half_x := maxf(7.5, map_size.x * 0.5 - 7.0)
	var half_z := maxf(7.5, map_size.y * 0.5 - 7.0)
	var points: Array[Vector3] = []

	var structures_root := building_manager.get_node_or_null("Structures") if building_manager != null else null
	if structures_root != null:
		for child in structures_root.get_children():
			var structure := child as Node3D
			if structure == null:
				continue
			var pos := structure.global_position
			var offset := Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))
			points.append(_clamp_menu_fly_point(pos + offset, center, half_x, half_z))

	if points.size() < 6:
		var rows := 8
		for i in range(rows):
			var t := float(i) / float(max(1, rows - 1))
			var z := lerpf(center.z - half_z * 0.76, center.z + half_z * 0.76, t) + randf_range(-3.0, 3.0)
			var x_amp := half_x * (0.68 + randf_range(-0.06, 0.06))
			var x := center.x + (x_amp if i % 2 == 0 else -x_amp) + randf_range(-3.2, 3.2)
			points.append(_clamp_menu_fly_point(Vector3(x, 0.0, z), center, half_x, half_z))

	if points.size() >= 2:
		points.append(points[0])

	_menu_flythrough_points = points
	_menu_flythrough_segment = 0
	_menu_flythrough_segment_t = 0.0
	_menu_flythrough_refresh = MENU_FPV_REFRESH_SEC
	_menu_camera_bank = 0.0
	if points.size() >= 2:
		var init_dir := Vector3(points[1].x - points[0].x, 0.0, points[1].z - points[0].z).normalized()
		if init_dir.length_squared() >= 0.001:
			_menu_camera_heading = init_dir


func _clamp_menu_fly_point(point: Vector3, center: Vector3, half_x: float, half_z: float) -> Vector3:
	return Vector3(
		clampf(point.x, center.x - half_x, center.x + half_x),
		0.0,
		clampf(point.z, center.z - half_z, center.z + half_z)
	)


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
			"guests": _serialize_guests_for_save(state.guests),
			"accommodation_states": _serialize_accommodation_states_for_save(state.accommodation_states),
			"failures": _serialize_failures_for_save(state.failures),
			"guest_reviews": _duplicate_dict_array(state.guest_reviews),
			"guest_transactions": _duplicate_dict_array(state.guest_transactions),
			"next_guest_id": max(1, int(state.next_guest_id)),
			"electricity": _serialize_electricity_state_for_save()
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
		"quests": _quest_manager.export_state() if _quest_manager != null else {}
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


func _serialize_guests_for_save(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for guest_any in value:
		if not (guest_any is Dictionary):
			continue
		var guest := (guest_any as Dictionary).duplicate(true)
		guest["lodging_slots"] = _serialize_lodging_slots_for_save(guest.get("lodging_slots", []))
		out.append(guest)
	return out


func _deserialize_guests_from_save(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for guest_any in value:
		if not (guest_any is Dictionary):
			continue
		var guest := (guest_any as Dictionary).duplicate(true)
		guest["lodging_slots"] = _deserialize_lodging_slots_from_save(guest.get("lodging_slots", []))
		out.append(guest)
	return out


func _serialize_lodging_slots_for_save(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for slot_any in value:
		if not (slot_any is Dictionary):
			continue
		var slot := (slot_any as Dictionary).duplicate(true)
		var accommodation_key := str(slot.get("accommodation_key", slot.get("acc_key", ""))).strip_edges()
		if accommodation_key.is_empty():
			if not slot.has("coord"):
				continue
			var coord_from_slot := _coord_from_variant(slot.get("coord", null), Vector2i.ZERO)
			accommodation_key = _coord_to_key(coord_from_slot)
		if accommodation_key.is_empty():
			continue
		slot["accommodation_key"] = accommodation_key
		slot["coord"] = _coord_to_save_dict(slot.get("coord", Vector2i.ZERO))
		slot["slot_index"] = max(0, int(slot.get("slot_index", 0)))
		slot["building_type"] = str(slot.get("building_type", ""))
		out.append(slot)
	return out


func _deserialize_lodging_slots_from_save(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for slot_any in value:
		if not (slot_any is Dictionary):
			continue
		var slot := (slot_any as Dictionary).duplicate(true)
		slot["accommodation_key"] = str(slot.get("accommodation_key", slot.get("acc_key", ""))).strip_edges()
		slot["coord"] = _coord_from_variant(slot.get("coord", Vector2i.ZERO), Vector2i.ZERO)
		slot["slot_index"] = max(0, int(slot.get("slot_index", 0)))
		slot["building_type"] = str(slot.get("building_type", ""))
		out.append(slot)
	return out


func _serialize_accommodation_states_for_save(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (value is Dictionary):
		return out
	for key_any in (value as Dictionary).keys():
		var key := str(key_any).strip_edges()
		if key.is_empty():
			continue
		var entry_any = (value as Dictionary).get(key_any, {})
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var sanitized_guest_ids: Array = []
		var seen_ids: Dictionary = {}
		var guest_ids_any = entry.get("guest_ids", [])
		if guest_ids_any is Array:
			for id_any in guest_ids_any:
				var guest_id := int(id_any)
				if guest_id <= 0 or seen_ids.has(guest_id):
					continue
				seen_ids[guest_id] = true
				sanitized_guest_ids.append(guest_id)
		out[key] = {
			"status": str(entry.get("status", "clean")).to_lower().strip_edges(),
			"building_type": str(entry.get("building_type", "")),
			"capacity": max(0, int(entry.get("capacity", 0))),
			"guest_ids": sanitized_guest_ids
		}
	return out


func _deserialize_accommodation_states_from_save(value: Variant) -> Dictionary:
	return _serialize_accommodation_states_for_save(value)


func _serialize_failures_for_save(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (value is Dictionary):
		return out
	var src := value as Dictionary
	for key_any in src.keys():
		var key := str(key_any).strip_edges()
		if key.is_empty():
			continue
		var entry_any = src.get(key_any, {})
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var fallback_coord := _coord_from_key_string(key)
		var coord := _coord_from_variant(entry.get("coord", fallback_coord), fallback_coord)
		out[key] = {
			"type": str(entry.get("type", "")),
			"coord": _coord_to_save_dict(coord),
			"since_day": max(1, int(entry.get("since_day", 1))),
			"repair_progress": clampf(float(entry.get("repair_progress", 0.0)), 0.0, 1.0)
		}
	return out


func _deserialize_failures_from_save(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (value is Dictionary):
		return out
	var src := value as Dictionary
	for key_any in src.keys():
		var key := str(key_any).strip_edges()
		if key.is_empty():
			continue
		var entry_any = src.get(key_any, {})
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var fallback_coord := _coord_from_key_string(key)
		var coord := _coord_from_variant(entry.get("coord", fallback_coord), fallback_coord)
		out[key] = {
			"type": str(entry.get("type", "")),
			"coord": coord,
			"since_day": max(1, int(entry.get("since_day", 1))),
			"repair_progress": clampf(float(entry.get("repair_progress", 0.0)), 0.0, 1.0)
		}
	return out


func _serialize_electricity_state_for_save() -> Dictionary:
	return {
		"last_billed_service_day": max(0, _electricity_last_billed_service_day),
		"notice_template_cursor": _coerce_electricity_notice_cursor(_electricity_notice_template_cursor),
		"power_cut_active": _electricity_power_cut_active,
		"ups_active": _electricity_ups_active,
		"ups_seconds_left": clampf(_electricity_ups_seconds_left, 0.0, ELECTRICITY_UPS_DURATION_SEC),
		"bills": _serialize_electricity_bills_for_save(_electricity_bills),
	}


func _serialize_electricity_bills_for_save(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for bill_any in value:
		if not (bill_any is Dictionary):
			continue
		var bill := (bill_any as Dictionary).duplicate(true)
		var line_items: Array[Dictionary] = []
		var line_items_any = bill.get("line_items", [])
		if line_items_any is Array:
			for line_any in line_items_any:
				if not (line_any is Dictionary):
					continue
				var line := (line_any as Dictionary).duplicate(true)
				line["coord"] = _coord_to_save_dict(line.get("coord", Vector2i.ZERO))
				line["power_units"] = max(0, int(line.get("power_units", 0)))
				line["kwh_per_day"] = snappedf(maxf(0.0, float(line.get("kwh_per_day", 0.0))), 0.1)
				line["cost_per_day"] = max(0, int(line.get("cost_per_day", 0)))
				line_items.append(line)
		bill["service_day"] = max(1, int(bill.get("service_day", 1)))
		bill["issued_day"] = max(1, int(bill.get("issued_day", 1)))
		bill["due_day"] = max(1, int(bill.get("due_day", 1)))
		bill["amount"] = max(0, int(bill.get("amount", 0)))
		bill["status"] = "paid" if str(bill.get("status", "unpaid")) == "paid" else "unpaid"
		bill["kwh_total"] = snappedf(maxf(0.0, float(bill.get("kwh_total", 0.0))), 0.1)
		bill["base_fee"] = max(0, int(bill.get("base_fee", 0)))
		bill["rate_per_kwh"] = maxf(0.0, float(bill.get("rate_per_kwh", ELECTRICITY_PRICE_PER_KWH)))
		bill["line_items"] = line_items
		out.append(bill)
	return out


func _deserialize_electricity_bills_from_save(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for bill_any in value:
		if not (bill_any is Dictionary):
			continue
		var bill := (bill_any as Dictionary).duplicate(true)
		var line_items: Array[Dictionary] = []
		var line_items_any = bill.get("line_items", [])
		if line_items_any is Array:
			for line_any in line_items_any:
				if not (line_any is Dictionary):
					continue
				var line := (line_any as Dictionary).duplicate(true)
				line["coord"] = _coord_from_variant(line.get("coord", Vector2i.ZERO), Vector2i.ZERO)
				line["power_units"] = max(0, int(line.get("power_units", 0)))
				line["kwh_per_day"] = snappedf(maxf(0.0, float(line.get("kwh_per_day", 0.0))), 0.1)
				line["cost_per_day"] = max(0, int(line.get("cost_per_day", 0)))
				line_items.append(line)
		bill["service_day"] = max(1, int(bill.get("service_day", 1)))
		bill["issued_day"] = max(1, int(bill.get("issued_day", 1)))
		bill["due_day"] = max(1, int(bill.get("due_day", 1)))
		bill["amount"] = max(0, int(bill.get("amount", 0)))
		bill["status"] = "paid" if str(bill.get("status", "unpaid")) == "paid" else "unpaid"
		bill["kwh_total"] = snappedf(maxf(0.0, float(bill.get("kwh_total", 0.0))), 0.1)
		bill["base_fee"] = max(0, int(bill.get("base_fee", 0)))
		bill["rate_per_kwh"] = maxf(0.0, float(bill.get("rate_per_kwh", ELECTRICITY_PRICE_PER_KWH)))
		bill["line_items"] = line_items
		out.append(bill)
	return out


func _duplicate_dict_array(value: Variant) -> Array:
	var out: Array = []
	if not (value is Array):
		return out
	for item_any in value:
		if item_any is Dictionary:
			out.append((item_any as Dictionary).duplicate(true))
	return out


func _duplicate_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _coord_from_variant(value: Variant, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	if value is Vector2:
		var vec2 := value as Vector2
		return Vector2i(int(vec2.x), int(vec2.y))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2i(int(dict.get("x", fallback.x)), int(dict.get("y", fallback.y)))
	if value is Array:
		var arr := value as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return fallback


func _coord_to_save_dict(value: Variant) -> Dictionary:
	var coord := _coord_from_variant(value, Vector2i.ZERO)
	return {"x": coord.x, "y": coord.y}


func _coord_from_key_string(key: String) -> Vector2i:
	var parts := key.split(":")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


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
			"guests": _deserialize_guests_from_save(state_data.get("guests", [])),
			"accommodation_states": _deserialize_accommodation_states_from_save(state_data.get("accommodation_states", {})),
			"failures": _deserialize_failures_from_save(state_data.get("failures", {})),
			"guest_reviews": _duplicate_dict_array(state_data.get("guest_reviews", [])),
			"guest_transactions": _duplicate_dict_array(state_data.get("guest_transactions", [])),
			"next_guest_id": max(1, int(state_data.get("next_guest_id", 1)))
		})
		var electricity_any = state_data.get("electricity", {})
		if electricity_any is Dictionary:
			var electricity := electricity_any as Dictionary
			_electricity_last_billed_service_day = max(0, int(electricity.get("last_billed_service_day", max(0, _day_index - 1))))
			var fallback_cursor := _coerce_electricity_notice_cursor(_electricity_last_billed_service_day)
			_electricity_notice_template_cursor = _coerce_electricity_notice_cursor(int(electricity.get("notice_template_cursor", fallback_cursor)))
			_electricity_bills = _deserialize_electricity_bills_from_save(electricity.get("bills", []))
			_electricity_ups_seconds_left = clampf(float(electricity.get("ups_seconds_left", ELECTRICITY_UPS_DURATION_SEC)), 0.0, ELECTRICITY_UPS_DURATION_SEC)
			_electricity_ups_active = bool(electricity.get("ups_active", false))
		else:
			_electricity_last_billed_service_day = max(0, _day_index - 1)
			_electricity_notice_template_cursor = _coerce_electricity_notice_cursor(0)
			_electricity_bills.clear()
			_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC
			_electricity_ups_active = false
		if preview_only:
			_electricity_ups_active = false
			_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC
		_refresh_electricity_power_cut_state(true)
	else:
		_electricity_last_billed_service_day = max(0, _day_index - 1)
		_electricity_notice_template_cursor = _coerce_electricity_notice_cursor(0)
		_electricity_bills.clear()
		_electricity_ups_active = false
		_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC
		_refresh_electricity_power_cut_state(true)

	var runtime_any = snapshot.get("runtime", {})
	if runtime_any is Dictionary:
		var runtime := runtime_any as Dictionary
		if time_system != null and time_system.has_method("set_time_hours"):
			time_system.set_time_hours(float(runtime.get("time_of_day_hours", 9.0)))
		if weather_system != null and weather_system.has_method("set_weather"):
			weather_system.set_weather(int(runtime.get("weather_state", WEATHER_CLEAR)))

	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(preview_only)
	if not preview_only:
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


func _sync_guest_accommodation_state() -> void:
	var state = CoreRoot.get_state()
	if state == null:
		return
	if state.guests == null:
		state.guests = []
	if state.accommodation_states == null:
		state.accommodation_states = {}
	if building_manager == null:
		state.accommodation_states = {}
		return

	var structures_root := building_manager.get_node_or_null("Structures")
	if structures_root == null:
		state.accommodation_states = {}
		return

	var guest_beds: Dictionary = {}
	var active_guest_ids: Array = []
	for guest_any in state.guests:
		if not (guest_any is Dictionary):
			continue
		var guest := guest_any as Dictionary
		var guest_id := int(guest.get("id", -1))
		if guest_id <= 0:
			continue
		var status := str(guest.get("status", "")).to_lower().strip_edges()
		if status != "active" and status != "sleep":
			continue
		if guest_beds.has(guest_id):
			continue
		guest_beds[guest_id] = max(1, int(guest.get("beds_used", guest.get("party_size", 1))))
		active_guest_ids.append(guest_id)
	active_guest_ids.sort()

	var previous_states: Dictionary = {}
	if state.accommodation_states is Dictionary:
		previous_states = state.accommodation_states
	var entries: Array = []

	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		var building_type := str(structure.get_meta("building_type", "")).strip_edges()
		var capacity := _accommodation_capacity_for_building(building_type)
		if capacity <= 0:
			structure.set_meta("guest_count", 0)
			structure.set_meta("has_guest", false)
			continue

		var origin_any = structure.get_meta("grid_origin", Vector2i.ZERO)
		var origin := origin_any as Vector2i if origin_any is Vector2i else Vector2i.ZERO
		var key := _coord_to_key(origin)

		var prev_any = previous_states.get(key, {})
		var prev := prev_any as Dictionary if prev_any is Dictionary else {}
		var status := str(prev.get("status", "clean")).to_lower().strip_edges()
		if status != "dirty":
			status = "clean"

		var preserved_ids: Array = []
		var seen_ids: Dictionary = {}
		var prev_ids_any = prev.get("guest_ids", [])
		if prev_ids_any is Array:
			for id_any in prev_ids_any:
				var gid := int(id_any)
				if gid <= 0 or seen_ids.has(gid):
					continue
				if not guest_beds.has(gid):
					continue
				seen_ids[gid] = true
				preserved_ids.append(gid)

		entries.append({
			"key": key,
			"structure": structure,
			"building_type": building_type,
			"capacity": capacity,
			"status": status,
			"guest_ids": preserved_ids,
			"beds_used": 0
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("key", "")) < str(b.get("key", ""))
	)

	var assigned: Dictionary = {}
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var capacity := int(entry.get("capacity", 0))
		var used_beds := 0
		var kept_ids: Array = []
		var ids_any = entry.get("guest_ids", [])
		if ids_any is Array:
			for id_any in ids_any:
				var gid := int(id_any)
				if gid <= 0 or assigned.has(gid):
					continue
				var beds := int(guest_beds.get(gid, 1))
				if beds <= 0 or (used_beds + beds) > capacity:
					continue
				kept_ids.append(gid)
				assigned[gid] = true
				used_beds += beds
		entry["guest_ids"] = kept_ids
		entry["beds_used"] = used_beds

	var remaining_ids: Array = []
	for gid_any in active_guest_ids:
		var gid := int(gid_any)
		if gid <= 0 or assigned.has(gid):
			continue
		remaining_ids.append(gid)

	var next_idx := 0
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		if next_idx >= remaining_ids.size():
			break
		var entry := entry_any as Dictionary
		var capacity := int(entry.get("capacity", 0))
		var used_beds := int(entry.get("beds_used", 0))
		var ids_any = entry.get("guest_ids", [])
		var ids: Array = ids_any if ids_any is Array else []
		while next_idx < remaining_ids.size():
			var gid := int(remaining_ids[next_idx])
			var beds := int(guest_beds.get(gid, 1))
			if beds <= 0 or (used_beds + beds) > capacity:
				break
			ids.append(gid)
			assigned[gid] = true
			used_beds += beds
			next_idx += 1
		entry["guest_ids"] = ids
		entry["beds_used"] = used_beds

	var rebuilt_states: Dictionary = {}
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var key := str(entry.get("key", ""))
		var structure := entry.get("structure") as Node3D
		var guest_ids_any = entry.get("guest_ids", [])
		var guest_ids: Array = guest_ids_any if guest_ids_any is Array else []
		var guest_count := guest_ids.size()
		var base_status := str(entry.get("status", "clean")).to_lower().strip_edges()
		var final_status := "occupied" if guest_count > 0 else ("dirty" if base_status == "dirty" else "clean")
		rebuilt_states[key] = {
			"status": final_status,
			"building_type": str(entry.get("building_type", "")),
			"capacity": int(entry.get("capacity", 0)),
			"guest_ids": guest_ids.duplicate()
		}
		if structure != null and is_instance_valid(structure):
			structure.set_meta("guest_count", guest_count)
			structure.set_meta("has_guest", guest_count > 0)

	state.accommodation_states = rebuilt_states


func _accommodation_capacity_for_building(building_type: String) -> int:
	var normalized := building_type.to_lower().strip_edges()
	if normalized.begins_with("tent"):
		return 1
	if normalized.begins_with("cabin"):
		return 2
	return 0


func _coord_to_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]


func _reset_state_for_new_game() -> void:
	_pending_loaded_player_state.clear()
	_pending_loaded_crt_state.clear()
	_last_known_crt_desktop_state.clear()
	_electricity_bills.clear()
	_electricity_last_billed_service_day = 0
	_electricity_notice_template_cursor = _coerce_electricity_notice_cursor(0)
	_electricity_power_cut_active = false
	_electricity_ups_active = false
	_electricity_ups_seconds_left = ELECTRICITY_UPS_DURATION_SEC
	_lamp_grid_power_available = true
	_active_save_path = ""
	_clear_blood_fx()
	var state = CoreRoot.get_state()
	if state == null:
		return
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
		if _can_pause_now():
			_open_pause_menu()


func _can_pause_now() -> bool:
	return (
		_startup_bootstrap_complete
		and _gameplay_started
		and not _menu_mode
		and not _game_over_active
		and not _is_any_interior_open()
		and (_pause_menu == null or not _pause_menu.is_open())
	)


func _open_pause_menu() -> void:
	if not _can_pause_now():
		return
	_ensure_pause_menu()
	_pause_menu.open(_pause_info_line())
	get_tree().paused = true


## Built once at bootstrap so it is ready (and laid out) long before the first Esc.
func _ensure_pause_menu() -> void:
	if _pause_menu != null:
		return
	_pause_menu = PAUSE_MENU_SCRIPT.new()
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(func() -> void: _close_pause_menu(true))
	_pause_menu.save_requested.connect(_on_pause_save_requested)
	_pause_menu.quit_to_title_requested.connect(_on_pause_quit_requested)


func _close_pause_menu(recapture_mouse: bool) -> void:
	if _pause_menu == null or not _pause_menu.is_open():
		return
	_pause_menu.close()
	get_tree().paused = false
	if recapture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


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
