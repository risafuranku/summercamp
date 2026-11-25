extends Node

## Headless check for building taking time (Richard 24. 11., docs/pc.md "Rozhodnutí 24. 11.",
## kolo 3; core/systems/construction_rules.gd): what takes the workers how long, their day,
## an order in Builder 98 going up as a site (paid now, a "site" on the grid, what it will be
## in GameState.sites) while a tool's RequestBuild still stands at once, the work counted and
## the building standing when it is done, a site taken down paid back as what it was to be,
## and the clock's runtime (scripts/camp/construction_works.gd) counting the workers' day only.
##
##   godot --headless --path godot res://tools/site_check.tscn

const RULES := preload("res://core/systems/construction_rules.gd")
const WORKS := preload("res://scripts/camp/construction_works.gd")

var _failures: Array[String] = []
var _finished: Array = []


func _ready() -> void:
	# The rules.
	_expect(RULES.hours("tent_1") == 0.0 and RULES.hours("bench") == 0.0 and RULES.hours("caravan_1") == 0.0, "a tent, a bench, a caravan stand at once")
	_expect(RULES.hours("cabin_1") == 2.0 and RULES.hours("pub") == 3.0 and RULES.hours("bowling") == 4.0, "a cabin 2 h, the pub 3 h, the bowling 4 h")
	_expect(not RULES.works_at(6.9) and RULES.works_at(7.0) and RULES.works_at(18.9) and not RULES.works_at(19.0), "the workers' day 7 to 19")
	_expect(is_equal_approx(RULES.work_between(9.5, 12.0), 2.5), "a morning's work")
	_expect(is_equal_approx(RULES.work_between(18.0, 24.0 + 7.0), 1.0), "ordered at six in the evening: one hour, then the night off")
	_expect(is_equal_approx(RULES.work_between(18.0, 24.0 + 9.0), 3.0), "and on from seven next morning")
	_expect(is_equal_approx(RULES.progress({"total": 4.0, "left": 1.0}), 0.75), "how far a site is")

	var state = CoreRoot.get_state()
	state.grid.init_dimensions(30, 30, 4.0)
	state.grid.cells.clear()
	state.sites = {}
	state.money = 100000
	state.day = 1
	CoreRoot.builder_authority._connect_event_bus()
	EventBus.site_finished.connect(func(t: String, at: Vector2i, _r: int) -> void: _finished.append([t, at]))

	# An order: the cabin goes up as a site, paid now.
	var cabin_cost := int(load("res://data/buildings/cabin_1.tres").cost)
	var before := int(state.money)
	EventBus.RequestOrder.emit("cabin_1", Vector2i(3, 3), 0)
	_expect(str(state.grid.get_cell_data(Vector2i(3, 3)).get("type", "")) == RULES.TYPE and str(state.grid.get_cell_data(Vector2i(4, 4)).get("type", "")) == RULES.TYPE,
		"the ordered cabin is a site on all its cells")
	var site: Dictionary = state.sites.get("3:3", {})
	_expect(str(site.get("type", "")) == "cabin_1" and is_equal_approx(float(site.get("total", 0)), 2.0) and (site.get("fp", []) as Array) == [2, 2], "what it will be: a cabin, 2 h, 2x2 (%s)" % [site])
	_expect(before - int(state.money) == cabin_cost, "paid now (%d)" % (before - int(state.money)))
	# A tool's RequestBuild and an order of a tent stand at once.
	EventBus.RequestBuild.emit("cabin_1", Vector2i(8, 3), 0)
	_expect(str(state.grid.get_cell_data(Vector2i(8, 3)).get("type", "")) == "cabin_1" and not state.sites.has("8:3"), "RequestBuild stands it at once")
	EventBus.RequestOrder.emit("tent_1", Vector2i(12, 3), 0)
	_expect(str(state.grid.get_cell_data(Vector2i(12, 3)).get("type", "")) == "tent_1" and not state.sites.has("12:3"), "an ordered tent stands at once")

	# The work: not done at 1.5 h, done past 2 h; then the cabin stands.
	_expect(CoreRoot.actions.site_work(1.5).is_empty() and is_equal_approx(float(state.sites["3:3"]["left"]), 0.5), "an hour and a half: half an hour left")
	_expect(CoreRoot.actions.site_work(0.6) == ["3:3"], "past two hours it is done")
	_expect(CoreRoot.actions.finish_site(Vector2i(3, 3)), "it is finished")
	_expect(str(state.grid.get_cell_data(Vector2i(3, 3)).get("type", "")) == "cabin_1" and str(state.grid.get_cell_data(Vector2i(4, 4)).get("type", "")) == "cabin_1" and not state.sites.has("3:3"),
		"the cabin stands where the site was")
	_expect(_finished == [["cabin_1", Vector2i(3, 3)]], "and the world was told (%s)" % [_finished])
	_expect(not CoreRoot.actions.finish_site(Vector2i(3, 3)), "once")

	# A site taken down is paid back as what it was to be.
	EventBus.RequestOrder.emit("pub", Vector2i(3, 9), 0)
	var m1 := int(state.money)
	CoreRoot.actions.remove_building(Vector2i(3, 9))
	var refund := int(int(load("res://data/buildings/pub.tres").cost) * preload("res://core/balance/balance_config.gd").REFUND_RATIO)
	_expect(int(state.money) - m1 == refund and not state.sites.has("3:9") and state.grid.is_cell_free(Vector2i(3, 9)), "a pub's site taken down: %d back (%d)" % [int(state.money) - m1, refund])

	# The clock: ordered at 18:00, an hour that evening, nothing in the night, done at 8 next day.
	var works = WORKS.new()
	add_child(works)
	EventBus.time_tick.emit(18, 0)
	EventBus.RequestOrder.emit("cabin_1", Vector2i(16, 3), 0)
	EventBus.time_tick.emit(19, 0)
	_expect(is_equal_approx(float(state.sites["16:3"]["left"]), 1.0), "an hour's work by seven in the evening")
	EventBus.time_tick.emit(23, 30)
	_expect(is_equal_approx(float(state.sites["16:3"]["left"]), 1.0), "nobody works in the night")
	state.day = 2
	EventBus.time_tick.emit(7, 30)
	_expect(is_equal_approx(float(state.sites["16:3"]["left"]), 0.5), "half an hour from seven")
	EventBus.time_tick.emit(8, 0)
	_expect(not state.sites.has("16:3") and str(state.grid.get_cell_data(Vector2i(16, 3)).get("type", "")) == "cabin_1", "done at eight: the cabin stands")
	# A load or a new camp (a jump back on the clock) counts nothing.
	EventBus.RequestOrder.emit("cabin_1", Vector2i(20, 3), 0)
	state.day = 1
	EventBus.time_tick.emit(9, 0)
	EventBus.time_tick.emit(10, 0)
	_expect(is_equal_approx(float(state.sites["20:3"]["left"]), 1.0), "after a jump back the clock starts again (%s)" % [state.sites["20:3"]["left"]])

	if _failures.is_empty():
		print("SITE CHECK: PASS")
	else:
		print("SITE CHECK: FAIL")
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
