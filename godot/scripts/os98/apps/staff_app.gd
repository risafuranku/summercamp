extends Control

## Personal 98: SoftSklad's program for everybody who works in the camp (the user 4. 11.:
## "sharing the hands out by the stands on the PC is horribly complicated; redo the whole
## program simply, so managing the staff is fun: there are the businesses' hands, and the
## staffroom's, who clean or take the guests in at the reception"). One list of the lot,
## and a click moves somebody where they are wanted; the businesses' programs only run their
## places. Pages:
##   Staff     everybody, where they work and what they are doing; the one picked: their
##             photo, how they are, a button for each place to move them to, the
##             staffroom's jobs as tick boxes (the blocks and the reception too), Let go
##   Hire      who is asking today (five, anybody not in work: ID photo, papers), a button
##             for each place to take them on at, with what they ask there; they come in
##             the next morning (the staffroom only with a locker free)
##   Lockers   one more locker for the boiler room, one more armchair for the lounge, Buy
##   Today     what the staffroom's hands did today, the wages tonight
## Drawn in the 98 look like its siblings (business_app.gd); nothing scrolls.

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const RULES := preload("res://core/systems/staff_rules.gd")
const BRT := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const LEDGER := preload("res://scripts/staff/staff_ledger.gd")
const PAGES := [["staff", "Staff", "staff"], ["hire", "Hire", "staff"], ["lockers", "Lockers", "stock"], ["today", "Today", "books"]]
const BAR_H := 34
const BANNER_H := 24
const STATUS_H := 20
const ROW_H := 18
const ROWS := 11
const RED := Color8(176, 0, 0)
const GREEN := Color8(0, 112, 0)
const HEAD := Color8(70, 54, 30)
const ICONS := "res://assets/textury/os98/icons/"
const PHOTOS := "res://assets/textury/os98/photos/"
const CARDS := "res://assets/textury/closeup/parts/"
## The places' colours on the list (business_app's banner colours), the staffroom's brown.
const PLACE_COL := {"pub": Color8(120, 60, 20), "rest": Color8(150, 40, 30), "vecerka": Color8(30, 90, 50), "corn": Color8(170, 130, 10), "bowl": Color8(40, 60, 130), "staff": HEAD}

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


func _has_room() -> bool:
	var tree := get_tree()
	return tree != null and not tree.get_nodes_in_group("staffroom").is_empty()


# ── who works where ──────────────────────────────────────────────────────────

## The places to work at: the businesses standing in the camp (their keys, by kind) and
## the staffroom ("staff") when there is one.
func _places() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var state = CoreRoot.get_state()
	var sites: Dictionary = state.biz.get("sites", {})
	var keys := sites.keys()
	keys.sort()
	for kind in ["pub", "rest", "vecerka", "corn", "bowl"]:
		for k in keys:
			if str((sites[k] as Dictionary).get("kind", "")) != kind:
				continue
			var p := str(k).split(":")
			if p.size() != 2:
				continue
			var cell: Dictionary = state.grid.cells.get(Vector2i(int(p[0]), int(p[1])), {})
			if BRT.is_business(str(cell.get("type", ""))):
				out.append(str(k))
	if _has_room():
		out.append("staff")
	return out


func _kind_of(place: String) -> String:
	return "staff" if place == "staff" else str(BUSINESS.site(place).get("kind", ""))


func _place_label(place: String) -> String:
	if place == "staff":
		return tr("Staffroom")
	var kind := _kind_of(place)
	var name := tr(str(BRT.info(kind).get("name", "")))
	var same: Array = _places().filter(func(k): return _kind_of(str(k)) == kind)
	return name if same.size() <= 1 else "%s %d" % [name, same.find(place) + 1]


## Everybody: [{p, at}], the businesses' first, the staffroom's after.
func _everyone() -> Array:
	var out: Array = []
	for place in _places():
		if place == "staff":
			continue
		for p in BUSINESS.site(place).get("crew", []):
			out.append({"p": p, "at": place})
	for p in _crew():
		out.append({"p": p, "at": "staff"})
	return out


