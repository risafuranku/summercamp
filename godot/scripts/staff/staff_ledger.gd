extends "res://scripts/closeup/closeup_view.gd"

## The staffroom's books on its table, close up (DESIGN.md §7c): the same accounts book
## as the businesses' (assets/textury/closeup/ledger.png and its pencilled parts), four
## pages with tabs:
##   STAFF   who works here, where each one is now (resting, out at a job, home, in a
##           guest's bed); the one picked: their wage and their jobs, a pencilled box
##           ticked for each (rubbish, raccoons, deliveries, branches, lodgings), LET GO
##   HIRE    who is asking today (their ID photo, what they ask a day, what their papers
##           say), TAKE ON: only with a locker free
##   ROOM    the cards glued in (a catalogue cut-out each): one more locker, one more
##           mattress, what the next one costs, BUY
##   DAY     what the hands did today, their wages tonight
## The same is on the office PC in SoftSklad's Personal 98 (os98/apps/staff_app.gd).

const RULES := preload("res://core/systems/staff_rules.gd")
const BRT := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PIC := "res://assets/textury/closeup/ledger.png"
const PARTS := "res://assets/textury/closeup/parts/"
const PHOTOS := "res://assets/textury/os98/photos/"
const SFX_STAMP := "res://assets/sfx/desk/stamp.mp3"
const SFX_PAGE := "res://assets/sfx/desk/paper_slide.mp3"
const PAGES := ["staff", "hire", "room", "day"]
const PAGE_LABEL := {"staff": "STAFF", "hire": "HIRE", "room": "LOCKERS", "day": "TODAY"}
const LEFT := Rect2(38, 40, 100, 140)
const RIGHT := Rect2(160, 40, 92, 140)
const INK := Color(0.16, 0.18, 0.34)
const PENCIL := Color(0.3, 0.29, 0.28)
const RED := Color(0.66, 0.12, 0.1)
const GREEN := Color(0.1, 0.4, 0.14)
const TOP := 74.0
static var _last_page := "staff"

var _page := "staff"
var _picked := ""
var _candidate := 0
var _gear_pick := "locker"
var _stamp_t := -1.0
var _stamp_text := ""
var _tex: Dictionary = {}
var _boxes: Dictionary = {}


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


func close_now() -> void:
	visible = false


func _opened() -> void:
	play(SFX_PAGE, -8.0)
	_page = _last_page
	var crew := _crew()
	if _picked == "" and not crew.is_empty():
		_picked = str(crew[0].get("slug", ""))
	if crew.is_empty():
		say("", tr("Nobody works here yet. Somebody is asking: the HIRE page."))
	else:
		say("", tr("%d on the books, %d lockers.") % [crew.size(), RULES.gear_count(_st(), "locker")])


func _st() -> Dictionary:
	return CoreRoot.actions.staff_state() if CoreRoot != null and CoreRoot.actions != null else {}


func _crew() -> Array:
	return _st().get("crew", [])


func _who(slug: String) -> Dictionary:
	for p in _crew():
		if str(p.get("slug", "")) == slug:
			return p
	return {}


func _applicants() -> Array:
	var taken: Array = []
	for p in _crew():
		taken.append(str(p.get("slug", "")))
	if CoreRoot != null and CoreRoot.get_state() != null:
		for k in CoreRoot.get_state().biz.get("sites", {}):
			for p in CoreRoot.get_state().biz["sites"][k].get("crew", []):
				taken.append(str(p.get("slug", "")))
	return RULES.applicants(CoreRoot.get_day(), taken, BUSINESS.camp_seed())


## Where a hand is now, in a word (staff_runtime's act).
static func whereabouts(p: Dictionary, act: Dictionary) -> String:
	match str(act.get("do", "home")):
		"home":
			return "Home"
		"coffee":
			return "Coffee"
		"rest":
			return "In a guest bed" if str(act.get("spot", "")).begins_with("bed:") else "Resting"
		"walk":
			var nx: Dictionary = act.get("next", {})
			if str(nx.get("do", "")) == "work":
				return RULES.job_label(str(nx.get("what", "")))
			return "Walking"
		"work":
			return RULES.job_label(str(act.get("what", "")))
	return ""


# ── hotspots ─────────────────────────────────────────────────────────────────

func _tab_rect(i: int) -> Rect2:
	var x := 38.0
	for j in i:
		x += _tab_w(j) + 2.0
	return Rect2(x, 24, _tab_w(i), 13)


