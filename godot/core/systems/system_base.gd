class_name SystemBase
extends Node

## Base class for all gameplay systems.
## Handles localized logic and data processing.

# Reference to shared state (dependency injection)
var game_state

func setup(state) -> void:
    game_state = state
    _on_setup()

func _on_setup() -> void:
    # Override in child classes to subscribe to events
    pass

func update_logic(delta: float) -> void:
    # Override for frame-based logic if needed
    pass
