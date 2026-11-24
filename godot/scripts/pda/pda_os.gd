extends Control

## "Okna CE" (Richard 24. 11., docs/player.md "PDA se stylusem"): the palmtop's own little
## system on its grey-green STN screen, in the spirit of the office's Okna 98: a title bar with
## the time, the apps' icons on the home screen (Grok's 1-bit pictures,
## tools/artgen/pda_art.py), the bar at the bottom with the window logo that takes you home.
## One app at a time; each draws itself with the helpers here (scripts/pda/apps/*.gd).
##
## Drawn in the screen's own pixels (`lcd`: 104 x 240 at 720p, wider and taller on bigger
## windows: scripts/pda/pda.gd scales the node by whole pixels); the stylus is the mouse.
## At night the backlight is on (`lit` 0..1). Nothing animates while nothing changes: the node
## redraws on a change, a blink or an app's own clock (`wants_tick`).

const INSTANCE = preload("res://scripts/instance/instance.gd")
const SHAPES = preload("res://scripts/ui/retro_ui_shapes.gd")
const ICONS := "res://assets/textury/pda/icons.png"
const ICON := 32
const LOGO := "res://assets/textury/pda/logo.png"
const FONT: FontFile = preload("res://assets/fonts/tiny5.fnt")
const FONT_SIZE := 8
const LINE := 9
## The STN glass, unlit and backlit, and its ink (a 1998 palmtop: dark grey-green letters).
const GLASS := Color8(150, 163, 116)
const GLASS_LIT := Color8(128, 196, 118)
const INK := Color8(30, 38, 22)
const INK_LIT := Color8(16, 44, 20)
const BAR_H := 11
const TASK_H := 12
const BLINK_SEC := 0.5

## The apps in the order of their icons on the sheet.
const APPS := [
	["map", "Site plan", "res://scripts/pda/apps/map_app.gd"],
	["inbox", "Messages", "res://scripts/pda/apps/inbox_app.gd"],
	["tasks", "Tasks", "res://scripts/pda/apps/tasks_app.gd"],
	["clock", "Clock", "res://scripts/pda/apps/clock_app.gd"],
	["snake", "Snake", "res://scripts/pda/apps/snake_app.gd"],
]

var main: Node
## The screen's size in its own pixels.
var lcd := Vector2i(104, 240)
## 0 the glass as it is, 1 the backlight full on.
var lit := 0.0
## The app on the screen ("" the home screen).
var app := ""
var _apps: Dictionary = {}
var _icons: Texture2D
var _logo: Texture2D
var _hits: Array = []
var _down := ""
var _hover := ""
var _blink_t := 0.0
var _blink_on := true
var _sounds: Callable = Callable()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	if ResourceLoader.exists(ICONS):
		_icons = load(ICONS)
	if ResourceLoader.exists(LOGO):
		_logo = load(LOGO)
	for a in APPS:
		var inst = load(str(a[2])).new()
		inst.os = self
		_apps[str(a[0])] = inst


## `play(name)`: the device's clicks and beeps (pda.gd).
func set_sounds(play: Callable) -> void:
	_sounds = play


func play(sound: String) -> void:
	if _sounds.is_valid():
		_sounds.call(sound)


func app_node(id: String):
	return _apps.get(id, null)


func open_app(id: String) -> void:
	app = id if _apps.has(id) else ""
	if app != "":
		_apps[app].opened()
	queue_redraw()


func go_home() -> void:
	if app != "" and _apps.has(app):
		_apps[app].closed()
	app = ""
	queue_redraw()


## Each frame while the device is up (pda.gd): the blink, the app's own clock.
func tick(delta: float) -> void:
	_blink_t += delta
	if _blink_t >= BLINK_SEC:
		_blink_t = 0.0
		_blink_on = not _blink_on
		queue_redraw()
	if app != "" and _apps[app].wants_tick():
		_apps[app].tick(delta)
		queue_redraw()


func blink() -> bool:
	return _blink_on


# ── colours ──────────────────────────────────────────────────────────────────

func glass() -> Color:
	return GLASS.lerp(GLASS_LIT, lit)


func ink() -> Color:
	return INK.lerp(INK_LIT, lit)


## The ink at half: what is greyed out, the grid of a page.
func mid() -> Color:
	return glass().lerp(ink(), 0.45)


