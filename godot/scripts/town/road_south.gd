extends Node3D

## The road out of the camp, past the barrier, on through the forest to the bus stop
## "Cerne jezero, kemp" about a minute's walk down, and on towards Lesna (only the bus goes
## that way). Built by world_generator.gd right after the gate (scripts/camp_gate.gd lays
## the first 120 m of gravel).
##
## All generated: gravel strips with collision, spruce walls either side (multimeshes of
## the camp's own tree meshes), invisible walls along the verges so the forest stays a
## wall, and the stop: a concrete shelter with a bench, the sign and the timetable case
## on a pole (building_type "trip_timetable": scripts/town/town_trip.gd opens the sheet),
## a lamp that comes on at night (and does not always stay on), a gravel loop where the
## bus turns. Past the stop the way on is only the bus's.
##
## Road points are relative to the gate: x from the gate's centre, z from the south fence
## line (south is -z).

const TEX_DIR := "res://assets/textury/camp/"
const TOWN_TEX := "res://assets/textury/town/"
const ROAD_WIDTH := 4.4
## The verge walls stand this far from the middle of the road.
const WALL_OFF := 5.0
## Gate, bend, end of camp_gate's road, then this one: the stop is ROAD[STOP].
const ROAD := [Vector2(0, 1), Vector2(2, -45), Vector2(14, -120), Vector2(17, -165), Vector2(12, -205), Vector2(9, -248), Vector2(6, -290), Vector2(-2, -345)]
const STOP := 5
const OWN_FROM := 2
## The walkable pad round the stop, along the road (south +) and across it (east +).
const PAD_NORTH := 24.0
const PAD_SOUTH := 14.0
const PAD_EAST := 9.0
const PAD_WEST := 22.0
## Trees per 10 m of road on each side.
const TREE_DENSITY := 24

var stop_name := "CERNE JEZERO, KEMP"
var _gx := 0.0
var _fz := 0.0
var _worldgen: Node
var _texture_style
var _rng := RandomNumberGenerator.new()
var _lamp: OmniLight3D
var _lamp_bulb: StandardMaterial3D
var _lamp_t := 0.0
var _lamp_flicker := 0.0
var _night := false


func build(gate_x: float, fence_z: float, worldgen: Node, texture_style) -> void:
	name = "RoadSouth"
	_gx = gate_x
	_fz = fence_z
	_worldgen = worldgen
	_texture_style = texture_style
	_rng.seed = 380
	var gravel := _gravel_material()
	for i in range(OWN_FROM, ROAD.size() - 1):
		_road_segment(point(i), point(i + 1), gravel)
	_build_walls()
	_build_ground()
	_build_trees()
	_build_stop()
	_build_loop(gravel)
	_build_forest_things()


# ── where things are ─────────────────────────────────────────────────────────

func point(i: int) -> Vector3:
	var p: Vector2 = ROAD[i]
	return Vector3(_gx + p.x, 0.0, _fz + p.y)


## Down the road at the stop (towards Lesna), and across it (east, the shelter's side).
func stop_south() -> Vector3:
	return (point(STOP + 1) - point(STOP - 1)).normalized()


func stop_east() -> Vector3:
	var s := stop_south()
	return Vector3(-s.z, 0.0, s.x)


## A point near the stop: `along` metres down the road (south), `across` east of its middle.
func at_stop(along: float, across: float) -> Vector3:
	return point(STOP) + stop_south() * along + stop_east() * across


## Where the bus stands at the stop, facing back up the road (north, the way it came
## in); its doors are on its right, at the shelter.
func bus_stop_pose() -> Transform3D:
	var pos := at_stop(0.5, 1.3)
	return Transform3D(Basis.looking_at(-stop_south(), Vector3.UP), pos)


## In from Lesna: up the east lane from out of sight to the stop.
func bus_arrive_path() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(point(ROAD.size() - 1) + stop_east() * 1.1 + stop_south() * 40.0)
	out.append(point(ROAD.size() - 1) + stop_east() * 1.1)
	out.append(point(STOP + 1) + stop_east() * 1.1)
	out.append(at_stop(14.0, 1.2))
	out.append(bus_stop_pose().origin)
	return out


