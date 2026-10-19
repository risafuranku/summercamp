extends Node3D

## Lesna, the village down the road where the bus goes (built by town_trip.gd the first
## time you need it, far off in the same world: ORIGIN). A small piece of a flat
## central Bohemian farming village, after Liblice by Cesky Brod: a road runs east-west
## through it between gabled houses; on its north side the Jednota and the pub U Jezera,
## across the road from them the green (the naves) with its pond, the war memorial, the
## bell pillar and the cross, the bus stop for the camp at its corner; the chapel set
## back, the motel, and at the east end the petrol station. Open fields all round, the
## two masts of the transmitter over the roofs to the west (liblice_masts.gd). Fronts are
## Grok elevations with the house built behind them (lib_*, town_facades.py), lettering
## on the walls from lettering.py; invisible walls keep you to the village.
##
## Local frame: x east, z south (the road along x at z = 0, north side -z).

const TEX := "res://assets/textury/town/"
const PEOPLE_SCRIPT = preload("res://scripts/town/town_people.gd")
const PUMP_JOB = preload("res://scripts/town/pump_job.gd")
## Pavements, paths, fences, the street's things and the life in the yards.
const DRESSING = preload("res://scripts/town/town_dressing.gd")
const ROAD_POST = preload("res://scripts/town/road_post.gd")
var dressing
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
	_road_posts()
	_walls()
	_green()
	_jednota(Vector3(-6.0, 0, -15.0))
	_pub(Vector3(16.0, 0, -15.5))
	_chapel(Vector3(-28.0, 0, -22.0))
	_motel(Vector3(-24.0, 0, 15.0))
	_station(Vector3(48.0, 0, 13.0))
	_houses()
	_stop_north()
	_stop_south()
	_lamps()
	_fields()
	_village_signs()
	_hotspots()
	_build_smoke()
	dressing = DRESSING.new()
	add_child(dressing)
	dressing.build(self)
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


## Where you are put off the bus from the camp: by the Jednota, looking down the street
## with the green across the road and the masts at the end of it.
func arrive_spot() -> Transform3D:
	var pos := w(Vector3(9.0, 0.15, -4.6))
	return Transform3D(Basis.looking_at(Vector3(-1, 0, 0.3), Vector3.UP), pos)


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
	# Unmown village grass (it was the camp's football pitch, stripes and all).
	var grass := _mat(_first([TEX + "village_grass.png", TEX_CAMP + "pitch_grass.png"]), Color(0.78, 0.9, 0.66), Vector2(180.0, 180.0))
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


## The road posts (road_post.gd) from where the village ends, both ways, opposite each
## other every 50 m; none between the houses.
func _road_posts() -> void:
	for x in [-66.0, -116.0, -166.0, -216.0, 76.0, 126.0, 176.0, 226.0]:
		for side in [-1.0, 1.0]:
			ROAD_POST.place(self, Vector3(x, 0.0, side * (ROAD_HALF + 0.6)), Vector3(0, 0, -side))


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
func _block(at: Vector3, size: Vector3, wall: Material, roof: String = "pitched", eternit := false) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_box(root, Vector3(0, size.y * 0.5, 0), size, _tiled(wall, size), true)
	# Clay tiles, or the grey asbestos-cement slates half the village re-roofed with.
	var roof_tex := _first([TEX + "roof_eternit.png", TEX + "roof_tiles.png"]) if eternit else _first([TEX + "roof_tiles.png", TEX_CAMP + "corrugated_roof.png"])
	var tiles := _tiled(_mat(roof_tex, Color(0.7, 0.4, 0.3) if not eternit else Color(0.9, 0.9, 0.9)), Vector3(size.x, 3.0, size.z * 0.6))
	if roof == "pitched":
		for side in [-1.0, 1.0]:
			var r := _box(root, Vector3(0, size.y + size.z * 0.18, side * size.z * 0.25), Vector3(size.x + 0.5, 0.14, size.z * 0.6), tiles)
			r.rotation.x = side * 0.62
		# Gable ends: triangles under the slopes (the ridge is size.z * 0.354 over the
		# walls, less the roof's thickness). They were boxes, whose top corners stood out
		# through the roof at both ends of every house (playtest 18. 10.: "clipping").
		var rise := size.z * 0.354 - 0.1
		for end in [-1.0, 1.0]:
			var g := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(size.z, rise, 0.1)
			g.mesh = pm
			g.material_override = wall
			g.position = Vector3(end * (size.x * 0.5 - 0.05), size.y + rise * 0.5, 0)
			g.rotation.y = PI * 0.5
			root.add_child(g)
	else:
		_box(root, Vector3(0, size.y + 0.1, 0), Vector3(size.x + 0.3, 0.2, size.z + 0.3), _mat("", Color(0.32, 0.3, 0.28)))
	return root


## The Jednota: the 1970s co-op shop with a flat roof, its picture the whole front; on
## the band over the windows the sheet-metal letters JEDNOTA and SAMOOBSLUHA (one of its
## letters fell off years ago), rust down the render under them.
func _jednota(at: Vector3) -> void:
	var wall := _mat(TEX_CAMP + "concrete.png", Color(0.86, 0.84, 0.8), Vector2(3.0, 1.0))
	var built := _flat_house("lib_jednota_front", at, 1.0, 10.0, wall)
	var root: Node3D
	var front_z := 5.0
	if built.is_empty():
		var size := Vector3(16.0, 4.0, 10.0)
		root = _block(at, size, wall, "flat")
		_face(root, Vector3(0, 2.0, size.z * 0.5), Vector2(7.1, 4.0), Vector3(0, 0, 1), _mat(_first([TEX + "shop_front.png"]), Color(0.7, 0.72, 0.74)))
		_letters(root, "jednota", Vector3(-2.4, 3.6, front_z), Vector3(0, 0, 1))
	else:
		root = built[0]
		var h: float = _front_meta("lib_jednota_front")["m"][1]
		_letters(root, "jednota", Vector3(-2.3, h - 0.95, front_z), Vector3(0, 0, 1))
		_letters(root, "samoobsluha", Vector3(2.7, h - 0.82, front_z), Vector3(0, 0, 1))
	spots["jednota_door"] = w(at + Vector3(0, 0, front_z + 1.2))
	spots["jednota"] = root


