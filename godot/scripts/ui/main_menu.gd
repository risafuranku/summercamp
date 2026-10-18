extends CanvasLayer

## Title screen over the live camp flythrough (the flythrough camera stays in main.gd).
##
##   CURSED CAMP                         (live camp, dithered dark on the left)
##   MANAGER SIMULATOR                   (the logo now and then flickers, in steps)
##
##   > CONTINUE
##     NEW CAMP
##     LOAD CAMP
##     CO-OP
##     WARDEN
##     CONFIGURATION
##     QUIT TO DOS
##
##   [picture] SPRUCE HOLLOW 1           (the camp CONTINUE goes back to: its picture,
##             DAY 3  21:40  $1,234       day, till and the warden; a click continues)
##             WARDEN RICKY
##   [v0.3  (C) 2026 UNDO LABS                                                    ]
## Clean (playtest 18. 10.): no tagline, no key hints.
##
## Wardens and camps (scripts/profiles.gd, playtest 18. 10.: "profiles with a name, worlds
## like Minecraft"): WARDEN picks or makes the profile whose camps you play (a new player
## is asked their name first, then chooses the figure and jacket the other warden sees in
## co-op; Edit warden changes the name and the look later); NEW CAMP asks the camp's name
## and, if you like, its seed;
## LOAD CAMP shows the warden's camps as tiles (the camp at its last save, day, till), a
## tile opens the camp: its saves to load, Duplicate, Delete. CO-OP hosts a new camp or a
## saved one through the same pages.
## Pages: main, profiles, look (one warden), newcamp, camps, load (one camp), coop, options, controls, and the secret test nights (L on the main
## page: a fresh test camp at 20:00 with the chosen thing already out, nothing saved). CO-OP (scripts/coop/coop.gd): host a
## sandbox camp (this machine's addresses beside it, for the other warden) or join one
## (Join opens a direct-connect window: the host's address, the last one filled in; it
## can also be typed straight into the row); your warden drawn beside the rows with their
## name (scripts/coop/warden_looks.gd). A loading plate covers everything while main
## builds the world. main.gd owns what the choices *do*; this script only reports them.

signal continue_requested
signal new_game_requested
signal new_camp_requested(camp_name: String, seed: int, coop: bool)
signal profile_changed
signal load_requested(path: String)
signal quit_requested
signal coop_host_requested
signal coop_host_saved_requested(path: String)
signal coop_join_requested(address: String)
signal test_night_requested(enemy_id: String)

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")
const WARDEN_LOOKS = preload("res://scripts/coop/warden_looks.gd")
const PROFILES = preload("res://scripts/profiles.gd")
const BOOT_SCREEN = preload("res://scripts/ui/boot_screen.gd")
const TILE_COLS := 3
const TILE_ROWS := 2

const VISIBLE_SAVE_ROWS := 6
## The test nights, in the order of the guests who bring them (main.debug_spawn_enemy ids).
const TEST_NIGHTS: Array[Dictionary] = [
	{"id": "silent_man", "text": "Silent Man", "sub": "Quiet Guy"},
	{"id": "tourist", "text": "Photographer", "sub": "Drunk"},
	{"id": "girl", "text": "Girl", "sub": "Cheap Chick"},
	{"id": "whistler", "text": "Whistler", "sub": "Tramp"},
	{"id": "child", "text": "Extra Child", "sub": "Family"},
	{"id": "basket", "text": "Basket Man", "sub": "Mushroom Picker"},
	{"id": "stalker", "text": "Antlered Man", "sub": "Mixed camp"},
	# Not a thing: the sewer breaks again as soon as it is mended (main.TEST_SEWER).
	{"id": "sewer", "text": "Sewer", "sub": "Pipes minigame"},
]

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
var _test_page: Control
var _test_list
var _coop_page: Control
var _coop_list
var _coop_notice: Label
var _coop_address := ""
var _coop_caret_t := 0.0
var _coop_preview: TextureRect
var _coop_who: Label
var _coop_last_path := ""
## The warden's name and look (WARDENS: a new warden, or Edit warden).
var _look_page: Control
var _look_list
var _look_preview: TextureRect
var _look_pid := ""
var _look_back := "profiles"
## Direct connect: the window over the CO-OP page with the address field.
var _connect_box: Control
var _connect_field: LineEdit
var _loading: Control
var _loading_label: Label
var _loading_tip: Label
var _loading_bar
var _loading_t: float = 0.0
var _has_continue: bool = false
var _continue_sub: String = ""
## The logo (it flickers now and then) and the card of the camp CONTINUE goes back to.
var _logo
var _flicker_next := 6.0
var _flicker_t := -1.0
var _card: Control
var _card_pic: TextureRect
var _card_name: Label
var _card_info: Label
var _card_warden: Label
## Camps and wardens.
var _for_coop := false
var _profiles_page: Control
var _profiles_list
var _profile_ids: Array[String] = []
var _profile_delete_armed := ""
var _newcamp_page: Control
var _newcamp_title
var _nc_name: LineEdit
var _nc_seed: LineEdit
var _camps_page: Control
var _camps_title
var _tiles: Array[Control] = []
var _camps: Array[Dictionary] = []
var _camp_sel := 0
var _camp_hint: Label
var _camp_id := ""
var _load_title
var _camp_thumb: TextureRect
var _camp_info: Label
var _btn_dup: Button
var _btn_del: Button
var _camp_delete_armed := false
var _ask_box: Control
var _ask_title: Label
var _ask_field: LineEdit
var _ask_done: Callable


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
	if not PROFILES.has_profile():
		show_page("profiles")
		_ask("WHO KEEPS THE CAMP?", "", "Your name", _make_profile)


func close() -> void:
	visible = false
	hide_loading()


