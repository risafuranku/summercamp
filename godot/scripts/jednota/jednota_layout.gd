extends RefCounted

## The Jednota's two rooms (DESIGN.md §7b "The Jednota"), built for scripts/service_interior.gd
## the pub's way (scripts/pub/pub_layout.gd):
##   shop   a 1970s village samoobsluha: tiles, the walls in oil paint, two tubes; the long
##          green rack at the back with the cage trolley beside it (the shelves' station:
##          the goods on it are the shop's state, jednota.gd), the till's counter on the
##          right with the queue along it (the till's station), the bread rack, the fridge,
##          the shelf of tins and the ice-cream chest on the left, the baskets by the
##          door, the storeroom's door in the back wall.
##   store  the storeroom behind: concrete under a bare bulb; the packing table at the
##          back (the storeroom's station: the cartons off the van, the box cutter, the
##          price gun, the trolley), the cartons on their rack, the locker, the empties,
##          the corner where what went off waits to be thrown out.
## Every station is a click box with meta "bistro_station" (STATIONS), the things worth a
## look meta "bistro_look" (room_sentence.gd). SURFACES is where each station is worked
## (scripts/business/station3d.gd); the shelves' station is a wall the width of the rack
## and the trolley, the rack's picture its own quad (RACK_*), so the camera takes in both.

const K := preload("res://scripts/interior_kit.gd")
const BISTRO := preload("res://scripts/bistro/bistro_layout.gd")
const PUB := preload("res://scripts/pub/pub_layout.gd")
const STATION3D := preload("res://scripts/business/station3d.gd")
const TEX := "res://assets/textury/camp/"
const J := "res://assets/textury/jednota/"
const SIZE := Vector3(6.4, 3.0, 5.2)
const STORE := Vector3(4.8, 2.8, 4.0)

## The stations: id -> {room, at (click box centre), size, stand (where the warden stands
## at it), pose (their picture there), mark (where its status hangs), label, tab_label}.
## They go in the order of the work, as the frame's tabs and keys 1-9 number them
## (the user, 21. 10.: "1 husk, 2 serve and butter, 3 drinks: it should make sense
## everywhere"): what prepares first, then what makes and serves, then the side jobs.
## You come in at the till (where an order starts), the first time.
const ENTRY := "till"
const STATIONS := {
	"store": {"room": "store", "at": Vector3(-0.2, 0.95, -0.95), "size": Vector3(1.7, 0.2, 0.6), "stand": Vector3(-0.2, 0.05, -0.2), "pose": "bag", "mark": Vector3(-0.2, 1.75, -1.3), "label": "the packing table", "tab_label": "STOREROOM", "icon": "res://assets/textury/jednota/box_closed.png"},
	"shelves": {"room": "shop", "at": Vector3(-0.75, 0.72, -2.32), "size": Vector3(2.2, 1.3, 0.36), "stand": Vector3(-0.75, 0.05, -1.75), "pose": "fix", "mark": Vector3(-0.75, 1.62, -2.25), "label": "the shelves", "tab_label": "SHELVES", "icon": "res://assets/textury/jednota/goods_bread.png"},
	"till": {"room": "shop", "at": Vector3(2.0, 1.0, -0.2), "size": Vector3(0.65, 0.25, 1.65), "stand": Vector3(2.75, 0.05, -0.2), "pose": "till", "mark": Vector3(2.0, 1.7, -0.2), "label": "the till", "tab_label": "TILL", "icon": "res://assets/textury/ui/mark_till.png"},
	# The deli counter at the till counter's far end (the brief of 20. 10.).
	"deli": {"room": "shop", "at": Vector3(2.0, 1.0, -1.75), "size": Vector3(0.65, 0.25, 1.2), "stand": Vector3(2.75, 0.05, -1.75), "pose": "till", "mark": Vector3(2.0, 1.7, -1.75), "label": "the deli counter", "tab_label": "DELI", "icon": "res://assets/textury/jednota/goods_salami.png", "menu": ["deli"]},
}
## Where each is worked: the till's counter top (the cashier behind it on the right, the
## customers across it), the rack and the trolley (a wall), the packing table's top.
const SURFACES := {
	"till": {"at": Vector3(2.0, 0.955, -0.2), "size": Vector2(1.6, 0.6), "yaw": 90.0, "flat": true, "cam_back": 0.7, "cam_up": 0.66, "cam_aim": 0.02, "tex": J + "st_till.png"},
	"shelves": {"at": Vector3(-0.35, 0.89375, -2.32), "size": Vector2(3.0, 1.6875), "yaw": 0.0, "flat": false, "cam_back": 1.95, "tex": ""},
	"store": {"at": Vector3(-0.2, 0.905, -0.95), "size": Vector2(1.6, 0.525), "yaw": 0.0, "flat": true, "cam_back": 0.9, "cam_up": 0.95, "cam_aim": 0.22, "cam_side": 0.35, "tex": J + "st_store.png"},
	"deli": {"at": Vector3(2.0, 0.955, -1.75), "size": Vector2(1.2, 0.6), "yaw": 90.0, "flat": true, "cam_back": 0.6, "cam_up": 0.62, "cam_aim": 0.02, "tex": J + "st_deli.png"},
}
## The rack's picture in the shelves' wall: its centre (room) and size; the trolley stands
## right of it (shelves_station.gd).
const RACK_AT := Vector3(-0.75, 0.71, -2.32)
const RACK_SIZE := Vector2(2.2, 1.24)
## The storeroom's shelf of cartons behind the packing table: its two boards' tops (room y).
const CARTON_SHELF_Y := [0.62, 1.22]

