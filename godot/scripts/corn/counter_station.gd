extends "res://scripts/corn/corn_station.gd"

## The counter of the corn stand (DESIGN.md §7b "The corn stand"), worked on the stand's
## counter out in the camp: the pot of boiling water at the left, the board, the butter and
## its brush, the salt, the napkins, the cash box (the stand's Build picture,
## corn/st_counter.png). Things are sprites at the room's pixel.
##   the pot     a click puts a husked cob from the bowl in (the husking fills the bowl); it
##               boils pale, then bright yellow (done), then grey and soft
##   a cob       a click takes it out onto the board, however done it is
##   the board   hold the button on the cob and brush along it: the butter goes on where
##               the brush passes (the butter warmer, gear: all of it in one stroke)
##   the salt    a shake a click, as many as they asked (none for NO SALT)
##   napkins     a click wraps it
##   over the counter (the front of it): to the picked slip, else the oldest; they judge
##               it (corn_rules.judge): hard, soft, no butter, the salt off and they hand
##               it back
##   BIN         (the frame's button) the cob on the board in the bin
## The cash box opens the books (the stock, the order).

## On the counter (design px, stand_layout.SURFACES: 2 mm a px).
const POT := Rect2(25, 108, 140, 128)
## One behind the other in the water (the bigger pot: two rows).
const POT_SLOTS := [Vector2(95, 142), Vector2(95, 170), Vector2(95, 198), Vector2(72, 156), Vector2(118, 184), Vector2(72, 212)]
const BOARD := Rect2(205, 130, 170, 105)
const BOARD_AT := Vector2(290, 182)
const BUTTER := Rect2(388, 142, 60, 86)
const SALT := Rect2(456, 124, 34, 56)
const NAPKINS := Rect2(448, 178, 72, 72)
const CASH := Rect2(522, 118, 96, 124)
const HAND := Rect2(170, 0, 300, 96)
const COB_M := 0.2
const DRAG_FAR := 6.0

var _cobs: Dictionary = {}          # cob id -> Sprite3D in the pot
var _board: Dictionary = {}         # {cook, butter: PackedByteArray, salt, napkin}
var _board_spr: Sprite3D
var _butter_spr: Sprite3D
var _napkin_spr: Sprite3D
var _salt_spr: Array = []
var _brushing := false
var _last := Vector2(-1, -1)
var _rng := RandomNumberGenerator.new()
var _bob := 0.0
## Opens the books (set by the stand's view).
var open_books: Callable


func _build() -> void:
	super._build()
	_rng.randomize()
	_board_spr = lying("cob_boiled", COB_M)
	_board_spr.visible = false
	_butter_spr = lying("cob_buttered", COB_M)
	_butter_spr.region_enabled = true
	_butter_spr.visible = false
	_napkin_spr = lying("cob_napkin", COB_M + 0.02)
	_napkin_spr.visible = false
	var salt := "res://assets/textury/closeup/parts/salt.png"
	for i in 6:
		var s := sprite(salt, 0.014, false)
		s.visible = false
		_salt_spr.append(s)


# ── what the state looks like ────────────────────────────────────────────────

