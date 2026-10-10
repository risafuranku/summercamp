extends RefCounted

## Guest "life" runtime: needs, mood and the activity each guest party is doing.
##
## Owned by GuestManager, advanced from its minute tick. It is deliberately independent
## of the 3D world: the visual agents (guest_agents.gd) only *follow* the activity plan
## stored on each guest (`activity` = travel from -> to, then dwell until `end`), so the
## simulation behaves identically when nobody is looking, in headless tests and across
## time skips.
##
## Guest fields owned here (all JSON-safe, persisted with the guest record):
##   needs            {energy, hunger, bladder, hygiene, fun, safety}  0-100
##   mood             0-100
##   tile             "x:y" where the party currently is (end of last activity)
##   activity         {kind, from, to, target_key, target_type, need, start, arrive, end,
##                     queued, queue_since, label}
##   thought          last line the guest "said"; thought_abs when
##   unhappy_minutes  continuous minutes below GuestNeedsSystem.UNHAPPY_MOOD
##   visits, complaints, sim_abs (last simulated absolute minute)

const NEEDS := preload("res://core/systems/guest_needs_system.gd")
const BALANCE_CONFIG := preload("res://core/balance/balance_config.gd")

const MAX_CHUNK_MINUTES := 20
const QUEUE_GIVE_UP_MINUTES := 16
const MAX_THOUGHT_LOG := 24
const LAMP_LIGHT_RADIUS := 3

var _rng := RandomNumberGenerator.new()
var _facilities: Array = []
var _facility_by_key: Dictionary = {}
var _usage: Dictionary = {}
var _lamp_tiles: Array[Vector2i] = []
var _path_tiles: Array[Vector2i] = []
var _gate: Vector2i = Vector2i(10, 2)
## Ways out of the camp: the gate road, the forest edges and the lake shore. Idle guests
## leave by them for hours ("Twenty guests, so where is everybody?").
var _exits: Array[Vector2i] = []
var _lake_shore: Array[Vector2i] = []
var _grid_size: Vector2i = Vector2i(20, 20)
var _power_available: bool = true
var _weather: int = 0
var _threat_map: Dictionary = {}  # "x:y" -> {strength, until_abs}
var _thought_log: Array[Dictionary] = []
var _events: Array[Dictionary] = []


func _init() -> void:
	_rng.randomize()


func set_power_available(available: bool) -> void:
	_power_available = available


func set_weather(weather_state: int) -> void:
	_weather = weather_state


func get_thought_log() -> Array[Dictionary]:
	return _thought_log.duplicate(true)


## Drains queued simulation events (storm-offs, bushes...) for GuestManager to react to.
func take_events() -> Array[Dictionary]:
	var out := _events.duplicate(true)
	_events.clear()
	return out


func get_facilities() -> Array:
	return _facilities


func gate_coord() -> Vector2i:
	return _gate


## Enemies (or anything scary) call this through GuestManager to frighten guests nearby.
func report_threat(tile: Vector2i, strength: float, until_abs: int) -> void:
	_threat_map["%d:%d" % [tile.x, tile.y]] = {"strength": clampf(strength, 0.0, 1.0), "until": until_abs}


## Rebuilds the facility / lamp / path caches from the grid. Cheap; called every tick.
func refresh_world(state, registry) -> void:
	if state == null or state.grid == null:
		return
	var grid = state.grid
	_grid_size = Vector2i(int(grid.grid_width), int(grid.grid_height))
	_facilities = NEEDS.collect_facilities(grid, registry, {
		"failures": state.failures,
		"power_available": _power_available,
		"weather": _weather,
	})
	_facility_by_key.clear()
	for f in _facilities:
		_facility_by_key[str(f["key"])] = f
	_lamp_tiles.clear()
	_path_tiles.clear()
	for coord_any in grid.cells.keys():
		var cell: Dictionary = grid.cells[coord_any]
		var type := str(cell.get("type", ""))
		if type == "lamp_post":
			_lamp_tiles.append(coord_any)
		elif type == "path":
			_path_tiles.append(coord_any)
			if bool(cell.get("lamp", false)):
				_lamp_tiles.append(coord_any)
	_gate = _find_gate(grid)
	_refresh_exits(grid)


