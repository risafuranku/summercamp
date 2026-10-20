class_name GameActions
extends RefCounted

## Validates and executes actions that modify game state.
## Acts as a command pattern / transaction script.

const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")

var _state
var _registry
var _warned_legacy_end_day: bool = false
# Cached because _get_building_cost() runs once per cell during demolish previews;
# an uncached find_child(recursive) there walks the whole scene tree per building.
var _economy_manager_cache: Node = null

func _init(state, registry) -> void:
	_state = state
	_registry = registry

func place_building(building_id: String, origin: Vector2i, footprint: Vector2i = Vector2i(1, 1), rotation: int = 0) -> bool:
	# 1. Validate Funds
	var cost = _get_building_cost(building_id)
	
	if _state.money < cost:
		return false

	# 2. Validate Space
	for y in range(footprint.y):
		for x in range(footprint.x):
			var tile = origin + Vector2i(x, y)
			if not _state.grid.is_cell_free(tile):
				return false
			# TODO: Check map bounds (requires map size access or simple check)
			# For now assuming caller (UI) checks bounds or we add map size to GridModel

	# 3. Execute
	_state.money -= cost
	
	var instance_id = str(Time.get_ticks_msec()) + "_" + str(randi()) # Simple unique ID for now
	
	for y in range(footprint.y):
		for x in range(footprint.x):
			var tile = origin + Vector2i(x, y)
			_state.grid.occupy_cell(tile, building_id, instance_id, origin)
	
	# 4. Notify
	# EventBus should be global
	EventBus.building_placed.emit(building_id, origin, footprint, rotation)
	EventBus.money_changed.emit(_state.money)
	
	return true


## An upgrade in place (tent_1 -> tent_2, cabin_1 -> cabin_2): same footprint, same
## instance, new type. Money is handled by the upgrade menu.
func retype_building(origin: Vector2i, new_type: String) -> bool:
	var data: Dictionary = _state.grid.get_cell_data(origin)
	if data.is_empty():
		return false
	var instance_id := str(data.get("id", ""))
	var root = data.get("root_coord", origin)
	var changed := false
	for c in _state.grid.cells:
		var cell_data: Dictionary = _state.grid.cells[c]
		var same: bool = (str(cell_data.get("id", "")) == instance_id) if instance_id != "" else (cell_data.get("root_coord", c) == root)
		if same:
			cell_data["type"] = new_type
			_state.grid.cells[c] = cell_data
			changed = true
	return changed


func remove_building(cell: Vector2i) -> bool:
	if _state.grid.is_cell_free(cell):
		return _remove_visual_tree(cell)
		
	var data = _state.grid.get_cell_data(cell)
	var instance_id = str(data.get("id", ""))
	var root = data.get("root_coord", cell)
	var type = data.get("type", "")
	
	var refund = _get_building_refund(type)

	# GridModel has no instance_id -> cells reverse index, so sweep the whole grid to
	# collect every cell of this footprint. Fine at 20x20; add an index if the map grows.
	var cells_to_clear: Array = []
	for c in _state.grid.cells:
		var cell_data = _state.grid.cells[c] as Dictionary
		if instance_id != "":
			if str(cell_data.get("id", "")) == instance_id:
				cells_to_clear.append(c)
		else:
			# Legacy fallback for pre-refactor data that may miss instance IDs.
			if cell_data.get("root_coord", c) == root and str(cell_data.get("type", "")) == str(type):
				cells_to_clear.append(c)
			
	for c in cells_to_clear:
		_state.grid.free_cell(c)
		
	_state.money += refund
	
	# Notify
	EventBus.building_removed.emit(root)
	EventBus.money_changed.emit(_state.money)
	
	return true


