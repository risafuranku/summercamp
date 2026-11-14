extends RefCounted

## The warden as their ID card on the counter (a title_desk.gd page; main_menu.gd's
## WARDEN, and the first thing a new player sees): the card twice its pixels
## (assets/textury/desk/id_card.png), the warden's photograph in its frame, their name
## written on its first line (typed into it), their language's flag (the one not theirs
## greyed: a click changes it, and the whole title with it), how many camps they keep.
## Beside it a photo booth's strip of the four figures and a row of jacket cloth pinned
## to the counter: a click dresses the warden (the other wardens see it in co-op). The
## other wardens' cards lie in a pile on the right: a click on one plays as them. Tapes:
## a new warden (a blank card to fill in: written and its tape pressed, it is theirs),
## throw this one away (asked twice), back. No warden yet: the blank card, no way back.

const PROFILES = preload("res://scripts/profiles.gd")
const WARDEN_LOOKS = preload("res://scripts/coop/warden_looks.gd")
const LANG = preload("res://scripts/lang.gd")
const CARD := "res://assets/textury/desk/id_card.png"
const SFX_CARD := "res://assets/sfx/desk/card_drop.mp3"
const SFX_PEN := "res://assets/sfx/desk/pen.mp3"
const SFX_PICK := "res://assets/sfx/desk/paper_pick.mp3"
const SFX_TEAR := "res://assets/sfx/desk/label_peel.mp3"
const CARD_AT := Vector2(22, 22)
const CARD_K := 2
## On the card (its own px, times CARD_K): the photograph's frame, the lines.
const PHOTO := Vector2(10, 16)
const LINE_X := 53.0
const LINES := [27.0, 34.0, 41.0]
## The figures' strip, the jackets' cloth, the other cards.
const STRIP_AT := Vector2(256, 22)
const STRIP_PITCH := 44.0
const CLOTH_AT := Vector2(26, 176)
const CLOTH_PITCH := 23.0
const CLOTH := 16
const PILE_AT := Vector2(316, 16)
const PILE_PITCH := 34.0
const PILE_MAX := 5
const TAPE_X := 400.0
const TAPE_Y0 := 224.0
const TAPE_PITCH := 15.0
const GREEN := Color8(30, 78, 44)
const RED_TAPE := Color8(150, 26, 22)

var menu
var desk
## A card being filled in (a new warden, not yet one).
var _blank := false
var _new_look := {"m": 0, "c": 0}
var _new_lang := "en"
var _name: LineEdit
var _delete_armed := false
## The look changed: told to the other wardens on the line when the page closes.
var _dressed := false


func _init(main_menu, title_desk) -> void:
	menu = main_menu
	desk = title_desk


func opened() -> void:
	_delete_armed = false
	_dressed = false
	if not PROFILES.has_profile():
		_start_blank()
	else:
		_blank = false
	_make_field()


func closed() -> void:
	_commit_name()
	if _dressed and PROFILES.has_profile():
		if Coop != null:
			Coop.announce_look()
		menu.warden_changed()
	_dressed = false


func _start_blank() -> void:
	_blank = true
	_new_look = {"m": PROFILES.list_profiles().size() % WARDEN_LOOKS.count(), "c": 0}
	_new_lang = LANG.current if PROFILES.has_profile() else LANG.system_default()
	LANG.apply(_new_lang)


func _make_field() -> void:
	desk.clear_fields()
	var at := _card_px(Vector2(LINE_X, LINES[0])) + Vector2(0, -8)
	_name = desk.field(Rect2(at, Vector2(CARD_AT.x + 108 * CARD_K - 6 - at.x, 10)), tr("Your name"))
	_name.max_length = 24
	_name.text = "" if _blank else PROFILES.profile_name()
	_name.text_submitted.connect(func(_t: String) -> void:
		if _blank:
			click("done")
		else:
			_commit_name()
			_name.release_focus())
	_name.focus_exited.connect(_commit_name)
	if _blank:
		_name.grab_focus()


## The name written on a card that is someone's kept (an empty line keeps the old one).
func _commit_name() -> void:
	if _blank or _name == null or not is_instance_valid(_name) or not PROFILES.has_profile():
		return
	var t := _name.text.strip_edges()
	if t == "" or t == PROFILES.profile_name():
		return
	PROFILES.rename_profile(PROFILES.profile_id, t)
	menu.warden_changed()


func _card_px(p: Vector2) -> Vector2:
	return CARD_AT + p * float(CARD_K)