func show_page(page: String) -> void:
	_page = page
	if _card != null:
		_card.visible = page == "main" and _has_continue
	_save_delete_armed = false
	_camp_delete_armed = false
	_profile_delete_armed = ""
	if _connect_box != null:
		_connect_box.visible = false
	if _ask_box != null:
		_ask_box.visible = false
	for pg in [_profiles_page, _look_page, _newcamp_page, _camps_page]:
		if pg != null:
			pg.visible = false
	if page == "profiles" and _profiles_page != null:
		_profiles_page.visible = true
		_refresh_profiles()
	elif page == "look" and _look_page != null:
		_look_page.visible = true
		_refresh_look()
	elif page == "newcamp" and _newcamp_page != null:
		_newcamp_page.visible = true
		_open_newcamp()
	elif page == "camps" and _camps_page != null:
		_camps_page.visible = true
		_refresh_camps()
	if _main_list == null:
		return
	_main_list.get_parent().visible = page == "main"
	_column.visible = page == "main"
	_sub_shade.visible = page != "main"
	_load_page.visible = page == "load"
	_options_page.visible = page == "options"
	_controls_page.visible = page == "controls"
	if _test_page != null:
		_test_page.visible = page == "test"
	if _coop_page != null:
		_coop_page.visible = page == "coop"
	if page == "coop":
		_refresh_coop()
	if page == "load":
		_refresh_camp_page()
	elif page == "options":
		_options.refresh()


## Re-reads the save folder: CONTINUE line, load list.
func refresh_saves() -> void:
	var newest: Array[Dictionary] = SaveManager.list_saves() if SaveManager != null else []
	_has_continue = not newest.is_empty()
	var camp: Dictionary = PROFILES.camp_info(PROFILES.camp_id) if PROFILES.camp_id != "" else {}
	_continue_sub = ("%s  %s" % [str(camp.get("name", "")).to_upper(), _summary(newest[0])]) if _has_continue else ""
	_save_entries = SaveManager.list_saves(PROFILES.camp_dir(_camp_id).path_join("saves")) if _camp_id != "" else newest
	_refresh_card(camp, newest[0] if _has_continue else {})
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
	_loading_label.text = message.trim_suffix("...").to_upper()
	# The camp it is about, under the bar.
	_loading_tip.text = PROFILES.profile_name().to_upper() if PROFILES.has_profile() else ""
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
	logo.set_colors(LOGO_TOP, LOGO_BOTTOM)
	logo.set_text("CURSED CAMP")
	logo.position = Vector2(-_vp(3), y)
	logo.size = logo.custom_minimum_size
	_column.add_child(logo)
	_logo = logo
	_paint_logo(logo)
	y += logo.custom_minimum_size.y - _vp(2)
	var sub := RETRO_UI.label("M A N A G E R   S I M U L A T O R", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, _scale)
	sub.position = Vector2(_vp(1), y)
	_column.add_child(sub)
	y += _vp(22)

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
	# Plain rows in the single-size letters, the one chosen amber, the rest muted.
	_main_list.row_height_vp = 15
	_main_list.size_vp = RETRO_UI.SIZE_BIG
	_main_list.indent_vp = 10
	_main_list.color_normal_top = Color(0.72, 0.68, 0.6)
	_main_list.color_normal_bottom = Color(0.5, 0.46, 0.4)
	_main_list.color_disabled = Color(0.3, 0.27, 0.24)
	_main_list.position = Vector2(-_vp(2), 0.0)
	_main_list.size = Vector2(vp.x * 0.6, pages_h)
	main_page.add_child(_main_list)
	_main_list.activated.connect(_on_main_activated)
	_lantern(_main_list)
	_main_list.set_items(_main_items())
	_build_card(vp)

	# ONE CAMP (its saves)
	_load_page = _page_frame("CAMP", plate_h)
	_load_title = _load_page.get_child(0)
	var left_w := _vp(100)
	_camp_thumb = TextureRect.new()
	_camp_thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_camp_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_camp_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_camp_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camp_thumb.position = Vector2(_vp(6), _vp(28))
	_camp_thumb.size = Vector2(left_w, left_w * 9.0 / 16.0)
	_load_page.add_child(_camp_thumb)
	_camp_info = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	_camp_info.position = Vector2(_vp(6), _camp_thumb.position.y + _camp_thumb.size.y + _vp(4))
	_load_page.add_child(_camp_info)
	_btn_dup = _plate_button(_load_page, "Duplicate", Vector2(_vp(6), plate_h - _vp(50)), Vector2(left_w, _vp(14)), _duplicate_camp)
	_btn_del = _plate_button(_load_page, "Delete camp", Vector2(_vp(6), plate_h - _vp(33)), Vector2(left_w, _vp(14)), _delete_camp)
	var inner_w := _load_page.size.x - left_w - _vp(16)
	_save_rows_host = Control.new()
	_save_rows_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_rows_host.position = Vector2(left_w + _vp(12), _vp(28))
	_save_rows_host.size = Vector2(inner_w, _vp(22 * _visible_rows))
	_load_page.add_child(_save_rows_host)
	_save_rows.clear()
	for i in _visible_rows:
		_save_rows.append(_make_save_row(i, inner_w))
	_save_hint = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	_save_hint.position = Vector2(_vp(8), plate_h - _vp(13))
	_load_page.add_child(_save_hint)

	_build_camp_pages(plate_h)

	# CO-OP
	_coop_page = _page_frame("CO-OP", plate_h)
	_coop_list = RETRO_MENU.MenuList.new()
	_coop_list.ui_scale = _scale
	_coop_list.row_height_vp = 22
	_coop_list.position = Vector2(_vp(2), _vp(30))
	_coop_list.size = Vector2(_coop_page.size.x * 0.66, _vp(22 * 6))
	_coop_page.add_child(_coop_list)
	_coop_list.activated.connect(_on_coop_activated)
	_lantern(_coop_list)
	var coop_items: Array[Dictionary] = [
		{"id": "host", "text": "Host a new camp"},
		{"id": "host_last", "text": "Host a saved camp"},
		{"id": "join", "text": "Join"},
		{"id": "back", "text": "Back"},
	]
	_coop_list.set_items(coop_items)
	# Your warden, as the other one will see you (chosen on the WARDENS page).
	var pv_top := _vp(28 + 22 * 3)
	var pv_h := plate_h - pv_top - _vp(28)
	_coop_preview = _warden_preview(_coop_page, Vector2(_coop_page.size.x - pv_h * 0.42 - _vp(12), pv_top), pv_h)
	_coop_who = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	_coop_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coop_who.position = Vector2(_coop_preview.position.x - _vp(30), pv_top + pv_h + _vp(2))
	_coop_who.size = Vector2(_coop_preview.size.x + _vp(60), _vp(10))
	_coop_page.add_child(_coop_who)
	_coop_notice = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, _scale)
	_coop_notice.position = Vector2(_vp(8), plate_h - _vp(13))
	_coop_page.add_child(_coop_notice)
	_build_connect_box()

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

	# TEST NIGHTS (secret: L on the main page)
	_test_page = _page_frame("TEST NIGHTS", plate_h)
	_test_list = RETRO_MENU.MenuList.new()
	_test_list.ui_scale = _scale
	_test_list.size_vp = RETRO_UI.SIZE_BIG
	_test_list.row_height_vp = 15
	_test_list.position = Vector2(_vp(2), _vp(28))
	_test_list.size = Vector2(_test_page.size.x - _vp(8), _vp(15 * (TEST_NIGHTS.size() + 1)))
	_test_page.add_child(_test_list)
	_test_list.activated.connect(_on_test_activated)
	var test_items: Array[Dictionary] = []
	test_items.append_array(TEST_NIGHTS)
	test_items.append({"id": "back", "text": "Back"})
	_test_list.set_items(test_items)
	var test_hint := RETRO_UI.label("A FRESH CAMP AT 20:00. NOTHING IS SAVED.", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	test_hint.position = Vector2(_vp(8), plate_h - _vp(13))
	_test_page.add_child(test_hint)

	_build_ask_box()
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
	_steel(page)
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
	bar.tile_texture = _ui_tex("menu_wood.png") if _ui_tex("menu_wood.png") != null else RETRO_UI.texture(RETRO_UI.PLATE_TEXTURE_PATH)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -_vp(13)
	bar.offset_left = -_vp(1)
	bar.offset_right = _vp(1)
	_root.add_child(bar)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var left := RETRO_UI.label("V%s  (C) 2026 UNDO LABS" % version if not version.is_empty() else "(C) 2026 UNDO LABS", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	left.position = Vector2(_vp(6), 0.0)
	RETRO_UI.place_on_baseline(left, 9.0, _scale)
	left.offset_left = _vp(6)
	bar.add_child(left)


## Over the dimmed camp while a camp is made or opened: what is going on in the big
## letters, the boot's stepped bar sweeping under it (no tips: clean).
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
	shade.color = Color(0.01, 0.008, 0.006, 0.86)
	_loading.add_child(shade)
	var frame = RETRO_MENU.DitherShade.new()
	frame.ui_scale = _scale
	frame.mode = "frame"
	frame.band = 0.16
	frame.color = Color(0, 0, 0, 1)
	_loading.add_child(frame)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(_vp(5)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.add_child(box)
	_loading_label = RETRO_UI.label("", RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG, RETRO_UI.C_AMBER_LIGHT, _scale)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_loading_label)
	_loading_bar = BOOT_SCREEN.StepBar.new()
	_loading_bar.ui_scale = _scale
	_loading_bar.segments = 20
	_loading_bar.sweep = true
	_loading_bar.custom_minimum_size = Vector2(_vp(130), _vp(7))
	_loading_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_loading_bar)
	_loading_tip = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	_loading_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_loading_tip)


