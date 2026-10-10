extends Node3D

@export var placement_range: float = 24.0
@export var tent_height: float = 1.8
@export var cabin_height: float = 2.8
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const BUILDING_MODELS = preload("res://scripts/building_models.gd")
const PSX_TEXTURE_DEFAULT_UV := Vector2(1.35, 1.35)
const PATH_TEXTURES := {
	"straight": "res://assets/textury/redneck/paths/gravel.png",
	"turn": "res://assets/textury/redneck/paths/gravelturn.png",
	"t_junction": "res://assets/textury/redneck/paths/gravelt.png",
	"cross": "res://assets/textury/redneck/paths/gravelcross.png",
	"dead_end": "res://assets/textury/redneck/paths/gravelend.png",
	"solo": "res://assets/textury/redneck/paths/graveldriveway.png",
}
const PATH_DIR_N := 1
const PATH_DIR_E := 2
const PATH_DIR_S := 4
const PATH_DIR_W := 8
const PATH_MASK_STRAIGHT := PATH_DIR_E | PATH_DIR_W
const PATH_MASK_TURN := PATH_DIR_W | PATH_DIR_S
const PATH_MASK_T_JUNCTION := PATH_DIR_W | PATH_DIR_E | PATH_DIR_S
const PATH_MASK_DEAD_END := PATH_DIR_E
const PATH_MASK_CROSS := PATH_DIR_N | PATH_DIR_E | PATH_DIR_S | PATH_DIR_W
const PATH_MESH_TILE_COVERAGE := 1.0
const PATH_MESH_Y_OFFSET := 0.06
const PATH_ALPHA_SCISSOR_THRESHOLD := 0.33
const LAMP_LIGHT_OCCLUSION_MULTIPLIER := 0.28
const LAMP_LIGHT_NORMALIZATION := 1.45

var _grid_manager
var _structures_root: Node3D
var _texture_style
var _models = null
var _path_texture_cache: Dictionary = {}
var _lamps_active: bool = false
var _lamp_runtime: Dictionary = {}
var _lamp_rng := RandomNumberGenerator.new()
var _lamp_flicker_roll_timer: float = 60.0
var _lamp_beam_texture: Texture2D = null
var _lamp_player_cache: Node3D = null


func _ready() -> void:
	_ensure_structures_root()
	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	_lamp_rng.randomize()
	var placed_cb := Callable(self, "_on_building_placed_event")
	if EventBus.has_signal("building_placed") and not EventBus.building_placed.is_connected(placed_cb):
		EventBus.building_placed.connect(placed_cb)
	var removed_cb := Callable(self, "_on_building_removed_event")
	if EventBus.has_signal("building_removed") and not EventBus.building_removed.is_connected(removed_cb):
		EventBus.building_removed.connect(removed_cb)


func _process(delta: float) -> void:
	if _lamp_runtime.is_empty():
		return

	_prune_stale_lamp_runtime()
	if _lamp_runtime.is_empty():
		return

	if _lamps_active:
		_lamp_flicker_roll_timer -= maxf(delta, 0.0)
		if _lamp_flicker_roll_timer <= 0.0:
			_roll_lamp_flickers()
			_lamp_flicker_roll_timer = _lamp_rng.randf_range(56.0, 68.0)

	var lamp_ids = _lamp_runtime.keys()
	for lamp_id_var in lamp_ids:
		var lamp_id = int(lamp_id_var)
		var entry_any = _lamp_runtime.get(lamp_id, null)
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		_update_lamp_beam_orientation(entry)
		_update_lamp_flicker(entry, maxf(delta, 0.0))
		_lamp_runtime[lamp_id] = entry


func _on_building_placed_event(building_id: String, origin: Vector2i, _footprint: Vector2i, rotation_steps: int) -> void:
	# This method is called AFTER state is updated.
	# We just need to spawn the visual representation.
	# We can reuse existing place_ methods but we might need to bypass some checks if they are redundant or rely on old state logic that might conflict?
	# Actually, existing place_ methods call `_grid_manager.occupy_footprint` which updates `GridManager`.
	# We should keep this for now to keep GridManager in sync with GridModel until GridManager is fully replaced.
	
	place_building_at_visual_only(origin, building_id, rotation_steps)

func _on_building_removed_event(origin: Vector2i) -> void:
	# Find the structure at this origin and remove it.
	# GridManager has get_tile(origin).occupant
	if _grid_manager:
		var tile = _grid_manager.get_tile(origin)
		if tile and tile.occupied and tile.occupant:
			var structure = tile.occupant
			
			# Remove from visual grid
			# If structure is multi-tile, we need to clear all tiles.
			# Using building metadata or grid manager helper if available.
			if building_manager_has_remove_logic():
				remove_structure(structure)
			else:
				# Fallback manual removal
				_grid_manager.set_tile_occupied(origin, false, null) # This is just one tile... not good for multi-tile.
				structure.queue_free()

func building_manager_has_remove_logic() -> bool:
	return has_method("remove_structure")



func setup(grid_manager) -> void:
	_grid_manager = grid_manager
	_ensure_structures_root()


## Lamps whose bulb has gone (a breakdown, a night job): dark until repaired, whatever
## the grid does. Keys are grid origins "x:y".
var _broken_lamps: Dictionary = {}


func set_broken_lamps(keys: Array) -> void:
	var next := {}
	for k in keys:
		next[str(k)] = true
	if next == _broken_lamps:
		return
	_broken_lamps = next
	for lamp_id in _lamp_runtime.keys():
		var entry: Dictionary = _lamp_runtime[lamp_id]
		_apply_lamp_entry_base_state(entry, _lamps_active)
		_lamp_runtime[lamp_id] = entry


func _is_lamp_entry_broken(entry: Dictionary) -> bool:
	var root = entry.get("root", null) as Node3D
	if root == null or not is_instance_valid(root) or _broken_lamps.is_empty():
		return false
	var origin = root.get_meta("grid_origin", null)
	if not (origin is Vector2i):
		return false
	return _broken_lamps.has("%d:%d" % [(origin as Vector2i).x, (origin as Vector2i).y])


func set_lamps_active(active: bool) -> void:
	_lamps_active = active
	_lamp_flicker_roll_timer = _lamp_rng.randf_range(54.0, 68.0)
	var lamp_ids = _lamp_runtime.keys()
	for lamp_id_var in lamp_ids:
		var lamp_id = int(lamp_id_var)
		var entry_any = _lamp_runtime.get(lamp_id, null)
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		entry["flicker_remaining"] = 0.0
		entry["flicker_phase"] = _lamp_rng.randf_range(0.0, TAU)
		_apply_lamp_entry_base_state(entry, _lamps_active)
		_lamp_runtime[lamp_id] = entry


func clear_structures() -> void:
	_ensure_structures_root()
	_lamp_runtime.clear()
	var existing_children := _structures_root.get_children()
	for child_any in existing_children:
		var child := child_any as Node
		if child == null:
			continue
		# Detach immediately so same-frame rebuild passes don't see stale structures.
		_structures_root.remove_child(child)
		child.queue_free()


func place_main_building(origin: Vector2i, footprint: Vector2i = Vector2i(2, 2)) -> bool:
	_ensure_structures_root()
	if _grid_manager == null:
		return false
	if not _grid_manager.can_place_footprint(origin, footprint, true):
		return false

	var building = StaticBody3D.new()
	building.name = "MainBuilding"
	_tag_structure(building, origin, footprint, "main_building", true)
	_structures_root.add_child(building)

	var size = Vector3(_grid_manager.tile_size * footprint.x * 0.9, 3.4, _grid_manager.tile_size * footprint.y * 0.9)
	var center = _grid_manager.get_footprint_center(origin, footprint)
	building.position = center + Vector3(0.0, size.y * 0.5 - 0.08, 0.0)

	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	building.add_child(collider)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat = _make_psx_material(Color(0.58, 0.60, 0.62), 0.012, 26.0, 6.0, 0.08, "brick", 0.88)
	mesh.material_override = mat
	building.add_child(mesh)

	# Simple gable roof so the silhouette reads better from distance.
	var roof = MeshInstance3D.new()
	roof.name = "MainRoof"
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var overhang = 0.22
	var half_w = (size.x * 0.5) + overhang
	var half_d = (size.z * 0.5) + overhang
	var roof_y = size.y * 0.5
	var roof_h = 0.95
	var rbl = Vector3(-half_w, roof_y, -half_d)
	var rbr = Vector3(half_w, roof_y, -half_d)
	var rfl = Vector3(-half_w, roof_y, half_d)
	var rfr = Vector3(half_w, roof_y, half_d)
	var rtb = Vector3(0.0, roof_y + roof_h, -half_d)
	var rtf = Vector3(0.0, roof_y + roof_h, half_d)
	# Left slope
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(rbl)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(rfl)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(rtf)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(rbl)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(rtf)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(rtb)
	# Right slope
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(rfr)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(rbr)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(rtb)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(rfr)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(rtb)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(rtf)
	# Front/Back gables
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(rfl)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(rfr)
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(rtf)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(rbr)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(rbl)
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(rtb)
	st.generate_normals()
	roof.mesh = st.commit()
	roof.material_override = _make_psx_material(Color(0.36, 0.34, 0.34), 0.010, 24.0, 6.0, 0.10, "cabin_lv1_exterior_roof", 0.74)
	building.add_child(roof)
	var roof_fan = MeshInstance3D.new()
	roof_fan.name = "MainRoofFan"
	var roof_fan_box = BoxMesh.new()
	roof_fan_box.size = Vector3(0.86, 0.05, 0.86)
	roof_fan.mesh = roof_fan_box
	roof_fan.position = Vector3(0.0, roof_y + roof_h + (roof_fan_box.size.y * 0.5) - 0.01, 0.0)
	var roof_fan_mat = _make_psx_material(Color(0.80, 0.78, 0.70), 0.006, 24.0, 6.0, 0.04, "office_roof_fan2", 0.96)
	roof_fan.material_override = roof_fan_mat
	building.add_child(roof_fan)

	_spawn_crt_placeholder(building, size)
	_spawn_door(building, size)
	_spawn_building_windows(building, size, "main_building")
	_spawn_office_sign(building, size)
	_set_structure_condition_internal(building, _default_condition_for_type("main_building"))
	_grid_manager.occupy_footprint(origin, footprint, building, _grid_manager.TILE_BUILDING, true)
	return true


func get_footprint_for_building(building_type: String) -> Vector2i:
	match building_type:
		"tent_1", "tent_2", "tent_3", "toilet_block", "shower_block", "bonfire", "power_generator", "sewer", "water_pump", "sewage_tank", "dumpsters", "path", "lamp_post":
			return Vector2i(1, 1)
		"cabin", "cabin_1", "cabin_2", "cabin_3", "restaurant", "pub", "vecerka":
			return Vector2i(2, 2)
		"caravan_1", "sports_field", "lake_slide":
			return Vector2i(2, 1)
		_:
			return Vector2i(1, 1)