func _refresh_exits(grid) -> void:
	_lake_shore.clear()
	var lake_far := Vector2i(-1, -1)
	for coord_any in grid.tile_types.keys():
		if int(grid.tile_types[coord_any]) != 1:  # TILE_LAKE
			continue
		var c: Vector2i = coord_any
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= _grid_size.x or n.y >= _grid_size.y:
				continue
			if int(grid.tile_types.get(n, 0)) == 1 or grid.cells.has(n):
				continue
			_lake_shore.append(n)
			if lake_far.x < 0 or n.distance_squared_to(_gate) > lake_far.distance_squared_to(_gate):
				lake_far = n
	var mid_y := clampi(int(_grid_size.y / 2), 1, _grid_size.y - 2)
	_exits = [
		_gate,
		Vector2i(0, mid_y),
		Vector2i(_grid_size.x - 1, mid_y),
		Vector2i(clampi(int(_grid_size.x / 2), 1, _grid_size.x - 2), _grid_size.y - 1),
	]
	if lake_far.x >= 0:
		_exits.append(lake_far)


## The gate lane: the free reserved tile on the south edge (east of the reception).
func _find_gate(grid) -> Vector2i:
	var best := Vector2i(-1, -1)
	for coord_any in grid.tile_types.keys():
		if int(grid.tile_types[coord_any]) != 2:  # TILE_RESERVED
			continue
		var c: Vector2i = coord_any
		if grid.cells.has(c):
			continue
		if best.x < 0 or c.y < best.y or (c.y == best.y and c.x > best.x):
			best = c
	if best.x < 0:
		return Vector2i(int(_grid_size.x / 2), 2)
	return best


## Initialises a freshly checked-in guest: needs, mood, and the walk from the gate.
func init_guest(guest: Dictionary, now_abs: int) -> void:
	guest["needs"] = NEEDS.default_needs(_rng)
	guest["mood"] = 68.0
	guest["unhappy_minutes"] = 0
	guest["visits"] = 0
	guest["complaints"] = 0
	guest["tile"] = _key(_gate)
	guest["sim_abs"] = now_abs
	var lodging := lodging_coord(guest)
	var target := lodging if lodging.x >= 0 else _gate
	guest["activity"] = _make_activity("arrive", _gate, target, now_abs, _rng.randi_range(8, 16), "", {})
	_say(guest, "Checked in. Let's see this camp.", now_abs)


## Sanitises life fields on a guest loaded from a save (or created before this system).
func ensure_guest_fields(guest: Dictionary, now_abs: int) -> void:
	if not (guest.get("needs", null) is Dictionary):
		guest["needs"] = NEEDS.default_needs(_rng)
	else:
		guest["needs"] = NEEDS.normalize_needs(guest["needs"])
	guest["mood"] = clampf(float(guest.get("mood", 65.0)), 0.0, 100.0)
	guest["unhappy_minutes"] = int(guest.get("unhappy_minutes", 0))
	guest["visits"] = int(guest.get("visits", 0))
	guest["complaints"] = int(guest.get("complaints", 0))
	if str(guest.get("tile", "")).is_empty():
		var lodging := lodging_coord(guest)
		guest["tile"] = _key(lodging if lodging.x >= 0 else _gate)
	var sim_abs := int(guest.get("sim_abs", now_abs))
	if sim_abs > now_abs or sim_abs < now_abs - 1440 * 3:
		sim_abs = now_abs
	guest["sim_abs"] = sim_abs
	if not (guest.get("activity", null) is Dictionary):
		guest["activity"] = {}


## Advances every guest to `now_abs`. `is_night_at` is a Callable(abs_minute) -> bool.
func advance_all(state, now_abs: int, is_night_at: Callable, weirdness: float) -> bool:
	if state == null:
		return false
	_prune_threats(now_abs)
	_rebuild_usage(state.guests)
	var changed := false
	for i in state.guests.size():
		var guest_any = state.guests[i]
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		# Parties still on the road or at the barrier are not in the camp yet.
		if str(guest.get("status", "")) in ["expected", "waiting"]:
			continue
		ensure_guest_fields(guest, now_abs)
		if _advance_guest(guest, now_abs, is_night_at, weirdness):
			changed = true
		state.guests[i] = guest
	return changed


