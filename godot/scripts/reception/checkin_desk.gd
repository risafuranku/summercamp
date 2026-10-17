extends CanvasLayer

## The reception desk, close up: checking a party in, the way Papers Please did it at its
## border booth. A 480x270 picture drawn at its own resolution (Grok art in
## assets/textury/desk/, the game's pixel fonts) and scaled up by a whole number.
##
## Across the counter at the top stands whoever is next (scripts/reception/desk_room.gd
## brings them from GuestManager.get_desk_queue()). They slide their papers across: the
## identity card and the CampMail booking slip. On your side of the counter:
##   - the guest register, open at today: drop the card on it and you write the name and
##     the card number, drop the slip on it and you write persons, nights and lodging;
##   - the key board: take the key for their lodging and drop it on the counter (up
##     there, where they stand). A key for a room that is not made up comes back; so
##     does somebody else's;
##   - two rubber stamps, CHECKED IN and REFUSED: pick one up, press it on the slip (or on
##     the card, for someone who has no slip);
##   - give the papers back (drop them on the counter) and they go. With CHECKED IN on
##     them only once they are written in and have their keys.
## Everything is dragged with the mouse: papers lift with a shadow, slide, drop with a
## sound. Esc or the right button stands you up; whoever is waiting keeps waiting.
##
## At night someone who is not booked may come to the desk (desk_room.gd decides). He
## has no slip, and his card is not right. Writing him in and giving him a key lets him
## stay; stamping him REFUSED and giving him his card back sends him away.

signal closed
signal checked_in(guest_id: int)
signal refused(guest_id: int)
signal stranger_admitted
signal stranger_refused

const TEX := "res://assets/textury/desk/"
const SFX := "res://assets/sfx/desk/"
const F_TYPE: FontFile = preload("res://assets/fonts/w95.fnt")
const F_TINY: FontFile = preload("res://assets/fonts/tiny5.fnt")
const F_SILK: FontFile = preload("res://assets/fonts/silkscreen.fnt")
const F_STAMP: FontFile = preload("res://assets/fonts/jersey10.fnt")

const W := 480
const H := 270
const COUNTER_Y := 104.0
const GIVE := Rect2(0, 0, 480, 116)
const DESK := Rect2(0, 116, 480, 154)
const BOOK := Rect2(4, 118, 226, 150)
const RACK := Rect2(298, 120, 178, 100)
const PAD := Rect2(424, 228, 48, 34)
const STAMP_SIZE := Vector2(42, 38)
const STAMP_HOME := {"in": Vector2(304, 222), "out": Vector2(360, 222)}
const CARD_SIZE := Vector2(108, 70)
const SLIP_SIZE := Vector2(88, 118)
const KEY_SIZE := Vector2(20, 20)
const ROW_Y0 := 144.0
const ROW_H := 12.0
const ROWS := 10
const HOOK_COLS := 8
const HOOK_ROWS := 3
const INK := Color(0.10, 0.14, 0.46)
const INK_RED := Color(0.62, 0.06, 0.05)
const STAMP_GREEN := Color(0.12, 0.46, 0.20, 0.86)
const STAMP_RED := Color(0.70, 0.08, 0.08, 0.86)
const PAPER_TEXT := Color(0.12, 0.11, 0.10)
const OPEN_SEC := 0.22
## The register's handwriting: a 3x5 pixel hand, so a name fits its column.
const HAND := {
	"A": "010101111101101",
	"B": "110101110101110",
	"C": "011100100100011",
	"D": "110101101101110",
	"E": "111100110100111",
	"F": "111100110100100",
	"G": "011100101101011",
	"H": "101101111101101",
	"I": "111010010010111",
	"J": "001001001101010",
	"K": "101101110101101",
	"L": "100100100100111",
	"M": "101111111101101",
	"N": "110101101101101",
	"O": "010101101101010",
	"P": "110101110100100",
	"Q": "010101101110011",
	"R": "110101110101101",
	"S": "011100010001110",
	"T": "111010010010010",
	"U": "101101101101111",
	"V": "101101101101010",
	"W": "101101111111101",
	"X": "101101010101101",
	"Y": "101101010010010",
	"Z": "111001010100111",
	"0": "111101101101111",
	"1": "010110010010111",
	"2": "110001010100111",
	"3": "110001010001110",
	"4": "101101111001001",
	"5": "111100110001110",
	"6": "011100110101010",
	"7": "111001010010010",
	"8": "010101010101010",
	"9": "010101011001110",
	".": "000000000000010",
	":": "000010000010000",
	",": "000000000010100",
	"-": "000000111000000",
	"/": "001001010100100",
}

## Callable() -> Array: the key board (GuestManager.get_key_board()).
var key_board_provider: Callable
## Callable(guest_id) -> Dictionary: {ok, reason} (GuestManager.request_check_in).
var check_in_call: Callable
## Callable() -> Dictionary: the next party in the queue, or {}.
var next_guest_provider: Callable

var _vp: SubViewport
var _canvas: Control
var _view: TextureRect
var _backdrop: ColorRect
var _k := 2
var _mouse := Vector2(-1, -1)
var _open_t := 0.0
var _closing_t := -1.0
var _tex: Dictionary = {}
var _audio: Array = []
var _audio_i := 0

var _guest: Dictionary = {}       # the desk row of whoever is at the counter, or {}
var _p: Dictionary = {}           # their progress (see _new_progress)
var _progress: Dictionary = {}    # guest id -> progress, kept while they wait
var _history: Array = []          # register rows: {no, name, card, persons, nights, lodging, key, day, red}
var _keys: Array = []             # the key board, refreshed while open
var _drag := ""                   # "card", "slip", "key:<key>"
var _drag_off := Vector2.ZERO
var _holding_stamp := ""          # "in" / "out"
var _guest_y := 0.0               # 0 = at the counter, 1 = gone below the counter
var _guest_target := 0.0
var _leave_then := ""             # what happens when the guest has walked off
var _say := ""
var _say_shown := 0.0
var _shake := 0.0
var _pen: Dictionary = {}         # {field: progress 0..1}
var _day := 1
var _t := 0.0
var _empty_t := 0.0


