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


## Where the player could sense this enemy right now: {"position": Vector3}, or {} when
## there is nothing to sense. A visible body, or the place its last sound came from.
## Feeds the insects falling silent and the HUD face's eyes (scripts/threat_senses.gd).
func get_presence() -> Dictionary:
	return {}
