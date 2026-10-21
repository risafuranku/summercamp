extends Control

## Personal 98: SoftSklad's fifth program (the user 21. 10.: "a fifth tab in SoftSklad
## where you hire the staff"), for the staffroom's hands (DESIGN.md §7c, the rules
## core/systems/staff_rules.gd). The same as the staffroom's paper books
## (scripts/staff/staff_ledger.gd), from the office PC or the staffroom's laptop:
##   Staff     who works here and where each of them is now; the one picked: their wage,
##             what their papers say, and a tick box for each job they see to; Let go
##   Hire      who is asking today (ID photo, wage, papers), Take on: one to a locker,
##             only with a staffroom standing
##   Lockers   one more locker, one more mattress for the boiler room, Buy
##   Today     what the hands did today, the wages tonight
## Drawn in the 98 look like its siblings (business_app.gd); nothing scrolls.

const T = preload("res://scripts/os98/os_theme.gd")
const RULES := preload("res://core/systems/staff_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const LEDGER := preload("res://scripts/staff/staff_ledger.gd")
const PAGES := [["staff", "Staff", "staff"], ["hire", "Hire", "staff"], ["lockers", "Lockers", "stock"], ["today", "Today", "books"]]
const BAR_H := 34
const BANNER_H := 24
const STATUS_H := 20
const ROW_H := 18
const RED := Color8(176, 0, 0)
const GREEN := Color8(0, 112, 0)
const HEAD := Color8(70, 54, 30)
const ICONS := "res://assets/textury/os98/icons/"
const PHOTOS := "res://assets/textury/os98/photos/"
const CARDS := "res://assets/textury/closeup/parts/"

var _shell
var _win
var _page := "staff"
var _pick := ""
var _candidate := 0
var _hits: Array = []
var _hover := ""
var _down := ""
var _notice := ""
var _notice_col := T.TEXT
var _tick := 0.0
var _tex: Dictionary = {}


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


func reopen(_args: Dictionary) -> void:
	refresh()


func refresh() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 1.0:
		_tick = 0.0
		queue_redraw()


func _st() -> Dictionary:
	return CoreRoot.actions.staff_state() if CoreRoot != null and CoreRoot.actions != null else {}


func _crew() -> Array:
	return _st().get("crew", [])


func _who(slug: String) -> Dictionary:
	for p in _crew():
		if str(p.get("slug", "")) == slug:
			return p
	return {}


func _has_room() -> bool:
	var tree := get_tree()
	return tree != null and not tree.get_nodes_in_group("staffroom").is_empty()


func _applicants() -> Array:
	var taken: Array = []
	for p in _crew():
		taken.append(str(p.get("slug", "")))
	if CoreRoot != null and CoreRoot.get_state() != null:
		for k in CoreRoot.get_state().biz.get("sites", {}):
			for p in CoreRoot.get_state().biz["sites"][k].get("crew", []):
				taken.append(str(p.get("slug", "")))
	return RULES.applicants(CoreRoot.get_day(), taken, BUSINESS.camp_seed())


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
	if id.begins_with("crew:"):
		_pick = id.substr(5)
		return
	if id.begins_with("cand:"):
		_candidate = int(id.substr(5))
		return
	if id.begins_with("job:"):
		var p := _who(_pick)
		if p.is_empty():
			return
		var job := id.substr(4)
		var jobs: Dictionary = p.get("jobs", RULES.default_jobs())
		CoreRoot.actions.staff_set_job(_pick, job, not bool(jobs.get(job, true)))
		_shell.play("click", -12.0)
		return
	if id.begins_with("buy:"):
		var gid := id.substr(4)
		var price := RULES.gear_price(_st(), gid)
		var label := tr(str(RULES.GEAR[gid]["label"]))
		_shell.message_box(tr("Personal 98"), tr("Buy a %s for $%d?") % [label.to_lower(), price], "question", [tr("Yes"), tr("No")], func(b: String):
			if b != tr("Yes"):
				return
			if CoreRoot.actions.staff_buy_gear(gid):
				_say(tr("%s bought: it is in the boiler room.") % label, GREEN)
				_shell.play("ding", -10.0)
			else:
				_shell.message_box(tr("Personal 98"), tr("The purchase of $%d could not be made.\n\nThe camp has $%d.") % [price, CoreRoot.get_money()], "error")
			queue_redraw())
		return
	match id:
		"hire":
			var ap := _applicants()
			if ap.is_empty():
				return
			if not _has_room():
				_shell.message_box(tr("Personal 98"), tr("There is no staffroom in the camp.\n\nBuild one in Builder 98 (Utilities): the hands need a locker and somewhere to sit."), "error")
				return
			if not RULES.can_hire(_st()):
				_shell.message_box(tr("Personal 98"), tr("No locker is free. One locker, one hand.\n\nBuy one on the Lockers page."), "error")
				return
			var p: Dictionary = ap[_candidate % ap.size()]
			if CoreRoot.actions.staff_hire(p, CoreRoot.get_day()):
				_pick = str(p["slug"])
				_say(tr("%s starts tomorrow at seven.") % str(p["name"]), GREEN)
				_shell.play("ding", -10.0)
		"fire":
			var who := _who(_pick)
			if who.is_empty():
				return
			var slug := _pick
			_shell.message_box(tr("Personal 98"), tr("Let %s go?") % str(who.get("name", "")), "question", [tr("Yes"), tr("No")], func(b: String):
				if b == tr("Yes"):
					CoreRoot.actions.staff_fire(slug)
					_pick = ""
					_say(tr("%s has been let go.") % str(who.get("name", "")), T.TEXT_DISABLED)
					queue_redraw())


func _say(text: String, col: Color) -> void:
	_notice = text
	_notice_col = col
	queue_redraw()


# ── drawing helpers (business_app.gd's) ──────────────────────────────────────

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


func _group(r: Rect2, caption: String) -> void:
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size), T.WHITE, false, 1.0)
	draw_rect(r, T.SHADOW, false, 1.0)
	var w := _w(caption) + 6
	draw_rect(Rect2(r.position + Vector2(7, -6), Vector2(w, 12)), T.FACE)
	_t(r.position + Vector2(10, 4), caption)


