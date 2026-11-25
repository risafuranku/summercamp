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
# The fear the camp has worked up to, carried from night to night (core/systems/night_swell.gd).
@export var night_swell: float = 0.0

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
# The businesses (core/systems/business_rules.gd): {sites, orders, licences}
@export var biz: Dictionary = {}
## Buildings going up (core/systems/construction_rules.gd): origin "x:y" -> {type, rot, fp: [w, h],
## total, left (hours of work)}; their cells are a "site" till then.
@export var sites: Dictionary = {}
## A sandbox camp's land (core/systems/plot_rules.gd): {"rect": [x0, y0, x1, y1] ([] the whole
## camp), "bought": strips bought so far}; {} the whole camp.
@export var plot: Dictionary = {}
## A camp's goals and what its score counts (core/systems/goal_rules.gd, scripts/camp/goal_watch.gd):
## {"chosen": [ids], "done": {id: day}, "peak": the most guests at once, "safe": nights in a row
## without a lost guest, "safe_best"}.
@export var goals: Dictionary = {}
## Guests the camp lost in the night (actions.note_lost_guest): {name, day, archetype, room};
## the district's paper and police read it (os98 browser: the Courier, the search for them).
@export var lost_guests: Array[Dictionary] = []

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
	biz = {"sites": {}, "orders": [], "licences": []}