func _tab_w(i: int) -> float:
	var w := RETRO_UI.FONT_LABEL.get_string_size(tr(str(PAGE_LABEL[PAGES[i]])), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	return maxf(30.0, w + 8.0)


func _rbutton(i: int) -> Rect2:
	return Rect2(RIGHT.position.x, 160 - i * 18, 68, 14)


func _job_rect(i: int) -> Rect2:
	return Rect2(RIGHT.position.x, 84 + i * 13 - 9, RIGHT.size.x, 12)


func _card_rect(id: String) -> Rect2:
	return Rect2(LEFT.position.x + 4, 52, 40, 60) if id == "locker" else Rect2(LEFT.position.x + 48, 66, 50, 36)


func _hotspots() -> Array:
	var out: Array = []
	for i in PAGES.size():
		out.append({"id": "tab:" + PAGES[i], "rect": _tab_rect(i)})
	match _page:
		"staff":
			var crew := _crew()
			for i in crew.size():
				out.append({"id": "crew:" + str(crew[i].get("slug", "")), "rect": Rect2(LEFT.position.x, TOP + i * 13 - 9, LEFT.size.x, 12)})
			if _picked != "" and not _who(_picked).is_empty():
				for i in RULES.JOBS.size():
					out.append({"id": "job:" + str(RULES.JOBS[i][0]), "rect": _job_rect(i)})
				out.append({"id": "fire", "rect": _rbutton(0)})
		"hire":
			if not _applicants().is_empty():
				out.append({"id": "next", "rect": _rbutton(1)})
				out.append({"id": "hire", "rect": _rbutton(0)})
		"room":
			for id in ["locker", "mattress"]:
				out.append({"id": "card:" + id, "rect": _card_rect(id)})
			if RULES.gear_price(_st(), _gear_pick) > 0:
				out.append({"id": "buy", "rect": _rbutton(0)})
	return out


func _clicked(id: String) -> void:
	if id.begins_with("tab:"):
		_page = id.substr(4)
		_last_page = _page
		play(SFX_PAGE, -10.0)
		say("", "")
		return
	if id.begins_with("crew:"):
		_picked = id.substr(5)
		play(SFX_PAGE, -16.0)
		return
	if id.begins_with("job:"):
		var job := id.substr(4)
		var p := _who(_picked)
		if p.is_empty():
			return
		var jobs: Dictionary = p.get("jobs", RULES.default_jobs())
		var on := not bool(jobs.get(job, true))
		CoreRoot.actions.staff_set_job(_picked, job, on)
		play(SFX_PAGE, -14.0)
		return
	if id.begins_with("card:"):
		_gear_pick = id.substr(5)
		play(SFX_PAGE, -16.0)
		say("", tr(str(RULES.GEAR[_gear_pick]["what"])))
		return
	match id:
		"fire":
			var p2 := _who(_picked)
			if p2.is_empty():
				return
			CoreRoot.actions.staff_fire(_picked)
			_stamp(tr("PAID OFF"))
			var lines := ["Suit yourself.", "And who sweeps up now? You?", "I'll leave the key on the boiler."]
			say(str(p2.get("name", "")), tr(str(lines[absi(hash(_picked)) % lines.size()])))
			_picked = ""
		"next":
			_candidate += 1
			play(SFX_PAGE, -12.0)
		"hire":
			var ap := _applicants()
			if ap.is_empty():
				return
			var who: Dictionary = ap[_candidate % ap.size()]
			if not RULES.can_hire(_st()):
				say("", tr("No locker free. One locker, one hand: buy one on the LOCKERS page."))
				return
			if CoreRoot.actions.staff_hire(who, CoreRoot.get_day()):
				_stamp(tr("HIRED"))
				_picked = str(who["slug"])
				var lines := ["Tomorrow at seven, then.", "Where's my locker?", "I bring my own broom.", "Cash on Fridays."]
				if str(who.get("strange", "")) == "night":
					lines = ["I know where the boiler room is."]
				elif str(who.get("strange", "")) == "unseen":
					lines = ["You will not notice me."]
				say(str(who["name"]), tr(str(lines[absi(hash(str(who["slug"]))) % lines.size()])))
		"buy":
			var g: Dictionary = RULES.GEAR.get(_gear_pick, {})
			if CoreRoot.actions.staff_buy_gear(_gear_pick):
				_stamp(tr("BOUGHT"))
				say("", tr("%s. It is in the boiler room.") % tr(str(g.get("label", ""))))
			else:
				say("", tr("That is $%d. The camp has not got it.") % RULES.gear_price(_st(), _gear_pick))


func _stamp(text: String) -> void:
	_stamp_t = 0.0
	_stamp_text = text
	play(SFX_STAMP, -4.0)


func _tick(delta: float) -> void:
	if _stamp_t >= 0.0:
		_stamp_t += delta
		if _stamp_t > 1.6:
			_stamp_t = -1.0


# ── drawing ──────────────────────────────────────────────────────────────────

func _text(c: Control, pos: Vector2, s: String, col := INK, size := 8, font: Font = null) -> void:
	c.draw_string(font if font != null else RETRO_UI.FONT_TEXT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _right(c: Control, x: float, y: float, s: String, col := INK) -> void:
	var w := RETRO_UI.FONT_TEXT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x - w, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _centre(c: Control, r: Rect2, s: String, col: Color, font: Font = null) -> void:
	var f: Font = font if font != null else RETRO_UI.FONT_TEXT
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(f, Vector2(r.get_center().x - w * 0.5, r.position.y + r.size.y * 0.5 + 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _wrap_at(c: Control, at: Vector2, s: String, width: float, col := INK, pitch := 9.0) -> float:
	var y := at.y
	for line in _wrap(s, RETRO_UI.FONT_TEXT, 8, width):
		_text(c, Vector2(at.x, y), str(line), col)
		y += pitch
	return y


func _part(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(PARTS + key + ".png") if ResourceLoader.exists(PARTS + key + ".png") else null
	return _tex[key]


func _photo(slug: String) -> Texture2D:
	var name := BUSINESS.photo_of(slug)
	var k := "photo:" + name
	if not _tex.has(k):
		var p := PHOTOS + name + ".png"
		_tex[k] = load(p) if ResourceLoader.exists(p) else null
	return _tex[k]


func _pencil_box(c: Control, r: Rect2, col := PENCIL) -> void:
	var t := _part("pencil_box")
	if t == null:
		c.draw_rect(r, col, false, 1.0)
		return
	var key := col.to_html()
	if not _boxes.has(key):
		var sb := StyleBoxTexture.new()
		sb.texture = t
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sb.set_texture_margin(side, 4.0)
		sb.modulate_color = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6)
		_boxes[key] = sb
	c.draw_style_box(_boxes[key], r)


func _pencil_button(c: Control, r: Rect2, label: String, col: Color, id: String) -> void:
	if hovered() == id:
		c.draw_rect(r, Color(col.r, col.g, col.b, 0.22))
	_pencil_box(c, r, col)
	_centre(c, r, label, col, RETRO_UI.FONT_LABEL)


func _tick_mark(c: Control, box: Rect2, col: Color) -> void:
	for p in [Vector2(2, 4), Vector2(3, 5), Vector2(4, 6), Vector2(5, 5), Vector2(6, 4), Vector2(7, 3), Vector2(7, 2)]:
		c.draw_rect(Rect2(box.position + p, Vector2(1, 1)), col)


func _paint(c: Control) -> void:
	for i in PAGES.size():
		var r := _tab_rect(i)
		var on: bool = PAGES[i] == _page
		var rr := r if on else Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 2))
		var tab := _part("paper_tab")
		if tab != null:
			c.draw_texture_rect(tab, rr, false, Color(1, 1, 1) if on else Color(0.82, 0.78, 0.7))
		_centre(c, rr, tr(str(PAGE_LABEL[PAGES[i]])), INK if on else PENCIL, RETRO_UI.FONT_LABEL)
		if hovered() == "tab:" + PAGES[i]:
			c.draw_rect(rr, Color(1, 0.9, 0.5, 0.18))
	_text(c, LEFT.position + Vector2(0, 8), tr("STAFFROOM"), INK, 10, RETRO_UI.FONT_BIG)
	_right(c, LEFT.end.x, LEFT.position.y + 8, tr("Day %d") % CoreRoot.get_day(), PENCIL)
	match _page:
		"staff":
			_paint_staff(c)
		"hire":
			_paint_hire(c)
		"room":
			_paint_room(c)
		"day":
			_paint_day(c)
	if _stamp_t >= 0.0:
		var k := clampf(_stamp_t * 6.0, 0.0, 1.0)
		var sz := lerpf(2.0, 1.0, k)
		var col := Color(0.72, 0.1, 0.12, 0.85 * clampf(2.0 - _stamp_t, 0.0, 1.0))
		var font: Font = RETRO_UI.FONT_BIG
		var w := font.get_string_size(_stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * sz)).x
		var at := Vector2(RIGHT.get_center().x - w * 0.5, 120)
		var frame := _part("stamp_frame")
		if frame != null:
			c.draw_texture_rect(frame, Rect2(at - Vector2(8, 15 * sz), Vector2(w + 16, 20 * sz)), false, Color(1, 1, 1, col.a))
		c.draw_string(font, at, _stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * sz), col)


