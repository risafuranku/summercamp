class_name FailureSystem
extends "res://core/systems/system_base.gd"

## Breakdowns. Once per in-game hour every building that can break rolls against
## MaintenanceRules.hazard_per_hour(condition): above 50% condition nothing breaks,
## below it the odds climb. A broken building is listed in GameState.failures, stops
## serving guests, and announces itself through EventBus.building_failed.
##
## Runs only while `enabled` (main.gd switches it on for play). It used to run in the
## main menu too, breaking the preview camp, and it rolled a flat 5% even on buildings
## in perfect condition, so neglect and bad luck were indistinguishable.

const RULES = preload("res://core/systems/maintenance_rules.gd")
const ROLL_EVERY_MINUTES := 60.0

var enabled: bool = false
var _registry
var _rng := RandomNumberGenerator.new()
var _minutes: float = 0.0


func _init(registry) -> void:
	_registry = registry
	_rng.randomize()


func _on_setup() -> void:
	pass


## `delta` in real seconds; at TIME_SCALE 1.0 that is game minutes.
func update(delta: float) -> void:
	if not enabled or game_state == null or game_state.grid == null:
		return
	_minutes += delta
	if _minutes < ROLL_EVERY_MINUTES:
		return
	_minutes -= ROLL_EVERY_MINUTES
	roll_hour()


## One hour of breakdown rolls. Public so harnesses can drive it directly.
func roll_hour() -> void:
	for coord_any in game_state.grid.cells.keys():
		var coord: Vector2i = coord_any
		var data: Dictionary = game_state.grid.cells[coord]
		if data.get("root_coord", coord) != coord:
			continue
		var type := str(data.get("type", ""))
		var def = _registry.get_def(StringName(type)) if _registry != null else null
		if not RULES.can_break(type, def):
			continue
		var key := "%d:%d" % [coord.x, coord.y]
		if game_state.failures.has(key):
			continue
		var condition := float(data.get("maintenance", 1.0))
		if _rng.randf() < RULES.hazard_per_hour(condition):
			_trigger_failure(key, type, coord)


func _trigger_failure(key: String, type: String, coord: Vector2i) -> void:
	game_state.failures[key] = {
		"type": type,
		"coord": coord,
		"since_day": game_state.day,
		"repair_progress": 0.0,
	}
	EventBus.state_changed.emit({"failures": "new_failure"})
	EventBus.building_failed.emit(coord, type)
