extends Control

const MAP_PANEL_SCRIPT = preload("res://scripts/crt_map_panel.gd")

const C_BG := Color(0.11, 0.11, 0.09, 1.0)
const C_PANEL := Color(0.20, 0.18, 0.14, 1.0)
const C_PANEL_ALT := Color(0.16, 0.15, 0.12, 1.0)
const C_BORDER := Color(0.36, 0.31, 0.22, 1.0)
const C_BORDER_DARK := Color(0.24, 0.21, 0.16, 1.0)
const C_BTN := Color(0.33, 0.29, 0.22, 1.0)
const C_BTN_ACTIVE := Color(0.22, 0.48, 0.74, 1.0)
const C_BTN_DANGER := Color(0.56, 0.18, 0.16, 1.0)
const C_BTN_PATH := Color(0.52, 0.38, 0.16, 1.0)
const C_BTN_LAMP := Color(0.56, 0.48, 0.12, 1.0)
const C_TEXT := Color(0.94, 0.90, 0.80, 1.0)
const C_TEXT_DIM := Color(0.66, 0.62, 0.54, 1.0)
const C_MONEY := Color(0.56, 0.98, 0.52, 1.0)
const C_STATUS_GOOD := Color(0.56, 0.94, 0.54, 1.0)
const C_STATUS_DENY := Color(0.98, 0.46, 0.38, 1.0)

## Reused system blip. Deny plays it detuned downward -- a "wrong" version of the
## sound the player already associates with the terminal accepting input.
const SFX_UI_BLIP := "res://assets/sfx/crtui/tudu.mp3"
const STATUS_FLASH_SEC := 0.45

const BTN_SIZE := Vector2(38, 38)
const TOOLBAR_HEIGHT := 52
const SUBMENU_HEIGHT := 50
const STATUS_HEIGHT := 20

const GROUPS: Array = [
	{
		"id": "housing",
		"items": [
			{"type": "tent_1", "name": "Tent", "icon": "res://assets/textury/builder/stan1.png"},
			{"type": "cabin_1", "name": "Cabin", "icon": "res://assets/textury/builder/chata1.PNG"},
			{"type": "caravan_1", "name": "Caravan (6 beds, needs power)", "icon": "res://assets/textury/builder/caravan.png"},
		],
	},
	{
		"id": "services",
		"items": [
			{"type": "toilet_block", "name": "Toilet", "icon": "res://assets/textury/builder/hajzly.PNG"},
			{"type": "shower_block", "name": "Shower", "icon": "res://assets/textury/builder/sprchy.PNG"},
			{"type": "pub", "name": "Pub", "icon": "res://assets/textury/builder/hospoda1.PNG"},
			{"type": "restaurant", "name": "Bistro", "icon": "res://assets/textury/builder/restaurace.PNG"},
			{"type": "vecerka", "name": "Jednota Mart", "icon": "res://assets/textury/builder/vecerka.jpg"},
		],
	},
	{
		"id": "attractions",
		"items": [
			{"type": "bonfire", "name": "Bonfire (fun, food, feels safe at night)", "icon": "res://assets/textury/builder/bonfire.png"},
			{"type": "sports_field", "name": "Sports Field (fun)", "icon": "res://assets/textury/builder/sports_field.png"},
			{"type": "lake_slide", "name": "Lake Slide (fun, a quick wash)", "icon": "res://assets/textury/builder/lake_slide.png"},
		],
	},
	{
		"id": "utilities",
		"items": [
			{"type": "sewer", "name": "Sewage", "icon": "res://assets/textury/builder/sewer.PNG"},
		],
	},
]

const DIRECT_TOOLS: Array = [
	{"id": "path", "name": "Path", "icon": "res://assets/textury/builder/parking.PNG", "accent": "path", "emoji": "🛣️"},
	{"id": "lamp_post", "name": "Lamp", "icon": "res://assets/textury/builder/gen.PNG", "accent": "lamp", "emoji": "💡"},
	{"id": "demolish", "name": "Bulldoze", "icon": "res://assets/textury/builder/obchod.png", "accent": "danger", "emoji": "🚜"},
]

var _grid_manager
var _building_manager

