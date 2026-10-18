extends Control

## The businesses' programs for the office PC (playtest 18. 10.: "on the PC in the
## reception you buy a licence on the net for a program to run the businesses from the
## PC; each business has its own app"): Hostinsky 98 (the pubs), Kuchar 98 (the bistros),
## Pult 98 (the Jednota), Klasek 98 (the corn stands). Bought on softsklad.cz, downloaded
## and installed like the others.
## A proper 1998 back-office program, drawn here in the 98 look: a toolbar of four pages,
## the site picked in a combo box (one site on screen at a time, nothing scrolls), a
## banner, a list view and a status bar.
##   Stock   a row per good: on the shelf, a block bar, capacity, on the van, the price
##   Order   packs per good with spinners, the line totals, the van, Send
##   Staff   the hand behind the counter (ID photo, wage, let go) or the applicants
##   Books   today and yesterday, and the takings of the last seven days as a bar chart
## The same books as the paper desk in the building (scripts/business/ledger_closeup.gd).
## The toolbar's icons, the warning mark and the hands' ID photos are renders
## (os98/icons/tb_*.png, os98/photos/<name>.png); the rest is the system's own chrome.

const T = preload("res://scripts/os98/os_theme.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PAGES := [["stock", "Stock"], ["order", "Order"], ["staff", "Staff"], ["books", "Books"]]
const KIND_OF_APP := {"pub_app": "pub", "bistro_app": "rest", "shop_app": "vecerka", "corn_app": "corn"}
const BAR_H := 34
const BANNER_H := 24
const STATUS_H := 20
const ROW_H := 18
const RED := Color8(176, 0, 0)
const GREEN := Color8(0, 112, 0)
const ICONS := "res://assets/textury/os98/icons/"
const PHOTOS := "res://assets/textury/os98/photos/"
const APP_ICON := {"pub": "pub_app", "rest": "bistro_app", "vecerka": "shop_app", "corn": "corn_app"}
const HEAD_COL := {"pub": Color8(110, 28, 16), "rest": Color8(22, 82, 40), "vecerka": Color8(150, 20, 20), "corn": Color8(150, 110, 0)}

var _shell
var _win
var _kind := "pub"
var _page := "stock"
var _pick: OptionButton
var _sites: Array = []
var _site := ""
var _order: Dictionary = {}       # site key -> {good: packs}
var _candidate := 0
var _hits: Array = []             # [[id, Rect2]], rebuilt each draw
var _hover := ""
var _down := ""
var _notice := ""
var _notice_col := T.TEXT
var _tick := 0.0
var _tex: Dictionary = {}


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_kind = str(KIND_OF_APP.get(str(win.app_id), "pub"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pick = OptionButton.new()
	_pick.focus_mode = Control.FOCUS_NONE
	_pick.item_selected.connect(func(i: int):
		_site = str(_sites[i]) if i >= 0 and i < _sites.size() else ""
		queue_redraw())
	add_child(_pick)
	resized.connect(_layout)
	_layout()
	refresh()


func reopen(_args: Dictionary) -> void:
	refresh()


func _layout() -> void:
	if _pick == null:
		return
	_pick.position = Vector2(size.x - 176, 6)
	_pick.size = Vector2(170, 22)


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 1.0:
		_tick = 0.0
		refresh()


func _live_sites() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	var keys := sites.keys()
	keys.sort()
	for k in keys:
		if str((sites[k] as Dictionary).get("kind", "")) == _kind:
			out.append(str(k))
	return out


func _site_label(i: int) -> String:
	return "%s %d  (%s)" % [str(RULES.info(_kind).get("name", "")), i + 1, str(_sites[i])]


func refresh() -> void:
	if _pick == null:
		return
	var now := _live_sites()
	if now != _sites:
		_sites = now
		_pick.clear()
		for i in _sites.size():
			_pick.add_item(_site_label(i))
		if not _sites.has(_site):
			_site = str(_sites[0]) if not _sites.is_empty() else ""
		if _site != "":
			_pick.select(_sites.find(_site))
		_pick.disabled = _sites.is_empty()
	queue_redraw()


# ── input ────────────────────────────────────────────────────────────────────

func _hit_at(p: Vector2) -> String:
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i][1] as Rect2).has_point(p):
			return str(_hits[i][0])
	return ""


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := _hit_at((e as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_down = _hit_at(mb.position)
		else:
			var h := _hit_at(mb.position)
			if h != "" and h == _down:
				_click(h)
			_down = ""
		queue_redraw()
		accept_event()


func _click(id: String) -> void:
	if id.begins_with("page:"):
		_page = id.substr(5)
		_shell.play("click", -10.0)
		return
	if id.begins_with("cand:"):
		_candidate = int(id.substr(5))
		return
	var s: Dictionary = BUSINESS.site(_site)
	if s.is_empty():
		return
	var info: Dictionary = RULES.info(_kind)
	if id.begins_with("plus:") or id.begins_with("minus:"):
		var g := id.get_slice(":", 1)
		var o: Dictionary = _order.get(_site, {})
		var n := int(o.get(g, 0)) + (1 if id.begins_with("plus:") else -1)
		var room: int = RULES.room_for(_kind, g, int(s["stock"].get(g, 0)), BUSINESS.on_order(_site, g))
		if n > room:
			_say("No room on the shelves for more %s." % str(RULES.goods(_kind)[g]["label"]).to_lower(), RED)
			_shell.play("ding", -8.0)
			return
		o[g] = clampi(n, 0, room)
		_order[_site] = o
		_shell.play("click", -12.0)
		return
	match id:
		"clear":
			_order.erase(_site)
		"send":
			var o: Dictionary = _order.get(_site, {})
			var cost: int = RULES.order_cost(_kind, o)
			if cost <= RULES.DELIVERY_FEE:
				return
			if not CoreRoot.actions.biz_order(_site, o, CoreRoot.get_day() + 1):
				_shell.message_box(str(info["app_name"]), "The order of $%d could not be sent.\n\nThe camp has $%d." % [cost, CoreRoot.get_money()], "error")
				return
			_order.erase(_site)
			_say("Order sent: $%d. The van comes in the morning." % cost, GREEN)
			_shell.play("ding", -10.0)
		"hire":
			var names: Array = info.get("hand", ["A hand"])
			var who := str(names[_candidate % names.size()])
			if CoreRoot.actions.biz_hire(_site, who, CoreRoot.get_day()):
				_say("%s starts today." % who, GREEN)
		"fire":
			var who := str(s["staff_name"])
			var key := _site
			_shell.message_box(str(info["app_name"]), "Let %s go?" % who, "question", ["Yes", "No"], func(b: String):
				if b == "Yes":
					CoreRoot.actions.biz_fire(key)
					_say("%s has been let go." % who, T.TEXT_DISABLED)
					queue_redraw())


func _say(text: String, col: Color) -> void:
	_notice = text
	_notice_col = col
	queue_redraw()


# ── drawing helpers ──────────────────────────────────────────────────────────

func _hit(id: String, r: Rect2) -> void:
	_hits.append([id, r])


func _w(s: String, bold := false) -> float:
	return (T.FONT_BOLD if bold else T.FONT).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x


func _t(p: Vector2, s: String, col := T.TEXT, bold := false) -> void:
	draw_string(T.FONT_BOLD if bold else T.FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)


func _tr(x: float, y: float, s: String, col := T.TEXT, bold := false) -> void:
	_t(Vector2(x - _w(s, bold), y), s, col, bold)


func _tc(r: Rect2, s: String, col := T.TEXT, bold := false) -> void:
	_t(Vector2(r.get_center().x - _w(s, bold) * 0.5, r.position.y + r.size.y * 0.5 + 4), s, col, bold)


func _button(r: Rect2, label: String, id: String, enabled := true) -> void:
	var pushed := enabled and _down == id and _hover == id
	draw_style_box(T.box("pressed" if pushed else "raised", T.FACE, Vector4.ZERO), r)
	var off := Vector2(1, 1) if pushed else Vector2.ZERO
	if enabled:
		_tc(Rect2(r.position + off, r.size), label)
		_hit(id, r)
	else:
		_tc(Rect2(r.position + Vector2(1, 1), r.size), label, T.WHITE)
		_tc(r, label, T.SHADOW)


func _header(r: Rect2, label: String, right := false) -> void:
	draw_style_box(T.box("thin_raised", T.FACE, Vector4.ZERO), r)
	if right:
		_tr(r.end.x - 5, r.position.y + 13, label)
	else:
		_t(r.position + Vector2(5, 13), label)


## The 98 progress bar: navy blocks in a sunken well.
func _blocks(r: Rect2, frac: float, col := T.NAVY) -> void:
	draw_style_box(T.box("well", T.FACE, Vector4.ZERO), r)
	var inner := r.grow(-2)
	var n := int(floor((inner.size.x + 2) / 8.0))
	var on := int(round(n * clampf(frac, 0.0, 1.0)))
	for i in on:
		draw_rect(Rect2(inner.position.x + i * 8, inner.position.y, 6, inner.size.y), col)


## An etched group box with its caption.
func _group(r: Rect2, caption: String) -> void:
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size), T.WHITE, false, 1.0)
	draw_rect(r, T.SHADOW, false, 1.0)
	var w := _w(caption) + 6
	draw_rect(Rect2(r.position + Vector2(7, -6), Vector2(w, 12)), T.FACE)
	_t(r.position + Vector2(10, 4), caption)


func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


func _icon(kind: String, at: Vector2) -> void:
	var t := _load(ICONS + "tb_%s.png" % kind)
	if t != null:
		draw_texture(t, at)


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), T.FACE)
	var info: Dictionary = RULES.info(_kind)
	# The toolbar: four flat buttons, the active one pressed in.
	for i in PAGES.size():
		var id: String = PAGES[i][0]
		var r := Rect2(4 + i * 72, 3, 70, 28)
		if _page == id:
			draw_style_box(T.box("pressed", T.LIGHT, Vector4.ZERO), r)
		elif _hover == "page:" + id:
			draw_style_box(T.box("thin_raised", T.FACE, Vector4.ZERO), r)
		var off := Vector2(1, 1) if _page == id else Vector2.ZERO
		_icon(id, r.position + Vector2(6, 6) + off)
		_t(r.position + Vector2(26, 18) + off, str(PAGES[i][1]))
		_hit("page:" + id, r)
	_tr(size.x - 182, 21, "Site:")
	draw_line(Vector2(0, BAR_H - 1), Vector2(size.x, BAR_H - 1), T.SHADOW)
	draw_line(Vector2(0, BAR_H), Vector2(size.x, BAR_H), T.WHITE)
	# The banner: the program's name on the business's colour, the cash.
	var band := Rect2(4, BAR_H + 3, size.x - 8, BANNER_H)
	var c0: Color = HEAD_COL.get(_kind, T.NAVY)
	for x in int(band.size.x / 4.0) + 1:
		draw_rect(Rect2(band.position.x + x * 4, band.position.y, 4, band.size.y), c0.lerp(c0.lightened(0.45), float(x * 4) / band.size.x))
	var app_icon := _load(ICONS + "%s_16.png" % str(APP_ICON.get(_kind, "pub_app")))
	if app_icon != null:
		draw_texture(app_icon, band.position + Vector2(5, 4))
	_t(band.position + Vector2(26, 16), "%s  -  %s" % [str(info.get("app_name", "")), str(info.get("name", ""))], T.WHITE, true)
	_tr(band.end.x - 8, band.position.y + 16, "Cash $%d" % (CoreRoot.get_money() if CoreRoot != null else 0), T.WHITE, true)
	# The page.
	var m := Rect2(4, band.end.y + 4, size.x - 8, size.y - band.end.y - 8 - STATUS_H - 2)
	var site: Dictionary = BUSINESS.site(_site) if _site != "" else {}
	if site.is_empty():
		draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), m)
		_tc(m, "There is no %s in the camp." % str(info.get("name", "")).to_lower(), T.SHADOW)
	else:
		match _page:
			"stock":
				_draw_stock(m, site)
			"order":
				_draw_order(m, site)
			"staff":
				_draw_staff(m, site)
			"books":
				_draw_books(m, site)
	_draw_status(site)