func _main_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if _has_continue:
		items.append({"id": "continue", "text": "Continue"})
	items.append({"id": "new", "text": "New camp"})
	items.append({"id": "load", "text": "Load camp", "enabled": not PROFILES.list_camps().is_empty()})
	items.append({"id": "coop", "text": "Co-op"})
	items.append({"id": "warden", "text": "Warden"})
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
			_save_hint.text = "NO SAVES YET"
		else:
			var more := ""
			if _save_entries.size() > _visible_rows:
				more = "%d/%d" % [_save_selected + 1, _save_entries.size()]
			_save_hint.text = more


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
	var path := str(_save_entries[_save_selected].get("path", ""))
	PROFILES.activate_for_save(path)
	if _for_coop:
		coop_host_saved_requested.emit(path)
	else:
		load_requested.emit(path)


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
	_refresh_camp_page()


# ── input ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible:
		return
	_flicker(delta)
	var vp := get_viewport().get_visible_rect().size
	if vp != _built_for:
		_rebuild()
	if _page == "coop" and _coop_list != null:
		# The caret in the address, blinking in steps.
		_coop_caret_t += delta
		if fmod(_coop_caret_t, 0.5) < delta:
			_refresh_coop_address()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (_loading != null and _loading.visible):
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var used := false
	if _ask_box != null and _ask_box.visible:
		# The field has the keys; Esc closes the box (not the first warden's).
		if event.is_action_pressed("ui_cancel") and PROFILES.has_profile():
			_ask_box.visible = false
		get_viewport().set_input_as_handled()
		return
	match _page:
		"profiles":
			used = _handle_profiles_input(event)
		"look":
			used = _handle_look_input(event)
		"newcamp":
			if event.is_action_pressed("ui_cancel"):
				show_page("coop" if _for_coop else "main")
				used = true
		"camps":
			used = _handle_camps_input(event)
		"main":
			var key := event as InputEventKey
			if key != null and key.pressed and not key.echo and key.keycode == KEY_L:
				show_page("test")
				_test_list.select(0, false)
				used = true
			else:
				used = _main_list.handle_input(event)
		"test":
			if event.is_action_pressed("ui_cancel"):
				show_page("main")
				used = true
			else:
				used = _test_list.handle_input(event)
		"load":
			used = _handle_load_input(event)
		"coop":
			used = _handle_coop_input(event)
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
			show_page("camps")
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
			_for_coop = false
			show_page("newcamp")
		"load":
			_for_coop = false
			show_page("camps")
		"warden":
			show_page("profiles")
		"coop":
			show_page("coop")
		"options":
			show_page("options")
		"quit":
			quit_requested.emit()


func _on_test_activated(id: String) -> void:
	if id == "back":
		show_page("main")
	else:
		test_night_requested.emit(id)


# ── co-op ─────────────────────────────────────────────────────────────────────

## Opens the co-op page with a line under the rows (why a call failed, the host left).
func show_coop_notice(text: String) -> void:
	if not visible:
		open()
	show_page("coop")
	if _coop_notice != null:
		_coop_notice.text = text.to_upper()


func _refresh_coop() -> void:
	if _coop_list == null:
		return
	if _coop_address.is_empty() and Coop != null:
		_coop_address = Coop.last_address
	var here: Array[String] = Coop.local_addresses() if Coop != null else []
	_coop_list.set_item_sub("host", "  ".join(here.slice(0, 2)))
	# The camp last hosted for two: its day and till.
	_coop_list.set_item_enabled("host_last", not PROFILES.list_camps().is_empty())
	_coop_list.set_item_sub("host_last", "")
	_refresh_coop_address()
	_refresh_coop_look()


