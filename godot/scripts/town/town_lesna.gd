extends Node3D

## Lesna, the village down the road where the bus goes (built by town_trip.gd the first
## time you need it, far off in the same world: ORIGIN). A road runs east-west through
## it; on the square (the naves) a little pond with the war memorial and benches round
## it, the chapel, the Jednota shop (Lesna 42) with the bus stop for the camp in front of
## it, the pub U Jezera, and the other side of the road the stop for Hlubocany, the
## motel and, at the east end where the road meets the main road, the petrol station.
## Houses in between, gardens, a forest all round and hills; invisible walls keep you to
## the village. Buildings are textured boxes (Grok faces in assets/textury/town/).
##
## Local frame: x east, z south (the road along x at z = 0, north side -z).

const TEX := "res://assets/textury/town/"
const PEOPLE_SCRIPT = preload("res://scripts/town/town_people.gd")
const PUMP_JOB = preload("res://scripts/town/pump_job.gd")
const TEX_CAMP := "res://assets/textury/camp/"
const ORIGIN := Vector3(4200.0, 0.0, 0.0)
## The walkable village: x and z extents.
const BOUND := Rect2(-70.0, -46.0, 150.0, 84.0)
const ROAD_HALF := 3.4

var worldgen: Node
var _rng := RandomNumberGenerator.new()
var _chimneys: Array = []
var _smoke: Array = []           # Sprite3D puffs
var _smoke_t := 0.0
var _hour := 12.0
var _mats: Dictionary = {}
## Things town_trip.gd looks for, by name: doors and people get added in stage C.
var spots: Dictionary = {}


func build(p_worldgen: Node) -> void:
	name = "Lesna"
	worldgen = p_worldgen
	_rng.seed = 42
	position = ORIGIN
	_ground()
	_roads()
	_walls()
	_square()
	_jednota(Vector3(-6.0, 0, -15.0))
	_pub(Vector3(16.0, 0, -15.5))
	_chapel(Vector3(-28.0, 0, -22.0))
	_motel(Vector3(-24.0, 0, 15.0))
	_station(Vector3(48.0, 0, 13.0))
	_houses()
	_stop_north()
	_stop_south()
	_lamps()
	_forest()
	_hotspots()
	_build_smoke()
	var people = PEOPLE_SCRIPT.new()
	add_child(people)
	people.build()
	spots["people"] = people
	var job = PUMP_JOB.new()
	add_child(job)
	var local_pumps: Array = []
	for pw in spots.get("pumps", []):
		local_pumps.append((pw as Vector3) - ORIGIN)
	job.setup(local_pumps)
	spots["job"] = job


# ── where things are (world space) ───────────────────────────────────────────

func w(local: Vector3) -> Vector3:
	return ORIGIN + local


## The bus to the camp ("to_camp") stands on the south side by the shelter, facing east
## (it came from Hlubocany in the west and goes on east to the main road and the camp);
## the one from the camp to Hlubocany ("to_hlub") stops on the north side, by the square,
## facing west. Right-hand traffic: the doors are on the kerb side.
func bus_pose(stop: String) -> Transform3D:
	if stop == "to_camp":
		return Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), w(Vector3(-2.0, 0, 1.6)))
	return Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), w(Vector3(8.0, 0, -1.6)))


