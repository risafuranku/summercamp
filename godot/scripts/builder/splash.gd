extends Control

## Builder 98's title window while it loads (S9, the playtest of 30. 10.: "the Builder's
## loading screen is awful AI slop; we want something that looks like a real program from
## the nineties"). It was a painted picture of a camp at sunset over the whole window; now
## it is what a 1998 shareware program put up as it started: a small window in the middle
## of the desktop with nothing round it, drawn here in the system's own fonts and colours
## (os_theme.gd). On the left a blueprint, the site plan of a camp in white lines on a
## blue grid (the lake and its jetty, the path, cabins, tents, trees, the fire, a north
## arrow, a dimension, the title block); on the right the program's icon, the maker,
## "Builder 98" big, what it is for and its version, who the copy is registered to (or the
## shareware's trial days), the copyright, and at the bottom what it is loading now over
## the system's progress bar. Made by builder_module._build_splash; it sets `t`.

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const PROGRESS = preload("res://scripts/os98/os_progress.gd")
const ICON := "res://assets/textury/os98/icons/builder.png"
const CARD := Vector2(448, 288)
const PLAN_W := 176.0
const BLUE := Color8(18, 52, 122)
const GRID := Color8(34, 74, 148)
const GRID_BIG := Color8(58, 100, 174)
const INK := Color8(222, 236, 255)
const WATER := Color8(120, 160, 222)
const RED := Color8(192, 0, 0)

## Seconds since it came up, of `total`; what it says it is doing, a line a quarter.
var t := 0.0
var total := 2.2
var lines: Array = []
var registered := false
var serial := ""
var licensee := ""
var days_left := 30

var _bar
var _icon: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = load(ICON) if ResourceLoader.exists(ICON) else null
	_bar = PROGRESS.new("blocks")
	add_child(_bar)
	resized.connect(_place_bar)
	_place_bar()


func _process(_delta: float) -> void:
	if _bar != null:
		_bar.value = clampf(t / (total * 0.9), 0.0, 1.0)
	queue_redraw()


func _card() -> Rect2:
	return Rect2(((size - CARD) * 0.5).floor(), CARD)


func _place_bar() -> void:
	if _bar == null:
		return
	var c := _card()
	_bar.position = c.position + Vector2(PLAN_W + 14, CARD.y - 24)
	_bar.size = Vector2(CARD.x - PLAN_W - 28, 12)


func _draw() -> void:
	# The desktop round it: the program's own window is not up yet.
	draw_rect(Rect2(Vector2.ZERO, size), T.DESKTOP)
	var c := _card()
	draw_rect(c, T.WHITE)
	_plan(Rect2(c.position, Vector2(PLAN_W, CARD.y)))
	_text(Rect2(c.position + Vector2(PLAN_W, 0), Vector2(CARD.x - PLAN_W, CARD.y)))
	# A black line round it and the bevel inside, the way borderless windows were.
	draw_rect(c.grow(1), T.DARK, false)
	draw_line(c.position + Vector2(0.5, 0.5), c.position + Vector2(c.size.x - 0.5, 0.5), T.WHITE)
	draw_line(c.position + Vector2(0.5, 0.5), c.position + Vector2(0.5, c.size.y - 0.5), T.WHITE)
	draw_line(c.position + Vector2(0.5, c.size.y - 0.5), c.end - Vector2(0.5, 0.5), T.SHADOW)
	draw_line(c.position + Vector2(c.size.x - 0.5, 0.5), c.end - Vector2(0.5, 0.5), T.SHADOW)


# ── the blueprint ─────────────────────────────────────────────────────────────

