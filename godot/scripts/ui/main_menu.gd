extends CanvasLayer

## Title screen over the live camp flythrough (the flythrough camera stays in main.gd).
##
##   CURSED CAMP                         (live camp, dithered dark on the left)
##   MANAGER SIMULATOR
##   One week minding aunt Vera's camp.
##
##   > CONTINUE      DAY 3  21:40  $1,234
##     NEW CAMP
##     LOAD CAMP
##     CONFIGURATION
##     QUIT TO DOS
##   [v0.3  (C) 1998 UNDO95 ............. ARROWS SELECT  ENTER OK  ESC BACK]
##
## Pages: main, load, options, controls. A loading plate covers everything while main
## builds the world. main.gd owns what the choices *do*; this script only reports them.

signal continue_requested
signal new_game_requested
signal load_requested(path: String)
signal quit_requested

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")

const TAGLINE := "One week minding aunt Vera's camp. What could go wrong."
const TIPS := [
	"Three archetypes roll for the night separately. A mixed camp is a safer camp.",
	"The builder locks at 20:00. Whatever you did not build by then, you will not have tonight.",
	"The electricity bill is issued at night and due three days later. The UPS lasts six minutes.",
	"Cheap Chicks pay the most and stay up the latest.",
	"Guests with no toilet use the bushes. They remember that in their review.",
	"Sweep your flashlight. Turn around. Whatever is out there hates being looked at.",
	"An unhappy guest counts double toward the night's spawn pressure.",
	"Read your mail. Aunt Vera does not repeat herself.",
]
const VISIBLE_SAVE_ROWS := 6

var _scale: int = 3
var _built_for: Vector2 = Vector2.ZERO
var _page: String = "main"
var _root: Control
var _shade
var _sub_shade
var _visible_rows: int = VISIBLE_SAVE_ROWS
var _column: Control
var _main_list
var _load_page: Control
var _save_rows_host: Control
var _save_rows: Array[Control] = []
var _save_entries: Array[Dictionary] = []
var _save_selected: int = 0
var _save_scroll: int = 0
var _save_delete_armed: bool = false
var _save_hint: Label
var _options_page: Control
var _options
var _controls_page: Control
var _controls
var _loading: Control
var _loading_label: Label
var _loading_tip: Label
var _loading_bar
var _loading_t: float = 0.0
var _has_continue: bool = false
var _continue_sub: String = ""


func _init() -> void:
	name = "MainMenu"
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_rebuild()


# ── public API ────────────────────────────────────────────────────────────────

func open() -> void:
	visible = true
	refresh_saves()
	show_page("main")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	visible = false
	hide_loading()


func show_page(page: String) -> void:
	_page = page
	_save_delete_armed = false
	if _main_list == null:
		return
	_main_list.get_parent().visible = page == "main"
	_column.visible = page == "main"
	_sub_shade.visible = page != "main"
	_load_page.visible = page == "load"
	_options_page.visible = page == "options"
	_controls_page.visible = page == "controls"
	if page == "load":
		refresh_saves()
	elif page == "options":
		_options.refresh()


## Re-reads the save folder: CONTINUE line, load list.
func refresh_saves() -> void:
	_save_entries = SaveManager.list_saves() if SaveManager != null else []
	_has_continue = not _save_entries.is_empty()
	_continue_sub = _summary(_save_entries[0]) if _has_continue else ""
	if _main_list != null:
		_main_list.set_items(_main_items())
		if _page == "main":
			_main_list.select_id("continue" if _has_continue else "new")
	_save_selected = clampi(_save_selected, 0, maxi(0, _save_entries.size() - 1))
	_save_scroll = clampi(_save_scroll, 0, maxi(0, _save_entries.size() - _visible_rows))
	_refresh_save_rows()


func show_loading(message: String) -> void:
	if _loading == null:
		return
	_loading_label.text = message
	_loading_tip.text = "TIP: %s" % TIPS[randi() % TIPS.size()]
	_loading_t = 0.0
	_loading.visible = true


func hide_loading() -> void:
	if _loading != null:
		_loading.visible = false


