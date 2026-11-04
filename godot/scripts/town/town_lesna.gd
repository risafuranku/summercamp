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
const GEO = preload("res://scripts/geo/geo_data.gd")
var dressing
const TEX_CAMP := "res://assets/textury/camp/"
## Set by town_trip.gd before it is built: where its centre stands in the real Liblice
## (on Bylanska, scripts/geo/) and which way its street runs (local +x along it, north).
static var ORIGIN := Vector3(4200.0, 0.0, 0.0)
static var YAW := 0.0
## In the real land (scripts/geo/geo_world.gd): the ground, the street's asphalt, the
## fields round it, the posts and the village signs are the real map's, not built here.
static var GEO_MODE := false
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
	name = "Liblice"
	worldgen = p_worldgen
	_rng.seed = 42
	position = ORIGIN
	rotation.y = YAW
	if not GEO_MODE:
		_ground()
		_road_posts()
	_roads()
	_green()
	_jednota(Vector3(-6.0, 0, -15.0))
	_pub(Vector3(16.0, 0, -15.5))
	_chapel(Vector3(-28.0, 0, -22.0))
	_motel(Vector3(-24.0, 0, 15.0))
	_station(Vector3(48.0, 0, 13.0))
	_houses()
	_side_street()
	_stop_north()
	_stop_south()
	_lamps()
	if not GEO_MODE:
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
	spots["street"] = STREET_LIFE.new()
	add_child(spots["street"])
	# The Benzina is only for filling up now (Lojza's job is at the one by the camp's
	# turn): the village's cars come in by day and fill up themselves.
	var cars = PUMP_JOB.new()
	cars.name = "StationCars"
	cars.self_service = true
	add_child(cars)
	var stops: Array = []
	var ins: Array = []
	var outs: Array = []
	for pw in spots.get("pumps", []):
		var stop: Vector3 = unw(pw as Vector3) + Vector3(0, 0, -1.9)
		stops.append(stop)
		# Off the road and in between the canopy's pillars, out again the other way.
		ins.append([Vector3(90.0, 0, 1.6), Vector3(66.0, 0, 1.6), Vector3(stop.x + 4.0, 0, 4.0), Vector3(stop.x + 1.5, 0, 8.6), stop])
		outs.append([stop + Vector3(-3.0, 0, -0.9), stop + Vector3(-5.0, 0, -5.9), Vector3(34.0, 0, -1.6), Vector3(-90.0, 0, -1.6)])
	cars.setup(stops, ins, outs)
	spots["station_cars"] = cars


# ── where things are (world space) ───────────────────────────────────────────

func w(local: Vector3) -> Vector3:
	return ORIGIN + Basis(Vector3.UP, YAW) * local


## A world point in the village's frame.
func unw(world: Vector3) -> Vector3:
	return Basis(Vector3.UP, YAW).inverse() * (world - ORIGIN)


## A direction in the village's frame, in the world's.
func wdir(local: Vector3) -> Vector3:
	return Basis(Vector3.UP, YAW) * local


## The bus to the camp ("to_camp") stands on the south side by the shelter, facing east
## (it came from Hlubocany in the west and goes on east to the main road and the camp);
## the one from the camp to Hlubocany ("to_hlub") stops on the north side, by the square,
## facing west. Right-hand traffic: the doors are on the kerb side.
func bus_pose(stop: String) -> Transform3D:
	if GEO_MODE:
		return _geo_pose(stop)
	if stop == "to_camp":
		return Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), w(Vector3(-2.0, 0, 1.6)))
	return Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), w(Vector3(8.0, 0, -1.6)))


func bus_arrive_path(stop: String) -> PackedVector3Array:
	if GEO_MODE:
		var s := GEO.stop_s("liblice")
		return GEO.line_path(s + 150.0, s - 4.0, 1.6) if stop == "to_camp" else GEO.line_path(s - 150.0, s + 4.0, 1.6)
	var out := PackedVector3Array()
	var end := bus_pose(stop).origin
	var dir := 1.0 if stop == "to_camp" else -1.0
	for k in [-140.0, -90.0, -40.0, -14.0, 0.0]:
		out.append(end + Vector3(dir * k, 0, 0))
	return out


func bus_leave_path(stop: String) -> PackedVector3Array:
	if GEO_MODE:
		var s := GEO.stop_s("liblice")
		return GEO.line_path(s - 4.0, s - 160.0, 1.6) if stop == "to_camp" else GEO.line_path(s + 4.0, s + 170.0, 1.6)
	var out := PackedVector3Array()
	var start := bus_pose(stop).origin
	var dir := 1.0 if stop == "to_camp" else -1.0
	for k in [0.0, 14.0, 40.0, 90.0, 150.0]:
		out.append(start + Vector3(dir * k, 0, 0))
	return out


## Where you are put off the bus from the camp: by the Jednota, looking down the street
## with the green across the road and the masts at the end of it.
func arrive_spot() -> Transform3D:
	if GEO_MODE:
		# Off the bus from the camp on the east side, looking up Bylanska to the green.
		var a := GEO.at(GEO.stop_s("liblice") + 6.0, 4.8)
		return Transform3D(Basis.looking_at(a["dir"] + _right(a["dir"]) * 0.15, Vector3.UP), a["p"] + Vector3(0, 0.15, 0))
	var pos := w(Vector3(9.0, 0.15, -4.6))
	return Transform3D(Basis.looking_at(Vector3(-1, 0, 0.3), Vector3.UP), pos)


## Where you wait for the bus to the camp, in the shelter's mouth across the road.
func wait_spot() -> Transform3D:
	if GEO_MODE:
		# In the shelter's mouth on the west side, looking down the road for the bus.
		var b := GEO.at(GEO.stop_s("liblice") - 3.0, -4.6)
		return Transform3D(Basis.looking_at(b["dir"] * -1.0 + _right(b["dir"]) * 0.4, Vector3.UP), b["p"] + Vector3(0, 0.15, 0))
	var pos := w(Vector3(-2.0, 0.15, 4.6))
	return Transform3D(Basis.looking_at(Vector3(-1, 0, -0.3), Vector3.UP), pos)


## In the real Liblice the stop is south of the centre, on Bylanska (the route's
## "liblice" stop): the bus for the camp on the west side facing south, the one from
## the camp on the east side facing north, each by its pole, doors to the kerb.
func _geo_pose(stop: String) -> Transform3D:
	var s := GEO.stop_s("liblice")
	if stop == "to_camp":
		var a := GEO.at(s - 4.0, -1.6)
		return Transform3D(Basis.looking_at(-(a["dir"] as Vector3), Vector3.UP), a["p"])
	var b := GEO.at(s + 4.0, 1.6)
	return Transform3D(Basis.looking_at(b["dir"], Vector3.UP), b["p"])


## The right-hand side of a way along `dir` (xz).
static func _right(dir: Vector3) -> Vector3:
	return Vector3(-dir.z, 0.0, dir.x)


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
	if not GEO_MODE:
		_plane(self, Vector3(0, 0.01, 0), Vector2(480, ROAD_HALF * 2.0), asphalt)
	# The square in front of the shop and the pub, and the station's forecourt.
	var cobbles := _mat(_first([TEX + "cobbles.png", TEX_CAMP + "gravel_road.png"]), Color(0.86, 0.84, 0.8), Vector2(10.0, 4.0))
	# (Over the real street's asphalt in the real land: a hair higher.)
	var lift := 0.09 if GEO_MODE else 0.0
	_plane(self, Vector3(4.0, 0.012 + lift, -8.0), Vector2(46.0, 9.0), cobbles)
	_plane(self, Vector3(48.0, 0.012 + lift, 9.0), Vector2(26.0, 12.0), _mat(_first([TEX + "asphalt.png"]), Color(0.7, 0.7, 0.7), Vector2(6.0, 3.0)))
	# Kerbs.
	var kerb := _mat("", Color(0.6, 0.6, 0.58))
	for z in [-ROAD_HALF, ROAD_HALF]:
		_box(self, Vector3(0, 0.05, z), Vector3(480 if not GEO_MODE else 160.0, 0.1, 0.2), kerb)


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
## Since 3. 11. (the user: "the other town interiors the same"): its shop windows and the
## glazed door are glass you see through (jednota_view.gd): the building hollow behind its
## front, the sales room built in it, lit while it is open (`_update_jednota`).
const JEDNOTA_VIEW = preload("res://scripts/town/jednota_view.gd")
const KIT = preload("res://scripts/interior_kit.gd")
var _jednota_lit := -1


