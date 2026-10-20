extends "res://scripts/jednota/jednota_station.gd"

## The deli counter (the brief of 20. 10.: "salami, cheese, bread: cut it, weigh it on the
## scale, wrap it in paper, the price by the weight"), the counter's far end by the till
## (jednota_layout SURFACES "deli", its Build picture st_deli: the board, the scale, the
## roll of paper). The order on the rail: who, what, how many deka (ten grams).
##   the board   with the piece of what they asked for on it: a click with the knife cuts a
##               slice onto the scale (each a little thicker or thinner: you stop when the
##               scale says enough); a slice off the scale with a click on it
##   the scale   its window says the weight in grams
##   the paper   a click wraps what is on the scale
##   the parcel  a click: over the counter; short and they want more, over and they take
##               it but it counts against you. It goes in their basket, paid at the till.

## Where the Build picture (jednota/st_deli.png) has them: the board, the scale with its
## plate at the back and its dial in front, the roll of paper. The grams lie at the plate's
## back edge: the hand at the plate hangs below the pointer and would hide the dial.
const BOARD := Rect2(24, 117, 192, 215)
const BOARD_AT := Vector2(120, 224)
const SCALE := Rect2(234, 15, 170, 320)
const PLATE_AT := Vector2(318, 92)
const DISPLAY_AT := Vector2(318, 24)
const PAPER := Rect2(418, 100, 210, 196)
const PIECE_M := {"salami": 0.36, "cheese": 0.2, "bread": 0.26}
const SLICES_M := {"salami": 0.08, "cheese": 0.1, "bread": 0.16}
const PIECE_TEX := {"salami": "deli_salami", "cheese": "deli_cheese", "bread": "deli_bread"}
const SLICE_TEX := {"salami": "deli_salami_slices", "cheese": "deli_cheese_slices", "bread": "deli_bread_half"}

## The order picked on the rail (the parcel goes to them).
static var picked := ""

## What is on the scale: {good, grams: [each slice], wrapped} ({} nothing).
var _on: Dictionary = {}
var _piece: Sprite3D
var _pile: Array = []
var _parcel: Sprite3D
var _display: Label3D
var _rng := RandomNumberGenerator.new()


func has_rail() -> bool:
	return true


func _build() -> void:
	super._build()
	_rng.randomize()
	_piece = jsprite("deli_salami", 0.36, true)
	put(_piece, BOARD_AT, 0.012)
	for i in 8:
		var s := jsprite("deli_salami_slices", 0.08, true)
		s.visible = false
		_pile.append(s)
	_parcel = jsprite("parcel", 0.16, true)
	_parcel.visible = false
	_display = Label3D.new()
	_display.font = RETRO_UI.FONT_BIG
	_display.font_size = 10
	_display.pixel_size = 0.5 / PX_PER_M
	_display.shaded = false
	_display.double_sided = true
	_display.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_display.modulate = Color(1.0, 0.6, 0.3)
	_display.outline_size = 0
	_display.rotation_degrees.x = -90.0
	_display.position = local_at(DISPLAY_AT, 0.02)
	add_child(_display)


# ── the orders ───────────────────────────────────────────────────────────────

func tickets() -> Array:
	return shop.deli_tickets(building_key) if shop != null and building_key != "" else []


func rail_tickets() -> Array:
	var out: Array = []
	for t in tickets():
		var d: Dictionary = (t as Dictionary).duplicate()
		var age := int(t.get("age", 0))
		d["band"] = 0 if age < RULES.DELI_WAIT / 2 else (1 if age < RULES.DELI_WAIT - 5 else 2)
		d["left"] = 1.0 - clampf(float(age) / float(RULES.DELI_WAIT), 0.0, 1.0)
		d["sig"] = str(int(float(d["left"]) * 12.0))
		out.append(d)
	return out


func picked_ticket() -> String:
	return picked


func rail_clicked(id: String) -> void:
	picked = "" if picked == id else id
	sfx("tick", -12.0, 1.2)


func current() -> Dictionary:
	var tix := tickets()
	for t in tix:
		if str(t["id"]) == picked:
			return t
	return tix[0] if not tix.is_empty() else {}


func big_ticket() -> Dictionary:
	return current()


func grams() -> float:
	var n := 0.0
	for g in (_on.get("grams", []) as Array):
		n += float(g)
	return n


