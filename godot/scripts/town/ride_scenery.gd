extends Node3D

## What goes past the windows of the bus (scripts/town/bus_ride.gd): the bus stands at
## the origin facing -Z and the land comes at it. The road is laid in 60 m pieces ahead
## and dropped behind, each piece of a kind the route asks for at that distance. The
## way to Lesna as it is in the Vysocina in late September: the forest from the camp, a
## wayside cross where it opens, the reservoir, a cow pasture behind an electric fence,
## maize standing high both sides of the road, stubble with round straw bales, a ploughed
## field with a Zetor going up it and a roe deer at the far edge, the old apple alley with
## its trunks painted white, the collective farm with its cowshed and silos, the LESNA
## sign, farmhouses with their gables to the road and somebody cycling home, the square.
## The other way round going back to the camp.
##
## Along the whole road the white posts with black tops, every 25 m. Trees are the camp's
## own meshes (world_generator.gd); animals, people, the tractor, the cross and the apple
## trees Build sprites (Grok, assets/textury/town/); buildings textured boxes. Now and then
## a car the other way, at night with its lights on; and at night not everything by the
## road is a tree.

const PIECE := 60.0
const AHEAD := 380.0
const BEHIND := 90.0
const ROAD_Y := -0.95
## The middle of the road: the bus keeps to the right half of it.
const LANE := -1.5
## The road's right edge (x).
const EDGE := 1.5
const TEX_CAMP := "res://assets/textury/camp/"
const TEX_TOWN := "res://assets/textury/town/"
const CORN_TEX := "res://assets/textury/world/corn.png"
## The route out from the camp, a kind per piece (reversed on the way back).
const ROUTE := ["camp", "forest", "forest_cross", "lake", "lake", "forest", "meadow", "corn", "corn", "stubble", "plough", "alley", "jzd", "alley", "edge", "village", "village", "town"]

var to_town := true
var night := false
var worldgen: Node
var travelled := 0.0
var _pieces: Array = []          # [{node, at}] at = distance along the route of its start
var _next_at := 0.0
var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _cars: Array = []
var _car_t := 6.0
var _figure_done := false
var _church_done := false
var _actors: Array = []          # {node, vel, kind}
var _tex: Dictionary = {}


func setup(p_to_town: bool, p_night: bool, p_worldgen: Node) -> void:
	to_town = p_to_town
	night = p_night
	worldgen = p_worldgen
	_rng.randomize()
	for p in _pieces:
		(p["node"] as Node).queue_free()
	_pieces.clear()
	for c in _cars:
		(c["node"] as Node).queue_free()
	_cars.clear()
	_actors.clear()
	travelled = 0.0
	_next_at = -BEHIND
	_figure_done = false
	_church_done = false
	_fill()


## How far the route goes (the stop at the far end is where the bus stops).
func route_length() -> float:
	return float(ROUTE.size() - 1) * PIECE + PIECE * 0.5


func advance(dist: float, delta: float) -> void:
	travelled += dist
	for p in _pieces:
		(p["node"] as Node3D).position.z = travelled - float(p["at"])
	while not _pieces.is_empty() and travelled - float(_pieces[0]["at"]) - PIECE > BEHIND:
		(_pieces[0]["node"] as Node).queue_free()
		_pieces.pop_front()
	_actors = _actors.filter(func(a): return is_instance_valid(a["node"]))
	_fill()
	_update_actors(delta)
	_update_cars(dist, delta)


func _kind_at(at: float) -> String:
	var i := int(floorf(at / PIECE))
	if i < 0:
		return ROUTE[0] if to_town else ROUTE[ROUTE.size() - 1]
	if i >= ROUTE.size():
		return "town" if to_town else "camp"
	return ROUTE[i] if to_town else ROUTE[ROUTE.size() - 1 - i]


func _fill() -> void:
	while _next_at < travelled + AHEAD:
		var node := _build_piece(_kind_at(_next_at), _next_at)
		add_child(node)
		node.position.z = travelled - _next_at
		_pieces.append({"node": node, "at": _next_at})
		_next_at += PIECE


# ── the pieces ───────────────────────────────────────────────────────────────

