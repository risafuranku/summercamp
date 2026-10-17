extends "res://scripts/closeup/closeup_view.gd"

## The Jednota in Lesna, across the counter (Grok picture; Mrs Novotna drawn in behind it,
## the electrician's wife): click what you want and it goes on the counter and the money
## in the till. Start cigarettes off the top shelf (a pack of 20), Lesnak 10 out of the
## crate (a bottle), a scratch card from the box by the till (RYCHLA KACKA: scratch the
## six fields with the mouse held down, three alike win), and batteries, which are sold
## out until further notice. Click her to talk. Open 7:00-17:00.
##
## What you buy goes into the pockets (scripts/town/pockets.gd) via `bought`.

signal bought(item: String)

const PIC := "res://assets/textury/town/closeup_shop.png"
const HER := "res://assets/textury/npc/town_shopgirl.png"
const SFX_TILL := "res://assets/sfx/bistro/till.mp3"
const SFX_SCRATCH := "res://assets/sfx/town/scratch.mp3"
const SFX_BELL := "res://assets/sfx/town/shop_bell.mp3"
const ITEMS := {
	"cigs": {"rect": Rect2(52, 28, 168, 26), "price": 2, "say": "Start. Twenty. Two dollars."},
	"beer": {"rect": Rect2(2, 128, 62, 42), "price": 1, "say": "Lesnak. Bring the bottle back next time."},
	"card": {"rect": Rect2(136, 156, 34, 18), "price": 1, "say": "Rychla kacka. Scratch it here, not on my counter."},
	"batteries": {"rect": Rect2(262, 74, 56, 56), "price": 0, "say": "Batteries are sold out until further notice. Please stop asking."},
}
const HER_RECT := Rect2(132, 44, 54, 120)
const COUNTER_Y := 163.0
const HER_LINES := [
	"What will it be.",
	"My husband does your lamps up there. He says your main is older than he is.",
	"Your Vera bought candles. Boxes of them, that last summer. And chalk.",
	"Bread comes Tuesdays and Fridays. Same as the van to your gate.",
	"We shut at five. After five I do not open for anybody.",
]
## Scratch card: symbols and what three of them pay.
const SYMBOLS := ["duck", "seven", "bell", "cherry", "clover", "acorn"]
const PRIZE := {"duck": 50, "seven": 20, "bell": 5, "cherry": 2, "clover": 1, "acorn": 0}
const CARD := Rect2(90, 40, 140, 112)
const FIELD := Vector2(36, 30)

var _her: Texture2D
var _line := 0
var _rng := RandomNumberGenerator.new()
## The card on the counter, or {}: {symbols: [6], scratched: [6 x PackedByteArray], paid}.
var _card: Dictionary = {}
var _scratch_snd_t := 0.0
var _last_scratch := Vector2(-1, -1)


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_her = load(HER) if ResourceLoader.exists(HER) else null
	_rng.randomize()


func _opened() -> void:
	play(SFX_BELL, -8.0)
	_card = {}
	say("Mrs Novotna", "What will it be.")


func _hotspots() -> Array:
	if not _card.is_empty():
		return [{"id": "card_done", "rect": Rect2(CARD.end.x - 18, CARD.position.y + 2, 16, 12)}]
	var out: Array = []
	for id in ITEMS.keys():
		out.append({"id": id, "rect": ITEMS[id]["rect"]})
	out.append({"id": "her", "rect": HER_RECT})
	return out


func _clicked(id: String) -> void:
	if id == "card_done":
		_card = {}
		return
	if id == "her":
		_line += 1
		say("Mrs Novotna", HER_LINES[_line % HER_LINES.size()])
		return
	var item: Dictionary = ITEMS[id]
	var price := int(item["price"])
	if price <= 0:
		say("Mrs Novotna", str(item["say"]))
		return
	if CoreRoot.get_money() < price or not CoreRoot.actions.spend_money(price):
		say("Mrs Novotna", "That's %d dollars. You have not got %d dollars." % [price, price])
		return
	play(SFX_TILL, -6.0)
	say("Mrs Novotna", str(item["say"]))
	if id == "card":
		_new_card()
	else:
		bought.emit(id)


# ── the scratch card ─────────────────────────────────────────────────────────

