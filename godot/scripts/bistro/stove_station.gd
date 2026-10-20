extends "res://scripts/bistro/bistro_station.gd"

## The stove (DESIGN.md §7b): its top is a Build texture (st_stove: the tray at the left,
## the big pan, the deep fryer, the warming rack at the right), the things on it sprites
## in the room.
##   fried cheese  take a breaded slice off the tray and lay it in the pan (drag it to a
##                 place, or a click puts it in the first free one). The column over it
##                 is the side in the oil: golden in the green, black past it. Click the
##                 slice to turn it; golden both sides, drag it to the rack (or click);
##                 black, a click bins it.
##   chips         the bucket fills the basket; a click lowers it into the oil, a click
##                 lifts it: golden onto the rack, pale back in, black in the bin.
## The pan and the fryer go on without you (kitchen.gd); the room's marks say so.

const SLOTS := [Vector2(172, 122), Vector2(240, 124), Vector2(206, 175)]
const TRAY := Rect2(0, 48, 64, 172)
const BUCKET := Rect2(0, 228, 76, 60)
const FRYER := Rect2(344, 56, 192, 192)
const BASKET_AT := Vector2(440, 140)
const RACK := Rect2(584, 60, 56, 210)
## How high the basket hangs over the oil on its hook, and how deep it sits in it.
const BASKET_UP := 0.2
const BASKET_DOWN := 0.012
const DRAG_FAR := 8.0

var _tray: Array = []
var _bucket: Sprite3D
var _slices: Array = []
var _slice_meters: Array = []
var _spits: Array = []
var _basket: Sprite3D
var _basket_meter: Sprite3D
var _bubbles: Array = []
var _rack_cheese: Array = []
var _rack_fries: Array = []
var _hand: Sprite3D
var _hand_what := ""
var _press_at := Vector2(-1, -1)
var _far := false
var _flip: Dictionary = {}
var _sizzle: AudioStreamPlayer


func _build() -> void:
	super._build()
	for i in 8:
		_tray.append(bsprite("cheese_breaded", true, 0.55))
	_bucket = bsprite("chips_bucket")
	put(_bucket, BUCKET.get_center(), 0.02)
	for i in SLOTS.size():
		var s := bsprite("slice_raw")
		put(s, SLOTS[i], 0.012)
		_slices.append(s)
		var m := meter()
		m.position = local_at(SLOTS[i] + Vector2(0, -26), 0.03)
		_slice_meters.append(m)
		var spits: Array = []
		for j in 3:
			spits.append(bsprite("oil_spit"))
		_spits.append(spits)
	_basket = bsprite("basket_empty")
	_basket_meter = meter(4, 18)
	_basket_meter.position = local_at(Vector2(FRYER.end.x + 12, FRYER.position.y + 40), 0.03)
	for j in 6:
		_bubbles.append(bsprite("oil_spit"))
	for i in 6:
		var c := bsprite("slice_golden_small")
		put(c, RACK.position + Vector2(28, 22 + i * 14), 0.015)
		_rack_cheese.append(c)
		var f := bsprite("chips_rack")
		put(f, RACK.position + Vector2(28, 120 + i * 14), 0.015)
		_rack_fries.append(f)
	_hand = bsprite("slice_raw")
	_hand.visible = false
	_sizzle = AudioStreamPlayer.new()
	var path := "res://assets/sfx/bistro/fryer.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStreamMP3).duplicate()
		st.loop = true
		_sizzle.stream = st
	_sizzle.volume_db = -60.0
	add_child(_sizzle)


func _ks() -> Dictionary:
	return kitchen.site(building_key)


# ── what the state looks like ────────────────────────────────────────────────