func _entry(slug: String) -> Dictionary:
	for e in _everyone():
		if str((e["p"] as Dictionary).get("slug", "")) == slug:
			return e
	return {}


func _taken() -> Array:
	var out: Array = []
	for e in _everyone():
		out.append(str((e["p"] as Dictionary).get("slug", "")))
	# (Somebody's whose place was pulled down is still on its books.)
	if CoreRoot != null and CoreRoot.get_state() != null:
		for k in CoreRoot.get_state().biz.get("sites", {}):
			for p in CoreRoot.get_state().biz["sites"][k].get("crew", []):
				if not out.has(str(p.get("slug", ""))):
					out.append(str(p.get("slug", "")))
	return out


## Who is asking today: anybody not working in the camp, five a day (the same on every
## machine).
func _applicants() -> Array:
	return BRT.applicants("camp", "camp", CoreRoot.get_day(), _taken(), BUSINESS.camp_seed())


## Whether `slug` would work at `place`: the businesses anybody; the staffroom (its
## brooms, its lounge) those who ask for it.
func _would(slug: String, place: String) -> bool:
	if place != "staff":
		return true
	return (BRT.PEOPLE.get(slug, {}).get("asks", []) as Array).has("staff")


## What `slug` asks a day at `place`.
func _wage_at(slug: String, place: String) -> int:
	return int(BRT.person(slug, _kind_of(place), BUSINESS.camp_seed()).get("wage", 25))


## What they are doing now, for the list.
func _status(e: Dictionary) -> String:
	var p: Dictionary = e["p"]
	var day := CoreRoot.get_day()
	if int(p.get("since", 0)) > day:
		return "From tomorrow"
	if int(p.get("absent", -1)) == day:
		return "Away today"
	if str(e["at"]) == "staff":
		return LEDGER.whereabouts(p, (_st().get("act", {}) as Dictionary).get(str(p.get("slug", "")), {}))
	var now := BUSINESS.crew_now(str(e["at"]))
	for q in now:
		if str(q.get("slug", "")) == str(p.get("slug", "")):
			return "At work"
	return "Off"


# ── doing ────────────────────────────────────────────────────────────────────

## Taken on at `place` (from tomorrow).
func _take_on(person: Dictionary, place: String) -> bool:
	var slug := str(person.get("slug", ""))
	var day := CoreRoot.get_day() + 1
	if place == "staff":
		if not RULES.can_hire(_st()):
			_shell.message_box(tr("Personal 98"), tr("No locker is free. One locker, one hand.\n\nBuy one on the Lockers page."), "error")
			return false
		return CoreRoot.actions.staff_hire(BRT.person(slug, "staff", BUSINESS.camp_seed()), day)
	return CoreRoot.actions.biz_hire(place, BRT.person(slug, _kind_of(place), BUSINESS.camp_seed()), day)