# ── build ─────────────────────────────────────────────────────────────────────

func _vp(v: float) -> float:
	return v * float(_scale)


func _rebuild() -> void:
	var vp := get_viewport().get_visible_rect().size
	_built_for = vp
	_scale = RETRO_UI.ui_scale(vp.y, vp.x, 400.0)
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()

	_shade = RETRO_MENU.DitherShade.new()
	_shade.ui_scale = _scale
	_shade.mode = "left"
	_shade.color = Color(0.03, 0.015, 0.01, 0.78)
	_shade.reach = clampf((_vp(16) + minf(_vp(250), vp.x * 0.62)) / vp.x, 0.4, 0.75)
	_shade.band = 0.10
	_root.add_child(_shade)
	# Sub-pages sit on a centred plate; the whole view dims behind them.
	_sub_shade = RETRO_MENU.DitherShade.new()
	_sub_shade.ui_scale = _scale
	_sub_shade.mode = "full"
	_sub_shade.color = Color(0.02, 0.012, 0.01, 0.6)
	_sub_shade.visible = false
	_root.add_child(_sub_shade)

	_column = Control.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.position = Vector2(_vp(16), _vp(14))
	_column.size = Vector2(minf(_vp(250), vp.x - _vp(32)), vp.y - _vp(14 + 20))
	_root.add_child(_column)

	var y := 0.0
	var logo := RETRO_UI.PixelTitle.new()
	logo.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 3, _scale)
	logo.set_colors(Color(1.0, 0.86, 0.46), Color(0.96, 0.46, 0.10))
	logo.set_text("CURSED CAMP")
	logo.position = Vector2(-_vp(3), y)
	logo.size = logo.custom_minimum_size
	_column.add_child(logo)
	y += logo.custom_minimum_size.y
	var sub := RETRO_UI.PixelTitle.new()
	sub.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG, _scale)
	sub.set_colors(Color(1.0, 0.52, 0.42), Color(0.78, 0.12, 0.08))
	sub.set_text("MANAGER SIMULATOR")
	sub.position = Vector2(_vp(0), y)
	sub.size = sub.custom_minimum_size
	_column.add_child(sub)
	y += sub.custom_minimum_size.y + _vp(2)
	var tag := RETRO_UI.label(TAGLINE, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE_DIM, _scale)
	tag.position = Vector2(_vp(1), y)
	_column.add_child(tag)
	y += _vp(18)

	var pages_top := y
	var pages_h := _column.size.y - pages_top
	var plate_h := minf(vp.y - _vp(13 + 12), _vp(206))
	var list_h := plate_h - _vp(26 + 16)
	_visible_rows = clampi(int(list_h / _vp(22)), 3, VISIBLE_SAVE_ROWS)

	# MAIN
	var main_page := Control.new()
	main_page.name = "MainPage"
	main_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_page.position = Vector2(0.0, pages_top)
	main_page.size = Vector2(_column.size.x, pages_h)
	_column.add_child(main_page)
	_main_list = RETRO_MENU.MenuList.new()
	_main_list.ui_scale = _scale
	_main_list.row_height_vp = 22
	_main_list.position = Vector2(-_vp(2), 0.0)
	_main_list.size = Vector2(vp.x * 0.6, pages_h)
	main_page.add_child(_main_list)
	_main_list.activated.connect(_on_main_activated)
	_main_list.set_items(_main_items())

	# LOAD
	_load_page = _page_frame("LOAD CAMP", plate_h)
	var inner_w := _load_page.size.x - _vp(8)
	_save_rows_host = Control.new()
	_save_rows_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_rows_host.position = Vector2(_vp(4), _vp(28))
	_save_rows_host.size = Vector2(inner_w, _vp(22 * _visible_rows))
	_load_page.add_child(_save_rows_host)
	_save_rows.clear()
	for i in _visible_rows:
		_save_rows.append(_make_save_row(i, inner_w))
	_save_hint = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	_save_hint.position = Vector2(_vp(8), plate_h - _vp(13))
	_load_page.add_child(_save_hint)

	# OPTIONS
	_options_page = _page_frame("CONFIGURATION", plate_h)
	_options = RETRO_MENU.OptionsPage.new()
	_options.ui_scale = _scale
	_options.position = Vector2(_vp(4), _vp(28))
	_options.size = Vector2(_options_page.size.x - _vp(8), _vp(150))
	_options_page.add_child(_options)
	_options.build()
	_options.back_requested.connect(func() -> void: show_page("main"))
	_options.controls_requested.connect(func() -> void: show_page("controls"))

	# CONTROLS
	_controls_page = _page_frame("CONTROLS", plate_h)
	_controls = RETRO_MENU.ControlsPage.new()
	_controls.ui_scale = _scale
	_controls.position = Vector2(_vp(4), _vp(28))
	_controls.size = Vector2(_controls_page.size.x - _vp(8), _vp(150))
	_controls_page.add_child(_controls)
	_controls.build()
	_controls.back_requested.connect(func() -> void: show_page("options"))

	_build_footer(vp)
	_build_loading(vp)
	show_page(_page)
	refresh_saves()


