extends RefCounted

## The configuration as printouts on the counter (a title_desk.gd page; main_menu.gd's
## CONFIGURATION): the machine's settings typed out on the striped computer paper, each
## value between the two arrows that step it, a scale filled in in pencil boxes; the
## other sheets are the warden's view and body, the controls (out in the camp, indoors:
## the keys that can be changed are changed there, a click and the new key) and the
## credits, their names punched on the tapes beside the paper. The rows and what they do:
## scripts/ui/settings_rows.gd (the pause menu's plate does the same with them).

const ROWS = preload("res://scripts/ui/settings_rows.gd")
const SETTINGS_PANEL = preload("res://scripts/settings_panel.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")
const SFX_STEP := "res://assets/sfx/desk/pen.mp3"
const SFX_SHEET := "res://assets/sfx/desk/paper_slide.mp3"
const SHEET := Rect2(16, 10, 360, 252)
## On the sheet: the names' column, the scale's, the value between its arrows.
const X := 34.0
const BAR_X := 176.0
const LEFT_ARROW := 262.0
const RIGHT_ARROW := 354.0
const Y0 := 56.0
const PITCH := 15.0
const KEYS_X := 360.0
const CONTROL_PITCH := 13.0
const TAPE_X := 428.0
const TAPE_Y0 := 30.0
const TAPE_PITCH := 16.0
const SHEETS := [["main", "Configuration"], ["body", "View and body"], ["controls", "Controls"], ["credits", "Credits"]]
const RED_TAPE := Color8(150, 26, 22)
const BLACK_TAPE := Color8(24, 24, 26)

var menu
var desk
## "main", "body", "controls", "credits".
var sheet := "main"
## The controls sheet's part: 0 out in the camp, 1 indoors, 2 the debug keys.
var _part := 0
var _sel := 0
## A key being changed (GameSettings.REBINDABLE), "" none; what it said after.
var _waiting := ""
var _note := ""


func _init(main_menu, title_desk) -> void:
	menu = main_menu
	desk = title_desk


func opened() -> void:
	_sel = 0
	_waiting = ""
	_note = ""
	if GameSettings != null and not GameSettings.settings_changed.is_connected(_on_settings):
		GameSettings.settings_changed.connect(_on_settings)


func closed() -> void:
	if GameSettings != null and GameSettings.settings_changed.is_connected(_on_settings):
		GameSettings.settings_changed.disconnect(_on_settings)


func _on_settings(_snap: Dictionary) -> void:
	desk.redraw()


func _rows() -> Array:
	return ROWS.BODY if sheet == "body" else ROWS.MAIN


func _row_y(i: int) -> float:
	return Y0 + PITCH * float(i)


func _parts() -> Array:
	var out: Array = ["Outdoors", "Indoors"]
	if OS.is_debug_build():
		out.append("Debug")
	return out


## The controls sheet's lines: [what, keys] and for a key that can be changed its action.
func _control_lines() -> Array:
	var rows: Array = SETTINGS_PANEL.CONTROL_REFERENCE
	if _part == 0:
		return rows.slice(0, SETTINGS_PANEL.OUTDOOR_ROWS)
	if _part == 2:
		var debug: Array = []
		for e in SETTINGS_PANEL.DEBUG_CONTROL_REFERENCE:
			debug.append(["(debug) " + str(e[0]), e[1]])
		return debug
	var out: Array = rows.slice(SETTINGS_PANEL.OUTDOOR_ROWS)
	for action in GameSettings.REBINDABLE.keys():
		var shown := tr("PRESS A KEY...") if _waiting == action else GameSettings.key_name(action)
		out.append([str(GameSettings.REBINDABLE[action][0]), shown, action])
	return out


func _tapes() -> Array:
	var out: Array = []
	for s in SHEETS:
		out.append([str(s[0]), str(s[1]), RED_TAPE if s[0] == sheet else BLACK_TAPE])
	out.append(["", "", null])
	if sheet == "main" or sheet == "body":
		out.append(["reset", "Reset defaults", BLACK_TAPE])
	out.append(["back", "Back", BLACK_TAPE])
	return out