func _init() -> void:
	layer = 140
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_canvas = Control.new()
	_canvas.size = Vector2(W, H)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_all)
	_vp.add_child(_canvas)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	for i in 4:
		var a := AudioStreamPlayer.new()
		a.volume_db = -6.0
		add_child(a)
		_audio.append(a)
	for n in ["desk_top", "desk_view", "register", "id_card", "booking", "key_rack", "key_fob", "stamp"]:
		var path: String = TEX + n + ".png"
		_tex[n] = load(path) if ResourceLoader.exists(path) else null
	get_tree().root.size_changed.connect(_layout)


# ── the outside: open, close, save ───────────────────────────────────────────

func is_open() -> bool:
	return visible and _closing_t < 0.0


func current_guest_id() -> int:
	return int(_guest.get("id", -999)) if not _guest.is_empty() else -999


## Opens at the counter with `guest` (a GuestManager desk row, or a stranger) or empty.
func open_desk(guest: Dictionary, day: int) -> void:
	_day = day
	if not visible:
		visible = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_open_t = 0.0
		_closing_t = -1.0
		_layout()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_play("book", -10.0)
	_refresh_keys()
	if guest.is_empty():
		_set_guest({})
	elif int(guest.get("id", -999)) != current_guest_id():
		_set_guest(guest)


func close_desk() -> void:
	if not visible or _closing_t >= 0.0:
		return
	_drop_everything()
	if not _guest.is_empty():
		_progress[current_guest_id()] = _p
	_closing_t = 0.0


func export_state() -> Dictionary:
	return {"history": _history.duplicate(true)}


func import_state(d: Dictionary) -> void:
	_history = (d.get("history", []) as Array).duplicate(true) if d.get("history", []) is Array else []


func history() -> Array:
	return _history


func _layout() -> void:
	if _view == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_k = maxi(1, int(floor(minf(vp.x / float(W), vp.y / float(H)))))
	_view.size = Vector2(W * _k, H * _k)
	_view.position = ((vp - _view.size) * 0.5).floor()


# ── who is at the counter ────────────────────────────────────────────────────

func _new_progress(guest: Dictionary) -> Dictionary:
	var stranger := bool(guest.get("stranger", false))
	return {
		"card_pos": Vector2(222, 186),
		"slip_pos": Vector2(206, 126),
		"card_on_desk": false,
		"slip_on_desk": false,
		"slide": 0.0,                      # 0..1 papers coming across
		"has_slip": not stranger,
		"written_card": false,
		"written_slip": false,
		"keys_given": [],
		"stamp": "",                      # "in" / "out"
		"stamp_on": "",                   # "slip" / "card"
		"stamp_at": Vector2.ZERO,         # on the paper, px
		"stamp_rot": 0.0,
		"card_back": false,
		"slip_back": false,
		"row": _history.size() + 1,
		"greeted": false,
	}


func _set_guest(guest: Dictionary) -> void:
	_guest = guest
	_drag = ""
	_holding_stamp = ""
	_pen.clear()
	if guest.is_empty():
		_p = {}
		_guest_y = 1.0
		_guest_target = 1.0
		_say_line("")
		return
	var id := int(guest.get("id", -999))
	_p = _progress.get(id, _new_progress(guest))
	_progress[id] = _p
	_guest_y = 1.0
	_guest_target = 0.0
	if not bool(_p.get("greeted", false)):
		_p["greeted"] = true
		_say_line(_greeting())
	else:
		_say_line("We are still here.")


func _greeting() -> String:
	if bool(_guest.get("stranger", false)):
		return "..."
	var rooms: Array = _guest.get("rooms", [])
	var lodging := str((rooms[0] as Dictionary).get("label", "a tent")) if not rooms.is_empty() else "a tent"
	var n := int(_guest.get("party_size", 1))
	var lines := [
		"Good evening. %s, we booked %s." % [str(_guest.get("name", "")), lodging.to_lower()] if not _is_day() else "Hello. %s, we have a booking. %s." % [str(_guest.get("name", "")), lodging],
		"%s. %s, %d of us." % [str(_guest.get("name", "")), lodging, n],
	]
	return lines[absi(int(_guest.get("id", 0))) % lines.size()]


func _is_day() -> bool:
	var h := _hour()
	return h >= 6.0 and h < 20.0


func _hour() -> float:
	var main := get_tree().current_scene if get_tree() != null else null
	if main != null and main.get("_time_of_day_hours") != null:
		return float(main.get("_time_of_day_hours"))
	return 12.0


func _say_line(text: String) -> void:
	_say = text
	_say_shown = 0.0


