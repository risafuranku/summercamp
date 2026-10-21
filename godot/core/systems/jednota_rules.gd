extends RefCounted

## The camp's Jednota (DESIGN.md §7b "The Jednota"; the state while the game runs is
## scripts/jednota/jednota.gd, the stations scripts/jednota/*_station.gd). Pure data and
## arithmetic, the same on every machine.
##
## The goods go: off the van into the storeroom (the books' stock); a box of one good made
## up at the packing table and put on the cage trolley (the storeroom); off the trolley onto
## its place on the rack (the shelves); a guest comes in, looks round and takes what they
## came for off the rack into a basket (what is not on the rack they go without); queues at
## the till; every thing rung up, they pay (often with a note too big), the change counted
## out of the drawer onto the mat; out they go with the bag.
##
## The brief of 20. 10. (the top of the ladder: everything a guest needs, and for the whole
## stay): the cards and the magazines on the rack's top shelf, the rum by the beer, the
## cigarettes behind the till (asked for there, fetched off the wall), and the deli
## counter: salami, cheese and bread cut to the weight they ask (in deka, ten grams),
## weighed, wrapped in paper and priced by the weight; the parcel goes in their basket.

const BUSINESS_RULES := preload("res://core/systems/business_rules.gd")

## The rack (its four shelves, top to bottom) and the goods' places on it, left to right.
const PLANOGRAM := [["sweets", "soap", "cards", "magazine"], ["pickles", "beer", "rum", "veg"], ["bread", "roll", "salami"], ["milk", "icecream"]]
## Goods kept behind the till (asked for at the till, not taken off the rack).
const BEHIND := ["cigs"]
## The deli counter: per hundred grams (dollars), how much a slice weighs about, the
## books' good it comes off (in kilos), what they ask for (grams, in steps of ten).
const DELI := {
	"salami": {"label": "Salami", "per100": 3, "slice": 14.0, "good": "deli_salami", "asks": [100, 150, 200, 250]},
	"cheese": {"label": "Cheese", "per100": 2, "slice": 18.0, "good": "deli_cheese", "asks": [100, 150, 200, 300]},
	"bread": {"label": "Bread", "per100": 1, "slice": 90.0, "good": "deli_bread", "asks": [500, 600, 700]},
}
## Game minutes they wait at the deli counter before they go on without it.
const DELI_WAIT := 25
## A place on the rack holds this many (a third more with More shelves, gear); a box from
## the storeroom is this many.
const SLOT_CAP := 6
const SLOT_CAP_RACKS := 8
const BOX := 6
## Game minutes (1.5 a second): a guest looks round this long before they come to the
## till; the queue's patience after that: green, amber, red, gone (the visit is kept that
## long: jednota.gd, orders.set_holds).
const BROWSE := 8
## (Half as long again and more from 21. 10.: the guests had too little patience.)
const PATIENCE_OK := 32
const PATIENCE_LATE := 64
const PATIENCE_GONE := 96
## The drawer: what change is counted out in.
const CHANGE := [1, 2, 5, 10]
## What they pay with when it is not the right money.
const NOTES := [5, 10, 20, 50]
## What each kind of guest comes in for (weights over the goods) and how much of it.
const TASTE := {
	"drunk": {"beer": 6, "salami": 2, "pickles": 2, "roll": 2, "sweets": 1, "rum": 3, "cigs": 3, "cards": 1},
	"tramp": {"bread": 3, "salami": 3, "beer": 3, "pickles": 1, "soap": 1, "rum": 2, "cigs": 2},
	"quiet_guy": {"roll": 3, "milk": 2, "pickles": 1, "bread": 1, "soap": 1, "veg": 1, "magazine": 2},
	"cheap_chick": {"sweets": 3, "icecream": 3, "beer": 1, "veg": 1, "soap": 2, "magazine": 2, "cigs": 1},
	"picker": {"bread": 3, "milk": 3, "veg": 2, "roll": 2, "magazine": 1},
	"family": {"milk": 3, "roll": 3, "icecream": 3, "bread": 2, "sweets": 2, "veg": 1, "cards": 1, "soap": 1},
}
## Who goes to the deli counter (a share of each kind's visits).
const DELI_ODDS := {"drunk": 0.4, "tramp": 0.6, "quiet_guy": 0.4, "cheap_chick": 0.25, "picker": 0.6, "family": 0.55}
const HOW_MANY := {"drunk": [2, 3], "tramp": [2, 4], "quiet_guy": [2, 3], "cheap_chick": [1, 3], "picker": [3, 4], "family": [3, 5]}


