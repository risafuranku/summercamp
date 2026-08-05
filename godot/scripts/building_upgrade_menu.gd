extends CanvasLayer

signal upgrade_confirmed
signal menu_closed

var _active: bool = false
var _root: Control
var _panel: Panel
var _title: Label
var _desc: Label
var _cost: Label
var _confirm_btn: Button
var _cancel_btn: Button


func _ready() -> void:
	layer = 96
	visible = false
	_build_ui()


func is_open() -> bool:
	return _active


func open_menu(title_text: String, desc_text: String, cost_text: String, enabled: bool) -> void:
	_active = true
	visible = true
	if _title != null:
		_title.text = title_text
	if _desc != null:
		_desc.text = desc_text
	if _cost != null:
		_cost.text = cost_text
	if _confirm_btn != null:
		_confirm_btn.disabled = not enabled


func close_menu() -> void:
	if not _active:
		return
	_active = false
	visible = false
	menu_closed.emit()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -240.0
	_panel.offset_top = -120.0
	_panel.offset_right = 240.0
	_panel.offset_bottom = 120.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.75, 0.75, 0.75)
	style.border_color = Color(0.35, 0.35, 0.40)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(14.0, 14.0)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.10, 0.10, 0.12))
	_panel.add_child(_title)

	_desc = Label.new()
	_desc.position = Vector2(14.0, 52.0)
	_desc.size = Vector2(452.0, 86.0)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 16)
	_desc.add_theme_color_override("font_color", Color(0.16, 0.18, 0.22))
	_panel.add_child(_desc)

	_cost = Label.new()
	_cost.position = Vector2(14.0, 142.0)
	_cost.add_theme_font_size_override("font_size", 18)
	_cost.add_theme_color_override("font_color", Color(0.06, 0.46, 0.12))
	_panel.add_child(_cost)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Potvrdit"
	_confirm_btn.position = Vector2(240.0, 180.0)
	_confirm_btn.size = Vector2(106.0, 30.0)
	_confirm_btn.pressed.connect(func():
		upgrade_confirmed.emit()
	)
	_panel.add_child(_confirm_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Zavrit"
	_cancel_btn.position = Vector2(356.0, 180.0)
	_cancel_btn.size = Vector2(106.0, 30.0)
	_cancel_btn.pressed.connect(close_menu)
	_panel.add_child(_cancel_btn)
