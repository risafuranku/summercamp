extends RefCounted

## What the camp's plan shows (the PDA's map, scripts/pda/apps/map_app.gd; until 24. 11. Vera's
## paper site plan on TAB): where everything is, and what needs you. Read off the camp each
## time, nothing kept.
##
##   collect(main) -> {w, h, lake: [coord], trees: [coord], paths: {coord: lit}, buildings:
##     [{type, at, fp}], rooms: {key: room state}, broken: {key: true}, jobs: [{kind, coord,
##     title, where...}], waiting, coming (guests at the gate, on the way), gate, todo:
##     ["what - where"], corn_gate, title}
##
## The plan is drawn as you see the camp walking in through the gate: the gate at the bottom,
## the far fence at the top (`to_plan`).

const INSTANCE = preload("res://scripts/instance/instance.gd")
const LANG = preload("res://scripts/lang.gd")

## Lodgings, whose state the plan shows.
const ROOM_TYPES := ["tent_1", "tent_2", "tent_3", "cabin", "cabin_1", "cabin_2", "cabin_3", "caravan_1", "caravan_2", "caravan_3"]


static func collect(main: Node) -> Dictionary:
	if main == null:
		return {}
	var core = INSTANCE.core(main)
	var guests = INSTANCE.guests(main)
	var state = core.get_state() if core != null else null
	var grid = main.get("grid_manager")
	if state == null or grid == null or guests == null:
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
		var def = core.registry.get_def(StringName(t)) if core.registry != null else null
		if def != null:
			fp = def.footprint
		fp = cell.get("fp", fp)
		buildings.append({"type": t, "at": root, "fp": fp})
	# The reception has no builder cell; find it in the scene.
	var reception: Node = main.find_child("MainBuilding", true, false)
	if reception != null and reception.has_meta("grid_origin"):
		buildings.append({"type": "main_building", "at": reception.get_meta("grid_origin"), "fp": reception.get_meta("grid_footprint", Vector2i(2, 2))})
	var rooms := {}
	for key in guests.get_accommodation_states():
		var rs: Dictionary = guests.get_room_state(str(key))
		if not rs.is_empty():
			rooms[str(key)] = rs
	var broken := {}
	for key in state.failures.keys():
		broken[str(key)] = true
	var jobs: Array = []
	var nj = main.get("_night_jobs")
	if nj != null and nj.has_method("open_jobs"):
		jobs = nj.open_jobs()
	var waiting := 0
	var coming := 0
	for a in guests.get_arrivals():
		if bool(a.get("at_gate", false)):
			waiting += int(a.get("party_size", 1))
		else:
			coming += int(a.get("party_size", 1))
	var todo: Array = []
	# The day's events and guests waiting to be served are marked like the night's jobs.
	var de = main.get("_day_events")
	if de != null and de.has_method("open_events"):
		for ev in de.open_events():
			if bool(ev.get("gate", false)):
				var gc: Vector2i = reception_coord(main) if str(ev.get("kind", "")) == "delivery" else guests.get_gate_coord()
				ev["coord"] = [gc.x, gc.y]
			jobs.append(ev)
	var im = main.get("_interior_manager")
	var biz = im.get("business") if im != null else null
	if biz != null and biz.has_method("waiting_sites"):
		for s in biz.waiting_sites():
			jobs.append({"kind": "serve", "coord": s["coord"], "title": LANG.f("%s: %d waiting for an order", [main.tr(str(s["title"])), int(s["n"])]), "where": "serve them at the counter"})
	for j in jobs:
		todo.append("%s - %s" % [main.tr(str(j.get("title", ""))), main.tr(str(j.get("where", "")))])
	return {"w": w, "h": h, "lake": lake, "trees": trees, "paths": paths, "buildings": buildings,
		"rooms": rooms, "broken": broken, "jobs": jobs, "waiting": waiting, "coming": coming,
		"gate": guests.get_gate_coord(), "todo": todo, "corn_gate": _corn_gate_coord(main, grid),
		"title": _title(main)}


