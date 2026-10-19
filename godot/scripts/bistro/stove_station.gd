extends "res://scripts/bistro/station_view.gd"

## The stove (assets/textury/bistro/st_stove.png): the breaded slices from the cellar on
## the tray at the left, the big pan of oil, the deep fryer, the warming rack at the right.
##   smazak  click the tray: a slice into the pan (three places). Each slice has a bar per
##           side; the side in the oil fills, golden in the green, black past it. Click
##           the slice to turn it; both sides golden, a click puts it on the rack; black,
##           a click bins it (the cheese is lost).
##   chips   click the bucket: the basket filled with raw chips; click the basket: down
##           into the oil; click it again: up, golden onto the rack (pale ones can go back
##           down, black ones go in the bin).
## The pan and the fryer go on cooking when you leave (kitchen.gd): mind the room's marks.

const SLOTS := [Vector2(172, 158), Vector2(248, 160), Vector2(210, 196)]
const SLICE := Vector2(58, 34)
const TRAY := Rect2(2, 96, 104, 78)
const BUCKET := Rect2(2, 178, 66, 70)
const FRYER := Rect2(352, 118, 146, 96)
const BASKET_UP := Vector2(424, 108)
const BASKET_DOWN := Vector2(424, 164)
const RACK := Rect2(530, 128, 106, 116)
const BIN := Rect2(600, 268, 38, 44)

var _flip: Dictionary = {}   # slot -> seconds since turned
var _sizzle: AudioStreamPlayer


func _ready() -> void:
	super._ready()
	station = "stove"
	room = "kitchen"
	picture = tex("st_stove")
	for n in ["slice_raw", "slice_golden", "slice_burnt", "slice_bad", "slice_raw_small", "slice_bad_small", "chips_rack", "slice_golden_small",
			"basket_empty", "basket_raw", "basket_gold", "chips_bucket", "smoke", "oil_spit", "flame"]:
		tex(n)
	_sizzle = AudioStreamPlayer.new()
	var path := "res://assets/sfx/bistro/fryer.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStreamMP3).duplicate()
		st.loop = true
		_sizzle.stream = st
	_sizzle.volume_db = -60.0
	add_child(_sizzle)


func _opened() -> void:
	if _sizzle.stream != null:
		_sizzle.play()


func _closing() -> void:
	_sizzle.stop()


func _ks() -> Dictionary:
	return kitchen.site(building_key)


func _slot_rect(i: int) -> Rect2:
	return Rect2(SLOTS[i] - SLICE * 0.5, SLICE)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var s := _ks()
	var raw := kitchen.prep(building_key, "cheese_raw") + kitchen.prep(building_key, "cheese_bad")
	out.append({"id": "tray", "rect": TRAY, "verb": ("Put a breaded slice in the pan (%d on the tray)" % raw) if raw > 0 else "The tray is empty: bread more in the cellar"})
	for i in SLOTS.size():
		var slot: Dictionary = s["pan"][i]
		if slot.is_empty():
			continue
		out.append({"id": "slot:%d" % i, "rect": _slot_rect(i), "verb": _slot_verb(slot)})
	var b: Dictionary = s["basket"]
	var chips := kitchen.prep(building_key, "chips_raw")
	if str(b["st"]) == "up" and int(b["n"]) == 0:
		out.append({"id": "bucket", "rect": BUCKET, "verb": ("Fill the basket with raw chips (%d)" % chips) if chips > 0 else "No raw chips: cut potatoes in the cellar"})
	out.append({"id": "basket", "rect": Rect2((BASKET_UP if str(b["st"]) == "up" else BASKET_DOWN) - Vector2(58, 34), Vector2(116, 70)), "verb": _basket_verb(b)})
	return out


func _slot_verb(slot: Dictionary) -> String:
	var bad := bool(slot.get("bad", false))
	var down := RULES.cheese_side(float(slot["t"][int(slot["down"])]), bad)
	var up := RULES.cheese_side(float(slot["t"][1 - int(slot["down"])]), bad)
	if down == 2 or up == 2:
		return "Bin the burnt slice"
	if down == 1 and up == 1:
		return "Golden both sides: onto the rack"
	return "Turn the slice"


