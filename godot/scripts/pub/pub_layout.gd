extends RefCounted

## The pub's two rooms (DESIGN.md §7b), built for scripts/service_interior.gd the
## bistro's way (scripts/bistro/bistro_layout.gd):
##   bar     a village hospoda: dark panelling, a worn plank floor, the bar on the right
##           with its tap and the bottles behind it, the washer at its end, the regulars'
##           table and one more on the left, the stove in the corner, the boar, the
##           pennants and the team photo, the slate of who owes, a window on the car park.
##   cellar  brick and concrete under a bare bulb: the keg on the line by the back wall
##           with its gas, the full kegs by it (the books: service_interior._fill_cellar),
##           the cooler, the slops, and an oak barrel that is on nobody's books.
## Every station is a click box with meta "bistro_station" (STATIONS), the things worth a
## look meta "bistro_look" (the line said about them, under the room: room_sentence.gd).
## A station is worked where it stands (scripts/business/station3d.gd): SURFACES is the
## place the camera goes over in steps and the station's things are laid on (the bar top
## at the tap, the bottle shelf's foot, the sink at the bar's end, the cellar floor by the
## pallet). Pictures are camp textures (assets/textury/camp/, Grok); a missing one is left
## out.

const K := preload("res://scripts/interior_kit.gd")
const BISTRO := preload("res://scripts/bistro/bistro_layout.gd")
const TEX := "res://assets/textury/camp/"
const SIZE := Vector3(5.8, 2.8, 4.6)
const CELLAR := Vector3(5.8, 2.5, 4.6)

## The building round the bar (building_models._pub), one plan with the room as the
## staffroom's is (scripts/staff/staffroom_plan.gd; the user 26. 10.: the businesses'
## windows real, seen into from the camp): the room's space is the building's own moved by
## AT (the house's middle, on the room's floor), its walls are the room's (K.room's, WALL
## thick) with the faces outside on them. The windows are where the faces' pictures have
## them (camp_pub_front_glass.png, camp_pub_side_glass.png: tools/artgen/glass_fronts.py
## pub): their glass in the room's space, the wall they are in, their size; the side's
## bars across it (z, and the cross bar's height).
const AT := Vector3(-0.6, 0.15, -0.4)
const WALL := 0.1
const WINDOWS := [
	{"wall": "front", "at": Vector3(0.321, 1.918, 2.3), "size": Vector2(0.664, 0.935)},
	{"wall": "front", "at": Vector3(1.694, 1.918, 2.3), "size": Vector2(0.664, 0.935)},
	{"wall": "left", "at": Vector3(-2.9, 1.787, 0.052), "size": Vector2(0.563, 0.861),
		"bars": [-0.136, -0.031, 0.073, 0.177, 0.282], "bar_y": 1.974},
]

## The guests' tables (room coordinates, on the floor): the regulars' first.
const TABLES := [Vector3(-1.6, 0.05, -1.0), Vector3(-1.6, 0.05, 0.9)]
## The ashtray on the second table, where the cards (the station "cards") are played.
const ASHTRAY_CARDS := Vector3(0.3, 0.74, -0.28)

