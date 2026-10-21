class_name BistroRules
extends RefCounted

## The bistro's kitchen as a game (DESIGN.md §7b, "the bistro"): what the guests order,
## what goes on a plate, how long things take on the stove, how a plate is judged.
## Pure data and arithmetic: the kitchen's state is scripts/bistro/kitchen.gd, the
## station screens scripts/bistro/*_station.gd.
##
## The chain, cellar to table:
##   cellar   potatoes (stock) -> peeled and cut -> raw chips (prep "chips_raw")
##            cheese (stock) -> flour, egg, crumbs -> breaded slices ("cheese_raw")
##   kitchen  breaded slice -> the pan, both sides golden -> fried cheese ("cheese")
##            raw chips -> the basket, golden -> chips ("fries")
##            goulash (stock) -> the pot, hot, stirred -> ladled
##            dumplings (stock) -> a loaf on the board, cut with the thread -> slices ("dumpling")
##   kitchen  sausages (stock) -> the grill on the island, turned till both sides are brown
##            -> grilled ("sausage")
##   pass     a clean plate, what the ticket says, the bell -> the guest's table
##   bufet    (the dining room's counter, the brief of 20. 10.): the soup of the day out of
##            its pot into a bowl, over the counter; the big drinks in glass bottles,
##            kofola and malinovka, opened there (the cap flies off and lies where it lands)
##   sink     the plates come back dirty -> washed -> clean again

## What a guest can order. parts: what goes on the plate; the ticket may change the
## counts (big: six dumplings) and the extras (onion on the goulash, no tartar).
const DISHES := {
	"goulash": {"label": "Goulash", "price": 7, "parts": {"goulash": 1, "dumpling": 4}},
	"smazak": {"label": "Fried cheese", "price": 8, "parts": {"cheese": 1, "fries": 1, "tartar": 1}},
	"fries": {"label": "Chips", "price": 3, "parts": {"fries": 1, "tartar": 1}},
	"sausage": {"label": "Grilled sausage", "price": 6, "parts": {"sausage": 1, "mustard": 1, "bread": 1}},
	# Served at the bufet in a bowl (not at the pass).
	"soup": {"label": "Soup of the day", "price": 3, "parts": {"soup": 1}, "bufet": true},
}
## The big drinks in glass bottles, opened at the bufet: a ticket of their own.
const DRINKS := {
	"kofola": {"label": "Kofola", "price": 3, "good": "kofola"},
	"malinovka": {"label": "Malinovka", "price": 3, "good": "malinovka"},
}
## The things a plate is built from at the pass, in the order they are drawn on it.
const PARTS := ["goulash", "dumpling", "onion", "cheese", "fries", "tartar", "sausage", "mustard", "bread", "soup"]
## What each kind of guest likes to order (weights).
const TASTE := {
	"drunk": {"goulash": 5, "smazak": 2, "fries": 1, "sausage": 4, "soup": 1},
	"tramp": {"goulash": 4, "fries": 2, "sausage": 3, "soup": 2},
	"quiet_guy": {"smazak": 4, "goulash": 2, "soup": 2},
	"cheap_chick": {"fries": 4, "smazak": 2, "soup": 2},
	"picker": {"goulash": 4, "smazak": 1, "soup": 3, "sausage": 1},
	"family": {"smazak": 3, "fries": 3, "goulash": 1, "sausage": 2, "soup": 1},
}
## The grill: seconds a side over the coals till brown, and till it is black; places on it.
const GRILL_GOLD := 7.0
const GRILL_BURNT := 15.0
const GRILL_SLOTS := 4
## The soup pot at the bufet: bowls it holds, a refill (the books' soup), and how a bowl
## is ladled: two ladles to a bowl (a third and it slops over).
const SOUP_CAP := 16
const SOUP_REFILL := 10
const SOUP_LADLES := 2

## Minutes of game time (1.5 a second): the ticket goes up this long after they sit down
## (reading the menu); green while it is younger than PATIENCE_OK, amber to PATIENCE_LATE,
## red to PATIENCE_GONE, when they get up and go hungry.
const ORDER_DELAY := 5
const PATIENCE_OK := 60
const PATIENCE_LATE := 120
const PATIENCE_GONE := 180
## A plate takes this long to eat; then it goes back to the kitchen dirty.
const EAT_MINUTES := 45