func _look() -> Dictionary:
	if _blank:
		return _new_look
	var look: Dictionary = PROFILES.profile_look()
	if int(look["m"]) < 0 and Coop != null:
		look = Coop.my_look()
	return {"m": posmod(maxi(0, int(look["m"])), WARDEN_LOOKS.count()), "c": posmod(int(look["c"]), WARDEN_LOOKS.color_count())}


func _dress(m: int, c: int) -> void:
	if _blank:
		_new_look = {"m": m, "c": c}
		LANG.set_figure(m)
	else:
		PROFILES.set_profile_look(PROFILES.profile_id, m, c)
		_dressed = true
	desk.play(SFX_PICK, -8.0)


func _lang() -> String:
	return _new_lang if _blank else PROFILES.profile_lang()


func _set_lang(code: String) -> void:
	if code == _lang():
		return
	if _blank:
		_new_lang = code
		LANG.apply(code)
	else:
		PROFILES.set_profile_lang(PROFILES.profile_id, code)
	desk.play(SFX_PEN, -10.0)
	# The card's own lines in the new language (the field's empty line says what goes on it).
	if _name != null and is_instance_valid(_name):
		_name.placeholder_text = tr("Your name")


func _others() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in PROFILES.list_profiles():
		if _blank or str(p["id"]) != PROFILES.profile_id:
			out.append(p)
	return out.slice(0, PILE_MAX)


func _flag_rect(i: int) -> Rect2:
	return Rect2(_card_px(Vector2(LINE_X, LINES[1])) + Vector2(float(i) * 30.0, -10), Vector2(24, 16))


func _tapes() -> Array:
	var out: Array = []
	if _blank:
		out.append(["done", "Done", GREEN])
	else:
		out.append(["new", "New warden", GREEN])
		out.append(["delete", "Really delete?" if _delete_armed else "Delete warden", RED_TAPE])
	if PROFILES.has_profile():
		out.append(["back", "Back", Color8(24, 24, 26)])
	return out


func hotspots() -> Array:
	var out: Array = []
	for i in WARDEN_LOOKS.count():
		out.append({"id": "fig:%d" % i, "rect": Rect2(STRIP_AT + Vector2(0, STRIP_PITCH * i), Vector2(desk.FACE)).grow(2)})
	for i in WARDEN_LOOKS.color_count():
		out.append({"id": "cloth:%d" % i, "rect": Rect2(CLOTH_AT + Vector2(CLOTH_PITCH * i, 0), Vector2(CLOTH, CLOTH)).grow(2)})
	for i in LANG.LANGS.size():
		out.append({"id": "lang:%s" % LANG.LANGS[i], "rect": _flag_rect(i)})
	var others := _others()
	# The pile: the top card (drawn last) answers first.
	for j in range(others.size() - 1, -1, -1):
		out.append({"id": "card:%s" % str(others[j]["id"]), "rect": Rect2(PILE_AT + Vector2(0, PILE_PITCH * j), Vector2(108, 70))})
	var y := TAPE_Y0
	for t in _tapes():
		out.append({"id": str(t[0]), "rect": desk.tape_rect(Vector2(TAPE_X, y), tr(str(t[1])))})
		y += TAPE_PITCH
	return out


func click(id: String) -> void:
	var look := _look()
	if id.begins_with("fig:"):
		_dress(int(id.trim_prefix("fig:")), int(look["c"]))
		return
	if id.begins_with("cloth:"):
		_dress(int(look["m"]), int(id.trim_prefix("cloth:")))
		return
	if id.begins_with("lang:"):
		_set_lang(id.trim_prefix("lang:"))
		return
	if id.begins_with("card:"):
		_commit_name()
		closed()
		PROFILES.select_profile(id.trim_prefix("card:"))
		_blank = false
		_delete_armed = false
		desk.play(SFX_CARD, -6.0)
		menu.warden_changed()
		_make_field()
		return
	match id:
		"done":
			var t := _name.text.strip_edges() if _name != null else ""
			if t == "":
				_name.grab_focus()
				desk.play("res://assets/sfx/desk/wrong.mp3", -10.0)
				return
			PROFILES.create_profile(t, int(_new_look["m"]), int(_new_look["c"]), _new_lang)
			_blank = false
			desk.play(SFX_CARD, -6.0)
			menu.warden_changed()
			menu.show_page("main")
		"new":
			_commit_name()
			closed()
			_start_blank()
			_delete_armed = false
			desk.play(SFX_CARD, -6.0)
			_make_field()
		"delete":
			if not _delete_armed:
				_delete_armed = true
				return
			_delete_armed = false
			desk.play(SFX_TEAR, -8.0)
			PROFILES.delete_profile(PROFILES.profile_id)
			menu.warden_changed()
			if not PROFILES.has_profile():
				_start_blank()
			_make_field()
		"back":
			if _blank and PROFILES.has_profile():
				# A blank card put away: back to the warden playing, as they are.
				_blank = false
				LANG.apply(PROFILES.profile_lang())
				LANG.set_figure(int(PROFILES.profile_look()["m"]))
				_make_field()
				return
			menu.show_page("main")


