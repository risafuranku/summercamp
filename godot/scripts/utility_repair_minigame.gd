extends CanvasLayer

signal repair_completed(coord: Vector2i, building_type: String)
signal repair_cancelled

var _active: bool = false
var _coord: Vector2i = Vector2i.ZERO
var _building_type: String = ""
var _progress: float = 0.0
var _decay_per_second: float = 0.18
var _pulse_gain: float = 0.16

var _root: Control
var _panel: Panel
var _title_label: Label
var _target_label: Label
var _hint_label: Label
var _progress_bar: ColorRect
var _progress_fill: ColorRect
var _progress_text: Label


func _ready() -> void:
	layer = 95
	visible = false
	set_process(true)
	_build_ui()


func is_open() -> bool:
	return _active


func open_repair(coord: Vector2i, building_type: String, label_text: String) -> void:
	_active = true
	visible = true
	_coord = coord
	_building_type = building_type
	_progress = 0.0
	if _target_label != null:
		_target_label.text = "%s [%d,%d]" % [label_text, coord.x, coord.y]
	_update_progress_ui()


func close_repair(cancelled: bool = true) -> void:
	_active = false
	visible = false
	if cancelled:
		repair_cancelled.emit()


func _process(delta: float) -> void:
	if not _active:
		return
	_progress = max(0.0, _progress - (_decay_per_second * max(delta, 0.0)))
	_update_progress_ui()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		close_repair(true)
		get_viewport().set_input_as_handled()
		return
	var pressed = false
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		var key = event as InputEventKey
		pressed = key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER)
	if pressed:
		_progress = min(1.0, _progress + _pulse_gain)
		_update_progress_ui()
		if _progress >= 1.0:
			_active = false
			visible = false
			repair_completed.emit(_coord, _building_type)
		get_viewport().set_input_as_handled()


func _update_progress_ui() -> void:
	if _progress_fill != null:
		_progress_fill.size.x = (_progress_bar.size.x - 6.0) * clamp(_progress, 0.0, 1.0)
	if _progress_text != null:
		_progress_text.text = "%d%%" % int(round(_progress * 100.0))


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = Panel.new()
	_panel.size = Vector2(520.0, 220.0)
	_panel.position = Vector2(120.0, 90.0)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -260.0
	_panel.offset_top = -110.0
	_panel.offset_right = 260.0
	_panel.offset_bottom = 110.0
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.74, 0.74, 0.74, 1.0)
	panel_style.border_color = Color(0.32, 0.32, 0.36, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	_title_label = Label.new()
	_title_label.text = "MINIHRA OPRAVY UTILIT"
	_title_label.position = Vector2(16.0, 14.0)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14))
	_panel.add_child(_title_label)

	_target_label = Label.new()
	_target_label.text = "..."
	_target_label.position = Vector2(16.0, 52.0)
	_target_label.add_theme_font_size_override("font_size", 18)
	_target_label.add_theme_color_override("font_color", Color(0.18, 0.20, 0.26))
	_panel.add_child(_target_label)

	_hint_label = Label.new()
	_hint_label.text = "Mash LMB / SPACE pro opravu. ESC = zrusit."
	_hint_label.position = Vector2(16.0, 82.0)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(0.20, 0.22, 0.28))
	_panel.add_child(_hint_label)

	_progress_bar = ColorRect.new()
	_progress_bar.position = Vector2(16.0, 132.0)
	_progress_bar.size = Vector2(488.0, 32.0)
	_progress_bar.color = Color(0.16, 0.16, 0.18)
	_panel.add_child(_progress_bar)

	_progress_fill = ColorRect.new()
	_progress_fill.position = Vector2(3.0, 3.0)
	_progress_fill.size = Vector2(0.0, 26.0)
	_progress_fill.color = Color(0.34, 0.72, 0.38)
	_progress_bar.add_child(_progress_fill)

	_progress_text = Label.new()
	_progress_text.position = Vector2(16.0, 172.0)
	_progress_text.text = "0%"
	_progress_text.add_theme_font_size_override("font_size", 18)
	_progress_text.add_theme_color_override("font_color", Color(0.08, 0.12, 0.08))
	_panel.add_child(_progress_text)
