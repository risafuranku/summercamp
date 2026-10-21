extends Node

## The staffroom's hands at work (DESIGN.md §7c, the rules core/systems/staff_rules.gd).
## The machine that runs the camp (Coop.sim_here) moves each of them on by the game's
## clock and writes where they are and what they are at into biz.staff.act (every state
## is a walk from a to b between two game minutes, a job at a place till a minute, or a
## spot in the staffroom); every machine draws them from it, so both wardens see the same
## hand at the same bin without messages of their own.
##   home    before their hour in the morning and after eight in the evening
##   walk    in from the gate along the camp's paths, out to a job, back, home again
##   coffee  in the morning, on the sofa with a cup (the lounge)
##   rest    lying on their mattress in the boiler room; with no mattress of their own,
##           in a guest's bed (a free made-up lodging: when they get up, it wants making
##           again, and the line says so)
##   work    at a bin bag (litter), at the bins (raccoons, shooed off with the broom), at
##           the wholesaler's van (signing), at a branch (sawing it up), in a lodging
##           (cleaning it, making the bed: one task after another, GuestManager)
## The figures in the camp are Build sprites at the people's pixel (128 px to 1.74 m):
## standing and bobbing as they walk, the broom at work, flat on the mattress or sat on
## the sofa where the staffroom's windows look in (the building's own rooms,
## building_models._staffroom). The room inside draws its own (inside()).
## The other wardens in the staffroom are drawn in its rooms here too when you are
## outside (at the laptop, at the books), and its lamps and curtains are as they are in.

const RULES = preload("res://core/systems/staff_rules.gd")
const PLAN = preload("res://scripts/staff/staffroom_plan.gd")
const ROOM = preload("res://scripts/staff/staffroom.gd")
const ROOM_RULES = preload("res://core/systems/room_rules.gd")
const COOP_FIGURE = preload("res://scripts/coop/remote_player.gd")
const PERSON_M := 1.74
const STEP := 0.5
const WALK_BOB_HZ := 2.4

var _poll := 0.0
var _figs: Dictionary = {}       # slug -> Sprite3D (in the camp)
var _wardens: Dictionary = {}    # peer id -> remote_player figure (in the camp's staffroom)
var _astar := AStarGrid2D.new()
var _nav_t := 0.0
var _nav_ok := false
var _paths: Dictionary = {}      # "ax:az|bx:bz" -> PackedVector3Array
var _t := 0.0


func _ready() -> void:
	add_to_group("staff_runtime")


# ── the camp ─────────────────────────────────────────────────────────────────

func _main() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


func staffroom() -> Node3D:
	if not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group("staffroom"):
		if is_instance_valid(n) and (n as Node3D).is_inside_tree():
			return n as Node3D
	return null


## Its key ("x:y", the grid origin), "" none.
func staffroom_key() -> String:
	var s := staffroom()
	if s == null:
		return ""
	var o = s.get_meta("grid_origin", null)
	return "%d:%d" % [(o as Vector2i).x, (o as Vector2i).y] if o is Vector2i else ""


func _now() -> float:
	var m := _main()
	return float(m._now_abs_minutes_float()) if m != null and m.has_method("_now_abs_minutes_float") else 0.0


func _hour() -> float:
	var m := _main()
	return float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 12.0


func _st() -> Dictionary:
	if CoreRoot == null or CoreRoot.get_state() == null:
		return {}
	var st = CoreRoot.get_state().biz.get("staff", {})
	return st if st is Dictionary else {}


func _crew() -> Array:
	return _st().get("crew", [])


func _acts() -> Dictionary:
	var a = _st().get("act", {})
	return a if a is Dictionary else {}


func _grid():
	var m := _main()
	return m.get("grid_manager") if m != null else null


## The staffroom's front door outside (world, on the ground).
func _door() -> Vector3:
	var s := staffroom()
	if s == null:
		return Vector3.INF
	var p := s.global_transform * Vector3(PLAN.DOOR_X, 0.0, PLAN.L_MAX.y + PLAN.WALL + 0.9)
	p.y = _ground_y(p)
	return p