## Where the guests stand in the shop (service_interior._start_life): the queue along the
## till's counter, the first at the till ([position, facing]); looking round at the
## racks on the left and at the main rack's ends ("clear_of": out of the way while that
## station is open, to "aside").
const QUEUE := [[Vector3(1.4, 0.05, -0.2), Vector3(1, 0, 0)], [Vector3(1.32, 0.05, -0.85), Vector3(1, 0, 0.3)],
	[Vector3(1.3, 0.05, -1.45), Vector3(0.6, 0, 1)], [Vector3(1.55, 0.05, -1.95), Vector3(0.2, 0, 1)]]
## The second till's queue (gear), by the door.
const QUEUE2 := [[Vector3(1.3, 0.05, 1.55), Vector3(1, 0, 0)], [Vector3(0.75, 0.05, 1.2), Vector3(1, 0, 0.2)]]
## Where the second till's hand stands (crew: till2).
const TILL2_STAND := Vector3(2.75, 0.05, 1.55)
const BROWSE := [
	{"pos": Vector3(-2.55, 0.05, -1.55), "face": Vector3(-1, 0, 0)},
	{"pos": Vector3(-2.5, 0.05, -0.45), "face": Vector3(-1, 0, 0)},
	{"pos": Vector3(-2.45, 0.05, 0.75), "face": Vector3(-1, 0, 0)},
	{"pos": Vector3(-1.45, 0.05, -1.8), "face": Vector3(0, 0, -1), "clear_of": ["shelves"], "aside": Vector3(-2.1, 0.05, -0.95)},
	{"pos": Vector3(-0.15, 0.05, -1.75), "face": Vector3(0, 0, -1), "clear_of": ["shelves"], "aside": Vector3(-1.75, 0.05, 0.2)},
	{"pos": Vector3(-1.9, 0.05, 1.55), "face": Vector3(-0.4, 0, -1)},
	{"pos": Vector3(-0.9, 0.05, 0.6), "face": Vector3(-0.3, 0, -1)},
	{"pos": Vector3(0.3, 0.05, -0.6), "face": Vector3(0, 0, -1)},
]


static func has_tex(n: String) -> bool:
	return ResourceLoader.exists(TEX + n + ".png")