## Out to Lesna: on up past the shelter, round the loop to the west and back down the
## west lane, out of sight.
func bus_leave_path() -> PackedVector3Array:
	var out := PackedVector3Array()
	var start := bus_stop_pose().origin
	out.append(start)
	var north := -stop_south()
	var west := -stop_east()
	var turn_from := start + north * 7.0
	out.append(turn_from)
	var centre := turn_from + west * 7.0
	for k in range(1, 13):
		var a := PI * float(k) / 12.0
		out.append(centre - west * 7.0 * cos(a) + north * 7.0 * sin(a))
	out.append(at_stop(4.0, -3.0))
	out.append(at_stop(16.0, -1.2))
	out.append(point(STOP + 1) - stop_east() * 1.1)
	out.append(point(ROAD.size() - 1) - stop_east() * 1.1)
	out.append(point(ROAD.size() - 1) - stop_east() * 1.1 + stop_south() * 40.0)
	return out


## The works bus after midnight: up past the stop without stopping, on up the road
## towards the camp, gone round the bend.
func works_bus_path() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(point(ROAD.size() - 1) + stop_east() * 1.1 + stop_south() * 40.0)
	for i in range(ROAD.size() - 1, OWN_FROM, -1):
		out.append(point(i) + _east_of(i) * 1.1)
	return out


## Where you wait: in the shelter's mouth, looking down the road.
func wait_spot() -> Transform3D:
	var pos := at_stop(-1.0, 3.6) + Vector3(0, 0.1, 0)
	return Transform3D(Basis.looking_at(stop_south() - stop_east() * 0.3, Vector3.UP), pos)


func _east_of(i: int) -> Vector3:
	var a := point(maxi(0, i - 1))
	var b := point(mini(ROAD.size() - 1, i + 1))
	var d := (b - a).normalized()
	return Vector3(-d.z, 0.0, d.x)


# ── the road ─────────────────────────────────────────────────────────────────

func _gravel_material() -> StandardMaterial3D:
	var m := _material(TEX_DIR + "gravel_road.png", "road", Color(0.62, 0.58, 0.5))
	var path := "res://assets/textury/redneck/paths/gravel.png"
	if ResourceLoader.exists(path):
		var img := (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.rotate_90(CLOCKWISE)
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.albedo_color = Color(1, 1, 1)
	return m


func _road_segment(from: Vector3, to: Vector3, mat: StandardMaterial3D) -> void:
	var length := from.distance_to(to)
	var yaw := atan2(to.x - from.x, to.z - from.z)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WALL_OFF * 2.0 + 1.0, 1.0, length + 2.0)
	shape.shape = box
	body.position = (from + to) * 0.5 + Vector3(0, -0.5, 0)
	body.rotation.y = yaw
	body.add_child(shape)
	add_child(body)
	var seg := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ROAD_WIDTH, length + 1.0)
	seg.mesh = plane
	seg.position = (from + to) * 0.5 + Vector3(0, 0.03, 0)
	seg.rotation.y = yaw
	var m := mat.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(1.0, (length + 1.0) / ROAD_WIDTH, 1.0)
	seg.material_override = m
	seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seg)


## The verges: a wall either side of every stretch from the gate down to the stop's pad,
## and round the pad (open only where the road comes in from the camp).
func _build_walls() -> void:
	for i in range(0, STOP - 1):
		var a := point(i)
		var b := point(i + 1)
		if i == 0:
			a.z = _fz - 0.4
		for side in [-1.0, 1.0]:
			_wall_along(a, b, side * WALL_OFF, 1.5)
	# The last stretch into the pad stops at its north edge.
	var e := point(STOP - 1)
	var pad_n := at_stop(-PAD_NORTH, 0.0)
	for side in [-1.0, 1.0]:
		_wall_along(e, pad_n, side * WALL_OFF, 1.0)
	# The pad: north (either side of the road), east, south, west.
	_wall_line(at_stop(-PAD_NORTH, WALL_OFF), at_stop(-PAD_NORTH, PAD_EAST))
	_wall_line(at_stop(-PAD_NORTH, -WALL_OFF), at_stop(-PAD_NORTH, -PAD_WEST))
	_wall_line(at_stop(-PAD_NORTH, PAD_EAST), at_stop(PAD_SOUTH, PAD_EAST))
	_wall_line(at_stop(PAD_SOUTH, PAD_EAST), at_stop(PAD_SOUTH, -PAD_WEST))
	_wall_line(at_stop(PAD_SOUTH, -PAD_WEST), at_stop(-PAD_NORTH, -PAD_WEST))
	# The pad's floor.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PAD_EAST + PAD_WEST + 2.0, 1.0, PAD_NORTH + PAD_SOUTH + 2.0)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_transform = Transform3D(Basis(stop_east(), Vector3.UP, -stop_south()), at_stop((PAD_SOUTH - PAD_NORTH) * 0.5, (PAD_EAST - PAD_WEST) * 0.5) + Vector3(0, -0.5, 0))