## A piece spans z from 0 (its start, nearest) to -PIECE in its own frame. Right of the
## road is +x (the doors' side), left is -x (the oncoming lane).
func _build_piece(kind: String, at: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Piece_%s" % kind
	# The stop you start from and the stop you stop at: a shelter where the bus stands.
	var idx := int(floorf(at / PIECE))
	if (at <= 0.0 and at + PIECE > 0.0) or idx == ROUTE.size() - 1:
		_shelter(root, -30.0)
	var ground := "grass"
	match kind:
		"forest", "forest_cross", "camp", "lake":
			ground = "forest"
		"meadow", "alley", "edge", "jzd":
			ground = "meadow"
		"corn", "stubble":
			ground = "stubble"
		"plough":
			ground = "plough"
	_ground(root, ground, kind)
	if kind != "camp":
		_road(root)
		_posts(root)
	else:
		_gravel(root)
	match kind:
		"camp":
			_trees(root, -1.0, 4.5, 50.0, 120)
			_trees(root, 1.0, 4.5, 50.0, 120)
		"forest":
			_trees(root, -1.0, 4.0, 60.0, 160)
			_trees(root, 1.0, 4.0, 60.0, 160)
			if night and not _figure_done and _rng.randf() < 0.18:
				_figure(root)
		"forest_cross":
			_trees(root, -1.0, 4.0, 60.0, 150)
			_trees(root, 1.0, 14.0, 60.0, 90)
			_billboard(root, "cross", 2.6, Vector3(EDGE + 2.4, ROAD_Y, -30.0))
			_deer(root, Vector3(LANE + 18.0, ROAD_Y, -46.0))
		"lake":
			var water_side := -1.0 if to_town else 1.0
			_water(root, water_side)
			_trees(root, -water_side, 4.5, 50.0, 110)
			_trees(root, water_side, 140.0, 190.0, 50)
			_rail(root, water_side)
		"meadow":
			_fence(root, 1.0, 6.2)
			for k in _rng.randi_range(4, 7):
				var look := _rng.randf() < 0.35
				var cow := _billboard(root, "cow_look" if look else "cow", 1.55 if look else 1.45, Vector3(LANE + _rng.randf_range(11.0, 60.0), ROAD_Y, -_rng.randf_range(4.0, 56.0)))
				cow.flip_h = _rng.randf() < 0.5
			_trees(root, -1.0, 40.0, 120.0, 30)
			_trees(root, 1.0, 80.0, 150.0, 20)
		"corn":
			_corn(root, 1.0)
			_corn(root, -1.0)
		"stubble":
			_bales(root, 1.0)
			_bales(root, -1.0)
			_trees(root, -1.0, 90.0, 160.0, 16)
			_trees(root, 1.0, 100.0, 170.0, 12)
		"plough":
			_power_line(root)
			_tractor(root)
			_deer(root, Vector3(LANE - 70.0, ROAD_Y, -30.0))
			_trees(root, -1.0, 85.0, 150.0, 24)
			_trees(root, 1.0, 110.0, 170.0, 14)
		"alley":
			_alley(root, 0.0)
			if _rng.randf() < 0.5:
				_billboard(root, "cross", 2.6, Vector3(LANE - 6.0, ROAD_Y, -_rng.randf_range(12.0, 48.0)))
			_trees(root, -1.0, 70.0, 140.0, 16)
		"jzd":
			_jzd(root)
			_alley(root, -1.0)
		"edge":
			_town_sign(root)
			_farmhouses(root, 1.0, 1)
			_alley(root, -1.0)
		"village":
			# The first village piece has the church on the green on the doors' side (the
			# side you sit on), a house past it; the second has houses both sides.
			_farmhouses(root, -1.0, 2)
			if not _church_done:
				_church_done = true
				_church(root, 1.0)
				_farmhouses(root, 1.0, 1)
			else:
				_farmhouses(root, 1.0, 2)
			if _rng.randf() < 0.6:
				_cyclist(root)
		"town":
			_farmhouses(root, -1.0, 3)
			_farmhouses(root, 1.0, 2)
	return root


# ── materials, meshes ────────────────────────────────────────────────────────

func _mat(key: String, path: String, tint: Color, uv: Vector2 = Vector2.ONE) -> StandardMaterial3D:
	var k := "%s_%s_%s" % [key, uv.x, uv.y]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_color = tint
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	_mats[k] = m
	return m


## A cut-out (alpha scissor), seen from both sides.
func _cut_mat(key: String, path: String, uv := Vector2.ONE) -> StandardMaterial3D:
	var m := _mat(key, path, Color.WHITE, uv)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := TEX_TOWN + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


func _plane(root: Node3D, pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


func _quad(root: Node3D, pos: Vector3, size: Vector2, yaw: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	mi.rotation.y = yaw
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


func _box(root: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	root.add_child(mi)
	return mi


## A Build sprite standing on the ground (its feet at `pos`), turned to face you.
func _billboard(root: Node3D, name: String, height: float, pos: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	var tex := _texture(name)
	if tex == null:
		return s
	s.texture = tex
	s.pixel_size = height / float(tex.get_height())
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.offset = Vector2(0, tex.get_height() * 0.5)
	s.position = pos
	root.add_child(s)
	return s


# ── the land ─────────────────────────────────────────────────────────────────

func _ground(root: Node3D, kind: String, piece: String) -> void:
	var w := 420.0
	match kind:
		"forest":
			# The same grass as the camp's own ground (world_generator), so the ride starts
			# on the floor you just left; forest_floor.png read as flat grey under the LUT.
			_plane(root, Vector3(0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w, PIECE), _mat("forest", "res://assets/textury/redneck/grass.png", Color(1.05, 1.08, 0.95), Vector2(w / 2.0, PIECE / 2.0)))
		"meadow":
			_plane(root, Vector3(0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w, PIECE), _mat("meadow", TEX_TOWN + "meadow.png", Color(0.95, 0.95, 0.9), Vector2(w / 8.0, PIECE / 8.0)))
		"stubble":
			_plane(root, Vector3(0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w, PIECE), _mat("stubble", TEX_TOWN + "field_stubble.png", Color(1, 1, 0.95), Vector2(w / 10.0, PIECE / 10.0)))
		"plough":
			_plane(root, Vector3(LANE - w * 0.25 - 3.0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w * 0.5, PIECE), _mat("stubble", TEX_TOWN + "field_stubble.png", Color(1, 1, 0.95), Vector2(w / 20.0, PIECE / 10.0)))
			_plane(root, Vector3(LANE + w * 0.25 + 3.0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w * 0.5, PIECE), _mat("plough", TEX_TOWN + "field_plough.png", Color(0.95, 0.95, 0.95), Vector2(w / 20.0, PIECE / 10.0)))
		_:
			_plane(root, Vector3(0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w, PIECE), _mat("grass", TEX_CAMP + "pitch_grass.png", Color(0.9, 0.92, 0.8), Vector2(w / 8.0, PIECE / 8.0)))
	# Grass verges and a ditch either side of the road.
	if piece != "camp":
		for side in [-1.0, 1.0]:
			_plane(root, Vector3(LANE + side * 4.3, ROAD_Y - 0.01, -PIECE * 0.5), Vector2(2.6, PIECE), _mat("verge", TEX_TOWN + "meadow.png", Color(0.82, 0.86, 0.7), Vector2(1.0, PIECE / 2.6)))
			_plane(root, Vector3(LANE + side * 5.9, ROAD_Y - 0.25, -PIECE * 0.5), Vector2(0.8, PIECE), _mat("ditch", TEX_TOWN + "meadow.png", Color(0.5, 0.52, 0.4), Vector2(1.0, PIECE / 2.0)))


func _road(root: Node3D) -> void:
	var asphalt := _mat("asphalt", TEX_TOWN + "asphalt.png", Color(0.72, 0.72, 0.74), Vector2(1.0, PIECE / 6.0))
	_plane(root, Vector3(LANE, ROAD_Y, -PIECE * 0.5), Vector2(6.0, PIECE), asphalt)
	# The centre line, dashed, worn away here and there.
	var paint := _mat("line", "", Color(0.86, 0.84, 0.76))
	for k in 6:
		if _rng.randf() < 0.85:
			_plane(root, Vector3(LANE, ROAD_Y + 0.01, -5.0 - k * 10.0), Vector2(0.12, 3.0), paint)


func _gravel(root: Node3D) -> void:
	_plane(root, Vector3(0, ROAD_Y, -PIECE * 0.5), Vector2(4.6, PIECE), _mat("gravel", TEX_CAMP + "gravel_road.png", Color(0.95, 0.9, 0.82), Vector2(1.0, PIECE / 4.6)))


## The white roadside posts with black tops (patniky), every 25 m both sides, an amber
## reflector on each that catches the headlights at night.
func _posts(root: Node3D) -> void:
	var white := _mat("post_white", "", Color(0.92, 0.92, 0.88))
	var black := _mat("post_black", "", Color(0.06, 0.06, 0.06))
	var refl := _mat("post_refl", "", Color(0.95, 0.55, 0.1))
	refl.emission_enabled = true
	refl.emission = Color(1.0, 0.55, 0.1) * (1.2 if night else 0.1)
	for z in [-12.0, -37.0]:
		for side in [-1.0, 1.0]:
			var x: float = LANE + side * 3.6
			_box(root, Vector3(x, ROAD_Y + 0.45, z), Vector3(0.12, 0.9, 0.12), white)
			_box(root, Vector3(x, ROAD_Y + 0.84, z), Vector3(0.125, 0.14, 0.125), black)
			_box(root, Vector3(x - side * 0.065, ROAD_Y + 0.7, z), Vector3(0.01, 0.1, 0.05), refl)


func _trees(root: Node3D, side: float, from: float, to: float, count: int) -> void:
	if worldgen == null or not worldgen.has_method("_tree_mesh"):
		return
	var spruce: Array[Transform3D] = []
	var birch: Array[Transform3D] = []
	for k in count:
		var off := lerpf(from, to, pow(_rng.randf(), 1.7))
		var p := Vector3(LANE + side * (3.0 + off), ROAD_Y, -_rng.randf() * PIECE)
		var sc := _rng.randf_range(0.9, 1.7)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.9, 1.3), sc))
		if _rng.randf() < 0.15:
			birch.append(Transform3D(b.scaled(Vector3(0.8, 0.8, 0.8)), p))
		else:
			spruce.append(Transform3D(b, p))
	_multi(root, "spruce_trunk", worldgen._tree_material("bark", 1), spruce)
	_multi(root, "spruce_crown", worldgen._tree_material("needles", 1), spruce)
	_multi(root, "birch_trunk", worldgen._tree_material("birch_bark", 0), birch)
	_multi(root, "birch_crown", worldgen._tree_material("leaf", 1), birch)
	# A thick wood: a wall of needles at the back so you never see the plain through it.
	if from < 20.0 and count >= 90:
		_box(root, Vector3(LANE + side * (3.0 + to + 3.0), ROAD_Y + 6.0, -PIECE * 0.5), Vector3(2.0, 12.0, PIECE + 0.5), worldgen._tree_material("needles", 2))


func _multi(root: Node3D, mesh_id: String, mat: Material, list: Array[Transform3D]) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = worldgen._tree_mesh(mesh_id)
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)


func _water(root: Node3D, side: float) -> void:
	var water := _mat("water", TEX_CAMP + "lake_water.png", Color(0.6, 0.66, 0.7), Vector2(30.0, 6.0))
	_plane(root, Vector3(LANE + side * 78.0, ROAD_Y - 1.2, -PIECE * 0.5), Vector2(140.0, PIECE), water)
	var bank := _mat("bank", TEX_CAMP + "lake_shore.png", Color(0.8, 0.8, 0.72), Vector2(2.0, PIECE / 4.0))
	var b := _plane(root, Vector3(LANE + side * 8.0, ROAD_Y - 0.6, -PIECE * 0.5), Vector2(3.0, PIECE), bank)
	b.rotation.z = side * 0.4


func _rail(root: Node3D, side: float) -> void:
	var steel := _mat("rail", TEX_CAMP + "galvanized.png", Color(0.7, 0.72, 0.7))
	var x: float = LANE + side * 3.4
	_box(root, Vector3(x, ROAD_Y + 0.55, -PIECE * 0.5), Vector3(0.06, 0.25, PIECE), steel)
	for k in 12:
		_box(root, Vector3(x, ROAD_Y + 0.3, -2.5 - k * 5.0), Vector3(0.1, 0.6, 0.1), steel)


## An electric fence round the pasture: thin posts and two wires.
func _fence(root: Node3D, side: float, off: float) -> void:
	var wood := _mat("fencepost", TEX_CAMP + "log_bark.png", Color(0.6, 0.52, 0.42))
	var wire := _mat("fwire", "", Color(0.75, 0.75, 0.72))
	var x: float = LANE + side * off
	for k in 7:
		_box(root, Vector3(x, ROAD_Y + 0.55, -2.0 - k * 9.5), Vector3(0.07, 1.1, 0.07), wood)
	for hh in [0.55, 0.95]:
		_box(root, Vector3(x, ROAD_Y + hh, -PIECE * 0.5), Vector3(0.015, 0.015, PIECE), wire)


## Maize standing high from just past the ditch to the horizon: walls of it (the Grok
## picture on long quads) at the edge and further back, single plants standing out in
## front of the edge (the camp's corn sprite in crossed quads).
func _corn(root: Node3D, side: float) -> void:
	var wall := _mat("cornwall", TEX_TOWN + "corn_wall.png", Color(1, 1, 1), Vector2(PIECE / 4.4, 1.0))
	wall.cull_mode = BaseMaterial3D.CULL_DISABLED
	for d in [7.4, 16.0, 34.0, 62.0]:
		_quad(root, Vector3(LANE + side * d, ROAD_Y + 1.25, -PIECE * 0.5), Vector2(PIECE, 2.5), -PI * 0.5 * side, wall)
	if not ResourceLoader.exists(CORN_TEX):
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _cross_quad(Vector2(0.7, 2.4))
	var xf: Array[Transform3D] = []
	for k in 70:
		var p := Vector3(LANE + side * _rng.randf_range(5.8, 7.3), ROAD_Y, -_rng.randf() * PIECE)
		var s := _rng.randf_range(0.85, 1.15)
		xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.15), s)), p))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var plant := StandardMaterial3D.new()
	plant.albedo_texture = load(CORN_TEX)
	plant.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plant.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	plant.alpha_scissor_threshold = 0.5
	plant.cull_mode = BaseMaterial3D.CULL_DISABLED
	plant.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = plant
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _cross_quad(size: Vector2) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var a := float(k) * PI * 0.5
		var dx := Vector3(cos(a), 0, sin(a)) * size.x * 0.5
		var v := [-dx, dx, dx + Vector3(0, size.y, 0), -dx + Vector3(0, size.y, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[i])
			st.add_vertex(v[i])
	st.generate_normals()
	return st.commit()


## Round straw bales left on the stubble, lying on their sides.
func _bales(root: Node3D, side: float) -> void:
	var straw := _mat("straw", TEX_TOWN + "straw.png", Color(1, 1, 1))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.75
	cyl.height = 1.2
	cyl.radial_segments = 10
	cyl.rings = 1
	for k in _rng.randi_range(4, 9):
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = straw
		mi.position = Vector3(LANE + side * _rng.randf_range(10.0, 80.0), ROAD_Y + 0.75, -_rng.randf_range(4.0, 56.0))
		mi.rotation = Vector3(0, _rng.randf() * TAU, PI * 0.5)
		root.add_child(mi)


## A Zetor ploughing up the field beside the road, slowly.
func _tractor(root: Node3D) -> void:
	var t := _billboard(root, "tractor", 2.6, Vector3(LANE + _rng.randf_range(30.0, 55.0), ROAD_Y, -_rng.randf_range(15.0, 45.0)))
	if t.texture == null:
		return
	t.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	t.rotation.y = PI * 0.5
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	t.flip_h = dir < 0.0
	_actors.append({"node": t, "vel": Vector3(0, 0, -1.6 * dir), "kind": "tractor"})


## A roe deer at the edge of the field: when the bus comes near it bolts.
func _deer(root: Node3D, pos: Vector3) -> void:
	if _rng.randf() > 0.6:
		return
	var d := _billboard(root, "deer", 1.15, pos)
	if d.texture != null:
		_actors.append({"node": d, "vel": Vector3.ZERO, "kind": "deer"})


## Somebody cycling home on the shoulder: the bus overtakes him.
func _cyclist(root: Node3D) -> void:
	var c := _billboard(root, "cyclist", 1.75, Vector3(EDGE + 0.6, ROAD_Y, -_rng.randf_range(20.0, 50.0)))
	if c.texture == null:
		return
	c.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	c.rotation.y = PI * 0.5
	_actors.append({"node": c, "vel": Vector3(0, 0, -4.5), "kind": "cyclist"})


func _update_actors(delta: float) -> void:
	var tick := floorf(Time.get_ticks_msec() / 83.0)
	for a in _actors:
		var n: Sprite3D = a["node"]
		var vel: Vector3 = a["vel"]
		if str(a["kind"]) == "deer" and vel == Vector3.ZERO:
			# The bus within 45 m: off it goes, away from the road.
			if n.global_position.z > -45.0:
				var away := signf(n.position.x - LANE)
				a["vel"] = Vector3(away * 9.0, 0, -2.0)
				n.flip_h = away < 0.0
			continue
		n.position += vel * delta
		# Pedalling, the tractor's shake, the deer's bounds: a pixel up and down in steps.
		if n.texture != null:
			n.offset.y = n.texture.get_height() * 0.5 + (1.0 if int(tick) % 2 == 0 else 0.0)


## The old apple alley: fruit trees both sides (or one, `only`), trunks painted white;
## a field with bales behind.
func _alley(root: Node3D, only: float) -> void:
	for side in [-1.0, 1.0]:
		if only != 0.0 and side != only:
			continue
		for k in 5:
			var z := -4.0 - k * 12.0 - _rng.randf_range(-1.5, 1.5)
			_billboard(root, "apple_tree", _rng.randf_range(4.6, 5.8), Vector3(LANE + side * _rng.randf_range(4.6, 5.4), ROAD_Y, z))
	_bales(root, 1.0 if only <= 0.0 else -1.0)


## The collective farm: a long cowshed along the road, two concrete silos, a dungheap.
func _jzd(root: Node3D) -> void:
	var x := LANE + 22.0
	var barn_face := _mat("jzd", TEX_TOWN + "jzd_barn.png", Color(1, 1, 1))
	var plaster := _mat("jzd_wall", TEX_CAMP + "concrete.png", Color(0.75, 0.74, 0.7), Vector2(6.0, 1.0))
	var roof := _mat("jzd_roof", TEX_CAMP + "corrugated_roof.png", Color(0.6, 0.5, 0.45), Vector2(8.0, 2.0))
	_box(root, Vector3(x + 7.0, ROAD_Y + 2.4, -30.0), Vector3(14.0, 4.8, 40.0), plaster)
	_box(root, Vector3(x + 7.0, ROAD_Y + 5.0, -30.0), Vector3(15.0, 0.4, 41.0), roof)
	for k in 2:
		_quad(root, Vector3(x - 0.01, ROAD_Y + 2.4, -20.0 - k * 20.0), Vector2(20.0, 4.8), -PI * 0.5, barn_face)
	var concrete := _mat("silo", TEX_CAMP + "concrete.png", Color(0.82, 0.82, 0.8), Vector2(3.0, 4.0))
	for k in 2:
		var s := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.2
		cyl.bottom_radius = 2.2
		cyl.height = 14.0
		cyl.radial_segments = 10
		s.mesh = cyl
		s.material_override = concrete
		s.position = Vector3(x + 20.0 + k * 5.0, ROAD_Y + 7.0, -12.0)
		root.add_child(s)
		_box(root, Vector3(x + 20.0 + k * 5.0, ROAD_Y + 14.2, -12.0), Vector3(1.8, 0.6, 1.8), _mat("silo_top", "", Color(0.4, 0.38, 0.36)))
	_box(root, Vector3(x - 4.0, ROAD_Y + 0.6, -52.0), Vector3(6.0, 1.2, 5.0), _mat("dung", TEX_TOWN + "field_plough.png", Color(0.55, 0.42, 0.3)))


## The village sign (white with a black border and the black name) on the way in; on
## the way back the one to the camp.
func _town_sign(root: Node3D) -> void:
	var post := _mat("signpost", "", Color(0.4, 0.42, 0.4))
	var x := EDGE + 1.6
	_box(root, Vector3(x, ROAD_Y + 1.1, -20.0), Vector3(0.08, 2.2, 0.08), post)
	_box(root, Vector3(x, ROAD_Y + 2.15, -20.0), Vector3(0.06, 0.62, 1.5), _mat("sign_black", "", Color(0.06, 0.06, 0.06)))
	_box(root, Vector3(x - 0.01, ROAD_Y + 2.15, -20.0), Vector3(0.06, 0.54, 1.42), _mat("sign_white", "", Color(0.94, 0.94, 0.9)))
	var label := Label3D.new()
	label.text = "LESNA" if to_town else "CERNE JEZERO 6"
	label.font = load("res://assets/fonts/jersey10.fnt")
	label.font_size = 48
	label.pixel_size = 0.005
	label.modulate = Color(0.06, 0.06, 0.08)
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = Vector3(x - 0.05, ROAD_Y + 2.15, -20.0)
	label.rotation.y = -PI * 0.5
	root.add_child(label)


## Farmhouses with their gables to the road, the Vysocina way: a white box, a pitched
## roof, the gable picture on the end facing the road; a picket fence, an apple tree.
func _farmhouses(root: Node3D, side: float, count: int) -> void:
	var walls := _mat("farm_wall", TEX_TOWN + "village_plaster.png", Color(1.0, 0.98, 0.94), Vector2(9.0, 2.0))
	var tiles := _mat("farm_roof", TEX_TOWN + "roof_tiles.png", Color(0.8, 0.6, 0.55), Vector2(6.0, 3.0))
	var gable := _cut_mat("farm_gable", TEX_TOWN + "farmhouse.png")
	var fence := _mat("farm_fence", TEX_CAMP + "planks_grey.png", Color(0.86, 0.84, 0.76), Vector2(6.0, 1.0))
	var lit := _mat("farm_lit", "", Color(1.0, 0.82, 0.5))
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.75, 0.4) * 1.6
	for k in count:
		var w := 7.0
		var depth := _rng.randf_range(11.0, 15.0)
		var h := 3.2
		var near := _rng.randf_range(9.0, 13.0)
		var z := -8.0 - float(k) * (PIECE / float(count)) - _rng.randf_range(0.0, 4.0)
		var cx: float = LANE + side * (near + depth * 0.5)
		_box(root, Vector3(cx, ROAD_Y + h * 0.5, z), Vector3(depth, h, w), walls)
		for s2 in [-1.0, 1.0]:
			var r := _box(root, Vector3(cx, ROAD_Y + h + 1.2, z + s2 * w * 0.26), Vector3(depth + 0.4, 0.14, w * 0.62), tiles)
			r.rotation.x = s2 * 0.72
		var gx: float = LANE + side * (near - 0.02)
		_quad(root, Vector3(gx, ROAD_Y + (h + 2.6) * 0.5, z), Vector2(w, h + 2.6), -PI * 0.5 * side, gable)
		if night and _rng.randf() < 0.6:
			_quad(root, Vector3(gx - side * 0.02, ROAD_Y + 1.6, z + _rng.randf_range(-1.5, 1.5)), Vector2(0.9, 0.9), -PI * 0.5 * side, lit)
		_box(root, Vector3(LANE + side * (near - 3.0), ROAD_Y + 0.5, z), Vector3(0.06, 1.0, w + 4.0), fence)
		if _rng.randf() < 0.5:
			_billboard(root, "apple_tree", _rng.randf_range(4.0, 5.0), Vector3(LANE + side * (near - 1.6), ROAD_Y, z - w * 0.5 - 2.5))


