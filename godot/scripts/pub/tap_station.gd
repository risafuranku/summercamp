extends "res://scripts/pub/pub_station.gd"

## The tap (assets/textury/pub/st_tap.png): the beer tower in the middle, its drip tray,
## the clean mugs on the draining board at the left, the bar top at the right.
##   a mug   click the board: a clean mug under the spout (pulling without one puts one
##           there too, if there is one: no clean mugs, nothing to pour into)
##   pour    hold the left button on the handle: it is pulled, beer with a little head;
##           hold the right one: it is pushed back, foam only. The head settles back to
##           beer while you wait. Over the rim it runs onto the tray.
##   knife   the foam knife off the bar: a stroke takes the top of the head off
##   serve   click the mug: it goes to the mat you picked, or to whoever's order it
##           matches best (pub_rules.judge_pour); the wrong pour they send back.
## The three pours: hladinka (beer to the line, a collar of foam to the rim), snyt (half
## and half), mliko (all foam, a finger of beer). The keg in the cellar decides how it
## comes: the gas low, slow and flat; high, all foam; the keg spent, it coughs.

## The picture's things, in canvas px (two to one of the 320x180 picture).
const SPOUT := Vector2(290, 136)
const MUG_FOOT := Vector2(290, 274)
const HANDLE := Rect2(272, 10, 36, 62)
const HANDLE_PIVOT := Vector2(290, 70)
## Where the knob is painted (picture px) and a patch of plain panelling beside it.
const KNOB_SRC := Rect2(136, 4, 18, 32)
const KNOB_PATCH := Rect2(110, 4, 18, 32)
const BOARD := Rect2(14, 196, 200, 92)
const KNIFE_AT := Vector2(470, 262)
const TRAY := Rect2(214, 250, 190, 60)
## The inside of the mug sprite (shares of its width and height): the glass's body
## between the dimples, its bottom and its rim.
const IN_X := Vector2(0.1, 0.72)
const IN_BOTTOM := 0.94
const IN_RIM := 0.08

var _mug := false
var _beer := 0.0
var _foam := 0.0
var _spilled := 0.0
var _puddle := 0.0
var _pull := false
var _push := false
var _lever := 0.0                  # -1 pushed .. 0 .. 1 pulled (eased)
var _slide := -1.0                 # the mug sliding off to its drinker (s), -1 = none
var _slide_ok := true
var _knife_t := -1.0
var _cough := 0.0
var _drips: Array = []
var _pour_loop: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	station = "tap"
	room = "bar"
	picture = tex("st_tap")
	_rng.randomize()
	for n in ["mug_clean", "mug_beer", "foam", "stream_beer", "stream_foam", "drip", "puddle", "knife", "towel"]:
		tex(n)
	_pour_loop = AudioStreamPlayer.new()
	var path := PUB_SFX + "tap_pour.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_pour_loop.stream = st
	_pour_loop.volume_db = -60.0
	add_child(_pour_loop)


func _rail_slots() -> int:
	# The handle stands up through the rail: the mats stop short of it.
	return 6


func _opened() -> void:
	_pull = false
	_push = false
	if _tickets().is_empty():
		say("", "Nobody at the bar. The tap drips onto the tray.")


func _closing() -> void:
	_pull = false
	_push = false
	_pour_loop.stop()


# ── the mug ──────────────────────────────────────────────────────────────────

func _mug_size() -> Vector2:
	var t := tex("mug_clean")
	return t.get_size() * float(PIX) if t != null else Vector2(80, 96)


func _mug_rect() -> Rect2:
	var sz := _mug_size()
	var foot := MUG_FOOT
	if _slide >= 0.0:
		foot.x += _slide / 0.5 * 160.0
	return Rect2((foot - Vector2(sz.x * 0.5, sz.y)).floor(), sz)


## The inside of the mug (canvas px): its body between bottom and rim.
func _inside() -> Rect2:
	var r := _mug_rect()
	var top := r.position.y + r.size.y * IN_RIM
	var bottom := r.position.y + r.size.y * IN_BOTTOM
	return Rect2(r.position.x + r.size.x * IN_X.x, top, r.size.x * (IN_X.y - IN_X.x), bottom - top)


