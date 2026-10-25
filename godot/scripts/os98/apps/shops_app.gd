extends Control

## Shops: SoftSklad's five programs on one tab: four for the camp's businesses
## (Hostinsky 98 for the pubs, Kuchar 98 for the bistros, Pult 98 for the Jednota, Klasek
## 98 for the corn stands; scripts/os98/apps/business_app.gd) and Personal 98 for the
## staffroom's hands (scripts/os98/apps/staff_app.gd). A strip of the five along the top;
## one without a licence is bought here, in this window, and is on the disk at once (playtest
## 25. 10.: "no downloading, no connecting through Beeternet, all of it in SoftSklad's
## window"); one licensed but not on the disk (bought on softsklad.cz, or by the other
## warden) installs with a click; the rest run below and keep their place when you switch.

const T = preload("res://scripts/os98/os_theme.gd")
const PAGE = preload("res://scripts/os98/os_page.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const APPS := [["pub_app", "pub"], ["bistro_app", "rest"], ["shop_app", "vecerka"], ["corn_app", "corn"], ["staff_app", "staff"]]
const STRIP_H := 28

var _shell
var _win
var _cur := ""
var _strip: Control
var _body: Control
var _subs: Dictionary = {}        # app id -> page holding its business_app
var _empty: Control
var _do: Button
var _hover := -1


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	_strip.draw.connect(_draw_strip)
	_strip.gui_input.connect(_strip_input)
	_strip.mouse_exited.connect(func():
		_hover = -1
		_strip.queue_redraw())
	add_child(_strip)
	_body = Control.new()
	_body.clip_contents = true
	add_child(_body)
	_empty = Control.new()
	_empty.draw.connect(_draw_empty)
	_body.add_child(_empty)
	_do = Button.new()
	_do.add_theme_font_override("font", T.FONT_BOLD)
	_do.focus_mode = Control.FOCUS_NONE
	_do.pressed.connect(_on_do)
	_empty.add_child(_do)
	resized.connect(_layout)
	_cur = str(args.get("program", _first_ready()))
	_layout()
	_switch(_cur)


func reopen(args: Dictionary) -> void:
	if args.has("program"):
		_switch(str(args["program"]))
	else:
		refresh()


func refresh() -> void:
	_switch(_cur)


func shown() -> void:
	refresh()


func install_tick() -> void:
	_update_empty()


func program_installed(_id: String) -> void:
	_switch(_cur)


func _first_ready() -> String:
	for a in APPS:
		if _shell._is_program_unlocked(str(a[0])):
			return str(a[0])
	for a in APPS:
		if _licensed(str(a[1])):
			return str(a[0])
	return "pub_app"


func _licensed(kind: String) -> bool:
	return CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.biz_has_licence(kind)


func _kind(app_id: String) -> String:
	for a in APPS:
		if str(a[0]) == app_id:
			return str(a[1])
	return "pub"


func _layout() -> void:
	if _strip == null:
		return
	_strip.position = Vector2.ZERO
	_strip.size = Vector2(size.x, STRIP_H)
	_body.position = Vector2(0, STRIP_H)
	_body.size = Vector2(size.x, size.y - STRIP_H)
	_empty.size = _body.size
	_do.size = Vector2(240, 26)
	_do.position = Vector2(floorf((_body.size.x - 240) * 0.5), 214)
	for k in _subs:
		(_subs[k] as Control).size = _body.size


func _switch(app_id: String) -> void:
	_cur = app_id
	var ready: bool = _shell._is_program_unlocked(app_id)
	if ready and not _subs.has(app_id):
		var page = PAGE.new()
		_body.add_child(page)
		page.setup(app_id, str(_shell.PROGRAMS[app_id]["title"]), _shell.icon(str(_shell.PROGRAMS[app_id]["icon"]), true), Rect2(Vector2.ZERO, _body.size))
		var app = load("res://scripts/os98/apps/staff_app.gd" if app_id == "staff_app" else "res://scripts/os98/apps/business_app.gd").new()
		page.content.add_child(app)
		app.size = page.client_size()
		page.resized.connect(func(): app.size = page.client_size())
		app.setup(_shell, page, {})
		_subs[app_id] = page
	for k in _subs:
		(_subs[k] as Control).visible = k == app_id and ready
	_empty.visible = not ready
	if ready:
		var a = (_subs[app_id] as Control).content.get_child(0)
		if a != null and a.has_method("refresh"):
			a.refresh()
	_win.title = str(_shell.PROGRAMS[app_id]["title"]) if _shell.PROGRAMS.has(app_id) else "Shops"
	_update_empty()
	_strip.queue_redraw()


func _update_empty() -> void:
	if not _empty.visible:
		return
	if _licensed(_kind(_cur)):
		_do.text = "Install"
	else:
		_do.text = "Buy the licence  ($%d)" % int(RULES.info(_kind(_cur)).get("licence", 0))
	_empty.queue_redraw()


func _on_do() -> void:
	_shell.play("click", -10.0)
	var kind := _kind(_cur)
	if _licensed(kind):
		_shell.install_program(_cur, false)
		_switch(_cur)
		return
	var info: Dictionary = RULES.info(kind)
	var app_id := _cur
	_shell.message_box("SoftSklad", tr("Buy a licence for %s for $%d?\n\nThe money is taken from the camp's account.") % [str(info.get("app_name", "")), int(info.get("licence", 0))], "question", ["Buy", "Cancel"], func(b: String):
		if b != "Buy" or not is_instance_valid(self):
			return
		if CoreRoot.actions.biz_buy_licence(kind):
			_shell.play("ding", -8.0)
			_shell.install_program(app_id, false)
			_switch(app_id)
		else:
			_shell.message_box("SoftSklad", tr("The payment was refused.\n\nThe camp has $%d.") % CoreRoot.get_money(), "error")
	)


# ── drawing ──────────────────────────────────────────────────────────────────

func _btn_rect(i: int) -> Rect2:
	var n := float(APPS.size())
	var w := floorf((size.x - 8 - 3 * (n - 1.0)) / n)
	return Rect2(4 + i * (w + 3), 3, w, STRIP_H - 6)


func _draw_strip() -> void:
	var c := _strip
	c.draw_rect(Rect2(Vector2.ZERO, c.size), T.FACE)
	c.draw_rect(Rect2(0, c.size.y - 2, c.size.x, 1), T.SHADOW)
	c.draw_rect(Rect2(0, c.size.y - 1, c.size.x, 1), T.WHITE)
	for i in APPS.size():
		var id := str(APPS[i][0])
		var r := _btn_rect(i)
		var on := id == _cur
		var installed: bool = _shell._is_program_unlocked(id)
		var lic := _licensed(str(APPS[i][1]))
		c.draw_style_box(T.box("pressed" if on else "raised", Color8(224, 224, 224) if on else (Color8(206, 214, 232) if _hover == i else T.FACE), Vector4.ZERO), r)
		var o := Vector2(1, 1) if on else Vector2.ZERO
		c.draw_texture_rect(_shell.icon(str(_shell.PROGRAMS[id]["icon"]), true), Rect2(r.position + Vector2(5, 3) + o, Vector2(16, 16)), false, Color.WHITE if installed else Color(1, 1, 1, 0.45))
		var label := str(_shell.PROGRAMS[id]["title"])
		c.draw_string(T.FONT, r.position + Vector2(26, 15) + o, label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 64, T.FONT_SIZE, T.TEXT if installed else T.TEXT_DISABLED)
		var tag := "" if installed else ("install" if lic else "buy")
		if tag != "":
			var tw := T.FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			c.draw_string(T.FONT, Vector2(r.end.x - tw - 6, r.position.y + 15) + o, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(0, 110, 0) if lic else T.SHADOW)


func _strip_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := -1
		for i in APPS.size():
			if _btn_rect(i).has_point(e.position):
				h = i
		if h != _hover:
			_hover = h
			_strip.queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in APPS.size():
			if _btn_rect(i).has_point(e.position) and str(APPS[i][0]) != _cur:
				_shell.play("click", -12.0)
				_switch(str(APPS[i][0]))


func _draw_empty() -> void:
	var c := _empty
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color8(255, 251, 232))
	var kind := _kind(_cur)
	var info: Dictionary = RULES.info(kind)
	var col := {"pub": Color8(110, 28, 16), "rest": Color8(22, 82, 40), "vecerka": Color8(150, 20, 20), "corn": Color8(150, 110, 0), "staff": Color8(70, 54, 30)}.get(kind, T.NAVY) as Color
	c.draw_rect(Rect2(0, 0, s.x, 34), col)
	c.draw_string(T.FONT_BOLD, Vector2(12, 22), "%s  -  %s" % [str(_shell.PROGRAMS[_cur]["title"]), str(info.get("name", ""))], HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	c.draw_texture(_shell.icon(str(_shell.PROGRAMS[_cur]["icon"])), Vector2(floorf(s.x * 0.5 - 16), 60))
	var lines: Array = []
	if _licensed(kind):
		lines = ["The licence is paid. The program is not on this computer yet."]
	elif kind == "staff":
		lines = ["Your own staff from this desk: who you take on, what each of them",
			"sees to, their lockers and their day.",
			"A licence costs $%d, paid once." % int(info.get("licence", 0))]
	else:
		lines = ["Run the %s from this desk: stock, orders to the wholesaler," % str(info.get("name", "business")).to_lower(),
			"staff and the takings, on one screen.",
			"A licence costs $%d, paid once." % int(info.get("licence", 0))]
	var y := 118.0
	for l in lines:
		var tw := T.FONT.get_string_size(str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		c.draw_string(T.FONT, Vector2(floorf((s.x - tw) * 0.5), y), str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
		y += 15.0