## The stations: id -> {room, at (click box centre), size, stand (where the warden stands
## at it), pose (their picture there), mark (where its status hangs), label, tab_label
## (on the frame's bar)}.
## They go in the order of the work, as the frame's tabs and keys 1-9 number them
## (the user, 21. 10.: "1 husk, 2 serve and butter, 3 drinks: it should make sense
## everywhere"): what prepares first, then what makes and serves, then the side jobs.
## You come in at the tap (where an order starts), the first time.
const ENTRY := "tap"
const STATIONS := {
	"keg": {"room": "cellar", "at": Vector3(-1.0, 0.55, -1.85), "size": Vector3(1.0, 1.1, 0.8), "stand": Vector3(-1.0, 0.05, -1.15), "pose": "fix", "mark": Vector3(-1.0, 1.45, -1.85), "label": "the keg", "tab_label": "KEG", "icon": "res://assets/textury/ui/mark_keg.png"},
	"tap": {"room": "bar", "at": Vector3(1.3, 1.3, -1.32), "size": Vector3(0.3, 0.42, 0.3), "stand": Vector3(1.3, 0.05, -1.99), "pose": "tap", "mark": Vector3(1.3, 1.78, -1.3), "label": "the tap", "tab_label": "TAP", "icon": "res://assets/textury/ui/mark_tap.png"},
	"back": {"room": "bar", "at": Vector3(0.63, 1.25, -1.4), "size": Vector3(0.52, 0.32, 0.3), "stand": Vector3(0.63, 0.05, -1.99), "pose": "pour", "mark": Vector3(0.63, 1.7, -1.4), "label": "the bottles", "tab_label": "BOTTLES", "icon": "res://assets/textury/ui/mark_shot.png", "menu": ["rum", "zelena", "slivovice", "kofola"]},
	"wash": {"room": "bar", "at": Vector3(2.12, 1.15, -1.3), "size": Vector3(0.45, 0.12, 0.62), "stand": Vector3(2.12, 0.05, -1.99), "pose": "wash", "mark": Vector3(2.12, 1.6, -1.4), "label": "the washer", "tab_label": "WASH", "icon": "res://assets/textury/ui/mark_wash.png"},
	# The fun (pub_fun.gd): clicked in the room, not on the frame's bar ("tab": false).
	"slot": {"room": "bar", "at": Vector3(-2.35, 0.8, -1.9), "size": Vector3(0.7, 1.55, 0.5), "stand": Vector3(-2.35, 0.05, -1.2), "pose": "stand", "mark": Vector3(-2.35, 1.85, -1.85), "label": "the LUCKY 7", "tab_label": "LUCKY 7", "tab": false},
	"darts": {"room": "bar", "at": Vector3(-2.82, 1.70, -1.0), "size": Vector3(0.15, 0.55, 0.55), "stand": Vector3(-0.6, 0.05, -1.0), "pose": "stand", "mark": Vector3(-2.75, 2.08, -1.0), "label": "the darts", "tab_label": "DARTS", "tab": false},
	"cards": {"room": "bar", "at": Vector3(-1.6, 0.8, 0.9), "size": Vector3(0.9, 0.2, 0.7), "stand": Vector3(-1.6, 0.05, 1.6), "pose": "stand", "mark": Vector3(-1.6, 1.3, 0.9), "label": "the cards", "tab_label": "CARDS", "tab": false},
}
## Where each station is worked (scripts/business/station3d.gd): its centre, size in
## metres, which way the worker faces it (yaw), flat (a top) or a wall; how far back and
## up the camera stands and how far over the top it looks. The bar's three are along its
## top on the barman's side (the bar top 1.10 m up, bar_counter.glb), the camera behind
## them in the narrow way between the bar and the shelf, as the bistro's over its
## counters: the bottles at the left end, the tap in the middle, the mugs' board by it,
## the sink at the right end (the empties come back onto the bar in front of it).
const SURFACES := {
	"tap": {"at": Vector3(1.3, 1.10, -1.33), "size": Vector2(1.6, 0.9), "yaw": 180.0, "flat": true, "cam_back": 0.62, "cam_up": 0.4, "cam_aim": 0.16},
	"back": {"at": Vector3(0.65, 1.10, -1.33), "size": Vector2(1.6, 0.9), "yaw": 180.0, "flat": true, "cam_back": 0.62, "cam_up": 0.4, "cam_aim": 0.12},
	"wash": {"at": Vector3(2.05, 1.10, -1.33), "size": Vector2(1.6, 0.9), "yaw": 180.0, "flat": true, "cam_back": 0.62, "cam_up": 0.42, "cam_aim": 0.06},
	"keg": {"at": Vector3(-1.0, 0.15, -1.75), "size": Vector2(1.6, 0.9), "yaw": 0.0, "flat": true, "cam_back": 0.85, "cam_up": 0.68, "cam_aim": 0.25},
	# The LUCKY 7's face (a wall: the cabinet stands against the back wall), the wall round
	# the dartboard seen from the line, the second table's top.
	"slot": {"at": Vector3(-2.35, 0.865, -1.93), "size": Vector2(0.96, 0.54), "yaw": 0.0, "flat": false, "cam_back": 0.8},
	"darts": {"at": Vector3(-2.86, 1.70, -1.0), "size": Vector2(0.853, 0.48), "yaw": 90.0, "flat": false, "cam_back": 1.0},
	"cards": {"at": Vector3(-1.6, 0.792, 0.9), "size": Vector2(0.8, 0.45), "yaw": 0.0, "flat": true, "cam_back": 0.55, "cam_up": 0.45, "cam_aim": 0.0},
}


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


