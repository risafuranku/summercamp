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
##   corn     a guest has wandered into the corn maze past the west fence: find them and
##            bring them back (scripts/corn_hunt.gd). Only with wanderers in camp
##            (drunks, families, tramps, mushroom pickers).
##   frozen   on a hard frost (the last third of the autumn, core/systems/season.gd) the
##            pipes freeze: the water pump, the showers or the toilets are out until you
##            thaw them (the ordinary repair). On the coldest nights, twice.
## Each job pages you, shows in the HUD's TONIGHT list and gets the waypoint. Jobs left
## at dawn are not forgiven: a tripped main stays off until somebody resets it, you at
## the board or the electrician you ring (and pay).
##
## Lamp, sewer and toilet jobs are ordinary breakdowns (FailureSystem); the director
## only decides when they happen. The breaker is its own state, read by main.

signal changed

const ELECTRICIAN_FEE := 60
const QUIET_NIGHTS := 1
const CIRCUIT_NAMES := ["LAMPS NORTH", "LAMPS SOUTH", "OFFICE", "FOOD", "WASH BLOCK", "PUMP"]
const FIRST_HOUR := 21.0
const LAST_HOUR := 28.5  # 04:30 next morning
const OMENS = preload("res://scripts/omens.gd")

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
	# A frost night in a tent: they say so.
	var night := _planned_night
	if night >= 1 and Season.temp_low(night) <= 0 and GuestManager != null and GuestManager.has_method("apply_cold_night"):
		var n: int = GuestManager.apply_cold_night(Season.temp_low(night))
		if n > 0:
			_report("A frost in the night. The people in the tents are not happy (%d)." % n, 2)
	# Nobody comes by themselves: the main stays off until you reset it at the board, and
	# a circuit that had to stay off stays off until the electrician has been (you ring
	# him: his number is on the noticeboard, scripts/reception/electrician_visit.gd).
	if breaker_tripped:
		_report("Morning, and the main is still off. The board at the generator, or ring Novotny (the number is on the office noticeboard).", 3)
	elif dead_circuit >= 0:
		_report("The %s circuit is still off. Novotny can put it right: his number is on the noticeboard." % CIRCUIT_NAMES[clampi(dead_circuit, 0, CIRCUIT_NAMES.size() - 1)].to_lower(), 2)
	for job in _jobs:
		if str(job["state"]) == "pending":
			job["state"] = "cancelled"
		elif str(job["kind"]) == "corn" and str(job["state"]) == "open":
			# Nobody went in after them: they come out on their own at first light.
			if _main != null and _main.has_method("end_corn_hunt"):
				_main.end_corn_hunt()
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
	call_deferred("_resume_corn")
	changed.emit()


## A save made while someone was lost in the corn: they are still in there.
func _resume_corn() -> void:
	for job in _jobs:
		if str(job["kind"]) == "corn" and str(job["state"]) == "open" and not job.has("rescued"):
			if _main == null or not _main.has_method("start_corn_hunt") or not _main.start_corn_hunt(job):
				job["state"] = "cancelled"


# ── planning ──────────────────────────────────────────────────────────────────

func _plan(night_index: int, abs_minute: int) -> void:
	_planned_night = night_index
	_jobs = _jobs.filter(func(j): return str(j["state"]) == "open")
	# The first night is quiet (main.QUIET_NIGHTS): no jobs either.
	if night_index <= QUIET_NIGHTS:
		changed.emit()
		return
	var count := clampi(1 + int(ceil(float(night_index) / 2.0)), 2, 4)
	var pool := _available_kinds()
	if pool.is_empty():
		return
	var kinds: Array = []
	# The frost comes first: on a hard-frost night the pipes freeze, on the coldest twice.
	var frozen := _coords_of(["water_pump", "shower_block", "toilet_block"])
	if not frozen.is_empty() and Season.hard_frost(night_index) and _rng.randf() < 0.85:
		kinds.append("frozen")
		if Season.temp_low(night_index) <= -5 and frozen.size() > 1:
			kinds.append("frozen")
	# The sewer only breaks because the raccoon chewed through it, and it is out more the
	# harder the night presses on the camp (pipes/pipe_director.gd).
	if pool.has("sewer") and _rng.randf() < sewer_chance(_night_pressure()):
		kinds.append("sewer")
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
		if k == "breaker" or k == "frozen" or k == "sewer" or (kinds.has(k) and not (k == "lamp" and kinds.count("lamp") < lamp_count)):
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


## How likely the raccoon is to be in the sewer tonight, from the night's pressure.
static func sewer_chance(pressure: float) -> float:
	return clampf(0.1 + 0.14 * pressure, 0.1, 0.85)


func _night_pressure() -> float:
	if _main != null and _main.has_method("_omen_context"):
		var ctx = _main.call("_omen_context")
		if ctx is Dictionary:
			return OMENS.pressure(ctx)
	return 1.0


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
	if _main != null and _main.has_method("corn_hunt_possible") and _main.corn_hunt_possible():
		out.append("corn")
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
			job.merge({"title": "Sewer leaking", "short": "Sewer", "where": "The sewer hatch: crawl in", "coord": [s.x, s.y]}, true)
		"corn":
			var gate: Vector3 = _main.corn_gate_world() if _main != null and _main.has_method("corn_gate_world") else Vector3.INF
			job.merge({"title": "Someone is in the corn", "short": "Corn", "where": "The wicket gate in the west fence", "pos": [gate.x, gate.y, gate.z]}, true)
		"frozen":
			var taken: Array = []
			for j in _jobs:
				if str(j.get("kind", "")) == "frozen":
					taken.append(Vector2i(int(j["coord"][0]), int(j["coord"][1])))
			var f := Vector2i(-1, -1)
			for c in _coords_of(["water_pump", "shower_block", "toilet_block"]):
				if not taken.has(c):
					f = c
					break
			var what := "The pipes"
			var state = CoreRoot.get_state()
			if f.x >= 0 and state != null and state.grid.cells.has(f):
				what = {"water_pump": "The water pump", "shower_block": "The showers", "toilet_block": "The toilets"}.get(str(state.grid.cells[f].get("type", "")), "The pipes")
			job.merge({"title": "%s froze" % what, "short": "Frozen", "where": "%d:%d: thaw the pipes" % [f.x, f.y], "coord": [f.x, f.y]}, true)
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
		"corn":
			if _main == null or not _main.has_method("start_corn_hunt") or not _main.start_corn_hunt(job):
				job["state"] = "cancelled"
				return
		"lamp", "sewer", "toilet", "frozen":
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
		"corn":
			return job.has("rescued")
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
	if job.has("pos"):
		var p: Array = job["pos"]
		return Vector3(float(p[0]), float(p[1]), float(p[2])) if float(p[0]) != INF else Vector3.INF
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
