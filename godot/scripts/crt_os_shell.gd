extends Control
signal desktop_ready

# --- OS STATE & ASSETS ---
enum os_state { OFF, BOOT, SPLASH, DESKTOP }
var _current_state = os_state.OFF

const ASSET_SPLASH = "res://assets/retrosplash.jpg"
const ASSET_WALLPAPER = "res://assets/textury/crt/UI/bios/wallpaper.png"
const ASSET_ICON_PC = "res://assets/computer-icon.png"
const ASSET_SPLASH_COMPOSITE = "res://assets/textury/crt/UI/bios/ChatGPT Image 15. 2. 2026 14_22_04.png"
const ASSET_SPLASH_BG_LAYER = "res://assets/textury/crt/UI/bios/splashback.png"
const ASSET_SPLASH_LOGO_LAYER = "res://assets/textury/crt/UI/bios/splashlogo.png"
const ASSET_SPLASH_TEXT_LAYER = "res://assets/textury/crt/UI/bios/splashtext.png"
const ASSET_SPLASH_BAR_FILL_LAYER = "res://assets/textury/crt/UI/bios/splashbar.png"
const ASSET_BIOS_BADGE_AWARD = "res://assets/award-logo.png"
const ASSET_BIOS_BADGE_ENERGY = "res://assets/energy-star.png"
const ASSET_BIOS_BADGE_MICRO = "res://assets/textury/crt/UI/bios/cpu logo.jpg"
const SFX_TUDU_TRANSITION = "res://assets/sfx/crtui/tudu.mp3"
const SFX_EMAIL_NOTIFICATION = "res://assets/sfx/crtui/email.mp3"
const SFX_CLICK_PLACEHOLDER = "res://assets/sfx/shust.mp3"
const ASSET_CURSOR_DEFAULT = "res://assets/textury/crt/UI/cursor.png"
const ASSET_CURSOR_HAND    = "res://assets/textury/crt/UI/cursorhand.png"
const CURSOR_DEFAULT_HOTSPOT := Vector2(17, 9)
const CURSOR_HAND_HOTSPOT := Vector2(25, 7)
const ASSET_ICON_BEETERNET = "res://assets/textury/crt/icons/beeternet.png"
const ASSET_ICON_DOWNLOADS = "res://assets/textury/crt/icons/folder.png"
const ASSET_ICON_BIN_EMPTY = "res://assets/textury/crt/icons/bin.png"
const ASSET_ICON_BIN_FULL  = "res://assets/textury/crt/icons/binfull.png"
const BEETERNET_HOME_URL = "home://start"
const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")
const SETTINGS_PANEL_SCRIPT = preload("res://scripts/settings_panel.gd")
const GUESTRACK_PANEL_SCRIPT = preload("res://scripts/guestrack_panel.gd")
const BOOT_MEMORY_RATE_KB_PER_SEC := 85000.0
const BOOT_STAGE_DELAY_SEC := 0.24
const BOOT_FINAL_DELAY_SEC := 0.90
const SPLASH_AUTO_SKIP_SEC := 2.10
const DESKTOP_TASKBAR_DELAY_SEC := 0.20
const DESKTOP_ICON_DELAY_SEC := 0.78
const DESKTOP_WALL_DELAY_SEC := 1.66
const DESKTOP_FADE_SEC := 0.90
const DESKTOP_ICON_POP_DELAY_SEC := 0.62
const DESKTOP_ICON_POP_STAGGER_SEC := 0.14
const DESKTOP_ICON_POP_DURATION_SEC := 0.24
const DESKTOP_ICON_PREPOP_SCALE := 0.93
const DESKTOP_ICON_PREPOP_ALPHA := 0.68
const DESKTOP_ICON_POP_OVERSHOOT_SCALE := 1.14
const WINDOW_OPEN_DELAY_SEC := 0.58
const EMAIL_TOAST_VISIBLE_SEC := 3.6
const EMAIL_TOAST_FADE_SEC := 0.35
const SPLASH_ANIM_FPS := 15.0
const SPLASH_DESIGN_SIZE := Vector2(1248.0, 832.0)
const SPLASH_BAR_RECT := Rect2(323.0, 688.0, 602.0, 34.0)
const SPLASH_BAR_INSET := Vector2(6.0, 5.0)
const SPLASH_BAR_SOURCE_RECT := Rect2(266.0, 535.0, 708.0, 52.0)
const SPLASH_STAGE_BG_TIME := 0.12
const SPLASH_STAGE_LOGO_TIME := 0.36
const SPLASH_STAGE_TEXT_TIME := 0.82
const SPLASH_STAGE_BAR_TIME := 1.20
const SPLASH_MIN_COMPLETE_TIME := 4.90
const SPLASH_MAX_FALLBACK_TIME := 8.50
const SPLASH_LOGO_OFFSET := Vector2(0.0, -210.0)
const SPLASH_LOGO_SCALE := 0.56
const SPLASH_DESYNC_MAX := 0.38
const SPLASH_STALL_CHANCE := 0.16
const COL_OS_WINDOW_BG = Color(0.63, 0.58, 0.48, 1.0)
const COL_OS_TITLE_BAR = Color(0.35, 0.19, 0.12, 1.0)
const COL_OS_TEXT_DARK = Color(0.12, 0.08, 0.06, 1.0)
const COL_OS_TEXT_LIGHT = Color(0.93, 0.89, 0.74, 1.0)
const COL_OS_BORDER = Color(0.31, 0.24, 0.16, 1.0)
const COL_OS_ACCENT = Color(0.45, 0.51, 0.30, 1.0)
const COL_OS_ACCENT_ALT = Color(0.59, 0.37, 0.20, 1.0)
const COL_OS_TRANSITION_FLASH = Color(0.82, 0.73, 0.35, 1.0)
const OS_DESIGN_SIZE := Vector2(1280.0, 720.0)
const DESKTOP_TASKBAR_HEIGHT := 24.0
const DESKTOP_TOP_BAR_HEIGHT := 22.0
const DESKTOP_TOP_BAR_NODE_LABEL_W := 148.0
const DESKTOP_TOP_BAR_TRAY_W := 238.0
const DESKTOP_TOP_BAR_EMAIL_W := 92.0
const DESKTOP_TOP_BAR_EMAIL_RIGHT_MARGIN := 8.0
const DESKTOP_TOP_BAR_DAY_W := 126.0
const TASKBAR_BUTTON_WIDTH := 152.0
const TASKBAR_BUTTON_HEIGHT := 22.0
const TITLEBAR_BUTTON_SIZE := Vector2(20.0, 18.0)
const TITLEBAR_BUTTON_TOP := 4.0
const TITLEBAR_BUTTON_RIGHT_MARGIN := 6.0
const TITLEBAR_BUTTON_GAP := 4.0
const DESKTOP_CLUTTER_SIDE_GUTTER := 14.0
const DESKTOP_CLUTTER_ICON_SAFE_LEFT := 124.0
const DESKTOP_CLUTTER_BADGE_MIN_WIDTH := 280.0
const DESKTOP_CLUTTER_BADGE_MAX_WIDTH := 520.0
const DESKTOP_CLUTTER_BADGE_SIZE := Vector2(360.0, 30.0)
const DESKTOP_CLUTTER_EMAIL_SIZE := Vector2(220.0, 54.0)
const DESKTOP_CLUTTER_UNDER_SIZE := Vector2(250.0, 70.0)
const DESKTOP_ICON_CONTAINER_SIZE := Vector2(92.0, 106.0)
const DESKTOP_ICON_TEXTURE_SIZE := Vector2(60.0, 60.0)
const DESKTOP_ICON_TEXTURE_OFFSET := Vector2(8.0, 2.0)
const DESKTOP_ICON_LABEL_Y := 66.0
const DESKTOP_ICON_LABEL_H := 38.0
const DESKTOP_ICON_COL0_X := 2.0
const DESKTOP_ICON_TOP_OFFSET := 8.0
const DESKTOP_ICON_COLUMN_GAP := 114.0
const DESKTOP_ICON_ROW_GAP := 118.0
const UPS_BANNER_HEIGHT := 42.0
const UPS_BANNER_BOTTOM_MARGIN := 6.0
const UPS_BANNER_BLINK_PERIOD := 0.42
const CAMP_STATUS_TABS: Array[String] = ["electricity", "billing", "night_risk", "utilities", "archive"]
const DESKTOP_ICON_SLOT_META := "layout_slot"
const DESKTOP_ICON_ORDER: Array[String] = [
	"builder",
	"beeternet",
	"campmail",
	"downloads",
	"bin",
	"guestrack",
	"camp_status",
	"finance",
	"minesweeper",
]
const BUILDER_LOCK_NOTICE_WINDOW_ID := "builder_lock_notice"
const BUILDER_LOCK_NOTICE_TITLE := "Builder Locked"
const BUILDER_LOCK_NOTICE_TEXT := "Builder is unavailable in NIGHT MODE.\n\nWait for DAY MODE to continue building."

const APP_INSTALLERS := {
	"builder": "_builder98_setup.exe",
	"guestrack": "_guestrack98_setup.exe",
	"camp_status": "_campstatus98_setup.exe",
	"finance": "_finance98_setup.exe",
	"minesweeper": "_minesweeper98_setup.exe",
	"campmail": "_campmail98_setup.exe",
}

const DEFAULT_UNLOCK_STATE := {
	"builder": false,
	"guestrack": false,
	"camp_status": false,
	"finance": false,
	"minesweeper": false,
	"campmail": true,
	"beeternet": true,
	"downloads": true,
	"bin": true,
}

# --- MANAGERS (Passed from Main) ---
var _grid_manager
var _building_manager

# --- UI NODES ---
var _black_bg: ColorRect
var _os_canvas: Control
var _boot_ui: Control
var _boot_label: Label
var _splash_ui: TextureRect
var _splash_canvas: Control
var _splash_background: TextureRect
var _splash_logo: TextureRect
var _splash_text: TextureRect
var _splash_progress_track: ColorRect
var _splash_progress_clip: Control
var _splash_progress_fill: TextureRect
var _desktop_ui: Control
var _desktop_wallpaper: TextureRect
var _desktop_boot_overlay: ColorRect
var _top_status_bar: Panel
var _top_bar_ticker_clip: Control
var _top_bar_email_indicator: Button
var _taskbar: Panel
var _taskbar_container: HBoxContainer
var _taskbar_buttons: Dictionary = {}
var _clock_label: Label
var _start_button: Button
var _start_menu: Panel
var _day_status_label: Label
var _camp_status_body: RichTextLabel = null
var _camp_status_window: Panel = null
var _camp_status_active_tab: String = "electricity"
var _camp_status_tabs: Dictionary = {}
var _camp_status_pages: Dictionary = {}
var _camp_status_notice_label: Label = null
var _finance_body: RichTextLabel = null
var _guestrack_panel: Control = null
var _desktop_icons: Control
var _desktop_clutter: Control
var _window_layer: Control
var _app_windows: Dictionary = {}

# --- DESKTOP ICON DRAG ---
var _dragging_icon: Control = null
var _dragging_icon_callback: Callable
var _dragging_icon_offset: Vector2 = Vector2.ZERO
var _icon_press_global_start: Vector2 = Vector2.ZERO
var _icon_has_dragged: bool = false

# --- WINDOW DRAG ---
var _dragging_window: Panel = null
var _dragging_window_offset: Vector2 = Vector2.ZERO

# --- BUILDER APP MODULE ---
var _builder_module: Control = null
var _is_day_mode: bool = true

# --- BOOT SEQUENCE STATE ---
var _boot_step: int = 0
var _boot_timer: float = 0.0
var _memory_kb: int = 0
var _boot_lines: Array = []
var _boot_sequence_id: int = 0
var _desktop_sequence_id: int = 0
var _monitor_powered: bool = false
var _transition_sfx_player: AudioStreamPlayer
var _notification_sfx_player: AudioStreamPlayer
var _click_sfx_player: AudioStreamPlayer
var _window_open_sequence_id: int = 0
var _desktop_fx_blink_nodes: Array = []
var _desktop_marquee_label: Label
var _desktop_badge_panel: Panel
var _desktop_badge_label: Label
var _desktop_email_panel: Panel
var _desktop_email_label: Label
var _email_toast_panel: Panel
var _email_toast_label: Label
var _email_toast_time_left: float = 0.0
var _ups_banner_panel: Panel = null
var _ups_banner_label: Label = null
var _ups_banner_active: bool = false
var _ups_banner_seconds_left: float = 0.0
var _ups_banner_blink_timer: float = 0.0

# --- EMAIL CLIENT STATE ---
var _email_selected_folder: String = "all"
var _email_selected_idx: int = -1
var _email_folder_inbox_btn: Button
var _email_folder_spam_btn: Button
var _email_list_vbox: VBoxContainer
var _email_preview_header: RichTextLabel
var _email_preview_body: RichTextLabel
var _email_confirm_btn: Button
var _email_reject_btn: Button
var _email_current_mail: Dictionary = {}
var _interior_host: Node
var _desktop_under_panel: Panel
var _desktop_under_label: Label
var _desktop_sparkle_label: Label
var _desktop_marquee_left_bound: float = 0.0
# --- CURSORS ---
var _cursor_default_tex: Texture2D = null
var _cursor_hand_tex: Texture2D = null
var _cursor_mode: int = -1 # -1 unknown, 0 default, 1 hand
# --- UNLOCK / DESKTOP FOLDERS ---
var _unlock_registry: Dictionary = {}
var _downloads_items: Array = []
var _bin_items: Array = []
var _pending_desktop_icon_layout: Dictionary = {}
var _bin_icon_img: TextureRect = null
var _start_menu_programs_box: VBoxContainer = null
var _desktop_program_icons: Dictionary = {}
var _start_menu_program_items: Dictionary = {}
var _desktop_marquee_right_bound: float = 0.0
var _desktop_fx_blink_tick: float = 0.0
var _desktop_fx_blink_state: bool = true
var _start_menu_sequence_id: int = 0
var _window_cascade_counter: int = 0
var _splash_anim_time: float = 0.0
var _splash_progress: float = 0.0
var _splash_frame_accum: float = 0.0
var _splash_bg_spawn_time: float = SPLASH_STAGE_BG_TIME
var _splash_logo_spawn_time: float = SPLASH_STAGE_LOGO_TIME
var _splash_text_spawn_time: float = SPLASH_STAGE_TEXT_TIME
var _splash_bar_spawn_time: float = SPLASH_STAGE_BAR_TIME
var _splash_lag_hold: float = 0.0
var _splash_logo_base_position: Vector2 = Vector2.ZERO

# --- COLORS ---
const COL_WIN98_BG = COL_OS_WINDOW_BG
const COL_WIN98_TITLE = COL_OS_TITLE_BAR
const COL_WIN98_TEXT = COL_OS_TEXT_DARK
const COL_BIOS_TEXT = Color(0.8, 0.8, 0.8, 1.0)


func _ready() -> void:
	randomize()
	var state_cb = Callable(self, "refresh_from_state")
	if not EventBus.state_changed.is_connected(state_cb):
		EventBus.state_changed.connect(state_cb)
	var money_cb = Callable(self, "_on_money_changed")
	if EventBus.has_signal("money_changed") and not EventBus.money_changed.is_connected(money_cb):
		EventBus.money_changed.connect(money_cb)
	var time_cb = Callable(self, "_on_time_tick")
	if EventBus.has_signal("time_tick") and not EventBus.time_tick.is_connected(time_cb):
		EventBus.time_tick.connect(time_cb)
	var install_cb = Callable(self, "_on_program_installed")
	if EventBus.has_signal("program_installed") and not EventBus.program_installed.is_connected(install_cb):
		EventBus.program_installed.connect(install_cb)
	var dl_cb = Callable(self, "_add_to_downloads")
	if EventBus.has_signal("file_downloaded") and not EventBus.file_downloaded.is_connected(dl_cb):
		EventBus.file_downloaded.connect(dl_cb)
	_seed_unlock_registry()
	_build_os_structure()
	_apply_pending_desktop_icon_layout()
	_setup_audio()
	_update_os_canvas_layout()
	_apply_state_visibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_os_canvas_layout()
		if _current_state == os_state.SPLASH:
			_layout_splash_canvas()
		elif _current_state == os_state.DESKTOP:
			_layout_desktop()


func _seed_unlock_registry() -> void:
	for app_id in DEFAULT_UNLOCK_STATE.keys():
		if not _unlock_registry.has(app_id):
			_unlock_registry[app_id] = DEFAULT_UNLOCK_STATE[app_id]


func _reset_unlock_registry_to_defaults() -> void:
	_unlock_registry.clear()
	for app_id in DEFAULT_UNLOCK_STATE.keys():
		_unlock_registry[app_id] = DEFAULT_UNLOCK_STATE[app_id]


func setup(grid_mgr, building_mgr, _ui_adapter = null, interior_host: Node = null) -> void:
	_grid_manager = grid_mgr
	_building_manager = building_mgr
	_interior_host = interior_host
	if _builder_module != null and _builder_module.has_method("setup"):
		_builder_module.call("setup", grid_mgr, building_mgr)
	set_is_day(_is_day_mode)


func open_panel() -> bool:
	visible = true
	_update_os_canvas_layout()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_init_cursors()
	if not _monitor_powered:
		_monitor_powered = true
		_start_boot_sequence()
		return true

	_apply_state_visibility()
	if _current_state == os_state.DESKTOP and (_desktop_boot_overlay == null or not _desktop_boot_overlay.visible):
		desktop_ready.emit()
	return true


func close_panel() -> void:
	visible = false
	_cursor_mode = -1
	# Reset all shapes we override, not only arrow.
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)


func is_open() -> bool:
	return visible


func is_desktop_ready() -> bool:
	return _monitor_powered and _current_state == os_state.DESKTOP


func power_off() -> void:
	_monitor_powered = false
	_boot_sequence_id += 1
	_desktop_sequence_id += 1
	_window_open_sequence_id += 1
	_current_state = os_state.OFF
	_boot_timer = 0.0
	_boot_step = 0
	_boot_lines.clear()
	for app_win in _app_windows.values():
		if app_win != null:
			app_win.visible = false
	_close_start_menu()
	_builder_module = null
	if _notification_sfx_player != null:
		_notification_sfx_player.stop()
	_apply_state_visibility()


func _process(delta: float) -> void:
	if not visible:
		return

	_update_os_canvas_layout()

	# Update Clock - Using EventBus state now
	# if _clock_label != null:
	# 	var time = Time.get_time_dict_from_system()
	# 	_clock_label.text = "%02d:%02d" % [time.hour, time.minute]

	# State Machine
	match _current_state:
		os_state.BOOT:
			_process_boot(delta)
		os_state.SPLASH:
			_process_splash(delta)
		os_state.DESKTOP:
			_layout_desktop()
			_update_desktop_fx(delta)
			_sync_cursor_visual_state()


func _input(event: InputEvent) -> void:
	if not visible: return

	# --- Window drag (title-bar initiated) ---
	if _dragging_window != null and not is_instance_valid(_dragging_window):
		_dragging_window = null
	if _dragging_window != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging_window = null
		get_viewport().set_input_as_handled()
		return
	if _dragging_window != null and event is InputEventMouseMotion:
		var vp_drag: Vector2 = _get_layout_size()
		var target: Vector2 = event.global_position - _dragging_window_offset
		target.x = clampf(target.x, 0.0, maxf(0.0, vp_drag.x - _dragging_window.size.x))
		target.y = clampf(target.y, DESKTOP_TOP_BAR_HEIGHT, maxf(DESKTOP_TOP_BAR_HEIGHT, vp_drag.y - DESKTOP_TASKBAR_HEIGHT - _dragging_window.size.y))
		_dragging_window.position = target
		get_viewport().set_input_as_handled()
		return

	# --- Desktop icon drag: release + motion ---
	# Release is handled here in _input() (not gui_input) so it fires reliably
	# regardless of move_to_front() disrupting GUI mouse-focus tracking.
	if _dragging_icon != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not _icon_has_dragged and _dragging_icon_callback.is_valid():
			_dragging_icon_callback.call()
			_play_click_sfx()
		_dragging_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_dragging_icon = null
		get_viewport().set_input_as_handled()
		return

	if _dragging_icon != null and event is InputEventMouseMotion:
		if (event.global_position - _icon_press_global_start).length() > 4.0:
			_icon_has_dragged = true
			if is_instance_valid(_dragging_icon):
				_dragging_icon.set_meta("custom_pos", true)
		if _icon_has_dragged and _desktop_icons != null:
			var vp := _get_layout_size()
			var local := _desktop_icons.get_local_mouse_position() - _dragging_icon_offset
			local.x = clampf(local.x, 0.0, vp.x - _dragging_icon.size.x)
			local.y = clampf(local.y, DESKTOP_TOP_BAR_HEIGHT, vp.y - DESKTOP_TASKBAR_HEIGHT - _dragging_icon.size.y)
			_dragging_icon.position = local
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and (_current_state == os_state.BOOT or _current_state == os_state.SPLASH):
			_skip_to_desktop()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _current_state == os_state.DESKTOP:
		_play_click_sfx()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _current_state == os_state.DESKTOP and _start_menu != null and _start_menu.visible:
			var click_pos = event.global_position
			var menu_rect = _start_menu.get_global_rect()
			var start_rect = Rect2(Vector2.ZERO, Vector2.ZERO)
			if _start_button != null:
				start_rect = _start_button.get_global_rect()
			if not menu_rect.has_point(click_pos) and not start_rect.has_point(click_pos):
				_close_start_menu()


func _update_os_canvas_layout() -> void:
	if _os_canvas == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var scale_x := viewport_size.x / OS_DESIGN_SIZE.x
	var scale_y := viewport_size.y / OS_DESIGN_SIZE.y
	if scale_x <= 0.0:
		scale_x = 1.0
	if scale_y <= 0.0:
		scale_y = 1.0
	_os_canvas.position = Vector2.ZERO
	_os_canvas.size = OS_DESIGN_SIZE
	_os_canvas.scale = Vector2(scale_x, scale_y)


func _get_layout_size() -> Vector2:
	if _os_canvas != null and _os_canvas.size.x > 0.0 and _os_canvas.size.y > 0.0:
		return _os_canvas.size
	return get_viewport().get_visible_rect().size


# --- BOOT SEQUENCE ---
func _start_boot_sequence() -> void:
	_boot_sequence_id += 1
	_desktop_sequence_id += 1
	_current_state = os_state.BOOT
	_apply_state_visibility()
	_boot_ui.move_to_front()

	_boot_lines.clear()
	_boot_label.text = ""
	_boot_step = 0
	_boot_timer = 0.0
	_memory_kb = 0

	_add_boot_line("Award Modular BIOS v4.51PG, An Energy Star Ally")
	_add_boot_line("Copyright (C) 1984-98, Award Software, Inc.")
	_add_boot_line("")
	_add_boot_line("ASUS P5A ACPI BIOS Revision 1011 Beta 005")
	_add_boot_line("PENTIUM-MMX CPU at 200MHz")


func _process_boot(delta: float) -> void:
	_boot_timer += delta

	if _boot_step == 0: # Memory Test
		_memory_kb += int(delta * BOOT_MEMORY_RATE_KB_PER_SEC)
		if _memory_kb >= 65536:
			_memory_kb = 65536
			_add_boot_line("Memory Test :  65536K OK")
			_boot_step = 1
			_boot_timer = 0.0
		else:
			# Update last line to show memory count
			var txt = _build_boot_text()
			_boot_label.text = txt + "\nMemory Test :  " + str(_memory_kb) + "K"
			return

	if _boot_step == 1 and _boot_timer > BOOT_STAGE_DELAY_SEC:
		_add_boot_line("")
		_add_boot_line("Award Plug and Play BIOS Extension v1.0A")
		_add_boot_line("Copyright (C) 1997, Award Software, Inc.")
		_boot_step = 2; _boot_timer = 0.0

	if _boot_step == 2 and _boot_timer > BOOT_STAGE_DELAY_SEC:
		_add_boot_line("Detecting HDD Primary Master   ... QUANTUM FIREBALL")
		_add_boot_line("Detecting HDD Primary Slave    ... None")
		_boot_step = 3; _boot_timer = 0.0

	if _boot_step == 3 and _boot_timer > BOOT_STAGE_DELAY_SEC:
		_add_boot_line("Detecting HDD Secondary Master ... CD-ROM DRIVE")
		_boot_step = 4; _boot_timer = 0.0

	if _boot_step == 4 and _boot_timer > BOOT_FINAL_DELAY_SEC:
		_enter_splash()


func _add_boot_line(text: String) -> void:
	_boot_lines.append(text)
	_boot_label.text = _build_boot_text()

func _build_boot_text() -> String:
	var s = ""
	for line in _boot_lines:
		s += line + "\n"
	return s

func _enter_splash() -> void:
	if not _monitor_powered:
		return
	_current_state = os_state.SPLASH
	_apply_state_visibility()
	_play_tudu_transition()
	_start_splash_animation()


func _start_splash_animation() -> void:
	_splash_anim_time = 0.0
	_splash_progress = 0.0
	_splash_frame_accum = 0.0
	var desync_span: float = randf_range(0.14, SPLASH_DESYNC_MAX)
	_splash_bg_spawn_time = SPLASH_STAGE_BG_TIME + randf_range(0.0, 0.08)
	_splash_logo_spawn_time = max(_splash_bg_spawn_time + 0.08, SPLASH_STAGE_LOGO_TIME + randf_range(0.04, desync_span))
	_splash_text_spawn_time = max(_splash_logo_spawn_time + 0.12, SPLASH_STAGE_TEXT_TIME + randf_range(0.10, desync_span + 0.16))
	_splash_bar_spawn_time = max(_splash_text_spawn_time + 0.10, SPLASH_STAGE_BAR_TIME + randf_range(0.14, desync_span + 0.28))
	_splash_lag_hold = randf_range(0.0, 0.07)
	_layout_splash_canvas()
	if _splash_background != null:
		_splash_background.visible = false
		_splash_background.modulate.a = 1.0
	if _splash_logo != null:
		_splash_logo.visible = false
		_splash_logo.modulate.a = 0.0
		_splash_logo.scale = Vector2.ONE
		_splash_logo.position = _splash_logo_base_position
	if _splash_text != null:
		_splash_text.visible = false
		_splash_text.modulate.a = 0.0
	if _splash_progress_track != null:
		_splash_progress_track.visible = false
	if _splash_progress_clip != null:
		_splash_progress_clip.visible = false
	if _splash_progress_fill != null:
		_splash_progress_fill.position = Vector2.ZERO
		_splash_progress_fill.size = Vector2(0.0, max(2.0, SPLASH_BAR_RECT.size.y - SPLASH_BAR_INSET.y * 2.0))


