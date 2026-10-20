extends "res://scripts/jednota/jednota_station.gd"

## The till (DESIGN.md §7b "The Jednota"): the counter top by the door, worked from behind
## it (the Build picture st_till: the basket's place on the left, the scale, the rubber
## mat, the till with its drawer on the right). The first in the queue has put their
## basket down: every thing in it is clicked through the till (it beeps, the till's
## display adds it up, it goes into their bag; the cabbage over the scale first). Then
## they put their money on the mat, mostly a note too big for it; a click takes it into
## the drawer. The change is counted out of the drawer's four places (1, 2, 5, 10) onto
## the mat, a piece back off it with a click; GIVE hands it over: short and they say so,
## too much and they keep it (jednota_rules.judge). Papa's score from how long they stood
## and how right the change was (jednota.serve). What is rung up and what is on the mat
## is the shop's state (jednota.gd ring, mat): everybody in the shop sees it.

## Design pixels on the counter (640 x 360 over st_till).
## The basket's goods lie in it (the basket is in the picture), a little askew.
const ITEM_SPOTS := [Vector2(74, 62), Vector2(120, 70), Vector2(76, 132), Vector2(122, 140), Vector2(72, 205), Vector2(120, 212)]
const ITEM_TURN := [-14.0, 18.0, 8.0, -20.0, 22.0, -6.0]
const SCALE_AT := Vector2(207, 104)
const MAT_AT := Vector2(320, 161)
const MAT_R := Vector2(36, 56)
const BAG_AT := Vector2(262, 34)
const DISPLAY_AT := Vector2(523, 70)
const DRAWER := [[1, Rect2(422, 247, 30, 83)], [2, Rect2(455, 247, 30, 83)], [5, Rect2(487, 247, 30, 83)], [10, Rect2(520, 247, 47, 83)]]
const PIECE_TEX := {1: "coin1", 2: "coin2", 5: "note5", 10: "note10", 20: "note20", 50: "note50"}
## The money a little bigger than life, so a coin is more than a speck on the mat.
const PIECE_M := {1: 0.04, 2: 0.046, 5: 0.085, 10: 0.085, 20: 0.085, 50: 0.085}
## The goods' size in the basket (the longer side, metres).
const GOOD_M := {"bread": 0.19, "roll": 0.16, "salami": 0.2, "milk": 0.17, "pickles": 0.12, "beer": 0.19,
	"icecream": 0.12, "sweets": 0.12, "veg": 0.16, "soap": 0.09}
const LINES := {"short": "That's short.", "over": "Thank you very much!", "slow": "Finally.", "good": "Thank you.", "great": "Thank you, dear."}

var _items: Array = []
var _bag: Sprite3D
var _paid: Array = []
var _change: Array = []
var _display: Label3D
var _display_box: MeshInstance3D
## Things flying off the counter into the bag: [{s, from, mid, to, t, dur}].
var _fly: Array = []
var _hold_t := 0.0
var _last_first := ""


func _build() -> void:
	super._build()
	for i in ITEM_SPOTS.size():
		var s := jsprite("goods_bread", 0.18, true)
		s.visible = false
		put(s, ITEM_SPOTS[i], 0.01 + 0.004 * float(i))
		s.rotation_degrees.y = float(ITEM_TURN[i])
		_items.append(s)
	_bag = jsprite("bag", 0.24)
	put(_bag, BAG_AT)
	_bag.visible = false
	for i in 4:
		var p := jsprite("note20", 0.085, true)
		p.visible = false
		_paid.append(p)
	for i in 12:
		var c := jsprite("coin1", 0.04, true)
		c.visible = false
		_change.append(c)
	# What is in the drawer's places, lying there.
	for d in DRAWER:
		var v := int(d[0])
		var r: Rect2 = d[1]
		for k in 3:
			var s := jsprite(str(PIECE_TEX[v]), float(PIECE_M[v]), true)
			if v >= 5:
				s.rotation_degrees.y = 90.0
			put(s, r.get_center() + Vector2(0, -22 + k * 22), 0.002 + 0.002 * k)
	# The till's display: green figures in a black box standing on it, to the cashier.
	_display_box = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.17, 0.075)
	_display_box.mesh = q
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.03, 0.05, 0.03)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_display_box.material_override = dm
	_display_box.position = local_at(DISPLAY_AT, 0.17)
	add_child(_display_box)
	_display = Label3D.new()
	_display.font = RETRO_UI.FONT_BIG
	_display.font_size = 10
	_display.pixel_size = 0.6 / PX_PER_M
	_display.shaded = false
	_display.double_sided = true
	_display.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_display.modulate = Color(0.55, 1.0, 0.45)
	_display.outline_size = 0
	_display.position = _display_box.position + Vector3(0, 0, 0.003)
	add_child(_display)