func place_building_at_visual_only(origin: Vector2i, building_id: String, rotation_steps: int) -> void:
	# Calls the legacy placement logic which instantiates the node and updates grid_manager
	# We ignore the return value because Actions should have guaranteed validity.
	var placed_ok := place_building_at(origin, building_id)
	if placed_ok:
		_apply_structure_rotation_at(origin, building_id, rotation_steps)
		
	if building_manager_has_remove_logic() and false: # Just to use the helper to avoid warning if not unused
		pass 

func place_building_at(origin: Vector2i, building_type: String) -> bool:
	if building_type.begins_with("tent_"):
		var level = 1
		var parts = building_type.split("_")
		if parts.size() >= 2:
			level = int(parts[1])
		return place_tent_at(origin, level)

	match building_type:
		"vecerka":
			return place_vecerka_at(origin)
		"cabin", "cabin_1":
			return place_cabin_at(origin, 1)
		"cabin_2":
			return place_cabin_at(origin, 2)
		"cabin_3":
			return place_cabin_at(origin, 3)
		"path":
			return place_path_at(origin)
		"lamp_post":
			return place_lamp_post_at(origin)
		"caravan_1":
			return _place_caravan_at(origin)
		"toilet_block":
			return _place_placeholder_at(origin, "toilet_block", Vector2i(1, 1), Color(0.58, 0.56, 0.50), Color(0.46, 0.36, 0.30), "services", 2.28)
		"shower_block":
			return _place_placeholder_at(origin, "shower_block", Vector2i(1, 1), Color(0.56, 0.64, 0.70), Color(0.44, 0.36, 0.30), "services", 3.08)
		"pub":
			return _place_placeholder_at(origin, "pub", Vector2i(2, 2), Color(0.48, 0.30, 0.24), Color(0.70, 0.44, 0.30), "services", 2.10)
		"restaurant":
			return _place_placeholder_at(origin, "restaurant", Vector2i(2, 2), Color(0.56, 0.38, 0.24), Color(0.78, 0.56, 0.34), "services", 2.90)
		"bonfire":
			return _place_placeholder_at(origin, "bonfire", Vector2i(1, 1), Color(0.42, 0.28, 0.20), Color(0.96, 0.56, 0.24), "attractions", 0.7)
		"sports_field":
			return _place_placeholder_at(origin, "sports_field", Vector2i(2, 1), Color(0.30, 0.54, 0.30), Color(0.84, 0.88, 0.86), "attractions", 0.5)
		"lake_slide":
			return _place_placeholder_at(origin, "lake_slide", Vector2i(2, 1), Color(0.26, 0.44, 0.72), Color(0.92, 0.60, 0.22), "attractions", 1.25)
		"power_generator":
			return _place_placeholder_at(origin, "power_generator", Vector2i(1, 1), Color(0.46, 0.44, 0.42), Color(0.90, 0.84, 0.34), "utilities", 1.25)
		"sewer", "water_pump", "sewage_tank":
			return _place_placeholder_at(origin, "sewer", Vector2i(1, 1), Color(0.34, 0.44, 0.36), Color(0.56, 0.66, 0.46), "utilities", 0.54)
		"dumpsters":
			return _place_placeholder_at(origin, "dumpsters", Vector2i(1, 1), Color(0.22, 0.38, 0.28), Color(0.18, 0.30, 0.22), "utilities", 0.9)
		_:
			return false


func _apply_structure_rotation_at(origin: Vector2i, building_type: String, rotation_steps: int) -> void:
	if _grid_manager == null:
		return
	var tile = _grid_manager.get_tile(origin)
	if tile == null or not tile.occupied or tile.occupant == null:
		return
	var structure = _resolve_structure_root(tile.occupant)
	if structure == null:
		return
	if not _building_supports_rotation(building_type):
		structure.set_meta("build_rotation", 0)
		return
	var normalized_rotation = wrapi(int(rotation_steps), 0, 4)
	structure.set_meta("build_rotation", normalized_rotation)
	structure.rotation.y = deg_to_rad(float(normalized_rotation) * 90.0)


func _building_supports_rotation(building_type: String) -> bool:
	if building_type == "" or building_type == "path" or building_type == "demolish":
		return false
	var fp = get_footprint_for_building(building_type)
	return fp.x == fp.y


func place_tent_in_front(player: Node3D) -> bool:
	var origin = find_nearest_free_tile_in_front(player, Vector2i(1, 1), placement_range)
	if origin.x < 0:
		return false
	return place_tent_at(origin)


func place_cabin_in_front(player: Node3D) -> bool:
	var footprint = Vector2i(2, 2)
	var origin = find_nearest_free_tile_in_front(player, footprint, placement_range)
	if origin.x < 0:
		return false
	return place_cabin_at(origin)


func place_tent_at(origin: Vector2i, level: int = 1) -> bool:
	_ensure_structures_root()
	if _grid_manager == null:
		return false
	if not _grid_manager.can_place_footprint(origin, Vector2i(1, 1)):
		return false

	var tent_root = StaticBody3D.new()
	tent_root.name = "Tent_Lv%d" % level
	tent_root.add_to_group("tents")
	_tag_structure(tent_root, origin, Vector2i(1, 1), "tent_%d" % level, false)
	_structures_root.add_child(tent_root)

	var tile_size = _grid_manager.tile_size
	var center = _grid_manager.grid_to_world(origin)
	tent_root.position = center + Vector3(0.0, -0.05, 0.0)

	# Tent colors and counts per level.
	var tent_color: Color
	var count: int
	var scale_mult: float
	match level:
		1:
			tent_color = Color(1.00, 0.86, 0.16)  # Yellow — small
			count = 1
			scale_mult = 0.75
		2:
			tent_color = Color(0.96, 0.14, 0.10)  # Red — 2x baseline
			count = 2
			scale_mult = 0.62
		3:
			tent_color = Color(0.16, 0.42, 1.00)  # Blue — 1 big tent
			count = 1
			scale_mult = 1.0
		_:
			tent_color = Color(0.90, 0.80, 0.40)
			count = 1
			scale_mult = 0.75

	# Spawn tent(s) within the tile.
	var offsets: Array = []
	if count == 1:
		offsets = [Vector3(0.0, 0.0, 0.0)]
	elif count == 2:
		offsets = [Vector3(-tile_size * 0.18, 0.0, 0.0), Vector3(tile_size * 0.18, 0.0, 0.0)]

	for i in range(count):
		var tent_w = tile_size * 0.6 * scale_mult
		var tent_h = tent_height * scale_mult
		var tent_d = tile_size * 0.7 * scale_mult
		var tent_mesh = _create_tent_prism(tent_w, tent_h, tent_d, tent_color)
		tent_mesh.position = offsets[i]
		tent_mesh.rotation.y = randf_range(-0.15, 0.15)
		tent_root.add_child(tent_mesh)
		# The camp's canvas, pegs, guy ropes, the door flap (stan1/2/3 in the Builder).
		if _models == null:
			_models = BUILDING_MODELS.new(Callable(self, "_make_psx_material"))
		tent_mesh.material_override = _models.tent_cloth(tent_color)
		_models.tent_details(tent_root, tent_w, tent_h, tent_d, offsets[i], tent_mesh.rotation.y, tent_color)

	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(tile_size * 0.7, tent_height, tile_size * 0.7)
	collider.shape = shape
	collider.position = Vector3(0.0, tent_height * 0.5, 0.0)
	tent_root.add_child(collider)

	_set_structure_condition_internal(tent_root, _default_condition_for_type("tent", level))
	_grid_manager.occupy_footprint(origin, Vector2i(1, 1), tent_root)
	return true


func _create_tent_prism(w: float, h: float, d: float, color: Color) -> MeshInstance3D:
	# Triangle prism tent shape using SurfaceTool.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Vertices of the tent prism.
	var bl = Vector3(-w * 0.5, 0.0, -d * 0.5)
	var br = Vector3(w * 0.5, 0.0, -d * 0.5)
	var fl = Vector3(-w * 0.5, 0.0, d * 0.5)
	var fr = Vector3(w * 0.5, 0.0, d * 0.5)
	var tb = Vector3(0.0, h, -d * 0.5)
	var tf = Vector3(0.0, h, d * 0.5)

	# Left face.
	st.set_normal(Vector3(-h, w * 0.5, 0.0).normalized())
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(bl)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(fl)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(tf)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(bl)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(tf)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(tb)

	# Right face.
	st.set_normal(Vector3(h, w * 0.5, 0.0).normalized())
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(fr)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(br)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(tb)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(fr)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(tb)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(tf)

	# Front face (triangle).
	st.set_normal(Vector3(0.0, 0.0, 1.0))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(fl)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(fr)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(tf)

	# Back face (triangle).
	st.set_normal(Vector3(0.0, 0.0, -1.0))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(br)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(bl)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(tb)

	# Bottom face.
	st.set_normal(Vector3(0.0, -1.0, 0.0))
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(bl)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(br)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(fr)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(bl)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(fr)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(fl)

	var mesh_inst = MeshInstance3D.new()
	st.generate_normals()
	mesh_inst.mesh = st.commit()
	# Use StandardMaterial3D — PSX vertex snap distorts small prisms.
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _texture_style != null:
		var tex = _texture_style.pick_texture("fabric", color)
		if tex != null:
			mat.albedo_texture = tex
			# Keep per-level tent tint visible even when textured.
			mat.albedo_color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.20)
	mesh_inst.material_override = mat
	return mesh_inst


func place_cabin_at(origin: Vector2i, level: int = 1) -> bool:
	_ensure_structures_root()
	if _grid_manager == null:
		return false
	var footprint = Vector2i(2, 2)
	if not _grid_manager.can_place_footprint(origin, footprint):
		return false

	var cabin_level = clampi(level, 1, 3)
	var cabin = StaticBody3D.new()
	cabin.name = "CabinLv%d" % cabin_level
	cabin.add_to_group("cabins")
	_tag_structure(cabin, origin, footprint, "cabin_%d" % cabin_level, false)
	_structures_root.add_child(cabin)

	var ts = _grid_manager.tile_size
	var center = _grid_manager.get_footprint_center(origin, footprint)
	cabin.position = center + Vector3(0.0, -0.06, 0.0)

	var wall_w = ts * (1.56 + float(cabin_level - 1) * 0.06)
	var wall_d = ts * (1.56 + float(cabin_level - 1) * 0.06)
	var wall_h = cabin_height * (0.86 + float(cabin_level - 1) * 0.04)
	if _models == null:
		_models = BUILDING_MODELS.new(Callable(self, "_make_psx_material"))
	# Modelled after the Builder's chata1/2/3 (scripts/building_models.gd).
	var cabin_box: Vector3 = _models.cabin(cabin, cabin_level, wall_w, wall_d, wall_h, cabin_height * 0.45)

	# Collider.
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(wall_w, cabin_box.y, wall_d)
	collider.shape = shape
	collider.position = Vector3(0.0, cabin_box.y * 0.5, 0.0)
	cabin.add_child(collider)

	_set_structure_condition_internal(cabin, _default_condition_for_type("cabin"))
	_grid_manager.occupy_footprint(origin, footprint, cabin)
	return true