## The warden you are, drawn beside the rows with their name.
func _refresh_coop_look() -> void:
	if _coop_list == null or Coop == null:
		return
	var look: Dictionary = Coop.my_look()
	if _coop_preview != null:
		_coop_preview.texture = WARDEN_LOOKS.texture(int(look["m"]), int(look["c"]), "stand")
	if _coop_who != null:
		_coop_who.text = str(look.get("n", "")).to_upper()


func _refresh_coop_address() -> void:
	if _coop_list == null:
		return
	var caret := "_" if _coop_list.current_id() == "join" and fmod(_coop_caret_t, 1.0) < 0.5 else " "
	_coop_list.set_item_sub("join", _coop_address + caret)


func _on_coop_activated(id: String) -> void:
	match id:
		"host":
			if _coop_notice != null:
				_coop_notice.text = ""
			_for_coop = true
			show_page("newcamp")
		"host_last":
			if _coop_notice != null:
				_coop_notice.text = ""
			_for_coop = true
			show_page("camps")
		"join":
			_open_connect_box()
		"back":
			show_page("main")


## The address is typed straight into the Join row (digits, letters, . : -), Backspace,
## Ctrl+V; the rows move with the arrows; Esc goes back.
func _handle_coop_input(event: InputEvent) -> bool:
	if _connect_box != null and _connect_box.visible:
		# The field has the keys; Esc closes the window.
		if event.is_action_pressed("ui_cancel"):
			_close_connect_box()
		return true
	if event.is_action_pressed("ui_cancel"):
		show_page("main")
		return true
	var key := event as InputEventKey
	if key != null and key.pressed and _coop_list.current_id() == "join":
		if key.keycode == KEY_BACKSPACE:
			_coop_address = _coop_address.left(maxi(0, _coop_address.length() - 1))
			_refresh_coop_address()
			return true
		if key.keycode == KEY_V and key.ctrl_pressed:
			var pasted := DisplayServer.clipboard_get().strip_edges()
			for ch in pasted:
				if _address_char(ch) and _coop_address.length() < 40:
					_coop_address += ch
			_refresh_coop_address()
			return true
		var ch := String.chr(key.unicode) if key.unicode > 32 else ""
		if ch != "" and _address_char(ch) and not key.ctrl_pressed and not key.alt_pressed:
			if _coop_address.length() < 40:
				_coop_address += ch
			_refresh_coop_address()
			return true
	var used: bool = _coop_list.handle_input(event)
	if used:
		_refresh_coop_address()
	return used


# ── direct connect ────────────────────────────────────────────────────────────

func _build_connect_box() -> void:
	_connect_box = Control.new()
	_connect_box.name = "DirectConnect"
	_connect_box.size = _coop_page.size
	_connect_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_box.visible = false
	_coop_page.add_child(_connect_box)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.size = _coop_page.size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_box.add_child(dim)
	var plate := RETRO_UI.BevelPanel.new()
	plate.ui_scale = _scale
	plate.fill = Color(0.07, 0.06, 0.05, 0.98)
	plate.light = RETRO_UI.C_PANEL_LIGHT
	plate.dark = Color(0.0, 0.0, 0.0, 1.0)
	plate.size = Vector2(minf(_vp(200), _coop_page.size.x - _vp(12)), _vp(76))
	plate.position = ((_coop_page.size - plate.size) * 0.5 / float(_scale)).floor() * float(_scale)
	_connect_box.add_child(plate)
	var title := RETRO_UI.label("DIRECT CONNECT", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER_LIGHT, _scale)
	title.position = Vector2(_vp(8), _vp(6))
	plate.add_child(title)
	_connect_field = LineEdit.new()
	_connect_field.placeholder_text = "192.168.0.10"
	_connect_field.max_length = 60
	_connect_field.position = Vector2(_vp(8), _vp(22))
	_connect_field.size = Vector2(plate.size.x - _vp(16), _vp(18))
	_connect_field.add_theme_font_override("font", RETRO_UI.FONT_TEXT)
	_connect_field.add_theme_font_size_override("font_size", RETRO_UI.SIZE_TEXT * _scale)
	_connect_field.add_theme_color_override("font_color", RETRO_UI.C_BONE)
	_connect_field.add_theme_color_override("font_placeholder_color", RETRO_UI.C_BONE_DIM.darkened(0.3))
	_connect_field.add_theme_color_override("caret_color", RETRO_UI.C_AMBER)
	_connect_field.add_theme_stylebox_override("normal", RETRO_UI.flat_box(RETRO_UI.C_LCD, RETRO_UI.C_PLATE_LIGHT.darkened(0.3), _scale))
	_connect_field.add_theme_stylebox_override("focus", RETRO_UI.flat_box(RETRO_UI.C_LCD, RETRO_UI.C_AMBER, _scale))
	_connect_field.text_submitted.connect(func(_t: String) -> void: _connect_now())
	plate.add_child(_connect_field)
	var go := Button.new()
	go.text = "Connect"
	RETRO_UI.style_button(go, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, _scale)
	go.size = Vector2(_vp(70), _vp(16))
	go.position = Vector2(plate.size.x - _vp(8) - go.size.x * 2.0 - _vp(6), plate.size.y - _vp(24))
	go.pressed.connect(_connect_now)
	plate.add_child(go)
	var cancel := Button.new()
	cancel.text = "Cancel"
	RETRO_UI.style_button(cancel, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, _scale)
	cancel.size = go.size
	cancel.position = Vector2(plate.size.x - _vp(8) - cancel.size.x, go.position.y)
	cancel.pressed.connect(_close_connect_box)
	plate.add_child(cancel)


func _open_connect_box() -> void:
	if _connect_box == null:
		return
	if _coop_notice != null:
		_coop_notice.text = ""
	_connect_field.text = _coop_address.strip_edges()
	_connect_box.visible = true
	_connect_field.grab_focus()
	_connect_field.caret_column = _connect_field.text.length()


func _close_connect_box() -> void:
	if _connect_box != null:
		_connect_box.visible = false
	_refresh_coop_address()


