extends CanvasLayer

## Hold TAB (or tap it: it stays with the bag, scripts/ui/inventory.gd, until TAB again):
## Vera's site plan on a folded sheet, drawn as you see the camp from the gate (gate at the
## bottom), everything on it what it is: the camp's own pictures (the Builder's, drawn from the
## models), the woods, the paths, the lake (the user 7. 11.: "in a built-up camp you cannot find
## your way, everything is squares"; "the trees need no names"). A lodging's number on a tag in
## the colour of its state (ready, dirty, not made up, guests in). It does NOT show where you
## are. It shows what needs you: broken things in red, tonight's jobs circled in red, who waits
## at the gate, and beside the plan what to do next.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const LANG = preload("res://scripts/lang.gd")
const ROOM_RULES = preload("res://core/systems/room_rules.gd")

const PAPER := Color(0.86, 0.80, 0.64)
const PENCIL := Color(0.22, 0.20, 0.22)
const INK_RED := Color(0.70, 0.10, 0.08)
const INK_AMBER := Color(0.70, 0.45, 0.05)
const PAPER_TEX := "res://assets/textury/map/paper.png"

## Short names written on the plan. Benches, flowers, gnomes and trees have none: their
## pictures say it.
const NAMES := {
	"main_building": "OFFICE",
	"toilet_block": "WC", "shower_block": "SHOWERS", "pub": "PUB", "restaurant": "BISTRO",
	"vecerka": "SHOP", "bonfire": "FIRE", "sports_field": "PITCH", "lake_slide": "SLIDE", "playground": "SWINGS", "ping_pong": "PING-PONG", "corn_stand": "CORN STAND",
	"bowling": "BOWLING", "staffroom": "STAFF",
	"sewer": "SEWER", "power_generator": "GENERATOR", "water_pump": "PUMP", "sewage_tank": "TANK", "dumpsters": "BINS",
}

## The pictures: a building's from the Builder's map (its first side, drawn from the model, a
## tile's width VIEW_TILE across) or, with none, its catalogue's.
const VIEW_DIR := "res://assets/textury/builder/iso3d/"
const VIEW_TILE := 128.0
const VIEW_OF := {"cabin": "cabin_1"}
const FILE_OF := {
	"staffroom": "res://assets/textury/builder/iso_staffroom.png", "bowling": "res://assets/textury/builder/iso_bowling.png",
	"water_pump": "res://assets/textury/builder/sewer.PNG", "sewage_tank": "res://assets/textury/builder/sewer.PNG", "dumpsters": "res://assets/textury/builder/sewer.PNG",
}
const TREE_TEX := "res://assets/textury/builder/strom.png"
const BIRCH_TEX := "res://assets/textury/builder/iso_birch.png"
const CORN_TEX := "res://assets/textury/builder/iso_corn.png"
## How big on the plan: a tile's width in the pictures is this many cells, and nothing is
## narrower than MIN_CELLS (a tent has to read as a tent).
const SCALE_CELLS := 2.3
const MIN_CELLS := 1.9
const SMALL_TYPES := ["bench", "picnic_table", "flower_bed", "gnome", "hammock", "flagpole"]
const SMALL_CELLS := 1.2
## On the screen, of its width and of its height: the plates' column, the checklist.
const PLATES_W := 0.165
const CHECKLIST_H := 0.205

var _main: Node
var _canvas: Control
var _open := 0.0
var _paper_tex: Texture2D
var _cache_t := 0.0
var _data: Dictionary = {}
## Held open without the key: the bag while it is open, tools (shot driver).
var force_open := false
## type -> [picture, its point over the middle of the footprint, in its pixels].
var _icons: Dictionary = {}
## The pictures at the plan's size: "<path>@<width>" -> texture (they go from 150 px across
## to 30: scaled here once, not by the card each frame).
var _scaled: Dictionary = {}
var _drawn_open := -1.0
var _warm_left: Array = []
var _warmed := false


func setup(main_node: Node) -> void:
	_main = main_node


func _ready() -> void:
	layer = 95
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)
	visible = false
	_load_icons()