func _refresh_keys() -> void:
	_keys = key_board_provider.call() if key_board_provider.is_valid() else []


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _closing_t >= 0.0:
		_closing_t += delta
		var f := 1.0 - clampf(_closing_t / (OPEN_SEC * 0.6), 0.0, 1.0)
		_set_open_fraction(f)
		if f <= 0.0:
			visible = false
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			closed.emit()
		return
	_open_t += delta
	_set_open_fraction(clampf(_open_t / OPEN_SEC, 0.0, 1.0))
	var m := (get_viewport().get_mouse_position() - _view.position) / float(_k)
	_mouse = m if Rect2(Vector2.ZERO, Vector2(W, H)).has_point(m) else Vector2(-1, -1)
	# The guest steps up to the counter, or away from it (in steps, like the sprites).
	var gspeed := 3.2
	if absf(_guest_y - _guest_target) > 0.001:
		_guest_y = move_toward(_guest_y, _guest_target, delta * gspeed)
		if _guest_y >= 1.0 and _guest_target >= 1.0 and _leave_then != "":
			_finish_leaving()
	if not _guest.is_empty() and _guest_y <= 0.05 and float(_p.get("slide", 0.0)) < 1.0:
		var was := float(_p["slide"])
		_p["slide"] = minf(1.0, was + delta * 2.4)
		if was == 0.0:
			_play("paper_slide", -6.0)
		if float(_p["slide"]) >= 1.0:
			_p["card_on_desk"] = true
			_p["slip_on_desk"] = bool(_p["has_slip"])
			_play("card_drop", -8.0)
	_say_shown = minf(float(_say.length()), _say_shown + delta * 40.0)
	_shake = maxf(0.0, _shake - delta * 6.0)
	for f in _pen.keys():
		_pen[f] = minf(1.0, float(_pen[f]) + delta * 1.4)
	if _guest.is_empty():
		_empty_t += delta
		if _empty_t > 0.8 and next_guest_provider.is_valid():
			_empty_t = 0.0
			var nxt: Dictionary = next_guest_provider.call()
			if not nxt.is_empty():
				_set_guest(nxt)
	_cursor()
	_canvas.queue_redraw()


func _set_open_fraction(f: float) -> void:
	var step := ceilf(f * 6.0) / 6.0
	_view.scale = Vector2(1.0, maxf(0.02, step))
	_view.pivot_offset = _view.size * 0.5
	_backdrop.color = Color(0, 0, 0, 0.8 * f)


func _cursor() -> void:
	if _mouse.x < 0.0:
		return
	if _drag != "" or _holding_stamp != "":
		HandCursor.want(HandCursor.GRAB)
	elif _thing_at(_mouse) != "":
		HandCursor.want(HandCursor.POINT)


# ── input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	# Esc goes on to the pause menu (main).
	if event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _closing_t >= 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_S:
		close_desk()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _holding_stamp != "":
				_holding_stamp = ""
				_play("ink", -12.0)
			else:
				close_desk()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if _mouse.x < 0.0:
			if mb.pressed:
				close_desk()
			return
		if mb.pressed:
			_press(_mouse)
		else:
			_release(_mouse)


func _press(p: Vector2) -> void:
	if _holding_stamp != "":
		_stamp_at(p)
		return
	var hit := _thing_at(p)
	if hit == "":
		return
	if hit.begins_with("stamp:"):
		_holding_stamp = hit.trim_prefix("stamp:")
		_play("ink", -10.0)
		return
	_drag = hit
	_drag_off = p - _thing_pos(hit)
	_play("paper_pick" if not hit.begins_with("key:") else "keys", -10.0)


func _release(p: Vector2) -> void:
	if _drag == "":
		return
	var what := _drag
	_drag = ""
	var pos := p - _drag_off
	if what.begins_with("key:"):
		_drop_key(what.trim_prefix("key:"), p)
		return
	var size := CARD_SIZE if what == "card" else SLIP_SIZE
	var rect := Rect2(pos, size)
	if p.y < GIVE.end.y - 4.0:
		_give_back(what)
		return
	pos.x = clampf(pos.x, -size.x * 0.4, W - size.x * 0.6)
	pos.y = clampf(pos.y, DESK.position.y - 6.0, H - size.y * 0.35)
	_p[what + "_pos"] = pos
	_play("paper_slide", -12.0)
	if BOOK.intersects(rect) and BOOK.has_point(p):
		_write_from(what)


func _drop_everything() -> void:
	_drag = ""
	_holding_stamp = ""


## What is under the mouse, topmost first: the dragged paper, papers, keys, stamps.
func _thing_at(p: Vector2) -> String:
	if _guest.is_empty() or float(_p.get("slide", 0.0)) < 1.0:
		return _stamp_under(p)
	var order: Array = ["slip", "card"] if _top_paper() == "slip" else ["card", "slip"]
	for d in order:
		if bool(_p.get(d + "_on_desk", false)) and Rect2(_paper_pos(d), CARD_SIZE if d == "card" else SLIP_SIZE).has_point(p):
			return d
	for k in _keys:
		var kd: Dictionary = k
		if _key_on_rack(kd) and Rect2(_key_pos(str(kd["key"])), KEY_SIZE).has_point(p):
			return "key:" + str(kd["key"])
	return _stamp_under(p)


func _stamp_under(p: Vector2) -> String:
	for s in STAMP_HOME.keys():
		if Rect2(STAMP_HOME[s], STAMP_SIZE).has_point(p):
			return "stamp:" + str(s)
	return ""


var _last_moved := "card"


func _top_paper() -> String:
	if _drag == "card" or _drag == "slip":
		_last_moved = _drag
	return _last_moved


func _thing_pos(id: String) -> Vector2:
	if id == "card" or id == "slip":
		return _paper_pos(id)
	if id.begins_with("key:"):
		return _key_pos(id.trim_prefix("key:"))
	return Vector2.ZERO


func _paper_pos(d: String) -> Vector2:
	if _drag == d and _mouse.x >= 0.0:
		return _mouse - _drag_off
	var at: Vector2 = _p.get(d + "_pos", Vector2.ZERO)
	var slide := float(_p.get("slide", 1.0))
	if slide < 1.0:
		# Pushed across the counter from where they stand.
		var from := Vector2(at.x + 10.0, 30.0)
		return from.lerp(at, slide).floor()
	return at


# ── the register ─────────────────────────────────────────────────────────────

