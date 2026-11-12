extends Control

## The belt pager (hud_manager.push_pager): whatever happens away from you comes through it,
## one message at a time (12. 11.: it was a stack of lines in the top corner, the pager's
## among the guests' talk and your own doings). It comes up off the belt, out of the status
## bar's top edge in the bottom left corner (out of the screen's bottom edge in a room), as
## it beeps, its screen lit, two lines of the message at a time (a long one goes on a page at
## a time), then the next message; with nothing left it goes back down. A message of the same
## group as one waiting takes its place (the post's "new mail" once, however many letters
## came). Nothing moves while it is away (set_process off).

## The slim pager (tools/artgen/pager_slim.py out of prompts_day.tsv hud_pager: 12. 11., the
## whole one with its buttons took a quarter of the view), 98 x 37: its screen, two lines of
## the HUD's small font, and its LED (lit while it shows a message).
const BODY_PATH := "res://assets/textury/hud/pager_slim.png"
const LCD := Rect2(10, 10, 78, 18)
const LED := Rect2(82, 1, 4, 4)
const LINES := 2
## Seconds a page stays, the least a whole message stays, the slide in or out.
const PAGE_SEC := 2.4
const MESSAGE_MIN_SEC := 3.8
const SLIDE_SEC := 0.22
## The screen's backlight over its own grey grain (a 1990s STN screen: dark letters on
## yellow-green) and its letters.
const LIT := Color(0.62, 0.78, 0.22, 0.55)
const INK := Color(0.1, 0.13, 0.06)
const LED_WARN := Color(1.0, 0.25, 0.15)
const LED_INFO := Color(0.55, 1.0, 0.35)

var ui_scale := 3
## Screen pixels left clear under the pager down to the edge it comes out of.
var gap_px := 0.0
var _body: Texture2D
var _queue: Array = []
var _current: Dictionary = {}
var _pages: Array = []
var _page := 0
var _page_t := 0.0
var _left := 0.0
## 0 up out of sight .. 1 down in the corner.
var _down := 0.0
var _going := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (Out of its rect's bottom edge: what is below it is not drawn.)
	clip_contents = true
	if ResourceLoader.exists(BODY_PATH):
		_body = load(BODY_PATH)
	set_process(false)


## A message on the pager (`kind`: hud_manager's STATUS_*; a warning lights the LED red).
func show_line(text: String, kind: int, group := "") -> void:
	var msg := {"text": text, "kind": kind, "group": group}
	if group != "":
		if str(_current.get("group", "")) == group:
			_current = msg
			_paginate()
			queue_redraw()
			return
		for i in _queue.size():
			if str(_queue[i].get("group", "")) == group:
				_queue[i] = msg
				return
	_queue.append(msg)
	if _current.is_empty():
		_next()
	set_process(true)


func _body_size() -> Vector2:
	return (Vector2(_body.get_size()) if _body != null else Vector2(136, 64)) * float(ui_scale)


func _next() -> void:
	if _queue.is_empty():
		_current = {}
		_going = 0.0
		return
	_current = _queue.pop_front()
	_paginate()
	_going = 1.0


func _paginate() -> void:
	var lines := _wrap(str(_current.get("text", "")), (LCD.size.x - 4.0) * float(ui_scale))
	_pages = []
	for i in range(0, lines.size(), LINES):
		_pages.append(lines.slice(i, i + LINES))
	if _pages.is_empty():
		_pages = [[""]]
	_page = 0
	_page_t = PAGE_SEC
	_left = maxf(MESSAGE_MIN_SEC, PAGE_SEC * float(_pages.size()))


## The message in lines as wide as the screen (`width` screen pixels), by words.
func _wrap(text: String, width: float) -> Array:
	var font: Font = RETRO_UI.FONT_TEXT
	var fs := RETRO_UI.SIZE_TEXT * ui_scale
	var fits := func(s: String) -> bool: return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width
	var out: Array = []
	var line := ""
	for word in text.strip_edges().split(" ", false):
		var w := str(word)
		var joined := w if line == "" else line + " " + w
		if fits.call(joined):
			line = joined
			continue
		if line != "":
			out.append(line)
		line = w
		# (A word wider than the screen goes on letter by letter.)
		while not fits.call(line) and line.length() > 1:
			var cut := line.length() - 1
			while cut > 1 and not fits.call(line.substr(0, cut)):
				cut -= 1
			out.append(line.substr(0, cut))
			line = line.substr(cut)
	if line != "":
		out.append(line)
	return out


func _process(delta: float) -> void:
	size = _body_size() + Vector2(0, gap_px)
	var was := _down
	_down = move_toward(_down, _going, delta / SLIDE_SEC)
	if not _current.is_empty() and _down >= 1.0:
		_left -= delta
		_page_t -= delta
		if _page_t <= 0.0 and _page < _pages.size() - 1:
			_page += 1
			_page_t = PAGE_SEC
			queue_redraw()
		if _left <= 0.0:
			_next()
			queue_redraw()
	if _current.is_empty() and _down <= 0.0:
		set_process(false)
	if _down != was:
		queue_redraw()


static func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


func _draw() -> void:
	if _body == null or _down <= 0.0:
		return
	var s := float(ui_scale)
	var top := size.y * (1.0 - _ease(_down))
	draw_texture_rect(_body, Rect2(Vector2(0, top), _body_size()), false)
	if _current.is_empty():
		return
	var lcd := Rect2(Vector2(LCD.position.x * s, top + LCD.position.y * s), LCD.size * s)
	draw_rect(lcd, LIT)
	# (The LED is round: a cross of two bars over its four by four.)
	var led_c := LED_WARN if int(_current.get("kind", 0)) >= 2 else LED_INFO
	var led := Vector2(LED.position.x * s, top + LED.position.y * s)
	draw_rect(Rect2(led + Vector2(s, 0), Vector2(LED.size.x - 2.0, LED.size.y) * s), led_c)
	draw_rect(Rect2(led + Vector2(0, s), Vector2(LED.size.x, LED.size.y - 2.0) * s), led_c)
	var font: Font = RETRO_UI.FONT_TEXT
	var fs := RETRO_UI.SIZE_TEXT * ui_scale
	var line_h := lcd.size.y / float(LINES)
	var lines: Array = _pages[_page] if _page < _pages.size() else []
	for i in lines.size():
		# (A pixel under the middle: a capital's háček stays off the screen's top edge.)
		var base := lcd.position + Vector2(2.0 * s, line_h * float(i) + line_h * 0.5 + s + RETRO_UI.cap_height_px(font, RETRO_UI.SIZE_TEXT, ui_scale) * 0.5)
		draw_string(font, base, str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	# More to come: a little arrow in the corner of the screen.
	if _page < _pages.size() - 1:
		var a := lcd.end - Vector2(4.0 * s, 3.0 * s)
		draw_colored_polygon(PackedVector2Array([a, a + Vector2(2.0 * s, 0), a + Vector2(s, s)]), INK)


const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