## The pub U Jezera: an old inn with its eaves to the street, the name painted on the
## plaster over the windows by a signwriter long ago.
func _pub(at: Vector3) -> void:
	var wall := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(0.78, 0.86, 0.74), Vector2(3.0, 1.0))
	var built := _eaves_house("lib_pub_front", at, 1.0, 10.0, wall, 0.12)
	if built.is_empty():
		var size := Vector3(14.0, 4.6, 10.0)
		var root := _block(at, size, wall)
		spots["pub_face"] = _face(root, Vector3(0, 2.3, size.z * 0.5), Vector2(8.2, 4.6), Vector3(0, 0, 1), _mat(_first([TEX + "pub_front.png"]), Color(0.6, 0.66, 0.56)))
		_letters(root, "hostinec", Vector3(0, 3.7, size.z * 0.5), Vector3(0, 0, 1))
		spots["pub"] = root
	else:
		var root: Node3D = built[0]
		var front: Array = built[1]
		var h: float = _front_meta("lib_pub_front")["m"][1]
		_letters(root, "hostinec", Vector3(0, h * 0.67, 5.0), Vector3(0, 0, 1))
		spots["pub_face"] = front[0]
		if front[2] != null:
			spots["pub_lit"] = front[2]
		spots["pub"] = root
	spots["pub_door"] = w(at + Vector3(0, 0, 5.0 + 1.2))


## The chapel of the Virgin Mary, set back from the street: its baroque front from the
## picture when there is one.
func _chapel(at: Vector3) -> void:
	var wall := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(0.95, 0.92, 0.84), Vector2(2.0, 1.0))
	var house := _gable_house("lib_chapel", at.x, at.z + 3.5, 1.0, 7.0, wall, {"max_rise": 3.2})
	if house.is_empty():
		var root := _block(at, Vector3(5.0, 5.0, 7.0), wall)
		_box(root, Vector3(0, 7.0, -2.5), Vector3(1.6, 3.6, 1.6), wall, false)
		_box(root, Vector3(0, 9.2, -2.5), Vector3(0.12, 0.9, 0.12), _mat("", Color(0.3, 0.3, 0.3)))
		_box(root, Vector3(0, 9.4, -2.5), Vector3(0.5, 0.1, 0.1), _mat("", Color(0.3, 0.3, 0.3)))
		_face(root, Vector3(0, 1.3, 3.5), Vector2(1.4, 2.6), Vector3(0, 0, 1), _mat(_first([TEX + "house_door.png", TEX_CAMP + "door_wood.png"]), Color(0.4, 0.3, 0.2)))
	spots["chapel"] = w(at + Vector3(0, 0, 4.5))


## The motel: tube letters MOTEL standing on its roof on their brackets over the
## entrance, LESNA in white metal beside them; the tubes light up after dark.
func _motel(at: Vector3) -> void:
	var wall := _mat(TEX_CAMP + "concrete.png", Color(0.9, 0.84, 0.72), Vector2(4.0, 2.0))
	var size := Vector3(22.0, 6.4, 9.0)
	var root := _block(at, size, wall, "flat")
	# Its front faces the road (north, -z).
	_face(root, Vector3(0, 3.2, -size.z * 0.5), Vector2(22.0, 6.4), Vector3(0, 0, -1), _mat(_first([TEX + "motel_front.png"]), Color(0.7, 0.6, 0.5), Vector2(2.0, 1.0)))
	var dark := _mat("", Color(0.16, 0.16, 0.17))
	var fz := -size.z * 0.5 + 0.35
	for x in [-8.2, -5.4, -1.9]:
		_box(root, Vector3(x, size.y + 0.75, fz + 0.12), Vector3(0.08, 1.5, 0.08), dark)
	_box(root, Vector3(-5.0, size.y + 0.3, fz + 0.12), Vector3(7.2, 0.08, 0.08), dark)
	var neon := _letters(root, "motel", Vector3(-6.6, size.y + 0.7, fz), Vector3(0, 0, -1))
	_letters(root, "motel_lesna", Vector3(-2.4, size.y + 0.45, fz), Vector3(0, 0, -1))
	if neon != null:
		neon.name = "MotelSign"
		spots["motel_neon"] = neon.material_override
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
	# BENZINA in white metal letters along the red fascia.
	_letters(root, "benzina", Vector3(0, 4.9, -4.05), Vector3(0, 0, -1))
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