func bus_arrive_path(stop: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var end := bus_pose(stop).origin
	var dir := 1.0 if stop == "to_camp" else -1.0
	for k in [-140.0, -90.0, -40.0, -14.0, 0.0]:
		out.append(end + Vector3(dir * k, 0, 0))
	return out


func bus_leave_path(stop: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var start := bus_pose(stop).origin
	var dir := 1.0 if stop == "to_camp" else -1.0
	for k in [0.0, 14.0, 40.0, 90.0, 150.0]:
		out.append(start + Vector3(dir * k, 0, 0))
	return out


## Where you are put off the bus from the camp: on the square's side, facing it.
func arrive_spot() -> Transform3D:
	var pos := w(Vector3(9.0, 0.15, -4.6))
	return Transform3D(Basis.looking_at(Vector3(-0.75, 0, -1), Vector3.UP), pos)


## Where you wait for the bus to the camp, in the shelter's mouth across the road.
func wait_spot() -> Transform3D:
	var pos := w(Vector3(-2.0, 0.15, 4.6))
	return Transform3D(Basis.looking_at(Vector3(-1, 0, -0.3), Vector3.UP), pos)


# ── materials and boxes ─────────────────────────────────────────────────────

func _mat(path: String, tint: Color, uv := Vector2.ONE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [path, tint, uv]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_color = tint
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	elif path != "":
		m.albedo_color = tint.darkened(0.1)
	_mats[key] = m
	return m


func _first(paths: Array) -> String:
	for p in paths:
		if ResourceLoader.exists(str(p)):
			return str(p)
	return ""


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	if solid:
		_solid(parent, pos, size)
	return mi


func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	return body


## A textured quad facing `facing` (one of the four directions, in the local frame).
func _face(parent: Node3D, pos: Vector3, size: Vector2, facing: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos + facing * 0.01
	mi.rotation.y = atan2(facing.x, facing.z)
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _plane(parent: Node3D, pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sign(parent: Node3D, pos: Vector3, facing: Vector3, text: String, size := 40, col := Color(0.08, 0.08, 0.1)) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/jersey10.fnt")
	label.font_size = size
	label.pixel_size = 0.004
	label.modulate = col
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = pos + facing * 0.03
	label.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(label)
	return label


# ── the land ────────────────────────────────────────────────────────────────

func _ground() -> void:
	var grass := _mat(TEX_CAMP + "pitch_grass.png", Color(0.86, 0.88, 0.74), Vector2(120.0, 120.0))
	var g := _plane(self, Vector3(0, -0.02, 0), Vector2(480, 480), grass)
	g.add_to_group("season_ground")
	_solid(self, Vector3(BOUND.get_center().x, -0.5, BOUND.get_center().y), Vector3(BOUND.size.x + 4.0, 1.0, BOUND.size.y + 4.0))


func _roads() -> void:
	var asphalt := _mat(_first([TEX + "asphalt.png", TEX_CAMP + "gravel_road.png"]), Color(0.62, 0.62, 0.64), Vector2(70.0, 2.0))
	_plane(self, Vector3(0, 0.01, 0), Vector2(480, ROAD_HALF * 2.0), asphalt)
	# The square in front of the shop and the pub, and the station's forecourt.
	var cobbles := _mat(_first([TEX + "cobbles.png", TEX_CAMP + "gravel_road.png"]), Color(0.86, 0.84, 0.8), Vector2(10.0, 4.0))
	_plane(self, Vector3(4.0, 0.012, -8.0), Vector2(46.0, 9.0), cobbles)
	_plane(self, Vector3(48.0, 0.012, 9.0), Vector2(26.0, 12.0), _mat(_first([TEX + "asphalt.png"]), Color(0.7, 0.7, 0.7), Vector2(6.0, 3.0)))
	# Kerbs.
	var kerb := _mat("", Color(0.6, 0.6, 0.58))
	for z in [-ROAD_HALF, ROAD_HALF]:
		_box(self, Vector3(0, 0.05, z), Vector3(480, 0.1, 0.2), kerb)


## The village ends where the gardens and the forest start: walls you do not see.
func _walls() -> void:
	var r := BOUND
	var lines := [[Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y)],
		[Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y)],
		[Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)],
		[Vector3(r.position.x, 0, r.end.y), Vector3(r.position.x, 0, r.position.y)]]
	for l in lines:
		var a: Vector3 = l[0]
		var b: Vector3 = l[1]
		var body := _solid(self, (a + b) * 0.5 + Vector3(0, 2.0, 0), Vector3(0.4, 4.0, a.distance_to(b) + 0.4))
		body.rotation.y = atan2(b.x - a.x, b.z - a.z)


## The square: a pond in a low stone rim, the war memorial, benches, a lime tree.
func _square() -> void:
	var stone := _mat(TEX_CAMP + "plaster_stone.png", Color(0.82, 0.8, 0.76), Vector2(3.0, 1.0))
	var pond := Vector3(-14.0, 0, -32.0)
	_plane(self, pond + Vector3(0, 0.05, 0), Vector2(14.0, 9.0), _mat(TEX_CAMP + "lake_water.png", Color(0.6, 0.66, 0.66), Vector2(3.0, 2.0)))
	for side in [[Vector3(0, 0.2, -4.6), Vector3(14.4, 0.4, 0.3)], [Vector3(0, 0.2, 4.6), Vector3(14.4, 0.4, 0.3)], [Vector3(-7.1, 0.2, 0), Vector3(0.3, 0.4, 9.2)], [Vector3(7.1, 0.2, 0), Vector3(0.3, 0.4, 9.2)]]:
		_box(self, pond + side[0], side[1], stone, true)
	spots["pond"] = w(pond)
	# The memorial: a stone with a cross and the names.
	var mem := Vector3(4.0, 0, -28.0)
	_box(self, mem + Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 1.4), stone, true)
	_box(self, mem + Vector3(0, 1.3, 0), Vector3(1.0, 2.0, 0.5), _mat(TEX_CAMP + "plaster_stone.png", Color(0.7, 0.7, 0.68)), true)
	_box(self, mem + Vector3(0, 2.6, 0), Vector3(0.12, 0.7, 0.12), stone)
	_box(self, mem + Vector3(0, 2.75, 0), Vector3(0.5, 0.12, 0.12), stone)
	_sign(self, mem + Vector3(0, 1.4, 0.25), Vector3(0, 0, 1), "1914 - 1918\n1939 - 1945", 22, Color(0.2, 0.18, 0.16))
	spots["memorial"] = w(mem)
	# Benches round the pond.
	var planks := _mat(TEX_CAMP + "planks_grey.png", Color(0.7, 0.62, 0.5))
	for b in [Vector3(-14.0, 0, -26.2), Vector3(-22.6, 0, -32.0), Vector3(-5.6, 0, -32.0)]:
		_box(self, b + Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.45), planks, true)
		_box(self, b + Vector3(0, 0.75, 0.2), Vector3(1.8, 0.4, 0.06), planks)
	spots["bench"] = w(Vector3(-14.0, 0, -26.2))
	# A big lime tree by the memorial (the camp's birch, scaled up).
	if worldgen != null and worldgen.has_method("_tree_mesh"):
		for part in [["birch_trunk", worldgen._tree_material("bark", 0)], ["birch_crown", worldgen._tree_material("leaf", 0)]]:
			var mi := MeshInstance3D.new()
			mi.mesh = worldgen._tree_mesh(str(part[0]))
			mi.material_override = part[1]
			mi.position = Vector3(8.5, 0, -30.0)
			mi.scale = Vector3(2.4, 2.0, 2.4)
			add_child(mi)