## Somebody working here moved to `place` (at once: they are in the camp already).
func _move(slug: String, place: String) -> void:
	var e := _entry(slug)
	if e.is_empty() or str(e["at"]) == place:
		return
	if place == "staff" and not RULES.can_hire(_st()):
		_shell.message_box(tr("Personal 98"), tr("No locker is free. One locker, one hand.\n\nBuy one on the Lockers page."), "error")
		return
	var p: Dictionary = (e["p"] as Dictionary)
	var since := int(p.get("since", CoreRoot.get_day()))
	var person := BRT.person(slug, _kind_of(place), BUSINESS.camp_seed())
	if str(e["at"]) == "staff":
		CoreRoot.actions.staff_fire(slug)
	else:
		CoreRoot.actions.biz_fire(str(e["at"]), slug)
	var ok: bool = CoreRoot.actions.staff_hire(person, since) if place == "staff" else CoreRoot.actions.biz_hire(place, person, since)
	if ok:
		_say(LANG.f("Moved: %s -> %s.", [str(p.get("name", "")), _place_label(place)]), GREEN)
		_shell.play("ding", -10.0)


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
	if id.begins_with("move:"):
		_move(_pick, id.substr(5))
		return
	if id.begins_with("take:"):
		var ap := _applicants()
		if ap.is_empty():
			return
		var p: Dictionary = ap[_candidate % ap.size()]
		var place := id.substr(5)
		if _take_on(p, place):
			_pick = str(p["slug"])
			_say(LANG.f("Taken on: %s, from tomorrow (%s).", [str(p["name"]), _place_label(place)]), GREEN)
			_shell.play("ding", -10.0)
		return
	if id.begins_with("job:"):
		var e := _entry(_pick)
		if e.is_empty() or str(e["at"]) != "staff":
			return
		var job := id.substr(4)
		CoreRoot.actions.staff_set_job(_pick, job, not RULES.does(e["p"], job))
		_shell.play("click", -12.0)
		return
	if id.begins_with("buy:"):
		var gid := id.substr(4)
		var price := RULES.gear_price(_st(), gid)
		var label := tr(str(RULES.GEAR[gid]["label"]))
		_shell.message_box(tr("Personal 98"), LANG.f("Buy a %s for $%d?", [label.to_lower(), price]), "question", [tr("Yes"), tr("No")], func(b: String):
			if b != tr("Yes"):
				return
			if CoreRoot.actions.staff_buy_gear(gid):
				_say(LANG.f("%s bought: it is in the staffroom.", label), GREEN)
				_shell.play("ding", -10.0)
			else:
				_shell.message_box(tr("Personal 98"), LANG.f("The purchase of $%d could not be made.\n\nThe camp has $%d.", [price, CoreRoot.get_money()]), "error")
			queue_redraw())
		return
	if id == "fire":
		var e2 := _entry(_pick)
		if e2.is_empty():
			return
		var slug := _pick
		var name := str((e2["p"] as Dictionary).get("name", ""))
		var at := str(e2["at"])
		_shell.message_box(tr("Personal 98"), LANG.f("Let %s go?", name), "question", [tr("Yes"), tr("No")], func(b: String):
			if b == tr("Yes"):
				if at == "staff":
					CoreRoot.actions.staff_fire(slug)
				else:
					CoreRoot.actions.biz_fire(at, slug)
				_pick = ""
				_say(LANG.f("%s has been let go.", name), T.TEXT_DISABLED)
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


## A place's button: its colour's chip, its name, what they ask there under it.
func _place_button(r: Rect2, place: String, id: String, enabled: bool, wage := -1) -> void:
	var pushed := enabled and _down == id and _hover == id
	draw_style_box(T.box("pressed" if pushed else "raised", T.FACE, Vector4.ZERO), r)
	var off := Vector2(1, 1) if pushed else Vector2.ZERO
	draw_rect(Rect2(r.position + Vector2(5, 6) + off, Vector2(8, 8)), PLACE_COL.get(_kind_of(place), T.NAVY) if enabled else T.SHADOW)
	var label := _place_label(place)
	if wage >= 0:
		label += "  " + LANG.money("$%d" % wage)
	_t(r.position + Vector2(17, 15) + off, label, T.TEXT if enabled else T.SHADOW)
	if enabled:
		_hit(id, r)


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
	_tr(band.end.x - 8, band.position.y + 16, LANG.f("Cash $%d", CoreRoot.get_money() if CoreRoot != null else 0), T.WHITE, true)
	var m := Rect2(4, band.end.y + 6, size.x - 8, size.y - band.end.y - 10 - STATUS_H - 2)
	if _places().is_empty() and _page != "lockers":
		draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), m)
		_tc(Rect2(m.position, Vector2(m.size.x, m.size.y * 0.5)), tr("Nowhere to work in the camp yet."), T.SHADOW)
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
	var wages := 0
	for e in _everyone():
		wages += int((e["p"] as Dictionary).get("wage", 0))
	var cells := [[_notice if _notice != "" else tr("Ready"), size.x - 4 - 90 - 140 - 120], [LANG.f("Day %d", CoreRoot.get_day() if CoreRoot != null else 0), 86],
		[LANG.f("Lockers %d / %d", [_crew().size(), RULES.gear_count(st, "locker")]), 136], [LANG.f("Wages $%d", wages), 116]]
	var x := 2.0
	for i in cells.size():
		var r := Rect2(x, y, float(cells[i][1]), STATUS_H - 2)
		draw_style_box(T.box("well", T.FACE, Vector4.ZERO), r)
		_t(r.position + Vector2(4, 13), str(cells[i][0]), _notice_col if i == 0 and _notice != "" else T.TEXT)
		x += r.size.x + 2


