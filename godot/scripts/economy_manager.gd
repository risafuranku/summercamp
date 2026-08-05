extends Node

signal money_changed(new_amount: int)
signal day_advanced(day: int, income: int)
@warning_ignore("unused_signal")
signal utility_failed(building_type: String, coord: Vector2i)
@warning_ignore("unused_signal")
signal utility_repaired(building_type: String, coord: Vector2i)

const CATEGORY_HOUSING := "housing"
const CATEGORY_SERVICES := "services"
const CATEGORY_ATTRACTIONS := "attractions"
const CATEGORY_UTILITIES := "utilities"

const CATEGORY_LABELS: Dictionary = {
	CATEGORY_HOUSING: "Housing",
	CATEGORY_SERVICES: "Services",
	CATEGORY_ATTRACTIONS: "Attractions",
	CATEGORY_UTILITIES: "Utilities",
}

const BUILDER_CATEGORIES: Array[String] = [
	CATEGORY_HOUSING,
	CATEGORY_SERVICES,
	CATEGORY_ATTRACTIONS,
	CATEGORY_UTILITIES,
]

# Higher-tier variants are upgrade-only and should not be directly placeable from builder.
const UPGRADE_ONLY_TYPES: Dictionary = {
	"tent_2": true,
	"tent_3": true,
	"cabin": true,
	"cabin_2": true,
	"cabin_3": true,
	# Legacy aliases kept only for backwards compatibility.
	"water_pump": true,
	"sewage_tank": true,
}

const BUILDING_DATA: Dictionary = {
	"tent_1": {"category": CATEGORY_HOUSING, "cost": 80, "income": 25, "label": "Tent Lv1 (1x1)", "footprint": Vector2i(1, 1), "capacity": 1, "power_use": 0, "water_use": 1, "sewage_use": 1, "waste_use": 1},
	"tent_2": {"category": CATEGORY_HOUSING, "cost": 180, "income": 55, "label": "Tent Lv2 (1x1)", "footprint": Vector2i(1, 1), "capacity": 2, "power_use": 0, "water_use": 2, "sewage_use": 1, "waste_use": 1},
	"tent_3": {"category": CATEGORY_HOUSING, "cost": 350, "income": 100, "label": "Tent Lv3 (1x1)", "footprint": Vector2i(1, 1), "capacity": 3, "power_use": 0, "water_use": 2, "sewage_use": 2, "waste_use": 1},
	"cabin": {"category": CATEGORY_HOUSING, "cost": 260, "income": 70, "label": "Cabin Lv1 (2x2)", "footprint": Vector2i(2, 2), "capacity": 2, "power_use": 2, "water_use": 2, "sewage_use": 2, "waste_use": 1},
	"cabin_1": {"category": CATEGORY_HOUSING, "cost": 260, "income": 70, "label": "Cabin Lv1 (2x2)", "footprint": Vector2i(2, 2), "capacity": 2, "power_use": 2, "water_use": 2, "sewage_use": 2, "waste_use": 1},
	"cabin_2": {"category": CATEGORY_HOUSING, "cost": 420, "income": 120, "label": "Cabin Lv2 (2x2)", "footprint": Vector2i(2, 2), "capacity": 3, "power_use": 3, "water_use": 3, "sewage_use": 2, "waste_use": 2},
	"cabin_3": {"category": CATEGORY_HOUSING, "cost": 620, "income": 180, "label": "Cabin Lv3 (2x2)", "footprint": Vector2i(2, 2), "capacity": 4, "power_use": 4, "water_use": 3, "sewage_use": 3, "waste_use": 2},
	"caravan_1": {"category": CATEGORY_HOUSING, "cost": 420, "income": 140, "label": "Caravan Lv1 (2x1)", "footprint": Vector2i(2, 1), "capacity": 6, "power_use": 4, "water_use": 3, "sewage_use": 3, "waste_use": 2},

	"toilet_block": {"category": CATEGORY_SERVICES, "cost": 180, "income": 0, "label": "Toilet Block (1x1)", "footprint": Vector2i(1, 1), "service_points": 3, "power_use": 1, "water_use": 2, "sewage_use": 2},
	"shower_block": {"category": CATEGORY_SERVICES, "cost": 220, "income": 5, "label": "Shower Block (1x1)", "footprint": Vector2i(1, 1), "service_points": 2, "power_use": 1, "water_use": 3, "sewage_use": 2},
	"pub": {"category": CATEGORY_SERVICES, "cost": 420, "income": 85, "label": "Pub (2x2)", "footprint": Vector2i(2, 2), "service_points": 4, "power_use": 3, "water_use": 2, "waste_use": 2},
	"restaurant": {"category": CATEGORY_SERVICES, "cost": 640, "income": 140, "label": "Restaurant (2x2)", "footprint": Vector2i(2, 2), "service_points": 6, "power_use": 4, "water_use": 3, "sewage_use": 2, "waste_use": 3},
	"vecerka": {"category": CATEGORY_SERVICES, "cost": 350, "income": 75, "label": "Convenience Store (2x2)", "footprint": Vector2i(2, 2), "service_points": 4, "power_use": 2, "water_use": 1, "waste_use": 2},

	"bonfire": {"category": CATEGORY_ATTRACTIONS, "cost": 120, "income": 20, "label": "Bonfire (1x1)", "footprint": Vector2i(1, 1), "attraction_points": 2, "waste_use": 1},
	"sports_field": {"category": CATEGORY_ATTRACTIONS, "cost": 260, "income": 35, "label": "Sports Field (2x1)", "footprint": Vector2i(2, 1), "attraction_points": 3, "power_use": 1},
	"lake_slide": {"category": CATEGORY_ATTRACTIONS, "cost": 380, "income": 55, "label": "Lake Slide (2x1)", "footprint": Vector2i(2, 1), "attraction_points": 4, "power_use": 2, "water_use": 1},

	"power_generator": {"category": CATEGORY_UTILITIES, "cost": 300, "income": 0, "label": "Generator (1x1)", "footprint": Vector2i(1, 1), "power_provide": 12},
	"sewer": {"category": CATEGORY_UTILITIES, "cost": 320, "income": 0, "label": "Sewer (1x1)", "footprint": Vector2i(1, 1), "water_provide": 10, "sewage_provide": 10, "power_use": 2},
	"lamp_post": {"category": CATEGORY_UTILITIES, "cost": 70, "income": 0, "label": "Lamp Post (1x1)", "footprint": Vector2i(1, 1), "power_use": 1},
	# Legacy aliases kept for loading old saves/maps.
	"water_pump": {"category": CATEGORY_UTILITIES, "cost": 320, "income": 0, "label": "Sewer (legacy)", "footprint": Vector2i(1, 1), "water_provide": 10, "sewage_provide": 10, "power_use": 2},
	"sewage_tank": {"category": CATEGORY_UTILITIES, "cost": 320, "income": 0, "label": "Sewer (legacy)", "footprint": Vector2i(1, 1), "water_provide": 10, "sewage_provide": 10, "power_use": 2},
	"dumpsters": {"category": CATEGORY_UTILITIES, "cost": 130, "income": 0, "label": "Dumpsters (1x1)", "footprint": Vector2i(1, 1), "waste_provide": 8},
	"path": {"category": CATEGORY_UTILITIES, "cost": 10, "income": 0, "label": "Path (1x1)", "footprint": Vector2i(1, 1)},

	"demolish": {"category": CATEGORY_UTILITIES, "cost": 0, "income": 0, "label": "Demolish / Bulldozer", "footprint": Vector2i(1, 1)},
}