# ── buildings ───────────────────────────────────────────────────────────────

## The material with its texture repeated about every 2.5 m on a box this size. A
## BoxMesh lays its six faces out 3 x 2 on the texture, so a scale of (3, 2) shows it once
## per face; more is that many times again.
func _tiled(base: Material, size: Vector3) -> Material:
	var m := base as StandardMaterial3D
	if m == null or m.albedo_texture == null:
		return base
	var nx := maxf(1.0, roundf(maxf(size.x, size.z) / 2.5))
	var ny := maxf(1.0, roundf(size.y / 2.5))
	var key := "%s|tiled|%s|%s" % [m.get_instance_id(), nx, ny]
	if _mats.has(key):
		return _mats[key]
	var t := m.duplicate() as StandardMaterial3D
	t.uv1_scale = Vector3(3.0 * nx, 2.0 * ny, 1.0)
	_mats[key] = t
	return t


## A house-like block: walls, a pitched (or flat) roof, solid. Returns its root.
func _block(at: Vector3, size: Vector3, wall: Material, roof: String = "pitched") -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_box(root, Vector3(0, size.y * 0.5, 0), size, _tiled(wall, size), true)
	var tiles := _tiled(_mat(_first([TEX + "roof_tiles.png", TEX_CAMP + "corrugated_roof.png"]), Color(0.7, 0.4, 0.3)), Vector3(size.x, 3.0, size.z * 0.6))
	if roof == "pitched":
		for side in [-1.0, 1.0]:
			var r := _box(root, Vector3(0, size.y + size.z * 0.18, side * size.z * 0.25), Vector3(size.x + 0.5, 0.14, size.z * 0.6), tiles)
			r.rotation.x = side * 0.62
		# Gable ends.
		for end in [-1.0, 1.0]:
			var g := _box(root, Vector3(end * size.x * 0.5, size.y + size.z * 0.16, 0), Vector3(0.1, size.z * 0.34, size.z * 0.55), wall)
			g.rotation.x = 0.0
	else:
		_box(root, Vector3(0, size.y + 0.1, 0), Vector3(size.x + 0.3, 0.2, size.z + 0.3), _mat("", Color(0.32, 0.3, 0.28)))
	return root


