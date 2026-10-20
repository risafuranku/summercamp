extends Control

## Goggle Reviews (the PC's Reviews tab; the logic is scripts/reviews/goggle.gd): the
## camp's listing on the search engine everybody uses, in its 1998 dress. On the left the
## place: its name, the big average and the stars, how many reviews, the bars of five to
## one; SpotlessName Ltd's banner (a bad review gone by morning, for a price); Stavitel
## software's partner box (which blueprints the next rating opens in Builder 98). On the
## right the reviews three to a page, newest, lowest or highest first, each with the
## guest's face, the stars, when, what they wrote and the owner's answer; Reply (two
## answers) and Remove on each. The pages run on along the bottom: G o o o g l e.
## Photos: last summer's guests' snaps of the camp (one has somebody in it who should not
## be there), big on a click, and what people also searched for (Agrostroj's site).

const T = preload("res://scripts/os98/os_theme.gd")
const GOGGLE = preload("res://scripts/reviews/goggle.gd")
const STAR_DIR := "res://assets/textury/os98/web/"
const BANNER := "res://assets/textury/os98/web/spotless_banner.png"
const PADLOCK := "res://assets/textury/os98/icons/padlock_16.png"
const LOGO_ICON := "res://assets/textury/os98/icons/goggle.png"
const FACES := {
	"quiet_guy": "res://assets/textury/npc/host1.png", "drunk": "res://assets/textury/npc/host2.png",
	"cheap_chick": "res://assets/textury/npc/host3.png", "tramp": "res://assets/textury/npc/host_tramp.png",
	"family": "res://assets/textury/npc/host_family.png", "picker": "res://assets/textury/npc/host_pensioner.png",
}
const LOGO_COLS := [Color8(36, 80, 220), Color8(210, 32, 30), Color8(230, 170, 0), Color8(36, 80, 220), Color8(20, 150, 50), Color8(210, 32, 30)]
const NAMES := {
	"tent_1": "Tent", "cabin_1": "Cabin", "caravan_1": "Caravan", "toilet_block": "Toilets", "shower_block": "Showers",
	"restaurant": "Bistro", "pub": "Pub", "corn_stand": "Corn stand", "bonfire": "Campfire", "sports_field": "Pitch",
	"lake_slide": "Lake slide", "playground": "Playground", "ping_pong": "Ping-pong", "hammock": "Hammock",
	"bench": "Bench", "picnic_table": "Picnic table", "flower_bed": "Flower bed", "gnome": "Gnome", "flagpole": "Flagpole",
	"vecerka": "Jednota",
	"upgrade:2": "room upgrades", "upgrade:3": "the best rooms",
}
const PER_PAGE := 3
const LEFT_W := 214.0
const BANNER_H := 98.0
## The guests' photos (tools/artgen/goggle_photos.py): [file number, who took it].
const PHOTOS := [[1, "Fam. Dvorakovi"], [2, "Pavel K."], [3, "Lenka"], [4, "Marketa S."], [5, "Houbari z Jihlavy"], [6, "Jirka Holub"]]
const PHOTO_DIR := "res://assets/textury/os98/web/photo_"
## People also searched for: [name, what, stars, reviews, url or ""].
const ALSO := [
	["Agrostroj Hlubocany", "Feed mill (planned)", 1.9, 7, "agrostroj-hlubocany.cz"],
	["U Jezera", "Pub, Lesna", 4.1, 23, ""],
	["Jednota Lesna", "Grocery", 3.6, 15, ""],
]
const BAR_H := 22.0
const HEAD_H := 46.0
const GREY := Color8(112, 112, 112)
const GREEN := Color8(0, 120, 40)
const RED := Color8(176, 0, 0)