func _jednota(at: Vector3) -> void:
	var wall := _mat(TEX_CAMP + "concrete.png", Color(0.86, 0.84, 0.8), Vector2(3.0, 1.0))
	if ResourceLoader.exists(TEX + "lib_jednota_front_glass.png") and not _front_meta("lib_jednota_front").is_empty():
		var shop := _jednota_hollow(at, wall)
		var hh: float = _front_meta("lib_jednota_front")["m"][1]
		_letters(shop, "jednota", Vector3(-2.3, hh - 0.95, 5.0), Vector3(0, 0, 1))
		_letters(shop, "u_marku", Vector3(2.9, hh - 0.86, 5.0), Vector3(0, 0, 1))
		spots["jednota_door"] = w(at + Vector3(0, 0, 5.0 + 1.2))
		spots["jednota"] = shop
		return
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
		_letters(root, "u_marku", Vector3(2.9, h - 0.86, front_z), Vector3(0, 0, 1))
	spots["jednota_door"] = w(at + Vector3(0, 0, front_z + 1.2))
	spots["jednota"] = root


## The Jednota's building, hollow: its walls and roof, the front wall round its glass
## behind the picture with its holes, the glass, a solid core nobody walks into, and the
## sales room behind the glass (built again as the hour lights or darkens it).
func _jednota_hollow(at: Vector3, wall: Material) -> Node3D:
	var V = JEDNOTA_VIEW
	var ww: float = V.W
	var hh: float = V.H
	var dd: float = V.DEPTH
	var root := Node3D.new()
	root.position = at
	root.name = "Jednota"
	add_child(root)
	_box(root, Vector3(0, hh * 0.5, -dd * 0.5 + 0.1), Vector3(ww, hh, 0.2), _tiled(wall, Vector3(ww, hh, 0.2)))
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(float(sx) * (ww * 0.5 - 0.1), hh * 0.5, 0), Vector3(0.2, hh, dd), _tiled(wall, Vector3(0.2, hh, dd)))
	_box(root, Vector3(0, hh + 0.06, 0), Vector3(ww + 0.2, 0.12, dd + 0.2), _mat("", Color(0.36, 0.36, 0.36)))
	# The front wall behind the picture, cut round the glass (the holes' reveals).
	var holes: Array = []
	for r in V.PANES + V.DOOR_GLASS:
		holes.append([float(r[0]) / V.PX_M - ww * 0.5, float(r[2]) / V.PX_M - ww * 0.5, hh - float(r[3]) / V.PX_M, hh - float(r[1]) / V.PX_M])
	var plaster := _mat(TEX_CAMP + "concrete.png", Color(0.8, 0.78, 0.74))
	for p in KIT.wall_pieces(ww * 0.5, hh, holes):
		_box(root, Vector3((float(p[0]) + float(p[1])) * 0.5, (float(p[2]) + float(p[3])) * 0.5, dd * 0.5 - 0.08), Vector3(float(p[1]) - float(p[0]), float(p[3]) - float(p[2]), 0.16), plaster)
	_front_quad(root, "lib_jednota_front_glass", Vector3(0, hh * 0.5, dd * 0.5), 1.0, Vector2(ww, hh))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.24, 0.29, 0.32, 0.16)
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for hl in holes:
		var g := _face(root, Vector3((float(hl[0]) + float(hl[1])) * 0.5, (float(hl[2]) + float(hl[3])) * 0.5, dd * 0.5 - 0.1), Vector2(float(hl[1]) - float(hl[0]), float(hl[3]) - float(hl[2])), Vector3(0, 0, 1), glass)
		g.set_meta("retro_skip", true)
	_solid(root, Vector3(0, hh * 0.5, -0.2), Vector3(ww - 0.4, hh, dd - 0.6))
	_update_jednota(_hour)
	return root


## The sales room behind the glass: lit with its tubes and Mrs Novotna at the counter
## while it is open (town_trip.HOURS: 7-17), dark after.
func _update_jednota(h: float) -> void:
	var shop = spots.get("jednota") if spots.has("jednota") else null
	var root: Node3D = shop as Node3D if shop != null else get_node_or_null("Jednota") as Node3D
	if root == null:
		return
	var lit := 1 if (h >= 7.0 and h < 17.0) else 0
	if lit == _jednota_lit and root.get_node_or_null("SalesRoom") != null:
		return
	_jednota_lit = lit
	var old := root.get_node_or_null("SalesRoom")
	if old != null:
		old.name = "SalesRoomOld"
		old.queue_free()
	var sales := Node3D.new()
	sales.name = "SalesRoom"
	sales.position = JEDNOTA_VIEW.origin()
	root.add_child(sales)
	var built: Dictionary = JEDNOTA_VIEW.build(sales, null, lit == 1)
	spots["jednota_shell"] = sales
	_jednota_tube = {}
	if lit == 0:
		_jednota_night_tube(sales, built)


## The closed shop after dark: the one tube they leave on, the dying one, the shelves cold
## in its light behind the glass and a little of it out on the pavement.
var _jednota_tube: Dictionary = {}
var _jtube_t := 1.0
var _jtube_out := 0.0


func _jednota_night_tube(sales: Node3D, built: Dictionary) -> void:
	var tubes: Array = built.get("tubes", [])
	if tubes.size() < 2:
		return
	var tube := tubes[1] as MeshInstance3D
	var m := tube.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(0.9, 0.96, 1.0)
	var l := OmniLight3D.new()
	l.light_color = Color(0.82, 0.9, 1.0)
	l.light_energy = 1.1
	l.omni_range = 7.0
	l.position = tube.position + Vector3(0, -0.3, 0)
	sales.add_child(l)
	_jednota_tube = {"light": l, "mat": m}
	_show_jednota_tube(_station_night)


func _show_jednota_tube(on: bool) -> void:
	if _jednota_tube.is_empty():
		return
	(_jednota_tube["light"] as OmniLight3D).visible = on
	(_jednota_tube["mat"] as StandardMaterial3D).emission_energy_multiplier = 1.5 if on else 0.0


## Mostly on, now and then a stutter.
func _tick_jednota_tube(delta: float) -> void:
	if _jednota_tube.is_empty():
		return
	_jtube_t -= delta
	if _jtube_t <= 0.0:
		_jtube_t = _rng.randf_range(0.06, 0.3) if _jtube_out > 0.0 else _rng.randf_range(3.0, 14.0)
		_jtube_out = 0.0 if _jtube_out > 0.0 else 1.0
	var on := _jtube_out <= 0.0 or fmod(_smoke_t * 19.0, 1.0) < 0.3
	(_jednota_tube["light"] as OmniLight3D).light_energy = 1.1 if on else 0.14
	(_jednota_tube["mat"] as StandardMaterial3D).emission_energy_multiplier = 1.5 if on else 0.1


## The pub U Jezera: an old inn with its eaves to the street, the name painted on the
## plaster over the windows by a signwriter long ago.
## Since 3. 11. its windows are glass you see through (pub_view.gd): the inn hollow behind
## its front, the taproom built in it, lit while it is open (`_update_pub`).
const PUB_VIEW = preload("res://scripts/town/pub_view.gd")
const PUB_STREET = preload("res://scripts/town/pub_street.gd")
const STREET_LIFE = preload("res://scripts/town/street_life.gd")
var _pub_lit := -1
var _pub_street


func _pub(at: Vector3) -> void:
	var wall := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(0.78, 0.86, 0.74), Vector2(3.0, 1.0))
	if ResourceLoader.exists(TEX + "lib_pub_front_glass.png") and not _front_meta("lib_pub_front").is_empty():
		var inn := _pub_hollow(at, wall)
		var hh: float = _front_meta("lib_pub_front")["m"][1]
		_letters(inn, "hostinec", Vector3(0, hh * 0.67, 5.0), Vector3(0, 0, 1))
		spots["pub"] = inn
		spots["pub_door"] = w(at + Vector3(0, 0, 5.0 + 1.2))
		return
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