func _advance_guest(guest: Dictionary, now_abs: int, is_night_at: Callable, weirdness: float) -> bool:
	var t := int(guest.get("sim_abs", now_abs))
	if t >= now_abs:
		return false
	var archetype := str(guest.get("archetype", "quiet_guy"))
	var comfort := lodging_comfort(guest)
	var safety_guard := 0
	while t < now_abs and safety_guard < 400:
		safety_guard += 1
		var act: Dictionary = guest.get("activity", {})
		var night_now := bool(is_night_at.call(t))
		if act.is_empty():
			act = _plan_next(guest, t, night_now)
			guest["activity"] = act
			continue
		# Night / day switches override whatever the guest was doing.
		var kind := str(act.get("kind", ""))
		if night_now and kind != "sleep" and kind != "night_out" and kind != "leave":
			_release_usage(act)
			act = _plan_sleep(guest, t)
			guest["activity"] = act
			continue
		if not night_now and kind == "sleep":
			guest["activity"] = {}
			guest["tile"] = str(act.get("to", guest.get("tile", "")))
			_say(guest, _morning_thought(guest), t)
			continue

		var seg_end := mini(now_abs, int(act.get("end", now_abs)))
		seg_end = mini(seg_end, t + MAX_CHUNK_MINUTES)
		if t < int(act.get("arrive", t)):
			seg_end = mini(seg_end, int(act.get("arrive", t)))
		seg_end = maxi(seg_end, t + 1)
		var minutes := float(seg_end - t)
		var dwelling := t >= int(act.get("arrive", t))
		var sleeping := dwelling and (kind == "sleep" or kind == "rest")
		var here := _parse_key(str(act.get("to", guest.get("tile", "")))) if dwelling else _parse_key(str(guest.get("tile", "")))
		var context := {
			"sleeping": sleeping,
			"comfort": comfort if kind == "sleep" else comfort * 0.8,
			"is_night": night_now,
			"lit": _is_lit(here),
			"threat": _threat_at(here, t),
			"weirdness": weirdness,
		}
		var needs: Dictionary = NEEDS.decay_needs(guest["needs"], archetype, minutes, context)
		guest["needs"] = needs
		var target_mood := NEEDS.mood_target(needs, archetype, comfort)
		guest["mood"] = NEEDS.step_mood(float(guest.get("mood", 60.0)), target_mood, minutes)
		_track_unhappiness(guest, int(minutes), t, night_now)
		t = seg_end

		if not bool(act.get("arrived", false)) and t >= int(act.get("arrive", t)):
			act["arrived"] = true
			_on_arrive(guest, act, t)
		if t >= int(act.get("end", t)):
			if bool(act.get("queued", false)):
				_on_queue_tick(guest, act, t)
			else:
				_on_complete(guest, act, t)
				guest["activity"] = {}
			continue
		guest["activity"] = act
	guest["sim_abs"] = t
	return true


func _plan_next(guest: Dictionary, t: int, night_now: bool) -> Dictionary:
	if night_now:
		return _plan_sleep(guest, t)
	var here := _parse_key(str(guest.get("tile", "")))
	var archetype := str(guest.get("archetype", "quiet_guy"))
	var goal: Dictionary = NEEDS.pick_goal(guest["needs"], archetype, _facilities, here, _usage, _rng)
	var thought := str(goal.get("thought", ""))
	match str(goal.get("kind", "wander")):
		"visit":
			var f: Dictionary = goal["facility"]
			var door := _door_tile(f, here)
			var act := _make_activity("visit", here, door, t, int(f.get("use_minutes", 10)), str(goal.get("need", "")), f)
			_claim_usage(act)
			if not thought.is_empty() and _rng.randf() < 0.55:
				_say(guest, thought, t)
			return act
		"rest":
			var lodging := lodging_coord(guest)
			if lodging.x >= 0:
				_say(guest, thought, t)
				return _make_activity("rest", here, lodging, t, _rng.randi_range(50, 110), "energy", {})
		"bushes":
			var edge := _nearest_edge(here)
			guest["complaints"] = int(guest.get("complaints", 0)) + 1
			_say(guest, thought, t)
			_events.append({"type": "bushes", "guest_id": int(guest.get("id", -1)), "abs": t})
			return _make_activity("bushes", here, edge, t, 5, "bladder", {})
	if not thought.is_empty():
		guest["complaints"] = int(guest.get("complaints", 0)) + 1
		_say(guest, thought, t)
	if str(goal.get("need", "")).is_empty():
		return _plan_idle(guest, here, t)
	var spot := _wander_target(here, guest)
	return _make_activity("wander", here, spot, t, _rng.randi_range(6, 18), str(goal.get("need", "")), {})


