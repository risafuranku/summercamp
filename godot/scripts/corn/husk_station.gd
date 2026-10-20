extends "res://scripts/corn/corn_station.gd"

## The husking at the corn stand (DESIGN.md §7b "The corn stand"), worked on the stand's
## counter beside the pot: the crate of cobs in their husks at the left, the table, the
## bowl the husked ones go in and the bucket for the husks at the right (the stand's Build
## picture, corn/st_husk.png). Things are sprites at the room's pixel.
##   the crate   a click: a cob in its husk onto the table (one off the books' cobs)
##   the cob     hold the button on it and pull away: a leaf comes off and flies into the
##               bucket (four leaves; two with the husking table, gear); then the silk at
##               its tip: a click picks a tuft (three)
##   clean       a click (or the bowl): into the bowl, for the pot

## On the counter (design px, stand_layout.SURFACES: 2 mm a px).
const CRATE := Rect2(10, 15, 165, 265)
const TABLE_AT := Vector2(320, 196)
const BOWL := Rect2(488, 30, 115, 110)
const BOWL_SPOTS := [Vector2(520, 70), Vector2(548, 64), Vector2(576, 72), Vector2(530, 96), Vector2(560, 100), Vector2(544, 84)]
const BUCKET := Rect2(482, 155, 155, 160)
const COB_M := 0.21
## A pull this long (design px) takes a leaf off.
const PULL := 34.0

## The cob on the table: {leaves, silk} ({} none). Yours alone (taken off the books).
var _cob: Dictionary = {}
var _cob_spr: Sprite3D
var _leaf_spr: Array = []
var _silk_spr: Array = []
var _bowl_spr: Array = []
var _flying: Array = []          # {sprite, from: Vector2, t}
var _pull_from := Vector2(-1, -1)
var _rng := RandomNumberGenerator.new()
## Opens the books (set by the stand's view).
var open_books: Callable


## The husking table once bought, under the cob being husked.
var _gear_table: Sprite3D


func _build() -> void:
	super._build()
	_rng.randomize()
	_gear_table = sprite("res://assets/textury/camp/gear_husktable.png", 0.42, true)
	put(_gear_table, TABLE_AT, 0.002)
	_gear_table.visible = false
	_cob_spr = lying("cob_raw", COB_M)
	_cob_spr.visible = false
	for i in CORN.LEAVES:
		var l := lying("husk_leaf", COB_M * 0.95, 0.16 if i % 2 == 0 else -0.16)
		l.visible = false
		_leaf_spr.append(l)
	for i in CORN.SILK:
		var s := csprite("silk", 0.06, false)
		s.visible = false
		_silk_spr.append(s)
	for i in BOWL_SPOTS.size():
		var b := lying("cob_raw", COB_M * 0.75, 0.25 if i % 2 == 0 else -0.2)
		b.visible = false
		_bowl_spr.append(b)


# ── what the state looks like ────────────────────────────────────────────────

func _show() -> void:
	if stand == null or building_key == "":
		return
	_gear_table.visible = BUSINESS.has_gear(building_key, "table")
	var n := int(stand.bowl(building_key))
	for i in _bowl_spr.size():
		var b: Sprite3D = _bowl_spr[i]
		b.visible = i < n
		put(b, BOWL_SPOTS[i], 0.04 + float(i / 3) * 0.025)
		b.position.z += 0.002 * float(i)
	var on := not _cob.is_empty()
	_cob_spr.visible = on
	if on:
		var leaves := int(_cob["leaves"])
		cretex(_cob_spr, "cob_husk" if leaves > 0 else "cob_raw", COB_M)
		put(_cob_spr, TABLE_AT, 0.03)
		for i in _leaf_spr.size():
			var l: Sprite3D = _leaf_spr[i]
			l.visible = i < leaves
			put(l, TABLE_AT + Vector2(-4 + (i % 2) * 8, 0), 0.03 + (0.006 if i % 2 == 0 else -0.004))
			l.position.z += 0.003 + 0.002 * float(i)
		var silk := int(_cob["silk"])
		for i in _silk_spr.size():
			var s: Sprite3D = _silk_spr[i]
			s.visible = leaves == 0 and i < silk
			# At the cob's tip (it lies across: its tip at the right).
			put(s, TABLE_AT + Vector2(46 + i * 5, 0), 0.04 + i * 0.004)
			s.position.z += 0.004
	else:
		for l in _leaf_spr:
			(l as Sprite3D).visible = false
		for s in _silk_spr:
			(s as Sprite3D).visible = false
	# The leaves torn off, flying into the bucket in steps.
	for f in _flying:
		var k := clampf(float(f["t"]) / 0.4, 0.0, 1.0)
		k = floorf(k * 5.0) / 5.0
		var to := BUCKET.get_center()
		var at: Vector2 = (f["from"] as Vector2).lerp(to, k)
		put(f["sprite"], at, 0.04 + sin(k * PI) * 0.14)