func _draw_staff(m: Rect2) -> void:
	var left := Rect2(m.position + Vector2(0, 8), Vector2(m.size.x * 0.56 - 6, m.size.y - 8))
	var right := Rect2(Vector2(left.end.x + 12, left.position.y), Vector2(m.end.x - left.end.x - 12, left.size.y))
	_group(left, tr("Everybody"))
	var all := _everyone()
	var lb := Rect2(left.position + Vector2(8, 14), Vector2(left.size.x - 16, ROWS * ROW_H + 4))
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), lb)
	if all.is_empty():
		_t(lb.position + Vector2(6, 15), tr("Nobody. You do it all yourself."), RED)
	if _entry(_pick).is_empty() and not all.is_empty():
		_pick = str((all[0]["p"] as Dictionary).get("slug", ""))
	for i in mini(all.size(), ROWS):
		var e: Dictionary = all[i]
		var p: Dictionary = e["p"]
		var r := Rect2(lb.position.x + 2, lb.position.y + 2 + i * ROW_H, lb.size.x - 4, ROW_H)
		var slug := str(p.get("slug", ""))
		var sel := slug == _pick
		if sel:
			draw_rect(r, T.NAVY)
		var fg := T.WHITE if sel else T.TEXT
		draw_rect(Rect2(r.position + Vector2(4, 5), Vector2(8, 8)), PLACE_COL.get(_kind_of(str(e["at"])), T.NAVY))
		_t(r.position + Vector2(16, 13), str(p.get("name", "")), fg)
		_t(r.position + Vector2(118, 13), _place_label(str(e["at"])), fg)
		var status := _status(e)
		var warn := status in ["Away today", "In a guest bed"] or int(p.get("owed", 0)) > 0
		_tr(r.end.x - 4, r.position.y + 13, LANG.f("Owed $%d", int(p.get("owed", 0))) if int(p.get("owed", 0)) > 0 else tr(status), (RED if warn and not sel else (GREEN if status == "From tomorrow" and not sel else fg)))
		_hit("crew:" + slug, r)
	if all.size() > ROWS:
		_t(Vector2(lb.position.x + 6, lb.end.y + 14), LANG.f("and %d more", all.size() - ROWS), T.SHADOW)
	# The one picked.
	var e2 := _entry(_pick)
	_group(right, tr("Works at"))
	if e2.is_empty():
		_t(right.position + Vector2(12, 30), tr("Nobody yet."), T.SHADOW)
		return
	var who: Dictionary = e2["p"]
	var pr := Rect2(right.position + Vector2(12, 18), Vector2(52, 66))
	_photo(pr, _pick)
	_t(Vector2(pr.end.x + 10, pr.position.y + 14), str(who.get("name", "")), T.TEXT, true)
	_t(Vector2(pr.end.x + 10, pr.position.y + 32), LANG.f("$%d a day", int(who.get("wage", 0))))
	var ways := [BRT.SPEED_WORD[clampi(int(who.get("speed", 1)), 0, 2)], str(BRT.TEMPER_WORD.get(str(who.get("temper", "flat")), ""))]
	var wy := pr.position.y + 50
	for w in ways:
		_t(Vector2(pr.end.x + 10, wy), tr(str(w)), T.SHADOW)
		wy += 14
	# A button for each place: where they are now pressed in, a click moves them.
	var places := _places()
	var bw := (right.size.x - 30) * 0.5
	var by := pr.end.y + 10
	for i in places.size():
		var place := str(places[i])
		var br := Rect2(right.position.x + 12 + (i % 2) * (bw + 6), by + (i / 2) * 24, bw, 22)
		if place == str(e2["at"]):
			draw_style_box(T.box("pressed", T.LIGHT, Vector4.ZERO), br)
			draw_rect(Rect2(br.position + Vector2(6, 7), Vector2(8, 8)), PLACE_COL.get(_kind_of(place), T.NAVY))
			_t(br.position + Vector2(18, 16), _place_label(place), T.TEXT, true)
		else:
			_place_button(br, place, "move:" + place, _would(_pick, place))
	var jy := by + ((places.size() + 1) / 2) * 24 + 6
	# The staffroom's jobs as tick boxes.
	if str(e2["at"]) == "staff":
		for i in RULES.JOBS.size():
			var id := str(RULES.JOBS[i][0])
			_check(Vector2(right.position.x + 12 + (i % 2) * (bw + 6), jy + (i / 2) * 20), tr(str(RULES.JOBS[i][1])), RULES.does(who, id), "job:" + id)
	_button(Rect2(right.end.x - 102, right.end.y - 30, 90, 22), tr("Let go"), "fire")


