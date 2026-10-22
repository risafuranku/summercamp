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
const KIND_OF := {"pub": "pub", "restaurant": "rest", "vecerka": "vecerka", "corn_stand": "corn", "bowling": "bowl"}

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
			# The grill, the bufet (bistro_rules: the sausage, the soup of the day, the big
			# drinks in glass bottles).
			"sausage": {"label": "Sausages", "unit": "sausages", "price": 6, "pack": 20, "pack_cost": 46, "cap": 60, "start": 10, "life": 5},
			"bread": {"label": "Rye bread", "unit": "slices", "price": 0, "pack": 40, "pack_cost": 10, "cap": 80, "start": 20, "life": 2},
			"soup": {"label": "Soup tins", "unit": "bowls", "price": 3, "pack": 30, "pack_cost": 24, "cap": 90, "start": 20, "life": 0},
			"kofola": {"label": "Kofola", "unit": "bottles", "price": 3, "pack": 20, "pack_cost": 20, "cap": 60, "start": 20, "life": 0},
			"malinovka": {"label": "Malinovka", "unit": "bottles", "price": 3, "pack": 20, "pack_cost": 18, "cap": 60, "start": 20, "life": 0},
			# Bought ready, half as dear again (the brief of 21. 10.: the cellar is optional):
			# they go onto the cellar's trays by themselves (kitchen._prepared).
			"chips_cut": {"label": "Cut chips (ready)", "unit": "portions", "price": 0, "pack": 30, "pack_cost": 45, "cap": 60, "start": 0, "life": 3},
			"cheese_breaded": {"label": "Breaded cheese (ready)", "unit": "slices", "price": 0, "pack": 20, "pack_cost": 96, "cap": 40, "start": 0, "life": 4},
		},
		"wants": {"goulash": 0.3, "cheese": 0.2, "potatoes": 0.15, "sausage": 0.15, "soup": 0.1, "kofola": 0.1},
	},
	"vecerka": {
		"name": "Jednota", "wage": 40, "hand": ["Mrs Novakova", "Zdenka", "Ivan"],
		"app": "shop_app", "app_name": "Pult 98", "licence": 220,
		# The village shop the guests love (DESIGN.md §7b, the Jednota): everything they
		# need, dear to build, stock and staff; it pays back in a fortnight of a busy camp
		# (jednota_rules.day_model, tools/jednota_check).
		"goods": {
			"bread": {"label": "Bread", "unit": "loaves", "price": 5, "pack": 20, "pack_cost": 46, "cap": 40, "start": 10, "life": 2},
			"roll": {"label": "Rolls", "unit": "rolls", "price": 2, "pack": 60, "pack_cost": 38, "cap": 120, "start": 40, "life": 2},
			"salami": {"label": "Salami", "unit": "sticks", "price": 8, "pack": 12, "pack_cost": 40, "cap": 36, "start": 6, "life": 8},
			"milk": {"label": "Milk", "unit": "bottles", "price": 4, "pack": 24, "pack_cost": 34, "cap": 48, "start": 12, "life": 3},
			"pickles": {"label": "Pickles", "unit": "jars", "price": 4, "pack": 12, "pack_cost": 26, "cap": 36, "start": 6, "life": 0},
			"beer": {"label": "Lesnak", "unit": "bottles", "price": 4, "pack": 20, "pack_cost": 28, "cap": 60, "start": 20, "life": 0},
			"icecream": {"label": "Ice cream", "unit": "bars", "price": 4, "pack": 24, "pack_cost": 30, "cap": 48, "start": 12, "life": 0},
			"sweets": {"label": "Sweets", "unit": "bars", "price": 3, "pack": 40, "pack_cost": 26, "cap": 80, "start": 20, "life": 0},
			"veg": {"label": "Fruit and veg", "unit": "heads", "price": 4, "pack": 20, "pack_cost": 24, "cap": 40, "start": 10, "life": 4},
			"soap": {"label": "Soap and paper", "unit": "packs", "price": 5, "pack": 12, "pack_cost": 22, "cap": 24, "start": 6, "life": 0},
			# The brief of 20. 10.: the fun (cards, magazines), the rum, the cigarettes behind
			# the till; the deli counter's salami, cheese and bread by the kilo.
			"cards": {"label": "Playing cards", "unit": "packs", "price": 4, "pack": 10, "pack_cost": 18, "cap": 20, "start": 6, "life": 0},
			"magazine": {"label": "Magazines", "unit": "copies", "price": 2, "pack": 20, "pack_cost": 16, "cap": 30, "start": 10, "life": 7},
			"rum": {"label": "Tuzemak", "unit": "bottles", "price": 9, "pack": 12, "pack_cost": 54, "cap": 24, "start": 6, "life": 0},
			"cigs": {"label": "Cigarettes", "unit": "packs", "price": 3, "pack": 40, "pack_cost": 70, "cap": 80, "start": 20, "life": 0},
			"deli_salami": {"label": "Salami (deli)", "unit": "kg", "price": 30, "pack": 4, "pack_cost": 48, "cap": 12, "start": 3, "life": 8},
			"deli_cheese": {"label": "Cheese (deli)", "unit": "kg", "price": 20, "pack": 4, "pack_cost": 34, "cap": 12, "start": 3, "life": 10},
			"deli_bread": {"label": "Bread (deli)", "unit": "kg", "price": 10, "pack": 6, "pack_cost": 18, "cap": 12, "start": 4, "life": 2},
		},
		"wants": {"bread": 0.08, "roll": 0.14, "salami": 0.06, "milk": 0.1, "pickles": 0.04, "beer": 0.12, "icecream": 0.1, "sweets": 0.08, "veg": 0.06, "soap": 0.05, "cards": 0.03, "magazine": 0.04, "rum": 0.04, "cigs": 0.06},
	},
	"corn": {
		"name": "Corn stand", "wage": 15, "hand": ["Pepicek", "Klara", "the Novak boy"],
		"app": "corn_app", "app_name": "Klasek 98", "licence": 60,
		"goods": {
			"cobs": {"label": "Corn cobs", "unit": "cobs", "price": 2, "pack": 40, "pack_cost": 32, "cap": 80, "start": 20, "life": 4},
			"butter": {"label": "Butter", "unit": "knobs", "price": 0, "pack": 60, "pack_cost": 15, "cap": 120, "start": 30, "life": 6},
			# The small drinks (corn_rules.DRINKS): the barrel of iced tea in cups, the
			# lemonade in bags off the big bottles.
			"tea": {"label": "Iced tea", "unit": "cups", "price": 1, "pack": 60, "pack_cost": 12, "cap": 120, "start": 30, "life": 3},
			"limo": {"label": "Lemonade", "unit": "bags", "price": 1, "pack": 36, "pack_cost": 9, "cap": 72, "start": 18, "life": 0},
		},
		"wants": {"cobs": 0.7, "tea": 0.15, "limo": 0.15},
	},
	# The bowling alley (scripts/bowling/): the lanes and the shoes are no goods (a game and
	# a pair are paid at the counter, bowling.gd); the snack bar's are, and the spray the
	# shoes get before they go back on the shelf.
	"bowl": {
		"name": "Bowling", "wage": 32, "hand": ["the Novak boy", "Franta", "Ivan"],
		"app": "bowl_app", "app_name": "Bowling 98", "licence": 160,
		"goods": {
			"sausage": {"label": "Sausages", "unit": "sausages", "price": 5, "pack": 20, "pack_cost": 40, "cap": 60, "start": 20, "life": 5},
			"roll": {"label": "Rolls", "unit": "rolls", "price": 0, "pack": 40, "pack_cost": 14, "cap": 80, "start": 30, "life": 2},
			"pickled": {"label": "Utopenci", "unit": "jars", "price": 4, "pack": 12, "pack_cost": 22, "cap": 36, "start": 8, "life": 0},
			"crisps": {"label": "Crisps", "unit": "bags", "price": 2, "pack": 30, "pack_cost": 24, "cap": 60, "start": 20, "life": 0},
			"tatranka": {"label": "Tatranka", "unit": "bars", "price": 1, "pack": 40, "pack_cost": 16, "cap": 80, "start": 30, "life": 0},
			"kofola": {"label": "Kofola", "unit": "bottles", "price": 2, "pack": 20, "pack_cost": 18, "cap": 60, "start": 20, "life": 0},
			"beer": {"label": "Beer", "unit": "pints", "price": 3, "pack": 50, "pack_cost": 60, "cap": 100, "start": 40, "life": 6},
			"spray": {"label": "Shoe spray", "unit": "sprays", "price": 0, "pack": 40, "pack_cost": 12, "cap": 80, "start": 30, "life": 0},
		},
		"wants": {"beer": 0.35, "kofola": 0.2, "sausage": 0.2, "crisps": 0.15, "pickled": 0.05, "tatranka": 0.05},
	},
	# The staffroom's hands (core/systems/staff_rules.gd): no shelves, no building of this
	# kind (not in KIND_OF); here for the wage, the program and its licence.
	"staff": {
		"name": "Staffroom", "wage": 28, "hand": [],
		"app": "staff_app", "app_name": "Personal 98", "licence": 90,
		"goods": {},
		"wants": {},
	},
}
## What a dish or a drink takes off the shelf (the counter games' names).
const RECIPES := {
	"rest": {"goulash": {"goulash": 1, "dumplings": 1}, "smazak": {"cheese": 1, "potatoes": 1}, "fries": {"potatoes": 1},
		"sausage": {"sausage": 1, "bread": 1}, "soup": {"soup": 1}, "kofola": {"kofola": 1}, "malinovka": {"malinovka": 1}},
	"corn": {"cob": {"cobs": 1, "butter": 1}, "tea": {"tea": 1}, "limo": {"limo": 1}},
	"bowl": {"hotdog": {"sausage": 1, "roll": 1}, "pickled": {"pickled": 1}, "crisps": {"crisps": 1}, "tatranka": {"tatranka": 1},
		"kofola": {"kofola": 1}, "beer": {"beer": 1}},
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
	if kind == "bowl" and out.has("sausage"):
		out["roll"] = int(out.get("roll", 0)) + int(out["sausage"])
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
			var chips := int(stock.get("potatoes", 0)) + int(stock.get("chips_cut", 0))
			out["smazak"] = int(stock.get("cheese", 0)) + int(stock.get("cheese_breaded", 0)) > 0 and chips > 0
			out["fries"] = chips > 0
			out["sausage"] = int(stock.get("sausage", 0)) > 0 and int(stock.get("bread", 0)) > 0
			out["soup"] = int(stock.get("soup", 0)) > 0
			out["kofola"] = int(stock.get("kofola", 0)) > 0 or int(stock.get("malinovka", 0)) > 0
		"pub":
			out["beer"] = int(stock.get("beer", 0)) > 0
			out["rum"] = int(stock.get("rum", 0)) > 0
			out["kofola"] = int(stock.get("kofola", 0)) > 0
		"corn":
			out["cob"] = int(stock.get("cobs", 0)) > 0
			out["tea"] = int(stock.get("tea", 0)) > 0
			out["limo"] = int(stock.get("limo", 0)) > 0
		"vecerka":
			for g in goods(kind):
				out[g] = int(stock.get(g, 0)) > 0
		"bowl":
			out["hotdog"] = int(stock.get("sausage", 0)) > 0 and int(stock.get("roll", 0)) > 0
			for g in ["pickled", "crisps", "tatranka", "kofola", "beer"]:
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
	"bowl": {
		"machine": {"label": "Stavomat S-12", "price": 900, "what": "A pinsetting machine: sets the pins on all four lanes by itself. Now and then something gets caught in its gears down in the cellar, and everything stops."},
		"brnoswick": {"label": "Brnoswick A-2", "price": 2400, "what": "A pinsetting machine like the American ones. Quicker than the Stavomat, and it never jams.", "needs": "machine"},
		"scoreboard": {"label": "Score screens", "price": 380, "what": "The scores up on screens over the lanes: the guests like it."},
		"dryer": {"label": "Shoe dryer", "price": 160, "what": "The shoes come back dry and fresh: no spraying at the counter."},
	},
}


