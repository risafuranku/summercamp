extends Node3D

## Visual guest agents: Build-engine style billboard sprites that act out the guest
## simulation in the world.
##
## The simulation (GuestManager + guest_life.gd) is authoritative and knows nothing about
## this node. Each guest party carries an activity plan (walk from tile A to tile B between
## `start` and `arrive`, then dwell until `end`). This layer turns that plan into motion:
## A* over the camp grid (trees, buildings and the lake block), sprites that bob while
## walking, queue outside busy facilities, disappear into cabins and toilets, stand around
## bonfires, and show a speech line when the guest has something to say.
##
## If a path cannot be found the agent glides straight to the target; the simulation
## never waits for the visuals.

const GUEST_NEEDS = preload("res://core/systems/guest_needs_system.gd")
const POSES = preload("res://scripts/attractions/poses.gd")
const DOOR_ANIM = preload("res://scripts/attractions/door_anim.gd")
## Going in through a door (game minutes): from a step outside to a step inside.
const ENTER_MIN := 1.4

const SNAPSHOT_INTERVAL_SEC := 0.25
const NAV_REBUILD_INTERVAL_SEC := 3.0
const SPRITE_HEIGHT_M := 1.72
const MEMBER_SPREAD_M := 0.55
const MAX_MEMBERS_PER_PARTY := 4
const WALK_BOB_HZ := 2.6
## Guests move and animate in steps, like 1996 sprites: position updates this many times
## a second, the walk cycle (bob, sway, turning) at ANIM_FPS.
const MOVE_FPS := 12.0
const ANIM_FPS := 8.0
const OPEN_AIR_TYPES := ["bonfire", "sports_field", "lake_slide"]
## Dwelling out of sight: in bed, resting in the lodging, arriving, or away from the
## camp altogether (walked out by one of the exits).
const HIDDEN_DWELL_KINDS := ["sleep", "rest", "arrive", "away"]
const INTERACT_MAX_DISTANCE := 4.2
const MARKER_ANGRY := preload("res://assets/textury/npc/mood_angry.png")
const MARKER_HAPPY := preload("res://assets/textury/npc/mood_happy.png")
const MARKER_NEED := preload("res://assets/textury/npc/mood_need.png")

var _move_acc := 0.0
var _grid_manager: Node
var _now_provider: Callable
var _astar := AStarGrid2D.new()
var _nav_dirty := true
var _nav_timer := 0.0
var _snapshot_timer := 0.0
var _snapshot: Array = []
var _parties: Dictionary = {}  # guest_id -> {root, members: Array, path_key, path, ...}
var _texture_cache: Dictionary = {}
var _shadow_mesh: QuadMesh
var _shadow_material: StandardMaterial3D
var _time := 0.0


func setup(grid_manager: Node, now_provider: Callable) -> void:
	_grid_manager = grid_manager
	_now_provider = now_provider
	name = "GuestAgents"
	_nav_dirty = true
	if EventBus.has_signal("building_placed") and not EventBus.building_placed.is_connected(_on_building_changed):
		EventBus.building_placed.connect(_on_building_changed)
	if EventBus.has_signal("building_removed") and not EventBus.building_removed.is_connected(_on_building_removed):
		EventBus.building_removed.connect(_on_building_removed)


func clear_agents() -> void:
	for id in _parties.keys():
		var party: Dictionary = _parties[id]
		var root := party.get("root", null) as Node3D
		if root != null and is_instance_valid(root):
			root.queue_free()
	_parties.clear()
	_snapshot.clear()


func _on_building_changed(_id: String, _origin: Vector2i, _footprint: Vector2i, _rotation: int) -> void:
	_nav_dirty = true


func _on_building_removed(_origin: Vector2i) -> void:
	_nav_dirty = true