## Where they come in from in the morning and go out to in the evening: the road
## outside the barrier.
func _gate() -> Vector3:
	var gate := get_tree().get_first_node_in_group("camp_gate") if is_inside_tree() else null
	if gate == null:
		return Vector3.INF
	var p: Vector3 = gate.road_spot()
	p.y = _ground_y(p)
	return p


func _ground_y(p: Vector3) -> float:
	var g = _grid()
	if g == null:
		return p.y
	return float(g.grid_to_world(g.world_to_grid(p)).y)


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]) if a.size() > 2 else 0.0, float(a[2]) if a.size() > 2 else float(a[1]))


static func _a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


# ── the way between two places (the guests' grid: paths are quicker) ─────────

func _rebuild_nav() -> void:
	var g = _grid()
	if g == null:
		return
	var size: Vector2i = g.get_grid_size()
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	var cells: Dictionary = CoreRoot.get_state().grid.cells if CoreRoot != null and CoreRoot.get_state() != null else {}
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			var tile = g.get_tile(c)
			var path := str((cells.get(c, {}) as Dictionary).get("type", "")) == "path"
			var solid: bool = tile == null or int(tile.tile_type) == 1 or ((tile.occupied or tile.occupant != null) and not path)
			_astar.set_point_solid(c, solid)
			if path:
				_astar.set_point_weight_scale(c, 0.6)
	_nav_ok = true
	_paths.clear()


## The nearest open cell to `c`.
func _open_cell(c: Vector2i) -> Vector2i:
	if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
		return c
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if _astar.is_in_boundsv(n) and not _astar.is_point_solid(n):
					return n
	return c


func _path(a: Vector3, b: Vector3) -> PackedVector3Array:
	var key := "%.1f:%.1f|%.1f:%.1f" % [a.x, a.z, b.x, b.z]
	if _paths.has(key):
		return _paths[key]
	var out := PackedVector3Array([a])
	var g = _grid()
	if g != null and _nav_ok:
		var ca: Vector2i = g.world_to_grid(a)
		var cb: Vector2i = g.world_to_grid(b)
		# Off the grid (the road outside the barrier): in by the gate lane first.
		var gate := get_tree().get_first_node_in_group("camp_gate")
		var lane: Array = gate.way_in() if gate != null else []
		var pre: Array = []
		var post: Array = []
		if not _astar.is_in_boundsv(ca) and not lane.is_empty():
			for p in lane:
				pre.append(p)
			ca = g.world_to_grid(lane[-1])
		if not _astar.is_in_boundsv(cb) and not lane.is_empty():
			var back: Array = lane.duplicate()
			back.reverse()
			post = back
			cb = g.world_to_grid(lane[-1])
		for p in pre:
			out.append(Vector3(p.x, _ground_y(p), p.z))
		if _astar.is_in_boundsv(ca) and _astar.is_in_boundsv(cb):
			var ids := _astar.get_id_path(_open_cell(ca), _open_cell(cb))
			for i in range(1, ids.size() - 1):
				out.append(g.grid_to_world(ids[i]))
		for p in post:
			out.append(Vector3(p.x, _ground_y(p), p.z))
	out.append(b)
	_paths[key] = out
	return out


static func _length(path: PackedVector3Array) -> float:
	var d := 0.0
	for i in range(1, path.size()):
		d += path[i - 1].distance_to(path[i])
	return d


static func _along(path: PackedVector3Array, d: float) -> Array:
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if d <= seg or i == path.size() - 1:
			var t := 0.0 if seg < 0.001 else clampf(d / seg, 0.0, 1.0)
			return [path[i - 1].lerp(path[i], t), path[i] - path[i - 1]]
		d -= seg
	return [path[path.size() - 1], Vector3.FORWARD]


# ── the clock (the machine that runs the camp) ───────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	_nav_t -= delta
	if _nav_t <= 0.0:
		_nav_t = 4.0
		_rebuild_nav()
	_poll -= delta
	if _poll <= 0.0:
		_poll = STEP
		if Coop.sim_here() and staffroom() != null:
			_run()
		elif staffroom() == null and not _acts().is_empty() and Coop.sim_here():
			# The staffroom was pulled down: everybody home.
			for slug in _acts().keys():
				CoreRoot.actions.staff_act(str(slug), {})
		_update_camp_side()
	_draw()