func _draw_status(site: Dictionary) -> void:
	var y := size.y - STATUS_H
	var cells := [[_notice if _notice != "" else "Ready", size.x - 4 - 90 - 100 - 110], ["Day %d" % (CoreRoot.get_day() if CoreRoot != null else 0), 86]]
	var orders := 0
	if CoreRoot != null:
		for o in CoreRoot.get_state().biz.get("orders", []):
			if str(o.get("key", "")) == _site:
				orders += 1
	cells.append(["On the van: %d" % orders, 96])
	cells.append([str(site.get("staff_name", "")) if bool(site.get("staff", false)) else "No staff", 106])
	var x := 2.0
	for i in cells.size():
		var r := Rect2(x, y, float(cells[i][1]), STATUS_H - 2)
		draw_style_box(T.box("well", T.FACE, Vector4.ZERO), r)
		_t(r.position + Vector2(4, 13), str(cells[i][0]), _notice_col if i == 0 and _notice != "" else T.TEXT)
		x += r.size.x + 2


## The list view: a white well with its column headers.
func _list(m: Rect2, cols: Array) -> void:
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), m)
	var x := m.position.x + 2
	for c in cols:
		_header(Rect2(x, m.position.y + 2, float(c[1]), 18), str(c[0]), bool(c[2]) if c.size() > 2 else false)
		x += float(c[1])
	if x < m.end.x - 2:
		_header(Rect2(x, m.position.y + 2, m.end.x - 2 - x, 18), "")


