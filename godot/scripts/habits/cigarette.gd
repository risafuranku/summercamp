extends RefCounted

## One cigarette, from the pack to the butt (pockets.gd draws it and plays its sounds).
## Pure: fed the keys and the place each frame, it moves through its states and leaves
## what happened in `events` for the owner to show, hear and send.
##
##   C tapped with nothing:  the pack comes up, one is tapped out and put in your mouth,
##                           and the lighter comes up to it.
##   C at the lighter:       each press is a flick of the wheel. It catches or it does
##                           not (wind and rain make it harder; never indoors); holding C
##                           keeps the gas open, and the flame held to the tip lights it
##                           while you draw. Let go and the flame is gone. Wind bends it,
##                           a gust blows it out.
##   C held, lit:            a drag. The hand comes up to your mouth, the ember flares,
##                           it burns fast. Let go and you breathe it out (the longer the
##                           drag, the more smoke). Too long and you cough.
##   X tapped:               the ash knocked off. Left on, it grows, and it falls by
##                           itself (sooner when you run).
##   X held:                 thrown away (outdoors a flick, the butt glowing where it
##                           lands; indoors stubbed out on the floor).
## Burned down to the filter it burns your fingers. Rain can put it out (C lights it again).

enum {NONE, PACK, LIPS, HOLD, DRAG, EXHALE, THROW}

const PACK_TIME := 0.95
## Holding the flame to the tip while drawing: this long and it is lit.
const LIGHT_TIME := 0.85
## A whole cigarette burns away in this many seconds left alone ...
const IDLE_BURN := 1.0 / 170.0
## ... and this much faster while you draw on it.
const DRAG_BURN := 0.05
const COUGH_DRAG := 2.8
const ASH_FALLS := 0.34
const THROW_HOLD := 0.38
const BURN_FINGERS := 0.05

var state := NONE
var lit := false
## 1 = a whole cigarette, 0 = only the filter.
var length := 1.0
## How much ash hangs on the end (0..).
var ash := 0.0
## The flame at the lighter: 0 none, 1 sparks only (this frame), 2 lit.
var flame := 0
var light_progress := 0.0
## How long the current drag is (and was, while it is breathed out).
var drag_t := 0.0
var exhale_t := 0.0
var t := 0.0                    # time in the state
var events: Array = []          # [name, value]
var _x_held := 0.0
## Debug (the screenshot driver): the next flicks always catch.
var debug_catch := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func active() -> bool:
	return state != NONE


## The pack comes up. False when there is one going already.
func start() -> bool:
	if state != NONE:
		return false
	_go(PACK)
	length = 1.0
	ash = 0.0
	lit = false
	events.append(["pack", 0])
	return true