func _run() -> void:
	var now := _now()
	var hour := _hour()
	var crew: Array = _crew()
	var acts := _acts()
	for slug in acts.keys():
		var known := false
		for p in crew:
			known = known or str(p.get("slug", "")) == str(slug)
		if not known:
			CoreRoot.actions.staff_act(str(slug), {})
	for i in crew.size():
		var p: Dictionary = crew[i]
		var slug := str(p.get("slug", ""))
		var act: Dictionary = acts.get(slug, {})
		var on := RULES.on_duty(p, hour, i)
		var doing := str(act.get("do", "home"))
		match doing:
			"home":
				if on and hour < RULES.HOME_HOUR - 0.4:
					_walk(slug, _gate(), _door(), {"do": "coffee"})
			"walk":
				var next: Dictionary = act.get("next", {})
				# A job done meanwhile by somebody else: back from where they are.
				if int(act.get("ev", -1)) >= 0 and str(next.get("do", "")) == "work" and not _events_open(int(act["ev"])):
					_back(slug, _pos_of(act, now))
				elif now >= float(act.get("t1", now)):
					_arrive(slug, p, act, now)
			"coffee":
				if not on:
					_leave(slug, act)
				elif now >= float(act.get("t1", 0.0)) and not _find_work(slug, p, act, now):
					_lie_down(slug, p, act, now)
			"rest":
				if not on:
					_leave(slug, act)
				elif now >= float(act.get("t1", 0.0)) and not _find_work(slug, p, act, now):
					act["t1"] = now + 6.0
			"work":
				_work(slug, p, act, now, on)


## A walk from `a` to `b` starting now, then `next` (a state, its t0 the arrival).
func _walk(slug: String, a: Vector3, b: Vector3, next: Dictionary, extra := {}) -> void:
	if a == Vector3.INF or b == Vector3.INF:
		return
	var now := _now()
	var d := _length(_path(a, b))
	var act := {"do": "walk", "a": _a(a), "b": _a(b), "t0": now, "t1": now + d / RULES.WALK_M_PER_MIN, "next": next}
	for k in extra:
		act[k] = extra[k]
	CoreRoot.actions.staff_act(slug, act)


func _arrive(slug: String, p: Dictionary, act: Dictionary, now: float) -> void:
	var next: Dictionary = (act.get("next", {}) as Dictionary).duplicate(true)
	match str(next.get("do", "")):
		"home":
			CoreRoot.actions.staff_act(slug, {"do": "home"})
		"coffee":
			var seat := _free_spot("sofa", slug)
			if seat == "":
				_lie_down(slug, p, act, now)
				return
			CoreRoot.actions.staff_act(slug, {"do": "coffee", "spot": seat, "t0": now, "t1": now + RULES.COFFEE_MIN})
		"rest":
			_lie_down(slug, p, act, now)
		"bed":
			CoreRoot.actions.staff_act(slug, {"do": "rest", "spot": "bed:" + str(next.get("room", "")), "room": str(next.get("room", "")), "t0": now, "t1": now + RULES.REST_MIN, "at": act.get("b")})
		"work":
			next["t0"] = now
			next["at"] = act.get("b")
			var minutes := RULES.work_minutes(str(next.get("what", "")), int(p.get("speed", 1)))
			if str(next.get("what", "")) == "rooms":
				var left := _room_left(str(next.get("room", "")))
				minutes *= maxf(1.0, float(left))
				next["each"] = RULES.work_minutes("rooms", int(p.get("speed", 1)))
			next["t1"] = now + minutes
			CoreRoot.actions.staff_act(slug, next)