static func gear_list(kind: String) -> Dictionary:
	return GEAR.get(kind, {})


static func has_gear(site: Dictionary, id: String) -> bool:
	return (site.get("gear", []) as Array).has(id)


## The gear a piece needs in first ("" none: the Brnoswick replaces the Stavomat).
static func gear_needs(kind: String, id: String) -> String:
	return str((gear_list(kind).get(id, {}) as Dictionary).get("needs", ""))


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
	"rest": [["pass", "Pass"], ["floor", "Floor"], ["stove", "Stove"], ["cellar", "Cellar"], ["sink", "Sink"], ["grill", "Grill"], ["bufet", "Soup"]],
	"pub": [["tap", "Tap"], ["bar", "Back bar"], ["wash", "Washer"], ["cellar", "Cellar"]],
	"corn": [["counter", "Counter"], ["husk", "Husking"], ["drinks", "Drinks"]],
	"vecerka": [["till", "Till"], ["shelves", "Shelves"], ["store", "Storeroom"], ["deli", "Deli counter"], ["till2", "Second till"]],
	"bowl": [["desk", "Counter"], ["pins", "Pinsetter"], ["bufet", "Snack bar"]],
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
	"dvorakova": {"name": "Mrs Dvorakova", "asks": ["rest", "vecerka", "staff"]},
	"pepa": {"name": "Pepa", "asks": ["rest", "pub"]},
	"hanka": {"name": "Hanka", "asks": ["rest", "pub", "vecerka", "staff", "bowl"]},
	"lojza": {"name": "Lojza", "asks": ["pub"]},
	"franta": {"name": "Franta", "asks": ["pub", "corn", "bowl"]},
	"mirek": {"name": "Mirek", "asks": ["pub", "rest", "vecerka", "staff"]},
	"novakova": {"name": "Mrs Novakova", "asks": ["vecerka"]},
	"zdenka": {"name": "Zdenka", "asks": ["vecerka", "rest", "staff"]},
	"ivan": {"name": "Ivan", "asks": ["vecerka", "pub", "staff", "bowl"]},
	"pepicek": {"name": "Pepicek", "asks": ["corn", "vecerka"]},
	"klara": {"name": "Klara", "asks": ["corn", "rest"]},
	"novak_boy": {"name": "the Novak boy", "asks": ["corn", "bowl"]},
	"jaromir": {"name": "Jaromir", "asks": ["rest", "pub", "vecerka", "staff", "bowl"], "strange": "night"},
	"marta": {"name": "Marta", "asks": ["vecerka", "rest", "corn", "staff"], "strange": "unseen"},
}
## The speeds: seconds a hand takes over one piece of work, and how often it goes wrong.
const SPEED_SEC := [9.0, 6.0, 4.0]
const SPEED_SLIP := [0.14, 0.08, 0.05]
const SPEED_WORD := ["Takes their time.", "Steady.", "Quick on their feet."]
const TEMPER_WORD := {"warm": "Talks to everybody.", "flat": "Keeps to themselves.", "sour": "Not much of a smile."}
## What a hand's temper does to the mood of the guest they serve (business_runtime
## .hand_mood): a warm one is worth a word, a sour one costs it.
const TEMPER_MOOD := {"warm": 0.4, "flat": 0.0, "sour": -0.6}
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
	# The staffroom takes anyone for the brooms and the bins: when those who ask for it are
	# all taken by the businesses, the others not in work come too (its list was empty:
	# playtest 21. 10.).
	if kind == "staff" and pool.size() < 3:
		var more: Array = []
		for slug in PEOPLE:
			if not taken.has(slug) and not pool.has(slug) and str(PEOPLE[slug].get("strange", "")) == "":
				more.append(slug)
		more.sort()
		pool.append_array(more)
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
	return {"orders": 0, "score": 0, "tips": 0, "stars": 0, "cost": 0.0, "best": {}, "worst": {}, "waste": 0, "lost": 0, "by_hands": 0, "opened": -1}