## The naves across the road from the Jednota and the pub, as in Liblice ("Ve Stare
## vsi"): grass with trodden paths, the little pond in its stone rim, the war memorial
## facing the road, the white bell pillar (zvonicka) with the stone cross beside it,
## lime trees and benches. The houses on its far side look over it at the road.
func _green() -> void:
	var stone := _mat(TEX_CAMP + "plaster_stone.png", Color(0.82, 0.8, 0.76), Vector2(3.0, 1.0))
	var pond := Vector3(8.0, 0, 20.0)
	_plane(self, pond + Vector3(0, 0.05, 0), Vector2(12.0, 8.0), _mat(TEX_CAMP + "lake_water.png", Color(0.56, 0.62, 0.6), Vector2(3.0, 2.0)))
	for side in [[Vector3(0, 0.2, -4.1), Vector3(12.4, 0.4, 0.3)], [Vector3(0, 0.2, 4.1), Vector3(12.4, 0.4, 0.3)], [Vector3(-6.1, 0.2, 0), Vector3(0.3, 0.4, 8.2)], [Vector3(6.1, 0.2, 0), Vector3(0.3, 0.4, 8.2)]]:
		_box(self, pond + side[0], side[1], stone, true)
	spots["pond"] = w(pond)
	# Trodden paths across the grass: from the stop to the memorial, from the road down
	# to the pond, round to the houses beyond.
	var dirt := _mat(_first([TEX + "dirt_path.png", TEX_CAMP + "gravel_road.png"]), Color(0.92, 0.88, 0.8))
	for p in [[Vector3(1.0, 0, 6.0), Vector3(25.0, 0, 11.2)], [Vector3(13.0, 0, 5.4), Vector3(9.0, 0, 15.6)], [Vector3(15.0, 0, 21.0), Vector3(26.0, 0, 28.6)], [Vector3(-5.0, 0, 9.0), Vector3(-3.0, 0, 28.6)]]:
		var a: Vector3 = p[0]
		var b: Vector3 = p[1]
		var length := a.distance_to(b)
		var m := (dirt as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.uv1_scale = Vector3(1.0, length / 1.4, 1.0)
		var pl := _plane(self, (a + b) * 0.5 + Vector3(0, 0.03, 0), Vector2(1.3, length), m)
		pl.rotation.y = atan2(b.x - a.x, b.z - a.z)
	# The memorial to the fallen, facing the road: a stone with a cross and the names.
	var mem := Vector3(26.0, 0, 13.0)
	_box(self, mem + Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 1.4), stone, true)
	_box(self, mem + Vector3(0, 1.3, 0), Vector3(1.0, 2.0, 0.5), _mat(TEX_CAMP + "plaster_stone.png", Color(0.7, 0.7, 0.68)), true)
	_box(self, mem + Vector3(0, 2.6, 0), Vector3(0.12, 0.7, 0.12), stone)
	_box(self, mem + Vector3(0, 2.75, 0), Vector3(0.5, 0.12, 0.12), stone)
	_sign(self, mem + Vector3(0, 1.4, -0.25), Vector3(0, 0, -1), "1914 - 1918\n1939 - 1945", 22, Color(0.2, 0.18, 0.16))
	spots["memorial"] = w(mem)
	# Benches round the pond, looking at it.
	_bench(Vector3(8.0, 0, 14.6), 0.0)
	_bench(Vector3(0.6, 0, 20.0), PI * 0.5)
	_bench(Vector3(15.4, 0, 20.0), -PI * 0.5)
	spots["bench"] = w(Vector3(8.0, 0, 14.6))
	_zvonicka(Vector3(-6.0, 0, 13.5))
	_stone_cross(Vector3(-2.6, 0, 12.0))
	# Lime trees (the camp's birch, scaled up) round the green.
	if worldgen != null and worldgen.has_method("_tree_mesh"):
		for t in [Vector3(19.5, 0, 8.8), Vector3(33.0, 0, 21.0), Vector3(-8.5, 0, 22.5), Vector3(-9.0, 0, 9.5)]:
			for part in [["birch_trunk", worldgen._tree_material("bark", 0)], ["birch_crown", worldgen._tree_material("leaf", 0)]]:
				var mi := MeshInstance3D.new()
				mi.mesh = worldgen._tree_mesh(str(part[0]))
				mi.material_override = part[1]
				mi.position = t
				mi.scale = Vector3(2.4, 2.0, 2.4)
				add_child(mi)
			_solid(self, t + Vector3(0, 1.5, 0), Vector3(0.6, 3.0, 0.6))


## A bench: plank seat and back, looking along `yaw` (0 = towards +z).
func _bench(at: Vector3, yaw: float) -> void:
	var planks := _mat(TEX_CAMP + "planks_grey.png", Color(0.7, 0.62, 0.5))
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	_box(root, Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.45), planks, true)
	_box(root, Vector3(0, 0.75, -0.2), Vector3(1.8, 0.4, 0.06), planks)
	for x in [-0.75, 0.75]:
		_box(root, Vector3(x, 0.22, 0), Vector3(0.08, 0.44, 0.4), _mat("", Color(0.22, 0.2, 0.18)))


## The bell pillar on the green: a white plastered pillar, an open belfry with the little
## bell, a tin cap and a cross.
func _zvonicka(at: Vector3) -> void:
	var white := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(1.0, 1.0, 0.98), Vector2(1.0, 2.0))
	var tin := _mat("", Color(0.36, 0.38, 0.36))
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_box(root, Vector3(0, 0.15, 0), Vector3(1.3, 0.3, 1.3), _mat(TEX_CAMP + "plaster_stone.png", Color(0.7, 0.7, 0.68)), true)
	_box(root, Vector3(0, 1.45, 0), Vector3(0.95, 2.3, 0.95), white, true)
	_box(root, Vector3(0, 2.67, 0), Vector3(1.1, 0.14, 1.1), white)
	for c in [Vector3(-0.4, 0, -0.4), Vector3(0.4, 0, -0.4), Vector3(-0.4, 0, 0.4), Vector3(0.4, 0, 0.4)]:
		_box(root, c + Vector3(0, 3.2, 0), Vector3(0.14, 0.95, 0.14), white)
	_box(root, Vector3(0, 3.72, 0), Vector3(1.1, 0.12, 1.1), white)
	var bell := _box(root, Vector3(0, 3.2, 0), Vector3(0.36, 0.42, 0.36), _mat("", Color(0.42, 0.32, 0.16)))
	bell.name = "Bell"
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.radial_segments = 4
	cm.rings = 1
	cm.top_radius = 0.02
	cm.bottom_radius = 0.92
	cm.height = 0.8
	cap.mesh = cm
	cap.material_override = tin
	cap.position = Vector3(0, 4.18, 0)
	cap.rotation.y = PI * 0.25
	root.add_child(cap)
	_box(root, Vector3(0, 4.85, 0), Vector3(0.05, 0.55, 0.05), tin)
	_box(root, Vector3(0, 4.95, 0), Vector3(0.3, 0.05, 0.05), tin)
	spots["zvonicka"] = w(at)


