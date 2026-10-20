extends "res://scripts/pub/pub_station.gd"

## Darts (the brief of 20. 10.: the pub's fun), at the board on the left wall, thrown from
## the line on the floor (pub_layout SURFACES "darts": the wall round the board).
##   the board   press on it to raise a dart and aim (the hand sways the longer you hold:
##               the dart goes where the tip is when you let go); three darts a turn
## Your three against the last guest's turn (taproom.gd "fun": the guests throw too, their
## darts stay in the board till the next turn); a click on the board after your third
## takes your darts out. Win or lose, the guests like a game (their mood); nobody bets.

const FUN := preload("res://core/systems/pub_fun.gd")
## The board on the wall (design px over SURFACES["darts"]): its middle and the double
## ring's outer edge (the board's picture, camp/dartboard_clean.png, laid on the wall in
## the room: its double ring is about three quarters of its half, the numbers outside it).
const BOARD_AT := Vector2(320, 180)
const DOUBLE_R := 139.0
const BOARD := Rect2(140, 0, 360, 360)
const DART_M := 0.09
## How far the hand wanders (design px) as you hold: at once, and at most.
const SWAY_MIN := 5.0
const SWAY_MAX := 46.0

var _mine: Array = []          # where your darts went (shares of DOUBLE_R from the middle)
var _scores: Array = []
var _stuck: Array = []         # Sprite3D, yours then the guest's
var _fly: Sprite3D
var _fly_t := -1.0
var _fly_to := Vector2.ZERO
var _aim_t := 0.0
var _rng := RandomNumberGenerator.new()


func has_rail() -> bool:
	return false


func _build() -> void:
	super._build()
	_rng.randomize()
	for i in FUN.DARTS * 2:
		var s := sprite(PUB_TEX + "dart_stuck.png", DART_M, false)
		s.visible = false
		_stuck.append(s)
	_fly = sprite(PUB_TEX + "dart_fly.png", 0.05, false)
	_fly.visible = false


## The point of the board (design px) for a dart at `share` of the double ring.
func _px_of(share: Vector2) -> Vector2:
	return BOARD_AT + share * DOUBLE_R


func _show() -> void:
	if taproom == null or building_key == "":
		return
	var f: Dictionary = taproom.fun(building_key)
	var theirs: Array = (f.get("darts", {}) as Dictionary).get("at", []) if _mine.is_empty() else []
	var all: Array = _mine + theirs
	for i in _stuck.size():
		var s: Sprite3D = _stuck[i]
		s.visible = i < all.size()
		if s.visible:
			var a = all[i]
			var at: Vector2 = a if a is Vector2 else Vector2(float(a[0]), float(a[1]))
			put(s, _px_of(at), 0.03 + 0.002 * i)
	_fly.visible = _fly_t >= 0.0
	if _fly.visible:
		# Away from you into the board, in steps: smaller as it goes.
		var k := floorf(clampf(_fly_t / 0.18, 0.0, 1.0) * 3.0) / 3.0
		_fly.scale = Vector3.ONE * (1.6 - k * 0.8)
		put(_fly, _px_of(_fly_to) + Vector2(0, 40.0 * (1.0 - k)), 0.25 * (1.0 - k) + 0.04)


func _tick(delta: float) -> void:
	if _held == "board":
		_aim_t += delta
	if _fly_t >= 0.0:
		_fly_t += delta
		if _fly_t >= 0.18:
			_fly_t = -1.0
			_land()


## Where the tip is now: the pointer and the hand's sway.
func _aim() -> Vector2:
	var a := minf(SWAY_MAX, SWAY_MIN + _aim_t * 18.0)
	var sway := Vector2(sin(_t * 2.3) * a, cos(_t * 1.7 + 0.6) * a * 0.8)
	var at := (_mouse_free if _mouse_free.x >= 0.0 else BOARD_AT) + sway
	return (at - BOARD_AT) / DOUBLE_R


func _spots() -> Array:
	if _mine.size() >= FUN.DARTS:
		return [{"id": "board", "rect": BOARD, "verb": "Pull your darts out of the board"}]
	return [{"id": "board", "rect": BOARD, "verb": "Hold to aim, let go to throw (dart %d of %d)" % [_mine.size() + 1, FUN.DARTS]}]


func hand_tool() -> String:
	return "dart"


func _press(id: String) -> void:
	if id != "board":
		return
	if _mine.size() >= FUN.DARTS:
		_mine = []
		_scores = []
		sfx("tick", -12.0, 0.8)
		return
	_aim_t = 0.0


func _release(id: String) -> void:
	if id != "board" or _mine.size() >= FUN.DARTS or _fly_t >= 0.0:
		return
	_fly_to = _aim()
	_fly_t = 0.0
	if _hands_ui != null and is_instance_valid(_hands_ui):
		_hands_ui.call("flash", "dart", 3)
	sfx("dart_throw", -8.0, _rng.randf_range(0.95, 1.08))


func _land() -> void:
	_mine.append(_fly_to)
	var pts := FUN.dart_score(_fly_to)
	_scores.append(pts)
	pop("%d" % pts if pts > 0 else "MISS", _px_of(_fly_to) + Vector2(0, -20), RETRO_UI.C_AMBER_LIGHT if pts >= 40 else RETRO_UI.C_BONE)
	if _mine.size() >= FUN.DARTS:
		var total := 0
		for s in _scores:
			total += int(s)
		var v: Dictionary = taproom.darts_done(building_key, _mine, total)
		var who := str(v.get("name", ""))
		if who == "":
			say("", "%d. Nobody to beat but the board." % total)
		elif int(v.get("theirs", 0)) > total:
			say(who, "%d to my %d. Again?" % [total, int(v["theirs"])])
		elif int(v.get("theirs", 0)) < total:
			say(who, "%d! You've done this before." % total)
		else:
			say(who, "%d each. A draw." % total)


## Your turn and the guest's, for the frame's bar.
func bar_text() -> String:
	var total := 0
	for s in _scores:
		total += int(s)
	var f: Dictionary = taproom.fun(building_key) if taproom != null else {}
	var d: Dictionary = f.get("guest", {})
	var them := ""
	if not d.is_empty():
		them = "   %s %d" % [ORDERS_first(str(d.get("name", ""))).to_upper(), int(d.get("total", 0))]
	return "YOU %d%s" % [total, them]


func _closing() -> void:
	_fly_t = -1.0


# ── debug (tools/pub_check.gd, tools/pub_shots.gd) ───────────────────────────

func debug_click(id: String) -> void:
	_press(id)
	_release(id)


## A dart thrown at `share` of the double ring from the middle.
func debug_throw(share: Vector2) -> void:
	_fly_to = share
	_land()
