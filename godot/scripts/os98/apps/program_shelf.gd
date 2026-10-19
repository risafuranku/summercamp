extends Control

## A program group on one tab (Jobs, Games), the way an Okna 98 folder looked in Web
## View: down the left the folder's name in big letters over the coloured rule, its
## programs as a list (the picked one in the selection colour), and under them what the
## picked one is (the maker, the version, the date, the size); the program itself on the
## right. A program not on the disk yet says what it is and installs with one click
## (os_shell.begin_install); the ones that run keep their place while you look at another.
## Subclasses give `_entries()` and `_heading()`, and may give `_card_status(id)` and
## `_cover_lines(id)`. Everything here is the system's own wording: plain, about files.

const T = preload("res://scripts/os98/os_theme.gd")
const PAGE = preload("res://scripts/os98/os_page.gd")
const PROGRESS = preload("res://scripts/os98/os_progress.gd")
const LIST_W := 168
const CARD_H := 44
const HEAD_H := 54

var _shell
var _win
var _cur := ""
var _list: Control
var _host: Control
var _subs: Dictionary = {}
var _cover: Control
var _do: Button
var _bar
var _hover := -1
var _tick := 0.0


## [{id, script, line}]: the programs on this shelf, in order.
func _entries() -> Array:
	return []


## [folder name, its icon] over the list.
func _heading() -> Array:
	return ["", "folder"]


## A short line under a card (today's count, the best score).
func _card_status(_id: String) -> String:
	return ""


## What the cover says about a program not installed yet.
func _cover_lines(_id: String) -> Array:
	return []


## The cover's button when it is not installing.
func _cover_button(id: String) -> String:
	return "Download  (%d KB)" % int(_shell.PROGRAMS[id]["kb"])


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_list.draw.connect(_draw_list)
	_list.gui_input.connect(_list_input)
	_list.mouse_exited.connect(func():
		_hover = -1
		_list.queue_redraw())
	add_child(_list)
	_host = Control.new()
	_host.clip_contents = true
	add_child(_host)
	_cover = Control.new()
	_cover.draw.connect(_draw_cover)
	_host.add_child(_cover)
	_do = Button.new()
	_do.add_theme_font_override("font", T.FONT_BOLD)
	_do.focus_mode = Control.FOCUS_NONE
	_do.pressed.connect(func():
		_shell.play("click", -10.0)
		_shell.begin_install(_cur)
		_update_cover())
	_cover.add_child(_do)
	_bar = PROGRESS.new("install")
	_bar.show_percent = true
	_cover.add_child(_bar)
	resized.connect(_layout)
	var first := str(args.get("program", ""))
	if first == "":
		for e in _entries():
			if _shell._is_program_unlocked(str(e["id"])):
				first = str(e["id"])
				break
	if first == "" and not _entries().is_empty():
		first = str(_entries()[0]["id"])
	_layout()
	_switch(first)


func reopen(args: Dictionary) -> void:
	if args.has("program"):
		_switch(str(args["program"]))


func refresh() -> void:
	_list.queue_redraw()


func shown() -> void:
	_switch(_cur)


func install_tick() -> void:
	_update_cover()
	_list.queue_redraw()


func program_installed(id: String) -> void:
	if id == _cur:
		_switch(_cur)
	_list.queue_redraw()


## The program now running on the right, or null.
func current_app() -> Control:
	var p: Control = _subs.get(_cur)
	if p == null or p.content.get_child_count() == 0:
		return null
	return p.content.get_child(0)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0 and is_visible_in_tree():
		_tick = 1.0
		_list.queue_redraw()