func _connect_now() -> void:
	var address := _connect_field.text.strip_edges()
	if address.is_empty():
		_connect_field.grab_focus()
		return
	_coop_address = address
	_close_connect_box()
	coop_join_requested.emit(address)


static func _address_char(ch: String) -> bool:
	return ch.length() == 1 and (ch.is_valid_int() or ch == "." or ch == ":" or ch == "-" or (ch.to_lower() >= "a" and ch.to_lower() <= "z"))


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


# ── wardens, camps ────────────────────────────────────────────────────────────

func _plate_button(parent: Control, text: String, pos: Vector2, size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	RETRO_UI.style_button(b, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, _scale)
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _line_edit(parent: Control, placeholder: String, pos: Vector2, width: float) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = placeholder
	f.max_length = 28
	f.position = pos
	f.size = Vector2(width, _vp(18))
	f.add_theme_font_override("font", RETRO_UI.FONT_TEXT)
	f.add_theme_font_size_override("font_size", RETRO_UI.SIZE_TEXT * _scale)
	f.add_theme_color_override("font_color", RETRO_UI.C_BONE)
	f.add_theme_color_override("font_placeholder_color", RETRO_UI.C_BONE_DIM.darkened(0.3))
	f.add_theme_color_override("caret_color", RETRO_UI.C_AMBER)
	f.add_theme_stylebox_override("normal", RETRO_UI.flat_box(RETRO_UI.C_LCD, RETRO_UI.C_PLATE_LIGHT.darkened(0.3), _scale))
	f.add_theme_stylebox_override("focus", RETRO_UI.flat_box(RETRO_UI.C_LCD, RETRO_UI.C_AMBER, _scale))
	parent.add_child(f)
	return f


func _build_camp_pages(plate_h: float) -> void:
	# WARDENS
	_profiles_page = _page_frame("WARDENS", plate_h)
	_profiles_list = RETRO_MENU.MenuList.new()
	_profiles_list.ui_scale = _scale
	_profiles_list.row_height_vp = 22
	_profiles_list.position = Vector2(_vp(2), _vp(30))
	_profiles_list.size = Vector2(_profiles_page.size.x - _vp(8), plate_h - _vp(50))
	_profiles_page.add_child(_profiles_list)
	_profiles_list.activated.connect(_on_profile_activated)
	_lantern(_profiles_list)
	# ONE WARDEN: the name and the look
	_look_page = _page_frame("WARDEN", plate_h)
	_look_list = RETRO_MENU.MenuList.new()
	_look_list.ui_scale = _scale
	_look_list.row_height_vp = 22
	_look_list.position = Vector2(_vp(2), _vp(30))
	_look_list.size = Vector2(_look_page.size.x * 0.62, _vp(22 * 4))
	_look_page.add_child(_look_list)
	_look_list.activated.connect(_on_look_activated)
	_lantern(_look_list)
	var look_items: Array[Dictionary] = [
		{"id": "name", "text": "Name"},
		{"id": "figure", "text": "Figure"},
		{"id": "jacket", "text": "Jacket"},
		{"id": "done", "text": "Done"},
	]
	_look_list.set_items(look_items)
	var lp_h := plate_h - _vp(28 + 18)
	_look_preview = _warden_preview(_look_page, Vector2(_look_page.size.x - lp_h * 0.42 - _vp(12), _vp(28)), lp_h)
	var look_hint := RETRO_UI.label("LEFT / RIGHT TO CHANGE. THE OTHER WARDEN SEES THIS.", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	look_hint.position = Vector2(_vp(8), plate_h - _vp(13))
	_look_page.add_child(look_hint)
	# NEW CAMP
	_newcamp_page = _page_frame("NEW CAMP", plate_h)
	_newcamp_title = _newcamp_page.get_child(0)
	var w := _newcamp_page.size.x - _vp(16)
	var l1 := RETRO_UI.label("CAMP NAME", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER_LIGHT, _scale)
	l1.position = Vector2(_vp(8), _vp(32))
	_newcamp_page.add_child(l1)
	_nc_name = _line_edit(_newcamp_page, "", Vector2(_vp(8), _vp(44)), w)
	_nc_name.text_submitted.connect(func(_t: String) -> void: _nc_seed.grab_focus())
	var l2 := RETRO_UI.label("SEED", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER_LIGHT, _scale)
	l2.position = Vector2(_vp(8), _vp(70))
	_newcamp_page.add_child(l2)
	_nc_seed = _line_edit(_newcamp_page, "Random", Vector2(_vp(8), _vp(82)), w)
	_nc_seed.max_length = 12
	_nc_seed.text_submitted.connect(func(_t: String) -> void: _generate_camp())
	_plate_button(_newcamp_page, "Generate", Vector2(_newcamp_page.size.x - _vp(8 + 70 * 2 + 6), plate_h - _vp(30)), Vector2(_vp(70), _vp(16)), _generate_camp)
	_plate_button(_newcamp_page, "Cancel", Vector2(_newcamp_page.size.x - _vp(8 + 70), plate_h - _vp(30)), Vector2(_vp(70), _vp(16)), func() -> void: show_page("coop" if _for_coop else "main"))
	# CAMPS (tiles)
	_camps_page = _page_frame("CAMPS", plate_h)
	_camps_title = _camps_page.get_child(0)
	_tiles.clear()
	var gap := _vp(4)
	var tw := floorf((_camps_page.size.x - _vp(12) - gap * float(TILE_COLS - 1)) / float(TILE_COLS))
	var th := floorf((plate_h - _vp(28 + 18) - gap * float(TILE_ROWS - 1)) / float(TILE_ROWS))
	for i in TILE_COLS * TILE_ROWS:
		_tiles.append(_make_tile(i, Vector2(_vp(6) + float(i % TILE_COLS) * (tw + gap), _vp(28) + float(i / TILE_COLS) * (th + gap)), Vector2(tw, th)))
	_camp_hint = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	_camp_hint.position = Vector2(_vp(8), plate_h - _vp(13))
	_camps_page.add_child(_camp_hint)


func _make_tile(i: int, pos: Vector2, size: Vector2) -> Control:
	var tile := RETRO_UI.BevelPanel.new()
	tile.ui_scale = _scale
	tile.position = pos
	tile.size = size
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_camps_page.add_child(tile)
	var pic := TextureRect.new()
	pic.name = "Pic"
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.position = Vector2(_vp(2), _vp(2))
	pic.size = Vector2(size.x - _vp(4), minf((size.x - _vp(4)) * 9.0 / 16.0, size.y - _vp(24)))
	tile.add_child(pic)
	var n := RETRO_UI.label("", RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE, _scale)
	n.name = "Name"
	n.clip_text = true
	n.size = Vector2(size.x - _vp(6), _vp(10))
	n.position = Vector2(_vp(3), pic.position.y + pic.size.y + _vp(1))
	tile.add_child(n)
	var info := RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	info.name = "Info"
	info.clip_text = true
	info.size = Vector2(size.x - _vp(6), _vp(8))
	info.position = Vector2(_vp(3), n.position.y + _vp(10))
	tile.add_child(info)
	tile.mouse_entered.connect(func() -> void: _select_camp(_page_first() + i))
	tile.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_camp(_page_first() + i)
			_open_camp()
	)
	return tile


func _page_first() -> int:
	var per := TILE_COLS * TILE_ROWS
	return (_camp_sel / per) * per


func _refresh_camps() -> void:
	_camps = PROFILES.list_camps()
	_camp_sel = clampi(_camp_sel, 0, maxi(0, _camps.size() - 1))
	if _camps_title != null:
		_camps_title.set_text("HOST A SAVED CAMP" if _for_coop else "CAMPS")
	_paint_tiles()


func _paint_tiles() -> void:
	var first := _page_first()
	for i in _tiles.size():
		var tile := _tiles[i] as RETRO_UI.BevelPanel
		var idx := first + i
		tile.visible = idx < _camps.size()
		if not tile.visible:
			continue
		var c: Dictionary = _camps[idx]
		var sel := idx == _camp_sel
		tile.fill = Color(0.24, 0.15, 0.07, 0.95) if sel else Color(0.06, 0.05, 0.04, 0.95)
		tile.light = RETRO_UI.C_AMBER if sel else RETRO_UI.C_PANEL_LIGHT
		tile.dark = Color(0, 0, 0, 1)
		tile.queue_redraw()
		(tile.get_node("Pic") as TextureRect).texture = _thumb_texture(str(c.get("thumb", "")))
		var n := tile.get_node("Name") as Label
		n.text = str(c.get("name", "Camp"))
		n.add_theme_color_override("font_color", RETRO_UI.C_AMBER_LIGHT if sel else RETRO_UI.C_BONE)
		(tile.get_node("Info") as Label).text = "DAY %d  $%s  %s" % [int(c.get("day", 1)), _money(int(c.get("money", 0))), _ago(int(c.get("played", 0)))]
	if _camp_hint != null:
		var per := TILE_COLS * TILE_ROWS
		var pages := maxi(1, int(ceil(float(_camps.size()) / float(per))))
		var at := "%d/%d" % [_camp_sel / per + 1, pages] if pages > 1 else ""
		_camp_hint.text = "NO CAMPS YET" if _camps.is_empty() else at


static var _thumbs: Dictionary = {}


func _thumb_texture(path: String) -> Texture2D:
	if path == "":
		return null
	var stamp := FileAccess.get_modified_time(ProjectSettings.globalize_path(path))
	var key := "%s|%d" % [path, stamp]
	if not _thumbs.has(key):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		_thumbs[key] = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	return _thumbs[key]


func _select_camp(index: int) -> void:
	if _camps.is_empty():
		return
	_camp_sel = clampi(index, 0, _camps.size() - 1)
	_paint_tiles()


func _open_camp() -> void:
	if _camp_sel < 0 or _camp_sel >= _camps.size():
		return
	_camp_id = str(_camps[_camp_sel]["id"])
	_save_selected = 0
	_save_scroll = 0
	show_page("load")


func _handle_camps_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		show_page("coop" if _for_coop else "main")
		return true
	if event.is_action_pressed("ui_right", true):
		_select_camp(_camp_sel + 1)
		return true
	if event.is_action_pressed("ui_left", true):
		_select_camp(_camp_sel - 1)
		return true
	if event.is_action_pressed("ui_down", true):
		_select_camp(_camp_sel + TILE_COLS)
		return true
	if event.is_action_pressed("ui_up", true):
		_select_camp(_camp_sel - TILE_COLS)
		return true
	if event.is_action_pressed("ui_accept"):
		_open_camp()
		return true
	return false


## One camp's page: its picture, its card, its saves (newest first).
func _refresh_camp_page() -> void:
	var c: Dictionary = PROFILES.camp_info(_camp_id) if _camp_id != "" else {}
	if _load_title != null:
		var title := str(c.get("name", "CAMP")).to_upper()
		# A long name in the smaller letters, so it stays on the plate.
		_load_title.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * (2 if title.length() <= 15 else 1), _scale)
		_load_title.set_text(title)
		_load_title.size = _load_title.custom_minimum_size
	if _camp_thumb != null:
		_camp_thumb.texture = _thumb_texture(str(c.get("thumb", "")))
	if _camp_info != null:
		var made := Time.get_datetime_dict_from_unix_time(int(c.get("created", 0)))
		_camp_info.text = "DAY %d   $%s\nGUESTS %d\nSEED %d\nSINCE %02d.%02d.%04d%s" % [int(c.get("day", 1)), _money(int(c.get("money", 0))), int(c.get("guests", 0)), int(c.get("seed", 0)), int(made.get("day", 1)), int(made.get("month", 1)), int(made.get("year", 1970)), "\nFOR TWO" if bool(c.get("coop", false)) else ""]
	if _btn_del != null:
		_btn_del.text = "Really delete?" if _camp_delete_armed else "Delete camp"
	refresh_saves()


