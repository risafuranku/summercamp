class_name MaintenanceSystem
extends "res://core/systems/system_base.gd"

## Handles daily maintenance costs and building degradation.

var _registry

func _init(registry) -> void:
	_registry = registry

func _on_setup() -> void:
	EventBus.day_tick.connect(_on_day_tick)

func _on_day_tick(_day: int) -> void:
	process_daily_costs()

func process_daily_costs() -> void:
	# Degrade buildings based on their Def
	# We iterate grid cells. Since building spans multiple cells, we should be careful not to apply multiple times if we iterate naive.
	# But data is per-cell in GridModel currently.
	# Best approach: Iterate cells, track processed InstanceIDs.
	
	var processed_ids = {}
	var grid = game_state.grid
	
	for coord in grid.cells:
		var data = grid.cells[coord]
		var instance_id = data.get("id", "")
		if instance_id == "" or processed_ids.has(instance_id):
			continue
			
		processed_ids[instance_id] = true
		
		# Get Def
		var type_id = data.get("type", "")
		var def = _registry.get_def(type_id)
		if def:
			var decay = def.maintenance_decay
			if decay > 0.0:
				# Apply decay to ALL cells of this building
				# We don't have a quick "get all cells for id" in GridModel, so we might have to iterate again or ensure we hit them.
				# Actually, for data consistency, we should update all cells that share this ID.
				# Since we are iterating all cells anyway, let's just apply to current cell? 
				# NO, data is duplicated in occupy_cell. We must update all of them or have a shared ref.
				# Implementation detail: GridModel copies value. We must update all cells for this building.
				_apply_decay_to_building(instance_id, decay)
				
	EventBus.state_changed.emit({"maintenance": "decayed"})

func _apply_decay_to_building(instance_id: String, amount: float) -> void:
	for coord in game_state.grid.cells:
		var data = game_state.grid.cells[coord]
		if data.get("id") == instance_id:
			var current = data.get("maintenance", 1.0)
			data.maintenance = max(0.0, current - amount)
