extends "res://scripts/closeup/closeup_view.gd"

## The side job at the Benzina in Lesna, close up: the pump's face (Grok picture) with its
## rolling counter, three nozzles and the car at the side. The driver says what they
## want: a fuel and an amount (dollars, litres, or full). Take the right nozzle (green
## Natural, yellow Special, black diesel), hold the left button to pump (it starts slow,
## then runs), let go to stop; the drums roll in steps. Hang the nozzle back up when you
## are done and they pay: Lojza's two dollars a car, and a tip if you stopped right on it.
## Over, and they will not pay for the extra; the wrong fuel, and Lojza takes ten off you.
##
## pump_job.gd opens it with an order and hears `served` with what came of it.

signal served(result: Dictionary)

const PIC := "res://assets/textury/town/closeup_pump.png"
const HAND := "res://assets/textury/hands/nozzle.png"
const SFX := "res://assets/sfx/town/"
const SFX_COINS := "res://assets/sfx/pub/coins_bar.mp3"
const DRUMS := Rect2(90, 33, 110, 41)
const ROW_Y := [33.0, 57.0]
const DRUM_H := 17.0
const NOZZLES := {"natural": Rect2(95, 98, 22, 40), "special": Rect2(128, 98, 26, 40), "diesel": Rect2(163, 98, 26, 40)}
const CAP := Vector2(262, 100)
const PRICE := {"natural": 0.8, "special": 0.75, "diesel": 0.7}
const NAMES := {"natural": "Natural", "special": "Special", "diesel": "diesel"}
## Litres a second at full flow, and how long it takes to get there.
const FLOW := 2.2
const RAMP := 0.7

var order: Dictionary = {}       # {fuel, kind: "money"|"litres"|"full", amount, tank, who}
var _held := ""                  # the nozzle in hand, or ""
var _litres := 0.0
var _pumping := false
var _pump_t := 0.0
var _hand: Texture2D
var _loop: AudioStreamPlayer
var _full := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_hand = load(HAND) if ResourceLoader.exists(HAND) else null
	_loop = AudioStreamPlayer.new()
	_loop.volume_db = -8.0
	add_child(_loop)
	_rng.randomize()


func start(o: Dictionary) -> void:
	order = o
	_held = ""
	_litres = 0.0
	_pumping = false
	_full = false
	open_view()
	say(str(o.get("who", "Driver")), _order_text())


func _order_text() -> String:
	var fuel := str(NAMES[order["fuel"]])
	match str(order["kind"]):
		"money":
			return "%s. %d dollars' worth, please." % [fuel.capitalize(), int(order["amount"])]
		"litres":
			return "%s, %d litres. Not a drop more, I measure it at home." % [fuel.capitalize(), int(order["amount"])]
	return "Fill her up. %s." % fuel.capitalize()


func _hotspots() -> Array:
	var out: Array = []
	if _held == "":
		for k in NOZZLES.keys():
			out.append({"id": "take:" + str(k), "rect": NOZZLES[k]})
	else:
		out.append({"id": "hang", "rect": NOZZLES[_held].grow(4)})
		out.append({"id": "car", "rect": Rect2(214, 20, 106, 170)})
	return out


func _clicked(id: String) -> void:
	if id.begins_with("take:"):
		_held = id.trim_prefix("take:")
		play(SFX + "nozzle_out.mp3", -6.0)
		return
	if id == "hang":
		_finish()


func _tick(delta: float) -> void:
	# Hold the button over the car (or anywhere but the holsters) to pump.
	var want := _held != "" and not _full and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _mouse.x >= 0.0 and hovered() != "hang"
	if want and not _pumping:
		_pumping = true
		_pump_t = 0.0
		var st = load(SFX + "pump_run.mp3")
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_loop.stream = st
		_loop.play()
	elif not want and _pumping:
		_pumping = false
		_loop.stop()
		play(SFX + "pump_click.mp3", -6.0)
	if _pumping:
		_pump_t += delta
		var flow := FLOW * clampf(_pump_t / RAMP, 0.08, 1.0)
		_litres += flow * delta
		# A full tank clicks the nozzle off by itself.
		if _litres >= float(order.get("tank", 40.0)):
			_litres = float(order.get("tank", 40.0))
			_full = true
			_pumping = false
			_loop.stop()
			play(SFX + "pump_click.mp3", -2.0)


func _money() -> float:
	return _litres * float(PRICE.get(_held if _held != "" else str(order.get("fuel", "natural")), 0.8))


