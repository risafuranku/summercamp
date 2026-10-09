class_name GridModel
extends Resource

## Single source of truth for the camp grid.
## Holds building state (cells), terrain types (tile_types), visual occupants,
## and spatial math methods. GridManager is now a thin facade over this.

# ─── Tile type constants ──────────────────────────────────────────────────────
const TILE_GRASS: int = 0
const TILE_LAKE: int = 1
const TILE_RESERVED: int = 2
const TILE_BUILDING: int = 3

class TileView:
	var coord: Vector2i = Vector2i.ZERO
	var world_position: Vector3 = Vector3.ZERO
	var occupied: bool = false
	var tile_type: int = TILE_GRASS
	var occupant: Node3D = null

# ─── Grid dimensions (set via init_dimensions) ───────────────────────────────
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var tile_size: float = 4.0

# ─── Building state (canonical, saved/loaded) ────────────────────────────────
# Map: Vector2i → { "type": String, "id": String, "root_coord": Vector2i, "maintenance": float }
@export var cells: Dictionary = {}

# ─── Terrain types (LAKE / RESERVED overrides; GRASS is default / missing key) ─
# Map: Vector2i → int (TILE_LAKE or TILE_RESERVED only; GRASS = not present)
@export var tile_types: Dictionary = {}

# ─── Visual occupants (Node3D per root coord; runtime only, not saved) ────────
var occupants: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# INITIALISATION
# ═══════════════════════════════════════════════════════════════════════════════

## Set grid dimensions. Call once when the grid is first created.
func init_dimensions(w: int, h: int, s: float) -> void:
	grid_width = max(1, w)
	grid_height = max(1, h)
	tile_size = max(0.25, s)


## Clear all state (building cells + terrain + occupants).
func clear() -> void:
	cells.clear()
	tile_types.clear()
	occupants.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# SPATIAL MATH  (identical logic as GridManager — single copy here)
# ═══════════════════════════════════════════════════════════════════════════════

func get_grid_size() -> Vector2i:
	return Vector2i(grid_width, grid_height)


func get_map_min_corner() -> Vector3:
	return Vector3(-grid_width * tile_size * 0.5, 0.0, -grid_height * tile_size * 0.5)


func get_map_center_world() -> Vector3:
	var mc = get_map_min_corner()
	return Vector3(mc.x + (grid_width * tile_size * 0.5), 0.0, mc.z + (grid_height * tile_size * 0.5))


func get_map_size_world() -> Vector2:
	return Vector2(grid_width * tile_size, grid_height * tile_size)


func grid_to_world(coord: Vector2i) -> Vector3:
	var mc = get_map_min_corner()
	return Vector3(mc.x + ((coord.x + 0.5) * tile_size), 0.0, mc.z + ((coord.y + 0.5) * tile_size))


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var mc = get_map_min_corner()
	return Vector2i(int(floor((world_pos.x - mc.x) / tile_size)), int(floor((world_pos.z - mc.z) / tile_size)))


func get_footprint_center(origin: Vector2i, footprint: Vector2i) -> Vector3:
	var mc = get_map_min_corner()
	return Vector3(mc.x + ((origin.x + (footprint.x * 0.5)) * tile_size), 0.0, mc.z + ((origin.y + (footprint.y * 0.5)) * tile_size))


func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < grid_width and coord.y < grid_height


func get_all_coords() -> Array:
	var result: Array = []
	result.resize(grid_width * grid_height)
	var i = 0
	for y in range(grid_height):
		for x in range(grid_width):
			result[i] = Vector2i(x, y)
			i += 1
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# TERRAIN TYPES
# ═══════════════════════════════════════════════════════════════════════════════

## Returns terrain type. TILE_GRASS is the default for any coord not in tile_types.
func get_tile_type(coord: Vector2i) -> int:
	return tile_types.get(coord, TILE_GRASS)


## Set terrain type. Pass TILE_GRASS to erase (use default).
func set_tile_type(coord: Vector2i, tile_type: int) -> void:
	if tile_type == TILE_GRASS:
		tile_types.erase(coord)
	else:
		tile_types[coord] = tile_type


## Returns the effective tile type: terrain overrides if any, else TILE_BUILDING if occupied, else TILE_GRASS.
func get_effective_tile_type(coord: Vector2i) -> int:
	var terrain = tile_types.get(coord, TILE_GRASS)
	if terrain != TILE_GRASS:
		return terrain
	if cells.has(coord):
		return TILE_BUILDING
	return TILE_GRASS


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL OCCUPANTS
# ═══════════════════════════════════════════════════════════════════════════════

