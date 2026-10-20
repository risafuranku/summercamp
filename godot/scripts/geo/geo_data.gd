extends RefCounted

## The real land round the camp (tools/geo/build_world.py -> data/geo/world.json), read
## once: metres from the camp's centre, x east, z south (-z north: the camp's gate and its
## road face north, to road 12). The bus route of line 380 with its stops, and the
## places' names (real ones; change them here).
##
## Data (c) OpenStreetMap contributors, ODbL.

const DATA := "res://data/geo/world.json"

## The names on the signs, the timetable and in what people say.
const CAMP_NAME := "Černé jezero, kemp"
const CAMP_NAME_ASCII := "Cerne jezero"
const TOWN := "Liblice"
const HAMLET := "Přistoupim"
const BROD := "Český Brod"
## Where line 380 goes on to past Liblice (east along Lstiborska) and comes from.
const BEYOND := "Lstiboř"
const SHOP := "Jednota u Marků"

static var _data: Dictionary = {}
static var _route: PackedVector2Array = PackedVector2Array()
static var _route_s: PackedFloat32Array = PackedFloat32Array()


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary:
			_data = parsed
	return _data


## A flat [x0, z0, x1, z1, ...] list as points.
static func pts(flat_list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(flat_list.size() / 2)
	for i in out.size():
		out[i] = Vector2(float(flat_list[i * 2]), float(flat_list[i * 2 + 1]))
	return out


# ── the route (from where the camp's road meets the real one, on to Lstibor) ──

## The line from the camp road's join with the real road on: points and the distance to
## each from its start.
static func route() -> PackedVector2Array:
	if _route.is_empty():
		_route = pts(data().get("route", []))
		_route_s.resize(_route.size())
		var acc := 0.0
		for i in _route.size():
			if i > 0:
				acc += _route[i].distance_to(_route[i - 1])
			_route_s[i] = acc
	return _route


static func route_length() -> float:
	route()
	return _route_s[_route_s.size() - 1] if not _route_s.is_empty() else 0.0


## Where along the route (from its start) a stop is: "pristoupim" or "liblice".
static func stop_s(stop: String) -> float:
	return float(data().get("stops", {}).get(stop, {}).get("s", -1.0))


## The route's point `s` metres along, `lane` metres to the right of its middle
## (right-hand traffic: +1.6 is the lane a bus drives in), and its heading there.
static func at(s: float, lane := 0.0) -> Dictionary:
	var r := route()
	if r.size() < 2:
		return {"p": Vector3.ZERO, "dir": Vector3.FORWARD}
	s = clampf(s, 0.0, _route_s[_route_s.size() - 1])
	var i := _route_s.bsearch(s) - 1
	i = clampi(i, 0, r.size() - 2)
	var a := r[i]
	var b := r[i + 1]
	var seg := maxf(0.001, _route_s[i + 1] - _route_s[i])
	var f := clampf((s - _route_s[i]) / seg, 0.0, 1.0)
	var p := a.lerp(b, f)
	var d := (b - a).normalized()
	# Round the corners: the heading eases from one segment's to the next over a few
	# metres either side of each bend.
	var ease := 6.0
	if s - _route_s[i] < ease and i > 0:
		var prev := (a - r[i - 1]).normalized()
		d = prev.lerp(d, 0.5 + 0.5 * (s - _route_s[i]) / ease).normalized()
	elif _route_s[i + 1] - s < ease and i + 2 < r.size():
		var nxt := (r[i + 2] - b).normalized()
		d = d.lerp(nxt, 0.5 - 0.5 * (_route_s[i + 1] - s) / ease).normalized()
	var right := Vector2(-d.y, d.x)
	p += right * lane
	return {"p": Vector3(p.x, 0.0, p.y), "dir": Vector3(d.x, 0.0, d.y)}


## How sharp the route turns around `s` (radians over 20 m), for slowing in bends.
static func bend(s: float) -> float:
	var a: Vector3 = at(s - 10.0)["dir"]
	var b: Vector3 = at(s + 10.0)["dir"]
	return a.angle_to(b)


## The nearest point of the route to `p` (xz): its distance along and away.
static func nearest(p: Vector3) -> Dictionary:
	var r := route()
	var q := Vector2(p.x, p.z)
	var best := {"s": 0.0, "d": 1e9}
	for i in r.size() - 1:
		var a := r[i]
		var b := r[i + 1]
		var ab := b - a
		var ll := ab.length_squared()
		var f := 0.0 if ll < 1e-6 else clampf((q - a).dot(ab) / ll, 0.0, 1.0)
		var d := q.distance_to(a + ab * f)
		if d < float(best["d"]):
			best = {"s": _route_s[i] + f * sqrt(ll), "d": d}
	return best


## The stop's point on the route (xz) and the route's heading there.
static func stop_point(stop: String) -> Dictionary:
	return at(stop_s(stop))


## The masts of Liblice B (their footings), world xz.
static func masts() -> Array:
	var out: Array = []
	for m in data().get("masts", []):
		out.append(Vector3(float(m[0]), 0.0, float(m[1])))
	return out


## Points along the route from `s0` to `s1` (either way), every `step` m, `lane` m to the
## right of the way the bus goes (so +1.6 is its own lane both ways).
static func line_path(s0: float, s1: float, lane: float, step := 3.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var dir := 1.0 if s1 >= s0 else -1.0
	var n := maxi(1, int(ceil(absf(s1 - s0) / step)))
	for k in n + 1:
		var s := lerpf(s0, s1, float(k) / float(n))
		out.append(at(s, lane * dir)["p"])
	return out


## The route's distance at the point nearest `p`.
static func s_near(p: Vector3) -> float:
	return float(nearest(p)["s"])


## The first `length` m of the real route (from where the camp's road meets it), walked
## from its far end back to its start, `lane` m to the right of the way it is walked.
static func route_path_head(length: float, lane: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := maxi(1, int(ceil(length / 4.0)))
	for k in n + 1:
		var s := length * (1.0 - float(k) / float(n))
		out.append(at(s, -lane)["p"])
	return out