## The pub's building, hollow: _eaves_house's walls, roof and gables, the front wall round
## its windows behind the picture with its holes, the glass, a solid core, the taproom.
func _pub_hollow(at: Vector3, wall: Material) -> Node3D:
	var V = PUB_VIEW
	var ww: float = V.W
	var hh: float = V.H
	var dd: float = V.DEPTH
	var wh := hh * (1.0 - 0.12)
	var side := _side_mat("lib_pub_front", wall)
	var root := Node3D.new()
	root.position = at
	root.name = "Pub"
	add_child(root)
	_box(root, Vector3(0, wh * 0.5, -dd * 0.5 + 0.1), Vector3(ww, wh, 0.2), _tiled(side, Vector3(ww, wh, 0.2)))
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(float(sx) * (ww * 0.5 - 0.1), wh * 0.5, 0), Vector3(0.2, wh, dd), _tiled(side, Vector3(0.2, wh, dd)))
	var rise := dd * 0.38
	var ang := atan2(rise, dd * 0.5)
	var half := dd * 0.5 + 0.4
	var tiles := _roof_mat(false, Vector3(ww, 3.0, half / cos(ang)))
	for s in [-1.0, 1.0]:
		var r := _box(root, Vector3(0, wh + rise - half * tan(ang) * 0.5 + 0.08, float(s) * half * 0.5), Vector3(ww + 0.5, 0.14, half / cos(ang)), tiles)
		r.rotation.x = float(s) * ang
		var eave_y := wh + 0.08 - 0.4 * rise / (dd * 0.5)
		_box(root, Vector3(0, eave_y - 0.1, float(s) * (half - 0.05)), Vector3(ww + 0.5, 0.1, 0.12), _house_mats()["tin"])
	_box(root, Vector3(0, wh + rise + 0.15, 0), Vector3(ww + 0.5, 0.12, 0.26), _house_mats()["ridge"])
	for e in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(dd, rise - 0.06, 0.12)
		g.mesh = pm
		g.material_override = side
		g.position = Vector3(float(e) * (ww * 0.5 - 0.08), wh + (rise - 0.06) * 0.5, 0)
		g.rotation.y = PI * 0.5
		root.add_child(g)
	# A ceiling over the taproom so the roof's inside is never seen through the glass.
	_box(root, Vector3(ww - 0.4, 0.1, dd - 0.4), Vector3(0, wh - 0.05, 0), _mat("", Color(0.2, 0.18, 0.16)))
	var holes: Array = []
	for r2 in V.PANES:
		holes.append([float(r2[0]) / V.PX_M - ww * 0.5, float(r2[2]) / V.PX_M - ww * 0.5, hh - float(r2[3]) / V.PX_M, hh - float(r2[1]) / V.PX_M])
	for p in KIT.wall_pieces(ww * 0.5, wh, holes):
		_box(root, Vector3((float(p[0]) + float(p[1])) * 0.5, (float(p[2]) + float(p[3])) * 0.5, dd * 0.5 - 0.08), Vector3(float(p[1]) - float(p[0]), float(p[3]) - float(p[2]), 0.16), side)
	_front_quad(root, "lib_pub_front_glass", Vector3(0, hh * 0.5, dd * 0.5), 1.0, Vector2(ww, hh))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.24, 0.29, 0.32, 0.16)
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for hl in holes:
		var gl := _face(root, Vector3((float(hl[0]) + float(hl[1])) * 0.5, (float(hl[2]) + float(hl[3])) * 0.5, dd * 0.5 - 0.1), Vector2(float(hl[1]) - float(hl[0]), float(hl[3]) - float(hl[2])), Vector3(0, 0, 1), glass)
		gl.set_meta("retro_skip", true)
	_solid(root, Vector3(0, wh * 0.5, -0.2), Vector3(ww - 0.4, wh, dd - 0.6))
	_update_pub(_hour)
	return root


## The taproom behind the glass: lit with Kubat and his regulars while the pub is open
## (town_trip.HOURS: 10-23), dark after.
func _update_pub(h: float) -> void:
	var inn = spots.get("pub") if spots.get("pub") is Node3D else get_node_or_null("Pub")
	var root: Node3D = inn as Node3D
	if root == null or root.name != "Pub":
		return
	# (Lit a little past its hours: the lamps go window by window, pub_street.gd.)
	var lit := 1 if (h >= 10.0 and h < PUB_STREET.CLOSE_TO) else 0
	if _pub_street != null and is_instance_valid(_pub_street):
		_pub_street.set_hour(h)
	if lit == _pub_lit and root.get_node_or_null("Taproom") != null:
		return
	_pub_lit = lit
	var old := root.get_node_or_null("Taproom")
	if old != null:
		old.name = "TaproomOld"
		old.queue_free()
	var tap := Node3D.new()
	tap.name = "Taproom"
	tap.position = PUB_VIEW.origin()
	root.add_child(tap)
	PUB_VIEW.build(tap, null, lit == 1)
	spots["pub_shell"] = tap
	# After dark, from the street: its smoke, its guests (pub_street.gd).
	_pub_street = null
	if lit == 1:
		_pub_street = PUB_STREET.new()
		tap.add_child(_pub_street)
		_pub_street.build()
		_pub_street.set_on(_station_night)


## The chapel of the Virgin Mary, set back from the street: its baroque front from the
## picture when there is one. Its sides bare of the house kit (no chimney, aerial, porch or
## house windows: "bare"), two oval windows in each, where they are inside
## (chapel_view.gd: the nave and its windows share the building's middle).
const CHAPEL_VIEW = preload("res://scripts/town/chapel_view.gd")


func _chapel(at: Vector3) -> void:
	var wall := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(0.95, 0.92, 0.84), Vector2(2.0, 1.0))
	var house := _gable_house("lib_chapel", at.x, at.z + 3.5, 1.0, 7.0, wall, {"max_rise": 3.2, "bare": true})
	if not house.is_empty() and ResourceLoader.exists(TEX_CAMP + "chapel_oval.png"):
		var oval := StandardMaterial3D.new()
		oval.albedo_texture = load(TEX_CAMP + "chapel_oval.png")
		oval.albedo_color = Color(0.62, 0.6, 0.58)
		oval.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		oval.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		oval.alpha_scissor_threshold = 0.5
		oval.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		# At night the candles inside show through the dirty glass (chapel_view.gd).
		oval.emission_enabled = true
		oval.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		oval.emission_texture = oval.albedo_texture
		oval.emission = Color(1.0, 0.6, 0.3)
		oval.emission_energy_multiplier = 0.0
		_chapel_oval = oval
		var t: Texture2D = oval.albedo_texture
		var size := Vector2(1.1 * float(t.get_width()) / float(t.get_height()), 1.1)
		var half: float = (house["size"] as Vector3).x * 0.5
		for side in [-1.0, 1.0]:
			for wz in CHAPEL_VIEW.WINDOWS_Z:
				_face(house["root"], Vector3(float(side) * half, CHAPEL_VIEW.WINDOW_Y, float(wz)), size, Vector3(float(side), 0, 0), oval)
	if house.is_empty():
		var root := _block(at, Vector3(5.0, 5.0, 7.0), wall)
		_box(root, Vector3(0, 7.0, -2.5), Vector3(1.6, 3.6, 1.6), wall, false)
		_box(root, Vector3(0, 9.2, -2.5), Vector3(0.12, 0.9, 0.12), _mat("", Color(0.3, 0.3, 0.3)))
		_box(root, Vector3(0, 9.4, -2.5), Vector3(0.5, 0.1, 0.1), _mat("", Color(0.3, 0.3, 0.3)))
		_face(root, Vector3(0, 1.3, 3.5), Vector2(1.4, 2.6), Vector3(0, 0, 1), _mat(_first([TEX + "house_door.png", TEX_CAMP + "door_wood.png"]), Color(0.4, 0.3, 0.2)))
	spots["chapel"] = w(at + Vector3(0, 0, 4.5))
	# A lamp in its bracket over the door, on at night, not always steadily.
	if ResourceLoader.exists(TEX_CAMP + "wall_lamp.png"):
		var door := at + Vector3(0, 0, 3.62)
		var lm := _cut_mat(TEX_CAMP + "wall_lamp.png")
		var lt: Texture2D = lm.albedo_texture
		var lw := 0.42 * float(lt.get_width()) / float(lt.get_height())
		_face(self, door + Vector3(0, 2.92, 0.03), Vector2(lw, 0.42), Vector3(0, 0, 1), lm)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 1.2
		l.omni_range = 6.0
		l.position = door + Vector3(0, 2.75, 0.5)
		l.visible = false
		add_child(l)
		var g := _glow(door + Vector3(0, 2.86, 0.12), 0.5)
		_chapel_bulb = [l, g]


## The motel: tube letters MOTEL standing on its roof on their brackets over the
## entrance, LESNA in white metal beside them; the tubes light up after dark. Since 3. 11.
## the whole block from its plan (motel_block.gd: the gallery, the stairs, the rooms
## behind real windows); the old painted box only while its pictures are missing.
const MOTEL_BLOCK = preload("res://scripts/town/motel_block.gd")


