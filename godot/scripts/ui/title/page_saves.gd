extends RefCounted

## One camp's saves as a printout on the counter (a title_desk.gd page; the key board's
## "Saves"): the camp's card where the key board laid it, beside it the list of its saves
## typed out on the striped computer paper, the newest first, a save to a pair of lines
## (its name and when; its day, hour and till). A click on one opens it (hosts it, for two);
## the tapes: open the one marked, throw it away (asked twice), back to the keys. More
## than a sheet holds turn over with the arrows at its foot.

const PROFILES = preload("res://scripts/profiles.gd")
const CAMP_TEXT = preload("res://scripts/ui/title/camp_text.gd")
const SFX_PAGE := "res://assets/sfx/desk/paper_slide.mp3"
const SFX_TEAR := "res://assets/sfx/desk/label_peel.mp3"
const SFX_PICK := "res://assets/sfx/desk/paper_pick.mp3"
const CARD_AT := Vector2(26, 22)
const SHEET := Rect2(132, 10, 236, 252)
## On the sheet: the lines' left edge and right edge, the first save's baseline, one save
## every PITCH.
const X := 150.0
const X_END := 352.0
const Y0 := 52.0
const PITCH := 24.0
const PER_SHEET := 8
const TAPE_X := 424.0
const TAPE_Y0 := 196.0
const TAPE_PITCH := 15.0
const GREEN := Color8(30, 78, 44)
const RED_TAPE := Color8(150, 26, 22)

var menu
var desk
var camp_id := ""
var _camp: Dictionary = {}
var _saves: Array[Dictionary] = []
var _sel := 0
var _first := 0
var _delete_armed := false


func _init(main_menu, title_desk) -> void:
	menu = main_menu
	desk = title_desk


func opened() -> void:
	_sel = 0
	_first = 0
	_delete_armed = false
	refresh()


func refresh() -> void:
	_camp = PROFILES.camp_info(camp_id) if camp_id != "" else {}
	_saves = SaveManager.list_saves(PROFILES.camp_dir(camp_id).path_join("saves")) if camp_id != "" else []
	_sel = clampi(_sel, 0, maxi(0, _saves.size() - 1))
	_first = clampi(_first, 0, maxi(0, _saves.size() - 1))


func _row_y(i: int) -> float:
	return Y0 + PITCH * float(i - _first)


func _tapes() -> Array:
	var out: Array = []
	if not _saves.is_empty():
		out.append(["open", "Host" if menu.for_coop else "Open", GREEN])
		out.append(["delete", "Really delete?" if _delete_armed else "Delete save", RED_TAPE])
	out.append(["back", "Back", Color8(24, 24, 26)])
	return out


func hotspots() -> Array:
	var out: Array = []
	for i in range(_first, mini(_first + PER_SHEET, _saves.size())):
		var y := _row_y(i)
		out.append({"id": "save:%d" % i, "rect": Rect2(X - 8, y - 9, X_END - X + 10, PITCH - 2)})
	if _first > 0:
		out.append({"id": "prev", "rect": Rect2(SHEET.position.x + 80, SHEET.end.y - 18, 24, 12)})
	if _first + PER_SHEET < _saves.size():
		out.append({"id": "next", "rect": Rect2(SHEET.position.x + 132, SHEET.end.y - 18, 24, 12)})
	var y := TAPE_Y0
	for t in _tapes():
		out.append({"id": str(t[0]), "rect": desk.tape_rect(Vector2(TAPE_X, y), tr(str(t[1])))})
		y += TAPE_PITCH
	return out


func click(id: String) -> void:
	if id.begins_with("save:"):
		var i := int(id.trim_prefix("save:"))
		_sel = i
		if _delete_armed:
			# (A click on the list while it asks: it asks no more.)
			_delete_armed = false
			return
		_open()
		return
	match id:
		"prev":
			_first = maxi(0, _first - PER_SHEET)
			desk.play(SFX_PAGE, -8.0)
		"next":
			_first += PER_SHEET
			desk.play(SFX_PAGE, -8.0)
		"open":
			_open()
		"delete":
			_delete()
		"back":
			menu.show_page("camps")


func _open() -> void:
	if _sel < 0 or _sel >= _saves.size():
		return
	desk.play(SFX_PICK, -6.0)
	menu.open_save(str(_saves[_sel].get("path", "")))


func _delete() -> void:
	if _saves.is_empty():
		return
	if not _delete_armed:
		_delete_armed = true
		return
	_delete_armed = false
	desk.play(SFX_TEAR, -8.0)
	SaveManager.delete_save(str(_saves[_sel].get("path", "")))
	menu.refresh_saves()
	refresh()


func _select(i: int) -> void:
	if _saves.is_empty():
		return
	var n := clampi(i, 0, _saves.size() - 1)
	if n != _sel:
		_delete_armed = false
	_sel = n
	if _sel < _first:
		_first = (_sel / PER_SHEET) * PER_SHEET
	elif _sel >= _first + PER_SHEET:
		_first = (_sel / PER_SHEET) * PER_SHEET


func key(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_down", true):
		_select(_sel + 1)
		return true
	if event.is_action_pressed("ui_up", true):
		_select(_sel - 1)
		return true
	if event.is_action_pressed("ui_accept"):
		_open()
		return true
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_DELETE or k.keycode == KEY_X):
		_delete()
		return true
	return false


func paint(d, c: Control) -> void:
	d.camp_card(c, CARD_AT, _camp)
	d.paper(c, SHEET)
	d.text(c, Vector2(X, SHEET.position.y + 22), str(_camp.get("name", tr("CAMP"))).to_upper(), d.RED)
	if _saves.is_empty():
		d.text(c, Vector2(X, Y0), tr("NO SAVES YET"), d.PENCIL)
	var hover: String = d.hovered()
	for i in range(_first, mini(_first + PER_SHEET, _saves.size())):
		var e: Dictionary = _saves[i]
		var y := _row_y(i)
		var name := tr(str(e.get("slot_name", "Save")))
		var lit := hover == "save:%d" % i or (hover == "" and i == _sel)
		d.text(c, Vector2(X, y), name, d.INK)
		var ago := CAMP_TEXT.ago(int(e.get("updated_unix", 0)))
		d.text(c, Vector2(X_END - d.text_w(ago), y), ago, d.PENCIL)
		var sub := CAMP_TEXT.summary(e)
		if i == _sel and _delete_armed:
			sub = tr("Really delete?").to_upper()
		d.text(c, Vector2(X, y + 10), sub, d.RED if i == _sel and _delete_armed else d.PENCIL)
		if lit:
			d.mark(c, Vector2(X, y), d.text_w(name))
	if _first > 0:
		d.text(c, Vector2(SHEET.position.x + 84, SHEET.end.y - 8), "<<", d.INK)
	if _first + PER_SHEET < _saves.size():
		d.text(c, Vector2(SHEET.position.x + 136, SHEET.end.y - 8), ">>", d.INK)
	var y := TAPE_Y0
	for t in _tapes():
		d.tape(c, Vector2(TAPE_X, y), tr(str(t[1])), str(t[0]), t[2])
		y += TAPE_PITCH
