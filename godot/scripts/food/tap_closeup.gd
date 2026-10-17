extends "res://scripts/closeup/closeup_view.gd"

## Behind the bar of the pub, close up (assets/textury/closeup/pub_tap.png): the tap and
## a glass on the drip tray. Whoever the guest simulation has in the pub orders, one slip
## at a time, the three Czech pours:
##   hladinka  beer up to the line, a collar of thick foam to the rim
##   snyt      half beer, the rest foam
##   mliko     all foam, a finger of beer under it (somebody always wants one)
## Hold the left button on the tap to pull it (beer, with a little head), the right to
## push it back (foam only). The head settles while you wait. Click the glass to slide it
## over: the sale, and a tip for a good pour (scripts/food/orders.gd). Spill over the rim
## and the tray swims.

const ORDERS = preload("res://scripts/food/orders.gd")
const PIC := "res://assets/textury/closeup/pub_tap.png"
const SFX_TAP_OPEN := "res://assets/sfx/pub/tap_open.mp3"
const SFX_TAP_CLOSE := "res://assets/sfx/pub/tap_close.mp3"
const SFX_POUR := "res://assets/sfx/pub/tap_pour.mp3"
const SFX_GLASS := "res://assets/sfx/pub/glass_down.mp3"
const SFX_COINS := "res://assets/sfx/pub/coins_bar.mp3"

const SPOUT := Vector2(152, 101)
const TAP_RECT := Rect2(98, 0, 70, 108)
const KNOB := Rect2(141, 3, 21, 52)
const KNOB_PATCH := Rect2(165, 3, 21, 52)
const KNOB_PIVOT := Vector2(151, 55)
## The glass: inside bottom and rim (picture y), widths at the bottom and the rim.
const G_X := 152.0
const G_BOTTOM := 203.0
const G_RIM := 114.0
const G_W_BOT := 28.0
const G_W_TOP := 38.0
const GLASS_RECT := Rect2(128, 108, 48, 102)
## The half-litre mark on the glass.
const LINE := 0.8

const POUR_RATE := 0.24       # glass heights a second, pulled
const PULL_FOAM := 0.045      # the head a pulled pour makes
const PUSH_FOAM := 0.36       # pushed back: foam only
const PUSH_BEER := 0.012
const SETTLE := 0.03          # foam a second turning back into beer (a third of it)

const POURS := {
	"hladinka": {"beer": 0.78, "price": 4},
	"snyt": {"beer": 0.46, "price": 3},
	"mliko": {"beer": 0.12, "price": 2},
}
## What each kind of guest asks for (weights), and how.
const TASTE := {
	"drunk": {"hladinka": 5, "snyt": 1},
	"tramp": {"hladinka": 3, "snyt": 2},
	"quiet_guy": {"hladinka": 4, "snyt": 1},
	"cheap_chick": {"mliko": 3, "snyt": 2},
	"picker": {"snyt": 3, "mliko": 1},
	"family": {"hladinka": 3, "snyt": 1},
}
const ASK := {
	"hladinka": ["A hladinka.", "Hladinka, boss.", "One more. Hladinka.", "Pivo. A proper one."],
	"snyt": ["A snyt, please.", "Just a snyt. I'm driving. Ish.", "Snyt. Half and half."],
	"mliko": ["A mliko! Don't look at me like that.", "Mliko. All froth.", "One mliko, sweetie."],
}
const GOOD := ["Now that's a beer.", "Like my grandad poured.", "Na zdravi!", "Ahh. Perfect.", "You've done this before."]
const FINE := ["It'll do.", "Bit off. Fine.", "Cheers."]
const BAD := ["Is that a %s? Pour it again.", "That's no %s. Again."]

var building_key := ""

