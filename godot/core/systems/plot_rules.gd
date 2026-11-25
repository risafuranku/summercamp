extends RefCounted

## The sandbox's land (Richard 25. 11., docs/DESIGN.md "Decisions 25. 11.": „Pozemek se
## kupuje“, „Po pásech od plotu“, „Rostoucí“, „Hranice z kolíků“): a sandbox camp starts on a
## smaller plot round the entrance (small, middle or the whole camp: its setup) and buys strips
## of STRIP tiles along a side of it in Builder 98, each half again dearer than the one before.
## Nothing is built off the plot (core/systems/builder_authority.gd); its edge stands in the
## camp as stakes and tape (scripts/camp/plot_stakes.gd); the outer fence stays where it is.
## A plot is [x0, y0, x1, y1] in grid tiles (x1, y1 past its last), [] the whole camp (a story
## camp, an old save). The south edge is the camp's (the gate's): a plot only grows west, east
## and north. Pure.

const STRIP := 4
## The first strip about a cabin, each next half again dearer.
const FIRST_PRICE := 260
const GROWTH := 1.5
## The setup's plots (0 small, 1 middle, 2 whole): [width, depth] from the south fence, its
## middle on the gate lane; -1 the whole camp.
const SIZES := [Vector2i(12, 12), Vector2i(20, 18), Vector2i(-1, -1)]
const SIDES := ["west", "east", "north"]


## The plot a new camp of `size` starts on (grid `grid`, the gate lane at column `gate_x`).
static func start(size: int, grid: Vector2i, gate_x: int) -> Array:
	var s: Vector2i = SIZES[clampi(size, 0, SIZES.size() - 1)]
	if s.x < 0 or s.x >= grid.x and s.y >= grid.y:
		return []
	var x0 := clampi(gate_x - s.x / 2, 0, maxi(0, grid.x - s.x))
	return [x0, 0, mini(grid.x, x0 + s.x), mini(grid.y, s.y)]


## `plot` as it is meant: [] the whole camp.
static func rect(plot: Array, grid: Vector2i) -> Rect2i:
	if plot.size() < 4:
		return Rect2i(Vector2i.ZERO, grid)
	return Rect2i(int(plot[0]), int(plot[1]), int(plot[2]) - int(plot[0]), int(plot[3]) - int(plot[1]))


static func contains(plot: Array, grid: Vector2i, c: Vector2i) -> bool:
	return rect(plot, grid).has_point(c)


## Whether a footprint `fp` at `origin` is all on the plot.
static func fits(plot: Array, grid: Vector2i, origin: Vector2i, fp: Vector2i) -> bool:
	return rect(plot, grid).encloses(Rect2i(origin, fp))


## The strip a side's purchase adds ({} none left that side).
static func strip(plot: Array, grid: Vector2i, side: String) -> Rect2i:
	var r := rect(plot, grid)
	match side:
		"west":
			var w := mini(STRIP, r.position.x)
			return Rect2i(r.position.x - w, r.position.y, w, r.size.y) if w > 0 else Rect2i()
		"east":
			var e := mini(STRIP, grid.x - r.end.x)
			return Rect2i(r.end.x, r.position.y, e, r.size.y) if e > 0 else Rect2i()
		"north":
			var n := mini(STRIP, grid.y - r.end.y)
			return Rect2i(r.position.x, r.end.y, r.size.x, n) if n > 0 else Rect2i()
	return Rect2i()


## The plot with `side`'s strip added ([] once it is the whole camp).
static func grow(plot: Array, grid: Vector2i, side: String) -> Array:
	var s := strip(plot, grid, side)
	if s.size == Vector2i.ZERO:
		return plot.duplicate()
	var r := rect(plot, grid).merge(s)
	if r.position == Vector2i.ZERO and r.size == grid:
		return []
	return [r.position.x, r.position.y, r.end.x, r.end.y]


## The next strip's price, `bought` strips bought before it.
static func price(bought: int) -> int:
	return int(round(float(FIRST_PRICE) * pow(GROWTH, float(maxi(0, bought)))))