func _process_splash(delta: float) -> void:
	if _splash_canvas == null:
		return
	_layout_splash_canvas()
	_splash_frame_accum += delta
	var frame_step: float = 1.0 / SPLASH_ANIM_FPS
	while _splash_frame_accum >= frame_step:
		_splash_frame_accum -= frame_step
		_advance_splash_frame(frame_step)


func _advance_splash_frame(step: float) -> void:
	_splash_anim_time += step
	if _splash_lag_hold > 0.0:
		_splash_lag_hold = max(0.0, _splash_lag_hold - step)
		if _splash_logo != null and _splash_logo.visible and randf() > 0.64:
			_splash_logo.position = _splash_logo_base_position + Vector2(randf_range(-2.5, 2.5), randf_range(-1.8, 1.8))
		return
	if randf() < SPLASH_STALL_CHANCE:
		_splash_lag_hold = randf_range(0.02, 0.12)

	if _splash_background != null and not _splash_background.visible and _splash_anim_time >= _splash_bg_spawn_time:
		_splash_background.visible = true

	if _splash_logo != null and _splash_anim_time >= _splash_logo_spawn_time:
		_splash_logo.visible = true
		var logo_progress: float = clampf((_splash_anim_time - _splash_logo_spawn_time) / 0.88, 0.0, 1.0)
		var logo_steps: float = floor(logo_progress * 5.0) / 5.0
		_splash_logo.modulate.a = max(0.2, logo_steps)
		var jitter_strength: float = (1.0 - logo_progress) * 5.0
		_splash_logo.position = _splash_logo_base_position + Vector2(randf_range(-jitter_strength, jitter_strength), randf_range(-jitter_strength * 0.6, jitter_strength * 0.6))

	if _splash_text != null and _splash_anim_time >= _splash_text_spawn_time:
		_splash_text.visible = true
		var text_progress: float = clampf((_splash_anim_time - _splash_text_spawn_time) / 0.88, 0.0, 1.0)
		_splash_text.modulate.a = floor(text_progress * 6.0) / 6.0

	if _splash_anim_time >= _splash_bar_spawn_time:
		if _splash_progress_track != null:
			_splash_progress_track.visible = true
		if _splash_progress_clip != null:
			_splash_progress_clip.visible = true
		var load_time: float = _splash_anim_time - _splash_bar_spawn_time
		var phase: float = clampf(load_time / SPLASH_MIN_COMPLETE_TIME, 0.0, 1.0)
		var natural_curve: float = pow(phase, 1.65)
		var jitter: float = randf_range(-0.018, 0.028) * (1.0 - natural_curve)
		var target: float = clampf(natural_curve + jitter, _splash_progress, 1.0)
		if randf() > 0.18 or _splash_progress > 0.88:
			var step_gain: float = randf_range(0.006, 0.038) * (1.0 - pow(_splash_progress, 0.55))
			_splash_progress = min(max(_splash_progress + step_gain, target), 1.0)

	if _splash_progress_fill != null:
		var bar_width := SPLASH_BAR_RECT.size.x
		if _splash_progress_clip != null:
			bar_width = _splash_progress_clip.size.x
		_splash_progress_fill.size.x = bar_width * clamp(_splash_progress, 0.0, 1.0)

	if _splash_progress >= 0.995 and _splash_anim_time >= SPLASH_MIN_COMPLETE_TIME:
		_enter_desktop()
		return
	if _splash_anim_time >= SPLASH_MAX_FALLBACK_TIME:
		_enter_desktop()


func _layout_splash_canvas() -> void:
	if _splash_canvas == null:
		return
	var vp: Vector2 = _get_layout_size()
	var scale_factor: float = minf(vp.x / SPLASH_DESIGN_SIZE.x, vp.y / SPLASH_DESIGN_SIZE.y)
	if scale_factor <= 0.0:
		scale_factor = 1.0
	var canvas_size: Vector2 = SPLASH_DESIGN_SIZE * scale_factor
	_splash_canvas.size = canvas_size
	_splash_canvas.position = (vp - canvas_size) * 0.5
	if _splash_logo != null:
		var logo_size: Vector2 = canvas_size * SPLASH_LOGO_SCALE
		_splash_logo.size = logo_size
		_splash_logo_base_position = (canvas_size - logo_size) * 0.5 + SPLASH_LOGO_OFFSET * scale_factor
		if not _splash_logo.visible:
			_splash_logo.position = _splash_logo_base_position
	var bar_rect: Rect2 = _get_splash_bar_inner_rect()
	if _splash_progress_track != null:
		_splash_progress_track.position = bar_rect.position * scale_factor
		_splash_progress_track.size = bar_rect.size * scale_factor
	if _splash_progress_clip != null:
		_splash_progress_clip.position = bar_rect.position * scale_factor
		_splash_progress_clip.size = bar_rect.size * scale_factor
	if _splash_progress_fill != null:
		_splash_progress_fill.size.y = bar_rect.size.y * scale_factor
		_splash_progress_fill.position = Vector2.ZERO


func _get_splash_bar_inner_rect() -> Rect2:
	var inner_pos: Vector2 = SPLASH_BAR_RECT.position + SPLASH_BAR_INSET
	var inner_size: Vector2 = Vector2(
		max(2.0, SPLASH_BAR_RECT.size.x - SPLASH_BAR_INSET.x * 2.0),
		max(2.0, SPLASH_BAR_RECT.size.y - SPLASH_BAR_INSET.y * 2.0)
	)
	return Rect2(inner_pos, inner_size)

func _skip_to_desktop() -> void:
	if not _monitor_powered:
		return
	_boot_sequence_id += 1
	_enter_desktop()

func _enter_desktop() -> void:
	if not _monitor_powered:
		return
	_current_state = os_state.DESKTOP
	_apply_state_visibility()
	_close_start_menu()
	set_is_day(_is_day_mode)
	_start_desktop_load_sequence()


func _apply_state_visibility() -> void:
	if _black_bg == null or _boot_ui == null or _splash_ui == null or _desktop_ui == null:
		return

	if not _monitor_powered or _current_state == os_state.OFF:
		_black_bg.visible = true
		_black_bg.color = Color(0.0, 0.0, 0.0, 1.0)
		_boot_ui.visible = false
		_splash_ui.visible = false
		_desktop_ui.visible = false
		move_child(_black_bg, 0)
		if _os_canvas != null:
			move_child(_os_canvas, 1)
		return

	if _current_state == os_state.BOOT:
		_black_bg.visible = true
		_black_bg.color = Color(0.0, 0.0, 0.0, 0.85)
		_boot_ui.visible = true
		_splash_ui.visible = false
		_desktop_ui.visible = false
		move_child(_black_bg, 0)
		if _os_canvas != null:
			move_child(_os_canvas, 1)
		return

	if _current_state == os_state.SPLASH:
		_black_bg.visible = true
		_black_bg.color = Color(0.0, 0.0, 0.0, 0.65)
		_boot_ui.visible = false
		_splash_ui.visible = true
		_desktop_ui.visible = false
		move_child(_black_bg, 0)
		if _os_canvas != null:
			move_child(_os_canvas, 1)
		return

	# DESKTOP
	_black_bg.visible = true
	_black_bg.color = Color(0.0, 0.0, 0.0, 0.35)
	_boot_ui.visible = false
	_splash_ui.visible = false
	_desktop_ui.visible = true
	move_child(_black_bg, 0)
	if _os_canvas != null:
		move_child(_os_canvas, 1)


func _start_desktop_load_sequence() -> void:
	_desktop_sequence_id += 1
	var seq_id := _desktop_sequence_id

	if _desktop_wallpaper != null:
		_desktop_wallpaper.visible = false
		_desktop_wallpaper.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _desktop_icons != null:
		_desktop_icons.visible = false
	if _desktop_clutter != null:
		_desktop_clutter.visible = false
	if _taskbar != null:
		_taskbar.visible = false
	if _window_layer != null:
		_window_layer.visible = false
	if _desktop_boot_overlay != null:
		_desktop_boot_overlay.visible = true
		_desktop_boot_overlay.color = Color(COL_OS_TRANSITION_FLASH.r, COL_OS_TRANSITION_FLASH.g, COL_OS_TRANSITION_FLASH.b, 0.46)
		_desktop_boot_overlay.move_to_front()

	get_tree().create_timer(DESKTOP_TASKBAR_DELAY_SEC).timeout.connect(func():
		if seq_id != _desktop_sequence_id or not _monitor_powered or _current_state != os_state.DESKTOP:
			return
		if _taskbar != null:
			_taskbar.visible = true
		if _desktop_boot_overlay != null:
			var t1 = create_tween()
			t1.tween_property(_desktop_boot_overlay, "color:a", 0.30, 0.14)
	)

	get_tree().create_timer(DESKTOP_ICON_DELAY_SEC).timeout.connect(func():
		if seq_id != _desktop_sequence_id or not _monitor_powered or _current_state != os_state.DESKTOP:
			return
		if _desktop_icons != null:
			_desktop_icons.visible = true
		_prepare_desktop_icons_for_late_pop(seq_id)
		if _desktop_clutter != null:
			_desktop_clutter.visible = true
		if _desktop_boot_overlay != null:
			var t2 = create_tween()
			t2.tween_property(_desktop_boot_overlay, "color:a", 0.18, 0.18)
		_update_window_layer_state()
	)

	get_tree().create_timer(DESKTOP_WALL_DELAY_SEC).timeout.connect(func():
		if seq_id != _desktop_sequence_id or not _monitor_powered or _current_state != os_state.DESKTOP:
			return
		if _desktop_wallpaper != null:
			_desktop_wallpaper.visible = true
			_desktop_wallpaper.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var t = create_tween()
		if _desktop_wallpaper != null:
			t.tween_property(_desktop_wallpaper, "modulate:a", 1.0, DESKTOP_FADE_SEC)
		if _desktop_boot_overlay != null:
			t.parallel().tween_property(_desktop_boot_overlay, "color:a", 0.0, DESKTOP_FADE_SEC)
		t.finished.connect(func():
			if seq_id != _desktop_sequence_id:
				return
			if _desktop_boot_overlay != null:
				_desktop_boot_overlay.visible = false
				_desktop_boot_overlay.color = COL_OS_TRANSITION_FLASH
			_play_desktop_icon_pop_sequence(seq_id)
			desktop_ready.emit()
			get_tree().create_timer(1.1).timeout.connect(func():
				if seq_id != _desktop_sequence_id or _current_state != os_state.DESKTOP:
					return
				_play_email_notification()
			)
		)
	)


func _collect_visible_desktop_icons() -> Array[Control]:
	var out: Array[Control] = []
	for app_id in DESKTOP_ICON_ORDER:
		if not _desktop_program_icons.has(app_id):
			continue
		var icon_node = _desktop_program_icons[app_id] as Control
		if icon_node == null or not icon_node.visible:
			continue
		out.append(icon_node)
	return out


func _prepare_desktop_icons_for_late_pop(seq_id: int) -> void:
	if seq_id != _desktop_sequence_id or _current_state != os_state.DESKTOP:
		return
	for icon_node in _collect_visible_desktop_icons():
		icon_node.pivot_offset = icon_node.size * 0.5
		icon_node.scale = Vector2.ONE * DESKTOP_ICON_PREPOP_SCALE
		icon_node.modulate = Color(1.0, 1.0, 1.0, DESKTOP_ICON_PREPOP_ALPHA)


func _play_desktop_icon_pop_sequence(seq_id: int) -> void:
	var icons := _collect_visible_desktop_icons()
	if icons.is_empty():
		return
	for idx in icons.size():
		var icon_node = icons[idx]
		var delay = DESKTOP_ICON_POP_DELAY_SEC + float(idx) * DESKTOP_ICON_POP_STAGGER_SEC
		_queue_desktop_icon_pop(seq_id, icon_node, delay)


func _queue_desktop_icon_pop(seq_id: int, icon_node: Control, delay: float) -> void:
	if icon_node == null:
		return
	get_tree().create_timer(maxf(0.0, delay)).timeout.connect(func():
		if seq_id != _desktop_sequence_id or not _monitor_powered or _current_state != os_state.DESKTOP:
			return
		if icon_node == null or not is_instance_valid(icon_node) or not icon_node.visible:
			return
		icon_node.pivot_offset = icon_node.size * 0.5
		icon_node.scale = Vector2.ONE * DESKTOP_ICON_POP_OVERSHOOT_SCALE
		icon_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var t = create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_BACK)
		t.tween_property(icon_node, "scale", Vector2.ONE, DESKTOP_ICON_POP_DURATION_SEC)
	)


# --- DESKTOP LOGIC ---
func _layout_desktop() -> void:
	var vp = _get_layout_size()

	# Top status bar — always full width
	if _top_status_bar:
		_top_status_bar.size = Vector2(vp.x, DESKTOP_TOP_BAR_HEIGHT)
	# Ticker clip: from node-label end to start of right tray
	if _top_bar_ticker_clip != null:
		var clip_left := DESKTOP_TOP_BAR_NODE_LABEL_W
		var clip_w := maxf(60.0, vp.x - clip_left - DESKTOP_TOP_BAR_TRAY_W)
		_top_bar_ticker_clip.position = Vector2(clip_left, 1.0)
		_top_bar_ticker_clip.size = Vector2(clip_w, DESKTOP_TOP_BAR_HEIGHT - 2.0)
		_desktop_marquee_right_bound = clip_w
		if _desktop_marquee_label != null:
			_desktop_marquee_label.size.y = DESKTOP_TOP_BAR_HEIGHT - 4.0
			if _desktop_marquee_label.position.x > clip_w + 100.0:
				_desktop_marquee_label.position.x = clip_w

	if _taskbar:
		_taskbar.position = Vector2(0.0, vp.y - DESKTOP_TASKBAR_HEIGHT)
		_taskbar.size = Vector2(vp.x, DESKTOP_TASKBAR_HEIGHT)
		if _taskbar_container:
			_taskbar_container.size = Vector2(vp.x - 280.0, 24.0)
		if _start_menu:
			_start_menu.position = Vector2(4.0, vp.y - DESKTOP_TASKBAR_HEIGHT - _start_menu.size.y - 2.0)
		_layout_desktop_clutter(vp)
	_layout_email_toast(vp)
	_layout_ups_banner(vp)


func _layout_desktop_clutter(_vp: Vector2, _force_marquee_reset: bool = false) -> void:
	# DreamClutter now contains only the subtle wallpaper tile tinting.
	# Ticker, email and node badge live in _top_status_bar — laid out by _layout_desktop().
	pass


func _update_desktop_fx(delta: float) -> void:
	_update_ups_banner_from_runtime(delta)

	if _desktop_marquee_label != null:
		# Marquee lives inside a clipped container — coordinates are local to the clip.
		# left edge = 0, right edge = clip width (_desktop_marquee_right_bound).
		var right_bound := _desktop_marquee_right_bound
		if right_bound <= 0.0:
			right_bound = _get_layout_size().x
		_desktop_marquee_label.position.x -= 76.0 * delta
		# Wrap: when tail passes the clip's left edge (x=0), jump back to right
		if _desktop_marquee_label.position.x + _desktop_marquee_label.size.x < 0.0:
			_desktop_marquee_label.position.x = right_bound

	if _email_toast_panel != null and _email_toast_panel.visible:
		_email_toast_time_left = maxf(0.0, _email_toast_time_left - delta)
		if _email_toast_time_left <= 0.0:
			_email_toast_panel.modulate.a = maxf(0.0, _email_toast_panel.modulate.a - (delta / EMAIL_TOAST_FADE_SEC))
			if _email_toast_panel.modulate.a <= 0.01:
				_email_toast_panel.visible = false

	_desktop_fx_blink_tick -= delta
	if _desktop_fx_blink_tick > 0.0:
		return

	_desktop_fx_blink_tick = 0.43
	_desktop_fx_blink_state = not _desktop_fx_blink_state
	for n in _desktop_fx_blink_nodes:
		var item = n as CanvasItem
		if item == null:
			continue
		item.visible = _desktop_fx_blink_state or (randi() % 3 != 0)


func _register_desktop_blink(node: CanvasItem) -> void:
	if node == null:
		return
	_desktop_fx_blink_nodes.append(node)


func _queue_window_open(win: Panel, play_email_ping: bool = false) -> void:
	if win == null:
		return
	# The sequence is per window: a second window opening during the delay used to
	# cancel the first one for good (e.g. a mail arriving as the Builder opened).
	_window_open_sequence_id += 1
	var seq_id = _window_open_sequence_id
	win.set_meta("open_seq", seq_id)
	win.visible = false
	if _window_layer != null:
		_window_layer.visible = true
	_reveal_window_later(win, seq_id, play_email_ping, WINDOW_OPEN_DELAY_SEC, 40)


## Shows a queued window once the desktop is up. A window requested while the OS is
## still booting waits for the desktop instead of being dropped.
func _reveal_window_later(win: Panel, seq_id: int, play_email_ping: bool, delay: float, tries_left: int) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		if not is_instance_valid(win) or int(win.get_meta("open_seq", -1)) != seq_id:
			return
		if _current_state != os_state.DESKTOP:
			if tries_left > 0 and _monitor_powered:
				_reveal_window_later(win, seq_id, play_email_ping, 0.3, tries_left - 1)
			return
		win.visible = true
		win.move_to_front()
		_update_window_layer_state()
		if _app_windows.get("builder", null) == win:
			_focus_builder_map_panel()
		if play_email_ping:
			_play_email_notification()
	)


func _open_builder_app() -> void:
	_close_start_menu()
	if not _is_program_unlocked("builder"):
		return
	if not _is_day_mode:
		_show_builder_locked_notice()
		return
	if _app_windows.has("builder") and is_instance_valid(_app_windows["builder"]):
		var existing = _app_windows["builder"]
		_sync_builder_module_reference(existing)
		if _builder_module != null and _builder_module.has_method("set_day_mode"):
			_builder_module.call("set_day_mode", _is_day_mode)
		if not _taskbar_buttons.has("builder"):
			_add_taskbar_button("builder", "Builder", existing)
		existing.visible = true
		existing.move_to_front()
		_update_window_layer_state()
		_update_taskbar_button_state("builder", true)
		_focus_builder_map_panel()
		return

	var win = _create_window_base("builder", "Builder", Vector2(1120, 660))
	_app_windows["builder"] = win
	_add_taskbar_button("builder", "Builder", win)
	# First launch opens maximized for map work.
	var vp_size = _get_layout_size()
	win.position = Vector2.ZERO
	win.size = Vector2(vp_size.x, vp_size.y - DESKTOP_TASKBAR_HEIGHT)
	var tb = win.get_child(0)
	if tb is Button:
		tb.size.x = win.size.x - 4
		for c in tb.get_children():
			if not (c is Button):
				continue
			var button := c as Button
			if button.name == "CloseBtn" or button.text == "X":
				button.position.x = tb.size.x - TITLEBAR_BUTTON_RIGHT_MARGIN - button.size.x
			elif button.name == "MaxBtn" or button.text == "[]":
				button.position.x = tb.size.x - TITLEBAR_BUTTON_RIGHT_MARGIN - button.size.x * 2.0 - TITLEBAR_BUTTON_GAP
			elif button.name == "MinBtn" or button.text == "_" or button.text == "-":
				button.position.x = tb.size.x - TITLEBAR_BUTTON_RIGHT_MARGIN - button.size.x * 3.0 - TITLEBAR_BUTTON_GAP * 2.0

	var BuilderScript = load("res://scripts/builder_module.gd")
	if BuilderScript == null:
		push_error("builder_module.gd not found")
		_close_app_window("builder")
		_app_windows.erase("builder")
		return
	var module_ctrl: Control = BuilderScript.new()
	_builder_module = module_ctrl
	win.add_child(module_ctrl)
	_layout_window_module_content(win, module_ctrl)
	win.resized.connect(func():
		if is_instance_valid(module_ctrl):
			_layout_window_module_content(win, module_ctrl)
	)
	if module_ctrl.has_method("setup"):
		module_ctrl.call("setup", _grid_manager, _building_manager)
	if module_ctrl.has_method("set_day_mode"):
		module_ctrl.call("set_day_mode", _is_day_mode)
	_queue_window_open(win)


func _sync_builder_module_reference(builder_window: Control) -> void:
	_builder_module = null
	if builder_window == null or not is_instance_valid(builder_window):
		return
	for child in builder_window.get_children():
		var ctrl := child as Control
		if ctrl == null:
			continue
		if ctrl.has_method("focus_map"):
			_builder_module = ctrl
			return


func _show_builder_locked_notice() -> void:
	if _app_windows.has(BUILDER_LOCK_NOTICE_WINDOW_ID) and is_instance_valid(_app_windows[BUILDER_LOCK_NOTICE_WINDOW_ID]):
		var existing_notice = _app_windows[BUILDER_LOCK_NOTICE_WINDOW_ID]
		existing_notice.visible = true
		existing_notice.move_to_front()
		_update_window_layer_state()
		_update_taskbar_button_state(BUILDER_LOCK_NOTICE_WINDOW_ID, true)
		return
	_open_text_window(BUILDER_LOCK_NOTICE_WINDOW_ID, BUILDER_LOCK_NOTICE_TITLE, BUILDER_LOCK_NOTICE_TEXT)


func _enforce_builder_night_lock() -> void:
	if not _app_windows.has("builder") or not is_instance_valid(_app_windows["builder"]):
		return
	var builder_window = _app_windows["builder"] as Control
	var was_open = builder_window.visible
	_close_app_window("builder")
	if was_open:
		_show_builder_locked_notice()


func _focus_builder_map_panel() -> void:
	if _builder_module == null or not is_instance_valid(_builder_module):
		return
	if _builder_module.has_method("focus_map"):
		_builder_module.call_deferred("focus_map")
	else:
		_builder_module.call_deferred("grab_focus")

func set_is_day(is_day: bool) -> void:
	var was_day_mode = _is_day_mode
	_is_day_mode = is_day
	if _day_status_label != null:
		if _is_day_mode:
			_day_status_label.text = "DAY MODE"
			_day_status_label.modulate = Color(0.72, 0.94, 0.74, 1.0)
		else:
			_day_status_label.text = "NIGHT MODE"
			_day_status_label.modulate = Color(0.95, 0.66, 0.66, 1.0)
	if _builder_module != null and is_instance_valid(_builder_module) and _builder_module.has_method("set_day_mode"):
		_builder_module.call("set_day_mode", _is_day_mode)
	if was_day_mode and not _is_day_mode:
		_enforce_builder_night_lock()


# --- BUILDER UI LOGIC (Inner Window) ---

func refresh_from_state(state: Dictionary) -> void:
	if state.has("money"):
		_on_money_changed(int(state["money"]))
			
	if state.has("time"):
		var t = state["time"]
		if _clock_label != null and t.has("string"):
			_clock_label.text = t["string"]
		if t.has("is_night"):
			var is_night = t["is_night"]
			if is_night == _is_day_mode: # If night is true, day mode should be false
				set_is_day(not is_night)
	elif state.has("is_night"):
		var is_night_direct = bool(state["is_night"])
		if is_night_direct == _is_day_mode:
			set_is_day(not is_night_direct)


func _on_time_tick(hour: int, minute: int) -> void:
	if _clock_label != null:
		_clock_label.text = "%02d:%02d" % [hour, minute]
	var now_min = hour * 60 + minute
	var day_start_min = int(BALANCE_CONFIG.DAY_START_HOUR * 60.0)
	var night_start_min = int(BALANCE_CONFIG.NIGHT_START_HOUR * 60)
	var is_night = (now_min >= night_start_min or now_min < day_start_min)
	if is_night == _is_day_mode:
		set_is_day(not is_night)
	_refresh_status_app_content()
	_refresh_finance_app_content()
	_refresh_guestrack_app_content()

# Retained for compatibility if needed, or redirect
func _on_money_changed(amount: int) -> void:
	if _builder_module != null and is_instance_valid(_builder_module) and _builder_module.has_method("_on_money_changed"):
		_builder_module.call("_on_money_changed", amount)
	_refresh_finance_app_content()

