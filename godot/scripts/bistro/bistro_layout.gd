extends RefCounted

## The bistro's three rooms (DESIGN.md §7b), built for scripts/service_interior.gd:
##   dining   a roadside bufet: oil-painted walls, checker lino, four gingham tables
##            (two chairs each, a carnation, the cruet, an ashtray), the counter on the
##            right with the till, the books, the cake case and the Kofola tap, the
##            serving hatch into the kitchen beside its door, the menu board, windows with
##            net curtains on the left, a television up in the corner, fly paper.
##   kitchen  white tiles to the shoulder and oil paint over them: the stove (pan and
##            fryer) and the goulash pot on its ring along the back under the hood, the
##            dumpling steamer and board, the pass along the left wall under the hatch
##            (red heat lamps, the bell), the sink and the plate rack on the right, the
##            island in the middle, the cellar door at the right.
##   cellar   brick and concrete under a bare bulb: the potato peeler and the chip cutter
##            on the left, the breading table on the right by the stairs, the shelves of
##            stock at the back (filled from the books: service_interior._fill_cellar),
##            and behind a chain-link partition in the far corner the machine nobody
##            ordered.
## Every station is a click box with meta "bistro_station" (STATIONS); the things worth a
## look have meta "bistro_look" (a line about them, shown under the room like the
## sentence of an old adventure game: scripts/bistro/room_sentence.gd).
## Pictures are camp textures (assets/textury/camp/, Grok); a missing one is left out.

const K := preload("res://scripts/interior_kit.gd")
const TEX := "res://assets/textury/camp/"
const SIZE := Vector3(6.2, 2.9, 4.8)

## The guests' tables in the dining room (room coordinates, on the floor).
const TABLES := [Vector3(-2.05, 0.05, -1.35), Vector3(-2.05, 0.05, 0.35), Vector3(-0.2, 0.05, -1.45), Vector3(0.2, 0.05, 0.0)]

## The stations: id -> {room, at (click box centre), size, stand (where the warden stands
## at it, on the floor), pose (their picture there), mark (where its status hangs), label}.
const STATIONS := {
	"stove": {"room": "kitchen", "at": Vector3(-1.15, 0.6, -1.95), "size": Vector3(1.7, 0.9, 0.95), "stand": Vector3(-1.15, 0.05, -1.2), "pose": "cook", "mark": Vector3(-1.15, 1.75, -1.95), "label": "the stove"},
	"pot": {"room": "kitchen", "at": Vector3(1.2, 0.6, -1.95), "size": Vector3(1.7, 0.9, 0.95), "stand": Vector3(1.2, 0.05, -1.2), "pose": "cook", "mark": Vector3(1.2, 1.75, -1.95), "label": "the goulash pot"},
	"pass": {"room": "kitchen", "at": Vector3(-2.62, 0.6, -0.45), "size": Vector3(0.95, 0.9, 1.7), "stand": Vector3(-1.9, 0.05, -0.45), "pose": "cook", "mark": Vector3(-2.62, 1.85, -0.45), "label": "the pass"},
	"sink": {"room": "kitchen", "at": Vector3(2.62, 0.6, -0.35), "size": Vector3(0.95, 0.9, 1.7), "stand": Vector3(1.9, 0.05, -0.35), "pose": "wash", "mark": Vector3(2.62, 1.75, -0.35), "label": "the sink"},
	"potatoes": {"room": "basement", "at": Vector3(-2.85, 0.72, -0.55), "size": Vector3(0.5, 1.4, 2.4), "stand": Vector3(-2.0, 0.05, -0.55), "pose": "cook", "mark": Vector3(-2.7, 1.75, -0.55), "label": "the potatoes"},
	"breading": {"room": "basement", "at": Vector3(2.5, 0.5, -0.55), "size": Vector3(0.95, 0.8, 1.7), "stand": Vector3(1.8, 0.05, -0.55), "pose": "cook", "mark": Vector3(2.5, 1.55, -0.55), "label": "the breading table"},
	"machine": {"room": "basement", "at": Vector3(1.45, 0.75, -2.2), "size": Vector3(2.4, 1.4, 0.4), "stand": Vector3(1.2, 0.05, -1.2), "pose": "stand", "mark": Vector3(1.45, 1.75, -2.2), "label": "the machine"},
}
## Where each station's surface lies (its picture, live: station_view.surface_texture):
## the centre, the size in metres (the picture's 16:9), the way the picture's top edge
## faces (yaw: 0 the back wall, 90 the left wall, -90 the right wall), lying on a counter
## (`flat`) or standing on a wall.
const SURFACES := {
	"stove": {"at": Vector3(-1.15, 0.952, -1.95), "size": Vector2(1.6, 0.9), "yaw": 0.0, "flat": true},
	"pot": {"at": Vector3(1.2, 0.952, -1.95), "size": Vector2(1.6, 0.9), "yaw": 0.0, "flat": true},
	"pass": {"at": Vector3(-2.62, 0.952, -0.45), "size": Vector2(1.6, 0.9), "yaw": 90.0, "flat": true},
	"sink": {"at": Vector3(2.62, 0.952, -0.35), "size": Vector2(1.6, 0.9), "yaw": -90.0, "flat": true},
	"potatoes": {"at": Vector3(-3.08, 0.72, -0.55), "size": Vector2(2.4, 1.35), "yaw": 90.0, "flat": false},
	"breading": {"at": Vector3(2.5, 0.802, -0.55), "size": Vector2(1.6, 0.9), "yaw": -90.0, "flat": true},
	"machine": {"at": Vector3(1.45, 0.72, -2.38), "size": Vector2(2.4, 1.35), "yaw": 0.0, "flat": false},
}
## The camera over a station: how far back along the way it faces, how far up the angle
## from straight down (flat ones) or level (wall ones).
const CAM_BACK := 0.62
const CAM_UP := 0.98
const CAM_WALL := 1.25


