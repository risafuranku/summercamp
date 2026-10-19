extends "res://scripts/bistro/station_view.gd"

## The goulash pot and the dumplings (assets/textury/bistro/st_pot.png): the big pot on
## its ring at the left, the catering tins on the shelf, the steamer at the back right,
## the board with its cotton thread in front of it.
##   the pot       hold the button in it and stir round: each turn scrapes the bottom.
##                 Left alone it catches (the bar under its portions; the room shows
##                 STIR) and when it does, the burnt layer goes in the bin. A tin from the
##                 shelf tops it up from the books' goulash; then it has to come back to
##                 the boil before it goes on a plate.
##   dumplings     click the steamer: a loaf onto the board (two plates' worth off the
##                 shelf). Then slice it with the thread, a click a slice: each slice
##                 slides off to the heat shelf at the pass.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const POT_C := Vector2(160, 150)
const POT_R := Vector2(92, 90)
const POT := Rect2(55, 50, 210, 205)
const TINS := Rect2(322, 5, 115, 135)
const STEAMER := Rect2(466, 8, 160, 140)
const BOARD := Rect2(326, 160, 230, 140)
const LOAF_AT := Vector2(440, 262)
const LOAF_LEN := 88.0
const SLICE_W := 21.0

var _stirring := false
var _last_ang := 0.0
var _turn := 0.0
var _spoon_at := Vector2.ZERO
var _cut_t := -1.0
var _slide: Array = []   # slices on their way off the board: seconds


func _ready() -> void:
	super._ready()
	station = "pot"
	room = "kitchen"
	picture = tex("st_pot")
	for n in ["spoon", "loaf", "loaf_cut", "dumpling_slice", "tin", "steam", "smoke", "pot_empty"]:
		tex(n)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var s: Dictionary = kitchen.site(building_key)
	var pot: Dictionary = s["pot"]
	var level := int(pot["level"])
	if level > 0:
		out.append({"id": "pot", "rect": POT, "verb": "Stir the pot (hold and go round)" if float(pot["catch"]) > 0.3 else "Stir the pot"})
	var stock: int = maxi(0, BUSINESS.stock_of(building_key, "goulash"))
	var room := RULES.POT_CAP - level
	out.append({"id": "tins", "rect": TINS, "verb": ("Top up the pot from a tin (%d portions in the cellar)" % stock) if stock > 0 and room > 0 else ("The pot is full" if room <= 0 else "No goulash in the cellar: order some in the books")})
	var loaf: Dictionary = s["loaf"]
	if int(loaf.get("left", 0)) <= 0:
		var d: int = maxi(0, BUSINESS.stock_of(building_key, "dumplings"))
		out.append({"id": "steamer", "rect": STEAMER, "verb": ("Take a loaf of dumplings out of the steamer (%d plates' worth)" % d) if d > 0 else "No dumplings: order some in the books"})
	else:
		out.append({"id": "loaf", "rect": _loaf_rect(int(loaf["left"])), "verb": "Cut a slice with the thread (%d left)" % int(loaf["left"])})
	return out


func _loaf_rect(left: int) -> Rect2:
	var len := LOAF_LEN * float(left) / float(RULES.LOAF_SLICES)
	return Rect2(LOAF_AT.x - LOAF_LEN * 0.5, LOAF_AT.y - 26, len + 6, 52)


func _press(id: String) -> void:
	match id:
		"pot":
			_stirring = true
			_last_ang = (_mouse - POT_C).angle()
			_turn = 0.0
		"tins":
			_top_up()
		"steamer":
			_take_loaf()
		"loaf":
			_cut()


func _release(id: String) -> void:
	if id == "pot":
		_stirring = false


func _drag(at: Vector2) -> void:
	if not _stirring or at.x < 0.0:
		return
	_spoon_at = at
	var a := (at - POT_C).angle()
	var d := wrapf(a - _last_ang, -PI, PI)
	_last_ang = a
	_turn += absf(d)
	if _turn >= TAU * 0.5:
		_turn -= TAU * 0.5
		var pot: Dictionary = (kitchen.site(building_key)["pot"] as Dictionary).duplicate()
		var before := float(pot["catch"])
		pot["catch"] = maxf(0.0, before - 0.22)
		kitchen.act(building_key, "pot", [pot])
		sfx("stir", -10.0, randf_range(0.9, 1.1))
		if before > 0.05 and float(pot["catch"]) <= 0.0:
			pop("STIRRED", POT_C + Vector2(0, -60), RETRO_UI.C_GREEN_LIGHT)