func _put_mug() -> bool:
	if _mug:
		return true
	if int(taproom.mugs(building_key)["clean"]) <= 0:
		var dirty := int(taproom.mugs(building_key)["dirty"])
		say("", "No clean mugs on the board. %d dirty in the washer." % dirty if dirty > 0 else "No mugs at all.")
		sfx("tick", -14.0, 0.7)
		return false
	_mug = true
	_beer = 0.0
	_foam = 0.0
	_spilled = 0.0
	sfx("glass_down", -10.0, randf_range(0.95, 1.05))
	return true


# ── what can be clicked ──────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if taproom == null:
		return out
	var clean := int(taproom.mugs(building_key)["clean"])
	if not _mug and _slide < 0.0:
		out.append({"id": "board", "rect": BOARD, "verb": ("Put a clean mug under the tap (%d)" % clean) if clean > 0 else "No clean mugs: the washer"})
	out.append({"id": "handle", "rect": HANDLE, "verb": _handle_verb()})
	if _mug and _slide < 0.0 and _beer + _foam > 0.02:
		out.append({"id": "mug", "rect": _mug_rect(), "verb": _mug_verb()})
	if _mug and _foam > 0.04 and _slide < 0.0:
		var kt := tex("knife")
		var ks := kt.get_size() * float(PIX) if kt != null else Vector2(40, 12)
		out.append({"id": "knife", "rect": Rect2(KNIFE_AT - ks * 0.5, ks).grow(4.0), "verb": "Cut the top off the head with the knife"})
	return out


func _handle_verb() -> String:
	match taproom.tap_trouble(building_key):
		"dry":
			return "The tap: no beer in the cellar (order it in the books)"
		"empty":
			return "The tap: the keg is spent (change it in the cellar)"
		"off":
			return "The tap: the head is off the keg (the cellar)"
	if _pull:
		return "Pulling: beer"
	if _push:
		return "Pushed back: foam"
	return "Hold to pull a beer  -  hold the right button for foam"


func _mug_verb() -> String:
	var orders := orders_here("tap")
	if orders.is_empty():
		return "Nobody asked for this one"
	return "Give it to %s (%s)" % [ORDERS_first(str(orders[0]["name"])), PUB.label(str(orders[0]["drink"]))]


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if visible and _closing_t < 0.0 and not get_tree().paused and mb != null and mb.button_index == MOUSE_BUTTON_RIGHT:
		# The right button on the handle pushes it back (anywhere else it steps away).
		if mb.pressed and _hover == "handle":
			_start(false)
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and _push:
			_stop()
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _press(id: String) -> void:
	match id:
		"board":
			_put_mug()
		"handle":
			_start(true)
		"mug":
			_serve()
		"knife":
			_foam = maxf(0.0, _foam - 0.12)
			_knife_t = 0.0
			sfx("scrape", -14.0, 1.4)


func _release(id: String) -> void:
	if id == "handle" and _pull:
		_stop()


func _start(pull: bool) -> void:
	if _slide >= 0.0:
		return
	var trouble: String = taproom.tap_trouble(building_key)
	if trouble != "":
		sfx("tap_open", -6.0, 0.8)
		_cough = 0.5
		say("", {"dry": "The tap coughs air. There is no beer in the cellar: order it in the books.",
			"empty": "The tap spits foam and air. The keg is spent: change it in the cellar.",
			"off": "Nothing comes. The head is off the keg in the cellar."}[trouble])
		return
	if not _put_mug():
		return
	_pull = pull
	_push = not pull
	sfx("tap_open", -6.0)
	_pour_loop.pitch_scale = 1.0 if pull else 1.3
	if not _pour_loop.playing:
		_pour_loop.play()


func _stop() -> void:
	_pull = false
	_push = false
	sfx("tap_close", -6.0)


# ── time ─────────────────────────────────────────────────────────────────────