func _motel(at: Vector3) -> void:
	if ResourceLoader.exists(TEX + "motel_plaster.png") and ResourceLoader.exists(TEX + "motel_window.png"):
		var block = MOTEL_BLOCK.new()
		block.position = at
		add_child(block)
		block.build(self)
		spots["motel"] = block
		spots["motel_block"] = block
		if block.neon != null:
			spots["motel_neon"] = block.neon
		spots["motel_door"] = w(block.door_spot(0))
		return
	var wall := _mat(TEX_CAMP + "concrete.png", Color(0.9, 0.84, 0.72), Vector2(4.0, 2.0))
	var size := Vector3(22.0, 6.4, 9.0)
	var root := _block(at, size, wall, "flat")
	# Its front faces the road (north, -z).
	_face(root, Vector3(0, 3.2, -size.z * 0.5), Vector2(22.0, 6.4), Vector3(0, 0, -1), _mat(_first([TEX + "motel_front.png"]), Color(0.7, 0.6, 0.5), Vector2(2.0, 1.0)))
	# Its rooms go round: the same windows on the ends and along the back.
	_face(root, Vector3(0, 3.2, size.z * 0.5), Vector2(22.0, 6.4), Vector3(0, 0, 1), _mat(_first([TEX + "motel_front.png"]), Color(0.66, 0.57, 0.48), Vector2(2.0, 1.0)))
	for sx in [-1.0, 1.0]:
		_face(root, Vector3(sx * size.x * 0.5, 3.2, 0), Vector2(size.z, 6.4), Vector3(sx, 0, 0), _mat(_first([TEX + "motel_front.png"]), Color(0.68, 0.58, 0.49), Vector2(size.z / 11.0, 1.0)))
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
	var steel := _mat(TEX_CAMP + "galvanized.png", Color(0.94, 0.94, 0.92), Vector2(1.0, 4.0))
	var side_pic := TEX + "pump_side.png"
	var red := _mat(side_pic, Color(1, 1, 1), Vector2(1.0, 1.0)) if ResourceLoader.exists(side_pic) else _mat("", Color(0.82, 0.1, 0.08))
	for p in [Vector3(-6, 0, -3), Vector3(6, 0, -3), Vector3(-6, 0, 3), Vector3(6, 0, 3)]:
		_box(root, p + Vector3(0, 2.4, 0), Vector3(0.3, 4.8, 0.3), steel, true)
		# The red band round each pillar's foot, kicked by bumpers.
		_box(root, p + Vector3(0, 0.45, 0), Vector3(0.34, 0.9, 0.34), red)
	# The canopy: weathered concrete panels underneath, streaked white sheet at the edge.
	_box(root, Vector3(0, 5.0, 0), Vector3(14.0, 0.5, 8.0), _tiled(_mat(TEX_CAMP + "concrete.png", Color(0.95, 0.95, 0.93), Vector2(3.0, 2.0)), Vector3(14.0, 0.5, 8.0)))
	_box(root, Vector3(0, 4.9, -4.02), Vector3(14.0, 0.5, 0.06), _mat(side_pic, Color(1, 1, 1), Vector2(14.0, 0.5)) if ResourceLoader.exists(side_pic) else _mat("", Color(0.82, 0.1, 0.08)))
	# BENZINA in white metal letters along the red fascia.
	_letters(root, "benzina", Vector3(0, 4.9, -4.05), Vector3(0, 0, -1))
	var pump_face := _mat(_first([TEX + "fuel_pump.png"]), Color(0.8, 0.2, 0.15))
	var pumps: Array = []
	for x in [-2.6, 2.6]:
		var island := _box(root, Vector3(x, 0.1, 0), Vector3(1.4, 0.2, 3.0), _mat(TEX_CAMP + "concrete.png", Color(0.78, 0.78, 0.74), Vector2(1.0, 2.0)), true)
		island.name = "Island"
		var body := _box(root, Vector3(x, 1.0, 0), Vector3(0.9, 1.7, 0.6), red, true)
		_face(root, Vector3(x, 1.0, -0.3), Vector2(0.9, 1.7), Vector3(0, 0, -1), pump_face)
		_face(root, Vector3(x, 1.0, 0.3), Vector2(0.9, 1.7), Vector3(0, 0, 1), pump_face)
		pumps.append(w(at + Vector3(x, 0, -1.2)))
		body.name = "Pump"
	spots["pumps"] = pumps
	# Under the canopy three fluorescent tubes in their fittings, lit at night (one of
	# them going), and their hum.
	var tubes: Array = []
	for x in [-4.0, 0.0, 4.0]:
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.86, 0.9, 0.88)
		tm.emission_enabled = true
		tm.emission = Color(0.86, 0.96, 0.92)
		tm.emission_energy_multiplier = 0.0
		_box(root, Vector3(x, 4.72, 0.0), Vector3(2.4, 0.08, 0.22), _mat(TEX_CAMP + "galvanized.png", Color(0.7, 0.7, 0.68)))
		_box(root, Vector3(x, 4.67, 0.0), Vector3(2.2, 0.05, 0.12), tm)
		var tl := OmniLight3D.new()
		tl.light_color = Color(0.82, 0.92, 0.86)
		tl.light_energy = 3.2
		tl.omni_range = 10.0
		tl.omni_attenuation = 1.0
		tl.position = Vector3(x, 4.3, 0.0)
		tl.visible = false
		root.add_child(tl)
		tubes.append({"mat": tm, "light": tl})
	spots["station_tubes"] = tubes
	var buzz := AudioStreamPlayer3D.new()
	var bs = load("res://assets/sfx/motel/neon_buzz.ogg") if ResourceLoader.exists("res://assets/sfx/motel/neon_buzz.ogg") else null
	if bs != null:
		bs = (bs as AudioStream).duplicate()
		if bs is AudioStreamOggVorbis:
			(bs as AudioStreamOggVorbis).loop = true
		buzz.stream = bs
		buzz.volume_db = -14.0
		buzz.unit_size = 3.0
		buzz.max_distance = 22.0
		buzz.position = Vector3(0, 4.4, 0)
		root.add_child(buzz)
		spots["station_buzz"] = buzz
	# By the islands and the kiosk: the oil rack, the air post, the bin with the towels,
	# old tyres.
	for v in [["oil_rack", 0.95, Vector3(-3.6, 0, 5.2)], ["air_post", 1.25, Vector3(6.9, 0, 1.5)], ["bin_towels", 1.1, Vector3(-1.4, 0.2, 1.2)], ["tyres", 0.62, Vector3(4.6, 0, 6.2)]]:
		_station_prop(root, str(v[0]), float(v[1]), v[2])
	var kiosk := Node3D.new()
	kiosk.name = "Kiosk"
	kiosk.position = Vector3(0, 0, 9.0)
	root.add_child(kiosk)
	var kwall := _mat(TEX_CAMP + "concrete.png", Color(0.9, 0.9, 0.88), Vector2(3.0, 1.0))
	if ResourceLoader.exists(TEX + "kiosk_front_glass.png"):
		_kiosk_hollow(kiosk, kwall)
	else:
		_box(kiosk, Vector3(0, 1.6, 0), Vector3(10.0, 3.2, 6.0), kwall, true)
		_face(kiosk, Vector3(0, 1.6, -3.0), Vector2(5.7, 3.2), Vector3(0, 0, -1), _mat(_first([TEX + "kiosk_front.png"]), Color(0.7, 0.72, 0.74)))
	_box(kiosk, Vector3(0, 3.3, 0), Vector3(10.4, 0.2, 6.4), _mat("", Color(0.3, 0.3, 0.3)))
	# The toilet's door round the east side (wc_view.gd): its click in _hotspots.
	if ResourceLoader.exists(TEX_CAMP + "wc_door_out.png"):
		_face(kiosk, WC_DOOR + Vector3(0.03, 0, 0), Vector2(1.29, 2.3), Vector3(1, 0, 0), _mat(TEX_CAMP + "wc_door_out.png", Color(0.9, 0.9, 0.9)))
	spots["kiosk"] = kiosk
	spots["kiosk_door"] = w(at + Vector3(0, 0, 9.0 - 4.2))
	spots["station"] = root


func _station_prop(root: Node3D, tex: String, height: float, at: Vector3) -> void:
	var path := TEX + tex + ".png"
	if not ResourceLoader.exists(path):
		return
	var t: Texture2D = load(path)
	var sp := Sprite3D.new()
	sp.name = "StationThing"
	sp.texture = t
	sp.pixel_size = height / float(t.get_height())
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.shaded = true
	sp.offset = Vector2(0, float(t.get_height()) * 0.5)
	sp.position = at
	root.add_child(sp)


## Since 3. 11. the kiosk's window and door are glass you see through (kiosk_view.gd): its
## box hollow, the front wall cut round the glass behind the picture with its holes, the
## little shop built in it, lit while it is open (`_update_kiosk`).
const KIOSK_VIEW = preload("res://scripts/town/kiosk_view.gd")
## The toilet's door on the kiosk's east wall (the kiosk's own frame: x east, z to the back).
const WC_DOOR := Vector3(5.0, 1.15, 1.5)
var _kiosk_lit := -1


