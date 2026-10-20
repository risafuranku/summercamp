class_name BusinessRules
extends RefCounted

## The camp's businesses as businesses (playtest 18. 10.; reworked with the user 20. 10.,
## DESIGN.md §7b): the pub, the bistro, the Jednota and the corn stand each keep goods on
## their shelves, sell them to the guests who come in, run out, and are restocked by the
## delivery van from what you order. Goods go off: every delivery is a lot with the day it
## came, the oldest is used first, and what is past its days goes bad on the shelf and has
## to be thrown out. Hands are taken on one by one, each with a job (a role) and a shift,
## each a person with their own speed, honesty and temper and their own wage; a place
## whose front job is covered serves without you. Better gear (the only progression: the
## menu is whole from the first day) is bought for each place. A place can stay open in
## the evening, when the night is already on.
##
## Pure data and arithmetic. The state is GameState.biz (actions.gd biz_*), the running
## side scripts/business/business_runtime.gd and scripts/business/staff.gd, the paper desk
## ledger_closeup.gd and the office PC's program scripts/os98/apps/business_app.gd.
##
##   biz = {
##     "sites": {"x:y": {"kind", "stock": {good: n}, "lots": {good: [[n, day], ...]},
##               "spoiled": {good: n}, "gear": [id, ...], "crew": [person, ...],
##               "late": bool, "staff": bool (the front job covered now), "staff_name",
##               "since_day", "today": {...}, "yesterday": {...}, "history": [...],
##               "shift": {...} (this shift's orders and scores), "zreport": {...}}},
##     "orders": [{"key", "goods": {good: packs}, "cost", "due_day"}],
##     "licences": ["pub", ...],
##   }

## Building type -> business kind.
const KIND_OF := {"pub": "pub", "restaurant": "rest", "vecerka": "vecerka", "corn_stand": "corn"}