func maintenance_shift(amount: float) -> bool:
	# Costs money, raises maintenance on every building by `amount` (capped at 1.0).
	var unique_buildings_count = 0 
	var visited_ids = {}
	
	# Count unique buildings for cost
	for coord in _state.grid.cells:
		var data = _state.grid.cells[coord]
		var id = data.get("id", "")
		if id != "" and not visited_ids.has(id):
			visited_ids[id] = true
			unique_buildings_count += 1
			
	if unique_buildings_count == 0:
		return false
		
	var cost_per_building = 20 # Arbitrary simple cost for now
	var total_cost = unique_buildings_count * cost_per_building
	
	if _state.money < total_cost:
		return false
		
	_state.money -= total_cost
	
	# Apply maintenance to ALL cells (simplifies lookup)
	for coord in _state.grid.cells:
		var data = _state.grid.cells[coord] as Dictionary
		if data.has("maintenance"):
			var current = float(data.get("maintenance", 1.0))
			data["maintenance"] = min(1.0, current + amount)
			_state.grid.cells[coord] = data
			
	EventBus.state_changed.emit({"maintenance" : "shifted"})
	EventBus.money_changed.emit(_state.money)
	
	return true

func spend_money(amount: int) -> bool:
	if _state.money < amount:
		return false
	_state.money -= amount
	EventBus.money_changed.emit(_state.money)
	return true


func add_money(amount: int) -> void:
	_state.money += amount
	EventBus.money_changed.emit(_state.money)


# ── the businesses (core/systems/business_rules.gd) ──────────────────────────

const BIZ_RULES := preload("res://core/systems/business_rules.gd")


func _biz() -> Dictionary:
	if not (_state.biz is Dictionary) or _state.biz.is_empty():
		_state.biz = {"sites": {}, "orders": [], "licences": []}
	for k in ["sites", "orders", "licences"]:
		if not _state.biz.has(k):
			_state.biz[k] = {} if k == "sites" else []
	# The books' stamp: another camp's books, another stamp (saved with them), so what the
	# places keep in memory (the kitchen's pans, the shop's rack) goes with the camp.
	if int(_state.biz.get("stamp", 0)) == 0:
		_state.biz["stamp"] = 1 + randi() % 1000000000
	return _state.biz


## Co-op, the joining machine: every change to the businesses' books is told here too
## (main sends it to the host's camp, which keeps the books: kind, args). Money is not in
## it: that goes with the till.
var biz_remote: Callable


func _biz_tell(kind: String, args: Array) -> void:
	if biz_remote.is_valid():
		biz_remote.call(kind, args)


## The record of the business at `key` ("x:y"); made, shelves stocked, the first time. An
## older save's record gets what it lacks (the lots dated today, its one hand as a person).
func biz_site(key: String, building_type: String) -> Dictionary:
	var sites: Dictionary = _biz()["sites"]
	var kind := BIZ_RULES.kind_of(building_type)
	# Another kind of place stands there now than the books knew: its own books.
	if sites.has(key) and kind != "" and str((sites[key] as Dictionary).get("kind", kind)) != kind:
		sites.erase(key)
	if not sites.has(key):
		if kind == "":
			return {}
		sites[key] = BIZ_RULES.new_site(kind, maxi(1, int(_state.day)))
	_biz_upgrade(sites[key])
	return sites[key]


## What an older record lacks (saves before 20. 10.).
func _biz_upgrade(site: Dictionary) -> void:
	if site.has("crew") and site.has("lots"):
		return
	var kind := str(site.get("kind", ""))
	var day := maxi(1, int(_state.day))
	if not site.has("lots"):
		var lots := {}
		for g in (site.get("stock", {}) as Dictionary):
			var n := int(site["stock"][g])
			lots[g] = [[n, day]] if n > 0 else []
		site["lots"] = lots
	for k in ["spoiled", "shift"]:
		if not site.has(k):
			site[k] = {} if k == "spoiled" else BIZ_RULES.empty_shift()
	for k in ["gear", "crew"]:
		if not site.has(k):
			site[k] = []
	if not site.has("late"):
		site["late"] = false
	# The one hand of the old books: a person at the front job, by day.
	if bool(site.get("staff", false)) and (site["crew"] as Array).is_empty():
		var name := str(site.get("staff_name", ""))
		var slug := ""
		for s in BIZ_RULES.PEOPLE:
			if str(BIZ_RULES.PEOPLE[s]["name"]) == name:
				slug = str(s)
		if slug != "":
			var p := BIZ_RULES.person(slug, kind)
			p["role"] = BIZ_RULES.front(kind)
			p["shift"] = "day"
			p["since"] = int(site.get("since_day", day))
			site["crew"].append(p)
	for k in ["waste", "short"]:
		for d in ["today", "yesterday"]:
			if site.get(d, {}) is Dictionary and not (site[d] as Dictionary).has(k):
				site[d][k] = 0


