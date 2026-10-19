extends "res://scripts/town/town_lesna.gd"

## Podlesi: a hamlet of a few houses off the road between the camp and Lesna, south
## Bohemia's backwater (built by hamlet_trip.gd the first time you get off there, far off
## in the same world: HAMLET_ORIGIN). The road runs east-west past it with its Czech road
## posts; at the turn the request stop PODLESI, rozc. on both sides (south for the buses
## to Lesna, north for the ones to the camp). By the road the ruined Hronek farmhouse,
## roofless since the seventies, Babetta and all. A dusty track with grass between its
## ruts leads a hundred metres south through the meadow to the hamlet: old Vondra's
## rustic baroque farmhouse, a cottage with a boarded gable, an ochre house, a little
## pond, the woodpile with the chopping block, washing on the line, a Trabant rusting
## behind the house, and the garage with Vondra's Skoda 120 that has not gone since 1991
## (the repair: hamlet_trip.gd, car_closeup.gd). Spruce forest all round.
##
## It shares Lesna's house kit (town_lesna.gd: fronts from Grok elevations, lettering on
## the walls); its own frame (x east, z south, the road at z = 0, the hamlet at z ~120).

const HAMLET_ORIGIN := Vector3(1800.0, 0.0, -2600.0)
## Where the bus stops for you (the pole) going to Lesna (+x) and to the camp (-x).
const POLE_TOWN := Vector3(8.0, 0, 4.4)
const POLE_CAMP := Vector3(-8.0, 0, -4.4)
## The walkable ground: the road, the track and the hamlet (an outline, x and z).
const OUTLINE := [Vector2(-110, -14), Vector2(110, -14), Vector2(110, 9), Vector2(14, 9), Vector2(14, 98),
	Vector2(42, 98), Vector2(42, 152), Vector2(-42, 152), Vector2(-42, 98), Vector2(-10, 98), Vector2(-10, 9), Vector2(-110, 9)]

## The things you click (building_type "ham_*", meta "what"), by name.
var things: Dictionary = {}
var vondra: Sprite3D
var car_root: Node3D
var _smoke_car: Array = []


func build(p_worldgen: Node) -> void:
	name = "Podlesi"
	worldgen = p_worldgen
	_rng.seed = 7
	position = HAMLET_ORIGIN
	_ground_h()
	_road_h()
	_walls_h()
	_stops_h()
	_track()
	_ruin_h()
	_hamlet_houses()
	_garage()
	_yard()
	_forest_h()
	_lamps_h()
	_build_smoke()


func w(local: Vector3) -> Vector3:
	return HAMLET_ORIGIN + local


## Where you get off: by the pole the bus came to, facing the turn.
func hamlet_arrive_spot(towards_town: bool) -> Transform3D:
	var pole := POLE_TOWN if towards_town else POLE_CAMP
	var pos := w(pole + Vector3(-1.4 if towards_town else 1.4, 0.15, 0.9 if towards_town else -0.9))
	return Transform3D(Basis.looking_at(Vector3(-0.8, 0, 1.0) if towards_town else Vector3(0.9, 0, 0.9), Vector3.UP), pos)


## The bus standing at the pole for `towards_town`, and its way in and out.
func hamlet_bus_pose(towards_town: bool) -> Transform3D:
	if towards_town:
		return Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), w(Vector3(5.0, 0, 1.6)))
	return Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), w(Vector3(-5.0, 0, -1.6)))


func hamlet_in_path(towards_town: bool) -> PackedVector3Array:
	var end := hamlet_bus_pose(towards_town).origin
	var d := 1.0 if towards_town else -1.0
	var out := PackedVector3Array()
	for k in [-220.0, -120.0, -50.0, -14.0, 0.0]:
		out.append(end + Vector3(d * k, 0, 0))
	return out


func hamlet_out_path(towards_town: bool) -> PackedVector3Array:
	var start := hamlet_bus_pose(towards_town).origin
	var d := 1.0 if towards_town else -1.0
	var out := PackedVector3Array()
	for k in [0.0, 14.0, 50.0, 120.0, 230.0]:
		out.append(start + Vector3(d * k, 0, 0))
	return out


# ── the land ────────────────────────────────────────────────────────────────

