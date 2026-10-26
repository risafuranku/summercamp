extends Control

## The businesses' programs for the office PC (playtest 18. 10.; one place for all of them
## from 20. 10., DESIGN.md §7b: "with a licence, the PC in the reception orders for every
## place at once"): Hostinsky 98 (the pubs), Kuchar 98 (the bistros), Pult 98 (the
## Jednota), Klasek 98 (the corn stands), bought on softsklad.cz. Each licence brings its
## places into the same SoftSklad window: a tab per place across the top, the place picked
## in it, and one order for every licensed place that the one van brings in the morning.
## A proper 1998 back-office program, drawn here in the 98 look (nothing scrolls):
##   Stock   a row per good: on the shelf, a block bar, gone off, the days left, the van
##   Order   packs per good with spinners for the place picked; the order runs across the
##           places, the foot adds it all up: one van, one fee, Send
##   Staff   who works there (job, shift, wage, away, owed; Job / Shift / Let go) and who is
##           asking today (ID photo, wage, what their papers say; Take on)
##   Gear    the place's better gear, Buy
##   Books   today and yesterday, the average score, open late or not, the takings chart
## The same books as the paper desk in the building (scripts/business/ledger_closeup.gd).
## The toolbar's icons, the warning mark and the ID photos are renders (os98/icons/tb_*.png,
## os98/photos/<slug>.png); the rest is the system's own chrome.

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PAGES := [["stock", "Stock"], ["order", "Order"], ["staff", "Staff"], ["gear", "Gear"], ["books", "Books"]]
const KIND_OF_APP := {"pub_app": "pub", "bistro_app": "rest", "shop_app": "vecerka", "corn_app": "corn"}
const BAR_H := 34
const BANNER_H := 24
const TABS_H := 22
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
var _start_kind := "pub"
var _page := "stock"
var _sites: Array = []            # site keys of the licensed places
var _site := ""
var _order: Dictionary = {}       # site key -> {good: packs}
var _candidate := 0
var _crew_pick := ""
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
	_start_kind = str(KIND_OF_APP.get(str(win.app_id), "pub"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


func reopen(_args: Dictionary) -> void:
	refresh()


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 1.0:
		_tick = 0.0
		refresh()


## The places whose program is licensed, the program's own kind first.
func _live_sites() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	var keys := sites.keys()
	keys.sort()
	for kind in [_start_kind, "rest", "pub", "vecerka", "corn"]:
		if not CoreRoot.actions.biz_has_licence(kind) and kind != _start_kind:
			continue
		for k in keys:
			if str((sites[k] as Dictionary).get("kind", "")) == kind and not out.has(str(k)):
				out.append(str(k))
	return out


func _kind() -> String:
	return str(BUSINESS.site(_site).get("kind", _start_kind)) if _site != "" else _start_kind


func _site_label(key: String) -> String:
	var kind := str(BUSINESS.site(key).get("kind", ""))
	var n := 0
	for k in _sites:
		if str(BUSINESS.site(str(k)).get("kind", "")) == kind:
			n += 1
			if str(k) == key:
				break
	var name := tr(str(RULES.info(kind).get("name", "")))
	return name if _count_kind(kind) <= 1 else "%s %d" % [name, n]


func _count_kind(kind: String) -> int:
	var n := 0
	for k in _sites:
		if str(BUSINESS.site(str(k)).get("kind", "")) == kind:
			n += 1
	return n


func refresh() -> void:
	var now := _live_sites()
	if now != _sites:
		_sites = now
		if not _sites.has(_site):
			_site = str(_sites[0]) if not _sites.is_empty() else ""
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
	if id.begins_with("site:"):
		_site = id.substr(5)
		_crew_pick = ""
		_candidate = 0
		_shell.play("click", -10.0)
		return
	if id.begins_with("cand:"):
		_candidate = int(id.substr(5))
		return
	if id.begins_with("crew:"):
		_crew_pick = id.substr(5)
		return
	var s: Dictionary = BUSINESS.site(_site)
	if s.is_empty():
		return
	var kind := _kind()
	var info: Dictionary = RULES.info(kind)
	if id.begins_with("plus:") or id.begins_with("minus:"):
		var g := id.get_slice(":", 1)
		var o: Dictionary = _order.get(_site, {})
		var n := int(o.get(g, 0)) + (1 if id.begins_with("plus:") else -1)
		var room := _room(_site, g)
		if n > room:
			_say(LANG.f("No room on the shelves for more %s.", tr(str(RULES.goods(kind)[g]["label"])).to_lower()), RED)
			_shell.play("ding", -8.0)
			return
		o[g] = clampi(n, 0, room)
		_order[_site] = o
		_shell.play("click", -12.0)
		return
	if id.begins_with("buy:"):
		var gid := id.substr(4)
		var gd: Dictionary = RULES.gear_list(kind).get(gid, {})
		var key := _site
		_shell.message_box(str(info["app_name"]), "Buy %s for $%d?" % [str(gd.get("label", "")), int(gd.get("price", 0))], "question", ["Yes", "No"], func(b: String):
			if b != "Yes":
				return
			if CoreRoot.actions.biz_buy_gear(key, gid):
				_say(LANG.f("%s bought.", tr(str(gd.get("label", "")))), GREEN)
				_shell.play("ding", -10.0)
			else:
				_shell.message_box(str(info["app_name"]), "The purchase of $%d could not be made.\n\nThe camp has $%d." % [int(gd.get("price", 0)), CoreRoot.get_money()], "error")
			queue_redraw())
		return
	match id:
		"clear":
			_order.clear()
		"send":
			var cost := _order_total()
			if cost <= RULES.DELIVERY_FEE:
				return
			if not CoreRoot.actions.biz_order_all(_order, CoreRoot.get_day() + 1):
				_shell.message_box("SoftSklad", "The order of $%d could not be sent.\n\nThe camp has $%d." % [cost, CoreRoot.get_money()], "error")
				return
			_order.clear()
			_say(LANG.f("Order sent: $%d. One van in the morning.", cost), GREEN)
			_shell.play("ding", -10.0)
		"hire":
			var ap := BUSINESS.applicants(_site)
			if ap.is_empty():
				return
			var p: Dictionary = ap[_candidate % ap.size()]
			if CoreRoot.actions.biz_hire(_site, p, CoreRoot.get_day()):
				_crew_pick = str(p["slug"])
				_say(LANG.f("%s starts today.", str(p["name"])), GREEN)
		"job", "shift":
			var who := _crew_of(_crew_pick)
			if who.is_empty():
				return
			var role := str(who.get("role", ""))
			var shift := str(who.get("shift", "day"))
			if id == "job":
				var roles: Array = RULES.ROLES.get(kind, [])
				var i := 0
				for j in roles.size():
					if str(roles[j][0]) == role:
						i = j
				role = str(roles[(i + 1) % roles.size()][0])
			else:
				shift = "late" if shift == "day" else "day"
			CoreRoot.actions.biz_set_job(_site, _crew_pick, role, shift)
		"fire":
			var who2 := _crew_of(_crew_pick)
			if who2.is_empty():
				return
			var key2 := _site
			var slug := _crew_pick
			_shell.message_box(str(info["app_name"]), "Let %s go?" % str(who2.get("name", "")), "question", ["Yes", "No"], func(b: String):
				if b == "Yes":
					CoreRoot.actions.biz_fire(key2, slug)
					_crew_pick = ""
					_say(LANG.f("%s has been let go.", str(who2.get("name", ""))), T.TEXT_DISABLED)
					queue_redraw())
		"late":
			CoreRoot.actions.biz_set_late(_site, not bool(s.get("late", false)))
		"bin":
			var n2: int = CoreRoot.actions.biz_bin(_site)
			if n2 > 0:
				_say(LANG.f("%d written off as waste.", n2), T.TEXT)


func _crew_of(slug: String) -> Dictionary:
	for p in BUSINESS.site(_site).get("crew", []):
		if str(p.get("slug", "")) == slug:
			return p
	return {}


## Packs of `g` that still fit at `key` (its shelves, what is on the van).
func _room(key: String, g: String) -> int:
	var s := BUSINESS.site(key)
	var kind := str(s.get("kind", ""))
	var d: Dictionary = RULES.goods(kind).get(g, {})
	return maxi(0, (RULES.cap_of(kind, g, s) - int(s["stock"].get(g, 0)) - BUSINESS.on_order(key, g)) / maxi(1, int(d.get("pack", 1))))


## The whole order across the places: the goods and one van.
func _order_total() -> int:
	var total := 0
	for key in _order:
		var kind := str(BUSINESS.site(str(key)).get("kind", ""))
		total += RULES.goods_cost(kind, _order[key])
	return total + (RULES.DELIVERY_FEE if total > 0 else 0)


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
		# Fitted into the toolbar's 16 x 16 (some renders are wider), centred.
		var sz := Vector2(t.get_size())
		var k := minf(16.0 / sz.x, 16.0 / sz.y)
		draw_texture_rect(t, Rect2(at + (Vector2(16, 16) - sz * k) * 0.5, sz * k), false)


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), T.FACE)
	var kind := _kind()
	var info: Dictionary = RULES.info(kind)
	# The toolbar: five flat buttons, the active one pressed in.
	for i in PAGES.size():
		var id: String = PAGES[i][0]
		var r := Rect2(4 + i * 72, 3, 70, 28)
		if _page == id:
			draw_style_box(T.box("pressed", T.LIGHT, Vector4.ZERO), r)
		elif _hover == "page:" + id:
			draw_style_box(T.box("thin_raised", T.FACE, Vector4.ZERO), r)
		var off := Vector2(1, 1) if _page == id else Vector2.ZERO
		_icon(id if id != "gear" else "staff", r.position + Vector2(6, 6) + off)
		_t(r.position + Vector2(26, 18) + off, tr(str(PAGES[i][1])))
		_hit("page:" + id, r)
	draw_line(Vector2(0, BAR_H - 1), Vector2(size.x, BAR_H - 1), T.SHADOW)
	draw_line(Vector2(0, BAR_H), Vector2(size.x, BAR_H), T.WHITE)
	# The banner: the program's name on the business's colour, the cash.
	var band := Rect2(4, BAR_H + 3, size.x - 8, BANNER_H)
	var c0: Color = HEAD_COL.get(kind, T.NAVY)
	for x in int(band.size.x / 4.0) + 1:
		draw_rect(Rect2(band.position.x + x * 4, band.position.y, 4, band.size.y), c0.lerp(c0.lightened(0.45), float(x * 4) / band.size.x))
	var app_icon := _load(ICONS + "%s_16.png" % str(APP_ICON.get(kind, "pub_app")))
	if app_icon != null:
		draw_texture(app_icon, band.position + Vector2(5, 4))
	_t(band.position + Vector2(26, 16), "SoftSklad  -  %s" % str(info.get("app_name", "")), T.WHITE, true)
	_tr(band.end.x - 8, band.position.y + 16, LANG.f("Cash $%d", CoreRoot.get_money() if CoreRoot != null else 0), T.WHITE, true)
	# The places: a tab each.
	var tx := 4.0
	var ty := band.end.y + 3
	for key in _sites:
		var label := _site_label(str(key))
		var tw := _w(label) + 22
		var tr := Rect2(tx, ty, tw, TABS_H)
		var on := str(key) == _site
		draw_style_box(T.box("raised" if on else "thin_raised", T.FACE if on else T.LIGHT, Vector4.ZERO), tr)
		var k2 := str(BUSINESS.site(str(key)).get("kind", ""))
		draw_rect(Rect2(tr.position + Vector2(5, 7), Vector2(8, 8)), HEAD_COL.get(k2, T.NAVY))
		var o: Dictionary = _order.get(str(key), {})
		_t(tr.position + Vector2(16, 15), label, T.TEXT, on or not o.is_empty())
		_hit("site:" + str(key), tr)
		tx += tw + 2
	# The page.
	var m := Rect2(4, ty + TABS_H + 4, size.x - 8, size.y - ty - TABS_H - 8 - STATUS_H - 2)
	var site: Dictionary = BUSINESS.site(_site) if _site != "" else {}
	if site.is_empty():
		draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), m)
		_tc(m, LANG.f("There is no %s in the camp.", tr(str(info.get("name", ""))).to_lower()), T.SHADOW)
	else:
		match _page:
			"stock":
				_draw_stock(m, site)
			"order":
				_draw_order(m, site)
			"staff":
				_draw_staff(m, site)
			"gear":
				_draw_gear(m, site)
			"books":
				_draw_books(m, site)
	_draw_status(site)


