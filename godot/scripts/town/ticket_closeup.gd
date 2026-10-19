extends "res://scripts/closeup/closeup_view.gd"

## The ticket machine on the pole by the bus's front door, close up (like the phone in
## the office): an orange tin box with a dot display, two rows of buttons, a coin slot,
## the slot the ticket comes out of and the cup under it.
##
## Press where you are going (the price comes up), click the coin slot to pay, the
## ticket prints and creeps out of its slot in steps; click it to take it. The bottom row
## is a child's half fare, a dog, a bag, and C. Now and then the machine takes the money
## and thinks about it: thump it.
##
## town_trip.gd / bus_ride.gd read `ticket` ({} or {to, kind, price}) when you sit down.

signal ticket_taken(ticket: Dictionary)

const PIC := "res://assets/textury/town/closeup_ticket_machine.png"
const SFX := "res://assets/sfx/bus/"
const DISPLAY := Rect2(102, 33, 108, 30)
const BUTTON0 := Vector2(96, 78)
const BUTTON_STEP := Vector2(24, 24)
const BUTTON_SIZE := Vector2(20, 20)
const COIN := Rect2(199, 80, 18, 34)
const SLOT := Rect2(110, 137, 54, 18)
const CUP := Rect2(101, 161, 59, 29)
const BODY := Rect2(88, 8, 140, 214)
const LCD := Color(1.0, 0.62, 0.16)
const LCD_DIM := Color(0.36, 0.18, 0.06)
## Stops by where the bus stands: [label on the button, the stop, price $].
const FARES := {
	"camp": [["LESNA", "LESNA", 3], ["HLUBOC", "HLUBOCANY", 5], ["DAM", "DAM", 2], ["PODL", "PODLESI", 1]],
	"town": [["KEMP", "KEMP", 3], ["DAM", "DAM", 2], ["HLUBOC", "HLUBOCANY", 2], ["PODL", "PODLESI", 2]],
	# Boarding at Podlesi's request stop, one way or the other.
	"hamlet_town": [["LESNA", "LESNA", 2], ["HLUBOC", "HLUBOCANY", 4]],
	"hamlet_camp": [["KEMP", "KEMP", 2]],
}
const EXTRAS := [["1/2", "half"], ["DOG", "dog"], ["BAG", "bag"], ["C", "cancel"]]

## "camp" or "town": where the bus stands (what the buttons offer).
var stop := "camp"
## What you hold: {} or {to, kind, price}.
var ticket: Dictionary = {}

var _choice: Array = []            # the fare chosen, or []
var _kind := "adult"
var _state := ""                   # "", "paid", "printing", "out", "stuck"
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
	say("", "", false)


func _button_rect(row: int, col: int) -> Rect2:
	return Rect2(BUTTON0 + Vector2(col, row) * BUTTON_STEP, BUTTON_SIZE)


func _hotspots() -> Array:
	var out: Array = []
	for i in 4:
		out.append({"id": "fare:%d" % i, "rect": _button_rect(0, i)})
		out.append({"id": "extra:%d" % i, "rect": _button_rect(1, i)})
	out.append({"id": "coin", "rect": COIN})
	if _state == "out":
		out.append({"id": "ticket", "rect": SLOT.grow(4)})
	out.append({"id": "thump", "rect": BODY})
	return out


func _clicked(id: String) -> void:
	if id.begins_with("fare:"):
		_press()
		var i := int(id.get_slice(":", 1))
		var fares: Array = FARES.get(stop, FARES["camp"])
		if i < fares.size() and _state == "":
			_choice = fares[i]
			_kind = "adult"
		return
	if id.begins_with("extra:"):
		_press()
		if _state != "":
			return
		var what := str(EXTRAS[int(id.get_slice(":", 1))][1])
		match what:
			"cancel":
				_choice = []
				_kind = "adult"
			"half":
				if not _choice.is_empty():
					_kind = "half"
			"dog", "bag":
				_choice = ["DOG" if what == "dog" else "BAG", what.to_upper(), 1]
				_kind = what
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
				say("", "It rattles. Nothing.")


func _press() -> void:
	play(SFX + "button.mp3", -6.0)


func _price() -> int:
	if _choice.is_empty():
		return 0
	var p := int(_choice[2])
	return maxi(1, p / 2) if _kind == "half" else p


func _pay() -> void:
	if _choice.is_empty() or _state != "":
		play(SFX + "coin.mp3", -12.0)
		if _choice.is_empty():
			say("", "The coin rattles down into the cup.")
		return
	var price := _price()
	if CoreRoot.get_money() < price or not CoreRoot.actions.spend_money(price):
		say("", "Not enough in your pockets.")
		return
	play(SFX + "coin.mp3", -4.0)
	_state = "paid"
	# Now and then it keeps the money and thinks about it.
	if _rng.randf() < 0.12:
		_state = "stuck"
		_blink = 0.0
		return
	_start_print()


