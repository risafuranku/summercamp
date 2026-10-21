extends "res://scripts/pub/pub_station.gd"

## The tap (DESIGN.md §7b "the pub"), worked on the bar in the room: the chrome tower seen
## from the side, its faucet's spout over the drip tray, the black handle on top of it,
## the clean mugs on the board at the left (the washer puts them there), the foam knife
## at the right. Things are sprites at the room's pixel (the pub's Grok sheets).
##   a mug   click the board: a clean mug under the spout (no clean mugs, nothing to pour
##           into: the washer)
##   pour    take the handle and draw it towards you: beer, with a little head; push it
##           away: foam only. Let go and it springs back. The head settles back to beer
##           while you wait; over the rim it runs onto the tray.
##   knife   a click takes the top off the head
##   serve   click the mug: over the bar to the mat you picked, or to whoever's order it
##           matches best (pub_rules.judge_pour); the wrong pour they send back: a mark
##           in pencil on their mat, the money when they go.
##   the bill on the bar's right (scripts/pub/bill_spot.gd): the mat of whoever wants to
##           pay with their marks; a click on it (or on BILL on the rail) settles it.
## SERVE (Space, Enter) sends the mug over; the next step is lit (`next_hint`): a mug,
## the handle towards you to the line, SERVE; the washer when the board is bare, the
## cellar when the keg will not pour.
## The three pours: hladinka (beer to the line, a collar of foam to the rim), snyt (half
## and half), mliko (all foam, a finger of beer). The keg in the cellar decides how it
## comes: the gas low, slow and flat; high, all foam; the keg spent, it coughs; flat when
## it has been on the line too long.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
## On the bar (design px across the surface, pub_layout.SURFACES: 2.5 mm a px): the
## tower, the mug's place under its spout (the faucet reaches left of the column: the
## tower's picture, pub/tap_tower.png, 0.38 m tall: its spout 14 of its 64 px left of
## the middle, 35 px up; the handle's socket 6 px left, at the top), the board of clean
## mugs (two rows of three: more than that is in the count), the knife.
const TOWER_AT := Vector2(320, 180)
const TOWER_M := 0.38
const MUG_FOOT := Vector2(287, 188)
const HANDLE_AT := Vector2(305, 184)
const BOARD := Rect2(56, 146, 168, 92)
const BOARD_SPOTS := [Vector2(186, 168), Vector2(136, 168), Vector2(86, 168), Vector2(176, 214), Vector2(126, 214), Vector2(76, 214)]
const KNIFE_AT := Vector2(404, 206)
## The second tap (gear, camp/gear_tap2.png) right of the tower, once bought.
const TAP2_AT := Vector2(356, 182)
const TAP2_M := 0.3
## The spout's tip over the bar top, and the handle's pivot on the faucet (metres).
const SPOUT_UP := 0.208
const HANDLE_UP := 0.375
## The mug: its height on the bar, and the inside of its picture (shares): its body between
## the bottom and the rim.
const MUG_M := 0.18
const IN_BOTTOM := 0.94
const IN_RIM := 0.08

var _tap2: Sprite3D
var _mug := false
var _beer := 0.0
var _foam := 0.0
var _spilled := 0.0
var _puddle := 0.0
var _lever := 0.0
var _grab_y := -1.0
var _slide := -1.0
var _knife_t := -1.0
var _cough := 0.0
var _rng := RandomNumberGenerator.new()
var _pour_loop: AudioStreamPlayer

var _mug_spr: Sprite3D
var _beer_spr: Sprite3D
var _foam_spr: Sprite3D
var _stream: Sprite3D
var _puddle_spr: Sprite3D
var _knife: Sprite3D
var _board_mugs: Array = []
var _handle: Sprite3D
var _handle_pivot: Node3D
var _level_meter: Sprite3D
## The bill on the bar's right (bill_spot.gd).
var _bill: Node3D


func _build() -> void:
	super._build()
	_rng.randomize()
	_build_tower()
	for i in BOARD_SPOTS.size():
		_board_mugs.append(psprite("mug_clean", MUG_M))
	_puddle_spr = psprite("puddle", 0.22, true)
	_puddle_spr.visible = false
	put(_puddle_spr, MUG_FOOT, 0.005)
	_mug_spr = psprite("mug_clean", MUG_M)
	_beer_spr = psprite("mug_beer", MUG_M)
	_beer_spr.region_enabled = true
	_foam_spr = psprite("foam", 0.12)
	_stream = psprite("stream_beer", 0.3)
	_stream.region_enabled = true
	_knife = psprite("knife", 0.16, true)
	put(_knife, KNIFE_AT, 0.006)
	_level_meter = meter(5, 18)
	_level_meter.position = local_at(MUG_FOOT + Vector2(-46, 0), 0.1)
	_pour_loop = AudioStreamPlayer.new()
	var path := "res://assets/sfx/pub/tap_pour.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_pour_loop.stream = st
	_pour_loop.volume_db = -60.0
	add_child(_pour_loop)
	_bill = load("res://scripts/pub/bill_spot.gd").new()
	_bill.name = "Bill"
	add_child(_bill)
	_bill.call("setup", self)


