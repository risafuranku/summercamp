extends "res://scripts/closeup/closeup_view.gd"

## The pub's back bar, close up (assets/textury/closeup/pub_shots.png): the bottles and a
## row of glasses. Whoever is in the pub orders a shot (a rum, a zelena, a slivovice)
## or a kofola. Pick the right bottle, hold the button to tip it over the glass, let go
## at the line: four centilitres in a shot glass, half a litre of kofola in a tall one.
## Over the line and it runs down the glass (the landlord's money); under, and they
## look at you. A shot is a shot of the pub's spirits (its books), a kofola a glass of
## kofola.
## The bottle in your hand, the glasses (empty, and full: the pour is the full render
## cut off at the level), the stream and the spill are renders (closeup/parts/).

const ORDERS := preload("res://scripts/food/orders.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PIC := "res://assets/textury/closeup/pub_shots.png"
const SFX_POUR := "res://assets/sfx/pub/tap_pour.mp3"
const SFX_GLASS := "res://assets/sfx/pub/glass_down.mp3"
const SFX_COINS := "res://assets/sfx/pub/coins_bar.mp3"

## The bottles on the bar (picture px), what each pours.
const BOTTLES := {
	"rum": {"rect": Rect2(90, 20, 44, 128), "col": Color(0.55, 0.3, 0.1), "label": "Rum"},
	"zelena": {"rect": Rect2(152, 34, 44, 118), "col": Color(0.25, 0.55, 0.2), "label": "Zelena"},
	"slivovice": {"rect": Rect2(217, 34, 46, 118), "col": Color(0.92, 0.92, 0.85), "label": "Slivovice"},
	"kofola": {"rect": Rect2(280, 66, 30, 86), "col": Color(0.28, 0.12, 0.06), "label": "Kofola"},
}
const DRINKS := {
	"rum": {"price": 3, "good": "rum", "tall": false},
	"zelena": {"price": 3, "good": "rum", "tall": false},
	"slivovice": {"price": 4, "good": "rum", "tall": false},
	"kofola": {"price": 2, "good": "kofola", "tall": true},
}
const TASTE := {
	"drunk": {"rum": 3, "zelena": 2}, "tramp": {"zelena": 2, "slivovice": 1, "rum": 1},
	"quiet_guy": {"slivovice": 2, "kofola": 1}, "cheap_chick": {"kofola": 3, "zelena": 1},
	"picker": {"kofola": 2, "slivovice": 1}, "family": {"kofola": 3},
}
const GLASS_AT := Vector2(44, 228)
## Where the etched line is on each glass's render (share of its height from the foot).
const LINE_SHOT := 0.8
const LINE_TALL := 0.8
const PARTS := "res://assets/textury/closeup/parts/"
const RATE_SHOT := 0.55
const RATE_TALL := 0.32

var building_key := ""
var _queue: Array = []        # [{v, drink}]
var _bottle := ""             # the one in your hand ("" = none)
var _fill := 0.0
var _pouring := false
var _spill := 0.0
var _tip := 0.0               # the bottle's tilt, eased
var _next := 1.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _floaters: Array = []


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_rng.randomize()


func _opened() -> void:
	_bottle = ""
	_fill = 0.0
	_spill = 0.0
	_next = 0.6
	if ORDERS.visitors(building_key).is_empty():
		say("", "Nobody at the bar wants a shot.", false)


func _tall() -> bool:
	return _bottle != "" and bool(DRINKS[_bottle]["tall"])


var _tex: Dictionary = {}


func _line() -> float:
	return LINE_TALL if _tall() else LINE_SHOT


func _part(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(PARTS + key + ".png") if ResourceLoader.exists(PARTS + key + ".png") else null
	return _tex[key]


func _glass_rect() -> Rect2:
	return Rect2(GLASS_AT.x - 16, GLASS_AT.y - 76, 32, 76) if _tall() else Rect2(GLASS_AT.x - 12, GLASS_AT.y - 34, 24, 34)


func _hotspots() -> Array:
	var out: Array = []
	for b in BOTTLES:
		out.append({"id": "bottle:" + b, "rect": BOTTLES[b]["rect"]})
	if _bottle != "":
		out.append({"id": "glass", "rect": _glass_rect().grow(8)})
	return out


func _clicked(id: String) -> void:
	if id.begins_with("bottle:"):
		var b := id.substr(7)
		if _fill > 0.0 and b != _bottle:
			say("", "Finish that glass first.")
			return
		_bottle = b
		return
	if id == "glass" and _fill > 0.05:
		_serve()


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if visible and _closing_t < 0.0 and mb != null and mb.button_index == MOUSE_BUTTON_LEFT and _bottle != "":
		var over_glass := _glass_rect().grow(30).has_point(_mouse) or Rect2(GLASS_AT.x - 40, 40, 80, 160).has_point(_mouse)
		if mb.pressed and over_glass and not hovered().begins_with("bottle:"):
			var good := str(DRINKS[_bottle]["good"])
			if BUSINESS.stock_of(building_key, good) == 0:
				say("", "The bottle is empty. Order more at the desk.")
				get_viewport().set_input_as_handled()
				return
			_pouring = true
			play(SFX_POUR, -12.0)
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and _pouring:
			_pouring = false
			_audio.stop()
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _tick(delta: float) -> void:
	_t += delta
	_tip = move_toward(_tip, 1.0 if _pouring else 0.0, delta * 6.0)
	if _pouring and _tip > 0.7:
		_fill += (RATE_TALL if _tall() else RATE_SHOT) * delta
		if _fill > 1.0:
			_spill += _fill - 1.0
			_fill = 1.0
	for f in _floaters:
		f["t"] = float(f["t"]) + delta
	_floaters = _floaters.filter(func(f): return float(f["t"]) < 1.4)
	_next -= delta
	if _next <= 0.0:
		_next = 1.6
		_sync_queue()


func _sync_queue() -> void:
	var here := {}
	for v in ORDERS.visitors(building_key):
		here[str(v["visit"])] = v
	_queue = _queue.filter(func(o): return here.has(str((o["v"] as Dictionary)["visit"])))
	if not _queue.is_empty():
		return
	for k in here:
		var v: Dictionary = here[k]
		if ORDERS.left_for(v, "pub") <= 0:
			continue
		var taste: Dictionary = TASTE.get(str(v["archetype"]), {"kofola": 1})
		var total := 0
		for d in taste:
			total += int(taste[d])
		var r := _rng.randi() % maxi(1, total)
		var pick := "kofola"
		for d in taste:
			r -= int(taste[d])
			if r < 0:
				pick = d
				break
		_queue.append({"v": v, "drink": pick})
		var asks := {"rum": ["A rum. A big one. Fine, a normal one.", "Rum, please."], "zelena": ["A zelena!", "One green, boss."], "slivovice": ["Slivovice. The good bottle.", "A slivovice for my nerves."], "kofola": ["A kofola, please.", "Kofola for the little one."]}
		var lines: Array = asks[pick]
		say(ORDERS.first_name(str(v["name"])), str(lines[_rng.randi() % lines.size()]))
		return


func _serve() -> void:
	if _queue.is_empty():
		say("", "Nobody ordered it. You knock it back yourself.")
		_reset_glass()
		return
	var o: Dictionary = _queue[0]
	var v: Dictionary = o["v"]
	var who := ORDERS.first_name(str(v["name"]))
	if str(o["drink"]) != _bottle:
		say(who, "That's not %s. That's %s." % [str(BOTTLES[o["drink"]]["label"]).to_lower(), str(BOTTLES[_bottle]["label"]).to_lower()])
		ORDERS.mood(int(v["id"]), -0.5, "")
		_reset_glass()
		return
	var err := absf(_fill - _line())
	var q := clampf(1.0 - err / 0.18 - _spill * 4.0, 0.0, 1.0)
	if _fill < _line() - 0.25:
		say(who, "Is that a shot or a rumour? Fill it up.")
		return
	var d: Dictionary = DRINKS[_bottle]
	var tip := 1 if q >= 0.8 else 0
	if not BUSINESS.sell(building_key, {str(d["good"]): 1}, int(d["price"]) + tip):
		say("", "The bottle ran dry. Order more at the desk.")
		_reset_glass()
		return
	ORDERS.note_served(v)
	_queue.pop_front()
	play(SFX_COINS, -8.0)
	_floaters.append({"text": "+$%d" % (int(d["price"]) + tip), "at": Vector2(40, 120), "t": 0.0, "col": RETRO_UI.C_AMBER_LIGHT if tip > 0 else RETRO_UI.C_BONE})
	if q >= 0.8:
		say(who, ["Na zdravi!", "Right to the line. Respect.", "Ahh. That burns properly."][_rng.randi() % 3])
		ORDERS.mood(int(v["id"]), 1.5, "The barman at the camp pours honest shots.")
	elif _fill >= 1.0:
		say(who, "Swimming in it. Not complaining.")
	else:
		say(who, "Bit short. Cheers anyway.")
	_reset_glass()
	_next = 1.2


func _reset_glass() -> void:
	_fill = 0.0
	_spill = 0.0
	_bottle = ""
	play(SFX_GLASS, -12.0)


func _paint(c: Control) -> void:
	# The kofola is not on the painting: its bottle stands at the end of the bar.
	var kt := _part("bottle_kofola")
	if kt != null:
		var kr: Rect2 = BOTTLES["kofola"]["rect"]
		var ks := Vector2(kt.get_size()) * (kr.size.y / float(kt.get_height()))
		c.draw_texture_rect(kt, Rect2(Vector2(kr.get_center().x - ks.x * 0.5, kr.end.y - ks.y), ks), false)
	# The labels under the bottles.
	for b in BOTTLES:
		var r: Rect2 = BOTTLES[b]["rect"]
		ink(c, RETRO_UI.FONT_TEXT, Vector2(r.position.x, r.end.y + 9), str(BOTTLES[b]["label"]), RETRO_UI.C_BONE if b != _bottle else RETRO_UI.C_AMBER_LIGHT, Color(0, 0, 0, 0.9))
		if hovered() == "bottle:" + b:
			c.draw_rect(r, Color(1, 0.92, 0.6, 0.15))
	if _bottle == "":
		return
	# The glass; what is in it is the full glass's render, cut off at the level.
	var g := _glass_rect()
	var col: Color = BOTTLES[_bottle]["col"]
	var tint := col.lightened(0.45)
	var spill := _part("spill")
	if _spill > 0.0 and spill != null:
		c.draw_texture_rect(spill, Rect2(g.position.x - 10, g.end.y - 6, g.size.x + 20, 10), false, Color(tint.r, tint.g, tint.b, minf(0.9, _spill * 6.0)))
	var empty := _part("glass_tall" if _tall() else "glass_shot")
	if empty != null:
		c.draw_texture_rect(empty, g, false)
	var full := _part("glass_" + _bottle)
	var h := g.size.y * clampf(_fill, 0.0, 1.0)
	if full != null and h >= 1.0:
		var src_h := float(full.get_height()) * h / g.size.y
		c.draw_texture_rect_region(full, Rect2(g.position.x, g.end.y - h, g.size.x, h), Rect2(0, full.get_height() - src_h, full.get_width(), src_h))
	# The bottle in your hand, tipping over the glass, the stream when it pours.
	var neck := Vector2(g.get_center().x + 12, g.position.y - 18)
	var bt := _part("bottle_" + _bottle)
	if bt != null:
		var bs := Vector2(bt.get_size()) * (74.0 / float(bt.get_height()))
		c.draw_set_transform(neck, lerpf(-0.2, -2.1, _tip), Vector2.ONE)
		c.draw_texture_rect(bt, Rect2(-bs.x * 0.5, -bs.y, bs.x, bs.y), false)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var stream := _part("pour_stream")
	if _pouring and _tip > 0.7 and stream != null:
		var top := neck.y + 4
		c.draw_texture_rect(stream, Rect2(g.get_center().x - 3, top, 6, maxf(1.0, g.end.y - h - top)), false, tint)
	if not _queue.is_empty():
		var o: Dictionary = _queue[0]
		ink(c, RETRO_UI.FONT_LABEL, Vector2(12, 24), "%s: %s" % [ORDERS.first_name(str((o["v"] as Dictionary)["name"])).to_upper(), str(BOTTLES[o["drink"]]["label"]).to_upper()], RETRO_UI.C_AMBER, Color(0, 0, 0, 0.9))
	for f in _floaters:
		var a := 1.0 - float(f["t"]) / 1.4
		ink(c, RETRO_UI.FONT_BIG, f["at"] - Vector2(0, float(f["t"]) * 18.0), str(f["text"]), Color(f["col"].r, f["col"].g, f["col"].b, a), Color(0, 0, 0, a), 10)
