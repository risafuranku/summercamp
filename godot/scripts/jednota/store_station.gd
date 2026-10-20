extends "res://scripts/jednota/jednota_station.gd"

## The storeroom (DESIGN.md §7b "The Jednota"): the packing table (the Build picture
## st_store: the knife, the tape, the labels, the price gun), behind it on the back wall
## the shelf of cartons off the van (the books' stock not yet on the rack or the trolley,
## jednota.backroom: what the rack will run out of first on the lower board), the cage
## trolley right of the table. A carton clicked comes onto the table; drag across its tape to cut
## it open (the pallet truck, gear: they come open); hold on it and the price gun prices
## the goods in it; priced, it goes onto the trolley (jednota.make_box) for the shelves.
## What went off in the night lies grey by the pallet; a click throws it all out.

const STATION_SIZE := Vector2(1.6, 0.525)
## On the table (design px over st_store): where a carton is worked.
const BOX_AT := Vector2(395, 262)
const BOX_M := 0.34
## On the floor round the table (this node's space, metres: the table top is 0).
const FLOOR := -0.855
## The cartons' shelf (jednota_layout.CARTON_SHELF_Y, its boards at 0.62 and 1.22 m, 0.82 m
## behind the table's middle), the trolley beside the table's right end (the camera stands
## a little to that side: jednota_layout SURFACES "cam_side"), where what went off waits
## (by the pallet).
const SHELF_LOCAL := [-0.285, 0.315]
const SHELF_Z := -0.82
const TROLLEY_AT := Vector3(1.22, FLOOR, 0.0)
const OFF_AT := Vector3(-1.25, FLOOR, -0.1)
const TROLLEY_M := 1.3
const CARTON_M := 0.27
const CARTONS := 6
const TROLLEY_PLACES := 8
const OFF := {"bread": "off_bread", "roll": "off_rolls", "milk": "off_milk", "salami": "off_salami", "veg": "off_potatoes", "pickles": "off_pickles"}
## Seconds of the price gun a carton (a clack for every thing in it).
const PRICE_SEC := 0.75

## Set by the room: opens the books (BOOKS on the bar).
var open_books: Callable
## The good of the last carton put on the trolley here.
var last_good := ""

var _cartons: Array = []
var _trolley: Sprite3D
var _boxes: Array = []
var _offs: Array = [null, null, null]
var _box: Sprite3D
var _box_icon: Sprite3D
var _meter: Sprite3D
## The carton on the table: {good, open (bool), cut (0..1), priced (0..1), from (Vector3),
## t (when it came)}; {} none. Its goods are still the storeroom's till it is on the trolley.
var _work: Dictionary = {}
var _cut_from := -1.0
var _pricing := false
var _clack_t := 0.0
## The carton going onto the trolley: {s, icon, from, to, t}.
var _away: Dictionary = {}


func _build() -> void:
	super._build()
	for i in CARTONS:
		var b := jsprite("box_closed", CARTON_M)
		var ic := jsprite("goods_bread", 0.1)
		b.visible = false
		ic.visible = false
		_cartons.append({"box": b, "icon": ic, "good": ""})
	_trolley = jsprite("trolley", TROLLEY_M)
	_trolley.position = TROLLEY_AT
	for i in TROLLEY_PLACES:
		var b := jsprite("box_closed", CARTON_M)
		var ic := jsprite("goods_bread", 0.1)
		b.visible = false
		ic.visible = false
		_boxes.append({"box": b, "icon": ic})
	_box = jsprite("box_closed", BOX_M)
	_box.visible = false
	_box_icon = jsprite("goods_bread", 0.12)
	_box_icon.visible = false
	_meter = meter(5, 18)
	_meter.visible = false


## The goods with cartons in the storeroom, what the rack will run out of first in front.
func carton_goods() -> Array:
	var out: Array = []
	if shop == null or building_key == "":
		return out
	for g in RULES.all_goods():
		if shop.backroom(building_key, g) > 0 and str(_work.get("good", "")) != g:
			out.append(g)
	var sh: Dictionary = shop.shelf(building_key)
	var tr: Dictionary = shop.trolley(building_key)
	out.sort_custom(func(a: String, b: String) -> bool:
		return int(sh.get(a, 0)) + int(tr.get(a, 0)) < int(sh.get(b, 0)) + int(tr.get(b, 0)))
	return out


func _carton_place(i: int) -> Vector3:
	var col := i % 3
	var row := i / 3
	return Vector3((float(col) - 1.0) * 0.5, float(SHELF_LOCAL[row]), SHELF_Z)