func _write_from(what: String) -> void:
	var field := "written_" + what
	if bool(_p.get(field, false)):
		return
	_p[field] = true
	_pen[what] = 0.0
	_play("pen", -6.0)
	if bool(_guest.get("stranger", false)) and what == "card":
		# Nobody else is in the room. The pen is cold.
		_say_line("...")


func _row_for_current() -> Dictionary:
	var card: Dictionary = _guest.get("card", {})
	var rooms: Array = _guest.get("rooms", [])
	var labels: Array = []
	for r in rooms:
		labels.append(str((r as Dictionary).get("label", "")).to_upper().replace("TENT ", "T").replace("CABIN ", "C").replace("CARAVAN ", "V"))
	return {
		"no": int(_p.get("row", _history.size() + 1)),
		"name": "%s %s." % [str(card.get("surname", "")), str(card.get("first", "")).substr(0, 1)],
		"card": str(card.get("number", "")),
		"surname": str(card.get("surname", "")),
		"first": str(card.get("first", "")),
		"persons": str(int(_guest.get("party_size", 1))) if bool(_p.get("has_slip", true)) else "",
		"nights": str(int(_guest.get("stay_nights", 1))) if bool(_p.get("has_slip", true)) else "",
		"lodging": ", ".join(labels),
		"key": "",
		"day": _day,
		"red": bool(_guest.get("stranger", false)),
	}


# ── keys ─────────────────────────────────────────────────────────────────────

func _key_on_rack(k: Dictionary) -> bool:
	if bool(k.get("held", false)):
		return false
	if _p.is_empty():
		return true
	return not (_p.get("keys_given", []) as Array).has(str(k["key"])) and _drag != "key:" + str(k["key"])


func _key_index(key: String) -> int:
	for i in _keys.size():
		if str((_keys[i] as Dictionary)["key"]) == key:
			return i
	return -1


func _hook_pos(i: int) -> Vector2:
	var col := i % HOOK_COLS
	var row := floori(float(i) / HOOK_COLS) % HOOK_ROWS
	# Where the hooks are on the board picture (key_rack.png).
	return Vector2(RACK.position.x + 18.0 + col * 20.9, RACK.position.y + 15.0 + row * 37.0)


func _key_pos(key: String) -> Vector2:
	if _drag == "key:" + key and _mouse.x >= 0.0:
		return _mouse - _drag_off
	var i := _key_index(key)
	return _hook_pos(maxi(0, i)) - Vector2(KEY_SIZE.x * 0.5, 3.0)


func _drop_key(key: String, p: Vector2) -> void:
	if p.y >= GIVE.end.y - 4.0 or _guest.is_empty():
		_play("key_hang", -8.0)
		return
	var k: Dictionary = _keys[_key_index(key)] if _key_index(key) >= 0 else {}
	if bool(_guest.get("stranger", false)):
		if not bool(k.get("ready", false)):
			_say_line("...")
			_play("key_hang", -8.0)
			return
		(_p["keys_given"] as Array).append(key)
		_play("keys", -6.0)
		return
	var wanted: Array = []
	for r in _guest.get("rooms", []):
		wanted.append(str((r as Dictionary).get("key", "")))
	if not wanted.has(key):
		var mine := str(((_guest.get("rooms", []) as Array)[0] as Dictionary).get("label", "")) if not (_guest.get("rooms", []) as Array).is_empty() else "something else"
		_say_line("That is not ours. We booked %s." % mine)
		_play("wrong", -4.0)
		_play("key_hang", -10.0)
		_shake = 1.0
		return
	if not bool(k.get("ready", false)):
		_say_line("Is it made up? We will wait until it is.")
		_play("wrong", -4.0)
		_play("key_hang", -10.0)
		return
	(_p["keys_given"] as Array).append(key)
	_play("keys", -6.0)
	if _all_keys_given():
		_say_line("Thank you.")
	else:
		_say_line("And the other one?")


func _all_keys_given() -> bool:
	var given: Array = _p.get("keys_given", [])
	for r in _guest.get("rooms", []):
		if not given.has(str((r as Dictionary).get("key", ""))):
			return false
	return not (_guest.get("rooms", []) as Array).is_empty()


# ── stamps ───────────────────────────────────────────────────────────────────

func _stamp_at(p: Vector2) -> void:
	var kind := _holding_stamp
	_holding_stamp = ""
	if _guest.is_empty():
		_play("ink", -12.0)
		return
	# On the slip if it is under the stamp, else on the card.
	var target := ""
	var order: Array = [_top_paper(), "slip" if _top_paper() == "card" else "card"]
	for d in order:
		if bool(_p.get(d + "_on_desk", false)) and Rect2(_paper_pos(d), CARD_SIZE if d == "card" else SLIP_SIZE).has_point(p):
			target = d
			break
	if target == "":
		_play("ink", -12.0)
		return
	if str(_p.get("stamp", "")) != "":
		# One stamp per booking; the second goes on top, crooked.
		pass
	_p["stamp"] = kind
	_p["stamp_on"] = target
	_p["stamp_at"] = p - _paper_pos(target)
	_p["stamp_rot"] = randf_range(-0.22, 0.12)
	_shake = 1.4
	_play("stamp", -2.0)


# ── giving back ──────────────────────────────────────────────────────────────

