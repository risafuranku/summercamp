extends RefCounted

## The trees past the camp's fence, for your body: thousands of them, drawn by the multimesh, and
## you walked through their trunks. No bodies for them (a chunk of the land is made in a few
## milliseconds): where they stand is kept here by cells, and the player's step asks if it is in
## a trunk (player_controller._hold_off_far_trees).

const CELL := 6.0

static var _cells := {}


static func clear() -> void:
	_cells.clear()


## A trunk at `at`, `radius` m round.
static func add(at: Vector3, radius: float) -> void:
	var c := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	if not _cells.has(c):
		_cells[c] = {}
	# (By where it stands: a chunk of the land is made again, and the same tree is one tree.)
	(_cells[c] as Dictionary)[Vector2i(roundi(at.x * 4.0), roundi(at.z * 4.0))] = Vector3(at.x, radius, at.z)


## All the trees of a multimesh's transforms, in the space of `xf`.
static func add_all(xforms: Array, xf := Transform3D.IDENTITY, trunk := 0.22) -> void:
	for t: Transform3D in xforms:
		add(xf * t.origin, trunk * t.basis.x.length())


## The way out of any trunk `at` (with `body` m of you round it) stands in, zero if none.
static func way_out(at: Vector3, body: float) -> Vector2:
	var out := Vector2.ZERO
	var c := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell = _cells.get(c + Vector2i(dx, dy))
			if cell == null:
				continue
			for t: Vector3 in (cell as Dictionary).values():
				var flat := Vector2(at.x - t.x, at.z - t.z)
				var d := flat.length()
				var r := t.y + body
				if d < r:
					out += (flat / d if d > 0.001 else Vector2(1.0, 0.0)) * (r - d)
	return out
