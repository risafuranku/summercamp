extends "res://scripts/bistro/station_view.gd"

## The pass (assets/textury/bistro/st_pass.png): the hatch to the dining room with the
## bell on its sill, the heat shelf with what the stove and the board made ready (fried
## cheese, chips, dumpling slices), the goulash pot in its water bath, the tartar and
## the onion, the stack of clean plates. The plate is built here, Papa's way:
##   the ticket   the oldest is picked for you (click another on the rail to take that
##                one instead); it hangs big beside the plate and ticks off what is on it;
##   the plate    click the stack, then each thing for it (the ladle, a slice of dumpling
##                a click, the cheese, the chips, the tartar, the onion); a click on the
##                plate takes the last thing off again;
##   the bell     out through the hatch to whoever the ticket is: judged (right dish,
##                right counts, how long they waited), the money and the tip, the stars.
##                Somebody else's dish comes back. SCRAPE on the bar bins the plate.

const SHELF_CHEESE := Rect2(236, 92, 64, 36)
const SHELF_FRIES := Rect2(304, 92, 64, 36)
const SHELF_DUMPLING := Rect2(372, 92, 70, 36)
const POT := Rect2(24, 96, 200, 180)
const STACK := Rect2(236, 156, 66, 66)
const PLATE_AT := Vector2(370, 248)
const PLATE := Vector2(116, 116)
const TARTAR := Rect2(450, 110, 85, 82)
const ONION := Rect2(520, 175, 105, 100)
const BELL := Rect2(548, 14, 66, 64)
const BIG_TICKET := Rect2(444, 228, 72, 104)
const SQUASH := 1.0
## Where each thing lies on the plate (offset from its centre, before the squash).
const ON_PLATE := {
	"goulash": Vector2(-16, -6), "dumpling": Vector2(22, -4), "onion": Vector2(-18, -10),
	"cheese": Vector2(-14, -2), "fries": Vector2(20, 2), "tartar": Vector2(4, 22),
}

var _plate: Array = []          # the parts in the order they went on
var _has_plate := false
var _out_t := -1.0              # the plate going up through the hatch
var _drop: Dictionary = {}      # part index -> seconds since it landed
var _stars := 0
var _stars_t := -1.0


func _ready() -> void:
	super._ready()
	station = "pass"
	room = "kitchen"
	picture = tex("st_pass")
	for n in ["plate_top", "plates_stack", "food_goulash", "food_dumpling", "food_cheese", "food_fries", "food_tartar", "food_onion",
			"slice_golden_small", "chips_rack", "dumpling_slice", "star", "star_dim"]:
		tex(n)


func _opened() -> void:
	_auto_pick()


func _auto_pick() -> void:
	var tix := _tickets()
	for t in tix:
		if str(t["id"]) == picked:
			return
	picked = str(tix[0]["id"]) if not tix.is_empty() else ""


func _picked_ticket() -> Dictionary:
	for t in _tickets():
		if str(t["id"]) == picked:
			return t
	return {}


func _counts() -> Dictionary:
	var out := {}
	for p in _plate:
		out[p] = int(out.get(p, 0)) + 1
	return out


func _spots() -> Array:
	var out: Array = []
	if kitchen == null or _out_t >= 0.0:
		return out
	var pl: Dictionary = kitchen.plates(building_key)
	if not _has_plate:
		out.append({"id": "stack", "rect": STACK, "verb": ("Take a clean plate (%d)" % int(pl["clean"])) if int(pl["clean"]) > 0 else "No clean plates: wash some at the sink"})
	var pot: Dictionary = kitchen.site(building_key)["pot"]
	out.append({"id": "goulash", "rect": POT, "verb": _verb_for("goulash", int(pot["level"]), "the pot is empty: fill it at the pot")})
	out.append({"id": "cheese", "rect": SHELF_CHEESE, "verb": _verb_for("cheese", kitchen.prep(building_key, "cheese"), "no fried cheese: the stove")})
	out.append({"id": "fries", "rect": SHELF_FRIES, "verb": _verb_for("fries", kitchen.prep(building_key, "fries"), "no chips: the stove")})
	out.append({"id": "dumpling", "rect": SHELF_DUMPLING, "verb": _verb_for("dumpling", kitchen.prep(building_key, "dumpling"), "no dumplings: cut a loaf at the pot")})
	out.append({"id": "tartar", "rect": TARTAR, "verb": _verb_for("tartar", 99, "")})
	out.append({"id": "onion", "rect": ONION, "verb": _verb_for("onion", 99, "")})
	if _has_plate:
		out.append({"id": "plate", "rect": Rect2(PLATE_AT - PLATE * 0.5, PLATE), "verb": ("Take the %s off again" % _label(str(_plate[-1]))) if not _plate.is_empty() else "An empty plate"})
		out.append({"id": "#scrape", "rect": _scrape_rect(), "verb": "Scrape the plate into the bin"})
	var t := _picked_ticket()
	out.append({"id": "bell", "rect": BELL, "verb": ("Ring: out to %s" % ORDERS_first(str(t["name"]))) if not t.is_empty() and _has_plate and not _plate.is_empty() else "The bell"})
	return out