func _start_print() -> void:
	_state = "printing"
	_print_t = 0.0
	play(SFX + "ticket_print.mp3", -4.0)


func _take() -> void:
	ticket = {"to": str(_choice[1]), "kind": _kind, "price": _price(), "from": stop}
	play("res://assets/sfx/desk/paper_pick.mp3", -8.0)
	var from := {"camp": "KEMP", "town": "LESNA", "hamlet_town": "PODLESI", "hamlet_camp": "PODLESI"}
	say("", "380   %s - %s   $%d%s" % [str(from.get(stop, "LESNA")), str(_choice[1]), _price(), "   (half)" if _kind == "half" else ""])
	ticket_taken.emit(ticket.duplicate())
	_choice = []
	_kind = "adult"
	_state = ""


func _tick(delta: float) -> void:
	_blink += delta
	if _state == "printing":
		_print_t += delta
		if _print_t >= 1.3:
			_state = "out"


func _paint(c: Control) -> void:
	if picture == null:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.2, 0.2, 0.22))
		c.draw_rect(BODY, Color(0.78, 0.36, 0.14))
		c.draw_rect(DISPLAY, Color(0.08, 0.06, 0.05))
		for r in 2:
			for i in 4:
				c.draw_rect(_button_rect(r, i), Color(0.86, 0.8, 0.62))
		c.draw_rect(COIN, Color(0.1, 0.1, 0.1))
		c.draw_rect(SLOT, Color(0.08, 0.08, 0.08))
	var f: Font = RETRO_UI.FONT_TEXT
	# The display: dot letters, the unlit dots showing faintly.
	var line1 := "CHOOSE"
	var line2 := ""
	match _state:
		"":
			if not _choice.is_empty():
				line1 = "%s%s" % [str(_choice[0]), " 1/2" if _kind == "half" else ""]
				line2 = "$%d  COINS" % _price()
		"paid", "printing":
			line1 = "PRINTING"
			line2 = "PLEASE WAIT"
		"out":
			line1 = "TAKE TICKET"
		"stuck":
			line1 = "ERROR 3" if int(_blink * 3.0) % 2 == 0 else ""
			line2 = "CALL DEPOT"
	if _state == "" and _choice.is_empty() and int(_blink * 2.0) % 2 == 1:
		line1 = ""
	c.draw_rect(DISPLAY, Color(0.05, 0.03, 0.02, 0.85))
	for y in range(int(DISPLAY.position.y) + 2, int(DISPLAY.end.y) - 1, 2):
		for x in range(int(DISPLAY.position.x) + 2, int(DISPLAY.end.x) - 1, 2):
			c.draw_rect(Rect2(x, y, 1, 1), LCD_DIM * Color(1, 1, 1, 0.35))
	ink(c, f, DISPLAY.position + Vector2(5, 12), line1, LCD)
	if line2 != "":
		ink(c, f, DISPLAY.position + Vector2(5, 23), line2, LCD)
	# The buttons' labels.
	var fares: Array = FARES.get(stop, FARES["camp"])
	for i in 4:
		var t := str(fares[i][0]) if i < fares.size() else "--"
		_button_label(c, _button_rect(0, i), t)
		_button_label(c, _button_rect(1, i), str(EXTRAS[i][0]))
	if hovered() != "" and hovered() != "thump":
		var r := Rect2()
		for h in _hotspots():
			if str(h["id"]) == hovered():
				r = h["rect"]
		c.draw_rect(r, Color(1.0, 0.92, 0.6, 0.16))
	# The ticket coming out of its slot, a step at a time.
	if _state in ["printing", "out"]:
		var k := 1.0 if _state == "out" else floorf(clampf(_print_t / 1.3, 0.0, 1.0) * 6.0) / 6.0
		var tr := Rect2(SLOT.position + Vector2(8, 6), Vector2(SLOT.size.x - 16, 24.0 * k))
		c.draw_rect(tr, Color(0.92, 0.9, 0.82))
		c.draw_rect(Rect2(tr.position, Vector2(tr.size.x, 1)), Color(0.7, 0.68, 0.6))
		if k > 0.5:
			ink(c, f, tr.position + Vector2(3, 8), "380", Color(0.2, 0.2, 0.5))
			ink(c, f, tr.position + Vector2(3, 15), str(_choice[0]) if not _choice.is_empty() else "", Color(0.2, 0.2, 0.5))


func _button_label(c: Control, r: Rect2, t: String) -> void:
	var f: Font = RETRO_UI.FONT_TEXT
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var size := 8
	if w > r.size.x - 2.0:
		t = t.substr(0, 4)
		w = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ink(c, f, Vector2(r.position.x + floorf((r.size.x - w) * 0.5), r.position.y + 13.0), t, Color(0.2, 0.16, 0.1))