## Sites whose building is gone go with it (their orders too, refunded).
func biz_prune(live_keys: Array) -> void:
	var b := _biz()
	for key in (b["sites"] as Dictionary).keys():
		if not live_keys.has(key):
			b["sites"].erase(key)
	var keep: Array = []
	for o in b["orders"]:
		if live_keys.has(str(o.get("key", ""))):
			keep.append(o)
		else:
			add_money(int(o.get("cost", 0)))
	b["orders"] = keep


## Takes goods off the shelf for a sale (the oldest first); false (nothing taken) when
## there is not enough.
func biz_take(key: String, needs: Dictionary) -> bool:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty() or not BIZ_RULES.can_take(site["stock"], needs):
		return false
	_biz_upgrade(site)
	for g in needs:
		site["stock"][g] = int(site["stock"].get(g, 0)) - int(needs[g])
		site["lots"][g] = BIZ_RULES.lots_take(site["lots"].get(g, []), int(needs[g]))
	_biz_tell("take", [key, needs])
	return true


## A sale rung up: the money is the camp's, the day's books count it.
func biz_sale(key: String, amount: int, units: int, by_hand: bool, credit := true) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	var day: Dictionary = site["today"]
	day["sold"] = int(day["sold"]) + units
	day["takings"] = int(day["takings"]) + amount
	if by_hand:
		day["by_hand"] = int(day["by_hand"]) + 1
	if amount > 0 and credit:
		add_money(amount)
	_biz_tell("sale", [key, amount, units, by_hand])


## The bistro's kitchen as it stands (scripts/bistro/kitchen.gd: the trays, the pot, the
## plates), kept with the books for the save. The host's: the other machine's kitchen
## follows its own ops.
func biz_kitchen(key: String, data: Dictionary) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if not site.is_empty():
		site["kitchen"] = data.duplicate(true)


## The pub's tap as it stands (scripts/pub/taproom.gd: the keg on the line, the gas, the
## mugs), kept with the books for the save. The host's: the other machines follow its ops.
func biz_tap(key: String, data: Dictionary) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if not site.is_empty():
		site["tap"] = data.duplicate(true)


## A place's own record of something it keeps (the corn stand's pot, the Jednota's
## shelves and queue), with the books for the save.
func biz_keep(key: String, what: String, data) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if not site.is_empty():
		site[what] = data.duplicate(true) if (data is Dictionary or data is Array) else data


## Somebody went away unserved (out of stock, or nobody behind the counter).
func biz_lost(key: String) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if not site.is_empty():
		site["today"]["lost"] = int(site["today"]["lost"]) + 1
		if site.get("shift", {}) is Dictionary and not (site["shift"] as Dictionary).is_empty():
			site["shift"]["lost"] = int(site["shift"].get("lost", 0)) + 1
		_biz_tell("lost", [key])


## An order for the van (goods: {good: packs}), paid now, delivered on `due_day`.
func biz_order(key: String, order: Dictionary, due_day: int) -> bool:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return false
	var clean := {}
	for g in order:
		if int(order[g]) > 0:
			clean[g] = int(order[g])
	if clean.is_empty():
		return false
	var cost := BIZ_RULES.order_cost(str(site["kind"]), clean)
	if not spend_money(cost):
		return false
	_biz()["orders"].append({"key": key, "goods": clean, "cost": cost, "due_day": due_day})
	EventBus.state_changed.emit({"biz": "ordered"})
	_biz_tell("order", [key, clean, cost, due_day])
	return true


## One order for every place at once (the office PC's program): {key: {good: packs}}, one
## van and one fee for the lot. False (nothing ordered) when the camp cannot pay it.
func biz_order_all(orders: Dictionary, due_day: int) -> bool:
	var lines: Array = []
	var total := 0
	for key in orders:
		var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
		if site.is_empty():
			continue
		var clean := {}
		for g in (orders[key] as Dictionary):
			if int(orders[key][g]) > 0:
				clean[g] = int(orders[key][g])
		if clean.is_empty():
			continue
		var cost := BIZ_RULES.goods_cost(str(site["kind"]), clean)
		lines.append([str(key), clean, cost])
		total += cost
	if lines.is_empty():
		return false
	total += BIZ_RULES.DELIVERY_FEE
	if not spend_money(total):
		return false
	# The van's fee goes on the first line (one van).
	lines[0][2] = int(lines[0][2]) + BIZ_RULES.DELIVERY_FEE
	for l in lines:
		_biz()["orders"].append({"key": str(l[0]), "goods": l[1], "cost": int(l[2]), "due_day": due_day})
		_biz_tell("order", [str(l[0]), l[1], int(l[2]), due_day])
	EventBus.state_changed.emit({"biz": "ordered"})
	return true


