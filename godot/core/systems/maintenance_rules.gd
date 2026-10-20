extends RefCounted

## The upkeep rules in one place, pure and static (no nodes, no state writes):
## who can break, how likely, what fixing costs, how long it takes.
##
## Only the lamps wear out (playtest 17. 10.: no upkeep on anything else, never asked
## for): every day a lamp's bulb is a little weaker, it lights less and flickers more,
## and when it is spent the lamp goes out and stays out until you put a new one in
## (hold R, the wrench). Nothing breaks by chance any more. The one other thing you
## repair with R is the derelict old cabin of the start (a failure marked "derelict").
## The toilet and shower blocks do not wear with time but get dirty with use
## (SOILED_BY_USE): cleaned inside, never with R.
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
## What wears out with time.
const WEARS := ["lamp_post"]

## What the guests dirty by using it (playtest 20. 10.: "dirty toilets you can smell from
## outside"): every visit takes this off the block's condition, cleaning it inside
## (service_interior.gd, the list from mess_rules.block_tasks) puts it back to 1.
## About thirty visits from clean to filthy: a busy camp needs its toilets done daily.
const SOILED_BY_USE := {"toilet_block": 0.03, "shower_block": 0.024}
## Below this the block stinks where you can see it, and worse the lower it goes.
const STINK_FROM := 0.6
## Below this a guest who uses it says so and likes the camp less.
const FILTHY := 0.35


static func soils(type: String) -> bool:
	return SOILED_BY_USE.has(type)


## 0 (clean enough) .. 1 (filthy): how much a block stinks at this condition.
static func stink(condition: float) -> float:
	if condition >= STINK_FROM:
		return 0.0
	return clampf((STINK_FROM - condition) / STINK_FROM, 0.0, 1.0)


static func can_break(type: String, def) -> bool:
	if not WEARS.has(type) or def == null:
		return false
	return float(def.maintenance_decay) > 0.0


## A lamp's condition: its own cell's, or for a lamp on a path the path cell's
## "lamp_maintenance".
static func lamp_condition(cell: Dictionary) -> float:
	if str(cell.get("type", "")) == "lamp_post":
		return float(cell.get("maintenance", 1.0))
	return float(cell.get("lamp_maintenance", 1.0))


## How bright a lamp of this condition burns (0 when it is spent).
static func lamp_brightness(condition: float) -> float:
	if condition <= 0.0:
		return 0.0
	return clampf(0.18 + 0.82 * smoothstep(0.0, 0.85, condition), 0.0, 1.0)


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