## The stone wayside cross beside it, on its stepped plinth.
func _stone_cross(at: Vector3) -> void:
	var sand := _mat(TEX_CAMP + "plaster_stone.png", Color(0.86, 0.8, 0.68))
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_box(root, Vector3(0, 0.12, 0), Vector3(1.1, 0.24, 1.1), sand, true)
	_box(root, Vector3(0, 0.75, 0), Vector3(0.62, 1.0, 0.62), sand, true)
	_box(root, Vector3(0, 1.32, 0), Vector3(0.72, 0.14, 0.72), sand)
	_box(root, Vector3(0, 2.35, 0), Vector3(0.18, 1.9, 0.18), sand)
	_box(root, Vector3(0, 2.75, 0), Vector3(0.9, 0.17, 0.17), sand)
	_box(root, Vector3(0, 2.5, -0.1), Vector3(0.1, 0.55, 0.05), _mat("", Color(0.3, 0.28, 0.24)))


# ── the street fronts (tools/artgen/town_facades.py) ────────────────────────

const SIGN_PX_M := 48.0

## What town_facades.py measured on each front: picture size in metres, the walls at the
## bottom (fractions), where the gable or roof starts (fraction from the top).
var _fronts: Dictionary = {}


func _front_meta(fid: String) -> Dictionary:
	if _fronts.is_empty() and ResourceLoader.exists(TEX + "lib_facades.json"):
		var j = load(TEX + "lib_facades.json")
		if j is JSON and j.data is Dictionary:
			_fronts = j.data
	if not ResourceLoader.exists(TEX + fid + ".png"):
		return {}
	return _fronts.get(fid, {})


## The picture on a quad in front of the wall, cut out by its alpha; its windows lit
## from the _win picture of an evening. Returns [mesh, dark, lit or null].
func _front_quad(parent: Node3D, fid: String, pos: Vector3, facing: float, size: Vector2) -> Array:
	var dark := StandardMaterial3D.new()
	dark.albedo_texture = load(TEX + fid + ".png")
	dark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	dark.alpha_scissor_threshold = 0.5
	dark.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	dark.roughness = 1.0
	var lit: StandardMaterial3D = null
	if ResourceLoader.exists(TEX + fid + "_win.png"):
		lit = dark.duplicate() as StandardMaterial3D
		lit.emission_enabled = true
		lit.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		lit.emission_texture = load(TEX + fid + "_win.png")
		lit.emission = Color(1.0, 0.78, 0.45)
		lit.emission_energy_multiplier = 1.5
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos + Vector3(0, 0, facing * 0.03)
	mi.rotation.y = 0.0 if facing > 0.0 else PI
	mi.material_override = dark
	parent.add_child(mi)
	return [mi, dark, lit]


## Lettering (tools/artgen/lettering.py) on a wall: a cut-out quad its own size
## (SIGN_PX_M pixels a metre). With a _glow picture it can light up (set the returned
## material's emission energy).
func _letters(parent: Node3D, sname: String, pos: Vector3, facing: Vector3) -> MeshInstance3D:
	var path := TEX + "sign_%s.png" % sname
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	var glow_path := TEX + "sign_%s_glow.png" % sname
	if ResourceLoader.exists(glow_path):
		m.emission_enabled = true
		m.emission = Color(0, 0, 0)
		m.emission_texture = load(glow_path)
		m.emission_energy_multiplier = 0.0
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(tex.get_width(), tex.get_height()) / SIGN_PX_M
	mi.mesh = q
	mi.position = pos + facing * 0.05
	mi.rotation.y = atan2(facing.x, facing.z)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The house's other walls: a tile of plain wall cut from its own front (town_facades.py
## <id>_side.png), so the sides are the colour and the dirt of the gable.
func _side_mat(fid: String, fallback: Material) -> Material:
	var p := TEX + fid + "_side.png"
	if ResourceLoader.exists(p):
		return _mat(p, Color(1, 1, 1), Vector2(3.0, 1.0))
	return fallback


## The roof tiles (or the grey asbestos-cement slates).
func _roof_mat(eternit: bool, size: Vector3) -> Material:
	var roof_tex := _first([TEX + "roof_eternit.png", TEX + "roof_tiles.png"]) if eternit else _first([TEX + "roof_tiles.png", TEX_CAMP + "corrugated_roof.png"])
	return _tiled(_mat(roof_tex, Color(0.7, 0.4, 0.3) if not eternit else Color(0.9, 0.9, 0.9)), size)


