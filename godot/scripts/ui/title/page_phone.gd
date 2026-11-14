extends RefCounted

## Co-op as the office telephone on the counter (a title_desk.gd page; main_menu.gd's
## CO-OP): the push-button set cut out of its close-up (assets/textury/desk/phone.png,
## tools/artgen/desk_phone_cut.py). The other warden's address is dialled: typed (digits,
## letters, . : -; Backspace, Ctrl+V) or pressed on its keys (* a dot, # a colon) and shown
## on its LCD; the handset lifted (a click on it, or Enter) calls them (main_menu
## coop_join_requested), the red button calls the last address again. Beside it a sheet
## of the paper with your own warden's photograph and name and this machine's addresses
## for the other one to dial, and why the last call failed in red. Hosting is two tapes:
## a new camp (the application, for two) and a saved one (the key board's sandbox camps).

const PROFILES = preload("res://scripts/profiles.gd")
const WARDEN_LOOKS = preload("res://scripts/coop/warden_looks.gd")
const PHONE := "res://assets/textury/desk/phone.png"
const SFX := "res://assets/sfx/phone/"
const PHONE_AT := Vector2(10, 42)
## In the cut-out (its close-up's places less the cut's corner, 4, 12).
const LCD := Rect2(125, 28, 70, 17)
const REDIAL := Rect2(207, 26, 18, 15)
const HANDSET := Rect2(37, 20, 76, 168)
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
const KEY_CENTRES := [
	Vector2(148, 84), Vector2(174, 84), Vector2(199, 82),
	Vector2(151.5, 108.5), Vector2(177.5, 105.5), Vector2(203, 102.5),
	Vector2(155, 130.5), Vector2(181, 128), Vector2(206.5, 124),
	Vector2(158.5, 153), Vector2(185, 150), Vector2(211, 146),
]
const KEY_HALF := Vector2(9.5, 7.5)
## The LCD lit from behind: pale green figures on its dark glass.
const LCD_INK := Color(0.66, 0.8, 0.52)
## The sheet beside it.
const NOTE := Rect2(296, 14, 120, 124)
const TAPE_X := 388.0
const TAPE_Y0 := 166.0
const TAPE_PITCH := 16.0
const GREEN := Color8(30, 78, 44)
const MAX_ADDRESS := 40

var menu
var desk
var address := ""
## Why the last call failed, the host left (main_menu.show_coop_notice); "" none.
var notice := ""
var _pressed := -1
var _audio: AudioStreamPlayer


func _init(main_menu, title_desk) -> void:
	menu = main_menu
	desk = title_desk


func opened() -> void:
	if address.is_empty() and Coop != null:
		address = Coop.last_address
	_pressed = -1


func _key_rect(i: int) -> Rect2:
	return Rect2(PHONE_AT + KEY_CENTRES[i] - KEY_HALF, KEY_HALF * 2.0)


func _has_saved() -> bool:
	return PROFILES.list_camps().any(func(c: Dictionary) -> bool: return bool(c.get("sandbox", false)))


func _tapes() -> Array:
	var out: Array = [["host", "Host a new camp", GREEN]]
	if _has_saved():
		out.append(["host_saved", "Host a saved camp", Color8(24, 24, 26)])
	out.append(["back", "Back", Color8(24, 24, 26)])
	return out


func hotspots() -> Array:
	var out: Array = []
	for i in KEYS.size():
		out.append({"id": "key:%d" % i, "rect": _key_rect(i)})
	out.append({"id": "redial", "rect": Rect2(PHONE_AT + REDIAL.position, REDIAL.size)})
	out.append({"id": "handset", "rect": Rect2(PHONE_AT + HANDSET.position, HANDSET.size)})
	var y := TAPE_Y0
	for t in _tapes():
		out.append({"id": str(t[0]), "rect": desk.tape_rect(Vector2(TAPE_X, y), tr(str(t[1])))})
		y += TAPE_PITCH
	return out


func click(id: String) -> void:
	if id.begins_with("key:"):
		var i := int(id.trim_prefix("key:"))
		var k: String = KEYS[i]
		_press(i)
		_tone("dtmf_star" if k == "*" else ("dtmf_hash" if k == "#" else "dtmf_" + k))
		_type("." if k == "*" else (":" if k == "#" else k))
		return
	match id:
		"redial":
			if Coop != null and Coop.last_address != "":
				address = Coop.last_address
				_call()
		"handset":
			_call()
		"host":
			notice = ""
			menu.for_coop = true
			menu.show_page("newcamp")
		"host_saved":
			notice = ""
			menu.for_coop = true
			menu.show_page("camps")
		"back":
			menu.show_page("main")


func _type(ch: String) -> void:
	if address.length() < MAX_ADDRESS:
		address += ch
	notice = ""


