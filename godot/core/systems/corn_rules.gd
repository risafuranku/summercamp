extends RefCounted

## The corn stand's numbers (DESIGN.md §7b "The corn stand"; the state while the game
## runs is scripts/corn/cornstand.gd, the stations scripts/corn/*_station.gd). Pure data
## and arithmetic, the same on every machine.
##
## A cob goes: out of the crate in its husk, the leaves pulled off one by one and the silk
## picked (the husking), into the bowl; from the bowl into the pot of boiling water; done
## when it is a bright yellow (DONE_AT seconds), grey and soft when left too long (from
## OVER_AT); out onto the board, brushed with butter all along, salted to the guest's
## wish, a napkin round it, over the counter.

## Seconds in the pot: from raw to done, done to going soft, and how long it takes to go
## quite soft after that.
const DONE_AT := 9.0
const OVER_AT := 21.0
const MUSH_SPAN := 15.0
## Places in the pot; with the bigger pot (gear).
const POT_PLACES := 3
const POT_PLACES_BIG := 6
## Husk leaves on a cob, and with the husking table (gear); the silk to pick.
const LEAVES := 4
const LEAVES_TABLE := 2
const SILK := 3
## Brush strokes' worth of butter along a cob: shares of it buttered (the butter warmer
## does it in one stroke).
const BUTTER_SLOTS := 20
## A cob's price (dollars), as the books have it (business_rules KINDS corn).
const PRICE := 2
## Game minutes (1.5 a second): an order is green while younger than PATIENCE_OK, amber to
## PATIENCE_LATE, red to PATIENCE_GONE, when they give up and go.
const PATIENCE_OK := 20
const PATIENCE_LATE := 40
const PATIENCE_GONE := 60
## The order goes up this long after they come to the counter.
const ORDER_DELAY := 2


## How done a cob is after `t` seconds in the pot: 0 raw .. 1 done, over 1 going soft
## (2 quite soft).
static func cook_of(t: float) -> float:
	return clampf(t / DONE_AT, 0.0, 1.0) + clampf((t - OVER_AT) / MUSH_SPAN, 0.0, 1.0)


## The stage of a cob in the pot: 0 pale, 1 done, 2 soft.
static func stage(t: float) -> int:
	var c := cook_of(t)
	if c < 1.0:
		return 0
	return 1 if c < 1.25 else 2


## The cooking's quality for the score (0..1): best done and not a second softer.
static func cook_quality(cook: float) -> float:
	if cook < 0.75:
		return 0.2
	if cook < 1.0:
		return 0.2 + (cook - 0.75) / 0.25 * 0.6
	if cook <= 1.05:
		return 1.0
	return clampf(1.0 - (cook - 1.05) * 1.6, 0.1, 1.0)


## How much salt a guest wants on their cob (0 none .. 3 shakes): the same on every machine.
static func salt_wish(visit: String, member: int) -> int:
	var h := absi(hash("%s#%d:salt" % [visit, member]))
	return [0, 1, 1, 2, 3][h % 5]


## The orders of a visit to the stand: one cob each person, all at once.
static func tickets_for(visit: String, figures: int, arrive: int, served: Dictionary, now: int) -> Array:
	var out: Array = []
	for m in maxi(1, figures):
		var tid := "%s#%d" % [visit, m]
		if served.has(tid):
			continue
		var since := arrive + ORDER_DELAY + m
		if now < since or now - since >= PATIENCE_GONE:
			continue
		out.append({"id": tid, "member": m, "salt": salt_wish(visit, m), "price": PRICE, "since": since, "age": now - since})
	return out


static func patience_band(age: int) -> int:
	if age < PATIENCE_OK:
		return 0
	return 1 if age < PATIENCE_LATE else 2


## The wait's share of the score (1 at once .. 0 at the last moment).
static func speed_of(age: int) -> float:
	if age < PATIENCE_OK * 0.6:
		return 1.0
	if age < PATIENCE_OK:
		return 0.75
	if age < PATIENCE_LATE:
		return 0.45
	return 0.15


## A cob against the order: {ok, build (0..1: the butter and the salt), cook (0..1),
## speed, notes: [what the guest says]}. ok false: they hand it back (a hard one, a mushy
## one, no butter at all, the salt far off).
static func judge(cook: float, butter: float, salt: int, wish: int, age: int) -> Dictionary:
	var notes: Array = []
	var build := 1.0
	if butter < 0.5:
		build -= 0.45
		notes.append("Where's the butter?")
	elif butter < 0.85:
		build -= 0.15
	var dsalt := absi(salt - wish)
	if dsalt > 0:
		build -= 0.2 * float(dsalt)
		notes.append("Too salty." if salt > wish else "Bit bland.")
	build = clampf(build, 0.0, 1.0)
	var cq := cook_quality(cook)
	if cook < 0.75:
		notes.push_front("It's still hard.")
	elif cook > 1.25:
		notes.push_front("It's gone soft and grey.")
	var ok := cq > 0.25 and build > 0.2
	return {"ok": ok, "build": build, "cook": cq, "speed": speed_of(age), "notes": notes}