var _shell
var _win
var _canvas: Control
var _sort := "newest"
## "reviews" or "photos" (the tab after the sorts).
var _view := "reviews"
## The photo open big (its index in PHOTOS), or -1.
var _photo := -1
var _photos: Dictionary = {}
var _page := 0
## The review whose Reply is open (its two answers showing), or -1.
var _replying := -1
var _hits: Array = []        # [Rect2, action]
var _hover := ""
var _faces: Dictionary = {}
var _stars: Dictionary = {}
var _art: Dictionary = {}
var _tick := 0.0
var _notice := ""
var _notice_until := 0.0
## How many characters the page drew (os98_check: a page is not empty).
var drawn_chars := 0


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_page)
	_canvas.gui_input.connect(_input_canvas)
	_canvas.mouse_exited.connect(func():
		_hover = ""
		_canvas.queue_redraw())
	add_child(_canvas)
	resized.connect(_layout)
	for k in ["full", "half", "empty"]:
		var p := STAR_DIR + "star_%s.png" % k
		_stars[k] = load(p) if ResourceLoader.exists(p) else null
	# Loaded here, not in _draw (a texture first loaded inside _draw draws white).
	for p in [LOGO_ICON, BANNER, PADLOCK]:
		_art[p] = load(p) if ResourceLoader.exists(p) else null
	for ph in PHOTOS:
		for suffix in ["_t", ""]:
			var pp := PHOTO_DIR + "%d%s.png" % [int(ph[0]), suffix]
			_photos[pp] = load(pp) if ResourceLoader.exists(pp) else null
	_layout()


func reopen(_args: Dictionary) -> void:
	refresh()


func _layout() -> void:
	if _canvas != null:
		_canvas.position = Vector2.ZERO
		_canvas.size = size
		_canvas.queue_redraw()


func refresh() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0 and is_visible_in_tree():
		_tick = 1.0
		refresh()


func _g():
	var m: Node = _shell.main_node() if _shell != null else null
	return m.get("_goggle") if m != null else null


func _day() -> int:
	return CoreRoot.get_day() if CoreRoot != null else 1


# ── input ────────────────────────────────────────────────────────────────────

func _input_canvas(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := _hit_at(e.position)
		if h != _hover:
			_hover = h
			_canvas.queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var a := _hit_at(e.position)
		if a != "":
			_act(a)
			_canvas.accept_event()


func _hit_at(p: Vector2) -> String:
	for h in _hits:
		if (h[0] as Rect2).has_point(p):
			return str(h[1])
	return ""


func _act(a: String) -> void:
	var parts := a.split(":")
	match parts[0]:
		"sort":
			_sort = parts[1]
			_view = "reviews"
			_page = 0
			_replying = -1
		"view":
			_view = parts[1]
			_photo = -1
			_replying = -1
		"photo":
			_photo = int(parts[1])
		"also":
			var url: String = str(ALSO[int(parts[1])][4])
			if url != "":
				_shell.open_app("browser", {"url": url})
		"page":
			_page = int(parts[1])
			_replying = -1
		"reply":
			_replying = int(parts[1]) if _replying != int(parts[1]) else -1
		"answer":
			var m: Node = _shell.main_node()
			if m != null and m.has_method("goggle_reply"):
				m.goggle_reply(int(parts[1]), parts[2])
			_replying = -1
			_shell.play("click", -10.0)
		"remove":
			_ask_removal(int(parts[1]))
	_shell.play("click", -14.0)
	_canvas.queue_redraw()


func _ask_removal(id: int) -> void:
	var g = _g()
	if g == null:
		return
	var e: Dictionary = g.by_id(id)
	var cost: int = g.removal_cost()
	_shell.message_box("SpotlessName Ltd", "Have %s's review taken down?\n\nGone by tomorrow morning. Fee: $%d.\nPayment in advance, no refunds." % [str(e.get("name", "a guest")), cost],
		"question", ["Pay $%d" % cost, "Cancel"], func(b: String):
			if not b.begins_with("Pay"):
				return
			var m: Node = _shell.main_node()
			var r: Dictionary = m.goggle_remove(id) if m != null and m.has_method("goggle_remove") else {}
			if bool(r.get("ok", false)):
				_shell.play("ding", -8.0)
				_notice = "SpotlessName Ltd: booked. $%d paid." % int(r.get("cost", 0))
			elif str(r.get("reason", "")) == "money":
				_notice = "SpotlessName Ltd: payment declined."
			_notice_until = Time.get_ticks_msec() / 1000.0 + 5.0
			_canvas.queue_redraw())


# ── drawing ──────────────────────────────────────────────────────────────────

## The page (drawn on _canvas: not the Control's own _draw, which the engine calls on
## this node and where drawing on the canvas is refused).
func _draw_page() -> void:
	_hits.clear()
	drawn_chars = 0
	var c := _canvas
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(Vector2.ZERO, c.size), T.WHITE)
	var g = _g()
	_draw_bar(c, w)
	_draw_head(c, w)
	if g == null:
		_text(c, T.FONT, Vector2(20, BAR_H + HEAD_H + 30), "The page cannot be displayed.", T.TEXT)
		return
	var top := BAR_H + HEAD_H + 4.0
	_draw_place(c, g, Rect2(8, top, LEFT_W, h - top - 6))
	c.draw_rect(Rect2(LEFT_W + 14, top, 1, h - top - 8), Color8(220, 220, 220))
	_draw_reviews(c, g, Rect2(LEFT_W + 22, top, w - LEFT_W - 30, h - top - 6))