func _draw_hire(m: Rect2) -> void:
	var ap := _applicants()
	var left := Rect2(m.position + Vector2(0, 8), Vector2(m.size.x * 0.4 - 6, m.size.y - 8))
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
		_hit("cand:%d" % i, r2)
	var free := RULES.gear_count(_st(), "locker") - _crew().size()
	_t(Vector2(left.position.x + 12, alb.end.y + 22), LANG.f("Lockers free: %d", maxi(0, free)), GREEN if free > 0 else RED)
	_group(right, tr("Papers"))
	var p2: Dictionary = ap[_candidate % ap.size()]
	var slug := str(p2["slug"])
	var pr := Rect2(right.position + Vector2(12, 18), Vector2(52, 66))
	_photo(pr, slug)
	_t(Vector2(pr.end.x + 10, pr.position.y + 14), str(p2["name"]), T.TEXT, true)
	# (Their papers say how they are: the speed, the temper, where they come from.)
	var ty := pr.position.y + 34
	for line in p2.get("refs", []):
		_t(Vector2(pr.end.x + 10, ty), tr(str(line)), T.TEXT)
		ty += 15
	ty = maxf(ty, pr.end.y + 4)
	# Take them on at: a button for each place, with what they ask there.
	_t(Vector2(right.position.x + 12, ty + 8), tr("Take on at:"), T.TEXT, true)
	var places := _places()
	var bw := (right.size.x - 30) * 0.5
	var by := ty + 16
	for i in places.size():
		var place := str(places[i])
		var ok := _would(slug, place) and (place != "staff" or free > 0)
		_place_button(Rect2(right.position.x + 12 + (i % 2) * (bw + 6), by + (i / 2) * 24, bw, 22), place, "take:" + place, ok, _wage_at(slug, place))


func _draw_lockers(m: Rect2) -> void:
	var st := _st()
	var i := 0
	for id in ["locker", "armchair"]:
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
		_t(Vector2(tx, r.position.y + 52), LANG.f("In the staffroom: %d of %d", [RULES.gear_count(st, id), int(d["max"])]), T.TEXT, true)
		var price := RULES.gear_price(st, id)
		if price > 0:
			_t(Vector2(tx, r.position.y + 72), LANG.f("$%d", price), T.TEXT)
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
	for e2 in _everyone():
		wages += int((e2["p"] as Dictionary).get("wage", 0))
	var fy := m.end.y - 12
	_t(Vector2(m.position.x + 10, fy), LANG.f("Jobs today: %d   yesterday: %d", [int(st.get("done_n", 0)), int(st.get("done_y", 0))]), T.TEXT, true)
	_tr(m.end.x - 10, fy, LANG.f("Wages tonight: $%d", wages), T.TEXT, true)
