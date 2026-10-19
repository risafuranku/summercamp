extends Control

## KlikBanka 98: Bohemia Online pays its members to confirm they have seen its adverts.
## A shift is forty seconds of pop-up windows on a little desktop. A real advert you
## confirm with its OK ($1); what is not an advert (the prize, the virus, the chain
## letter) you close with its x; clicking its big button is a mistake and costs $2 of the
## shift's pay. Adverts left alone go away unpaid. Paid at the end of the shift, up to
## DAY_LIMIT a day (os_shell.job_done / job_add).
##
## Now and then a notice comes up that is neither, and will not close.

const T = preload("res://scripts/os98/os_theme.gd")
const DAY_LIMIT := 30
const SHIFT_SEC := 40.0
const HEAD_H := 46
const POP := Vector2(214, 96)
const MAX_OPEN := 7
const ADS := [
	["Budvar", "BUDVAR 12", "Beer from Budweis.\nOn tap at Hostinec U Jezera."],
	["Jednota Lesna", "JEDNOTA LESNA", "Rolls 1.20 Kc!\nBatteries: still sold out."],
	["CSAD Jihlava", "LINE 380", "The bus to the reservoir.\nIt stops where it stops."],
	["Bohemia Online", "BOHEMIA ONLINE", "The Internet for 1.20 Kc\na minute. Since 1996."],
	["Kofola", "KOFOLA", "If you love it,\nthere is nothing to discuss."],
	["Hostinec U Jezera", "U JEZERA", "Karbanatky to our own recipe.\nOpen till ten. Do not knock."],
	["Stavitel software", "BUILDER 98", "Register now! 990 Kc.\nPlan more than one site."],
	["Agrostroj Hlubocany", "AGROSTROJ", "Feed for the nation.\nSoon by the reservoir."],
	["Okna 98", "OKNA 98", "Now with Beeternet\nExplorer 4.01 inside."],
	["Bazar Hlubocany", "BAZAR", "Buy and sell in the district.\nAds free."],
]
const SCAMS := [
	["CONGRATULATIONS!!!", "YOU HAVE WON!", "You are the 1,000,000th visitor!\nClaim your Skoda Felicia now!", "CLAIM!"],
	["WARNING - VIRUS", "1998 VIRUSES FOUND", "Your computer is infected.\nClick to remove them all.", "REMOVE"],
	["FREE RAM", "MORE MEMORY FREE", "Download MORERAM.EXE and\nyour PC runs twice as fast!", "DOWNLOAD"],
	["Chain letter", "SEND TO 10 FRIENDS", "or the man in the hat will\nstand behind you tonight.", "SEND"],
	["SPORTKA", "YOU WON 2,000,000 KC", "Send us your bank details\nto collect your prize.", "COLLECT"],
	["Lonely?", "SINGLE TRACTORS", "in your district want\nto meet you. Click now!", "MEET"],
	["Free screensaver", "DANCING HAMSTER 3D", "The funniest screensaver of\n1998! Install it now!", "INSTALL"],
]

var _shell
var _win
var _area: Control
var _start: Button
var _pops: Array = []
var _state := "idle"            # idle, shift, done
var _t := 0.0
var _spawn := 0.0
var _ok := 0
var _bad := 0
var _missed := 0
var _paid := 0
var _rng := RandomNumberGenerator.new()
var _missing_shown := false
var _last_ad := -1


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.clip_contents = true
	_area.draw.connect(_draw_area)
	_area.gui_input.connect(_area_input)
	add_child(_area)
	_start = Button.new()
	_start.text = "Start a shift"
	_start.add_theme_font_override("font", T.FONT_BOLD)
	_start.focus_mode = Control.FOCUS_NONE
	_start.pressed.connect(_begin)
	_area.add_child(_start)
	resized.connect(_layout)
	_layout()


func page_hidden() -> void:
	# Walking away from a shift ends it (the adverts do not wait for you).
	if _state == "shift":
		_end()


func _layout() -> void:
	if _area == null:
		return
	_area.position = Vector2(0, HEAD_H)
	_area.size = Vector2(size.x, size.y - HEAD_H)
	_start.size = Vector2(160, 28)
	_start.position = Vector2(floorf((_area.size.x - 160) * 0.5), floorf(_area.size.y * 0.5 + 34))


func _left_today() -> int:
	return maxi(0, DAY_LIMIT - _shell.job_done("adclick"))


func _begin() -> void:
	if _left_today() <= 0:
		_shell.message_box("KlikBanka 98", "Bohemia Online has no more adverts for you today.\n\nCome back tomorrow.", "info")
		return
	_shell.play("click", -8.0)
	_pops.clear()
	_state = "shift"
	_t = 0.0
	_spawn = 0.4
	_ok = 0
	_bad = 0
	_missed = 0
	_missing_shown = false
	_start.visible = false
	queue_redraw()