## A house with its gable to the street, the Liblice way: the picture (fid) is the gable
## end; the walls run `depth` back into the yard, the gable's back, the roof and a
## chimney built to fit the picture; windows and the door on the yard side (+x), a
## house number by the right-hand window. Returns the house for town_dressing.
func _gable_house(fid: String, cx: float, front_z: float, facing: float, depth: float, side_wall: Material, opts := {}) -> Dictionary:
	var meta := _front_meta(fid)
	if meta.is_empty():
		return {}
	var W: float = meta["m"][0]
	var H: float = meta["m"][1]
	var eave: float = meta["eave"]
	var ww: float = (float(meta["wall_r"]) - float(meta["wall_l"])) * W
	var wh := (1.0 - eave) * H
	var rise := minf(eave * H, float(opts.get("max_rise", 99.0)))
	var off: float = ((float(meta["wall_l"]) + float(meta["wall_r"])) * 0.5 - 0.5) * W
	side_wall = _side_mat(fid, side_wall)
	var root := Node3D.new()
	root.position = Vector3(cx, 0, front_z - facing * depth * 0.5)
	add_child(root)
	var fz := facing * depth * 0.5
	_box(root, Vector3(off, wh * 0.5, 0), Vector3(ww, wh, depth), _tiled(side_wall, Vector3(ww, wh, depth)), true)
	for end in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(ww, rise - 0.06, 0.12)
		g.mesh = pm
		g.material_override = side_wall
		g.position = Vector3(off, wh + (rise - 0.06) * 0.5, end * (depth * 0.5 - 0.08))
		root.add_child(g)
	var ang := atan2(rise, ww * 0.5)
	var half := ww * 0.5 + 0.35
	# A ruin ("ruin" in opts) has no roof left and no chimney: the picture's rafters are it.
	if not bool(opts.get("ruin", false)):
		var tiles := _roof_mat(bool(opts.get("eternit", false)), Vector3(half / cos(ang), 3.0, depth))
		for side in [-1.0, 1.0]:
			var r := _box(root, Vector3(off + side * half * 0.5, wh + rise - half * tan(ang) * 0.5 + 0.08, 0), Vector3(half / cos(ang), 0.14, depth + 0.5), tiles)
			r.rotation.z = -side * ang
		# The chimney through the right slope, towards the back.
		var chx := off + ww * 0.22
		var roof_y := wh + rise - (ww * 0.22) * tan(ang)
		var chim := Vector3(chx, roof_y + 0.5, -fz * 0.3)
		_box(root, chim, Vector3(0.55, 1.6, 0.55), _mat(TEX_CAMP + "brick_red.png", Color(0.9, 0.85, 0.8)))
		if _rng.randf() < 0.7:
			_chimneys.append(root.position + chim + Vector3(0, 0.9, 0))
	# The street gable: the picture.
	var front := _front_quad(root, fid, Vector3(0, H * 0.5, fz), facing, Vector2(W, H))
	var lit_windows: Array = spots.get("lit_windows", [])
	if front[2] != null:
		lit_windows.append({"mesh": front[0], "on": _rng.randf_range(17.5, 20.5), "off": _rng.randf_range(21.5, 24.5), "dark": front[1], "lit": front[2]})
	# The yard side: the door near the street, windows further back.
	var yard := Vector3(off + ww * 0.5, 0, 0)
	var kinds: Array = spots.get("window_kinds", [])
	var kind: Array = kinds[int(opts.get("kind", 0)) % kinds.size()] if not kinds.is_empty() else []
	var door_z := fz - facing * 2.2
	var door_mats: Array = spots.get("door_mats", [_mat(TEX_CAMP + "door_wood.png", Color(0.42, 0.3, 0.2))])
	_face(root, yard + Vector3(0, 1.05, door_z), Vector2(1.0, 2.1), Vector3(1, 0, 0), door_mats[int(opts.get("kind", 0)) % door_mats.size()])
	if not kind.is_empty():
		var k := 1
		while depth * 0.5 - (2.2 + 3.0 * k) > -depth * 0.5 + 1.2:
			var wz := fz - facing * (2.2 + 3.0 * k)
			var win := _face(root, yard + Vector3(0, 1.7, wz), Vector2(1.2, 1.25), Vector3(1, 0, 0), kind[0])
			lit_windows.append({"mesh": win, "on": _rng.randf_range(17.5, 20.5), "off": _rng.randf_range(21.5, 24.5), "dark": kind[0], "lit": kind[1]})
			k += 1
	spots["lit_windows"] = lit_windows
	if opts.has("number"):
		_letters(root, "cp_" + str(opts["number"]), Vector3(off + ww * 0.4 * facing, wh * 0.62, fz + facing * 0.02), Vector3(0, 0, facing))
	return {"at": root.position, "size": Vector3(ww, wh, depth), "facing": facing, "root": root}


## The 1970s cube house: its picture is the front with the hipped roof's outline; walls
## and a four-sided roof built to fit.
func _hip_house(fid: String, cx: float, front_z: float, facing: float, depth: float, side_wall: Material, opts := {}) -> Dictionary:
	var meta := _front_meta(fid)
	if meta.is_empty():
		return {}
	var W: float = meta["m"][0]
	var H: float = meta["m"][1]
	var eave: float = meta["eave"]
	var ww: float = (float(meta["wall_r"]) - float(meta["wall_l"])) * W
	var wh := (1.0 - eave) * H
	var rise := eave * H
	side_wall = _side_mat(fid, side_wall)
	var root := Node3D.new()
	root.position = Vector3(cx, 0, front_z - facing * depth * 0.5)
	add_child(root)
	_box(root, Vector3(0, wh * 0.5, 0), Vector3(ww, wh, depth), _tiled(side_wall, Vector3(ww, wh, depth)), true)
	var hw := W * 0.5
	var hd := depth * 0.5 + 0.3
	var rl := maxf(0.0, hd - hw)
	var top := wh + rise
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-hw, wh, -hd)
	var b := Vector3(hw, wh, -hd)
	var c := Vector3(hw, wh, hd)
	var d := Vector3(-hw, wh, hd)
	var r1 := Vector3(0, top, -rl)
	var r2 := Vector3(0, top, rl)
	# Clockwise from outside (Godot's front faces).
	for tri in [[r2, c, d], [r1, a, b], [r1, b, c], [r2, r1, c], [r2, d, a], [r1, r2, a]]:
		for p in tri:
			st.set_uv(Vector2(p.x + p.z, p.y * 1.4) / 2.5)
			st.add_vertex(p)
	st.generate_normals()
	var roof := MeshInstance3D.new()
	roof.mesh = st.commit()
	var rm := (_mat(_first([TEX + "roof_eternit.png", TEX + "roof_tiles.png"]), Color(0.9, 0.9, 0.9)) as StandardMaterial3D).duplicate() as StandardMaterial3D
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof.material_override = rm
	root.add_child(roof)
	var fz := facing * depth * 0.5
	var front := _front_quad(root, fid, Vector3(0, H * 0.5, fz), facing, Vector2(W, H))
	var lit_windows: Array = spots.get("lit_windows", [])
	if front[2] != null:
		lit_windows.append({"mesh": front[0], "on": _rng.randf_range(17.5, 20.5), "off": _rng.randf_range(21.5, 24.5), "dark": front[1], "lit": front[2]})
	spots["lit_windows"] = lit_windows
	var chim := Vector3(W * 0.2, top - 0.2, 0.0)
	_box(root, chim, Vector3(0.5, 1.4, 0.5), _mat(TEX_CAMP + "brick_red.png", Color(0.9, 0.85, 0.8)))
	_chimneys.append(root.position + chim + Vector3(0, 0.8, 0))
	if opts.has("number"):
		_letters(root, "cp_" + str(opts["number"]), Vector3(-ww * 0.36 * facing, wh * 0.35, fz + facing * 0.02), Vector3(0, 0, facing))
	return {"at": root.position, "size": Vector3(ww, wh, depth), "facing": facing, "root": root}