static func _cut(parent: Node3D, n: String, size: Vector2, pos: Vector3, yaw := 0.0, billboard := false, node_name := "Cutout") -> MeshInstance3D:
	if not has_tex(n):
		return null
	return K.cutout(parent, n, size, pos, yaw, billboard, node_name)


static func _pic(parent: Node3D, n: String, size: Vector2, pos: Vector3, yaw := 0.0, node_name := "Picture") -> MeshInstance3D:
	if not has_tex(n):
		return null
	return K.picture(parent, n, size, pos, yaw, node_name)


static func look(parent: Node3D, name: String, line: String, at: Vector3, size: Vector3) -> StaticBody3D:
	return BISTRO.look(parent, name, line, at, size)


## A Jednota sprite (assets/textury/jednota/) standing on the floor at the rooms' pixel,
## its longer side `metres`, turned to you about Y.
static func jsprite(parent: Node3D, n: String, metres: float, pos: Vector3, node_name := "Thing") -> Sprite3D:
	var path := J + n + ".png"
	var tex := STATION3D.room_tex(path, metres)
	if tex == null:
		return null
	var s := Sprite3D.new()
	s.name = node_name
	s.texture = tex
	s.pixel_size = metres / float(maxi(tex.get_width(), tex.get_height()))
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.offset = Vector2(0, float(tex.get_height()) * 0.5)
	s.position = pos
	parent.add_child(s)
	return s


## A picture at the rooms' pixel on a quad (the rack's front: 91 px to the metre).
static func room_picture(parent: Node3D, path: String, size: Vector2, pos: Vector3, yaw := 0.0, node_name := "Picture") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	var tex := STATION3D.room_tex(path, size.x)
	if tex != null:
		m.albedo_texture = tex
	else:
		m.albedo_color = Color(0.22, 0.32, 0.24)
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees.y = yaw
	parent.add_child(mi)
	return mi


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
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission = Color(0.35, 0.33, 0.3)
	mi.material_override = m
	mi.position = d["at"]
	mi.rotation_degrees.y = float(d["yaw"])
	mi.set_meta("bistro_surface", id)
	parent.add_child(mi)
	return mi


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


static func _tube(parent: Node3D, at: Vector3, length := 1.2) -> void:
	K.slab(parent, Vector3(length + 0.1, 0.06, 0.16), at + Vector3(0, 0.03, 0), K.surface("steel_kitchen", 0.5, Color(0.85, 0.85, 0.82)), "TubeFitting")
	var tube := K.slab(parent, Vector3(length, 0.04, 0.05), at - Vector3(0, 0.02, 0), BISTRO._flat(Color(0.95, 0.97, 0.92)), "Tube")
	var m := tube.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(0.9, 0.95, 0.88)
	m.emission_energy_multiplier = 1.2


static func _green() -> StandardMaterial3D:
	return K.surface("steel_brushed", 0.6, Color(0.36, 0.52, 0.38))


# ── the shop ─────────────────────────────────────────────────────────────────

