extends "res://scripts/bistro/station_view.gd"

## The sink (assets/textury/bistro/st_sink.png): the dirty plates come back from the
## tables onto the draining board on their own (kitchen.gd, when the guests have eaten);
## the pass has only the clean ones on the rack.
##   click the pile: a plate into the water; then hold the button on it and scrub, up and
##   down, the goulash and the crumbs coming off stroke by stroke; clean, a click puts it
##   in the rack.

const PILE := Rect2(30, 75, 150, 190)
const WATER_AT := Vector2(320, 175)
const WATER := Rect2(195, 80, 250, 180)
const RACK := Rect2(470, 50, 160, 160)
const STROKES := 900.0

var _in_water := false
var _dirt := 1.0
var _scrubbing := false
var _last := Vector2(-1, -1)
var _bubbles: Array = []
var _rack_t := -1.0


func _ready() -> void:
	super._ready()
	station = "sink"
	how = "Click the pile: a plate in the water. Hold on it and rub. Clean: click it onto the stack."
	room = "kitchen"
	picture = tex("st_sink")
	for n in ["plate_dirty", "plate_top", "sponge", "bubbles", "plates_stack"]:
		tex(n)


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var pl: Dictionary = kitchen.plates(building_key)
	var dirty := int(pl["dirty"]) - (1 if _in_water else 0)
	if not _in_water:
		out.append({"id": "pile", "rect": PILE, "verb": ("Put a dirty plate in the water (%d)" % dirty) if dirty > 0 else "No dirty plates"})
	else:
		out.append({"id": "plate", "rect": WATER, "verb": "Scrub the plate (hold and rub)" if _dirt > 0.0 else "Clean: into the rack"})
	return out


func _press(id: String) -> void:
	match id:
		"pile":
			if int(kitchen.plates(building_key)["dirty"]) <= 0:
				return
			_in_water = true
			_dirt = 1.0
			sfx("splash", -8.0)
		"plate":
			if _dirt <= 0.0:
				# In the rack: one clean, one dirty fewer.
				kitchen.act(building_key, "plates", [1, -1])
				_in_water = false
				_rack_t = 0.0
				pop("+1", RACK.get_center(), RETRO_UI.C_GREEN_LIGHT)
				sfx("plate_rack", -8.0)
				return
			_scrubbing = true
			_last = _mouse


func _release(_id: String) -> void:
	_scrubbing = false


func _drag(at: Vector2) -> void:
	if not _scrubbing or at.x < 0.0 or _dirt <= 0.0:
		return
	var d := (at - _last).length()
	_last = at
	if d <= 0.5:
		return
	_dirt = maxf(0.0, _dirt - d / STROKES)
	if randf() < d / 40.0:
		_bubbles.append({"at": at + Vector2(randf_range(-10, 10), randf_range(-6, 6)), "t": 0.0})
	if randf() < d / 120.0:
		sfx("scrub", -14.0, randf_range(0.9, 1.15))
	if _dirt <= 0.0:
		pop("CLEAN", WATER_AT + Vector2(0, -40), RETRO_UI.C_GREEN_LIGHT)
		sfx("tick", -10.0, 1.4)
		_scrubbing = false


func _tick(delta: float) -> void:
	for b in _bubbles:
		b["t"] = float(b["t"]) + delta
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return float(b["t"]) < 0.7)
	if _rack_t >= 0.0:
		_rack_t += delta
		if _rack_t > 0.4:
			_rack_t = -1.0


func _closing() -> void:
	# A plate half washed goes back on the pile (it is still counted dirty).
	_in_water = false
	_scrubbing = false


func _paint(c: Control) -> void:
	if kitchen == null:
		return
	var pl: Dictionary = kitchen.plates(building_key)
	var dirty := int(pl["dirty"]) - (1 if _in_water else 0)
	# The pile on the draining board.
	for i in mini(dirty, 10):
		var at := PILE.get_center() + Vector2((i % 2) * 4 - 2, 30 - i * 6)
		if tex("plate_dirty") != null:
			var t := tex("plate_dirty")
			var ts := t.get_size() * float(PIX)
			c.draw_texture_rect(t, Rect2((at - Vector2(ts.x * 0.5, ts.y * 0.3)).floor(), Vector2(ts.x, floorf(ts.y * 0.6))), false)
	ink(c, PILE.position + Vector2(4, PILE.size.y + 10), "DIRTY %d" % maxi(0, dirty), RETRO_UI.C_BONE)
	# The plate in the water, the dirt fading.
	if _in_water:
		blit(c, "plate_top", WATER_AT, 1.0)
		blit(c, "plate_dirty", WATER_AT, _dirt)
		if _scrubbing:
			blit(c, "sponge", _mouse + Vector2(0, -4))
		var r := Rect2(WATER.position.x + 10, WATER.end.y + 4, WATER.size.x - 20, 5)
		meter(c, r, 1.0 - _dirt, Vector2(-1, -1), RETRO_UI.C_GREEN)
	for b in _bubbles:
		var k := float(b["t"]) / 0.7
		blit(c, "bubbles", (b["at"] as Vector2) + Vector2(0, -k * 10.0), 1.0 - k)
	# The rack: the clean plates standing in it.
	var clean := int(pl["clean"])
	# The clean ones stacked on the counter, a stack a five.
	for i in mini(clean, 15):
		blit(c, "plates_stack", RACK.position + Vector2(40 + (i / 5) * 60, 120 - (i % 5) * 8))
	ink(c, RACK.position + Vector2(4, RACK.size.y + 10), "CLEAN %d" % clean, RETRO_UI.C_BONE if clean > 0 else RETRO_UI.C_RED_LIGHT)