## Back in the staffroom (or off to a guest's bed): a mattress of their own if there is
## one free, else the nearest made-up lodging nobody is in.
func _lie_down(slug: String, p: Dictionary, act: Dictionary, now: float) -> void:
	var spot := _free_spot("mat", slug)
	if spot != "":
		CoreRoot.actions.staff_act(slug, {"do": "rest", "spot": spot, "t0": now, "t1": now + RULES.REST_MIN})
		return
	var bed := _guest_bed(slug)
	if bed.is_empty():
		# Nowhere at all: on the sofa, or standing about in the lounge.
		var seat := _free_spot("sofa", slug)
		CoreRoot.actions.staff_act(slug, {"do": "rest", "spot": seat if seat != "" else "stand", "t0": now, "t1": now + RULES.REST_MIN})
		return
	var from := _door()
	_walk(slug, from, bed["pos"], {"do": "bed", "room": bed["key"]})
	_say(tr("%s has no mattress in the staffroom. They lie down in %s.") % [str(p.get("name", "")), _room_label(str(bed["key"]))], 2)


## A free place of `kind` ("mat", "sofa") in the staffroom, "" none.
func _free_spot(kind: String, slug: String) -> String:
	var n := RULES.gear_count(_st(), "mattress") if kind == "mat" else PLAN.SOFA_SEATS.size()
	var taken := {}
	var acts := _acts()
	for s in acts:
		if str(s) != slug and str(acts[s].get("do", "")) in ["rest", "coffee"]:
			taken[str(acts[s].get("spot", ""))] = true
	# The first of them goes to the first mattress (their own), and so on.
	var mine := -1
	var crew := _crew()
	for i in crew.size():
		if str(crew[i].get("slug", "")) == slug:
			mine = i
	if kind == "mat" and mine >= 0 and mine < n and not taken.has("mat:%d" % mine):
		return "mat:%d" % mine
	for i in n:
		if not taken.has("%s:%d" % [kind, i]):
			return "%s:%d" % [kind, i]
	return ""


## A made-up lodging with nobody in it and nobody's hand on it: {key, pos}.
func _guest_bed(slug: String) -> Dictionary:
	var state = CoreRoot.get_state()
	var taken := {}
	var acts := _acts()
	for s in acts:
		if str(s) != slug:
			taken[str(acts[s].get("room", ""))] = true
	var door := _door()
	var best := {}
	var best_d := INF
	for key in state.accommodation_states:
		var acc: Dictionary = state.accommodation_states[key]
		if taken.has(str(key)) or int(acc.get("occupied", 0)) > 0 or (acc.get("guest_ids", []) as Array).size() > 0:
			continue
		if ROOM_RULES.normalize_status(str(acc.get("status", ""))) != ROOM_RULES.STATUS_READY:
			continue
		var pos := _lodging_door(str(key))
		if pos == Vector3.INF:
			continue
		var d := pos.distance_to(door)
		if d < best_d:
			best_d = d
			best = {"key": str(key), "pos": pos}
	return best


## Out to the nearest thing they are set to do (true when they went).
func _find_work(slug: String, p: Dictionary, act: Dictionary, now: float) -> bool:
	var jobs: Dictionary = p.get("jobs", RULES.default_jobs())
	var from := _here(act)
	var best := {}
	var best_d := INF
	var taken_ev := {}
	var taken_room := {}
	var acts := _acts()
	for s in acts:
		if str(s) != slug:
			taken_ev[int(acts[s].get("ev", -1))] = true
			taken_room[str(acts[s].get("room", ""))] = true
	var de = _day_events()
	if de != null:
		var kinds: Array = []
		for k in ["litter", "raccoons", "delivery", "tree"]:
			if bool(jobs.get(k, true)):
				kinds.append(k)
		for j in de.staff_jobs(kinds):
			if taken_ev.has(int(j["id"])):
				continue
			var d := from.distance_to(j["pos"])
			if d < best_d:
				best_d = d
				best = {"what": str(j["kind"]), "ev": int(j["id"]), "pos": j["pos"]}
	if bool(jobs.get("rooms", true)):
		var state = CoreRoot.get_state()
		for key in state.accommodation_states:
			var acc: Dictionary = state.accommodation_states[key]
			if taken_room.has(str(key)) or int(acc.get("occupied", 0)) > 0 or (acc.get("guest_ids", []) as Array).size() > 0:
				continue
			if ROOM_RULES.normalize_status(str(acc.get("status", ""))) == ROOM_RULES.STATUS_READY or _room_left(str(key)) <= 0:
				continue
			var pos := _lodging_door(str(key))
			if pos == Vector3.INF:
				continue
			# A lodging counts a little further off than a bin bag (the guests mind those).
			var d := from.distance_to(pos) + 25.0
			if d < best_d:
				best_d = d
				best = {"what": "rooms", "room": str(key), "pos": pos}
	if best.is_empty():
		return false
	_unmake_bed(slug, act)
	var next := {"do": "work", "what": best["what"]}
	var extra := {}
	if best.has("ev"):
		next["ev"] = best["ev"]
		extra["ev"] = best["ev"]
	if best.has("room"):
		next["room"] = best["room"]
		extra["room"] = best["room"]
	_walk(slug, from, best["pos"], next, extra)
	return true


