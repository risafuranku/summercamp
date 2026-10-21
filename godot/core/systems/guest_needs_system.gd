class_name GuestNeedsSystem
extends RefCounted

## Pure guest needs / mood / goal-selection model.
##
## No scene access. Inputs are plain dictionaries plus the GridModel + BuildingRegistry;
## outputs are numbers and dictionaries. GuestManager owns the per-guest state and calls
## in here once per simulated segment of game time.
##
## SCALES: every need is 0-100 where 100 means "fully satisfied" (a full belly, an empty
## bladder, rested). Mood is 0-100 as well. Guest reviews map mood/20 -> stars.

const NEED_ENERGY := "energy"
const NEED_HUNGER := "hunger"
## Something to drink (the brief of 20. 10.: the businesses' ladder, a small drink at the
## corn stand, a light one at the pub, a big one at the bistro, the Jednota's bottles to
## take home). Their own tap water at the lodging keeps them from going dry, no more.
const NEED_THIRST := "thirst"
const NEED_BLADDER := "bladder"
const NEED_HYGIENE := "hygiene"
const NEED_FUN := "fun"
const NEED_SAFETY := "safety"
const NEEDS: Array[String] = [NEED_ENERGY, NEED_HUNGER, NEED_THIRST, NEED_BLADDER, NEED_HYGIENE, NEED_FUN, NEED_SAFETY]
## Needs a guest actively walks somewhere to fix (energy/safety are handled by sleep/light).
const SEEKABLE_NEEDS: Array[String] = [NEED_HUNGER, NEED_THIRST, NEED_BLADDER, NEED_HYGIENE, NEED_FUN]

const NEED_LABELS := {
	NEED_ENERGY: "Energy",
	NEED_HUNGER: "Hunger",
	NEED_THIRST: "Thirst",
	NEED_BLADDER: "Bladder",
	NEED_HYGIENE: "Hygiene",
	NEED_FUN: "Fun",
	NEED_SAFETY: "Safety",
}

## Base decay per game minute while awake (100 -> 0 in roughly: energy 22h, hunger 10h,
## thirst 12h, bladder 6h, hygiene 24h, fun 14h).
const BASE_DECAY := {
	NEED_ENERGY: 0.075,
	NEED_HUNGER: 0.16,
	NEED_THIRST: 0.14,
	NEED_BLADDER: 0.27,
	NEED_HYGIENE: 0.07,
	NEED_FUN: 0.12,
	NEED_SAFETY: 0.0,
}