func place_path_at(origin: Vector2i) -> bool:
	_ensure_structures_root()
	if _grid_manager == null:
		return false
	if not _grid_manager.can_place_footprint(origin, Vector2i(1, 1)):
		return false

	var path_node = StaticBody3D.new()
	path_node.name = "Path"
	path_node.add_to_group("paths")
	_tag_structure(path_node, origin, Vector2i(1, 1), "path", false)
	_structures_root.add_child(path_node)

	var ts = _grid_manager.tile_size
	var center = _grid_manager.grid_to_world(origin)
	path_node.position = center

	var mesh = MeshInstance3D.new()
	mesh.name = "PathMesh"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane = PlaneMesh.new()
	plane.size = Vector2(ts * PATH_MESH_TILE_COVERAGE, ts * PATH_MESH_TILE_COVERAGE)
	mesh.mesh = plane
	mesh.position = Vector3(0.0, PATH_MESH_Y_OFFSET, 0.0)
	mesh.material_override = _make_path_surface_material(_load_path_texture(str(PATH_TEXTURES.get("straight", ""))))
	path_node.add_child(mesh)

	# No collider needed for flat path — walkable.
	_set_structure_condition_internal(path_node, _default_condition_for_type("path"))
	_grid_manager.occupy_footprint(origin, Vector2i(1, 1), path_node)
	_refresh_path_neighbors(origin)
	return true


func place_lamp_post_at(origin: Vector2i) -> bool:
	_ensure_structures_root()
	if _grid_manager == null:
		return false
	# On a path tile the lamp goes to the edge of the path; the path stays.
	var path_root: Node3D = null
	if not _grid_manager.can_place_footprint(origin, Vector2i(1, 1)):
		path_root = _get_path_root_at(origin)
		if path_root == null or path_root.has_meta("lamp_node"):
			return false

	var lamp = StaticBody3D.new()
	lamp.name = "LampPost"
	lamp.add_to_group("utilities")
	lamp.add_to_group("lamp_posts")
	_tag_structure(lamp, origin, Vector2i(1, 1), "lamp_post", false)
	_structures_root.add_child(lamp)

	var ts = _grid_manager.tile_size
	lamp.position = _grid_manager.grid_to_world(origin) + Vector3(0.0, -0.05, 0.0)
	if path_root != null:
		# The side of the tile where the path does not continue; the head leans over it.
		var side := Vector2i(0, 1)
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			if not _is_path_at(origin + d):
				side = d
				break
		lamp.position += Vector3(side.x, 0.0, side.y) * ts * 0.40
		lamp.rotation.y = atan2(-float(side.x), -float(side.y))
		lamp.set_meta("on_path", true)
		path_root.set_meta("lamp_node", lamp)

	var base_size = Vector3(ts * 0.24, 0.24, ts * 0.24)
	var base_mesh = MeshInstance3D.new()
	var base_box = BoxMesh.new()
	base_box.size = base_size
	base_mesh.mesh = base_box
	base_mesh.position = Vector3(0.0, base_size.y * 0.5, 0.0)
	base_mesh.material_override = _make_psx_material(Color(0.34, 0.34, 0.30), 0.006, 24.0, 6.0, 0.08, "utility_power_back_609", 0.76)
	lamp.add_child(base_mesh)

	var pole_height = maxf(2.9, ts * 0.86)
	var pole_radius = maxf(0.08, ts * 0.042)
	var pole_mesh = MeshInstance3D.new()
	var pole_geo = CylinderMesh.new()
	pole_geo.top_radius = pole_radius
	pole_geo.bottom_radius = pole_radius * 1.08
	pole_geo.height = pole_height
	pole_mesh.mesh = pole_geo
	pole_mesh.position = Vector3(0.0, base_size.y + pole_height * 0.5, 0.0)
	pole_mesh.material_override = _make_psx_material(Color(0.40, 0.40, 0.36), 0.006, 24.0, 6.0, 0.12, "decor_metal", 0.70)
	lamp.add_child(pole_mesh)

	var arm_mesh = MeshInstance3D.new()
	var arm_box = BoxMesh.new()
	arm_box.size = Vector3(maxf(0.34, ts * 0.32), 0.10, 0.10)
	arm_mesh.mesh = arm_box
	var lamp_head_anchor = Vector3(0.0, base_size.y + pole_height - 0.14, ts * 0.12)
	arm_mesh.position = lamp_head_anchor
	arm_mesh.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	arm_mesh.material_override = _make_psx_material(Color(0.46, 0.44, 0.38), 0.006, 24.0, 6.0, 0.10, "decor_metal", 0.70)
	lamp.add_child(arm_mesh)

	var hood_mesh = MeshInstance3D.new()
	var hood_box = BoxMesh.new()
	hood_box.size = Vector3(0.26, 0.16, 0.22)
	hood_mesh.mesh = hood_box
	var hood_pos = lamp_head_anchor + Vector3(0.0, -0.03, arm_box.size.x * 0.48)
	hood_mesh.position = hood_pos
	hood_mesh.material_override = _make_psx_material(Color(0.50, 0.46, 0.34), 0.006, 24.0, 6.0, 0.08, "utility_power_side_610", 0.70)
	lamp.add_child(hood_mesh)

	var bulb_mesh = MeshInstance3D.new()
	var bulb_box = BoxMesh.new()
	bulb_box.size = Vector3(0.14, 0.24, 0.14)
	bulb_mesh.mesh = bulb_box
	var bulb_pos = hood_pos + Vector3(0.0, -0.18, -0.01)
	bulb_mesh.position = bulb_pos
	var bulb_light_color = Color(1.0, 0.90, 0.56)
	var bulb_material = _make_psx_material(Color(1.0, 0.94, 0.78, 0.52), 0.004, 20.0, 6.0, 0.0, "building_window", 0.20)
	var bulb_std = bulb_material as StandardMaterial3D
	if bulb_std != null:
		bulb_std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bulb_std.emission_enabled = true
		bulb_std.emission = bulb_light_color
		bulb_std.emission_energy_multiplier = 0.22
		bulb_std.albedo_color = Color(1.0, 0.94, 0.78, 0.40)
	bulb_mesh.material_override = bulb_material
	lamp.add_child(bulb_mesh)
	var beam_height = maxf(2.9, ts * 0.86)
	var beam_width = maxf(1.3, ts * 0.40)
	var cone_ground_y = maxf(base_size.y + 0.12, bulb_pos.y - beam_height * 0.88)
	var cone_ground_local = Vector3(bulb_pos.x, cone_ground_y, bulb_pos.z)

	var lamp_spot = SpotLight3D.new()
	lamp_spot.name = "LampSpot"
	lamp_spot.position = bulb_pos + Vector3(0.0, -0.05, 0.0)
	lamp_spot.light_color = Color(1.0, 0.92, 0.66)
	lamp_spot.light_energy = 2.85
	lamp_spot.spot_range = maxf(9.4, ts * 2.22)
	lamp_spot.spot_angle = 40.0
	lamp_spot.spot_attenuation = 0.82
	lamp_spot.shadow_enabled = false
	lamp.add_child(lamp_spot)
	var cone_ground_global = lamp.to_global(cone_ground_local)
	lamp_spot.look_at(cone_ground_global, Vector3.FORWARD)

	var lamp_fill = OmniLight3D.new()
	lamp_fill.name = "LampFill"
	lamp_fill.position = Vector3(bulb_pos.x, cone_ground_y + 0.16, bulb_pos.z)
	lamp_fill.light_color = Color(1.0, 0.90, 0.62)
	lamp_fill.light_energy = 0.72
	lamp_fill.omni_range = maxf(4.2, ts * 1.08)
	lamp_fill.omni_attenuation = 2.1
	lamp_fill.shadow_enabled = false
	lamp.add_child(lamp_fill)

	var beam_mesh = MeshInstance3D.new()
	beam_mesh.name = "LampBeam"
	beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam_geo = QuadMesh.new()
	beam_geo.size = Vector2(beam_width, beam_height)
	beam_mesh.mesh = beam_geo
	beam_mesh.position = bulb_pos + Vector3(0.0, -beam_height * 0.52, 0.0)
	var beam_mat = StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	beam_mat.albedo_texture = _get_lamp_beam_texture()
	beam_mat.albedo_color = Color(bulb_light_color.r, bulb_light_color.g, bulb_light_color.b, 0.14)
	beam_mat.emission_enabled = true
	beam_mat.emission = bulb_light_color
	beam_mat.emission_energy_multiplier = 0.22
	beam_mat.set_meta("beam_base_alpha", beam_mat.albedo_color.a)
	beam_mat.set_meta("beam_base_emission", beam_mat.emission_energy_multiplier)
	beam_mesh.material_override = beam_mat
	lamp.add_child(beam_mesh)

	var dust = GPUParticles3D.new()
	dust.name = "LampDust"
	dust.amount = 9
	dust.lifetime = 3.4
	dust.one_shot = false
	dust.explosiveness = 0.0
	dust.randomness = 0.24
	dust.preprocess = 2.6
	dust.local_coords = true
	dust.visibility_aabb = AABB(Vector3(-0.24, -0.42, -0.24), Vector3(0.48, 0.68, 0.48))
	dust.position = hood_pos + Vector3(0.0, -0.16, 0.0)
	var dust_process = ParticleProcessMaterial.new()
	dust_process.direction = Vector3(0.0, -1.0, 0.0)
	dust_process.spread = 8.0
	dust_process.initial_velocity_min = 0.004
	dust_process.initial_velocity_max = 0.018
	dust_process.gravity = Vector3(0.0, 0.02, 0.0)
	dust_process.linear_accel_min = -0.01
	dust_process.linear_accel_max = 0.01
	dust_process.damping_min = 0.10
	dust_process.damping_max = 0.20
	dust_process.scale_min = 0.006
	dust_process.scale_max = 0.014
	dust_process.color = Color(0.98, 0.88, 0.64, 0.11)
	dust_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dust_process.emission_sphere_radius = 0.05
	dust.process_material = dust_process
	var dust_quad = QuadMesh.new()
	dust_quad.size = Vector2(0.011, 0.011)
	dust.draw_pass_1 = dust_quad
	var dust_material = StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.98, 0.88, 0.64, 0.08)
	dust_material.emission_enabled = true
	dust_material.emission = Color(1.0, 0.86, 0.56)
	dust_material.emission_energy_multiplier = 0.10
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	dust_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	dust_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dust.material_override = dust_material
	lamp.add_child(dust)

	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(maxf(0.44, ts * 0.18), pole_height + 0.40, maxf(0.62, ts * 0.26))
	collider.shape = shape
	collider.position = Vector3(0.0, shape.size.y * 0.5, 0.0)
	lamp.add_child(collider)

	_set_structure_condition_internal(lamp, _default_condition_for_type("utility"))
	if path_root == null:
		_grid_manager.occupy_footprint(origin, Vector2i(1, 1), lamp)
	else:
		# Walk-through: no collider in the middle of the path's neighbours' way.
		collider.position.x = 0.0
	_register_lamp_runtime(lamp, lamp_spot, lamp_fill, beam_mesh, dust)
	return true


