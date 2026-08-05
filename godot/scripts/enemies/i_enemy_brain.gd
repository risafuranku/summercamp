extends RefCounted
class_name IEnemyBrain


func get_enemy_id() -> String:
	return "unknown"


func start_night(_seed: int, _difficulty: int, _references: Dictionary) -> void:
	pass


func tick(_delta: float) -> void:
	pass


func stop_night() -> void:
	pass


func get_debug_snapshot() -> Dictionary:
	return {}
