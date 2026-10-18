extends Node3D

const TREE_WIND_SHADER = preload("res://materials/tree_wind.gdshader")
const CAMP_LAKE_SCRIPT = preload("res://scripts/camp_lake.gd")

@export_range(0.0, 1.0, 0.01) var tree_spawn_chance: float = 0.30
@export var wind_direction_degrees: float = 32.0
@export var tree_wobble_intensity: float = 0.028
@export var tree_wobble_speed: float = 0.34
@export var tree_wobble_variation_degrees: float = 18.0
@export_range(0.0, 1.0, 0.01) var grass_patch_chance: float = 0.0
@export_range(0, 8, 1) var grass_clumps_per_patch: int = 0
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const CAMP_GATE_SCRIPT = preload("res://scripts/camp_gate.gd")
## The road on past the barrier to the bus stop (built with the gate).
const ROAD_SOUTH_SCRIPT = preload("res://scripts/town/road_south.gd")
const POWER_BUILDING_EDGE_PADDING: int = 2
const POWER_BUILDING_WATER_PADDING: int = 2
const POWER_BUILDING_ROTATION_STEPS: int = 2
const SEWER_WATER_PADDING: int = 2

var _grid_manager
var _building_manager
var _rng = RandomNumberGenerator.new()
## The camp's seed (generate_base_world): 0 until a camp is drawn, then kept.
var world_seed: int = 0

var _terrain_root: Node3D
var _nature_root: Node3D
var _texture_style

# Shared tree meshes/materials (a camp has hundreds of trees; one set of resources).
var _tree_meshes: Dictionary = {}
var _tree_materials: Dictionary = {}

const TREE_KIND_SPRUCE := 0
const TREE_KIND_BIRCH := 1
const TREE_KIND_DEAD := 2
## Spruce tiers: [bottom radius, height, y of the tier's base].
const SPRUCE_TIERS := [[1.55, 1.7, 1.15], [1.2, 1.5, 2.15], [0.86, 1.3, 3.0], [0.5, 1.1, 3.75]]
const HORIZON_TREE_COUNT := 900
const CORN_DEPTH := 24.0
const CORNFIELD_SCRIPT = preload("res://scripts/cornfield.gd")
const HORIZON_HILL_COUNT := 14


func _ready() -> void:
	_ensure_roots()
	_texture_style = TEXTURE_STYLE_SCRIPT.new()


func setup(grid_manager, building_manager) -> void:
	_grid_manager = grid_manager
	_building_manager = building_manager
	_ensure_roots()


func generate_world() -> void:
	generate_base_world(true, true)


func generate_base_world(spawn_default_buildings: bool = true, spawn_trees: bool = true) -> void:
	_corn_gate_z = INF
	_ensure_roots()
	if _grid_manager == null or _building_manager == null:
		push_error("WorldGenerator is missing GridManager or BuildingManager reference.")
		return

	# The camp's own seed, saved with the game (main.gd "grid.seed") and sent to the
	# other warden in co-op: the same seed draws the same lake, fences, corn, litter and
	# horizon, and each tile's tree is its own (_tile_rng), so the camp is the same camp
	# after a load and on both machines. 0 asks for a new camp.
	if world_seed == 0:
		world_seed = (randi() & 0x7fffffff) | 1
	_rng.seed = world_seed
	_corn_seed_value = -1
	_clear_generated_nodes()
	_building_manager.clear_structures()

	_grid_manager.reset_tiles(_grid_manager.TILE_GRASS)
	_mark_north_lake_row()
	var entrance_origin = _mark_south_entrance_reserved_area()

	_generate_terrain()
	if spawn_default_buildings:
		_building_manager.place_main_building(entrance_origin, Vector2i(2, 2))
		place_starter_path()
		_place_power_building_landmark()
		place_sewer_landmark()
	if spawn_trees:
		_spawn_random_trees()

	_grid_manager.rebuild_debug_mesh()


func populate_trees() -> void:
	if _grid_manager == null:
		return
	_ensure_roots()
	_clear_nature_nodes_and_occupancy()
	_spawn_random_trees()


func place_sewer_landmark() -> bool:
	if _grid_manager == null or _building_manager == null:
		return false
	for coord in _collect_sewer_landmark_candidates():
		if not _grid_manager.is_in_bounds(coord):
			continue
		var tile = _grid_manager.get_tile(coord)
		if tile == null:
			continue
		if tile.tile_type != _grid_manager.TILE_GRASS:
			continue
		if tile.occupied:
			continue
		if _building_manager.place_building_at(coord, "sewer"):
			return true
	return false


func _collect_sewer_landmark_candidates() -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var seen: Dictionary = {}
	if _grid_manager == null:
		return candidates

	for coord in _grid_manager.get_all_coords():
		var tile = _grid_manager.get_tile(coord)
		if tile == null or tile.tile_type != _grid_manager.TILE_LAKE:
			continue
		_push_unique_coord(candidates, seen, coord + Vector2i(0, -SEWER_WATER_PADDING))
		_push_unique_coord(candidates, seen, coord + Vector2i(1, 0))
		_push_unique_coord(candidates, seen, coord + Vector2i(-1, 0))
		_push_unique_coord(candidates, seen, coord + Vector2i(0, 1))

	if not candidates.is_empty():
		return candidates

	var center_x := int(floor(float(_grid_manager.grid_width) / 2.0))
	var fallback_y: int = int(max(0, _grid_manager.grid_height - 3))
	var x_offsets := [0, 2, -2, 4, -4, 6, -6]
	for x_off in x_offsets:
		var x := clampi(center_x + int(x_off), 0, _grid_manager.grid_width - 1)
		_push_unique_coord(candidates, seen, Vector2i(x, fallback_y))
		_push_unique_coord(candidates, seen, Vector2i(x, max(0, fallback_y - 1)))
	return candidates


func _push_unique_coord(out: Array[Vector2i], seen: Dictionary, coord: Vector2i) -> void:
	var key := "%d:%d" % [coord.x, coord.y]
	if seen.has(key):
		return
	seen[key] = true
	out.append(coord)


func _mark_north_lake_row() -> void:
	var y = _grid_manager.grid_height - 1
	for x in range(_grid_manager.grid_width):
		_grid_manager.set_tile_type(Vector2i(x, y), _grid_manager.TILE_LAKE)


## The entrance: the gate lane (1 tile wide) on the south edge, the reception (2x2) west
## of it one tile in from the fence, and the starter path in front of both. Reserved, so
## nothing is built in the way.
func _mark_south_entrance_reserved_area() -> Vector2i:
	var center_start_x = int(floor((_grid_manager.grid_width - 2) * 0.5))
	for y in range(4):
		for x in range(center_start_x, center_start_x + 3):
			_grid_manager.set_tile_type(Vector2i(x, y), _grid_manager.TILE_RESERVED)

	return Vector2i(center_start_x, 1)


