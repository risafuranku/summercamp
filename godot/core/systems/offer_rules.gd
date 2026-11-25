extends RefCounted

## A sandbox camp's offers and events, one a week (Richard 25. 11., docs/DESIGN.md "Round 4":
## „Jednou týdně“): which day of each week something comes and what. A tour (a coach party at half
## again the price, an offer in CampMail), the district's inspection (written the day before), a
## sponsor (money for a billboard placed in Builder 98). Drawn from the camp's seed and the week:
## the same on a load and on every co-op machine. Pure; scripts/camp/week_offers.gd sends them.

## What can come, taking turns week by week (the ones not made yet are left out).
const KINDS := ["tour"]
## On which days of a week (1-7) one may come: not the first nor the last.
const FIRST_DAY := 2
const LAST_DAY := 6
## Office hours: it comes from HOUR on its day; one that cannot come yet (a tour with too few
## free beds) is tried every hour till LAST_HOUR, day after day, till the week is out.
const HOUR := 10
const LAST_HOUR := 17
## A tour: how many (never more than the free beds), how many nights, how much dearer a head.
const TOUR_PARTY := Vector2i(8, 15)
const TOUR_NIGHTS := Vector2i(2, 4)
const TOUR_PAY := 1.5


## The week a camp day is in (days 1-7 the first, 0).
static func week_of(day: int) -> int:
	return (maxi(1, day) - 1) / 7


## The camp day week `week`'s offer comes on.
static func day_of(week: int, seed: int) -> int:
	var h := absi(hash([seed, week, "offer_day"]))
	return week * 7 + FIRST_DAY + h % (LAST_DAY - FIRST_DAY + 1)


## What comes in week `week`: the kinds in turn, from a place the seed picks.
static func kind_of(week: int, seed: int) -> String:
	if KINDS.is_empty():
		return ""
	return str(KINDS[(week + absi(hash([seed, "offer_kind"]))) % KINDS.size()])


## What is due at `day` `hour` ("" nothing): this week's, once its day and hour have come,
## in office hours, while the week has not had it (`done`: week -> kind, as actions keep it).
static func due(day: int, hour: int, seed: int, done: Dictionary) -> String:
	var week := week_of(day)
	if done.has(str(week)) or hour < HOUR or hour > LAST_HOUR or day < day_of(week, seed):
		return ""
	return kind_of(week, seed)


## A tour's size for `free` beds: TOUR_PARTY at most what is free; 0 when too few are.
static func tour_size(free: int, roll: float) -> int:
	if free < TOUR_PARTY.x:
		return 0
	var most := mini(TOUR_PARTY.y, free)
	return TOUR_PARTY.x + int(floor(clampf(roll, 0.0, 0.999) * float(most - TOUR_PARTY.x + 1)))
