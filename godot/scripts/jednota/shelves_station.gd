extends "res://scripts/jednota/jednota_station.gd"

## The shelves (DESIGN.md §7b "The Jednota"): the long green rack at the back of the shop
## and the cage trolley beside it, worked standing in front of them (a wall:
## jednota_layout.SURFACES "shelves", the rack's picture st_rack its own quad). Every good
## has its place on the rack (jednota_rules.PLANOGRAM), a little picture of it on the
## shelf's edge; what is on the rack stands there, one by one (the shop's state: the
## guests take from it). The boxes made up in the storeroom wait on the trolley: take one
## (press on it), carry it to its place and let go: its goods go up onto the shelf as far
## as there is room; anywhere else it goes back on the trolley. What went off in the night
## lies at the end of its place, grey; a click throws it all out (actions.biz_bin).

const STATION_SIZE := Vector2(3.0, 1.6875)
## The rack in the station's design pixels (jednota_layout RACK_*): its shelves' tops
## (where the goods stand), how much room is over each, the shelves' inner ends.
const SHELF_Y := [126.5, 197.0, 262.4, 327.7]
const SHELF_ROOM := [38.0, 56.0, 49.0, 47.0]
const SHELF_X := Vector2(13.0, 456.0)
const TROLLEY_AT := Vector2(538, 360)
const TROLLEY_M := 1.3
const TROLLEY_OUT := 0.42
const BOX_M := 0.27
const GOOD_M := {"bread": 0.2, "roll": 0.19, "salami": 0.21, "milk": 0.2, "pickles": 0.15, "beer": 0.22,
	"icecream": 0.14, "sweets": 0.13, "veg": 0.17, "soap": 0.1, "cards": 0.09, "magazine": 0.18, "rum": 0.24}
const OFF := {"bread": "off_bread", "roll": "off_rolls", "milk": "off_milk", "salami": "off_salami", "veg": "off_potatoes", "pickles": "off_pickles"}
const MAX_UNITS := 8
const TROLLEY_PLACES := 8

## good -> [Sprite3D, ...] standing on its place.
var _units: Dictionary = {}
## good -> how many stand there now on the screen (it catches up with the state in steps).
var _shown: Dictionary = {}
var _labels: Array = []
var _trolley: Sprite3D
## The boxes on the trolley: [{box: Sprite3D, icon: Sprite3D, good}].
var _boxes: Array = []
var _offs: Array = []
var _held_box: Dictionary = {}
var _step_acc := 0.0


func _build() -> void:
	super._build()
	for g in RULES.all_goods():
		var list: Array = []
		for i in MAX_UNITS:
			var s := jsprite("goods_" + g, float(GOOD_M.get(g, 0.18)))
			s.visible = false
			list.append(s)
		_units[g] = list
		_shown[g] = -1
		# The little picture on the shelf's edge: what goes there.
		var r := slot_rect(g)
		var lab := jsprite("goods_" + g, 0.05)
		put(lab, Vector2(r.position.x + 16.0, r.end.y + 1.0), 0.03)
		_labels.append(lab)
	_trolley = jsprite("trolley", TROLLEY_M)
	put(_trolley, TROLLEY_AT, TROLLEY_OUT)
	for i in TROLLEY_PLACES:
		var b := jsprite("box_closed", BOX_M)
		var ic := jsprite("goods_bread", 0.11)
		b.visible = false
		ic.visible = false
		_boxes.append({"box": b, "icon": ic, "good": ""})
	_offs = [null, null, null, null]


## A good's place on the rack (design px): over its shelf, its share of the shelf's width.
static func slot_rect(good: String) -> Rect2:
	var at: Array = RULES.slot_of(good)
	if int(at[0]) < 0:
		return Rect2()
	var row: Array = RULES.PLANOGRAM[int(at[0])]
	var w := (SHELF_X.y - SHELF_X.x) / float(row.size())
	var x0 := SHELF_X.x + w * float(int(at[1]))
	var y := float(SHELF_Y[int(at[0])])
	var room := float(SHELF_ROOM[int(at[0])])
	return Rect2(x0, y - room, w, room + 12.0)