func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var s := _ks()
	var st := int(_t * 12.0)
	# The tray: the breaded slices waiting, in two rows (the badly breaded ones last).
	var good := kitchen.prep(building_key, "cheese_raw")
	var bad := kitchen.prep(building_key, "cheese_bad")
	if _hand_what == "tray":
		if good > 0:
			good -= 1
		else:
			bad -= 1
	for i in _tray.size():
		var spr: Sprite3D = _tray[i]
		spr.visible = i < good + bad
		if spr.visible:
			bretex(spr, "cheese_patchy" if i >= good else "cheese_breaded", 0.55)
			put(spr, TRAY.position + Vector2(18 + (i % 2) * 28, 30 + (i / 2) * 26), 0.012 + (i % 2) * 0.002)
	_bucket.visible = kitchen.prep(building_key, "chips_raw") > 0
	# The pan: each slice, the side up as it is, the side down on its column.
	for i in SLOTS.size():
		var slot: Dictionary = s["pan"][i]
		var spr: Sprite3D = _slices[i]
		var m: Sprite3D = _slice_meters[i]
		var empty := slot.is_empty() or _hand_what == "slot:%d" % i
		spr.visible = not empty
		m.visible = not slot.is_empty()
		for sp in _spits[i]:
			(sp as Sprite3D).visible = false
		if slot.is_empty():
			continue
		var bad_s := bool(slot.get("bad", false))
		var up_t := float(slot["t"][1 - int(slot["down"])])
		var down_t := float(slot["t"][int(slot["down"])])
		var burnt := RULES.CHEESE_BURNT_BAD if bad_s else RULES.CHEESE_BURNT
		bretex(spr, _slice_tex(up_t, bad_s))
		# Turned over a moment ago: up off the oil and back down, in steps.
		var lift := 0.012
		if _flip.has(i) and float(_flip[i]) < 0.25:
			lift += 0.05 if float(_flip[i]) < 0.17 else 0.02
		put(spr, SLOTS[i], lift)
		var down_state := RULES.cheese_side(down_t, bad_s)
		set_meter(m, down_t / (burnt + 2.0), Vector2(RULES.CHEESE_GOLD / (burnt + 2.0), burnt / (burnt + 2.0)), [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][down_state], down_state == 2)
		if not empty:
			var spits: Array = _spits[i]
			for j in spits.size():
				var sp: Sprite3D = spits[j]
				var k := (st + j * 5 + i * 3) % 8
				sp.visible = k < 5
				put(sp, SLOTS[i] + Vector2(-24 + (k % 4) * 16, -12 + (k / 4) * 26), 0.016)
	# The basket: up on its hook or down in the oil.
	var b: Dictionary = s["basket"]
	var down := str(b["st"]) == "down"
	var bt := float(b["t"])
	var key := "basket_empty"
	if int(b["n"]) > 0:
		key = "basket_gold" if bt >= RULES.FRIES_GOLD else "basket_raw"
	bretex(_basket, key, 2.0)
	_basket.modulate = Color(0.45, 0.35, 0.28) if bt > RULES.FRIES_BURNT else (Color(0.8, 0.7, 0.55) if down else Color(1, 1, 1))
	put(_basket, BASKET_AT, BASKET_DOWN if down else BASKET_UP)
	for j in _bubbles.size():
		var bub: Sprite3D = _bubbles[j]
		bub.visible = down
		if down:
			put(bub, Vector2(FRYER.position.x + 14 + fmod(j * 29.0 + st * 4.0, FRYER.size.x - 28), FRYER.position.y + 16 + fmod(j * 17.0 + st * 3.0, FRYER.size.y - 40)), 0.02)
	_basket_meter.visible = int(b["n"]) > 0 and (down or bt > 0.0)
	if _basket_meter.visible:
		var fs := RULES.fries_state(bt)
		set_meter(_basket_meter, bt / (RULES.FRIES_BURNT + 3.0), Vector2(RULES.FRIES_GOLD / (RULES.FRIES_BURNT + 3.0), RULES.FRIES_BURNT / (RULES.FRIES_BURNT + 3.0)), [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][fs], fs == 2)
	# The rack: what is ready for the pass.
	var cheese := kitchen.prep(building_key, "cheese")
	var fries := kitchen.prep(building_key, "fries")
	for i in _rack_cheese.size():
		(_rack_cheese[i] as Sprite3D).visible = i < cheese
	for i in _rack_fries.size():
		(_rack_fries[i] as Sprite3D).visible = i < fries


## The side you see: raw, browning, golden, going black.
func _slice_tex(t: float, bad: bool) -> String:
	var burnt := RULES.CHEESE_BURNT_BAD if bad else RULES.CHEESE_BURNT
	if t < RULES.CHEESE_GOLD:
		return "slice_bad" if bad and t < RULES.CHEESE_GOLD * 0.5 else "slice_raw"
	if t < burnt:
		return "slice_golden"
	return "slice_burnt"


