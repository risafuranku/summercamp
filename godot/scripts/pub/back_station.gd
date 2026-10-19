extends "res://scripts/pub/pub_station.gd"

## The back bar (assets/textury/pub/st_back.png): the shelves of bottles behind, the bar
## top in front with the four that are poured from standing on it.
##   pick    click a bottle: it is in your hand, and its glass stands on the bar (a shot
##           glass, the tall one for the kofola)
##   pour    hold the button over the glass: the bottle tips and pours; let go at the
##           line (four centilitres; the kofola to its line). Over it runs down the
##           glass, under it is a rumour.
##   serve   click the glass: to the mat you picked, or to the oldest order for that
##           drink; the wrong drink comes back.
## Kofola and the spirits come off the books' shelves (rum for the three spirits).

const BOTTLES := {
	"rum": {"x": 196, "label": "Rum"},
	"zelena": {"x": 262, "label": "Zelena"},
	"slivovice": {"x": 328, "label": "Slivovice"},
	"kofola": {"x": 394, "label": "Kofola"},
}
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const BAR_Y := 300
const GLASS_FOOT := Vector2(540, 300)

var _bottle := ""
var _fill := 0.0
var _spill := 0.0
var _pouring := false
var _tip := 0.0
var _slide := -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	station = "back"
	room = "bar"
	picture = tex("st_back")
	_rng.randomize()
	for n in ["bottle_rum", "bottle_zelena", "bottle_slivovice", "bottle_kofola", "shot_empty", "shot_full", "tall_empty", "tall_kofola", "stream_beer", "puddle", "jigger"]:
		tex(n)


func _opened() -> void:
	_pouring = false
	if orders_here("bar").is_empty():
		say("", "Nobody wants a shot. The bottles watch you.")


func _closing() -> void:
	_pouring = false


func _tall() -> bool:
	return _bottle != "" and bool(PUB.DRINKS[_bottle].get("tall", false))


func _glass_name() -> String:
	return "tall_empty" if _tall() else "shot_empty"


func _glass_rect() -> Rect2:
	var t := tex(_glass_name())
	var sz := t.get_size() * float(PIX) if t != null else Vector2(32, 40)
	var foot := GLASS_FOOT
	if _slide >= 0.0:
		foot.x += _slide / 0.5 * 90.0
	return Rect2((foot - Vector2(sz.x * 0.5, sz.y)).floor(), sz)


func _bottle_rect(b: String) -> Rect2:
	var t := tex("bottle_" + b)
	var sz := t.get_size() * float(PIX) if t != null else Vector2(36, 110)
	return Rect2(Vector2(float(BOTTLES[b]["x"]) - sz.x * 0.5, BAR_Y - sz.y), sz)


func _spots() -> Array:
	var out: Array = []
	for b in BOTTLES:
		if b == _bottle:
			continue
		var stock := BUSINESS.stock_of(building_key, str(PUB.DRINKS[b]["good"]))
		out.append({"id": "bottle:" + b, "rect": _bottle_rect(b), "verb": ("Take the %s" % str(BOTTLES[b]["label"]).to_lower()) if stock != 0 else "The %s bottle is empty (order it in the books)" % str(BOTTLES[b]["label"]).to_lower()})
	if _bottle != "" and _slide < 0.0:
		var g := _glass_rect()
		# Over the glass: the bottle, tipped while you hold; the glass itself: served.
		out.append({"id": "pour", "rect": Rect2(g.position.x - 40, 70, g.size.x + 80, g.position.y - 76), "verb": "Hold to pour the %s" % PUB.label(_bottle).to_lower()})
		if _fill > 0.05:
			out.append({"id": "glass", "rect": g.grow(6.0), "verb": _glass_verb()})
	return out


func _glass_verb() -> String:
	var orders := _orders_for(_bottle)
	if orders.is_empty():
		return "Nobody ordered %s" % PUB.label(_bottle).to_lower()
	return "Give it to %s" % ORDERS_first(str(orders[0]["name"]))


## The orders for `drink`, the picked one first.
func _orders_for(drink: String) -> Array:
	var out: Array = []
	for t in orders_here("bar"):
		if str(t["drink"]) == drink or str(t["id"]) == picked:
			out.append(t)
	return out


func _press(id: String) -> void:
	if id.begins_with("bottle:"):
		var b := id.substr(7)
		if _fill > 0.02:
			say("", "Finish that glass first.")
			return
		_bottle = b
		_fill = 0.0
		_spill = 0.0
		sfx("glass_down", -12.0, 1.2)
		return
	if id == "pour":
		if BUSINESS.stock_of(building_key, str(PUB.DRINKS[_bottle]["good"])) == 0:
			say("", "The bottle is empty. Order more in the books.")
			return
		_pouring = true
		sfx("tap_pour", -12.0, 1.4 if not _tall() else 1.0)
	elif id == "glass":
		_serve()


func _release(id: String) -> void:
	if id == "pour":
		_pouring = false