## Archetype personalities: decay multipliers, how much each need weighs on mood, and
## which facilities they love (score multiplier when choosing where to go).
const ARCHETYPES := {
	"quiet_guy": {
		"decay": {NEED_ENERGY: 1.0, NEED_HUNGER: 0.9, NEED_THIRST: 0.8, NEED_BLADDER: 0.9, NEED_HYGIENE: 1.1, NEED_FUN: 0.7},
		"weight": {NEED_HYGIENE: 1.3, NEED_FUN: 0.7, NEED_SAFETY: 1.3, NEED_THIRST: 0.6},
		"likes": {"corn_stand": 0.9, "bonfire": 1.4, "lake_slide": 0.8, "pub": 0.5, "sports_field": 0.7, "restaurant": 1.1, "bench": 1.4, "hammock": 1.6, "ping_pong": 1.0, "picnic_table": 1.0, "playground": 0.3},
		"comfort_weight": 0.8,
	},
	"drunk": {
		"decay": {NEED_ENERGY: 1.1, NEED_HUNGER: 1.2, NEED_THIRST: 1.6, NEED_BLADDER: 1.5, NEED_HYGIENE: 0.6, NEED_FUN: 1.4},
		"weight": {NEED_FUN: 1.4, NEED_HUNGER: 1.1, NEED_HYGIENE: 0.6, NEED_THIRST: 1.2},
		"likes": {"corn_stand": 1.0, "pub": 2.0, "bonfire": 1.4, "vecerka": 1.3, "sports_field": 0.6, "picnic_table": 1.4, "ping_pong": 1.3, "bench": 1.1, "hammock": 1.2, "playground": 0.2},
		"comfort_weight": 0.5,
	},
	"cheap_chick": {
		"decay": {NEED_ENERGY: 0.9, NEED_HUNGER: 0.9, NEED_THIRST: 1.1, NEED_BLADDER: 1.0, NEED_HYGIENE: 1.5, NEED_FUN: 1.2},
		"weight": {NEED_HYGIENE: 1.5, NEED_FUN: 1.2, NEED_THIRST: 0.8},
		"likes": {"corn_stand": 1.4, "lake_slide": 1.7, "sports_field": 1.2, "restaurant": 1.3, "shower_block": 1.2, "pub": 0.8, "hammock": 1.5, "ping_pong": 1.1, "bench": 0.8, "picnic_table": 1.0, "playground": 0.4},
		"comfort_weight": 1.5,
	},
	# Tramps: sleep anywhere, live at the fire with a guitar, wash in the lake (or not).
	"tramp": {
		"decay": {NEED_ENERGY: 0.8, NEED_HUNGER: 1.1, NEED_THIRST: 1.2, NEED_BLADDER: 1.0, NEED_HYGIENE: 0.5, NEED_FUN: 1.3},
		"weight": {NEED_FUN: 1.5, NEED_HUNGER: 1.0, NEED_HYGIENE: 0.4, NEED_SAFETY: 0.8, NEED_THIRST: 0.9},
		"likes": {"corn_stand": 1.3, "bonfire": 2.2, "pub": 1.4, "vecerka": 1.2, "lake_slide": 0.9, "restaurant": 0.5, "bench": 1.2, "hammock": 1.4, "picnic_table": 1.3, "ping_pong": 0.7, "playground": 0.3},
		"comfort_weight": 0.3,
	},
	# Family: kids are hungry and bored every hour, parents want it clean and safe.
	"family": {
		"decay": {NEED_ENERGY: 1.1, NEED_HUNGER: 1.4, NEED_THIRST: 1.3, NEED_BLADDER: 1.3, NEED_HYGIENE: 1.2, NEED_FUN: 1.6},
		"weight": {NEED_FUN: 1.3, NEED_HYGIENE: 1.3, NEED_SAFETY: 1.6, NEED_HUNGER: 1.2, NEED_THIRST: 0.9},
		"likes": {"corn_stand": 1.8, "sports_field": 1.8, "lake_slide": 1.8, "restaurant": 1.5, "vecerka": 1.2, "shower_block": 1.3, "pub": 0.4, "playground": 2.4, "picnic_table": 1.6, "ping_pong": 1.3, "bench": 1.0, "hammock": 0.9},
		"comfort_weight": 1.3,
	},
	# Mushroom pickers: early to bed, up at four, out in the woods; hate noise.
	"picker": {
		"decay": {NEED_ENERGY: 1.2, NEED_HUNGER: 0.8, NEED_THIRST: 0.9, NEED_BLADDER: 1.2, NEED_HYGIENE: 0.9, NEED_FUN: 0.5},
		"weight": {NEED_ENERGY: 1.4, NEED_SAFETY: 1.2, NEED_FUN: 0.5, NEED_THIRST: 0.7},
		"likes": {"corn_stand": 1.2, "restaurant": 1.4, "vecerka": 1.5, "bonfire": 0.8, "pub": 0.4, "sports_field": 0.3, "bench": 1.6, "picnic_table": 1.3, "hammock": 0.8, "ping_pong": 0.5, "playground": 0.3},
		"comfort_weight": 1.2,
	},
}

