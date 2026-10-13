extends Node3D

## The forest lake behind the camp (DESIGN §14). The last row of the grid is the camp's
## shore (TILE_LAKE: guests stand at it, the slide goes into it); from there the water
## opens out beyond the north fence into a real lake: an irregular sheet of panning water,
## a muddy shore, reeds, a jetty with a rowing boat tied to it, the forest around, and
## mist on the water in the early morning.
##
## You can walk out on the jetty; the water itself is fenced off by invisible walls along
## the shore (you do not swim at night).

const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
const WATER_SHADER = preload("res://materials/lake_water.gdshader")
const REEDS := "res://assets/textury/world/reeds.png"
const SHORE_TEX := "res://assets/textury/camp/lake_shore.png"
const WATER_TEX := "res://assets/textury/camp/lake_water.png"

const WATER_Y := 0.06
const JETTY_LEN := 9.0
const JETTY_W := 1.6
const JETTY_Y := 0.42

var _main: Node
var _mist: Array[MeshInstance3D] = []
var _mist_t := 0.0


## `shore_z`: world z of the camp-side edge of the lake row; `north_z`: the map's north
## edge; `west`/`east`: the map's x edges. `rng` keeps it the same for a seed.
static func water_polygon(shore_z: float, north_z: float, west: float, east: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(west + 0.2, shore_z))
	pts.append(Vector2(east - 0.2, shore_z))
	# Up the east side, round the far shore, back down the west side (kept clear of the
	# corn field, which reaches 8 m past the north fence west of the camp).
	var cx := (west + east) * 0.5
	var rx := (east - west) * 0.5 + 16.0
	var rz := 46.0
	var n := 22
	for i in n + 1:
		var a := PI * float(i) / float(n)
		var wob := rng.randf_range(-4.5, 4.5)
		var x := cx + cos(a) * (rx + wob)
		var z := north_z + 6.0 + sin(a) * (rz + wob)
		if a > PI * 0.82:
			x = maxf(x, west - 1.0 - (z - north_z) * 0.4)
		pts.append(Vector2(x, z))
	pts.append(Vector2(west - 0.5, north_z + 9.0))
	pts.append(Vector2(west + 0.2, north_z))
	return pts


func build(main_node: Node, shore_z: float, north_z: float, west: float, east: float, texture_seed: int) -> void:
	_main = main_node
	name = "CampLake"
	var rng := RandomNumberGenerator.new()
	rng.seed = texture_seed
	var poly := water_polygon(shore_z, north_z, west, east, rng)
	var far_z := north_z + 52.0

	# The shore: the water outline grown by 3 m, mud and sand, just under the water.
	var shore_poly: PackedVector2Array = Geometry2D.offset_polygon(poly, 3.2)[0]
	var shore := _flat_mesh(shore_poly, 0.02, "LakeShore")
	var shore_mat := StandardMaterial3D.new()
	shore_mat.albedo_texture = load(SHORE_TEX)
	shore_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shore_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	shore_mat.uv1_triplanar = true
	shore_mat.uv1_world_triplanar = true
	shore_mat.uv1_scale = Vector3.ONE / 2.5
	shore.material_override = shore_mat
	shore.position.z = 0.0

	# The water.
	var water := _flat_mesh(poly, WATER_Y, "LakeWater")
	var wmat := ShaderMaterial.new()
	wmat.shader = WATER_SHADER
	wmat.set_shader_parameter("water_tex", load(WATER_TEX))
	wmat.set_shader_parameter("shore_z", Vector2(shore_z, far_z))
	water.material_override = wmat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Reeds along the shore (not in front of the jetty), thick at the corners.
	var jetty_x := (west + east) * 0.5 + 9.0
	var reeds_tex: Texture2D = load(REEDS) if ResourceLoader.exists(REEDS) else null
	if reeds_tex != null:
		var outline := Geometry2D.offset_polygon(poly, -0.6)[0] as PackedVector2Array
		for i in outline.size():
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[(i + 1) % outline.size()]
			var steps := int(a.distance_to(b) / 2.2)
			for k in steps:
				var p := a.lerp(b, (float(k) + rng.randf()) / float(maxi(1, steps)))
				if absf(p.x - jetty_x) < 3.0 and p.y < shore_z + 2.0:
					continue
				if rng.randf() < 0.45:
					continue
				_reed_clump(Vector3(p.x, WATER_Y, p.y), rng, reeds_tex)

	# The jetty: planks on posts, from the camp shore out over the water, and the boat.
	_build_jetty(Vector3(jetty_x, 0.0, shore_z - 1.0))
	var boat := INTERIOR_KIT.prop(self, "rowboat", Vector3(jetty_x + 1.6, WATER_Y - 0.12, shore_z + JETTY_LEN * 0.55), 12.0)
	if boat != null:
		boat.name = "RowBoat"

	# You cannot walk into the water: a wall along the camp shore with a gap for the jetty.
	var gap_l := jetty_x - JETTY_W * 0.5
	var gap_r := jetty_x + JETTY_W * 0.5
	_wall(Vector3((west + gap_l) * 0.5, 1.0, shore_z + 0.3), Vector3(gap_l - west, 2.0, 0.3))
	_wall(Vector3((gap_r + east) * 0.5, 1.0, shore_z + 0.3), Vector3(east - gap_r, 2.0, 0.3))

	# Morning mist: a few soft sheets low over the water, drifting.
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.seed = texture_seed
	fn.frequency = 0.012
	noise.noise = fn
	for i in 3:
		var mist := MeshInstance3D.new()
		mist.name = "LakeMist%d" % i
		var plane := PlaneMesh.new()
		plane.size = Vector2(east - west + 30.0, 52.0)
		mist.mesh = plane
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_texture = noise
		mm.albedo_color = Color(0.86, 0.88, 0.86, 0.0)
		mm.uv1_scale = Vector3(3.0 + i, 2.0 + i, 1.0)
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mm.disable_receive_shadows = true
		mist.material_override = mm
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist.position = Vector3((west + east) * 0.5, 0.35 + 0.45 * i, north_z + 20.0)
		add_child(mist)
		_mist.append(mist)


