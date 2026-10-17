extends "res://scripts/closeup/closeup_view.gd"

## The bistro's pass, close up (assets/textury/closeup/bistro_hatch.png): the goulash
## pot, the trays of dumplings and fried cheese, the chip basket, the tartar, the stack
## of plates and the bell. Whoever the guest simulation has eating in the bistro orders;
## the tickets go up on the rail with what is on the plate drawn on them. Take a plate,
## put on it what the ticket says (a click on each pot and tray), ring the bell: the
## money, and a tip if it went out quickly (scripts/food/orders.gd). A wrong plate comes
## back; a click on the plate on the pass scrapes it.

const ORDERS = preload("res://scripts/food/orders.gd")
const PIC := "res://assets/textury/closeup/bistro_hatch.png"
const FOOD_DIR := "res://assets/textury/closeup/food/"
const SFX_PLATE := "res://assets/sfx/bistro/plate_down.mp3"
const SFX_LADLE := "res://assets/sfx/bistro/ladle_plate.mp3"
const SFX_BELL := "res://assets/sfx/bistro/bell_ding.mp3"
const SFX_TILL := "res://assets/sfx/bistro/till.mp3"
const SFX_FRYER := "res://assets/sfx/bistro/fryer.mp3"

const DISHES := {
	"goulash": {"parts": ["goulash", "dumpling"], "price": 7,
		"ask": ["Goulash and dumplings, chef.", "Gulas. With six dumplings. Fine, four.", "The goulash. It's the goulash or nothing."]},
	"smazak": {"parts": ["cheese", "fries", "tartar"], "price": 8,
		"ask": ["Fried cheese, chips, tartar.", "A smazak. Heavy on the tartar.", "Fried cheese, please. The proper one."]},
	"fries": {"parts": ["fries", "tartar"], "price": 3,
		"ask": ["Just chips. And tartar.", "Chips for the boy.", "Chips. I'm watching my figure."]},
}
const TASTE := {
	"drunk": {"goulash": 4, "smazak": 1},
	"tramp": {"goulash": 3, "fries": 1},
	"quiet_guy": {"smazak": 3, "goulash": 1},
	"cheap_chick": {"fries": 3, "smazak": 1},
	"picker": {"goulash": 3, "smazak": 1},
	"family": {"smazak": 2, "fries": 2},
}
## Where each thing is in the picture (picture px; first match wins).
const SPOTS := [
	["bell", Rect2(284, 96, 36, 34)],
	["plates", Rect2(258, 34, 62, 60)],
	["tartar", Rect2(247, 100, 36, 28)],
	["fries", Rect2(208, 50, 62, 48)],
	["cheese", Rect2(170, 76, 80, 62)],
	["dumpling", Rect2(110, 88, 64, 72)],
	["goulash", Rect2(6, 58, 104, 76)],
]
const PASS_AT := Vector2(198, 176)
const PASS_RECT := Rect2(156, 154, 86, 44)
const TICKETS := [Rect2(164, 12, 26, 37), Rect2(196, 9, 26, 37), Rect2(228, 6, 24, 36)]
## On the plate (centre offsets, squashed by the angle you see the pass at).
const ON_PLATE := {
	"goulash": [Vector2(-11, -2), Vector2(34, 17)],
	"dumpling": [Vector2(12, -3), Vector2(13, 8)],
	"cheese": [Vector2(-10, -1), Vector2(30, 15)],
	"fries": [Vector2(12, -3), Vector2(26, 13)],
	"tartar": [Vector2(3, 7), Vector2(13, 7)],
}
const GOOD := ["Now that's food.", "Like at my mother's.", "Quick! Thank you.", "Dobrou chut, eh?"]
const SLOW := ["Finally.", "Thought you'd gone fishing.", "Cheers."]
const WRONG := ["That's not what I ordered.", "Whose is this?", "No. Look at the ticket."]

var building_key := ""

var _plate: Array = []          # parts on the plate on the pass; [] and _has_plate false = none
var _has_plate := false
var _queue: Array = []          # [{v, dish, t0}]
var _next_order := 0.0
var _t := 0.0
var _pop: Dictionary = {}       # part -> seconds since it landed (a little drop-in)
var _plate_slide := -1.0        # the plate going out (s)
var _floaters: Array = []
var _tex: Dictionary = {}
var _fryer: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_rng.randomize()
	for n in ["plate", "goulash", "dumpling", "cheese", "fries", "tartar"]:
		var p: String = FOOD_DIR + n + ".png"
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
		# Little drawings for the tickets (made at that size, not shrunk from the big ones).
		var ip: String = FOOD_DIR + "icon_" + n + ".png"
		_tex["icon_" + n] = load(ip) if ResourceLoader.exists(ip) else null
	_fryer = AudioStreamPlayer.new()
	_fryer.volume_db = -60.0
	if ResourceLoader.exists(SFX_FRYER):
		var st = load(SFX_FRYER)
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_fryer.stream = st
	add_child(_fryer)


