extends Control

## Builder 98, the site planner (shareware, Stavitel software). Runs in its window on the
## camp computer: a menu line, a toolbar (bulldozer, path, lamp, the four catalogues,
## rotate and zoom, the cash and the clock), the catalogue of the open category with
## prices, the isometric map (crt_map_panel.gd) and a status bar that says what is under
## the cursor and what the tool costs.
##
## setup(), focus_map(), set_day_mode() are what builder_app.gd calls.

signal exit_requested
signal message_requested(title: String, text: String, kind: String)
## A Yes/No question; `on_yes` runs on Yes (builder_app.gd asks it in a message box).
signal confirm_requested(title: String, text: String, on_yes: Callable)
## Another program wanted (the building card's GuestRack button).
signal program_requested(app_id: String)
## The title picture has gone (builder_app.gd shows the shareware nag after it).
signal splash_finished

const T = preload("res://scripts/os98/os_theme.gd")
const MAP_PANEL_SCRIPT = preload("res://scripts/crt_map_panel.gd")
const UPKEEP_RULES = preload("res://core/systems/maintenance_rules.gd")
## Keys (the panel's 1-9 are the computer's tabs; S stands you up, D leans you out).
const CATEGORY_KEYS := {KEY_F1: "housing", KEY_F2: "services", KEY_F3: "fun", KEY_F4: "decor", KEY_F5: "utilities"}
const TOOL_KEYS := {KEY_B: "demolish", KEY_P: "path", KEY_L: "lamp_post"}
const OVERLAY_SHORT := {"": "Off", "condition": "Wear", "power": "Power", "rooms": "Rooms", "light": "Light"}

const CATEGORIES: Array = [
	{"id": "housing", "label": "Housing", "icon": "res://assets/textury/builder/tb_housing.png", "items": ["tent_1", "cabin_1", "caravan_1"]},
	{"id": "services", "label": "Services", "icon": "res://assets/textury/builder/tb_services.png", "items": ["toilet_block", "shower_block", "restaurant", "pub", "corn_stand", "vecerka"]},
	{"id": "fun", "label": "Fun", "icon": "res://assets/textury/builder/tb_fun.png", "items": ["bonfire", "sports_field", "lake_slide", "playground", "ping_pong", "hammock"]},
	{"id": "decor", "label": "Decor", "icon": "res://assets/textury/builder/tb_decor.png", "items": ["bench", "picnic_table", "flower_bed", "gnome", "flagpole", "mega_gnome"]},
	{"id": "utilities", "label": "Utilities", "icon": "res://assets/textury/builder/tb_utilities.png", "items": ["sewer"]},
]

## Catalogue pictures (the map has its own, isometric).
const ITEM_ICONS := {
	"tent_1": "res://assets/textury/builder/stan1.png",
	"cabin_1": "res://assets/textury/builder/chata1.PNG",
	"caravan_1": "res://assets/textury/builder/iso_caravan.png",
	"toilet_block": "res://assets/textury/builder/hajzly.PNG",
	"shower_block": "res://assets/textury/builder/sprchy.PNG",
	"vecerka": "res://assets/textury/builder/iso_jednota.png",
	"restaurant": "res://assets/textury/builder/restaurace.PNG",
	"pub": "res://assets/textury/builder/hospoda1.PNG",
	"bonfire": "res://assets/textury/builder/iso_bonfire.png",
	"sports_field": "res://assets/textury/builder/iso_sports.png",
	"lake_slide": "res://assets/textury/builder/iso_slide.png",
	"sewer": "res://assets/textury/builder/sewer.PNG",
	"bench": "res://assets/textury/builder/iso_bench.png",
	"picnic_table": "res://assets/textury/builder/iso_picnic.png",
	"flower_bed": "res://assets/textury/builder/iso_flowerbed.png",
	"gnome": "res://assets/textury/builder/iso_gnome.png",
	"mega_gnome": "res://assets/textury/builder/iso_gnome.png",
	"flagpole": "res://assets/textury/builder/iso_flagpole.png",
	"playground": "res://assets/textury/builder/iso_playground.png",
	"ping_pong": "res://assets/textury/builder/iso_pingpong.png",
	"hammock": "res://assets/textury/builder/iso_hammock.png",
	"corn_stand": "res://assets/textury/builder/iso_corn_stand.png",
}

## Even shorter, for when a catalogue has so many cards that they get narrow.
const TINY_NAMES := {
	"sports_field": "Pitch", "lake_slide": "Slide", "playground": "Swings", "picnic_table": "Picnic",
	"flower_bed": "Flowers", "toilet_block": "WC", "shower_block": "Showers", "restaurant": "Bistro",
	"ping_pong": "Pingpong", "corn_stand": "Corn",
}
## Card size in the catalogue strip: as wide as this, narrower when there are more of
## them than fit (the strip never scrolls: every card of a catalogue is on screen).
const CARD_W := 138
const CARD_MIN_W := 96

## Short names for the catalogue cards; the registry's display names are long.
const SHORT_NAMES := {
	"tent_1": "Tent", "cabin_1": "Cabin", "caravan_1": "Caravan", "toilet_block": "Toilets",
	"shower_block": "Showers", "vecerka": "Jednota", "restaurant": "Bistro", "pub": "Pub",
	"bonfire": "Bonfire", "sports_field": "Sports field", "lake_slide": "Lake slide", "sewer": "Sewage",
	"path": "Path", "lamp_post": "Lamp", "demolish": "Bulldozer",
	"bench": "Bench", "picnic_table": "Picnic table", "flower_bed": "Flower bed", "gnome": "Gnome", "mega_gnome": "Mega gnome",
	"flagpole": "Flagpole", "playground": "Playground", "ping_pong": "Ping-pong", "hammock": "Hammock",
	"corn_stand": "Corn stand",
}

const BLURBS := {
	"tent_1": "Cheap. One guest sleeps here, not very well.",
	"cabin_1": "Two guests, a proper bed. Better sleep, better reviews.",
	"caravan_1": "Two cheap beds on wheels. Needs power. Kids love the bunks.",
	"toilet_block": "Without it, guests use the bushes. Needs the sewer.",
	"shower_block": "Guests get dirty. Needs the sewer.",
	"vecerka": "Bread, salami, ice cream, beer. Guests love it.",
	"restaurant": "Proper hot meals. Needs power.",
	"pub": "Beer and noise. Guests love it, then they get loud.",
	"bonfire": "Fun, food on sticks, and a light that feels safe at night.",
	"sports_field": "Fun for the active ones.",
	"lake_slide": "Fun, and a quick wash on the way down.",
	"sewer": "The toilets and showers drain here. Somebody has to clean it.",
	"bench": "A seat by the path. The old ones love it.",
	"picnic_table": "Bread, salami and a beer in the open.",
	"flower_bed": "Pretty. The cabins round it feel nicer.",
	"gnome": "Kitsch. Guests smile at it. Mostly.",
	"mega_gnome": "As tall as a cabin. Registered copies only.",
	"flagpole": "The camp's flag. It looks like a real camp now.",
	"playground": "Swings and a seesaw. Families will thank you.",
	"ping_pong": "A table, two bats and an argument.",
	"hammock": "One guest, one book, one hour of peace.",
	"corn_stand": "Boiled corn with butter and salt, and a cup of kofola. Cheap, quick, everybody wants one.",
	"path": "Drag to lay a path. Guests walk on paths.",
	"lamp_post": "Light at night. A lit path is a safe path.",
	"demolish": "Drag over trees or buildings, then click inside to clear them.",
}

const TOOLS := ["demolish", "path", "lamp_post"]
const TOOLBAR_H := 40
const CATALOGUE_H := 64
const PROGRESS = preload("res://scripts/os98/os_progress.gd")
const TICKER = preload("res://scripts/builder/ticker.gd")
const TICKER_H := 17
## Builder's own clicks (ElevenLabs, tools/audiogen/prompts_builder.tsv): every button,
## card, window and tool has its sound, as in RCT and Theme Hospital.
const UI_SFX := "res://assets/sfx/builder/ui_%s.mp3"
## Builder's own title picture (Grok, tools/artgen: bld_splash), shown while it loads.
const SPLASH_TEX := "res://assets/textury/builder/splash.png"
const SPLASH_SEC := 2.2
const SPLASH_LINES := ["Reading the site plan...", "Counting the trees...", "Measuring the lake...", "Checking the licence..."]

var _grid_manager
var _building_manager
var _map_panel: Control
var _toolbar: Control
var _catalogue: Control
var _cards: HBoxContainer
var _status_msg: Label
var _status_tile: Label
var _status_cost: Label
var _money: Label
## The cash as a 1998 odometer: the shown sum rolls to the camp's money, its digits
## turning over one into the next (green coming in, red going out).
var _odo: Control
var _odo_v := -1.0
var _odo_flash := 0.0
var _odo_dir := 0
## Coins flying from the building that earned them to the cash (guests paying for their
## rooms, the businesses' takings): {from, t, life} on a layer over everything.
const COIN_TEX := "res://assets/textury/builder/coin.png"
var _coin_tex: Texture2D = load(COIN_TEX) if ResourceLoader.exists(COIN_TEX) else null
var _coin_layer: Control
var _coins: Array = []
var _coin_cd := 0.0
var _coin_scan := 0.0
var _takings_seen: Dictionary = {}
var _paid: Dictionary = {}       # coord -> amount waiting to fly (batched)
## Builder's own tune (a General MIDI loop, assets/sfx/builder/music.ogg): toward the
## evening and on a bad night's eve it goes a little flat and slow.
const MUSIC := "res://assets/sfx/builder/music.ogg"
const MUSIC_DB := -19.0
## The tool in hand on the pointer over the map (os_shell.tool_cursor).
const TOOL_CURSORS := {
	"demolish": "res://assets/textury/builder/tb2_bulldoze.png",
	"path": "res://assets/textury/builder/tb2_path.png",
	"lamp_post": "res://assets/textury/builder/tb2_lamp.png",
	"": "",
	"*": "res://assets/textury/builder/cur_blueprint.png",
}
var _cursor_tex: Dictionary = {}
var _music: AudioStreamPlayer
var _music_btn: Button
var _music_t := 0.0
var _clock: Label
var _tool_buttons: Dictionary = {}
var _cat_buttons: Dictionary = {}
var _active_cat := ""
var _selected := ""
var _icon_cache: Dictionary = {}
var _sfx: AudioStreamPlayer
var _tick := 0.0
var _splash: Control
var _splash_t := -1.0
var _splash_bar
var _cat_open := 0.0          # 0..1, the catalogue sliding open
var _info: Control            # the card for what is selected
var _hover_card := ""
var _overlay_btn: Button
## The view has been put on the camp once (it is the player's to move after that).
var camp_focused := false
## The building card: what a clicked building is and what can be done about it.
var _inspect: Control
var _insp: Dictionary = {}     # {type, origin, footprint, root} from the map
var _insp_view: Dictionary = {} # what the card shows, worked out on refresh
var _insp_btns: Dictionary = {}
## The message line at the foot of the map (scripts/builder/ticker.gd).
var _ticker: Control
var _ui_players: Dictionary = {}
var _deny_cd := 0.0
## The map's own sound under the pointer (crt_map_panel.sound_under_pointer): the lake,
## the woods, the playground, a pub, the camp; a quiet loop each, crossfading as the
## pointer goes over the map, from the PC's speaker.
const AMB_DB := -26.0
var _amb: Dictionary = {}
var _amb_kind := ""
var _amb_t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	theme = T.get_theme()
	_build_ui()
	EventBus.money_changed.connect(_on_money_changed)
	_refresh_info()


func _on_money_changed(_amount: int) -> void:
	_refresh_info()


func setup(grid_mgr, building_mgr) -> void:
	_grid_manager = grid_mgr
	_building_manager = building_mgr
	if _map_panel != null:
		_map_panel.setup(_grid_manager, _building_manager)
		_map_panel.view_rot = int(_shell_stored("builder_view", 1))
	_refresh_info()


func focus_map() -> void:
	if _map_panel != null:
		_map_panel.call_deferred("grab_focus")


func set_day_mode(_is_day: bool) -> void:
	pass   # the shell closes Builder at nightfall


