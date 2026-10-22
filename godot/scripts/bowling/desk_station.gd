extends "res://scripts/business/station3d.gd"

## The bowling alley's shoe counter (scripts/bowling/bowling_interior.gd hosts it; the
## alley's record scripts/bowling/bowling.gd): worked from behind the counter along the
## hall's left wall, the parties queuing across it.
##
## The first in the queue tells you their shoe sizes (their ticket: one a head). The
## rental shoes sit in the cubbies sunk along your edge of the counter, one cubby a size
## with its number on the lip: a click puts a pair of that size on the counter in front of
## them, a click on a pair there takes it back. The lamps on the right are the lanes, green
## the free ones (the first free is theirs, a click on another free one gives them that);
## SERVE hands it all over: they pay a game and the shoes a head and go to their lane (or a
## table to wait for one). A pair a size off pinches or flops and they say so (the score's
## build), how long they stood is its speed: Papa's stars and the tip.
## The pairs handed back by those who went pile up on the left: a click sprays one (the
## shoe spray off the books; the shoe dryer from the books spares it) and it goes back into
## its cubby. A size with no pairs left is an empty cubby.
## Design pixels on the counter (640 x 360 over its 2.6 m by 0.72 m): x from the lanes'
## end (your left) to the door's, y from the far edge (theirs) to yours.

