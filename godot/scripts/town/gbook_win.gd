extends RefCounted

## One window of gOS (scripts/town/gbook_os.gd): where it stands, its chrome and how that is
## drawn, in the system's one-pixel lines. What is inside is the subclass's (gbook_apps.gd):
## `draw_body`, `press`, `drag`, `release`, `key`, `tick`. The little drawing kit under it
## (fill, frame, text, wrapped, button, field) is static: the OS draws its own bars with it too.

const LANG = preload("res://scripts/lang.gd")
const FONT: FontFile = preload("res://assets/fonts/w95.fnt")
const FONT_B: FontFile = preload("res://assets/fonts/w95b.fnt")
const FS := 12
const LINE := 13
const TITLE_H := 15
## A scroll bar's width, and the corner where the two meet.
const BAR := 13
const BOX := 9

const C_BLACK := Color8(20, 19, 22)
const C_WHITE := Color8(240, 239, 232)
const C_PALE := Color8(224, 222, 215)
const C_LIGHT := Color8(204, 202, 196)
const C_MID := Color8(170, 168, 163)
const C_GREY := Color8(128, 126, 122)
const C_DARK := Color8(78, 76, 74)

var os
## What it shows: the same thing opens the same window.
var ident := ""
## A msgid (a name of the disk's, looked up when drawn).
var title := ""
var rect := Rect2i(40, 40, 200, 120)
var closable := true
var zoomable := false
var growable := false
var min_size := Vector2i(120, 80)
## No title bar, a double frame: the system's boxes.
var bare := false
## The icon it came out of (it zooms out of it and back in).
var from := Rect2i()
## {"r": Rect2i from the body's corner, "label", "cmd": Callable, "default", "on"}
var buttons: Array = []
var held_button := -1
var held_in := false
## {"r", "text", "secret"}
var fields: Array = []
var focus := -1
var close_held := false
var zoom_held := false
var zoom_back := Rect2i()


func body() -> Rect2i:
	if bare:
		return Rect2i(rect.position + Vector2i(4, 4), rect.size - Vector2i(8, 8))
	return Rect2i(rect.position + Vector2i(1, TITLE_H + 1), rect.size - Vector2i(2, TITLE_H + 2))


func close_box() -> Rect2i:
	return Rect2i(rect.position.x + 7, rect.position.y + 3, BOX, BOX)


func zoom_box() -> Rect2i:
	return Rect2i(rect.end.x - 7 - BOX, rect.position.y + 3, BOX, BOX)


func grow_box() -> Rect2i:
	return Rect2i(rect.end.x - 1 - BAR, rect.end.y - 1 - BAR, BAR, BAR)


func on_title(p: Vector2i) -> bool:
	return not bare and p.y < rect.position.y + TITLE_H + 1


func draw(c: CanvasItem, active: bool) -> void:
	if bare:
		fill(c, rect, C_PALE)
		frame(c, rect, C_BLACK)
		frame(c, rect.grow(-2), C_BLACK)
		fill(c, Rect2i(rect.end.x, rect.position.y + 2, 1, rect.size.y - 1), C_BLACK)
		fill(c, Rect2i(rect.position.x + 2, rect.end.y, rect.size.x - 1, 1), C_BLACK)
		draw_body(c, body(), active)
		draw_widgets(c)
		return
	fill(c, rect, C_LIGHT)
	var t := Rect2i(rect.position.x + 1, rect.position.y + 1, rect.size.x - 2, TITLE_H - 1)
	fill(c, t, C_PALE if active else C_LIGHT)
	var label := LANG.t(title)
	label = fit(label, rect.size.x - 44, true)
	var tw := text_w(label, true)
	var lx: int = rect.position.x + (rect.size.x - tw) / 2
	if active:
		# The title bar's lines, cut round the name and the boxes.
		for i in 6:
			var y: int = t.position.y + 2 + i * 2
			fill(c, Rect2i(t.position.x + 2, y, t.size.x - 4, 1), C_GREY)
			fill(c, Rect2i(t.position.x + 2, y + 1, t.size.x - 4, 1), C_WHITE)
		fill(c, Rect2i(lx - 5, t.position.y, tw + 10, t.size.y), C_PALE)
		if closable:
			fill(c, close_box().grow(2), C_PALE)
			fill(c, close_box(), C_LIGHT)
			frame(c, close_box(), C_BLACK)
			if close_held and close_box().grow(1).has_point(os.pointer):
				fill(c, close_box().grow(-2), C_BLACK)
		if zoomable:
			var z := zoom_box()
			fill(c, z.grow(2), C_PALE)
			fill(c, z, C_LIGHT)
			frame(c, z, C_BLACK)
			frame(c, Rect2i(z.position, Vector2i(6, 6)), C_BLACK)
			if zoom_held and z.grow(1).has_point(os.pointer):
				fill(c, z.grow(-2), C_BLACK)
	text(c, lx, t.position.y + 1, label, C_BLACK if active else C_GREY, true)
	fill(c, Rect2i(rect.position.x, rect.position.y + TITLE_H, rect.size.x, 1), C_BLACK)
	draw_body(c, body(), active)
	draw_widgets(c)
	frame(c, rect, C_BLACK if active else C_DARK)
	if active:
		fill(c, Rect2i(rect.end.x, rect.position.y + 1, 1, rect.size.y), C_BLACK)
		fill(c, Rect2i(rect.position.x + 1, rect.end.y, rect.size.x, 1), C_BLACK)


