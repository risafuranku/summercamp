extends RefCounted

## What gOS's windows hold (gbook_os.gd is the window manager, gbook_win.gd the chrome): a
## folder and the desktop (one class: icons on a ground), gText, the calculator, the
## sliding puzzle, the Installer, the Dialer, the control panels, Get Info and the system's
## boxes. Nothing here installs, downloads or changes the machine: whatever would asks for
## an administrator (Auth) and that always fails, in a real system's own words.

const FILES = preload("res://scripts/town/gbook_files.gd")


# ── a folder (and the desktop) ───────────────────────────────────────────────

class Folder extends "res://scripts/town/gbook_win.gd":
	const CELL := Vector2i(78, 50)
	const HEAD := 15
	const ROW := 14
	var folder := ""
	var items: Array = []
	var sel: Array = []
	var spots := {}
	var by_name := false
	var desktop := false
	var _held := ""
	var _held_at := Vector2i.ZERO
	var moved := false

	func _init(p_os, p_folder: String) -> void:
		os = p_os
		folder = p_folder
		ident = p_folder
		title = str(FILES.ITEMS[p_folder]["name"])
		items = (FILES.ITEMS[p_folder]["items"] as Array).duplicate()
		zoomable = true
		growable = true
		rect.size = best_size()
		min_size = Vector2i(CELL.x + BAR + 10, CELL.y + TITLE_H + HEAD + BAR + 12)
		clean_up()

	func best_size() -> Vector2i:
		var cols := clampi(items.size(), 2, 3)
		var rows: int = (items.size() + cols - 1) / cols
		return Vector2i(cols * CELL.x + BAR + 24, rows * CELL.y + TITLE_H + HEAD + BAR + 12)

	func body() -> Rect2i:
		return rect if desktop else super.body()

	func area() -> Rect2i:
		var b := body()
		if desktop:
			return b
		return Rect2i(b.position + Vector2i(0, HEAD), b.size - Vector2i(BAR, HEAD + BAR))

	func clean_up() -> void:
		var cols := maxi(1, area().size.x / CELL.x)
		for i in items.size():
			spots[items[i]] = Vector2i((i % cols) * CELL.x + 8, (i / cols) * CELL.y + 5)

	func resized() -> void:
		clean_up()
		var cols := maxi(1, area().size.x / CELL.x)
		var rows: int = (items.size() + cols - 1) / cols
		rect.size.y = maxi(rect.size.y, rows * CELL.y + TITLE_H + HEAD + BAR + 12)

	func icon_rect(id: String) -> Rect2i:
		var p: Vector2i = area().position + (spots[id] as Vector2i)
		return Rect2i(p + Vector2i((CELL.x - 32) / 2, 0), Vector2i(32, 32))

	func _name(id: String) -> String:
		return fit(LANG.t(str(FILES.ITEMS[id]["name"])), CELL.x + 16)

	func label_rect(id: String) -> Rect2i:
		var ir := icon_rect(id)
		var w := text_w(_name(id)) + 4
		return Rect2i(ir.position.x + 16 - w / 2, ir.end.y + 1, w, 13)

	func _row_rect(i: int) -> Rect2i:
		var a := area()
		return Rect2i(a.position.x + 2, a.position.y + 16 + i * ROW, a.size.x - 4, ROW)

	func item_at(p: Vector2i) -> String:
		if by_name:
			for i in items.size():
				if _row_rect(i).has_point(p):
					return str(items[i])
			return ""
		for i in range(items.size() - 1, -1, -1):
			var id := str(items[i])
			if icon_rect(id).has_point(p) or label_rect(id).has_point(p):
				return id
		return ""

	func draw_body(c: CanvasItem, r: Rect2i, active: bool) -> void:
		if desktop:
			for id in items:
				_draw_item(c, str(id), true)
			return
		fill(c, r, C_WHITE)
		_draw_head(c, r)
		var a := area()
		if by_name:
			_draw_list(c, a, active)
		else:
			for id in items:
				if a.encloses(icon_rect(str(id))):
					_draw_item(c, str(id), active)
		draw_bars(c, Rect2i(r.position + Vector2i(0, HEAD + 1), r.size - Vector2i(0, HEAD + 1)), active)

	func _draw_head(c: CanvasItem, r: Rect2i) -> void:
		var count := LANG.t_n(items.size(), "%d item", "%d items")
		var y: int = r.position.y + 1
		text(c, r.position.x + 6, y, count, C_BLACK)
		var used := LANG.f("%s in disk", [FILES.figure("36.8 MB")])
		var free := LANG.f("%s available", [FILES.figure("1.6 MB")])
		var fw := text_w(free)
		text(c, r.end.x - fw - 6, y, free, C_BLACK)
		var mid: int = r.position.x + (r.size.x - text_w(used)) / 2
		if mid > r.position.x + text_w(count) + 12 and mid + text_w(used) + 10 < r.end.x - fw:
			text(c, mid, y, used, C_BLACK)
		fill(c, Rect2i(r.position.x, r.position.y + HEAD - 2, r.size.x, 1), C_BLACK)
		fill(c, Rect2i(r.position.x, r.position.y + HEAD, r.size.x, 1), C_BLACK)

	func _draw_item(c: CanvasItem, id: String, active: bool) -> void:
		var ir := icon_rect(id)
		var chosen := sel.has(id)
		var col := Color.WHITE
		if os.is_open(id):
			col = Color(0.62, 0.62, 0.66)
		if chosen and active:
			col = Color(0.42, 0.42, 0.48)
		os.icon(c, str(FILES.ITEMS[id]["icon"]), ir.position, col)
		var lr := label_rect(id)
		var label := _name(id)
		if chosen and active:
			fill(c, lr, C_BLACK)
			text(c, lr.position.x + 2, lr.position.y, label, C_WHITE)
		else:
			if desktop:
				fill(c, lr, C_WHITE)
			text(c, lr.position.x + 2, lr.position.y, label, C_BLACK)

	func _draw_list(c: CanvasItem, a: Rect2i, active: bool) -> void:
		var cols := _columns(a)
		var y: int = a.position.y + 1
		for col in cols:
			text(c, a.position.x + int(col[0]), y, LANG.t(str(col[1])), C_BLACK, true)
		fill(c, Rect2i(a.position.x, a.position.y + 14, a.size.x, 1), C_GREY)
		for i in items.size():
			var row := _row_rect(i)
			if row.end.y > a.end.y:
				break
			var id := str(items[i])
			var chosen := sel.has(id) and active
			if chosen:
				fill(c, row, C_BLACK)
			var ink := C_WHITE if chosen else C_BLACK
			os.icon(c, str(FILES.ITEMS[id]["icon"]) + "_16", row.position + Vector2i(4, -1), Color.WHITE)
			var it: Dictionary = FILES.ITEMS[id]
			text(c, row.position.x + 23, row.position.y + 1, fit(LANG.t(str(it["name"])), 92), ink)
			for col in cols:
				var v := str(col[2])
				if v == "":
					continue
				var s: String = os.changed_of(id) if v == "changed" else str(it.get(v, ""))
				if v == "type":
					s = LANG.t(s)
				elif v == "size":
					s = FILES.figure(s)
				text(c, a.position.x + int(col[0]), row.position.y + 1, fit(s, int(col[3])), ink)

	func _columns(a: Rect2i) -> Array:
		var cols: Array = [[25, "Name", "", 0]]
		var x := 118
		for col in [[50, "Size", "size"], [88, "Kind", "type"], [100, "Last Modified", "changed"]]:
			if x + int(col[0]) > a.size.x:
				break
			cols.append([x, col[1], col[2], int(col[0]) - 4])
			x += int(col[0])
		return cols

	func press(p: Vector2i, twice: bool) -> void:
		var id := item_at(p)
		if id == "":
			sel.clear()
			return
		if not sel.has(id):
			sel = [id]
		_held = id
		_held_at = p
		moved = false
		if twice:
			_held = ""
			os.open_item(id, icon_rect(id) if not by_name else _row_rect(items.find(id)))

	func drag(p: Vector2i) -> void:
		if _held != "" and not by_name and (p - _held_at).length() >= 3.0:
			moved = true

	func release(p: Vector2i) -> void:
		if _held != "" and moved:
			os.drop_icon(self, _held, p - _held_at, p)
		_held = ""
		moved = false

	## The outline held in the drag (screen pixels).
	func held_outline(p: Vector2i) -> Rect2i:
		if _held == "" or not moved:
			return Rect2i()
		var ir := icon_rect(_held)
		ir.position += p - _held_at
		return ir

	func move_item(id: String, by: Vector2i) -> void:
		var a := area()
		var at: Vector2i = (spots[id] as Vector2i) + by
		spots[id] = Vector2i(clampi(at.x, -(CELL.x - 32) / 2, a.size.x - CELL.x + (CELL.x - 32) / 2), clampi(at.y, 0, a.size.y - 46))

	func select_all() -> void:
		sel = items.duplicate()

	## The list wants the width for its dates.
	func list_view(on: bool) -> void:
		by_name = on
		sel.clear()
		if on:
			rect.size.x = maxi(rect.size.x, mini(378, os.W - rect.position.x - 6))