func hotspots() -> Array:
	var out: Array = []
	if sheet == "main" or sheet == "body":
		var rows := _rows()
		for i in rows.size():
			var id := str(rows[i]["id"])
			var y := _row_y(i)
			out.append({"id": "dec:" + id, "rect": Rect2(LEFT_ARROW - 4, y - 9, 14, 12)})
			out.append({"id": "inc:" + id, "rect": Rect2(RIGHT_ARROW - 6, y - 9, 14, 12)})
			out.append({"id": "row:" + id, "rect": Rect2(X - 8, y - 9, LEFT_ARROW - X + 4, 12)})
	elif sheet == "controls":
		var parts := _parts()
		var x := X
		for i in parts.size():
			var w: float = desk.text_w(tr(str(parts[i])).to_upper())
			out.append({"id": "part:%d" % i, "rect": Rect2(x - 3, SHEET.position.y + 33, w + 6, 12)})
			x += w + 16.0
		var lines := _control_lines()
		for i in lines.size():
			if (lines[i] as Array).size() > 2:
				out.append({"id": "rebind:" + str(lines[i][2]), "rect": Rect2(X - 8, _control_y(i) - 9, KEYS_X - X + 12, 12)})
	var y := TAPE_Y0
	for t in _tapes():
		if str(t[0]) != "":
			out.append({"id": "tape:" + str(t[0]), "rect": desk.tape_rect(Vector2(TAPE_X, y), tr(str(t[1])))})
		y += TAPE_PITCH
	return out


func _control_y(i: int) -> float:
	return SHEET.position.y + 60.0 + CONTROL_PITCH * float(i)


func click(id: String) -> void:
	_waiting = "" if not id.begins_with("rebind:") else _waiting
	if id.begins_with("dec:") or id.begins_with("inc:") or id.begins_with("row:"):
		var rid := id.substr(4)
		_sel = _index_of(rid)
		_step(rid, -1 if id.begins_with("dec:") else 1)
		return
	if id.begins_with("part:"):
		_part = int(id.trim_prefix("part:"))
		_note = ""
		desk.play(SFX_SHEET, -10.0)
		return
	if id.begins_with("rebind:"):
		_waiting = id.trim_prefix("rebind:")
		_note = ""
		return
	match id.trim_prefix("tape:"):
		"main", "body", "controls", "credits":
			var to := id.trim_prefix("tape:")
			if to != sheet:
				sheet = to
				_sel = 0
				_note = ""
				desk.play(SFX_SHEET, -8.0)
		"reset":
			ROWS.reset()
			desk.play(SFX_STEP, -10.0)
		"back":
			menu.show_page("main")


func _index_of(rid: String) -> int:
	var rows := _rows()
	for i in rows.size():
		if str(rows[i]["id"]) == rid:
			return i
	return 0


func _step(rid: String, dir: int) -> void:
	if ROWS.change(rid, dir):
		desk.play(SFX_STEP, -12.0)


func key(event: InputEvent) -> bool:
	# Waiting for the new key: that key (Esc leaves it as it was).
	if _waiting != "":
		var k := event as InputEventKey
		if k != null and k.pressed and not k.echo:
			if k.keycode != KEY_ESCAPE:
				var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
				var clash := GameSettings.key_clash(_waiting, code)
				GameSettings.set_key(_waiting, code)
				_note = (tr("%s is also: %s") % [OS.get_keycode_string(code), clash]) if clash != "" else ""
			_waiting = ""
			return true
		return event is InputEventKey
	if sheet == "main" or sheet == "body":
		var rows := _rows()
		if event.is_action_pressed("ui_down", true):
			_sel = posmod(_sel + 1, rows.size())
			return true
		if event.is_action_pressed("ui_up", true):
			_sel = posmod(_sel - 1, rows.size())
			return true
		if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_accept"):
			_step(str(rows[_sel]["id"]), 1)
			return true
		if event.is_action_pressed("ui_left", true):
			_step(str(rows[_sel]["id"]), -1)
			return true
	elif sheet == "controls":
		if event.is_action_pressed("ui_right"):
			_part = posmod(_part + 1, _parts().size())
			return true
		if event.is_action_pressed("ui_left"):
			_part = posmod(_part - 1, _parts().size())
			return true
	if event.is_action_pressed("ui_focus_next"):
		var i := 0
		for k in SHEETS.size():
			if SHEETS[k][0] == sheet:
				i = k
		sheet = str(SHEETS[(i + 1) % SHEETS.size()][0])
		_sel = 0
		return true
	return false


