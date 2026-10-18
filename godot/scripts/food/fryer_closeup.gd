extends "res://scripts/closeup/closeup_view.gd"

## The bistro's stove, close up (assets/textury/closeup/fryer.png): the pan of hot oil and
## the chip basket. What is fried here goes to the pass (scripts/food/hatch_closeup.gd
## takes it from site.prep {cheese, fries}): no fried cheese ready, no smazak goes out.
##   cheese: a breaded slice into the pan (two at a time); it browns, flip it when the
##           underside is golden, then the other; out onto the rack when both are. Too
##           long and it goes black and the cheese runs out of it: the bin.
##   fries:  drop the basket; lift it when they are golden.
## A hand in the kitchen fries without you.
## Everything on the stove is a render (closeup/parts/): the slice raw, golden and burnt
## (cross-faded as it fries), the basket sunk in the oil (pale chips, golden chips), the
## oil spitting, the smoke of a burning side, the portions on the rack.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PIC := "res://assets/textury/closeup/fryer.png"
const SFX_FRY := "res://assets/sfx/bistro/fryer.mp3"
const SFX_FLIP := "res://assets/sfx/bistro/plate_down.mp3"

const PAN := Rect2(10, 80, 135, 66)
const SLICES := Rect2(180, 145, 135, 95)
const BASKET := Rect2(200, 60, 115, 80)
const RACK := Rect2(4, 4, 110, 40)
## A side is golden from GOLD seconds, black from BURNT.
const GOLD := 6.0
const BURNT := 13.0
const FRIES_GOLD := 8.0
const FRIES_BURNT := 15.0
const MAX_PREP := 8
const PARTS := "res://assets/textury/closeup/parts/"

var building_key := ""
var _pan: Array = []            # {down: 0/1 (which side is in the oil), t: [side a, side b], slot}
var _basket := -1.0             # seconds in the oil, -1 = up
var _t := 0.0
var _sizzle: AudioStreamPlayer
var _tex: Dictionary = {}


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	for k in ["cheese_raw", "cheese_golden", "cheese_burnt", "basket_oil", "basket_oil_gold", "chips_portion", "smoke", "oil_spit", "wall_rack"]:
		if ResourceLoader.exists(PARTS + k + ".png"):
			_tex[k] = load(PARTS + k + ".png")
	_sizzle = AudioStreamPlayer.new()
	if ResourceLoader.exists(SFX_FRY):
		var st = load(SFX_FRY)
		if st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			(st as AudioStreamMP3).loop = true
		_sizzle.stream = st
	_sizzle.volume_db = -60.0
	add_child(_sizzle)


static func prep(key: String) -> Dictionary:
	var site: Dictionary = BUSINESS.site(key)
	if site.is_empty():
		return {}
	if not site.has("prep"):
		site["prep"] = {"cheese": 0, "fries": 0}
	return site["prep"]


func _opened() -> void:
	if _sizzle.stream != null:
		_sizzle.play()
	var p := prep(building_key)
	if not p.is_empty():
		say("", "On the rack: %d cheese, %d chips." % [int(p["cheese"]), int(p["fries"])], false)


func _closing() -> void:
	_sizzle.stop()


func _slice_rect(s: Dictionary) -> Rect2:
	return Rect2(PAN.position.x + 22 + int(s["slot"]) * 52, PAN.position.y + 16, 44, 30)


func _hotspots() -> Array:
	var out: Array = []
	for i in _pan.size():
		out.append({"id": "slice:%d" % i, "rect": _slice_rect(_pan[i])})
	out.append({"id": "slices", "rect": SLICES})
	out.append({"id": "basket", "rect": BASKET})
	return out


func _side_state(t: float) -> int:
	return 0 if t < GOLD else (1 if t < BURNT else 2)