## Co-op, the host: an order the other warden paid for at their end (the money came with
## their till).
func biz_add_order(key: String, goods: Dictionary, cost: int, due_day: int) -> void:
	if not (_biz()["sites"] as Dictionary).has(key):
		return
	_biz()["orders"].append({"key": key, "goods": goods, "cost": cost, "due_day": due_day})
	EventBus.state_changed.emit({"biz": "ordered"})


## The van is unloaded: every order due by `day` goes on its shelves, a lot dated today.
## Returns how many.
func biz_receive(day: int) -> int:
	var b := _biz()
	var keep: Array = []
	var n := 0
	for o in b["orders"]:
		if int(o.get("due_day", 0)) > day:
			keep.append(o)
			continue
		var site: Dictionary = (b["sites"] as Dictionary).get(str(o.get("key", "")), {})
		if site.is_empty():
			continue
		_biz_upgrade(site)
		var kind := str(site["kind"])
		var g_all: Dictionary = BIZ_RULES.goods(kind)
		for g in o["goods"]:
			var pack := int((g_all.get(g, {}) as Dictionary).get("pack", 1))
			var cap := BIZ_RULES.cap_of(kind, str(g), site)
			var before := int(site["stock"].get(g, 0))
			var after := mini(cap, before + pack * int(o["goods"][g]))
			site["stock"][g] = after
			if after > before:
				var lots: Array = site["lots"].get(g, [])
				lots.append([after - before, day])
				site["lots"][g] = lots
		n += 1
	b["orders"] = keep
	if n > 0:
		EventBus.state_changed.emit({"biz": "delivered"})
	return n


## Goods that came with no order and no bill (the bistro cellar's machine): onto the shelf
## as a lot of today's, as much as the shelf takes. The books do not say from where.
func biz_gift(key: String, goods: Dictionary) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	_biz_upgrade(site)
	var kind := str(site["kind"])
	var day := maxi(1, int(_state.day))
	for g in goods:
		var before := int(site["stock"].get(g, 0))
		var after := mini(BIZ_RULES.cap_of(kind, str(g), site), before + int(goods[g]))
		if after <= before:
			continue
		site["stock"][g] = after
		var lots: Array = site["lots"].get(g, [])
		lots.append([after - before, day])
		site["lots"][g] = lots
	EventBus.state_changed.emit({"biz": "gift"})
	_biz_tell("gift", [key, goods])


## The van went away without anybody signing: what was due comes a day later.
func biz_postpone(day: int) -> void:
	for o in _biz()["orders"]:
		if int(o.get("due_day", 0)) <= day:
			o["due_day"] = day + 1


## The morning: what has been on the shelves too long goes off (it stays there, bad, till
## somebody throws it out: biz_bin). Returns [{key, good, n}].
func biz_spoil(day: int) -> Array:
	var out: Array = []
	for key in (_biz()["sites"] as Dictionary):
		var site: Dictionary = _biz()["sites"][key]
		_biz_upgrade(site)
		var kind := str(site["kind"])
		for g in (site["lots"] as Dictionary).keys():
			var days := BIZ_RULES.life_of(kind, str(g), site)
			if days <= 0:
				continue
			var kept: Array = []
			var off := 0
			for lot in site["lots"][g]:
				if day - int(lot[1]) >= days:
					off += int(lot[0])
				else:
					kept.append(lot)
			if off <= 0:
				continue
			site["lots"][g] = kept
			site["stock"][g] = maxi(0, int(site["stock"].get(g, 0)) - off)
			site["spoiled"][g] = int(site["spoiled"].get(g, 0)) + off
			out.append({"key": str(key), "good": str(g), "n": off})
	if not out.is_empty():
		EventBus.state_changed.emit({"biz": "spoiled"})
	return out


