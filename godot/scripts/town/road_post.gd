extends RefCounted

## The Czech roadside post (smerovy sloupek Z 11, "patnik"), as the decree draws it and
## as it stood by every road in 1998: a white plastic post of triangular section, its top
## cut on a slant that falls towards the road, a black band 150 mm under the top edge and
## parallel to it all the way round. The face turned to the traffic on its own side of the
## road carries two orange reflectors lying one above the other; the face turned to the
## other lane one white reflector standing upright; the field side only the band.
## 0.80 m above the ground at the field edge (ordinary roads), 0.13 m faces. Posts stand
## opposite each other, every 50 m on the straight (CSN 73 6101).
##
##   ROAD_POST.place(parent, position, to_road)   to_road: towards the middle of the road
##   ROAD_POST.set_night(on)                      the reflectors catch the headlights
##
## Right-hand traffic is built in: the orange face looks back along the near lane.

const HEIGHT := 0.80        # top of the field edge above the ground
const DROP := 0.07          # how much lower the top is at the road edge
const BAND_FROM := 0.155    # under the top edge, the band's upper edge
const BAND_TO := 0.295
# The triangle: apex towards the road (a), back edge (b) and its width (w).
const A := 0.06
const B := 0.04
const W := 0.16
# The atlas: three faces side by side, PX_COL wide each, PX_M pixels per metre down.
const PX_COL := 16
const PX_M := 128
const ROWS := 128

static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D


static func place(parent: Node3D, pos: Vector3, to_road: Vector3) -> MeshInstance3D:
	var x := Vector3(to_road.x, 0.0, to_road.z).normalized()
	var mi := MeshInstance3D.new()
	mi.name = "RoadPost"
	mi.mesh = mesh()
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# +X to the road, +Z along the near lane's traffic (x cross up).
	mi.transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), pos)
	parent.add_child(mi)
	return mi


static func set_night(on: bool) -> void:
	material().emission_energy_multiplier = 1.3 if on else 0.0


static func material() -> StandardMaterial3D:
	if _mat != null:
		return _mat
	var paint := _atlas(false)
	var glow := _atlas(true)
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = ImageTexture.create_from_image(paint)
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat.roughness = 1.0
	_mat.emission_enabled = true
	_mat.emission = Color(0, 0, 0)
	_mat.emission_texture = ImageTexture.create_from_image(glow)
	_mat.emission_energy_multiplier = 0.0
	return _mat


## How far under the top edge a point of the post is (the top falls towards the road).
static func _top(u: float) -> float:
	return HEIGHT - (u + B) / (A + B) * DROP


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var apex := Vector2(A, 0.0)
	var back_l := Vector2(-B, -W * 0.5)
	var back_r := Vector2(-B, W * 0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Faces as (from, to, atlas column): front (orange), back (white), field side.
	for f in [[back_l, apex, 0], [apex, back_r, 1], [back_r, back_l, 2]]:
		_face(st, f[0], f[1], int(f[2]))
	# The cap: white, from the top row of the atlas.
	var cap_uv := Vector2(0.5 / 3.0, 0.5 / float(ROWS))
	st.set_normal(Vector3(DROP, A + B, 0).normalized())
	# Clockwise seen from outside: Godot's front faces.
	for p in [apex, back_r, back_l]:
		st.set_uv(cap_uv)
		st.add_vertex(Vector3(p.x, _top(p.x), p.y))
	_mesh = st.commit()
	return _mesh


## One face between two corners of the triangle (x = across, y = along in the plane).
static func _face(st: SurfaceTool, p0: Vector2, p1: Vector2, col: int) -> void:
	var edge := p1 - p0
	var n := Vector3(edge.y, 0.0, -edge.x).normalized()
	var u0 := float(col) / 3.0
	var u1 := float(col + 1) / 3.0
	# v: metres under the top edge, so the band and the reflectors run parallel to it.
	var corners := [
		[Vector3(p0.x, 0.0, p0.y), Vector2(u0, _top(p0.x))],
		[Vector3(p1.x, 0.0, p1.y), Vector2(u1, _top(p1.x))],
		[Vector3(p1.x, _top(p1.x), p1.y), Vector2(u1, 0.0)],
		[Vector3(p0.x, _top(p0.x), p0.y), Vector2(u0, 0.0)],
	]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(corners[i][1] * Vector2(1.0, float(PX_M) / float(ROWS)))
		st.add_vertex(corners[i][0])


## The paint (or, with glow, only the reflectors on black) for the three faces.
static func _atlas(glow: bool) -> Image:
	var img := Image.create(PX_COL * 3, ROWS, false, Image.FORMAT_RGB8)
	var white := Color(0.9, 0.9, 0.86)
	var black := Color(0.07, 0.07, 0.07)
	var orange := Color(0.98, 0.5, 0.08)
	var refl_white := Color(0.94, 0.95, 0.96)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var band0 := int(round(BAND_FROM * PX_M))
	var band1 := int(round(BAND_TO * PX_M))
	for col in 3:
		for y in ROWS:
			for x in PX_COL:
				var c := white
				# Road dirt splashed up the lower part, more towards the ground.
				var depth := float(y) / float(PX_M)
				if depth > HEIGHT - 0.22:
					var k := clampf((depth - (HEIGHT - 0.22)) / 0.22, 0.0, 1.0)
					c = c.lerp(Color(0.52, 0.48, 0.4), k * 0.55 + rng.randf() * 0.12)
				elif rng.randf() < 0.04:
					c = c.darkened(0.08)
				if y >= band0 and y < band1:
					c = black
				img.set_pixel(col * PX_COL + x, y, Color(0, 0, 0) if glow else c)
	# Front: two orange reflectors lying one above the other in the band.
	for r in [[band0 + 2, band0 + 7], [band0 + 10, band0 + 15]]:
		for y in range(r[0], r[1]):
			for x in range(4, 12):
				img.set_pixel(x, y, orange)
	# Back: one white reflector standing upright.
	for y in range(band0 + 4, band1 - 4):
		for x in range(6, 10):
			img.set_pixel(PX_COL + x, y, refl_white)
	return img
