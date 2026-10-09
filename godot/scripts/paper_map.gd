extends CanvasLayer

## Hold TAB: Vera's site plan, a folded sheet of paper with the camp drawn in pencil.
## It does NOT show where you are (you have to know the camp). It shows what needs you:
## every room with a sticker (made up, dirty, not made up yet, occupied), broken
## buildings in red, tonight's jobs circled, who is waiting at the barrier, and the
## to-do list in the margin.

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
	"cabin": "CABIN", "cabin_1": "CABIN", "cabin_2": "CABIN", "cabin_3": "CABIN", "caravan_1": "CARAVAN",
	"toilet_block": "WC", "shower_block": "SHOWERS", "pub": "PUB", "restaurant": "BISTRO",
	"vecerka": "SHOP", "bonfire": "FIRE", "sports_field": "PITCH", "lake_slide": "SLIDE",
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
		"gate": GuestManager.get_gate_coord(), "todo": todo}


func _is_tree(n: Node) -> bool:
	var cur := n
	while cur != null:
		if cur.is_in_group("trees"):
			return true
		cur = cur.get_parent()
	return false


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw_map() -> void:
	if _data.is_empty():
		return
	var screen := _canvas.size
	var k := ease(_open, 0.4)
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.45 * k))
	var w := int(_data["w"])
	var h := int(_data["h"])
	var sheet_h := screen.y * 0.86
	var cell := floorf((sheet_h - 120.0) / float(h))
	var plan := Vector2(w, h) * cell
	var margin_w := maxf(220.0, screen.x * 0.18)
	var sheet := Vector2(plan.x + margin_w + 90.0, plan.y + 110.0)
	var origin := ((screen - sheet) * 0.5 + Vector2(0, (1.0 - k) * screen.y * 0.6)).floor()
	_draw_paper(Rect2(origin, sheet))
	var o := origin + Vector2(40, 74)
	var fs := maxi(12, int(cell * 0.42))
	var font: Font = RETRO_UI.FONT_TEXT
	var title: Font = RETRO_UI.FONT_BIG
	_canvas.draw_string(title, origin + Vector2(40, 46), "KEMP CERNE JEZERO - site plan", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 1.9), PENCIL)
	_canvas.draw_string(font, origin + Vector2(40, 64), "drawn by V., 1996. keep in the office. (not to scale)", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL.lightened(0.3))
	# Fence: a dashed rectangle around the camp.
	_dashed_rect(Rect2(o, plan), PENCIL, 2.0)
	for c in _data["lake"]:
		_hatch(Rect2(o + Vector2(c) * cell, Vector2(cell, cell)), INK_BLUE.lightened(0.25))
	for c in _data["trees"]:
		var p: Vector2 = o + (Vector2(c) + Vector2(0.5, 0.6)) * cell
		var r := cell * 0.22
		if (c.x * 7 + c.y * 3) % 3 == 0:
			_canvas.draw_polyline(PackedVector2Array([p + Vector2(-r, r * 0.6), p + Vector2(0, -r), p + Vector2(r, r * 0.6)]), PENCIL.lightened(0.55), 1.0)
	var paths: Dictionary = _data["paths"]
	for c in paths.keys():
		var p: Vector2 = o + (Vector2(c) + Vector2(0.5, 0.5)) * cell
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if paths.has(c + d):
				_canvas.draw_line(p, p + Vector2(d) * cell, Color(0.45, 0.32, 0.18), maxf(2.0, cell * 0.16))
		_canvas.draw_circle(p, maxf(1.5, cell * 0.08), Color(0.45, 0.32, 0.18))
		if bool(paths[c]):
			_canvas.draw_circle(p + Vector2(cell * 0.3, -cell * 0.3), maxf(2.0, cell * 0.1), INK_AMBER)
	var rooms: Dictionary = _data["rooms"]
	var broken: Dictionary = _data["broken"]
	for b in _data["buildings"]:
		var t := str(b["type"])
		var at: Vector2i = b["at"]
		var r := Rect2(o + Vector2(at) * cell + Vector2(2, 2), Vector2(b["fp"]) * cell - Vector2(4, 4))
		if t == "lamp_post":
			_canvas.draw_circle(r.get_center(), maxf(2.0, cell * 0.12), INK_AMBER)
			continue
		_canvas.draw_rect(r, PAPER.darkened(0.06))
		_canvas.draw_rect(r, PENCIL, false, 1.5)
		var label := str(NAMES.get(t, t.to_upper()))
		# Written under the building, like on a hand-drawn plan.
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_canvas.draw_string(font, Vector2(r.get_center().x - lw * 0.5, r.end.y + fs + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
		var key := "%d:%d" % [at.x, at.y]
		if rooms.has(key):
			_room_sticker(r, rooms[key], fs)
		if broken.has(key):
			_stamp(r, "BROKEN", INK_RED, fs)
	for j in _data["jobs"]:
		var jc: Array = j.get("coord", [-1, -1])
		if int(jc[0]) < 0:
			continue
		var p: Vector2 = o + (Vector2(int(jc[0]), int(jc[1])) + Vector2(0.5, 0.5)) * cell
		_canvas.draw_arc(p, cell * 0.9, 0, TAU, 24, INK_RED, 2.5)
		_canvas.draw_string(font, p + Vector2(cell * 0.9, -cell * 0.6), str(j.get("short", "!")).to_upper() + "!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK_RED)
	# The gate and who is there.
	var g: Vector2i = _data["gate"]
	var gp: Vector2 = o + (Vector2(g) + Vector2(0.5, 0.0)) * cell
	_canvas.draw_line(gp - Vector2(cell, 0), gp + Vector2(cell, 0), INK_RED, 3.0)
	_canvas.draw_string(font, gp + Vector2(-cell, -6), "GATE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
	if int(_data["waiting"]) > 0:
		_stamp(Rect2(gp + Vector2(cell * 1.2, -cell * 1.4), Vector2(cell * 5, cell)), "%d WAITING!" % int(_data["waiting"]), INK_RED, fs)
	# Legend and the to-do list in the margin.
	var mx := o.x + plan.x + 40.0
	var y := o.y
	_canvas.draw_string(title, Vector2(mx, y + fs), "TO DO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 1.5), PENCIL)
	y += fs * 2.2
	for line in _data["todo"]:
		for wl in _wrap("- " + str(line), margin_w - 20.0, font, fs):
			_canvas.draw_string(font, Vector2(mx, y), wl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
			y += fs * 1.25
		y += fs * 0.4
	if int(_data["coming"]) > 0:
		_canvas.draw_string(font, Vector2(mx, y), "- %d more on the road" % int(_data["coming"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
		y += fs * 1.6
	y = maxf(y + fs, o.y + plan.y - fs * 7.5)
	for row in [[INK_GREEN, "made up"], [INK_RED, "dirty - clean it"], [INK_AMBER, "not made up yet"], [INK_BLUE, "guests in"]]:
		_canvas.draw_circle(Vector2(mx + 6, y - fs * 0.35), fs * 0.4, row[0])
		_canvas.draw_string(font, Vector2(mx + 18, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL)
		y += fs * 1.35
	_canvas.draw_string(font, Vector2(mx, y + fs * 0.4), "you are not on this map.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PENCIL.lightened(0.35))


func _room_sticker(r: Rect2, rs: Dictionary, fs: int) -> void:
	var st := str(rs.get("status", ""))
	var col := INK_GREEN
	var mark := "OK"
	if bool(rs.get("occupied", false)):
		col = INK_BLUE
		mark = "IN"
	elif st == ROOM_RULES.STATUS_DIRTY:
		col = INK_RED
		mark = "X"
	elif st == ROOM_RULES.STATUS_UNPREPARED:
		col = INK_AMBER
		mark = "!"
	var c := r.position + Vector2(r.size.x - fs * 0.6, r.size.y - fs * 0.6)
	_canvas.draw_circle(c, fs * 0.62, col)
	_canvas.draw_string(RETRO_UI.FONT_TEXT, c + Vector2(-fs * 0.3, fs * 0.35), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PAPER)


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
	# Folds: the sheet has been in a pocket.
	for f in [0.33, 0.66]:
		var x: float = r.position.x + r.size.x * f
		_canvas.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), PAPER.darkened(0.16), 2.0)
		_canvas.draw_line(Vector2(x + 2, r.position.y), Vector2(x + 2, r.end.y), PAPER.lightened(0.1), 1.0)
	var y := r.position.y + r.size.y * 0.5
	_canvas.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), PAPER.darkened(0.14), 2.0)
	# A coffee ring.
	_canvas.draw_arc(r.end - Vector2(90, 70), 34, 0, TAU, 40, Color(0.45, 0.30, 0.15, 0.25), 4.0)


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
