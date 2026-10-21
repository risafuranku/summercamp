extends Node3D

## The real land round the camp, 1:1 (geo_data.gd, from OpenStreetMap): the fields, the
## meadows and woods, the ponds and brooks, every road with its asphalt or dust, every
## building of Pristoupim, Liblice and the southern edge of Cesky Brod built from its
## footprint, the trees, the power lines on their poles, the posts along the roads.
## The camp itself is the game's own: nothing real is laid inside its square.
##
## Built by town_trip.gd once (the flat things all at once) and then round your eye in
## chunks (CHUNK m squares): the buildings, trees, poles and fences of the chunks within
## NEAR are made a few at a time each frame and let go past FAR. Places the game builds
## itself (Liblice's centre, the farm at Pristoupim, the stops) clear their ground first
## (clear_area): no real house, tree or fence inside.
##
## The buildings, the Build-engine way: walls of plaster in the village's colours
## standing on a darker plinth, windows that light up of an evening (WINDOW_SHADER), a
## door, sills; gabled roofs of red tiles or grey eternit along a house's long side, hips
## on squarer ones, an L-shaped house a roof on each wing; a chimney with its cap and
## often a TV aerial on its pole. Barns, sheds, garages, the works by the road: plainer.

const GEO = preload("res://scripts/geo/geo_data.gd")
const ROAD_POST = preload("res://scripts/town/road_post.gd")
const PUMP_JOB = preload("res://scripts/town/pump_job.gd")
const TEX := "res://assets/textury/town/"
const TEX_CAMP := "res://assets/textury/camp/"
const CHUNK := 250.0
const NEAR := 950.0
const FAR := 1350.0
## Microseconds a frame for making chunks.
const BUDGET := 4000
## The game's camp (its fenced square, the lake band, the gate's road): the real map
## is not laid here (x, z, width, depth).
const CAMP := Rect2(-80.0, -80.0, 160.0, 175.0)
## The whole of it (x, z, width, depth).
const AREA := Rect2(-900.0, -1950.0, 4300.0, 2950.0)

const WINDOW_SHADER := """
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform sampler2D tex : source_color, filter_nearest;
uniform float lit = 0.0;
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	// COLOR.a is the window's own dice: those under `lit` are on tonight; the dark
	// glass of the picture glows, the frame does not.
	float on = step(COLOR.a, lit);
	float glass = 1.0 - smoothstep(0.32, 0.5, dot(t.rgb, vec3(0.333)));
	EMISSION = vec3(1.0, 0.74, 0.4) * on * glass * 1.4;
}
"""

## Houses' plaster and roofs: the colours a village was painted in.
const WALLS := [Color(0.97, 0.96, 0.92), Color(0.98, 0.9, 0.74), Color(0.93, 0.8, 0.55), Color(0.95, 0.8, 0.74),
	Color(0.82, 0.82, 0.8), Color(0.96, 0.92, 0.62), Color(0.84, 0.9, 0.78), Color(0.74, 0.73, 0.7), Color(0.9, 0.86, 0.8)]
const ROOFS := [Color(0.82, 0.46, 0.36), Color(0.66, 0.36, 0.28), Color(0.58, 0.4, 0.32), Color(0.74, 0.5, 0.38)]

var worldgen: Node
var _data: Dictionary
var _mats: Dictionary = {}
var _window_mats: Array[ShaderMaterial] = []
var _chunks: Dictionary = {}       # Vector2i -> Node3D (built)
var _queue: Array[Vector2i] = []
var _index: Dictionary = {}        # Vector2i -> {"b": [...], "wood": [...], "res": [...], "rows": [...], "power": [...], "fence": [...], "road": [...]}
var _clear: Array = []             # PackedVector2Array: the game's own places
var _residential: Array = []       # PackedVector2Array: villages (no road posts inside)
var _eye := Vector3.ZERO
## Lojza's side job at the Benzina by the camp's turn (pump_job.gd), and the station's
## middle (town_trip ends the shift when you walk off from it).
var pump_job
var benzina_at := Vector3.INF
var _lojza: Node3D
var _lit := 0.0


func build(p_worldgen: Node) -> void:
	name = "GeoWorld"
	worldgen = p_worldgen
	_data = GEO.data()
	if _data.is_empty():
		push_warning("geo: no data/geo/world.json")
		return
	_make_index()
	_keep_lake_clear()
	_hide_horizon_hills()
	_ground()
	_land()
	_water()
	_roads()
	_benzina()
	_village_signs()


## No real buildings, trees or fences inside `poly` (world xz): a place the game builds
## itself. Chunks already made there are made again.
func clear_area(poly: PackedVector2Array) -> void:
	_clear.append(poly)
	var r := _poly_rect(poly)
	for key in _chunks.keys():
		if _chunk_rect(key).intersects(r):
			(_chunks[key] as Node).queue_free()
			_chunks.erase(key)


## Every frame: the chunks round `eye` (world position) made or let go.
func update(eye: Vector3) -> void:
	_eye = eye
	var c := _chunk_of(Vector2(eye.x, eye.z))
	var reach := int(ceil(NEAR / CHUNK))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := c + Vector2i(dx, dz)
			if _chunks.has(key) or _queue.has(key) or not _index.has(key):
				continue
			if _chunk_rect(key).get_center().distance_to(Vector2(eye.x, eye.z)) < NEAR:
				_queue.append(key)
	for key in _chunks.keys():
		if _chunk_rect(key).get_center().distance_to(Vector2(eye.x, eye.z)) > FAR:
			(_chunks[key] as Node).queue_free()
			_chunks.erase(key)
	if _queue.is_empty():
		return
	_queue.sort_custom(func(a, b): return _chunk_rect(a).get_center().distance_squared_to(Vector2(eye.x, eye.z)) < _chunk_rect(b).get_center().distance_squared_to(Vector2(eye.x, eye.z)))
	var t0 := Time.get_ticks_usec()
	while not _queue.is_empty() and Time.get_ticks_usec() - t0 < BUDGET:
		var key: Vector2i = _queue.pop_front()
		_chunks[key] = _make_chunk(key)


## Builds every chunk round `eye` at once (a test, a teleport).
func build_all_near(eye: Vector3) -> void:
	update(eye)
	while not _queue.is_empty():
		var key: Vector2i = _queue.pop_front()
		_chunks[key] = _make_chunk(key)


## The windows of an evening: how many are lit at hour `h`.
func set_hour(h: float) -> void:
	var lit := 0.0
	if h >= 17.0 and h < 23.5:
		lit = clampf((h - 17.0) / 2.0, 0.0, 0.75) - clampf((h - 21.5) / 2.0, 0.0, 0.6)
	elif h >= 5.0 and h < 7.0:
		lit = 0.3
	if absf(lit - _lit) > 0.01:
		_lit = lit
		for m in _window_mats:
			m.set_shader_parameter("lit", lit)
	# Lojza is at his pumps while the Benzina is open (6 - 21).
	if _lojza != null:
		var there := h >= 6.0 and h < 21.0
		if _lojza.visible != there:
			_lojza.visible = there
			var body := _lojza.get_node_or_null("Body") as StaticBody3D
			if body != null:
				body.collision_layer = 1 if there else 0


# ── the index: what lies in which chunk ──────────────────────────────────────

func _chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK)), int(floor(p.y / CHUNK)))


func _chunk_rect(key: Vector2i) -> Rect2:
	return Rect2(Vector2(key) * CHUNK, Vector2(CHUNK, CHUNK))


