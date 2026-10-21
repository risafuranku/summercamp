extends "res://scripts/bistro/bistro_station.gd"

## The floor (na place) of the bistro (the brief of 21. 10.: "the floor is drinks and
## serving; the plates from the kitchen pile up on the hatch and whoever is on the floor
## takes them to the guests"): the counter along the dining room's right wall, its top a
## Build texture (st_floor: the counter, the opener on its string, the crate of bottles).
##   the hatch    the plates rung out at the pass wait at the left of the counter, each
##                with its dish on it; a click on one (or SERVE: Space, Enter) takes the
##                picked ticket's plate (else the oldest) to its table: judged there (the
##                plate as the pass made it, how long they waited), the money, the tip,
##                the stars flying up
##   the crate    a click on its left (kofola) or its right (malinovka): a bottle out
##   the opener   hold it on the cap and lift: the cap flies off and lies where it lands
##   a bottle     a click (or SERVE) over the counter to the picked ticket of it (else the
##                oldest)
## The next step is lit: a plate waiting, the bottle wanted, the opener, SERVE; the pass
## when nothing is out yet. A hand on the floor (the books' STAFF) does all of it.

const HATCH := Rect2(20, 40, 380, 280)
const HATCH_SPOTS := [Vector2(90, 110), Vector2(210, 110), Vector2(330, 110), Vector2(90, 230), Vector2(210, 230), Vector2(330, 230)]
const CRATE := Rect2(522, 0, 118, 300)
const BOTTLE_AT := Vector2(450, 300)
const OPENER := Rect2(466, 40, 64, 190)
const BOTTLE_M := 0.24
const CAP_M := 0.03
const CAPS := 12
## The dish's own picture on its plate, bigger than the pass's (to be told at a glance:
## the brief's "I cannot tell chips from fried cheese").
const DISH_FOOD := {"goulash": "food_goulash", "smazak": "food_cheese", "fries": "food_fries", "sausage": "sausage_done", "soup": "bowl_soup"}
const PLATE_K := 1.25

var _bottle: Dictionary = {}
var _bottle_spr: Sprite3D
var _plates: Array = []          # [{plate, food, side}] sprites, one set a hatch spot
var _caps: Array = []
var _lift_y := -1.0
var _rng := RandomNumberGenerator.new()
var _known: Dictionary = {}


func where() -> String:
	return "floor"


func _build() -> void:
	super._build()
	_rng.randomize()
	for i in HATCH_SPOTS.size():
		var p := bsprite("plate_top", true, PLATE_K)
		var f := bsprite("food_cheese", true, PLATE_K)
		var s := bsprite("food_fries", true, PLATE_K)
		for n in [p, f, s]:
			(n as Sprite3D).visible = false
		_plates.append({"plate": p, "food": f, "side": s})
	_bottle_spr = sprite(TEX + "bottle_kofola.png", BOTTLE_M, false)
	_bottle_spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bottle_spr.visible = false


func _foot(s: Sprite3D) -> void:
	if s.texture != null:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)


## The plates on the hatch with their tickets, oldest first: [{t, rec, i}].
func _waiting() -> Array:
	var out: Array = []
	if kitchen == null or building_key == "":
		return out
	var by_id := {}
	for t in tickets():
		by_id[str(t["id"])] = t
	var i := 0
	for h in kitchen.hatch(building_key):
		if i >= HATCH_SPOTS.size():
			break
		var t: Dictionary = by_id.get(str(h["tid"]), {})
		if t.is_empty():
			continue
		out.append({"t": t, "rec": h, "i": i})
		i += 1
	return out