## Where each kind likes to sleep: comfort points on top of the lodging's own (by building
## type; the exact type before its kind, "cabin_2" before "cabin"). The key you hand over
## at the desk matters: a family is happiest in a caravan with bunks, the pensioner hates
## a tent, the tramp is at home under canvas, Kristyna wants a shower of her own.
const LODGING_TASTE := {
	"quiet_guy": {"tent": -6.0, "cabin": 10.0, "caravan": -8.0},
	"drunk": {"tent": 4.0, "cabin": 0.0, "caravan": 8.0},
	"cheap_chick": {"tent": -25.0, "cabin": -4.0, "cabin_2": 18.0, "cabin_3": 22.0, "caravan": -10.0, "caravan_3": 14.0},
	"tramp": {"tent": 14.0, "cabin": -2.0, "caravan": 2.0},
	"family": {"tent": -10.0, "cabin": 6.0, "caravan": 8.0, "caravan_2": 16.0, "caravan_3": 18.0},
	"picker": {"tent": -20.0, "cabin": 12.0, "caravan": -4.0},
}
## What they say about it when they move in (the same lookup; strong tastes only).
const LODGING_THOUGHTS := {
	"quiet_guy": {"cabin": "Four walls and quiet. Good.", "caravan": "You can hear everything through these walls.", "tent": "Canvas. Every sound comes through."},
	"drunk": {"caravan": "A caravan with a fridge. The beer stays cold.", "tent": "Smells like a festival in here. Lovely."},
	"cheap_chick": {"tent": "A tent? Where am I supposed to plug in the hairdryer?", "cabin": "No shower in the room? Seriously?", "cabin_2": "A shower of my own. Finally.", "cabin_3": "Now THIS is a holiday.", "caravan": "It smells of old gas in here.", "caravan_3": "Fairy lights! It's like a little doll's house."},
	"tramp": {"tent": "Canvas over my head, the sky above that. Perfect.", "cabin": "A bit posh, all these walls."},
	"family": {"tent": "Four of us in a tent. The kids will freeze.", "cabin": "A proper roof for the kids.", "caravan": "The kids think the caravan is a spaceship.", "caravan_2": "The boy is in love with the bunk bed.", "caravan_3": "Bunks, fairy lights and a telly. They'll never want to leave."},
	"picker": {"tent": "A tent, at my age. My back will be in the lake by morning.", "cabin": "A proper bed and a door that shuts. Up at four."},
}
## Who keeps the camp awake (drunks sing until about three) and who it keeps awake.
const NOISY := {"drunk": 1.0}
const LIGHT_SLEEPERS := {"picker": 1.0, "quiet_guy": 0.8, "family": 0.5, "cheap_chick": 0.4}
## Within this many tiles of a noisy party's lodging (lodgings are 1-2 tiles wide).
const NOISE_RANGE_TILES := 3
const NOISE_COMFORT := 24.0
## How much of the noise next door comes through the walls, by lodging kind (21. 10.,
## the caravan's balance): canvas and a caravan's thin shell let it all in and more, a
## cabin's four walls keep some of it out.
const WALLS_LET_IN := {"tent": 1.2, "caravan": 1.35, "cabin": 0.75}
## A caravan with the camp's power gone: the fridge warm, the lamp dead, the pump dry.
const CARAVAN_NO_POWER := 14.0


## How much of the noise outside reaches a guest lodged in `building_type`.
static func walls_let_in(building_type: String) -> float:
	return float(WALLS_LET_IN.get(building_type.to_lower().get_slice("_", 0), 1.0))


## Comfort a lodging loses to the state of the camp now (`powered`: the grid is up).
static func lodging_upset(building_type: String, powered: bool) -> float:
	if not powered and building_type.to_lower().begins_with("caravan"):
		return CARAVAN_NO_POWER
	return 0.0


## Warm on a frost night: a caravan done up with its gas heater (Lv3); tents and the
## other caravans freeze (GuestManager.apply_cold_night).
static func frost_proof(building_type: String) -> bool:
	var bt := building_type.to_lower()
	return not (bt.begins_with("tent") or bt.begins_with("caravan")) or bt == "caravan_3"

## A need below this is something the guest goes and deals with.
const SEEK_THRESHOLD := 62.0
## The evening rush (the brief of 20. 10.: "the peak of the day: queues at every place"):
## from a quarter to six to eight nearly everybody goes for supper, a drink and a bit of
## fun, so the places' needs are seen to much sooner than by day.
const RUSH_FROM := 17.75
const RUSH_TO := 20.0
const RUSH_SEEK := {NEED_HUNGER: 90.0, NEED_THIRST: 88.0, NEED_FUN: 80.0}


static func is_rush(hour: float) -> bool:
	return hour >= RUSH_FROM and hour < RUSH_TO
## Below this the need becomes an emergency (bushes, storm-off pressure).
const CRITICAL_THRESHOLD := 12.0
## Mood below this counts as "unhappy" (liminal pressure, early departure clock).
const UNHAPPY_MOOD := 35.0
## Minutes of continuous unhappiness before a guest packs up and leaves.
const STORM_OFF_MINUTES := 180
## Game minutes to cross one grid tile on foot.
const MINUTES_PER_TILE := 3.0
## Mood drifts toward its target at this rate per game minute.
const MOOD_FOLLOW_PER_MINUTE := 0.6