func _poly_rect(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


func _add(key: Vector2i, what: String, i: int) -> void:
	if not _index.has(key):
		_index[key] = {}
	var d: Dictionary = _index[key]
	if not d.has(what):
		d[what] = []
	(d[what] as Array).append(i)


## Polygons and lines go into every chunk their box touches; buildings into the one
## their middle is in.
func _add_spread(r: Rect2, what: String, i: int) -> void:
	var a := _chunk_of(r.position)
	var b := _chunk_of(r.end)
	for z in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			_add(Vector2i(x, z), what, i)


func _make_index() -> void:
	var bs: Array = _data.get("buildings", [])
	for i in bs.size():
		var poly := GEO.pts(bs[i]["p"])
		var c := _poly_rect(poly).get_center()
		_add(_chunk_of(c), "b", i)
	var land: Array = _data.get("land", [])
	for i in land.size():
		var k := str(land[i]["k"])
		var poly := GEO.pts(land[i]["p"])
		if k in ["wood", "scrub", "orchard"]:
			_add_spread(_poly_rect(poly), "wood", i)
		elif k in ["residential", "gardens", "farmyard", "green", "cemetery"]:
			_add_spread(_poly_rect(poly), "res", i)
			if k == "residential":
				_residential.append(poly)
	var rows: Array = _data.get("tree_rows", [])
	for i in rows.size():
		_add_spread(_poly_rect(GEO.pts(rows[i]["p"])), "rows", i)
	var power: Array = _data.get("power", [])
	for i in power.size():
		_add_spread(_poly_rect(GEO.pts(power[i]["p"])), "power", i)
	var fences: Array = _data.get("fences", [])
	for i in fences.size():
		_add_spread(_poly_rect(GEO.pts(fences[i]["p"])), "fence", i)
	var roads: Array = _data.get("roads", [])
	for i in roads.size():
		_add_spread(_poly_rect(GEO.pts(roads[i]["p"])), "road", i)
	var trees: Array = _data.get("trees", [])
	for i in range(0, trees.size(), 2):
		_add(_chunk_of(Vector2(float(trees[i]), float(trees[i + 1]))), "tree", i)


func _cleared(p: Vector2) -> bool:
	if CAMP.has_point(p):
		return true
	for poly in _clear:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func _in_village(p: Vector2) -> bool:
	for poly in _residential:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


# ── materials ────────────────────────────────────────────────────────────────

func _mat(path: String, tint := Color.WHITE, two_sided := false, cut := false) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [path, tint, two_sided, cut]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.vertex_color_use_as_albedo = true
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if cut:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	_mats[key] = m
	return m


func _first(paths: Array) -> String:
	for p in paths:
		if ResourceLoader.exists(str(p)):
			return str(p)
	return ""


func _window_mat(path: String) -> ShaderMaterial:
	var key := "win|" + path
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WINDOW_SHADER
	m.shader = sh
	if ResourceLoader.exists(path):
		m.set_shader_parameter("tex", load(path))
	m.set_shader_parameter("lit", _lit)
	_mats[key] = m
	_window_mats.append(m)
	return m


# ── a bag of triangles per material ──────────────────────────────────────────

class Bag:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()

	## A triangle facing `nrm` (Godot's front faces are clockwise seen from the front).
	func tri(a: Vector3, b: Vector3, c: Vector3, nrm: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, color: Color) -> void:
		if (b - a).cross(c - a).dot(nrm) > 0.0:
			var t := b
			b = c
			c = t
			var tu := ub
			ub = uc
			uc = tu
		v.append(a)
		v.append(b)
		v.append(c)
		uv.append(ua)
		uv.append(ub)
		uv.append(uc)
		for k in 3:
			n.append(nrm)
			col.append(color)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, color: Color) -> void:
		tri(a, b, c, nrm, ua, ub, uc, color)
		tri(a, c, d, nrm, ua, uc, ud, color)

	## A wall quad from `p0` to `p1` (xz) between heights y0 and y1, facing `nrm`, its
	## texture `tile` metres a repeat, starting `u0` along.
	func wall(p0: Vector2, p1: Vector2, y0: float, y1: float, nrm: Vector3, tile: Vector2, color: Color, u0 := 0.0) -> void:
		var len := p0.distance_to(p1)
		var a := Vector3(p0.x, y0, p0.y)
		var b := Vector3(p1.x, y0, p1.y)
		var c := Vector3(p1.x, y1, p1.y)
		var d := Vector3(p0.x, y1, p0.y)
		quad(a, b, c, d, nrm, Vector2(u0 / tile.x, -y0 / tile.y), Vector2((u0 + len) / tile.x, -y0 / tile.y),
			Vector2((u0 + len) / tile.x, -y1 / tile.y), Vector2(u0 / tile.x, -y1 / tile.y), color)

	## A box (all six sides) centred at `c`, turned `yaw` about y.
	func box(c: Vector3, size: Vector3, yaw: float, color: Color, tile := 1.0) -> void:
		var bx := Basis(Vector3.UP, yaw)
		var h := size * 0.5
		var corners := []
		for s in [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]:
			corners.append(c + bx * (h * s))
		var faces := [[0, 1, 2, 3, Vector3.DOWN], [4, 5, 6, 7, Vector3.UP], [0, 1, 5, 4, Vector3.FORWARD], [3, 2, 6, 7, Vector3.BACK], [0, 3, 7, 4, Vector3.LEFT], [1, 2, 6, 5, Vector3.RIGHT]]
		for f in faces:
			var nrm: Vector3 = bx * (f[4] as Vector3)
			quad(corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]], nrm, Vector2(0, 0), Vector2(tile, 0), Vector2(tile, tile), Vector2(0, tile), color)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = col
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


func _bags_to(parent: Node3D, bags: Dictionary, range_end := 0.0) -> void:
	for key in bags.keys():
		var bag: Bag = bags[key][0]
		if bag.v.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = bag.mesh()
		mi.material_override = bags[key][1]
		if range_end > 0.0:
			mi.visibility_range_end = range_end
		parent.add_child(mi)


func _bag(bags: Dictionary, key: String, mat: Material) -> Bag:
	if not bags.has(key):
		bags[key] = [Bag.new(), mat]
	return bags[key][0]


# ── the flat things, once ────────────────────────────────────────────────────

## Grass under all of it (the land's patches lie on it), and floors to walk on round
## the camp's own square.
func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = AREA.size + Vector2(800.0, 800.0)
	g.mesh = pm
	g.position = Vector3(AREA.get_center().x, -0.08, AREA.get_center().y)
	var m := _mat(_first([TEX + "meadow.png", TEX_CAMP + "pitch_grass.png"]), Color(0.8, 0.86, 0.66)).duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(pm.size.x / 6.0, pm.size.y / 6.0, 1.0)
	m.vertex_color_use_as_albedo = false
	g.material_override = m
	g.add_to_group("season_ground")
	add_child(g)
	# Floors: the area less the camp's map (its own ground and lake are the game's).
	var camp := _camp_map_rect()
	var a := AREA.grow(400.0)
	for r in [Rect2(a.position.x, a.position.y, a.size.x, camp.position.y - a.position.y),
			Rect2(a.position.x, camp.end.y, a.size.x, a.end.y - camp.end.y),
			Rect2(a.position.x, camp.position.y, camp.position.x - a.position.x, camp.size.y),
			Rect2(camp.end.x, camp.position.y, a.end.x - camp.end.x, camp.size.y)]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x, 1.0, r.size.y)
		shape.shape = box
		body.add_child(shape)
		body.position = Vector3(r.get_center().x, -0.5, r.get_center().y)
		add_child(body)


## The camp's lake reaches past its fenced map (camp_lake.gd): its water, its shore and
## reeds and Mr Hruby's boathouse behind the far shore are the game's. No real house,
## tree or fence in them, nor a little way round (the village's houses stood in the water
## and through the boathouse, and the boat came alongside a gable).
func _keep_lake_clear() -> void:
	var lake = worldgen.get("_lake_poly") if worldgen != null else null
	if lake is PackedVector2Array and (lake as PackedVector2Array).size() > 2:
		var grown := Geometry2D.offset_polygon(lake, 12.0)
		if not grown.is_empty():
			_clear.append(grown[0])


## The camp generator's made-up hills on the horizon: the real land is here instead.
func _hide_horizon_hills() -> void:
	if worldgen == null:
		return
	worldgen.set("horizon_hills", false)
	var terrain = worldgen.get("_terrain_root")
	var horizon: Node = terrain.get_node_or_null("Horizon") if terrain is Node else null
	if horizon == null:
		return
	for n in horizon.get_children():
		if str(n.name).begins_with("Hill"):
			(n as Node3D).visible = false


## The camp's fenced map (and the band of its lake), from the world generator.
func _camp_map_rect() -> Rect2:
	var gm = worldgen.get("_grid_manager") if worldgen != null else null
	if gm != null and gm.has_method("get_map_size_world"):
		var size: Vector2 = gm.get_map_size_world()
		return Rect2(-size * 0.5, size)
	return Rect2(-56.0, -56.0, 112.0, 112.0)