func _duplicate_camp() -> void:
	if _camp_id == "":
		return
	var nid := PROFILES.duplicate_camp(_camp_id)
	if nid != "":
		_camp_id = nid
		_refresh_camp_page()


func _delete_camp() -> void:
	if _camp_id == "":
		return
	if not _camp_delete_armed:
		_camp_delete_armed = true
		_refresh_camp_page()
		return
	_camp_delete_armed = false
	PROFILES.delete_camp(_camp_id)
	_camp_id = ""
	refresh_saves()
	show_page("camps")


func _open_newcamp() -> void:
	if _newcamp_title != null:
		_newcamp_title.set_text("HOST A NEW CAMP" if _for_coop else "NEW CAMP")
	_nc_name.text = PROFILES.default_camp_name()
	_nc_seed.text = ""
	_nc_name.grab_focus()
	_nc_name.select_all()


func _generate_camp() -> void:
	var name := _nc_name.text.strip_edges()
	if name == "":
		name = PROFILES.default_camp_name()
	var seed_txt := _nc_seed.text.strip_edges()
	var seed := 0
	if seed_txt != "":
		# A number is the seed itself; words make one (the same words, the same camp).
		seed = int(seed_txt) if seed_txt.is_valid_int() else absi(seed_txt.hash())
		seed = (seed & 0x7fffffff) | 1
	_nc_name.release_focus()
	_nc_seed.release_focus()
	new_camp_requested.emit(name, seed, _for_coop)


