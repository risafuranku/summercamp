extends RefCounted

## How the nights follow on (the user 7. 11.: "the first night with them the radio went straight
## to the hell waltz, a mad peak; we must start gentler", "after a first night of total hell the
## next nights were dull: the nights must follow on, the fear smoother, no such drops", and then
## "it must not be scripted: it must unfold by the state of the guests, and still the nights must
## follow on"). Nothing here counts nights.
##
## `swell` 0-1 is the fear the camp has worked up to, carried from night to night
## (GameState.night_swell). Every bad night it moves toward what the guests are like tonight
## (`reading`: how many, how unhappy, how many kinds of them, whom the night took), by RISE at
## most up and FALL at most down: a full camp cannot go from nothing to the worst at a stroke, a
## camp that has just emptied does not fall silent at one. The roll still says what the camp
## brings (guest_manager's forecast); the swell says how much of it the night may have. A small
## content camp settles low and stays gentle, a full miserable one climbs to the worst and stays
## there, one that is put right comes back down.

const RISE := 0.2
const FALL := 0.1
## From here on the hells' splinters (the radio's, the director's), the Antlered Man.
const HELLS_FROM := 0.45
const ANTLERED_FROM := 0.7
## From here on a second kind may come though the roll did not bring it.
const SECOND_KIND_FROM := 0.6
## All that is left of the radio with nothing worked up to: it only frets.
const DREAD_FLOOR := 0.15


## What the guests in the camp are like tonight, 0-1: `guests` checked in, `unhappy` of them,
## `kinds` of them with something to turn into, `lost` taken by the night since the last one.
static func reading(guests: int, unhappy: int, kinds: int, lost := 0) -> float:
	if guests <= 0:
		return 0.0
	var crowd := float(guests) / float(guests + 8)
	var misery := clampf(float(unhappy) / float(guests), 0.0, 1.0)
	var mix := clampf(float(kinds - 1) / 3.0, 0.0, 1.0)
	return clampf(0.72 * crowd + 0.38 * misery + 0.14 * mix + 0.1 * float(lost), 0.0, 1.0)


## Tonight's swell from last night's and the guests' reading.
static func next(swell: float, read: float) -> float:
	return clampf(swell + clampf(read - swell, -FALL, RISE), 0.0, 1.0)


## A camp saved before there was a swell: what has come so far.
static func from_nights_visited(visited: int) -> float:
	return clampf(0.1 * float(visited), 0.0, 0.6)


## Kinds hunting at most, how hard they are at most, how many Silent Men at once.
static func kinds_cap(swell: float) -> int:
	return 1 + int(clampf(swell, 0.0, 1.0) * 3.2)


static func difficulty_cap(swell: float) -> int:
	return 1 + int(clampf(swell, 0.0, 1.0) * 4.6)


## And at least, however few guests of the kind there are: the fear makes it worse.
static func difficulty_floor(swell: float) -> int:
	return 1 + int(clampf(swell, 0.0, 1.0) * 3.0)


static func silent_cap(swell: float) -> int:
	return 1 + int(clampf(swell, 0.0, 1.0) * 2.6)


## How bad the radio may get: under the terror songs at first, the hell songs near the top.
static func dread_cap(swell: float) -> float:
	return lerpf(DREAD_FLOOR, 1.0, pow(clampf(swell, 0.0, 1.0), 0.8))


## The NIGHT RISK lamps at most: they say what the night may have.
static func lamps_cap(swell: float) -> int:
	return 1 + int(clampf(swell, 0.0, 1.0) * 3.99)


## The night's roll (its entries: archetype, spawned, guest_count) as the night may have it.
## `last`: the archetypes that came last night, `known`: those with something to turn into,
## `dice` 0-1. Returns the entries with `spawned` set: last night's first, then the most guests;
## at most kinds_cap. The roll brought too little for the fear in the camp: what came last night
## carries on while its guests are here, a camp with the fear in it may still bring something
## (the more of it the likelier), and well up a second kind comes with the first.
static func shape(entries: Array, swell: float, last: Array, known: Dictionary, dice: float) -> Array:
	var out: Array = []
	var cap := kinds_cap(swell)
	var pool: Array = []
	for e_any in entries:
		if not (e_any is Dictionary):
			continue
		var e: Dictionary = (e_any as Dictionary).duplicate()
		out.append(e)
		if known.has(str(e.get("archetype", ""))) and int(e.get("guest_count", 0)) > 0:
			pool.append(e)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _rank(a, last) > _rank(b, last))
	var kept := 0
	for e in pool:
		if int(e.get("spawned", 0)) <= 0:
			continue
		if kept >= cap:
			e["spawned"] = 0
		else:
			kept += 1
	var want := 0
	if swell > 0.0 and (not last.is_empty() or dice < swell * 2.0):
		want = 2 if swell >= SECOND_KIND_FROM and dice < swell else 1
	for e in pool:
		if kept >= mini(want, cap):
			break
		if int(e.get("spawned", 0)) <= 0:
			e["spawned"] = 1
			kept += 1
	return out


## Last night's first, those the roll brought next, the most guests after.
static func _rank(e: Dictionary, last: Array) -> int:
	return (1000 if last.has(str(e.get("archetype", ""))) else 0) + (500 if int(e.get("spawned", 0)) > 0 else 0) + int(e.get("guest_count", 0))
