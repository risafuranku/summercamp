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
	return _state.biz


## Co-op, the joining machine: every change to the businesses' books is told here too
## (main sends it to the host's camp, which keeps the books: kind, args). Money is not in
## it: that goes with the till.
var biz_remote: Callable


func _biz_tell(kind: String, args: Array) -> void:
	if biz_remote.is_valid():
		biz_remote.call(kind, args)


## The record of the business at `key` ("x:y"); made, shelves stocked, the first time.
func biz_site(key: String, building_type: String) -> Dictionary:
	var sites: Dictionary = _biz()["sites"]
	if not sites.has(key):
		var kind := BIZ_RULES.kind_of(building_type)
		if kind == "":
			return {}
		sites[key] = BIZ_RULES.new_site(kind)
	return sites[key]


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


## Takes goods off the shelf for a sale; false (nothing taken) when there is not enough.
func biz_take(key: String, needs: Dictionary) -> bool:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty() or not BIZ_RULES.can_take(site["stock"], needs):
		return false
	for g in needs:
		site["stock"][g] = int(site["stock"].get(g, 0)) - int(needs[g])
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


## Somebody went away unserved (out of stock, or nobody behind the counter).
func biz_lost(key: String) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if not site.is_empty():
		site["today"]["lost"] = int(site["today"]["lost"]) + 1
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


## Co-op, the host: an order the other warden paid for at their end (the money came with
## their till).
func biz_add_order(key: String, goods: Dictionary, cost: int, due_day: int) -> void:
	if not (_biz()["sites"] as Dictionary).has(key):
		return
	_biz()["orders"].append({"key": key, "goods": goods, "cost": cost, "due_day": due_day})
	EventBus.state_changed.emit({"biz": "ordered"})


## The van is unloaded: every order due by `day` goes on its shelves. Returns how many.
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
		var g_all: Dictionary = BIZ_RULES.goods(str(site["kind"]))
		for g in o["goods"]:
			var pack := int((g_all.get(g, {}) as Dictionary).get("pack", 1))
			var cap := int((g_all.get(g, {}) as Dictionary).get("cap", 9999))
			site["stock"][g] = mini(cap, int(site["stock"].get(g, 0)) + pack * int(o["goods"][g]))
		n += 1
	b["orders"] = keep
	if n > 0:
		EventBus.state_changed.emit({"biz": "delivered"})
	return n


## The van went away without anybody signing: what was due comes a day later.
func biz_postpone(day: int) -> void:
	for o in _biz()["orders"]:
		if int(o.get("due_day", 0)) <= day:
			o["due_day"] = day + 1


func biz_hire(key: String, name: String, day: int) -> bool:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty() or bool(site["staff"]):
		return false
	site["staff"] = true
	site["staff_name"] = name
	site["since_day"] = day
	EventBus.state_changed.emit({"biz": "hired"})
	_biz_tell("hire", [key, name, day])
	return true


func biz_fire(key: String) -> void:
	var site: Dictionary = (_biz()["sites"] as Dictionary).get(key, {})
	if site.is_empty():
		return
	site["staff"] = false
	site["staff_name"] = ""
	EventBus.state_changed.emit({"biz": "fired"})
	_biz_tell("fire", [key])


## The day ends: the hands are paid (all of it, even into the red: they want their
## money), today's books become yesterday's. Returns the wages paid.
func biz_close_day() -> int:
	var wages := 0
	for key in (_biz()["sites"] as Dictionary).keys():
		var site: Dictionary = _biz()["sites"][key]
		if bool(site["staff"]):
			wages += int(BIZ_RULES.info(str(site["kind"])).get("wage", 0))
		# The last week, for the office programs' charts.
		var history: Array = site.get("history", [])
		history.append(site["today"])
		while history.size() > 7:
			history.pop_front()
		site["history"] = history
		site["yesterday"] = site["today"]
		site["today"] = BIZ_RULES.empty_day()
	if wages > 0:
		_state.money -= wages
		EventBus.money_changed.emit(_state.money)
	return wages


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
