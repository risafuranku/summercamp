extends "res://scripts/closeup/closeup_view.gd"

## The business's books on the counter, close up (playtest 18. 10.; widened 20. 10.,
## DESIGN.md §7b): an accounts book open on the counter, five pages with tabs in pencil:
##   STOCK   what is on the shelves, a bar each, red when it is running low; what has
##           gone off in red, THROW OUT; the days before the oldest lot goes
##   ORDER   packs to order (- / +), what is already on order, the cost; the stamp sends
##           it, the van brings it in the morning
##   STAFF   who works here (their job, their shift, away today, owed) and who is asking
##           for work today (their ID photo, what they ask a day, what their papers say);
##           take one on, give somebody another job or shift, let them go
##   GEAR    better gear for the place (the only progression), bought here
##   BOOKS   today and yesterday (sold, takings, by you, went away, thrown out, short),
##           the place's average, OPEN LATE (the evening shift), the last Z report
## Picture: assets/textury/closeup/ledger.png (Grok). On it, renders too (closeup/parts/):
## the paper tabs, the pencilled boxes (nine-sliced), the pencil hatching of the bars, the
## rubber stamp's frame; only the writing is set here.

const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PIC := "res://assets/textury/closeup/ledger.png"
const SFX_STAMP := "res://assets/sfx/desk/stamp.mp3"
const SFX_PAGE := "res://assets/sfx/desk/paper_slide.mp3"
const PAGES := ["stock", "order", "staff", "gear", "books"]
const PAGE_LABEL := {"stock": "STOCK", "order": "ORDER", "staff": "STAFF", "gear": "GEAR", "books": "BOOKS"}
## The two pages of the open book (picture px, measured on the painting): the pencil lies
## in the gutter between them, the rubber stamp on the right page's bottom corner (it
## sends the order too).
const LEFT := Rect2(38, 40, 100, 140)
const RIGHT := Rect2(160, 40, 92, 140)
const STAMP := Rect2(232, 138, 58, 62)
const INK := Color(0.16, 0.18, 0.34)
const PENCIL := Color(0.3, 0.29, 0.28)
const RED := Color(0.66, 0.12, 0.1)
const GREEN := Color(0.1, 0.4, 0.14)
const PARTS := "res://assets/textury/closeup/parts/"
const PHOTOS := "res://assets/textury/os98/photos/"

## The Z report's receipt opens over the book (scripts/business/zreport_closeup.gd).
signal want_zreport(key: String)

var building_key := ""
var building_type := ""
var _page := "stock"
var _start_page := "stock"
var _order: Dictionary = {}
var _candidate := 0
var _picked := ""          # the crew member picked on the STAFF page (slug)
var _gear_pick := ""
var _stamp_t := -1.0
var _stamp_text := ""
var _tex: Dictionary = {}
var _boxes: Dictionary = {}           # colour -> the pencil box's nine-slice


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


## `page`: the one it opens on (the corn stand's leaflet opens it on "order").
func open_for(key: String, btype: String, page := "stock") -> void:
	building_key = key
	building_type = btype
	_start_page = page if page in PAGES else "stock"
	_order = {}
	_picked = ""
	_gear_pick = ""
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_site(key, btype)
	open_view()


func _kind() -> String:
	return RULES.kind_of(building_type)


func _site() -> Dictionary:
	return BUSINESS.site(building_key)


func _opened() -> void:
	play(SFX_PAGE, -8.0)
	var site := _site()
	if site.is_empty():
		say("", "No books for this place.")
		return
	_page = _start_page
	var off := 0
	for g in site.get("spoiled", {}):
		off += int(site["spoiled"][g])
	if off > 0:
		say("", "Something on the shelves has gone off.")
		return
	var lows: Array = []
	for g in site["stock"]:
		if RULES.is_low(_kind(), g, int(site["stock"][g])):
			lows.append(str(RULES.goods(_kind())[g]["label"]).to_lower())
	if not lows.is_empty():
		say("", "Running low: %s." % ", ".join(lows))
	elif not bool(site.get("staff", false)):
		say("", "Nobody behind the counter.")
	else:
		say("", "%s is behind the counter." % str(site.get("staff_name", "")))