# ── wardens ───────────────────────────────────────────────────────────────────

func _refresh_profiles() -> void:
	var items: Array[Dictionary] = []
	_profile_ids.clear()
	for pr in PROFILES.list_profiles():
		_profile_ids.append(str(pr["id"]))
		var mine := str(pr["id"]) == PROFILES.profile_id
		var sub := "PRESS DEL AGAIN TO DELETE" if _profile_delete_armed == str(pr["id"]) else "%d CAMP%s%s" % [int(pr["camps"]), "" if int(pr["camps"]) == 1 else "S", "  (PLAYING)" if mine else ""]
		items.append({"id": "p:" + str(pr["id"]), "text": str(pr["name"]), "sub": sub})
	if PROFILES.has_profile():
		items.append({"id": "edit", "text": "Edit warden", "sub": PROFILES.profile_name().to_upper()})
	items.append({"id": "new", "text": "New warden"})
	if PROFILES.has_profile():
		items.append({"id": "back", "text": "Back"})
	var keep: String = _profiles_list.current_id()
	_profiles_list.set_items(items)
	if keep != "":
		_profiles_list.select_id(keep)
	elif PROFILES.has_profile():
		_profiles_list.select_id("p:" + PROFILES.profile_id)


func _on_profile_activated(id: String) -> void:
	if id == "back":
		show_page("main")
	elif id == "new":
		_ask("NEW WARDEN", "", "Name", _make_profile)
	elif id == "edit":
		_open_look(PROFILES.profile_id, "profiles")
	elif id.begins_with("p:"):
		PROFILES.select_profile(id.substr(2))
		_camp_id = ""
		refresh_saves()
		profile_changed.emit()
		show_page("main")


## Named, then dressed: the look page follows (each new warden starts as the next figure).
func _make_profile(name: String) -> void:
	if name.strip_edges() == "":
		return
	var pid := PROFILES.create_profile(name, PROFILES.list_profiles().size() % WARDEN_LOOKS.count(), 0)
	_camp_id = ""
	refresh_saves()
	profile_changed.emit()
	_open_look(pid, "main")


## A frame of the warden standing (the look page, the CO-OP page).
func _warden_preview(parent: Control, pos: Vector2, height: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(height * 0.42, height)
	tr.position = pos
	parent.add_child(tr)
	return tr


func _open_look(pid: String, back: String) -> void:
	if pid == "":
		return
	_look_pid = pid
	_look_back = back
	show_page("look")
	_look_list.select_id("name")


## The warden's look as kept (a warden from before looks were theirs: the one the CO-OP
## page had, for the warden playing, else the first figure).
func _look_now() -> Dictionary:
	var look: Dictionary = PROFILES.profile_look(_look_pid)
	if int(look["m"]) < 0 and _look_pid == PROFILES.profile_id and Coop != null:
		look = Coop.my_look()
	return {"m": posmod(maxi(0, int(look["m"])), WARDEN_LOOKS.count()), "c": posmod(int(look["c"]), WARDEN_LOOKS.color_count())}


func _refresh_look() -> void:
	if _look_list == null or _look_pid == "":
		return
	var look := _look_now()
	_look_list.set_item_sub("name", PROFILES.profile_name(_look_pid).to_upper())
	_look_list.set_item_sub("figure", "<  %s  >" % WARDEN_LOOKS.FIGURES[int(look["m"])])
	_look_list.set_item_sub("jacket", "<  %s  >" % WARDEN_LOOKS.color_name(int(look["c"])))
	_look_preview.texture = WARDEN_LOOKS.texture(int(look["m"]), int(look["c"]), "stand")


func _look_cycle(which: String, dir: int) -> void:
	var look := _look_now()
	var m := int(look["m"])
	var c := int(look["c"])
	if which == "figure":
		m = posmod(m + dir, WARDEN_LOOKS.count())
	else:
		c = posmod(c + dir, WARDEN_LOOKS.color_count())
	PROFILES.set_profile_look(_look_pid, m, c)
	_refresh_look()


func _on_look_activated(id: String) -> void:
	match id:
		"name":
			_ask("WARDEN'S NAME", PROFILES.profile_name(_look_pid), "Name", func(text: String) -> void:
				PROFILES.rename_profile(_look_pid, text)
				_refresh_look())
		"figure", "jacket":
			_look_cycle(id, 1)
		"done":
			_close_look()


## Kept as it is: the card, the list and the other warden (if one is on the line) told.
func _close_look() -> void:
	if _look_pid == PROFILES.profile_id and Coop != null:
		Coop.announce_look()
	refresh_saves()
	profile_changed.emit()
	show_page(_look_back)


func _handle_look_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		_close_look()
		return true
	var row: String = _look_list.current_id()
	if row in ["figure", "jacket"]:
		if event.is_action_pressed("ui_left", true):
			_look_cycle(row, -1)
			return true
		if event.is_action_pressed("ui_right", true):
			_look_cycle(row, 1)
			return true
	return _look_list.handle_input(event)


func _handle_profiles_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		if _profile_delete_armed != "":
			_profile_delete_armed = ""
			_refresh_profiles()
		elif PROFILES.has_profile():
			show_page("main")
		return true
	var key := event as InputEventKey
	var cur: String = _profiles_list.current_id()
	if key != null and key.pressed and not key.echo and key.keycode == KEY_DELETE and cur.begins_with("p:"):
		var pid := cur.substr(2)
		if _profile_delete_armed == pid:
			_profile_delete_armed = ""
			PROFILES.delete_profile(pid)
			_camp_id = ""
			refresh_saves()
			profile_changed.emit()
		else:
			_profile_delete_armed = pid
		_refresh_profiles()
		return true
	if key != null and key.pressed and _profile_delete_armed != "":
		_profile_delete_armed = ""
		_refresh_profiles()
	return _profiles_list.handle_input(event)


# ── a name to type ────────────────────────────────────────────────────────────

func _build_ask_box() -> void:
	_ask_box = Control.new()
	_ask_box.name = "Ask"
	_ask_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ask_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_ask_box.visible = false
	_root.add_child(_ask_box)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ask_box.add_child(dim)
	var plate := RETRO_UI.BevelPanel.new()
	plate.ui_scale = _scale
	plate.fill = Color(0.07, 0.06, 0.05, 0.98)
	plate.light = RETRO_UI.C_PANEL_LIGHT
	plate.dark = Color(0.0, 0.0, 0.0, 1.0)
	plate.size = Vector2(minf(_vp(200), _built_for.x - _vp(12)), _vp(70))
	_steel(plate)
	plate.position = ((_built_for - plate.size) * 0.5 / float(_scale)).floor() * float(_scale)
	_ask_box.add_child(plate)
	_ask_title = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER_LIGHT, _scale)
	_ask_title.position = Vector2(_vp(8), _vp(6))
	plate.add_child(_ask_title)
	_ask_field = _line_edit(plate, "", Vector2(_vp(8), _vp(20)), plate.size.x - _vp(16))
	_ask_field.max_length = 24
	_ask_field.text_submitted.connect(func(_t: String) -> void: _ask_ok())
	_plate_button(plate, "OK", Vector2(plate.size.x - _vp(8 + 60), plate.size.y - _vp(24)), Vector2(_vp(60), _vp(16)), _ask_ok)