static func shop(parent: Node3D, si) -> void:
	K.room(parent, SIZE, "shop_floor", "oil_wall", "ceiling_board", SIZE.y, 1.0, 0.05)
	K.skirting(parent, SIZE, "planks_dark", 0.05)
	for z: float in [-1.3, 0.9]:
		_tube(parent, Vector3(-1.2, SIZE.y + 0.02, z), 1.4)
		_tube(parent, Vector3(1.2, SIZE.y + 0.02, z), 1.4)
	# The long rack at the back: a green steel body, its front the Grok picture (the
	# goods on it are the shelves' station's), the sign over it.
	var body_at := RACK_AT + Vector3(0, 0, -0.15)
	K.slab(parent, Vector3(RACK_SIZE.x + 0.04, RACK_SIZE.y + 0.04, 0.28), Vector3(body_at.x, RACK_AT.y, body_at.z - 0.002), _green(), "RackBody")
	room_picture(parent, J + "st_rack.png", RACK_SIZE, RACK_AT + Vector3(0, 0, 0.002), 0.0, "RackFront")
	si._sign(parent, "SAMOOBSLUHA\nself-service", Vector3(-0.75, 2.12, -2.55), 30, "enamel")
	# The bread rack, the fridge and the shelf of tins along the left wall; the chiller
	# beside the fridge once bought (service_interior._apply_jednota_gear).
	_rack_picture(parent, "shop_bread", Vector2(0.78, 1.04), Vector3(-2.95, 0.05, -1.55), 0.42, "BreadRack")
	look(parent, "bread rack", "Yesterday's bread at the bottom, today's on top. The top is yesterday's too.", Vector3(-2.9, 0.6, -1.55), Vector3(0.4, 1.0, 0.8))
	var fridge := _rack_picture(parent, "shop_fridge", Vector2(0.72, 0.96), Vector3(-2.95, 0.05, -0.45), 0.6, "Fridge")
	if fridge != null:
		var fm := fridge.material_override as StandardMaterial3D
		fm.emission_enabled = true
		fm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		fm.emission_texture = fm.albedo_texture
		fm.emission = Color(0.7, 0.85, 1.0)
		fm.emission_energy_multiplier = 0.4
	look(parent, "fridge", "It hums a note lower at night. The milk keeps, mostly.", Vector3(-2.9, 0.6, -0.45), Vector3(0.6, 1.0, 0.75))
	# The gear once bought (service_interior._apply_jednota_gear): the chiller cabinet by the
	# fridge, the extra shelf unit by the rack.
	var chiller := _cut(parent, "gear_fridge", Vector2(0.74, 1.04), Vector3(-2.8, 0.05, 0.4), 90.0, false, "GearChiller")
	if chiller != null:
		chiller.visible = false
	var racks := _cut(parent, "gear_racks", Vector2(0.82, 1.0), Vector3(-2.5, 0.05, -2.45), 0.0, false, "GearRacks")
	if racks != null:
		racks.visible = false
	_rack_picture(parent, "shop_shelf_goods", Vector2(1.5, 0.84), Vector3(-2.95, 0.55, 1.45), 0.36, "TinShelf")
	look(parent, "tins", "Pork in its own juice, peas, peas with carrots, pork with peas. The labels have faded the same blue.", Vector3(-2.9, 0.95, 1.45), Vector3(0.4, 0.84, 1.5))
	# The ice-cream chest by the door, the baskets.
	_cut(parent, "shop_freezer", Vector2(0.9, 0.69), Vector3(-2.2, 0.05, 2.15), 0.0, true, "Freezer")
	look(parent, "freezer", "Ice cream on a stick, 3 crowns. Something under the ice at the bottom has been there since spring.", Vector3(-2.2, 0.35, 2.15), Vector3(0.9, 0.7, 0.6))
	_cut(parent, "shop_baskets", Vector2(0.5, 0.48), Vector3(-0.9, 0.05, 2.25), 0.0, true, "Baskets")
	look(parent, "baskets", "Red wire baskets. One more than this morning.", Vector3(-0.9, 0.25, 2.25), Vector3(0.5, 0.5, 0.4))
	# The till's counter on the right: a box faced with the shop's counter, its top the
	# till's station; the cigarettes and the price list on the wall behind the cashier;
	# the second till further back once bought.
	_counter(parent, Vector3(2.0, 0.05, -0.2), "TillCounter", 1.6, 0.6)
	_counter(parent, Vector3(2.0, 0.05, -1.75), "DeliCounter", 1.2, 0.6)
	_pic(parent, "shop_shelf_cigs", Vector2(1.5, 0.84), Vector3(3.17, 1.65, -0.2), -90.0, "Cigarettes")
	look(parent, "cigarettes", "Petra, Sparta, Start. Start smells of the stove and Sparta of nothing.", Vector3(3.12, 1.65, -0.2), Vector3(0.1, 0.84, 1.5))
	var t2 := Node3D.new()
	t2.name = "GearTill2"
	t2.visible = false
	parent.add_child(t2)
	_counter(t2, Vector3(2.0, 0.05, 1.55), "Till2Counter", 1.1, 0.6)
	_cut(t2, "shop_till", Vector2(0.34, 0.3), Vector3(2.15, 0.95, 1.8), -90.0, false, "Till2")
	# The shop's books on a shelf behind the cashier (service_interior LEDGER_AT).
	K.slab(parent, Vector3(0.36, 0.04, 0.8), Vector3(3.02, 1.085, -1.05), K.surface("planks_dark", 0.6), "LedgerShelf")
	K.cutout(parent, "wall_clock", Vector2(0.3, 0.3), Vector3(3.17, 2.35, 0.9), -90.0, false, "Clock")
	look(parent, "clock", "It runs a minute fast in the morning and a minute slow by closing. It is right at noon.", Vector3(3.12, 2.35, 0.9), Vector3(0.1, 0.32, 0.32))
	_cut(parent, "calendar", Vector2(0.32, 0.46), Vector3(3.17, 1.6, 1.25), -90.0, false, "Calendar")
	# The back wall's posters either side of the rack.
	_pic(parent, "poster_mushrooms", Vector2(0.5, 0.66), Vector3(-2.55, 1.7, -2.57), 0.0, "PosterMushrooms")
	look(parent, "poster", "Which mushrooms you may pick. The last row has been torn off.", Vector3(-2.55, 1.7, -2.54), Vector3(0.5, 0.66, 0.1))
	_pic(parent, "shop_poster", Vector2(0.5, 0.66), Vector3(1.05, 1.75, -2.57), 0.0, "PosterFamily")
	look(parent, "poster", "A family with a full basket. The child's eyes have been scratched out and drawn back in, a little wrong.", Vector3(1.05, 1.75, -2.54), Vector3(0.5, 0.66, 0.1))
	for id in STATIONS:
		if str(STATIONS[id]["room"]) == "shop":
			station_body(parent, str(id))
	surface(parent, "till")
	surface(parent, "deli")


