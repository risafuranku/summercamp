extends CanvasLayer

## Death or blackout. Red dither over the frozen frame, the cause in big letters, a
## one-line account of the run and two ways out.

signal load_last_requested
signal main_menu_requested

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")

var _scale: int = 3
var _title_text: String = "YOU DIED"
var _reason_text: String = ""
var _stats_text: String = ""
var _has_save: bool = true
var _root: Control
var _list
var _built_for: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _init() -> void:
	name = "GameOverScreen"
	layer = 220
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(title: String, reason: String, stats: String, has_save: bool) -> void:
	_title_text = title
	_reason_text = reason
	_stats_text = stats
	_has_save = has_save


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_rebuild()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _vp(v: float) -> float:
	return v * float(_scale)


func _rebuild() -> void:
	var vp := get_viewport().get_visible_rect().size
	_built_for = vp
	_scale = RETRO_UI.ui_scale(vp.y, vp.x, 400.0)
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	var shade = RETRO_MENU.DitherShade.new()
	shade.ui_scale = _scale
	shade.mode = "full"
	shade.color = Color(0.20, 0.0, 0.0, 0.62)
	_root.add_child(shade)
	var frame = RETRO_MENU.DitherShade.new()
	frame.ui_scale = _scale
	frame.mode = "frame"
	frame.band = 0.16
	frame.color = Color(0.0, 0.0, 0.0, 0.9)
	_root.add_child(frame)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(_vp(4)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -_vp(40)
	_root.add_child(box)
	var title := RETRO_UI.PixelTitle.new()
	title.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 3, _scale)
	title.set_colors(Color(1.0, 0.46, 0.36), Color(0.72, 0.06, 0.04))
	title.set_text(_title_text)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(title)
	var reason := RETRO_UI.label(_reason_text, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE, _scale)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reason)
	var stats := RETRO_UI.label(_stats_text.to_upper(), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)

	_list = RETRO_MENU.MenuList.new()
	_list.ui_scale = _scale
	_list.row_height_vp = 22
	var items: Array[Dictionary] = [
		{"id": "load", "text": "Load last save", "enabled": _has_save},
		{"id": "menu", "text": "Main menu"},
	]
	_list.set_items(items)
	var list_w: float = _list.content_width()
	_list.size = Vector2(list_w + _vp(8), _vp(44))
	_list.position = Vector2(floorf((vp.x - list_w) * 0.5 / _scale) * _scale - _vp(4), vp.y - _vp(70))
	_root.add_child(_list)
	_list.activated.connect(func(id: String) -> void:
		if id == "load":
			load_last_requested.emit()
		else:
			main_menu_requested.emit()
	)
	# Swallow input for a moment so a held key from the death doesn't pick an option.
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if get_viewport().get_visible_rect().size != _built_for:
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if _list == null or _t < 0.8:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if _list.handle_input(event):
		get_viewport().set_input_as_handled()
