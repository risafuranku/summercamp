extends Node3D

## The camp's ground, covered (scripts/world_generator.gd): tufts of meadow grass and
## coarse tussocks, dry dead grass, clover, late dandelions, yarrow and thistles, a few
## stones, fallen twigs and spruce cones (Grok sprites, assets/textury/world/spr_*.png),
## thick on the open grass and none on paths or under anything built. Each a sprite on a
## quad turned to you round its upright axis (materials/ground_tuft.gdshader), its top
## leaning with the wind in steps; at the rooms' own pixel (91 px to the metre).
##   - where each one stands comes from the camp's seed and its tile (the same on every
##     co-op machine, the same after a load), not from the world generator's dice;
##   - built in chunks of 8 x 8 tiles, each drawn only within VIEW_M of you;
##   - built again when what stands on the grid changes (built, cleared, a camp loaded):
##     no grass through a floor;
##   - the wind and the season are the world's (the trees' global uniforms: the grass
##     yellows with the leaves, snow lies on it);
##   - what grows takes the ground's colour (the user 20. 10.: the grass sprites did not
##     match the grass): each picture's average brought to the ground picture's average
##     as it is drawn now (season_look.gd's tint, the autumn's picture), its own light and
##     dark kept; the flowers only a little, the stones not at all.

const DIR := "res://assets/textury/world/"
const SHADER = preload("res://materials/ground_tuft.gdshader")
## Kind: picture, height (m), how often (weight), how far it leans in the wind, how far
## it takes the ground's colour.
const KINDS := [
	["spr_tuft_grass_a", 0.46, 30.0, 0.09, 0.9],
	["spr_tuft_grass_b", 0.34, 20.0, 0.06, 0.9],
	["spr_tuft_dry", 0.40, 15.0, 0.08, 0.65],
	["spr_tuft_clover", 0.14, 12.0, 0.01, 0.85],
	["spr_flower_dandelion", 0.30, 6.0, 0.06, 0.25],
	["spr_flower_yarrow", 0.48, 5.0, 0.08, 0.25],
	["spr_thistle", 0.72, 3.0, 0.05, 0.35],
	["spr_stones_small", 0.16, 5.0, 0.0, 0.0],
	["spr_twigs", 0.12, 3.0, 0.0, 0.0],
	["spr_pinecones", 0.10, 1.5, 0.0, 0.0],
]
const PER_TILE := Vector2i(5, 10)
const CHUNK := 8
const VIEW_M := 70.0

var grid: Node
var seed_value := 1
var _mats: Dictionary = {}       # kind name -> ShaderMaterial
var _quad: QuadMesh
var _dirty := false
var _check_t := 0.0
var _occupied_hash := 0
var _tint_t := 0.0
var _ground_key := ""
## A picture's average colour (its opaque pixels), by its path.
var _means: Dictionary = {}


func build(grid_manager: Node, world_seed: int) -> void:
	grid = grid_manager
	seed_value = world_seed
	name = "GroundCover"
	_quad = QuadMesh.new()
	_quad.size = Vector2(1.0, 1.0)
	_quad.center_offset = Vector3(0.0, 0.5, 0.0)
	for k in KINDS:
		var path: String = DIR + str(k[0]) + ".png"
		if not ResourceLoader.exists(path):
			continue
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("tex", load(path))
		m.set_shader_parameter("sway", float(k[3]))
		# Stones, twigs and cones keep their colour; what grows turns with the leaves.
		m.set_shader_parameter("seasonal", 0.0 if float(k[3]) <= 0.0 else 0.55)
		m.set_shader_parameter("ground_match", float(k[4]))
		m.set_meta("mean", _mean_of(m.get_shader_parameter("tex")))
		_mats[str(k[0])] = m
	if not EventBus.BuildConfirmed.is_connected(_on_built):
		EventBus.BuildConfirmed.connect(_on_built)
	if not EventBus.DemolishConfirmed.is_connected(_on_cleared):
		EventBus.DemolishConfirmed.connect(_on_cleared)
	_rebuild()


func _on_built(_t: String, _at: Vector2i, _rot: int) -> void:
	_dirty = true


func _on_cleared(_area: Rect2i, _n: int, _fee: int, _refund: int) -> void:
	_dirty = true


func _process(delta: float) -> void:
	# What stands on the grid (a load puts its buildings back without a word).
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 2.0
		if _occupancy() != _occupied_hash:
			_dirty = true
	_tint_t -= delta
	if _tint_t <= 0.0:
		_tint_t = 2.0
		_match_ground()
	if _dirty:
		_dirty = false
		_rebuild()