## A picture standing on the floor against a wall (a rack, a fridge), on a box as deep
## as `depth`: the left wall's things, facing into the room.
static func _rack_picture(parent: Node3D, n: String, size: Vector2, foot: Vector3, depth: float, node_name: String) -> MeshInstance3D:
	if not has_tex(n):
		return null
	var holder := Node3D.new()
	holder.name = node_name
	parent.add_child(holder)
	var x := -SIZE.x * 0.5 + depth
	K.slab(holder, Vector3(depth, size.y, size.x), Vector3(x - depth * 0.5, foot.y + size.y * 0.5, foot.z), _green(), node_name + "Body")
	return K.picture(holder, n, size, Vector3(x + 0.004, foot.y + size.y * 0.5, foot.z), 90.0, node_name + "Front")


## A counter of the shop (0.9 m high, `depth` across, as long as `length` along z): its
## customers' side the shop's counter front, a laminate top.
static func _counter(parent: Node3D, foot: Vector3, node_name: String, length := 1.6, depth := 0.6) -> void:
	var h := 0.9
	K.slab(parent, Vector3(depth, h - 0.03, length), foot + Vector3(0, (h - 0.03) * 0.5, 0), K.surface("planks_dark", 0.8, Color(0.62, 0.5, 0.4)), node_name)
	K.slab(parent, Vector3(depth + 0.04, 0.03, length + 0.04), foot + Vector3(0, h - 0.015, 0), K.surface("steel_brushed", 0.6, Color(0.72, 0.7, 0.66)), node_name + "Top")
	if has_tex("shop_counter"):
		K.picture(parent, "shop_counter", Vector2(length, h - 0.04), foot + Vector3(-depth * 0.5 - 0.002, (h - 0.04) * 0.5, 0), -90.0, node_name + "Front")


# ── the storeroom ────────────────────────────────────────────────────────────