## What went off is thrown out (the books count it as waste). Returns the units.
func biz_bin(key: String) -> int:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return 0
	_biz_upgrade(site)
	var n := 0
	for g in site["spoiled"]:
		n += int(site["spoiled"][g])
	if n <= 0:
		return 0
	site["spoiled"] = {}
	site["today"]["waste"] = int(site["today"].get("waste", 0)) + n
	site["shift"]["waste"] = int(site["shift"].get("waste", 0)) + n
	EventBus.state_changed.emit({"biz": "binned"})
	_biz_tell("bin", [key])
	return n


## Goods thrown out whole from the shelf (a flat keg down the drain): off the stock, the
## oldest first, the books count them as waste. Returns the units.
func biz_waste(key: String, goods: Dictionary) -> int:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return 0
	_biz_upgrade(site)
	var n := 0
	for g in goods:
		var k := mini(int(goods[g]), int(site["stock"].get(g, 0)))
		if k <= 0:
			continue
		site["stock"][g] = int(site["stock"].get(g, 0)) - k
		site["lots"][g] = BIZ_RULES.lots_take(site["lots"].get(g, []), k)
		n += k
	if n <= 0:
		return 0
	site["today"]["waste"] = int(site["today"].get("waste", 0)) + n
	site["shift"]["waste"] = int(site["shift"].get("waste", 0)) + n
	EventBus.state_changed.emit({"biz": "binned"})
	_biz_tell("waste", [key, goods])
	return n


## Gear for a place (the only progression), paid now.
func biz_buy_gear(key: String, id: String) -> bool:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return false
	_biz_upgrade(site)
	var g: Dictionary = BIZ_RULES.gear_list(str(site["kind"])).get(id, {})
	if g.is_empty() or (site["gear"] as Array).has(id):
		return false
	if not spend_money(int(g["price"])):
		return false
	site["gear"].append(id)
	EventBus.state_changed.emit({"biz": "gear"})
	_biz_tell("gear", [key, id])
	return true


## Co-op, the host: gear the other warden paid for at their end.
func biz_add_gear(key: String, id: String) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	_biz_upgrade(site)
	if not (site["gear"] as Array).has(id):
		site["gear"].append(id)
		EventBus.state_changed.emit({"biz": "gear"})


## Takes a person on (one of the day's applicants: BusinessRules.person) for a job and a
## shift ("day" or "late").
func biz_hire(key: String, person: Dictionary, day: int) -> bool:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty() or person.is_empty():
		return false
	_biz_upgrade(site)
	for p in site["crew"]:
		if str(p.get("slug", "")) == str(person.get("slug", "")):
			return false
	var p2 := person.duplicate(true)
	p2["since"] = day
	if not p2.has("role"):
		p2["role"] = _free_role(site)
	if not p2.has("shift"):
		p2["shift"] = "day"
	site["crew"].append(p2)
	EventBus.state_changed.emit({"biz": "hired"})
	_biz_tell("hire", [key, p2, day])
	return true


## The first job nobody has (the front first), or the front again.
func _free_role(site: Dictionary) -> String:
	var taken := {}
	for p in site["crew"]:
		taken["%s/%s" % [str(p.get("role", "")), str(p.get("shift", "day"))]] = true
	for r in BIZ_RULES.ROLES.get(str(site["kind"]), []):
		if not taken.has("%s/day" % str(r[0])):
			return str(r[0])
	return BIZ_RULES.front(str(site["kind"]))


## Lets a person go (by their slug; "" the last taken on).
func biz_fire(key: String, slug := "") -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	_biz_upgrade(site)
	var crew: Array = site["crew"]
	for i in range(crew.size() - 1, -1, -1):
		if slug == "" or str(crew[i].get("slug", "")) == slug:
			crew.remove_at(i)
			break
	EventBus.state_changed.emit({"biz": "fired"})
	_biz_tell("fire", [key, slug])


## A person's job and shift.
func biz_set_job(key: String, slug: String, role: String, shift: String) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	_biz_upgrade(site)
	for p in site["crew"]:
		if str(p.get("slug", "")) == slug:
			p["role"] = role
			p["shift"] = shift
	EventBus.state_changed.emit({"biz": "job"})
	_biz_tell("job", [key, slug, role, shift])


