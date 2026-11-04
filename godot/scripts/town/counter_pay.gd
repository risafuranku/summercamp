extends "res://scripts/closeup/closeup_view.gd"

## Paying at the counter, close up (counter_shop.gd opens it with the sum rung up): the
## counter's worn top from above, what you are buying, the till's display with the sum,
## the rubber mat, and your open wallet with your money in it as notes and coins (only what
## a wallet holds, however rich the camp: counter_goods.gd `wallet`). Take the pieces out and
## lay them on the mat, a click sends one across, a drag puts it where you like, off the mat
## it goes back into the wallet. Once what lies on the mat covers the sum, her hand comes
## down and sweeps it up, comes back with the change and leaves it on the mat, and the
## change goes into your wallet.
##
## Esc, a right click or a click outside the plate leave it unpaid.
## Nothing is said about any of this on the screen: a wallet, a mat, a sum on a till.

## She has taken the money: spend it now (counter_shop.gd).
signal paid

const GOODS = preload("res://scripts/town/counter_goods.gd")
const SEVEN = preload("res://scripts/ui/seven_seg.gd")
const SHOP := "res://assets/textury/shop/"
const SFX := "res://assets/sfx/shop/"
const SFX_DRAWER := "res://assets/sfx/jednota/drawer.mp3"
const STEP := 1.0 / 12.0
const PIC := SHOP + "pay_counter.png"
## Picture px. The mat you lay the money on (its rubber, not its edge), the wallet (the notes
## in its left leaf, the coins in the pouch).
const MAT_AT := Vector2(176, 30)
const TRAY := Rect2(184, 37, 119, 72)
const WALLET_AT := Vector2(46, 126)
## Each kind of note in its pile on the wallet's left leaf, the coins in the pouch.
const PILES := {5: Vector2(49, 133), 10: Vector2(106, 135), 20: Vector2(49, 175), 50: Vector2(106, 177)}
const PILE_STEP := Vector2(2, 3)
const COIN_SPOTS := [Vector2(182, 160), Vector2(206, 156), Vector2(230, 160), Vector2(194, 178), Vector2(218, 176), Vector2(242, 178), Vector2(170, 178)]
const GOODS_AT := Vector2(8, 118)
const TILL_AT := Vector2(0, 0)
## The till's display: where its digits go.
const WINDOW := Rect2(15, 8, 120, 15)
const LIT := Color(0.42, 1.0, 0.62)
const GHOST := Color(0.07, 0.17, 0.11)
## Her hand: over the mat, up out of the picture or down at the mat.
const HAND_X := 211.0
const HAND_SPEED := 22.0
const STAMP := Color(0.1, 0.09, 0.08, 0.92)

var _lines: Dictionary = {}
var _total := 0
var _goods: Array = []
## The money: {"v", "coin", "tex", "size", "at", "home", "on": "wallet"|"mat"|"hand"|"gone", "to"}.
var _pieces: Array = []
var _drag: Dictionary = {}
var _grab := Vector2.ZERO
var _press_at := Vector2.ZERO
var _state := "pay"
var _wait := 0.0
var _given := 0
var _hand_y := -200.0
var _hand_tex: Texture2D
var _step := 0.0
var _change: Array = []
var _change_i := 0
var _forced := false
var _tex: Dictionary = {}


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_hand_tex = _t("pay_hand")