## The village church: a plastered nave under tiles, its front (Grok, church.png) to the
## road, a lime tree and a wayside cross on the green before it.
func _church(root: Node3D, side: float) -> void:
	var walls := _mat("church_wall", TEX_TOWN + "village_plaster.png", Color(0.92, 0.9, 0.86), Vector2(10.0, 3.0))
	var tiles := _mat("church_roof", TEX_TOWN + "roof_tiles.png", Color(0.62, 0.5, 0.46), Vector2(8.0, 4.0))
	var front := _cut_mat("church_front", TEX_TOWN + "church.png")
	var w := 7.0
	var fh := w * 171.0 / 96.0
	var h := fh * 0.58
	var depth := 16.0
	var near := 16.0
	var z := -38.0
	var cx: float = LANE + side * (near + depth * 0.5)
	_box(root, Vector3(cx, ROAD_Y + h * 0.5, z), Vector3(depth, h, w), walls)
	for s2 in [-1.0, 1.0]:
		var r := _box(root, Vector3(cx, ROAD_Y + h + 1.3, z + s2 * w * 0.27), Vector3(depth, 0.16, w * 0.66), tiles)
		r.rotation.x = s2 * 0.68
	_quad(root, Vector3(LANE + side * (near - 0.03), ROAD_Y + fh * 0.5, z), Vector2(w, fh), -PI * 0.5 * side, front)
	if night:
		var lit := _mat("church_lit", "", Color(1.0, 0.8, 0.5))
		lit.emission_enabled = true
		lit.emission = Color(1.0, 0.7, 0.35) * 0.9
		_quad(root, Vector3(LANE + side * (near - 0.06), ROAD_Y + fh * 0.475, z), Vector2(0.8, 2.4), -PI * 0.5 * side, lit)
	_billboard(root, "apple_tree", 7.5, Vector3(LANE + side * (near - 6.0), ROAD_Y, z + w * 0.5 + 3.0))
	_billboard(root, "cross", 2.6, Vector3(LANE + side * (near - 4.0), ROAD_Y, z - w * 0.5 - 1.5))


