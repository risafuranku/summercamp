extends "res://scripts/closeup/closeup_view.gd"

## The orange punch box (označovač) on the pole by the bus's door, close up
## (closeup_validator.png: Grok's face_validator on the blurred bus): your ticket in your
## hand at the bottom; click it and it goes up into the slot in steps, the box goes cvak,
## the lamp lights and the arrow turns to a tick, and it comes back out with the holes
## punched through it and the time printed along it. bus_ride.gd counts it punched
## (`punched`) at the cvak; click it again (or close) to put it away.

signal punched

const PIC := "res://assets/textury/town/closeup_validator.png"
const SFX := "res://assets/sfx/bus/"
const SLOT := Rect2(97, 72, 36, 8)
const ARROW := Rect2(87, 135, 56, 33)
const LAMP := Rect2(100, 13, 28, 20)
## The ticket in your hand, and how big it is there.
const HAND := Vector2(206, 168)
const TICKET := Vector2(78, 40)

## The time to print on it ("13:52").
var stamp := ""

var _state := ""                   # "" in hand, "in", "cvak", "out", "done"
var _t := 0.0


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


func _opened() -> void:
	_state = ""
	_t = 0.0
	say("", "The orange box. Your ticket in your hand: put it in the slot.", false)


func _hotspots() -> Array:
	var out: Array = []
	if _state in ["", "done"]:
		out.append({"id": "ticket", "rect": Rect2(HAND, TICKET)})
	if _state == "":
		out.append({"id": "slot", "rect": SLOT.grow(10)})
	return out


func _clicked(id: String) -> void:
	if _state == "done":
		close_view()
		return
	if _state == "" and (id == "ticket" or id == "slot"):
		_state = "in"
		_t = 0.0
		play("res://assets/sfx/desk/paper_pick.mp3", -10.0)


func _tick(delta: float) -> void:
	_t += delta
	match _state:
		"in":
			if _t >= 0.5:
				_state = "cvak"
				_t = 0.0
				if ResourceLoader.exists(SFX + "ticket_punch.mp3"):
					play(SFX + "ticket_punch.mp3", -2.0)
				elif ResourceLoader.exists(SFX + "ticket_punch.wav"):
					# tools/audiogen/synth_sfx.py's cvak.
					play(SFX + "ticket_punch.wav", -1.0)
				else:
					play(SFX + "button.mp3", 0.0)
				say("", "Cvak.", false)
				punched.emit()
		"cvak":
			if _t >= 0.55:
				_state = "out"
				_t = 0.0
		"out":
			if _t >= 0.5:
				_state = "done"
				say("", "Punched: the holes through it, %s printed along the edge. Click it to put it away." % stamp, false)


## Where the ticket is: in the hand, going up into the slot, in it, coming back.
func _ticket_rect() -> Rect2:
	var in_slot := Rect2(SLOT.position + Vector2(2, -TICKET.y * 0.5 + 4.0), Vector2(SLOT.size.x - 4.0, TICKET.y * 0.5))
	var hand := Rect2(HAND, TICKET)
	match _state:
		"in":
			var k := floorf(clampf(_t / 0.5, 0.0, 1.0) * 5.0) / 5.0
			return Rect2(hand.position.lerp(in_slot.position, k), hand.size.lerp(in_slot.size, k))
		"cvak":
			return in_slot
		"out":
			var k := floorf(clampf(_t / 0.5, 0.0, 1.0) * 5.0) / 5.0
			return Rect2(in_slot.position.lerp(hand.position, k), in_slot.size.lerp(hand.size, k))
	return hand


func _paint(c: Control) -> void:
	if picture == null:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.14, 0.12, 0.1))
		c.draw_rect(Rect2(70, 33, 90, 197), Color(0.86, 0.44, 0.1))
		c.draw_rect(SLOT, Color(0.05, 0.05, 0.05))
		c.draw_rect(ARROW, Color(0.05, 0.08, 0.05))
	var f: Font = RETRO_UI.FONT_TEXT
	# The lamp and the window: lit for the cvak, a tick instead of the arrow after.
	if _state in ["cvak", "out"]:
		c.draw_rect(LAMP.grow(-4), Color(1.0, 0.86, 0.4, 0.55))
	if _state in ["cvak", "out", "done"]:
		c.draw_rect(ARROW.grow(-4), Color(0.03, 0.05, 0.03))
		var mid := ARROW.get_center()
		var tick := PackedVector2Array([mid + Vector2(-9, 0), mid + Vector2(-3, 6), mid + Vector2(10, -8)])
		c.draw_polyline(tick, Color(0.4, 1.0, 0.3), 3.0)
	var r := _ticket_rect()
	if _state == "cvak":
		# In the slot: only its end shows.
		r = Rect2(r.position, Vector2(r.size.x, maxf(2.0, r.size.y - 12.0)))
	c.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.35))
	c.draw_rect(r, Color(0.92, 0.9, 0.82))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.36, 0.5, 0.74))
	if r.size.x > 40.0:
		var ink_c := Color(0.2, 0.2, 0.5)
		ink(c, f, r.position + Vector2(4, 11), "ČSAD  380", ink_c)
		ink(c, f, r.position + Vector2(4, 19), "JÍZDENKA", ink_c)
		ink(c, f, r.position + Vector2(4, 27), "NEPŘESTUPNÍ", ink_c)
		if _state == "done":
			# The punch's holes and the time printed along the edge.
			for h in [Vector2(54, 6), Vector2(62, 6), Vector2(70, 6), Vector2(58, 13), Vector2(66, 13), Vector2(62, 20)]:
				c.draw_rect(Rect2(r.position + h, Vector2(3, 3)), Color(0.08, 0.06, 0.05))
			ink(c, f, r.position + Vector2(4, 36), "%s  380/07" % stamp, Color(0.62, 0.12, 0.1))
	if hovered() != "":
		for h in _hotspots():
			if str(h["id"]) == hovered():
				c.draw_rect(h["rect"], Color(1.0, 0.92, 0.6, 0.14))
