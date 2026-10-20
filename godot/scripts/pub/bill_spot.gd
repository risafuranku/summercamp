extends Node3D

## The bill on the bar (the brief of 20. 10.: "a mark on the mat for every beer; at the end
## the guest pays by the marks: count them and take it right"), worked at the tap station
## on the bar right of the tower, the guests' side (scripts/pub/tap_station.gd; left of
## the tower the board of mugs would hide it): the mat of the one
## who asked for the bill (the picked bill on the rail, else the oldest) with its marks in
## pencil, a stroke a beer, a cross a shot, a ring a kofola (pub_rules.TAB), the note
## they put down on it; the waiter's black wallet at your edge of the bar, in front of
## the bottles, with its four places (1, 2, 5, 10).
##   the note    a click: into the wallet (the right money: that is it, settled)
##   the wallet  a click on a place: that piece of change onto the mat
##   the mat     a click with the change on it: handed over (taproom.settle): short and
##               they say so, too much and they keep it; CLEAR (the frame) takes it back
## The marks are counted by you: the frame's big mat has them and the board's prices.

const PUB := preload("res://core/systems/pub_rules.gd")
const J_TEX := "res://assets/textury/jednota/"
## On the bar (the tap station's design px).
const MAT_AT := Vector2(420, 110)
const MAT := Rect2(370, 66, 100, 88)
const WALLET_AT := Vector2(527, 226)
const WALLET := [[1, Rect2(452, 200, 30, 50)], [2, Rect2(484, 200, 30, 50)], [5, Rect2(516, 200, 38, 50)], [10, Rect2(556, 200, 46, 50)]]
const PIECE_TEX := {1: "coin1", 2: "coin2", 5: "note5", 10: "note10", 20: "note20", 50: "note50"}
const PIECE_M := {1: 0.035, 2: 0.04, 5: 0.075, 10: 0.075, 20: 0.075, 50: 0.075}
const MAT_M := 0.13

## The station (tap_station.gd) this lies on.
var st
## The bill on the bar now ({} none) and what has been done with it here: the note taken
## into the wallet, the change counted onto the mat.
var bill: Dictionary = {}
var taken := false
var given: Array = []
var _mat: Sprite3D
var _marks: Label3D
var _notes: Array = []
var _change: Array = []
var _wallet: Sprite3D
var _piles: Array = []


func setup(station) -> void:
	st = station
	_mat = st.sprite(st.PUB_TEX + "mat.png", MAT_M, true, self)
	_marks = Label3D.new()
	_marks.font = load("res://scripts/ui/retro_ui.gd").FONT_LABEL
	_marks.font_size = 8
	_marks.pixel_size = 0.45 / st.PX_PER_M
	_marks.modulate = Color(0.22, 0.2, 0.24)
	_marks.shaded = true
	_marks.double_sided = true
	_marks.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_marks.outline_size = 0
	_marks.rotation_degrees.x = -90.0
	add_child(_marks)
	for i in 3:
		var n: Sprite3D = st.sprite(J_TEX + "note20.png", 0.075, true, self)
		n.visible = false
		_notes.append(n)
	for i in 10:
		var c: Sprite3D = st.sprite(J_TEX + "coin1.png", 0.035, true, self)
		c.visible = false
		_change.append(c)
	# The waiter's wallet (pub/wallet.png, Grok) open on the bar; without it the change
	# lies in four little piles.
	_wallet = st.sprite("res://assets/textury/pub/wallet.png", 0.3, true, self)
	st.put(_wallet, WALLET_AT, 0.003)
	for d in WALLET:
		var v := int(d[0])
		var r: Rect2 = d[1]
		for k in 2:
			var p: Sprite3D = st.sprite(J_TEX + str(PIECE_TEX[v]) + ".png", float(PIECE_M[v]), true, self)
			if v >= 5:
				p.rotation_degrees.y = 90.0
			st.put(p, r.get_center() + Vector2(0, -8 + k * 16), 0.006 + 0.002 * k)
			_piles.append(p)


## The bill to work: the picked one if it is a bill, else the oldest; a new one clears
## what was counted for the last.
func pick(b: Dictionary) -> void:
	if str(b.get("id", "")) != str(bill.get("id", "")):
		taken = false
		given = []
	bill = b


func given_sum() -> int:
	var n := 0
	for v in given:
		n += int(v)
	return n


