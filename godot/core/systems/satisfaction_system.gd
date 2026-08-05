class_name SatisfactionSystem
extends RefCounted

## Pure function system for Satisfaction calculations.
## Input: GridModel, BuildingRegistry, global penalties
## Output: satisfaction (0.0 - 1.0)

static func calculate(grid, registry) -> float:
	var total_base_satisfaction: float = 0.5 # Starting at 50%
	
	# We need to find housing units to calculate average satisfaction
	var housing_count: int = 0
	var total_housing_satisfaction: float = 0.0
	
	# Pre-cache buildings for faster lookup
	# coord -> { def: BuildingDef, id: String }
	var placed_buildings = {}
	var service_buildings = [] # List of { coord: Vector2i, def: BuildingDef }
	
	for coord in grid.cells:
		var cell_data = grid.cells[coord]
		if cell_data.get("root_coord", coord) != coord:
			continue
			
		var building_id = cell_data.get("type")
		var def = registry.get_def(building_id)
		if not def:
			continue
			
		placed_buildings[coord] = { "def": def, "id": building_id }
		
		# Identify services (buildings with radius > 0 usually)
		if def.radius > 0 and (def.hygiene_delta > 0 or def.fun_delta > 0):
			service_buildings.append({ "coord": coord, "def": def })
			
	# Iterate housing to calculate individual satisfaction
	for coord in placed_buildings:
		var entry = placed_buildings[coord]
		var def = entry["def"]
		
		# Check if it's housing (category 'housing' or similar tag)
		if def.category == "housing" or "housing" in def.tags:
			housing_count += 1
			
			var current_housing_score = 0.5 # Base
			
			# Check nearby services
			# Simple distance check for now
			for service in service_buildings:
				var dist = Vector2(coord).distance_to(Vector2(service["coord"]))
				if dist <= service["def"].radius:
					# Apply effects
					# Diminishing returns could be added here
					current_housing_score += service["def"].hygiene_delta * 0.1
					current_housing_score += service["def"].fun_delta * 0.1
			
			total_housing_satisfaction += clampf(current_housing_score, 0.0, 1.0)
			
	if housing_count == 0:
		return 0.5 # Default if no housing
		
	return clampf(total_housing_satisfaction / float(housing_count), 0.0, 1.0)