static func goods() -> Dictionary:
	return BUSINESS_RULES.goods("vecerka")


static func price(good: String) -> int:
	return int((goods().get(good, {}) as Dictionary).get("price", 1))


static func slot_cap(racks: bool) -> int:
	return SLOT_CAP_RACKS if racks else SLOT_CAP


## Where a good stands on the rack: [shelf, place] ([-1, -1] not on it).
static func slot_of(good: String) -> Array:
	for s in PLANOGRAM.size():
		var row: Array = PLANOGRAM[s]
		for i in row.size():
			if str(row[i]) == good:
				return [s, i]
	return [-1, -1]


static func all_goods() -> Array:
	var out: Array = []
	for row in PLANOGRAM:
		for g in row:
			out.append(str(g))
	return out


# ── the deli counter ─────────────────────────────────────────────────────────

## What a visitor asks for at the deli counter ({} nothing): {good, want (grams)}.
static func deli_wish(visit: String, archetype: String) -> Dictionary:
	var h := absi(hash(visit + ":deli"))
	if float(h % 100) / 100.0 >= float(DELI_ODDS.get(archetype, 0.3)):
		return {}
	var goods: Array = DELI.keys()
	var good := str(goods[(h / 100) % goods.size()])
	var asks: Array = DELI[good]["asks"]
	return {"good": good, "want": int(asks[(h / 1000) % asks.size()])}


## A parcel's price: its weight at the hundred grams' price (rounded up to a dollar).
static func deli_price(good: String, grams: float) -> int:
	return maxi(1, int(ceil(grams / 100.0 * float(DELI[good]["per100"]))))


## A parcel in a basket: "deli:<good>:<grams>" (its price is its weight's).
static func parcel(good: String, grams: int) -> String:
	return "deli:%s:%d" % [good, grams]


static func is_parcel(item: String) -> bool:
	return item.begins_with("deli:")


## The weight against what they asked: {ok, accuracy, speed, notes}. Under by more than a
## tenth and they want more; over, they take it ("a bit over, is that all right?") but it
## counts against you.
static func judge_deli(made: float, want: int, wrapped: bool, age: int) -> Dictionary:
	var speed := speed_of(age)
	if not wrapped:
		return {"ok": false, "accuracy": 0.0, "speed": speed, "notes": ["Wrap it, please."]}
	var d := (made - float(want)) / float(want)
	if d < -0.1:
		return {"ok": false, "accuracy": 0.0, "speed": speed, "notes": ["That's not %d deka." % int(want / 10)]}
	var acc := 1.0 if absf(d) <= 0.05 else clampf(1.0 - (absf(d) - 0.05) * 2.0, 0.3, 0.95)
	var notes: Array = []
	if d > 0.15:
		notes.append("A bit over. Never mind.")
	return {"ok": true, "accuracy": acc, "speed": speed, "notes": notes}