## Nothing to do. A camp guest mostly keeps to themselves: shut in their cabin, gone
## for a long walk out of the camp, or standing at the water. Only sometimes do they
## stroll the paths where you can see them.
func _plan_idle(guest: Dictionary, here: Vector2i, t: int) -> Dictionary:
	var roll := _rng.randf()
	var lodging := lodging_coord(guest)
	if roll < 0.45 and lodging.x >= 0:
		return _make_activity("rest", here, lodging, t, _rng.randi_range(70, 160), "", {})
	if roll < 0.80 and not _exits.is_empty():
		var exit := _exits[_rng.randi_range(0, _exits.size() - 1)]
		if _rng.randf() < 0.3:
			_say(guest, _away_thought(exit), t)
		return _make_activity("away", here, exit, t, _rng.randi_range(120, 240), "", {})
	if roll < 0.90 and not _lake_shore.is_empty():
		var shore := _lake_shore[_rng.randi_range(0, _lake_shore.size() - 1)]
		return _make_activity("linger", here, shore, t, _rng.randi_range(15, 40), "", {})
	return _make_activity("wander", here, _wander_target(here, guest), t, _rng.randi_range(6, 18), "", {})


func _away_thought(exit: Vector2i) -> String:
	if exit == _gate:
		return "Going to walk to the village and back."
	if _lake_shore.has(exit):
		return "Going round the lake. Back later."
	return "There's a path into the woods. Going to see where it goes."


func _plan_sleep(guest: Dictionary, t: int) -> Dictionary:
	var here := _parse_key(str(guest.get("tile", "")))
	var lodging := lodging_coord(guest)
	var target := lodging if lodging.x >= 0 else here
	# Sleep lasts until the next morning; the day switch in _advance_guest ends it.
	var act := _make_activity("sleep", here, target, t, 24 * 60, "energy", {})
	return act


## Starts a night-time wander (the archetype "trouble" window) from the lodging.
func start_night_out(guest: Dictionary, t: int) -> void:
	var act: Dictionary = guest.get("activity", {})
	if str(act.get("kind", "")) == "night_out":
		return
	var lodging := lodging_coord(guest)
	var from := lodging if lodging.x >= 0 else _parse_key(str(guest.get("tile", "")))
	var target := _night_out_target(from, str(guest.get("archetype", "")))
	guest["tile"] = _key(from)
	guest["activity"] = _make_activity("night_out", from, target, t, _rng.randi_range(18, 30), "fun", {})
	match str(guest.get("archetype", "")):
		"drunk":
			_say(guest, "One more beer. Just one. Where did everyone go?", t)
		"cheap_chick":
			_say(guest, "Can't sleep. Going to look at the lake.", t)
		"tramp":
			_say(guest, "Who's got a guitar? One more song at the fire.", t)
		"family":
			_say(guest, "Has anyone seen our boy? He was right here.", t)
		"picker":
			_say(guest, "Four o'clock. Best time for boletes. Off to the woods.", t)
		_:
			_say(guest, "Heard something outside. Probably nothing.", t)


func _on_arrive(guest: Dictionary, act: Dictionary, t: int) -> void:
	var kind := str(act.get("kind", ""))
	if kind != "visit":
		return
	var f: Dictionary = _facility_by_key.get(str(act.get("target_key", "")), {})
	if f.is_empty() or not bool(f.get("working", true)):
		var label := str(act.get("label", "place"))
		_say(guest, "The %s is closed?! Walked all this way." % label.to_lower(), t)
		guest["complaints"] = int(guest.get("complaints", 0)) + 1
		_release_usage(act)
		act["end"] = t
		act["failed"] = true
		return
	var using := _count_using(str(act.get("target_key", "")), int(guest.get("id", -1)))
	if using >= int(f.get("capacity", 1)):
		act["queued"] = true
		act["queue_since"] = t
		act["end"] = t + 1
		if _rng.randf() < 0.4:
			_say(guest, "A queue for the %s. Of course." % str(f.get("label", "place")).to_lower(), t)