## The starter path: the gravel road goes on through the barrier, up the gate lane past
## the reception, turns in front of the reception's door, and one tile on into the camp
## for whatever gets built next. It cannot be bulldozed (builder_authority.gd), so the
## camp always joins the entrance. On a loaded game the tiles that are already a path are
## marked again, free ones are laid.
func starter_path_tiles() -> Array[Vector2i]:
	var g := gate_tile()
	var out: Array[Vector2i] = []
	for y in range(0, 5):
		out.append(Vector2i(g.x, y))
	out.append(Vector2i(g.x - 1, 3))
	out.append(Vector2i(g.x - 2, 3))
	return out


func place_starter_path() -> void:
	if _grid_manager == null or _building_manager == null:
		return
	for t in starter_path_tiles():
		if not _grid_manager.is_in_bounds(t):
			continue
		var tile = _grid_manager.get_tile(t)
		var occ = tile.occupant if tile != null else null
		if occ != null:
			var root := occ as Node
			while root != null and not root.has_meta("grid_origin"):
				root = root.get_parent()
			if root != null and str(root.get_meta("building_type", "")) == "path":
				root.set_meta("permanent", true)
			continue
		_building_manager.place_path_at(t, true)


## The gate lane tile on the south edge (east of the reception).
func gate_tile() -> Vector2i:
	return Vector2i(int(floor((_grid_manager.grid_width - 2) * 0.5)) + 2, 0)


func _place_power_building_landmark() -> void:
	if _grid_manager == null or _building_manager == null:
		return
	var footprint = Vector2i.ONE
	if _building_manager.has_method("get_footprint_for_building"):
		footprint = _building_manager.get_footprint_for_building("power_generator")

	var primary = Vector2i(
		max(0, _grid_manager.grid_width - POWER_BUILDING_EDGE_PADDING - footprint.x),
		max(0, _grid_manager.grid_height - POWER_BUILDING_WATER_PADDING - footprint.y)
	)
	var candidates: Array[Vector2i] = [
		primary,
		primary + Vector2i(-1, 0),
		primary + Vector2i(-2, 0),
		primary + Vector2i(0, -1),
		primary + Vector2i(-1, -1),
	]

	for candidate in candidates:
		if not _grid_manager.is_in_bounds(candidate):
			continue
		if not _grid_manager.can_place_footprint(candidate, footprint):
			continue
		if _building_manager.place_building_at(candidate, "power_generator"):
			_mark_power_building_permanent(candidate)
			return


func _mark_power_building_permanent(coord: Vector2i) -> void:
	if _grid_manager == null:
		return
	var tile = _grid_manager.get_tile(coord)
	if tile == null or tile.occupant == null:
		return
	var root = _resolve_occupant_root(tile.occupant)
	if root == null:
		return
	root.set_meta("is_permanent", true)
	root.set_meta("builder_locked", true)
	root.set_meta("build_rotation", POWER_BUILDING_ROTATION_STEPS)
	root.rotation.y = deg_to_rad(float(POWER_BUILDING_ROTATION_STEPS) * 90.0)


func _resolve_occupant_root(occupant: Variant) -> Node3D:
	if occupant == null:
		return null
	var node = occupant as Node
	if node == null:
		return null
	if node is Node3D and node.has_meta("grid_origin"):
		return node as Node3D
	var current = node.get_parent()
	while current != null:
		if current is Node3D and current.has_meta("grid_origin"):
			return current as Node3D
		current = current.get_parent()
	return null


func _generate_terrain() -> void:
	var map_size = _grid_manager.get_map_size_world()
	var map_center = _grid_manager.get_map_center_world()
	# Override grass texture if needed
	var batch2_grass_tex = _load_force_texture("res://assets/textury/redneck/grass.png")
	if batch2_grass_tex == null:
		print("Ground: Falling back for batch2 grass...")
		batch2_grass_tex = _load_force_texture("res://assets/textury/redneck/grass.png")
	if batch2_grass_tex == null and _texture_style != null:
		batch2_grass_tex = _texture_style.pick_texture("grass", Color(0.80, 1.0, 0.80, 1.0))
	if batch2_grass_tex == null:
		batch2_grass_tex = _load_force_texture("res://assets/textury/redneck/RRTX0296.png")

	var ground = StaticBody3D.new()
	ground.name = "Ground"
	_terrain_root.add_child(ground)

	var ground_size = Vector3(map_size.x, 1.0, map_size.y)
	ground.position = map_center + Vector3(0.0, -0.5, 0.0)

	var ground_collider = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = ground_size
	ground_collider.shape = ground_shape
	ground.add_child(ground_collider)

	var ground_mesh = MeshInstance3D.new()
	var ground_box = BoxMesh.new()
	ground_box.size = ground_size
	ground_mesh.mesh = ground_box
	var ground_uv_scale = Vector3(map_size.x * 0.5, 1.0, map_size.y * 0.5)
	var grass_mat = _make_psx_material(Color(0.42, 0.72, 0.36), 0.006, 24.0, 6.0, 1.0, 0.0, 0.10, 0.22, "grass", 0.26)
	var grass_base_mat := grass_mat as BaseMaterial3D
	if grass_base_mat != null:
		grass_base_mat.uv1_scale = ground_uv_scale
		if batch2_grass_tex != null:
			grass_base_mat.albedo_texture = batch2_grass_tex
			grass_base_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	ground_mesh.material_override = grass_mat
	ground_mesh.add_to_group("season_ground")
	ground.add_child(ground_mesh)

	# Explicit grass overlay to guarantee visible ground texture.
	var grass_overlay = MeshInstance3D.new()
	var overlay_plane = PlaneMesh.new()
	overlay_plane.size = Vector2(map_size.x, map_size.y)
	grass_overlay.mesh = overlay_plane
	grass_overlay.position = map_center + Vector3(0.0, 0.032, 0.0)
	var overlay_uv_scale = Vector3(map_size.x * 0.5, map_size.y * 0.5, 1.0)
	var grass_overlay_mat := StandardMaterial3D.new()
	grass_overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	grass_overlay_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	grass_overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	grass_overlay_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	grass_overlay_mat.uv1_scale = overlay_uv_scale
	grass_overlay_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	if batch2_grass_tex != null:
		grass_overlay_mat.albedo_texture = batch2_grass_tex
	grass_overlay.material_override = grass_overlay_mat
	grass_overlay.add_to_group("season_ground")
	grass_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(grass_overlay)

	var lake = StaticBody3D.new()
	lake.name = "Lake"
	_terrain_root.add_child(lake)

	var lake_center = _grid_manager.grid_to_world(Vector2i(int(floor(float(_grid_manager.grid_width) / 2.0)), _grid_manager.grid_height - 1))
	lake.position = Vector3(map_center.x, 0.08, lake_center.z)

	var lake_size = Vector3(map_size.x, 0.2, _grid_manager.tile_size)
	var lake_collider = CollisionShape3D.new()
	var lake_shape = BoxShape3D.new()
	lake_shape.size = lake_size
	lake_collider.shape = lake_shape
	lake.add_child(lake_collider)

	var lake_mesh = MeshInstance3D.new()
	var lake_plane = BoxMesh.new()
	lake_plane.size = lake_size
	lake_mesh.mesh = lake_plane
	var lake_uv_scale = Vector3(max(1.0, lake_size.x * 0.34), 1.0, max(1.0, lake_size.z * 0.34))
	var lake_mat = _make_psx_material(Color(0.32, 0.56, 0.70), 0.004, 22.0, 6.0, 1.0, 0.0, 0.10, 0.20, "water", 0.58)
	var lake_base_mat := lake_mat as BaseMaterial3D
	if lake_base_mat != null:
		lake_base_mat.uv1_scale = lake_uv_scale
	lake_mesh.material_override = lake_mat
	lake.add_child(lake_mesh)
	# The camp's shore row is drawn by the lake beyond it (scripts/camp_lake.gd).
	lake_mesh.visible = false
	_build_lake(map_size, map_center)
	_spawn_perimeter_fence(map_size, map_center)
	_spawn_horizon(map_size, map_center, batch2_grass_tex)
	_spawn_cornfield(map_size, map_center)
	_spawn_camp_gate(map_size, map_center)

	_scatter_ground_litter()

	# Dense grass clumps looked like floating green squares; keep only textured terrain.
	# _spawn_stylized_grass()


