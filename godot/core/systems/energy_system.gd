class_name EnergySystem
extends RefCounted

## Pure function system for Energy calculations.
## Input: GridModel, BuildingRegistry
## Output: energy_load (0.0 - 1.0)

static func calculate(grid, registry) -> float:
	var total_draw: float = 0.0
	var total_capacity: float = 0.0
	
	# Iterate all placed buildings
	for coord in grid.cells:
		var cell_data = grid.cells[coord]
		# Only process root cells to avoid double counting
		if cell_data.get("root_coord", coord) != coord:
			continue
			
		var building_id = cell_data.get("type")
		var def = registry.get_def(building_id)
		if not def:
			continue
			
		total_draw += def.power_draw
		total_capacity += def.power_production
		
	# Avoid division by zero
	if total_capacity <= 0.001:
		# If we have draw but no capacity, it's 100% overload (or maybe more? clamped to 1.0 for now)
		# If total_draw is 0 and capacity is 0, load is 0.
		return 1.0 if total_draw > 0.001 else 0.0
		
	return clampf(total_draw / total_capacity, 0.0, 1.0)