func _power_line(root: Node3D) -> void:
	var wood := _mat("pole", TEX_CAMP + "log_bark.png", Color(0.5, 0.42, 0.34), Vector2(1.0, 3.0))
	var x := LANE + 9.0
	for k in 2:
		var z := -10.0 - k * 30.0
		_box(root, Vector3(x, ROAD_Y + 4.0, z), Vector3(0.22, 8.0, 0.22), wood)
		_box(root, Vector3(x, ROAD_Y + 7.6, z), Vector3(1.6, 0.12, 0.12), wood)
	var wire := _mat("wire", "", Color(0.12, 0.12, 0.12))
	for dx in [-0.7, 0.0, 0.7]:
		_box(root, Vector3(x + dx, ROAD_Y + 7.4, -PIECE * 0.5), Vector3(0.02, 0.02, PIECE), wire)


func _shelter(root: Node3D, z: float) -> void:
	var concrete := _mat("stop", TEX_TOWN + "stop_concrete.png", Color(0.8, 0.78, 0.74), Vector2(1.0, 1.0))
	_box(root, Vector3(5.6, ROAD_Y + 1.2, z), Vector3(0.18, 2.4, 4.2), concrete)
	_box(root, Vector3(4.8, ROAD_Y + 2.5, z), Vector3(2.0, 0.18, 4.6), concrete)
	_box(root, Vector3(4.8, ROAD_Y + 1.2, z - 2.0), Vector3(1.6, 2.4, 0.16), concrete)
	_box(root, Vector3(4.8, ROAD_Y + 1.2, z + 2.0), Vector3(1.6, 2.4, 0.16), concrete)