## A crew member's record changed by the running side (absent today, owed, the photo of
## the one whose face will not hold still): `fields` merged in.
func biz_crew_note(key: String, slug: String, fields: Dictionary) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	for p in site.get("crew", []):
		if str(p.get("slug", "")) == slug:
			for f in fields:
				p[f] = fields[f]


## The place open in the evening (after 20:00, till 23:00) or not.
func biz_set_late(key: String, on: bool) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	site["late"] = on
	EventBus.state_changed.emit({"biz": "late"})
	_biz_tell("late", [key, on])


## Who covers the front job now (business_runtime works it out each second): `staff`
## true when somebody does (the place serves without you), and their name.
func biz_staffed(key: String, on: bool, name: String) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	site["staff"] = on
	site["staff_name"] = name


## An order rung out (Papa's): its score into this shift's tally. rec: {score, tip,
## what (the dish), who (the guest), hand (a hand served it)}.
func biz_score(key: String, rec: Dictionary) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	_biz_upgrade(site)
	var sh: Dictionary = site["shift"]
	sh["orders"] = int(sh.get("orders", 0)) + 1
	sh["score"] = int(sh.get("score", 0)) + int(rec.get("score", 0))
	sh["tips"] = int(sh.get("tips", 0)) + int(rec.get("tip", 0))
	if bool(rec.get("hand", false)):
		sh["by_hands"] = int(sh.get("by_hands", 0)) + 1
	var best: Dictionary = sh.get("best", {})
	if best.is_empty() or int(rec.get("score", 0)) > int(best.get("score", -1)):
		sh["best"] = rec.duplicate()
	var worst: Dictionary = sh.get("worst", {})
	if worst.is_empty() or int(rec.get("score", 0)) < int(worst.get("score", 101)):
		sh["worst"] = rec.duplicate()
	# The place's running average, for the books.
	site["all_orders"] = int(site.get("all_orders", 0)) + 1
	site["all_score"] = int(site.get("all_score", 0)) + int(rec.get("score", 0))
	_biz_tell("score", [key, rec])


## The shift ends: its tally becomes the Z report (wages and waste in it), a new one
## starts. Returns the report.
func biz_close_shift(key: String, wages: int, day: int, late: bool) -> Dictionary:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return {}
	_biz_upgrade(site)
	var z: Dictionary = (site["shift"] as Dictionary).duplicate(true)
	z["wages"] = wages
	z["day"] = day
	z["late"] = late
	z["takings"] = int(site["today"].get("takings", 0))
	z["kind"] = str(site["kind"])
	site["zreport"] = z
	site["zreport_read"] = false
	site["shift"] = BIZ_RULES.empty_shift()
	return z


## Somebody's hand in the till or on the shelf (a dishonest hand): money or goods short.
func biz_short(key: String, money: int, good := "", n := 0) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	if money > 0:
		_state.money -= money
		EventBus.money_changed.emit(_state.money)
	if good != "" and n > 0 and int(site["stock"].get(good, 0)) >= n:
		site["stock"][good] = int(site["stock"][good]) - n
		site["lots"][good] = BIZ_RULES.lots_take(site["lots"].get(good, []), n)
	site["today"]["short"] = int(site["today"].get("short", 0)) + money + n


## The day ends: the hands who came in are paid for their shift (a late one costs more);
## whoever the camp cannot pay is owed it, and after two days unpaid they leave. Today's
## books become yesterday's. Returns {wages, left: [names]}.
func biz_close_day(day := -1) -> Dictionary:
	var wages := 0
	var left: Array = []
	for key in (_biz()["sites"] as Dictionary).keys():
		var site: Dictionary = _biz()["sites"][key]
		_biz_upgrade(site)
		var crew: Array = site["crew"]
		for i in range(crew.size() - 1, -1, -1):
			var p: Dictionary = crew[i]
			if day >= 0 and int(p.get("absent", -1)) == day:
				continue
			var due := BIZ_RULES.shift_pay(p) + int(p.get("owed", 0))
			if _state.money >= due:
				_state.money -= due
				wages += due
				p["owed"] = 0
				p["unpaid"] = 0
			else:
				p["owed"] = due
				p["unpaid"] = int(p.get("unpaid", 0)) + 1
				if int(p["unpaid"]) >= 2:
					left.append(str(p.get("name", "A hand")))
					crew.remove_at(i)
		# The last week, for the office programs' charts.
		var history: Array = site.get("history", [])
		history.append(site["today"])
		while history.size() > 7:
			history.pop_front()
		site["history"] = history
		site["yesterday"] = site["today"]
		site["today"] = BIZ_RULES.empty_day()
	if wages > 0:
		EventBus.money_changed.emit(_state.money)
	return {"wages": wages, "left": left}