func _paint_staff(c: Control) -> void:
	var crew := _crew()
	var acts: Dictionary = _st().get("act", {})
	_text(c, LEFT.position + Vector2(0, 21), tr("Working here"), PENCIL)
	if crew.is_empty():
		_text(c, Vector2(LEFT.position.x, TOP + 4), tr("Nobody."), RED, 10, RETRO_UI.FONT_BIG)
		_text(c, Vector2(LEFT.position.x, TOP + 14), tr("You do it all."), RED)
	for i in crew.size():
		var p: Dictionary = crew[i]
		var y := TOP + i * 13.0
		var slug := str(p.get("slug", ""))
		var row := Rect2(LEFT.position.x - 1, y - 9, LEFT.size.x + 2, 12)
		if slug == _picked:
			c.draw_rect(row, Color(1, 0.9, 0.5, 0.35))
		elif hovered() == "crew:" + slug:
			c.draw_rect(row, Color(1, 0.9, 0.5, 0.15))
		_text(c, Vector2(LEFT.position.x, y), str(p.get("name", "")).replace("Mrs ", "Mrs."), INK)
		var where := whereabouts(p, acts.get(slug, {}))
		if int(p.get("owed", 0)) > 0:
			where = "OWED"
		_right(c, LEFT.end.x, y, tr(where).substr(0, 9), RED if where in ["OWED", "In a guest bed"] else PENCIL)
	var lockers := RULES.gear_count(_st(), "locker")
	_text(c, Vector2(LEFT.position.x, 172), tr("Lockers %d / %d") % [crew.size(), lockers], PENCIL)
	var who := _who(_picked)
	if who.is_empty():
		_text(c, RIGHT.position + Vector2(0, 21), tr("Pick one."), PENCIL)
		return
	_text(c, RIGHT.position + Vector2(0, 8), str(who.get("name", "")).replace("Mrs ", "Mrs."), INK)
	_text(c, RIGHT.position + Vector2(0, 19), tr("$%d a day") % RULES.wage_of(who), PENCIL)
	var jobs: Dictionary = who.get("jobs", RULES.default_jobs())
	_text(c, RIGHT.position + Vector2(0, 30), tr("Sees to:"), PENCIL)
	for i in RULES.JOBS.size():
		var r := _job_rect(i)
		var id := str(RULES.JOBS[i][0])
		var on := bool(jobs.get(id, true))
		if hovered() == "job:" + id:
			c.draw_rect(r, Color(1, 0.9, 0.5, 0.18))
		var box := Rect2(r.position + Vector2(0, 2), Vector2(9, 9))
		_pencil_box(c, box, PENCIL)
		if on:
			_tick_mark(c, box, GREEN)
		_text(c, Vector2(r.position.x + 12, r.position.y + 9), tr(str(RULES.JOBS[i][1])), INK if on else PENCIL)
	_pencil_button(c, _rbutton(0), tr("LET GO"), RED, "fire")


