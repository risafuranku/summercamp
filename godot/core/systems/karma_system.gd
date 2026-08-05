class_name KarmaSystem
extends RefCounted

## Pure function system for Karma calculations.
## Input: GridModel, BuildingRegistry, current overload
## Output: karma_delta (float)

static func calculate(grid, registry, energy_overload: float, infra_load: float) -> float:
	var delta: float = 0.0
	
	# 1. Base Karma from buildings
	for coord in grid.cells:
		var cell_data = grid.cells[coord]
		if cell_data.get("root_coord", coord) != coord:
			continue
			
		var building_id = cell_data.get("type")
		var def = registry.get_def(building_id)
		if not def:
			continue
			
		delta += def.karma_delta
		
	# 2. Penalty for Energy Overload
	# If energy load is high (> 0.8), start penalizing
	if energy_overload > 0.8:
		delta -= (energy_overload - 0.8) * 10.0 # Arbitrary multiplier
		
	# 3. Penalty for Darkness (Placeholder - would need checks for lights)
	# TODO: Implement darkness check
	
	# 4. Penalty for Low Maintenance (Placeholder)
	# TODO: Implement maintenance check
	
	return delta