func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var waiting := _waiting()
	for k in _plates.size():
		var pl: Dictionary = _plates[k]
		var on := k < waiting.size()
		(pl["plate"] as Sprite3D).visible = on
		(pl["food"] as Sprite3D).visible = on
		(pl["side"] as Sprite3D).visible = false
		if not on:
			continue
		var w: Dictionary = waiting[k]
		var tid := str(w["t"]["id"])
		if not _known.has(tid):
			_known[tid] = true
			hop(pl["plate"])
		var at: Vector2 = HATCH_SPOTS[k]
		put(pl["plate"], at, 0.004)
		var dish := str(w["t"]["dish"])
		bretex(pl["food"], str(DISH_FOOD.get(dish, "food_cheese")), PLATE_K)
		put(pl["food"], at + Vector2(-8, -2), 0.012 + _hop_of(pl["plate"]))
		var parts: Dictionary = w["rec"].get("parts", {})
		var side := ""
		if dish == "smazak":
			side = "food_fries"
		elif dish == "goulash":
			side = "dumpling_slice"
		elif dish == "sausage":
			side = "food_bread"
		if side != "" and (dish != "goulash" or int(parts.get("dumpling", 0)) > 0):
			(pl["side"] as Sprite3D).visible = true
			bretex(pl["side"], side, PLATE_K * (1.3 if side == "dumpling_slice" else 1.0))
			put(pl["side"], at + Vector2(22, 6), 0.014 + _hop_of(pl["plate"]))
	_bottle_spr.visible = not _bottle.is_empty()
	if _bottle_spr.visible:
		var kind := str(_bottle["kind"])
		retex(_bottle_spr, TEX + "bottle_%s%s.png" % [kind, "_open" if bool(_bottle["open"]) else ""], BOTTLE_M)
		_foot(_bottle_spr)
		put(_bottle_spr, BOTTLE_AT, 0.0)
	# The caps: flying in an arc (smooth), then lying where they came down.
	for c in _caps:
		var s: Sprite3D = c["sprite"]
		var k := clampf(float(c["t"]) / 0.45, 0.0, 1.0)
		var at2: Vector2 = (c["from"] as Vector2).lerp(c["to"], k)
		put(s, at2, 0.006 + sin(k * PI) * 0.22)


func _tick(delta: float) -> void:
	for c in _caps:
		var was := float(c["t"])
		c["t"] = was + delta
		if was < 0.45 and float(c["t"]) >= 0.45:
			sfx("res://assets/sfx/bistro/tick.mp3", -10.0, _rng.randf_range(1.6, 2.0))


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	for w in _waiting():
		var t: Dictionary = w["t"]
		var pl: Dictionary = _plates[int(w["i"])]
		out.append({"id": "plate:" + str(t["id"]), "node": pl["plate"], "verb": "Out to %s: %s" % [ORDERS_first(str(t["name"])), RULES.dish_label(str(t["dish"])).to_lower()]})
	if _bottle.is_empty():
		out.append({"id": "crate_kofola", "rect": Rect2(CRATE.position, Vector2(CRATE.size.x * 0.5, CRATE.size.y)), "verb": "A kofola out of the crate (%d)" % maxi(0, BUSINESS.stock_of(building_key, "kofola"))})
		out.append({"id": "crate_malinovka", "rect": Rect2(CRATE.position + Vector2(CRATE.size.x * 0.5, 0), Vector2(CRATE.size.x * 0.5, CRATE.size.y)), "verb": "A malinovka out of the crate (%d)" % maxi(0, BUSINESS.stock_of(building_key, "malinovka"))})
	else:
		if not bool(_bottle["open"]):
			out.append({"id": "opener", "rect": OPENER, "verb": "Hold the opener on the cap and lift"})
			out.append({"id": "cap", "node": _bottle_spr, "verb": "Hold the opener on the cap and lift"})
		else:
			var tb := _ticket_for(str(_bottle["kind"]))
			out.append({"id": "bottle", "node": _bottle_spr, "verb": "Over the counter to %s" % ORDERS_first(str(tb["name"])) if not tb.is_empty() else "Nobody asked for it"})
	return out


## The picked ticket if it is for `dish`, else the oldest that is.
func _ticket_for(dish: String) -> Dictionary:
	var best := {}
	for t in tickets():
		if str(t["dish"]) != dish or bool(t.get("hatched", false)):
			continue
		if str(t["id"]) == picked:
			return t
		if best.is_empty():
			best = t
	return best


func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	match id:
		"opener", "cap":
			return "opener"
	return "open"


func _press(id: String) -> void:
	if id.begins_with("plate:"):
		_serve_plate(id.substr(6))
		return
	match id:
		"crate_kofola", "crate_malinovka":
			var kind := id.substr(6)
			if BUSINESS.stock_of(building_key, kind) == 0:
				say("", "No %s left." % RULES.dish_label(kind).to_lower())
				return
			_bottle = {"kind": kind, "open": false}
			sfx("res://assets/sfx/pub/glass_down.mp3", -8.0)
			hop(_bottle_spr)
		"opener", "cap":
			_lift_y = _vp_mouse.y
		"bottle":
			_serve_bottle()


