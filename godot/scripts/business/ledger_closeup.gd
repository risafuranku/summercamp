extends "res://scripts/closeup/closeup_view.gd"

## The business's books on the counter, close up (playtest 18. 10.; widened 20. 10.,
## DESIGN.md §7b; Richard 8. 11.: "polish the books, the staff, the goods and the orders,
## some stats of profit and costs"): an accounts book open on the counter, five pages with
## tabs in pencil, the same pages in the same order in every place (the brief of 21. 10.;
## opened from the frame's BOOKS, B, as well as from the book in the room):
##   GOODS   what is on the shelf and how long it lasts, what is on the van, packs to
##           order on the same row (- / +), FILL writes in what a few days want, the
##           stamp sends it, the van brings it in the morning
##   MENU    what is sold: a pencilled box ticked for each dish, drink or good on the
##           menu; untick it and the guests do not order it (the place's own is always on)
##   STAFF   who works here (their job, their shift, away today, owed), a click on a name
##           their card on the right (their job, their shift, let go); with nobody picked
##           who is asking for work today (their ID photo, what they ask, their papers)
##   GEAR    better gear for the place (the only progression), bought here
##   ACCOUNTS the place's money today and yesterday (takings, goods, wages, the van, short,
##           profit), sold and went away; the last week's profit as a pencil chart, its
##           sum and the place's whole run, the last shift's mark; OPEN LATE, the Z report
## Picture: assets/textury/closeup/ledger.png (Grok). On it, renders too (closeup/parts/):
## the paper tabs, the pencilled boxes (nine-sliced), the pencil hatching of the bars, the
## rubber stamp's frame; only the writing is set here.

const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const LANG := preload("res://scripts/lang.gd")
const PIC := "res://assets/textury/closeup/ledger.png"
const SFX_STAMP := "res://assets/sfx/desk/stamp.mp3"
const SFX_PAGE := "res://assets/sfx/desk/paper_slide.mp3"
const PAGES := ["goods", "menu", "staff", "gear", "books"]
const PAGE_LABEL := {"goods": "GOODS", "menu": "MENU", "staff": "STAFF", "gear": "GEAR", "books": "ACCOUNTS"}
## The page last open (it opens there again).
static var _last_page := "goods"
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
var _page := "goods"
var _start_page := "goods"
## What the strip last said for the row under the pointer.
var _row_said := ""
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
	strip_over = true
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


## `page`: the one it opens on (the corn stand's leaflet opens it on "order").
func open_for(key: String, btype: String, page := "") -> void:
	building_key = key
	building_type = btype
	# (The old pages' names: the stand's leaflet opened on "order".)
	_start_page = "goods" if page in ["stock", "order"] else (page if page in PAGES else _last_page)
	_sheet = 0
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
	var lows: Array = []
	for g in site["stock"]:
		if RULES.is_low(_kind(), g, int(site["stock"][g])):
			lows.append(tr(str(RULES.goods(_kind())[g]["label"])).to_lower())
	if not lows.is_empty():
		say("", LANG.f("Running low: %s.", ", ".join(lows)))
	elif not bool(site.get("staff", false)):
		say("", "Nobody behind the counter.")
	else:
		say("", LANG.f("%s is behind the counter.", str(site.get("staff_name", ""))))


# ── hotspots ─────────────────────────────────────────────────────────────────

## The tabs along the top edge, each as wide as its word.
func _tab_rect(i: int) -> Rect2:
	var x := 38.0
	for j in i:
		x += _tab_w(j) + 1.0
	return Rect2(x, 24, _tab_w(i), 13)


