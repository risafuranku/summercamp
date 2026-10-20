extends "res://scripts/corn/corn_station.gd"

## The drinks at the corn stand (the brief of 20. 10.: "a small cheap drink: lemonade in
## a bag with a straw, or iced tea from the barrel into a cup"), worked on the little table
## at the stand's end (scripts/corn/stand_layout.gd "drinks", its Build picture
## corn/st_drinks.png): the stack of cups, the drip grate, the tray of bags and straws;
## standing on it the orange barrel of iced tea with its tap and the big bottle of
## raspberry lemonade. Things are sprites at the room's pixel.
##   the cups    a click: a cup onto the grate under the barrel's tap
##   the tap     hold: the tea runs into the cup (its column: the green window is right;
##               over the top it runs onto the grate)
##   the bags    a click: an empty bag onto the table
##   the bottle  hold: it tips and the lemonade runs into the bag, to the line
##   the straws  a click on the filled bag: tied round a straw
##   the drink   a click: over the counter to the picked drink slip (else the oldest);
##               the wrong drink, half a cup or an open bag and they hand it back
##   BIN         (the frame) what is on the table into the bin

const DRINK_TEX := "res://assets/textury/corn/"
## On the table (design px across its picture, stand_layout.SURFACES "drinks").
const CUPS := Rect2(8, 60, 96, 150)
const GRATE_AT := Vector2(214, 236)
const BARREL_AT := Vector2(214, 132)
const TAP := Rect2(160, 40, 110, 170)
const BAG_AT := Vector2(452, 244)
const BOTTLE_AT := Vector2(458, 120)
const BOTTLE := Rect2(410, 30, 96, 170)
const BAGS := Rect2(530, 150, 104, 150)
const STRAWS := Rect2(536, 40, 96, 100)
const HAND := Rect2(120, 0, 400, 40)
const CUP_M := 0.1
const BAG_M := 0.16

## What is on the table: {kind: tea|limo, fill, tied, spilt} ({} none).
var _drink: Dictionary = {}
var _pouring := false
var _barrel: Sprite3D
var _bottle: Sprite3D
var _cup_empty: Sprite3D
var _cup_full: Sprite3D
var _bag_empty: Sprite3D
var _bag_full: Sprite3D
var _stream: Sprite3D
var _fill: Sprite3D
var _rng := RandomNumberGenerator.new()
## Opens the books (set by the stand's view).
var open_books: Callable


func _build() -> void:
	super._build()
	_rng.randomize()
	for n in ["tea", "limo"]:
		var p := MARKS + "mark_%s.png" % n
		_icons[n] = load(p) if ResourceLoader.exists(p) else null
	_barrel = _stand("drink_barrel", 0.3)
	put(_barrel, BARREL_AT, 0.0)
	_bottle = _stand("drink_bottle", 0.26)
	put(_bottle, BOTTLE_AT, 0.0)
	_cup_empty = _stand("cup_empty", CUP_M)
	_cup_full = _stand("cup_tea", CUP_M)
	_cup_full.region_enabled = true
	_bag_empty = _stand("bag_empty", BAG_M)
	_bag_full = _stand("bag_limo", BAG_M)
	_bag_full.region_enabled = true
	_stream = _stand("stream_tea", 0.12)
	_fill = meter(5, 18)
	for s in [_cup_empty, _cup_full, _bag_empty, _bag_full, _stream, _fill]:
		(s as Node3D).visible = false


## A thing standing on the table on its foot, facing you.
func _stand(name: String, metres: float) -> Sprite3D:
	var s := sprite(DRINK_TEX + name + ".png", metres, false)
	if s.texture != null:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)
	return s


func serves() -> String:
	return "drink"


# ── what the state looks like ────────────────────────────────────────────────

func _show() -> void:
	var on := not _drink.is_empty()
	var tea := on and str(_drink["kind"]) == "tea"
	var limo := on and str(_drink["kind"]) == "limo"
	var fill := clampf(float(_drink.get("fill", 0.0)), 0.0, 1.0)
	_cup_empty.visible = tea
	_cup_full.visible = tea and fill > 0.02
	_bag_empty.visible = limo and fill < 0.3
	_bag_full.visible = limo and (fill >= 0.3)
	if tea:
		put(_cup_empty, GRATE_AT, 0.006)
		_fill_region(_cup_full, fill, GRATE_AT)
	if limo:
		put(_bag_empty, BAG_AT, 0.004)
		_fill_region(_bag_full, fill if not bool(_drink["tied"]) else 1.0, BAG_AT)
	# The tea or the lemonade running while the tap is held or the bottle tipped.
	_stream.visible = _pouring and on
	if _stream.visible:
		retex(_stream, DRINK_TEX + ("stream_tea" if tea else "stream_limo") + ".png", 0.12)
		put(_stream, (GRATE_AT if tea else BAG_AT) + Vector2(0, -6), 0.11 if tea else 0.17)
		_stream.position.z -= 0.004
	# The bottle tips over the bag while it pours (its picture lies over, never turned:
	# it moves to the bag's mouth).
	put(_bottle, BOTTLE_AT if not (_pouring and limo) else BAG_AT + Vector2(-20, -30), 0.0 if not (_pouring and limo) else 0.12)
	_fill.visible = on and not bool(_drink.get("tied", false))
	if _fill.visible:
		var at := (GRATE_AT if tea else BAG_AT) + Vector2(46, 0)
		put(_fill, at, 0.0)
		var col: Color = RETRO_UI.C_RED if fill > CORN.FILL_OK.y else RETRO_UI.C_AMBER
		set_meter(_fill, fill, CORN.FILL_OK, col, fill > 1.0 - 0.001)