func _give_back(what: String) -> void:
	_p[what + "_back"] = true
	_p[what + "_on_desk"] = false
	_play("paper_slide", -8.0)
	var need_slip := bool(_p.get("has_slip", true))
	var all_back := bool(_p.get("card_back", false)) and (not need_slip or bool(_p.get("slip_back", false)))
	if not all_back:
		return
	var stamp := str(_p.get("stamp", ""))
	if stamp == "":
		_bounce("Is that it? You have not stamped anything.")
		return
	if stamp == "out":
		_say_line("..." if bool(_guest.get("stranger", false)) else "We drove four hours. Fine.")
		_leave("refused")
		return
	if not bool(_p.get("written_card", false)) or (need_slip and not bool(_p.get("written_slip", false))):
		_bounce("Do you not write us in the book?")
		return
	if bool(_guest.get("stranger", false)):
		if (_p.get("keys_given", []) as Array).is_empty():
			_bounce("...")
			return
		_leave("stranger_in")
		return
	if not _all_keys_given():
		_bounce("And our key?")
		return
	var res: Dictionary = check_in_call.call(int(_guest.get("id", -1))) if check_in_call.is_valid() else {"ok": true}
	if not bool(res.get("ok", false)):
		_bounce("The room is not ready?")
		return
	_say_line("Thank you. Good night." if not _is_day() else "Thank you.")
	_leave("in")


func _bounce(line: String) -> void:
	# They push the papers back across the counter.
	_say_line(line)
	_play("wrong", -4.0)
	for d in ["card", "slip"]:
		if bool(_p.get(d + "_back", false)):
			_p[d + "_back"] = false
			_p[d + "_on_desk"] = d == "card" or bool(_p.get("has_slip", true))
			_p[d + "_pos"] = Vector2(230 + (0 if d == "card" else 22), 122)
	_play("paper_slide", -8.0)


func _leave(how: String) -> void:
	_leave_then = how
	_guest_target = 1.0
	if how == "in" or how == "stranger_in":
		var row := _row_for_current()
		var given: Array = _p.get("keys_given", [])
		row["key"] = "OK" if not given.is_empty() else ""
		_history.append(row)
	if how == "refused" and bool(_guest.get("stranger", false)):
		# He does not walk away. He is not there.
		_guest_y = 1.0
		_finish_leaving()


func _finish_leaving() -> void:
	var how := _leave_then
	_leave_then = ""
	var id := int(_guest.get("id", -999))
	var stranger := bool(_guest.get("stranger", false))
	_progress.erase(id)
	_set_guest({})
	_refresh_keys()
	match how:
		"in":
			checked_in.emit(id)
		"refused":
			if stranger:
				stranger_refused.emit()
			else:
				refused.emit(id)
		"stranger_in":
			stranger_admitted.emit()


func _play(sfx: String, db: float) -> void:
	var path := SFX + sfx + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var a: AudioStreamPlayer = _audio[_audio_i]
	_audio_i = (_audio_i + 1) % _audio.size()
	a.stream = load(path)
	a.volume_db = db
	a.pitch_scale = randf_range(0.95, 1.05)
	a.play()


## Harnesses and the shot driver: do a step of a check-in as the player would.
func debug_do(step: String) -> void:
	if _guest.is_empty():
		return
	_p["slide"] = 1.0
	_p["card_on_desk"] = not bool(_p.get("card_back", false))
	_p["slip_on_desk"] = bool(_p.get("has_slip", true)) and not bool(_p.get("slip_back", false))
	match step:
		"write":
			_write_from("card")
			_write_from("slip")
		"key":
			for r in _guest.get("rooms", []):
				_drop_key(str((r as Dictionary).get("key", "")), Vector2(200, 50))
		"wrong_key":
			for k in _keys:
				var kd: Dictionary = k
				var mine := false
				for r in _guest.get("rooms", []):
					mine = mine or str((r as Dictionary).get("key", "")) == str(kd["key"])
				if not mine and not bool(kd.get("held", false)):
					_drop_key(str(kd["key"]), Vector2(200, 50))
					return
		"stamp_in", "stamp_out":
			_holding_stamp = step.trim_prefix("stamp_")
			var on := "slip" if bool(_p.get("has_slip", true)) else "card"
			_stamp_at(_paper_pos(on) + Vector2(44, 70) if on == "slip" else _paper_pos(on) + Vector2(70, 40))
		"give":
			_give_back("card")
			if bool(_p.get("has_slip", true)):
				_give_back("slip")


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw_all() -> void:
	var c := _canvas
	var sh := Vector2(roundf(sin(_t * 70.0) * _shake), 0) if _shake > 0.05 else Vector2.ZERO
	c.draw_set_transform(sh)
	_draw_booth(c)
	_draw_desk(c)
	_draw_book(c)
	_draw_rack(c)
	_draw_stamps(c)
	# Papers: the one not on top first.
	var top := _top_paper()
	var order: Array = ["slip", "card"] if top == "card" else ["card", "slip"]
	for d in order:
		_draw_paper(c, d)
	_draw_dragged_key(c)
	if _holding_stamp != "" and _mouse.x >= 0.0:
		_draw_stamp_tool(c, _holding_stamp, _mouse - STAMP_SIZE * 0.5 + Vector2(0, -6), true)
	c.draw_set_transform(Vector2.ZERO)