func _on_queue_tick(guest: Dictionary, act: Dictionary, t: int) -> void:
	var key := str(act.get("target_key", ""))
	var f: Dictionary = _facility_by_key.get(key, {})
	var using := _count_using(key, int(guest.get("id", -1)))
	if not f.is_empty() and using < int(f.get("capacity", 1)):
		act["queued"] = false
		act["arrive"] = t
		act["end"] = t + int(f.get("use_minutes", 10))
		act["in_use"] = true
		guest["activity"] = act
		return
	if t - int(act.get("queue_since", t)) >= QUEUE_GIVE_UP_MINUTES:
		_say(guest, "Forget this queue. This camp needs a second %s." % str(act.get("label", "one")).to_lower(), t)
		guest["complaints"] = int(guest.get("complaints", 0)) + 1
		guest["mood"] = clampf(float(guest.get("mood", 50.0)) - 6.0, 0.0, 100.0)
		_release_usage(act)
		guest["tile"] = str(act.get("to", guest.get("tile", "")))
		guest["activity"] = {}
		return
	act["end"] = t + 1
	guest["activity"] = act


func _on_complete(guest: Dictionary, act: Dictionary, t: int) -> void:
	var kind := str(act.get("kind", ""))
	guest["tile"] = str(act.get("to", guest.get("tile", "")))
	_release_usage(act)
	match kind:
		"visit":
			if bool(act.get("failed", false)):
				return
			var f: Dictionary = _facility_by_key.get(str(act.get("target_key", "")), {})
			if f.is_empty():
				return
			guest["needs"] = NEEDS.apply_facility(guest["needs"], f.get("services", {}), str(guest.get("archetype", "")), str(f.get("type", "")))
			guest["visits"] = int(guest.get("visits", 0)) + 1
			_events.append({"type": "visit", "guest_id": int(guest.get("id", -1)), "facility": str(f.get("type", "")), "abs": t})
			if _rng.randf() < 0.3:
				_say(guest, _thought_after_visit(str(f.get("type", "")), guest), t)
		"bushes":
			var needs: Dictionary = guest["needs"]
			needs["bladder"] = 88.0
			needs["hygiene"] = clampf(float(needs.get("hygiene", 50.0)) - 18.0, 0.0, 100.0)
			guest["needs"] = needs
			guest["mood"] = clampf(float(guest.get("mood", 50.0)) - 8.0, 0.0, 100.0)
		"night_out":
			# Walk back home; the sleep plan takes over from the new tile.
			guest["activity"] = _plan_sleep(guest, t)
		"leave":
			_events.append({"type": "left", "guest_id": int(guest.get("id", -1)), "abs": t})


func _track_unhappiness(guest: Dictionary, minutes: int, t: int, night_now: bool) -> void:
	var mood := float(guest.get("mood", 50.0))
	if mood < NEEDS.UNHAPPY_MOOD:
		guest["unhappy_minutes"] = int(guest.get("unhappy_minutes", 0)) + minutes
	else:
		guest["unhappy_minutes"] = maxi(0, int(guest.get("unhappy_minutes", 0)) - minutes * 2)
	if night_now or bool(guest.get("storming_off", false)):
		return
	if int(guest.get("unhappy_minutes", 0)) >= NEEDS.STORM_OFF_MINUTES:
		guest["storming_off"] = true
		var here := _parse_key(str(guest.get("tile", "")))
		_say(guest, "That's it. We're leaving. Don't expect a good review.", t)
		guest["activity"] = _make_activity("leave", here, _gate, t, 1, "", {})
		_events.append({"type": "storm_off", "guest_id": int(guest.get("id", -1)), "abs": t})


func _make_activity(kind: String, from: Vector2i, to: Vector2i, t: int, dwell: int, need: String, facility: Dictionary) -> Dictionary:
	var travel := NEEDS.travel_minutes(from, to) if from != to else 0
	var act := {
		"kind": kind,
		"from": _key(from),
		"to": _key(to),
		"need": need,
		"start": t,
		"arrive": t + travel,
		"end": t + travel + maxi(1, dwell),
		"queued": false,
		"arrived": false,
	}
	if not facility.is_empty():
		act["target_key"] = str(facility.get("key", ""))
		act["target_type"] = str(facility.get("type", ""))
		act["label"] = str(facility.get("label", ""))
	return act