func _col_x(m: Rect2, cols: Array, i: int) -> float:
	var x := m.position.x + 2
	for k in i:
		x += float(cols[k][1])
	return x


func _draw_stock(m: Rect2, site: Dictionary) -> void:
	var gd: Dictionary = RULES.goods(_kind)
	var cols := [["Item", 110], ["On shelf", 70, true], ["Level", 150], ["Capacity", 70, true], ["On the van", 80, true], ["Price", 60, true]]
	_list(m, cols)
	var value := 0
	var i := 0
	for g in gd:
		var d: Dictionary = gd[g]
		var n := int(site["stock"].get(g, 0))
		var low: bool = RULES.is_low(_kind, g, n)
		var y := m.position.y + 22 + i * ROW_H
		var col: Color = RED if low else T.TEXT
		var warn := _load(ICONS + "tb_warning.png")
		if low and warn != null:
			draw_texture_rect(warn, Rect2(_col_x(m, cols, 0) + 2, y + 1, 14, 14), false)
		_t(Vector2(_col_x(m, cols, 0) + 18, y + 13), str(d["label"]), col)
		_tr(_col_x(m, cols, 2) - 6, y + 13, "%d %s" % [n, str(d["unit"])], col)
		_blocks(Rect2(_col_x(m, cols, 2) + 4, y + 3, 142, 12), float(n) / float(maxi(1, int(d["cap"]))), RED if low else T.NAVY)
		_tr(_col_x(m, cols, 4) - 6, y + 13, "%d" % int(d["cap"]))
		var due: int = BUSINESS.on_order(_site, g)
		_tr(_col_x(m, cols, 5) - 6, y + 13, "+%d" % due if due > 0 else "-", GREEN if due > 0 else T.SHADOW)
		_tr(_col_x(m, cols, 6) - 6, y + 13, "$%d" % int(d["price"]) if int(d["price"]) > 0 else "-")
		value += n * int(d["price"])
		i += 1
	var y2 := m.end.y - 22
	draw_line(Vector2(m.position.x + 4, y2), Vector2(m.end.x - 4, y2), T.LIGHT)
	_t(Vector2(m.position.x + 8, y2 + 15), "On the shelves: $%d at the counter" % value, T.TEXT, true)
	_tr(m.end.x - 8, y2 + 15, "Today: %d sold, $%d" % [int(site["today"]["sold"]), int(site["today"]["takings"])])