# ── hotspots ─────────────────────────────────────────────────────────────────

func _tab_rect(i: int) -> Rect2:
	return Rect2(40 + i * 43, 24, 41, 13)


func _goods_keys() -> Array:
	return RULES.goods(_kind()).keys()


## The rows of a page: as many as the place has goods, packed to fit the page.
func _pitch() -> float:
	return minf(15.0, 96.0 / float(maxi(1, _goods_keys().size())))


## Under the page's head (the place, the day) and its title line.
const TOP := 74.0


func _row_y(i: int) -> float:
	return TOP + i * _pitch()


func _hotspots() -> Array:
	var out: Array = []
	for i in PAGES.size():
		out.append({"id": "tab:" + PAGES[i], "rect": _tab_rect(i)})
	var site := _site()
	if site.is_empty():
		return out
	match _page:
		"stock":
			if _spoiled_n(site) > 0:
				out.append({"id": "bin", "rect": _rbutton(0)})
		"order":
			var keys: Array = _goods_keys()
			for i in keys.size():
				var y := _row_y(i)
				out.append({"id": "minus:" + str(keys[i]), "rect": _minus_rect(y)})
				out.append({"id": "plus:" + str(keys[i]), "rect": _plus_rect(y)})
			out.append({"id": "send", "rect": _rbutton(0)})
			out.append({"id": "stamp", "rect": STAMP})
		"staff":
			var crew: Array = site.get("crew", [])
			for i in crew.size():
				out.append({"id": "crew:" + str(crew[i].get("slug", "")), "rect": Rect2(LEFT.position.x, TOP + i * 11 - 8, LEFT.size.x, 10)})
			if _picked != "":
				out.append({"id": "job", "rect": _lbutton(0)})
				out.append({"id": "shift", "rect": _lbutton(1)})
				out.append({"id": "fire", "rect": _lbutton(2)})
			if not _applicants().is_empty():
				out.append({"id": "next", "rect": _rbutton(1)})
				out.append({"id": "hire", "rect": _rbutton(0)})
		"gear":
			var gear: Array = RULES.gear_list(_kind()).keys()
			for i in gear.size():
				out.append({"id": "gearrow:" + str(gear[i]), "rect": Rect2(LEFT.position.x, TOP + i * 15 - 9, LEFT.size.x, 14)})
			if _gear_pick != "" and not RULES.has_gear(site, _gear_pick):
				out.append({"id": "buy", "rect": _rbutton(0)})
		"books":
			out.append({"id": "late", "rect": _rbutton(1)})
			if not (site.get("zreport", {}) as Dictionary).is_empty():
				out.append({"id": "zreport", "rect": _rbutton(0)})
	return out


func _minus_rect(y: float) -> Rect2:
	return Rect2(RIGHT.position.x + 1, y - 8, 11, 10)


func _plus_rect(y: float) -> Rect2:
	return Rect2(RIGHT.position.x + 33, y - 8, 11, 10)


## A pencilled button at the bottom of the right page (0 the lowest), clear of the stamp.
func _rbutton(i: int) -> Rect2:
	return Rect2(RIGHT.position.x, 160 - i * 18, 68, 14)


## One at the bottom of the left page.
func _lbutton(i: int) -> Rect2:
	return Rect2(LEFT.position.x + i * 34, 162, 32, 14)


func _applicants() -> Array:
	return BUSINESS.applicants(building_key)


func _crew_of(slug: String) -> Dictionary:
	for p in _site().get("crew", []):
		if str(p.get("slug", "")) == slug:
			return p
	return {}


func _spoiled_n(site: Dictionary) -> int:
	var n := 0
	for g in site.get("spoiled", {}):
		n += int(site["spoiled"][g])
	return n