func _work(slug: String, p: Dictionary, act: Dictionary, now: float, on: bool) -> void:
	var what := str(act.get("what", ""))
	var name := str(p.get("name", ""))
	if what == "rooms":
		var key := str(act.get("room", ""))
		var acc_ok := _room_free(key)
		var each := maxf(1.0, float(act.get("each", 9.0)))
		var due := int((now - float(act.get("t0", now))) / each)
		var done := int(act.get("done", 0))
		while done < due and acc_ok and _room_left(key) > 0:
			var left: Array = GuestManager.get_room_state(key).get("remaining", [])
			if left.is_empty():
				break
			GuestManager.complete_room_task(key, str(left[0].get("id", "")))
			done += 1
		act["done"] = done
		if not acc_ok or _room_left(key) <= 0 or not on:
			if _room_left(key) <= 0:
				_log("%s made up %s." % [name, _room_label(key)])
			if on:
				_back(slug, _v(act.get("at", [0, 0, 0])))
			else:
				_leave(slug, act)
		return
	var ev := int(act.get("ev", -1))
	if ev >= 0 and not _events_open(ev):
		_back(slug, _v(act.get("at", [0, 0, 0])))
		return
	if now >= float(act.get("t1", now)) or not on:
		var de = _day_events()
		if de != null and ev >= 0 and on and de.staff_done(ev, name):
			_log("%s: %s" % [name, RULES.job_label(what).to_lower()])
		if on:
			_back(slug, _v(act.get("at", [0, 0, 0])))
		else:
			_leave(slug, act)


func _back(slug: String, from: Vector3) -> void:
	_walk(slug, from, _door(), {"do": "rest"})


func _leave(slug: String, act: Dictionary) -> void:
	_unmake_bed(slug, act)
	_walk(slug, _here(act), _gate(), {"do": "home"})


## Where a hand is now (world).
func _here(act: Dictionary) -> Vector3:
	if str(act.get("do", "")) == "rest" and str(act.get("spot", "")).begins_with("bed:"):
		return _v(act.get("at", [0, 0, 0]))
	if str(act.get("do", "")) in ["work"]:
		return _v(act.get("at", [0, 0, 0]))
	if str(act.get("do", "")) == "walk":
		return _pos_of(act, _now())
	return _door()


## Up from a guest's bed: it wants making again.
func _unmake_bed(slug: String, act: Dictionary) -> void:
	var spot := str(act.get("spot", ""))
	if str(act.get("do", "")) != "rest" or not spot.begins_with("bed:"):
		return
	var key := spot.substr(4)
	var state = CoreRoot.get_state()
	if state == null or not state.accommodation_states.has(key):
		return
	var acc: Dictionary = state.accommodation_states[key]
	var done: Array = (acc.get("prep_done", []) as Array).duplicate()
	done.erase("bed")
	acc["prep_done"] = done
	acc["status"] = ROOM_RULES.STATUS_DIRTY
	state.accommodation_states[key] = acc
	var name := ""
	for p in _crew():
		if str(p.get("slug", "")) == slug:
			name = str(p.get("name", ""))
	_say(tr("%s got up from the bed in %s. It is unmade.") % [name, _room_label(key)], 2)
	if EventBus.has_signal("accommodation_state_changed"):
		EventBus.accommodation_state_changed.emit(key, ROOM_RULES.STATUS_DIRTY, 0)