func _make_panel_style(bg: Color, border: Color, border_width: int = 2, corner_radius: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func _apply_button_style(btn: Button, base_color: Color, text_color: Color = COL_OS_TEXT_DARK) -> void:
	if btn == null:
		return
	var normal = _make_panel_style(base_color, base_color.darkened(0.34), 2, 0)
	var hover = _make_panel_style(base_color.lightened(0.08), base_color.darkened(0.26), 2, 0)
	var pressed = _make_panel_style(base_color.darkened(0.14), base_color.darkened(0.42), 2, 0)
	var disabled = _make_panel_style(base_color.darkened(0.24), base_color.darkened(0.44), 2, 0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_color_override("font_disabled_color", text_color.darkened(0.45))


func _apply_titlebar_button_style(btn: Button, is_close: bool = false) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.clip_text = false
	btn.add_theme_constant_override("h_separation", 0)
	btn.add_theme_font_size_override("font_size", 13)
	if is_close:
		_apply_button_style(btn, Color(0.60, 0.28, 0.22, 1.0), COL_OS_TEXT_LIGHT)
		return
	_apply_button_style(btn, COL_WIN98_TITLE.lightened(0.18), Color(0.95, 0.90, 0.78, 1.0))


func _apply_win95_button_style(btn: Button, text_color: Color = COL_OS_TEXT_DARK) -> void:
	if btn == null:
		return
	var base = COL_OS_WINDOW_BG
	var normal = _make_panel_style(base, COL_OS_BORDER.darkened(0.08), 2, 0)
	var hover = _make_panel_style(base.lightened(0.06), COL_OS_BORDER.darkened(0.02), 2, 0)
	var pressed = _make_panel_style(base.darkened(0.10), COL_OS_BORDER.darkened(0.14), 2, 0)
	var disabled = _make_panel_style(base.darkened(0.16), COL_OS_BORDER.darkened(0.20), 2, 0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_color_override("font_disabled_color", text_color.darkened(0.45))


# --- UI CONSTRUCTION ---
func _build_os_structure() -> void:
	# 1. Overlay Background
	_black_bg = ColorRect.new()
	_black_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black_bg.color = Color(0, 0, 0, 0.8)
	add_child(_black_bg)

	_os_canvas = Control.new()
	_os_canvas.name = "OSCanvas"
	_os_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_os_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_os_canvas.position = Vector2.ZERO
	_os_canvas.size = OS_DESIGN_SIZE
	add_child(_os_canvas)

	# 2. Boot UI
	_boot_ui = Control.new()
	_boot_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_os_canvas.add_child(_boot_ui)

	# BIOS badge cards (logo image with text fallback).
	_boot_ui.add_child(_make_boot_badge("AWARD BIOS", ASSET_BIOS_BADGE_AWARD, Vector2(16, 8), Vector2(152, 52), false, false))
	_boot_ui.add_child(_make_boot_badge("MICRO-STAR", ASSET_BIOS_BADGE_MICRO, Vector2(-332, 4), Vector2(322, 126), true, false))

	_boot_label = Label.new()
	_boot_label.add_theme_font_size_override("font_size", 16)
	_boot_label.add_theme_color_override("font_color", COL_BIOS_TEXT)
	_boot_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_label.offset_left = 20.0
	_boot_label.offset_top = 136.0
	_boot_label.offset_right = -18.0
	_boot_label.offset_bottom = -18.0
	_boot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boot_ui.add_child(_boot_label)

	# 3. Splash UI
	var splash_composite_tex := _safe_load_texture(ASSET_SPLASH_COMPOSITE)
	var splash_fallback_tex := splash_composite_tex
	if splash_fallback_tex == null:
		splash_fallback_tex = _safe_load_texture(ASSET_SPLASH)

	_splash_ui = TextureRect.new()
	_splash_ui.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash_ui.texture = null
	_splash_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash_ui.stretch_mode = TextureRect.STRETCH_SCALE
	_splash_ui.self_modulate = Color(0.18, 0.24, 0.20, 1.0)
	_splash_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_splash_canvas = Control.new()
	_splash_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_ui.add_child(_splash_canvas)

	_splash_background = TextureRect.new()
	_splash_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_splash_background.texture = _safe_load_texture(ASSET_SPLASH_BG_LAYER)
	if _splash_background.texture == null:
		_splash_background.texture = splash_fallback_tex
	_splash_canvas.add_child(_splash_background)

	_splash_logo = TextureRect.new()
	_splash_logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_splash_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash_logo.stretch_mode = TextureRect.STRETCH_SCALE
	_splash_logo.texture = _safe_load_texture(ASSET_SPLASH_LOGO_LAYER)
	_splash_canvas.add_child(_splash_logo)

	_splash_text = TextureRect.new()
	_splash_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash_text.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash_text.stretch_mode = TextureRect.STRETCH_SCALE
	_splash_text.texture = _safe_load_texture(ASSET_SPLASH_TEXT_LAYER)
	_splash_canvas.add_child(_splash_text)

	_splash_progress_track = ColorRect.new()
	_splash_progress_track.color = Color(0.05, 0.03, 0.02, 0.34)
	_splash_progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_canvas.add_child(_splash_progress_track)

	_splash_progress_clip = Control.new()
	_splash_progress_clip.clip_contents = true
	_splash_progress_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_canvas.add_child(_splash_progress_clip)

	_splash_progress_fill = TextureRect.new()
	_splash_progress_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash_progress_fill.stretch_mode = TextureRect.STRETCH_SCALE
	var bar_inner_rect: Rect2 = _get_splash_bar_inner_rect()
	_splash_progress_fill.texture = _safe_load_texture_region(ASSET_SPLASH_BAR_FILL_LAYER, SPLASH_BAR_SOURCE_RECT)
	if _splash_progress_fill.texture == null:
		_splash_progress_fill.texture = _safe_load_texture(ASSET_SPLASH_BAR_FILL_LAYER)
	_splash_progress_fill.size = bar_inner_rect.size
	_splash_progress_clip.add_child(_splash_progress_fill)

	_start_splash_animation()
	_os_canvas.add_child(_splash_ui)

	# 4. Desktop UI
	_desktop_ui = Control.new()
	_desktop_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_os_canvas.add_child(_desktop_ui)

	# Wallpaper
	var wall = TextureRect.new()
	wall.texture = _safe_load_texture(ASSET_WALLPAPER)
	if wall.texture == null:
		wall.texture = _safe_load_texture(ASSET_SPLASH)
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_desktop_ui.add_child(wall)
	_desktop_wallpaper = wall

	var wall_tint = ColorRect.new()
	wall_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall_tint.color = Color(0.20, 0.16, 0.10, 0.26)
	wall_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop_ui.add_child(wall_tint)

	var wall_noise = ColorRect.new()
	wall_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall_noise.color = Color(0.94, 0.88, 0.74, 0.04)
	wall_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop_ui.add_child(wall_noise)

	_desktop_boot_overlay = ColorRect.new()
	_desktop_boot_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desktop_boot_overlay.color = COL_OS_TRANSITION_FLASH
	_desktop_boot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop_boot_overlay.visible = false
	_desktop_ui.add_child(_desktop_boot_overlay)

	# Desktop Icons Area
	_desktop_icons = Control.new()
	_desktop_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desktop_icons.add_theme_constant_override("margin_left", 20)
	_desktop_icons.add_theme_constant_override("margin_top", 20)
	_desktop_icons.add_theme_constant_override("margin_right", -20)
	_desktop_icons.add_theme_constant_override("margin_bottom", -40) # Leave space for taskbar
	_desktop_icons.mouse_filter = Control.MOUSE_FILTER_PASS
	_desktop_ui.add_child(_desktop_icons)
	_register_program_icon("builder", "Builder", Callable(self, "_open_builder_app"), "res://assets/textury/crt/icons/builder.png")
	_register_program_icon("guestrack", "GuestRack", Callable(self, "_open_guestrack_app"), "res://assets/textury/crt/icons/guestrack.png")
	_register_program_icon("camp_status", "Camp\nStatus", Callable(self, "_open_status_app"), "res://assets/textury/crt/icons/campstat.png")
	_register_program_icon("finance", "Finance", Callable(self, "_open_finance_app"), "res://assets/textury/crt/icons/finance.png")
	_register_program_icon("minesweeper", "Minesweeper", Callable(self, "_open_minesweeper_app"), "res://assets/textury/crt/icons/minesweeper.png")
	_register_program_icon("campmail", "CampMail", Callable(self, "_open_email_app"), "res://assets/textury/crt/icons/email.png")
	_register_program_icon("beeternet", "Beeternet", Callable(self, "_open_beeternet_app"), ASSET_ICON_BEETERNET)
	_register_program_icon("downloads", "Downloads", Callable(self, "_open_downloads_folder"), ASSET_ICON_DOWNLOADS)
	var _bin_icon_container = _register_program_icon("bin", "Bin", Callable(self, "_open_bin_folder"), ASSET_ICON_BIN_EMPTY)
	if _bin_icon_container != null:
		_bin_icon_img = _bin_icon_container.get_child(0) as TextureRect
	_build_desktop_clutter()

	# Top status bar (above everything except windows — added after clutter so it draws on top)
	_build_top_status_bar()

	# Window Layer
	_window_layer = Control.new()
	_window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_layer.visible = false
	_desktop_ui.add_child(_window_layer)

	# Taskbar — Win95-style raised 3D bar
	_taskbar = Panel.new()
	_taskbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_taskbar.offset_top = -DESKTOP_TASKBAR_HEIGHT
	_taskbar.offset_bottom = 0
	var tb_style = _make_panel_style(COL_OS_WINDOW_BG.darkened(0.04), COL_OS_BORDER, 0, 0)
	_taskbar.add_theme_stylebox_override("panel", tb_style)
	_desktop_ui.add_child(_taskbar)

	# ── START BUTTON ──────────────────────────────────────────────────────────
	# Pixel-art sprite (203x64) with baked raised effect, no extra runtime shadow.
	const ASSET_START_BUTTON := "res://assets/textury/crt/UI/start.png"
	_start_button = Button.new()
	_start_button.text = ""
	# Anchored top-to-bottom in taskbar so button height always matches taskbar height.
	_start_button.anchor_left   = 0.0
	_start_button.anchor_right  = 0.0
	_start_button.anchor_top    = 0.0
	_start_button.anchor_bottom = 1.0
	_start_button.offset_left   = 2.0
	_start_button.offset_right  = 78.0   # left + 76
	_start_button.offset_top    = 0.0
	_start_button.offset_bottom = 0.0
	_start_button.focus_mode = Control.FOCUS_NONE
	var start_tex := _safe_load_texture(ASSET_START_BUTTON)
	if start_tex:
		# StyleBoxTexture stretches texture to fill button rect — no aspect-ratio padding
		var sbn := StyleBoxTexture.new()
		sbn.texture = start_tex
		sbn.set_content_margin_all(0)
		_start_button.add_theme_stylebox_override("normal", sbn)
		var sbh := StyleBoxTexture.new()
		sbh.texture = start_tex
		sbh.set_content_margin_all(0)
		sbh.modulate_color = Color(1.18, 1.18, 1.18)
		_start_button.add_theme_stylebox_override("hover", sbh)
		var sbp := StyleBoxTexture.new()
		sbp.texture = start_tex
		sbp.set_content_margin_all(0)
		sbp.modulate_color = Color(0.78, 0.78, 0.78)
		_start_button.add_theme_stylebox_override("pressed", sbp)
		_start_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	else:
		# Fallback: programmatic style when sprite not found
		_start_button.text = " START"
		var start_normal := StyleBoxFlat.new()
		start_normal.bg_color = Color(0.68, 0.62, 0.50)
		start_normal.border_color = Color(0.24, 0.18, 0.10)
		start_normal.set_border_width_all(2)
		_start_button.add_theme_stylebox_override("normal", start_normal)
		var start_hover := StyleBoxFlat.new()
		start_hover.bg_color = Color(0.76, 0.70, 0.58)
		start_hover.border_color = Color(0.24, 0.18, 0.10)
		start_hover.set_border_width_all(2)
		_start_button.add_theme_stylebox_override("hover", start_hover)
		var start_pressed := StyleBoxFlat.new()
		start_pressed.bg_color = Color(0.54, 0.48, 0.38)
		start_pressed.border_color = Color(0.18, 0.12, 0.07)
		start_pressed.set_border_width_all(2)
		_start_button.add_theme_stylebox_override("pressed", start_pressed)
		var fallback_icon := _safe_load_texture_scaled(ASSET_ICON_PC, 16, 16)
		if fallback_icon:
			_start_button.icon = fallback_icon
			_start_button.add_theme_constant_override("h_separation", 5)
		_start_button.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02))
		_start_button.add_theme_font_size_override("font_size", 13)
	_start_button.pressed.connect(_toggle_start_menu)
	_taskbar.add_child(_start_button)

	_taskbar_container = HBoxContainer.new()
	_taskbar_container.position = Vector2(94, 1)
	_taskbar_container.size = Vector2(500, DESKTOP_TASKBAR_HEIGHT)
	_taskbar_container.add_theme_constant_override("separation", 2)
	_taskbar_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_taskbar.add_child(_taskbar_container)

	# Tray separator — vertical divider before the clock
	var tray_sep = ColorRect.new()
	tray_sep.anchor_left = 1.0; tray_sep.anchor_right = 1.0
	tray_sep.position = Vector2(-76, 3)
	tray_sep.size = Vector2(1, 24)
	tray_sep.color = Color(0.34, 0.32, 0.28)
	_taskbar.add_child(tray_sep)
	var tray_sep_hi = ColorRect.new()
	tray_sep_hi.anchor_left = 1.0; tray_sep_hi.anchor_right = 1.0
	tray_sep_hi.position = Vector2(-75, 3)
	tray_sep_hi.size = Vector2(1, 24)
	tray_sep_hi.color = Color(0.72, 0.70, 0.64)
	_taskbar.add_child(tray_sep_hi)

	_clock_label = Label.new()
	_clock_label.anchor_left = 1.0; _clock_label.anchor_right = 1.0
	_clock_label.position = Vector2(-68, 5)
	_clock_label.add_theme_color_override("font_color", COL_OS_TEXT_DARK)
	_clock_label.add_theme_font_size_override("font_size", 12)
	_taskbar.add_child(_clock_label)

	# _day_status_label is now owned by _build_top_status_bar()

	_build_start_menu()
	_build_ups_banner()
	_sync_all_program_visibility()
	_update_os_canvas_layout()


func _build_desktop_clutter() -> void:
	if _desktop_ui == null:
		return

	_desktop_fx_blink_nodes.clear()
	_desktop_fx_blink_tick = 0.36
	_desktop_fx_blink_state = true
	_desktop_marquee_label = null
	_desktop_badge_panel = null
	_desktop_badge_label = null
	_desktop_email_panel = null
	_desktop_email_label = null
	_desktop_under_panel = null
	_desktop_under_label = null
	_desktop_sparkle_label = null
	_desktop_marquee_left_bound = 0.0
	_desktop_marquee_right_bound = 0.0

	var clutter = Control.new()
	clutter.name = "DreamClutter"
	clutter.set_anchors_preset(Control.PRESET_FULL_RECT)
	clutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop_clutter = clutter
	_desktop_ui.add_child(clutter)

	var tile_palette = [
		Color(0.40, 0.30, 0.18, 0.14),
		Color(0.34, 0.42, 0.24, 0.12),
		Color(0.50, 0.38, 0.22, 0.12),
		Color(0.24, 0.30, 0.24, 0.10),
		Color(0.44, 0.28, 0.22, 0.10),
	]
	for y in range(0, 9):
		for x in range(0, 11):
			if (x + y) % 2 == 0:
				continue
			var tile = ColorRect.new()
			tile.position = Vector2(float(x) * 104.0 - 30.0, float(y) * 78.0 - 24.0)
			tile.size = Vector2(128.0, 92.0)
			tile.color = tile_palette[(x + y) % tile_palette.size()]
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clutter.add_child(tile)

	# badge, email and marquee are now owned by _build_top_status_bar()
	# DreamClutter keeps only the subtle wallpaper tile tinting


func _register_program_icon(app_id: String, label_text: String, on_pressed: Callable, icon_path: String = "") -> Control:
	var icon_node = _add_desktop_icon(label_text, on_pressed, icon_path)
	_desktop_program_icons[app_id] = icon_node
	_sync_program_visibility(app_id)
	return icon_node


func _register_program_menu_item(parent: VBoxContainer, app_id: String, text: String, callback: Callable, icon_path: String = "") -> Button:
	var item = _make_start_item(text, callback, icon_path)
	parent.add_child(item)
	_start_menu_program_items[app_id] = item
	_sync_program_visibility(app_id)
	return item


func _sync_program_visibility(app_id: String) -> void:
	var unlocked := _is_program_unlocked(app_id)
	if _desktop_program_icons.has(app_id):
		var icon_node = _desktop_program_icons[app_id] as Control
		if icon_node != null:
			icon_node.visible = unlocked
	if _start_menu_program_items.has(app_id):
		var menu_item = _start_menu_program_items[app_id] as Control
		if menu_item != null:
			menu_item.visible = unlocked
	_reflow_desktop_program_icons()


func _sync_all_program_visibility() -> void:
	for app_id in DEFAULT_UNLOCK_STATE.keys():
		var unlocked := _is_program_unlocked(app_id)
		if _desktop_program_icons.has(app_id):
			var icon_node = _desktop_program_icons[app_id] as Control
			if icon_node != null:
				icon_node.visible = unlocked
		if _start_menu_program_items.has(app_id):
			var menu_item = _start_menu_program_items[app_id] as Control
			if menu_item != null:
				menu_item.visible = unlocked
	_reflow_desktop_program_icons()


func _reflow_desktop_program_icons() -> void:
	var used_slots: Dictionary = {}
	# Keep existing slot assignment for visible icons so unlock events do not reshuffle layout.
	for app_id in DESKTOP_ICON_ORDER:
		if not _desktop_program_icons.has(app_id):
			continue
		var icon_node = _desktop_program_icons[app_id] as Control
		if icon_node == null or not icon_node.visible:
			continue
		if not icon_node.has_meta(DESKTOP_ICON_SLOT_META):
			continue
		var slot := int(icon_node.get_meta(DESKTOP_ICON_SLOT_META, -1))
		if slot < 0 or used_slots.has(slot):
			icon_node.remove_meta(DESKTOP_ICON_SLOT_META)
			continue
		used_slots[slot] = true

	# Assign slot only to icons that do not have one yet (typically newly unlocked apps).
	for app_id in DESKTOP_ICON_ORDER:
		if not _desktop_program_icons.has(app_id):
			continue
		var icon_node = _desktop_program_icons[app_id] as Control
		if icon_node == null or not icon_node.visible:
			continue
		if icon_node.has_meta(DESKTOP_ICON_SLOT_META):
			continue
		var slot := _next_free_desktop_icon_slot(used_slots)
		icon_node.set_meta(DESKTOP_ICON_SLOT_META, slot)
		used_slots[slot] = true

	# Apply slot position only to non-dragged icons.
	for app_id in DESKTOP_ICON_ORDER:
		if not _desktop_program_icons.has(app_id):
			continue
		var icon_node = _desktop_program_icons[app_id] as Control
		if icon_node == null or not icon_node.visible:
			continue
		if icon_node.has_meta("custom_pos"):
			continue
		var slot := int(icon_node.get_meta(DESKTOP_ICON_SLOT_META, -1))
		if slot < 0:
			slot = _next_free_desktop_icon_slot(used_slots)
			icon_node.set_meta(DESKTOP_ICON_SLOT_META, slot)
			used_slots[slot] = true
		icon_node.position = _desktop_icon_slot_to_position(slot)


func _next_free_desktop_icon_slot(used_slots: Dictionary) -> int:
	var slot := 0
	while used_slots.has(slot):
		slot += 1
	return slot


func _desktop_icon_slot_to_position(slot: int) -> Vector2:
	var icon_top := DESKTOP_TOP_BAR_HEIGHT + DESKTOP_ICON_TOP_OFFSET
	var col0 := DESKTOP_ICON_COL0_X
	var col1 := col0 + DESKTOP_ICON_COLUMN_GAP
	var row := int(floor(float(slot) / 2.0))
	var col_x := col0 if (slot % 2) == 0 else col1
	return Vector2(col_x, icon_top + float(row) * DESKTOP_ICON_ROW_GAP)


func _add_desktop_icon(label_text: String, on_pressed: Callable, icon_path: String = "") -> Control:
	# Win95-style: bare icon + text-shadow label, no border box
	var container = Control.new()
	container.position = Vector2.ZERO
	container.size = DESKTOP_ICON_CONTAINER_SIZE
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var img = TextureRect.new()
	var final_icon_path = icon_path if not icon_path.is_empty() else ASSET_ICON_PC
	var icon_tex = _safe_load_texture(final_icon_path)
	if icon_tex == null and final_icon_path != ASSET_ICON_PC:
		icon_tex = _safe_load_texture(ASSET_ICON_PC)
	if icon_tex:
		img.texture = icon_tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.position = DESKTOP_ICON_TEXTURE_OFFSET
	img.size = DESKTOP_ICON_TEXTURE_SIZE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(img)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, DESKTOP_ICON_LABEL_Y)
	lbl.size = Vector2(DESKTOP_ICON_CONTAINER_SIZE.x, DESKTOP_ICON_LABEL_H)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)

	_desktop_icons.add_child(container)

	container.gui_input.connect(func(ev: InputEvent) -> void:
		_on_desktop_icon_input(ev, container, on_pressed))
	return container


func _on_desktop_icon_input(event: InputEvent, icon: Control, on_pressed: Callable) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging_icon = icon
		_dragging_icon_callback = on_pressed
		_dragging_icon_offset = icon.get_local_mouse_position()
		_icon_press_global_start = get_global_mouse_position()
		_icon_has_dragged = false
		icon.move_to_front()
		icon.modulate = Color(1.0, 1.0, 1.0, 0.72)
	get_viewport().set_input_as_handled()


func _safe_load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.is_empty():
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		err = image.load_png_from_buffer(bytes)
	elif bytes.size() >= 2 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = image.load_jpg_from_buffer(bytes)
	else:
		err = image.load(abs_path)
	if err == OK and not image.is_empty():
		return ImageTexture.create_from_image(image)
	return null


func _safe_load_texture_scaled(path: String, width: int, height: int) -> Texture2D:
	if path.is_empty():
		return null
	var abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var image := Image.new()
	var err := image.load(abs_path)
	if err != OK or image.is_empty():
		return null
	image.resize(max(1, width), max(1, height), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _safe_load_texture_region(path: String, region: Rect2) -> Texture2D:
	if path.is_empty():
		return null
	var abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var image := Image.new()
	var err := image.load(abs_path)
	if err != OK or image.is_empty():
		return null
	var x := int(clamp(region.position.x, 0.0, float(max(image.get_width() - 1, 0))))
	var y := int(clamp(region.position.y, 0.0, float(max(image.get_height() - 1, 0))))
	var w := int(clamp(region.size.x, 1.0, float(image.get_width() - x)))
	var h := int(clamp(region.size.y, 1.0, float(image.get_height() - y)))
	var cropped := image.get_region(Rect2i(x, y, w, h))
	if cropped == null or cropped.is_empty():
		return null
	return ImageTexture.create_from_image(cropped)


func _setup_audio() -> void:
	_transition_sfx_player = AudioStreamPlayer.new()
	_transition_sfx_player.name = "DesktopTransitionSfx"
	_transition_sfx_player.volume_db = -7.0
	_transition_sfx_player.stream = _safe_load_audio(SFX_TUDU_TRANSITION)
	add_child(_transition_sfx_player)

	_notification_sfx_player = AudioStreamPlayer.new()
	_notification_sfx_player.name = "DesktopEmailSfx"
	_notification_sfx_player.volume_db = -8.0
	var radio_bus_index = AudioServer.get_bus_index("Radio")
	if radio_bus_index >= 0:
		_notification_sfx_player.bus = "Radio"
	else:
		_notification_sfx_player.bus = "Master"
	_notification_sfx_player.stream = _safe_load_audio(SFX_EMAIL_NOTIFICATION)
	add_child(_notification_sfx_player)

	_click_sfx_player = AudioStreamPlayer.new()
	_click_sfx_player.name = "DesktopClickSfx"
	_click_sfx_player.volume_db = -18.0
	_click_sfx_player.stream = _safe_load_audio(SFX_CLICK_PLACEHOLDER)
	add_child(_click_sfx_player)


func _safe_load_audio(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var stream = load(path) as AudioStream
		if stream != null:
			return stream
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	if path.get_extension().to_lower() == "mp3":
		var bytes := FileAccess.get_file_as_bytes(abs_path)
		if bytes.is_empty():
			return null
		var mp3 := AudioStreamMP3.new()
		mp3.data = bytes
		return mp3
	return null


func _play_tudu_transition() -> void:
	if _transition_sfx_player == null or _transition_sfx_player.stream == null:
		return
	_transition_sfx_player.stop()
	_transition_sfx_player.play()


func _play_email_notification() -> void:
	if not is_desktop_ready():
		return
	if _notification_sfx_player == null or _notification_sfx_player.stream == null:
		return
	_notification_sfx_player.volume_db = _resolve_email_notification_volume_db()
	_notification_sfx_player.stop()
	_notification_sfx_player.play()


func _resolve_email_notification_volume_db() -> float:
	if _interior_host != null and is_instance_valid(_interior_host):
		if _interior_host.has_method("get_radio_notification_volume_db"):
			return float(_interior_host.call("get_radio_notification_volume_db"))
	return -8.0


func _on_email_received(mail: Dictionary) -> void:
	_email_update_unread_indicator(EmailManager.get_unread_count())
	_play_email_notification()
	if _current_state == os_state.DESKTOP:
		_show_email_toast(mail)
	if _app_windows.has("email"):
		var email_win = _app_windows["email"] as Panel
		if email_win != null and is_instance_valid(email_win) and email_win.visible:
			_email_refresh_list()


func _show_email_toast(mail: Dictionary) -> void:
	if _desktop_ui == null:
		return
	if _email_toast_panel == null:
		_build_email_toast()
	if _email_toast_panel == null or _email_toast_label == null:
		return
	var sender = _mail_sender_short(str(mail.get("from", "Unknown")))
	var subject = _mail_subject_short(str(mail.get("subject", "(no subject)")))
	_email_toast_label.text = "[NEW EMAIL]\\n%s\\n%s" % [sender, subject]
	_email_toast_panel.visible = true
	_email_toast_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_email_toast_panel.move_to_front()
	_email_toast_time_left = EMAIL_TOAST_VISIBLE_SEC
	_layout_email_toast(_get_layout_size())


func _build_email_toast() -> void:
	if _desktop_ui == null or (_email_toast_panel != null and is_instance_valid(_email_toast_panel)):
		return
	var toast = Panel.new()
	toast.name = "EmailToast"
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.14, 0.16, 0.18, 0.96), Color(0.58, 0.66, 0.78, 1.0), 1, 0)
	)
	_desktop_ui.add_child(toast)
	_email_toast_panel = toast

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 8.0
	label.offset_top = 6.0
	label.offset_right = -8.0
	label.offset_bottom = -6.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	toast.add_child(label)
	_email_toast_label = label