# var money: int = 500 # Moved to CoreRoot
# var day_number: int = 1 # Moved to CoreRoot
# var _placed_buildings: Array = [] # DEPRECATED: Read from GridModel via _get_placed_buildings()
var _rng := RandomNumberGenerator.new()


func get_failed_count() -> int:
	return CoreRoot.state.failures.size()


func get_failed_entries() -> Array:
	return CoreRoot.state.failures.values()


func _ready() -> void:
	_rng.randomize()
	if OS.is_debug_build():
		_validate_against_building_registry()
	var money_cb = Callable(self, "_on_eventbus_money_changed")
	if EventBus.has_signal("money_changed") and not EventBus.money_changed.is_connected(money_cb):
		EventBus.money_changed.connect(money_cb)
	var day_cb = Callable(self, "_on_eventbus_day_advanced")
	if EventBus.has_signal("day_advanced") and not EventBus.day_advanced.is_connected(day_cb):
		EventBus.day_advanced.connect(day_cb)


## Drift guard for the two building catalogs.
##
## `BUILDING_DATA` here and `res://data/buildings/*.tres` describe the same buildings.
## The .tres set is canonical (BuildingRegistry + the pure core systems read it); this
## dictionary is the legacy builder-UI catalog that is being strangled out. Until it is
## gone, a mismatch means the simulation and the shop disagree -- so shout in debug builds.
func _validate_against_building_registry() -> void:
	if CoreRoot == null or CoreRoot.registry == null:
		return
	for building_type in BUILDING_DATA.keys():
		if UPGRADE_ONLY_TYPES.has(building_type) and building_type in ["water_pump", "sewage_tank"]:
			continue
		if building_type == "demolish":
			continue
		var def = CoreRoot.registry.get_def(building_type)
		if def == null:
			push_warning("EconomyManager: '%s' has no BuildingDef in res://data/buildings/." % building_type)
			continue
		var legacy: Dictionary = BUILDING_DATA[building_type]
		if int(def.cost) != int(legacy.get("cost", 0)):
			push_warning("EconomyManager: cost drift for '%s' (tres=%d, legacy=%d)." % [building_type, def.cost, legacy.get("cost", 0)])
		if def.footprint != legacy.get("footprint", Vector2i(1, 1)):
			push_warning("EconomyManager: footprint drift for '%s'." % building_type)


