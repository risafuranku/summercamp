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

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")
const LANG = preload("res://scripts/lang.gd")

var _scale: int = 3
var _built_for: Vector2 = Vector2.ZERO
var _built_lang := ""
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


func open(info: String) -> void:
	_info_text = info
	if _info != null:
		_info.text = info
	var coop: bool = Coop.has_partner() or Coop.is_host()
	# Built at bootstrap, before a warden (and so the language) was chosen: Czech rows
	# are taller.
	if coop != _built_coop or LANG.current != _built_lang:
		_built_coop = coop
		_rebuild()
	visible = true
	_show("main")
	_list.select_id("resume")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	HandCursor.menu_over = true
	# main pauses the tree for this unless a co-op camp goes on (main._open_pause_menu).
	if Coop.is_active():
		_mute_others(true)


func close() -> void:
	visible = false
	HandCursor.menu_over = false
	_mute_others(false)


## [node, which callbacks] whose input is off while the menu is up in a co-op camp.
var _muted: Array = []


## Co-op: Esc pauses nothing (the other warden plays on), so the room, the close-up or the
## station under the menu went on reading the clicks and keys meant for the menu (playtest
## 1. 11.: "in a building the settings do not work, I click the room's things"). While it
## is up every other node's input is off, as a paused tree's would be; on closing, back as
## it was. The walkie-talkie (Coop's voice) stays on.
func _mute_others(on: bool) -> void:
	if not on:
		for e in _muted:
			var n: Node = e[0]
			if not is_instance_valid(n):
				continue
			var f: int = e[1]
			if f & 1:
				n.set_process_input(true)
			if f & 2:
				n.set_process_unhandled_input(true)
			if f & 4:
				n.set_process_unhandled_key_input(true)
			if f & 8:
				n.set_process_shortcut_input(true)
		_muted.clear()
		return
	if not _muted.is_empty():
		return
	var coop := get_node_or_null("/root/Coop")
	for n in get_tree().root.find_children("*", "", true, false):
		if n == self or is_ancestor_of(n) or (coop != null and (n == coop or coop.is_ancestor_of(n))):
			continue
		var f := 0
		if n.is_processing_input():
			f |= 1
			n.set_process_input(false)
		if n.is_processing_unhandled_input():
			f |= 2
			n.set_process_unhandled_input(false)
		if n.is_processing_unhandled_key_input():
			f |= 4
			n.set_process_unhandled_key_input(false)
		if n.is_processing_shortcut_input():
			f |= 8
			n.set_process_shortcut_input(false)
		if f != 0:
			_muted.append([n, f])


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
	_built_lang = LANG.current
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
	items.append_array([
		{"id": "save", "text": "Save game"},
		{"id": "options", "text": "Configuration"},
		{"id": "quit", "text": "Quit to title"},
	] as Array[Dictionary])
	_list.set_items(items)
	_list.activated.connect(_on_activated)
	var list_w: float = _list.content_width()
	var plate_w := maxf(_vp(200), list_w + _vp(28))
	# The rows as the list makes them: in Czech taller, for the capitals' accents
	# (playtest 1. 11.: the last row hung out of the plate, the first one's accent sat on
	# the info line).
	var row_vp: float = _list._row_vp()
	var rows_h := float(items.size()) * row_vp
	var accent_vp := row_vp - float(_list.row_height_vp)
	_plate = _centered_plate(Vector2(plate_w, _vp(60.0 + accent_vp + rows_h)))
	var title := RETRO_UI.PixelTitle.new()
	title.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	title.set_colors(RETRO_UI.C_AMBER_LIGHT, RETRO_UI.C_AMBER)
	# In a co-op camp nothing stops while this is up.
	title.set_text("MENU" if _built_coop else "PAUSED")
	title.size = title.custom_minimum_size
	title.position = Vector2(floorf((_plate.size.x - title.size.x) * 0.5 / _scale) * _scale, _vp(6))
	_plate.add_child(title)
	_info = RETRO_UI.label(_info_text, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	# main sends it translated piece by piece (main._pause_info_line).
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.anchor_right = 1.0
	_info.offset_top = _vp(32)
	_info.offset_bottom = _vp(42)
	_plate.add_child(_info)
	_list.position = Vector2(floorf((plate_w - list_w) * 0.5 / _scale) * _scale - _vp(4), _vp(46.0 + accent_vp))
	_list.size = Vector2(list_w + _vp(8), _vp(rows_h))
	_plate.add_child(_list)
	# Again, now that the list has its width: the rows were made 0 wide (measured before
	# it was sized, outside the tree, so no resize reached them) and took no clicks.
	_list.set_items(items)

	# In Czech the pages' titles and rows go down a little: the title's capital accents
	# (NASTAVENÍ) stood over the plate's top edge (an accent and its outline reach ten of
	# the big title's pixels above its capitals).
	var drop := 0.0 if LANG.current == "en" else 8.0
	_options_plate = _centered_plate(Vector2(_vp(250), _vp(186 + drop)))
	_add_plate_title(_options_plate, "CONFIGURATION", drop)
	_options = RETRO_MENU.OptionsPage.new()
	_options.ui_scale = _scale
	_options.position = Vector2(_vp(4), _vp(28 + drop))
	_options.size = Vector2(_options_plate.size.x - _vp(8), _vp(150))
	_options_plate.add_child(_options)
	_options.build()
	_fit_plate(_options_plate, _options)
	_options.back_requested.connect(func() -> void: _show("main"))
	_options.controls_requested.connect(func() -> void: _show("controls"))
	_options.credits_requested.connect(func() -> void: _show("credits"))

	_controls_plate = _centered_plate(Vector2(_vp(250), _vp(186 + drop)))
	_add_plate_title(_controls_plate, "CONTROLS", drop)
	_controls = RETRO_MENU.ControlsPage.new()
	_controls.ui_scale = _scale
	_controls.position = Vector2(_vp(4), _vp(28 + drop))
	_controls.size = Vector2(_controls_plate.size.x - _vp(8), _vp(150))
	_controls_plate.add_child(_controls)
	_controls.build()
	_controls.back_requested.connect(func() -> void: _show("options"))

	_credits_plate = _centered_plate(Vector2(_vp(250), _vp(186 + drop)))
	_add_plate_title(_credits_plate, "CREDITS", drop)
	_credits = RETRO_MENU.CreditsPage.new()
	_credits.ui_scale = _scale
	_credits.position = Vector2(_vp(4), _vp(28 + drop))
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


## A page's plate as tall as its rows (the options' last row hung out of the plate).
func _fit_plate(plate: Control, page: Control) -> void:
	plate.size.y = maxf(_vp(186), page.position.y + page.custom_minimum_size.y + _vp(8))
	page.size.y = maxf(page.size.y, page.custom_minimum_size.y)
	plate.position = ((_built_for - plate.size) * 0.5 / float(_scale)).floor() * float(_scale)


func _add_plate_title(plate: Control, text: String, drop := 0.0) -> void:
	var t := RETRO_UI.PixelTitle.new()
	t.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	t.set_colors(RETRO_UI.C_AMBER_LIGHT, RETRO_UI.C_AMBER)
	t.set_text(text)
	t.position = Vector2(_vp(6), _vp(4.0 + drop))
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