func _plan(r: Rect2) -> void:
	draw_rect(r, BLUE)
	var o := r.position
	for x in range(8, int(r.size.x), 8):
		draw_line(o + Vector2(x + 0.5, 0), o + Vector2(x + 0.5, r.size.y), GRID_BIG if x % 32 == 0 else GRID)
	for y in range(8, int(r.size.y), 8):
		draw_line(o + Vector2(0, y + 0.5), o + Vector2(r.size.x, y + 0.5), GRID_BIG if y % 32 == 0 else GRID)
	# The drawing's frame and its title block.
	_box(o, Rect2(6, 6, 164, 276))
	_box(o, Rect2(6, 254, 164, 28))
	_line(o, Vector2(118, 254), Vector2(118, 282))
	draw_string(T.FONT, o + Vector2(12, 272), tr("SITE PLAN"), HORIZONTAL_ALIGNMENT_LEFT, 104, T.FONT_SIZE, INK)
	draw_string(T.FONT, o + Vector2(124, 272), "1:500", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, INK)
	# The lake, its water lines and the jetty.
	_poly(o, [Vector2(100, 14), Vector2(130, 10), Vector2(158, 16), Vector2(165, 40), Vector2(160, 70), Vector2(140, 88), Vector2(118, 86), Vector2(104, 72), Vector2(96, 50), Vector2(98, 28)], true)
	for w in [[110, 124, 26], [134, 150, 26], [106, 118, 38], [128, 156, 38], [112, 132, 50], [140, 156, 50], [118, 146, 62], [124, 140, 74]]:
		draw_line(o + Vector2(w[0], w[2] + 0.5), o + Vector2(w[1], w[2] + 0.5), WATER)
	_box(o, Rect2(100, 55, 18, 5))
	# The path up from the gate to the shore, a branch to the cabins.
	var path := [Vector2(62, 254), Vector2(64, 230), Vector2(72, 208), Vector2(86, 190), Vector2(98, 168), Vector2(104, 140), Vector2(108, 112), Vector2(114, 88)]
	_poly(o, path.map(func(p: Vector2) -> Vector2: return p + Vector2(-3, 0)), false)
	_poly(o, path.map(func(p: Vector2) -> Vector2: return p + Vector2(3, 0)), false)
	_poly(o, [Vector2(85, 176), Vector2(64, 166), Vector2(46, 162)], false)
	_poly(o, [Vector2(89, 182), Vector2(66, 172), Vector2(46, 168)], false)
	# Cabins (their ridges), tents (a cross in a diamond), the fire and its benches.
	for b in [Rect2(20, 156, 26, 16), Rect2(16, 118, 26, 16), Rect2(122, 170, 26, 16)]:
		_box(o, b)
		_line(o, Vector2(b.position.x, b.get_center().y), Vector2(b.end.x, b.get_center().y))
	for p in [Vector2(134, 118), Vector2(150, 136), Vector2(140, 206), Vector2(126, 226)]:
		_poly(o, [p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)], true)
		_line(o, p + Vector2(-3, 0), p + Vector2(3, 0))
		_line(o, p + Vector2(0, -3), p + Vector2(0, 3))
	var fire := Vector2(64, 120)
	draw_arc(o + fire, 5.0, 0.0, TAU, 12, INK)
	_line(o, fire + Vector2(-2, 0), fire + Vector2(2, 0))
	_line(o, fire + Vector2(0, -2), fire + Vector2(0, 2))
	for a in 4:
		var d := Vector2.RIGHT.rotated(a * PI * 0.5 + PI * 0.25) * 11.0
		var s := d.orthogonal().normalized() * 3.0
		_line(o, fire + d - s, fire + d + s)
	# Trees: a ring and its trunk's dot.
	for p in [Vector2(40, 22), Vector2(58, 16), Vector2(78, 26), Vector2(22, 46), Vector2(44, 48), Vector2(80, 58), Vector2(20, 82), Vector2(152, 104), Vector2(158, 164), Vector2(156, 236), Vector2(30, 204), Vector2(18, 222), Vector2(88, 92)]:
		draw_arc(o + p, 5.0, 0.0, TAU, 10, INK)
		draw_rect(Rect2(o + p, Vector2.ONE), INK)
	# North: an arrow in a ring, the top-left corner.
	var n := Vector2(20, 22)
	draw_arc(o + n, 8.0, 0.0, TAU, 14, INK)
	draw_colored_polygon(PackedVector2Array([o + n + Vector2(0, -7), o + n + Vector2(3, 5), o + n + Vector2(0, 2)]), INK)
	_poly(o, [n + Vector2(0, -7), n + Vector2(-3, 5), n + Vector2(0, 2)], false)
	# A dimension along the bottom left, clear of the path: the extension lines, the
	# ticks, the length over it.
	var y := 246.0
	_line(o, Vector2(10, y - 8), Vector2(10, y + 3))
	_line(o, Vector2(52, y - 8), Vector2(52, y + 3))
	_line(o, Vector2(10, y), Vector2(52, y))
	_line(o, Vector2(7, y + 3), Vector2(13, y - 3))
	_line(o, Vector2(49, y + 3), Vector2(55, y - 3))
	draw_string(T.FONT, o + Vector2(20, y - 3), "40 m", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, INK)