func _top_up() -> void:
	var pot: Dictionary = (kitchen.site(building_key)["pot"] as Dictionary).duplicate()
	var room := RULES.POT_CAP - int(pot["level"])
	if room <= 0:
		say("", "The pot is full.")
		return
	var n: int = mini(mini(RULES.POT_REFILL, room), maxi(0, BUSINESS.stock_of(building_key, "goulash")))
	if n <= 0:
		say("", "No goulash left in the cellar. The van brings what you order.")
		sfx("tick", -14.0, 0.7)
		return
	if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"goulash": n}):
		return
	var level := int(pot["level"])
	# Cold goulash into hot: the pot comes off the boil for a while.
	pot["heat"] = clampf(float(pot["heat"]) * float(level) / float(level + n), 0.0, 1.0) * 0.6
	pot["level"] = level + n
	kitchen.act(building_key, "pot", [pot])
	pop("+%d" % n, POT_C + Vector2(0, -50), RETRO_UI.C_GREEN_LIGHT)
	sfx("pour", -6.0)


func _take_loaf() -> void:
	var have: int = maxi(0, BUSINESS.stock_of(building_key, "dumplings"))
	var units := mini(RULES.LOAF_UNITS, have)
	if units <= 0:
		say("", "No dumplings in the cellar. Order some in the books.")
		sfx("tick", -14.0, 0.7)
		return
	if not kitchen.room_for(building_key, "dumpling", 1):
		say("", "The pass is full of dumplings.")
		return
	if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"dumplings": units}):
		return
	var slices := RULES.LOAF_SLICES * units / RULES.LOAF_UNITS
	kitchen.act(building_key, "loaf", [{"left": slices}])
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
	_cut_t = 0.0
	_slide.append(0.0)
	sfx("thread", -8.0, randf_range(0.95, 1.1))