func _process(delta: float) -> void:
	if _grid_manager == null or not is_instance_valid(_grid_manager):
		return
	_time += delta
	_nav_timer += delta
	if _nav_dirty or _nav_timer >= NAV_REBUILD_INTERVAL_SEC:
		_rebuild_nav()
	_snapshot_timer -= delta
	if _snapshot_timer <= 0.0:
		_snapshot_timer = SNAPSHOT_INTERVAL_SEC
		_refresh_snapshot()
	DOOR_ANIM.tick(delta)
	_move_acc += delta
	if _move_acc < 1.0 / MOVE_FPS:
		return
	var step := _move_acc
	_move_acc = 0.0
	var now := _now_abs_float()
	for id in _parties.keys():
		_update_party(_parties[id], now, step)


## Guest under the player's crosshair, for the talk interaction. Returns the snapshot
## entry (plus "distance") or {} when nobody is close enough and in view.
## Where a party is standing right now (its first member), or Vector3.INF.
func guest_world_position(guest_id: int) -> Vector3:
	var party: Dictionary = _parties.get(guest_id, {})
	for member_any in party.get("members", []):
		var member := member_any as Node3D
		if member != null and is_instance_valid(member) and member.is_visible_in_tree():
			return member.global_position
	return Vector3.INF


func find_guest_in_view(camera: Camera3D, max_distance: float = INTERACT_MAX_DISTANCE) -> Dictionary:
	if camera == null:
		return {}
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var best: Dictionary = {}
	var best_score := INF
	for id in _parties.keys():
		var party: Dictionary = _parties[id]
		for member_any in party.get("members", []):
			var member := member_any as Node3D
			if member == null or not member.visible:
				continue
			var to := member.global_position + Vector3(0.0, 1.1, 0.0) - origin
			var dist := to.length()
			if dist > max_distance or dist < 0.05:
				continue
			var cos_angle := forward.dot(to / dist)
			if cos_angle < 0.93:
				continue
			var score := dist * (2.0 - cos_angle)
			if score < best_score:
				best_score = score
				var info: Dictionary = (party.get("info", {}) as Dictionary).duplicate()
				info["distance"] = dist
				best = info
	return best


## World positions of visible guests (enemies use this to stalk sleepwalkers).
func get_visible_guest_positions() -> Array:
	var out: Array = []
	for id in _parties.keys():
		var party: Dictionary = _parties[id]
		var members: Array = party.get("members", [])
		if members.is_empty():
			continue
		var lead := members[0] as Node3D
		if lead != null and lead.visible:
			out.append({"guest_id": int(id), "position": lead.global_position, "archetype": str((party.get("info", {}) as Dictionary).get("archetype", ""))})
	return out


# ── snapshot → parties ─────────────────────────────────────────────────────────

func _refresh_snapshot() -> void:
	if GuestManager == null or not GuestManager.has_method("get_guest_life_snapshot"):
		return
	_snapshot = GuestManager.get_guest_life_snapshot()
	var seen: Dictionary = {}
	for entry_any in _snapshot:
		var entry: Dictionary = entry_any
		var id := int(entry.get("id", -1))
		seen[id] = true
		if not _parties.has(id):
			_parties[id] = _create_party(entry)
		var party: Dictionary = _parties[id]
		party["info"] = entry
		_sync_party_plan(party, entry)
	for id in _parties.keys():
		if seen.has(id):
			continue
		var party: Dictionary = _parties[id]
		var root := party.get("root", null) as Node3D
		if root != null and is_instance_valid(root):
			root.queue_free()
		_parties.erase(id)