func _on_eventbus_money_changed(new_amount: int) -> void:
	money_changed.emit(new_amount)


func _on_eventbus_day_advanced(day: int, income: int) -> void:
	day_advanced.emit(day, income)


func can_afford(building_type: String) -> bool:
	var data = BUILDING_DATA.get(building_type)
	if data == null:
		return false
	return CoreRoot.get_money() >= int(data.get("cost", 0))


func get_cost(building_type: String) -> int:
	var data = BUILDING_DATA.get(building_type)
	if data == null:
		return 0
	return int(data.get("cost", 0))


func get_income(building_type: String) -> int:
	var data = BUILDING_DATA.get(building_type)
	if data == null:
		return 0
	return int(data.get("income", 0))


func get_label(building_type: String) -> String:
	var data = BUILDING_DATA.get(building_type)
	if data == null:
		return building_type
	return str(data.get("label", building_type))


func get_category_label(category: String) -> String:
	return str(CATEGORY_LABELS.get(category, category))


func get_builder_categories() -> Array[String]:
	return BUILDER_CATEGORIES.duplicate()


func get_builder_catalog(category: String) -> Array:
	var items: Array = []
	for type in BUILDING_DATA.keys():
		var data = BUILDING_DATA[type]
		if str(data.get("category", "")) != category:
			continue
		if type == "demolish":
			continue
		if UPGRADE_ONLY_TYPES.has(type):
			continue
		items.append({
			"type": type,
			"label": str(data.get("label", type)),
			"cost": int(data.get("cost", 0)),
		})
	items.sort_custom(func(a, b): return int(a["cost"]) < int(b["cost"]))
	return items


func can_build_from_builder(building_type: String) -> bool:
	if building_type == "demolish":
		return true
	
	# Try Registry first
	var def = CoreRoot.registry.get_def(building_type)
	if def:
		return not def.id in UPGRADE_ONLY_TYPES # Check id in dictionary
		
	return not UPGRADE_ONLY_TYPES.has(building_type)


func get_money() -> int:
	return CoreRoot.get_money()


func purchase(_building_type: String) -> bool:
	# LEGACY REDIRECT TO ACTIONS
	push_error("EconomyManager: purchase() called without coord. Legacy UI should use LegacyUIAdapter.")
	return false

func spend_money(amount: int) -> bool:
	return CoreRoot.actions.spend_money(amount)

func add_money(amount: int) -> void:
	CoreRoot.actions.add_money(amount)


func get_refund(building_type: String) -> int:
	var cost = get_cost(building_type)
	if cost <= 0:
		return 0
	return int(round(float(cost) * 0.5))


func register_building(_type: String, _coord: Vector2i, _comfort: float = 1.0) -> void:
	# NO-OP: GridModel is now updated directly by Actions.
	pass

func unregister_building_at(_coord: Vector2i, _type: String = "") -> bool:
	# NO-OP: GridModel is now updated directly by Actions.
	return true


func calculate_day_income() -> int:
	var total: int = 0
	for entry in _get_placed_buildings():
		var btype = str(entry.get("type", ""))
		# Try Registry first
		var income = 0
		var def = CoreRoot.registry.get_def(btype)
		if def:
			income = int(round(float(def.passive_income)))
		elif BUILDING_DATA.has(btype):
			income = int(BUILDING_DATA[btype].get("income", 0))
			
		if income <= 0: continue
		
		if _is_failed_coord(entry.get("coord", Vector2i.ZERO)):
			income = int(round(float(income) * 0.35))
		
		var comfort = float(entry.get("comfort", 1.0))
		total += int(income * comfort)
	return total


func end_day() -> void:
	# Legacy compatibility path: route through the canonical day_tick flow.
	var next_day := CoreRoot.get_day() + 1
	CoreRoot.apply_changes({"day": next_day})
	EventBus.day_tick.emit(next_day)


