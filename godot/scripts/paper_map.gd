extends CanvasLayer

## Hold TAB: Vera's site plan, coloured pencil on paper, drawn as you see the camp from
## the gate (gate at the bottom). It does NOT show where you are. It shows what needs
## you: rooms coloured by state (ready, dirty, not made up, guests in), broken buildings
## stamped, tonight's jobs circled in red, who waits at the gate, and three lines of
## what to do next.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const ROOM_RULES = preload("res://core/systems/room_rules.gd")

const PAPER := Color(0.86, 0.80, 0.64)
const PENCIL := Color(0.22, 0.20, 0.22)
const INK_RED := Color(0.70, 0.10, 0.08)
const INK_GREEN := Color(0.10, 0.45, 0.12)
const INK_BLUE := Color(0.12, 0.22, 0.60)
const INK_AMBER := Color(0.70, 0.45, 0.05)

## Short names written on the plan.
const NAMES := {
	"main_building": "OFFICE", "tent_1": "TENT", "tent_2": "TENT", "tent_3": "TENT",
	"cabin": "CABIN", "cabin_1": "CABIN", "cabin_2": "CABIN", "cabin_3": "CABIN", "caravan_1": "CARAVAN", "caravan_2": "CARAVAN", "caravan_3": "CARAVAN",
	"toilet_block": "WC", "shower_block": "SHOWERS", "pub": "PUB", "restaurant": "BISTRO",
	"vecerka": "SHOP", "bonfire": "FIRE", "sports_field": "PITCH", "lake_slide": "SLIDE", "playground": "SWINGS", "ping_pong": "PING-PONG", "hammock": "HAMMOCK", "corn_stand": "CORN",
	"bench": "BENCH", "picnic_table": "PICNIC", "flower_bed": "FLOWERS", "gnome": "GNOME", "flagpole": "FLAG",
	"sewer": "SEWER", "power_generator": "GENERATOR", "lamp_post": "", "path": "",
	"water_pump": "PUMP", "sewage_tank": "TANK", "dumpsters": "BINS",
}

var _main: Node
var _canvas: Control
var _open := 0.0
var _paper_tex: Texture2D
var _cache_t := 0.0
var _data: Dictionary = {}
## Tools (shot driver): hold the map open without the key.
var force_open := false


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


func _process(delta: float) -> void:
	var want := (Input.is_physical_key_pressed(KEY_TAB) or force_open) and _allowed()
	_open = move_toward(_open, 1.0 if want else 0.0, delta * 6.0)
	visible = _open > 0.0
	if not visible:
		return
	_cache_t -= delta
	if _cache_t <= 0.0:
		_cache_t = 0.5
		_data = _collect()
	_canvas.queue_redraw()


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
		if t == "main_building":
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
	var hud = _main.get("_hud_manager")
	var objective := str(hud.get("_objective_text").text) if hud != null and hud.get("_objective_text") != null else ""
	if not objective.is_empty():
		todo.append(objective)
	for j in jobs:
		todo.append("%s - %s" % [j.get("title", ""), j.get("where", "")])
	return {"w": w, "h": h, "lake": lake, "trees": trees, "paths": paths, "buildings": buildings,
		"rooms": rooms, "broken": broken, "jobs": jobs, "waiting": waiting, "coming": coming,
		"gate": GuestManager.get_gate_coord(), "todo": todo, "corn_gate": _corn_gate_coord(grid)}


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
		if cur.is_in_group("trees"):
			return true
		cur = cur.get_parent()
	return false


# ── drawing ──────────────────────────────────────────────────────────────────

## Category colours on the plan (soft washes, like coloured pencil).
const WASH_GRASS := Color(0.70, 0.76, 0.52)
const WASH_WOOD := Color(0.48, 0.60, 0.38, 0.45)
const WASH_LAKE := Color(0.46, 0.62, 0.74)
const WASH_PATH := Color(0.55, 0.40, 0.24)
const WASH_FACILITY := Color(0.90, 0.88, 0.80)
const WASH_UTILITY := Color(0.62, 0.62, 0.60)
const WASH_FUN := Color(0.64, 0.80, 0.50)
const WASH_OFFICE := Color(0.66, 0.46, 0.32)
const ROOM_TYPES := ["tent_1", "tent_2", "tent_3", "cabin", "cabin_1", "cabin_2", "cabin_3", "caravan_1", "caravan_2", "caravan_3"]
const UTILITY_TYPES := ["power_generator", "sewer", "water_pump", "sewage_tank", "dumpsters"]
const FUN_TYPES := ["bonfire", "sports_field", "lake_slide", "playground", "ping_pong", "hammock", "bench", "picnic_table", "flower_bed", "gnome", "flagpole"]