func _opened() -> void:
	_next_order = 1.0
	_sync_queue()
	_fryer.volume_db = -22.0
	_fryer.play()
	if ORDERS.visitors(building_key).is_empty():
		say("", "Nobody out front. The goulash keeps warm on its own.", false)
	else:
		say("", "", false)


func _closing() -> void:
	_fryer.stop()


func _hotspots() -> Array:
	var out: Array = []
	for s in SPOTS:
		out.append({"id": str(s[0]), "rect": s[1]})
	if _has_plate and _plate_slide < 0.0:
		out.insert(0, {"id": "pass", "rect": PASS_RECT})
	return out


func _clicked(id: String) -> void:
	if _plate_slide >= 0.0:
		return
	match id:
		"plates":
			if not _has_plate:
				_has_plate = true
				_plate = []
				_pop["plate"] = 0.0
				_sfx(SFX_PLATE, -8.0, 1.0)
		"bell":
			_sfx(SFX_BELL, -4.0, 1.0)
			if _has_plate and not _plate.is_empty():
				_send_out()
		"pass":
			# Scraped into the bin: start again.
			_has_plate = false
			_plate = []
			_sfx(SFX_PLATE, -12.0, 0.8)
		_:
			if not _has_plate:
				_sfx(SFX_LADLE, -18.0, 1.4)
				return
			if not _plate.has(id):
				_plate.append(id)
				_pop[id] = 0.0
				_sfx(SFX_LADLE, -8.0, 1.0 if id == "goulash" else 1.25)


func _tick(delta: float) -> void:
	_t += delta
	for k in _pop.keys():
		_pop[k] = float(_pop[k]) + delta
	if _plate_slide >= 0.0:
		_plate_slide += delta
		if _plate_slide > 0.45:
			_plate_slide = -1.0
			_has_plate = false
			_plate = []
	for f in _floaters:
		f["t"] = float(f["t"]) + delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.4)
	_next_order -= delta
	if _next_order <= 0.0:
		_next_order = _rng.randf_range(6.0, 10.0)
		_sync_queue()
		_new_order()


func _sync_queue() -> void:
	var here := {}
	for v in ORDERS.visitors(building_key):
		here[int(v["id"])] = true
	_queue = _queue.filter(func(o: Dictionary) -> bool: return here.has(int((o["v"] as Dictionary)["id"])))


func _new_order() -> void:
	if _queue.size() >= TICKETS.size():
		return
	var waiting := {}
	for o in _queue:
		var k := str((o["v"] as Dictionary)["visit"])
		waiting[k] = int(waiting.get(k, 0)) + 1
	var who: Array = []
	for v in ORDERS.visitors(building_key):
		if ORDERS.left_for(v, "rest") - int(waiting.get(str(v["visit"]), 0)) > 0:
			who.append(v)
	if who.is_empty():
		return
	var v: Dictionary = who[_rng.randi() % who.size()]
	var dish := _pick(str(v["archetype"]))
	_queue.append({"v": v, "dish": dish, "t0": _t})
	var lines: Array = (DISHES[dish] as Dictionary)["ask"]
	say(ORDERS.first_name(str(v["name"])), str(lines[_rng.randi() % lines.size()]))


func _pick(arch: String) -> String:
	var w: Dictionary = TASTE.get(arch, {"goulash": 1})
	var total := 0
	for k in w:
		total += int(w[k])
	var r := _rng.randi() % maxi(1, total)
	for k in w:
		r -= int(w[k])
		if r < 0:
			return str(k)
	return "goulash"


## Out through the hatch: to whichever ticket it is (any of them, the room does not mind
## the order), or back if it is nobody's.
func _send_out() -> void:
	var have := _plate.duplicate()
	have.sort()
	for i in _queue.size():
		var o: Dictionary = _queue[i]
		var need: Array = ((DISHES[str(o["dish"])] as Dictionary)["parts"] as Array).duplicate()
		need.sort()
		if need != have:
			continue
		var v: Dictionary = o["v"]
		var took := _t - float(o["t0"])
		var tip := 2 if took < 14.0 else (1 if took < 26.0 else 0)
		var price := int((DISHES[str(o["dish"])] as Dictionary)["price"])
		ORDERS.pay(price + tip)
		ORDERS.note_served(v)
		_queue.remove_at(i)
		_plate_slide = 0.0
		_sfx(SFX_TILL, -8.0, 1.0)
		_floaters.append({"text": "+$%d" % (price + tip), "at": Vector2(250, 150), "t": 0.0, "col": RETRO_UI.C_AMBER_LIGHT if tip > 0 else RETRO_UI.C_BONE})
		var who := ORDERS.first_name(str(v["name"]))
		if tip >= 2:
			say(who, str(GOOD[_rng.randi() % GOOD.size()]))
			ORDERS.mood(int(v["id"]), 2.0, "The bistro is quick and the food is hot.")
		else:
			say(who, str(SLOW[_rng.randi() % SLOW.size()]))
			ORDERS.mood(int(v["id"]), 0.3 if tip > 0 else -0.5, "" if tip > 0 else "Waited an age for my dinner.")
		return
	# Nobody's: it comes back through the hatch.
	var first: Dictionary = _queue[0]["v"] if not _queue.is_empty() else {}
	say(ORDERS.first_name(str(first.get("name", ""))) if not first.is_empty() else "", str(WRONG[_rng.randi() % WRONG.size()]) if not _queue.is_empty() else "Nobody ordered that. It goes in the bin.")
	_has_plate = false
	_plate = []