## The full picture shown from its foot up to `fill` (the cup filling, the bag swelling).
func _fill_region(s: Sprite3D, fill: float, at: Vector2) -> void:
	var tex := s.texture
	if tex == null:
		return
	var h := float(tex.get_height())
	var shown := maxf(1.0, ceilf(h * fill))
	s.region_rect = Rect2(0, h - shown, tex.get_width(), shown)
	s.offset = Vector2(0, shown * 0.5)
	put(s, at, 0.0)
	s.position.z += 0.003


# ── what can be used ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if _drink.is_empty():
		var tea := maxi(0, BUSINESS.stock_of(building_key, "tea"))
		var limo := maxi(0, BUSINESS.stock_of(building_key, "limo"))
		out.append({"id": "cups", "rect": CUPS, "verb": "A cup under the tap (%d of tea)" % tea if tea > 0 else "The barrel is dry: order iced tea in the books"})
		out.append({"id": "bags", "rect": BAGS, "verb": "A bag for lemonade (%d)" % limo if limo > 0 else "No lemonade: order it in the books"})
	else:
		var kind := str(_drink["kind"])
		var fill := float(_drink["fill"])
		if kind == "tea":
			out.append({"id": "tap", "node": _barrel, "verb": "Hold to run the tea in" if fill < CORN.FILL_OK.x else "Full to the line"})
		else:
			if not bool(_drink["tied"]):
				out.append({"id": "bottle", "node": _bottle, "verb": "Hold to pour the lemonade in" if fill < CORN.FILL_OK.x else "Full to the line"})
				if fill >= 0.5:
					out.append({"id": "straws", "rect": STRAWS, "verb": "Tie it round a straw"})
		var t := current_ticket()
		var verb := "Over the counter"
		if not t.is_empty():
			verb = "Over the counter to %s" % first_name(str(t["name"]))
		var node: Sprite3D = (_cup_full if _cup_full.visible else _cup_empty) if kind == "tea" else (_bag_full if _bag_full.visible else _bag_empty)
		out.append({"id": "drink", "node": node, "verb": verb})
		out.append({"id": "hand", "rect": HAND, "verb": verb})
	return out


func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	match id:
		"tap", "cups":
			return "cup"
		"drink":
			return "cup" if str(_drink.get("kind", "")) == "tea" else "open"
		"bottle", "bags", "straws", "hand":
			return "open"
	return "open"


func _press(id: String) -> void:
	match id:
		"cups":
			_new("tea")
		"bags":
			_new("limo")
		"tap", "bottle":
			_pouring = true
			sfx("tea_pour" if id == "tap" else "pour", -10.0, _rng.randf_range(0.95, 1.05))
		"straws":
			if not _drink.is_empty() and float(_drink["fill"]) >= 0.5:
				_drink["tied"] = true
				sfx("bag_tie", -8.0)
		"drink", "hand":
			_hand_over()


func _release(_id: String) -> void:
	_pouring = false


func _new(kind: String) -> void:
	if BUSINESS.stock_of(building_key, kind) == 0:
		say("", "The barrel is dry." if kind == "tea" else "No lemonade left.")
		sfx("tick", -14.0, 0.7)
		return
	_drink = {"kind": kind, "fill": 0.0, "tied": false}
	sfx("plate_down", -14.0, 1.5)


func _tick(delta: float) -> void:
	if not _pouring or _drink.is_empty():
		return
	var rate := float(CORN.DRINKS[str(_drink["kind"])]["rate"])
	var was := float(_drink["fill"])
	_drink["fill"] = minf(1.08, was + rate * delta)
	if was <= 1.0 and float(_drink["fill"]) > 1.0:
		say("", "It runs over the top.")