## The browser's address line.
func _draw_bar(c: Control, w: float) -> void:
	c.draw_rect(Rect2(0, 0, w, BAR_H), T.FACE)
	c.draw_rect(Rect2(0, BAR_H - 1, w, 1), T.SHADOW)
	_text(c, T.FONT, Vector2(6, 15), "Address", T.TEXT)
	var r := Rect2(56, 3, w - 62, 16)
	c.draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	_text(c, T.FONT, Vector2(r.position.x + 4, 15), "http://www.goggle.cz/places?q=camp+cerne+jezero+hlubocany", T.TEXT)


## The wordmark, the goggles, the search box.
func _draw_head(c: Control, w: float) -> void:
	var y := BAR_H + 6.0
	var icon: Texture2D = _art.get(LOGO_ICON)
	var x := 10.0
	var word := "Goggle"
	for i in word.length():
		var ch := word[i]
		c.draw_string(T.FONT_BOLD, Vector2(x + 1, y + 27), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0, 0, 0, 0.25))
		c.draw_string(T.FONT_BOLD, Vector2(x, y + 26), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, LOGO_COLS[i])
		x += T.FONT_BOLD.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	if icon != null:
		c.draw_texture_rect(icon, Rect2(x + 2, y + 2, 28, 28), false)
	_text(c, T.FONT, Vector2(12, y + 38), "Places", GREY)
	var box := Rect2(LEFT_W + 22, y + 8, w - LEFT_W - 140, 20)
	c.draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), box)
	_text(c, T.FONT, Vector2(box.position.x + 5, box.position.y + 14), "camp cerne jezero hlubocany", T.TEXT)
	var btn := Rect2(box.end.x + 6, box.position.y - 1, 104, 22)
	c.draw_style_box(T.box("raised", T.FACE, Vector4.ZERO), btn)
	_text(c, T.FONT, Vector2(btn.position.x + 12, btn.position.y + 15), "Goggle Search", T.TEXT)
	c.draw_rect(Rect2(0, BAR_H + HEAD_H, w, 1), Color8(60, 100, 200))