func _layout_email_toast(vp: Vector2) -> void:
	if _email_toast_panel == null:
		return
	var width = clampf(vp.x * 0.30, 280.0, 400.0)
	_email_toast_panel.size = Vector2(width, 72.0)
	_email_toast_panel.position = Vector2(
		vp.x - width - 10.0,
		DESKTOP_TOP_BAR_HEIGHT + 10.0
	)


func _build_ups_banner() -> void:
	if _desktop_ui == null or (_ups_banner_panel != null and is_instance_valid(_ups_banner_panel)):
		return
	var banner := Panel.new()
	banner.name = "UPSBanner"
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.66, 0.13, 0.10, 0.98), Color(1.0, 0.84, 0.52, 1.0), 2, 0)
	)
	_desktop_ui.add_child(banner)
	_ups_banner_panel = banner

	var label := Label.new()
	label.name = "UPSBannerLabel"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 12.0
	label.offset_top = 8.0
	label.offset_right = -12.0
	label.offset_bottom = -8.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	banner.add_child(label)
	_ups_banner_label = label


func _layout_ups_banner(vp: Vector2) -> void:
	if _ups_banner_panel == null:
		return
	var width := maxf(320.0, vp.x - 20.0)
	_ups_banner_panel.size = Vector2(width, UPS_BANNER_HEIGHT)
	_ups_banner_panel.position = Vector2(
		(vp.x - width) * 0.5,
		vp.y - DESKTOP_TASKBAR_HEIGHT - UPS_BANNER_HEIGHT - UPS_BANNER_BOTTOM_MARGIN
	)


func _resolve_electricity_host() -> Node:
	if _interior_host != null and is_instance_valid(_interior_host):
		var cursor: Node = _interior_host
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


func _update_ups_banner_from_runtime(delta: float) -> void:
	if _current_state != os_state.DESKTOP:
		if _ups_banner_panel != null:
			_ups_banner_panel.visible = false
		_ups_banner_active = false
		return
	var host := _resolve_electricity_host()
	if host == null or not host.has_method("get_electricity_ui_snapshot"):
		if _ups_banner_panel != null:
			_ups_banner_panel.visible = false
		_ups_banner_active = false
		return
	var snapshot_any = host.call("get_electricity_ui_snapshot")
	if not (snapshot_any is Dictionary):
		if _ups_banner_panel != null:
			_ups_banner_panel.visible = false
		_ups_banner_active = false
		return
	var snapshot := snapshot_any as Dictionary
	var ups_active := bool(snapshot.get("ups_active", false))
	var seconds_left := maxf(0.0, float(snapshot.get("ups_seconds_left", 0.0)))
	_ups_banner_active = ups_active
	_ups_banner_seconds_left = seconds_left
	if _ups_banner_panel == null or _ups_banner_label == null:
		return
	_ups_banner_panel.visible = _ups_banner_active
	if not _ups_banner_active:
		return
	var sec := maxi(0, int(ceil(_ups_banner_seconds_left)))
	var mm := sec / 60
	var ss := sec % 60
	_ups_banner_label.text = "UPS BACKUP ACTIVE  --  PAY OVERDUE ELECTRICITY BILLS  --  SHUTDOWN IN %02d:%02d" % [mm, ss]
	_ups_banner_blink_timer += maxf(delta, 0.0)
	if _ups_banner_blink_timer >= UPS_BANNER_BLINK_PERIOD:
		_ups_banner_blink_timer = 0.0
	var blink_phase := absf(sin(_ups_banner_blink_timer * (TAU / UPS_BANNER_BLINK_PERIOD)))
	var alpha := lerpf(0.58, 1.0, blink_phase)
	_ups_banner_panel.modulate = Color(1.0, 1.0, 1.0, alpha)


func _mail_sender_short(raw_from: String) -> String:
	var sender = raw_from.strip_edges()
	if sender.contains("<"):
		sender = sender.split("<")[0].strip_edges()
	if sender.is_empty():
		sender = "Unknown sender"
	if sender.length() > 28:
		sender = sender.left(26) + ".."
	return sender


func _mail_subject_short(subject: String) -> String:
	var out = subject.strip_edges()
	if out.is_empty():
		out = "(no subject)"
	if out.length() > 44:
		out = out.left(42) + ".."
	return out


func _mail_time_to_minutes(raw_time: String) -> int:
	var parts = raw_time.split(":")
	if parts.size() < 2:
		return 0
	var hour = clampi(int(parts[0]), 0, 23)
	var minute = clampi(int(parts[1]), 0, 59)
	return (hour * 60) + minute


func _email_mail_sort_key(mail: Dictionary) -> int:
	var day = max(0, _email_stamp_day(mail))
	var minutes = _mail_time_to_minutes(str(mail.get("time", "00:00")))
	return (day * 1440) + minutes


func _email_mail_datetime_label(mail: Dictionary) -> String:
	return "Day %d  %s" % [_email_stamp_day(mail), str(mail.get("time", "??:??"))]


## The day printed on a mail. A story mail may carry `stamp_day_offset`: delivered on
## its day, stamped with a later one (the night log that arrives dated tomorrow).
func _email_stamp_day(mail: Dictionary) -> int:
	return int(mail.get("day", 0)) + int(mail.get("stamp_day_offset", 0))


func _email_mail_snippet(mail: Dictionary) -> String:
	var body = str(mail.get("body", "")).strip_edges()
	if body.is_empty():
		return ""
	body = body.replace("\n", " ").replace("\t", " ")
	while body.find("  ") >= 0:
		body = body.replace("  ", " ")
	if body.length() > 74:
		body = body.left(72) + ".."
	return body


func _email_is_booking_mail(mail: Dictionary) -> bool:
	var mail_type = str(mail.get("type", "")).to_lower().strip_edges()
	return mail_type == "guest" or mail_type == "customer"


func _email_customer_panel_text(mail: Dictionary) -> String:
	if not _email_is_booking_mail(mail):
		return ""
	if EmailManager == null or not EmailManager.has_method("get_customer_panel_data"):
		return ""
	var panel_any = EmailManager.get_customer_panel_data(mail)
	if not (panel_any is Dictionary):
		return ""
	var panel: Dictionary = panel_any
	if panel.is_empty():
		return ""

	var guest_name = str(panel.get("guest_name", "Guest")).strip_edges()
	if guest_name.is_empty():
		guest_name = "Guest"
	var party_size = max(1, int(panel.get("party_size", mail.get("guests", 1))))
	var stay_nights = max(1, int(panel.get("stay_nights", mail.get("nights", 1))))
	var arrival_time = str(panel.get("arrival_time", mail.get("arrival_time", "10:00")))
	var difficulty = clampi(int(panel.get("difficulty", mail.get("difficulty", 1))), 1, 5)
	var archetype = str(panel.get("archetype_label", panel.get("archetype", mail.get("archetype", "customer")))).strip_edges()
	var daily_total = max(0, int(panel.get("daily_total", mail.get("daily_total", 0))))
	var trouble_time = str(panel.get("night_trouble_time", mail.get("night_trouble_time", ""))).strip_edges()

	var lines: Array[String] = []
	lines.append("=== CUSTOMER PANEL ===")
	lines.append("Guest: %s" % guest_name)
	lines.append("Archetype: %s" % archetype)
	lines.append("Party size: %d" % party_size)
	lines.append("Stay nights: %d" % stay_nights)
	lines.append("Arrival: %s" % arrival_time)
	lines.append("Difficulty: %d/5" % difficulty)
	lines.append("Payment per day: $%d" % daily_total)
	lines.append("Total if accepted: $%d" % (daily_total * stay_nights))
	if not trouble_time.is_empty():
		lines.append("Night trouble window: ~%s" % trouble_time)

	var risk_lines := _email_liminal_impact_lines(panel, mail, party_size)
	if not risk_lines.is_empty():
		lines.append("")
		lines.append_array(risk_lines)
	return "\n".join(lines)


## The risk half of the accept/reject trade. Without this the player sees only the
## payout and is making the game's core decision blind.
func _email_liminal_impact_lines(panel: Dictionary, mail: Dictionary, party_size: int) -> Array[String]:
	var out: Array[String] = []
	if GuestManager == null or not GuestManager.has_method("get_liminal_booking_impact"):
		return out
	var raw_archetype := str(panel.get("archetype", mail.get("archetype", ""))).strip_edges()
	if raw_archetype.is_empty():
		return out

	var impact_any = GuestManager.call("get_liminal_booking_impact", raw_archetype, party_size)
	if not (impact_any is Dictionary):
		return out
	var impact: Dictionary = impact_any

	var label := str(impact.get("label", raw_archetype))
	var safe := int(impact.get("safe_count", 3))
	var before := int(impact.get("current_count", 0))
	var after := int(impact.get("after_count", 0))

	out.append("=== NIGHT RISK ===")
	out.append("%s in camp: %d -> %d  (safe up to %d)" % [label, before, after, safe])

	var after_entry_any = impact.get("after", {})
	if not (after_entry_any is Dictionary):
		return out
	var after_entry: Dictionary = after_entry_any

	if int(after_entry.get("guaranteed_spawns", 0)) > 0:
		out.append("Result: SPAWN GUARANTEED tonight.")
		return out

	var tier := str(after_entry.get("chance_tier", "none"))
	if tier == "none" or tier.is_empty():
		out.append("Result: still within safe count.")
	else:
		var pct := int(round(float(after_entry.get("chance_probability", 0.0)) * 100.0))
		out.append("Result: %s spawn chance (~%d%%)." % [tier.to_upper(), pct])

	var thresholds_any = after_entry.get("next_thresholds", {})
	if thresholds_any is Dictionary:
		var thresholds: Dictionary = thresholds_any
		var guaranteed_at := int(thresholds.get("guaranteed_at", 0))
		if guaranteed_at > after:
			out.append("Guaranteed spawn at %d %s." % [guaranteed_at, label])
	return out


func _email_compose_preview_body(mail: Dictionary) -> String:
	var base_text = str(mail.get("body", "")).strip_edges()
	if base_text.is_empty():
		base_text = "(empty message)"

	var mail_type = str(mail.get("type", "")).to_lower().strip_edges()
	if mail_type == "spam":
		var banner_name = str(mail.get("banner_png", "")).strip_edges()
		if not banner_name.is_empty():
			base_text += "\n\n[SPAM BANNER] %s" % banner_name

	var customer_panel_text = _email_customer_panel_text(mail)
	if not customer_panel_text.is_empty():
		base_text += "\n\n" + customer_panel_text
	return base_text


func _play_click_sfx() -> void:
	if _click_sfx_player == null or _click_sfx_player.stream == null:
		return
	_click_sfx_player.stop()
	_click_sfx_player.play()


func _make_boot_badge(text: String, texture_path: String, pos: Vector2, badge_size: Vector2, align_right: bool, align_bottom: bool) -> Control:
	var badge = Control.new()
	badge.position = pos
	badge.size = badge_size
	if align_right:
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
	if align_bottom:
		badge.anchor_top = 1.0
		badge.anchor_bottom = 1.0

	var key_threshold := 0.06
	var key_softness := 0.06
	# Award logo has a dark matte around glyph edges; use a tighter key so the black blends cleanly with BIOS background.
	if texture_path == ASSET_BIOS_BADGE_AWARD:
		key_threshold = 0.10
		key_softness = 0.04
	var logo_tex: Texture2D = _safe_load_texture_with_black_key(texture_path, key_threshold, key_softness)
	if logo_tex == null:
		logo_tex = _safe_load_texture(texture_path)
	if logo_tex != null:
		var logo = TextureRect.new()
		logo.set_anchors_preset(Control.PRESET_FULL_RECT)
		logo.offset_left = 0.0
		logo.offset_top = 0.0
		logo.offset_right = 0.0
		logo.offset_bottom = 0.0
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(logo)
	else:
		var label = Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = text
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
		badge.add_child(label)
	return badge


func _safe_load_texture_with_black_key(path: String, threshold: float = 0.055, softness: float = 0.045) -> Texture2D:
	if path.is_empty():
		return null
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var bytes := FileAccess.get_file_as_bytes(abs_path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	var err := ERR_INVALID_DATA
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		err = image.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47 and bytes[4] == 0x0D and bytes[5] == 0x0A and bytes[6] == 0x1A and bytes[7] == 0x0A:
		err = image.load_png_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46 and bytes[8] == 0x57 and bytes[9] == 0x45 and bytes[10] == 0x42 and bytes[11] == 0x50:
		err = image.load_webp_from_buffer(bytes)
	else:
		err = image.load_png_from_buffer(bytes)
		if err != OK:
			err = image.load_jpg_from_buffer(bytes)
		if err != OK:
			err = image.load_webp_from_buffer(bytes)
	if err != OK or image.is_empty():
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var w: int = image.get_width()
	var h: int = image.get_height()
	var safe_softness: float = max(0.001, softness)
	var upper: float = threshold + safe_softness
	for y in range(h):
		for x in range(w):
			var c: Color = image.get_pixel(x, y)
			var luma_key: float = maxf(c.r, maxf(c.g, c.b))
			if luma_key <= threshold:
				c.a = 0.0
			elif luma_key < upper:
				var alpha_scale: float = (luma_key - threshold) / safe_softness
				c.a *= alpha_scale
				# Remove black matte from antialiased edge pixels to avoid dark halo over BIOS black.
				if alpha_scale > 0.001 and alpha_scale < 1.0:
					var inv = 1.0 / alpha_scale
					c.r = clampf(c.r * inv, 0.0, 1.0)
					c.g = clampf(c.g * inv, 0.0, 1.0)
					c.b = clampf(c.b * inv, 0.0, 1.0)
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)


func _build_top_status_bar() -> void:
	# --- Outer panel ---
	var bar = Panel.new()
	bar.name = "TopStatusBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = DESKTOP_TOP_BAR_HEIGHT
	var bar_style = _make_panel_style(Color(0.13, 0.15, 0.17, 0.97), Color(0.30, 0.36, 0.42, 1.0), 1, 0)
	bar_style.border_width_top = 0
	bar_style.border_width_left = 0
	bar_style.border_width_right = 0
	bar_style.border_width_bottom = 1
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop_ui.add_child(bar)
	_top_status_bar = bar

	# --- Left: node identifier (static, amber-tinted) ---
	var node_lbl = Label.new()
	node_lbl.text = "CAMP-NODE-04 ::"
	node_lbl.position = Vector2(8, 4)
	node_lbl.add_theme_font_size_override("font_size", 11)
	node_lbl.add_theme_color_override("font_color", Color(0.70, 0.80, 0.88, 0.86))
	bar.add_child(node_lbl)

	# --- Center: ticker clip container (scrolling marquee stays clipped here) ---
	var clip = Control.new()
	clip.name = "TickerClip"
	clip.clip_contents = true
	clip.position = Vector2(DESKTOP_TOP_BAR_NODE_LABEL_W, 1)
	clip.size = Vector2(900, DESKTOP_TOP_BAR_HEIGHT - 2)
	bar.add_child(clip)
	_top_bar_ticker_clip = clip

	var ticker = Label.new()
	ticker.text = "  [ LIVE ] CAMP DVR 56k CONNECTED :: WEATHER: CLEAR + DRY WIND :: RADIO: TURBOFOLK FM ::  "
	ticker.position = Vector2(900, 4)
	ticker.size = Vector2(1800, 16)
	ticker.add_theme_font_size_override("font_size", 11)
	ticker.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96))
	clip.add_child(ticker)
	_desktop_marquee_label = ticker
	_desktop_marquee_left_bound = 0.0
	_desktop_marquee_right_bound = 900.0

	# --- Right tray separator ---
	var sep_line = ColorRect.new()
	sep_line.anchor_left = 1.0
	sep_line.anchor_right = 1.0
	sep_line.position = Vector2(-DESKTOP_TOP_BAR_TRAY_W - 1.0, 3)
	sep_line.size = Vector2(1, DESKTOP_TOP_BAR_HEIGHT - 6)
	sep_line.color = Color(0.38, 0.46, 0.54, 0.76)
	bar.add_child(sep_line)

	# --- Day / Night mode indicator ---
	_day_status_label = Label.new()
	_day_status_label.anchor_left = 1.0
	_day_status_label.anchor_right = 1.0
	_day_status_label.position = Vector2(
		-DESKTOP_TOP_BAR_TRAY_W + 8.0,
		4.0
	)
	_day_status_label.size = Vector2(DESKTOP_TOP_BAR_DAY_W, 16.0)
	_day_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_day_status_label.clip_text = true
	_day_status_label.add_theme_font_size_override("font_size", 10)
	_day_status_label.add_theme_color_override("font_color", Color(0.70, 0.92, 0.76))
	bar.add_child(_day_status_label)

	# --- Email indicator (clickable button styled as label) ---
	var email_ind = Button.new()
	email_ind.text = "MAIL --"
	email_ind.flat = true
	email_ind.focus_mode = Control.FOCUS_NONE
	email_ind.anchor_left = 1.0
	email_ind.anchor_right = 1.0
	email_ind.position = Vector2(
		-DESKTOP_TOP_BAR_EMAIL_W - DESKTOP_TOP_BAR_EMAIL_RIGHT_MARGIN,
		1.0
	)
	email_ind.size = Vector2(DESKTOP_TOP_BAR_EMAIL_W, 20.0)
	email_ind.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	email_ind.clip_text = true
	email_ind.add_theme_font_size_override("font_size", 10)
	email_ind.add_theme_color_override("font_color", Color(0.98, 0.88, 0.62))
	email_ind.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.82))
	var _email_btn_style = StyleBoxEmpty.new()
	email_ind.add_theme_stylebox_override("normal", _email_btn_style)
	email_ind.add_theme_stylebox_override("hover", _email_btn_style)
	email_ind.add_theme_stylebox_override("pressed", _email_btn_style)
	email_ind.add_theme_stylebox_override("focus", _email_btn_style)
	email_ind.pressed.connect(_open_email_app)
	bar.add_child(email_ind)
	_top_bar_email_indicator = email_ind
	_register_desktop_blink(email_ind)
	# Wire unread count updates
	if EmailManager.has_signal("unread_count_changed"):
		var unread_cb = Callable(self, "_email_update_unread_indicator")
		if not EmailManager.unread_count_changed.is_connected(unread_cb):
			EmailManager.unread_count_changed.connect(unread_cb)
	if EmailManager.has_signal("email_received"):
		var receive_cb = Callable(self, "_on_email_received")
		if not EmailManager.email_received.is_connected(receive_cb):
			EmailManager.email_received.connect(receive_cb)
	_email_update_unread_indicator(EmailManager.get_unread_count())
	_build_email_toast()


func _build_start_menu() -> void:
	_start_menu = Panel.new()
	_start_menu.visible = false
	_start_menu.size = Vector2(260, 336)
	_start_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = _make_panel_style(COL_OS_WINDOW_BG, COL_OS_BORDER, 2, 0)
	_start_menu.add_theme_stylebox_override("panel", style)
	_desktop_ui.add_child(_start_menu)

	var sidebar = ColorRect.new()
	sidebar.position = Vector2(0, 0)
	sidebar.size = Vector2(38, _start_menu.size.y)
	sidebar.color = COL_OS_TITLE_BAR
	_start_menu.add_child(sidebar)

	var sidebar_label = Label.new()
	sidebar_label.text = "CAMP OS 95"
	sidebar_label.position = Vector2(8, _start_menu.size.y - 10.0)
	sidebar_label.size = Vector2(_start_menu.size.y - 20.0, 24.0)
	sidebar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sidebar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sidebar_label.rotation_degrees = -90.0
	sidebar_label.add_theme_font_size_override("font_size", 11)
	sidebar_label.add_theme_color_override("font_color", COL_OS_TEXT_LIGHT)
	sidebar.add_child(sidebar_label)

	var menu_box = VBoxContainer.new()
	menu_box.position = Vector2(44, 6)
	menu_box.size = Vector2(210, 324)
	menu_box.add_theme_constant_override("separation", 2)
	_start_menu.add_child(menu_box)

	# Programs group
	menu_box.add_child(_make_start_folder("Programs"))
	_register_program_menu_item(menu_box, "builder", "  Builder", Callable(self, "_open_builder_app"), "res://assets/textury/crt/icons/builder.png")
	_register_program_menu_item(menu_box, "guestrack", "  GuestRack", Callable(self, "_open_guestrack_app"), "res://assets/textury/crt/icons/guestrack.png")
	_register_program_menu_item(menu_box, "camp_status", "  Camp Status", Callable(self, "_open_status_app"), "res://assets/textury/crt/icons/campstat.png")
	_register_program_menu_item(menu_box, "finance", "  Finance", Callable(self, "_open_finance_app"), "res://assets/textury/crt/icons/finance.png")
	_register_program_menu_item(menu_box, "minesweeper", "  Minesweeper", Callable(self, "_open_minesweeper_app"), "res://assets/textury/crt/icons/minesweeper.png")
	_register_program_menu_item(menu_box, "campmail", "  CampMail", Callable(self, "_open_email_app"), "res://assets/textury/crt/icons/email.png")
	_register_program_menu_item(menu_box, "beeternet", "  Beeternet", Callable(self, "_open_beeternet_app"), ASSET_ICON_BEETERNET)
	_start_menu_programs_box = menu_box

	var sep1 = HSeparator.new()
	menu_box.add_child(sep1)

	menu_box.add_child(_make_start_item("Settings", Callable(self, "_open_settings_app")))
	menu_box.add_child(_make_start_item("Save Game", Callable(self, "_save_game_from_start_menu")))

	var sep2 = HSeparator.new()
	menu_box.add_child(sep2)

	menu_box.add_child(_make_start_item("Log Out", Callable(self, "_placeholder_logout")))
	menu_box.add_child(_make_start_item("Shut Down", Callable(self, "_shutdown_desktop")))


