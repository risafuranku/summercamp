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
## Pictures are camp textures (assets/textury/camp/, Grok); a missing one is left out.

const K := preload("res://scripts/interior_kit.gd")
const BISTRO := preload("res://scripts/bistro/bistro_layout.gd")
const TEX := "res://assets/textury/camp/"
const SIZE := Vector3(5.8, 2.8, 4.6)
const CELLAR := Vector3(5.8, 2.5, 4.6)

## The guests' tables (room coordinates, on the floor): the regulars' first.
const TABLES := [Vector3(-1.6, 0.05, -1.0), Vector3(-1.6, 0.05, 0.9)]

## The stations: id -> {room, at (click box centre), size, stand (where the warden stands
## at it), pose (their picture there), mark (where its status hangs), label}.
const STATIONS := {
	"tap": {"room": "bar", "at": Vector3(1.275, 1.28, -1.405), "size": Vector3(0.52, 0.46, 0.34), "stand": Vector3(1.275, 0.05, -1.8), "pose": "tap", "mark": Vector3(1.275, 1.86, -1.405), "label": "the tap"},
	"back": {"room": "bar", "at": Vector3(1.35, 1.45, -2.05), "size": Vector3(1.4, 0.8, 0.4), "stand": Vector3(1.75, 0.05, -1.85), "pose": "pour", "mark": Vector3(1.75, 2.12, -2.0), "label": "the back bar"},
	"wash": {"room": "bar", "at": Vector3(2.35, 1.05, -1.2), "size": Vector3(0.5, 0.4, 0.5), "stand": Vector3(2.35, 0.05, -1.75), "pose": "wash", "mark": Vector3(2.35, 1.52, -1.2), "label": "the washer"},
	"keg": {"room": "cellar", "at": Vector3(-1.0, 0.55, -1.85), "size": Vector3(1.0, 1.1, 0.8), "stand": Vector3(-1.0, 0.05, -1.15), "pose": "fix", "mark": Vector3(-1.0, 1.45, -1.85), "label": "the keg"},
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
	# The bar on the right: the counter with its tap, the bottles behind, the crates.
	K.prop(parent, "bar_counter", Vector3(1.35, 0.05, -1.25))
	K.prop(parent, "bottle_shelf", Vector3(1.35, 1.0, -2.16))
	K.prop(parent, "beer_crates", Vector3(2.5, 0.05, -1.95))
	K.prop(parent, "radio_set", Vector3(0.62, 1.13, -1.2), -15.0)
	look(parent, "radio", "It plays the same polka at the same time every evening. It is unplugged.", Vector3(0.62, 1.25, -1.2), Vector3(0.35, 0.25, 0.25))
	for x: float in [0.6, 1.3, 2.0]:
		K.prop(parent, "bar_stool", Vector3(x, 0.05, -0.6))
	_cut(parent, "pub_mats", Vector2(0.14, 0.1), Vector3(2.05, 1.1, -1.1), 0.0, true, "BeerMats")
	look(parent, "beer mats", "Mats from a dozen breweries. Two of them are breweries nobody has heard of.", Vector3(2.05, 1.15, -1.1), Vector3(0.2, 0.12, 0.2))
	_cut(parent, "pub_crate", Vector2(0.5, 0.36), Vector3(2.65, 0.05, -0.55), 0.0, true, "Empties")
	look(parent, "crate of empties", "Empties for the brewery. Twenty bottles, twenty-one caps.", Vector3(2.65, 0.25, -0.55), Vector3(0.5, 0.4, 0.4))
	# The tables on the left, the regulars' with its plaque; ashtrays, a lamp over each.
	for i in TABLES.size():
		var t: Vector3 = TABLES[i]
		K.prop(parent, "pub_table", t)
		K.prop(parent, "chair_wood", t + Vector3(-0.55, 0, 0), 90.0)
		K.prop(parent, "chair_wood", t + Vector3(0.55, 0, 0), -90.0)
		K.cutout(parent, "ashtray", Vector2(0.15, 0.13), t + Vector3(0.1, 0.74, 0.1), 0.0, true, "Ashtray")
		si._pub_lamp(parent, t + Vector3(0, 2.05, 0))
	_cut(parent, "pub_plaque", Vector2(0.2, 0.14), TABLES[0] + Vector3(-0.12, 0.74, -0.12), 0.0, true, "Plaque")
	look(parent, "regulars' table", "STAMGAST. The regulars' table. Nobody sits there, even when it is empty.", TABLES[0] + Vector3(-0.1, 0.85, -0.1), Vector3(0.3, 0.2, 0.3))
	look(parent, "ashtray", "From the Slavia hotel. Somebody walked out with it in 1979.", TABLES[1] + Vector3(0.1, 0.8, 0.1), Vector3(0.2, 0.12, 0.2))
	si._pub_lamp(parent, Vector3(1.35, 2.15, -1.2))
	# The back wall: the brewery's sign, the pennants, the calendar, the clock.
	K.picture(parent, "pub_sign", Vector2(0.7, 0.52), Vector3(-0.9, 1.75, -2.28), 0.0, "BrewerySign")
	look(parent, "brewery sign", "The brewery closed in 1991. The sign stayed; the beer changed.", Vector3(-0.9, 1.75, -2.25), Vector3(0.7, 0.52, 0.1))
	_cut(parent, "pub_pennant", Vector2(0.3, 0.36), Vector3(-2.0, 1.9, -2.28), 0.0, false, "Pennant")
	_cut(parent, "pub_pennant", Vector2(0.28, 0.34), Vector3(-1.62, 1.95, -2.28), 0.0, false, "Pennant")
	look(parent, "pennants", "SK Lesna. Promoted in 1983, relegated in 1984.", Vector3(-1.8, 2.0, -2.25), Vector3(0.7, 0.4, 0.1))
	_pic(parent, "pub_calendar", Vector2(0.32, 0.46), Vector3(0.15, 1.65, -2.28), 0.0, "Calendar")
	look(parent, "calendar", "September 1986. Nobody has turned it over.", Vector3(0.15, 1.65, -2.25), Vector3(0.32, 0.46, 0.1))
	K.cutout(parent, "wall_clock", Vector2(0.3, 0.3), Vector3(2.4, 1.85, -2.28), 0.0, false, "Clock")
	look(parent, "clock", "Ten to closing. It always says ten to closing.", Vector3(2.4, 2.0, -2.25), Vector3(0.32, 0.32, 0.1))
	# The left wall: the dartboard, the antlers, the boar, the window on the car park.
	K.cutout(parent, "dartboard", Vector2(0.48, 0.48), Vector3(-2.88, 1.46, -1.0), 90.0, false, "PubDartBoard")
	look(parent, "dartboard", "Three darts in the treble twenty. Nobody in here throws like that.", Vector3(-2.85, 1.7, -1.0), Vector3(0.1, 0.5, 0.5))
	K.cutout(parent, "antlers", Vector2(0.4, 0.52), Vector3(-2.88, 1.6, -1.75), 90.0, false, "Antlers")
	look(parent, "antlers", "A six-pointer. Shot by the landlord's father, or bought at the market in Pisek: it depends who tells it.", Vector3(-2.85, 1.85, -1.75), Vector3(0.1, 0.5, 0.45))
	_cut(parent, "pub_boar", Vector2(0.55, 0.55), Vector3(-2.88, 1.55, 1.75), 90.0, false, "Boar")
	look(parent, "boar", "Somebody has dusted the boar lately. Round the eyes.", Vector3(-2.85, 1.8, 1.75), Vector3(0.1, 0.55, 0.55))
	var rw = load("res://scripts/ambient/room_weather.gd").new()
	parent.add_child(rw)
	var win := _pic(parent, "window_view", Vector2(0.9, 0.8), Vector3(-2.88, 1.5, 0.05), 90.0, "Window")
	if win != null:
		rw.add_window(win)
	_pic(parent, "window_curtain", Vector2(0.96, 0.86), Vector3(-2.86, 1.5, 0.05), 90.0, "NetCurtain")
	K.slab(parent, Vector3(0.18, 0.04, 1.0), Vector3(-2.82, 1.07, 0.05), K.surface("planks_dark", 0.5), "Sill")
	_cut(parent, "pub_geranium", Vector2(0.26, 0.32), Vector3(-2.78, 1.09, 0.3), 90.0, false, "Geranium")
	look(parent, "window", "The car park, the lamp, the forest. The lamp flickers when somebody walks under it. Nobody is.", Vector3(-2.82, 1.5, 0.05), Vector3(0.1, 0.8, 0.9))
	# The right wall: the slate of who owes, the lake poster, the print.
	_pic(parent, "pub_board", Vector2(0.5, 0.42), Vector3(2.88, 1.55, 1.3), -90.0, "DebtSlate")
	look(parent, "slate", "DLUZNICI, who owes for beer. The top name is rubbed out every morning and is back every night.", Vector3(2.85, 1.55, 1.3), Vector3(0.1, 0.42, 0.5))
	K.picture(parent, "poster_lake", Vector2(0.6, 0.8), Vector3(2.88, 1.6, 0.55), -90.0, "PubPoster")
	look(parent, "poster", "Lake Lesna, 1978. More people on the beach than live in the whole district now.", Vector3(2.85, 1.6, 0.55), Vector3(0.1, 0.8, 0.6))
	_pic(parent, "pub_hockey", Vector2(0.5, 0.36), Vector3(-0.2, 1.65, 2.28), 180.0, "TeamPhoto")
	_pic(parent, "pub_print", Vector2(0.5, 0.4), Vector3(0.6, 1.65, 2.28), 180.0, "PondPrint")
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
