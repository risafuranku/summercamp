extends "res://scripts/bistro/bistro_station.gd"

## The bufet: the soup of the day on the kitchen island beside the grill (the brief of
## 20. 10.: "the soup of the day out of a big pot, quick and cheap"; moved into the kitchen
## 21. 10.: the kitchen cooks, the floor pours the bottles and serves). Its top is a Build
## texture (st_soup: the soup pot on its hot plate, the stack of bowls); the things on it
## sprites.
##   the bowls    a click: a clean bowl under the ladle (the kitchen's plates and bowls)
##   the pot      a click: a ladle of soup into the bowl; two fill it, a third slops over
##   a bowl       a click (or SERVE: Space, Enter): over the counter to the picked soup
##                ticket (else the oldest)
##   the tins     (the pot's foot) a click when it runs low: the books' soup into it
## The guests' soups are tickets of their own (bistro_rules: the soup of the day).

## Where the Build picture (bistro/st_soup.png) has them: the pot on its plate (its foot
## the tins), the stack of bowls; a bowl is filled on the bare top in front.
const POT := Rect2(5, 0, 222, 240)
const POT_AT := Vector2(109, 129)
const TINS := Rect2(5, 245, 222, 115)
const STACK := Rect2(240, 35, 149, 200)
const BOWL_AT := Vector2(470, 250)
const BOWL_M := 0.13

## The bowl at the pot: {ladles} ({} none).
var _bowl: Dictionary = {}
var _bowl_spr: Sprite3D
var _level_spr: Sprite3D
var _stack: Array = []
var _rng := RandomNumberGenerator.new()


func where() -> String:
	return "bufet"


func _build() -> void:
	super._build()
	_rng.randomize()
	# The bowls lie on the top (their pictures are drawn from above).
	for i in 4:
		var b := sprite(TEX + "bowl_empty.png", BOWL_M, true)
		put(b, STACK.get_center() + Vector2(0, 20), 0.004 + i * 0.022)
		_stack.append(b)
	_bowl_spr = sprite(TEX + "bowl_empty.png", BOWL_M, true)
	_bowl_spr.visible = false
	_level_spr = meter(5, 16)
	_level_spr.position = local_at(POT_AT + Vector2(-90, -100), 0.04)


func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var clean := int(kitchen.plates(building_key)["clean"]) - (1 if not _bowl.is_empty() else 0)
	for i in _stack.size():
		(_stack[i] as Sprite3D).visible = i < mini(4, ceili(maxi(0, clean) / 3.0))
	_bowl_spr.visible = not _bowl.is_empty()
	if _bowl_spr.visible:
		retex(_bowl_spr, TEX + ("bowl_soup.png" if int(_bowl["ladles"]) > 0 else "bowl_empty.png"), BOWL_M)
		put(_bowl_spr, BOWL_AT, 0.006)
	var level := int(kitchen.site(building_key)["soup"]["level"])
	_level_spr.visible = is_open()
	set_meter(_level_spr, float(level) / float(RULES.SOUP_CAP), Vector2(-1, -1), RETRO_UI.C_AMBER if level > 3 else RETRO_UI.C_RED, level <= 2)


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
			out.append({"id": "bowl", "node": _bowl_spr, "verb": _serve_verb()})
	if level < RULES.SOUP_CAP - RULES.SOUP_REFILL + 1:
		var tins := maxi(0, BUSINESS.stock_of(building_key, "soup"))
		out.append({"id": "tins", "rect": TINS, "verb": "Tip a tin into the pot (%d)" % tins if tins > 0 else "No soup tins: order them in the books"})
	return out


func _serve_verb() -> String:
	var t := current_ticket()
	if t.is_empty():
		return "Nobody asked for it"
	return "Over the counter to %s" % ORDERS_first(str(t["name"]))


func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	return "ladle" if id == "pot" else "open"


func _press(id: String) -> void:
	match id:
		"stack":
			if int(kitchen.plates(building_key)["clean"]) <= 0:
				return
			kitchen.act(building_key, "plates", [-1, 0])
			_bowl = {"ladles": 0}
			sfx("plate_down", -10.0, 1.2)
			hop(_bowl_spr)
		"pot":
			_ladle()
		"tins":
			_refill()
		"bowl":
			_serve_soup()