func _layout() -> void:
	if _list == null:
		return
	_list.position = Vector2.ZERO
	_list.size = Vector2(LIST_W, size.y)
	_host.position = Vector2(LIST_W + 2, 0)
	_host.size = Vector2(size.x - LIST_W - 2, size.y)
	_cover.size = _host.size
	_do.size = Vector2(240, 26)
	_do.position = Vector2(floorf((_host.size.x - 240) * 0.5), 250)
	_bar.position = Vector2(floorf((_host.size.x - 300) * 0.5), 222)
	_bar.size = Vector2(300, 18)
	for k in _subs:
		(_subs[k] as Control).size = _host.size


func _entry(id: String) -> Dictionary:
	for e in _entries():
		if str(e["id"]) == id:
			return e
	return {}


func _switch(id: String) -> void:
	if id == "":
		return
	if id != _cur:
		var old = current_app()
		if old != null and old.has_method("page_hidden"):
			old.page_hidden()
	_cur = id
	var ready: bool = _shell._is_program_unlocked(id)
	if ready and not _subs.has(id):
		var e := _entry(id)
		var page = PAGE.new()
		_host.add_child(page)
		page.setup(id, str(_shell.PROGRAMS[id]["title"]), _shell.icon(str(_shell.PROGRAMS[id]["icon"]), true), Rect2(Vector2.ZERO, _host.size))
		var app = load("res://scripts/os98/apps/%s.gd" % str(e.get("script", id))).new()
		page.content.add_child(app)
		app.size = page.client_size()
		page.resized.connect(func(): app.size = page.client_size())
		if app.has_method("setup"):
			app.setup(_shell, page, {})
		_subs[id] = page
	for k in _subs:
		(_subs[k] as Control).visible = k == id and ready
	_cover.visible = not ready
	var a = current_app()
	if a != null and a.has_method("shown"):
		a.shown()
	_win.title = "%s - %s" % [str(_shell.PROGRAMS[id]["title"]), str(_heading()[0])]
	_update_cover()
	_list.queue_redraw()


func _update_cover() -> void:
	if not _cover.visible:
		return
	var p: float = _shell.install_progress(_cur)
	_bar.visible = p >= 0.0
	if p >= 0.0:
		_bar.value = p
	_do.disabled = p >= 0.0
	_do.text = _shell.install_status(_cur) if p >= 0.0 else _cover_button(_cur)
	_cover.queue_redraw()


# ── the list ─────────────────────────────────────────────────────────────────

func _card_rect(i: int) -> Rect2:
	return Rect2(4, HEAD_H + 4 + i * (CARD_H + 2), LIST_W - 8, CARD_H)


## What the folder pane says about a program: the lines under its name.
func _describe(id: String) -> Array:
	var info: Array = _shell.PROGRAM_INFO.get(id, ["", "", ""])
	var out: Array = ["Application"]
	if str(info[0]) != "":
		out.append(str(info[0]))
	if str(info[1]) != "":
		out.append("Version %s" % info[1])
	if str(info[2]) != "":
		out.append("Modified: %s" % info[2])
	out.append("Size: %d KB" % int(_shell.PROGRAMS[id].get("kb", 0)))
	return out


