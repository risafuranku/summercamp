class_name BusinessRules
extends RefCounted

## The camp's businesses as businesses (playtest 18. 10.): the pub, the bistro, the
## Jednota and the corn stand each keep goods on their shelves, sell them to the guests
## who come in, run out, and are restocked by the delivery van from what you order.
## Until you take somebody on, nobody serves: the guests who come in wait at the
## counter and you serve them yourself in the counter's minigame (scripts/food/*). A
## hand serves everybody who comes in, for a wage each day, a little slower and without
## the tips you would get.
##
## Pure data and arithmetic. The state is GameState.biz (actions.gd biz_*), the running
## side scripts/business/business_runtime.gd, the paper desk ledger_closeup.gd and the
## office PC's programs scripts/os98/apps/business_app.gd.
##
##   biz = {
##     "sites": {"x:y": {"kind", "stock": {good: n}, "staff": bool, "staff_name",
##               "since_day", "today": {sold, takings, lost, served_by_hand},
##               "yesterday": {...}}},
##     "orders": [{"key", "goods": {good: packs}, "cost", "due_day"}],
##     "licences": ["pub", ...],
##   }

## Building type -> business kind.
const KIND_OF := {"pub": "pub", "restaurant": "rest", "vecerka": "vecerka", "corn_stand": "corn"}

## Per kind: its name, the hand's wage a day, the PC program, and its goods:
##   good -> {label, unit, price (what a guest pays), pack (units per delivery pack),
##            pack_cost, cap (shelf space), start (on the shelf when it is built)}
const KINDS := {
	"pub": {
		"name": "Pub", "wage": 30, "hand": ["Lojza", "Franta", "Mirek"],
		"app": "pub_app", "app_name": "Hostinsky 98", "licence": 120,
		"goods": {
			"beer": {"label": "Beer", "unit": "pints", "price": 4, "pack": 50, "pack_cost": 60, "cap": 150, "start": 40},
			"rum": {"label": "Rum", "unit": "shots", "price": 3, "pack": 20, "pack_cost": 26, "cap": 60, "start": 10},
			"kofola": {"label": "Kofola", "unit": "glasses", "price": 2, "pack": 24, "pack_cost": 18, "cap": 72, "start": 12},
		},
		# What a visit takes, by the kind of guest (shares of a visit's appetite).
		"wants": {"beer": 0.7, "rum": 0.2, "kofola": 0.1},
	},
	"rest": {
		"name": "Bistro", "wage": 35, "hand": ["Mrs Dvorakova", "Pepa", "Hanka"],
		"app": "bistro_app", "app_name": "Kuchar 98", "licence": 140,
		"goods": {
			"goulash": {"label": "Goulash", "unit": "portions", "price": 7, "pack": 20, "pack_cost": 70, "cap": 60, "start": 12},
			"cheese": {"label": "Cheese", "unit": "slices", "price": 8, "pack": 20, "pack_cost": 64, "cap": 60, "start": 10},
			"potatoes": {"label": "Potatoes", "unit": "portions", "price": 3, "pack": 30, "pack_cost": 30, "cap": 90, "start": 20},
			"dumplings": {"label": "Dumplings", "unit": "plates", "price": 0, "pack": 30, "pack_cost": 24, "cap": 90, "start": 15},
		},
		"wants": {"goulash": 0.45, "cheese": 0.3, "potatoes": 0.25},
	},
	"vecerka": {
		"name": "Jednota", "wage": 25, "hand": ["Mrs Novakova", "Zdenka", "Ivan"],
		"app": "shop_app", "app_name": "Pult 98", "licence": 100,
		# The till's own goods (scripts/food/till_closeup.gd).
		"goods": {
			"bread": {"label": "Bread", "unit": "loaves", "price": 3, "pack": 20, "pack_cost": 30, "cap": 40, "start": 10},
			"roll": {"label": "Rolls", "unit": "rolls", "price": 1, "pack": 60, "pack_cost": 30, "cap": 120, "start": 40},
			"salami": {"label": "Salami", "unit": "sticks", "price": 4, "pack": 12, "pack_cost": 30, "cap": 36, "start": 6},
			"milk": {"label": "Milk", "unit": "bags", "price": 2, "pack": 24, "pack_cost": 28, "cap": 48, "start": 12},
			"pickles": {"label": "Pickles", "unit": "jars", "price": 3, "pack": 12, "pack_cost": 22, "cap": 36, "start": 6},
			"beer": {"label": "Lesnak", "unit": "bottles", "price": 2, "pack": 20, "pack_cost": 24, "cap": 60, "start": 20},
		},
		"wants": {"bread": 0.15, "roll": 0.3, "salami": 0.1, "milk": 0.2, "pickles": 0.07, "beer": 0.18},
	},
	"corn": {
		"name": "Corn stand", "wage": 15, "hand": ["Pepicek", "Klara", "the Novak boy"],
		"app": "corn_app", "app_name": "Klasek 98", "licence": 60,
		"goods": {
			"cobs": {"label": "Corn cobs", "unit": "cobs", "price": 2, "pack": 40, "pack_cost": 32, "cap": 80, "start": 20},
			"butter": {"label": "Butter", "unit": "knobs", "price": 0, "pack": 60, "pack_cost": 15, "cap": 120, "start": 30},
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


## A new site's record, the shelves stocked to start with.
static func new_site(kind: String) -> Dictionary:
	var stock := {}
	for g in goods(kind):
		stock[g] = int(goods(kind)[g]["start"])
	return {"kind": kind, "stock": stock, "staff": false, "staff_name": "", "since_day": 0,
		"today": empty_day(), "yesterday": empty_day()}


static func empty_day() -> Dictionary:
	return {"sold": 0, "takings": 0, "lost": 0, "by_hand": 0}


## The cost of an order (goods: {good: packs}), the van's fee included.
static func order_cost(kind: String, order: Dictionary) -> int:
	var total := 0
	for g in order:
		var d: Dictionary = goods(kind).get(g, {})
		total += int(d.get("pack_cost", 0)) * int(order[g])
	return total + (DELIVERY_FEE if total > 0 else 0)


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