# ── drawing helpers (the apps draw with these) ───────────────────────────────

func text(x: float, y_top: float, s: String, col := Color(0, 0, 0, 0)) -> void:
	draw_string(FONT, Vector2(roundf(x), roundf(y_top) + 7.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ink() if col.a <= 0.0 else col)


func text_w(s: String) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x


## `s` in `r`, centred.
func text_c(r: Rect2, s: String, col := Color(0, 0, 0, 0)) -> void:
	text(r.position.x + floorf((r.size.x - text_w(s)) * 0.5), r.position.y + floorf((r.size.y - 8.0) * 0.5), s, col)


func text_r(x_right: float, y_top: float, s: String, col := Color(0, 0, 0, 0)) -> void:
	text(x_right - text_w(s), y_top, s, col)


## `s` cut to `width` with "..." when it does not fit.
func clip(s: String, width: float) -> String:
	if text_w(s) <= width:
		return s
	var out := s
	while out.length() > 1 and text_w(out + "..") > width:
		out = out.left(out.length() - 1)
	return out + ".."


## `s` in lines of at most `width` (words kept whole where they fit).
func wrap(s: String, width: float) -> Array:
	var lines: Array = []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var cand := word if line == "" else line + " " + word
			if text_w(cand) <= width:
				line = cand
				continue
			if line != "":
				lines.append(line)
			line = word
			while text_w(line) > width and line.length() > 1:
				var cut := line.length() - 1
				while cut > 1 and text_w(line.left(cut)) > width:
					cut -= 1
				lines.append(line.left(cut))
				line = line.substr(cut)
		lines.append(line)
	return lines


func frame(r: Rect2, col := Color(0, 0, 0, 0)) -> void:
	draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), ink() if col.a <= 0.0 else col, false, 1.0)


func fill(r: Rect2, col := Color(0, 0, 0, 0)) -> void:
	draw_rect(r, ink() if col.a <= 0.0 else col)


func hline(x0: float, x1: float, y: float, col := Color(0, 0, 0, 0)) -> void:
	fill(Rect2(x0, y, x1 - x0, 1), col)


## A button: framed, its label inverted while the stylus is down on it; greyed when it
## cannot be pressed.
func button(r: Rect2, label: String, id: String, enabled := true) -> void:
	var pressed := enabled and _down == id and _hover == id
	# (Their corners a pixel round, as every highlight's: Richard 24. 11.)
	if pressed:
		SHAPES.round1_fill(self, r, 1.0, ink())
		text_c(r, label, glass())
	else:
		SHAPES.round1_edge(self, r, 1.0, ink() if enabled else mid())
		text_c(r, label, ink() if enabled else mid())
	if enabled:
		hit(id, r)


func hit(id: String, r: Rect2) -> void:
	_hits.append([id, r])


## Icon `i` of the sheet at `at` (its top left), in the ink.
func icon(i: int, at: Vector2) -> void:
	if _icons == null:
		return
	draw_texture_rect_region(_icons, Rect2(at, Vector2(ICON, ICON)), Rect2(i * ICON, 0, ICON, ICON), ink())


## The work area between the title bar and the task bar.
func work() -> Rect2:
	return Rect2(0, BAR_H, lcd.x, lcd.y - BAR_H - TASK_H)


# ── the screen ───────────────────────────────────────────────────────────────

func _draw() -> void:
	_hits.clear()
	fill(Rect2(Vector2.ZERO, Vector2(lcd)), glass())
	var title := "Okna CE"
	if app != "":
		title = tr(_app_name(app))
	# The title bar: inverted, the time at its right.
	fill(Rect2(0, 0, lcd.x, BAR_H))
	var t := clock_text()
	text(2, 2, clip(title, lcd.x - text_w(t) - 8), glass())
	text_r(lcd.x - 2, 2, t, glass())
	if app == "":
		_draw_home(work())
	else:
		_apps[app].draw(work())
	_draw_taskbar()