func _load_icons() -> void:
	var f := FileAccess.open(VIEW_DIR + "views.json", FileAccess.READ)
	var views = JSON.parse_string(f.get_as_text()) if f != null else null
	if views is Dictionary:
		for key in (views as Dictionary).keys():
			var k := str(key)
			if not k.ends_with("_0"):
				continue
			var a: Array = (views[key] as Dictionary).get("anchor", [0, 0])
			_icons[k.left(k.length() - 2)] = [VIEW_DIR + k + ".png", Vector2(float(a[0]), float(a[1]))]
	for t in FILE_OF.keys():
		if not _icons.has(t):
			_icons[t] = [str(FILE_OF[t]), Vector2.INF]


func _process(delta: float) -> void:
	var want := (Input.is_physical_key_pressed(KEY_TAB) or force_open) and _allowed()
	_open = move_toward(_open, 1.0 if want else 0.0, delta * 6.0)
	visible = _open > 0.0
	if not visible:
		_drawn_open = -1.0
		_warm()
		return
	_cache_t -= delta
	var fresh := _cache_t <= 0.0
	if fresh:
		_cache_t = 0.5
		_data = _collect()
	# (Lying still, it is drawn again only when what is on it can have changed.)
	if fresh or _open != _drawn_open:
		_drawn_open = _open
		_canvas.queue_redraw()


## The pictures made ready at the plan's size, one a frame, before the first TAB.
func _warm() -> void:
	if _warm_left.is_empty() and _warmed:
		return
	var grid = _main.get("grid_manager") if _main != null else null
	if grid == null or not bool(_main.get("_gameplay_started")):
		return
	var m := _measure(_canvas.size, int(grid.grid_width), int(grid.grid_height))
	var cell := float(m["cell"])
	if not _warmed:
		_warmed = true
		_warm_left = _icons.keys()
		_scaled_trees(cell)
		return
	_picture_rect(str(_warm_left.pop_back()), Vector2.ZERO, cell)


func _scaled_trees(cell: float) -> Array:
	return [_picture(TREE_TEX, int(maxf(5.0, cell * 0.8))), _picture(BIRCH_TEX, int(maxf(5.0, cell * 0.75)))]


func _allowed() -> bool:
	if _main == null:
		return false
	if bool(_main.get("_menu_mode")) or bool(_main.get("_game_over_active")):
		return false
	return not (_main.has_method("_is_any_interior_open") and _main._is_any_interior_open())


# ── what is on the plan ──────────────────────────────────────────────────────