## Per kind: its name, the hand's base wage a day, the PC program, and its goods:
##   good -> {label, unit, price (what a guest pays), pack (units per delivery pack),
##            pack_cost, cap (shelf space), start (on the shelf when it is built),
##            life (days before it goes off on the shelf; 0 never)}
const KINDS := {
	"pub": {
		"name": "Pub", "wage": 30, "hand": ["Lojza", "Franta", "Mirek"],
		"app": "pub_app", "app_name": "Hostinsky 98", "licence": 120,
		"goods": {
			"beer": {"label": "Beer", "unit": "pints", "price": 4, "pack": 50, "pack_cost": 60, "cap": 150, "start": 40, "life": 6},
			"rum": {"label": "Rum", "unit": "shots", "price": 3, "pack": 20, "pack_cost": 26, "cap": 60, "start": 10, "life": 0},
			"kofola": {"label": "Kofola", "unit": "glasses", "price": 2, "pack": 24, "pack_cost": 18, "cap": 72, "start": 12, "life": 8},
		},
		# What a visit takes, by the kind of guest (shares of a visit's appetite).
		"wants": {"beer": 0.7, "rum": 0.2, "kofola": 0.1},
	},
	"rest": {
		"name": "Bistro", "wage": 35, "hand": ["Mrs Dvorakova", "Pepa", "Hanka"],
		"app": "bistro_app", "app_name": "Kuchar 98", "licence": 140,
		"goods": {
			"goulash": {"label": "Goulash", "unit": "portions", "price": 7, "pack": 20, "pack_cost": 70, "cap": 60, "start": 12, "life": 0},
			"cheese": {"label": "Cheese", "unit": "slices", "price": 8, "pack": 20, "pack_cost": 64, "cap": 60, "start": 10, "life": 6},
			"potatoes": {"label": "Potatoes", "unit": "portions", "price": 3, "pack": 30, "pack_cost": 30, "cap": 90, "start": 20, "life": 5},
			"dumplings": {"label": "Dumplings", "unit": "plates", "price": 0, "pack": 30, "pack_cost": 24, "cap": 90, "start": 15, "life": 3},
		},
		"wants": {"goulash": 0.45, "cheese": 0.3, "potatoes": 0.25},
	},
	"vecerka": {
		"name": "Jednota", "wage": 40, "hand": ["Mrs Novakova", "Zdenka", "Ivan"],
		"app": "shop_app", "app_name": "Pult 98", "licence": 100,
		# The village shop the guests love (DESIGN.md §7b, the Jednota): everything they
		# need, dear to stock and to staff.
		"goods": {
			"bread": {"label": "Bread", "unit": "loaves", "price": 4, "pack": 20, "pack_cost": 46, "cap": 40, "start": 10, "life": 2},
			"roll": {"label": "Rolls", "unit": "rolls", "price": 1, "pack": 60, "pack_cost": 38, "cap": 120, "start": 40, "life": 2},
			"salami": {"label": "Salami", "unit": "sticks", "price": 5, "pack": 12, "pack_cost": 40, "cap": 36, "start": 6, "life": 8},
			"milk": {"label": "Milk", "unit": "bags", "price": 2, "pack": 24, "pack_cost": 34, "cap": 48, "start": 12, "life": 3},
			"pickles": {"label": "Pickles", "unit": "jars", "price": 3, "pack": 12, "pack_cost": 26, "cap": 36, "start": 6, "life": 0},
			"beer": {"label": "Lesnak", "unit": "bottles", "price": 2, "pack": 20, "pack_cost": 28, "cap": 60, "start": 20, "life": 0},
			"icecream": {"label": "Ice cream", "unit": "cones", "price": 2, "pack": 24, "pack_cost": 30, "cap": 48, "start": 12, "life": 0},
			"sweets": {"label": "Sweets", "unit": "bars", "price": 1, "pack": 40, "pack_cost": 26, "cap": 80, "start": 20, "life": 0},
			"veg": {"label": "Fruit and veg", "unit": "bags", "price": 2, "pack": 20, "pack_cost": 24, "cap": 40, "start": 10, "life": 4},
			"soap": {"label": "Soap and paper", "unit": "packs", "price": 3, "pack": 12, "pack_cost": 22, "cap": 24, "start": 6, "life": 0},
		},
		"wants": {"bread": 0.1, "roll": 0.18, "salami": 0.08, "milk": 0.12, "pickles": 0.04, "beer": 0.14, "icecream": 0.12, "sweets": 0.1, "veg": 0.08, "soap": 0.04},
	},
	"corn": {
		"name": "Corn stand", "wage": 15, "hand": ["Pepicek", "Klara", "the Novak boy"],
		"app": "corn_app", "app_name": "Klasek 98", "licence": 60,
		"goods": {
			"cobs": {"label": "Corn cobs", "unit": "cobs", "price": 2, "pack": 40, "pack_cost": 32, "cap": 80, "start": 20, "life": 4},
			"butter": {"label": "Butter", "unit": "knobs", "price": 0, "pack": 60, "pack_cost": 15, "cap": 120, "start": 30, "life": 6},
		},
		"wants": {"cobs": 1.0},
	},
}
## What a dish or a drink takes off the shelf (the counter games' names).
const RECIPES := {
	"rest": {"goulash": {"goulash": 1, "dumplings": 1}, "smazak": {"cheese": 1, "potatoes": 1}, "fries": {"potatoes": 1}},
	"corn": {"cob": {"cobs": 1, "butter": 1}},
}
## The van: what one delivery costs on top of the goods, the day after you order.
const DELIVERY_FEE := 10
## A hand serves this share of who comes in (the rest gives up waiting).
const HAND_SERVES := 0.85


static func is_business(building_type: String) -> bool:
	return KIND_OF.has(building_type)


static func kind_of(building_type: String) -> String:
	return str(KIND_OF.get(building_type, ""))


static func info(kind: String) -> Dictionary:
	return KINDS.get(kind, {})


static func goods(kind: String) -> Dictionary:
	return (KINDS.get(kind, {}) as Dictionary).get("goods", {})


## A new site's record, the shelves stocked to start with (one lot each, dated `day`).
static func new_site(kind: String, day := 1) -> Dictionary:
	var stock := {}
	var lots := {}
	for g in goods(kind):
		var n := int(goods(kind)[g]["start"])
		stock[g] = n
		lots[g] = [[n, day]] if n > 0 else []
	return {"kind": kind, "stock": stock, "lots": lots, "spoiled": {}, "gear": [], "crew": [], "late": false,
		"staff": false, "staff_name": "", "since_day": 0, "today": empty_day(), "yesterday": empty_day(),
		"shift": empty_shift()}