func _ask(title: String, value: String, placeholder: String, done: Callable) -> void:
	if _ask_box == null:
		return
	_ask_title.text = title
	_ask_field.text = value
	_ask_field.placeholder_text = placeholder
	_ask_done = done
	_ask_box.visible = true
	_ask_field.grab_focus()


func _ask_ok() -> void:
	var text := _ask_field.text.strip_edges()
	if text == "":
		_ask_field.grab_focus()
		return
	_ask_box.visible = false
	_ask_field.release_focus()
	if _ask_done.is_valid():
		_ask_done.call(text)


# ── the look ──────────────────────────────────────────────────────────────────

## The menu's own surfaces (Grok, assets/textury/ui/): rusty riveted steel for the plates,
## dark boards for the bar at the foot, chipped sign paint in the logo's letters, a
## kerosene lantern for the cursor.
const UI_TEX := "res://assets/textury/ui/"


static func _ui_tex(name: String) -> Texture2D:
	var p := UI_TEX + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _paint_logo(logo: Control) -> void:
	BOOT_SCREEN.paint_logo(logo, _scale)


## A plate in the rusty steel (or as it was, without the texture).
func _steel(panel: Control, tint := Color(0.5, 0.46, 0.42)) -> void:
	var t := _ui_tex("menu_steel.png")
	if t != null and "tile_texture" in panel:
		panel.tile_texture = t
		panel.tile_tint = tint


func _lantern(list) -> void:
	var t := _ui_tex("menu_lantern.png")
	if t != null:
		list.cursor_texture = t


const LOGO_TOP := Color(1.0, 0.84, 0.44)
const LOGO_BOTTOM := Color(0.92, 0.38, 0.08)
const LOGO_DIM_TOP := Color(0.42, 0.26, 0.12)
const LOGO_DIM_BOTTOM := Color(0.3, 0.12, 0.04)


## A failing sign: every few seconds the logo drops dark for a step or two, in steps.
func _flicker(delta: float) -> void:
	if _logo == null:
		return
	if _flicker_t >= 0.0:
		_flicker_t += delta
		var step := int(_flicker_t * 16.0)
		var dark := step in [0, 2, 3]
		_logo.set_colors(LOGO_DIM_TOP if dark else LOGO_TOP, LOGO_DIM_BOTTOM if dark else LOGO_BOTTOM)
		if step > 4:
			_flicker_t = -1.0
			_logo.set_colors(LOGO_TOP, LOGO_BOTTOM)
			_flicker_next = randf_range(5.0, 11.0)
		return
	_flicker_next -= delta
	if _flicker_next <= 0.0:
		_flicker_t = 0.0


## The camp CONTINUE goes back to: its picture, its name, day, time and till, the warden.
func _build_card(vp: Vector2) -> void:
	var card := RETRO_UI.BevelPanel.new()
	card.ui_scale = _scale
	card.fill = Color(0.05, 0.04, 0.03, 0.9)
	card.light = RETRO_UI.C_PANEL_LIGHT
	card.dark = Color(0, 0, 0, 1)
	card.size = Vector2(minf(_vp(212), _column.size.x), _vp(42))
	card.position = Vector2(-_vp(2), _column.size.y - card.size.y)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_steel(card, Color(0.42, 0.38, 0.35))
	card.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			continue_requested.emit()
	)
	_column.add_child(card)
	_card = card
	_card_pic = TextureRect.new()
	_card_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_card_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_pic.position = Vector2(_vp(3), _vp(3))
	_card_pic.size = Vector2(_vp(64), _vp(36))
	card.add_child(_card_pic)
	var x := _vp(72)
	_card_name = RETRO_UI.label("", RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_AMBER_LIGHT, _scale)
	_card_name.position = Vector2(x, _vp(4))
	_card_name.clip_text = true
	_card_name.size = Vector2(card.size.x - x - _vp(4), _vp(10))
	card.add_child(_card_name)
	_card_info = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE, _scale, false)
	_card_info.position = Vector2(x, _vp(16))
	card.add_child(_card_info)
	_card_warden = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale, false)
	_card_warden.position = Vector2(x, _vp(27))
	card.add_child(_card_warden)
	card.visible = false


func _refresh_card(camp: Dictionary, save: Dictionary) -> void:
	if _card == null:
		return
	_card.visible = _has_continue and _page == "main"
	if not _has_continue:
		return
	_card_pic.texture = _thumb_texture(str(camp.get("thumb", "")))
	_card_name.text = str(camp.get("name", "Camp"))
	_card_info.text = _summary(save)
	_card_warden.text = "WARDEN %s   %s" % [PROFILES.profile_name().to_upper(), _ago(int(save.get("updated_unix", 0)))]
