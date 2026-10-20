extends "res://scripts/closeup/closeup_view.gd"

## The Jednota's till, close up (assets/textury/closeup/shop_till.png): the old register
## with its keys and the open drawer. Whoever the guest simulation has in the shop comes
## to the counter with a few things, a price on each. Key in what it comes to (the keys,
## or the number keys), turn the crank: they pay, often with a note too big, and you count
## the change out of the drawer onto the mat (a click on a compartment; a click on the mat
## takes one back), then click their note to hand it over. Charge too much and they say
## so; too little, or too much change, and it is the camp's money gone. Quick and exact:
## they leave you the small change (scripts/food/orders.gd).

const ORDERS = preload("res://scripts/food/orders.gd")
const BUSINESS = preload("res://scripts/business/business_runtime.gd")
const PIC := "res://assets/textury/closeup/shop_till.png"
const GOODS_DIR := "res://assets/textury/closeup/goods/"
const SFX_KEY := "res://assets/sfx/os98/key.mp3"
const SFX_RING := "res://assets/sfx/bistro/till.mp3"
const SFX_COIN := "res://assets/sfx/pub/coins_bar.mp3"

const PRICES := {"roll": 1, "salami": 4, "beer": 2, "milk": 2, "pickles": 3, "bread": 3}
const BASKETS := {
	"drunk": [["beer", "beer", "beer", "salami"], ["beer", "beer", "roll"], ["beer", "pickles"]],
	"tramp": [["bread", "salami", "pickles"], ["bread", "beer"], ["salami", "roll", "roll"]],
	"quiet_guy": [["milk", "roll", "roll"], ["bread", "milk"], ["roll", "roll", "roll"]],
	"cheap_chick": [["beer", "roll"], ["milk", "roll"], ["pickles", "beer"]],
	"picker": [["bread", "milk", "roll", "roll", "roll"], ["milk", "pickles", "bread"], ["roll", "roll", "milk"]],
	"family": [["milk", "bread", "roll", "roll"], ["milk", "salami", "roll"], ["bread", "pickles", "milk"]],
}
## The light keys of the register (detected on the picture): 7 8 9 / 4 5 6 / 1 2 3 / C 0.
const KEYS := [
	["7", Vector2(230.3, 68.8)], ["8", Vector2(239.4, 69.6)], ["9", Vector2(247.8, 70.5)],
	["4", Vector2(227.2, 75.5)], ["5", Vector2(236.1, 76.3)], ["6", Vector2(245.2, 76.9)],
	["1", Vector2(223.9, 82.2)], ["2", Vector2(233.0, 83.1)], ["3", Vector2(242.3, 84.0)],
	["C", Vector2(220.7, 89.5)], ["0", Vector2(230.0, 90.5)],
]
const GLYPHS := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
	"C": ["111", "100", "100", "100", "111"],
}
## Seven segments per digit: a b c d e f g.
const SEG := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
	"6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
}
const DISPLAY := Rect2(231, 44, 50, 16)
const CRANK := Rect2(281, 70, 26, 44)
## The drawer: coin compartments and the notes.
const TRAYS := [["c1", 1, Rect2(140, 140, 26, 27)], ["c2", 2, Rect2(166, 144, 30, 27)], ["n5", 5, Rect2(197, 148, 28, 32)], ["n10", 10, Rect2(225, 150, 28, 30)]]
const MAT := Rect2(92, 186, 54, 22)
const NOTE_AT := Rect2(44, 188, 40, 18)

var building_key := ""

var _state := "wait"            # wait / key / change / done
var _who: Dictionary = {}
var _basket: Array = []
var _typed := ""
var _charged := 0
var _paid := 0
var _change: Array = []          # values on the mat
var _t := 0.0
var _t0 := 0.0
var _next := 0.0
var _flash := 0.0
var _floaters: Array = []
var _tex: Dictionary = {}
## The money and the price tags are renders (closeup/parts/: note_5/10/20, coin_1/2,
## price_tag).
const PARTS := "res://assets/textury/closeup/parts/"