## Sleep restores energy per minute, scaled by lodging comfort.
const SLEEP_ENERGY_PER_MINUTE := 0.34

## Asleep at night the body waits for the morning (playtest 20. 10.: "at three in the
## morning they were cross with me over a broken toilet; at night guests sleep"):
## hunger, bladder, hygiene and fun stand still and what is wrong in the camp does not
## reach them. Only the bed (comfort, the drunks singing next door) and fear (safety)
## sour a sleeper's mood, and only down to a ceiling (sleep_mood_target). The night is
## paid on waking: the queue for the toilets and breakfast come when the warden is up.
const MORNING_NEEDS := {NEED_BLADDER: 30.0, NEED_HUNGER: 20.0, NEED_THIRST: 15.0, NEED_HYGIENE: 8.0}
## Back at their lodging (a lie-down, a night's rest) they drink their own water: thirst
## comes back up to here, never higher (a proper drink is the businesses').
const HOME_WATER := 55.0
const HOME_WATER_PER_MINUTE := 0.12
## Comfort below which a bed spoils the night (a tent for the pensioner, Kristyna's).
const BAD_BED := 45.0
## Score a facility loses when it is at its filthiest (choosing where to go).
const DIRT_PENALTY := 24.0


static func archetype_profile(archetype: String) -> Dictionary:
	return ARCHETYPES.get(archetype, ARCHETYPES["quiet_guy"])


## Comfort points this kind of guest adds to (or takes off) a lodging of `building_type`.
static func lodging_taste(archetype: String, building_type: String) -> float:
	var t: Dictionary = LODGING_TASTE.get(archetype, {})
	var bt := building_type.to_lower()
	if t.has(bt):
		return float(t[bt])
	return float(t.get(bt.get_slice("_", 0), 0.0))


## What they think of their lodging when they move in ("" = nothing worth saying).
static func lodging_thought(archetype: String, building_type: String) -> String:
	var t: Dictionary = LODGING_THOUGHTS.get(archetype, {})
	var bt := building_type.to_lower()
	if t.has(bt):
		return str(t[bt])
	return str(t.get(bt.get_slice("_", 0), ""))


