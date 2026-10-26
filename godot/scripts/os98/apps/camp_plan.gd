extends Control

## GuestRack 98's plan of the camp (the Rooms tab; the user 20. 10.: "GuestRack has no map
## or stylised picture; I click CampStat's 'a dirty cabin' and want to learn which one"):
## the camp seen from above as the program prints it, a sheet of paper with the grid,
## the lake, the paths, every building a box, the rooms coloured by how they stand
## (ready green, to clean red, not made up amber, taken blue) with their numbers, the
## rest grey with a short name, a broken one crossed. A click picks a building (`picked`),
## the one asked for (`focus`) blinks. What it shows is read in `rebuild()` (GuestRack's
## refresh), not every frame.

const T = preload("res://scripts/os98/os_theme.gd")
const PAPER := Color8(250, 248, 238)
const GRID := Color8(230, 228, 216)
const LAKE := Color8(176, 206, 232)
const PATH := Color8(216, 200, 166)
const INK := Color8(40, 40, 52)
const READY := Color8(70, 160, 70)
const DIRTY := Color8(200, 56, 40)
const UNMADE := Color8(214, 160, 40)
const TAKEN := Color8(80, 110, 210)
const SERVICE := Color8(200, 200, 190)
const BLINK := Color8(255, 220, 0)
const SHORT := {
	"toilet_block": "WC", "shower_block": "Sh", "pub": "Pub", "pub_2": "Pub", "restaurant": "Bis", "vecerka": "Jed",
	"corn_stand": "Crn", "bonfire": "Fire", "sewer": "Sew", "power_generator": "Gen", "main_building": "Office",
	"sports_field": "Pitch", "lake_slide": "Slide", "playground": "Play", "ping_pong": "PP",
}

signal picked(coord: Vector2i)

var grid_manager
## The building to show (its origin): it blinks.
var focus := Vector2i(-1, -1)
## [{type, origin, footprint, col, label, lodging, broken, room}] and the ground, from `rebuild()`.
var buildings: Array = []
var _lake: Array = []
var _paths: Array = []
var _boxes: Array = []   # [Rect2, origin]
## The part of the camp drawn: what is built and a margin, not the empty forest.
var _view := Rect2i()
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(func():
		if grid_manager != null and not buildings.is_empty():
			_view = _bounds()
		queue_redraw())


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree() and focus.x >= 0:
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for b in _boxes:
			if (b[0] as Rect2).grow(1.0).has_point(e.position):
				focus = b[1]
				picked.emit(b[1])
				queue_redraw()
				accept_event()
				return


## The building with this cell in it (its row), or {}.
func building_at(coord: Vector2i) -> Dictionary:
	for b in buildings:
		if Rect2i(b["origin"], b["footprint"]).has_point(coord):
			return b
	return {}


## Reads the camp: the ground, every building once, how each room stands, what is broken.
func rebuild() -> void:
	buildings.clear()
	_lake.clear()
	_paths.clear()
	if grid_manager == null:
		queue_redraw()
		return
	var st = CoreRoot.get_state() if CoreRoot != null else null
	if st != null and st.grid != null:
		for c in st.grid.tile_types:
			if int(st.grid.tile_types[c]) == int(grid_manager.TILE_LAKE):
				_lake.append(c)
		for c in st.grid.cells:
			if str((st.grid.cells[c] as Dictionary).get("type", "")) == "path":
				_paths.append(c)
	var wear := _wear()
	var seen := {}
	for y in int(grid_manager.grid_height):
		for x in int(grid_manager.grid_width):
			var tile = grid_manager.get_tile(Vector2i(x, y))
			if tile == null or not tile.occupied or tile.occupant == null:
				continue
			var root: Node = tile.occupant
			while not root.has_meta("grid_origin") and root.get_parent() is Node3D:
				root = root.get_parent()
			if root.is_in_group("trees") or root.is_in_group("corn") or seen.has(root.get_instance_id()):
				continue
			seen[root.get_instance_id()] = true
			var t := str(root.get_meta("building_type", ""))
			if t == "" or t == "path" or t == "lamp_post":
				continue
			var og: Vector2i = root.get_meta("grid_origin", Vector2i(x, y))
			var key := "%d:%d" % [og.x, og.y]
			var rs: Dictionary = GuestManager.get_room_state(key) if GuestManager != null else {}
			var row := {"type": t, "origin": og, "footprint": root.get_meta("grid_footprint", Vector2i.ONE),
				"col": SERVICE, "label": str(SHORT.get(t, "")), "lodging": not rs.is_empty(), "broken": bool((wear.get(og, {}) as Dictionary).get("broken", false)),
				"condition": float((wear.get(og, {}) as Dictionary).get("condition", -1.0)), "room": rs}
			if not rs.is_empty():
				var s := str(rs.get("status", ""))
				row["col"] = TAKEN if bool(rs.get("occupied", false)) else ({"ready": READY, "dirty": DIRTY}.get(s, UNMADE) as Color)
				row["label"] = GuestManager.room_short(key)
			buildings.append(row)
	_view = _bounds()
	queue_redraw()