## A 98 check box (the sunken white square, the tick when on) with its label.
func _check(at: Vector2, label: String, on: bool, id: String) -> void:
	var box := Rect2(at, Vector2(13, 13))
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), box)
	if on:
		for k in 3:
			draw_line(box.position + Vector2(3, 5 + k), box.position + Vector2(5, 7 + k), T.TEXT)
			draw_line(box.position + Vector2(5, 7 + k), box.position + Vector2(9, 3 + k), T.TEXT)
	_t(at + Vector2(19, 11), label)
	var r := Rect2(at - Vector2(2, 2), Vector2(_w(label) + 26, 17))
	if _hover == id:
		draw_rect(r, Color(T.NAVY, 0.12))
	_hit(id, r)


func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


func _photo(r: Rect2, slug: String) -> void:
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	var t := _load(PHOTOS + BUSINESS.photo_of(slug) + ".png")
	if t != null:
		draw_texture_rect(t, r.grow(-2), false)


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), T.FACE)
	for i in PAGES.size():
		var id: String = PAGES[i][0]
		var r := Rect2(4 + i * 84, 3, 82, 28)
		if _page == id:
			draw_style_box(T.box("pressed", T.LIGHT, Vector4.ZERO), r)
		elif _hover == "page:" + id:
			draw_style_box(T.box("thin_raised", T.FACE, Vector4.ZERO), r)
		var off := Vector2(1, 1) if _page == id else Vector2.ZERO
		var ic := _load(ICONS + "tb_%s.png" % str(PAGES[i][2]))
		if ic != null:
			var sz := Vector2(ic.get_size())
			var k := minf(16.0 / sz.x, 16.0 / sz.y)
			draw_texture_rect(ic, Rect2(r.position + Vector2(6, 6) + off + (Vector2(16, 16) - sz * k) * 0.5, sz * k), false)
		_t(r.position + Vector2(26, 18) + off, tr(str(PAGES[i][1])))
		_hit("page:" + id, r)
	draw_line(Vector2(0, BAR_H - 1), Vector2(size.x, BAR_H - 1), T.SHADOW)
	draw_line(Vector2(0, BAR_H), Vector2(size.x, BAR_H), T.WHITE)
	var band := Rect2(4, BAR_H + 3, size.x - 8, BANNER_H)
	for x in int(band.size.x / 4.0) + 1:
		draw_rect(Rect2(band.position.x + x * 4, band.position.y, 4, band.size.y), HEAD.lerp(HEAD.lightened(0.45), float(x * 4) / band.size.x))
	var app_icon := _load(ICONS + "staff_app_16.png")
	if app_icon == null:
		app_icon = _load(ICONS + "tb_staff.png")
	if app_icon != null:
		draw_texture_rect(app_icon, Rect2(band.position + Vector2(5, 4), Vector2(16, 16)), false)
	_t(band.position + Vector2(26, 16), "SoftSklad  -  Personal 98", T.WHITE, true)
	_tr(band.end.x - 8, band.position.y + 16, tr("Cash $%d") % (CoreRoot.get_money() if CoreRoot != null else 0), T.WHITE, true)
	var m := Rect2(4, band.end.y + 6, size.x - 8, size.y - band.end.y - 10 - STATUS_H - 2)
	if not _has_room() and _crew().is_empty() and _page != "hire":
		draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), m)
		_tc(Rect2(m.position, Vector2(m.size.x, m.size.y * 0.5)), tr("There is no staffroom in the camp."), T.SHADOW)
		_tc(Rect2(m.position + Vector2(0, 20), Vector2(m.size.x, m.size.y * 0.5)), tr("Builder 98, Utilities: Staffroom."), T.SHADOW)
	else:
		match _page:
			"staff":
				_draw_staff(m)
			"hire":
				_draw_hire(m)
			"lockers":
				_draw_lockers(m)
			"today":
				_draw_today(m)
	_draw_status()