func _ground_h() -> void:
	var grass := _mat(_first([TEX + "meadow.png", TEX_CAMP + "pitch_grass.png"]), Color(0.86, 0.92, 0.72), Vector2(90.0, 90.0))
	_plane(self, Vector3(0, -0.02, 60.0), Vector2(520, 520), grass).add_to_group("season_ground")
	_solid(self, Vector3(0, -0.5, 60.0), Vector3(300.0, 1.0, 300.0))


## The road from the camp to Lesna: patched asphalt, a worn centre line, grass verges,
## the posts both sides every 50 m (none at the turn).
func _road_h() -> void:
	var asphalt := _mat(_first([TEX + "asphalt.png", TEX_CAMP + "gravel_road.png"]), Color(0.66, 0.66, 0.68), Vector2(80.0, 1.0))
	_plane(self, Vector3(0, 0.01, 0), Vector2(480, 6.0), asphalt)
	var paint := _mat("", Color(0.86, 0.84, 0.76))
	var x := -236.0
	while x < 236.0:
		if _rng.randf() < 0.85:
			_plane(self, Vector3(x, 0.02, 0), Vector2(3.0, 0.12), paint)
		x += 10.0
	for px in [-200.0, -150.0, -100.0, -50.0, 50.0, 100.0, 150.0, 200.0]:
		for side in [-1.0, 1.0]:
			ROAD_POST.place(self, Vector3(px, 0.0, side * 3.7), Vector3(0, 0, -side))


func _walls_h() -> void:
	for i in OUTLINE.size():
		var a: Vector2 = OUTLINE[i]
		var b: Vector2 = OUTLINE[(i + 1) % OUTLINE.size()]
		var mid := Vector3((a.x + b.x) * 0.5, 2.0, (a.y + b.y) * 0.5)
		var body := _solid(self, mid, Vector3(0.4, 4.0, a.distance_to(b) + 0.4))
		body.rotation.y = atan2(b.x - a.x, b.y - a.y)


## The request stop both sides: a pole with the bus sign, the name plate "PODLESI, rozc.
## na znameni" and the timetable case (click: town_trip's timetable, stop "hamlet").
func _stops_h() -> void:
	var grey := _mat("", Color(0.42, 0.44, 0.42))
	var sign_mat := _mat(_first([TEX + "stop_sign.png"]), Color(0.9, 0.9, 0.86))
	for pole in [[POLE_TOWN, Vector3(0, 0, -1)], [POLE_CAMP, Vector3(0, 0, 1)]]:
		var at: Vector3 = pole[0]
		var f: Vector3 = pole[1]
		_box(self, at + Vector3(0, 1.4, 0), Vector3(0.08, 2.8, 0.08), grey)
		_box(self, at + Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.3), _mat(TEX_CAMP + "concrete.png", Color(0.8, 0.8, 0.78)))
		_box(self, at + Vector3(0, 2.5, 0), Vector3(0.6, 0.45, 0.03), grey)
		for s in [f, -f]:
			_face(self, at + Vector3(0, 2.5, 0) + s * 0.02, Vector2(0.6, 0.45), s, sign_mat)
			_letters(self, "podlesi_stop", at + Vector3(0, 2.05, 0) + s * 0.01, s)
		var case_mat := _mat(_first([TEX + "timetable_case.png"]), Color(0.6, 0.62, 0.6))
		_box(self, at + Vector3(0, 1.45, 0) + f * 0.06, Vector3(0.46, 0.62, 0.05), _mat("", Color(0.55, 0.56, 0.55)))
		_face(self, at + Vector3(0, 1.45, 0) + f * 0.09, Vector2(0.46, 0.62), f, case_mat)
		var body := _click_h(at + Vector3(0, 1.45, 0) + f * 0.12, Vector3(0.6, 0.8, 0.3), "ham_timetable")
		body.set_meta("stop", "hamlet")
	# The hamlet's own sign at the turn, facing the road.
	_box(self, Vector3(4.6, 0.9, 6.2), Vector3(0.06, 1.8, 0.06), grey)
	_letters(self, "podlesi", Vector3(4.6, 1.75, 6.2), Vector3(0, 0, -1))