## Grid cell -> point on the sheet. The plan is drawn as you see the camp walking in
## through the gate: the gate at the bottom, the far fence at the top (and so left and
## right as they are in front of you).
func _to_sheet(o: Vector2, cell: float, c: Vector2, w: int, h: int) -> Vector2:
	return o + Vector2(float(w) - c.x, float(h) - c.y) * cell


func _cell_rect(o: Vector2, cell: float, at: Vector2i, fp: Vector2i, w: int, h: int) -> Rect2:
	var a := _to_sheet(o, cell, Vector2(at), w, h)
	var b := _to_sheet(o, cell, Vector2(at + fp), w, h)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())


func _draw_map() -> void:
	if _data.is_empty():
		return
	var screen := _canvas.size
	var k := ease(_open, 0.4)
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.5 * k))
	var w := int(_data["w"])
	var h := int(_data["h"])
	var fs := maxi(14, int(screen.y * 0.02))
	var font: Font = RETRO_UI.FONT_TEXT
	var title: Font = RETRO_UI.FONT_BIG
	var footer := fs * 6.5
	var header := fs * 3.6
	# The checklist column (hud_manager.gd) comes up on the right with the plan: the
	# sheet goes in the space left of it.
	var hud = _main.get("_hud_manager") if _main != null else null
	var side: float = float(hud.side_column_px()) + 12.0 if hud != null and hud.has_method("side_column_px") else 0.0
	var avail_w := screen.x - side - 24.0
	var cell := floorf((screen.y * 0.9 - header - footer - 40.0) / float(h))
	cell = minf(cell, floorf((avail_w - 64.0 - fs * 3.0) / float(w)))
	var plan := Vector2(w, h) * cell
	var sheet := Vector2(plan.x + 64.0 + fs * 3.0, plan.y + header + footer + 40.0)
	var origin := (Vector2((screen.x - side - sheet.x) * 0.5, (screen.y - sheet.y) * 0.5) + Vector2(0, (1.0 - k) * screen.y * 0.6)).floor()
	_draw_paper(Rect2(origin, sheet))
	var o := origin + Vector2(32, header + 12.0)
	_canvas.draw_string(title, origin + Vector2(32, fs * 2.2), "KEMP CERNE JEZERO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 1.8), PENCIL)
	var sub := "site plan - V. 1996"
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_canvas.draw_string(font, origin + Vector2(sheet.x - 32 - sw, fs * 2.2), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL.lightened(0.35))

	# The ground inside the fence, the woods, the lake.
	_canvas.draw_rect(Rect2(o, plan), WASH_GRASS)
	for c in _data["trees"]:
		var p := _to_sheet(o, cell, Vector2(c) + Vector2(0.5, 0.5), w, h)
		_canvas.draw_circle(p, cell * 0.5, WASH_WOOD)
	for c in _data["lake"]:
		_canvas.draw_rect(_cell_rect(o, cell, c, Vector2i.ONE, w, h).grow(0.5), WASH_LAKE)
	for c in _data["lake"]:
		if (c.x + c.y * 3) % 4 == 0:
			var p := _to_sheet(o, cell, Vector2(c) + Vector2(0.5, 0.5), w, h)
			_canvas.draw_polyline(PackedVector2Array([p + Vector2(-cell * 0.3, 0), p + Vector2(-cell * 0.1, -cell * 0.12), p + Vector2(cell * 0.1, 0), p + Vector2(cell * 0.3, -cell * 0.12)]), WASH_LAKE.darkened(0.3), 1.5)
	_dashed_rect(Rect2(o, plan), PENCIL, 2.0)

	# Paths, then lamps on them.
	var paths: Dictionary = _data["paths"]
	var pw := maxf(3.0, cell * 0.34)
	for c in paths.keys():
		var p := _to_sheet(o, cell, Vector2(c) + Vector2(0.5, 0.5), w, h)
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if paths.has(c + d):
				_canvas.draw_line(p, _to_sheet(o, cell, Vector2(c + d) + Vector2(0.5, 0.5), w, h), WASH_PATH, pw)
		_canvas.draw_circle(p, pw * 0.5, WASH_PATH)
	for c in paths.keys():
		if bool(paths[c]):
			var p := _to_sheet(o, cell, Vector2(c) + Vector2(0.5, 0.5), w, h)
			_canvas.draw_circle(p + Vector2(cell * 0.28, -cell * 0.28), maxf(2.5, cell * 0.13), INK_AMBER)

	# Buildings: a filled block per building, rooms coloured by what they need.
	var rooms: Dictionary = _data["rooms"]
	var broken: Dictionary = _data["broken"]
	var labels: Array = []
	for b in _data["buildings"]:
		var t := str(b["type"])
		var at: Vector2i = b["at"]
		var r := _cell_rect(o, cell, at, b["fp"], w, h).grow(-2.0)
		if t == "lamp_post":
			_canvas.draw_circle(r.get_center(), maxf(2.5, cell * 0.13), INK_AMBER)
			continue
		var key := "%d:%d" % [at.x, at.y]
		var fill := WASH_FACILITY
		if t in ROOM_TYPES:
			fill = _room_colour(rooms.get(key, {}))
		elif t in UTILITY_TYPES:
			fill = WASH_UTILITY
		elif t in FUN_TYPES:
			fill = WASH_FUN
		elif t == "main_building":
			fill = WASH_OFFICE
		_canvas.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.18))
		_canvas.draw_rect(r, fill)
		_canvas.draw_rect(r, PENCIL, false, 2.0)
		var label := str(NAMES.get(t, t.to_upper()))
		# Lodgings by their number: TENT 1, CABIN 2, CARAVAN 1 (the keys say T1, C2, V1).
		if t in ROOM_TYPES and GuestManager != null and GuestManager.room_number(key) > 0:
			label = GuestManager.room_label(key).to_upper()
		if label != "":
			labels.append([label, r])
		if broken.has(key):
			_stamp(r, "BROKEN", INK_RED, fs)

	# Names: inside the block if they fit, else below, above, right or left of it,
	# wherever they do not cover another name or building; left out if nowhere fits.
	var taken: Array = []
	for b in _data["buildings"]:
		taken.append(_cell_rect(o, cell, b["at"], b["fp"], w, h))
	var gate_rect := Rect2(_to_sheet(o, cell, Vector2(_data["gate"]), w, h) - Vector2(cell * 4, 0), Vector2(cell * 8, fs * 1.6))
	taken.append(gate_rect)
	for entry in labels:
		var label: String = entry[0]
		var r: Rect2 = entry[1]
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var size := Vector2(lw + 6, fs + 3)
		var spot := Rect2()
		if r.size.x >= size.x + 2 and r.size.y >= fs * 1.6:
			spot = Rect2(r.get_center() - size * 0.5, size)
		else:
			for cand in [Vector2(r.get_center().x - size.x * 0.5, r.end.y + 2), Vector2(r.get_center().x - size.x * 0.5, r.position.y - size.y - 2),
					Vector2(r.end.x + 3, r.get_center().y - size.y * 0.5), Vector2(r.position.x - size.x - 3, r.get_center().y - size.y * 0.5)]:
				var box := Rect2(cand, size)
				if not Rect2(o, plan).encloses(box):
					continue
				if taken.any(func(t: Rect2): return t.intersects(box) and t != r):
					continue
				spot = box
				break
			if spot.size == Vector2.ZERO:
				continue
			_canvas.draw_rect(spot, Color(PAPER, 0.8))
		taken.append(spot)
		_canvas.draw_string(font, spot.position + Vector2(3, fs), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)

	# The wicket gate into the corn: a gap in the west fence and the field beyond it
	# (drawn in the margin: the plan is seen from the gate, so west is on the right).
	var cg: Vector2i = _data.get("corn_gate", Vector2i(-1, -1))
	var corn_p := Vector2.INF
	if cg.x >= 0:
		var gp := _to_sheet(o, cell, Vector2(0.0, float(cg.y) + 0.5), w, h)
		_canvas.draw_line(gp - Vector2(0, cell * 0.5), gp + Vector2(0, cell * 0.5), Color(0.88, 0.84, 0.70), 5.0)
		for i in 5:
			var y := gp.y - cell * 2.0 + i * cell
			_canvas.draw_line(Vector2(gp.x + 6, y), Vector2(gp.x + 6 + cell * 0.5, y - cell * 0.6), Color(0.62, 0.55, 0.22), 2.0)
		_canvas.draw_string(font, gp + Vector2(6, cell * 2.2 + fs), "CORN", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
		corn_p = gp + Vector2(cell * 0.6, 0)

	# Tonight's jobs: circled in red (the corn job round its gate).
	for j in _data["jobs"]:
		var jc: Array = j.get("coord", [-1, -1])
		if str(j.get("kind", "")) == "corn" and corn_p != Vector2.INF:
			_canvas.draw_arc(corn_p, cell * 1.3, 0, TAU, 28, INK_RED, 3.0)
			continue
		if int(jc[0]) < 0:
			continue
		var p := _to_sheet(o, cell, Vector2(int(jc[0]), int(jc[1])) + Vector2(0.5, 0.5), w, h)
		_canvas.draw_arc(p, cell * 1.0, 0, TAU, 28, INK_RED, 3.0)

	# The gate, at the bottom, and who is waiting there.
	var g: Vector2i = _data["gate"]
	var gp := _to_sheet(o, cell, Vector2(g) + Vector2(0.5, 0.0), w, h)
	_canvas.draw_line(gp - Vector2(cell, 0), gp + Vector2(cell, 0), Color(0.88, 0.84, 0.70), 5.0)
	_canvas.draw_line(gp - Vector2(cell, 0), gp + Vector2(cell, 0), INK_RED, 2.0)
	var gl := "GATE" if int(_data["waiting"]) == 0 else "GATE - %d AT RECEPTION" % int(_data["waiting"])
	var gw := font.get_string_size(gl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_canvas.draw_string(font, gp + Vector2(-gw * 0.5, fs + 6), gl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK_RED if int(_data["waiting"]) > 0 else PENCIL)

	# Underneath: what needs you (three lines at most), and the key to the colours.
	var y := o.y + plan.y + fs * 2.8
	var lines: Array = []
	for line in _data["todo"]:
		lines.append(str(line))
	if int(_data["coming"]) > 0:
		lines.append("%d more on the road" % int(_data["coming"]))
	for line in lines.slice(0, 3):
		var wrapped: Array = _wrap("- " + line, plan.x, font, fs)
		_canvas.draw_string(font, Vector2(o.x, y), str(wrapped[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
		y += fs * 1.3
	var lx := o.x
	var ly2 := origin.y + sheet.y - 18.0
	for row in [[ROOM_READY, "ready"], [ROOM_DIRTY, "dirty"], [ROOM_UNMADE, "not made up"], [ROOM_TAKEN, "guests in"]]:
		_canvas.draw_rect(Rect2(lx, ly2 - fs * 0.8, fs * 0.9, fs * 0.9), row[0])
		_canvas.draw_rect(Rect2(lx, ly2 - fs * 0.8, fs * 0.9, fs * 0.9), PENCIL, false, 1.0)
		_canvas.draw_string(font, Vector2(lx + fs * 1.3, ly2), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
		lx += fs * 1.3 + font.get_string_size(str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 1.4


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


func _stamp(r: Rect2, text: String, col: Color, fs: int) -> void:
	var w := RETRO_UI.FONT_TEXT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(r.get_center() - Vector2(w * 0.5 + 4, fs * 0.7), Vector2(w + 8, fs * 1.4))
	_canvas.draw_rect(box, col, false, 2.0)
	_canvas.draw_string(RETRO_UI.FONT_TEXT, box.position + Vector2(4, fs * 1.05), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_paper(r: Rect2) -> void:
	_canvas.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.35))
	if _paper_tex == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1996
		for y in 128:
			for x in 128:
				img.set_pixel(x, y, PAPER.darkened(rng.randf_range(0.0, 0.07)))
		_paper_tex = ImageTexture.create_from_image(img)
	_canvas.draw_texture_rect(_paper_tex, r, true)


func _dashed_rect(r: Rect2, col: Color, width: float) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 10.0)
		for k in n:
			if k % 2 == 0:
				_canvas.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, width)


func _hatch(r: Rect2, col: Color) -> void:
	var step := maxf(4.0, r.size.x / 4.0)
	var t := 0.0
	while t < r.size.x * 2.0:
		var a := r.position + Vector2(minf(t, r.size.x), maxf(0.0, t - r.size.x))
		var b := r.position + Vector2(maxf(0.0, t - r.size.y), minf(t, r.size.y))
		_canvas.draw_line(a, b, col, 1.0)
		t += step


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