func _draw_order(m: Rect2, site: Dictionary) -> void:
	var gd: Dictionary = RULES.goods(_kind)
	var o: Dictionary = _order.get(_site, {})
	var cols := [["Item", 100], ["Pack", 90], ["Pack $", 56, true], ["On shelf", 64, true], ["Room", 50, true], ["Packs", 86], ["Line $", 60, true]]
	var lm := Rect2(m.position, Vector2(m.size.x, m.size.y - 58))
	_list(lm, cols)
	var i := 0
	for g in gd:
		var d: Dictionary = gd[g]
		var y := lm.position.y + 22 + i * ROW_H
		var have := int(site["stock"].get(g, 0))
		var due: int = BUSINESS.on_order(_site, g)
		var room: int = RULES.room_for(_kind, g, have, due)
		var packs := int(o.get(g, 0))
		_t(Vector2(_col_x(lm, cols, 0) + 5, y + 13), str(d["label"]))
		_t(Vector2(_col_x(lm, cols, 1) + 5, y + 13), "%d %s" % [int(d["pack"]), str(d["unit"])], T.SHADOW)
		_tr(_col_x(lm, cols, 3) - 6, y + 13, "$%d" % int(d["pack_cost"]))
		_tr(_col_x(lm, cols, 4) - 6, y + 13, "%d" % have)
		_tr(_col_x(lm, cols, 5) - 6, y + 13, "%d" % room, RED if room == 0 else T.TEXT)
		var sx := _col_x(lm, cols, 5) + 6
		_button(Rect2(sx, y + 1, 16, 16), "-", "minus:" + g, packs > 0)
		draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), Rect2(sx + 18, y + 1, 32, 16))
		_tc(Rect2(sx + 18, y + 1, 32, 16), "%d" % packs, T.TEXT, packs > 0)
		_button(Rect2(sx + 52, y + 1, 16, 16), "+", "plus:" + g, room > 0)
		_tr(_col_x(lm, cols, 7) - 6, y + 13, "$%d" % (packs * int(d["pack_cost"])) if packs > 0 else "-", T.TEXT if packs > 0 else T.SHADOW)
		if due > 0:
			_t(Vector2(_col_x(lm, cols, 7) + 6, y + 13), "+%d" % due, GREEN)
		i += 1
	# The foot: the van, the total, the cash; Clear and Send.
	var cost: int = RULES.order_cost(_kind, o)
	var foot := Rect2(m.position.x, lm.end.y + 8, m.size.x, 48)
	_group(foot, "Order")
	_t(foot.position + Vector2(12, 22), "Van $%d" % (RULES.DELIVERY_FEE if cost > 0 else 0))
	_t(foot.position + Vector2(90, 22), "Total $%d" % cost, RED if cost > CoreRoot.get_money() else T.TEXT, true)
	_t(foot.position + Vector2(200, 22), "Cash $%d" % CoreRoot.get_money(), T.SHADOW)
	_t(foot.position + Vector2(12, 38), "Arrives: day %d, morning" % (CoreRoot.get_day() + 1), T.SHADOW)
	_button(Rect2(foot.end.x - 186, foot.position.y + 14, 84, 24), "Clear", "clear", cost > 0)
	_button(Rect2(foot.end.x - 96, foot.position.y + 14, 88, 24), "Send order", "send", cost > RULES.DELIVERY_FEE)


