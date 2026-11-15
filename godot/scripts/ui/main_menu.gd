extends CanvasLayer

## The title screen's menu over the reception at dusk (scripts/ui/title/title_stage.gd
## holds the office's view; playtest 14. 11.: "the reception at dusk": the menu is the
## counter's own things). The main page is the guest book open on the counter
## (title_book.gd): what can be done, a line each, and the last entry, the camp CONTINUE
## goes back to. Every other page is a thing on the counter seen close up (title_desk.gd,
## a page object each, in scripts/ui/title/):
##   camps      the camps as keys on the key board          page_keys.gd
##   saves      one camp's saves on a printout              page_saves.gd  ("load")
##   newcamp    the application with its rubber stamp        page_form.gd
##   coop       the office telephone                         page_phone.gd
##   warden     the warden's ID card                         page_warden.gd ("profiles", "look")
##   options    the configuration's printouts               page_config.gd ("controls", "credits")
## and the secret test nights (L on the main page: a fresh test camp at 20:00 with the
## chosen thing already out, nothing saved) on a plate. A new player starts at a blank
## ID card. A loading plate covers everything while main builds the world. Wardens and
## camps are scripts/profiles.gd's; main.gd owns what the choices *do*, this script and
## its pages only report them (the signals).

const INSTANCE = preload("res://scripts/instance/instance.gd")
signal continue_requested
signal new_game_requested
## `sandbox`: no story; `rules` its switches (main.CAMP_RULES: threats, weather, events,
## wear, money). A co-op camp is always a sandbox camp.
signal new_camp_requested(camp_name: String, seed: int, coop: bool, sandbox: bool, rules: Dictionary)
signal profile_changed
signal load_requested(path: String)
signal quit_requested
signal coop_host_requested
signal coop_host_saved_requested(path: String)
signal coop_join_requested(address: String)
signal test_night_requested(enemy_id: String)

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")
const PROFILES = preload("res://scripts/profiles.gd")
const LANG = preload("res://scripts/lang.gd")
const BOOT_SCREEN = preload("res://scripts/ui/boot_screen.gd")
const CAMP_TEXT = preload("res://scripts/ui/title/camp_text.gd")
const TITLE_BOOK = preload("res://scripts/ui/title/title_book.gd")
const TITLE_DESK = preload("res://scripts/ui/title/title_desk.gd")
const PAGE_KEYS = preload("res://scripts/ui/title/page_keys.gd")
const PAGE_SAVES = preload("res://scripts/ui/title/page_saves.gd")
const PAGE_FORM = preload("res://scripts/ui/title/page_form.gd")
const PAGE_PHONE = preload("res://scripts/ui/title/page_phone.gd")
const PAGE_WARDEN = preload("res://scripts/ui/title/page_warden.gd")
const PAGE_CONFIG = preload("res://scripts/ui/title/page_config.gd")
## Old page names and the page each is now (the shot driver, main.gd's game over).
const ALIASES := {"profiles": "warden", "look": "warden", "load": "saves", "controls": "options", "credits": "options"}
## The configuration's sheet an old page name opens.
const SHEET_OF := {"options": "main", "controls": "controls", "credits": "credits"}

## The test nights, in the order of the guests who bring them (main.debug_spawn_enemy ids).
const TEST_NIGHTS: Array[Dictionary] = [
	{"id": "silent_man", "text": "Silent Man", "sub": "Quiet Guy"},
	{"id": "tourist", "text": "Photographer", "sub": "Drunk"},
	{"id": "girl", "text": "Girl", "sub": "Cheap Chick"},
	{"id": "whistler", "text": "Whistler", "sub": "Tramp"},
	# His places in turn, one each time: the corn, the board, the pipes (main).
	{"id": "child", "text": "The Boy", "sub": "Family: corn, board, pipes"},
	{"id": "basket", "text": "The Granny", "sub": "Mushroom Picker"},
	{"id": "stalker", "text": "Antlered Man", "sub": "Mixed camp"},
	# Not a thing: the sewer breaks again as soon as it is mended (main.TEST_SEWER).
	{"id": "sewer", "text": "Sewer", "sub": "Pipes minigame"},
	# Not a night: the camp's bus stop as the 380 comes up the road (scripts/debug/test_camps.gd start_bus).
	{"id": "bus", "text": "Bus to Liblice", "sub": "Day, camp stop"},
	# Not a night: every business and a full camp, to try the work (main._start_test_businesses).
	{"id": "podniky", "text": "Businesses", "sub": "Day, a full camp"},
	# Not a night: a day of the camp's best scenes for filming, L for the next
	# (scripts/content_reel.gd).
	{"id": "content", "text": "Content reel", "sub": "L: next scene"},
]