func _draw_taskbar() -> void:
	var y := lcd.y - TASK_H
	hline(0, lcd.x, y)
	var start := Rect2(1, y + 2, 13, TASK_H - 3)
	if _logo != null:
		draw_texture_rect(_logo, Rect2(start.position + Vector2(1, 0), Vector2(12, 9)), false, ink())
	if _down == "home" and _hover == "home":
		draw_rect(start, Color(ink(), 0.35))
	hit("home", start)
	# The messages not read yet, as the office's tray shows the post.
	var unread: int = _apps["inbox"].unread()
	var right := lcd.x - 2.0
	if unread > 0:
		var s := "%d" % unread
		var r := Rect2(right - text_w(s) - 13, y + 2, text_w(s) + 13, TASK_H - 3)
		if blink():
			fill(r)
			_envelope(Vector2(r.position.x + 2, y + 4), glass())
			text(r.position.x + 11, y + 2, s, glass())
		else:
			frame(r)
			_envelope(Vector2(r.position.x + 2, y + 4), ink())
			text(r.position.x + 11, y + 2, s)
		hit("app:inbox", r)
		right = r.position.x - 3
	if app != "":
		text(17, y + 2, clip(tr(_app_name(app)), right - 19))


## A little envelope, 7 x 5 (the tray's mark for unread messages).
func _envelope(at: Vector2, col: Color) -> void:
	draw_rect(Rect2(at + Vector2(0.5, 0.5), Vector2(7, 5)), col, false, 1.0)
	draw_line(at + Vector2(1, 1), at + Vector2(4, 3), col, 1.0)
	draw_line(at + Vector2(7, 1), at + Vector2(4, 3), col, 1.0)


func _draw_home(r: Rect2) -> void:
	var cols := maxi(2, int(r.size.x / 46.0))
	var cw := floorf(r.size.x / float(cols))
	var ch := float(ICON + LINE + 6)
	var top := r.position.y + 6
	for i in APPS.size():
		var id := str(APPS[i][0])
		var cell := Rect2(r.position.x + float(i % cols) * cw, top + float(i / cols) * ch, cw, ch)
		var at := Vector2(cell.position.x + floorf((cw - ICON) * 0.5), cell.position.y)
		var pressed := _down == "app:" + id and _hover == "app:" + id
		if pressed:
			fill(Rect2(at - Vector2(2, 2), Vector2(ICON + 4, ICON + 4)))
			if _icons != null:
				draw_texture_rect_region(_icons, Rect2(at, Vector2(ICON, ICON)), Rect2(i * ICON, 0, ICON, ICON), glass())
		else:
			icon(i, at)
		var label := clip(tr(str(APPS[i][1])), cw - 2)
		text_c(Rect2(cell.position.x, at.y + ICON + 1, cw, LINE), label)
		if id == "inbox":
			var n: int = _apps["inbox"].unread()
			if n > 0:
				var s := "%d" % n
				var b := Rect2(at.x + ICON - text_w(s) - 1, at.y - 2, text_w(s) + 4, LINE)
				fill(b)
				text(b.position.x + 2, b.position.y, s, glass())
		hit("app:" + id, Rect2(cell.position.x, cell.position.y - 2, cw, ch))


func _app_name(id: String) -> String:
	for a in APPS:
		if str(a[0]) == id:
			return str(a[1])
	return id


## The camp's clock as the office's has it ("21:07").
func clock_text() -> String:
	var gm = INSTANCE.guests(main) if main != null else null
	if gm == null:
		return "--:--"
	return "%02d:%02d" % [int(gm.get("_last_known_hour")), int(gm.get("_last_known_minute"))]


# ── the stylus ───────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	if mm != null:
		var h := _hit_at(mm.position)
		if h != _hover:
			_hover = h
			queue_redraw()
		if app != "" and _apps[app].has_method("drag") and _down != "":
			_apps[app].drag(mm.position)
		accept_event()
		return
	if mb == null:
		return
	accept_event()
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = _hit_at(mb.position)
		_hover = _down
		play("tap")
		if _down == "" and app != "":
			_apps[app].tap(mb.position)
		queue_redraw()
		return
	var id := _hit_at(mb.position)
	var was := _down
	_down = ""
	queue_redraw()
	if id == "" or id != was:
		return
	if id == "home":
		go_home()
	elif id.begins_with("app:"):
		open_app(id.substr(4))
	elif app != "":
		_apps[app].press(id)


func _hit_at(p: Vector2) -> String:
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i][1] as Rect2).has_point(p):
			return str(_hits[i][0])
	return ""


## Keys while the device is up (the snake's arrows): the app's, if it wants them.
func key(event: InputEventKey) -> bool:
	if app != "" and _apps[app].has_method("key"):
		return bool(_apps[app].key(event))
	return false
