extends Node

## Headless check of the night work: scripts/night_jobs.gd (planning, starting,
## resolving, dawn) and scripts/breaker_panel.gd (the faulty circuit trips the main;
## the electrician's method finds it).
##
##   godot --headless --path godot res://tools/nightjobs_check.tscn

const JOBS := preload("res://scripts/night_jobs.gd")
const BOARD := preload("res://scripts/breaker_panel.gd")

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	state.grid.cells.clear()
	state.failures.clear()
	state.day = 1
	for p in [["power_generator", Vector2i(20, 15)], ["lamp_post", Vector2i(5, 5)], ["lamp_post", Vector2i(5, 20)], ["sewer", Vector2i(3, 24)], ["toilet_block", Vector2i(8, 8)]]:
		state.grid.occupy_cell(p[1], p[0], "%s_x" % p[0], p[1])

	var jobs = JOBS.new()
	add_child(jobs)
	jobs.setup(null)
	var money_before: int = CoreRoot.get_money()

	# Night 1 starts at 20:00 of day 1: two jobs, spread over the night.
	var night_start := 20 * 60
	jobs.tick(night_start, true, 1)
	var planned: Array = jobs._jobs
	_expect(planned.size() == 2, "night 1 plans two jobs (%d)" % planned.size())
	for j in planned:
		var at := int(j["at"])
		_expect(at >= 21 * 60 and at <= 28 * 60 + 30, "job %s at %02d:%02d is within 21:00-04:30" % [j["kind"], (at / 60) % 24, at % 60])

	# Run the night minute by minute; resolve breakdowns as a player would.
	var saw_breaker := false
	var saw_failure := false
	for minute in range(night_start, 30 * 60 + 30):
		jobs.tick(minute, true, 1)
		if jobs.breaker_tripped:
			saw_breaker = true
		for key in state.failures.keys():
			saw_failure = true
			state.failures.erase(key)
	print("NIGHTJOBS CHECK: night 1 jobs ", jobs._jobs.map(func(j): return [j["kind"], j["state"], j["at"]]))
	_expect(saw_breaker or saw_failure, "the night's jobs start")
	for j in jobs._jobs:
		_expect(str(j["state"]) != "cancelled", "a planned %s job is not cancelled on a camp that has one" % j["kind"])
	_expect(jobs.open_jobs().size() <= 1, "resolved breakdowns close their jobs (%d open)" % jobs.open_jobs().size())

	# A breaker left tripped until dawn: the electrician resets it, for a fee.
	jobs.breaker_tripped = true
	jobs.on_dawn()
	_expect(not jobs.breaker_tripped, "dawn resets the breaker")
	_expect(CoreRoot.get_money() == money_before - JOBS.ELECTRICIAN_FEE, "and the electrician is paid (%d -> %d)" % [money_before, CoreRoot.get_money()])

	# Night 7: up to four jobs.
	jobs.tick(6 * 1440 + 20 * 60, true, 7)
	_expect(jobs._jobs.size() >= 3, "a late night has more work (%d jobs)" % jobs._jobs.size())

	# A lamp circuit left off darkens half the camp's lamps.
	jobs.dead_circuit = 0
	var dark: Array = jobs.extra_dark_lamps(["5:5", "5:20"], 28)
	_expect(dark == ["5:20"], "LAMPS NORTH off darkens the northern lamps (%s)" % [dark])
	jobs.dead_circuit = 3
	_expect(jobs.extra_dark_lamps(["5:5", "5:20"], 28).is_empty(), "a non-lamp circuit darkens no lamps")

	# ── the distribution board ──
	var board = BOARD.new()
	add_child(board)
	# Lambdas capture locals by value: collect into an array.
	var fixed_with: Array = []
	board.fixed.connect(func(f): fixed_with.append(f))
	board.open(2)
	# Main up with everything up: it throws itself.
	board._main_on = true
	for i in 20:
		board._process(0.05)
	_expect(not board._main_on, "the faulty circuit trips the main")
	# Everything down, main up: it holds (nothing on it yet).
	for i in 6:
		board._up[i] = false
	board._main_on = true
	for i in 20:
		board._process(0.05)
	_expect(board._main_on, "with every circuit down the main holds")
	# One at a time: the faulty one throws it; leave it down, the rest up.
	var found := -1
	for c in 6:
		board._up[c] = true
		for i in 20:
			board._process(0.05)
		if not board._main_on:
			found = c
			board._up[c] = false
			board._main_on = true
	_expect(found == 2, "one at a time finds the fault (%d)" % found)
	for i in 40:
		board._process(0.05)
	_expect(fixed_with == [2], "the main holding with the other five up fixes the board (%s)" % [fixed_with])

	print("")
	if _failures.is_empty():
		print("NIGHTJOBS CHECK: PASS")
		get_tree().quit(0)
	else:
		print("NIGHTJOBS CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