func get_building_at(coord: Vector2i) -> Dictionary:
	var data = CoreRoot.state.grid.get_building_at(coord)
	if data.is_empty(): return {}
	return {
		"type": data.type,
		"coord": data.root_coord,
		"comfort": data.get("maintenance", 1.0) # Mapping maintenance to comfort for legacy
	}

func upgrade_comfort(_coord: Vector2i, _amount: float) -> void:
	# NO-OP: Should be handled by Actions/Systems
	pass


func get_utility_balance() -> Dictionary:
	var provided = {"power": 0, "water": 0, "sewage": 0, "waste": 0}
	var used = {"power": 0, "water": 0, "sewage": 0, "waste": 0}
	var capacity_total := 0

	for entry in _get_placed_buildings():
		var btype = str(entry.get("type", ""))
		var coord = entry.get("coord", Vector2i.ZERO)
		var is_failed = _is_failed_coord(coord)
		var power_use: int = _resolve_power_use_for_type(btype)
		
		# Get data from Registry or Legacy dict
		var def = CoreRoot.registry.get_def(btype)
		if def:
			capacity_total += def.capacity
			if not (is_failed and def.category == CATEGORY_UTILITIES):
				provided["power"] += def.power_provide
				provided["water"] += def.water_provide
				provided["sewage"] += def.sewage_provide
				provided["waste"] += def.waste_provide
			used["power"] += power_use
			used["water"] += def.water_use
			used["sewage"] += def.sewage_use
			used["waste"] += def.waste_use
		elif BUILDING_DATA.has(btype):
			var data = BUILDING_DATA[btype]
			capacity_total += int(data.get("capacity", 0))
			if not (is_failed and data.get("category") == CATEGORY_UTILITIES):
				provided["power"] += int(data.get("power_provide", 0))
				provided["water"] += int(data.get("water_provide", 0))
				provided["sewage"] += int(data.get("sewage_provide", 0))
				provided["waste"] += int(data.get("waste_provide", 0))
			used["power"] += power_use
			used["water"] += int(data.get("water_use", 0))
			used["sewage"] += int(data.get("sewage_use", 0))
			used["waste"] += int(data.get("waste_use", 0))

	# Placeholder host consumption model (to be replaced later by real guest sim).
	used["power"] += int(ceil(float(capacity_total) * 0.4))
	used["water"] += int(ceil(float(capacity_total) * 0.7))
	used["sewage"] += int(ceil(float(capacity_total) * 0.6))
	used["waste"] += int(ceil(float(capacity_total) * 0.35))

	return {
		"provided": provided,
		"used": used,
		"capacity_total": capacity_total,
	}

func _get_placed_buildings() -> Array:
	var list = []
	var seen_ids = {}
	for coord in CoreRoot.state.grid.cells:
		var data = CoreRoot.state.grid.cells[coord]
		var id = data.get("id", "")
		if id != "" and not seen_ids.has(id):
			seen_ids[id] = true
			list.append({
				"type": data.type,
				"coord": data.root_coord,
				"comfort": data.get("maintenance", 1.0)
			})
	return list


func get_manager_status_lines() -> Array:
	var lines: Array = []
	var util = get_utility_balance()
	var provided = util["provided"]
	var used = util["used"]

	lines.append(_format_metric_line("PWR", int(used["power"]), int(provided["power"])))
	lines.append(_format_metric_line("H2O", int(used["water"]), int(provided["water"])))
	lines.append(_format_metric_line("SEW", int(used["sewage"]), int(provided["sewage"])))
	lines.append(_format_metric_line("WST", int(used["waste"]), int(provided["waste"])))
	lines.append("ACTIVE FAILURES: %d" % get_failed_count())

	var alerts = _collect_placeholder_alerts()
	if not alerts.is_empty():
		lines.append_array(alerts)
	return lines


func _format_metric_line(label: String, used_value: int, provided_value: int) -> String:
	var state = "OK"
	if used_value > provided_value:
		state = "SHORTAGE"
	return "%s %d/%d %s" % [label, used_value, provided_value, state]


func _collect_placeholder_alerts() -> Array:
	var alerts: Array = []
	for key in CoreRoot.state.failures.keys():
		var entry = CoreRoot.state.failures[key]
		var btype = str(entry.get("type", ""))
		var coord = entry.get("coord", _coord_from_key_string(str(key)))
		alerts.append("FAILURE: %s [%d,%d] -> repair minigame" % [get_label(btype), coord.x, coord.y])
	return alerts


func has_failed_utility_at(coord: Vector2i) -> bool:
	return CoreRoot.state.failures.has(_coord_key(coord))


func get_failed_entry_at(coord: Vector2i) -> Dictionary:
	var key = _coord_key(coord)
	return CoreRoot.state.failures.get(key, {})