func _events_open(id: int) -> bool:
	var de = _day_events()
	return de != null and de.staff_open(id)


func _room_left(key: String) -> int:
	if key == "" or GuestManager == null:
		return 0
	var rs: Dictionary = GuestManager.get_room_state(key)
	return (rs.get("remaining", []) as Array).size()


func _room_free(key: String) -> bool:
	var state = CoreRoot.get_state()
	if state == null or not state.accommodation_states.has(key):
		return false
	var acc: Dictionary = state.accommodation_states[key]
	return int(acc.get("occupied", 0)) <= 0 and (acc.get("guest_ids", []) as Array).is_empty()


func _room_label(key: String) -> String:
	return str(GuestManager.room_label(key)) if GuestManager != null and GuestManager.has_method("room_label") else key


## The door of a lodging (where E aims at its building), world.
func _lodging_door(key: String) -> Vector3:
	var g = _grid()
	if g == null:
		return Vector3.INF
	var c := Vector2i(int(key.get_slice(":", 0)), int(key.get_slice(":", 1)))
	var tile = g.get_tile(c)
	if tile == null or tile.occupant == null:
		return Vector3.INF
	var n: Node = tile.occupant
	while n != null and not n.has_meta("building_type"):
		n = n.get_parent()
	if not (n is Node3D):
		return Vector3.INF
	var local: Vector3 = n.get_meta("interaction_target_local", Vector3(0, 0, 1.5))
	var p: Vector3 = (n as Node3D).global_transform * (local + Vector3(0, 0, 0.9))
	p.y = _ground_y(p)
	return p


func _day_events():
	var m := _main()
	return m.get("_day_events") if m != null else null


func _log(text: String) -> void:
	CoreRoot.actions.staff_log(text, int(_now()))


func _say(text: String, kind := 1) -> void:
	var m := _main()
	var hud = m.get("_hud_manager") if m != null else null
	if hud != null:
		hud.push_status(text, kind)


# ── what is drawn (every machine) ────────────────────────────────────────────

## The position of a walking hand at `now` and the way they face.
func _pos_of(act: Dictionary, now: float) -> Vector3:
	return _walk_at(act, now)[0]


func _walk_at(act: Dictionary, now: float) -> Array:
	var a := _v(act.get("a", [0, 0, 0]))
	var b := _v(act.get("b", [0, 0, 0]))
	var path := _path(a, b)
	var d := (now - float(act.get("t0", now))) * RULES.WALK_M_PER_MIN
	return _along(path, clampf(d, 0.0, _length(path)))


## The hands in the staffroom for its room inside (and for its windows here): [{slug,
## name, pose, at (building space), head, spot}].
func inside() -> Array:
	var out: Array = []
	var acts := _acts()
	for p in _crew():
		var slug := str(p.get("slug", ""))
		var act: Dictionary = acts.get(slug, {})
		var spot := str(act.get("spot", ""))
		if not (str(act.get("do", "")) in ["rest", "coffee"]):
			continue
		var f := {"slug": slug, "name": str(p.get("name", "")), "spot": spot, "head": Vector3.ZERO}
		if spot.begins_with("mat:"):
			var i := int(spot.substr(4))
			if i >= PLAN.MATTRESSES.size():
				continue
			f["pose"] = "lie"
			f["at"] = PLAN.MATTRESSES[i][0]
			f["head"] = PLAN.MATTRESSES[i][1]
		elif spot.begins_with("sofa:"):
			var j := int(spot.substr(5))
			f["pose"] = "sit"
			f["at"] = PLAN.SOFA_SEATS[clampi(j, 0, PLAN.SOFA_SEATS.size() - 1)]
		elif spot == "stand":
			f["pose"] = "stand"
			f["at"] = Vector3(-2.3, PLAN.FLOOR, -1.4)
		else:
			continue
		# The one nobody quite sees: only now and then.
		if str(p.get("strange", "")) == "unseen" and int(_now() / 30.0) % 3 != 0:
			continue
		out.append(f)
	return out