func draw_body(_c: CanvasItem, _r: Rect2i, _active: bool) -> void:
	pass


## The bars along a list's right and bottom edge. `at` and `share` place the thumb of the
## vertical one (0..1; a share of 1 has nothing to scroll: the bar stands empty).
func draw_bars(c: CanvasItem, r: Rect2i, active: bool, at := 0.0, share := 1.0, horizontal := true) -> void:
	var v := Rect2i(r.end.x - BAR, r.position.y - 1, BAR + 1, r.size.y - BAR + 2)
	var ink := C_BLACK if active else C_GREY
	fill(c, v, C_WHITE if share >= 1.0 or not active else C_LIGHT)
	frame(c, v, ink)
	_arrow(c, Rect2i(v.position.x, v.position.y, BAR + 1, BAR), -1, ink, active and share < 1.0)
	_arrow(c, Rect2i(v.position.x, v.end.y - BAR, BAR + 1, BAR), 1, ink, active and share < 1.0)
	if share < 1.0 and active:
		var track := bar_track(r)
		var th := maxi(12, int(track.size.y * share))
		var ty: int = track.position.y + int((track.size.y - th) * at)
		var thumb := Rect2i(track.position.x, ty, track.size.x, th)
		fill(c, thumb, C_PALE)
		frame(c, thumb, C_BLACK)
	if horizontal:
		var h := Rect2i(r.position.x - 1, r.end.y - BAR, r.size.x - BAR + 2, BAR + 1)
		fill(c, h, C_WHITE)
		frame(c, h, ink)
		frame(c, Rect2i(h.position.x, h.position.y, BAR, BAR + 1), ink)
		frame(c, Rect2i(h.end.x - BAR, h.position.y, BAR, BAR + 1), ink)
	var g := Rect2i(r.end.x - BAR, r.end.y - BAR, BAR + 1, BAR + 1)
	fill(c, g, C_LIGHT if growable else C_WHITE)
	frame(c, g, ink)
	if growable and active:
		frame(c, Rect2i(g.position.x + 3, g.position.y + 3, 5, 5), C_BLACK)
		frame(c, Rect2i(g.position.x + 5, g.position.y + 5, 6, 6), C_BLACK)


## The vertical bar's track, between its arrows.
func bar_track(r: Rect2i) -> Rect2i:
	return Rect2i(r.end.x - BAR, r.position.y + BAR - 1, BAR + 1, r.size.y - BAR * 3 + 2)


func _arrow(c: CanvasItem, r: Rect2i, dir: int, ink: Color, on: bool) -> void:
	frame(c, r, ink)
	var mid: int = r.position.x + r.size.x / 2
	var y0: int = r.position.y + (3 if dir < 0 else r.size.y - 4)
	for i in 5:
		fill(c, Rect2i(mid - i, y0 - dir * -i, i * 2 + 1, 1), C_BLACK if on else C_MID)