## A deli order on the rail: the name, what (its picture), how many deka.
func draw_ticket(c: Control, t: Dictionary, size: Vector2) -> void:
	var paper: Texture2D = load("res://assets/textury/bistro/ticket.png") if ResourceLoader.exists("res://assets/textury/bistro/ticket.png") else null
	if paper != null:
		c.draw_texture_rect(paper, Rect2(Vector2.ZERO, size), false)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.88, 0.76))
	var f: Font = RETRO_UI.FONT_TEXT
	c.draw_string(f, Vector2(2, 8), first_name(str(t.get("name", ""))).to_upper().substr(0, 4), HORIZONTAL_ALIGNMENT_LEFT, size.x - 3, 8, Color(0.55, 0.1, 0.08))
	var ic: Texture2D = _tex(str(SLICE_TEX.get(str(t.get("good", "")), "")))
	if ic != null:
		var sc := minf(1.0, 14.0 / maxf(ic.get_width(), ic.get_height()))
		c.draw_texture_rect(ic, Rect2(Vector2(floorf((size.x - ic.get_width() * sc) * 0.5), 10), (ic.get_size() * sc).floor()), false)
	var w := "%dDK" % int(int(t.get("want", 0)) / 10)
	var ww := f.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(f, Vector2(floorf((size.x - ww) * 0.5), size.y - 6), w, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.16, 0.12, 0.1))
	var band := int(t.get("band", 0))
	var bar := Rect2(3, size.y - 3, size.x - 6, 2)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * float(t.get("left", 1.0))), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band])


## The order big: who, what, how much, what is on the scale against it.
func draw_big_ticket(c: Control, r: Rect2, t: Dictionary) -> void:
	var paper: Texture2D = load("res://assets/textury/bistro/ticket.png") if ResourceLoader.exists("res://assets/textury/bistro/ticket.png") else null
	if paper != null:
		c.draw_texture_rect(paper, r, false)
	else:
		c.draw_rect(r, Color(0.92, 0.88, 0.76))
	var x := r.position.x + 7
	var y := r.position.y + 18
	var ink := Color(0.16, 0.12, 0.1)
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, y), first_name(str(t["name"])).substr(0, 9).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.1, 0.08))
	y += 24
	var good := str(t["good"])
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), str(RULES.DELI[good]["label"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	y += 13
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), "%d DEKA" % int(int(t["want"]) / 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	y += 13
	if not _on.is_empty() and str(_on["good"]) == good:
		var g := grams()
		var d := (g - float(t["want"])) / float(t["want"])
		var col := Color(0.1, 0.45, 0.12) if absf(d) <= 0.05 else (Color(0.62, 0.08, 0.05) if d < -0.1 else ink)
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), "SCALE %d G" % int(round(g)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		y += 13
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), "WRAPPED" if bool(_on["wrapped"]) else "WRAP IT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.1, 0.45, 0.12) if bool(_on["wrapped"]) else ink)
	var band := 0 if int(t.get("age", 0)) < RULES.DELI_WAIT / 2 else (1 if int(t.get("age", 0)) < RULES.DELI_WAIT - 5 else 2)
	var bar := Rect2(r.position.x + 6, r.end.y - 8, r.size.x - 12, 4)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * (1.0 - clampf(float(t.get("age", 0)) / float(RULES.DELI_WAIT), 0.0, 1.0))), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band])


# ── what it looks like ───────────────────────────────────────────────────────

func _show() -> void:
	var t := current()
	var good := str(_on.get("good", t.get("good", "salami")))
	_piece.visible = not t.is_empty() or not _on.is_empty()
	if _piece.visible:
		retex(_piece, JTEX + str(PIECE_TEX[good]) + ".png", float(PIECE_M[good]))
	var n := (_on.get("grams", []) as Array).size()
	var wrapped := bool(_on.get("wrapped", false))
	for i in _pile.size():
		var s: Sprite3D = _pile[i]
		s.visible = not wrapped and i < n
		if s.visible:
			retex(s, JTEX + str(SLICE_TEX[good]) + ".png", float(SLICES_M[good]))
			put(s, PLATE_AT + Vector2(-8 + (i % 3) * 8, -6 + (i / 3) * 6), 0.03 + 0.003 * i)
	_parcel.visible = wrapped
	if wrapped:
		put(_parcel, PLATE_AT, 0.035)
	_display.text = "%d g" % int(round(grams())) if not _on.is_empty() else "0 g"