func _t(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := SHOP + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


func _look_tex(id: String) -> Texture2D:
	var path := str(GOODS.LOOK.get(id, {}).get("tex", ""))
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


func _hand_up() -> float:
	return -float(_hand_tex.get_height()) - 2.0 if _hand_tex != null else -120.0


## Far enough down for her fingers to be on the mat.
func _hand_down() -> float:
	return TRAY.get_center().y + 16.0 - (float(_hand_tex.get_height()) if _hand_tex != null else 120.0)


## The sum rung up, what it is for, her words.
func open_pay(lines: Dictionary, total: int, ids: Array, line: String) -> void:
	_lines = lines
	_total = total
	_goods = ids
	_state = "pay"
	_forced = false
	_wait = 0.0
	_drag = {}
	_change = []
	_hand_y = _hand_up()
	_fill_wallet()
	open_view()
	play(SFX + "wallet_open.mp3", -2.0)
	say(str(lines.get("who", "")), line)


func _fill_wallet() -> void:
	_pieces.clear()
	var have: Dictionary = GOODS.wallet(CoreRoot.get_money())
	for v in [5, 10, 20, 50]:
		for i in int(have.get(v, 0)):
			_pieces.append(_piece(int(v), PILES[v] + PILE_STEP * float(i)))
	var c := 0
	for v in [2, 1]:
		for i in int(have.get(v, 0)):
			_pieces.append(_piece(int(v), COIN_SPOTS[c % COIN_SPOTS.size()]))
			c += 1


func _piece(v: int, at: Vector2) -> Dictionary:
	var coin := v <= 2
	var tex := _t(("coin_%d" if coin else "note_%d") % v)
	var size := Vector2(tex.get_size()) if tex != null else Vector2(22, 22) if coin else Vector2(72, 40)
	return {"v": v, "coin": coin, "tex": tex, "size": size, "at": at, "home": at, "on": "wallet"}


func _hotspots() -> Array:
	var out: Array = []
	if _state != "pay":
		return out
	for i in range(_pieces.size() - 1, -1, -1):
		var p: Dictionary = _pieces[i]
		if str(p["on"]) in ["wallet", "mat"]:
			out.append({"id": "p%d" % i, "rect": Rect2(p["at"], p["size"])})
	return out


func _clicked(id: String) -> void:
	var i := int(id.substr(1))
	if i < 0 or i >= _pieces.size():
		return
	var p: Dictionary = _pieces[i]
	_pieces.remove_at(i)
	_pieces.append(p)
	p.erase("to")
	_drag = p
	_grab = _mouse - (p["at"] as Vector2)
	_press_at = _mouse
	_wait = 0.0


## Let go of what you held: on the mat, back in the wallet; a click sends it across.
func _drop() -> void:
	var p := _drag
	_drag = {}
	if _mouse.x >= 0.0 and _mouse.distance_to(_press_at) < 3.0:
		if str(p["on"]) == "mat":
			_home(p)
		else:
			_lay(p, _mat_spot(p))
		return
	var mid: Vector2 = (p["at"] as Vector2) + (p["size"] as Vector2) * 0.5
	if TRAY.has_point(mid):
		var size: Vector2 = p["size"]
		var at: Vector2 = p["at"]
		_lay(p, Vector2(clampf(at.x, TRAY.position.x, TRAY.end.x - size.x), clampf(at.y, TRAY.position.y, TRAY.end.y - size.y)).floor())
	else:
		_home(p)


func _lay(p: Dictionary, at: Vector2) -> void:
	p["on"] = "mat"
	p["to"] = at
	play(SFX + ("coin_mat.mp3" if bool(p["coin"]) else "note_mat.mp3"), -2.0)


func _home(p: Dictionary) -> void:
	p["on"] = "wallet"
	p["to"] = p["home"]


## Where a piece sent across lands: notes to the left of the mat, each a little further on,
## coins along its right side.
func _mat_spot(p: Dictionary) -> Vector2:
	var n := 0
	var size: Vector2 = p["size"]
	for q in _pieces:
		if q != p and str(q["on"]) == "mat" and bool(q["coin"]) == bool(p["coin"]):
			n += 1
	if bool(p["coin"]):
		return TRAY.position + Vector2(TRAY.size.x - size.x - 4.0 - float(n % 3) * 24.0, 4.0 + float((n / 3) % 3) * 24.0)
	return TRAY.position + Vector2(4.0 + float(n % 4) * 7.0, 4.0 + float(n % 4) * 9.0)


func _sum() -> int:
	var n := 0
	for p in _pieces:
		if str(p["on"]) == "mat":
			n += int(p["v"])
	return n


func _moving() -> bool:
	for p in _pieces:
		if p.has("to"):
			return true
	return false


# ── every frame ──────────────────────────────────────────────────────────────

func _tick(delta: float) -> void:
	if not _drag.is_empty():
		HandCursor.want(HandCursor.GRAB)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _mouse.x >= 0.0:
			_drag["at"] = (_mouse - _grab).floor()
		else:
			_drop()
	_step += delta
	while _step >= STEP:
		_step -= STEP
		_step12()
	if _state == "pay" and _drag.is_empty() and not _moving() and _sum() >= _total:
		_wait += delta
		if _wait >= 0.45:
			_state = "reach"
			_given = _sum()
	elif _state == "pay":
		_wait = 0.0
	elif _state == "thanks":
		_wait += delta
		if _wait >= 1.0:
			_forced = true
			close_view()


## What moves, twelve steps a second.
func _step12() -> void:
	for p in _pieces:
		if p.has("to"):
			var to: Vector2 = p["to"]
			p["at"] = (p["at"] as Vector2).move_toward(to, 34.0)
			if (p["at"] as Vector2).is_equal_approx(to):
				p.erase("to")
	match _state:
		"reach":
			_hand_y = move_toward(_hand_y, _hand_down(), HAND_SPEED)
			if is_equal_approx(_hand_y, _hand_down()):
				play(SFX + "money_sweep.mp3", -2.0)
				for p in _pieces:
					if str(p["on"]) == "mat":
						p["on"] = "hand"
				_state = "sweep"
		"sweep":
			var was := _hand_y
			_hand_y = move_toward(_hand_y, _hand_up(), HAND_SPEED)
			for p in _pieces:
				if str(p["on"]) == "hand":
					p["at"] = (p["at"] as Vector2) + Vector2(0, _hand_y - was)
			if is_equal_approx(_hand_y, _hand_up()):
				_taken()
		"count_in":
			_hand_y = move_toward(_hand_y, _hand_down(), HAND_SPEED)
			if is_equal_approx(_hand_y, _hand_down()):
				_state = "count"
				_wait = 0.0
				_change_i = 0
				play(SFX + "change_count.mp3", -2.0)
		"count":
			_wait += STEP
			if _wait >= 0.3:
				_wait = 0.0
				if _change_i < _change.size():
					_leave_change(int(_change[_change_i]))
					_change_i += 1
				else:
					_state = "count_out"
		"count_out":
			_hand_y = move_toward(_hand_y, _hand_up(), HAND_SPEED)
			if is_equal_approx(_hand_y, _hand_up()):
				play(SFX + "coins_back.mp3", -2.0)
				for p in _pieces:
					if str(p["on"]) == "mat":
						p["on"] = "wallet"
						p["to"] = p["home"]
				_wait = 0.0
				_state = "thanks"


## The money is hers. The change, or nothing.
func _taken() -> void:
	for p in _pieces.duplicate():
		if str(p["on"]) == "hand":
			_pieces.erase(p)
	paid.emit()
	play(SFX_DRAWER, -6.0)
	var back := _given - _total
	_change = GOODS.change_in(back)
	if _change.is_empty():
		say(str(_lines.get("who", "")), str(_lines.get("exact", "")))
		_wait = 0.0
		_state = "thanks"
		return
	var big: bool = back >= 15 and back >= _total * 6
	say(str(_lines.get("who", "")), str(_lines.get("big", "")) if big else str(_lines.get("change", "")) % back)
	_state = "count_in"


## A piece of the change onto the mat; its place in the wallet is the first free of its kind.
func _leave_change(v: int) -> void:
	var same := 0
	var coins := 0
	for q in _pieces:
		if bool(q["coin"]):
			coins += 1
		if int(q["v"]) == v:
			same += 1
	var home: Vector2 = COIN_SPOTS[coins % COIN_SPOTS.size()] if v <= 2 else PILES[v] + PILE_STEP * float(same % 4)
	var size := Vector2(24, 24) if v <= 2 else Vector2(57, 33)
	var p := _piece(v, (TRAY.get_center() - size * 0.5 + Vector2(float(_change_i % 3 - 1) * 20.0, float(_change_i % 2) * 12.0 - 6.0)).floor())
	p["home"] = home
	p["on"] = "mat"
	_pieces.append(p)


func close_view() -> void:
	# Once she has reached for it, it is done (only the room going ends it: force_close).
	if _state != "pay" and not _forced:
		return
	super.close_view()


func force_close() -> void:
	_forced = true
	close_view()


func _closing() -> void:
	play(SFX + "wallet_shut.mp3", -2.0)


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if picture == null:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.3, 0.27, 0.22))
	_paint_goods(c)
	var mat := _t("pay_mat")
	if mat != null:
		c.draw_texture(mat, MAT_AT)
	var till := _t("pay_till")
	if till != null:
		c.draw_texture(till, TILL_AT)
	_paint_sum(c)
	var wallet := _t("pay_wallet")
	if wallet != null:
		c.draw_texture(wallet, WALLET_AT)
	for p in _pieces:
		if p == _drag:
			continue
		_paint_piece(c, p)
	if not _drag.is_empty():
		c.draw_texture(_drag["tex"], (_drag["at"] as Vector2) + Vector2(3, 4), Color(0, 0, 0, 0.45))
		_paint_piece(c, _drag)
	if _hand_tex != null and _hand_y > _hand_up():
		c.draw_texture(_hand_tex, Vector2(HAND_X, _hand_y))


