extends RefCounted

## Wires (the masts' guys and frames, the power lines along the roads) as ribbons turned to
## the eye that never get thinner than a pixel and a bit on the low-resolution screen, and
## solid: a 1-px line flickered in and out as you went past, a 3.5 cm box went under a
## pixel a few metres off and broke up, and the guys were drawn see-through (the user
## 4. 11.: "the masts' cables close to them clip weirdly, they are half transparent, not
## quite there, riding the bus"). Far off they go into the haze by colour, not by alpha.
##
## mesh(): every pair of points (a, b, a, b, ...) one straight piece of wire, each end
## knowing the other (CUSTOM0: the other end and the side), the vertex shader widening it
## across the view at its own depth.

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled{FOG};
uniform vec4 haze_color : source_color = vec4(0.7, 0.76, 0.82, 1.0);
uniform float haze = 0.0;
uniform float light = 1.0;
uniform vec3 color = vec3(0.24, 0.24, 0.25);
// Half its real thickness (m), and the least it is on the screen (pixels across).
uniform float radius = 0.02;
uniform float min_px = 1.3;
void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 q = (MODELVIEW_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
	vec3 side = cross(q - p, p);
	float sl = length(side);
	side = sl > 1e-6 ? side / sl : vec3(1.0, 0.0, 0.0);
	// (A piece's end behind the eye: as far as it is, so the width along the piece in
	// front does not shrink toward it.)
	float d = max(abs(p.z), 0.05);
	// (Its y scale is negative: the renderer's clip space has y down.)
	float per_px = 2.0 * d / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	p += side * max(radius, min_px * per_px * 0.5) * CUSTOM0.w;
	POSITION = PROJECTION_MATRIX * vec4(p, 1.0);
}
void fragment() {
	ALBEDO = mix(color * light, haze_color.rgb, clamp(haze, 0.0, 1.0));
}
"""

static var _shaders: Dictionary = {}
## The longest straight piece a wire is drawn in (metres).
const MAX_PIECE := 10.0


## `own_haze`: hazed by hand (set "haze", "haze_color"; the masts kilometres off), else
## in the world's own fog like everything round it (the power lines).
static func material(color: Color, radius: float, own_haze := false) -> ShaderMaterial:
	if not _shaders.has(own_haze):
		var sh := Shader.new()
		sh.code = SHADER.replace("{FOG}", ", fog_disabled" if own_haze else "")
		_shaders[own_haze] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[own_haze]
	m.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("radius", radius)
	return m


## The ribbons for `segments` (pairs of points in the mesh's space), or null for none.
static func mesh(segments: PackedVector3Array) -> ArrayMesh:
	if segments.size() < 2:
		return null
	var verts := PackedVector3Array()
	var custom := PackedFloat32Array()
	var idx := PackedInt32Array()
	var i := 0
	while i + 1 < segments.size():
		var a0 := segments[i]
		var b0 := segments[i + 1]
		i += 2
		var length := a0.distance_to(b0)
		if length < 1e-4:
			continue
		# In short pieces: each end's width is its own depth's, and over a long guy that
		# passes over your head (one end behind you) it went to nothing in between and the
		# wire broke into dashes.
		var n := maxi(1, ceili(length / MAX_PIECE))
		for k in n:
			var a := a0.lerp(b0, float(k) / float(n))
			var b := a0.lerp(b0, float(k + 1) / float(n))
			var base := verts.size()
			# Each end: its two edges. Seen from b the way to the other end is the other
			# way round, so its sides are the other way round too.
			for e in [[a, b, 1.0], [b, a, -1.0]]:
				for s in [-1.0, 1.0]:
					verts.append(e[0])
					var o: Vector3 = e[1]
					custom.append_array(PackedFloat32Array([o.x, o.y, o.z, s * float(e[2])]))
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return m


## A wire hung from a to b, sagging `sag` metres in its middle: `pieces` straight pieces
## along the curve (pairs, for mesh()).
static func hang(a: Vector3, b: Vector3, sag: float, pieces := 4) -> PackedVector3Array:
	var out := PackedVector3Array()
	var prev := a
	for k in range(1, pieces + 1):
		var t := float(k) / float(pieces)
		var p := a.lerp(b, t) - Vector3(0.0, sag * 4.0 * t * (1.0 - t), 0.0)
		out.append(prev)
		out.append(p)
		prev = p
	return out
