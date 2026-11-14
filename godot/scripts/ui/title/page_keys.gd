extends RefCounted

## The camps as keys on the reception's key board (a title_desk.gd page; main_menu.gd's
## CAMPS, and the camps to host for two): a key on a hook a camp, its name punched on Dymo
## tape over it, eight to the board (the arrows under it turn to the next eight). The one
## picked hangs out a little; its card lies beside the board (title_desk.camp_card). What
## can be done with it is punched on strips of tape stuck on the counter under the card:
## open it (its last save), its older saves (page_saves.gd), a copy, throw it away (asked
## twice), back. In co-op only sandbox camps hang there: a story camp is one warden's.

const PROFILES = preload("res://scripts/profiles.gd")
const BOARD := "res://assets/textury/desk/key_board.png"
const FOB := "res://assets/textury/desk/key_fob.png"
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
var desk
## The warden's camps as PROFILES.list_camps gives them (the one played last first).
var camps: Array[Dictionary] = []
var sel := 0
var _first := 0
var _delete_armed := false


func _init(main_menu, title_desk) -> void:
	menu = main_menu
	desk = title_desk


func opened() -> void:
	refresh()
	_first = (sel / (COLS * ROWS)) * COLS * ROWS
	_delete_armed = false


func refresh() -> void:
	camps = PROFILES.list_camps()
	if menu.for_coop:
		var sandbox: Array[Dictionary] = []
		for c in camps:
			if bool(c.get("sandbox", false)):
				sandbox.append(c)
		camps = sandbox
	sel = clampi(sel, 0, maxi(0, camps.size() - 1))


func picked() -> Dictionary:
	return camps[sel] if sel >= 0 and sel < camps.size() else {}


func _hook(i: int) -> Vector2:
	var j := i - _first
	return BOARD_AT + HOOK0 + Vector2(float(j % COLS) * CELL.x, float(j / COLS) * CELL.y)


func hotspots() -> Array:
	var out: Array = []
	for i in range(_first, mini(_first + COLS * ROWS, camps.size())):
		var h := _hook(i)
		out.append({"id": "key:%d" % i, "rect": Rect2(h + Vector2(-34, -14), Vector2(68, 74))})
	if _first > 0:
		out.append({"id": "prev", "rect": Rect2(BOARD_AT + Vector2(130, 204), Vector2(30, 12))})
	if _first + COLS * ROWS < camps.size():
		out.append({"id": "next", "rect": Rect2(BOARD_AT + Vector2(196, 204), Vector2(30, 12))})
	var y := TAPE_Y0
	for t in _tapes():
		out.append({"id": str(t[0]), "rect": desk.tape_rect(Vector2(TAPE_X, y), tr(str(t[1])))})
		y += TAPE_PITCH
	return out


## The strips under the card: [id, text, tape colour].
func _tapes() -> Array:
	var out: Array = []
	if not camps.is_empty():
		out.append(["open", "Host" if menu.for_coop else "Open", GREEN])
		out.append(["saves", "Saves", BLACK_TAPE])
		if not menu.for_coop:
			out.append(["copy", "Duplicate", BLACK_TAPE])
			out.append(["delete", "Really delete?" if _delete_armed else "Delete camp", RED_TAPE])
	out.append(["back", "Back", BLACK_TAPE])
	return out


func click(id: String) -> void:
	if id.begins_with("key:"):
		sel = int(id.trim_prefix("key:"))
		_delete_armed = false
		desk.play(SFX_KEYS, -6.0)
		return
	var camp := picked()
	match id:
		"prev":
			_first = maxi(0, _first - COLS * ROWS)
		"next":
			_first += COLS * ROWS
		"open":
			if camp.is_empty():
				return
			var saves: Array[Dictionary] = SaveManager.list_saves(PROFILES.camp_dir(str(camp["id"])).path_join("saves"))
			if saves.is_empty():
				menu.show_saves(str(camp["id"]))
				return
			desk.play(SFX_HANG, -6.0)
			menu.open_save(str(saves[0].get("path", "")))
		"saves":
			if not camp.is_empty():
				menu.show_saves(str(camp["id"]))
		"copy":
			if not camp.is_empty():
				desk.play(SFX_PEEL, -8.0)
				PROFILES.duplicate_camp(str(camp["id"]))
				refresh()
		"delete":
			if camp.is_empty():
				return
			if not _delete_armed:
				_delete_armed = true
			else:
				desk.play(SFX_PEEL, -8.0)
				PROFILES.delete_camp(str(camp["id"]))
				_delete_armed = false
				menu.refresh_saves()
				refresh()
				_first = (sel / (COLS * ROWS)) * COLS * ROWS
		"back":
			menu.show_page("coop" if menu.for_coop else "main")


func key(event: InputEvent) -> bool:
	var n: int = camps.size()
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
	sel = clampi(sel + dir, 0, n - 1)
	_first = (sel / (COLS * ROWS)) * COLS * ROWS
	_delete_armed = false
	return true


func paint(d, c: Control) -> void:
	var board: Texture2D = d.tex(BOARD)
	if board != null:
		c.draw_texture_rect(board, Rect2(BOARD_AT, board.get_size() * BOARD_K), false)
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
		var is_picked: bool = i == sel
		var lift := Vector2(0, -3) if is_picked else Vector2.ZERO
		var hover: bool = d.hovered() == "key:%d" % i
		d.dymo(c, h + Vector2(0, -10), str(camp.get("name", "Camp")), RED_TAPE if is_picked else BLACK_TAPE)
		if fob != null:
			# Its ring (7, 2 in the picture) on the hook.
			var at := (h + lift - Vector2(14, 3)).floor()
			if is_picked:
				c.draw_texture_rect(fob, Rect2(at + Vector2(4, 6), fob.get_size() * 2), false, Color(0, 0, 0, 0.35))
			c.draw_texture_rect(fob, Rect2(at, fob.get_size() * 2), false, Color(1.15, 1.12, 1.05) if hover else Color.WHITE)
	if _first > 0:
		d.text(c, BOARD_AT + Vector2(134, 214), "<<", d.PAPER)
	if _first + COLS * ROWS < camps.size():
		d.text(c, BOARD_AT + Vector2(200, 214), ">>", d.PAPER)
	d.camp_card(c, CARD_AT, picked())
	var y := TAPE_Y0
	for t in _tapes():
		d.tape(c, Vector2(TAPE_X, y), tr(str(t[1])), str(t[0]), t[2])
		y += TAPE_PITCH