## A program for the office PC, bought on the web.
func biz_buy_licence(kind: String) -> bool:
	var b := _biz()
	if (b["licences"] as Array).has(kind):
		return true
	if not spend_money(int(BIZ_RULES.info(kind).get("licence", 0))):
		return false
	b["licences"].append(kind)
	return true


func biz_has_licence(kind: String) -> bool:
	return (_biz()["licences"] as Array).has(kind)


func end_day(income: int) -> void:
	if not _warned_legacy_end_day:
		_warned_legacy_end_day = true
		push_warning("GameActions.end_day() is legacy and bypasses canonical day_tick flow. Prefer EventBus.day_tick path.")
	_state.day += 1
	_state.money += income
	
	EventBus.day_advanced.emit(_state.day, income)
	EventBus.money_changed.emit(_state.money)
	EventBus.state_changed.emit({"day": _state.day, "money": _state.money})


## UI Helper: Calculates consequences of demolishing a rectangle.
func get_demolish_summary(rect: Rect2i) -> Dictionary:
	var targets = []
	var seen_ids = {}
	var seen_tree_roots = {}
	var refund_total = 0
	var blocked_main = 0
	
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var coord = Vector2i(x, y)
			if _state.grid.cells.has(coord):
				var data = _state.grid.cells[coord]
				var inst_id = data.get("id", "")
				if inst_id != "" and not seen_ids.has(inst_id):
					var type = data.get("type", "")
					if type == "main_building":
						blocked_main += 1
					else:
						seen_ids[inst_id] = true
						targets.append({"origin": data.get("root_coord", coord), "type": type})
						refund_total += _get_building_refund(type)

			var tree_root = _resolve_visual_occupant_root(_state.grid.get_occupant(coord))
			if tree_root == null or not tree_root.is_in_group("trees"):
				continue
			var tree_id = int(tree_root.get_instance_id())
			if seen_tree_roots.has(tree_id):
				continue
			seen_tree_roots[tree_id] = true
			targets.append({"origin": coord, "type": "tree"})
				
	var area = rect.size.x * rect.size.y
	var fee = area * 4 # DEMOLISH_FEE_PER_TILE from map panel
	
	return {
		"area_tiles": area,
		"target_count": targets.size(),
		"blocked_main": blocked_main,
		"refund_total": refund_total,
		"fee_total": fee,
		"net_total": refund_total - fee,
		"targets": targets
	}

## Services (or, if broken, repairs) the building at `coord`, paying `cost`. Restores
## condition to 100% on every cell of the building and clears its failure.
## Returns false, changing nothing, if there is no building or not enough money.
func service_building(coord: Vector2i, cost: int) -> bool:
	if not _state.grid.cells.has(coord):
		return false
	var root: Vector2i = _state.grid.cells[coord].get("root_coord", coord)
	if not _state.grid.cells.has(root):
		return false
	if _state.money < cost:
		return false
	var inst_id := str(_state.grid.cells[root].get("id", ""))
	var type := str(_state.grid.cells[root].get("type", ""))
	var key := "%d:%d" % [root.x, root.y]
	var was_broken: bool = _state.failures.has(key)
	_state.money -= maxi(0, cost)
	_state.failures.erase(key)
	# A lamp on a path: its bulb is the path cell's lamp_maintenance.
	if type == "path" and bool(_state.grid.cells[root].get("lamp", false)):
		var lamp_cell: Dictionary = _state.grid.cells[root]
		lamp_cell["lamp_maintenance"] = 1.0
		_state.grid.cells[root] = lamp_cell
		EventBus.money_changed.emit(_state.money)
		EventBus.state_changed.emit({"maintenance": "serviced", "failures": "repaired" if was_broken else ""})
		EventBus.building_serviced.emit(root, "lamp_post", was_broken, cost)
		return true
	for c in _state.grid.cells:
		var cell_data = _state.grid.cells[c] as Dictionary
		if str(cell_data.get("id", "")) == inst_id:
			cell_data["maintenance"] = 1.0
			_state.grid.cells[c] = cell_data
	EventBus.money_changed.emit(_state.money)
	EventBus.state_changed.emit({"maintenance": "serviced", "failures": "repaired" if was_broken else ""})
	EventBus.building_serviced.emit(root, type, was_broken, cost)
	return true