## The tower (a sprite standing on the bar, its foot at TOWER_AT), the drip tray under the
## spout, the handle on its pivot on top of the faucet: it tips left as it is drawn
## towards you (beer), right as it is pushed away (foam).
func _build_tower() -> void:
	put(psprite("tap_tower", TOWER_M), TOWER_AT, 0.0)
	_tap2 = sprite("res://assets/textury/camp/gear_tap2.png", TAP2_M, false)
	if _tap2.texture != null:
		_tap2.offset = Vector2(0, float(_tap2.texture.get_height()) * 0.5)
	put(_tap2, TAP2_AT, 0.0)
	_tap2.visible = false
	put(psprite("drip_tray", 0.22, true), MUG_FOOT, 0.003)
	_handle_pivot = Node3D.new()
	_handle_pivot.position = local_at(HANDLE_AT, HANDLE_UP)
	add_child(_handle_pivot)
	_handle = psprite("tap_handle", 0.15)
	remove_child(_handle)
	_handle_pivot.add_child(_handle)
	_handle.position = Vector3.ZERO


# ── what the state looks like ────────────────────────────────────────────────

## The bill being worked here: the picked one if it is a bill, else the oldest.
func serves_kind() -> String:
	return "tap"


func serve_ready() -> bool:
	return _mug and _slide < 0.0 and _beer + _foam > 0.3 and absf(_lever) <= 0.5 and not orders_here("tap").is_empty()


func serve_now() -> void:
	_serve()


## A beer's checklist: a clean mug, the pour they want (beer to the line, half and half,
## all foam), up to the rim, nothing over it.
func checklist(t: Dictionary) -> Array:
	if str(t.get("kind", "")) == "bill" or PUB.kind(str(t.get("drink", ""))) != "tap":
		return super.checklist(t)
	var drink := str(t["drink"])
	var want := float(PUB.DRINKS[drink]["beer"])
	var top := _beer + _foam
	var pour_word: String = {"hladinka": "BEER TO THE LINE", "snyt": "HALF BEER, HALF FOAM", "mliko": "ALL FOAM"}.get(drink, "BEER")
	var near := absf(_beer - want) <= 0.065
	return [
		{"text": "A CLEAN MUG", "state": "done" if _mug else "todo"},
		{"text": pour_word, "state": ("done" if near else ("bad" if _beer > want + 0.065 else "todo")) if _mug and top > 0.05 else "todo"},
		{"text": "UP TO THE RIM", "state": "done" if _mug and top >= 0.92 else "todo"},
		{"text": "NOTHING SPILT", "state": "bad" if _spilled > 0.05 else ("done" if _mug and top >= 0.92 else "todo")},
	]


## What is best to do at the tap now: settle a bill (a click on its mat), a mug for the
## beer ordered, the handle towards you to the line (away for an all-foam mliko), SERVE;
## the washer when no clean mug is left, the cellar when the keg will not pour, the
## bottles when only shots and kofolas wait.
func next_hint() -> Dictionary:
	if taproom == null or building_key == "":
		return {}
	var orders := orders_here("tap")
	if not orders.is_empty():
		var t: Dictionary = orders[0]
		var trouble: String = taproom.tap_trouble(building_key)
		if trouble != "" and trouble != "flat":
			return {"tab": "keg"}
		if not _mug:
			if int(taproom.mugs(building_key)["clean"]) <= 0:
				return {"tab": "wash"}
			return {"rect": BOARD, "gesture": "click"}
		var want := float(PUB.DRINKS[str(t["drink"])]["beer"])
		if _beer + _foam < 0.92:
			var foam_first := str(t["drink"]) == "mliko" and _foam < 0.6
			return {"node": _handle, "gesture": "drag", "to": HANDLE_AT + Vector2(0, -70 if foam_first else 70)}
		if _beer < want - 0.065:
			return {"node": _handle, "gesture": "drag", "to": HANDLE_AT + Vector2(0, 70)}
		return {"ui": "serve"}
	if not current_bill().is_empty():
		return {"rect": _bill.MAT, "gesture": "click"}
	if not orders_here("bar").is_empty():
		return {"tab": "back"}
	if int(taproom.mugs(building_key)["clean"]) <= 1 and int(taproom.mugs(building_key)["dirty"]) > 0:
		return {"tab": "wash"}
	return {}