# ── what can be used ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if stand == null:
		return out
	if _cob.is_empty():
		var n := maxi(0, BUSINESS.stock_of(building_key, "cobs"))
		out.append({"id": "crate", "rect": CRATE, "verb": "A cob from the crate (%d)" % n if n > 0 else "The crate is empty: order corn in the books"})
	else:
		var verb := "Into the bowl"
		if int(_cob["leaves"]) > 0:
			verb = "Hold and pull a leaf off (%d)" % int(_cob["leaves"])
		elif int(_cob["silk"]) > 0:
			verb = "Pick the silk off (%d)" % int(_cob["silk"])
		out.append({"id": "cob", "node": _cob_spr, "verb": verb})
		if int(_cob["leaves"]) == 0 and int(_cob["silk"]) == 0:
			out.append({"id": "bowl", "rect": BOWL, "verb": "Into the bowl (%d in it)" % int(stand.bowl(building_key))})
	return out


## The bare glove for the crate and the bowl, the fist on a leaf as it is pulled.
func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	if id == "cob" and not _cob.is_empty() and int(_cob["leaves"]) > 0:
		return "husk"
	return "open"


func _press(id: String) -> void:
	match id:
		"crate":
			_take()
		"cob":
			if int(_cob["leaves"]) > 0:
				_pull_from = _mouse_free
			elif int(_cob["silk"]) > 0:
				_cob["silk"] = int(_cob["silk"]) - 1
				sfx("tick", -14.0, _rng.randf_range(1.4, 1.7))
			else:
				_into_bowl()
		"bowl":
			if not _cob.is_empty() and int(_cob["leaves"]) == 0 and int(_cob["silk"]) == 0:
				_into_bowl()


func _drag(at: Vector2) -> void:
	if _pull_from.x < 0.0 or at.x < -500.0 or _cob.is_empty():
		return
	if at.distance_to(_pull_from) >= PULL and int(_cob["leaves"]) > 0:
		_cob["leaves"] = int(_cob["leaves"]) - 1
		_pull_from = Vector2(-1, -1)
		var l := lying("husk_leaf", COB_M * 0.95, 0.4)
		_flying.append({"sprite": l, "from": at, "t": 0.0})
		sfx("leaf_tear", -10.0, _rng.randf_range(0.9, 1.1))


func _release(_id: String) -> void:
	_pull_from = Vector2(-1, -1)


func _take() -> void:
	if BUSINESS.stock_of(building_key, "cobs") == 0:
		say("", "The crate is empty.")
		sfx("tick", -14.0, 0.7)
		return
	if CoreRoot != null and CoreRoot.actions != null and BUSINESS.stock_of(building_key, "cobs") > 0:
		if not CoreRoot.actions.biz_take(building_key, {"cobs": 1}):
			return
	_cob = {"leaves": int(stand.leaves(building_key)), "silk": CORN.SILK}
	sfx("plate_down", -12.0, 0.8)


func _into_bowl() -> void:
	_cob = {}
	stand.act(building_key, "husked", [1])
	sfx("plate_down", -10.0, 1.1)


func _tick(delta: float) -> void:
	for f in _flying:
		f["t"] = float(f["t"]) + delta
	var keep: Array = []
	for f in _flying:
		if float(f["t"]) > 0.45:
			(f["sprite"] as Node).queue_free()
		else:
			keep.append(f)
	_flying = keep


func _closing() -> void:
	_pull_from = Vector2(-1, -1)


func bar_buttons() -> Array:
	return [{"id": "books", "label": "BOOKS"}]


func bar_button(id: String) -> void:
	if id == "books" and open_books.is_valid():
		open_books.call()


# ── debug (tools/stand_check.gd, tools/stand_shots.gd) ───────────────────────

func debug_click(id: String) -> void:
	_press(id)


## The cob on the table husked clean at once (a leaf pull is a press and a drag).
func debug_husk() -> void:
	if _cob.is_empty():
		_take()
	if not _cob.is_empty():
		_cob["leaves"] = 0
		_cob["silk"] = 0


## Pulls one leaf (as a press and a drag would).
func debug_pull() -> void:
	if not _cob.is_empty() and int(_cob["leaves"]) > 0:
		_pull_from = TABLE_AT
		_drag(TABLE_AT + Vector2(0, -PULL - 2.0))
