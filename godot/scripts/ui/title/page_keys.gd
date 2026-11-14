extends RefCounted

## The camps as keys on the reception's key board (a title_desk.gd page; main_menu.gd's
## CAMPS, and the camps to host for two): a key on a hook a camp, its name punched on Dymo
## tape over it, eight to the board (the arrows under it turn to the next eight). The one
## picked hangs out a little; its card lies beside the board, the camp's photograph glued
## on, its day and till in pencil. What can be done with it is punched on strips of tape
## stuck on the counter under the card: open it (its last save), its older saves, a copy,
## throw it away (asked twice), back.

const BOARD := "res://assets/textury/desk/key_board.png"
const FOB := "res://assets/textury/desk/key_fob.png"
const CARD := "res://assets/textury/desk/booking.png"
const SFX_KEYS := "res://assets/sfx/desk/keys.mp3"
const SFX_HANG := "res://assets/sfx/desk/key_hang.mp3"
const SFX_PEEL := "res://assets/sfx/desk/label_peel.mp3"
## The board at twice its pixels, its hooks four by two.
const BOARD_AT := Vector2(10, 22)
const BOARD_K := 2
const COLS := 4
const ROWS := 2
const HOOK0 := Vector2(56, 62)
const CELL := Vector2(84, 92)
## The card beside it and the tapes under the card.
const CARD_AT := Vector2(378, 20)
const TAPE_X := 422.0
const TAPE_Y0 := 160.0
const TAPE_PITCH := 15.0
const GREEN := Color8(30, 78, 44)
const RED_TAPE := Color8(150, 26, 22)
const BLACK_TAPE := Color8(24, 24, 26)

var menu
var _first := 0
var _delete_armed := false


func _init(main_menu) -> void:
	menu = main_menu


func opened() -> void:
	menu._refresh_camps()
	_first = (menu._camp_sel / (COLS * ROWS)) * COLS * ROWS
	_delete_armed = false


func _camps() -> Array:
	return menu._camps


func _hook(i: int) -> Vector2:
	var j := i - _first
	return BOARD_AT + HOOK0 + Vector2(float(j % COLS) * CELL.x, float(j / COLS) * CELL.y)


func hotspots() -> Array:
	var out: Array = []
	var camps := _camps()
	for i in range(_first, mini(_first + COLS * ROWS, camps.size())):
		var h := _hook(i)
		out.append({"id": "key:%d" % i, "rect": Rect2(h + Vector2(-34, -14), Vector2(68, 74))})
	if _first > 0:
		out.append({"id": "prev", "rect": Rect2(BOARD_AT + Vector2(130, 204), Vector2(30, 12))})
	if _first + COLS * ROWS < camps.size():
		out.append({"id": "next", "rect": Rect2(BOARD_AT + Vector2(196, 204), Vector2(30, 12))})
	var y := TAPE_Y0
	for t in _tapes():
		out.append({"id": str(t[0]), "rect": Rect2(TAPE_X - 44, y - 6, 88, 12)})
		y += TAPE_PITCH
	return out


## The strips under the card: [id, text, tape colour].
func _tapes() -> Array:
	var out: Array = []
	if not _camps().is_empty():
		out.append(["open", "Host" if menu._for_coop else "Open", GREEN])
		out.append(["saves", "Saves", BLACK_TAPE])
		if not menu._for_coop:
			out.append(["copy", "Duplicate", BLACK_TAPE])
			out.append(["delete", "Really delete?" if _delete_armed else "Delete camp", RED_TAPE])
	out.append(["back", "Back", BLACK_TAPE])
	return out


func click(id: String) -> void:
	var desk = menu._desk
	if id.begins_with("key:"):
		menu._camp_sel = int(id.trim_prefix("key:"))
		_delete_armed = false
		desk.play(SFX_KEYS, -6.0)
		return
	match id:
		"prev":
			_first = maxi(0, _first - COLS * ROWS)
		"next":
			_first += COLS * ROWS
		"open":
			desk.play(SFX_HANG, -6.0)
			menu.open_camp_latest()
		"saves":
			menu._open_camp()
		"copy":
			desk.play(SFX_PEEL, -8.0)
			menu.duplicate_selected_camp()
			opened()
		"delete":
			if not _delete_armed:
				_delete_armed = true
			else:
				desk.play(SFX_PEEL, -8.0)
				menu.delete_selected_camp()
				opened()
		"back":
			menu.show_page("coop" if menu._for_coop else "main")