func _clicked(id: String) -> void:
	var p := prep(building_key)
	if p.is_empty():
		return
	if id == "slices":
		if _pan.size() >= 2:
			say("", "Two in the pan is all it takes.")
			return
		var have := BUSINESS.stock_of(building_key, "cheese")
		if have <= int(p["cheese"]) + _pan.size():
			say("", "No cheese left in the fridge.")
			return
		if int(p["cheese"]) + _pan.size() >= MAX_PREP:
			say("", "The rack is full.")
			return
		var slot := 0 if _pan.is_empty() or int(_pan[0]["slot"]) == 1 else 1
		_pan.append({"down": 0, "t": [0.0, 0.0], "slot": slot})
		play(SFX_FLIP, -12.0)
		return
	if id.begins_with("slice:"):
		var i := int(id.get_slice(":", 1))
		var s: Dictionary = _pan[i]
		var a := _side_state(float(s["t"][0]))
		var b := _side_state(float(s["t"][1]))
		if a == 2 or b == 2:
			_pan.remove_at(i)
			# Burnt: the bin, and the slice is gone from the books.
			if CoreRoot != null and CoreRoot.actions != null:
				CoreRoot.actions.biz_take(building_key, {"cheese": 1})
			say("", "Black. The bin.")
			return
		if a == 1 and b == 1:
			_pan.remove_at(i)
			p["cheese"] = int(p["cheese"]) + 1
			play(SFX_FLIP, -10.0)
			say("", "Golden. %d on the rack." % int(p["cheese"]))
			return
		s["down"] = 1 - int(s["down"])
		play(SFX_FLIP, -10.0)
		return
	if id == "basket":
		if _basket < 0.0:
			var have := BUSINESS.stock_of(building_key, "potatoes")
			if have <= int(p["fries"]):
				say("", "No potatoes cut.")
				return
			if int(p["fries"]) >= MAX_PREP:
				say("", "The rack is full.")
				return
			_basket = 0.0
			play(SFX_FLIP, -10.0)
			return
		var st := 0 if _basket < FRIES_GOLD else (1 if _basket < FRIES_BURNT else 2)
		_basket = -1.0
		if st == 2:
			if CoreRoot != null and CoreRoot.actions != null:
				CoreRoot.actions.biz_take(building_key, {"potatoes": 1})
			say("", "Burnt to sticks. The bin.")
		elif st == 0:
			say("", "Pale and limp. Back in.")
			_basket = 0.0
		else:
			p["fries"] = int(p["fries"]) + 1
			say("", "Golden. %d portions on the rack." % int(p["fries"]))


func _tick(delta: float) -> void:
	_t += delta
	for s in _pan:
		var d := int(s["down"])
		s["t"][d] = float(s["t"][d]) + delta
	if _basket >= 0.0:
		_basket += delta
	var busy := not _pan.is_empty() or _basket >= 0.0
	_sizzle.volume_db = move_toward(_sizzle.volume_db, -10.0 if busy else -30.0, delta * 40.0)


## A render, `alpha` faded, its own size centred in `r` (scaled to fit when bigger).
func _blit(c: Control, key: String, r: Rect2, alpha := 1.0, tint := Color(1, 1, 1)) -> void:
	var t: Texture2D = _tex.get(key)
	if t == null or alpha <= 0.0:
		return
	var sz := Vector2(t.get_size())
	var k := minf(1.0, minf(r.size.x / sz.x, r.size.y / sz.y))
	var d := Rect2(r.get_center() - sz * k * 0.5, sz * k)
	c.draw_texture_rect(t, d, false, Color(tint.r, tint.g, tint.b, alpha))


## One side of a slice as it fries: the raw render going over to the golden one, then
## the golden to the burnt.
func _draw_side(c: Control, r: Rect2, t: float) -> void:
	if t < GOLD:
		_blit(c, "cheese_raw", r)
		_blit(c, "cheese_golden", r, t / GOLD)
	elif t < BURNT:
		_blit(c, "cheese_golden", r)
		_blit(c, "cheese_burnt", r, pow((t - GOLD) / (BURNT - GOLD), 2.0))
	else:
		_blit(c, "cheese_burnt", r)


