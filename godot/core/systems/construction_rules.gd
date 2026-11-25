extends RefCounted

## Building takes time (Richard 24. 11., docs/pc.md "Rozhodnutí 24. 11.: šťáva u PC i mimo něj",
## kolo 3: „Pár hodin podle velikosti“: stan a lavička hned, chatka a podniky 2 až 4 herní
## hodiny; mezitím lešení, dělníci a bouchání, hosté dovnitř nemůžou). A building ordered in
## Builder 98 stands as a site ("site", its own type: no guest, room or place counts it) until
## the workers have put in its hours; then the building itself stands there. Pure: the
## authority asks it what an order takes, scripts/camp/construction_works.gd counts the hours.

## The building's id while it goes up.
const TYPE := "site"
## Hours of work a building takes (its size: a tent, a caravan, a bench or a lamp stands at
## once; what has walls takes the workers a while).
const HOURS := {
	"toilet_block": 1.0,
	"shower_block": 1.0,
	"cabin_1": 2.0,
	"staffroom": 2.0,
	"warehouse": 2.0,
	"corn_stand": 2.0,
	"pub": 3.0,
	"restaurant": 3.0,
	"vecerka": 4.0,
	"bowling": 4.0,
}
## The workers' day (game hours): at night the site stands still, nobody on it.
const WORK_FROM_H := 7.0
const WORK_TO_H := 19.0


## Hours of work `type` takes (0: it stands at once).
static func hours(type: String) -> float:
	return float(HOURS.get(type, 0.0))


static func works_at(hour: float) -> bool:
	return hour >= WORK_FROM_H and hour < WORK_TO_H


## The work done between two moments (absolute game hours, day * 24 + hour), counting only the
## workers' day.
static func work_between(from_abs: float, to_abs: float) -> float:
	if to_abs <= from_abs:
		return 0.0
	var done := 0.0
	var t := from_abs
	while t < to_abs:
		var day_start := floorf(t / 24.0) * 24.0
		var a := maxf(t, day_start + WORK_FROM_H)
		var b := minf(to_abs, day_start + WORK_TO_H)
		if b > a:
			done += b - a
		t = day_start + 24.0
	return done


## How far a site is, 0..1.
static func progress(site: Dictionary) -> float:
	var total := float(site.get("total", 0.0))
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - float(site.get("left", 0.0)) / total, 0.0, 1.0)


## A site's key in GameState.sites ("x:y", its origin).
static func key(origin: Vector2i) -> String:
	return "%d:%d" % [origin.x, origin.y]
