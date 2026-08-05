class_name FailureSystem
extends "res://core/systems/system_base.gd"

## core/systems/failure_system.gd
## Simulates building failures and malfunctions based on type and chance.

var _registry
var _rng := RandomNumberGenerator.new()
var _failure_timer: float = 0.0
var _base_interval: float = 18.0

func _init(registry) -> void:
	_registry = registry
	_rng.randomize()

func _on_setup() -> void:
	# Access state via game_state from SystemBase
	pass

func update(delta: float) -> void:
	if not game_state: return
	_failure_timer += delta
	var current_interval = _calculate_dynamic_interval()
	
	if _failure_timer >= current_interval:
		_failure_timer = 0.0
		_try_trigger_failure()

func _calculate_dynamic_interval() -> float:
	# More buildings = more frequent checks
	var b_count = game_state.grid.cells.size()
	return clamp(_base_interval - (float(b_count) * 0.1), 8.0, 30.0)

func _try_trigger_failure() -> void:
	var candidates = []
	for coord in game_state.grid.cells:
		var data = game_state.grid.cells[coord]
		var type = data.get("type", "")
		var inst_id = data.get("id", "")
		var root = data.get("root_coord", coord)
		
		# Only trigger on root cell of non-path buildings
		if coord != root or type == "path" or type == "main_building":
			continue
			
		var coord_str = "%d:%d" % [coord.x, coord.y]
		if game_state.failures.has(coord_str):
			continue
			
		candidates.append({"coord": coord, "type": type, "key": coord_str})

	if candidates.is_empty():
		return

	# Higher failure chance if maintenance is low
	var picked = candidates[_rng.randi() % candidates.size()]
	var maintenance = game_state.grid.cells[picked.coord].get("maintenance", 1.0)
	var failure_chance = 0.05 + (1.0 - maintenance) * 0.4
	
	if _rng.randf() < failure_chance:
		_trigger_failure(picked.key, picked.type, picked.coord)

func _trigger_failure(key: String, type: String, coord: Vector2i) -> void:
	var failure_data = {
		"type": type,
		"coord": coord,
		"since_day": game_state.day,
		"repair_progress": 0.0
	}
	game_state.failures[key] = failure_data
	EventBus.state_changed.emit({"failures": "new_failure"})
	# Legacy signal bridge if needed, but we aim for state_changed
	print("FailureSystem: Building %s at %s failed!" % [type, key])