## What one unit of a good costs off the van (its pack's price over the pack).
static func unit_cost(kind: String, good: String) -> float:
	var d: Dictionary = goods(kind).get(good, {})
	return float(d.get("pack_cost", 0)) / float(maxi(1, int(d.get("pack", 1))))


## The shift's mark on the Z report (the brief of 20. 10.: "the grade of the day and what
## to do better, short and spurring on"): A to E from how the orders went, how many were
## served of those who came, and whether it paid; and the one thing to mend first.
static func day_grade(z: Dictionary) -> Dictionary:
	var n := int(z.get("orders", 0))
	var lost := int(z.get("lost", 0))
	if n <= 0 and lost <= 0:
		return {"grade": "-", "advice": "Nobody came. Open in the evening rush."}
	var avg := float(z.get("score", 0)) / float(maxi(1, n))
	var served := float(n) / float(maxi(1, n + lost))
	var profit := int(z.get("takings", 0)) - int(z.get("wages", 0)) - int(round(float(z.get("cost", 0.0))))
	var pts := avg * 0.55 + served * 45.0 - (8.0 if profit < 0 else 0.0)
	var grade := "E"
	for g in [["A", 86.0], ["B", 74.0], ["C", 62.0], ["D", 50.0]]:
		if pts >= float(g[1]):
			grade = str(g[0])
			break
	var advice := "A good shift. Same again tomorrow."
	if served < 0.75:
		advice = "Too many went away unserved. Another pair of hands for the rush."
	elif avg < 60.0:
		var worst: Dictionary = z.get("worst", {})
		advice = "The orders went out poor. Mind the %s." % str(worst.get("what", "orders")).to_lower() if not worst.is_empty() else "The orders went out poor."
	elif int(z.get("waste", 0)) > 6:
		advice = "Too much went off. Order less, more often."
	elif profit < 0:
		advice = "The wages ate the takings. Fewer hands, or more guests."
	elif grade == "A":
		advice = "The best in the district. Keep it so."
	return {"grade": grade, "advice": advice}