func _draw_status() -> void:
	var y := size.y - STATUS_H
	var st := _st()
	var cells := [[_notice if _notice != "" else tr("Ready"), size.x - 4 - 90 - 140], [tr("Day %d") % (CoreRoot.get_day() if CoreRoot != null else 0), 86],
		[tr("Lockers %d / %d") % [_crew().size(), RULES.gear_count(st, "locker")], 136]]
	var x := 2.0
	for i in cells.size():
		var r := Rect2(x, y, float(cells[i][1]), STATUS_H - 2)
		draw_style_box(T.box("well", T.FACE, Vector4.ZERO), r)
		_t(r.position + Vector2(4, 13), str(cells[i][0]), _notice_col if i == 0 and _notice != "" else T.TEXT)
		x += r.size.x + 2


func _draw_staff(m: Rect2) -> void:
	var left := Rect2(m.position + Vector2(0, 8), Vector2(m.size.x * 0.55 - 6, m.size.y - 8))
	var right := Rect2(Vector2(left.end.x + 12, left.position.y), Vector2(m.end.x - left.end.x - 12, left.size.y))
	_group(left, tr("Working here"))
	var crew := _crew()
	var acts: Dictionary = _st().get("act", {})
	var lb := Rect2(left.position + Vector2(8, 14), Vector2(left.size.x - 16, 6 * ROW_H + 4))
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), lb)
	if crew.is_empty():
		_t(lb.position + Vector2(6, 15), tr("Nobody. You do it all yourself."), RED)
	if _pick == "" and not crew.is_empty():
		_pick = str(crew[0].get("slug", ""))
	for i in mini(crew.size(), 6):
		var p: Dictionary = crew[i]
		var r := Rect2(lb.position.x + 2, lb.position.y + 2 + i * ROW_H, lb.size.x - 4, ROW_H)
		var slug := str(p.get("slug", ""))
		var sel := slug == _pick
		if sel:
			draw_rect(r, T.NAVY)
		var fg := T.WHITE if sel else T.TEXT
		_t(r.position + Vector2(4, 13), str(p.get("name", "")), fg)
		var where := LEDGER.whereabouts(p, acts.get(slug, {}))
		_t(r.position + Vector2(118, 13), tr(where), (RED if where == "In a guest bed" and not sel else fg))
		var tag := (tr("Owed $%d") % int(p.get("owed", 0))) if int(p.get("owed", 0)) > 0 else tr("$%d") % RULES.wage_of(p)
		_tr(r.end.x - 4, r.position.y + 13, tag, (RED if int(p.get("owed", 0)) > 0 and not sel else fg))
		_hit("crew:" + slug, r)
	_button(Rect2(left.position.x + 8, lb.end.y + 8, 90, 22), tr("Let go"), "fire", not _who(_pick).is_empty())
	_group(right, tr("Sees to"))
	var who := _who(_pick)
	if who.is_empty():
		_t(right.position + Vector2(12, 30), tr("Pick somebody on the left."), T.SHADOW)
		return
	_t(right.position + Vector2(12, 26), str(who.get("name", "")), T.TEXT, true)
	var jobs: Dictionary = who.get("jobs", RULES.default_jobs())
	for i in RULES.JOBS.size():
		var id := str(RULES.JOBS[i][0])
		_check(right.position + Vector2(12, 40 + i * 22), tr(str(RULES.JOBS[i][1])), bool(jobs.get(id, true)), "job:" + id)
	var ways := [BUSINESS.RULES.SPEED_WORD[clampi(int(who.get("speed", 1)), 0, 2)], str(BUSINESS.RULES.TEMPER_WORD.get(str(who.get("temper", "flat")), ""))]
	var y := right.position.y + 40 + RULES.JOBS.size() * 22 + 14
	for w in ways:
		_t(Vector2(right.position.x + 12, y), tr(str(w)), T.SHADOW)
		y += 16