# ── what can be used ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var s := _ks()
	var raw := kitchen.prep(building_key, "cheese_raw") + kitchen.prep(building_key, "cheese_bad")
	if raw > 0:
		out.append({"id": "tray", "rect": TRAY, "verb": "Take a breaded slice (%d)" % raw})
	var b: Dictionary = s["basket"]
	var chips := kitchen.prep(building_key, "chips_raw")
	if str(b["st"]) == "up" and int(b["n"]) == 0 and chips > 0:
		out.append({"id": "bucket", "rect": BUCKET, "verb": "Fill the basket with raw chips (%d)" % chips})
	if int(b["n"]) > 0:
		out.append({"id": "basket", "node": _basket, "verb": _basket_verb(b)})
	for i in SLOTS.size():
		var slot: Dictionary = s["pan"][i]
		if not slot.is_empty():
			out.append({"id": "slot:%d" % i, "node": _slices[i], "verb": _slot_verb(slot)})
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
	if str(b["st"]) == "up":
		return "Lower the basket into the oil"
	match RULES.fries_state(float(b["t"])):
		0:
			return "Lift the basket (still pale)"
		1:
			return "Lift the basket: golden"
	return "Lift the basket: burnt"


# ── the hand ─────────────────────────────────────────────────────────────────

func _press(id: String) -> void:
	_press_at = _mouse
	_far = false
	var s := _ks()
	if id == "tray":
		var bad := kitchen.prep(building_key, "cheese_raw") <= 0
		_hand_what = "tray"
		bretex(_hand, "slice_bad" if bad else "slice_raw")
		_hand.visible = true
		_drag(_mouse_free)
		sfx("tick", -16.0, 1.4)
		return
	if id.begins_with("slot:"):
		var i := int(id.get_slice(":", 1))
		var slot: Dictionary = s["pan"][i]
		if slot.is_empty():
			return
		var bad := bool(slot.get("bad", false))
		var down := RULES.cheese_side(float(slot["t"][int(slot["down"])]), bad)
		var up := RULES.cheese_side(float(slot["t"][1 - int(slot["down"])]), bad)
		if down == 1 and up == 1:
			# Golden: picked up, to the rack.
			_hand_what = id
			bretex(_hand, "slice_golden")
			_hand.visible = true
			_drag(_mouse_free)
		return
	if id == "bucket":
		_fill_basket()
		return
	if id == "basket":
		_basket_click()


func _drag(at: Vector2) -> void:
	if _hand_what == "" or at.x < -500.0:
		return
	if _press_at.x >= 0.0 and at.distance_to(_press_at) > DRAG_FAR:
		_far = true
	_hand.position = held_at(0.07)
	# Where it would go lights up: the free place in the pan, the rack.
	if not _far:
		mark_target(Rect2())
	elif _hand_what == "tray":
		var slot := _slot_near(at)
		mark_target(Rect2(SLOTS[slot] - Vector2(32, 20), Vector2(64, 40)) if slot >= 0 else Rect2())
	else:
		mark_target(RACK if RACK.grow(30.0).has_point(at) else Rect2())


func _release(id: String) -> void:
	var what := _hand_what
	_hand_what = ""
	_hand.visible = false
	mark_target(Rect2())
	var at := _mouse_free
	if what == "tray":
		var slot := _slot_near(at) if _far else _first_free()
		if slot < 0:
			if _far:
				return
			say("", "The pan is full.")
			return
		_lay_slice(slot)
		return
	if what.begins_with("slot:"):
		if _far and not RACK.grow(30.0).has_point(at):
			return
		_to_rack(int(what.get_slice(":", 1)))
		return
	if id.begins_with("slot:") and what == "":
		_slot_click(int(id.get_slice(":", 1)))


