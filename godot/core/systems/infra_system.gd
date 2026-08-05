class_name InfraSystem
extends RefCounted

## Pure function system for Infrastructure calculations.
## Input: GridModel, BuildingRegistry
## Output: infra_load (float, absolute value)

static func calculate(grid, registry) -> float:
	var total_infra_load: float = 0.0
	
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
			
		total_infra_load += def.infra_load
		
	return total_infra_load