## The station's surface: a quad named Surface_<id> its picture goes on (the room puts the
## texture on it once the station exists).
static func surface(parent: Node3D, id: String) -> MeshInstance3D:
	var d: Dictionary = SURFACES[id]
	var mi := MeshInstance3D.new()
	mi.name = "Surface_" + id
	var q := QuadMesh.new()
	q.size = d["size"]
	if bool(d["flat"]):
		q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	# Lit by the room, a little of its own so it reads under a dim bulb.
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission = Color(0.35, 0.33, 0.3)
	mi.material_override = m
	mi.position = d["at"]
	mi.rotation_degrees.y = float(d["yaw"])
	mi.set_meta("bistro_surface", id)
	parent.add_child(mi)
	return mi


## Where the camera goes over station `id` (room coordinates): [position, the point it
## looks at].
static func pose(id: String) -> Array:
	var d: Dictionary = SURFACES[id]
	var c: Vector3 = d["at"]
	var yaw := deg_to_rad(float(d["yaw"]))
	# The picture's top edge faces `away`; the cook stands the other way.
	var away := Vector3(-sin(yaw), 0.0, -cos(yaw))
	if bool(d["flat"]):
		var sz: Vector2 = d["size"]
		var k := sz.x / 1.6
		return [c - away * (CAM_BACK * k) + Vector3(0, CAM_UP * k, 0), c - away * 0.04]
	return [c - away * CAM_WALL + Vector3(0, 0.1, 0), c]


## The surface's point (its picture's pixels, 640x360) a ray hits, or (-1, -1).
static func surface_point(mi: MeshInstance3D, from: Vector3, dir: Vector3) -> Vector2:
	var d: Dictionary = SURFACES[str(mi.get_meta("bistro_surface"))]
	var inv := mi.global_transform.affine_inverse()
	var o := inv * from
	var r := inv.basis * dir
	var sz: Vector2 = d["size"]
	var u := 0.0
	var v := 0.0
	if bool(d["flat"]):
		if absf(r.y) < 0.0001:
			return Vector2(-1, -1)
		var t := -o.y / r.y
		if t < 0.0:
			return Vector2(-1, -1)
		var hit := o + r * t
		u = hit.x / sz.x + 0.5
		v = hit.z / sz.y + 0.5
	else:
		if absf(r.z) < 0.0001:
			return Vector2(-1, -1)
		var t := -o.z / r.z
		if t < 0.0:
			return Vector2(-1, -1)
		var hit := o + r * t
		u = hit.x / sz.x + 0.5
		v = 0.5 - hit.y / sz.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1, -1)
	return Vector2(u * 640.0, v * 360.0)