func _wall_along(a: Vector3, b: Vector3, off: float, overlap: float) -> void:
	var d := (b - a).normalized()
	var east := Vector3(-d.z, 0.0, d.x)
	_wall_line(a - d * overlap + east * off, b + d * overlap + east * off)


func _wall_line(a: Vector3, b: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Verge"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 4.0, a.distance_to(b) + 0.4)
	shape.shape = box
	body.add_child(shape)
	body.position = (a + b) * 0.5 + Vector3(0, 2.0, 0)
	body.rotation.y = atan2(b.x - a.x, b.z - a.z)
	add_child(body)


## Forest floor under it all, past where the camp's own apron reaches.
func _build_ground() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in ROAD.size():
		var p := point(i)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(hi.x - lo.x + 260.0, hi.y - lo.y + 200.0)
	ground.mesh = plane
	ground.position = Vector3((lo.x + hi.x) * 0.5, -0.12, (lo.y + hi.y) * 0.5 - 60.0)
	var m := _material(TOWN_TEX + "forest_floor.png", "grass", Color(0.36, 0.34, 0.26))
	m.uv1_scale = Vector3(plane.size.x / 4.0, plane.size.y / 4.0, 1.0)
	ground.material_override = m
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


## Spruce walls either side of the road (the camp's own meshes, one multimesh per part),
## thick enough to be a wall, thinning out further back. None on the road, the pad or
## inside the camp.
func _build_trees() -> void:
	if _worldgen == null or not _worldgen.has_method("_tree_mesh"):
		return
	var xforms: Array[Transform3D] = []
	var birches: Array[Transform3D] = []
	for i in range(0, ROAD.size() - 1):
		var a := point(i)
		var b := point(i + 1)
		var length := a.distance_to(b)
		var d := (b - a) / length
		var east := Vector3(-d.z, 0.0, d.x)
		var n := int(length / 10.0 * TREE_DENSITY)
		for k in n:
			var along := _rng.randf() * length
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var off := WALL_OFF + 1.2 + pow(_rng.randf(), 2.2) * 38.0
			var p := a + d * along + east * side * off
			if p.z > _fz - 3.0:
				continue
			if _on_road(p, WALL_OFF + 1.0) or _on_pad(p, 2.0):
				continue
			var sc := _rng.randf_range(0.9, 1.6) * (1.0 + (off - WALL_OFF) / 60.0)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.9, 1.3), sc))
			if _rng.randf() < 0.14:
				birches.append(Transform3D(basis.scaled(Vector3(0.8, 0.8, 0.8)), Vector3(p.x, 0.0, p.z)))
			else:
				xforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.z)))
	# Round the stop: the forest closes in behind the pad.
	for k in 520:
		var along := _rng.randf_range(-PAD_NORTH - 10.0, PAD_SOUTH + 40.0)
		var across := _rng.randf_range(-PAD_WEST - 36.0, PAD_EAST + 36.0)
		var p := at_stop(along, across)
		if _on_pad(p, 1.5) or _on_road(p, WALL_OFF + 1.0):
			continue
		var sc := _rng.randf_range(1.0, 1.7)
		xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.9, 1.3), sc)), Vector3(p.x, 0.0, p.z)))
	var parts := [["spruce_trunk", _worldgen._tree_material("bark", 1), xforms], ["spruce_crown", _worldgen._tree_material("needles", 1), xforms],
		["birch_trunk", _worldgen._tree_material("birch_bark", 0), birches], ["birch_crown", _worldgen._tree_material("leaf", 1), birches]]
	for part in parts:
		var list: Array[Transform3D] = part[2]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _worldgen._tree_mesh(str(part[0]))
		mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, list[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = part[1]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## Within `margin` of the middle of any stretch of road.
func _on_road(p: Vector3, margin: float) -> bool:
	var q := Vector2(p.x, p.z)
	for i in ROAD.size() - 1:
		var a := Vector2(point(i).x, point(i).z)
		var b := Vector2(point(i + 1).x, point(i + 1).z)
		if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < margin:
			return true
	return false


func _on_pad(p: Vector3, margin: float) -> bool:
	var rel := p - point(STOP)
	var along := rel.dot(stop_south())
	var across := rel.dot(stop_east())
	return along > -PAD_NORTH - margin and along < PAD_SOUTH + margin and across > -PAD_WEST - margin and across < PAD_EAST + margin


# ── the stop ─────────────────────────────────────────────────────────────────

func _build_stop() -> void:
	var root := Node3D.new()
	root.name = "BusStop"
	add_child(root)
	# The stop's frame: x across the road (east), z up it (north, towards the camp).
	root.global_transform = Transform3D(Basis(stop_east(), Vector3.UP, -stop_south()), point(STOP))
	var concrete := _material(TOWN_TEX + "stop_concrete.png", "concrete", Color(0.62, 0.6, 0.56))
	var dark := _paint(Color(0.2, 0.2, 0.2))
	# The shelter: back wall to the east, side walls, a slab roof; open to the road.
	var sx := 5.6
	_box(root, Vector3(sx + 0.9, 1.2, 0.0), Vector3(0.18, 2.4, 4.2), concrete)
	_box(root, Vector3(sx, 1.2, -2.0), Vector3(1.9, 2.4, 0.16), concrete)
	_box(root, Vector3(sx, 1.2, 2.0), Vector3(1.9, 2.4, 0.16), concrete)
	_box(root, Vector3(sx - 0.1, 2.5, 0.0), Vector3(2.5, 0.18, 4.7), concrete)
	_box(root, Vector3(sx, 0.04, 0.0), Vector3(2.0, 0.08, 4.1), _paint(Color(0.42, 0.41, 0.39)))
	# The bench: planks on two concrete feet.
	var planks := _material(TEX_DIR + "planks_grey.png", "wood", Color(0.5, 0.45, 0.38))
	_box(root, Vector3(sx + 0.5, 0.45, 0.0), Vector3(0.45, 0.06, 3.4), planks)
	_box(root, Vector3(sx + 0.78, 0.75, 0.0), Vector3(0.06, 0.3, 3.4), planks)
	for z in [-1.4, 1.4]:
		_box(root, Vector3(sx + 0.5, 0.22, z), Vector3(0.4, 0.44, 0.16), concrete)
	_solid(root, Vector3(sx + 0.9, 1.2, 0.0), Vector3(0.18, 2.4, 4.2))
	_solid(root, Vector3(sx, 1.2, -2.0), Vector3(1.9, 2.4, 0.16))
	_solid(root, Vector3(sx, 1.2, 2.0), Vector3(1.9, 2.4, 0.16))
	# A litter bin by the shelter.
	_flat_sprite(root, TOWN_TEX + "street_bin.png", 0.95, Vector3(sx - 0.7, 0.0, -2.6), true)
	# The platform: a strip of concrete slabs along the road with its kerb, worn earth
	# where people stand and wait, butts trodden into it (playtest 17. 10.: "paths at
	# the stops").
	var slabs := _material(TOWN_TEX + "sidewalk.png", "concrete", Color(0.86, 0.86, 0.84))
	var pm := slabs.duplicate() as StandardMaterial3D
	pm.uv1_scale = Vector3(1.4, 4.0, 1.0)
	pm.uv1_triplanar = false
	var plat := _box(root, Vector3(3.55, 0.04, 0.0), Vector3(2.3, 0.08, 7.0), pm)
	plat.name = "Platform"
	_box(root, Vector3(2.38, 0.07, 0.0), Vector3(0.16, 0.14, 7.0), concrete)
	for k in 3:
		_flat_decal(root, TOWN_TEX + "dirt_path.png", Vector2(1.6, 1.3), Vector3(sx - 1.2 + k * 0.3, 0.09, -1.2 + k * 1.2))
	_flat_decal(root, "res://assets/textury/mess/litter_ash.png", Vector2(0.5, 0.5), Vector3(sx - 0.2, 0.1, 0.6))
	_flat_decal(root, "res://assets/textury/mess/litter_ash.png", Vector2(0.4, 0.4), Vector3(3.6, 0.09, 2.4))
	# The trodden path through the verge from the platform back up towards the camp.
	var path := _material(TOWN_TEX + "dirt_path.png", "earth", Color(0.9, 0.86, 0.8))
	var lane := path.duplicate() as StandardMaterial3D
	lane.uv1_triplanar = false
	lane.uv1_scale = Vector3(1.0, 6.0, 1.0)
	_box(root, Vector3(3.3, 0.02, 7.5), Vector3(1.0, 0.04, 8.0), lane)
	# The pole by the road: the sign at the top, the timetable on it.
	var pole_at := Vector3(3.4, 0.0, 3.0)
	_box(root, pole_at + Vector3(0, 1.4, 0), Vector3(0.08, 2.8, 0.08), _paint(Color(0.42, 0.44, 0.42)))
	_box(root, pole_at + Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.3), concrete)
	var sign_mat := _material(TOWN_TEX + "stop_sign.png", "metal", Color(0.9, 0.9, 0.86))
	_box(root, pole_at + Vector3(0, 2.5, 0), Vector3(0.03, 0.56, 0.74), _paint(Color(0.3, 0.3, 0.3)))
	var name_board := _box(root, pole_at + Vector3(0, 2.07, 0), Vector3(0.04, 0.24, 1.1), _paint(Color(0.92, 0.9, 0.84)))
	name_board.name = "StopName"
	for side in [-1.0, 1.0]:
		_face(root, pole_at + Vector3(side * 0.02, 2.5, 0), Vector2(0.74, 0.56), side, sign_mat)
		var label := Label3D.new()
		label.text = stop_name
		label.font = load("res://assets/fonts/jersey10.fnt")
		label.font_size = 32
		label.pixel_size = 0.0027
		label.modulate = Color(0.08, 0.08, 0.1)
		label.outline_size = 0
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.position = pole_at + Vector3(side * 0.025, 2.07, 0)
		label.rotation.y = PI * 0.5 * side
		root.add_child(label)
	# The timetable case, facing the road: click it to read.
	var case_mat := _material(TOWN_TEX + "timetable_case.png", "metal", Color(0.7, 0.72, 0.7))
	_box(root, pole_at + Vector3(-0.06, 1.45, 0), Vector3(0.05, 0.62, 0.46), _paint(Color(0.55, 0.56, 0.55)))
	var case_mesh := _face(root, pole_at + Vector3(-0.09, 1.45, 0), Vector2(0.46, 0.62), -1.0, case_mat)
	case_mesh.name = "TimetableCase"
	var body := StaticBody3D.new()
	body.name = "Timetable"
	body.set_meta("building_type", "trip_timetable")
	body.set_meta("stop", "camp")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.8, 0.6)
	shape.shape = box
	body.add_child(shape)
	body.position = pole_at + Vector3(-0.1, 1.45, 0)
	root.add_child(body)
	# The lamp: a concrete post with an old bowl lamp over the shelter's mouth.
	var lamp_at := Vector3(3.6, 0.0, -2.8)
	_box(root, lamp_at + Vector3(0, 2.3, 0), Vector3(0.16, 4.6, 0.16), concrete)
	_box(root, lamp_at + Vector3(0.45, 4.55, 0), Vector3(0.9, 0.08, 0.08), dark)
	_lamp_bulb = StandardMaterial3D.new()
	_lamp_bulb.albedo_color = Color(0.5, 0.48, 0.42)
	_lamp_bulb.emission_enabled = true
	_lamp_bulb.emission = Color(0, 0, 0)
	_box(root, lamp_at + Vector3(0.85, 4.45, 0), Vector3(0.36, 0.14, 0.36), _lamp_bulb)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.78, 0.5)
	_lamp.light_energy = 1.6
	_lamp.omni_range = 11.0
	_lamp.position = lamp_at + Vector3(0.85, 4.2, 0)
	_lamp.visible = false
	root.add_child(_lamp)