func _make_start_item(text: String, callback: Callable, icon_path: String = "") -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(206, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	var icon_src := icon_path if not icon_path.is_empty() else ASSET_ICON_PC
	var menu_icon = _safe_load_texture_scaled(icon_src, 16, 16)
	if menu_icon == null:
		menu_icon = _safe_load_texture(icon_src)
	if menu_icon != null:
		btn.icon = menu_icon
		btn.add_theme_constant_override("h_separation", 8)
	_apply_button_style(btn, COL_OS_ACCENT_ALT, COL_OS_TEXT_DARK)
	btn.pressed.connect(callback)
	return btn


func _make_start_folder(label: String) -> Control:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(206, 24)
	var folder_lbl = Label.new()
	folder_lbl.text = "[" + label + "]"
	folder_lbl.add_theme_font_size_override("font_size", 11)
	folder_lbl.add_theme_color_override("font_color", COL_OS_TEXT_DARK.lightened(0.28))
	folder_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(folder_lbl)
	return hbox


func _toggle_start_menu() -> void:
	if _start_menu == null:
		return
	_start_menu_sequence_id += 1
	var seq_id = _start_menu_sequence_id
	if _start_menu.visible:
		_start_menu.visible = false
		return
	_start_menu.visible = false
	get_tree().create_timer(0.18).timeout.connect(func():
		if seq_id != _start_menu_sequence_id:
			return
		if _current_state != os_state.DESKTOP:
			return
		_start_menu.visible = true
		_start_menu.move_to_front()
	)


func _close_start_menu() -> void:
	if _start_menu != null:
		_start_menu_sequence_id += 1
		_start_menu.visible = false


func _open_notepad_app() -> void:
	_open_text_window("notepad", "Notepad", "TODO:\n- Day: expand the camp\n- Evening: guest routines + lore\n- Night: survive")


func _open_guestrack_app() -> void:
	if not _is_program_unlocked("guestrack"):
		return
	var window_id = "guestrack"
	var title = "GuestRack"
	if _app_windows.has(window_id) and is_instance_valid(_app_windows[window_id]):
		var existing = _app_windows[window_id] as Control
		if _guestrack_panel == null or not is_instance_valid(_guestrack_panel):
			_guestrack_panel = existing.get_node_or_null("GuestTrackPanel") as Control
		_refresh_guestrack_app_content()
		if not _taskbar_buttons.has(window_id):
			_add_taskbar_button(window_id, title, existing)
		existing.visible = true
		existing.move_to_front()
		_update_window_layer_state()
		_update_taskbar_button_state(window_id, true)
		return

	var win = _create_window_base(window_id, title, Vector2(760, 470))
	_app_windows[window_id] = win
	_add_taskbar_button(window_id, title, win)

	if GUESTRACK_PANEL_SCRIPT == null:
		var body := RichTextLabel.new()
		body.bbcode_enabled = false
		body.text = "GuestRack module missing."
		body.position = Vector2(8.0, 36.0)
		body.size = Vector2(win.size.x - 16.0, win.size.y - 44.0)
		body.scroll_active = true
		body.add_theme_stylebox_override("normal", _make_panel_style(Color(0.17, 0.19, 0.18, 0.92), Color(0.38, 0.36, 0.32, 1.0), 1, 0))
		body.add_theme_color_override("default_color", COL_OS_TEXT_LIGHT)
		win.add_child(body)
		win.resized.connect(func() -> void:
			body.position = Vector2(8.0, 36.0)
			body.size = Vector2(maxf(120.0, win.size.x - 16.0), maxf(120.0, win.size.y - 44.0))
		)
		_queue_window_open(win, true)
		return

	_guestrack_panel = GUESTRACK_PANEL_SCRIPT.new()
	_guestrack_panel.name = "GuestTrackPanel"
	win.add_child(_guestrack_panel)
	_layout_window_module_content(win, _guestrack_panel)
	win.resized.connect(func() -> void:
		if is_instance_valid(_guestrack_panel):
			_layout_window_module_content(win, _guestrack_panel)
	)
	_refresh_guestrack_app_content()
	_queue_window_open(win, true)


func _open_settings_app() -> void:
	var window_id = "settings"
	var title = "Settings"
	var win = _create_window_base(window_id, title, Vector2(520, 360))
	_app_windows[window_id] = win
	_add_taskbar_button(window_id, title, win)

	var panel := SETTINGS_PANEL_SCRIPT.new()
	panel.position = Vector2(10.0, 36.0)
	panel.size = Vector2(win.size.x - 20.0, win.size.y - 46.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.add_child(panel)

	win.resized.connect(func() -> void:
		panel.position = Vector2(10.0, 36.0)
		panel.size = Vector2(maxf(120.0, win.size.x - 20.0), maxf(120.0, win.size.y - 46.0))
	)

	_queue_window_open(win)


func _save_game_from_start_menu() -> void:
	_close_start_menu()
	var main_node := _resolve_main_game_node()
	if main_node == null or not main_node.has_method("request_manual_save"):
		_show_save_result_window("Save system unavailable.")
		return
	var save_path := str(main_node.call("request_manual_save", "Manual Save"))
	if save_path.is_empty():
		_show_save_result_window("Manual save failed.")
		return
	_show_save_result_window("Saved successfully.\n\n%s" % save_path)


func _resolve_main_game_node() -> Node:
	if _interior_host != null and is_instance_valid(_interior_host):
		var cursor: Node = _interior_host
		while cursor != null:
			if cursor.has_method("request_manual_save"):
				return cursor
			cursor = cursor.get_parent()
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.root
	if root == null:
		return null
	var main_candidate := root.get_node_or_null("Main")
	if main_candidate != null and main_candidate.has_method("request_manual_save"):
		return main_candidate
	for child in root.get_children():
		if child != null and child.has_method("request_manual_save"):
			return child
	return null


func _show_save_result_window(text: String) -> void:
	if _app_windows.has("save_game_result"):
		_close_app_window("save_game_result")
	_open_text_window("save_game_result", "Save Game", text)


func _open_minesweeper_app() -> void:
	if not _is_program_unlocked("minesweeper"):
		return
	_open_text_window("minesweeper", "Minesweeper", "Minesweeper skeleton\n\nFull game will be added in the next pass.")


func _open_explorer_app() -> void:
	_open_text_window("explorer", "Explorer", "A:/camp\nA:/camp/lore\nA:/camp/guests\nA:/camp/buildings")


func _open_status_app() -> void:
	_close_start_menu()
	if not _is_program_unlocked("camp_status"):
		return
	var window_id := "camp_status"
	var title := "Camp Status"
	if _app_windows.has(window_id) and is_instance_valid(_app_windows[window_id]):
		var existing = _app_windows[window_id] as Panel
		if existing == null:
			return
		_restore_camp_status_runtime_refs(existing)
		_refresh_status_app_content()
		if not _taskbar_buttons.has(window_id):
			_add_taskbar_button(window_id, title, existing)
		existing.visible = true
		existing.move_to_front()
		_update_window_layer_state()
		_update_taskbar_button_state(window_id, true)
		return

	var win = _create_window_base(window_id, title, Vector2(760, 470))
	_app_windows[window_id] = win
	_add_taskbar_button(window_id, title, win)
	_camp_status_window = win
	_camp_status_tabs.clear()
	_camp_status_pages.clear()
	if not CAMP_STATUS_TABS.has(_camp_status_active_tab):
		_camp_status_active_tab = "electricity"

	var masthead := Panel.new()
	masthead.name = "CampStatusMasthead"
	masthead.add_theme_stylebox_override("panel", _make_panel_style(Color(0.34, 0.20, 0.12, 1.0), Color(0.34, 0.28, 0.20, 1.0), 2, 0))
	win.add_child(masthead)

	var masthead_title := Label.new()
	masthead_title.name = "CampStatusMastheadTitle"
	masthead_title.text = "CAMPSTAT 98"
	masthead_title.add_theme_font_size_override("font_size", 18)
	masthead_title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	masthead.add_child(masthead_title)

	var masthead_sub := Label.new()
	masthead_sub.name = "CampStatusMastheadSubtitle"
	masthead_sub.text = "Power Grid Telemetry and Billing Console"
	masthead_sub.add_theme_font_size_override("font_size", 11)
	masthead_sub.add_theme_color_override("font_color", Color(0.90, 0.86, 0.78, 1.0))
	masthead.add_child(masthead_sub)

	var masthead_status := Label.new()
	masthead_status.name = "CampStatusMastheadStatus"
	masthead_status.text = "UNPAID 0 | OVERDUE 0 | GRID ON"
	masthead_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	masthead_status.add_theme_font_size_override("font_size", 11)
	masthead_status.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	masthead.add_child(masthead_status)

	var tab_bar := Panel.new()
	tab_bar.name = "CampStatusTabBar"
	tab_bar.add_theme_stylebox_override("panel", _make_panel_style(Color(0.73, 0.69, 0.60, 1.0), Color(0.34, 0.28, 0.20, 1.0), 1, 0))
	win.add_child(tab_bar)

	var tab_row := HBoxContainer.new()
	tab_row.name = "CampStatusTabRow"
	tab_row.add_theme_constant_override("separation", 6)
	tab_bar.add_child(tab_row)
	for tab_id in CAMP_STATUS_TABS:
		var tab_btn := _camp_status_make_tab_button(tab_id)
		_camp_status_tabs[tab_id] = tab_btn
		tab_row.add_child(tab_btn)

	var body := Panel.new()
	body.name = "CampStatusBody"
	body.add_theme_stylebox_override("panel", _make_panel_style(Color(0.78, 0.74, 0.65, 1.0), Color(0.34, 0.28, 0.20, 1.0), 1, 0))
	win.add_child(body)

	var notice_panel := Panel.new()
	notice_panel.name = "CampStatusNotice"
	notice_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.71, 0.67, 0.58, 1.0), Color(0.34, 0.28, 0.20, 1.0), 1, 0))
	body.add_child(notice_panel)

	var notice_label := Label.new()
	notice_label.name = "CampStatusNoticeLabel"
	notice_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	notice_label.offset_left = 8.0
	notice_label.offset_top = 6.0
	notice_label.offset_right = -8.0
	notice_label.offset_bottom = -6.0
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 11)
	notice_panel.add_child(notice_label)
	_camp_status_notice_label = notice_label

	var content := RichTextLabel.new()
	content.name = "CampStatusContent"
	content.bbcode_enabled = true
	content.scroll_active = true
	content.fit_content = false
	content.add_theme_stylebox_override("normal", _make_panel_style(Color(0.80, 0.76, 0.68, 1.0), Color(0.34, 0.28, 0.20, 1.0), 1, 0))
	content.add_theme_color_override("default_color", Color(0.16, 0.12, 0.09, 1.0))
	content.add_theme_font_size_override("normal_font_size", 11)
	content.meta_hover_started.connect(func(_m: Variant): _apply_cursor_hand())
	content.meta_hover_ended.connect(func(_m: Variant): _apply_cursor_default())
	content.meta_clicked.connect(func(meta: Variant):
		var url := str(meta)
		if url.begins_with("pay://"):
			_on_camp_status_pay_bill_requested(url.substr(6))
		elif url.begins_with("crew://"):
			_on_camp_status_crew_requested()
	)
	body.add_child(content)
	_camp_status_body = content
	_camp_status_pages["content"] = content

	_layout_status_app_window(win)
	_refresh_status_app_content()
	win.resized.connect(func() -> void:
		if is_instance_valid(win):
			_layout_status_app_window(win)
	)
	_queue_window_open(win)


func _restore_camp_status_runtime_refs(win: Panel) -> void:
	_camp_status_window = win
	_camp_status_body = win.get_node_or_null("CampStatusBody/CampStatusContent") as RichTextLabel
	_camp_status_notice_label = win.get_node_or_null("CampStatusBody/CampStatusNotice/CampStatusNoticeLabel") as Label
	_camp_status_tabs.clear()
	for tab_id in CAMP_STATUS_TABS:
		var path := "CampStatusTabBar/CampStatusTabRow/CampStatusTab_%s" % tab_id
		var tab_btn = win.get_node_or_null(path) as Button
		if tab_btn != null:
			_camp_status_tabs[tab_id] = tab_btn


func _camp_status_make_tab_button(tab_id: String) -> Button:
	var btn := Button.new()
	btn.name = "CampStatusTab_%s" % tab_id
	btn.text = _camp_status_tab_title(tab_id)
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(110.0, 24.0)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func() -> void:
		_set_camp_status_active_tab(tab_id)
	)
	return btn


func _camp_status_tab_title(tab_id: String) -> String:
	match tab_id:
		"electricity":
			return "Electricity"
		"billing":
			return "Billing"
		"night_risk":
			return "Night Risk"
		"utilities":
			return "Upkeep"
		"archive":
			return "Reviews"
		_:
			return tab_id.capitalize()


func _set_camp_status_active_tab(tab_id: String) -> void:
	if not CAMP_STATUS_TABS.has(tab_id):
		return
	_camp_status_active_tab = tab_id
	_camp_status_apply_tab_styles()
	_refresh_status_app_content()


func _camp_status_apply_tab_styles() -> void:
	for tab_id in CAMP_STATUS_TABS:
		var tab_any = _camp_status_tabs.get(tab_id, null)
		if not (tab_any is Button):
			continue
		var btn := tab_any as Button
		var active := tab_id == _camp_status_active_tab
		var base := Color(0.82, 0.78, 0.68, 1.0) if active else Color(0.71, 0.67, 0.58, 1.0)
		var border := Color(0.30, 0.24, 0.17, 1.0) if active else Color(0.36, 0.30, 0.22, 1.0)
		var text := Color(0.12, 0.09, 0.07, 1.0)
		var normal = _make_panel_style(base, border, 2, 0)
		var hover = _make_panel_style(base.lightened(0.05), border.darkened(0.05), 2, 0)
		var pressed = _make_panel_style(base.darkened(0.08), border.darkened(0.12), 2, 0)
		btn.set_pressed_no_signal(active)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("focus", normal)
		btn.add_theme_color_override("font_color", text)
		btn.add_theme_color_override("font_hover_color", text)
		btn.add_theme_color_override("font_pressed_color", text)


func _layout_status_app_window(win: Panel) -> void:
	if win == null or not is_instance_valid(win):
		return
	var title_h := 30.0
	var masthead_h := 58.0
	var tab_bar_h := 32.0
	var content_y := title_h + 4.0
	var total_w := win.size.x
	var masthead_w := total_w - 4.0
	var tab_y := content_y + masthead_h + 4.0
	var body_y := tab_y + tab_bar_h + 4.0
	var body_h := maxf(80.0, win.size.y - body_y - 2.0)

	var masthead = win.get_node_or_null("CampStatusMasthead") as Control
	if masthead != null:
		masthead.position = Vector2(2.0, content_y)
		masthead.size = Vector2(masthead_w, masthead_h)
		var title = masthead.get_node_or_null("CampStatusMastheadTitle") as Label
		if title != null:
			title.position = Vector2(10.0, 7.0)
		var subtitle = masthead.get_node_or_null("CampStatusMastheadSubtitle") as Label
		if subtitle != null:
			subtitle.position = Vector2(12.0, 32.0)
			subtitle.size = Vector2(maxf(170.0, masthead_w - 210.0), 16.0)
		var status = masthead.get_node_or_null("CampStatusMastheadStatus") as Label
		if status != null:
			status.position = Vector2(0.0, 11.0)
			status.size = Vector2(masthead_w - 12.0, 18.0)

	var tab_bar = win.get_node_or_null("CampStatusTabBar") as Control
	if tab_bar != null:
		tab_bar.position = Vector2(2.0, tab_y)
		tab_bar.size = Vector2(total_w - 4.0, tab_bar_h)
		var tab_row = tab_bar.get_node_or_null("CampStatusTabRow") as HBoxContainer
		if tab_row != null:
			tab_row.position = Vector2(6.0, 4.0)
			tab_row.size = Vector2(maxf(120.0, tab_bar.size.x - 12.0), maxf(20.0, tab_bar_h - 8.0))
			var separators := 6.0 * float(maxi(0, CAMP_STATUS_TABS.size() - 1))
			var btn_w := clampf((tab_row.size.x - separators) / float(maxi(1, CAMP_STATUS_TABS.size())), 92.0, 180.0)
			for tab_id in CAMP_STATUS_TABS:
				var tab_any = _camp_status_tabs.get(tab_id, null)
				if tab_any is Button:
					(tab_any as Button).custom_minimum_size = Vector2(btn_w, 24.0)

	var body = win.get_node_or_null("CampStatusBody") as Control
	if body != null:
		body.position = Vector2(2.0, body_y)
		body.size = Vector2(total_w - 4.0, body_h)
		var notice = body.get_node_or_null("CampStatusNotice") as Control
		var notice_h := 32.0
		if notice != null:
			notice.position = Vector2(8.0, 8.0)
			notice.size = Vector2(maxf(140.0, body.size.x - 16.0), notice_h)
		var content = body.get_node_or_null("CampStatusContent") as RichTextLabel
		if content != null:
			content.position = Vector2(8.0, 8.0 + notice_h + 6.0)
			content.size = Vector2(
				maxf(120.0, body.size.x - 16.0),
				maxf(80.0, body.size.y - (8.0 + notice_h + 6.0) - 8.0)
			)


func _get_camp_status_snapshot() -> Dictionary:
	var host := _resolve_electricity_host()
	if host == null or not host.has_method("get_electricity_ui_snapshot"):
		return {}
	var snapshot_any = host.call("get_electricity_ui_snapshot")
	if snapshot_any is Dictionary:
		return (snapshot_any as Dictionary).duplicate(true)
	return {}


func _set_camp_status_notice(text: String, color: Color) -> void:
	if _camp_status_notice_label == null or not is_instance_valid(_camp_status_notice_label):
		return
	_camp_status_notice_label.text = text
	_camp_status_notice_label.add_theme_color_override("font_color", color)


func _refresh_status_masthead(snapshot: Dictionary) -> void:
	if _camp_status_window == null or not is_instance_valid(_camp_status_window):
		return
	var status_lbl = _camp_status_window.get_node_or_null("CampStatusMasthead/CampStatusMastheadStatus") as Label
	if status_lbl == null:
		return
	if snapshot.is_empty():
		status_lbl.text = "RUNTIME OFFLINE"
		status_lbl.add_theme_color_override("font_color", Color(0.98, 0.74, 0.68, 1.0))
		return
	var unpaid_count: int = maxi(0, int(snapshot.get("unpaid_count", 0)))
	var overdue_count: int = maxi(0, int(snapshot.get("overdue_count", 0)))
	var grid_on := not bool(snapshot.get("power_cut_active", false))
	status_lbl.text = "UNPAID %d | OVERDUE %d | GRID %s" % [unpaid_count, overdue_count, "ON" if grid_on else "OFF"]
	status_lbl.add_theme_color_override(
		"font_color",
		Color(0.98, 0.95, 0.86, 1.0) if grid_on else Color(0.99, 0.76, 0.64, 1.0)
	)