func current_bill() -> Dictionary:
	var all := bills()
	for b in all:
		if str(b["id"]) == picked:
			return b
	return all[0] if not all.is_empty() else {}


func _show() -> void:
	if taproom == null or building_key == "":
		return
	_bill.call("pick", current_bill())
	_bill.call("show_state")
	_tap2.visible = BUSINESS.has_gear(building_key, "tap2")
	var clean := int(taproom.mugs(building_key)["clean"]) - (1 if _mug else 0)
	for i in _board_mugs.size():
		var s: Sprite3D = _board_mugs[i]
		s.visible = i < clean
		put(s, BOARD_SPOTS[i], 0.0)
	_puddle_spr.visible = _puddle > 0.05
	_mug_spr.visible = _mug
	_beer_spr.visible = _mug and _beer > 0.01
	_foam_spr.visible = _mug and _foam > 0.01
	# The bar's stations stand side by side: a column only at the one you are at.
	_level_meter.visible = _mug and is_open()
	var foot := MUG_FOOT
	if _slide >= 0.0:
		# Over the bar to the guest, sliding (smooth).
		var ks := clampf(_slide / 0.5, 0.0, 1.0)
		foot.y -= (1.0 - pow(1.0 - ks, 2.0)) * 220.0
	if _mug:
		put(_mug_spr, foot, 0.004)
		var tex := _beer_spr.texture
		if tex != null:
			var H := float(tex.get_height())
			var W := float(tex.get_width())
			var inside := IN_BOTTOM - IN_RIM
			var h := maxf(1.0, floorf(H * ((1.0 - IN_BOTTOM) + inside * clampf(_beer, 0.0, 1.0))))
			_beer_spr.region_rect = Rect2(0, H - h, W, h)
			_beer_spr.offset = Vector2(0, h * 0.5)
			# Over the empty mug's picture, a hair nearer the eye (no flicker between them).
			put(_beer_spr, foot, 0.004)
			_beer_spr.position.z += 0.003
			# The head on the beer, as thick as the foam is.
			var level_m := MUG_M * ((1.0 - IN_BOTTOM) + inside * clampf(_beer, 0.0, 1.0))
			var foam_m := MUG_M * inside * clampf(_foam, 0.0, 1.0 - _beer)
			_foam_spr.scale = Vector3(1.0, maxf(0.15, foam_m / 0.05), 1.0)
			_foam_spr.position = local_at(foot, 0.004) + Vector3(0, level_m, 0.005)
		set_meter(_level_meter, _beer + _foam, Vector2(PUB.LINE - 0.04, 1.0), RETRO_UI.C_AMBER if _beer + _foam < 1.0 else RETRO_UI.C_RED)
	# The stream from the spout down into the mug while it runs.
	var running: bool = _mug and absf(_lever) > 0.5 and _slide < 0.0 and taproom.tap_trouble(building_key) == ""
	_stream.visible = running
	if running:
		pretex(_stream, "stream_beer" if _lever > 0.0 else "stream_foam", 0.3)
		var top := SPOUT_UP
		var level := MUG_M * ((1.0 - IN_BOTTOM) + (IN_BOTTOM - IN_RIM) * clampf(_beer + _foam, 0.0, 1.0))
		var len := maxf(0.02, top - level)
		var tex2 := _stream.texture
		if tex2 != null:
			var px := maxf(1.0, floorf(len / _stream.pixel_size))
			_stream.region_rect = Rect2(0, 0, tex2.get_width(), minf(px, tex2.get_height()))
			_stream.offset = Vector2(0, minf(px, tex2.get_height()) * 0.5)
			_stream.position = local_at(MUG_FOOT, 0.004) + Vector3(0, level, 0.002)
	# The handle drawn towards you or pushed away (smooth).
	_handle_pivot.rotation.z = _lever * 0.55
	if _knife_t >= 0.0:
		put(_knife, MUG_FOOT + Vector2(-30 + _knife_t / 0.35 * 60.0, -6), 0.16)
	else:
		put(_knife, KNIFE_AT, 0.006)