func _process(delta: float) -> void:
	if _mist.is_empty() or _main == null:
		return
	_mist_t += delta
	var h := float(_main.get("_time_of_day_hours")) if _main.get("_time_of_day_hours") != null else 12.0
	# Thick at dawn (04:30-08:30), a breath of it at night, gone by day.
	var dawn := clampf(1.0 - absf(h - 6.3) / 2.2, 0.0, 1.0)
	var night := 0.25 if (h >= 21.5 or h < 4.5) else 0.0
	var amount := maxf(dawn, night)
	for i in _mist.size():
		var mm := _mist[i].material_override as StandardMaterial3D
		mm.albedo_color.a = amount * (0.42 - 0.1 * i)
		mm.uv1_offset = Vector3(_mist_t * (0.004 + 0.002 * i), _mist_t * 0.0015 * (i - 1), 0.0)
		_mist[i].visible = amount > 0.01


func _build_jetty(start: Vector3) -> void:
	var K := INTERIOR_KIT
	var planks := K.surface("planks_grey", 1.2)
	var posts := K.surface("planks_dark", 0.6)
	var body := StaticBody3D.new()
	body.name = "Jetty"
	add_child(body)
	var deck_center := start + Vector3(0, JETTY_Y, JETTY_LEN * 0.5)
	K.slab(body, Vector3(JETTY_W, 0.08, JETTY_LEN), deck_center, planks, "Deck")
	var n := int(JETTY_LEN / 1.6)
	for i in n + 1:
		var z := start.z + float(i) * JETTY_LEN / float(n)
		for side: float in [-1.0, 1.0]:
			K.slab(body, Vector3(0.14, 1.1, 0.14), Vector3(start.x + side * (JETTY_W * 0.5 - 0.07), JETTY_Y - 0.45, z), posts, "Post")
	# A low rail on one side and a mooring post with a rope at the end.
	K.slab(body, Vector3(0.08, 0.08, JETTY_LEN), start + Vector3(-JETTY_W * 0.5 + 0.04, JETTY_Y + 0.55, JETTY_LEN * 0.5), posts, "Rail")
	for i in 4:
		K.slab(body, Vector3(0.08, 0.55, 0.08), start + Vector3(-JETTY_W * 0.5 + 0.04, JETTY_Y + 0.28, JETTY_LEN * float(i) / 3.0), posts, "RailPost")
	# Steps down from the shore, and the walking surfaces.
	K.slab(body, Vector3(JETTY_W, 0.2, 0.6), start + Vector3(0, 0.12, -0.3), planks, "Step")
	_collider(body, deck_center + Vector3(0, -0.04, 0), Vector3(JETTY_W, 0.1, JETTY_LEN))
	_collider(body, start + Vector3(0, 0.12, -0.3), Vector3(JETTY_W, 0.24, 0.6))
	# Invisible sides and end, so you stay on the planks.
	for side: float in [-1.0, 1.0]:
		_collider(body, deck_center + Vector3(side * (JETTY_W * 0.5 + 0.1), 1.0, 0), Vector3(0.2, 2.0, JETTY_LEN))
	_collider(body, start + Vector3(0, JETTY_Y + 1.0, JETTY_LEN + 0.1), Vector3(JETTY_W + 0.4, 2.0, 0.2))


func _reed_clump(at: Vector3, rng: RandomNumberGenerator, tex: Texture2D) -> void:
	for i in rng.randi_range(1, 3):
		var s := Sprite3D.new()
		s.texture = tex
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		var height := rng.randf_range(1.2, 2.0)
		s.pixel_size = height / float(tex.get_height())
		s.offset = Vector2(0, tex.get_height() * 0.5)
		s.flip_h = rng.randf() < 0.5
		s.position = at + Vector3(rng.randf_range(-0.6, 0.6), -0.1, rng.randf_range(-0.6, 0.6))
		add_child(s)


func _flat_mesh(poly: PackedVector2Array, y: float, node_name: String) -> MeshInstance3D:
	var idx := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(0, idx.size(), 3):
		# Wind the triangles so they face up.
		for j in [0, 2, 1]:
			var p: Vector2 = poly[idx[i + j]]
			st.set_uv(p * 0.25)
			st.add_vertex(Vector3(p.x, y, p.y))
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	add_child(mi)
	return mi


func _wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "ShoreWall"
	add_child(body)
	_collider(body, center, size)


func _collider(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = center
	body.add_child(cs)
