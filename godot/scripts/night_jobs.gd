extends Node

## Work for the night (DESIGN.md §5b). A dark camp is not only something to survive:
## things go wrong after 20:00 and you are the one who goes out to them.
##
## When the night starts, a few jobs are planned for it (two on the first nights, up
## to four later), spread between 21:00 and 04:30:
##   breaker  the main at the generator trips: every lamp out, powered facilities shut.
##            Fixed at the distribution board (scripts/breaker_panel.gd); the faulty
##            circuit stays off for the rest of the night (half the lamps, if it was a
##            lamp circuit).
##   lamp     a lamp post's bulb goes: that lamp is dark until you hold R at it.
##   sewer    the sewer clogs: toilets and showers close until you crawl the pipes.
##   toilet   the toilet block blocks: go in and unblock it (service_interior).
## Each job pages you, shows in the HUD's TONIGHT list and gets the waypoint. Jobs left
## at dawn are not forgiven: a tripped breaker is reset by an electrician you pay.
##
## Lamp, sewer and toilet jobs are ordinary breakdowns (FailureSystem); the director
## only decides when they happen. The breaker is its own state, read by main.

signal changed

const ELECTRICIAN_FEE := 60
const FIRST_HOUR := 21.0
const LAST_HOUR := 28.5  # 04:30 next morning

var breaker_tripped := false
## Circuit left off after the breaker was fixed (0 lamps north, 1 lamps south, ...), -1.
var dead_circuit := -1
var _fault := 0
var _jobs: Array = []
var _planned_night := -1
var _rng := RandomNumberGenerator.new()
var _main: Node


func setup(main_node: Node) -> void:
	_main = main_node
	_rng.randomize()


func reset() -> void:
	breaker_tripped = false
	dead_circuit = -1
	_jobs.clear()
	_planned_night = -1


## Called every frame with the clock. `night_index` is the day the night started on.
func tick(abs_minute: int, is_night: bool, night_index: int) -> void:
	if is_night and _planned_night != night_index:
		_plan(night_index, abs_minute)
	for job in _jobs:
		match str(job["state"]):
			"pending":
				if abs_minute >= int(job["at"]):
					_start(job)
			"open":
				if _is_resolved(job):
					job["state"] = "done"
					_report("%s: sorted." % str(job["title"]), 1)
					changed.emit()


## Dawn: the night's leftovers.
func on_dawn() -> void:
	if breaker_tripped:
		breaker_tripped = false
		if CoreRoot.actions != null:
			CoreRoot.actions.add_money(-ELECTRICIAN_FEE)
		_report("The electrician came at six and reset the main: -$%d." % ELECTRICIAN_FEE, 3)
	dead_circuit = -1
	for job in _jobs:
		if str(job["state"]) == "pending":
			job["state"] = "cancelled"
	_jobs = _jobs.filter(func(j): return str(j["state"]) == "open")
	changed.emit()


func open_jobs() -> Array:
	var out: Array = []
	for job in _jobs:
		if str(job["state"]) == "open":
			out.append(job.duplicate())
	return out


func hud_rows() -> Array:
	var rows: Array = []
	for job in _jobs:
		if str(job["state"]) == "open":
			rows.append({"title": job["title"], "where": job["where"]})
	return rows