func _get_lamp_beam_texture() -> Texture2D:
	if _lamp_beam_texture != null:
		return _lamp_beam_texture

	var width := 96
	var height := 224
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(height):
		var t = float(y) / float(height - 1)
		var half_width = lerpf(0.03, 0.50, pow(t, 0.88))
		var vertical_falloff = clampf(pow(1.0 - t, 0.42), 0.0, 1.0)
		for x in range(width):
			var u = float(x) / float(width - 1)
			var dist = absf(u - 0.5)
			if dist > half_width:
				continue
			var edge_soft = 1.0 - clampf(dist / maxf(half_width, 0.0001), 0.0, 1.0)
			edge_soft = edge_soft * edge_soft
			var alpha = edge_soft * vertical_falloff * 0.78
			if alpha <= 0.001:
				continue
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	_lamp_beam_texture = ImageTexture.create_from_image(img)
	return _lamp_beam_texture


func place_vecerka_at(origin: Vector2i) -> bool:
	_ensure_structures_root()
	if _grid_manager == null:
		return false
	var footprint = Vector2i(2, 2)
	if not _grid_manager.can_place_footprint(origin, footprint):
		return false

	var vecerka = StaticBody3D.new()
	vecerka.name = "Vecerka"
	vecerka.add_to_group("services")
	vecerka.set_meta("service_type", "vecerka")
	vecerka.set_meta("interior_click_type", "building_door") # Allow clicking to enter
	_tag_structure(vecerka, origin, footprint, "vecerka", true)
	_structures_root.add_child(vecerka)

	var center = _grid_manager.get_footprint_center(origin, footprint)
	vecerka.position = center

	var ts = _grid_manager.tile_size
	var w = ts * 2.0 * 0.95
	var d = ts * 2.0 * 0.95
	var h = 3.6

	# Main Body
	var body_mesh = MeshInstance3D.new()
	var body_box = BoxMesh.new()
	body_box.size = Vector3(w, h, d)
	body_mesh.mesh = body_box
	body_mesh.position = Vector3(0.0, h * 0.5, 0.0)
	var body_mat = _make_psx_material(Color(0.58, 0.60, 0.62), 0.010, 24.0, 6.0, 0.10, "service_vecerka_wall", 0.78)
	if body_mat is StandardMaterial3D:
		(body_mat as StandardMaterial3D).uv1_scale = Vector3(1.2, 1.2, 1.0)
	body_mesh.material_override = body_mat
	vecerka.add_child(body_mesh)

	# Roof
	var roof_mesh = MeshInstance3D.new()
	var roof_box = BoxMesh.new()
	roof_box.size = Vector3(w + 0.4, 0.2, d + 0.4)
	roof_mesh.mesh = roof_box
	roof_mesh.position = Vector3(0.0, h + 0.1, 0.0)
	roof_mesh.material_override = _make_psx_material(Color(0.30, 0.28, 0.26), 0.012, 16.0, 2.0, 0.10, "roof")
	vecerka.add_child(roof_mesh)

	# Front Sign Board
	var sign_mesh = MeshInstance3D.new()
	var sign_box = BoxMesh.new()
	sign_box.size = Vector3(w * 0.8, 0.8, 0.1)
	sign_mesh.mesh = sign_box
	sign_mesh.position = Vector3(0.0, h - 0.7, d * 0.5 + 0.06)
	sign_mesh.material_override = _make_psx_material(Color(0.72, 0.20, 0.16), 0.005, 32.0, 4.0, 0.05, "metal")
	vecerka.add_child(sign_mesh)

	var sign_lbl = Label3D.new()
	sign_lbl.text = "VECERKA"
	sign_lbl.font_size = 64
	sign_lbl.outline_size = 16
	sign_lbl.position = Vector3(0.0, 0.0, 0.06)
	sign_lbl.modulate = Color(1.0, 1.0, 0.9)
	sign_mesh.add_child(sign_lbl)

	# Door
	var door_mesh = MeshInstance3D.new()
	var door_box = BoxMesh.new()
	door_box.size = Vector3(1.4, 2.4, 0.1)
	door_mesh.mesh = door_box
	door_mesh.position = Vector3(-w * 0.15, 1.2, d * 0.5 + 0.06)
	door_mesh.material_override = _make_psx_material(Color(0.24, 0.22, 0.20), 0.008, 24.0, 6.0, 0.08, "building_door")
	vecerka.add_child(door_mesh)

	# Cola Machine (Outside Prop)
	var cola_mesh = MeshInstance3D.new()
	var cola_box = BoxMesh.new()
	cola_box.size = Vector3(1.0, 2.0, 0.9)
	cola_mesh.mesh = cola_box
	cola_mesh.position = Vector3(w * 0.30, 1.0, d * 0.5 + 0.6)
	cola_mesh.rotation_degrees = Vector3(0.0, -15.0, 0.0)
	cola_mesh.material_override = _make_psx_material(Color(0.80, 0.20, 0.20), 0.006, 24.0, 6.0, 0.10, "service_vecerka_cola")
	vecerka.add_child(cola_mesh)

	# Collider
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(w, h, d)
	collider.shape = shape
	collider.position = Vector3(0.0, h * 0.5, 0.0)
	vecerka.add_child(collider)

	_set_structure_condition_internal(vecerka, _default_condition_for_type("vecerka"))
	_grid_manager.occupy_footprint(origin, footprint, vecerka)
	return true


func _place_caravan_at(origin: Vector2i) -> bool:
	_ensure_structures_root()
	if _grid_manager == null:
		return false
	var footprint = Vector2i(2, 1)
	if not _grid_manager.can_place_footprint(origin, footprint):
		return false

	var caravan = StaticBody3D.new()
	caravan.name = "CaravanLv1"
	caravan.add_to_group("housing")
	_tag_structure(caravan, origin, footprint, "caravan_1", false)
	_structures_root.add_child(caravan)
	caravan.position = _grid_manager.get_footprint_center(origin, footprint) + Vector3(0.0, -0.05, 0.0)

	var ts = _grid_manager.tile_size
	if _models == null:
		_models = BUILDING_MODELS.new(Callable(self, "_make_psx_material"))
	# Modelled after the Builder's caravan (scripts/building_models.gd).
	var body_size: Vector3 = _models.caravan(caravan, ts * 2.0, ts)
	caravan.set_meta("interaction_target_local", Vector3(-body_size.x * 0.2, 1.1, body_size.z * 0.5))

	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(body_size.x, body_size.y, body_size.z)
	collider.shape = shape
	collider.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	caravan.add_child(collider)

	_set_structure_condition_internal(caravan, _default_condition_for_type("caravan"))
	_grid_manager.occupy_footprint(origin, footprint, caravan)
	return true