func _jednota(at: Vector3) -> void:
	var wall := _mat(TEX_CAMP + "concrete.png", Color(0.86, 0.84, 0.8), Vector2(3.0, 1.0))
	var size := Vector3(16.0, 4.0, 10.0)
	var root := _block(at, size, wall, "flat")
	var front := _mat(_first([TEX + "shop_front.png"]), Color(0.7, 0.72, 0.74))
	_face(root, Vector3(0, 2.0, size.z * 0.5), Vector2(7.1, 4.0), Vector3(0, 0, 1), front)
	# The sign along the top: JEDNOTA in red on white.
	_box(root, Vector3(0, 3.55, size.z * 0.5 + 0.06), Vector3(9.0, 0.7, 0.1), _mat("", Color(0.92, 0.9, 0.86)))
	_sign(root, Vector3(0, 3.55, size.z * 0.5 + 0.12), Vector3(0, 0, 1), "JEDNOTA   SAMOOBSLUHA", 52, Color(0.72, 0.08, 0.06))
	spots["jednota_door"] = w(at + Vector3(0, 0, size.z * 0.5 + 1.2))
	spots["jednota"] = root


func _pub(at: Vector3) -> void:
	var wall := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(0.78, 0.86, 0.74), Vector2(3.0, 1.0))
	var size := Vector3(14.0, 4.6, 10.0)
	var root := _block(at, size, wall)
	_face(root, Vector3(0, 2.3, size.z * 0.5), Vector2(8.2, 4.6), Vector3(0, 0, 1), _mat(_first([TEX + "pub_front.png"]), Color(0.6, 0.66, 0.56)))
	_box(root, Vector3(0, 3.7, size.z * 0.5 + 0.06), Vector3(6.0, 0.6, 0.1), _mat("", Color(0.2, 0.18, 0.14)))
	_sign(root, Vector3(0, 3.7, size.z * 0.5 + 0.12), Vector3(0, 0, 1), "HOSTINEC U JEZERA", 44, Color(0.95, 0.85, 0.6))
	spots["pub_door"] = w(at + Vector3(0, 0, size.z * 0.5 + 1.2))
	spots["pub"] = root


func _chapel(at: Vector3) -> void:
	var wall := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(0.95, 0.92, 0.84), Vector2(2.0, 1.0))
	var root := _block(at, Vector3(5.0, 5.0, 7.0), wall)
	_box(root, Vector3(0, 7.0, -2.5), Vector3(1.6, 3.6, 1.6), wall, false)
	_box(root, Vector3(0, 9.2, -2.5), Vector3(0.12, 0.9, 0.12), _mat("", Color(0.3, 0.3, 0.3)))
	_box(root, Vector3(0, 9.4, -2.5), Vector3(0.5, 0.1, 0.1), _mat("", Color(0.3, 0.3, 0.3)))
	_face(root, Vector3(0, 1.3, 3.5), Vector2(1.4, 2.6), Vector3(0, 0, 1), _mat(_first([TEX + "house_door.png", TEX_CAMP + "door_wood.png"]), Color(0.4, 0.3, 0.2)))
	spots["chapel"] = w(at + Vector3(0, 0, 4.5))