func _finish() -> void:
	play(SFX + "pump_click.mp3", -8.0)
	_loop.stop()
	_pumping = false
	var result := {"fee": 0, "tip": 0, "fine": 0, "line": ""}
	if _litres < 0.05:
		_held = ""
		return
	if _held != str(order["fuel"]):
		result["fine"] = 10
		result["line"] = "%s? In my car? You wait till Lojza hears about this." % str(NAMES[_held]).capitalize()
	else:
		var want := 0.0
		var got := 0.0
		match str(order["kind"]):
			"money":
				want = float(order["amount"])
				got = _money()
			"litres":
				want = float(order["amount"])
				got = _litres
			_:
				want = float(order.get("tank", 40.0))
				got = _litres
		var off := got - want
		var tol := 0.05 if str(order["kind"]) != "full" else 0.01
		result["fee"] = 2
		if absf(off) <= tol or (str(order["kind"]) == "full" and _full):
			result["tip"] = 3 + _rng.randi_range(0, 2)
			result["line"] = "Right on it. Here, for you." if str(order["kind"]) != "full" else "Full to the neck. Good lad."
		elif off < 0.0 and off > -0.6:
			result["tip"] = 1
			result["line"] = "Near enough."
		elif off < 0.0:
			result["line"] = "That's not what I asked for. Here, take it, I'm late."
		else:
			result["fee"] = 1
			result["line"] = "I said %s. I'm not paying for your extra." % (("%d dollars" % int(order["amount"])) if str(order["kind"]) == "money" else ("%d litres" % int(order["amount"])))
	_held = ""
	if int(result["fee"]) + int(result["tip"]) > 0:
		play(SFX_COINS, -4.0)
	say(str(order.get("who", "Driver")), str(result["line"]))
	served.emit(result)
	order = {}
	get_tree().create_timer(1.6).timeout.connect(func():
		if visible and order.is_empty():
			close_view()
	)


func _closing() -> void:
	_loop.stop()
	_pumping = false


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if picture == null:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.3, 0.3, 0.32))
		c.draw_rect(Rect2(80, 10, 140, 210), Color(0.75, 0.2, 0.15))
		c.draw_rect(DRUMS, Color(0.9, 0.9, 0.86))
	# The counter: litres on top, dollars below, each drum rolling to the next digit.
	var money := _money()
	_drums(c, ROW_Y[0], _litres * 10.0, 1)
	_drums(c, ROW_Y[1], money * 100.0, 2)
	# The nozzles: the one in your hand is gone from its holster.
	if _held != "":
		var r: Rect2 = NOZZLES[_held]
		c.draw_rect(Rect2(r.position + Vector2(4, 2), Vector2(r.size.x - 8, 22)), Color(0.12, 0.12, 0.12))
		if _hand != null:
			var k := 0.55
			var size := Vector2(_hand.get_width(), _hand.get_height()) * k
			var shake := Vector2(0, 1 if _pumping and int(floorf(_pump_t * 12.0)) % 2 == 0 else 0)
			c.draw_texture_rect(_hand, Rect2((CAP + Vector2(-8, -18) + shake).floor(), size), false)
	if hovered() != "":
		for h in _hotspots():
			if str(h["id"]) == hovered() and str(h["id"]) != "car":
				c.draw_rect(h["rect"], Color(1.0, 0.92, 0.6, 0.18))


## Six drums across the window; `value` in the last digit's units, `decimals` after the
## point (a painted dot). The last drum rolls smoothly in steps, the others turn over
## when the one to their right passes 9.
func _drums(c: Control, y: float, value: float, decimals: int) -> void:
	var f: Font = RETRO_UI.FONT_BIG
	var w := DRUMS.size.x / 6.0
	var v := maxf(0.0, value)
	# Each drum's digit; the last one turns all the time (in quarter steps), a drum only
	# turns over while the one to its right is going from 9 to 0.
	var digits: Array = []
	var fracs: Array = []
	for i in 6:
		digits.append(int(floorf(fmod(v / pow(10.0, 5 - i), 10.0))))
		fracs.append(0.0)
	fracs[5] = floorf((fmod(v, 1.0)) * 4.0) / 4.0
	for i in range(4, -1, -1):
		fracs[i] = fracs[i + 1] if int(digits[i + 1]) == 9 else 0.0
	for i in 6:
		var digit: int = digits[i]
		var frac: float = fracs[i]
		var x := DRUMS.position.x + float(i) * w
		var cell := Rect2(x + 1, y, w - 2, DRUM_H)
		c.draw_rect(cell, Color(0.93, 0.92, 0.86))
		var dy := frac * DRUM_H
		ink(c, f, Vector2(x + w * 0.5 - 3.0, y + DRUM_H - 3.0 - dy), str(digit), Color(0.1, 0.1, 0.12), Color(0, 0, 0, 0), 10)
		if frac > 0.0:
			ink(c, f, Vector2(x + w * 0.5 - 3.0, y + DRUM_H * 2.0 - 3.0 - dy), str((digit + 1) % 10), Color(0.1, 0.1, 0.12), Color(0, 0, 0, 0), 10)
		# Clip the roll to the drum: cover what spills over below.
		c.draw_rect(Rect2(x, y + DRUM_H, w, 7), Color(0.55, 0.56, 0.55))
		c.draw_rect(Rect2(x, y - 6, w, 6), Color(0.55, 0.56, 0.55))
		c.draw_rect(Rect2(cell.position.x, cell.position.y, cell.size.x, 2), Color(0, 0, 0, 0.25))
		if i == 5 - decimals:
			c.draw_rect(Rect2(x + w - 2, y + DRUM_H - 4, 2, 2), Color(0.1, 0.1, 0.12))