static func empty_day() -> Dictionary:
	return {"sold": 0, "takings": 0, "lost": 0, "by_hand": 0, "waste": 0, "short": 0}


## The cost of an order (goods: {good: packs}), the van's fee included.
static func order_cost(kind: String, order: Dictionary) -> int:
	var total := 0
	for g in order:
		var d: Dictionary = goods(kind).get(g, {})
		total += int(d.get("pack_cost", 0)) * int(order[g])
	return total + (DELIVERY_FEE if total > 0 else 0)


## The goods' cost of an order without the van (one van brings everything ordered for the
## camp the same day: the PC program's single order).
static func goods_cost(kind: String, order: Dictionary) -> int:
	return maxi(0, order_cost(kind, order) - (DELIVERY_FEE if not order.is_empty() else 0))


## How many packs of `good` still fit on the shelf, counting what is already ordered.
static func room_for(kind: String, good: String, stock: int, on_order_units: int) -> int:
	var d: Dictionary = goods(kind).get(good, {})
	var free: int = int(d.get("cap", 0)) - stock - on_order_units
	return maxi(0, free / maxi(1, int(d.get("pack", 1))))


## What one visit takes off the shelf: {good: units} by the guest kind's appetite (pub:
## a drunk drinks four), the kind's wants deciding which goods.
static func basket(kind: String, appetite: int, roll: float) -> Dictionary:
	var out := {}
	var wants: Dictionary = (KINDS.get(kind, {}) as Dictionary).get("wants", {})
	for i in maxi(1, appetite):
		var r := fmod(roll * float(i + 1) * 7.31, 1.0)
		var acc := 0.0
		for g in wants:
			acc += float(wants[g])
			if r <= acc:
				out[g] = int(out.get(g, 0)) + 1
				break
	return out


## The money a basket brings (the goods' prices; a dish's sides are in the main price).
static func basket_price(kind: String, b: Dictionary) -> int:
	var total := 0
	for g in b:
		total += int((goods(kind).get(g, {}) as Dictionary).get("price", 0)) * int(b[g])
	return total


## Units a basket needs from the shelf, the bistro's sides added (goulash comes with
## dumplings), the stand's butter on every cob.
static func needs_for(kind: String, b: Dictionary) -> Dictionary:
	var out := b.duplicate()
	if kind == "rest" and out.has("goulash"):
		out["dumplings"] = int(out.get("dumplings", 0)) + int(out["goulash"])
	if kind == "corn" and out.has("cobs"):
		out["butter"] = int(out.get("butter", 0)) + int(out["cobs"])
	return out


static func can_take(stock: Dictionary, needs: Dictionary) -> bool:
	for g in needs:
		if int(stock.get(g, 0)) < int(needs[g]):
			return false
	return true


## Low when below a pack's worth (the desk and the program show it red).
static func is_low(kind: String, good: String, n: int) -> bool:
	return n < int((goods(kind).get(good, {}) as Dictionary).get("pack", 1)) / 2


# ── going off ────────────────────────────────────────────────────────────────

## Days `good` keeps on the shelf (0: it does not go off).
static func life(kind: String, good: String) -> int:
	return int((goods(kind).get(good, {}) as Dictionary).get("life", 0))


## The lots of a good, oldest first, with `n` taken off the oldest: returns the lots left.
static func lots_take(lots: Array, n: int) -> Array:
	var out: Array = []
	var left := n
	for lot in lots:
		var have := int(lot[0])
		if left > 0:
			var used := mini(have, left)
			have -= used
			left -= used
		if have > 0:
			out.append([have, int(lot[1])])
	return out


## The lots of a good on `day`: [kept lots, units gone off]. A lot goes off once it has
## been on the shelf longer than the good's life.
static func lots_spoil(kind: String, good: String, lots: Array, day: int) -> Array:
	var days := life(kind, good)
	if days <= 0:
		return [lots, 0]
	var kept: Array = []
	var off := 0
	for lot in lots:
		if day - int(lot[1]) >= days:
			off += int(lot[0])
		else:
			kept.append(lot)
	return [kept, off]


## Days before the oldest lot of a good goes off (-1 never; 0 today).
static func days_left(kind: String, good: String, lots: Array, day: int) -> int:
	var days := life(kind, good)
	if days <= 0 or lots.is_empty():
		return -1
	return maxi(0, days - (day - int(lots[0][1])))