func _clicked(id: String) -> void:
	if id.begins_with("tab:"):
		_page = id.substr(4)
		play(SFX_PAGE, -10.0)
		say("", "")
		return
	var site := _site()
	if site.is_empty():
		return
	var kind := _kind()
	if id.begins_with("plus:") or id.begins_with("minus:"):
		var g := id.get_slice(":", 1)
		var n: int = int(_order.get(g, 0)) + (1 if id.begins_with("plus:") else -1)
		var room: int = maxi(0, (RULES.cap_of(kind, g, site) - int(site["stock"].get(g, 0)) - BUSINESS.on_order(building_key, g)) / maxi(1, int(RULES.goods(kind)[g]["pack"])))
		if n > room:
			say("", "No room on the shelves for more %s." % str(RULES.goods(kind)[g]["label"]).to_lower())
			return
		_order[g] = clampi(n, 0, room)
		play(SFX_PAGE, -18.0)
		return
	if id.begins_with("crew:"):
		_picked = id.substr(5) if _picked != id.substr(5) else ""
		play(SFX_PAGE, -16.0)
		return
	if id.begins_with("gearrow:"):
		_gear_pick = id.substr(8)
		play(SFX_PAGE, -16.0)
		var gd: Dictionary = RULES.gear_list(kind)[_gear_pick]
		say("", str(gd["what"]))
		return
	match id:
		"send", "stamp":
			var cost: int = RULES.order_cost(kind, _order)
			if cost <= RULES.DELIVERY_FEE:
				say("", "Nothing written on the order.")
				return
			if not CoreRoot.actions.biz_order(building_key, _order, CoreRoot.get_day() + 1):
				say("", "That is $%d. The camp has not got it." % cost)
				return
			_order = {}
			_stamp("ORDERED")
			say("", "The van comes in the morning.")
		"bin":
			var n2: int = CoreRoot.actions.biz_bin(building_key)
			if n2 > 0:
				_stamp("THROWN OUT")
				say("", "%d in the bin." % n2)
		"next":
			_candidate += 1
			play(SFX_PAGE, -12.0)
		"hire":
			var ap := _applicants()
			if ap.is_empty():
				return
			var p: Dictionary = ap[_candidate % ap.size()]
			if CoreRoot.actions.biz_hire(building_key, p, CoreRoot.get_day()):
				_stamp("HIRED")
				_picked = str(p["slug"])
				var lines := ["I start now? Right.", "I'll need the keys.", "Fine. Cash on Fridays.", "Where do I put my coat?"]
				if str(p.get("strange", "")) == "night":
					lines = ["I know where everything is."]
				elif str(p.get("strange", "")) == "unseen":
					lines = ["I will be here."]
				say(str(p["name"]), str(lines[absi(hash(str(p["slug"]))) % lines.size()]))
		"job":
			var who := _crew_of(_picked)
			if who.is_empty():
				return
			var roles: Array = RULES.ROLES.get(kind, [])
			var i := 0
			for j in roles.size():
				if str(roles[j][0]) == str(who.get("role", "")):
					i = j
			var next_role := str(roles[(i + 1) % roles.size()][0])
			CoreRoot.actions.biz_set_job(building_key, _picked, next_role, str(who.get("shift", "day")))
			play(SFX_PAGE, -14.0)
		"shift":
			var who2 := _crew_of(_picked)
			if who2.is_empty():
				return
			var to := "late" if str(who2.get("shift", "day")) == "day" else "day"
			CoreRoot.actions.biz_set_job(building_key, _picked, str(who2.get("role", "")), to)
			if to == "late" and not bool(site.get("late", false)):
				say(str(who2.get("name", "")), "Evenings? You shut at eight.")
			play(SFX_PAGE, -14.0)
		"fire":
			var who3 := _crew_of(_picked)
			if who3.is_empty():
				return
			CoreRoot.actions.biz_fire(building_key, _picked)
			_stamp("PAID OFF")
			var line := "Suit yourself."
			match str(who3.get("strange", "")):
				"night":
					line = "He folds his apron. He was not on anybody's books in '97 either."
				"unseen":
					line = "She nods. Tomorrow she is at the counter again, and then she is not."
				_:
					line = ["Suit yourself.", "You will be back behind that counter by tonight.", "And my money?"][absi(hash(_picked)) % 3]
			say(str(who3.get("name", "")), line)
			_picked = ""
		"buy":
			var gd2: Dictionary = RULES.gear_list(kind).get(_gear_pick, {})
			if gd2.is_empty():
				return
			if CoreRoot.actions.biz_buy_gear(building_key, _gear_pick):
				_stamp("BOUGHT")
				say("", "%s. It is in." % str(gd2["label"]))
			else:
				say("", "That is $%d. The camp has not got it." % int(gd2["price"]))
		"late":
			CoreRoot.actions.biz_set_late(building_key, not bool(site.get("late", false)))
			_stamp("OPEN LATE" if bool(site.get("late", false)) else "SHUT AT 8")
		"zreport":
			want_zreport.emit(building_key)


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

