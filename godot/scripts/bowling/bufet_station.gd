extends "res://scripts/business/station3d.gd"

## The bowling alley's snack bar (scripts/bowling/bowling_interior.gd hosts it; the orders
## are scripts/bowling/bowling.gd's): worked from behind its counter on the hall's right,
## the lanes beyond.
##
## The parties on their lanes send their orders over (the rail: the party's face, what they
## want, how long they have waited). What is on the counter: the hot dog steamer (a click,
## a frankfurter into a roll), the jar of utopenci, the crisps, the Tatranky, the Kofola tap
## and the beer tap (held: the glass fills, let go at the line; under it is flat, over it
## the foam runs down). It all goes onto the tray; a click on a thing there takes it off
## again. SERVE takes the tray over to their lane: they pay for what they wanted and got
## (the goods off the books), Papa's stars by how long they waited, how right it was and how
## well poured; it stands on their bench after.
## Design pixels on the counter (640 x 360 over its 2.4 m by 0.72 m): x from the front
## wall's end (your left) to the lanes', y from the far edge to yours.

const BOWLING := preload("res://scripts/bowling/bowling.gd")
const LAYOUT := preload("res://scripts/bowling/bowling_layout.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const KIT := preload("res://scripts/interior_kit.gd")
const BTEX := "res://assets/textury/bowling/"
## The things on the counter and where (design px).
const TRAY_AT := Vector2(300, 104)
const TRAY_SLOTS := [Vector2(256, 92), Vector2(300, 84), Vector2(344, 92), Vector2(278, 124), Vector2(322, 124)]
const STEAMER_AT := Vector2(80, 196)
const ROLLS_AT := Vector2(84, 300)
const JAR_AT := Vector2(176, 232)
const CRISPS_AT := Vector2(258, 290)
const WAFER_AT := Vector2(352, 300)
const TAPS := {"kofola": Vector2(440, 116), "beer": Vector2(510, 116)}
## Under a tap, where the glass stands while it fills.
const UNDER_TAP := Vector2(0, 74)
## The thing's sprite on the tray and on the bench, its size (metres).
const ITEM_TEX := {"beer": "beer", "kofola": "kofola", "hotdog": "hotdog", "pickled": "pickled", "crisps": "crisps", "tatranka": "wafer"}
const ITEM_M := {"beer": 0.17, "kofola": 0.15, "hotdog": 0.2, "pickled": 0.16, "crisps": 0.16, "tatranka": 0.15}
const ITEM_WORD := {"beer": "Beer", "kofola": "Kofola", "hotdog": "Hot dog", "pickled": "Utopenec", "crisps": "Crisps", "tatranka": "Tatranka"}
## Pouring: a glass full in this many seconds held; the line it should stop at.
const POUR_SEC := {"beer": 1.7, "kofola": 1.2}
const POUR_LINE := 0.88
const TRAY_MAX := 5
const LINES := {"good": "Thanks, mate.", "great": "Now that's a beer.", "slow": "About time.", "wrong": "That's not what we asked for.", "flat": "Half of it is foam."}

## The lanes' views (lane.gd), set by the hall: where the tray is taken.
var lanes: Array = []
var _tray: Array = []           # [{item, q, s: Sprite3D}]
var _pick := ""
var _pour: Dictionary = {}      # {item, fill, s: Sprite3D (the glass)} while a tap is held
var _meter: Sprite3D
var _icons: Dictionary = {}
var _stock_sprites: Array = []


func _build() -> void:
	fine = 2.0
	if state == null:
		state = BOWLING.of(get_tree())
	for it in ITEM_TEX:
		var p := BTEX + str(ITEM_TEX[it]) + ".png"
		_icons[it] = load(p) if ResourceLoader.exists(p) else null
	# The counter's top, the formica of the counter across the hall.
	var top := MeshInstance3D.new()
	top.name = "Top"
	var pm := PlaneMesh.new()
	pm.size = surf_size
	top.mesh = pm
	top.material_override = KIT.surface("formica", 0.8)
	top.position = Vector3(0, 0.001, 0)
	top.set_meta("retro_no_pull", true)
	add_child(top)
	_stand("tray", TRAY_AT, 0.42, true)
	_stand("steamer", STEAMER_AT, 0.36, false)
	_stand("rolls", ROLLS_AT, 0.28, false)
	_stand("pickled", JAR_AT, 0.2, false)
	for k in 3:
		_stand("crisps", CRISPS_AT + Vector2(-34 + k * 34, -8 + k * 10), 0.17, false)
		var w := _stand("wafer", WAFER_AT + Vector2(0, -14 + k * 14), 0.15, true)
		w.position.y += 0.006 * k
	_stand("tap_kofola", TAPS["kofola"], 0.34, false)
	_stand("tap_beer", TAPS["beer"], 0.4, false)
	_meter = meter(5, 18)
	_meter.visible = false


## A thing of the counter standing on it (or lying flat), its picture from the sheet.
func _stand(n: String, px: Vector2, metres: float, flat: bool) -> Sprite3D:
	var s := sprite(BTEX + n + ".png", metres, flat)
	if not flat and s.texture != null:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)
	# (Lying ones a little over the top: level with it they flicker under it.)
	put(s, px, 0.012 if flat else 0.002)
	_stock_sprites.append(s)
	return s