func _draw_booth(c: Control) -> void:
	var view: Texture2D = _tex.get("desk_view")
	var dark := not _is_day()
	if view != null:
		var src_h := float(view.get_height()) * COUNTER_Y / float(H) * 1.6
		var src := Rect2(0, (view.get_height() - src_h) * 0.45, view.get_width(), src_h)
		c.draw_texture_rect_region(view, Rect2(0, 0, W, COUNTER_Y + 2), src, Color(0.5, 0.5, 0.62) if dark else Color.WHITE)
	else:
		c.draw_rect(Rect2(0, 0, W, COUNTER_Y + 2), Color8(92, 70, 48))
	# Whoever is at the counter, from the chest up, big.
	if not _guest.is_empty():
		var tex: Texture2D = _guest_tex()
		if tex != null:
			var zoom := 1.75
			var gw := tex.get_width() * zoom
			var gh := tex.get_height() * zoom
			var x := floorf(176.0 - gw * 0.5)
			var y := floorf(14.0 + _guest_y * 120.0)
			var col := Color.WHITE
			if bool(_guest.get("stranger", false)):
				col = Color(0.16, 0.15, 0.16)
			elif dark:
				col = Color(0.72, 0.72, 0.82)
			# Clip at the counter: draw only what is above it.
			var vis := minf(gh, COUNTER_Y - y)
			if vis > 0.0:
				c.draw_texture_rect_region(tex, Rect2(x, y, gw, vis), Rect2(0, 0, tex.get_width(), vis / zoom), col)
		if _say != "" and _guest_y < 0.3:
			_draw_bubble(c, _say.substr(0, int(_say_shown)))
	# The counter's edge.
	c.draw_rect(Rect2(0, COUNTER_Y, W, 12), Color8(58, 36, 22))
	c.draw_rect(Rect2(0, COUNTER_Y, W, 1), Color8(120, 84, 52))
	c.draw_rect(Rect2(0, COUNTER_Y + 11, W, 1), Color8(24, 14, 8))
	if _drag != "":
		# Where the papers go back: a lighter strip along the counter.
		c.draw_rect(Rect2(0, COUNTER_Y, W, 12), Color(1, 0.9, 0.6, 0.12 + 0.06 * sin(_t * 8.0)))