## Where a box sits on the trolley (design px of its foot, and how far out).
func _trolley_place(i: int) -> Vector2:
	var col := i % 2
	var row := i / 2
	return TROLLEY_AT + Vector2(-31.0 + col * 62.0, -30.0 - row * 60.0)


# ── what the state says ──────────────────────────────────────────────────────

func _show() -> void:
	if shop == null or building_key == "":
		return
	var shelf: Dictionary = shop.shelf(building_key)
	var cap: int = shop.cap(building_key)
	_step_acc += STEP
	var step := _step_acc >= 0.16
	if step:
		_step_acc = 0.0
	for g in RULES.all_goods():
		var want := mini(int(shelf.get(g, 0)), MAX_UNITS)
		var shown := int(_shown[g])
		if shown < 0 or want < shown:
			shown = want
		elif want > shown and step:
			# Up onto the shelf one by one.
			shown += 1
			sfx("shelve", -16.0, 0.9 + 0.05 * float(shown % 4))
		_shown[g] = shown
		var r := slot_rect(g)
		var gap := r.size.x / float(maxi(cap, 1))
		var list: Array = _units[g]
		for i in list.size():
			var s: Sprite3D = list[i]
			s.visible = i < shown
			if s.visible:
				put(s, Vector2(r.position.x + gap * (float(i) + 0.5), float(r.end.y) - 12.0), 0.02 + 0.004 * float(i % 2))
	# The boxes on the trolley, a box a six (BOX) of a good.
	var trolley: Dictionary = shop.trolley(building_key)
	var held_good := str(_held_box.get("good", ""))
	var i := 0
	for g in RULES.all_goods():
		var n := int(trolley.get(g, 0))
		var boxes := int(ceil(float(n) / float(RULES.BOX)))
		if g == held_good:
			boxes -= 1
		for k in boxes:
			if i >= _boxes.size():
				break
			var e: Dictionary = _boxes[i]
			e["good"] = g
			var b: Sprite3D = e["box"]
			var ic: Sprite3D = e["icon"]
			b.visible = true
			ic.visible = true
			jretex(ic, "goods_" + g, 0.11)
			put(b, _trolley_place(i), TROLLEY_OUT + 0.04)
			put(ic, _trolley_place(i) + Vector2(0, -14), TROLLEY_OUT + 0.07)
			i += 1
	for j in range(i, _boxes.size()):
		(_boxes[j]["box"] as Sprite3D).visible = false
		(_boxes[j]["icon"] as Sprite3D).visible = false
		_boxes[j]["good"] = ""
	# The box in the hand, right under the pointer.
	if not _held_box.is_empty():
		var hb: Sprite3D = _held_box["box"]
		var hi: Sprite3D = _held_box["icon"]
		hb.position = held_at(0.3) - Vector3(0, BOX_M * 0.5, 0)
		hi.position = hb.position + Vector3(0, BOX_M * 0.45, 0.12)
	_show_off()


## What went off: grey at the end of its place till it is thrown out.
func _show_off() -> void:
	var spoiled: Dictionary = BIZ.site(building_key).get("spoiled", {})
	var k := 0
	for g in OFF:
		if k >= _offs.size():
			break
		if int(spoiled.get(g, 0)) <= 0:
			continue
		var path := "res://assets/textury/camp/%s.png" % str(OFF[g])
		if not ResourceLoader.exists(path):
			continue
		var o = _offs[k]
		if o == null:
			o = sprite(path, 0.18, false)
			_offs[k] = o
		else:
			retex(o, path, 0.18)
		if (o as Sprite3D).texture != null:
			(o as Sprite3D).offset = Vector2(0, float((o as Sprite3D).texture.get_height()) * 0.5)
		(o as Sprite3D).visible = true
		var r := slot_rect(g)
		put(o, Vector2(r.end.x - 20.0, r.end.y - 12.0), 0.06)
		k += 1
	for j in range(k, _offs.size()):
		if _offs[j] != null:
			(_offs[j] as Sprite3D).visible = false