func _ladle() -> void:
	var soup: Dictionary = kitchen.site(building_key)["soup"]
	if int(soup["level"]) <= 0:
		say("", "The pot is empty.")
		return
	kitchen.act(building_key, "soup", [{"level": int(soup["level"]) - (1 if int(_bowl["ladles"]) == 0 else 0)}])
	_bowl["ladles"] = int(_bowl["ladles"]) + 1
	sfx("ladle_plate", -8.0, _rng.randf_range(0.95, 1.05))
	if int(_bowl["ladles"]) == RULES.SOUP_LADLES:
		sfx("tick", -12.0, 1.5)
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
	var t := current_ticket()
	if t.is_empty():
		say("", "Nobody asked for soup.")
		return
	var ladles := int(_bowl["ladles"])
	# Two ladles a bowl: one is short, three slop over.
	var q := 1.0 if ladles == RULES.SOUP_LADLES else (0.55 if ladles < RULES.SOUP_LADLES else 0.7)
	var v: Dictionary = kitchen.serve(building_key, t, {"soup": 1}, q)
	var who := ORDERS_first(str(t["name"]))
	if not bool(v.get("ok", false)):
		say(who, "None left." if str(v.get("why", "")) == "dry" else "That's not mine.")
		return
	_bowl = {}
	if picked == str(t["id"]):
		picked = ""
	sfx("till", -8.0)
	pop("+$%d" % int(v["amount"]), BOWL_AT + Vector2(0, -60), RETRO_UI.C_AMBER_LIGHT if int(v["tip"]) > 0 else RETRO_UI.C_BONE, true)
	v["build"] = float(v.get("accuracy", 1.0))
	score_card(v, "Soup of the day", _with_patience(t))
	say(who, ["Lovely.", "Thank you.", "Just what I needed.", "Dobrou chut."][_rng.randi() % 4])


# ── the frame ────────────────────────────────────────────────────────────────

func serve_ready() -> bool:
	return not _bowl.is_empty() and int(_bowl["ladles"]) > 0 and not current_ticket().is_empty()


func serve_now() -> void:
	_serve_soup()


## A soup's checklist: a bowl, two ladles (red when it slopped), SERVE.
func checklist(t: Dictionary) -> Array:
	if str(t.get("dish", "")) != "soup":
		return super.checklist(t)
	var ladles := int(_bowl.get("ladles", 0))
	return [
		{"text": "A CLEAN BOWL", "state": "done" if not _bowl.is_empty() else "todo"},
		{"text": "TWO LADLES", "state": "done" if ladles == RULES.SOUP_LADLES else ("bad" if ladles > RULES.SOUP_LADLES else "todo")},
	]


## What is best to do here now: tins into an empty pot, a bowl, two ladles, SERVE.
func next_hint() -> Dictionary:
	if kitchen == null or building_key == "" or current_ticket().is_empty():
		return {}
	var level := int(kitchen.site(building_key)["soup"]["level"])
	if level <= 0:
		return {"rect": TINS, "gesture": "click"}
	if _bowl.is_empty():
		return {"rect": STACK, "gesture": "click"} if int(kitchen.plates(building_key)["clean"]) > 0 else {"tab": "sink"}
	if int(_bowl["ladles"]) < RULES.SOUP_LADLES:
		return {"rect": POT, "gesture": "click"}
	return {"ui": "serve"}


## Soup wanted: amber; wanted and the pot dry: red.
func alert() -> int:
	if kitchen == null or building_key == "" or tickets().is_empty():
		return 0
	return 2 if int(kitchen.site(building_key)["soup"]["level"]) <= 0 else 1


func bar_text() -> String:
	if kitchen == null or building_key == "":
		return ""
	return "SOUP %d  TINS %d" % [int(kitchen.site(building_key)["soup"]["level"]), maxi(0, BUSINESS.stock_of(building_key, "soup"))]


func _closing() -> void:
	# A bowl half filled goes back on the stack.
	if not _bowl.is_empty():
		kitchen.act(building_key, "plates", [1, 0])
		_bowl = {}


# ── debug (tools/bistro_check.gd, tools/bistro_shots.gd) ─────────────────────

func debug_click(id: String) -> void:
	_press(id)
