extends "res://scripts/closeup/closeup_view.gd"

## The business's books on the desk, close up (playtest 18. 10.: "wherever you click in
## an interior there are management desks: on paper you see how much stock is left, you
## order the van, and you serve by hand until you take somebody on"): an accounts book
## open on the counter, four pages with tabs in pencil:
##   STOCK   what is on the shelves, a bar each, red when it is running low
##   ORDER   packs to order (- / +), what is already on order, the cost; the stamp sends it,
##           the van brings it in the morning
##   STAFF   take a hand on (a wage a day: they serve everybody, a bit slower, no tips) or
##           let them go
##   BOOKS   today and yesterday: sold, takings, served by you, went away unserved
## Picture: assets/textury/closeup/ledger.png (Grok). On it, renders too (closeup/parts/):
## the paper tabs, the pencilled boxes (nine-sliced), the pencil hatching of the bars, the
## rubber stamp's frame; only the writing is set here.

const RULES := preload("res://core/systems/business_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PIC := "res://assets/textury/closeup/ledger.png"
const SFX_STAMP := "res://assets/sfx/desk/stamp.mp3"
const SFX_PAGE := "res://assets/sfx/desk/paper_slide.mp3"
const PAGES := ["stock", "order", "staff", "books"]
const PAGE_LABEL := {"stock": "STOCK", "order": "ORDER", "staff": "STAFF", "books": "BOOKS"}
## The two pages of the open book (picture px, measured on the painting): the pencil lies
## in the gutter between them, the rubber stamp on the right page's bottom corner (it
## sends the order too).
const LEFT := Rect2(42, 40, 94, 138)
const RIGHT := Rect2(160, 40, 70, 138)
const STAMP := Rect2(232, 138, 58, 62)
const SEND := Rect2(160, 64, 70, 14)
const INK := Color(0.16, 0.18, 0.34)
const PENCIL := Color(0.3, 0.29, 0.28)
const RED := Color(0.66, 0.12, 0.1)
const GREEN := Color(0.1, 0.4, 0.14)
const PAPER := Color(0.93, 0.89, 0.78)
const PARTS := "res://assets/textury/closeup/parts/"

var building_key := ""
var building_type := ""
var _page := "stock"
var _order: Dictionary = {}
var _candidate := 0
var _stamp_t := -1.0
var _stamp_text := ""
var _tex: Dictionary = {}
var _boxes: Dictionary = {}           # colour -> the pencil box's nine-slice


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


func open_for(key: String, btype: String) -> void:
	building_key = key
	building_type = btype
	_order = {}
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_site(key, btype)
	open_view()


func _kind() -> String:
	return RULES.kind_of(building_type)


func _opened() -> void:
	play(SFX_PAGE, -8.0)
	var site: Dictionary = BUSINESS.site(building_key)
	if site.is_empty():
		say("", "No books for this place.")
		return
	_page = "stock"
	var lows: Array = []
	for g in site["stock"]:
		if RULES.is_low(_kind(), g, int(site["stock"][g])):
			lows.append(str(RULES.goods(_kind())[g]["label"]).to_lower())
	if not lows.is_empty():
		say("", "Running low: %s." % ", ".join(lows))
	elif not bool(site["staff"]):
		say("", "Nobody behind the counter.")
	else:
		say("", "%s is behind the counter." % str(site["staff_name"]))


# ── hotspots ─────────────────────────────────────────────────────────────────

func _tab_rect(i: int) -> Rect2:
	return Rect2(46 + i * 50, 24, 46, 13)


func _goods_keys() -> Array:
	return RULES.goods(_kind()).keys()


func _row_y(i: int) -> float:
	return 92.0 + i * 15.0


func _hotspots() -> Array:
	var out: Array = []
	for i in PAGES.size():
		out.append({"id": "tab:" + PAGES[i], "rect": _tab_rect(i)})
	match _page:
		"order":
			var keys: Array = _goods_keys()
			for i in keys.size():
				var y := _row_y(i)
				out.append({"id": "minus:" + str(keys[i]), "rect": _minus_rect(y)})
				out.append({"id": "plus:" + str(keys[i]), "rect": _plus_rect(y)})
			out.append({"id": "send", "rect": SEND})
			out.append({"id": "stamp", "rect": STAMP})
		"staff":
			var site: Dictionary = BUSINESS.site(building_key)
			if not site.is_empty() and bool(site["staff"]):
				out.append({"id": "fire", "rect": _button(1)})
			else:
				out.append({"id": "next", "rect": _button(0)})
				out.append({"id": "hire", "rect": _button(1)})
	return out


func _minus_rect(y: float) -> Rect2:
	return Rect2(RIGHT.position.x + 1, y - 9, 11, 11)


func _plus_rect(y: float) -> Rect2:
	return Rect2(RIGHT.position.x + 33, y - 9, 11, 11)


## The pencilled buttons on the right page, under the candidate.
func _button(i: int) -> Rect2:
	return Rect2(RIGHT.position.x, 92 + i * 20, RIGHT.size.x, 15)


func _clicked(id: String) -> void:
	if id.begins_with("tab:"):
		_page = id.substr(4)
		play(SFX_PAGE, -10.0)
		say("", "")
		return
	var site: Dictionary = BUSINESS.site(building_key)
	if site.is_empty():
		return
	var kind := _kind()
	if id.begins_with("plus:") or id.begins_with("minus:"):
		var g := id.get_slice(":", 1)
		var n: int = int(_order.get(g, 0)) + (1 if id.begins_with("plus:") else -1)
		var room: int = RULES.room_for(kind, g, int(site["stock"].get(g, 0)), BUSINESS.on_order(building_key, g))
		if n > room:
			say("", "No room on the shelves for more %s." % str(RULES.goods(kind)[g]["label"]).to_lower())
			return
		_order[g] = clampi(n, 0, room)
		play(SFX_PAGE, -18.0)
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
		"next":
			_candidate += 1
			play(SFX_PAGE, -12.0)
		"hire":
			var name := _candidate_name()
			if CoreRoot.actions.biz_hire(building_key, name, CoreRoot.get_day()):
				_stamp("HIRED")
				say(name, ["I start now? Right.", "I'll need the keys.", "Fine. Cash on Fridays."][_candidate % 3])
		"fire":
			var who := str(site["staff_name"])
			CoreRoot.actions.biz_fire(building_key)
			_stamp("PAID OFF")
			say(who, "Suit yourself. You will be back behind that counter by tonight.")


func _candidate_name() -> String:
	var names: Array = RULES.info(_kind()).get("hand", ["A hand"])
	return str(names[_candidate % names.size()])


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


func _part(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(PARTS + key + ".png") if ResourceLoader.exists(PARTS + key + ".png") else null
	return _tex[key]


## A box pencilled round `r`: the render of a pencilled box, nine-sliced, in `col`.
func _pencil_box(c: Control, r: Rect2, col := PENCIL) -> void:
	var t := _part("pencil_box")
	if t == null:
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
	var site: Dictionary = BUSINESS.site(building_key)
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
	# The left page: the place and the day, always.
	_text(c, LEFT.position + Vector2(2, 12), str(info.get("name", "")).to_upper(), INK, 10, RETRO_UI.FONT_BIG)
	_text(c, LEFT.position + Vector2(2, 23), "Day %d" % CoreRoot.get_day(), PENCIL)
	match _page:
		"stock":
			_paint_stock(c, site, kind)
		"order":
			_paint_order(c, site, kind)
		"staff":
			_paint_staff(c, site, kind)
		"books":
			_paint_books(c, site, kind)
	if _stamp_t >= 0.0:
		var k := clampf(_stamp_t * 6.0, 0.0, 1.0)
		var sz := lerpf(2.0, 1.0, k)
		var col := Color(0.72, 0.1, 0.12, 0.85 * clampf(2.0 - _stamp_t, 0.0, 1.0))
		var font: Font = RETRO_UI.FONT_BIG
		var w := font.get_string_size(_stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * sz)).x
		var at := Vector2(RIGHT.get_center().x - w * 0.5, 132)
		var frame := _part("stamp_frame")
		if frame != null:
			c.draw_texture_rect(frame, Rect2(at - Vector2(8, 15 * sz), Vector2(w + 16, 20 * sz)), false, Color(1, 1, 1, col.a))
		c.draw_string(font, at, _stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * sz), col)


