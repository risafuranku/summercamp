extends RefCounted

## The camp's paths joined into one (the user, 21. 10.: "when I build paths 2x4, make it
## one big path, in the Builder and in the camp; really join the textures"). A path tile
## is composed from its eight neighbours instead of the Redneck pieces (straight, turn, T,
## cross, end), whose dark green grass corners put a lawn into every block of paths:
##   the gravel   redneck/paths/gravel_fill.png (tools/artgen/path_fill.py), its ruts
##                along the way the path goes, wherever the path reaches: across a side
##                with a path beyond it, into a corner when both its sides and the corner
##                are path;
##   the edge     rounded where it ends, a little ragged (the same along a seam on both
##                tiles), a darker worn rim;
##   the grass    see-through: the camp's own ground (its season) shows round the gravel.
## One texture per pattern of neighbours, kept. BuildingManager (the camp) and the 2D map
## of Builder (crt_map_panel._draw_path) draw the same tiles.

const FILL := "res://assets/textury/redneck/paths/gravel_fill.png"
const SIZE := 128
## The grass left along a side without a path, how round the ends are, how soft the inside
## corners (all in tiles).
const MARGIN := 0.14
const ROUND := 0.17
const FILLET := 0.1
## Neighbour bits.
const N := 1
const E := 2
const S := 4
const W := 8
const NE := 16
const SE := 32
const SW := 64
const NW := 128

static var _cache: Dictionary = {}
static var _fill: PackedByteArray = PackedByteArray()


## The pattern round `coord`; `is_path(coord) -> bool`. A corner counts only with both of
## its sides (otherwise it changes nothing).
static func mask_at(coord: Vector2i, is_path: Callable) -> int:
	var m := 0
	if is_path.call(coord + Vector2i(0, -1)):
		m |= N
	if is_path.call(coord + Vector2i(1, 0)):
		m |= E
	if is_path.call(coord + Vector2i(0, 1)):
		m |= S
	if is_path.call(coord + Vector2i(-1, 0)):
		m |= W
	if m & N and m & E and is_path.call(coord + Vector2i(1, -1)):
		m |= NE
	if m & S and m & E and is_path.call(coord + Vector2i(1, 1)):
		m |= SE
	if m & S and m & W and is_path.call(coord + Vector2i(-1, 1)):
		m |= SW
	if m & N and m & W and is_path.call(coord + Vector2i(-1, -1)):
		m |= NW
	return m


## The tile for a pattern: u east, v south (as a PlaneMesh lies on the ground, and as the
## 2D map maps it onto a tile's diamond).
static func texture(mask: int) -> Texture2D:
	if _cache.has(mask):
		return _cache[mask]
	var tex := ImageTexture.create_from_image(_compose(mask))
	_cache[mask] = tex
	return tex


static func _compose(mask: int) -> Image:
	if _fill.is_empty():
		var src := load(FILL) as Texture2D
		var img: Image = src.get_image() if src != null else null
		if img == null:
			img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.72, 0.56, 0.38))
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
		_fill = img.get_data()
	var m := MARGIN
	# The gravel: rectangles in the tile's frame (reaching past it where the path goes on).
	var rects: Array = [Rect2(m, m, 1.0 - 2.0 * m, 1.0 - 2.0 * m)]
	if mask & E:
		rects.append(Rect2(m, m, 2.0, 1.0 - 2.0 * m))
	if mask & W:
		rects.append(Rect2(-1.0, m, 2.0 - m, 1.0 - 2.0 * m))
	if mask & N:
		rects.append(Rect2(m, -1.0, 1.0 - 2.0 * m, 2.0 - m))
	if mask & S:
		rects.append(Rect2(m, m, 1.0 - 2.0 * m, 2.0))
	if mask & NE:
		rects.append(Rect2(m, -1.0, 2.0, 2.0 - m))
	if mask & SE:
		rects.append(Rect2(m, m, 2.0, 2.0))
	if mask & SW:
		rects.append(Rect2(-1.0, m, 2.0 - m, 2.0))
	if mask & NW:
		rects.append(Rect2(-1.0, -1.0, 2.0 - m, 2.0 - m))
	# Ruts along the way it goes: east-west unless it only goes north-south.
	var across := (mask & (E | W)) == 0 and (mask & (N | S)) != 0
	var out := PackedByteArray()
	out.resize(SIZE * SIZE * 4)
	var inv := 1.0 / float(SIZE)
	for y in SIZE:
		var v := (float(y) + 0.5) * inv
		for x in SIZE:
			var u := (float(x) + 0.5) * inv
			var d := 1e9
			for r in rects:
				d = _smin(d, _box(u, v, r), FILLET)
			d += _ragged(u, v)
			var o := (y * SIZE + x) * 4
			if d >= 0.0:
				out[o + 3] = 0
				continue
			var si := ((x * SIZE + y) if across else (y * SIZE + x)) * 4
			var k := 1.0
			if d > -0.025:
				k = 0.5
			elif d > -0.05:
				k = 0.7
			elif d > -0.08:
				k = 0.86
			out[o] = int(float(_fill[si]) * k)
			out[o + 1] = int(float(_fill[si + 1]) * k)
			out[o + 2] = int(float(_fill[si + 2]) * k)
			out[o + 3] = 255
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, out)


## A rounded box's signed distance (negative inside).
static func _box(u: float, v: float, r: Rect2) -> float:
	var c := r.get_center()
	var h := r.size * 0.5 - Vector2(ROUND, ROUND)
	var qx := absf(u - c.x) - h.x
	var qy := absf(v - c.y) - h.y
	return Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - ROUND


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


## The edge's raggedness: whole waves across a tile, so it meets itself at every seam.
static func _ragged(u: float, v: float) -> float:
	return 0.012 * sin(TAU * (3.0 * u) + 1.3) * sin(TAU * (2.0 * v) + 0.4) \
		+ 0.008 * sin(TAU * (5.0 * u + 4.0 * v) + 2.1) \
		+ 0.006 * sin(TAU * (7.0 * v - 3.0 * u) + 0.7)