# ── layout ───────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_menu()
	_build_toolbar()
	_build_catalogue()
	_map_panel = MAP_PANEL_SCRIPT.new()
	add_child(_map_panel)
	_map_panel.status_changed.connect(_on_status)
	_map_panel.tool_canceled.connect(func(): _select(""))
	_map_panel.submenu_close_requested.connect(func(): _open_category(""))
	_map_panel.hover_info.connect(func(t: String): _status_tile.text = t)
	_map_panel.building_clicked.connect(_on_building_clicked)
	_map_panel.guest_clicked.connect(_on_guest_clicked)
	if EventBus.has_signal("BuildConfirmed"):
		EventBus.BuildConfirmed.connect(_on_build_for_nag)
	_build_status()
	_ticker = TICKER.new()
	add_child(_ticker)
	add_child(_ticker.popup)
	_ticker.go_to.connect(_go_to)
	_ticker.follow.connect(func(id: int):
		_ui("open")
		_on_guest_clicked(id)
		_following = true
		_follow_btn.set_pressed_no_signal(true))
	_build_info()
	_build_inspector()
	_build_guest_card()
	_build_splash()
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if _map_panel == null:
		return
	var y := 20.0
	_toolbar.position = Vector2(0, y)
	_toolbar.size = Vector2(size.x, TOOLBAR_H)
	y += TOOLBAR_H
	_catalogue.visible = not _active_cat.is_empty()
	if _catalogue.visible:
		# It slides open in a few steps (the map moves down with it).
		var hh := floorf(CATALOGUE_H * (ceilf(_cat_open * 4.0) / 4.0))
		_catalogue.position = Vector2(0, y)
		_catalogue.size = Vector2(size.x, hh)
		_catalogue.clip_contents = true
		y += hh
	var well: Control = get_node("MapWell")
	well.position = Vector2(0, y)
	well.size = Vector2(size.x, size.y - y - 20 - TICKER_H)
	if _ticker != null:
		_ticker.position = Vector2(0, well.position.y + well.size.y)
		_ticker.size = Vector2(size.x, TICKER_H)
		_ticker.popup.position = well.position + Vector2(8, 8)
	_map_panel.position = well.position + Vector2(2, 2)
	_map_panel.size = well.size - Vector2(4, 4)
	var bar: Control = get_node("StatusBar")
	bar.position = Vector2(0, size.y - 18)
	bar.size = Vector2(size.x, 18)
	var w := size.x
	_status_msg.get_parent().size = Vector2(w - 290, 18)
	_status_tile.get_parent().position = Vector2(w - 288, 0)
	_status_cost.get_parent().position = Vector2(w - 110, 0)
	if _info != null:
		_info.position = Vector2(well.position.x + 8, well.position.y + well.size.y - _info.size.y - 8)
	if _inspect != null:
		_inspect.position = Vector2(well.position.x + well.size.x - _inspect.size.x - 8, well.position.y + well.size.y - _inspect.size.y - 8)
	if _gcard != null:
		_gcard.position = Vector2(well.position.x + well.size.x - _gcard.size.x - 8, well.position.y + well.size.y - _gcard.size.y - 8)
	if _splash != null:
		_splash.size = size
		if _splash_bar != null:
			_splash_bar.position = Vector2(floorf(size.x * 0.5 - 120), size.y - 46)
			_splash_bar.size = Vector2(240, 14)


func _build_menu() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(2, 1)
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	var menus := {
		"File": ["Site report", "New site...", "-", "Exit"],
		"View": ["Zoom in", "Zoom out", "Rotate building  (Q)", "Turn the view  (T)", "-", "Overlay: off", "Overlay: wear", "Overlay: power", "Overlay: rooms", "Overlay: light at night"],
		"Help": ["Keys", "Help topics", "Register...", "-", "About Builder 98"],
	}
	for name in menus:
		var b := MenuButton.new()
		b.text = name
		b.flat = true
		b.switch_on_hover = true
		var pm := b.get_popup()
		for entry in menus[name]:
			if entry == "-":
				pm.add_separator()
			else:
				pm.add_item(entry)
		pm.index_pressed.connect(func(i: int): _menu(pm.get_item_text(i)))
		row.add_child(b)


func _menu(item: String) -> void:
	match item:
		"Exit":
			exit_requested.emit()
		"Zoom in":
			_map_panel.apply_zoom_step(1)
		"Zoom out":
			_map_panel.apply_zoom_step(-1)
		"Rotate building  (Q)":
			_map_panel.rotate_selected_building(1)
		"Turn the view  (T)":
			turn_view(1)
		"Site report":
			message_requested.emit("Site report", _site_report(), "info")
		"New site...":
			message_requested.emit("Builder 98", "The shareware version plans one site only.\n\nRegistered copies too: one camp, one site.", "info")
		"Overlay: off":
			_set_overlay("")
		"Overlay: wear":
			_set_overlay("condition")
		"Overlay: power":
			_set_overlay("power")
		"Overlay: rooms":
			_set_overlay("rooms")
		"Overlay: light at night":
			_set_overlay("light")
		"Keys":
			message_requested.emit("Builder 98 - Keys", "B  bulldozer        P  path        L  lamp\nF1 housing   F2 services   F3 fun   F4 decor   F5 utilities\nQ / E  turn the building     T  turn the view     X  put the tool away\nO  overlay (wear, power, rooms, light)\nArrows  move the map     +/-  zoom     Ctrl+Z  undo today's build\n\nNo tool in hand: click a building for its card.", "info")
		"Help topics":
			message_requested.emit("Builder 98 Help", "Cannot open BUILDER.HLP.\n\nThe file is missing or damaged.\n\n(Help > Keys still works.)", "error")
		"Register...":
			_register_dialog()
		"About Builder 98":
			_about_dialog()


func _build_toolbar() -> void:
	_toolbar = Panel.new()
	_toolbar.add_theme_stylebox_override("panel", T.box("thin_raised", T.FACE, Vector4.ZERO))
	add_child(_toolbar)
	var row := HBoxContainer.new()
	row.position = Vector2(4, 3)
	row.add_theme_constant_override("separation", 2)
	_toolbar.add_child(row)
	var tool_keys := {"demolish": "B", "path": "P", "lamp_post": "L"}
	for id in TOOLS:
		var b := _tool_button(_tool_art(id), "%s  (%s)\n%s" % [SHORT_NAMES[id], tool_keys.get(id, ""), BLURBS[id]])
		var tool: String = id
		b.pressed.connect(func():
			_open_category("")
			_select("" if _selected == tool else tool)
		)
		_tool_buttons[id] = b
		row.add_child(b)
	row.add_child(_gap())
	var fk := 1
	for cat in CATEGORIES:
		var cat_icon := _texture(str(cat["icon"]).replace("/tb_", "/tb2_"))
		var b := _tool_button(cat_icon if cat_icon != null else _texture(str(cat["icon"])), "%s  (F%d)" % [str(cat["label"]), fk])
		fk += 1
		var cid: String = cat["id"]
		b.pressed.connect(func(): _open_category("" if _active_cat == cid else cid))
		_cat_buttons[cid] = b
		row.add_child(b)
	row.add_child(_gap())
	var rot := Button.new()
	rot.tooltip_text = "Turn the building (Q / E)"
	rot.custom_minimum_size = Vector2(36, 34)
	rot.focus_mode = Control.FOCUS_NONE
	rot.icon = _texture("res://assets/textury/builder/tb2_rotate.png")
	if rot.icon == null:
		rot.text = "Rotate"
	rot.expand_icon = true
	rot.add_theme_constant_override("icon_max_width", 26)
	_flat_style(rot)
	rot.pressed.connect(func(): _map_panel.rotate_selected_building(1))
	row.add_child(rot)
	# The whole map a quarter round (T, Shift+T back), as RCT turned its park.
	var turn := Button.new()
	turn.tooltip_text = "Turn the view (T)"
	turn.custom_minimum_size = Vector2(36, 34)
	turn.focus_mode = Control.FOCUS_NONE
	turn.icon = _texture("res://assets/textury/builder/tb2_view.png")
	if turn.icon == null:
		turn.text = "View"
	turn.expand_icon = true
	turn.add_theme_constant_override("icon_max_width", 26)
	_flat_style(turn)
	turn.pressed.connect(func(): turn_view(1))
	row.add_child(turn)
	var undo := Button.new()
	undo.icon = _tool_icon("undo")
	undo.expand_icon = true
	undo.add_theme_constant_override("icon_max_width", 24)
	undo.tooltip_text = "Take back the last thing you built today (Ctrl+Z), money back"
	undo.custom_minimum_size = Vector2(36, 34)
	undo.focus_mode = Control.FOCUS_NONE
	undo.add_theme_font_override("font", T.FONT_BOLD)
	_flat_style(undo)
	undo.pressed.connect(func(): _map_panel.undo_last())
	row.add_child(undo)
	for z in [["-", -1, "Zoom out (-)"], ["+", 1, "Zoom in (+)"]]:
		var zb := Button.new()
		zb.icon = _tool_icon("zoom_out" if int(z[1]) < 0 else "zoom_in")
		zb.expand_icon = true
		zb.add_theme_constant_override("icon_max_width", 24)
		zb.tooltip_text = z[2]
		zb.custom_minimum_size = Vector2(32, 34)
		zb.focus_mode = Control.FOCUS_NONE
		zb.add_theme_font_override("font", T.FONT_BOLD)
		_flat_style(zb)
		var step: int = z[1]
		zb.pressed.connect(func(): _map_panel.apply_zoom_step(step))
		row.add_child(zb)
	row.add_child(_gap())
	# What the map shows over the camp: off, wear, power, rooms, light (O).
	_overlay_btn = Button.new()
	_overlay_btn.custom_minimum_size = Vector2(36, 34)
	_overlay_btn.toggle_mode = true
	_overlay_btn.icon = _tool_icon("map")
	_overlay_btn.expand_icon = true
	_overlay_btn.add_theme_constant_override("icon_max_width", 24)
	_overlay_btn.focus_mode = Control.FOCUS_NONE
	_overlay_btn.tooltip_text = "Show on the map: wear, power, rooms, light at night (O)"
	_overlay_btn.text = ""
	_flat_style(_overlay_btn)
	_overlay_btn.pressed.connect(func():
		_click()
		_set_overlay(str(_map_panel.OVERLAYS[(_map_panel.OVERLAYS.find(_map_panel.overlay) + 1) % _map_panel.OVERLAYS.size()])))
	row.add_child(_overlay_btn)
	# The music on and off (remembered by the PC).
	_music_btn = Button.new()
	_music_btn.focus_mode = Control.FOCUS_NONE
	_music_btn.custom_minimum_size = Vector2(36, 34)
	_music_btn.expand_icon = true
	_music_btn.add_theme_constant_override("icon_max_width", 26)
	_music_btn.tooltip_text = "Music"
	_music_btn.icon = _music_icon(bool(_shell_stored("builder_music_off", false)))
	if _music_btn.icon == null:
		_music_btn.text = "Music"
	_flat_style(_music_btn)
	_music_btn.pressed.connect(func():
		_click()
		_toggle_music())
	row.add_child(_music_btn)
	# The Graphs window (G).
	var gb := Button.new()
	gb.focus_mode = Control.FOCUS_NONE
	gb.custom_minimum_size = Vector2(36, 34)
	gb.expand_icon = true
	gb.add_theme_constant_override("icon_max_width", 26)
	gb.tooltip_text = "Graphs  (G)"
	gb.icon = _texture("res://assets/textury/builder/tb2_graphs.png")
	if gb.icon == null:
		gb.text = "Graphs"
	_flat_style(gb)
	gb.pressed.connect(func():
		_click()
		toggle_graphs())
	row.add_child(gb)
	# Cash and clock, right-aligned in sunken wells.
	var cash := Panel.new()
	cash.name = "Cash"
	cash.add_theme_stylebox_override("panel", T.box("field", Color8(0, 0, 0), Vector4.ZERO))
	_toolbar.add_child(cash)
	_money = Label.new()
	_money.add_theme_font_override("font", T.FONT_BOLD)
	_money.add_theme_color_override("font_color", Color8(80, 255, 80))
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money.visible = false
	cash.add_child(_money)
	_odo = Control.new()
	_odo.clip_contents = true
	_odo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_odo.draw.connect(_draw_odo)
	cash.add_child(_odo)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toolbar.add_child(_clock)
	_toolbar.resized.connect(func():
		cash.position = Vector2(_toolbar.size.x - 94, 4)
		cash.size = Vector2(90, 18)
		_money.position = Vector2(4, 2)
		_money.size = Vector2(80, 14)
		_odo.position = Vector2(3, 2)
		_odo.size = Vector2(84, 14)
		_clock.position = Vector2(_toolbar.size.x - 150, 23)
		_clock.size = Vector2(146, 14)
	)