func _trolley_place(i: int) -> Vector3:
	return TROLLEY_AT + Vector3(-0.15 + float(i % 2) * 0.3, 0.12 + float(i / 2) * 0.27, 0.05)


# ── what the state says ──────────────────────────────────────────────────────

func _show() -> void:
	if shop == null or building_key == "":
		return
	var goods := carton_goods()
	for i in _cartons.size():
		var e: Dictionary = _cartons[i]
		var b: Sprite3D = e["box"]
		var ic: Sprite3D = e["icon"]
		b.visible = i < goods.size()
		ic.visible = b.visible
		e["good"] = str(goods[i]) if b.visible else ""
		if b.visible:
			jretex(ic, "goods_" + str(goods[i]), 0.1)
			b.position = _carton_place(i)
			ic.position = b.position + Vector3(0, 0.08, 0.02)
	var trolley: Dictionary = shop.trolley(building_key)
	var k := 0
	for g in RULES.all_goods():
		for n in int(ceil(float(int(trolley.get(g, 0))) / float(RULES.BOX))):
			if k >= _boxes.size():
				break
			var e2: Dictionary = _boxes[k]
			(e2["box"] as Sprite3D).visible = true
			(e2["icon"] as Sprite3D).visible = true
			jretex(e2["icon"], "goods_" + g, 0.1)
			(e2["box"] as Sprite3D).position = _trolley_place(k)
			(e2["icon"] as Sprite3D).position = _trolley_place(k) + Vector3(0, 0.08, 0.02)
			k += 1
	for j in range(k, _boxes.size()):
		(_boxes[j]["box"] as Sprite3D).visible = false
		(_boxes[j]["icon"] as Sprite3D).visible = false
	_show_work()
	_show_off()


func _show_work() -> void:
	if _work.is_empty():
		_box.visible = false
		_box_icon.visible = false
		_meter.visible = false
	else:
		var g := str(_work["good"])
		var opened := bool(_work["open"])
		jretex(_box, "box_open" if opened else "box_closed", BOX_M)
		jretex(_box_icon, "goods_" + g, 0.12)
		# Onto the table from the pallet, in steps.
		var k := clampf((_t - float(_work["t"])) / 0.35, 0.0, 1.0)
		k = floorf(k * 4.0) / 4.0
		var to := local_at(BOX_AT)
		var from: Vector3 = _work["from"]
		_box.position = from.lerp(to, k) + Vector3(0, 0.12 * sin(k * PI), 0)
		_box.visible = true
		_box_icon.visible = true
		_box_icon.position = _box.position + (Vector3(0, BOX_M * 0.62, -0.03) if opened else Vector3(0, 0.1, 0.03))
		_meter.visible = k >= 1.0
		_meter.position = local_at(BOX_AT + Vector2(64, -10), 0.12)
		var fill := float(_work["priced"]) if opened else float(_work["cut"])
		set_meter(_meter, fill, Vector2(-1, -1), RETRO_UI.C_GREEN if opened else RETRO_UI.C_AMBER)
	if not _away.is_empty():
		var s: Sprite3D = _away["s"]
		var ic: Sprite3D = _away["icon"]
		var f := clampf((_t - float(_away["t"])) / 0.4, 0.0, 1.0)
		f = floorf(f * 5.0) / 5.0
		s.position = (_away["from"] as Vector3).lerp(_away["to"], f) + Vector3(0, 0.1 * sin(f * PI), 0)
		ic.position = s.position + Vector3(0, 0.08, 0.02)
		if f >= 1.0:
			s.queue_free()
			ic.queue_free()
			_away = {}


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
			o = sprite(path, 0.2, false)
			_offs[k] = o
		else:
			retex(o, path, 0.2)
		if (o as Sprite3D).texture != null:
			(o as Sprite3D).offset = Vector2(0, float((o as Sprite3D).texture.get_height()) * 0.5)
		(o as Sprite3D).visible = true
		(o as Sprite3D).position = OFF_AT + Vector3(0.22 * float(k), 0.0, 0.0)
		k += 1
	for j in range(k, _offs.size()):
		if _offs[j] != null:
			(_offs[j] as Sprite3D).visible = false