func _paint_stock(c: Control, site: Dictionary, kind: String) -> void:
	var gd: Dictionary = RULES.goods(kind)
	var keys: Array = _goods_keys()
	_text(c, LEFT.position + Vector2(2, 38), "On the shelves", PENCIL)
	for i in keys.size():
		var g: String = keys[i]
		var d: Dictionary = gd[g]
		var n := int(site["stock"].get(g, 0))
		var y := _row_y(i)
		var low: bool = RULES.is_low(kind, g, n)
		_text(c, Vector2(LEFT.position.x + 2, y), str(d["label"]), RED if low else INK)
		_right(c, LEFT.end.x - 2, y, "%d" % n, RED if low else INK)
		_text(c, Vector2(LEFT.position.x + 4, y + 7), str(d["unit"]), PENCIL, 6)
		# The bar, hatched in pencil.
		var bar := Rect2(RIGHT.position.x + 2, y - 8, RIGHT.size.x - 4, 9)
		_pencil_box(c, bar)
		var fill := bar.size.x * clampf(float(n) / float(maxi(1, int(d["cap"]))), 0.0, 1.0)
		var hatch := _part("pencil_hatch")
		if hatch != null and fill >= 1.0:
			var tint := Color(1.6, 0.5, 0.45) if low else Color(1, 1, 1)
			c.draw_texture_rect_region(hatch, Rect2(bar.position + Vector2(1, 1), Vector2(fill - 2, bar.size.y - 2)), Rect2(0, 0, hatch.get_width() * fill / bar.size.x, hatch.get_height()), tint)
	var due := 0
	for o in CoreRoot.get_state().biz.get("orders", []):
		if str(o.get("key", "")) == building_key:
			due += 1
	_text(c, RIGHT.position + Vector2(2, 12), "Shelf", PENCIL)
	if due > 0:
		_text(c, RIGHT.position + Vector2(2, 23), "Van due: %d" % due, INK)


