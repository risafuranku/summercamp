extends "res://scripts/pub/pub_station.gd"

## LUCKY 7 (the brief of 20. 10.: the pub's fun), the old one-armed bandit in the corner by
## the dartboard: worked standing at it (its face is the station's wall, pub_layout
## SURFACES "slot"; the cabinet is the room's own cutout, camp/pub_slot.png).
##   the lever   hold it and pull down: the three reels spin and stop one after another
##               (pub_fun.spin: the same game on every machine); a line pays out into the
##               tray with a bell
## It is the camp's machine: what a warden puts in comes back out of the same camp, so a
## warden plays for the fun of it, but three sevens and the whole pub cheers (their mood).
## The guests feed it too (taproom.gd, "fun"): the reels spin for them while you watch,
## and what they leave in it is the pub's takings.

const FUN := preload("res://core/systems/pub_fun.gd")
## On the machine's face (design px over pub_layout SURFACES["slot"], 0.96 m across): the
## three reels in the window of its picture (camp/pub_slot.png), the lever's foot at its
## right side.
const REEL_AT := [Vector2(197, 180), Vector2(305, 180), Vector2(417, 180)]
const REEL_M := 0.14
const LEVER_AT := Vector2(587, 186)
const LEVER_M := 0.24
const LEVER := Rect2(548, 10, 84, 236)
const TRAY_AT := Vector2(320, 330)
## Pulled this far down the screen (a share of the view's height) the lever goes.
const PULL := 0.12

var _reels: Array = []
var _lever: Sprite3D
var _pull := 0.0
var _grab_y := -1.0
## The spin shown: its reels, when it started (seconds here), who played.
var _spin: Dictionary = {}
var _spin_t := 99.0
var _stopped := 0
var _paid := false
var _rng := RandomNumberGenerator.new()


func has_rail() -> bool:
	return false


func _build() -> void:
	super._build()
	_rng.randomize()
	for i in 3:
		var s := sprite(PUB_TEX + "reel_seven.png", REEL_M, false)
		_reels.append(s)
		put(s, REEL_AT[i], 0.02)
	_lever = sprite(PUB_TEX + "slot_lever.png", LEVER_M, false)
	if _lever.texture != null:
		_lever.offset = Vector2(0, float(_lever.texture.get_height()) * 0.5)
	put(_lever, LEVER_AT, 0.03)


## The reel's picture `i` while it spins (a new symbol every tick) or where it stopped.
func _show() -> void:
	if taproom == null or building_key == "":
		return
	var f: Dictionary = taproom.fun(building_key)
	var s: Dictionary = f.get("slot", {})
	if str(s.get("id", "")) != str(_spin.get("id", "")):
		_spin = s
		_spin_t = 0.0 if not s.is_empty() else 99.0
		_stopped = 0
		_paid = false
	var reels: Array = FUN.spin(int(_spin.get("seed", 0))) if not _spin.is_empty() else ["seven", "seven", "seven"]
	for i in 3:
		var stop_at := FUN.SPIN_SEC + FUN.STOP_GAP * float(i)
		var sym: String = reels[i]
		if _spin_t < stop_at:
			sym = FUN.SYMBOLS[(int(_t * 12.0) + i * 2) % FUN.SYMBOLS.size()]
		retex(_reels[i], PUB_TEX + "reel_%s.png" % sym, REEL_M)
	# The lever down while pulled, in steps (its picture moved down its slot; never turned).
	var down := floorf(clampf(_pull, 0.0, 1.0) * 3.0) / 3.0
	put(_lever, LEVER_AT + Vector2(0, down * 90.0), 0.03)


func _tick(delta: float) -> void:
	_spin_tick(delta)
	if _held != "lever":
		_pull = move_toward(_pull, 0.0, delta * 6.0)


func _process(delta: float) -> void:
	super._process(delta)
	# The reels run whether anybody stands at it (the guests' games too).
	if not is_open():
		_spin_tick(delta)


func _spin_tick(delta: float) -> void:
	if _spin.is_empty():
		return
	var was := _spin_t
	_spin_t += delta
	for i in 3:
		var stop_at := FUN.SPIN_SEC + FUN.STOP_GAP * float(i)
		if was < stop_at and _spin_t >= stop_at:
			_stopped = i + 1
			if is_visible_in_tree():
				sfx("slot_stop", -10.0, 1.0 + 0.05 * i)
	if not _paid and _spin_t >= FUN.SPIN_SEC + FUN.STOP_GAP * 2.0 + 0.1:
		_paid = true
		var win := FUN.payout(FUN.spin(int(_spin.get("seed", 0))))
		if win > 0 and is_visible_in_tree():
			sfx("slot_win", -8.0)
			if is_open():
				pop("$%d" % win, TRAY_AT + Vector2(0, -30), RETRO_UI.C_AMBER_LIGHT, true)
		if is_open() and str(_spin.get("who", "")) == "you":
			taproom.slot_done(building_key, _spin)


func _spots() -> Array:
	var spinning := not _spin.is_empty() and _spin_t < FUN.SPIN_SEC + FUN.STOP_GAP * 2.0 + 0.2
	if spinning:
		return [{"id": "lever", "rect": LEVER, "verb": "The reels are going"}]
	return [{"id": "lever", "rect": LEVER, "verb": "Hold the lever and pull it down: a coin's game"}]


func hand_tool() -> String:
	return "open"


func _press(id: String) -> void:
	if id == "lever":
		_grab_y = _vp_mouse.y


func _drag(_at: Vector2) -> void:
	if _held != "lever" or _grab_y < 0.0 or _vp_mouse.y < 0.0:
		return
	var full := 36.0
	if camera != null and is_instance_valid(camera):
		full = maxf(12.0, float(camera.get_viewport().size.y) * PULL)
	var was := _pull
	_pull = clampf((_vp_mouse.y - _grab_y) / full, 0.0, 1.0)
	if _pull >= 1.0 and was < 1.0:
		_pulled()


func _release(_id: String) -> void:
	_grab_y = -1.0


## The lever all the way down: a game, if the reels are still.
func _pulled() -> void:
	if not _spin.is_empty() and _spin_t < FUN.SPIN_SEC + FUN.STOP_GAP * 2.0 + 0.2:
		return
	sfx("slot_lever", -8.0)
	sfx("slot_reels", -10.0)
	taproom.slot_play(building_key, _rng.randi(), "you")


func bar_text() -> String:
	return "LUCKY 7   777 PAYS %d" % int(FUN.PAY_THREE["seven"])


# ── debug (tools/pub_check.gd, tools/pub_shots.gd) ───────────────────────────

func debug_click(id: String) -> void:
	_press(id)
	_release(id)


func debug_pull() -> void:
	_pull = 1.0
	_pulled()


## The spin shown as if `seconds` had passed.
func debug_run(seconds: float) -> void:
	_spin_tick(seconds)
