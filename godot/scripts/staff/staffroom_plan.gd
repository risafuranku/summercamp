extends RefCounted

## The staffroom's plan (DESIGN.md §7c): one set of boxes for both places it is seen.
##   inside   the room you walk into (scripts/staff/staffroom.gd, in the service
##            interior's own world): the lounge and the boiler room behind it, their
##            windows real views out (window_portal.gd) with curtains;
##   outside  the building in the camp (building_models._staffroom): the same rooms built
##            in it behind real glass, so from the camp you see into it, its lamp, its
##            curtains, the hands lying on the mattresses, a warden at the laptop.
## Building space: the footprint's middle on the ground, the front (the door) toward +Z,
## the floor FLOOR up on its plinth. The room's own space is the same (the service
## interior's room root sits at the origin), so a window's view out is the building's
## transform and nothing else.
##
## A 1970s Czech village prefab hut, Build style (plain boxes, Grok faces and textures):
##   the lounge      the door in the front wall, a window either side of it and one over
##                   the sofa on the left; the sofa, the formica table with the old chunky
##                   laptop (the office PC's functions) and the staffroom's books, two
##                   chairs, the kitchen counter with the coffee machine, the fridge, the
##                   TV on its cabinet, a safety poster, a calendar, the coats by the door;
##                   and the armchairs the books have bought (the hands' breaks);
##   the boiler room through the doorway in the right wall: the coal boiler and its flue,
##                   the coal, the mattress on the floor (the warden's, to sleep on:
##                   scripts/lodge_bed.gd), the lockers along the front wall, a small
##                   high window, a bare bulb.

const K = preload("res://scripts/interior_kit.gd")
const CAMP := "res://assets/textury/camp/"

const FLOOR := 0.3
## The lounge's inside (x, z) and height.
const L_MIN := Vector2(-3.4, -2.0)
const L_MAX := Vector2(1.0, 2.0)
const L_H := 2.6
## The boiler room's.
const B_MIN := Vector2(1.15, -2.0)
const B_MAX := Vector2(3.8, 2.0)
const B_H := 2.4
## Walls: the inside face is the room's edge, the outside face this much further out.
const WALL := 0.16
const IN_LAYER := 0.06
## The front door (centre x, width, height), the doorway between the rooms (centre z,
## width, height) in the wall at x = L_MAX.x .. B_MIN.x.
const DOOR_X := -1.2
const DOOR_W := 0.9
const DOOR_H := 2.0
const INNER_Z := -0.9
const INNER_W := 0.85
## The windows: id -> {room, c (the glass's middle on the wall's inside face), size,
## out (the way out)}.
const WINDOWS := {
	"front_l": {"room": "lounge", "c": Vector3(-2.75, FLOOR + 1.45, 2.0), "size": Vector2(0.9, 0.95), "out": Vector3(0, 0, 1)},
	"front_r": {"room": "lounge", "c": Vector3(0.18, FLOOR + 1.45, 2.0), "size": Vector2(0.9, 0.95), "out": Vector3(0, 0, 1)},
	"left": {"room": "lounge", "c": Vector3(-3.4, FLOOR + 1.5, -0.65), "size": Vector2(1.0, 0.8), "out": Vector3(-1, 0, 0)},
	"boiler": {"room": "boiler", "c": Vector3(3.8, FLOOR + 1.78, -0.1), "size": Vector2(0.6, 0.45), "out": Vector3(1, 0, 0)},
}
const WINDOW_ORDER := ["front_l", "front_r", "left", "boiler"]

## Where things are (building space, on the floor unless said).
const TABLE := Vector3(-1.75, FLOOR, 0.15)
const TABLE_TOP := 0.76
## The laptop on the table, its keys toward the chair at the front side.
const LAPTOP := Vector3(-1.45, FLOOR + TABLE_TOP, 0.22)
const LAPTOP_CHAIR := Vector3(-1.45, FLOOR, 0.92)
## Sat at it: the eye over the keys, looking down at the screen.
const LAPTOP_EYE := Vector3(-1.45, FLOOR + 1.22, 0.78)
const LEDGER := Vector3(-2.05, FLOOR + TABLE_TOP, 0.3)
const SOFA_SEATS := [Vector3(-2.98, FLOOR, -1.05), Vector3(-2.98, FLOOR, -0.25)]
const COFFEE := Vector3(-1.15, FLOOR + 0.92, -1.74)
const FRIDGE := Vector3(-0.02, FLOOR, -1.69)
const TV := Vector3(0.62, FLOOR + 0.62, 0.62)
## The warden's mattress along the boiler room's right wall: its centre on the floor, its
## head end (toward the back wall).
const MATTRESS := Vector3(3.39, FLOOR, -0.1)
const MATTRESS_HEAD := Vector3(3.39, FLOOR, -0.95)
## The armchairs in the lounge, in the order they are bought: [where, the way it faces].
const ARMCHAIRS := [
	[Vector3(-2.85, FLOOR, 1.3), Vector3(1.0, 0.0, -0.25)],
	[Vector3(-2.05, FLOOR, 1.45), Vector3(0.95, 0.0, -0.35)],
	[Vector3(0.45, FLOOR, -0.2), Vector3(-1.0, 0.0, 0.0)],
]
const MATTRESS_SIZE := Vector3(0.78, 0.14, 1.9)
## The lockers along the boiler room's front wall, left to right seen from inside.
const LOCKER_W := 0.46
const LOCKERS_X0 := 1.42
const LOCKER_Z := 1.74
const MAX_LOCKERS := 5
## Where you stand in each room (the eye) and look; the way between them through the
## doorway (the walk: scripts/ui/walk_path.gd).
const EYE_LOUNGE := Vector3(-0.85, FLOOR + 1.6, 1.45)
const LOOK_LOUNGE := Vector3(-0.2, 0.0, 0.0)
const EYE_BOILER := Vector3(1.55, FLOOR + 1.6, -0.62)
const LOOK_BOILER := Vector3(-0.12, -1.5708, 0.0)
const WAY_TO_BOILER := [Vector3(-0.85, FLOOR + 1.6, 1.45), Vector3(0.1, FLOOR + 1.6, 0.1), Vector3(0.7, FLOOR + 1.6, -0.85), Vector3(1.55, FLOOR + 1.6, -0.62)]
## The front door, inside (where the way out is) and outside (where E aims).
const DOOR_OUT := Vector3(DOOR_X, FLOOR + 1.1, 2.0 + WALL + 0.25)


