extends RefCounted

## One bottle of Lesnak 10, from the bag to empty (pockets.gd draws it and plays it).
## Pure like cigarette.gd: keys and the place in, states and `events` out.
##
##   B tapped with nothing:  a bottle out of the bag, shut, in your right hand (the torch
##                           goes in your pocket: one hand each).
##   B held, shut:           the cap levered off with the lighter; it strains, then pops.
##                           Shaken on the way (running, jumping, drunk) it foams over:
##                           hold B at once and you drink the foam, else it runs away.
##   B held, open:           drinking: the bottle up, a swallow every so often. Let go
##                           and it comes down. A whole bottle in one go: the big burp.
##   B tapped, empty:        tipped up for nothing.
##   X tapped:               set down at your feet (indoors on the floor), kept full or not.
##   X held:                 thrown (smashes on the hard ground, thuds in the grass).
## Every swallow is in `drunk_add` (one bottle = 1.0), for the owner's drunkenness.

enum {NONE, UP, SHUT, OPENING, OPEN, FOAM, DRINK, DOWN, THROW}

const UP_TIME := 0.45
## A half-litre goes down in about this many seconds of drinking.
const DRINK_SECONDS := 9.0
const GULP_EVERY := 0.62
const THROW_HOLD := 0.38
const FOAM_TIME := 2.6

var state := NONE
var opened := false
## 1 full, 0 empty.
var level := 1.0
## How shaken the shut bottle is (0..).
var shake := 0.0
var t := 0.0
var open_need := 1.0
var events: Array = []
var drunk_add := 0.0
var _gulp_t := 0.0
var _drink_from := 1.0
var _x_held := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func active() -> bool:
	return state != NONE


func start() -> bool:
	if state != NONE:
		return false
	_go(UP)
	opened = false
	level = 1.0
	shake = 0.0
	events.append(["up", 0])
	return true


## `env`: {speed m/s, jumped, drunk}; keys: b_held, b_pressed, x_held.
func tick(dt: float, keys: Dictionary, env: Dictionary) -> void:
	t += dt
	var b_held: bool = keys.get("b_held", false)
	var b_pressed: bool = keys.get("b_pressed", false)
	var x_held: bool = keys.get("x_held", false)
	var speed := float(env.get("speed", 0.0))
	if not opened:
		shake = maxf(0.0, shake - dt * 0.03)
		if speed > 4.5:
			shake += dt * 0.09
		if bool(env.get("jumped", false)):
			shake += 0.25
		shake += dt * float(env.get("drunk", 0.0)) * 0.01
	match state:
		UP:
			if t >= UP_TIME:
				_go(SHUT if not opened else OPEN)
		SHUT:
			if b_held and t > 0.15:
				_go(OPENING)
				open_need = _rng.randf_range(0.55, 1.35)
				events.append(["lever", 0])
		OPENING:
			if not b_held:
				_go(SHUT)
				events.append(["lever_stop", 0])
			elif t >= open_need:
				opened = true
				events.append(["pop", shake])
				if shake > 0.45:
					_go(FOAM)
					events.append(["foam", shake])
				else:
					_go(OPEN)
		FOAM:
			if b_held and t > 0.1:
				# Your mouth on it: the foam goes down instead of away.
				_drink(dt)
			else:
				level = maxf(0.0, level - dt * 0.09)
			if t >= FOAM_TIME:
				shake = 0.0
				_go(DRINK if b_held else OPEN)
				if state == DRINK:
					_drink_from = level
		OPEN:
			if b_pressed and level <= 0.001:
				events.append(["empty", 0])
			elif b_held and t > 0.12 and level > 0.001:
				_go(DRINK)
				_drink_from = level
				_gulp_t = 0.25
				events.append(["raise", 0])
		DRINK:
			if not b_held or level <= 0.0:
				var whole := _drink_from >= 0.98 and level <= 0.0
				_go(OPEN)
				events.append(["lower", 1 if whole else 0])
			else:
				_drink(dt)
		THROW:
			if t >= 0.35:
				events.append(["thrown", level if opened else 2.0])
				_reset()
				return
	if state in [SHUT, OPEN]:
		if x_held:
			_x_held += dt
			if _x_held >= THROW_HOLD:
				_x_held = 0.0
				_go(THROW)
				events.append(["throw", 0])
		elif _x_held > 0.0:
			_x_held = 0.0
			events.append(["set_down", level if opened else 2.0])
			_reset()


func _drink(dt: float) -> void:
	var before := level
	level = maxf(0.0, level - dt / DRINK_SECONDS)
	drunk_add += before - level
	_gulp_t -= dt
	if _gulp_t <= 0.0:
		_gulp_t = GULP_EVERY * _rng.randf_range(0.85, 1.2)
		events.append(["gulp", level])


func _go(s: int) -> void:
	state = s
	t = 0.0


func _reset() -> void:
	state = NONE
	t = 0.0


## The hand's picture (assets/textury/hands/).
func frame() -> String:
	match state:
		UP, SHUT, THROW:
			return "hand2_beer_shut" if not opened else "hand2_beer_open"
		OPENING:
			return "hand2_beer_opening"
		FOAM:
			return "hand2_beer_drink" if t > 0.1 and level < 0.999 and _drinking_foam() else "hand2_beer_foam"
		DRINK:
			# On the way up, then the bottom of the bottle at your eye.
			return "hand2_beer_tilt" if t < 0.22 else "hand2_beer_drink"
	return "hand2_beer_open"


var _foam_drink := false


func _drinking_foam() -> bool:
	return _foam_drink


func set_keys_for_frame(b_held: bool) -> void:
	_foam_drink = b_held


## For the other machine: 0 none, 1 shut in hand, 2 opening, 3 open in hand, 4 drinking.
func coop_code() -> int:
	match state:
		NONE, THROW:
			return 0
		UP, SHUT:
			return 1 if not opened else 3
		OPENING:
			return 2
		DRINK, FOAM:
			return 4
	return 3