# ── what can be done ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	var t := current()
	if t.is_empty() and _on.is_empty():
		return out
	var good := str(_on.get("good", t.get("good", "salami")))
	var wrapped := bool(_on.get("wrapped", false))
	if not wrapped:
		out.append({"id": "cut", "rect": BOARD, "verb": "Cut a slice of the %s onto the scale" % str(RULES.DELI[good]["label"]).to_lower()})
		if not _on.is_empty():
			out.append({"id": "off", "rect": SCALE, "verb": "A slice back off the scale (%d g)" % int(round(grams()))})
			out.append({"id": "wrap", "rect": PAPER, "verb": "Wrap it in paper"})
	else:
		var who := first_name(str(t.get("name", ""))) if not t.is_empty() else ""
		out.append({"id": "give", "node": _parcel, "verb": "Over the counter to %s (%d g)" % [who, int(round(grams()))] if who != "" else "Nobody asked for it"})
	return out


func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	match id:
		"cut":
			return "knife"
		"wrap":
			return "wrap"
	return "open"


func _press(id: String) -> void:
	var t := current()
	match id:
		"cut":
			_cut(t)
		"off":
			var g: Array = _on.get("grams", [])
			if not g.is_empty():
				g.pop_back()
				sfx("box_down", -16.0, 1.8)
				if g.is_empty():
					_on = {}
		"wrap":
			if not _on.is_empty():
				_on["wrapped"] = true
				sfx("res://assets/sfx/jednota/paper_wrap.mp3", -8.0)
		"give":
			_give(t)


func _cut(t: Dictionary) -> void:
	var good := str(_on.get("good", t.get("good", "")))
	if good == "":
		return
	var slice := float(RULES.DELI[good]["slice"]) * _rng.randf_range(0.75, 1.3)
	var got: float = shop.cut_slice(building_key, good, slice)
	if got <= 0.0:
		say("", "None left. Order it in the books.")
		return
	if _on.is_empty():
		_on = {"good": good, "grams": [], "wrapped": false}
	(_on["grams"] as Array).append(got)
	sfx("res://assets/sfx/jednota/knife_slice.mp3", -8.0, _rng.randf_range(0.95, 1.08))
	sfx("res://assets/sfx/jednota/scale.mp3", -14.0, _rng.randf_range(0.95, 1.05))


func _give(t: Dictionary) -> void:
	if t.is_empty() or _on.is_empty():
		return
	var who := first_name(str(t["name"]))
	if str(_on["good"]) != str(t["good"]):
		say(who, "I asked for %s." % str(RULES.DELI[str(t["good"])]["label"]).to_lower())
		return
	var v: Dictionary = shop.deli_serve(building_key, t, grams(), bool(_on["wrapped"]))
	if not bool(v.get("ok", false)):
		say(who, " ".join(v.get("notes", [])))
		score_card(v, str(RULES.DELI[str(t["good"])]["label"]))
		return
	_on = {}
	picked = ""
	sfx("bag", -10.0)
	score_card(v, str(RULES.DELI[str(t["good"])]["label"]))
	var notes: Array = v.get("notes", [])
	say(who, " ".join(notes) if not notes.is_empty() else ["Lovely. Thank you.", "Just right.", "And some for tomorrow, then."][_rng.randi() % 3])


func bar_buttons() -> Array:
	return [{"id": "bin", "label": "BIN"}] if not _on.is_empty() else []


func bar_button(id: String) -> void:
	if id == "bin":
		_on = {}
		sfx("bin", -10.0)


func bar_text() -> String:
	if building_key == "":
		return ""
	var parts: Array = []
	for g in RULES.DELI:
		parts.append("%s %d" % [str(RULES.DELI[g]["label"]).to_upper(), maxi(0, BIZ.stock_of(building_key, str(RULES.DELI[g]["good"])))])
	return "  ".join(parts)


func _closing() -> void:
	_on = {}


# ── debug (tools/podniky_check.gd, tools/jednota_shots.gd) ───────────────────

func debug_click(id: String) -> void:
	_press(id)


## Cut till the scale says about what the order wants.
func debug_cut_to_want() -> void:
	var t := current()
	if t.is_empty():
		return
	var guard := 0
	while grams() < float(t["want"]) and guard < 60:
		_cut(t)
		guard += 1