const RULES := preload("res://core/systems/bowling_rules.gd")
const BOWLING := preload("res://scripts/bowling/bowling.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const KIT := preload("res://scripts/interior_kit.gd")
const LAYOUT := preload("res://scripts/bowling/bowling_layout.gd")
const BTEX := "res://assets/textury/bowling/"
const SIZES := BOWLING.SIZES
## The cubbies along your edge: the first one's left and the step, their band (design y).
const CUBBY_X0 := 22.0
const CUBBY_STEP := 42.6
const CUBBY_Y := Vector2(262, 352)
## Where the pairs for the one at the counter are put, a head each (design px).
const SLOTS := [Vector2(250, 112), Vector2(318, 112), Vector2(386, 112), Vector2(454, 112)]
const SLOT_R := Vector2(30, 70)
## The pairs handed back, in a heap on the left.
const BACK_AT := Vector2(78, 120)
const BACK_R := Vector2(62, 96)
## The lanes' lamps on the right.
const LAMPS := [Vector2(536, 200), Vector2(566, 200), Vector2(596, 200), Vector2(626, 200)]
const LAMP_R := 13.0
## A pair's size on the counter (the longer side, metres).
const PAIR_M := 0.2
const LINES := {"good": "Thanks.", "great": "Lovely, thank you.", "slow": "Finally.", "small": "These pinch.",
	"big": "I'm swimming in these.", "wait": "We'll wait for a lane, then.", "short": "That's not all of us."}

## What is on the counter for the one at it: visit -> [size or -1, one a head].
var _given: Dictionary = {}
## The lane picked for them (-1: the first free).
var _pick := -1
## Each cubby's pairs: the one in front, the one behind it (a second pair there).
var _cubby_pairs: Array = []
var _slot_pairs: Array = []
var _back_pairs: Array = []
var _lamps: Array = []
var _lamp_mats: Array = []
var _spray: Sprite3D
var _spray_t := -9.0
var _icon_shoes: Texture2D


func _build() -> void:
	fine = 2.0
	if state == null:
		state = BOWLING.of(get_tree())
	_icon_shoes = load(BTEX + "shoes_red.png") if ResourceLoader.exists(BTEX + "shoes_red.png") else null
	# The counter's top: its formica, at the room's pixel.
	var top := MeshInstance3D.new()
	top.name = "Top"
	var pm := PlaneMesh.new()
	pm.size = surf_size
	top.mesh = pm
	top.material_override = KIT.surface("formica", 0.8)
	top.position = Vector3(0, 0.001, 0)
	# What lies on it stays on it (retro_materials._pull_of).
	top.set_meta("retro_no_pull", true)
	add_child(top)
	# The cubbies sunk along your edge: a dark tray, a divider between each size, the size
	# painted on the lip.
	var wood := KIT.surface("veneer_dark", 0.6)
	var y0 := local_at(Vector2(0, CUBBY_Y.x)).z
	var y1 := local_at(Vector2(0, CUBBY_Y.y)).z
	KIT.slab(self, Vector3(surf_size.x - 0.04, 0.006, y1 - y0), Vector3(0, 0.004, (y0 + y1) * 0.5), KIT.surface("veneer_dark", 0.6, Color(0.45, 0.42, 0.4)), "CubbyFloor")
	for edge: float in [y0, y1]:
		KIT.slab(self, Vector3(surf_size.x - 0.04, 0.035, 0.012), Vector3(0, 0.018, edge), wood, "CubbyLip")
	for j in SIZES.size() + 1:
		var x := local_at(Vector2(CUBBY_X0 + CUBBY_STEP * float(j) - CUBBY_STEP * 0.5, 0)).x
		KIT.slab(self, Vector3(0.01, 0.035, y1 - y0), Vector3(x, 0.018, (y0 + y1) * 0.5), wood, "CubbyWall")
	for j in SIZES.size():
		var c := _cubby_center(j)
		var tex := BTEX + ("shoes_red.png" if j % 2 == 0 else "shoes_blue.png")
		var behind := sprite(tex, PAIR_M * 0.8, true)
		put(behind, c + Vector2(3, -14), 0.02)
		var front := sprite(tex, PAIR_M * 0.8, true)
		put(front, c + Vector2(-2, 2), 0.012)
		_cubby_pairs.append([front, behind])
		var n := _flat_label(str(SIZES[j]), Color(0.95, 0.9, 0.72), 0.55)
		n.position = local_at(Vector2(c.x, CUBBY_Y.y - 8), 0.037)
	for k in SLOTS.size():
		var s := sprite(BTEX + "shoes_red.png", PAIR_M, true)
		s.visible = false
		_slot_pairs.append(s)
	for k in 8:
		var s := sprite(BTEX + ("shoes_blue.png" if k % 2 == 0 else "shoes_red.png"), PAIR_M, true)
		s.visible = false
		s.rotation_degrees.y = float([18, -24, 40, -8, 70, -50, 5, 30][k])
		_back_pairs.append(s)
	# The lanes' lamps: a little panel with four bulbs and their numbers.
	KIT.slab(self, Vector3(metres_x(130.0), 0.02, 0.09), local_at(Vector2(581, 200), 0.01), wood, "LampPanel")
	for i in LAMPS.size():
		var b := MeshInstance3D.new()
		b.name = "Lamp%d" % (i + 1)
		var sm := SphereMesh.new()
		sm.radius = 0.016
		sm.height = 0.022
		sm.radial_segments = 8
		sm.rings = 4
		b.mesh = sm
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		m.albedo_color = Color(0.2, 0.2, 0.2)
		b.material_override = m
		b.set_meta("retro_skip", true)
		b.position = local_at(LAMPS[i], 0.03)
		add_child(b)
		_lamps.append(b)
		_lamp_mats.append(m)
		var n := _flat_label(str(i + 1), Color(0.95, 0.9, 0.72), 0.45)
		n.position = local_at(LAMPS[i] + Vector2(0, 26), 0.021)
	_spray = sprite(BTEX + "spray.png", 0.16, false)
	_spray.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_spray.visible = false


## A word painted flat on the counter, read from your side.
func _flat_label(text: String, col: Color, k: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = RETRO_UI.FONT_BIG
	l.font_size = 10
	l.pixel_size = k / PX_PER_M
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.modulate = col
	l.outline_size = 0
	l.rotation_degrees.x = -90.0
	add_child(l)
	return l


func _cubby_center(j: int) -> Vector2:
	return Vector2(CUBBY_X0 + CUBBY_STEP * float(j), (CUBBY_Y.x + CUBBY_Y.y) * 0.5)


func _cubby_rect(j: int) -> Rect2:
	var c := _cubby_center(j)
	return Rect2(c.x - CUBBY_STEP * 0.5 + 2.0, CUBBY_Y.x, CUBBY_STEP - 4.0, CUBBY_Y.y - CUBBY_Y.x)


func sfx_dir() -> String:
	return "res://assets/sfx/bowling/"


## A bowling sound, else the Jednota's, the pub's or the bistro's of the same name.
func sfx(n: String, db := -8.0, pitch := 1.0) -> void:
	if n.begins_with("res://"):
		super.sfx(n, db, pitch)
		return
	for d in [sfx_dir(), "res://assets/sfx/jednota/", "res://assets/sfx/pub/", "res://assets/sfx/bistro/"]:
		var p: String = d + n + ".mp3"
		if ResourceLoader.exists(p):
			super.sfx(p, db, pitch)
			return


func ding_sound() -> String:
	return "res://assets/sfx/town/shop_bell.mp3"


# ── what the record says ─────────────────────────────────────────────────────

func tickets() -> Array:
	return state.desk_tickets(building_key) if state != null and building_key != "" else []


## The one at the counter: the first in the queue ({} nobody).
func first() -> Dictionary:
	var q := tickets()
	return q[0] if not q.is_empty() else {}


func rail_tickets() -> Array:
	var out: Array = []
	var q := tickets()
	for i in q.size():
		var d: Dictionary = q[i].duplicate()
		d["picked"] = i == 0
		d["sig"] = "%d" % (d["sizes"] as Array).size()
		out.append(d)
	return out


func picked_ticket() -> String:
	return str(first().get("id", ""))


func big_ticket() -> Dictionary:
	return first()


func ticket_items(t: Dictionary) -> Array:
	var sizes: Array = t.get("sizes", [])
	var word := " ".join(sizes.map(func(s) -> String: return str(s))) if sizes.size() <= 2 else "x%d" % sizes.size()
	return [{"icon": _icon_shoes, "word": word}]


## The pairs on the counter for `t` (a size or -1 each head).
func given(t: Dictionary) -> Array:
	var visit := str(t.get("visit", ""))
	var n := (t.get("sizes", []) as Array).size()
	var g: Array = _given.get(visit, [])
	while g.size() < n:
		g.append(-1)
	_given[visit] = g
	return g


## The pairs of `size` in its cubby now (less those lying on the counter).
func available(size: int) -> int:
	var n := int(state.shelf(building_key).get(size, 0)) if state != null else 0
	for v in _given:
		for s in _given[v]:
			if int(s) == size:
				n -= 1
	return maxi(0, n)


## The lane they get: the one picked if it is still free, else the first free (-1 none).
func lane_for() -> int:
	if state == null:
		return -1
	if _pick >= 0 and str(state.lane(building_key, _pick).get("visit", "")) == "":
		return _pick
	return state.free_lane(building_key)


func checklist(t: Dictionary) -> Array:
	var out: Array = []
	var sizes: Array = t.get("sizes", [])
	var g := given(t)
	for k in sizes.size():
		var st := "todo"
		if int(g[k]) == int(sizes[k]):
			st = "done"
		elif int(g[k]) >= 0:
			st = "bad"
		out.append({"text": tr("Shoes %d") % int(sizes[k]), "state": st})
	var li := lane_for()
	out.append({"text": tr("Lane %d") % (li + 1) if li >= 0 else tr("Wait for a lane"), "state": "done" if li >= 0 else "todo"})
	return out


# ── what is shown ────────────────────────────────────────────────────────────

func _show() -> void:
	if state == null or building_key == "":
		return
	for j in SIZES.size():
		var n := available(int(SIZES[j]))
		(_cubby_pairs[j][0] as Sprite3D).visible = n > 0
		(_cubby_pairs[j][1] as Sprite3D).visible = n > 1
	var t := first()
	var g: Array = given(t) if not t.is_empty() else []
	for k in _slot_pairs.size():
		var s: Sprite3D = _slot_pairs[k]
		s.visible = k < g.size() and int(g[k]) >= 0
		if s.visible:
			retex(s, BTEX + ("shoes_red.png" if SIZES.find(int(g[k])) % 2 == 0 else "shoes_blue.png"), PAIR_M)
			put(s, SLOTS[k], 0.012)
	var back: Array = state.returned(building_key)
	for k in _back_pairs.size():
		var s: Sprite3D = _back_pairs[k]
		s.visible = k < back.size()
		if s.visible:
			put(s, BACK_AT + Vector2(float([0, 22, -18, 30, -10, 12, -26, 4][k]), float([0, -30, 34, 40, -44, 60, -64, -8][k])), 0.012 + 0.004 * k)
	var li := lane_for()
	for i in _lamps.size():
		var taken := str(state.lane(building_key, i).get("visit", "")) != ""
		var col := Color(0.85, 0.12, 0.08) if taken else (Color(1.0, 0.72, 0.2) if i == li and not t.is_empty() else Color(0.3, 0.9, 0.3))
		var m: StandardMaterial3D = _lamp_mats[i]
		m.albedo_color = col
		m.emission = col
		m.emission_energy_multiplier = 1.4 if (i == li and not t.is_empty() and int(_t * 3.0) % 2 == 0) else 0.8
	if _spray.visible:
		var k2 := (_t - _spray_t) / 0.45
		if k2 >= 1.0:
			_spray.visible = false
		else:
			put(_spray, BACK_AT + Vector2(-10, -40), 0.12 + 0.02 * sin(k2 * PI * 6.0))


# ── what can be done ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if state == null:
		return out
	var back: Array = state.returned(building_key)
	if not back.is_empty():
		out.append({"id": "back", "rect": Rect2(BACK_AT - BACK_R, BACK_R * 2.0), "verb": tr("Spray a pair handed back and shelve it (size %d)") % int(back[0])})
	var t := first()
	if t.is_empty():
		return out
	var g := given(t)
	var who := first_word(str(t.get("name", "")))
	for j in SIZES.size():
		var size := int(SIZES[j])
		if available(size) > 0 and g.has(-1):
			out.append({"id": "cubby:%d" % size, "rect": _cubby_rect(j), "verb": tr("A pair of %d for %s") % [size, who]})
	for k in mini(g.size(), _slot_pairs.size()):
		if int(g[k]) >= 0:
			out.append({"id": "slot:%d" % k, "node": _slot_pairs[k], "verb": tr("Take the %d back") % int(g[k])})
	for i in LAMPS.size():
		if str(state.lane(building_key, i).get("visit", "")) == "" and i != lane_for():
			out.append({"id": "lamp:%d" % i, "rect": Rect2(LAMPS[i] - Vector2(LAMP_R, LAMP_R), Vector2(LAMP_R, LAMP_R) * 2.0), "verb": tr("Give them lane %d") % (i + 1)})
	return out


func _press(id: String) -> void:
	if id == "back":
		_shelve_one()
		return
	var t := first()
	if t.is_empty():
		return
	var g := given(t)
	if id.begins_with("cubby:"):
		var size := int(id.substr(6))
		var k := g.find(-1)
		if k < 0 or available(size) <= 0:
			return
		g[k] = size
		var j := SIZES.find(size)
		fly(BTEX + ("shoes_red.png" if j % 2 == 0 else "shoes_blue.png"), PAIR_M, local_at(_cubby_center(j), 0.02), global_transform * local_at(SLOTS[k], 0.012), 0.25, 0.12)
		sfx("shoes", -10.0, randf_range(0.95, 1.08))
		return
	if id.begins_with("slot:"):
		var k2 := int(id.substr(5))
		if k2 < g.size() and int(g[k2]) >= 0:
			var j2 := SIZES.find(int(g[k2]))
			g[k2] = -1
			if j2 >= 0:
				fly(BTEX + ("shoes_red.png" if j2 % 2 == 0 else "shoes_blue.png"), PAIR_M, local_at(SLOTS[k2], 0.02), global_transform * local_at(_cubby_center(j2), 0.012), 0.22, 0.1)
			sfx("shoes", -14.0, 0.85)
		return
	if id.begins_with("lamp:"):
		_pick = int(id.substr(5))
		sfx("res://assets/sfx/ui/click.mp3", -12.0)


## The pair on top of the heap handed back: sprayed and into its cubby.
func _shelve_one() -> void:
	var back: Array = state.returned(building_key)
	if back.is_empty():
		return
	var idx := back.size() - 1
	var size: int = state.shelve_returned(building_key, idx)
	if size < 0:
		return
	# With the shoe dryer from the books they come back dry: no spray.
	if BUSINESS.has_gear(building_key, "dryer"):
		sfx("shoes", -12.0, 0.9)
	else:
		_spray.visible = true
		_spray_t = _t
		sfx("spray", -10.0, randf_range(0.95, 1.05))
	var j := SIZES.find(size)
	if j >= 0:
		fly(BTEX + ("shoes_red.png" if j % 2 == 0 else "shoes_blue.png"), PAIR_M, local_at(BACK_AT, 0.02), global_transform * local_at(_cubby_center(j), 0.012), 0.35, 0.15)


## SERVE: they have a pair each: they pay and go to their lane.
func serve_ready() -> bool:
	var t := first()
	return not t.is_empty() and not given(t).has(-1)


func serve_now() -> void:
	var t := first()
	if t.is_empty():
		return
	var g := given(t)
	var who := first_word(str(t.get("name", "")))
	if g.has(-1):
		say(who, tr(LINES["short"]))
		return
	var sizes: Array = t["sizes"]
	var fit := 0.0
	var small := false
	var big := false
	for k in sizes.size():
		var d := int(g[k]) - int(sizes[k])
		fit += 1.0 if d == 0 else (0.5 if absi(d) == 1 else 0.0)
		small = small or d < 0
		big = big or d > 0
	fit /= float(maxi(1, sizes.size()))
	var li := lane_for()
	var sale: Dictionary = state.check_in(building_key, str(t["visit"]), true, li, g.duplicate())
	if sale.is_empty():
		return
	_given.erase(str(t["visit"]))
	_pick = -1
	var age := float(t.get("age", 0.0))
	var speed := 1.0 - clampf((age - 6.0) / (BOWLING.DESK_GONE - 6.0), 0.0, 1.0)
	var pts := RULES_BIZ.score(speed, fit)
	var price := int(sale["amount"])
	var r := RULES_BIZ.reward(pts, price)
	var tip := int(r["tip"])
	if tip > 0 and CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_sale(building_key, tip, 0, true)
	var line: String = LINES["good"]
	if small and fit < 1.0:
		line = LINES["small"]
	elif big and fit < 1.0:
		line = LINES["big"]
	elif speed < 0.3:
		line = LINES["slow"]
	elif int(sale["lane"]) < 0:
		line = LINES["wait"]
	elif int(r["stars"]) >= 3:
		line = LINES["great"]
	say(who, tr(line))
	sfx("till", -8.0)
	var guest := int(t.get("guest", 0))
	var thought := "The camp has its own bowling alley. Real lanes!"
	if fit < 1.0:
		thought = "The bowling shoes didn't fit."
	elif speed < 0.3:
		thought = "Queued forever for bowling shoes."
	ORDERS.mood(guest, float(r["mood"]) + (1.0 if fit >= 1.0 else -2.0), thought)
	ORDERS.note_meal(guest, thought, pts)
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_score(building_key, {"score": pts, "tip": tip, "what": "Lane and shoes", "who": str(t.get("name", "")), "hand": false})
	pop("+$%d" % (price + tip), SLOTS[1] + Vector2(34, -40), RETRO_UI.C_GREEN if int(r["stars"]) >= 2 else RETRO_UI.C_AMBER)
	score_card({"ok": true, "score": pts, "stars": int(r["stars"]), "tip": tip, "amount": price + tip, "speed": speed, "build": fit}, "Lane and shoes", t)


## Where the one at the counter stands (global), for the stars over them.
func guest_point(_t: Dictionary) -> Vector3:
	var p := get_parent() as Node3D
	var q: Vector3 = LAYOUT.DESK_QUEUE[0][0]
	return p.to_global(q + Vector3(0, 1.75, 0)) if p != null else Vector3.INF


## What is best to do now: a pair for the first head without the right one (a wrong one
## back first), SERVE; with nobody at the counter, the heap handed back.
func next_hint() -> Dictionary:
	var t := first()
	if t.is_empty():
		if state != null and not (state.returned(building_key) as Array).is_empty():
			return {"rect": Rect2(BACK_AT - BACK_R, BACK_R * 2.0), "gesture": "click"}
		return {}
	var g := given(t)
	var sizes: Array = t["sizes"]
	for k in sizes.size():
		if int(g[k]) >= 0 and int(g[k]) != int(sizes[k]) and available(int(sizes[k])) > 0:
			return {"node": _slot_pairs[k], "gesture": "click"}
	for k in sizes.size():
		if int(g[k]) < 0:
			var size := int(sizes[k])
			for d in [0, 1, -1]:
				var j := SIZES.find(size + d)
				if j >= 0 and available(size + d) > 0:
					return {"rect": _cubby_rect(j), "gesture": "click"}
			return {}
	return {"ui": "serve"}


func alert() -> int:
	var t := first()
	if not t.is_empty():
		return 2 if int(t.get("band", 0)) == 2 else 1
	if state != null and (state.returned(building_key) as Array).size() >= 4:
		return 1
	return 0


func bar_text() -> String:
	var n := tickets().size()
	var back := (state.returned(building_key) as Array).size() if state != null else 0
	var parts: Array = []
	if n > 0:
		parts.append(tr("QUEUE %d") % n)
	if back > 0:
		parts.append(tr("SHOES BACK %d") % back)
	return "  ".join(parts)


func _key(e: InputEventKey) -> void:
	if e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if serve_ready():
			serve_now()


## The open hand for the shoes, the spray can over the heap, a finger for the lamps.
func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	if id == "back":
		return "bottle"
	if id.begins_with("lamp:"):
		return "press"
	return "open"


# ── debug (the shot drivers) ─────────────────────────────────────────────────

## A click on `id` as if the pointer pressed it.
func debug_click(id: String) -> void:
	_press(id)


## The first in the queue given the right pairs (the nearest when a size is out) and
## served: the verdict ({} nobody there).
func debug_serve_right() -> Dictionary:
	var t := first()
	if t.is_empty():
		return {}
	for size in t["sizes"]:
		for d in [0, 1, -1, 2, -2]:
			if available(int(size) + d) > 0:
				_press("cubby:%d" % (int(size) + d))
				break
	serve_now()
	return {"served": str(t["visit"])}