func _place_placeholder_at(origin: Vector2i, building_type: String, footprint: Vector2i, base_color: Color, accent_color: Color, group_name: String, structure_height: float) -> bool:
	_ensure_structures_root()
	if _grid_manager == null:
		return false
	if not _grid_manager.can_place_footprint(origin, footprint):
		return false

	var structure = StaticBody3D.new()
	structure.name = "Placeholder_%s" % building_type
	structure.add_to_group(group_name)
	_tag_structure(structure, origin, footprint, building_type, false)
	_structures_root.add_child(structure)
	structure.position = _grid_manager.get_footprint_center(origin, footprint) + Vector3(0.0, -0.05, 0.0)

	# Modelled after the Builder's pixel art (scripts/building_models.gd).
	if BUILDING_MODELS.has_model(building_type):
		if _models == null:
			_models = BUILDING_MODELS.new(Callable(self, "_make_psx_material"))
		var info: Dictionary = _models.build(building_type, structure, _grid_manager.tile_size, footprint)
		var msize: Vector3 = info["size"]
		structure.set_meta("interaction_target_local", info.get("target", Vector3(0.0, 1.0, msize.z * 0.5)))
		var mcol := CollisionShape3D.new()
		var mshape := BoxShape3D.new()
		mshape.size = Vector3(msize.x, maxf(0.3, msize.y), msize.z)
		mcol.shape = mshape
		mcol.position = Vector3(0.0, mshape.size.y * 0.5, 0.0)
		structure.add_child(mcol)
		var mcondition := "attraction"
		if group_name == "utilities":
			mcondition = "utility"
		elif group_name == "services":
			mcondition = "service"
		_set_structure_condition_internal(structure, _default_condition_for_type(mcondition))
		_grid_manager.occupy_footprint(origin, footprint, structure)
		return true

	var ts = _grid_manager.tile_size
	var body_size = Vector3(ts * footprint.x * 0.86, structure_height, ts * footprint.y * 0.86)
	if building_type == "toilet_block":
		body_size = Vector3(ts * footprint.x * 0.66, structure_height, ts * footprint.y * 0.92)
	elif building_type == "shower_block":
		body_size = Vector3(ts * footprint.x * 0.92, structure_height, ts * footprint.y * 0.66)
	elif building_type == "power_generator":
		var cube_edge = maxf(body_size.x, body_size.z)
		body_size = Vector3(cube_edge, cube_edge, cube_edge)
	structure.set_meta(
		"interaction_target_local",
		Vector3(0.0, min(1.18, body_size.y * 0.62), body_size.z * 0.52)
	)
	var body_mesh = MeshInstance3D.new()
	var body_box = BoxMesh.new()
	body_box.size = body_size
	body_mesh.mesh = body_box
	body_mesh.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	var body_category := "metal"
	if group_name == "utilities":
		body_category = "utility_exterior_wall"
	elif group_name == "services":
		match building_type:
			"restaurant":
				body_category = "service_block_exterior_wall"
			"pub":
				body_category = "cabin_lv1_exterior_wood"
			"toilet_block", "shower_block":
				body_category = "service_block_exterior_wall"
			_:
				body_category = "brick"
	elif group_name == "attractions":
		body_category = "stone"
	body_mesh.material_override = _make_psx_material(base_color, 0.010, 24.0, 6.0, 0.10, body_category)
	structure.add_child(body_mesh)
	if building_type == "toilet_block" or building_type == "shower_block":
		_add_service_block_side_patterns(structure, building_type, body_size)
	elif building_type == "power_generator":
		_add_power_generator_side_back_panels(structure, body_size)

	var roof_size = Vector3(body_size.x * 0.98, max(0.05, body_size.y * 0.12), body_size.z * 0.98)
	if building_type == "sewer":
		roof_size = Vector3(body_size.x * 0.92, max(0.04, body_size.y * 0.10), body_size.z * 0.92)
	var roof_mesh = MeshInstance3D.new()
	var roof_box = BoxMesh.new()
	roof_box.size = roof_size
	roof_mesh.mesh = roof_box
	var roof_vertical_factor := 0.35
	if building_type == "sewer":
		roof_vertical_factor = 0.18
	elif building_type == "pub":
		roof_vertical_factor = 0.02
	elif building_type == "toilet_block" or building_type == "shower_block":
		roof_vertical_factor = 0.22
	roof_mesh.position = Vector3(0.0, body_size.y + roof_size.y * roof_vertical_factor, 0.0)
	var roof_category = "roof" if group_name != "utilities" else "metal"
	if building_type == "toilet_block" or building_type == "shower_block":
		roof_category = "service_block_exterior_roof"
	elif building_type == "pub":
		roof_category = "cabin_lv1_exterior_wood"
	if building_type == "toilet_block" or building_type == "shower_block":
		# Roof slopes down away from the entrance (door is on +Z/front side).
		roof_mesh.rotation = Vector3(deg_to_rad(-11.0), 0.0, 0.0)
	var roof_mat = _make_psx_material(accent_color, 0.008, 24.0, 6.0, 0.06, roof_category)
	var roof_std = roof_mat as StandardMaterial3D
	if roof_std != null:
		roof_std.uv1_scale = Vector3(2.0, 1.0, 1.0) # Larger tiles for roof plates
	roof_mesh.material_override = roof_mat
	roof_mesh.material_override = roof_mat
	structure.add_child(roof_mesh)

	if building_type == "toilet_block" or building_type == "shower_block":
		_add_service_roof_wedges(structure, body_size, roof_size, roof_mesh.position.y, roof_mesh.rotation.x, "service_block_exterior_wall")
	if building_type == "sewer":
		var roof_patch = MeshInstance3D.new()
		var roof_patch_box = BoxMesh.new()
		roof_patch_box.size = Vector3(body_size.x * 0.34, max(0.03, roof_size.y * 0.62), body_size.z * 0.34)
		roof_patch.mesh = roof_patch_box
		roof_patch.position = Vector3(
			0.0,
			roof_mesh.position.y + (roof_size.y * 0.5) + (roof_patch_box.size.y * 0.5) - 0.006,
			0.0
		)
		roof_patch.material_override = _make_psx_material(
			Color(0.62, 0.64, 0.58),
			0.006,
			24.0,
			6.0,
			0.04,
			"service_sewer_roof_patch"
		)
		structure.add_child(roof_patch)

	if building_type != "bonfire" and building_type != "sports_field" and building_type != "lake_slide":
		var door_mesh = MeshInstance3D.new()
		var door_box = BoxMesh.new()
		door_box.size = Vector3(min(0.78, body_size.x * 0.42), min(1.86, body_size.y * 0.82), 0.05)
		door_mesh.mesh = door_box
		door_mesh.position = Vector3(0.0, door_box.size.y * 0.5, body_size.z * 0.5 + 0.03)
		door_mesh.material_override = _make_psx_material(Color(0.46, 0.30, 0.22), 0.006, 28.0, 6.0, 0.06, "building_door")
		structure.add_child(door_mesh)

	if building_type == "bonfire":
		var flame = MeshInstance3D.new()
		var flame_box = BoxMesh.new()
		flame_box.size = Vector3(0.26, 0.32, 0.26)
		flame.mesh = flame_box
		flame.position = Vector3(0.0, body_size.y + 0.22, 0.0)
		flame.material_override = _make_psx_material(Color(0.98, 0.44, 0.16), 0.014, 20.0, 6.0, 0.0, "decor")
		structure.add_child(flame)
	elif building_type == "sports_field":
		var stripe_a = MeshInstance3D.new()
		var stripe_b = MeshInstance3D.new()
		var stripe_box = BoxMesh.new()
		stripe_box.size = Vector3(body_size.x * 0.92, 0.03, 0.08)
		stripe_a.mesh = stripe_box
		stripe_b.mesh = stripe_box
		stripe_a.position = Vector3(0.0, body_size.y + 0.04, -body_size.z * 0.22)
		stripe_b.position = Vector3(0.0, body_size.y + 0.04, body_size.z * 0.22)
		var stripe_mat = _make_psx_material(Color(0.92, 0.94, 0.88), 0.006, 24.0, 6.0, 0.0, "decor_paper")
		stripe_a.material_override = stripe_mat
		stripe_b.material_override = stripe_mat
		structure.add_child(stripe_a)
		structure.add_child(stripe_b)
	elif building_type == "lake_slide":
		var slide = MeshInstance3D.new()
		var slide_box = BoxMesh.new()
		slide_box.size = Vector3(body_size.x * 0.25, body_size.y * 0.9, body_size.z * 0.75)
		slide.mesh = slide_box
		slide.position = Vector3(body_size.x * 0.18, body_size.y + slide_box.size.y * 0.25, 0.0)
		slide.material_override = _make_psx_material(Color(0.92, 0.62, 0.26), 0.009, 24.0, 6.0, 0.04, "decor_metal")
		structure.add_child(slide)

	if building_type != "bonfire" and building_type != "sewer" and building_type != "toilet_block" and building_type != "shower_block":
		_spawn_building_windows(structure, body_size, building_type)

	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(body_size.x, max(0.5, body_size.y + roof_size.y), body_size.z)
	collider.shape = shape
	collider.position = Vector3(0.0, shape.size.y * 0.5, 0.0)
	structure.add_child(collider)

	var condition_type = "placeholder"
	if group_name == "utilities":
		condition_type = "utility"
	elif group_name == "services":
		condition_type = "service"
	elif group_name == "attractions":
		condition_type = "attraction"
	_set_structure_condition_internal(structure, _default_condition_for_type(condition_type))
	_grid_manager.occupy_footprint(origin, footprint, structure)
	return true


func _add_service_block_side_patterns(structure: Node3D, building_type: String, body_size: Vector3) -> void:
	if structure == null:
		return
	var panel_thickness: float = 0.03
	var panel_height: float = maxf(0.8, body_size.y * 0.92)
	var panel_y: float = panel_height * 0.5
	var front_back_width: float = maxf(0.34, body_size.x * 0.92)
	var left_right_depth: float = maxf(0.34, body_size.z * 0.92)
	var front_category := "service_block_ext_427"
	var right_category := "service_block_ext_428"
	var back_category := "service_block_ext_429"
	var left_category := "service_block_ext_430"
	if building_type == "shower_block":
		front_category = "service_block_ext_430"
		right_category = "service_block_ext_427"
		back_category = "service_block_ext_428"
		left_category = "service_block_ext_429"
	_add_service_pattern_panel(
		structure,
		"PatternFront",
		Vector3(front_back_width, panel_height, panel_thickness),
		Vector3(0.0, panel_y, body_size.z * 0.5 + panel_thickness * 0.25),
		front_category
	)
	_add_service_pattern_panel(
		structure,
		"PatternBack",
		Vector3(front_back_width, panel_height, panel_thickness),
		Vector3(0.0, panel_y, -body_size.z * 0.5 - panel_thickness * 0.25),
		back_category
	)
	_add_service_pattern_panel(
		structure,
		"PatternRight",
		Vector3(panel_thickness, panel_height, left_right_depth),
		Vector3(body_size.x * 0.5 + panel_thickness * 0.25, panel_y, 0.0),
		right_category
	)
	_add_service_pattern_panel(
		structure,
		"PatternLeft",
		Vector3(panel_thickness, panel_height, left_right_depth),
		Vector3(-body_size.x * 0.5 - panel_thickness * 0.25, panel_y, 0.0),
		left_category
	)


func _add_power_generator_side_back_panels(structure: Node3D, body_size: Vector3) -> void:
	if structure == null:
		return
	var panel_thickness: float = 0.03
	var panel_height: float = maxf(0.8, body_size.y * 0.92)
	var panel_y: float = panel_height * 0.5
	var back_width: float = maxf(0.34, body_size.x * 0.92)
	var side_depth: float = maxf(0.34, body_size.z * 0.92)
	_add_service_pattern_panel(
		structure,
		"PowerSideLeft610",
		Vector3(panel_thickness, panel_height, side_depth),
		Vector3(-body_size.x * 0.5 - panel_thickness * 0.25, panel_y, 0.0),
		"utility_power_side_610"
	)
	_add_service_pattern_panel(
		structure,
		"PowerSideRight610",
		Vector3(panel_thickness, panel_height, side_depth),
		Vector3(body_size.x * 0.5 + panel_thickness * 0.25, panel_y, 0.0),
		"utility_power_side_610"
	)
	_add_service_pattern_panel(
		structure,
		"PowerBack609",
		Vector3(back_width, panel_height, panel_thickness),
		Vector3(0.0, panel_y, -body_size.z * 0.5 - panel_thickness * 0.25),
		"utility_power_back_609"
	)


func _add_service_pattern_panel(
	structure: Node3D,
	panel_name: String,
	panel_size: Vector3,
	panel_position: Vector3,
	panel_category: String
) -> void:
	if structure == null:
		return
	var panel_mesh := MeshInstance3D.new()
	panel_mesh.name = panel_name
	var box := BoxMesh.new()
	box.size = panel_size
	panel_mesh.mesh = box
	panel_mesh.position = panel_position
	panel_mesh.material_override = _make_psx_material(
		Color(1.0, 1.0, 1.0, 1.0),
		0.006,
		24.0,
		6.0,
		0.02,
		panel_category,
		1.0
	)
	structure.add_child(panel_mesh)


func _register_lamp_runtime(lamp_root: Node3D, spot: SpotLight3D, fill: OmniLight3D, beam: MeshInstance3D, dust: GPUParticles3D) -> void:
	if lamp_root == null:
		return
	var lamp_id = int(lamp_root.get_instance_id())
	var entry: Dictionary = {
		"root": lamp_root,
		"spot": spot,
		"fill": fill,
		"beam": beam,
		"dust": dust,
		"base_spot_energy": spot.light_energy if spot != null else 1.0,
		"base_fill_energy": fill.light_energy if fill != null else 0.0,
		"flicker_remaining": 0.0,
		"flicker_phase": _lamp_rng.randf_range(0.0, TAU),
	}
	_update_lamp_beam_orientation(entry)
	_apply_lamp_entry_base_state(entry, _lamps_active)
	_lamp_runtime[lamp_id] = entry


func _prune_stale_lamp_runtime() -> void:
	var stale_ids: Array[int] = []
	for lamp_id_var in _lamp_runtime.keys():
		var lamp_id = int(lamp_id_var)
		var entry_any = _lamp_runtime.get(lamp_id, null)
		if not (entry_any is Dictionary):
			stale_ids.append(lamp_id)
			continue
		var entry: Dictionary = entry_any
		var root = entry.get("root", null)
		if not (root is Node) or not is_instance_valid(root):
			stale_ids.append(lamp_id)
	for lamp_id in stale_ids:
		_lamp_runtime.erase(lamp_id)