func _gap() -> Control:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(6, 34)
	return s


func _tool_button(icon: Texture2D, tip: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(36, 34)
	b.icon = icon
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.add_theme_constant_override("icon_max_width", 28)
	_flat_style(b)
	return b


## The cool-toolbar look: nothing until the mouse is on it, then a thin bevel; sunk
## while on.
func _flat_style(b: Button) -> void:
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", T.box("thin_raised", T.FACE, Vector4(2, 2, 2, 2)))
	b.add_theme_stylebox_override("pressed", T.box("well", Color8(214, 214, 214), Vector4(3, 3, 1, 1)))
	b.add_theme_stylebox_override("hover_pressed", T.box("well", Color8(214, 214, 214), Vector4(3, 3, 1, 1)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _build_catalogue() -> void:
	_catalogue = Panel.new()
	_catalogue.add_theme_stylebox_override("panel", T.box("thin_raised", T.FACE, Vector4.ZERO))
	_catalogue.visible = false
	add_child(_catalogue)
	_cards = HBoxContainer.new()
	_cards.position = Vector2(4, 3)
	_cards.add_theme_constant_override("separation", 3)
	_catalogue.add_child(_cards)
	var well := Panel.new()
	well.name = "MapWell"
	well.add_theme_stylebox_override("panel", T.box("field", Color8(0, 0, 0), Vector4.ZERO))
	add_child(well)


func _build_status() -> void:
	var bar := Panel.new()
	bar.name = "StatusBar"
	bar.add_theme_stylebox_override("panel", T.flat(T.FACE, Vector4.ZERO))
	add_child(bar)
	_status_msg = _status_cell(bar, Vector2(0, 0), 300)
	_status_tile = _status_cell(bar, Vector2(0, 0), 176)
	_status_cost = _status_cell(bar, Vector2(0, 0), 108)
	_status_msg.text = "Ready"


func _status_cell(bar: Control, pos: Vector2, w: float) -> Label:
	var well := Panel.new()
	well.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4.ZERO))
	well.position = pos
	well.size = Vector2(w, 18)
	well.clip_contents = true
	bar.add_child(well)
	var l := Label.new()
	l.position = Vector2(4, 2)
	l.size = Vector2(w - 8, 14)
	l.clip_text = true
	well.add_child(l)
	return l


# ── tools ────────────────────────────────────────────────────────────────────

func _open_category(cid: String) -> void:
	if cid != _active_cat:
		_ui("card" if cid != "" else "close")
	_active_cat = cid
	for k in _cat_buttons:
		_cat_buttons[k].set_pressed_no_signal(k == cid)
	for c in _cards.get_children():
		c.queue_free()
	if not cid.is_empty():
		_cat_open = 0.0
		for cat in CATEGORIES:
			if cat["id"] == cid:
				var n: int = (cat["items"] as Array).size()
				var avail := maxf(200.0, size.x - 8.0)
				var w := clampi(int(floor((avail - 3.0 * float(n - 1)) / float(maxi(1, n)))), CARD_MIN_W, CARD_W)
				var i := 0
				for t in cat["items"]:
					var card := _make_card(str(t), w)
					card.set_meta("appear", 0.06 * float(i))
					card.modulate.a = 0.0
					_cards.add_child(card)
					i += 1
	_layout()


func _click() -> void:
	_ui("button")


## One of Builder's own sounds (button, card, open, close, tool, deny), from the PC's
## speaker: as loud as the room has it (os_shell.sound_db).
func _ui(id: String, db := -10.0) -> void:
	var path := UI_SFX % id
	if not ResourceLoader.exists(path):
		path = "res://assets/sfx/os98/click.mp3"
	var p: AudioStreamPlayer = _ui_players.get(id)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = load(path)
		add_child(p)
		_ui_players[id] = p
	var shell = _shell_node()
	var room := float(shell.call("sound_db")) if shell != null and shell.has_method("sound_db") else 0.0
	if room <= -60.0:
		return
	p.volume_db = db + room
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()


## The map to a place (the message line's click): there, and its card if it has one.
func _go_to(coord: Vector2i) -> void:
	_ui("open")
	_map_panel.debug_center_on(coord)
	var info: Dictionary = _map_panel.structure_at(coord)
	if not info.is_empty():
		_on_building_clicked(info)
		_map_panel.inspect_origin = info.get("origin", Vector2i(-1, -1))
		_map_panel.inspect_footprint = info.get("footprint", Vector2i.ONE)


## The camp's Goggle rating has not opened this blueprint yet: the stars and reviews it
## needs ({} when it is open).
func _locked(type: String) -> Dictionary:
	if type == "mega_gnome":
		_ensure_sw()
		return {} if _sw != null and _sw.unlocked(type) else {"registered": true}
	var main := get_tree().current_scene if get_tree() != null else null
	var g = main.get("_goggle") if main != null else null
	if g == null or type == "" or g.unlocked(type):
		return {}
	return g.TIERS[g.tier_of(type)]


func _select(tool: String) -> void:
	var lock := _locked(tool)
	if lock.has("registered"):
		message_requested.emit("Builder 98", "The Mega gnome comes with registered copies of Builder 98.\n\nHelp > Register...", "info")
		return
	if not lock.is_empty():
		message_requested.emit("Builder 98", "This blueprint is for Stavitel partner camps.\n\nIt opens when your camp has %d guests at once." % int(lock["guests"]), "info")
		return
	_ui("tool" if tool != "" else "button")
	_selected = tool
	if tool != "" and not _insp.is_empty():
		_close_inspector()
	for k in _tool_buttons:
		_tool_buttons[k].set_pressed_no_signal(k == tool)
	for c in _cards.get_children():
		c.queue_redraw()
	_map_panel.set_selected_building(tool)
	if not tool.is_empty():
		_map_panel.call_deferred("grab_focus")
	_refresh_cost()
	_refresh_info_card()


func _set_overlay(id: String) -> void:
	_map_panel.set_overlay(id)
	if _overlay_btn != null:
		_overlay_btn.set_pressed_no_signal(_map_panel.overlay != "")
		_overlay_btn.tooltip_text = "Map overlay: %s  (O for the next)" % OVERLAY_SHORT.get(_map_panel.overlay, "Off")


## The keys, while Builder is on the screen (and not under its title picture).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _splash != null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var k: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if event.ctrl_pressed or event.alt_pressed:
		return
	if k >= KEY_A and k <= KEY_Z:
		_cheat_key(char(k))
	if CATEGORY_KEYS.has(event.keycode):
		var cid := str(CATEGORY_KEYS[event.keycode])
		_open_category("" if _active_cat == cid else cid)
	elif TOOL_KEYS.has(k):
		var tool := str(TOOL_KEYS[k])
		_open_category("")
		_select("" if _selected == tool else tool)
	elif k == KEY_O:
		_click()
		_set_overlay(str(_map_panel.OVERLAYS[(_map_panel.OVERLAYS.find(_map_panel.overlay) + 1) % _map_panel.OVERLAYS.size()]))
	elif k == KEY_G:
		_click()
		toggle_graphs()
	elif k == KEY_T:
		turn_view(-1 if event.shift_pressed else 1)
	elif k == KEY_X or k == KEY_DELETE or k == KEY_BACKSPACE:
		if _selected != "":
			_select("")
		elif not _insp.is_empty():
			_close_inspector()
		elif _active_cat != "":
			_open_category("")
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


# ── the building card ────────────────────────────────────────────────────────

const INSP_SIZE := Vector2(282, 150)


func _build_inspector() -> void:
	_inspect = Control.new()
	_inspect.size = INSP_SIZE
	_inspect.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspect.visible = false
	_inspect.draw.connect(_draw_inspector)
	add_child(_inspect)
	var defs := [["upgrade", "Upgrade"], ["crew", "Send the crew"], ["demolish", "Demolish"], ["rack", "GuestRack"], ["lamp", "Put a lamp here"]]
	for i in defs.size():
		var b := Button.new()
		b.text = str(defs[i][1])
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(6 + (i % 2) * 136, INSP_SIZE.y - 50 + (i / 2) * 24)
		b.size = Vector2(134, 22)
		var id := str(defs[i][0])
		b.pressed.connect(func(): _insp_action(id))
		_inspect.add_child(b)
		_insp_btns[id] = b
	var close := Button.new()
	close.text = "x"
	close.focus_mode = Control.FOCUS_NONE
	close.position = Vector2(INSP_SIZE.x - 21, 4)
	close.size = Vector2(16, 14)
	close.pressed.connect(_close_inspector)
	_inspect.add_child(close)


func _on_building_clicked(info: Dictionary) -> void:
	_close_guest_card()
	if not info.is_empty():
		_ui("open")
	elif not _insp.is_empty():
		_ui("close")
	_insp = info
	_inspect.visible = not info.is_empty()
	if _inspect.visible:
		_refresh_inspector()
		_layout()


func _close_inspector() -> void:
	if not _insp.is_empty():
		_ui("close")
	_insp = {}
	_inspect.visible = false
	_map_panel.inspect_origin = Vector2i(-1, -1)


func _main() -> Node:
	var tree := get_tree()
	return tree.current_scene if tree != null else null


# ── the guest card ───────────────────────────────────────────────────────────

## A guest clicked on the map: their name, their party and room, how they are (six needs,
## the mood), what they last thought (theirs; now and then one that is not quite right);
## Follow keeps them in the middle of the map.
const GCARD_SIZE := Vector2(282, 150)
const NEED_SHORT := [["energy", "Sleep"], ["hunger", "Food"], ["bladder", "WC"], ["hygiene", "Wash"], ["fun", "Fun"], ["safety", "Safe"]]
const ODD_THOUGHTS := [
	"The lake looked at me.", "Someone sat on my bed while I was out.", "The boy in the red shoes asked for me.",
	"There is one more tent than yesterday.", "Who whistles out there at night?", "I counted the lamps twice. Not the same.",
	"The man at the desk wrote my name before I said it.",
]
var _gcard: Control
var _gcard_id := -1
var _gcard_odd := ""
var _following := false
var _follow_btn: Button


func _build_guest_card() -> void:
	_gcard = Control.new()
	_gcard.size = GCARD_SIZE
	_gcard.mouse_filter = Control.MOUSE_FILTER_STOP
	_gcard.visible = false
	_gcard.draw.connect(_draw_guest_card)
	add_child(_gcard)
	_follow_btn = Button.new()
	_follow_btn.text = "Follow"
	_follow_btn.toggle_mode = true
	_follow_btn.focus_mode = Control.FOCUS_NONE
	_follow_btn.position = Vector2(GCARD_SIZE.x - 82, GCARD_SIZE.y - 28)
	_follow_btn.size = Vector2(76, 22)
	_follow_btn.toggled.connect(func(on: bool):
		_click()
		_following = on)
	_gcard.add_child(_follow_btn)
	var close := Button.new()
	close.text = "x"
	close.focus_mode = Control.FOCUS_NONE
	close.position = Vector2(GCARD_SIZE.x - 21, 4)
	close.size = Vector2(16, 14)
	close.pressed.connect(_close_guest_card)
	_gcard.add_child(close)


func _on_guest_clicked(id: int) -> void:
	_close_inspector()
	_gcard_id = id
	_following = false
	_follow_btn.set_pressed_no_signal(false)
	# Now and then what they think is not quite right: more so when they are frightened.
	_gcard_odd = ""
	var g := _guest_row(id)
	var safe := float((g.get("needs", {}) as Dictionary).get("safety", 100.0))
	if randf() < (0.3 if safe < 40.0 else 0.04):
		_gcard_odd = str(ODD_THOUGHTS[randi() % ODD_THOUGHTS.size()])
	_gcard.visible = true
	_gcard.queue_redraw()
	_layout()


func _close_guest_card() -> void:
	if _gcard_id >= 0:
		_ui("close")
	_gcard_id = -1
	_following = false
	if _gcard != null:
		_gcard.visible = false


func _guest_row(id: int) -> Dictionary:
	if GuestManager == null or not GuestManager.has_method("get_guest_life_snapshot"):
		return {}
	for g in GuestManager.get_guest_life_snapshot():
		if g is Dictionary and int(g.get("id", -2)) == id:
			return g
	return {}


func _tick_guest_card(delta: float) -> void:
	if _gcard == null or not _gcard.visible:
		return
	if _following and not _map_panel.follow_guest(_gcard_id, delta):
		_following = false
		_follow_btn.set_pressed_no_signal(false)
	_gcard_t -= delta
	if _gcard_t <= 0.0:
		_gcard_t = 0.5
		if _guest_row(_gcard_id).is_empty():
			_close_guest_card()
		else:
			_gcard.queue_redraw()


var _gcard_t := 0.0
var _gcard_face: Dictionary = {}


func _draw_guest_card() -> void:
	var c := _gcard
	var s := c.size
	var g := _guest_row(_gcard_id)
	c.draw_style_box(T.box("window", T.FACE), Rect2(Vector2.ZERO, s))
	var band := Rect2(3, 3, s.x - 6, 17)
	for i in int(ceil(band.size.x / 8.0)):
		c.draw_rect(Rect2(band.position.x + i * 8, band.position.y, minf(8.0, band.size.x - i * 8), band.size.y), T.TITLE_A.lerp(T.TITLE_B, float(i * 8) / band.size.x))
	if g.is_empty():
		return
	var party := int(g.get("party_size", 1))
	var title := str(g.get("name", "Guest")) + ("  and %d more" % (party - 1) if party > 1 else "")
	c.draw_string(T.FONT_BOLD, band.position + Vector2(4, 13), title, HORIZONTAL_ALIGNMENT_LEFT, s.x - 40, T.FONT_SIZE, T.WHITE)
	# Their face: the top of their figure.
	var face := _guest_face(str(g.get("sprite_path", "")))
	c.draw_rect(Rect2(6, 24, 50, 50), Color8(40, 56, 40))
	if face != null:
		c.draw_texture_rect(face, Rect2(8, 26, 46, 46), false)
	var x := 62.0
	var y := 36.0
	var room := ""
	var lodg = g.get("lodging", null)
	if lodg is Vector2i and (lodg as Vector2i).x >= 0 and GuestManager != null:
		room = GuestManager.room_label("%d:%d" % [lodg.x, lodg.y])
	c.draw_string(T.FONT, Vector2(x, y), room if room != "" else "No room", HORIZONTAL_ALIGNMENT_LEFT, s.x - x - 26, T.FONT_SIZE, Color8(60, 60, 110))
	c.draw_string(T.FONT_BOLD, Vector2(x, y + 14), str(g.get("mood_label", "")), HORIZONTAL_ALIGNMENT_LEFT, s.x - x - 8, T.FONT_SIZE, Color8(40, 70, 170))
	# Six needs, two columns of little bars.
	var needs: Dictionary = g.get("needs", {})
	for i in NEED_SHORT.size():
		var nx := x + float(i % 2) * 106.0
		var ny := y + 24.0 + float(i / 2) * 13.0
		var v := clampf(float(needs.get(NEED_SHORT[i][0], 100.0)) / 100.0, 0.0, 1.0)
		c.draw_string(T.FONT, Vector2(nx, ny + 9), str(NEED_SHORT[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.SHADOW)
		var bar := Rect2(nx + 34, ny + 1, 62, 8)
		c.draw_rect(bar, Color8(60, 60, 60))
		var col := Color8(40, 170, 40) if v > 0.6 else (Color8(220, 160, 0) if v > 0.3 else Color8(200, 30, 20))
		c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * v), bar.size.y)), col)
	# What they last thought.
	var thought := _gcard_odd if _gcard_odd != "" else str(g.get("thought", ""))
	if thought != "":
		T.FONT.draw_multiline_string(c.get_canvas_item(), Vector2(8, s.y - 36), char(34) + thought + char(34), HORIZONTAL_ALIGNMENT_LEFT, s.x - 96, T.FONT_SIZE, 2, Color8(70, 50, 30))