# ── what can be done ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if _work.is_empty():
		for e in _cartons:
			if (e["box"] as Sprite3D).visible and str(e["good"]) != "":
				var g := str(e["good"])
				out.append({"id": "carton:" + g, "node": e["box"], "verb": "Take a carton of %s" % str(RULES.goods().get(g, {}).get("label", g)).to_lower()})
	elif _box.visible and clampf((_t - float(_work["t"])) / 0.35, 0.0, 1.0) >= 1.0:
		out.append({"id": "box", "node": _box, "verb": "Price the goods" if bool(_work["open"]) else "Cut the tape"})
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
	if id.begins_with("carton:"):
		var g := id.substr(7)
		var from := Vector3.ZERO
		for e in _cartons:
			if str(e["good"]) == g:
				from = (e["box"] as Sprite3D).position
		_work = {"good": g, "open": BIZ.has_gear(building_key, "pallet"), "cut": 0.0, "priced": 0.0, "from": from, "t": _t}
		sfx("box_lift", -8.0)
		return
	if id == "box" and not _work.is_empty():
		if bool(_work["open"]):
			_pricing = true
			_clack_t = 0.0
		else:
			_cut_from = _mouse_free.x


## Dragging the knife across the tape: how much of the carton's width it has crossed.
func _drag(at: Vector2) -> void:
	if _work.is_empty() or bool(_work["open"]) or _cut_from < 0.0 or at.x < -900.0:
		return
	var w := BOX_M / STATION_SIZE.x * DESIGN.x
	var crossed := absf(at.x - _cut_from) / w
	if crossed > float(_work["cut"]):
		if int(crossed * 6.0) != int(float(_work["cut"]) * 6.0):
			sfx("tape_rip", -12.0, 0.9 + 0.2 * crossed)
		_work["cut"] = minf(crossed, 1.0)
	if float(_work["cut"]) >= 0.85:
		_work["open"] = true
		_work["cut"] = 1.0
		_cut_from = -1.0
		sfx("box_open", -8.0)


func _release(_id: String) -> void:
	_pricing = false
	_cut_from = -1.0


func _tick(delta: float) -> void:
	if not _pricing or _work.is_empty() or not bool(_work["open"]):
		return
	_clack_t -= delta
	if _clack_t <= 0.0:
		_clack_t = PRICE_SEC / float(RULES.BOX)
		sfx("price_gun", -10.0, 0.95 + randf() * 0.1)
		pop("%d" % RULES.price(str(_work["good"])), BOX_AT + Vector2(randf_range(-30, 30), -60), RETRO_UI.C_BONE)
	_work["priced"] = minf(1.0, float(_work["priced"]) + delta / PRICE_SEC)
	if float(_work["priced"]) >= 1.0:
		_done()


## Priced: onto the trolley (the books' units move from the storeroom to it).
func _done() -> void:
	var g := str(_work["good"])
	_pricing = false
	var n: int = shop.make_box(building_key, g)
	if n > 0:
		last_good = g
		var s := jsprite("box_closed", CARTON_M)
		var ic := jsprite("goods_" + g, 0.1)
		var count := 0
		for e in _boxes:
			if (e["box"] as Sprite3D).visible:
				count += 1
		_away = {"s": s, "icon": ic, "from": _box.position, "to": _trolley_place(mini(count, TROLLEY_PLACES - 1)), "t": _t}
		sfx("box_down", -8.0)
	_work = {}


func _closing() -> void:
	_pricing = false
	_cut_from = -1.0


func bar_buttons() -> Array:
	return [{"id": "books", "label": "BOOKS"}]


func bar_button(id: String) -> void:
	if id == "books" and open_books.is_valid():
		open_books.call()


func bar_text() -> String:
	if shop == null or building_key == "":
		return ""
	var boxes := 0
	var cartons := 0
	for g in RULES.all_goods():
		boxes += int(ceil(float(int(shop.trolley(building_key).get(g, 0))) / float(RULES.BOX)))
		cartons += int(ceil(float(shop.backroom(building_key, g)) / float(RULES.BOX)))
	return "CARTONS %d   TROLLEY %d" % [cartons, boxes]


# ── debug (tools/jednota_check.gd, tools/jednota_shots.gd) ───────────────────

## A carton of `good` worked through as a warden would: onto the table, cut, priced, onto
## the trolley. The units moved to the trolley.
func debug_box(good: String) -> int:
	var before := int(shop.trolley(building_key).get(good, 0))
	_press("carton:" + good)
	if _work.is_empty():
		return 0
	_work["t"] = _t - 1.0
	if not bool(_work["open"]):
		_cut_from = 0.0
		_drag(Vector2(DESIGN.x, 0))
	_pricing = true
	_tick(PRICE_SEC + 0.1)
	return int(shop.trolley(building_key).get(good, 0)) - before