func _refresh_status_notice(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		_set_camp_status_notice("Electricity runtime unavailable.", Color(0.76, 0.20, 0.15, 1.0))
		return
	var power_cut := bool(snapshot.get("power_cut_active", false))
	var overdue_count: int = maxi(0, int(snapshot.get("overdue_count", 0)))
	var unpaid_count: int = maxi(0, int(snapshot.get("unpaid_count", 0)))
	if power_cut:
		var warning := "POWER CUT ACTIVE: pay all overdue invoices to restore the grid."
		if bool(snapshot.get("ups_active", false)):
			var sec := maxi(0, int(ceil(float(snapshot.get("ups_seconds_left", 0.0)))))
			warning += " UPS backup %02d:%02d remaining." % [sec / 60, sec % 60]
		_set_camp_status_notice(warning, Color(0.78, 0.14, 0.12, 1.0))
		return
	if _camp_status_active_tab == "billing":
		if overdue_count > 0:
			_set_camp_status_notice("Overdue invoices detected: %d" % overdue_count, Color(0.78, 0.14, 0.12, 1.0))
		elif unpaid_count > 0:
			_set_camp_status_notice("Unpaid invoices waiting: %d" % unpaid_count, Color(0.58, 0.42, 0.12, 1.0))
		else:
			_set_camp_status_notice("Billing clear. Grid power stable.", Color(0.18, 0.42, 0.19, 1.0))
		return
	var issue_hour := clampi(int(snapshot.get("bill_issue_hour", 20)), 0, 23)
	var issue_minute := clampi(int(snapshot.get("bill_issue_minute", 0)), 0, 59)
	_set_camp_status_notice(
		"Daily invoices are issued at %02d:%02d for previous-day usage." % [issue_hour, issue_minute],
		Color(0.26, 0.25, 0.22, 1.0)
	)


func _build_status_app_text() -> String:
	return _build_status_app_text_with_snapshot(_get_camp_status_snapshot())


func _build_status_app_text_with_snapshot(snapshot: Dictionary) -> String:
	match _camp_status_active_tab:
		"electricity":
			return _build_status_electricity_text(snapshot)
		"billing":
			return _build_status_billing_text(snapshot)
		"night_risk":
			return _build_status_night_risk_text()
		"utilities":
			return _build_status_upkeep_text()
		"archive":
			return _build_status_reviews_text()
		_:
			return "[b]CAMP STATUS[/b]"


## Player-facing view of the liminal forecast.
##
## This data drives the game's main risk decision but used to be reachable only from
## a debug window, leaving the HUD bulbs as the sole (unlabelled) signal.
func _build_status_night_risk_text() -> String:
	if GuestManager == null or not GuestManager.has_method("get_liminal_forecast_data"):
		return "[b]NIGHT RISK[/b]\n\n[color=#7d2f24]Guest telemetry unavailable.[/color]"
	var payload_any = GuestManager.call("get_liminal_forecast_data")
	if not (payload_any is Dictionary) or not bool((payload_any as Dictionary).get("ok", false)):
		return "[b]NIGHT RISK[/b]\n\n[color=#7d2f24]Forecast unavailable.[/color]"
	var payload: Dictionary = payload_any

	var totals_any = payload.get("totals", {})
	var totals: Dictionary = totals_any if totals_any is Dictionary else {}
	var safe_count := int(payload.get("safe_count", 3))

	var text := "[b]OVERNIGHT ANOMALY FORECAST[/b]\n"
	text += "Guests in camp: %d  |  Safe count per archetype: %d\n" % [
		int(totals.get("guests", 0)), safe_count]
	text += "Expected spawns tonight: [b]%.2f[/b]  |  Guaranteed: [b]%d[/b]\n\n" % [
		float(totals.get("expected_spawns", 0.0)), int(totals.get("guaranteed_spawns", 0))]

	text += "[b]Pressure by archetype[/b]\n"
	var entries_any = payload.get("archetypes", [])
	var entries: Array = entries_any if entries_any is Array else []
	if entries.is_empty():
		text += "(No archetype data.)\n"
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var label := str(entry.get("label", "?"))
		var count := int(entry.get("count", 0))
		var guaranteed := int(entry.get("guaranteed_spawns", 0))
		var tier := str(entry.get("chance_tier", "none"))
		var pct := int(round(float(entry.get("chance_probability", 0.0)) * 100.0))

		var verdict := ""
		var colour := "#3f6f34"
		if guaranteed > 0:
			verdict = "GUARANTEED x%d" % guaranteed
			colour = "#7d2f24"
		elif tier == "none" or tier.is_empty():
			verdict = "safe"
		else:
			verdict = "%s ~%d%%" % [tier.to_upper(), pct]
			colour = "#7d6220" if pct < 40 else "#7d2f24"

		text += "  %-12s %2d in camp   [color=%s]%s[/color]\n" % [label, count, colour, verdict]

		var thresholds_any = entry.get("next_thresholds", {})
		if thresholds_any is Dictionary:
			var thresholds: Dictionary = thresholds_any
			var next_at := 0
			var next_name := ""
			for key in ["small_at", "medium_at", "large_at", "guaranteed_at"]:
				var at := int(thresholds.get(key, 0))
				if at > count:
					next_at = at
					next_name = str(key).replace("_at", "").to_upper()
					break
			if next_at > 0:
				text += "               next tier %s at %d (+%d more)\n" % [next_name, next_at, next_at - count]

	text += "\n[i]Accepting more guests of one archetype raises that archetype's odds.\n"
	text += "A wide mixed camp is safer than a deep single-archetype camp.[/i]\n\n"
	text += _night_procedures_text()
	return text


## Staff guidance, in the voice of a camp operator that has clearly done this before.
## It never says what these things are. It only says what to do.
const NIGHT_PROCEDURES := [
	["Quiet Guy", "SILENT MAN", "Footsteps behind staff. Respond to every sound: turn, move. Do not stand still in the dark."],
	["Drunk", "THE TOURIST", "A flash charging somewhere in the field. Turn your back before it fires. Do not pose."],
	["Cheap Chick", "THE GIRL", "She stays where the light ends. Keep her in sight, keep moving, keep to the lamps. Batteries are not covered by the camp."],
	["Two or more", "THE ANTLERED MAN", "Walks the fence. Stay off the fence line after dark. He does not enter lamp light."],
]


func _night_procedures_text() -> String:
	var t := "[b]STAFF PROCEDURES (NIGHT)[/b]  [color=#5b4a36]rev. 3, do not remove from terminal[/color]\n"
	for row in NIGHT_PROCEDURES:
		t += "[b]%s[/b] -> [color=#7d2f24]%s[/color]\n    %s\n" % [row[0], row[1], row[2]]
	t += "[color=#5b4a36]Incidents are not to be reported to guests. Incidents are not to be reported.[/color]"
	return t


func _build_status_electricity_text(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return "[b]ELECTRICITY[/b]\n\n[color=#7d2f24]Runtime unavailable.[/color]"
	var day := int(snapshot.get("day", 0))
	var time := str(snapshot.get("time", "--:--"))
	var total_kwh := float(snapshot.get("daily_kwh_total", 0.0))
	var energy_cost := int(snapshot.get("daily_cost_energy", 0))
	var total_cost := int(snapshot.get("daily_cost_total", 0))
	var base_fee := int(snapshot.get("base_fee", 0))
	var rate := float(snapshot.get("rate_per_kwh", 0.0))
	var text := "[b]LIVE ELECTRICITY DRAW[/b]\n"
	text += "Day %d  |  Time %s\n" % [day, time]
	text += "Tariff: $%.2f / kWh  |  Base fee: $%d / day\n\n" % [rate, base_fee]
	text += "[b]Current Daily Consumption[/b]\n"
	text += "Total load: [b]%.1f kWh/day[/b]\n" % total_kwh
	text += "Energy charge: $%d/day\n" % energy_cost
	text += "Projected daily invoice: [b]$%d[/b]\n\n" % total_cost
	text += "[b]Built Structures[/b]\n"
	var lines_any = snapshot.get("consumption_lines", [])
	if not (lines_any is Array) or (lines_any as Array).is_empty():
		text += "(No powered structures built.)\n"
		return text
	var lines := lines_any as Array
	var line_idx := 1
	for line_any in lines:
		if not (line_any is Dictionary):
			continue
		var line := line_any as Dictionary
		var label := str(line.get("label", "Unknown")).strip_edges()
		if label.is_empty():
			label = "Unknown"
		var coord_text := _camp_status_coord_label(line.get("coord", Vector2i.ZERO))
		var power_units: int = maxi(0, int(line.get("power_units", 0)))
		var kwh := maxf(0.0, float(line.get("kwh_per_day", 0.0)))
		var cost: int = maxi(0, int(line.get("cost_per_day", 0)))
		text += "%02d) %s @ %s  --  %d pu  --  %.1f kWh/day  --  $%d/day\n" % [line_idx, label, coord_text, power_units, kwh, cost]
		line_idx += 1
	return text


func _build_status_billing_text(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return "[b]BILLING[/b]\n\n[color=#7d2f24]Runtime unavailable.[/color]"
	var unpaid_count: int = maxi(0, int(snapshot.get("unpaid_count", 0)))
	var overdue_count: int = maxi(0, int(snapshot.get("overdue_count", 0)))
	var unpaid_total: int = maxi(0, int(snapshot.get("unpaid_total", 0)))
	var overdue_total: int = maxi(0, int(snapshot.get("overdue_total", 0)))
	var grace_days: int = maxi(1, int(snapshot.get("bill_grace_days", 3)))
	var issue_hour := clampi(int(snapshot.get("bill_issue_hour", 20)), 0, 23)
	var issue_minute := clampi(int(snapshot.get("bill_issue_minute", 0)), 0, 59)
	var default_issue_time := "%02d:%02d" % [issue_hour, issue_minute]
	var power_cut_active := bool(snapshot.get("power_cut_active", false))
	var text := "[b]ELECTRICITY BILLING[/b]\n"
	text += "Invoices are issued daily at %02d:%02d for the previous day.\n" % [issue_hour, issue_minute]
	text += "Each invoice must be paid within [b]%d in-game days[/b].\n\n" % grace_days
	text += "Open invoices: %d  |  Overdue: %d\n" % [unpaid_count, overdue_count]
	text += "Unpaid total: [b]$%d[/b]  |  Overdue total: [b]$%d[/b]\n" % [unpaid_total, overdue_total]
	if power_cut_active:
		text += "[color=#7d2f24][b]GRID POWER OFF[/b][/color] until all overdue invoices are paid.\n"
		if bool(snapshot.get("ups_active", false)):
			var sec := maxi(0, int(ceil(float(snapshot.get("ups_seconds_left", 0.0)))))
			text += "[color=#7d2f24]UPS backup in use: %02d:%02d remaining.[/color]\n" % [sec / 60, sec % 60]
		text += "\n"
	var bills_any = snapshot.get("bills", [])
	if not (bills_any is Array) or (bills_any as Array).is_empty():
		text += "\nNo invoices issued yet.\nFirst invoice appears once Day 2 reaches %s." % default_issue_time
		return text
	var bills := bills_any as Array
	for bill_any in bills:
		if not (bill_any is Dictionary):
			continue
		var bill := bill_any as Dictionary
		var bill_id := str(bill.get("id", "")).strip_edges()
		var service_day := int(bill.get("service_day", 0))
		var issued_day := int(bill.get("issued_day", 0))
		var issued_time := str(bill.get("issued_time", default_issue_time))
		var due_day := int(bill.get("due_day", 0))
		var amount: int = maxi(0, int(bill.get("amount", 0)))
		var total_kwh := maxf(0.0, float(bill.get("kwh_total", 0.0)))
		var status := str(bill.get("status", "unpaid")).to_lower().strip_edges()
		var is_paid := status == "paid"
		var is_overdue := bool(bill.get("is_overdue", false))
		var days_left := int(bill.get("days_left", 0))
		var status_label := "PAID"
		var status_color := "#2f5c33"
		if not is_paid:
			status_label = "OVERDUE" if is_overdue else "UNPAID"
			status_color = "#7d2f24" if is_overdue else "#6f5517"
		text += "----------------------------------------\n"
		text += "[b]Service Day %d[/b]  [color=%s][b]%s[/b][/color]\n" % [service_day, status_color, status_label]
		text += "Issued: Day %d  %s\n" % [issued_day, issued_time]
		text += "Due: Day %d  (%s)\n" % [due_day, _camp_status_due_label(days_left, is_paid, is_overdue)]
		text += "Usage: %.1f kWh  |  Amount: [b]$%d[/b]\n" % [total_kwh, amount]
		if not is_paid and not bill_id.is_empty():
			if is_overdue:
				text += "[url=pay://%s][color=#7d2f24][b]PAY NOW (RESTORE GRID)[/b][/color][/url]\n" % bill_id
			else:
				text += "[url=pay://%s][color=#2f5c7b]Pay invoice[/color][/url]\n" % bill_id
		var line_items_any = bill.get("line_items", [])
		if line_items_any is Array:
			var line_items := line_items_any as Array
			if not line_items.is_empty():
				text += "Load sample:\n"
				var preview_count := mini(3, line_items.size())
				for idx in range(preview_count):
					var line_any = line_items[idx]
					if not (line_any is Dictionary):
						continue
					var line := line_any as Dictionary
					var line_label := str(line.get("label", "Unknown")).strip_edges()
					if line_label.is_empty():
						line_label = "Unknown"
					var line_kwh := maxf(0.0, float(line.get("kwh_per_day", 0.0)))
					text += "  - %s (%.1f kWh/day)\n" % [line_label, line_kwh]
				if line_items.size() > preview_count:
					text += "  +%d more\n" % (line_items.size() - preview_count)
		text += "\n"
	text += "[i]Consequence: overdue invoices cut power to outdoor lamps/interiors and immediately start the 6-minute UPS shutdown countdown.[/i]"
	return text


## Building condition, worst first. Buildings below 50% can break down; a broken one
## stops serving guests until someone repairs it (walk up and hold R, or the crew).
func _build_status_upkeep_text() -> String:
	var host := _resolve_electricity_host()
	if host == null or not host.has_method("get_upkeep_snapshot"):
		return "[b]UPKEEP[/b]\n\n[color=#7d2f24]Maintenance telemetry unavailable.[/color]"
	var snap: Dictionary = host.call("get_upkeep_snapshot")
	var rows: Array = snap.get("rows", [])
	var text := "[b]UPKEEP[/b]\n"
	text += "[color=#5b4a36]Below 50% a building can break down. Broken buildings serve no one.\nWalk up to it and hold [b]R[/b] to service or repair it.[/color]\n\n"
	if rows.is_empty():
		return text + "[i]Nothing built that needs looking after yet.[/i]"
	var broken := 0
	for row_any in rows:
		var row: Dictionary = row_any
		var condition := float(row.get("condition", 1.0))
		var is_broken := bool(row.get("broken", false))
		if is_broken:
			broken += 1
		var cells := int(round(condition * 10.0))
		var bar := "#".repeat(cells) + ".".repeat(10 - cells)
		var color := "#2f5423"
		var word := "GOOD"
		if is_broken:
			color = "#7d2f24"
			word = "BROKEN"
			bar = "XXXXXXXXXX"
		elif condition < 0.5:
			color = "#7d2f24"
			word = "POOR"
		elif condition < 0.75:
			color = "#8a5a12"
			word = "WORN"
		text += "[code][color=%s]%s[/color][/code]  %3d%%  [color=%s]%-6s[/color]  %s  [color=#5b4a36]%s  $%d[/color]\n" % [
			color, bar, int(round(condition * 100.0)), color, word,
			str(row.get("label", "?")), "repair" if is_broken else "service", int(row.get("cost", 0))]
	text += "\n"
	var jobs := int(snap.get("crew_jobs", 0))
	if jobs <= 0:
		text += "[color=#2f5423]Everything is in working order.[/color]"
	elif bool(snap.get("night", false)):
		text += "[color=#5b4a36]Maintenance crew: %d job(s), $%d. The crew does not come out after dark.[/color]" % [jobs, int(snap.get("crew_cost", 0))]
	else:
		text += "[url=crew://all][color=#2f5c7b][b]CALL THE MAINTENANCE CREW[/b][/color][/url]  [color=#5b4a36]%d job(s), $%d (premium for not doing it yourself)[/color]" % [jobs, int(snap.get("crew_cost", 0))]
	if broken > 0:
		text = text.replace("[b]UPKEEP[/b]", "[b]UPKEEP[/b]  [color=#7d2f24]%d BROKEN[/color]" % broken)
	return text


func _on_camp_status_crew_requested() -> void:
	var host := _resolve_electricity_host()
	if host == null or not host.has_method("request_maintenance_crew"):
		_set_camp_status_notice("Maintenance crew unavailable.", Color(0.78, 0.14, 0.12, 1.0))
		return
	var result: Dictionary = host.call("request_maintenance_crew")
	_refresh_status_app_content()
	if bool(result.get("ok", false)):
		_set_camp_status_notice("Crew finished %d job(s). -$%d" % [int(result.get("jobs", 0)), int(result.get("amount", 0))], Color(0.18, 0.42, 0.19, 1.0))
		_refresh_finance_app_content()
		return
	match str(result.get("reason", "")):
		"night":
			_set_camp_status_notice("The crew does not come out after dark.", Color(0.58, 0.42, 0.12, 1.0))
		"insufficient_funds":
			_set_camp_status_notice("Not enough cash for the crew ($%d)." % int(result.get("amount", 0)), Color(0.78, 0.14, 0.12, 1.0))
		_:
			_set_camp_status_notice("Nothing for the crew to do.", Color(0.26, 0.25, 0.22, 1.0))


## Guest reviews, newest first, with the running average.
func _build_status_reviews_text() -> String:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	var reviews: Array = state.guest_reviews if state != null else []
	var text := "[b]GUEST REVIEWS[/b]\n\n"
	if reviews.is_empty():
		return text + "[i]No reviews yet. Guests write one when they check out.[/i]"
	var total := 0.0
	for r_any in reviews:
		if r_any is Dictionary:
			total += float((r_any as Dictionary).get("rating", 0))
	text += "Average [b]%.1f / 5[/b] from %d review(s)\n\n" % [total / float(reviews.size()), reviews.size()]
	for i in range(reviews.size() - 1, maxi(-1, reviews.size() - 31), -1):
		var r: Dictionary = reviews[i] if reviews[i] is Dictionary else {}
		var rating := clampi(int(r.get("rating", 0)), 0, 5)
		var stars := "*".repeat(rating) + "-".repeat(5 - rating)
		var color := "#2f5423" if rating >= 4 else ("#8a5a12" if rating == 3 else "#7d2f24")
		text += "[code][color=%s]%s[/color][/code]  [b]%s[/b]  [color=#5b4a36]day %d[/color]\n    %s\n" % [
			color, stars, str(r.get("name", "Guest")), int(r.get("day", 0)), str(r.get("text", ""))]
	return text


func _camp_status_due_label(days_left: int, is_paid: bool, is_overdue: bool) -> String:
	if is_paid:
		return "paid"
	if is_overdue:
		return "%d day(s) overdue" % abs(days_left)
	if days_left <= 0:
		return "due today"
	if days_left == 1:
		return "1 day left"
	return "%d days left" % days_left


func _camp_status_coord_label(value: Variant) -> String:
	if value is Vector2i:
		var coord := value as Vector2i
		return "%d:%d" % [coord.x, coord.y]
	if value is Vector2:
		var coord2 := value as Vector2
		return "%d:%d" % [int(coord2.x), int(coord2.y)]
	if value is Dictionary:
		var dict := value as Dictionary
		return "%d:%d" % [int(dict.get("x", 0)), int(dict.get("y", 0))]
	return "0:0"


func _on_camp_status_pay_bill_requested(bill_id: String) -> void:
	var target_id := bill_id.strip_edges()
	if target_id.is_empty():
		_set_camp_status_notice("Invalid invoice id.", Color(0.78, 0.14, 0.12, 1.0))
		return
	var host := _resolve_electricity_host()
	if host == null or not host.has_method("request_pay_electricity_bill"):
		_set_camp_status_notice("Billing runtime unavailable.", Color(0.78, 0.14, 0.12, 1.0))
		return
	var result_any = host.call("request_pay_electricity_bill", target_id)
	if not (result_any is Dictionary):
		_set_camp_status_notice("Payment failed: invalid runtime response.", Color(0.78, 0.14, 0.12, 1.0))
		return
	var result := result_any as Dictionary
	_refresh_status_app_content()
	if bool(result.get("ok", false)):
		var amount: int = maxi(0, int(result.get("amount", 0)))
		_set_camp_status_notice("Invoice paid successfully. -$%d" % amount, Color(0.18, 0.42, 0.19, 1.0))
		_refresh_finance_app_content()
		return
	var reason := str(result.get("reason", "payment_failed"))
	var message := "Payment failed."
	match reason:
		"already_paid":
			message = "Invoice already paid."
		"insufficient_funds":
			var amount_needed: int = maxi(0, int(result.get("amount", 0)))
			if amount_needed > 0:
				message = "Insufficient funds. Need $%d." % amount_needed
			else:
				message = "Insufficient funds."
		"not_found":
			message = "Invoice not found."
		"money_system_missing":
			message = "Money system unavailable."
		"runtime_missing":
			message = "Runtime unavailable."
		_:
			message = "Payment failed (%s)." % reason
	_set_camp_status_notice(message, Color(0.78, 0.14, 0.12, 1.0))


func _refresh_status_app_content() -> void:
	if _camp_status_body == null or not is_instance_valid(_camp_status_body):
		return
	var snapshot := _get_camp_status_snapshot()
	_refresh_status_masthead(snapshot)
	_refresh_status_notice(snapshot)
	_camp_status_apply_tab_styles()
	_camp_status_body.text = _build_status_app_text_with_snapshot(snapshot)


func _open_finance_app() -> void:
	if not _is_program_unlocked("finance"):
		return
	var window_id = "finance"
	var title = "Finance"
	if _app_windows.has(window_id) and is_instance_valid(_app_windows[window_id]):
		var existing = _app_windows[window_id] as Control
		_refresh_finance_app_content()
		if not _taskbar_buttons.has(window_id):
			_add_taskbar_button(window_id, title, existing)
		existing.visible = true
		existing.move_to_front()
		_update_window_layer_state()
		_update_taskbar_button_state(window_id, true)
		return

	var win = _create_window_base(window_id, title, Vector2(400, 340))
	_app_windows[window_id] = win
	_add_taskbar_button(window_id, title, win)

	var body = RichTextLabel.new()
	_finance_body = body
	body.bbcode_enabled = true
	body.position = Vector2(8, 36)
	body.size = Vector2(win.size.x - 16, win.size.y - 44)
	body.scroll_active = true
	body.add_theme_stylebox_override("normal", _make_panel_style(Color(0.12, 0.12, 0.08, 0.94), Color(0.35, 0.32, 0.28, 1.0), 1, 0))
	body.add_theme_color_override("default_color", Color(0.95, 0.95, 0.88))
	win.add_child(body)
	win.resized.connect(func() -> void:
		body.position = Vector2(8.0, 36.0)
		body.size = Vector2(maxf(120.0, win.size.x - 16.0), maxf(120.0, win.size.y - 44.0))
	)

	_refresh_finance_app_content()
	_queue_window_open(win)


func _build_finance_app_text() -> String:
	var balance = CoreRoot.get_money()
	var day = CoreRoot.get_day()
	var passive_income := 0
	var breakdown: Array = []
	var failed_count := 0
	var economy = _resolve_economy_manager()
	if economy != null:
		if economy.has_method("calculate_day_income"):
			passive_income = int(economy.call("calculate_day_income"))
		if economy.has_method("get_income_breakdown"):
			breakdown = economy.call("get_income_breakdown")
		if economy.has_method("get_failed_count"):
			failed_count = int(economy.call("get_failed_count"))

	var guest_daily_income := 0
	var active_guest_count := 0
	var state = CoreRoot.get_state()
	if state != null:
		for guest_any in state.guests:
			if not (guest_any is Dictionary):
				continue
			var guest: Dictionary = guest_any
			var status = str(guest.get("status", "")).to_lower().strip_edges()
			if status != "active" and status != "sleep":
				continue
			active_guest_count += 1
			guest_daily_income += max(1, int(guest.get("daily_income", 1)))

	var projected_daily_total = passive_income + guest_daily_income
	var text = "[center][b]FINANCE LOG[/b][/center]\n"
	text += "======================================\n"
	text += "Day: [color=#aaddff]%d[/color]\n" % day
	text += "Cash balance: [color=#ffffaa]$%d[/color]\n\n" % balance
	text += "[b]ESTIMATED DAILY FLOW:[/b]\n"
	text += "  Passive structures: [color=#aaffaa]$%d[/color]\n" % passive_income
	text += "  Active guest stays: [color=#aaffaa]$%d[/color]  (%d guests)\n" % [guest_daily_income, active_guest_count]
	text += "  [b]Projected total/day:[/b] [color=#aaffaa]$%d[/color]\n\n" % projected_daily_total

	if not breakdown.is_empty():
		text += "[b]STRUCTURE BREAKDOWN:[/b]\n"
		for line_any in breakdown:
			text += "  %s\n" % str(line_any)
	else:
		text += "[b]STRUCTURE BREAKDOWN:[/b]\n  (no passive income)\n"

	if failed_count > 0:
		text += "\n[color=#ffaaaa][b]FAILURES: %d[/b][/color]\n" % failed_count
		text += "[i]Failures reduce passive income.[/i]\n"

	text += "======================================\n"
	text += "[i]Balance is live. Income lines are current projections per in-game day.[/i]"
	return text


func _refresh_finance_app_content() -> void:
	if _finance_body == null or not is_instance_valid(_finance_body):
		return
	_finance_body.text = _build_finance_app_text()


func _refresh_guestrack_app_content() -> void:
	if _guestrack_panel == null or not is_instance_valid(_guestrack_panel):
		return
	if _guestrack_panel.has_method("refresh"):
		_guestrack_panel.call("refresh")


func _resolve_economy_manager() -> Node:
	if _grid_manager != null and is_instance_valid(_grid_manager):
		var parent = _grid_manager.get_parent()
		if parent != null:
			var from_parent = parent.get_node_or_null("EconomyManager")
			if from_parent != null:
				return from_parent
	var root = get_tree().root
	if root == null:
		return null
	var main = root.get_node_or_null("Main")
	if main != null:
		var from_main = main.get_node_or_null("EconomyManager")
		if from_main != null:
			return from_main
	return null


func _open_email_app() -> void:
	_close_start_menu()
	if not _is_program_unlocked("campmail"):
		return
	if _app_windows.has("email"):
		var existing = _app_windows["email"]
		existing.visible = true
		existing.move_to_front()
		_update_window_layer_state()
		_email_refresh_list()
		return

	var win = _create_window_base("email", "CampMail v2.1", Vector2(760, 470))
	_app_windows["email"] = win
	_add_taskbar_button("email", "CampMail", win)

	_email_build_content(win)
	_email_refresh_list()

	win.resized.connect(func(): _email_layout_content(win))

	win.visible = true
	win.move_to_front()
	_update_window_layer_state()
	_email_update_unread_indicator(EmailManager.get_unread_count())


func _email_build_content(win: Panel) -> void:
	var TITLE_H := 30.0
	var MASTHEAD_H := 58.0
	var COL_MAIL_MASTHEAD_BG := Color(0.34, 0.20, 0.12, 1.0)
	var COL_MAIL_MASTHEAD_TEXT := Color(0.98, 0.95, 0.86, 1.0)
	var COL_MAIL_DIVIDER := Color(0.34, 0.28, 0.20, 1.0)
	var COL_MAIL_SIDEBAR_BG := Color(0.73, 0.69, 0.60, 1.0)
	var COL_MAIL_LIST_BG := Color(0.80, 0.76, 0.68, 1.0)
	var COL_MAIL_LIST_HEADER_BG := Color(0.46, 0.41, 0.31, 1.0)
	var COL_MAIL_LIST_HEADER_TEXT := Color(0.97, 0.94, 0.85, 1.0)
	var COL_MAIL_PREVIEW_BG := Color(0.78, 0.74, 0.65, 1.0)
	var COL_MAIL_PREVIEW_HEAD_BG := Color(0.70, 0.66, 0.56, 1.0)

	var content_y := TITLE_H + 4.0
	var total_w := win.size.x
	var masthead_w := total_w - 4.0
	_email_selected_folder = "all"

	var masthead := Panel.new()
	masthead.name = "EmailMasthead"
	masthead.position = Vector2(2.0, content_y)
	masthead.size = Vector2(masthead_w, MASTHEAD_H)
	masthead.add_theme_stylebox_override("panel", _make_panel_style(COL_MAIL_MASTHEAD_BG, COL_MAIL_DIVIDER, 2, 0))
	win.add_child(masthead)

	var masthead_title := Label.new()
	masthead_title.name = "EmailMastheadTitle"
	masthead_title.text = "CAMPMAIL 98"
	masthead_title.position = Vector2(10.0, 7.0)
	masthead_title.add_theme_font_size_override("font_size", 18)
	masthead_title.add_theme_color_override("font_color", COL_MAIL_MASTHEAD_TEXT)
	masthead.add_child(masthead_title)

	var masthead_sub := Label.new()
	masthead_sub.name = "EmailMastheadSubtitle"
	masthead_sub.text = "Reception Dispatch and Booking Queue"
	masthead_sub.position = Vector2(12.0, 32.0)
	masthead_sub.size = Vector2(maxf(180.0, masthead_w - 180.0), 16.0)
	masthead_sub.add_theme_font_size_override("font_size", 11)
	masthead_sub.add_theme_color_override("font_color", COL_MAIL_MASTHEAD_TEXT.darkened(0.12))
	masthead.add_child(masthead_sub)

	var masthead_status := Label.new()
	masthead_status.name = "EmailMastheadStatus"
	masthead_status.text = "INBOX -- | UNREAD --"
	masthead_status.position = Vector2(0.0, 11.0)
	masthead_status.size = Vector2(masthead_w - 12.0, 18.0)
	masthead_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	masthead_status.add_theme_font_size_override("font_size", 11)
	masthead_status.add_theme_color_override("font_color", COL_MAIL_MASTHEAD_TEXT)
	masthead.add_child(masthead_status)

	var body_y := content_y + MASTHEAD_H + 6.0
	var total_h := win.size.y - body_y - 2.0
	var sidebar_w := _email_sidebar_width(total_w)
	var right_x := sidebar_w + 3.0
	var right_w := maxf(220.0, total_w - right_x - 2.0)
	var list_ratio := _email_list_ratio(total_w, total_h)
	var list_h := floorf(total_h * list_ratio)
	var preview_h := maxf(120.0, total_h - list_h - 1.0)

	var sidebar = Panel.new()
	sidebar.name = "EmailSidebar"
	sidebar.position = Vector2(2.0, body_y)
	sidebar.size = Vector2(sidebar_w, total_h)
	sidebar.add_theme_stylebox_override("panel", _make_panel_style(COL_MAIL_SIDEBAR_BG, COL_MAIL_DIVIDER, 1, 0))
	win.add_child(sidebar)

	var account_label = Label.new()
	account_label.name = "EmailAccountLabel"
	account_label.text = "campmail@camp-node-04"
	account_label.position = Vector2(8.0, 8.0)
	account_label.size = Vector2(sidebar_w - 16.0, 16.0)
	account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_label.add_theme_font_size_override("font_size", 10)
	account_label.add_theme_color_override("font_color", Color(0.17, 0.13, 0.09, 1.0))
	sidebar.add_child(account_label)

	var folder_label = Label.new()
	folder_label.name = "EmailFolderLabel"
	folder_label.text = "MAILBOX"
	folder_label.position = Vector2(8.0, 30.0)
	folder_label.add_theme_font_size_override("font_size", 10)
	folder_label.add_theme_color_override("font_color", Color(0.22, 0.17, 0.12, 1.0))
	sidebar.add_child(folder_label)

	_email_folder_inbox_btn = _email_make_folder_btn("ALL MAIL", Vector2(8.0, 48.0), sidebar, "all")
	_email_folder_spam_btn = null
	_email_apply_folder_button_state(_email_folder_inbox_btn, true)

	var hint = Label.new()
	hint.name = "EmailSidebarHint"
	hint.text = "Tip: customer mails are mixed with spam. Hunt for Accept / Refuse bookings."
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.position = Vector2(8.0, -92.0)
	hint.size = Vector2(sidebar_w - 16.0, 84.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.24, 0.20, 0.15, 1.0))
	sidebar.add_child(hint)

	var div_v = ColorRect.new()
	div_v.name = "EmailDividerV"
	div_v.position = Vector2(sidebar_w, body_y)
	div_v.size = Vector2(1.0, total_h)
	div_v.color = COL_MAIL_DIVIDER
	win.add_child(div_v)

	var list_header = Panel.new()
	list_header.name = "EmailListHeader"
	list_header.position = Vector2(right_x, body_y)
	list_header.size = Vector2(right_w, 24.0)
	list_header.add_theme_stylebox_override("panel", _make_panel_style(COL_MAIL_LIST_HEADER_BG, COL_MAIL_DIVIDER, 1, 0))
	win.add_child(list_header)

	var list_title = Label.new()
	list_title.name = "EmailListTitle"
	list_title.text = "MESSAGES"
	list_title.position = Vector2(right_x + 8.0, body_y + 5.0)
	list_title.add_theme_font_size_override("font_size", 10)
	list_title.add_theme_color_override("font_color", COL_MAIL_LIST_HEADER_TEXT)
	win.add_child(list_title)

	var list_scroll = ScrollContainer.new()
	list_scroll.name = "EmailListScroll"
	list_scroll.position = Vector2(right_x, body_y + 24.0)
	list_scroll.size = Vector2(right_w, list_h - 24.0)
	list_scroll.add_theme_stylebox_override("panel", _make_panel_style(COL_MAIL_LIST_BG, COL_MAIL_DIVIDER, 1, 0))
	win.add_child(list_scroll)

	_email_list_vbox = VBoxContainer.new()
	_email_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_email_list_vbox.add_theme_constant_override("separation", 1)
	list_scroll.add_child(_email_list_vbox)

	var div_h = ColorRect.new()
	div_h.name = "EmailDivH"
	div_h.position = Vector2(right_x, body_y + list_h)
	div_h.size = Vector2(right_w, 1.0)
	div_h.color = COL_MAIL_DIVIDER
	win.add_child(div_h)

	var preview = Panel.new()
	preview.name = "EmailPreview"
	preview.position = Vector2(right_x, body_y + list_h + 1.0)
	preview.size = Vector2(right_w, preview_h)
	preview.add_theme_stylebox_override("panel", _make_panel_style(COL_MAIL_PREVIEW_BG, COL_MAIL_DIVIDER, 1, 0))
	win.add_child(preview)

	_email_preview_header = RichTextLabel.new()
	_email_preview_header.bbcode_enabled = true
	_email_preview_header.scroll_active = false
	_email_preview_header.position = Vector2(8.0, 8.0)
	_email_preview_header.size = Vector2(right_w - 16.0, 58.0)
	_email_preview_header.add_theme_font_size_override("font_size", 11)
	_email_preview_header.add_theme_color_override("default_color", Color(0.15, 0.11, 0.08, 1.0))
	_email_preview_header.add_theme_stylebox_override("normal", _make_panel_style(COL_MAIL_PREVIEW_HEAD_BG, COL_MAIL_DIVIDER, 1, 0))
	_email_preview_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(_email_preview_header)

	var hdr_sep = ColorRect.new()
	hdr_sep.name = "EmailPreviewSep"
	hdr_sep.position = Vector2(8.0, 72.0)
	hdr_sep.size = Vector2(right_w - 16.0, 1.0)
	hdr_sep.color = COL_MAIL_DIVIDER
	preview.add_child(hdr_sep)

	_email_preview_body = RichTextLabel.new()
	_email_preview_body.bbcode_enabled = false
	_email_preview_body.scroll_active = true
	_email_preview_body.position = Vector2(8.0, 76.0)
	_email_preview_body.size = Vector2(right_w - 16.0, maxf(48.0, preview_h - 116.0))
	_email_preview_body.add_theme_font_size_override("font_size", 11)
	_email_preview_body.add_theme_color_override("default_color", Color(0.13, 0.10, 0.08, 1.0))
	_email_preview_body.add_theme_stylebox_override("normal", _make_panel_style(COL_MAIL_LIST_BG, COL_MAIL_DIVIDER, 1, 0))
	_email_preview_body.meta_hover_started.connect(func(_m: Variant): _apply_cursor_hand())
	_email_preview_body.meta_hover_ended.connect(func(_m: Variant): _apply_cursor_default())
	preview.add_child(_email_preview_body)

	_email_confirm_btn = Button.new()
	_email_confirm_btn.text = "Accept"
	_email_confirm_btn.size = Vector2(160.0, 24.0)
	_email_confirm_btn.position = Vector2(8.0, preview_h - 30.0)
	_email_confirm_btn.visible = false
	_apply_button_style(_email_confirm_btn, Color(0.33, 0.50, 0.26, 1.0), Color(0.92, 0.96, 0.86, 1.0))
	_email_confirm_btn.pressed.connect(_on_email_confirm_pressed)
	preview.add_child(_email_confirm_btn)

	_email_reject_btn = Button.new()
	_email_reject_btn.text = "Refuse"
	_email_reject_btn.size = Vector2(160.0, 24.0)
	_email_reject_btn.position = Vector2(176.0, preview_h - 30.0)
	_email_reject_btn.visible = false
	_apply_button_style(_email_reject_btn, Color(0.58, 0.28, 0.22, 1.0), COL_OS_TEXT_LIGHT)
	_email_reject_btn.pressed.connect(_on_email_reject_pressed)
	preview.add_child(_email_reject_btn)

	_email_layout_content(win)


func _email_layout_content(win: Panel) -> void:
	var TITLE_H := 30.0
	var MASTHEAD_H := 58.0
	var content_y := TITLE_H + 4.0
	var total_w := win.size.x
	var masthead_w := total_w - 4.0
	var body_y := content_y + MASTHEAD_H + 6.0
	var total_h := win.size.y - body_y - 2.0
	var sidebar_w := _email_sidebar_width(total_w)
	var right_x := sidebar_w + 3.0
	var right_w := maxf(220.0, total_w - right_x - 2.0)
	var list_ratio := _email_list_ratio(total_w, total_h)
	var list_h := floorf(total_h * list_ratio)
	var preview_h := maxf(120.0, total_h - list_h - 1.0)
	var action_gap := 8.0
	var action_btn_w := clampf((right_w - 16.0 - action_gap) * 0.5, 100.0, 200.0)
	var action_y := preview_h - 30.0

	for child in win.get_children():
		match child.name:
			"EmailMasthead":
				child.position = Vector2(2.0, content_y)
				child.size = Vector2(masthead_w, MASTHEAD_H)
				var mast_title = child.get_node_or_null("EmailMastheadTitle") as Label
				if mast_title != null:
					mast_title.position = Vector2(10.0, 7.0)
				var mast_sub = child.get_node_or_null("EmailMastheadSubtitle") as Label
				if mast_sub != null:
					mast_sub.position = Vector2(12.0, 32.0)
					mast_sub.size = Vector2(maxf(160.0, masthead_w - 180.0), 16.0)
				var mast_status = child.get_node_or_null("EmailMastheadStatus") as Label
				if mast_status != null:
					mast_status.position = Vector2(0.0, 11.0)
					mast_status.size = Vector2(masthead_w - 12.0, 18.0)
			"EmailSidebar":
				child.position = Vector2(2.0, body_y)
				child.size = Vector2(sidebar_w, total_h)
				var account = child.get_node_or_null("EmailAccountLabel") as Label
				if account != null:
					account.size.x = maxf(60.0, sidebar_w - 16.0)
				var folder = child.get_node_or_null("EmailFolderLabel") as Label
				if folder != null:
					folder.size.x = maxf(60.0, sidebar_w - 16.0)
				var hint = child.get_node_or_null("EmailSidebarHint") as Label
				if hint != null:
					hint.size = Vector2(maxf(60.0, sidebar_w - 16.0), 84.0)
				if _email_folder_inbox_btn != null and is_instance_valid(_email_folder_inbox_btn):
					_email_folder_inbox_btn.size.x = maxf(84.0, sidebar_w - 16.0)
			"EmailDividerV":
				child.position = Vector2(sidebar_w, body_y)
				child.size = Vector2(1.0, total_h)
			"EmailListHeader":
				child.position = Vector2(right_x, body_y)
				child.size = Vector2(right_w, 24.0)
			"EmailListTitle":
				child.position = Vector2(right_x + 8.0, body_y + 5.0)
			"EmailListScroll":
				child.position = Vector2(right_x, body_y + 24.0)
				child.size = Vector2(right_w, list_h - 24.0)
			"EmailDivH":
				child.position = Vector2(right_x, body_y + list_h)
				child.size = Vector2(right_w, 1.0)
			"EmailPreview":
				child.position = Vector2(right_x, body_y + list_h + 1.0)
				child.size = Vector2(right_w, preview_h)
				if _email_preview_header:
					_email_preview_header.position = Vector2(8.0, 8.0)
					_email_preview_header.size = Vector2(right_w - 16.0, 58.0)
				var preview_sep = child.get_node_or_null("EmailPreviewSep") as ColorRect
				if preview_sep != null:
					preview_sep.position = Vector2(8.0, 72.0)
					preview_sep.size.x = right_w - 16.0
				if _email_preview_body:
					_email_preview_body.position = Vector2(8.0, 76.0)
					_email_preview_body.size = Vector2(right_w - 16.0, maxf(48.0, preview_h - 116.0))
				if _email_confirm_btn:
					_email_confirm_btn.size.x = action_btn_w
					_email_confirm_btn.position = Vector2(8.0, action_y)
				if _email_reject_btn:
					_email_reject_btn.size.x = action_btn_w
					_email_reject_btn.position = Vector2(8.0 + action_btn_w + action_gap, action_y)


func _email_sidebar_width(total_w: float) -> float:
	if total_w < 660.0:
		return 138.0
	if total_w < 860.0:
		return 168.0
	return 198.0


func _email_list_ratio(total_w: float, total_h: float) -> float:
	if total_w < 700.0:
		return 0.52
	if total_h < 340.0:
		return 0.50
	return 0.44


func _email_make_folder_btn(label: String, pos: Vector2, parent: Control, folder_id: String) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.flat = false
	btn.position = pos
	btn.size = Vector2(166.0, 25.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 11)
	_email_apply_folder_button_state(btn, false)
	btn.pressed.connect(func(): _email_select_folder(folder_id))
	parent.add_child(btn)
	return btn


func _email_apply_folder_button_state(btn: Button, active: bool) -> void:
	if btn == null:
		return
	var base := Color(0.82, 0.78, 0.68, 1.0) if active else Color(0.71, 0.67, 0.58, 1.0)
	var border := Color(0.30, 0.24, 0.17, 1.0) if active else Color(0.36, 0.30, 0.22, 1.0)
	var text := Color(0.12, 0.09, 0.07, 1.0)
	var normal = _make_panel_style(base, border, 2, 0)
	var hover = _make_panel_style(base.lightened(0.05), border.darkened(0.05), 2, 0)
	var pressed = _make_panel_style(base.darkened(0.08), border.darkened(0.12), 2, 0)
	btn.set_pressed_no_signal(active)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", text)
	btn.add_theme_color_override("font_hover_color", text)
	btn.add_theme_color_override("font_pressed_color", text)


func _email_select_folder(folder: String) -> void:
	_email_selected_folder = folder
	_email_selected_idx = -1
	_email_current_mail = {}
	_email_apply_folder_button_state(_email_folder_inbox_btn, folder == "all")
	if _email_preview_header:
		_email_preview_header.text = ""
	if _email_preview_body:
		_email_preview_body.text = ""
	if _email_confirm_btn:
		_email_confirm_btn.visible = false
	if _email_reject_btn:
		_email_reject_btn.visible = false
	_email_refresh_list()


func _email_refresh_list() -> void:
	if _email_list_vbox == null:
		return
	for c in _email_list_vbox.get_children():
		c.queue_free()

	var mails: Array = EmailManager.inbox.duplicate()
	mails.sort_custom(func(a, b): return _email_mail_sort_key(a) > _email_mail_sort_key(b))

	if mails.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No messages in mailbox."
		empty_lbl.custom_minimum_size = Vector2(0, 28)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.27, 0.22, 0.16, 1.0))
		_email_list_vbox.add_child(empty_lbl)

	var idx := 0
	var has_current_selection := not _email_current_mail.is_empty()
	for mail in mails:
		var is_unread: bool = not bool(mail.get("_read", false))
		var is_selected := false
		if has_current_selection and is_same(mail, _email_current_mail):
			is_selected = true
			_email_selected_idx = idx
		elif not has_current_selection and _email_selected_idx == idx:
			is_selected = true

		var row = Button.new()
		row.flat = false
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(0, 44)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row_bg = Color(0.81, 0.77, 0.69, 0.98) if idx % 2 == 0 else Color(0.76, 0.72, 0.64, 0.98)
		if is_selected:
			row_bg = Color(0.66, 0.58, 0.44, 0.99)
		var row_border = Color(0.34, 0.28, 0.20, 0.95)
		if is_selected:
			row_border = Color(0.42, 0.33, 0.22, 1.0)
		var row_style_normal = _make_panel_style(row_bg, row_border, 1, 0)
		var row_style_hover = _make_panel_style(row_bg.lightened(0.05), row_border.darkened(0.08), 1, 0)
		row.add_theme_stylebox_override("normal", row_style_normal)
		row.add_theme_stylebox_override("hover", row_style_hover)
		row.add_theme_stylebox_override("pressed", row_style_hover)
		row.add_theme_stylebox_override("focus", row_style_normal)

		var sender: String = _mail_sender_short(str(mail.get("from", "Unknown")))
		var subject: String = str(mail.get("subject", "(no subject)"))
		if subject.length() > 52:
			subject = subject.left(50) + ".."
		if _email_is_booking_mail(mail):
			subject = "[CUSTOMER] " + subject
		elif str(mail.get("type", "")).to_lower().strip_edges() == "spam":
			subject = "[SPAM] " + subject
		var snippet = _email_mail_snippet(mail)
		var preview_line = subject if snippet.is_empty() else "%s - %s" % [subject, snippet]
		if preview_line.length() > 92:
			preview_line = preview_line.left(90) + ".."

		var content = MarginContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8.0
		content.offset_top = 4.0
		content.offset_right = -8.0
		content.offset_bottom = -4.0
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(content)

		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(col)

		var head = HBoxContainer.new()
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(head)

		var sender_lbl = Label.new()
		sender_lbl.text = ("%s%s" % ["● " if is_unread else "", sender])
		sender_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sender_lbl.add_theme_font_size_override("font_size", 11)
		sender_lbl.add_theme_color_override("font_color", Color(0.16, 0.12, 0.09, 1.0) if is_unread else Color(0.22, 0.17, 0.12, 1.0))
		sender_lbl.clip_text = true
		sender_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(sender_lbl)

		var time_lbl = Label.new()
		time_lbl.text = _email_mail_datetime_label(mail)
		time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		time_lbl.add_theme_font_size_override("font_size", 10)
		time_lbl.add_theme_color_override("font_color", Color(0.24, 0.20, 0.14, 1.0))
		time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(time_lbl)

		var preview_lbl = Label.new()
		preview_lbl.text = preview_line
		preview_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_lbl.add_theme_font_size_override("font_size", 10)
		preview_lbl.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0) if is_unread else Color(0.34, 0.28, 0.20, 1.0))
		preview_lbl.clip_text = true
		preview_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(preview_lbl)

		var captured_mail: Dictionary = mail
		var captured_idx: int = idx
		row.pressed.connect(func(): _email_open_message(captured_mail, captured_idx))
		_email_list_vbox.add_child(row)
		idx += 1

	# Update folder button labels with counts
	var total_count: int = int(EmailManager.inbox.size())
	var unread_count: int = int(EmailManager.inbox.filter(func(m): return not m.get("_read", false)).size())
	var customer_count: int = int(EmailManager.inbox.filter(func(m): return _email_is_booking_mail(m)).size())
	var spam_count: int = int(EmailManager.inbox.filter(func(m): return str(m.get("type", "")).to_lower().strip_edges() == "spam").size())

	if _email_folder_inbox_btn:
		_email_folder_inbox_btn.text = "ALL %d | C:%d S:%d%s" % [total_count, customer_count, spam_count, "*" if unread_count > 0 else ""]
		_email_apply_folder_button_state(_email_folder_inbox_btn, _email_selected_folder == "all")

	var email_win_any = _app_windows.get("email", null)
	if email_win_any is Control and is_instance_valid(email_win_any):
		var email_win := email_win_any as Control
		var masthead_status = email_win.get_node_or_null("EmailMasthead/EmailMastheadStatus") as Label
		if masthead_status != null:
			masthead_status.text = "INBOX %d | UNREAD %d | C:%d | S:%d" % [total_count, unread_count, customer_count, spam_count]