static func default_needs(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for need in NEEDS:
		out[need] = rng.randf_range(58.0, 88.0) if rng != null else 75.0
	out[NEED_SAFETY] = 80.0
	return out


## Sanitises a needs dictionary loaded from JSON (floats, missing keys).
static func normalize_needs(raw: Variant) -> Dictionary:
	var out := {}
	var src: Dictionary = raw if raw is Dictionary else {}
	for need in NEEDS:
		out[need] = clampf(float(src.get(need, 70.0)), 0.0, 100.0)
	return out


## Applies `minutes` of passive decay. `context` keys:
##   sleeping (bool), night_sleep (bool: the night's rest, in bed or up in the night's
##   trouble, see MORNING_NEEDS),
##   comfort (0-100), is_night (bool), lit (bool: near light),
##   threat (0-1: enemy pressure near the guest), crowd (0-1).
static func decay_needs(needs: Dictionary, archetype: String, minutes: float, context: Dictionary) -> Dictionary:
	var out := needs.duplicate()
	if minutes <= 0.0:
		return out
	var profile := archetype_profile(archetype)
	var decay_mult: Dictionary = profile.get("decay", {})
	var sleeping := bool(context.get("sleeping", false))
	var night_sleep := bool(context.get("night_sleep", false))
	var comfort := clampf(float(context.get("comfort", 50.0)), 0.0, 100.0)
	for need in [NEED_HUNGER, NEED_THIRST, NEED_BLADDER, NEED_HYGIENE, NEED_FUN]:
		var rate := float(BASE_DECAY[need]) * float(decay_mult.get(need, 1.0))
		if night_sleep or (sleeping and need == NEED_FUN):
			rate = 0.0
		elif sleeping:
			rate *= 0.35
		out[need] = clampf(float(out.get(need, 70.0)) - rate * minutes, 0.0, 100.0)
	if sleeping and not night_sleep and float(out[NEED_THIRST]) < HOME_WATER:
		out[NEED_THIRST] = minf(HOME_WATER, float(out[NEED_THIRST]) + HOME_WATER_PER_MINUTE * minutes)
	if sleeping:
		var quality := lerpf(0.55, 1.25, comfort / 100.0)
		out[NEED_ENERGY] = clampf(float(out[NEED_ENERGY]) + SLEEP_ENERGY_PER_MINUTE * quality * minutes, 0.0, 100.0)
	else:
		var e_rate := float(BASE_DECAY[NEED_ENERGY]) * float(decay_mult.get(NEED_ENERGY, 1.0))
		out[NEED_ENERGY] = clampf(float(out[NEED_ENERGY]) - e_rate * minutes, 0.0, 100.0)
	out[NEED_SAFETY] = _safety_toward_target(float(out[NEED_SAFETY]), context, minutes)
	return out


static func _safety_toward_target(current: float, context: Dictionary, minutes: float) -> float:
	var target := 85.0
	if bool(context.get("is_night", false)):
		target = 70.0 if bool(context.get("lit", false)) else 45.0
		if bool(context.get("sleeping", false)):
			target += 10.0
	target -= clampf(float(context.get("threat", 0.0)), 0.0, 1.0) * 70.0
	target -= clampf(float(context.get("weirdness", 0.0)), 0.0, 1.0) * 20.0
	var step := minutes * (1.2 if target < current else 0.5)
	return clampf(move_toward(current, target, step), 0.0, 100.0)


## Applies a facility visit. `services` comes from BuildingDef.guest_services.
static func apply_facility(needs: Dictionary, services: Dictionary, archetype: String, building_type: String) -> Dictionary:
	var out := needs.duplicate()
	var like := float(archetype_profile(archetype).get("likes", {}).get(building_type, 1.0))
	for key in services.keys():
		var need := str(key)
		if not out.has(need):
			continue
		var amount := float(services[key])
		if amount > 0.0 and need == NEED_FUN:
			amount *= like
		out[need] = clampf(float(out[need]) + amount, 0.0, 100.0)
	return out


## Target mood from needs + lodging comfort. The worst need dominates: a guest with a
## bursting bladder is not consoled by a great bonfire.
static func mood_target(needs: Dictionary, archetype: String, comfort: float) -> float:
	var profile := archetype_profile(archetype)
	var weights: Dictionary = profile.get("weight", {})
	var total := 0.0
	var weight_sum := 0.0
	var worst := 100.0
	for need in NEEDS:
		var w := float(weights.get(need, 1.0))
		var v := float(needs.get(need, 70.0))
		total += v * w
		weight_sum += w
		worst = minf(worst, lerpf(100.0, v, clampf(w, 0.0, 1.5) / 1.5))
	var avg := total / maxf(weight_sum, 0.001)
	var comfort_term := (clampf(comfort, 0.0, 100.0) - 50.0) * 0.18 * float(profile.get("comfort_weight", 1.0))
	return clampf(avg * 0.62 + worst * 0.38 + comfort_term, 0.0, 100.0)


## A sleeper's mood target (see MORNING_NEEDS): where the mood was, sunk only by a bad
## night: a poor bed for this kind of guest, the noise next door (`noise`, the comfort
## points it takes), fear. Never up while asleep: the morning's rested energy does that.
static func sleep_mood_target(current: float, needs: Dictionary, archetype: String, comfort: float, noise: float = 0.0) -> float:
	var profile := archetype_profile(archetype)
	var cw := float(profile.get("comfort_weight", 1.0))
	var w_safety := float((profile.get("weight", {}) as Dictionary).get(NEED_SAFETY, 1.0))
	var ceiling := 100.0 - maxf(0.0, BAD_BED - comfort) * 1.2 * cw
	ceiling = minf(ceiling, 100.0 - maxf(0.0, noise) * 1.5)
	ceiling = minf(ceiling, lerpf(100.0, float(needs.get(NEED_SAFETY, 80.0)), clampf(w_safety, 0.0, 1.5) / 1.5))
	return clampf(minf(current, ceiling), 0.0, 100.0)


## Waking up in the morning: the night's hunger and full bladder at once (MORNING_NEEDS).
static func wake_needs(needs: Dictionary) -> Dictionary:
	var out := needs.duplicate()
	for need in MORNING_NEEDS:
		out[need] = clampf(float(out.get(need, 70.0)) - float(MORNING_NEEDS[need]), 0.0, 100.0)
	return out


static func step_mood(current: float, target: float, minutes: float) -> float:
	return clampf(move_toward(current, target, MOOD_FOLLOW_PER_MINUTE * maxf(minutes, 0.0)), 0.0, 100.0)


## Scans the grid for guest facilities. Returns an Array of dictionaries:
##   {key, coord, type, services, capacity, use_minutes, working, reason, label}
## `flags`: {power_available: bool, failures: Dictionary, weather: int}
## Facilities that require "dry" close in drizzle, rain and storm (weather 3..5).
static func collect_facilities(grid, registry, flags: Dictionary) -> Array:
	var out: Array = []
	if grid == null or registry == null:
		return out
	var failures: Dictionary = flags.get("failures", {})
	var power_ok := bool(flags.get("power_available", true))
	var sewer_ok := _has_working_sewer(grid, failures)
	var weather := int(flags.get("weather", 0))
	var dry := weather < 3 or weather > 5
	for coord_any in grid.cells.keys():
		if not (coord_any is Vector2i):
			continue
		var coord: Vector2i = coord_any
		var cell: Dictionary = grid.cells[coord]
		if cell.get("root_coord", coord) != coord:
			continue
		var type := str(cell.get("type", ""))
		var def = registry.get_def(StringName(type))
		if def == null or def.guest_capacity <= 0 or def.guest_services.is_empty():
			continue
		var key := "%d:%d" % [coord.x, coord.y]
		var working := true
		var reason := ""
		if failures.has(key):
			working = false
			reason = "broken"
		elif def.requires.has("sewer") and not sewer_ok:
			working = false
			reason = "no_sewer"
		elif def.requires.has("power") and not power_ok:
			working = false
			reason = "no_power"
		elif def.requires.has("dry") and not dry:
			working = false
			reason = "rained_out"
		out.append({
			"key": key,
			"coord": coord,
			"type": type,
			"label": str(def.display_name).split(" (")[0],
			"services": def.guest_services,
			"capacity": int(def.guest_capacity),
			"use_minutes": maxi(4, int(def.use_minutes)),
			"footprint": def.footprint,
			"working": working,
			"reason": reason,
			# How clean it is (the toilets and showers get dirty with use).
			"condition": clampf(float(cell.get("maintenance", 1.0)), 0.0, 1.0),
		})
	return out


static func _has_working_sewer(grid, failures: Dictionary) -> bool:
	for coord_any in grid.cells.keys():
		var cell: Dictionary = grid.cells[coord_any]
		var type := str(cell.get("type", ""))
		if type != "sewer" and type != "sewage_tank":
			continue
		var root = cell.get("root_coord", coord_any)
		if root != coord_any:
			continue
		var key := "%d:%d" % [root.x, root.y]
		if not failures.has(key):
			return true
	return false


## Travel time on foot between two tiles (Manhattan, the camp is a grid of paths).
static func travel_minutes(from_coord: Vector2i, to_coord: Vector2i) -> int:
	var tiles := absi(from_coord.x - to_coord.x) + absi(from_coord.y - to_coord.y)
	return maxi(1, int(ceil(float(tiles) * MINUTES_PER_TILE)))


## Chooses what an awake guest does next.
##
## Returns {kind, need, facility (Dictionary or {}), thought}. kind is one of:
##   "visit"  walk to `facility` and use it for its use_minutes
##   "bushes" no toilet anywhere and it is an emergency
##   "wander" nothing needed, or nothing available: stroll around
##   "rest"   go back to the lodging for a while (tired but not night)
## `usage`: facility key -> parties currently using/queuing there.
static func pick_goal(
	needs: Dictionary,
	archetype: String,
	facilities: Array,
	from_coord: Vector2i,
	usage: Dictionary,
	rng: RandomNumberGenerator,
	hour := -1.0
) -> Dictionary:
	var profile := archetype_profile(archetype)
	var weights: Dictionary = profile.get("weight", {})
	var likes: Dictionary = profile.get("likes", {})
	var rush := is_rush(hour)

	# Rank needs by urgency; sample among the pressing ones so guests are not robots.
	var candidates: Array = []
	for need in SEEKABLE_NEEDS:
		var value := float(needs.get(need, 70.0))
		var seek := float(RUSH_SEEK.get(need, SEEK_THRESHOLD)) if rush else SEEK_THRESHOLD
		if value >= seek:
			continue
		var urgency := pow((100.0 - value) / 100.0, 2.0) * float(weights.get(need, 1.0))
		if rush and RUSH_SEEK.has(need):
			# Supper time: going for it is the thing to do, however full they are.
			urgency += 0.25
		candidates.append({"need": need, "urgency": urgency, "value": value})
	if float(needs.get(NEED_ENERGY, 100.0)) < 25.0:
		candidates.append({"need": NEED_ENERGY, "urgency": 0.6, "value": float(needs.get(NEED_ENERGY, 0.0))})

	candidates.sort_custom(func(a, b): return float(a["urgency"]) > float(b["urgency"]))
	# Guests are not robots: a quarter of the time the second most urgent need goes first.
	if candidates.size() > 1 and rng != null and rng.randf() < 0.25:
		var first = candidates[0]
		candidates[0] = candidates[1]
		candidates[1] = first
	for entry_any in candidates:
		var entry: Dictionary = entry_any
		var need := str(entry["need"])
		if need == NEED_ENERGY:
			return {"kind": "rest", "need": need, "facility": {}, "thought": "I need a lie-down."}
		var best := _best_facility_for(need, facilities, from_coord, usage, likes)
		if not best.is_empty():
			return {"kind": "visit", "need": need, "facility": best, "thought": _thought_for_visit(need, best)}
		var broken := _find_broken_for(need, facilities)
		if need == NEED_BLADDER and float(entry["value"]) < CRITICAL_THRESHOLD + 8.0:
			var why := "The toilets are out of order. The bushes it is." if not broken.is_empty() else "No toilet in this whole camp? The bushes it is."
			return {"kind": "bushes", "need": need, "facility": {}, "thought": why}
		if not broken.is_empty():
			return {"kind": "wander", "need": need, "facility": {}, "thought": _thought_for_broken(need, broken)}
		return {"kind": "wander", "need": need, "facility": {}, "thought": _thought_for_missing(need)}

	# Nothing pressing: leisure. Sometimes pick a loved attraction, else stroll.
	if rng != null and rng.randf() < 0.30:
		var leisure := _best_facility_for(NEED_FUN, facilities, from_coord, usage, likes, true)
		if not leisure.is_empty():
			return {"kind": "visit", "need": NEED_FUN, "facility": leisure, "thought": "Nice day for the %s." % str(leisure.get("label", "camp")).to_lower()}
	return {"kind": "wander", "need": "", "facility": {}, "thought": ""}


static func _best_facility_for(need: String, facilities: Array, from_coord: Vector2i, usage: Dictionary, likes: Dictionary, leisure_only: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for f_any in facilities:
		var f: Dictionary = f_any
		if not bool(f.get("working", true)):
			continue
		var services: Dictionary = f.get("services", {})
		var gain := float(services.get(need, 0.0))
		if gain <= 0.0:
			continue
		if leisure_only and float(services.get(NEED_FUN, 0.0)) < 20.0:
			continue
		var busy := int(usage.get(str(f.get("key", "")), 0))
		var cap := maxi(1, int(f.get("capacity", 1)))
		var crowd_penalty := 0.0 if busy < cap else 25.0 + float(busy - cap) * 12.0
		var dist := float(travel_minutes(from_coord, f.get("coord", from_coord)))
		var like := float(likes.get(str(f.get("type", "")), 1.0))
		# A dirty block: they would rather walk to a cleaner one.
		var dirt := (1.0 - float(f.get("condition", 1.0))) * DIRT_PENALTY
		var score := gain * like - dist * 0.8 - crowd_penalty - dirt
		if score > best_score:
			best_score = score
			best = f
	return best


static func _find_broken_for(need: String, facilities: Array) -> Dictionary:
	for f_any in facilities:
		var f: Dictionary = f_any
		if bool(f.get("working", true)):
			continue
		var services: Dictionary = f.get("services", {})
		if float(services.get(need, 0.0)) > 0.0:
			return f
	return {}


static func _thought_for_visit(need: String, facility: Dictionary) -> String:
	var label := str(facility.get("label", "somewhere")).to_lower()
	match need:
		NEED_HUNGER:
			return "Starving. Off to the %s." % label
		NEED_BLADDER:
			return "Need the %s. Now." % label
		NEED_HYGIENE:
			return "I smell like the lake. %s time." % str(facility.get("label", "Shower"))
		NEED_FUN:
			return "Bored. Let's try the %s." % label
	return ""


static func _thought_for_broken(need: String, facility: Dictionary) -> String:
	var label := str(facility.get("label", "it"))
	match str(facility.get("reason", "")):
		"no_sewer":
			return "%s is closed - something about the sewer." % label
		"no_power":
			return "%s is dark. No power?" % label
		"rained_out":
			return "Rained out. The %s is a puddle." % label.to_lower()
	match need:
		NEED_HUNGER:
			return "The %s is broken and I'm starving." % label.to_lower()
	return "The %s is broken. Great camp." % label.to_lower()


static func _thought_for_missing(need: String) -> String:
	match need:
		NEED_HUNGER:
			return "Nowhere to eat in this camp."
		NEED_BLADDER:
			return "Where is the toilet?!"
		NEED_HYGIENE:
			return "No showers. I feel disgusting."
		NEED_FUN:
			return "There is nothing to do here."
	return ""


## Worst need for a status readout: {need, value, label}.
static func worst_need(needs: Dictionary) -> Dictionary:
	var worst_need := NEED_ENERGY
	var worst_value := 101.0
	for need in NEEDS:
		var v := float(needs.get(need, 100.0))
		if v < worst_value:
			worst_value = v
			worst_need = need
	return {"need": worst_need, "value": worst_value, "label": str(NEED_LABELS.get(worst_need, worst_need))}


static func mood_label(mood: float) -> String:
	if mood >= 80.0:
		return "Delighted"
	if mood >= 62.0:
		return "Happy"
	if mood >= 45.0:
		return "Okay"
	if mood >= UNHAPPY_MOOD:
		return "Grumpy"
	if mood >= 18.0:
		return "Unhappy"
	return "Furious"


## Star rating 1-5 from a guest's final mood blended with camp satisfaction (0-100).
static func review_stars(mood: float, camp_satisfaction: float) -> int:
	var blended := clampf(mood, 0.0, 100.0) * 0.8 + clampf(camp_satisfaction, 0.0, 100.0) * 0.2
	return clampi(int(round((blended + 5.0) / 20.0)), 1, 5)


## The Jednota's bag to take home (the brief of 20. 10.: "supplies for the whole stay"):
## what they bought keeps topping their needs up when they run low, a little a minute,
## until it is used up. `stash` is {need: points left}; returns [needs, stash].
const STASH_BELOW := 60.0
const STASH_PER_MINUTE := 0.25
## What a basket from a place puts in the bag (points a need, used as above), at most
## STASH_CAP of each kept.
const STASH_FROM := {"vecerka": {NEED_HUNGER: 45.0, NEED_THIRST: 45.0, NEED_FUN: 20.0, NEED_HYGIENE: 25.0}}
const STASH_CAP := 120.0


## The bag after a basket from `building_type` (unchanged when it fills nothing).
static func add_stash(stash: Dictionary, building_type: String) -> Dictionary:
	var out := stash.duplicate()
	var from: Dictionary = STASH_FROM.get(building_type, {})
	for need in from:
		out[need] = minf(STASH_CAP, float(out.get(need, 0.0)) + float(from[need]))
	return out


static func use_stash(needs: Dictionary, stash: Dictionary, minutes: float) -> Array:
	if stash.is_empty() or minutes <= 0.0:
		return [needs, stash]
	var out := needs.duplicate()
	var left := stash.duplicate()
	for need in left.keys():
		var have := float(left[need])
		var v := float(out.get(need, 70.0))
		if have <= 0.0 or v >= STASH_BELOW:
			continue
		var take := minf(have, minf(STASH_PER_MINUTE * minutes, STASH_BELOW - v))
		out[need] = v + take
		left[need] = have - take
	for need in left.keys():
		if float(left[need]) <= 0.01:
			left.erase(need)
	return [out, left]

