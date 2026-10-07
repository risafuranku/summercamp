extends RefCounted

## The upkeep rules in one place, pure and static (no nodes, no state writes):
## who can break, how likely, what fixing costs, how long it takes.
##
## The rule the player can learn: keep a building above SAFE_CONDITION and it does not
## break. Below that, the hourly breakdown odds climb toward HAZARD_AT_ZERO. Condition
## decays daily by BuildingDef.maintenance_decay (MaintenanceSystem).
##
## Servicing a worn building (hold R next to it) is cheap and quick. Repairing a broken
## one costs more and takes longer. The maintenance crew (Camp Status > Upkeep) does
## everything at once for a premium, but only in daylight.

const SAFE_CONDITION := 0.5
const WORN_CONDITION := 0.75
const HAZARD_AT_ZERO := 0.10
const SERVICE_COST_FACTOR := 0.12
const SERVICE_COST_MIN := 5
const REPAIR_COST_FACTOR := 0.25
const REPAIR_COST_MIN := 15
const CREW_PREMIUM := 1.5
const REPAIR_SECONDS := 4.0

## Building types that never break (no condition loop).
const EXEMPT_TYPES := ["path", "main_building", "reception"]


static func can_break(type: String, def) -> bool:
	if EXEMPT_TYPES.has(type) or def == null:
		return false
	return float(def.maintenance_decay) > 0.0


## Chance that a building breaks during one in-game hour.
static func hazard_per_hour(condition: float) -> float:
	if condition >= SAFE_CONDITION:
		return 0.0
	var t := clampf((SAFE_CONDITION - condition) / SAFE_CONDITION, 0.0, 1.0)
	return HAZARD_AT_ZERO * pow(t, 1.5)


static func service_cost(def, condition: float) -> int:
	var base := float(def.cost) if def != null else 100.0
	return maxi(SERVICE_COST_MIN, int(ceil(base * SERVICE_COST_FACTOR * (1.0 - clampf(condition, 0.0, 1.0)))))


static func repair_cost(def) -> int:
	var base := float(def.cost) if def != null else 100.0
	return maxi(REPAIR_COST_MIN, int(ceil(base * REPAIR_COST_FACTOR)))


## Seconds of holding R. Servicing scales with wear; a breakdown is a fixed job.
static func work_seconds(condition: float, broken: bool) -> float:
	if broken:
		return REPAIR_SECONDS
	return 0.8 + 1.6 * (1.0 - clampf(condition, 0.0, 1.0))


static func condition_word(condition: float, broken: bool) -> String:
	if broken:
		return "BROKEN"
	if condition < SAFE_CONDITION:
		return "POOR"
	if condition < WORN_CONDITION:
		return "WORN"
	return "GOOD"