func _email_open_message(mail: Dictionary, idx: int) -> void:
	_email_selected_idx = idx
	_email_current_mail = mail
	EmailManager.mark_read(mail)
	_email_refresh_list()  # refresh to clear unread star

	if _email_preview_header == null or _email_preview_body == null:
		return

	var type_label = str(mail.get("type", "mail")).to_upper()
	if type_label.is_empty():
		type_label = "MAIL"
	var hdr: String = "[b]%s[/b]\n[b]From:[/b] %s\n[b]To:[/b] camp.reception@camp.local\n[b]Subject:[/b] %s\n[b]Received:[/b] %s" % [
		type_label,
		str(mail.get("from", "?")),
		str(mail.get("subject", "(no subject)")),
		_email_mail_datetime_label(mail)
	]
	_email_preview_header.text = hdr
	_email_preview_body.text = _email_compose_preview_body(mail)

	var is_customer: bool = _email_is_booking_mail(mail)
	var already_actioned: bool = bool(mail.get("_actioned", false))
	var can_accept: bool = true
	if is_customer and EmailManager != null and EmailManager.has_method("can_accept_customer_booking"):
		can_accept = bool(EmailManager.can_accept_customer_booking(mail))
	if _email_confirm_btn:
		_email_confirm_btn.visible = is_customer and not already_actioned
		_email_confirm_btn.disabled = already_actioned or not can_accept
		_email_confirm_btn.text = "Accept" if can_accept else "No Free Beds"
	if _email_reject_btn:
		_email_reject_btn.visible = is_customer and not already_actioned
		_email_reject_btn.disabled = already_actioned


func _on_email_confirm_pressed() -> void:
	if _email_current_mail.is_empty():
		return
	var confirmed = bool(EmailManager.confirm_customer_booking(_email_current_mail))
	if not confirmed:
		if _email_preview_body:
			_email_preview_body.text = _email_compose_preview_body(_email_current_mail) + \
				"\n\n-- ACCEPT FAILED: NO FREE BEDS --"
		_email_refresh_list()
		return
	if _email_confirm_btn:
		_email_confirm_btn.visible = false
	if _email_reject_btn:
		_email_reject_btn.visible = false
	# Show confirmation in body
	if _email_preview_body:
		_email_preview_body.text = _email_compose_preview_body(_email_current_mail) + \
			"\n\n-- ACCEPTED: GUEST CHECKED-IN --"
	_email_refresh_list()


func _on_email_reject_pressed() -> void:
	if _email_current_mail.is_empty():
		return
	var rejected_subject = str(_email_current_mail.get("subject", "(no subject)"))
	EmailManager.reject_customer_booking(_email_current_mail)
	_email_current_mail = {}
	_email_selected_idx = -1
	if _email_confirm_btn:
		_email_confirm_btn.visible = false
	if _email_reject_btn:
		_email_reject_btn.visible = false
	if _email_preview_header:
		_email_preview_header.text = "[b]MESSAGE REMOVED[/b]\n[b]SUBJECT:[/b] %s" % rejected_subject
	if _email_preview_body:
		_email_preview_body.text = "Booking request refused.\nEmail was removed from mailbox."
	_email_refresh_list()


func _email_update_unread_indicator(count: int) -> void:
	if _top_bar_email_indicator == null:
		return
	if count > 0:
		_top_bar_email_indicator.text = "MAIL %02d" % count
		_top_bar_email_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_top_bar_email_indicator.text = "MAIL --"
		_top_bar_email_indicator.modulate = Color(0.80, 0.80, 0.80, 1.0)


func _open_text_window(window_id: String, title: String, text: String) -> void:
	var win = _create_window_base(window_id, title, Vector2(380, 250))
	_app_windows[window_id] = win
	_add_taskbar_button(window_id, title, win)

	var body = RichTextLabel.new()
	body.bbcode_enabled = false
	body.text = text
	body.position = Vector2(8, 36)
	body.size = Vector2(win.size.x - 16, win.size.y - 44)
	body.scroll_active = true
	body.add_theme_stylebox_override("normal", _make_panel_style(Color(0.17, 0.19, 0.18, 0.92), Color(0.38, 0.36, 0.32, 1.0), 1, 0))
	body.add_theme_color_override("default_color", COL_OS_TEXT_LIGHT)
	win.add_child(body)

	_queue_window_open(win, window_id == "guestrack")


func _create_window_base(window_id: String, title: String, window_size: Vector2) -> Panel:
	var win = Panel.new()
	win.visible = false
	win.clip_contents = true
	win.size = window_size
	var style = _make_panel_style(COL_OS_WINDOW_BG, COL_OS_BORDER, 2, 0)
	win.add_theme_stylebox_override("panel", style)
	_update_window_layer_state()
	_window_layer.add_child(win)

	var vp = _get_layout_size()
	# Cascade windows so they don't stack exactly on top of each other
	var cascade_offset = Vector2(30.0, 30.0) * float(_window_cascade_counter % 8)
	win.position = ((vp - win.size) * 0.5) + cascade_offset
	win.position.x = clampf(win.position.x, 0.0, max(0.0, vp.x - win.size.x))
	win.position.y = clampf(win.position.y, 0.0, max(0.0, vp.y - win.size.y - 30.0))
	_window_cascade_counter += 1

	var title_bar = Button.new()
	title_bar.name = "TitleBar"
	title_bar.flat = true
	title_bar.focus_mode = FOCUS_NONE
	title_bar.size = Vector2(win.size.x - 4, 26)
	title_bar.position = Vector2(2, 2)
	win.add_child(title_bar)

	var tb_bg = ColorRect.new()
	tb_bg.color = COL_WIN98_TITLE
	tb_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	tb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(tb_bg)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", COL_OS_TEXT_LIGHT)
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.position = Vector2(6, 0)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size.x = maxf(20.0, title_bar.size.x - 90.0)
	title_lbl.size.y = 26
	title_bar.add_child(title_lbl)

	title_bar.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging_window = win
				_dragging_window_offset = event.global_position - win.position
				win.move_to_front()
				_update_taskbar_button_state(window_id, true)
			elif _dragging_window == win:
				_dragging_window = null
	)

	win.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			win.move_to_front()
	)

	var close = Button.new()
	close.name = "CloseBtn"
	close.text = "X"
	close.size = TITLEBAR_BUTTON_SIZE
	close.position = Vector2(title_bar.size.x - TITLEBAR_BUTTON_RIGHT_MARGIN - close.size.x, TITLEBAR_BUTTON_TOP)
	_apply_titlebar_button_style(close, true)
	close.pressed.connect(func():
		_close_app_window(window_id)
	)
	title_bar.add_child(close)

	var maximize = Button.new()
	maximize.name = "MaxBtn"
	maximize.text = "[]"
	maximize.size = TITLEBAR_BUTTON_SIZE
	maximize.position = Vector2(close.position.x - maximize.size.x - TITLEBAR_BUTTON_GAP, TITLEBAR_BUTTON_TOP)
	_apply_titlebar_button_style(maximize)
	title_bar.add_child(maximize)

	var minimize = Button.new()
	minimize.name = "MinBtn"
	minimize.text = "-"
	minimize.size = TITLEBAR_BUTTON_SIZE
	minimize.position = Vector2(maximize.position.x - minimize.size.x - TITLEBAR_BUTTON_GAP, TITLEBAR_BUTTON_TOP)
	_apply_titlebar_button_style(minimize)
	minimize.pressed.connect(func():
		win.visible = false
		_update_window_layer_state()
		_update_taskbar_button_state(window_id, false)
	)
	title_bar.add_child(minimize)

	var maximize_state := {
		"is_maximized": false,
		"pre_max_pos": Vector2.ZERO,
		"pre_max_size": Vector2.ZERO,
	}

	maximize.pressed.connect(func():
		var is_maximized_now = bool(maximize_state.get("is_maximized", false))
		if not is_maximized_now:
			maximize_state["pre_max_pos"] = win.position
			maximize_state["pre_max_size"] = win.size
			win.position = Vector2.ZERO
			var vp_size = _get_layout_size()
			win.size = Vector2(vp_size.x, vp_size.y - 28)
			maximize_state["is_maximized"] = true
		else:
			var restored_pos: Vector2 = maximize_state.get("pre_max_pos", Vector2.ZERO)
			var restored_size: Vector2 = maximize_state.get("pre_max_size", win.size)
			win.position = restored_pos
			win.size = restored_size
			maximize_state["is_maximized"] = false

		# Update sub-elements
		title_bar.size.x = win.size.x - 4
		# tb_bg has anchors preset full rect, so it should follow if title_bar changes?
		# Actually title_bar is a Button, we need to ensure its size updates.
		close.position.x = title_bar.size.x - TITLEBAR_BUTTON_RIGHT_MARGIN - close.size.x
		maximize.position.x = close.position.x - maximize.size.x - TITLEBAR_BUTTON_GAP
		minimize.position.x = maximize.position.x - minimize.size.x - TITLEBAR_BUTTON_GAP

		for child in win.get_children():
			if child is RichTextLabel:
				child.size = Vector2(win.size.x - 16, win.size.y - 44)
	)

	return win

func _close_app_window(window_id: String) -> void:
	if _app_windows.has(window_id):
		var win = _app_windows[window_id]
		win.visible = false
		if window_id == "builder":
			_builder_module = null
		elif window_id == "guestrack":
			_guestrack_panel = null
		_window_open_sequence_id += 1
		_update_window_layer_state()
		_remove_taskbar_button(window_id)


func _add_taskbar_button(window_id: String, title: String, window_ref: Control, custom_callback: Callable = Callable()) -> void:
	if _taskbar_container == null: return
	if _taskbar_buttons.has(window_id): return

	var btn = Button.new()
	btn.text = title
	btn.clip_text = true
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.custom_minimum_size = Vector2(TASKBAR_BUTTON_WIDTH, TASKBAR_BUTTON_HEIGHT)
	btn.focus_mode = Control.FOCUS_NONE
	_apply_win95_button_style(btn, COL_OS_TEXT_DARK)

	btn.pressed.connect(func():
		if custom_callback.is_valid():
			custom_callback.call()
		else:
			if window_ref.visible:
				# In Win95, if you click the button of the ACTIVE window, it minimizes.
				# If it's NOT active but visible, it should just MOVE TO FRONT.
				if window_ref.get_index() == window_ref.get_parent().get_child_count() - 1:
					window_ref.visible = false
				else:
					window_ref.move_to_front()
					window_ref.visible = true
			else:
				window_ref.visible = true
				window_ref.move_to_front()
			_update_window_layer_state()
			_update_taskbar_button_state(window_id, window_ref.visible)
	)

	_taskbar_container.add_child(btn)
	_taskbar_buttons[window_id] = btn
	# Initial state check
	var window_visible = window_ref.visible if window_ref else false
	_update_taskbar_button_state(window_id, window_visible)

func _remove_taskbar_button(window_id: String) -> void:
	if _taskbar_buttons.has(window_id):
		var btn = _taskbar_buttons[window_id]
		btn.queue_free()
		_taskbar_buttons.erase(window_id)

func _update_taskbar_button_state(window_id: String, window_visible: bool) -> void:
	if _taskbar_buttons.has(window_id):
		var btn = _taskbar_buttons[window_id] as Button
		# In Win95, active window button is "pressed" (sunken).
		# We can use our _apply_win95_button_style logic or just set specific style overlay.
		# For now, let's just use font color or maybe a custom style tweak.
		if window_visible:
			btn.add_theme_color_override("font_color", COL_OS_TEXT_DARK)
			var base = COL_OS_WINDOW_BG.darkened(0.12)
			var pressed = _make_panel_style(base, COL_OS_BORDER.darkened(0.2), 2, 0)
			pressed.border_width_left = 2; pressed.border_width_top = 2
			pressed.border_width_right = 1; pressed.border_width_bottom = 1
			btn.add_theme_stylebox_override("normal", pressed)
		else:
			# Restore normal style (popped out)
			_apply_win95_button_style(btn, COL_OS_TEXT_DARK)


func _update_window_layer_state() -> void:
	if _window_layer == null:
		return
	var has_visible_windows = false
	for win in _app_windows.values():
		var panel = win as Panel
		if panel != null and panel.visible:
			has_visible_windows = true
			break
	_window_layer.visible = has_visible_windows


func _placeholder_logout() -> void:
	_close_start_menu()
	# Log Out — placeholder, not yet implemented


func _shutdown_desktop() -> void:
	_close_start_menu()
	power_off()



# ═══════════════════════════════════════════════════════════════════════════
# BEETERNET — desktop launcher
# ═══════════════════════════════════════════════════════════════════════════

func _layout_window_module_content(win: Panel, module_ctrl: Control) -> void:
	if win == null or module_ctrl == null:
		return
	module_ctrl.position = Vector2(8.0, 36.0)
	module_ctrl.size = Vector2(maxf(120.0, win.size.x - 16.0), maxf(80.0, win.size.y - 44.0))
	if module_ctrl.has_method("_relayout"):
		module_ctrl.call("_relayout")