## The free place in the pan nearest a point (-1 none near).
func _slot_near(at: Vector2) -> int:
	var best := -1
	var best_d := 64.0
	for i in SLOTS.size():
		if not (_ks()["pan"][i] as Dictionary).is_empty():
			continue
		var d := at.distance_to(SLOTS[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _first_free() -> int:
	for i in SLOTS.size():
		if (_ks()["pan"][i] as Dictionary).is_empty():
			return i
	return -1


func _lay_slice(slot: int) -> void:
	var bad := false
	if not kitchen.take(building_key, "cheese_raw"):
		if not kitchen.take(building_key, "cheese_bad"):
			sfx("tick", -14.0, 0.7)
			return
		bad = true
	kitchen.act(building_key, "pan", [slot, {"bad": bad, "down": 0, "t": [0.0, 0.0]}])
	_flip[slot] = 1.0
	sfx("sizzle_in", -6.0, randf_range(0.95, 1.05))


func _slot_click(i: int) -> void:
	var slot: Dictionary = (_ks()["pan"][i] as Dictionary).duplicate(true)
	if slot.is_empty():
		return
	var bad := bool(slot.get("bad", false))
	var down := RULES.cheese_side(float(slot["t"][int(slot["down"])]), bad)
	var up := RULES.cheese_side(float(slot["t"][1 - int(slot["down"])]), bad)
	if down == 2 or up == 2:
		kitchen.act(building_key, "pan", [i, {}])
		pop("BURNT", SLOTS[i] - Vector2(0, 20), RETRO_UI.C_RED_LIGHT)
		sfx("scrape", -8.0)
		return
	slot["down"] = 1 - int(slot["down"])
	kitchen.act(building_key, "pan", [i, slot])
	_flip[i] = 0.0
	sfx("flip", -8.0, randf_range(0.9, 1.1))


func _to_rack(i: int) -> void:
	if not kitchen.room_for(building_key, "cheese"):
		say("", "The rack is full.")
		return
	kitchen.act(building_key, "pan", [i, {}])
	kitchen.act(building_key, "prep", ["cheese", 1])
	pop("+1", RACK.get_center() + Vector2(0, -60), RETRO_UI.C_GREEN_LIGHT)
	sfx("plate_down", -10.0, 1.2)


func _fill_basket() -> void:
	var n := mini(RULES.BASKET_PORTIONS, kitchen.prep(building_key, "chips_raw"))
	if n <= 0:
		return
	kitchen.act(building_key, "prep", ["chips_raw", -n])
	kitchen.act(building_key, "basket", [{"st": "up", "t": 0.0, "n": n}])
	sfx("chips_load", -8.0)


func _basket_click() -> void:
	var b: Dictionary = (_ks()["basket"] as Dictionary).duplicate()
	if int(b["n"]) == 0:
		return
	if str(b["st"]) == "up":
		b["st"] = "down"
		kitchen.act(building_key, "basket", [b])
		sfx("basket_drop", -4.0)
		return
	var st := RULES.fries_state(float(b["t"]))
	if st == 2:
		kitchen.act(building_key, "basket", [{"st": "up", "t": 0.0, "n": 0}])
		pop("BURNT", BASKET_AT, RETRO_UI.C_RED_LIGHT)
		sfx("scrape", -8.0)
	elif st == 0:
		b["st"] = "up"
		kitchen.act(building_key, "basket", [b])
		say("", "Pale and limp. Back in with them.")
		sfx("basket_lift", -8.0)
	else:
		var room_left := mini(int(b["n"]), int(RULES.PREP_CAP["fries"]) - kitchen.prep(building_key, "fries"))
		if room_left <= 0:
			say("", "The rack is full.")
			b["st"] = "up"
			kitchen.act(building_key, "basket", [b])
			return
		kitchen.act(building_key, "basket", [{"st": "up", "t": 0.0, "n": 0}])
		kitchen.act(building_key, "prep", ["fries", room_left])
		pop("+%d" % room_left, RACK.get_center() + Vector2(0, 40), RETRO_UI.C_GREEN_LIGHT)
		sfx("basket_lift", -6.0)


func _tick(delta: float) -> void:
	for k in _flip.keys():
		_flip[k] = float(_flip[k]) + delta
		if float(_flip[k]) > 0.4:
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


func _opened() -> void:
	if _sizzle.stream != null:
		_sizzle.play()


func _closing() -> void:
	_sizzle.stop()
	_hand_what = ""
	_hand.visible = false


# ── debug (tools/bistro_shots.gd, tools/bistro_coop.gd) ──────────────────────

## As a player would: a slice from the tray into the first free place.
func debug_lay() -> void:
	var i := _first_free()
	if i >= 0:
		_lay_slice(i)


func debug_click(id: String) -> void:
	if id.begins_with("slot:"):
		var i := int(id.get_slice(":", 1))
		var slot: Dictionary = _ks()["pan"][i]
		if slot.is_empty():
			return
		var bad := bool(slot.get("bad", false))
		if RULES.cheese_side(float(slot["t"][0]), bad) == 1 and RULES.cheese_side(float(slot["t"][1]), bad) == 1:
			_to_rack(i)
		else:
			_slot_click(i)
	elif id == "bucket":
		_fill_basket()
	elif id == "basket":
		_basket_click()
