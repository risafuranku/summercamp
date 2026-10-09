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

const T = preload("res://scripts/os98/os_theme.gd")
const MAP_PANEL_SCRIPT = preload("res://scripts/crt_map_panel.gd")

const CATEGORIES: Array = [
	{"id": "housing", "label": "Housing", "icon": "res://assets/textury/builder/tb_housing.png", "items": ["tent_1", "cabin_1", "caravan_1"]},
	{"id": "services", "label": "Services", "icon": "res://assets/textury/builder/tb_services.png", "items": ["toilet_block", "shower_block", "vecerka", "restaurant", "pub"]},
	{"id": "fun", "label": "Fun", "icon": "res://assets/textury/builder/tb_fun.png", "items": ["bonfire", "sports_field", "lake_slide"]},
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
}

## Short names for the catalogue cards; the registry's display names are long.
const SHORT_NAMES := {
	"tent_1": "Tent", "cabin_1": "Cabin", "caravan_1": "Caravan", "toilet_block": "Toilets",
	"shower_block": "Showers", "vecerka": "Jednota", "restaurant": "Bistro", "pub": "Pub",
	"bonfire": "Bonfire", "sports_field": "Sports field", "lake_slide": "Lake slide", "sewer": "Sewage",
	"path": "Path", "lamp_post": "Lamp", "demolish": "Bulldozer",
}

const BLURBS := {
	"tent_1": "Cheap. One guest sleeps here, not very well.",
	"cabin_1": "Two guests, a proper bed. Better sleep, better reviews.",
	"caravan_1": "Six beds. Needs power.",
	"toilet_block": "Without it, guests use the bushes. Needs the sewer.",
	"shower_block": "Guests get dirty. Needs the sewer.",
	"vecerka": "Bread, sausages, beer. Cheap food.",
	"restaurant": "Proper hot meals. Needs power.",
	"pub": "Beer and noise. Guests love it, then they get loud.",
	"bonfire": "Fun, food on sticks, and a light that feels safe at night.",
	"sports_field": "Fun for the active ones.",
	"lake_slide": "Fun, and a quick wash on the way down.",
	"sewer": "The toilets and showers drain here. Somebody has to clean it.",
	"path": "Drag to lay a path. Guests walk on paths.",
	"lamp_post": "Light at night. A lit path is a safe path.",
	"demolish": "Drag over trees or buildings, then click inside to clear them.",
}

const TOOLS := ["demolish", "path", "lamp_post"]
const TOOLBAR_H := 40
const CATALOGUE_H := 46

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
var _clock: Label
var _tool_buttons: Dictionary = {}
var _cat_buttons: Dictionary = {}
var _active_cat := ""
var _selected := ""
var _icon_cache: Dictionary = {}
var _sfx: AudioStreamPlayer
var _tick := 0.0


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
	_build_status()
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
		_catalogue.position = Vector2(0, y)
		_catalogue.size = Vector2(size.x, CATALOGUE_H)
		y += CATALOGUE_H
	var well: Control = get_node("MapWell")
	well.position = Vector2(0, y)
	well.size = Vector2(size.x, size.y - y - 20)
	_map_panel.position = well.position + Vector2(2, 2)
	_map_panel.size = well.size - Vector2(4, 4)
	var bar: Control = get_node("StatusBar")
	bar.position = Vector2(0, size.y - 18)
	bar.size = Vector2(size.x, 18)
	var w := size.x
	_status_msg.get_parent().size = Vector2(w - 290, 18)
	_status_tile.get_parent().position = Vector2(w - 288, 0)
	_status_cost.get_parent().position = Vector2(w - 110, 0)