func _end() -> void:
	_state = "done"
	_pops.clear()
	var pay := clampi(_ok - 2 * _bad, 0, _left_today())
	_paid = pay
	if pay > 0:
		_shell.earn(pay)
		_shell.job_add("adclick", pay)
	_shell.play("ding", -8.0)
	_start.visible = true
	_start.text = "Another shift" if _left_today() > 0 else "Done for today"
	_start.disabled = _left_today() <= 0
	_area.queue_redraw()
	queue_redraw()


func _process(delta: float) -> void:
	if _state != "shift":
		return
	_t += delta
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = lerpf(1.25, 0.55, clampf(_t / SHIFT_SEC, 0.0, 1.0)) * _rng.randf_range(0.7, 1.3)
		if _pops.size() < MAX_OPEN:
			_add_pop()
	for i in range(_pops.size() - 1, -1, -1):
		var p: Dictionary = _pops[i]
		p["t"] = float(p["t"]) + delta
		p["shake"] = maxf(0.0, float(p.get("shake", 0.0)) - delta)
		if float(p["t"]) >= float(p["life"]):
			if str(p["kind"]) == "ad":
				_missed += 1
			_pops.remove_at(i)
	if _t >= SHIFT_SEC:
		_end()
		return
	_area.queue_redraw()
	queue_redraw()


func _add_pop() -> void:
	var pos := Vector2(_rng.randf_range(4, _area.size.x - POP.x - 4), _rng.randf_range(4, _area.size.y - POP.y - 4)).floor()
	var p := {"t": 0.0, "rect": Rect2(pos, POP), "shake": 0.0}
	var roll := _rng.randf()
	if not _missing_shown and _t > 12.0 and roll < 0.05:
		_missing_shown = true
		p.merge({"kind": "missing", "title": "Notice", "head": "MISSING", "body": "Jana K. (11). Last seen at the\nCerne jezero camp, August 1987.", "btn": "OK", "life": 9.0})
	elif roll < 0.42:
		var s: Array = SCAMS[_rng.randi_range(0, SCAMS.size() - 1)]
		p.merge({"kind": "scam", "title": s[0], "head": s[1], "body": s[2], "btn": s[3], "life": 5.0})
	else:
		var i := _rng.randi_range(0, ADS.size() - 1)
		if i == _last_ad:
			i = (i + 1) % ADS.size()
		_last_ad = i
		var a: Array = ADS[i]
		p.merge({"kind": "ad", "title": a[0], "head": a[1], "body": a[2], "btn": "OK", "life": 4.6})
	_pops.append(p)
	_shell.play("ding", -22.0)


func _close_rect(r: Rect2) -> Rect2:
	return Rect2(r.end.x - 19, r.position.y + 5, 14, 12)


func _btn_rect(r: Rect2) -> Rect2:
	return Rect2(r.position.x + floorf((r.size.x - 84) * 0.5), r.end.y - 26, 84, 20)