# ── what can be used ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if taproom == null:
		return out
	var clean := int(taproom.mugs(building_key)["clean"])
	if not _mug and _slide < 0.0 and clean > 0:
		out.append({"id": "board", "rect": BOARD, "verb": "A clean mug under the tap (%d)" % clean})
	out.append({"id": "handle", "node": _handle, "verb": _handle_verb()})
	if _mug and _slide < 0.0 and _beer + _foam > 0.02:
		out.append({"id": "mug", "node": _mug_spr, "verb": _mug_verb()})
	if _mug and _foam > 0.04 and _slide < 0.0:
		out.append({"id": "knife", "node": _knife, "verb": "Cut the top off the head"})
	out.append_array(_bill.call("spots"))
	return out


## The tap's handle in the fist, the bare glove for the mugs, the money for the bill.
func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	if id == "handle":
		return "tap"
	if id.begins_with("bill:"):
		return "coin" if bool(_bill.get("taken")) else "open"
	return "open"


func _handle_verb() -> String:
	match taproom.tap_trouble(building_key):
		"dry":
			return "The tap: no beer in the cellar"
		"empty":
			return "The tap: the keg is spent"
		"off":
			return "The tap: the head is off the keg"
		"flat":
			return "The tap: the keg has gone flat"
	if _lever > 0.5:
		return "Drawing beer"
	if _lever < -0.5:
		return "Pushed: foam"
	return "Draw a beer: towards you for beer, away for foam"


func _mug_verb() -> String:
	var orders := orders_here("tap")
	if orders.is_empty():
		return "Nobody asked for this one"
	return "Over the bar to %s (%s)" % [ORDERS_first(str(orders[0]["name"])), PUB.label(str(orders[0]["drink"]))]


func _press(id: String) -> void:
	if bool(_bill.call("press", id)):
		return
	match id:
		"board":
			_put_mug()
		"handle":
			# The handle always goes with the hand (no mug under it: nothing comes out). It
			# is pulled by how far the pointer moves on the screen: the handle stands high on
			# the tower, where the pointer's ray may not even meet the bar's top.
			_grab_y = _vp_mouse.y
			_put_mug()
		"mug":
			_serve()
		"knife":
			_foam = maxf(0.0, _foam - 0.12)
			_knife_t = 0.0
			sfx("scrape", -14.0, 1.4)


func _drag(_at: Vector2) -> void:
	if _held != "handle" or _grab_y < 0.0 or _vp_mouse.y < 0.0:
		return
	# Towards you (down the screen) draws the beer, away pushes the foam: a tenth of the
	# picture's height is the whole way.
	var was := _lever
	var full := 36.0
	if camera != null and is_instance_valid(camera):
		full = maxf(12.0, float(camera.get_viewport().size.y) * 0.1)
	_lever = clampf((_vp_mouse.y - _grab_y) / full, -1.0, 1.0)
	if absf(_lever) > 0.5 and absf(was) <= 0.5:
		_start(_lever > 0.0)
	elif absf(_lever) <= 0.5 and absf(was) > 0.5:
		sfx("tap_close", -8.0)


func _release(id: String) -> void:
	if id == "handle":
		if absf(_lever) > 0.5:
			sfx("tap_close", -6.0)
		_grab_y = -1.0


func _put_mug() -> bool:
	if _mug:
		return true
	if int(taproom.mugs(building_key)["clean"]) <= 0:
		var dirty := int(taproom.mugs(building_key)["dirty"])
		say("", "No clean mugs on the board. %d in the washer." % dirty if dirty > 0 else "No mugs at all.")
		sfx("tick", -14.0, 0.7)
		return false
	_mug = true
	_beer = 0.0
	_foam = 0.0
	_spilled = 0.0
	sfx("glass_down", -10.0, randf_range(0.95, 1.05))
	hop(_mug_spr)
	return true


func _start(pull: bool) -> void:
	var trouble: String = taproom.tap_trouble(building_key)
	if trouble != "" and trouble != "flat":
		sfx("tap_open", -6.0, 0.8)
		_cough = 0.5
		say("", {"dry": "The tap coughs air.", "empty": "The tap spits foam and air.", "off": "Nothing comes."}.get(trouble, ""))
		return
	sfx("tap_open", -6.0)
	_pour_loop.pitch_scale = 1.0 if pull else 1.3
	if not _pour_loop.playing:
		_pour_loop.play()


# ── time ─────────────────────────────────────────────────────────────────────