## The hand's ID photo in its sunken frame.
func _photo(r: Rect2, who: String) -> void:
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	var slug := who.to_lower().replace("mrs ", "").replace("the ", "").replace(" ", "_")
	var t := _load(PHOTOS + slug + ".png")
	if t != null:
		draw_texture_rect(t, r.grow(-2), false)


func _draw_staff(m: Rect2, site: Dictionary) -> void:
	var info: Dictionary = RULES.info(_kind)
	var left := Rect2(m.position + Vector2(0, 8), Vector2(m.size.x * 0.5 - 6, m.size.y - 8))
	var right := Rect2(Vector2(left.end.x + 12, left.position.y), Vector2(m.end.x - left.end.x - 12, left.size.y))
	_group(left, "Behind the counter")
	if bool(site["staff"]):
		var who := str(site["staff_name"])
		_photo(Rect2(left.position + Vector2(14, 20), Vector2(56, 68)), who)
		_t(left.position + Vector2(82, 34), who, T.TEXT, true)
		_t(left.position + Vector2(82, 52), "Since day %d" % int(site["since_day"]))
		_t(left.position + Vector2(82, 68), "Wage $%d a day" % int(info["wage"]))
		_t(left.position + Vector2(82, 84), "Serves alone", T.SHADOW)
		_button(Rect2(left.position.x + 14, left.position.y + 104, 90, 24), "Let go", "fire")
	else:
		_t(left.position + Vector2(14, 34), "Nobody.", RED, true)
		_t(left.position + Vector2(14, 52), "You serve by hand.", RED)
	# The applicants (or, staffed, the wages).
	if bool(site["staff"]):
		_group(right, "Wages")
		_t(right.position + Vector2(14, 34), "Today, at the close: $%d" % int(info["wage"]))
		_t(right.position + Vector2(14, 52), "Takings today: $%d" % int(site["today"]["takings"]))
		var net := int(site["today"]["takings"]) - int(info["wage"])
		_t(right.position + Vector2(14, 70), ("Net: $%d" if net >= 0 else "Net: -$%d") % absi(net), GREEN if net >= 0 else RED, true)
		return
	_group(right, "Applicants")
	var names: Array = info.get("hand", ["A hand"])
	var lb := Rect2(right.position + Vector2(12, 18), Vector2(right.size.x - 24, names.size() * ROW_H + 6))
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), lb)
	for i in names.size():
		var r := Rect2(lb.position.x + 3, lb.position.y + 3 + i * ROW_H, lb.size.x - 6, ROW_H)
		var sel := i == _candidate % names.size()
		if sel:
			draw_rect(r, T.NAVY)
		_t(r.position + Vector2(4, 13), str(names[i]), T.WHITE if sel else T.TEXT)
		_tr(r.end.x - 4, r.position.y + 13, "$%d a day" % int(info["wage"]), T.WHITE if sel else T.TEXT)
		_hit("cand:%d" % i, r)
	var pr := Rect2(right.position + Vector2(12, lb.end.y - right.position.y + 8), Vector2(56, 68))
	_photo(pr, str(names[_candidate % names.size()]))
	_t(Vector2(pr.end.x + 10, pr.position.y + 14), str(names[_candidate % names.size()]), T.TEXT, true)
	_t(Vector2(pr.end.x + 10, pr.position.y + 32), "Can start today", T.SHADOW)
	_button(Rect2(pr.end.x + 10, pr.end.y - 24, 90, 24), "Take on", "hire")