func _build_menu() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(2, 1)
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	var menus := {
		"File": ["Site report", "New site...", "-", "Exit"],
		"View": ["Zoom in", "Zoom out", "Rotate building  (Q)"],
		"Help": ["Help topics", "-", "About Builder 98"],
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
		"Site report":
			message_requested.emit("Site report", _site_report(), "info")
		"New site...":
			message_requested.emit("Builder 98", "The shareware version plans one site only.\n\nRegister Builder 98 for 990 Kc to plan more sites.", "info")
		"Help topics":
			message_requested.emit("Builder 98 Help", "Cannot open BUILDER.HLP.\n\nThe file is missing or damaged.", "error")
		"About Builder 98":
			var left := maxi(0, 30 - CoreRoot.get_day())
			message_requested.emit("About Builder 98", "Builder 98  version 1.2\n(c) 1996-98 Stavitel software, Jihlava\n\nUNREGISTERED SHAREWARE\n%d days of the trial left.\n\nLicensed for recreational facilities:\n06:30 - 20:00 only." % left, "info")


func _build_toolbar() -> void:
	_toolbar = Panel.new()
	_toolbar.add_theme_stylebox_override("panel", T.box("thin_raised", T.FACE, Vector4.ZERO))
	add_child(_toolbar)
	var row := HBoxContainer.new()
	row.position = Vector2(4, 3)
	row.add_theme_constant_override("separation", 2)
	_toolbar.add_child(row)
	for id in TOOLS:
		var b := _tool_button(_tool_art(id), "%s\n%s" % [SHORT_NAMES[id], BLURBS[id]])
		var tool: String = id
		b.pressed.connect(func():
			_open_category("")
			_select("" if _selected == tool else tool)
		)
		_tool_buttons[id] = b
		row.add_child(b)
	row.add_child(_gap())
	for cat in CATEGORIES:
		var b := _tool_button(_texture(str(cat["icon"])), str(cat["label"]))
		var cid: String = cat["id"]
		b.pressed.connect(func(): _open_category("" if _active_cat == cid else cid))
		_cat_buttons[cid] = b
		row.add_child(b)
	row.add_child(_gap())
	var rot := Button.new()
	rot.text = "Rotate"
	rot.tooltip_text = "Turn the building (Q / E)"
	rot.custom_minimum_size = Vector2(0, 34)
	rot.focus_mode = Control.FOCUS_NONE
	rot.pressed.connect(func(): _map_panel.rotate_selected_building(1))
	row.add_child(rot)
	for z in [["-", -1, "Zoom out"], ["+", 1, "Zoom in"]]:
		var zb := Button.new()
		zb.text = z[0]
		zb.tooltip_text = z[2]
		zb.custom_minimum_size = Vector2(24, 34)
		zb.focus_mode = Control.FOCUS_NONE
		var step: int = z[1]
		zb.pressed.connect(func(): _map_panel.apply_zoom_step(step))
		row.add_child(zb)
	# Cash and clock, right-aligned in sunken wells.
	var cash := Panel.new()
	cash.name = "Cash"
	cash.add_theme_stylebox_override("panel", T.box("field", Color8(0, 0, 0), Vector4.ZERO))
	_toolbar.add_child(cash)
	_money = Label.new()
	_money.add_theme_font_override("font", T.FONT_BOLD)
	_money.add_theme_color_override("font_color", Color8(80, 255, 80))
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cash.add_child(_money)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toolbar.add_child(_clock)
	_toolbar.resized.connect(func():
		cash.position = Vector2(_toolbar.size.x - 94, 4)
		cash.size = Vector2(90, 18)
		_money.position = Vector2(4, 2)
		_money.size = Vector2(80, 14)
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
	b.custom_minimum_size = Vector2(34, 34)
	b.icon = icon
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.add_theme_constant_override("icon_max_width", 28)
	return b


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
		_click()
	_active_cat = cid
	for k in _cat_buttons:
		_cat_buttons[k].set_pressed_no_signal(k == cid)
	for c in _cards.get_children():
		c.queue_free()
	if not cid.is_empty():
		for cat in CATEGORIES:
			if cat["id"] == cid:
				for t in cat["items"]:
					_cards.add_child(_make_card(str(t)))
	_layout()


func _click() -> void:
	var path := "res://assets/sfx/os98/click.mp3"
	if not ResourceLoader.exists(path):
		return
	if _sfx == null:
		_sfx = AudioStreamPlayer.new()
		_sfx.stream = load(path)
		_sfx.volume_db = -12.0
		add_child(_sfx)
	_sfx.play()


func _select(tool: String) -> void:
	_click()
	_selected = tool
	for k in _tool_buttons:
		_tool_buttons[k].set_pressed_no_signal(k == tool)
	for c in _cards.get_children():
		c.queue_redraw()
	_map_panel.set_selected_building(tool)
	if not tool.is_empty():
		_map_panel.call_deferred("grab_focus")
	_refresh_cost()


func _make_card(type: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(112, 40)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.tooltip_text = _tooltip(type)
	var icon := _texture(str(ITEM_ICONS.get(type, "")))
	c.draw.connect(func():
		var on := _selected == type
		c.draw_style_box(T.box("pressed" if on else "raised", Color8(208, 208, 208) if on else T.FACE, Vector4.ZERO), Rect2(Vector2.ZERO, c.size))
		var o := Vector2(1, 1) if on else Vector2.ZERO
		if icon != null:
			var isz := icon.get_size()
			var k := minf(32.0 / isz.x, 32.0 / isz.y)
			var d := (isz * k).floor()
			c.draw_texture_rect(icon, Rect2(Vector2(4, 4) + o + ((Vector2(32, 32) - d) * 0.5).floor(), d), false)
		var afford := CoreRoot.get_money() >= _cost(type)
		c.draw_string(T.FONT_BOLD, Vector2(40, 16) + o, str(SHORT_NAMES.get(type, type)), HORIZONTAL_ALIGNMENT_LEFT, 70, T.FONT_SIZE, T.TEXT)
		c.draw_string(T.FONT, Vector2(40, 31) + o, "$%d" % _cost(type), HORIZONTAL_ALIGNMENT_LEFT, 70, T.FONT_SIZE, T.TEXT if afford else Color8(160, 0, 0))
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select("" if _selected == type else type)
	)
	return c


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

func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_refresh_info()


func _refresh_info() -> void:
	if _money == null:
		return
	_money.text = "$%s" % _group(CoreRoot.get_money())
	var tree := get_tree()
	var main = tree.current_scene if tree != null else null
	var clock := str(main.call("_time_of_day_string")) if main != null and main.has_method("_time_of_day_string") else "--:--"
	_clock.text = "Day %d   %s" % [CoreRoot.get_day(), clock]
	_refresh_cost()


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
const PIX_COLORS := {
	"Y": Color8(240, 200, 0), "K": Color8(20, 20, 20), "D": Color8(110, 110, 110), "B": Color8(150, 150, 160),
	"T": Color8(110, 80, 40), "t": Color8(200, 170, 110), "d": Color8(160, 130, 80),
	"y": Color8(255, 240, 140), "G": Color8(90, 90, 96),
}


## The painted toolbar icons, falling back to the little pixel ones.
func _tool_art(id: String) -> Texture2D:
	var name: String = {"demolish": "bulldoze", "path": "path", "lamp_post": "lamp"}.get(id, id)
	var tex := _texture("res://assets/textury/builder/tb_%s.png" % name)
	return tex if tex != null else _tool_icon(id)


func _tool_icon(id: String) -> Texture2D:
	var rows: Array = TOOL_PIX.get(id, [])
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