func _draw() -> void:
	var m := _main()
	var world: Node3D = m.get("_world_3d") if m != null else null
	if world == null:
		return
	var now := _now()
	var acts := _acts()
	var seen := {}
	var room := staffroom()
	for p in _crew():
		var slug := str(p.get("slug", ""))
		var act: Dictionary = acts.get(slug, {})
		var doing := str(act.get("do", "home"))
		var pose := "stand"
		var at := Vector3.INF
		var head := Vector3.ZERO
		var dir := Vector3.ZERO
		var walking := false
		match doing:
			"walk":
				var r: Array = _walk_at(act, now)
				at = r[0]
				dir = r[1]
				walking = true
			"work":
				at = _v(act.get("at", [0, 0, 0]))
				pose = "stand" if str(act.get("what", "")) == "delivery" else "sweep"
				if str(act.get("what", "")) == "rooms":
					# In the lodging, sweeping its step now and then.
					pose = "sweep" if int(now / 6.0) % 2 == 0 else ""
			"rest", "coffee":
				var spot := str(act.get("spot", ""))
				if room != null and (spot.begins_with("mat:") or spot.begins_with("sofa:") or spot == "stand"):
					for f in inside():
						if str(f["slug"]) == slug:
							pose = str(f["pose"])
							at = room.global_transform * (f["at"] as Vector3)
							head = room.global_transform * (f["head"] as Vector3)
		if at == Vector3.INF or pose == "":
			continue
		if str(p.get("strange", "")) == "unseen" and doing != "rest":
			continue
		seen[slug] = true
		var spr: Sprite3D = _figs.get(slug)
		if spr == null or not is_instance_valid(spr):
			spr = Sprite3D.new()
			spr.name = "StaffHand_" + slug
			spr.pixel_size = PERSON_M / 128.0
			spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			spr.shaded = true
			world.add_child(spr)
			_figs[slug] = spr
		ROOM._place(spr, slug, pose, at, head)
		if pose == "lie" and room != null:
			spr.position = at + Vector3(0, PLAN.MATTRESS_SIZE.y + 0.02, 0)
		if walking:
			# The step bob, twelve times a second; facing the way they go.
			var ph := floorf((_t + float(hash(slug) % 100) * 0.01) * 12.0) / 12.0
			spr.position.y += absf(sin(ph * TAU * WALK_BOB_HZ * 0.5)) * 0.04
			var cam := get_viewport().get_camera_3d()
			if cam != null and dir.length() > 0.01:
				spr.flip_h = dir.dot(cam.global_basis.x) < 0.0
		elif pose == "sweep":
			spr.flip_h = int(_t * 2.0) % 2 == 0
	for slug in _figs.keys():
		if not seen.has(slug):
			(_figs[slug] as Node).queue_free()
			_figs.erase(slug)