func _draw_hire(m: Rect2) -> void:
	var ap := _applicants()
	var left := Rect2(m.position + Vector2(0, 8), Vector2(m.size.x * 0.45 - 6, m.size.y - 8))
	var right := Rect2(Vector2(left.end.x + 12, left.position.y), Vector2(m.end.x - left.end.x - 12, left.size.y))
	_group(left, tr("Asking today"))
	if ap.is_empty():
		_t(left.position + Vector2(12, 30), tr("Nobody."), T.SHADOW)
		return
	var alb := Rect2(left.position + Vector2(8, 14), Vector2(left.size.x - 16, ap.size() * ROW_H + 4))
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), alb)
	for i in ap.size():
		var r2 := Rect2(alb.position.x + 2, alb.position.y + 2 + i * ROW_H, alb.size.x - 4, ROW_H)
		var sel := i == _candidate % ap.size()
		if sel:
			draw_rect(r2, T.NAVY)
		_t(r2.position + Vector2(4, 13), str(ap[i]["name"]), T.WHITE if sel else T.TEXT)
		_tr(r2.end.x - 4, r2.position.y + 13, tr("$%d") % int(ap[i]["wage"]), T.WHITE if sel else T.TEXT)
		_hit("cand:%d" % i, r2)
	var free := RULES.gear_count(_st(), "locker") - _crew().size()
	_t(Vector2(left.position.x + 12, alb.end.y + 22), tr("Lockers free: %d") % maxi(0, free), GREEN if free > 0 else RED)
	_t(Vector2(left.position.x + 12, alb.end.y + 40), tr("They come at 7:00, go home at 20:00."), T.SHADOW)
	_group(right, tr("Papers"))
	var p2: Dictionary = ap[_candidate % ap.size()]
	var pr := Rect2(right.position + Vector2(12, 18), Vector2(52, 66))
	_photo(pr, str(p2["slug"]))
	_t(Vector2(pr.end.x + 10, pr.position.y + 14), str(p2["name"]), T.TEXT, true)
	_t(Vector2(pr.end.x + 10, pr.position.y + 32), tr("$%d a day") % int(p2["wage"]))
	var ty := pr.end.y + 18
	for line in p2.get("refs", []):
		_t(Vector2(right.position.x + 12, ty), tr(str(line)), T.TEXT)
		ty += 16
	_button(Rect2(right.position.x + 12, right.end.y - 32, 100, 22), tr("Take on"), "hire", free > 0 and _has_room())