## Fields, meadows, woods' floors, gardens: the land's patches, one mesh per kind of
## ground (a field's furrows run its own way).
func _land() -> void:
	var bags := {}
	var land: Array = _data.get("land", [])
	var order := {"farmland": 0.004, "meadow": 0.008, "grass": 0.012, "orchard": 0.012, "wetland": 0.012, "scrub": 0.014,
		"wood": 0.016, "residential": 0.006, "gardens": 0.018, "green": 0.02, "farmyard": 0.02, "cemetery": 0.02,
		"pitch": 0.022, "industrial": 0.01}
	for i in land.size():
		var k := str(land[i]["k"])
		var poly := GEO.pts(land[i]["p"])
		var tex := ""
		var tint := Color.WHITE
		var tile := 10.0
		match k:
			"farmland":
				var pick := hash(int(land[i].get("id", i))) % 5
				tex = [TEX + "field_plough.png", TEX + "field_stubble.png", TEX + "field_plough.png", TEX + "field_stubble.png", TEX + "meadow.png"][pick]
				tint = [Color(0.86, 0.8, 0.72), Color(1.0, 1.0, 0.94), Color(0.78, 0.72, 0.64), Color(0.96, 0.92, 0.82), Color(0.74, 0.86, 0.56)][pick]
				tile = 14.0
			"meadow", "grass", "orchard", "pitch":
				tex = TEX + "meadow.png"
				tint = Color(0.82, 0.9, 0.66) if k != "pitch" else Color(0.7, 0.86, 0.56)
			"wetland":
				tex = TEX + "meadow.png"
				tint = Color(0.62, 0.72, 0.56)
			"wood", "scrub":
				tex = _first([TEX + "forest_floor.png", TEX + "meadow.png"])
				tint = Color(0.9, 0.9, 0.86)
				tile = 8.0
			"residential", "gardens", "green", "cemetery":
				tex = _first([TEX + "village_grass.png", TEX + "meadow.png"])
				tint = Color(0.86, 0.92, 0.74) if k != "cemetery" else Color(0.7, 0.8, 0.62)
				tile = 8.0
			"farmyard":
				tex = _first([TEX + "dirt_path.png", TEX_CAMP + "gravel_road.png"])
				tint = Color(0.9, 0.86, 0.8)
				tile = 5.0
			"industrial":
				tex = _first([TEX + "turnaround.png", TEX_CAMP + "concrete.png"])
				tint = Color(0.8, 0.8, 0.78)
				tile = 8.0
		var key := "%s|%s" % [tex, tint]
		var bag := _bag(bags, key, _mat(tex, tint))
		_fill_poly(bag, poly, float(order.get(k, 0.01)), tile, Color.WHITE)
	_bags_to(self, bags)