func sfx_dir() -> String:
	return "res://assets/sfx/bowling/"


## A bowling sound, else the pub's or the bistro's of the same name.
func sfx(n: String, db := -8.0, pitch := 1.0) -> void:
	if n.begins_with("res://"):
		super.sfx(n, db, pitch)
		return
	for d in [sfx_dir(), "res://assets/sfx/pub/", "res://assets/sfx/bistro/"]:
		var p: String = d + n + ".mp3"
		if ResourceLoader.exists(p):
			super.sfx(p, db, pitch)
			return


func ding_sound() -> String:
	return "res://assets/sfx/pub/order_in.mp3"


# ── the orders ───────────────────────────────────────────────────────────────

func tickets() -> Array:
	return state.bufet_tickets(building_key) if state != null and building_key != "" else []


## The order being made: the one picked on the rail, else the oldest.
func current() -> Dictionary:
	var q := tickets()
	for t in q:
		if str(t["id"]) == _pick:
			return t
	return q[0] if not q.is_empty() else {}


func rail_tickets() -> Array:
	var out: Array = []
	var cur := str(current().get("id", ""))
	for t in tickets():
		var d: Dictionary = t.duplicate()
		d["picked"] = str(d["id"]) == cur
		d["sig"] = "%d" % (d["items"] as Array).size()
		out.append(d)
	return out


func picked_ticket() -> String:
	return str(current().get("id", ""))


func rail_clicked(id: String) -> void:
	_pick = id
	sfx("pencil", -16.0)


func big_ticket() -> Dictionary:
	return current()


func ticket_items(t: Dictionary) -> Array:
	var out: Array = []
	for item in t.get("items", []):
		out.append({"icon": _icons.get(str(item)), "word": "x%d" % (t["items"] as Array).size() if (t["items"] as Array).size() > 1 else str(ITEM_WORD.get(str(item), item))})
	return out


func checklist(t: Dictionary) -> Array:
	var out: Array = []
	var on: Array = _tray.map(func(e) -> String: return str(e["item"]))
	for item in t.get("items", []):
		var at := on.find(item)
		out.append({"text": tr(str(ITEM_WORD.get(str(item), item))), "state": "done" if at >= 0 else "todo"})
		if at >= 0:
			on.remove_at(at)
	for extra in on:
		out.append({"text": tr(str(ITEM_WORD.get(str(extra), extra))), "state": "bad"})
	out.append({"text": tr("Lane %d") % (int(t.get("lane", 0)) + 1), "state": "todo"})
	return out


# ── what is shown ────────────────────────────────────────────────────────────

func _show() -> void:
	for i in _tray.size():
		var e: Dictionary = _tray[i]
		put(e["s"], TRAY_SLOTS[i % TRAY_SLOTS.size()], 0.03)
	if not _pour.is_empty():
		var tap: Vector2 = TAPS[str(_pour["item"])]
		put(_pour["s"], tap + UNDER_TAP, 0.004)
		_meter.visible = true
		_meter.position = local_at(tap + UNDER_TAP + Vector2(26, 0), 0.06)
		var f := float(_pour["fill"])
		set_meter(_meter, minf(f, 1.0), Vector2(POUR_LINE - 0.06, POUR_LINE + 0.06), RETRO_UI.C_RED if f > 1.0 else RETRO_UI.C_AMBER)
	else:
		_meter.visible = false


func _tick(delta: float) -> void:
	if _pour.is_empty():
		return
	_pour["fill"] = float(_pour["fill"]) + delta / float(POUR_SEC.get(str(_pour["item"]), 1.5))
	# Past the brim the foam runs down; let go of it at last.
	if float(_pour["fill"]) > 1.25:
		_finish_pour()


