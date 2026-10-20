extends "res://scripts/bistro/bistro_station.gd"

## The sink (DESIGN.md §7b): the counter's top is a Build texture (st_sink: the draining
## board, the basin of grey water, the brush and the sponge), the things on it sprites in
## the room. The dirty plates come back from the tables onto the draining board by
## themselves (kitchen.gd, when the guests have eaten); the clean ones stand at the right.
##   take a plate off the pile into the water (drag it, or a click); hold the button on
##   it and rub, the goulash and the crumbs coming off stroke by stroke; clean, onto the
##   clean ones (drag it, or a click).

const PILE := Rect2(30, 70, 150, 200)
const WATER_AT := Vector2(320, 168)
const WATER := Rect2(195, 80, 250, 180)
const RACK := Rect2(470, 40, 160, 220)
const STROKES := 900.0
const DRAG_FAR := 8.0

var _in_water := false
var _dirt := 1.0
var _scrubbing := false
var _last := Vector2(-1, -1)
var _bubbles: Array = []
var _pile: Array = []
var _clean: Array = []
var _plate: Sprite3D
var _plate_dirt: Sprite3D
var _sponge: Sprite3D
var _bubble_spr: Array = []
var _shine: Sprite3D
var _hand_what := ""
var _press_at := Vector2(-1, -1)
var _far := false


func _build() -> void:
	super._build()
	for i in 10:
		_pile.append(bsprite("plate_dirty", true, 0.9))
	for i in 4:
		_clean.append(bstand("plates_stack", 1.1))
	_plate = bsprite("plate_top")
	_plate_dirt = bsprite("plate_dirty")
	_sponge = bsprite("sponge", true, 1.4)
	_sponge.visible = false
	for i in 8:
		var b := bsprite("bubbles", true, 1.4)
		b.visible = false
		_bubble_spr.append(b)
	_shine = meter(5, 18)
	_shine.position = local_at(Vector2(WATER.end.x + 6, WATER.position.y + 40), 0.04)


func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var pl: Dictionary = kitchen.plates(building_key)
	var dirty := int(pl["dirty"]) - (1 if _in_water or _hand_what == "pile" else 0)
	for i in _pile.size():
		var spr: Sprite3D = _pile[i]
		spr.visible = i < dirty
		put(spr, PILE.get_center() + Vector2((i % 2) * 4 - 2, 30 - i * 5), 0.012 + i * 0.01)
	# The clean ones in stacks of five, standing at the right.
	var clean := int(pl["clean"])
	for i in _clean.size():
		var spr: Sprite3D = _clean[i]
		spr.visible = i < ceili(clean / 5.0)
		put(spr, RACK.position + Vector2(40 + (i % 2) * 70, 90 + (i / 2) * 70), 0.0)
	var in_hand := _hand_what != ""
	_plate.visible = _in_water or in_hand
	_plate_dirt.visible = (_in_water and _dirt > 0.0) or _hand_what == "pile"
	if in_hand:
		_plate.position = held_at(0.08)
		_plate_dirt.position = held_at(0.083)
	else:
		put(_plate, WATER_AT, 0.01)
		put(_plate_dirt, WATER_AT, 0.013)
	# The dirt comes off in steps (a picture of four looks, not a smooth fade).
	_plate_dirt.modulate.a = 1.0 if _hand_what == "pile" else ceilf(_dirt * 4.0) / 4.0
	_sponge.visible = _scrubbing and _mouse_free.x > -500.0
	if _sponge.visible:
		_sponge.position = held_at(0.05)
	for i in _bubble_spr.size():
		var spr: Sprite3D = _bubble_spr[i]
		spr.visible = i < _bubbles.size()
		if spr.visible:
			var b: Dictionary = _bubbles[i]
			var k := floorf(float(b["t"]) / 0.7 * 5.0) / 5.0
			put(spr, b["at"], 0.03 + k * 0.08)
	_shine.visible = _in_water and not in_hand
	if _shine.visible:
		set_meter(_shine, 1.0 - _dirt, Vector2(-1, -1), RETRO_UI.C_GREEN)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var pl: Dictionary = kitchen.plates(building_key)
	var dirty := int(pl["dirty"]) - (1 if _in_water else 0)
	if not _in_water and dirty > 0:
		out.append({"id": "pile", "rect": PILE, "verb": "A dirty plate into the water (%d)" % dirty})
	if _in_water:
		out.append({"id": "plate", "node": _plate, "verb": "Scrub the plate: hold and rub" if _dirt > 0.0 else "Clean: onto the others"})
	return out