func _drag(_at: Vector2) -> void:
	if not (_held in ["opener", "cap"]) or _lift_y < 0.0 or _bottle.is_empty() or bool(_bottle["open"]):
		return
	var full := 30.0
	if camera != null and is_instance_valid(camera):
		full = maxf(10.0, float(camera.get_viewport().size.y) * 0.08)
	if _lift_y - _vp_mouse.y >= full:
		_pop()


func _release(_id: String) -> void:
	_lift_y = -1.0


## The cap off: it flies and lies where it lands; the bottle open.
func _pop() -> void:
	_bottle["open"] = true
	_lift_y = -1.0
	sfx("res://assets/sfx/bistro/bottle_pop.mp3", -6.0, _rng.randf_range(0.95, 1.1))
	if _hands_ui != null and is_instance_valid(_hands_ui):
		_hands_ui.call("flash", "opener", 3)
	var s := sprite(TEX + "bottle_cap.png", CAP_M, true)
	var to := Vector2(_rng.randf_range(240, 500), _rng.randf_range(200, 350))
	_caps.append({"sprite": s, "from": BOTTLE_AT + Vector2(0, -20), "to": to, "t": 0.0})
	while _caps.size() > CAPS:
		var old: Dictionary = _caps.pop_front()
		(old["sprite"] as Node).queue_free()


## The plate of ticket `tid` off the hatch to its table.
func _serve_plate(tid: String) -> void:
	for w in _waiting():
		var t: Dictionary = w["t"]
		if str(t["id"]) != tid:
			continue
		var v: Dictionary = kitchen.serve_hatch(building_key, t)
		if not bool(v.get("ok", false)):
			say("", "None left." if str(v.get("why", "")) == "dry" else "")
			return
		var pl: Dictionary = _plates[int(w["i"])]
		fly(TEX + str(DISH_FOOD.get(str(t["dish"]), "plate_top")) + ".png", 0.16, (pl["plate"] as Node3D).position, guest_point(t), 0.5, 0.3)
		_after(v, t, RULES.dish_label(str(t["dish"])))
		return


func _serve_bottle() -> void:
	var kind := str(_bottle["kind"])
	var t := _ticket_for(kind)
	if t.is_empty():
		var other := _ticket_for("kofola" if kind == "malinovka" else "malinovka")
		say(ORDERS_first(str(other.get("name", ""))) if not other.is_empty() else "", "I asked for %s." % RULES.dish_label(str(other["dish"])).to_lower() if not other.is_empty() else "Nobody asked for it.")
		return
	var v: Dictionary = kitchen.serve(building_key, t, {kind: 1}, -1.0)
	if bool(v.get("ok", false)):
		fly(TEX + "bottle_%s_open.png" % kind, BOTTLE_M, local_at(BOTTLE_AT, 0.1), guest_point(t), 0.45, 0.25)
		_bottle = {}
	_after(v, t, RULES.dish_label(kind))


func _after(v: Dictionary, t: Dictionary, what: String) -> void:
	var who := ORDERS_first(str(t["name"]))
	if not bool(v.get("ok", false)):
		say(who, "None left." if str(v.get("why", "")) == "dry" else "That's not mine.")
		return
	if picked == str(t["id"]):
		picked = ""
	sfx("till", -8.0)
	v["build"] = float(v.get("accuracy", 1.0))
	score_card(v, what, _with_patience(t))
	var stars := int(v.get("stars", 1))
	if stars >= 3:
		say(who, ["Now that's food.", "Like at my mother's.", "Quick! Thank you.", "Dobrou chut, eh?"][_rng.randi() % 4])
	elif float(v.get("accuracy", 1.0)) < 0.85:
		say(who, ["Hm. Not quite what I asked for.", "Where's the rest of it?", "Close enough."][_rng.randi() % 3])
	else:
		say(who, ["Finally.", "Thought you'd gone fishing.", "Cheers."][_rng.randi() % 3])


## Where the guest of ticket `t` sits (their table), for the plate's flight and the stars.
func guest_point(t: Dictionary) -> Vector3:
	var life: Node = null
	if get_parent() != null:
		for c in get_parent().get_children():
			if c.has_method("headcount"):
				life = c
	if life == null:
		return Vector3.INF
	var people = life.get("_people")
	if not (people is Dictionary):
		return Vector3.INF
	var p: Dictionary = (people as Dictionary).get("%d:%d" % [int(t.get("guest_id", -1)), int(t.get("member", 0))], {})
	var n = p.get("node", null)
	if n is Node3D and is_instance_valid(n):
		return (n as Node3D).global_position + Vector3(0, 1.2, 0)
	return Vector3.INF