func _spawn_perimeter_fence(map_size: Vector2, map_center: Vector3) -> void:
	var fence_root = Node3D.new()
	fence_root.name = "PerimeterFence"
	_terrain_root.add_child(fence_root)
	var inset = 0.08
	var fence_height = 1.18
	var fence_thickness = 0.12
	var north_south_size = Vector3(map_size.x + 0.24, fence_height, fence_thickness)
	var east_west_size = Vector3(fence_thickness, fence_height, map_size.y + 0.24)
	# No fence across the north side: that is the lake shore (camp_lake.gd walls it off).
	# The south fence has the gate gap east of the reception.
	var south_z: float = map_center.z - (map_size.y * 0.5) + inset
	var gap_x: float = _grid_manager.grid_to_world(gate_tile()).x
	var west_end: float = map_center.x - map_size.x * 0.5 - 0.12
	var east_end: float = map_center.x + map_size.x * 0.5 + 0.12
	var gap_half := 2.3
	_add_fence_segment(fence_root, "FenceSouthWest", Vector3((west_end + gap_x - gap_half) * 0.5, fence_height * 0.5, south_z), Vector3((gap_x - gap_half) - west_end, fence_height, fence_thickness))
	_add_fence_segment(fence_root, "FenceSouthEast", Vector3((gap_x + gap_half + east_end) * 0.5, fence_height * 0.5, south_z), Vector3(east_end - (gap_x + gap_half), fence_height, fence_thickness))
	_add_fence_segment(fence_root, "FenceEast", map_center + Vector3((map_size.x * 0.5) - inset, fence_height * 0.5, 0.0), east_west_size)
	# The west fence has the wicket gate into the corn (cornfield.gd builds the gate).
	var west_x: float = map_center.x - (map_size.x * 0.5) + inset
	var z0: float = map_center.z - map_size.y * 0.5 - 0.12
	var z1: float = map_center.z + map_size.y * 0.5 + 0.12
	var gz := corn_gate_z(map_size, map_center)
	var gh := 0.9
	# On the field side only posts and two wires: the corn runs on both sides of it, so
	# the field reads as one with the camp's own corn (corn tiles below), not behind a wall.
	_add_wire_fence(fence_root, "FenceWestS", west_x, z0, gz - gh, fence_height)
	_add_wire_fence(fence_root, "FenceWestN", west_x, gz + gh, z1, fence_height)


## A field fence along z at `x`: posts every 2.2 m, two wires, the same invisible barrier
## the board fence had (the Antlered Man walks it like any other fence).
func _add_wire_fence(parent: Node3D, node_name: String, x: float, z_from: float, z_to: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = Vector3(x, height * 0.5, (z_from + z_to) * 0.5)
	parent.add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.12, height, absf(z_to - z_from))
	col.shape = shape
	body.add_child(col)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.36, 0.28, 0.2)
	post_mat.roughness = 1.0
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.42, 0.42, 0.4)
	var n := int(absf(z_to - z_from) / 2.2)
	for i in n + 1:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.1, height + 0.1, 0.1)
		post.mesh = pm
		post.material_override = post_mat
		post.position = Vector3(0.0, 0.05, lerpf(z_from, z_to, float(i) / float(maxi(1, n))) - body.position.z)
		post.rotation.z = _rng.randf_range(-0.04, 0.04)
		body.add_child(post)
	for h in [0.45, 0.95]:
		var wire := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.015, 0.015, absf(z_to - z_from))
		wire.mesh = wm
		wire.material_override = wire_mat
		wire.position = Vector3(0.0, h - height * 0.5, 0.0)
		body.add_child(wire)


var _lake_poly := PackedVector2Array()


