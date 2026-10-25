extends Control

## DataPunch 98: night work for the District Office (Okresni urad Hlubocany). The old
## register of everyone who stayed in the camps round the reservoir, 1961-1989, is being
## put on computer; anyone with a PC can type cards in at home and is paid per card.
## A card comes up (a scan: a filing card, typed and handwritten), you type its four
## fields into the form, Enter files it. Paid by how well you copy it: every field right
## pays the full rate, a slip or two less, more and nothing. The office takes every card
## you send (playtest 25. 10.: "no limit"); it stays pocket money (a guest pays more for
## one night). While you type you are not watching the camp. The fields are letters only
## (the same playtest: "no numbers, so the hands stay on the letters").
##
## Some of the old cards are not old.
##
## The cards are in the program's own memory; what was paid tonight is the shell's
## (export_persistent_state) so a reboot does not reset the night.

const T = preload("res://scripts/os98/os_theme.gd")
const RATE := 4                 # $ for a perfect card
const FIELDS := ["Surname", "First name", "Born in", "Stayed at"]
const SURNAMES := ["NOVAK", "DVORAK", "SVOBODA", "CERNY", "PROCHAZKA", "KUCERA", "VESELY", "HORAK", "NEMEC", "POKORNY", "MAREK", "POSPISIL", "HAJEK", "KRAL", "JELINEK", "RUZICKA", "BENES", "FIALA", "SEDLACEK", "DOLEZAL", "ZEMAN", "KOLAR", "NAVRATIL", "CERMAK", "VANEK", "URBAN", "BLAZEK", "KRIZ", "KOVAR", "BARTOS"]
const NAMES := ["JAN", "PETR", "JOSEF", "PAVEL", "JIRI", "MARIE", "JANA", "EVA", "HANA", "ANNA", "KAREL", "ZDENEK", "MILOS", "VLASTA", "LUDMILA", "JAROSLAV", "BOHUMIL", "VERA", "DANA", "IVANA"]
const TOWNS := ["PRAHA", "BRNO", "PLZEN", "KOLIN", "TABOR", "PISEK", "JIHLAVA", "KLADNO", "OLOMOUC", "PARDUBICE", "HLUBOCANY", "LIBLICE", "STRAKONICE", "BENESOV", "PRIBRAM", "ZNOJMO"]
const PLACES := ["KEMP CERNE JEZERO", "KEMP LIBLICE", "RZ HLUBOCANY", "KEMP U HRAZE", "PIONYRSKY TABOR", "CHATY POD LESEM"]

var _shell
var _card: Control
var _inputs: Array = []
var _status: Label
var _pay: Label
var _cur: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _stamp := ""
var _stamp_t := 0.0


const HEAD_H := 46


func setup(shell, _win, _args: Dictionary) -> void:
	_shell = shell
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = Control.new()
	_card.position = Vector2(10, HEAD_H + 10)
	_card.size = Vector2(300, 168)
	_card.draw.connect(_draw_card)
	add_child(_card)
	# The form beside the scan: four fields, Enter goes on to the next, the last files it.
	var x := 320.0
	var y := HEAD_H + 10.0
	for i in FIELDS.size():
		var l := Label.new()
		l.text = FIELDS[i] + ":"
		l.position = Vector2(x, y)
		add_child(l)
		var e := LineEdit.new()
		e.position = Vector2(x, y + 15)
		e.size = Vector2(140, 22)
		e.max_length = 28
		var idx := i
		e.text_submitted.connect(func(_t): _next_field(idx))
		add_child(e)
		_inputs.append(e)
		y += 42.0
	var file := Button.new()
	file.text = "File card  (Enter)"
	file.position = Vector2(x, y + 2)
	file.size = Vector2(140, 24)
	file.focus_mode = Control.FOCUS_NONE
	file.pressed.connect(_file)
	add_child(file)
	_pay = Label.new()
	_pay.position = Vector2(10, HEAD_H + 186)
	add_child(_pay)
	_status = Label.new()
	_status.position = Vector2(10, HEAD_H + 204)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.size = Vector2(450, 40)
	add_child(_status)
	var how := Label.new()
	how.text = "Copy each field of the card exactly as it is written. A card with every field\nright is paid in full, one or two slips are paid half, more are not paid."
	how.position = Vector2(10, HEAD_H + 250)
	how.add_theme_color_override("font_color", T.SHADOW)
	add_child(how)
	_new_card()
	_refresh_pay()