func _sfx(path: String, db: float, pitch: float) -> void:
	_audio.pitch_scale = pitch
	play(path, db)


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	_paint_tickets(c)
	if _has_plate:
		var at := PASS_AT
		if _plate_slide >= 0.0:
			# Through the hatch: up and away.
			at += Vector2(_plate_slide * 30.0, -_plate_slide * _plate_slide * 260.0)
		var drop := clampf(float(_pop.get("plate", 1.0)) / 0.12, 0.0, 1.0)
		at.y -= (1.0 - drop) * 6.0
		_draw_squashed(c, "plate", at, Vector2(78, 40))
		for part in ["goulash", "cheese", "dumpling", "fries", "tartar"]:
			if not _plate.has(part):
				continue
			var spec: Array = ON_PLATE[part]
			var k := clampf(float(_pop.get(part, 1.0)) / 0.15, 0.0, 1.0)
			var p: Vector2 = at + (spec[0] as Vector2) + Vector2(0, -(1.0 - k) * 8.0)
			if part == "dumpling":
				for j in 3:
					_draw_squashed(c, part, p + Vector2(float(j) * 5.0 - 5.0, float(j % 2) * 3.0 - 1.0), spec[1])
			else:
				_draw_squashed(c, part, p, spec[1])
	for f in _floaters:
		var kk := float(f["t"]) / 1.4
		var fat: Vector2 = (f["at"] as Vector2) + Vector2(0, -16.0 * kk)
		var col: Color = f["col"]
		col.a = 1.0 - kk * kk
		ink(c, RETRO_UI.FONT_LABEL, fat.floor(), str(f["text"]), col, Color(0, 0, 0, col.a), 8)


func _draw_squashed(c: Control, n: String, centre: Vector2, size: Vector2) -> void:
	var t: Texture2D = _tex.get(n, null)
	if t == null:
		return
	c.draw_texture_rect(t, Rect2((centre - size * 0.5).floor(), size), false)


## The tickets on the rail: a little drawing of each thing that goes on the plate. The
## picture's own (old, blank) slips are painted out with the steel beside the rail.
func _paint_tickets(c: Control) -> void:
	for i in TICKETS.size():
		var r: Rect2 = TICKETS[i]
		if i >= _queue.size():
			if picture != null:
				c.draw_texture_rect_region(picture, r.grow(2.0), Rect2(Vector2(126.0, r.position.y - 2.0), r.size + Vector2(4, 4)))
			continue
		var o: Dictionary = _queue[i]
		c.draw_rect(r, Color(0.92, 0.88, 0.76))
		c.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), Color(0, 0, 0, 0.45))
		c.draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 1, r.position.y + 1, 2, 2), Color(0.7, 0.12, 0.1))
		var parts: Array = (DISHES[str(o["dish"])] as Dictionary)["parts"]
		for j in parts.size():
			var t: Texture2D = _tex.get("icon_" + str(parts[j]), null)
			if t != null:
				var ts := t.get_size()
				c.draw_texture_rect(t, Rect2(floorf(r.position.x + (r.size.x - ts.x) * 0.5), r.position.y + 4.0 + float(j) * 10.0, ts.x, ts.y), false)
		# Waiting long: the ticket curls (goes darker at the edge).
		var age := _t - float(o["t0"])
		if age > 26.0:
			c.draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), Color(0.6, 0.5, 0.36, 0.6))


# ── debug (tools/shot_driver.gd) ─────────────────────────────────────────────

## The plate ticket `i` asks for, on the pass.
func debug_plate_for(i: int) -> void:
	if i < 0 or i >= _queue.size():
		return
	_has_plate = true
	_plate = ((DISHES[str(_queue[i]["dish"])] as Dictionary)["parts"] as Array).duplicate()
	for p in _plate:
		_pop[p] = 0.0