func _show() -> void:
	if stand == null or building_key == "":
		return
	var pot: Array = stand.pot(building_key)
	var live := {}
	for c in pot:
		var id := str(c["id"])
		live[id] = true
		var s: Sprite3D = _cobs.get(id, null)
		if s == null or not is_instance_valid(s):
			s = lying("cob_raw", COB_M, 0.08 * float(int(c["slot"]) % 3 - 1))
			_cobs[id] = s
		var stage := CORN.stage(float(c["t"]))
		cretex(s, ["cob_raw", "cob_boiled", "cob_mushy"][stage] if CORN.cook_of(float(c["t"])) >= 0.4 or stage > 0 else "cob_raw", COB_M)
		# Rolling a little in the boil, in steps.
		var slot := clampi(int(c["slot"]), 0, POT_SLOTS.size() - 1)
		# Bobbing in the boil, in steps.
		var bob := floorf(fmod(_t * 2.0 + float(slot) * 0.7, 2.0)) * 0.008
		put(s, POT_SLOTS[slot], 0.03 + bob)
	for id in _cobs.keys():
		if not live.has(id):
			if is_instance_valid(_cobs[id]):
				(_cobs[id] as Node).queue_free()
			_cobs.erase(id)
	var on := not _board.is_empty()
	_board_spr.visible = on and not bool(_board.get("napkin", false))
	_napkin_spr.visible = on and bool(_board.get("napkin", false))
	_butter_spr.visible = _board_spr.visible and _butter_share() > 0.0
	if on:
		var stage := 0 if float(_board["cook"]) < 1.0 else (1 if float(_board["cook"]) < 1.25 else 2)
		cretex(_board_spr, ["cob_raw", "cob_boiled", "cob_mushy"][stage] if float(_board["cook"]) >= 0.4 else "cob_raw", COB_M)
		put(_board_spr, BOARD_AT, 0.035)
		put(_napkin_spr, BOARD_AT, 0.038)
		# The butter shines over the stretch the brush has passed (the cob's length is the
		# picture's height: it lies across).
		var tex := _butter_spr.texture
		if tex != null and _butter_spr.visible:
			var span := _butter_span()
			var H := float(tex.get_height())
			var y0 := floorf(span.x * H)
			var y1 := ceilf(span.y * H)
			_butter_spr.region_rect = Rect2(0, y0, tex.get_width(), maxf(1.0, y1 - y0))
			# The region's middle over its place along the cob.
			_butter_spr.offset = Vector2(0, -((y0 + y1) * 0.5 - H * 0.5))
			put(_butter_spr, BOARD_AT, 0.035)
			_butter_spr.position.z += 0.003
		var shakes := mini(int(_board.get("salt", 0)) * 2, _salt_spr.size())
		for i in _salt_spr.size():
			var sp: Sprite3D = _salt_spr[i]
			sp.visible = i < shakes and not bool(_board.get("napkin", false))
			if sp.visible:
				put(sp, BOARD_AT + Vector2(-34 + fmod(float(i) * 23.7, 68.0), 0), 0.042 + fmod(float(i) * 0.007, 0.02))
				sp.position.z += 0.006
	else:
		for sp in _salt_spr:
			(sp as Sprite3D).visible = false


func _butter_share() -> float:
	if _board.is_empty():
		return 0.0
	var mask: PackedByteArray = _board["butter"]
	var n := 0
	for v in mask:
		n += v
	return float(n) / float(mask.size())


## The buttered stretch as shares of the cob's length (from its first buttered slot to
## its last).
func _butter_span() -> Vector2:
	var mask: PackedByteArray = _board["butter"]
	var a := -1
	var b := -1
	for i in mask.size():
		if mask[i] == 1:
			if a < 0:
				a = i
			b = i
	if a < 0:
		return Vector2.ZERO
	return Vector2(float(a) / mask.size(), float(b + 1) / mask.size())


## What is on the cob, for the big slip.
func cob_counts() -> Dictionary:
	if _board.is_empty():
		return {}
	return {"butter": _butter_share(), "salt": int(_board["salt"]), "napkin": bool(_board["napkin"])}


# ── what can be used ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if stand == null:
		return out
	for c in stand.pot(building_key):
		var s: Sprite3D = _cobs.get(str(c["id"]), null)
		if s != null:
			var stage := CORN.stage(float(c["t"]))
			var verb: String = ["Pale yet: take it out anyway", "Done: onto the board", "Gone soft: out with it"][stage]
			out.append({"id": "cob:" + str(c["id"]), "node": s, "verb": verb})
	if stand.free_slot(building_key) >= 0:
		var n := int(stand.bowl(building_key))
		out.append({"id": "pot", "rect": POT, "verb": "A husked cob into the pot (%d in the bowl)" % n if n > 0 else "The bowl is empty: husk some"})
	if not _board.is_empty():
		if not bool(_board["napkin"]):
			out.append({"id": "board", "node": _board_spr, "verb": "Hold and brush it with butter" if _butter_share() < 0.85 else "Buttered"})
			out.append({"id": "salt", "rect": SALT, "verb": "A shake of salt (%d on it)" % int(_board["salt"])})
			out.append({"id": "napkin", "rect": NAPKINS, "verb": "Wrap it in a napkin"})
		var t := current_ticket()
		if not t.is_empty():
			out.append({"id": "hand", "rect": HAND, "verb": "Over the counter to %s" % first_name(str(t["name"]))})
	out.append({"id": "cash", "rect": CASH, "verb": "The books"})
	return out


func _press(id: String) -> void:
	if id.begins_with("cob:"):
		_take_out(id.substr(4))
		return
	match id:
		"pot":
			_put_in()
		"board":
			_brushing = true
			_last = _mouse_free
			if BUSINESS.has_gear(building_key, "butter"):
				_butter_all()
		"salt":
			_board["salt"] = int(_board["salt"]) + 1
			sfx("salt_shake" if ResourceLoader.exists(sfx_dir() + "salt_shake.mp3") else "tick", -10.0, _rng.randf_range(1.2, 1.5))
		"napkin":
			_board["napkin"] = true
			sfx("plate_down", -14.0, 1.3)
		"hand":
			_hand_over()
		"cash":
			if open_books.is_valid():
				open_books.call()


func _release(_id: String) -> void:
	_brushing = false