var _map_panel: Control
var _money_label: Label
var _status_label: Label
var _status_sfx_player: AudioStreamPlayer
var _status_flash_tween: Tween
var _submenu_shell: Panel

var _group_rows: Dictionary = {}
var _group_buttons: Dictionary = {}
var _item_buttons: Dictionary = {}
var _direct_buttons: Dictionary = {}

var _active_group: String = ""
var _selected_tool: String = ""


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()
	_wire_event_bus()
	_refresh_money()


func setup(grid_mgr, building_mgr) -> void:
	_grid_manager = grid_mgr
	_building_manager = building_mgr
	if _map_panel != null and _map_panel.has_method("setup"):
		_map_panel.call("setup", _grid_manager, _building_manager)
	_refresh_money()


func focus_map() -> void:
	if _map_panel != null:
		_map_panel.call_deferred("grab_focus")


func set_day_mode(_is_day: bool) -> void:
	# Builder locking by day/night is handled by CRT shell.
	pass


func _build_ui() -> void:
	var root := Panel.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_stylebox_override("panel", _panel_style(C_BG, C_BORDER_DARK))
	add_child(root)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	root.add_child(outer)

	_build_toolbar(outer)
	_build_submenu_shell(outer)
	_build_map(outer)
	_build_status_bar(outer)

	_apply_highlights()


func _build_toolbar(parent: VBoxContainer) -> void:
	var toolbar := Panel.new()
	toolbar.custom_minimum_size = Vector2(0.0, TOOLBAR_HEIGHT)
	toolbar.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_BORDER))
	parent.add_child(toolbar)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	toolbar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	for group_data in GROUPS:
		var group_id = str(group_data.get("id", ""))
		if group_id.is_empty():
			continue
		var items: Array = group_data.get("items", [])
		var icon_path = ""
		if not items.is_empty():
			icon_path = str(items[0].get("icon", ""))
		var btn = _make_icon_button(icon_path, group_id.capitalize())
		btn.toggle_mode = true
		btn.pressed.connect(func() -> void:
			_on_group_button_pressed(group_id)
		)
		_group_buttons[group_id] = btn
		row.add_child(btn)

	var divider_a := VSeparator.new()
	divider_a.custom_minimum_size = Vector2(2, 0)
	row.add_child(divider_a)

	for direct in DIRECT_TOOLS:
		var tool_id = str(direct.get("id", ""))
		if tool_id.is_empty():
			continue
		var tool_name = str(direct.get("name", tool_id))
		var icon_path = str(direct.get("icon", ""))
		var emoji = str(direct.get("emoji", ""))
		var tool_btn = _make_icon_button(icon_path, tool_name, emoji)
		tool_btn.pressed.connect(func() -> void:
			_set_selected_tool(tool_id)
			_set_active_group("")
		)
		_direct_buttons[tool_id] = tool_btn
		row.add_child(tool_btn)

	var divider_b := VSeparator.new()
	divider_b.custom_minimum_size = Vector2(2, 0)
	row.add_child(divider_b)

	var zoom_out = _make_text_icon_button("-", "Zoom Out")
	zoom_out.pressed.connect(func() -> void:
		if _map_panel != null and _map_panel.has_method("apply_zoom_step"):
			_map_panel.call("apply_zoom_step", -1)
	)
	row.add_child(zoom_out)

	var zoom_in = _make_text_icon_button("+", "Zoom In")
	zoom_in.pressed.connect(func() -> void:
		if _map_panel != null and _map_panel.has_method("apply_zoom_step"):
			_map_panel.call("apply_zoom_step", 1)
	)
	row.add_child(zoom_in)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var money_panel := Panel.new()
	money_panel.custom_minimum_size = Vector2(144, 0)
	money_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.18, 0.10, 1.0), Color(0.26, 0.50, 0.26, 1.0)))
	row.add_child(money_panel)

	var money_margin := MarginContainer.new()
	money_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	money_margin.add_theme_constant_override("margin_left", 6)
	money_margin.add_theme_constant_override("margin_right", 6)
	money_panel.add_child(money_margin)

	_money_label = Label.new()
	_money_label.text = "$0"
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_money_label.add_theme_color_override("font_color", C_MONEY)
	_money_label.add_theme_font_size_override("font_size", 15)
	money_margin.add_child(_money_label)