func _hand_over() -> void:
	if _drink.is_empty():
		return
	var t := current_ticket()
	if t.is_empty():
		say("", "Nobody asked for a drink.")
		return
	var who := first_name(str(t["name"]))
	var v: Dictionary = stand.serve_drink(building_key, t, str(_drink["kind"]), float(_drink["fill"]), bool(_drink["tied"]))
	if not bool(v.get("ok", false)):
		if str(v.get("why", "")) == "empty":
			say("", "Nothing left to pour.")
			return
		say(who, " ".join(v.get("notes", [])))
		score_card(v, str(CORN.DRINKS[str(_drink["kind"])]["label"]))
		# A wrong drink stays on the table for whoever wanted it; an open bag or a short
		# cup the guest hands back as it is.
		return
	picked = ""
	_drink = {}
	sfx("till", -10.0, 1.2)
	pop("+$%d" % int(v["amount"]), HAND.get_center() + Vector2(0, 40), RETRO_UI.C_AMBER_LIGHT if int(v["tip"]) > 0 else RETRO_UI.C_BONE)
	score_card(v, str(CORN.DRINKS[str(t["kind"])]["label"]))
	if not (v.get("notes", []) as Array).is_empty():
		say(who, " ".join(v["notes"]))
	else:
		say(who, ["Lovely and cold.", "Cheers.", "That hits the spot."][_rng.randi() % 3])


func bar_buttons() -> Array:
	var out: Array = [{"id": "books", "label": "BOOKS"}]
	if not _drink.is_empty():
		out.push_front({"id": "bin", "label": "BIN"})
	return out


func bar_button(id: String) -> void:
	match id:
		"bin":
			_drink = {}
			_pouring = false
			sfx("scrape", -10.0)
		"books":
			if open_books.is_valid():
				open_books.call()


func _closing() -> void:
	_pouring = false


## A drink slip: the cup or the bag it wants, TIE for the bag; the fill against the line.
func draw_big_ticket(c: Control, r: Rect2, t: Dictionary) -> void:
	var paper: Texture2D = _icons.get("ticket")
	if paper != null:
		c.draw_texture_rect(paper, r, false)
	else:
		c.draw_rect(r, Color(0.92, 0.88, 0.76))
	var x := r.position.x + 7
	var y := r.position.y + 18
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, y), first_name(str(t["name"])).substr(0, 9).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.1, 0.08))
	var kind := str(t.get("kind", "tea"))
	var ic: Texture2D = _icons.get(kind)
	if ic != null:
		c.draw_texture_rect(ic, Rect2(Vector2(r.end.x - ic.get_width() * 2 - 6, r.position.y + 6), ic.get_size() * 2.0), false)
	var ink := Color(0.16, 0.12, 0.1)
	var ok := Color(0.1, 0.45, 0.12)
	var bad := Color(0.62, 0.08, 0.05)
	y += 26
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), "ICED TEA" if kind == "tea" else "LEMONADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	var on := not _drink.is_empty() and str(_drink["kind"]) == kind
	var fill := float(_drink.get("fill", 0.0)) if on else 0.0
	y += 13
	var fcol := ink
	if on:
		fcol = ok if fill >= CORN.FILL_OK.x and fill <= CORN.FILL_OK.y else (bad if fill > CORN.FILL_OK.y else ink)
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), "TO THE LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, fcol)
	if kind == "limo":
		y += 13
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), "STRAW, TIED", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ok if on and bool(_drink["tied"]) else ink)
	var band := CORN.patience_band(int(t.get("age", 0)))
	var bar := Rect2(r.position.x + 6, r.end.y - 8, r.size.x - 12, 4)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * (1.0 - clampf(float(t.get("age", 0)) / float(CORN.PATIENCE_GONE), 0.0, 1.0))), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band])


## The barrel and the lemonade, for the frame's bar.
func bar_text() -> String:
	if building_key == "":
		return ""
	return "TEA %d  LEMONADE %d" % [maxi(0, BUSINESS.stock_of(building_key, "tea")), maxi(0, BUSINESS.stock_of(building_key, "limo"))]


# ── debug (tools/stand_check.gd, tools/stand_shots.gd) ───────────────────────

func debug_click(id: String) -> void:
	_press(id)
	_release(id)


## Pours for `seconds` as if the tap or the bottle were held.
func debug_pour(seconds: float) -> void:
	if _drink.is_empty():
		return
	_pouring = true
	var left := seconds
	while left > 0.0:
		_tick(minf(0.05, left))
		left -= 0.05
	_pouring = false


## Holds the pour on (for a picture of it running) or lets go.
func debug_hold(on: bool) -> void:
	_pouring = on


## The drink on the table made as the oldest drink slip wants.
func debug_make_right() -> void:
	var t := current_ticket()
	if t.is_empty():
		return
	_drink = {"kind": str(t["kind"]), "fill": 0.9, "tied": true}