func _drag(at: Vector2) -> void:
	if not _brushing or _board.is_empty() or at.x < -500.0:
		return
	if BUSINESS.stock_of(building_key, "butter") == 0:
		say("", "No butter. Order it in the books.")
		_brushing = false
		return
	var d := (at - _last).length()
	_last = at
	if d <= 0.5:
		return
	# Along the cob (it lies across the board): where the brush is, over its length.
	var mask: PackedByteArray = _board["butter"]
	var half := metres_x(1.0)
	var len_px := COB_M / half
	var u := clampf((at.x - (BOARD_AT.x - len_px * 0.5)) / len_px, 0.0, 0.999)
	var k := int(u * mask.size())
	for j in range(maxi(0, k - 1), mini(mask.size(), k + 2)):
		mask[j] = 1
	if _rng.randf() < d / 60.0:
		sfx("scrub", -16.0, _rng.randf_range(1.2, 1.4))


func _butter_all() -> void:
	var mask: PackedByteArray = _board["butter"]
	for j in mask.size():
		mask[j] = 1
	sfx("scrub", -14.0, 1.3)


func _put_in() -> void:
	var slot: int = stand.free_slot(building_key)
	if slot < 0:
		say("", "The pot is full.")
		return
	if int(stand.bowl(building_key)) <= 0:
		say("", "The bowl is empty. Husk some.")
		sfx("tick", -14.0, 0.7)
		return
	stand.act(building_key, "in", [stand.new_id(), slot])
	sfx("ladle_plate", -8.0, 0.9)


func _take_out(id: String) -> void:
	if not _board.is_empty():
		say("", "There is one on the board already.")
		return
	for c in stand.pot(building_key):
		if str(c["id"]) == id:
			var mask := PackedByteArray()
			mask.resize(CORN.BUTTER_SLOTS)
			_board = {"cook": CORN.cook_of(float(c["t"])), "butter": mask, "salt": 0, "napkin": false}
			stand.act(building_key, "out", [id])
			sfx("plate_down", -8.0)
			return


func _hand_over() -> void:
	var t := current_ticket()
	if t.is_empty() or _board.is_empty():
		return
	var who := first_name(str(t["name"]))
	if not bool(_board["napkin"]):
		say(who, "In my hand? It's boiling. A napkin, please.")
		return
	var v: Dictionary = stand.serve(building_key, t, float(_board["cook"]), _butter_share(), int(_board["salt"]))
	if not bool(v.get("ok", false)):
		if str(v.get("why", "")) == "butter":
			say("", "No butter left. Order it in the books.")
			return
		say(who, " ".join(v.get("notes", [])) + " Do another one.")
		_board = {}
		sfx("plate_down", -12.0, 0.7)
		return
	picked = ""
	_board = {}
	sfx("till", -8.0)
	pop("+$%d" % int(v["amount"]), CASH.get_center() + Vector2(0, -40), RETRO_UI.C_AMBER_LIGHT if int(v["tip"]) > 0 else RETRO_UI.C_BONE, true)
	if int(v["stars"]) >= 3:
		say(who, ["Now that is a cob.", "Like at my gran's.", "Perfect. Keep the change."][_rng.randi() % 3])
	else:
		var notes: Array = v.get("notes", [])
		say(who, " ".join(notes) if not notes.is_empty() else "Cheers.")


func bar_buttons() -> Array:
	var out: Array = [{"id": "books", "label": "BOOKS"}]
	if not _board.is_empty():
		out.push_front({"id": "bin", "label": "BIN"})
	return out


func bar_button(id: String) -> void:
	match id:
		"bin":
			_board = {}
			sfx("scrape", -10.0)
		"books":
			if open_books.is_valid():
				open_books.call()


func _tick(delta: float) -> void:
	_bob += delta


func _closing() -> void:
	_brushing = false


# ── debug (tools/stand_check.gd, tools/stand_shots.gd) ───────────────────────

func debug_click(id: String) -> void:
	_press(id)


## The cob on the board dressed as the picked (or oldest) order wants.
func debug_dress_right() -> void:
	if _board.is_empty():
		return
	_butter_all()
	var t := current_ticket()
	_board["salt"] = int(t.get("salt", 0))
	_board["napkin"] = true


## The first cob in the pot onto the board.
func debug_take_first() -> void:
	var pot: Array = stand.pot(building_key)
	if not pot.is_empty():
		_take_out(str(pot[0]["id"]))


## A cob straight onto the board, `cook` done.
func debug_board(cook: float) -> void:
	var mask := PackedByteArray()
	mask.resize(CORN.BUTTER_SLOTS)
	_board = {"cook": cook, "butter": mask, "salt": 0, "napkin": false}