## A polygon lying flat at height y, its texture `tile` metres a repeat.
func _fill_poly(bag: Bag, poly: PackedVector2Array, y: float, tile: float, color: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		# Self-touching rings do not triangulate: their convex hull will do.
		poly = Geometry2D.convex_hull(poly)
		idx = Geometry2D.triangulate_polygon(poly)
	for t in range(0, idx.size(), 3):
		var a := poly[idx[t]]
		var b := poly[idx[t + 1]]
		var c := poly[idx[t + 2]]
		bag.tri(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3.UP, a / tile, b / tile, c / tile, color)


## The ponds and the brooks.
func _water() -> void:
	var bags := {}
	var m := _mat(_first([TEX_CAMP + "lake_water.png", TEX + "meadow.png"]), Color(0.52, 0.6, 0.62))
	var bag := _bag(bags, "water", m)
	for w in _data.get("water", []):
		_fill_poly(bag, GEO.pts(w["p"]), 0.03, 9.0, Color.WHITE)
	var bank := _bag(bags, "bank", _mat(_first([TEX + "dirt_path.png", TEX_CAMP + "gravel_road.png"]), Color(0.7, 0.66, 0.56)))
	for w in _data.get("water", []):
		_strip(bank, GEO.pts(w["p"]), 1.6, 0.025, 3.0, true)
	for s in _data.get("streams", []):
		_strip(bag, GEO.pts(s["p"]), float(s.get("w", 1.6)), 0.028, 4.0)
	_bags_to(self, bags)


## A strip `width` wide along a polyline at height y (closed: back to its start).
func _strip(bag: Bag, line: PackedVector2Array, width: float, y: float, tile: float, closed := false, color := Color.WHITE) -> void:
	if closed and line.size() > 2:
		line = line.duplicate()
		line.append(line[0])
	var acc := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var d := (b - a)
		var len := d.length()
		if len < 0.05:
			continue
		d /= len
		var side := Vector2(-d.y, d.x) * width * 0.5
		# Lengthen each piece a little so the joints overlap instead of gaping.
		var ext := d * minf(width * 0.5, 2.0)
		var a2 := a - ext if i > 0 else a
		var b2 := b + ext if i < line.size() - 2 else b
		bag.quad(Vector3(a2.x - side.x, y, a2.y - side.y), Vector3(a2.x + side.x, y, a2.y + side.y),
			Vector3(b2.x + side.x, y, b2.y + side.y), Vector3(b2.x - side.x, y, b2.y - side.y), Vector3.UP,
			Vector2(0, acc / tile), Vector2(1, acc / tile), Vector2(1, (acc + len) / tile), Vector2(0, (acc + len) / tile), color)
		acc += len


## Every road: asphalt (patched, in the village's grey) or dust; road 12 with its white
## lines; the bigger road on top where two cross.
func _roads() -> void:
	var bags := {}
	var asphalt := _mat(_first([TEX + "asphalt.png", TEX_CAMP + "gravel_road.png"]), Color(0.66, 0.66, 0.68))
	var dust := _mat(_first([TEX + "road_gravel.png", TEX + "dirt_path.png"]), Color(0.86, 0.8, 0.7))
	var paint := _mat("", Color(0.9, 0.88, 0.8))
	var rank := {"primary": 0.075, "secondary": 0.07, "tertiary": 0.066, "unclassified": 0.062, "residential": 0.058,
		"living_street": 0.056, "service": 0.052, "track": 0.048, "footway": 0.044, "path": 0.042, "cycleway": 0.044, "steps": 0.044, "pedestrian": 0.05}
	# Nothing real inside the camp's fence: a field track of the map ran straight across
	# it, a dirt road through the tents the Builder knew nothing of (the user, 21. 10.).
	var camp := _camp_map_rect()
	for r in _data.get("roads", []):
		var c := str(r["c"])
		var y := float(rank.get(c, 0.05))
		var w := float(r["w"])
		var dirt := int(r.get("d", 0)) == 1
		for line in _outside(GEO.pts(r["p"]), camp.grow(w * 0.7)):
			if line.size() < 2:
				continue
			_strip(_bag(bags, "dust" if dirt else "asphalt", dust if dirt else asphalt), line, w, y, w * 1.4)
			if c == "primary":
				_road_lines(_bag(bags, "paint", paint), line, w, y + 0.004)
	_bags_to(self, bags)


## The pieces of a line outside `rect` (each segment cut where it crosses the edge).
func _outside(line: PackedVector2Array, rect: Rect2) -> Array:
	var out: Array = []
	var cur := PackedVector2Array()
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		# Where the segment is inside: t0..t1 (Liang-Barsky), or none.
		var t0 := 0.0
		var t1 := 1.0
		var d := b - a
		var hit := true
		for k in 4:
			var p: float = [-d.x, d.x, -d.y, d.y][k]
			var q: float = [a.x - rect.position.x, rect.end.x - a.x, a.y - rect.position.y, rect.end.y - a.y][k]
			if absf(p) < 1e-6:
				if q < 0.0:
					hit = false
					break
			else:
				var t := q / p
				if p < 0.0:
					t0 = maxf(t0, t)
				else:
					t1 = minf(t1, t)
		if hit and t0 < t1:
			if t0 > 0.0:
				if cur.is_empty():
					cur.append(a)
				cur.append(a + d * t0)
			if cur.size() >= 2:
				out.append(cur)
			cur = PackedVector2Array()
			if t1 < 1.0:
				cur.append(a + d * t1)
				cur.append(b)
		else:
			if cur.is_empty():
				cur.append(a)
			cur.append(b)
	if cur.size() >= 2:
		out.append(cur)
	return out


## Road 12's paint: a dashed line in the middle, a line along each edge.
func _road_lines(bag: Bag, line: PackedVector2Array, w: float, y: float) -> void:
	var acc := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var len := a.distance_to(b)
		if len < 0.1:
			continue
		var d := (b - a) / len
		var side := Vector2(-d.y, d.x)
		var s := 0.0
		while s < len:
			var t := fposmod(acc + s, 9.0)
			if t < 3.0:
				var e := minf(len, s + (3.0 - t))
				_flat_quad(bag, a + d * s, a + d * e, side, 0.0, 0.12, y)
				s = e
			else:
				s += 9.0 - t
		for edge in [-1.0, 1.0]:
			_flat_quad(bag, a, b, side, edge * (w * 0.5 - 0.35), 0.12, y)
		acc += len


func _flat_quad(bag: Bag, a: Vector2, b: Vector2, side: Vector2, off: float, width: float, y: float) -> void:
	var p := side * off
	var h := side * width * 0.5
	bag.quad(Vector3(a.x + p.x - h.x, y, a.y + p.y - h.y), Vector3(a.x + p.x + h.x, y, a.y + p.y + h.y),
		Vector3(b.x + p.x + h.x, y, b.y + p.y + h.y), Vector3(b.x + p.x - h.x, y, b.y + p.y - h.y), Vector3.UP,
		Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN, Color.WHITE)


# ── the game's own things in the real land ──────────────────────────────────

## The petrol station at the camp's turn off road 12, where the Orlen is now: as it was,
## a state Benzina, its white canopy on four pillars with the red fascia and BENZINA
## in metal letters, two pumps on their islands, the kiosk behind with its price board
## on a pole, the forecourt stained with oil.
func _benzina() -> void:
	var at := Vector3.INF
	for f in _data.get("fuel", []):
		if str(f.get("n", "")).begins_with("Orlen"):
			at = Vector3(float(f["p"][0]), 0, float(f["p"][1]))
	if at == Vector3.INF:
		return
	# It faces road 12 (the canopy's front, -z, towards it), its pumps along the road,
	# the kiosk behind; a little nearer the road than OSM's point (that is the kiosk).
	var road_at: Vector3 = GEO.at(float(GEO.nearest(at)["s"]))["p"]
	var face := (road_at - at) * Vector3(1, 0, 1)
	face = face.normalized() if face.length() > 0.1 else Vector3.FORWARD
	at += face * minf(10.0, maxf(0.0, (road_at - at).length() - 22.0))
	_clear.append(PackedVector2Array([Vector2(at.x - 26, at.z - 22), Vector2(at.x + 26, at.z - 22), Vector2(at.x + 26, at.z + 22), Vector2(at.x - 26, at.z + 22)]))
	var root := Node3D.new()
	root.name = "Benzina"
	root.position = at
	root.rotation.y = atan2(-face.x, -face.z)
	add_child(root)
	var bags := {}
	var steel := _bag(bags, "steel", _mat("", Color(0.86, 0.86, 0.84)))
	var red := _bag(bags, "red", _mat("", Color(0.8, 0.12, 0.08)))
	var conc := _bag(bags, "conc", _mat(TEX_CAMP + "concrete.png", Color(0.92, 0.92, 0.9)))
	var dark := _bag(bags, "dark", _mat("", Color(0.3, 0.3, 0.3)))
	var fore := _bag(bags, "fore", _mat(_first([TEX + "turnaround.png", TEX + "asphalt.png"]), Color(0.8, 0.8, 0.78)))
	_fill_poly(fore, PackedVector2Array([Vector2(-20, -14), Vector2(20, -14), Vector2(20, 14), Vector2(-20, 14)]), 0.09, 8.0, Color.WHITE)
	for p in [Vector2(-6, -3), Vector2(6, -3), Vector2(-6, 3), Vector2(6, 3)]:
		steel.box(Vector3(p.x, 2.4, p.y), Vector3(0.3, 4.8, 0.3), 0.0, Color.WHITE)
	conc.box(Vector3(0, 5.0, 0), Vector3(14.0, 0.5, 8.0), 0.0, Color.WHITE, 3.0)
	# The fascia deep enough for the letters, red all round.
	red.box(Vector3(0, 4.95, -4.03), Vector3(14.1, 0.9, 0.06), 0.0, Color.WHITE)
	red.box(Vector3(0, 4.95, 4.03), Vector3(14.1, 0.9, 0.06), 0.0, Color.WHITE)
	red.box(Vector3(-7.03, 4.95, 0), Vector3(0.06, 0.9, 8.0), 0.0, Color.WHITE)
	red.box(Vector3(7.03, 4.95, 0), Vector3(0.06, 0.9, 8.0), 0.0, Color.WHITE)
	for x in [-2.6, 2.6]:
		conc.box(Vector3(x, 0.15, 0), Vector3(1.4, 0.2, 3.0), 0.0, Color.WHITE)
		red.box(Vector3(x, 1.0, 0), Vector3(0.9, 1.7, 0.6), 0.0, Color.WHITE)
	conc.box(Vector3(0, 1.6, 9.0), Vector3(10.0, 3.2, 6.0), 0.0, Color.WHITE, 3.0)
	dark.box(Vector3(0, 3.3, 9.0), Vector3(10.4, 0.2, 6.4), 0.0, Color.WHITE)
	dark.box(Vector3(-11.0, 3.0, -2.0), Vector3(0.18, 6.0, 0.18), 0.0, Color.WHITE)
	_bags_to(root, bags)
	for x in [-2.6, 2.6]:
		for side in [-1.0, 1.0]:
			_picture(root, TEX + "fuel_pump.png", Vector3(x, 1.0, 0.31 * side), Vector2(0.9, 1.7), Vector3(0, 0, side))
	_picture(root, TEX + "kiosk_front.png", Vector3(0, 1.6, 5.98), Vector2(5.7, 3.2), Vector3(0, 0, -1))
	_picture(root, TEX + "sign_benzina.png", Vector3(0, 4.95, -4.07), Vector2(4.4, 0.82), Vector3(0, 0, -1))
	_picture(root, TEX + "sign_benzina.png", Vector3(0, 4.95, 4.07), Vector2(4.4, 0.82), Vector3(0, 0, 1))
	# The price board on its pole: white, the prices in black.
	var plate := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.3)
	plate.mesh = q
	plate.material_override = _mat("", Color(0.94, 0.94, 0.9))
	plate.position = Vector3(-11.0, 4.6, -2.1)
	plate.rotation.y = PI
	root.add_child(plate)
	var board := Label3D.new()
	board.text = "BENZINA\nSPECIAL  21,90\nNATURAL  23,40\nNAFTA  19,80"
	board.font = load("res://assets/fonts/jersey10.fnt")
	board.font_size = 32
	board.pixel_size = 0.006
	board.outline_size = 0
	board.modulate = Color(0.08, 0.08, 0.1)
	board.double_sided = false
	board.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	board.position = Vector3(-11.0, 4.6, -2.12)
	board.rotation.y = PI
	root.add_child(board)
	var body := StaticBody3D.new()
	root.add_child(body)
	for b in [[Vector3(0, 1.6, 9.0), Vector3(10.0, 3.2, 6.0)], [Vector3(-2.6, 1.0, 0), Vector3(1.4, 2.0, 3.0)], [Vector3(2.6, 1.0, 0), Vector3(1.4, 2.0, 3.0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		shape.shape = box
		shape.position = b[0]
		body.add_child(shape)
	benzina_at = at
	_benzina_job(root, (root.transform.affine_inverse() * road_at).z)


## Lojza's job at this Benzina: the cars' ways in off road 12 and out again (in the
## station's frame: road 12 runs along x at `road_z`, the canopy faces it), the pumps to
## click, and Lojza himself between them.
func _benzina_job(root: Node3D, road_z: float) -> void:
	# Cars drive along +x on the station's side of the road (it is on their right), turn
	# in at the forecourt's corner, stop beside an island, drive on past the kiosk's
	# front and back out to the road the same way.
	var lane := road_z + 1.6
	var stops: Array = []
	var ins: Array = []
	var outs: Array = []
	for cx: float in [-4.3, 4.3]:
		var stop := Vector3(cx, 0, 0.3)
		stops.append(stop)
		ins.append([Vector3(-110.0, 0, lane), Vector3(-22.0, 0, lane), Vector3(-12.0, 0, -15.0), Vector3(cx, 0, -8.0), Vector3(cx, 0, -3.0), stop])
		outs.append([Vector3(cx, 0, 4.6), Vector3(11.0, 0, 4.6), Vector3(13.0, 0, -2.0), Vector3(13.0, 0, -14.0), Vector3(22.0, 0, lane), Vector3(110.0, 0, lane)])
	pump_job = PUMP_JOB.new()
	pump_job.name = "PumpJob"
	root.add_child(pump_job)
	pump_job.setup(stops, ins, outs)
	# The pumps to click (bigger than their islands, so the click finds them first).
	for i in 2:
		var click := StaticBody3D.new()
		click.collision_layer = 1 << 11
		click.collision_mask = 0
		click.set_meta("building_type", "trip_pump")
		click.set_meta("pump", i)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 2.2, 3.2)
		shape.shape = box
		click.add_child(shape)
		click.position = Vector3(-2.6 if i == 0 else 2.6, 1.1, 0)
		root.add_child(click)
	# Lojza, between his pumps (the Grok billboard the village had him as).
	var path := "res://assets/textury/npc/town_pumpar.png"
	if not ResourceLoader.exists(path):
		return
	_lojza = Node3D.new()
	_lojza.name = "Lojza"
	_lojza.position = Vector3(0.2, 0, 0.8)
	root.add_child(_lojza)
	var s := Sprite3D.new()
	s.texture = load(path)
	s.pixel_size = 0.0145
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.offset = Vector2(0, s.texture.get_height() * 0.5)
	_lojza.add_child(s)
	var who := StaticBody3D.new()
	who.name = "Body"
	who.set_meta("building_type", "trip_lojza")
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	cap.shape = capsule
	cap.position = Vector3(0, 0.9, 0)
	who.add_child(cap)
	_lojza.add_child(who)


## A picture on a quad (its own size from the texture at 48 px a metre when `size` is
## zero), cut out by its alpha, facing `facing` (in the parent's frame).
func _picture(parent: Node3D, path: String, pos: Vector3, size: Vector2, facing: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size if size != Vector2.ZERO else Vector2(tex.get_width(), tex.get_height()) / 48.0
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(mi)


## The villages' white name plates where the 380 comes in: Pristoupim off road 12,
## Liblice at the top of Pristoupimska.
func _village_signs() -> void:
	var r12b := GEO.s_near(Vector3(2228.0, 0, 17.0))
	for s in [[r12b + 45.0, "obec_pristoupim"], [GEO.stop_s("liblice") - 235.0, "obec"]]:
		var a := GEO.at(float(s[0]), 5.2)
		var p: Vector3 = a["p"]
		var dir: Vector3 = a["dir"]
		var root := Node3D.new()
		root.position = p
		add_child(root)
		var bags := {}
		_bag(bags, "pole", _mat("", Color(0.45, 0.47, 0.45))).box(Vector3(0, 1.1, 0), Vector3(0.07, 2.2, 0.07), 0.0, Color.WHITE)
		_bags_to(root, bags)
		_picture(root, TEX + "sign_%s.png" % str(s[1]), Vector3(0, 1.95, 0) - dir * 0.05, Vector2.ZERO, -dir)


# ── a chunk: buildings, trees, poles, fences ─────────────────────────────────

func _make_chunk(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(root)
	var d: Dictionary = _index.get(key, {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var bags := {}
	var body := StaticBody3D.new()
	root.add_child(body)
	var blocked: Array = []   # Rect2 round each building, for the trees
	var bs: Array = _data.get("buildings", [])
	for i in d.get("b", []):
		var poly := GEO.pts(bs[i]["p"])
		var r := _poly_rect(poly)
		if _cleared(r.get_center()):
			continue
		blocked.append(r.grow(1.5))
		_building(bags, body, bs[i], poly, rng)
	_trees(root, key, d, rng, blocked)
	_power(bags, key, d)
	_fences(bags, key, d)
	_posts(root, key, d)
	_bags_to(root, bags, FAR)
	return root


## One building from its footprint.
func _building(bags: Dictionary, body: StaticBody3D, b: Dictionary, poly: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var kind := str(b.get("k", "yes"))
	var area := absf(_signed_area(poly))
	var levels := int(b.get("lv", 0))
	var height := float(b.get("h", 0.0))
	var dice := RandomNumberGenerator.new()
	dice.seed = int(b.get("id", 0))
	var wall_h := 3.3
	var roof := "gable"
	var windows := true
	var house := false
	match kind:
		"garage", "garages", "shed", "carport", "kiosk", "hut":
			wall_h = 2.5
			roof = "flat"
			windows = false
		"industrial", "warehouse", "commercial", "retail", "factory", "service", "transportation", "manufacture":
			wall_h = 6.5 if area > 300.0 else 4.5
			roof = "flat" if area > 600.0 else "low"
		"barn", "farm_auxiliary", "cowshed", "stable", "agricultural", "greenhouse":
			wall_h = 4.2
			windows = false
		"church", "chapel":
			wall_h = 8.0
		"school", "civic", "hospital", "public", "hotel", "office", "kindergarten", "government", "apartments":
			wall_h = 7.0 if area < 600.0 else 10.0
			roof = "hip"
		_:
			house = true
			wall_h = 3.2 if area < 130.0 else 5.8
			if dice.randf() < 0.18 and area < 160.0 and area > 70.0:
				wall_h = 5.8
	if levels > 0:
		wall_h = 2.9 * float(levels) + 0.3
	if height > 0.0:
		wall_h = maxf(2.4, height * 0.75)
	var wall_col: Color = WALLS[dice.randi() % WALLS.size()] if house else Color(0.84, 0.82, 0.78)
	if kind in ["barn", "farm_auxiliary", "cowshed", "stable", "agricultural"]:
		wall_col = Color(0.9, 0.78, 0.66) if dice.randf() < 0.5 else Color(0.8, 0.8, 0.76)
	var eternit := dice.randf() < 0.28
	var roof_col: Color = ROOFS[dice.randi() % ROOFS.size()] if not eternit else Color(0.74, 0.74, 0.76)
	var ccw := _signed_area(poly) > 0.0
	var walls := _bag(bags, "wall", _mat(_first([TEX + "lib_gable_white_side.png", TEX + "village_plaster.png"]), Color.WHITE))
	var plinth := _bag(bags, "plinth", _mat(_first([TEX_CAMP + "roughcast_wall.png", TEX_CAMP + "concrete.png"]), Color(0.52, 0.52, 0.5)))
	if not house:
		walls = _bag(bags, "wall_plain", _mat(_first([TEX_CAMP + "concrete.png", TEX + "village_plaster.png"]), Color.WHITE))
	if kind in ["barn", "cowshed", "stable"] and dice.randf() < 0.5:
		walls = _bag(bags, "brick", _mat(TEX_CAMP + "brick_red.png", Color.WHITE))
		wall_col = Color(0.9, 0.86, 0.82)
	# Walls round the footprint, the plinth along their foot.
	var n_pts := poly.size()
	var door_edge := -1
	var longest := 0.0
	for i in n_pts:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n_pts]
		var len := p0.distance_to(p1)
		if len > longest:
			longest = len
			door_edge = i
	for i in n_pts:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n_pts]
		var len := p0.distance_to(p1)
		if len < 0.2:
			continue
		var e := (p1 - p0) / len
		var out := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
		var nrm := Vector3(out.x, 0, out.y)
		walls.wall(p0, p1, 0.0, wall_h, nrm, Vector2(2.6, 2.6), wall_col)
		if house or kind in ["barn", "cowshed", "stable", "school", "civic"]:
			plinth.wall(p0 + out * 0.025, p1 + out * 0.025, 0.0, 0.5, nrm, Vector2(2.0, 2.0), Color.WHITE)
		if windows and len > 2.2:
			_windows(bags, p0, p1, out, wall_h, house, i == door_edge, dice)
	# The roof.
	_roof(bags, poly, wall_h, roof, house, kind, roof_col, eternit, wall_col, dice)
	# Solid: a box per convex piece's bounding rectangle.
	for piece in _pieces(poly):
		var bb := _obb(piece)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(bb["len"], wall_h, bb["wid"])
		shape.shape = box
		var u: Vector2 = bb["u"]
		shape.transform = Transform3D(Basis(Vector3.UP, -atan2(u.y, u.x)), Vector3(bb["c"].x, wall_h * 0.5, bb["c"].y))
		body.add_child(shape)


func _signed_area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


## The footprint in convex pieces (an L-shaped farmhouse in two wings).
func _pieces(poly: PackedVector2Array) -> Array:
	var parts := Geometry2D.decompose_polygon_in_convex(poly)
	if parts.is_empty():
		return [poly]
	return parts


## The smallest rectangle round a convex piece: centre, long axis u, its length, width.
func _obb(poly: PackedVector2Array) -> Dictionary:
	var best := {"c": poly[0], "u": Vector2.RIGHT, "len": 1.0, "wid": 1.0, "area": 1e18}
	for i in poly.size():
		var e := poly[(i + 1) % poly.size()] - poly[i]
		if e.length() < 0.3:
			continue
		var u := e.normalized()
		var v := Vector2(-u.y, u.x)
		var mn := Vector2(1e9, 1e9)
		var mx := Vector2(-1e9, -1e9)
		for p in poly:
			var q := Vector2(p.dot(u), p.dot(v))
			mn = mn.min(q)
			mx = mx.max(q)
		var size := mx - mn
		if size.x * size.y < float(best["area"]):
			var mid := (mn + mx) * 0.5
			var c := u * mid.x + v * mid.y
			if size.x >= size.y:
				best = {"c": c, "u": u, "len": size.x, "wid": size.y, "area": size.x * size.y}
			else:
				best = {"c": c, "u": v, "len": size.y, "wid": size.x, "area": size.x * size.y}
	return best


## Windows along one wall (and its door, on the house's longest side): the picture a
## little out from the plaster, a sill under each.
func _windows(bags: Dictionary, p0: Vector2, p1: Vector2, out: Vector2, wall_h: float, house: bool, with_door: bool, dice: RandomNumberGenerator) -> void:
	var len := p0.distance_to(p1)
	var e := (p1 - p0) / len
	var nrm := Vector3(out.x, 0, out.y)
	var kinds := [TEX + "house_window.png", TEX + "window_shutter.png", TEX + "window_flowers.png"]
	var pic: String = kinds[dice.randi() % kinds.size()] if house else TEX + "house_window.png"
	if not ResourceLoader.exists(pic):
		pic = TEX + "house_window.png"
	var win := _bag(bags, "win|" + pic, _window_mat(pic))
	var sill := _bag(bags, "sill", _mat(TEX_CAMP + "concrete.png", Color(0.74, 0.73, 0.7)))
	var door := _bag(bags, "door", _mat(_first([TEX + "house_door.png", TEX_CAMP + "door_wood.png"]), Color.WHITE))
	var floors := [[0.95, 2.15]]
	if wall_h > 5.0:
		floors.append([3.75, 4.85])
	if wall_h > 8.0:
		floors.append([6.55, 7.65])
	var count := int(floor((len - 0.8) / (2.6 if house else 4.0)))
	if count < 1:
		return
	var step := len / float(count)
	var door_at := count / 2 if with_door and house else -1
	var ww := 1.1 if house else 1.6
	for k in count:
		var mid := step * (float(k) + 0.5)
		for f in floors.size():
			var fl: Array = floors[f]
			if f == 0 and k == door_at:
				var a := p0 + e * (mid - 0.55) + out * 0.03
				var b := p0 + e * (mid + 0.55) + out * 0.03
				door.wall(a, b, 0.0, 2.15, nrm, Vector2(1.1, 2.15), Color.WHITE)
				sill.box(Vector3((a.x + b.x) * 0.5 + out.x * 0.25, 0.08, (a.y + b.y) * 0.5 + out.y * 0.25), Vector3(1.4, 0.16, 0.6), -atan2(e.y, e.x), Color.WHITE)
				continue
			if float(fl[1]) > wall_h - 0.25:
				continue
			var a := p0 + e * (mid - ww * 0.5) + out * 0.03
			var b := p0 + e * (mid + ww * 0.5) + out * 0.03
			# Its dice for the evening: under the shader's `lit` it is on.
			win.wall(a, b, float(fl[0]), float(fl[1]), nrm, Vector2(ww, float(fl[1]) - float(fl[0])), Color(1, 1, 1, dice.randf()))
			var sc := p0 + e * mid + out * 0.07
			sill.box(Vector3(sc.x, float(fl[0]) - 0.03, sc.y), Vector3(ww + 0.14, 0.05, 0.12), -atan2(e.y, e.x), Color.WHITE)


## The roof over the footprint: per convex piece a saddle along its long side (a hip on
## a squarish house or a big civic one), a low or flat roof on works and garages; gable
## triangles in the wall's plaster; on houses a chimney with its cap and maybe an aerial.
func _roof(bags: Dictionary, poly: PackedVector2Array, wall_h: float, roof: String, house: bool, kind: String, roof_col: Color, eternit: bool, wall_col: Color, dice: RandomNumberGenerator) -> void:
	var tiles := _bag(bags, "eternit" if eternit else "tiles", _mat(_first([TEX + ("roof_eternit.png" if eternit else "roof_tiles.png"), TEX_CAMP + "corrugated_roof.png"]), Color.WHITE, true))
	var gable_walls := _bag(bags, "wall", _mat(_first([TEX + "lib_gable_white_side.png", TEX + "village_plaster.png"]), Color.WHITE))
	if not house:
		gable_walls = _bag(bags, "wall_plain", _mat(_first([TEX_CAMP + "concrete.png", TEX + "village_plaster.png"]), Color.WHITE))
	var flat := _bag(bags, "flat", _mat(_first([TEX_CAMP + "concrete.png"]), Color(0.42, 0.42, 0.42)))
	if roof == "flat":
		_fill_poly(flat, poly, wall_h, 4.0, Color.WHITE)
		# A parapet's edge.
		var ccw := _signed_area(poly) > 0.0
		for i in poly.size():
			var p0 := poly[i]
			var p1 := poly[(i + 1) % poly.size()]
			var len := p0.distance_to(p1)
			if len < 0.2:
				continue
			var e := (p1 - p0) / len
			var out := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
			flat.wall(p0 + out * 0.04, p1 + out * 0.04, wall_h - 0.12, wall_h + 0.22, Vector3(out.x, 0, out.y), Vector2(2.0, 1.0), Color(0.8, 0.8, 0.8))
		return
	var pieces := _pieces(poly)
	var chimney_done := false
	for piece in pieces:
		var bb := _obb(piece)
		var L: float = bb["len"]
		var W: float = bb["wid"]
		if W < 2.0 or L < 2.0:
			_fill_poly(flat, piece, wall_h, 4.0, Color.WHITE)
			continue
		var u: Vector2 = bb["u"]
		var v := Vector2(-u.y, u.x)
		var c: Vector2 = bb["c"]
		var pitch := deg_to_rad(40.0) if house else deg_to_rad(28.0)
		if roof == "low":
			pitch = deg_to_rad(12.0)
		var rise := W * 0.5 * tan(pitch)
		var o := 0.35
		var eave_y := wall_h - o * tan(pitch)
		var top := wall_h + rise
		var hip := roof == "hip" or (house and L / W < 1.3 and dice.randf() < 0.7)
		var ridge_half := maxf(0.0, L * 0.5 - (W * 0.5 if hip else 0.0)) + (0.0 if hip else o)
		var r0 := c - u * ridge_half
		var r1 := c + u * ridge_half
		var e00 := c - u * (L * 0.5 + o) - v * (W * 0.5 + o)
		var e10 := c + u * (L * 0.5 + o) - v * (W * 0.5 + o)
		var e11 := c + u * (L * 0.5 + o) + v * (W * 0.5 + o)
		var e01 := c - u * (L * 0.5 + o) + v * (W * 0.5 + o)
		var R0 := Vector3(r0.x, top, r0.y)
		var R1 := Vector3(r1.x, top, r1.y)
		var E00 := Vector3(e00.x, eave_y, e00.y)
		var E10 := Vector3(e10.x, eave_y, e10.y)
		var E11 := Vector3(e11.x, eave_y, e11.y)
		var E01 := Vector3(e01.x, eave_y, e01.y)
		var tile := 2.2
		# The two long slopes.
		var n_minus := (Vector3(-v.x, 0, -v.y) * sin(pitch) + Vector3.UP * cos(pitch)).normalized()
		var n_plus := (Vector3(v.x, 0, v.y) * sin(pitch) + Vector3.UP * cos(pitch)).normalized()
		var slope := (W * 0.5 + o) / cos(pitch)
		tiles.quad(E00, E10, R1, R0, n_minus, Vector2(0, slope / tile), Vector2(L / tile, slope / tile), Vector2(L / tile, 0), Vector2(0, 0), roof_col)
		tiles.quad(E01, E11, R1, R0, n_plus, Vector2(0, slope / tile), Vector2(L / tile, slope / tile), Vector2(L / tile, 0), Vector2(0, 0), roof_col)
		if hip:
			var n_u := (Vector3(u.x, 0, u.y) * sin(pitch) + Vector3.UP * cos(pitch)).normalized()
			var n_mu := (Vector3(-u.x, 0, -u.y) * sin(pitch) + Vector3.UP * cos(pitch)).normalized()
			tiles.tri(E10, E11, R1, n_u, Vector2(0, slope / tile), Vector2(W / tile, slope / tile), Vector2(W * 0.5 / tile, 0), roof_col)
			tiles.tri(E00, E01, R0, n_mu, Vector2(0, slope / tile), Vector2(W / tile, slope / tile), Vector2(W * 0.5 / tile, 0), roof_col)
		else:
			# The gable triangles at both ends, in the walls' plaster.
			for end: float in [-1.0, 1.0]:
				var g: Vector2 = c + u * (L * 0.5) * end
				var gl: Vector2 = g - v * (W * 0.5)
				var gr: Vector2 = g + v * (W * 0.5)
				var nrm: Vector3 = Vector3(u.x, 0, u.y) * end
				gable_walls.tri(Vector3(gl.x, wall_h, gl.y), Vector3(gr.x, wall_h, gr.y), Vector3(g.x, top - 0.05, g.y), nrm,
					Vector2(0, -wall_h / 2.6), Vector2(W / 2.6, -wall_h / 2.6), Vector2(W * 0.5 / 2.6, -(top) / 2.6), wall_col)
				# A small vent window high in the gable of a house.
				if house and W > 5.0:
					var win := _bag(bags, "win|" + TEX + "house_window.png", _window_mat(TEX + "house_window.png"))
					var a: Vector2 = g - v * 0.4 + Vector2(u.x, u.y) * end * 0.03
					var b: Vector2 = g + v * 0.4 + Vector2(u.x, u.y) * end * 0.03
					win.wall(a, b, wall_h + rise * 0.25, wall_h + rise * 0.25 + 0.75, nrm, Vector2(0.8, 0.75), Color(1, 1, 1, dice.randf()))
		# Ridge tiles.
		var ridge := _bag(bags, "ridge", _mat(_first([TEX + "roof_tiles.png"]), Color(0.56, 0.34, 0.27)))
		var rd := R1 - R0
		if rd.length() > 0.3:
			ridge.box((R0 + R1) * 0.5 + Vector3(0, 0.05, 0), Vector3(rd.length() + 0.2, 0.14, 0.28), -atan2(u.y, u.x), Color.WHITE)
		if house and not chimney_done:
			chimney_done = true
			_chimney(bags, c, u, v, L, W, wall_h, rise, dice)


func _chimney(bags: Dictionary, c: Vector2, u: Vector2, v: Vector2, L: float, W: float, wall_h: float, rise: float, dice: RandomNumberGenerator) -> void:
	var brick := _bag(bags, "brick", _mat(TEX_CAMP + "brick_red.png", Color.WHITE))
	var cap := _bag(bags, "sill", _mat(TEX_CAMP + "concrete.png", Color(0.74, 0.73, 0.7)))
	var along := dice.randf_range(-0.3, 0.3) * L
	var across := W * 0.18 * (1.0 if dice.randf() < 0.5 else -1.0)
	var p := c + u * along + v * across
	var roof_y := wall_h + rise * (1.0 - absf(across) / (W * 0.5))
	var h := 1.3
	brick.box(Vector3(p.x, roof_y + h * 0.5 - 0.3, p.y), Vector3(0.5, h, 0.5), -atan2(u.y, u.x), Color.WHITE)
	cap.box(Vector3(p.x, roof_y + h - 0.26, p.y), Vector3(0.66, 0.07, 0.66), -atan2(u.y, u.x), Color.WHITE)
	if dice.randf() < 0.55:
		# The TV aerial on its pole beside the chimney, turned to Liblice B.
		var iron := _bag(bags, "iron", _mat("", Color(0.2, 0.2, 0.2)))
		var q := c - u * along * 0.5 - v * across
		var base := wall_h + rise * (1.0 - absf(across) / (W * 0.5))
		var ph := dice.randf_range(1.8, 2.8)
		iron.box(Vector3(q.x, base + ph * 0.5, q.y), Vector3(0.07, ph, 0.07), 0.0, Color.WHITE)
		var masts := GEO.masts()
		var yaw := 0.0
		if not masts.is_empty():
			var m: Vector3 = masts[0]
			yaw = -atan2(m.z - q.y, m.x - q.x)
		var bx := Basis(Vector3.UP, yaw)
		var top := Vector3(q.x, base + ph - 0.08, q.y)
		iron.box(top + bx * Vector3(0.35, 0, 0), Vector3(1.4, 0.045, 0.045), yaw, Color.WHITE)
		for k in 5:
			iron.box(top + bx * Vector3(-0.25 + 0.3 * float(k), 0, 0), Vector3(0.03, 0.03, 0.62 - 0.06 * float(k)), yaw, Color.WHITE)


## Trees: the woods and the scrub filled (spruce and birch, denser in the middle), the
## rows along roads and brooks, the gardens' fruit trees round the houses.
func _trees(root: Node3D, key: Vector2i, d: Dictionary, rng: RandomNumberGenerator, blocked: Array) -> void:
	if worldgen == null or not worldgen.has_method("_tree_mesh"):
		return
	var rect := _chunk_rect(key)
	var spruce: Array[Transform3D] = []
	var birch: Array[Transform3D] = []
	var linden: Array[Transform3D] = []
	var land: Array = _data.get("land", [])
	for i in d.get("wood", []):
		var poly := GEO.pts(land[i]["p"])
		var k := str(land[i]["k"])
		var r := _poly_rect(poly).intersection(rect)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var per := 70.0 if k == "wood" else 160.0
		if k == "orchard":
			per = 90.0
		var n := mini(1600, int(r.get_area() / per))
		for t in n:
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			if not Geometry2D.is_point_in_polygon(p, poly) or _cleared(p):
				continue
			var s := rng.randf_range(0.8, 1.35)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s)), Vector3(p.x, 0, p.y))
			if k == "wood" and rng.randf() < 0.55:
				spruce.append(xf.scaled_local(Vector3(1.3, 1.5, 1.3)))
			elif k == "orchard":
				# Apple and plum trees: a small round crown.
				linden.append(xf.scaled_local(Vector3(0.42, 0.36, 0.42)))
			elif rng.randf() < 0.4:
				# The broadleaves (oak, maple, linden alike from the road).
				linden.append(xf.scaled_local(Vector3(0.85, 0.85, 0.85)))
			else:
				birch.append(xf.scaled_local(Vector3(1.2, 1.2, 1.2)))
	var rows: Array = _data.get("tree_rows", [])
	for i in d.get("rows", []):
		# Alleys along the roads and brooks: lindens and the odd birch.
		_along_line(GEO.pts(rows[i]["p"]), 9.0, rect, func(p: Vector2):
			var yaw := rng.randf() * TAU
			if rng.randf() < 0.7:
				linden.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.7, 0.95)), Vector3(p.x, 0, p.y)))
			else:
				birch.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.0, 2.0, 1.0) * rng.randf_range(1.0, 1.3)), Vector3(p.x, 0, p.y))))
	var singles: Array = _data.get("trees", [])
	for i in d.get("tree", []):
		var p := Vector2(float(singles[i]), float(singles[i + 1]))
		if not _cleared(p):
			# The trees on their own (village greens, chapels, crossroads): lindens.
			linden.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15)), Vector3(p.x, 0, p.y)))
	# Gardens: fruit trees and a spruce or two behind the houses, not on a road.
	var on_road := _road_cells(d, 4.0)
	for i in d.get("res", []):
		var poly := GEO.pts(land[i]["p"])
		var r := _poly_rect(poly).intersection(rect)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var n := mini(260, int(r.get_area() / 420.0))
		for t in n:
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			if not Geometry2D.is_point_in_polygon(p, poly) or _cleared(p) or on_road.has(Vector2i(int(floor(p.x / 3.0)), int(floor(p.y / 3.0)))):
				continue
			var hit := false
			for b in blocked:
				if (b as Rect2).has_point(p):
					hit = true
					break
			if hit:
				continue
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.15)), Vector3(p.x, 0, p.y))
			if rng.randf() < 0.18:
				spruce.append(xf.scaled_local(Vector3(0.9, 1.1, 0.9)))
			elif rng.randf() < 0.75:
				# Fruit trees: small and round.
				linden.append(xf.scaled_local(Vector3(0.45, 0.38, 0.45)))
			else:
				birch.append(xf.scaled_local(Vector3(1.05, 0.85, 1.05)))
	_multimesh(root, spruce, "spruce", 2)
	_multimesh(root, birch, "birch", 0)
	_multimesh(root, linden, "linden", 0)