func _basket_verb(b: Dictionary) -> String:
	if int(b["n"]) == 0:
		return "The basket (empty)"
	if str(b["st"]) == "up":
		return "Lower the basket into the oil"
	match RULES.fries_state(float(b["t"])):
		0:
			return "Lift the basket (still pale)"
		1:
			return "Lift the basket: golden"
	return "Lift the basket: burnt"


func _press(id: String) -> void:
	var s := _ks()
	if id == "tray":
		var free := -1
		for i in SLOTS.size():
			if (s["pan"][i] as Dictionary).is_empty():
				free = i
				break
		if free < 0:
			say("", "The pan is full.")
			return
		var bad := false
		if not kitchen.take(building_key, "cheese_raw"):
			if not kitchen.take(building_key, "cheese_bad"):
				say("", "No breaded slices. The cheese is breaded in the cellar.")
				sfx("tick", -14.0, 0.7)
				return
			bad = true
		kitchen.act(building_key, "pan", [free, {"bad": bad, "down": 0, "t": [0.0, 0.0]}])
		_flip[free] = 0.0
		sfx("sizzle_in", -6.0, randf_range(0.95, 1.05))
		return
	if id.begins_with("slot:"):
		var i := int(id.get_slice(":", 1))
		var slot: Dictionary = (s["pan"][i] as Dictionary).duplicate(true)
		if slot.is_empty():
			return
		var bad := bool(slot.get("bad", false))
		var down := RULES.cheese_side(float(slot["t"][int(slot["down"])]), bad)
		var up := RULES.cheese_side(float(slot["t"][1 - int(slot["down"])]), bad)
		if down == 2 or up == 2:
			kitchen.act(building_key, "pan", [i, {}])
			pop("BURNT", SLOTS[i] - Vector2(0, 20), RETRO_UI.C_RED_LIGHT)
			say("", "Black. The bin.")
			sfx("scrape", -8.0)
			return
		if down == 1 and up == 1:
			if not kitchen.room_for(building_key, "cheese"):
				say("", "The rack is full.")
				return
			kitchen.act(building_key, "pan", [i, {}])
			kitchen.act(building_key, "prep", ["cheese", 1])
			pop("+1", RACK.get_center(), RETRO_UI.C_GREEN_LIGHT)
			sfx("plate_down", -10.0, 1.2)
			return
		slot["down"] = 1 - int(slot["down"])
		kitchen.act(building_key, "pan", [i, slot])
		_flip[i] = 0.0
		sfx("flip", -8.0, randf_range(0.9, 1.1))
		return
	if id == "bucket":
		var n := mini(RULES.BASKET_PORTIONS, kitchen.prep(building_key, "chips_raw"))
		if n <= 0:
			say("", "No raw chips. The potatoes are cut in the cellar.")
			return
		kitchen.act(building_key, "prep", ["chips_raw", -n])
		kitchen.act(building_key, "basket", [{"st": "up", "t": 0.0, "n": n}])
		sfx("chips_load", -8.0)
		return
	if id == "basket":
		var b: Dictionary = (s["basket"] as Dictionary).duplicate()
		if int(b["n"]) == 0:
			_press("bucket")
			return
		if str(b["st"]) == "up":
			b["st"] = "down"
			kitchen.act(building_key, "basket", [b])
			sfx("basket_drop", -4.0)
			return
		var st := RULES.fries_state(float(b["t"]))
		if st == 2:
			kitchen.act(building_key, "basket", [{"st": "up", "t": 0.0, "n": 0}])
			pop("BURNT", BASKET_UP, RETRO_UI.C_RED_LIGHT)
			say("", "Burnt to sticks. The bin.")
			sfx("scrape", -8.0)
		elif st == 0:
			b["st"] = "up"
			kitchen.act(building_key, "basket", [b])
			say("", "Pale and limp. Back in with them.")
			sfx("basket_lift", -8.0)
		else:
			var room := mini(int(b["n"]), int(RULES.PREP_CAP["fries"]) - kitchen.prep(building_key, "fries"))
			if room <= 0:
				say("", "The rack is full.")
				b["st"] = "up"
				kitchen.act(building_key, "basket", [b])
				return
			kitchen.act(building_key, "basket", [{"st": "up", "t": 0.0, "n": 0}])
			kitchen.act(building_key, "prep", ["fries", room])
			pop("+%d" % room, RACK.get_center() + Vector2(0, 30), RETRO_UI.C_GREEN_LIGHT)
			sfx("basket_lift", -6.0)