func _kiosk_hollow(kiosk: Node3D, kwall: Material) -> void:
	var V = KIOSK_VIEW
	var b: Vector3 = V.BOX
	_box(kiosk, Vector3(0, b.y * 0.5, b.z * 0.5 - 0.1), Vector3(b.x, b.y, 0.2), _tiled(kwall, Vector3(b.x, b.y, 0.2)))
	for sx in [-1.0, 1.0]:
		_box(kiosk, Vector3(float(sx) * (b.x * 0.5 - 0.1), b.y * 0.5, 0), Vector3(0.2, b.y, b.z), _tiled(kwall, Vector3(0.2, b.y, b.z)))
	var holes: Array = []
	for r in V.PANES + V.DOOR_GLASS:
		holes.append([V.W * 0.5 - float(r[2]) / V.PX_M, V.W * 0.5 - float(r[0]) / V.PX_M, V.H - float(r[3]) / V.PX_M, V.H - float(r[1]) / V.PX_M])
	for p in KIT.wall_pieces(b.x * 0.5, b.y, holes):
		_box(kiosk, Vector3((float(p[0]) + float(p[1])) * 0.5, (float(p[2]) + float(p[3])) * 0.5, -b.z * 0.5 + 0.08), Vector3(float(p[1]) - float(p[0]), float(p[3]) - float(p[2]), 0.16), kwall)
	_face(kiosk, Vector3(0, 1.6, -b.z * 0.5 - 0.02), Vector2(V.W, V.H), Vector3(0, 0, -1), _cut_mat(TEX + "kiosk_front_glass.png"))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.24, 0.29, 0.32, 0.16)
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for hl in holes:
		var g := _face(kiosk, Vector3((float(hl[0]) + float(hl[1])) * 0.5, (float(hl[2]) + float(hl[3])) * 0.5, -b.z * 0.5 + 0.1), Vector2(float(hl[1]) - float(hl[0]), float(hl[3]) - float(hl[2])), Vector3(0, 0, -1), glass)
		g.set_meta("retro_skip", true)
	_solid(kiosk, Vector3(0, b.y * 0.5, 0.25), Vector3(b.x - 0.4, b.y, b.z - 0.5))
	_update_kiosk(_hour, kiosk)