## At night in the forest, once a ride at most: somebody standing by the road, pale,
## facing the bus. Nobody else on the bus turns round.
func _figure(root: Node3D) -> void:
	_figure_done = true
	var tex_path := "res://assets/textury/npc/enemy_tourist.png"
	if not ResourceLoader.exists(tex_path):
		return
	var s := Sprite3D.new()
	s.texture = load(tex_path)
	s.pixel_size = 0.018
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.modulate = Color(0.62, 0.66, 0.7)
	s.position = Vector3(LANE + _rng.randf_range(7.0, 8.5) * (1.0 if _rng.randf() < 0.5 else -1.0), ROAD_Y + 1.0, -_rng.randf_range(10.0, 50.0))
	root.add_child(s)


# ── traffic ──────────────────────────────────────────────────────────────────

## Now and then a car the other way (a box with lights), at night only its lights first.
func _update_cars(dist: float, delta: float) -> void:
	_car_t -= delta
	if _car_t <= 0.0 and dist > 0.05:
		_car_t = _rng.randf_range(7.0, 16.0)
		_spawn_car()
	for c in _cars:
		var n: Node3D = c["node"]
		n.position.z += dist + float(c["speed"]) * delta
	while not _cars.is_empty() and (_cars[0]["node"] as Node3D).position.z > BEHIND:
		(_cars[0]["node"] as Node).queue_free()
		_cars.pop_front()