static var _hidden_mat: ShaderMaterial


## A model's surfaces by material name not drawn (the bar's own tap tower).
static func _hide_surfaces(n: Node, names: Array) -> void:
	if n == null:
		return
	if _hidden_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;
render_mode unshaded;
void fragment() {
	discard;
}
"
		_hidden_mat = ShaderMaterial.new()
		_hidden_mat.shader = sh
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i)
			if mat != null and names.has(mat.resource_name):
				(mi as MeshInstance3D).set_surface_override_material(i, _hidden_mat)


## A station's surface with a picture of its own: the quad Surface_<id> (the room puts
## the picture on it at the room's pixel, service_interior._make_stations).
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


# ── the bar ──────────────────────────────────────────────────────────────────

static func bar(parent: Node3D, si) -> void:
	K.room(parent, SIZE, "planks_red", "pub_panel", "planks_dark", 1.4, 1.0, 0.05)
	K.skirting(parent, SIZE, "planks_dark", 0.05)
	# The bar on the right (its own tap tower is not drawn: the tap's station has one that
	# works), the bottles behind on their shelf, the radio on top of it, the crates.
	var bar_model := K.prop(parent, "bar_counter", Vector3(1.35, 0.05, -1.25))
	_hide_surfaces(bar_model, ["chrome", "tap_handle"])
	K.prop(parent, "bottle_shelf", Vector3(1.35, 1.0, -2.16))
	K.prop(parent, "beer_crates", Vector3(-0.85, 0.05, -2.1))
	K.prop(parent, "radio_set", Vector3(1.85, 2.17, -2.14))
	look(parent, "radio", "It plays the same polka at the same time every evening. It is unplugged.", Vector3(1.85, 2.3, -2.14), Vector3(0.35, 0.25, 0.25))
	for x: float in [0.6, 1.3, 2.0]:
		K.prop(parent, "bar_stool", Vector3(x, 0.05, -0.6))
	_cut(parent, "pub_mats", Vector2(0.14, 0.1), Vector3(0.95, 1.1, -0.98), 0.0, true, "BeerMats")
	look(parent, "beer mats", "Mats from a dozen breweries. Two of them are breweries nobody has heard of.", Vector3(0.95, 1.15, -0.98), Vector3(0.2, 0.12, 0.2))
	# The glass washer at the end of the way behind the bar, once bought
	# (service_interior._apply_pub_gear).
	var gw := _cut(parent, "gear_glasswasher", Vector2(0.47, 0.65), Vector3(2.62, 0.05, -1.98), 0.0, true, "GearGlassWasher")
	if gw != null:
		gw.visible = false
	_cut(parent, "pub_crate", Vector2(0.5, 0.36), Vector3(2.65, 0.05, -0.55), 0.0, true, "Empties")
	look(parent, "crate of empties", "Empties for the brewery. Twenty bottles, twenty-one caps.", Vector3(2.65, 0.25, -0.55), Vector3(0.5, 0.4, 0.4))
	# The tables on the left, the regulars' with its plaque; ashtrays, a lamp over each.
	for i in TABLES.size():
		var t: Vector3 = TABLES[i]
		K.prop(parent, "pub_table", t)
		K.prop(parent, "chair_wood", t + Vector3(-0.55, 0, 0), 90.0)
		K.prop(parent, "chair_wood", t + Vector3(0.55, 0, 0), -90.0)
		# The second table's ashtray in its far corner, out of the cards' way.
		K.cutout(parent, "ashtray", Vector2(0.15, 0.13), t + (Vector3(0.1, 0.74, 0.1) if i == 0 else ASHTRAY_CARDS), 0.0, true, "Ashtray")
		si._pub_lamp(parent, t + Vector3(0, 2.05, 0))
	_cut(parent, "pub_plaque", Vector2(0.2, 0.14), TABLES[0] + Vector3(-0.12, 0.74, -0.12), 0.0, true, "Plaque")
	look(parent, "regulars' table", "STAMGAST. The regulars' table. Nobody sits there, even when it is empty.", TABLES[0] + Vector3(-0.1, 0.85, -0.1), Vector3(0.3, 0.2, 0.3))
	look(parent, "ashtray", "From the Slavia hotel. Somebody walked out with it in 1979.", TABLES[1] + ASHTRAY_CARDS + Vector3(0, 0.06, 0), Vector3(0.2, 0.12, 0.2))
	si._pub_lamp(parent, Vector3(1.35, 2.15, -1.2))
	# The back wall: the brewery's sign, the pennants, the calendar, the clock.
	K.picture(parent, "pub_sign", Vector2(0.7, 0.52), Vector3(-0.9, 1.75, -2.28), 0.0, "BrewerySign")
	look(parent, "brewery sign", "The brewery closed in 1991. The sign stayed; the beer changed.", Vector3(-0.9, 1.75, -2.25), Vector3(0.7, 0.52, 0.1))
	_cut(parent, "pub_pennant", Vector2(0.3, 0.36), Vector3(-2.0, 1.9, -2.28), 0.0, false, "Pennant")
	_cut(parent, "pub_pennant", Vector2(0.28, 0.34), Vector3(-1.62, 1.95, -2.28), 0.0, false, "Pennant")
	look(parent, "pennants", "SK Liblice. Promoted in 1983, relegated in 1984.", Vector3(-1.8, 2.0, -2.25), Vector3(0.7, 0.4, 0.1))
	_cut(parent, "pub_calendar", Vector2(0.32, 0.46), Vector3(0.15, 1.65, -2.28), 0.0, false, "Calendar")
	look(parent, "calendar", "September 1986. Nobody has turned it over.", Vector3(0.15, 1.65, -2.25), Vector3(0.32, 0.46, 0.1))
	K.cutout(parent, "wall_clock", Vector2(0.3, 0.3), Vector3(2.4, 1.85, -2.28), 0.0, false, "Clock")
	look(parent, "clock", "Ten to closing. It always says ten to closing.", Vector3(2.4, 2.0, -2.25), Vector3(0.32, 0.32, 0.1))
	# The left wall: the dartboard (a station: darts), the antlers, the boar, the window on
	# the car park; in the corner by it the LUCKY 7 (a station: the slot machine).
	# The clean board (Grok, with its numbers; the old picture had darts painted in it,
	# which a player's own darts got mixed with).
	K.cutout(parent, "dartboard_clean" if has_tex("dartboard_clean") else "dartboard", Vector2(0.48, 0.48), Vector3(-2.88, 1.46, -1.0), 90.0, false, "PubDartBoard")
	# The LUCKY 7 at its picture's own proportions (camp/pub_slot.png 74 x 136): its reel
	# window at 0.87 m, where the station's surface is (SURFACES "slot").
	_cut(parent, "pub_slot", Vector2(0.74, 1.36), Vector3(-2.35, 0.05, -1.95), 0.0, true, "SlotMachine")
	K.cutout(parent, "antlers", Vector2(0.4, 0.52), Vector3(-2.88, 1.6, -1.75), 90.0, false, "Antlers")
	look(parent, "antlers", "A six-pointer. Shot by the landlord's father, or bought at the market in Pisek: it depends who tells it.", Vector3(-2.85, 1.85, -1.75), Vector3(0.1, 0.5, 0.45))
	_cut(parent, "pub_boar", Vector2(0.55, 0.55), Vector3(-2.88, 1.55, 1.75), 90.0, false, "Boar")
	look(parent, "boar", "Somebody has dusted the boar lately. Round the eyes.", Vector3(-2.85, 1.8, 1.75), Vector3(0.1, 0.55, 0.55))
	# The windows, where the building's faces have them (WINDOWS).
	var rw = load("res://scripts/ambient/room_weather.gd").new()
	parent.add_child(rw)
	for wd in WINDOWS:
		_window(parent, wd, rw)
	var side: Dictionary = WINDOWS[2]
	var side_at: Vector3 = side["at"]
	var sill_y: float = side_at.y - (side["size"] as Vector2).y * 0.5
	_cut(parent, "pub_geranium", Vector2(0.26, 0.32), Vector3(-2.78, sill_y + 0.02, side_at.z + 0.18), 90.0, false, "Geranium")
	look(parent, "window", "The car park, the lamp, the forest. The lamp flickers when somebody walks under it. Nobody is.", Vector3(-2.82, side_at.y, side_at.z), Vector3(0.1, 0.8, 0.6))
	# The right wall: the slate of who owes, the lake poster, the print.
	_cut(parent, "pub_board", Vector2(0.5, 0.42), Vector3(2.88, 1.55, 1.3), -90.0, false, "DebtSlate")
	look(parent, "slate", "DLUZNICI, who owes for beer. The top name is rubbed out every morning and is back every night.", Vector3(2.85, 1.55, 1.3), Vector3(0.1, 0.42, 0.5))
	K.picture(parent, "poster_lake", Vector2(0.6, 0.8), Vector3(2.88, 1.6, 0.55), -90.0, "PubPoster")
	look(parent, "poster", "Cerne jezero, 1978. More people on the beach than live in the whole district now.", Vector3(2.85, 1.6, 0.55), Vector3(0.1, 0.8, 0.6))
	# The front wall's pictures beside its windows and between them.
	_cut(parent, "pub_hockey", Vector2(0.5, 0.36), Vector3(-0.75, 1.65, 2.28), 180.0, false, "TeamPhoto")
	_cut(parent, "pub_print", Vector2(0.5, 0.4), Vector3(1.008, 1.65, 2.28), 180.0, false, "PondPrint")
	# The front corner: the stove and its coal, the coat stand, the fly paper.
	_cut(parent, "pub_stove", Vector2(0.55, 1.3), Vector3(-2.4, 0.05, 1.85), 0.0, true, "Stove")
	look(parent, "stove", "The kamna. Cold since spring. There is warm ash in it.", Vector3(-2.4, 0.6, 1.85), Vector3(0.55, 1.2, 0.5))
	_cut(parent, "pub_coal", Vector2(0.32, 0.3), Vector3(-1.95, 0.05, 1.95), 0.0, true, "CoalScuttle")
	look(parent, "coal", "Coal for the winter. A child's shoe on top of it.", Vector3(-1.95, 0.2, 1.95), Vector3(0.35, 0.3, 0.3))
	_cut(parent, "pub_coatstand", Vector2(0.55, 1.75), Vector3(2.55, 0.05, 1.85), 0.0, true, "CoatStand")
	look(parent, "coat stand", "A green loden coat, wet through. It has not rained today.", Vector3(2.55, 1.0, 1.85), Vector3(0.5, 1.7, 0.5))
	_cut(parent, "pub_flypaper", Vector2(0.1, 0.5), Vector3(0.0, 2.3, -0.4), 20.0, true, "FlyPaper")
	look(parent, "fly paper", "Full. Somebody has hung a new one beside it, and that is filling up too.", Vector3(0.0, 2.55, -0.4), Vector3(0.15, 0.5, 0.15))
	si._sign(parent, "HOSPODA\nthe pub", Vector3(0.0, 2.36, -2.24), 30, "enamel")
	for id in STATIONS:
		if str(STATIONS[id]["room"]) == "bar":
			station_body(parent, str(id))


