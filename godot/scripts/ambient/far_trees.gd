extends RefCounted

## The trees past the camp's fence, for your body: tens of thousands of them, drawn by the
## multimesh, and you walked through their trunks. No bodies for them, and nothing worked out as
## a chunk of the land is made (a chunk has its own four milliseconds, and a list of its thousands
## of trees in GDScript took tens): each patch of trees is kept as it came, and only the ones
## round you are picked out of it, every couple of metres you walk.
## player_controller._hold_off_far_trees asks if your step is in a trunk.

## Picked out this far round you, and again when you have walked this far.
const REACH := 9.0
const WALK := 2.0

static var _patches: Array = []
static var _near: Array = []
static var _near_from := Vector3.INF


static func clear() -> void:
	_patches.clear()
	_near.clear()
	_near_from = Vector3.INF


## A patch of trees: a multimesh's transforms in the space of `xf`; `rect` (x, z) where they stand
## if you know it; gone with `owner` (a chunk of the land let go).
static func add_all(xforms: Array, xf := Transform3D.IDENTITY, trunk := 0.22, rect := Rect2(), owner: Node = null) -> void:
	if rect.size == Vector2.ZERO:
		for t: Transform3D in xforms:
			var p: Vector3 = xf * t.origin
			var at := Vector2(p.x, p.z)
			rect = Rect2(at, Vector2(0.01, 0.01)) if rect.size == Vector2.ZERO else rect.expand(at)
	_patches.append({"list": xforms, "xf": xf, "trunk": trunk, "rect": rect.grow(REACH + WALK), "owner": owner, "owned": owner != null})
	_near_from = Vector3.INF


## One trunk at `at`, `radius` m round.
static func add(at: Vector3, radius: float) -> void:
	add_all([Transform3D(Basis().scaled(Vector3.ONE * radius), at)], Transform3D.IDENTITY, 1.0)


static func _gather(at: Vector3) -> void:
	_near_from = at
	_near.clear()
	var here := Vector2(at.x, at.z)
	for i in range(_patches.size() - 1, -1, -1):
		var patch: Dictionary = _patches[i]
		if bool(patch["owned"]) and not is_instance_valid(patch["owner"]):
			_patches.remove_at(i)
			continue
		if not (patch["rect"] as Rect2).has_point(here):
			continue
		var xf: Transform3D = patch["xf"]
		var trunk: float = patch["trunk"]
		for t: Transform3D in patch["list"]:
			var p: Vector3 = xf * t.origin
			if absf(p.x - at.x) < REACH and absf(p.z - at.z) < REACH:
				_near.append(Vector3(p.x, trunk * t.basis.x.length(), p.z))


## The way out of any trunk `at` (with `body` m of you round it) stands in, zero if none.
static func way_out(at: Vector3, body: float) -> Vector2:
	if _near_from == Vector3.INF or Vector2(at.x - _near_from.x, at.z - _near_from.z).length() > WALK:
		_gather(at)
	var out := Vector2.ZERO
	for t: Vector3 in _near:
		var flat := Vector2(at.x - t.x, at.z - t.z)
		var d := flat.length()
		var r := t.y + body
		if d < r:
			out += (flat / d if d > 0.001 else Vector2(1.0, 0.0)) * (r - d)
	return out