func _collect() -> Dictionary:
	var state = CoreRoot.get_state()
	var grid = _main.get("grid_manager")
	if state == null or grid == null:
		return {}
	var w := int(grid.grid_width)
	var h := int(grid.grid_height)
	var lake: Array = []
	var trees: Array = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var tile = grid.get_tile(c)
			if tile == null:
				continue
			if int(tile.tile_type) == int(grid.TILE_LAKE):
				lake.append(c)
			elif tile.occupant != null and _is_tree(tile.occupant):
				trees.append(c)
	var buildings: Array = []
	var paths: Dictionary = {}
	var seen := {}
	for coord in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[coord]
		var t := str(cell.get("type", ""))
		if t == "path":
			paths[coord] = bool(cell.get("lamp", false))
			continue
		if t == "main_building" or t.begins_with("tree_"):
			continue
		var root: Vector2i = cell.get("root_coord", coord)
		var id := str(cell.get("id", "")) + str(root)
		if seen.has(id):
			continue
		seen[id] = true
		var fp := Vector2i.ONE
		var def = CoreRoot.registry.get_def(StringName(t)) if CoreRoot.registry != null else null
		if def != null:
			fp = def.footprint
		fp = cell.get("fp", fp)
		buildings.append({"type": t, "at": root, "fp": fp})
	# The reception has no builder cell; find it in the scene.
	var reception: Node = _main.find_child("MainBuilding", true, false)
	if reception != null and reception.has_meta("grid_origin"):
		buildings.append({"type": "main_building", "at": reception.get_meta("grid_origin"), "fp": reception.get_meta("grid_footprint", Vector2i(2, 2))})
	var rooms := {}
	for key in GuestManager.get_accommodation_states():
		var rs: Dictionary = GuestManager.get_room_state(str(key))
		if not rs.is_empty():
			rooms[str(key)] = rs
	var broken := {}
	for key in state.failures.keys():
		broken[str(key)] = true
	var jobs: Array = []
	var nj = _main.get("_night_jobs")
	if nj != null and nj.has_method("open_jobs"):
		jobs = nj.open_jobs()
	var waiting := 0
	var coming := 0
	for a in GuestManager.get_arrivals():
		if bool(a.get("at_gate", false)):
			waiting += int(a.get("party_size", 1))
		else:
			coming += int(a.get("party_size", 1))
	var todo: Array = []
	# (The checklist's step is beside the plan on the HUD's column, not on the sheet as well.)
	# The day's events and guests waiting to be served are circled like the night's jobs.
	var de = _main.get("_day_events")
	if de != null and de.has_method("open_events"):
		for ev in de.open_events():
			if bool(ev.get("gate", false)):
				var gc: Vector2i = _reception_coord() if str(ev.get("kind", "")) == "delivery" else GuestManager.get_gate_coord()
				ev["coord"] = [gc.x, gc.y]
			jobs.append(ev)
	var im = _main.get("_interior_manager")
	var biz = im.get("business") if im != null else null
	if biz != null and biz.has_method("waiting_sites"):
		for s in biz.waiting_sites():
			jobs.append({"kind": "serve", "coord": s["coord"], "title": LANG.f("%s: %d waiting for an order", [tr(str(s["title"])), int(s["n"])]), "where": "serve them at the counter"})
	for j in jobs:
		todo.append("%s - %s" % [tr(str(j.get("title", ""))), tr(str(j.get("where", "")))])
	return {"w": w, "h": h, "lake": lake, "trees": trees, "paths": paths, "buildings": buildings,
		"rooms": rooms, "broken": broken, "jobs": jobs, "waiting": waiting, "coming": coming,
		"gate": GuestManager.get_gate_coord(), "todo": todo, "corn_gate": _corn_gate_coord(grid),
		"title": _title()}


## The camp's own name on the sheet, once it has one.
func _title() -> String:
	var n: String = str(_main.call("camp_name")) if _main.has_method("camp_name") else ""
	return n.to_upper() if not n.is_empty() else "KEMP CERNE JEZERO"


## Grid row of the wicket gate into the corn (on the west fence), or (-1, -1).
func _corn_gate_coord(grid) -> Vector2i:
	if not _main.has_method("corn_gate_world"):
		return Vector2i(-1, -1)
	var p: Vector3 = _main.corn_gate_world()
	if p == Vector3.INF:
		return Vector2i(-1, -1)
	var c: Vector2i = grid.world_to_grid(p + Vector3(1.0, 0, 0))
	return Vector2i(0, c.y)


func _is_tree(n: Node) -> bool:
	var cur := n
	while cur != null:
		if cur.is_in_group("trees") or str(cur.get_meta("building_type", "")).begins_with("tree_"):
			return true
		cur = cur.get_parent()
	return false


# ── drawing ──────────────────────────────────────────────────────────────────

## Coloured pencil on the sheet: the camp inside its fence, the lake, the paths.
const WASH_CAMP := Color(0.60, 0.70, 0.38, 0.24)
const WASH_LAKE := Color(0.40, 0.58, 0.72, 0.82)
const WASH_PATH := Color(0.80, 0.70, 0.50)
const EDGE_PATH := Color(0.42, 0.32, 0.20)
const ROOM_TYPES := ["tent_1", "tent_2", "tent_3", "cabin", "cabin_1", "cabin_2", "cabin_3", "caravan_1", "caravan_2", "caravan_3"]


## Grid cell -> point on the sheet. The plan is drawn as you see the camp walking in
## through the gate: the gate at the bottom, the far fence at the top (and so left and
## right as they are in front of you).
func _to_sheet(o: Vector2, cell: float, c: Vector2, w: int, h: int) -> Vector2:
	return o + Vector2(float(w) - c.x, float(h) - c.y) * cell