func _new_card() -> void:
	# Mostly nothing; now and then three alike.
	var syms: Array = []
	var roll := _rng.randf()
	var win := ""
	if roll < 0.01:
		win = "duck"
	elif roll < 0.05:
		win = "seven"
	elif roll < 0.13:
		win = "bell"
	elif roll < 0.22:
		win = "cherry"
	elif roll < 0.32:
		win = "clover"
	if win != "":
		var others: Array = SYMBOLS.filter(func(x): return x != win)
		others.shuffle()
		syms = [win, win, win, others[0], others[1], others[2]]
	else:
		# Each symbol at most twice: no three alike.
		var pool: Array = SYMBOLS + SYMBOLS
		pool.shuffle()
		syms = pool.slice(0, 6)
	syms.shuffle()
	var scratched: Array = []
	for i in 6:
		var mask := PackedByteArray()
		mask.resize(int(FIELD.x * FIELD.y))
		scratched.append(mask)
	_card = {"symbols": syms, "scratched": scratched, "paid": false}


func _field_rect(i: int) -> Rect2:
	var col := i % 3
	var row := i / 3
	return Rect2(CARD.position + Vector2(8 + col * (FIELD.x + 8), 34 + row * (FIELD.y + 8)), FIELD)


func _tick(delta: float) -> void:
	_scratch_snd_t -= delta
	if _card.is_empty() or _mouse.x < 0.0:
		_last_scratch = Vector2(-1, -1)
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_last_scratch = Vector2(-1, -1)
		return
	# Scratch along the way the mouse went since the last frame.
	var from := _last_scratch if _last_scratch.x >= 0.0 else _mouse
	var steps := int(maxf(1.0, from.distance_to(_mouse) / 2.0))
	var any := false
	for k in steps + 1:
		var p := from.lerp(_mouse, float(k) / float(steps))
		for i in 6:
			var r := _field_rect(i)
			if not r.grow(2).has_point(p):
				continue
			var local := p - r.position
			var mask: PackedByteArray = _card["scratched"][i]
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if dx * dx + dy * dy > 10:
						continue
					var x := int(local.x) + dx
					var y := int(local.y) + dy
					if x >= 0 and y >= 0 and x < int(FIELD.x) and y < int(FIELD.y):
						if mask[y * int(FIELD.x) + x] == 0:
							mask[y * int(FIELD.x) + x] = 1
							any = true
	_last_scratch = _mouse
	if any and _scratch_snd_t <= 0.0:
		_scratch_snd_t = 0.5
		play(SFX_SCRATCH, -10.0)
	if any:
		_check_card()


func _revealed(i: int) -> bool:
	var mask: PackedByteArray = _card["scratched"][i]
	var n := 0
	for v in mask:
		n += v
	return float(n) / float(mask.size()) > 0.55


func _check_card() -> void:
	if bool(_card["paid"]):
		return
	for i in 6:
		if not _revealed(i):
			return
	_card["paid"] = true
	var syms: Array = _card["symbols"]
	for s in SYMBOLS:
		if syms.count(s) >= 3 and int(PRIZE[s]) > 0:
			CoreRoot.actions.add_money(int(PRIZE[s]))
			play(SFX_TILL, -4.0)
			say("Mrs Novotna", "Three %s. Well. %d dollars. Do not tell anybody where you bought it." % [_sym_name(s), int(PRIZE[s])])
			return
	say("Mrs Novotna", "Nothing. Nobody wins. My husband says they print them that way.")


func _sym_name(s: String) -> String:
	return {"duck": "ducks", "seven": "sevens", "bell": "bells", "cherry": "cherries", "clover": "clovers", "acorn": "acorns"}.get(s, s)


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if picture == null:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.3, 0.26, 0.2))
		c.draw_rect(Rect2(0, COUNTER_Y, W, PIC_H - COUNTER_Y), Color(0.24, 0.16, 0.1))
	# Mrs Novotna behind the counter, from the waist up.
	if _her != null:
		var k := 1.0
		var size := Vector2(_her.get_width(), _her.get_height()) * k
		var pos := Vector2(HER_RECT.get_center().x - size.x * 0.5, COUNTER_Y + 12.0 - size.y)
		var vis := COUNTER_Y - pos.y
		c.draw_texture_rect_region(_her, Rect2(pos.floor(), Vector2(size.x, vis)), Rect2(0, 0, _her.get_width(), vis / k))
		# Redraw the counter's edge over her.
		if picture != null:
			c.draw_texture_rect_region(picture, Rect2(110, COUNTER_Y - 2, 100, 10), Rect2(110, COUNTER_Y - 2, 100, 10))
	# The box of scratch cards by the till.
	var box: Rect2 = ITEMS["card"]["rect"]
	c.draw_rect(box, Color(0.62, 0.46, 0.22))
	c.draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, 6)), Color(0.95, 0.82, 0.2))
	c.draw_rect(Rect2(box.position + Vector2(4, 3), Vector2(8, 4)), Color(0.85, 0.2, 0.15))
	if hovered() != "" and hovered() != "card_done":
		var r := Rect2()
		for h in _hotspots():
			if str(h["id"]) == hovered():
				r = h["rect"]
		c.draw_rect(r, Color(1.0, 0.92, 0.6, 0.14))
	if not _card.is_empty():
		_paint_card(c)