func _build_lake(map_size: Vector2, map_center: Vector3) -> void:
	var shore_z: float = _grid_manager.grid_to_world(Vector2i(0, _grid_manager.grid_height - 1)).z - _grid_manager.tile_size * 0.5
	var north_z: float = map_center.z + map_size.y * 0.5
	var west: float = map_center.x - map_size.x * 0.5
	var east: float = map_center.x + map_size.x * 0.5
	var lake_seed := _rng.randi()
	var lake := CAMP_LAKE_SCRIPT.new()
	_terrain_root.add_child(lake)
	lake.build(get_parent(), shore_z, north_z, west, east, lake_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = lake_seed
	var poly := CAMP_LAKE_SCRIPT.water_polygon(shore_z, north_z, west, east, rng)
	_lake_poly = Geometry2D.offset_polygon(poly, 4.0)[0]


func _spawn_camp_gate(map_size: Vector2, map_center: Vector3) -> void:
	var gate = CAMP_GATE_SCRIPT.new()
	gate.add_to_group("camp_gate")
	_terrain_root.add_child(gate)
	var fence_z: float = map_center.z - map_size.y * 0.5 + 0.08
	gate.build(_grid_manager.grid_to_world(gate_tile()), fence_z, _texture_style)
	var road = ROAD_SOUTH_SCRIPT.new()
	road.add_to_group("road_south")
	_terrain_root.add_child(road)
	road.build(gate.gap_center_x, fence_z, self, _texture_style)


var _corn_gate_z := INF


## Where the wicket gate into the corn is: on the west fence, somewhere near the middle,
## snapped to the maze grid (cornfield.gd TILE) so the way in lines up with it.
func corn_gate_z(map_size: Vector2, map_center: Vector3) -> float:
	if _corn_gate_z == INF:
		var tile := 1.6
		var field_z0 := map_center.z - map_size.y * 0.5 - 8.0
		var want := map_center.z + _rng.randf_range(-map_size.y * 0.15, map_size.y * 0.15)
		_corn_gate_z = field_z0 + (floor((want - field_z0) / tile) + 0.5) * tile
	return _corn_gate_z


## West of the fence: a corn field with a scarecrow, a power line behind it.
func _spawn_cornfield(map_size: Vector2, map_center: Vector3) -> void:
	var west := map_center.x - map_size.x * 0.5
	var field := Rect2(west - 3.0 - CORN_DEPTH, map_center.z - map_size.y * 0.5 - 8.0, CORN_DEPTH, map_size.y + 16.0)
	var corn := CORNFIELD_SCRIPT.new()
	corn.name = "CornField"
	_terrain_root.add_child(corn)
	corn.build(field, west - CORN_DEPTH - 10.0, Vector2(map_center.z - map_size.y * 0.5 - 90.0, map_center.z + map_size.y * 0.5 + 90.0), _rng, west + 0.08, corn_gate_z(map_size, map_center))


func _on_gate_road(p: Vector3, map_size: Vector2, map_center: Vector3) -> bool:
	var fence_z: float = map_center.z - map_size.y * 0.5
	if p.z > fence_z:
		return false
	var gx: float = _grid_manager.grid_to_world(gate_tile()).x
	var depth := fence_z - p.z
	# The road, the gatehouse and a clearing either side of the barrier; then the road on
	# to the bus stop and past it (scripts/town/road_south.gd), and the stop's clearing.
	var half := 5.5 if depth > 10.0 else 10.0
	var road: Array = ROAD_SOUTH_SCRIPT.ROAD
	var q := Vector2(p.x - gx, p.z - fence_z)
	for i in road.size() - 1:
		if Geometry2D.get_closest_point_to_segment(q, road[i], road[i + 1]).distance_to(q) < half:
			return true
	var stop: Vector2 = road[ROAD_SOUTH_SCRIPT.STOP]
	return q.distance_to(stop) < 34.0


func _add_fence_segment(parent: Node3D, node_name: String, pos: Vector3, size: Vector3) -> void:
	var fence_body = StaticBody3D.new()
	fence_body.name = node_name
	fence_body.position = pos
	parent.add_child(fence_body)
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	fence_body.add_child(collider)
	var fence_mesh = MeshInstance3D.new()
	var fence_box = BoxMesh.new()
	fence_box.size = size
	fence_mesh.mesh = fence_box
	var fence_mat = _make_psx_material(Color(0.58, 0.48, 0.32), 0.004, 24.0, 6.0, 0.0, 0.0, 0.0, 0.0, "map_fence", 0.92)
	var fence_base := fence_mat as BaseMaterial3D
	if fence_base != null:
		fence_base.uv1_scale = Vector3(max(1.0, size.x * 0.9), 1.0, max(1.0, size.z * 0.9))
	fence_mesh.material_override = fence_mat
	fence_body.add_child(fence_mesh)


func _spawn_random_trees() -> void:
	for coord in _grid_manager.get_all_coords():
		var tile = _grid_manager.get_tile(coord)
		if tile.tile_type != _grid_manager.TILE_GRASS:
			continue
		if tile.occupied:
			continue
		# Keep the way to the wicket gate into the corn clear.
		if coord.x <= 1 and _corn_gate_z != INF and absf(tile.world_position.z - _corn_gate_z) < _grid_manager.tile_size * 1.2:
			continue
		# The field comes in over the west fence: the first columns are corn, a ragged
		# edge, not a line. Corn is cleared in the Builder like trees.
		if coord.x <= _corn_band(coord.y):
			var patch := _create_corn_patch(tile.world_position, _tile_rng(coord))
			_nature_root.add_child(patch)
			_grid_manager.set_tile_occupied(coord, true, patch)
			continue
		var trng := _tile_rng(coord)
		if trng.randf() > tree_spawn_chance:
			continue

		var tree = _create_tree(tile.world_position, trng)
		_nature_root.add_child(tree)
		_grid_manager.set_tile_occupied(coord, true, tree)


## The tile's own dice: the tree that grows on it (or not) does not depend on what was
## drawn before it.
func _tile_rng(coord: Vector2i) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%d|%d" % [world_seed, coord.x, coord.y])
	return r


## Where the trees and the corn stand now (saved with the game: what was cleared stays
## cleared). [{x, y, k: "tree" | "corn"}]
func nature_snapshot() -> Array:
	var out: Array = []
	if _grid_manager == null:
		return out
	for coord in _grid_manager.get_all_coords():
		var tile = _grid_manager.get_tile(coord)
		if tile == null or not tile.occupied or tile.occupant == null or not is_instance_valid(tile.occupant):
			continue
		var occupant := tile.occupant as Node
		if occupant == null or not (occupant.is_in_group("trees") or occupant.name == "Tree"):
			continue
		out.append({"x": coord.x, "y": coord.y, "k": "corn" if occupant.is_in_group("corn") else "tree"})
	return out


## The trees and the corn exactly as nature_snapshot() had them; each tree is the one
## its tile grows (the same dice as _spawn_random_trees).
func restore_nature(list: Array) -> void:
	if _grid_manager == null:
		return
	_ensure_roots()
	_clear_nature_nodes_and_occupancy()
	for e_any in list:
		if not (e_any is Dictionary):
			continue
		var e := e_any as Dictionary
		var c := Vector2i(int(e.get("x", -1)), int(e.get("y", -1)))
		if not _grid_manager.is_in_bounds(c):
			continue
		var tile = _grid_manager.get_tile(c)
		if tile == null or tile.occupied or tile.tile_type != _grid_manager.TILE_GRASS:
			continue
		var node: Node3D
		if str(e.get("k", "tree")) == "corn":
			node = _create_corn_patch(tile.world_position, _tile_rng(c))
		else:
			var trng := _tile_rng(c)
			trng.randf()
			node = _create_tree(tile.world_position, trng)
		_nature_root.add_child(node)
		_grid_manager.set_tile_occupied(c, true, node)


## How far into the camp the corn reaches in this row (tile x, inclusive; -1 = none).
func _corn_band(row: int) -> int:
	var h := absi(hash("corn%d:%d" % [row, _corn_seed()])) % 100
	var wave := sin(float(row) * 0.55 + float(_corn_seed() % 17)) * 0.9
	return clampi(int(round(1.0 + wave + (0.6 if h > 70 else 0.0))), 0, 2)


func _corn_seed() -> int:
	if _corn_seed_value < 0:
		_corn_seed_value = absi(world_seed) % 100000
	return _corn_seed_value


var _corn_seed_value := -1
const CORN_TEX := "res://assets/textury/world/corn.png"
const FOREST_FLOOR = preload("res://scripts/ambient/forest_floor.gd")
static var _corn_mat: StandardMaterial3D
static var _corn_mesh: ArrayMesh


## One tile of corn inside the camp: stalks you walk through (they rustle and slow you),
## a "tree" for the Builder (bulldoze clears it) drawn there as corn.
func _create_corn_patch(pos: Vector3, dice: RandomNumberGenerator = null) -> Node3D:
	var r: RandomNumberGenerator = dice if dice != null else _rng
	var patch := Node3D.new()
	patch.name = "CornPatch"
	patch.add_to_group("trees")
	patch.add_to_group("corn")
	patch.position = pos
	var size: float = _grid_manager.tile_size
	if _corn_mat == null:
		_corn_mat = StandardMaterial3D.new()
		_corn_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_corn_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_corn_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if ResourceLoader.exists(CORN_TEX):
			_corn_mat.albedo_texture = load(CORN_TEX)
			_corn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			_corn_mat.alpha_scissor_threshold = 0.5
		else:
			_corn_mat.albedo_color = Color(0.62, 0.6, 0.3)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 2:
			var a := float(k) * PI * 0.5
			var d := Vector3(cos(a), 0, sin(a)) * 0.35
			var v := [Vector3(-d.x, 0, -d.z), Vector3(d.x, 0, d.z), Vector3(d.x, 2.4, d.z), Vector3(-d.x, 2.4, -d.z)]
			var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[idx])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[idx])
		_corn_mesh = st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _corn_mesh
	var xf: Array[Transform3D] = []
	var x := -size * 0.5 + 0.35
	while x < size * 0.5:
		var z := -size * 0.5 + r.randf_range(0.1, 0.4)
		while z < size * 0.5:
			if r.randf() > 0.08:
				var s := r.randf_range(0.8, 1.15)
				xf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.9, 1.15), s)), Vector3(x + r.randf_range(-0.15, 0.15), 0.0, z)))
			z += r.randf_range(0.55, 0.8)
		x += 1.0
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _corn_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.add_child(mi)
	var soil := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	soil.mesh = plane
	soil.position = Vector3(0, 0.012, 0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.26, 0.2, 0.13)
	soil.material_override = sm
	patch.add_child(soil)
	return patch