# ── gText ────────────────────────────────────────────────────────────────────

class Reader extends "res://scripts/town/gbook_win.gd":
	const COL2 := 50
	var words := ""
	var lines := PackedStringArray()
	var top := 0
	## The program opened by itself: an empty page to type on, kept nowhere.
	var editable := false
	var _thumb := false

	func _init(p_os, p_key: String, p_title: String, p_words: String) -> void:
		os = p_os
		ident = p_key
		title = p_title
		words = p_words
		zoomable = true
		growable = true
		rect.size = Vector2i(288, 186)
		min_size = Vector2i(150, 90)
		resized()
		# As tall as its words, up to what the screen has: his lists stand whole.
		rect.size.y = clampi(lines.size() * LINE + TITLE_H + 12, 130, 232)
		resized()

	func best_size() -> Vector2i:
		return Vector2i(330, 240)

	func _view() -> Rect2i:
		var b := body()
		return Rect2i(b.position + Vector2i(7, 4), b.size - Vector2i(BAR + 12, 8))

	func rows() -> int:
		return maxi(1, _view().size.y / LINE)

	func resized() -> void:
		lines = wrapped(words, _view().size.x, COL2)
		top = clampi(top, 0, maxi(0, lines.size() - rows()))

	func draw_body(c: CanvasItem, r: Rect2i, active: bool) -> void:
		fill(c, r, C_WHITE)
		var v := _view()
		for i in rows():
			var n := top + i
			if n >= lines.size():
				break
			_line(c, v, v.position.y + i * LINE, lines[n])
		if editable and active and os.caret_on():
			var last := lines[lines.size() - 1] if not lines.is_empty() else ""
			var y := v.position.y + (mini(lines.size(), rows() + top) - 1 - top) * LINE
			fill(c, Rect2i(v.position.x + text_w(last), maxi(y, v.position.y), 1, 12), C_BLACK)
		var share := 1.0 if lines.size() <= rows() else float(rows()) / float(lines.size())
		var at := 0.0 if lines.size() <= rows() else float(top) / float(lines.size() - rows())
		draw_bars(c, r, active, at, share, false)

	func _line(c: CanvasItem, v: Rect2i, y: int, s: String) -> void:
		var parts := s.split("\t")
		text(c, v.position.x, y, parts[0], C_BLACK)
		if parts.size() > 1:
			text(c, v.position.x + COL2, y, parts[1], C_BLACK)
		if parts.size() > 2:
			text(c, v.end.x - text_w(parts[2]) - 2, y, parts[2], C_BLACK)

	func press(p: Vector2i, _twice: bool) -> void:
		var b := body()
		if p.x < b.end.x - BAR or lines.size() <= rows():
			return
		var track := bar_track(b)
		if p.y < track.position.y:
			wheel(-1)
		elif p.y >= track.end.y:
			wheel(1)
		else:
			_thumb = true
			drag(p)

	func drag(p: Vector2i) -> void:
		if _thumb:
			var track := bar_track(body())
			var k := clampf(float(p.y - track.position.y) / float(maxi(1, track.size.y)), 0.0, 1.0)
			top = int(roundf(k * float(lines.size() - rows())))

	func release(_p: Vector2i) -> void:
		_thumb = false

	func wheel(dir: int) -> void:
		top = clampi(top + dir, 0, maxi(0, lines.size() - rows()))

	func key(ev: InputEventKey) -> bool:
		if not editable:
			return false
		if ev.keycode == KEY_BACKSPACE:
			words = words.substr(0, maxi(0, words.length() - 1))
		elif ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			words += "\n"
		elif ev.unicode >= 32 and ev.unicode != 127 and words.length() < 2000:
			words += String.chr(ev.unicode)
		else:
			return false
		resized()
		top = maxi(0, lines.size() - rows())
		return true