func key(_event: InputEvent) -> bool:
	return false


func paint(d, c: Control) -> void:
	var look := _look()
	var m := int(look["m"])
	var col := int(look["c"])
	var hover: String = d.hovered()
	# The card.
	var card: Texture2D = d.tex(CARD)
	if card != null:
		var r := Rect2(CARD_AT, card.get_size() * CARD_K)
		c.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
		c.draw_texture_rect(card, r, false)
	d.text(c, CARD_AT + Vector2(20, 22), tr("WARDEN"), d.RED)
	d.face(c, _card_px(PHOTO) + Vector2(0, 0), m, col, CARD_K, false)
	for i in LANG.LANGS.size():
		var code: String = LANG.LANGS[i]
		var fr := _flag_rect(i)
		var flag: Texture2D = d.tex(LANG.FLAGS[code])
		var mine := code == _lang()
		if flag != null:
			c.draw_texture_rect(flag, fr, false, Color.WHITE if mine else Color(0.55, 0.52, 0.5, 0.8))
		if mine:
			c.draw_rect(fr.grow(2), d.RED, false, 1.0)
		elif hover == "lang:" + code:
			c.draw_rect(Rect2(fr.position.x, fr.end.y + 2, fr.size.x, 1), d.RED)
	if not _blank:
		var n := 0
		for p in PROFILES.list_profiles():
			if str(p["id"]) == PROFILES.profile_id:
				n = int(p["camps"])
		d.text(c, _card_px(Vector2(LINE_X, LINES[2])) + Vector2(0, 6), LANG.t_n(n, "%d camp", "%d camps").to_upper(), d.PENCIL)
	# The figures' strip.
	for i in WARDEN_LOOKS.count():
		var at := STRIP_AT + Vector2(0, STRIP_PITCH * i)
		var fr: Rect2 = d.face(c, at, i, col if i == m else 0)
		if i == m:
			c.draw_rect(fr.grow(4), d.RED, false, 1.0)
		elif hover == "fig:%d" % i:
			c.draw_rect(Rect2(fr.position.x, fr.end.y + 4, fr.size.x, 1), d.RED)
	# The jackets' cloth: the jacket's own pixels in each colour, pinned on.
	for i in WARDEN_LOOKS.color_count():
		var r := Rect2(CLOTH_AT + Vector2(CLOTH_PITCH * i, 0), Vector2(CLOTH, CLOTH))
		var t := WARDEN_LOOKS.texture(m, i, "stand")
		c.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.35))
		if t != null:
			c.draw_texture_rect_region(t, r, Rect2(WARDEN_LOOKS.cloth_rect(m, CLOTH)))
		c.draw_rect(Rect2(r.position.x + CLOTH / 2 - 1, r.position.y - 1, 2, 2), Color8(214, 176, 82))
		if i == col:
			c.draw_rect(r.grow(3), d.RED, false, 1.0)
		elif hover == "cloth:%d" % i:
			c.draw_rect(Rect2(r.position.x, r.end.y + 3, r.size.x, 1), d.RED)
	# The other wardens' cards, in a pile.
	var others := _others()
	for j in others.size():
		var p: Dictionary = others[j]
		var at := PILE_AT + Vector2(0, PILE_PITCH * j)
		if card != null:
			c.draw_rect(Rect2(at + Vector2(2, 3), card.get_size()), Color(0, 0, 0, 0.35))
			c.draw_texture(card, at, Color(1.08, 1.06, 1.0) if hover == "card:" + str(p["id"]) else Color.WHITE)
		var pl: Dictionary = PROFILES.profile_look(str(p["id"]))
		d.face(c, at + PHOTO, maxi(0, int(pl["m"])), int(pl["c"]), 1, false)
		var name := str(p["name"]).to_upper()
		while name.length() > 1 and d.text_w(name) > 52:
			name = name.left(name.length() - 1)
		d.text(c, at + Vector2(LINE_X, LINES[0]), name, d.INK)
	var y := TAPE_Y0
	for t in _tapes():
		d.tape(c, Vector2(TAPE_X, y), tr(str(t[1])), str(t[0]), t[2])
		y += TAPE_PITCH