## What a visitor comes in for: [good, ...] (the same on every machine).
static func basket_for(visit: String, archetype: String) -> Array:
	var taste: Dictionary = TASTE.get(archetype, TASTE["quiet_guy"])
	var span: Array = HOW_MANY.get(archetype, [2, 3])
	var h := absi(hash(visit + ":jednota"))
	var n := int(span[0]) + h % (int(span[1]) - int(span[0]) + 1)
	var total := 0
	for g in taste:
		total += int(taste[g])
	var out: Array = []
	for k in n:
		var r := absi(hash("%s#%d" % [visit, k])) % maxi(1, total)
		for g in taste:
			r -= int(taste[g])
			if r < 0:
				out.append(str(g))
				break
	return out


static func total_of(items: Array) -> int:
	var t := 0
	for g in items:
		t += item_price(str(g))
	return t


## A thing in a basket's price: a good's, or a parcel's by its weight.
static func item_price(item: String) -> int:
	if is_parcel(item):
		var p := item.split(":")
		return deli_price(p[1], float(p[2])) if p.size() >= 3 else 1
	return price(item)


## What they put on the mat for `total`: the right money (0: no change) now and then, else
## the smallest note it fits under.
static func pay_with(total: int, visit: String) -> int:
	if absi(hash(visit + ":pay")) % 4 == 0:
		return 0
	for note in NOTES:
		if note > total:
			return int(note)
	return int(NOTES[NOTES.size() - 1]) * int(ceil(float(total + 1) / float(NOTES[NOTES.size() - 1])))


## The change due on `paid` for `total` (0 when they paid right).
static func change_due(total: int, paid: int) -> int:
	return maxi(0, paid - total) if paid > 0 else 0


static func patience_band(age: int) -> int:
	if age < PATIENCE_OK:
		return 0
	return 1 if age < PATIENCE_LATE else 2


static func speed_of(age: int) -> float:
	if age < PATIENCE_OK * 0.5:
		return 1.0
	if age < PATIENCE_OK:
		return 0.75
	if age < PATIENCE_LATE:
		return 0.45
	return 0.15


## The change counted out against what is due: {ok, accuracy (0..1), speed, over (what went
## out too much)}. Short: they say so (not ok, count again); too much: they take it.
static func judge(given: int, due: int, age: int) -> Dictionary:
	if given < due:
		return {"ok": false, "accuracy": 0.0, "speed": speed_of(age), "over": 0, "short": due - given}
	var over := given - due
	var acc := 1.0 if over == 0 else clampf(1.0 - 0.2 * float(over), 0.3, 0.9)
	return {"ok": true, "accuracy": acc, "speed": speed_of(age), "over": over, "short": 0}


## What a unit of `good` costs off the van (the pack's price over the pack).
static func unit_cost(good: String) -> float:
	var d: Dictionary = goods().get(good, {})
	return float(d.get("pack_cost", 0)) / float(maxi(1, int(d.get("pack", 1))))


## A plain day of a staffed Jednota (DESIGN.md §7b: dear, but it pays): `visits` baskets
## (the guests' kinds in turn) rung up quick and right (Papa's full tip), their goods at
## the van's prices, `deliveries` vans, `waste_k` of the goods gone off, the hands'
## `wages`: {takings, goods, waste, fees, wages, net} in dollars.
static func day_model(visits: int, wages: int, deliveries := 1, waste_k := 0.05) -> Dictionary:
	var takings := 0
	var cost := 0.0
	var kinds: Array = TASTE.keys()
	var pts := BUSINESS_RULES.score(1.0, 1.0)
	for i in visits:
		var items := basket_for("model%d@%d" % [i, 600 + i * 37], str(kinds[i % kinds.size()]))
		var total := total_of(items)
		takings += total + int(BUSINESS_RULES.reward(pts, total)["tip"])
		for g in items:
			cost += unit_cost(str(g))
	var waste := cost * waste_k
	var fees := deliveries * BUSINESS_RULES.DELIVERY_FEE
	var net := float(takings) - cost - waste - float(fees) - float(wages)
	return {"takings": takings, "goods": int(round(cost)), "waste": int(round(waste)), "fees": fees, "wages": wages, "net": int(round(net))}