func _draw_status(site: Dictionary) -> void:
	var y := size.y - STATUS_H
	var cells := [[_notice if _notice != "" else tr("Ready"), size.x - 4 - 90 - 100 - 130], [LANG.f("Day %d", CoreRoot.get_day() if CoreRoot != null else 0), 86]]
	var orders := 0
	if CoreRoot != null:
		for o in CoreRoot.get_state().biz.get("orders", []):
			if str(o.get("key", "")) == _site:
				orders += 1
	cells.append([LANG.f("On the van: %d", orders), 96])
	cells.append([(LANG.f("%d at work", BUSINESS.crew_now(_site).size())) if not site.is_empty() else "", 126])
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
		_header(Rect2(x, m.position.y + 2, float(c[1]), 18), tr(str(c[0])), bool(c[2]) if c.size() > 2 else false)
		x += float(c[1])
	if x < m.end.x - 2:
		_header(Rect2(x, m.position.y + 2, m.end.x - 2 - x, 18), "")


func _col_x(m: Rect2, cols: Array, i: int) -> float:
	var x := m.position.x + 2
	for k in i:
		x += float(cols[k][1])
	return x


## Rows packed to fit the page (the Jednota has ten goods).
func _row_h(n: int, room: float) -> float:
	return minf(float(ROW_H), floorf(room / float(maxi(1, n))))


