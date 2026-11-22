extends RefCounted

## What lies on a pipe's wall (moss, fungus, the thing's guts, scratches): a strip of the
## pipe's own inside, following its ten faces, so nothing stands out of the concrete as a
## flat card or hangs in the air (22. 11.: cards half a metre wide in a pipe 0.8 m across
## poked through the curve in shards). Kept clear of the junctions' drums at either end.
##
## The pipes are CSG cylinders of SIDES faces (scripts/sewer_pipe_minigame.gd _pipe): one
## running along X has a corner at its crown, one running along Z a face there.

const SIDES := 10
## How far in front of the wall it lies (no flicker against the concrete).
const INSET := 0.008


## `a` and `b`: the pipe's ends on the ground plan (world, at any height), `r` its radius,
## `axis_y` the height of its axis. `t`: where along it from a (0..1), clamped clear of the
## drums (`drum_r` the junction's radius). `ang`: round the wall from the crown (0 the
## crown, +-PI/2 the sides, PI the invert). `size`: across and along in metres. `spin`: the
## picture turned on the wall.
static func patch(mat: Material, a: Vector3, b: Vector3, r: float, axis_y: float, drum_r: float, t: float, ang: float, size: Vector2, spin: float = 0.0) -> MeshInstance3D:
	var flat_a := Vector3(a.x, 0.0, a.z)
	var flat_b := Vector3(b.x, 0.0, b.z)
	var length := flat_a.distance_to(flat_b)
	if length < 0.01:
		return null
	var along := (flat_b - flat_a) / length
	var side := Vector3(along.z, 0.0, -along.x)
	var margin := drum_r + size.y * 0.5 + 0.02
	var s_mid := clampf(t * length, minf(margin, length * 0.5), maxf(length - margin, length * 0.5))
	var centre := flat_a + along * s_mid + Vector3(0.0, axis_y, 0.0)
	# A corner at the crown along X, a face along Z (the cylinders' turn).
	var phase := 0.0 if absf(along.x) > 0.5 else PI / float(SIDES)
	var half_ang := size.x * 0.5 / r
	var a0 := ang - half_ang
	var a1 := ang + half_ang
	var angs: Array[float] = [a0]
	var step := TAU / float(SIDES)
	var k := ceilf((a0 - phase) / step)
	while phase + k * step < a1:
		var v := phase + k * step
		if v > a0 + 0.001:
			angs.append(v)
		k += 1.0
	angs.append(a1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := cos(spin)
	var s := sin(spin)
	# The picture's foot down the wall (moss drips, guts run down), its width along the pipe.
	var down := 1.0 if sin(ang) >= 0.0 else -1.0
	var rows: Array = []
	for th in angs:
		var out := (side * sin(th) + Vector3.UP * cos(th)).normalized()
		var rr := _radius_at(r, th - phase) - INSET
		var across := (th - ang) * r
		var row: Array = []
		for sv: float in [-0.5, 0.5]:
			var p: Vector3 = centre + out * rr + along * (sv * size.y)
			var lx := sv
			var ly := across / size.x * down
			var uv := Vector2(lx * c - ly * s, lx * s + ly * c) + Vector2(0.5, 0.5)
			row.append([p, uv, -out])
		rows.append(row)
	for i in rows.size() - 1:
		var q0: Array = rows[i]
		var q1: Array = rows[i + 1]
		# Wound clockwise as seen from the axis: the front faces the one crawling.
		for v in [q0[0], q1[1], q1[0], q0[0], q0[1], q1[1]]:
			st.set_normal(v[2])
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


## The ten-sided pipe's distance from its axis at an angle from one of its corners.
static func _radius_at(r: float, from_corner: float) -> float:
	var step := TAU / float(SIDES)
	var d := fposmod(from_corner, step) - step * 0.5
	return r * cos(step * 0.5) / cos(d)


## The decal material every patch of one picture shares: cut out, both sides, no repeat
## (a turned picture's corners stay empty). `tint` takes a pale picture down to the wet
## concrete's (a plaster patch under the torch stood out as a lit square).
static func material(tex: Texture2D, roughness: float = 0.6, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.texture_repeat = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = roughness
	return m