func _tick(delta: float) -> void:
	_lever = move_toward(_lever, 1.0 if _pull else (-1.0 if _push else 0.0), delta * 9.0)
	var want := (-7.0 if _pull else -13.0) if (_pull or _push) else -60.0
	_pour_loop.volume_db = move_toward(_pour_loop.volume_db, want, delta * 120.0)
	if _pour_loop.volume_db <= -59.0 and _pour_loop.playing:
		_pour_loop.stop()
	if (_pull or _push) and taproom.tap_trouble(building_key) != "":
		_stop()
	_cough = maxf(0.0, _cough - delta)
	_puddle = maxf(0.0, _puddle - delta * 0.004)
	if _knife_t >= 0.0:
		_knife_t += delta
		if _knife_t > 0.35:
			_knife_t = -1.0
	if _slide >= 0.0:
		_slide += delta
		if _slide > 0.5:
			_slide = -1.0
			_mug = false
			_beer = 0.0
			_foam = 0.0
			_spilled = 0.0
	elif _mug:
		_pour(delta)
	for d in _drips:
		d["v"] = minf(60.0, float(d["v"]) + delta * 90.0)
		d["y"] = float(d["y"]) + float(d["v"]) * delta
	_drips = _drips.filter(func(d: Dictionary) -> bool: return float(d["y"]) < MUG_FOOT.y)


func _pour(delta: float) -> void:
	var gas: Dictionary = PUB.gas_pour(float(taproom.keg(building_key)["gas"]))
	if _pull:
		_beer += PUB.POUR_RATE * float(gas["rate"]) * delta
		_foam += PUB.PULL_FOAM * float(gas["foam"]) * delta
	elif _push:
		_beer += PUB.PUSH_BEER * delta
		_foam += PUB.PUSH_FOAM * delta
	if _foam > 0.0:
		var s := minf(_foam, PUB.SETTLE * delta)
		_foam -= s
		_beer += s / 3.0
	var over := _beer + _foam - 1.0
	if over > 0.0:
		# Over the rim: the foam goes first, then the beer.
		var off_foam := minf(over, _foam)
		_foam -= off_foam
		_beer -= over - off_foam
		_spilled += over
		_puddle = minf(1.0, _puddle + over * 2.5)
		if _rng.randf() < 0.25 and _drips.size() < 10:
			var r := _inside()
			_drips.append({"x": r.position.x - 2.0 if _rng.randf() < 0.5 else r.end.x + 2.0, "y": r.position.y, "v": 4.0})


