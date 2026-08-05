extends Node

## res://modules/adapters/legacy_ui_adapter.gd
## Translates UI requests into central GameActions.

func purchase(building_id: String, origin: Vector2i, footprint: Vector2i, rotation: int) -> bool:
	return CoreRoot.actions.place_building(building_id, origin, footprint, rotation)

func demolish(origin: Vector2i) -> bool:
	return CoreRoot.actions.remove_building(origin)

func maintenance_shift(amount: float) -> bool:
	return CoreRoot.actions.maintenance_shift(amount)

func add_repair_progress(coord: Vector2i, amount: float) -> bool:
	return CoreRoot.actions.repair_building(coord, amount)
