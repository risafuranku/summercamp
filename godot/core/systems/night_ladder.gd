extends RefCounted

## How the nights follow on from one another (the user 7. 11.: "the first night with them the
## radio went straight to the hell waltz, a mad peak; we must start gentler", and "after a first
## night of total hell the next nights were dull, nothing much happened: the nights must follow
## on, the fear smoother, no such drops"). What comes is rolled from the guests in the camp, so
## a full camp had the worst on its first bad night and a thinner one nothing on the next. The
## roll still says what the camp brings; this says how much of it the night may have: worked up
## to night by night, what came last night first, and never back down to nothing while there
## is anybody in the camp to turn. `step` is the bad night's number: 1 the first.

## By step: kinds hunting at most, how hard they are at most, how many Silent Men at once, how
## bad the radio may get. Past the end, the camp's own numbers.
const STEPS := [
	{"kinds": 1, "difficulty": 1, "silent": 1, "dread": 0.42},
	{"kinds": 1, "difficulty": 2, "silent": 1, "dread": 0.58},
	{"kinds": 2, "difficulty": 2, "silent": 2, "dread": 0.7},
	{"kinds": 2, "difficulty": 3, "silent": 2, "dread": 0.78},
	{"kinds": 3, "difficulty": 4, "silent": 3, "dread": 0.9},
]
## From this bad night on the Antlered Man may come.
const ANTLERED_FROM := 4


static func _at(step: int) -> Dictionary:
	if step < 1:
		return {"kinds": 0, "difficulty": 1, "silent": 0, "dread": 0.15}
	return STEPS[step - 1] if step <= STEPS.size() else {"kinds": 99, "difficulty": 5, "silent": 3, "dread": 1.0}


static func kinds_cap(step: int) -> int:
	return int(_at(step)["kinds"])


static func difficulty_cap(step: int) -> int:
	return int(_at(step)["difficulty"])


static func silent_cap(step: int) -> int:
	return int(_at(step)["silent"])


static func dread_cap(step: int) -> float:
	return float(_at(step)["dread"])


## The night's roll (its entries: archetype, spawned, guest_count) as the night may have it.
## `last`: the archetypes that came last night, `known`: those with something to turn into.
## Returns the entries with `spawned` set: last night's first, then the most guests; at most
## kinds_cap; none spawned and somebody in the camp: last night's, or the most guests', comes.
static func shape(entries: Array, step: int, last: Array, known: Dictionary) -> Array:
	var out: Array = []
	var cap := kinds_cap(step)
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
	if kept == 0 and cap > 0 and not pool.is_empty():
		pool[0]["spawned"] = 1
	return out


## Last night's first, those the roll brought next, the most guests after.
static func _rank(e: Dictionary, last: Array) -> int:
	return (1000 if last.has(str(e.get("archetype", ""))) else 0) + (500 if int(e.get("spawned", 0)) > 0 else 0) + int(e.get("guest_count", 0))
