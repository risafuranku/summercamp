extends Node3D

## What goes past the windows of the bus (scripts/town/bus_ride.gd): the bus stands at
## the origin facing -Z and the land comes at it. The road is laid in 60 m pieces ahead
## and dropped behind, each piece of a kind the route asks for at that distance: the
## forest, the reservoir by the dam, fields with a power line and poplars, the first
## houses, Lesna. The other way round going back to the camp. Trees are the camp's own
## meshes (world_generator.gd), houses textured boxes; now and then a car comes the
## other way, at night with its lights on, and at night not everything by the road is a
## tree.

const PIECE := 60.0
const AHEAD := 360.0
const BEHIND := 90.0
const ROAD_Y := -0.95
## The middle of the road: the bus keeps to the right half of it.
const LANE := -1.5
const TEX_CAMP := "res://assets/textury/camp/"
const TEX_TOWN := "res://assets/textury/town/"
## The route out from the camp, a kind per piece (reversed on the way back).
const ROUTE := ["camp", "forest", "forest", "lake", "lake", "forest", "forest", "fields", "fields", "poles", "fields", "edge", "village", "village", "town", "town"]

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
	travelled = 0.0
	_next_at = -BEHIND
	_figure_done = false
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
	_fill()
	_update_cars(dist, delta)


func _kind_at(at: float) -> String:
	var i := int(floorf(at / PIECE))
	if i < 0:
		return ROUTE[0] if to_town else ROUTE[ROUTE.size() - 1]
	if i >= ROUTE.size():
		return "end"
	return ROUTE[i] if to_town else ROUTE[ROUTE.size() - 1 - i]


func _fill() -> void:
	while _next_at < travelled + AHEAD:
		var node := _build_piece(_kind_at(_next_at), _next_at)
		add_child(node)
		node.position.z = travelled - _next_at
		_pieces.append({"node": node, "at": _next_at})
		_next_at += PIECE


# ── the pieces ───────────────────────────────────────────────────────────────

## A piece spans z from 0 (its start, nearest) to -PIECE in its own frame.
func _build_piece(kind: String, at: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Piece_%s" % kind
	# The stop you start from and the stop you stop at: a shelter where the bus stands.
	var idx := int(floorf(at / PIECE))
	if (at <= 0.0 and at + PIECE > 0.0) or idx == ROUTE.size() - 1:
		_shelter(root, -30.0)
	var ground := "grass"
	match kind:
		"forest", "camp", "lake":
			ground = "forest"
		"fields", "poles":
			ground = "field"
	_ground(root, ground, kind)
	if kind != "camp":
		_road(root)
	else:
		_gravel(root)
	match kind:
		"camp":
			_trees(root, -1.0, 4.5, 50.0, 70)
			_trees(root, 1.0, 4.5, 50.0, 70)
		"forest":
			_trees(root, -1.0, 4.5, 60.0, 80)
			_trees(root, 1.0, 4.5, 60.0, 80)
			if night and not _figure_done and _rng.randf() < 0.18:
				_figure(root)
		"lake":
			# The reservoir on the left going out (on the right coming back): water to a
			# far shore of forest; trees only on the other side.
			var water_side := -1.0 if to_town else 1.0
			_water(root, water_side)
			_trees(root, -water_side, 4.5, 50.0, 60)
			_trees(root, water_side, 140.0, 190.0, 50)
			_rail(root, water_side)
		"fields":
			_poplars(root, 1.0 if int(at / PIECE) % 2 == 0 else -1.0)
			_trees(root, -1.0, 90.0, 160.0, 18)
			_trees(root, 1.0, 90.0, 160.0, 18)
		"poles":
			_power_line(root)
			_trees(root, -1.0, 100.0, 160.0, 14)
		"edge":
			_trees(root, -1.0, 6.0, 40.0, 30)
			_houses(root, 1.0, 2)
			_sign(root, "LESNA" if to_town else "CERNE JEZERO 6")
		"village":
			_houses(root, -1.0, 3)
			_houses(root, 1.0, 3)
			_trees(root, -1.0, 30.0, 70.0, 10)
		"town", "end":
			_houses(root, -1.0, 4)
			_houses(root, 1.0, 3)
	return root


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


func _box(root: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	root.add_child(mi)
	return mi


func _ground(root: Node3D, kind: String, piece: String) -> void:
	var w := 400.0
	match kind:
		"forest":
			_plane(root, Vector3(0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w, PIECE), _mat("forest", TEX_TOWN + "forest_floor.png", Color(0.62, 0.6, 0.52), Vector2(w / 6.0, PIECE / 6.0)))
		"field":
			# Stubble one side, ploughed the other (the same texture, two tints).
			_plane(root, Vector3(-w * 0.25 - 4.0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w * 0.5, PIECE), _mat("stubble", TEX_TOWN + "field_stubble.png", Color(1.0, 1.0, 0.95), Vector2(w / 10.0, PIECE / 10.0)))
			_plane(root, Vector3(w * 0.25 + 4.0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w * 0.5, PIECE), _mat("plough", TEX_TOWN + "field_plough.png", Color(0.95, 0.95, 0.95), Vector2(w / 10.0, PIECE / 10.0)))
		_:
			_plane(root, Vector3(0, ROAD_Y - 0.02, -PIECE * 0.5), Vector2(w, PIECE), _mat("grass", TEX_CAMP + "pitch_grass.png", Color(0.9, 0.92, 0.8), Vector2(w / 8.0, PIECE / 8.0)))
	# Verges either side of the road.
	if piece != "camp":
		for side in [-1.0, 1.0]:
			_plane(root, Vector3(LANE + side * 4.2, ROAD_Y - 0.01, -PIECE * 0.5), Vector2(2.4, PIECE), _mat("verge", TEX_CAMP + "gravel_road.png", Color(0.62, 0.58, 0.5), Vector2(1.0, PIECE / 2.4)))


func _road(root: Node3D) -> void:
	var asphalt := _mat("asphalt", TEX_CAMP + "gravel_road.png", Color(0.42, 0.42, 0.44), Vector2(1.0, PIECE / 6.0))
	_plane(root, Vector3(LANE, ROAD_Y, -PIECE * 0.5), Vector2(6.0, PIECE), asphalt)
	# The centre line, dashed.
	var paint := _mat("line", "", Color(0.86, 0.84, 0.76))
	for k in 6:
		_plane(root, Vector3(LANE, ROAD_Y + 0.01, -5.0 - k * 10.0), Vector2(0.12, 3.0), paint)


func _gravel(root: Node3D) -> void:
	_plane(root, Vector3(0, ROAD_Y, -PIECE * 0.5), Vector2(4.6, PIECE), _mat("gravel", TEX_CAMP + "gravel_road.png", Color(0.95, 0.9, 0.82), Vector2(1.0, PIECE / 4.6)))


func _trees(root: Node3D, side: float, from: float, to: float, count: int) -> void:
	if worldgen == null or not worldgen.has_method("_tree_mesh"):
		return
	var spruce: Array[Transform3D] = []
	var birch: Array[Transform3D] = []
	for k in count:
		var off := lerpf(from, to, pow(_rng.randf(), 1.7))
		var p := Vector3(side * off, ROAD_Y, -_rng.randf() * PIECE)
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


## Poplars in a row along the field side of the road.
func _poplars(root: Node3D, side: float) -> void:
	if worldgen == null:
		return
	var list: Array[Transform3D] = []
	for k in 6:
		var p := Vector3(side * 8.0, ROAD_Y, -5.0 - k * 10.0)
		list.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.7, 1.9, 0.7)), p))
	_multi(root, "birch_trunk", worldgen._tree_material("birch_bark", 0), list)
	_multi(root, "birch_crown", worldgen._tree_material("leaf", 2), list)