## A counter under a flat surface: a steel (or wooden) body to the floor, its top just
## under the picture.
static func _counter(parent: Node3D, id: String, mat: Material, top := 0.95) -> void:
	var d: Dictionary = SURFACES[id]
	var sz: Vector2 = d["size"]
	var c: Vector3 = d["at"]
	var along_x := absf(float(d["yaw"])) < 1.0
	var size := Vector3(sz.x + 0.06, top - 0.05, sz.y + 0.06) if along_x else Vector3(sz.y + 0.06, top - 0.05, sz.x + 0.06)
	K.slab(parent, size, Vector3(c.x, 0.05 + (top - 0.05) * 0.5 - 0.002, c.z), mat, "Counter_" + id)


static func has_tex(n: String) -> bool:
	return ResourceLoader.exists(TEX + n + ".png")


## A cutout if its picture is there (K.cutout leaves a white quad without one).
static func _cut(parent: Node3D, n: String, size: Vector2, pos: Vector3, yaw := 0.0, billboard := false, node_name := "Cutout") -> MeshInstance3D:
	if not has_tex(n):
		return null
	return K.cutout(parent, n, size, pos, yaw, billboard, node_name)


static func _pic(parent: Node3D, n: String, size: Vector2, pos: Vector3, yaw := 0.0, node_name := "Picture") -> MeshInstance3D:
	if not has_tex(n):
		return null
	return K.picture(parent, n, size, pos, yaw, node_name)