func get_occupant(coord: Vector2i) -> Node3D:
	return occupants.get(coord, null)


func set_occupant(coord: Vector2i, node: Node3D) -> void:
	if node == null:
		occupants.erase(coord)
	else:
		occupants[coord] = node


func is_occupied_visual(coord: Vector2i) -> bool:
	return occupants.has(coord)


## Legacy compatibility helper used by GridManager facade.
func set_tile_occupied(coord: Vector2i, occupied: bool, occupant: Node3D = null) -> bool:
	if not is_in_bounds(coord):
		return false
	if occupied:
		# Keep key presence as occupancy marker even when occupant node is null.
		occupants[coord] = occupant
	else:
		occupants.erase(coord)
	return true


## Legacy compatibility helper used by GridManager facade.
func reset_tiles(tile_type: int = TILE_GRASS) -> void:
	occupants.clear()
	tile_types.clear()
	if tile_type == TILE_GRASS:
		return
	for coord in get_all_coords():
		tile_types[coord] = tile_type


func get_tile_view(coord: Vector2i):
	if not is_in_bounds(coord):
		return null
	var tile = TileView.new()
	tile.coord = coord
	tile.world_position = grid_to_world(coord)
	tile.occupied = is_occupied_visual(coord)
	tile.tile_type = get_tile_type(coord)
	var occ = occupants.get(coord, null)
	tile.occupant = occ if occ is Node3D else null
	return tile


## Legacy compatibility helper used by GridManager facade.
func occupy_footprint(origin: Vector2i, footprint: Vector2i, occupant_node: Node3D, tile_type: int = TILE_BUILDING, preserve_reserved: bool = false) -> void:
	for oy in range(footprint.y):
		for ox in range(footprint.x):
			var coord = origin + Vector2i(ox, oy)
			if not is_in_bounds(coord):
				continue
			occupants[coord] = occupant_node
			if preserve_reserved and get_tile_type(coord) == TILE_RESERVED:
				continue
			set_tile_type(coord, tile_type)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILDING STATE (existing API, unchanged)
# ═══════════════════════════════════════════════════════════════════════════════

## Every lamp: lamp posts of their own, and lamps standing at the edge of a path tile
## (the cell stays a path, with "lamp": true).
func lamp_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for coord in cells.keys():
		var cell: Dictionary = cells[coord]
		var t := str(cell.get("type", ""))
		if (t == "lamp_post" and cell.get("root_coord", coord) == coord) or (t == "path" and bool(cell.get("lamp", false))):
			out.append(coord)
	return out


func is_cell_free(coord: Vector2i) -> bool:
	return not cells.has(coord)


func get_cell_data(coord: Vector2i) -> Dictionary:
	return cells.get(coord, {})


func occupy_cell(coord: Vector2i, type: String, id: String, root_coord: Vector2i) -> void:
	cells[coord] = {
		"type": type,
		"id": id,
		"root_coord": root_coord,
		"maintenance": 1.0
	}


func free_cell(coord: Vector2i) -> void:
	cells.erase(coord)


func get_building_at(coord: Vector2i) -> Dictionary:
	var data = get_cell_data(coord)
	if data.is_empty():
		return {}
	return get_cell_data(data.root_coord)


# ═══════════════════════════════════════════════════════════════════════════════
# PLACEMENT VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

## Check if a footprint can be placed. Considers visual occupancy and tile_types.
func can_place_footprint(origin: Vector2i, footprint: Vector2i, allow_reserved: bool = false) -> bool:
	for oy in range(footprint.y):
		for ox in range(footprint.x):
			var coord = origin + Vector2i(ox, oy)
			if not is_in_bounds(coord):
				return false
			if is_occupied_visual(coord):
				return false
			var terrain = tile_types.get(coord, TILE_GRASS)
			if terrain == TILE_LAKE:
				return false
			if terrain == TILE_RESERVED and not allow_reserved:
				return false
	return true


## Occupy a multi-tile footprint (visual layer). Stores occupant node references.
## Does NOT update cells dict — that is done by GameActions.occupy_cell().
func occupy_footprint_visual(origin: Vector2i, footprint: Vector2i, occupant_node: Node3D, _preserve_reserved: bool = false) -> void:
	for oy in range(footprint.y):
		for ox in range(footprint.x):
			var coord = origin + Vector2i(ox, oy)
			if occupant_node != null:
				occupants[coord] = occupant_node


## Clear occupant refs for a footprint (visual layer only).
func free_footprint_visual(origin: Vector2i, footprint: Vector2i) -> void:
	for oy in range(footprint.y):
		for ox in range(footprint.x):
			occupants.erase(origin + Vector2i(ox, oy))