func _motel(at: Vector3) -> void:
	var wall := _mat(TEX_CAMP + "concrete.png", Color(0.9, 0.84, 0.72), Vector2(4.0, 2.0))
	var size := Vector3(22.0, 6.4, 9.0)
	var root := _block(at, size, wall, "flat")
	# Its front faces the road (north, -z).
	_face(root, Vector3(0, 3.2, -size.z * 0.5), Vector2(22.0, 6.4), Vector3(0, 0, -1), _mat(_first([TEX + "motel_front.png"]), Color(0.7, 0.6, 0.5), Vector2(2.0, 1.0)))
	_box(root, Vector3(-6.0, 6.9, -size.z * 0.5 - 0.3), Vector3(7.0, 0.9, 0.12), _mat("", Color(0.16, 0.18, 0.3)))
	var neon := _sign(root, Vector3(-6.0, 6.9, -size.z * 0.5 - 0.38), Vector3(0, 0, -1), "MOTEL  LESNA", 64, Color(1.0, 0.36, 0.3))
	neon.name = "MotelSign"
	spots["motel_sign"] = neon
	spots["motel_door"] = w(at + Vector3(-6.0, 0, -size.z * 0.5 - 1.2))
	spots["motel"] = root


func _station(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	# The canopy on four pillars over two pumps, the kiosk behind.
	var steel := _mat("", Color(0.86, 0.86, 0.84))
	for p in [Vector3(-6, 0, -3), Vector3(6, 0, -3), Vector3(-6, 0, 3), Vector3(6, 0, 3)]:
		_box(root, p + Vector3(0, 2.4, 0), Vector3(0.3, 4.8, 0.3), steel, true)
	_box(root, Vector3(0, 5.0, 0), Vector3(14.0, 0.5, 8.0), _mat("", Color(0.9, 0.9, 0.88)))
	_box(root, Vector3(0, 4.9, -4.02), Vector3(14.0, 0.5, 0.06), _mat("", Color(0.82, 0.1, 0.08)))
	_sign(root, Vector3(0, 4.9, -4.06), Vector3(0, 0, -1), "BENZINA", 56, Color(0.98, 0.95, 0.9))
	var pump_face := _mat(_first([TEX + "fuel_pump.png"]), Color(0.8, 0.2, 0.15))
	var pumps: Array = []
	for x in [-2.6, 2.6]:
		var island := _box(root, Vector3(x, 0.1, 0), Vector3(1.4, 0.2, 3.0), _mat("", Color(0.6, 0.6, 0.6)), true)
		island.name = "Island"
		var body := _box(root, Vector3(x, 1.0, 0), Vector3(0.9, 1.7, 0.6), _mat("", Color(0.8, 0.22, 0.16)), true)
		_face(root, Vector3(x, 1.0, -0.3), Vector2(0.9, 1.7), Vector3(0, 0, -1), pump_face)
		_face(root, Vector3(x, 1.0, 0.3), Vector2(0.9, 1.7), Vector3(0, 0, 1), pump_face)
		pumps.append(w(at + Vector3(x, 0, -1.2)))
		body.name = "Pump"
	spots["pumps"] = pumps
	var kiosk := Node3D.new()
	kiosk.position = Vector3(0, 0, 9.0)
	root.add_child(kiosk)
	_box(kiosk, Vector3(0, 1.6, 0), Vector3(10.0, 3.2, 6.0), _mat(TEX_CAMP + "concrete.png", Color(0.9, 0.9, 0.88), Vector2(3.0, 1.0)), true)
	_box(kiosk, Vector3(0, 3.3, 0), Vector3(10.4, 0.2, 6.4), _mat("", Color(0.3, 0.3, 0.3)))
	_face(kiosk, Vector3(0, 1.6, -3.0), Vector2(5.7, 3.2), Vector3(0, 0, -1), _mat(_first([TEX + "kiosk_front.png"]), Color(0.7, 0.72, 0.74)))
	spots["kiosk_door"] = w(at + Vector3(0, 0, 9.0 - 4.2))
	spots["station"] = root


## Houses along the road and round the square, each with a window or two and a door.
func _houses() -> void:
	var walls := [_mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(1.0, 0.95, 0.85), Vector2(3.0, 1.0)),
		_mat(TEX_CAMP + "brick_red.png", Color(0.95, 0.9, 0.85), Vector2(3.0, 1.0)),
		_mat(_first([TEX + "village_plaster.png", TEX_CAMP + "roughcast_wall.png"]), Color(0.9, 0.95, 1.0), Vector2(3.0, 1.0))]
	var window := _mat(_first([TEX + "house_window.png", TEX_CAMP + "window_curtain.png"]), Color(0.6, 0.66, 0.7))
	# The same window with the light on behind the curtain (multiply: the picture shows,
	# warmed and brighter), for the evenings.
	var lit := (window as StandardMaterial3D).duplicate() as StandardMaterial3D
	lit.emission_enabled = true
	lit.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	lit.emission_texture = lit.albedo_texture
	lit.emission = Color(1.0, 0.78, 0.45)
	lit.emission_energy_multiplier = 1.4
	var lit_windows: Array = []
	var door := _mat(_first([TEX + "house_door.png", TEX_CAMP + "door_wood.png"]), Color(0.42, 0.3, 0.2))
	var places := [[Vector3(-44, 0, -16), 1.0], [Vector3(34, 0, -17), 1.0], [Vector3(-48, 0, 16), -1.0], [Vector3(10, 0, 19), -1.0], [Vector3(-60, 0, -18), 1.0], [Vector3(68, 0, -16), 1.0], [Vector3(-36, 0, -36), 1.0], [Vector3(30, 0, -34), 1.0]]
	for p in places:
		var at: Vector3 = p[0]
		var facing := Vector3(0, 0, float(p[1]))
		var size := Vector3(_rng.randf_range(9.0, 12.0), _rng.randf_range(3.6, 4.4), _rng.randf_range(7.0, 8.5))
		var root := _block(at, size, walls[_rng.randi() % walls.size()])
		var fz := size.z * 0.5 * facing.z
		for wx in [-size.x * 0.28, size.x * 0.28]:
			var win := _face(root, Vector3(wx, 1.7, fz), Vector2(1.3, 1.3), facing, window)
			# Each window has its own evening: lit from some hour to some hour.
			lit_windows.append({"mesh": win, "on": _rng.randf_range(17.5, 20.5), "off": _rng.randf_range(21.5, 24.5), "dark": window, "lit": lit})
		# A chimney, and smoke from it when somebody has the stove going.
		var chim := Vector3(size.x * 0.3, size.y + size.z * 0.34, -size.z * 0.12)
		_box(root, chim, Vector3(0.6, 1.4, 0.6), _mat(TEX_CAMP + "brick_red.png", Color(0.9, 0.85, 0.8)))
		if _rng.randf() < 0.7:
			_chimneys.append(root.position + chim + Vector3(0, 0.8, 0))
		_face(root, Vector3(0, 1.05, fz), Vector2(1.1, 2.1), facing, door)
		# A picket fence along the front garden.
		spots["lit_windows"] = lit_windows
		var fence := _mat(TEX_CAMP + "planks_grey.png", Color(0.86, 0.84, 0.76), Vector2(6.0, 1.0))
		_box(self, at + Vector3(0, 0.5, fz + facing.z * 3.0), Vector3(size.x + 2.0, 1.0, 0.06), fence, true)