## Takes the wear off a building that no longer wears (old saves, from before only the
## lamps did): full condition, no breakdown, nothing charged or announced.
func clear_wear(coord: Vector2i) -> void:
	if not _state.grid.cells.has(coord):
		return
	var root: Vector2i = _state.grid.cells[coord].get("root_coord", coord)
	var inst_id := str(_state.grid.cells.get(root, {}).get("id", ""))
	_state.failures.erase("%d:%d" % [root.x, root.y])
	for c in _state.grid.cells:
		var cell_data = _state.grid.cells[c] as Dictionary
		if inst_id != "" and str(cell_data.get("id", "")) == inst_id:
			cell_data["maintenance"] = 1.0
			_state.grid.cells[c] = cell_data
	EventBus.state_changed.emit({"maintenance": "cleared"})


func repair_building(coord: Vector2i, amount: float) -> bool:
	var key = "%d:%d" % [coord.x, coord.y]
	if not _state.failures.has(key):
		return false
		
	var failure = _state.failures[key]
	failure.repair_progress = min(1.0, failure.repair_progress + amount)
	
	if failure.repair_progress >= 1.0:
		_state.failures.erase(key)
		# Restore maintenance to full on success
		if _state.grid.cells.has(coord):
			var inst_id = str(_state.grid.cells[coord].get("id", ""))
			for c in _state.grid.cells:
				var cell_data = _state.grid.cells[c] as Dictionary
				if str(cell_data.get("id", "")) == inst_id:
					cell_data["maintenance"] = 1.0
					_state.grid.cells[c] = cell_data
					
		EventBus.state_changed.emit({"failures": "repaired"})
	else:
		EventBus.state_changed.emit({"failures": "progress"})
		
	return true


func _get_building_cost(building_id: String) -> int:
	if _registry != null:
		var def = _registry.get_def(building_id)
		if def != null:
			return int(def.cost)
	if building_id == "path":
		return 10

	var econ = _find_economy_manager()
	if econ != null and econ.has_method("get_cost"):
		return int(econ.get_cost(building_id))
	return 0


func _get_building_refund(building_id: String) -> int:
	var cost = _get_building_cost(building_id)
	if cost <= 0:
		return 0
	return int(cost * BALANCE_CONFIG.REFUND_RATIO)


func _find_economy_manager() -> Node:
	if _economy_manager_cache != null and is_instance_valid(_economy_manager_cache):
		return _economy_manager_cache
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree = main_loop as SceneTree
		if scene_tree.root != null:
			_economy_manager_cache = scene_tree.root.find_child("EconomyManager", true, false)
	return _economy_manager_cache


func _remove_visual_tree(cell: Vector2i) -> bool:
	var tree_root = _resolve_visual_occupant_root(_state.grid.get_occupant(cell))
	if tree_root == null or not tree_root.is_in_group("trees"):
		return false

	var coords_to_clear: Array = []
	for coord in _state.grid.occupants:
		if _state.grid.occupants[coord] == tree_root:
			coords_to_clear.append(coord)

	if coords_to_clear.is_empty():
		coords_to_clear.append(cell)

	for coord in coords_to_clear:
		_state.grid.set_tile_occupied(coord, false, null)

	tree_root.queue_free()
	return true


func _resolve_visual_occupant_root(occupant: Variant) -> Node:
	if occupant == null:
		return null
	var node = occupant as Node
	if node == null:
		return null
	if node.has_meta("grid_origin"):
		return node
	var current = node.get_parent()
	while current != null:
		if current.has_meta("grid_origin"):
			return current
		current = current.get_parent()
	return node