# ── Papa's frame (the brief of 21. 10.) ──────────────────────────────────────

## The menu of each place (the books' MENU page): what can be switched off so the guests
## do not order it ([id, label, the place's own: never off]). Nothing to unlock: only
## switches. The tickets of each place leave out what is off.
const MENU := {
	"corn": [["cob", "Corn on the cob", true], ["tea", "Iced tea", false], ["limo", "Lemonade in a bag", false]],
	"pub": [["beer", "Draught beer", true], ["rum", "Rum", false], ["zelena", "Zelena", false], ["slivovice", "Slivovice", false], ["kofola", "Kofola", false]],
	"rest": [["smazak", "Fried cheese", true], ["fries", "Chips", false], ["goulash", "Goulash and dumplings", false], ["sausage", "Grilled sausage", false], ["soup", "Soup of the day", false], ["drinks", "Bottled drinks", false]],
	"vecerka": [["bread", "Bread and rolls", true], ["salami", "Salami", false], ["milk", "Milk", false], ["pickles", "Pickles", false], ["beer", "Beer", false], ["icecream", "Ice cream", false],
		["sweets", "Sweets", false], ["veg", "Fruit and veg", false], ["soap", "Soap and paper", false], ["cards", "Playing cards", false], ["magazine", "Magazines", false],
		["rum", "Tuzemak", false], ["cigs", "Cigarettes", false], ["deli", "The deli counter", false]],
	"bowl": [["games", "Lanes and shoes", true], ["hotdog", "Hot dog", false], ["pickled", "Utopenec", false], ["crisps", "Crisps", false],
		["tatranka", "Tatranka", false], ["kofola", "Kofola", false], ["beer", "Draught beer", false]],
}
## What a menu switch covers when it is not the item's own name (the Jednota's bread is the
## rolls too, its deli all three cuts; the pub's beer is all three pours).
const MENU_COVERS := {
	"vecerka": {"roll": "bread", "deli_salami": "deli", "deli_cheese": "deli", "deli_bread": "deli"},
	"pub": {"hladinka": "beer", "snyt": "beer", "mliko": "beer"},
	"rest": {"kofola": "drinks", "malinovka": "drinks"},
	"bowl": {"sausage": "hotdog", "roll": "hotdog"},
}