func _water(root: Node3D, side: float) -> void:
	var water := _mat("water", TEX_CAMP + "lake_water.png", Color(0.6, 0.66, 0.7), Vector2(30.0, 6.0))
	_plane(root, Vector3(side * 75.0, ROAD_Y - 1.2, -PIECE * 0.5), Vector2(140.0, PIECE), water)
	# The bank down to it.
	var bank := _mat("bank", TEX_CAMP + "lake_shore.png", Color(0.8, 0.8, 0.72), Vector2(2.0, PIECE / 4.0))
	var b := _plane(root, Vector3(side * 6.5, ROAD_Y - 0.6, -PIECE * 0.5), Vector2(3.0, PIECE), bank)
	b.rotation.z = side * 0.4


func _rail(root: Node3D, side: float) -> void:
	var steel := _mat("rail", TEX_CAMP + "galvanized.png", Color(0.7, 0.72, 0.7))
	_box(root, Vector3(side * 4.4, ROAD_Y + 0.55, -PIECE * 0.5), Vector3(0.06, 0.25, PIECE), steel)
	for k in 12:
		_box(root, Vector3(side * 4.4, ROAD_Y + 0.3, -2.5 - k * 5.0), Vector3(0.1, 0.6, 0.1), steel)


func _power_line(root: Node3D) -> void:
	var wood := _mat("pole", TEX_CAMP + "log_bark.png", Color(0.5, 0.42, 0.34), Vector2(1.0, 3.0))
	for k in 2:
		var z := -10.0 - k * 30.0
		_box(root, Vector3(7.0, ROAD_Y + 4.0, z), Vector3(0.22, 8.0, 0.22), wood)
		_box(root, Vector3(7.0, ROAD_Y + 7.6, z), Vector3(1.6, 0.12, 0.12), wood)
	var wire := _mat("wire", "", Color(0.12, 0.12, 0.12))
	for x in [6.3, 7.0, 7.7]:
		_box(root, Vector3(x, ROAD_Y + 7.4, -PIECE * 0.5), Vector3(0.02, 0.02, PIECE), wire)


