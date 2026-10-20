extends "res://scripts/pub/pub_station.gd"

## The washer at the bar's end (DESIGN.md §7b "the pub"), worked in the room: a steel sink
## let into the right end of the bar top, the dirty mugs come back from the tables onto the
## bar in front of it by themselves (taproom.gd, when they are drunk), the clean ones go on
## the board by the tap (its sprites are the tap's: tap_station.BOARD). Things are sprites
## at the room's pixel.
##   take a dirty mug into the water (drag it, or a click); hold the button on it and rub,
##   up and down, the rings coming off stroke by stroke; clean, onto the rack (drag it,
##   or a click). The glass washer (gear) washes the lot by itself.

## On the bar top (design px, pub_layout.SURFACES: 2.5 mm a px): the empties on the
## guests' side, the sink on the barman's, the tap's board of clean mugs at its right.
const PILE := Rect2(196, 24, 168, 90)
const PILE_SPOTS := [Vector2(226, 52), Vector2(278, 52), Vector2(330, 52), Vector2(240, 96), Vector2(292, 96), Vector2(344, 96)]
const WATER_AT := Vector2(280, 228)
const WATER := Rect2(200, 168, 160, 112)
const RACK := Rect2(356, 146, 168, 92)
const K_SURF := preload("res://scripts/interior_kit.gd")
const STROKES := 700.0
const MUG_M := 0.16
const DRAG_FAR := 8.0

var _in_water := false
var _dirt := 1.0
var _scrubbing := false
var _last := Vector2(-1, -1)
var _hand_what := ""
var _press_at := Vector2(-1, -1)
var _far := false
var _pile: Array = []
var _mug: Sprite3D
var _mug_dirt: Sprite3D
var _bubbles: Array = []
var _bubble_spr: Array = []
var _shine: Sprite3D


func _build() -> void:
	super._build()
	_build_sink()
	for i in PILE_SPOTS.size():
		_pile.append(psprite("mug_dirty", MUG_M))
	_mug = psprite("mug_clean", MUG_M)
	_mug_dirt = psprite("mug_dirty", MUG_M)
	for i in 8:
		var b := sprite("res://assets/textury/bistro/bubbles.png", 0.05, true)
		b.visible = false
		_bubble_spr.append(b)
	_shine = meter(5, 18)
	_shine.position = local_at(Vector2(WATER.position.x - 16, WATER_AT.y), 0.1)


## The sink: a steel rim let into the bar top, the water in it (camp/galvanized.png,
## camp/lake_water.png greyed), plain boxes the room's way.
func _build_sink() -> void:
	var c := local_at(WATER.get_center(), 0.0)
	var w := metres_x(WATER.size.x)
	var d := WATER.size.y / DESIGN.y * surf_size.y
	var rim := MeshInstance3D.new()
	rim.name = "SinkRim"
	var b := BoxMesh.new()
	b.size = Vector3(w + 0.04, 0.016, d + 0.04)
	rim.mesh = b
	rim.material_override = K_SURF.surface("galvanized", 0.3, Color(0.85, 0.87, 0.9))
	rim.position = c + Vector3(0, 0.008, 0)
	add_child(rim)
	var water := MeshInstance3D.new()
	water.name = "SinkWater"
	var q := BoxMesh.new()
	q.size = Vector3(w, 0.004, d)
	water.mesh = q
	water.material_override = K_SURF.surface("lake_water", 0.4, Color(0.55, 0.6, 0.58))
	water.position = c + Vector3(0, 0.018, 0)
	add_child(water)


func _show() -> void:
	if taproom == null or building_key == "":
		return
	var m: Dictionary = taproom.mugs(building_key)
	var dirty := int(m["dirty"]) - (1 if _in_water or _hand_what == "pile" else 0)
	for i in _pile.size():
		var s: Sprite3D = _pile[i]
		s.visible = i < dirty
		put(s, PILE_SPOTS[i], 0.0)
	var in_hand := _hand_what != ""
	_mug.visible = _in_water or in_hand
	_mug_dirt.visible = (_in_water and _dirt > 0.0) or _hand_what == "pile"
	if in_hand:
		_mug.position = held_at(0.06)
		_mug_dirt.position = held_at(0.06) + Vector3(0, 0, 0.003)
	else:
		# Pressed down in the water as you scrub: in steps, up and down.
		var down := 0.0
		if _scrubbing and _last.y >= 0.0:
			down = -0.03 * (float(int(_t * 10.0) % 2))
		put(_mug, WATER_AT, -0.05 + down)
		put(_mug_dirt, WATER_AT, -0.05 + down)
		_mug_dirt.position.z += 0.003
	_mug_dirt.modulate.a = 1.0 if _hand_what == "pile" else ceilf(_dirt * 4.0) / 4.0
	for i in _bubble_spr.size():
		var spr: Sprite3D = _bubble_spr[i]
		spr.visible = i < _bubbles.size()
		if spr.visible:
			var b: Dictionary = _bubbles[i]
			put(spr, b["at"], 0.04 + floorf(float(b["t"]) / 0.7 * 5.0) / 5.0 * 0.08)
	_shine.visible = _in_water and not in_hand and is_open()
	if _shine.visible:
		set_meter(_shine, 1.0 - _dirt, Vector2(-1, -1), RETRO_UI.C_GREEN)


func _spots() -> Array:
	var out: Array = []
	if taproom == null:
		return out
	var dirty := int(taproom.mugs(building_key)["dirty"]) - (1 if _in_water else 0)
	if not _in_water and dirty > 0:
		out.append({"id": "pile", "rect": PILE, "verb": "A dirty mug into the water (%d)" % dirty})
	if _in_water:
		out.append({"id": "mug", "node": _mug, "verb": "Scrub it: hold and rub" if _dirt > 0.0 else "Clean: onto the rack"})
	return out


func _press(id: String) -> void:
	_press_at = _mouse
	_far = false
	match id:
		"pile":
			_hand_what = "pile"
			sfx("glass_down", -14.0, 1.2)
		"mug":
			if _dirt <= 0.0:
				_hand_what = "clean"
				return
			_scrubbing = true
			_last = _mouse_free


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
		_bubbles.append({"at": at + Vector2(randf_range(-14, 14), randf_range(-8, 8)), "t": 0.0})
	if randf() < d / 120.0:
		sfx("scrub", -14.0, randf_range(0.9, 1.15))
	if _dirt <= 0.0:
		pop("CLEAN", WATER_AT + Vector2(0, -50), RETRO_UI.C_GREEN_LIGHT)
		sfx("tick", -10.0, 1.4)
		_scrubbing = false


func _release(_id: String) -> void:
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
	elif what == "clean":
		if _far and not RACK.grow(30.0).has_point(at):
			return
		taproom.act(building_key, "mugs", [1, -1])
		_in_water = false
		pop("+1", RACK.get_center() + Vector2(0, -60), RETRO_UI.C_GREEN_LIGHT)
		sfx("glass_down", -8.0)


func _tick(delta: float) -> void:
	for b in _bubbles:
		b["t"] = float(b["t"]) + delta
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return float(b["t"]) < 0.7)


func _closing() -> void:
	_in_water = false
	_scrubbing = false
	_hand_what = ""


# ── debug (tools/pub_shots.gd) ───────────────────────────────────────────────

func debug_wash_one() -> void:
	if int(taproom.mugs(building_key)["dirty"]) > 0:
		taproom.act(building_key, "mugs", [1, -1])


func debug_into_water() -> void:
	if int(taproom.mugs(building_key)["dirty"]) > 0:
		_in_water = true
		_dirt = 0.6
