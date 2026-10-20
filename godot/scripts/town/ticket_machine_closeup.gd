extends "res://scripts/closeup/closeup_view.gd"

## The yellow ticket machine on the stop's pole, close up (ticket_machine.gd in the
## world): its black panel with the grey LCD, six fares on white labels with a button
## each side, the coin slot, the slot the ticket comes out of
## (closeup_stop_machine.png: Grok's face_ticket_machine on the stop).
##
## Press a fare (either button by its label), the LCD says what it costs; click the coin
## slot to pay; the ticket prints and creeps out of its slot in steps; click it to take
## it (into the bag, to be punched on the bus). Now and then it keeps the money and
## thinks about it: thump it. The LCD speaks Czech; the strip under says it in English.

signal ticket_taken(to: String)

const PIC := "res://assets/textury/town/closeup_stop_machine.png"
const SFX := "res://assets/sfx/bus/"
const INVENTORY = preload("res://scripts/ui/inventory.gd")
const LCD := Rect2(117, 13, 86, 24)
const LEFT_X := 112.0
const RIGHT_X := 191.0
const LABEL_X := 147.0
const ROW0 := 48.0
const ROW_STEP := 15.0
const BUTTON := Vector2(16, 12)
const LABEL := Vector2(26, 11)
const COIN := Rect2(106, 147, 39, 44)
const SLOT := Rect2(129, 207, 63, 9)
const BODY := Rect2(66, 0, 188, 240)
const INK_LCD := Color(0.1, 0.13, 0.09)
const PANEL := Color(0.12, 0.13, 0.15)
## The rows by the stop: [label, the destination (as on the ticket), price $, English].
const FARES := {
	"camp": [["LIBL.", "LIBLICE", 2, "Liblice"], ["LSTIB.", "LSTIBOR", 3, "Lstibor"], ["PŘIST.", "PRISTOUPIM", 1, "Pristoupim"]],
	"town": [["KEMP", "KEMP", 2, "the camp"], ["PŘIST.", "PRISTOUPIM", 1, "Pristoupim"], ["LSTIB.", "LSTIBOR", 1, "Lstibor"]],
}
const EXTRAS := [["1/2", "half"], ["PES", "dog"], ["STORNO", "cancel"]]

## "camp" or "town": whose machine (what the labels offer).
var stop := "camp"

var _choice: Array = []            # the fare chosen, or []
var _half := false
var _state := ""                   # "", "printing", "out", "stuck"
var _print_t := 0.0
var _blink := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_rng.randomize()


func _opened() -> void:
	if _state == "printing":
		_state = "out"
	say("", "The 380's ticket machine. Pick a fare, then coins in the slot.", false)


func _rows() -> Array:
	var out: Array = (FARES.get(stop, FARES["camp"]) as Array).duplicate()
	for e in EXTRAS:
		out.append([e[0], e[1], 0, ""])
	return out


func _row_y(i: int) -> float:
	return ROW0 + ROW_STEP * float(i)


func _hotspots() -> Array:
	var out: Array = []
	for i in 6:
		out.append({"id": "row:%d" % i, "rect": Rect2(Vector2(LEFT_X, _row_y(i)), BUTTON)})
		out.append({"id": "row:%d" % i, "rect": Rect2(Vector2(RIGHT_X, _row_y(i)), BUTTON)})
	out.append({"id": "coin", "rect": COIN})
	if _state == "out":
		out.append({"id": "ticket", "rect": Rect2(SLOT.position + Vector2(12, 4), Vector2(SLOT.size.x - 24, 240.0 - SLOT.position.y))})
	out.append({"id": "thump", "rect": BODY})
	return out


func _clicked(id: String) -> void:
	if id.begins_with("row:"):
		play(SFX + "button.mp3", -6.0)
		if _state != "":
			return
		var row: Array = _rows()[int(id.get_slice(":", 1))]
		match str(row[1]):
			"cancel":
				_choice = []
				_half = false
				say("", "Storno: cancelled.", false)
			"half":
				if not _choice.is_empty():
					_half = true
					say("", "%s, half fare: $%d." % [_choice[3], _price()], false)
			"dog":
				_choice = ["PES", "DOG", 1, "a dog"]
				_half = false
				say("", "A ticket for a dog: $1. You have not got a dog.", false)
			_:
				_choice = row
				_half = false
				say("", "%s: $%d. Coins in the slot." % [row[3], _price()], false)
		return
	match id:
		"coin":
			_pay()
		"ticket":
			_take()
		"thump":
			play(SFX + "thump.mp3", -4.0)
			if _state == "stuck" and _rng.randf() < 0.55:
				_start_print()
			elif _state == "stuck":
				say("", "It rattles. PORUCHA: out of order. Hit it again.", false)


func _price() -> int:
	if _choice.is_empty():
		return 0
	var p := int(_choice[2])
	return maxi(1, p / 2) if _half else p