func key(event: InputEvent) -> bool:
	var n: int = _camps().size()
	if n == 0:
		return false
	var dir := 0
	if event.is_action_pressed("ui_right"):
		dir = 1
	elif event.is_action_pressed("ui_left"):
		dir = -1
	elif event.is_action_pressed("ui_down"):
		dir = COLS
	elif event.is_action_pressed("ui_up"):
		dir = -COLS
	elif event.is_action_pressed("ui_accept"):
		click("open")
		return true
	if dir == 0:
		return false
	menu._camp_sel = clampi(menu._camp_sel + dir, 0, n - 1)
	_first = (menu._camp_sel / (COLS * ROWS)) * COLS * ROWS
	_delete_armed = false
	return true


func paint(d, c: Control) -> void:
	var board: Texture2D = d.tex(BOARD)
	if board != null:
		c.draw_texture_rect(board, Rect2(BOARD_AT, board.get_size() * BOARD_K), false)
	var camps := _camps()
	var fob: Texture2D = d.tex(FOB)
	for j in COLS * ROWS:
		var i := _first + j
		var h := _hook(i)
		# The brass cup hook, screwed into the board.
		c.draw_rect(Rect2(h + Vector2(-2, -3), Vector2(4, 2)), Color8(96, 66, 24))
		c.draw_rect(Rect2(h + Vector2(-2, -1), Vector2(2, 5)), Color8(214, 176, 82))
		c.draw_rect(Rect2(h + Vector2(0, 3), Vector2(3, 2)), Color8(150, 112, 44))
		if i >= camps.size():
			continue
		var camp: Dictionary = camps[i]
		var picked: bool = i == menu._camp_sel
		var lift := Vector2(0, -3) if picked else Vector2.ZERO
		var hover: bool = d.hovered() == "key:%d" % i
		d.dymo(c, h + Vector2(0, -10), str(camp.get("name", "Camp")), Color8(150, 26, 22) if picked else BLACK_TAPE)
		if fob != null:
			# Its ring (7, 2 in the picture) on the hook.
			var at := (h + lift - Vector2(14, 3)).floor()
			if picked:
				c.draw_texture_rect(fob, Rect2(at + Vector2(4, 6), fob.get_size() * 2), false, Color(0, 0, 0, 0.35))
			c.draw_texture_rect(fob, Rect2(at, fob.get_size() * 2), false, Color(1.15, 1.12, 1.05) if hover else Color.WHITE)
	if _first > 0:
		d.text(c, BOARD_AT + Vector2(134, 214), "<<", d.PAPER)
	if _first + COLS * ROWS < camps.size():
		d.text(c, BOARD_AT + Vector2(200, 214), ">>", d.PAPER)
	_paint_card(d, c)
	var y := TAPE_Y0
	for t in _tapes():
		var r: Rect2 = d.dymo(c, Vector2(TAPE_X, y), tr(str(t[1])), t[2])
		if d.hovered() == str(t[0]):
			c.draw_rect(Rect2(r.position.x, r.end.y + 1, r.size.x, 1), Color(0.95, 0.85, 0.5))
		y += TAPE_PITCH


func _paint_card(d, c: Control) -> void:
	var card: Texture2D = d.tex(CARD)
	var cr := Rect2(CARD_AT, card.get_size() if card != null else Vector2(88, 118))
	c.draw_rect(Rect2(cr.position + Vector2(2, 3), cr.size), Color(0, 0, 0, 0.35))
	if card != null:
		c.draw_texture(card, cr.position)
	else:
		c.draw_rect(cr, d.PAPER)
	var camps := _camps()
	if camps.is_empty():
		return
	var camp: Dictionary = camps[clampi(menu._camp_sel, 0, camps.size() - 1)]
	d.photo(c, Rect2(cr.position + Vector2(8, 10), Vector2(72, 40)), menu._thumb_texture(str(camp.get("thumb", ""))))
	var x := cr.position.x + 12
	d.text(c, Vector2(x, cr.position.y + 66), str(camp.get("name", "Camp")).to_upper(), d.INK)
	d.text(c, Vector2(x, cr.position.y + 78), (tr("SANDBOX") if bool(camp.get("sandbox", false)) else tr("STORY")) + "  " + tr("DAY %d") % int(camp.get("day", 1)), d.PENCIL)
	d.text(c, Vector2(x, cr.position.y + 89), "$" + menu._money(int(camp.get("money", 0))), d.PENCIL)
	d.text(c, Vector2(x, cr.position.y + 100), tr("%d GUESTS") % int(camp.get("guests", 0)), d.PENCIL)