var _beer := 0.0
var _foam := 0.0
var _spilled := 0.0
var _puddle := 0.0
var _pull := false
var _push := false
var _knob := 0.0                     # -1 pushed .. 0 .. 1 pulled (eased)
var _slide := -1.0                   # the glass sliding off (s), -1 = on the tray
var _drop := 0.0                     # a new glass set down (s left)
var _queue: Array = []               # [{v, pour, t0}]
var _next_order := 0.0
var _bubbles: Array = []             # [Vector2 (x offset, fraction)]
var _drips: Array = []               # [{x, y, v}]
var _floaters: Array = []            # [{text, at, t, col}]
var _t := 0.0
var _pour_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_rng.randomize()
	_pour_player = AudioStreamPlayer.new()
	_pour_player.volume_db = -60.0
	if ResourceLoader.exists(SFX_POUR):
		var st = load(SFX_POUR)
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_pour_player.stream = st
	add_child(_pour_player)
	for i in 14:
		_bubbles.append(Vector2(_rng.randf_range(-0.42, 0.42), _rng.randf()))


func _opened() -> void:
	_pull = false
	_push = false
	_next_order = 1.2
	_sync_queue()
	if ORDERS.visitors(building_key).is_empty():
		say("", "Nobody at the bar. The tap drips onto the tray.", false)
	else:
		say("", "", false)


func _closing() -> void:
	_pull = false
	_push = false
	_pour_player.stop()


func _hotspots() -> Array:
	var out: Array = [{"id": "tap", "rect": TAP_RECT}]
	if _slide < 0.0 and _beer + _foam > 0.02:
		out.append({"id": "glass", "rect": GLASS_RECT})
	return out


func _clicked(id: String) -> void:
	if id == "glass":
		_serve()


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if visible and _closing_t < 0.0 and not get_tree().paused and mb != null \
			and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
		if mb.pressed and hovered() == "tap" and _slide < 0.0:
			_pull = mb.button_index == MOUSE_BUTTON_LEFT
			_push = not _pull
			play(SFX_TAP_OPEN, -6.0)
			_pour_player.pitch_scale = 1.0 if _pull else 1.3
			if not _pour_player.playing:
				_pour_player.play()
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and (_pull or _push):
			_pull = false
			_push = false
			play(SFX_TAP_CLOSE, -6.0)
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _tick(delta: float) -> void:
	_t += delta
	_knob = move_toward(_knob, 1.0 if _pull else (-1.0 if _push else 0.0), delta * 9.0)
	_pour_player.volume_db = move_toward(_pour_player.volume_db, (-7.0 if _pull else -13.0) if (_pull or _push) else -60.0, delta * 120.0)
	if _pour_player.volume_db <= -59.0 and _pour_player.playing:
		_pour_player.stop()
	if (_pull or _push) and HandCursor != null:
		HandCursor.want(HandCursor.GRAB)
	# The glass.
	if _slide >= 0.0:
		_slide += delta
		if _slide > 0.5:
			_slide = -1.0
			_beer = 0.0
			_foam = 0.0
			_spilled = 0.0
			_drop = 0.18
			play(SFX_GLASS, -10.0)
	else:
		_pour(delta)
	_drop = maxf(0.0, _drop - delta)
	_puddle = maxf(0.0, _puddle - delta * 0.004)
	# Drips running down the outside, then onto the tray.
	for d in _drips:
		d["v"] = minf(26.0, float(d["v"]) + delta * 30.0)
		d["y"] = float(d["y"]) + float(d["v"]) * delta
	_drips = _drips.filter(func(d: Dictionary) -> bool: return float(d["y"]) < G_BOTTOM + 4.0)
	for f in _floaters:
		f["t"] = float(f["t"]) + delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.4)
	# Orders from the room.
	_next_order -= delta
	if _next_order <= 0.0:
		_next_order = _rng.randf_range(5.0, 9.0)
		_sync_queue()
		_new_order()


func _pour(delta: float) -> void:
	if _pull:
		_beer += POUR_RATE * delta
		_foam += PULL_FOAM * delta
	elif _push:
		_beer += PUSH_BEER * delta
		_foam += PUSH_FOAM * delta
	if _foam > 0.0:
		var s := minf(_foam, SETTLE * delta)
		_foam -= s
		_beer += s / 3.0
	var over := _beer + _foam - 1.0
	if over > 0.0:
		# Over the rim: the foam goes first, then the beer.
		var off_foam := minf(over, _foam)
		_foam -= off_foam
		_beer -= over - off_foam
		_spilled += over
		_puddle = minf(1.0, _puddle + over * 2.5)
		if _rng.randf() < 0.18 and _drips.size() < 10:
			_drips.append({"side": -1.0 if _rng.randf() < 0.5 else 1.0, "y": G_RIM + 1.0, "v": 2.0})