# ── what can be done ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if state == null:
		return out
	var menu: Array = state.bufet_menu(building_key)
	var room := _tray.size() < TRAY_MAX
	if room and menu.has("hotdog"):
		out.append({"id": "add:hotdog", "rect": Rect2(STEAMER_AT - Vector2(46, 60), Vector2(92, 80)), "verb": tr("A hot dog onto the tray")})
	if room and menu.has("pickled"):
		out.append({"id": "add:pickled", "rect": Rect2(JAR_AT - Vector2(24, 52), Vector2(48, 56)), "verb": tr("An utopenec out of the jar")})
	if room and menu.has("crisps"):
		out.append({"id": "add:crisps", "rect": Rect2(CRISPS_AT - Vector2(46, 46), Vector2(92, 64)), "verb": tr("A bag of crisps")})
	if room and menu.has("tatranka"):
		out.append({"id": "add:tatranka", "rect": Rect2(WAFER_AT - Vector2(34, 22), Vector2(68, 44)), "verb": tr("A Tatranka")})
	for it in TAPS:
		if room and menu.has(it):
			var tap: Vector2 = TAPS[it]
			out.append({"id": "tap:" + str(it), "rect": Rect2(tap - Vector2(30, 70), Vector2(60, 150)), "verb": tr("Hold to pour a beer") if it == "beer" else tr("Hold to pour a Kofola")})
	for i in _tray.size():
		out.append({"id": "off:%d" % i, "node": _tray[i]["s"], "verb": tr("Take it off the tray")})
	return out


func _press(id: String) -> void:
	if id.begins_with("add:"):
		_add(id.substr(4), 1.0, _src_of(id.substr(4)))
		return
	if id.begins_with("tap:"):
		var it := id.substr(4)
		var g := sprite(BTEX + ("glass_beer.png" if it == "beer" else "glass_tall.png"), 0.16 if it == "beer" else 0.14, false)
		if g.texture != null:
			g.offset = Vector2(0, float(g.texture.get_height()) * 0.5)
		_pour = {"item": it, "fill": 0.0, "s": g}
		sfx("tap_open", -12.0)
		sfx("tap_pour", -10.0, 1.0 if it == "beer" else 1.15)
		return
	if id.begins_with("off:"):
		var i := int(id.substr(4))
		if i < _tray.size():
			var e: Dictionary = _tray[i]
			(e["s"] as Node).queue_free()
			_tray.remove_at(i)
			sfx("glass_down", -14.0, 0.8)


func _release(id: String) -> void:
	if id.begins_with("tap:") and not _pour.is_empty():
		_finish_pour()


func _finish_pour() -> void:
	var it := str(_pour["item"])
	var f := float(_pour["fill"])
	var g: Sprite3D = _pour["s"]
	g.queue_free()
	_pour = {}
	sfx("tap_close", -12.0)
	if f < 0.2:
		return
	var q := clampf(1.0 - absf(f - POUR_LINE) * 3.5, 0.0, 1.0)
	_add(it, q, TAPS[it] + UNDER_TAP)


func _src_of(item: String) -> Vector2:
	match item:
		"hotdog":
			return STEAMER_AT
		"pickled":
			return JAR_AT
		"crisps":
			return CRISPS_AT
		"tatranka":
			return WAFER_AT
	return TRAY_AT


## A thing onto the tray (`q`: how well it was poured; `_from`: where it came from).
func _add(item: String, q: float, _from: Vector2) -> void:
	if _tray.size() >= TRAY_MAX:
		return
	var s := sprite(BTEX + str(ITEM_TEX.get(item, item)) + ".png", float(ITEM_M.get(item, 0.16)), false)
	if s.texture != null:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)
	_tray.append({"item": item, "q": q, "s": s})
	hop(s)
	put(s, TRAY_SLOTS[(_tray.size() - 1) % TRAY_SLOTS.size()], 0.03)
	match item:
		"crisps":
			sfx("crumbs", -12.0, 1.3)
		"hotdog", "pickled":
			sfx("plate_down", -12.0, 1.1)
		_:
			sfx("glass_down", -10.0)


func serve_ready() -> bool:
	return not _tray.is_empty() and not current().is_empty()


