extends RefCounted

## What wakes you in a room of the motel (the user, 4. 11.: "work out the night in the motel, it
## should feel weird, like a clicking horror adventure"). Never a script: while you sleep
## the night is weighed at every step of the clock (town_trip._motel_night): how likely it
## is that something wakes you now, from how you are (the hidden sanity), what this night
## is (the guest out in the car park, the light in six, who else has a room), the weather,
## the hour and how often you have been woken already; and when something does, which,
## weighed the same way. The room then plays it (motel_view.woken) and you go and look, or
## lie down again.
##
##   knock     on your door, again and again; the peephole shows the gallery, now and
##             then somebody standing right outside it;
##   phone     the phone on the bedside cabinet rings; on the line something, never a voice;
##   tv        the set comes on by itself, snow, or the car park from the pole outside
##             (where there is no set whatever the room has instead: the valves in two,
##             the tape in nine, Mr Hora's screen in eleven);
##   bath      the light on in the bathroom under its door, the tap running;
##   car       headlights through the curtains, an engine idling in the car park, a door;
##   upstairs  somebody walks about over your bed, drags something, stops;
##   wall      through the wall: a neighbour's set and cough, or with nobody in there a
##             slow scratching along it;
##   radiator  the pipes knock, and knock back if you answer them.
## The bell at three is the village's (town_trip): some nights it wakes you too.

const KINDS := ["knock", "phone", "tv", "bath", "car", "upstairs", "wall", "radiator"]
const MAX_WAKES := 3


## Wakes an hour (a rate) now. `ctx`: {"hour", "sanity" 0..100, "watch" (the guest in the
## car park tonight, now), "six" (its light on now), "rain", "woken" (times tonight),
## "since" (hours since you lay down or were last woken)}.
static func hazard(ctx: Dictionary) -> float:
	var h := float(ctx.get("hour", 0.0))
	if not (h >= 23.25 or h < 5.25):
		return 0.0
	var woken := int(ctx.get("woken", 0))
	if woken >= MAX_WAKES or float(ctx.get("since", 0.0)) < 0.75:
		return 0.0
	var low := clampf((100.0 - float(ctx.get("sanity", 100.0))) / 100.0, 0.0, 1.0)
	var lam := 0.16 + 0.45 * low
	if bool(ctx.get("watch", false)):
		lam += 0.18
	if bool(ctx.get("six", false)):
		lam += 0.08
	if bool(ctx.get("rain", false)):
		lam += 0.04
	# The small hours, two till four, are the worst.
	if h >= 2.0 and h < 4.0:
		lam *= 1.5
	return lam * pow(0.55, float(woken))


## Which: weighed by the night, never the same twice in one. `ctx` as hazard's, with
## "taken" (the rooms let tonight), "sides" and "above" (the rooms next to yours and over
## it) and "had" (what woke you already).
static func pick(ctx: Dictionary, rng: RandomNumberGenerator) -> String:
	var h := float(ctx.get("hour", 0.0))
	var low := clampf((100.0 - float(ctx.get("sanity", 100.0))) / 100.0, 0.0, 1.0)
	var taken: Array = ctx.get("taken", [])
	var had: Array = ctx.get("had", [])
	var watch := bool(ctx.get("watch", false))
	var side := false
	for k in ctx.get("sides", []):
		side = side or taken.has(k)
	var w := {
		"knock": 0.8 + 1.4 * low + (1.8 if watch else 0.0),
		"phone": 0.7 + 0.9 * low + (1.5 if bool(ctx.get("six", false)) else 0.0),
		"tv": 0.5 + 1.3 * low,
		"bath": 0.6 + 1.1 * low + (0.4 if bool(ctx.get("rain", false)) else 0.0),
		"car": 0.9 if (h >= 22.0 or h < 2.5) else 0.35,
		"upstairs": 0.9 if taken.has(int(ctx.get("above", 0))) else 0.3 + 1.0 * low,
		"wall": 0.8 if side else 0.25 + 0.9 * low,
		"radiator": 0.5,
	}
	var sum := 0.0
	for k in KINDS:
		if had.has(k):
			w[k] = 0.0
		sum += float(w[k])
	if sum <= 0.0:
		return ""
	var r := rng.randf() * sum
	for k in KINDS:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return KINDS[KINDS.size() - 1]
