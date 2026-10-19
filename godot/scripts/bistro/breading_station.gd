extends "res://scripts/bistro/station_view.gd"

## The breading table in the cellar (assets/textury/bistro/st_breading.png): the block of
## Edam on its board, three bowls (flour, egg, crumbs), the tray for the stove.
##   click the cheese: a slice off the block (off the books' shelf); then the bowls in
##   their order, flour, egg, crumbs: the slice goes in and comes out coated. Then the
##   tray. Out of order, or a bowl missed, and it is badly breaded: the cheese runs out
##   of it in the pan and it burns sooner (kitchen.gd prep "cheese_bad").

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const BLOCK := Rect2(10, 80, 145, 190)
const BOWLS := [Rect2(160, 118, 100, 104), Rect2(276, 118, 100, 104), Rect2(396, 118, 100, 104)]
const BOWL_NAMES := ["flour", "egg", "crumbs"]
const TRAY := Rect2(520, 95, 106, 168)
const HAND := Vector2(330, 290)

var _slice := false
var _steps: Array = []     # the bowls it has been through, in order
var _dip := -1.0           # the dip animation
var _dip_bowl := -1


func _ready() -> void:
	super._ready()
	station = "breading"
	room = "basement"
	picture = tex("st_breading")
	for n in ["cheese_plain", "cheese_floured", "cheese_egged", "cheese_breaded", "cheese_patchy", "slice_raw_small", "slice_bad_small"]:
		tex(n)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var stock: int = maxi(0, BUSINESS.stock_of(building_key, "cheese"))
	if not _slice:
		out.append({"id": "block", "rect": BLOCK, "verb": ("Cut a slice of cheese (%d in the cellar)" % stock) if stock > 0 else "No cheese: order some in the books"})
	else:
		for i in 3:
			out.append({"id": "bowl:%d" % i, "rect": BOWLS[i], "verb": "Into the %s" % BOWL_NAMES[i]})
		out.append({"id": "tray", "rect": TRAY, "verb": "Onto the tray" + ("" if _good() else " (badly breaded)")})
	return out


func _good() -> bool:
	return _steps == [0, 1, 2]


func _press(id: String) -> void:
	if _dip >= 0.0:
		return
	if id == "block":
		if not kitchen.room_for(building_key, "cheese_raw", 1 + kitchen.prep(building_key, "cheese_bad")):
			say("", "The tray is full. Fry some upstairs.")
			return
		if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"cheese": 1}):
			say("", "No cheese. Order some in the books.")
			sfx("tick", -14.0, 0.7)
			return
		_slice = true
		_steps = []
		sfx("knife", -8.0)
		return
	if id.begins_with("bowl:"):
		var b := int(id.get_slice(":", 1))
		_steps.append(b)
		_dip = 0.0
		_dip_bowl = b
		sfx(["flour", "egg", "crumbs"][b], -8.0)
		return
	if id == "tray":
		var good := _good()
		kitchen.act(building_key, "prep", ["cheese_raw" if good else "cheese_bad", 1])
		pop("+1" if good else "+1 POOR", TRAY.get_center() + Vector2(0, -40), RETRO_UI.C_GREEN_LIGHT if good else RETRO_UI.C_AMBER)
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


func _closing() -> void:
	# A slice half breaded goes on the tray as it is.
	if _slice:
		kitchen.act(building_key, "prep", ["cheese_raw" if _good() else "cheese_bad", 1])
	_slice = false
	_steps = []


## The slice's look after the bowls it has had.
func _stage() -> String:
	if _steps.is_empty():
		return "cheese_plain"
	var last := int(_steps[-1])
	if last == 2:
		return "cheese_breaded" if _good() else "cheese_patchy"
	return "cheese_egged" if last == 1 else "cheese_floured"


func _paint(c: Control) -> void:
	if kitchen == null:
		return
	# The tray: the breaded slices waiting for the stove.
	var good := kitchen.prep(building_key, "cheese_raw")
	var bad := kitchen.prep(building_key, "cheese_bad")
	for i in mini(8, good + bad):
		blit(c, "slice_bad_small" if i >= good and tex("slice_bad_small") != null else "slice_raw_small", TRAY.position + Vector2(26 + (i % 2) * 44, 22 + (i / 2) * 24))
	ink(c, TRAY.position + Vector2(4, TRAY.size.y + 10), "TRAY %d" % (good + bad), RETRO_UI.C_BONE)
	ink(c, BLOCK.position + Vector2(4, BLOCK.size.y + 10), "CHEESE %d" % maxi(0, BUSINESS.stock_of(building_key, "cheese")), RETRO_UI.C_BONE)
	# The order of the bowls, ticked as it goes.
	for i in 3:
		var r: Rect2 = BOWLS[i]
		var done := _steps.has(i)
		ink(c, Vector2(r.get_center().x - 3, r.end.y + 12), str(i + 1), RETRO_UI.C_GREEN_LIGHT if done else RETRO_UI.C_BONE_DIM, RETRO_UI.FONT_BIG, 10)
	if not _slice:
		return
	var at := HAND
	if _dip >= 0.0:
		# Down into the bowl and back.
		var bowl: Rect2 = BOWLS[_dip_bowl]
		var k := sin(clampf(_dip / 0.45, 0.0, 1.0) * PI)
		at = HAND.lerp(bowl.get_center(), k)
	var key := _stage()
	if tex(key) == null:
		key = "slice_raw_small"
	blit(c, key, at)
