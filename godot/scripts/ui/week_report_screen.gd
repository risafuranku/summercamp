extends CanvasLayer

## Day 31, 08:00: the district's inspection, Vera out on the first bus for it, the books
## (scripts/week_ledger.gd). Dark amber dither over the frozen frame, the ledger rows, her
## verdict and the count at breakfast.
## Two ways on: stay on (the camp runs on without an end) or the main menu. A poor month has
## one: the district sells, your bus is at ten, and that is the end of the run. The door, the
## engine pulling off, the black, the title.

signal stay_requested
signal main_menu_requested

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")

## The two ways on, a row each (px of the 240-line screen).
const LIST_ROW := 16
const BUS_SFX := "res://assets/sfx/bus/"
## The last bus: the door, then the engine, over this long a black.
const LEAVE_SEC := 2.6

var _scale: int = 3
var _report: Dictionary = {}
var _root: Control
var _list
var _built_for: Vector2 = Vector2.ZERO
var _t: float = 0.0
## Co-op: the warden who joined reads the books too; staying on is the host's to say.
var follower := false
var _leaving := false


func _init() -> void:
	name = "WeekReportScreen"
	layer = 215
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(report: Dictionary) -> void:
	_report = report


func report_data() -> Dictionary:
	return _report


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
	shade.color = Color(0.05, 0.035, 0.01, 0.86)
	_root.add_child(shade)

	# (All of it on a 240-line screen: the title went off the top, its accents with it, and the
	# two ways on lay over Vera's count at the bottom.)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(_vp(1)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = _vp(10)
	box.offset_right = -_vp(10)
	box.offset_top = _vp(4)
	box.offset_bottom = -_vp(LIST_ROW * 2 + 6)
	_root.add_child(box)

	var title := RETRO_UI.PixelTitle.new()
	title.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	title.set_colors(RETRO_UI.C_AMBER_LIGHT, RETRO_UI.C_AMBER_DIM)
	title.set_text("THE BOOKS")
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(title)
	var sub := RETRO_UI.label("%s, 08:00. THE INSPECTION." % Season.date_long(Season.RETURN_DAY).to_upper(), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_gap(3))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vp(8)))
	grid.add_theme_constant_override("v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row in _report.get("rows", []):
		var k := RETRO_UI.label(str(row[0]).to_upper(), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, _scale, false)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(k)
		var v := RETRO_UI.label(str(row[1]), RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE, _scale, false)
		v.custom_minimum_size.x = _vp(270)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(v)
	box.add_child(grid)
	box.add_child(_gap(3))

	var grade := str(_report.get("grade", "fair"))
	var verdict_color: Color = RETRO_UI.C_GREEN_LIGHT if grade == "good" else (RETRO_UI.C_RED_LIGHT if grade == "poor" else RETRO_UI.C_QUOTE)
	box.add_child(_paragraph(str(_report.get("verdict", "")), verdict_color))
	box.add_child(_gap(1))
	box.add_child(_paragraph(str(_report.get("coda", "")) + "  - V.", RETRO_UI.C_BONE_DIM))

	_list = RETRO_MENU.MenuList.new()
	_list.ui_scale = _scale
	_list.row_height_vp = LIST_ROW
	_list.size_vp = 12
	var items: Array[Dictionary] = []
	if grade == "poor":
		items.append({"id": "bus", "text": "To the bus"})
	else:
		if not follower:
			items.append({"id": "stay", "text": "Stay on"})
		items.append({"id": "menu", "text": "Main menu"})
	_list.set_items(items)
	var list_w: float = _list.content_width()
	_list.size = Vector2(list_w + _vp(8), _vp(LIST_ROW * items.size()))
	var list_y: float = vp.y - _vp(LIST_ROW * 2 + 3) + _vp(LIST_ROW * (2 - items.size())) * 0.5
	_list.position = Vector2(floorf((vp.x - list_w) * 0.5 / _scale) * _scale - _vp(4), list_y)
	_root.add_child(_list)
	_list.activated.connect(func(id: String) -> void:
		if id == "stay":
			stay_requested.emit()
		elif id == "bus":
			_take_the_bus()
		else:
			main_menu_requested.emit()
	)
	_t = 0.0


## The month was poor and the run is over: the bus's door behind you, the engine going off
## into the black, then the title.
func _take_the_bus() -> void:
	if _leaving:
		return
	_leaving = true
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(black)
	_sound("door_close.mp3", -6.0)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, LEAVE_SEC * 0.5)
	tw.tween_callback(func() -> void: _sound("depart.mp3", -8.0))
	tw.tween_interval(LEAVE_SEC * 0.5)
	tw.tween_callback(func() -> void: main_menu_requested.emit())


func _sound(file: String, db: float) -> void:
	if not ResourceLoader.exists(BUS_SFX + file):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(BUS_SFX + file)
	p.volume_db = db
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()


func _paragraph(text: String, color: Color) -> Label:
	var l := RETRO_UI.label(text, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, color, _scale, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = _vp(396)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = _vp(h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _process(delta: float) -> void:
	_t += delta
	if get_viewport().get_visible_rect().size != _built_for:
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	# A moment of grace so a key held from play does not pick an option.
	if _list == null or _t < 1.2 or _leaving:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if _list.handle_input(event):
		get_viewport().set_input_as_handled()
