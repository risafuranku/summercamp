extends RefCounted

## A path trodden over grass: a strip that wanders a little and goes wider and narrower with
## ragged edges, the way feet leave one. (They were straight planes with cut edges: dark red
## straps laid over the village green.) The picture runs along it, its grass rims along the
## edges. On a flat, as the green and the yards are.

const STEP := 0.45
## The dirt in the light of the street: brown through the palette, not its dark maroon.
const TINT := Color(1.3, 1.24, 1.02)


static func mesh(a: Vector3, b: Vector3, width: float, rng: RandomNumberGenerator, wander := 0.14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := b - a
	var length := d.length()
	var along := d / maxf(length, 0.001)
	var side := Vector3(along.z, 0.0, -along.x)
	var n := maxi(2, int(ceil(length / STEP)))
	var s1 := rng.randf() * TAU
	var s2 := rng.randf() * TAU
	var s3 := rng.randf() * TAU
	var left: Array = []
	var right: Array = []
	var vs: Array = []
	for i in n + 1:
		var k := float(i) / float(n)
		var t := k * length
		# Pinned at both ends: it starts and stops where it was asked to.
		var ends := minf(1.0, minf(k, 1.0 - k) * 6.0)
		var mid := a + along * t + side * (sin(t * 0.7 + s1) * wander + sin(t * 1.9 + s2) * wander * 0.45) * ends
		var half := width * 0.5 * (1.0 + 0.16 * sin(t * 1.3 + s3))
		left.append(mid - side * (half + rng.randf_range(-0.09, 0.09)))
		right.append(mid + side * (half + rng.randf_range(-0.09, 0.09)))
		vs.append(t / 1.4)
	for i in n:
		_corner(st, left[i], 0.0, vs[i])
		_corner(st, right[i], 1.0, vs[i])
		_corner(st, right[i + 1], 1.0, vs[i + 1])
		_corner(st, left[i], 0.0, vs[i])
		_corner(st, right[i + 1], 1.0, vs[i + 1])
		_corner(st, left[i + 1], 0.0, vs[i + 1])
	return st.commit()


static func _corner(st: SurfaceTool, p: Vector3, u: float, v: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(u, v))
	st.add_vertex(p)


## Its own dice: a path must not move what the town rolls for after it.
static func dice(nth: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1998 + nth * 31
	return r


## The strip as a node under `parent`, in `parent`'s space, not casting anything.
static func lay(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material, rng: RandomNumberGenerator, wander := 0.14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(a, b, width, rng, wander)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