var _scale: int = 3
var _built_for: Vector2 = Vector2.ZERO
var _page: String = "main"
var _root: Control
var _book
var _desk
## The pages on the counter, by name.
var _pages: Dictionary = {}
## Hosting for two: the camps, the new camp and the saves are the co-op's (sandbox only).
var for_coop := false
var _has_continue := false
var _continue_camp: Dictionary = {}
var _continue_save: Dictionary = {}
var _sub_shade
var _test_page: Control
var _test_list
var _loading: Control
var _loading_label: Label
var _loading_tip: Label
var _loading_bar


func _init() -> void:
	name = "MainMenu"
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_desk = TITLE_DESK.new()
	_desk.name = "TitleDesk"
	add_child(_desk)
	_desk.back.connect(_desk_back)
	_pages = {
		"camps": PAGE_KEYS.new(self, _desk),
		"saves": PAGE_SAVES.new(self, _desk),
		"newcamp": PAGE_FORM.new(self, _desk),
		"coop": PAGE_PHONE.new(self, _desk),
		"warden": PAGE_WARDEN.new(self, _desk),
		"options": PAGE_CONFIG.new(self, _desk),
	}
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_rebuild()


## The language changed (the warden's, a flag on their card): the guest book written again
## in it, the page on the counter too.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _book != null and is_instance_valid(_book):
		_book.set_items(_main_items(), "continue" if _has_continue else "new")
		_book.set_entry(_book_entry())
		if _desk != null:
			_desk.redraw()


# ── public API ────────────────────────────────────────────────────────────────

func open() -> void:
	visible = true
	refresh_saves()
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show_page("main" if PROFILES.has_profile() else "warden")


func close() -> void:
	visible = false
	_desk.close()
	hide_loading()


func show_page(page: String) -> void:
	if SHEET_OF.has(page):
		_pages["options"].sheet = SHEET_OF[page]
	page = str(ALIASES.get(page, page))
	if page == "saves" and str(_pages["saves"].camp_id) == "":
		_pages["saves"].camp_id = PROFILES.camp_id
	if page == "main":
		for_coop = false
	_page = page
	if _pages.has(page):
		_desk.open_page(_pages[page])
	else:
		_desk.close()
	if _book != null:
		_book.visible = page == "main"
	if _test_page != null:
		_test_page.visible = page == "test"
		_sub_shade.visible = page == "test"


## Re-reads the saves: the guest book's CONTINUE and its last entry.
func refresh_saves() -> void:
	var newest: Array[Dictionary] = SaveManager.list_saves() if SaveManager != null else []
	_has_continue = not newest.is_empty()
	_continue_camp = PROFILES.camp_info(PROFILES.camp_id) if PROFILES.camp_id != "" else {}
	_continue_save = newest[0] if _has_continue else {}
	if _book != null:
		_book.set_items(_main_items(), "continue" if _has_continue else "new")
		_book.set_entry(_book_entry())


## A save opened from a page (the key board's camp at its last, one of its saves): played,
## or hosted for two.
func open_save(path: String) -> void:
	if path == "":
		return
	PROFILES.activate_for_save(path)
	if for_coop:
		coop_host_saved_requested.emit(path)
	else:
		load_requested.emit(path)


## One camp's saves on the printout.
func show_saves(camp_id: String) -> void:
	_pages["saves"].camp_id = camp_id
	show_page("saves")


## The warden changed (another chosen, renamed, dressed, made, thrown away): the guest
## book's entry is theirs, main is told.
func warden_changed() -> void:
	refresh_saves()
	profile_changed.emit()


## Opens the co-op page with a line on its sheet (why a call failed, the host left).
func show_coop_notice(text: String) -> void:
	if not visible:
		open()
	show_page("coop")
	_pages["coop"].notice = text
	_desk.redraw()


## What the co-op page says went wrong ("" nothing; the co-op checks read it).
func coop_notice() -> String:
	return str(_pages["coop"].notice)