func shown() -> void:
	if not _inputs.is_empty():
		(_inputs[0] as LineEdit).grab_focus.call_deferred()


## The office's band over the work, like the other jobs' programs.
func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, HEAD_H), Color8(60, 40, 30))
	draw_rect(Rect2(0, HEAD_H - 2, w, 2), Color8(190, 60, 50))
	draw_string(T.FONT_BOLD, Vector2(10, 20), "DataPunch 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(236, 226, 196))
	draw_string(T.FONT, Vector2(12, 38), "Okresni urad Hlubocany - register transcription 1961-1989", HORIZONTAL_ALIGNMENT_LEFT, w - 170, T.FONT_SIZE, Color8(210, 190, 160))
	var cells := [["TONIGHT", "%d" % _done_tonight()], ["A CARD", "$%d" % RATE]]
	var x := w - 4.0
	for i in range(cells.size() - 1, -1, -1):
		x -= 70.0
		var r := Rect2(x, 6, 70, HEAD_H - 14)
		draw_style_box(T.box("field", Color8(20, 20, 20), Vector4.ZERO), r)
		draw_string(T.FONT, r.position + Vector2(5, 12), str(cells[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(120, 200, 120))
		draw_string(T.FONT_BOLD, r.position + Vector2(5, 26), str(cells[i][1]), HORIZONTAL_ALIGNMENT_LEFT, 62, T.FONT_SIZE, Color8(90, 255, 120))
		x -= 4.0


func _night_key() -> String:
	var day := CoreRoot.get_day() if CoreRoot != null else 1
	var main = _shell.get_tree().current_scene if _shell != null else null
	var h := float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 22.0
	# Before 06:00 the night belongs to the day before.
	return str(day - (1 if h < 12.0 else 0))


func _done_tonight() -> int:
	var d: Dictionary = _shell.get_meta("datapunch_nights", {}) if _shell != null else {}
	return int(d.get(_night_key(), 0))


func _add_done(n: int) -> void:
	var d: Dictionary = _shell.get_meta("datapunch_nights", {})
	d[_night_key()] = int(d.get(_night_key(), 0)) + n
	_shell.set_meta("datapunch_nights", d)


func _refresh_pay() -> void:
	_pay.text = "Card %d of tonight's batch." % (_done_tonight() + 1)
	queue_redraw()


func _new_card() -> void:
	var n := _done_tonight()
	var wrong := n > 6 and _rng.randf() < 0.07
	var year := _rng.randi_range(1961, 1989)
	_cur = {
		"Surname": SURNAMES[_rng.randi_range(0, SURNAMES.size() - 1)],
		"First name": NAMES[_rng.randi_range(0, NAMES.size() - 1)],
		"Born in": TOWNS[_rng.randi_range(0, TOWNS.size() - 1)],
		"Stayed at": PLACES[_rng.randi_range(0, PLACES.size() - 1)],
		"year": year,
		"note": "",
		"hand": _rng.randf() < 0.55,
		"seed": _rng.randi(),
	}
	if wrong:
		# One of the cards that should not be in the box.
		var odd := _rng.randi_range(0, 2)
		match odd:
			0:
				_cur["year"] = 1998
				_cur["Stayed at"] = "KEMP CERNE JEZERO"
				_cur["note"] = "DID NOT LEAVE"
			1:
				_cur["Surname"] = "HRUBY"
				_cur["First name"] = "?"
				_cur["note"] = "SEE CARD 0"
			_:
				_cur["Born in"] = "CERNE JEZERO"
				_cur["note"] = "STILL HERE"
	for e in _inputs:
		(e as LineEdit).text = ""
	if not _inputs.is_empty() and is_visible_in_tree():
		(_inputs[0] as LineEdit).grab_focus()
	_card.queue_redraw()


func _next_field(i: int) -> void:
	if i + 1 < _inputs.size():
		(_inputs[i + 1] as LineEdit).grab_focus()
	else:
		_file()


func _file() -> void:
	var slips := 0
	for i in FIELDS.size():
		slips += _distance(str((_inputs[i] as LineEdit).text).strip_edges().to_upper(), str(_cur[FIELDS[i]]))
	var pay := RATE if slips == 0 else (RATE / 2 if slips <= 2 else 0)
	if pay > 0 and Coop.is_client():
		# Co-op: the till is the host's.
		Coop.send_request("money", [pay])
	elif pay > 0 and CoreRoot.actions != null:
		CoreRoot.actions.add_money(pay)
	_add_done(1)
	_stamp = "FILED" if pay == RATE else ("FILED -%d" % (RATE - pay) if pay > 0 else "REJECTED")
	_stamp_t = 1.2
	_status.text = ("Filed. $%d." % pay) if slips == 0 else (("%d slip%s. $%d." % [slips, "" if slips == 1 else "s", pay]) if pay > 0 else "Too many mistakes. The office will not pay for this one.")
	if str(_cur.get("note", "")) != "":
		_status.text += " The card is not in the batch list."
	_shell.play("click" if pay > 0 else "error", -8.0)
	_refresh_pay()
	_new_card()


## Letters out of place (an edit distance, small strings).
static func _distance(a: String, b: String) -> int:
	var n := a.length()
	var m := b.length()
	if n == 0:
		return m
	var prev: Array = []
	for j in m + 1:
		prev.append(j)
	for i in range(1, n + 1):
		var cur: Array = [i]
		for j in range(1, m + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur.append(mini(mini(int(prev[j]) + 1, int(cur[j - 1]) + 1), int(prev[j - 1]) + cost))
		prev = cur
	return int(prev[m])


func _process(delta: float) -> void:
	if _stamp_t > 0.0:
		_stamp_t -= delta
		_card.queue_redraw()


## The scanned card: cream card, a red line under the header, typed labels, the entries
## in typewriter or in ink (crooked), a stamp when filed.
func _draw_card() -> void:
	var c := _card
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color8(48, 44, 40))
	var card := Rect2(Vector2(6, 6), s - Vector2(12, 12))
	c.draw_rect(card, Color8(236, 226, 196))
	c.draw_rect(Rect2(card.position + Vector2(0, 26), Vector2(card.size.x, 1)), Color8(190, 60, 50))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_cur.get("seed", 1))
	# Foxing: brown spots of age.
	for i in 14:
		var p := card.position + Vector2(rng.randf() * card.size.x, rng.randf() * card.size.y)
		c.draw_rect(Rect2(p, Vector2(rng.randi_range(1, 3), rng.randi_range(1, 3))), Color(0.55, 0.42, 0.25, 0.35))
	var f := T.FONT
	c.draw_string(T.FONT_BOLD, card.position + Vector2(8, 16), "EVIDENCE UBYTOVANYCH  %d" % int(_cur.get("year", 1970)), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(40, 34, 30))
	c.draw_string(f, card.position + Vector2(card.size.x - 52, 16), "c. %04d" % (int(_cur.get("seed", 0)) % 9000 + 1000), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(80, 70, 60))
	var y := card.position.y + 46.0
	for k in FIELDS:
		c.draw_string(f, Vector2(card.position.x + 8, y), str(k).to_upper() + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(90, 80, 70))
		var val := str(_cur.get(k, ""))
		if bool(_cur.get("hand", false)):
			# In ink: each letter a little off its line.
			var x := card.position.x + 96.0
			for ch in val:
				var dy := rng.randf_range(-1.6, 1.6)
				c.draw_string(T.FONT, Vector2(x, y + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(30, 40, 110))
				x += T.FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + rng.randf_range(0.0, 1.2)
		else:
			c.draw_string(T.FONT, Vector2(card.position.x + 96, y), val, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(20, 20, 20))
		y += 26.0
	var note := str(_cur.get("note", ""))
	if note != "":
		c.draw_string(T.FONT_BOLD, Vector2(card.position.x + 96, card.end.y - 8), note, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(150, 20, 20))
	if _stamp_t > 0.0:
		var col := Color8(40, 110, 50) if _stamp.begins_with("FILED") else Color8(170, 30, 30)
		col.a = clampf(_stamp_t, 0.0, 1.0)
		var w := T.FONT_BOLD.get_string_size(_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2).x
		var r := Rect2(card.get_center() - Vector2(w * 0.5 + 8, 16), Vector2(w + 16, 26))
		c.draw_rect(r, col, false, 2.0)
		c.draw_string(T.FONT_BOLD, r.position + Vector2(8, 19), _stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, col)
