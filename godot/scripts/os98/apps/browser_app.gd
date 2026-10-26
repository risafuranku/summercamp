extends Control

## Beeternet Explorer 4: the menu bar, the "cool" toolbar (grey icons that light up under
## the mouse, scripts/os98/apps/browser_icons.gd), the spinning globe with its bee, the
## Address and Links bands, the page, and the status bar with its progress and zone
## cells. The first page of the session dials the modem. Typing a word that is not an
## address searches the Czech web (the portal's index). Download links ask, then hand the
## file to the shell.
##
## Pages (scripts/os98/web_pages.gd) arrive the way they did over 33.6k: the text in a
## couple of gulps, then the pictures one by one, interlaced. GIF banners rotate their
## frames once they are down; some pages are papered with a tile; [blink] blinks and
## [marquee] runs.
##
## Tabs (the user 20. 10.): the middle button on a link opens it in a tab behind; the
## strip shows from the second tab, a click picks one, the middle button or its x closes it.

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const OS_KEYS = preload("res://scripts/os98/os_keys.gd")
const WEB = preload("res://scripts/os98/web_pages.gd")
const ICONS = preload("res://scripts/os98/apps/browser_icons.gd")
const NBSP := " "
const LINK_RE := "\\{([^{}|]+)\\|([^{}]+)\\}"
const IMG_RE := "\\{\\{(img|banner):([a-z0-9_]+):([^{}]+)\\}\\}"
const WEB_IMG := "res://assets/textury/web/"
## Interlaced passes (GIF style): one row in 8, in 4, in 2, then the picture.
const PASSES := [8, 4, 2, 1]
const MENU_H := 18
const TOOL_H := 42
const BAND_H := 24
const STATUS_H := 20
const TAB_H := 20
const MAX_TABS := 8
const THROB_W := 50
const BANNER_FRAME := 2.6
const LINKS := [["Bohemia", "bohemia-online.cz"], ["Courier", "kuryr-hlubocany.cz"], ["Weather", "bohemia-online.cz/weather"], ["Camp", "cerne-jezero.cz"]]


## [blink]: on, off, the way Netscape meant it.
class BlinkFx extends RichTextEffect:
	var bbcode := "blink"

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		fx.visible = fmod(fx.elapsed_time, 1.0) < 0.62
		return true


## [marquee w=440 speed=40]: the line runs right to left inside w pixels and comes back
## round. Each letter's place along the line is summed from the glyph advances.
class MarqueeFx extends RichTextEffect:
	var bbcode := "marquee"
	var _acc := 0.0

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		var w := float(fx.env.get("w", 440.0))
		var speed := float(fx.env.get("speed", 40.0))
		if fx.relative_index == 0:
			_acc = 0.0
		var x0 := _acc
		_acc += TextServerManager.get_primary_interface().font_get_glyph_advance(fx.font, T.FONT_SIZE, fx.glyph_index).x
		var x := fposmod(x0 - floorf(fx.elapsed_time * speed), w)
		fx.offset.x += x - x0
		return true


var _shell
var _win
var _address: LineEdit
var _frame: Panel
var _page: RichTextLabel
var _status: Label
var _status_idle := "Done"
var _progress: Control
var _throbber: Control
var _tools: Array = []          # cool buttons, by id in their meta
var _history: Array[String] = []
var _hist_i := -1
var _url := ""
var _loading := 0.0
var _load_total := 1.0
var _reveal := -1.0
var _pending := ""
var _dial: Control
var _dial_label: Label
var _dial_t := -1.0
var _dial_then := ""
var _anim := 0.0
var _spin := 0.0
var _counters: Dictionary = {}
## Pages seen (kept on the machine between sittings: the visited links are purple).
var _visited: Dictionary = {}
var _link_re := RegEx.new()
var _img_re := RegEx.new()
## Pictures still coming down the line: [{key, src: Image, tex, pass, t, kb}]
var _pictures: Array = []
var _pic_i := 0
## Banners on the page: [{tex, frames: Array[Image], i, t, pic}]
var _banners: Array = []
var _menu: Control
var _menu_catch: Control
## Every tab's page and history ({url, history, hist_i, scroll}); the one shown lives in
## _url / _history / _hist_i and is written back on a switch.
var _tab_list: Array = []
var _tab := 0
var _tabbar: Control
var _hover_meta := ""


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	_link_re.compile(LINK_RE)
	_img_re.compile(IMG_RE)
	var seen = shell.stored("web_visited", {}) if shell.has_method("stored") else {}
	_visited = (seen as Dictionary).duplicate() if seen is Dictionary else {}
	_build()
	navigate(str(args.get("url", WEB.HOME)))


func reopen(args: Dictionary) -> void:
	if args.has("url"):
		navigate(str(args["url"]))


func closing() -> void:
	# Hang up when the browser closes: the call costs money by the minute.
	_shell.set_online(false)
	_shell.pointer_hand = false
	if _loading > 0.0 or _dial_t >= 0.0:
		_shell.set_busy(false)


# ── the chrome ───────────────────────────────────────────────────────────────

func _build() -> void:
	var chrome := Control.new()
	chrome.name = "Chrome"
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.draw.connect(_draw_chrome.bind(chrome))
	add_child(chrome)

	# The menu bar.
	var mx := 4.0
	for m in ["File", "View", "Go", "Favorites", "Help"]:
		var w := T.FONT.get_string_size(tr(m), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 12.0
		add_child(_menu_title(m, Vector2(mx, 1), Vector2(w, MENU_H - 2)))
		mx += w

	# The cool toolbar.
	var defs := [
		["back", "Back", func(): _go_history(-1)],
		["forward", "Forward", func(): _go_history(1)],
		["stop", "Stop", _stop],
		["refresh", "Refresh", func(): _load(_url, false)],
		["home", "Home", func(): navigate(WEB.HOME)],
		["|"],
		["search", "Search", func(): navigate(WEB.HOME + "/search")],
		["favorites", "Favorites", func(): _open_menu("Favorites", Vector2(0, MENU_H + TOOL_H))],
		["history", "History", func(): _open_menu("History", Vector2(0, MENU_H + TOOL_H))],
		["|"],
		["mail", "Mail", func(): _shell.open_app("mail")],
		["print", "Print", _print],
	]
	var x := 4.0
	for d in defs:
		if d[0] == "|":
			x += 6.0
			continue
		var b := _cool(str(d[0]), str(d[1]), d[2], Vector2(x, MENU_H + 1), Vector2(48, TOOL_H - 2))
		add_child(b)
		_tools.append(b)
		x += 48.0

	_throbber = Control.new()
	_throbber.size = Vector2(THROB_W, MENU_H + TOOL_H - 2)
	_throbber.mouse_filter = Control.MOUSE_FILTER_STOP
	_throbber.draw.connect(_draw_throbber)
	_throbber.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			navigate(WEB.HOME)
	)
	add_child(_throbber)

	# The Address band, the Links band beside it.
	var row := HBoxContainer.new()
	row.name = "AddressRow"
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var lab := Label.new()
	lab.text = "Address"
	lab.add_theme_color_override("font_color", T.TEXT)
	row.add_child(lab)
	_address = LineEdit.new()
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ab := T.box("field", T.WHITE, Vector4(22, 2, 4, 2)).duplicate() as StyleBoxTexture
	_address.add_theme_stylebox_override("normal", ab)
	_address.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_address.text_submitted.connect(func(t): navigate(t))
	row.add_child(_address)
	var page_icon := TextureRect.new()
	page_icon.texture = ICONS.get_icon("page")
	page_icon.position = Vector2(3, 1)
	page_icon.size = Vector2(16, 16)
	page_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	page_icon.stretch_mode = TextureRect.STRETCH_SCALE
	page_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_address.add_child(page_icon)
	var go := Button.new()
	go.text = "Go"
	go.custom_minimum_size = Vector2(30, 20)
	go.pressed.connect(func(): navigate(_address.text))
	row.add_child(go)

	var links := HBoxContainer.new()
	links.name = "LinksRow"
	links.add_theme_constant_override("separation", 0)
	add_child(links)
	var ll := Label.new()
	ll.text = "Links "
	links.add_child(ll)
	for l in LINKS:
		links.add_child(_link_button(str(l[0]), str(l[1])))

	# The page in its sunken frame.
	_frame = Panel.new()
	_frame.name = "PageFrame"
	_frame.add_theme_stylebox_override("panel", T.box("field", T.WHITE, Vector4.ZERO))
	add_child(_frame)
	_page = RichTextLabel.new()
	_page.bbcode_enabled = true
	_page.selection_enabled = false
	_page.meta_underlined = true
	_page.position = Vector2(2, 2)
	_page.install_effect(BlinkFx.new())
	_page.install_effect(MarqueeFx.new())
	_page.meta_clicked.connect(func(m): _on_link(str(m)))
	_page.meta_hover_started.connect(func(m):
		_hover_meta = str(m)
		_shell.pointer_hand = true
		_status.text = "Shortcut to " + _describe(str(m))
	)
	_page.meta_hover_ended.connect(func(_m):
		_hover_meta = ""
		_shell.pointer_hand = false
		_status.text = _status_idle
	)
	_page.mouse_exited.connect(func():
		_hover_meta = ""
		_shell.pointer_hand = false)
	_page.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_MIDDLE and _hover_meta != "":
			open_in_tab(_hover_meta)
			_page.accept_event()
	)
	_frame.add_child(_page)

	# The status bar: the text, the progress, the zone.
	var bar := Control.new()
	bar.name = "StatusBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_status.bind(bar))
	add_child(bar)
	_status = Label.new()
	_status.position = Vector2(24, 3)
	_status.clip_text = true
	bar.add_child(_status)
	_progress = bar

	_tabbar = Control.new()
	_tabbar.name = "TabBar"
	_tabbar.visible = false
	_tabbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_tabbar.draw.connect(_draw_tabs)
	_tabbar.gui_input.connect(_tab_input)
	add_child(_tabbar)
	_tab_list = [{"url": "", "history": [], "hist_i": -1, "scroll": 0}]

	_build_dialer()
	resized.connect(_layout)
	_layout()
	_layout.call_deferred()