func _label(part: String) -> String:
	return {"goulash": "goulash", "dumpling": "slice of dumpling", "onion": "onion", "cheese": "fried cheese", "fries": "chips", "tartar": "tartar"}.get(part, part)


func _verb_for(part: String, have: int, empty: String) -> String:
	if have <= 0:
		return empty.capitalize() if empty != "" else ""
	if not _has_plate:
		return "%s (%d): take a plate first" % [_label(part).capitalize(), have] if have < 99 else "%s: take a plate first" % _label(part).capitalize()
	return "Put %s on the plate%s" % [_label(part), (" (%d)" % have) if have < 99 else ""]


func _scrape_rect() -> Rect2:
	return Rect2(W - 84, H - BAR_H + 3, 80, BAR_H - 6)


func _press(id: String) -> void:
	if _out_t >= 0.0:
		return
	match id:
		"stack":
			if int(kitchen.plates(building_key)["clean"]) <= 0:
				say("", "No clean plates. The sink.")
				sfx("tick", -14.0, 0.7)
				return
			kitchen.act(building_key, "plates", [-1, 0])
			_has_plate = true
			_plate = []
			_drop.clear()
			_auto_pick()
			sfx("plate_down", -8.0)
		"bell":
			sfx("bell_ding", -4.0)
			if _has_plate and not _plate.is_empty():
				_ring()
		"plate":
			if _plate.is_empty():
				return
			var last := str(_plate.pop_back())
			_give_back(last)
			sfx("ladle_plate", -14.0, 1.3)
		"#scrape":
			_scrape()
		_:
			_add(id)


func _add(part: String) -> void:
	if not _has_plate:
		say("", "A plate first: the stack.")
		sfx("tick", -14.0, 0.7)
		return
	var counts := _counts()
	match part:
		"goulash":
			var pot: Dictionary = (kitchen.site(building_key)["pot"] as Dictionary).duplicate()
			if int(pot["level"]) <= 0:
				say("", "The pot is empty.")
				return
			if float(pot["heat"]) < 0.6:
				say("", "Not hot yet.")
				return
			if int(counts.get("goulash", 0)) >= 2:
				return
			pot["level"] = int(pot["level"]) - 1
			kitchen.act(building_key, "pot", [pot])
			sfx("ladle_plate", -6.0)
		"cheese", "fries", "dumpling":
			if not kitchen.take(building_key, part):
				say("", {"cheese": "No fried cheese on the shelf. The stove.", "fries": "No chips on the shelf. The stove.", "dumpling": "No dumplings cut. The board by the pot."}[part])
				sfx("tick", -14.0, 0.7)
				return
			sfx("plate_down", -12.0, 1.3 if part == "dumpling" else 1.0)
		"tartar", "onion":
			if int(counts.get(part, 0)) >= 2:
				return
			sfx("ladle_plate", -12.0, 1.5)
	_plate.append(part)
	_drop[_plate.size() - 1] = 0.0


## Back where it came from (the shelf, the pot); tartar and onion are just wiped off.
func _give_back(part: String) -> void:
	match part:
		"goulash":
			var pot: Dictionary = (kitchen.site(building_key)["pot"] as Dictionary).duplicate()
			pot["level"] = int(pot["level"]) + 1
			kitchen.act(building_key, "pot", [pot])
		"cheese", "fries", "dumpling":
			kitchen.act(building_key, "prep", [part, 1])


func _scrape() -> void:
	if not _has_plate:
		return
	_has_plate = false
	_plate = []
	kitchen.act(building_key, "plates", [0, 1])
	sfx("scrape", -8.0)
	say("", "In the bin.")