## A box you can click for a look: meta bistro_look = what is said about it.
static func look(parent: Node3D, name: String, line: String, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Look_" + name.replace(" ", "")
	body.set_meta("interior_click_type", "bistro_look")
	body.set_meta("bistro_look", line)
	body.set_meta("bistro_name", name)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	parent.add_child(body)
	return body


## The click box of a station (meta bistro_station = its id) in its room.
static func station_body(parent: Node3D, id: String) -> StaticBody3D:
	var st: Dictionary = STATIONS[id]
	var body := StaticBody3D.new()
	body.name = "Station_" + id
	body.set_meta("interior_click_type", "bistro_station")
	body.set_meta("bistro_station", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = st["size"]
	shape.shape = box
	body.add_child(shape)
	body.position = st["at"]
	parent.add_child(body)
	return body


static func _glow(m: StandardMaterial3D, col: Color, energy: float) -> void:
	if m == null:
		return
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_texture = m.albedo_texture
	m.emission = col
	m.emission_energy_multiplier = energy


static func _flat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


static func _cyl(parent: Node3D, r: float, h: float, at: Vector3, mat: Material, node_name := "Cyl", segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	mi.mesh = c
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## A fluorescent tube in its fitting on the ceiling, lit.
static func _tube(parent: Node3D, at: Vector3, length := 1.2) -> void:
	K.slab(parent, Vector3(length + 0.1, 0.06, 0.16), at + Vector3(0, 0.03, 0), K.surface("steel_kitchen", 0.5, Color(0.85, 0.85, 0.82)), "TubeFitting")
	var tube := K.slab(parent, Vector3(length, 0.04, 0.05), at - Vector3(0, 0.02, 0), _flat(Color(0.95, 0.97, 0.92)), "Tube")
	var m := tube.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(0.9, 0.95, 0.88)
	m.emission_energy_multiplier = 1.2


# ── the dining room ──────────────────────────────────────────────────────────

static func dining(parent: Node3D, si) -> void:
	K.room(parent, SIZE, "lino_checker", "oil_wall", "ceiling_board", SIZE.y, 0.9, 0.05)
	K.skirting(parent, SIZE, "planks_dark", 0.05)
	# The counter on the right: the till, the books (service_interior puts them), the cake
	# case, the Kofola tap, the fridge behind; a price list on the wall over it.
	K.prop(parent, "shop_counter", Vector3(2.0, 0.05, -1.25))
	K.prop(parent, "fridge_tall", Vector3(2.7, 0.05, -2.0))
	_cut(parent, "shop_till", Vector2(0.34, 0.3), Vector3(2.45, 1.0, -1.25), -20.0, false, "Till")
	_cut(parent, "bistro_cakes", Vector2(0.62, 0.5), Vector3(2.05, 1.0, -1.05), 0.0, false, "CakeCase")
	_cut(parent, "bistro_tap", Vector2(0.3, 0.42), Vector3(1.6, 1.0, -1.35), 0.0, false, "KofolaTap")
	K.prop(parent, "radio_set", Vector3(2.75, 1.0, -1.45), -30.0)
	look(parent, "cake case", "Laskonky, a vetrnik, two rakvicky. The same ones as on Monday.", Vector3(2.05, 1.25, -1.05), Vector3(0.6, 0.5, 0.3))
	look(parent, "Kofola tap", "Kofola on draught. The line hisses when nobody's pouring.", Vector3(1.6, 1.2, -1.35), Vector3(0.3, 0.45, 0.3))
	# The menu board over the tables, chalk prices, and the sign.
	var board := K.slab(parent, Vector3(1.9, 0.86, 0.04), Vector3(-1.45, 1.92, -2.36), K.surface("ceiling_board", 4.0, Color(0.32, 0.34, 0.3)), "MenuBoard")
	board.name = "DiningMenuBoard"
	K.slab(parent, Vector3(1.98, 0.94, 0.03), Vector3(-1.45, 1.92, -2.385), K.surface("planks_dark", 0.6), "MenuFrame")
	var menu := Label3D.new()
	menu.text = "DNES VARIME / TODAY\nGoulash, dumplings ...... $7\nFried cheese, chips ..... $8\nChips, tartar ........... $3\nKofola .................. $2"
	menu.position = Vector3(-1.45, 1.92, -2.33)
	menu.font_size = 18
	menu.modulate = Color(0.92, 0.92, 0.86, 0.95)
	menu.outline_size = 0
	menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(menu)
	look(parent, "menu board", "Somebody rubbed out SVICKOVA and never wrote anything in its place.", Vector3(-1.45, 1.92, -2.3), Vector3(1.9, 0.86, 0.1))
	si._sign(parent, "BUFET\ndiner", Vector3(-1.45, 2.6, -2.33), 30, "enamel")
	# The hatch into the kitchen, beside its door: a steel sill, the kitchen lit behind.
	hatch(parent, Vector3(0.45, 1.3, -2.4))
	look(parent, "hatch", "The hatch to the kitchen. Plates come out of it by themselves when the kitchen is busy.", Vector3(0.45, 1.35, -2.33), Vector3(0.9, 0.55, 0.1))
	# Windows on the left with net curtains and geraniums, the radiator under them.
	# The weather at them (scripts/ambient/room_weather.gd): rain on the glass, lightning.
	var rw = load("res://scripts/ambient/room_weather.gd").new()
	parent.add_child(rw)
	for z: float in [-1.35, 0.55]:
		rw.add_window(_pic(parent, "window_view", Vector2(0.9, 0.8), Vector3(-3.08, 1.55, z), 90.0, "Window"))
		_pic(parent, "window_curtain", Vector2(0.96, 0.86), Vector3(-3.06, 1.55, z), 90.0, "NetCurtain")
		K.slab(parent, Vector3(0.18, 0.04, 1.0), Vector3(-3.02, 1.12, z), K.surface("planks_dark", 0.5), "Sill")
		_cut(parent, "plant_dry", Vector2(0.24, 0.3), Vector3(-2.98, 1.14, z + 0.25), 90.0, false, "Geranium")
		K.slab(parent, Vector3(0.08, 0.5, 0.9), Vector3(-3.04, 0.45, z), K.surface("galvanized", 0.3, Color(0.85, 0.82, 0.76)), "Radiator")
	look(parent, "window", "The car park, the bins, the forest. A man stood by the bins yesterday for an hour.", Vector3(-3.0, 1.55, -1.35), Vector3(0.1, 0.8, 0.9))
	_pic(parent, "picture_deer", Vector2(0.5, 0.66), Vector3(-3.06, 1.75, -0.4), 90.0, "Deer")
	look(parent, "deer", "A stag in a clearing. Its eyes were painted in later, by somebody else.", Vector3(-3.0, 1.75, -0.4), Vector3(0.1, 0.66, 0.5))
	_pic(parent, "poster_mushrooms", Vector2(0.5, 0.66), Vector3(3.06, 1.65, 0.6), -90.0, "Mushrooms")
	look(parent, "mushroom chart", "EDIBLE and POISONOUS. Somebody has drawn a third column in pencil.", Vector3(3.0, 1.65, 0.6), Vector3(0.1, 0.66, 0.5))
	_cut(parent, "wall_clock", Vector2(0.3, 0.3), Vector3(0.1, 2.25, -2.37), 0.0, false, "Clock")
	look(parent, "clock", "Four minutes slow, as always. Today it is fast.", Vector3(0.1, 2.4, -2.33), Vector3(0.32, 0.32, 0.1))
	_pic(parent, "calendar", Vector2(0.32, 0.46), Vector3(3.06, 1.6, -0.2), -90.0, "Calendar")
	# A television up in the corner on its bracket, the test card on it.
	var tv := _cut(parent, "bistro_tv", Vector2(0.55, 0.5), Vector3(2.85, 2.1, 1.2), -60.0, false, "TV")
	if tv == null:
		K.prop(parent, "tv_small", Vector3(2.8, 2.05, 1.1), -60.0)
	look(parent, "television", "It is on with the sound off. Nobody has the remote.", Vector3(2.8, 2.3, 1.15), Vector3(0.5, 0.45, 0.45))
	# Fly paper over the middle table, the fan, two tubes.
	_cut(parent, "bistro_flypaper", Vector2(0.1, 0.5), Vector3(-0.2, 2.35, -1.45), 20.0, true, "FlyPaper")
	look(parent, "fly paper", "Fourteen flies. Fifteen.", Vector3(-0.2, 2.6, -1.45), Vector3(0.15, 0.5, 0.15))
	_tube(parent, Vector3(-1.2, 2.88, -0.6))
	_tube(parent, Vector3(1.4, 2.88, -0.6))
	# The coat stand by the door you came in at, a coat on it.
	_cut(parent, "bistro_coatstand", Vector2(0.55, 1.75), Vector3(-2.75, 0.05, 1.9), 0.0, true, "CoatStand")
	look(parent, "coat stand", "A grey coat and a hat. Nobody came in wearing them.", Vector3(-2.75, 1.0, 1.9), Vector3(0.5, 1.7, 0.5))
	_cut(parent, "extinguisher", Vector2(0.2, 0.5), Vector3(2.98, 0.6, 1.0), -90.0, false, "Extinguisher")
	_cut(parent, "plastic_plant", Vector2(0.45, 0.8), Vector3(2.75, 0.05, 1.9), 0.0, true, "Plant")
	si._sign(parent, "NEKOURIT\nno smoking", Vector3(1.0, 2.35, -2.35), 18, "danger")
	# The tables: gingham, a chair each side, the carnation, the cruet, the ashtray.
	for t: Vector3 in TABLES:
		K.prop(parent, "gingham_table", t)
		K.prop(parent, "chair_wood", t + Vector3(-0.55, 0, 0), 90.0)
		K.prop(parent, "chair_wood", t + Vector3(0.55, 0, 0), -90.0)
		_cut(parent, "ashtray", Vector2(0.15, 0.13), t + Vector3(0.14, 0.76, -0.14), 0.0, true, "Ashtray")
		_cut(parent, "bistro_vase", Vector2(0.1, 0.28), t + Vector3(-0.05, 0.76, -0.18), 0.0, true, "Vase")
		_cut(parent, "bistro_cruet", Vector2(0.16, 0.14), t + Vector3(-0.18, 0.76, -0.12), 0.0, true, "Cruet")


## The hatch through a wall (its sill at `at.y - 0.3`): a dark opening, the light of
## the other side in it, a steel sill and frame.
static func hatch(parent: Node3D, at: Vector3, yaw := 0.0) -> Node3D:
	var h := Node3D.new()
	h.name = "Hatch"
	h.position = at
	h.rotation_degrees.y = yaw
	parent.add_child(h)
	var steel := K.surface("steel_brushed", 0.9)
	var hole := K.slab(h, Vector3(0.84, 0.5, 0.02), Vector3(0, 0, 0.012), _flat(Color(0.36, 0.3, 0.22)), "HatchHole")
	var m := hole.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(0.85, 0.7, 0.45)
	m.emission_energy_multiplier = 0.35
	K.slab(h, Vector3(0.96, 0.05, 0.28), Vector3(0, -0.27, 0.1), steel, "HatchSill")
	K.slab(h, Vector3(0.96, 0.05, 0.06), Vector3(0, 0.27, 0.03), steel, "HatchTop")
	K.slab(h, Vector3(0.05, 0.56, 0.06), Vector3(-0.46, 0, 0.03), steel, "HatchSide")
	K.slab(h, Vector3(0.05, 0.56, 0.06), Vector3(0.46, 0, 0.03), steel, "HatchSide")
	return h


# ── the kitchen ──────────────────────────────────────────────────────────────

static func kitchen(parent: Node3D, si) -> void:
	K.room(parent, SIZE, "lino_checker", "oil_wall", "ceiling_board", SIZE.y, 0.9, 0.05)
	K.skirting(parent, SIZE, "steel_kitchen", 0.05)
	# White tiles to the shoulder round all four walls, not over the doors (their dark
	# and their leaves sit on the wall's face) nor the hatch.
	var tiles := K.surface("kitchen_tiles", 0.9)
	var th := 1.6
	K.slab(parent, Vector3(SIZE.x, th, 0.02), Vector3(0, 0.05 + th * 0.5, -SIZE.z * 0.5 + 0.012), tiles, "TilesBack")
	K.slab(parent, Vector3(SIZE.x, th, 0.02), Vector3(0, 0.05 + th * 0.5, SIZE.z * 0.5 - 0.012), tiles, "TilesFront")
	# Along the side walls: [from z, to z, height].
	for seg: Array in [[-2.4, -0.95, th], [-0.95, 0.05, 0.98], [0.05, 0.9, th], [2.0, 2.4, th]]:
		var len := float(seg[1]) - float(seg[0])
		K.slab(parent, Vector3(0.02, float(seg[2]), len), Vector3(-SIZE.x * 0.5 + 0.012, 0.05 + float(seg[2]) * 0.5, (float(seg[0]) + float(seg[1])) * 0.5), tiles, "TilesLeft")
	for seg: Array in [[-2.4, 0.9, th], [2.0, 2.4, th]]:
		var len := float(seg[1]) - float(seg[0])
		K.slab(parent, Vector3(0.02, float(seg[2]), len), Vector3(SIZE.x * 0.5 - 0.012, 0.05 + float(seg[2]) * 0.5, (float(seg[0]) + float(seg[1])) * 0.5), tiles, "TilesRight")
	# Brushed stainless (Grok, camp/steel_brushed.png): the old dented sheet read as stone
	# on anything this big.
	var steel := K.surface("steel_brushed", 1.2, Color(0.62, 0.63, 0.64))
	# The hood over the stove.
	K.slab(parent, Vector3(1.8, 0.5, 0.8), Vector3(-1.15, 2.45, -1.98), steel, "Hood")
	# The stove and the pot: counters along the back, their tops the stations' live
	# surfaces (the pan, the fryer; the pot, the board, the steamer).
	_counter(parent, "stove", steel)
	surface(parent, "stove")
	_counter(parent, "pot", steel)
	surface(parent, "pot")
	K.prop(parent, "steel_counter", Vector3(-2.45, 0.05, -2.06), 0.0, 0.85)
	_cut(parent, "bistro_ladles", Vector2(1.0, 0.5), Vector3(1.4, 1.55, -2.36), 0.0, false, "Ladles")
	_cut(parent, "bistro_knives", Vector2(0.6, 0.22), Vector3(-2.45, 1.45, -2.36), 0.0, false, "Knives")
	look(parent, "knives", "Four knives on the magnet. There is a place for a fifth.", Vector3(-2.45, 1.45, -2.33), Vector3(0.6, 0.25, 0.1))
	_cut(parent, "bistro_zapper", Vector2(0.4, 0.28), Vector3(0.0, 2.25, 2.35), 180.0, false, "FlyZapper")
	si._sign(parent, "KUCHYNE\nkitchen", Vector3(-0.2, 2.06, -2.36), 26, "enamel")
	var wash_sign: Node3D = si._sign(parent, "MYJTE SI RUCE\nwash your hands", Vector3(2.45, 1.85, 2.37), 14, "enamel")
	wash_sign.rotation_degrees.y = 180.0
	# The pass along the left wall, under the hatch to the dining room: heat lamps, bell.
	_counter(parent, "pass", steel)
	surface(parent, "pass")
	hatch(parent, Vector3(-3.1, 1.35, -0.45), 90.0)
	# The heat shelf over the pass: a steel shelf on brackets, two lamp hoods under it
	# glowing red on the plates waiting.
	K.slab(parent, Vector3(0.42, 0.04, 1.7), Vector3(-2.86, 2.0, -0.45), steel, "HeatShelf")
	for z: float in [-0.85, -0.05]:
		_cyl(parent, 0.1, 0.12, Vector3(-2.78, 1.92, z), _flat(Color(0.18, 0.18, 0.19)), "LampHood", 10)
		var glow := _cyl(parent, 0.075, 0.01, Vector3(-2.78, 1.855, z), _flat(Color(0.9, 0.2, 0.1)), "LampGlow", 10)
		(glow.material_override as StandardMaterial3D).emission_enabled = true
		(glow.material_override as StandardMaterial3D).emission = Color(1.0, 0.25, 0.1)
		(glow.material_override as StandardMaterial3D).emission_energy_multiplier = 2.0
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.35, 0.18)
		l.light_energy = 0.5
		l.omni_range = 1.3
		l.position = Vector3(-2.72, 1.6, z)
		parent.add_child(l)
	_cut(parent, "bistro_bell", Vector2(0.14, 0.12), Vector3(-2.95, 1.07, -0.05), 90.0, false, "Bell")
	# The sink and the plate rack on the right, the fridge in the corner.
	_counter(parent, "sink", steel)
	surface(parent, "sink")
	K.prop(parent, "fridge_tall", Vector3(2.72, 0.05, -1.75), -90.0)
	# The island: the board, onions, eggs, the flour sacks under it.
	K.prop(parent, "steel_counter", Vector3(0.0, 0.05, 0.25), 0.0, 0.8)
	_cut(parent, "bistro_flour", Vector2(0.45, 0.55), Vector3(-0.3, 0.05, 0.5), 0.0, true, "FlourSack")
	_cut(parent, "bistro_stockpot", Vector2(0.4, 0.36), Vector3(0.3, 0.92, 0.25), 0.0, true, "StockPot")
	look(parent, "stock pot", "Bones for the broth. They have been simmering since before you came.", Vector3(0.3, 1.1, 0.25), Vector3(0.4, 0.36, 0.4))
	_tube(parent, Vector3(-1.0, 2.88, 0.0))
	_tube(parent, Vector3(1.2, 2.88, 0.0))
	_pic(parent, "calendar", Vector2(0.32, 0.46), Vector3(-3.06, 1.95, 1.0), 90.0, "Calendar")
	look(parent, "calendar", "1987. Every Thursday ringed in red.", Vector3(-3.0, 1.95, 1.0), Vector3(0.1, 0.46, 0.32))


## The plates waiting at the sink are on its surface now (sink_station.gd draws them).
static func dirty_pile(_parent: Node3D, _n: int) -> void:
	pass


# ── the cellar ───────────────────────────────────────────────────────────────

static func cellar(parent: Node3D, si) -> Node3D:
	var size := Vector3(6.2, 2.7, 4.8)
	K.room(parent, size, "concrete", "brick_red", "concrete", 1.0, 1.2, 0.05)
	# Pipes along the ceiling, the drain in the floor, a puddle.
	for z: float in [-1.9, -1.6]:
		var pipe := _cyl(parent, 0.05, size.x, Vector3(0, 2.55, z), K.surface("galvanized", 0.5, Color(0.7, 0.6, 0.5)), "Pipe", 8)
		pipe.rotation_degrees.z = 90.0
	K.slab(parent, Vector3(0.3, 0.01, 0.3), Vector3(0.2, 0.055, 0.6), _flat(Color(0.12, 0.12, 0.12)), "Drain")
	var puddle := K.slab(parent, Vector3(0.8, 0.005, 0.5), Vector3(0.0, 0.054, 0.4), _flat(Color(0.2, 0.22, 0.22)), "Puddle")
	(puddle.material_override as StandardMaterial3D).roughness = 0.05
	look(parent, "drain", "The drain gurgles. Then, a while later, it gurgles again somewhere further off.", Vector3(0.2, 0.1, 0.6), Vector3(0.4, 0.1, 0.4))
	# The potato corner on the left: the peeler drum, the chip cutter on its table, the
	# sack, the bucket.
	# The potato corner is its surface on the left wall (the peeler, the cutter, the sack,
	# the bucket: st_potatoes), the breading table its top by the stairs.
	surface(parent, "potatoes")
	var wood := K.surface("planks_dark", 0.8)
	_counter(parent, "breading", wood, 0.8)
	surface(parent, "breading")
	# The shelves of stock at the back left (the books' goods stood on them each visit).
	K.prop(parent, "wall_shelf", Vector3(-1.4, 1.4, -2.3), 0.0, 1.6)
	_cut(parent, "bistro_jars", Vector2(0.9, 0.45), Vector3(-1.4, 1.45, -2.3), 0.0, false, "Jars")
	look(parent, "jars", "Gherkins, 1986. One jar is labelled in a hand you do not know: DO NOT OPEN.", Vector3(-1.4, 1.65, -2.25), Vector3(0.9, 0.45, 0.2))
	# The machine in the far right corner behind the chain-link partition.
	var bars := K.surface("galvanized", 0.3, Color(0.55, 0.55, 0.52))
	for i in [0, 4, 8]:
		K.slab(parent, Vector3(0.04, 2.2, 0.04), Vector3(0.25 + i * 0.3, 1.15, -0.95), bars, "FencePost")
	# The mesh between the posts (Grok, camp/chainlink.png, see-through), the gate ajar.
	if has_tex("chainlink"):
		var mesh := StandardMaterial3D.new()
		mesh.albedo_texture = load(TEX + "chainlink.png")
		mesh.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.uv1_scale = Vector3(4.0, 3.6, 1.0)
		var wire := MeshInstance3D.new()
		wire.name = "ChainLink"
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 2.1)
		wire.mesh = q
		wire.material_override = mesh
		wire.position = Vector3(0.85, 1.15, -0.95)
		parent.add_child(wire)
		var gate := MeshInstance3D.new()
		gate.name = "ChainLinkGate"
		var gq := QuadMesh.new()
		gq.size = Vector2(0.9, 2.1)
		gate.mesh = gq
		var gm := mesh.duplicate() as StandardMaterial3D
		gm.uv1_scale = Vector3(2.2, 3.6, 1.0)
		gate.material_override = gm
		gate.position = Vector3(2.05 + 0.32, 1.15, -0.95 + 0.3)
		gate.rotation_degrees.y = -40.0
		parent.add_child(gate)
	K.slab(parent, Vector3(2.5, 0.03, 0.03), Vector3(1.45, 2.25, -0.95), bars, "FenceTop")
	K.slab(parent, Vector3(2.5, 0.03, 0.03), Vector3(1.45, 0.15, -0.95), bars, "FenceFoot")
	# The machine is its surface on the back wall behind the partition (st_machine).
	surface(parent, "machine")
	# One bare bulb on its cord in the middle.
	K.slab(parent, Vector3(0.01, 0.5, 0.01), Vector3(0.0, 2.45, -0.3), _flat(Color(0.1, 0.1, 0.1)), "BulbCord")
	var bulb := _cyl(parent, 0.04, 0.08, Vector3(0.0, 2.17, -0.3), _flat(Color(1.0, 0.95, 0.8)), "Bulb", 8)
	(bulb.material_override as StandardMaterial3D).emission_enabled = true
	(bulb.material_override as StandardMaterial3D).emission = Color(1.0, 0.85, 0.6)
	var light := OmniLight3D.new()
	light.name = "CellarBulb"
	light.position = Vector3(0.0, 2.05, -0.3)
	light.light_color = Color(1.0, 0.84, 0.6)
	light.light_energy = 1.5
	light.omni_range = 5.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	parent.add_child(light)
	_cut(parent, "bistro_cobweb", Vector2(0.6, 0.5), Vector3(-3.0, 2.2, -2.3), 45.0, false, "Cobweb")
	_cut(parent, "bistro_cobweb", Vector2(0.5, 0.45), Vector3(3.0, 2.25, 2.3), -135.0, false, "Cobweb")
	_cut(parent, "bistro_trap", Vector2(0.2, 0.1), Vector3(-1.0, 0.05, -2.15), 0.0, true, "MouseTrap")
	look(parent, "mouse trap", "Set. The cheese is gone.", Vector3(-1.0, 0.1, -2.15), Vector3(0.25, 0.15, 0.2))
	si._sign(parent, "SKLEP\ncellar", Vector3(-0.2, 2.1, -2.33), 26, "enamel")
	return light