## A picture with holes, cut out by its alpha (the kiosk's front).
func _cut_mat(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = Color(0.86, 0.87, 0.88)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


## The shop behind the kiosk's glass: lit with Mrs Lojzova at the counter 6-21.
func _update_kiosk(h: float, kiosk: Node3D = null) -> void:
	if kiosk == null:
		var k = spots.get("kiosk")
		kiosk = k as Node3D if k is Node3D else null
	if kiosk == null or not ResourceLoader.exists(TEX + "kiosk_front_glass.png"):
		return
	var lit := 1 if (h >= 6.0 and h < 21.0) else 0
	if lit == _kiosk_lit and kiosk.get_node_or_null("Shop") != null:
		return
	_kiosk_lit = lit
	var old := kiosk.get_node_or_null("Shop")
	if old != null:
		old.name = "ShopOld"
		old.queue_free()
	var shop := Node3D.new()
	shop.name = "Shop"
	shop.position = KIOSK_VIEW.origin()
	shop.basis = KIOSK_VIEW.basis()
	kiosk.add_child(shop)
	KIOSK_VIEW.build(shop, null, lit == 1)
	spots["kiosk_shell"] = shop


# ── the stops ───────────────────────────────────────────────────────────────

## The stop for the camp: a shelter on the south side, open to the road (its local +z
## faces north).
func _stop_south() -> void:
	var concrete := _mat(_first([TEX + "stop_concrete.png", TEX_CAMP + "concrete.png"]), Color(0.86, 0.84, 0.8))
	var root := Node3D.new()
	root.position = Vector3(-2.0, 0, 6.4)
	root.rotation.y = PI
	if GEO_MODE:
		# West of the real street at the stop, open to the road (its +z towards it).
		var a := GEO.at(GEO.stop_s("liblice") - 3.0, -6.2)
		root.position = unw(a["p"])
		var to_road: Vector3 = unw(a["p"] + _right(a["dir"])) - root.position
		root.rotation.y = atan2(to_road.x, to_road.z)
	add_child(root)
	# The shelter, open to the road (south).
	_box(root, Vector3(0, 1.2, -0.9), Vector3(4.2, 2.4, 0.18), concrete, true)
	_box(root, Vector3(-2.0, 1.2, 0), Vector3(0.16, 2.4, 1.9), concrete, true)
	_box(root, Vector3(2.0, 1.2, 0), Vector3(0.16, 2.4, 1.9), concrete, true)
	_box(root, Vector3(0, 2.5, 0.1), Vector3(4.7, 0.18, 2.5), concrete)
	var planks := _mat(TEX_CAMP + "planks_grey.png", Color(0.7, 0.62, 0.5))
	_box(root, Vector3(0, 0.45, -0.5), Vector3(3.4, 0.06, 0.45), planks)
	_pole(root, Vector3(-2.8, 0, 1.3), "LIBLICE", "town")


## The stop for Hlubocany: only a pole by the square.
func _stop_north() -> void:
	var root := Node3D.new()
	root.position = Vector3(10.0, 0, -5.6)
	if GEO_MODE:
		var b := GEO.at(GEO.stop_s("liblice") + 6.0, 5.4)
		root.position = unw(b["p"])
		var to_road: Vector3 = unw(b["p"] - _right(b["dir"])) - root.position
		root.rotation.y = atan2(to_road.x, to_road.z)
	add_child(root)
	_pole(root, Vector3(0, 0, 0), "LIBLICE", "town_through")


## A stop pole: the bus sign, the name, a timetable case (clickable).
func _pole(root: Node3D, at: Vector3, stop_name: String, stop_id: String) -> void:
	# The yellow ticket machine beside it, facing the road.
	preload("res://scripts/town/ticket_machine.gd").place(root, at + Vector3(0.8, 0, 0.1), 0.0, "town")
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


const POND_SHADER = preload("res://materials/lake_water.gdshader")
const REEDS := "res://assets/textury/world/reeds.png"
var _pond_mat: ShaderMaterial


## Reeds thick in the pond's corners and thin along its long sides, standing in the water.
func _pond_reeds(pond: Vector3) -> void:
	if not ResourceLoader.exists(REEDS):
		return
	var t: Texture2D = load(REEDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111
	for c in [Vector2(-5.2, -3.2), Vector2(5.2, -3.2), Vector2(-5.2, 3.2), Vector2(5.2, 3.2), Vector2(-1.5, 3.4), Vector2(2.4, -3.4)]:
		var n := 5 if absf(c.x) > 5.0 else 2
		for k in n:
			var sp := Sprite3D.new()
			sp.name = "Reeds"
			sp.texture = t
			var h := rng.randf_range(0.9, 1.5)
			sp.pixel_size = h / float(t.get_height())
			sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			sp.shaded = true
			sp.flip_h = rng.randf() < 0.5
			sp.offset = Vector2(0, float(t.get_height()) * 0.5)
			sp.position = pond + Vector3(c.x + rng.randf_range(-0.6, 0.6), 0.02, c.y + rng.randf_range(-0.4, 0.4))
			add_child(sp)


## The pond as lit as the hour: dark at night with a glint of the moon, bright by day.
func _pond_light(h: float) -> void:
	if _pond_mat == null:
		return
	var day := clampf(minf((h - 5.0) / 2.0, (21.0 - h) / 2.0), 0.0, 1.0)
	_pond_mat.set_shader_parameter("light_level", lerpf(0.14, 1.0, day))
	_pond_mat.set_shader_parameter("sky_col", Color(0.58, 0.64, 0.7).lerp(Color(0.12, 0.14, 0.22), 1.0 - day))


func _lamps() -> void:
	var lights: Array = []
	var pic := TEX + "sodium_lamp.png"
	for x in [-40.0, -12.0, 18.0, 44.0]:
		var at := Vector3(x, 0, -4.2)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 4.2
		l.omni_range = 15.0
		l.omni_attenuation = 1.05
		l.position = at + Vector3(0, 5.4, 0.6)
		l.visible = false
		add_child(l)
		if ResourceLoader.exists(pic):
			var glow := _lamp_post(at, pic)
			lights.append([l, glow])
			continue
		var post := _mat(TEX_CAMP + "concrete.png", Color(0.78, 0.78, 0.76))
		_box(self, at + Vector3(0, 2.6, 0), Vector3(0.16, 5.2, 0.16), post, true)
		_box(self, at + Vector3(0, 5.15, 0.6), Vector3(0.1, 0.1, 1.3), post)
		var bulb := StandardMaterial3D.new()
		bulb.albedo_color = Color(0.6, 0.58, 0.5)
		bulb.emission_enabled = true
		_box(self, at + Vector3(0, 5.05, 1.15), Vector3(0.4, 0.14, 0.3), bulb)
		lights.append([l, bulb])
	# The chapel's bulb (built before these) is switched with them.
	if not _chapel_bulb.is_empty():
		lights.append(_chapel_bulb)
	spots["lamps"] = lights


var _chapel_bulb: Array = []
var _chapel_oval: StandardMaterial3D
var _bulb_t := 12.0


## A soft round glow at `at` (an effect, turned to you), lit by set_night: its material.
func _glow(at: Vector3, size: float) -> StandardMaterial3D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var d := Vector2(x - 5.5, y - 5.5).length() / 6.0
			img.set_pixel(x, y, Color(1.0, 0.74, 0.42, clampf(1.0 - d, 0.0, 1.0) * (0.9 if d < 0.45 else 0.45)))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.emission_enabled = true
	m.emission = Color(0, 0, 0)
	m.albedo_color = Color(1, 1, 1, 0)
	var q := MeshInstance3D.new()
	q.name = "Glow"
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	q.mesh = qm
	q.material_override = m
	q.position = at
	q.set_meta("retro_skip", true)
	add_child(q)
	return m


## Lamp post `pic` (a sprite turned to you, the post on `at`) and the glow over its head:
## the glow's material comes back, for set_night to light.
const LAMP_H := 6.2
const LAMP_POST_PX := 10
const LAMP_HEAD_PX := Vector2(41, 22)


func _lamp_post(at: Vector3, pic: String) -> StandardMaterial3D:
	var t: Texture2D = load(pic)
	var px := LAMP_H / float(t.get_height())
	var sp := Sprite3D.new()
	sp.name = "LampPost"
	sp.texture = t
	sp.pixel_size = px
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.shaded = true
	# The post's foot on `at` (it stands at the picture's left).
	sp.offset = Vector2(float(t.get_width()) * 0.5 - float(LAMP_POST_PX), float(t.get_height()) * 0.5)
	sp.position = at
	add_child(sp)
	_solid(self, at + Vector3(0, 2.6, 0), Vector3(0.2, 5.2, 0.2))
	# The glow: a soft round patch over the glass, turned with the post.
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var d := Vector2(x - 5.5, y - 5.5).length() / 6.0
			img.set_pixel(x, y, Color(1.0, 0.7, 0.36, clampf(1.0 - d, 0.0, 1.0) * (0.9 if d < 0.45 else 0.45)))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.emission_enabled = true
	m.emission = Color(0, 0, 0)
	m.albedo_color = Color(1, 1, 1, 0)
	var q := MeshInstance3D.new()
	q.name = "LampGlow"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.75, 0.75)
	# Over the glass, where the picture has it from the post (in its pixels).
	qm.center_offset = Vector3((LAMP_HEAD_PX.x - float(LAMP_POST_PX)) * px, (float(t.get_height()) - LAMP_HEAD_PX.y) * px, 0.02)
	q.mesh = qm
	q.material_override = m
	q.position = at
	q.set_meta("retro_skip", true)
	add_child(q)
	return m


## The naves across the road from the Jednota and the pub, as in Liblice ("Ve Stare
## vsi"): grass with trodden paths, the little pond in its stone rim, the war memorial
## facing the road, the white bell pillar (zvonicka) with the stone cross beside it,
## lime trees and benches. The houses on its far side look over it at the road.
func _green() -> void:
	var stone := _mat(TEX_CAMP + "plaster_stone.png", Color(0.82, 0.8, 0.76), Vector2(3.0, 1.0))
	var pond := Vector3(8.0, 0, 20.0)
	var water := _plane(self, pond + Vector3(0, 0.05, 0), Vector2(12.0, 8.0), _mat(TEX_CAMP + "lake_water.png", Color(0.56, 0.62, 0.6), Vector2(3.0, 2.0)))
	if water is GeometryInstance3D:
		var wm := ShaderMaterial.new()
		wm.shader = POND_SHADER
		wm.set_shader_parameter("water_tex", load(TEX_CAMP + "lake_water.png"))
		wm.set_shader_parameter("tex_scale", 0.16)
		wm.set_shader_parameter("tint", Color(0.38, 0.46, 0.36))
		wm.set_shader_parameter("deep", Color(0.2, 0.24, 0.18))
		# No shore to go deeper from: the same all over.
		wm.set_shader_parameter("shore_z", Vector2(-1000.0, -900.0))
		wm.set_shader_parameter("sky_col", Color(0.58, 0.64, 0.7))
		wm.set_shader_parameter("wind", 0.12)
		(water as GeometryInstance3D).material_override = wm
		(water as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pond_mat = wm
	_pond_reeds(pond)
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
	# Cut into the stone: PADLYM and the two wars' years.
	for row in [["pomnik_padlym", 1.95], ["pomnik_1918", 1.55], ["pomnik_1945", 1.3]]:
		_letters(self, str(row[0]), mem + Vector3(0, float(row[1]), -0.25), Vector3(0, 0, -1))
	spots["memorial"] = w(mem)
	# Benches round the pond, looking at it.
	_bench(Vector3(8.0, 0, 14.6), 0.0)
	_bench(Vector3(0.6, 0, 20.0), PI * 0.5)
	_bench(Vector3(15.4, 0, 20.0), -PI * 0.5)
	spots["bench"] = w(Vector3(8.0, 0, 14.6))
	_zvonicka(Vector3(-6.0, 0, 13.5))
	_stone_cross(Vector3(-2.6, 0, 12.0))
	# Lindens round the green (world_generator.gd's linden: bole, dome, leaf cards).
	if worldgen != null and worldgen.has_method("_tree_mesh"):
		var k := 0
		for t in [Vector3(19.5, 0, 8.8), Vector3(33.0, 0, 21.0), Vector3(-8.5, 0, 22.5), Vector3(-9.0, 0, 9.5)]:
			_linden(self, t, 0.95 + 0.06 * float(k % 3), 1.3 * float(k))
			_solid(self, t + Vector3(0, 1.5, 0), Vector3(0.8, 3.0, 0.8))
			k += 1


## A linden (world_generator.gd's): its bole and limbs, the crown, the leaf cards.
func _linden(parent: Node3D, at: Vector3, size: float, yaw: float) -> void:
	for part in [["linden_trunk", worldgen._tree_material("bark", 0)], ["linden_crown", worldgen._tree_material("leaf", 0)], ["linden_cards", worldgen._tree_material("leaf_cards", 1)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = worldgen._tree_mesh(str(part[0]))
		mi.material_override = part[1]
		mi.position = at
		mi.rotation.y = yaw
		mi.scale = Vector3.ONE * size
		parent.add_child(mi)


## A bench: plank seat and back, looking along `yaw` (0 = towards +z).
func _bench(at: Vector3, yaw: float) -> void:
	_park_bench(self, at, yaw)


## A park bench the way the national committee set them out: two cast concrete sides,
## three seat slats and three back slats of planed wood in faded green paint, the back
## leaning a little. You can sit on it (building_type "town_bench": town_trip.gd sits you
## down looking the way it faces, local +z).
func _park_bench(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var wood := _mat(TEX_CAMP + "planks_grey.png", Color(0.42, 0.56, 0.4), Vector2(2.0, 0.3))
	var concrete := _mat(TEX_CAMP + "concrete.png", Color(0.72, 0.72, 0.7), Vector2(0.3, 0.3))
	var bolts := _mat("", Color(0.18, 0.16, 0.14))
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	for x in [-0.78, 0.78]:
		_box(root, Vector3(x, 0.21, 0.02), Vector3(0.1, 0.42, 0.5), concrete)
		_box(root, Vector3(x, 0.02, 0.02), Vector3(0.14, 0.04, 0.56), concrete)
		var arm := _box(root, Vector3(x, 0.66, -0.2), Vector3(0.09, 0.5, 0.09), concrete)
		arm.rotation.x = -0.25
	for k in 3:
		_box(root, Vector3(0, 0.44, -0.14 + float(k) * 0.15), Vector3(1.86, 0.035, 0.12), wood)
	for k in 3:
		var slat := _box(root, Vector3(0, 0.6 + float(k) * 0.13, -0.24 - float(k) * 0.035), Vector3(1.86, 0.1, 0.03), wood)
		slat.rotation.x = -0.25
	for x in [-0.78, 0.78]:
		_box(root, Vector3(x, 0.465, 0.0), Vector3(0.12, 0.012, 0.3), bolts)
	_solid(root, Vector3(0, 0.25, 0.0), Vector3(1.8, 0.5, 0.5))
	var seat := StaticBody3D.new()
	seat.collision_layer = 1 << 11
	seat.collision_mask = 0
	seat.set_meta("building_type", "town_bench")
	seat.add_to_group("town_bench")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.9, 0.7)
	shape.shape = box
	seat.add_child(shape)
	seat.position = Vector3(0, 0.5, 0.05)
	root.add_child(seat)
	return root


## The side street (Za Kaplickou): off the main road west of the chapel, north between
## the gardens, then bending right towards the east behind the Jednota and the pub,
## older patched asphalt without kerbs; three houses on its outer side, a farmyard gate,
## a lamp at the bend, a bench under the chapel's wall.
func _side_street() -> void:
	var asphalt := _mat(_first([TEX + "asphalt.png", TEX_CAMP + "gravel_road.png"]), Color(0.6, 0.6, 0.6), Vector2(1.0, 6.0))
	var pts: Array = [Vector3(-33.6, 0, -3.4), Vector3(-33.6, 0, -36.0)]
	var centre := Vector3(-33.6 + 14.0, 0, -36.0)
	for k in range(1, 9):
		var a := PI * 0.5 * float(k) / 8.0
		pts.append(centre + Vector3(-14.0 * cos(a), 0, -14.0 * sin(a)))
	pts.append(Vector3(36.0, 0, -50.0))
	for i in pts.size() - 1:
		var a2: Vector3 = pts[i]
		var b2: Vector3 = pts[i + 1]
		var length := a2.distance_to(b2) + 0.5
		var m := (asphalt as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.uv1_scale = Vector3(1.0, length / 5.0, 1.0)
		var pl := _plane(self, (a2 + b2) * 0.5 + Vector3(0, 0.014, 0), Vector2(5.0, length), m)
		pl.rotation.y = atan2(b2.x - a2.x, b2.z - a2.z)
	spots["side_street"] = pts
	var white := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(1.0, 0.98, 0.94), Vector2(3.0, 1.0))
	var houses: Array = spots.get("houses", [])
	var gi := houses.size()
	for row in [["lib_gable_grey", -12.0, 31], ["lib_gable_red", 0.0, 37], ["lib_gable_white", 12.0, 41]]:
		var house := _gable_house(str(row[0]), float(row[1]), -55.0, 1.0, 12.0, white, {"kind": gi, "number": int(row[2]), "eternit": str(row[0]) == "lib_gable_grey"})
		if not house.is_empty():
			houses.append(house)
			gi += 1
	spots["houses"] = houses
	_farm_wall(23.0, -55.0, 1.0)
	_park_bench(self, Vector3(-30.2, 0, -14.0), PI * 0.5)


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
## Fronts whose plain wall is too patchy to tile (the ochre one is brick showing through
## all over: mirrored into a tile it made a kaleidoscope on the back walls; the chapel's
## tiled into false ovals beside its real windows), and the plaster their other walls
## get instead.
const SIDE_FROM := {"lib_gable_ochre": "village_plaster.png", "lib_chapel": "village_plaster.png"}


func _side_mat(fid: String, fallback: Material) -> Material:
	if SIDE_FROM.has(fid) and ResourceLoader.exists(TEX + str(SIDE_FROM[fid])):
		return _mat(TEX + str(SIDE_FROM[fid]), Color(1.0, 0.97, 0.94), Vector2(3.0, 1.0))
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
		var bare := bool(opts.get("bare", false))
		var chx := off + ww * 0.22
		var roof_y := wh + rise - (ww * 0.22) * tan(ang)
		var chim := Vector3(chx, roof_y + 0.5, -fz * 0.3)
		if not bare:
			_box(root, chim, Vector3(0.55, 1.6, 0.55), _mat(TEX_CAMP + "brick_red.png", Color(0.9, 0.85, 0.8)))
			_box(root, chim + Vector3(0, 0.84, 0), Vector3(0.72, 0.08, 0.72), _house_mats()["sill"])
		if not bare and _rng.randf() < 0.7:
			_chimneys.append(root.position + chim + Vector3(0, 0.9, 0))
		# The ridge tiles, the gutters along both eaves with the downpipe at the back of
		# the yard side, and (on most) the TV aerial on its pole, turned to Liblice.
		_box(root, Vector3(off, wh + rise + 0.15, 0), Vector3(0.26, 0.12, depth + 0.5), _house_mats()["ridge"])
		var eave_y := wh + 0.08 - 0.35 * rise / (ww * 0.5)
		_gutters(root, off, ww, half, eave_y, depth, -fz * 0.94)
		if not bare and _rng.randf() < 0.65:
			_aerial(root, Vector3(off - ww * 0.12, wh + rise + 0.1, -fz * 0.6))
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
	var no_house := bool(opts.get("bare", false))
	if not no_house:
		_face(root, yard + Vector3(0, 1.05, door_z), Vector2(1.0, 2.1), Vector3(1, 0, 0), door_mats[int(opts.get("kind", 0)) % door_mats.size()])
	if not bool(opts.get("ruin", false)) and not no_house:
		_porch(root, yard, door_z)
	if not kind.is_empty() and not no_house:
		var k := 1
		while depth * 0.5 - (2.2 + 3.0 * k) > -depth * 0.5 + 1.2:
			var wz := fz - facing * (2.2 + 3.0 * k)
			var win := _face(root, yard + Vector3(0, 1.7, wz), Vector2(1.2, 1.25), Vector3(1, 0, 0), kind[0])
			_box(root, yard + Vector3(0.07, 1.04, wz), Vector3(0.14, 0.05, 1.36), _house_mats()["sill"])
			lit_windows.append({"mesh": win, "on": _rng.randf_range(17.5, 20.5), "off": _rng.randf_range(21.5, 24.5), "dark": kind[0], "lit": kind[1]})
			k += 1
		# Two windows in the back wall over the garden, with their sills.
		if not bool(opts.get("ruin", false)):
			for bx in [-0.24, 0.24]:
				var back := Vector3(off + bx * ww, 1.7, -fz)
				var bwin := _face(root, back, Vector2(1.1, 1.2), Vector3(0, 0, -facing), kind[0])
				lit_windows.append({"mesh": bwin, "on": _rng.randf_range(18.0, 21.0), "off": _rng.randf_range(21.0, 23.5), "dark": kind[0], "lit": kind[1]})
				_box(root, back + Vector3(0, -0.63, -facing * 0.07), Vector3(1.24, 0.05, 0.14), _house_mats()["sill"])
	spots["lit_windows"] = lit_windows
	if opts.has("number"):
		_letters(root, "cp_" + str(opts["number"]), Vector3(off + ww * 0.4 * facing, wh * 0.62, fz + facing * 0.02), Vector3(0, 0, facing))
	_plinth(root, off, ww, depth, fz)
	_front_sills(root, fid, W, H, fz, facing)
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
	_box(root, chim + Vector3(0, 0.74, 0), Vector3(0.66, 0.08, 0.66), _house_mats()["sill"])
	_chimneys.append(root.position + chim + Vector3(0, 0.8, 0))
	# Gutters round all four eaves, the aerial on the top.
	for side in [-1.0, 1.0]:
		_box(root, Vector3(side * (hw - 0.03), wh - 0.07, 0), Vector3(0.12, 0.1, hd * 2.0), _house_mats()["tin"])
		_box(root, Vector3(0, wh - 0.07, side * (hd - 0.03)), Vector3(hw * 2.0, 0.1, 0.12), _house_mats()["tin"])
	_box(root, Vector3(hw - 0.2, (wh - 0.1) * 0.5, -fz * 0.97), Vector3(0.08, wh - 0.1, 0.08), _house_mats()["tin"])
	_aerial(root, Vector3(-W * 0.12, top - 0.1, -rl * 0.5))
	_plinth(root, 0.0, ww, depth, fz)
	_front_sills(root, fid, W, H, fz, facing)
	if opts.has("number"):
		_letters(root, "cp_" + str(opts["number"]), Vector3(-ww * 0.36 * facing, wh * 0.35, fz + facing * 0.02), Vector3(0, 0, facing))
	return {"at": root.position, "size": Vector3(ww, wh, depth), "facing": facing, "root": root}


# ── what a box with a picture on it lacks ─────────────────────────────────────
# Playtest 20. 10.: "the houses better, in the style it is meant to be". The Build
# engine's houses were never flat: things stand out of the walls. Here: a grey roughcast
# plinth round the sides and the back (the street front has its own in the picture), a
# sill under every window, gutters along the eaves with a downpipe, the ridge tiles, a cap
# on each chimney, on most roofs a TV aerial on its pole turned towards the transmitter,
# and at the yard door a concrete step and a little tin canopy.

var _hmats: Dictionary = {}


func _house_mats() -> Dictionary:
	if _hmats.is_empty():
		_hmats = {
			"plinth": _mat(_first([TEX_CAMP + "roughcast_wall.png", TEX_CAMP + "concrete.png"]), Color(0.46, 0.46, 0.44), Vector2(6.0, 0.5)),
			"sill": _mat(TEX_CAMP + "concrete.png", Color(0.72, 0.71, 0.67), Vector2(0.5, 0.2)),
			"tin": _mat("", Color(0.44, 0.46, 0.45)),
			"iron": _mat("", Color(0.2, 0.2, 0.2)),
			"ridge": _mat(_first([TEX + "roof_tiles.png", TEX_CAMP + "corrugated_roof.png"]), Color(0.5, 0.3, 0.24), Vector2(0.3, 4.0)),
			"canopy": _mat(_first([TEX_CAMP + "corrugated_roof.png", TEX + "roof_eternit.png"]), Color(0.7, 0.7, 0.68), Vector2(1.0, 1.0)),
		}
	return _hmats


## The plinth (sokl): a band of grey roughcast 55 cm high, standing 2.5 cm out of the
## two sides and the back of a house whose walls are `ww` wide and `depth` deep round
## x = `cx` (its front at z = `fz`).
func _plinth(root: Node3D, cx: float, ww: float, depth: float, fz: float) -> void:
	var m: Material = _house_mats()["plinth"]
	var h := 0.55
	for side in [-1.0, 1.0]:
		_box(root, Vector3(cx + side * (ww * 0.5 + 0.0125), h * 0.5, 0), Vector3(0.025, h, depth), m)
	_box(root, Vector3(cx, h * 0.5, -fz - signf(fz) * 0.0125), Vector3(ww + 0.05, h, 0.025), m)


## A concrete sill under each window of the front picture (lib_facades.json "windows",
## fractions of the picture); not under a door.
func _front_sills(root: Node3D, fid: String, W: float, H: float, fz: float, facing: float) -> void:
	for win in _front_meta(fid).get("windows", []):
		var x0: float = win[0]
		var x1: float = win[2]
		var bottom := H * (1.0 - float(win[3]))
		if bottom < 0.5:
			continue
		var cx := facing * ((x0 + x1) * 0.5 - 0.5) * W
		_box(root, Vector3(cx, bottom - 0.03, fz + facing * 0.1), Vector3((x1 - x0) * W + 0.16, 0.06, 0.16), _house_mats()["sill"])


## Gutters under both eaves of a saddle roof (`half` out from `off`, its edge at `eave_y`)
## and a downpipe down the yard side's back corner (z = `pipe_z`).
func _gutters(root: Node3D, off: float, ww: float, half: float, eave_y: float, depth: float, pipe_z: float) -> void:
	var tin: Material = _house_mats()["tin"]
	for side in [-1.0, 1.0]:
		_box(root, Vector3(off + side * (half - 0.05), eave_y - 0.1, 0), Vector3(0.12, 0.1, depth + 0.5), tin)
	var px := off + ww * 0.5 + 0.08
	_box(root, Vector3(px, (eave_y - 0.12) * 0.5, pipe_z), Vector3(0.08, eave_y - 0.12, 0.08), tin)
	_box(root, Vector3((px + off + half - 0.05) * 0.5, eave_y - 0.14, pipe_z), Vector3(half - ww * 0.5 - 0.05, 0.07, 0.07), tin)
	_box(root, Vector3(px + 0.08, 0.1, pipe_z), Vector3(0.24, 0.07, 0.08), tin)


## A TV aerial on its pole on the roof (the poles are what you saw of every Czech
## village's roofs): guy wires left out, a boom with its elements, all of them turned
## west to the masts at Liblice.
func _aerial(root: Node3D, at: Vector3) -> void:
	var iron: Material = _house_mats()["iron"]
	var a := Node3D.new()
	a.position = at
	a.rotation.y = -PI * 0.5 + _rng.randf_range(-0.12, 0.12)
	root.add_child(a)
	var h := _rng.randf_range(1.8, 2.8)
	_box(a, Vector3(0, h * 0.5, 0), Vector3(0.07, h, 0.07), iron)
	var booms := 2 if _rng.randf() < 0.4 else 1
	for b in booms:
		var y := h - 0.08 - float(b) * 0.55
		var length := 1.5 - float(b) * 0.4
		_box(a, Vector3(0, y, -length * 0.35), Vector3(0.045, 0.045, length), iron)
		var n := 6 - b * 2
		for k in n:
			var z := -length * 0.35 - length * 0.5 + length * (float(k) + 0.5) / float(n)
			_box(a, Vector3(0, y, z), Vector3(0.62 - 0.05 * float(k), 0.03, 0.03), iron)


## The yard door's concrete step and the little canopy of corrugated tin over it on two
## brackets. `yard`: the yard wall's foot (its x), `door_z` where the door is.
func _porch(root: Node3D, yard: Vector3, door_z: float) -> void:
	_box(root, Vector3(yard.x + 0.3, 0.09, door_z), Vector3(0.6, 0.18, 1.4), _house_mats()["sill"])
	var c := _box(root, Vector3(yard.x + 0.42, 2.38, door_z), Vector3(0.86, 0.05, 1.5), _house_mats()["canopy"])
	c.rotation.z = -0.18
	for dz in [-0.62, 0.62]:
		var br := _box(root, Vector3(yard.x + 0.25, 2.18, door_z + dz), Vector3(0.5, 0.04, 0.04), _house_mats()["iron"])
		br.rotation.z = 0.55


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
		var eave_y := wh + 0.08 - 0.4 * rise / (depth * 0.5)
		_box(root, Vector3(0, eave_y - 0.1, side * (half - 0.05)), Vector3(W + 0.5, 0.1, 0.12), _house_mats()["tin"])
	_box(root, Vector3(0, wh + rise + 0.15, 0), Vector3(W + 0.5, 0.12, 0.26), _house_mats()["ridge"])
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
			if absf(p.z) < 9.0 and absf(p.x) < 250.0:
				continue
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
	if not spots.has("motel_block"):
		_click(Vector3(-30.0, 1.1, 10.4), Vector3(1.6, 2.2, 0.4), "town_door", "motel")
	_click(Vector3(50.0, 1.1, 18.9), Vector3(1.6, 2.2, 0.4), "town_door", "kiosk")
	if ResourceLoader.exists(TEX_CAMP + "wc_door_out.png"):
		_click(Vector3(48.0, 0, 22.0) + WC_DOOR + Vector3(0.1, 0, 0), Vector3(0.4, 2.2, 1.2), "town_door", "wc")
	_click(Vector3(-28.0, 1.3, -18.4), Vector3(1.6, 2.6, 0.4), "town_door", "chapel")
	_click(Vector3(26.0, 1.4, 12.6), Vector3(1.2, 2.2, 0.8), "town_read", "memorial")
	var pumps: Array = spots.get("pumps", [])
	for i in pumps.size():
		var body := _click(unw(pumps[i] as Vector3) + Vector3(0, 1.0, 1.2), Vector3(1.0, 1.8, 0.8), "town_pump", "pump")
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
	if _station_night:
		_tick_tubes(delta)
		_tick_bulb(delta)
		_tick_jednota_tube(delta)
		if _chapel_oval != null:
			# The candles inside the chapel: slow, uneven.
			var cs := floorf(_smoke_t * 6.0)
			_chapel_oval.emission_energy_multiplier = 0.5 + 0.08 * sin(cs * 0.9) + 0.05 * sin(cs * 2.3)
	var step := floorf(_smoke_t * 12.0) / 12.0
	for p in _smoke:
		var age := fmod(step * 0.22 + float(p["phase"]), 1.0)
		var s: Sprite3D = p["sprite"]
		s.position = (p["base"] as Vector3) + Vector3(age * 1.6, age * 4.5, age * 0.4)
		s.scale = Vector3.ONE * (0.6 + age * 1.8)
		s.modulate = Color(1, 1, 1, (1.0 - age) * 0.7)


var _station_night := false
var _tube_t := 0.0
var _tube_out := 0.0


func _tick_bulb(delta: float) -> void:
	if _chapel_bulb.is_empty():
		return
	_bulb_t -= delta
	var l: OmniLight3D = _chapel_bulb[0]
	var g: StandardMaterial3D = _chapel_bulb[1]
	var out := _bulb_t < 0.0 and _bulb_t > -0.16
	if _bulb_t < -0.16:
		_bulb_t = _rng.randf_range(8.0, 30.0)
	l.light_energy = 0.1 if out else 1.2
	g.albedo_color = Color(1, 1, 1, 0.15 if out else 1.0)


func _tick_tubes(delta: float) -> void:
	var tubes: Array = spots.get("station_tubes", [])
	if tubes.size() < 2:
		return
	var t: Dictionary = tubes[1]
	_tube_t -= delta
	if _tube_t <= 0.0:
		_tube_t = _rng.randf_range(0.05, 0.4) if _tube_out > 0.0 else _rng.randf_range(2.0, 9.0)
		_tube_out = 0.0 if _tube_out > 0.0 else 1.0
	var on := _tube_out <= 0.0 or fmod(_smoke_t * 23.0, 1.0) < 0.35
	(t["light"] as OmniLight3D).light_energy = 3.2 if on else 0.3
	(t["mat"] as StandardMaterial3D).emission_energy_multiplier = 2.2 if on else 0.3


## The hour, for the windows (town_trip.gd, now and then).
func set_hour(h: float) -> void:
	_hour = h
	_pond_light(h)
	_update_jednota(h)
	_update_pub(h)
	_update_kiosk(h)
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
		var gm := pair[1] as StandardMaterial3D
		gm.emission = Color(1.0, 0.76, 0.42) * (1.6 if night else 0.0)
		if gm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			gm.albedo_color = Color(1, 1, 1, 1.0 if night else 0.0)
	_station_night = night
	_show_jednota_tube(night)
	if _pub_street != null and is_instance_valid(_pub_street):
		_pub_street.set_on(night)
	if _chapel_oval != null:
		_chapel_oval.emission_energy_multiplier = 0.5 if night else 0.0
	for t in spots.get("station_tubes", []):
		(t["light"] as OmniLight3D).visible = night
		(t["mat"] as StandardMaterial3D).emission_energy_multiplier = 2.2 if night else 0.0
	var buzz = spots.get("station_buzz")
	if buzz != null and is_instance_valid(buzz):
		if night and not (buzz as AudioStreamPlayer3D).playing:
			(buzz as AudioStreamPlayer3D).play()
		elif not night:
			(buzz as AudioStreamPlayer3D).stop()
	var neon = spots.get("motel_neon", null)
	if neon != null:
		(neon as StandardMaterial3D).emission_energy_multiplier = 1.8 if night else 0.0
