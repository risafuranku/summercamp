extends RefCounted

## The Builder's construction feedback (crt_map_panel.gd draws the map and calls these on
## its dynamic layer each frame). One visual language for all of it (playtest 2026-10-17:
## "make building feel alive, not green and red squares"): cool blue light for what you
## point at and may do, warm amber when it costs or will happen, red with hatching where it
## cannot. Everything is a few lines and polygons a frame from shared time values, no nodes.
##
##   wave      a ring of light rolls out over the cells round the one you just pointed at
##   grid      a faint local grid round the cursor while a tool is out, fading with distance,
##             its lines one pixel wide at any zoom
##   outline   the edge of a set of cells (a footprint, a drag) as one outline, a light
##             running round it
##   ripple    rings out from a footprint when something is built, inward when removed
##   flash     the cells of something just built glow and fade

const BLUE := Color(0.55, 0.85, 1.0)
const AMBER := Color(1.0, 0.78, 0.36)
const RED := Color(1.0, 0.36, 0.3)
const WAVE_SPEED := 9.0      # cells a second
const WAVE_REACH := 3.2
const GRID_REACH := 4.5

var _wave_at := Vector2i(-1, -1)
var _wave_t := 9.0
var _ripples: Array = []     # {cells: Array[Vector2i], t, life, color, inward}
var _flashes: Array = []     # {cells, t, life}


func point_at(cell: Vector2i) -> void:
	if cell == _wave_at:
		return
	_wave_at = cell
	_wave_t = 0.0


func built(cells: Array, removed := false) -> void:
	_ripples.append({"cells": cells.duplicate(), "t": 0.0, "life": 0.7, "color": (RED if removed else AMBER), "inward": removed})
	if not removed:
		_flashes.append({"cells": cells.duplicate(), "t": 0.0, "life": 0.9})


func tick(delta: float) -> void:
	_wave_t += delta
	for r in _ripples:
		r["t"] = float(r["t"]) + delta
	_ripples = _ripples.filter(func(r): return float(r["t"]) < float(r["life"]))
	for f in _flashes:
		f["t"] = float(f["t"]) + delta
	_flashes = _flashes.filter(func(f): return float(f["t"]) < float(f["life"]))


func busy() -> bool:
	return _wave_t < 1.0 or not _ripples.is_empty() or not _flashes.is_empty()


## `iso`: Callable(Vector2 cell) -> Vector2 panel point of that cell's middle (cells may be
## fractional); `valid`: Callable(Vector2i) -> bool.
func draw_wave(cv: CanvasItem, iso: Callable, valid: Callable, tile_w: float, tile_h: float) -> void:
	if _wave_t > (WAVE_REACH + 1.0) / WAVE_SPEED or not bool(valid.call(_wave_at)):
		return
	var front := _wave_t * WAVE_SPEED
	var r := int(ceil(WAVE_REACH))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := _wave_at + Vector2i(dx, dy)
			if (dx == 0 and dy == 0) or not bool(valid.call(c)):
				continue
			var d := Vector2(dx, dy).length()
			if d > WAVE_REACH:
				continue
			var band := 1.0 - clampf(absf(d - front) / 0.9, 0.0, 1.0)
			if band <= 0.0:
				continue
			var a := band * (1.0 - d / (WAVE_REACH + 0.5)) * 0.32
			_diamond(cv, iso.call(Vector2(c)), tile_w * 0.92, tile_h * 0.92, Color(BLUE.r, BLUE.g, BLUE.b, a * 0.45), Color(BLUE.r, BLUE.g, BLUE.b, a))


## The local grid round `at`: cell edges within GRID_REACH, fainter further out.
func draw_grid(cv: CanvasItem, iso: Callable, valid: Callable, at: Vector2i, tile_w: float, tile_h: float) -> void:
	if not bool(valid.call(at)):
		return
	var r := int(ceil(GRID_REACH))
	var hw := tile_w * 0.5
	var hh := tile_h * 0.5
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := at + Vector2i(dx, dy)
			if not bool(valid.call(c)):
				continue
			var d := Vector2(dx, dy).length()
			if d > GRID_REACH:
				continue
			var a := 0.16 * (1.0 - d / (GRID_REACH + 0.3))
			var p: Vector2 = iso.call(Vector2(c))
			# Two edges per cell (the far ones belong to the neighbours): no doubled lines.
			cv.draw_line(p + Vector2(0, -hh), p + Vector2(hw, 0), Color(1, 1, 1, a), 1.0)
			cv.draw_line(p + Vector2(0, -hh), p + Vector2(-hw, 0), Color(1, 1, 1, a), 1.0)