## Over the bar with it: the mat it goes to, judged; sent back if it is not what they
## asked for.
func _serve() -> void:
	var orders := orders_here("tap")
	if orders.is_empty():
		say("", "Nobody asked for that one. You drink it yourself.")
		_slide = 0.0
		_slide_ok = false
		return
	# The mat you picked; else whoever it is closest to what they asked for (the oldest
	# of them when it is nobody's: they send it back).
	var best: Dictionary = orders[0]
	var best_v: Dictionary = PUB.judge_pour(str(best["drink"]), _beer, _foam, _spilled, int(best["age"]))
	if str(best["id"]) != picked:
		for t in orders:
			var v := PUB.judge_pour(str(t["drink"]), _beer, _foam, _spilled, int(t["age"]))
			if bool(v["ok"]) and (not bool(best_v["ok"]) or float(v["accuracy"]) > float(best_v["accuracy"]) + 0.001):
				best = t
				best_v = v
	var who := ORDERS_first(str(best["name"]))
	if not bool(best_v["ok"]):
		say(who, ["Is that a %s? Pour it again.", "That's no %s. Again."][_rng.randi() % 2] % PUB.label(str(best["drink"])).to_lower())
		sfx("glass_down", -12.0, 0.8)
		_slide = 0.0
		_slide_ok = false
		return
	var verdict: Dictionary = taproom.serve(building_key, best, best_v)
	if not bool(verdict.get("ok", false)):
		say("", "The keg ran dry under the glass. Order beer in the books.")
		return
	picked = ""
	_slide = 0.0
	_slide_ok = true
	sfx("coins_bar", -8.0)
	var col := RETRO_UI.C_AMBER_LIGHT if int(verdict["tip"]) > 0 else RETRO_UI.C_BONE
	pop("+$%d" % int(verdict["amount"]), MUG_FOOT + Vector2(60, -110), col, true)
	if int(verdict["stars"]) >= 3:
		say(who, ["Now that's a beer.", "Like my grandad poured.", "Na zdravi!", "Ahh. Perfect.", "You've done this before."][_rng.randi() % 5])
	elif float(verdict["accuracy"]) >= 0.6:
		say(who, ["It'll do.", "Cheers.", "Bit off. Fine."][_rng.randi() % 3] + ("" if _spilled < 0.05 else " And mind the bar."))
	else:
		say(who, "Hm. Thanks.")


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if taproom == null:
		return
	_paint_lever(c)
	# The clean mugs on the draining board, a few in a row and the count.
	var clean := int(taproom.mugs(building_key)["clean"])
	var shown := mini(3, clean - (1 if _mug else 0))
	for i in shown:
		stand(c, "mug_clean", Vector2(BOARD.position.x + 50 + i * 46, BOARD.end.y - 4))
	ink(c, Vector2(BOARD.position.x + 6, BOARD.end.y + 10), "MUGS %d" % clean, RETRO_UI.C_BONE if clean > 0 else RETRO_UI.C_RED_LIGHT)
	# The puddle on the tray, the knife.
	if _puddle > 0.02:
		var pt := tex("puddle")
		if pt != null:
			var ps := pt.get_size() * float(PIX)
			c.draw_texture_rect(pt, Rect2((MUG_FOOT - Vector2(ps.x * 0.5, ps.y * 0.6)).floor(), ps), false, Color(1, 1, 1, minf(0.9, _puddle * 1.5)))
	var knife_at := KNIFE_AT
	if _knife_t >= 0.0:
		var k := _knife_t / 0.35
		knife_at = _inside().position + Vector2(_inside().size.x * k, 0)
	blit(c, "knife", knife_at)
	# The mug under the spout, what is in it, the stream falling into it.
	if _mug:
		var r := _mug_rect()
		var inside := _inside()
		var beer_h := floorf(inside.size.y * clampf(_beer, 0.0, 1.0))
		var foam_h := floorf(inside.size.y * clampf(_foam, 0.0, 1.0 - _beer))
		var bt := tex("mug_beer")
		if bt != null and beer_h >= 1.0:
			# The full mug's render cut off at the beer's level.
			var src := bt.get_size()
			var y_cut := r.position.y + r.size.y * IN_BOTTOM - beer_h
			var share := (r.end.y - y_cut) / r.size.y
			c.draw_texture_rect_region(bt, Rect2(r.position.x, y_cut, r.size.x, r.end.y - y_cut), Rect2(0, src.y * (1.0 - share), src.x, src.y * share))
		var ft := tex("foam")
		if ft != null and foam_h >= 1.0:
			c.draw_texture_rect(ft, Rect2(inside.position.x - 1, inside.end.y - beer_h - foam_h, inside.size.x + 2, foam_h + 2), false)
		stand(c, "mug_clean", Vector2(r.get_center().x, r.end.y), 0.85)
		if (_pull or _push) and _slide < 0.0:
			var st := tex("stream_beer" if _pull and float(PUB.gas_pour(float(taproom.keg(building_key)["gas"]))["foam"]) < 3.0 else "stream_foam")
			if st != null:
				var top := SPOUT.y
				var bottom := inside.end.y - beer_h - foam_h
				var sw := st.get_width() * float(PIX)
				c.draw_texture_rect(st, Rect2(SPOUT.x - sw * 0.5, top, sw, maxf(2.0, bottom - top)), true)
	elif _cough > 0.0:
		blit(c, "drip", SPOUT + Vector2(0, 10 + (0.5 - _cough) * 80.0))
	for d in _drips:
		blit(c, "drip", Vector2(float(d["x"]), float(d["y"])))


## The handle: pulled towards you it tips one way, pushed back the other.
func _paint_lever(c: Control) -> void:
	if picture == null or absf(_lever) < 0.02:
		return
	var src := KNOB_SRC
	var dst := Rect2(src.position * float(PIX), src.size * float(PIX))
	# Plain panelling over the painted knob, then the knob turned about its foot.
	c.draw_texture_rect_region(picture, dst, KNOB_PATCH)
	var pivot := HANDLE_PIVOT
	c.draw_set_transform(pivot, _lever * 0.45, Vector2.ONE)
	c.draw_texture_rect_region(picture, Rect2(dst.position - pivot, dst.size), src)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