## (Close round the word: the six in Czech ran off the picture, Z REPORT cut in half.)
func _tab_w(i: int) -> float:
	var w := RETRO_UI.FONT_LABEL.get_string_size(tr(str(PAGE_LABEL[PAGES[i]])), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	return maxf(26.0, w + 5.0)


## The goods on the sheet open now. A page holds SHEET_ROWS; more than that (the shop has
## seventeen, packed to fit they ran into each other) go on sheets of their own.
const SHEET_ROWS := 8
var _sheet := 0


func _goods_keys() -> Array:
	var all: Array = RULES.goods(_kind()).keys()
	var n := _sheets()
	if n <= 1:
		return all
	var per := ceili(float(all.size()) / float(n))
	return all.slice(mini(_sheet, n - 1) * per, (mini(_sheet, n - 1) + 1) * per)


func _sheets() -> int:
	return ceili(float(RULES.goods(_kind()).size()) / float(SHEET_ROWS))


## The rows of a page: as many as the sheet has goods, packed to fit the page.
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
		"menu":
			var rows: Array = RULES.MENU.get(_kind(), [])
			for i in rows.size():
				if not bool(rows[i][2]):
					out.append({"id": "menu:" + str(rows[i][0]), "rect": _menu_rect(i, rows.size())})
		"goods":
			if _sheets() > 1:
				out.append({"id": "sheet", "rect": _lbutton(0)})
			var keys: Array = _goods_keys()
			for i in keys.size():
				var y := _row_y(i)
				out.append({"id": "minus:" + str(keys[i]), "rect": _minus_rect(y)})
				out.append({"id": "plus:" + str(keys[i]), "rect": _plus_rect(y)})
			for i in keys.size():
				out.append({"id": "row:" + str(keys[i]), "rect": Rect2(LEFT.position.x - 1, _row_y(i) - 8, RIGHT.end.x - LEFT.position.x + 2, _pitch())})
			out.append({"id": "send", "rect": _rbutton(0)})
			out.append({"id": "stamp", "rect": STAMP})
			out.append({"id": "auto", "rect": _auto_rect()})
			out.append({"id": "fill", "rect": _fill_rect()})
		"staff":
			var crew: Array = site.get("crew", [])
			for i in crew.size():
				out.append({"id": "crew:" + str(crew[i].get("slug", "")), "rect": _crew_row(i)})
			if _picked != "" and not _crew_of(_picked).is_empty():
				var roles: Array = RULES.ROLES.get(_kind(), [])
				for i in roles.size():
					out.append({"id": "role:" + str(roles[i][0]), "rect": _role_rect(i)})
				out.append({"id": "shift", "rect": _rbutton(0)})
				out.append({"id": "fire", "rect": _fire_rect()})
				out.append({"id": "asking", "rect": _asking_rect()})
			elif not _applicants().is_empty():
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


## A row of the menu: down the left page, then the right.
func _menu_rect(i: int, n: int) -> Rect2:
	var per := 7 if n > 7 else n
	var col := i / per
	var row := i % per
	var page := LEFT if col == 0 else RIGHT
	return Rect2(page.position.x, TOP + row * 13 - 9, page.size.x, 12)


func _minus_rect(y: float) -> Rect2:
	return Rect2(RIGHT.position.x + 1, y - 8, 11, 10)


func _plus_rect(y: float) -> Rect2:
	return Rect2(RIGHT.position.x + 33, y - 8, 11, 10)


## A pencilled button at the bottom of the right page (0 the lowest), clear of the stamp.
## The tick on the ORDER page: the hands see to the shelves themselves.
func _auto_rect() -> Rect2:
	return Rect2(LEFT.position.x + 34, 163, 76, 12)


## FILL, beside the till's count at the head of the right page.
func _fill_rect() -> Rect2:
	return Rect2(RIGHT.end.x - 52, 53, 52, 12)


## A row of the people on the left page.
func _crew_row(i: int) -> Rect2:
	return Rect2(LEFT.position.x - 1, TOP + i * 12.0 - 9.0, LEFT.size.x + 2, 12)


## A job on the card: two columns on the right page.
func _role_rect(i: int) -> Rect2:
	return Rect2(RIGHT.position.x + (i % 2) * 47.0, 112.0 + (i / 2) * 11.0, 45, 11)


## Let them go: under the names; back to who is asking: over the card.
func _fire_rect() -> Rect2:
	return Rect2(LEFT.position.x, 162, 60, 14)


func _asking_rect() -> Rect2:
	return Rect2(RIGHT.end.x - 46, 41, 46, 12)


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


func _clicked(id: String) -> void:
	if id.begins_with("tab:"):
		_page = id.substr(4)
		_last_page = _page
		play(SFX_PAGE, -10.0)
		say("", "")
		return
	if id == "sheet":
		_sheet = (_sheet + 1) % maxi(1, _sheets())
		play(SFX_PAGE, -10.0)
		return
	var site := _site()
	if site.is_empty():
		return
	var kind := _kind()
	if id.begins_with("menu:"):
		var item := id.substr(5)
		var on := not RULES.menu_on(kind, site, item)
		if CoreRoot != null and CoreRoot.actions != null:
			CoreRoot.actions.biz_set_menu(building_key, item, on)
		play(SFX_PAGE, -14.0)
		say("", "On the menu." if on else "Off the menu: nobody orders it.")
		return
	if id.begins_with("plus:") or id.begins_with("minus:"):
		var g := id.get_slice(":", 1)
		var n: int = int(_order.get(g, 0)) + (1 if id.begins_with("plus:") else -1)
		var room: int = maxi(0, (RULES.cap_of(kind, g, site) - int(site["stock"].get(g, 0)) - BUSINESS.on_order(building_key, g)) / maxi(1, int(RULES.goods(kind)[g]["pack"])))
		if n > room:
			say("", LANG.f("No room on the shelves for more %s.", tr(str(RULES.goods(kind)[g]["label"])).to_lower()))
			return
		_order[g] = clampi(n, 0, room)
		play(SFX_PAGE, -18.0)
		return
	if id.begins_with("crew:"):
		_picked = id.substr(5) if _picked != id.substr(5) else ""
		play(SFX_PAGE, -16.0)
		return
	if id.begins_with("role:"):
		var w0 := _crew_of(_picked)
		if not w0.is_empty():
			CoreRoot.actions.biz_set_job(building_key, _picked, id.substr(5), str(w0.get("shift", "day")))
			play(SFX_PAGE, -14.0)
		return
	if id.begins_with("gearrow:"):
		_gear_pick = id.substr(8)
		play(SFX_PAGE, -16.0)
		var gd: Dictionary = RULES.gear_list(kind)[_gear_pick]
		say("", str(gd["what"]))
		return
	if id.begins_with("row:"):
		return
	match id:
		"fill":
			var coming := {}
			for g2 in RULES.goods(kind):
				coming[g2] = BUSINESS.on_order(building_key, g2)
			_order = RULES.fill_order(kind, site, coming)
			play(SFX_PAGE, -14.0)
			say("", "The shelves are full." if _order.is_empty() else LANG.f("Written in: $%d with the van.", RULES.goods_cost(kind, _order) + int(CoreRoot.actions.van_fee(BUSINESS.van_day()))), false)
		"asking":
			_picked = ""
			play(SFX_PAGE, -16.0)
		"send", "stamp":
			var van_day: int = BUSINESS.van_day()
			if RULES.goods_cost(kind, _order) <= 0:
				say("", "Nothing written on the order.")
				return
			var cost: int = RULES.goods_cost(kind, _order) + CoreRoot.actions.van_fee(van_day)
			if not CoreRoot.actions.biz_order(building_key, _order, van_day):
				say("", LANG.f("That is $%d. The camp has not got it.", cost))
				return
			_order = {}
			_stamp("ORDERED")
			say("", "It goes on today's van." if van_day <= CoreRoot.get_day() else "The van comes tomorrow.")
		"auto":
			CoreRoot.actions.biz_set_auto(building_key, not bool(_site().get("auto_order", true)))
			play(SFX_PAGE, -14.0)
		"next":
			_candidate += 1
			play(SFX_PAGE, -12.0)
		"hire":
			var ap := _applicants()
			if ap.is_empty():
				return
			var p: Dictionary = ap[_candidate % ap.size()]
			# In the next morning (the user 4. 11.: "hired and at work at once?").
			if CoreRoot.actions.biz_hire(building_key, p, CoreRoot.get_day() + 1):
				_stamp("HIRED")
				_picked = str(p["slug"])
				var lines := ["Tomorrow at seven, then.", "I'll need the keys.", "Fine. Cash on Fridays.", "Where do I put my coat?"]
				if str(p.get("strange", "")) == "night":
					lines = ["I know where everything is."]
				elif str(p.get("strange", "")) == "unseen":
					lines = ["I will be here."]
				say(tr(str(p["name"])), str(lines[absi(hash(str(p["slug"]))) % lines.size()]))
		"shift":
			var who2 := _crew_of(_picked)
			if who2.is_empty():
				return
			var to := "late" if str(who2.get("shift", "day")) == "day" else "day"
			CoreRoot.actions.biz_set_job(building_key, _picked, str(who2.get("role", "")), to)
			if to == "late" and not bool(site.get("late", false)):
				say(tr(str(who2.get("name", ""))), "Evenings? You shut at eight.")
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
			say(tr(str(who3.get("name", ""))), line)
			_picked = ""
		"buy":
			var gd2: Dictionary = RULES.gear_list(kind).get(_gear_pick, {})
			if gd2.is_empty():
				return
			var needs := RULES.gear_needs(kind, _gear_pick)
			if needs != "" and not RULES.has_gear(site, needs):
				say("", LANG.f("Needs: %s", tr(str(RULES.gear_list(kind)[needs]["label"]))))
				return
			if CoreRoot.actions.biz_buy_gear(building_key, _gear_pick):
				_stamp("BOUGHT")
				say("", LANG.f("%s. It is in.", tr(str(gd2["label"]))))
			else:
				say("", LANG.f("That is $%d. The camp has not got it.", int(gd2["price"])))
		"late":
			CoreRoot.actions.biz_set_late(building_key, not bool(site.get("late", false)))
			_stamp("OPEN LATE" if bool(site.get("late", false)) else "SHUT AT 8")
		"zreport":
			if want_zreport.get_connections().is_empty():
				_open_zreport()
			else:
				want_zreport.emit(building_key)


## The corn stand's and the alley's books: no room behind them to open the receipt, it opens
## over them from here (the button did nothing there, "The Z report is in the books" or not).
var _zreport: Node


func _open_zreport() -> void:
	var site: Dictionary = (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).get(building_key, {})
	var z: Dictionary = site.get("zreport", {})
	if z.is_empty():
		return
	close_view()
	if _zreport == null or not is_instance_valid(_zreport):
		_zreport = load("res://scripts/business/zreport_closeup.gd").new()
		_zreport.name = "ZReport"
		get_parent().add_child(_zreport)
	_zreport.set("layer", layer)
	_zreport.call("open_report", building_key, z)


func _stamp(text: String) -> void:
	_stamp_t = 0.0
	_stamp_text = tr(text)
	play(SFX_STAMP, -4.0)


func _tick(delta: float) -> void:
	if _stamp_t >= 0.0:
		_stamp_t += delta
		if _stamp_t > 1.6:
			_stamp_t = -1.0
	var over := hovered()
	if over.begins_with("row:") or over.begins_with("minus:") or over.begins_with("plus:"):
		var g := over.get_slice(":", 1)
		if g != _row_said:
			_row_said = g
			say("", _row_line(g), false)
	elif _row_said != "":
		_row_said = ""


## What the strip says of a good under the pointer.
func _row_line(g: String) -> String:
	var site := _site()
	var kind := _kind()
	var d: Dictionary = RULES.goods(kind).get(g, {})
	if site.is_empty() or d.is_empty():
		return ""
	var use := RULES.use_per_day(site, g)
	var line := LANG.f("%s: a pack of %d for $%d. On the shelf %d of %d.", [tr(str(d["label"])), int(d["pack"]), int(d["pack_cost"]), int(site["stock"].get(g, 0)), RULES.cap_of(kind, g, site)])
	if use > 0.0:
		line += " " + LANG.f("About %d a day.", int(round(use)))
	return line


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


func _tick_mark(c: Control, box: Rect2, col: Color) -> void:
	for p in [Vector2(2, 4), Vector2(3, 5), Vector2(4, 6), Vector2(5, 5), Vector2(6, 4), Vector2(7, 3), Vector2(7, 2)]:
		c.draw_rect(Rect2(box.position + p, Vector2(1, 1)), col)


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
	_centre(c, r, tr(label), col, RETRO_UI.FONT_LABEL)


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
		_centre(c, rr, tr(str(PAGE_LABEL[PAGES[i]])), INK if on else PENCIL, RETRO_UI.FONT_LABEL)
		if hovered() == "tab:" + PAGES[i]:
			c.draw_rect(rr, Color(1, 0.9, 0.5, 0.18))
	if site.is_empty():
		return
	# The left page's head: the place and the day, always.
	var title := tr(str(info.get("name", ""))).to_upper()
	if kind == "corn" and title.length() > 12:
		title = tr("Corn").to_upper()
	_text(c, LEFT.position + Vector2(0, 8), title, INK, 10, RETRO_UI.FONT_BIG)
	_right(c, LEFT.end.x, LEFT.position.y + 8, LANG.f("Day %d", CoreRoot.get_day()), PENCIL)
	match _page:
		"menu":
			_paint_menu(c, site, kind)
		"goods":
			_paint_goods(c, site, kind)
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


## The menu: a pencilled box for each thing the place sells, ticked while it is on; the
## place's own is inked in for good.
func _paint_menu(c: Control, site: Dictionary, kind: String) -> void:
	var rows: Array = RULES.MENU.get(kind, [])
	_text(c, LEFT.position + Vector2(0, 21), tr("What we sell"), PENCIL)
	for i in rows.size():
		var r := _menu_rect(i, rows.size())
		var id := str(rows[i][0])
		var locked := bool(rows[i][2])
		var on := RULES.menu_on(kind, site, id)
		var box := Rect2(r.position + Vector2(0, 2), Vector2(9, 9))
		if hovered() == "menu:" + id:
			c.draw_rect(r, Color(1, 0.9, 0.5, 0.18))
		_pencil_box(c, box, INK if locked else PENCIL)
		if on:
			var col := INK if locked else GREEN
			for p in [Vector2(2, 4), Vector2(3, 5), Vector2(4, 6), Vector2(5, 5), Vector2(6, 4), Vector2(7, 3), Vector2(7, 2)]:
				c.draw_rect(Rect2(box.position + p, Vector2(1, 1)), col)
		_text(c, Vector2(r.position.x + 12, r.position.y + 9), tr(str(rows[i][1])), INK if on else PENCIL)
	# (Under the stamp and the pencil down by the foot of the page it could not be read: at the
	# head of the right page, or under the second column.)
	var note_y := LEFT.position.y + 21.0 if rows.size() <= 7 else TOP + (rows.size() - 7) * 13.0 + 6.0
	_wrap_at(c, Vector2(RIGHT.position.x, note_y), tr("Tick off what you have no time for: nobody will order it."), RIGHT.size.x, PENCIL)


## Goods on one page: a row each across the two pages: what it is, how many on the shelf, how
## long they last (or what is on the van), and how many packs to write in.
func _paint_goods(c: Control, site: Dictionary, kind: String) -> void:
	var gd: Dictionary = RULES.goods(kind)
	var keys: Array = _goods_keys()
	var van_fee: int = CoreRoot.actions.van_fee(BUSINESS.van_day())
	_right(c, 116, LEFT.position.y + 21, tr("Shelf"), PENCIL)
	_right(c, LEFT.end.x, LEFT.position.y + 21, tr("Days"), PENCIL)
	for i in keys.size():
		var g: String = keys[i]
		var d: Dictionary = gd[g]
		var y := _row_y(i)
		var n := int(site["stock"].get(g, 0))
		var low: bool = RULES.is_low(kind, g, n) and RULES.kept(kind, g)
		var over := hovered() in ["row:" + g, "minus:" + g, "plus:" + g]
		if over:
			c.draw_rect(Rect2(LEFT.position.x - 1, y - 8, LEFT.size.x + 2, _pitch()), Color(1, 0.9, 0.5, 0.2))
			c.draw_rect(Rect2(RIGHT.position.x - 1, y - 8, RIGHT.size.x + 2, _pitch()), Color(1, 0.9, 0.5, 0.2))
		_text(c, Vector2(LEFT.position.x, y), _fit(tr(str(d["label"])), 60.0), RED if low else INK)
		_right(c, 116, y, "%d" % n, RED if low else INK)
		var on_units: int = BUSINESS.on_order(building_key, g)
		var days := RULES.days_left(site, g)
		if on_units > 0:
			_right(c, LEFT.end.x, y, "+%d" % on_units, GREEN)
		elif days >= 0:
			_right(c, LEFT.end.x, y, str(days), RED if days <= 1 else PENCIL)
		# The right page: the packs, the price of one.
		var mr := _minus_rect(y)
		var pr := _plus_rect(y)
		for b in [["minus:", mr, "-"], ["plus:", pr, "+"]]:
			var r: Rect2 = b[1]
			if hovered() == str(b[0]) + g:
				c.draw_rect(r, Color(1, 0.9, 0.5, 0.3))
			_centre(c, r, str(b[2]), INK, RETRO_UI.FONT_BIG)
		var packs := int(_order.get(g, 0))
		_centre(c, Rect2(mr.end.x, mr.position.y, pr.position.x - mr.end.x, mr.size.y), "%d" % packs, INK if packs > 0 else PENCIL)
		_right(c, 230, y, _cash(int(d["pack_cost"]) * maxi(1, packs)), INK if packs > 0 else PENCIL)
	var goods_cost: int = RULES.goods_cost(kind, _order)
	var cost: int = goods_cost + (van_fee if goods_cost > 0 else 0)
	_text(c, RIGHT.position + Vector2(0, 10), LANG.f("Total $%d", cost), INK, 10, RETRO_UI.FONT_BIG)
	_text(c, RIGHT.position + Vector2(0, 22), _cash(CoreRoot.get_money()), RED if cost > CoreRoot.get_money() else PENCIL)
	_pencil_button(c, _fill_rect(), "FILL", INK, "fill")
	var auto := _auto_rect()
	if hovered() == "auto":
		c.draw_rect(auto, Color(1, 0.9, 0.5, 0.18))
	var tick := Rect2(auto.position + Vector2(0, 2), Vector2(9, 9))
	_pencil_box(c, tick, PENCIL)
	var hands_order := bool(site.get("auto_order", true))
	if hands_order:
		_tick_mark(c, tick, Color(0.1, 0.42, 0.1))
	_text(c, Vector2(auto.position.x + 12, auto.position.y + 9), _fit(tr("Hands order"), auto.size.x - 12.0), INK if hands_order else PENCIL)
	_pencil_button(c, _rbutton(0), "SEND ORDER", RED, "send")
	if goods_cost > 0:
		_text(c, Vector2(RIGHT.position.x, 183), LANG.f("van $%d", van_fee), PENCIL)
	if hovered() == "stamp":
		c.draw_rect(STAMP, Color(1, 0.9, 0.5, 0.12))
	_paint_sheet(c)


## A sum in the ledger's columns: the number alone in Czech (the crowns' word took the room).
func _cash(v: int) -> String:
	return LANG.money("$%d" % absi(v)).replace(" Kč", "")


## Which sheet of the goods, at the foot of the left page; a click turns it.
func _paint_sheet(c: Control) -> void:
	if _sheets() > 1:
		_pencil_button(c, _lbutton(0), "%d/%d" % [mini(_sheet, _sheets() - 1) + 1, _sheets()], INK, "sheet")


func _width(s: String) -> float:
	return _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x


## `s` cut to `room` (a long Czech name ran into its price).
func _fit(s: String, room: float) -> String:
	if _width(s) <= room:
		return s
	var out := s
	while out.length() > 3 and _width(out + ".") > room:
		out = out.left(-1)
	return out.strip_edges() + "."


## Who is here on the left; on the right the one picked (their card) or who is asking.
func _paint_staff(c: Control, site: Dictionary, kind: String) -> void:
	var crew: Array = site.get("crew", [])
	_text(c, LEFT.position + Vector2(0, 21), tr("Working here"), PENCIL)
	var day := CoreRoot.get_day()
	var wages := 0
	if crew.is_empty():
		_text(c, Vector2(LEFT.position.x, TOP + 4), tr("Nobody."), RED, 10, RETRO_UI.FONT_BIG)
		_text(c, Vector2(LEFT.position.x, TOP + 14), tr("You serve."), RED)
	for i in crew.size():
		var p: Dictionary = crew[i]
		var row := _crew_row(i)
		var y := row.position.y + 9.0
		var slug := str(p.get("slug", ""))
		wages += RULES.shift_pay(p)
		if slug == _picked:
			c.draw_rect(row, Color(1, 0.9, 0.5, 0.35))
		elif hovered() == "crew:" + slug:
			c.draw_rect(row, Color(1, 0.9, 0.5, 0.15))
		var away := int(p.get("absent", -1)) == day
		_text(c, Vector2(LEFT.position.x, y), _fit(hand_name(str(p.get("name", ""))), 52.0), RED if away else INK)
		var tag := _fit(tr(RULES.role_label(kind, str(p.get("role", "")))), 34.0)
		tag += " L" if str(p.get("shift", "day")) == "late" else ""
		if away:
			tag = tr("AWAY")
		elif int(p.get("owed", 0)) > 0:
			tag = tr("OWED")
		elif int(p.get("since", 0)) > day:
			tag = tr("TOMORROW")
		_right(c, LEFT.end.x, y, tag, RED if away or int(p.get("owed", 0)) > 0 else PENCIL)
	if wages > 0:
		_text(c, Vector2(LEFT.position.x, 154), LANG.f("Wages a day $%d", wages), INK)
	var who := _crew_of(_picked)
	if not who.is_empty():
		_paint_card(c, who, kind, day)
		return
	# The right page: who is asking today.
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
	_text(c, Vector2(pr.end.x + 4, 58), hand_name(str(p2["name"])), INK)
	_text(c, Vector2(pr.end.x + 4, 68), LANG.f("$%d a day", int(p2["wage"])), INK)
	_text(c, Vector2(pr.end.x + 4, 78), LANG.f("%d of %d", [_candidate % ap.size() + 1, ap.size()]), PENCIL)
	var y2 := 102.0
	for line in p2.get("refs", []):
		y2 = _wrap_at(c, Vector2(RIGHT.position.x, y2), tr(str(line)), RIGHT.size.x, INK, 8.0)
	_pencil_button(c, _rbutton(1), "NEXT", PENCIL, "next")
	_pencil_button(c, _rbutton(0), "TAKE ON", GREEN, "hire")


## The one picked: their photo and pay, how they are, the jobs of this place to put them
## on, their shift, and letting them go.
func _paint_card(c: Control, who: Dictionary, kind: String, day: int) -> void:
	var slug := str(who.get("slug", ""))
	var ph := _photo(slug)
	var pr := Rect2(RIGHT.position.x, 56, 32, 42)
	if ph != null:
		c.draw_texture_rect(ph, pr, false)
	c.draw_rect(pr.grow(1.0), PENCIL, false, 1.0)
	_pencil_button(c, _asking_rect(), "ASKING", PENCIL, "asking")
	var tx := pr.end.x + 4
	_text(c, Vector2(tx, 64), _fit(hand_name(str(who.get("name", ""))), RIGHT.end.x - tx), INK)
	_text(c, Vector2(tx, 74), LANG.f("$%d a late shift" if str(who.get("shift", "day")) == "late" else "$%d a day", RULES.shift_pay(who)), INK)
	var status := "At work today"
	if int(who.get("absent", -1)) == day:
		status = "Away today"
	elif int(who.get("since", 0)) > day:
		status = "From tomorrow"
	elif int(who.get("owed", 0)) > 0:
		status = "Owed"
	_text(c, Vector2(tx, 84), _fit(tr(status), RIGHT.end.x - tx), RED if status in ["Away today", "Owed"] else PENCIL)
	_text(c, Vector2(RIGHT.position.x, 107), _fit(tr(str(RULES.SPEED_WORD[clampi(int(who.get("speed", 1)), 0, 2)])), RIGHT.size.x - 10.0), PENCIL)
	var roles: Array = RULES.ROLES.get(kind, [])
	var mine := str(who.get("role", ""))
	for i in roles.size():
		var r := _role_rect(i)
		var on := str(roles[i][0]) == mine
		if hovered() == "role:" + str(roles[i][0]):
			c.draw_rect(r, Color(1, 0.9, 0.5, 0.25))
		var box := Rect2(r.position + Vector2(0, 1), Vector2(9, 9))
		_pencil_box(c, box, INK if on else PENCIL)
		if on:
			_tick_mark(c, box, GREEN)
		_text(c, Vector2(r.position.x + 11, r.position.y + 9), _fit(tr(str(roles[i][1])), r.size.x - 11.0), INK if on else PENCIL)
	var late := str(who.get("shift", "day")) == "late"
	_pencil_button(c, _rbutton(0), "LATE SHIFT" if late else "DAY SHIFT", INK, "shift")
	_pencil_button(c, _fire_rect(), "LET GO", RED, "fire")


func _paint_gear(c: Control, site: Dictionary, kind: String) -> void:
	var gear: Dictionary = RULES.gear_list(kind)
	_text(c, LEFT.position + Vector2(0, 21), tr("For the place"), PENCIL)
	var i := 0
	for id in gear:
		var y := TOP + i * 15.0
		var g: Dictionary = gear[id]
		var owned := RULES.has_gear(site, str(id))
		if str(id) == _gear_pick:
			c.draw_rect(Rect2(LEFT.position.x - 1, y - 9, LEFT.size.x + 2, 14), Color(1, 0.9, 0.5, 0.35))
		elif hovered() == "gearrow:" + str(id):
			c.draw_rect(Rect2(LEFT.position.x - 1, y - 9, LEFT.size.x + 2, 14), Color(1, 0.9, 0.5, 0.15))
		_text(c, Vector2(LEFT.position.x, y), tr(str(g["label"])), PENCIL if owned else INK)
		_right(c, LEFT.end.x, y, tr("IN") if owned else LANG.money("$%d" % int(g["price"])), GREEN if owned else PENCIL)
		i += 1
	if _gear_pick == "" or not gear.has(_gear_pick):
		_text(c, RIGHT.position + Vector2(0, 21), tr("Pick one."), PENCIL)
		return
	var gd: Dictionary = gear[_gear_pick]
	_text(c, RIGHT.position + Vector2(0, 21), tr(str(gd["label"])), INK)
	_wrap_at(c, RIGHT.position + Vector2(0, 34), tr(str(gd["what"])), RIGHT.size.x, PENCIL)
	var needs := RULES.gear_needs(kind, _gear_pick)
	if RULES.has_gear(site, _gear_pick):
		_text(c, RIGHT.position + Vector2(0, 100), tr("In the place."), GREEN)
	elif needs != "" and not RULES.has_gear(site, needs):
		_text(c, RIGHT.position + Vector2(0, 100), LANG.money("$%d" % int(gd["price"])), PENCIL, 10, RETRO_UI.FONT_BIG)
		_wrap_at(c, RIGHT.position + Vector2(0, 116), LANG.f("Needs: %s", tr(str(gear[needs]["label"]))), RIGHT.size.x, RED)
	else:
		_text(c, RIGHT.position + Vector2(0, 100), LANG.money("$%d" % int(gd["price"])), INK, 10, RETRO_UI.FONT_BIG)
		_pencil_button(c, _rbutton(0), "BUY", GREEN, "buy")


## The money (Richard 8. 11.: "some stats of profit and costs"): today against yesterday on
## the left, the last week's profit as a pencil chart on the right, the whole run under it.
func _paint_books(c: Control, site: Dictionary, _kind_of: String) -> void:
	var today_n: int = CoreRoot.get_day()
	var t: Dictionary = RULES.today_money(site, today_n)
	var yd: Dictionary = RULES.day_money(site["yesterday"])
	_right(c, 108, LEFT.position.y + 21, tr("Today"), PENCIL)
	_right(c, LEFT.end.x, LEFT.position.y + 21, tr("Yesterday"), PENCIL)
	var rows := [["Takings", "takings"], ["Goods", "goods"], ["Wages", "wages"], ["Van", "van"], ["Short", "short"]]
	for i in rows.size():
		var y := TOP + i * 10.0
		var key: String = rows[i][1]
		_text(c, Vector2(LEFT.position.x, y), tr(str(rows[i][0])), PENCIL)
		_right(c, 108, y, _cash(int(t[key])), INK if key == "takings" else PENCIL)
		_right(c, LEFT.end.x, y, _cash(int(yd[key])), INK if key == "takings" else PENCIL)
	var py := TOP + rows.size() * 10.0 + 2.0
	c.draw_rect(Rect2(LEFT.position.x, py - 9.0, LEFT.size.x, 1), INK)
	_text(c, Vector2(LEFT.position.x, py), tr("PROFIT"), INK, 8, RETRO_UI.FONT_LABEL)
	_right(c, 108, py, _signed(int(t["profit"])), RED if int(t["profit"]) < 0 else GREEN)
	_right(c, LEFT.end.x, py, _signed(int(yd["profit"])), RED if int(yd["profit"]) < 0 else GREEN)
	var cy := py + 12.0
	for row in [["Sold", "sold"], ["Went away", "lost"]]:
		var key2: String = row[1]
		var a := int((site["today"] as Dictionary).get(key2, 0))
		var b := int((site["yesterday"] as Dictionary).get(key2, 0))
		_text(c, Vector2(LEFT.position.x, cy), tr(str(row[0])), PENCIL)
		_right(c, 108, cy, str(a), RED if key2 == "lost" and a > 0 else PENCIL)
		_right(c, LEFT.end.x, cy, str(b), RED if key2 == "lost" and b > 0 else PENCIL)
		cy += 10.0
	var n := int(site.get("all_orders", 0))
	if n > 0:
		_text(c, Vector2(LEFT.position.x, cy + 2.0), LANG.f("Average %d%%", int(round(float(site.get("all_score", 0)) / float(n)))), INK)
	# The week.
	_text(c, RIGHT.position + Vector2(0, 8), tr("Profit, 7 days"), PENCIL)
	var shown: Array = []
	for d0 in (site.get("history", []) as Array).slice(-6):
		shown.append(int(RULES.day_money(d0)["profit"]))
	shown.append(int(t["profit"]))
	_week_chart(c, Rect2(RIGHT.position.x, 52, RIGHT.size.x - 10.0, 34), shown)
	var week: Dictionary = RULES.week_money(site, today_n)
	_text(c, Vector2(RIGHT.position.x, 98), tr("7 days"), PENCIL)
	_right(c, RIGHT.end.x - 10.0, 98, _signed(int(week["profit"])), RED if int(week["profit"]) < 0 else GREEN)
	var total: Dictionary = site.get("total", {}) if site.get("total", {}) is Dictionary else {}
	var run := int(total.get("profit", 0)) + int(t["profit"])
	_text(c, Vector2(RIGHT.position.x, 108), tr("All told"), PENCIL)
	_right(c, RIGHT.end.x - 10.0, 108, _signed(run), RED if run < 0 else GREEN)
	# The last shift's mark, in big pencil; and the evening.
	var z: Dictionary = site.get("zreport", {}) if site.get("zreport", {}) is Dictionary else {}
	if z.has("grade"):
		var g := str(z["grade"])
		_text(c, Vector2(RIGHT.position.x, 122), tr("Last shift"), PENCIL)
		_right(c, RIGHT.end.x - 10.0, 123, g, Color(0.16, 0.42, 0.14) if g in ["A", "B"] else (RED if g in ["D", "E"] else INK))
	var late := bool(site.get("late", false))
	_text(c, Vector2(RIGHT.position.x, 134), tr("Open till 23:00") if late else tr("Open till 20:00"), INK)
	_pencil_button(c, _rbutton(1), "SHUT AT 8" if late else "OPEN LATE", RED if late else INK, "late")
	if not z.is_empty():
		_pencil_button(c, _rbutton(0), "Z REPORT", INK, "zreport")


func _signed(v: int) -> String:
	return ("+" if v > 0 else ("-" if v < 0 else "")) + _cash(v)


## The last days' profit: hatched bars up from a line, red ones down, today's left open.
func _week_chart(c: Control, r: Rect2, values: Array) -> void:
	var hi := 1
	var lo := 0
	for v in values:
		hi = maxi(hi, int(v))
		lo = mini(lo, int(v))
	var zero := r.position.y + r.size.y * float(hi) / float(hi - lo)
	c.draw_rect(Rect2(r.position.x, zero, r.size.x, 1), PENCIL)
	var w := r.size.x / 7.0
	var hatch := _part("pencil_hatch")
	for i in values.size():
		var v2: int = values[i]
		var x := r.position.x + (7 - values.size() + i) * w + 1.0
		var h := r.size.y * float(absi(v2)) / float(hi - lo)
		if h < 1.0:
			continue
		var bar := Rect2(x, zero - h if v2 >= 0 else zero + 1.0, w - 2.0, h)
		var today := i == values.size() - 1
		if hatch != null:
			var tint := Color(1.6, 0.5, 0.45) if v2 < 0 else Color(0.7, 1.15, 0.7)
			if today:
				tint.a = 0.55
			c.draw_texture_rect_region(hatch, bar, Rect2(0, 0, bar.size.x * 2.0, bar.size.y * 2.0), tint)
		else:
			c.draw_rect(bar, Color(0.4, 0.38, 0.36, 0.5))
		if today:
			c.draw_rect(bar, PENCIL, false, 1.0)
