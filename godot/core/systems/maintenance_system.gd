class_name MaintenanceSystem
extends "res://core/systems/system_base.gd"

## The daily wear: only the lamps (MaintenanceRules.WEARS) grow weaker, by lamp_post's
## maintenance_decay a day, the lamps on paths too (their path cell's lamp_maintenance).

var _registry

func _init(registry) -> void:
	_registry = registry

func _on_setup() -> void:
	EventBus.day_tick.connect(_on_day_tick)

func _on_day_tick(_day: int) -> void:
	process_daily_costs()

func process_daily_costs() -> void:
	var lamp_def = _registry.get_def(&"lamp_post") if _registry != null else null
	var decay := float(lamp_def.maintenance_decay) if lamp_def != null else 0.06
	var grid = game_state.grid
	for coord in grid.lamp_coords():
		var cell: Dictionary = grid.cells[coord]
		if str(cell.get("type", "")) == "lamp_post":
			cell["maintenance"] = maxf(0.0, float(cell.get("maintenance", 1.0)) - decay)
		else:
			cell["lamp_maintenance"] = maxf(0.0, float(cell.get("lamp_maintenance", 1.0)) - decay)
		grid.cells[coord] = cell
	EventBus.state_changed.emit({"maintenance": "decayed"})
