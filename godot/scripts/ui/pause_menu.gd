extends CanvasLayer

## Esc during first-person play. The game has no other way to save on demand, reach
## the configuration, or leave to the title screen, so this is the in-game hub:
##
##            PAUSED
##   DAY 3  21:40   LAST SAVE 2 MIN AGO
##   > RESUME
##     SAVE GAME
##     CONFIGURATION
##     QUIT TO TITLE
##
## main.gd pauses the SceneTree while this is open; the layer keeps processing.
## Quitting to the title autosaves first, so no confirmation is needed.

signal resume_requested
signal save_requested
signal quit_to_title_requested
## The way out of a room, a close-up or a job (main: _on_pause_leave_requested).
signal leave_requested

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")

var _scale: int = 3
var _built_for: Vector2 = Vector2.ZERO
var _page: String = "main"
var _root: Control
var _plate: Control
var _list
var _info: Label
var _options_plate: Control
var _options
var _controls_plate: Control
var _credits_plate: Control
var _credits
var _controls
var _info_text: String = ""
## "Go outside" and the like when there is somewhere to leave; "" outdoors.
var _leave_text: String = ""


func _init() -> void:
	name = "PauseMenu"
	# Over every room, close-up and job (the check-in desk is 140, the pipes 128): it was
	# opening behind the desk, unseen.
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_rebuild()


var _built_coop := false


func open(info: String, leave_text := "") -> void:
	_info_text = info
	if _info != null:
		_info.text = info
	var coop: bool = Coop.has_partner() or Coop.is_host()
	if leave_text != _leave_text or coop != _built_coop:
		_leave_text = leave_text
		_built_coop = coop
		_rebuild()
	visible = true
	_show("main")
	_list.select_id("resume")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


## Shown after a save so the player sees it happened.
func set_info(info: String) -> void:
	_info_text = info
	if _info != null:
		_info.text = info


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
	shade.color = Color(0.02, 0.015, 0.01, 0.62)
	_root.add_child(shade)

	_list = RETRO_MENU.MenuList.new()
	_list.ui_scale = _scale
	_list.row_height_vp = 24
	var items: Array[Dictionary] = [{"id": "resume", "text": "Resume"}]
	if _leave_text != "":
		items.append({"id": "leave", "text": _leave_text})
	items.append_array([
		{"id": "save", "text": "Save game"},
		{"id": "options", "text": "Configuration"},
		{"id": "quit", "text": "Quit to title"},
	] as Array[Dictionary])
	_list.set_items(items)
	_list.activated.connect(_on_activated)
	var list_w: float = _list.content_width()
	var plate_w := maxf(_vp(200), list_w + _vp(28))
	var rows_h := float(items.size() * 24)
	_plate = _centered_plate(Vector2(plate_w, _vp(60.0 + rows_h)))
	var title := RETRO_UI.PixelTitle.new()
	title.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	title.set_colors(RETRO_UI.C_AMBER_LIGHT, RETRO_UI.C_AMBER)
	# In a co-op camp nothing stops while this is up.
	title.set_text("MENU" if _built_coop else "PAUSED")
	title.size = title.custom_minimum_size
	title.position = Vector2(floorf((_plate.size.x - title.size.x) * 0.5 / _scale) * _scale, _vp(6))
	_plate.add_child(title)
	_info = RETRO_UI.label(_info_text, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.anchor_right = 1.0
	_info.offset_top = _vp(32)
	_info.offset_bottom = _vp(42)
	_plate.add_child(_info)
	_list.position = Vector2(floorf((plate_w - list_w) * 0.5 / _scale) * _scale - _vp(4), _vp(46))
	_list.size = Vector2(list_w + _vp(8), _vp(rows_h))
	_plate.add_child(_list)
	# Again, now that the list has its width: the rows were made 0 wide (measured before
	# it was sized, outside the tree, so no resize reached them) and took no clicks.
	_list.set_items(items)

	_options_plate = _centered_plate(Vector2(_vp(250), _vp(186)))
	_add_plate_title(_options_plate, "CONFIGURATION")
	_options = RETRO_MENU.OptionsPage.new()
	_options.ui_scale = _scale
	_options.position = Vector2(_vp(4), _vp(28))
	_options.size = Vector2(_options_plate.size.x - _vp(8), _vp(150))
	_options_plate.add_child(_options)
	_options.build()
	_options.back_requested.connect(func() -> void: _show("main"))
	_options.controls_requested.connect(func() -> void: _show("controls"))
	_options.credits_requested.connect(func() -> void: _show("credits"))

	_controls_plate = _centered_plate(Vector2(_vp(250), _vp(186)))
	_add_plate_title(_controls_plate, "CONTROLS")
	_controls = RETRO_MENU.ControlsPage.new()
	_controls.ui_scale = _scale
	_controls.position = Vector2(_vp(4), _vp(28))
	_controls.size = Vector2(_controls_plate.size.x - _vp(8), _vp(150))
	_controls_plate.add_child(_controls)
	_controls.build()
	_controls.back_requested.connect(func() -> void: _show("options"))

	_credits_plate = _centered_plate(Vector2(_vp(250), _vp(186)))
	_add_plate_title(_credits_plate, "CREDITS")
	_credits = RETRO_MENU.CreditsPage.new()
	_credits.ui_scale = _scale
	_credits.position = Vector2(_vp(4), _vp(28))
	_credits.size = Vector2(_credits_plate.size.x - _vp(8), _vp(150))
	_credits_plate.add_child(_credits)
	_credits.build()
	_credits.back_requested.connect(func() -> void: _show("options"))
	_show(_page)


func _centered_plate(plate_size: Vector2) -> Control:
	var plate := RETRO_UI.BevelPanel.new()
	plate.ui_scale = _scale
	plate.fill = Color(0.06, 0.05, 0.04, 0.95)
	plate.light = RETRO_UI.C_PANEL_LIGHT
	plate.dark = Color(0.0, 0.0, 0.0, 1.0)
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.size = plate_size
	plate.position = ((_built_for - plate_size) * 0.5 / float(_scale)).floor() * float(_scale)
	_root.add_child(plate)
	return plate


func _add_plate_title(plate: Control, text: String) -> void:
	var t := RETRO_UI.PixelTitle.new()
	t.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	t.set_colors(RETRO_UI.C_AMBER_LIGHT, RETRO_UI.C_AMBER)
	t.set_text(text)
	t.position = Vector2(_vp(6), _vp(4))
	t.size = t.custom_minimum_size
	plate.add_child(t)


func _show(page: String) -> void:
	_page = page
	if _plate == null:
		return
	_plate.visible = page == "main"
	_options_plate.visible = page == "options"
	_controls_plate.visible = page == "controls"
	if _credits_plate != null:
		_credits_plate.visible = page == "credits"
	if page == "options":
		_options.refresh()


func _on_activated(id: String) -> void:
	match id:
		"resume":
			resume_requested.emit()
		"leave":
			leave_requested.emit()
		"save":
			save_requested.emit()
		"options":
			_show("options")
		"quit":
			quit_to_title_requested.emit()


func _process(_delta: float) -> void:
	if visible and get_viewport().get_visible_rect().size != _built_for:
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var used := false
	match _page:
		"main":
			if event.is_action_pressed("ui_cancel"):
				resume_requested.emit()
				used = true
			else:
				used = _list.handle_input(event)
		"options":
			used = _options.handle_input(event)
		"controls":
			used = _controls.handle_input(event)
		"credits":
			used = _credits.handle_input(event)
	if used:
		get_viewport().set_input_as_handled()