func draw_widgets(c: CanvasItem) -> void:
	var b := body()
	for i in buttons.size():
		var bt: Dictionary = buttons[i]
		var r: Rect2i = bt["r"]
		button(c, Rect2i(b.position + r.position, r.size), LANG.t(str(bt["label"])), held_button == i and held_in, bool(bt.get("default", false)), bool(bt.get("on", true)))
	for i in fields.size():
		var f: Dictionary = fields[i]
		var r2: Rect2i = f["r"]
		field(c, Rect2i(b.position + r2.position, r2.size), str(f["text"]), bool(f.get("secret", false)), focus == i, os.caret_on())


func add_button(r: Rect2i, label: String, cmd: Callable, is_default := false, on := true) -> void:
	buttons.append({"r": r, "label": label, "cmd": cmd, "default": is_default, "on": on})


## A press on a button or a field: true when it was one.
func press_widget(p: Vector2i) -> bool:
	var q := p - body().position
	for i in buttons.size():
		if (buttons[i]["r"] as Rect2i).has_point(q) and bool(buttons[i].get("on", true)):
			held_button = i
			held_in = true
			return true
	for i in fields.size():
		if (fields[i]["r"] as Rect2i).has_point(q):
			focus = i
			return true
	return false


func drag_widget(p: Vector2i) -> void:
	if held_button >= 0:
		held_in = (buttons[held_button]["r"] as Rect2i).has_point(p - body().position)


func release_widget(p: Vector2i) -> void:
	if held_button < 0:
		return
	var i := held_button
	held_button = -1
	if (buttons[i]["r"] as Rect2i).has_point(p - body().position):
		(buttons[i]["cmd"] as Callable).call()


## A key into the focused field (a name, a password): true when it went there.
func key_field(ev: InputEventKey) -> bool:
	if focus < 0 or focus >= fields.size():
		return false
	var f: Dictionary = fields[focus]
	if ev.keycode == KEY_TAB:
		focus = (focus + 1) % fields.size()
		return true
	if ev.keycode == KEY_BACKSPACE:
		var s := str(f["text"])
		f["text"] = s.substr(0, maxi(0, s.length() - 1))
		return true
	var u := ev.unicode
	if u >= 32 and u != 127 and str(f["text"]).length() < 24 and not ev.ctrl_pressed:
		f["text"] = str(f["text"]) + String.chr(u)
		return true
	return false


## The default button, by Return or Enter.
func press_default() -> bool:
	for b in buttons:
		if bool(b.get("default", false)) and bool(b.get("on", true)):
			(b["cmd"] as Callable).call()
			return true
	return false


func press(_p: Vector2i, _twice: bool) -> void:
	pass


func drag(_p: Vector2i) -> void:
	pass


func release(_p: Vector2i) -> void:
	pass


func key(_ev: InputEventKey) -> bool:
	return false


func wheel(_dir: int) -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Moved or sized by the title bar's zoom box or the corner.
func resized() -> void:
	pass


func closing() -> void:
	pass


## The size the zoom box asks for.
func best_size() -> Vector2i:
	return rect.size


# ── the kit ──────────────────────────────────────────────────────────────────

static func fill(c: CanvasItem, r: Rect2i, col: Color) -> void:
	c.draw_rect(Rect2(r), col)


static func frame(c: CanvasItem, r: Rect2i, col: Color) -> void:
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), col)
	c.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), col)
	c.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), col)
	c.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), col)


## A line of dots, for the menus' separators and the outlines held in a drag.
static func dots(c: CanvasItem, from_p: Vector2i, to_p: Vector2i, col: Color) -> void:
	if from_p.y == to_p.y:
		for x in range(from_p.x, to_p.x, 2):
			c.draw_rect(Rect2(x, from_p.y, 1, 1), col)
	else:
		for y in range(from_p.y, to_p.y, 2):
			c.draw_rect(Rect2(from_p.x, y, 1, 1), col)