func _tick(delta: float) -> void:
	_tip = move_toward(_tip, 1.0 if _pouring else 0.0, delta * 6.0)
	if _pouring and _tip > 0.7:
		_fill += (PUB.RATE_TALL if _tall() else PUB.RATE_SHOT) * delta
		if _fill > 1.0:
			_spill += _fill - 1.0
			_fill = 1.0
	if _slide >= 0.0:
		_slide += delta
		if _slide > 0.5:
			_slide = -1.0
			_bottle = ""
			_fill = 0.0
			_spill = 0.0


func _serve() -> void:
	var orders := _orders_for(_bottle)
	if orders.is_empty():
		say("", "Nobody ordered it. You knock it back yourself.")
		_slide = 0.0
		return
	var t: Dictionary = orders[0]
	var who := ORDERS_first(str(t["name"]))
	if str(t["drink"]) != _bottle:
		say(who, "That's not %s. That's %s." % [PUB.label(str(t["drink"])).to_lower(), PUB.label(_bottle).to_lower()])
		_slide = 0.0
		return
	var v := PUB.judge_glass(_bottle, _fill, _spill, int(t["age"]))
	if not bool(v["ok"]):
		say(who, "Is that a shot or a rumour? Fill it up." if not _tall() else "Half a kofola? Fill it up.")
		return
	var verdict: Dictionary = taproom.serve(building_key, t, v)
	if not bool(verdict.get("ok", false)):
		say("", "The bottle ran dry. Order more in the books.")
		return
	picked = ""
	_slide = 0.0
	sfx("coins_bar", -8.0)
	pop("+$%d" % int(verdict["amount"]), GLASS_FOOT + Vector2(0, -90), RETRO_UI.C_AMBER_LIGHT if int(verdict["tip"]) > 0 else RETRO_UI.C_BONE, true)
	if float(verdict["accuracy"]) >= 0.8:
		say(who, ["Na zdravi!", "Right to the line. Respect.", "Ahh. That burns properly."][_rng.randi() % 3] if not _tall() else "Proper kofola. Thanks.")
	elif _fill >= 1.0:
		say(who, "Swimming in it. Not complaining.")
	else:
		say(who, "Bit short. Cheers anyway.")


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	for b in BOTTLES:
		if b == _bottle:
			continue
		var r := _bottle_rect(b)
		stand(c, "bottle_" + str(b), Vector2(r.get_center().x, r.end.y))
		var lw := RETRO_UI.FONT_TEXT.get_string_size(str(BOTTLES[b]["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		ink(c, Vector2(r.get_center().x - lw * 0.5, BAR_Y + 12), str(BOTTLES[b]["label"]), RETRO_UI.C_BONE, RETRO_UI.FONT_TEXT)
	blit(c, "jigger", Vector2(120, BAR_Y - 14))
	if _bottle == "":
		return
	var g := _glass_rect()
	if _spill > 0.0:
		var pt := tex("puddle")
		if pt != null:
			var ps := pt.get_size() * float(PIX)
			c.draw_texture_rect(pt, Rect2(Vector2(g.get_center().x - ps.x * 0.5, g.end.y - ps.y * 0.6).floor(), ps), false, Color(1, 1, 1, minf(0.9, _spill * 6.0)))
	var tint: Color = SPIRIT_TINT.get(_bottle, Color(1, 1, 1))
	fill_to(c, "tall_kofola" if _tall() else "shot_full", Vector2(g.get_center().x, g.end.y), _fill * 0.92, tint)
	stand(c, _glass_name(), Vector2(g.get_center().x, g.end.y))
	# The line etched on the glass.
	var line := PUB.LINE_TALL if _tall() else PUB.LINE_SHOT
	var ly := floorf(g.end.y - g.size.y * 0.92 * line)
	c.draw_rect(Rect2(g.position.x + 4, ly, 6, 1), Color(1, 1, 1, 0.55))
	if _slide >= 0.0:
		return
	# The bottle in your hand over the glass, tipped as you pour; the stream from its neck.
	var bt := tex("bottle_" + _bottle)
	if bt == null:
		return
	var bs := bt.get_size() * float(PIX)
	var tipped := -2.1
	var neck := Vector2(g.get_center().x + 6.0, g.position.y - 10.0)
	var ang := lerpf(-0.25, tipped, _tip)
	var foot := neck - Vector2(0, -bs.y).rotated(ang)
	c.draw_set_transform(foot, ang, Vector2.ONE)
	c.draw_texture_rect(bt, Rect2(-bs.x * 0.5, -bs.y, bs.x, bs.y), false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _pouring and _tip > 0.7:
		var st := tex("stream_beer")
		if st != null:
			var surface := g.end.y - g.size.y * 0.92 * _fill
			var sw := st.get_width() * float(PIX) * 0.6
			c.draw_texture_rect(st, Rect2(neck.x - sw * 0.5, neck.y, sw, maxf(2.0, surface - neck.y)), true, Color(tint.r, tint.g, tint.b, 0.9))