func _create_party(entry: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "GuestParty_%d" % int(entry.get("id", 0))
	add_child(root)
	var members: Array = []
	var count: int = POSES.figure_count(str(entry.get("archetype", "")), int(entry.get("party_size", 1)), MAX_MEMBERS_PER_PARTY)
	var tex := _texture_for(str(entry.get("sprite_path", "")))
	for i in count:
		var member := Node3D.new()
		member.name = "Member%d" % i
		root.add_child(member)
		var sprite := Sprite3D.new()
		sprite.name = "Sprite"
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = true
		sprite.double_sided = true
		if tex != null:
			sprite.pixel_size = SPRITE_HEIGHT_M / float(tex.get_height()) * (0.92 + 0.08 * float(i % 3))
			sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
		# Slight tint per member so a family is not four clones.
		var tints := [Color(1, 1, 1), Color(0.86, 0.92, 1.0), Color(1.0, 0.9, 0.84), Color(0.9, 1.0, 0.88)]
		sprite.modulate = tints[i % tints.size()]
		member.add_child(sprite)
		member.add_child(_make_shadow())
		members.append(member)
	var marker := Sprite3D.new()
	marker.name = "MoodMarker"
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	marker.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	marker.pixel_size = 0.014
	marker.shaded = false
	marker.visible = false
	root.add_child(marker)
	return {
		"root": root,
		"members": members,
		"marker": marker,
		"plan_key": "",
		"path": PackedVector3Array(),
		"path_lengths": PackedFloat32Array(),
		"info": entry,
		"dwell_spot": Vector3.ZERO,
		"last_pos": Vector3.INF,
	}


func _sync_party_plan(party: Dictionary, entry: Dictionary) -> void:
	var act: Dictionary = entry.get("activity", {})
	var key := "%s|%s|%s|%s" % [act.get("kind", ""), act.get("from", ""), act.get("to", ""), act.get("start", "")]
	if key == str(party.get("plan_key", "")):
		return
	party["plan_key"] = key
	var from_tile := _parse_key(str(act.get("from", entry.get("tile", ""))))
	var to_tile := _parse_key(str(act.get("to", entry.get("tile", ""))))
	var start_world := _stand_point(from_tile, Vector2i(-1, -1))
	var last_pos: Vector3 = party.get("last_pos", Vector3.INF)
	# Picks up where they stand (the reception door after check-in is 12-13 m from the gate).
	if last_pos != Vector3.INF and last_pos.distance_to(start_world) < 16.0:
		start_world = last_pos
	if str(act.get("kind", "")) != "wait_gate":
		for k in ["wg_pos", "wg_route", "wg_target", "wg_dir"]:
			party.erase(k)
	var goal_tile := _stand_tile(to_tile, _grid_manager.world_to_grid(start_world))
	var goal_world := _tile_center(goal_tile)
	var path := _find_path(_grid_manager.world_to_grid(start_world), goal_tile)
	var points := PackedVector3Array()
	# Coming in from the barrier: walk from the waiting spot through the gap first.
	if str(act.get("kind", "")) == "arrive" and last_pos != Vector3.INF and _grid_manager.world_to_grid(last_pos).y < 0:
		points.append(last_pos)
		start_world = _tile_center(from_tile)
		path = _find_path(from_tile, goal_tile)
	# Out of the building they were in: from inside the door, out through it (it opens).
	var kind_now := str(act.get("kind", ""))
	party["exit"] = {}
	party["exit_open"] = false
	party.erase("entering")
	if bool(party.get("inside", false)):
		var from_st := DOOR_ANIM.structure_at(from_tile)
		if from_st != null and str(from_st.get_meta("building_type", "")) != "main_building":
			party["exit"] = DOOR_ANIM.entry_points(from_st)
	party["inside"] = false
	var ex: Dictionary = party["exit"]
	if not ex.is_empty():
		points.append(ex["inside"])
		points.append(ex["outside"])
	points.append(start_world)
	for p in path:
		points.append(_tile_center(p))
	points.append(goal_world)
	# Into a building: up to its door (the dwell takes them through it).
	party["entry"] = {}
	party["entry_open"] = false
	var indoor := (kind_now == "visit" and not OPEN_AIR_TYPES.has(str(act.get("target_type", "")))) or kind_now in ["rest", "sleep", "arrive"]
	if indoor:
		var to_st := DOOR_ANIM.structure_at(to_tile)
		if to_st != null and str(to_st.get_meta("building_type", "")) != "main_building":
			party["entry"] = DOOR_ANIM.entry_points(to_st)
			if not (party["entry"] as Dictionary).is_empty():
				points.append(party["entry"]["outside"])
	var lengths := PackedFloat32Array()
	var total := 0.0
	lengths.append(0.0)
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		lengths.append(total)
	party["path"] = points
	party["path_lengths"] = lengths
	party["goal_tile"] = goal_tile
	party["target_tile"] = to_tile
	party["dwell_spot"] = _dwell_spot(act, to_tile, goal_world, int(entry.get("id", 0)))


# ── per-frame motion ──────────────────────────────────────────────────────────

func _update_party(party: Dictionary, now: float, _delta: float) -> void:
	var info: Dictionary = party.get("info", {})
	var act: Dictionary = info.get("activity", {})
	var members: Array = party.get("members", [])
	var kind := str(act.get("kind", ""))
	var start := float(act.get("start", now))
	var arrive := float(act.get("arrive", now))
	var points: PackedVector3Array = party.get("path", PackedVector3Array())
	var lengths: PackedFloat32Array = party.get("path_lengths", PackedFloat32Array())
	var total := lengths[lengths.size() - 1] if lengths.size() > 0 else 0.0

	var walking := false
	var lead_pos := Vector3.ZERO
	var visible_now := true
	var dwell_phase := false
	if points.is_empty():
		visible_now = false
	elif now < arrive and arrive > start and total > 0.05:
		var t := clampf((now - start) / (arrive - start), 0.0, 1.0)
		lead_pos = _sample_path(points, lengths, t * total)
		walking = true
		# Coming out of a building: its door opens as they step out.
		if not bool(party.get("exit_open", true)) and not (party.get("exit", {}) as Dictionary).is_empty():
			party["exit_open"] = true
			DOOR_ANIM.open(party["exit"].get("door", null), 1.4)
	elif kind == "wait_gate":
		# Through the barrier and up the path to the reception, in the order they came;
		# the first two go in (the counter, the bench: building_interior.gd), the rest
		# wait at the door.
		dwell_phase = true
		var qi := int(act.get("queue_index", 0))
		var moved := _walk_to_reception(party, _gate_waiting_spot(qi), _delta)
		lead_pos = party["wg_pos"]
		walking = moved
		if not moved and qi <= 1:
			visible_now = false
	else:
		dwell_phase = true
		lead_pos = points[points.size() - 1]
		var queued := bool(act.get("queued", false))
		var going_in := (kind == "visit" and not queued and not OPEN_AIR_TYPES.has(str(act.get("target_type", "")))) or HIDDEN_DWELL_KINDS.has(kind)
		var entry: Dictionary = party.get("entry", {})
		if going_in and not entry.is_empty():
			# Through the door: it swings open, they step in one after another, it shuts.
			var e := (now - arrive) / ENTER_MIN
			visible_now = e < 1.0 + 0.35 * float(members.size() - 1)
			if visible_now and not bool(party.get("entry_open", false)):
				party["entry_open"] = true
				DOOR_ANIM.open(entry.get("door", null), 1.2 + 0.4 * float(members.size()))
			if not visible_now:
				party["inside"] = true
			lead_pos = entry["outside"]
			party["entering"] = e
		elif going_in:
			visible_now = (now - arrive) < 0.6
		elif kind == "leave":
			visible_now = (now - arrive) < 1.0
		else:
			lead_pos = party.get("dwell_spot", lead_pos)
	if str(info.get("status", "")) == "sleep" and kind == "sleep" and dwell_phase:
		visible_now = false

	party["last_pos"] = lead_pos
	var side := Vector3.RIGHT
	if walking and kind == "wait_gate":
		var wdir: Vector3 = party.get("wg_dir", Vector3.FORWARD)
		side = wdir.cross(Vector3.UP)
	elif walking:
		var ahead := _sample_path(points, lengths, minf(total, clampf((now - start) / maxf(arrive - start, 0.01), 0.0, 1.0) * total + 0.5))
		var dir := ahead - lead_pos
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			side = dir.normalized().cross(Vector3.UP)
	# At the fire, on the slide, on the pitch: the attraction places and poses them
	# (scripts/attractions/: campfire.gd, slide_ride.gd, pitch_play.gd).
	var posed: Node = null
	if dwell_phase and kind == "visit" and not bool(act.get("queued", false)) and OPEN_AIR_TYPES.has(str(act.get("target_type", ""))):
		posed = _attraction_at(party.get("target_tile", Vector2i(-1, -1)))
	var marker_pos := lead_pos
	for i in members.size():
		var member := members[i] as Node3D
		if member == null:
			continue
		member.visible = visible_now
		if not visible_now:
			continue
		var msprite := member.get_node_or_null("Sprite") as Sprite3D
		if posed != null and posed.pose_member(int(info.get("id", 0)), i, members.size(), member, msprite, info, _time):
			if i == 0:
				marker_pos = member.position + Vector3(0, float(member.get_meta("marker_drop", 0.0)), 0)
			continue
		POSES.set_pose(msprite, str(info.get("sprite_path", "")), "")
		# Back on the ground after an attraction that lifted them off it (the slide).
		var blob := member.get_node_or_null("BlobShadow") as Node3D
		if blob != null:
			blob.visible = true
		var offset := side * (float(i) - float(members.size() - 1) * 0.5) * MEMBER_SPREAD_M
		if not walking and members.size() > 1:
			# Standing about: a loose huddle (so they never line up behind each other
			# from where you look), turned a little differently for every party.
			var turn := float(int(info.get("id", 0)) * 97 % 360) * PI / 180.0
			var ang := turn + TAU * float(i) / float(members.size())
			offset = Vector3(cos(ang), 0.0, sin(ang)) * (0.55 + 0.12 * float(members.size()))
		if dwell_phase and bool(act.get("queued", false)):
			offset = Vector3(float(i) * 0.4, 0.0, 0.9 + float(int(info.get("id", 0)) % 3) * 0.7)
		var pos := lead_pos + offset
		var sprite := member.get_node_or_null("Sprite") as Sprite3D
		if dwell_phase and party.has("entering") and not (party.get("entry", {}) as Dictionary).is_empty():
			var en: Dictionary = party["entry"]
			var ei := float(party["entering"]) - 0.35 * float(i)
			if ei >= 1.0:
				member.visible = false
				continue
			var k := clampf(ei, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			pos = (en["outside"] as Vector3).lerp(en["inside"], k) + (en["outside"] - en["inside"]).normalized() * 0.45 * maxf(0.0, -ei) * 2.0
			# No door leaf: a tent; they duck in under the flap.
			if en.get("door", null) == null:
				pos.y -= smoothstep(0.35, 1.0, ei) * 1.0
			member.position = pos
			POSES.set_pose(sprite, str(info.get("sprite_path", "")), "")
			continue
		if walking:
			var phase := floorf(_time * ANIM_FPS) / ANIM_FPS * WALK_BOB_HZ * TAU + float(i) * 1.7
			pos.y = absf(sin(phase)) * 0.06
			if sprite != null:
				sprite.flip_h = sin(phase * 0.5) > 0.0
				sprite.rotation.z = sin(phase) * 0.04
		else:
			pos.y = 0.0
			if sprite != null:
				sprite.rotation.z = sin(_time * 0.8 + float(i)) * 0.01
		member.position = pos
	_update_marker(party, info, marker_pos, visible_now)


## The attraction controller whose footprint holds `tile` (group "attraction"), or null.
func _attraction_at(tile: Vector2i) -> Node:
	if tile.x < 0 or not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group("attraction"):
		if n.has_method("covers_tile") and n.covers_tile(tile):
			return n
	return null


## Build games had no floating text; guests show a small marker instead: a red "!"
## when miserable, a "?" while they are hunting for something they need, a heart when
## delighted. What they actually say goes to the HUD quote line (see nearby_thoughts).
func _update_marker(party: Dictionary, info: Dictionary, lead_pos: Vector3, visible_now: bool) -> void:
	var marker := party.get("marker", null) as Sprite3D
	if marker == null:
		return
	var mood := float(info.get("mood", 60.0))
	var worst: Dictionary = info.get("worst_need", {})
	var tex: Texture2D = null
	if mood < GUEST_NEEDS.UNHAPPY_MOOD:
		tex = MARKER_ANGRY
	elif not worst.is_empty() and float(worst.get("value", 100.0)) < GUEST_NEEDS.CRITICAL_THRESHOLD + 10.0:
		tex = MARKER_NEED
	elif mood >= 80.0:
		tex = MARKER_HAPPY
	if not visible_now or tex == null:
		marker.visible = false
		return
	marker.texture = tex
	marker.position = lead_pos + Vector3(0.0, SPRITE_HEIGHT_M + 0.35 + sin(_time * 3.0) * 0.05, 0.0)
	marker.visible = true


## Fresh things visible guests near `world_pos` said, newest first:
## [{guest_id, name, text, mood, distance, key}]. `key` is stable per utterance so the
## HUD can show each line once.
func nearby_thoughts(world_pos: Vector3, radius: float = 9.0, max_age_minutes: int = 6) -> Array:
	var out: Array = []
	for id in _parties.keys():
		var party: Dictionary = _parties[id]
		var info: Dictionary = party.get("info", {})
		var text := str(info.get("thought", ""))
		if text.is_empty() or int(info.get("thought_age", 9999)) > max_age_minutes:
			continue
		var members: Array = party.get("members", [])
		if members.is_empty():
			continue
		var lead := members[0] as Node3D
		if lead == null or not lead.visible:
			continue
		var d := lead.global_position.distance_to(world_pos)
		if d > radius:
			continue
		out.append({
			"guest_id": int(id),
			"name": str(info.get("name", "Guest")),
			"text": text,
			"mood": float(info.get("mood", 60.0)),
			"distance": d,
			"key": "%d:%s" % [int(id), text.hash()],
		})
	out.sort_custom(func(a, b): return float(a["distance"]) < float(b["distance"]))
	return out


# ── navigation ───────────────────────────────────────────────────────────────

func _rebuild_nav() -> void:
	_nav_dirty = false
	_nav_timer = 0.0
	var size: Vector2i = _grid_manager.get_grid_size()
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			_astar.set_point_solid(c, not _is_walkable(c))
			if _is_path_tile(c):
				_astar.set_point_weight_scale(c, 0.6)


func _is_walkable(c: Vector2i) -> bool:
	var tile = _grid_manager.get_tile(c)
	if tile == null:
		return false
	if int(tile.tile_type) == 1:  # lake
		return false
	# Anything standing on the tile blocks it (the reception too, which is placed
	# without a builder cell and used to be walked straight through).
	if not tile.occupied and tile.occupant == null:
		return true
	return _is_path_tile(c)


func _is_path_tile(c: Vector2i) -> bool:
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return false
	var cell: Dictionary = state.grid.cells.get(c, {})
	return str(cell.get("type", "")) == "path"


func _find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to):
		return out
	if _astar.is_point_solid(from) or _astar.is_point_solid(to):
		return out
	var ids := _astar.get_id_path(from, to)
	for p in ids:
		out.append(p)
	return out


## Nearest walkable tile next to `tile` (a building's root, a tree...), closest to `near`.
func _stand_tile(tile: Vector2i, near: Vector2i) -> Vector2i:
	if _astar.is_in_boundsv(tile) and not _astar.is_point_solid(tile):
		return tile
	var state = CoreRoot.get_state()
	var cells: Array[Vector2i] = [tile]
	if state != null and state.grid != null and state.grid.cells.has(tile):
		var cell: Dictionary = state.grid.cells[tile]
		var root = cell.get("root_coord", tile)
		for c_any in state.grid.cells.keys():
			if (state.grid.cells[c_any] as Dictionary).get("root_coord", Vector2i(-99, -99)) == root:
				cells.append(c_any)
	var best := tile
	var best_d := INF
	for c in cells:
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = c + d
			if not _astar.is_in_boundsv(n) or _astar.is_point_solid(n):
				continue
			var dist := Vector2(n - near).length() + (0.0 if d == Vector2i(0, -1) else 0.4)
			if dist < best_d:
				best_d = dist
				best = n
	if best_d == INF:
		# Search outward for anything walkable.
		for r in range(1, 5):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var n := tile + Vector2i(dx, dy)
					if _astar.is_in_boundsv(n) and not _astar.is_point_solid(n):
						return n
	return best


func _stand_point(tile: Vector2i, near: Vector2i) -> Vector3:
	return _tile_center(_stand_tile(tile, near if near.x >= 0 else tile))


func _tile_center(c: Vector2i) -> Vector3:
	return _grid_manager.grid_to_world(c)


func _dwell_spot(act: Dictionary, to_tile: Vector2i, goal_world: Vector3, seed_id: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_id * 7919 + int(act.get("start", 0))
	var type := str(act.get("target_type", ""))
	if OPEN_AIR_TYPES.has(type):
		# Stand around the attraction, facing it.
		var center: Vector3 = _grid_manager.grid_to_world(to_tile)
		var angle := rng.randf() * TAU
		return center + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.6, 2.4)
	return goal_world + Vector3(rng.randf_range(-0.9, 0.9), 0.0, rng.randf_range(-0.9, 0.9))


func _sample_path(points: PackedVector3Array, lengths: PackedFloat32Array, dist: float) -> Vector3:
	if points.size() == 1:
		return points[0]
	for i in range(1, points.size()):
		if dist <= lengths[i]:
			var seg := lengths[i] - lengths[i - 1]
			var t := 0.0 if seg <= 0.0001 else (dist - lengths[i - 1]) / seg
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]


