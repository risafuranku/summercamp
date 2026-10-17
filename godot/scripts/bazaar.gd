extends RefCounted

## The office's lost and found, and the district's classifieds where it can go
## (bazar-hlubocany.cz in the browser, DESIGN.md §5h). A party that checks out sometimes
## leaves something behind; on the PC you put it up for sale; the morning after, some of
## it has sold. Pure logic (seeded), checked by tools/bazaar_check.gd; main pays, says it,
## and saves it.
##
## One thing in the box nobody left: from the sixth day, a child's red shoe, small and wet.
## It sells for a dollar to a buyer with no name, and the day after it is in the box again.

const LEAVE_CHANCE := 0.35
## Families and their children leave more behind.
const LEAVE_CHANCE_FAMILY := 0.55
const SELL_CHANCE := 0.55
## Each day an ad stays up it is likelier to go.
const SELL_CHANCE_PER_DAY := 0.15
const SHOE_FROM_DAY := 6
const SHOE_CHANCE := 0.3
## Sold things stay on the page this many days.
const SOLD_SHOWN_DAYS := 3

const ITEMS := [
	{"short": "Walkman", "name": "a Walkman, a tape still in it", "value": 35},
	{"short": "Thermos", "name": "a thermos flask, dented", "value": 8},
	{"short": "Sunglasses", "name": "sunglasses, one arm taped", "value": 6},
	{"short": "Fishing rod", "name": "a fishing rod and a tin of hooks", "value": 28},
	{"short": "Watch", "name": "a child's digital watch, the alarm set for 3:00", "value": 12},
	{"short": "Camera", "name": "a compact camera, film inside", "value": 45},
	{"short": "Penknife", "name": "a penknife with a corkscrew", "value": 10},
	{"short": "Sleeping bag", "name": "a sleeping bag, rolled", "value": 22},
	{"short": "Paperback", "name": "a paperback, Stephen King, swollen from the damp", "value": 4},
	{"short": "Boots", "name": "hiking boots, size 43", "value": 18},
	{"short": "Radio", "name": "a transistor radio", "value": 15},
	{"short": "Game Boy", "name": "a Game Boy with Tetris", "value": 40},
	{"short": "Binoculars", "name": "binoculars in a leather case", "value": 30},
	{"short": "Cap", "name": "a baseball cap, Chicago Bulls", "value": 5},
]
const SHOE := {"short": "Red shoe", "name": "a child's red shoe, small and wet", "value": 1, "uncanny": true}

## [{id, short, name, value, from, where, found_day, listed_day, sold_day, price, uncanny}]
var items: Array = []
var shoe_seen := false
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## A party checked out of `where`: maybe something stayed behind. The thing, or {}.
func on_checkout(guest_name: String, where: String, day: int, archetype: String = "") -> Dictionary:
	var chance := LEAVE_CHANCE_FAMILY if archetype == "family" else LEAVE_CHANCE
	if _rng.randf() >= chance:
		return {}
	var have := {}
	for it in in_box():
		have[str(it["short"])] = true
	var pool: Array = ITEMS.filter(func(i): return not have.has(str(i["short"])))
	if pool.is_empty():
		return {}
	return _add(pool[_rng.randi_range(0, pool.size() - 1)], guest_name, where, day)


## Put it up for sale. False when it is not in the box.
func list(id: int, day: int) -> bool:
	for it in items:
		if int(it["id"]) == id and int(it["listed_day"]) < 0 and int(it["sold_day"]) < 0:
			it["listed_day"] = day
			return true
	return false


## The morning of `day`: ads up since an earlier day may have sold; the shoe comes back.
## Returns {sold: [items], back: [items], found: [items]} for main to pay and say.
func settle(day: int) -> Dictionary:
	var sold: Array = []
	var back: Array = []
	var found: Array = []
	for it in items:
		if int(it["sold_day"]) >= 0 or int(it["listed_day"]) < 0 or int(it["listed_day"]) >= day:
			continue
		var up := day - int(it["listed_day"])
		if bool(it.get("uncanny", false)) or _rng.randf() < SELL_CHANCE + SELL_CHANCE_PER_DAY * float(up - 1):
			it["sold_day"] = day
			it["price"] = int(it["value"])
			sold.append(it)
	# The shoe sold yesterday is in the box again this morning.
	for it in items.duplicate():
		if bool(it.get("uncanny", false)) and int(it["sold_day"]) >= 0 and int(it["sold_day"]) < day and not bool(it.get("returned", false)):
			it["returned"] = true
			back.append(_add(SHOE, "", "", day))
	if not shoe_seen and day >= SHOE_FROM_DAY and _rng.randf() < SHOE_CHANCE:
		shoe_seen = true
		found.append(_add(SHOE, "", "", day))
	# Old sold ads drop off the page.
	items = items.filter(func(i): return int(i["sold_day"]) < 0 or day - int(i["sold_day"]) <= SOLD_SHOWN_DAYS or (bool(i.get("uncanny", false)) and not bool(i.get("returned", false))))
	return {"sold": sold, "back": back, "found": found}


func in_box() -> Array:
	return items.filter(func(i): return int(i["listed_day"]) < 0 and int(i["sold_day"]) < 0)


func listed() -> Array:
	return items.filter(func(i): return int(i["listed_day"]) >= 0 and int(i["sold_day"]) < 0)


func sold() -> Array:
	return items.filter(func(i): return int(i["sold_day"]) >= 0)


func export_state() -> Dictionary:
	return {"items": items.duplicate(true), "shoe_seen": shoe_seen, "next_id": _next_id}


func import_state(d: Dictionary) -> void:
	items.clear()
	for it in d.get("items", []):
		if it is Dictionary:
			var c: Dictionary = (it as Dictionary).duplicate(true)
			for k in ["id", "value", "found_day", "listed_day", "sold_day", "price"]:
				c[k] = int(c.get(k, -1))
			items.append(c)
	shoe_seen = bool(d.get("shoe_seen", false))
	_next_id = maxi(1, int(d.get("next_id", 1)))


func reset() -> void:
	items.clear()
	shoe_seen = false
	_next_id = 1


func _add(def: Dictionary, from: String, where: String, day: int) -> Dictionary:
	var it := {"id": _next_id, "short": str(def["short"]), "name": str(def["name"]), "value": int(def["value"]),
		"from": from, "where": where, "found_day": day, "listed_day": -1, "sold_day": -1, "price": 0,
		"uncanny": bool(def.get("uncanny", false))}
	_next_id += 1
	items.append(it)
	return it