func _pay() -> void:
	if _choice.is_empty() or _state != "":
		play(SFX + "coin.mp3", -12.0)
		if _choice.is_empty():
			say("", "The coin rattles straight down into the return cup. Pick a fare first.", false)
		return
	var bag = INVENTORY.find(get_tree())
	if bag != null and not bag.room_for("ticket"):
		say("", "No room in your bag for a ticket.", false)
		return
	var price := _price()
	if CoreRoot.get_money() < price or not CoreRoot.actions.spend_money(price):
		say("", "Not enough in your pockets.", false)
		return
	play(SFX + "coin.mp3", -4.0)
	# Now and then it keeps the money and thinks about it.
	if _rng.randf() < 0.1:
		_state = "stuck"
		_blink = 0.0
		say("", "It takes the coins. Then nothing. The LCD says PORUCHA.", false)
		return
	_start_print()


func _start_print() -> void:
	_state = "printing"
	_print_t = 0.0
	play(SFX + "ticket_print.mp3", -4.0)
	say("", "It whirrs and clicks. TISKNU: printing.", false)


func _take() -> void:
	var bag = INVENTORY.find(get_tree())
	if bag != null and not bag.add_item("ticket"):
		say("", "No room in your bag for it.", false)
		return
	play("res://assets/sfx/desk/paper_pick.mp3", -8.0)
	say("", "A ticket to %s, $%d. Punch it in the orange box on the bus." % [_choice[3], _price()], false)
	ticket_taken.emit(str(_choice[1]))
	_choice = []
	_half = false
	_state = ""


func _tick(delta: float) -> void:
	_blink += delta
	if _state == "printing":
		_print_t += delta
		if _print_t >= 1.4:
			_state = "out"
			say("", "VEZMĚTE SI JÍZDENKU: take your ticket.", false)


func _paint(c: Control) -> void:
	if picture == null:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.18, 0.2, 0.18))
		c.draw_rect(BODY, Color(0.82, 0.62, 0.16))
		c.draw_rect(BODY.grow(-24), PANEL)
		c.draw_rect(LCD, Color(0.5, 0.54, 0.46))
	var f: Font = RETRO_UI.FONT_TEXT
	# The slot: empty unless a ticket is in it (the picture has one sticking out).
	c.draw_rect(Rect2(SLOT.position.x + 12, SLOT.end.y, SLOT.size.x - 24, 240.0 - SLOT.end.y), PANEL)
	c.draw_rect(Rect2(SLOT.position + Vector2(4, 3), Vector2(SLOT.size.x - 8, 3)), Color(0.02, 0.02, 0.02))
	# The labels: the fares.
	var rows := _rows()
	for i in 6:
		var t := str(rows[i][0])
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		ink(c, f, Vector2(LABEL_X + floorf((LABEL.x - tw) * 0.5), _row_y(i) + 9.0), t, Color(0.16, 0.12, 0.1))
		if not _choice.is_empty() and str(rows[i][1]) == str(_choice[1]):
			c.draw_rect(Rect2(Vector2(LABEL_X - 1, _row_y(i) - 1), LABEL + Vector2(2, 2)), Color(0.8, 0.12, 0.08), false, 1.0)
	# The LCD: black segments on grey-green, the unlit ones faintly there.
	var line1 := "ZVOLTE JÍZDNÉ"
	var line2 := ""
	match _state:
		"":
			if not _choice.is_empty():
				line1 = "%s%s" % [str(_choice[0]), "  1/2" if _half else ""]
				line2 = "$%d  MINCE" % _price()
			elif int(_blink * 2.0) % 2 == 1:
				line1 = ""
		"printing":
			line1 = "TISKNU"
			line2 = "ČEKEJTE"
		"out":
			line1 = "VEZMĚTE SI"
			line2 = "JÍZDENKU"
		"stuck":
			line1 = "PORUCHA 3" if int(_blink * 3.0) % 2 == 0 else ""
			line2 = "VOLEJTE DEPO"
	ink(c, f, LCD.position + Vector2(5, 10), "8888888888888", Color(INK_LCD, 0.07))
	ink(c, f, LCD.position + Vector2(5, 20), "8888888888888", Color(INK_LCD, 0.07))
	ink(c, f, LCD.position + Vector2(5, 10), line1, INK_LCD)
	if line2 != "":
		ink(c, f, LCD.position + Vector2(5, 20), line2, INK_LCD)
	if hovered() != "" and hovered() != "thump":
		for h in _hotspots():
			if str(h["id"]) == hovered():
				c.draw_rect(h["rect"], Color(1.0, 0.92, 0.6, 0.18))
	# The ticket creeping out of its slot, a step at a time.
	if _state in ["printing", "out"]:
		var k := 1.0 if _state == "out" else floorf(clampf(_print_t / 1.4, 0.0, 1.0) * 7.0) / 7.0
		var tr := Rect2(SLOT.position + Vector2(13, 5), Vector2(SLOT.size.x - 26, (240.0 - SLOT.position.y - 5.0) * k))
		c.draw_rect(tr, Color(0.93, 0.91, 0.84))
		c.draw_rect(Rect2(tr.position, Vector2(tr.size.x, 1)), Color(0.7, 0.68, 0.6))
		c.draw_rect(Rect2(tr.position + Vector2(0, tr.size.y - 1), Vector2(tr.size.x, 1)), Color(0.78, 0.76, 0.68))
		if tr.size.y > 12.0:
			ink(c, f, tr.position + Vector2(3, 9), "ČSAD 380", Color(0.2, 0.2, 0.5))
		if tr.size.y > 20.0 and not _choice.is_empty():
			ink(c, f, tr.position + Vector2(3, 17), str(_choice[0]), Color(0.2, 0.2, 0.5))