func _press(id: String) -> void:
	_press_at = _mouse
	_far = false
	match id:
		"pile":
			if int(kitchen.plates(building_key)["dirty"]) <= 0:
				return
			_hand_what = "pile"
			sfx("tick", -16.0, 1.3)
		"plate":
			if _dirt <= 0.0:
				_hand_what = "clean"
				return
			_scrubbing = true
			_last = _mouse_free


func _release(id: String) -> void:
	var what := _hand_what
	_hand_what = ""
	_scrubbing = false
	mark_target(Rect2())
	var at := _mouse_free
	if what == "pile":
		if _far and not WATER.grow(20.0).has_point(at):
			return
		_in_water = true
		_dirt = 1.0
		sfx("splash", -8.0)
		return
	if what == "clean":
		if _far and not RACK.grow(30.0).has_point(at):
			return
		_rack()


func _rack() -> void:
	# On the clean ones: one clean, one dirty fewer.
	kitchen.act(building_key, "plates", [1, -1])
	_in_water = false
	pop("+1", RACK.get_center() + Vector2(0, -40), RETRO_UI.C_GREEN_LIGHT)
	sfx("plate_rack", -8.0)


func _drag(at: Vector2) -> void:
	if at.x < -500.0:
		return
	if _press_at.x >= 0.0 and at.distance_to(_press_at) > DRAG_FAR:
		_far = true
	if _hand_what == "pile":
		mark_target(WATER if _far and WATER.grow(20.0).has_point(at) else Rect2())
	elif _hand_what == "clean":
		mark_target(RACK if _far and RACK.grow(30.0).has_point(at) else Rect2())
	if not _scrubbing or _dirt <= 0.0:
		return
	var d := (at - _last).length()
	_last = at
	if d <= 0.5:
		return
	_dirt = maxf(0.0, _dirt - d / STROKES)
	if randf() < d / 40.0 and _bubbles.size() < _bubble_spr.size():
		_bubbles.append({"at": at + Vector2(randf_range(-12, 12), randf_range(-8, 8)), "t": 0.0})
	if randf() < d / 120.0:
		sfx("scrub", -14.0, randf_range(0.9, 1.15))
	if _dirt <= 0.0:
		pop("CLEAN", WATER_AT + Vector2(0, -40), RETRO_UI.C_GREEN_LIGHT)
		sfx("tick", -10.0, 1.4)
		_scrubbing = false


func _tick(delta: float) -> void:
	for b in _bubbles:
		b["t"] = float(b["t"]) + delta
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return float(b["t"]) < 0.7)


func _closing() -> void:
	# A plate half washed goes back on the pile (it is still counted dirty).
	_in_water = false
	_scrubbing = false
	_hand_what = ""


func bar_text() -> String:
	if kitchen == null:
		return ""
	var pl: Dictionary = kitchen.plates(building_key)
	return "CLEAN %d  DIRTY %d" % [int(pl["clean"]), int(pl["dirty"])]


# ── debug (tools/bistro_shots.gd) ────────────────────────────────────────────

func debug_wash_one() -> void:
	if int(kitchen.plates(building_key)["dirty"]) <= 0:
		return
	_in_water = true
	_dirt = 0.0
	_rack()


func debug_into_water() -> void:
	if int(kitchen.plates(building_key)["dirty"]) > 0:
		_in_water = true
		_dirt = 0.6
