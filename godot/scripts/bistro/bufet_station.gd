extends "res://scripts/bistro/bistro_station.gd"

## The bufet counter in the dining room (the brief of 20. 10.: "the soup of the day out of
## a big pot, quick and cheap; the big drinks in glass bottles, opened with the opener,
## the caps flying"). Its top is a Build texture (st_bufet: the soup pot on its hot plate,
## the bowls, the crate of bottles, the opener on its string); the things on it sprites.
##   the bowls    a click: a clean bowl under the ladle (the kitchen's plates and bowls)
##   the pot      a click: a ladle of soup into the bowl; two fill it, a third slops over
##   the crate    a click on its left (kofola) or its right (malinovka): a bottle out
##   the opener   hold it on the cap and lift: the cap flies off and lies where it lands
##   a bowl, a bottle   a click: over the counter to the picked ticket of it (else the
##                oldest): the soup of the day, a kofola, a malinovka
##   the tins     (the pot's foot) a click when it runs low: the books' soup into it
## The guests' soups and bottles are tickets of their own (bistro_rules: drink_wish).

## Where the Build picture (bistro/st_bufet.png) has them: the pot on its plate (its foot
## the tins), the stack of bowls, the opener on its string, the crate; a bowl and a bottle
## are worked on the bare top in front.
const POT := Rect2(4, 24, 166, 200)
const POT_AT := Vector2(82, 141)
const TINS := Rect2(4, 228, 166, 100)
const STACK := Rect2(180, 70, 112, 150)
const BOWL_AT := Vector2(262, 292)
const CRATE := Rect2(522, 0, 118, 300)
const BOTTLE_AT := Vector2(430, 290)
const OPENER := Rect2(466, 40, 64, 190)
const BOWL_M := 0.13
const BOTTLE_M := 0.24
const CAP_M := 0.03
## Caps that stay lying on the counter (the oldest goes when another lands).
const CAPS := 12

## The bowl at the pot: {ladles} ({} none); the bottle on the counter: {kind, open}.
var _bowl: Dictionary = {}
var _bottle: Dictionary = {}
var _bowl_spr: Sprite3D
var _bottle_spr: Sprite3D
var _level_spr: Sprite3D
var _stack: Array = []
var _caps: Array = []           # {sprite, from, to, t}
var _lift_y := -1.0
var _rng := RandomNumberGenerator.new()


func where() -> String:
	return "bufet"


func _build() -> void:
	super._build()
	_rng.randomize()
	for i in 4:
		var b := sprite(TEX + "bowl_empty.png", BOWL_M, false)
		if b.texture != null:
			b.offset = Vector2(0, float(b.texture.get_height()) * 0.5)
		put(b, STACK.get_center() + Vector2(0, 20), 0.0 + i * 0.022)
		_stack.append(b)
	_bowl_spr = sprite(TEX + "bowl_empty.png", BOWL_M, false)
	_bowl_spr.visible = false
	_bottle_spr = sprite(TEX + "bottle_kofola.png", BOTTLE_M, false)
	_bottle_spr.visible = false
	_level_spr = meter(5, 16)
	_level_spr.position = local_at(POT_AT + Vector2(-66, -96), 0.04)


func _foot(s: Sprite3D) -> void:
	if s.texture != null:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)