func add_repair_progress(coord: Vector2i, amount: float) -> Dictionary:
	var key = _coord_key(coord)
	var success = CoreRoot.actions.repair_building(coord, amount)
	
	var failure = CoreRoot.state.failures.get(key, {})
	if failure.is_empty() and success:
		return {"valid": true, "done": true, "progress": 1.0, "type": ""} # Type is lost on erase but usually not needed for UI return here
	
	if failure.is_empty():
		return {"valid": false, "done": false, "progress": 0.0, "type": ""}
		
	return {
		"valid": true, 
		"done": false, 
		"progress": failure.get("repair_progress", 0.0), 
		"type": str(failure.get("type", ""))
	}


func decay_repair_progress(_coord: Vector2i, _amount: float) -> float:
	# Simplified or NO-OP as Actions handles repair now
	return 0.0


func _is_failed_coord(coord: Vector2i) -> bool:
	return CoreRoot.state.failures.has(_coord_key(coord))


func _coord_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]


func _coord_from_key_string(key: String) -> Vector2i:
	var parts = key.split(":")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func get_building_counts_by_category() -> Dictionary:
	var counts: Dictionary = {}
	for entry in _get_placed_buildings():
		var btype = str(entry.get("type", ""))
		var data = BUILDING_DATA.get(btype, {})
		if data.is_empty():
			continue
		var cat = str(data.get("category", ""))
		if not counts.has(cat):
			counts[cat] = 0
		counts[cat] += 1
	return counts


func get_income_breakdown() -> Array:
	var breakdown: Array = []
	var type_totals: Dictionary = {}
	for entry in _get_placed_buildings():
		var btype = str(entry.get("type", ""))
		var data = BUILDING_DATA.get(btype, {})
		if data.is_empty():
			continue
		var base = int(data.get("income", 0))
		if base <= 0:
			continue
		if _is_failed_coord(entry.get("coord", Vector2i.ZERO)):
			base = int(round(float(base) * 0.35))
		if not type_totals.has(btype):
			type_totals[btype] = {"count": 0, "total": 0, "label": get_label(btype)}
		type_totals[btype]["count"] += 1
		type_totals[btype]["total"] += base
	for btype in type_totals.keys():
		var info = type_totals[btype]
		breakdown.append("%s x%d: $%d" % [info["label"], info["count"], info["total"]])
	return breakdown


func get_power_draw_breakdown() -> Array:
	var breakdown: Array = []
	for entry in _get_placed_buildings():
		var btype = str(entry.get("type", ""))
		if btype.is_empty():
			continue
		if _is_power_breakdown_hidden_type(btype):
			continue
		var power_use: int = _resolve_power_use_for_type(btype)
		if power_use <= 0:
			continue
		var coord = _coord_from_variant(entry.get("coord", Vector2i.ZERO))
		breakdown.append({
			"type": btype,
			"label": get_label(btype),
			"coord": coord,
			"power_use": power_use,
		})
	breakdown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("power_use", 0))
		var pb := int(b.get("power_use", 0))
		if pa == pb:
			return str(a.get("label", "")) < str(b.get("label", ""))
		return pa > pb
	)
	return breakdown


func _resolve_power_use_for_type(building_type: String) -> int:
	var normalized := building_type.to_lower().strip_edges()
	if normalized.begins_with("tent"):
		return 0
	if normalized == "path" or normalized == "demolish":
		return 0
	var def = CoreRoot.registry.get_def(building_type)
	if def:
		var def_power_use: int = maxi(0, int(def.power_use))
		if def_power_use > 0:
			return def_power_use
		if float(def.power_draw) > 0.0:
			return max(0, ceili(float(def.power_draw)))
	if BUILDING_DATA.has(building_type):
		return max(0, int(BUILDING_DATA[building_type].get("power_use", 0)))
	return 0


func _is_power_breakdown_hidden_type(building_type: String) -> bool:
	var normalized := building_type.to_lower().strip_edges()
	return normalized == "path" or normalized == "demolish"


func _coord_from_variant(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	if value is Vector2:
		var vec2 := value as Vector2
		return Vector2i(int(vec2.x), int(vec2.y))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
	if value is Array:
		var arr := value as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i.ZERO


func get_total_capacity() -> int:
	var total := 0
	for entry in _get_placed_buildings():
		var btype = str(entry.get("type", ""))
		var def = CoreRoot.registry.get_def(btype)
		if def:
			total += def.capacity
		elif BUILDING_DATA.has(btype):
			total += int(BUILDING_DATA[btype].get("capacity", 0))
	return total
