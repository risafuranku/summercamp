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
const BUSINESS = preload("res://scripts/business/business_runtime.gd")
const GLASSES = preload("res://scripts/food/glass_wash_closeup.gd")
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
## The glass and what is in it are renders (closeup/parts/): the empty glass, the full
## glass of beer (cut off at the beer's level), the head of foam (stretched over the
## foam), the streams, a drip, the spill, the chits.
const PARTS := "res://assets/textury/closeup/parts/"
var _tex: Dictionary = {}


func _part(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(PARTS + key + ".png") if ResourceLoader.exists(PARTS + key + ".png") else null
	return _tex[key]

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
		if mb.pressed and hovered() == "tap" and _slide < 0.0 and BUSINESS.stock_of(building_key, "beer") == 0:
			# The keg is dry: a cough of air and foam, nothing else.
			play(SFX_TAP_OPEN, -6.0)
			say("", "The tap coughs and spits. The keg is empty: order beer at the desk.")
			get_viewport().set_input_as_handled()
			return
		var mugs: Dictionary = GLASSES.glasses(building_key)
		if mb.pressed and hovered() == "tap" and _slide < 0.0 and not mugs.is_empty() and int(mugs["clean"]) <= 0 and _beer + _foam <= 0.0:
			play(SFX_GLASS, -16.0)
			say("", "No clean mugs on the rack. %d dirty by the sink." % int(mugs["dirty"]))
			get_viewport().set_input_as_handled()
			return
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
	if not BUSINESS.sell(building_key, {"beer": 1}, price + tip):
		say("", "The keg ran dry under the glass. Order beer at the desk.")
		_slide = 0.0
		return
	var mugs2: Dictionary = GLASSES.glasses(building_key)
	if not mugs2.is_empty():
		mugs2["clean"] = maxi(0, int(mugs2["clean"]) - 1)
		mugs2["dirty"] = int(mugs2["dirty"]) + 1
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
		var drip := _part("foam_drip")
		if drip != null:
			c.draw_texture_rect(drip, Rect2(dx - 1.0 + off.x, dy - 5.0, 3, 6), false)
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
	var t := _part("pour_stream" if _pull else "foam_stream")
	if t == null or top_y <= SPOUT.y:
		return
	# A shiver in steps along the stream.
	var wob := roundf(sin(_t * 30.0) * 0.6)
	c.draw_texture_rect(t, Rect2(SPOUT.x - 2.0 + wob, SPOUT.y, 4.0 if _pull else 3.0, top_y - SPOUT.y), false)


## The glass's render placed over its glass on the painting: the foot on G_BOTTOM, the
## rim on G_RIM (the base's three pixels hang below).
func _glass_box(t: Texture2D, off: Vector2) -> Rect2:
	var h := G_BOTTOM - G_RIM + 3.0
	var w := float(t.get_width()) * h / float(t.get_height())
	return Rect2(G_X - w * 0.5 + off.x, G_RIM + off.y, w, h)


func _paint_glass(c: Control, off: Vector2) -> void:
	var glass := _part("tap_glass")
	var beer := _part("tap_beer")
	var foam := _part("tap_foam")
	var ref := glass if glass != null else beer
	if ref == null:
		return
	var box := _glass_box(ref, off)
	if glass != null:
		c.draw_texture_rect(glass, box, false)
	var beer_y := _level_y(_beer)
	var top_y := _level_y(_beer + _foam)
	# The beer: the full glass's render from the foot up to the level.
	if beer != null and _beer > 0.0:
		var hb := box.end.y - (beer_y + off.y)
		var src := float(beer.get_height()) * hb / box.size.y
		c.draw_texture_rect_region(beer, Rect2(box.position.x, beer_y + off.y, box.size.x, hb), Rect2(0, beer.get_height() - src, beer.get_width(), src))
	# The head: the foam's render over it, as wide as the glass is there.
	if foam != null and beer_y - top_y >= 1.0:
		var w := lerpf(G_W_BOT, G_W_TOP, (G_BOTTOM - top_y) / (G_BOTTOM - G_RIM)) - 2.0
		c.draw_texture_rect(foam, Rect2(G_X - w * 0.5 + off.x, top_y + off.y - 2.0, w, beer_y - top_y + 3.0), false)


func _paint_puddle(c: Control) -> void:
	var t := _part("spill")
	if _puddle <= 0.01 or t == null:
		return
	var rw := 30.0 + _puddle * 60.0
	c.draw_texture_rect(t, Rect2(G_X - rw * 0.5, G_BOTTOM - 1.0, rw, 8.0), false, Color(1, 1, 1, 0.4 + _puddle * 0.5))


## The slips of the orders waiting, pinned on the left like a pad of chits.
func _paint_slips(c: Control) -> void:
	var chit := _part("ticket")
	for i in _queue.size():
		var o: Dictionary = _queue[i]
		var text := "%s  %s" % [ORDERS.first_name(str((o["v"] as Dictionary)["name"])).to_upper(), str(o["pour"]).to_upper()]
		var tw := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(8, 132 + i * 15, ceilf(tw) + 11.0, 13)
		if chit != null:
			c.draw_texture_rect(chit, r, false, Color(1, 1, 1) if i == 0 else Color(0.8, 0.77, 0.7))
		ink(c, RETRO_UI.FONT_LABEL, Vector2(r.position.x + 5, r.position.y + 9), text, Color(0.12, 0.1, 0.12), Color(0, 0, 0, 0), 8)


func _level_y(frac: float) -> float:
	return G_BOTTOM - clampf(frac, 0.0, 1.0) * (G_BOTTOM - G_RIM)


func _foam_bump(xi: int) -> float:
	return round(sin(float(xi) * 0.9 + _t * 1.6) * 0.6 + sin(float(xi) * 0.37 + 1.3) * 0.8)