## The stove, in seconds of hot oil. A breaded side is golden from GOLD and black from
## BURNT (a badly breaded slice, the cheese running out of it, sooner).
const CHEESE_GOLD := 6.0
const CHEESE_BURNT := 13.0
const CHEESE_BURNT_BAD := 9.5
const PAN_SLOTS := 3
const FRIES_GOLD := 8.0
const FRIES_BURNT := 15.0
## Portions of chips in one basket.
const BASKET_PORTIONS := 2
## The pot: portions it holds, what one refill puts in (goulash units off the shelf),
## seconds to come back to the boil after a refill, seconds before it catches on the
## bottom if nobody stirs it (and the portions lost when it does).
const POT_CAP := 12
const POT_REFILL := 8
const POT_HEAT_SEC := 18.0
const POT_CATCH_SEC := 80.0
const POT_BURN_LOSS := 2
## A loaf of dumplings: dumpling units off the shelf (a unit is a plate's worth) and
## the slices it cuts into.
const LOAF_UNITS := 2
const LOAF_SLICES := 8
## The cellar: potatoes peeled in one go (stock units, each a portion of chips).
const PEEL_BATCH := 4
## Seconds of the peeler: peeled from PEEL_DONE, worn to marbles from PEEL_OVER.
const PEEL_DONE := 3.5
const PEEL_OVER := 7.0
## How much fits on the trays and racks.
const PREP_CAP := {"chips_raw": 12, "cheese_raw": 8, "cheese": 6, "fries": 6, "dumpling": 16}
## Plates in the kitchen when it opens.
const PLATES := 10


static func dish_label(dish: String) -> String:
	if DRINKS.has(dish):
		return str(DRINKS[dish]["label"])
	return str((DISHES.get(dish, {}) as Dictionary).get("label", dish))


## Whether a ticket's dish is done at the bufet (the soup, the drinks) and not the pass.
static func at_bufet(dish: String) -> bool:
	return DRINKS.has(dish) or bool((DISHES.get(dish, {}) as Dictionary).get("bufet", false))


## The drink a guest wants with their food ("" none): the same on every machine.
static func drink_wish(tid: String) -> String:
	return ["kofola", "", "malinovka", "", "kofola", ""][absi(hash(tid + ":drink")) % 6]


## The tickets one visit puts up: one per person at the table. Decided by the visit and
## the seat alone, so every machine in co-op writes the same ones without being told.
##   visit: "<guest id>@<visit start>"; returns [{id, member, dish, parts, price}]
static func tickets_for(visit: String, archetype: String, figures: int) -> Array:
	var out: Array = []
	for m in maxi(1, figures):
		var tid := "%s#%d" % [visit, m]
		var h := absi(hash(tid))
		var dish := pick_dish(archetype, h % 997)
		var parts: Dictionary = (DISHES[dish]["parts"] as Dictionary).duplicate()
		var price := int(DISHES[dish]["price"])
		var roll := (h / 997) % 100
		match dish:
			"goulash":
				if roll < 30:
					parts["dumpling"] = 6
					price += 1
				if (h / 99700) % 100 < 40:
					parts["onion"] = 1
			"smazak":
				if roll < 15:
					parts.erase("tartar")
			"fries":
				if roll < 40:
					parts.erase("tartar")
		out.append({"id": tid, "member": m, "dish": dish, "parts": parts, "price": price})
		# A big drink with it, on a ticket of its own (opened at the bufet).
		var d := drink_wish(tid)
		if d != "":
			out.append({"id": tid + ":d", "member": m, "dish": d, "parts": {d: 1}, "price": int(DRINKS[d]["price"]), "drink": true})
	return out


## Ticket `t` with its dish off the menu (the books' MENU): the next dish they would like
## that is on (`on`: dish -> bool), its plate as the dish's own and its price; the same
## ticket id, so every machine agrees. The fried cheese is never off.
static func instead(t: Dictionary, on: Callable) -> Dictionary:
	var out := t.duplicate()
	for d in ["smazak", "goulash", "fries", "sausage", "soup"]:
		if d != str(t["dish"]) and bool(on.call(d)):
			out["dish"] = d
			out["parts"] = (DISHES[d]["parts"] as Dictionary).duplicate()
			out["price"] = int(DISHES[d]["price"])
			return out
	return out


static func pick_dish(archetype: String, roll: int) -> String:
	var w: Dictionary = TASTE.get(archetype, {"goulash": 1, "smazak": 1})
	var total := 0
	for k in w:
		total += int(w[k])
	var r := roll % maxi(1, total)
	for k in w:
		r -= int(w[k])
		if r < 0:
			return str(k)
	return "goulash"


