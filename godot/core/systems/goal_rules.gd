extends RefCounted

## A sandbox camp's goals and score (Richard 25. 11., docs/DESIGN.md "Decisions 25. 11.":
## „Vybereš si je při založení“: tick one to three goals from a list when making the camp,
## CampStat shows them with their progress, a goal met has a short celebration, the score counts
## all along). The camp's numbers come from scripts/camp/goal_watch.gd (`numbers`: peak guests at
## once, the till, nights in a row without a lost guest, lodgings, places, the last reviews'
## stars); this says how far each goal is and what the score is. Pure.

## [id, the words, the number it reads, how much of it]. The till's in the game's dollars
## (LANG.money writes them as crowns).
const GOALS := [
	["guests", "Fifty guests at once", "peak", 50],
	["money", "$10,000 in the till", "money", 10000],
	["safe", "Fourteen nights, nobody lost", "safe", 14],
	["lodgings", "Twenty lodgings", "lodgings", 20],
	["places", "Four businesses", "places", 4],
	["stars", "Four stars from guests", "stars", 4.0],
]
const MAX_CHOSEN := 3
## A met goal's worth in the score; the camp's numbers' worth.
const SCORE_GOAL := 1000
const SCORE_PER := {"peak": 20, "safe_best": 40, "lodgings": 15, "places": 60, "stars": 100, "days": 5}


static func goal(id: String) -> Array:
	for g in GOALS:
		if str(g[0]) == id:
			return g
	return []


## How far goal `id` is, 0..1, by the camp's `numbers`.
static func progress(id: String, numbers: Dictionary) -> float:
	var g := goal(id)
	if g.is_empty():
		return 0.0
	return clampf(float(numbers.get(str(g[2]), 0.0)) / maxf(0.001, float(g[3])), 0.0, 1.0)


static func met(id: String, numbers: Dictionary) -> bool:
	return progress(id, numbers) >= 1.0


## The camp's score: what it has got to (its best, not what it has now) and the goals met.
static func score(numbers: Dictionary, goals_met: int) -> int:
	var s := goals_met * SCORE_GOAL
	for k in SCORE_PER:
		s += int(round(float(numbers.get(k, 0.0)) * float(SCORE_PER[k])))
	return s


## The goals a camp is made with: the ones chosen that exist, at most MAX_CHOSEN.
static func chosen(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if not goal(str(id)).is_empty() and not out.has(str(id)) and out.size() < MAX_CHOSEN:
			out.append(str(id))
	return out