## The dusty track to the hamlet: two ruts of dry dust and the grass ridge between them,
## a little bend, a few birches and the posts of a long gone fence along it.
func _track() -> void:
	var dust := _mat(TEX_CAMP + "gravel_road.png", Color(1.04, 0.94, 0.76), Vector2(1.0, 8.0))
	var ridge := _mat(_first([TEX + "meadow.png"]), Color(0.82, 0.88, 0.66), Vector2(1.0, 8.0))
	var pts := [Vector3(0, 0, 3.2), Vector3(4.0, 0, 34.0), Vector3(-2.5, 0, 70.0), Vector3(0.5, 0, 100.0), Vector3(0, 0, 116.0)]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var length := a.distance_to(b) + 1.0
		var yaw := atan2(b.x - a.x, b.z - a.z)
		var m := (dust as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.uv1_scale = Vector3(1.0, length / 3.2, 1.0)
		var t := _plane(self, (a + b) * 0.5 + Vector3(0, 0.025, 0), Vector2(3.2, length), m)
		t.rotation.y = yaw
		var r := _plane(self, (a + b) * 0.5 + Vector3(0, 0.03, 0), Vector2(0.55, length), ridge)
		r.rotation.y = yaw
	var wood := _mat(TEX_CAMP + "log_bark.png", Color(0.5, 0.44, 0.36), Vector2(1.0, 2.0))
	for k in 9:
		var z := 14.0 + k * 9.0
		_box(self, Vector3(-4.6 + (sin(z * 0.08) * 2.0), 0.55, z), Vector3(0.12, 1.1, 0.12), wood)
	if worldgen != null and worldgen.has_method("_tree_mesh"):
		for t in [Vector3(7.5, 0, 22.0), Vector3(-6.5, 0, 52.0), Vector3(6.0, 0, 84.0)]:
			for part in [["birch_trunk", worldgen._tree_material("birch_bark", 0)], ["birch_crown", worldgen._tree_material("leaf", 1)]]:
				var mi := MeshInstance3D.new()
				mi.mesh = worldgen._tree_mesh(str(part[0]))
				mi.material_override = part[1]
				mi.position = t
				mi.scale = Vector3.ONE * 1.3
				add_child(mi)


## The Hronek place by the road: the ruin's gable, no roof, rubble; the Babetta leaning
## on its wall, its tank still half full.
func _ruin_h() -> void:
	var stone := _mat(TEX_CAMP + "plaster_stone.png", Color(0.78, 0.76, 0.72))
	var house := _gable_house("lib_ruin", -70.0, -8.6, 1.0, 11.0, stone, {"ruin": true})
	if not house.is_empty():
		things["ruin"] = _click_h(Vector3(-70.0, 1.4, -8.4), Vector3(6.0, 2.8, 0.4), "ham_ruin")
	for k in 6:
		_box(self, Vector3(-70.0 + _rng.randf_range(-5.0, 5.0), 0.15, -7.5 + _rng.randf_range(-0.6, 1.4)), Vector3(_rng.randf_range(0.4, 1.0), 0.3, _rng.randf_range(0.3, 0.7)), stone)
	things["moped"] = _sprite_thing("ham_moped", 1.05, Vector3(-64.3, 0, -7.4), "ham_moped", Vector3(1.4, 1.2, 0.8))


## The houses round the hamlet's little square, their gables to it: old Vondra's rustic
## baroque farmhouse, the cottage with the boarded gable, the ochre house.
func _hamlet_houses() -> void:
	var white := _mat(_first([TEX + "village_plaster.png", TEX_CAMP + "plaster_stone.png"]), Color(1.0, 0.98, 0.94), Vector2(3.0, 1.0))
	var houses: Array = []
	for row in [["lib_baroque", -16.0, 132.0, -1.0, 13.0], ["lib_cottage", 2.0, 134.0, -1.0, 11.0], ["lib_gable_ochre", -24.0, 104.0, 1.0, 12.0]]:
		var house := _gable_house(str(row[0]), float(row[1]), float(row[2]), float(row[3]), float(row[4]), white, {"kind": houses.size(), "max_rise": 3.4})
		if house.is_empty():
			house = _gable_house("lib_gable_white", float(row[1]), float(row[2]), float(row[3]), float(row[4]), white, {"kind": houses.size()})
		if not house.is_empty():
			houses.append(house)
	spots["houses"] = houses


## Vondra's garage: three walls of flaking plaster and a flat roof, the doors open flat
## against the front (the picture's doorway is cut out: you see in), dim inside, and his
## Skoda 120 standing in it with its engine lid (at the back, by the door) up.
func _garage() -> void:
	var meta := _front_meta("lib_garage")
	var W := 6.0
	var H := 4.5
	if not meta.is_empty():
		W = meta["m"][0]
		H = meta["m"][1]
	var depth := 7.0
	var root := Node3D.new()
	root.position = Vector3(18.0, 0, 133.0 + depth * 0.5)
	add_child(root)
	var wall := _side_mat("lib_garage", _mat(TEX_CAMP + "concrete.png", Color(0.8, 0.8, 0.78)))
	var wh := H * 0.88
	_box(root, Vector3(0, wh * 0.5, depth * 0.5), Vector3(W, wh, 0.3), wall, true)
	for s in [-1.0, 1.0]:
		_box(root, Vector3(s * (W * 0.5 - 0.15), wh * 0.5, 0), Vector3(0.3, wh, depth), wall, true)
	_box(root, Vector3(0, wh + 0.08, 0), Vector3(W + 0.3, 0.16, depth + 0.3), _mat("", Color(0.22, 0.2, 0.19)))
	_plane(root, Vector3(0, 0.02, 0), Vector2(W - 0.6, depth - 0.3), _mat(TEX_CAMP + "concrete.png", Color(0.42, 0.4, 0.38)))
	if not meta.is_empty():
		_front_quad(root, "lib_garage", Vector3(0, H * 0.5, -depth * 0.5), -1.0, Vector2(W, H))
	# A bulb on a wire inside.
	var bulb := OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.82, 0.55)
	bulb.light_energy = 0.9
	bulb.omni_range = 6.0
	bulb.position = Vector3(0, wh - 0.4, 0.6)
	root.add_child(bulb)
	spots["garage_bulb"] = bulb
	car_root = _skoda(root, Vector3(0, 0, 0.5))
	things["car"] = _click_on(root, Vector3(0, 0.9, -1.4), Vector3(1.8, 1.4, 1.2), "ham_car")
	things["canister"] = _sprite_thing("ham_canister", 0.45, root.position + Vector3(-1.9, 0, -1.4), "ham_canister", Vector3(0.6, 0.6, 0.6))
	spots["garage"] = root