## The place: the name, the average, the stars, the bars; the banner; the partner box.
func _draw_place(c: Control, g, r: Rect2) -> void:
	var day := _day()
	var x := r.position.x
	var y := r.position.y + 4
	_text(c, T.FONT_BOLD, Vector2(x, y + 12), "Camp Cerne Jezero", T.TEXT, 14)
	_text(c, T.FONT, Vector2(x, y + 27), "Campground  -  Hlubocany", GREY)
	y += 36
	var n: int = g.count()
	var rating: float = g.rating(day)
	if n == 0:
		_text(c, T.FONT, Vector2(x, y + 22), "No reviews yet.", GREY)
		y += 34
	else:
		_text(c, T.FONT_BOLD, Vector2(x, y + 30), "%.1f" % rating, T.TEXT, 32)
		_draw_stars(c, Vector2(x + 58, y + 8), rating, 16)
		_text(c, T.FONT, Vector2(x + 58, y + 38), "%d review%s" % [n, "" if n == 1 else "s"], Color8(26, 13, 171))
		y += 46
		var hist: Array = g.histogram()
		var top_n := 1
		for k in range(1, 6):
			top_n = maxi(top_n, int(hist[k]))
		for k in range(5, 0, -1):
			_text(c, T.FONT, Vector2(x, y + 10), str(k), GREY)
			var bar := Rect2(x + 12, y + 2, r.size.x - 40, 9)
			c.draw_rect(bar, Color8(232, 232, 232))
			c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * float(hist[k]) / float(top_n)), bar.size.y)), Color8(250, 186, 20))
			_text(c, T.FONT, Vector2(bar.end.x + 4, y + 10), str(hist[k]), GREY)
			y += 13
	if g.flagged(day):
		y += 4
		var fr := Rect2(x, y, r.size.x, 30)
		c.draw_rect(fr, Color8(255, 236, 236))
		c.draw_rect(Rect2(fr.position, Vector2(3, fr.size.y)), RED)
		_text(c, T.FONT_BOLD, Vector2(x + 8, y + 13), "Unusual review activity", RED)
		_text(c, T.FONT, Vector2(x + 8, y + 26), "on this listing has been detected.", RED)
		y += 34
	y += 8
	_draw_banner(c, g, Rect2(x, y, r.size.x, BANNER_H))
	y += BANNER_H + 8
	_draw_partner(c, g, Rect2(x, y, r.size.x, r.end.y - y))


## SpotlessName Ltd's ad (a 1998 banner: the picture, the pitch on it).
func _draw_banner(c: Control, g, r: Rect2) -> void:
	var tex: Texture2D = _art.get(BANNER)
	if tex != null:
		c.draw_texture_rect(tex, r, false)
	else:
		c.draw_rect(r, Color8(120, 220, 230))
	c.draw_rect(r, Color8(0, 0, 0), false, 1.0)
	# The pitch on the calm right side of the picture (the broom and the cloud left).
	var tx := r.position.x + r.size.x * 0.45 + 2.0
	var ty := r.position.y
	var blink := int(Time.get_ticks_msec() / 500) % 2 == 0
	_text(c, T.FONT_BOLD, Vector2(tx, ty + 17), "Bad review?", Color8(200, 0, 0) if blink else Color8(0, 0, 160))
	_text(c, T.FONT_BOLD, Vector2(tx, ty + 32), "GONE by", T.TEXT)
	_text(c, T.FONT_BOLD, Vector2(tx, ty + 45), "morning!", T.TEXT)
	_text(c, T.FONT, Vector2(tx, ty + 61), "SpotlessName Ltd", Color8(0, 0, 140))
	_text(c, T.FONT, Vector2(tx, ty + 74), "from $%d" % int(g.removal_cost()), T.TEXT)
	_text(c, T.FONT, Vector2(tx, ty + 88), "Discreet. Fast. Legal*", Color8(60, 60, 60), 10)


