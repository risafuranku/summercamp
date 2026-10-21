extends "res://scripts/bistro/bistro_station.gd"

## The goulash pot and the dumplings (DESIGN.md §7b): the counter's top is a Build texture
## (st_pot: the big pot on its ring at the left, a catering tin, the steamer at the back,
## the board with its cotton thread), the things on it sprites in the room.
##   the pot       hold the button in it and go round: the spoon stirs, each turn scrapes
##                 the bottom. Left alone it catches (the BOTTOM column; the room shows
##                 STIR) and the burnt layer goes in the bin. The tin tops it up from the
##                 cellar's goulash; then it has to come back to the boil (the HEAT column
##                 into the green) before it goes on a plate.
##   dumplings     the steamer: a loaf onto the board (two plates' worth off the shelf);
##                 slice it with the thread, a click a slice, each slice off to the pass.

const POT_C := Vector2(152, 140)
const POT := Rect2(52, 50, 205, 190)
const TINS := Rect2(318, 6, 118, 134)
const STEAMER := Rect2(462, 8, 160, 140)
const BOARD := Rect2(326, 160, 230, 140)
const LOAF_AT := Vector2(440, 232)
const LOAF_LEN := 120.0

var _stirring := false
var _last_ang := 0.0
var _turn := 0.0
var _spoon: Sprite3D
var _loaf: Sprite3D
var _slide: Array = []
var _slide_spr: Array = []
var _heat: Sprite3D
var _bottom: Sprite3D
var _empty: Sprite3D


func _build() -> void:
	super._build()
	_empty = bsprite("pot_empty")
	if _empty.texture == null:
		_empty.queue_free()
		_empty = null
	else:
		put(_empty, POT_C, 0.01)
	_spoon = bsprite("spoon")
	_spoon.visible = false
	_loaf = bsprite("loaf", true, 1.4)
	_loaf.region_enabled = true
	for i in 3:
		var s := bsprite("dumpling_slice", true, 1.6)
		s.visible = false
		_slide_spr.append(s)
	_heat = meter(5, 18)
	_heat.position = local_at(Vector2(POT.end.x + 10, POT.position.y + 70), 0.04)
	_bottom = meter(5, 18)
	_bottom.position = local_at(Vector2(POT.end.x + 24, POT.position.y + 70), 0.04)


func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var s: Dictionary = kitchen.site(building_key)
	var pot: Dictionary = s["pot"]
	var level := int(pot["level"])
	if _empty != null:
		_empty.visible = level <= 0
	var hot := float(pot["heat"]) >= 0.6
	set_meter(_heat, float(pot["heat"]), Vector2(0.6, 1.0), RETRO_UI.C_RED if hot else RETRO_UI.C_BLUE)
	set_meter(_bottom, float(pot["catch"]), Vector2(-1, -1), RETRO_UI.C_RED if float(pot["catch"]) > 0.6 else RETRO_UI.C_AMBER_DIM, float(pot["catch"]) > 0.75)
	_heat.visible = level > 0
	_bottom.visible = level > 0
	_spoon.visible = _stirring
	# The loaf on the board, shorter by a slice each cut (its picture cut off at the end).
	var left := int((s["loaf"] as Dictionary).get("left", 0))
	_loaf.visible = left > 0 and _loaf.texture != null
	if _loaf.visible:
		var tw := float(_loaf.texture.get_width())
		var th := float(_loaf.texture.get_height())
		var w := maxf(1.0, floorf(tw * float(left) / float(RULES.LOAF_SLICES)))
		_loaf.region_rect = Rect2(0, 0, w, th)
		var x0 := LOAF_AT.x - LOAF_LEN * 0.5
		put(_loaf, Vector2(x0 + LOAF_LEN * (w / tw) * 0.5, LOAF_AT.y), 0.02)
	for i in _slide_spr.size():
		var spr: Sprite3D = _slide_spr[i]
		spr.visible = i < _slide.size()
		if spr.visible:
			var k := floorf(clampf(float(_slide[i]) / 0.6, 0.0, 1.0) * 7.0) / 7.0
			var from := Vector2(LOAF_AT.x - LOAF_LEN * 0.5 + LOAF_LEN * float(left) / float(RULES.LOAF_SLICES) + 8.0, LOAF_AT.y)
			put(spr, from + Vector2(k * 110.0, k * 30.0), 0.03 + k * 0.05)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var s: Dictionary = kitchen.site(building_key)
	var pot: Dictionary = s["pot"]
	var level := int(pot["level"])
	if level > 0:
		out.append({"id": "pot", "rect": POT, "verb": "Stir the pot: hold and go round" if float(pot["catch"]) > 0.3 else "Stir the pot"})
	var stock: int = maxi(0, BUSINESS.stock_of(building_key, "goulash"))
	var room_left := KITCHEN.pot_cap(building_key) - level
	if stock > 0 and room_left > 0:
		out.append({"id": "tins", "rect": TINS, "verb": "Top the pot up from a tin (%d in the cellar)" % stock})
	var loaf: Dictionary = s["loaf"]
	if int(loaf.get("left", 0)) <= 0:
		var d: int = maxi(0, BUSINESS.stock_of(building_key, "dumplings"))
		if d > 0:
			out.append({"id": "steamer", "rect": STEAMER, "verb": "A loaf of dumplings out of the steamer"})
	else:
		out.append({"id": "loaf", "node": _loaf, "verb": "Cut a slice with the thread (%d left)" % int(loaf["left"])})
	return out