func _build_submenu_shell(parent: VBoxContainer) -> void:
	_submenu_shell = Panel.new()
	_submenu_shell.custom_minimum_size = Vector2(0.0, SUBMENU_HEIGHT)
	_submenu_shell.add_theme_stylebox_override("panel", _panel_style(C_PANEL_ALT, C_BORDER_DARK))
	parent.add_child(_submenu_shell)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_submenu_shell.add_child(margin)

	var shell := Control.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(shell)

	for group_data in GROUPS:
		var group_id = str(group_data.get("id", ""))
		if group_id.is_empty():
			continue

		var row := HBoxContainer.new()
		row.visible = false
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.add_theme_constant_override("separation", 4)
		shell.add_child(row)
		_group_rows[group_id] = row

		var items: Array = group_data.get("items", [])
		for item_data in items:
			var tool_id = str(item_data.get("type", ""))
			if tool_id.is_empty():
				continue
			var tool_name = str(item_data.get("name", tool_id))
			var icon_path = str(item_data.get("icon", ""))
			var btn = _make_icon_button(icon_path, tool_name)
			btn.pressed.connect(func() -> void:
				_set_selected_tool(tool_id)
				_set_active_group(group_id)
			)
			_item_buttons[tool_id] = btn
			row.add_child(btn)

	_update_submenu_visibility()


func _build_map(parent: VBoxContainer) -> void:
	_map_panel = MAP_PANEL_SCRIPT.new()
	_map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_map_panel)

	if _map_panel.has_signal("tool_canceled"):
		_map_panel.connect("tool_canceled", Callable(self, "_on_map_tool_canceled"))
	if _map_panel.has_signal("submenu_close_requested"):
		_map_panel.connect("submenu_close_requested", Callable(self, "_on_map_submenu_close_requested"))
	if _map_panel.has_signal("status_changed"):
		_map_panel.connect("status_changed", Callable(self, "_on_map_status_changed"))


func _build_status_bar(parent: VBoxContainer) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0.0, STATUS_HEIGHT)
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL_ALT, C_BORDER_DARK))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	panel.add_child(margin)

	_status_label = Label.new()
	_status_label.text = "Ready"
	_status_label.add_theme_color_override("font_color", C_TEXT_DIM)
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_status_label)


func _wire_event_bus() -> void:
	var money_cb := Callable(self, "_on_money_changed")
	if EventBus.has_signal("money_changed") and not EventBus.money_changed.is_connected(money_cb):
		EventBus.money_changed.connect(money_cb)


func _on_group_button_pressed(group_id: String) -> void:
	if _active_group == group_id:
		_set_active_group("")
	else:
		_set_active_group(group_id)


func _set_active_group(group_id: String) -> void:
	_active_group = group_id
	_update_submenu_visibility()
	_apply_highlights()


func _set_selected_tool(tool_id: String) -> void:
	_selected_tool = tool_id
	if _map_panel != null and _map_panel.has_method("set_selected_building"):
		_map_panel.call("set_selected_building", tool_id)
		_map_panel.call_deferred("grab_focus")
	_apply_highlights()


func _update_submenu_visibility() -> void:
	for group_id in _group_rows.keys():
		var row = _group_rows[group_id] as Control
		if row == null:
			continue
		row.visible = (str(group_id) == _active_group)


func _apply_highlights() -> void:
	for group_id in _group_buttons.keys():
		var group_btn = _group_buttons[group_id] as Button
		if group_btn == null:
			continue
		var is_active = str(group_id) == _active_group
		group_btn.button_pressed = is_active
		_style_button(group_btn, is_active, C_BTN_ACTIVE)

	for tool_id in _item_buttons.keys():
		var item_btn = _item_buttons[tool_id] as Button
		if item_btn == null:
			continue
		_style_button(item_btn, str(tool_id) == _selected_tool, C_BTN_ACTIVE)

	for tool_id in _direct_buttons.keys():
		var direct_btn = _direct_buttons[tool_id] as Button
		if direct_btn == null:
			continue
		var accent = C_BTN_ACTIVE
		if str(tool_id) == "path":
			accent = C_BTN_PATH
		elif str(tool_id) == "lamp_post":
			accent = C_BTN_LAMP
		elif str(tool_id) == "demolish":
			accent = C_BTN_DANGER
		_style_button(direct_btn, str(tool_id) == _selected_tool, accent)