func _cell_rect(o: Vector2, cell: float, at: Vector2i, fp: Vector2i, w: int, h: int) -> Rect2:
	var a := _to_sheet(o, cell, Vector2(at), w, h)
	var b := _to_sheet(o, cell, Vector2(at + fp), w, h)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())


## `path` at `width` pixels across, scaled once, smoothly.
func _picture(path: String, width: int) -> Texture2D:
	var key := "%s@%d" % [path, width]
	if _scaled.has(key):
		return _scaled[key]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var out: Texture2D = null
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			var used := img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0 and used != Rect2i(Vector2i.ZERO, img.get_size()):
				img = img.get_region(used)
			img.convert(Image.FORMAT_RGBA8)
			img.resize(maxi(1, width), maxi(1, int(round(float(img.get_height()) * float(width) / float(img.get_width())))), Image.INTERPOLATE_LANCZOS)
			out = ImageTexture.create_from_image(img)
	_scaled[key] = out
	return out


## Where a building's picture goes, standing on the middle of its footprint.
func _picture_rect(type: String, centre: Vector2, cell: float) -> Dictionary:
	var e: Array = _icons.get(str(VIEW_OF.get(type, type)), [])
	if e.is_empty():
		return {}
	var path := str(e[0])
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		return {}
	var used := tex.get_size()
	var k := cell * SCALE_CELLS / VIEW_TILE
	var least := cell * (SMALL_CELLS if type in SMALL_TYPES else MIN_CELLS)
	var w := maxf(used.x * k, least)
	var pic := _picture(path, int(round(w)))
	if pic == null:
		return {}
	var size := pic.get_size()
	var anchor: Vector2 = e[1]
	var at := centre - size * 0.5
	if anchor != Vector2.INF:
		at = centre - Vector2(anchor.x / used.x * size.x, anchor.y / used.y * size.y)
	return {"tex": pic, "rect": Rect2(at.floor(), size)}


func _write(font: Font, at: Vector2, text: String, fs: int, col: Color) -> void:
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_canvas.draw_string(font, at + d, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PAPER, 0.9))
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## The sheet's measures on this screen.
func _measure(screen: Vector2, w: int, h: int) -> Dictionary:
	var fs := maxi(14, int(screen.y * 0.02))
	# The checklist column (hud_manager.gd) comes up on the right with the plan: the sheet goes
	# in the space left of it. The bag (scripts/ui/inventory.gd) opens on the left with it.
	var hud = _main.get("_hud_manager") if _main != null else null
	var side: float = float(hud.side_column_px()) + 12.0 if hud != null and hud.has_method("side_column_px") else 0.0
	var bag = get_tree().get_first_node_in_group("inventory")
	var left: float = float(bag.reserve_left()) if bag != null else 0.0
	# With the bag open too the plan would be left a strip: the sheet goes under the checklist
	# instead, beside the plates below it (the checklist is wide, they are not).
	var top := 0.0
	if left > 0.0:
		side = minf(side, screen.x * PLATES_W)
		top = screen.y * CHECKLIST_H
	var avail_w := screen.x - side - left - 24.0
	var header := float(fs) * 3.2
	var pad := float(fs) * 1.5
	var col_w := clampf(screen.x * 0.1, float(fs) * 8.0, float(fs) * 12.0)
	var corn_gap := float(fs) * 2.6
	var cell := floorf((screen.y * 0.97 - top - header - pad) / float(h))
	cell = maxf(6.0, minf(cell, floorf((avail_w - col_w - corn_gap - pad * 2.0) / float(w))))
	return {"fs": fs, "side": side, "left": left, "top": top, "header": header, "pad": pad, "col_w": col_w, "corn_gap": corn_gap, "cell": cell}