# ── helpers ──────────────────────────────────────────────────────────────────

## Walks a waiting party along the fixed way in (the road outside the barrier, the gate
## lane, the reception door) at a walking pace in real time. True while moving.
const WAIT_WALK_SPEED := 1.35


func _walk_to_reception(party: Dictionary, target: Vector3, delta: float) -> bool:
	if not party.has("wg_pos"):
		var gate := get_tree().get_first_node_in_group("camp_gate") if is_inside_tree() else null
		var road: Vector3 = gate.road_spot() if gate != null and gate.has_method("road_spot") else target
		party["wg_pos"] = road
		var route: Array = [road]
		if gate != null and gate.has_method("way_in"):
			route.append_array(gate.way_in())
		party["wg_route"] = route
	var route: Array = party.get("wg_route", [])
	if party.get("wg_target", Vector3.INF) != target:
		party["wg_target"] = target
		route.append(target)
		party["wg_route"] = route
	var pos: Vector3 = party["wg_pos"]
	var budget := WAIT_WALK_SPEED * delta
	var moved := false
	while budget > 0.0 and not route.is_empty():
		var next: Vector3 = route[0]
		var d := pos.distance_to(next)
		if d <= budget:
			pos = next
			budget -= d
			route.pop_front()
			moved = moved or d > 0.001
		else:
			party["wg_dir"] = (next - pos).normalized()
			pos = pos + (next - pos) / d * budget
			budget = 0.0
			moved = true
	party["wg_pos"] = pos
	party["wg_route"] = route
	return moved