func _on_map_tool_canceled() -> void:
	_selected_tool = ""
	_apply_highlights()


func _on_map_submenu_close_requested() -> void:
	_set_active_group("")


func _on_map_status_changed(text: String, kind: int = 0) -> void:
	if _status_label == null:
		return
	_status_label.text = text

	var col := C_TEXT_DIM
	if kind == MAP_PANEL_SCRIPT.STATUS_GOOD:
		col = C_STATUS_GOOD
	elif kind == MAP_PANEL_SCRIPT.STATUS_DENY:
		col = C_STATUS_DENY
	_status_label.add_theme_color_override("font_color", col)

	if kind == MAP_PANEL_SCRIPT.STATUS_INFO:
		return

	# Flash back to the resting colour so a repeated identical message still reads
	# as a fresh event rather than a stuck label.
	_play_status_sfx(kind)
	if _status_flash_tween != null and _status_flash_tween.is_valid():
		_status_flash_tween.kill()
	_status_flash_tween = create_tween()
	_status_flash_tween.tween_property(_status_label, "modulate", Color(1.0, 1.0, 1.0, 0.35), STATUS_FLASH_SEC * 0.5)
	_status_flash_tween.tween_property(_status_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), STATUS_FLASH_SEC * 0.5)


func _play_status_sfx(kind: int) -> void:
	if _status_sfx_player == null:
		_status_sfx_player = AudioStreamPlayer.new()
		_status_sfx_player.name = "BuilderStatusSfx"
		_status_sfx_player.bus = "Master"
		if ResourceLoader.exists(SFX_UI_BLIP):
			_status_sfx_player.stream = load(SFX_UI_BLIP) as AudioStream
		add_child(_status_sfx_player)
	if _status_sfx_player.stream == null:
		return
	if kind == MAP_PANEL_SCRIPT.STATUS_DENY:
		_status_sfx_player.pitch_scale = 0.62
		_status_sfx_player.volume_db = -12.0
	else:
		_status_sfx_player.pitch_scale = 1.18
		_status_sfx_player.volume_db = -16.0
	_status_sfx_player.stop()
	_status_sfx_player.play()


func _on_money_changed(amount: int) -> void:
	if _money_label != null:
		_money_label.text = "$%s" % _format_money(amount)


func _refresh_money() -> void:
	var core = get_node_or_null("/root/CoreRoot")
	if core != null and core.has_method("get_money"):
		_on_money_changed(int(core.get_money()))


func _make_icon_button(icon_path: String, tooltip: String, emoji_text: String = "") -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = BTN_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = true
	btn.tooltip_text = tooltip
	if emoji_text.is_empty():
		btn.text = ""
		btn.icon = _load_texture(icon_path)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		btn.text = emoji_text
		btn.add_theme_font_size_override("font_size", 16)
	_style_button(btn, false, C_BTN_ACTIVE)
	return btn


func _make_text_icon_button(icon_text: String, tooltip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = BTN_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = tooltip
	btn.text = icon_text
	btn.add_theme_font_size_override("font_size", 16)
	_style_button(btn, false, C_BTN_ACTIVE)
	return btn


func _style_button(btn: Button, is_active: bool, active_color: Color) -> void:
	if btn == null:
		return
	var base_color = active_color if is_active else C_BTN
	var normal = _panel_style(base_color, C_BORDER)
	var hover = _panel_style(base_color.lightened(0.08), C_BORDER)
	var pressed = _panel_style(base_color.darkened(0.10), C_BORDER_DARK)
	normal.set_corner_radius_all(0)
	hover.set_corner_radius_all(0)
	pressed.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", _panel_style(base_color, C_BORDER))
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", C_TEXT)
	btn.add_theme_color_override("font_pressed_color", C_TEXT)


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	return style


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _format_money(amount: int) -> String:
	var is_negative = amount < 0
	var raw = str(abs(amount))
	var grouped = ""
	var counter = 0
	for idx in range(raw.length() - 1, -1, -1):
		if counter > 0 and counter % 3 == 0:
			grouped = "," + grouped
		grouped = raw[idx] + grouped
		counter += 1
	return ("-" if is_negative else "") + grouped