func _draw_stock(m: Rect2, site: Dictionary) -> void:
	var kind := _kind()
	var gd: Dictionary = RULES.goods(kind)
	var cols := [["Item", 110], ["On shelf", 76, true], ["Level", 130], ["Off", 44, true], ["Keeps", 50, true], ["On the van", 76, true]]
	var lm := Rect2(m.position, Vector2(m.size.x, m.size.y - 30))
	_list(lm, cols)
	var rh := _row_h(gd.size(), lm.size.y - 24)
	var i := 0
	var day := CoreRoot.get_day()
	for g in gd:
		var d: Dictionary = gd[g]
		var n := int(site["stock"].get(g, 0))
		var low: bool = RULES.is_low(kind, g, n)
		var y := lm.position.y + 22 + i * rh
		var col: Color = RED if low else T.TEXT
		var warn := _load(ICONS + "tb_warning.png")
		if low and warn != null:
			draw_texture_rect(warn, Rect2(_col_x(lm, cols, 0) + 2, y + 1, 14, 14), false)
		_t(Vector2(_col_x(lm, cols, 0) + 18, y + 13), tr(str(d["label"])), col)
		_tr(_col_x(lm, cols, 2) - 6, y + 13, "%d %s" % [n, tr(str(d["unit"]))], col)
		_blocks(Rect2(_col_x(lm, cols, 2) + 4, y + 3, 122, minf(12.0, rh - 4)), float(n) / float(maxi(1, RULES.cap_of(kind, g, site))), RED if low else T.NAVY)
		var off := int((site.get("spoiled", {}) as Dictionary).get(g, 0))
		_tr(_col_x(lm, cols, 4) - 6, y + 13, "%d" % off if off > 0 else "-", RED if off > 0 else T.SHADOW)
		var lots: Array = site.get("lots", {}).get(g, [])
		var life := RULES.life_of(kind, g, site)
		if life > 0 and not lots.is_empty():
			var left := maxi(0, life - (day - int(lots[0][1])))
			_tr(_col_x(lm, cols, 5) - 6, y + 13, "%d d" % left, RED if left <= 1 else T.TEXT)
		else:
			_tr(_col_x(lm, cols, 5) - 6, y + 13, "-", T.SHADOW)
		var due: int = BUSINESS.on_order(_site, g)
		_tr(_col_x(lm, cols, 6) - 6, y + 13, "+%d" % due if due > 0 else "-", GREEN if due > 0 else T.SHADOW)
		i += 1
	var foot := Rect2(m.position.x, lm.end.y + 4, m.size.x, 24)
	var spoiled := 0
	for g in site.get("spoiled", {}):
		spoiled += int(site["spoiled"][g])
	_t(foot.position + Vector2(6, 16), LANG.f("Today: %d sold, $%d", [int(site["today"]["sold"]), int(site["today"]["takings"])]))
	_button(Rect2(foot.end.x - 128, foot.position.y + 1, 124, 22), LANG.f("Write off (%d)", spoiled), "bin", spoiled > 0)


