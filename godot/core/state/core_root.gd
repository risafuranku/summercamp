extends Node

## Helper for accessing GameState as a singleton.
## Registers itself as an Autoload named "CoreRoot".

signal state_changed(changes: Dictionary)

# The single source of truth for runtime state
var _state
var state:
	get:
		return _state
var actions
var maintenance_system: Node
var failure_system: Node
var builder_authority: Node
var registry: Node

# Cached scripts for dynamic invocation (bypasses class_name issues)
var _BalanceConfig
var _EnergySystem
var _InfraSystem
var _SatisfactionSystem
var _KarmaSystem

func _ready() -> void:
	# Initialize Registry
	# Load Scripts Dynamically
	var BuildingRegistryScript = load("res://core/data/building_registry.gd")
	registry = BuildingRegistryScript.new()
	add_child(registry)  # BuildingRegistry._ready() performs load_all()

	var GameStateScript = load("res://core/state/game_state.gd")
	_state = GameStateScript.new()
	
	var GameActionsScript = load("res://core/state/actions.gd")
	actions = GameActionsScript.new(_state, registry)
	
	var MaintenanceSystemScript = load("res://core/systems/maintenance_system.gd")
	maintenance_system = MaintenanceSystemScript.new(registry)
	add_child(maintenance_system)
	maintenance_system.setup(_state)
	
	var FailureSystemScript = load("res://core/systems/failure_system.gd")
	failure_system = FailureSystemScript.new(registry)
	add_child(failure_system)
	failure_system.setup(_state)

	var BuilderAuthorityScript = load("res://core/systems/builder_authority.gd")
	if BuilderAuthorityScript != null:
		builder_authority = BuilderAuthorityScript.new()
		add_child(builder_authority)
		if builder_authority.has_method("setup"):
			builder_authority.setup(_state, actions, registry)
	
	# Load Static System Scripts
	_BalanceConfig = load("res://core/balance/balance_config.gd")
	_EnergySystem = load("res://core/systems/energy_system.gd")
	_InfraSystem = load("res://core/systems/infra_system.gd")
	_SatisfactionSystem = load("res://core/systems/satisfaction_system.gd")
	_KarmaSystem = load("res://core/systems/karma_system.gd")
	
	# Initialize default values if needed
	_state.money = _BalanceConfig.STARTING_MONEY
	_state.day = 1
	_state.is_night = false
	_state.energy_load = 0.0
	_state.infra_load = 0.0
	_state.satisfaction = 50.0
	_state.karma = 0.0
	_state.hrotfaktor = 0.0
	
	# Wait for EventBus to be ready
	await get_tree().process_frame
	
	# Connect signals
	EventBus.day_tick.connect(_on_day_tick)
	EventBus.building_placed.connect(func(_id, _o, _f, _r): recalculate_systems())
	EventBus.building_removed.connect(func(_o): recalculate_systems())
	
	# Initial broadcast
	recalculate_systems()
	EventBus.state_changed.emit(get_state_snapshot())
	state_changed.emit(get_state_snapshot())


## Returns a Dictionary representation of the current state
func get_state_snapshot() -> Dictionary:
	var guest_count = 0
	var active_guest_count = 0
	var dirty_accommodation_count = 0
	var review_count = 0
	if _state != null:
		guest_count = int(_state.guests.size())
		for guest_any in _state.guests:
			if not (guest_any is Dictionary):
				continue
			var guest: Dictionary = guest_any
			var status = str(guest.get("status", ""))
			if status == "active" or status == "sleep":
				active_guest_count += 1
		for key_any in _state.accommodation_states.keys():
			var acc = _state.accommodation_states[key_any]
			if acc is Dictionary and str(acc.get("status", "clean")) == "dirty":
				dirty_accommodation_count += 1
		review_count = int(_state.guest_reviews.size())

	return {
		"money": _state.money,
		"day": _state.day,
		"is_night": _state.is_night,
		"energy_load": _state.energy_load,
		"infra_load": _state.infra_load,
		"satisfaction": _state.satisfaction,
		"karma": _state.karma,
		"hrotfaktor": _state.hrotfaktor,
		"guest_count": guest_count,
		"active_guest_count": active_guest_count,
		"dirty_accommodation_count": dirty_accommodation_count,
		"review_count": review_count
	}


## Applies changes to the state.
## keys in `changes` should match property names in GameState.
func apply_changes(changes: Dictionary) -> void:
	var applied_changes: Dictionary = {}
	var has_changes: bool = false
	var money_changed: bool = false
	
	for key in changes.keys():
		if _state_has_property(str(key)):
			var old_value = _state.get(key)
			var new_value = changes[key]
			
			if old_value != new_value:
				_state.set(key, new_value)
				applied_changes[key] = new_value
				has_changes = true
				if str(key) == "money":
					money_changed = true
		else:
			push_warning("CoreRoot: Attempted to set invalid state key '%s'" % key)

	if has_changes:
		if money_changed and EventBus.has_signal("money_changed"):
			EventBus.money_changed.emit(int(_state.money))
		EventBus.state_changed.emit(applied_changes)
		state_changed.emit(applied_changes)


func _state_has_property(key: String) -> bool:
	if _state == null:
		return false
	for prop in _state.get_property_list():
		if str(prop.get("name", "")) == key:
			return true
	return false


## ACCESSORS (Helpers)
func get_state(): return _state
func get_money() -> int: return _state.money
func get_day() -> int: return _state.day
func is_night() -> bool: return _state.is_night


func _on_day_tick(_day_index: int) -> void:
	# Recalculate daily metrics
	recalculate_systems()
	# Apply daily karma change
	_apply_daily_karma()

func recalculate_systems() -> void:
	if not _state.grid:
		return
		
	var changes = {}
	
	# Energy
	var energy = _EnergySystem.calculate(_state.grid, registry)
	changes["energy_load"] = energy
	
	# Infra
	var infra = _InfraSystem.calculate(_state.grid, registry)
	changes["infra_load"] = infra
	
	# Satisfaction
	var sat = _SatisfactionSystem.calculate(_state.grid, registry)
	changes["satisfaction"] = sat
	
	apply_changes(changes)

func _apply_daily_karma() -> void:
	# Calculate delta only
	var energy = _state.energy_load
	var infra = _state.infra_load
	var delta = _KarmaSystem.calculate(_state.grid, registry, energy, infra)
	
	apply_changes({ "karma": _state.karma + delta })

func _process(delta: float) -> void:
	if failure_system:
		failure_system.update(delta)
