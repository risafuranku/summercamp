extends Control

## CampStat 98: the camp's back office. Power draw, the electricity bills (pay them here
## or the grid goes off), tonight's risk with the staff night procedures, the condition
## of the buildings (call the crew), the money, and what guests wrote.
##
## Drawn like the utility software of its year (playtest 18. 10.: the rich-text pages
## were "absolutely hideous"): a navy title band with the meter's status lights, an alert
## bar when something is wrong, page buttons with little glyphs down the left (a badge
## when a page wants you), and in the white well the page itself: green LCD readouts,
## tables with column headers, bars, status chips and real buttons (Pay, Call the crew).
## Downloaded from campgrid.cz and installed.

const T = preload("res://scripts/os98/os_theme.gd")
const TABS := [["today", "Today"], ["power", "Power"], ["bills", "Bills"], ["night", "Night"], ["upkeep", "Upkeep"], ["money", "Money"], ["reviews", "Reviews"]]
const RED := Color8(176, 0, 0)
const AMBER := Color8(160, 112, 0)
const GREEN := Color8(0, 120, 0)
const GREY := Color8(96, 96, 96)
const LCD_BG := Color8(8, 24, 12)
const LCD_ON := Color8(80, 255, 120)
const LCD_DIM := Color8(40, 128, 64)
const ROW_ALT := Color8(236, 236, 244)
const HEAD_H := 40.0
const ALERT_H := 18.0
const NAV_W := 92.0
const PAD := 8.0
const LINE := 14.0

## Staff guidance, in the voice of a camp operator that has clearly done this before.
## It never says what these things are. It only says what to do.
const NIGHT_PROCEDURES := [
	["Quiet Guy", "SILENT MAN", "Footsteps on the gravel behind you that stop when you stop. Do not stand still in the dark. Turn round and put a light on him. If he whispers, turn round at once."],
	["Drunk", "THE PHOTOGRAPHER", "A red light blinking in the trees, beeping faster. Turn your back or get behind something before the flash. Do not pose."],
	["Cheap Chick", "THE GIRL", "She stays where the light ends. Keep her in sight, keep moving, keep to the lamps. Batteries are not covered by the camp."],
	["Two or more", "THE ANTLERED MAN", "Walks the fence. Stay off the fence line after dark. He does not enter lamp light."],
	["Tramps", "THE WHISTLER", "Whistling in the trees, a campfire song. Do not go towards it. Stand under a lamp until it stops. It stops when it gives up on you."],
	["Family", "THE EXTRA CHILD", "A child standing among the tents with its back to you. Do NOT put your torch on it. Torch off, walk past, do not look back."],
	["Mushroom Pickers", "THE BASKET MAN", "Before dawn, out of the woods, a basket creaking. It sees only what moves. When you hear the basket, stand still until it has gone by."],
	["In the sewer", "THE WET ONE", "It cannot see. It hears your boots and the clamp. Stand still and listen; keep the torch on it and it backs off. It drags you back to the ladder."],
]

var _shell
var _win
var _page := "today"
var _tick := 0.0
var _head: Control
var _nav: Control
var _well: Control
var _canvas: Control
var _scroll: VScrollBar
## What the pages draw from, read on refresh (every 2 s and on any change).
var _snap: Dictionary = {}
var _upkeep: Dictionary = {}
var _forecast: Dictionary = {}
var _notice := ""
var _notice_col := Color.BLACK
var _notice_until := 0.0
## Clickable things drawn this frame: [Rect2 (canvas), action String, enabled bool].
var _hits: Array = []
var _hover := ""
var _press := ""
var _content_h := 0.0
## How many characters the page drew (os98_check: a page is not empty).
var drawn_chars := 0


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_head = Control.new()
	_head.draw.connect(_draw_head)
	add_child(_head)
	_nav = Control.new()
	_nav.mouse_filter = Control.MOUSE_FILTER_STOP
	_nav.draw.connect(_draw_nav)
	_nav.gui_input.connect(_nav_input)
	add_child(_nav)
	_well = Panel.new()
	_well.add_theme_stylebox_override("panel", T.box("field", T.WHITE, Vector4.ZERO))
	_well.clip_contents = true
	add_child(_well)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_page)
	_canvas.gui_input.connect(_canvas_input)
	_canvas.mouse_exited.connect(func():
		_hover = ""
		_press = ""
		_canvas.queue_redraw())
	_well.add_child(_canvas)
	_scroll = VScrollBar.new()
	_scroll.value_changed.connect(func(_v): _canvas.queue_redraw())
	add_child(_scroll)
	resized.connect(_layout)
	_layout()
	refresh()


func reopen(_args: Dictionary) -> void:
	refresh()


## Opens a page by its id (the tools, the shot driver).
func select_page(id: String) -> void:
	for t in TABS:
		if str(t[0]) == id:
			_page = id
			_scroll.value = 0.0
			refresh()
			return


func _layout() -> void:
	if _head == null:
		return
	_head.position = Vector2.ZERO
	_head.size = Vector2(size.x, HEAD_H + ALERT_H + 4)
	var top := HEAD_H + ALERT_H + 6.0
	_nav.position = Vector2(2, top)
	_nav.size = Vector2(NAV_W, size.y - top - 2)
	_well.position = Vector2(NAV_W + 6, top)
	_well.size = Vector2(size.x - NAV_W - 8 - 16, size.y - top - 2)
	_scroll.position = Vector2(_well.position.x + _well.size.x, top)
	_scroll.size = Vector2(16, _well.size.y)
	_canvas.position = Vector2(2, 2)
	_canvas.size = _well.size - Vector2(4, 4)
	_fit_scroll()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0 and is_visible_in_tree():
		_tick = 2.0
		refresh()


func refresh() -> void:
	if _head == null:
		return
	_snap = _snapshot()
	if CoreRoot != null and _shell.has_method("store"):
		_shell.store("cash_d%d" % CoreRoot.get_day(), CoreRoot.get_money())
	var m: Node = _shell.main_node()
	_upkeep = m.get_upkeep_snapshot() if m != null and m.has_method("get_upkeep_snapshot") else {}
	_forecast = {}
	if GuestManager != null and GuestManager.has_method("get_liminal_forecast_data"):
		var p = GuestManager.get_liminal_forecast_data()
		_forecast = p if p is Dictionary else {}
	_head.queue_redraw()
	_nav.queue_redraw()
	_canvas.queue_redraw()


func _snapshot() -> Dictionary:
	var m: Node = _shell.main_node()
	if m == null or not m.has_method("get_electricity_ui_snapshot"):
		return {}
	var s = m.get_electricity_ui_snapshot()
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}


func _set_notice(text: String, color: Color) -> void:
	_notice = text
	_notice_col = color
	_notice_until = Time.get_ticks_msec() / 1000.0 + 6.0
	_head.queue_redraw()


# ── the title band, the status lights, the alert ─────────────────────────────