func _sync_queue() -> void:
	var here := {}
	for v in ORDERS.visitors(building_key):
		here[int(v["id"])] = true
	_queue = _queue.filter(func(o: Dictionary) -> bool: return here.has(int((o["v"] as Dictionary)["id"])))


func _new_order() -> void:
	if _queue.size() >= 3:
		return
	var waiting := {}
	for o in _queue:
		var k := str((o["v"] as Dictionary)["visit"])
		waiting[k] = int(waiting.get(k, 0)) + 1
	var who: Array = []
	for v in ORDERS.visitors(building_key):
		if ORDERS.left_for(v, "pub") - int(waiting.get(str(v["visit"]), 0)) > 0:
			who.append(v)
	if who.is_empty():
		return
	var v: Dictionary = who[_rng.randi() % who.size()]
	var pour := _pick_pour(str(v["archetype"]))
	_queue.append({"v": v, "pour": pour, "t0": _t})
	if _queue.size() == 1:
		_ask(_queue[0])


func _pick_pour(arch: String) -> String:
	var w: Dictionary = TASTE.get(arch, {"hladinka": 1})
	var total := 0
	for k in w:
		total += int(w[k])
	var r := _rng.randi() % maxi(1, total)
	for k in w:
		r -= int(w[k])
		if r < 0:
			return str(k)
	return "hladinka"


func _ask(o: Dictionary) -> void:
	var lines: Array = ASK.get(str(o["pour"]), ["A beer."])
	say(ORDERS.first_name(str((o["v"] as Dictionary)["name"])), str(lines[_rng.randi() % lines.size()]))


## Over the bar with it: how close it is to what they asked for.
func _serve() -> void:
	if _queue.is_empty():
		say("", "Nobody asked for that one. You drink it yourself.")
		_slide = 0.0
		return
	var o: Dictionary = _queue[0]
	var v: Dictionary = o["v"]
	var want: Dictionary = POURS[str(o["pour"])]
	var top := _beer + _foam
	var e_beer := absf(_beer - float(want["beer"])) / 0.13
	var e_top := maxf(0.0, 0.96 - top) / 0.1
	var e_spill := _spilled / 0.12
	var q := clampf(1.0 - 0.5 * e_beer - 0.5 * e_top - 0.25 * e_spill, 0.0, 1.0)
	var who := ORDERS.first_name(str(v["name"]))
	if q < 0.3:
		# Sent back: the order stays, the glass goes down the sink.
		say(who, str(BAD[_rng.randi() % BAD.size()]) % str(o["pour"]))
		ORDERS.mood(int(v["id"]), -1.5, "The beer here is poured by a child.")
		_slide = 0.0
		return
	var tip := 2 if q >= 0.85 else (1 if q >= 0.6 else 0)
	var price := int(want["price"])
	ORDERS.pay(price + tip)
	ORDERS.note_served(v)
	_queue.pop_front()
	_slide = 0.0
	play(SFX_COINS, -8.0)
	_floaters.append({"text": "+$%d" % (price + tip), "at": Vector2(232, 150), "t": 0.0, "col": RETRO_UI.C_AMBER_LIGHT if tip > 0 else RETRO_UI.C_BONE})
	if q >= 0.85:
		say(who, str(GOOD[_rng.randi() % GOOD.size()]))
		ORDERS.mood(int(v["id"]), 2.0, "The barman pours a proper %s." % str(o["pour"]))
	else:
		say(who, str(FINE[_rng.randi() % FINE.size()]) + ("" if _spilled < 0.05 else " And mind the bar."))
		ORDERS.mood(int(v["id"]), 0.4, "")
	if not _queue.is_empty():
		_next_order = maxf(_next_order, 1.6)
		get_tree().create_timer(1.4).timeout.connect(_ask_next)