func _paint_hire(c: Control) -> void:
	var free := RULES.gear_count(_st(), "locker") - _crew().size()
	_text(c, LEFT.position + Vector2(0, 21), tr("Lockers free"), PENCIL)
	_text(c, Vector2(LEFT.position.x, TOP + 6), "%d" % maxi(0, free), GREEN if free > 0 else RED, 10, RETRO_UI.FONT_BIG)
	var y := _wrap_at(c, Vector2(LEFT.position.x, TOP + 22), tr("One locker, one hand. They come at seven and go home at eight."), LEFT.size.x, PENCIL)
	if free <= 0:
		_wrap_at(c, Vector2(LEFT.position.x, y + 6), tr("Buy a locker first: the LOCKERS page."), LEFT.size.x, RED)
	var ap := _applicants()
	_text(c, RIGHT.position + Vector2(0, 8), tr("Asking today"), PENCIL)
	if ap.is_empty():
		_text(c, RIGHT.position + Vector2(0, 30), tr("Nobody."), PENCIL)
		return
	var p2: Dictionary = ap[_candidate % ap.size()]
	var ph := _photo(str(p2["slug"]))
	var pr := Rect2(RIGHT.position.x, 50, 32, 42)
	if ph != null:
		c.draw_texture_rect(ph, pr, false)
	c.draw_rect(pr.grow(1.0), PENCIL, false, 1.0)
	_text(c, Vector2(pr.end.x + 4, 58), str(p2["name"]).replace("Mrs ", "Mrs."), INK)
	_text(c, Vector2(pr.end.x + 4, 68), tr("$%d a day") % int(p2["wage"]), INK)
	_text(c, Vector2(pr.end.x + 4, 78), tr("%d of %d") % [_candidate % ap.size() + 1, ap.size()], PENCIL)
	var y2 := 102.0
	for line in p2.get("refs", []):
		y2 = _wrap_at(c, Vector2(RIGHT.position.x, y2), tr(str(line)), RIGHT.size.x, INK, 8.0)
	_pencil_button(c, _rbutton(1), tr("NEXT"), PENCIL, "next")
	_pencil_button(c, _rbutton(0), tr("TAKE ON"), GREEN if free > 0 else PENCIL, "hire")