func _part(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(PARTS + key + ".png") if ResourceLoader.exists(PARTS + key + ".png") else null
	return _tex[key]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_rng.randomize()
	for n in PRICES:
		var p: String = GOODS_DIR + str(n) + ".png"
		_tex[n] = load(p) if ResourceLoader.exists(p) else null


func _opened() -> void:
	if _state == "wait":
		_next = 1.0
	if ORDERS.visitors(building_key).is_empty() and _state == "wait":
		say("", "Nobody at the counter. The fridge hums.", false)
	elif _state == "wait":
		say("", "", false)


## Walking away mid-sale: the change they are owed goes back to them (the camp keeps
## only what it charged).
func _closing() -> void:
	_settle_owed()


func _settle_owed() -> void:
	if _state == "change":
		ORDERS.pay(-(_paid - _charged))
		ORDERS.note_served(_who)
		_reset("done")
		_next = 1.0


func _hotspots() -> Array:
	var out: Array = []
	for k in KEYS:
		var c: Vector2 = k[1]
		out.append({"id": "k" + str(k[0]), "rect": Rect2(c - Vector2(4, 3.5), Vector2(8, 7))})
	out.append({"id": "crank", "rect": CRANK})
	if _state == "change":
		for tr in TRAYS:
			out.append({"id": str(tr[0]), "rect": tr[2]})
		if not _change.is_empty():
			out.append({"id": "mat", "rect": MAT})
		out.append({"id": "note", "rect": NOTE_AT})
	return out


func _clicked(id: String) -> void:
	if id.begins_with("k"):
		_press(id.substr(1))
		return
	match id:
		"crank":
			_ring()
		"mat":
			_change.pop_back()
			_sfx(SFX_COIN, -16.0, 1.5)
		"note":
			_hand_over()
		_:
			for tr in TRAYS:
				if str(tr[0]) == id and _change.size() < 12:
					_change.append(int(tr[1]))
					_sfx(SFX_COIN, -14.0, 1.4 if int(tr[1]) < 5 else 0.8)


func _key(event: InputEventKey) -> bool:
	var code := event.keycode
	if code >= KEY_0 and code <= KEY_9:
		_press(str(code - KEY_0))
		return true
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		_press(str(code - KEY_KP_0))
		return true
	if code == KEY_BACKSPACE or code == KEY_DELETE:
		_press("C")
		return true
	if code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
		if _state == "change":
			_hand_over()
		else:
			_ring()
		return true
	return false


func _press(k: String) -> void:
	_sfx(SFX_KEY, -10.0, 0.7)
	if _state != "key":
		return
	if k == "C":
		_typed = ""
	elif _typed.length() < 3:
		_typed = (_typed + k).lstrip("0")


func _tick(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	for f in _floaters:
		f["t"] = float(f["t"]) + delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.4)
	if _state == "key" or _state == "change":
		# They got bored of waiting, or left the shop.
		var still := false
		for v in ORDERS.visitors(building_key):
			if int(v["id"]) == int(_who.get("id", -1)):
				still = true
		if not still:
			_settle_owed()
			_reset("wait")
		return
	_next -= delta
	if _next > 0.0:
		return
	if _state == "done":
		_reset("wait")
		_next = _rng.randf_range(2.0, 4.0)
		return
	_next = _rng.randf_range(4.0, 7.0)
	_new_customer()


func _reset(state: String) -> void:
	_state = state
	_who = {}
	_basket = []
	_typed = ""
	_change = []
	_paid = 0
	_charged = 0


func _new_customer() -> void:
	var who: Array = []
	for v in ORDERS.visitors(building_key):
		if ORDERS.left_for(v, "vecerka") > 0:
			who.append(v)
	if who.is_empty():
		return
	_who = who[_rng.randi() % who.size()]
	var options: Array = BASKETS.get(str(_who["archetype"]), BASKETS["quiet_guy"])
	_basket = (options[_rng.randi() % options.size()] as Array).duplicate()
	_state = "key"
	_t0 = _t
	var lines := ["Just these.", "This lot, please.", "And that's me.", "Ring that up, will you?"]
	say(ORDERS.first_name(str(_who["name"])), lines[_rng.randi() % lines.size()])


func _total() -> int:
	var s := 0
	for b in _basket:
		s += int(PRICES.get(str(b), 0))
	return s


## The crank: the sale goes on the roll and they pay.
func _ring() -> void:
	if _state != "key" or _typed == "":
		_sfx(SFX_KEY, -12.0, 0.5)
		return
	var typed := int(_typed)
	var total := _total()
	var who := ORDERS.first_name(str(_who["name"]))
	if typed > total:
		say(who, "That's not right. I can count, you know.")
		ORDERS.mood(int(_who["id"]), -1.0, "The camp shop tried to overcharge me.")
		_flash = 0.6
		_typed = ""
		return
	var needs := {}
	for b in _basket:
		needs[str(b)] = int(needs.get(str(b), 0)) + 1
	if not BUSINESS.sell(building_key, needs, typed, false):
		say(who, "You haven't got it on the shelf? Then I'll go to Liblice.")
		if CoreRoot != null and CoreRoot.actions != null:
			CoreRoot.actions.biz_lost(building_key)
		ORDERS.note_served(_who)
		_reset("wait")
		return
	_sfx(SFX_RING, -6.0, 1.0)
	_charged = typed
	# What they pay with: exact, or the next note up (sometimes a bigger one).
	var notes := [5, 10, 20]
	_paid = 20
	for n in notes:
		if n >= _charged:
			_paid = n
			break
	if _rng.randf() < 0.3 and _paid < 20:
		_paid = notes[mini(notes.find(_paid) + 1, notes.size() - 1)]
	if _charged <= 6 and _rng.randf() < 0.25:
		_paid = _charged
	ORDERS.pay(_paid)
	if _paid == _charged:
		say(who, "Exact. There you go.")
		_finish(0)
		return
	_state = "change"
	say(who, "Here's %d." % _paid)


## Their note goes in the drawer, the change into their hand.
func _hand_over() -> void:
	if _state != "change":
		return
	var given := 0
	for v in _change:
		given += int(v)
	var due := _paid - _charged
	var who := ORDERS.first_name(str(_who["name"]))
	if given < due:
		say(who, "My change? I'm still owed %d." % (due - given))
		return
	ORDERS.pay(-given)
	_sfx(SFX_COIN, -10.0, 1.1)
	if given > due:
		say(who, "Ooh. Thanks!")
		ORDERS.mood(int(_who["id"]), 0.5, "")
		_floaters.append({"text": "-$%d" % (given - due), "at": Vector2(110, 176), "t": 0.0, "col": RETRO_UI.C_RED_LIGHT})
		_finish(-1)
		return
	_finish(0)


func _finish(_how: int) -> void:
	var who := ORDERS.first_name(str(_who["name"]))
	var exact := _charged == _total()
	var quick := _t - _t0 < 22.0
	var tip := 1 if exact and quick and _how == 0 else 0
	if tip > 0:
		ORDERS.pay(tip)
		say(who, ["Keep the crown.", "Quick hands. Keep the small change.", "Thanks, love. Keep it."][_rng.randi() % 3])
		ORDERS.mood(int(_who["id"]), 1.0, "The shop here is quick.")
	elif _how == 0 and not exact:
		say(who, "Lovely. Bye!")
	elif _how == 0:
		say(who, "Ta.")
	if _charged > 0:
		_floaters.append({"text": "+$%d" % (_charged + tip), "at": Vector2(150, 120), "t": 0.0, "col": RETRO_UI.C_AMBER_LIGHT if tip > 0 else RETRO_UI.C_BONE})
	ORDERS.note_served(_who)
	_state = "done"
	_next = 1.6


func _sfx(path: String, db: float, pitch: float) -> void:
	_audio.pitch_scale = pitch
	play(path, db)


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	# The key legends, in dark ink on the keys.
	for k in KEYS:
		_glyph(c, str(k[0]), (k[1] as Vector2) - Vector2(1, 2), Color(0.16, 0.12, 0.08))
	_paint_display(c)
	_paint_goods(c)
	if _state == "change" or (_state == "done" and _paid > 0):
		_paint_note(c, _paid, NOTE_AT.position)
	var x := MAT.position.x + 2.0
	for v in _change:
		if int(v) >= 5:
			_paint_note(c, int(v), Vector2(x, MAT.position.y + 6.0), true)
			x += 9.0
		else:
			var coin := _part("coin_2" if int(v) == 2 else "coin_1")
			if coin != null:
				c.draw_texture(coin, Vector2(x, MAT.position.y + 9.0))
			x += 5.0
	for f in _floaters:
		var kk := float(f["t"]) / 1.4
		var at: Vector2 = (f["at"] as Vector2) + Vector2(0, -16.0 * kk)
		var col2: Color = f["col"]
		col2.a = 1.0 - kk * kk
		ink(c, RETRO_UI.FONT_LABEL, at.floor(), str(f["text"]), col2, Color(0, 0, 0, col2.a), 8)


func _glyph(c: Control, g: String, at: Vector2, col: Color) -> void:
	var rows: Array = GLYPHS.get(g, [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "1":
				c.draw_rect(Rect2(floorf(at.x) + x, floorf(at.y) + y, 1, 1), col)


## The register's window: what you have keyed, in green segments.
func _paint_display(c: Control) -> void:
	c.draw_rect(DISPLAY, Color(0.06, 0.1, 0.07))
	var lit := Color(0.52, 1.0, 0.46) if _flash <= 0.0 or int(_flash * 10.0) % 2 == 0 else Color(1.0, 0.4, 0.3)
	var text := _typed if _state == "key" else (str(_charged) if _state != "wait" else "")
	var x := DISPLAY.end.x - 3.0
	for i in range(text.length() - 1, -1, -1):
		x -= 7.0
		_seg_digit(c, text[i], Vector2(x, DISPLAY.position.y + 3.0), lit)
	if text == "" and int(_t * 2.0) % 2 == 0:
		c.draw_rect(Rect2(DISPLAY.end.x - 9.0, DISPLAY.end.y - 4.0, 5, 1), lit * Color(1, 1, 1, 0.6))


func _seg_digit(c: Control, d: String, at: Vector2, col: Color) -> void:
	var segs: String = SEG.get(d, "")
	var x := floorf(at.x)
	var y := floorf(at.y)
	if segs.contains("a"):
		c.draw_rect(Rect2(x + 1, y, 3, 1), col)
	if segs.contains("b"):
		c.draw_rect(Rect2(x + 4, y + 1, 1, 4), col)
	if segs.contains("c"):
		c.draw_rect(Rect2(x + 4, y + 6, 1, 3), col)
	if segs.contains("d"):
		c.draw_rect(Rect2(x + 1, y + 9, 3, 1), col)
	if segs.contains("e"):
		c.draw_rect(Rect2(x, y + 6, 1, 3), col)
	if segs.contains("f"):
		c.draw_rect(Rect2(x, y + 1, 1, 4), col)
	if segs.contains("g"):
		c.draw_rect(Rect2(x + 1, y + 5, 3, 1), col)


## What they put on the counter, a price tag under each.
func _paint_goods(c: Control) -> void:
	var x := 12.0
	for b in _basket:
		var t: Texture2D = _tex.get(str(b), null)
		if t == null:
			continue
		var s := t.get_size()
		c.draw_texture_rect(t, Rect2(x, 170.0 - s.y, s.x, s.y), false)
		var tag := "$%d" % int(PRICES[str(b)])
		var tw := RETRO_UI.FONT_LABEL.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var tag_r := Rect2(x + s.x * 0.5 - tw * 0.5 - 2.0, 172.0, tw + 4.0, 9.0)
		var tag_t := _part("price_tag")
		if tag_t != null:
			c.draw_texture_rect(tag_t, tag_r, false)
		ink(c, RETRO_UI.FONT_LABEL, Vector2(tag_r.position.x + 2.0, tag_r.position.y + 7.0), tag, Color(0.6, 0.08, 0.06), Color(0, 0, 0, 0), 8)
		x += maxf(s.x, tw + 4.0) + 6.0


func _paint_note(c: Control, value: int, at: Vector2, small := false) -> void:
	var r := Rect2(at, Vector2(14, 8) if small else Vector2(34, 16))
	var note := _part("note_%d" % value)
	if note != null:
		c.draw_texture_rect(note, r, false)
	if not small:
		ink(c, RETRO_UI.FONT_LABEL, Vector2(r.position.x + 4.0, r.position.y + 11.0), "$%d" % value, Color(0.96, 0.94, 0.86), Color(0, 0, 0, 0.6), 8)


# ── debug (tools/shot_driver.gd) ─────────────────────────────────────────────

func debug_key_total() -> void:
	if _state == "key":
		_typed = str(_total())


func debug_count_change() -> void:
	var due := _paid - _charged
	_change = []
	for v in [10, 5, 2, 1]:
		while due >= v:
			_change.append(v)
			due -= v
