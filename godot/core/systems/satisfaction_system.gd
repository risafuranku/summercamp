class_name SatisfactionSystem
extends RefCounted

## Pure function system for Satisfaction calculations.
## Input: GridModel, BuildingRegistry
## Output: satisfaction on a 0-100 scale.
##
## SCALE CONTRACT: `GameState.satisfaction` is 0-100 (default 50.0). Every consumer
## (guest reviews, save snapshots, guest trouble penalties) assumes that range.
## Returning 0-1 here silently pinned every guest review to 1 star -- do not change
## the scale without updating `GuestManager._build_review_for_guest()` as well.

const NEUTRAL_SATISFACTION: float = 50.0

## Category / tag names that mark a building as guest housing.
const HOUSING_CATEGORIES: Array[StringName] = [&"housing", &"accommodation"]


static func calculate(grid, registry) -> float:
	# coord -> BuildingDef of every root cell we can resolve
	var placed_buildings: Dictionary = {}
	# Buildings that project a comfort effect over a radius.
	var service_buildings: Array = []

	for coord in grid.cells:
		var cell_data = grid.cells[coord]
		# Only process root cells to avoid double counting multi-tile footprints.
		if cell_data.get("root_coord", coord) != coord:
			continue

		var def = registry.get_def(cell_data.get("type"))
		if def == null:
			continue

		placed_buildings[coord] = def

		if def.radius > 0 and (def.hygiene_delta > 0.0 or def.fun_delta > 0.0):
			service_buildings.append({"coord": coord, "def": def})

	var housing_count: int = 0
	var total_housing_satisfaction: float = 0.0

	for coord in placed_buildings:
		var def = placed_buildings[coord]
		if not _is_housing(def):
			continue

		housing_count += 1
		var score := NEUTRAL_SATISFACTION

		for service in service_buildings:
			var radius: float = float(service["def"].radius)
			if Vector2(coord).distance_to(Vector2(service["coord"])) > radius:
				continue
			# hygiene/fun deltas are authored on a per-point scale; 1 point == 1 satisfaction.
			score += service["def"].hygiene_delta
			score += service["def"].fun_delta

		total_housing_satisfaction += clampf(score, 0.0, 100.0)

	if housing_count == 0:
		return NEUTRAL_SATISFACTION

	return clampf(total_housing_satisfaction / float(housing_count), 0.0, 100.0)


static func _is_housing(def) -> bool:
	if def.category in HOUSING_CATEGORIES:
		return true
	for tag in def.tags:
		if StringName(tag) in HOUSING_CATEGORIES:
			return true
	return false