## Whether `item` (a dish, a drink, a good) is on the menu of a place (`site`: its books).
static func menu_on(kind: String, site: Dictionary, item: String) -> bool:
	var sw := str((MENU_COVERS.get(kind, {}) as Dictionary).get(item, item))
	for row in MENU.get(kind, []):
		if str(row[0]) == sw and bool(row[2]):
			return true
	return not (site.get("menu_off", []) as Array).has(sw)


## Last orders this long (game minutes) before a place shuts: the bell, and nobody new
## orders; who already ordered waits to the end of their patience, past the closing hour.
const LAST_ORDERS_MIN := 30


## The minute of the day of last orders: the day shift's, or the late shift's.
static func last_orders_at(late: bool) -> int:
	return (LATE_CLOSE if late else DAY_CLOSE) * 60 - LAST_ORDERS_MIN


## A run of good orders (Papa's combo): from three in a row, a little on top of the tip,
## more the longer the run (the money the stand gets for a cob is two dollars: a dollar).
const COMBO_FROM := 3


static func combo_bonus(combo: int, price: int) -> int:
	if combo < COMBO_FROM:
		return 0
	return maxi(1, int(round(float(price) * 0.1 * float(mini(combo - COMBO_FROM + 1, 5)))))


## The shift's mark so far (the frame shows it all the time): A to E from the orders served
## and who went away unserved, and the average stars. {grade, stars (0..3), orders}.
static func shift_mark(shift: Dictionary) -> Dictionary:
	var n := int(shift.get("orders", 0))
	var lost := int(shift.get("lost", 0))
	if n <= 0 and lost <= 0:
		return {"grade": "-", "stars": 0.0, "orders": 0}
	var avg := float(shift.get("score", 0)) / float(maxi(1, n))
	var served := float(n) / float(maxi(1, n + lost))
	var pts := avg * 0.55 + served * 45.0
	var grade := "E"
	for g in [["A", 86.0], ["B", 74.0], ["C", 62.0], ["D", 50.0]]:
		if pts >= float(g[1]):
			grade = str(g[0])
			break
	return {"grade": grade, "stars": float(shift.get("stars", 0)) / float(maxi(1, n)), "orders": n}