static func dotted_frame(c: CanvasItem, r: Rect2i, col: Color) -> void:
	dots(c, r.position, Vector2i(r.end.x, r.position.y), col)
	dots(c, Vector2i(r.position.x, r.end.y - 1), r.end - Vector2i(0, 1), col)
	dots(c, r.position, Vector2i(r.position.x, r.end.y), col)
	dots(c, Vector2i(r.end.x - 1, r.position.y), r.end - Vector2i(1, 0), col)


static func text(c: CanvasItem, x: int, y: int, s: String, col: Color, bold := false) -> void:
	c.draw_string(FONT_B if bold else FONT, Vector2(x, y + 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, col)


static func text_w(s: String, bold := false) -> int:
	return int((FONT_B if bold else FONT).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x)


## `s` cut down to `w` pixels.
static func fit(s: String, w: int, bold := false) -> String:
	if text_w(s, bold) <= w:
		return s
	var cut := s
	while cut.length() > 1 and text_w(cut + "..", bold) > w:
		cut = cut.substr(0, cut.length() - 1)
	return cut.strip_edges() + ".."


## Word wrap to `w` pixels. A line of a list (a tab in it) wraps in its second column, from
## `col2` px; one of three columns stays whole.
static func wrapped(s: String, w: int, col2 := 0) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var parts := para.split("\t")
		if parts.size() > 2:
			out.append(para)
		elif parts.size() == 2:
			var rows := _broken(parts[1], w - col2)
			for i in rows.size():
				out.append((parts[0] if i == 0 else "") + "\t" + rows[i])
		else:
			out.append_array(_broken(para, w))
	return out


static func _broken(s: String, w: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		var next := word if line == "" else line + " " + word
		if text_w(next) > w and line != "":
			out.append(line)
			line = word
		else:
			line = next
	out.append(line)
	return out


## A filled box with its corners off, round like the system's buttons.
static func rbox(c: CanvasItem, r: Rect2i, inside: Color, line: Color) -> void:
	var x: int = r.position.x
	var y: int = r.position.y
	var w: int = r.size.x
	var h: int = r.size.y
	c.draw_rect(Rect2(x + 2, y + 1, w - 4, h - 2), inside)
	c.draw_rect(Rect2(x + 1, y + 2, w - 2, h - 4), inside)
	c.draw_rect(Rect2(x + 3, y, w - 6, 1), line)
	c.draw_rect(Rect2(x + 3, y + h - 1, w - 6, 1), line)
	c.draw_rect(Rect2(x, y + 3, 1, h - 6), line)
	c.draw_rect(Rect2(x + w - 1, y + 3, 1, h - 6), line)
	for q in [Vector2(x + 1, y + 2), Vector2(x + 2, y + 1), Vector2(x + w - 3, y + 1), Vector2(x + w - 2, y + 2), Vector2(x + 1, y + h - 3), Vector2(x + 2, y + h - 2), Vector2(x + w - 3, y + h - 2), Vector2(x + w - 2, y + h - 3)]:
		c.draw_rect(Rect2(q, Vector2.ONE), line)


static func button(c: CanvasItem, r: Rect2i, label: String, down := false, is_default := false, on := true) -> void:
	if is_default:
		rbox(c, r.grow(3), C_BLACK, C_BLACK)
		rbox(c, r.grow(1), C_PALE, C_PALE)
	rbox(c, r, C_BLACK if down else C_WHITE, C_BLACK if on else C_GREY)
	var ink := C_WHITE if down else (C_BLACK if on else C_GREY)
	text(c, r.position.x + (r.size.x - text_w(label, true)) / 2, r.position.y + (r.size.y - 12) / 2, label, ink, true)


static func field(c: CanvasItem, r: Rect2i, s: String, secret: bool, focused: bool, caret: bool) -> void:
	fill(c, r, C_WHITE)
	frame(c, r, C_BLACK)
	var x: int = r.position.x + 3
	if secret:
		for i in s.length():
			fill(c, Rect2i(x + i * 6 + 1, r.position.y + 6, 4, 4), C_BLACK)
		x += s.length() * 6
	else:
		text(c, x, r.position.y + 2, s, C_BLACK)
		x += text_w(s)
	if focused and caret:
		fill(c, Rect2i(x, r.position.y + 2, 1, r.size.y - 4), C_BLACK)