func _guest_face(path: String) -> Texture2D:
	if _gcard_face.has(path):
		return _gcard_face[path]
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		var src := (load(path) as Texture2D).get_image().duplicate() as Image
		if src.is_compressed():
			src.decompress()
		var used := src.get_used_rect()
		var side := mini(used.size.x, int(used.size.y * 0.34))
		var crop := src.get_region(Rect2i(used.position.x + (used.size.x - side) / 2, used.position.y, side, side))
		crop.resize(46, 46, Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(crop)
	_gcard_face[path] = tex
	return tex


## What the card says about the building now: worked out twice a second while it is up.
func _refresh_inspector() -> void:
	if _insp.is_empty() or _inspect == null:
		return
	var root = _insp.get("root")
	if root == null or not is_instance_valid(root):
		_close_inspector()
		return
	var t := str(_insp["type"])
	var o: Vector2i = _insp["origin"]
	var fp: Vector2i = _insp.get("footprint", Vector2i.ONE)
	var def = CoreRoot.registry.get_def(StringName(t)) if CoreRoot.registry != null else null
	var key := "%d:%d" % [o.x, o.y]
	var v := {"title": _nice_type(t, def), "sub": "", "lines": [], "icon": _texture(str(ITEM_ICONS.get(_base_type(t), ""))), "type": t}
	var lines: Array = []
	var m := _main()
	# Lodgings: the room, who is in it, how many beds, what is still to do.
	var lodging := t.begins_with("tent") or t.begins_with("cabin") or t.begins_with("caravan")
	if lodging and GuestManager != null:
		v["sub"] = GuestManager.room_label(key)
		var rs: Dictionary = GuestManager.get_room_state(key)
		var st := str(rs.get("status", ""))
		var who := _guests_in(key)
		var beds := int(def.capacity) if def != null else 0
		if bool(rs.get("occupied", false)) or not who.is_empty():
			lines.append(["Guests", "%s  (%d/%d)" % [", ".join(who.slice(0, 2)), who.size(), beds] if not who.is_empty() else "taken", Color8(40, 70, 170)])
		else:
			lines.append(["Room", {"ready": "ready, %d bed%s" % [beds, "" if beds == 1 else "s"], "dirty": "DIRTY: clean it", "unprepared": "not made up yet"}.get(st, st), Color8(0, 110, 0) if st == "ready" else Color8(170, 0, 0)])
	elif t == "path":
		# A path: whether it is lit; the lamp is put on it from here.
		var lit := bool(_insp.get("lamp", false))
		v["title"] = "Path with a lamp" if lit else "Path"
		v["icon"] = _tool_art("lamp_post" if lit else "path")
		v["sub"] = str(BLURBS["lamp_post" if lit else "path"])
		lines.append(["Light", "lit at night" if lit else "dark at night", Color8(0, 110, 0) if lit else Color8(150, 100, 0)])
	elif BLURBS.has(_base_type(t)):
		v["sub"] = str(BLURBS[_base_type(t)])
	# A toilet or shower block: how clean it is (the guests' use soils it).
	if t == "toilet_block" or t == "shower_block":
		var cell: Dictionary = CoreRoot.get_state().grid.cells.get(o, {})
		var clean := float(cell.get("maintenance", 1.0))
		lines.append(["Clean", "FILTHY" if clean < UPKEEP_RULES.FILTHY else "%d%%" % int(round(clean * 100.0)), Color8(170, 0, 0) if clean < UPKEEP_RULES.FILTHY else (Color8(150, 100, 0) if clean < 0.7 else Color8(0, 110, 0))])
	# A business: today in its books (what it took, how many it served).
	var biz: Dictionary = (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).get(key, {}) if CoreRoot.get_state().biz is Dictionary else {}
	if not biz.is_empty():
		var today: Dictionary = biz.get("today", {})
		lines.append(["Today", "$%d, %d served" % [int(today.get("takings", 0)), int(today.get("sold", 0))], Color8(0, 110, 0)])
	# Wear and repairs.
	var crew_cost := 0
	var worn := false
	if m != null and m.has_method("get_upkeep_snapshot"):
		for r in (m.get_upkeep_snapshot() as Dictionary).get("rows", []):
			if Vector2i(r["coord"]) == o:
				var cond := float(r.get("condition", 1.0))
				var broken := bool(r.get("broken", false))
				lines.append(["Condition", "BROKEN" if broken else "%d%%" % int(round(cond * 100.0)), Color8(170, 0, 0) if broken or cond < 0.5 else (Color8(150, 100, 0) if cond < UPKEEP_RULES.WORN_CONDITION else Color8(0, 110, 0))])
				v["cond"] = 0.0 if broken else cond
				worn = broken or cond < 0.999
				crew_cost = int(ceil(float(r.get("cost", 0)) * UPKEEP_RULES.CREW_PREMIUM))
				break
	# Power.
	if def != null and int(def.power_use) > 0 and m != null and m.has_method("get_electricity_ui_snapshot"):
		var kwh := 0.0
		for l in (m.get_electricity_ui_snapshot() as Dictionary).get("consumption_lines", []):
			if (l as Dictionary).get("coord", null) == o:
				kwh = float(l.get("kwh_per_day", 0.0))
		lines.append(["Power", "%.1f kWh a day" % kwh, Color8(150, 100, 0)])
	v["lines"] = lines
	_insp_view = v
	# The buttons.
	var im = m.get("_interior_manager") if m != null else null
	var up: Dictionary = im.map_upgrade_offer(o, t) if im != null and lodging and im.has_method("map_upgrade_offer") else {}
	var ub: Button = _insp_btns["upgrade"]
	ub.visible = lodging
	if not up.is_empty() and float(up.get("locked", 0.0)) > 0.0:
		ub.text = "Upgrade at %d guests" % int(up["locked"])
		ub.disabled = true
		ub.tooltip_text = "Opens when the camp has had %d guests at once" % int(up["locked"])
	elif not up.is_empty() and not bool(up.get("max", false)):
		ub.text = "Upgrade  $%d" % int(up["cost"])
		ub.disabled = CoreRoot.get_money() < int(up["cost"])
		ub.tooltip_text = "To %s" % str(up.get("label", ""))
	else:
		ub.text = "Top level"
		ub.disabled = true
	# The crew only where there is something for them (what wears: lamps, a derelict one).
	var cb: Button = _insp_btns["crew"]
	cb.visible = worn
	cb.text = "Send the crew  $%d" % crew_cost
	cb.disabled = CoreRoot.is_night() or CoreRoot.get_money() < crew_cost
	cb.tooltip_text = "The crew does not come out after dark." if CoreRoot.is_night() else ""
	var sum: Dictionary = CoreRoot.builder_authority.summarize_demolish(Rect2i(o, fp)) if CoreRoot.builder_authority != null and CoreRoot.builder_authority.has_method("summarize_demolish") else {}
	var db: Button = _insp_btns["demolish"]
	var net := int(sum.get("refund", 0)) - int(sum.get("fee", 0))
	db.text = "Demolish  %s$%d" % ["+" if net >= 0 else "-", absi(net)]
	db.disabled = int(sum.get("count", 0)) <= 0 or bool(root.get_meta("permanent", false))
	var rb: Button = _insp_btns["rack"]
	rb.visible = lodging
	var lb: Button = _insp_btns["lamp"]
	lb.visible = t == "path" and not bool(_insp.get("lamp", false))
	lb.text = "Put a lamp here  $%d" % _cost("lamp_post")
	lb.disabled = CoreRoot.get_money() < _cost("lamp_post")
	# The buttons that are there, two to a row from the bottom up, no gaps.
	var shown: Array = []
	for id in ["upgrade", "lamp", "crew", "rack", "demolish"]:
		if (_insp_btns[id] as Button).visible:
			shown.append(_insp_btns[id])
	var rows := int(ceil(float(shown.size()) / 2.0))
	# As tall as what it says and the buttons under it.
	var sub_h := 0.0
	if str(v.get("sub", "")) != "":
		sub_h = 14.0 if T.FONT.get_string_size(str(v["sub"]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x < INSP_SIZE.x - 70 else 27.0
	var text_bottom := maxf(78.0, 26.0 + sub_h + 14.0 * lines.size() + 6.0)
	var h := text_bottom + rows * 24 + 6
	if absf(_inspect.size.y - h) > 0.5:
		_inspect.size = Vector2(INSP_SIZE.x, h)
		_layout()
	for i in shown.size():
		var b: Button = shown[i]
		var row := i / 2
		b.position = Vector2(6 + (i % 2) * 136, h - 6 - (rows - row) * 24)
	_inspect.queue_redraw()


func _base_type(t: String) -> String:
	for b in ["tent", "cabin", "caravan"]:
		if t.begins_with(b):
			return b + "_1"
	return t


func _nice_type(t: String, def) -> String:
	var name := str(SHORT_NAMES.get(_base_type(t), def.display_name.split(" (")[0] if def != null else t))
	var lv := t.get_slice("_", 1)
	if (t.begins_with("tent") or t.begins_with("cabin") or t.begins_with("caravan")) and lv.is_valid_int():
		name += "  Lv%s" % lv
	return name


## The names of the guests sleeping in a room (by their lodging slots).
func _guests_in(key: String) -> Array:
	var out: Array = []
	var state = CoreRoot.get_state()
	if state == null:
		return out
	for g in state.guests:
		if not (g is Dictionary) or not (str(g.get("status", "")) in ["active", "sleep"]):
			continue
		for s in g.get("lodging_slots", []):
			if s is Dictionary and str(s.get("accommodation_key", "")) == key:
				out.append(str(g.get("name", "Guest")).split(" ")[0])
				break
	return out


func _insp_action(id: String) -> void:
	if _insp.is_empty():
		return
	var t := str(_insp["type"])
	var o: Vector2i = _insp["origin"]
	var fp: Vector2i = _insp.get("footprint", Vector2i.ONE)
	var m := _main()
	_click()
	match id:
		"upgrade":
			var im = m.get("_interior_manager") if m != null else null
			if im != null and im.map_upgrade(o, t):
				_map_panel._add_fx("pop", Vector2(o), 1.4, "UPGRADED", Color8(255, 220, 80))
				_map_panel._play("money", -8.0)
				# The building is a new node now: the card follows it.
				(func():
					var again: Dictionary = _map_panel.structure_at(o)
					_on_building_clicked(again)
					_map_panel.inspect_origin = again.get("origin", Vector2i(-1, -1))
					_map_panel.inspect_footprint = again.get("footprint", Vector2i.ONE)
				).call_deferred()
			else:
				message_requested.emit("Builder 98", "The upgrade could not be done.\n\nThe camp has $%d." % CoreRoot.get_money(), "error")
		"crew":
			var res: Dictionary = m.request_maintenance_crew_at(o) if m != null and m.has_method("request_maintenance_crew_at") else {}
			if bool(res.get("ok", false)):
				_map_panel._add_fx("pop", Vector2(o), 1.4, "-$%d" % int(res.get("amount", 0)), Color8(255, 220, 80))
				_on_status("The crew sorted it out. -$%d" % int(res.get("amount", 0)), MAP_PANEL_SCRIPT.STATUS_GOOD)
			else:
				match str(res.get("reason", "")):
					"night":
						message_requested.emit("Builder 98", "The crew does not come out after dark.", "info")
					"insufficient_funds":
						message_requested.emit("Builder 98", "Not enough money for the crew ($%d)." % int(res.get("amount", 0)), "error")
					_:
						_on_status("Nothing for the crew to do there.", MAP_PANEL_SCRIPT.STATUS_INFO)
		"demolish":
			var rect := Rect2i(o, fp)
			var name := str(_insp_view.get("title", t))
			confirm_requested.emit("Builder 98", "Demolish %s?\n\nIt cannot be undone." % name, func():
				_map_panel._send_demolish_request(rect)
				_close_inspector())
		"rack":
			program_requested.emit("guestrack")
		"lamp":
			_map_panel._send_build_request("lamp_post", o, 0)
			# The card shows the lamp once the camp has it.
			get_tree().create_timer(0.35).timeout.connect(func():
				if not _insp.is_empty() and _insp.get("origin") == o:
					_on_building_clicked(_map_panel.structure_at(o)))
	_refresh_inspector()


func _draw_inspector() -> void:
	var c := _inspect
	var s := c.size
	c.draw_style_box(T.box("window", T.FACE), Rect2(Vector2.ZERO, s))
	var band := Rect2(3, 3, s.x - 6, 17)
	for i in int(ceil(band.size.x / 8.0)):
		c.draw_rect(Rect2(band.position.x + i * 8, band.position.y, minf(8.0, band.size.x - i * 8), band.size.y), T.TITLE_A.lerp(T.TITLE_B, float(i * 8) / band.size.x))
	c.draw_string(T.FONT_BOLD, band.position + Vector2(4, 13), str(_insp_view.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, s.x - 40, T.FONT_SIZE, T.WHITE)
	var ic: Texture2D = _insp_view.get("icon")
	# A little live view: the building as the camp has it, turning slowly round, a side
	# at a time (its four pictures from the 3D model).
	var turning: Texture2D = _map_panel.card_view(str(_insp_view.get("type", "")), _card_side) if _map_panel != null else null
	if turning != null:
		ic = turning
	if ic != null:
		var isz := ic.get_size()
		var k := minf(46.0 / isz.x, 46.0 / isz.y)
		var d := (isz * k).floor()
		c.draw_rect(Rect2(6, 24, 50, 50), Color8(40, 56, 40))
		c.draw_texture_rect(ic, Rect2(Vector2(8, 26) + ((Vector2(46, 46) - d) * 0.5).floor(), d), false)
	var x := 62.0
	var y := 36.0
	var sub := str(_insp_view.get("sub", ""))
	if sub != "":
		T.FONT.draw_multiline_string(c.get_canvas_item(), Vector2(x, y), sub, HORIZONTAL_ALIGNMENT_LEFT, s.x - x - 8, T.FONT_SIZE, 2, Color8(60, 60, 110))
		y += 14.0 if T.FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x < s.x - x - 8 else 27.0
	for l in _insp_view.get("lines", []):
		c.draw_string(T.FONT, Vector2(x, y), str(l[0]) + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.SHADOW)
		c.draw_string(T.FONT_BOLD, Vector2(x + 62, y), str(l[1]), HORIZONTAL_ALIGNMENT_LEFT, s.x - x - 70, T.FONT_SIZE, l[2])
		y += 14.0


const PADLOCK_TEX := "res://assets/textury/os98/icons/padlock_16.png"
const STAR_TEX := "res://assets/textury/os98/web/star_full.png"
var _padlock: Texture2D = load(PADLOCK_TEX) if ResourceLoader.exists(PADLOCK_TEX) else null
var _star: Texture2D = load(STAR_TEX) if ResourceLoader.exists(STAR_TEX) else null


func _make_card(type: String, w: int = CARD_W) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 58)
	# Narrow cards: a smaller picture, and the shortest name if the short one is too long.
	var box_side := 46.0 if w >= 130 else 36.0
	var text_x := box_side + 8.0
	var text_w := float(w) - text_x - 3.0
	var label := str(SHORT_NAMES.get(type, type))
	if T.FONT_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x > text_w:
		label = str(TINY_NAMES.get(type, label))
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.tooltip_text = _tooltip(type)
	c.set_meta("hover", false)
	var icon := _texture(str(ITEM_ICONS.get(type, "")))
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		_hover_card = type
		c.queue_redraw()
		_refresh_info_card()
	)
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		if _hover_card == type:
			_hover_card = ""
		c.queue_redraw()
		_refresh_info_card()
	)
	c.draw.connect(func():
		var on := _selected == type
		var hov := bool(c.get_meta("hover"))
		var face := Color8(208, 208, 208) if on else (Color8(206, 214, 232) if hov else T.FACE)
		c.draw_style_box(T.box("pressed" if on else "raised", face, Vector4.ZERO), Rect2(Vector2.ZERO, c.size))
		var o := Vector2(1, 1) if on else (Vector2(0, -1) if hov else Vector2.ZERO)
		if icon != null:
			var isz := icon.get_size()
			var box := Vector2(box_side, box_side)
			var k := minf(box.x / isz.x, box.y / isz.y)
			var d := (isz * k).floor()
			c.draw_texture_rect(icon, Rect2(Vector2(5, 6 + (46.0 - box_side) * 0.5) + o + ((box - d) * 0.5).floor(), d), false)
		var afford := CoreRoot.get_money() >= _cost(type)
		var lock := _locked(type)
		if not lock.is_empty():
			# Greyed, a padlock on the picture, the rating it waits for.
			c.draw_rect(Rect2(Vector2(3, 3), c.size - Vector2(6, 6)), Color(0.75, 0.75, 0.75, 0.55))
			if _padlock != null:
				c.draw_texture_rect(_padlock, Rect2(Vector2(4, c.size.y - 20), Vector2(16, 16)), false)
			c.draw_string(T.FONT_BOLD, Vector2(text_x, 17), label, HORIZONTAL_ALIGNMENT_LEFT, text_w, T.FONT_SIZE, T.TEXT_DISABLED)
			if lock.has("registered"):
				c.draw_string(T.FONT_BOLD, Vector2(text_x, 32), "Registered", HORIZONTAL_ALIGNMENT_LEFT, text_w, T.FONT_SIZE, Color8(150, 100, 0))
				c.draw_string(T.FONT, Vector2(text_x, 47), "copies only", HORIZONTAL_ALIGNMENT_LEFT, text_w, T.FONT_SIZE, T.TEXT_DISABLED)
				return
			# The guests in the camp it waits for.
			c.draw_string(T.FONT_BOLD, Vector2(text_x, 32), "%d guests" % int(lock["guests"]), HORIZONTAL_ALIGNMENT_LEFT, text_w, T.FONT_SIZE, Color8(150, 100, 0))
			c.draw_string(T.FONT, Vector2(text_x, 47), "in the camp", HORIZONTAL_ALIGNMENT_LEFT, text_w, T.FONT_SIZE, T.TEXT_DISABLED)
			return
		c.draw_string(T.FONT_BOLD, Vector2(text_x, 17) + o, label, HORIZONTAL_ALIGNMENT_LEFT, text_w, T.FONT_SIZE, T.TEXT)
		c.draw_string(T.FONT, Vector2(text_x, 32) + o, "$%d" % _cost(type), HORIZONTAL_ALIGNMENT_LEFT, text_w, T.FONT_SIZE, T.TEXT if afford else Color8(160, 0, 0))
		c.draw_string(T.FONT, Vector2(text_x, 47) + o, _stat_line(type), HORIZONTAL_ALIGNMENT_LEFT, text_w, T.FONT_SIZE, Color8(70, 70, 90))
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select("" if _selected == type else type)
	)
	return c


## One short line under the price: beds, power, size.
func _stat_line(type: String) -> String:
	var def = CoreRoot.registry.get_def(StringName(type)) if CoreRoot.registry != null else null
	if def == null:
		return ""
	var bits: Array = []
	if int(def.capacity) > 0:
		bits.append("%d bed%s" % [int(def.capacity), "" if int(def.capacity) == 1 else "s"])
	if int(def.power_use) > 0:
		bits.append("power")
	if def.footprint != Vector2i.ONE:
		bits.append("%dx%d" % [def.footprint.x, def.footprint.y])
	# What a business fills, the most first (the guests' needs: food, drink, fun, wash).
	if BusinessRules.is_business(type):
		var fills: Array = []
		for need in def.guest_services:
			if float(def.guest_services[need]) >= 20.0:
				fills.append([float(def.guest_services[need]), {"hunger": "food", "thirst": "drink", "fun": "fun", "hygiene": "wash"}.get(str(need), str(need))])
		fills.sort_custom(func(a, b) -> bool: return float(a[0]) > float(b[0]))
		if not fills.is_empty():
			bits.push_front(", ".join(fills.map(func(f) -> String: return str(f[1]))))
	return ", ".join(bits)


# ── the splash and the info card ─────────────────────────────────────────────

func _build_splash() -> void:
	var tex := _texture(SPLASH_TEX)
	if tex == null:
		splash_finished.emit.call_deferred()
		return
	_splash = Control.new()
	_splash.mouse_filter = Control.MOUSE_FILTER_STOP
	_splash.draw.connect(func():
		# A draw can still be queued when the click skips the splash and frees it.
		if _splash == null:
			return
		var sz := _splash.size
		_splash.draw_rect(Rect2(Vector2.ZERO, sz), Color.BLACK)
		var ts := tex.get_size()
		var k := maxf(sz.x / ts.x, sz.y / ts.y)
		var d := ts * k
		_splash.draw_texture_rect(tex, Rect2((sz - d) * 0.5, d), false)
		# The title, as the box had it: big, bevelled, a drop shadow.
		var title := "Builder 98"
		var fs := T.FONT_SIZE * 3
		var tw := T.FONT_BOLD.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := Vector2(floorf((sz.x - tw) * 0.5), 58)
		_splash.draw_string(T.FONT_BOLD, tp + Vector2(3, 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
		_splash.draw_string(T.FONT_BOLD, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color8(255, 214, 90))
		var sub := "Stavitel software  -  site planning for recreational facilities"
		var sw := T.FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		_splash.draw_string(T.FONT, Vector2(floorf((sz.x - sw) * 0.5) + 1, 79), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color(0, 0, 0, 0.8))
		_splash.draw_string(T.FONT, Vector2(floorf((sz.x - sw) * 0.5), 78), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
		var line: String = SPLASH_LINES[clampi(int(_splash_t / SPLASH_SEC * SPLASH_LINES.size()), 0, SPLASH_LINES.size() - 1)]
		var lw := T.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		_splash.draw_rect(Rect2(floorf((sz.x - 260) * 0.5), sz.y - 66, 260, 40), Color(0, 0, 0, 0.55))
		_splash.draw_string(T.FONT, Vector2(floorf((sz.x - lw) * 0.5), sz.y - 52), line, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	)
	_splash.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_splash_t = SPLASH_SEC
	)
	add_child(_splash)
	_splash_bar = PROGRESS.new("blocks")
	_splash.add_child(_splash_bar)
	_splash_t = 0.0


func _build_info() -> void:
	_info = Control.new()
	_info.size = Vector2(250, 66)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_info.draw.connect(_draw_info)
	add_child(_info)


func _refresh_info_card() -> void:
	if _info == null:
		return
	var t := _hover_card if _hover_card != "" else _selected
	_info.visible = t != ""
	_info.set_meta("type", t)
	_info.queue_redraw()


func _draw_info() -> void:
	var t := str(_info.get_meta("type", ""))
	if t == "":
		return
	var r := Rect2(Vector2.ZERO, _info.size)
	_info.draw_style_box(T.box("window", T.FACE, Vector4.ZERO), r)
	var icon := _texture(str(ITEM_ICONS.get(t, "")))
	if icon == null and t in TOOLS:
		icon = _tool_art(t)
	if icon != null:
		var isz := icon.get_size()
		var k := minf(52.0 / isz.x, 52.0 / isz.y)
		var d := (isz * k).floor()
		_info.draw_rect(Rect2(6, 6, 56, 54), Color8(40, 56, 40))
		_info.draw_texture_rect(icon, Rect2(Vector2(8, 7) + ((Vector2(52, 52) - d) * 0.5).floor(), d), false)
	var x := 70.0
	_info.draw_string(T.FONT_BOLD, Vector2(x, 17), str(SHORT_NAMES.get(t, t)), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	var cost := _cost(t)
	if cost > 0:
		var afford := CoreRoot.get_money() >= cost
		var ct := "$%d" % cost
		var cw := T.FONT_BOLD.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		_info.draw_string(T.FONT_BOLD, Vector2(_info.size.x - cw - 8, 17), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(0, 110, 0) if afford else Color8(170, 0, 0))
	T.FONT.draw_multiline_string(_info.get_canvas_item(), Vector2(x, 31), str(BLURBS.get(t, "")), HORIZONTAL_ALIGNMENT_LEFT, _info.size.x - x - 8, T.FONT_SIZE, 2, T.TEXT)
	var stats := _stat_line(t)
	if stats != "":
		_info.draw_string(T.FONT, Vector2(x, 60), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(60, 60, 110))


func _tooltip(type: String) -> String:
	var def = CoreRoot.registry.get_def(StringName(type)) if CoreRoot.registry != null else null
	var t := "%s  -  $%d\n%s" % [SHORT_NAMES.get(type, type), _cost(type), BLURBS.get(type, "")]
	if def != null:
		var bits: Array = []
		if int(def.capacity) > 0:
			bits.append("%d bed(s)" % int(def.capacity))
		if int(def.power_use) > 0:
			bits.append("uses power")
		if float(def.fun_delta) > 0.0:
			bits.append("fun")
		if def.footprint != Vector2i.ONE:
			bits.append("%dx%d" % [def.footprint.x, def.footprint.y])
		if not bits.is_empty():
			t += "\n" + ", ".join(bits)
	return t


func _cost(type: String) -> int:
	var def = CoreRoot.registry.get_def(StringName(type)) if CoreRoot.registry != null else null
	return int(def.cost) if def != null else 0


# ── info ─────────────────────────────────────────────────────────────────────

var _card_side := 0
var _card_t := 0.0


func _process(delta: float) -> void:
	_deny_cd -= delta
	if _inspect != null and _inspect.visible:
		_card_t += delta
		if _card_t >= 1.4:
			_card_t = 0.0
			_card_side = (_card_side + 1) % 4
			_inspect.queue_redraw()
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_refresh_info()
	_tick_odo(delta)
	_tick_news(delta)
	_tick_guest_card(delta)
	_tick_coins(delta)
	_tick_music(delta)
	_tick_ambience(delta)
	_tick_cursor()
	# The first time the map has a size: the camp in the middle, near enough to read.
	if not camp_focused and _map_panel != null and _map_panel.size.x > 0.0 and is_visible_in_tree():
		camp_focused = _map_panel.focus_camp()
	if _catalogue != null and _catalogue.visible and _cat_open < 1.0:
		_cat_open = minf(1.0, _cat_open + delta * 7.0)
		_layout()
	if _cards != null and _catalogue != null and _catalogue.visible:
		for c in _cards.get_children():
			if c.has_meta("appear"):
				var at := float(c.get_meta("appear")) - delta
				c.set_meta("appear", at)
				if at <= 0.0:
					c.modulate.a = 1.0
					c.remove_meta("appear")
	if _splash != null and _splash_t >= 0.0:
		_splash_t += delta
		if _splash_bar != null:
			_splash_bar.value = clampf(_splash_t / (SPLASH_SEC * 0.9), 0.0, 1.0)
		_splash.queue_redraw()
		if _splash_t >= SPLASH_SEC:
			_splash_t = -1.0
			_splash.queue_free()
			_splash = null
			_splash_bar = null
			splash_finished.emit()


func _tick_odo(delta: float) -> void:
	if _odo == null:
		return
	var target := float(CoreRoot.get_money())
	if _odo_v < 0.0:
		# The first look: the sum as it is (it was drawn once before it knew it: "$0").
		_odo_v = target
		_odo.queue_redraw()
	if absf(target - _odo_v) > 0.01:
		var step := maxf(4.0, absf(target - _odo_v) * 3.5) * delta
		_odo_dir = 1 if target > _odo_v else -1
		_odo_v = move_toward(_odo_v, target, step)
		_odo_flash = 0.8
		_odo.queue_redraw()
	elif _odo_flash > 0.0:
		_odo_flash -= delta
		if _odo_flash <= 0.0:
			_odo.queue_redraw()


func _draw_odo() -> void:
	var v := maxf(0.0, _odo_v)
	var whole := int(floor(v))
	var frac := v - float(whole)
	var col := Color8(80, 255, 80)
	if _odo_flash > 0.0:
		col = Color8(170, 255, 140) if _odo_dir > 0 else Color8(255, 96, 80)
	var text := "$" + _group(whole)
	var cw := 7.0
	var h := _odo.size.y
	var x := _odo.size.x
	var place := 0
	for i in range(text.length() - 1, -1, -1):
		var ch := text[i]
		x -= cw if ch.is_valid_int() else T.FONT_BOLD.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 1.0
		if not ch.is_valid_int():
			_odo.draw_string(T.FONT_BOLD, Vector2(x, 12), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)
			continue
		var d := int(ch)
		# A wheel turns while every wheel under it stands on 9 (and the last one always).
		var p10 := int(pow(10, place))
		var roll := frac if place == 0 or whole % p10 == p10 - 1 else 0.0
		roll = floorf(roll * 4.0) / 4.0
		_odo.draw_string(T.FONT_BOLD, Vector2(x, 12 - roll * h), str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)
		if roll > 0.0:
			_odo.draw_string(T.FONT_BOLD, Vector2(x, 12 + (1.0 - roll) * h), str((d + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)
		place += 1


## A guest paid for their room: coins from the room to the cash.
func _on_guest_paid(amount: int, guest_id: int) -> void:
	if not is_visible_in_tree() or amount <= 0:
		return
	var st = CoreRoot.get_state()
	if st == null:
		return
	for g in st.guests:
		if g is Dictionary and int(g.get("id", -2)) == guest_id:
			var slots: Array = g.get("lodging_slots", []) if g.get("lodging_slots", []) is Array else []
			if not slots.is_empty() and slots[0] is Dictionary:
				var key := str((slots[0] as Dictionary).get("accommodation_key", ""))
				if key.contains(":"):
					var c := Vector2i(int(key.get_slice(":", 0)), int(key.get_slice(":", 1)))
					_paid[c] = int(_paid.get(c, 0)) + amount
			return


func _tick_coins(delta: float) -> void:
	_coin_cd -= delta
	if _coin_layer == null:
		_coin_layer = Control.new()
		_coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_coin_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_coin_layer.z_index = 50
		_coin_layer.draw.connect(_draw_coins)
		add_child(_coin_layer)
		if EventBus.has_signal("guest_payment_received"):
			EventBus.guest_payment_received.connect(_on_guest_paid)
	# The businesses' takings since the last look (their books in GameState.biz).
	_coin_scan -= delta
	if _coin_scan <= 0.0:
		_coin_scan = 0.6
		var st = CoreRoot.get_state()
		var sites: Dictionary = st.biz.get("sites", {}) if st != null and st.biz is Dictionary else {}
		for key in sites:
			var today: Dictionary = (sites[key] as Dictionary).get("today", {}) if sites[key] is Dictionary else {}
			var tk := int(today.get("takings", 0))
			var seen := int(_takings_seen.get(key, -1))
			if seen >= 0 and tk > seen and str(key).contains(":"):
				var c := Vector2i(int(str(key).get_slice(":", 0)), int(str(key).get_slice(":", 1)))
				_paid[c] = int(_paid.get(c, 0)) + tk - seen
			_takings_seen[key] = tk
		for c in _paid.keys():
			_launch_coins(c, int(_paid[c]))
		_paid.clear()
	for i in range(_coins.size() - 1, -1, -1):
		_coins[i]["t"] = float(_coins[i]["t"]) + delta
		if float(_coins[i]["t"]) >= float(_coins[i]["life"]):
			_coins.remove_at(i)
			_odo_flash = 0.8
	if not _coins.is_empty() or _coin_layer.has_meta("drawn"):
		_coin_layer.queue_redraw()
		if _coins.is_empty():
			_coin_layer.remove_meta("drawn")


func _launch_coins(coord: Vector2i, amount: int) -> void:
	if _map_panel == null or _odo == null or not is_visible_in_tree() or amount <= 0:
		return
	var p: Vector2 = _map_panel.cell_screen_point(coord)
	if not p.is_finite():
		return
	var to_layer := _coin_layer.get_global_transform().affine_inverse()
	var from: Vector2 = to_layer * (_map_panel.get_global_transform() * p)
	var n := clampi(amount / 8 + 1, 1, 6)
	for i in n:
		_coins.append({"from": from + Vector2(randf_range(-5, 5), randf_range(-3, 3)), "t": -0.08 * float(i), "life": randf_range(0.7, 0.9)})
	if _coin_cd <= 0.0 and _map_panel.has_method("_play"):
		_map_panel._play("coins", -16.0)
		_coin_cd = 0.6


## Each coin on an arc to the cash, turning in four steps (face, edge, back, edge).
func _draw_coins() -> void:
	if _coin_tex == null or _odo == null:
		return
	_coin_layer.set_meta("drawn", true)
	var to_layer := _coin_layer.get_global_transform().affine_inverse()
	var target: Vector2 = to_layer * (_odo.get_global_transform() * (_odo.size * 0.5))
	for c in _coins:
		var t := float(c["t"])
		if t < 0.0:
			continue
		var k := t / float(c["life"])
		var a: Vector2 = c["from"]
		var mid := (a + target) * 0.5 + Vector2(0, -60.0)
		var p := a.lerp(mid, k).lerp(mid.lerp(target, k), k)
		var turn: float = [1.0, 0.55, 0.15, 0.55][int(t * 12.0) % 4]
		var sz := _coin_tex.get_size()
		var w := maxf(2.0, sz.x * turn)
		_coin_layer.draw_texture_rect(_coin_tex, Rect2((p - Vector2(w, sz.y) * 0.5).floor(), Vector2(w, sz.y)), false)


func _tick_music(delta: float) -> void:
	if _music == null:
		if not ResourceLoader.exists(MUSIC):
			return
		_music = AudioStreamPlayer.new()
		var s = load(MUSIC)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_music.stream = s
		_music.volume_db = MUSIC_DB
		add_child(_music)
	var off := bool(_shell_stored("builder_music_off", false))
	var shell = _shell_node()
	var dist := float(shell.call("sound_db")) if shell != null and shell.has_method("sound_db") else 0.0
	var want := is_visible_in_tree() and not off and _splash == null and dist > -60.0
	if want and not _music.playing:
		_music.play()
	elif not want and _music.playing:
		_music.stop()
	if not _music.playing:
		return
	_music_t += delta
	# Flat and slow toward the evening (18:00 to the lock at 20:00), more on a bad night's eve.
	var main = get_tree().current_scene if get_tree() != null else null
	var h := float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 12.0
	var dusk := clampf((h - 18.0) / 2.0, 0.0, 1.0)
	var hud = main.get("_hud_manager") if main != null else null
	var risk := int(hud.get("_risk_level_index")) if hud != null and hud.get("_risk_level_index") != null else 0
	var flat := dusk * 0.05 + (0.02 if risk >= 3 else 0.0)
	var wow := sin(_music_t * 0.8) * 0.004 * (1.0 + 6.0 * flat)
	_music.pitch_scale = clampf(1.0 - flat + wow, 0.85, 1.05)
	_music.volume_db = MUSIC_DB + dist


func _tick_ambience(delta: float) -> void:
	_amb_t -= delta
	if _amb_t <= 0.0:
		_amb_t = 0.4
		_amb_kind = _map_panel.sound_under_pointer() if is_visible_in_tree() and _splash == null and _map_panel != null else ""
	var shell = _shell_node()
	var room := float(shell.call("sound_db")) if shell != null and shell.has_method("sound_db") else 0.0
	for k in ["lake", "forest", "play", "pub", "camp"]:
		var want: bool = k == _amb_kind and room > -60.0
		var p: AudioStreamPlayer = _amb.get(k)
		if p == null:
			if not want:
				continue
			var path := "res://assets/sfx/builder/amb_%s.mp3" % k
			if not ResourceLoader.exists(path):
				continue
			var st = load(path)
			if st is AudioStreamMP3:
				(st as AudioStreamMP3).loop = true
			p = AudioStreamPlayer.new()
			p.stream = st
			p.volume_db = -60.0
			add_child(p)
			_amb[k] = p
		if want and not p.playing:
			p.play(randf() * 6.0)
		p.volume_db = move_toward(p.volume_db, (AMB_DB + room) if want else -60.0, delta * 24.0)
		if not want and p.playing and p.volume_db <= -59.5:
			p.stop()


var _graphs: Control


## The Graphs window, in the middle of the map; again to put it away.
func toggle_graphs() -> void:
	if _graphs != null and is_instance_valid(_graphs):
		_graphs.queue_free()
		_graphs = null
		_ui("close")
		return
	_ui("open")
	_graphs = load("res://scripts/builder/graphs_window.gd").new()
	add_child(_graphs)
	_graphs.closed.connect(func():
		_click()
		toggle_graphs())
	var well := _map_panel.get_rect()
	_graphs.position = (well.position + (well.size - Vector2(440, 268)) * 0.5).floor()


# ── shareware and cheats (scripts/builder/shareware.gd) ─────────────────────

var _sw = null
## The tool and the overlay before each of the last letters typed: a cheat's letters
## are tool keys too (B the bulldozer, O the overlay...), put back once it is typed.
var _cheat_undo: Array = []


func _ensure_sw() -> void:
	if _sw != null:
		return
	var shell := _shell_node()
	if shell == null:
		return
	_sw = load("res://scripts/builder/shareware.gd").new()
	var d = shell.call("stored", "builder98", {})
	if d is Dictionary and not (d as Dictionary).is_empty():
		_sw.import_state(d)
	else:
		var wg = _main().get("world_generator") if _main() != null else null
		_sw.reset(int(wg.get("world_seed")) if wg != null else 0)


func _save_sw() -> void:
	var shell := _shell_node()
	if shell != null and _sw != null:
		shell.call("store", "builder98", _sw.export_state())


## A build here: the nag now and then (unregistered copies).
func _on_build_for_nag(_type: String, _pos: Vector2i, _rot: int) -> void:
	if not is_visible_in_tree():
		return
	_ensure_sw()
	if _sw == null:
		return
	var nag: bool = _sw.note_build()
	_save_sw()
	if nag:
		message_requested.emit("Builder 98 - Unregistered", "You have built %d things with an unregistered copy\nof Builder 98. Thank you for trying it!\n\nRegister for $99: Help > Register...\nRegistered copies plan without this reminder\nand come with the Mega gnome." % int(_sw.builds), "info")


func _mail_tomorrow(kind: String, extra: String) -> void:
	if Coop.is_client():
		Coop.send_request("builder98_mail", [kind, extra])
	elif EmailManager != null and EmailManager.has_method("schedule_pool_mail"):
		EmailManager.schedule_pool_mail(load("res://scripts/builder/shareware.gd").mail_for(kind, extra, CoreRoot.get_day()))


func _register_dialog() -> void:
	_ensure_sw()
	var shell := _shell_node()
	if _sw == null or shell == null:
		return
	if _sw.registered:
		message_requested.emit("Register Builder 98", "This copy of Builder 98 is registered\nto Camp Cerne Jezero.\n\nThank you!", "info")
		return
	if _sw.key == "":
		confirm_requested.emit("Register Builder 98", "Register Builder 98 for $99?\n\nStavitel software mails your key the next morning.", func():
			if not CoreRoot.actions.spend_money(load("res://scripts/builder/shareware.gd").PRICE):
				message_requested.emit("Register Builder 98", "The camp has not got $99.", "error")
				return
			var key: String = _sw.order(CoreRoot.get_day())
			_save_sw()
			_mail_tomorrow("key", key)
			_map_panel._emit_status("Registration ordered: the key comes by mail tomorrow.", 1))
		return
	# Ordered: the key typed in from the mail.
	var win = shell.call("_make_dialog", "b98reg", "Register Builder 98", null, Rect2(Vector2(150, 160), Vector2(330, 120)))
	win.can_minimize = false
	var c: Control = win.content
	var l := Label.new()
	l.text = "Type the key from Stavitel software's mail:"
	l.position = Vector2(12, 10)
	c.add_child(l)
	var edit := LineEdit.new()
	edit.position = Vector2(12, 34)
	edit.size = Vector2(300, 22)
	c.add_child(edit)
	var ok := Button.new()
	ok.text = "OK"
	ok.position = Vector2(126, 64)
	ok.size = Vector2(75, 23)
	c.add_child(ok)
	var go := func():
		var good: bool = _sw.register(edit.text)
		_save_sw()
		shell.call("_close_window", win)
		if good:
			message_requested.emit("Builder 98", "Thank you for registering Builder 98!\n\nRegistered to: Camp Cerne Jezero\nThe Mega gnome is in the Decor catalogue.", "info")
			_open_category(_active_cat)
		else:
			message_requested.emit("Builder 98", "That key is not valid.", "error")
	ok.pressed.connect(go)
	edit.text_submitted.connect(func(_t): go.call())
	edit.grab_focus.call_deferred()


func _cheat_key(ch: String) -> void:
	_ensure_sw()
	if _sw == null:
		return
	_cheat_undo.append([_selected, _map_panel.overlay, _active_cat])
	while _cheat_undo.size() > 12:
		_cheat_undo.pop_front()
	var cheat: String = _sw.type_key(ch)
	if cheat == "":
		return
	# The letters did their tool jobs on the way: undo them (the state before the first).
	var before: Array = _cheat_undo[maxi(0, _cheat_undo.size() - cheat.length())]
	_cheat_undo.clear()
	call_deferred("_after_cheat", before, cheat)


func _after_cheat(before: Array, cheat: String) -> void:
	_select(str(before[0]))
	_set_overlay(str(before[1]))
	_open_category(str(before[2]))
	match cheat:
		"BOHEMIA":
			CoreRoot.actions.add_money(5000)
			_map_panel._emit_status("BOHEMIA: +$5,000.", 1)
			_map_panel._play("coins", -8.0)
			_mail_tomorrow("bohemia", "")
		"KAREL":
			_map_panel.show_old_camp(5.0)
		"MOLE":
			_map_panel.show_buried(6.0)
		"VERA":
			_map_panel._emit_status("Vera: \"Stop playing with the computer and go and look at the toilets.\"")


## About: the credits, and in the box below them a little bulldozer flattening tents
## (it drives itself; the arrows take it).
func _about_dialog() -> void:
	var shell := _shell_node()
	if shell == null:
		return
	_ensure_sw()
	var win = shell.call("_make_dialog", "b98about", "About Builder 98", null, Rect2(Vector2(150, 70), Vector2(340, 330)))
	win.can_minimize = false
	var c: Control = win.content
	var l := Label.new()
	var reg := "Registered to: Camp Cerne Jezero" if _sw != null and _sw.registered else "UNREGISTERED SHAREWARE  -  %d days of the trial left" % maxi(0, 30 - CoreRoot.get_day())
	l.text = "Builder 98  version 1.2\n(c) 1996-98 Stavitel software, Jihlava\n%s\n\nPlanning: Ing. Pavel Stavitel\nPictures: Jana Stavitelova\nMusic: the Sound Blaster\nThe game around it: UNDO LABS" % reg
	l.position = Vector2(12, 8)
	c.add_child(l)
	var toy = load("res://scripts/builder/about_dozer.gd").new()
	toy.position = Vector2(12, 144)
	toy.size = Vector2(c.size.x - 24 if c.size.x > 100 else 300, 118)
	c.add_child(toy)
	var ok := Button.new()
	ok.text = "OK"
	ok.position = Vector2(126, 272)
	ok.size = Vector2(75, 23)
	ok.pressed.connect(func(): shell.call("_close_window", win))
	c.add_child(ok)


# ── the Courier's extra editions and the district's diplomas ─────────────────

var _courier = null
var _news_queue: Array = []
var _news_open: Control
var _news_t := 3.0
## What each edition's picture is (the catalogue's own, printed as a halftone).
const NEWS_PICTURES := {
	"caravan": "caravan_1", "slide": "lake_slide", "pub": "pub", "jednota": "vecerka", "mega_gnome": "mega_gnome",
	"guests": "tent_1",
}


func _ensure_courier() -> void:
	if _courier != null:
		return
	var shell := _shell_node()
	if shell == null or _map_panel == null:
		return
	_courier = load("res://scripts/builder/courier_news.gd").new()
	var d = shell.call("stored", "courier", {})
	if d is Dictionary and not (d as Dictionary).is_empty():
		_courier.import_state(d)
	else:
		# A camp already going: what it has now is old news, not an extra edition.
		_courier.check(_camp_facts())
		shell.call("store", "courier", _courier.export_state())


## What the camp has now, for the Courier (the map's last picture of it, Goggle, the
## guests, the upkeep).
func _camp_facts() -> Dictionary:
	var types := {}
	var buildings := 0
	for o in _map_panel._known:
		var t := str(_map_panel._known[o][0])
		types[t] = true
		if t != "path" and t != "lamp_post":
			buildings += 1
	var m := _main()
	var day := CoreRoot.get_day() if CoreRoot != null else 1
	var g = m.get("_goggle") if m != null else null
	var people := 0
	if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
		for x in GuestManager.get_guest_life_snapshot():
			people += int((x as Dictionary).get("party_size", 1)) if x is Dictionary else 0
	var mood := 0.0
	if GuestManager != null and GuestManager.has_method("get_camp_mood_summary"):
		mood = float((GuestManager.get_camp_mood_summary() as Dictionary).get("avg_mood", 0.0))
	var repair := 0.0
	if m != null and m.has_method("get_upkeep_snapshot"):
		var rows: Array = (m.get_upkeep_snapshot() as Dictionary).get("rows", [])
		var sum := 0.0
		for r in rows:
			sum += 0.0 if bool(r.get("broken", false)) else float(r.get("condition", 1.0))
		repair = sum / float(rows.size()) if not rows.is_empty() else 0.0
	var caught := false
	var start := 5.0
	var tier_stars := {}
	if g != null:
		for e in g.reviews:
			if bool(e.get("flagged", false)):
				caught = true
		var olds: Array = g.OLD_REVIEWS
		var sum2 := 0.0
		for r in olds:
			sum2 += float(r["stars"])
		start = snappedf(sum2 / float(maxi(1, olds.size())), 0.1)
		for i in g.TIERS.size():
			tier_stars[i] = "%d" % int(g.TIERS[i]["guests"])
	return {
		"caravan": types.keys().any(func(t): return str(t).begins_with("caravan")),
		"slide": types.has("lake_slide"), "pub": types.has("pub") or types.has("pub_2"),
		"jednota": types.has("vecerka"), "mega_gnome": types.has("mega_gnome"),
		"tier": int(g.tier) if g != null else 0, "tier_stars": tier_stars,
		"rating": float(g.rating(day)) if g != null else 0.0, "start_rating": start,
		"caught": caught, "guests": people, "mood": mood, "buildings": buildings, "repair": repair,
	}


func _tick_news(delta: float) -> void:
	if not is_visible_in_tree() or _splash != null:
		return
	_news_t -= delta
	if _news_t <= 0.0:
		_news_t = 3.0
		_ensure_courier()
		if _courier != null:
			var due: Array = _courier.check(_camp_facts())
			if not due.is_empty():
				_news_queue.append_array(due)
				var shell := _shell_node()
				if shell != null:
					shell.call("store", "courier", _courier.export_state())
	if (_news_open == null or not is_instance_valid(_news_open)) and not _news_queue.is_empty():
		_show_news(_news_queue.pop_front())


func _show_news(item: Dictionary) -> void:
	var pic: Texture2D = null
	var id := str(item.get("id", ""))
	if id.begins_with("tier"):
		pic = _texture("res://assets/textury/os98/icons/goggle.png")
	elif id == "caught":
		pic = _texture("res://assets/textury/os98/web/spotless_banner.png")
	else:
		var key := id.rstrip("0123456789")
		if NEWS_PICTURES.has(key):
			pic = _texture(str(ITEM_ICONS.get(str(NEWS_PICTURES[key]), "")))
	if _ticker != null:
		var diploma := str(item.get("kind", "")) == "diploma"
		_ticker.add(("Your camp won a diploma: %s." if diploma else "Hlubocany Courier: %s") % str(item.get("title", "")).rstrip("."), "medal" if diploma else "cabin")
	_news_open = load("res://scripts/builder/news_paper.gd").new()
	_news_open.setup(item, pic)
	add_child(_news_open)
	var well := _map_panel.get_rect()
	_news_open.position = (well.position + (well.size - _news_open.size) * 0.5).floor()
	_news_open.done.connect(func():
		_click()
		_news_open.queue_free()
		_news_open = null)
	_map_panel._play("diploma" if str(item.get("kind", "")) == "diploma" else "news", -9.0)


func _tick_cursor() -> void:
	var shell := _shell_node()
	if shell == null or _map_panel == null:
		return
	var tex: Texture2D = null
	# Where the shell draws its pointer (the PC's own mouse, in its screen's pixels).
	var m = shell.get("_mouse")
	var at: Vector2 = m if m is Vector2 else _map_panel.get_global_mouse_position()
	if is_visible_in_tree() and _map_panel.get_global_rect().has_point(at):
		tex = cursor_texture(_selected)
	if shell.get("tool_cursor") != tex:
		shell.set("tool_cursor", tex)


## The picture beside the arrow for a tool ("" none, any building the blueprint).
func cursor_texture(tool: String) -> Texture2D:
	var key := tool if TOOL_CURSORS.has(tool) else "*"
	if not _cursor_tex.has(key):
		var p := str(TOOL_CURSORS[key])
		_cursor_tex[key] = load(p) if p != "" and ResourceLoader.exists(p) else null
	return _cursor_tex[key]


func _exit_tree() -> void:
	var shell := _shell_node()
	if shell != null and shell.get("tool_cursor") != null:
		shell.set("tool_cursor", null)


func _shell_node() -> Node:
	var n: Node = self
	while n != null and not n.has_method("stored"):
		n = n.get_parent()
	return n


func _shell_stored(key: String, default: Variant) -> Variant:
	var s := _shell_node()
	return s.call("stored", key, default) if s != null else default


## The map a quarter round; the PC remembers which way it was left.
func turn_view(step: int) -> void:
	_map_panel.rotate_view(step)
	var s := _shell_node()
	if s != null:
		s.call("store", "builder_view", int(_map_panel.view_rot))


func _toggle_music() -> void:
	var s := _shell_node()
	if s == null:
		return
	var off := not bool(s.call("stored", "builder_music_off", false))
	s.call("store", "builder_music_off", off)
	if _music_btn != null:
		_music_btn.icon = _music_icon(off)


func _music_icon(off: bool) -> Texture2D:
	var p := "res://assets/textury/builder/tb2_music_%s.png" % ("off" if off else "on")
	return load(p) if ResourceLoader.exists(p) else null


func _refresh_info() -> void:
	if _money == null:
		return
	_money.text = "$%s" % _group(CoreRoot.get_money())
	var tree := get_tree()
	var main = tree.current_scene if tree != null else null
	var clock := str(main.call("_time_of_day_string")) if main != null and main.has_method("_time_of_day_string") else "--:--"
	_clock.text = "Day %d   %s" % [CoreRoot.get_day(), clock]
	_refresh_cost()
	if _inspect != null and _inspect.visible:
		_refresh_inspector()


func _refresh_cost() -> void:
	if _status_cost == null:
		return
	match _selected:
		"":
			_status_cost.text = ""
		"demolish":
			_status_cost.text = "Trees: free"
		_:
			_status_cost.text = "Cost: $%d" % _cost(_selected)


func _on_status(text: String, kind: int) -> void:
	_status_msg.text = text
	var col := T.TEXT
	if kind == MAP_PANEL_SCRIPT.STATUS_DENY:
		col = Color8(160, 0, 0)
		# A no has its sound (not one per tile of a refused row).
		if _deny_cd <= 0.0 and is_visible_in_tree():
			_ui("deny", -9.0)
			_deny_cd = 0.4
	elif kind == MAP_PANEL_SCRIPT.STATUS_GOOD:
		col = Color8(0, 96, 0)
	_status_msg.add_theme_color_override("font_color", col)


func _site_report() -> String:
	var counts := {}
	var seen := {}
	if _grid_manager != null:
		for y in int(_grid_manager.grid_height):
			for x in int(_grid_manager.grid_width):
				var tile = _grid_manager.get_tile(Vector2i(x, y))
				if tile == null or not tile.occupied or tile.occupant == null:
					continue
				var root: Node = tile.occupant
				while root.get_parent() != null and not root.has_meta("building_type") and not root.is_in_group("trees"):
					root = root.get_parent()
				if seen.has(root.get_instance_id()) or root.is_in_group("trees"):
					continue
				seen[root.get_instance_id()] = true
				var k := str(root.get_meta("building_type", ""))
				if not k.is_empty():
					counts[k] = int(counts.get(k, 0)) + 1
	var beds: Dictionary = GuestManager.get_bed_metrics() if GuestManager != null else {}
	var t := "Site: Kemp Cerne jezero\nDay %d\n\nBeds: %d (%d free)\nCash: $%s" % [CoreRoot.get_day(), int(beds.get("capacity", 0)), int(beds.get("free", 0)), _group(CoreRoot.get_money())]
	var guests := 0
	if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			guests += int((g as Dictionary).get("party_size", 1)) if g is Dictionary else 0
	var m := _main()
	var h := float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 12.0
	if guests > 0 and h >= 18.0 and randf() < 0.12:
		guests += 1
	t += "\nGuests: %d" % guests
	if not counts.is_empty():
		t += "\n"
		for k in counts:
			if k != "path" and k != "tree":
				t += "\n%s: %d" % [SHORT_NAMES.get(k, k), counts[k]]
	return t


# ── art ──────────────────────────────────────────────────────────────────────

func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _icon_cache.has(path):
		return _icon_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icon_cache[path] = tex
	return tex


## Small pixel icons for the three plain tools, 12x12 drawn at 2x.
const TOOL_PIX := {
	"demolish": [
		"............",
		"....YYYY....",
		"....Y..Y....",
		"....Y..YYYY.",
		"B...YYYYYYY.",
		"BB..YYYYYYY.",
		"BBBYYYYYYYY.",
		"BB..YYYYYYY.",
		"B..KKKKKKKK.",
		"..KDKDKDKDK.",
		"...KKKKKKK..",
		"............"],
	"path": [
		"............",
		".....TT.....",
		"....TttT....",
		"...TttdtT...",
		"..TtdtttdT..",
		".TttttdtttT.",
		"..TtdtttdT..",
		"...TttdtT...",
		"....TttT....",
		".....TT.....",
		"............",
		"............"],
	"lamp_post": [
		"....KKKK....",
		"...KyyyyK...",
		"...KyyyyK...",
		"....KKKK....",
		".....KK.....",
		".....GG.....",
		".....GG.....",
		".....GG.....",
		".....GG.....",
		".....GG.....",
		"....GGGG....",
		"...KKKKKK..."],
}
const TOOL_PIX_MORE := {
	"undo": [
		"............",
		"...K........",
		"..KcK.......",
		".KccKKKKK...",
		"KcccccccKK..",
		".KccKKKKcK..",
		"..KcK...KcK.",
		"...K....KcK.",
		".......KcK..",
		"....KKKcK...",
		"....KccK....",
		"....KKK....."],
	"zoom_in": [
		"..KKKK......",
		".KwwwwK.....",
		"KwwKKwwK....",
		"KwKKKKwK....",
		"KwwKKwwK....",
		".KwwwwK.....",
		"..KKKKMM....",
		"......MMM...",
		".......MMM..",
		"........MMM.",
		".........MM.",
		"............"],
	"zoom_out": [
		"..KKKK......",
		".KwwwwK.....",
		"KwwwwwwK....",
		"KwKKKKwK....",
		"KwwwwwwK....",
		".KwwwwK.....",
		"..KKKKMM....",
		"......MMM...",
		".......MMM..",
		"........MMM.",
		".........MM.",
		"............"],
	"map": [
		"............",
		"KKKK.KKKK.KK",
		"KggKKbbbbKgK",
		"KggKbbbbKggK",
		"KggKbbbKgggK",
		"KgggKbbKggrK",
		"KggggKbKgrgK",
		"KggggKbKrggK",
		"KgggKbbKggyK",
		"KggKbbbKgyyK",
		"KKK.KKKK.KKK",
		"............"],
}
const PIX_COLORS := {
	"c": Color8(60, 140, 60), "w": Color8(220, 236, 255), "M": Color8(120, 80, 40),
	"g": Color8(110, 170, 80), "b": Color8(80, 130, 210), "r": Color8(200, 60, 40),
	"Y": Color8(240, 200, 0), "K": Color8(20, 20, 20), "D": Color8(110, 110, 110), "B": Color8(150, 150, 160),
	"T": Color8(110, 80, 40), "t": Color8(200, 170, 110), "d": Color8(160, 130, 80),
	"y": Color8(255, 240, 140), "G": Color8(90, 90, 96),
}


## The painted toolbar icons, falling back to the little pixel ones.
func _tool_art(id: String) -> Texture2D:
	var name: String = {"demolish": "bulldoze", "path": "path", "lamp_post": "lamp"}.get(id, id)
	var tex := _texture("res://assets/textury/builder/tb2_%s.png" % name)
	if tex == null:
		tex = _texture("res://assets/textury/builder/tb_%s.png" % name)
	return tex if tex != null else _tool_icon(id)


func _tool_icon(id: String) -> Texture2D:
	var rows: Array = TOOL_PIX.get(id, TOOL_PIX_MORE.get(id, []))
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if PIX_COLORS.has(ch):
				img.fill_rect(Rect2i(x * 2, y * 2, 2, 2), PIX_COLORS[ch])
	return ImageTexture.create_from_image(img)


static func _group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