func _layout() -> void:
	if _page == null:
		return
	var chrome: Control = get_node("Chrome")
	chrome.size = size
	_throbber.position = Vector2(size.x - THROB_W - 2, 1)
	var by := float(MENU_H + TOOL_H + 2)
	var links: Control = get_node("LinksRow")
	var lw := 0.0
	for c in links.get_children():
		lw += (c as Control).get_combined_minimum_size().x
	var row: Control = get_node("AddressRow")
	row.position = Vector2(8, by + 2)
	row.size = Vector2(size.x - lw - 28, 20)
	links.position = Vector2(size.x - lw - 6, by + 2)
	links.size = Vector2(lw, 20)
	var top := by + BAND_H + 2
	_tabbar.visible = _tab_list.size() > 1
	if _tabbar.visible:
		_tabbar.position = Vector2(0, top)
		_tabbar.size = Vector2(size.x, TAB_H)
		top += TAB_H
	_frame.position = Vector2(0, top)
	_frame.size = Vector2(size.x, size.y - top - STATUS_H - 1)
	_page.size = _frame.size - Vector2(4, 4)
	var bar: Control = get_node("StatusBar")
	bar.position = Vector2(0, size.y - STATUS_H)
	bar.size = Vector2(size.x, STATUS_H)
	_status.size = Vector2(size.x - 24 - 200, 14)
	_dial.position = ((size - _dial.size) * 0.5).floor()


## The etched lines between the bands, the grip at the start of each.
func _draw_chrome(c: Control) -> void:
	for y in [MENU_H, MENU_H + TOOL_H, MENU_H + TOOL_H + BAND_H + 2]:
		c.draw_rect(Rect2(0, y, size.x, 1), T.SHADOW)
		c.draw_rect(Rect2(0, y + 1, size.x, 1), T.WHITE)
	for y0 in [MENU_H + 3, MENU_H + TOOL_H + 5]:
		var h := TOOL_H - 6 if y0 == MENU_H + 3 else BAND_H - 6
		c.draw_rect(Rect2(1, y0, 1, h), T.WHITE)
		c.draw_rect(Rect2(2, y0, 1, h), T.SHADOW)
		c.draw_rect(Rect2(4, y0, 1, h), T.WHITE)
		c.draw_rect(Rect2(5, y0, 1, h), T.SHADOW)
	# The grip between the Address and the Links bands.
	var links: Control = get_node_or_null("LinksRow")
	if links != null:
		var gx := links.position.x - 8
		c.draw_rect(Rect2(gx, MENU_H + TOOL_H + 5, 1, BAND_H - 6), T.SHADOW)
		c.draw_rect(Rect2(gx + 1, MENU_H + TOOL_H + 5, 1, BAND_H - 6), T.WHITE)


## A toolbar button of the IE4 kind: flat; under the mouse a thin bevel and the icon in
## colour; pushed, sunk; disabled, an embossed grey.
func _cool(id: String, text: String, cb: Callable, pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("id", id)
	c.set_meta("hover", false)
	c.set_meta("down", false)
	c.set_meta("disabled", false)
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		c.queue_redraw()
	)
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		c.set_meta("down", false)
		c.queue_redraw()
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not bool(c.get_meta("disabled")):
			if e.pressed:
				c.set_meta("down", true)
			elif bool(c.get_meta("down")):
				c.set_meta("down", false)
				_shell.play("click", -14.0)
				cb.call()
			c.queue_redraw()
	)
	c.draw.connect(func():
		var hov := bool(c.get_meta("hover"))
		var down := bool(c.get_meta("down"))
		var dis := bool(c.get_meta("disabled"))
		if not dis and down:
			c.draw_style_box(T.box("well", T.FACE), Rect2(Vector2.ZERO, sz))
		elif not dis and hov:
			c.draw_style_box(T.box("thin_raised", T.FACE), Rect2(Vector2.ZERO, sz))
		var o := Vector2(1, 1) if down else Vector2.ZERO
		var ip := Vector2(floorf((sz.x - ICONS.S) * 0.5), 3) + o
		var label := tr(text)
		var tw := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var tp := Vector2(floorf((sz.x - tw) * 0.5), sz.y - 5) + o
		if dis:
			c.draw_texture(ICONS.get_icon(id, false), ip + Vector2(1, 1), Color(1, 1, 1, 0.9))
			c.draw_texture(ICONS.get_icon(id, false), ip, Color(0.55, 0.55, 0.55, 0.6))
			c.draw_string(T.FONT, tp + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
			c.draw_string(T.FONT, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.SHADOW)
		else:
			c.draw_texture(ICONS.get_icon(id, hov), ip)
			c.draw_string(T.FONT, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	)
	return c


func _tool_by(id: String) -> Control:
	for b in _tools:
		if str(b.get_meta("id")) == id:
			return b
	return null


func _set_tool_enabled(id: String, on: bool) -> void:
	var b := _tool_by(id)
	if b != null and bool(b.get_meta("disabled")) == on:
		b.set_meta("disabled", not on)
		b.queue_redraw()


func _link_button(text: String, target: String) -> Control:
	var label := tr(text)
	var w := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 26.0
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 20)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("hover", false)
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		_status.text = "Shortcut to " + _describe(target)
		c.queue_redraw()
	)
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		_status.text = _status_idle
		c.queue_redraw()
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			navigate(target)
	)
	c.draw.connect(func():
		if bool(c.get_meta("hover")):
			c.draw_style_box(T.box("thin_raised", T.FACE), Rect2(Vector2.ZERO, c.size))
		c.draw_texture_rect(ICONS.get_icon("page", bool(c.get_meta("hover"))), Rect2(3, 2, 16, 16), false)
		c.draw_string(T.FONT, Vector2(22, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	)
	return c


func _draw_status(bar: Control) -> void:
	var s := bar.size
	bar.draw_rect(Rect2(Vector2.ZERO, s), T.FACE)
	var zone_w := 110.0
	var prog_w := 90.0
	var text_r := Rect2(1, 2, s.x - zone_w - prog_w - 6, s.y - 3)
	var prog_r := Rect2(text_r.end.x + 2, 2, prog_w, s.y - 3)
	var zone_r := Rect2(prog_r.end.x + 2, 2, zone_w, s.y - 3)
	for r in [text_r, prog_r, zone_r]:
		bar.draw_style_box(T.box("well", T.FACE, Vector4.ZERO), r)
	bar.draw_texture_rect(ICONS.get_icon("page"), Rect2(4, 3, 16, 16), false)
	var p := _progress_value()
	if p >= 0.0:
		var n := int(p * 10.0)
		for i in n:
			bar.draw_rect(Rect2(prog_r.position.x + 3 + i * 8.5, prog_r.position.y + 3, 7, prog_r.size.y - 6), T.NAVY)
	# The zone: a little globe, "Internet".
	var gc := zone_r.position + Vector2(10, zone_r.size.y * 0.5)
	bar.draw_circle(gc, 6.0, Color8(40, 90, 200))
	bar.draw_circle(gc + Vector2(-2, -1), 2.5, Color8(60, 170, 70))
	bar.draw_circle(gc + Vector2(3, 2), 2.0, Color8(60, 170, 70))
	bar.draw_arc(gc, 6.0, 0, TAU, 16, T.DARK, 1.0)
	var zone := tr("Internet") if _shell.is_online() else tr("Offline")
	bar.draw_string(T.FONT, zone_r.position + Vector2(22, 13), zone, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)


func _progress_value() -> float:
	if _loading > 0.0:
		return clampf(1.0 - _loading / _load_total, 0.0, 1.0) * 0.6
	if _pic_i < _pictures.size():
		return 0.6 + 0.4 * float(_pic_i) / float(_pictures.size())
	return -1.0


## Beeternet's globe, turning while a page comes down, with the bee going round it.
func _draw_throbber() -> void:
	var s := _throbber.size
	_throbber.draw_style_box(T.box("well", Color8(0, 0, 0), Vector4.ZERO), Rect2(Vector2.ZERO, s))
	for i in int(s.y - 2):
		_throbber.draw_rect(Rect2(1, 1 + i, s.x - 2, 1), Color8(0, 0, 40).lerp(Color8(30, 40, 110), float(i) / s.y))
	var c := (s * 0.5).floor() + Vector2(0, 1)
	var r := 14.0
	var bee_a := _spin * 1.7
	var bee := c + Vector2(cos(bee_a) * 20.0, sin(bee_a) * 6.0 - 2.0)
	var bee_behind := sin(bee_a) < 0.0
	if bee_behind:
		_draw_bee(bee)
	# The sphere in 2 px cells: each cell's longitude turns with the spin.
	var cell := 2.0
	var y := -r
	while y < r:
		var x := -r
		while x < r:
			var px := x + cell * 0.5
			var py := y + cell * 0.5
			var d2 := px * px + py * py
			if d2 < r * r:
				var z := sqrt(r * r - d2)
				var lon := atan2(px, z) + _spin
				var lat := py / r
				var land := sin(lon * 2.0 + 0.6) + sin(lon * 3.0 + lat * 4.0) * 0.6 + cos(lat * 5.0) * 0.4
				var shade := 0.45 + 0.55 * (z / r) * (0.75 + 0.25 * (-px / r))
				var col := Color8(60, 170, 70) if land > 0.85 else Color8(40, 90, 220)
				if absf(lat) > 0.86:
					col = Color8(230, 240, 255)
				_throbber.draw_rect(Rect2(c + Vector2(x, y), Vector2(cell, cell)), Color(col.r * shade, col.g * shade, col.b * shade))
			x += cell
		y += cell
	if not bee_behind:
		_draw_bee(bee)


func _draw_bee(p: Vector2) -> void:
	p = p.floor()
	var flap := int(_anim * 30.0) % 2 == 0
	_throbber.draw_rect(Rect2(p + Vector2(-1, -4 if flap else -3), Vector2(3, 2)), Color(0.85, 0.92, 1.0, 0.9))
	_throbber.draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 3)), Color8(250, 200, 20))
	_throbber.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(1, 3)), Color8(20, 20, 20))
	_throbber.draw_rect(Rect2(p + Vector2(1, -1), Vector2(1, 3)), Color8(20, 20, 20))
	_throbber.draw_rect(Rect2(p + Vector2(3, 0), Vector2(1, 1)), Color8(20, 20, 20))