## The dishes and drinks a place can make now from its shelves (the menu board crosses
## out the rest in chalk): {dish: bool}.
static func menu(kind: String, stock: Dictionary) -> Dictionary:
	var out := {}
	match kind:
		"rest":
			out["goulash"] = int(stock.get("goulash", 0)) > 0 and int(stock.get("dumplings", 0)) > 0
			out["smazak"] = int(stock.get("cheese", 0)) > 0 and int(stock.get("potatoes", 0)) > 0
			out["fries"] = int(stock.get("potatoes", 0)) > 0
		"pub":
			out["beer"] = int(stock.get("beer", 0)) > 0
			out["rum"] = int(stock.get("rum", 0)) > 0
			out["kofola"] = int(stock.get("kofola", 0)) > 0
		"corn":
			out["cob"] = int(stock.get("cobs", 0)) > 0
		"vecerka":
			for g in goods(kind):
				out[g] = int(stock.get(g, 0)) > 0
	return out


# ── gear: the only progression ───────────────────────────────────────────────

## What each place can buy to work better, Papa's way (DESIGN.md §7b): a short list a
## place, bought in the books or on the PC, seen in the room once it stands there.
##   id -> {label, price, what (one line, what it does)}
const GEAR := {
	"rest": {
		"basket2": {"label": "Second fryer basket", "price": 180, "what": "Two baskets of chips in the oil at once."},
		"pan": {"label": "Heavy pan", "price": 160, "what": "A fourth place in the pan; slices burn later."},
		"washer": {"label": "Dishwasher", "price": 340, "what": "The dirty plates in, clean ones out a while later."},
		"pot": {"label": "Big pot", "price": 150, "what": "Holds twenty portions and catches slower."},
		"lamp": {"label": "Heat lamp", "price": 110, "what": "Fried food on the shelf keeps hot: no stars lost."},
		"clock": {"label": "Ticket clock", "price": 90, "what": "The guests see the order is up: they wait longer."},
	},
	"pub": {
		"tap2": {"label": "Second tap", "price": 260, "what": "A second spout on the line: the beer comes faster, a hand draws two at once."},
		"glasswasher": {"label": "Glass washer", "price": 220, "what": "The mugs come out clean by themselves."},
		"cooler": {"label": "Keg cooler", "price": 200, "what": "A tapped keg keeps twice as long."},
		"coupler": {"label": "Quick coupler", "price": 90, "what": "A keg changed in a moment."},
	},
	"corn": {
		"pot": {"label": "Bigger pot", "price": 80, "what": "Six cobs boil at once."},
		"butter": {"label": "Butter warmer", "price": 60, "what": "Soft butter: a cob buttered in one stroke."},
		"table": {"label": "Husking table", "price": 70, "what": "The husks come off in fewer pulls."},
	},
	"vecerka": {
		"till2": {"label": "Second till", "price": 420, "what": "Two queues at once (it needs a second hand)."},
		"pallet": {"label": "Pallet truck", "price": 260, "what": "A delivery unloaded in half the time."},
		"fridge": {"label": "Chiller cabinet", "price": 380, "what": "Milk and salami keep twice as long."},
		"racks": {"label": "More shelves", "price": 300, "what": "A third more on every shelf."},
	},
}


static func gear_list(kind: String) -> Dictionary:
	return GEAR.get(kind, {})


static func has_gear(site: Dictionary, id: String) -> bool:
	return (site.get("gear", []) as Array).has(id)


## Shelf space with the gear in (the Jednota's extra shelves).
static func cap_of(kind: String, good: String, site: Dictionary) -> int:
	var cap := int((goods(kind).get(good, {}) as Dictionary).get("cap", 0))
	if kind == "vecerka" and has_gear(site, "racks"):
		cap = int(cap * 1.34)
	return cap


## The shelf life with the gear in (the chiller, the keg cooler).
static func life_of(kind: String, good: String, site: Dictionary) -> int:
	var days := life(kind, good)
	if days > 0 and kind == "vecerka" and good in ["milk", "salami"] and has_gear(site, "fridge"):
		days *= 2
	if days > 0 and kind == "pub" and good == "beer" and has_gear(site, "cooler"):
		days *= 2
	return days


# ── the hands ────────────────────────────────────────────────────────────────

