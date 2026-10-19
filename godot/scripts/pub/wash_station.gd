extends "res://scripts/pub/pub_station.gd"

## The glass washer (assets/textury/pub/st_wash.png): the steel counter at the left where
## the dirty mugs come back to, the sink in the middle with its two upright brushes, the
## drying rack at the right.
##   take    click the dirty mugs: one onto the brushes
##   scrub   hold the button on it and work the mouse up and down: the foam rings and the
##           lipstick come off stroke by stroke (pub_rules.SCRUBS), the suds rise
##   rack    click the rack: the clean mug goes up on it (a clean mug for the tap)
## A hand behind the bar washes up too.

const DIRTY := Rect2(12, 150, 170, 150)
const BRUSH_FOOT := Vector2(300, 250)
const RACK := Rect2(420, 120, 210, 170)

var _holding := false
var _dirt := 1.0
var _last_y := -1.0
var _dir := 0
var _scrubbing := false
var _suds: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	station = "wash"
	room = "bar"
	picture = tex("st_wash")
	_rng.randomize()
	for n in ["mug_clean", "mug_dirty", "bubbles"]:
		tex(n)


func _opened() -> void:
	var m: Dictionary = taproom.mugs(building_key)
	if int(m["dirty"]) == 0 and not _holding:
		say("", "Nothing to wash. %d clean mugs." % int(m["clean"]))


func _closing() -> void:
	_scrubbing = false


func _mug_rect() -> Rect2:
	var t := tex("mug_clean")
	var sz := t.get_size() * float(PIX) if t != null else Vector2(80, 96)
	var foot := BRUSH_FOOT + Vector2(0, (_last_y - 200.0) * 0.15 if _scrubbing and _last_y >= 0.0 else 0.0)
	return Rect2((foot - Vector2(sz.x * 0.5, sz.y)).floor(), sz)


func _spots() -> Array:
	var out: Array = []
	if taproom == null:
		return out
	var dirty := int(taproom.mugs(building_key)["dirty"])
	if not _holding:
		out.append({"id": "dirty", "rect": DIRTY, "verb": ("Take a dirty mug (%d)" % dirty) if dirty > 0 else "No dirty mugs"})
	elif _dirt > 0.02:
		out.append({"id": "mug", "rect": _mug_rect().grow(10.0), "verb": "Hold and scrub it up and down on the brushes"})
	else:
		out.append({"id": "rack", "rect": RACK, "verb": "Put it up on the rack"})
		out.append({"id": "mug", "rect": _mug_rect(), "verb": "Clean. Up on the rack with it"})
	return out


func _press(id: String) -> void:
	match id:
		"dirty":
			if int(taproom.mugs(building_key)["dirty"]) <= 0:
				say("", "None dirty. Go and pour.")
				return
			_holding = true
			_dirt = 1.0
			sfx("glass_down", -12.0, 0.9)
		"mug":
			if _dirt > 0.02:
				_scrubbing = true
				_last_y = _mouse.y
				_dir = 0
			else:
				_rack()
		"rack":
			_rack()


func _release(_id: String) -> void:
	_scrubbing = false


func _drag(at: Vector2) -> void:
	if not _scrubbing or at.x < 0.0:
		return
	var dy := at.y - _last_y
	if absf(dy) < 6.0:
		return
	var d := 1 if dy > 0.0 else -1
	if d != _dir:
		# A stroke: the brush turns in the mug, a little dirt off.
		_dir = d
		_dirt = maxf(0.0, _dirt - 1.0 / float(PUB.SCRUBS))
		sfx("scrub", -12.0, randf_range(0.9, 1.15))
		for i in 3:
			_suds.append({"at": _mug_rect().get_center() + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-30, 20)), "t": 0.0})
		if _dirt <= 0.02:
			_scrubbing = false
			say("", "Clean.")
			sfx("glass_clink", -10.0)
	_last_y = at.y


func _rack() -> void:
	var m: Dictionary = taproom.mugs(building_key)
	if int(m["dirty"]) > 0:
		taproom.act(building_key, "mugs", [1, -1])
	_holding = false
	_dirt = 1.0
	pop("+1", RACK.get_center(), RETRO_UI.C_GREEN_LIGHT)
	sfx("glass_down", -10.0, 1.1)


func _tick(delta: float) -> void:
	for s in _suds:
		s["t"] = float(s["t"]) + delta
	_suds = _suds.filter(func(s: Dictionary) -> bool: return float(s["t"]) < 0.8)


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if taproom == null:
		return
	var m: Dictionary = taproom.mugs(building_key)
	# The dirty ones back from the tables, as many as there are (a few shown).
	var dirty := int(m["dirty"]) - (1 if _holding else 0)
	for i in mini(4, maxi(0, dirty)):
		stand(c, "mug_dirty", Vector2(DIRTY.position.x + 40 + (i % 2) * 70, DIRTY.end.y - 6 - (i / 2) * 40))
	ink(c, Vector2(DIRTY.position.x + 4, DIRTY.end.y + 12), "DIRTY %d" % maxi(0, dirty), RETRO_UI.C_BONE)
	# The clean ones up on the rack.
	var clean := int(m["clean"])
	for i in mini(6, clean):
		stand(c, "mug_clean", Vector2(RACK.position.x + 34 + (i % 3) * 66, RACK.position.y + 80 + (i / 3) * 80))
	ink(c, Vector2(RACK.position.x + 4, RACK.end.y + 12), "CLEAN %d" % clean, RETRO_UI.C_BONE)
	# The mug on the brushes: the dirty picture fading off the clean one.
	if _holding:
		var r := _mug_rect()
		stand(c, "mug_clean", Vector2(r.get_center().x, r.end.y))
		stand(c, "mug_dirty", Vector2(r.get_center().x, r.end.y), _dirt)
		meter(c, Rect2(r.end.x + 10, r.position.y + 10, 6, 60), 1.0 - _dirt, Vector2(-1, -1), RETRO_UI.C_GREEN, true)
	for s in _suds:
		blit(c, "bubbles", (s["at"] as Vector2) + Vector2(0, -float(s["t"]) * 30.0), 1.0 - float(s["t"]) / 0.8)