# ── what can be done ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	for e in _boxes:
		var b: Sprite3D = e["box"]
		if b.visible and str(e["good"]) != "":
			var g := str(e["good"])
			out.append({"id": "box:" + g, "node": b, "verb": "Take the box of %s" % str(RULES.goods().get(g, {}).get("label", g)).to_lower()})
	for o in _offs:
		if o != null and (o as Sprite3D).visible:
			out.append({"id": "off", "node": o, "verb": "Throw out what went off"})
	return out


func _press(id: String) -> void:
	if id == "off":
		if CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.has_method("biz_bin"):
			CoreRoot.actions.biz_bin(building_key)
		sfx("bin", -8.0)
		return
	if id.begins_with("box:"):
		var g := id.substr(4)
		var b := jsprite("box_closed", BOX_M)
		var ic := jsprite("goods_" + g, 0.11)
		_held_box = {"good": g, "box": b, "icon": ic}
		mark_target(slot_rect(g))
		sfx("box_lift", -10.0)


func _drag(_at: Vector2) -> void:
	if not _held_box.is_empty():
		mark_target(slot_rect(str(_held_box["good"])))


func _release(_id: String) -> void:
	if _held_box.is_empty():
		return
	var g := str(_held_box["good"])
	var r := slot_rect(g).grow(10.0)
	var moved := 0
	if r.has_point(_mouse_free):
		moved = shop.shelve(building_key, g)
		if moved <= 0:
			sfx("clunk", -8.0)
	else:
		sfx("box_down", -10.0)
	for k in ["box", "icon"]:
		var n = _held_box.get(k, null)
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_held_box = {}
	mark_target(Rect2())


func _closing() -> void:
	if not _held_box.is_empty():
		_release("")


func bar_text() -> String:
	if shop == null or building_key == "":
		return ""
	var boxes := 0
	for g in RULES.all_goods():
		boxes += int(ceil(float(int(shop.trolley(building_key).get(g, 0))) / float(RULES.BOX)))
	var empty := 0
	for g in RULES.all_goods():
		if int(shop.shelf(building_key).get(g, 0)) <= 0:
			empty += 1
	var text := "TROLLEY %d" % boxes
	if empty > 0:
		text += "   EMPTY %d" % empty
	return text


# ── debug (tools/jednota_check.gd, tools/jednota_shots.gd) ───────────────────

## A box of `good` off the trolley onto its place, as a warden would: the units moved.
func debug_shelve(good: String) -> int:
	_press("box:" + good)
	_mouse_free = slot_rect(good).get_center()
	var before := int(shop.shelf(building_key).get(good, 0))
	_release("box:" + good)
	return int(shop.shelf(building_key).get(good, 0)) - before


# ── the frame: the next step, the tab ────────────────────────────────────────

## What is best to do at the rack: what went off out, a box from the trolley for a place
## that is empty (carried to it); the storeroom when the trolley has none for it.
func next_hint() -> Dictionary:
	for o in _offs:
		if o != null and (o as Sprite3D).visible:
			return {"node": o, "gesture": "click"}
	var empty := empty_places()
	for e in _boxes:
		var b: Sprite3D = e["box"]
		if b.visible and str(e["good"]) in empty:
			return {"node": b, "gesture": "click"}
	if not empty.is_empty():
		return {"tab": "store"}
	return {}


## Places empty on the rack (the guests go without): amber, red when three or more are.
func alert() -> int:
	var n := empty_places().size()
	return 2 if n >= 3 else (1 if n > 0 else 0)