func _line(o: Vector2, a: Vector2, b: Vector2) -> void:
	draw_line(o + a + Vector2(0.5, 0.5), o + b + Vector2(0.5, 0.5), INK)


func _box(o: Vector2, r: Rect2) -> void:
	draw_rect(Rect2(o + r.position + Vector2(0.5, 0.5), r.size), INK, false)


func _poly(o: Vector2, pts: Array, closed: bool) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(o + (v as Vector2) + Vector2(0.5, 0.5))
	if closed:
		p.append(p[0])
	draw_polyline(p, INK)


# ── the words ─────────────────────────────────────────────────────────────────

func _text(r: Rect2) -> void:
	var x := r.position.x + 14.0
	var w := r.size.x - 28.0
	var y0 := r.position.y
	if _icon != null:
		draw_texture_rect(_icon, Rect2(x, y0 + 14, 32, 32), false)
	draw_string(T.FONT_BOLD, Vector2(x + 40, y0 + 34), "STAVITEL SOFTWARE", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.NAVY)
	# The name big, a grey shadow under it, "98" in red; a navy rule, a red one.
	var big := T.FONT_SIZE * 3
	var name_w := T.FONT_BOLD.get_string_size("Builder", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	for k in [[Vector2(2, 2), T.LIGHT, T.LIGHT], [Vector2.ZERO, T.NAVY, RED]]:
		var at := Vector2(x, y0 + 88) + (k[0] as Vector2)
		draw_string(T.FONT_BOLD, at, "Builder", HORIZONTAL_ALIGNMENT_LEFT, -1, big, k[1])
		draw_string(T.FONT_BOLD, at + Vector2(name_w + 10, 0), "98", HORIZONTAL_ALIGNMENT_LEFT, -1, big, k[2])
	draw_rect(Rect2(x, y0 + 96, w, 2), T.NAVY)
	draw_rect(Rect2(x, y0 + 100, 96, 1), RED)
	_say(tr("Site planning for recreational facilities"), x, y0 + 120, w, T.TEXT)
	_say(LANG.f("Version %s for Okna 98", ["1.2"]), x, y0 + 136, w, T.TEXT)
	# An etched line, then who it is for.
	draw_rect(Rect2(x, y0 + 148, w, 1), T.SHADOW)
	draw_rect(Rect2(x, y0 + 149, w, 1), T.WHITE)
	if registered:
		_say(tr("Registered to:"), x, y0 + 168, w, T.TEXT)
		_say(licensee, x, y0 + 184, w, T.TEXT, true)
		_say(LANG.f("Serial No. %s", [serial]), x, y0 + 200, w, T.SHADOW)
	else:
		_say(tr("UNREGISTERED SHAREWARE"), x, y0 + 168, w, RED, true)
		_say(LANG.f("Trial copy: %d days left", [days_left]), x, y0 + 184, w, T.TEXT)
		_say(tr("To register: Help > Register..."), x, y0 + 200, w, T.SHADOW)
	_say("(c) 1996-98 Stavitel software, Jihlava.", x, y0 + 222, w, T.SHADOW)
	_say(tr("All rights reserved."), x, y0 + 236, w, T.SHADOW)
	if not lines.is_empty():
		var line: String = lines[clampi(int(t / total * lines.size()), 0, lines.size() - 1)]
		_say(tr(line), x, y0 + CARD.y - 30, w, T.TEXT)


func _say(s: String, x: float, y: float, w: float, col: Color, bold := false) -> void:
	draw_string(T.FONT_BOLD if bold else T.FONT, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, w, T.FONT_SIZE, col)