func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var clean := int(kitchen.plates(building_key)["clean"]) - (1 if not _bowl.is_empty() else 0)
	for i in _stack.size():
		(_stack[i] as Sprite3D).visible = i < mini(4, ceili(maxi(0, clean) / 3.0))
	_bowl_spr.visible = not _bowl.is_empty()
	if _bowl_spr.visible:
		retex(_bowl_spr, TEX + ("bowl_soup.png" if int(_bowl["ladles"]) > 0 else "bowl_empty.png"), BOWL_M)
		_foot(_bowl_spr)
		put(_bowl_spr, BOWL_AT, 0.0)
	_bottle_spr.visible = not _bottle.is_empty()
	if _bottle_spr.visible:
		var kind := str(_bottle["kind"])
		retex(_bottle_spr, TEX + "bottle_%s%s.png" % [kind, "_open" if bool(_bottle["open"]) else ""], BOTTLE_M)
		_foot(_bottle_spr)
		put(_bottle_spr, BOTTLE_AT, 0.0)
	var level := int(kitchen.site(building_key)["soup"]["level"])
	_level_spr.visible = is_open()
	set_meter(_level_spr, float(level) / float(RULES.SOUP_CAP), Vector2(-1, -1), RETRO_UI.C_AMBER if level > 3 else RETRO_UI.C_RED, level <= 2)
	# The caps: flying in an arc, in steps, then lying where they came down.
	for c in _caps:
		var s: Sprite3D = c["sprite"]
		var k := clampf(float(c["t"]) / 0.45, 0.0, 1.0)
		k = floorf(k * 6.0) / 6.0
		var at: Vector2 = (c["from"] as Vector2).lerp(c["to"], k)
		put(s, at, 0.006 + sin(k * PI) * 0.22 + (0.0 if k < 1.0 else 0.0))


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
	var level := int(kitchen.site(building_key)["soup"]["level"])
	if _bowl.is_empty() and int(kitchen.plates(building_key)["clean"]) > 0:
		out.append({"id": "stack", "rect": STACK, "verb": "A clean bowl under the ladle"})
	if not _bowl.is_empty():
		if level > 0:
			out.append({"id": "pot", "rect": POT, "verb": "A ladle of the soup of the day (%d in)" % int(_bowl["ladles"])})
		if int(_bowl["ladles"]) > 0:
			out.append({"id": "bowl", "node": _bowl_spr, "verb": _serve_verb("soup")})
	if level < RULES.SOUP_CAP - RULES.SOUP_REFILL + 1:
		var tins := maxi(0, BUSINESS.stock_of(building_key, "soup"))
		out.append({"id": "tins", "rect": TINS, "verb": "Tip a tin into the pot (%d)" % tins if tins > 0 else "No soup tins: order them in the books"})
	if _bottle.is_empty():
		out.append({"id": "crate_kofola", "rect": Rect2(CRATE.position, Vector2(CRATE.size.x * 0.5, CRATE.size.y)), "verb": "A kofola out of the crate (%d)" % maxi(0, BUSINESS.stock_of(building_key, "kofola"))})
		out.append({"id": "crate_malinovka", "rect": Rect2(CRATE.position + Vector2(CRATE.size.x * 0.5, 0), Vector2(CRATE.size.x * 0.5, CRATE.size.y)), "verb": "A malinovka out of the crate (%d)" % maxi(0, BUSINESS.stock_of(building_key, "malinovka"))})
	else:
		if not bool(_bottle["open"]):
			out.append({"id": "opener", "rect": OPENER, "verb": "Hold the opener on the cap and lift"})
			out.append({"id": "cap", "node": _bottle_spr, "verb": "Hold the opener on the cap and lift"})
		else:
			out.append({"id": "bottle", "node": _bottle_spr, "verb": _serve_verb(str(_bottle["kind"]))})
	return out


func _serve_verb(dish: String) -> String:
	var t := _ticket_for(dish)
	if t.is_empty():
		return "Nobody asked for it"
	return "Over the counter to %s" % ORDERS_first(str(t["name"]))


## The picked ticket if it is for `dish`, else the oldest that is.
func _ticket_for(dish: String) -> Dictionary:
	var best := {}
	for t in tickets():
		if str(t["dish"]) != dish:
			continue
		if str(t["id"]) == picked:
			return t
		if best.is_empty():
			best = t
	return best


func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	match id:
		"pot":
			return "ladle"
		"opener", "cap":
			return "opener"
	return "open"


func _press(id: String) -> void:
	match id:
		"stack":
			if int(kitchen.plates(building_key)["clean"]) <= 0:
				return
			kitchen.act(building_key, "plates", [-1, 0])
			_bowl = {"ladles": 0}
			sfx("plate_down", -10.0, 1.2)
		"pot":
			_ladle()
		"tins":
			_refill()
		"crate_kofola", "crate_malinovka":
			var kind := id.substr(6)
			if BUSINESS.stock_of(building_key, kind) == 0:
				say("", "No %s left." % RULES.dish_label(kind).to_lower())
				return
			_bottle = {"kind": kind, "open": false}
			sfx("res://assets/sfx/pub/glass_down.mp3", -8.0)
		"opener", "cap":
			_lift_y = _vp_mouse.y
		"bowl":
			_serve_soup()
		"bottle":
			_serve_bottle()