func paint(d, c: Control) -> void:
	d.paper(c, SHEET)
	var title := ""
	for s in SHEETS:
		if s[0] == sheet:
			title = tr(str(s[1])).to_upper()
	d.text(c, Vector2(X, SHEET.position.y + 24), title, d.RED)
	match sheet:
		"main", "body":
			_paint_rows(d, c)
		"controls":
			_paint_controls(d, c)
		"credits":
			_paint_credits(d, c)
	var y := TAPE_Y0
	for t in _tapes():
		if str(t[0]) != "":
			d.tape(c, Vector2(TAPE_X, y), tr(str(t[1])), "tape:" + str(t[0]), t[2])
		y += TAPE_PITCH


func _paint_rows(d, c: Control) -> void:
	var rows := _rows()
	var hover: String = d.hovered()
	var lit_id := hover.substr(4) if hover.length() > 4 and hover.substr(3, 1) == ":" else ""
	for i in rows.size():
		var row: Dictionary = rows[i]
		var id := str(row["id"])
		var y := _row_y(i)
		var name := tr(str(row["name"])).to_upper()
		d.text(c, Vector2(X, y), name, d.INK)
		if id == lit_id or (lit_id == "" and hover == "" and i == _sel):
			d.mark(c, Vector2(X, y), d.text_w(name))
		var v: Dictionary = ROWS.value(id)
		var text := tr(str(v["text"]))
		if row.has("bar"):
			_paint_scale(d, c, Vector2(BAR_X, y - 6), int(row["bar"]), float(v["bar"]))
		var mid := (LEFT_ARROW + 6.0 + RIGHT_ARROW) * 0.5
		var room := RIGHT_ARROW - LEFT_ARROW - 12.0
		while text.length() > 2 and d.text_w(text) > room:
			text = text.left(text.length() - 3) + ".."
		d.text(c, Vector2(floorf(mid - d.text_w(text) * 0.5), y), text, d.INK)
		d.text(c, Vector2(LEFT_ARROW, y), "<", d.RED if hover == "dec:" + id else d.PENCIL)
		d.text(c, Vector2(RIGHT_ARROW - 4, y), ">", d.RED if hover == "inc:" + id else d.PENCIL)


## A scale of `steps` boxes, as many filled in pencil as `value` (0..1) says.
func _paint_scale(d, c: Control, at: Vector2, steps: int, value: float) -> void:
	var full := int(round(value * float(steps)))
	for s in steps:
		var r := Rect2(at + Vector2(float(s) * 6.0, 0), Vector2(4, 6))
		if s < full:
			c.draw_rect(r, Color(d.PENCIL, 0.85))
		else:
			c.draw_rect(r, Color(d.PENCIL, 0.55), false, 1.0)


func _paint_controls(d, c: Control) -> void:
	var parts := _parts()
	var hover: String = d.hovered()
	var x := X
	for i in parts.size():
		var s := tr(str(parts[i])).to_upper()
		var w: float = d.text_w(s)
		var at := Vector2(x, SHEET.position.y + 42)
		d.text(c, at, s, d.INK if i == _part else d.PENCIL)
		if i == _part:
			c.draw_rect(Rect2(at.x - 3, at.y - 9, w + 6, 12), d.RED, false, 1.0)
		elif hover == "part:%d" % i:
			c.draw_rect(Rect2(at.x - 1, at.y + 1, w + 2, 1), d.RED)
		x += w + 16.0
	var lines := _control_lines()
	for i in lines.size():
		var e: Array = lines[i]
		var y := _control_y(i)
		var what := tr(str(e[0]))
		# Looked up as written, then upper-cased: "SHIFT" is a work shift in the catalogue.
		var keys := tr(str(e[1])).to_upper()
		var kw: float = d.text_w(keys)
		d.text(c, Vector2(X, y), what, d.INK)
		var changeable := e.size() > 2
		d.text(c, Vector2(KEYS_X - kw, y), keys, d.RED if changeable and _waiting == str(e[2]) else d.PENCIL)
		if changeable and (hover == "rebind:" + str(e[2])):
			c.draw_rect(Rect2(KEYS_X - kw - 1, y + 1, kw + 2, 1), d.RED)
	if _note != "":
		d.text(c, Vector2(X, _control_y(lines.size()) + 4), _note.to_upper(), d.RED)


func _paint_credits(d, c: Control) -> void:
	var y := SHEET.position.y + 50.0
	for entry in RETRO_MENU.CreditsPage.LINES:
		var what := str(entry[0])
		var who := str(entry[1])
		if what != "":
			d.text(c, Vector2(X, y), tr(what).to_upper(), d.INK)
		if who != "":
			var w := who.to_upper()
			d.text(c, Vector2(KEYS_X - d.text_w(w), y), w, d.PENCIL)
		y += 14.0