# ── the frame ────────────────────────────────────────────────────────────────

func serve_ready() -> bool:
	if not _waiting().is_empty():
		return true
	return not _bottle.is_empty() and bool(_bottle["open"]) and not _ticket_for(str(_bottle["kind"])).is_empty()


## SERVE: the picked ticket's plate (else the oldest on the hatch), else the open bottle.
func serve_now() -> void:
	var waiting := _waiting()
	for w in waiting:
		if str(w["t"]["id"]) == picked:
			_serve_plate(picked)
			return
	if not waiting.is_empty():
		_serve_plate(str(waiting[0]["t"]["id"]))
		return
	if not _bottle.is_empty() and bool(_bottle["open"]):
		_serve_bottle()


## The big ticket: the plate waiting longest, else the bottle wanted.
func big_ticket() -> Dictionary:
	for t in tickets():
		if str(t["id"]) == picked:
			return _with_patience(t)
	var waiting := _waiting()
	if not waiting.is_empty():
		return _with_patience(waiting[0]["t"])
	var tix := tickets()
	return _with_patience(tix[0]) if not tix.is_empty() else {}


## A bottle's checklist: the bottle, opened, SERVE.
func checklist(t: Dictionary) -> Array:
	var dish := str(t.get("dish", ""))
	if not RULES.DRINKS.has(dish):
		return super.checklist(t)
	var mine := not _bottle.is_empty() and str(_bottle["kind"]) == dish
	return [
		{"text": str(SHORT.get(dish, dish.to_upper())), "state": "done" if mine else ("bad" if not _bottle.is_empty() else "todo")},
		{"text": "OPENED", "state": "done" if mine and bool(_bottle["open"]) else "todo"},
	]


## What is best to do on the floor now: a plate on the hatch out (SERVE), the bottle
## wanted out of the crate, opened, SERVE; the pass when the plates are still to be made.
func next_hint() -> Dictionary:
	if kitchen == null or building_key == "":
		return {}
	if not _waiting().is_empty():
		return {"ui": "serve"}
	if not _bottle.is_empty():
		if not bool(_bottle["open"]):
			return {"node": _bottle_spr, "gesture": "drag", "to": BOTTLE_AT + Vector2(0, -80)}
		return {"ui": "serve"} if not _ticket_for(str(_bottle["kind"])).is_empty() else {}
	for t in tickets():
		var dish := str(t["dish"])
		if RULES.DRINKS.has(dish):
			var half := Rect2(CRATE.position + Vector2(CRATE.size.x * 0.5 if dish == "malinovka" else 0.0, 0), Vector2(CRATE.size.x * 0.5, CRATE.size.y))
			return {"rect": half, "gesture": "click"}
	if not kitchen.tickets(building_key, "pass").is_empty():
		return {"tab": "pass"}
	if not kitchen.tickets(building_key, "bufet").is_empty():
		return {"tab": "bufet"}
	return {}


## Plates waiting on the hatch: amber, red when their guest is in the red; bottles wanted:
## amber.
func alert() -> int:
	if kitchen == null or building_key == "":
		return 0
	var waiting := _waiting()
	for w in waiting:
		if RULES.patience_band(int(w["t"].get("age", 0))) == 2:
			return 2
	return 1 if not waiting.is_empty() or not tickets().is_empty() else 0


func bar_text() -> String:
	if kitchen == null or building_key == "":
		return ""
	return "HATCH %d  KOFOLA %d  MALINOVKA %d" % [kitchen.hatch(building_key).size(), maxi(0, BUSINESS.stock_of(building_key, "kofola")), maxi(0, BUSINESS.stock_of(building_key, "malinovka"))]


func _closing() -> void:
	_lift_y = -1.0
	_bottle = {}


# ── debug (tools/bistro_check.gd, tools/bistro_shots.gd) ─────────────────────

func debug_click(id: String) -> void:
	_press(id)


func debug_pop() -> void:
	if not _bottle.is_empty():
		_pop()


## The oldest plate on the hatch out to its table.
func debug_serve_first() -> bool:
	var waiting := _waiting()
	if waiting.is_empty():
		return false
	_serve_plate(str(waiting[0]["t"]["id"]))
	return true