func _drag(_at: Vector2) -> void:
	if not (_held in ["opener", "cap"]) or _lift_y < 0.0 or _bottle.is_empty() or bool(_bottle["open"]):
		return
	# Lifted a tenth of the view: the cap pops.
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
	var to := Vector2(_rng.randf_range(240, 620), _rng.randf_range(160, 350))
	_caps.append({"sprite": s, "from": BOTTLE_AT + Vector2(0, -20), "to": to, "t": 0.0})
	while _caps.size() > CAPS:
		var old: Dictionary = _caps.pop_front()
		(old["sprite"] as Node).queue_free()


func _ladle() -> void:
	var soup: Dictionary = kitchen.site(building_key)["soup"]
	if int(soup["level"]) <= 0:
		say("", "The pot is empty.")
		return
	kitchen.act(building_key, "soup", [{"level": int(soup["level"]) - (1 if int(_bowl["ladles"]) == 0 else 0)}])
	_bowl["ladles"] = int(_bowl["ladles"]) + 1
	sfx("ladle_plate", -8.0, _rng.randf_range(0.95, 1.05))
	if int(_bowl["ladles"]) > RULES.SOUP_LADLES:
		say("", "It slops over the rim.")


func _refill() -> void:
	var soup: Dictionary = kitchen.site(building_key)["soup"]
	var n := mini(RULES.SOUP_REFILL, maxi(0, BUSINESS.stock_of(building_key, "soup")))
	if n <= 0:
		say("", "No tins left.")
		return
	if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"soup": n}):
		return
	kitchen.act(building_key, "soup", [{"level": mini(RULES.SOUP_CAP, int(soup["level"]) + n)}])
	sfx("pour", -8.0)


func _serve_soup() -> void:
	var t := _ticket_for("soup")
	if t.is_empty():
		say("", "Nobody asked for soup.")
		return
	var ladles := int(_bowl["ladles"])
	# Two ladles a bowl: one is short, three slop over.
	var q := 1.0 if ladles == RULES.SOUP_LADLES else (0.55 if ladles < RULES.SOUP_LADLES else 0.7)
	var v: Dictionary = kitchen.serve(building_key, t, {"soup": 1}, q)
	_after(v, t, "Soup of the day")
	if bool(v.get("ok", false)):
		_bowl = {}


func _serve_bottle() -> void:
	var kind := str(_bottle["kind"])
	var t := _ticket_for(kind)
	if t.is_empty():
		var other := _ticket_for("kofola" if kind == "malinovka" else "malinovka")
		say(ORDERS_first(str(other.get("name", ""))) if not other.is_empty() else "", "I asked for %s." % RULES.dish_label(str(other["dish"])).to_lower() if not other.is_empty() else "Nobody asked for it.")
		return
	var v: Dictionary = kitchen.serve(building_key, t, {kind: 1}, -1.0)
	_after(v, t, RULES.dish_label(kind))
	if bool(v.get("ok", false)):
		_bottle = {}


func _after(v: Dictionary, t: Dictionary, what: String) -> void:
	var who := ORDERS_first(str(t["name"]))
	if not bool(v.get("ok", false)):
		say(who, "None left." if str(v.get("why", "")) == "dry" else "That's not mine.")
		return
	picked = ""
	sfx("till", -8.0)
	pop("+$%d" % int(v["amount"]), BOWL_AT + Vector2(80, -60), RETRO_UI.C_AMBER_LIGHT if int(v["tip"]) > 0 else RETRO_UI.C_BONE, true)
	v["build"] = float(v.get("accuracy", 1.0))
	score_card(v, what)
	say(who, ["Lovely.", "Thank you.", "Just what I needed.", "Dobrou chut."][_rng.randi() % 4])


func bar_text() -> String:
	if kitchen == null or building_key == "":
		return ""
	return "SOUP %d  KOFOLA %d  MALINOVKA %d" % [int(kitchen.site(building_key)["soup"]["level"]), maxi(0, BUSINESS.stock_of(building_key, "kofola")), maxi(0, BUSINESS.stock_of(building_key, "malinovka"))]


func _closing() -> void:
	_lift_y = -1.0
	# A bowl half filled goes back on the stack; a bottle back in the crate.
	if not _bowl.is_empty():
		kitchen.act(building_key, "plates", [1, 0])
		_bowl = {}
	_bottle = {}


# ── debug (tools/bistro_check.gd, tools/bistro_shots.gd) ─────────────────────

func debug_click(id: String) -> void:
	_press(id)


## The cap levered off at once (a hold and a lift).
func debug_pop() -> void:
	if not _bottle.is_empty():
		_pop()