## A titled plate centred over the dimmed view (load, configuration, controls).
func _page_frame(title: String, plate_h: float) -> Control:
	var vp := _built_for
	var page := RETRO_UI.BevelPanel.new()
	page.ui_scale = _scale
	page.fill = Color(0.05, 0.04, 0.03, 0.95)
	page.light = RETRO_UI.C_PANEL_LIGHT
	page.dark = Color(0.0, 0.0, 0.0, 1.0)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.size = Vector2(minf(_vp(270), vp.x - _vp(16)), plate_h)
	var free_h := vp.y - _vp(13)
	page.position = (Vector2((vp.x - page.size.x) * 0.5, (free_h - plate_h) * 0.5) / float(_scale)).floor() * float(_scale)
	page.visible = false
	_root.add_child(page)
	var t := RETRO_UI.PixelTitle.new()
	t.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	t.set_colors(RETRO_UI.C_AMBER_LIGHT, RETRO_UI.C_AMBER)
	t.set_text(title)
	t.position = Vector2(_vp(6), _vp(4))
	t.size = t.custom_minimum_size
	page.add_child(t)
	return page


func _build_footer(vp: Vector2) -> void:
	var bar := RETRO_UI.BevelPanel.new()
	bar.ui_scale = _scale
	bar.tile_texture = RETRO_UI.texture(RETRO_UI.PLATE_TEXTURE_PATH)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -_vp(13)
	bar.offset_left = -_vp(1)
	bar.offset_right = _vp(1)
	_root.add_child(bar)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var left := RETRO_UI.label("V%s  (C) 1998 UNDO95" % version if not version.is_empty() else "(C) 1998 UNDO95", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	left.position = Vector2(_vp(6), 0.0)
	RETRO_UI.place_on_baseline(left, 9.0, _scale)
	left.offset_left = _vp(6)
	bar.add_child(left)
	var right := RETRO_UI.label("ARROWS SELECT   ENTER OK   ESC BACK", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.anchor_left = 0.0
	right.anchor_right = 1.0
	right.offset_right = -_vp(6)
	RETRO_UI.place_on_baseline(right, 9.0, _scale)
	bar.add_child(right)


func _build_loading(vp: Vector2) -> void:
	_loading = Control.new()
	_loading.name = "Loading"
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading.visible = false
	_root.add_child(_loading)
	var shade = RETRO_MENU.DitherShade.new()
	shade.ui_scale = _scale
	shade.mode = "full"
	shade.color = Color(0.02, 0.012, 0.01, 0.72)
	_loading.add_child(shade)
	var plate := RETRO_UI.BevelPanel.new()
	plate.ui_scale = _scale
	plate.fit_children = true
	plate.pad_vp = Vector4(8, 6, 8, 7)
	plate.fill = Color(0.06, 0.05, 0.04, 0.96)
	plate.light = RETRO_UI.C_PANEL_LIGHT
	plate.dark = Color(0.0, 0.0, 0.0, 1.0)
	plate.anchor_left = 0.5
	plate.anchor_right = 0.5
	plate.anchor_top = 0.5
	plate.anchor_bottom = 0.5
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading.add_child(plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_vp(4)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(box)
	var title := RETRO_UI.PixelTitle.new()
	title.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	title.set_colors(RETRO_UI.C_AMBER_LIGHT, RETRO_UI.C_AMBER)
	title.set_text("LOADING")
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(title)
	_loading_label = RETRO_UI.label("", RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE, _scale)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_loading_label)
	_loading_bar = RETRO_UI.SegmentBar.new()
	_loading_bar.ui_scale = _scale
	_loading_bar.segments = 20
	_loading_bar.color_full = RETRO_UI.C_AMBER
	_loading_bar.color_low = RETRO_UI.C_AMBER
	_loading_bar.custom_minimum_size = Vector2(_vp(180), _vp(5))
	box.add_child(_loading_bar)
	_loading_tip = RETRO_UI.label("", RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE_DIM, _scale)
	_loading_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loading_tip.custom_minimum_size = Vector2(_vp(180), 0.0)
	_loading_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_loading_tip)


func _main_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if _has_continue:
		items.append({"id": "continue", "text": "Continue", "sub": _continue_sub})
	items.append({"id": "new", "text": "New camp"})
	items.append({"id": "load", "text": "Load camp", "enabled": _has_continue})
	items.append({"id": "options", "text": "Configuration"})
	items.append({"id": "quit", "text": "Quit to DOS"})
	return items


func _make_save_row(i: int, width: float) -> Control:
	var row := RETRO_UI.BevelPanel.new()
	row.ui_scale = _scale
	row.fill = Color(0, 0, 0, 0)
	row.light = Color(0, 0, 0, 0)
	row.dark = Color(0, 0, 0, 0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.position = Vector2(0.0, _vp(22) * float(i))
	row.size = Vector2(width, _vp(21))
	_save_rows_host.add_child(row)
	var name_label := RETRO_UI.label("", RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE, _scale)
	name_label.name = "Name"
	name_label.position = Vector2(_vp(5), _vp(2))
	row.add_child(name_label)
	var info := RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	info.name = "Info"
	info.position = Vector2(_vp(5), _vp(11))
	row.add_child(info)
	row.mouse_entered.connect(func() -> void: _select_save(_save_scroll + i))
	row.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_select_save(_save_scroll + i)
			_load_selected()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_saves(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_saves(-1)
	)
	return row


func _refresh_save_rows() -> void:
	if _save_rows.is_empty():
		return
	for i in _save_rows.size():
		var row := _save_rows[i] as RETRO_UI.BevelPanel
		var idx := _save_scroll + i
		var has := idx < _save_entries.size()
		row.visible = has
		if not has:
			continue
		var entry: Dictionary = _save_entries[idx]
		var selected := idx == _save_selected
		row.fill = Color(0.24, 0.15, 0.07, 0.9) if selected else Color(0, 0, 0, 0)
		row.light = RETRO_UI.C_AMBER_DIM if selected else Color(0, 0, 0, 0)
		row.dark = Color(0.05, 0.03, 0.02, 1.0) if selected else Color(0, 0, 0, 0)
		row.queue_redraw()
		var n := row.get_node("Name") as Label
		var info := row.get_node("Info") as Label
		n.text = "%s%s" % ["> " if selected else "", str(entry.get("slot_name", "Save"))]
		n.add_theme_color_override("font_color", RETRO_UI.C_AMBER_LIGHT if selected else RETRO_UI.C_BONE)
		if selected and _save_delete_armed:
			info.text = "PRESS DEL AGAIN TO DELETE THIS SAVE"
			info.add_theme_color_override("font_color", RETRO_UI.C_RED_LIGHT)
		else:
			info.text = "%s   %s" % [_summary(entry), _ago(int(entry.get("updated_unix", 0)))]
			info.add_theme_color_override("font_color", RETRO_UI.C_AMBER_DIM if selected else RETRO_UI.C_BONE_DIM)
	if _save_hint != null:
		if _save_entries.is_empty():
			_save_hint.text = "NO SAVED CAMPS YET.   ESC BACK"
		else:
			var more := ""
			if _save_entries.size() > _visible_rows:
				more = "%d/%d   " % [_save_selected + 1, _save_entries.size()]
			_save_hint.text = "%sENTER LOAD   DEL DELETE   ESC BACK" % more


func _select_save(index: int) -> void:
	if _save_entries.is_empty():
		return
	var clamped := clampi(index, 0, _save_entries.size() - 1)
	if clamped != _save_selected:
		_save_delete_armed = false
	_save_selected = clamped
	if _save_selected < _save_scroll:
		_save_scroll = _save_selected
	elif _save_selected >= _save_scroll + _visible_rows:
		_save_scroll = _save_selected - _visible_rows + 1
	_refresh_save_rows()


func _scroll_saves(dir: int) -> void:
	_save_scroll = clampi(_save_scroll + dir, 0, maxi(0, _save_entries.size() - _visible_rows))
	_refresh_save_rows()


func _load_selected() -> void:
	if _save_selected < 0 or _save_selected >= _save_entries.size():
		return
	load_requested.emit(str(_save_entries[_save_selected].get("path", "")))


func _delete_selected() -> void:
	if _save_selected < 0 or _save_selected >= _save_entries.size():
		return
	if not _save_delete_armed:
		_save_delete_armed = true
		_refresh_save_rows()
		return
	_save_delete_armed = false
	SaveManager.delete_save(str(_save_entries[_save_selected].get("path", "")))
	refresh_saves()
	if _save_entries.is_empty():
		show_page("main")


# ── input ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp != _built_for:
		_rebuild()
	if _loading != null and _loading.visible and _loading_bar != null:
		# Indeterminate: the bar fills segment by segment, holds, and starts over.
		_loading_t += delta
		var segs: int = _loading_bar.segments
		var head := int(_loading_t * 18.0) % (segs + 6)
		_loading_bar.set_value(clampf(float(head) / float(segs), 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (_loading != null and _loading.visible):
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var used := false
	match _page:
		"main":
			used = _main_list.handle_input(event)
		"load":
			used = _handle_load_input(event)
		"options":
			used = _options.handle_input(event)
		"controls":
			used = _controls.handle_input(event)
	if used:
		get_viewport().set_input_as_handled()


func _handle_load_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		if _save_delete_armed:
			_save_delete_armed = false
			_refresh_save_rows()
		else:
			show_page("main")
		return true
	if event.is_action_pressed("ui_down", true):
		_select_save(_save_selected + 1)
		return true
	if event.is_action_pressed("ui_up", true):
		_select_save(_save_selected - 1)
		return true
	if event.is_action_pressed("ui_accept"):
		_load_selected()
		return true
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_DELETE or key.keycode == KEY_X):
		_delete_selected()
		return true
	if key != null and key.pressed and _save_delete_armed:
		_save_delete_armed = false
		_refresh_save_rows()
	return false


func _on_main_activated(id: String) -> void:
	match id:
		"continue":
			continue_requested.emit()
		"new":
			new_game_requested.emit()
		"load":
			show_page("load")
		"options":
			show_page("options")
		"quit":
			quit_requested.emit()


# ── text helpers ──────────────────────────────────────────────────────────────

func _summary(entry: Dictionary) -> String:
	var hours := float(entry.get("time_hours", 9.0))
	var h := int(floor(hours)) % 24
	var m := int(floor((hours - floor(hours)) * 60.0))
	return "DAY %d  %02d:%02d  $%s" % [int(entry.get("day", 1)), h, m, _money(int(entry.get("money", 0)))]


func _money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if amount < 0 else "") + out


func _ago(unix: int) -> String:
	if unix <= 0:
		return ""
	var delta := int(Time.get_unix_time_from_system()) - unix
	if delta < 90:
		return "JUST NOW"
	if delta < 3600:
		return "%d MIN AGO" % (delta / 60)
	if delta < 86400:
		return "%d H AGO" % (delta / 3600)
	return "%d DAYS AGO" % (delta / 86400)
