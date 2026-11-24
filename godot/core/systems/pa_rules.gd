extends RefCounted

## The camp's PA (Richard 24. 11., docs/audio.md "Rozhodnutí 24. 11.: amplióny s rádiem"): the
## poles built in Builder ("pa_pole") play what the reception's radio plays. One place for
## their numbers: how far a pole carries, what it does to the guests awake near it, and to the
## light sleepers after ten. Pure: guest_life reads it, Builder's map draws the reach,
## scripts/audio/pa_horns.gd plays it.

## How far a pole carries, in metres ("dosah asi 35 m").
const RANGE_M := 35.0
## A guest awake within reach while the radio plays gets this much fun a minute (the fun
## drains at about 0.12 a minute: most of it is made up)...
const FUN_PER_MIN := 0.08
## ...but never past this: the radio in the background is not an evening by the fire
## (a bonfire's visit gives 45 and can take it to the top).
const FUN_CAP := 60.0
## From ten in the evening to six in the morning a pole playing by a light sleeper's lodging
## keeps them up: this much of a drunk party next door (guest_life._noise_for).
const NOISE := 0.7
const QUIET_FROM_H := 22.0
const QUIET_TO_H := 6.0
## The building's id.
const TYPE := "pa_pole"
## A place's news out of the horns (docs/pc.md, 24. 11.: "jen znělka"): for this long after it
## a guest in reach who plans what to do next goes to the place named, once, this often.
const PULL_MINUTES := 90
const PULL_CHANCE := 0.35


## The reach in tiles of `tile_size` metres.
static func range_tiles(tile_size: float) -> float:
	return RANGE_M / maxf(0.25, tile_size)


## Whether `hour` (0-24) is in the night's quiet.
static func quiet_hours(hour: float) -> bool:
	return hour >= QUIET_FROM_H or hour < QUIET_TO_H


## Whether `tile` is within reach of any of `poles` (tiles).
static func near(poles: Array, tile: Vector2i, tile_size: float) -> bool:
	var r := range_tiles(tile_size)
	for c in poles:
		if Vector2(Vector2i(c) - tile).length() <= r:
			return true
	return false


## A guest's fun after `minutes` within reach of a pole playing: up by FUN_PER_MIN a minute,
## never past FUN_CAP, never down.
static func fun_after(fun: float, minutes: float) -> float:
	return maxf(fun, minf(FUN_CAP, fun + FUN_PER_MIN * minutes))