func _open_beeternet_app() -> void:
	_close_start_menu()
	if not _is_program_unlocked("beeternet"):
		return
	if _app_windows.has("beeternet") and is_instance_valid(_app_windows["beeternet"]):
		var existing = _app_windows["beeternet"]
		if not _taskbar_buttons.has("beeternet"):
			_add_taskbar_button("beeternet", "Beeternet", existing)
		existing.visible = true
		existing.move_to_front()
		_update_window_layer_state()
		_update_taskbar_button_state("beeternet", true)
		return

	var win = _create_window_base("beeternet", "Beeternet", Vector2(760, 520))
	_app_windows["beeternet"] = win
	_add_taskbar_button("beeternet", "Beeternet", win)

	var BeetenetScript = load("res://scripts/beeternet.gd")
	if BeetenetScript == null:
		push_error("beeternet.gd not found")
		_close_app_window("beeternet")
		_app_windows.erase("beeternet")
		return
	var browser: Control = BeetenetScript.new()
	if browser.has_method("set_desktop_context"):
		browser.call("set_desktop_context", _downloads_items, _unlock_registry)
	win.add_child(browser)
	_layout_window_module_content(win, browser)
	win.resized.connect(func():
		if is_instance_valid(browser):
			_layout_window_module_content(win, browser)
	)
	if browser.has_signal("link_hover_entered"):
		browser.link_hover_entered.connect(func(): _apply_cursor_hand())
	if browser.has_signal("link_hover_exited"):
		browser.link_hover_exited.connect(func(): _apply_cursor_default())
	_queue_window_open(win)


# ═══════════════════════════════════════════════════════════════════════════
# DOWNLOADS FOLDER — desktop shell
# ═══════════════════════════════════════════════════════════════════════════

func _add_to_downloads(filename: String) -> void:
	if filename in _downloads_items:
		return
	_downloads_items.append(filename)


func _get_installer_filename(app_id: String) -> String:
	return str(APP_INSTALLERS.get(app_id, ""))


func _get_app_id_for_installer(filename: String) -> String:
	for app_id in APP_INSTALLERS.keys():
		if str(APP_INSTALLERS.get(app_id, "")) == filename:
			return str(app_id)
	return ""


func _move_download_to_bin(filename: String) -> void:
	if not filename in _downloads_items:
		return
	_downloads_items.erase(filename)
	if not filename in _bin_items:
		_bin_items.append(filename)
	_refresh_bin_icon()


func _restore_from_bin(filename: String) -> void:
	if not filename in _bin_items:
		return
	_bin_items.erase(filename)
	if not filename in _downloads_items:
		_downloads_items.append(filename)
	_refresh_bin_icon()


func _open_downloads_folder() -> void:
	_close_start_menu()
	if not _is_program_unlocked("downloads"):
		return
	if _app_windows.has("downloads") and is_instance_valid(_app_windows["downloads"]):
		_remove_taskbar_button("downloads")
		_app_windows["downloads"].queue_free()
	_app_windows.erase("downloads")

	var win = _create_window_base("downloads", "Downloads", Vector2(520, 360))
	_app_windows["downloads"] = win
	_add_taskbar_button("downloads", "Downloads", win)

	var masthead := Panel.new()
	masthead.name = "DownloadsMasthead"
	masthead.add_theme_stylebox_override("panel", _make_panel_style(Color(0.34, 0.20, 0.12, 1.0), Color(0.34, 0.28, 0.20, 1.0), 2, 0))
	win.add_child(masthead)

	var title := Label.new()
	title.name = "DownloadsTitle"
	title.text = "DOWNLOADS 98"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	masthead.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "DownloadsSubtitle"
	subtitle.text = "Offline Transfer Cache and Setup Queue"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.90, 0.86, 0.78, 1.0))
	masthead.add_child(subtitle)

	var count_lbl := Label.new()
	count_lbl.name = "DownloadsCount"
	count_lbl.text = "FILES 0"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	masthead.add_child(count_lbl)

	var body := Panel.new()
	body.name = "DownloadsBody"
	body.add_theme_stylebox_override("panel", _make_panel_style(Color(0.78, 0.74, 0.65, 1.0), Color(0.34, 0.28, 0.20, 1.0), 1, 0))
	win.add_child(body)

	var content := RichTextLabel.new()
	content.name = "DownloadsContent"
	content.bbcode_enabled = true
	content.scroll_active = true
	content.fit_content = false
	content.add_theme_stylebox_override("normal", _make_panel_style(Color(0.80, 0.76, 0.68, 1.0), Color(0.34, 0.28, 0.20, 1.0), 1, 0))
	content.add_theme_color_override("default_color", Color(0.16, 0.12, 0.09, 1.0))
	content.add_theme_font_size_override("normal_font_size", 11)
	content.meta_hover_started.connect(func(_m: Variant): _apply_cursor_hand())
	content.meta_hover_ended.connect(func(_m: Variant): _apply_cursor_default())
	content.meta_clicked.connect(func(meta: Variant):
		var url = str(meta)
		if url.begins_with("run://"):
			_handle_downloads_run(url.substr(6))
		elif url.begins_with("trash://"):
			_move_download_to_bin(url.substr(8))
			_open_downloads_folder()
	)
	body.add_child(content)

	_layout_downloads_folder_window(win)
	_refresh_downloads_folder_content(win)
	win.resized.connect(func() -> void:
		if is_instance_valid(win):
			_layout_downloads_folder_window(win)
	)
	_queue_window_open(win)


func _layout_downloads_folder_window(win: Panel) -> void:
	if win == null or not is_instance_valid(win):
		return
	var title_h := 30.0
	var masthead_h := 58.0
	var content_y := title_h + 4.0
	var total_w := win.size.x
	var masthead_w := total_w - 4.0
	var body_y := content_y + masthead_h + 6.0
	var body_h := win.size.y - body_y - 2.0

	var masthead = win.get_node_or_null("DownloadsMasthead") as Control
	if masthead != null:
		masthead.position = Vector2(2.0, content_y)
		masthead.size = Vector2(masthead_w, masthead_h)
		var title = masthead.get_node_or_null("DownloadsTitle") as Label
		if title != null:
			title.position = Vector2(10.0, 7.0)
		var subtitle = masthead.get_node_or_null("DownloadsSubtitle") as Label
		if subtitle != null:
			subtitle.position = Vector2(12.0, 32.0)
			subtitle.size = Vector2(maxf(170.0, masthead_w - 190.0), 16.0)
		var count_lbl = masthead.get_node_or_null("DownloadsCount") as Label
		if count_lbl != null:
			count_lbl.position = Vector2(0.0, 11.0)
			count_lbl.size = Vector2(masthead_w - 12.0, 18.0)

	var body = win.get_node_or_null("DownloadsBody") as Control
	if body != null:
		body.position = Vector2(2.0, body_y)
		body.size = Vector2(total_w - 4.0, body_h)
		var content = body.get_node_or_null("DownloadsContent") as RichTextLabel
		if content != null:
			content.position = Vector2(8.0, 8.0)
			content.size = Vector2(maxf(120.0, body.size.x - 16.0), maxf(90.0, body.size.y - 16.0))


func _refresh_downloads_folder_content(win: Panel) -> void:
	if win == null or not is_instance_valid(win):
		return
	var content = win.get_node_or_null("DownloadsBody/DownloadsContent") as RichTextLabel
	var count_lbl = win.get_node_or_null("DownloadsMasthead/DownloadsCount") as Label
	if count_lbl != null:
		count_lbl.text = "FILES %d" % _downloads_items.size()
	if content == null:
		return

	if _downloads_items.is_empty():
		content.text = "[color=#4f4638]No files in Downloads.[/color]"
		return

	var t = "[b]Downloads Index[/b]\n[color=#5e5343]%d item(s)[/color]\n\n" % _downloads_items.size()
	for fname in _downloads_items:
		var app_id := _get_app_id_for_installer(fname)
		if app_id.is_empty():
			t += "■  [color=#2b2419]%s[/color]\n    [url=trash://%s][color=#7d2f24]Move to Bin[/color][/url]\n\n" % [fname, fname]
		else:
			t += "►  [color=#2b2419]%s[/color]\n    [url=run://%s][color=#2f5423]Run Installer[/color][/url]  [url=trash://%s][color=#7d2f24]Move to Bin[/color][/url]\n\n" % [fname, fname, fname]
	t += "[color=#5e5343][i]Installers unlock software. Use Bin for temporary cleanup.[/i][/color]"
	content.text = t


func _handle_downloads_run(filename: String) -> void:
	var app_id := _get_app_id_for_installer(filename)
	if not app_id.is_empty():
		_close_app_window("downloads")
		_app_windows.erase("downloads")
		_open_install_wizard(app_id)


func _get_app_display_name(app_id: String) -> String:
	match app_id:
		"builder":
			return "Builder"
		"guestrack":
			return "GuestRack"
		"camp_status":
			return "Camp Status"
		"finance":
			return "Finance"
		"minesweeper":
			return "Minesweeper"
		"campmail":
			return "CampMail"
		_:
			return app_id.capitalize()


func _open_install_wizard(app_id: String) -> void:
	var wid = "wizard_" + app_id
	if _app_windows.has(wid) and is_instance_valid(_app_windows[wid]):
		var existing = _app_windows[wid]
		if not _taskbar_buttons.has(wid):
			_add_taskbar_button(wid, "Setup", existing)
		existing.visible = true
		existing.move_to_front()
		_update_window_layer_state()
		_update_taskbar_button_state(wid, true)
		return

	var title = "Setup Wizard — %s" % _get_app_display_name(app_id)
	var win = _create_window_base(wid, title, Vector2(520, 370))
	_app_windows[wid] = win
	_add_taskbar_button(wid, "Setup", win)

	var WizardScript = load("res://scripts/install_wizard.gd")
	if WizardScript == null:
		push_error("install_wizard.gd not found")
		_close_app_window(wid)
		_app_windows.erase(wid)
		return
	var wizard: Control = WizardScript.new()
	wizard.app_id = app_id
	win.add_child(wizard)
	_layout_window_module_content(win, wizard)
	win.resized.connect(func():
		if is_instance_valid(wizard):
			_layout_window_module_content(win, wizard)
	)
	wizard.close_requested.connect(func():
		_close_app_window(wid)
		_app_windows.erase(wid)
	)
	_queue_window_open(win)


# ═══════════════════════════════════════════════════════════════════════════
# BIN FOLDER — desktop shell
# ═══════════════════════════════════════════════════════════════════════════

func _open_bin_folder() -> void:
	_close_start_menu()
	if not _is_program_unlocked("bin"):
		return
	if _app_windows.has("bin") and is_instance_valid(_app_windows["bin"]):
		_remove_taskbar_button("bin")
		_app_windows["bin"].queue_free()
	_app_windows.erase("bin")

	var win = _create_window_base("bin", "Bin", Vector2(500, 330))
	_app_windows["bin"] = win
	_add_taskbar_button("bin", "Bin", win)

	var masthead := Panel.new()
	masthead.name = "BinMasthead"
	masthead.add_theme_stylebox_override("panel", _make_panel_style(Color(0.34, 0.20, 0.12, 1.0), Color(0.34, 0.28, 0.20, 1.0), 2, 0))
	win.add_child(masthead)

	var title := Label.new()
	title.name = "BinTitle"
	title.text = "RECYCLE BIN 98"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	masthead.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "BinSubtitle"
	subtitle.text = "Staged Disposal and Recovery"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.90, 0.86, 0.78, 1.0))
	masthead.add_child(subtitle)

	var count_lbl := Label.new()
	count_lbl.name = "BinCount"
	count_lbl.text = "FILES 0"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	masthead.add_child(count_lbl)

	var body := Panel.new()
	body.name = "BinBody"
	body.add_theme_stylebox_override("panel", _make_panel_style(Color(0.78, 0.74, 0.65, 1.0), Color(0.34, 0.28, 0.20, 1.0), 1, 0))
	win.add_child(body)

	var content := RichTextLabel.new()
	content.name = "BinContent"
	content.bbcode_enabled = true
	content.scroll_active = true
	content.fit_content = false
	content.add_theme_stylebox_override("normal", _make_panel_style(Color(0.80, 0.76, 0.68, 1.0), Color(0.34, 0.28, 0.20, 1.0), 1, 0))
	content.add_theme_color_override("default_color", Color(0.16, 0.12, 0.09, 1.0))
	content.add_theme_font_size_override("normal_font_size", 11)
	content.meta_hover_started.connect(func(_m: Variant): _apply_cursor_hand())
	content.meta_hover_ended.connect(func(_m: Variant): _apply_cursor_default())
	content.meta_clicked.connect(func(meta: Variant):
		var url = str(meta)
		if url.begins_with("restore://"):
			_restore_from_bin(url.substr(10))
			_open_bin_folder()
		elif url.begins_with("empty://"):
			_empty_bin_items()
			_open_bin_folder()
	)
	body.add_child(content)

	_layout_bin_folder_window(win)
	_refresh_bin_folder_content(win)
	win.resized.connect(func() -> void:
		if is_instance_valid(win):
			_layout_bin_folder_window(win)
	)
	_queue_window_open(win)


func _layout_bin_folder_window(win: Panel) -> void:
	if win == null or not is_instance_valid(win):
		return
	var title_h := 30.0
	var masthead_h := 58.0
	var content_y := title_h + 4.0
	var total_w := win.size.x
	var masthead_w := total_w - 4.0
	var body_y := content_y + masthead_h + 6.0
	var body_h := win.size.y - body_y - 2.0

	var masthead = win.get_node_or_null("BinMasthead") as Control
	if masthead != null:
		masthead.position = Vector2(2.0, content_y)
		masthead.size = Vector2(masthead_w, masthead_h)
		var title = masthead.get_node_or_null("BinTitle") as Label
		if title != null:
			title.position = Vector2(10.0, 7.0)
		var subtitle = masthead.get_node_or_null("BinSubtitle") as Label
		if subtitle != null:
			subtitle.position = Vector2(12.0, 32.0)
			subtitle.size = Vector2(maxf(170.0, masthead_w - 190.0), 16.0)
		var count_lbl = masthead.get_node_or_null("BinCount") as Label
		if count_lbl != null:
			count_lbl.position = Vector2(0.0, 11.0)
			count_lbl.size = Vector2(masthead_w - 12.0, 18.0)

	var body = win.get_node_or_null("BinBody") as Control
	if body != null:
		body.position = Vector2(2.0, body_y)
		body.size = Vector2(total_w - 4.0, body_h)
		var content = body.get_node_or_null("BinContent") as RichTextLabel
		if content != null:
			content.position = Vector2(8.0, 8.0)
			content.size = Vector2(maxf(120.0, body.size.x - 16.0), maxf(90.0, body.size.y - 16.0))


func _refresh_bin_folder_content(win: Panel) -> void:
	if win == null or not is_instance_valid(win):
		return
	var content = win.get_node_or_null("BinBody/BinContent") as RichTextLabel
	var count_lbl = win.get_node_or_null("BinMasthead/BinCount") as Label
	if count_lbl != null:
		count_lbl.text = "FILES %d" % _bin_items.size()
	if content == null:
		return
	if _bin_items.is_empty():
		content.text = "[color=#4f4638]Bin is empty.[/color]\n\n[color=#5e5343][i]Disposed files are removed permanently after Empty Bin.[/i][/color]"
		return

	var t = "[b]Recovery Queue[/b]\n[color=#5e5343]%d item(s)[/color]\n\n" % _bin_items.size()
	t += "[url=empty://all][color=#7d2f24][b]Empty Bin[/b][/color][/url]\n\n"
	for fname in _bin_items:
		t += "■  [color=#2b2419]%s[/color]  [url=restore://%s][color=#2f5c7b]Restore[/color][/url]\n" % [fname, fname]
	t += "\n[color=#5e5343][i]Restore returns a file to Downloads.[/i][/color]"
	content.text = t


func _empty_bin_items() -> void:
	if _bin_items.is_empty():
		return
	_bin_items.clear()
	_refresh_bin_icon()


func _refresh_bin_icon() -> void:
	if _bin_icon_img == null or not is_instance_valid(_bin_icon_img):
		return
	var icon_path = ASSET_ICON_BIN_FULL if not _bin_items.is_empty() else ASSET_ICON_BIN_EMPTY
	var tex = _safe_load_texture(icon_path)
	if tex != null:
		_bin_icon_img.texture = tex


# ═══════════════════════════════════════════════════════════════════════════
# UNLOCK SYSTEM — desktop reakce na EventBus.program_installed
# ═══════════════════════════════════════════════════════════════════════════

func _is_program_unlocked(app_id: String) -> bool:
	return _unlock_registry.get(app_id, false)


func _on_program_installed(app_id: String) -> void:
	if _is_program_unlocked(app_id):
		return
	_unlock_registry[app_id] = true
	var installer_file := _get_installer_filename(app_id)
	if not installer_file.is_empty():
		_downloads_items.erase(installer_file)
		if not installer_file in _bin_items:
			_bin_items.append(installer_file)
	_refresh_bin_icon()
	_sync_program_visibility(app_id)


func export_persistent_state() -> Dictionary:
	return {
		"unlock_registry": _sanitize_unlock_registry_snapshot(),
		"downloads": _sanitize_string_array(_downloads_items),
		"bin": _sanitize_string_array(_bin_items),
		"desktop_icon_layout": _capture_desktop_icon_layout_snapshot(),
		"monitor_powered": bool(_monitor_powered)
	}


func import_persistent_state(data: Dictionary) -> void:
	_reset_unlock_registry_to_defaults()
	if data.is_empty():
		_downloads_items.clear()
		_bin_items.clear()
		_sync_all_program_visibility()
		_refresh_bin_icon()
		_pending_desktop_icon_layout.clear()
		_apply_pending_desktop_icon_layout()
		_monitor_powered = false
		_current_state = os_state.OFF
		_apply_state_visibility()
		return

	var unlocks_any = data.get("unlock_registry", {})
	if unlocks_any is Dictionary:
		var unlocks := unlocks_any as Dictionary
		for app_id in DEFAULT_UNLOCK_STATE.keys():
			if unlocks.has(app_id):
				_unlock_registry[app_id] = bool(unlocks[app_id])
		for key_any in unlocks.keys():
			var key := str(key_any).strip_edges()
			if key.is_empty():
				continue
			_unlock_registry[key] = bool(unlocks[key_any])

	_downloads_items = _sanitize_string_array(data.get("downloads", []))
	_bin_items = _sanitize_string_array(data.get("bin", []))
	_remove_downloads_that_are_in_bin()
	var layout_any = data.get("desktop_icon_layout", data.get("icon_layout", {}))
	if layout_any is Dictionary:
		_pending_desktop_icon_layout = (layout_any as Dictionary).duplicate(true)
	else:
		_pending_desktop_icon_layout.clear()
	_sync_all_program_visibility()
	_refresh_bin_icon()
	_apply_pending_desktop_icon_layout()
	_monitor_powered = bool(data.get("monitor_powered", true))
	_current_state = os_state.DESKTOP if _monitor_powered else os_state.OFF
	_apply_state_visibility()


func _sanitize_unlock_registry_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for key_any in _unlock_registry.keys():
		var key := str(key_any).strip_edges()
		if key.is_empty():
			continue
		out[key] = bool(_unlock_registry[key_any])
	return out


func _sanitize_string_array(value: Variant) -> Array:
	var out: Array = []
	if not (value is Array):
		return out
	var seen: Dictionary = {}
	for item_any in value:
		var txt := str(item_any).strip_edges()
		if txt.is_empty() or seen.has(txt):
			continue
		seen[txt] = true
		out.append(txt)
	return out


func _capture_desktop_icon_layout_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for app_id in DESKTOP_ICON_ORDER:
		if not _desktop_program_icons.has(app_id):
			continue
		var icon_node = _desktop_program_icons[app_id] as Control
		if icon_node == null or not is_instance_valid(icon_node):
			continue
		var entry: Dictionary = {}
		if icon_node.has_meta(DESKTOP_ICON_SLOT_META):
			entry["slot"] = int(icon_node.get_meta(DESKTOP_ICON_SLOT_META, -1))
		var has_custom_pos := icon_node.has_meta("custom_pos")
		entry["custom_pos"] = has_custom_pos
		if has_custom_pos:
			entry["position"] = {
				"x": float(icon_node.position.x),
				"y": float(icon_node.position.y)
			}
		out[app_id] = entry
	return out


func _apply_pending_desktop_icon_layout() -> void:
	if _desktop_program_icons.is_empty():
		return
	_apply_desktop_icon_layout_snapshot(_pending_desktop_icon_layout.duplicate(true))
	_pending_desktop_icon_layout.clear()


func _apply_desktop_icon_layout_snapshot(layout_any: Variant) -> void:
	_clear_desktop_icon_layout_state()
	if not (layout_any is Dictionary):
		_reflow_desktop_program_icons()
		return

	var layout := layout_any as Dictionary
	var used_slots: Dictionary = {}
	for key_any in layout.keys():
		var app_id := str(key_any).strip_edges()
		if app_id.is_empty() or not _desktop_program_icons.has(app_id):
			continue
		var icon_node = _desktop_program_icons[app_id] as Control
		if icon_node == null or not is_instance_valid(icon_node):
			continue
		var entry_any = layout[key_any]
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var slot := int(entry.get("slot", -1))
		if slot < 0 or used_slots.has(slot):
			continue
		icon_node.set_meta(DESKTOP_ICON_SLOT_META, slot)
		used_slots[slot] = true

	for key_any in layout.keys():
		var app_id := str(key_any).strip_edges()
		if app_id.is_empty() or not _desktop_program_icons.has(app_id):
			continue
		var icon_node = _desktop_program_icons[app_id] as Control
		if icon_node == null or not is_instance_valid(icon_node):
			continue
		var entry_any = layout[key_any]
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		if not bool(entry.get("custom_pos", false)):
			continue
		var icon_position := _parse_desktop_icon_layout_position(entry.get("position", {}))
		icon_node.position = _clamp_desktop_icon_position(icon_node, icon_position)
		icon_node.set_meta("custom_pos", true)

	_reflow_desktop_program_icons()


func _clear_desktop_icon_layout_state() -> void:
	for icon_any in _desktop_program_icons.values():
		var icon_node = icon_any as Control
		if icon_node == null or not is_instance_valid(icon_node):
			continue
		if icon_node.has_meta(DESKTOP_ICON_SLOT_META):
			icon_node.remove_meta(DESKTOP_ICON_SLOT_META)
		if icon_node.has_meta("custom_pos"):
			icon_node.remove_meta("custom_pos")


func _parse_desktop_icon_layout_position(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Dictionary:
		var pos_dict := value as Dictionary
		return Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", DESKTOP_TOP_BAR_HEIGHT)))
	if value is Array:
		var arr := value as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(DESKTOP_ICON_COL0_X, DESKTOP_TOP_BAR_HEIGHT + DESKTOP_ICON_TOP_OFFSET)


func _clamp_desktop_icon_position(icon_node: Control, position: Vector2) -> Vector2:
	var vp := _get_layout_size()
	var icon_size := icon_node.size
	if icon_size.x <= 0.0 or icon_size.y <= 0.0:
		icon_size = DESKTOP_ICON_CONTAINER_SIZE
	var max_x := maxf(0.0, vp.x - icon_size.x)
	var min_y := DESKTOP_TOP_BAR_HEIGHT
	var max_y := maxf(min_y, vp.y - DESKTOP_TASKBAR_HEIGHT - icon_size.y)
	return Vector2(
		clampf(position.x, 0.0, max_x),
		clampf(position.y, min_y, max_y)
	)


func _remove_downloads_that_are_in_bin() -> void:
	if _downloads_items.is_empty() or _bin_items.is_empty():
		return
	var bin_lookup: Dictionary = {}
	for item in _bin_items:
		bin_lookup[str(item)] = true
	var cleaned: Array = []
	for item in _downloads_items:
		var txt := str(item)
		if not bin_lookup.has(txt):
			cleaned.append(txt)
	_downloads_items = cleaned


# ═══════════════════════════════════════════════════════════════════════════
# CURSOR SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

func _init_cursors() -> void:
	if _cursor_default_tex == null:
		_cursor_default_tex = _safe_load_texture(ASSET_CURSOR_DEFAULT)
	if _cursor_hand_tex == null:
		_cursor_hand_tex = _safe_load_texture(ASSET_CURSOR_HAND)
	_apply_cursor_default()


func _apply_cursor_default() -> void:
	_set_cursor_mode(false)


func _apply_cursor_hand() -> void:
	_set_cursor_mode(true)


func _set_cursor_mode(hand: bool) -> void:
	if _cursor_default_tex == null or _cursor_hand_tex == null:
		return
	var new_mode := 1 if hand else 0
	if _cursor_mode == new_mode:
		return
	_cursor_mode = new_mode
	if hand:
		Input.set_custom_mouse_cursor(_cursor_hand_tex, Input.CURSOR_ARROW, CURSOR_HAND_HOTSPOT)
	else:
		Input.set_custom_mouse_cursor(_cursor_default_tex, Input.CURSOR_ARROW, CURSOR_DEFAULT_HOTSPOT)
	# Keep the pointing-hand shape mapped to hand texture all the time.
	Input.set_custom_mouse_cursor(_cursor_hand_tex, Input.CURSOR_POINTING_HAND, CURSOR_HAND_HOTSPOT)


func _sync_cursor_visual_state() -> void:
	if _cursor_default_tex == null or _cursor_hand_tex == null:
		return
	var want_hand := false
	var vp := get_viewport()
	if vp != null:
		var hovered := vp.gui_get_hovered_control()
		if hovered != null and hovered.is_visible_in_tree():
			var local_pos := hovered.get_local_mouse_position()
			var cursor_shape := hovered.get_cursor_shape(local_pos)
			want_hand = cursor_shape == Control.CURSOR_POINTING_HAND
	_set_cursor_mode(want_hand)