## What is built (buildings and paths) and two cells round it, at least 14 across and as
## wide as the control is. The sewer and the generator stand off in the corners: left out
## unless shown, or a tent would be a dot.
const OFF_PLAN := {"sewer": true, "power_generator": true, "sewage_tank": true, "water_pump": true}


func _bounds() -> Rect2i:
	var gw := int(grid_manager.grid_width)
	var gh := int(grid_manager.grid_height)
	var lo := Vector2i(gw, gh)
	var hi := Vector2i(-1, -1)
	for b in buildings:
		if OFF_PLAN.has(str(b["type"])) and Vector2i(b["origin"]) != focus:
			continue
		lo = lo.min(b["origin"])
		hi = hi.max(Vector2i(b["origin"]) + Vector2i(b["footprint"]) - Vector2i.ONE)
	for c in _paths:
		lo = lo.min(c)
		hi = hi.max(c)
	if hi.x < 0:
		return Rect2i(0, 0, gw, gh)
	lo -= Vector2i(2, 2)
	hi += Vector2i(2, 2)
	var aspect := size.x / maxf(1.0, size.y) if size.y > 0.0 else 1.0
	var w := maxi(14, hi.x - lo.x + 1)
	var h := maxi(14, hi.y - lo.y + 1)
	if float(w) / float(h) < aspect:
		w = int(ceil(h * aspect))
	else:
		h = int(ceil(w / aspect))
	w = mini(w, gw)
	h = mini(h, gh)
	var c := (lo + hi) / 2
	var x0 := clampi(c.x - w / 2, 0, gw - w)
	var y0 := clampi(c.y - h / 2, 0, gh - h)
	return Rect2i(x0, y0, w, h)


## The cell size and where the camp starts, to fit the control.
func _fit(gw: int, gh: int) -> Array:
	var cell := maxf(3.0, floorf(minf((size.x - 8.0) / float(gw), (size.y - 8.0) / float(gh))))
	return [cell, ((size - Vector2(gw, gh) * cell) * 0.5).floor()]


func _draw() -> void:
	_boxes.clear()
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	draw_rect(Rect2(Vector2.ZERO, size), T.SHADOW, false, 1.0)
	if grid_manager == null:
		return
	if _view.size.x <= 0 or _view.size.y <= 0:
		return
	var gw := _view.size.x
	var gh := _view.size.y
	var f := _fit(gw, gh)
	var cell: float = f[0]
	# The view's first cell at the fitted corner: every cell drawn from it.
	var o: Vector2 = f[1] - Vector2(_view.position) * cell
	var area := Rect2(f[1], Vector2(gw, gh) * cell)
	for x in gw + 1:
		draw_line(area.position + Vector2(x * cell, 0), area.position + Vector2(x * cell, gh * cell), GRID, 1.0)
	for y in gh + 1:
		draw_line(area.position + Vector2(0, y * cell), area.position + Vector2(gw * cell, y * cell), GRID, 1.0)
	for c in _lake:
		if _view.has_point(c):
			draw_rect(Rect2(o + Vector2(c) * cell, Vector2(cell, cell)), LAKE)
	for c in _paths:
		if _view.has_point(c):
			draw_rect(Rect2(o + Vector2(c) * cell + Vector2(1, 1), Vector2(cell - 2, cell - 2)), PATH)
	for b in buildings:
		if _view.intersects(Rect2i(b["origin"], b["footprint"])):
			_draw_building(b, o, cell)
	draw_rect(area, INK, false, 1.0)


func _draw_building(b: Dictionary, o: Vector2, cell: float) -> void:
	var og: Vector2i = b["origin"]
	var r := Rect2(o + Vector2(og) * cell + Vector2(1, 1), Vector2(b["footprint"]) * cell - Vector2(2, 2))
	var lit := og == focus and int(_t * 3.0) % 2 == 0
	draw_rect(r, b["col"])
	if og == focus:
		draw_rect(r.grow(1.0), BLINK if lit else INK, false, 3.0)
	else:
		draw_rect(r, INK, false, 1.0)
	if bool(b["broken"]):
		draw_line(r.position, r.end, DIRTY, 2.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), DIRTY, 2.0)
	var label := tr(str(b["label"]))
	if label != "":
		# A room's number always (a tent is one cell: it runs over, outlined); a service's
		# name only where it fits.
		var font: Font = T.FONT_BOLD if bool(b["lodging"]) else T.FONT
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var at := Vector2(floorf(r.position.x + (r.size.x - w) * 0.5), floorf(r.position.y + r.size.y * 0.5 + 5))
		if bool(b["lodging"]):
			draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, 3, INK)
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
		elif w <= r.size.x + 4.0:
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, INK)
	_boxes.append([r, og])


## How each building wears (CampStat's upkeep), by origin.
func _wear() -> Dictionary:
	var out := {}
	var m = get_tree().current_scene if get_tree() != null else null
	if m != null and m.has_method("get_upkeep_snapshot"):
		for row in (m.get_upkeep_snapshot() as Dictionary).get("rows", []):
			if row.get("coord", null) is Vector2i:
				out[row["coord"]] = row
	return out