func _draw_order(m: Rect2, site: Dictionary) -> void:
	var kind := _kind()
	var gd: Dictionary = RULES.goods(kind)
	var o: Dictionary = _order.get(_site, {})
	var cols := [["Item", 104], ["Pack", 92], ["Pack $", 56, true], ["On shelf", 64, true], ["Room", 46, true], ["Packs", 82], ["Line $", 60, true]]
	var lm := Rect2(m.position, Vector2(m.size.x, m.size.y - 58))
	_list(lm, cols)
	var rh := _row_h(gd.size(), lm.size.y - 24)
	var i := 0
	for g in gd:
		var d: Dictionary = gd[g]
		var y := lm.position.y + 22 + i * rh
		var have := int(site["stock"].get(g, 0))
		var due: int = BUSINESS.on_order(_site, g)
		var room := _room(_site, g)
		var packs := int(o.get(g, 0))
		_t(Vector2(_col_x(lm, cols, 0) + 5, y + 13), tr(str(d["label"])))
		_t(Vector2(_col_x(lm, cols, 1) + 5, y + 13), "%d %s" % [int(d["pack"]), tr(str(d["unit"]))], T.SHADOW)
		_tr(_col_x(lm, cols, 3) - 6, y + 13, LANG.money("$%d" % int(d["pack_cost"])))
		_tr(_col_x(lm, cols, 4) - 6, y + 13, "%d" % have)
		_tr(_col_x(lm, cols, 5) - 6, y + 13, "%d" % room, RED if room == 0 else T.TEXT)
		var sx := _col_x(lm, cols, 5) + 6
		var bh := minf(16.0, rh - 1)
		_button(Rect2(sx, y + 1, 16, bh), "-", "minus:" + g, packs > 0)
		draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), Rect2(sx + 18, y + 1, 30, bh))
		_tc(Rect2(sx + 18, y + 1, 30, bh), "%d" % packs, T.TEXT, packs > 0)
		_button(Rect2(sx + 50, y + 1, 16, bh), "+", "plus:" + g, room > 0)
		_tr(_col_x(lm, cols, 7) - 6, y + 13, LANG.money("$%d" % (packs * int(d["pack_cost"]))) if packs > 0 else "-", T.TEXT if packs > 0 else T.SHADOW)
		if due > 0:
			_t(Vector2(_col_x(lm, cols, 7) + 6, y + 13), "+%d" % due, GREEN)
		i += 1
	# The foot: every place's part of the order, one van, the total, the cash.
	var cost := _order_total()
	var foot := Rect2(m.position.x, lm.end.y + 8, m.size.x, 48)
	_group(foot, tr("Order for the camp"))
	var parts: Array = []
	for key in _order:
		var k2 := str(BUSINESS.site(str(key)).get("kind", ""))
		var c2 := RULES.goods_cost(k2, _order[key])
		if c2 > 0:
			parts.append(LANG.money("%s $%d" % [_site_label(str(key)), c2]))
	_t(foot.position + Vector2(12, 22), ", ".join(parts) if not parts.is_empty() else tr("Nothing yet"), T.SHADOW)
	_t(foot.position + Vector2(12, 38), LANG.f("One van $%d   Total $%d", [RULES.DELIVERY_FEE if cost > 0 else 0, cost]), RED if cost > CoreRoot.get_money() else T.TEXT, true)
	_button(Rect2(foot.end.x - 186, foot.position.y + 14, 84, 24), tr("Clear"), "clear", cost > 0)
	_button(Rect2(foot.end.x - 96, foot.position.y + 14, 88, 24), tr("Send order"), "send", cost > RULES.DELIVERY_FEE)