## The main thing on a plate: what the guest would call it (goulash, fried cheese, chips),
## "" for an empty plate or a heap of sides.
static func main_of(parts: Dictionary) -> String:
	for d in DRINKS:
		if int(parts.get(d, 0)) > 0:
			return str(d)
	if int(parts.get("soup", 0)) > 0:
		return "soup"
	if int(parts.get("sausage", 0)) > 0:
		return "sausage"
	if int(parts.get("goulash", 0)) > 0:
		return "goulash"
	if int(parts.get("cheese", 0)) > 0:
		return "smazak"
	if int(parts.get("fries", 0)) > 0:
		return "fries"
	return ""


## A plate against its ticket: {ok (the right dish at all), accuracy 0..1, speed 0..1,
## tip, stars 1..3, mood}. `age` is the ticket's age in game minutes.
static func judge(have: Dictionary, want: Dictionary, age: int) -> Dictionary:
	if main_of(have) != main_of(want) or main_of(have) == "":
		return {"ok": false, "accuracy": 0.0, "speed": 0.0, "tip": 0, "stars": 0, "mood": -1.0}
	var off := 0
	var total := 0
	for p in PARTS:
		var a := int(have.get(p, 0))
		var b := int(want.get(p, 0))
		total += b
		# A dumpling short or over is half a mistake; a missing thing is a whole one.
		off += absi(a - b) if p != "dumpling" else ceili(absi(a - b) * 0.5)
	var accuracy := clampf(1.0 - float(off) / float(maxi(1, total)), 0.0, 1.0)
	var speed := 1.0 if age < 45 else (0.6 if age < PATIENCE_OK + 30 else (0.3 if age < PATIENCE_LATE + 15 else 0.0))
	var tip := int(round(accuracy * 2.0 + speed * 2.0)) if accuracy > 0.5 else 0
	var stars := 1 + (1 if accuracy >= 0.85 else 0) + (1 if speed >= 0.6 else 0)
	var mood := -1.0 + accuracy * 2.0 + speed * 1.5
	return {"ok": true, "accuracy": accuracy, "speed": speed, "tip": tip, "stars": stars, "mood": mood}


## The colour band of a ticket's wait: 0 green, 1 amber, 2 red.
static func patience_band(age: int) -> int:
	if age < PATIENCE_OK:
		return 0
	if age < PATIENCE_LATE:
		return 1
	return 2


## A side of breaded cheese after `t` seconds in the oil: 0 raw, 1 golden, 2 burnt.
static func cheese_side(t: float, bad := false) -> int:
	if t < CHEESE_GOLD:
		return 0
	return 1 if t < (CHEESE_BURNT_BAD if bad else CHEESE_BURNT) else 2


## The basket after `t` seconds down: 0 pale, 1 golden, 2 burnt.
static func fries_state(t: float) -> int:
	if t < FRIES_GOLD:
		return 0
	return 1 if t < FRIES_BURNT else 2


## A sausage's side on the grill after `t` seconds: 0 pink, 1 brown, 2 black.
static func sausage_side(t: float) -> int:
	if t < GRILL_GOLD:
		return 0
	return 1 if t < GRILL_BURNT else 2


## The peeler after `t` seconds: 0 still in their skins, 1 peeled, 2 worn to marbles.
static func peel_state(t: float) -> int:
	if t < PEEL_DONE:
		return 0
	return 1 if t < PEEL_OVER else 2


# ── PROTOTYP 540, the cellar's machine (DESIGN.md §7b "The bistro") ──────────

## Portions of goulash meat it leaves in its tray by morning when it was fed in the night.
const PROTO_MEAT := 20


## Whether it is awake at `hour`: the night, and from eight while the bistro is open late.
static func proto_awake(hour: int, late: bool) -> bool:
	return hour >= 21 or hour < 5 or (late and hour >= 20)


## The night `hour` of `day` belongs to (a night is the day it began on).
static func proto_night(day: int, hour: int) -> int:
	return day if hour >= 12 else day - 1


## Whether a sack lies in front of it on `night`: always the night after the camp woke
## without somebody (`taken`), else one night in five (the same on every machine).
static func proto_sack(key: String, night: int, taken: bool) -> bool:
	return taken or absi(hash("540:%s:%d" % [key, night])) % 5 == 0
