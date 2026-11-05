extends Control

## Atlas, the Czech web directory of 1998 (the PC's fifth tab, key 5; the logic is
## scripts/reviews/goggle.gd, named from when this was Goggle, a search engine's places
## page; the user 30. 10.: "make it a Czech directory of the 90s, call it Atlas, red and
## black"). Under the black masthead and the red bar of where you are, four pages:
##   - the camp's page (it opens there): on the left the place, the big average and the
##     stars, how many reviews, the bars of five to one; SpotlessName Ltd's banner (a bad
##     review gone by morning, for a price); Stavitel software's partner box (which
##     blueprints the next guests open in Builder 98). On the right the reviews three to
##     a page, newest, lowest or highest first, each with the guest's face, the stars,
##     when, what they wrote and the owner's answer, Reply (two answers) and Remove; or
##     last summer's photos (one has somebody in it who should not be there), big on a
##     click, and what people also searched for (Agrostroj's site);
##   - the catalogue, Atlas's front page: a banner over its sections; Travel leads on to
##   - Camps in the district: the camp among the others, by their stars;
##   - Advertise (the user 30. 10.: "buy banners on Atlas: some percent more mails for a
##     while, as in RollerCoaster Tycoon"): three kinds for 1, 3 or 7 days, each seen
##     where it was bought for: the camp first under Camps with a TIP, its banner over the
##     camps, its banner over the catalogue (goggle.ADS: the prices, how much more mail).

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const GOGGLE = preload("res://scripts/reviews/goggle.gd")
const STAR_DIR := "res://assets/textury/os98/web/"
const BANNER := "res://assets/textury/os98/web/spotless_banner.png"
const PADLOCK := "res://assets/textury/os98/icons/padlock_16.png"
const LOGO_ICON := "res://assets/textury/os98/icons/atlas.png"
const FACES := {
	"quiet_guy": "res://assets/textury/npc/host1.png", "drunk": "res://assets/textury/npc/host2.png",
	"cheap_chick": "res://assets/textury/npc/host3.png", "tramp": "res://assets/textury/npc/host_tramp.png",
	"family": "res://assets/textury/npc/host_family.png", "picker": "res://assets/textury/npc/host_pensioner.png",
}
const NAMES := {
	"tent_1": "Tent", "cabin_1": "Cabin", "caravan_1": "Caravan", "toilet_block": "Toilets", "shower_block": "Showers",
	"restaurant": "Bistro", "pub": "Pub", "corn_stand": "Corn stand", "bonfire": "Campfire", "sports_field": "Pitch",
	"lake_slide": "Lake slide", "playground": "Playground", "ping_pong": "Ping-pong", "hammock": "Hammock",
	"bench": "Bench", "picnic_table": "Picnic table", "flower_bed": "Flower bed", "gnome": "Gnome", "flagpole": "Flagpole",
	"tree_spruce": "Spruce", "tree_birch": "Birch",
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
	["U Jezera", "Pub, Liblice", 4.1, 23, ""],
	["Jednota u Marku", "Grocery", 3.6, 15, ""],
]
## The catalogue's sections on the front page: [name, pages in it, three of its own].
## Travel leads to Camps; the rest are being rebuilt.
const SECTIONS := [
	["Cars and motorbikes", 2841, "Cars, Motorbikes, Spare parts"],
	["Travel", 1977, "Accommodation, Camps, Timetables"],
	["Business and money", 1260, "Banks, Shares, Insurance"],
	["Games", 954, "Computer games, Cheats, Cards"],
	["Culture", 2213, "Cinema, Theatre, Music"],
	["People and society", 1678, "Clubs, Hobbies, Mysteries"],
	["Shops and services", 3105, "Shops, Building, Crafts"],
	["Computers and the Internet", 4410, "Hardware, Software, Shareware"],
	["Regions", 2766, "Praha, Vysocina, Hlubocany district"],
	["Sport", 1532, "Football, Ice hockey, Fishing"],
	["Health", 812, "Doctors, Chemists, Herbs"],
	["News and media", 1094, "Papers, Radio, Television"],
]
## The other camps of the district under Camps: [name, stars, reviews, what, address].
const CAMPS := [
	["Autokemp Lesna", 3.8, 41, "Cabins, tents, a snack bar, boats for hire.", "www.autokemp-lesna.cz"],
	["Chatova osada Raj", 4.3, 29, "Family chalets in the woods, a playground.", "www.osada-raj.cz"],
	["Kemp Pod Hrazi", 3.2, 18, "Tents by the water, showers, fishing.", "www.podhrazi.cz"],
	["Taboriste U Mlyna", 3.5, 9, "A meadow by the brook, a fire pit, a dry toilet.", ""],
	["RS Jiskra Liblice", 2.9, 12, "The works' holiday chalets, a canteen, table tennis.", "www.jiskra-liblice.cz"],
]
## Each kind of advertising: where it shows and what it says it does.
const AD_TEXT := {
	"listing": "Your camp first under Camps, in red, with a TIP.",
	"travel": "Your banner over the camps, for everyone looking for a holiday.",
	"front": "Your banner on the front page, over the catalogue. Everyone sees it.",
}
const BAR_H := 22.0
const HEAD_H := 44.0
const NAV_H := 18.0
## Where the pages begin: under the address, the masthead and the red bar.
const TOP := BAR_H + HEAD_H + NAV_H
## A full banner of 1998.
const FULL := Vector2(468, 60)
const GREY := Color8(112, 112, 112)
const GREEN := Color8(0, 120, 40)
## Atlas's red and black; its links are red and underlined.
const RED := Color8(204, 0, 0)
const BLACK := Color8(20, 20, 20)
const LINK := Color8(176, 0, 0)
const PALE := Color8(255, 236, 232)
const RULE := Color8(224, 224, 224)
## The camp's banner: the woods' greens, lighter at the top.
const WOODS := [Color8(30, 112, 58), Color8(22, 96, 48), Color8(14, 80, 38), Color8(8, 64, 30)]