# ── the stops ───────────────────────────────────────────────────────────────

## The stop for the camp: a shelter on the south side, open to the road (its local +z
## faces north).
func _stop_south() -> void:
	var concrete := _mat(_first([TEX + "stop_concrete.png", TEX_CAMP + "concrete.png"]), Color(0.86, 0.84, 0.8))
	var root := Node3D.new()
	root.position = Vector3(-2.0, 0, 6.4)
	root.rotation.y = PI
	add_child(root)
	# The shelter, open to the road (south).
	_box(root, Vector3(0, 1.2, -0.9), Vector3(4.2, 2.4, 0.18), concrete, true)
	_box(root, Vector3(-2.0, 1.2, 0), Vector3(0.16, 2.4, 1.9), concrete, true)
	_box(root, Vector3(2.0, 1.2, 0), Vector3(0.16, 2.4, 1.9), concrete, true)
	_box(root, Vector3(0, 2.5, 0.1), Vector3(4.7, 0.18, 2.5), concrete)
	var planks := _mat(TEX_CAMP + "planks_grey.png", Color(0.7, 0.62, 0.5))
	_box(root, Vector3(0, 0.45, -0.5), Vector3(3.4, 0.06, 0.45), planks)
	_pole(root, Vector3(-2.8, 0, 1.3), "LESNA, JEDNOTA", "town")