## The Skoda: a box body, its cabin, the picture of a Skoda on its sides and ends (the
## Lesna cars'), facing into the garage so the engine lid is at the door.
func _skoda(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = PI * 0.5
	parent.add_child(root)
	var paint := _mat("", Color(0.62, 0.66, 0.5))
	_box(root, Vector3(0, 0.75, 0), Vector3(4.2, 0.9, 1.6), paint, true)
	_box(root, Vector3(0.1, 1.45, 0), Vector3(2.2, 0.55, 1.5), _mat("", Color(0.26, 0.3, 0.32)))
	for f in [["car_side", Vector2(4.2, 1.45), Vector3(0, 0.88, 0.81), 0.0], ["car_side", Vector2(4.2, 1.45), Vector3(0, 0.88, -0.81), PI], ["car_front", Vector2(1.6, 1.2), Vector3(-2.11, 0.75, 0), -PI * 0.5], ["car_back", Vector2(1.6, 1.2), Vector3(2.11, 0.75, 0), PI * 0.5]]:
		var p := TEX + str(f[0]) + ".png"
		if not ResourceLoader.exists(p):
			continue
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(p)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = f[1]
		mi.mesh = q
		mi.position = f[2]
		mi.rotation.y = f[3]
		mi.material_override = m
		root.add_child(mi)
	# The engine lid (it is at the back on a 120, here towards the door) propped open.
	var lid := _box(root, Vector3(2.05, 1.6, 0), Vector3(0.08, 0.9, 1.3), paint)
	lid.rotation.z = 0.6
	return root


## The little square: a pond in a rim, the woodpile and the chopping block with the
## hammer in it, the washing line with a pair of stockings, the Trabant behind Vondra's
## house with its battery still in, a bench by the cottage; old Vondra himself.
func _yard() -> void:
	var stone := _mat(TEX_CAMP + "plaster_stone.png", Color(0.8, 0.78, 0.74), Vector2(2.0, 1.0))
	var pond := Vector3(14.0, 0, 108.0)
	_plane(self, pond + Vector3(0, 0.05, 0), Vector2(9.0, 5.5), _mat(TEX_CAMP + "lake_water.png", Color(0.5, 0.56, 0.52), Vector2(2.0, 1.0)))
	for side in [[Vector3(0, 0.15, -2.9), Vector3(9.4, 0.3, 0.3)], [Vector3(0, 0.15, 2.9), Vector3(9.4, 0.3, 0.3)], [Vector3(-4.7, 0.15, 0), Vector3(0.3, 0.3, 6.0)], [Vector3(4.7, 0.15, 0), Vector3(0.3, 0.3, 6.0)]]:
		_box(self, pond + side[0], side[1], stone, true)
	var planks := _mat(TEX_CAMP + "planks_grey.png", Color(0.7, 0.62, 0.5))
	# The woodpile and the block.
	_box(self, Vector3(-5.5, 0.6, 121.5), Vector3(3.2, 1.2, 0.9), _mat(TEX_CAMP + "log_bark.png", Color(0.62, 0.52, 0.42), Vector2(3.0, 1.0)), true)
	_box(self, Vector3(-3.4, 0.3, 119.6), Vector3(0.6, 0.6, 0.6), _mat(TEX_CAMP + "log_bark.png", Color(0.7, 0.6, 0.5)), true)
	things["hammer"] = _sprite_thing("ham_hammer", 0.32, Vector3(-3.4, 0.6, 119.6), "ham_hammer", Vector3(0.7, 0.5, 0.7))
	# The washing line with the stockings.
	var wood := _mat(TEX_CAMP + "log_bark.png", Color(0.6, 0.52, 0.44))
	for x in [6.0, 12.0]:
		_box(self, Vector3(x, 1.0, 118.0), Vector3(0.1, 2.0, 0.1), wood)
	_box(self, Vector3(9.0, 1.9, 118.0), Vector3(6.0, 0.02, 0.02), _mat("", Color(0.82, 0.82, 0.8)))
	things["stockings"] = _sprite_thing("ham_stockings", 0.8, Vector3(9.6, 1.15, 118.0), "ham_stockings", Vector3(1.0, 1.0, 0.5))
	# The Trabant behind Vondra's house.
	things["wreck"] = _sprite_thing("ham_car_wreck", 1.5, Vector3(-30.5, 0, 121.0), "ham_wreck", Vector3(3.0, 1.6, 2.0))
	# A bench by the cottage.
	_box(self, Vector3(2.0, 0.45, 127.4), Vector3(1.8, 0.08, 0.45), planks, true)
	_box(self, Vector3(2.0, 0.75, 127.6), Vector3(1.8, 0.4, 0.06), planks)
	# Vondra by the garage by day.
	var tex_path := "res://assets/textury/npc/town_vondra.png"
	if ResourceLoader.exists(tex_path):
		vondra = Sprite3D.new()
		vondra.texture = load(tex_path)
		vondra.pixel_size = 1.72 / float(vondra.texture.get_height())
		vondra.offset = Vector2(0, vondra.texture.get_height() * 0.5)
		vondra.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		vondra.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		vondra.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		vondra.shaded = true
		vondra.position = Vector3(13.6, 0, 127.0)
		add_child(vondra)
		things["vondra"] = _click_h(Vector3(13.6, 0.9, 127.0), Vector3(0.8, 1.8, 0.8), "ham_npc")


func _forest_h() -> void:
	if worldgen == null or not worldgen.has_method("_tree_mesh"):
		return
	var xf: Array[Transform3D] = []
	for k in 700:
		var p := Vector3(_rng.randf_range(-240.0, 240.0), 0, _rng.randf_range(-200.0, 300.0))
		# Not on the road, the track's meadow or the hamlet.
		if absf(p.z) < 26.0 or (absf(p.x) < 60.0 and p.z > 0.0 and p.z < 165.0):
			continue
		if p.z < 0.0 and absf(p.x) < 110.0 and p.z > -60.0 and _rng.randf() < 0.7:
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
	for k in 6:
		var t := Vector3(_rng.randf_range(-36.0, 36.0), 0, _rng.randf_range(140.0, 150.0))
		if worldgen.has_method("_tree_mesh"):
			for part in [["birch_trunk", worldgen._tree_material("bark", 0)], ["birch_crown", worldgen._tree_material("leaf", 1)]]:
				var mi := MeshInstance3D.new()
				mi.mesh = worldgen._tree_mesh(str(part[0]))
				mi.material_override = part[1]
				mi.position = t
				mi.scale = Vector3(1.2, 0.9, 1.2)
				add_child(mi)


## A lamp at the turn and one on the square (on at night, set_night).
func _lamps_h() -> void:
	var post := _mat(TEX_CAMP + "concrete.png", Color(0.78, 0.78, 0.76))
	var lights: Array = []
	for at in [Vector3(2.0, 0, -5.0), Vector3(3.0, 0, 112.0)]:
		_box(self, at + Vector3(0, 2.6, 0), Vector3(0.16, 5.2, 0.16), post, true)
		_box(self, at + Vector3(0, 5.15, 0.5), Vector3(0.1, 0.1, 1.1), post)
		var bulb := StandardMaterial3D.new()
		bulb.albedo_color = Color(0.6, 0.58, 0.5)
		bulb.emission_enabled = true
		_box(self, at + Vector3(0, 5.05, 1.0), Vector3(0.4, 0.14, 0.3), bulb)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.76, 0.46)
		l.light_energy = 1.6
		l.omni_range = 12.0
		l.position = at + Vector3(0, 4.8, 1.0)
		l.visible = false
		add_child(l)
		lights.append([l, bulb])
	spots["lamps"] = lights