func _paint_card(c: Control) -> void:
	var f: Font = RETRO_UI.FONT_LABEL
	c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0, 0, 0, 0.45))
	c.draw_rect(Rect2(CARD.position + Vector2(3, 4), CARD.size), Color(0, 0, 0, 0.5))
	c.draw_rect(CARD, Color(0.98, 0.84, 0.18))
	c.draw_rect(CARD.grow(-3), Color(0.9, 0.24, 0.16), false, 1.0)
	ink(c, RETRO_UI.FONT_BIG, CARD.position + Vector2(10, 18), "RYCHLA KACKA", Color(0.7, 0.1, 0.08), Color(0, 0, 0, 0), 10)
	ink(c, RETRO_UI.FONT_TEXT, CARD.position + Vector2(10, 28), "3 alike win.   $1", Color(0.3, 0.12, 0.05))
	c.draw_rect(Rect2(CARD.end.x - 18, CARD.position.y + 2, 16, 12), Color(0.3, 0.12, 0.05))
	ink(c, f, Vector2(CARD.end.x - 14, CARD.position.y + 11), "X", Color(0.98, 0.84, 0.18))
	var syms: Array = _card["symbols"]
	for i in 6:
		var r := _field_rect(i)
		c.draw_rect(r, Color(0.98, 0.96, 0.9))
		_draw_symbol(c, r, str(syms[i]))
		# The silver coating, minus what has been scratched off (in 2x2 blocks).
		var mask: PackedByteArray = _card["scratched"][i]
		for y in range(0, int(FIELD.y), 2):
			for x in range(0, int(FIELD.x), 2):
				if mask[y * int(FIELD.x) + x] == 0:
					var shade := 0.66 + 0.08 * float(((x + y) / 2) % 2)
					c.draw_rect(Rect2(r.position + Vector2(x, y), Vector2(2, 2)), Color(shade, shade, shade + 0.03))


func _draw_symbol(c: Control, r: Rect2, s: String) -> void:
	var m := r.get_center()
	match s:
		"duck":
			c.draw_rect(Rect2(m + Vector2(-9, -2), Vector2(14, 8)), Color(0.95, 0.8, 0.1))
			c.draw_rect(Rect2(m + Vector2(2, -8), Vector2(7, 7)), Color(0.95, 0.8, 0.1))
			c.draw_rect(Rect2(m + Vector2(9, -5), Vector2(4, 2)), Color(0.95, 0.45, 0.1))
			c.draw_rect(Rect2(m + Vector2(5, -6), Vector2(1, 1)), Color(0, 0, 0))
		"seven":
			ink(c, RETRO_UI.FONT_BIG, m + Vector2(-4, 6), "7", Color(0.8, 0.1, 0.1), Color(0, 0, 0, 0), 20)
		"bell":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-7, 6), m + Vector2(7, 6), m + Vector2(4, -6), m + Vector2(-4, -6)]), Color(0.9, 0.7, 0.15))
			c.draw_rect(Rect2(m + Vector2(-1, 6), Vector2(3, 3)), Color(0.6, 0.45, 0.1))
		"cherry":
			c.draw_circle(m + Vector2(-4, 4), 4.0, Color(0.8, 0.08, 0.1))
			c.draw_circle(m + Vector2(5, 3), 4.0, Color(0.8, 0.08, 0.1))
			c.draw_line(m + Vector2(-4, 0), m + Vector2(2, -8), Color(0.2, 0.5, 0.15), 1.0)
			c.draw_line(m + Vector2(5, -1), m + Vector2(2, -8), Color(0.2, 0.5, 0.15), 1.0)
		"clover":
			for o in [Vector2(-3, -3), Vector2(3, -3), Vector2(0, 2)]:
				c.draw_circle(m + o, 3.5, Color(0.2, 0.6, 0.2))
			c.draw_line(m + Vector2(0, 4), m + Vector2(2, 9), Color(0.2, 0.5, 0.15), 1.0)
		_:
			c.draw_circle(m + Vector2(0, 2), 5.0, Color(0.55, 0.35, 0.15))
			c.draw_rect(Rect2(m + Vector2(-6, -5), Vector2(12, 4)), Color(0.4, 0.26, 0.12))