# ── the calculator ───────────────────────────────────────────────────────────

class Calc extends "res://scripts/town/gbook_win.gd":
	const KEY := Vector2i(22, 17)
	const GAP := 3
	## label, column, row, columns wide, rows tall.
	const KEYS := [
		["C", 0, 0, 1, 1], ["/", 1, 0, 1, 1], ["*", 2, 0, 1, 1], ["-", 3, 0, 1, 1],
		["7", 0, 1, 1, 1], ["8", 1, 1, 1, 1], ["9", 2, 1, 1, 1], ["+", 3, 1, 1, 2],
		["4", 0, 2, 1, 1], ["5", 1, 2, 1, 1], ["6", 2, 2, 1, 1],
		["1", 0, 3, 1, 1], ["2", 1, 3, 1, 1], ["3", 2, 3, 1, 1], ["=", 3, 3, 1, 2],
		["0", 0, 4, 2, 1], [".", 2, 4, 1, 1],
	]
	var shown := "0"
	var acc := 0.0
	var op := ""
	var fresh := true
	var _down := -1

	func _init(p_os) -> void:
		os = p_os
		ident = "calc"
		title = "Calculator"
		rect.size = Vector2i(4 * KEY.x + 3 * GAP + 14, 5 * KEY.y + 4 * GAP + 34 + TITLE_H + 2)

	func _key_rect(i: int) -> Rect2i:
		var k: Array = KEYS[i]
		var b := body()
		var x: int = b.position.x + 7 + int(k[1]) * (KEY.x + GAP)
		var y: int = b.position.y + 27 + int(k[2]) * (KEY.y + GAP)
		return Rect2i(x, y, KEY.x * int(k[3]) + GAP * (int(k[3]) - 1), KEY.y * int(k[4]) + GAP * (int(k[4]) - 1))

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		fill(c, r, C_LIGHT)
		var d := Rect2i(r.position.x + 7, r.position.y + 6, r.size.x - 14, 16)
		fill(c, d, C_WHITE)
		frame(c, d, C_BLACK)
		text(c, d.end.x - 4 - text_w(shown), d.position.y + 2, shown, C_BLACK)
		for i in KEYS.size():
			var kr := _key_rect(i)
			var label := str(KEYS[i][0])
			var on := _down == i
			fill(c, kr, C_BLACK if on else C_PALE)
			frame(c, kr, C_BLACK)
			if not on:
				fill(c, Rect2i(kr.position.x + 1, kr.end.y - 2, kr.size.x - 2, 1), C_MID)
				fill(c, Rect2i(kr.end.x - 2, kr.position.y + 1, 1, kr.size.y - 2), C_MID)
			text(c, kr.position.x + (kr.size.x - text_w(label, true)) / 2, kr.position.y + (kr.size.y - 12) / 2, label, C_WHITE if on else C_BLACK, true)

	func press(p: Vector2i, _twice: bool) -> void:
		for i in KEYS.size():
			if _key_rect(i).has_point(p):
				_down = i
				return

	func release(p: Vector2i) -> void:
		if _down >= 0 and _key_rect(_down).has_point(p):
			punch(str(KEYS[_down][0]))
		_down = -1

	func key(ev: InputEventKey) -> bool:
		var u := String.chr(ev.unicode) if ev.unicode > 0 else ""
		if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			u = "="
		elif ev.keycode == KEY_BACKSPACE or ev.keycode == KEY_DELETE:
			u = "C"
		elif u == ",":
			u = "."
		elif u == "c":
			u = "C"
		if u != "" and "0123456789.+-*/=C".contains(u):
			punch(u)
			return true
		return false

	func punch(k: String) -> void:
		if k == "C":
			shown = "0"
			acc = 0.0
			op = ""
			fresh = true
		elif k in ["+", "-", "*", "/", "="]:
			if op != "" and not fresh:
				_work()
			elif op == "" or k == "=":
				acc = shown.to_float()
			op = "" if k == "=" else k
			fresh = true
		elif k == ".":
			if fresh:
				shown = "0."
				fresh = false
			elif not shown.contains("."):
				shown += "."
		elif fresh:
			shown = k
			fresh = false
		elif shown.length() < 11:
			shown = k if shown == "0" else shown + k

	func _work() -> void:
		var v := shown.to_float()
		match op:
			"+":
				acc += v
			"-":
				acc -= v
			"*":
				acc *= v
			"/":
				if is_zero_approx(v):
					shown = LANG.t("Error")
					acc = 0.0
					op = ""
					return
				acc /= v
		var s := "%.8f" % acc
		if s.contains("."):
			s = s.rstrip("0").rstrip(".")
		# As many digits as the display has; past them it gives up, as they did.
		if s.length() > 12:
			s = s.substr(0, 12) if s.find(".") in range(0, 12) else LANG.t("Error")
		shown = s