func _tick(delta: float) -> void:
	if _held != "handle":
		# Let go: it springs back up, in steps.
		_lever = move_toward(_lever, 0.0, delta * 8.0)
	var pouring := absf(_lever) > 0.5 and _mug and _slide < 0.0
	var trouble: String = taproom.tap_trouble(building_key)
	if trouble != "" and trouble != "flat":
		pouring = false
	_pour_loop.volume_db = move_toward(_pour_loop.volume_db, (-7.0 if _lever > 0.0 else -13.0) if pouring else -60.0, delta * 120.0)
	if _pour_loop.volume_db <= -59.0 and _pour_loop.playing:
		_pour_loop.stop()
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
		_pour(delta, pouring, trouble == "flat")


func _pour(delta: float, pouring: bool, flat: bool) -> void:
	var gas: Dictionary = PUB.gas_pour(float(taproom.keg(building_key)["gas"]))
	# The second tap (gear): the line is wider, the beer comes faster.
	if BUSINESS.has_gear(building_key, "tap2"):
		delta *= 1.6
	if pouring and _lever > 0.0:
		_beer += PUB.POUR_RATE * float(gas["rate"]) * delta
		# A flat keg gives no head at all.
		_foam += PUB.PULL_FOAM * float(gas["foam"]) * delta * (0.1 if flat else 1.0)
	elif pouring:
		_beer += PUB.PUSH_BEER * delta
		_foam += PUB.PUSH_FOAM * delta * (0.25 if flat else 1.0)
	if _foam > 0.0:
		var s := minf(_foam, PUB.SETTLE * delta * (3.0 if flat else 1.0))
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


## Over the bar with it: the mat it goes to, judged; sent back if it is not what they
## asked for.
func _serve() -> void:
	var orders := orders_here("tap")
	if orders.is_empty():
		say("", "Nobody asked for that one. You drink it yourself.")
		_slide = 0.0
		return
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
		return
	if taproom.tap_trouble(building_key) == "flat":
		best_v["accuracy"] = float(best_v["accuracy"]) * 0.6
	var verdict: Dictionary = taproom.serve(building_key, best, best_v)
	if not bool(verdict.get("ok", false)):
		say("", "The keg ran dry under the glass.")
		return
	picked = ""
	_slide = 0.0
	sfx("glass_down", -8.0)
	sfx("pencil", -12.0)
	# A mark on their mat (the pencil in your hand a moment), the money when they go.
	var col := RETRO_UI.C_AMBER_LIGHT if int(verdict["tip"]) > 0 else RETRO_UI.C_BONE
	pop("|", MUG_FOOT + Vector2(0, -120), col, true)
	if _hands_ui != null and is_instance_valid(_hands_ui):
		_hands_ui.call("flash", "pencil", 4)
	score_card(verdict, PUB.label(str(best["drink"])), _with_patience(best))
	if int(verdict["stars"]) >= 3:
		say(who, ["Now that's a beer.", "Like my grandad poured.", "Na zdravi!", "Ahh. Perfect.", "You've done this before."][_rng.randi() % 5])
	elif float(verdict["accuracy"]) >= 0.6:
		say(who, ["It'll do.", "Cheers.", "Bit off. Fine."][_rng.randi() % 3] + ("" if _spilled < 0.05 else " And mind the bar."))
	else:
		say(who, "Hm. Thanks.")


func bar_buttons() -> Array:
	if not (_bill.get("given") as Array).is_empty():
		return [{"id": "clear", "label": "CLEAR"}]
	return []


func bar_button(id: String) -> void:
	if id == "clear":
		_bill.call("clear")
		sfx("res://assets/sfx/jednota/coin.mp3", -12.0, 0.8)


func _opened() -> void:
	_lever = 0.0


func _closing() -> void:
	_lever = 0.0
	_grab_y = -1.0
	_pour_loop.stop()
	# A mug on its way over the bar is gone when you turn away (time stops here).
	if _slide >= 0.0:
		_slide = -1.0
		_mug = false
		_beer = 0.0
		_foam = 0.0
		_spilled = 0.0


# ── debug (tools/pub_check.gd, tools/pub_shots.gd) ───────────────────────────

## A pour as a player would: `beer` and `foam` shares, then served.
func debug_pour(beer: float, foam: float) -> void:
	_put_mug()
	_beer = beer
	_foam = foam


## The pour the first beer ordered wants (its beer to the line, the head to the rim).
func debug_pour_right() -> void:
	var orders := orders_here("tap")
	var want := 0.78 if orders.is_empty() else float(PUB.DRINKS[str(orders[0]["drink"])]["beer"])
	debug_pour(want, 0.96 - want)


func debug_click(id: String) -> void:
	_press(id)