## A building with its long side and eaves to the street (the pub, the barn): the
## picture is the front, its top `roof_frac` the roof seen edge-on; walls, a pitched roof
## along the street and gables at both ends behind it. Returns [root, front array].
func _eaves_house(fid: String, at: Vector3, facing: float, depth: float, side_wall: Material, roof_frac: float, eternit := false) -> Array:
	var meta := _front_meta(fid)
	if meta.is_empty():
		return []
	var W: float = meta["m"][0]
	var H: float = meta["m"][1]
	var wh := H * (1.0 - roof_frac)
	side_wall = _side_mat(fid, side_wall)
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_box(root, Vector3(0, wh * 0.5, 0), Vector3(W, wh, depth), _tiled(side_wall, Vector3(W, wh, depth)), true)
	var rise := depth * 0.38
	var ang := atan2(rise, depth * 0.5)
	var half := depth * 0.5 + 0.4
	var tiles := _roof_mat(eternit, Vector3(W, 3.0, half / cos(ang)))
	for side in [-1.0, 1.0]:
		var r := _box(root, Vector3(0, wh + rise - half * tan(ang) * 0.5 + 0.08, side * half * 0.5), Vector3(W + 0.5, 0.14, half / cos(ang)), tiles)
		r.rotation.x = side * ang
	for end in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(depth, rise - 0.06, 0.12)
		g.mesh = pm
		g.material_override = side_wall
		g.position = Vector3(end * (W * 0.5 - 0.08), wh + (rise - 0.06) * 0.5, 0)
		g.rotation.y = PI * 0.5
		root.add_child(g)
	var front := _front_quad(root, fid, Vector3(0, H * 0.5, facing * depth * 0.5), facing, Vector2(W, H))
	return [root, front]


## A flat-roofed front (the Jednota): a box the picture's size, a flat roof.
func _flat_house(fid: String, at: Vector3, facing: float, depth: float, side_wall: Material) -> Array:
	var meta := _front_meta(fid)
	if meta.is_empty():
		return []
	var W: float = meta["m"][0]
	var H: float = meta["m"][1]
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_box(root, Vector3(0, H * 0.5, 0), Vector3(W, H, depth), _tiled(side_wall, Vector3(W, H, depth)), true)
	_box(root, Vector3(0, H + 0.06, 0), Vector3(W + 0.2, 0.12, depth + 0.2), _mat("", Color(0.36, 0.36, 0.36)))
	var front := _front_quad(root, fid, Vector3(0, H * 0.5, facing * depth * 0.5), facing, Vector2(W, H))
	return [root, front]


## The farmyard wall between two houses with its arched gate: the picture on a solid
## wall.
func _farm_wall(cx: float, front_z: float, facing: float) -> void:
	var meta := _front_meta("lib_farm_gate")
	if meta.is_empty():
		return
	var W: float = meta["m"][0]
	var H: float = meta["m"][1]
	var root := Node3D.new()
	root.position = Vector3(cx, 0, front_z - facing * 0.2)
	add_child(root)
	_box(root, Vector3(0, H * 0.5 - 0.3, 0), Vector3(W, H - 0.6, 0.4), _mat(_first([TEX + "village_plaster.png"]), Color(0.95, 0.88, 0.7)), true)
	_front_quad(root, "lib_farm_gate", Vector3(0, H * 0.5, facing * 0.2), facing, Vector2(W, H))


# ── the houses ──────────────────────────────────────────────────────────────