## An ID photo in its sunken frame.
func _photo(r: Rect2, slug: String) -> void:
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	var t := _load(PHOTOS + BUSINESS.photo_of(slug) + ".png")
	if t != null:
		draw_texture_rect(t, r.grow(-2), false)


func _draw_staff(m: Rect2, site: Dictionary) -> void:
	var kind := _kind()
	var left := Rect2(m.position + Vector2(0, 8), Vector2(m.size.x * 0.55 - 6, m.size.y - 8))
	var right := Rect2(Vector2(left.end.x + 12, left.position.y), Vector2(m.end.x - left.end.x - 12, left.size.y))
	_group(left, "Working here")
	var crew: Array = site.get("crew", [])
	var day := CoreRoot.get_day()
	var lb := Rect2(left.position + Vector2(8, 14), Vector2(left.size.x - 16, 6 * ROW_H + 4))
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), lb)
	if crew.is_empty():
		_t(lb.position + Vector2(6, 15), tr("Nobody. You serve by hand."), RED)
	for i in mini(crew.size(), 6):
		var p: Dictionary = crew[i]
		var r := Rect2(lb.position.x + 2, lb.position.y + 2 + i * ROW_H, lb.size.x - 4, ROW_H)
		var slug := str(p.get("slug", ""))
		var sel := slug == _crew_pick
		if sel:
			draw_rect(r, T.NAVY)
		var fg := T.WHITE if sel else T.TEXT
		var away := int(p.get("absent", -1)) == day
		_t(r.position + Vector2(4, 13), str(p.get("name", "")), RED if away and not sel else fg)
		_t(r.position + Vector2(118, 13), tr(RULES.role_label(kind, str(p.get("role", "")))), fg)
		_t(r.position + Vector2(196, 13), tr("Late") if str(p.get("shift", "day")) == "late" else tr("Day"), fg)
		var tag := tr("Away") if away else (LANG.f("Owed $%d", int(p.get("owed", 0))) if int(p.get("owed", 0)) > 0 else LANG.money("$%d" % RULES.shift_pay(p)))
		_tr(r.end.x - 4, r.position.y + 13, tag, (RED if (away or int(p.get("owed", 0)) > 0) and not sel else fg))
		_hit("crew:" + slug, r)
	var by := lb.end.y + 8
	var picked := not _crew_of(_crew_pick).is_empty()
	_button(Rect2(left.position.x + 8, by, 80, 22), tr("Job"), "job", picked)
	_button(Rect2(left.position.x + 92, by, 80, 22), tr("Shift"), "shift", picked)
	_button(Rect2(left.position.x + 176, by, 80, 22), tr("Let go"), "fire", picked)
	# What the one picked is like (their speed and temper: what the guests get from them).
	if picked:
		var pp := _crew_of(_crew_pick)
		var ways: Array = [tr(RULES.SPEED_WORD[clampi(int(pp.get("speed", 1)), 0, 2)]), tr(str(RULES.TEMPER_WORD.get(str(pp.get("temper", "flat")), "")))]
		_t(Vector2(left.position.x + 8, by + 38), "  ".join(ways), T.TEXT)
	if not bool(site.get("late", false)):
		_t(Vector2(left.position.x + 8, by + 56 if picked else by + 40), tr("Shuts at 20:00"), T.SHADOW)
	# Who is asking today.
	_group(right, tr("Asking today"))
	var ap := BUSINESS.applicants(_site)
	if ap.is_empty():
		_t(right.position + Vector2(12, 30), tr("Nobody."), T.SHADOW)
		return
	var alb := Rect2(right.position + Vector2(8, 14), Vector2(right.size.x - 16, ap.size() * ROW_H + 4))
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), alb)
	for i in ap.size():
		var r2 := Rect2(alb.position.x + 2, alb.position.y + 2 + i * ROW_H, alb.size.x - 4, ROW_H)
		var sel2 := i == _candidate % ap.size()
		if sel2:
			draw_rect(r2, T.NAVY)
		_t(r2.position + Vector2(4, 13), str(ap[i]["name"]), T.WHITE if sel2 else T.TEXT)
		_tr(r2.end.x - 4, r2.position.y + 13, LANG.money("$%d" % int(ap[i]["wage"])), T.WHITE if sel2 else T.TEXT)
		_hit("cand:%d" % i, r2)
	var p2: Dictionary = ap[_candidate % ap.size()]
	var pr := Rect2(right.position + Vector2(8, alb.end.y - right.position.y + 8), Vector2(52, 66))
	_photo(pr, str(p2["slug"]))
	var ty := pr.position.y + 12
	for line in p2.get("refs", []):
		_t(Vector2(pr.end.x + 8, ty), tr(str(line)), T.TEXT)
		ty += 16
	_button(Rect2(pr.end.x + 8, pr.end.y - 22, 90, 22), tr("Take on"), "hire")