func _draw_head() -> void:
	var c := _head
	var w := c.size.x
	# The band: navy into blue, the name in white.
	for x in int(w):
		c.draw_rect(Rect2(x, 0, 1, HEAD_H), T.TITLE_A.lerp(T.TITLE_B, clampf(float(x) / (w * 0.7), 0.0, 1.0)))
	_glyph(c, "power", Vector2(8, 12), 1.0)
	c.draw_string(T.FONT_BOLD, Vector2(30, 19), "CampStat 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color(0, 0, 0, 0.5))
	c.draw_string(T.FONT_BOLD, Vector2(29, 18), "CampStat 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, T.WHITE)
	c.draw_string(T.FONT, Vector2(30, 33), "CampGrid s.r.o.  /  Hlubocany District Power", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(190, 205, 255))
	# Status lights on the right, each in its own well.
	var x := w - 4.0
	var grid_on := not _snap.is_empty() and not bool(_snap.get("power_cut_active", false))
	var overdue := int(_snap.get("overdue_count", 0))
	var unpaid := int(_snap.get("unpaid_count", 0))
	var wells := [
		["BILLS", "%d DUE" % unpaid if overdue == 0 else "%d LATE" % overdue, RED if overdue > 0 else (AMBER if unpaid > 0 else GREEN)],
		["DAY %d" % int(_snap.get("day", CoreRoot.get_day() if CoreRoot != null else 0)), str(_snap.get("time", "--:--")), Color8(0, 0, 0, 0)],
		["GRID", "ON" if grid_on else ("NO LINK" if _snap.is_empty() else "OFF"), GREEN if grid_on else RED],
	]
	for wl in wells:
		var bw := 74.0
		x -= bw
		var r := Rect2(x, 5, bw, HEAD_H - 10)
		c.draw_style_box(T.box("field", T.FACE, Vector4.ZERO), r)
		var lx := r.position.x + 6.0
		if (wl[2] as Color).a > 0.0:
			_led(c, Vector2(lx + 4, r.position.y + r.size.y * 0.5), wl[2])
			lx += 12.0
		c.draw_string(T.FONT, Vector2(lx, r.position.y + 13), str(wl[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, GREY)
		c.draw_string(T.FONT_BOLD, Vector2(lx, r.position.y + 26), str(wl[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
		x -= 4.0
	# The alert bar: what wants doing, red when it costs you the grid.
	var a := _alert()
	var ar := Rect2(0, HEAD_H + 2, w, ALERT_H)
	if (a[1] as Color) == RED or (a[1] as Color) == AMBER:
		c.draw_rect(ar, a[1])
		c.draw_rect(Rect2(ar.position.x + 4, ar.position.y + 3, 12, 12), T.WHITE)
		c.draw_string(T.FONT_BOLD, Vector2(ar.position.x + 8, ar.position.y + 13), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, a[1])
		c.draw_string(T.FONT_BOLD, Vector2(ar.position.x + 22, ar.position.y + 13), str(a[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 30, T.FONT_SIZE, T.WHITE)
	else:
		c.draw_style_box(T.box("well", T.FACE, Vector4.ZERO), ar)
		c.draw_string(T.FONT, Vector2(ar.position.x + 6, ar.position.y + 13), str(a[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 12, T.FONT_SIZE, a[1])


## [text, colour] for the alert bar: a fresh notice (paid, the crew), else the worst.
func _alert() -> Array:
	if _notice != "" and Time.get_ticks_msec() / 1000.0 < _notice_until:
		return [_notice, _notice_col]
	if _snap.is_empty():
		return ["No connection to the meter.", RED]
	if bool(_snap.get("power_cut_active", false)):
		var warn := "POWER CUT: pay every overdue bill to get the grid back."
		if bool(_snap.get("ups_active", false)):
			var sec := maxi(0, int(ceil(float(_snap.get("ups_seconds_left", 0.0)))))
			warn += "  UPS %02d:%02d left." % [sec / 60, sec % 60]
		return [warn, RED]
	var overdue := int(_snap.get("overdue_count", 0))
	if overdue > 0:
		return ["%d overdue bill%s. The utility cuts the power for overdue bills: see Bills." % [overdue, "" if overdue == 1 else "s"], RED]
	var unpaid := int(_snap.get("unpaid_count", 0))
	if unpaid > 0:
		return ["%d bill%s waiting to be paid (see Bills)." % [unpaid, "" if unpaid == 1 else "s"], AMBER]
	var broken := _broken_count()
	if broken > 0:
		return ["%d building%s broken down (see Upkeep)." % [broken, "" if broken == 1 else "s"], AMBER]
	return ["All in order. Bills are issued every day at %s for the day before." % _issue_time(), GREY]


func _broken_count() -> int:
	var n := 0
	for r in _upkeep.get("rows", []):
		if r is Dictionary and bool(r.get("broken", false)):
			n += 1
	return n


func _issue_time() -> String:
	return "%02d:%02d" % [clampi(int(_snap.get("bill_issue_hour", 20)), 0, 23), clampi(int(_snap.get("bill_issue_minute", 0)), 0, 59)]


# ── the page buttons ─────────────────────────────────────────────────────────

const NAV_BTN_H := 34.0


func _draw_nav() -> void:
	var c := _nav
	c.draw_style_box(T.box("well", T.FACE, Vector4.ZERO), Rect2(Vector2.ZERO, c.size))
	for i in TABS.size():
		var id := str(TABS[i][0])
		var r := Rect2(3, 3 + i * (NAV_BTN_H + 2), c.size.x - 6, NAV_BTN_H)
		var on := id == _page
		c.draw_style_box(T.box("pressed" if on else "raised", Color8(208, 208, 224) if on else T.FACE, Vector4.ZERO), r)
		var off := Vector2(1, 1) if on else Vector2.ZERO
		_glyph(c, id, r.position + Vector2(6, 9) + off, 1.0)
		c.draw_string(T.FONT_BOLD if on else T.FONT, r.position + Vector2(28, 21) + off, str(TABS[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.NAVY if on else T.TEXT)
		var badge := _badge(id)
		if not badge.is_empty():
			var br := Rect2(r.end.x - 18, r.position.y + 4, 14, 12)
			c.draw_rect(br, badge[1])
			c.draw_rect(br, T.DARK, false, 1.0)
			c.draw_string(T.FONT_BOLD, Vector2(br.position.x, br.position.y + 10), str(badge[0]), HORIZONTAL_ALIGNMENT_CENTER, br.size.x, T.FONT_SIZE, T.WHITE)


## [text, colour] of the little flag on a page's button, or [].
func _badge(id: String) -> Array:
	match id:
		"bills":
			var od := int(_snap.get("overdue_count", 0))
			if od > 0:
				return [str(od), RED]
			var un := int(_snap.get("unpaid_count", 0))
			if un > 0:
				return [str(un), AMBER]
		"upkeep":
			var b := _broken_count()
			if b > 0:
				return [str(b), RED]
		"night":
			var tot: Dictionary = _forecast.get("totals", {}) if _forecast.get("totals", {}) is Dictionary else {}
			if int(tot.get("guaranteed_spawns", 0)) > 0:
				return ["!", RED]
	return []


func _nav_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var i := int((mb.position.y - 3) / (NAV_BTN_H + 2))
	if i >= 0 and i < TABS.size() and str(TABS[i][0]) != _page:
		_shell.play("click")
		select_page(str(TABS[i][0]))


# ── the page ─────────────────────────────────────────────────────────────────

func _draw_page() -> void:
	_hits.clear()
	drawn_chars = 0
	var c := _canvas
	var y := PAD - _scroll.value
	match _page:
		"today":
			y = _page_today(y)
		"power":
			y = _page_power(y)
		"bills":
			y = _page_bills(y)
		"night":
			y = _page_night(y)
		"upkeep":
			y = _page_upkeep(y)
		"money":
			y = _page_money(y)
		"reviews":
			y = _page_reviews(y)
	var h := y + _scroll.value + PAD
	if absf(h - _content_h) > 0.5:
		_content_h = h
		_fit_scroll.call_deferred()


func _fit_scroll() -> void:
	if _scroll == null or _canvas == null:
		return
	_scroll.max_value = maxf(_content_h, _canvas.size.y)
	_scroll.page = _canvas.size.y
	_scroll.step = LINE
	_scroll.visible = _content_h > _canvas.size.y + 1.0
	if not _scroll.visible:
		_scroll.value = 0.0


func _canvas_input(ev: InputEvent) -> void:
	var mm := ev as InputEventMouseMotion
	if mm != null:
		var h := _hit_at(mm.position)
		if h != _hover:
			_hover = h
			_canvas.queue_redraw()
		return
	var mb := ev as InputEventMouseButton
	if mb == null:
		return
	if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP):
		_scroll.value += (3.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -3.0) * LINE
		accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var at := _hit_at(mb.position)
	if mb.pressed:
		_press = at
		_canvas.queue_redraw()
	else:
		var was := _press
		_press = ""
		_canvas.queue_redraw()
		if was != "" and was == at:
			_do(at)


func _hit_at(p: Vector2) -> String:
	for h in _hits:
		if bool(h[2]) and (h[0] as Rect2).has_point(p):
			return str(h[1])
	return ""


func _do(action: String) -> void:
	if action.begins_with("pay://"):
		_pay(action.trim_prefix("pay://"))
	elif action == "payall://":
		_pay_all()
	elif action == "crew://all":
		_crew()
	elif action.begins_with("tab://"):
		_shell.play("click", -10.0)
		_shell.open_app(action.trim_prefix("tab://"))
	elif action.begins_with("page://"):
		_shell.play("click")
		select_page(action.trim_prefix("page://"))
	elif action.begins_with("map://"):
		var p := action.trim_prefix("map://").split(":")
		if p.size() == 2:
			_shell.show_on_map(Vector2i(int(p[0]), int(p[1])))


## The page's title and a line under it.
func _title(y: float, title: String, sub: String = "") -> float:
	var c := _canvas
	_text(Vector2(PAD, y), title, T.NAVY, true)
	var tw := T.FONT_BOLD.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	if sub != "":
		_text(Vector2(PAD + tw + 10, y), sub, GREY)
	c.draw_rect(Rect2(PAD, y + 16, c.size.x - PAD * 2, 1), T.SHADOW)
	c.draw_rect(Rect2(PAD, y + 17, c.size.x - PAD * 2, 1), T.WHITE)
	return y + 24.0


## `y` is the top of the line.
func _text(at: Vector2, s: String, col := T.TEXT, bold := false, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_canvas.draw_string(T.FONT_BOLD if bold else T.FONT, at + Vector2(0, 11), s, align, width, T.FONT_SIZE, col)
	drawn_chars += s.length()


## Wrapped text; returns the y under it.
func _para(y: float, s: String, col := T.TEXT, x := PAD, bold := false) -> float:
	var w := _canvas.size.x - x - PAD
	var f: Font = T.FONT_BOLD if bold else T.FONT
	var h := f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, T.FONT_SIZE).y
	_canvas.draw_multiline_string(f, Vector2(x, y + 11), s, HORIZONTAL_ALIGNMENT_LEFT, w, T.FONT_SIZE, -1, col)
	drawn_chars += s.length()
	return y + h + 2.0


## The green LCD: cells of [label, value] side by side.
func _lcd(y: float, cells: Array) -> float:
	var c := _canvas
	var r := Rect2(PAD, y, c.size.x - PAD * 2, 42)
	c.draw_style_box(T.box("field", LCD_BG, Vector4.ZERO), r)
	var cw := (r.size.x - 8) / float(cells.size())
	for i in cells.size():
		var x := r.position.x + 6 + cw * i
		if i > 0:
			c.draw_rect(Rect2(x - 4, r.position.y + 6, 1, r.size.y - 12), LCD_DIM)
		c.draw_string(T.FONT, Vector2(x + 2, r.position.y + 14), str(cells[i][0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, cw - 6, T.FONT_SIZE, LCD_DIM)
		var col: Color = cells[i][2] if cells[i].size() > 2 else LCD_ON
		c.draw_string(T.FONT_MONO, Vector2(x + 2, r.position.y + 34), str(cells[i][1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 6, T.FONT_MONO_SIZE, col)
		drawn_chars += str(cells[i][1]).length()
	return r.end.y + 8.0


## A table: `cols` = [[title, width (0: the rest), align]], `rows` = arrays of cells. A
## cell is a String, or a Dictionary: {t, c (colour), b (bold)}, {bar: 0..1, c},
## {chip: text, c}, {btn: text, act, on}, {stars: n}.
func _table(y: float, cols: Array, rows: Array, row_h := 18.0) -> float:
	var c := _canvas
	var x0 := PAD
	var full := c.size.x - PAD * 2
	var fixed := 0.0
	for col in cols:
		fixed += float(col[1])
	var widths: Array = []
	for col in cols:
		widths.append(float(col[1]) if float(col[1]) > 0.0 else maxf(40.0, full - fixed))
	# The header: raised buttons, the way a list view's columns were.
	var x := x0
	for i in cols.size():
		var hr := Rect2(x, y, widths[i], 18)
		c.draw_style_box(T.box("raised", T.FACE, Vector4.ZERO), hr)
		_text(Vector2(x + 4, y + 3), str(cols[i][0]), T.TEXT, false, widths[i] - 8, cols[i][2])
		x += widths[i]
	y += 18.0
	var body := Rect2(x0, y, full, maxf(row_h, row_h * rows.size()))
	c.draw_rect(body, T.WHITE)
	for ri in rows.size():
		var ry := y + ri * row_h
		if ri % 2 == 1:
			c.draw_rect(Rect2(x0, ry, full, row_h), ROW_ALT)
		x = x0
		for i in cols.size():
			_cell(Rect2(x, ry, widths[i], row_h), rows[ri][i] if i < rows[ri].size() else "", cols[i][2])
			x += widths[i]
	c.draw_rect(body, T.SHADOW, false, 1.0)
	return body.end.y + 8.0


func _cell(r: Rect2, cell, align: int) -> void:
	var c := _canvas
	var inner := r.grow_individual(-4, -2, -4, -2)
	if cell is String:
		_text(Vector2(inner.position.x, r.position.y + (r.size.y - 14) * 0.5), cell, T.TEXT, false, inner.size.x, align)
		return
	var d: Dictionary = cell
	if d.has("bar"):
		_bar(Rect2(inner.position.x, r.position.y + 4, inner.size.x, r.size.y - 8), float(d["bar"]), d.get("c", T.NAVY))
	elif d.has("chip"):
		var tw := T.FONT_BOLD.get_string_size(str(d["chip"]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 10
		var cr := Rect2(inner.position.x, r.position.y + 2, minf(tw, inner.size.x), r.size.y - 4)
		c.draw_rect(cr, d.get("c", GREY))
		_text(Vector2(cr.position.x, cr.position.y + (cr.size.y - 14) * 0.5), str(d["chip"]), T.WHITE, true, cr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	elif d.has("btn"):
		_button(Rect2(inner.position.x, r.position.y + 1, inner.size.x, r.size.y - 2), str(d["btn"]), str(d.get("act", "")), bool(d.get("on", true)))
	elif d.has("stars"):
		_stars(Vector2(inner.position.x, r.position.y + r.size.y * 0.5), int(d["stars"]), 5.0)
	else:
		_text(Vector2(inner.position.x, r.position.y + (r.size.y - 14) * 0.5), str(d.get("t", "")), d.get("c", T.TEXT), bool(d.get("b", false)), inner.size.x, align)


## A segmented bar, ten blocks, the way the meters of the time drew.
func _bar(r: Rect2, frac: float, col: Color) -> void:
	var c := _canvas
	c.draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	var n := 10
	var bw := (r.size.x - 4) / float(n)
	var lit := int(round(clampf(frac, 0.0, 1.0) * n))
	for i in lit:
		c.draw_rect(Rect2(r.position.x + 2 + i * bw, r.position.y + 2, bw - 1, r.size.y - 4), col)


func _button(r: Rect2, text: String, action: String, enabled := true) -> void:
	var c := _canvas
	var down := enabled and _press == action and _hover == action
	c.draw_style_box(T.box("pressed" if down else "raised", T.FACE, Vector4.ZERO), r)
	if enabled and _hover == action and not down:
		c.draw_rect(r.grow(1), T.DARK, false, 1.0)
	var off := Vector2(1, 1) if down else Vector2.ZERO
	_text(Vector2(r.position.x, r.position.y + (r.size.y - 14) * 0.5) + off, text, T.TEXT if enabled else T.TEXT_DISABLED, enabled, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_hits.append([r, action, enabled])


func _stars(at: Vector2, n: int, rad: float) -> void:
	for i in 5:
		var ctr := at + Vector2(rad + i * (rad * 2 + 2), 0)
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + k * PI / 5.0
			pts.append(ctr + Vector2(cos(a), sin(a)) * (rad if k % 2 == 0 else rad * 0.45))
		_canvas.draw_colored_polygon(pts, Color8(240, 200, 0) if i < n else Color8(200, 200, 200))
		pts.append(pts[0])
		_canvas.draw_polyline(pts, Color8(96, 72, 0) if i < n else T.SHADOW, 1.0)


func _led(c: Control, at: Vector2, col: Color) -> void:
	c.draw_circle(at, 4.0, col.darkened(0.5))
	c.draw_circle(at, 3.0, col)
	c.draw_rect(Rect2(at + Vector2(-2, -2), Vector2(2, 2)), col.lightened(0.6))


## Little 16 px pictures for the page buttons (and the band).
func _glyph(c: Control, id: String, p: Vector2, _k: float) -> void:
	match id:
		"today":
			# A desk calendar: the red band, the day.
			c.draw_rect(Rect2(p + Vector2(1, 2), Vector2(14, 13)), T.WHITE)
			c.draw_rect(Rect2(p + Vector2(1, 2), Vector2(14, 4)), RED)
			c.draw_rect(Rect2(p + Vector2(1, 2), Vector2(14, 13)), T.DARK, false, 1.0)
			c.draw_rect(Rect2(p + Vector2(4, 0), Vector2(2, 4)), T.DARK)
			c.draw_rect(Rect2(p + Vector2(10, 0), Vector2(2, 4)), T.DARK)
			for i in 3:
				c.draw_rect(Rect2(p + Vector2(4 + i * 3, 9), Vector2(2, 2)), T.SHADOW)
				c.draw_rect(Rect2(p + Vector2(4 + i * 3, 12), Vector2(2, 1)), T.SHADOW)
		"power":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(9, 0), p + Vector2(2, 9), p + Vector2(7, 9), p + Vector2(5, 16), p + Vector2(13, 6), p + Vector2(8, 6), p + Vector2(11, 0)]), Color8(255, 220, 0))
			c.draw_polyline(PackedVector2Array([p + Vector2(9, 0), p + Vector2(2, 9), p + Vector2(7, 9), p + Vector2(5, 16), p + Vector2(13, 6), p + Vector2(8, 6), p + Vector2(11, 0), p + Vector2(9, 0)]), Color8(120, 80, 0), 1.0)
		"bills":
			c.draw_rect(Rect2(p + Vector2(2, 0), Vector2(11, 15)), T.WHITE)
			c.draw_rect(Rect2(p + Vector2(2, 0), Vector2(11, 15)), T.DARK, false, 1.0)
			for i in 4:
				c.draw_rect(Rect2(p + Vector2(4, 3 + i * 3), Vector2(7 if i < 3 else 4, 1)), T.SHADOW)
			c.draw_rect(Rect2(p + Vector2(8, 11), Vector2(3, 2)), RED)
		"night":
			c.draw_circle(p + Vector2(8, 8), 7.0, Color8(255, 230, 120))
			c.draw_circle(p + Vector2(11, 6), 6.0, T.FACE)
		"upkeep":
			c.draw_line(p + Vector2(3, 14), p + Vector2(11, 6), Color8(130, 90, 40), 3.0)
			c.draw_rect(Rect2(p + Vector2(8, 1), Vector2(8, 5)), Color8(110, 110, 120))
			c.draw_rect(Rect2(p + Vector2(8, 1), Vector2(8, 5)), T.DARK, false, 1.0)
		"money":
			c.draw_circle(p + Vector2(8, 8), 7.0, Color8(120, 90, 0))
			c.draw_circle(p + Vector2(8, 8), 6.0, Color8(240, 200, 40))
			c.draw_string(T.FONT_BOLD, p + Vector2(5, 13), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(120, 80, 0))
		"reviews":
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + k * PI / 5.0
				pts.append(p + Vector2(8, 8) + Vector2(cos(a), sin(a)) * (8.0 if k % 2 == 0 else 3.5))
			c.draw_colored_polygon(pts, Color8(240, 200, 0))
			pts.append(pts[0])
			c.draw_polyline(pts, Color8(96, 72, 0), 1.0)


# ── today ────────────────────────────────────────────────────────────────────

## The camp on one page: the money, and every thing that wants doing with the button
## that does it (or the program that does it). The page the program opens on.
func _page_today(y: float) -> float:
	y = _title(y, "TODAY", "day %d, %s" % [int(_snap.get("day", CoreRoot.get_day() if CoreRoot != null else 1)), str(_snap.get("time", "--:--"))])
	var unpaid := int(_snap.get("unpaid_total", 0))
	var guests := 0
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state != null:
		for g in state.guests:
			if g is Dictionary and str(g.get("status", "")) in ["active", "sleep"]:
				guests += maxi(1, int(g.get("party_size", 1)))
	y = _lcd(y, [["Cash", "$" + _shell._group(CoreRoot.get_money() if CoreRoot != null else 0)], ["Bills to pay", "$%d" % unpaid, Color8(255, 90, 70) if int(_snap.get("overdue_count", 0)) > 0 else LCD_ON], ["Guests in camp", str(guests)]])
	var rows: Array = []
	# The bills.
	var overdue := int(_snap.get("overdue_count", 0))
	var un := int(_snap.get("unpaid_count", 0))
	if bool(_snap.get("power_cut_active", false)):
		rows.append([{"chip": "POWER CUT", "c": RED}, "Every overdue bill must be paid to get the grid back.", {"btn": "Pay all $%d" % unpaid, "act": "payall://"}])
	elif un > 0:
		rows.append([{"chip": "%d LATE" % overdue if overdue > 0 else "%d DUE" % un, "c": RED if overdue > 0 else AMBER}, "Electricity: $%d to pay." % unpaid, {"btn": "Pay all $%d" % unpaid, "act": "payall://"}])
	else:
		rows.append([{"chip": "PAID", "c": GREEN}, "No electricity bills waiting.", ""])
	# Upkeep.
	var broken := _broken_count()
	var jobs := int(_upkeep.get("crew_jobs", 0))
	if jobs > 0:
		var night := bool(_upkeep.get("night", false))
		rows.append([{"chip": "%d BROKEN" % broken if broken > 0 else "%d WORN" % jobs, "c": RED if broken > 0 else AMBER}, "Repairs waiting for the crew." if not night else "Repairs waiting (the crew comes by day).",
			{"btn": "Crew $%d" % int(_upkeep.get("crew_cost", 0)), "act": "crew://all", "on": not night}])
	elif not _upkeep.is_empty():
		rows.append([{"chip": "GOOD", "c": GREEN}, "Everything is in working order.", ""])
	# Guests: at the desk, on the way, rooms to make up.
	if GuestManager != null and GuestManager.has_method("get_arrivals"):
		var at_gate := 0
		var coming := 0
		var not_ready := 0
		for r in GuestManager.get_arrivals():
			if r is Dictionary:
				if bool(r.get("at_gate", false)):
					at_gate += 1
				else:
					coming += 1
				for room in r.get("rooms", []):
					if not bool((room as Dictionary).get("ready", false)):
						not_ready += 1
		if at_gate > 0:
			rows.append([{"chip": "%d AT DESK" % at_gate, "c": RED}, "Guests are waiting at reception. Check them in.", {"btn": "GuestRack", "act": "tab://guestrack"}])
		if coming > 0:
			rows.append([{"chip": "%d COMING" % coming, "c": T.NAVY}, ("Rooms not ready for them: %d." % not_ready) if not_ready > 0 else "Their rooms are ready.", {"btn": "GuestRack", "act": "tab://guestrack"}])
		var dirty := 0
		for key in GuestManager.get_accommodation_states():
			var rs: Dictionary = GuestManager.get_room_state(str(key))
			if not rs.is_empty() and str(rs.get("status", "")) == "dirty" and not bool(rs.get("occupied", false)):
				dirty += 1
		if dirty > 0:
			rows.append([{"chip": "%d DIRTY" % dirty, "c": AMBER}, "Rooms to clean before anyone can have them.", {"btn": "GuestRack", "act": "tab://guestrack"}])
	# The mail.
	var unread := EmailManager.get_unread_count() if EmailManager != null else 0
	if unread > 0:
		rows.append([{"chip": "%d NEW" % unread, "c": T.NAVY}, "Unread mail (bookings come by mail).", {"btn": "CampMail", "act": "tab://mail"}])
	# Tonight.
	var tot: Dictionary = _forecast.get("totals", {}) if _forecast.get("totals", {}) is Dictionary else {}
	var certain := int(tot.get("guaranteed_spawns", 0))
	var m: Node = _shell.main_node()
	if m != null and m.has_method("camp_rule") and not bool(m.camp_rule("threats")):
		pass
	elif certain > 0:
		rows.append([{"chip": "TONIGHT", "c": RED}, "Something is certain to come tonight. Read the procedures.", {"btn": "Night", "act": "page://night"}])
	elif float(tot.get("expected_spawns", 0.0)) > 0.3:
		rows.append([{"chip": "TONIGHT", "c": AMBER}, "Tonight may not be quiet (%.1f expected)." % float(tot.get("expected_spawns", 0.0)), {"btn": "Night", "act": "page://night"}])
	y = _table(y, [["", 96, HORIZONTAL_ALIGNMENT_LEFT], ["What wants doing", 0, HORIZONTAL_ALIGNMENT_LEFT], ["", 100, HORIZONTAL_ALIGNMENT_CENTER]], rows, 22.0)
	return _para(y, "CampGrid customer line 0663 30 199, weekdays 7:00-15:30.", GREY)


func _pay_all() -> void:
	var m: Node = _shell.main_node()
	if m == null or not m.has_method("request_pay_electricity_bill"):
		_set_notice("The utility does not answer.", RED)
		return
	var paid := 0
	var short := false
	# Overdue first: they are the ones that cut the power.
	var bills: Array = (_snap.get("bills", []) as Array).duplicate() if _snap.get("bills", []) is Array else []
	bills.sort_custom(func(a, b): return bool(a.get("is_overdue", false)) and not bool(b.get("is_overdue", false)))
	for b_any in bills:
		var b: Dictionary = b_any
		if str(b.get("status", "unpaid")).to_lower() == "paid":
			continue
		var res: Dictionary = m.request_pay_electricity_bill(str(b.get("id", ""))) as Dictionary
		if bool(res.get("ok", false)):
			paid += int(res.get("amount", 0))
		elif str(res.get("reason", "")) == "insufficient_funds":
			short = true
			break
	refresh()
	if paid > 0:
		_shell.play("click")
		_set_notice("Paid. -$%d" % paid, GREEN)
	if short:
		_shell.message_box("CampStat 98", "Not enough money to pay every bill.\n\nPaid what could be paid ($%d)." % paid, "error")


# ── power ────────────────────────────────────────────────────────────────────

func _page_power(y: float) -> float:
	y = _title(y, "POWER DRAW", "Tariff $%.2f per kWh, standing charge $%d a day" % [float(_snap.get("rate_per_kwh", 0.0)), int(_snap.get("base_fee", 0))])
	if _snap.is_empty():
		return _para(y, "No reading from the meter.", RED)
	y = _lcd(y, [["Load today", "%.1f kWh" % float(_snap.get("daily_kwh_total", 0.0))], ["Energy", "$%d" % int(_snap.get("daily_cost_energy", 0))], ["Bill tomorrow", "$%d" % int(_snap.get("daily_cost_total", 0))]])
	var lines: Array = _snap.get("consumption_lines", []) if _snap.get("consumption_lines", []) is Array else []
	if lines.is_empty():
		return _para(y, "Nothing on the grid yet.", GREY)
	var top := 0.001
	for l in lines:
		if l is Dictionary:
			top = maxf(top, float(l.get("kwh_per_day", 0.0)))
	var rows: Array = []
	for l_any in lines:
		if not (l_any is Dictionary):
			continue
		var l: Dictionary = l_any
		var kwh := maxf(0.0, float(l.get("kwh_per_day", 0.0)))
		rows.append([str(l.get("label", "?")).strip_edges(), _coord(l.get("coord", Vector2i.ZERO)), str(maxi(0, int(l.get("power_units", 0)))),
			"%.1f" % kwh, "$%d" % maxi(0, int(l.get("cost_per_day", 0))), {"bar": kwh / top, "c": Color8(200, 150, 0)}])
	return _table(y, [["Building", 0, HORIZONTAL_ALIGNMENT_LEFT], ["Tile", 50, HORIZONTAL_ALIGNMENT_CENTER], ["Units", 46, HORIZONTAL_ALIGNMENT_RIGHT],
		["kWh/day", 62, HORIZONTAL_ALIGNMENT_RIGHT], ["$/day", 50, HORIZONTAL_ALIGNMENT_RIGHT], ["Share", 90, HORIZONTAL_ALIGNMENT_LEFT]], rows)


# ── bills ────────────────────────────────────────────────────────────────────

func _page_bills(y: float) -> float:
	var grace: int = maxi(1, int(_snap.get("bill_grace_days", 3)))
	y = _title(y, "ELECTRICITY BILLS", "Hlubocany District Power")
	if _snap.is_empty():
		return _para(y, "No connection to the utility.", RED)
	var overdue_total := maxi(0, int(_snap.get("overdue_total", 0)))
	y = _lcd(y, [["Unpaid", "$%d" % maxi(0, int(_snap.get("unpaid_total", 0)))], ["Overdue", "$%d" % overdue_total, Color8(255, 90, 70) if overdue_total > 0 else LCD_ON], ["Pay within", "%d days" % grace]])
	if bool(_snap.get("power_cut_active", false)):
		y = _para(y, "The grid is off until every overdue bill is paid.", RED, PAD, true)
	var bills: Array = _snap.get("bills", []) if _snap.get("bills", []) is Array else []
	if bills.is_empty():
		return _para(y, "No bills yet. The first one comes on day 2 at %s." % _issue_time(), GREY)
	var rows: Array = []
	for b_any in bills:
		if not (b_any is Dictionary):
			continue
		var b: Dictionary = b_any
		var id := str(b.get("id", "")).strip_edges()
		var paid := str(b.get("status", "unpaid")).to_lower().strip_edges() == "paid"
		var overdue := bool(b.get("is_overdue", false))
		var word := "PAID"
		var col := GREEN
		if not paid:
			word = "OVERDUE" if overdue else "UNPAID"
			col = RED if overdue else AMBER
		var act: Variant = ""
		if not paid and not id.is_empty():
			act = {"btn": "Pay now" if overdue else "Pay", "act": "pay://" + id}
		rows.append([{"t": "Day %d" % int(b.get("service_day", 0)), "b": true}, "%.1f kWh" % maxf(0.0, float(b.get("kwh_total", 0.0))),
			{"t": "$%d" % maxi(0, int(b.get("amount", 0))), "b": true}, {"chip": word, "c": col},
			"day %d, %s" % [int(b.get("due_day", 0)), _due(int(b.get("days_left", 0)), paid, overdue)], act])
	y = _table(y, [["Bill", 54, HORIZONTAL_ALIGNMENT_LEFT], ["Used", 70, HORIZONTAL_ALIGNMENT_RIGHT], ["Amount", 58, HORIZONTAL_ALIGNMENT_RIGHT],
		["Status", 74, HORIZONTAL_ALIGNMENT_LEFT], ["Due", 0, HORIZONTAL_ALIGNMENT_LEFT], ["", 70, HORIZONTAL_ALIGNMENT_CENTER]], rows, 20.0)
	var unpaid_all := maxi(0, int(_snap.get("unpaid_total", 0)))
	if unpaid_all > 0:
		_button(Rect2(PAD, y, 160, 24), "Pay all  $%d" % unpaid_all, "payall://")
		y += 32.0
	return _para(y, "A bill comes every day at %s for the day before. An overdue bill cuts the power to the lamps and the buildings; this computer then runs on its UPS for six minutes." % _issue_time(), GREY)


func _due(days_left: int, paid: bool, overdue: bool) -> String:
	if paid:
		return "paid"
	if overdue:
		return "%d day(s) late" % absi(days_left)
	if days_left <= 0:
		return "today"
	return "1 day left" if days_left == 1 else "%d days left" % days_left


func _pay(bill_id: String) -> void:
	var m: Node = _shell.main_node()
	if m == null or not m.has_method("request_pay_electricity_bill"):
		_set_notice("The utility does not answer.", RED)
		return
	var r = m.request_pay_electricity_bill(bill_id)
	var res: Dictionary = r if r is Dictionary else {}
	refresh()
	if bool(res.get("ok", false)):
		_shell.play("click")
		_set_notice("Paid. -$%d" % maxi(0, int(res.get("amount", 0))), GREEN)
		return
	var msg := "The payment did not go through."
	match str(res.get("reason", "")):
		"already_paid":
			msg = "That bill is already paid."
		"insufficient_funds":
			msg = "Not enough money. You need $%d." % maxi(0, int(res.get("amount", 0)))
		"not_found":
			msg = "The utility has no record of that bill."
	_shell.message_box("CampStat 98", msg, "error")


# ── night ────────────────────────────────────────────────────────────────────

func _page_night(y: float) -> float:
	y = _title(y, "TONIGHT", "who is in the camp, and what that brings")
	var m: Node = _shell.main_node()
	if m != null and m.has_method("camp_rule") and not bool(m.camp_rule("threats")):
		y = _para(y, "Night threats are switched off in this camp (sandbox). The nights are quiet: nobody turns, nothing comes to the window.", GREEN)
	elif not bool(_forecast.get("ok", false)):
		y = _para(y, "No forecast.", RED)
	else:
		var totals: Dictionary = _forecast.get("totals", {}) if _forecast.get("totals", {}) is Dictionary else {}
		var safe := int(_forecast.get("safe_count", 3))
		var certain := int(totals.get("guaranteed_spawns", 0))
		y = _lcd(y, [["Guests in camp", str(int(totals.get("guests", 0)))], ["Expected visits", "%.2f" % float(totals.get("expected_spawns", 0.0))],
			["Certain", str(certain), Color8(255, 90, 70) if certain > 0 else LCD_ON]])
		var rows: Array = []
		for e_any in _forecast.get("archetypes", []):
			if not (e_any is Dictionary):
				continue
			var e: Dictionary = e_any
			var tier := str(e.get("chance_tier", "none"))
			var prob := float(e.get("chance_probability", 0.0))
			var verdict := "quiet"
			var col := GREEN
			if int(e.get("guaranteed_spawns", 0)) > 0:
				verdict = "CERTAIN x%d" % int(e.get("guaranteed_spawns", 0))
				col = RED
				prob = 1.0
			elif not (tier == "none" or tier.is_empty()):
				verdict = "%s %d%%" % [tier.to_upper(), int(round(prob * 100.0))]
				col = AMBER if prob < 0.4 else RED
			rows.append([str(e.get("label", "?")), str(int(e.get("count", 0))), {"bar": prob, "c": col}, {"chip": verdict, "c": col}])
		y = _table(y, [["Kind of guest", 0, HORIZONTAL_ALIGNMENT_LEFT], ["In camp", 56, HORIZONTAL_ALIGNMENT_RIGHT], ["Odds", 110, HORIZONTAL_ALIGNMENT_LEFT], ["Tonight", 104, HORIZONTAL_ALIGNMENT_LEFT]], rows)
		y = _para(y, "Each kind of guest is quiet up to %d in the camp. More of one kind raise that kind's odds: a mixed camp is a quieter camp." % safe, GREY)
	y += 6.0
	y = _night_log(y)
	y = _title(y, "STAFF PROCEDURES (NIGHT)", "rev. 3, do not remove from terminal")
	for row in NIGHT_PROCEDURES:
		_text(Vector2(PAD, y), str(row[0]), T.TEXT, true)
		var kw := T.FONT_BOLD.get_string_size(str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		_text(Vector2(PAD + kw + 6, y), "->  " + str(row[1]), RED, true)
		y = _para(y + LINE, str(row[2]), T.TEXT, PAD + 12) + 4.0
	return _para(y, "Incidents are not to be reported to guests. Incidents are not to be reported.", GREY)


## The night director's log of the night before, and what the camp is like tonight
## (scripts/night/night_director.gd): the patterns are there for whoever reads them.
func _night_log(y: float) -> float:
	var m: Node = _shell.main_node()
	var d = m.get("_director") if m != null else null
	if d == null:
		return y
	if m.has_method("_director_context"):
		var dom: int = d.dominant(m._director_context())
		var hint: String = d.ARCH_HINTS[dom] if dom >= 0 else "The camp is empty. The woods are not."
		y = _title(y, "THE CAMP TONIGHT")
		y = _para(y, hint, AMBER) + 6.0
	y = _title(y, "LAST NIGHT'S LOG", "motion log, previous operator's script")
	var lines: Array = d.last_log if not d.last_log.is_empty() else []
	var c := _canvas
	var h := maxf(1, lines.size()) * LINE + 8.0
	var r := Rect2(PAD, y, c.size.x - PAD * 2, h)
	c.draw_style_box(T.box("field", LCD_BG, Vector4.ZERO), r)
	if lines.is_empty():
		c.draw_string(T.FONT, Vector2(r.position.x + 6, r.position.y + 15), "NOTHING LOGGED.", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, LCD_DIM)
	else:
		for i in lines.size():
			var e: Dictionary = lines[i]
			var line := str(d.LOG_LINES.get(str(e.get("id", "")), str(e.get("id", ""))))
			if line.contains("%s"):
				line = line % str(e.get("who", "A guest"))
			var ly := r.position.y + 15 + i * LINE
			c.draw_string(T.FONT, Vector2(r.position.x + 6, ly), str(e.get("time", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, LCD_DIM)
			c.draw_string(T.FONT, Vector2(r.position.x + 50, ly), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, T.FONT_SIZE, LCD_ON)
			drawn_chars += line.length()
	return r.end.y + 12.0


# ── upkeep ───────────────────────────────────────────────────────────────────

## Worst first. Below 50% a building can break; broken ones serve nobody.
func _page_upkeep(y: float) -> float:
	y = _title(y, "UPKEEP", "worst first")
	if _upkeep.is_empty():
		return _para(y, "No maintenance data.", RED)
	y = _para(y, "Below 50% a building can break down, and broken buildings serve no one. Walk up to one and hold R to service or repair it, or send the crew.", GREY) + 4.0
	var rows_in: Array = _upkeep.get("rows", [])
	if rows_in.is_empty():
		return _para(y, "Nothing built that needs looking after yet.", GREY)
	var rows: Array = []
	for r_any in rows_in:
		var r: Dictionary = r_any
		var cond := float(r.get("condition", 1.0))
		var broken := bool(r.get("broken", false))
		var col := GREEN
		var word := "GOOD"
		if broken:
			col = RED
			word = "BROKEN"
		elif cond < 0.5:
			col = RED
			word = "POOR"
		elif cond < 0.75:
			col = AMBER
			word = "WORN"
		var c = r.get("coord", null)
		var map_btn: Variant = {"btn": "Map", "act": "map://%d:%d" % [c.x, c.y]} if c is Vector2i else ""
		rows.append([str(r.get("label", "?")), {"bar": 0.0 if broken else cond, "c": col}, "%d%%" % int(round(cond * 100.0)), {"chip": word, "c": col},
			"%s $%d" % ["repair" if broken else "service", int(r.get("cost", 0))], map_btn])
	y = _table(y, [["Building", 0, HORIZONTAL_ALIGNMENT_LEFT], ["Condition", 100, HORIZONTAL_ALIGNMENT_LEFT], ["", 36, HORIZONTAL_ALIGNMENT_RIGHT],
		["State", 64, HORIZONTAL_ALIGNMENT_LEFT], ["Cost", 82, HORIZONTAL_ALIGNMENT_RIGHT], ["", 44, HORIZONTAL_ALIGNMENT_CENTER]], rows, 20.0)
	var jobs := int(_upkeep.get("crew_jobs", 0))
	if jobs <= 0:
		return _para(y, "Everything is in working order.", GREEN, PAD, true)
	var night := bool(_upkeep.get("night", false))
	_button(Rect2(PAD, y, 220, 24), "Call the maintenance crew", "crew://all", not night)
	_text(Vector2(PAD + 230, y + 5), "%d job(s), $%d" % [jobs, int(_upkeep.get("crew_cost", 0))], T.TEXT, true)
	y += 30.0
	if night:
		y = _para(y, "The crew does not come out after dark.", GREY)
	return y


func _crew() -> void:
	var m: Node = _shell.main_node()
	if m == null or not m.has_method("request_maintenance_crew"):
		return
	var res: Dictionary = m.request_maintenance_crew()
	refresh()
	if bool(res.get("ok", false)):
		_set_notice("The crew did %d job(s). -$%d" % [int(res.get("jobs", 0)), int(res.get("amount", 0))], GREEN)
		return
	match str(res.get("reason", "")):
		"night":
			_shell.message_box("CampStat 98", "The crew does not come out after dark.", "info")
		"insufficient_funds":
			_shell.message_box("CampStat 98", "Not enough money for the crew ($%d)." % int(res.get("amount", 0)), "error")
		_:
			_set_notice("Nothing for the crew to do.", GREY)


# ── money ────────────────────────────────────────────────────────────────────

func _page_money(y: float) -> float:
	y = _title(y, "MONEY", "day %d" % int(_snap.get("day", CoreRoot.get_day())))
	var passive := 0
	var breakdown: Array = []
	var m: Node = _shell.main_node()
	var eco: Node = m.get_node_or_null("EconomyManager") if m != null else null
	if eco != null:
		if eco.has_method("calculate_day_income"):
			passive = int(eco.calculate_day_income())
		if eco.has_method("get_income_breakdown"):
			breakdown = eco.get_income_breakdown()
	var guests_income := 0
	var guests := 0
	var state = CoreRoot.get_state()
	if state != null:
		for g_any in state.guests:
			if g_any is Dictionary and str(g_any.get("status", "")).to_lower() in ["active", "sleep"]:
				guests += 1
				guests_income += maxi(1, int(g_any.get("daily_income", 1)))
	var total := guests_income + passive
	y = _lcd(y, [["Cash", "$" + _shell._group(CoreRoot.get_money())], ["Income a day", "$%d" % total], ["Guests paying", str(guests)]])
	y = _week_chart(y)
	var top := float(maxi(1, maxi(guests_income, passive)))
	var rows: Array = [
		["Guests (%d)" % guests, {"t": "$%d" % guests_income, "b": true}, {"bar": guests_income / top, "c": GREEN}],
		["Facilities", {"t": "$%d" % passive, "b": true}, {"bar": passive / top, "c": T.NAVY}],
		[{"t": "Total a day", "b": true}, {"t": "$%d" % total, "b": true}, ""],
	]
	y = _table(y, [["Income", 0, HORIZONTAL_ALIGNMENT_LEFT], ["a day", 80, HORIZONTAL_ALIGNMENT_RIGHT], ["", 150, HORIZONTAL_ALIGNMENT_LEFT]], rows)
	if not breakdown.is_empty():
		var brows: Array = []
		for l in breakdown:
			brows.append([str(l)])
		y = _table(y, [["Facilities", 0, HORIZONTAL_ALIGNMENT_LEFT]], brows)
	return _para(y, "Electricity is billed separately (see Bills).", GREY)


## The last seven days: what guests paid (green), what the electricity cost (amber),
## and the cash at each day's end (the line), as the utility's software drew its graphs.
func _week_chart(y: float) -> float:
	var c := _canvas
	var today := CoreRoot.get_day() if CoreRoot != null else 1
	var days: Array = []
	for i in range(6, -1, -1):
		if today - i >= 1:
			days.append(today - i)
	var income := {}
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state != null:
		for tx in state.guest_transactions:
			if tx is Dictionary:
				var d := int(tx.get("day", 0))
				income[d] = int(income.get(d, 0)) + maxi(0, int(tx.get("amount", 0)))
	var power := {}
	for b in _snap.get("bills", []):
		if b is Dictionary:
			var d2 := int(b.get("service_day", 0))
			power[d2] = int(power.get(d2, 0)) + maxi(0, int(b.get("amount", 0)))
	var cash := {}
	for d3 in days:
		var v = _shell.stored("cash_d%d" % int(d3), null) if _shell.has_method("stored") else null
		if v != null:
			cash[d3] = int(v)
	var top := 1.0
	for d4 in days:
		top = maxf(top, float(maxi(int(income.get(d4, 0)), int(power.get(d4, 0)))))
	var ctop := 1.0
	var cbot := 0.0
	for v2 in cash.values():
		ctop = maxf(ctop, float(v2))
		cbot = minf(cbot, float(v2))
	_text(Vector2(PAD, y), "THE LAST SEVEN DAYS", T.NAVY, true)
	_text(Vector2(PAD + 150, y), "guests paid", GREEN)
	_text(Vector2(PAD + 230, y), "electricity", AMBER)
	_text(Vector2(PAD + 304, y), "cash", T.NAVY)
	y += 16.0
	var r := Rect2(PAD, y, c.size.x - PAD * 2, 110)
	c.draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	var plot := Rect2(r.position + Vector2(8, 8), r.size - Vector2(16, 30))
	for k in 4:
		var gy := plot.position.y + plot.size.y * float(k) / 4.0
		c.draw_rect(Rect2(plot.position.x, gy, plot.size.x, 1), Color8(228, 228, 236))
	c.draw_rect(Rect2(plot.position.x, plot.end.y, plot.size.x, 1), T.SHADOW)
	var n := maxi(1, days.size())
	var cw := plot.size.x / 7.0
	var pts := PackedVector2Array()
	for i in days.size():
		var d5 := int(days[i])
		var x := plot.position.x + cw * i
		var hi := plot.size.y * float(income.get(d5, 0)) / top
		var hp := plot.size.y * float(power.get(d5, 0)) / top
		var bw := floorf(cw * 0.3)
		c.draw_rect(Rect2(x + cw * 0.5 - bw - 1, plot.end.y - hi, bw, hi), GREEN)
		c.draw_rect(Rect2(x + cw * 0.5 + 1, plot.end.y - hp, bw, hp), Color8(220, 160, 20))
		_text(Vector2(x, plot.end.y + 3), Season.weekday_short(d5) if d5 != today else "today", GREY, false, cw, HORIZONTAL_ALIGNMENT_CENTER)
		if cash.has(d5):
			var k2 := (float(cash[d5]) - cbot) / maxf(1.0, ctop - cbot)
			pts.append(Vector2(x + cw * 0.5, plot.end.y - plot.size.y * (0.08 + 0.84 * k2)))
	if pts.size() >= 2:
		c.draw_polyline(pts, T.NAVY, 1.0)
	for p in pts:
		c.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), T.NAVY)
	if n == 1 and income.is_empty() and power.is_empty():
		_text(Vector2(plot.position.x + 8, plot.position.y + 8), "The first day. The graph fills in as the days go.", GREY)
	return r.end.y + 10.0


# ── reviews ──────────────────────────────────────────────────────────────────

func _page_reviews(y: float) -> float:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	var reviews: Array = state.guest_reviews if state != null else []
	y = _title(y, "GUEST REVIEWS", "what they wrote when they left")
	if reviews.is_empty():
		return _para(y, "No reviews yet. Guests write one when they leave.", GREY)
	var total := 0.0
	for r in reviews:
		if r is Dictionary:
			total += float(r.get("rating", 0))
	var avg := total / float(reviews.size())
	y = _lcd(y, [["Average", "%.1f / 5" % avg], ["Reviews", str(reviews.size())], ["Newest", "day %d" % int((reviews[reviews.size() - 1] as Dictionary).get("day", 0)) if reviews[reviews.size() - 1] is Dictionary else "-"]])
	for i in range(reviews.size() - 1, maxi(-1, reviews.size() - 31), -1):
		var r: Dictionary = reviews[i] if reviews[i] is Dictionary else {}
		var rating := clampi(int(r.get("rating", 0)), 0, 5)
		_stars(Vector2(PAD, y + 7), rating, 5.0)
		_text(Vector2(PAD + 64, y), str(r.get("name", "Guest")), T.TEXT, true)
		_text(Vector2(PAD, y), "day %d" % int(r.get("day", 0)), GREY, false, _canvas.size.x - PAD * 2, HORIZONTAL_ALIGNMENT_RIGHT)
		y = _para(y + LINE + 2, str(r.get("text", "")), T.TEXT, PAD + 12)
		_canvas.draw_rect(Rect2(PAD, y + 2, _canvas.size.x - PAD * 2, 1), Color8(220, 220, 220))
		y += 8.0
	return y


func _coord(v: Variant) -> String:
	if v is Vector2i:
		return "%d:%d" % [v.x, v.y]
	if v is Vector2:
		return "%d:%d" % [int(v.x), int(v.y)]
	if v is Dictionary:
		return "%d:%d" % [int(v.get("x", 0)), int(v.get("y", 0))]
	return "-"