func _press(id: String) -> void:
	match id:
		"pot":
			_stirring = true
			_last_ang = (_mouse_free - POT_C).angle()
			_turn = 0.0
			_drag(_mouse_free)
		"tins":
			_top_up()
		"steamer":
			_take_loaf()
		"loaf":
			_cut()


func _release(id: String) -> void:
	if id == "pot":
		_stirring = false
		_spoon.visible = false


func _drag(at: Vector2) -> void:
	if not _stirring or at.x < -500.0:
		return
	# The spoon's bowl where the pointer is, kept inside the pot.
	var rel := at - POT_C
	if rel.length() > 80.0:
		rel = rel.normalized() * 80.0
	put(_spoon, POT_C + rel + Vector2(36, -6), 0.06)
	_spoon.visible = true
	var a := rel.angle()
	var d := wrapf(a - _last_ang, -PI, PI)
	_last_ang = a
	_turn += absf(d)
	if _turn >= PI:
		_turn -= PI
		var pot: Dictionary = (kitchen.site(building_key)["pot"] as Dictionary).duplicate()
		var before := float(pot["catch"])
		pot["catch"] = maxf(0.0, before - 0.22)
		kitchen.act(building_key, "pot", [pot])
		sfx("stir", -10.0, randf_range(0.9, 1.1))
		if before > 0.05 and float(pot["catch"]) <= 0.0:
			pop("STIRRED", POT_C + Vector2(0, -70), RETRO_UI.C_GREEN_LIGHT)


func _top_up() -> void:
	var pot: Dictionary = (kitchen.site(building_key)["pot"] as Dictionary).duplicate()
	var room_left := KITCHEN.pot_cap(building_key) - int(pot["level"])
	if room_left <= 0:
		say("", "The pot is full.")
		return
	var n: int = mini(mini(RULES.POT_REFILL, room_left), maxi(0, BUSINESS.stock_of(building_key, "goulash")))
	if n <= 0:
		sfx("tick", -14.0, 0.7)
		return
	if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"goulash": n}):
		return
	var level := int(pot["level"])
	# Cold goulash into hot: the pot comes off the boil for a while.
	pot["heat"] = clampf(float(pot["heat"]) * float(level) / float(level + n), 0.0, 1.0) * 0.6
	pot["level"] = level + n
	kitchen.act(building_key, "pot", [pot])
	pop("+%d" % n, POT_C + Vector2(0, -60), RETRO_UI.C_GREEN_LIGHT)
	sfx("pour", -6.0)