func _draw_gear(m: Rect2, site: Dictionary) -> void:
	var kind := _kind()
	var gear: Dictionary = RULES.gear_list(kind)
	var cols := [["Gear", 170], ["What it does", 300], ["Price", 70, true]]
	_list(m, cols)
	var i := 0
	for id in gear:
		var g: Dictionary = gear[id]
		var y := m.position.y + 22 + i * 26
		var owned := RULES.has_gear(site, str(id))
		_t(Vector2(_col_x(m, cols, 0) + 6, y + 15), tr(str(g["label"])), T.SHADOW if owned else T.TEXT, not owned)
		_t(Vector2(_col_x(m, cols, 1) + 6, y + 15), tr(str(g["what"])), T.SHADOW if owned else T.TEXT)
		if owned:
			_tr(_col_x(m, cols, 3) - 6, y + 15, tr("Installed"), GREEN)
		else:
			_tr(_col_x(m, cols, 3) - 6, y + 15, LANG.money("$%d" % int(g["price"])))
			_button(Rect2(_col_x(m, cols, 3) + 6, y + 2, 60, 22), tr("Buy"), "buy:" + str(id), CoreRoot.get_money() >= int(g["price"]))
		i += 1


func _draw_books(m: Rect2, site: Dictionary) -> void:
	var cols := [["", 104], ["Today", 70, true], ["Yesterday", 76, true]]
	var rows := [["Sold", "sold", ""], ["Takings", "takings", "$"], ["Goods used", "cost", "$"], ["Served by you", "by_hand", ""], ["Went away", "lost", ""], ["Thrown out", "waste", ""], ["Short", "short", "$"]]
	var tm := Rect2(m.position, Vector2(256, 22 + rows.size() * ROW_H + 6))
	_list(tm, cols)
	for i in rows.size():
		var y := tm.position.y + 22 + i * ROW_H
		var key: String = rows[i][1]
		var a := int(round(float((site["today"] as Dictionary).get(key, 0))))
		var bad := key in ["lost", "waste", "short"]
		_t(Vector2(tm.position.x + 7, y + 13), tr(str(rows[i][0])))
		_tr(_col_x(tm, cols, 2) - 6, y + 13, LANG.money("%s%d" % [rows[i][2], a]), RED if bad and a > 0 else T.TEXT)
		_tr(_col_x(tm, cols, 3) - 6, y + 13, LANG.money("%s%d" % [rows[i][2], int(round(float((site["yesterday"] as Dictionary).get(key, 0))))]))
	# The average, the evening.
	var g := Rect2(tm.position.x, tm.end.y + 12, tm.size.x, m.end.y - tm.end.y - 12)
	_group(g, tr("The place"))
	var n := int(site.get("all_orders", 0))
	_t(g.position + Vector2(12, 22), LANG.f("Orders rated: %d", n))
	if n > 0:
		_t(g.position + Vector2(12, 40), LANG.f("Average score: %d%%", int(round(float(site.get("all_score", 0)) / float(n)))), T.TEXT, true)
	# The last shift's Z report: its mark and the one thing to mend.
	var z: Dictionary = site.get("zreport", {}) if site.get("zreport", {}) is Dictionary else {}
	if not z.is_empty():
		var mark: Dictionary = {"grade": z["grade"], "advice": z.get("advice", "")} if z.has("grade") else RULES.day_grade(z)
		var gr := str(mark["grade"])
		_t(g.position + Vector2(150, 22), LANG.f("Last shift: %s", gr), GREEN if gr in ["A", "B"] else (RED if gr in ["D", "E"] else T.TEXT), true)
		var adv := tr(str(mark["advice"]))
		while adv.length() > 4 and _w(adv) > g.size.x - 162:
			adv = adv.substr(0, adv.length() - 4) + "..."
		_t(g.position + Vector2(150, 40), adv, T.SHADOW)
	var late := bool(site.get("late", false))
	_t(g.position + Vector2(12, 62), LANG.f("Open till %s", "23:00" if late else "20:00"))
	_button(Rect2(g.position.x + 12, g.position.y + 70, 120, 22), tr("Shut at 20:00") if late else tr("Open late"), "late")
	# The chart: the takings of the last seven days.
	var ch := Rect2(tm.end.x + 10, m.position.y, m.end.x - tm.end.x - 10, m.size.y)
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), ch)
	_t(ch.position + Vector2(8, 16), tr("Takings, last 7 days"), T.TEXT, true)
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
		if int(d.get("lost", 0)) > 0:
			var lh := minf(plot.size.y, plot.size.y * float(int(d["lost"])) / float(maxi(10, top / 4)))
			draw_rect(Rect2(x + bw * 0.2 + bw * 0.6 - 4, plot.end.y - lh, 3, lh), RED)
		var dn := today - (days.size() - 1 - i)
		if dn >= 1:
			_tc(Rect2(x, plot.end.y + 2, bw, 14), "%d" % dn, T.SHADOW)
	draw_rect(Rect2(ch.end.x - 92, ch.position.y + 8, 8, 8), T.NAVY)
	_t(Vector2(ch.end.x - 80, ch.position.y + 16), "$", T.SHADOW)
	draw_rect(Rect2(ch.end.x - 60, ch.position.y + 8, 8, 8), RED)
	_t(Vector2(ch.end.x - 48, ch.position.y + 16), tr("Lost"), T.SHADOW)