## `env`: {indoors, wind 0..1, rain 0..1, speed m/s}; `c_held`, `c_pressed`,
## `x_pressed`, `x_held`.
func tick(dt: float, keys: Dictionary, env: Dictionary) -> void:
	t += dt
	var c_held: bool = keys.get("c_held", false)
	var c_pressed: bool = keys.get("c_pressed", false)
	var x_pressed: bool = keys.get("x_pressed", false)
	var x_held: bool = keys.get("x_held", false)
	var wind := 0.0 if bool(env.get("indoors", false)) else float(env.get("wind", 0.0))
	var rain := 0.0 if bool(env.get("indoors", false)) else float(env.get("rain", 0.0))
	if flame == 1:
		flame = 0
	match state:
		PACK:
			if t >= PACK_TIME:
				_go(LIPS)
				events.append(["lips", 0])
		LIPS:
			_tick_lighter(dt, c_held, c_pressed, wind, rain)
		HOLD:
			if c_held and t > 0.12:
				_go(DRAG)
				drag_t = 0.0
				events.append(["drag", 0])
		DRAG:
			drag_t += dt
			if not c_held or drag_t >= COUGH_DRAG:
				var cough := drag_t >= COUGH_DRAG
				_go(EXHALE)
				exhale_t = drag_t
				events.append(["exhale", drag_t])
				if cough:
					events.append(["cough", 0])
		EXHALE:
			if t >= 0.45:
				_go(HOLD)
		THROW:
			if t >= 0.35:
				events.append(["thrown", length if lit else -length])
				_reset()
				return
	if lit and state in [HOLD, DRAG, EXHALE]:
		var burn := (IDLE_BURN * (1.0 + wind * 0.8)) * dt
		if state == DRAG:
			burn += DRAG_BURN * dt
		length = maxf(0.0, length - burn)
		ash += burn * (1.0 if state != DRAG else 0.8)
		var speed := float(env.get("speed", 0.0))
		var falls := ASH_FALLS * (0.6 if speed > 4.0 else 1.0)
		if ash > falls or (ash > 0.08 and speed > 4.0 and _rng.randf() < dt * 0.35):
			events.append(["ash_fall", ash])
			ash = 0.0
		if rain > 0.0 and state == HOLD and _rng.randf() < dt * 0.025 * rain:
			lit = false
			events.append(["doused", 0])
		if length <= BURN_FINGERS and state in [HOLD, DRAG]:
			events.append(["burned", 0])
			_go(THROW)
			return
	if state in [HOLD, EXHALE]:
		if x_held:
			_x_held += dt
			if _x_held >= THROW_HOLD:
				_x_held = 0.0
				_go(THROW)
				events.append(["throw", 0])
				return
		elif _x_held > 0.0:
			# Let go before it was a throw: a tap of the ash.
			_x_held = 0.0
			if ash > 0.02:
				events.append(["ash_tap", ash])
				ash = 0.0
			else:
				events.append(["ash_none", 0])
		if not lit and c_pressed and state == HOLD:
			# Gone out: back to the mouth and the lighter.
			_go(LIPS)
			events.append(["relight", 0])
	elif not x_held:
		_x_held = 0.0
	if x_pressed:
		pass


## At the lighter: flicks, the flame, lighting it.
func _tick_lighter(dt: float, c_held: bool, c_pressed: bool, wind: float, rain: float) -> void:
	if t < 0.3:
		return
	if c_pressed:
		var catch_p := 0.62 - wind * 0.42 - rain * 0.18
		if debug_catch or _rng.randf() < catch_p:
			flame = 2
			events.append(["strike", 1])
		else:
			flame = 1
			events.append(["strike", 0])
	elif flame == 2 and not c_held:
		flame = 0
		events.append(["flame_off", 0])
	if flame == 2:
		# A gust takes it.
		if _rng.randf() < dt * wind * 0.55:
			flame = 0
			events.append(["blown_out", 0])
			return
		light_progress += dt / LIGHT_TIME * (1.0 - wind * 0.35)
		if light_progress >= 1.0:
			light_progress = 0.0
			lit = true
			flame = 0
			events.append(["lit", 0])
			_go(EXHALE)
			exhale_t = 0.6
	else:
		light_progress = maxf(0.0, light_progress - dt * 0.6)


func _go(s: int) -> void:
	state = s
	t = 0.0


func _reset() -> void:
	state = NONE
	lit = false
	flame = 0
	light_progress = 0.0
	ash = 0.0
	t = 0.0


## The stage picture for its length and ash (assets/textury/habits/cig_*.png).
func stage() -> String:
	if not lit and length > 0.97:
		return "cig_new"
	var s := "cig_full"
	if length < 0.12:
		s = "cig_end"
	elif length < 0.38:
		s = "cig_quarter"
	elif length < 0.62:
		s = "cig_half"
	elif length < 0.86:
		s = "cig_3q"
	return s + ("_ash" if ash > 0.1 and s != "cig_end" else "") + ("" if lit else "_out")


## For the other machine: 0 none, 1 in the mouth (unlit), 2 at the flame, 3 held lit,
## 4 drawing on it, 5 held out.
func coop_code() -> int:
	match state:
		NONE, THROW:
			return 0
		PACK, LIPS:
			return 2 if flame == 2 else 1
		DRAG:
			return 4
	return 3 if lit else 5