func _take_loaf() -> void:
	var have: int = maxi(0, BUSINESS.stock_of(building_key, "dumplings"))
	var units := mini(RULES.LOAF_UNITS, have)
	if units <= 0:
		sfx("tick", -14.0, 0.7)
		return
	if not kitchen.room_for(building_key, "dumpling", 1):
		say("", "The pass is full of dumplings.")
		return
	if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"dumplings": units}):
		return
	kitchen.act(building_key, "loaf", [{"left": RULES.LOAF_SLICES * units / RULES.LOAF_UNITS}])
	sfx("steam_lid", -8.0)


func _cut() -> void:
	var loaf: Dictionary = (kitchen.site(building_key)["loaf"] as Dictionary).duplicate()
	var left := int(loaf.get("left", 0))
	if left <= 0:
		return
	if not kitchen.room_for(building_key, "dumpling"):
		say("", "The heat shelf is full of dumplings.")
		return
	loaf["left"] = left - 1
	kitchen.act(building_key, "loaf", [loaf])
	kitchen.act(building_key, "prep", ["dumpling", 1])
	_slide.append(0.0)
	sfx("thread", -8.0, randf_range(0.95, 1.1))


func _tick(delta: float) -> void:
	for i in _slide.size():
		_slide[i] = float(_slide[i]) + delta
	_slide = _slide.filter(func(t: float) -> bool: return t < 0.6)


func _closing() -> void:
	_stirring = false
	_spoon.visible = false


func bar_text() -> String:
	if kitchen == null:
		return ""
	var pot: Dictionary = kitchen.site(building_key)["pot"]
	return "GOULASH %d/%d  DUMPLINGS %d" % [int(pot["level"]), KITCHEN.pot_cap(building_key), kitchen.prep(building_key, "dumpling")]


## The ladle in the goulash, the bare glove for the tins, the loaf and the steamer.
func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	return "ladle" if id == "pot" else "open"

# ── debug (tools/bistro_shots.gd, tools/bistro_coop.gd) ──────────────────────

func debug_click(id: String) -> void:
	match id:
		"tins":
			_top_up()
		"steamer":
			_take_loaf()
		"loaf":
			_cut()
		"stir":
			var pot: Dictionary = (kitchen.site(building_key)["pot"] as Dictionary).duplicate()
			pot["catch"] = 0.0
			kitchen.act(building_key, "pot", [pot])


# ── the frame: the next step, the tab ────────────────────────────────────────

## What is best to do at the pot: stir when it starts to catch, top it up when it runs
## low, a loaf out and slices cut while dumplings are wanted.
func next_hint() -> Dictionary:
	if kitchen == null or building_key == "":
		return {}
	var s: Dictionary = kitchen.site(building_key)
	var pot: Dictionary = s["pot"]
	if int(pot["level"]) > 0 and float(pot["catch"]) > 0.3:
		return spot_hint("pot", "rub")
	var goulash := 0
	for t in kitchen.tickets(building_key, "pass"):
		goulash += int((t["parts"] as Dictionary).get("goulash", 0))
	if goulash > int(pot["level"]):
		var h := spot_hint("tins")
		if not h.is_empty():
			return h
	if wanted("dumpling") > 0:
		var cut := spot_hint("loaf")
		if not cut.is_empty():
			return cut
		return spot_hint("steamer")
	return {}


func alert() -> int:
	if kitchen == null or building_key == "":
		return 0
	var pot: Dictionary = kitchen.site(building_key)["pot"]
	if int(pot["level"]) > 0 and float(pot["catch"]) > 0.6:
		return 2
	return 1 if (int(pot["level"]) > 0 and float(pot["catch"]) > 0.3) or wanted("dumpling") > 0 else 0