func _tick(delta: float) -> void:
	for k in _flip.keys():
		_flip[k] = float(_flip[k]) + delta
		if float(_flip[k]) > 0.3:
			_flip.erase(k)
	if kitchen == null:
		return
	var st: Dictionary = kitchen.stove_state(building_key)
	var want := -30.0
	if bool(st["cooking"]):
		want = -9.0
	if str(_ks()["basket"]["st"]) == "down":
		want = -4.0
	_sizzle.volume_db = move_toward(_sizzle.volume_db, want, delta * 40.0)


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if kitchen == null:
		return
	var s := _ks()
	var st := floorf(_t * 12.0)
	# The tray: the breaded slices waiting, in two rows (the badly breaded ones last).
	var good := kitchen.prep(building_key, "cheese_raw")
	var bad := kitchen.prep(building_key, "cheese_bad")
	for i in mini(8, good + bad):
		var at := TRAY.position + Vector2(24 + (i % 3) * 28, 22 + (i / 3) * 18)
		blit(c, "slice_bad_small" if i >= good and tex("slice_bad_small") != null else "slice_raw_small", at)
	ink(c, TRAY.position + Vector2(4, TRAY.size.y - 4), "%d" % (good + bad), RETRO_UI.C_BONE)
	# The bucket of raw chips under it.
	var chips := kitchen.prep(building_key, "chips_raw")
	if chips > 0 and tex("chips_bucket") != null:
		blit(c, "chips_bucket", BUCKET.get_center())
		ink(c, BUCKET.position + Vector2(4, BUCKET.size.y - 2), "%d" % chips, RETRO_UI.C_BONE)
	# The pan: the oil spitting round each slice, the slice browning, its two bars.
	for i in SLOTS.size():
		var slot: Dictionary = s["pan"][i]
		if slot.is_empty():
			continue
		var at: Vector2 = SLOTS[i]
		var bad_s := bool(slot.get("bad", false))
		for j in 3:
			var k := int(st + j * 5 + i * 3) % 8
			blit(c, "oil_spit", at + Vector2(-26 + (k % 4) * 17, -14 + (k / 4) * 28), 0.85)
		var up_t := float(slot["t"][1 - int(slot["down"])])
		var down_t := float(slot["t"][int(slot["down"])])
		var squash := 1.0
		if _flip.has(i):
			squash = absf(1.0 - float(_flip[i]) / 0.15)
		_draw_slice(c, at, up_t, bad_s, squash)
		# Smoke from a side going too far.
		var burnt := RULES.CHEESE_BURNT_BAD if bad_s else RULES.CHEESE_BURNT
		var smoke := clampf((maxf(up_t, down_t) - (burnt - 3.0)) / 3.0, 0.0, 1.0)
		for j in int(ceil(smoke * 3.0)):
			var age := fmod(st / 12.0 * 0.8 + j * 0.33, 1.0)
			blit(c, "smoke", at + Vector2(-12 + j * 12 + sin(age * 6.0 + j) * 3.0, -18 - age * 30.0), smoke * (1.0 - age) * 0.9, 1, false, Color(0.6, 0.58, 0.55))
		# Two bars: the side up (what you see) and the side in the oil.
		var zone := Vector2(RULES.CHEESE_GOLD / 16.0, burnt / 16.0)
		var top := at + Vector2(-16, -SLICE.y * 0.5 - 16)
		_side_bar(c, Rect2(top, Vector2(32, 4)), up_t, zone, false)
		_side_bar(c, Rect2(top + Vector2(0, 7), Vector2(32, 4)), down_t, zone, true)
	# The fryer basket, up on its hook or down in the oil.
	var b: Dictionary = s["basket"]
	var down := str(b["st"]) == "down"
	var bt := float(b["t"])
	var key := "basket_empty"
	if int(b["n"]) > 0:
		key = "basket_gold" if bt >= RULES.FRIES_GOLD else "basket_raw"
	var tint := Color(1, 1, 1)
	if bt > RULES.FRIES_BURNT:
		tint = Color(0.45, 0.35, 0.28)
	if down:
		blit(c, key, BASKET_DOWN, 1.0, 1, false, tint)
		for j in 6:
			var at := Vector2(FRYER.position.x + 10 + fmod(j * 29.0 + st * 4.0, FRYER.size.x - 24), FRYER.position.y + 14 + fmod(j * 17.0 + st * 3.0, FRYER.size.y - 40))
			blit(c, "oil_spit", at, 0.9)
		meter(c, Rect2(FRYER.end.x + 6, FRYER.position.y + 6, 6, 70), bt / 18.0, Vector2(RULES.FRIES_GOLD / 18.0, RULES.FRIES_BURNT / 18.0), _band_col(RULES.fries_state(bt)), true)
	else:
		blit(c, key, BASKET_UP, 1.0, 1, false, tint)
		if int(b["n"]) > 0 and bt > 0.0:
			meter(c, Rect2(FRYER.end.x + 6, FRYER.position.y + 6, 6, 70), bt / 18.0, Vector2(RULES.FRIES_GOLD / 18.0, RULES.FRIES_BURNT / 18.0), _band_col(RULES.fries_state(bt)), true)
	# The rack: what is ready for the pass.
	var cheese := kitchen.prep(building_key, "cheese")
	for i in mini(6, cheese):
		blit(c, "slice_golden_small", RACK.position + Vector2(24 + (i % 2) * 50, 26 + (i / 2) * 20))
	var fries := kitchen.prep(building_key, "fries")
	for i in mini(6, fries):
		blit(c, "chips_rack", RACK.position + Vector2(26 + (i % 2) * 48, 82 + (i / 2) * 14))
	ink(c, RACK.position + Vector2(4, RACK.size.y + 12), "CHEESE %d  CHIPS %d" % [cheese, fries], RETRO_UI.C_BONE)