func _spawn_car() -> void:
	var car := Node3D.new()
	var colours := [Color(0.82, 0.8, 0.7), Color(0.5, 0.12, 0.1), Color(0.18, 0.3, 0.5), Color(0.3, 0.4, 0.22), Color(0.82, 0.62, 0.18)]
	var paint := _mat("car_%d" % (_rng.randi() % colours.size()), "", colours[_rng.randi() % colours.size()])
	_box(car, Vector3(0, 0.55, 0), Vector3(1.6, 0.6, 4.0), paint)
	_box(car, Vector3(0, 1.05, 0.3), Vector3(1.4, 0.45, 2.0), _mat("car_glass", "", Color(0.14, 0.16, 0.18)))
	var lamp := _mat("car_lamp", "", Color(1.0, 0.95, 0.8))
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.7) * (3.0 if night else 0.3)
	for x in [-0.6, 0.6]:
		_box(car, Vector3(x, 0.6, 2.01), Vector3(0.3, 0.16, 0.02), lamp)
		for zz in [-1.0, 1.0]:
			_box(car, Vector3(x * 1.3, 0.3, zz * 1.3), Vector3(0.22, 0.56, 0.56), _mat("tyre", "", Color(0.06, 0.06, 0.06)))
	if night:
		var beam := SpotLight3D.new()
		beam.light_color = Color(1.0, 0.9, 0.7)
		beam.light_energy = 3.0
		beam.spot_range = 30.0
		beam.spot_angle = 28.0
		beam.position = Vector3(0, 0.7, 2.2)
		car.add_child(beam)
	# The other lane, coming towards the bus (+Z), facing it.
	car.position = Vector3(LANE - 1.5, ROAD_Y, -AHEAD)
	add_child(car)
	_cars.append({"node": car, "speed": _rng.randf_range(10.0, 16.0)})
