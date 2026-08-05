extends Node3D

const TILE_GRASS = 0
const TILE_LAKE = 1
const TILE_RESERVED = 2
const TILE_BUILDING = 3
const GRID_MODEL_SCRIPT = preload("res://core/state/grid_model.gd")

@export var grid_width: int = 20
@export var grid_height: int = 20
@export var tile_size: float = 4.0
@export var debug_draw_grid: bool = false
@export var debug_line_color: Color = Color(0.86, 0.94, 1.0, 0.72)
@export var debug_line_height: float = 0.06

var _grid_model: GridModel
var _debug_mesh_instance: MeshInstance3D
var _debug_material: StandardMaterial3D


func _ready() -> void:
	_ensure_grid_model()
	_ensure_debug_visual()


func initialize_grid(new_size: Vector2i = Vector2i(20, 20), new_tile_size: float = 4.0) -> void:
	_ensure_grid_model()
	_grid_model.init_dimensions(new_size.x, new_size.y, new_tile_size)
	_pull_dimensions_from_model()
	rebuild_debug_mesh()


func get_grid_size() -> Vector2i:
	_ensure_grid_model()
	_pull_dimensions_from_model()
	return _grid_model.get_grid_size()


func get_map_min_corner() -> Vector3:
	_ensure_grid_model()
	return _grid_model.get_map_min_corner()


func get_map_center_world() -> Vector3:
	_ensure_grid_model()
	return _grid_model.get_map_center_world()


func get_map_size_world() -> Vector2:
	_ensure_grid_model()
	return _grid_model.get_map_size_world()


func grid_to_world(coord: Vector2i) -> Vector3:
	_ensure_grid_model()
	return _grid_model.grid_to_world(coord)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	_ensure_grid_model()
	return _grid_model.world_to_grid(world_pos)


func get_footprint_center(origin: Vector2i, footprint: Vector2i) -> Vector3:
	_ensure_grid_model()
	return _grid_model.get_footprint_center(origin, footprint)


func is_in_bounds(coord: Vector2i) -> bool:
	_ensure_grid_model()
	return _grid_model.is_in_bounds(coord)


func get_tile(coord: Vector2i):
	_ensure_grid_model()
	return _grid_model.get_tile_view(coord)


func get_all_coords() -> Array:
	_ensure_grid_model()
	return _grid_model.get_all_coords()


func reset_tiles(tile_type: int = TILE_GRASS) -> void:
	_ensure_grid_model()
	_grid_model.reset_tiles(tile_type)


func set_tile_type(coord: Vector2i, tile_type: int) -> bool:
	_ensure_grid_model()
	if not _grid_model.is_in_bounds(coord):
		return false
	_grid_model.set_tile_type(coord, tile_type)
	return true


func set_tile_occupied(coord: Vector2i, occupied: bool, occupant: Node3D = null) -> bool:
	_ensure_grid_model()
	return _grid_model.set_tile_occupied(coord, occupied, occupant)


func can_place_footprint(origin: Vector2i, footprint: Vector2i, allow_reserved: bool = false) -> bool:
	_ensure_grid_model()
	return _grid_model.can_place_footprint(origin, footprint, allow_reserved)


func occupy_footprint(origin: Vector2i, footprint: Vector2i, occupant: Node3D, tile_type: int = TILE_BUILDING, preserve_reserved: bool = false) -> void:
	_ensure_grid_model()
	_grid_model.occupy_footprint(origin, footprint, occupant, tile_type, preserve_reserved)


func rebuild_debug_mesh() -> void:
	_ensure_grid_model()
	_pull_dimensions_from_model()
	_ensure_debug_visual()
	_debug_mesh_instance.visible = debug_draw_grid
	if not debug_draw_grid:
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var min_corner = get_map_min_corner()
	var max_x = min_corner.x + (grid_width * tile_size)
	var max_z = min_corner.z + (grid_height * tile_size)

	for x in range(grid_width + 1):
		var wx = min_corner.x + (x * tile_size)
		st.set_color(debug_line_color)
		st.add_vertex(Vector3(wx, debug_line_height, min_corner.z))
		st.set_color(debug_line_color)
		st.add_vertex(Vector3(wx, debug_line_height, max_z))

	for y in range(grid_height + 1):
		var wz = min_corner.z + (y * tile_size)
		st.set_color(debug_line_color)
		st.add_vertex(Vector3(min_corner.x, debug_line_height, wz))
		st.set_color(debug_line_color)
		st.add_vertex(Vector3(max_x, debug_line_height, wz))

	_debug_mesh_instance.mesh = st.commit()
	_debug_mesh_instance.material_override = _debug_material


func _ensure_debug_visual() -> void:
	if _debug_mesh_instance == null:
		_debug_mesh_instance = MeshInstance3D.new()
		_debug_mesh_instance.name = "GridDebug"
		add_child(_debug_mesh_instance)

	if _debug_material == null:
		_debug_material = StandardMaterial3D.new()
		_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_material.albedo_color = debug_line_color


func _ensure_grid_model() -> void:
	var resolved_model: GridModel = null
	var core_root = get_node_or_null("/root/CoreRoot")
	if core_root != null and core_root.has_method("get_state"):
		var state = core_root.get_state()
		if state != null:
			var state_grid = state.get("grid")
			if state_grid == null or not (state_grid is GridModel):
				state_grid = GRID_MODEL_SCRIPT.new()
				state.set("grid", state_grid)
			resolved_model = state_grid as GridModel

	if resolved_model != null:
		if _grid_model != resolved_model:
			_grid_model = resolved_model
			_pull_dimensions_from_model()
		return

	if _grid_model == null:
		_grid_model = GRID_MODEL_SCRIPT.new()
		_pull_dimensions_from_model()


func _pull_dimensions_from_model() -> void:
	if _grid_model == null:
		return
	grid_width = int(_grid_model.grid_width)
	grid_height = int(_grid_model.grid_height)
	tile_size = float(_grid_model.tile_size)