func _houses(root: Node3D, side: float, count: int) -> void:
	var walls := [_mat("roughcast", TEX_CAMP + "roughcast_wall.png", Color(0.95, 0.9, 0.8), Vector2(2.0, 1.0)),
		_mat("brick", TEX_CAMP + "brick_red.png", Color(0.95, 0.9, 0.85), Vector2(2.0, 1.0)),
		_mat("plaster", TEX_CAMP + "plaster_stone.png", Color(0.95, 0.92, 0.85), Vector2(2.0, 1.0))]
	var roof := _mat("roof", TEX_CAMP + "corrugated_roof.png", Color(0.62, 0.32, 0.26), Vector2(3.0, 2.0))
	var lit := _mat("window_lit", "", Color(1.0, 0.82, 0.5))
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.75, 0.4) * 1.6
	var dark := _mat("window_dark", "", Color(0.12, 0.14, 0.16))
	for k in count:
		var z := -6.0 - k * (PIECE / float(count)) - _rng.randf() * 4.0
		var off := _rng.randf_range(11.0, 18.0)
		var size := Vector3(_rng.randf_range(7.0, 10.0), _rng.randf_range(3.6, 5.2), _rng.randf_range(6.0, 8.0))
		_box(root, Vector3(side * (off + size.x * 0.5), ROAD_Y + size.y * 0.5, z), size, walls[_rng.randi() % walls.size()])
		_box(root, Vector3(side * (off + size.x * 0.5), ROAD_Y + size.y + 0.9, z), Vector3(size.x + 0.6, 1.8, size.z * 0.72), roof)
		# Two windows on the side facing the road; at night one or both lit.
		for wz in [-size.z * 0.25, size.z * 0.25]:
			var on := night and _rng.randf() < 0.6
			var win := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(1.1, 1.2)
			win.mesh = q
			win.material_override = lit if on else dark
			win.position = Vector3(side * (off - 0.02), ROAD_Y + size.y * 0.55, z + wz)
			win.rotation.y = -PI * 0.5 * side
			root.add_child(win)
		# A garden fence along the road.
		var fence := _mat("fence", TEX_CAMP + "planks_grey.png", Color(0.8, 0.78, 0.7), Vector2(4.0, 1.0))
		_box(root, Vector3(side * (off - 3.0), ROAD_Y + 0.5, z), Vector3(0.06, 1.0, size.z + 3.0), fence)


func _shelter(root: Node3D, z: float) -> void:
	var concrete := _mat("stop", TEX_TOWN + "stop_concrete.png", Color(0.8, 0.78, 0.74), Vector2(1.0, 1.0))
	_box(root, Vector3(5.6, ROAD_Y + 1.2, z), Vector3(0.18, 2.4, 4.2), concrete)
	_box(root, Vector3(4.8, ROAD_Y + 2.5, z), Vector3(2.0, 0.18, 4.6), concrete)
	_box(root, Vector3(4.8, ROAD_Y + 1.2, z - 2.0), Vector3(1.6, 2.4, 0.16), concrete)
	_box(root, Vector3(4.8, ROAD_Y + 1.2, z + 2.0), Vector3(1.6, 2.4, 0.16), concrete)


func _sign(root: Node3D, text: String) -> void:
	var post := _mat("signpost", "", Color(0.4, 0.42, 0.4))
	_box(root, Vector3(4.6, ROAD_Y + 1.1, -20.0), Vector3(0.08, 2.2, 0.08), post)
	_box(root, Vector3(4.6, ROAD_Y + 2.1, -20.0), Vector3(0.05, 0.5, 1.4), _mat("signboard", "", Color(0.95, 0.85, 0.2)))
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/jersey10.fnt")
	label.font_size = 32
	label.pixel_size = 0.004
	label.modulate = Color(0.06, 0.06, 0.08)
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = Vector3(4.6 + 0.03, ROAD_Y + 2.1, -20.0)
	label.rotation.y = PI * 0.5
	root.add_child(label)


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
	s.position = Vector3(_rng.randf_range(5.5, 7.0) * (1.0 if _rng.randf() < 0.5 else -1.0), ROAD_Y + 1.0, -_rng.randf_range(10.0, 50.0))
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
			var wheel := _box(car, Vector3(x * 1.3, 0.3, zz * 1.3), Vector3(0.22, 0.56, 0.56), _mat("tyre", "", Color(0.06, 0.06, 0.06)))
			wheel.name = "Wheel"
	if night:
		var beam := SpotLight3D.new()
		beam.light_color = Color(1.0, 0.9, 0.7)
		beam.light_energy = 3.0
		beam.spot_range = 30.0
		beam.spot_angle = 28.0
		beam.position = Vector3(0, 0.7, 2.2)
		beam.rotation.y = 0.0
		car.add_child(beam)
	# The other lane, coming towards the bus (+Z), facing it.
	car.position = Vector3(LANE - 1.5, ROAD_Y, -AHEAD)
	car.rotation.y = 0.0
	add_child(car)
	_cars.append({"node": car, "speed": _rng.randf_range(10.0, 16.0)})