## The jobs of each place, in the order they matter (the first is the front: with it
## covered the place serves without you).
const ROLES := {
	"rest": [["pass", "Pass"], ["stove", "Stove"], ["cellar", "Cellar"], ["sink", "Sink"]],
	"pub": [["tap", "Tap"], ["bar", "Back bar"], ["wash", "Washer"], ["cellar", "Cellar"]],
	"corn": [["counter", "Counter"], ["husk", "Husking"]],
	"vecerka": [["till", "Till"], ["shelves", "Shelves"], ["store", "Storeroom"], ["till2", "Second till"]],
}


static func front(kind: String) -> String:
	var r: Array = ROLES.get(kind, [])
	return str(r[0][0]) if not r.is_empty() else ""


static func role_label(kind: String, role: String) -> String:
	for r in ROLES.get(kind, []):
		if str(r[0]) == role:
			return str(r[1])
	return role.capitalize()


## The people who come asking for work: slug (their ID photo, their sprites) -> {name,
## asks (the places they ask at), sex}. The last two nobody quite remembers.
const PEOPLE := {
	"dvorakova": {"name": "Mrs Dvorakova", "asks": ["rest", "vecerka"]},
	"pepa": {"name": "Pepa", "asks": ["rest", "pub"]},
	"hanka": {"name": "Hanka", "asks": ["rest", "pub", "vecerka"]},
	"lojza": {"name": "Lojza", "asks": ["pub"]},
	"franta": {"name": "Franta", "asks": ["pub", "corn"]},
	"mirek": {"name": "Mirek", "asks": ["pub", "rest", "vecerka"]},
	"novakova": {"name": "Mrs Novakova", "asks": ["vecerka"]},
	"zdenka": {"name": "Zdenka", "asks": ["vecerka", "rest"]},
	"ivan": {"name": "Ivan", "asks": ["vecerka", "pub"]},
	"pepicek": {"name": "Pepicek", "asks": ["corn", "vecerka"]},
	"klara": {"name": "Klara", "asks": ["corn", "rest"]},
	"novak_boy": {"name": "the Novak boy", "asks": ["corn"]},
	"jaromir": {"name": "Jaromir", "asks": ["rest", "pub", "vecerka"], "strange": "night"},
	"marta": {"name": "Marta", "asks": ["vecerka", "rest", "corn"], "strange": "unseen"},
}
## The speeds: seconds a hand takes over one piece of work, and how often it goes wrong.
const SPEED_SEC := [9.0, 6.0, 4.0]
const SPEED_SLIP := [0.14, 0.08, 0.05]
const SPEED_WORD := ["Takes their time.", "Steady.", "Quick on their feet."]
const TEMPER_WORD := {"warm": "Talks to everybody.", "flat": "Keeps to themselves.", "sour": "Not much of a smile."}
## A late shift costs this much more than a day.
const LATE_PAY := 1.5
## Opening: the day shift to 20:00, the late one to 23:00.
const DAY_CLOSE := 20
const LATE_CLOSE := 23


## A person's ways, the same in a camp every time (seeded by the camp): {speed 0..2,
## honest, temper, strange, wage}.
static func traits(slug: String, kind: String, seed := 0) -> Dictionary:
	var p: Dictionary = PEOPLE.get(slug, {})
	var h := absi(hash("%s|%d" % [slug, seed]))
	var strange := str(p.get("strange", ""))
	var speed := h % 3
	var honest := (h / 3) % 4 != 0
	var temper: String = ["warm", "flat", "sour"][(h / 12) % 3]
	if strange != "":
		# The two nobody remembers work well, never steal and want next to nothing.
		speed = 2
		honest = true
		temper = "warm"
	return {"speed": speed, "honest": honest, "temper": temper, "strange": strange, "wage": wage(kind, speed, honest, temper, strange)}


## What they ask a day: the place's wage, more for the quick and the pleasant, less for
## the slow and the sour; a thief asks a little less (a tell for the careful).
static func wage(kind: String, speed: int, honest: bool, temper: String, strange := "") -> int:
	var w := int((KINDS.get(kind, {}) as Dictionary).get("wage", 25))
	w += (speed - 1) * 8
	w += {"warm": 4, "flat": 0, "sour": -4}.get(temper, 0)
	if not honest:
		w -= 3
	if strange != "":
		w = int(round(w * 0.55))
	return maxi(8, w)