## The street: gabled houses one after another along the road, as in Liblice, a cube
## house of the seventies here and there, a farmyard wall with its gate; more of them
## round the far side of the green, the old barn with the slogan showing through its
## whitewash and the fire station. Each gable is a Grok elevation (lib_*), the house
## built behind it; a missing picture falls back to the next one that is there.
func _houses() -> void:
	var walls := {
		"ochre": _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(1.0, 0.92, 0.7), Vector2(3.0, 1.0)),
		"white": _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(1.0, 1.0, 1.0), Vector2(3.0, 1.0)),
		"red": _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(0.86, 0.5, 0.42), Vector2(3.0, 1.0)),
		"grey": _mat(_first([TEX_CAMP + "roughcast_wall.png", TEX + "village_plaster.png"]), Color(0.82, 0.82, 0.8), Vector2(3.0, 1.0)),
	}
	# Windows on the yard sides: three kinds, each with its lit twin.
	var kinds: Array = []
	for wp in [_first([TEX + "house_window.png", TEX_CAMP + "window_curtain.png"]), _first([TEX + "window_shutter.png", TEX + "house_window.png"]), _first([TEX + "window_flowers.png", TEX + "house_window.png"])]:
		var dark_m := _mat(wp, Color(0.6, 0.66, 0.7) if wp.ends_with("house_window.png") else Color(0.9, 0.9, 0.9))
		var lit_m := (dark_m as StandardMaterial3D).duplicate() as StandardMaterial3D
		lit_m.emission_enabled = true
		lit_m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		lit_m.emission_texture = lit_m.albedo_texture
		lit_m.emission = Color(1.0, 0.78, 0.45)
		lit_m.emission_energy_multiplier = 1.4
		kinds.append([dark_m, lit_m])
	spots["window_kinds"] = kinds
	spots["door_mats"] = [_mat(_first([TEX + "house_door.png", TEX_CAMP + "door_wood.png"]), Color(0.42, 0.3, 0.2)), _mat(_first([TEX + "house_door2.png", TEX + "house_door.png"]), Color(0.9, 0.9, 0.9))]
	var gables := ["lib_gable_white", "lib_gable_ochre", "lib_gable_grey", "lib_gable_red"]
	var colour := {"lib_gable_white": "white", "lib_gable_ochre": "ochre", "lib_gable_grey": "grey", "lib_gable_red": "red"}
	# [kind, x, front z, facing, depth, number]
	var street := [
		["lib_gable_white", -63.0, -9.5, 1.0, 14.0, 12], ["lib_gable_ochre", -52.0, -9.5, 1.0, 15.0, 27], ["lib_gable_grey", -41.0, -9.5, 1.0, 13.0, 31],
		["gate", 5.1, -10.0, 1.0, 0.0, 0], ["kostka", 31.0, -9.5, 1.0, 9.0, 116], ["lib_gable_red", 42.0, -9.5, 1.0, 14.0, 44], ["gate", 52.0, -9.5, 1.0, 0.0, 0],
		["lib_gable_ochre", 61.0, -9.5, 1.0, 15.0, 58], ["lib_gable_white", 72.0, -9.5, 1.0, 13.0, 63],
		["lib_gable_grey", -66.0, 9.5, -1.0, 14.0, 71], ["lib_gable_red", -55.0, 9.5, -1.0, 13.0, 89], ["kostka", -44.0, 9.5, -1.0, 9.0, 128],
		["lib_gable_ochre", 64.0, 9.5, -1.0, 14.0, 95], ["lib_gable_grey", 74.0, 9.5, -1.0, 13.0, 103],
		# Over the green.
		["lib_gable_red", -3.0, 30.0, -1.0, 13.0, 0], ["lib_gable_white", 26.0, 30.0, -1.0, 13.0, 0],
	]
	var houses: Array = []
	var gi := 0
	for row in street:
		var kind_id: String = row[0]
		var x: float = row[1]
		var fz: float = row[2]
		var f: float = row[3]
		var depth: float = row[4]
		var opts := {"kind": gi}
		if int(row[5]) > 0:
			opts["number"] = int(row[5])
		var house := {}
		if kind_id == "gate":
			_farm_wall(x, fz, f)
			continue
		if kind_id == "kostka":
			house = _hip_house("lib_kostka", x, fz, f, depth, walls["grey"], opts)
			if house.is_empty():
				kind_id = gables[gi % gables.size()]
		if house.is_empty():
			# The asked-for gable, or the next one there is a picture of.
			for k in gables.size():
				var g: String = gables[(gables.find(kind_id) + k) % gables.size()] if gables.has(kind_id) else gables[(gi + k) % gables.size()]
				house = _gable_house(g, x, fz, f, depth, walls[colour[g]], dict_merge(opts, {"eternit": g == "lib_gable_grey"}))
				if not house.is_empty():
					break
		if house.is_empty():
			# No pictures at all: the old block with a door.
			var size := Vector3(9.0, 4.0, depth)
			var root := _block(Vector3(x, 0, fz - f * depth * 0.5), size, walls["white"], "pitched")
			house = {"at": root.position, "size": size, "facing": f, "root": root}
		houses.append(house)
		gi += 1
	spots["houses"] = houses
	# The barn over the green with the old slogan coming through its whitewash, and the
	# fire station on the corner.
	var barn := _eaves_house("lib_barn", Vector3(11.0, 0, 30.0 + 5.0), -1.0, 10.0, _mat(TEX_CAMP + "brick_red.png", Color(0.9, 0.8, 0.72), Vector2(3.0, 1.0)), 0.2)
	if not barn.is_empty():
		_letters(barn[0], "slogan", Vector3(0, 4.6, -5.0 - 0.02), Vector3(0, 0, -1))
	# The fire station: its hall's gable to the green, the hose tower beside it, the name
	# painted over the doors.
	var fire := _gable_house("lib_firehouse", 37.0, 30.0, -1.0, 12.0, _mat(_first([TEX + "village_plaster.png"]), Color(1.0, 0.94, 0.7), Vector2(3.0, 1.0)), {"max_rise": 3.6})
	if not fire.is_empty():
		spots["firehouse"] = fire["root"]
		var fw: float = _front_meta("lib_firehouse")["m"][0]
		_letters(fire["root"], "hasici", Vector3(0.08 * fw, 4.5, -6.0 - 0.02), Vector3(0, 0, -1))


static func dict_merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


# ── the land round it ───────────────────────────────────────────────────────