func _guest_tex() -> Texture2D:
	var path := str(_guest.get("sprite_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


func _draw_bubble(c: Control, text: String) -> void:
	var r := Rect2(262, 12, 206, 44)
	c.draw_rect(r, Color8(244, 238, 220))
	c.draw_rect(r, Color8(40, 30, 24), false, 1.0)
	for i in 6:
		c.draw_rect(Rect2(r.position.x - 6 + i, r.position.y + 18 + i, 6 - i, 1), Color8(244, 238, 220))
	c.draw_rect(Rect2(r.position.x - 6, r.position.y + 18, 1, 1), Color8(40, 30, 24))
	F_TYPE.draw_multiline_string(c.get_canvas_item(), r.position + Vector2(6, 14), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 12, 3, Color8(30, 24, 20))


func _draw_desk(c: Control) -> void:
	var top: Texture2D = _tex.get("desk_top")
	if top != null:
		var src := Rect2(0, top.get_height() * 0.38, top.get_width(), top.get_height() * 0.62)
		c.draw_texture_rect_region(top, Rect2(0, COUNTER_Y + 12, W, H - COUNTER_Y - 12), src)
	else:
		c.draw_rect(Rect2(0, COUNTER_Y + 12, W, H - COUNTER_Y - 12), Color8(70, 46, 30))


func _draw_book(c: Control) -> void:
	var tex: Texture2D = _tex.get("register")
	if tex != null:
		c.draw_texture_rect(tex, BOOK, false)
	else:
		c.draw_rect(BOOK, Color8(232, 222, 196))
	var left := BOOK.position.x + 8.0
	var right := BOOK.position.x + BOOK.size.x * 0.5 + 6.0
	var hy := BOOK.position.y + 17.0
	var head := Color(0.42, 0.18, 0.14)
	for h in [[left, "NO"], [left + 10, "NAME"], [right, "CARD NO"], [right + 38, "PERS"], [right + 56, "NTS"], [right + 70, "ROOM"], [right + 89, "KEY"]]:
		_print3(c, Vector2(float(h[0]), hy), str(h[1]), head)
	_print3(c, Vector2(BOOK.position.x + BOOK.size.x - 44, BOOK.position.y + 10), Season.date_str(_day), head)
	# The rows: the last ones written, then the one being written now.
	var rows: Array = []
	var start := maxi(0, _history.size() - (ROWS - 1))
	for i in range(start, _history.size()):
		rows.append(_history[i])
	var current := {}
	if not _guest.is_empty() and (bool(_p.get("written_card", false)) or bool(_p.get("written_slip", false))):
		current = _row_for_current()
	for i in rows.size():
		_draw_row(c, i, rows[i], 1.0, 1.0)
	if not current.is_empty():
		var a := float(_pen.get("card", 1.0)) if bool(_p.get("written_card", false)) else 0.0
		var b := float(_pen.get("slip", 1.0)) if bool(_p.get("written_slip", false)) else 0.0
		_draw_row(c, rows.size(), current, a, b)
	elif not _guest.is_empty():
		# The empty line waiting for them.
		var y := ROW_Y0 + rows.size() * ROW_H
		c.draw_rect(Rect2(BOOK.position.x + 6, y - 9, BOOK.size.x - 12, ROW_H - 1), Color(1.0, 0.95, 0.4, 0.10 + 0.05 * sin(_t * 4.0)))


func _draw_row(c: Control, i: int, row: Dictionary, left_k: float, right_k: float) -> void:
	var y := ROW_Y0 + i * ROW_H
	var red := bool(row.get("red", false)) and int(row.get("day", 0)) < _day
	var ink := INK_RED if red else INK
	var left := BOOK.position.x + 8.0
	var right := BOOK.position.x + BOOK.size.x * 0.5 + 6.0
	_hand(c, Vector2(left, y), str(row.get("no", "")), ink, 1.0, i * 31)
	if left_k > 0.0:
		_hand(c, Vector2(left + 10, y), str(row.get("name", "")), ink, left_k, i * 31 + 3)
		_hand(c, Vector2(right, y), str(row.get("card", "")), ink, left_k, i * 31 + 7)
	if right_k > 0.0:
		_hand(c, Vector2(right + 42, y), str(row.get("persons", "")), ink, right_k, i * 31 + 11)
		_hand(c, Vector2(right + 58, y), str(row.get("nights", "")), ink, right_k, i * 31 + 13)
		_hand(c, Vector2(right + 70, y), str(row.get("lodging", "")), ink, right_k, i * 31 + 17)
	if str(row.get("key", "")) != "":
		# A tick in the key column.
		var tx := right + 92.0
		for k in 3:
			c.draw_rect(Rect2(tx + k, y - 3 + k, 1, 1), ink)
		for k in 5:
			c.draw_rect(Rect2(tx + 3 + k, y - 1 - k, 1, 1), ink)


## Handwriting: the 3x5 hand (HAND), every letter nudged a pixel up or down, revealed
## left to right as the pen goes. `at.y` is the baseline.
func _hand(c: Control, at: Vector2, text: String, col: Color, k: float, salt: int) -> void:
	var n := int(ceilf(float(text.length()) * clampf(k, 0.0, 1.0)))
	var x := at.x
	for i in n:
		var ch := text.substr(i, 1).to_upper()
		var dy := -1.0 if ((salt + i * 3) % 5) == 0 else 0.0
		x += _glyph3(c, Vector2(x, at.y - 5.0 + dy), ch, col)


## The same face, upright: the printed column heads.
func _print3(c: Control, at: Vector2, text: String, col: Color) -> void:
	var x := at.x
	for i in text.length():
		x += _glyph3(c, Vector2(x, at.y - 5.0), text.substr(i, 1).to_upper(), col)


## Draws one 3x5 letter with its top-left at `top`; returns the advance.
func _glyph3(c: Control, top: Vector2, ch: String, col: Color) -> float:
	if ch == " ":
		return 3.0
	var bits := str(HAND.get(ch, ""))
	if bits.is_empty():
		return 2.0
	for b in 15:
		if bits[b] == "1":
			c.draw_rect(Rect2(top.x + float(b % 3), top.y + floorf(float(b) / 3.0), 1, 1), col)
	return 4.0


func _draw_rack(c: Control) -> void:
	var tex: Texture2D = _tex.get("key_rack")
	if tex != null:
		c.draw_texture_rect(tex, RACK, false)
	else:
		c.draw_rect(RACK, Color8(150, 104, 60))
	for i in mini(_keys.size(), HOOK_COLS * HOOK_ROWS):
		var k: Dictionary = _keys[i]
		var hook := _hook_pos(i)
		var label := str(k.get("key", ""))
		var kind := str(k.get("kind", ""))
		# The little white label under the hook.
		F_TINY.draw_string(c.get_canvas_item(), hook + Vector2(-7, 12), label, HORIZONTAL_ALIGNMENT_LEFT, 16, 8, Color8(40, 30, 20) if kind != "cabin" else Color8(20, 40, 110))
		if _key_on_rack(k):
			_draw_key(c, _key_pos(label), k)


func _draw_key(c: Control, pos: Vector2, k: Dictionary, lifted := false) -> void:
	pos = pos.floor()
	if lifted:
		c.draw_rect(Rect2(pos + Vector2(4, 5), KEY_SIZE), Color(0, 0, 0, 0.3))
	var tex: Texture2D = _tex.get("key_fob")
	if tex != null:
		c.draw_texture_rect(tex, Rect2(pos, KEY_SIZE), false)
	else:
		c.draw_rect(Rect2(pos + Vector2(4, 0), Vector2(8, 14)), Color8(200, 170, 70))
		c.draw_rect(Rect2(pos + Vector2(0, 14), Vector2(16, 16)), Color8(180, 30, 30))
	# A dot on the fob's label: green made up, red not.
	var dot := Color8(60, 200, 80) if bool(k.get("ready", false)) else Color8(230, 50, 40)
	c.draw_rect(Rect2(pos + Vector2(13, 9), Vector2(3, 3)), dot)


func _draw_dragged_key(c: Control) -> void:
	if not _drag.begins_with("key:"):
		return
	var key := _drag.trim_prefix("key:")
	var i := _key_index(key)
	if i >= 0:
		_draw_key(c, _key_pos(key), _keys[i], true)


func _draw_stamps(c: Control) -> void:
	c.draw_rect(PAD, Color8(30, 26, 40))
	c.draw_rect(PAD.grow(-3), Color8(54, 40, 96))
	for s in STAMP_HOME.keys():
		if _holding_stamp == s:
			continue
		_draw_stamp_tool(c, str(s), STAMP_HOME[s], false)


func _draw_stamp_tool(c: Control, kind: String, pos: Vector2, lifted: bool) -> void:
	pos = pos.floor()
	if lifted:
		c.draw_rect(Rect2(pos + Vector2(6, 10), STAMP_SIZE - Vector2(6, 6)), Color(0, 0, 0, 0.28))
	var tex: Texture2D = _tex.get("stamp")
	var tint := Color(0.75, 1.0, 0.78) if kind == "in" else Color(1.0, 0.72, 0.7)
	if tex != null:
		c.draw_texture_rect(tex, Rect2(pos, STAMP_SIZE), false, tint)
	else:
		c.draw_rect(Rect2(pos + Vector2(14, 0), Vector2(14, 22)), Color8(90, 60, 40))
		c.draw_rect(Rect2(pos + Vector2(4, 22), Vector2(34, 12)), Color8(40, 40, 40))
	var label := "CHECKED IN" if kind == "in" else "REFUSED"
	var w := F_TINY.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	F_TINY.draw_string(c.get_canvas_item(), pos + Vector2(floorf((STAMP_SIZE.x - w) * 0.5), STAMP_SIZE.y + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(240, 230, 200))


func _draw_paper(c: Control, d: String) -> void:
	if _guest.is_empty():
		return
	var slide := float(_p.get("slide", 0.0))
	if slide <= 0.0 or (slide >= 1.0 and not bool(_p.get(d + "_on_desk", false))):
		return
	if d == "slip" and not bool(_p.get("has_slip", true)):
		return
	var pos := _paper_pos(d).floor()
	var size := CARD_SIZE if d == "card" else SLIP_SIZE
	var lifted := _drag == d
	c.draw_rect(Rect2(pos + (Vector2(5, 6) if lifted else Vector2(2, 2)), size), Color(0, 0, 0, 0.34 if lifted else 0.22))
	if d == "card":
		_draw_card(c, pos)
	else:
		_draw_slip(c, pos)
	if str(_p.get("stamp_on", "")) == d:
		_draw_stamp_mark(c, pos + (_p.get("stamp_at", Vector2.ZERO) as Vector2), str(_p.get("stamp", "")), float(_p.get("stamp_rot", 0.0)))


func _draw_card(c: Control, pos: Vector2) -> void:
	var tex: Texture2D = _tex.get("id_card")
	if tex != null:
		c.draw_texture_rect(tex, Rect2(pos, CARD_SIZE), false)
	else:
		c.draw_rect(Rect2(pos, CARD_SIZE), Color8(206, 222, 196))
		c.draw_rect(Rect2(pos, CARD_SIZE), Color8(120, 130, 110), false, 1.0)
	var card: Dictionary = _guest.get("card", {})
	var ci := c.get_canvas_item()
	F_SILK.draw_string(ci, pos + Vector2(50, 11), "IDENTITY CARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(60, 70, 60))
	# The photo: the guest's own face, washed out, or nothing at all.
	var photo := Rect2(pos + Vector2(12, 18), Vector2(33, 35))
	var tex2 := _guest_tex()
	if bool(_guest.get("stranger", false)):
		c.draw_rect(photo.grow(-1), Color8(18, 16, 16))
	elif tex2 != null:
		var src := Rect2(tex2.get_width() * 0.14, 0, tex2.get_width() * 0.72, tex2.get_width() * 0.72 * 35.0 / 33.0)
		c.draw_texture_rect_region(tex2, photo.grow(-2), src, Color(0.86, 0.84, 0.78))
	var lab := Color8(90, 100, 90)
	var val := PAPER_TEXT
	var x := pos.x + 52.0
	F_TINY.draw_string(ci, Vector2(x, pos.y + 20), "SURNAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, lab)
	F_SILK.draw_string(ci, Vector2(x, pos.y + 27), str(card.get("surname", "")), HORIZONTAL_ALIGNMENT_LEFT, 54, 8, val)
	F_TINY.draw_string(ci, Vector2(x, pos.y + 34), "NAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, lab)
	F_SILK.draw_string(ci, Vector2(x, pos.y + 41), str(card.get("first", "")), HORIZONTAL_ALIGNMENT_LEFT, 54, 8, val)
	F_TINY.draw_string(ci, Vector2(x, pos.y + 49), "BORN %s" % str(card.get("born", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, val)
	F_TINY.draw_string(ci, Vector2(x, pos.y + 56), "VALID %s" % str(card.get("valid", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, val)
	F_TINY.draw_string(ci, Vector2(pos.x + 12, pos.y + 61), str(card.get("town", "")), HORIZONTAL_ALIGNMENT_LEFT, 38, 8, val)
	F_TINY.draw_string(ci, Vector2(x, pos.y + 64), str(card.get("number", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(150, 30, 30))


func _draw_slip(c: Control, pos: Vector2) -> void:
	var tex: Texture2D = _tex.get("booking")
	if tex != null:
		c.draw_texture_rect(tex, Rect2(pos, SLIP_SIZE), false)
	else:
		c.draw_rect(Rect2(pos, SLIP_SIZE), Color8(236, 240, 226))
	var ci := c.get_canvas_item()
	var x := pos.x + 12.0
	var y := pos.y + 14.0
	var ink := Color8(40, 40, 52)
	var lines := [
		"CAMPMAIL 98",
		"BOOKING CONFIRMED",
		"",
		"NAME     %s" % str(_guest.get("name", "")).to_upper(),
		"PERSONS  %d" % int(_guest.get("party_size", 1)),
		"NIGHTS   %d" % int(_guest.get("stay_nights", 1)),
	]
	var rooms: Array = _guest.get("rooms", [])
	for i in rooms.size():
		lines.append(("LODGING  " if i == 0 else "         ") + str((rooms[i] as Dictionary).get("label", "")).to_upper())
	lines.append("")
	lines.append("KEMP CERNE JEZERO")
	lines.append("HLUBOCANY DISTRICT")
	for l in lines:
		F_TINY.draw_string(ci, Vector2(x, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, SLIP_SIZE.x - 22, 8, ink)
		y += 9.0


func _draw_stamp_mark(c: Control, at: Vector2, kind: String, rot: float) -> void:
	var col := STAMP_GREEN if kind == "in" else STAMP_RED
	var label := "CHECKED IN" if kind == "in" else "REFUSED"
	var w := F_STAMP.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
	var hgt := 18.0
	c.draw_set_transform(at, rot)
	c.draw_rect(Rect2(-w * 0.5, -hgt * 0.5, w, hgt), col, false, 2.0)
	F_STAMP.draw_string(c.get_canvas_item(), Vector2(-w * 0.5 + 5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	# Where the rubber did not take: specks of paper through the ink.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 13.0 + at.y * 7.0)
	for i in 14:
		c.draw_rect(Rect2(Vector2(rng.randf_range(-w * 0.5, w * 0.5), rng.randf_range(-hgt * 0.5, hgt * 0.5)).floor(), Vector2.ONE), Color(0.93, 0.9, 0.82, 0.8))
	c.draw_set_transform(Vector2(roundf(sin(_t * 70.0) * _shake), 0) if _shake > 0.05 else Vector2.ZERO)