## A Grok sprite `h` tall on the ground at `pos` (its feet), turned to face you.
func _flat_sprite(root: Node3D, path: String, h: float, pos: Vector3, billboard: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var t: Texture2D = load(path)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(h * float(t.get_width()) / float(t.get_height()), h)
	q.center_offset = Vector3(0, h * 0.5, 0)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
	mi.material_override = m
	mi.position = pos
	root.add_child(mi)


## A Grok picture lying flat on the ground (keyed edges): worn earth, butts.
func _flat_decal(root: Node3D, path: String, size: Vector2, pos: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = randf() * TAU
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## What a Czech forest road has along it (playtest 17. 10.: "details, bring the world to
## life"): the deer warning sign past the barrier, a kilometre stone, a stack of felled
## spruce waiting for the lorry, the hunters' high seat back in the trees, a deer feeder
## in a clearing, the red-and-white trail marks on two dead snags by the verge. Grok
## sprites (assets/textury/world).
func _build_forest_things() -> void:
	var W := "res://assets/textury/world/"
	_flat_sprite(self, W + "deer_sign.png", 1.9, _along(OWN_FROM, 0.12, 3.0), true)
	_flat_sprite(self, W + "km_stone.png", 0.55, _along(3, 0.5, -2.8), true)
	_flat_sprite(self, W + "timber_stack.png", 1.5, _along(3, 0.85, 7.0), true)
	_flat_sprite(self, W + "hunters_seat.png", 6.5, _along(4, 0.4, -13.0), true)
	_flat_sprite(self, W + "deer_feeder.png", 2.4, _along(5, 0.35, 11.0), true)
	var bark := _material(TEX_DIR + "log_bark.png", "wood", Color(0.62, 0.58, 0.52))
	for snag in [[2, 0.6, 3.6], [4, 0.75, -3.7]]:
		var at := _along(int(snag[0]), float(snag[1]), float(snag[2]))
		var trunk := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.2
		cm.height = 7.0
		cm.radial_segments = 7
		trunk.mesh = cm
		trunk.material_override = bark
		trunk.position = at + Vector3(0, 3.5, 0)
		add_child(trunk)
		_solid(self, at + Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4))
		# The mark on the side facing the road.
		var to_road := (_along(int(snag[0]), float(snag[1]), 0.0) - at).normalized()
		var mark := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 0.2)
		mark.mesh = q
		var mm := StandardMaterial3D.new()
		if ResourceLoader.exists(W + "trail_mark.png"):
			mm.albedo_texture = load(W + "trail_mark.png")
		mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mark.material_override = mm
		mark.position = at + Vector3(0, 1.6, 0) + to_road * 0.19
		mark.rotation.y = atan2(to_road.x, to_road.z)
		add_child(mark)