func _draw_map() -> void:
	if _data.is_empty():
		return
	var screen := _canvas.size
	var k := ease(_open, 0.4)
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.5 * k))
	var w := int(_data["w"])
	var h := int(_data["h"])
	var font: Font = RETRO_UI.FONT_TEXT
	var title: Font = RETRO_UI.FONT_BIG
	var m := _measure(screen, w, h)
	var fs: int = m["fs"]
	var side: float = m["side"]
	var left: float = m["left"]
	var header: float = m["header"]
	var pad: float = m["pad"]
	var col_w: float = m["col_w"]
	var corn_gap: float = m["corn_gap"]
	var cell: float = m["cell"]
	var plan := Vector2(w, h) * cell
	var sheet := Vector2(pad + plan.x + corn_gap + col_w + pad, header + plan.y + pad)
	# Centred in what is left; never over the bag (out to the right instead, if it must).
	var ox := clampf(left + (screen.x - side - left - sheet.x) * 0.5, left, maxf(left, screen.x - sheet.x - 12.0))
	var origin := (Vector2(ox, maxf((screen.y - sheet.y) * 0.5, float(m["top"]))) + Vector2(0, (1.0 - k) * screen.y * 0.6)).floor()
	_draw_paper(Rect2(origin, sheet))
	var o := origin + Vector2(pad, header)
	# The sheet's head: the camp's name, as much of it as fits, the plan's date.
	var name_text := str(_data.get("title", ""))
	var ts := int(fs * 2.0)
	var sub := tr("site plan - V. 1996")
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while ts > fs and title.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x + sw + pad * 3.0 > sheet.x:
		ts -= 1
	_canvas.draw_string(title, origin + Vector2(pad, float(fs) * 2.3), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, PENCIL)
	_canvas.draw_string(font, origin + Vector2(sheet.x - pad - sw, float(fs) * 2.3), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL.lightened(0.3))

	# The ground inside the fence, the lake.
	_canvas.draw_rect(Rect2(o, plan), WASH_CAMP)
	_draw_lake(o, cell, w, h)
	# The woods: a small tree on each of theirs, drawn from the far fence forward.
	var trees: Array = (_data["trees"] as Array).duplicate()
	trees.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	var both := _scaled_trees(cell)
	var spruce: Texture2D = both[0]
	var birch: Texture2D = both[1]
	for c in trees:
		var p := _to_sheet(o, cell, Vector2(c) + Vector2(0.5, 0.75), w, h)
		var t: Texture2D = birch if (c.x * 7 + c.y * 3) % 5 == 0 else spruce
		if t != null:
			var sz := t.get_size()
			_canvas.draw_texture_rect(t, Rect2((p - Vector2(sz.x * 0.5, sz.y)).floor(), sz), false, Color(1.0, 1.0, 0.92, 0.48))
	_dashed_rect(Rect2(o, plan), PENCIL, 2.0)

	# Paths, then lamps on them.
	var paths: Dictionary = _data["paths"]
	var pw := maxf(4.0, cell * 0.42)
	for pass_n in 2:
		var col: Color = EDGE_PATH if pass_n == 0 else WASH_PATH
		var wide: float = pw + (2.0 if pass_n == 0 else 0.0)
		for c in paths.keys():
			var p := _to_sheet(o, cell, Vector2(c) + Vector2(0.5, 0.5), w, h)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if paths.has(c + d):
					_canvas.draw_line(p, _to_sheet(o, cell, Vector2(c + d) + Vector2(0.5, 0.5), w, h), col, wide)
			_canvas.draw_circle(p, wide * 0.5, col)
	for c in paths.keys():
		if bool(paths[c]):
			var p := _to_sheet(o, cell, Vector2(c) + Vector2(0.5, 0.5), w, h)
			_canvas.draw_circle(p + Vector2(cell * 0.3, -cell * 0.3), maxf(2.0, cell * 0.12), INK_AMBER)

	# Everything that stands in the camp: its picture, drawn from the far fence forward.
	var rooms: Dictionary = _data["rooms"]
	var broken: Dictionary = _data["broken"]
	var order: Array = (_data["buildings"] as Array).duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["at"] as Vector2i).y > (b["at"] as Vector2i).y)
	var labels: Array = []
	var tags: Array = []
	var taken: Array = []
	for b in order:
		var t := str(b["type"])
		var at: Vector2i = b["at"]
		var fp: Vector2i = b["fp"]
		var r := _cell_rect(o, cell, at, fp, w, h)
		if t == "lamp_post":
			_canvas.draw_circle(r.get_center(), maxf(2.0, cell * 0.12), INK_AMBER)
			continue
		var key := "%d:%d" % [at.x, at.y]
		var drawn := _picture_rect(t, r.get_center(), cell)
		var box := r
		if drawn.is_empty():
			# (Nothing drawn of it yet: pencil, not a coloured block.)
			_canvas.draw_rect(r.grow(-1.0), Color(PAPER, 0.8))
			_canvas.draw_rect(r.grow(-1.0), PENCIL, false, 1.0)
		else:
			box = drawn["rect"]
			_canvas.draw_texture_rect(drawn["tex"], box, false, Color(1.0, 0.98, 0.92))
		taken.append(box)
		var is_broken := broken.has(key)
		if t in ROOM_TYPES and GuestManager != null and GuestManager.room_number(key) > 0:
			tags.append([str(GuestManager.room_number(key)), box, _room_colour(rooms.get(key, {})), is_broken])
		elif is_broken:
			labels.append([tr("BROKEN"), box, INK_RED])
		elif NAMES.has(t):
			labels.append([tr(str(NAMES[t])), box, PENCIL])
		if is_broken:
			_cross(box.grow(-box.size.x * 0.18))

	# A lodging's number on its tag, in the colour of its state.
	var th := float(fs) + 3.0
	for e in tags:
		var r: Rect2 = e[1]
		var tw := maxf(th, font.get_string_size(str(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 7.0)
		var tag := Rect2(Vector2(r.end.x - tw * 0.75, r.position.y + r.size.y * 0.5 - th).floor(), Vector2(tw, th))
		_canvas.draw_rect(Rect2(tag.position + Vector2(1, 2), tag.size), Color(0, 0, 0, 0.3))
		_canvas.draw_rect(tag, e[2])
		_canvas.draw_rect(tag, INK_RED if bool(e[3]) else PENCIL, false, 2.0 if bool(e[3]) else 1.0)
		var nw := font.get_string_size(str(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_canvas.draw_string(font, tag.position + Vector2((tag.size.x - nw) * 0.5, float(fs) + 0.5), str(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
		taken.append(tag)

	# Names under their pictures, else over, right or left of them, wherever they do not cover
	# another name; left out if nowhere fits.
	var placed: Array = []
	var gate_at := _to_sheet(o, cell, Vector2(_data["gate"]), w, h)
	placed.append(Rect2(gate_at - Vector2(cell * 4, 0), Vector2(cell * 8, float(fs) * 1.6)))
	for e in tags:
		placed.append(Rect2((e[1] as Rect2).end - Vector2((e[1] as Rect2).size.x * 0.3, (e[1] as Rect2).size.y * 0.5 + th), Vector2(th * 1.6, th)))
	for entry in labels:
		var label: String = entry[0]
		var r: Rect2 = entry[1]
		var size := Vector2(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 4.0, float(fs) + 2.0)
		var cands := [Vector2(r.get_center().x - size.x * 0.5, r.end.y - 1.0), Vector2(r.get_center().x - size.x * 0.5, r.position.y - size.y),
				Vector2(r.end.x + 1.0, r.get_center().y - size.y * 0.5), Vector2(r.position.x - size.x - 1.0, r.get_center().y - size.y * 0.5)]
		# Clear of the other pictures if it can be, else only of the other names.
		var spot := Rect2()
		for over_pictures in [false, true]:
			for cand in cands:
				var box := Rect2(cand, size)
				if not Rect2(o, plan).encloses(box) or placed.any(func(t: Rect2): return t.intersects(box)):
					continue
				if not over_pictures and taken.any(func(t: Rect2): return t != r and t.intersects(box)):
					continue
				spot = box
				break
			if spot.size != Vector2.ZERO:
				break
		if spot.size != Vector2.ZERO:
			placed.append(spot)
			_write(font, spot.position + Vector2(2.0, float(fs)), label, fs, entry[2])

	# The wicket gate into the corn: a gap in the west fence and the field beyond it
	# (in the margin: the plan is seen from the gate, so west is on the right).
	var cg: Vector2i = _data.get("corn_gate", Vector2i(-1, -1))
	var corn_p := Vector2.INF
	if cg.x >= 0:
		var gp := _to_sheet(o, cell, Vector2(0.0, float(cg.y) + 0.5), w, h)
		_canvas.draw_line(gp - Vector2(0, cell * 0.5), gp + Vector2(0, cell * 0.5), PAPER, 5.0)
		var corn := _picture(CORN_TEX, int(corn_gap * 0.62))
		if corn != null:
			var cs := corn.get_size()
			for i in 3:
				_canvas.draw_texture_rect(corn, Rect2((gp + Vector2(5.0 + float(i % 2) * cs.x * 0.45, (float(i) - 1.0) * cs.y * 0.62 - cs.y * 0.5)).floor(), cs), false, Color(1.0, 0.98, 0.9))
		var cw := font.get_string_size(tr("CORN"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_write(font, gp + Vector2(-cw - 5.0, cell * 0.9 + float(fs)), tr("CORN"), fs, PENCIL)
		corn_p = gp + Vector2(corn_gap * 0.34, 0)

	# What needs you (tonight's jobs, the day's events, guests waiting at a counter):
	# circled in red (the corn job round its gate).
	for j in _data["jobs"]:
		var jc: Array = j.get("coord", [-1, -1])
		if str(j.get("kind", "")) == "corn" and corn_p != Vector2.INF:
			_ring(corn_p, cell * 1.6)
			continue
		if int(jc[0]) < 0:
			continue
		_ring(_to_sheet(o, cell, Vector2(int(jc[0]), int(jc[1])) + Vector2(0.5, 0.5), w, h), cell * 1.5)

	# The gate, at the bottom, and who is waiting there.
	var g: Vector2i = _data["gate"]
	var gp2 := _to_sheet(o, cell, Vector2(g) + Vector2(0.5, 0.0), w, h)
	_canvas.draw_line(gp2 - Vector2(cell, 0), gp2 + Vector2(cell, 0), PAPER, 5.0)
	_canvas.draw_line(gp2 - Vector2(cell, 0), gp2 + Vector2(cell, 0), INK_RED, 2.0)
	var gl := tr("GATE") if int(_data["waiting"]) == 0 else LANG.f("GATE - %d AT RECEPTION", int(_data["waiting"]))
	var gw := font.get_string_size(gl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_write(font, gp2 + Vector2(-gw * 0.5, float(fs) + 3.0), gl, fs, INK_RED if int(_data["waiting"]) > 0 else PENCIL)

	# Beside the plan: what needs you, and the key to the tags.
	var cx := o.x + plan.x + corn_gap
	var y := o.y + float(fs)
	var lines: Array = []
	for line in _data["todo"]:
		lines.append(str(line))
	if int(_data["coming"]) > 0:
		lines.append(LANG.f("%d more on the road", int(_data["coming"])))
	var legend_h := float(fs) * 1.5 * 4.0
	var bottom := o.y + plan.y - legend_h - float(fs)
	for line in lines:
		var wrapped: Array = _wrap("- " + line, col_w, font, fs)
		if y + float(fs) * 1.25 * float(wrapped.size()) > bottom:
			break
		for part in wrapped:
			_canvas.draw_string(font, Vector2(cx, y), str(part), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
			y += float(fs) * 1.25
		y += float(fs) * 0.5
	var ly := o.y + plan.y - legend_h + float(fs)
	for row in [[ROOM_READY, "ready"], [ROOM_DIRTY, "dirty"], [ROOM_UNMADE, "not made up"], [ROOM_TAKEN, "guests in"]]:
		var box := Rect2(cx, ly - float(fs) * 0.85, float(fs) * 1.05, float(fs) * 1.05)
		_canvas.draw_rect(box, row[0])
		_canvas.draw_rect(box, PENCIL, false, 1.0)
		_canvas.draw_string(font, Vector2(cx + float(fs) * 1.5, ly), tr(str(row[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
		ly += float(fs) * 1.5


const ROOM_READY := Color(0.56, 0.78, 0.46)
const ROOM_DIRTY := Color(0.86, 0.42, 0.34)
const ROOM_UNMADE := Color(0.92, 0.72, 0.34)
const ROOM_TAKEN := Color(0.50, 0.62, 0.86)


func _room_colour(rs: Dictionary) -> Color:
	if rs.is_empty():
		return ROOM_UNMADE
	if bool(rs.get("occupied", false)):
		return ROOM_TAKEN
	var st := str(rs.get("status", ""))
	if st == ROOM_RULES.STATUS_DIRTY:
		return ROOM_DIRTY
	if st == ROOM_RULES.STATUS_UNPREPARED:
		return ROOM_UNMADE
	return ROOM_READY


## The lake across the top of the plan, its shore a pencil line that wanders a little, a few
## ripples on it.
func _draw_lake(o: Vector2, cell: float, w: int, h: int) -> void:
	var shore := {}
	for c in _data["lake"]:
		var p := _to_sheet(o, cell, Vector2(c), w, h)
		shore[c.x] = maxf(float(shore.get(c.x, -INF)), p.y)
	if shore.is_empty():
		return
	var pts := PackedVector2Array()
	var xs: Array = shore.keys()
	xs.sort()
	xs.reverse()
	for x in xs:
		var px := _to_sheet(o, cell, Vector2(float(x) + 1.0, 0.0), w, h).x
		for i in 3:
			var at := px + cell * float(i) / 3.0
			pts.append(Vector2(at, float(shore[x]) + sin(at * 0.11) * cell * 0.22 + sin(at * 0.031) * cell * 0.3))
	var poly := PackedVector2Array([Vector2(pts[0].x, o.y)])
	poly.append_array(pts)
	poly.append(Vector2(pts[pts.size() - 1].x, o.y))
	_canvas.draw_colored_polygon(poly, WASH_LAKE)
	_canvas.draw_polyline(pts, WASH_LAKE.darkened(0.45), 1.5)
	var top := float(shore[xs[0]]) - o.y
	var i := 0
	var x := o.x + cell
	while x < o.x + float(w) * cell - cell:
		var y := o.y + top * (0.3 + 0.25 * float(i % 3))
		_canvas.draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + cell * 0.3, y - cell * 0.14), Vector2(x + cell * 0.6, y), Vector2(x + cell * 0.9, y - cell * 0.14)]), WASH_LAKE.darkened(0.3), 1.0)
		x += cell * 3.3
		i += 1


## A red pencil's circle, gone round twice.
func _ring(at: Vector2, r: float) -> void:
	_canvas.draw_arc(at, r, 0.3, TAU + 0.5, 30, INK_RED, 2.0)
	_canvas.draw_arc(at + Vector2(1.0, -1.0), r * 1.06, 2.0, TAU + 2.6, 30, INK_RED, 1.5)


## A red pencil's cross.
func _cross(r: Rect2) -> void:
	_canvas.draw_line(r.position, r.end, INK_RED, 3.0)
	_canvas.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), INK_RED, 3.0)


func _draw_paper(r: Rect2) -> void:
	_canvas.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.35))
	if _paper_tex == null and ResourceLoader.exists(PAPER_TEX):
		_paper_tex = load(PAPER_TEX)
	if _paper_tex != null:
		_canvas.draw_texture_rect(_paper_tex, r, false)
	else:
		_canvas.draw_rect(r, PAPER)


func _dashed_rect(r: Rect2, col: Color, width: float) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 10.0)
		for k in n:
			if k % 2 == 0:
				_canvas.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, width)


func _wrap(text: String, width: float, font: Font, fs: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var cand := word if line.is_empty() else line + " " + word
		if font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = cand
	if not line.is_empty():
		out.append(line)
	return out


## Where the van's driver is going (the gate when there is no reception).
static func _reception_coord() -> Vector2i:
	var state = CoreRoot.get_state()
	if state != null:
		for coord in state.grid.cells.keys():
			var cell: Dictionary = state.grid.cells[coord]
			if str(cell.get("type", "")) == "main_building" and cell.get("root_coord", coord) == coord:
				return coord
	return GuestManager.get_gate_coord()