var _shell
var _win
var _canvas: Control
## The page: "place" (the camp's), "home" (the catalogue), "camps" or "ads".
var _view := "place"
## The camp's page shows "reviews" or "photos".
var _part := "reviews"
var _sort := "newest"
## The photo open big (its index in PHOTOS), or -1.
var _photo := -1
var _photos: Dictionary = {}
var _page := 0
## The review whose Reply is open (its two answers showing), or -1.
var _replying := -1
## Advertise: how many days a campaign is ordered for (goggle.AD_DAYS).
var _days := 3
var _hits: Array = []        # [Rect2, action]
var _hover := ""
var _faces: Dictionary = {}
var _stars: Dictionary = {}
var _art: Dictionary = {}
var _tick := 0.0
var _notice := ""
var _notice_col := GREEN
var _notice_until := 0.0
## How many characters the page drew (os98_check: a page is not empty).
var drawn_chars := 0


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_page)
	_canvas.gui_input.connect(_input_canvas)
	_canvas.mouse_exited.connect(func():
		_hover = ""
		_shell.pointer_hand = false
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
	_open(args)
	_layout()


func reopen(args: Dictionary) -> void:
	_open(args)
	refresh()


## A link from elsewhere may name the page ({"page": "ads"}).
func _open(args: Dictionary) -> void:
	var p := str(args.get("page", ""))
	if p in ["place", "home", "camps", "ads"]:
		_go(p)


func _layout() -> void:
	if _canvas != null:
		_canvas.position = Vector2.ZERO
		_canvas.size = size
		_canvas.queue_redraw()


func refresh() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	# A quarter of a second: the banners blink as the GIFs did.
	_tick -= delta
	if _tick <= 0.0 and is_visible_in_tree():
		_tick = 0.25
		refresh()


func _g():
	var m: Node = _shell.main_node() if _shell != null else null
	return m.get("_goggle") if m != null else null


func _day() -> int:
	return CoreRoot.get_day() if CoreRoot != null else 1


## The hour now from day 0 (main's; Atlas's campaigns run from hour to hour).
func _hour_abs() -> int:
	var m: Node = _shell.main_node() if _shell != null else null
	return int(m.atlas_hour()) if m != null and m.has_method("atlas_hour") else _day() * 24 + 9


func _camp_name() -> String:
	return tr("Camp Cerne Jezero")


# ── input ────────────────────────────────────────────────────────────────────

func _input_canvas(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := _hit_at(e.position)
		if h != _hover:
			_hover = h
			# The PC's own pointer: the hand over a link, as in the browser.
			_shell.pointer_hand = h != ""
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


func _go(view: String) -> void:
	_view = view
	_photo = -1
	_replying = -1
	_notice_until = 0.0


func _act(a: String) -> void:
	var parts := a.split(":")
	match parts[0]:
		"go":
			_go(parts[1])
		"search":
			# What the box has is a camp: the camps of the district come up.
			_go("camps")
		"sort":
			_sort = parts[1]
			_part = "reviews"
			_page = 0
			_replying = -1
		"part":
			_part = parts[1]
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
		"section":
			_say(LANG.f("%s: this section is being rebuilt. Please try again later.", tr(str(SECTIONS[int(parts[1])][0]))), RED)
		"days":
			_days = int(parts[1])
		"order":
			_ask_ad(parts[1])
	_shell.play("click", -14.0)
	_canvas.queue_redraw()


func _say(text: String, col: Color) -> void:
	_notice = text
	_notice_col = col
	_notice_until = Time.get_ticks_msec() / 1000.0 + 5.0


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
				_say(LANG.f("SpotlessName Ltd: booked. $%d paid.", int(r.get("cost", 0))), GREEN)
			elif str(r.get("reason", "")) == "money":
				_say(tr("SpotlessName Ltd: payment declined."), RED)
			_canvas.queue_redraw())


## Advertise: a campaign of `kind` for the days chosen, asked first as a shop would.
func _ask_ad(kind: String) -> void:
	var m: Node = _shell.main_node() if _shell != null else null
	if m == null or not m.has_method("atlas_buy_ad"):
		return
	var days := _days
	var cost: int = GOGGLE.ad_cost(kind, days)
	var ad: Dictionary = GOGGLE.ADS[kind]
	var end := _hour_abs() + days * 24
	_shell.message_box("Atlas s.r.o.", "Order %s for %s?\n\nIt runs from now till day %d, %d:00.\nBooking letters: %d%% more while it runs.\nPrice: $%d, paid in advance." % [
			str(ad["name"]), "%d day%s" % [days, "" if days == 1 else "s"], end / 24, end % 24, roundi(float(ad["boost"]) * 100.0), cost],
		"question", ["Pay $%d" % cost, "Cancel"], func(b: String):
			if not b.begins_with("Pay"):
				return
			var r: Dictionary = m.atlas_buy_ad(kind, days)
			if bool(r.get("ok", false)):
				_shell.play("ding", -8.0)
				_say(LANG.f("Ordered: %s. It runs from now.", tr(str(ad["name"]))), GREEN)
			elif str(r.get("reason", "")) == "money":
				_say(tr("Atlas s.r.o.: payment declined. Not enough money."), RED)
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
	_draw_nav(c, w)
	if g == null:
		_text(c, T.FONT, Vector2(20, TOP + 30), tr("The page cannot be displayed."), T.TEXT)
		return
	var body := Rect2(0, TOP, w, h - TOP)
	match _view:
		"home":
			_draw_home(c, g, body)
		"camps":
			_draw_camps(c, g, body)
		"ads":
			_draw_ads(c, g, body)
		_:
			var top := TOP + 4.0
			_draw_place(c, g, Rect2(8, top, LEFT_W, h - top - 6))
			c.draw_rect(Rect2(LEFT_W + 14, top, 1, h - top - 8), RULE)
			_draw_reviews(c, g, Rect2(LEFT_W + 22, top, w - LEFT_W - 30, h - top - 6))


## The browser's address line.
func _draw_bar(c: Control, w: float) -> void:
	c.draw_rect(Rect2(0, 0, w, BAR_H), T.FACE)
	c.draw_rect(Rect2(0, BAR_H - 1, w, 1), T.SHADOW)
	_text(c, T.FONT, Vector2(6, 15), tr("Address"), T.TEXT)
	var r := Rect2(56, 3, w - 62, 16)
	c.draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	var url: String = {"home": "http://www.atlas.cz/", "camps": "http://www.atlas.cz/katalog/cestovani/kempy/",
		"ads": "http://www.atlas.cz/reklama/"}.get(_view, "http://www.atlas.cz/katalog/cestovani/kempy/cerne-jezero.html")
	_text(c, T.FONT, Vector2(r.position.x + 4, 15), url, T.TEXT)


## The masthead: black, the red globe and ATLAS, what it is, the search.
func _draw_head(c: Control, w: float) -> void:
	var y := BAR_H
	c.draw_rect(Rect2(0, y, w, HEAD_H), BLACK)
	var icon: Texture2D = _art.get(LOGO_ICON)
	if icon != null:
		c.draw_texture_rect(icon, Rect2(8, y + 6, 32, 32), false)
	var word := "ATLAS"
	var x := 44.0
	_text(c, T.FONT_BOLD, Vector2(x + 2, y + 33), word, Color8(90, 0, 0), 24)
	_text(c, T.FONT_BOLD, Vector2(x, y + 31), word, Color8(236, 20, 20), 24)
	x += T.FONT_BOLD.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 2
	_text(c, T.FONT_BOLD, Vector2(x, y + 31), ".cz", T.WHITE)
	var logo := Rect2(4, y + 2, x + 22, HEAD_H - 4)
	_hits.append([logo, "go:home"])
	_text(c, T.FONT, Vector2(x + 28, y + 31), tr("the Czech web directory"), Color8(176, 176, 176))
	var btn := Rect2(w - 74, y + 12, 66, 21)
	var box := Rect2(btn.position.x - 176, y + 13, 170, 19)
	c.draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), box)
	var q: String = {"place": tr("camp cerne jezero"), "camps": tr("camps hlubocany")}.get(_view, "")
	_text(c, T.FONT, Vector2(box.position.x + 5, box.position.y + 14), q, T.TEXT)
	c.draw_style_box(T.box("raised", Color8(224, 24, 24) if _hover == "search" else RED, Vector4.ZERO), btn)
	var label := tr("Search")
	var lw := T.FONT_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	_text(c, T.FONT_BOLD, Vector2(btn.position.x + (btn.size.x - lw) * 0.5, btn.position.y + 15), label, T.WHITE)
	_hits.append([btn, "search"])