## The stop for Hlubocany: only a pole by the square.
func _stop_north() -> void:
	var root := Node3D.new()
	root.position = Vector3(10.0, 0, -5.6)
	add_child(root)
	_pole(root, Vector3(0, 0, 0), "LESNA, JEDNOTA", "town_through")


## A stop pole: the bus sign, the name, a timetable case (clickable).
func _pole(root: Node3D, at: Vector3, stop_name: String, stop_id: String) -> void:
	var grey := _mat("", Color(0.42, 0.44, 0.42))
	_box(root, at + Vector3(0, 1.4, 0), Vector3(0.08, 2.8, 0.08), grey)
	_box(root, at + Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.3), _mat(TEX_CAMP + "concrete.png", Color(0.8, 0.8, 0.78)))
	var sign_mat := _mat(_first([TEX + "stop_sign.png"]), Color(0.9, 0.9, 0.86))
	_box(root, at + Vector3(0, 2.5, 0), Vector3(0.74, 0.56, 0.03), grey)
	for f in [Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		_face(root, at + Vector3(0, 2.5, 0) + f * 0.02, Vector2(0.74, 0.56), f, sign_mat)
		_sign(root, at + Vector3(0, 2.07, 0) + f * 0.025, f, stop_name, 32, Color(0.08, 0.08, 0.1)).pixel_size = 0.0027
	_box(root, at + Vector3(0, 2.07, 0), Vector3(1.1, 0.24, 0.04), _mat("", Color(0.92, 0.9, 0.84)))
	var case_mat := _mat(_first([TEX + "timetable_case.png"]), Color(0.6, 0.62, 0.6))
	_box(root, at + Vector3(0, 1.45, 0.06), Vector3(0.46, 0.62, 0.05), _mat("", Color(0.55, 0.56, 0.55)))
	_face(root, at + Vector3(0, 1.45, 0.09), Vector2(0.46, 0.62), Vector3(0, 0, 1), case_mat)
	var body := StaticBody3D.new()
	body.set_meta("building_type", "trip_timetable")
	body.set_meta("stop", "town")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.8, 0.3)
	shape.shape = box
	body.add_child(shape)
	body.position = at + Vector3(0, 1.45, 0.12)
	root.add_child(body)
	if stop_id == "town_through":
		body.set_meta("stop", "town")


func _lamps() -> void:
	var post := _mat(TEX_CAMP + "concrete.png", Color(0.78, 0.78, 0.76))
	var lights: Array = []
	for x in [-40.0, -12.0, 18.0, 44.0]:
		var at := Vector3(x, 0, -4.2)
		_box(self, at + Vector3(0, 2.6, 0), Vector3(0.16, 5.2, 0.16), post, true)
		_box(self, at + Vector3(0, 5.15, 0.6), Vector3(0.1, 0.1, 1.3), post)
		var bulb := StandardMaterial3D.new()
		bulb.albedo_color = Color(0.6, 0.58, 0.5)
		bulb.emission_enabled = true
		_box(self, at + Vector3(0, 5.05, 1.15), Vector3(0.4, 0.14, 0.3), bulb)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.76, 0.46)
		l.light_energy = 1.8
		l.omni_range = 13.0
		l.position = at + Vector3(0, 4.8, 1.15)
		l.visible = false
		add_child(l)
		lights.append([l, bulb])
	spots["lamps"] = lights