## The ground's colour as it is drawn now (the camp's ground: its picture's average times
## its tint), and each picture's way to it.
func _match_ground() -> void:
	var ground: BaseMaterial3D = null
	for n in get_tree().get_nodes_in_group("season_ground"):
		var gi := n as GeometryInstance3D
		if gi != null and not gi.has_meta("season_keep_texture") and gi.material_override is BaseMaterial3D:
			ground = gi.material_override
			break
	if ground == null or ground.albedo_texture == null:
		return
	var key := "%s|%s" % [ground.albedo_texture.resource_path, str(ground.albedo_color)]
	if key == _ground_key:
		return
	_ground_key = key
	var gm: Color = _mean_of(ground.albedo_texture)
	var g := Vector3(gm.r * ground.albedo_color.r, gm.g * ground.albedo_color.g, gm.b * ground.albedo_color.b)
	for m in _mats.values():
		var tm: Color = m.get_meta("mean", Color(0.5, 0.5, 0.5))
		var ratio := Vector3(g.x / maxf(tm.r, 0.02), g.y / maxf(tm.g, 0.02), g.z / maxf(tm.b, 0.02))
		(m as ShaderMaterial).set_shader_parameter("ground_ratio", ratio.clamp(Vector3.ONE * 0.25, Vector3.ONE * 3.0))


func _mean_of(tex: Texture2D) -> Color:
	if tex == null:
		return Color(0.5, 0.5, 0.5)
	var path := tex.resource_path
	if _means.has(path):
		return _means[path]
	var img := tex.get_image()
	if img == null:
		return Color(0.5, 0.5, 0.5)
	if img.is_compressed():
		img.decompress()
	var sum := Vector3.ZERO
	var n := 0
	var step := maxi(1, int(img.get_width() * img.get_height() / 4096))
	var i := 0
	for y in img.get_height():
		for x in img.get_width():
			i += 1
			if i % step != 0:
				continue
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	var out := Color(sum.x / n, sum.y / n, sum.z / n) if n > 0 else Color(0.5, 0.5, 0.5)
	_means[path] = out
	return out


## Which grass tiles have something on them, as one number.
func _occupancy() -> int:
	if grid == null:
		return 0
	var h := 17
	for coord in grid.get_all_coords():
		var tile = grid.get_tile(coord)
		if tile != null and tile.occupied:
			h = hash([h, coord])
	return h


func _rebuild() -> void:
	_occupied_hash = _occupancy()
	# Out at once (the new chunks take the same names).
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if grid == null or _mats.is_empty():
		return
	var weights := 0.0
	for k in KINDS:
		if _mats.has(str(k[0])):
			weights += float(k[2])
	# chunk -> kind -> [Transform3D]
	var chunks: Dictionary = {}
	var size: float = float(grid.get("tile_size"))
	for coord in grid.get_all_coords():
		var tile = grid.get_tile(coord)
		if tile == null or tile.tile_type != grid.TILE_GRASS or tile.occupied:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%d:%d:cover" % [seed_value, coord.x, coord.y])
		var n := rng.randi_range(PER_TILE.x, PER_TILE.y)
		var ck := Vector2i(floori(float(coord.x) / CHUNK), floori(float(coord.y) / CHUNK))
		if not chunks.has(ck):
			chunks[ck] = {}
		var by_kind: Dictionary = chunks[ck]
		var base: Vector3 = tile.world_position
		for _i in n:
			var pick := rng.randf() * weights
			var kind: Array = KINDS[0]
			for k in KINDS:
				if not _mats.has(str(k[0])):
					continue
				pick -= float(k[2])
				if pick <= 0.0:
					kind = k
					break
			var tex: Texture2D = (_mats[str(kind[0])] as ShaderMaterial).get_shader_parameter("tex")
			var h: float = float(kind[1]) * rng.randf_range(0.8, 1.2)
			var w := h * float(tex.get_width()) / maxf(1.0, float(tex.get_height())) if tex != null else h
			var p := base + Vector3(rng.randf_range(-0.48, 0.48) * size, 0.0, rng.randf_range(-0.48, 0.48) * size)
			var b := Basis.IDENTITY.scaled(Vector3(w * (1.0 if rng.randf() < 0.5 else -1.0), h, 1.0))
			if not by_kind.has(str(kind[0])):
				by_kind[str(kind[0])] = []
			(by_kind[str(kind[0])] as Array).append(Transform3D(b, p))
	for ck in chunks.keys():
		var by_kind: Dictionary = chunks[ck]
		for kind in by_kind.keys():
			var list: Array = by_kind[kind]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _quad
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mi := MultiMeshInstance3D.new()
			mi.name = "Cover_%d_%d_%s" % [ck.x, ck.y, kind]
			mi.multimesh = mm
			mi.material_override = _mats[kind]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = VIEW_M
			# The quads turn in the shader: grow the box so the chunk is not culled early.
			mi.extra_cull_margin = 2.0
			add_child(mi)