func _area_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or _state != "shift":
		return
	for i in range(_pops.size() - 1, -1, -1):
		var p: Dictionary = _pops[i]
		var r: Rect2 = p["rect"]
		if not r.has_point(e.position):
			continue
		var kind := str(p["kind"])
		if _close_rect(r).has_point(e.position):
			if kind == "missing" and float(p["t"]) < 3.0:
				# It does not close. Not yet.
				p["shake"] = 0.4
				_shell.play("ding", -12.0)
				return
			_shell.play("click", -16.0)
			if kind == "ad":
				_missed += 1
			_pops.remove_at(i)
		elif _btn_rect(r).has_point(e.position):
			match kind:
				"ad":
					_ok += 1
					_shell.play("click", -10.0)
				"scam":
					_bad += 1
					_shell.play("ding", -6.0)
					# What it does: more of them.
					for k in 2:
						if _pops.size() < MAX_OPEN + 2:
							var s: Array = SCAMS[_rng.randi_range(0, SCAMS.size() - 1)]
							var pos := (r.position + Vector2(18 + k * 18, 16 + k * 16)).clamp(Vector2(4, 4), _area.size - POP - Vector2(4, 4))
							_pops.append({"t": 0.0, "rect": Rect2(pos, POP), "shake": 0.0, "kind": "scam", "title": s[0], "head": s[1], "body": s[2], "btn": s[3], "life": 5.0})
				_:
					_shell.play("click", -14.0)
			_pops.remove_at(i)
		else:
			# Brought to the front.
			_pops.remove_at(i)
			_pops.append(p)
		_area.queue_redraw()
		queue_redraw()
		return


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, HEAD_H), Color8(250, 214, 40))
	draw_rect(Rect2(0, HEAD_H - 2, w, 2), Color8(120, 90, 0))
	draw_string(T.FONT_BOLD, Vector2(10, 20), "KlikBanka 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(150, 0, 0))
	draw_string(T.FONT, Vector2(12, 38), "Bohemia Online pays you to look at adverts.", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(80, 40, 0))
	var cells := [
		["TODAY", "$%d / $%d" % [_shell.job_done("adclick"), DAY_LIMIT]],
		["SHIFT", ("0:%02d" % int(ceil(SHIFT_SEC - _t))) if _state == "shift" else "-"],
		["PAY", "$%d" % maxi(0, _ok - 2 * _bad)],
	]
	var x := w - 4.0
	for i in range(cells.size() - 1, -1, -1):
		var cw := 70.0
		x -= cw
		var r := Rect2(x, 6, cw, HEAD_H - 14)
		draw_style_box(T.box("field", Color8(20, 20, 20), Vector4.ZERO), r)
		draw_string(T.FONT, r.position + Vector2(5, 12), str(cells[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(120, 200, 120))
		draw_string(T.FONT_BOLD, r.position + Vector2(5, 26), str(cells[i][1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 8, T.FONT_SIZE, Color8(90, 255, 120))
		x -= 4.0


func _draw_area() -> void:
	var c := _area
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color8(0, 104, 104))
	# The wallpaper of a member's PC: a tiled K.
	for yy in range(0, int(s.y), 48):
		for xx in range(0, int(s.x), 64):
			c.draw_string(T.FONT_BOLD, Vector2(xx + 22 + (yy / 48 % 2) * 32, yy + 30), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(0, 118, 118))
	if _state == "shift":
		var bar := Rect2(0, s.y - 4, s.x * (1.0 - _t / SHIFT_SEC), 4)
		c.draw_rect(bar, Color8(250, 214, 40))
		for p in _pops:
			_draw_pop(c, p)
		return
	var box := Rect2(floorf((s.x - 330) * 0.5), floorf(s.y * 0.5 - 92), 330, 168)
	c.draw_style_box(T.box("window", T.FACE), box)
	var lines: Array = []
	if _state == "done":
		lines = ["SHIFT OVER", "Confirmed %d adverts, missed %d." % [_ok, _missed], "Mistakes: %d  (-$%d)" % [_bad, 2 * _bad], "Paid into the camp's account: $%d" % _paid]
	else:
		lines = ["HOW IT WORKS", "Adverts pop up for 40 seconds.", "A real advert: click its OK.  ($1)", "A prize, a virus, a chain letter: close it (x).", "Click their button and it costs you $2."]
	var y := box.position.y + 24
	for i in lines.size():
		c.draw_string(T.FONT_BOLD if i == 0 else T.FONT, Vector2(box.position.x + 18, y), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 30, T.FONT_SIZE, T.NAVY if i == 0 else T.TEXT)
		y += 17


func _draw_pop(c: Control, p: Dictionary) -> void:
	var r: Rect2 = p["rect"]
	if float(p.get("shake", 0.0)) > 0.0:
		r.position.x += sin(float(p["shake"]) * 60.0) * 3.0
	var kind := str(p["kind"])
	var age := float(p["t"])
	c.draw_style_box(T.box("window", T.FACE), r)
	var band := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 16))
	var a := T.TITLE_A
	var b := T.TITLE_B
	if kind == "missing":
		a = Color8(40, 40, 40)
		b = Color8(90, 90, 90)
	c.draw_rect(band, a)
	c.draw_rect(Rect2(band.position + Vector2(band.size.x * 0.5, 0), Vector2(band.size.x * 0.5, band.size.y)), b)
	c.draw_string(T.FONT_BOLD, band.position + Vector2(4, 12), str(p["title"]), HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 24, T.FONT_SIZE, T.WHITE)
	var cr := _close_rect(r)
	c.draw_style_box(T.box("raised", T.FACE, Vector4.ZERO), cr)
	for i in 5:
		c.draw_rect(Rect2(cr.position + Vector2(4 + i, 3 + i), Vector2(2, 1)), T.DARK)
		c.draw_rect(Rect2(cr.position + Vector2(8 - i, 3 + i), Vector2(2, 1)), T.DARK)
	var head := str(p["head"])
	var head_col := Color8(0, 0, 128)
	if kind == "scam":
		head_col = Color8(220, 0, 0) if fmod(age, 0.5) < 0.25 else Color8(255, 120, 0)
	elif kind == "missing":
		head_col = Color8(20, 20, 20)
	c.draw_string(T.FONT_BOLD, r.position + Vector2(10, 35), head, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, T.FONT_SIZE, head_col)
	var y := r.position.y + 50
	for l in str(p["body"]).split("\n"):
		c.draw_string(T.FONT, Vector2(r.position.x + 10, y), l, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, T.FONT_SIZE, T.TEXT)
		y += 13
	var br := _btn_rect(r)
	var face := Color8(255, 230, 60) if kind == "scam" else T.FACE
	c.draw_style_box(T.box("raised", face, Vector4.ZERO), br)
	c.draw_string(T.FONT_BOLD, br.position + Vector2(0, 14), str(p["btn"]), HORIZONTAL_ALIGNMENT_CENTER, br.size.x, T.FONT_SIZE, T.TEXT)
	# How long it stays: a thin line along the bottom that shrinks.
	var left := clampf(1.0 - age / float(p["life"]), 0.0, 1.0)
	c.draw_rect(Rect2(r.position.x + 3, r.end.y - 4, (r.size.x - 6) * left, 1), Color8(0, 0, 0, 90))