## A window of WINDOWS: its view (a picture the service interior makes a real one of:
## _make_windows), the net curtain over it, the sill under it.
static func _window(parent: Node3D, wd: Dictionary, rw) -> void:
	var at: Vector3 = wd["at"]
	var size: Vector2 = wd["size"]
	var front := str(wd["wall"]) == "front"
	var yaw := 180.0 if front else 90.0
	var into := Vector3(0, 0, -1) if front else Vector3(1, 0, 0)
	var win := _pic(parent, "window_view", size, at + into * 0.02, yaw, "Window")
	if win != null:
		rw.add_window(win)
	_pic(parent, "window_curtain", size + Vector2(0.06, 0.06), at + into * 0.04, yaw, "NetCurtain")
	var sill := Vector3(size.x + 0.1, 0.04, 0.18) if front else Vector3(0.18, 0.04, size.x + 0.1)
	K.slab(parent, sill, at + into * 0.08 - Vector3(0, size.y * 0.5 + 0.02, 0), K.surface("planks_dark", 0.5), "Sill")


## The bar built again in its building in the camp (building_models._pub): the same room
## by the same code, its walls open where the windows are, nothing in it to click; `host`
## stands in for the service interior (its signs and lamps: business/room_outside.gd).
static func bar_outside(parent: Node3D, host) -> void:
	bar(parent, host)
	K.strip_for_outside(parent)
	K.open_windows(parent, WINDOWS)