## The staffroom as it is inside, seen from the camp: the lamps (somebody in, dusk or
## dark, the power on), the curtains as they were left, the laptop's glow, the TV; the
## other wardens in it at the laptop or the books.
func _update_camp_side() -> void:
	var room := staffroom()
	if room == null:
		return
	var refs: Dictionary = room.get_meta("staffroom", {})
	if refs.is_empty():
		return
	var hour := _hour()
	var dark := hour >= 19.0 or hour < 7.0
	var dusk := hour >= 17.5 or hour < 7.5
	var m := _main()
	var power := true
	var si = null
	var im = m.get("_interior_manager") if m != null else null
	if im != null:
		si = im.get("_service_interior")
		var ps = im.get("_grid_power_available")
		power = ps == null or bool(ps)
	var someone := not inside().is_empty() or not _wardens_in().is_empty()
	var key := staffroom_key()
	var me_in: bool = si != null and si.is_open() and str(si.get("_current_profile")) == "staff" and im.get("_active_service_node") == room
	if me_in:
		someone = true
	var lights: Dictionary = refs.get("lights", {})
	if lights.has("lounge"):
		(lights["lounge"] as OmniLight3D).light_energy = 1.4 if power and dusk and someone else 0.0
	if lights.has("boiler"):
		(lights["boiler"] as OmniLight3D).light_energy = 0.7 if power and dark and someone else 0.0
	if lights.has("door"):
		(lights["door"] as OmniLight3D).light_energy = 0.9 if power and dark else 0.0
	for mi in refs.get("lamp_meshes", []):
		var mesh := mi as MeshInstance3D
		if mesh == null:
			continue
		var on := power and dusk and someone
		var mat := mesh.material_override as StandardMaterial3D
		if mat != null and not mesh.has_meta("own_mat"):
			mat = mat.duplicate()
			mesh.material_override = mat
			mesh.set_meta("own_mat", true)
		if mat != null:
			mat.emission_enabled = on
			mat.emission = Color(1.0, 0.95, 0.8) * (1.6 if on else 0.0)
	# The curtains as somebody left them inside (interior_manager keeps them by building).
	var cur: Array = (im.get("_curtains_by_room") as Dictionary).get(key, []) if im != null and im.get("_curtains_by_room") is Dictionary else []
	var ci := 0
	for id in PLAN.WINDOW_ORDER:
		var parts: Array = (refs.get("curtains", {}) as Dictionary).get(id, [])
		if parts.size() == 3:
			var open: bool = ci >= cur.size() or bool(cur[ci])
			(parts[0] as Node3D).visible = not open
			(parts[1] as Node3D).visible = open
			(parts[2] as Node3D).visible = open
		ci += 1
	# The laptop: the office PC's picture, dim (somebody at it: theirs is live in the room).
	var scr := refs.get("laptop_screen") as MeshInstance3D
	if scr != null:
		var bi = im.get("_building_interior") if im != null else null
		var vp = bi.get("_crt_viewport") if bi != null else null
		var mat := scr.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_texture = (vp as SubViewport).get_texture() if vp is SubViewport and power else null
			mat.albedo_color = Color(0.6, 0.65, 0.68) if power else Color(0.05, 0.06, 0.07)
	# Mattresses and lockers as bought.
	var nm := RULES.gear_count(_st(), "mattress")
	var mats: Array = refs.get("mattresses", [])
	for i in mats.size():
		(mats[i] as Node3D).visible = i < nm
	var nl := RULES.gear_count(_st(), "locker")
	var lks: Array = refs.get("lockers", [])
	for i in lks.size():
		(lks[i] as Node3D).visible = i < nl
	_draw_wardens(room, me_in)


## The other wardens whose room is this staffroom: peer id -> their room state.
func _wardens_in() -> Dictionary:
	var out := {}
	if not Coop.is_active():
		return out
	var key := staffroom_key()
	for id in Coop.others():
		var r: Dictionary = Coop.state_of(id).get("room", {})
		if str(r.get("t", "")) == "service" and str(r.get("k", "")) == key and str(r.get("s", "")).begins_with("staff/"):
			out[id] = r
	return out


func _draw_wardens(room: Node3D, me_in: bool) -> void:
	var inside_now := _wardens_in()
	for id in _wardens.keys():
		if me_in or not inside_now.has(id):
			if is_instance_valid(_wardens[id]):
				(_wardens[id] as Node).queue_free()
			_wardens.erase(id)
	if me_in:
		return
	for id in inside_now:
		var r: Dictionary = inside_now[id]
		var fig = _wardens.get(id)
		if fig == null or not is_instance_valid(fig):
			var look: Dictionary = Coop.look_of(id)
			fig = COOP_FIGURE.new()
			fig.setup(int(look.get("m", 1)), int(look.get("c", 0)), true)
			room.add_child(fig)
			_wardens[id] = fig
		var at := Vector3(PLAN.EYE_LOUNGE.x, PLAN.FLOOR, PLAN.EYE_LOUNGE.z - 0.6)
		var pose := "stand"
		if str(r.get("s", "")) == "staff/boiler":
			at = Vector3(PLAN.EYE_BOILER.x + 0.6, PLAN.FLOOR, PLAN.EYE_BOILER.z)
		match str(r.get("w", "")):
			"laptop":
				at = PLAN.LAPTOP_CHAIR
				pose = "desk"
			"ledger":
				at = Vector3(PLAN.LEDGER.x - 0.1, PLAN.FLOOR, PLAN.LEDGER.z + 0.5)
				pose = "write"
		fig.set_walking(false)
		fig.show_at(room.global_transform * at, pose)