# ── usage bookkeeping (who is using / queuing at which facility) ─────────────────

func _rebuild_usage(guests: Array) -> void:
	_usage.clear()
	for g_any in guests:
		if not (g_any is Dictionary):
			continue
		var act: Dictionary = (g_any as Dictionary).get("activity", {})
		if str(act.get("kind", "")) == "visit":
			_claim_usage(act)


func _claim_usage(act: Dictionary) -> void:
	var key := str(act.get("target_key", ""))
	if key.is_empty():
		return
	_usage[key] = int(_usage.get(key, 0)) + 1


func _release_usage(act: Dictionary) -> void:
	var key := str(act.get("target_key", ""))
	if key.is_empty() or not _usage.has(key):
		return
	_usage[key] = maxi(0, int(_usage[key]) - 1)


## Parties physically at the facility (arrived and not queuing), excluding `except_id`.
func _count_using(key: String, except_id: int) -> int:
	var n := 0
	var state = CoreRoot.get_state()
	if state == null:
		return 0
	for g_any in state.guests:
		if not (g_any is Dictionary):
			continue
		var g: Dictionary = g_any
		if int(g.get("id", -1)) == except_id:
			continue
		var act: Dictionary = g.get("activity", {})
		if str(act.get("kind", "")) != "visit" or str(act.get("target_key", "")) != key:
			continue
		if bool(act.get("arrived", false)) and not bool(act.get("queued", false)) and not bool(act.get("failed", false)):
			n += 1
	return n


# ── world helpers ─────────────────────────────────────────────────────────────

func lodging_coord(guest: Dictionary) -> Vector2i:
	var slots: Array = guest.get("lodging_slots", []) if guest.get("lodging_slots", []) is Array else []
	for slot_any in slots:
		if slot_any is Dictionary:
			var c = (slot_any as Dictionary).get("coord", null)
			if c is Vector2i:
				return c
			var key := str((slot_any as Dictionary).get("accommodation_key", ""))
			if not key.is_empty():
				return _parse_key(key)
	return Vector2i(-1, -1)


func lodging_comfort(guest: Dictionary) -> float:
	var slots: Array = guest.get("lodging_slots", []) if guest.get("lodging_slots", []) is Array else []
	for slot_any in slots:
		if slot_any is Dictionary:
			var type := str((slot_any as Dictionary).get("building_type", ""))
			if CoreRoot != null and CoreRoot.registry != null:
				var def = CoreRoot.registry.get_def(StringName(type))
				if def != null:
					return float(def.comfort)
	return 40.0


func _door_tile(facility: Dictionary, from: Vector2i) -> Vector2i:
	# Walk to the facility's root tile; the agent layer steps to a free adjacent tile.
	var coord: Vector2i = facility.get("coord", from)
	return coord


func _wander_target(here: Vector2i, guest: Dictionary) -> Vector2i:
	if not _path_tiles.is_empty() and _rng.randf() < 0.65:
		return _path_tiles[_rng.randi_range(0, _path_tiles.size() - 1)]
	var lodging := lodging_coord(guest)
	var anchor := lodging if lodging.x >= 0 and _rng.randf() < 0.5 else here
	var target := anchor + Vector2i(_rng.randi_range(-4, 4), _rng.randi_range(-4, 4))
	target.x = clampi(target.x, 1, _grid_size.x - 2)
	target.y = clampi(target.y, 1, _grid_size.y - 3)
	return target


func _night_out_target(from: Vector2i, archetype: String) -> Vector2i:
	var preferred := "bonfire"
	match archetype:
		"drunk":
			preferred = "pub"
		"cheap_chick":
			preferred = "lake_slide"
		"tramp":
			preferred = "bonfire"
		"family":
			preferred = "sports_field"
	for f in _facilities:
		if str(f.get("type", "")) == preferred:
			return f.get("coord", from)
	if archetype == "cheap_chick":
		return Vector2i(clampi(from.x + _rng.randi_range(-3, 3), 1, _grid_size.x - 2), _grid_size.y - 2)
	if archetype == "picker":
		# Into the trees by the fence, basket on the arm.
		return Vector2i(1, clampi(from.y + _rng.randi_range(-4, 4), 1, _grid_size.y - 3))
	return Vector2i(
		clampi(from.x + _rng.randi_range(-5, 5), 1, _grid_size.x - 2),
		clampi(from.y + _rng.randi_range(-5, 5), 1, _grid_size.y - 3)
	)