func has_rail() -> bool:
	return true


# ── what the state says ──────────────────────────────────────────────────────

static func rung_items(t: Dictionary) -> int:
	var n := 0
	for i in (t.get("rung", []) as Array):
		if int(i) >= 0:
			n += 1
	return n


static func all_rung(t: Dictionary) -> bool:
	return not t.is_empty() and rung_items(t) >= (t["items"] as Array).size()


static func money_taken(t: Dictionary) -> bool:
	return (t.get("rung", []) as Array).has(-1)


## What they put on the mat: the note (or for the right money, the coins and notes of it).
static func paid_pieces(t: Dictionary) -> Array:
	if int(t["paid"]) > 0:
		return [int(t["paid"])]
	var left := int(t["total"])
	var out: Array = []
	for v in [50, 20, 10, 5, 2, 1]:
		while left >= v and out.size() < 4:
			out.append(v)
			left -= v
	return out


static func running_total(t: Dictionary) -> int:
	var n := 0
	var items: Array = t["items"]
	for i in (t.get("rung", []) as Array):
		if int(i) >= 0 and int(i) < items.size():
			n += RULES.price(str(items[int(i)]))
	return n


func _show() -> void:
	var t := first()
	if str(t.get("id", "")) != _last_first:
		_last_first = str(t.get("id", ""))
		_fly.clear()
	var items: Array = t.get("items", [])
	var rung: Array = t.get("rung", [])
	for i in _items.size():
		var s: Sprite3D = _items[i]
		var on := i < items.size() and not rung.has(i) and not _flying(i)
		s.visible = on
		if i < items.size():
			var g := str(items[i])
			retex(s, JTEX + "goods_" + g + ".png", float(GOOD_M.get(g, 0.18)))
	_bag.visible = not t.is_empty() and rung_items(t) > 0
	# The money on the mat: theirs till it is taken, then the change counted out.
	var show_paid := all_rung(t) and not money_taken(t)
	var pp: Array = paid_pieces(t) if show_paid else []
	for i in _paid.size():
		var s: Sprite3D = _paid[i]
		s.visible = i < pp.size()
		if s.visible:
			var v := int(pp[i])
			retex(s, JTEX + str(PIECE_TEX.get(v, "note20")) + ".png", float(PIECE_M.get(v, 0.085)))
			put(s, MAT_AT + Vector2(-8 + i * 7, -14 + i * 9), 0.003 + 0.002 * i)
			s.rotation_degrees.y = 15.0 * float(i)
	var mat: Array = t.get("mat", [])
	var notes := 0
	var coins := 0
	for i in _change.size():
		var c: Sprite3D = _change[i]
		c.visible = money_taken(t) and i < mat.size()
		if c.visible:
			var v := int(mat[i])
			retex(c, JTEX + str(PIECE_TEX.get(v, "coin1")) + ".png", float(PIECE_M.get(v, 0.04)))
			c.rotation_degrees.y = 90.0 if v >= 5 else 0.0
			put(c, _mat_place(notes if v >= 5 else coins, v), 0.003 + 0.0015 * i)
			if v >= 5:
				notes += 1
			else:
				coins += 1
	if t.is_empty():
		_display.text = ""
	elif money_taken(t):
		_display.text = "%d" % int(t["due"])
	else:
		_display.text = "%d" % running_total(t)
	_step_fly()