## The red bar: where you are in the catalogue, each step a link; Advertise on the right.
func _draw_nav(c: Control, w: float) -> void:
	var y := BAR_H + HEAD_H
	c.draw_rect(Rect2(0, y, w, NAV_H), RED)
	c.draw_rect(Rect2(0, y + NAV_H - 1, w, 1), Color8(120, 0, 0))
	var steps: Array = [[tr("Catalogue"), "go:home"]]
	match _view:
		"camps":
			steps.append_array([[tr("Travel"), "go:camps"], [tr("Camps"), "go:camps"]])
		"place":
			steps.append_array([[tr("Travel"), "go:camps"], [tr("Camps"), "go:camps"], [_camp_name(), "go:place"]])
		"ads":
			steps.append([tr("Advertise on Atlas"), "go:ads"])
	var x := 8.0
	for i in steps.size():
		var s: Array = steps[i]
		var last := i == steps.size() - 1
		var sw := T.FONT_BOLD.get_string_size(str(s[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		_text(c, T.FONT_BOLD, Vector2(x, y + 13), str(s[0]), T.WHITE if last or _hover != str(s[1]) else Color8(255, 230, 120))
		if not last:
			c.draw_rect(Rect2(x, y + 15, sw, 1), T.WHITE)
			_hits.append([Rect2(x - 2, y, sw + 4, NAV_H), str(s[1])])
			_text(c, T.FONT_BOLD, Vector2(x + sw + 6, y + 13), ">", Color8(255, 170, 170))
			x += sw + 18
	# Advertise, on black at the end of the bar.
	var ad := tr("Advertise")
	var aw := T.FONT_BOLD.get_string_size(ad, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 16
	var ar := Rect2(w - aw - 4, y + 1, aw, NAV_H - 2)
	c.draw_rect(ar, BLACK)
	_text(c, T.FONT_BOLD, Vector2(ar.position.x + 8, y + 13), ad, Color8(255, 230, 120) if _hover == "go:ads" or _view == "ads" else T.WHITE)
	_hits.append([ar, "go:ads"])


# ── the catalogue (the front page) ───────────────────────────────────────────

func _draw_home(c: Control, g, r: Rect2) -> void:
	var w := r.size.x
	var y := r.position.y + 8
	var slot := Rect2(floorf((w - FULL.x) * 0.5), y, FULL.x, FULL.y)
	if not g.ad_running("front", _hour_abs()).is_empty():
		_draw_my_banner(c, slot)
	else:
		_draw_house_ad(c, slot)
	y += FULL.y + 12
	var cols := 3
	var col_w := floorf((w - 24.0) / cols)
	for i in SECTIONS.size():
		var s: Array = SECTIONS[i]
		var x := 12.0 + float(i % cols) * col_w
		var sy := y + float(i / cols) * 50.0
		var travel := str(s[0]) == "Travel"
		var end := _link(c, T.FONT_BOLD, Vector2(x, sy + 12), tr(str(s[0])), "go:camps" if travel else "section:%d" % i)
		_text(c, T.FONT, Vector2(end + 5, sy + 12), "(%s)" % _num(int(s[1])), GREY)
		var lines := _wrap(tr(str(s[2])) + "...", col_w - 14.0)
		for k in mini(2, lines.size()):
			_text(c, T.FONT, Vector2(x, sy + 26 + 13 * k), str(lines[k]), T.TEXT)
	y += 50.0 * ceilf(float(SECTIONS.size()) / cols) + 2
	c.draw_rect(Rect2(12, y, w - 24, 1), RULE)
	y += 16
	var links: Array = [[tr("Add a page"), ""], [tr("Advertise on Atlas"), "go:ads"], [tr("About Atlas"), ""]]
	var total := 0.0
	for l in links:
		total += T.FONT.get_string_size(str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 20
	var lx := floorf((w - total + 20) * 0.5)
	for l in links:
		if str(l[1]) != "":
			lx = _link(c, T.FONT, Vector2(lx, y), str(l[0]), str(l[1])) + 20
		else:
			_text(c, T.FONT, Vector2(lx, y), str(l[0]), GREY)
			lx += T.FONT.get_string_size(str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 20
	y += 16
	var foot := _notice if _notice_on() else LANG.f("(c) 1996-98 Atlas s.r.o.   Visits today: %s", _num(38000 + (_day() * 1361) % 9000))
	var fw := T.FONT.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	_text(c, T.FONT_BOLD if _notice_on() else T.FONT, Vector2(floorf((w - fw) * 0.5), y), foot, _notice_col if _notice_on() else GREY)


## Atlas's own banner where nobody has bought the place: the place for sale.
func _draw_house_ad(c: Control, r: Rect2) -> void:
	c.draw_rect(r, BLACK)
	var blink := int(Time.get_ticks_msec() / 600) % 2 == 0
	_text(c, T.FONT_BOLD, Vector2(r.position.x + 14, r.position.y + 28), tr("YOUR CAMP HERE?"), Color8(236, 20, 20) if blink else T.WHITE, 24)
	_text(c, T.FONT, Vector2(r.position.x + 16, r.position.y + 48), LANG.f("Advertise on Atlas, from $%d a day.", int(GOGGLE.ADS["listing"]["per_day"])), Color8(200, 200, 200))
	var btn := Rect2(r.end.x - 98, r.position.y + 17, 86, 26)
	c.draw_style_box(T.box("raised", RED, Vector4.ZERO), btn)
	var more := tr("MORE >>")
	var mw := T.FONT_BOLD.get_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	_text(c, T.FONT_BOLD, Vector2(btn.position.x + (btn.size.x - mw) * 0.5, btn.position.y + 17), more, T.WHITE)
	c.draw_rect(r, Color8(120, 0, 0), false, 1.0)
	_hits.append([r, "go:ads"])


## The camp's own banner (bought on Advertise, its preview there): a GIF of 1998 in two
## frames, the lake's photo, the name in yellow, the button blinking. A click goes to the
## camp's page.
func _draw_my_banner(c: Control, r: Rect2, link := true) -> void:
	var band := ceilf(r.size.y / WOODS.size())
	for i in WOODS.size():
		c.draw_rect(Rect2(r.position.x, r.position.y + band * i, r.size.x, minf(band, r.end.y - r.position.y - band * i)), WOODS[i])
	var pr := Rect2(r.position + Vector2(4, 4), Vector2(floorf((r.size.y - 8) * 4.0 / 3.0), r.size.y - 8))
	var photo: Texture2D = _photos.get(PHOTO_DIR + "1_t.png")
	if photo != null:
		c.draw_texture_rect(photo, pr, false)
	c.draw_rect(pr, Color8(0, 0, 0), false, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var btn := Rect2(r.end.x - 96, r.position.y + floorf((r.size.y - 26) * 0.5), 86, 26)
	var tx := pr.end.x + 10
	var room := btn.position.x - tx - 6
	var big: String
	var small: String
	if fmod(t, 5.0) < 3.0:
		big = _camp_name().to_upper()
		small = tr("Tents, cabins, the lake, the woods. Hlubocany district.")
	else:
		big = tr("FREE BEDS!")
		small = tr("Write to us: we answer within the day.")
	var fs := 24 if T.FONT_BOLD.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x <= room else T.FONT_SIZE
	_text(c, T.FONT_BOLD, Vector2(tx + 2, r.position.y + 29), big, Color8(0, 30, 10), fs)
	_text(c, T.FONT_BOLD, Vector2(tx, r.position.y + 27), big, Color8(255, 226, 40), fs)
	_text(c, T.FONT, Vector2(tx, r.position.y + 46), small, T.WHITE)
	var blink := int(t * 2.0) % 2 == 0
	c.draw_style_box(T.box("raised", Color8(255, 222, 0) if blink else T.WHITE, Vector4.ZERO), btn)
	var go := tr("CLICK HERE!")
	var gw := T.FONT_BOLD.get_string_size(go, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	_text(c, T.FONT_BOLD, Vector2(btn.position.x + (btn.size.x - gw) * 0.5, btn.position.y + 17), go, RED)
	c.draw_rect(r, Color8(0, 0, 0), false, 1.0)
	if link:
		_hits.append([r, "go:place"])


# ── Camps ────────────────────────────────────────────────────────────────────

func _draw_camps(c: Control, g, r: Rect2) -> void:
	var w := r.size.x
	var x := 14.0
	var y := r.position.y + 6
	var now := _hour_abs()
	var day := _day()
	_text(c, T.FONT_BOLD, Vector2(x, y + 13), tr("Camps"), T.TEXT, 14)
	var tw := T.FONT_BOLD.get_string_size(tr("Camps"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_text(c, T.FONT, Vector2(x + tw + 8, y + 13), tr("Hlubocany district"), GREY)
	var n_text := LANG.f("%d entries", CAMPS.size() + 1)
	_text(c, T.FONT, Vector2(w - 14 - T.FONT.get_string_size(n_text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x, y + 13), n_text, GREY)
	y += 22
	if not g.ad_running("travel", now).is_empty():
		_draw_my_banner(c, Rect2(floorf((w - FULL.x) * 0.5), y, FULL.x, FULL.y))
		y += FULL.y + 8
	else:
		var box := Rect2(x, y, w - 28, 22)
		c.draw_rect(box, Color8(250, 248, 240))
		c.draw_rect(box, Color8(210, 200, 180), false, 1.0)
		var pitch := LANG.f("Want to be first here? A priority listing from $%d a day.", int(GOGGLE.ADS["listing"]["per_day"]))
		_text(c, T.FONT, Vector2(x + 8, y + 15), pitch, T.TEXT)
		_link(c, T.FONT_BOLD, Vector2(x + 16 + T.FONT.get_string_size(pitch, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x, y + 15), tr("Advertise >>"), "go:ads")
		y += 30
	# The camps by their stars; the priority listing puts the camp first, whatever.
	var mine := ["", float(g.rating(day)), int(g.count()), "Tents and cabins by the reservoir, swimming, the woods.", ""]
	var rows: Array = CAMPS.duplicate()
	rows.append(mine)
	rows.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var tip: bool = not g.ad_running("listing", now).is_empty()
	if tip:
		rows.erase(mine)
		rows.push_front(mine)
	var row_h := minf(44.0, floorf((r.end.y - y - 4) / rows.size()))
	for e in rows:
		var is_mine: bool = e == mine
		var er := Rect2(x - 6, y, w - 16, row_h - 4)
		if is_mine and tip:
			c.draw_rect(er, PALE)
			c.draw_rect(er, Color8(230, 150, 140), false, 1.0)
		var nx := x
		if is_mine and tip:
			var tag := Rect2(nx, y + 3, 26, 13)
			c.draw_rect(tag, RED)
			_text(c, T.FONT_BOLD, Vector2(nx + 4, y + 13), tr("TIP"), T.WHITE)
			nx += 32
		var title: String = _camp_name() if is_mine else tr(str(e[0]))
		var end: float
		if is_mine:
			end = _link(c, T.FONT_BOLD, Vector2(nx, y + 14), title, "go:place")
		else:
			_text(c, T.FONT_BOLD, Vector2(nx, y + 14), title, T.TEXT)
			end = nx + T.FONT_BOLD.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var stars := float(e[1])
		if int(e[2]) > 0:
			_draw_stars(c, Vector2(end + 10, y + 4), stars, 11)
			_text(c, T.FONT, Vector2(end + 72, y + 14), "%.1f (%d)" % [stars, int(e[2])], GREY)
		else:
			_text(c, T.FONT, Vector2(end + 10, y + 14), tr("No reviews yet."), GREY)
		var line := tr(str(e[3]))
		_text(c, T.FONT, Vector2(nx, y + 28), line, T.TEXT)
		if str(e[4]) != "":
			_text(c, T.FONT, Vector2(nx + T.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 10, y + 28), str(e[4]), GREEN)
		y += row_h


# ── Advertise ────────────────────────────────────────────────────────────────

func _draw_ads(c: Control, g, r: Rect2) -> void:
	var w := r.size.x
	var x := 14.0
	var y := r.position.y + 6
	var now := _hour_abs()
	_text(c, T.FONT_BOLD, Vector2(x, y + 13), tr("Advertise on Atlas"), T.TEXT, 14)
	y += 18
	if _notice_on():
		_text(c, T.FONT_BOLD, Vector2(x, y + 12), _notice, _notice_col)
	else:
		_text(c, T.FONT, Vector2(x, y + 12), tr("Atlas is opened 40,000 times a day. Show them your camp."), GREY)
	y += 20
	# How long: the three lengths on offer, the one chosen black.
	var label := tr("Campaign length:")
	_text(c, T.FONT_BOLD, Vector2(x, y + 14), label, T.TEXT)
	var cx := x + T.FONT_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 10
	for d in GOGGLE.AD_DAYS:
		var s := LANG.f("%d day%s", [int(d), "" if int(d) == 1 else "s"])
		var sw := T.FONT_BOLD.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 18
		var chip := Rect2(cx, y + 1, sw, 19)
		var on := _days == int(d)
		c.draw_rect(chip, BLACK if on else (PALE if _hover == "days:%d" % d else T.WHITE))
		c.draw_rect(chip, BLACK if on else RED, false, 1.0)
		_text(c, T.FONT_BOLD, Vector2(cx + 9, y + 15), s, T.WHITE if on else LINK)
		_hits.append([chip, "days:%d" % d])
		cx += sw + 6
	y += 28
	var row_h := 62.0
	for kind in GOGGLE.AD_KINDS:
		_draw_offer(c, g, str(kind), Rect2(x, y, w - 28, row_h - 6), now)
		y += row_h
		c.draw_rect(Rect2(x, y - 4, w - 28, 1), RULE)
	y += 2
	_text(c, T.FONT_BOLD, Vector2(x, y + 12), tr("Your banner"), T.TEXT)
	_text(c, T.FONT, Vector2(x, y + 26), tr("468 x 60, as a GIF."), GREY)
	_text(c, T.FONT, Vector2(x, y + 40), tr("A click on it opens"), GREY)
	_text(c, T.FONT, Vector2(x, y + 54), tr("your camp's page."), GREY)
	_draw_my_banner(c, Rect2(w - FULL.x - 14, y + 2, FULL.x, FULL.y), false)


## One kind of advertising: where it shows (a sketch of the page), what it is and does,
## the price, Order or how long it still runs.
func _draw_offer(c: Control, g, kind: String, r: Rect2, now: int) -> void:
	var ad: Dictionary = GOGGLE.ADS[kind]
	var x := r.position.x
	var y := r.position.y
	_draw_where(c, kind, Rect2(x, y + 4, 56, 44))
	var tx := x + 68
	_text(c, T.FONT_BOLD, Vector2(tx, y + 13), tr(str(ad["name"])), T.TEXT)
	var price_x := r.end.x - 196.0
	var lines := _wrap(tr(str(AD_TEXT[kind])), price_x - tx - 12)
	for k in mini(2, lines.size()):
		_text(c, T.FONT, Vector2(tx, y + 27 + 13 * k), str(lines[k]), GREY)
	_text(c, T.FONT_BOLD, Vector2(tx, y + 27 + 13 * mini(2, lines.size())), LANG.f("+%d%% booking letters", roundi(float(ad["boost"]) * 100.0)), GREEN)
	_text(c, T.FONT, Vector2(price_x, y + 13), LANG.f("$%d a day", int(ad["per_day"])), T.TEXT)
	_text(c, T.FONT_BOLD, Vector2(price_x, y + 28), LANG.f("%d day%s: $%d", [_days, "" if _days == 1 else "s", GOGGLE.ad_cost(kind, _days)]), T.TEXT)
	var run: Dictionary = g.ad_running(kind, now)
	var bx := r.end.x - 84.0
	if run.is_empty():
		_button(c, Vector2(bx, y + 12), tr("Order..."), "order:" + kind, 80.0, 22.0)
		return
	var left := int(run["to_h"]) - now
	_text(c, T.FONT_BOLD, Vector2(bx, y + 13), tr("Running"), GREEN)
	_text(c, T.FONT, Vector2(bx, y + 27), LANG.f("%d h left", left) if left < 24 else LANG.f("%d day%s left", [ceili(left / 24.0), "" if ceili(left / 24.0) == 1 else "s"]), T.TEXT)
	var bar := Rect2(bx, y + 33, 80, 7)
	c.draw_rect(bar, Color8(232, 232, 232))
	var done := clampf(float(now - int(run["from_h"])) / float(maxi(1, int(run["to_h"]) - int(run["from_h"]))), 0.0, 1.0)
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * (1.0 - done)), bar.size.y)), GREEN)
	c.draw_rect(bar, Color8(160, 160, 160), false, 1.0)


## A sketch of the page the kind is shown on: Atlas's black head and red bar, the red
## where the camp goes.
func _draw_where(c: Control, kind: String, r: Rect2) -> void:
	c.draw_rect(r, T.WHITE)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), BLACK)
	c.draw_rect(Rect2(r.position + Vector2(0, 7), Vector2(r.size.x, 3)), RED)
	var x := r.position.x + 4
	var y := r.position.y + 13
	var iw := r.size.x - 8
	match kind:
		"listing":
			c.draw_rect(Rect2(x - 1, y - 1, iw + 2, 6), PALE)
			c.draw_rect(Rect2(x, y, 5, 4), RED)
			c.draw_rect(Rect2(x + 7, y + 1, iw - 18, 2), LINK)
			for k in 5:
				c.draw_rect(Rect2(x + 7, y + 8 + k * 5, iw - 14 - (k % 2) * 8, 2), Color8(170, 170, 170))
		"travel":
			c.draw_rect(Rect2(x, y, iw, 9), Color8(30, 112, 58))
			c.draw_rect(Rect2(x, y, iw, 9), RED, false, 1.0)
			for k in 4:
				c.draw_rect(Rect2(x, y + 13 + k * 5, iw - (k % 2) * 10, 2), Color8(170, 170, 170))
		_:
			c.draw_rect(Rect2(x + 4, y, iw - 8, 9), Color8(30, 112, 58))
			c.draw_rect(Rect2(x + 4, y, iw - 8, 9), RED, false, 1.0)
			for k in 6:
				c.draw_rect(Rect2(x + float(k % 3) * (iw / 3.0), y + 14 + float(k / 3) * 8, iw / 3.0 - 4, 2), LINK)
	c.draw_rect(r, Color8(150, 150, 150), false, 1.0)


# ── the camp's page ──────────────────────────────────────────────────────────

## The place: the name, the average, the stars, the bars; the banner; the partner box.
func _draw_place(c: Control, g, r: Rect2) -> void:
	var day := _day()
	var x := r.position.x
	var y := r.position.y + 4
	_text(c, T.FONT_BOLD, Vector2(x, y + 12), _camp_name(), T.TEXT, 14)
	_text(c, T.FONT, Vector2(x, y + 27), tr("Campground  -  Hlubocany"), GREY)
	y += 36
	var n: int = g.count()
	var rating: float = g.rating(day)
	if n == 0:
		_text(c, T.FONT, Vector2(x, y + 22), tr("No reviews yet."), GREY)
		y += 34
	else:
		_text(c, T.FONT_BOLD, Vector2(x, y + 30), "%.1f" % rating, T.TEXT, 32)
		_draw_stars(c, Vector2(x + 58, y + 8), rating, 16)
		_text(c, T.FONT, Vector2(x + 58, y + 38), LANG.f("%d review%s", [n, "" if n == 1 else "s"]), LINK)
		y += 46
		var hist: Array = g.histogram()
		var top_n := 1
		for k in range(1, 6):
			top_n = maxi(top_n, int(hist[k]))
		for k in range(5, 0, -1):
			_text(c, T.FONT, Vector2(x, y + 10), str(k), GREY)
			var bar := Rect2(x + 12, y + 2, r.size.x - 40, 9)
			c.draw_rect(bar, Color8(236, 236, 236))
			c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * float(hist[k]) / float(top_n)), bar.size.y)), RED)
			_text(c, T.FONT, Vector2(bar.end.x + 4, y + 10), str(hist[k]), GREY)
			y += 13
	if g.flagged(day):
		y += 4
		var fr := Rect2(x, y, r.size.x, 30)
		c.draw_rect(fr, Color8(255, 236, 236))
		c.draw_rect(Rect2(fr.position, Vector2(3, fr.size.y)), RED)
		_text(c, T.FONT_BOLD, Vector2(x + 8, y + 13), tr("Unusual review activity"), RED)
		_text(c, T.FONT, Vector2(x + 8, y + 26), tr("on this listing has been detected."), RED)
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
	_text(c, T.FONT_BOLD, Vector2(tx, ty + 17), tr("Bad review?"), Color8(200, 0, 0) if blink else Color8(0, 0, 160))
	_text(c, T.FONT_BOLD, Vector2(tx, ty + 32), tr("GONE by"), T.TEXT)
	_text(c, T.FONT_BOLD, Vector2(tx, ty + 45), tr("morning!"), T.TEXT)
	_text(c, T.FONT, Vector2(tx, ty + 61), "SpotlessName Ltd", Color8(0, 0, 140))
	_text(c, T.FONT, Vector2(tx, ty + 74), LANG.f("from $%d", int(g.removal_cost())), T.TEXT)
	_text(c, T.FONT, Vector2(tx, ty + 88), tr("Discreet. Fast. Legal*"), Color8(60, 60, 60), 10)


## Stavitel software's partner programme: what the next guests open in Builder 98.
func _draw_partner(c: Control, g, r: Rect2) -> void:
	var nt: Dictionary = g.next_tier()
	c.draw_style_box(T.box("field", Color8(255, 252, 230), Vector4.ZERO), r)
	var x := r.position.x + 6
	var y := r.position.y + 14
	_text(c, T.FONT_BOLD, Vector2(x, y), tr("Builder 98 partner camps"), Color8(120, 70, 0))
	y += 15
	if nt.is_empty():
		_text(c, T.FONT, Vector2(x, y), tr("Every blueprint is yours."), T.TEXT)
		return
	var pad: Texture2D = _art.get(PADLOCK)
	_text(c, T.FONT_BOLD, Vector2(x, y), LANG.f("%d guests in the camp", int(nt["guests"])), T.TEXT)
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
		_text(c, T.FONT, Vector2(ix + 15, iy), tr(str(NAMES.get(str(items[i]), str(items[i])))), T.TEXT)


## The reviews: the sorts and Photos as the 90s had them (words, the one on bold), a page
## of them, the pages.
func _draw_reviews(c: Control, g, r: Rect2) -> void:
	var day := _day()
	var x := r.position.x
	var y := r.position.y + 4
	_text(c, T.FONT_BOLD, Vector2(x, y + 12), tr("Reviews"), T.TEXT, 14)
	var tx := x + T.FONT_BOLD.get_string_size(tr("Reviews"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14
	var tabs := [["sort:newest", "Newest", _part == "reviews" and _sort == "newest"], ["sort:lowest", "Lowest", _part == "reviews" and _sort == "lowest"],
		["sort:highest", "Highest", _part == "reviews" and _sort == "highest"], ["part:photos", "Photos", _part == "photos"]]
	for i in tabs.size():
		var t: Array = tabs[i]
		if i > 0:
			_text(c, T.FONT, Vector2(tx, y + 12), "|", Color8(170, 170, 170))
			tx += 12
		var label := tr(str(t[1]))
		if bool(t[2]):
			_text(c, T.FONT_BOLD, Vector2(tx, y + 12), label, T.TEXT)
			tx += T.FONT_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 8
		else:
			tx = _link(c, T.FONT, Vector2(tx, y + 12), label, str(t[0])) + 8
	if _notice_on():
		_text(c, T.FONT_BOLD, Vector2(tx + 10, y + 12), _notice, _notice_col)
	y += 22
	c.draw_rect(Rect2(x, y - 4, r.size.x, 1), RULE)
	if _part == "photos":
		_draw_photos(c, Rect2(x, y + 2, r.size.x, r.end.y - y - 2))
		return
	var list: Array = g.shown()
	match _sort:
		"lowest":
			list.sort_custom(func(a, b): return int(a["stars"]) < int(b["stars"]) or (int(a["stars"]) == int(b["stars"]) and int(a["day"]) > int(b["day"])))
		"highest":
			list.sort_custom(func(a, b): return int(a["stars"]) > int(b["stars"]) or (int(a["stars"]) == int(b["stars"]) and int(a["day"]) > int(b["day"])))
	var pages := maxi(1, ceili(float(list.size()) / PER_PAGE))
	_page = clampi(_page, 0, pages - 1)
	var card_h := (r.end.y - y - 26.0) / PER_PAGE
	for i in range(_page * PER_PAGE, mini(list.size(), (_page + 1) * PER_PAGE)):
		_draw_card(c, g, list[i], Rect2(x, y, r.size.x, card_h - 4), day)
		y += card_h
	if list.is_empty():
		_text(c, T.FONT, Vector2(x, y + 14), tr("Be the first to review this place."), GREY)
	_draw_pages(c, Rect2(x, r.end.y - 22, r.size.x, 20), pages)


func _draw_card(c: Control, g, e: Dictionary, r: Rect2, day: int) -> void:
	var x := r.position.x
	var y := r.position.y
	var face := _face(str(e["archetype"]))
	if face != null:
		c.draw_texture_rect(face, Rect2(x, y + 2, 28, 28), false)
	c.draw_rect(Rect2(x, y + 2, 28, 28), Color8(180, 180, 180), false, 1.0)
	var tx := x + 36.0
	_text(c, T.FONT_BOLD, Vector2(tx, y + 12), tr(str(e["name"]), "reviewer"), LINK)
	var helpful := int(e.get("helpful", 0))
	if helpful > 0:
		var ht := LANG.f("%d found this helpful", helpful)
		var hw := T.FONT.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_text(c, T.FONT, Vector2(r.end.x - hw - 2, y + 12), ht, GREY, 10)
	_draw_stars(c, Vector2(tx, y + 16), float(e["stars"]), 11)
	_text(c, T.FONT, Vector2(tx + 64, y + 26), _when(int(e["day"]), day) + (tr("  (edited)") if bool(e.get("edited", false)) and str(e["text"]).contains("EDIT:") else ""), GREY)
	var ty := y + 42.0
	var lines := _wrap(_review_text(str(e["text"])), r.size.x - 40.0)
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
		var resp := tr("Response from the owner")
		_text(c, T.FONT_BOLD, Vector2(tx + 6, ty), resp, GREY, 10)
		var ow := T.FONT_BOLD.get_string_size(resp, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var own := tr("Owner")
		var own_w := T.FONT_BOLD.get_string_size(own, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 6
		c.draw_rect(Rect2(tx + 12 + ow, ty - 9, own_w, 11), BLACK)
		_text(c, T.FONT_BOLD, Vector2(tx + 15 + ow, ty), own, T.WHITE, 10)
		_text(c, T.FONT, Vector2(tx + 6, ty + 12), _wrap(tr(ans), r.size.x - 50.0)[0], Color8(70, 70, 70))
		ty += 26
	# What you can do about it.
	var by := r.end.y - 18.0
	var bx := tx
	if int(e["removing"]) >= 0:
		_chip(c, Vector2(bx, by), tr("Removal booked: gone by morning"), Color8(0, 110, 140))
	elif bool(e["flagged"]):
		_chip(c, Vector2(bx, by), tr("Reported to Atlas"), RED)
	else:
		if str(e["reply"]) == "" and str(e.get("ghost_reply", "")) == "":
			bx = _button(c, Vector2(bx, by), tr("Reply"), "reply:%d" % int(e["id"])) + 4
		if int(e["stars"]) <= 3:
			bx = _button(c, Vector2(bx, by), LANG.f("Remove  $%d", int(g.removal_cost())), "remove:%d" % int(e["id"])) + 4
	if _replying == int(e["id"]):
		bx = _button(c, Vector2(bx + 8, by), tr("Apologise"), "answer:%d:sorry" % int(e["id"])) + 4
		_button(c, Vector2(bx, by), tr("Blame the weather"), "answer:%d:weather" % int(e["id"]))
	c.draw_rect(Rect2(x, r.end.y + 1, r.size.x, 1), Color8(236, 236, 236))


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
		_text(c, T.FONT, Vector2(br.position.x, br.end.y + 14), LANG.f("Photo by %s  -  a year ago", str(ph[1])), GREY)
		var bx := br.end.x - 70.0
		if _photo > 0:
			_button(c, Vector2(bx, br.end.y + 3), "<", "photo:%d" % (_photo - 1))
		if _photo < PHOTOS.size() - 1:
			_button(c, Vector2(bx + 30, br.end.y + 3), ">", "photo:%d" % (_photo + 1))
		return
	for i in PHOTOS.size():
		var ph: Array = PHOTOS[i]
		var pr := Rect2(x + float(i % 3) * (tw + gap), y + float(i / 3) * (th + 20.0), tw, th)
		var tex: Texture2D = _photos.get(PHOTO_DIR + "%d_t.png" % int(ph[0]))
		if tex != null:
			c.draw_texture_rect(tex, pr, false)
		c.draw_rect(pr, RED if _hover == "photo:%d" % i else Color8(200, 200, 200), false, 1.0)
		_hits.append([pr, "photo:%d" % i])
		_text(c, T.FONT, Vector2(pr.position.x, pr.end.y + 12), str(ph[1]), GREY, 10)
	y += (th + 20.0) * 2.0 + 4.0
	_text(c, T.FONT_BOLD, Vector2(x, y + 12), tr("People also searched for"), T.TEXT)
	y += 20
	var aw := r.size.x / float(ALSO.size())
	for i in ALSO.size():
		var a: Array = ALSO[i]
		var ax := x + float(i) * aw
		if str(a[4]) != "":
			_link(c, T.FONT_BOLD, Vector2(ax, y + 11), str(a[0]), "also:%d" % i)
		else:
			_text(c, T.FONT_BOLD, Vector2(ax, y + 11), str(a[0]), T.TEXT)
		_draw_stars(c, Vector2(ax, y + 16), float(a[2]), 9)
		_text(c, T.FONT, Vector2(ax + 52, y + 25), "%.1f (%d)" % [float(a[2]), int(a[3])], GREY, 10)
		_text(c, T.FONT, Vector2(ax, y + 38), tr(str(a[1])), GREY, 10)


## The pages as a directory of 1998 had them: << Previous  1 2 3  Next >>, the one shown
## bold, the rest links.
func _draw_pages(c: Control, r: Rect2, pages: int) -> void:
	if pages <= 1:
		return
	var parts: Array = []
	if _page > 0:
		parts.append([tr("<< Previous"), "page:%d" % (_page - 1)])
	for i in pages:
		parts.append([str(i + 1), "" if i == _page else "page:%d" % i])
	if _page < pages - 1:
		parts.append([tr("Next >>"), "page:%d" % (_page + 1)])
	var total := 0.0
	for p in parts:
		total += T.FONT_BOLD.get_string_size(str(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 10
	var x := r.position.x + floorf((r.size.x - total + 10) * 0.5)
	var y := r.position.y + 14
	for p in parts:
		if str(p[1]) == "":
			_text(c, T.FONT_BOLD, Vector2(x, y), str(p[0]), T.TEXT)
			x += T.FONT_BOLD.get_string_size(str(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 10
		else:
			x = _link(c, T.FONT, Vector2(x, y), str(p[0]), str(p[1])) + 10


# ── bits ─────────────────────────────────────────────────────────────────────

func _notice_on() -> bool:
	return _notice != "" and Time.get_ticks_msec() / 1000.0 < _notice_until


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


## A link: red and underlined, black under the pointer. Returns where it ends.
func _link(c: Control, f: Font, at: Vector2, s: String, action: String) -> float:
	var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var col := T.TEXT if _hover == action else LINK
	_text(c, f, at, s, col)
	c.draw_rect(Rect2(at.x, at.y + 2, sw, 1), col)
	_hits.append([Rect2(at.x - 1, at.y - 11, sw + 2, 15), action])
	return at.x + sw


func _button(c: Control, at: Vector2, label: String, action: String, min_w := 0.0, h := 17.0) -> float:
	var w := maxf(min_w, T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 14)
	var r := Rect2(at, Vector2(w, h))
	var hov := _hover == action
	c.draw_style_box(T.box("raised", Color8(236, 214, 214) if hov else T.FACE, Vector4.ZERO), r)
	var lw := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	_text(c, T.FONT, Vector2(at.x + floorf((w - lw) * 0.5), at.y + r.size.y - 5), label, T.TEXT)
	_hits.append([r, action])
	return r.end.x


func _chip(c: Control, at: Vector2, label: String, col: Color) -> void:
	var w := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 12
	c.draw_rect(Rect2(at, Vector2(w, 16)), col)
	_text(c, T.FONT, Vector2(at.x + 6, at.y + 12), label, T.WHITE)


func _text(c: Control, f: Font, at: Vector2, s: String, col: Color, fs: int = T.FONT_SIZE) -> void:
	c.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	drawn_chars += s.length()


## 41237 -> "41,237" (in Czech "41 237").
func _num(v: int) -> String:
	var s := LANG.group_thousands(v)
	return s if LANG.is_czech() else s.replace(" ", ",")


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
		return tr("a year ago")
	var ago := today - d
	if ago <= 0:
		return tr("today")
	if ago == 1:
		return tr("yesterday")
	if ago < 7:
		return LANG.f("%d days ago", ago)
	return LANG.f("%d weeks ago", ago / 7)


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


## A review in the player's language: an apology's EDIT (goggle.gd) added to the end of
## its text, each half translated on its own.
func _review_text(text: String) -> String:
	var at := text.find(" EDIT: ")
	if at < 0:
		return tr(text)
	return tr(text.substr(0, at)) + tr(text.substr(at))