func _draw_lockers(m: Rect2) -> void:
	var st := _st()
	var i := 0
	for id in ["locker", "mattress"]:
		var d: Dictionary = RULES.GEAR[id]
		var r := Rect2(m.position.x, m.position.y + 8 + i * ((m.size.y - 8) * 0.5), m.size.x, (m.size.y - 8) * 0.5 - 8)
		_group(r, tr(str(d["label"])))
		var pic := Rect2(r.position + Vector2(12, 16), Vector2(64, r.size.y - 28))
		draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), pic)
		var t := _load(CARDS + "card_%s.png" % id)
		if t != null:
			var sz := Vector2(t.get_size())
			var k := minf((pic.size.x - 6) / sz.x, (pic.size.y - 6) / sz.y)
			draw_texture_rect(t, Rect2(pic.position + (pic.size - sz * k) * 0.5, sz * k), false)
		var tx := pic.end.x + 14
		_t(Vector2(tx, r.position.y + 30), tr(str(d["what"])), T.TEXT)
		_t(Vector2(tx, r.position.y + 52), tr("In the boiler room: %d of %d") % [RULES.gear_count(st, id), int(d["max"])], T.TEXT, true)
		var price := RULES.gear_price(st, id)
		if price > 0:
			_t(Vector2(tx, r.position.y + 72), tr("$%d") % price, T.TEXT)
			_button(Rect2(tx + 70, r.position.y + 58, 80, 22), tr("Buy"), "buy:" + id, CoreRoot.get_money() >= price and _has_room())
		else:
			_t(Vector2(tx, r.position.y + 72), tr("No room for more."), GREEN)
		i += 1


func _draw_today(m: Rect2) -> void:
	var st := _st()
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), m)
	var day := CoreRoot.get_day()
	var rows: Array = []
	for e in st.get("log", []):
		if int(e.get("day", 0)) == day:
			rows.append(e)
	var fit := int((m.size.y - 60) / 16.0)
	rows = rows.slice(maxi(0, rows.size() - fit))
	var y := m.position.y + 18
	if rows.is_empty():
		_t(Vector2(m.position.x + 10, y), tr("Nothing done yet today."), T.SHADOW)
	for e in rows:
		var mm := int(e.get("t", 0)) % 1440
		_t(Vector2(m.position.x + 10, y), "%d:%02d" % [mm / 60, mm % 60], T.SHADOW)
		_t(Vector2(m.position.x + 60, y), tr(str(e.get("text", ""))))
		y += 16
	var wages := 0
	for p in _crew():
		wages += RULES.wage_of(p)
	var fy := m.end.y - 12
	_t(Vector2(m.position.x + 10, fy), tr("Jobs today: %d   yesterday: %d") % [int(st.get("done_n", 0)), int(st.get("done_y", 0))], T.TEXT, true)
	_tr(m.end.x - 10, fy, tr("Wages tonight: $%d") % wages, T.TEXT, true)