## Stavitel software's partner programme: what the next rating opens in Builder 98.
func _draw_partner(c: Control, g, r: Rect2) -> void:
	var nt: Dictionary = g.next_tier()
	c.draw_style_box(T.box("field", Color8(255, 252, 230), Vector4.ZERO), r)
	var x := r.position.x + 6
	var y := r.position.y + 14
	_text(c, T.FONT_BOLD, Vector2(x, y), "Builder 98 partner camps", Color8(120, 70, 0))
	y += 15
	if nt.is_empty():
		_text(c, T.FONT, Vector2(x, y), "Every blueprint is yours.", T.TEXT)
		return
	var pad: Texture2D = _art.get(PADLOCK)
	_draw_stars(c, Vector2(x, y - 10), float(nt["stars"]), 11)
	_text(c, T.FONT, Vector2(x + 62, y), "%.1f and %d reviews" % [float(nt["stars"]), int(nt["reviews"])], T.TEXT)
	y += 15
	var items: Array = nt["items"]
	var col_w := (r.size.x - 12.0) * 0.5
	for i in items.size():
		var ix := x + float(i % 2) * col_w
		var iy := y + float(i / 2) * 14.0
		if iy > r.end.y - 4:
			break
		if pad != null:
			c.draw_texture_rect(pad, Rect2(ix, iy - 11, 12, 12), false)
		_text(c, T.FONT, Vector2(ix + 15, iy), str(NAMES.get(str(items[i]), str(items[i]))), T.TEXT)