func _band_col(state: int) -> Color:
	return [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][clampi(state, 0, 2)]


## A side's bar: raw grey, golden in the green, black past it. The side in the oil has
## a flame by it (flickering).
func _side_bar(c: Control, r: Rect2, t: float, zone: Vector2, in_oil: bool) -> void:
	var st := RULES.cheese_side(t, zone.y < RULES.CHEESE_BURNT / 16.0)
	meter(c, r, t / 16.0, zone, _band_col(st))
	if in_oil:
		var f := int(_t * 10.0) % 2
		c.draw_rect(Rect2(r.position + Vector2(-5, 1 - f), Vector2(3, 3 + f)), Color(1.0, 0.55, 0.15))
		c.draw_rect(Rect2(r.position + Vector2(-4, 2), Vector2(1, 2)), Color(1.0, 0.9, 0.5))
	else:
		c.draw_rect(Rect2(r.position + Vector2(-5, 1), Vector2(3, 2)), Color(0.85, 0.82, 0.74))


func _draw_slice(c: Control, at: Vector2, t: float, bad: bool, squash: float) -> void:
	var gold := RULES.CHEESE_GOLD
	var burnt := RULES.CHEESE_BURNT_BAD if bad else RULES.CHEESE_BURNT
	var layers: Array = []
	if t < gold:
		layers = [["slice_bad" if bad and tex("slice_bad") != null else "slice_raw", 1.0], ["slice_golden", t / gold]]
	elif t < burnt:
		layers = [["slice_golden", 1.0], ["slice_burnt", pow((t - gold) / (burnt - gold), 2.0)]]
	else:
		layers = [["slice_burnt", 1.0]]
	for l in layers:
		var tx := tex(str(l[0]))
		if tx == null or float(l[1]) <= 0.0:
			continue
		var sz := tx.get_size() * float(PIX)
		var h := maxf(2.0, floorf(sz.y * squash))
		c.draw_texture_rect(tx, Rect2((at - Vector2(sz.x, h) * 0.5).floor(), Vector2(sz.x, h)), false, Color(1, 1, 1, float(l[1])))


func _paint_bar(c: Control, r: Rect2) -> void:
	super._paint_bar(c, r)