## What you are buying, in a row along the counter.
func _paint_goods(c: Control) -> void:
	var x := GOODS_AT.x
	var row_y := GOODS_AT.y
	for id in _goods:
		var t := _look_tex(str(id))
		if t == null:
			continue
		var w := float(t.get_width())
		var h := float(t.get_height())
		if x + w > MAT_AT.x:
			x = GOODS_AT.x + 6.0
			row_y -= 34.0
		var at := Vector2(x, row_y - h).floor()
		c.draw_texture(t, at + Vector2(2, 2), Color(0, 0, 0, 0.35))
		c.draw_texture(t, at)
		x += w + 3.0


func _paint_sum(c: Control) -> void:
	var h := WINDOW.size.y - 6.0
	var text := GOODS.face(_total)
	var x := WINDOW.end.x - SEVEN.text_width(text, h) - 2.0
	var y := WINDOW.position.y + 3.0
	var ghost := "8888"
	SEVEN.draw_text(c, Vector2(WINDOW.end.x - SEVEN.text_width(ghost, h) - 2.0, y), h, ghost, GHOST, GHOST, true, false)
	SEVEN.draw_text(c, Vector2(x, y), h, text, LIT, GHOST, true, true)


func _paint_piece(c: Control, p: Dictionary) -> void:
	var at: Vector2 = (p["at"] as Vector2).floor()
	var size: Vector2 = p["size"]
	var tex: Texture2D = p["tex"]
	if tex != null:
		c.draw_texture(tex, at)
	else:
		c.draw_rect(Rect2(at, size), Color(0.5, 0.5, 0.45))
	var face := GOODS.face(int(p["v"]))
	var f: Font = RETRO_UI.FONT_LABEL
	var w := f.get_string_size(face, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	if bool(p["coin"]):
		ink(c, f, at + Vector2(floorf((size.x - w) * 0.5) + 1.0, floorf(size.y * 0.5) + 3.0), face, STAMP)
	else:
		# In the pale oval on the note's right.
		ink(c, f, at + Vector2(floorf(size.x * 0.76 - w * 0.5), floorf(size.y * 0.5) + 3.0), face, STAMP)
	if hovered() != "" and _hovered_piece() == p:
		c.draw_rect(Rect2(at, size), Color(1.0, 0.92, 0.6, 0.14))


func _hovered_piece() -> Dictionary:
	var i := int(hovered().substr(1))
	return _pieces[i] if i >= 0 and i < _pieces.size() else {}


# ── for the tools ────────────────────────────────────────────────────────────

## Lays pieces on the mat as a player would, biggest first, until the sum is covered.
func debug_cover() -> void:
	var order := _pieces.duplicate()
	order.sort_custom(func(a, b): return int(a["v"]) > int(b["v"]))
	for p in order:
		if _sum() >= _total:
			break
		if int(p["v"]) + _sum() > _total + 4 and p != order.back():
			continue
		_lay(p, _mat_spot(p))


## The exact sum from the smallest pieces that make it, or debug_cover.
func debug_piece_to_mat(v: int) -> bool:
	for p in _pieces:
		if int(p["v"]) == v and str(p["on"]) == "wallet":
			_lay(p, _mat_spot(p))
			return true
	return false