func _draw_books(m: Rect2, site: Dictionary) -> void:
	var cols := [["", 104], ["Today", 70, true], ["Yesterday", 76, true]]
	var tm := Rect2(m.position, Vector2(256, 22 + 5 * ROW_H + 6))
	_list(tm, cols)
	var rows := [["Sold", "sold", ""], ["Takings", "takings", "$"], ["Served by you", "by_hand", ""], ["Went away", "lost", ""]]
	for i in rows.size():
		var y := tm.position.y + 22 + i * ROW_H
		var key: String = rows[i][1]
		var a := int(site["today"][key])
		_t(Vector2(tm.position.x + 7, y + 13), str(rows[i][0]))
		_tr(_col_x(tm, cols, 2) - 6, y + 13, "%s%d" % [rows[i][2], a], RED if key == "lost" and a > 0 else T.TEXT)
		_tr(_col_x(tm, cols, 3) - 6, y + 13, "%s%d" % [rows[i][2], int(site["yesterday"][key])])
	if bool(site["staff"]):
		var y := tm.position.y + 22 + 4 * ROW_H
		_t(Vector2(tm.position.x + 7, y + 13), "Wage")
		_tr(_col_x(tm, cols, 2) - 6, y + 13, "-$%d" % int(RULES.info(_kind)["wage"]), RED)
	# The chart: the takings of the last seven days.
	var ch := Rect2(tm.end.x + 10, m.position.y, m.end.x - tm.end.x - 10, m.size.y)
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), ch)
	_t(ch.position + Vector2(8, 16), "Takings, last 7 days", T.TEXT, true)
	var days: Array = (site.get("history", []) as Array).duplicate()
	days.append(site["today"])
	while days.size() > 7:
		days.pop_front()
	var top := 10
	for d in days:
		top = maxi(top, int(d["takings"]))
	top = int(ceil(top / 10.0)) * 10
	var plot := Rect2(ch.position.x + 40, ch.position.y + 30, ch.size.x - 52, ch.size.y - 52)
	for k in 5:
		var gy := plot.end.y - plot.size.y * k / 4.0
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), T.LIGHT)
		_tr(plot.position.x - 4, gy + 4, "%d" % int(top * k / 4.0), T.SHADOW)
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), T.TEXT)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, T.TEXT)
	var bw := plot.size.x / 7.0
	var today := CoreRoot.get_day()
	for i in days.size():
		var d: Dictionary = days[i]
		var v := float(int(d["takings"])) / float(top)
		var x := plot.position.x + (7 - days.size() + i) * bw
		var bh := plot.size.y * v
		var bar := Rect2(x + bw * 0.2, plot.end.y - bh, bw * 0.6, bh)
		draw_rect(bar, T.NAVY if i < days.size() - 1 else Color8(0, 128, 128))
		draw_rect(Rect2(bar.position + Vector2(bar.size.x, 2), Vector2(2, maxf(0.0, bh - 2))), T.SHADOW)
		if int(d["lost"]) > 0:
			var lh := minf(plot.size.y, plot.size.y * float(int(d["lost"])) / float(maxi(10, top / 4)))
			draw_rect(Rect2(x + bw * 0.2 + bw * 0.6 - 4, plot.end.y - lh, 3, lh), RED)
		var dn := today - (days.size() - 1 - i)
		if dn >= 1:
			_tc(Rect2(x, plot.end.y + 2, bw, 14), "%d" % dn, T.SHADOW)
	draw_rect(Rect2(ch.end.x - 92, ch.position.y + 8, 8, 8), T.NAVY)
	_t(Vector2(ch.end.x - 80, ch.position.y + 16), "$", T.SHADOW)
	draw_rect(Rect2(ch.end.x - 60, ch.position.y + 8, 8, 8), RED)
	_t(Vector2(ch.end.x - 48, ch.position.y + 16), "Lost", T.SHADOW)
