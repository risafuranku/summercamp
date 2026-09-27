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

const SNAPSHOT_INTERVAL_SEC := 0.25
const NAV_REBUILD_INTERVAL_SEC := 3.0
const SPRITE_HEIGHT_M := 1.72
const MEMBER_SPREAD_M := 0.55
const MAX_MEMBERS_PER_PARTY := 4
const WALK_BOB_HZ := 2.6
const OPEN_AIR_TYPES := ["bonfire", "sports_field", "lake_slide"]
const HIDDEN_DWELL_KINDS := ["sleep", "rest", "arrive"]
const INTERACT_MAX_DISTANCE := 4.2
const MARKER_ANGRY := preload("res://assets/textury/npc/mood_angry.png")
const MARKER_HAPPY := preload("res://assets/textury/npc/mood_happy.png")
const MARKER_NEED := preload("res://assets/textury/npc/mood_need.png")

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
	var now := _now_abs_float()
	for id in _parties.keys():
		_update_party(_parties[id], now, delta)


## Guest under the player's crosshair, for the talk interaction. Returns the snapshot
## entry (plus "distance") or {} when nobody is close enough and in view.
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
	var count := clampi(int(entry.get("party_size", 1)), 1, MAX_MEMBERS_PER_PARTY)
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
	if last_pos != Vector3.INF and last_pos.distance_to(start_world) < 12.0:
		start_world = last_pos
	var goal_tile := _stand_tile(to_tile, _grid_manager.world_to_grid(start_world))
	var goal_world := _tile_center(goal_tile)
	var path := _find_path(_grid_manager.world_to_grid(start_world), goal_tile)
	var points := PackedVector3Array()
	points.append(start_world)
	for p in path:
		points.append(_tile_center(p))
	points.append(goal_world)
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
	else:
		dwell_phase = true
		lead_pos = points[points.size() - 1]
		var queued := bool(act.get("queued", false))
		if kind == "visit" and not queued and not OPEN_AIR_TYPES.has(str(act.get("target_type", ""))):
			# Inside the building: hide after a short beat at the door.
			visible_now = (now - arrive) < 0.6
		elif HIDDEN_DWELL_KINDS.has(kind):
			visible_now = (now - arrive) < 0.6
		elif kind == "leave":
			visible_now = (now - arrive) < 1.0
		else:
			lead_pos = party.get("dwell_spot", lead_pos)
	if str(info.get("status", "")) == "sleep" and kind == "sleep" and dwell_phase:
		visible_now = false

	party["last_pos"] = lead_pos
	var side := Vector3.RIGHT
	if walking:
		var ahead := _sample_path(points, lengths, minf(total, clampf((now - start) / maxf(arrive - start, 0.01), 0.0, 1.0) * total + 0.5))
		var dir := ahead - lead_pos
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			side = dir.normalized().cross(Vector3.UP)
	for i in members.size():
		var member := members[i] as Node3D
		if member == null:
			continue
		member.visible = visible_now
		if not visible_now:
			continue
		var offset := side * (float(i) - float(members.size() - 1) * 0.5) * MEMBER_SPREAD_M
		if dwell_phase and bool(act.get("queued", false)):
			offset = Vector3(float(i) * 0.4, 0.0, 0.9 + float(int(info.get("id", 0)) % 3) * 0.7)
		var pos := lead_pos + offset
		var sprite := member.get_node_or_null("Sprite") as Sprite3D
		if walking:
			var phase := _time * WALK_BOB_HZ * TAU + float(i) * 1.7
			pos.y = absf(sin(phase)) * 0.06
			if sprite != null:
				sprite.flip_h = sin(phase * 0.5) > 0.0
				sprite.rotation.z = sin(phase) * 0.04
		else:
			pos.y = 0.0
			if sprite != null:
				sprite.rotation.z = sin(_time * 0.8 + float(i)) * 0.01
		member.position = pos
	_update_marker(party, info, lead_pos, visible_now)


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
	if not tile.occupied:
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