## Forest all round past the gardens, and hills.
func _forest() -> void:
	if worldgen == null or not worldgen.has_method("_tree_mesh"):
		return
	var xf: Array[Transform3D] = []
	for k in 900:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(78.0, 200.0)
		var p := Vector3(cos(ang) * dist * 1.1, 0, sin(ang) * dist * 0.75)
		if absf(p.z) < ROAD_HALF + 2.0:
			continue
		var sc := _rng.randf_range(0.9, 1.8)
		xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.9, 1.3), sc)), p))
	for part in [["spruce_trunk", worldgen._tree_material("bark", 1)], ["spruce_crown", worldgen._tree_material("needles", 1)]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = worldgen._tree_mesh(str(part[0]))
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = part[1]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	# Gardens: a few fruit trees (birches stand in) behind the houses.
	var hill_mat := _mat("", Color(0.28, 0.36, 0.26))
	for k in 8:
		var ang := TAU * float(k) / 8.0 + _rng.randf_range(-0.2, 0.2)
		var hill := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 8
		sphere.rings = 4
		hill.mesh = sphere
		hill.material_override = hill_mat
		hill.scale = Vector3(160.0, 40.0, 120.0)
		hill.position = Vector3(cos(ang) * 330.0, -8.0, sin(ang) * 260.0)
		add_child(hill)


# ── what you click ──────────────────────────────────────────────────────────

## Doors (building_type "town_door", meta "door") and things to read ("town_read").
func _hotspots() -> void:
	_click(Vector3(-6.0, 1.1, -9.9), Vector3(1.8, 2.2, 0.4), "town_door", "jednota")
	_click(Vector3(16.0, 1.2, -10.4), Vector3(1.8, 2.4, 0.4), "town_door", "pub")
	_click(Vector3(-30.0, 1.1, 10.4), Vector3(1.6, 2.2, 0.4), "town_door", "motel")
	_click(Vector3(50.0, 1.1, 18.9), Vector3(1.6, 2.2, 0.4), "town_door", "kiosk")
	_click(Vector3(-28.0, 1.3, -18.4), Vector3(1.6, 2.6, 0.4), "town_door", "chapel")
	_click(Vector3(4.0, 1.4, -27.6), Vector3(1.2, 2.2, 0.8), "town_read", "memorial")
	var pumps: Array = spots.get("pumps", [])
	for i in pumps.size():
		var body := _click((pumps[i] as Vector3) - ORIGIN + Vector3(0, 1.0, 1.2), Vector3(1.0, 1.8, 0.8), "town_pump", "pump")
		body.set_meta("pump", i)


func _click(pos: Vector3, size: Vector3, kind: String, what: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 11
	body.collision_mask = 0
	body.set_meta("building_type", kind)
	body.set_meta("door" if kind != "town_read" else "read", what)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)
	return body


# ── the night ───────────────────────────────────────────────────────────────

## Chimney smoke: a few grey pixel puffs per chimney, rising and leaning with the wind,
## moved in steps.
func _build_smoke() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x - 3.5, y - 3.5).length()
			if d < 2.2 or (d < 3.8 and (x + y) % 2 == 0):
				img.set_pixel(x, y, Color(0.78, 0.78, 0.76, 0.8))
	var tex := ImageTexture.create_from_image(img)
	for c in _chimneys:
		for k in 5:
			var s := Sprite3D.new()
			s.texture = tex
			s.pixel_size = 0.12
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.shaded = false
			s.position = c
			add_child(s)
			_smoke.append({"sprite": s, "base": c, "phase": float(k) / 5.0})


func _process(delta: float) -> void:
	_smoke_t += delta
	var step := floorf(_smoke_t * 12.0) / 12.0
	for p in _smoke:
		var age := fmod(step * 0.22 + float(p["phase"]), 1.0)
		var s: Sprite3D = p["sprite"]
		s.position = (p["base"] as Vector3) + Vector3(age * 1.6, age * 4.5, age * 0.4)
		s.scale = Vector3.ONE * (0.6 + age * 1.8)
		s.modulate = Color(1, 1, 1, (1.0 - age) * 0.7)


## The hour, for the windows (town_trip.gd, now and then).
func set_hour(h: float) -> void:
	_hour = h
	for wdict in spots.get("lit_windows", []):
		var d: Dictionary = wdict
		var on_at: float = d["on"]
		var off_at: float = d["off"]
		var lit := (h >= on_at and h < minf(off_at, 24.0)) or (off_at > 24.0 and h < off_at - 24.0) or (h >= 5.6 and h < 6.6 and on_at < 18.5)
		(d["mesh"] as MeshInstance3D).material_override = d["lit"] if lit else d["dark"]


func set_night(night: bool) -> void:
	for pair in spots.get("lamps", []):
		(pair[0] as OmniLight3D).visible = night
		(pair[1] as StandardMaterial3D).emission = Color(1.0, 0.76, 0.42) * (1.6 if night else 0.0)
	var neon = spots.get("motel_sign", null)
	if neon != null:
		(neon as Label3D).modulate = Color(1.0, 0.3, 0.26) * (1.6 if night else 0.7)
