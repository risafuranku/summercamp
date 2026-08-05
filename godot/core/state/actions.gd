class_name GameActions
extends RefCounted

## Validates and executes actions that modify game state.
## Acts as a command pattern / transaction script.

const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")

var _state
var _registry
var _warned_legacy_end_day: bool = false

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


func remove_building(cell: Vector2i) -> bool:
	if _state.grid.is_cell_free(cell):
		return _remove_visual_tree(cell)
		
	var data = _state.grid.get_cell_data(cell)
	var instance_id = str(data.get("id", ""))
	var root = data.get("root_coord", cell)
	var type = data.get("type", "")
	
	# Calculate refund (simplified)
	var refund = _get_building_refund(type)
	
	# Execute
	# We need to find all cells with this instance ID to clear them
	# The GridModel doesn't have a reverse lookup yet, but we know the root and could store footprint?
	# For now, let's just clear the cell we clicked and maybe the root?
	# Better: Store footprint in GridModel data or look it up.
	# Let's simple-clear the root and let the visual system handle the rest for now, 
	# OR brute force clear neighbors that share ID.
	
	# Brute force clearing for now (GridModel is small enough usually)
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
	# Cost calculation: 20 money per building for the shift?
	# User request: "stojí peníze, zvýší maintenance všech budov o X (cap 1)"
	
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
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree = main_loop as SceneTree
		if scene_tree.root != null:
			return scene_tree.root.find_child("EconomyManager", true, false)
	return null


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