## The open Polabi round the village instead of a forest: ploughed land and stubble to
## the sky line, poplars along a field track, an orchard behind the gardens, the masts
## of the transmitter beyond (liblice_masts.gd, put in the world by town_trip). Flat:
## no hills, the sky comes down to the fields.
func _fields() -> void:
	var plough := _mat(_first([TEX + "field_plough.png", TEX_CAMP + "pitch_grass.png"]), Color(0.86, 0.8, 0.72), Vector2(40.0, 30.0))
	var stubble := _mat(_first([TEX + "field_stubble.png", TEX_CAMP + "pitch_grass.png"]), Color(0.92, 0.88, 0.76), Vector2(40.0, 30.0))
	for f in [[Vector3(0, -0.01, -200.0), Vector2(480.0, 300.0), plough], [Vector3(0, -0.01, 200.0), Vector2(480.0, 300.0), stubble],
			[Vector3(-250.0, -0.01, 0), Vector2(300.0, 100.0), stubble], [Vector3(250.0, -0.01, 0), Vector2(300.0, 100.0), plough]]:
		_plane(self, f[0], f[1], f[2])
	if worldgen == null or not worldgen.has_method("_tree_mesh"):
		return
	var poplars: Array[Transform3D] = []
	var fruit: Array[Transform3D] = []
	# Poplars along two field tracks and the main road west, a gap now and then.
	for line in [[Vector3(-240.0, 0, -96.0), Vector3(240.0, 0, -96.0), 9.0], [Vector3(118.0, 0, -240.0), Vector3(118.0, 0, 240.0), 8.0], [Vector3(-90.0, 0, 9.0), Vector3(-400.0, 0, 9.0), 14.0], [Vector3(-90.0, 0, -9.0), Vector3(-400.0, 0, -9.0), 14.0]]:
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		var step: float = line[2]
		var n := int(a.distance_to(b) / step)
		for k in n:
			if _rng.randf() < 0.12:
				continue
			var p := a.lerp(b, float(k) / float(n)) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			var sc := _rng.randf_range(0.9, 1.15)
			poplars.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(0.7 * sc, 2.3 * sc, 0.7 * sc)), p))
	# Orchards behind the gardens on both sides.
	for k in 70:
		var side := -1.0 if k % 2 == 0 else 1.0
		var p := Vector3(_rng.randf_range(-80.0, 90.0), 0, side * _rng.randf_range(44.0, 70.0))
		if absf(p.x) < 45.0 and side > 0.0 and p.z < 50.0:
			continue
		var sc := _rng.randf_range(0.6, 0.85)
		fruit.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc * 1.2, sc, sc * 1.2)), p))
	for group in [[poplars, "birch_trunk", "birch_crown"], [fruit, "birch_trunk", "birch_crown"]]:
		var xf: Array[Transform3D] = group[0]
		if xf.is_empty():
			continue
		for part in [[str(group[1]), worldgen._tree_material("bark", 0)], [str(group[2]), worldgen._tree_material("leaf", 0)]]:
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


## The village sign at both ends (IS 12a): the name on a white plate, black border,
## facing the traffic coming in.
func _village_signs() -> void:
	var grey := _mat("", Color(0.42, 0.44, 0.42))
	for s in [[Vector3(-69.0, 0, 5.6), Vector3(-1, 0, 0)], [Vector3(79.0, 0, -5.6), Vector3(1, 0, 0)]]:
		var at: Vector3 = s[0]
		var f: Vector3 = s[1]
		_box(self, at + Vector3(0, 1.1, 0), Vector3(0.07, 2.2, 0.07), grey)
		_box(self, at + Vector3(0, 1.95, 0) - f * 0.03, Vector3(0.03, 0.52, 1.12), grey)
		_letters(self, "obec", at + Vector3(0, 1.95, 0) - f * 0.03, f)


# ── what you click ──────────────────────────────────────────────────────────

## Doors (building_type "town_door", meta "door") and things to read ("town_read").
func _hotspots() -> void:
	_click(Vector3(-6.0, 1.1, -9.9), Vector3(1.8, 2.2, 0.4), "town_door", "jednota")
	_click(Vector3(16.0, 1.2, -10.4), Vector3(1.8, 2.4, 0.4), "town_door", "pub")
	_click(Vector3(-30.0, 1.1, 10.4), Vector3(1.6, 2.2, 0.4), "town_door", "motel")
	_click(Vector3(50.0, 1.1, 18.9), Vector3(1.6, 2.2, 0.4), "town_door", "kiosk")
	_click(Vector3(-28.0, 1.3, -18.4), Vector3(1.6, 2.6, 0.4), "town_door", "chapel")
	_click(Vector3(26.0, 1.4, 12.6), Vector3(1.2, 2.2, 0.8), "town_read", "memorial")
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
	if dressing != null:
		dressing.set_hour(h)
	for wdict in spots.get("lit_windows", []):
		var d: Dictionary = wdict
		var on_at: float = d["on"]
		var off_at: float = d["off"]
		var lit := (h >= on_at and h < minf(off_at, 24.0)) or (off_at > 24.0 and h < off_at - 24.0) or (h >= 5.6 and h < 6.6 and on_at < 18.5)
		(d["mesh"] as MeshInstance3D).material_override = d["lit"] if lit else d["dark"]


func set_night(night: bool) -> void:
	ROAD_POST.set_night(night)
	for pair in spots.get("lamps", []):
		(pair[0] as OmniLight3D).visible = night
		(pair[1] as StandardMaterial3D).emission = Color(1.0, 0.76, 0.42) * (1.6 if night else 0.0)
	var neon = spots.get("motel_neon", null)
	if neon != null:
		(neon as StandardMaterial3D).emission_energy_multiplier = 1.8 if night else 0.0