## SERVE: the tray taken over to their lane.
func serve_now() -> void:
	var t := current()
	if t.is_empty() or _tray.is_empty():
		return
	var built: Array = _tray.map(func(e) -> String: return str(e["item"]))
	var poured := 0
	var q := 0.0
	for e in _tray:
		if str(e["item"]) in ["beer", "kofola"]:
			poured += 1
			q += float(e["q"])
	var quality := q / float(poured) if poured > 0 else 1.0
	var v: Dictionary = state.serve_bufet(building_key, str(t["id"]), built, quality, true)
	var who := first_word(str(t.get("name", "")))
	if v.is_empty():
		return
	if not bool(v.get("ok", false)):
		say("", tr("The shelf has run out of it. Order more in the books."))
		return
	var r := RULES_BIZ.reward(int(v["score"]), maxi(1, int(v["amount"])))
	var tip := int(r["tip"])
	if tip > 0 and CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_sale(building_key, tip, 0, true)
	var line: String = LINES["good"]
	if float(v["fit"]) < 1.0:
		line = LINES["wrong"]
	elif quality < 0.5:
		line = LINES["flat"]
	elif float(v["speed"]) < 0.3:
		line = LINES["slow"]
	elif int(r["stars"]) >= 3:
		line = LINES["great"]
	say(who, tr(line))
	# Off across the hall to their bench.
	var to := guest_point(t)
	for e in _tray:
		var s: Sprite3D = e["s"]
		if to != Vector3.INF:
			fly(BTEX + str(ITEM_TEX.get(str(e["item"]), e["item"])) + ".png", float(ITEM_M.get(str(e["item"]), 0.16)), s.position, to, 0.6, 0.35)
		s.queue_free()
	_tray.clear()
	_pick = ""
	sfx("till", -9.0)
	pop("+$%d" % (int(v["amount"]) + tip), TRAY_AT + Vector2(0, -50), RETRO_UI.C_GREEN if int(r["stars"]) >= 2 else RETRO_UI.C_AMBER)
	score_card({"ok": true, "score": int(v["score"]), "stars": int(r["stars"]), "tip": tip, "amount": int(v["amount"]) + tip,
		"speed": float(v["speed"]), "build": float(v["fit"]) * quality}, "Snack bar", t)


## Where the party of order `t` sits: its lane's bench.
func guest_point(t: Dictionary) -> Vector3:
	var p := get_parent() as Node3D
	var li := int(t.get("lane", -1))
	if p == null or li < 0:
		return Vector3.INF
	return p.to_global(LAYOUT.snack_table(li) + Vector3(0, 0.15, 0))


## What is best to do: the next thing the order wants that is not on the tray yet, a wrong
## one off first, SERVE.
func next_hint() -> Dictionary:
	var t := current()
	if t.is_empty():
		return {}
	var want: Array = (t["items"] as Array).duplicate()
	for i in _tray.size():
		var at := want.find(_tray[i]["item"])
		if at >= 0:
			want.remove_at(at)
		else:
			return {"node": _tray[i]["s"], "gesture": "click"}
	if want.is_empty():
		return {"ui": "serve"}
	for s in _spots():
		var id := str(s["id"])
		if id == "add:" + str(want[0]):
			return {"rect": s["rect"], "gesture": "click"}
		if id == "tap:" + str(want[0]):
			return {"rect": s["rect"], "gesture": "hold"}
	return {}


func alert() -> int:
	var q := tickets()
	if q.is_empty():
		return 0
	return 2 if int(q[0].get("band", 0)) == 2 else 1


func bar_text() -> String:
	var n := tickets().size()
	return tr("ORDERS %d") % n if n > 0 else ""


func _key(e: InputEventKey) -> void:
	if e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and serve_ready():
		serve_now()


func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	if id.begins_with("tap:"):
		return "tap"
	if id.begins_with("add:"):
		return "tongs" if id == "add:hotdog" or id == "add:pickled" else "open"
	return "open"


func _closing() -> void:
	if not _pour.is_empty():
		(_pour["s"] as Node).queue_free()
		_pour = {}


# ── debug (the shot drivers) ─────────────────────────────────────────────────

## The current order made up right (the drinks poured to the line) and left on the tray.
func debug_make() -> int:
	var t := current()
	if t.is_empty():
		return 0
	for item in t["items"]:
		if str(item) in ["beer", "kofola"]:
			_press("tap:" + str(item))
			_pour["fill"] = POUR_LINE
			_finish_pour()
		else:
			_press("add:" + str(item))
	return _tray.size()


## A tap held a while (for a picture of the glass filling).
func debug_pour(item: String, fill: float) -> void:
	_press("tap:" + item)
	_pour["fill"] = fill
