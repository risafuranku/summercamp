extends RefCounted

## A ten-pin bowling pin as a turned low-poly mesh (the user 21. 10.: "we want real
## bowling"): the regulation profile (15 in tall, 4.77 in across the belly, the neck at
## two thirds), white with the two red neck stripes in its vertex colours, a little
## grimier toward the foot. The camp's bowling alley stands one three metres tall on its
## roof (building_models._bowling); the lanes inside use the real size.
##
##   PIN_MESH.mesh(height, sides) -> ArrayMesh (origin on the floor at its middle)
##   PIN_MESH.material() -> the material for it (vertex colours, flat, no shine)

## The profile: [height (0..1), radius (shares of the height)], bottom to top.
const PROFILE := [
	[0.0, 0.0], [0.0, 0.064], [0.03, 0.094], [0.1, 0.136], [0.2, 0.156], [0.3, 0.158],
	[0.4, 0.142], [0.5, 0.108], [0.58, 0.074], [0.64, 0.066], [0.72, 0.074], [0.8, 0.088],
	[0.87, 0.086], [0.93, 0.07], [0.975, 0.042], [1.0, 0.0],
]
## The red stripes round the neck (shares of the height).
const STRIPES := [[0.585, 0.615], [0.655, 0.685]]
const WHITE := Color(0.93, 0.92, 0.88)
const RED := Color(0.72, 0.1, 0.09)

static var _cache := {}


static func mesh(height: float, sides := 12) -> ArrayMesh:
	var key := "%.3f/%d" % [height, sides]
	if _cache.has(key):
		return _cache[key]
	# The stripes' edges as rings of their own, so the colour changes sharply there.
	var rings: Array = []
	for p in PROFILE:
		rings.append([float(p[0]), float(p[1])])
	for s in STRIPES:
		for y in s:
			rings.append([float(y), _radius_at(float(y))])
	rings.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size() - 1):
		var y0 := float(rings[i][0])
		var y1 := float(rings[i + 1][0])
		var r0 := float(rings[i][1]) * height
		var r1 := float(rings[i + 1][1]) * height
		var c := _colour_at((y0 + y1) * 0.5)
		# The band's slope: its normal leans out and up (or down, for the foot's disc).
		var dy := (y1 - y0) * height
		var dr := r1 - r0
		for k in sides:
			var a0 := TAU * float(k) / float(sides)
			var a1 := TAU * float(k + 1) / float(sides)
			var p00 := Vector3(cos(a0) * r0, y0 * height, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, y0 * height, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, y1 * height, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, y1 * height, sin(a1) * r1)
			var n0 := Vector3(cos(a0) * dy, -dr, sin(a0) * dy).normalized()
			var n1 := Vector3(cos(a1) * dy, -dr, sin(a1) * dy).normalized()
			for e in [[p00, n0], [p10, n0], [p11, n1], [p00, n0], [p11, n1], [p01, n1]]:
				st.set_color(c)
				st.set_normal(e[1])
				st.add_vertex(e[0])
	var m := st.commit()
	_cache[key] = m
	return m


static func _radius_at(y: float) -> float:
	for i in range(PROFILE.size() - 1):
		var a: Array = PROFILE[i]
		var b: Array = PROFILE[i + 1]
		if y >= float(a[0]) and y <= float(b[0]):
			var span := maxf(0.0001, float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), (y - float(a[0])) / span)
	return 0.0


static func _colour_at(y: float) -> Color:
	for s in STRIPES:
		if y > float(s[0]) and y < float(s[1]):
			return RED
	# The foot takes the floor's grime.
	return WHITE.darkened(clampf(0.18 - y * 0.6, 0.0, 0.18))


static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# Its normals are set by hand, so either winding shows.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m