static func store(parent: Node3D, si) -> void:
	K.room(parent, STORE, "concrete", "oil_wall", "concrete", STORE.y, 1.2, 0.05)
	# The packing table in the room: steel legs, a steel top (its picture is the station's).
	var top := 0.9
	var tc := Vector3(-0.2, 0.0, -0.95)
	for x: float in [-0.74, 0.74]:
		for z: float in [-0.22, 0.22]:
			K.slab(parent, Vector3(0.05, top - 0.05, 0.05), Vector3(tc.x + x, 0.05 + (top - 0.05) * 0.5, tc.z + z), _grey(), "TableLeg")
	K.slab(parent, Vector3(1.64, 0.04, 0.56), Vector3(tc.x, top - 0.02, tc.z), _grey(), "TableTop")
	surface(parent, "store")
	# Behind it on the back wall the cartons' shelf (the cartons are the station's: what
	# the books have in the storeroom); the trolley right of the table (the station's too).
	for y: float in CARTON_SHELF_Y:
		K.slab(parent, Vector3(1.7, 0.04, 0.42), Vector3(tc.x, y - 0.02, -1.77), _grey(), "CartonShelf")
	for x: float in [-1.03, 0.63]:
		for z: float in [-1.58, -1.96]:
			K.slab(parent, Vector3(0.04, 1.62, 0.04), Vector3(x, 0.86, z), _grey(), "CartonShelfPost")
	# The empty pallet and last year's cartons by the left wall (the books: click them for
	# the stock), the locker, the empties; the bulb on its cord.
	var pallet := jsprite(parent, "pallet", 0.8, Vector3(-1.75, 0.05, -1.5), "Pallet")
	if pallet != null:
		pallet.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		pallet.rotation_degrees.y = 25.0
	K.prop(parent, "cardboard_boxes", Vector3(-2.0, 0.05, 0.35), 90.0)
	K.prop(parent, "cardboard_boxes", Vector3(-2.0, 0.85, 0.35), 90.0)
	K.prop(parent, "cardboard_boxes", Vector3(-2.0, 0.05, 1.3), 90.0)
	look(parent, "cartons", "Last year's cartons, flattened and kept. One has a child's name written inside.", Vector3(-2.0, 0.6, 1.3), Vector3(0.5, 0.8, 0.9))
	# The pallet truck once bought (service_interior._apply_jednota_gear).
	var truck := _cut(parent, "gear_pallet", Vector2(0.8, 0.8), Vector3(-1.45, 0.05, -0.35), 25.0, false, "GearPallet")
	if truck != null:
		truck.visible = false
	K.prop(parent, "locker", Vector3(2.0, 0.05, -1.3), -90.0)
	look(parent, "locker", "Mrs Novakova's coat and a pair of slippers. The slippers face the wrong way.", Vector3(1.95, 1.0, -1.3), Vector3(0.5, 1.8, 1.2))
	K.prop(parent, "beer_crates", Vector3(1.0, 0.05, 1.5), 180.0)
	look(parent, "empties", "The brewery's crates of empties. Somebody has washed them.", Vector3(1.0, 0.4, 1.5), Vector3(1.0, 0.8, 0.5))
	_cut(parent, "bulb_cord", Vector2(0.18, 0.5), Vector3(0.0, STORE.y - 0.5, 0.2), 0.0, true, "BulbCord")
	var bulb := OmniLight3D.new()
	bulb.name = "StoreBulb"
	bulb.position = Vector3(0.0, STORE.y - 0.55, 0.2)
	bulb.light_color = Color(1.0, 0.88, 0.66)
	bulb.light_energy = 1.2
	bulb.omni_range = 5.5
	parent.add_child(bulb)
	si._sign(parent, "SKLAD\nstaff only", Vector3(-0.2, 2.3, -1.96), 30, "enamel")
	station_body(parent, "store")


static func _grey() -> StandardMaterial3D:
	return K.surface("steel_brushed", 0.5, Color(0.55, 0.56, 0.58))