func _draw_list() -> void:
	var c := _list
	var head: Array = _heading()
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), T.WHITE)
	c.draw_rect(Rect2(s.x - 1, 0, 1, s.y), T.SHADOW)
	# The folder's name, big, and the rule of colours under it.
	c.draw_texture(_shell.icon(str(head[1])), Vector2(8, 8))
	c.draw_string(T.FONT_BOLD, Vector2(46, 34), str(head[0]), HORIZONTAL_ALIGNMENT_LEFT, s.x - 50, T.FONT_SIZE * 2, T.TEXT)
	var rule_w := s.x - 16
	for x in int(rule_w):
		var k := float(x) / rule_w
		var col: Color = T.NAVY.lerp(Color8(0, 160, 160), k * 2.0) if k < 0.5 else Color8(0, 160, 160).lerp(Color8(240, 210, 60), (k - 0.5) * 2.0)
		c.draw_rect(Rect2(8 + x, 46, 1, 2), col)
	var es := _entries()
	for i in es.size():
		var id := str(es[i]["id"])
		var r := _card_rect(i)
		var on := id == _cur
		var ready: bool = _shell._is_program_unlocked(id)
		if on:
			c.draw_rect(r, T.NAVY)
		elif _hover == i:
			c.draw_rect(r, Color8(228, 234, 248))
		c.draw_texture(_shell.icon(str(_shell.PROGRAMS[id]["icon"])), r.position + Vector2(4, 6), Color.WHITE if ready else Color(1, 1, 1, 0.4))
		var name_col := T.WHITE if on else (T.TEXT if ready else T.TEXT_DISABLED)
		c.draw_string(T.FONT_BOLD, r.position + Vector2(42, 18), str(_shell.PROGRAMS[id]["title"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 46, T.FONT_SIZE, name_col)
		var p: float = _shell.install_progress(id)
		var st := ("Installing... %d%%" % int(p * 100.0)) if p >= 0.0 else (_card_status(id) if ready else "Not installed")
		c.draw_string(T.FONT, r.position + Vector2(42, 33), st, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 46, T.FONT_SIZE, Color8(200, 210, 255) if on else T.SHADOW)
	# Under the list: what the picked one is, as Properties would say.
	var y := HEAD_H + 12 + es.size() * (CARD_H + 2)
	c.draw_rect(Rect2(8, y - 6, s.x - 16, 1), Color8(210, 210, 210))
	if _cur != "" and _shell.PROGRAMS.has(_cur):
		c.draw_string(T.FONT_BOLD, Vector2(8, y + 8), str(_shell.PROGRAMS[_cur]["title"]), HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, T.TEXT)
		y += 22
		for l in _describe(_cur):
			c.draw_string(T.FONT, Vector2(8, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, T.TEXT)
			y += 14
	else:
		c.draw_string(T.FONT, Vector2(8, y + 8), "Select an item to view its description.", HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, T.TEXT)
	c.draw_string(T.FONT, Vector2(8, s.y - 8), "%d object(s)" % es.size(), HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, T.SHADOW)


func _list_input(e: InputEvent) -> void:
	var es := _entries()
	if e is InputEventMouseMotion:
		var h := -1
		for i in es.size():
			if _card_rect(i).has_point(e.position):
				h = i
		if h != _hover:
			_hover = h
			_list.queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in es.size():
			if _card_rect(i).has_point(e.position) and str(es[i]["id"]) != _cur:
				_shell.play("click", -12.0)
				_switch(str(es[i]["id"]))


func _draw_cover() -> void:
	var c := _cover
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color8(240, 240, 232))
	var box := Rect2(floorf((s.x - 380) * 0.5), 40, 380, 260)
	c.draw_style_box(T.box("window", T.FACE), box)
	var band := Rect2(box.position + Vector2(3, 3), Vector2(box.size.x - 6, 18))
	for i in int(ceil(band.size.x / 8.0)):
		c.draw_rect(Rect2(band.position.x + i * 8, band.position.y, minf(8.0, band.size.x - i * 8), band.size.y), T.TITLE_A.lerp(T.TITLE_B, float(i * 8) / band.size.x))
	c.draw_string(T.FONT_BOLD, band.position + Vector2(5, 13), str(_shell.PROGRAMS[_cur]["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	c.draw_texture(_shell.icon(str(_shell.PROGRAMS[_cur]["icon"])), box.position + Vector2(16, 34))
	var y := box.position.y + 46
	for l in _cover_lines(_cur):
		c.draw_string(T.FONT, Vector2(box.position.x + 60, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 70, T.FONT_SIZE, T.TEXT)
		y += 15
	c.draw_string(T.FONT, Vector2(box.position.x + 60, box.position.y + 168), "From: http://www.%s/  (%s)" % [_shell.PROGRAMS[_cur]["site"], _shell.PROGRAMS[_cur]["file"]], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 70, T.FONT_SIZE, T.SHADOW)
