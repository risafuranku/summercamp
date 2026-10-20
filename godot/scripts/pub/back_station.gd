extends "res://scripts/pub/pub_station.gd"

## The bottles (DESIGN.md §7b "the pub"), worked at the left end of the bar top in the
## room: the rum, the zelena, the slivovice and the kofola standing in a row, the glass in
## front of them on the barman's side. Things are sprites at the room's pixel.
##   take a bottle (a click): it comes over the glass, and the glass is the one for it (a
##   shot glass, the tall glass for the kofola); hold the button on it: it tips and pours,
##   the glass fills; to the line, not over it (the column by the glass, its green
##   window). Then the glass: over the bar to whoever ordered it.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const BOTTLES := ["rum", "zelena", "slivovice", "kofola"]
## On the bar top (design px, pub_layout.SURFACES: 2.5 mm a px): the bottles in a row on
## the guests' side of the barman's half, the glass in front of them.
const FOOT_Y := 168.0
const BOTTLE_X := [244.0, 292.0, 340.0, 388.0]
const GLASS_AT := Vector2(196, 204)
const LIFT := 0.0
const BOTTLE_M := 0.3

var _bottle := ""
var _fill := 0.0
var _spill := 0.0
var _pouring := false
var _tip := 0.0
var _slide := -1.0
var _rng := RandomNumberGenerator.new()
var _bottles: Dictionary = {}
var _glass: Sprite3D
var _glass_fill: Sprite3D
var _stream: Sprite3D
var _line: Sprite3D


func _build() -> void:
	super._build()
	_rng.randomize()
	for i in BOTTLES.size():
		var b: String = BOTTLES[i]
		var s := psprite("bottle_" + b, BOTTLE_M * (0.86 if b == "kofola" else 1.0))
		put(s, Vector2(BOTTLE_X[i], FOOT_Y), LIFT)
		_bottles[b] = s
	_glass = psprite("shot_empty", 0.08)
	_glass_fill = psprite("shot_full", 0.08)
	_glass_fill.region_enabled = true
	_stream = psprite("stream_beer", 0.2)
	_stream.region_enabled = true
	_line = meter(5, 18)
	_line.position = local_at(GLASS_AT + Vector2(-34, 0), 0.1)


func _tall() -> bool:
	return _bottle != "" and bool(PUB.DRINKS[_bottle].get("tall", false))


func _glass_m() -> float:
	return 0.17 if _tall() else 0.08


# ── what the state looks like ────────────────────────────────────────────────

func _show() -> void:
	if taproom == null:
		return
	for i in BOTTLES.size():
		var b: String = BOTTLES[i]
		var s: Sprite3D = _bottles[b]
		var stock := BUSINESS.stock_of(building_key, str(PUB.DRINKS[b]["good"]))
		s.modulate = Color(1, 1, 1) if stock != 0 else Color(0.5, 0.5, 0.5)
		if b == _bottle and _slide < 0.0:
			# Up in the hand beside the glass, tipping over it as it pours (in steps): its
			# mouth just over the rim, the bottle turning about its foot.
			var a := floorf(_tip * 4.0) / 4.0 * 1.75
			var l := BOTTLE_M * (0.86 if b == "kofola" else 1.0) * 0.94
			var mouth_up := _glass_m() + 0.035
			s.rotation.z = a
			put(s, GLASS_AT + Vector2(6.0 + l * sin(a) / metres_x(1.0), 0.0), maxf(0.1, mouth_up - l * cos(a)))
		else:
			s.rotation.z = 0.0
			put(s, Vector2(BOTTLE_X[i], FOOT_Y), LIFT)
	var has_glass := _bottle != ""
	_glass.visible = has_glass
	_glass_fill.visible = has_glass and _fill > 0.01
	_line.visible = has_glass and _slide < 0.0 and is_open()
	_stream.visible = has_glass and _tip > 0.7 and _slide < 0.0
	if not has_glass:
		return
	var foot := GLASS_AT
	if _slide >= 0.0:
		# Over the bar to them: away across the top, in steps.
		foot.y -= floorf(_slide / 0.5 * 6.0) / 6.0 * 200.0
	pretex(_glass, "glass_tall" if _tall() else "shot_empty", _glass_m())
	put(_glass, foot, LIFT)
	pretex(_glass_fill, "glass_kofola" if _tall() else "shot_full", _glass_m())
	var tex := _glass_fill.texture
	if tex != null:
		var H := float(tex.get_height())
		var h := maxf(1.0, floorf(H * clampf(_fill, 0.0, 1.0) * 0.9))
		_glass_fill.region_rect = Rect2(0, H - h, tex.get_width(), h)
		_glass_fill.offset = Vector2(0, h * 0.5)
		put(_glass_fill, foot, LIFT)
		_glass_fill.position.z += 0.003
		var line := PUB.LINE_TALL if _tall() else PUB.LINE_SHOT
		set_meter(_line, _fill, Vector2(line - 0.06, line + 0.06), RETRO_UI.C_AMBER if _fill < line + 0.06 else RETRO_UI.C_RED)
	if _stream.visible:
		pretex(_stream, "stream_beer", 0.2)
		var t2 := _stream.texture
		if t2 != null:
			# From the bottle's mouth over the rim down to what is in the glass.
			var len_px := floorf(maxf(0.02, _glass_m() + 0.035 - _glass_m() * _fill * 0.9) / _stream.pixel_size)
			_stream.region_rect = Rect2(0, 0, t2.get_width(), minf(len_px, t2.get_height()))
			_stream.offset = Vector2(0, minf(len_px, t2.get_height()) * 0.5)
			_stream.modulate = Color(0.3, 0.18, 0.1) if _bottle == "kofola" else SPIRIT_TINT.get(_bottle, Color(1, 1, 1))
			put(_stream, foot + Vector2(4, 0), LIFT + 0.01)
			_stream.position.y += _glass_m() * _fill * 0.9