## A point `t` of the way along road segment i, `across` metres east of its middle.
func _along(i: int, t: float, across: float) -> Vector3:
	var a := point(i)
	var b := point(i + 1)
	var d := (b - a).normalized()
	return a.lerp(b, t) + Vector3(-d.z, 0.0, d.x) * across


## The gravel loop the bus turns in (bus_leave_path's turn), west of the stop.
func _build_loop(gravel: StandardMaterial3D) -> void:
	var start := bus_stop_pose().origin
	var centre := start - stop_south() * 7.0 - stop_east() * 7.0
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 10.0
	cyl.bottom_radius = 10.0
	cyl.height = 0.02
	cyl.radial_segments = 20
	disc.mesh = cyl
	var m := gravel.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(3.0, 3.0, 1.0)
	m.albedo_color = Color(0.92, 0.9, 0.86)
	disc.material_override = m
	disc.position = centre + Vector3(0, 0.02, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)


# ── the lamp ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_lamp_t -= delta
	if _lamp_t <= 0.0:
		_lamp_t = 1.0
		var main := get_tree().current_scene
		var h := float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 12.0
		_night = h >= 19.8 or h < 6.2
		# Now and then the old lamp gives up for a moment.
		if _night and _rng.randf() < 0.06:
			_lamp_flicker = _rng.randf_range(0.4, 2.2)
	_lamp_flicker = maxf(0.0, _lamp_flicker - delta)
	var on := _night and (_lamp_flicker <= 0.0 or int(Time.get_ticks_msec() / 83) % 3 == 0)
	if _lamp != null:
		_lamp.visible = on
		_lamp_bulb.emission = Color(1.0, 0.78, 0.45) * 1.4 if on else Color(0, 0, 0)


# ── helpers ──────────────────────────────────────────────────────────────────

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


## A textured quad facing east (side 1) or west (side -1) in the parent's frame.
func _face(parent: Node3D, pos: Vector3, size: Vector2, side: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	m.position = pos
	m.rotation.y = PI * 0.5 * side
	m.material_override = mat
	parent.add_child(m)
	return m


func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)


func _paint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


func _material(path: String, fallback_category: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif ResourceLoader.exists(TEX_DIR + "concrete.png") and fallback_category == "concrete":
		tex = load(TEX_DIR + "concrete.png") as Texture2D
	elif _texture_style != null:
		tex = _texture_style.pick_texture(fallback_category, tint)
	if tex != null:
		m.albedo_texture = tex
		m.albedo_color = Color(1, 1, 1)
	else:
		m.albedo_color = tint
	return m