func _paint(c: Control) -> void:
	var st := floorf(_t * 12.0)
	# The oil spitting in the pan, in steps: harder round a slice.
	for i in 5:
		var at := Vector2(PAN.position.x + 14 + fmod(i * 23.0 + st * 5.0, PAN.size.x - 28), PAN.position.y + 18 + fmod(i * 13.0 + st * 3.0, PAN.size.y - 36))
		_blit(c, "oil_spit", Rect2(at, Vector2(12, 12)), 0.7)
	for s in _pan:
		var r := _slice_rect(s)
		var up := 1 - int(s["down"])
		var down_t := float(s["t"][int(s["down"])])
		for i in 3:
			var k := int(st + i * 5 + int(s["slot"]) * 3) % 8
			var at := r.position + Vector2(-6 + (k % 4) * (r.size.x / 3.0), -6 + (k / 4) * (r.size.y + 2))
			_blit(c, "oil_spit", Rect2(at, Vector2(12, 12)), 0.9)
		_draw_side(c, r, float(s["t"][up]))
		# The side down going too far: smoke, more of it the nearer black it is.
		var smoke := clampf((down_t - (GOLD + BURNT) * 0.5) / (BURNT - (GOLD + BURNT) * 0.5), 0.0, 1.0)
		if down_t >= BURNT:
			smoke = 1.0
		for i in int(ceil(smoke * 3.0)):
			var age := fmod(st / 12.0 * 0.7 + i * 0.33, 1.0)
			var at := Vector2(r.position.x + 6 + i * 12 + sin(age * 6.0 + i) * 3.0, r.position.y - 6 - age * 26.0)
			_blit(c, "smoke", Rect2(at, Vector2(24, 24)), smoke * (1.0 - age) * 0.8, Color(0.55, 0.53, 0.5))
		if hovered() == "slice:%d" % _pan.find(s):
			c.draw_rect(r.grow(1), Color(1, 0.95, 0.6, 0.18))
	# The basket sunk in the oil (the painting has it up, full): pale chips going golden,
	# black when forgotten; the oil seething over it.
	if _basket >= 0.0:
		var well := Rect2(BASKET.position.x + 6, BASKET.position.y + 8, BASKET.size.x - 12, BASKET.size.y - 14)
		var gold := clampf(_basket / FRIES_GOLD, 0.0, 1.0)
		var dark := clampf((_basket - FRIES_BURNT) / 4.0, 0.0, 1.0)
		var tint := Color(1, 1, 1).lerp(Color(0.38, 0.28, 0.22), dark)
		for key in ["basket_oil", "basket_oil_gold"]:
			var t: Texture2D = _tex.get(key)
			if t != null:
				c.draw_texture_rect(t, well, false, Color(tint.r, tint.g, tint.b, 1.0 if key == "basket_oil" else gold))
		for i in 6:
			var at := Vector2(well.position.x + fmod(i * 29.0 + st * 4.0, well.size.x - 12), well.position.y + fmod(i * 17.0 + st * 3.0, well.size.y - 12))
			_blit(c, "oil_spit", Rect2(at, Vector2(12, 12)), 0.85)
	# The rack: what is ready for the pass, each portion where it lies.
	var p := prep(building_key)
	_blit(c, "wall_rack", RACK)
	if not p.is_empty():
		for i in mini(8, int(p["cheese"])):
			_blit(c, "cheese_golden", Rect2(RACK.position + Vector2(4 + (i % 4) * 26, 2 + (i / 4) * 9), Vector2(26, 18)))
		for i in mini(8, int(p["fries"])):
			_blit(c, "chips_portion", Rect2(RACK.position + Vector2(4 + i * 13, 24), Vector2(18, 18)))
	if hovered() in ["slices", "basket"]:
		for h in _hotspots():
			if str(h["id"]) == hovered():
				c.draw_rect(h["rect"], Color(1.0, 0.92, 0.6, 0.12))