func show_loading(message: String) -> void:
	if _loading == null:
		return
	_loading_label.text = tr(message).trim_suffix("...").to_upper()
	# The camp it is about, under the bar.
	_loading_tip.text = PROFILES.profile_name().to_upper() if PROFILES.has_profile() else ""
	_loading.visible = true


func hide_loading() -> void:
	if _loading != null:
		_loading.visible = false


## Esc, the right button, a click off the counter's thing: the page before.
func _desk_back() -> void:
	match _page:
		"camps", "newcamp":
			show_page("coop" if for_coop else "main")
		"saves":
			show_page("camps")
		"warden":
			if PROFILES.has_profile():
				_pages["warden"].click("back")
		_:
			show_page("main")


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
	_book = TITLE_BOOK.new()
	_book.name = "GuestBook"
	_root.add_child(_book)
	_book.layout(vp)
	_book.activated.connect(_on_main_activated)
	# The test nights' plate over the dimmed office.
	_sub_shade = RETRO_MENU.DitherShade.new()
	_sub_shade.ui_scale = _scale
	_sub_shade.mode = "full"
	_sub_shade.color = Color(0.02, 0.012, 0.01, 0.6)
	_root.add_child(_sub_shade)
	var plate_h := minf(vp.y - _vp(13 + 12), _vp(206))
	_test_page = _page_frame("TEST NIGHTS", plate_h)
	_test_list = RETRO_MENU.MenuList.new()
	_test_list.ui_scale = _scale
	_test_list.size_vp = RETRO_UI.SIZE_BIG
	_test_list.row_height_vp = 15
	_test_list.position = Vector2(_vp(2), _vp(28))
	_test_list.size = Vector2(_test_page.size.x - _vp(8), _vp(15 * (TEST_NIGHTS.size() + 1)))
	_test_page.add_child(_test_list)
	_test_list.activated.connect(_on_test_activated)
	_lantern(_test_list)
	var test_items: Array[Dictionary] = []
	test_items.append_array(TEST_NIGHTS)
	test_items.append({"id": "back", "text": "Back"})
	_test_list.set_items(test_items)
	var test_hint := RETRO_UI.label("A FRESH CAMP. NOTHING IS SAVED.", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	test_hint.position = Vector2(_vp(8), plate_h - _vp(13))
	_test_page.add_child(test_hint)
	_build_loading(vp)
	refresh_saves()
	_book.visible = _page == "main"
	_test_page.visible = _page == "test"
	_sub_shade.visible = _page == "test"


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


## The guest book's last entry: the camp CONTINUE goes back to, its photograph, its day and
## till, its warden and how long ago ({} without one).
func _book_entry() -> Dictionary:
	if not _has_continue or _continue_save.is_empty():
		return {}
	return {"name": str(_continue_camp.get("name", "Camp")), "thumb": CAMP_TEXT.thumb(str(_continue_camp.get("thumb", ""))),
		"lines": [CAMP_TEXT.summary(_continue_save), LANG.f("Warden %s", [PROFILES.profile_name()]), CAMP_TEXT.ago(int(_continue_save.get("updated_unix", 0)))]}


# ── input ─────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp != _built_for:
		_rebuild()


## The guest book's keys and the test nights' (the counter's pages take their own:
## title_desk.gd).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or (_loading != null and _loading.visible):
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var used := false
	match _page:
		"main":
			var key := event as InputEventKey
			if key != null and key.pressed and not key.echo and key.keycode == KEY_L:
				show_page("test")
				_test_list.select(0, false)
				used = true
			else:
				used = _book.handle_input(event)
		"test":
			if event.is_action_pressed("ui_cancel"):
				show_page("main")
				used = true
			else:
				used = _test_list.handle_input(event)
	if used:
		get_viewport().set_input_as_handled()


func _on_main_activated(id: String) -> void:
	match id:
		"continue":
			continue_requested.emit()
		"new":
			for_coop = false
			show_page("newcamp")
		"load":
			for_coop = false
			show_page("camps")
		"warden":
			show_page("warden")
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


# ── the look ──────────────────────────────────────────────────────────────────

## The test nights' plate in the menu's old surfaces (Grok, assets/textury/ui/): rusty
## riveted steel, a kerosene lantern for the cursor.
const UI_TEX := "res://assets/textury/ui/"


static func _ui_tex(name: String) -> Texture2D:
	var p := UI_TEX + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


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