## Where the nearest open job is (for the waypoint), or Vector3.INF.
func waypoint(from: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for job in _jobs:
		if str(job["state"]) != "open":
			continue
		var p := _world_pos(job)
		if p == Vector3.INF:
			continue
		var d := from.distance_to(p)
		if d < best_d:
			best_d = d
			best = {"position": p + Vector3(0, 2.4, 0), "label": str(job["short"])}
	return best


func breaker_fault() -> int:
	return _fault


## The board says the main holds again.
func on_breaker_fixed(fault_index: int) -> void:
	breaker_tripped = false
	dead_circuit = fault_index
	changed.emit()


## Lamps that are dark for the night's reasons (on top of lamp breakdowns): the dead
## circuit, if it was a lamp circuit, takes the north or south half of the camp.
func extra_dark_lamps(lamp_keys: Array, grid_height: int) -> Array:
	if dead_circuit != 0 and dead_circuit != 1:
		return []
	var out: Array = []
	for k in lamp_keys:
		var y := int(str(k).get_slice(":", 1))
		var north := y >= int(grid_height / 2)
		if (dead_circuit == 0 and north) or (dead_circuit == 1 and not north):
			out.append(k)
	return out


func export_state() -> Dictionary:
	return {"breaker_tripped": breaker_tripped, "dead_circuit": dead_circuit, "fault": _fault, "jobs": _jobs.duplicate(true), "planned_night": _planned_night}


func import_state(data: Dictionary) -> void:
	reset()
	breaker_tripped = bool(data.get("breaker_tripped", false))
	dead_circuit = int(data.get("dead_circuit", -1))
	_fault = int(data.get("fault", 0))
	_planned_night = int(data.get("planned_night", -1))
	for j in data.get("jobs", []):
		if j is Dictionary:
			_jobs.append(j)
	changed.emit()


# ── planning ──────────────────────────────────────────────────────────────────

func _plan(night_index: int, abs_minute: int) -> void:
	_planned_night = night_index
	_jobs = _jobs.filter(func(j): return str(j["state"]) == "open")
	var count := clampi(1 + int(ceil(float(night_index) / 2.0)), 2, 4)
	var pool := _available_kinds()
	if pool.is_empty():
		return
	var kinds: Array = []
	# The breaker is the signature job: most nights have one.
	if pool.has("breaker") and _rng.randf() < 0.8:
		kinds.append("breaker")
	# Different kinds of trouble before any repeats; only lamps can go twice (there are
	# several).
	var lamp_count := _coords_of(["lamp_post"]).size()
	for _attempt in 24:
		if kinds.size() >= count:
			break
		var k: String = pool[_rng.randi_range(0, pool.size() - 1)]
		if k == "breaker" or (kinds.has(k) and not (k == "lamp" and kinds.count("lamp") < lamp_count)):
			continue
		kinds.append(k)
	kinds.shuffle()
	var night_start := abs_minute - int(posmod(abs_minute, 1440)) + int(FIRST_HOUR * 60.0)
	if posmod(abs_minute, 1440) < 12 * 60:
		night_start -= 1440
	var span := int((LAST_HOUR - FIRST_HOUR) * 60.0)
	for i in kinds.size():
		var slot := span * (float(i) + _rng.randf_range(0.15, 0.85)) / float(kinds.size())
		var at := maxi(abs_minute + 10, night_start + int(slot))
		_jobs.append(_make(kinds[i], at))
	changed.emit()


func _available_kinds() -> Array[String]:
	var out: Array[String] = []
	if not _coords_of(["power_generator"]).is_empty():
		out.append("breaker")
	if not _coords_of(["lamp_post"]).is_empty():
		out.append("lamp")
	if not _coords_of(["sewer"]).is_empty() and not _coords_of(["toilet_block", "shower_block"]).is_empty():
		out.append("sewer")
	if not _coords_of(["toilet_block"]).is_empty():
		out.append("toilet")
	return out


func _make(kind: String, at: int) -> Dictionary:
	var job := {"kind": kind, "at": at, "state": "pending", "coord": [-1, -1]}
	match kind:
		"breaker":
			var g := _pick(["power_generator"])
			job.merge({"title": "Power out", "short": "Breaker", "where": "Generator: the distribution board", "coord": [g.x, g.y]}, true)
		"lamp":
			var l := _pick(["lamp_post"])
			job.merge({"title": "A lamp went out", "short": "Lamp", "where": "Lamp %d:%d, hold R" % [l.x, l.y], "coord": [l.x, l.y]}, true)
		"sewer":
			var s := _pick(["sewer"])
			job.merge({"title": "Sewer blocked", "short": "Sewer", "where": "The sewer hatch: crawl in", "coord": [s.x, s.y]}, true)
		"toilet":
			var t := _pick(["toilet_block"])
			job.merge({"title": "Toilets blocked", "short": "Toilets", "where": "Toilet block %d:%d: go in and unblock it" % [t.x, t.y], "coord": [t.x, t.y]}, true)
	return job


func _start(job: Dictionary) -> void:
	var c := Vector2i(int(job["coord"][0]), int(job["coord"][1]))
	match str(job["kind"]):
		"breaker":
			if breaker_tripped:
				job["state"] = "cancelled"
				return
			breaker_tripped = true
			dead_circuit = -1
			_fault = _rng.randi_range(0, 5)
		"lamp", "sewer", "toilet":
			var state = CoreRoot.get_state()
			var key := "%d:%d" % [c.x, c.y]
			if c.x < 0 or state.failures.has(key) or not state.grid.cells.has(c):
				job["state"] = "cancelled"
				return
			var type := str(state.grid.cells[c].get("type", ""))
			CoreRoot.failure_system._trigger_failure(key, type, c)
	job["state"] = "open"
	_report("Pager: %s. %s." % [str(job["title"]), str(job["where"])], 2)
	_page()
	changed.emit()


func _is_resolved(job: Dictionary) -> bool:
	match str(job["kind"]):
		"breaker":
			return not breaker_tripped
		_:
			var c: Array = job["coord"]
			return not CoreRoot.get_state().failures.has("%d:%d" % [int(c[0]), int(c[1])])


# ── helpers ───────────────────────────────────────────────────────────────────

func _coords_of(types: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return out
	for coord in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[coord]
		if cell.get("root_coord", coord) == coord and types.has(str(cell.get("type", ""))):
			out.append(coord)
		elif types.has("lamp_post") and str(cell.get("type", "")) == "path" and bool(cell.get("lamp", false)):
			out.append(coord)
	return out


func _pick(types: Array) -> Vector2i:
	var all := _coords_of(types)
	if all.is_empty():
		return Vector2i(-1, -1)
	return all[_rng.randi_range(0, all.size() - 1)]


func _world_pos(job: Dictionary) -> Vector3:
	var gm = _main.get("grid_manager") if _main != null else null
	var c: Array = job["coord"]
	if gm == null or int(c[0]) < 0:
		return Vector3.INF
	return gm.grid_to_world(Vector2i(int(c[0]), int(c[1])))


func _report(text: String, kind: int) -> void:
	var hud = _main.get("_hud_manager") if _main != null else null
	if hud != null:
		hud.push_status(text, kind, "night_jobs")


func _page() -> void:
	var hud = _main.get("_hud_manager") if _main != null else null
	if hud != null and hud.has_method("page"):
		hud.page()