func _spawn_stylized_grass() -> void:
	if _grid_manager == null:
		return
	if grass_patch_chance <= 0.0:
		return

	var transforms: Array[Transform3D] = []
	var custom_data: Array[Color] = []

	for coord in _grid_manager.get_all_coords():
		var tile = _grid_manager.get_tile(coord)
		if tile == null:
			continue
		if tile.tile_type != _grid_manager.TILE_GRASS:
			continue
		if tile.occupied:
			continue
		if _rng.randf() > grass_patch_chance:
			continue

		var clump_count = 1 + _rng.randi_range(0, max(0, grass_clumps_per_patch))
		for _i in range(clump_count):
			var pos = tile.world_position
			pos.x += _rng.randf_range(-_grid_manager.tile_size * 0.34, _grid_manager.tile_size * 0.34)
			pos.z += _rng.randf_range(-_grid_manager.tile_size * 0.34, _grid_manager.tile_size * 0.34)
			pos.y = 0.22

			var yaw = _rng.randf_range(0.0, TAU)
			var scale_xz = _rng.randf_range(0.75, 1.20)
			var scale_y = _rng.randf_range(0.85, 1.35)
			var transform_basis = Basis()
			transform_basis = transform_basis.rotated(Vector3.UP, yaw)
			transform_basis = transform_basis.scaled(Vector3(scale_xz, scale_y, scale_xz))

			transforms.append(Transform3D(transform_basis, pos))
			custom_data.append(Color(_rng.randf(), _rng.randf(), _rng.randf(), 1.0))

	if transforms.is_empty():
		return

	var grass_clump = BoxMesh.new()
	grass_clump.size = Vector3(0.22, 0.46, 0.22)

	var mm = MultiMesh.new()
	mm.mesh = grass_clump
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = transforms.size()

	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_custom_data(i, custom_data[i])

	var mm_instance = MultiMeshInstance3D.new()
	mm_instance.name = "StylizedGrass"
	mm_instance.multimesh = mm

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.76, 0.32, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _texture_style != null:
		var grass_tex = _texture_style.pick_texture("grass", mat.albedo_color)
		if grass_tex != null:
			mat.albedo_texture = grass_tex
			mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mm_instance.material_override = mat

	_nature_root.add_child(mm_instance)


func _scatter_ground_litter() -> void:
	if _grid_manager == null or _terrain_root == null:
		return
	if _texture_style == null:
		return

	var total_tiles = _grid_manager.grid_width * _grid_manager.grid_height
	var litter_count = clampi(int(round(float(total_tiles) * 0.018)), 8, 64)
	var scatter_root = Node3D.new()
	scatter_root.name = "GroundLitter"
	_terrain_root.add_child(scatter_root)

	# 1. Spawn random details (bushes, rocks)
	var litter_tex = _load_force_texture("res://assets/textury/redneck/random/krovi.png")
	if litter_tex == null:
		litter_tex = _load_force_texture("res://assets/textury/redneck/random/krovi.png")
	if litter_tex == null and _texture_style != null:
		litter_tex = _texture_style.pick_texture("foliage", Color(0.34, 0.52, 0.28))
	for _i in range(litter_count):
		var coord = Vector2i(_rng.randi_range(0, _grid_manager.grid_width - 1), _rng.randi_range(0, _grid_manager.grid_height - 1))
		var tile = _grid_manager.get_tile(coord)
		if tile == null:
			continue
		if tile.tile_type != _grid_manager.TILE_GRASS:
			continue
		if tile.occupied:
			continue

		var piece = MeshInstance3D.new()
		var piece_box = BoxMesh.new()
		var sx = _rng.randf_range(0.30, 0.78)
		var sz = _rng.randf_range(0.24, 0.62)
		piece_box.size = Vector3(sx, 0.010, sz)
		piece.mesh = piece_box
		piece.position = tile.world_position + Vector3(
			_rng.randf_range(-_grid_manager.tile_size * 0.34, _grid_manager.tile_size * 0.34),
			0.036,
			_rng.randf_range(-_grid_manager.tile_size * 0.34, _grid_manager.tile_size * 0.34)
		)
		piece.rotation.y = _rng.randf_range(0.0, TAU)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var piece_mat = StandardMaterial3D.new()
		piece_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		piece_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		piece_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		piece_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		piece_mat.roughness = 0.94
		piece_mat.albedo_color = Color(0.84, 0.82, 0.74, 0.98)
		piece_mat.uv1_scale = Vector3(max(1.0, sx * 2.8), 1.0, max(1.0, sz * 2.8))
		if litter_tex != null:
			piece_mat.albedo_texture = litter_tex
			piece_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			piece_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			piece_mat.alpha_scissor_threshold = 0.30
		piece.material_override = piece_mat
		scatter_root.add_child(piece)