func _call() -> void:
	var a := address.strip_edges()
	_tone("lift")
	if a.is_empty():
		return
	notice = ""
	menu.coop_join_requested.emit(a)


func key(event: InputEvent) -> bool:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return false
	if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_call()
		return true
	if k.keycode == KEY_BACKSPACE:
		address = address.left(maxi(0, address.length() - 1))
		return true
	if k.keycode == KEY_V and k.ctrl_pressed:
		for ch in DisplayServer.clipboard_get().strip_edges():
			if address_char(ch):
				_type(ch)
		return true
	var ch := String.chr(k.unicode) if k.unicode > 32 else ""
	if ch != "" and address_char(ch) and not k.ctrl_pressed and not k.alt_pressed:
		var at := KEYS.find(ch)
		if at >= 0:
			_press(at)
			_tone("dtmf_" + ch)
		_type(ch)
		return true
	return false


## The key goes down and comes back up (it never stays down).
func _press(i: int) -> void:
	_pressed = i
	desk.get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if _pressed == i:
			_pressed = -1
			desk.redraw())


static func address_char(ch: String) -> bool:
	return ch.length() == 1 and (ch.is_valid_int() or ch == "." or ch == ":" or ch == "-" or (ch.to_lower() >= "a" and ch.to_lower() <= "z"))


func _tone(name: String) -> void:
	desk.play(SFX + name + ".mp3", -9.0)


func paint(d, c: Control) -> void:
	var phone: Texture2D = d.tex(PHONE)
	if phone != null:
		# Its shadow on the counter, then the set.
		c.draw_texture(phone, PHONE_AT + Vector2(5, -4), Color(0, 0, 0, 0.4))
		c.draw_texture(phone, PHONE_AT)
	# The key being pressed, darker.
	if _pressed >= 0:
		var r := _key_rect(_pressed)
		c.draw_rect(r.grow(-2.0), Color(0, 0, 0, 0.18))
	var hover: String = d.hovered()
	if hover.begins_with("key:"):
		var hr := _key_rect(int(hover.trim_prefix("key:")))
		c.draw_rect(Rect2(hr.position.x + 3, hr.end.y - 2, hr.size.x - 6, 1), d.RED)
	elif hover == "handset":
		var hs := Rect2(PHONE_AT + HANDSET.position, HANDSET.size)
		c.draw_rect(Rect2(hs.position.x + 16, hs.end.y + 2, hs.size.x - 32, 1), d.RED)
	elif hover == "redial":
		var rr := Rect2(PHONE_AT + REDIAL.position, REDIAL.size)
		c.draw_rect(Rect2(rr.position.x, rr.end.y + 1, rr.size.x, 1), d.RED)
	_paint_lcd(d, c)
	_paint_note(d, c)
	var y := TAPE_Y0
	for t in _tapes():
		d.tape(c, Vector2(TAPE_X, y), tr(str(t[1])), str(t[0]), t[2])
		y += TAPE_PITCH


## The dialled address on the LCD in its lit figures, the end of it when it is longer
## than the glass, the cursor after it.
func _paint_lcd(d, c: Control) -> void:
	var r := Rect2(PHONE_AT + LCD.position, LCD.size)
	var shown := address.to_upper() + "_"
	var room := r.size.x - 6.0
	while shown.length() > 1 and d.text_w(shown) > room:
		shown = shown.substr(1)
	d.text(c, Vector2(r.end.x - 3.0 - d.text_w(shown), r.position.y + 12), shown, LCD_INK)


## The sheet with who you are and where you are: the photograph, the name, this
## machine's addresses; the last call's trouble in red under them.
func _paint_note(d, c: Control) -> void:
	d.paper(c, NOTE)
	var x := NOTE.position.x + 12
	var look: Dictionary = Coop.my_look() if Coop != null else {"m": 0, "c": 0, "n": ""}
	d.face(c, Vector2(x, NOTE.position.y + 12), int(look["m"]), int(look["c"]))
	var name := str(look.get("n", "")).to_upper()
	if name == "":
		name = PROFILES.profile_name().to_upper()
	for i in mini(2, d.wrap(name, 52).size()):
		d.text(c, Vector2(x + 44, NOTE.position.y + 24 + i * 10), d.wrap(name, 52)[i], d.INK)
	var y := NOTE.position.y + 70
	var here: Array = Coop.local_addresses() if Coop != null else []
	for a in here.slice(0, 3):
		d.text(c, Vector2(x, y), str(a), d.PENCIL)
		y += 12
	if notice != "":
		y += 4
		for line in d.wrap(notice.to_upper(), NOTE.size.x - 24):
			if y > NOTE.end.y - 6:
				break
			d.text(c, Vector2(x, y), line, d.RED)
			y += 10
