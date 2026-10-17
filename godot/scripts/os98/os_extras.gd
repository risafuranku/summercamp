extends Control

## The things that made a 1998 desktop feel like a machine and not a picture of one
## (scripts/os98/os_shell.gd owns the desktop, windows and taskbar):
##   - windows zoom open from where they came from and shrink into the taskbar (the
##     outline rectangles, in steps);
##   - right-click on the desktop: the context menu (Arrange Icons, Refresh, Properties);
##   - Display Properties (scripts/os98/apps/display_app.gd): the wallpaper and the
##     screen saver;
##   - the screen saver: after the wait with nobody at the keyboard, Flying Okna (the
##     logo coming at you out of the dark) or Starfield. You see it from across the
##     office, too. Any key or the mouse wakes the desktop.

const T = preload("res://scripts/os98/os_theme.gd")
const LOGO := "res://assets/textury/os98/okna_logo_small.png"
const SAVERS := ["Flying Okna", "Starfield", "Blank Screen", "(None)"]

var shell
var saver := "Flying Okna"
## Seconds of nobody at the computer. It never comes on while you sit at it (playtest
## 2026-10-17: it came on while reading and got in the way); only an empty desk gets it.
var saver_wait := 120.0
var _idle := 0.0
var _saving := false
var _zooms: Array = []          # {from, to, t}
var _menu: Control
var _stars: Array = []
var _logos: Array = []
var _logo_tex: Texture2D
var _t := 0.0
var _drawn := false


func setup(shell_node) -> void:
	shell = shell_node
	size = shell.SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_tex = load(LOGO) if ResourceLoader.exists(LOGO) else null
	_reset_saver_field()


func export_state() -> Dictionary:
	return {"saver": saver, "saver_wait": saver_wait}


func import_state(d: Dictionary) -> void:
	saver = str(d.get("saver", saver))
	saver_wait = maxf(60.0, float(d.get("saver_wait", saver_wait)))


## Somebody touched the keyboard or the mouse.
func poke() -> void:
	_idle = 0.0
	if _saving:
		_saving = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()


func is_saving() -> bool:
	return _saving


# ── the zoom rectangles ──────────────────────────────────────────────────────

func zoom(from: Rect2, to: Rect2) -> void:
	_zooms.append({"from": from, "to": to, "t": 0.0})


func _process(delta: float) -> void:
	_t += delta
	if shell == null:
		return
	if shell.is_desktop_ready():
		# Somebody is at it: no saver, and the wait starts again when they get up.
		_idle = 0.0 if shell.is_open() else _idle + delta
		# Never while somebody sits at it, however they got there (playtest 2026-10-17:
		# it blocked the game a second time): sitting down is touching the mouse.
		if _saving and shell.is_open():
			poke()
		if not _saving and saver != "(None)" and _idle >= saver_wait:
			_saving = true
			mouse_filter = Control.MOUSE_FILTER_STOP
			_reset_saver_field()
	for z in _zooms:
		z["t"] = float(z["t"]) + delta
	_zooms = _zooms.filter(func(z): return float(z["t"]) < 0.24)
	if _saving:
		_tick_saver(delta)
	if _saving or not _zooms.is_empty():
		move_to_front()
		queue_redraw()
		_drawn = true
	elif _drawn:
		# One more frame to wipe the last outline.
		_drawn = false
		queue_redraw()


func _draw() -> void:
	if _saving:
		_draw_saver()
		return
	for z in _zooms:
		# Four outlines trailing each other, in steps of a 60th.
		var k := floorf(clampf(float(z["t"]) / 0.22, 0.0, 1.0) * 8.0) / 8.0
		for j in 3:
			var kk := clampf(k - j * 0.12, 0.0, 1.0)
			var from: Rect2 = z["from"]
			var to: Rect2 = z["to"]
			var r := Rect2(from.position.lerp(to.position, kk), from.size.lerp(to.size, kk))
			draw_rect(r, Color(0.5, 0.5, 0.5), false, 2.0)


# ── the desktop's context menu ───────────────────────────────────────────────