## Where the change lies on the mat: the `i`th note fanned along the top, the `i`th coin
## in rows below.
func _mat_place(i: int, v: int) -> Vector2:
	if v >= 5:
		return MAT_AT + Vector2(-14 + i * 7, -20 + i * 3)
	return MAT_AT + Vector2(-26 + (i % 4) * 17, 22 + (i / 4) * 22)


func _flying(i: int) -> bool:
	for f in _fly:
		if int(f["i"]) == i:
			return true
	return false


func _step_fly() -> void:
	var keep: Array = []
	for f in _fly:
		var s: Sprite3D = f["s"]
		var k := clampf((_t - float(f["t"])) / float(f["dur"]), 0.0, 1.0)
		# Twelve steps a second: over the scale (the cabbage) or straight into the bag.
		var stepped := floorf(k * float(f["dur"]) * 12.0) / maxf(1.0, float(f["dur"]) * 12.0)
		var a: Vector2 = f["from"]
		var m: Vector2 = f["mid"]
		var b: Vector2 = f["to"]
		var p := a.lerp(m, stepped * 2.0) if stepped < 0.5 else m.lerp(b, (stepped - 0.5) * 2.0)
		put(s, p, 0.01 + 0.06 * sin(stepped * PI))
		if k >= 1.0:
			s.queue_free()
			continue
		keep.append(f)
	_fly = keep


# ── what can be done ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var t := first()
	var out: Array = []
	if t.is_empty():
		return out
	var items: Array = t["items"]
	var rung: Array = t["rung"]
	if not all_rung(t):
		for i in mini(items.size(), _items.size()):
			if not rung.has(i) and (_items[i] as Sprite3D).visible:
				var g := str(items[i])
				out.append({"id": "item:%d" % i, "node": _items[i], "verb": "Ring up the %s" % str(RULES.goods().get(g, {}).get("label", g)).to_lower()})
		return out
	if not money_taken(t):
		out.append({"id": "paid", "rect": Rect2(MAT_AT - MAT_R, MAT_R * 2.0), "verb": "Take the money"})
		return out
	for d in DRAWER:
		out.append({"id": "c:%d" % int(d[0]), "rect": d[1], "verb": "Count out %d" % int(d[0])})
	var mat: Array = t["mat"]
	for i in mini(mat.size(), _change.size()):
		out.append({"id": "back:%d" % i, "node": _change[i], "verb": "Take the %d back" % int(mat[i])})
	return out


func _press(id: String) -> void:
	var t := first()
	if t.is_empty():
		return
	var visit := str(t["visit"])
	if id.begins_with("item:"):
		if all_rung(t):
			return
		var i := int(id.substr(5))
		var items: Array = t["items"]
		if i >= items.size():
			return
		var g := str(items[i])
		shop.act(building_key, "ring", [visit, i])
		# The thing itself off the counter into the bag (the cabbage over the scale).
		var s := jsprite("goods_" + g, float(GOOD_M.get(g, 0.18)), true)
		s.rotation_degrees.y = float(ITEM_TURN[i % ITEM_TURN.size()])
		var from: Vector2 = ITEM_SPOTS[i]
		var mid := SCALE_AT if g == "veg" else from.lerp(BAG_AT, 0.5)
		_fly.append({"s": s, "i": i, "from": from, "mid": mid, "to": BAG_AT, "t": _t, "dur": 0.5 if g == "veg" else 0.3})
		sfx("beep", -10.0, 1.0 + 0.04 * float(i % 3))
		if all_rung(first()):
			sfx("till", -8.0)
		return
	if id == "paid":
		if not all_rung(t) or money_taken(t):
			return
		shop.act(building_key, "ring", [visit, -1])
		sfx("drawer", -8.0)
		if int(t["due"]) == 0:
			# The right money: nothing to count, they go.
			_give(first())
		return
	if not money_taken(t):
		return
	if id.begins_with("c:"):
		var mat: Array = (t["mat"] as Array).duplicate()
		if mat.size() >= _change.size():
			return
		var v := int(id.substr(2))
		mat.append(v)
		shop.act(building_key, "mat", [visit, mat])
		sfx("coin" if v < 5 else "note", -10.0, 1.0 + 0.05 * float(mat.size() % 3))
		return
	if id.begins_with("back:"):
		var mat2: Array = (t["mat"] as Array).duplicate()
		var j := int(id.substr(5))
		if j < mat2.size():
			mat2.remove_at(j)
			shop.act(building_key, "mat", [visit, mat2])
			sfx("coin", -14.0, 0.8)