func _ring() -> void:
	var t := _picked_ticket()
	if t.is_empty():
		say("", "Nobody ordered that.")
		return
	var verdict: Dictionary = kitchen.serve(building_key, t, _counts())
	var who := ORDERS_first(str(t["name"]))
	if not bool(verdict.get("ok", false)):
		say(who, ["That's not what I ordered.", "Whose is this?", "No. Look at the ticket."][randi() % 3])
		sfx("tick", -10.0, 0.6)
		return
	_out_t = 0.0
	_stars = int(verdict["stars"])
	_stars_t = 0.0
	pop("+$%d" % int(verdict["amount"]), PLATE_AT + Vector2(0, -40), RETRO_UI.C_AMBER_LIGHT if int(verdict["tip"]) > 0 else RETRO_UI.C_BONE, true)
	sfx("till", -8.0)
	var lines: Array
	if _stars >= 3:
		lines = ["Now that's food.", "Like at my mother's.", "Quick! Thank you.", "Dobrou chut, eh?"]
	elif float(verdict["accuracy"]) < 0.85:
		lines = ["Hm. Not quite what I asked for.", "Where's the rest of it?", "Close enough."]
	else:
		lines = ["Finally.", "Thought you'd gone fishing.", "Cheers."]
	say(who, str(lines[randi() % lines.size()]))
	picked = ""


func _tick(delta: float) -> void:
	for k in _drop.keys():
		_drop[k] = float(_drop[k]) + delta
	if _stars_t >= 0.0:
		_stars_t += delta
		if _stars_t > 2.2:
			_stars_t = -1.0
	if _out_t >= 0.0:
		_out_t += delta
		if _out_t > 0.5:
			_out_t = -1.0
			_has_plate = false
			_plate = []
			_auto_pick()
	elif picked == "" or _picked_ticket().is_empty():
		_auto_pick()


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if kitchen == null:
		return
	# The heat shelf: fried cheese, chips, dumpling slices.
	for i in mini(6, kitchen.prep(building_key, "cheese")):
		blit(c, "slice_golden_small", SHELF_CHEESE.position + Vector2(18 + (i % 2) * 26, 12 + (i / 2) * 7))
	for i in mini(6, kitchen.prep(building_key, "fries")):
		blit(c, "chips_rack", SHELF_FRIES.position + Vector2(18 + (i % 2) * 26, 12 + (i / 2) * 7))
	for i in mini(12, kitchen.prep(building_key, "dumpling")):
		blit(c, "dumpling_slice" if tex("dumpling_slice") != null else "food_dumpling", SHELF_DUMPLING.position + Vector2(10 + (i % 4) * 14, 14 + (i / 4) * 7))
	ink(c, SHELF_CHEESE.position + Vector2(2, SHELF_CHEESE.size.y + 8), "CHEESE %d" % kitchen.prep(building_key, "cheese"), RETRO_UI.C_BONE)
	ink(c, SHELF_FRIES.position + Vector2(4, SHELF_FRIES.size.y + 8), "CHIPS %d" % kitchen.prep(building_key, "fries"), RETRO_UI.C_BONE)
	ink(c, SHELF_DUMPLING.position + Vector2(4, SHELF_DUMPLING.size.y + 8), "DUMPL %d" % kitchen.prep(building_key, "dumpling"), RETRO_UI.C_BONE)
	# The pot's level and heat.
	var pot: Dictionary = kitchen.site(building_key)["pot"]
	ink(c, POT.position + Vector2(4, POT.size.y + 14), "GOULASH %d" % int(pot["level"]), RETRO_UI.C_BONE if float(pot["heat"]) >= 0.6 else RETRO_UI.C_BLUE)
	# The stack of clean plates.
	var clean := int(kitchen.plates(building_key)["clean"])
	if clean > 0:
		var stack := tex("plates_stack")
		if stack != null and not _has_plate:
			blit(c, "plates_stack", STACK.get_center())
		elif stack != null:
			blit(c, "plates_stack", STACK.get_center(), 0.85)
		else:
			for i in mini(clean, 8):
				_squashed(c, "plate_top", STACK.get_center() + Vector2(0, -i * 3), Vector2(60, 36))
	# The plate on the counter, and what is on it.
	if _has_plate:
		var at := PLATE_AT
		if _out_t >= 0.0:
			# Up through the hatch.
			at += Vector2(_out_t * 40.0, -_out_t * _out_t * 900.0)
		_squashed(c, "plate_top", at, PLATE)
		var placed := {}
		for i in _plate.size():
			var part := str(_plate[i])
			var n := int(placed.get(part, 0))
			placed[part] = n + 1
			var k := clampf(float(_drop.get(i, 1.0)) / 0.12, 0.0, 1.0)
			var off: Vector2 = ON_PLATE.get(part, Vector2.ZERO)
			if part == "dumpling":
				off += Vector2((n % 3) * 9 - 9, (n / 3) * 8 - 4)
			elif n > 0:
				off += Vector2(n * 6, n * 4)
			var p := at + Vector2(off.x, off.y * SQUASH) + Vector2(0, -(1.0 - k) * 10.0)
			var key := "food_" + part
			if part == "dumpling" and tex("dumpling_slice") != null:
				key = "dumpling_slice"
			var t := tex(key)
			if t != null:
				_squashed(c, key, p, t.get_size() * float(PIX))
			elif part == "onion":
				c.draw_arc(p, 6, 0, TAU, 10, Color(0.95, 0.92, 0.8), 2.0)
	_paint_ticket(c)
	if _stars_t >= 0.0:
		for i in 3:
			var on := i < _stars
			var at := PLATE_AT + Vector2(-30 + i * 30, -70 - minf(_stars_t, 0.3) * 30.0)
			if tex("star") != null:
				blit(c, "star" if on else "star_dim", at)
			else:
				ink(c, at, "*", RETRO_UI.C_AMBER_LIGHT if on else RETRO_UI.C_BONE_DIM, RETRO_UI.FONT_BIG, 20)