func _gate_waiting_spot(i: int) -> Vector3:
	var gate := get_tree().get_first_node_in_group("camp_gate") if is_inside_tree() else null
	if gate != null and gate.has_method("waiting_spot"):
		return gate.waiting_spot(i)
	return _tile_center(Vector2i(10, 0)) + Vector3(0, 0, -5.0 - float(i) * 1.7)


func _now_abs_float() -> float:
	if _now_provider.is_valid():
		return float(_now_provider.call())
	return 0.0


func _texture_for(path: String) -> Texture2D:
	if path.is_empty():
		path = "res://assets/textury/npc/host1.png"
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex := load(path) as Texture2D
	_texture_cache[path] = tex
	return tex


func _make_shadow() -> MeshInstance3D:
	if _shadow_mesh == null:
		_shadow_mesh = QuadMesh.new()
		_shadow_mesh.size = Vector2(0.75, 0.42)
		_shadow_mesh.orientation = PlaneMesh.FACE_Y
		_shadow_material = StandardMaterial3D.new()
		_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.42)
		_shadow_mesh.material = _shadow_material
	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	shadow.mesh = _shadow_mesh
	shadow.position = Vector3(0.0, 0.03, 0.0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow


static func _parse_key(key: String) -> Vector2i:
	var parts := key.split(":")
	if parts.size() != 2:
		return Vector2i(10, 2)
	return Vector2i(int(parts[0]), int(parts[1]))