func _unregister_lamp_runtime(lamp_root: Node3D) -> void:
	if lamp_root == null:
		return
	_lamp_runtime.erase(int(lamp_root.get_instance_id()))
	if _lamp_runtime.is_empty():
		_lamp_player_cache = null


func _resolve_lamp_target_player() -> Node3D:
	if _lamp_player_cache != null and is_instance_valid(_lamp_player_cache):
		return _lamp_player_cache
	_lamp_player_cache = null
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	_lamp_player_cache = tree.root.find_child("Player", true, false) as Node3D
	return _lamp_player_cache


func _update_lamp_beam_orientation(entry: Dictionary) -> void:
	var beam = entry.get("beam", null) as Node3D
	if beam == null or not is_instance_valid(beam):
		return
	var player = _resolve_lamp_target_player()
	if player == null or not is_instance_valid(player):
		return
	var target = player.global_position
	target.y = beam.global_position.y
	var dir = target - beam.global_position
	if dir.length_squared() <= 0.0001:
		return
	beam.look_at(beam.global_position + dir.normalized(), Vector3.UP)


func _roll_lamp_flickers() -> void:
	if not _lamps_active or _lamp_runtime.is_empty():
		return
	var lamp_ids = _lamp_runtime.keys()
	for lamp_id_var in lamp_ids:
		var lamp_id = int(lamp_id_var)
		var entry_any = _lamp_runtime.get(lamp_id, null)
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		if float(entry.get("flicker_remaining", 0.0)) > 0.0:
			continue
		if _lamp_rng.randf() <= 0.10:
			entry["flicker_remaining"] = _lamp_rng.randf_range(0.10, 0.30)
			entry["flicker_phase"] = _lamp_rng.randf_range(0.0, TAU)
			_lamp_runtime[lamp_id] = entry


func _apply_lamp_entry_base_state(entry: Dictionary, active: bool) -> void:
	active = active and not _is_lamp_entry_broken(entry)
	var spot = entry.get("spot", null) as SpotLight3D
	var fill = entry.get("fill", null) as OmniLight3D
	var beam = entry.get("beam", null) as MeshInstance3D
	var dust = entry.get("dust", null) as GPUParticles3D
	var base_spot = float(entry.get("base_spot_energy", 1.0))
	var base_fill = float(entry.get("base_fill_energy", 0.0))
	var beam_mat = beam.material_override as StandardMaterial3D if beam != null else null
	if active:
		if spot != null:
			spot.visible = true
			spot.light_energy = base_spot
		if fill != null:
			fill.visible = true
			fill.light_energy = base_fill
		if beam != null:
			beam.visible = true
		if beam_mat != null:
			var base_alpha = float(beam_mat.get_meta("beam_base_alpha", 0.085))
			var base_emission = float(beam_mat.get_meta("beam_base_emission", 0.30))
			beam_mat.albedo_color = Color(beam_mat.albedo_color.r, beam_mat.albedo_color.g, beam_mat.albedo_color.b, base_alpha)
			beam_mat.emission_energy_multiplier = base_emission
		if dust != null:
			dust.emitting = true
	else:
		if spot != null:
			spot.visible = false
			spot.light_energy = 0.0
		if fill != null:
			fill.visible = false
			fill.light_energy = 0.0
		if beam != null:
			beam.visible = false
		if beam_mat != null:
			beam_mat.albedo_color = Color(beam_mat.albedo_color.r, beam_mat.albedo_color.g, beam_mat.albedo_color.b, 0.0)
			beam_mat.emission_energy_multiplier = 0.0
		if dust != null:
			dust.emitting = false


func _update_lamp_flicker(entry: Dictionary, delta: float) -> void:
	if not _lamps_active or _is_lamp_entry_broken(entry):
		return
	var remaining = float(entry.get("flicker_remaining", 0.0))
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	var phase = float(entry.get("flicker_phase", 0.0))
	phase += delta * 42.0
	entry["flicker_remaining"] = remaining
	entry["flicker_phase"] = phase

	var pulse = clampf(0.22 + absf(sin(phase)) * 0.78, 0.16, 1.0)
	var spot = entry.get("spot", null) as SpotLight3D
	var fill = entry.get("fill", null) as OmniLight3D
	var beam = entry.get("beam", null) as MeshInstance3D
	var base_spot = float(entry.get("base_spot_energy", 1.0))
	var base_fill = float(entry.get("base_fill_energy", 0.0))
	if spot != null:
		spot.light_energy = base_spot * pulse
	if fill != null:
		fill.light_energy = base_fill * (0.35 + (pulse * 0.65))
	if beam != null:
		var beam_mat = beam.material_override as StandardMaterial3D
		if beam_mat != null:
			var base_alpha = float(beam_mat.get_meta("beam_base_alpha", 0.085))
			var base_emission = float(beam_mat.get_meta("beam_base_emission", 0.30))
			var beam_mul = 0.30 + (pulse * 0.70)
			beam_mat.albedo_color = Color(beam_mat.albedo_color.r, beam_mat.albedo_color.g, beam_mat.albedo_color.b, base_alpha * beam_mul)
			beam_mat.emission_energy_multiplier = base_emission * beam_mul

	if remaining <= 0.0:
		_apply_lamp_entry_base_state(entry, true)


func get_light_level_at(world_pos: Vector3) -> float:
	if not _lamps_active:
		return 0.0
	_prune_stale_lamp_runtime()
	if _lamp_runtime.is_empty():
		return 0.0

	var sample_pos = world_pos + Vector3(0.0, 0.2, 0.0)
	var total := 0.0
	var space_state: PhysicsDirectSpaceState3D = null
	if get_world_3d() != null:
		space_state = get_world_3d().direct_space_state

	for entry_any in _lamp_runtime.values():
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var root = entry.get("root", null) as Node3D
		if root == null or not is_instance_valid(root):
			continue

		var spot = entry.get("spot", null) as SpotLight3D
		if spot != null and spot.visible and spot.light_energy > 0.001:
			total += _sample_spot_light_contribution(sample_pos, root, spot, entry, space_state)

		var fill = entry.get("fill", null) as OmniLight3D
		if fill != null and fill.visible and fill.light_energy > 0.001:
			total += _sample_fill_light_contribution(sample_pos, root, fill, entry, space_state)

	return clampf(total / LAMP_LIGHT_NORMALIZATION, 0.0, 1.0)


func _sample_spot_light_contribution(
	sample_pos: Vector3,
	lamp_root: Node3D,
	spot: SpotLight3D,
	entry: Dictionary,
	space_state: PhysicsDirectSpaceState3D
) -> float:
	var to_sample = sample_pos - spot.global_position
	var dist = to_sample.length()
	var range = maxf(0.01, spot.spot_range)
	if dist > range:
		return 0.0
	if dist <= 0.0001:
		return 0.0

	var dir_to_sample = to_sample / dist
	var spot_forward = (-spot.global_transform.basis.z).normalized()
	var cone_limit = cos(deg_to_rad(maxf(4.0, spot.spot_angle) * 0.5))
	var cone_dot = spot_forward.dot(dir_to_sample)
	if cone_dot < cone_limit:
		return 0.0

	var cone_t = clampf((cone_dot - cone_limit) / maxf(1.0 - cone_limit, 0.0001), 0.0, 1.0)
	var distance_t = 1.0 - clampf(dist / range, 0.0, 1.0)
	var energy_scale = clampf(float(entry.get("base_spot_energy", spot.light_energy)) / 1.10, 0.05, 1.80)
	var occlusion = _lamp_line_of_sight_multiplier(sample_pos, spot.global_position, lamp_root, space_state)
	return (distance_t * distance_t) * cone_t * energy_scale * occlusion


func _sample_fill_light_contribution(
	sample_pos: Vector3,
	lamp_root: Node3D,
	fill: OmniLight3D,
	entry: Dictionary,
	space_state: PhysicsDirectSpaceState3D
) -> float:
	var to_sample = sample_pos - fill.global_position
	var dist = to_sample.length()
	var range = maxf(0.01, fill.omni_range)
	if dist > range:
		return 0.0
	var distance_t = 1.0 - clampf(dist / range, 0.0, 1.0)
	var energy_scale = clampf(float(entry.get("base_fill_energy", fill.light_energy)) / 0.20, 0.05, 1.60)
	var occlusion = _lamp_line_of_sight_multiplier(sample_pos, fill.global_position, lamp_root, space_state)
	return (distance_t * distance_t) * 0.52 * energy_scale * occlusion


func _lamp_line_of_sight_multiplier(
	sample_pos: Vector3,
	light_pos: Vector3,
	lamp_root: Node3D,
	space_state: PhysicsDirectSpaceState3D
) -> float:
	if space_state == null:
		return 1.0
	var query := PhysicsRayQueryParameters3D.create(sample_pos, light_pos)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit = space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	var collider = hit.get("collider", null)
	if collider == null:
		return 1.0
	if collider == lamp_root:
		return 1.0
	if collider is Node and lamp_root.is_ancestor_of(collider as Node):
		return 1.0
	return LAMP_LIGHT_OCCLUSION_MULTIPLIER


func remove_structure(node: Node) -> bool:
	# A path takes its lamp with it.
	if node != null and node.has_meta("lamp_node"):
		var lamp_node = node.get_meta("lamp_node")
		if lamp_node != null and is_instance_valid(lamp_node):
			(lamp_node as Node).queue_free()
	if _grid_manager == null or node == null:
		return false

	var structure = _resolve_structure_root(node)
	if structure == null:
		return false

	var origin = structure.get_meta("grid_origin", _grid_manager.world_to_grid(structure.global_position))
	var footprint = structure.get_meta("grid_footprint", Vector2i(1, 1))
	var preserve_reserved = bool(structure.get_meta("preserve_reserved", false))
	var building_type = str(structure.get_meta("building_type", ""))
	var was_path = building_type == "path" or structure.is_in_group("paths")
	var was_lamp = building_type == "lamp_post" or structure.is_in_group("lamp_posts")

	for oy in range(footprint.y):
		for ox in range(footprint.x):
			var coord = origin + Vector2i(ox, oy)
			if not _grid_manager.is_in_bounds(coord):
				continue
			_grid_manager.set_tile_occupied(coord, false, null)
			if preserve_reserved:
				continue
			_grid_manager.set_tile_type(coord, _grid_manager.TILE_GRASS)

	if was_lamp:
		_unregister_lamp_runtime(structure)
	structure.queue_free()
	if was_path:
		_refresh_path_neighbors(origin)
	return true


func _refresh_path_neighbors(origin: Vector2i) -> void:
	_refresh_path_visual_at(origin)
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_refresh_path_visual_at(origin + offset)