func _tick(delta: float) -> void:
	if _cut_t >= 0.0:
		_cut_t += delta
		if _cut_t > 0.2:
			_cut_t = -1.0
	for i in _slide.size():
		_slide[i] = float(_slide[i]) + delta
	_slide = _slide.filter(func(t: float) -> bool: return t < 0.6)


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if kitchen == null:
		return
	var s: Dictionary = kitchen.site(building_key)
	var pot: Dictionary = s["pot"]
	var level := int(pot["level"])
	var st := floorf(_t * 12.0)
	if level <= 0:
		# Empty: the scraped steel of the inside.
		if tex("pot_empty") != null:
			blit(c, "pot_empty", POT_C)
		else:
			c.draw_set_transform(POT_C, 0.0, Vector2(1.0, POT_R.y / POT_R.x))
			c.draw_circle(Vector2.ZERO, POT_R.x, Color(0.42, 0.42, 0.42))
			c.draw_circle(Vector2(0, 8), POT_R.x * 0.8, Color(0.32, 0.31, 0.3))
			c.draw_set_transform(Vector2.ZERO)
	else:
		# The bottom catching: black flecks come up, then smoke.
		var catch := float(pot["catch"])
		if catch > 0.5:
			for i in int((catch - 0.5) * 24.0):
				var a := float(i) * 2.399
				var rr := sqrt(float(i) / 12.0) * 0.8
				c.draw_rect(Rect2((POT_C + Vector2(cos(a) * POT_R.x * rr, sin(a) * POT_R.y * rr)).floor(), Vector2(2, 2)), Color(0.08, 0.04, 0.03, 0.8))
		if catch > 0.75 or kitchen.burnt_flash.has(building_key):
			for j in 3:
				var age := fmod(st / 12.0 * 0.6 + j * 0.33, 1.0)
				blit(c, "smoke", POT_C + Vector2(-30 + j * 30, -20 - age * 60.0), (1.0 - age) * 0.9, 1, false, Color(0.5, 0.48, 0.46))
		# Steam when it is hot, a bubble or two.
		if float(pot["heat"]) >= 0.6:
			for j in 4:
				var k := int(st + j * 7) % 16
				c.draw_rect(Rect2((POT_C + Vector2(-70 + (k * 37) % 140, -20 + (k * 13) % 40)).floor(), Vector2(3, 2)), Color(0.75, 0.45, 0.3, 0.8))
	# The level on a chalk tag, the heat and the catching under it.
	var tag := Rect2(14, 290, 166, 40)
	c.draw_rect(tag, Color(0.08, 0.07, 0.06, 0.85))
	ink(c, tag.position + Vector2(6, 12), "GOULASH  %d / %d" % [level, RULES.POT_CAP], RETRO_UI.C_BONE)
	ink(c, tag.position + Vector2(6, 24), "HEAT", RETRO_UI.C_BONE_DIM, RETRO_UI.FONT_TEXT)
	meter(c, Rect2(tag.position.x + 36, tag.position.y + 17, 104, 5), float(pot["heat"]), Vector2(0.6, 1.0), RETRO_UI.C_RED if float(pot["heat"]) >= 0.6 else RETRO_UI.C_BLUE)
	ink(c, tag.position + Vector2(6, 35), "BOTTOM", RETRO_UI.C_BONE_DIM, RETRO_UI.FONT_TEXT)
	meter(c, Rect2(tag.position.x + 36, tag.position.y + 29, 104, 5), float(pot["catch"]), Vector2(-1, -1), RETRO_UI.C_RED if float(pot["catch"]) > 0.6 else RETRO_UI.C_AMBER_DIM)
	if _stirring:
		if tex("spoon") != null:
			blit(c, "spoon", _spoon_at + Vector2(10, -30))
		else:
			c.draw_line(_spoon_at, _spoon_at + Vector2(24, -60), Color(0.55, 0.38, 0.2), 4.0)
	# The tins on the shelf.
	var stock: int = maxi(0, BUSINESS.stock_of(building_key, "goulash"))
	if tex("tin") != null:
		for i in mini(3, ceili(stock / 8.0)):
			blit(c, "tin", TINS.get_center() + Vector2(-16 + i * 16, 8 - i * 2))
	ink(c, TINS.position + Vector2(2, TINS.size.y + 8), "TINS %d" % stock, RETRO_UI.C_BONE)
	# The loaf on the board, shorter by a slice each cut; the slices sliding off.
	var loaf: Dictionary = s["loaf"]
	var left := int(loaf.get("left", 0))
	if left > 0:
		var lt := tex("loaf")
		var len := LOAF_LEN * float(left) / float(RULES.LOAF_SLICES)
		var x0 := LOAF_AT.x - LOAF_LEN * 0.5
		if lt != null:
			# The loaf as long as it is still: its picture cut off at the right end.
			var src_w := floorf(lt.get_width() * float(left) / float(RULES.LOAF_SLICES))
			var h := lt.get_height() * PIX
			c.draw_texture_rect_region(lt, Rect2(Vector2(x0, LOAF_AT.y - h * 0.5).floor(), Vector2(src_w * PIX, h)), Rect2(0, 0, src_w, lt.get_height()))
		else:
			c.draw_rect(Rect2(x0, LOAF_AT.y - 18, len, 36), Color(0.92, 0.9, 0.82))
			c.draw_rect(Rect2(x0 + len - 3, LOAF_AT.y - 18, 3, 36), Color(0.82, 0.8, 0.7))
		# The thread, where the next cut goes.
		if hovered() == "loaf":
			var tx := x0 + len - SLICE_W * LOAF_LEN / (SLICE_W * RULES.LOAF_SLICES)
			c.draw_line(Vector2(tx, LOAF_AT.y - 34), Vector2(tx - 6, LOAF_AT.y + 32), Color(0.95, 0.95, 0.9), 1.0)
		ink(c, Vector2(x0, LOAF_AT.y + 40), "SLICES %d" % left, RETRO_UI.C_BONE)
	for t in _slide:
		var k := clampf(float(t) / 0.6, 0.0, 1.0)
		var from := Vector2(LOAF_AT.x - LOAF_LEN * 0.5 + LOAF_LEN * float(left) / float(RULES.LOAF_SLICES) + 10, LOAF_AT.y)
		blit(c, "dumpling_slice", from + Vector2(k * 90.0, k * k * 40.0), 1.0 - k * 0.5)
	ink(c, Vector2(332, 314), "AT THE PASS %d" % kitchen.prep(building_key, "dumpling"), RETRO_UI.C_BONE)