## The reviews: the sort tabs, a page of them, the page numbers.
func _draw_reviews(c: Control, g, r: Rect2) -> void:
	var day := _day()
	var x := r.position.x
	var y := r.position.y + 4
	_text(c, T.FONT_BOLD, Vector2(x, y + 12), "Reviews", T.TEXT, 14)
	var tx := x + 74.0
	for s in [["newest", "Newest"], ["lowest", "Lowest"], ["highest", "Highest"]]:
		var tw := T.FONT.get_string_size(str(s[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 14
		var tr := Rect2(tx, y, tw, 18)
		var on: bool = _sort == str(s[0])
		c.draw_style_box(T.box("pressed" if on else "raised", Color8(232, 232, 232) if on else T.FACE, Vector4.ZERO), tr)
		_text(c, T.FONT, Vector2(tx + 7, y + 13), str(s[1]), T.TEXT)
		_hits.append([tr, "sort:" + str(s[0])])
		tx += tw + 4
	var pw := T.FONT.get_string_size("Photos", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 14
	var pr := Rect2(tx + 10, y, pw, 18)
	c.draw_style_box(T.box("pressed" if _view == "photos" else "raised", Color8(232, 232, 232) if _view == "photos" else T.FACE, Vector4.ZERO), pr)
	_text(c, T.FONT, Vector2(pr.position.x + 7, y + 13), "Photos", T.TEXT)
	_hits.append([pr, "view:photos"])
	tx = pr.end.x + 4
	if _notice != "" and Time.get_ticks_msec() / 1000.0 < _notice_until:
		_text(c, T.FONT_BOLD, Vector2(tx + 8, y + 13), _notice, GREEN)
	y += 26
	if _view == "photos":
		_draw_photos(c, Rect2(x, y, r.size.x, r.end.y - y))
		return
	var list: Array = g.shown()
	match _sort:
		"lowest":
			list.sort_custom(func(a, b): return int(a["stars"]) < int(b["stars"]) or (int(a["stars"]) == int(b["stars"]) and int(a["day"]) > int(b["day"])))
		"highest":
			list.sort_custom(func(a, b): return int(a["stars"]) > int(b["stars"]) or (int(a["stars"]) == int(b["stars"]) and int(a["day"]) > int(b["day"])))
	var pages := maxi(1, ceili(float(list.size()) / PER_PAGE))
	_page = clampi(_page, 0, pages - 1)
	var card_h := (r.end.y - y - 34.0) / PER_PAGE
	for i in range(_page * PER_PAGE, mini(list.size(), (_page + 1) * PER_PAGE)):
		_draw_card(c, g, list[i], Rect2(x, y, r.size.x, card_h - 4), day)
		y += card_h
	if list.is_empty():
		_text(c, T.FONT, Vector2(x, y + 14), "Be the first to review this place.", GREY)
	_draw_pages(c, Rect2(x, r.end.y - 30, r.size.x, 28), pages)


func _draw_card(c: Control, g, e: Dictionary, r: Rect2, day: int) -> void:
	var x := r.position.x
	var y := r.position.y
	var face := _face(str(e["archetype"]))
	if face != null:
		c.draw_texture_rect(face, Rect2(x, y + 2, 28, 28), false)
	c.draw_rect(Rect2(x, y + 2, 28, 28), Color8(180, 180, 180), false, 1.0)
	var tx := x + 36.0
	_text(c, T.FONT_BOLD, Vector2(tx, y + 12), str(e["name"]), Color8(26, 13, 171))
	var helpful := int(e.get("helpful", 0))
	if helpful > 0:
		var ht := "%d found this helpful" % helpful
		var hw := T.FONT.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_text(c, T.FONT, Vector2(r.end.x - hw - 2, y + 12), ht, GREY, 10)
	_draw_stars(c, Vector2(tx, y + 16), float(e["stars"]), 11)
	_text(c, T.FONT, Vector2(tx + 64, y + 26), _when(int(e["day"]), day) + ("  (edited)" if bool(e.get("edited", false)) and str(e["text"]).contains("EDIT:") else ""), GREY)
	var ty := y + 42.0
	var lines := _wrap(str(e["text"]), r.size.x - 40.0)
	if lines.size() > 3:
		# Longer than the card: cut on the third line, as the page does.
		lines = lines.slice(0, 3)
		lines[2] = str(_wrap(str(lines[2]), r.size.x - 64.0)[0]) + " ..."
	for l in lines:
		_text(c, T.FONT, Vector2(tx, ty), l, T.TEXT)
		ty += 13
	# The owner's answer (yours, or one nobody here wrote).
	var ans := ""
	if str(e["reply"]) != "":
		ans = str(GOGGLE.REPLIES.get(str(e["reply"]), ""))
	elif str(e.get("ghost_reply", "")) != "":
		ans = str(e["ghost_reply"])
	if ans != "" and ty < r.end.y - 30:
		c.draw_rect(Rect2(tx, ty - 9, 2, 22), Color8(200, 200, 200))
		_text(c, T.FONT_BOLD, Vector2(tx + 6, ty), "Response from the owner", GREY, 10)
		var ow := T.FONT_BOLD.get_string_size("Response from the owner", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		c.draw_rect(Rect2(tx + 12 + ow, ty - 9, 34, 11), Color8(26, 80, 170))
		_text(c, T.FONT_BOLD, Vector2(tx + 15 + ow, ty), "Owner", T.WHITE, 10)
		_text(c, T.FONT, Vector2(tx + 6, ty + 12), _wrap(ans, r.size.x - 50.0)[0], Color8(70, 70, 70))
		ty += 26
	# What you can do about it.
	var by := r.end.y - 18.0
	var bx := tx
	if int(e["removing"]) >= 0:
		_chip(c, Vector2(bx, by), "Removal booked: gone by morning", Color8(0, 110, 140))
	elif bool(e["flagged"]):
		_chip(c, Vector2(bx, by), "Reported to Goggle", RED)
	else:
		if str(e["reply"]) == "" and str(e.get("ghost_reply", "")) == "":
			bx = _button(c, Vector2(bx, by), "Reply", "reply:%d" % int(e["id"])) + 4
		if int(e["stars"]) <= 3:
			bx = _button(c, Vector2(bx, by), "Remove  $%d" % int(g.removal_cost()), "remove:%d" % int(e["id"])) + 4
	if _replying == int(e["id"]):
		bx = _button(c, Vector2(bx + 8, by), "Apologise", "answer:%d:sorry" % int(e["id"])) + 4
		_button(c, Vector2(bx, by), "Blame the weather", "answer:%d:weather" % int(e["id"]))
	c.draw_rect(Rect2(x, r.end.y + 1, r.size.x, 1), Color8(232, 232, 232))


## Last summer's photos, three to a row, who took them under; one big on a click (over
## the rest, click it to put it back); then what people also searched for.
func _draw_photos(c: Control, r: Rect2) -> void:
	var x := r.position.x
	var y := r.position.y
	var tw := 120.0
	var th := 90.0
	var gap := (r.size.x - tw * 3.0) * 0.5
	if _photo >= 0 and _photo < PHOTOS.size():
		var ph: Array = PHOTOS[_photo]
		var big: Texture2D = _photos.get(PHOTO_DIR + "%d.png" % int(ph[0]))
		var br := Rect2(x + (r.size.x - 360.0) * 0.5, y, 360, 270)
		if big != null:
			c.draw_texture_rect(big, br, false)
		c.draw_rect(br, Color8(0, 0, 0), false, 1.0)
		_hits.append([br, "photo:-1"])
		_text(c, T.FONT, Vector2(br.position.x, br.end.y + 14), "Photo by %s  -  a year ago" % str(ph[1]), GREY)
		var bx := br.end.x - 70.0
		if _photo > 0:
			_button(c, Vector2(bx, br.end.y + 3), "<", "photo:%d" % (_photo - 1))
		if _photo < PHOTOS.size() - 1:
			_button(c, Vector2(bx + 30, br.end.y + 3), ">", "photo:%d" % (_photo + 1))
		return
	for i in PHOTOS.size():
		var ph: Array = PHOTOS[i]
		var pr := Rect2(x + float(i % 3) * (tw + gap), y + float(i / 3) * (th + 22.0), tw, th)
		var tex: Texture2D = _photos.get(PHOTO_DIR + "%d_t.png" % int(ph[0]))
		if tex != null:
			c.draw_texture_rect(tex, pr, false)
		c.draw_rect(pr, Color8(120, 120, 120) if _hover == "photo:%d" % i else Color8(200, 200, 200), false, 1.0)
		_hits.append([pr, "photo:%d" % i])
		_text(c, T.FONT, Vector2(pr.position.x, pr.end.y + 12), str(ph[1]), GREY, 10)
	y += (th + 22.0) * 2.0 + 6.0
	_text(c, T.FONT_BOLD, Vector2(x, y + 12), "People also searched for", T.TEXT)
	y += 20
	var aw := r.size.x / float(ALSO.size())
	for i in ALSO.size():
		var a: Array = ALSO[i]
		var ax := x + float(i) * aw
		var linked := str(a[4]) != ""
		var name_r := Rect2(ax, y, aw - 8, 14)
		_text(c, T.FONT_BOLD, Vector2(ax, y + 11), str(a[0]), Color8(26, 13, 171) if linked else T.TEXT)
		if linked:
			var nw := T.FONT_BOLD.get_string_size(str(a[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			c.draw_rect(Rect2(ax, y + 13, nw, 1), Color8(26, 13, 171))
			_hits.append([name_r, "also:%d" % i])
		_draw_stars(c, Vector2(ax, y + 16), float(a[2]), 9)
		_text(c, T.FONT, Vector2(ax + 52, y + 25), "%.1f (%d)" % [float(a[2]), int(a[3])], GREY, 10)
		_text(c, T.FONT, Vector2(ax, y + 38), str(a[1]), GREY, 10)


## G o o o g l e, a letter o for each page, the page's number under it.
func _draw_pages(c: Control, r: Rect2, pages: int) -> void:
	var word: Array = ["G"]
	for i in pages:
		word.append("o")
	word.append_array(["g", "l", "e"])
	var widths := 0.0
	for ch in word:
		widths += T.FONT_BOLD.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var x := r.position.x + (r.size.x - widths) * 0.5
	var y := r.position.y + 18
	var col_i := 0
	for i in word.size():
		var ch: String = word[i]
		var cw := T.FONT_BOLD.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var page := i - 1
		var is_page := ch == "o" and page >= 0 and page < pages
		var col: Color = LOGO_COLS[col_i % LOGO_COLS.size()]
		if is_page and page == _page:
			col = RED
		c.draw_string(T.FONT_BOLD, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		if is_page:
			var num := str(page + 1)
			var nw := T.FONT.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			_text(c, T.FONT, Vector2(x + (cw - nw) * 0.5, y + 11), num, T.TEXT if page == _page else Color8(26, 13, 171))
			_hits.append([Rect2(x, r.position.y, cw, r.size.y), "page:%d" % page])
		x += cw
		col_i += 1


# ── bits ─────────────────────────────────────────────────────────────────────

func _draw_stars(c: Control, at: Vector2, value: float, sz: int) -> void:
	for i in 5:
		var k := "empty"
		if value >= float(i) + 0.75:
			k = "full"
		elif value >= float(i) + 0.25:
			k = "half"
		var tex: Texture2D = _stars.get(k)
		var r := Rect2(at + Vector2(i * (sz + 1), 0), Vector2(sz, sz))
		if tex != null:
			c.draw_texture_rect(tex, r, false)
		else:
			_text(c, T.FONT_BOLD, r.position + Vector2(1, sz - 1), "*", Color8(250, 186, 20) if k != "empty" else Color8(200, 200, 200), sz + 2)


func _button(c: Control, at: Vector2, label: String, action: String) -> float:
	var w := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 14
	var r := Rect2(at, Vector2(w, 17))
	var hov := _hover == action
	c.draw_style_box(T.box("raised", Color8(214, 220, 236) if hov else T.FACE, Vector4.ZERO), r)
	_text(c, T.FONT, Vector2(at.x + 7, at.y + 12), label, T.TEXT)
	_hits.append([r, action])
	return r.end.x


func _chip(c: Control, at: Vector2, label: String, col: Color) -> void:
	var w := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 12
	c.draw_rect(Rect2(at, Vector2(w, 16)), col)
	_text(c, T.FONT, Vector2(at.x + 6, at.y + 12), label, T.WHITE)


func _text(c: Control, f: Font, at: Vector2, s: String, col: Color, fs: int = T.FONT_SIZE) -> void:
	c.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	drawn_chars += s.length()


func _wrap(s: String, w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in s.split(" "):
		var test := word if line == "" else line + " " + word
		if T.FONT.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x > w and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out if not out.is_empty() else [""]


func _when(d: int, today: int) -> String:
	if d <= 0:
		return "a year ago"
	var ago := today - d
	if ago <= 0:
		return "today"
	if ago == 1:
		return "yesterday"
	if ago < 7:
		return "%d days ago" % ago
	return "%d weeks ago" % (ago / 7)


## The reviewer's face: the top of their figure, small.
func _face(arch: String) -> Texture2D:
	var key := arch if FACES.has(arch) else "quiet_guy"
	if _faces.has(key):
		return _faces[key]
	var path: String = FACES[key]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var src := (load(path) as Texture2D).get_image().duplicate() as Image
		if src.is_compressed():
			src.decompress()
		var used := src.get_used_rect()
		var side := mini(used.size.x, int(used.size.y * 0.32))
		var cx := used.position.x + (used.size.x - side) / 2
		var crop := src.get_region(Rect2i(cx, used.position.y, side, side))
		crop.resize(28, 28, Image.INTERPOLATE_NEAREST)
		var bg := Image.create(28, 28, false, Image.FORMAT_RGBA8)
		bg.fill(Color8(214, 222, 232))
		bg.blend_rect(crop, Rect2i(0, 0, 28, 28), Vector2i.ZERO)
		tex = ImageTexture.create_from_image(bg)
	_faces[key] = tex
	return tex