func _refresh_path_visual_at(coord: Vector2i) -> void:
	var path_root = _get_path_root_at(coord)
	if path_root == null:
		return
	var path_mesh = path_root.get_node_or_null("PathMesh") as MeshInstance3D
	if path_mesh == null:
		return
	var style = _resolve_path_style(coord)
	var texture_path = str(style.get("texture_path", ""))
	var rotation_steps = int(style.get("rotation_steps", 0))
	path_mesh.material_override = _make_path_surface_material(_load_path_texture(texture_path))
	path_root.rotation_degrees = Vector3(0.0, float(rotation_steps) * 90.0, 0.0)


func _resolve_path_style(coord: Vector2i) -> Dictionary:
	var mask = 0
	if _is_path_at(coord + Vector2i(0, -1)):
		mask |= PATH_DIR_N
	if _is_path_at(coord + Vector2i(1, 0)):
		mask |= PATH_DIR_E
	if _is_path_at(coord + Vector2i(0, 1)):
		mask |= PATH_DIR_S
	if _is_path_at(coord + Vector2i(-1, 0)):
		mask |= PATH_DIR_W

	var connection_count = _count_path_connections(mask)
	var style_key = "straight"
	var target_mask = mask

	match connection_count:
		4:
			style_key = "cross"
			target_mask = PATH_MASK_CROSS
		3:
			style_key = "t_junction"
		2:
			if mask == (PATH_DIR_N | PATH_DIR_S) or mask == (PATH_DIR_E | PATH_DIR_W):
				style_key = "straight"
			else:
				style_key = "turn"
		1:
			style_key = "dead_end"
		0:
			style_key = "solo"
			target_mask = PATH_MASK_DEAD_END
		_:
			style_key = "straight"

	var base_mask = _path_base_mask(style_key)
	var rotation_steps = _find_path_rotation_steps(base_mask, target_mask)
	var texture_path = str(PATH_TEXTURES.get(style_key, PATH_TEXTURES["straight"]))
	return {
		"texture_path": texture_path,
		"rotation_steps": rotation_steps,
	}


func _count_path_connections(mask: int) -> int:
	var count = 0
	if (mask & PATH_DIR_N) != 0:
		count += 1
	if (mask & PATH_DIR_E) != 0:
		count += 1
	if (mask & PATH_DIR_S) != 0:
		count += 1
	if (mask & PATH_DIR_W) != 0:
		count += 1
	return count


func _path_base_mask(style_key: String) -> int:
	match style_key:
		"cross":
			return PATH_MASK_CROSS
		"t_junction":
			return PATH_MASK_T_JUNCTION
		"turn":
			return PATH_MASK_TURN
		"dead_end":
			return PATH_MASK_DEAD_END
		"solo":
			return PATH_MASK_DEAD_END
		"straight":
			return PATH_MASK_STRAIGHT
		_:
			return PATH_MASK_STRAIGHT


func _find_path_rotation_steps(base_mask: int, target_mask: int) -> int:
	for step in range(4):
		if _rotate_path_mask_ccw(base_mask, step) == target_mask:
			return step
	return 0


func _rotate_path_mask_ccw(mask: int, steps: int) -> int:
	var rotated = mask
	var safe_steps = wrapi(steps, 0, 4)
	for _i in range(safe_steps):
		var next_mask = 0
		if (rotated & PATH_DIR_E) != 0:
			next_mask |= PATH_DIR_N
		if (rotated & PATH_DIR_S) != 0:
			next_mask |= PATH_DIR_E
		if (rotated & PATH_DIR_W) != 0:
			next_mask |= PATH_DIR_S
		if (rotated & PATH_DIR_N) != 0:
			next_mask |= PATH_DIR_W
		rotated = next_mask
	return rotated


func _is_path_at(coord: Vector2i) -> bool:
	return _get_path_root_at(coord) != null


func _get_path_root_at(coord: Vector2i) -> Node3D:
	if _grid_manager == null or not _grid_manager.is_in_bounds(coord):
		return null
	var tile = _grid_manager.get_tile(coord)
	if tile == null or not tile.occupied or tile.occupant == null:
		return null
	var root = _resolve_structure_root(tile.occupant)
	if root == null:
		return null
	if root.is_in_group("paths"):
		return root
	if str(root.get_meta("building_type", "")) == "path":
		return root
	return null


func _load_path_texture(texture_path: String) -> Texture2D:
	if texture_path == "":
		return null
	if _path_texture_cache.has(texture_path):
		return _path_texture_cache[texture_path] as Texture2D
	var tex = load(texture_path) as Texture2D
	if tex == null:
		var image = Image.new()
		var abs_path = ProjectSettings.globalize_path(texture_path)
		if FileAccess.file_exists(abs_path) and image.load(abs_path) == OK and not image.is_empty():
			tex = ImageTexture.create_from_image(image)
	_path_texture_cache[texture_path] = tex
	return tex


func _make_path_surface_material(albedo_tex: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = PATH_ALPHA_SCISSOR_THRESHOLD
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	if albedo_tex != null:
		mat.albedo_texture = albedo_tex
	mat.set_meta("base_albedo_color", mat.albedo_color)
	return mat


func set_structure_condition(node: Node, condition: float) -> bool:
	if node == null:
		return false
	var structure = _resolve_structure_root(node)
	if structure == null:
		return false
	_set_structure_condition_internal(structure, condition)
	return true


func get_structure_condition(node: Node) -> float:
	if node == null:
		return 1.0
	var structure = _resolve_structure_root(node)
	if structure == null:
		return 1.0
	return float(structure.get_meta("condition", 1.0))


func find_nearest_free_tile_in_front(player: Node3D, footprint: Vector2i = Vector2i(1, 1), max_distance: float = 24.0) -> Vector2i:
	if _grid_manager == null or player == null:
		return Vector2i(-1, -1)

	var camera = player.get_node_or_null("Head/Camera3D") as Camera3D
	var forward = -player.global_transform.basis.z
	if camera != null:
		forward = -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.length_squared() <= 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)

	var player_pos = player.global_position
	var best_coord = Vector2i(-1, -1)
	var best_score = 1.0e20

	for coord in _grid_manager.get_all_coords():
		if not _grid_manager.can_place_footprint(coord, footprint):
			continue

		var tile_center = _grid_manager.get_footprint_center(coord, footprint)
		var to_tile = tile_center - player_pos
		to_tile.y = 0.0
		var distance = to_tile.length()
		if distance > max_distance or distance < 0.2:
			continue

		var dir = to_tile / distance
		var front_dot = dir.dot(forward)
		if front_dot < 0.12:
			continue

		var score = distance + ((1.0 - front_dot) * 8.0)
		if score < best_score:
			best_score = score
			best_coord = coord

	return best_coord


func _spawn_crt_placeholder(building: Node3D, building_size: Vector3) -> void:
	var crt = StaticBody3D.new()
	crt.name = "CRTPlaceholder"
	building.add_child(crt)

	var crt_size = Vector3(1.0, 0.85, 0.8)
	crt.position = Vector3(0.0, -building_size.y * 0.5 + (crt_size.y * 0.5) + 0.15, building_size.z * 0.2)

	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = crt_size
	collider.shape = shape
	crt.add_child(collider)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = crt_size
	mesh.mesh = box
	var mat = _make_psx_material(Color(0.52, 0.50, 0.48), 0.008, 28.0, 6.0, 0.06, "decor_metal")
	mesh.material_override = mat
	crt.add_child(mesh)


func _spawn_door(building: Node3D, building_size: Vector3) -> void:
	var door = StaticBody3D.new()
	door.name = "Door"
	door.add_to_group("crt_interactable")
	building.add_child(door)

	var collider = CollisionShape3D.new()
	var collider_shape = BoxShape3D.new()
	collider_shape.size = Vector3(1.2, 2.4, 0.32)
	collider.shape = collider_shape
	door.add_child(collider)

	var door_mesh_instance = MeshInstance3D.new()
	var door_mesh = BoxMesh.new()
	var door_size = Vector3(1.0, 2.2, 0.08)
	door_mesh.size = door_size
	door_mesh_instance.mesh = door_mesh
	door_mesh_instance.position = Vector3(0.0, 0.0, 0.02)
	door.position = Vector3(0.0, -building_size.y * 0.5 + door_size.y * 0.5, building_size.z * 0.5 + 0.02)
	var mat = _make_psx_material(Color(0.56, 0.35, 0.24), 0.006, 30.0, 6.0, 0.08, "building_door", 0.36)
	door_mesh_instance.material_override = mat
	door.add_child(door_mesh_instance)

	var frame_l = MeshInstance3D.new()
	var frame_r = MeshInstance3D.new()
	var frame_t = MeshInstance3D.new()
	var frame_box = BoxMesh.new()
	frame_box.size = Vector3(0.10, 2.34, 0.12)
	frame_l.mesh = frame_box
	frame_r.mesh = frame_box
	frame_l.position = Vector3(-(door_size.x * 0.5) - 0.08, 0.0, 0.04)
	frame_r.position = Vector3((door_size.x * 0.5) + 0.08, 0.0, 0.04)
	var frame_top_box = BoxMesh.new()
	frame_top_box.size = Vector3(door_size.x + 0.32, 0.12, 0.12)
	frame_t.mesh = frame_top_box
	frame_t.position = Vector3(0.0, (door_size.y * 0.5) + 0.10, 0.04)
	var frame_mat = _make_psx_material(Color(0.78, 0.72, 0.64), 0.004, 26.0, 6.0, 0.06, "building_door", 0.24)
	frame_l.material_override = frame_mat
	frame_r.material_override = frame_mat
	frame_t.material_override = frame_mat
	door.add_child(frame_l)
	door.add_child(frame_r)
	door.add_child(frame_t)

	var knob = MeshInstance3D.new()
	var knob_box = BoxMesh.new()
	knob_box.size = Vector3(0.04, 0.06, 0.06)
	knob.mesh = knob_box
	knob.position = Vector3(0.34, -0.18, 0.07)
	knob.material_override = _make_psx_material(Color(0.88, 0.78, 0.42), 0.002, 30.0, 6.0, 0.02, "decor_metal")
	door.add_child(knob)