# ── what you click ──────────────────────────────────────────────────────────

func _click_h(pos: Vector3, size: Vector3, kind: String) -> StaticBody3D:
	return _click_on(self, pos, size, kind)


func _click_on(parent: Node3D, pos: Vector3, size: Vector3, kind: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 11
	body.collision_mask = 0
	body.set_meta("building_type", kind)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	return body


## A Build sprite standing at `pos` (its feet), clickable as `kind`; returns the sprite
## (its click body is its "body" meta).
func _sprite_thing(tex_name: String, h: float, pos: Vector3, kind: String, click_size: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	var p := TEX + tex_name + ".png"
	if ResourceLoader.exists(p):
		s.texture = load(p)
		s.pixel_size = h / float(s.texture.get_height())
		s.offset = Vector2(0, s.texture.get_height() * 0.5)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.position = pos
	add_child(s)
	var body := _click_h(pos + Vector3(0, click_size.y * 0.5, 0), click_size, kind)
	s.set_meta("body", body)
	return s


## Takes a thing out of the world (picked up): its sprite and its click body.
func take(what: String) -> void:
	var s = things.get(what, null)
	if s is Sprite3D and is_instance_valid(s):
		var body = (s as Sprite3D).get_meta("body", null)
		if body != null and is_instance_valid(body):
			(body as Node).queue_free()
		(s as Node).queue_free()
	things.erase(what)


## The Skoda running: black smoke from under its back in pixel puffs, for a while.
func car_running(on: bool) -> void:
	if not on:
		for p in _smoke_car:
			(p as Node).queue_free()
		_smoke_car.clear()
		return
	if not _smoke_car.is_empty() or car_root == null:
		return
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x - 3.5, y - 3.5).length()
			if d < 2.6 or (d < 3.8 and (x + y) % 2 == 0):
				img.set_pixel(x, y, Color(0.12, 0.12, 0.12, 0.85))
	var tex := ImageTexture.create_from_image(img)
	for k in 6:
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = 0.07
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		add_child(s)
		_smoke_car.append(s)
		_smoke.append({"sprite": s, "base": car_root.global_position - HAMLET_ORIGIN + Vector3(0, 0.3, -2.6), "phase": float(k) / 6.0})


## Vondra is out by the garage by day, indoors at night.
func set_hour(h: float) -> void:
	super.set_hour(h)
	if vondra != null:
		var out := h >= 7.0 and h < 19.5
		vondra.visible = out
		var body = things.get("vondra", null)
		if body != null and is_instance_valid(body):
			(body as StaticBody3D).collision_layer = (1 << 11) if out else 0