## What they put down, as pieces (the note, or the right money in notes and coins).
func paid_pieces() -> Array:
	var note := int(bill.get("note", 0))
	if note > 0:
		var out: Array = []
		var left := note
		while left >= 50:
			out.append(50)
			left -= 50
		if left > 0:
			out.append(left)
		return out
	var out2: Array = []
	var amount := PUB.to_pay(bill)
	for v in [50, 20, 10, 5, 2, 1]:
		while amount >= v and out2.size() < 6:
			out2.append(v)
			amount -= v
	return out2


func show_state() -> void:
	var on := not bill.is_empty()
	_mat.visible = on
	_marks.visible = on
	if on:
		st.put(_mat, MAT_AT, 0.004)
		_marks.text = marks_text(bill.get("counts", {}))
		_marks.position = st.local_at(MAT_AT + Vector2(0, -2), 0.007)
	var pieces: Array = paid_pieces() if on and not taken else []
	for i in _notes.size():
		var n: Sprite3D = _notes[i]
		n.visible = i < pieces.size()
		if n.visible:
			var v := int(pieces[i])
			st.retex(n, J_TEX + str(PIECE_TEX.get(v, "note20")) + ".png", float(PIECE_M.get(v, 0.075)))
			st.put(n, MAT_AT + Vector2(-22 + i * 14, 18 + i * 3), 0.008 + 0.002 * i)
	for i in _change.size():
		var c: Sprite3D = _change[i]
		c.visible = on and i < given.size()
		if c.visible:
			var v2 := int(given[i])
			st.retex(c, J_TEX + str(PIECE_TEX.get(v2, "coin1")) + ".png", float(PIECE_M.get(v2, 0.035)))
			st.put(c, MAT_AT + Vector2(-30 + (i % 5) * 15, -22 + (i / 5) * 14), 0.01 + 0.002 * i)


## The marks on a mat as the landlord's pencil has them: strokes, crosses, rings.
static func marks_text(counts: Dictionary) -> String:
	var parts: Array = []
	for c in ["beer", "shot", "kofola"]:
		var n := int(counts.get(c, 0))
		if n > 0:
			parts.append(str(PUB.TAB[c]["mark"]).repeat(n).to_upper())
	return " ".join(parts)


func spots() -> Array:
	var out: Array = []
	if bill.is_empty():
		return out
	var who := str(bill.get("name", "")).split(" ")[0]
	if not taken:
		var note := int(bill.get("note", 0))
		var verb := "Take %s's $%d" % [who, note] if note > 0 else "Take %s's money: the right amount" % who
		out.append({"id": "bill:mat", "rect": MAT, "verb": verb})
		return out
	for d in WALLET:
		out.append({"id": "bill:%d" % int(d[0]), "rect": d[1], "verb": "$%d of change onto the mat (%d on it)" % [int(d[0]), given_sum()]})
	out.append({"id": "bill:mat", "rect": MAT, "verb": "Hand %s the change: $%d" % [who, given_sum()]})
	return out


## A press on the bill's things: true when it was one of them.
func press(id: String) -> bool:
	if not id.begins_with("bill:") or bill.is_empty():
		return false
	var what := id.substr(5)
	if what == "mat":
		if not taken:
			taken = true
			st.sfx("res://assets/sfx/jednota/note.mp3", -10.0)
			if int(bill.get("note", 0)) == 0:
				_settle()
			return true
		_settle()
		return true
	var v := int(what)
	if given.size() < _change.size():
		given.append(v)
		st.sfx("res://assets/sfx/jednota/coin.mp3", -10.0, randf_range(0.95, 1.1))
	return true


func clear() -> void:
	given = []


func _settle() -> void:
	var who := str(bill.get("name", "")).split(" ")[0]
	var v: Dictionary = st.taproom.settle(st.building_key, bill, given_sum())
	if not bool(v.get("ok", false)):
		st.say(who, "That's short. %d more." % int(v.get("short", 0)))
		st.sfx("tick", -12.0, 0.7)
		return
	st.sfx("coins_bar", -8.0)
	st.pop("+$%d" % int(v["kept"]), MAT_AT + Vector2(0, 30), load("res://scripts/ui/retro_ui.gd").C_AMBER_LIGHT, true)
	v["ok"] = true
	st.score_card(v, "The bill")
	if int(v.get("over", 0)) > 0:
		st.say(who, "Thank you very much!")
	elif int(bill.get("make_it", 0)) > 0:
		st.say(who, ["Keep the change.", "Na shledanou.", "Good beer tonight."][randi() % 3])
	else:
		st.say(who, "Na shledanou.")
	bill = {}
	taken = false
	given = []