# ── what can be used ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	for b in BOTTLES:
		var stock := BUSINESS.stock_of(building_key, str(PUB.DRINKS[b]["good"]))
		if b == _bottle:
			if _slide < 0.0 and stock != 0:
				out.append({"id": "pour", "node": _bottles[b], "verb": "Hold to pour the %s" % PUB.label(b).to_lower()})
			continue
		if stock != 0:
			out.append({"id": "bottle:" + b, "node": _bottles[b], "verb": "Take the %s" % PUB.label(b).to_lower()})
	if _bottle != "" and _slide < 0.0 and _fill > 0.05:
		out.append({"id": "glass", "node": _glass, "verb": _glass_verb()})
	return out


func _glass_verb() -> String:
	var orders := _orders_for(_bottle)
	if orders.is_empty():
		return "Nobody ordered %s" % PUB.label(_bottle).to_lower()
	return "Over the bar to %s" % ORDERS_first(str(orders[0]["name"]))


func _orders_for(drink: String) -> Array:
	var out: Array = []
	for t in orders_here("bar"):
		if str(t["drink"]) == drink or str(t["id"]) == picked:
			out.append(t)
	return out


func _press(id: String) -> void:
	if id.begins_with("bottle:"):
		if _fill > 0.02:
			say("", "There is a glass half poured already.")
			return
		_bottle = id.substr(7)
		_fill = 0.0
		_spill = 0.0
		sfx("glass_down", -12.0, 1.2)
		return
	match id:
		"pour":
			_pouring = true
			sfx("tap_pour", -12.0, 1.4 if not _tall() else 1.0)
		"glass":
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
		say(who, ["Fill it up, you miser.", "Half a shot? Come on."][_rng.randi() % 2])
		sfx("glass_down", -12.0, 0.8)
		return
	var verdict: Dictionary = taproom.serve(building_key, t, v)
	if not bool(verdict.get("ok", false)):
		say("", "The bottle is empty.")
		return
	picked = ""
	_slide = 0.0
	sfx("coins_bar", -8.0)
	pop("+$%d" % int(verdict["amount"]), GLASS_AT + Vector2(0, -120), RETRO_UI.C_AMBER_LIGHT if int(verdict["tip"]) > 0 else RETRO_UI.C_BONE, true)
	say(who, ["Na zdravi.", "Cheers.", "Another in a bit."][_rng.randi() % 3] if int(verdict["stars"]) >= 2 else "Hm.")


func _closing() -> void:
	_pouring = false
	_tip = 0.0
	if _slide >= 0.0:
		_slide = -1.0
		_bottle = ""
		_fill = 0.0
		_spill = 0.0


## The bottle in the hand once taken (tipped while it pours), the bare glove else.
func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	if id == "pour" or id.begins_with("bottle:"):
		return "bottle"
	return "open"

# ── debug (tools/pub_check.gd, tools/pub_shots.gd) ───────────────────────────

func debug_pour(bottle: String, fill: float) -> void:
	_bottle = bottle
	_fill = fill
	_spill = 0.0


func debug_click(id: String) -> void:
	_press(id)
