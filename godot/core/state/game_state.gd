class_name GameState
extends Resource

## Holds the runtime state of the game.
## Saved/Loaded via ResourceSaver/ResourceLoader.

# Core Resources
@export var money: int = 500
@export var day: int = 1
@export var is_night: bool = false

# Metrics
@export var karma: float = 0.0
@export var satisfaction: float = 50.0
@export var hrotfaktor: float = 0.0

# System Loads
@export var energy_load: float = 0.0
@export var infra_load: float = 0.0

@export var grid: Resource
@export var failures: Dictionary = {} # coord (String "x:y") -> failure_data (Dict)

# Guest simulation (data-only, no visual agents yet)
@export var guests: Array[Dictionary] = []
# coord key "x:y" -> {status, building_type, capacity, guest_ids}
@export var accommodation_states: Dictionary = {}
@export var guest_reviews: Array[Dictionary] = []
@export var guest_transactions: Array[Dictionary] = []
@export var next_guest_id: int = 1

func _init() -> void:
	# Dynamically load GridModel script
	var GridModelScript = load("res://core/state/grid_model.gd")
	grid = GridModelScript.new()
	failures = {}
	guests = []
	accommodation_states = {}
	guest_reviews = []
	guest_transactions = []
	next_guest_id = 1
	hrotfaktor = 0.0