func _create_tree(pos: Vector3, dice: RandomNumberGenerator = null) -> StaticBody3D:
	var r: RandomNumberGenerator = dice if dice != null else _rng
	var tree = StaticBody3D.new()
	tree.name = "Tree"
	tree.add_to_group("trees")
	tree.position = pos + Vector3(r.randf_range(-0.6, 0.6), 0.0, r.randf_range(-0.6, 0.6))
	tree.rotation.y = r.randf_range(0.0, TAU)
	var roll := r.randf()
	var kind := TREE_KIND_SPRUCE
	if roll < 0.06:
		kind = TREE_KIND_DEAD
	elif roll < 0.24:
		kind = TREE_KIND_BIRCH
	var s := r.randf_range(0.82, 1.32)
	tree.scale = Vector3(s, s * r.randf_range(0.92, 1.12), s)

	var trunk_collider = CollisionShape3D.new()
	var trunk_shape = CylinderShape3D.new()
	trunk_shape.height = 2.2
	trunk_shape.radius = 0.24
	trunk_collider.shape = trunk_shape
	trunk_collider.position = Vector3(0.0, 1.1, 0.0)
	tree.add_child(trunk_collider)

	match kind:
		TREE_KIND_BIRCH:
			_add_tree_part(tree, _tree_mesh("birch_trunk"), _tree_material("birch_bark", 0))
			_add_tree_part(tree, _tree_mesh("birch_crown"), _tree_material("leaf", r.randi_range(1, 2)))
		TREE_KIND_DEAD:
			_add_tree_part(tree, _tree_mesh("dead"), _tree_material("bark", 1))
		_:
			_add_tree_part(tree, _tree_mesh("spruce_trunk"), _tree_material("bark", 0))
			_add_tree_part(tree, _tree_mesh("spruce_crown"), _tree_material("needles", r.randi_range(0, 2)))
	# Ferns, mushrooms, a stump... at its foot (scripts/ambient/forest_floor.gd).
	FOREST_FLOOR.dress(tree)
	return tree


func _add_tree_part(tree: Node3D, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tree.add_child(mi)


## Low-poly tree meshes in the Build/PSX manner: few sides, hard facets, built once.
func _tree_mesh(id: String) -> Mesh:
	if _tree_meshes.has(id):
		return _tree_meshes[id]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match id:
		"spruce_trunk":
			_st_cone(st, Vector3.ZERO, 0.22, 0.12, 2.4, 6, 1.0)
		"spruce_crown":
			# Stacked drooping tiers, each slightly rotated so the silhouette is jagged.
			for i in SPRUCE_TIERS.size():
				var t: Array = SPRUCE_TIERS[i]
				_st_cone(st, Vector3(0.0, float(t[2]), 0.0), float(t[0]), 0.04, float(t[1]), 7, 1.6, float(i) * 0.45)
		"birch_trunk":
			_st_cone(st, Vector3.ZERO, 0.16, 0.08, 4.2, 6, 1.0)
		"birch_crown":
			_st_blob(st, Vector3(0.0, 3.6, 0.0), Vector3(1.2, 1.3, 1.2))
			_st_blob(st, Vector3(0.45, 4.4, 0.2), Vector3(0.85, 0.95, 0.85))
			_st_blob(st, Vector3(-0.4, 3.2, -0.3), Vector3(0.8, 0.8, 0.8))
		"dead":
			_st_cone(st, Vector3.ZERO, 0.2, 0.05, 4.6, 5, 1.0)
			_st_branch(st, Vector3(0.0, 2.2, 0.0), Vector3(0.9, 0.9, 0.1), 0.07)
			_st_branch(st, Vector3(0.0, 2.9, 0.0), Vector3(-0.7, 0.8, 0.4), 0.06)
			_st_branch(st, Vector3(0.0, 3.5, 0.0), Vector3(0.2, 0.7, -0.6), 0.05)
	st.generate_normals()
	var mesh := st.commit()
	_tree_meshes[id] = mesh
	return mesh


## Open-bottomed cone/frustum with UVs that wrap the texture `uv_wrap` times around.
func _st_cone(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, sides: int, uv_wrap: float, twist: float = 0.0) -> void:
	for i in sides:
		var a0 := twist + TAU * float(i) / float(sides)
		var a1 := twist + TAU * float(i + 1) / float(sides)
		var b0 := base + Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var b1 := base + Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
		var t0 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var t1 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		var u0 := uv_wrap * float(i) / float(sides)
		var u1 := uv_wrap * float(i + 1) / float(sides)
		st.set_uv(Vector2(u0, 1.0)); st.add_vertex(b0)
		st.set_uv(Vector2(u1, 1.0)); st.add_vertex(b1)
		st.set_uv(Vector2(u1, 0.0)); st.add_vertex(t1)
		st.set_uv(Vector2(u0, 1.0)); st.add_vertex(b0)
		st.set_uv(Vector2(u1, 0.0)); st.add_vertex(t1)
		st.set_uv(Vector2(u0, 0.0)); st.add_vertex(t0)
		# Underside, so a tier reads as a solid skirt from below.
		st.set_uv(Vector2(u0, 1.0)); st.add_vertex(b0)
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(base + Vector3(0.0, h * 0.25, 0.0))
		st.set_uv(Vector2(u1, 1.0)); st.add_vertex(b1)


## Faceted blob (octahedron-ish, 6 around x 3 rings) for birch crowns.
func _st_blob(st: SurfaceTool, c: Vector3, r: Vector3) -> void:
	var rings := [[-1.0, 0.0], [-0.45, 0.85], [0.35, 0.95], [1.0, 0.0]]
	var sides := 6
	for ri in rings.size() - 1:
		var y0: float = rings[ri][0]
		var w0: float = rings[ri][1]
		var y1: float = rings[ri + 1][0]
		var w1: float = rings[ri + 1][1]
		for i in sides:
			var a0 := TAU * float(i) / float(sides) + float(ri) * 0.5
			var a1 := TAU * float(i + 1) / float(sides) + float(ri) * 0.5
			var p00 := c + Vector3(cos(a0) * w0 * r.x, y0 * r.y, sin(a0) * w0 * r.z)
			var p01 := c + Vector3(cos(a1) * w0 * r.x, y0 * r.y, sin(a1) * w0 * r.z)
			var p10 := c + Vector3(cos(a0) * w1 * r.x, y1 * r.y, sin(a0) * w1 * r.z)
			var p11 := c + Vector3(cos(a1) * w1 * r.x, y1 * r.y, sin(a1) * w1 * r.z)
			var u0 := float(i) / float(sides)
			var u1 := float(i + 1) / float(sides)
			st.set_uv(Vector2(u0, 1.0 - float(ri) / 3.0)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, 1.0 - float(ri) / 3.0)); st.add_vertex(p01)
			st.set_uv(Vector2(u1, 1.0 - float(ri + 1) / 3.0)); st.add_vertex(p11)
			st.set_uv(Vector2(u0, 1.0 - float(ri) / 3.0)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, 1.0 - float(ri + 1) / 3.0)); st.add_vertex(p11)
			st.set_uv(Vector2(u0, 1.0 - float(ri + 1) / 3.0)); st.add_vertex(p10)


func _st_branch(st: SurfaceTool, from: Vector3, dir: Vector3, r: float) -> void:
	# A thin four-sided stick from `from` along `dir`.
	var axis := dir.normalized()
	var side := axis.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var up := side.cross(axis).normalized()
	var to := from + dir
	var ring := [side * r, up * r, -side * r, -up * r]
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		st.set_uv(Vector2(0, 1)); st.add_vertex(from + a)
		st.set_uv(Vector2(1, 1)); st.add_vertex(from + b)
		st.set_uv(Vector2(1, 0)); st.add_vertex(to + b * 0.3)
		st.set_uv(Vector2(0, 1)); st.add_vertex(from + a)
		st.set_uv(Vector2(1, 0)); st.add_vertex(to + b * 0.3)
		st.set_uv(Vector2(0, 0)); st.add_vertex(to + a * 0.3)


