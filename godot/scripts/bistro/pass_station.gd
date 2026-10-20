extends "res://scripts/bistro/bistro_station.gd"

## The pass (DESIGN.md §7b): the counter's top is a Build texture (st_pass: the goulash
## pot in its water bath, the tartar and the onion, the bell by the hatch), the things on
## it sprites in the room: what the stove and the board made ready on the heat shelf
## (fried cheese, chips, dumpling slices), the stack of clean plates, the plate you build.
## The plate is built Papa's way:
##   the ticket   the oldest is picked for you (click another on the rail to take that
##                one); it hangs big in the frame and ticks off what is on the plate;
##   the plate    a plate off the stack, then each thing for it (the ladle, a slice of
##                dumpling a click, the cheese, the chips, the tartar, the onion); a click
##                on the plate takes the last thing off again; SCRAPE bins it;
##   the bell     out through the hatch to whoever the ticket is: judged (the right dish,
##                the right counts, how long they waited), the money, the tip, the stars.
##                Somebody else's dish comes back.

const SHELF_CHEESE := Rect2(236, 70, 64, 50)
const SHELF_FRIES := Rect2(304, 70, 64, 50)
const SHELF_DUMPLING := Rect2(372, 70, 70, 50)
const POT := Rect2(20, 40, 200, 230)
const STACK := Rect2(232, 160, 70, 70)
const PLATE_AT := Vector2(372, 250)
const TARTAR := Rect2(450, 110, 85, 82)
const ONION := Rect2(520, 175, 105, 100)
const BELL := Rect2(548, 6, 70, 60)
## Where each thing lies on the plate (offset from its centre, design px).
const ON_PLATE := {
	"goulash": Vector2(-14, -6), "dumpling": Vector2(20, -4), "onion": Vector2(-16, -12),
	"cheese": Vector2(-12, -2), "fries": Vector2(18, 2), "tartar": Vector2(4, 20),
}
const PLATE_LIFT := 0.016

var _plate: Array = []
var _has_plate := false
var _out_t := -1.0
var _out_from := Vector3.ZERO
var _drop: Dictionary = {}
var _plate_spr: Sprite3D
var _food: Array = []
var _stack: Array = []
var _shelf: Dictionary = {}
var _stars: Array = []
var _stars_t := -1.0
var _star_n := 0


func _build() -> void:
	super._build()
	for i in 2:
		_stack.append(bstand("plates_stack", 1.1))
	_shelf = {"cheese": [], "fries": [], "dumpling": []}
	for i in 6:
		(_shelf["cheese"] as Array).append(bsprite("slice_golden_small"))
		(_shelf["fries"] as Array).append(bsprite("chips_rack"))
	for i in 12:
		(_shelf["dumpling"] as Array).append(bsprite("dumpling_slice", true, 1.4))
	_plate_spr = bsprite("plate_top")
	_plate_spr.visible = false
	for i in 14:
		var f := bsprite("food_cheese")
		f.visible = false
		_food.append(f)
	for i in 3:
		var st := bsprite("star", false, 1.6)
		st.visible = false
		st.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		st.shaded = false
		_stars.append(st)


func _opened() -> void:
	_auto_pick()


func _auto_pick() -> void:
	var tix := tickets()
	for t in tix:
		if str(t["id"]) == picked:
			return
	picked = str(tix[0]["id"]) if not tix.is_empty() else ""


func _picked_ticket() -> Dictionary:
	for t in tickets():
		if str(t["id"]) == picked:
			return t
	return {}


func _counts() -> Dictionary:
	var out := {}
	for p in _plate:
		out[p] = int(out.get(p, 0)) + 1
	return out


func plate_counts() -> Dictionary:
	return _counts()


func building_plate() -> bool:
	return _has_plate


func big_ticket() -> Dictionary:
	return _picked_ticket()


# ── what the state looks like ────────────────────────────────────────────────

func _show() -> void:
	if kitchen == null or building_key == "":
		return
	# The clean plates in stacks of five or so, standing by the pot.
	var clean := int(kitchen.plates(building_key)["clean"]) - (1 if _has_plate else 0)
	var n_stack := mini(_stack.size(), ceili(maxi(0, clean) / 5.0))
	for i in _stack.size():
		var p: Sprite3D = _stack[i]
		p.visible = i < n_stack
		put(p, STACK.get_center() + Vector2(-16 + i * 30, 10), 0.0)
	var shelf_rects := {"cheese": SHELF_CHEESE, "fries": SHELF_FRIES, "dumpling": SHELF_DUMPLING}
	for part in _shelf:
		var have := kitchen.prep(building_key, str(part))
		var list: Array = _shelf[part]
		var r: Rect2 = shelf_rects[part]
		for i in list.size():
			var spr: Sprite3D = list[i]
			spr.visible = i < have
			if part == "dumpling":
				put(spr, r.position + Vector2(10 + (i % 4) * 15, 12 + (i / 4) * 12), 0.014)
			else:
				put(spr, r.position + Vector2(18 + (i % 2) * 26, 12 + (i / 2) * 14), 0.014 + (i / 2) * 0.004)
	# The plate on the counter (or on its way up through the hatch) and what is on it.
	_plate_spr.visible = _has_plate
	for f in _food:
		(f as Sprite3D).visible = false
	if _has_plate:
		var base := local_at(PLATE_AT, PLATE_LIFT)
		if _out_t >= 0.0:
			var k := floorf(clampf(_out_t / 0.5, 0.0, 1.0) * 6.0) / 6.0
			base = base.lerp(_out_from, k)
		_plate_spr.position = base
		var placed := {}
		for i in mini(_plate.size(), _food.size()):
			var part := str(_plate[i])
			var n := int(placed.get(part, 0))
			placed[part] = n + 1
			var off: Vector2 = ON_PLATE.get(part, Vector2.ZERO)
			if part == "dumpling":
				off += Vector2((n % 3) * 9 - 9, (n / 3) * 8 - 4)
			elif n > 0:
				off += Vector2(n * 6, n * 4)
			var spr: Sprite3D = _food[i]
			var key := "food_" + part
			if part == "dumpling":
				key = "dumpling_slice"
			bretex(spr, key, 1.4 if part == "dumpling" else 1.0)
			spr.visible = true
			var dk := clampf(float(_drop.get(i, 1.0)) / 0.12, 0.0, 1.0)
			var lift := 0.006 + i * 0.002 + (1.0 - floorf(dk * 3.0) / 3.0) * 0.06
			spr.position = base + local_at(PLATE_AT + off, 0.0) - local_at(PLATE_AT, 0.0) + Vector3(0, lift, 0)
	for i in _stars.size():
		var st: Sprite3D = _stars[i]
		st.visible = _stars_t >= 0.0
		if st.visible:
			bretex(st, "star" if i < _star_n else "star_dim", 1.6)
			put(st, PLATE_AT + Vector2(-30 + i * 30, -60), 0.16 + floorf(minf(_stars_t, 0.3) * 12.0) / 12.0 * 0.12)