# ── the cellar ───────────────────────────────────────────────────────────────

static func cellar(parent: Node3D, si) -> void:
	K.room(parent, CELLAR, "concrete", "brick_red", "concrete", 1.0, 1.2, 0.05)
	K.prop(parent, "wall_shelf", Vector3(-2.75, 1.4, -0.4), 90.0, 1.4)
	K.prop(parent, "oil_drum", Vector3(-2.4, 0.05, 1.5))
	look(parent, "oil drum", "Diesel for the generator. It sloshes when you pass, a moment late.", Vector3(-2.4, 0.5, 1.5), Vector3(0.6, 1.0, 0.6))
	K.slab(parent, Vector3(2.6, 0.12, 0.6), Vector3(0.6, 0.11, -1.9), K.surface("planks_dark", 0.8), "KegRack")
	# The keg on the line at the back left, its hose up to the ceiling, the gas by it.
	K.slab(parent, Vector3(0.7, 0.1, 0.6), Vector3(-1.0, 0.1, -1.9), K.surface("planks_dark", 0.8), "Pallet")
	K.slab(parent, Vector3(0.03, 1.6, 0.03), Vector3(-1.0, 1.75, -1.95), BISTRO._flat(Color(0.75, 0.72, 0.55)), "BeerHose")
	_cut(parent, "pub_cooler", Vector2(0.6, 0.55), Vector3(-1.95, 0.05, -1.95), 0.0, true, "Cooler")
	look(parent, "cooler", "The python: ice water round the beer line. It hums loudest when nobody is pouring.", Vector3(-1.95, 0.3, -1.95), Vector3(0.6, 0.55, 0.5))
	# The old barrel in the far corner that nobody ordered.
	_cut(parent, "pub_barrel", Vector2(0.55, 0.7), Vector3(2.45, 0.05, -1.95), 0.0, true, "OakBarrel")
	look(parent, "oak barrel", "Oak, chalked 1968. Nobody has delivered oak for thirty years. It is full, and cold, and it is not on the books.", Vector3(2.45, 0.4, -1.95), Vector3(0.55, 0.7, 0.5))
	_cut(parent, "pub_bucket", Vector2(0.3, 0.3), Vector3(-0.2, 0.05, -1.35), 0.0, true, "Slops")
	look(parent, "slops", "The slops bucket. Always half full, however often it is emptied.", Vector3(-0.2, 0.2, -1.35), Vector3(0.3, 0.3, 0.3))
	_cut(parent, "pub_broom", Vector2(0.3, 1.2), Vector3(2.75, 0.05, 0.6), 0.0, true, "Broom")
	look(parent, "broom", "Worn down on one side, as if it swept the same spot for years.", Vector3(2.75, 0.6, 0.6), Vector3(0.3, 1.2, 0.3))
	_cut(parent, "pub_trap", Vector2(0.2, 0.1), Vector3(1.4, 0.05, -1.4), 0.0, true, "MouseTrap")
	look(parent, "mouse trap", "Sprung, and empty. Something took the bait and the spring with it.", Vector3(1.4, 0.1, -1.4), Vector3(0.25, 0.15, 0.2))
	_cut(parent, "pub_cobweb", Vector2(0.6, 0.5), Vector3(-2.8, 2.0, -2.2), 45.0, false, "Cobweb")
	_cut(parent, "pub_cobweb", Vector2(0.5, 0.45), Vector3(2.8, 2.05, 2.2), -135.0, false, "Cobweb")
	var bulb := OmniLight3D.new()
	bulb.position = Vector3(0.0, 2.2, -0.2)
	bulb.light_color = Color(1.0, 0.86, 0.62)
	bulb.light_energy = 1.1
	bulb.omni_range = 5.5
	parent.add_child(bulb)
	si._sign(parent, "SKLEP\ncellar", Vector3(-0.2, 2.05, -2.24), 30, "enamel")
	station_body(parent, "keg")