func _squashed(c: Control, n: String, centre: Vector2, size: Vector2) -> void:
	var t := tex(n)
	if t == null:
		return
	var s := Vector2(size.x, maxf(2.0, floorf(size.y * SQUASH)))
	c.draw_texture_rect(t, Rect2((centre - s * 0.5).floor(), s), false)


## The picked ticket, big, beside the plate: what it wants and what is on the plate.
func _paint_ticket(c: Control) -> void:
	var t := _picked_ticket()
	if t.is_empty():
		return
	var r := BIG_TICKET
	if tex("ticket") != null:
		c.draw_texture_rect(tex("ticket"), r, false)
	var x := r.position.x + 6
	var y := r.position.y + 18
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, y), ORDERS_first(str(t["name"])).substr(0, 9).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.1, 0.08))
	y += 6
	var want: Dictionary = t["parts"]
	var have := _counts()
	for p in RULES.PARTS:
		var w := int(want.get(p, 0))
		var h := int(have.get(p, 0))
		if w == 0 and h == 0:
			continue
		y += 13
		var ic: Texture2D = _tex.get("icon:" + p, null)
		if ic != null:
			c.draw_texture_rect(ic, Rect2(x, y - 10, ic.get_width(), ic.get_height()), false)
		var col := Color(0.16, 0.12, 0.1)
		var mark := ""
		if h == w:
			col = Color(0.1, 0.45, 0.12)
			mark = "OK"
		elif h > w:
			col = Color(0.65, 0.1, 0.06)
			mark = "+%d" % (h - w) if w > 0 else "NO"
		else:
			col = Color(0.4, 0.3, 0.2)
			mark = "-%d" % (w - h)
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x + 14, y), "%d/%d" % [h, w], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x + 42, y), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	var band := RULES.patience_band(int(t.get("age", 0)))
	var bar := Rect2(r.position.x + 5, r.end.y - 9, r.size.x - 10, 4)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * (1.0 - clampf(float(t["age"]) / float(RULES.PATIENCE_GONE), 0.0, 1.0))), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band])


func _paint_bar(c: Control, r: Rect2) -> void:
	if _has_plate:
		_button(c, _scrape_rect(), "SCRAPE", _hover == "#scrape", false)
		r.size.x -= 86
	super._paint_bar(c, r)


func _closing() -> void:
	# A plate half built goes back on the stack (its food to the bin).
	if _has_plate and _out_t < 0.0:
		for p in _plate:
			_give_back(str(p))
		kitchen.act(building_key, "plates", [1, 0])
	_has_plate = false
	_plate = []
	_out_t = -1.0


# ── debug (tools/bistro_coop.gd, tools/bistro_shots.gd) ──────────────────────

## A plate for the picked ticket, built from the trays as a player would.
func debug_build_picked() -> void:
	_auto_pick()
	var t := _picked_ticket()
	if t.is_empty():
		return
	if not _has_plate:
		_press("stack")
	var want: Dictionary = t["parts"]
	for p in RULES.PARTS:
		for i in int(want.get(p, 0)):
			_add(p)