## What waits for the warden as reminders with a key that stays the same while it waits
## (the office printer, scripts/reception/office_printer.gd): tonight's jobs, today's events,
## what has broken down. [{key, text}] (the guests waiting at a counter are left out: their
## count changes by the minute). No pass over the map's tiles: cheap to ask every few seconds.
static func reminders(main: Node) -> Array:
	var out: Array = []
	if main == null:
		return out
	var nj = main.get("_night_jobs")
	if nj != null and nj.has_method("open_jobs"):
		for j in nj.open_jobs():
			out.append({"key": "job:%s" % str(j.get("id", j.get("title", ""))), "text": _line(main, j)})
	var de = main.get("_day_events")
	if de != null and de.has_method("open_events"):
		for ev in de.open_events():
			out.append({"key": "event:%s" % str(ev.get("id", "")), "text": _line(main, ev)})
	var core = INSTANCE.core(main)
	var state = core.get_state() if core != null else null
	if state != null:
		for key in state.failures.keys():
			var cell: Dictionary = state.grid.cells.get(_parse(str(key)), {})
			var t := str(cell.get("type", ""))
			out.append({"key": "broken:%s" % str(key), "text": main.tr("%s: broken down") % main.tr(place_name(t))})
	return out


static func _line(main: Node, j: Dictionary) -> String:
	var where := str(j.get("where", ""))
	var title := main.tr(str(j.get("title", "")))
	return title if where == "" else "%s - %s" % [title, main.tr(where)]


static func _parse(key: String) -> Vector2i:
	return Vector2i(int(key.get_slice(":", 0)), int(key.get_slice(":", 1))) if key.contains(":") else Vector2i(-1, -1)


## A building's name as the PDA's plan and the printer write it.
const NAMES := {
	"main_building": "Office", "toilet_block": "Toilets", "shower_block": "Showers", "pub": "Pub",
	"restaurant": "Bistro", "vecerka": "Jednota", "bonfire": "Bonfire", "sports_field": "Sports field",
	"lake_slide": "Lake slide", "playground": "Playground", "ping_pong": "Ping-pong", "corn_stand": "Corn stand",
	"bowling": "Bowling", "staffroom": "Staffroom", "warehouse": "Warehouse", "sewer": "Sewage",
	"power_generator": "Generator", "water_pump": "Pump", "sewage_tank": "Tank", "dumpsters": "Bins",
	"pa_pole": "PA pole", "lamp_post": "Lamp", "bench": "Bench", "picnic_table": "Picnic table",
	"flower_bed": "Flower bed", "gnome": "Gnome", "mega_gnome": "Mega gnome", "flagpole": "Flagpole",
	"hammock": "Hammock",
}


static func place_name(type: String) -> String:
	return str(NAMES.get(type, type.capitalize()))


## A grid cell on a plan `w` x `h` cells: the gate at the bottom (as you walk in), so left and
## right as they are in front of you.
static func to_plan(c: Vector2, w: int, h: int) -> Vector2:
	return Vector2(float(w) - c.x, float(h) - c.y)


## The camp's own name, once it has one.
static func _title(main: Node) -> String:
	var n: String = str(main.call("camp_name")) if main.has_method("camp_name") else ""
	return n.to_upper() if not n.is_empty() else "KEMP CERNE JEZERO"


## Grid row of the wicket gate into the corn (on the west fence), or (-1, -1).
static func _corn_gate_coord(main: Node, grid) -> Vector2i:
	if not main.has_method("corn_gate_world"):
		return Vector2i(-1, -1)
	var p: Vector3 = main.corn_gate_world()
	if p == Vector3.INF:
		return Vector2i(-1, -1)
	var c: Vector2i = grid.world_to_grid(p + Vector3(1.0, 0, 0))
	return Vector2i(0, c.y)


static func _is_tree(n: Node) -> bool:
	var cur := n
	while cur != null:
		if cur.is_in_group("trees") or str(cur.get_meta("building_type", "")).begins_with("tree_"):
			return true
		cur = cur.get_parent()
	return false


## Where the van's driver is going (the gate when there is no reception).
static func reception_coord(main: Node) -> Vector2i:
	var state = INSTANCE.core(main).get_state()
	if state != null:
		for coord in state.grid.cells.keys():
			var cell: Dictionary = state.grid.cells[coord]
			if str(cell.get("type", "")) == "main_building" and cell.get("root_coord", coord) == coord:
				return coord
	return INSTANCE.guests(main).get_gate_coord()