func _ask_next() -> void:
	if visible and not _queue.is_empty():
		_ask(_queue[0])


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	_paint_knob(c)
	_paint_puddle(c)
	var off := Vector2.ZERO
	if _slide >= 0.0:
		off.x = _slide * _slide * 900.0
	elif _drop > 0.0:
		off.y = -_drop * 30.0
	_paint_stream(c)
	_paint_glass(c, off)
	# Foam running down the outside of the glass, along its wall.
	for d in _drips:
		var dy := float(d["y"])
		var dw := lerpf(G_W_BOT, G_W_TOP, (G_BOTTOM - dy) / (G_BOTTOM - G_RIM))
		var dx := G_X + float(d["side"]) * (dw * 0.5 + 1.0) - (1.0 if float(d["side"]) < 0.0 else 0.0)
		c.draw_rect(Rect2(dx + off.x, dy - 3.0, 1, 4), Color(0.96, 0.92, 0.8, 0.85))
	_paint_slips(c)
	for f in _floaters:
		var k := float(f["t"]) / 1.4
		var at: Vector2 = (f["at"] as Vector2) + Vector2(0, -16.0 * k)
		var col: Color = f["col"]
		col.a = 1.0 - k * k
		ink(c, RETRO_UI.FONT_LABEL, at.floor(), str(f["text"]), col, Color(0, 0, 0, col.a), 8)


func _paint_knob(c: Control) -> void:
	if picture == null or absf(_knob) < 0.05:
		return
	# The handle over a patch of the wall beside it, pulled toward you or pushed back.
	c.draw_texture_rect_region(picture, KNOB, KNOB_PATCH)
	c.draw_set_transform(KNOB_PIVOT, -_knob * 0.3, Vector2(1.0, 1.0 - absf(_knob) * 0.12))
	c.draw_texture_rect_region(picture, Rect2(KNOB.position - KNOB_PIVOT, KNOB.size), KNOB)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_stream(c: Control) -> void:
	if _slide >= 0.0 or not (_pull or _push):
		return
	var top_y := _level_y(_beer + _foam)
	var y0 := SPOUT.y
	for y in range(int(y0), int(top_y)):
		var wob := int(sin(_t * 30.0 + y * 0.7) * 0.6)
		if _pull:
			c.draw_rect(Rect2(SPOUT.x - 1 + wob, y, 3, 1), Color(0.86, 0.6, 0.18, 0.95))
			c.draw_rect(Rect2(SPOUT.x + wob, y, 1, 1), Color(1.0, 0.84, 0.42))
		else:
			if (y + int(_t * 40.0)) % 3 != 0:
				c.draw_rect(Rect2(SPOUT.x + wob, y, 1, 1), Color(0.98, 0.95, 0.86))