## Hands the change over (`t` the one at the till, as it is now).
func _give(t: Dictionary) -> void:
	if t.is_empty() or not money_taken(t):
		return
	var given := sum_of(t["mat"])
	var who := first_name(str(t["name"]))
	var v: Dictionary = shop.serve(building_key, t, given)
	if not bool(v.get("ok", false)):
		say(who, LINES["short"])
		sfx("guest_grumble", -12.0)
		return
	var line: String = LINES["good"]
	if int(v.get("over", 0)) > 0:
		line = LINES["over"]
	elif float(v.get("speed", 1.0)) < 0.3:
		line = LINES["slow"]
	elif int(v.get("stars", 0)) >= 3:
		line = LINES["great"]
	say(who, line)
	pop("+$%d" % int(v.get("amount", 0)), MAT_AT + Vector2(0, -40), RETRO_UI.C_GREEN if int(v.get("stars", 0)) >= 2 else RETRO_UI.C_AMBER)
	sfx("bag", -10.0)


func bar_buttons() -> Array:
	var t := first()
	if t.is_empty() or not money_taken(t):
		return []
	var out: Array = [{"id": "give", "label": "GIVE"}]
	if not (t["mat"] as Array).is_empty():
		out.push_front({"id": "clear", "label": "CLEAR"})
	return out


func bar_button(id: String) -> void:
	var t := first()
	match id:
		"give":
			_give(t)
		"clear":
			if not t.is_empty():
				shop.act(building_key, "mat", [str(t["visit"]), []])
				sfx("coin", -12.0, 0.8)


func _key(e: InputEventKey) -> void:
	if e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_give(first())


func bar_text() -> String:
	var n := tickets().size()
	return "QUEUE %d" % n if n > 0 else ""


func big_ticket() -> Dictionary:
	return first()


# ── the warden at the till: its hand stands aside ────────────────────────────

func _me() -> String:
	return str(multiplayer.get_unique_id()) if Coop.is_active() else "me"


func _opened() -> void:
	_hold_t = 0.0
	if shop != null:
		shop.act(building_key, "till", [_me(), true])


func _tick(delta: float) -> void:
	_hold_t += delta
	if _hold_t >= 4.0 and shop != null:
		_hold_t = 0.0
		shop.act(building_key, "till", [_me(), true])


func _closing() -> void:
	if shop != null:
		shop.act(building_key, "till", [_me(), false])


# ── debug (tools/jednota_check.gd, tools/jednota_shots.gd) ───────────────────

## One more piece of the right change onto the mat (the biggest that still fits), as a
## warden counts it out; false when it is all there (tools/movie_driver.gd).
func debug_next_coin() -> bool:
	var t := first()
	if t.is_empty() or not money_taken(t):
		return false
	var left := int(t["due"]) - sum_of(t["mat"])
	for v in [10, 5, 2, 1]:
		if left >= v:
			_press("c:%d" % v)
			return true
	return false


## The first in the queue rung up, their money taken and the right change counted out:
## the verdict ({} nobody in the queue).
func debug_serve_right() -> Dictionary:
	var t := first()
	if t.is_empty():
		return {}
	var visit := str(t["visit"])
	for i in (t["items"] as Array).size():
		_press("item:%d" % i)
	_press("paid")
	t = _ticket_of(visit)
	if t.is_empty():
		return {"ok": true, "exact": true}
	var left := int(t["due"])
	var mat: Array = []
	for v in [10, 5, 2, 1]:
		while left >= v:
			mat.append(v)
			left -= v
	shop.act(building_key, "mat", [visit, mat])
	var v: Dictionary = shop.serve(building_key, _ticket_of(visit), sum_of(mat))
	return v


func _ticket_of(visit: String) -> Dictionary:
	for t in tickets():
		if str(t["visit"]) == visit:
			return t
	return {}