func _spawn_building_windows(building: Node3D, building_size: Vector3, building_type: String = "") -> void:
	if building == null:
		return
	if building_type == "bonfire" or building_type == "path":
		return

	var win_w = clampf(building_size.x * 0.20, 0.22, 0.74)
	var win_h = clampf(building_size.y * 0.24, 0.24, 0.56)
	var win_t = 0.04
	var win_y = -building_size.y * 0.5 + building_size.y * 0.68
	var window_mat = _make_psx_material(Color(0.56, 0.74, 0.90), 0.004, 24.0, 6.0, 0.03, "building_window")

	var offsets: Array[float] = [0.0]
	if building_size.x > 1.8:
		offsets = [-building_size.x * 0.23, building_size.x * 0.23]

	for x in offsets:
		var front_window = MeshInstance3D.new()
		var front_box = BoxMesh.new()
		front_box.size = Vector3(win_w, win_h, win_t)
		front_window.mesh = front_box
		front_window.position = Vector3(x, win_y, building_size.z * 0.5 + 0.02)
		front_window.material_override = window_mat
		building.add_child(front_window)

	if building_size.z > 1.2:
		for side in [-1.0, 1.0]:
			var side_window = MeshInstance3D.new()
			var side_box = BoxMesh.new()
			side_box.size = Vector3(clampf(building_size.z * 0.22, 0.20, 0.66), win_h * 0.86, win_t)
			side_window.mesh = side_box
			side_window.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			side_window.position = Vector3(float(side) * (building_size.x * 0.5 + 0.02), win_y, 0.0)
			side_window.material_override = window_mat
			building.add_child(side_window)


func _spawn_office_sign(building: Node3D, building_size: Vector3) -> void:
	var sign_node = Node3D.new()
	sign_node.name = "OfficeSign"
	building.add_child(sign_node)
	sign_node.position = Vector3(building_size.x * 0.34, -building_size.y * 0.5 + 0.02, building_size.z * 0.5 + 0.64)

	var post_h = 1.52
	var post_spacing = 0.78
	var post_size = Vector3(0.08, post_h, 0.08)
	for side in [-1.0, 1.0]:
		var post_mesh = MeshInstance3D.new()
		var post_box = BoxMesh.new()
		post_box.size = post_size
		post_mesh.mesh = post_box
		post_mesh.position = Vector3(float(side) * post_spacing * 0.5, post_h * 0.5, 0.0)
		post_mesh.material_override = _make_psx_material(Color(0.38, 0.28, 0.18), 0.006, 24.0, 6.0, 0.08, "office_sign_post")
		sign_node.add_child(post_mesh)

	var board_w = 1.08
	var board_h = 0.56
	var board_t = 0.03
	var board_y = post_h * 0.72

	var front_board = MeshInstance3D.new()
	var front_box = BoxMesh.new()
	front_box.size = Vector3(board_w, board_h, board_t)
	front_board.mesh = front_box
	front_board.position = Vector3(0.0, board_y, board_t * 0.5)
	front_board.material_override = _make_psx_material(Color(0.90, 0.84, 0.70), 0.004, 24.0, 6.0, 0.02, "office_sign_front")
	sign_node.add_child(front_board)

	var back_board = MeshInstance3D.new()
	var back_box = BoxMesh.new()
	back_box.size = Vector3(board_w, board_h, board_t)
	back_board.mesh = back_box
	back_board.position = Vector3(0.0, board_y, -board_t * 0.5)
	back_board.material_override = _make_psx_material(Color(0.44, 0.30, 0.20), 0.004, 24.0, 6.0, 0.02, "office_sign_back")
	sign_node.add_child(back_board)


func _get_or_create_child(node_name: String) -> Node3D:
	var existing = get_node_or_null(node_name) as Node3D
	if existing != null:
		return existing
	var created = Node3D.new()
	created.name = node_name
	add_child(created)
	return created


func _ensure_structures_root() -> void:
	if _structures_root == null:
		_structures_root = _get_or_create_child("Structures")


func _resolve_structure_root(node: Node) -> Node3D:
	var current = node
	while current != null:
		if current is Node3D and current.get_parent() == _structures_root:
			return current as Node3D
		current = current.get_parent()
	return null


func _tag_structure(structure: Node3D, origin: Vector2i, footprint: Vector2i, building_type: String, preserve_reserved: bool) -> void:
	structure.set_meta("grid_origin", origin)
	structure.set_meta("grid_footprint", footprint)
	structure.set_meta("building_type", building_type)
	structure.set_meta("preserve_reserved", preserve_reserved)
	structure.set_meta("condition", 1.0)
	structure.set_meta("guest_count", 0)
	structure.set_meta("has_guest", false)


func _make_psx_material(base_color: Color, _wobble_strength: float, _snap_amount: float, _color_steps: float, _corrosion_amount: float = 0.0, texture_category: String = "", _texture_influence: float = 0.62) -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var category = texture_category if texture_category != "" else _guess_texture_category(base_color)
	if _texture_style != null:
		var albedo_tex = _texture_style.pick_texture(category, base_color)
		if albedo_tex != null:
			mat.albedo_texture = albedo_tex
	_apply_psx_texture_profile(mat, category, _texture_influence, base_color)
	return mat


func _apply_psx_texture_profile(mat: StandardMaterial3D, category: String, requested_influence: float, base_color: Color) -> void:
	var canonical = category.to_lower()
	var uv_scale := PSX_TEXTURE_DEFAULT_UV
	var min_influence := 0.44

	if canonical.contains("wall") or canonical == "brick":
		uv_scale = Vector2(2.3, 1.8)
		min_influence = 0.62
	elif canonical.contains("roof"):
		uv_scale = Vector2(2.0, 2.0)
		min_influence = 0.56
	elif canonical.contains("wood"):
		uv_scale = Vector2(1.8, 1.2)
		min_influence = 0.52
	elif canonical == "building_door":
		uv_scale = Vector2(1.4, 1.4)
		min_influence = 0.36
	elif canonical == "building_window":
		uv_scale = Vector2(1.0, 1.0)
		min_influence = 0.42
	elif canonical.contains("sign"):
		uv_scale = Vector2(1.2, 1.2)
		min_influence = 0.52
	elif canonical.contains("road") or canonical.contains("floor"):
		uv_scale = Vector2(1.6, 1.6)
		min_influence = 0.50
	elif canonical.contains("metal"):
		uv_scale = Vector2(1.4, 1.4)
		min_influence = 0.46

	mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	var influence = maxf(clampf(requested_influence, 0.0, 1.0), min_influence)
	if mat.albedo_texture != null:
		mat.albedo_color = base_color.lerp(Color(1.0, 1.0, 1.0, 1.0), influence)
	else:
		mat.albedo_color = base_color
	mat.set_meta("base_albedo_color", mat.albedo_color)


func _guess_texture_category(base_color: Color) -> String:
	var h = base_color.h
	var s = base_color.s
	var v = base_color.v

	if s < 0.18 and v < 0.35:
		return "decor_metal"
	if s < 0.22 and v > 0.65:
		return "wall"
	if h >= 0.50 and h <= 0.66:
		return "water"
	if h >= 0.22 and h <= 0.42 and s > 0.24:
		return "grass"
	if h >= 0.03 and h <= 0.17 and s > 0.25:
		return "decor_wood"
	if h >= 0.55 and s < 0.28:
		return "decor_metal"
	if h >= 0.08 and h <= 0.18 and v < 0.55:
		return "floor"
	if h >= 0.90 or h <= 0.06:
		return "roof"
	return "decor"


func _default_condition_for_type(building_type: String, level: int = 1) -> float:
	match building_type:
		"main_building":
			return 0.88
		"cabin":
			return 0.82
		"caravan":
			return 0.80
		"path":
			return 0.72
		"service":
			return 0.86
		"attraction":
			return 0.84
		"utility":
			return 0.78
		"placeholder":
			return 0.86
		"tent":
			if level <= 1:
				return 0.74
			if level == 2:
				return 0.84
			return 0.92
		_:
			return 0.90


func _set_structure_condition_internal(structure: Node3D, condition: float) -> void:
	var clamped = clamp(condition, 0.0, 1.0)
	structure.set_meta("condition", clamped)
	var corrosion_amount = clamp(1.0 - clamped, 0.0, 1.0)
	_apply_corrosion_recursive(structure, corrosion_amount)


func _apply_corrosion_recursive(node: Node, corrosion_amount: float) -> void:
	if node is MeshInstance3D:
		var mesh = node as MeshInstance3D
		var std_mat = mesh.material_override as StandardMaterial3D
		if std_mat != null:
			var base_color = Color(1.0, 1.0, 1.0, 1.0)
			if std_mat.has_meta("base_albedo_color"):
				var stored = std_mat.get_meta("base_albedo_color")
				if stored is Color:
					base_color = stored
			var darken = lerpf(1.0, 0.62, corrosion_amount)
			std_mat.albedo_color = Color(base_color.r * darken, base_color.g * darken, base_color.b * darken, base_color.a)
		var shader_mat = mesh.material_override as ShaderMaterial
		if shader_mat != null:
			shader_mat.set_shader_parameter("corrosion_amount", corrosion_amount)

	for child in node.get_children():
		_apply_corrosion_recursive(child, corrosion_amount)


func _add_service_roof_wedges(structure: Node3D, body_size: Vector3, _roof_size: Vector3, _roof_y: float, roof_rot_x: float, wall_category: String) -> void:
	if structure == null:
		return

	# The roof is rotated by roof_rot_x around its X-axis (approx -11 deg).
	# Negative X rotation in Godot = front (+Z) rises, back (-Z) dips.
	# This creates a triangular gap on each side wall between the flat
	# wall top (at body_size.y) and the angled underside of the roof.
	# The gap is tallest at the front (+Z) and zero at the back (-Z).

	var depth = body_size.z
	var angle_rad = abs(roof_rot_x)
	var gap_height = tan(angle_rad) * depth + 0.02  # slight overlap to avoid z-fighting

	# PrismMesh creates a triangular prism.
	# left_to_right = 0.0 places the apex at the -X side.
	# We set size so X = depth (along the wall), Y = gap height, Z = wall thickness.
	# Then rotate -90° around Y so the prism's X-axis aligns with world Z (depth).
	# After rotation: the tall edge (apex) maps to +Z (front), tapering to 0 at -Z (back).

	var thickness = body_size.x * 0.08  # match approximate wall panel thickness
	thickness = maxf(thickness, 0.08)

	var wedge_mesh = PrismMesh.new()
	wedge_mesh.left_to_right = 0.0
	wedge_mesh.size = Vector3(depth, gap_height, thickness)

	var mat = _make_psx_material(Color(0.58, 0.56, 0.50), 0.01, 24.0, 6.0, 0.10, wall_category)

	# Left side wall wedge
	var w_left = MeshInstance3D.new()
	w_left.name = "RoofWedgeLeft"
	w_left.mesh = wedge_mesh
	w_left.rotation_degrees = Vector3(0, -90, 0)
	w_left.position = Vector3(-body_size.x * 0.5, body_size.y + gap_height * 0.5, 0.0)
	w_left.material_override = mat
	structure.add_child(w_left)

	# Right side wall wedge
	var w_right = MeshInstance3D.new()
	w_right.name = "RoofWedgeRight"
	w_right.mesh = wedge_mesh
	w_right.rotation_degrees = Vector3(0, -90, 0)
	w_right.position = Vector3(body_size.x * 0.5, body_size.y + gap_height * 0.5, 0.0)
	w_right.material_override = mat
	structure.add_child(w_right)