func desktop_menu(at: Vector2) -> void:
	close_menu()
	var items := [["Arrange Icons", "arrange"], ["Line up Icons", "lineup"], ["-", ""], ["Refresh", "refresh"], ["-", ""], ["Paste", ""], ["Paste Shortcut", ""], ["-", ""], ["New", ""], ["-", ""], ["Properties", "props"]]
	var w := 150.0
	var h := 4.0
	for it in items:
		h += 8.0 if it[0] == "-" else 18.0
	var pos := Vector2(minf(at.x, shell.SCREEN.x - w), minf(at.y, shell.DESKTOP_SIZE.y - h))
	_menu = Control.new()
	_menu.position = pos
	_menu.size = Vector2(w, h)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.draw.connect(func(): _menu.draw_style_box(T.box("window", T.FACE), Rect2(Vector2.ZERO, _menu.size)))
	shell.add_child(_menu)
	var y := 2.0
	for it in items:
		if it[0] == "-":
			var sep := Control.new()
			sep.position = Vector2(2, y)
			sep.size = Vector2(w - 4, 8)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sep.draw.connect(func():
				sep.draw_rect(Rect2(2, 3, w - 8, 1), T.SHADOW)
				sep.draw_rect(Rect2(2, 4, w - 8, 1), T.WHITE)
			)
			_menu.add_child(sep)
			y += 8.0
			continue
		var c := _item(str(it[0]), str(it[1]), Vector2(2, y), Vector2(w - 4, 18))
		_menu.add_child(c)
		y += 18.0


func close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func menu_open() -> bool:
	return _menu != null and is_instance_valid(_menu)


func _item(text: String, action: String, pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("hover", false)
	var enabled := action != ""
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		c.queue_redraw()
	)
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		c.queue_redraw()
	)
	c.draw.connect(func():
		var hov := bool(c.get_meta("hover"))
		if hov:
			c.draw_rect(Rect2(Vector2.ZERO, sz), T.NAVY)
		var col := T.WHITE if hov else (T.TEXT if enabled else T.TEXT_DISABLED)
		if not enabled and not hov:
			c.draw_string(T.FONT, Vector2(21, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
		c.draw_string(T.FONT, Vector2(20, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)
		if text in ["Arrange Icons", "New"]:
			var ax := sz.x - 10
			for k in 4:
				c.draw_rect(Rect2(ax + k, 9 - 3 + k, 1, 7 - k * 2), col)
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_menu()
			_do(action)
			c.accept_event()
	)
	return c


func _do(action: String) -> void:
	match action:
		"arrange", "lineup", "refresh":
			shell._refresh_desktop_icons()
			shell.play("click", -12.0)
		"props":
			shell.open_app("display")


# ── the screen saver ─────────────────────────────────────────────────────────

func _reset_saver_field() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 98
	_stars.clear()
	for i in 90:
		_stars.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(0.1, 1.0)))
	_logos.clear()
	for i in 14:
		_logos.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(0.1, 1.0)))


func _tick_saver(delta: float) -> void:
	var speed := 0.32 if saver == "Flying Okna" else 0.5
	var field: Array = _logos if saver == "Flying Okna" else _stars
	for i in field.size():
		var p: Vector3 = field[i]
		p.z -= delta * speed
		if p.z <= 0.02:
			p = Vector3(randf_range(-1, 1), randf_range(-1, 1), 1.0)
		field[i] = p


func _draw_saver() -> void:
	var s: Vector2 = shell.SCREEN
	draw_rect(Rect2(Vector2.ZERO, s), Color.BLACK)
	if saver == "Blank Screen":
		return
	var c := s * 0.5
	if saver == "Starfield":
		for p: Vector3 in _stars:
			var q := c + Vector2(p.x, p.y) / p.z * 220.0
			var b := clampf(1.2 - p.z, 0.2, 1.0)
			var px := 2.0 if p.z < 0.35 else 1.0
			draw_rect(Rect2(q.floor(), Vector2(px, px)), Color(b, b, b))
		return
	# Flying Okna: the four-pane window logo coming out of the dark, far ones first.
	var sorted := _logos.duplicate()
	sorted.sort_custom(func(a, b): return a.z > b.z)
	for p: Vector3 in sorted:
		var q := c + Vector2(p.x, p.y) / p.z * 200.0
		var sz := 26.0 / p.z
		var a := clampf((1.0 - p.z) * 1.6, 0.0, 1.0)
		if _logo_tex != null:
			draw_texture_rect(_logo_tex, Rect2(q - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, a))
		else:
			var cols := [Color8(220, 40, 30), Color8(40, 170, 60), Color8(40, 90, 220), Color8(240, 200, 30)]
			for k in 4:
				var o: Vector2 = Vector2(k % 2, k / 2) * sz * 0.5
				draw_rect(Rect2(q - Vector2(sz, sz) * 0.5 + o, Vector2(sz, sz) * 0.46), Color(cols[k], a))