## The three asking at `kind`'s place today (decided by the day and the place, the same on
## every machine): [{slug, name, speed, honest, temper, strange, wage, refs}]. Those
## already working there do not ask again; the strange ones turn up now and then.
static func applicants(kind: String, key: String, day: int, taken: Array, seed := 0) -> Array:
	var pool: Array = []
	var odd: Array = []
	for slug in PEOPLE:
		if taken.has(slug) or not (PEOPLE[slug]["asks"] as Array).has(kind):
			continue
		if str(PEOPLE[slug].get("strange", "")) != "":
			odd.append(slug)
		else:
			pool.append(slug)
	pool.sort()
	var out: Array = []
	var h := absi(hash("%s|%s|%d|%d" % [kind, key, day, seed]))
	for i in mini(3, pool.size()):
		var j := (h / (i * 7 + 1) + i * 5) % pool.size()
		var slug: String = pool[j]
		pool.remove_at(j)
		out.append(person(slug, kind, seed))
	# Every fourth day or so one of the two nobody quite remembers is among them.
	if not odd.is_empty() and (h / 97) % 4 == 0:
		var s2: String = odd[(h / 389) % odd.size()]
		if out.size() >= 3:
			out[2] = person(s2, kind, seed)
		else:
			out.append(person(s2, kind, seed))
	return out


static func person(slug: String, kind: String, seed := 0) -> Dictionary:
	var t := traits(slug, kind, seed)
	t["slug"] = slug
	t["name"] = str((PEOPLE.get(slug, {}) as Dictionary).get("name", slug.capitalize()))
	t["refs"] = refs(slug, t)
	return t


## What their references say (the honesty is never said; a thief's papers are thin).
static func refs(slug: String, t: Dictionary) -> Array:
	var out: Array = [SPEED_WORD[clampi(int(t["speed"]), 0, 2)], str(TEMPER_WORD.get(str(t["temper"]), ""))]
	match str(t.get("strange", "")):
		"night":
			out.append("Has worked here before.")
		"unseen":
			out.append("References: (left blank)")
		_:
			if not bool(t["honest"]):
				out.append(["Between jobs.", "Left the last place in a hurry.", "Can start today. Today."][absi(hash(slug)) % 3])
			else:
				out.append(["Six years at the JZD canteen.", "References from the Lesna pub.", "Worked the season at Pelhrimov."][absi(hash(slug)) % 3])
	return out


## The pay for a shift: a late one costs more.
static func shift_pay(p: Dictionary) -> int:
	var w := int(p.get("wage", 0))
	return int(round(w * LATE_PAY)) if str(p.get("shift", "day")) == "late" else w


# ── how an order went down (Papa's) ──────────────────────────────────────────

## An order's score 0..100 from its parts (each 0..1, or -1 when it has none): the wait,
## the build (the right things and counts), the cooking (golden, hot, not burnt).
static func score(wait: float, build: float, cook := -1.0) -> int:
	var parts: Array = [[wait, 0.3], [build, 0.35], [cook, 0.35]]
	var total := 0.0
	var weight := 0.0
	for p in parts:
		if float(p[0]) < 0.0:
			continue
		total += clampf(float(p[0]), 0.0, 1.0) * float(p[1])
		weight += float(p[1])
	return int(round(100.0 * total / maxf(0.001, weight)))


## The tip and the stars a score earns, and the guest's mood after it.
static func reward(score_pts: int, price: int) -> Dictionary:
	var stars := 1 + (1 if score_pts >= 65 else 0) + (1 if score_pts >= 88 else 0)
	var tip := 0
	if score_pts >= 95:
		tip = maxi(2, int(round(price * 0.5)))
	elif score_pts >= 80:
		tip = maxi(1, int(round(price * 0.3)))
	elif score_pts >= 65:
		tip = 1
	var mood := -2.0 + score_pts / 100.0 * 5.0
	return {"stars": stars, "tip": tip, "mood": mood}


## A fresh shift's tally: orders, the score summed, tips, the best and the worst order.
static func empty_shift() -> Dictionary:
	return {"orders": 0, "score": 0, "tips": 0, "best": {}, "worst": {}, "waste": 0, "lost": 0, "by_hands": 0, "opened": -1}