static func tex(name: String, fallback: String) -> String:
	return name if ResourceLoader.exists(CAMP + name + ".png") else fallback


static func _mat_face(name: String, fallback: String, tint := Color(1, 1, 1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.albedo_color = tint
	var t := tex(name, fallback)
	if ResourceLoader.exists(CAMP + t + ".png"):
		m.albedo_texture = load(CAMP + t + ".png")
	return m


## A picture on the face of a box: a quad at `pos` facing `normal` (horizontal).
static func face(parent: Node3D, name: String, fallback: String, size: Vector2, pos: Vector3, normal: Vector3, node_name := "Face") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _mat_face(name, fallback)
	mi.position = pos
	mi.rotation.y = atan2(normal.x, normal.z)
	parent.add_child(mi)
	return mi


## A wall from `a` to `b` (x, z on the floor) whose inside face is that line, `h` tall
## from `y0`, `thick` deep toward `outward`, with holes [[along (from a), width, bottom,
## top], ...]: built of boxes round the holes.
static func wall(parent: Node3D, a: Vector2, b: Vector2, y0: float, h: float, thick: float, outward: Vector2, holes: Array, mat: Material, offset := 0.0, node_name := "Wall") -> void:
	var dir := (b - a)
	var length := dir.length()
	dir /= length
	var spans: Array = []   # [from, to, bottom, top]
	var cuts: Array = holes.duplicate()
	cuts.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var t := 0.0
	for c in cuts:
		var c0 := float(c[0]) - float(c[1]) * 0.5
		var c1 := float(c[0]) + float(c[1]) * 0.5
		if c0 > t:
			spans.append([t, c0, 0.0, h])
		# Below and above the hole.
		if float(c[2]) > 0.001:
			spans.append([c0, c1, 0.0, float(c[2])])
		if float(c[3]) < h - 0.001:
			spans.append([c0, c1, float(c[3]), h])
		t = c1
	if t < length:
		spans.append([t, length, 0.0, h])
	for sp in spans:
		var s0 := float(sp[0])
		var s1 := float(sp[1])
		var lo := float(sp[2])
		var hi := float(sp[3])
		if s1 - s0 < 0.005 or hi - lo < 0.005:
			continue
		var mid := a + dir * (s0 + s1) * 0.5 + outward * (offset + thick * 0.5)
		var size := Vector3(absf(dir.x) * (s1 - s0) + absf(outward.x) * thick, hi - lo, absf(dir.y) * (s1 - s0) + absf(outward.y) * thick)
		K.slab(parent, size, Vector3(mid.x, y0 + (lo + hi) * 0.5, mid.y), mat, node_name)


## The holes of each wall: the windows and the doors (along, width, bottom, top).
static func _holes(which: String) -> Array:
	var out: Array = []
	for id in WINDOWS:
		var w: Dictionary = WINDOWS[id]
		var c: Vector3 = w["c"]
		var s: Vector2 = w["size"]
		var bottom := c.y - FLOOR - s.y * 0.5
		var top := c.y - FLOOR + s.y * 0.5
		match which:
			"l_front":
				if id.begins_with("front"):
					out.append([c.x - L_MIN.x, s.x, bottom, top])
			"l_left":
				if id == "left":
					out.append([c.z - L_MIN.y, s.x, bottom, top])
			"b_right":
				if id == "boiler":
					out.append([c.z - B_MIN.y, s.x, bottom, top])
	match which:
		"l_front":
			out.append([DOOR_X - L_MIN.x, DOOR_W, 0.0, DOOR_H])
		"part":
			out.append([INNER_Z - L_MIN.y, INNER_W, 0.0, DOOR_H])
	return out


## Builds the rooms into `root` (building space). `camp`: the building in the camp (its
## outside walls, the roof, glass in the windows, nothing to click); else the room
## inside. Returns what the caller drives: {tv_screen, laptop_screen, lockers: [Node3D],
## lockers_open: [Node3D], mattresses: [Node3D], glass: {id: MeshInstance3D}, curtains:
## {id: [shut, open_l, open_r]}, lamp_meshes: [MeshInstance3D], door: Node3D, hot: {id:
## [centre, size]}}.
static func build(root: Node3D, camp: bool) -> Dictionary:
	var out := {"lockers": [], "lockers_open": [], "armchairs": [], "glass": {}, "curtains": {}, "lamp_meshes": [], "hot": {}}
	var wall_in := K.surface(tex("staff_wall_in", "oil_wall"), L_H)
	var boiler_wall := K.surface(tex("kotelna_wall", "brick_red"), B_H)
	var plaster := K.surface(tex("staff_plaster", "roughcast_wall"), 1.6)
	var lino := K.surface(tex("staff_lino", "lino_floor"), 1.2)
	var concrete := K.surface(tex("kotelna_floor", "concrete"), 1.4)
	var ceiling := K.surface("ceiling_board", 1.2)
	# Floors and ceilings.
	var lw := L_MAX.x - L_MIN.x
	var ld := L_MAX.y - L_MIN.y
	var bw := B_MAX.x - B_MIN.x
	var bd := B_MAX.y - B_MIN.y
	K.slab(root, Vector3(lw, 0.1, ld), Vector3((L_MIN.x + L_MAX.x) * 0.5, FLOOR - 0.05, (L_MIN.y + L_MAX.y) * 0.5), lino, "LoungeFloor")
	K.slab(root, Vector3(bw, 0.1, bd), Vector3((B_MIN.x + B_MAX.x) * 0.5, FLOOR - 0.05, (B_MIN.y + B_MAX.y) * 0.5), concrete, "BoilerFloor")
	K.slab(root, Vector3(B_MIN.x - L_MAX.x, 0.1, INNER_W), Vector3((L_MAX.x + B_MIN.x) * 0.5, FLOOR - 0.05, INNER_Z), concrete, "Threshold")
	K.slab(root, Vector3(lw, 0.1, ld), Vector3((L_MIN.x + L_MAX.x) * 0.5, FLOOR + L_H + 0.05, (L_MIN.y + L_MAX.y) * 0.5), ceiling, "LoungeCeiling")
	K.slab(root, Vector3(bw, 0.1, bd), Vector3((B_MIN.x + B_MAX.x) * 0.5, FLOOR + B_H + 0.05, (B_MIN.y + B_MAX.y) * 0.5), K.surface(tex("kotelna_wall", "concrete"), 1.4, Color(0.7, 0.7, 0.7)), "BoilerCeiling")
	# The inside faces of the walls.
	var lay := IN_LAYER
	wall(root, Vector2(L_MIN.x, L_MIN.y), Vector2(L_MAX.x, L_MIN.y), FLOOR, L_H, lay, Vector2(0, -1), [], wall_in, 0.0, "LoungeBack")
	wall(root, Vector2(L_MIN.x, L_MAX.y), Vector2(L_MAX.x, L_MAX.y), FLOOR, L_H, lay, Vector2(0, 1), _holes("l_front"), wall_in, 0.0, "LoungeFront")
	wall(root, Vector2(L_MIN.x, L_MIN.y), Vector2(L_MIN.x, L_MAX.y), FLOOR, L_H, lay, Vector2(-1, 0), _holes("l_left"), wall_in, 0.0, "LoungeLeft")
	# The wall between them: the lounge's face, the boiler room's face.
	var part := B_MIN.x - L_MAX.x
	wall(root, Vector2(L_MAX.x, L_MIN.y), Vector2(L_MAX.x, L_MAX.y), FLOOR, L_H, part * 0.5, Vector2(1, 0), _holes("part"), wall_in, 0.0, "PartLounge")
	wall(root, Vector2(L_MAX.x, L_MIN.y), Vector2(L_MAX.x, L_MAX.y), FLOOR, B_H, part * 0.5, Vector2(1, 0), _holes("part"), boiler_wall, part * 0.5, "PartBoiler")
	wall(root, Vector2(B_MIN.x, B_MIN.y), Vector2(B_MAX.x, B_MIN.y), FLOOR, B_H, lay, Vector2(0, -1), [], boiler_wall, 0.0, "BoilerBack")
	wall(root, Vector2(B_MIN.x, B_MAX.y), Vector2(B_MAX.x, B_MAX.y), FLOOR, B_H, lay, Vector2(0, 1), [], boiler_wall, 0.0, "BoilerFront")
	wall(root, Vector2(B_MAX.x, B_MIN.y), Vector2(B_MAX.x, B_MAX.y), FLOOR, B_H, lay, Vector2(1, 0), _holes("b_right"), boiler_wall, 0.0, "BoilerRight")
	if camp:
		_outside(root, plaster, out)
	# The doorway's frame and the door standing open into the boiler room.
	var frame_mat := K.surface("planks_dark", 0.6)
	for sz: float in [-1.0, 1.0]:
		K.slab(root, Vector3(part + 0.04, DOOR_H, 0.05), Vector3(L_MAX.x + part * 0.5, FLOOR + DOOR_H * 0.5, INNER_Z + sz * (INNER_W * 0.5 + 0.025)), frame_mat, "DoorwayJamb")
	K.slab(root, Vector3(part + 0.04, 0.06, INNER_W + 0.1), Vector3(L_MAX.x + part * 0.5, FLOOR + DOOR_H + 0.03, INNER_Z), frame_mat, "DoorwayHead")
	var hinge := Node3D.new()
	hinge.name = "InnerDoorHinge"
	hinge.position = Vector3(B_MIN.x + 0.02, FLOOR, INNER_Z + INNER_W * 0.5)
	hinge.rotation.y = deg_to_rad(-170.0)
	root.add_child(hinge)
	K.slab(hinge, Vector3(0.04, DOOR_H - 0.04, INNER_W - 0.04), Vector3(0, DOOR_H * 0.5, -(INNER_W - 0.04) * 0.5), K.surface("door_interior", 2.0), "InnerDoor")
	# The front door, shut (inside: its back; in the camp: the Grok face outside).
	var door := Node3D.new()
	door.name = "FrontDoor"
	door.position = Vector3(DOOR_X, FLOOR, L_MAX.y + WALL * 0.5)
	root.add_child(door)
	K.slab(door, Vector3(DOOR_W - 0.04, DOOR_H - 0.02, 0.05), Vector3(0, DOOR_H * 0.5, 0), K.surface("door_interior", 2.0), "DoorLeaf")
	face(door, "staff_door", "door_wood", Vector2(DOOR_W - 0.04, DOOR_H - 0.02), Vector3(0, DOOR_H * 0.5, 0.027), Vector3(0, 0, 1), "DoorOut")
	face(door, "door_interior", "door_wood", Vector2(DOOR_W - 0.04, DOOR_H - 0.02), Vector3(0, DOOR_H * 0.5, -0.027), Vector3(0, 0, -1), "DoorIn")
	out["door"] = door
	_lounge(root, out, camp)
	_boiler(root, out, camp)
	_windows(root, out, camp)
	return out


# ── outside (the camp only) ───────────────────────────────────────────────────

static func _outside(root: Node3D, plaster: Material, out: Dictionary) -> void:
	var o := IN_LAYER
	var t := WALL - IN_LAYER
	# Up to the roofs' undersides (the ceilings' edges are not seen between).
	var lh := L_H + 0.12
	var bh := B_H + 0.1
	wall(root, Vector2(L_MIN.x - WALL, L_MIN.y), Vector2(L_MAX.x, L_MIN.y), FLOOR, lh, t, Vector2(0, -1), [], plaster, o, "OutBack")
	wall(root, Vector2(L_MIN.x - WALL, L_MAX.y), Vector2(L_MAX.x, L_MAX.y), FLOOR, lh, t, Vector2(0, 1), _shift(_holes("l_front"), WALL), plaster, o, "OutFront")
	wall(root, Vector2(L_MIN.x, L_MIN.y - WALL), Vector2(L_MIN.x, L_MAX.y + WALL), FLOOR, lh, t, Vector2(-1, 0), _shift(_holes("l_left"), WALL), plaster, o, "OutLeft")
	wall(root, Vector2(L_MAX.x, L_MIN.y), Vector2(B_MAX.x + WALL, B_MIN.y), FLOOR, bh, t, Vector2(0, -1), [], plaster, o, "OutBackB")
	wall(root, Vector2(L_MAX.x, B_MAX.y), Vector2(B_MAX.x + WALL, B_MAX.y), FLOOR, bh, t, Vector2(0, 1), [], plaster, o, "OutFrontB")
	wall(root, Vector2(B_MAX.x, B_MIN.y - WALL), Vector2(B_MAX.x, B_MAX.y + WALL), FLOOR, bh, t, Vector2(1, 0), _shift(_holes("b_right"), WALL), plaster, o, "OutRight")
	# The lounge's taller wall over the boiler room's roof.
	K.slab(root, Vector3(B_MIN.x - L_MAX.x, L_H - B_H + 0.2, L_MAX.y - L_MIN.y + 2.0 * WALL), Vector3((L_MAX.x + B_MIN.x) * 0.5, FLOOR + B_H + (L_H - B_H + 0.2) * 0.5, 0.0), plaster, "OutStep")
	# The plinth all round, the steps up to the door.
	var plinth := K.surface(tex("staff_plinth", "concrete"), 1.2)
	var x0 := L_MIN.x - WALL - 0.04
	var x1 := B_MAX.x + WALL + 0.04
	var z0 := L_MIN.y - WALL - 0.04
	var z1 := L_MAX.y + WALL + 0.04
	K.slab(root, Vector3(x1 - x0, FLOOR + 0.1, z1 - z0), Vector3((x0 + x1) * 0.5, (FLOOR - 0.1) * 0.5, (z0 + z1) * 0.5), plinth, "Plinth")
	K.slab(root, Vector3(1.3, FLOOR * 0.5, 0.36), Vector3(DOOR_X, FLOOR * 0.25, z1 + 0.18), plinth, "StepLow")
	K.slab(root, Vector3(1.2, FLOOR, 0.2), Vector3(DOOR_X, FLOOR * 0.5 - 0.02, z1 + 0.06), plinth, "StepHigh")
	# The flat roofs of tar paper, a tin edge round them; the boiler room's chimney.
	var tar := K.surface(tex("staff_tarpaper", "corrugated_roof"), 2.0)
	var tin := K.surface("galvanized", 0.8)
	var rl := Vector3(L_MAX.x - L_MIN.x + 2.0 * WALL + 0.3, 0.16, L_MAX.y - L_MIN.y + 2.0 * WALL + 0.3)
	var ry := FLOOR + L_H + 0.18
	K.slab(root, rl, Vector3((L_MIN.x + L_MAX.x) * 0.5 - 0.02, ry, 0.0), tar, "RoofL")
	K.slab(root, Vector3(rl.x + 0.04, 0.08, rl.z + 0.04), Vector3((L_MIN.x + L_MAX.x) * 0.5 - 0.02, ry + 0.07, 0.0), tin, "RoofEdgeL")
	K.slab(root, Vector3(rl.x - 0.1, 0.06, rl.z - 0.1), Vector3((L_MIN.x + L_MAX.x) * 0.5 - 0.02, ry + 0.11, 0.0), tar, "RoofTopL")
	var rb := Vector3(B_MAX.x - L_MAX.x + WALL + 0.15, 0.14, B_MAX.y - B_MIN.y + 2.0 * WALL + 0.3)
	var by := FLOOR + B_H + 0.16
	K.slab(root, rb, Vector3((L_MAX.x + B_MAX.x + WALL) * 0.5 + 0.08, by, 0.0), tar, "RoofB")
	K.slab(root, Vector3(rb.x + 0.04, 0.07, rb.z + 0.04), Vector3((L_MAX.x + B_MAX.x + WALL) * 0.5 + 0.08, by + 0.06, 0.0), tin, "RoofEdgeB")
	var brick := K.surface("brick_red", 0.8)
	K.slab(root, Vector3(0.42, 1.5, 0.42), Vector3(B_MAX.x - 0.35, FLOOR + B_H + 0.75, B_MIN.y + 0.3), brick, "Chimney")
	K.slab(root, Vector3(0.5, 0.08, 0.5), Vector3(B_MAX.x - 0.35, FLOOR + B_H + 1.52, B_MIN.y + 0.3), K.surface("concrete", 0.6), "ChimneyCap")
	# The enamel plate by the door, a lamp over it, a drainpipe.
	var plate := K.slab(root, Vector3(0.5, 0.16, 0.02), Vector3(DOOR_X + 0.74, FLOOR + 1.6, L_MAX.y + WALL + 0.012), K.surface("enamel_white", 0.5), "Plate")
	var l := Label3D.new()
	l.text = "PERSONAL"
	if ResourceLoader.exists("res://assets/fonts/w95b.fnt"):
		l.font = load("res://assets/fonts/w95b.fnt")
	l.font_size = 16
	l.pixel_size = 0.09 / 16.0
	l.modulate = Color(0.1, 0.16, 0.42)
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.double_sided = false
	l.position = plate.position + Vector3(0, 0, 0.015)
	root.add_child(l)
	K.slab(root, Vector3(0.18, 0.1, 0.2), Vector3(DOOR_X, FLOOR + DOOR_H + 0.28, z1 + 0.06), K.surface("galvanized", 0.4), "DoorLamp")
	var bulb := K.slab(root, Vector3(0.1, 0.08, 0.1), Vector3(DOOR_X, FLOOR + DOOR_H + 0.19, z1 + 0.1), K.surface("enamel_white", 0.4), "DoorBulb")
	out["lamp_meshes"].append(bulb)
	K.slab(root, Vector3(0.08, FLOOR + L_H, 0.08), Vector3(L_MIN.x - WALL - 0.06, (FLOOR + L_H) * 0.5, z1 - 0.12), tin, "Drainpipe")
	# The coal hatch low on the boiler room's right wall, coal spilt under it.
	K.slab(root, Vector3(0.04, 0.4, 0.55), Vector3(B_MAX.x + WALL + 0.02, FLOOR + 0.35, 1.1), K.surface("metal_green", 0.5), "CoalHatch")


## Holes along a wall that starts `by` earlier.
static func _shift(holes: Array, by: float) -> Array:
	var out: Array = []
	for h in holes:
		out.append([float(h[0]) + by, h[1], h[2], h[3]])
	return out


# ── the lounge ────────────────────────────────────────────────────────────────

static func _lounge(root: Node3D, out: Dictionary, camp: bool) -> void:
	var wood := K.surface("planks_dark", 0.6)
	var steel := K.surface("steel_brushed", 0.5)
	var formica := K.surface(tex("staff_formica", "formica"), 0.8)
	# The sofa along the left wall under the window, facing the room.
	var cord := K.surface(tex("sofa_cord", "velvet"), 0.6)
	var sx := L_MIN.x + 0.02
	K.slab(root, Vector3(0.74, 0.24, 1.66), Vector3(sx + 0.42, FLOOR + 0.3, -0.65), cord, "SofaSeat")
	K.slab(root, Vector3(0.66, 0.18, 1.66), Vector3(sx + 0.4, FLOOR + 0.09, -0.65), wood, "SofaBase")
	K.slab(root, Vector3(0.22, 0.52, 1.66), Vector3(sx + 0.11, FLOOR + 0.62, -0.65), cord, "SofaBack")
	for z: float in [-1.55, 0.25]:
		K.slab(root, Vector3(0.78, 0.22, 0.14), Vector3(sx + 0.4, FLOOR + 0.52, z), wood, "SofaArm")
	K.slab(root, Vector3(0.5, 0.05, 0.6), Vector3(sx + 0.36, FLOOR + 0.44, -0.2), K.surface("blanket_check", 0.6), "SofaBlanket")
	# The table, the laptop, the books.
	K.slab(root, Vector3(1.2, 0.04, 0.74), TABLE + Vector3(0, TABLE_TOP - 0.02, 0), formica, "TableTop")
	for dx: float in [-0.55, 0.55]:
		for dz: float in [-0.32, 0.32]:
			K.slab(root, Vector3(0.04, TABLE_TOP - 0.04, 0.04), TABLE + Vector3(dx, (TABLE_TOP - 0.04) * 0.5, dz), steel, "TableLeg")
	_chair(root, LAPTOP_CHAIR, 0.0, wood, steel)
	_chair(root, TABLE + Vector3(-0.2, 0.0, -0.66), PI, wood, steel)
	out["laptop_screen"] = _laptop(root, LAPTOP)
	out["hot"]["laptop"] = [LAPTOP + Vector3(0, 0.14, 0), Vector3(0.5, 0.36, 0.42)]
	var book := K.slab(root, Vector3(0.34, 0.035, 0.25), LEDGER + Vector3(0, 0.018, 0), K.surface("veneer_dark", 0.4), "Ledger")
	book.rotation.y = 0.18
	var pages := K.picture(root, "ledger_open", Vector2(0.32, 0.23), LEDGER + Vector3(0, 0.037, 0), 0.0, "LedgerPages")
	pages.rotation = Vector3(-PI * 0.5, 0.18, 0.0)
	out["hot"]["ledger"] = [LEDGER + Vector3(0, 0.05, 0), Vector3(0.42, 0.14, 0.34)]
	K.cutout(root, "desk_mug", Vector2(0.09, 0.1), TABLE + Vector3(-0.42, TABLE_TOP, -0.2), 0.0, true, "Mug")
	K.cutout(root, "ashtray", Vector2(0.14, 0.05), TABLE + Vector3(0.45, TABLE_TOP, -0.18), 0.0, true, "Ashtray")
	# The kitchen counter on the back wall, the coffee machine on it; the fridge.
	var counter_mat := K.surface("veneer_dark", 0.6)
	K.slab(root, Vector3(1.35, 0.86, 0.56), Vector3(-1.22, FLOOR + 0.43, L_MIN.y + 0.3), counter_mat, "Counter")
	K.slab(root, Vector3(1.4, 0.04, 0.6), Vector3(-1.22, FLOOR + 0.88, L_MIN.y + 0.3), formica, "CounterTop")
	K.slab(root, Vector3(1.3, 0.62, 0.32), Vector3(-1.22, FLOOR + 1.85, L_MIN.y + 0.18), counter_mat, "WallCupboard")
	K.cutout(root, tex("coffee_maker", "desk_mug"), Vector2(0.24, 0.32), COFFEE, 0.0, false, "CoffeeMaker")
	out["hot"]["coffee"] = [COFFEE + Vector3(0, 0.16, 0), Vector3(0.32, 0.36, 0.3)]
	K.cutout(root, "desk_mug", Vector2(0.08, 0.09), COFFEE + Vector3(0.3, 0.0, 0.05), 0.0, false, "CounterMug")
	var fridge_side := K.surface("enamel_white", 0.6, Color(0.92, 0.88, 0.76))
	K.slab(root, Vector3(0.62, 1.42, 0.6), FRIDGE + Vector3(0, 0.71, 0), fridge_side, "Fridge")
	face(root, "staff_fridge", "shop_fridge", Vector2(0.62, 1.42), FRIDGE + Vector3(0, 0.71, 0.302), Vector3(0, 0, 1), "FridgeFront")
	out["hot"]["fridge"] = [FRIDGE + Vector3(0, 0.75, 0.15), Vector3(0.66, 1.45, 0.4)]
	# The TV on its cabinet in the right-front corner, turned to the sofa.
	K.slab(root, Vector3(0.5, 0.6, 0.6), Vector3(TV.x + 0.1, FLOOR + 0.3, TV.z), counter_mat, "TvCabinet")
	var tv := Node3D.new()
	tv.name = "Tv"
	tv.position = TV
	tv.rotation.y = -PI * 0.5 - 0.42
	root.add_child(tv)
	K.slab(tv, Vector3(0.62, 0.46, 0.44), Vector3(0, 0.23, 0), K.surface("veneer_dark", 0.4), "TvBox")
	face(tv, "staff_tv", "bistro_tv", Vector2(0.62, 0.46), Vector3(0, 0.23, 0.222), Vector3(0, 0, 1), "TvFront")
	var scr := MeshInstance3D.new()
	scr.name = "TvScreen"
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.27)
	scr.mesh = q
	scr.position = Vector3(-0.1, 0.24, 0.226)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sm.albedo_color = Color(0.05, 0.06, 0.06)
	scr.material_override = sm
	tv.add_child(scr)
	out["tv_screen"] = scr
	out["hot"]["tv"] = [TV + Vector3(0, 0.24, 0), Vector3(0.6, 0.5, 0.6)]
	# On the walls: the safety poster, the calendar, the coats by the door, a radiator.
	K.picture(root, tex("bozp_poster", "shop_poster"), Vector2(0.48, 0.64), Vector3(-2.75, FLOOR + 1.62, L_MIN.y + 0.01), 0.0, "Poster")
	K.picture(root, "calendar", Vector2(0.3, 0.42), Vector3(0.62, FLOOR + 1.55, L_MIN.y + 0.01), 0.0, "Calendar")
	K.cutout(root, "coat_hook", Vector2(0.42, 1.0), Vector3(-0.52, FLOOR + 0.85, L_MAX.y - 0.03), 180.0, false, "Coats")
	K.slab(root, Vector3(0.8, 0.5, 0.08), Vector3(-2.75, FLOOR + 0.45, L_MAX.y - 0.08), K.surface("enamel_white", 0.3, Color(0.85, 0.84, 0.78)), "Radiator")
	# The armchairs (staffroom.gd shows as many as the books have bought).
	var fabric := K.surface(tex("armchair_fabric", "velvet"), 0.6)
	for i in ARMCHAIRS.size():
		var a := Node3D.new()
		a.name = "Armchair%d" % i
		a.position = ARMCHAIRS[i][0]
		var f: Vector3 = ARMCHAIRS[i][1]
		a.rotation.y = atan2(f.x, f.z)
		root.add_child(a)
		K.slab(a, Vector3(0.62, 0.2, 0.6), Vector3(0, 0.3, 0.02), fabric, "ChairSeat")
		K.slab(a, Vector3(0.56, 0.16, 0.56), Vector3(0, 0.1, 0.0), wood, "ChairBase")
		K.slab(a, Vector3(0.62, 0.5, 0.16), Vector3(0, 0.6, -0.24), fabric, "ChairBack")
		for side: float in [-1.0, 1.0]:
			K.slab(a, Vector3(0.09, 0.2, 0.6), Vector3(side * 0.33, 0.47, 0.0), wood, "ChairArm")
		out["armchairs"].append(a)
	# The tube light on the ceiling.
	var tube := K.slab(root, Vector3(1.2, 0.06, 0.14), Vector3(-1.2, FLOOR + L_H - 0.05, 0.0), K.surface("enamel_white", 0.4), "TubeLight")
	out["lamp_meshes"].append(tube)
	if not camp:
		K.cutout(root, "doormat", Vector2(0.8, 0.02), Vector3(DOOR_X, FLOOR + 0.005, L_MAX.y - 0.4), 0.0, false, "Mat")


static func _chair(root: Node3D, at: Vector3, yaw: float, wood: Material, steel: Material) -> void:
	var c := Node3D.new()
	c.name = "Chair"
	c.position = at
	c.rotation.y = yaw
	root.add_child(c)
	K.slab(c, Vector3(0.42, 0.04, 0.42), Vector3(0, 0.45, 0), wood, "ChairSeat")
	K.slab(c, Vector3(0.42, 0.4, 0.04), Vector3(0, 0.68, 0.2), wood, "ChairBack")
	for dx: float in [-0.18, 0.18]:
		for dz: float in [-0.18, 0.18]:
			K.slab(c, Vector3(0.03, 0.44, 0.03), Vector3(dx, 0.22, dz), steel, "ChairLeg")


## The old chunky laptop: its base with the keys, the lid up and tipped back, the screen
## a quad on it (returned: staffroom.gd puts the office PC's picture on it).
static func _laptop(root: Node3D, at: Vector3) -> MeshInstance3D:
	var lap := Node3D.new()
	lap.name = "Laptop"
	lap.position = at
	root.add_child(lap)
	var grey := K.surface(tex("laptop_lid", "plastic"), 0.4)
	K.slab(lap, Vector3(0.36, 0.045, 0.27), Vector3(0, 0.022, 0), grey, "LaptopBase")
	var keys := K.picture(lap, tex("laptop_keys", "keyboard"), Vector2(0.34, 0.25), Vector3(0, 0.046, 0.0), 0.0, "LaptopKeys")
	keys.rotation.x = -PI * 0.5
	var lid := Node3D.new()
	lid.name = "LaptopLid"
	lid.position = Vector3(0, 0.045, -0.13)
	lid.rotation.x = -0.28
	lap.add_child(lid)
	K.slab(lid, Vector3(0.36, 0.27, 0.025), Vector3(0, 0.135, -0.012), grey, "LidBox")
	var back := K.picture(lid, tex("laptop_lid", "monitor_back"), Vector2(0.34, 0.25), Vector3(0, 0.135, -0.026), 180.0, "LidBack")
	back.name = "LidBack"
	var scr := MeshInstance3D.new()
	scr.name = "LaptopScreen"
	var q := QuadMesh.new()
	q.size = Vector2(0.29, 0.215)
	scr.mesh = q
	scr.position = Vector3(0, 0.14, 0.002)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.albedo_color = Color(0.1, 0.13, 0.16)
	scr.material_override = m
	lid.add_child(scr)
	return scr


# ── the boiler room ───────────────────────────────────────────────────────────

static func _boiler(root: Node3D, out: Dictionary, _camp: bool) -> void:
	# The boiler in the back-right corner, its doors to the room; the flue.
	var green := K.surface("metal_green", 0.6)
	var bx := B_MAX.x - 0.42
	var bz := B_MIN.y + 0.42
	K.slab(root, Vector3(0.76, 1.3, 0.76), Vector3(bx, FLOOR + 0.65, bz), green, "Boiler")
	face(root, tex("kotel", "boiler"), "boiler", Vector2(0.76, 1.3), Vector3(bx - 0.382, FLOOR + 0.65, bz), Vector3(-1, 0, 0), "BoilerFront")
	var flue := K.surface("galvanized", 0.5, Color(0.4, 0.38, 0.36))
	K.slab(root, Vector3(0.2, B_H - 1.3, 0.2), Vector3(bx + 0.08, FLOOR + 1.3 + (B_H - 1.3) * 0.5, bz - 0.08), flue, "Flue")
	var glow := OmniLight3D.new()
	glow.name = "BoilerGlow"
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 0.35
	glow.omni_range = 2.2
	glow.position = Vector3(bx - 0.6, FLOOR + 0.35, bz)
	root.add_child(glow)
	K.cutout(root, tex("coal_pile", "pub_coal"), Vector2(0.7, 0.45), Vector3(B_MIN.x + 0.85, FLOOR, B_MIN.y + 0.35), 0.0, false, "Coal")
	# The warden's mattress on the floor, a pillow and a grey blanket.
	var mat_tex := K.surface(tex("mattress_stain", "mattress"), 0.9)
	var node := Node3D.new()
	node.name = "Mattress"
	node.position = MATTRESS
	root.add_child(node)
	K.slab(node, MATTRESS_SIZE, Vector3(0, MATTRESS_SIZE.y * 0.5, 0), mat_tex, "MattressBody")
	K.slab(node, Vector3(0.44, 0.08, 0.3), Vector3(0, MATTRESS_SIZE.y + 0.04, -0.72), K.surface("blanket_grey", 0.5, Color(0.92, 0.9, 0.86)), "Pillow")
	K.slab(node, Vector3(0.74, 0.03, 0.8), Vector3(0, MATTRESS_SIZE.y + 0.015, 0.45), K.surface("blanket_grey", 0.6), "Blanket")
	out["mattress"] = node
	# The lockers along the front wall, their doors to the room.
	for i in MAX_LOCKERS:
		var x := LOCKERS_X0 + LOCKER_W * (float(i) + 0.5)
		var lk := Node3D.new()
		lk.name = "Locker%d" % i
		lk.position = Vector3(x, FLOOR, LOCKER_Z)
		root.add_child(lk)
		K.slab(lk, Vector3(LOCKER_W - 0.02, 1.8, 0.48), Vector3(0, 0.9, 0), K.surface("metal_green", 0.5, Color(0.7, 0.76, 0.72)), "LockerBox")
		var shut := face(lk, tex("staff_locker", "metal_green"), "metal_green", Vector2(LOCKER_W - 0.03, 1.78), Vector3(0, 0.9, -0.242), Vector3(0, 0, -1), "LockerDoor")
		var open := face(lk, tex("staff_locker_open", "metal_green"), "metal_green", Vector2(LOCKER_W - 0.03, 1.78), Vector3(0, 0.9, -0.243), Vector3(0, 0, -1), "LockerInside")
		open.visible = false
		out["lockers"].append(lk)
		out["lockers_open"].append([shut, open])
		out["hot"]["locker%d" % i] = [Vector3(x, FLOOR + 0.9, LOCKER_Z - 0.2), Vector3(LOCKER_W - 0.02, 1.8, 0.2)]
	# The bare bulb.
	var bulb := K.slab(root, Vector3(0.07, 0.1, 0.07), Vector3((B_MIN.x + B_MAX.x) * 0.5, FLOOR + B_H - 0.35, 0.0), K.surface("enamel_white", 0.3), "Bulb")
	K.slab(root, Vector3(0.01, 0.3, 0.01), Vector3((B_MIN.x + B_MAX.x) * 0.5, FLOOR + B_H - 0.15, 0.0), K.surface("planks_dark", 0.3), "BulbCord")
	out["lamp_meshes"].append(bulb)


# ── the windows ───────────────────────────────────────────────────────────────

## Old window glass seen from the camp: a little dark and green, the sky's sheen on it
## when you look along it, clear enough to see the room behind (its own shader: the PS1
## conversion of retro_materials would make it a solid pane).
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = mix(vec3(0.05, 0.07, 0.07), vec3(0.55, 0.62, 0.66), f);
	ALPHA = 0.18 + 0.5 * f;
}
"""
static var _glass_material: ShaderMaterial


static func _glass_mat() -> ShaderMaterial:
	if _glass_material == null:
		var sh := Shader.new()
		sh.code = GLASS_SHADER
		_glass_material = ShaderMaterial.new()
		_glass_material.shader = sh
	return _glass_material


## In the camp: glass in each window (dark, a little see-through), its frame, and the
## curtains as a slab drawn shut or two bunched at the sides (staffroom.gd sets which).
## Inside, the room makes them real (window_portal.gd).
static func _windows(root: Node3D, out: Dictionary, camp: bool) -> void:
	if not camp:
		return
	var frame := K.surface("enamel_white", 0.4, Color(0.9, 0.88, 0.82))
	var cloth := K.surface("curtain_floral", 0.7)
	for id in WINDOW_ORDER:
		var w: Dictionary = WINDOWS[id]
		var c: Vector3 = w["c"]
		var s: Vector2 = w["size"]
		var o: Vector3 = w["out"]
		var across := Vector3(-o.z, 0, o.x)
		var glass := MeshInstance3D.new()
		glass.name = "Glass_" + id
		var q := QuadMesh.new()
		q.size = s
		glass.mesh = q
		glass.material_override = _glass_mat()
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glass.position = c + o * (WALL * 0.6)
		glass.rotation.y = atan2(o.x, o.z)
		root.add_child(glass)
		out["glass"][id] = glass
		# The white frame: sill, head, the two sides and the middle bar.
		var at := c + o * (WALL * 0.6)
		var fsize := Vector3(absf(across.x) * (s.x + 0.1) + absf(o.x) * 0.06, 0.05, absf(across.z) * (s.x + 0.1) + absf(o.z) * 0.06)
		K.slab(root, fsize, at + Vector3(0, -s.y * 0.5 - 0.02, 0), frame, "WinSill")
		K.slab(root, fsize, at + Vector3(0, s.y * 0.5 + 0.02, 0), frame, "WinHead")
		var side := Vector3(absf(across.x) * 0.05 + absf(o.x) * 0.06, s.y, absf(across.z) * 0.05 + absf(o.z) * 0.06)
		for k: float in [-1.0, 1.0]:
			K.slab(root, side, at + across * k * (s.x * 0.5 + 0.02), frame, "WinSide")
		K.slab(root, Vector3(absf(across.x) * 0.03 + absf(o.x) * 0.04, s.y, absf(across.z) * 0.03 + absf(o.z) * 0.04), at, frame, "WinBar")
		# The curtains behind the glass.
		var cat := c - o * 0.08
		var cs := Vector3(absf(across.x) * (s.x + 0.16) + absf(o.x) * 0.02, s.y + 0.18, absf(across.z) * (s.x + 0.16) + absf(o.z) * 0.02)
		var shut := K.slab(root, cs, cat, cloth, "CurtainShut")
		var bunch := Vector3(absf(across.x) * 0.16 + absf(o.x) * 0.04, s.y + 0.18, absf(across.z) * 0.16 + absf(o.z) * 0.04)
		var ol := K.slab(root, bunch, cat - across * (s.x * 0.5 + 0.02), cloth, "CurtainL")
		var orr := K.slab(root, bunch, cat + across * (s.x * 0.5 + 0.02), cloth, "CurtainR")
		shut.visible = false
		out["curtains"][id] = [shut, ol, orr]
