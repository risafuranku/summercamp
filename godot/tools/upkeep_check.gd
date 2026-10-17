extends Node

## Headless check for the upkeep loop. Only the lamps wear (maintenance_rules.gd): they
## lose a little every day and go out when spent; nothing else decays or breaks.
##
##   godot --headless --path godot res://tools/upkeep_check.tscn
##
## Run as a SCENE (CoreRoot / EventBus autoloads). Places buildings straight into the
## grid and asserts:
## - nothing breaks at any condition, however long, except a spent lamp;
## - the daily wear touches only the lamps (on their own tile and on a path), and a
##   spent lamp goes out through EventBus.building_failed;
## - servicing a lamp on a path gives it a new bulb;
## - a broken toilet stops serving guests ("rained_out"/"broken" logic in needs);
## - service_building() restores 100%, clears the failure, charges the cost, and
##   refuses (changing nothing) without the cash;
## - outdoor attractions close in rain.

const RULES = preload("res://core/systems/maintenance_rules.gd")
const NEEDS = preload("res://core/systems/guest_needs_system.gd")

var _failures: Array[String] = []
var _failed_events: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	state.grid.cells.clear()
	state.failures.clear()
	EventBus.building_failed.connect(func(coord: Vector2i, type: String) -> void:
		_failed_events.append([coord, type]))

	_place("toilet_block", Vector2i(2, 2))
	_place("shower_block", Vector2i(4, 2))
	_place("bonfire", Vector2i(6, 2))
	_place("lamp_post", Vector2i(8, 2))
	_place("path", Vector2i(9, 2))
	_place("sewer", Vector2i(10, 2))
	# A lamp on the path.
	var path_cell: Dictionary = state.grid.cells[Vector2i(9, 2)]
	path_cell["lamp"] = true
	state.grid.cells[Vector2i(9, 2)] = path_cell

	var fs = CoreRoot.failure_system
	fs.enabled = true

	# Nothing breaks by chance: 400 hours at 10% condition, no breakdowns at all.
	_set_condition(0.1)
	for h in 400:
		fs.roll_hour()
	_expect(state.failures.is_empty(), "no breakdowns at 10%% condition (got %s)" % ", ".join(state.failures.keys()))

	# The daily wear: only the lamps.
	_set_condition(1.0)
	var ms = CoreRoot.get("maintenance_system")
	if ms == null:
		ms = CoreRoot.get("_maintenance_system")
	_expect(ms != null, "the maintenance system is there")
	if ms != null:
		ms.process_daily_costs()
		_expect(is_equal_approx(float(state.grid.cells[Vector2i(2, 2)].get("maintenance", 1.0)), 1.0), "toilets do not wear")
		_expect(float(state.grid.cells[Vector2i(8, 2)].get("maintenance", 1.0)) < 1.0, "a lamp wears")
		_expect(float(state.grid.cells[Vector2i(9, 2)].get("lamp_maintenance", 1.0)) < 1.0, "a lamp on a path wears")
		_expect(is_equal_approx(float(state.grid.cells[Vector2i(9, 2)].get("maintenance", 1.0)), 1.0), "the path under it does not")

	# A spent lamp goes out (and says so); the others do not.
	var lamp_cell: Dictionary = state.grid.cells[Vector2i(8, 2)]
	lamp_cell["maintenance"] = 0.0
	state.grid.cells[Vector2i(8, 2)] = lamp_cell
	fs.roll_hour()
	_expect(state.failures.has("8:2") and state.failures.size() == 1, "the spent lamp goes out, nothing else")
	_expect(_failed_events.size() == 1, "its going out is announced")

	# A new bulb in the lamp on the path.
	var pc: Dictionary = state.grid.cells[Vector2i(9, 2)]
	pc["lamp_maintenance"] = 0.2
	state.grid.cells[Vector2i(9, 2)] = pc
	state.money = 50
	_expect(CoreRoot.actions.service_building(Vector2i(9, 2), 5), "the lamp on the path is serviced")
	_expect(is_equal_approx(float(state.grid.cells[Vector2i(9, 2)].get("lamp_maintenance", 0.0)), 1.0), "its bulb is new")

	# A broken toilet serves nobody.
	state.failures["2:2"] = {"type": "toilet_block", "coord": Vector2i(2, 2), "since_day": 1, "repair_progress": 0.0}
	var fac := _facility("toilet_block", {"failures": state.failures, "power_available": true, "weather": 0})
	_expect(not fac.is_empty() and not bool(fac["working"]), "broken toilet is not working")

	# Service without cash: refused, nothing changes.
	var def = CoreRoot.registry.get_def(&"toilet_block")
	var cost := RULES.repair_cost(def)
	state.money = cost - 1
	_expect(not CoreRoot.actions.service_building(Vector2i(2, 2), cost), "repair refused without cash")
	_expect(state.failures.has("2:2"), "refused repair leaves the failure")
	# With cash: fixed, full condition, charged.
	state.money = cost + 100
	_expect(CoreRoot.actions.service_building(Vector2i(2, 2), cost), "repair succeeds with cash")
	_expect(not state.failures.has("2:2"), "repair clears the failure")
	_expect(is_equal_approx(float(state.grid.cells[Vector2i(2, 2)].get("maintenance", 0.0)), 1.0), "repair restores 100%")
	_expect(state.money == 100, "repair charged $%d (money now %d)" % [cost, state.money])

	# Rain closes the bonfire, not the toilet.
	state.failures.clear()
	var rainy := {"failures": state.failures, "power_available": true, "weather": 4}
	var bonfire := _facility("bonfire", rainy)
	_expect(not bonfire.is_empty() and str(bonfire["reason"]) == "rained_out", "bonfire is rained out in rain")
	var toilet := _facility("toilet_block", rainy)
	_expect(not toilet.is_empty() and bool(toilet["working"]), "toilet works in rain")
	var dry := _facility("bonfire", {"failures": state.failures, "power_available": true, "weather": 0})
	_expect(not dry.is_empty() and bool(dry["working"]), "bonfire works in clear weather")

	fs.enabled = false
	print("")
	if _failures.is_empty():
		print("UPKEEP CHECK: PASS")
		get_tree().quit(0)
	else:
		print("UPKEEP CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _place(type: String, origin: Vector2i) -> void:
	CoreRoot.get_state().grid.occupy_cell(origin, type, "%s_%d_%d" % [type, origin.x, origin.y], origin)


func _set_condition(value: float) -> void:
	var state = CoreRoot.get_state()
	state.failures.clear()
	_failed_events.clear()
	for c in state.grid.cells.keys():
		var d: Dictionary = state.grid.cells[c]
		d["maintenance"] = value
		state.grid.cells[c] = d


func _facility(type: String, flags: Dictionary) -> Dictionary:
	for f in NEEDS.collect_facilities(CoreRoot.get_state().grid, CoreRoot.registry, flags):
		if str(f["type"]) == type:
			return f
	return {}


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
