extends Node

## Headless check for a sandbox camp's land (core/systems/plot_rules.gd, Richard 25. 11.: „Pozemek
## se kupuje“, „Po pásech od plotu“, „Rostoucí“, „Hranice z kolíků“): the plots a camp starts
## on, the strips along a side, their growing price, a strip bought through the authority (money
## paid, the plot grown, the world told), nothing built nor bulldozed off the plot, and the
## whole camp with nothing left to buy.
##
##   godot --headless --path godot res://tools/plot_check.tscn

const PLOT := preload("res://core/systems/plot_rules.gd")

var _failures: Array[String] = []
var _bought: Array = []
var _turned: Array = []


func _ready() -> void:
	var g := Vector2i(28, 28)
	# The rules.
	_expect(PLOT.start(2, g, 15).is_empty(), "the whole camp: no plot")
	var small := PLOT.start(0, g, 15)
	_expect(small == [9, 0, 21, 12], "the small plot round the gate lane (%s)" % [small])
	_expect(PLOT.start(1, g, 15) == [5, 0, 25, 18], "the middle one (%s)" % [PLOT.start(1, g, 15)])
	_expect(PLOT.contains(small, g, Vector2i(15, 0)) and not PLOT.contains(small, g, Vector2i(8, 5)) and PLOT.contains([], g, Vector2i(0, 27)), "on and off the plot")
	_expect(PLOT.fits(small, g, Vector2i(10, 2), Vector2i(2, 2)) and not PLOT.fits(small, g, Vector2i(20, 2), Vector2i(2, 2)), "a cabin on it, one half off")
	_expect(PLOT.strip(small, g, "west") == Rect2i(5, 0, 4, 12) and PLOT.strip(small, g, "north") == Rect2i(9, 12, 12, 4), "a strip four wide along a side")
	_expect(PLOT.grow(small, g, "east") == [9, 0, 25, 12], "the east strip bought")
	_expect(PLOT.strip([0, 0, 28, 26], g, "north") == Rect2i(0, 26, 28, 2) and PLOT.grow([0, 0, 28, 26], g, "north").is_empty(), "the last strip as wide as is left, then the whole camp")
	_expect(PLOT.price(0) == 260 and PLOT.price(1) == 390 and PLOT.price(2) == 585, "half again dearer each (%d %d %d)" % [PLOT.price(0), PLOT.price(1), PLOT.price(2)])

	# Through the authority.
	var st = CoreRoot.get_state()
	st.grid.init_dimensions(28, 28, 4.0)
	st.grid.cells.clear()
	st.sites = {}
	st.money = 100000
	CoreRoot.builder_authority._connect_event_bus()
	EventBus.PlotBought.connect(func(side: String, cost: int) -> void: _bought.append([side, cost]))
	EventBus.BuildRejected.connect(func(_t: String, _at: Vector2i, _r: int, reason: String) -> void: _turned.append(reason))
	CoreRoot.actions.set_plot(small)
	EventBus.RequestBuild.emit("cabin_1", Vector2i(4, 4), 0)
	_expect(st.grid.is_cell_free(Vector2i(4, 4)) and _turned == ["outside_plot"], "no cabin off the plot (%s)" % [_turned])
	EventBus.RequestBuild.emit("cabin_1", Vector2i(10, 4), 0)
	_expect(str(st.grid.get_cell_data(Vector2i(10, 4)).get("type", "")) == "cabin_1", "a cabin on it")
	var m0 := int(st.money)
	EventBus.RequestPlot.emit("west")
	_expect(_bought == [["west", 260]] and m0 - int(st.money) == 260, "the west strip bought for 260 (%s)" % [_bought])
	_expect(CoreRoot.actions.plot_rect() == [5, 0, 21, 12] and int(st.plot["bought"]) == 1, "the plot grown west (%s)" % [st.plot])
	EventBus.RequestBuild.emit("cabin_1", Vector2i(6, 4), 0)
	_expect(str(st.grid.get_cell_data(Vector2i(6, 4)).get("type", "")) == "cabin_1", "built on the strip just bought")
	# Off the plot nothing is bulldozed either (a tree that is not yours).
	st.grid.occupy_cell(Vector2i(1, 20), "tree_spruce", "t1", Vector2i(1, 20))
	EventBus.RequestDemolish.emit(Rect2i(0, 18, 3, 3))
	_expect(not st.grid.is_cell_free(Vector2i(1, 20)), "a tree off the plot stays")
	# No money, no land.
	st.money = 10
	EventBus.RequestPlot.emit("north")
	_expect(_bought.size() == 1 and CoreRoot.actions.plot_rect() == [5, 0, 21, 12], "no money, no strip")
	# The whole camp: nothing to buy.
	CoreRoot.actions.set_plot([])
	st.money = 100000
	EventBus.RequestPlot.emit("east")
	_expect(_bought.size() == 1, "a camp that is all its own buys nothing")

	if _failures.is_empty():
		print("PLOT CHECK: PASS")
	else:
		print("PLOT CHECK: FAIL")
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
