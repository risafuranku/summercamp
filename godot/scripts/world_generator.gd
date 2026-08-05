extends Node3D

@export_range(0.0, 1.0, 0.01) var tree_spawn_chance: float = 0.30
@export var wind_direction_degrees: float = 32.0
@export var tree_wobble_intensity: float = 0.028
@export var tree_wobble_speed: float = 0.34
@export var tree_wobble_variation_degrees: float = 18.0
@export_range(0.0, 1.0, 0.01) var grass_patch_chance: float = 0.0
@export_range(0, 8, 1) var grass_clumps_per_patch: int = 0
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const POWER_BUILDING_EDGE_PADDING: int = 2
const POWER_BUILDING_WATER_PADDING: int = 2
const POWER_BUILDING_ROTATION_STEPS: int = 2
const SEWER_WATER_PADDING: int = 2

var _grid_manager
var _building_manager
var _rng = RandomNumberGenerator.new()

var _terrain_root: Node3D
var _nature_root: Node3D
var _texture_style


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
	_ensure_roots()
	if _grid_manager == null or _building_manager == null:
		push_error("WorldGenerator is missing GridManager or BuildingManager reference.")
		return

	_rng.randomize()
	_clear_generated_nodes()
	_building_manager.clear_structures()

	_grid_manager.reset_tiles(_grid_manager.TILE_GRASS)
	_mark_north_lake_row()
	var entrance_origin = _mark_south_entrance_reserved_area()

	_generate_terrain()
	if spawn_default_buildings:
		_building_manager.place_main_building(entrance_origin, Vector2i(2, 2))
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


func _mark_south_entrance_reserved_area() -> Vector2i:
	var center_start_x = int(floor((_grid_manager.grid_width - 2) * 0.5))
	for y in range(3):
		for x in range(center_start_x, center_start_x + 2):
			_grid_manager.set_tile_type(Vector2i(x, y), _grid_manager.TILE_RESERVED)

	return Vector2i(center_start_x, 0)


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
	_spawn_perimeter_fence(map_size, map_center)

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
	_add_fence_segment(fence_root, "FenceNorth", map_center + Vector3(0.0, fence_height * 0.5, (map_size.y * 0.5) - inset), north_south_size)
	_add_fence_segment(fence_root, "FenceSouth", map_center + Vector3(0.0, fence_height * 0.5, -(map_size.y * 0.5) + inset), north_south_size)
	_add_fence_segment(fence_root, "FenceEast", map_center + Vector3((map_size.x * 0.5) - inset, fence_height * 0.5, 0.0), east_west_size)
	_add_fence_segment(fence_root, "FenceWest", map_center + Vector3(-(map_size.x * 0.5) + inset, fence_height * 0.5, 0.0), east_west_size)


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
		if _rng.randf() > tree_spawn_chance:
			continue

		var tree = _create_tree(tile.world_position)
		_nature_root.add_child(tree)
		_grid_manager.set_tile_occupied(coord, true, tree)


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


func _create_tree(pos: Vector3) -> StaticBody3D:
	var tree = StaticBody3D.new()
	tree.name = "Tree"
	tree.add_to_group("trees")
	tree.position = pos
	tree.rotation.y = _rng.randf_range(0.0, TAU)

	var scale_jitter = _rng.randf_range(0.92, 1.18)
	tree.scale = Vector3.ONE * scale_jitter

	var trunk_collider = CollisionShape3D.new()
	var trunk_shape = CylinderShape3D.new()
	trunk_shape.height = 2.2
	trunk_shape.radius = 0.28
	trunk_collider.shape = trunk_shape
	trunk_collider.position = Vector3(0.0, 1.1, 0.0)
	tree.add_child(trunk_collider)

	var trunk_mesh = MeshInstance3D.new()
	var trunk = CylinderMesh.new()
	trunk.height = 2.2
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.30
	trunk_mesh.mesh = trunk
	trunk_mesh.position = Vector3(0.0, 1.1, 0.0)
	trunk_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	trunk_mesh.visibility_range_end = 0.0
	trunk_mesh.visibility_range_begin_margin = 0.0
	trunk_mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var random_phase = _rng.randf_range(0.0, TAU)
	var trunk_mat = _make_psx_material(Color(0.58, 0.42, 0.30), tree_wobble_intensity * 0.45, 24.0, 6.0, 0.90, random_phase, tree_wobble_speed * 0.65, 0.36, "tree_bark", 0.58)
	trunk_mesh.material_override = trunk_mat
	tree.add_child(trunk_mesh)

	var canopy_mesh = MeshInstance3D.new()
	var canopy = CylinderMesh.new()
	canopy.height = 3.2
	canopy.top_radius = 0.08
	canopy.bottom_radius = 1.25
	canopy_mesh.mesh = canopy
	canopy_mesh.position = Vector3(0.0, 3.1, 0.0)
	canopy_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	canopy_mesh.visibility_range_end = 0.0
	canopy_mesh.visibility_range_begin_margin = 0.0
	canopy_mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var leaves_mat = _make_psx_material(Color(0.26, 0.62, 0.28), tree_wobble_intensity * 0.58, 22.0, 6.0, 0.84, random_phase + _rng.randf_range(-0.25, 0.25), tree_wobble_speed * 0.70, 0.40, "tree_canopy", 0.62)
	canopy_mesh.material_override = leaves_mat
	tree.add_child(canopy_mesh)

	return tree


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