func _nearest_edge(here: Vector2i) -> Vector2i:
	var left := here.x
	var right := _grid_size.x - 1 - here.x
	if left <= right:
		return Vector2i(0, clampi(here.y, 1, _grid_size.y - 3))
	return Vector2i(_grid_size.x - 1, clampi(here.y, 1, _grid_size.y - 3))


func _is_lit(tile: Vector2i) -> bool:
	for lamp in _lamp_tiles:
		if absi(lamp.x - tile.x) + absi(lamp.y - tile.y) <= LAMP_LIGHT_RADIUS:
			return true
	for f in _facilities:
		if str(f.get("type", "")) == "bonfire" and bool(f.get("working", true)):
			var c: Vector2i = f.get("coord", Vector2i(-99, -99))
			if absi(c.x - tile.x) + absi(c.y - tile.y) <= 2:
				return true
	return false


func _threat_at(tile: Vector2i, t: int) -> float:
	var best := 0.0
	for key in _threat_map.keys():
		var entry: Dictionary = _threat_map[key]
		if int(entry.get("until", 0)) < t:
			continue
		var c := _parse_key(str(key))
		var d := absi(c.x - tile.x) + absi(c.y - tile.y)
		if d > 5:
			continue
		best = maxf(best, float(entry.get("strength", 0.0)) * (1.0 - float(d) / 6.0))
	return best


func _prune_threats(now_abs: int) -> void:
	for key in _threat_map.keys():
		if int((_threat_map[key] as Dictionary).get("until", 0)) < now_abs - 60:
			_threat_map.erase(key)


# ── thoughts ───────────────────────────────────────────────────────────────────

func _say(guest: Dictionary, text: String, t: int) -> void:
	if text.is_empty():
		return
	guest["thought"] = text
	guest["thought_abs"] = t
	_thought_log.append({
		"guest_id": int(guest.get("id", -1)),
		"name": str(guest.get("name", "Guest")),
		"archetype": str(guest.get("archetype", "")),
		"text": text,
		"abs": t,
		"mood": float(guest.get("mood", 50.0)),
	})
	while _thought_log.size() > MAX_THOUGHT_LOG:
		_thought_log.remove_at(0)


func _morning_thought(guest: Dictionary) -> String:
	var needs: Dictionary = guest.get("needs", {})
	if float(needs.get("safety", 80.0)) < 40.0:
		return "Something walked past the tent all night. I'm not imagining it."
	if float(needs.get("energy", 50.0)) < 45.0:
		return "Barely slept. That bed is a crime."
	return ["Morning. Smells like pine and diesel.", "Slept like a log.", "Who was whistling at 3 AM?"][_rng.randi_range(0, 2)]


func _thought_after_visit(type: String, guest: Dictionary) -> String:
	match type:
		"pub":
			return "Cheap beer, warm bench. Perfect." if str(guest.get("archetype", "")) == "drunk" else "The pub smells like a wet dog."
		"restaurant":
			return "Goulash was actually decent."
		"vecerka":
			return "Bought rohlíky and suspicious salami."
		"bonfire":
			return "Sausages on a stick. Childhood unlocked."
		"lake_slide":
			return "The slide is terrifying. Again!"
		"sports_field":
			return "Lost at football to a ten year old."
		"shower_block":
			return "Hot water for exactly 40 seconds."
		"toilet_block":
			return "Relief."
	return ""


# ── keys ─────────────────────────────────────────────────────────────────────

static func _key(c: Vector2i) -> String:
	return "%d:%d" % [c.x, c.y]


static func _parse_key(key: String) -> Vector2i:
	var parts := key.split(":")
	if parts.size() != 2:
		return Vector2i(10, 2)
	return Vector2i(int(parts[0]), int(parts[1]))