## A set of cells as one outline (edges with no neighbour in the set), with a soft fill,
## a light running round it (`moving`), hatching when `bad`.
func draw_area(cv: CanvasItem, iso: Callable, cells: Array, tile_w: float, tile_h: float, color: Color, time: float, bad := false, fill_a := 0.22) -> void:
	if cells.is_empty():
		return
	var set := {}
	for c in cells:
		set[c] = true
	var hw := tile_w * 0.5
	var hh := tile_h * 0.5
	for c in cells:
		var p: Vector2 = iso.call(Vector2(c))
		var pts := PackedVector2Array([p + Vector2(0, -hh), p + Vector2(hw, 0), p + Vector2(0, hh), p + Vector2(-hw, 0)])
		cv.draw_colored_polygon(pts, Color(color.r, color.g, color.b, fill_a))
		if bad:
			# Diagonal hatching inside the cell.
			for i in range(1, 4):
				var t := float(i) / 4.0
				cv.draw_line(pts[3].lerp(pts[0], t), pts[2].lerp(pts[1], t), Color(color.r, color.g, color.b, 0.5), 1.0)
	# Edges: in grid terms N (y-1), E (x+1), S (y+1), W (x-1); each is a cell side.
	var edges: Array = []
	for c in cells:
		var cc: Vector2i = c
		var p: Vector2 = iso.call(Vector2(cc))
		var top := p + Vector2(0, -hh)
		var right := p + Vector2(hw, 0)
		var bottom := p + Vector2(0, hh)
		var left := p + Vector2(-hw, 0)
		if not set.has(cc + Vector2i(0, -1)):
			edges.append([top, right])
		if not set.has(cc + Vector2i(1, 0)):
			edges.append([right, bottom])
		if not set.has(cc + Vector2i(0, 1)):
			edges.append([bottom, left])
		if not set.has(cc + Vector2i(-1, 0)):
			edges.append([left, top])
	var width := clampf(tile_h * 0.07, 1.0, 2.5)
	var total := 0.0
	for e in edges:
		total += (e[0] as Vector2).distance_to(e[1])
	var head := fmod(time * 1.4, 1.0) * total
	var run := 0.0
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		cv.draw_line(a, b, Color(color.r, color.g, color.b, 0.9), width)
		var l := a.distance_to(b)
		# The running light: a bright stretch about a cell long.
		var s0 := clampf((head - run) / maxf(l, 0.001), 0.0, 1.0)
		var s1 := clampf((head - run + tile_w * 0.9) / maxf(l, 0.001), 0.0, 1.0)
		if s1 > s0 and head - run < l:
			cv.draw_line(a.lerp(b, s0), a.lerp(b, s1), Color(1, 1, 1, 0.85), width + 1.0)
		run += l


func draw_ripples(cv: CanvasItem, iso: Callable, tile_w: float, tile_h: float) -> void:
	for r in _ripples:
		var k := float(r["t"]) / float(r["life"])
		var cells: Array = r["cells"]
		var mid := Vector2.ZERO
		for c in cells:
			mid += Vector2(c)
		mid /= maxf(1.0, float(cells.size()))
		var span := sqrt(float(cells.size()))
		var col: Color = r["color"]
		for ring in 2:
			var kk := clampf(k - ring * 0.18, 0.0, 1.0)
			if kk <= 0.0:
				continue
			var grow := (span * 0.5 + 0.5) + (kk * 2.4 if not bool(r["inward"]) else (1.0 - kk) * 2.4)
			var p: Vector2 = iso.call(mid)
			var pts := PackedVector2Array([p + Vector2(0, -tile_h * grow), p + Vector2(tile_w * grow, 0), p + Vector2(0, tile_h * grow), p + Vector2(-tile_w * grow, 0), p + Vector2(0, -tile_h * grow)])
			cv.draw_polyline(pts, Color(col.r, col.g, col.b, (1.0 - kk) * 0.8), clampf(tile_h * 0.08, 1.0, 3.0))
	for f in _flashes:
		var k2 := float(f["t"]) / float(f["life"])
		for c in f["cells"]:
			var p2: Vector2 = iso.call(Vector2(c))
			_diamond(cv, p2, tile_w, tile_h, Color(1.0, 0.92, 0.6, 0.4 * (1.0 - k2)), Color(0, 0, 0, 0))


static func _diamond(cv: CanvasItem, p: Vector2, tw: float, th: float, fill: Color, line: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -th * 0.5), p + Vector2(tw * 0.5, 0), p + Vector2(0, th * 0.5), p + Vector2(-tw * 0.5, 0)])
	cv.draw_colored_polygon(pts, fill)
	if line.a > 0.0:
		pts.append(pts[0])
		cv.draw_polyline(pts, line, 1.0)
