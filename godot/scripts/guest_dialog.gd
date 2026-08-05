extends CanvasLayer

signal dialog_closed

var _active: bool = false
var _root: Control
var _panel: Panel
var _title_label: Label
var _body_label: Label
var _close_btn: Button


func _ready() -> void:
	layer = 97
	visible = false
	_build_ui()


func is_open() -> bool:
	return _active


func open_dialog(title_text: String, body_text: String) -> void:
	_active = true
	visible = true
	if _title_label != null:
		_title_label.text = title_text
	if _body_label != null:
		_body_label.text = body_text
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_dialog() -> void:
	if not _active:
		return
	_active = false
	visible = false
	dialog_closed.emit()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.50)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -230.0
	_panel.offset_top = -120.0
	_panel.offset_right = 230.0
	_panel.offset_bottom = 120.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.74, 0.74, 0.74, 1.0)
	style.border_color = Color(0.34, 0.34, 0.38)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	_title_label = Label.new()
	_title_label.position = Vector2(14.0, 14.0)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.15))
	_panel.add_child(_title_label)

	_body_label = Label.new()
	_body_label.position = Vector2(14.0, 56.0)
	_body_label.size = Vector2(430.0, 118.0)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", Color(0.16, 0.17, 0.20))
	_panel.add_child(_body_label)

	_close_btn = Button.new()
	_close_btn.text = "Konec dialogu"
	_close_btn.position = Vector2(290.0, 188.0)
	_close_btn.size = Vector2(150.0, 30.0)
	_close_btn.pressed.connect(close_dialog)
	_panel.add_child(_close_btn)