## Shared materials. `variant` shifts the tint so a stand of trees is not one colour.
func _tree_material(kind: String, variant: int) -> Material:
	var key := "%s_%d" % [kind, variant]
	if _tree_materials.has(key):
		return _tree_materials[key]
	var mat: StandardMaterial3D
	match kind:
		"needles":
			mat = _make_psx_material(Color(0.26, 0.5, 0.26), 0.0, 22.0, 6.0, 0.0, 0.0, 0.0, 0.0, "tree_canopy", 0.62) as StandardMaterial3D
			mat.albedo_color = [Color(0.62, 0.78, 0.6), Color(0.5, 0.66, 0.5), Color(0.72, 0.8, 0.58)][variant % 3]
			mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"leaf":
			mat = _make_psx_material(Color(0.4, 0.6, 0.3), 0.0, 22.0, 6.0, 0.0, 0.0, 0.0, 0.0, "tree_canopy", 0.62) as StandardMaterial3D
			mat.albedo_color = [Color(0.9, 1.0, 0.7), Color(0.98, 1.0, 0.62), Color(1.0, 0.92, 0.58)][variant % 3]
		"birch_bark":
			mat = _make_psx_material(Color(0.85, 0.83, 0.78), 0.0, 24.0, 6.0, 0.0, 0.0, 0.0, 0.0, "tree_bark", 0.58) as StandardMaterial3D
			mat.albedo_color = Color(1.6, 1.58, 1.5)
		_:
			mat = _make_psx_material(Color(0.58, 0.42, 0.30), 0.0, 24.0, 6.0, 0.0, 0.0, 0.0, 0.0, "tree_bark", 0.58) as StandardMaterial3D
			mat.albedo_color = Color(0.9, 0.85, 0.8) if variant == 0 else Color(0.62, 0.6, 0.58)
	var wind := _wind_material(mat, kind)
	_tree_materials[key] = wind
	return wind


## The PSX look of `std` (texture, tint, tiling) on the wind shader. Crowns sway and
## flutter, trunks lean a little, dead trunks lean more and rattle in a storm.
func _wind_material(std: StandardMaterial3D, kind: String) -> Material:
	var m := ShaderMaterial.new()
	m.shader = TREE_WIND_SHADER
	m.set_shader_parameter("albedo_tex", std.albedo_texture)
	m.set_shader_parameter("albedo_color", std.albedo_color)
	m.set_shader_parameter("uv_scale", Vector2(std.uv1_scale.x, std.uv1_scale.y))
	match kind:
		"needles":
			m.set_shader_parameter("sway", 1.0)
			m.set_shader_parameter("flutter", 0.6)
			m.set_shader_parameter("height", 6.0)
		"leaf":
			m.set_shader_parameter("sway", 1.0)
			m.set_shader_parameter("flutter", 1.4)
			m.set_shader_parameter("height", 5.0)
			m.set_shader_parameter("seasonal", 1.0)
		"birch_bark":
			m.set_shader_parameter("sway", 1.0)
			m.set_shader_parameter("height", 5.0)
		_:
			# Bark of spruces (variant 0) and the dead trees (variant 1).
			m.set_shader_parameter("sway", 0.9)
			m.set_shader_parameter("flutter", 0.25)
			m.set_shader_parameter("height", 5.5)
	return m


