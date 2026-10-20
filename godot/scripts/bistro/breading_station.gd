extends "res://scripts/bistro/bistro_station.gd"

## The breading table in the cellar (DESIGN.md §7b): its top is a Build texture
## (st_breading: the block of Edam and the knife on the board, three bowls: flour, egg,
## crumbs; the tray for the stove), the slice and the tray's slices sprites in the room.
##   a click on the cheese cuts a slice (off the books' shelf); then the bowls in their
##   order, flour, egg, crumbs: drag the slice into each (or click the bowl), it comes out
##   coated; then onto the tray. Out of order, or a bowl missed, it is badly breaded: the
##   cheese runs out of it in the pan and it burns sooner (kitchen.gd prep "cheese_bad").

const BLOCK := Rect2(10, 70, 145, 200)
const BOWLS := [Rect2(150, 110, 110, 110), Rect2(270, 110, 110, 110), Rect2(392, 110, 110, 110)]
const TRAY := Rect2(520, 90, 110, 175)
## Where the slice waits between bowls: in front of them, nearer you.
const HAND := Vector2(330, 290)
const DRAG_FAR := 8.0

var _slice := false
var _steps: Array = []
var _dip := -1.0
var _dip_bowl := -1
var _slice_spr: Sprite3D
var _tray: Array = []
var _held_at := Vector2(-1, -1)
var _press_at := Vector2(-1, -1)
var _far := false


func _build() -> void:
	super._build()
	_slice_spr = bsprite("cheese_plain")
	_slice_spr.visible = false
	for i in 8:
		_tray.append(bsprite("cheese_breaded", true, 0.8))


func _good() -> bool:
	return _steps == [0, 1, 2]


## The slice's look after the bowls it has had.
func _stage() -> String:
	if _steps.is_empty():
		return "cheese_plain"
	var last := int(_steps[-1])
	if last == 2:
		return "cheese_breaded" if _good() else "cheese_patchy"
	return "cheese_egged" if last == 1 else "cheese_floured"


func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var good := kitchen.prep(building_key, "cheese_raw")
	var bad := kitchen.prep(building_key, "cheese_bad")
	for i in _tray.size():
		var spr: Sprite3D = _tray[i]
		spr.visible = i < good + bad
		if spr.visible:
			bretex(spr, "cheese_patchy" if i >= good else "cheese_breaded", 0.8)
			put(spr, TRAY.position + Vector2(30 + (i % 2) * 46, 26 + (i / 2) * 38), 0.012)
	_slice_spr.visible = _slice
	if not _slice:
		return
	bretex(_slice_spr, _stage())
	var at := HAND
	var lift := 0.02
	if _held_at.x > -500.0 and _held_at.x >= 0.0:
		at = _held_at
		lift = 0.08
	if _dip >= 0.0 and _dip_bowl >= 0:
		# Down into the bowl and back, in steps.
		var bowl: Rect2 = BOWLS[_dip_bowl]
		var k := sin(floorf(clampf(_dip / 0.45, 0.0, 1.0) * 6.0) / 6.0 * PI)
		at = at.lerp(bowl.get_center(), k)
		lift = lerpf(lift, 0.0, k)
		put(_slice_spr, at, lift)
	elif _held == "slice":
		_slice_spr.position = held_at(0.08)
	else:
		put(_slice_spr, at, lift)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var stock: int = maxi(0, BUSINESS.stock_of(building_key, "cheese"))
	if not _slice:
		if stock > 0:
			out.append({"id": "block", "rect": BLOCK, "verb": "Cut a slice of cheese (%d in the cellar)" % stock})
	elif _dip < 0.0:
		var names := ["flour", "egg", "crumbs"]
		for i in 3:
			out.append({"id": "bowl:%d" % i, "rect": BOWLS[i], "verb": "Into the %s" % names[i]})
		out.append({"id": "tray", "rect": TRAY, "verb": "Onto the tray" + ("" if _good() else " (badly breaded)")})
		out.append({"id": "slice", "node": _slice_spr, "verb": "Take the slice"})
	return out


func _press(id: String) -> void:
	if _dip >= 0.0:
		return
	_press_at = _mouse
	_far = false
	if id == "block":
		if not kitchen.room_for(building_key, "cheese_raw", 1 + kitchen.prep(building_key, "cheese_bad")):
			say("", "The tray is full. Fry some upstairs.")
			return
		if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"cheese": 1}):
			sfx("tick", -14.0, 0.7)
			return
		_slice = true
		_steps = []
		sfx("knife", -8.0)
		return
	if id == "slice":
		_held_at = _mouse_free
		return
	if id.begins_with("bowl:"):
		_dip_in(int(id.get_slice(":", 1)))
		return
	if id == "tray":
		_to_tray()


func _drag(at: Vector2) -> void:
	if at.x < -500.0 or _held == "":
		return
	if _press_at.x >= 0.0 and at.distance_to(_press_at) > DRAG_FAR:
		_far = true
	if _held == "slice":
		_held_at = at
		mark_target(_target_at(at) if _far else Rect2())


## The bowl or the tray a held slice is over (Rect2() none).
func _target_at(at: Vector2) -> Rect2:
	for i in 3:
		if (BOWLS[i] as Rect2).grow(10.0).has_point(at):
			return BOWLS[i]
	if TRAY.grow(16.0).has_point(at):
		return TRAY
	return Rect2()


func _release(id: String) -> void:
	if id != "slice":
		return
	mark_target(Rect2())
	var at := _held_at
	_held_at = Vector2(-1, -1)
	if not _far:
		return
	for i in 3:
		if (BOWLS[i] as Rect2).grow(10.0).has_point(at):
			_dip_in(i)
			return
	if TRAY.grow(16.0).has_point(at):
		_to_tray()


func _dip_in(b: int) -> void:
	_steps.append(b)
	_dip = 0.0
	_dip_bowl = b
	sfx(["flour", "egg", "crumbs"][b], -8.0)


func _to_tray() -> void:
	var good := _good()
	kitchen.act(building_key, "prep", ["cheese_raw" if good else "cheese_bad", 1])
	pop("+1" if good else "+1 POOR", TRAY.get_center() + Vector2(0, -50), RETRO_UI.C_GREEN_LIGHT if good else RETRO_UI.C_AMBER)
	if not good:
		say("", "That won't hold together in the pan.")
	_slice = false
	_steps = []
	sfx("plate_down", -10.0, 1.3)


func _tick(delta: float) -> void:
	if _dip >= 0.0:
		_dip += delta
		if _dip > 0.45:
			_dip = -1.0
			_dip_bowl = -1


func _closing() -> void:
	# A slice half breaded goes on the tray as it is.
	if _slice:
		kitchen.act(building_key, "prep", ["cheese_raw" if _good() else "cheese_bad", 1])
	_slice = false
	_steps = []
	_held_at = Vector2(-1, -1)


func bar_text() -> String:
	if kitchen == null:
		return ""
	return "TRAY %d  CHEESE %d" % [kitchen.prep(building_key, "cheese_raw") + kitchen.prep(building_key, "cheese_bad"), maxi(0, BUSINESS.stock_of(building_key, "cheese"))]


func has_rail() -> bool:
	return true


## The knife for the cheese block, the bare glove for the slices and the bowls.
func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	return "knife" if id == "block" else "open"

# ── debug (tools/bistro_shots.gd) ────────────────────────────────────────────

func debug_click(id: String) -> void:
	if id.begins_with("bowl:"):
		_dip_in(int(id.get_slice(":", 1)))
		_dip = -1.0
	else:
		_press(id)
