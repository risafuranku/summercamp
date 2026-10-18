extends CanvasLayer

## The upgrade offer of a lodging (the catalog on the tent's, cabin's or caravan's table):
##
##   TENT: UPGRADE
##   Upgrade Tent Lv1 -> Tent Lv2 (better comfort + capacity).
##   COST $120                       [UPGRADE] [CLOSE]
##   S / RIGHT CLICK  CLOSE
##
## The room that asked for it gets no input while it is up (its clicks and its way out
## are read in `_input`, before any button, so Close never got the click and S left the
## room with this still on screen and the mouse captured), and it shuts itself the
## moment that room is gone. Esc stays the pause menu's.

signal upgrade_confirmed
signal menu_closed

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")

var _active: bool = false
var _scale: int = 3
var _built_for: Vector2 = Vector2.ZERO
var _root: Control
var _confirm_btn: Button
var _room: Node = null
var _title_text: String = ""
var _desc_text: String = ""
var _cost_text: String = ""
var _enabled: bool = false


func _ready() -> void:
	layer = 96
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)


func is_open() -> bool:
	return _active


## `room`: the interior that asked; it is muted while this is up and closing it closes this.
func open_menu(title_text: String, desc_text: String, cost_text: String, enabled: bool, room: Node = null) -> void:
	_title_text = title_text
	_desc_text = desc_text
	_cost_text = cost_text
	_enabled = enabled
	_unmute_room()
	_room = room
	if _room != null:
		_room.set_process_input(false)
	_active = true
	visible = true
	_rebuild()


func close_menu() -> void:
	if not _active:
		return
	_active = false
	visible = false
	_unmute_room()
	menu_closed.emit()


func _unmute_room() -> void:
	if _room != null and is_instance_valid(_room):
		_room.set_process_input(true)
	_room = null


func _process(_delta: float) -> void:
	if not _active:
		return
	if _room != null and (not is_instance_valid(_room) or not (_room.has_method("is_open") and _room.is_open())):
		close_menu()
		return
	if get_viewport().get_visible_rect().size != _built_for:
		_rebuild()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	var leave := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		leave = true
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_S:
		leave = true
	if leave:
		close_menu()
		get_viewport().set_input_as_handled()


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
	shade.color = Color(0.02, 0.015, 0.01, 0.5)
	_root.add_child(shade)

	var plate_size := Vector2(_vp(230), _vp(104))
	var plate := RETRO_UI.BevelPanel.new()
	plate.ui_scale = _scale
	plate.fill = Color(0.06, 0.05, 0.04, 0.95)
	plate.light = RETRO_UI.C_PANEL_LIGHT
	plate.dark = Color(0.0, 0.0, 0.0, 1.0)
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.size = plate_size
	plate.position = ((vp - plate_size) * 0.5 / float(_scale)).floor() * float(_scale)
	_root.add_child(plate)

	var title := RETRO_UI.PixelTitle.new()
	title.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	title.set_colors(RETRO_UI.C_AMBER_LIGHT, RETRO_UI.C_AMBER)
	title.set_text(_title_text.to_upper())
	title.position = Vector2(_vp(6), _vp(4))
	title.size = title.custom_minimum_size
	plate.add_child(title)

	var desc := RETRO_UI.label(_desc_text, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE, _scale)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(_vp(8), _vp(30))
	desc.size = Vector2(plate_size.x - _vp(16), _vp(30))
	plate.add_child(desc)

	var priced := _cost_text.begins_with("$")
	var cost_line := ("COST " + _cost_text) if priced else _cost_text
	var cost_col := RETRO_UI.C_GREEN if _enabled else (RETRO_UI.C_RED_LIGHT if priced else RETRO_UI.C_BONE_DIM)
	var cost := RETRO_UI.label(cost_line, RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG, cost_col, _scale)
	cost.position = Vector2(_vp(8), _vp(64))
	plate.add_child(cost)
	if priced and not _enabled:
		var short := RETRO_UI.label("NOT ENOUGH MONEY", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_RED_LIGHT, _scale)
		short.position = Vector2(_vp(8), _vp(78))
		plate.add_child(short)

	_confirm_btn = _button("UPGRADE", Vector2(plate_size.x - _vp(124), _vp(64)))
	_confirm_btn.disabled = not _enabled
	_confirm_btn.pressed.connect(func() -> void: upgrade_confirmed.emit())
	plate.add_child(_confirm_btn)
	var close_btn := _button("CLOSE", Vector2(plate_size.x - _vp(62), _vp(64)))
	close_btn.pressed.connect(close_menu)
	plate.add_child(close_btn)

	var hint := RETRO_UI.label("S / RIGHT CLICK  CLOSE", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(_vp(8), _vp(90))
	hint.size = Vector2(plate_size.x - _vp(16), _vp(10))
	plate.add_child(hint)


func _button(text: String, at: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	RETRO_UI.style_button(b, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, _scale)
	b.position = at
	b.size = Vector2(_vp(56), _vp(18))
	return b