func _font() -> Font:
	return RETRO_UI.FONT_TEXT


func _text(c: Control, pos: Vector2, s: String, col := INK, size := 8, font: Font = null) -> void:
	c.draw_string(font if font != null else _font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _right(c: Control, x: float, y: float, s: String, col := INK) -> void:
	var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(_font(), Vector2(x - w, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _centre(c: Control, r: Rect2, s: String, col: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(f, Vector2(r.get_center().x - w * 0.5, r.position.y + r.size.y * 0.5 + 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## Words wrapped to `width` px, from `at` down, `pitch` apart; returns the next y.
func _wrap_at(c: Control, at: Vector2, s: String, width: float, col := INK, pitch := 9.0) -> float:
	var line := ""
	var y := at.y
	for w in s.split(" "):
		var cand := w if line == "" else line + " " + w
		if _font().get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width and line != "":
			_text(c, Vector2(at.x, y), line, col)
			y += pitch
			line = w
		else:
			line = cand
	if line != "":
		_text(c, Vector2(at.x, y), line, col)
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


## A box pencilled round `r`: the render of a pencilled box, nine-sliced, in `col`.
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


func _paint(c: Control) -> void:
	var site := _site()
	var kind := _kind()
	var info: Dictionary = RULES.info(kind)
	# The tabs: paper slips stuck in along the top edge.
	for i in PAGES.size():
		var r := _tab_rect(i)
		var on: bool = PAGES[i] == _page
		var rr := r if on else Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 2))
		var tab := _part("paper_tab")
		if tab != null:
			c.draw_texture_rect(tab, rr, false, Color(1, 1, 1) if on else Color(0.82, 0.78, 0.7))
		_centre(c, rr, PAGE_LABEL[PAGES[i]], INK if on else PENCIL, RETRO_UI.FONT_LABEL)
		if hovered() == "tab:" + PAGES[i]:
			c.draw_rect(rr, Color(1, 0.9, 0.5, 0.18))
	if site.is_empty():
		return
	# The left page's head: the place and the day, always.
	_text(c, LEFT.position + Vector2(0, 8), str(info.get("name", "")).to_upper(), INK, 10, RETRO_UI.FONT_BIG)
	_right(c, LEFT.end.x, LEFT.position.y + 8, "Day %d" % CoreRoot.get_day(), PENCIL)
	match _page:
		"stock":
			_paint_stock(c, site, kind)
		"order":
			_paint_order(c, site, kind)
		"staff":
			_paint_staff(c, site, kind)
		"gear":
			_paint_gear(c, site, kind)
		"books":
			_paint_books(c, site, kind)
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


func _paint_stock(c: Control, site: Dictionary, kind: String) -> void:
	var gd: Dictionary = RULES.goods(kind)
	var keys: Array = _goods_keys()
	_text(c, LEFT.position + Vector2(0, 21), "On the shelves", PENCIL)
	_text(c, RIGHT.position + Vector2(0, 21), "Shelf      keeps", PENCIL)
	var day := CoreRoot.get_day()
	for i in keys.size():
		var g: String = keys[i]
		var d: Dictionary = gd[g]
		var n := int(site["stock"].get(g, 0))
		var y := _row_y(i)
		var low: bool = RULES.is_low(kind, g, n)
		var off := int((site.get("spoiled", {}) as Dictionary).get(g, 0))
		_text(c, Vector2(LEFT.position.x, y), str(d["label"]), RED if low else INK)
		_right(c, LEFT.end.x - (16 if off > 0 else 0), y, "%d" % n, RED if low else INK)
		if off > 0:
			_right(c, LEFT.end.x, y, "-%d" % off, RED)
		# The bar, hatched in pencil.
		var bar := Rect2(RIGHT.position.x, y - 7, 60, 7)
		var fill := bar.size.x * clampf(float(n) / float(maxi(1, RULES.cap_of(kind, g, site))), 0.0, 1.0)
		var hatch := _part("pencil_hatch")
		if hatch != null and fill >= 1.0:
			var tint := Color(1.6, 0.5, 0.45) if low else Color(1, 1, 1)
			c.draw_texture_rect_region(hatch, Rect2(bar.position + Vector2(1, 1), Vector2(fill - 2, bar.size.y - 2)), Rect2(0, 0, hatch.get_width() * fill / bar.size.x, hatch.get_height()), tint)
		elif fill >= 1.0:
			c.draw_rect(Rect2(bar.position, Vector2(fill, bar.size.y)), Color(0.4, 0.38, 0.36, 0.5))
		# Days before the oldest lot goes off.
		var left := RULES.days_left(kind, g, site.get("lots", {}).get(g, []), day)
		var life := RULES.life_of(kind, g, site)
		if left >= 0 and life > 0:
			left = maxi(0, life - (day - int(site["lots"][g][0][1])))
			_right(c, RIGHT.end.x, y, "%dd" % left, RED if left <= 1 else PENCIL)
	var due := 0
	for o in CoreRoot.get_state().biz.get("orders", []):
		if str(o.get("key", "")) == building_key:
			due += 1
	if due > 0:
		_text(c, Vector2(RIGHT.position.x, 140), "Van due: %d" % due, INK)
	if _spoiled_n(site) > 0:
		_pencil_button(c, _rbutton(0), "THROW OUT", RED, "bin")


func _paint_order(c: Control, site: Dictionary, kind: String) -> void:
	var gd: Dictionary = RULES.goods(kind)
	var keys: Array = _goods_keys()
	_text(c, LEFT.position + Vector2(0, 21), "Wholesaler", PENCIL)
	_right(c, LEFT.end.x, LEFT.position.y + 21, "van $%d" % RULES.DELIVERY_FEE, PENCIL)
	for i in keys.size():
		var g: String = keys[i]
		var d: Dictionary = gd[g]
		var y := _row_y(i)
		_text(c, Vector2(LEFT.position.x, y), str(d["label"]), INK)
		_right(c, LEFT.end.x, y, "$%d/%d" % [int(d["pack_cost"]), int(d["pack"])], PENCIL)
		var mr := _minus_rect(y)
		var pr := _plus_rect(y)
		for b in [["minus:", mr, "-"], ["plus:", pr, "+"]]:
			var r: Rect2 = b[1]
			if hovered() == str(b[0]) + g:
				c.draw_rect(r, Color(1, 0.9, 0.5, 0.3))
			_centre(c, r, str(b[2]), INK, RETRO_UI.FONT_BIG)
		_centre(c, Rect2(mr.end.x, mr.position.y, pr.position.x - mr.end.x, mr.size.y), "%d" % int(_order.get(g, 0)), INK)
		var on_units: int = BUSINESS.on_order(building_key, g)
		if on_units > 0:
			_text(c, Vector2(pr.end.x + 3, y), "+%d" % on_units, PENCIL)
	var cost: int = RULES.order_cost(kind, _order)
	_text(c, RIGHT.position + Vector2(0, 10), "Total $%d" % cost, INK, 10, RETRO_UI.FONT_BIG)
	_text(c, RIGHT.position + Vector2(0, 21), "Cash $%d" % CoreRoot.get_money(), PENCIL)
	_pencil_button(c, _rbutton(0), "SEND ORDER", RED, "send")
	if hovered() == "stamp":
		c.draw_rect(STAMP, Color(1, 0.9, 0.5, 0.12))


func _paint_staff(c: Control, site: Dictionary, kind: String) -> void:
	var crew: Array = site.get("crew", [])
	_text(c, LEFT.position + Vector2(0, 21), "Working here", PENCIL)
	var day := CoreRoot.get_day()
	if crew.is_empty():
		_text(c, Vector2(LEFT.position.x, TOP + 4), "Nobody.", RED, 10, RETRO_UI.FONT_BIG)
		_text(c, Vector2(LEFT.position.x, TOP + 14), "You serve.", RED)
	for i in crew.size():
		var p: Dictionary = crew[i]
		var y := TOP + i * 11.0
		var slug := str(p.get("slug", ""))
		if slug == _picked:
			c.draw_rect(Rect2(LEFT.position.x - 1, y - 8, LEFT.size.x + 2, 10), Color(1, 0.9, 0.5, 0.35))
		elif hovered() == "crew:" + slug:
			c.draw_rect(Rect2(LEFT.position.x - 1, y - 8, LEFT.size.x + 2, 10), Color(1, 0.9, 0.5, 0.15))
		var away := int(p.get("absent", -1)) == day
		_text(c, Vector2(LEFT.position.x, y), str(p.get("name", "")).replace("Mrs ", "Mrs."), RED if away else INK)
		var tag := RULES.role_label(kind, str(p.get("role", ""))).substr(0, 5)
		tag += " L" if str(p.get("shift", "day")) == "late" else ""
		if away:
			tag = "AWAY"
		elif int(p.get("owed", 0)) > 0:
			tag = "OWED"
		_right(c, LEFT.end.x, y, tag, RED if away or int(p.get("owed", 0)) > 0 else PENCIL)
	if _picked != "":
		var who := _crew_of(_picked)
		if not who.is_empty():
			_text(c, Vector2(LEFT.position.x, 150), "$%d a %s" % [RULES.shift_pay(who), "late shift" if str(who.get("shift", "day")) == "late" else "day"], INK)
			_pencil_button(c, _lbutton(0), "JOB", INK, "job")
			_pencil_button(c, _lbutton(1), "SHIFT", INK, "shift")
			_pencil_button(c, _lbutton(2), "GO", RED, "fire")
	# The right page: who is asking today.
	var ap := _applicants()
	_text(c, RIGHT.position + Vector2(0, 8), "Asking today", PENCIL)
	if ap.is_empty():
		_text(c, RIGHT.position + Vector2(0, 30), "Nobody.", PENCIL)
		return
	var p2: Dictionary = ap[_candidate % ap.size()]
	var ph := _photo(str(p2["slug"]))
	var pr := Rect2(RIGHT.position.x, 50, 32, 42)
	if ph != null:
		c.draw_texture_rect(ph, pr, false)
	c.draw_rect(pr.grow(1.0), PENCIL, false, 1.0)
	_text(c, Vector2(pr.end.x + 4, 58), str(p2["name"]).replace("Mrs ", "Mrs."), INK)
	_text(c, Vector2(pr.end.x + 4, 68), "$%d a day" % int(p2["wage"]), INK)
	_text(c, Vector2(pr.end.x + 4, 78), "%d of %d" % [_candidate % ap.size() + 1, ap.size()], PENCIL)
	var y2 := 102.0
	for line in p2.get("refs", []):
		y2 = _wrap_at(c, Vector2(RIGHT.position.x, y2), str(line), RIGHT.size.x, INK, 8.0)
	_pencil_button(c, _rbutton(1), "NEXT", PENCIL, "next")
	_pencil_button(c, _rbutton(0), "TAKE ON", GREEN, "hire")


func _paint_gear(c: Control, site: Dictionary, kind: String) -> void:
	var gear: Dictionary = RULES.gear_list(kind)
	_text(c, LEFT.position + Vector2(0, 21), "For the place", PENCIL)
	var i := 0
	for id in gear:
		var y := TOP + i * 15.0
		var g: Dictionary = gear[id]
		var owned := RULES.has_gear(site, str(id))
		if str(id) == _gear_pick:
			c.draw_rect(Rect2(LEFT.position.x - 1, y - 9, LEFT.size.x + 2, 14), Color(1, 0.9, 0.5, 0.35))
		elif hovered() == "gearrow:" + str(id):
			c.draw_rect(Rect2(LEFT.position.x - 1, y - 9, LEFT.size.x + 2, 14), Color(1, 0.9, 0.5, 0.15))
		_text(c, Vector2(LEFT.position.x, y), str(g["label"]), PENCIL if owned else INK)
		_right(c, LEFT.end.x, y, "IN" if owned else "$%d" % int(g["price"]), GREEN if owned else PENCIL)
		i += 1
	if _gear_pick == "" or not gear.has(_gear_pick):
		_text(c, RIGHT.position + Vector2(0, 21), "Pick one.", PENCIL)
		return
	var gd: Dictionary = gear[_gear_pick]
	_text(c, RIGHT.position + Vector2(0, 21), str(gd["label"]), INK)
	_wrap_at(c, RIGHT.position + Vector2(0, 34), str(gd["what"]), RIGHT.size.x, PENCIL)
	if RULES.has_gear(site, _gear_pick):
		_text(c, RIGHT.position + Vector2(0, 100), "In the place.", GREEN)
	else:
		_text(c, RIGHT.position + Vector2(0, 100), "$%d" % int(gd["price"]), INK, 10, RETRO_UI.FONT_BIG)
		_pencil_button(c, _rbutton(0), "BUY", GREEN, "buy")


func _paint_books(c: Control, site: Dictionary, kind: String) -> void:
	var rows := [["Sold", "sold"], ["Takings $", "takings"], ["By you", "by_hand"], ["Went away", "lost"], ["Thrown out", "waste"], ["Short", "short"]]
	_text(c, LEFT.position + Vector2(0, 21), "Today   Yesterday", PENCIL)
	for i in rows.size():
		var y := TOP + i * 11.0
		var key: String = rows[i][1]
		var t := int((site["today"] as Dictionary).get(key, 0))
		var yd := int((site["yesterday"] as Dictionary).get(key, 0))
		var bad := key in ["lost", "waste", "short"]
		_text(c, Vector2(LEFT.position.x, y), str(rows[i][0]), PENCIL)
		_right(c, LEFT.end.x - 30, y, str(t), RED if bad and t > 0 else INK)
		_right(c, LEFT.end.x, y, str(yd), RED if bad and yd > 0 else INK)
	var n := int(site.get("all_orders", 0))
	if n > 0:
		_text(c, Vector2(LEFT.position.x, 146), "Orders rated %d" % n, PENCIL)
		_text(c, Vector2(LEFT.position.x, 157), "Average %d%%" % int(round(float(site.get("all_score", 0)) / float(n))), INK, 10, RETRO_UI.FONT_BIG)
	var wages := 0
	for p in site.get("crew", []):
		wages += RULES.shift_pay(p)
	if wages > 0:
		_text(c, Vector2(LEFT.position.x, 170), "Wages tonight $%d" % wages, INK)
	var late := bool(site.get("late", false))
	_text(c, RIGHT.position + Vector2(0, 21), "Open till", PENCIL)
	_text(c, RIGHT.position + Vector2(0, 34), "11 at night" if late else "8 in the evening", INK, 10, RETRO_UI.FONT_BIG)
	_pencil_button(c, _rbutton(1), "SHUT AT 8" if late else "OPEN LATE", RED if late else INK, "late")
	if not (site.get("zreport", {}) as Dictionary).is_empty():
		_pencil_button(c, _rbutton(0), "Z REPORT", INK, "zreport")