func _paint_order(c: Control, site: Dictionary, kind: String) -> void:
	var gd: Dictionary = RULES.goods(kind)
	var keys: Array = _goods_keys()
	_text(c, LEFT.position + Vector2(2, 38), "Wholesaler", PENCIL)
	_right(c, LEFT.end.x - 2, LEFT.position.y + 38, "van $%d" % RULES.DELIVERY_FEE, PENCIL)
	for i in keys.size():
		var g: String = keys[i]
		var d: Dictionary = gd[g]
		var y := _row_y(i)
		_text(c, Vector2(LEFT.position.x + 2, y), str(d["label"]), INK)
		_right(c, LEFT.end.x - 2, y, "$%d" % int(d["pack_cost"]), PENCIL)
		_text(c, Vector2(LEFT.position.x + 4, y + 7), "%d %s" % [int(d["pack"]), str(d["unit"])], PENCIL, 6)
		var mr := _minus_rect(y)
		var pr := _plus_rect(y)
		for b in [["minus:", mr, "-"], ["plus:", pr, "+"]]:
			var r: Rect2 = b[1]
			_pencil_box(c, r, INK)
			if hovered() == str(b[0]) + g:
				c.draw_rect(r, Color(1, 0.9, 0.5, 0.25))
			_centre(c, r, str(b[2]), INK)
		_centre(c, Rect2(mr.end.x, mr.position.y, pr.position.x - mr.end.x, mr.size.y), "%d" % int(_order.get(g, 0)), INK)
		var on_units: int = BUSINESS.on_order(building_key, g)
		if on_units > 0:
			_text(c, Vector2(pr.end.x + 3, y), "+%d" % on_units, PENCIL)
	var cost: int = RULES.order_cost(kind, _order)
	_text(c, RIGHT.position + Vector2(2, 12), "Total $%d" % cost, INK, 10, RETRO_UI.FONT_BIG)
	_text(c, RIGHT.position + Vector2(2, 22), "Cash $%d" % CoreRoot.get_money(), PENCIL)
	_pencil_button(c, SEND, "SEND ORDER", RED, "send")
	if hovered() == "stamp":
		c.draw_rect(STAMP, Color(1, 0.9, 0.5, 0.12))


func _paint_staff(c: Control, site: Dictionary, kind: String) -> void:
	var info: Dictionary = RULES.info(kind)
	_text(c, LEFT.position + Vector2(2, 38), "At the counter", PENCIL)
	if bool(site["staff"]):
		_text(c, Vector2(LEFT.position.x + 2, 96), str(site["staff_name"]), INK, 10, RETRO_UI.FONT_BIG)
		_text(c, Vector2(LEFT.position.x + 2, 108), "since day %d" % int(site["since_day"]), PENCIL)
		_text(c, Vector2(LEFT.position.x + 2, 124), "$%d a day," % int(info["wage"]), INK)
		_text(c, Vector2(LEFT.position.x + 2, 134), "paid at night", INK)
		_text(c, RIGHT.position + Vector2(2, 12), "Serves alone", PENCIL)
		_pencil_button(c, _button(1), "LET GO", RED, "fire")
		return
	_text(c, Vector2(LEFT.position.x + 2, 96), "Nobody.", RED, 10, RETRO_UI.FONT_BIG)
	_text(c, Vector2(LEFT.position.x + 2, 108), "You serve.", RED)
	_text(c, RIGHT.position + Vector2(2, 12), "Asking:", PENCIL)
	_text(c, RIGHT.position + Vector2(2, 24), _candidate_name(), INK, 10, RETRO_UI.FONT_BIG)
	_text(c, RIGHT.position + Vector2(2, 36), "$%d a day" % int(info["wage"]), INK)
	_pencil_button(c, _button(0), "NEXT", PENCIL, "next")
	_pencil_button(c, _button(1), "TAKE ON", GREEN, "hire")


func _paint_books(c: Control, site: Dictionary, kind: String) -> void:
	var rows := [["Sold", "sold"], ["Takings $", "takings"], ["By you", "by_hand"], ["Went away", "lost"]]
	_text(c, LEFT.position + Vector2(2, 38), "Today", PENCIL)
	_text(c, RIGHT.position + Vector2(2, 12), "Yesterday", PENCIL)
	for i in rows.size():
		var y := _row_y(i) + i * 3.0
		var key: String = rows[i][1]
		var col: Color = RED if key == "lost" and int(site["today"][key]) > 0 else INK
		_text(c, Vector2(LEFT.position.x + 2, y), str(rows[i][0]), PENCIL)
		_right(c, LEFT.end.x - 2, y, str(int(site["today"][key])), col)
		_text(c, Vector2(RIGHT.position.x + 2, y), str(rows[i][0]), PENCIL)
		_right(c, RIGHT.end.x - 2, y, str(int(site["yesterday"][key])), INK)
	if bool(site["staff"]):
		_text(c, Vector2(LEFT.position.x + 2, 168), "Wage tonight $%d" % int(RULES.info(kind)["wage"]), INK)