# ── what can be used ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if kitchen == null or _out_t >= 0.0:
		return out
	var pl: Dictionary = kitchen.plates(building_key)
	if not _has_plate and int(pl["clean"]) > 0:
		out.append({"id": "stack", "rect": STACK, "verb": "Take a clean plate (%d)" % int(pl["clean"])})
	if _has_plate:
		var pot: Dictionary = kitchen.site(building_key)["pot"]
		if int(pot["level"]) > 0:
			out.append({"id": "goulash", "rect": POT, "verb": "Ladle goulash onto the plate" if float(pot["heat"]) >= 0.6 else "The goulash is not hot yet"})
		for part in ["cheese", "fries", "dumpling"]:
			var have := kitchen.prep(building_key, part)
			if have > 0:
				var r: Rect2 = {"cheese": SHELF_CHEESE, "fries": SHELF_FRIES, "dumpling": SHELF_DUMPLING}[part]
				out.append({"id": part, "rect": r, "verb": "Put %s on the plate (%d)" % [_label(part), have]})
		out.append({"id": "tartar", "rect": TARTAR, "verb": "Put tartar on the plate"})
		out.append({"id": "onion", "rect": ONION, "verb": "Put onion on the plate"})
		if not _plate.is_empty():
			out.append({"id": "plate", "node": _plate_spr, "verb": "Take the %s off again" % _label(str(_plate[-1]))})
			var t := _picked_ticket()
			if not t.is_empty():
				out.append({"id": "bell", "rect": BELL, "verb": "Ring: out to %s" % ORDERS_first(str(t["name"]))})
	return out


func _label(part: String) -> String:
	return {"goulash": "goulash", "dumpling": "a slice of dumpling", "onion": "onion", "cheese": "the fried cheese", "fries": "chips", "tartar": "tartar"}.get(part, part)


func bar_buttons() -> Array:
	return [{"id": "scrape", "label": "SCRAPE"}] if _has_plate and _out_t < 0.0 else []


func bar_button(id: String) -> void:
	if id == "scrape":
		_scrape()


func _press(id: String) -> void:
	if _out_t >= 0.0:
		return
	match id:
		"stack":
			if int(kitchen.plates(building_key)["clean"]) <= 0:
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
			_give_back(str(_plate.pop_back()))
			sfx("ladle_plate", -14.0, 1.3)
		_:
			_add(id)


func _add(part: String) -> void:
	if not _has_plate:
		return
	var counts := _counts()
	match part:
		"goulash":
			var pot: Dictionary = (kitchen.site(building_key)["pot"] as Dictionary).duplicate()
			if int(pot["level"]) <= 0:
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
				sfx("tick", -14.0, 0.7)
				return
			sfx("plate_down", -12.0, 1.3 if part == "dumpling" else 1.0)
		"tartar", "onion":
			if int(counts.get(part, 0)) >= 2:
				return
			sfx("ladle_plate", -12.0, 1.5)
		_:
			return
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
	# Up and out through the hatch over the pass.
	_out_t = 0.0
	_out_from = local_at(PLATE_AT, PLATE_LIFT) + Vector3(0, 0.16, -0.66)
	_star_n = int(verdict["stars"])
	_stars_t = 0.0
	pop("+$%d" % int(verdict["amount"]), PLATE_AT + Vector2(0, -30), RETRO_UI.C_AMBER_LIGHT if int(verdict["tip"]) > 0 else RETRO_UI.C_BONE, true)
	sfx("till", -8.0)
	var lines: Array
	if _star_n >= 3:
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
		if _out_t > 0.55:
			_out_t = -1.0
			_has_plate = false
			_plate = []
			_auto_pick()
	elif picked == "" or _picked_ticket().is_empty():
		_auto_pick()


func _closing() -> void:
	# A plate half built goes back on the stack (its food back where it came from).
	if _has_plate and _out_t < 0.0:
		for p in _plate:
			_give_back(str(p))
		kitchen.act(building_key, "plates", [1, 0])
	_has_plate = false
	_plate = []
	_out_t = -1.0


func bar_text() -> String:
	var text := super.bar_text()
	if kitchen != null:
		var d: Dictionary = kitchen.today(building_key)
		if int(d["plates"]) > 0:
			text = "TODAY %d *%.1f $%d   " % [int(d["plates"]), float(d["stars"]), int(d["money"])] + text
	return text


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


func debug_click(id: String) -> void:
	_press(id)