func _paint_glass(c: Control, off: Vector2) -> void:
	var beer_y := _level_y(_beer)
	var top_y := _level_y(_beer + _foam)
	var h := G_BOTTOM - G_RIM
	for yi in range(int(G_RIM), int(G_BOTTOM)):
		var y := float(yi)
		var k := (G_BOTTOM - y) / h
		var w := lerpf(G_W_BOT, G_W_TOP, k)
		var x0 := G_X - w * 0.5
		var row := Rect2(x0 + off.x, y + off.y, w, 1)
		if y >= beer_y:
			# Beer: dark amber at the bottom, gold at the top, a dither between.
			var depth := clampf((y - beer_y) / maxf(1.0, G_BOTTOM - beer_y), 0.0, 1.0)
			var col := Color(0.95, 0.66, 0.16).lerp(Color(0.62, 0.32, 0.06), depth)
			c.draw_rect(row, col)
			for xi in range(int(w)):
				if (xi + yi) % 2 == 0 and xi % 3 == 0:
					c.draw_rect(Rect2(x0 + xi + off.x, y + off.y, 1, 1), col.lightened(0.12))
		elif y >= top_y - _foam_bump(0):
			# Foam, a bumpy top.
			var col2 := Color(0.97, 0.94, 0.84)
			for xi in range(int(w)):
				if y < top_y - _foam_bump(xi):
					continue
				var sp := (xi * 7 + yi * 13) % 11 == 0
				c.draw_rect(Rect2(x0 + xi + off.x, y + off.y, 1, 1), Color(0.84, 0.8, 0.7) if sp else col2)
		else:
			c.draw_rect(row, Color(0.62, 0.7, 0.74, 0.12))
		# The glass walls.
		c.draw_rect(Rect2(x0 - 1 + off.x, y + off.y, 1, 1), Color(0.78, 0.84, 0.88, 0.75))
		c.draw_rect(Rect2(x0 + w + off.x, y + off.y, 1, 1), Color(0.6, 0.66, 0.7, 0.6))
		if yi % 9 < 6:
			c.draw_rect(Rect2(x0 + 2 + off.x, y + off.y, 1, 1), Color(1, 1, 1, 0.22))
	# Rising bubbles in the beer.
	for b in _bubbles:
		var frac := fmod(b.y + _t * 0.18, 1.0)
		var by := G_BOTTOM - frac * (G_BOTTOM - beer_y)
		if by > beer_y + 1.0 and _beer > 0.05:
			var bw := lerpf(G_W_BOT, G_W_TOP, (G_BOTTOM - by) / h)
			c.draw_rect(Rect2(G_X + b.x * bw + off.x, by + off.y, 1, 1), Color(1.0, 0.9, 0.6, 0.8))
	# The rim, the thick base and the half-litre mark.
	c.draw_rect(Rect2(G_X - G_W_TOP * 0.5 - 1 + off.x, G_RIM - 1 + off.y, G_W_TOP + 2, 1), Color(0.86, 0.9, 0.92, 0.85))
	c.draw_rect(Rect2(G_X - G_W_BOT * 0.5 - 1 + off.x, G_BOTTOM + off.y, G_W_BOT + 2, 3), Color(0.7, 0.76, 0.8, 0.7))
	var ly := _level_y(LINE)
	var lw := lerpf(G_W_BOT, G_W_TOP, LINE)
	c.draw_rect(Rect2(G_X + 2 + off.x, ly + off.y, lw * 0.5 - 4, 1), Color(1, 1, 1, 0.7))
	c.draw_rect(Rect2(G_X + lw * 0.5 - 4 + off.x, ly - 2 + off.y, 1, 2), Color(1, 1, 1, 0.6))


func _paint_puddle(c: Control) -> void:
	if _puddle <= 0.01:
		return
	var rw := 30.0 + _puddle * 60.0
	var col := Color(0.82, 0.62, 0.22, 0.3 + _puddle * 0.4)
	for i in 4:
		var w := rw * (1.0 - float(i) * 0.18)
		c.draw_rect(Rect2(G_X - w * 0.5, G_BOTTOM + 2 + i, w, 1), col)


## The slips of the orders waiting, pinned on the left like a pad of chits.
func _paint_slips(c: Control) -> void:
	for i in _queue.size():
		var o: Dictionary = _queue[i]
		var text := "%s  %s" % [ORDERS.first_name(str((o["v"] as Dictionary)["name"])).to_upper(), str(o["pour"]).to_upper()]
		var tw := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(8, 132 + i * 15, ceilf(tw) + 7.0, 12)
		c.draw_rect(r, Color(0.88, 0.84, 0.72) if i == 0 else Color(0.74, 0.7, 0.6))
		c.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), Color(0, 0, 0, 0.5))
		ink(c, RETRO_UI.FONT_LABEL, Vector2(r.position.x + 3, r.position.y + 9), text, Color(0.12, 0.1, 0.12), Color(0, 0, 0, 0), 8)


func _level_y(frac: float) -> float:
	return G_BOTTOM - clampf(frac, 0.0, 1.0) * (G_BOTTOM - G_RIM)


func _foam_bump(xi: int) -> float:
	return round(sin(float(xi) * 0.9 + _t * 1.6) * 0.6 + sin(float(xi) * 0.37 + 1.3) * 0.8)