## The 3 m cells a chunk's roads (and `margin` either side) cover.
func _road_cells(d: Dictionary, margin: float) -> Dictionary:
	var cells := {}
	var roads: Array = _data.get("roads", [])
	for i in d.get("road", []):
		var line := GEO.pts(roads[i]["p"])
		var half := float(roads[i]["w"]) * 0.5 + margin
		var reach := int(ceil(half / 3.0))
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var len := a.distance_to(b)
			var s := 0.0
			while s <= len:
				var p := a.lerp(b, s / maxf(len, 0.001))
				var c := Vector2i(int(floor(p.x / 3.0)), int(floor(p.y / 3.0)))
				for dz in range(-reach, reach + 1):
					for dx in range(-reach, reach + 1):
						cells[c + Vector2i(dx, dz)] = true
				s += 2.0
	return cells


## Calls `f` every `step` metres along `line`, inside `rect` only.
func _along_line(line: PackedVector2Array, step: float, rect: Rect2, f: Callable) -> void:
	var carry := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var len := a.distance_to(b)
		var s := carry
		while s < len:
			var p := a.lerp(b, s / len)
			if rect.has_point(p) and not _cleared(p):
				f.call(p)
			s += step
		carry = s - len


func _multimesh(root: Node3D, xforms: Array[Transform3D], species: String, variant: int) -> void:
	if xforms.is_empty():
		return
	for part in [["%s_trunk" % species, "bark"], ["%s_crown" % species, "needles" if species == "spruce" else "leaf"]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = worldgen._tree_mesh(str(part[0]))
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = worldgen._tree_material(str(part[1]), variant)
		mmi.visibility_range_end = FAR
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	# Leaves on cards round the crowns' lumps, near to (a ragged outline, not a ball).
	if species in ["birch", "linden"]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = worldgen._tree_mesh("%s_cards" % species)
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var cards := MultiMeshInstance3D.new()
		cards.multimesh = mm
		cards.material_override = worldgen._tree_material("leaf_cards", variant)
		cards.visibility_range_end = 420.0
		cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(cards)


## The power lines: concrete poles (the big lines steel ones, taller) and three wires
## between each pair, with a little sag.
func _power(bags: Dictionary, key: Vector2i, d: Dictionary) -> void:
	var lines: Array = _data.get("power", [])
	var rect := _chunk_rect(key)
	var pole_mat := _bag(bags, "pole", _mat(TEX_CAMP + "concrete.png", Color(0.7, 0.7, 0.68)))
	var wire := _bag(bags, "iron", _mat("", Color(0.2, 0.2, 0.2)))
	for i in d.get("power", []):
		var line := GEO.pts(lines[i]["p"])
		var big := str(lines[i]["k"]) == "line"
		var poles: Array = Array(GEO.pts(lines[i].get("poles", [])))
		if poles.size() < 2:
			poles = []
			_along_line(line, 45.0 if not big else 260.0, Rect2(-1e6, -1e6, 2e6, 2e6), func(p: Vector2): poles.append(p))
		var h := 9.0 if not big else 26.0
		for k in poles.size():
			var p: Vector2 = poles[k]
			if not rect.has_point(p) or _cleared(p):
				continue
			if big:
				# A lattice pylon, the Build way: four tapering legs and the crossarms.
				for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var foot: Vector2 = p + s * 2.2
					var head: Vector2 = p + s * 0.6
					pole_mat.box(Vector3((foot.x + head.x) * 0.5, h * 0.5, (foot.y + head.y) * 0.5), Vector3(0.25, h, 0.25), 0.0, Color(0.5, 0.52, 0.52))
				for y in [h * 0.7, h * 0.85, h]:
					wire.box(Vector3(p.x, y, p.y), Vector3(10.0, 0.25, 0.4), 0.0, Color.WHITE)
			else:
				pole_mat.box(Vector3(p.x, h * 0.5, p.y), Vector3(0.24, h, 0.24), 0.0, Color.WHITE)
				wire.box(Vector3(p.x, h - 0.3, p.y), Vector3(1.6, 0.1, 0.1), 0.0, Color.WHITE)
			if k + 1 < poles.size():
				var q: Vector2 = poles[k + 1]
				var len := p.distance_to(q)
				var yaw := -atan2(q.y - p.y, q.x - p.x)
				var mid := (p + q) * 0.5
				for off: float in ([-0.7, 0.0, 0.7] if not big else [-4.5, 0.0, 4.5]):
					var side: Vector2 = Vector2(-(q - p).normalized().y, (q - p).normalized().x) * off
					wire.box(Vector3(mid.x + side.x, h - (0.3 if not big else 1.0) - len * 0.012, mid.y + side.y), Vector3(len, 0.035 if not big else 0.06, 0.035 if not big else 0.06), yaw, Color.WHITE)


## The villages' fences and walls along their gardens.
func _fences(bags: Dictionary, key: Vector2i, d: Dictionary) -> void:
	var fences: Array = _data.get("fences", [])
	var rect := _chunk_rect(key)
	var picket := _bag(bags, "fence", _mat(_first([TEX + "fence_picket.png", TEX + "fence_mesh.png"]), Color.WHITE, true, true))
	var wall := _bag(bags, "fence_wall", _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(0.86, 0.84, 0.8)))
	for i in d.get("fence", []):
		var line := GEO.pts(fences[i]["p"])
		var is_wall := str(fences[i]["k"]) == "wall"
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var mid := (a + b) * 0.5
			if not rect.has_point(mid) or _cleared(mid) or a.distance_to(b) < 0.3:
				continue
			var e := (b - a).normalized()
			var nrm := Vector3(-e.y, 0, e.x)
			if is_wall:
				wall.wall(a, b, 0.0, 1.8, nrm, Vector2(2.5, 2.5), Color.WHITE)
				wall.wall(b, a, 0.0, 1.8, -nrm, Vector2(2.5, 2.5), Color.WHITE)
			else:
				picket.wall(a, b, 0.0, 1.2, nrm, Vector2(2.0, 1.2), Color.WHITE)


## The white posts (Z 11) along the roads between the villages, opposite each other
## every 50 m.
func _posts(root: Node3D, key: Vector2i, d: Dictionary) -> void:
	var roads: Array = _data.get("roads", [])
	var rect := _chunk_rect(key)
	for i in d.get("road", []):
		var c := str(roads[i]["c"])
		if not c in ["primary", "secondary", "tertiary", "unclassified"]:
			continue
		var line := GEO.pts(roads[i]["p"])
		var half := float(roads[i]["w"]) * 0.5 + 0.7
		var carry := 0.0
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var len := a.distance_to(b)
			if len < 0.1:
				continue
			var e := (b - a) / len
			var side := Vector2(-e.y, e.x)
			var s := carry
			while s < len:
				var p := a + e * s
				if rect.has_point(p) and not _cleared(p) and not _in_village(p):
					for sgn in [-1.0, 1.0]:
						var q: Vector2 = p + side * half * sgn
						ROAD_POST.place(root, Vector3(q.x, 0.0, q.y), Vector3(-side.x * sgn, 0, -side.y * sgn))
				s += 50.0
			carry = s - len