# ── the menus ────────────────────────────────────────────────────────────────

func _menu_title(text: String, pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("hover", false)
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		c.queue_redraw()
		# Once a menu is open, moving along the bar opens the next one.
		if _menu != null and is_instance_valid(_menu) and str(_menu.get_meta("title")) != text:
			_open_menu(text, Vector2(pos.x, MENU_H))
	)
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		c.queue_redraw()
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _menu != null and is_instance_valid(_menu) and str(_menu.get_meta("title")) == text:
				_close_menu()
			else:
				_open_menu(text, Vector2(pos.x, MENU_H))
	)
	c.draw.connect(func():
		var open := _menu != null and is_instance_valid(_menu) and str(_menu.get_meta("title")) == text
		if open:
			c.draw_style_box(T.box("well", T.FACE), Rect2(Vector2.ZERO, sz))
		elif bool(c.get_meta("hover")):
			c.draw_style_box(T.box("thin_raised", T.FACE), Rect2(Vector2.ZERO, sz))
		var label := tr(text)
		c.draw_string(T.FONT, Vector2(6, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
		# The underlined access key.
		var w := T.FONT.get_string_size(label.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		c.draw_rect(Rect2(6, 14, w, 1), T.TEXT)
	)
	return c


func _menu_entries(title: String) -> Array:
	match title:
		"File":
			return [["Work Offline", func(): _work_offline()], ["Print...", _print], ["-"], ["Close", func(): _shell.close_app_window(_win)]]
		"View":
			return [["Stop", _stop], ["Refresh", func(): _load(_url, false)], ["-"], ["Source", func(): _shell.message_box("Beeternet Explorer", "The source of this page cannot be viewed. Notepad was not found in C:\\OKNA.", "warning")]]
		"Go":
			return [["Back", func(): _go_history(-1)], ["Forward", func(): _go_history(1)], ["-"], ["Home Page", func(): navigate(WEB.HOME)], ["Search the Web", func(): navigate(WEB.HOME + "/search")]]
		"Favorites":
			var fav: Array = []
			for k in WEB.FAVORITES:
				fav.append([str(WEB.PAGES.get(k, {}).get("title", k)), func(): navigate(k)])
			return fav
		"History":
			var hist: Array = []
			var seen: Array = []
			for i in range(_history.size() - 1, -1, -1):
				var k: String = _history[i]
				if k in seen:
					continue
				seen.append(k)
				hist.append([_title_of(k), func(): navigate(k)])
				if hist.size() >= 12:
					break
			return hist if not hist.is_empty() else [["(empty)", Callable()]]
		"Help":
			return [["About Beeternet Explorer", func(): _shell.message_box("About Beeternet Explorer", "Beeternet Explorer 4.01\nVersion 4.72.3110.8\n\nCopyright (C) 1995-1997 Beesoft Corp.\n\nLicensed to: Kemp Cerne jezero\nThis product is licensed for use by one computer.", "info")]]
	return []


func _open_menu(title: String, at: Vector2) -> void:
	_close_menu()
	var entries := _menu_entries(title)
	var w := 150.0
	for e in entries:
		w = maxf(w, T.FONT.get_string_size(tr(str(e[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 44.0)
	var h := 4.0
	for e in entries:
		h += 8.0 if e[0] == "-" else 18.0
	# A transparent catcher: a click anywhere else shuts the menu.
	_menu_catch = Control.new()
	_menu_catch.size = size
	_menu_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_catch.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_menu()
	)
	add_child(_menu_catch)
	_menu = Control.new()
	_menu.set_meta("title", title)
	_menu.position = Vector2(minf(at.x, size.x - w), at.y)
	_menu.size = Vector2(w, h)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.draw.connect(func(): _menu.draw_style_box(T.box("window", T.FACE), Rect2(Vector2.ZERO, _menu.size)))
	add_child(_menu)
	var y := 2.0
	for e in entries:
		if e[0] == "-":
			var sep := Control.new()
			sep.position = Vector2(2, y)
			sep.size = Vector2(w - 4, 8)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sep.draw.connect(func():
				sep.draw_rect(Rect2(2, 3, w - 8, 1), T.SHADOW)
				sep.draw_rect(Rect2(2, 4, w - 8, 1), T.WHITE)
			)
			_menu.add_child(sep)
			y += 8.0
			continue
		_menu.add_child(_menu_item(tr(str(e[0])), e[1], Vector2(2, y), Vector2(w - 4, 18), title == "Favorites" or title == "History"))
		y += 18.0
	for c in get_children():
		if c is Control and c.has_meta("hover"):
			(c as Control).queue_redraw()


func _menu_item(text: String, cb: Callable, pos: Vector2, sz: Vector2, page_icon: bool) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("hover", false)
	var enabled := cb.is_valid()
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		c.queue_redraw()
	)
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		c.queue_redraw()
	)
	c.draw.connect(func():
		var hov := bool(c.get_meta("hover")) and enabled
		if hov:
			c.draw_rect(Rect2(Vector2.ZERO, sz), T.NAVY)
		if page_icon:
			c.draw_texture_rect(ICONS.get_icon("page"), Rect2(3, 1, 16, 16), false)
		var col := T.WHITE if hov else (T.TEXT if enabled else T.TEXT_DISABLED)
		c.draw_string(T.FONT, Vector2(22, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and enabled:
			_close_menu()
			cb.call()
			c.accept_event()
	)
	return c


func _close_menu() -> void:
	for n in [_menu, _menu_catch]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_menu = null
	_menu_catch = null
	for c in get_children():
		if c is Control and c.has_meta("hover"):
			(c as Control).queue_redraw()


func _work_offline() -> void:
	_stop()
	_shell.set_online(false)
	_status_idle = "Working offline."
	_status.text = _status_idle
	get_node("StatusBar").queue_redraw()


func _print() -> void:
	_shell.message_box("Print", "There is no printer installed.\n\nTo install a printer, open the Printers folder in My Computer.", "warning")


# ── navigation ───────────────────────────────────────────────────────────────

static func normalize(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	for p in ["http://", "https://", "www."]:
		s = s.trim_prefix(p)
	s = s.trim_suffix("/")
	for suffix in ["/index.htm", "/index.html"]:
		s = s.trim_suffix(suffix)
	return s


func navigate(raw: String) -> void:
	var s := raw.strip_edges()
	if s.is_empty():
		return
	var key := normalize(s)
	# A word, not an address: search.
	if key.find(".") < 0 and not key.begins_with("search?"):
		key = "search?q=" + key.uri_encode()
	if _hist_i < _history.size() - 1:
		_history.resize(_hist_i + 1)
	_history.append(key)
	_hist_i = _history.size() - 1
	_load(key, true)


func _go_history(step: int) -> void:
	var i := _hist_i + step
	if i < 0 or i >= _history.size():
		return
	_hist_i = i
	_load(_history[i], false)


func _load(key: String, _fresh: bool) -> void:
	if key.is_empty():
		return
	_address.text = _address_for(key)
	if not _shell.is_online():
		_dial_then = key
		_open_dialer()
		return
	_pending = key
	if _loading <= 0.0:
		_shell.set_busy(true)
	_loading = randf_range(0.5, 1.3) + (0.6 if not _shell.is_day() else 0.0)
	_load_total = _loading
	_status_idle = "Opening page %s..." % _describe(key)
	_status.text = "Finding site: www.%s" % key.split("/")[0]
	_set_tool_enabled("back", _hist_i > 0)
	_set_tool_enabled("forward", _hist_i < _history.size() - 1)
	_set_tool_enabled("stop", true)


func _address_for(key: String) -> String:
	if key.begins_with("search?"):
		return "http://www.bohemia-online.cz/" + key
	# A host with its own name in front (tv.bohemia-online.cz) has no www.
	var host := key.split("/")[0]
	var www := "" if host.count(".") >= 2 else "www."
	return "http://" + www + key + ("/" if key.find("/") < 0 else "")


func _describe(target: String) -> String:
	if target.begins_with("download://"):
		return target.trim_prefix("download://")
	return _address_for(normalize(target))


func _title_of(key: String) -> String:
	if key.begins_with("search?q="):
		return LANG.f("Search: %s", key.trim_prefix("search?q=").uri_decode())
	return str(WEB.PAGES.get(key, {}).get("title", "http://www." + key))


func _stop() -> void:
	if _loading > 0.0:
		_loading = 0.0
		_shell.set_busy(false)
		_status_idle = "Stopped."
		_status.text = _status_idle
	_pictures = _pictures.slice(0, _pic_i)
	_set_tool_enabled("stop", false)


func _process(delta: float) -> void:
	_anim += delta
	var busy := _loading > 0.0 or _pic_i < _pictures.size() or _dial_t >= 0.0
	if busy:
		_spin += delta * 3.2
		_throbber.queue_redraw()
		if _shell.has_method("net_activity"):
			_shell.net_activity()
	if _loading > 0.0:
		_loading -= delta
		get_node("StatusBar").queue_redraw()
		if _loading <= 0.0:
			_shell.set_busy(false)
			_show(_pending)
	if _reveal >= 0.0:
		# The text comes in two or three gulps, the way the HTML did.
		_reveal += delta
		var k := clampf(floorf(_reveal / 0.12) / 3.0, 0.0, 1.0)
		_page.visible_ratio = k
		if k >= 1.0:
			_reveal = -1.0
	if _dial_t >= 0.0:
		_tick_dialer(delta)
	if _pic_i < _pictures.size() and _loading <= 0.0 and _reveal < 0.0:
		_tick_pictures(delta)
	_tick_banners(delta)


## The page's text at once, the pictures as grey boxes that fill in one by one.
func _set_page(bbcode: String) -> void:
	_page.clear()
	_pictures.clear()
	_banners.clear()
	_pic_i = 0
	var pos := 0
	for m in _img_re.search_all(bbcode):
		_page.append_text(bbcode.substr(pos, m.get_start() - pos))
		if m.get_string(1) == "banner":
			_add_banner(m.get_string(2), m.get_string(3))
		else:
			_add_picture(m.get_string(2), int(m.get_string(3)))
		pos = m.get_end()
	_page.append_text(bbcode.substr(pos))


func _load_image(file: String) -> Image:
	var path := WEB_IMG + file + ".png"
	if not ResourceLoader.exists(path):
		return null
	var src: Image = (load(path) as Texture2D).get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGB8)
	return src


func _add_picture(file: String, width: int) -> ImageTexture:
	var src := _load_image(file)
	if src == null:
		return null
	var w := width
	var h := maxi(1, int(round(float(src.get_height()) * float(w) / float(src.get_width()))))
	src.resize(w, h, Image.INTERPOLATE_NEAREST)
	var key := "pic%d" % _pictures.size()
	var tex := ImageTexture.create_from_image(_placeholder(w, h))
	_page.add_image(tex, w, h, Color.WHITE, INLINE_ALIGNMENT_CENTER, Rect2(), key)
	# A rough size for the status line: what a 1998 JPEG of this would weigh.
	_pictures.append({"key": key, "src": src, "tex": tex, "pass": -1, "t": 0.0, "kb": maxi(2, w * h / 1800)})
	return tex


## A GIF banner, 468x60, a link: its frames turn once the first one is down. After dark
## the last frame is another one.
func _add_banner(id: String, target: String) -> void:
	var frames: Array = []
	for n in 3:
		var img := _load_image("banner_%s_%d" % [id, n])
		if img != null:
			frames.append(img)
	if frames.is_empty():
		return
	if not _shell.is_day():
		var night := _load_image("banner_%s_night" % id)
		if night != null:
			frames[frames.size() - 1] = night
	_page.push_meta(target)
	var tex := _add_picture("banner_%s_0" % id, 468)
	_page.pop()
	if tex != null:
		_banners.append({"tex": tex, "frames": frames, "i": 0, "t": 0.0, "pic": _pictures.size() - 1})


func _tick_banners(delta: float) -> void:
	for b in _banners:
		if _pic_i <= int(b["pic"]):
			continue
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) >= BANNER_FRAME:
			b["t"] = 0.0
			b["i"] = (int(b["i"]) + 1) % (b["frames"] as Array).size()
			(b["tex"] as ImageTexture).update(b["frames"][int(b["i"])])


## The empty picture frame IE drew while waiting: a sunken grey box, a tiny icon.
static func _placeholder(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.75, 0.75, 0.75))
	for x in w:
		img.set_pixel(x, 0, Color(0.5, 0.5, 0.5))
		img.set_pixel(x, h - 1, Color(1, 1, 1))
	for y in h:
		img.set_pixel(0, y, Color(0.5, 0.5, 0.5))
		img.set_pixel(w - 1, y, Color(1, 1, 1))
	for y in range(3, mini(h - 1, 12)):
		for x in range(3, mini(w - 1, 12)):
			var edge := x == 3 or y == 3 or x == 11 or y == 11
			img.set_pixel(x, y, Color(0.3, 0.3, 0.3) if edge else (Color(0.2, 0.6, 0.3) if y > 8 else Color(0.5, 0.7, 0.95)))
	return img


## One picture at a time down the modem: each pass takes longer for a bigger picture.
func _tick_pictures(delta: float) -> void:
	var p: Dictionary = _pictures[_pic_i]
	p["t"] = float(p["t"]) + delta
	var per_pass := 0.12 + float(p["kb"]) * 0.018
	if float(p["t"]) < per_pass:
		return
	p["t"] = 0.0
	p["pass"] = int(p["pass"]) + 1
	var src: Image = p["src"]
	var k: int = PASSES[clampi(int(p["pass"]), 0, PASSES.size() - 1)]
	var img := src.duplicate() as Image
	if k > 1:
		img.resize(src.get_width(), maxi(1, src.get_height() / k), Image.INTERPOLATE_NEAREST)
		img.resize(src.get_width(), src.get_height(), Image.INTERPOLATE_NEAREST)
	(p["tex"] as ImageTexture).update(img)
	var done_kb := int(float(p["kb"]) * float(int(p["pass"]) + 1) / float(PASSES.size()))
	_status.text = "Downloading picture %d of %d (%d of %d KB)..." % [_pic_i + 1, _pictures.size(), done_kb, int(p["kb"])]
	if int(p["pass"]) >= PASSES.size() - 1:
		_pic_i += 1
		if _pic_i >= _pictures.size():
			_status_idle = "Done"
			_status.text = _status_idle
			_set_tool_enabled("stop", false)
	get_node("StatusBar").queue_redraw()


func _show(key: String) -> void:
	_url = key
	_address.text = _address_for(key)
	var page := _page_for(key)
	var bg := Color.html(str(page.get("bg", "#ffffff")))
	var tile := str(page.get("tile", ""))
	var sb: StyleBox = T.flat(bg, Vector4(8, 6, 8, 6))
	if tile != "" and ResourceLoader.exists(WEB_IMG + tile + ".png"):
		var st := StyleBoxTexture.new()
		st.texture = load(WEB_IMG + tile + ".png")
		st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		st.content_margin_left = 8
		st.content_margin_top = 6
		st.content_margin_right = 8
		st.content_margin_bottom = 6
		sb = st
	_page.add_theme_stylebox_override("normal", sb)
	_page.add_theme_color_override("default_color", Color.html(str(page.get("fg", "#000000"))))
	# The page in the warden's language before its links are made ({site|Label} kept by
	# the lookup: lang._forms).
	_set_page(_expand(tr(str(page.get("body", ""))), str(page.get("link", "#0000ee")), key))
	_page.scroll_to_line(0)
	_page.visible_ratio = 0.0
	_reveal = 0.0
	_win.title = "%s - Beeternet Explorer" % tr(str(page.get("title", key)))
	if _tabbar != null:
		_tabbar.queue_redraw()
	_status_idle = "Done" if _pictures.is_empty() else "Downloading picture 1 of %d..." % _pictures.size()
	_status.text = _status_idle
	if _pictures.is_empty():
		_set_tool_enabled("stop", false)
	_throbber.queue_redraw()
	get_node("StatusBar").queue_redraw()
	_counters[key] = int(_counters.get(key, 0)) + 1
	if not _visited.has(key):
		_visited[key] = true
		if _shell.has_method("store"):
			_shell.store("web_visited", _visited.duplicate())


func _page_for(key: String) -> Dictionary:
	if key.begins_with("search?q="):
		return _search_page(key.trim_prefix("search?q=").uri_decode())
	if WEB.PAGES.has(key):
		return WEB.PAGES[key]
	return {
		"title": "Cannot find server",
		"bg": "#ffffff", "fg": "#000000", "link": "#0000ee",
		"body": "[font_size=18][b]The page cannot be displayed[/b][/font_size]\n\nThe page you are looking for is currently unavailable. The Web site might be experiencing technical difficulties, or you may need to adjust your browser settings.\n\n" + WEB.HR + "\n\n[b]Please try the following:[/b]\n * Click the Refresh button, or try again later.\n * If you typed the page address in the Address bar, make sure that it is spelled correctly.\n * Click the Back button to try another link.\n\n[b]Cannot find server or DNS Error[/b]\nhttp://www.%s\n\n{%s|Go to the Bohemia Online start page}" % [key, WEB.HOME],
	}


## SoftSklad's four programs: the licence to buy, or (bought) the download.
func _softsklad() -> String:
	var R = load("res://core/systems/business_rules.gd")
	var files := {"pub": "HOSPOD98.EXE", "rest": "KUCHAR98.EXE", "vecerka": "PULT98.EXE", "corn": "KLASEK98.EXE", "staff": "PERSON98.EXE"}
	var blurbs := {"pub": "for pubs and bars: kegs, spirits, kofola, glasses", "rest": "for canteens and bistros: the kitchen's stock, portions", "vecerka": "for shops: bread, rolls, salami, milk, beer", "corn": "for stands: cobs and butter", "staff": "for your own staff: hiring, lockers, who sees to what"}
	var t := ""
	for k in ["pub", "rest", "vecerka", "corn", "staff"]:
		var info: Dictionary = R.info(k)
		t += "[b]%s[/b] - %s\n" % [str(info["app_name"]), str(blurbs[k])]
		if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.biz_has_licence(k):
			t += " [color=#006600]Licensed.[/color] {download://%s|%s}\n\n" % [files[k], files[k]]
		else:
			t += " {licence://%s|Buy a licence - $%d}\n\n" % [k, int(info["licence"])]
	return t


## PC Servis's order line: the button, or where the order is.
func _pcservis() -> String:
	var post = _shell.post_delivery() if _shell.has_method("post_delivery") else null
	if post == null:
		return ""
	match post.stage():
		"":
			return "[center]{order://monitor2|[b]>> ORDER THE SET <<[/b]}[/center]"
		"delivered":
			return "[color=#006600][b]Order no. %d: delivered. Thank you for your custom.[/b][/color]" % post.order_no()
	return "[color=#006600][b]Order no. %d: sent. The post brings it.[/b][/color]" % post.order_no()


func _on_link(target: String) -> void:
	# PC Servis's set (scripts/reception/post_delivery.gd): paid now, the post brings it.
	if target == "order://monitor2":
		var post = _shell.post_delivery() if _shell.has_method("post_delivery") else null
		if post == null or post.stage() != "":
			_load(_url, false)
			return
		_shell.message_box("PC Servis Hlubocany", LANG.f("Order the monitor and the second card for $%d?\n\nThe money is taken from the camp's account.", post.PRICE), "question", ["Order", "Cancel"], func(b: String):
			if b != "Order":
				return
			if post.order():
				_shell.play("click", -8.0)
				_load(_url, false)
				_shell.message_box("PC Servis Hlubocany", LANG.f("Thank you. Order no. %d.\n\nThe post brings it in a few hours.", post.order_no()), "info")
			else:
				_shell.message_box("PC Servis Hlubocany", LANG.f("The payment was refused.\n\nThe camp has $%d.", CoreRoot.get_money()), "error")
		)
		return
	# A SoftSklad licence: paid from the camp's money, the download appears.
	if target.begins_with("licence://"):
		var kind := target.trim_prefix("licence://")
		var info: Dictionary = load("res://core/systems/business_rules.gd").info(kind)
		_shell.message_box("SoftSklad", "Buy a licence for %s for $%d?\n\nThe money is taken from the camp's account." % [str(info.get("app_name", "")), int(info.get("licence", 0))], "question", ["Buy", "Cancel"], func(b: String):
			if b != "Buy":
				return
			if CoreRoot.actions.biz_buy_licence(kind):
				_shell.play("click", -8.0)
				_load(_url, false)
			else:
				_shell.message_box("SoftSklad", "The payment was refused.\n\nThe camp has $%d." % CoreRoot.get_money(), "error")
		)
		return
	# The bazaar's "put it up" (bazaar://list/ID): the ad goes up, the page comes again.
	if target.begins_with("bazaar://list/"):
		var m: Node = _shell.main_node()
		if m != null and m.has_method("bazaar_list"):
			m.bazaar_list(int(target.trim_prefix("bazaar://list/")))
		_shell.play("click", -8.0)
		_load(_url, false)
		return
	if target.begins_with("download://"):
		var file := target.trim_prefix("download://")
		_shell.message_box("File Download", "You have chosen to download a file from this location.\n\n%s from www.%s\n\nSave this program to disk (C:\\DOWNLOAD)?" % [file, _url.split("/")[0]], "question", ["Save", "Cancel"], func(b: String):
			if b == "Save":
				_shell.start_download(file, "http://www." + _url)
		)
		return
	navigate(target)


# ── tabs ─────────────────────────────────────────────────────────────────────

## A link in a tab of its own, behind the one you read (the middle button). A licence,
## a download or a bazaar ad has no page of its own: it goes as a plain click.
func open_in_tab(target: String) -> void:
	if target.contains("://"):
		_on_link(target)
		return
	var key := normalize(target)
	if _tab_list.size() >= MAX_TABS:
		_shell.play("ding", -12.0)
		_status.text = "Too many windows open. Close one first."
		return
	# Online it comes down behind the one you read; offline it waits for the modem.
	_tab_list.insert(_tab + 1, {"url": key if _shell.is_online() else "", "history": [key], "hist_i": 0, "scroll": 0})
	_shell.play("click", -12.0)
	_status.text = "Opened in a new tab: " + _describe(key)
	_layout()
	_tabbar.queue_redraw()


func _save_tab() -> void:
	_tab_list[_tab] = {"url": _url, "history": _history.duplicate(), "hist_i": _hist_i, "scroll": int(_page.get_v_scroll_bar().value)}


func select_tab(i: int) -> void:
	if i < 0 or i >= _tab_list.size() or i == _tab:
		return
	_save_tab()
	_tab = i
	var t: Dictionary = _tab_list[i]
	_history.assign(t["history"])
	_hist_i = int(t["hist_i"])
	_set_tool_enabled("back", _hist_i > 0)
	_set_tool_enabled("forward", _hist_i < _history.size() - 1)
	_tabbar.queue_redraw()
	if str(t["url"]) == "":
		if _hist_i >= 0 and _hist_i < _history.size():
			_load(_history[_hist_i], false)
		return
	# A tab behind came in while you read the other one: it is there at once.
	if _loading > 0.0:
		_loading = 0.0
		_shell.set_busy(false)
	_show(str(t["url"]))
	_page.visible_ratio = 1.0
	_reveal = -1.0
	for pic in _pictures:
		(pic["tex"] as ImageTexture).update(pic["src"])
	_pic_i = _pictures.size()
	_status_idle = "Done"
	_status.text = _status_idle
	_set_tool_enabled("stop", false)
	var sc := int(t.get("scroll", 0))
	(func(): _page.get_v_scroll_bar().value = sc).call_deferred()


func close_tab(i: int) -> void:
	if _tab_list.size() <= 1 or i < 0 or i >= _tab_list.size():
		return
	_shell.play("click", -12.0)
	if i == _tab:
		_tab_list.remove_at(i)
		_tab = -1
		select_tab(mini(i, _tab_list.size() - 1))
	else:
		_tab_list.remove_at(i)
		if i < _tab:
			_tab -= 1
	_layout()
	_tabbar.queue_redraw()


func _tab_rects() -> Array:
	var n := _tab_list.size()
	var w := floorf(minf(150.0, (size.x - 4.0) / float(n)))
	var out: Array = []
	for i in n:
		out.append(Rect2(2 + i * w, 2, w - 1, TAB_H - 2))
	return out


func _tab_title(i: int) -> String:
	var t: Dictionary = _tab_list[i]
	var key := _url if i == _tab else str(t["url"])
	if key == "":
		var h: Array = t["history"]
		key = str(h[int(t["hist_i"])]) if not h.is_empty() else ""
	return _title_of(key) if key != "" else "about:blank"


func _draw_tabs() -> void:
	var c := _tabbar
	c.draw_rect(Rect2(Vector2.ZERO, c.size), T.FACE)
	c.draw_rect(Rect2(0, c.size.y - 1, c.size.x, 1), T.WHITE)
	var rects := _tab_rects()
	for i in rects.size():
		var r: Rect2 = rects[i]
		var on := i == _tab
		if not on:
			r = Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 2))
		c.draw_rect(r, T.FACE if not on else T.LIGHT)
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), T.WHITE)
		c.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), T.WHITE)
		c.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 1), T.DARK)
		c.draw_rect(Rect2(r.end.x - 2, r.position.y + 1, 1, r.size.y - 1), T.SHADOW)
		if on:
			c.draw_rect(Rect2(r.position.x + 1, c.size.y - 1, r.size.x - 2, 1), T.LIGHT)
		c.draw_texture_rect(ICONS.get_icon("page"), Rect2(r.position.x + 3, r.position.y + 1, 16, 16), false)
		c.draw_string(T.FONT_BOLD if on else T.FONT, Vector2(r.position.x + 21, r.position.y + 13), tr(_tab_title(i)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, T.FONT_SIZE, T.TEXT)
		# The x that closes it.
		var x := Vector2(r.end.x - 11, r.position.y + 5)
		for k in 5:
			c.draw_rect(Rect2(x + Vector2(k, k), Vector2(2, 1)), T.TEXT)
			c.draw_rect(Rect2(x + Vector2(4 - k, k), Vector2(2, 1)), T.TEXT)


func _tab_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or not e.pressed:
		return
	var rects := _tab_rects()
	for i in rects.size():
		var r: Rect2 = rects[i]
		if not r.has_point(e.position):
			continue
		if e.button_index == MOUSE_BUTTON_MIDDLE or (e.button_index == MOUSE_BUTTON_LEFT and e.position.x > r.end.x - 14):
			close_tab(i)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if i != _tab:
				_shell.play("click", -14.0)
			select_tab(i)
		_tabbar.accept_event()
		return


# ── page content ─────────────────────────────────────────────────────────────

func _expand(body: String, link: String, key: String) -> String:
	var t := body
	if t.find("{{") >= 0:
		t = t.replace("{{search}}", "\n[center][bgcolor=#e0e8ff] [b]Search the Czech web:[/b] type a word in the Address bar and press Go. [/bgcolor][/center]\n")
		t = t.replace("{{day}}", str(_day()))
		t = t.replace("{{date}}", _date(_day()))
		t = t.replace("{{time}}", _time())
		t = t.replace("{{counter}}", _counter(key))
		t = t.replace("{{weather}}", _weather())
		t = t.replace("{{forecast}}", _forecast())
		t = t.replace("{{guestbook}}", _guestbook())
		t = t.replace("{{bazaar}}", _bazaar())
		t = t.replace("{{level}}", _level())
		t = t.replace("{{softsklad}}", _softsklad())
		t = t.replace("{{pcservis}}", _pcservis())
		t = t.replace("{{chat}}", _chat())
		t = t.replace("{{chatcount}}", "%d people here" % (9 + _day() % 5 + (1 if not _shell.is_day() else 0)))
		t = t.replace("{{horoscope}}", _horoscope())
		t = t.replace("{{news}}", _news())
		t = t.replace("{{headline}}", _headline())
		t = t.replace("{{tv}}", _tv())
		t = t.replace("{{agro_days}}", _agro_days())
	t = _pad_marquees(t)
	# Links to pages already seen in the visited colour, as every browser did.
	var vlink := _vlink_for(link)
	var out := ""
	var pos := 0
	for m in _link_re.search_all(t):
		var target := m.get_string(1)
		var col := vlink if _visited.has(normalize(target)) and target.find("://") < 0 else link
		out += t.substr(pos, m.get_start() - pos) + "[url=%s][color=%s]%s[/color][/url]" % [target, col, m.get_string(2)]
		pos = m.get_end()
	return out + t.substr(pos)


## The visited colour beside a page's link colour: purple on a light page, lilac on a dark one.
static func _vlink_for(link: String) -> String:
	var c := Color.html(link) if Color.html_is_valid(link) else Color8(0, 0, 238)
	return "#cc99ff" if c.get_luminance() > 0.45 else "#551a8b"


## Keys the way Beeternet had them: Backspace or Alt+Left back, Alt+Right forward, F5
## again (not while you type into the address).
func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or not (e is InputEventKey) or not e.pressed or e.echo or not OS_KEYS.here(self):
		return
	if _shell.wants_keyboard() or _shell.has_dialog():
		return
	var k: int = e.keycode
	if k == KEY_BACKSPACE or (e.alt_pressed and k == KEY_LEFT):
		_go_history(-1)
	elif e.alt_pressed and k == KEY_RIGHT:
		_go_history(1)
	elif k == KEY_F5:
		_load(_url, false)
	elif e.ctrl_pressed and k == KEY_TAB and _tab_list.size() > 1:
		select_tab(wrapi(_tab + (-1 if e.shift_pressed else 1), 0, _tab_list.size()))
	elif e.ctrl_pressed and k == KEY_W and _tab_list.size() > 1:
		close_tab(_tab)
	else:
		return
	get_viewport().set_input_as_handled()


## A marquee's line is padded out to its width with no-break spaces, so its band of
## colour runs the whole way and the letters come round inside it.
func _pad_marquees(t: String) -> String:
	if t.find("[marquee") < 0:
		return t
	var re := RegEx.new()
	re.compile("\\[marquee w=(\\d+)([^\\]]*)\\]([^\\[]*)\\[/marquee\\]")
	var out := ""
	var pos := 0
	for m in re.search_all(t):
		var w := float(m.get_string(1))
		var text := m.get_string(3)
		var tw := T.FONT_BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var nb := maxf(1.0, T.FONT_BOLD.get_string_size(NBSP, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x)
		var n := maxi(1, int(ceilf((w - tw) / nb)))
		var padded := text + NBSP.repeat(n)
		var real_w := T.FONT_BOLD.get_string_size(padded, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		out += t.substr(pos, m.get_start() - pos) + "[marquee w=%d%s]%s[/marquee]" % [int(real_w), m.get_string(2), padded]
		pos = m.get_end()
	return out + t.substr(pos)


func _day() -> int:
	return CoreRoot.get_day() if CoreRoot != null else 1


func _time() -> String:
	var m: Node = _shell.main_node()
	return str(m.call("_time_of_day_string")) if m != null and m.has_method("_time_of_day_string") else "--:--"


## The calendar: day 1 is Saturday 19 September 1998 (core/systems/season.gd).
func _date(day: int) -> String:
	return Season.date_str(day)


## The counter, in the black box with the green digits every page had.
func _counter(key: String) -> String:
	var base := 1000 + (absi(key.hash()) % 7000)
	var n := base + _day() * 3 + int(_counters.get(key, 0))
	if key == "cerne-jezero.cz" and not _shell.is_day():
		# At night the camp's counter counts something else.
		n = _in_camp() + 1
	return "[bgcolor=#000000][color=#33ff33][code] %06d [/code][/color][/bgcolor]" % n


func _in_camp() -> int:
	var n := 0
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state != null:
		for g in state.guests:
			if g is Dictionary and str(g.get("status", "")) in ["active", "sleep"]:
				n += maxi(1, int(g.get("party_size", 1)))
	return n


func _weather_state() -> int:
	var m: Node = _shell.main_node()
	return int(m.get("_weather_state")) if m != null and m.get("_weather_state") != null else 0


const WX_NAMES := ["clear", "windy", "fog", "light rain", "rain", "thunderstorms", "fog"]
const WX_ICONS := ["sun", "suncloud", "fog", "cloud", "rain", "storm", "fog"]


func _weather() -> String:
	var w := clampi(_weather_state(), 0, 6)
	var day := _day()
	var wx_name: String = WX_NAMES[w]
	var icon: String = WX_ICONS[w]
	if (w == 3 or w == 4 or w == 5) and Season.precip_is_snow(day, 12.0):
		wx_name = "snow"
		icon = "cloud"
	var t := "{{img:wx_%s:40}}  [b]Now, Vysocina:[/b] %s, %d degrees\n" % [icon, wx_name, Season.temp_high(day) - 2]
	var low := Season.temp_low(day)
	var night_word := "fog in the valleys" if w == 2 or w == 6 else ("ground frost" if low <= 0 else "mostly clear, cool")
	t += "[b]Tonight:[/b] %s, %d to %d degrees.\n" % [night_word, low, low + 3]
	if Season.hard_frost(day):
		t += "[color=#0044aa][b]Frost warning:[/b] drain outdoor water pipes and pumps.[/color]\n"
	if w == 6:
		t += "\n[color=#cc0000][blink]The reservoir station reports.[/blink] Reading: 0 0 0 0 0 0[/color]\n"
	return t


## Three days ahead, each with its icon. The fourth day the forecast does not reach.
func _forecast() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1998 + _day()
	var t := "[table=4]"
	for i in 4:
		var d := _day() + i + 1
		t += "[cell padding=6,2,14,2][center][b]%s[/b] %s\n" % [Season.weekday_short(d), Season.date_short(d)]
		if i == 3:
			t += "{{img:wx_fog:40}}\n[color=#888888]no data[/color][/center][/cell]"
		else:
			var p := Season.progress(d)
			var pool: Array = ["sun", "suncloud", "suncloud", "cloud", "rain"] if p < 0.4 else ["suncloud", "cloud", "fog", "rain", "rain"]
			var icon: String = pool[rng.randi_range(0, pool.size() - 1)]
			var hi := Season.temp_high(d) + rng.randi_range(-2, 2)
			var lo := Season.temp_low(d) + rng.randi_range(-1, 1)
			if icon == "rain" and Season.precip_is_snow(d, 12.0):
				icon = "cloud"
			t += "{{img:wx_%s:40}}\n%d / %d C[/center][/cell]" % [icon, hi, lo]
	return t + "[/table]"


## The reservoir's water level by day: it should go down in a dry September. It does not.
func _level() -> String:
	var t := "[code]date         level    inflow  outflow\n"
	var lvl := 512.40
	for i in range(-6, 1):
		var d := _day() + i
		var label := Season.date_str(d)
		if d >= 1:
			lvl += 0.04
		t += "%-12s %6.2f m   %s     %s\n" % [label, lvl, "0.0" if d >= 1 else "0.4", "0.3"]
	return t + "[/code]"


## Old entries, then new ones as the week goes on. Some are written tonight.
## The camp's ads on the bazaar: the lost and found (to put up), what is up, what went.
func _bazaar() -> String:
	var m: Node = _shell.main_node()
	var b = m.get("_bazaar") if m != null else null
	if b == null:
		return ""
	var box: Array = b.in_box()
	var up: Array = b.listed()
	var gone: Array = b.sold()
	if box.is_empty() and up.is_empty() and gone.is_empty():
		return "[color=#888888]Nothing in the lost and found.[/color]\n"
	var t := ""
	for it in box:
		var src := "nobody left it, found %s" % _date(int(it["found_day"]))
		if str(it["from"]) != "":
			src = "left by %s%s, %s" % [str(it["from"]), (" in " + str(it["where"])) if str(it["where"]) != "" else "", _date(int(it["found_day"]))]
		t += "[b]%s[/b] - %s [color=#666666](%s)[/color]   {bazaar://list/%d|put it up for $%d}\n" % [str(it["short"]), str(it["name"]), src, int(it["id"]), int(it["value"])]
	for it in up:
		var looked := 2 + (int(it["id"]) * 7 + _day() * 5) % 19
		t += "[b]%s[/b]  $%d   [color=#666666]up since %s, %d looked[/color]\n" % [str(it["short"]), int(it["value"]), _date(int(it["listed_day"])), looked]
	for it in gone:
		t += "[color=#888888]%s[/color]   [color=#008800][b]SOLD $%d[/b][/color]\n" % [str(it["short"]), int(it["price"])]
	return t


func _guestbook() -> String:
	var rows: Array = [
		["Petr & Jitka", "12.7.1997", "Great week!! The lake is freezing but beautiful. The night game with Karel was SO scary :-)"],
		["Tomas", "2.8.1997", "who was the man in the hat at the disco? he stood by the door the whole time and didnt dance. nobody knew him"],
		["Lucie (mum of Ondra)", "16.8.1997", "Ondra came back with only one shoe. Not red, I checked, ha ha. Thank you Vera for everything."],
		["Honza", "21.8.1997", "the photos from the night game came out all black except one. who is that by the fence"],
		["-", "1.1.1998", "1987"],
		["Martina", "15.6.1998", "Is the camp open this year? Nobody answers the phone."],
	]
	var day := _day()
	var guests := _in_camp()
	var night: bool = not _shell.is_day()
	if day >= 2:
		rows.append(["karel", _date(day - 1) + "  23:58", "whoever is minding the camp now: count them at ten and at midnight. write it down. dont stay up past one"])
	if day >= 6:
		rows.append(["Jana", _date(day - 1) + "  02:10", "has anyone seen my shoe"])
	if day >= 11:
		rows.append(["(no name)", _date(day - 1) + "  03:33", "smile :)"])
	if day >= 16:
		rows.append(["Vera", _date(day - 1) + "  21:15", "I am at my sister's. Please do not write here any more. The district reads it."])
	if night and guests > 0:
		rows.append(["(no name)", _date(day) + "  " + _time(), "you have %d in the camp tonight. we counted %d" % [guests, guests + 1]])
	var t := ""
	for i in range(rows.size() - 1, -1, -1):
		var r: Array = rows[i]
		t += "[color=#808080]________________________________________[/color]\n"
		t += "[b][color=#66ff66]%s[/color][/b]  [color=#aaaaaa]%s[/color]\n%s\n" % [r[0], r[1], r[2]]
	return t + "[color=#808080]________________________________________[/color]\n[color=#aaaaaa]The guest book is full. New entries cannot be added.[/color]\n"


## The chat room #jih, as far as it has got today: who said what, by the clock. After
## dark, later in the month, somebody logs in with the camp's own name.
const CHAT_DAY := [
	["08:12", "Hanka_17", "ahoj everybody"],
	["08:13", "Hanka_17", "a/s/l?"],
	["08:15", "Pepa_CB", "18/m/Budejovice. you?"],
	["08:15", "Hanka_17", "17/f/Tabor. bye"],
	["09:40", "Jarda", "does anyone know how to turn off the modem noise. my wife hears it upstairs"],
	["09:41", "kosmonaut", "Jarda put a pillow on it"],
	["10:02", "Pepa_CB", "who has the new Lucie CD. I will swap for Kabat"],
	["11:30", "HokejNagano", "JAGR!!! still cannot believe it"],
	["11:30", "HokejNagano", "HASEK!!!!!!!!"],
	["12:05", "Mirek_Liblice", "is the Jednota in Liblice open on saturday"],
	["12:06", "Jarda", "till 11. no batteries"],
	["12:06", "Mirek_Liblice", "there are never batteries"],
	["13:20", "kosmonaut", "anyone going to the Infravrany gig in Jihlava"],
	["14:44", "Zdena", "how do I make the letters bigger"],
	["14:51", "Zdena", "HOW DO I MAKE THE LETTERS SMALLER"],
	["15:10", "Pepa_CB", "the 380 bus did not stop at the dam again"],
	["15:11", "Mirek_Liblice", "it never stops at the dam after dark"],
	["15:11", "Pepa_CB", "it is 3 in the afternoon"],
	["16:30", "Jarda", "the old camp by the reservoir is open again? saw lights"],
	["16:32", "kosmonaut", "some nephew is running it. good luck to him"],
	["17:45", "Hanka_17", "is anyone from Hlubocany. need a lift saturday"],
	["19:02", "Zdena", "goodnight all, the film is on"],
	["20:15", "HokejNagano", "Sparta lost. I am going to bed"],
	["21:40", "kosmonaut", "anyone still up"],
]
const CHAT_NIGHT := [
	["22:30", "*", "kemp_cj has joined #jih"],
	["22:31", "kemp_cj", "is anyone else up"],
	["22:40", "kosmonaut", "kemp_cj? the camp has internet now?"],
	["23:05", "kemp_cj", "there are lights by the fence"],
	["23:58", "kemp_cj", "i counted them at ten. i counted them again"],
	["00:20", "kemp_cj", "one more"],
	["02:10", "kemp_cj", "has anyone seen my shoe"],
	["03:33", "*", "kemp_cj has left #jih (Connection reset by peer)"],
]


func _chat() -> String:
	var now := _minutes(_time())
	var t := ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + _day()
	var rows: Array = []
	for r in CHAT_DAY:
		# Not every line every day: the room is a little different each day.
		if rng.randf() < 0.75:
			rows.append(r)
	if _day() >= 3:
		for r in CHAT_NIGHT:
			rows.append(r)
	# The room's day runs from six in the morning: what has been said by now.
	var now_rel := (now - 360 + 1440) % 1440
	var shown := 0
	for r in rows:
		if (_minutes(str(r[0])) - 360 + 1440) % 1440 > now_rel:
			continue
		var nick := str(r[1])
		if nick == "*":
			t += "[color=#808080][%s] *** %s[/color]\n" % [r[0], r[2]]
		else:
			var col := "#ff6666" if nick == "kemp_cj" else "#66ff66"
			t += "[color=#808080][%s][/color] [color=%s]<%s>[/color] %s\n" % [r[0], col, nick, str(r[2])]
		shown += 1
	if shown == 0:
		t = "[color=#808080]Nobody has said anything yet today.[/color]\n"
	return t


func _minutes(hhmm: String) -> int:
	var p := hhmm.split(":")
	if p.size() < 2 or not p[0].is_valid_int():
		return 12 * 60
	return int(p[0]) * 60 + int(p[1])


const SIGNS := ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
const STARS := [
	"A financial surprise is coming. It is probably the electricity bill.",
	"Love is near. So is a raccoon. Close the bins.",
	"A good day for planning. Builder 98 agrees, until eight in the evening.",
	"Someone close to you wants to talk. Answer the phone; it may be the electrician.",
	"Your hard work is noticed. Mostly by mosquitoes.",
	"Avoid long journeys. The 380 bus agrees with the stars.",
	"Beware of strangers in hats. And of people who say 'trust me'.",
	"A good day to finish what you started. Begin with the toilets.",
	"Your lucky number is seven. Your lucky colour is any colour but red.",
	"Money comes from an unexpected direction. Check the lost and found.",
	"Rest. You have earned it. Do not rest by the lake.",
	"An old friend gets in touch. Do not knock back.",
]
const STARS_ODD := [
	"Count them at ten. Count them again at midnight. Write both numbers down.",
	"Someone is standing behind you. Do not turn round until they have gone.",
	"Today your sign has one more star than it should.",
]


func _horoscope() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1998 * 31 + _day()
	var order: Array = range(STARS.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var odd := rng.randi_range(0, SIGNS.size() - 1) if _day() >= 4 and rng.randf() < 0.5 else -1
	var t := ""
	for i in SIGNS.size():
		var text: String = STARS[order[i]] if i != odd else STARS_ODD[rng.randi_range(0, STARS_ODD.size() - 1)]
		t += "[b][color=#ffff66]%s[/color][/b]  %s\n" % [SIGNS[i].to_upper(), text]
	return t


## This week's Courier: the region's small news, what the camp is doing among it, by day.
func _news_items() -> Array:
	var day := _day()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400 + day
	var items: Array = []
	var guests := _in_camp()
	if day <= 3:
		items.append(["Cerne jezero camp open again", "The camp by the reservoir, shut since last summer, is taking guests for the autumn. The district inspects it on 19 October; Agrostroj Hlubocany has asked for the land."])
	elif guests > 0:
		items.append(["Guests at the reservoir camp", "%d people stayed at Cerne jezero last night. \"More than we expected in October,\" said the district's accommodation office." % guests])
	else:
		items.append(["Quiet at the reservoir", "The camp at Cerne jezero had no guests last night. The district's inspection is on 19 October."])
	var pool := [
		["Batteries in Liblice", "A delivery of R20 batteries came to the Jednota u Marku on Tuesday. They were sold out by noon."],
		["Bridge repair put off again", "The bridge at Liblice stays closed to lorries until spring. The district has no money for it this year."],
		["Feed mill plan before the council", "Agrostroj Hlubocany showed the council its plan for a feed mill by the reservoir. \"Forty jobs,\" said the director."],
		["Hockey: Hlubocany lose again", "HC Hlubocany lost 2:7 at home. The coach blamed the ice."],
		["Fire station ball on Saturday", "The Liblice volunteer firemen invite everyone to the ball. Music: INFRAVRANY (if they come)."],
		["Mushroom season", "Pickers are out in the woods round the reservoir. The district reminds them that the forest is closed after ten at night."],
		["The water is still rising", "The reservoir's level has risen again although it has not rained. The Water Board will look at the gauge."],
		["Lost dog", "A brown dachshund answering to Bobik went missing near the dam. He was last seen walking into the water."],
	]
	var used := {}
	for i in 3:
		var k := (day * 3 + i * 3 + rng.randi_range(0, 2)) % pool.size()
		while used.has(k):
			k = (k + 1) % pool.size()
		used[k] = true
		items.append(pool[k])
	var wx: String = WX_NAMES[clampi(_weather_state(), 0, 6)]
	items.append(["Weather", "Today %s, %d degrees; tonight %d. %s" % [wx, Season.temp_high(day), Season.temp_low(day), "Frost in the valleys." if Season.hard_frost(day) else "Fog by the water after dark."]])
	return items


func _news() -> String:
	var t := ""
	for it in _news_items():
		t += "[b][font_size=14]%s[/font_size][/b]\n%s\n\n" % [it[0], it[1]]
	return t


## The portal's ticker: the Courier's first story, the weather.
func _headline() -> String:
	var items := _news_items()
	return "%s +++ %s" % [str(items[0][0]), str(items[items.size() - 1][1]).get_slice(";", 0)]


## Tonight's television (four channels). After the late film the transmitters show the
## test card. Some nights one of them shows something else at three.
func _tv() -> String:
	var day := _day()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9800 + day
	var films := ["Columbo", "The Saint", "Kojak", "Derrick", "Murder, She Wrote", "Matlock"]
	var czech := ["a Czech fairy tale", "Cottage by the Water (series)", "Hospital at the End of Town (repeat)", "the Saturday quiz", "a variety evening from Ostrava"]
	var sport := ["Football: Sparta - Slavia", "Hockey: Vsetin - Trinec", "Motorcycles from Most"]
	var nights := ["The Night Film", "Film Club", "The Late Western", "Horror at Midnight"]
	var t := "[table=2]"
	var chans := [
		["CT1", [["18:45", "Bedtime story"], ["19:00", "The News"], ["19:30", "Weather"], ["20:00", czech[rng.randi_range(0, czech.size() - 1)]], ["21:35", films[rng.randi_range(0, films.size() - 1)]], ["23:10", "The News, last"], ["23:30", "Test card"]]],
		["CT2", [["19:00", "Nature: the deer rut"], ["20:00", sport[rng.randi_range(0, sport.size() - 1)]], ["22:00", nights[rng.randi_range(0, nights.size() - 1)]], ["0:15", "Test card"]]],
		["Nova", [["19:30", "Televizni noviny"], ["20:00", films[rng.randi_range(0, films.size() - 1)]], ["21:50", "Quiz: Who Wants to Win"], ["23:00", nights[rng.randi_range(0, nights.size() - 1)]], ["1:00", "Night music"]]],
		["Prima", [["19:15", "Regional news"], ["20:00", "The Simpsons (dubbed)"], ["20:30", czech[rng.randi_range(0, czech.size() - 1)]], ["22:15", films[rng.randi_range(0, films.size() - 1)]], ["0:30", "Test card"]]],
	]
	if day >= 5 and rng.randf() < 0.15:
		(chans[1][1] as Array).append(["3:00", "[color=#cc0000]Kemp Cerne jezero, live[/color]"])
	for ch in chans:
		t += "[cell padding=4,2,16,6][b][color=#ffff66]%s[/color][/b]\n" % ch[0]
		for row in ch[1]:
			t += "[color=#aaaaaa]%s[/color]  %s\n" % [row[0], row[1]]
		t += "[/cell]"
	return t + "[/table]"


## Days to the district's inspection (19 October, 08:00: day 31).
func _agro_days() -> String:
	var left := 31 - _day()
	if left > 1:
		return "%d days" % left
	if left == 1:
		return "tomorrow"
	return "now"


func _search_page(q: String) -> Dictionary:
	var words := q.to_lower().replace("+", " ").split(" ", false)
	var hits: Array = []
	for key in WEB.INDEX:
		var idx := str(WEB.INDEX[key])
		for w in words:
			if idx.find(w) >= 0 or str(key).find(w) >= 0:
				hits.append(key)
				break
	var body := WEB.SEARCH_HEAD + "\n[b]You searched for:[/b] %s\n\n" % q.replace("[", "")
	if hits.is_empty():
		body += "No pages were found. Check the spelling, or try fewer words.\n"
	else:
		body += "[color=#666666]Pages 1-%d of %d:[/color]\n\n" % [hits.size(), hits.size()]
		var n := 1
		for k in hits:
			var p: Dictionary = WEB.PAGES.get(k, {})
			body += "%d. [b]{%s|%s}[/b]\n   [color=#008000]http://www.%s/[/color]\n\n" % [n, k, str(p.get("title", k)), k]
			n += 1
	body += "{{banner:cd:bohemica.cz}}\n" + WEB.HR + "\n{%s|Bohemia Online}" % WEB.HOME
	return {"title": "Bohemia Online - search", "bg": "#ffffff", "fg": "#000000", "link": "#0000ee", "body": body}


# ── dial-up ──────────────────────────────────────────────────────────────────

func _build_dialer() -> void:
	_dial = Panel.new()
	_dial.add_theme_stylebox_override("panel", T.box("window", T.FACE, Vector4.ZERO))
	_dial.size = Vector2(300, 150)
	_dial.visible = false
	add_child(_dial)
	var title := Panel.new()
	title.add_theme_stylebox_override("panel", T.flat(T.NAVY))
	title.position = Vector2(3, 3)
	title.size = Vector2(294, 18)
	_dial.add_child(title)
	var tl := Label.new()
	tl.text = "Dial-up Connection"
	tl.add_theme_font_override("font", T.FONT_BOLD)
	tl.add_theme_color_override("font_color", T.WHITE)
	tl.position = Vector2(4, 2)
	title.add_child(tl)
	var info := Label.new()
	info.text = "Connect to:     Bohemia Online\nUser name:      kemp.cj\nPassword:       ********\nPhone number:   0638 41 41 00"
	info.position = Vector2(12, 28)
	_dial.add_child(info)
	_dial_label = Label.new()
	_dial_label.position = Vector2(12, 90)
	_dial_label.size = Vector2(276, 14)
	_dial.add_child(_dial_label)
	var ok := Button.new()
	ok.name = "Connect"
	ok.text = "Connect"
	ok.position = Vector2(126, 116)
	ok.size = Vector2(80, 23)
	ok.pressed.connect(_start_dial)
	_dial.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.position = Vector2(212, 116)
	cancel.size = Vector2(80, 23)
	cancel.pressed.connect(func():
		_dial.visible = false
		if _dial_t >= 0.0:
			_shell.set_busy(false)
		_dial_t = -1.0
		_status_idle = "Not connected. Click Refresh to dial again."
		_status.text = _status_idle
		_page.text = "[b]You are working offline.[/b]\n\nBeeternet Explorer could not open the page because the computer is not connected to the Internet."
		_page.visible_ratio = 1.0
	)
	_dial.add_child(cancel)


func _open_dialer() -> void:
	_dial.visible = true
	_dial.move_to_front()
	_dial_label.text = "Ready."
	(_dial.get_node("Connect") as Button).disabled = false
	_status.text = "Not connected."


func _start_dial() -> void:
	(_dial.get_node("Connect") as Button).disabled = true
	_dial_t = 0.0
	_shell.set_busy(true)
	_shell.play("modem", -6.0)


func _tick_dialer(delta: float) -> void:
	_dial_t += delta
	var steps := [[0.0, "Dialing 0638 41 41 00..."], [2.6, "Waiting for the other computer..."], [4.6, "Verifying user name and password..."], [6.2, "Logging on to network..."], [7.2, "Connected at 33,600 bps."]]
	for s in steps:
		if _dial_t >= float(s[0]):
			_dial_label.text = str(s[1])
	if _dial_t >= 7.8:
		_dial_t = -1.0
		_dial.visible = false
		_shell.set_busy(false)
		_shell.set_online(true)
		_load(_dial_then, false)