## Everything past the fence, so the camp sits in a forest valley instead of on a
## plate in the void: an apron of ground, a dense spruce belt hugging the fence, and
## low hills on the horizon that the weather fog swallows. Visual only, no collision.
func _spawn_horizon(map_size: Vector2, map_center: Vector3, grass_tex: Texture2D) -> void:
	var root := Node3D.new()
	root.name = "Horizon"
	_terrain_root.add_child(root)
	var half := maxf(map_size.x, map_size.y) * 0.5

	var apron := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(half * 12.0, half * 12.0)
	apron.mesh = plane
	apron.position = map_center + Vector3(0.0, -0.06, 0.0)
	var apron_mat := StandardMaterial3D.new()
	apron_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	apron_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	apron_mat.albedo_color = Color(0.62, 0.66, 0.56)
	apron_mat.uv1_scale = Vector3(half * 3.0, half * 3.0, 1.0)
	if grass_tex != null:
		apron_mat.albedo_texture = grass_tex
	apron.material_override = apron_mat
	apron.add_to_group("season_ground")
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(apron)

	# Spruce belt: one MultiMesh per part, dense at the fence, thinning outward.
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = _tree_mesh("spruce_trunk")
	var crown_mm := MultiMesh.new()
	crown_mm.transform_format = MultiMesh.TRANSFORM_3D
	crown_mm.mesh = _tree_mesh("spruce_crown")
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < HORIZON_TREE_COUNT and tries < HORIZON_TREE_COUNT * 4:
		tries += 1
		var dist := half + 3.0 + pow(_rng.randf(), 1.8) * half * 2.2
		var ang := _rng.randf() * TAU
		var p := map_center + Vector3(cos(ang), 0.0, sin(ang)) * dist
		# Square map: keep trees outside the fenced rectangle.
		if absf(p.x - map_center.x) < map_size.x * 0.5 + 2.0 and absf(p.z - map_center.z) < map_size.y * 0.5 + 2.0:
			continue
		# Not in the lake.
		if not _lake_poly.is_empty() and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _lake_poly):
			continue
		# And off the gate road (it runs south from the gate with a slight bend east).
		if _on_gate_road(p, map_size, map_center):
			continue
		# And out of the corn field and the power line west of the fence.
		var west := map_center.x - map_size.x * 0.5
		if p.x < west - 2.0 and p.x > west - CORN_DEPTH - 14.0 and absf(p.z - map_center.z) < map_size.y * 0.5 + 40.0:
			continue
		var sc := _rng.randf_range(0.9, 1.7) * (1.0 + (dist - half) / (half * 4.0))
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.9, 1.25), sc))
		xforms.append(Transform3D(b, Vector3(p.x, 0.0, p.z)))
	trunk_mm.instance_count = xforms.size()
	crown_mm.instance_count = xforms.size()
	for i in xforms.size():
		trunk_mm.set_instance_transform(i, xforms[i])
		crown_mm.set_instance_transform(i, xforms[i])
	var trunks := MultiMeshInstance3D.new()
	trunks.multimesh = trunk_mm
	trunks.material_override = _tree_material("bark", 1)
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trunks)
	var crowns := MultiMeshInstance3D.new()
	crowns.multimesh = crown_mm
	crowns.material_override = _tree_material("needles", 1)
	crowns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(crowns)

	# Hills: flattened faceted blobs far out, dark like distant forest.
	var hill_mat := StandardMaterial3D.new()
	hill_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	hill_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	hill_mat.albedo_color = Color(0.32, 0.4, 0.3)
	var canopy_tex: Texture2D = _texture_style.pick_texture("tree_canopy", Color(0.26, 0.5, 0.26)) if _texture_style != null else null
	if canopy_tex != null:
		hill_mat.albedo_texture = canopy_tex
		hill_mat.uv1_scale = Vector3(6.0, 2.0, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st_blob(st, Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
	st.generate_normals()
	var hill_mesh := st.commit()
	for i in HORIZON_HILL_COUNT:
		var ang := TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / float(HORIZON_HILL_COUNT)
		# Not across the road south to the bus stop: those hills step aside.
		var off_road := angle_difference(ang, -PI * 0.5)
		if absf(off_road) < 0.6:
			ang = -PI * 0.5 + signf(off_road if off_road != 0.0 else 1.0) * 0.6
		var dist := half * _rng.randf_range(3.2, 4.6)
		var hill := MeshInstance3D.new()
		hill.mesh = hill_mesh
		hill.material_override = hill_mat
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var w := half * _rng.randf_range(0.9, 1.6)
		hill.scale = Vector3(w, half * _rng.randf_range(0.18, 0.34), w * _rng.randf_range(0.6, 1.0))
		hill.rotation.y = _rng.randf() * TAU
		hill.position = map_center + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		root.add_child(hill)


func _clear_generated_nodes() -> void:
	_ensure_roots()
	for child in _terrain_root.get_children():
		child.queue_free()
	_clear_nature_nodes_and_occupancy()


func _clear_nature_nodes_and_occupancy() -> void:
	if _nature_root == null:
		return
	if _grid_manager != null:
		for coord in _grid_manager.get_all_coords():
			var tile = _grid_manager.get_tile(coord)
			if tile == null or not tile.occupied:
				continue
			var occupant := tile.occupant as Node
			if occupant == null:
				continue
			if occupant.is_in_group("trees") or occupant.name == "Tree":
				_grid_manager.set_tile_occupied(coord, false, null)
	for child in _nature_root.get_children():
		child.queue_free()


func _get_or_create_child(node_name: String) -> Node3D:
	var existing = get_node_or_null(node_name) as Node3D
	if existing != null:
		return existing
	var created = Node3D.new()
	created.name = node_name
	add_child(created)
	return created


func _ensure_roots() -> void:
	if _terrain_root == null:
		_terrain_root = _get_or_create_child("Terrain")
	if _nature_root == null:
		_nature_root = _get_or_create_child("Nature")


func _make_psx_material(base_color: Color, _wobble_strength: float, _snap_amount: float, _color_steps: float, _wind_alignment: float, _wobble_phase: float, _wobble_speed: float, _wobble_scale: float, texture_category: String = "", _texture_influence: float = 0.58) -> Material:
	var mat := StandardMaterial3D.new()
	var category = texture_category if texture_category != "" else "generic"
	mat.albedo_color = base_color
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _texture_style != null:
		var albedo_tex = _texture_style.pick_texture(category, base_color)
		if albedo_tex != null:
			mat.albedo_texture = albedo_tex
			mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	return mat


## Vytvoří záchranný ground pokud generace světa selže. Přesunuto z main.gd.
func create_emergency_ground(world_3d: Node3D) -> void:
	if world_3d.get_node_or_null("EmergencyGround") != null:
		return
	var ground = StaticBody3D.new()
	ground.name = "EmergencyGround"
	world_3d.add_child(ground)
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(80.0, 1.0, 80.0)
	collider.shape = shape
	collider.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(collider)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	mesh.mesh = box
	mesh.position = Vector3(0.0, -0.5, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.23, 0.08, 0.08)
	mesh.material_override = mat
	ground.add_child(mesh)
	var marker = MeshInstance3D.new()
	var marker_mesh = BoxMesh.new()
	marker_mesh.size = Vector3(4.0, 16.0, 4.0)
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, 8.0, 0.0)
	var marker_mat = StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.2, 0.2)
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(0.8, 0.1, 0.1)
	marker.material_override = marker_mat
	ground.add_child(marker)


## Najde vhodnou spawn coord pro hráče. Přesunuto z main.gd.
## Vyžaduje, aby byl _grid_manager nastaven přes setup().
func find_player_spawn_coord() -> Vector2i:
	if _grid_manager == null:
		return Vector2i(1, 1)
	var preferred_spawn := _find_spawn_near_main_building()
	var spawn_coord = preferred_spawn if preferred_spawn != Vector2i(-1, -1) else Vector2i(10, 4)
	var width_value = _grid_manager.get("grid_width")
	var height_value = _grid_manager.get("grid_height")
	if width_value != null:
		spawn_coord.x = int(floor(float(width_value) / 2.0))
		if preferred_spawn != Vector2i(-1, -1):
			spawn_coord = preferred_spawn
	if _grid_manager.is_in_bounds(spawn_coord):
		var start_tile = _grid_manager.get_tile(spawn_coord)
		if start_tile != null and not start_tile.occupied and start_tile.tile_type == _grid_manager.TILE_GRASS:
			return spawn_coord
	var max_radius = 8
	for radius in range(1, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var coord = spawn_coord + Vector2i(dx, dy)
				if not _grid_manager.is_in_bounds(coord):
					continue
				var tile = _grid_manager.get_tile(coord)
				if tile == null or tile.occupied:
					continue
				if tile.tile_type != _grid_manager.TILE_GRASS:
					continue
				return coord
	if width_value != null and height_value != null:
		return Vector2i(clamp(int(floor(float(width_value) / 2.0)), 0, int(width_value) - 1), clamp(3, 0, int(height_value) - 1))
	return Vector2i(1, 1)


func _find_spawn_near_main_building() -> Vector2i:
	if _building_manager == null or _grid_manager == null:
		return Vector2i(-1, -1)
	var structures_root: Node = _building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return Vector2i(-1, -1)

	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		if str(structure.get_meta("building_type", "")) != "main_building":
			continue
		var origin_any = structure.get_meta("grid_origin", Vector2i(-1, -1))
		var footprint_any = structure.get_meta("grid_footprint", Vector2i(2, 2))
		var origin := origin_any as Vector2i if origin_any is Vector2i else Vector2i(-1, -1)
		var footprint := footprint_any as Vector2i if footprint_any is Vector2i else Vector2i(2, 2)
		if not _grid_manager.is_in_bounds(origin):
			continue
		var center := origin + Vector2i(max(0, int(floor(float(footprint.x) * 0.5))), max(0, int(floor(float(footprint.y) * 0.5))))
		for radius in range(1, 9):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if abs(dx) != radius and abs(dy) != radius:
						continue
					var coord := center + Vector2i(dx, dy)
					if not _grid_manager.is_in_bounds(coord):
						continue
					var tile = _grid_manager.get_tile(coord)
					if tile == null or tile.occupied:
						continue
					if tile.tile_type != _grid_manager.TILE_GRASS:
						continue
					return coord
	return Vector2i(-1, -1)


func _load_force_texture(res_path: String) -> Texture2D:
	var tex = load(res_path) as Texture2D
	if tex != null:
		return tex
	var abs_path = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var image = Image.new()
	var err = image.load(abs_path)
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