func _paint_room(c: Control) -> void:
	_text(c, LEFT.position + Vector2(0, 21), tr("For the boiler room"), PENCIL)
	var st := _st()
	for id in ["locker", "mattress"]:
		var r := _card_rect(id)
		var t := _part("card_" + id)
		if id == _gear_pick:
			c.draw_rect(r.grow(2.0), Color(1, 0.9, 0.5, 0.35))
		elif hovered() == "card:" + id:
			c.draw_rect(r.grow(2.0), Color(1, 0.9, 0.5, 0.15))
		if t != null:
			var sz := t.get_size()
			var k := minf(r.size.x / sz.x, r.size.y / sz.y)
			c.draw_texture_rect(t, Rect2(r.position + (r.size - sz * k) * 0.5, sz * k), false)
		var d: Dictionary = RULES.GEAR[id]
		_text(c, Vector2(r.position.x, r.end.y + 10), "%d / %d" % [RULES.gear_count(st, id), int(d["max"])], INK)
	var g: Dictionary = RULES.GEAR[_gear_pick]
	_text(c, RIGHT.position + Vector2(0, 21), tr(str(g["label"])), INK)
	_wrap_at(c, RIGHT.position + Vector2(0, 34), tr(str(g["what"])), RIGHT.size.x, PENCIL)
	var price := RULES.gear_price(st, _gear_pick)
	if price <= 0:
		_text(c, RIGHT.position + Vector2(0, 100), tr("No room for more."), GREEN)
	else:
		_text(c, RIGHT.position + Vector2(0, 100), tr("$%d") % price, INK, 10, RETRO_UI.FONT_BIG)
		_pencil_button(c, _rbutton(0), tr("BUY"), GREEN, "buy")


func _paint_day(c: Control) -> void:
	var st := _st()
	_text(c, LEFT.position + Vector2(0, 21), tr("Done today"), PENCIL)
	var day := CoreRoot.get_day()
	var y := TOP
	var lines: Array = []
	for e in st.get("log", []):
		if int(e.get("day", 0)) == day:
			lines.append(e)
	lines = lines.slice(maxi(0, lines.size() - 9))
	if lines.is_empty():
		_text(c, Vector2(LEFT.position.x, y), tr("Nothing yet."), PENCIL)
	for e in lines:
		var m := int(e.get("t", 0)) % 1440
		var t := "%d:%02d " % [m / 60, m % 60]
		y = _wrap_at(c, Vector2(LEFT.position.x, y), t + tr(str(e.get("text", ""))), LEFT.size.x, INK, 8.0)
		if y > 176.0:
			break
	var wages := 0
	for p in _crew():
		wages += RULES.wage_of(p)
	_text(c, RIGHT.position + Vector2(0, 21), tr("Wages tonight"), PENCIL)
	_text(c, RIGHT.position + Vector2(0, 36), tr("$%d") % wages, INK, 10, RETRO_UI.FONT_BIG)
	_text(c, RIGHT.position + Vector2(0, 56), tr("Jobs today %d") % int(st.get("done_n", 0)), INK)
	_text(c, RIGHT.position + Vector2(0, 68), tr("Yesterday %d") % int(st.get("done_y", 0)), PENCIL)