# ── the sliding puzzle ───────────────────────────────────────────────────────

class Puzzle extends "res://scripts/town/gbook_win.gd":
	const TILE := 30
	const SLIDE := 0.07
	## As it was left. Kept while the game runs: it is one machine.
	static var tiles: Array = []
	var _from := -1
	var _to := -1
	var _t := 0.0
	var _flash := 0.0

	func _init(p_os) -> void:
		os = p_os
		ident = "puzzle"
		title = "Puzzle"
		rect.size = Vector2i(TILE * 4 + 10, TILE * 4 + 10 + TITLE_H + 2)
		if tiles.is_empty() or solved():
			tiles = _mixed()

	static func solved() -> bool:
		for i in 15:
			if int(tiles[i]) != i + 1:
				return false
		return true

	## Legal moves from the solved board, so it can be finished.
	static func _mixed() -> Array:
		var t: Array = []
		for i in 15:
			t.append(i + 1)
		t.append(0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1998
		var gap := 15
		var last := -1
		for n in 140:
			var opts: Array = []
			for d in [-1, 1, -4, 4]:
				var q: int = gap + int(d)
				if q < 0 or q > 15 or q == last or (absi(int(d)) == 1 and q / 4 != gap / 4):
					continue
				opts.append(q)
			var q2: int = opts[rng.randi_range(0, opts.size() - 1)]
			t[gap] = t[q2]
			t[q2] = 0
			last = gap
			gap = q2
		return t

	func _cell(i: int) -> Rect2i:
		var b := body()
		return Rect2i(b.position.x + 4 + (i % 4) * TILE, b.position.y + 4 + (i / 4) * TILE, TILE, TILE)

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		fill(c, r, C_LIGHT)
		fill(c, Rect2i(r.position + Vector2i(3, 3), Vector2i(TILE * 4 + 2, TILE * 4 + 2)), C_DARK)
		frame(c, Rect2i(r.position + Vector2i(3, 3), Vector2i(TILE * 4 + 2, TILE * 4 + 2)), C_BLACK)
		for i in 16:
			if int(tiles[i]) == 0 or i == _to:
				continue
			_tile(c, _cell(i), int(tiles[i]))
		if _to >= 0:
			var k := clampf(_t / SLIDE, 0.0, 1.0)
			var a := Vector2(_cell(_from).position)
			var b := Vector2(_cell(_to).position)
			var at := Vector2i(a.lerp(b, k).round())
			_tile(c, Rect2i(at, Vector2i(TILE, TILE)), int(tiles[_to]))

	func _tile(c: CanvasItem, r: Rect2i, n: int) -> void:
		var lit := _flash > 0.0
		fill(c, r, C_BLACK if lit else C_PALE)
		frame(c, r, C_BLACK)
		fill(c, Rect2i(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), C_WHITE)
		fill(c, Rect2i(r.position.x + 1, r.position.y + 1, 1, r.size.y - 2), C_WHITE)
		fill(c, Rect2i(r.position.x + 2, r.end.y - 2, r.size.x - 3, 1), C_MID)
		fill(c, Rect2i(r.end.x - 2, r.position.y + 2, 1, r.size.y - 3), C_MID)
		var s := str(n)
		text(c, r.position.x + (r.size.x - text_w(s, true)) / 2, r.position.y + 8, s, C_WHITE if lit else C_BLACK, true)

	func press(p: Vector2i, _twice: bool) -> void:
		if _to >= 0 or solved():
			return
		var gap := tiles.find(0)
		for i in 16:
			if not _cell(i).has_point(p) or i == gap:
				continue
			var same_row: bool = i / 4 == gap / 4
			var same_col: bool = i % 4 == gap % 4
			if not same_row and not same_col:
				return
			# The whole line between the tile and the gap goes along.
			var step: int = (1 if i > gap else -1) * (1 if same_row else 4)
			var q := gap
			while q != i:
				tiles[q] = tiles[q + step]
				q += step
				tiles[q] = 0
			_from = i
			_to = i - step
			_t = 0.0
			return

	func tick(delta: float) -> void:
		if _to >= 0:
			_t += delta
			os.dirty = true
			if _t >= SLIDE:
				_to = -1
				if solved():
					_flash = 0.5
					os.beep()
		if _flash > 0.0:
			_flash -= delta
			os.dirty = true


# ── the Installer, the Dialer ────────────────────────────────────────────────

class Installer extends "res://scripts/town/gbook_win.gd":
	func _init(p_os) -> void:
		os = p_os
		ident = "installer"
		title = "Installer"
		rect.size = Vector2i(276, 168)
		var w := rect.size.x - 2
		var h := rect.size.y - TITLE_H - 2
		add_button(Rect2i(w - 150, h - 25, 60, 18), "Quit", func(): os.close_window(self))
		add_button(Rect2i(w - 82, h - 25, 72, 18), "Install", func(): os.ask_admin("Installer"), true)

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		fill(c, r, C_PALE)
		os.icon(c, "app_installer", r.position + Vector2i(9, 6), Color.WHITE)
		text(c, r.position.x + 50, r.position.y + 7, LANG.t("gOS Installer"), C_BLACK, true)
		text(c, r.position.x + 50, r.position.y + 21, LANG.t("Easy Install"), C_BLACK)
		fill(c, Rect2i(r.position.x + 7, r.position.y + 42, r.size.x - 14, 1), C_GREY)
		fill(c, Rect2i(r.position.x + 7, r.position.y + 43, r.size.x - 14, 1), C_WHITE)
		var y: int = r.position.y + 48
		for s in wrapped(LANG.t("Click Install to place gOS 2.1 Update and Network Software on the disk “gBook HD”."), r.size.x - 18):
			text(c, r.position.x + 9, y, s, C_BLACK)
			y += LINE
		text(c, r.position.x + 9, r.end.y - 41, LANG.f("Disk space needed: %s", [FILES.figure("6,240K")]), C_DARK)


class Dialer extends "res://scripts/town/gbook_win.gd":
	var status := "Idle"
	var _left := 0.0
	var _stage := 0

	func _init(p_os) -> void:
		os = p_os
		ident = "dialer"
		title = "Dialer"
		rect.size = Vector2i(240, 124)
		var w := rect.size.x - 2
		var h := rect.size.y - TITLE_H - 2
		add_button(Rect2i(10, h - 25, 84, 18), "Download...", func(): os.ask_admin("Dialer"))
		add_button(Rect2i(w - 76, h - 25, 66, 18), "Connect", _connect, true)

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		fill(c, r, C_PALE)
		os.icon(c, "app_dialer", r.position + Vector2i(9, 6), Color.WHITE)
		text(c, r.position.x + 50, r.position.y + 7, "Hruška Online", C_BLACK, true)
		text(c, r.position.x + 50, r.position.y + 21, "0 2 / 6710 1020", C_BLACK)
		fill(c, Rect2i(r.position.x + 7, r.position.y + 42, r.size.x - 14, 1), C_GREY)
		fill(c, Rect2i(r.position.x + 7, r.position.y + 43, r.size.x - 14, 1), C_WHITE)
		text(c, r.position.x + 9, r.position.y + 49, LANG.f("Status: %s", [LANG.t(status)]), C_BLACK)

	func _connect() -> void:
		if _stage != 0:
			return
		_stage = 1
		_left = 1.1
		status = "Initializing modem..."
		os.sound("seek_b")

	func tick(delta: float) -> void:
		if _stage == 0:
			return
		_left -= delta
		if _left > 0.0:
			return
		_stage += 1
		os.dirty = true
		if _stage == 2:
			status = "Waiting for dial tone..."
			_left = 2.2
		else:
			_stage = 0
			status = "Idle"
			os.alert("caution", LANG.t("There is no dial tone. Check that the telephone line is connected."))


# ── the control panels ───────────────────────────────────────────────────────

class SoundPanel extends "res://scripts/town/gbook_win.gd":
	const ALERTS := [["alert_clonk", "Clonk"], ["alert_drip", "Drip"], ["alert_pip", "Pip"]]
	var _sliding := false

	func _init(p_os) -> void:
		os = p_os
		ident = "sound"
		title = "Sounds"
		rect.size = Vector2i(262, 128)

	func _slider() -> Rect2i:
		var b := body()
		return Rect2i(b.position.x + 34, b.position.y + 24, 13, 80)

	func _row(i: int) -> Rect2i:
		var b := body()
		return Rect2i(b.position.x + 128, b.position.y + 25 + i * 15, 120, 15)

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		fill(c, r, C_PALE)
		text(c, r.position.x + 8, r.position.y + 6, LANG.t("Speaker Volume"), C_BLACK, true)
		text(c, r.position.x + 127, r.position.y + 6, LANG.t("Alert Sound"), C_BLACK, true)
		var s := _slider()
		for i in 8:
			var y: int = s.end.y - 4 - i * ((s.size.y - 8) / 7)
			fill(c, Rect2i(s.position.x - 6, y, 4, 1), C_BLACK)
			if i == 0 or i == 7:
				text(c, s.position.x - 16, y - 6, str(i), C_BLACK)
		fill(c, Rect2i(s.position.x + 5, s.position.y, 3, s.size.y), C_WHITE)
		frame(c, Rect2i(s.position.x + 5, s.position.y, 3, s.size.y), C_BLACK)
		var ky: int = s.end.y - 4 - int(os.volume) * ((s.size.y - 8) / 7)
		var knob := Rect2i(s.position.x, ky - 3, s.size.x, 7)
		fill(c, knob, C_LIGHT)
		frame(c, knob, C_BLACK)
		fill(c, Rect2i(knob.position.x + 2, ky, knob.size.x - 4, 1), C_BLACK)
		var list := Rect2i(_row(0).position - Vector2i(1, 1), Vector2i(_row(0).size.x + 2, ALERTS.size() * 15 + 2))
		fill(c, list, C_WHITE)
		frame(c, list, C_BLACK)
		for i in ALERTS.size():
			var row := _row(i)
			var on: bool = os.alert_sound == str(ALERTS[i][0])
			if on:
				fill(c, row, C_BLACK)
			text(c, row.position.x + 5, row.position.y + 1, LANG.t(str(ALERTS[i][1])), C_WHITE if on else C_BLACK)

	func press(p: Vector2i, _twice: bool) -> void:
		for i in ALERTS.size():
			if _row(i).has_point(p):
				os.alert_sound = str(ALERTS[i][0])
				os.beep()
				return
		if _slider().grow(3).has_point(p):
			_sliding = true
			drag(p)

	func drag(p: Vector2i) -> void:
		if not _sliding:
			return
		var s := _slider()
		var step := (s.size.y - 8) / 7
		os.volume = clampi((s.end.y - 4 - p.y + step / 2) / step, 0, 7)

	func release(_p: Vector2i) -> void:
		if _sliding:
			_sliding = false
			os.beep()


class DatePanel extends "res://scripts/town/gbook_win.gd":
	func _init(p_os) -> void:
		os = p_os
		ident = "date"
		title = "Date & Time"
		rect.size = Vector2i(234, 118)
		add_button(Rect2i(rect.size.x - 78, rect.size.y - TITLE_H - 27, 68, 18), "Set...", func(): os.ask_admin("Date & Time"))

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		fill(c, r, C_PALE)
		os.icon(c, "cp_date", r.position + Vector2i(9, 8), Color.WHITE)
		var x: int = r.position.x + 50
		text(c, x, r.position.y + 7, LANG.t("Current Date"), C_BLACK, true)
		var d := Rect2i(x, r.position.y + 21, r.size.x - 58, 15)
		fill(c, d, C_WHITE)
		frame(c, d, C_BLACK)
		text(c, x + 4, d.position.y + 1, fit(os.date_text(), d.size.x - 6), C_BLACK)
		text(c, x, r.position.y + 41, LANG.t("Current Time"), C_BLACK, true)
		var t := Rect2i(x, r.position.y + 55, 60, 15)
		fill(c, t, C_WHITE)
		frame(c, t, C_BLACK)
		text(c, x + 4, t.position.y + 1, os.time_text(), C_BLACK)


class About extends "res://scripts/town/gbook_win.gd":
	func _init(p_os) -> void:
		os = p_os
		ident = "about"
		title = "About This gBook"
		rect.size = Vector2i(276, 142)

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		fill(c, r, C_PALE)
		os.icon(c, "about", r.position + Vector2i(9, 7), Color.WHITE)
		var x: int = r.position.x + 50
		text(c, x, r.position.y + 6, "gOS 2.1", C_BLACK, true)
		text(c, x, r.position.y + 20, "Hruška gBook 180", C_BLACK)
		var taken := 2982
		var rows: Array = [["gOS", taken]]
		for w in os.windows:
			var k := str(w.ident)
			if FILES.ITEMS.has(k) and str(FILES.ITEMS[k]["kind"]) == "app" and str(FILES.ITEMS[k]["type"]) == "application":
				var kb := 320 + str(FILES.ITEMS[k]["size"]).to_int()
				rows.append([FILES.ITEMS[k]["name"], kb])
				taken += kb
		var y: int = r.position.y + 42
		text(c, r.position.x + 9, y, LANG.f("Built-in Memory: %s", ["8 MB"]), C_BLACK)
		text(c, r.position.x + 9, y + LINE, LANG.f("Largest Unused Block: %s", [_k(8192 - taken)]), C_BLACK)
		fill(c, Rect2i(r.position.x + 7, y + 27, r.size.x - 14, 1), C_GREY)
		y += 30
		for i in mini(rows.size(), 2):
			var row: Array = rows[i]
			text(c, r.position.x + 9, y, LANG.t(str(row[0])), C_BLACK)
			var bar := Rect2i(r.position.x + 120, y + 2, r.size.x - 130, 8)
			frame(c, bar, C_BLACK)
			fill(c, Rect2i(bar.position.x + 1, bar.position.y + 1, int((bar.size.x - 2) * float(row[1]) / 8192.0), 6), C_DARK)
			text(c, r.position.x + 74, y, _k(int(row[1])), C_BLACK)
			y += LINE
		text(c, r.position.x + 9, r.end.y - 14, "(C) 1994-1996 Hruška Computer", C_DARK)

	static func _k(kb: int) -> String:
		return FILES.figure("%d,%03dK" % [kb / 1000, kb % 1000] if kb >= 1000 else "%dK" % kb)


class Info extends "res://scripts/town/gbook_win.gd":
	var item := ""

	func _init(p_os, p_item: String) -> void:
		os = p_os
		item = p_item
		ident = "info:" + p_item
		title = LANG.f("%s Info", [LANG.t(str(FILES.ITEMS[p_item]["name"]))])
		rect.size = Vector2i(226, 156)

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		fill(c, r, C_PALE)
		var it: Dictionary = FILES.ITEMS[item]
		os.icon(c, str(it["icon"]), r.position + Vector2i(9, 6), Color.WHITE)
		text(c, r.position.x + 48, r.position.y + 15, fit(LANG.t(str(it["name"])), r.size.x - 54), C_BLACK, true)
		fill(c, Rect2i(r.position.x + 7, r.position.y + 42, r.size.x - 14, 1), C_GREY)
		var y: int = r.position.y + 46
		for row in [["Kind:", LANG.t(str(it.get("type", "")))], ["Size:", FILES.figure(str(it.get("size", "")))], ["Where:", _where(it)], ["Created:", str(it.get("made", ""))], ["Modified:", os.changed_of(item)]]:
			var label := LANG.t(str(row[0]))
			text(c, r.position.x + 9, y, label, C_BLACK, true)
			text(c, r.position.x + 74, y, fit(str(row[1]), r.size.x - 82), C_BLACK)
			y += LINE
		var box := Rect2i(r.position.x + 9, r.end.y - 16, 10, 10)
		fill(c, box, C_WHITE)
		frame(c, box, C_GREY)
		if bool(it.get("locked", false)):
			fill(c, box.grow(-3), C_GREY)
		text(c, box.end.x + 4, box.position.y - 2, LANG.t("Locked"), C_GREY)

	func _where(it: Dictionary) -> String:
		var w := str(it.get("where", ""))
		if w == "":
			return LANG.t("Desktop")
		return LANG.t(w) if w == "gBook HD" else "gBook HD: %s" % LANG.t(w)


# ── the system's boxes ───────────────────────────────────────────────────────

class Alert extends "res://scripts/town/gbook_win.gd":
	var icon := ""
	var lines := PackedStringArray()

	## `choices`: [[label, Callable or null], ...], the last the default.
	func _init(p_os, p_icon: String, message: String, choices: Array) -> void:
		os = p_os
		icon = "alert_" + p_icon
		bare = true
		ident = "alert"
		var w := 276
		lines = wrapped(message, w - 66)
		var h := maxi(lines.size() * LINE, 34) + 44
		rect = Rect2i((p_os.W - w) / 2, 56, w, h)
		var x := w - 8
		for i in range(choices.size() - 1, -1, -1):
			var choice: Array = choices[i]
			var bw := maxi(52, text_w(LANG.t(str(choice[0])), true) + 18)
			x -= bw + 4
			var then = choice[1]
			var cmd := func() -> void:
				os.close_dialog(self)
				if then != null:
					(then as Callable).call()
			add_button(Rect2i(x, h - 28, bw, 18), str(choice[0]), cmd, i == choices.size() - 1)
			x -= 6

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		os.icon(c, icon, r.position + Vector2i(8, 7), Color.WHITE)
		var y: int = r.position.y + 7
		for s in lines:
			text(c, r.position.x + 52, y, s, C_BLACK)
			y += LINE


class Auth extends "res://scripts/town/gbook_win.gd":
	const TRIES := 3
	var who := ""
	var lines := PackedStringArray()
	var _tries := 0

	func _init(p_os, p_who: String) -> void:
		os = p_os
		who = p_who
		bare = true
		ident = "auth"
		var w := 290
		lines = wrapped(LANG.f("%s requires that you type an administrator's name and password.", [LANG.t(p_who)]), w - 64)
		var h := 112 + lines.size() * LINE
		rect = Rect2i((p_os.W - w) / 2, 50, w, h)
		var top := 12 + lines.size() * LINE + 4
		fields.append({"r": Rect2i(112, top, 160, 16), "text": "", "secret": false})
		fields.append({"r": Rect2i(112, top + 21, 160, 16), "text": "", "secret": true})
		focus = 0
		add_button(Rect2i(w - 142, h - 28, 58, 18), "Cancel", func(): os.close_dialog(self))
		add_button(Rect2i(w - 72, h - 28, 58, 18), "OK", _check, true)

	func draw_body(c: CanvasItem, r: Rect2i, _active: bool) -> void:
		os.icon(c, "key", r.position + Vector2i(8, 7), Color.WHITE)
		var y: int = r.position.y + 7
		for s in lines:
			text(c, r.position.x + 52, y, s, C_BLACK)
			y += LINE
		var f0: Rect2i = fields[0]["r"]
		var f1: Rect2i = fields[1]["r"]
		var lx := r.position.x + f0.position.x - 6
		var n := LANG.t("Name:")
		var p := LANG.t("Password:")
		text(c, lx - text_w(n, true), r.position.y + f0.position.y + 2, n, C_BLACK, true)
		text(c, lx - text_w(p, true), r.position.y + f1.position.y + 2, p, C_BLACK, true)

	func _check() -> void:
		_tries += 1
		os.busy(0.9, _refused)

	func _refused() -> void:
		fields[1]["text"] = ""
		focus = 1
		if _tries >= TRIES:
			os.close_dialog(self)
			os.alert("stop", LANG.t("You do not have enough access privileges."))
		else:
			os.alert("caution", LANG.t("The name or password is incorrect."))
