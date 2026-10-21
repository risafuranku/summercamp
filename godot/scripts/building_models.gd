extends RefCounted

## Building exteriors modelled after the Builder's pixel art (assets/textury/builder/:
## hajzly, sprchy, hospoda1, restaurace, gen, sewer, bonfire, iso_sports, iso_slide).
## Low-poly Build-engine kitbash: boxes, prisms, a few cylinders, the camp's own
## generated textures (assets/textury/camp/) and the PSX material of BuildingManager,
## so wear (corrosion) darkens them like everything else.
##
## `build(type, root, tile, footprint)` fills `root` (the structure, origin at the
## footprint centre on the ground, the front facing +Z) and returns
## {size: Vector3 (the collision box), target: Vector3 (where E aims, local)}.

const CAMP := "res://assets/textury/camp/"
## The cabin's plan, shared with the room inside (cabin_interior.gd).
const CL = preload("res://scripts/cabin_layout.gd")
const FONT := "res://assets/fonts/w95b.fnt"
const MODELS := ["toilet_block", "shower_block", "pub", "restaurant", "power_generator", "sewer",
	"bonfire", "sports_field", "lake_slide", "dumpsters",
	"bench", "picnic_table", "flower_bed", "gnome", "flagpole", "playground", "ping_pong", "hammock", "corn_stand", "mega_gnome",
	"vecerka", "bowling", "staffroom"]

var _psx: Callable           # (color, wobble, snap, steps, corrosion, category) -> Material
var _cache: Dictionary = {}


func _init(psx_material: Callable = Callable()) -> void:
	_psx = psx_material


static func has_model(type: String) -> bool:
	return MODELS.has(type)


func build(type: String, root: Node3D, tile: float, footprint: Vector2i) -> Dictionary:
	var w := tile * float(footprint.x)
	var d := tile * float(footprint.y)
	match type:
		"toilet_block":
			return _toilets(root, w, d)
		"shower_block":
			return _showers(root, w, d)
		"pub":
			return _pub(root, w, d)
		"restaurant":
			return _restaurant(root, w, d)
		"power_generator":
			return _substation(root, w, d)
		"sewer":
			return _sewer(root, w, d)
		"bonfire":
			return _bonfire(root, w, d)
		"sports_field":
			return _sports(root, w, d)
		"lake_slide":
			return _slide(root, w, d)
		"dumpsters":
			return _dumpsters(root, w, d)
		"bench":
			return _bench(root, w, d)
		"picnic_table":
			return _picnic(root, w, d)
		"flower_bed":
			return _flowerbed(root, w, d)
		"gnome":
			return _gnome(root, w, d)
		"mega_gnome":
			return _mega_gnome(root, w, d)
		"flagpole":
			return _flagpole(root, w, d)
		"playground":
			return _playground(root, w, d)
		"ping_pong":
			return _pingpong(root, w, d)
		"hammock":
			return _hammock(root, w, d)
		"corn_stand":
			return _corn_stand(root, w, d)
		"vecerka":
			return _jednota(root, w, d)
		"bowling":
			return _bowling(root, w, d)
		"staffroom":
			return _staffroom(root, w, d)
		# Built by BuildingManager's own placers; here for tools/model_viewer.
		"cabin_1", "cabin_2", "cabin_3":
			var lv := int(type.right(1))
			var cs := tile * (1.56 + float(lv - 1) * 0.06)
			var box := cabin(root, lv, cs, cs, 2.8 * (0.86 + float(lv - 1) * 0.04), 1.26)
			return {"size": box, "target": Vector3(0, 1.0, cs * 0.5)}
		"caravan_1":
			return {"size": caravan(root, w, d), "target": Vector3(0, 1.0, d * 0.25)}
	return {"size": Vector3(w * 0.8, 2.0, d * 0.8), "target": Vector3(0, 1.0, d * 0.4)}


# ── WC (hajzly.PNG): a plank shack, mossy tin roof, two doors with hearts ──────

func _toilets(r: Node3D, _w: float, _d: float) -> Dictionary:
	var sx := 2.9
	var sz := 2.1
	var h := 2.25
	var planks := _camp("planks_grey.png", Color(0.92, 0.9, 0.84), Vector3(2.0, 1.0, 1.0))
	_plinth(r, sx + 0.2, sz + 0.2)
	_box(r, "Shack", Vector3(sx, h, sz), Vector3(0, h * 0.5 + 0.1, 0), planks)
	# Roof: one slope falling to the back, overhanging, with moss.
	_lean_roof(r, sx + 0.5, sz + 0.7, h + 0.1, 0.45, _camp("corrugated_roof.png", Color(0.62, 0.72, 0.5), Vector3(2.0, 2.0, 1.0)))
	var door := _camp("door_wood.png", Color(0.82, 0.74, 0.62))
	for i in 2:
		var x := -0.62 + i * 1.24
		_box(r, "Door%d" % i, Vector3(0.78, 1.82, 0.05), Vector3(x, 1.01, sz * 0.5 + 0.03), door)
		# The heart cut in the door (the Czech outhouse has a heart).
		var heart := _box(r, "Heart%d" % i, Vector3(0.14, 0.14, 0.06), Vector3(x, 1.62, sz * 0.5 + 0.035), _flat(Color(0.05, 0.04, 0.03)))
		heart.rotation.z = PI * 0.25
		_box(r, "Plaque%d" % i, Vector3(0.2, 0.2, 0.02), Vector3(x, 1.32, sz * 0.5 + 0.065), _flat(Color(0.86, 0.82, 0.62)))
		_label(r, "M" if i == 0 else "Z", Vector3(x, 1.32, sz * 0.5 + 0.08), 0.15, Color(0.12, 0.1, 0.08))
	# The WC board over the doors.
	_box(r, "WCBoard", Vector3(0.9, 0.36, 0.04), Vector3(0, h - 0.05, sz * 0.5 + 0.06), _flat(Color(0.18, 0.16, 0.12)))
	_label(r, "WC", Vector3(0, h - 0.05, sz * 0.5 + 0.09), 0.3, Color(0.95, 0.78, 0.2))
	# A washbasin on the left wall, a bench, a toilet roll on a nail, a bucket.
	_box(r, "Basin", Vector3(0.18, 0.12, 0.42), Vector3(-sx * 0.5 - 0.1, 0.92, 0.3), _flat(Color(0.86, 0.86, 0.82)))
	_box(r, "Tap", Vector3(0.12, 0.06, 0.04), Vector3(-sx * 0.5 - 0.06, 1.18, 0.3), _metal())
	_box(r, "Bench", Vector3(1.1, 0.06, 0.32), Vector3(-0.9, 0.46, sz * 0.5 + 0.55), _wood())
	for x: float in [-1.35, -0.45]:
		_box(r, "BenchLeg", Vector3(0.06, 0.42, 0.28), Vector3(x, 0.22, sz * 0.5 + 0.55), _wood())
	_cyl(r, "Roll", 0.06, 0.1, Vector3(sx * 0.5 + 0.05, 1.3, 0.2), _flat(Color(0.94, 0.94, 0.9)), Vector3(0, 0, PI * 0.5))
	_cyl(r, "Bucket", 0.16, 0.3, Vector3(sx * 0.5 + 0.3, 0.25, sz * 0.5 + 0.1), _flat(Color(0.32, 0.46, 0.38)))
	return {"size": Vector3(sx + 0.4, h + 0.6, sz + 0.4), "target": Vector3(0, 1.1, sz * 0.5 + 0.1)}


# ── showers: a concrete shower house (the room inside: service_interior.gd wash) ─

## A low block of grey roughcast concrete under a flat slab roof, built round the room
## inside (3.6 x 3.2 m): the three cubicles along the back wall lit by a strip of glass
## blocks under the roof, the boiler on the right wall with its flue up past the roof,
## the bench on the left. The green steel door in the middle of the front, its enamel
## plate and a caged bulb over it, a tap with a bucket outside on the left, the hot-water
## tank on the roof, a downpipe, a vent grille. Build style: boxes and camp textures.
func _showers(r: Node3D, _w: float, _d: float) -> Dictionary:
	var sx := 3.6
	var sz := 3.2
	var h := 2.7
	var front := sz * 0.5
	var back := -sz * 0.5
	var walls: Material = _camp("roughcast_wall.png", Color(0.95, 0.96, 0.98), Vector3(1.0, 1.0, 1.0)) if ResourceLoader.exists(CAMP + "roughcast_wall.png") \
		else _camp("booth_wall.png", Color(0.86, 0.86, 0.84), Vector3(1.2, 1.2, 1.2))
	var slab := _camp_or("concrete.png", Color(0.7, 0.7, 0.68), "stone", Vector3(1.5, 1.5, 1.5))
	var glass_blocks: Material = _camp("glass_blocks.png", Color(0.9, 0.96, 0.96), Vector3(2.4, 2.4, 2.4)) if ResourceLoader.exists(CAMP + "glass_blocks.png") \
		else _camp("tiles_bathroom.png", Color(0.62, 0.78, 0.8), Vector3(3.0, 3.0, 3.0))
	var steel := _camp_or("metal_green.png", Color(0.5, 0.66, 0.5), "metal")
	var galv := _camp_or("galvanized.png", Color(0.72, 0.74, 0.74), "metal", Vector3(0.6, 0.6, 0.6))
	_plinth(r, sx + 0.3, sz + 0.3)
	_box(r, "House", Vector3(sx, h, sz), Vector3(0, h * 0.5 + 0.1, 0), walls)
	# A darker painted base band, splashed and damp.
	_box(r, "BaseBand", Vector3(sx + 0.03, 0.45, sz + 0.03), Vector3(0, 0.32, 0), _camp_or("concrete.png", Color(0.38, 0.4, 0.38), "stone"))
	# The flat roof: a concrete slab overhanging all round, tar paper on top.
	_box(r, "RoofSlab", Vector3(sx + 0.36, 0.18, sz + 0.36), Vector3(0, h + 0.19, 0), slab)
	_box(r, "TarPaper", Vector3(sx + 0.26, 0.03, sz + 0.26), Vector3(0, h + 0.295, 0), _flat(Color(0.12, 0.12, 0.13)))
	# Glass blocks: a strip under the roof above the cubicles, a small square each side.
	_box(r, "GlassBlocksBack", Vector3(sx * 0.78, 0.42, 0.05), Vector3(0, h - 0.3, back - 0.01), glass_blocks)
	for side: float in [-1.0, 1.0]:
		_box(r, "GlassBlocksSide", Vector3(0.05, 0.42, 0.56), Vector3(side * (sx * 0.5 + 0.01), h - 0.3, back + 0.7), glass_blocks)
	# The door: a concrete surround, the green steel leaf with a wired-glass slit.
	_box(r, "DoorSurround", Vector3(1.16, 2.18, 0.06), Vector3(0, 1.19, front + 0.02), slab)
	_box(r, "Door", Vector3(0.9, 2.0, 0.05), Vector3(0, 1.1, front + 0.05), steel)
	_box(r, "DoorGlass", Vector3(0.22, 0.5, 0.055), Vector3(0, 1.62, front + 0.055), _flat(Color(0.42, 0.5, 0.5)))
	_box(r, "DoorHandle", Vector3(0.12, 0.03, 0.05), Vector3(0.32, 1.05, front + 0.1), _metal())
	_box(r, "Step", Vector3(1.3, 0.16, 0.5), Vector3(0, 0.08, front + 0.3), slab)
	# A bulb in a wire cage over the door, on a little arm.
	_box(r, "LampArm", Vector3(0.05, 0.05, 0.28), Vector3(0, 2.42, front + 0.14), _metal())
	_cyl(r, "LampCage", 0.09, 0.16, Vector3(0, 2.36, front + 0.28), _flat(Color(0.25, 0.26, 0.24)))
	_cyl(r, "LampBulb", 0.055, 0.1, Vector3(0, 2.33, front + 0.28), _flat(Color(1.0, 0.92, 0.66)))
	# The enamel plate left of the door (the same plate as inside).
	_box(r, "SignRim", Vector3(0.98, 0.36, 0.03), Vector3(-1.2, 1.78, front + 0.03), _flat(Color(0.16, 0.2, 0.36)))
	_box(r, "SignPlate", Vector3(0.92, 0.3, 0.035), Vector3(-1.2, 1.78, front + 0.035), _flat(Color(0.92, 0.9, 0.82)))
	_label(r, "SPRCHY", Vector3(-1.2, 1.78, front + 0.06), 0.17, Color(0.15, 0.25, 0.4))
	# Outside on the left: a tap on its pipe, a bucket and a red basin on a duckboard.
	var tap_z := front - 0.8
	_box(r, "TapBoard", Vector3(0.42, 0.06, 0.9), Vector3(-sx * 0.5 - 0.23, 0.14, tap_z), _wood())
	_cyl(r, "TapPipe", 0.025, 0.9, Vector3(-sx * 0.5 - 0.04, 0.85, tap_z), galv)
	_box(r, "Tap", Vector3(0.14, 0.05, 0.05), Vector3(-sx * 0.5 - 0.1, 0.62, tap_z), _metal())
	_cyl(r, "Bucket", 0.14, 0.26, Vector3(-sx * 0.5 - 0.24, 0.3, tap_z + 0.2), _flat(Color(0.7, 0.72, 0.72)))
	_cyl(r, "Basin", 0.2, 0.1, Vector3(-sx * 0.5 - 0.24, 0.22, tap_z - 0.22), _flat(Color(0.7, 0.16, 0.12)))
	# The boiler's flue: out of the right wall where the boiler hangs inside, up past the roof.
	var flue_x := sx * 0.5 + 0.12
	_box(r, "FlueBracket", Vector3(0.24, 0.06, 0.06), Vector3(sx * 0.5 + 0.06, 1.75, -0.6), _metal())
	_cyl(r, "Flue", 0.07, h + 0.4 - 1.6, Vector3(flue_x, (1.6 + h + 0.4) * 0.5, -0.6), galv)
	_cyl(r, "FlueCap", 0.12, 0.08, Vector3(flue_x, h + 0.46, -0.6), _metal())
	# Rain: a gutter outlet and a downpipe at the front right corner.
	_cyl(r, "Downpipe", 0.05, h + 0.1, Vector3(sx * 0.5 + 0.06, (h + 0.1) * 0.5 + 0.05, front - 0.06), galv)
	_box(r, "DownpipeShoe", Vector3(0.22, 0.06, 0.12), Vector3(sx * 0.5 + 0.12, 0.08, front - 0.06), galv)
	# A vent grille low on the back wall.
	_box(r, "Vent", Vector3(0.4, 0.22, 0.04), Vector3(sx * 0.3, 0.7, back - 0.02), _flat(Color(0.2, 0.2, 0.2)))
	for i in 4:
		_box(r, "VentSlat", Vector3(0.38, 0.025, 0.05), Vector3(sx * 0.3, 0.62 + i * 0.055, back - 0.03), _metal())
	# The hot-water tank on the roof on two cradles, its pipe going down into the roof.
	var tank_y := h + 0.31 + 0.5
	_cyl(r, "Tank", 0.42, 1.3, Vector3(-sx * 0.2, tank_y, back + 0.8), _psx_mat(Color(0.56, 0.4, 0.28), "metal"), Vector3(0, 0, PI * 0.5))
	for x: float in [-sx * 0.2 - 0.45, -sx * 0.2 + 0.45]:
		_box(r, "TankCradle", Vector3(0.1, 0.36, 0.7), Vector3(x, h + 0.49, back + 0.8), _wood())
	_cyl(r, "TankPipe", 0.03, 0.5, Vector3(-sx * 0.2 + 0.7, h + 0.55, back + 0.8), galv)
	return {"size": Vector3(sx + 0.8, h + 1.0, sz + 0.6), "target": Vector3(0, 1.1, front + 0.35)}


# ── the pub (hospoda1.PNG): a plastered village house, porch, barrels ─────────

func _pub(r: Node3D, w: float, d: float) -> Dictionary:
	var sx := w * 0.62
	var sz := d * 0.5
	var h := 3.1
	var plaster: Material = _town_or("village_plaster.png", Color(0.96, 0.92, 0.82), "plaster_stone.png", Vector3(2.0, 1.2, 1.0))
	_plinth(r, sx + 0.3, sz + 0.3, Vector3(-0.6, 0, -0.4))
	_box(r, "House", Vector3(sx, h, sz), Vector3(-0.6, h * 0.5 + 0.1, -0.4), plaster)
	_gable_roof(r, Vector3(-0.6, h + 0.1, -0.4), sx + 0.5, sz + 0.6, 1.5, _camp("corrugated_roof.png", Color(0.62, 0.6, 0.56), Vector3(3.0, 2.0, 1.0)))
	_box(r, "Chimney", Vector3(0.45, 1.4, 0.45), Vector3(sx * 0.25 - 0.6, h + 1.2, -0.7), _camp_or("brick_red.png", Color(0.7, 0.42, 0.34), "brick"))
	# The lower annex on the right with a lean-to roof.
	var ax := sx * 0.5 - 0.6 + 1.4
	_box(r, "Annex", Vector3(2.6, 2.3, sz * 0.8), Vector3(ax, 1.25, -0.6), plaster)
	_lean_roof(r, 2.9, sz * 0.8 + 0.5, 2.4, 0.35, _camp("corrugated_roof.png", Color(0.5, 0.48, 0.44), Vector3(2.0, 2.0, 1.0)), Vector3(ax, 0, -0.6))
	# The front: the pub's face (door on the left third, two windows with geraniums, the
	# lamp and the enamel plate) over the whole wall; the porch over its door.
	var front := -0.4 + sz * 0.5
	var face_w := sx
	var door_x := -0.6 - sx * 0.5 + sx * 0.21
	if ResourceLoader.exists(CAMP + "camp_pub_front.png"):
		_quad(r, "PubFront", Vector2(face_w, h), Vector3(-0.6, h * 0.5 + 0.1, front + 0.012), 0.0, _face_mat("camp_pub_front.png"))
	else:
		_box(r, "Door", Vector3(0.95, 2.0, 0.06), Vector3(door_x, 1.1, front + 0.03), _camp("door_wood.png", Color(0.7, 0.62, 0.5)))
		_window(r, Vector3(0.6, 1.7, front + 0.02), Vector2(1.0, 0.8))
		_window(r, Vector3(1.9, 1.7, front + 0.02), Vector2(1.0, 0.8))
	if ResourceLoader.exists(CAMP + "camp_pub_side.png"):
		_quad(r, "PubSide", Vector2(sz, h), Vector3(-0.6 - sx * 0.5 - 0.012, h * 0.5 + 0.1, -0.4), -PI * 0.5, _face_mat("camp_pub_side.png"))
	var awning := _box(r, "Awning", Vector3(1.7, 0.08, 1.1), Vector3(door_x, 2.55, front + 0.55), _flat(Color(0.28, 0.42, 0.26)))
	awning.rotation.x = 0.18
	for x: float in [door_x - 0.78, door_x + 0.78]:
		_box(r, "Post", Vector3(0.1, 2.45, 0.1), Vector3(x, 1.32, front + 1.02), _wood())
	_box(r, "Step", Vector3(1.4, 0.16, 0.5), Vector3(door_x, 0.08, front + 0.3), _psx_mat(Color(0.6, 0.6, 0.58), "stone"))
	_window(r, Vector3(-0.6, 1.9, -0.4 - sz * 0.5 - 0.02), Vector2(0.9, 0.7), PI)
	# The sign, barrels, a crate of empties, a satellite dish and the aerial.
	_box(r, "SignBoard", Vector3(1.6, 0.42, 0.05), Vector3(0.9, 2.65, front + 0.05), _flat(Color(0.2, 0.14, 0.1)))
	_label(r, "HOSPODA", Vector3(0.9, 2.65, front + 0.085), 0.24, Color(0.96, 0.84, 0.5))
	# The barrels and the empties out by the annex, clear of the door.
	for i in 3:
		_cyl(r, "Barrel%d" % i, 0.28, 0.75, Vector3(2.3 + i * 0.62, 0.48, front + 0.5 + (i % 2) * 0.2), _psx_mat(Color(0.5, 0.36, 0.22), "decor_wood"))
	_box(r, "Crate", Vector3(0.5, 0.3, 0.36), Vector3(4.3, 0.25, front + 0.3), _camp_or("beer_crate.png", Color(0.7, 0.5, 0.2), "plastic"))
	_cyl(r, "Dish", 0.32, 0.06, Vector3(sx * 0.5 - 0.6 + 0.05, 2.6, front - 0.6), _flat(Color(0.82, 0.82, 0.8)), Vector3(0.4, 0.0, PI * 0.5))
	_cyl(r, "Aerial", 0.02, 1.6, Vector3(-1.6, h + 1.8, -0.4), _metal())
	_box(r, "AerialBar", Vector3(0.9, 0.03, 0.03), Vector3(-1.6, h + 2.3, -0.4), _metal())
	return {"size": Vector3(sx + 2.4, h + 1.0, sz + 0.6), "target": Vector3(door_x, 1.2, front + 0.2)}


# ── the restaurant (restaurace.PNG): flat roof, tiled band, the red sign ──────

func _restaurant(r: Node3D, w: float, d: float) -> Dictionary:
	var sx := w * 0.72
	var sz := d * 0.52
	var h := 2.9
	var front := sz * 0.5
	_plinth(r, sx + 0.3, sz + 0.3)
	_box(r, "Upper", Vector3(sx, h - 1.0, sz), Vector3(0, 1.0 + (h - 1.0) * 0.5 + 0.1, 0), _camp_or("concrete.png", Color(1.0, 0.98, 0.9), "wall"))
	_box(r, "Tiles", Vector3(sx + 0.02, 1.0, sz + 0.02), Vector3(0, 0.6, 0), _camp_or("tiles_green.png", Color(0.62, 0.8, 0.66), "wall", Vector3(4.0, 1.0, 1.0)))
	_box(r, "Roof", Vector3(sx + 0.3, 0.2, sz + 0.3), Vector3(0, h + 0.2, 0), _camp_or("concrete.png", Color(0.6, 0.6, 0.58), "roof"))
	if ResourceLoader.exists(CAMP + "camp_bistro_front.png"):
		_quad(r, "BistroFront", Vector2(sx, h), Vector3(0, h * 0.5 + 0.1, front + 0.015), 0.0, _face_mat("camp_bistro_front.png"))
	else:
		_box(r, "Door", Vector3(0.9, 2.0, 0.06), Vector3(-0.4, 1.1, front + 0.03), _camp("door_wood.png", Color(0.6, 0.66, 0.6)))
		for x: float in [-2.2, 1.0, 2.0]:
			_window(r, Vector3(x, 1.75, front + 0.02), Vector2(0.85, 0.8))
	var awn := _box(r, "Awning", Vector3(1.4, 0.07, 0.8), Vector3(0.0, 2.55, front + 0.4), _flat(Color(0.86, 0.66, 0.16)))
	awn.rotation.x = 0.25
	# The big red sign on the roof edge.
	_box(r, "Sign", Vector3(sx * 0.62, 0.62, 0.12), Vector3(0, h + 0.62, front - 0.1), _flat(Color(0.74, 0.08, 0.06)))
	_label(r, "RESTAURACE", Vector3(0, h + 0.62, front - 0.03), 0.34, Color(0.98, 0.95, 0.88))
	# A drinks machine, the blue bin, the dish, an AC box, a gas bottle.
	_box(r, "Vending", Vector3(0.8, 1.8, 0.7), Vector3(-sx * 0.5 - 0.2, 1.0, front - 0.6), _flat(Color(0.78, 0.08, 0.06)))
	_box(r, "VendingStripe", Vector3(0.82, 0.25, 0.72), Vector3(-sx * 0.5 - 0.2, 1.3, front - 0.6), _flat(Color(0.95, 0.95, 0.92)))
	_box(r, "Bin", Vector3(1.2, 1.0, 0.8), Vector3(sx * 0.5 + 0.4, 0.6, front - 0.4), _flat(Color(0.16, 0.3, 0.62)))
	var lid := _box(r, "BinLid", Vector3(1.24, 0.06, 0.84), Vector3(sx * 0.5 + 0.4, 1.14, front - 0.42), _flat(Color(0.1, 0.18, 0.4)))
	lid.rotation.x = -0.12
	_cyl(r, "Dish", 0.36, 0.06, Vector3(sx * 0.3, h + 0.8, -0.6), _flat(Color(0.84, 0.84, 0.82)), Vector3(0.6, 0, 0))
	_box(r, "ACUnit", Vector3(0.7, 0.45, 0.5), Vector3(-sx * 0.25, h + 0.52, -0.8), _metal())
	_cyl(r, "Gas", 0.16, 0.6, Vector3(sx * 0.5 + 0.2, 0.4, -0.6), _flat(Color(0.7, 0.24, 0.12)))
	return {"size": Vector3(sx + 1.6, h + 0.9, sz + 0.6), "target": Vector3(0.0, 1.2, front + 0.2)}


# ── the substation (gen.PNG): brick block, steel doors, a transformer on top ──

func _substation(r: Node3D, _w: float, _d: float) -> Dictionary:
	var s := 2.8
	var h := 2.6
	var brick := _camp_or("brick_red.png", Color(0.76, 0.5, 0.4), "brick", Vector3(2.0, 2.0, 1.0))
	_plinth(r, s + 0.3, s + 0.3)
	_box(r, "Block", Vector3(s, h, s), Vector3(0, h * 0.5 + 0.1, 0), brick)
	_box(r, "Slab", Vector3(s + 0.3, 0.16, s + 0.3), Vector3(0, h + 0.18, 0), _camp_or("concrete.png", Color(0.62, 0.62, 0.6), "stone"))
	var steel := _psx_mat(Color(0.52, 0.56, 0.6), "metal")
	for i in 2:
		_box(r, "Door%d" % i, Vector3(0.6, 1.9, 0.05), Vector3(-0.31 + i * 0.62, 1.05, s * 0.5 + 0.03), steel)
		_triangle(r, Vector3(-0.31 + i * 0.62, 1.4, s * 0.5 + 0.06), 0.3, Color(0.95, 0.8, 0.1))
	_box(r, "Plate", Vector3(0.9, 0.34, 0.03), Vector3(0, 2.3, s * 0.5 + 0.03), _flat(Color(0.92, 0.92, 0.9)))
	_label(r, "TP-32", Vector3(0, 2.3, s * 0.5 + 0.05), 0.22, Color(0.7, 0.08, 0.06))
	_box(r, "Steps", Vector3(1.4, 0.2, 0.5), Vector3(0, 0.1, s * 0.5 + 0.35), _camp_or("concrete.png", Color(0.6, 0.6, 0.58), "stone"))
	_box(r, "Vent", Vector3(0.05, 0.4, 0.8), Vector3(s * 0.5 + 0.03, 1.7, 0), _flat(Color(0.2, 0.2, 0.2)))
	# The transformer on the roof: tank, fins, three insulators.
	_box(r, "Transformer", Vector3(1.2, 0.8, 0.8), Vector3(0, h + 0.66, -0.3), steel)
	for i in 4:
		_box(r, "Fin%d" % i, Vector3(0.04, 0.6, 0.9), Vector3(-0.45 + i * 0.3, h + 0.6, -0.3), steel)
	for i in 3:
		_cyl(r, "Insulator%d" % i, 0.07, 0.5, Vector3(-0.36 + i * 0.36, h + 1.3, -0.3), _flat(Color(0.5, 0.36, 0.26)))
	return {"size": Vector3(s + 0.3, h + 1.2, s + 0.3), "target": Vector3(0, 1.1, s * 0.5 + 0.1)}


# ── the sewer (sewer.PNG): a low brick tank with a manhole on top ─────────────

func _sewer(r: Node3D, _w: float, _d: float) -> Dictionary:
	var sx := 3.0
	var sz := 2.0
	var h := 0.8
	_box(r, "Tank", Vector3(sx, h, sz), Vector3(0, h * 0.5, 0), _camp_or("brick_red.png", Color(0.62, 0.42, 0.36), "brick", Vector3(3.0, 1.0, 1.0)))
	_box(r, "Top", Vector3(sx + 0.1, 0.1, sz + 0.1), Vector3(0, h + 0.05, 0), _camp_or("concrete.png", Color(0.56, 0.56, 0.52), "stone"))
	_cyl(r, "Manhole", 0.45, 0.06, Vector3(0.3, h + 0.13, 0), _psx_mat(Color(0.3, 0.3, 0.3), "metal"))
	_cyl(r, "ManholeRim", 0.5, 0.04, Vector3(0.3, h + 0.11, 0), _flat(Color(0.2, 0.2, 0.2)))
	_box(r, "Hatch", Vector3(0.5, 0.5, 0.04), Vector3(-sx * 0.3, 0.38, sz * 0.5 + 0.03), _psx_mat(Color(0.4, 0.4, 0.4), "metal"))
	_cyl(r, "PipeOut", 0.12, 0.6, Vector3(sx * 0.5 + 0.2, 0.3, 0.3), _psx_mat(Color(0.44, 0.36, 0.3), "metal"), Vector3(0, 0, PI * 0.5))
	return {"size": Vector3(sx, h + 0.2, sz), "target": Vector3(0.3, 0.8, sz * 0.5)}


# ── the bonfire: stones, crossed logs, log benches, the fire ──────────────────

func _bonfire(r: Node3D, _w: float, _d: float) -> Dictionary:
	# A camp táborák: scorched ground, a ring of field stones round a bed of ash and coals,
	# a teepee of split logs, three log benches on stumps round it (people sit there: the
	# benches carry "seat" points), a woodpile with a chopping block and the axe in it.
	# The fire itself (flame quads, light, sparks, smoke, sound) is scripts/attractions/campfire.gd.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var bark := _camp_or("log_bark.png", Color(0.86, 0.8, 0.74), "tree_bark", Vector3(1.0, 2.0, 1.0))
	var charred := _camp_or("log_bark.png", Color(0.32, 0.26, 0.22), "tree_bark", Vector3(1.0, 2.0, 1.0))
	var ends := _camp_or("log_end.png", Color(0.95, 0.9, 0.82), "wood")
	var stone := _camp_or("fire_stone.png", Color(0.82, 0.8, 0.78), "stone", Vector3(0.4, 0.4, 1.0))
	var sooty := _camp_or("fire_stone.png", Color(0.42, 0.4, 0.38), "stone", Vector3(0.4, 0.4, 1.0))
	_cyl(r, "Scorch", 1.25, 0.012, Vector3(0, 0.006, 0), _camp_or("fire_ash.png", Color(0.34, 0.3, 0.26), "stone", Vector3(3.0, 3.0, 1.0)))
	var bed := MeshInstance3D.new()
	bed.name = "EmberBed"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.62
	bm.bottom_radius = 0.62
	bm.height = 0.03
	bm.radial_segments = 14
	bed.mesh = bm
	bed.position = Vector3(0, 0.02, 0)
	var bmat := ShaderMaterial.new()
	bmat.shader = load("res://materials/fire_embers.gdshader")
	if ResourceLoader.exists(CAMP + "fire_ash.png"):
		bmat.set_shader_parameter("ash_tex", load(CAMP + "fire_ash.png"))
	bed.material_override = bmat
	r.add_child(bed)
	# The stone ring: fourteen stones, no two alike, the ones on the fire side sooty.
	for i in 14:
		var a := TAU * float(i) / 14.0 + rng.randf_range(-0.08, 0.08)
		var sz := Vector3(rng.randf_range(0.22, 0.34), rng.randf_range(0.14, 0.24), rng.randf_range(0.18, 0.26))
		var rad := 0.78 + rng.randf_range(-0.04, 0.05)
		var st := _box(r, "Stone%d" % i, sz, Vector3(cos(a) * rad, sz.y * 0.5 - 0.02, sin(a) * rad), stone if i % 3 != 0 else sooty)
		st.rotation = Vector3(rng.randf_range(-0.15, 0.15), -a + rng.randf_range(-0.4, 0.4), rng.randf_range(-0.12, 0.12))
	# The teepee: five split logs leaning in, black where the fire has had them.
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.3
		var lg := _box(r, "FireLog%d" % i, Vector3(0.1, 0.78, 0.12), Vector3(cos(a) * 0.2, 0.33, sin(a) * 0.2), charred if i % 2 == 0 else bark)
		# Tip in toward the middle (round the horizontal axis across the log's direction).
		lg.basis = Basis(Vector3(-sin(a), 0, cos(a)), 0.42) * Basis(Vector3.UP, rng.randf() * TAU)
	for i in 2:
		var lg2 := _cyl(r, "FireLog%d" % (5 + i), 0.075, 0.8, Vector3(0, 0.09, 0), charred, Vector3(0, 0.9 + float(i) * 1.6, PI * 0.5))
		lg2.position = Vector3(0.05 - 0.1 * i, 0.09 + 0.05 * i, 0.04 * i)
	# The flames: three fixed-Y quads, the big one behind, a core, a lick to one side.
	var fk := 0
	for f in [[Vector2(1.0, 1.3), Vector3(0, 0.66, 0)], [Vector2(0.72, 1.0), Vector3(0.08, 0.52, 0.06)], [Vector2(0.5, 0.78), Vector3(-0.14, 0.42, -0.05)]]:
		var fl := MeshInstance3D.new()
		fl.name = "FireFlame%d" % fk
		fk += 1
		var q := QuadMesh.new()
		q.size = f[0]
		fl.mesh = q
		fl.position = f[1]
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.add_child(fl)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.6, 0.28)
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = true
	light.shadow_bias = 0.08
	# Above the teepee, so the logs do not throw the whole camp into shadow.
	light.position = Vector3(0, 1.2, 0)
	r.add_child(light)
	var fire := Node3D.new()
	fire.name = "Campfire"
	fire.set_script(load("res://scripts/attractions/campfire.gd"))
	r.add_child(fire)
	# Three log benches: a half log, flat side up, on two stumps; two seats each. The flat
	# face is weathered grey-brown (pale pine burnt out to a flat red by the fire's light).
	var top := _camp_or("knotty_pine.png", Color(0.56, 0.5, 0.44), "wood", Vector3(2.0, 0.5, 1.0))
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.55
		var bench := Node3D.new()
		bench.name = "Bench%d" % i
		bench.position = Vector3(cos(a) * 1.65, 0, sin(a) * 1.65)
		bench.rotation.y = -a + PI * 0.5
		r.add_child(bench)
		_box(bench, "Seat", Vector3(1.5, 0.12, 0.34), Vector3(0, 0.4, 0), bark)
		_box(bench, "SeatTop", Vector3(1.46, 0.02, 0.28), Vector3(0, 0.47, 0), top)
		for x: float in [-0.52, 0.52]:
			_cyl(bench, "Stump", 0.13, 0.36, Vector3(x, 0.18, 0), bark)
			_cyl(bench, "StumpEnd", 0.125, 0.012, Vector3(x, 0.362, 0), ends)
		bench.set_meta("seat", [Vector3(-0.4, 0.47, 0), Vector3(0.4, 0.47, 0)])
	# The woodpile: eight logs in a stack (the ones you throw on), ends out.
	var pile := Node3D.new()
	pile.name = "Woodpile"
	pile.position = Vector3(1.7, 0, -1.25)
	pile.rotation.y = 0.55
	r.add_child(pile)
	var n := 0
	for row in 3:
		for k in 4 - row:
			if n >= 8:
				break
			var lg3 := Node3D.new()
			lg3.name = "PileLog%d" % n
			lg3.position = Vector3(-0.3 + float(k) * 0.2 + float(row) * 0.1, 0.09 + float(row) * 0.16, 0)
			pile.add_child(lg3)
			_cyl(lg3, "Log", 0.085, 0.62, Vector3.ZERO, bark, Vector3(PI * 0.5, 0, 0))
			for z: float in [-0.311, 0.311]:
				_cyl(lg3, "End", 0.083, 0.004, Vector3(0, 0, z), ends, Vector3(PI * 0.5, 0, 0))
			n += 1
	# Woodpile logs are the campfire's: it finds them as its parent's children.
	for c in pile.get_children():
		pile.remove_child(c)
		r.add_child(c)
		c.position = pile.transform * c.position
		c.rotation.y = pile.rotation.y
	# The chopping block, the axe in it, a few split chips.
	_cyl(r, "Block", 0.24, 0.42, Vector3(-1.75, 0.21, -1.05), bark)
	_cyl(r, "BlockTop", 0.235, 0.012, Vector3(-1.75, 0.422, -1.05), ends)
	var axe := Node3D.new()
	axe.name = "Axe"
	axe.position = Vector3(-1.72, 0.43, -1.02)
	axe.rotation = Vector3(0.0, 0.6, -0.5)
	r.add_child(axe)
	_box(axe, "Handle", Vector3(0.04, 0.62, 0.035), Vector3(0, 0.3, 0), _wood())
	_box(axe, "Head", Vector3(0.16, 0.09, 0.03), Vector3(0.05, 0.02, 0), _metal())
	for i in 5:
		var chip := _box(r, "Chip%d" % i, Vector3(0.12, 0.025, 0.05), Vector3(-1.75 + rng.randf_range(-0.5, 0.5), 0.015, -1.05 + rng.randf_range(-0.5, 0.5)), ends)
		chip.rotation.y = rng.randf() * TAU
	return {"size": Vector3(1.8, 0.6, 1.8), "target": Vector3(0, 0.4, 0.8)}


# ── the sports field (iso_sports): a nohejbal court on the camp grass ──────────
#    Mown grass (pitch_grass.png), chalk lines, the low net across the middle, the
#    kids' goals at the ends with their nets, corner flags, a bench and a crate of
#    bottles; the ball. Played on by scripts/attractions/pitch_play.gd.

func _sports(r: Node3D, w: float, d: float) -> Dictionary:
	var px := w * 0.92
	var pz := d * 0.86
	_box(r, "Pitch", Vector3(px, 0.08, pz), Vector3(0, 0.04, 0), _camp_or("pitch_grass.png", Color(0.92, 1.0, 0.9), "grass", Vector3(2.0, 1.0, 2.0)))
	# Worn: the goal mouths and both sides of the net, where everyone stands.
	var worn := _camp_or("gravel_road.png", Color(0.62, 0.52, 0.38), "dirt", Vector3(1.0, 1.0, 1.0))
	for x: float in [-px * 0.5 + 0.7, -px * 0.25, px * 0.25, px * 0.5 - 0.7]:
		_box(r, "Worn", Vector3(0.9 if absf(x) > px * 0.3 else 1.4, 0.084, 0.8), Vector3(x, 0.042, 0.1 if x > 0.0 else -0.1), worn)
	var line := _flat(Color(0.94, 0.94, 0.9))
	_box(r, "LineN", Vector3(px - 0.4, 0.02, 0.06), Vector3(0, 0.09, -pz * 0.5 + 0.2), line)
	_box(r, "LineS", Vector3(px - 0.4, 0.02, 0.06), Vector3(0, 0.09, pz * 0.5 - 0.2), line)
	_box(r, "LineW", Vector3(0.06, 0.02, pz - 0.4), Vector3(-px * 0.5 + 0.2, 0.09, 0), line)
	_box(r, "LineE", Vector3(0.06, 0.02, pz - 0.4), Vector3(px * 0.5 - 0.2, 0.09, 0), line)
	_box(r, "LineMid", Vector3(0.06, 0.02, pz - 0.4), Vector3(0, 0.09, 0), line)
	for side: float in [-1.0, 1.0]:
		_box(r, "LineServe", Vector3(0.05, 0.02, pz - 0.4), Vector3(side * px * 0.18, 0.09, 0), line)
	var net_mat := _net_material()
	# The nohejbal net: two posts, a cord along the top, the mesh hanging under it.
	for z: float in [-pz * 0.5 + 0.08, pz * 0.5 - 0.08]:
		_box(r, "NetPost", Vector3(0.07, 1.16, 0.07), Vector3(0, 0.62, z), _metal())
	_box(r, "NetCord", Vector3(0.025, 0.025, pz - 0.16), Vector3(0, 1.1, 0), line)
	_cord_net(r, "Net", Vector2(pz - 0.2, 0.46), 0.12, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.86, 0)), net_mat)
	# The goals at the ends, nets behind them.
	for side: float in [-1.0, 1.0]:
		var gx := side * (px * 0.5 - 0.22)
		for z: float in [-0.75, 0.75]:
			_box(r, "GoalPost", Vector3(0.07, 1.1, 0.07), Vector3(gx, 0.6, z), line)
		_box(r, "GoalBar", Vector3(0.07, 0.07, 1.57), Vector3(gx, 1.15, 0), line)
		var back := side * 0.5
		_cord_net(r, "GoalNet", Vector2(1.5, 1.1), 0.15, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(gx + back, 0.6, 0)), net_mat)
		for z: float in [-0.75, 0.75]:
			_cord_net(r, "GoalNetSide", Vector2(0.5, 1.1), 0.15, Transform3D(Basis(), Vector3(gx + back * 0.5, 0.6, z)), net_mat)
		_cord_net(r, "GoalNetTop", Vector2(0.5, 1.5), 0.15, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(gx + back * 0.5, 1.15, 0)), net_mat)
	# Corner flags (their cloth stirs: pitch_play.gd).
	var flag_mat := _flat(Color(0.92, 0.3, 0.12))
	flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ci := 0
	for x: float in [-px * 0.5 + 0.2, px * 0.5 - 0.2]:
		for z: float in [-pz * 0.5 + 0.2, pz * 0.5 - 0.2]:
			var f := Node3D.new()
			f.name = "CornerFlag%d" % ci
			f.position = Vector3(x, 0, z)
			r.add_child(f)
			_box(f, "Pole", Vector3(0.03, 0.9, 0.03), Vector3(0, 0.45, 0), line)
			var cloth := Node3D.new()
			cloth.name = "Cloth"
			cloth.position = Vector3(0, 0.8, 0)
			f.add_child(cloth)
			_quad(cloth, "Flag", Vector2(0.22, 0.15), Vector3(0.11, 0, 0), 0.0, flag_mat)
			ci += 1
	# A bench along the side and the crate of bottles under it.
	var bench_wood := _camp_or("knotty_pine.png", Color(0.86, 0.76, 0.62), "wood", Vector3(2.0, 0.5, 1.0))
	var bz := -pz * 0.5 - 0.32
	_box(r, "BenchSeat", Vector3(1.8, 0.07, 0.32), Vector3(1.6, 0.44, bz), bench_wood)
	for x: float in [0.85, 2.35]:
		_box(r, "BenchLeg", Vector3(0.08, 0.42, 0.28), Vector3(x, 0.21, bz), bench_wood)
	_box(r, "Crate", Vector3(0.42, 0.28, 0.3), Vector3(-1.8, 0.14, bz), _camp_or("beer_crate.png", Color(1, 1, 1), "wood"))
	# The ball.
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	sm.radial_segments = 8
	sm.rings = 4
	ball.mesh = sm
	ball.material_override = _ball_material()
	ball.position = Vector3(0.6, 0.11, 0.3)
	r.add_child(ball)
	r.set_meta("court_half", Vector2(px * 0.5 - 0.3, pz * 0.5 - 0.25))
	var play := Node3D.new()
	play.name = "PitchPlay"
	play.set_script(load("res://scripts/attractions/pitch_play.gd"))
	r.add_child(play)
	return {"size": Vector3(px, 0.3, pz), "target": Vector3(0, 0.3, pz * 0.4)}


## Netting cord: off-white, both sides lit alike.
func _net_material() -> StandardMaterial3D:
	if _cache.has("net"):
		return _cache["net"]
	var m := _flat(Color(0.86, 0.86, 0.82))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["net"] = m
	return m


## A net of real cords (thin strips in one mesh), `size` across x and y of the plane
## `xf` puts it in, a square mesh of `cell` metres: crisp at any distance, where a
## see-through texture breaks up into a maze.
func _cord_net(parent: Node3D, n: String, size: Vector2, cell: float, xf: Transform3D, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var th := 0.012
	var cols := maxi(1, int(round(size.x / cell)))
	var rows := maxi(1, int(round(size.y / cell)))
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	for i in cols + 1:
		var x := -hx + size.x * float(i) / float(cols)
		_strip(st, Vector3(x - th, -hy, 0), Vector3(x + th, -hy, 0), Vector3(x + th, hy, 0), Vector3(x - th, hy, 0))
	for j in rows + 1:
		var y := -hy + size.y * float(j) / float(rows)
		_strip(st, Vector3(-hx, y - th, 0), Vector3(hx, y - th, 0), Vector3(hx, y + th, 0), Vector3(-hx, y + th, 0))
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.name = n
	m.mesh = st.commit()
	m.transform = xf
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _strip(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## The ball: white panels and black, the old leather kind.
func _ball_material() -> StandardMaterial3D:
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 8:
			img.set_pixel(x, y, Color(0.12, 0.12, 0.12) if (x + y * 3) % 4 == 0 else Color(0.95, 0.94, 0.9))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.8
	m.set_meta("base_albedo_color", m.albedo_color)
	return m


func _quad(parent: Node3D, n: String, size: Vector2, pos: Vector3, yaw: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	m.position = pos
	m.rotation = rot if rot != Vector3.ZERO else Vector3(0, yaw, 0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


# ── the lake slide (iso_slide): a timber tower, a yellow chute, a tiled pool ─────
#    The tower and ladder in grey planks, the chute in cracked yellow plastic
#    (slide_chute.png) curving down to a round splash pool tiled in blue
#    (pool_tiles.png), a lifebuoy on the tower, towels on a bench. Ridden by
#    scripts/attractions/slide_ride.gd, which reads the chute's line from the metas.

func _slide(r: Node3D, w: float, _d: float) -> Dictionary:
	var wood := _wood()
	var tx := -w * 0.3
	var th := 3.2
	for x: float in [-0.45, 0.45]:
		for z: float in [-0.45, 0.45]:
			_box(r, "Leg", Vector3(0.14, th + 0.9, 0.14), Vector3(tx + x, (th + 0.9) * 0.5, z), wood)
	for y: float in [0.9, 1.9, 2.8]:
		for z: float in [-0.45, 0.45]:
			_box(r, "Brace", Vector3(1.0, 0.08, 0.08), Vector3(tx, y, z), wood)
		var cross := _box(r, "Cross", Vector3(0.08, 0.08, 1.24), Vector3(tx + 0.45, y - 0.45, 0), wood)
		cross.rotation.x = 0.72
	_box(r, "Platform", Vector3(1.1, 0.1, 1.1), Vector3(tx, th, 0), wood)
	for z: float in [-0.5, 0.5]:
		_box(r, "Rail", Vector3(1.1, 0.06, 0.06), Vector3(tx, th + 0.82, z), wood)
		_box(r, "RailMid", Vector3(1.1, 0.05, 0.05), Vector3(tx, th + 0.42, z), wood)
	_box(r, "RailBack", Vector3(0.06, 0.06, 0.6), Vector3(tx - 0.52, th + 0.82, -0.22), wood)
	# The ladder up the back.
	var lx := tx - 0.75
	for z: float in [-0.25, 0.25]:
		_box(r, "LadderRail", Vector3(0.07, th + 0.6, 0.07), Vector3(lx, (th + 0.6) * 0.5, z), wood)
	for i in 8:
		_box(r, "Rung", Vector3(0.06, 0.05, 0.5), Vector3(lx, 0.36 + i * 0.4, 0), wood)
	# A lifebuoy on the tower.
	var buoy := MeshInstance3D.new()
	buoy.name = "Lifebuoy"
	var tor := TorusMesh.new()
	tor.inner_radius = 0.16
	tor.outer_radius = 0.27
	tor.rings = 10
	tor.ring_segments = 6
	buoy.mesh = tor
	buoy.material_override = _flat(Color(0.88, 0.2, 0.14))
	buoy.position = Vector3(tx, 1.4, 0.53)
	buoy.rotation.x = PI * 0.5
	r.add_child(buoy)
	# The chute: from the platform's front edge, steep then flattening, to the lip.
	var chute_mat := _camp_or("slide_chute.png", Color(1, 1, 1), "plastic", Vector3(1.2, 1.2, 1.2))
	var x_top := tx + 0.55
	var x_lip := tx + 0.55 + w * 0.5
	var y_lip := 0.5
	var segs := 9
	var line := PackedVector3Array()
	for i in segs + 1:
		var t := float(i) / float(segs)
		var y := th - (th - y_lip) * (1.0 - (1.0 - t) * (1.0 - t))
		line.append(Vector3(lerpf(x_top, x_lip, t), y, 0))
	for i in segs:
		var a := line[i]
		var b := line[i + 1]
		var len := Vector2(b.x - a.x, b.y - a.y).length()
		var ang := atan2(b.y - a.y, b.x - a.x)
		var seg := _box(r, "Chute%d" % i, Vector3(len + 0.03, 0.06, 0.62), (a + b) * 0.5, chute_mat)
		seg.rotation.z = ang
		for z: float in [-0.33, 0.33]:
			var side := _box(r, "ChuteSide%d" % i, Vector3(len + 0.03, 0.18, 0.05), (a + b) * 0.5 + Vector3(0, 0.09, z), chute_mat)
			side.rotation.z = ang
	# Stilts under the chute's long run.
	for t: float in [0.35, 0.62]:
		var p := line[int(round(t * float(segs)))]
		for z: float in [-0.25, 0.25]:
			_box(r, "ChuteLeg", Vector3(0.1, p.y, 0.1), Vector3(p.x, p.y * 0.5, z), wood)
	# The splash pool: a tiled rim, tiled floor, the water.
	var pool_c := Vector3(x_lip + 0.95, 0, 0)
	var pool_r := 0.95
	var tiles := _camp_or("pool_tiles.png", Color(1, 1, 1), "tiles", Vector3(1.0, 1.0, 1.0))
	_cyl(r, "PoolFloor", pool_r, 0.06, pool_c + Vector3(0, 0.03, 0), tiles)
	var rim_n := 14
	for i in rim_n:
		var a2 := TAU * float(i) / float(rim_n)
		var rim := _box(r, "PoolRim%d" % i, Vector3(0.5, 0.45, 0.16), pool_c + Vector3(cos(a2) * (pool_r + 0.06), 0.225, sin(a2) * (pool_r + 0.06)), tiles)
		rim.rotation.y = -a2 + PI * 0.5
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.5, 0.78, 0.86, 0.82)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	water.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	water.uv1_triplanar = true
	water.uv1_scale = Vector3(0.7, 0.7, 0.7)
	water.set_meta("base_albedo_color", water.albedo_color)
	if ResourceLoader.exists(CAMP + "lake_water.png"):
		water.albedo_texture = load(CAMP + "lake_water.png")
	_cyl(r, "PoolWater", pool_r, 0.04, pool_c + Vector3(0, 0.36, 0), water)
	# Towels drying on a bench by the pool.
	var bench_wood := _camp_or("knotty_pine.png", Color(0.86, 0.76, 0.62), "wood", Vector3(2.0, 0.5, 1.0))
	var bp := pool_c + Vector3(-1.4, 0, 1.45)
	_box(r, "TowelBench", Vector3(1.2, 0.07, 0.3), bp + Vector3(0, 0.42, 0), bench_wood)
	for x: float in [-0.5, 0.5]:
		_box(r, "TowelBenchLeg", Vector3(0.07, 0.4, 0.26), bp + Vector3(x, 0.2, 0), bench_wood)
	_box(r, "Towel", Vector3(0.42, 0.02, 0.34), bp + Vector3(-0.25, 0.47, 0), _camp_or("blanket_check.png", Color(1.0, 0.8, 0.7), "cloth"))
	r.set_meta("slide_chute", line)
	r.set_meta("slide_ladder", [Vector3(lx - 0.25, 0, 0), Vector3(lx - 0.1, th + 0.05, 0), Vector3(tx - 0.1, th + 0.05, 0)])
	r.set_meta("slide_pool", [pool_c, pool_r])
	var ride := Node3D.new()
	ride.name = "SlideRide"
	ride.set_script(load("res://scripts/attractions/slide_ride.gd"))
	r.add_child(ride)
	return {"size": Vector3(w * 0.9, th + 0.9, 1.3), "target": Vector3(tx, 1.0, 0.7)}


# ── dumpsters: two blue bins, lids ajar ───────────────────────────────────────

func _dumpsters(r: Node3D, _w: float, _d: float) -> Dictionary:
	for i in 2:
		var x := -0.7 + i * 1.45
		var c := Color(0.16, 0.3, 0.6) if i == 0 else Color(0.2, 0.42, 0.26)
		_box(r, "Bin%d" % i, Vector3(1.3, 1.1, 0.9), Vector3(x, 0.6, 0), _psx_mat(c, "metal"))
		var lid := _box(r, "Lid%d" % i, Vector3(1.34, 0.06, 0.94), Vector3(x, 1.18, -0.02), _flat(c.darkened(0.4)))
		lid.rotation.x = -0.1 - 0.25 * i
		for wx: float in [-0.5, 0.5]:
			_cyl(r, "Wheel", 0.08, 0.06, Vector3(x + wx, 0.08, 0.4), _flat(Color(0.08, 0.08, 0.08)), Vector3(0, 0, PI * 0.5))
	_box(r, "Bag", Vector3(0.45, 0.45, 0.4), Vector3(0.1, 0.22, 0.75), _flat(Color(0.07, 0.07, 0.08)))
	return {"size": Vector3(2.8, 1.3, 1.0), "target": Vector3(0, 0.8, 0.5)}


# ── cabins (chata1/2/3.PNG): plank huts under a gable of rusty tin ────────────

## Lv1 sun-bleached grey planks, Lv2 oxblood red, Lv3 dark creosote; the same tin roof
## patched with rust. Front +Z: the door between two windows. Returns the wall box.
func cabin(r: Node3D, level: int, _w := 0.0, _d := 0.0, _wall_h := 0.0, _roof_h := 0.0) -> Vector3:
	# One plan for the model and the room inside it (scripts/cabin_layout.gd): the windows
	# are where the room has them, each tier a visible step up from the last.
	#   Lv1  weathered grey boards, rust on the tin, a concrete block for a step, firewood
	#   Lv2  boards painted red, white trim, a porch with a little roof over the door, a
	#        flower box, the bathroom built on at the right
	#   Lv3  stained dark boards, green shutters, the chimney of the stove inside, the TV
	#        aerial, gutters, a deep porch with its bench and a lantern by the door
	var lv := clampi(level, 1, 3)
	var s: Vector2 = CL.size(lv)
	var w := s.x
	var d := s.y
	var wall_h: float = CL.wall_h(lv)
	var roof_h: float = CL.roof_rise(lv)
	var top := wall_h + 0.1
	var plank_file := ["planks_grey.png", "planks_red.png", "planks_dark.png"][lv - 1] as String
	var tint := [Color(0.86, 0.84, 0.8), Color(0.95, 0.85, 0.82), Color(0.92, 0.86, 0.8)][lv - 1] as Color
	var walls := _camp(plank_file, tint, Vector3(1.4, 1.4, 1.0))
	var trim: Material = _wood() if lv == 1 else _camp("planks_grey.png", Color(0.96, 0.95, 0.9) if lv == 2 else Color(0.86, 0.84, 0.76))
	_plinth(r, w + 0.2, d + 0.2)
	_box(r, "Walls", Vector3(w, wall_h, d), Vector3(0, wall_h * 0.5 + 0.1, 0), walls)
	for x: float in [-w * 0.5, w * 0.5]:
		for z: float in [-d * 0.5, d * 0.5]:
			_box(r, "Corner", Vector3(0.14, wall_h, 0.14), Vector3(x, wall_h * 0.5 + 0.1, z), trim)
	var tin := _camp("corrugated_roof.png", [Color(0.7, 0.66, 0.62), Color(0.78, 0.74, 0.7), Color(0.56, 0.6, 0.56)][lv - 1] as Color, Vector3(1.6, 1.6, 1.0))
	_gable_roof(r, Vector3(0, top, 0), w + 0.5, d + 0.7, roof_h, tin, walls)
	# Rust on the tin: the basic cabin has the most, the best none.
	var rust := _camp("corrugated_roof.png", Color(0.62, 0.36, 0.22), Vector3(1.6, 1.6, 1.0))
	var ang := atan2(roof_h, (d + 0.7) * 0.5)
	for i in [3, 1, 0][lv - 1]:
		var side := 1.0 if i % 2 == 0 else -1.0
		var p := _box(r, "Rust%d" % i, Vector3(0.8 + 0.3 * i, 0.03, 0.6), Vector3(-w * 0.25 + i * w * 0.24, top + roof_h * 0.56 + 0.06, side * (d + 0.7) * 0.22), rust)
		p.rotation.x = side * ang
	var front := d * 0.5
	# The door in the middle of the front.
	_box(r, "Door", Vector3(CL.DOOR_W, CL.DOOR_H, 0.06), Vector3(0, CL.MODEL_FLOOR + CL.DOOR_H * 0.5, front + 0.03), _camp("door_wood.png", [Color(0.74, 0.68, 0.6), Color(0.62, 0.78, 0.66), Color(0.82, 0.66, 0.54)][lv - 1] as Color))
	_box(r, "DoorFrame", Vector3(CL.DOOR_W + 0.16, CL.DOOR_H + 0.12, 0.04), Vector3(0, CL.MODEL_FLOOR + CL.DOOR_H * 0.5 + 0.03, front + 0.01), trim)
	# The cabin's number on an enamel plate right of the door (scripts/lodging_signs.gd).
	r.set_meta("number_plate", Transform3D(Basis(), Vector3(0.66, 1.72, front + 0.04)))
	# The windows, as the room has them.
	for win in CL.windows(lv):
		var c: Vector3 = win["centre"]
		var o: Vector3 = win["out"]
		var yaw := atan2(o.x, o.z)
		_window(r, c + o * 0.02, win["size"], yaw, trim)
		if lv == 3 and str(win["wall"]) == "front":
			# Green shutters folded back either side of it.
			var sw: Vector2 = win["size"]
			for sx: float in [-1.0, 1.0]:
				_box(r, "Shutter", Vector3(sw.x * 0.5, sw.y + 0.1, 0.04), c + Vector3(sx * (sw.x * 0.75 + 0.1), 0, 0.05), _camp("planks_grey.png", Color(0.44, 0.62, 0.42)))
	if CL.has_bath(lv):
		_bathroom_annex(r, w, wall_h, walls, trim, tin, lv)
	match lv:
		1:
			# A concrete block for a step, firewood stacked at the side, a bucket.
			_box(r, "Step", Vector3(0.6, 0.2, 0.4), Vector3(0, 0.1, front + 0.3), _camp_or("concrete.png", Color(0.6, 0.6, 0.56), "stone"))
			for i in 4:
				_cyl(r, "Firewood", 0.1, 0.8, Vector3(-w * 0.5 - 0.3, 0.12 + i * 0.18, -0.6 + (i % 2) * 0.1), _psx_mat(Color(0.5, 0.36, 0.24), "tree_bark"), Vector3(PI * 0.5, 0, 0))
			_cyl(r, "Bucket", 0.16, 0.3, Vector3(w * 0.5 + 0.35, 0.15, front - 0.3), _metal())
		2:
			# A porch board with two posts and a little tin roof over the door, the flower box.
			_porch(r, w * 0.62, 0.95, front, trim, tin, false)
			_box(r, "FlowerBox", Vector3(CL.FRONT_WIN.x + 0.1, 0.16, 0.2), Vector3(CL.FRONT_WIN_X, CL.MODEL_FLOOR + CL.SILL_MID - CL.FRONT_WIN.y * 0.5 - 0.12, front + 0.13), _wood())
			for i in 4:
				_box(r, "Flower", Vector3(0.08, 0.12, 0.08), Vector3(CL.FRONT_WIN_X - 0.24 + i * 0.16, CL.MODEL_FLOOR + CL.SILL_MID - CL.FRONT_WIN.y * 0.5, front + 0.13), _flat([Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.2)][i % 2]))
		3:
			_porch(r, w * 0.9, 1.25, front, trim, tin, true)
			# The stove's chimney over the front left corner, where the stove stands inside.
			var cx := -w * 0.5 + 0.44
			var cz := front - CL.STOVE_FROM_FRONT
			var roof_at := top + roof_h * (1.0 - absf(cz) / ((d + 0.7) * 0.5))
			_box(r, "Chimney", Vector3(0.42, 1.0, 0.42), Vector3(cx, roof_at + 0.32, cz), _camp_or("brick_red.png", Color(0.62, 0.44, 0.38), "brick"))
			_box(r, "ChimneyCap", Vector3(0.52, 0.06, 0.52), Vector3(cx, roof_at + 0.85, cz), _metal())
			# The TV's aerial on the ridge.
			_cyl(r, "AerialMast", 0.02, 1.0, Vector3(w * 0.25, top + roof_h + 0.5, 0), _metal())
			for i in 3:
				_box(r, "AerialBar", Vector3(0.7 - i * 0.14, 0.02, 0.02), Vector3(w * 0.25, top + roof_h + 0.62 + i * 0.16, 0), _metal())
			# Gutters along the eaves, a downpipe at the front corner.
			for gz: float in [-1.0, 1.0]:
				_box(r, "Gutter", Vector3(w + 0.5, 0.07, 0.1), Vector3(0, top - 0.02, gz * (d * 0.5 + 0.37)), _metal())
			_box(r, "Downpipe", Vector3(0.07, top, 0.07), Vector3(w * 0.5 + 0.2, top * 0.5, front + 0.37), _metal())
	return Vector3(w + 0.4, wall_h + roof_h + 0.3, d + 0.4)


## The porch in front of the door: boards on the ground, two posts and a tin roof over the
## door; `bench` the better one's bench under the right window and the lantern by the door.
func _porch(r: Node3D, pw: float, pd: float, front: float, trim: Material, tin: Material, bench: bool) -> void:
	_box(r, "Porch", Vector3(pw, 0.12, pd), Vector3(0, 0.12, front + pd * 0.5), _wood())
	_box(r, "PorchStep", Vector3(1.0, 0.08, 0.3), Vector3(0, 0.05, front + pd + 0.15), _wood())
	var post_h := CL.MODEL_FLOOR + CL.DOOR_H + 0.3
	for px: float in [-pw * 0.5 + 0.08, pw * 0.5 - 0.08]:
		_box(r, "PorchPost", Vector3(0.1, post_h, 0.1), Vector3(px, post_h * 0.5 + 0.1, front + pd - 0.08), trim)
	var roof := _box(r, "PorchRoof", Vector3(pw + 0.2, 0.06, pd + 0.2), Vector3(0, post_h + 0.22, front + pd * 0.5), tin)
	roof.rotation.x = 0.2
	if bench:
		_box(r, "Bench", Vector3(1.0, 0.06, 0.32), Vector3(CL.FRONT_WIN_X, 0.55, front + 0.3), _wood())
		for bx: float in [-0.42, 0.42]:
			_box(r, "BenchLeg", Vector3(0.06, 0.4, 0.28), Vector3(CL.FRONT_WIN_X + bx, 0.33, front + 0.3), _wood())
		for rx: float in [-pw * 0.5 + 0.08, pw * 0.5 - 0.08]:
			_box(r, "PorchRail", Vector3(0.06, 0.06, pd - 0.1), Vector3(rx, 0.95, front + pd * 0.5), trim)
		var lamp := _box(r, "Lantern", Vector3(0.14, 0.2, 0.12), Vector3(-CL.DOOR_W * 0.5 - 0.22, CL.MODEL_FLOOR + 1.9, front + 0.08), _flat(Color(0.95, 0.86, 0.6)))
		lamp.set_meta("porch_lantern", true)


# ── tents (stan1/2/3.png): pegs, guy ropes, the door flap ─────────────────────

## Details for one A-frame tent of `w` x `h` x `d` (ridge along Z) placed at `at`.
func tent_details(r: Node3D, w: float, h: float, d: float, at: Vector3, yaw: float, color: Color) -> void:
	var t := Node3D.new()
	t.position = at
	t.rotation.y = yaw
	r.add_child(t)
	var flap := _prism_flap(w * 0.55, h * 0.8, color.darkened(0.45))
	flap.name = "TentFlap"
	flap.position = Vector3(0, 0, d * 0.5 + 0.015)
	t.add_child(flap)
	var rope := _flat(Color(0.84, 0.8, 0.66))
	var peg := _flat(Color(0.3, 0.3, 0.3))
	for z: float in [-d * 0.5, d * 0.5]:
		_cyl(t, "Pole", 0.02, h + 0.1, Vector3(0, (h + 0.1) * 0.5, z + signf(z) * 0.03), _wood())
		var end := Vector3(0, 0.02, z + signf(z) * 0.7)
		var top := Vector3(0, h + 0.05, z + signf(z) * 0.03)
		var mid := (end + top) * 0.5
		var line := _box(t, "GuyRope", Vector3(0.015, (top - end).length(), 0.015), mid, rope)
		line.rotation.x = -signf(z) * atan2(absf(end.z - top.z), top.y - end.y)
		_box(t, "Peg", Vector3(0.04, 0.12, 0.04), end, peg)
	for x: float in [-w * 0.5 - 0.1, w * 0.5 + 0.1]:
		for z: float in [-d * 0.35, d * 0.35]:
			_box(t, "Peg", Vector3(0.04, 0.1, 0.04), Vector3(x, 0.03, z), peg)


func _prism_flap(base: float, rise: float, c: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(-base * 0.5, 0, 0), Vector3(base * 0.5, 0, 0), Vector3(0, rise, 0)]:
		st.add_vertex(p)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := _flat(c)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	return m


## Tent cloth: the camp's canvas tinted to the level colour.
func tent_cloth(color: Color) -> StandardMaterial3D:
	var mat := _camp("tarp_canvas.png", color.lerp(Color.WHITE, 0.12), Vector3(1.5, 1.5, 1.0))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_triplanar = false
	mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
	return mat


# ── the caravan (caravan.png): a cream two-tone van with a striped awning ─────

func caravan(r: Node3D, w: float, d: float, level := 1) -> Vector3:
	# The old Czechoslovak tourer of the Builder's sprites (iso_caravan / 2 / 3): ribbed
	# cream aluminium over a band (brown on the old one, red once done up), round ends,
	# the door and curtained windows on the camp side (+Z), on its axle with the drawbar.
	#   Lv1  worn, a little awning over the window, the gas bottle, one folding chair
	#   Lv2  the big striped awning on two poles, two chairs and a table, the red band
	#   Lv3  fairy lights along the awning (lit at night), the TV aerial, wooden steps,
	#        geraniums in a pot, a second axle
	var lx := w * 0.62
	var lz := d * 0.5
	var h := 1.9
	var y0 := 0.42
	var lv := clampi(level, 1, 3)
	var worn := Color(0.86, 0.82, 0.74) if lv == 1 else Color(1, 1, 1)
	var cream := _flat(Color(0.9, 0.86, 0.74) * worn)
	var band_col := Color(0.5, 0.34, 0.22) if lv == 1 else Color(0.66, 0.2, 0.16)
	var band := _flat(band_col)
	var skin := _camp_or("caravan_body.png", worn, "metal", Vector3(1.0, 1.0, 1.0))
	# The box of it: the textured sides (the ribs and the band are in the texture),
	# a plain roof, the lower skirt in the band colour.
	_box(r, "Body", Vector3(lx, h * 0.62, lz), Vector3(0, y0 + h * 0.31 + h * 0.38, 0), cream)
	_box(r, "Lower", Vector3(lx, h * 0.38, lz), Vector3(0, y0 + h * 0.19, 0), band)
	for side: float in [-1.0, 1.0]:
		_side_quad(r, "Skin", Vector2(lx, h), Vector3(0, y0 + h * 0.5, side * (lz * 0.5 + 0.004)), 0.0 if side > 0.0 else PI, skin, Vector3(lx / 1.9, 1.0, 1.0))
	# Rounded ends: half cylinders, cream over the band.
	for side: float in [-1.0, 1.0]:
		var cap := _cyl(r, "End", lz * 0.5, h * 0.62, Vector3(side * lx * 0.5, y0 + h * 0.69, 0), cream)
		cap.scale = Vector3(0.45, 1.0, 1.0)
		var capl := _cyl(r, "EndLow", lz * 0.5 + 0.005, h * 0.38, Vector3(side * lx * 0.5, y0 + h * 0.19, 0), band)
		capl.scale = Vector3(0.45, 1.0, 1.0)
	_box(r, "Roof", Vector3(lx + 0.02, 0.06, lz + 0.02), Vector3(0, y0 + h + 0.03, 0), cream)
	_box(r, "RoofVent", Vector3(0.5, 0.12, 0.4), Vector3(-lx * 0.15, y0 + h + 0.09, 0), _flat(Color(0.95, 0.94, 0.9)))
	# The door and the windows on the camp side; windows on the back too.
	var door_x := -lx * 0.25
	_side_quad(r, "Door", Vector2(0.62, 1.55), Vector3(door_x, y0 + 0.85, lz * 0.5 + 0.012), 0.0, _camp_or("caravan_door.png", Color(1, 1, 1), "wood"))
	# Its number on an enamel plate beside the door (scripts/lodging_signs.gd).
	r.set_meta("number_plate", Transform3D(Basis(), Vector3(door_x + 0.56, y0 + 1.2, lz * 0.5 + 0.03)))
	var glass := _camp_or("caravan_window.png", Color(1, 1, 1), "glass")
	# (Lit at night while the guests are in: scripts/ambient/window_lights.gd.)
	for wx: float in [lx * 0.14, lx * 0.37]:
		_side_quad(r, "Window", Vector2(0.78, 0.56), Vector3(wx, y0 + h * 0.66, lz * 0.5 + 0.012), 0.0, glass).set_meta("lit_window", true)
	_side_quad(r, "WindowSide", Vector2(0.62, 0.5), Vector3(-lx * 0.4, y0 + h * 0.66, lz * 0.5 + 0.012), 0.0, glass).set_meta("lit_window", true)
	for wx2: float in [-lx * 0.3, lx * 0.05, lx * 0.33]:
		_side_quad(r, "WindowBack", Vector2(0.7, 0.5), Vector3(wx2, y0 + h * 0.66, -lz * 0.5 - 0.012), PI, glass).set_meta("lit_window", true)
	# Running gear: one axle (two on Lv3), the drawbar with its jockey wheel, the gas.
	var axles: Array = [0.0] if lv < 3 else [-0.36, 0.36]
	for ax in axles:
		for side: float in [-1.0, 1.0]:
			_cyl(r, "Wheel", 0.32, 0.2, Vector3(float(ax), 0.32, side * (lz * 0.5 + 0.02)), _flat(Color(0.08, 0.08, 0.08)), Vector3(PI * 0.5, 0, 0))
			_cyl(r, "Hub", 0.12, 0.22, Vector3(float(ax), 0.32, side * (lz * 0.5 + 0.03)), _metal(), Vector3(PI * 0.5, 0, 0))
	var bar := _box(r, "Drawbar", Vector3(1.0, 0.08, 0.08), Vector3(lx * 0.5 + 0.7, 0.42, 0), _metal())
	bar.rotation.z = 0.08
	_cyl(r, "Gas", 0.15, 0.5, Vector3(lx * 0.5 + 0.55, 0.7, 0), _flat(Color(0.72, 0.22, 0.12)))
	_box(r, "Jack", Vector3(0.06, 0.42, 0.06), Vector3(lx * 0.5 + 1.1, 0.21, 0), _metal())
	for x: float in [-lx * 0.42, lx * 0.42]:
		_box(r, "Prop", Vector3(0.1, y0, 0.1), Vector3(x, y0 * 0.5, lz * 0.35), _metal())
	# The awning: a stub over the window on Lv1, the big one on poles from Lv2.
	var stripe_a := _flat(Color(0.86, 0.2, 0.16))
	var stripe_b := _flat(Color(0.95, 0.94, 0.88))
	if lv == 1:
		for i in 4:
			var st := _box(r, "Awning%d" % i, Vector3(0.22, 0.04, 0.5), Vector3(lx * 0.14 - 0.33 + i * 0.22, y0 + h * 0.66 + 0.42, lz * 0.5 + 0.22), stripe_a if i % 2 == 0 else stripe_b)
			st.rotation.x = 0.42
	else:
		for i in 8:
			var st2 := _box(r, "Awning%d" % i, Vector3(0.26, 0.04, 1.3), Vector3(door_x - 0.9 + i * 0.26, y0 + h - 0.08, lz * 0.5 + 0.6), stripe_a if i % 2 == 0 else stripe_b)
			st2.rotation.x = 0.2
		_box(r, "AwningValance", Vector3(2.08, 0.14, 0.03), Vector3(door_x, y0 + h - 0.28, lz * 0.5 + 1.24), stripe_a)
		for x: float in [door_x - 0.98, door_x + 0.98]:
			_box(r, "AwningPole", Vector3(0.04, y0 + h - 0.2, 0.04), Vector3(x, (y0 + h - 0.2) * 0.5, lz * 0.5 + 1.25), _metal())
	# Out front: chairs (and a table from Lv2).
	var chair := _flat(Color(0.86, 0.2, 0.16) if lv >= 2 else Color(0.2, 0.36, 0.62))
	var n_chairs := 1 if lv == 1 else 2
	for i in n_chairs:
		var cx := lx * 0.08 + i * 0.95
		_box(r, "ChairSeat", Vector3(0.45, 0.04, 0.45), Vector3(cx, 0.42, lz * 0.5 + 1.1), chair)
		var back := _box(r, "ChairBack", Vector3(0.45, 0.5, 0.04), Vector3(cx, 0.68, lz * 0.5 + 1.32), chair)
		back.rotation.x = -0.2
		for lx2: float in [-0.18, 0.18]:
			_box(r, "ChairLeg", Vector3(0.03, 0.42, 0.03), Vector3(cx + lx2, 0.21, lz * 0.5 + 1.1), _metal())
	if lv >= 2:
		_box(r, "TableTop", Vector3(0.6, 0.04, 0.6), Vector3(lx * 0.08 + 0.48, 0.66, lz * 0.5 + 1.0), _flat(Color(0.95, 0.94, 0.88)))
		_box(r, "TableLeg", Vector3(0.05, 0.64, 0.05), Vector3(lx * 0.08 + 0.48, 0.32, lz * 0.5 + 1.0), _metal())
		_box(r, "Doormat", Vector3(0.6, 0.02, 0.4), Vector3(door_x, 0.01, lz * 0.5 + 0.45), _flat(Color(0.36, 0.3, 0.2)))
	if lv >= 3:
		# The steps up to the door, geraniums, the aerial, the fairy lights.
		var step_wood := _camp_or("knotty_pine.png", Color(0.86, 0.76, 0.62), "wood", Vector3(1.0, 1.0, 1.0))
		_box(r, "Step1", Vector3(0.6, 0.16, 0.26), Vector3(door_x, 0.08, lz * 0.5 + 0.28), step_wood)
		_box(r, "Step2", Vector3(0.6, 0.16, 0.2), Vector3(door_x, 0.24, lz * 0.5 + 0.12), step_wood)
		_cyl(r, "FlowerPot", 0.16, 0.24, Vector3(door_x + 0.55, 0.12, lz * 0.5 + 0.3), _flat(Color(0.66, 0.32, 0.18)))
		for i in 5:
			var a := TAU * float(i) / 5.0
			_box(r, "Geranium", Vector3(0.1, 0.1, 0.1), Vector3(door_x + 0.55 + cos(a) * 0.08, 0.32 + float(i % 2) * 0.05, lz * 0.5 + 0.3 + sin(a) * 0.08), _flat(Color(0.86, 0.12, 0.16)))
		_box(r, "AerialMast", Vector3(0.04, 0.7, 0.04), Vector3(lx * 0.3, y0 + h + 0.4, -lz * 0.2), _metal())
		_box(r, "AerialBoom", Vector3(0.7, 0.03, 0.03), Vector3(lx * 0.3, y0 + h + 0.72, -lz * 0.2), _metal())
		for i in 5:
			_box(r, "AerialRod", Vector3(0.03, 0.03, 0.34 - i * 0.04), Vector3(lx * 0.3 - 0.3 + i * 0.15, y0 + h + 0.72, -lz * 0.2), _metal())
		var bulb := StandardMaterial3D.new()
		bulb.albedo_color = Color(1.0, 0.86, 0.5)
		bulb.emission_enabled = true
		bulb.emission = Color(1.0, 0.78, 0.4)
		bulb.emission_energy_multiplier = 0.0
		bulb.set_meta("base_albedo_color", bulb.albedo_color)
		var lights := Node3D.new()
		lights.name = "FairyLights"
		r.add_child(lights)
		for i in 9:
			var bx := door_x - 0.96 + i * 0.24
			_box(lights, "Bulb%d" % i, Vector3(0.05, 0.06, 0.05), Vector3(bx, y0 + h - 0.38 - absf(sin(float(i) * 0.9)) * 0.05, lz * 0.5 + 1.25), bulb)
		lights.set_meta("bulb_material", bulb)
	return Vector3(lx + lz * 0.5, y0 + h + 0.2, lz)


## A flat face on a side of a model (a door, a window, a skin), `yaw` turning it to
## face out; `uv` repeats the texture across it.
func _side_quad(parent: Node3D, n: String, size: Vector2, pos: Vector3, yaw: float, mat: Material, uv := Vector3.ONE) -> MeshInstance3D:
	var m := _quad(parent, n, size, pos, yaw, mat)
	if uv != Vector3.ONE and mat is StandardMaterial3D:
		var mm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		mm.uv1_triplanar = false
		mm.uv1_scale = uv
		m.material_override = mm
	elif mat is StandardMaterial3D and (mat as StandardMaterial3D).uv1_triplanar:
		var m2 := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		m2.uv1_triplanar = false
		m2.uv1_scale = Vector3.ONE
		m.material_override = m2
	return m


# ── decorations and small attractions (iso_bench .. iso_hammock in the Builder) ──
#    Plain boxes with the camp's textures, Build style. The ones guests use carry
#    their places as the "seats" meta ([{pos, face, pose}], local) for
#    scripts/attractions/seats_use.gd; the playground, the table and the flag have
#    their own scripts.

func _bench(r: Node3D, _w: float, _d: float) -> Dictionary:
	var green := _camp_or("planks_grey.png", Color(0.4, 0.62, 0.42), "wood", Vector3(2.0, 1.0, 1.0))
	var iron := _flat(Color(0.12, 0.12, 0.13))
	for x: float in [-0.68, 0.68]:
		_box(r, "BenchLeg", Vector3(0.06, 0.44, 0.44), Vector3(x, 0.22, 0.0), iron)
		var back_leg := _box(r, "BenchBackLeg", Vector3(0.06, 0.5, 0.05), Vector3(x, 0.66, -0.22), iron)
		back_leg.rotation.x = -0.18
	for i in 3:
		_box(r, "BenchSlat", Vector3(1.6, 0.04, 0.12), Vector3(0, 0.45, -0.14 + i * 0.14), green)
	for i in 2:
		var slat := _box(r, "BenchBack", Vector3(1.6, 0.11, 0.035), Vector3(0, 0.66 + i * 0.16, -0.25 - i * 0.03), green)
		slat.rotation.x = -0.18
	_box(r, "Newspaper", Vector3(0.3, 0.01, 0.24), Vector3(0.58, 0.475, 0.02), _flat(Color(0.84, 0.82, 0.74)))
	r.set_meta("seats", [
		{"pos": Vector3(-0.4, 0.0, 0.26), "face": Vector3(0, 0, 1), "pose": "sit"},
		{"pos": Vector3(0.35, 0.0, 0.26), "face": Vector3(0, 0, 1), "pose": "sit"},
	])
	_use_script(r, "res://scripts/attractions/seats_use.gd")
	return {"size": Vector3(1.7, 0.9, 0.6), "target": Vector3(0, 0.6, 0.4)}


func _picnic(r: Node3D, _w: float, _d: float) -> Dictionary:
	var wood := _camp_or("planks_grey.png", Color(0.9, 0.84, 0.74), "wood", Vector3(2.0, 1.0, 1.0))
	_box(r, "TableTop", Vector3(1.7, 0.06, 0.8), Vector3(0, 0.74, 0), wood)
	for side: float in [-1.0, 1.0]:
		_box(r, "Bench", Vector3(1.7, 0.05, 0.26), Vector3(0, 0.44, side * 0.62), wood)
	for x: float in [-0.66, 0.66]:
		for side2: float in [-1.0, 1.0]:
			var leg := _box(r, "Leg", Vector3(0.07, 0.8, 0.07), Vector3(x, 0.38, side2 * 0.3), wood)
			leg.rotation.x = side2 * 0.42
		_box(r, "Brace", Vector3(0.07, 0.07, 1.5), Vector3(x, 0.4, 0), wood)
	_box(r, "Cloth", Vector3(0.9, 0.01, 0.82), Vector3(-0.25, 0.775, 0.02), _camp_or("gingham.png", Color(1, 1, 1), "cloth", Vector3(2.0, 2.0, 2.0)))
	_cyl(r, "Bottle", 0.035, 0.24, Vector3(0.35, 0.89, -0.1), _flat(Color(0.26, 0.4, 0.18)))
	_box(r, "Roll", Vector3(0.2, 0.06, 0.08), Vector3(0.12, 0.8, 0.18), _flat(Color(0.82, 0.6, 0.32)))
	var seats: Array = []
	for side3: float in [-1.0, 1.0]:
		for x2: float in [-0.42, 0.42]:
			seats.append({"pos": Vector3(x2, 0.0, side3 * 0.78), "face": Vector3(0, 0, -side3), "pose": "eat"})
	r.set_meta("seats", seats)
	_use_script(r, "res://scripts/attractions/seats_use.gd")
	return {"size": Vector3(1.8, 0.85, 1.5), "target": Vector3(0, 0.6, 0.8)}


func _flowerbed(r: Node3D, _w: float, _d: float) -> Dictionary:
	var stone := _flat(Color(0.88, 0.86, 0.8))
	var soil := _flat(Color(0.26, 0.17, 0.1))
	_box(r, "Soil", Vector3(1.6, 0.22, 1.0), Vector3(0, 0.11, 0), soil)
	var n := 0
	for i in 7:
		var x := -0.78 + i * 0.26
		for z: float in [-0.52, 0.52]:
			var st := _box(r, "Stone%d" % n, Vector3(0.22, 0.18, 0.12), Vector3(x, 0.09, z), stone)
			st.rotation.y = float(n % 3) * 0.1 - 0.1
			n += 1
	for z2: float in [-0.26, 0.0, 0.26]:
		for side: float in [-1.0, 1.0]:
			_box(r, "Stone%d" % n, Vector3(0.12, 0.18, 0.22), Vector3(side * 0.82, 0.09, z2), stone)
			n += 1
	var cols := [Color(0.88, 0.14, 0.12), Color(0.96, 0.78, 0.12), Color(0.24, 0.42, 0.9), Color(0.94, 0.94, 0.9)]
	var leaf := _flat(Color(0.2, 0.42, 0.18))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in 30:
		var at := Vector3(rng.randf_range(-0.66, 0.66), 0.22, rng.randf_range(-0.38, 0.38))
		var h := rng.randf_range(0.12, 0.3)
		_box(r, "Stem", Vector3(0.03, h, 0.03), at + Vector3(0, h * 0.5, 0), leaf)
		_box(r, "Bloom", Vector3(0.09, 0.07, 0.09), at + Vector3(0, h + 0.03, 0), _flat(cols[i % cols.size()]))
	_cyl(r, "WateringCan", 0.1, 0.2, Vector3(1.0, 0.1, 0.3), _flat(Color(0.3, 0.52, 0.4)))
	var spout := _box(r, "Spout", Vector3(0.24, 0.03, 0.03), Vector3(1.12, 0.17, 0.3), _flat(Color(0.3, 0.52, 0.4)))
	spout.rotation.z = 0.5
	return {"size": Vector3(1.7, 0.5, 1.1), "target": Vector3(0, 0.4, 0.6)}


func _gnome(r: Node3D, _w: float, _d: float) -> Dictionary:
	var g := Node3D.new()
	g.name = "Gnome"
	r.add_child(g)
	_cyl(g, "Moss", 0.3, 0.04, Vector3(0, 0.02, 0), _flat(Color(0.24, 0.4, 0.16)))
	_cyl(g, "Boots", 0.11, 0.06, Vector3(0, 0.07, 0.02), _flat(Color(0.3, 0.18, 0.1)))
	var coat := _cyl(g, "Coat", 0.11, 0.22, Vector3(0, 0.2, 0), _flat(Color(0.2, 0.32, 0.66)))
	(coat.mesh as CylinderMesh).top_radius = 0.08
	_cyl(g, "Belt", 0.105, 0.03, Vector3(0, 0.25, 0), _flat(Color(0.14, 0.1, 0.06)))
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sm := SphereMesh.new()
	sm.radius = 0.075
	sm.height = 0.15
	sm.radial_segments = 8
	sm.rings = 4
	head.mesh = sm
	head.material_override = _flat(Color(0.94, 0.74, 0.6))
	head.position = Vector3(0, 0.37, 0)
	g.add_child(head)
	_box(g, "Beard", Vector3(0.12, 0.12, 0.06), Vector3(0, 0.33, 0.06), _flat(Color(0.95, 0.95, 0.92)))
	var hat := _cyl(g, "Hat", 0.085, 0.22, Vector3(0, 0.52, -0.01), _flat(Color(0.84, 0.14, 0.12)))
	(hat.mesh as CylinderMesh).top_radius = 0.0
	hat.rotation.x = -0.12
	var lamp := _box(g, "Lantern", Vector3(0.05, 0.07, 0.05), Vector3(0.12, 0.2, 0.06), _flat(Color(1.0, 0.86, 0.4)))
	lamp.name = "Lantern"
	_use_script(g, "res://scripts/attractions/gnome.gd")
	return {"size": Vector3(0.5, 0.65, 0.5), "target": Vector3(0, 0.4, 0.3)}


## Builder 98's registered copies' gnome: the garden gnome, four and a half times over
## (as tall as a cabin), on its 2x2.
func _mega_gnome(r: Node3D, w: float, d: float) -> Dictionary:
	var info := _gnome(r, w, d)
	var g := r.get_node_or_null("Gnome") as Node3D
	var k := 4.5
	if g != null:
		g.scale = Vector3(k, k, k)
	return {"size": (info["size"] as Vector3) * k, "target": (info["target"] as Vector3) * k}


func _flagpole(r: Node3D, _w: float, _d: float) -> Dictionary:
	var white := _flat(Color(0.92, 0.92, 0.9))
	_box(r, "Base", Vector3(0.6, 0.2, 0.6), Vector3(0, 0.1, 0), _camp_or("concrete.png", Color(0.7, 0.7, 0.68), "stone"))
	for side: float in [-1.0, 1.0]:
		_box(r, "Kerb", Vector3(0.9, 0.08, 0.12), Vector3(0, 0.04, side * 0.45), _flat(Color(0.6, 0.6, 0.58)))
	_cyl(r, "Pole", 0.045, 6.0, Vector3(0, 3.1, 0), white)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.radial_segments = 8
	sm.rings = 4
	ball.mesh = sm
	ball.material_override = _flat(Color(0.86, 0.72, 0.3))
	ball.position = Vector3(0, 6.14, 0)
	r.add_child(ball)
	_box(r, "Rope", Vector3(0.01, 5.6, 0.01), Vector3(0.06, 3.1, 0), _flat(Color(0.8, 0.78, 0.7)))
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0.05, 5.6, 0)
	r.add_child(flag)
	flag.set_meta("material", _flag_material())
	_use_script(flag, "res://scripts/attractions/flag_wave.gd")
	return {"size": Vector3(0.6, 6.2, 0.6), "target": Vector3(0, 1.0, 0.4)}


## The camp's flag: green, a white spruce, the bottom border white (made once).
func _flag_material() -> StandardMaterial3D:
	if _cache.has("flag"):
		return _cache["flag"]
	var img := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.14, 0.42, 0.22))
	for y in 16:
		for x in 24:
			# The spruce: a stacked triangle at the hoist end, a trunk.
			var cx := 8.0
			var tier := float(y - 2) / 11.0
			if y >= 2 and y <= 12 and absf(float(x) - cx) <= tier * 5.0 + 0.3 * float((y - 2) % 4):
				img.set_pixel(x, y, Color(0.95, 0.95, 0.9))
			if y >= 12 and y <= 13 and absf(float(x) - cx) < 1.0:
				img.set_pixel(x, y, Color(0.95, 0.95, 0.9))
			if y >= 14:
				img.set_pixel(x, y, Color(0.95, 0.95, 0.9))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.set_meta("base_albedo_color", m.albedo_color)
	_cache["flag"] = m
	return m


func _playground(r: Node3D, w: float, _d: float) -> Dictionary:
	var red := _flat(Color(0.78, 0.16, 0.12))
	var yellow := _flat(Color(0.94, 0.76, 0.16))
	var sand := _camp_or("gravel_road.png", Color(1.0, 0.9, 0.66), "dirt", Vector3(1.0, 1.0, 1.0))
	_box(r, "SandPatch", Vector3(w * 0.88, 0.04, 3.0), Vector3(0, 0.02, 0), sand)
	# The swing frame on the left half: two A-frames, the bar, two seats on chains.
	var sx := -w * 0.22
	# Each end an A: two legs from the bar down to the ground, spread 1.3 m apart there.
	var spread := 0.65
	var top := 2.2
	var lean := atan2(spread, top)
	var leg_len := sqrt(spread * spread + top * top)
	for x: float in [sx - 1.1, sx + 1.1]:
		for z: float in [-1.0, 1.0]:
			var leg := _box(r, "SwingLeg", Vector3(0.07, leg_len, 0.07), Vector3(x, top * 0.5, z * spread * 0.5), red)
			leg.rotation.x = -z * lean
		_box(r, "SwingFoot", Vector3(0.1, 0.06, spread * 2.0 + 0.1), Vector3(x, 0.03, 0), red)
	_box(r, "SwingBar", Vector3(2.3, 0.07, 0.07), Vector3(sx, 2.2, 0), red)
	var chain := _flat(Color(0.5, 0.5, 0.52))
	for i in 2:
		var pivot := Node3D.new()
		pivot.name = "Swing%d" % i
		pivot.position = Vector3(sx - 0.5 + i * 1.0, 2.18, 0)
		r.add_child(pivot)
		for cx: float in [-0.2, 0.2]:
			_box(pivot, "Chain", Vector3(0.02, 1.7, 0.02), Vector3(cx, -0.85, 0), chain)
		_box(pivot, "Seat", Vector3(0.48, 0.05, 0.2), Vector3(0, -1.72, 0), _camp_or("swing_seat.png", Color(0.16, 0.16, 0.18), "rubber"))
	# The seesaw on the right: the fulcrum and the plank on its pivot.
	var tx := w * 0.22
	_box(r, "Fulcrum", Vector3(0.24, 0.42, 0.3), Vector3(tx, 0.21, 0), red)
	var see := Node3D.new()
	see.name = "Seesaw"
	see.position = Vector3(tx, 0.46, 0)
	r.add_child(see)
	_box(see, "Plank", Vector3(2.6, 0.06, 0.26), Vector3(0, 0, 0), yellow)
	for end: float in [-1.15, 1.15]:
		_box(see, "Handle", Vector3(0.04, 0.24, 0.24), Vector3(end + (0.15 if end < 0 else -0.15), 0.14, 0), red)
	# The sandpit at the back with a bucket and spade.
	var plank := _camp_or("planks_grey.png", Color(0.9, 0.82, 0.7), "wood", Vector3(1.0, 1.0, 1.0))
	var pz := -1.1
	for side: float in [-1.0, 1.0]:
		_box(r, "PitSide", Vector3(1.5, 0.18, 0.08), Vector3(tx, 0.09, pz + side * 0.55), plank)
		_box(r, "PitEnd", Vector3(0.08, 0.18, 1.1), Vector3(tx + side * 0.75, 0.09, pz), plank)
	_box(r, "PitSand", Vector3(1.42, 0.12, 1.02), Vector3(tx, 0.08, pz), _flat(Color(0.86, 0.76, 0.52)))
	_cyl(r, "Bucket", 0.08, 0.14, Vector3(tx + 0.3, 0.2, pz + 0.1), _flat(Color(0.2, 0.42, 0.8)))
	r.set_meta("swing_seat_drop", 1.72)
	_use_script(r, "res://scripts/attractions/playground_play.gd")
	return {"size": Vector3(w * 0.88, 2.3, 3.0), "target": Vector3(0, 0.8, 1.4)}


func _pingpong(r: Node3D, _w: float, _d: float) -> Dictionary:
	var green := _flat(Color(0.12, 0.36, 0.24))
	var line := _flat(Color(0.94, 0.94, 0.9))
	var top_y := 0.76
	_box(r, "TableTop", Vector3(2.74, 0.04, 1.52), Vector3(0, top_y - 0.02, 0), green)
	_box(r, "CentreLine", Vector3(2.7, 0.005, 0.02), Vector3(0, top_y + 0.003, 0), line)
	for z: float in [-0.75, 0.75]:
		_box(r, "EdgeLine", Vector3(2.74, 0.005, 0.02), Vector3(0, top_y + 0.003, z), line)
	for x: float in [-1.36, 1.36]:
		_box(r, "EndLine", Vector3(0.02, 0.005, 1.52), Vector3(x, top_y + 0.003, 0), line)
		for z2: float in [-0.6, 0.6]:
			_box(r, "Leg", Vector3(0.05, top_y - 0.04, 0.05), Vector3(x * 0.85, (top_y - 0.04) * 0.5, z2), _metal())
	_box(r, "NetPostL", Vector3(0.03, 0.17, 0.03), Vector3(0, top_y + 0.08, -0.79), _metal())
	_box(r, "NetPostR", Vector3(0.03, 0.17, 0.03), Vector3(0, top_y + 0.08, 0.79), _metal())
	_cord_net(r, "Net", Vector2(1.58, 0.15), 0.05, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, top_y + 0.08, 0)), _net_material())
	for i in 2:
		var bat := _cyl(r, "Bat%d" % i, 0.08, 0.012, Vector3(-0.9 + i * 1.8, top_y + 0.01, 0.4 - i * 0.8), _flat(Color(0.78, 0.12, 0.1)))
		bat.name = "Bat%d" % i
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.radial_segments = 6
	sm.rings = 3
	ball.mesh = sm
	ball.material_override = _flat(Color(0.98, 0.98, 0.96))
	ball.position = Vector3(0.3, top_y + 0.025, 0.1)
	r.add_child(ball)
	r.set_meta("table_top", top_y)
	_use_script(r, "res://scripts/attractions/pingpong_play.gd")
	return {"size": Vector3(2.8, 0.9, 1.6), "target": Vector3(0, 0.7, 0.9)}


func _hammock(r: Node3D, _w: float, _d: float) -> Dictionary:
	var wood := _camp_or("log_bark.png", Color(0.8, 0.7, 0.6), "wood", Vector3(1.0, 1.0, 1.0))
	for x: float in [-1.4, 1.4]:
		_box(r, "Post", Vector3(0.14, 1.7, 0.14), Vector3(x, 0.85, 0), wood)
	var sway := Node3D.new()
	sway.name = "HammockSway"
	sway.position = Vector3(0, 1.45, 0)
	r.add_child(sway)
	var cloth := _camp_or("blanket_check.png", Color(1.0, 0.66, 0.4), "cloth", Vector3(2.0, 2.0, 2.0))
	var rope := _flat(Color(0.82, 0.76, 0.62))
	# The bed of it: segments down into a sag and up again, on ropes to the posts.
	var segs := 7
	var span := 2.2
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var x0 := -span * 0.5 + span * t0
		var x1 := -span * 0.5 + span * t1
		var y0 := -0.62 * sin(t0 * PI)
		var y1 := -0.62 * sin(t1 * PI)
		var seg := _box(sway, "Cloth%d" % i, Vector3(Vector2(x1 - x0, y1 - y0).length() + 0.02, 0.03, 0.62), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0), cloth)
		seg.rotation.z = atan2(y1 - y0, x1 - x0)
	for side: float in [-1.0, 1.0]:
		var rp := _box(sway, "Rope", Vector3(0.32, 0.02, 0.02), Vector3(side * 1.25, 0.06, 0), rope)
		rp.rotation.z = side * -0.3
	_box(sway, "Pillow", Vector3(0.34, 0.1, 0.4), Vector3(-0.72, -0.44, 0), _flat(Color(0.92, 0.9, 0.84)))
	_box(sway, "Book", Vector3(0.16, 0.03, 0.22), Vector3(0.4, -0.54, 0.1), _flat(Color(0.5, 0.2, 0.14)))
	r.set_meta("seats", [{"pos": Vector3(-0.1, 0.0, 0.0), "face": Vector3(0, 0, 1), "pose": "sit", "lift": 0.62, "sway": "HammockSway"}])
	_use_script(r, "res://scripts/attractions/seats_use.gd")
	return {"size": Vector3(3.0, 1.7, 0.7), "target": Vector3(0, 0.8, 0.5)}


## A behaviour node on a model (the guests' use of it, a flag in the wind, a gnome).
# ── the staffroom (scripts/staff/staffroom_plan.gd): its rooms behind real glass ──

## The hut and its rooms as one (the same plan the room inside is built from), so from
## the camp you see into it; what the camp's side drives (curtains, lamps, the hands on
## the mattresses, the laptop's glow) is kept on the root (meta "staffroom") for
## scripts/staff/staff_runtime.gd. Lamps: the tube in the lounge, the bulb in the boiler
## room, the one over the door (off until the runtime puts them on).
func _staffroom(r: Node3D, _w: float, _d: float) -> Dictionary:
	var plan = load("res://scripts/staff/staffroom_plan.gd")
	var rooms := Node3D.new()
	rooms.name = "StaffRooms"
	r.add_child(rooms)
	var refs: Dictionary = plan.build(rooms, true)
	var lights := {}
	for k in [["lounge", Vector3(-1.2, plan.FLOOR + plan.L_H - 0.3, 0.0), 6.0, Color(0.92, 0.96, 1.0)],
			["boiler", Vector3(2.5, plan.FLOOR + plan.B_H - 0.45, 0.0), 4.0, Color(1.0, 0.82, 0.6)],
			["door", Vector3(plan.DOOR_X, plan.FLOOR + plan.DOOR_H + 0.1, plan.L_MAX.y + plan.WALL + 0.35), 5.0, Color(1.0, 0.86, 0.6)]]:
		var l := OmniLight3D.new()
		l.name = "Lamp_" + str(k[0])
		l.position = k[1]
		l.omni_range = float(k[2])
		l.light_color = k[3]
		l.light_energy = 0.0
		l.shadow_enabled = str(k[0]) != "door"
		rooms.add_child(l)
		lights[k[0]] = l
	refs["lights"] = lights
	r.set_meta("staffroom", refs)
	r.add_to_group("staffroom")
	var sx: float = plan.B_MAX.x + plan.WALL - (plan.L_MIN.x - plan.WALL)
	var sz: float = plan.L_MAX.y - plan.L_MIN.y + 2.0 * plan.WALL
	return {"size": Vector3(sx, plan.FLOOR + plan.L_H + 0.3, sz), "target": Vector3(plan.DOOR_X, 1.2, plan.L_MAX.y + plan.WALL + 0.1)}


func _use_script(r: Node3D, path: String) -> void:
	var n := Node3D.new()
	n.name = "Use"
	n.set_script(load(path))
	r.add_child(n)


# ── kit ───────────────────────────────────────────────────────────────────────

func _box(parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


func _cyl(parent: Node3D, n: String, radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	m.mesh = c
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	parent.add_child(m)
	return m


## A concrete strip under a building, so it sits on the ground and not in it.
func _plinth(r: Node3D, sx: float, sz: float, at := Vector3.ZERO) -> void:
	_box(r, "Plinth", Vector3(sx, 0.2, sz), at + Vector3(0, 0.05, 0), _camp_or("concrete.png", Color(0.54, 0.54, 0.5), "stone"))


## One slope: high at the front (+Z), low at the back, overhanging all round.
func _lean_roof(r: Node3D, sx: float, sz: float, y: float, rise: float, mat: Material, at := Vector3.ZERO) -> void:
	var roof := _box(r, "Roof", Vector3(sx, 0.08, sz), at + Vector3(0, y + rise * 0.5, 0), mat)
	roof.rotation.x = -atan2(rise, sz)
	# Fill the triangle under the slope on both ends.
	for side: float in [-1.0, 1.0]:
		var tri := _prism(Vector3(0.06, rise, sz - 0.3), mat)
		tri.position = at + Vector3(side * (sx * 0.5 - 0.3), y, 0)
		r.add_child(tri)


## A gable roof, ridge along X: two slabs and the end triangles (`end_mat` for those, the
## walls' boards on a cabin; else the roof's).
func _gable_roof(r: Node3D, at: Vector3, sx: float, sz: float, rise: float, mat: Material, end_mat: Material = null) -> void:
	var half := sz * 0.5
	var slope := Vector2(half, rise).length()
	var ang := atan2(rise, half)
	for side: float in [-1.0, 1.0]:
		var slab := _box(r, "RoofSlab", Vector3(sx, 0.08, slope + 0.05), at + Vector3(0, rise * 0.5, side * half * 0.5), mat)
		slab.rotation.x = side * ang
	for side: float in [-1.0, 1.0]:
		var em: Material = end_mat if end_mat != null else mat
		var gable := _gable_triangle(sz - 0.5, rise - 0.05, (em as StandardMaterial3D) if em is StandardMaterial3D else null)
		gable.position = at + Vector3(side * (sx * 0.5 - 0.28), 0, 0)
		r.add_child(gable)


## A right-angled wedge for the space under a lean-to roof (rises toward +Z).
func _prism(size: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var pts := [Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz), Vector3(-hx, size.y, hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(hx, size.y, hz)]
	for tri in [[0, 1, 2], [3, 5, 4], [1, 4, 5], [1, 5, 2], [0, 2, 5], [0, 5, 3]]:
		for k in tri:
			var p: Vector3 = pts[k]
			st.set_uv(Vector2(p.z / size.z + 0.5, 1.0 - p.y / maxf(0.01, size.y)))
			st.add_vertex(p)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	return m


## The triangle at a gable end (in the YZ plane), filled with the wall below it; both
## faces (one side was culled: the cabins showed a hole under the roof from the side,
## playtest 21. 10.).
func _gable_triangle(base: float, rise: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := base * 0.5
	for tri in [[Vector3(0, 0, -hz), Vector3(0, 0, hz), Vector3(0, rise, 0)], [Vector3(0, 0, hz), Vector3(0, 0, -hz), Vector3(0, rise, 0)]]:
		for p: Vector3 in tri:
			st.set_uv(Vector2(p.z / base + 0.5, 1.0 - p.y / rise))
			st.add_vertex(p)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat if mat != null else _flat(Color(0.6, 0.6, 0.58))
	return m


## A yellow warning triangle with its black edge (a flat prism facing +Z).
func _triangle(r: Node3D, pos: Vector3, size: float, color: Color) -> void:
	for layer in [[size, Color(0.08, 0.08, 0.08), 0.0], [size * 0.78, color, 0.005]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var s: float = layer[0]
		for p in [Vector3(-s * 0.5, -s * 0.4, 0), Vector3(s * 0.5, -s * 0.4, 0), Vector3(0, s * 0.5, 0)]:
			st.add_vertex(p)
		st.generate_normals()
		var m := MeshInstance3D.new()
		m.mesh = st.commit()
		var mat := _flat(layer[1] as Color)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		m.position = pos + Vector3(0, 0, float(layer[2]))
		r.add_child(m)


func _window(r: Node3D, pos: Vector3, size: Vector2, yaw := 0.0, frame_mat: Material = null) -> void:
	var frame := _box(r, "WindowFrame", Vector3(size.x + 0.12, size.y + 0.12, 0.05), pos, frame_mat if frame_mat != null else _wood())
	frame.rotation.y = yaw
	var glass_mat := _camp("window_curtain.png", Color(0.8, 0.84, 0.86))
	# The whole picture on the pane, a quad over the frame's face (a box mapped by its
	# metres showed a dark corner of it: inventory 20. 10.); lit at night by
	# scripts/ambient/window_lights.gd while the guests are in.
	var glass := _side_quad(r, "Window", size, pos + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.03), yaw, glass_mat)
	glass.set_meta("lit_window", true)
	var bar := _box(r, "WindowBar", Vector3(0.04, size.y, 0.07), pos, _wood())
	bar.rotation.y = yaw
	# Not seen by the cameras that look out through this window from inside.
	for m in [frame, glass, bar]:
		(m as MeshInstance3D).layers = GLASS_LAYER


## The bathroom of a better cabin, built on at the right where the room has its door
## (scripts/cabin_layout.gd ANNEX): a lower box of the same boards under a lean tin roof,
## a small frosted window, the vent pipe.
func _bathroom_annex(r: Node3D, w: float, _wall_h: float, walls: Material, trim: Material, tin: Material, lv: int) -> void:
	var box: AABB = CL.annex_box(lv)
	var ax := box.size.x
	var az := box.size.z
	var ah := box.size.y
	var cx := box.position.x + ax * 0.5
	var cz := box.position.z + az * 0.5
	_box(r, "BathAnnex", Vector3(ax, ah, az), Vector3(cx, ah * 0.5 + 0.1, cz), walls)
	for z: float in [cz - az * 0.5, cz + az * 0.5]:
		_box(r, "BathCorner", Vector3(0.12, ah, 0.12), Vector3(w * 0.5 + ax, ah * 0.5 + 0.1, z), trim)
	var roof := _box(r, "BathRoof", Vector3(ax + 0.35, 0.06, az + 0.4), Vector3(cx + 0.1, ah + 0.22, cz), tin)
	roof.rotation.z = -0.22
	_window(r, Vector3(w * 0.5 + ax + 0.02, CL.MODEL_FLOOR + 1.62, cz), CL.BATH_WIN, PI * 0.5, trim)
	_cyl(r, "BathPipe", 0.04, ah * 0.9, Vector3(w * 0.5 + ax + 0.06, ah * 0.45 + 0.1, cz + az * 0.38), _metal())


func _label(r: Node3D, text: String, pos: Vector3, height_m: float, color: Color, yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if ResourceLoader.exists(FONT):
		l.font = load(FONT)
	l.font_size = 16
	l.pixel_size = height_m / 16.0
	l.modulate = color
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	r.add_child(l)
	# The board it is painted on stays behind it (retro_materials pulls thin boards forward).
	var behind := pos - Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.05)
	for c in r.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh is BoxMesh:
			var local: Vector3 = mi.transform.affine_inverse() * behind
			var half: Vector3 = (mi.mesh as BoxMesh).size * 0.5 + Vector3(0.02, 0.02, 0.06)
			if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
				mi.set_meta("retro_no_pull", true)
	return l


func _camp(file: String, tint: Color, uv := Vector3.ONE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [file, tint, uv]
	if _cache.has(key):
		return (_cache[key] as StandardMaterial3D).duplicate()
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	# Triplanar in local metres: `uv` repeats per two metres.
	mat.uv1_scale = uv * 0.5
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = false
	if ResourceLoader.exists(CAMP + file):
		mat.albedo_texture = load(CAMP + file)
	mat.albedo_color = tint
	mat.set_meta("base_albedo_color", tint)
	_cache[key] = mat
	return mat.duplicate()


## A camp texture if it has been generated, else the PSX category (redneck set).
# ── the corn stand: a plank booth, a striped awning, the pot steaming ─────────

## Repeats of camp/awning_stripes.png per two metres (its stripes about a sixth of the stand).
const AWNING_UV := 1.2


func _corn_stand(r: Node3D, w: float, _d: float) -> Dictionary:
	var bw := minf(w * 0.8, 2.6)
	var depth := 1.3
	var h := 1.05
	var planks := _camp_or("planks_grey.png", Color(0.95, 0.86, 0.5), "wood", Vector3(1.0, 1.0, 1.0))
	# The counter, its painted front (Grok) to the camp.
	_box(r, "Counter", Vector3(bw, h, depth), Vector3(0, h * 0.5, 0), planks)
	if ResourceLoader.exists(CAMP + "corn_stand.png"):
		_quad(r, "StandFront", Vector2(bw, h + 1.0), Vector3(0, (h + 1.0) * 0.5, depth * 0.5 + 0.012), 0.0, _face_mat("corn_stand.png"))
	_box(r, "CounterTop", Vector3(bw + 0.1, 0.06, depth + 0.1), Vector3(0, h + 0.03, 0), _wood())
	# Four posts and the awning in red and white stripes.
	for x: float in [-bw * 0.5 + 0.05, bw * 0.5 - 0.05]:
		for z: float in [-depth * 0.5 + 0.05, depth * 0.5 - 0.05]:
			_box(r, "Post", Vector3(0.07, 2.3, 0.07), Vector3(x, 1.15, z), _wood())
	# The awning: striped canvas (Grok, camp/awning_stripes.png) and its scalloped fringe
	# along the front, one tongue a flap (camp/awning_fringe.png: a red and a cream one).
	var stripes := 6
	var canvas := _camp_or("awning_stripes.png", Color(0.82, 0.12, 0.1), "fabric", Vector3(AWNING_UV, 1.0, AWNING_UV))
	var awning := _box(r, "Awning", Vector3(bw, 0.04, depth + 0.6), Vector3(0, 2.32, 0.15), canvas)
	awning.rotation.x = 0.2
	var fringe_path := CAMP + "awning_fringe.png"
	for i in stripes:
		var mat: Material = _flat(Color(0.82, 0.12, 0.1) if i % 2 == 0 else Color(0.94, 0.92, 0.86))
		if ResourceLoader.exists(fringe_path):
			var fm := _cut_face(fringe_path)
			fm.uv1_scale = Vector3(0.5, 1.0, 1.0)
			fm.uv1_offset = Vector3(0.5 * (i % 2), 0.0, 0.0)
			mat = fm
		var flap := _quad(r, "AwningFlap%d" % i, Vector2(bw / float(stripes), 0.26), Vector3(-bw * 0.5 + bw / float(stripes) * (i + 0.5), 2.1, depth * 0.5 + 0.46), 0.0, mat)
		flap.name = "AwningFlap%d" % i
	# Behind the counter: the pot on its gas ring, a gas bottle, a crate of cobs.
	_cyl(r, "Pot", 0.28, 0.42, Vector3(-bw * 0.22, h + 0.27, -0.25), _metal())
	_cyl(r, "Ring", 0.2, 0.06, Vector3(-bw * 0.22, h + 0.06, -0.25), _camp_or("steel_kitchen.png", Color(0.32, 0.32, 0.34), "metal"))
	# The gas bottle: its render on two crossed cards.
	if ResourceLoader.exists(CAMP + "gas_bottle.png"):
		for yaw in [0.0, PI * 0.5]:
			_quad(r, "Gas", Vector2(0.34, 0.62), Vector3(bw * 0.5 - 0.25, 0.31, -depth * 0.5 - 0.15), yaw, _cut_face(CAMP + "gas_bottle.png"))
	if ResourceLoader.exists("res://assets/textury/town/corn_crate.png"):
		var crate := _quad(r, "CornCrate", Vector2(0.62, 0.48), Vector3(bw * 0.25, h + 0.25, -0.35), 0.0, _cut_face("res://assets/textury/town/corn_crate.png"))
		crate.name = "CornCrate"
	r.set_meta("steam_at", Vector3(-bw * 0.22, h + 0.55, -0.25))
	_use_script(r, "res://scripts/business/corn_stand_life.gd")
	return {"size": Vector3(bw, 2.4, depth), "target": Vector3(0, 1.0, depth * 0.5 + 0.2)}


# ── the Jednota (agent C, 20. 10.; iso_jednota): a 1970s village self-service grocery ───
#    A long single-storey block under a flat concrete roof, its faces Grok pictures
#    (camp/jednota_front: the band of shop windows, the glass door, the red board;
#    jednota_side, jednota_back), the sheet-metal letters JEDNOTA on the board (the same as
#    Lesna's: town/sign_jednota.png), a flat canopy over the door; out front the crates of
#    empties, the ice-cream freezer, a bench. Inside it is scripts/jednota/jednota_layout.gd.

func _jednota(r: Node3D, _w: float, _d: float) -> Dictionary:
	var sx := 7.2
	var sz := 6.0
	var h := 3.4
	var front := sz * 0.5
	var plaster: Material = _camp_or("plaster_stone.png", Color(0.9, 0.86, 0.78), "wall", Vector3(2.0, 1.2, 1.0))
	_plinth(r, sx + 0.3, sz + 0.3)
	_box(r, "Shop", Vector3(sx, h, sz), Vector3(0, h * 0.5 + 0.1, 0), plaster)
	_box(r, "Roof", Vector3(sx + 0.5, 0.25, sz + 0.5), Vector3(0, h + 0.22, 0), _camp_or("concrete.png", Color(0.62, 0.6, 0.58), "roof"))
	if ResourceLoader.exists(CAMP + "jednota_front.png"):
		_quad(r, "JednotaFront", Vector2(sx, h), Vector3(0, h * 0.5 + 0.1, front + 0.012), 0.0, _face_mat("jednota_front.png"))
	if ResourceLoader.exists(CAMP + "jednota_side.png"):
		_quad(r, "JednotaSideL", Vector2(sz, h), Vector3(-sx * 0.5 - 0.012, h * 0.5 + 0.1, 0), -PI * 0.5, _face_mat("jednota_side.png"))
		_quad(r, "JednotaSideR", Vector2(sz, h), Vector3(sx * 0.5 + 0.012, h * 0.5 + 0.1, 0), PI * 0.5, _face_mat("jednota_side.png"))
	if ResourceLoader.exists(CAMP + "jednota_back.png"):
		_quad(r, "JednotaBack", Vector2(sx, h), Vector3(0, h * 0.5 + 0.1, -front - 0.012), PI, _face_mat("jednota_back.png"))
	# The letters on the red board along the top of the front.
	var letters := "res://assets/textury/town/sign_jednota.png"
	if ResourceLoader.exists(letters):
		var lm := _cut_face(letters)
		_quad(r, "SignJEDNOTA", Vector2(1.6, 0.47), Vector3(0, h - 0.22, front + 0.03), 0.0, lm)
	# The canopy over the door, on two thin posts.
	_box(r, "Canopy", Vector3(2.0, 0.1, 1.1), Vector3(0, 2.62, front + 0.55), _camp_or("concrete.png", Color(0.7, 0.68, 0.64), "roof"))
	for x: float in [-0.92, 0.92]:
		_box(r, "CanopyPost", Vector3(0.07, 2.55, 0.07), Vector3(x, 1.33, front + 1.05), _metal())
	_box(r, "Step", Vector3(2.2, 0.14, 0.8), Vector3(0, 0.07, front + 0.4), _psx_mat(Color(0.6, 0.6, 0.58), "stone"))
	# Out front: the crates of empties by the wall, the freezer, the bench.
	var crate := "res://assets/textury/camp/beer_crate_full.png"
	if ResourceLoader.exists(crate):
		for i in 5:
			var at := Vector3(-2.6 + float(i % 3) * 0.58, 0.05 + float(i / 3) * 0.4, front + 0.35)
			_quad(r, "Empties", Vector2(0.55, 0.42), at + Vector3(0, 0.21, 0), 0.0, _cut_face(crate))
	var freezer := CAMP + "shop_freezer.png"
	if ResourceLoader.exists(freezer):
		_box(r, "Freezer", Vector3(1.1, 0.85, 0.62), Vector3(2.2, 0.48, front + 0.5), _flat(Color(0.72, 0.1, 0.08)))
		_quad(r, "FreezerFace", Vector2(1.1, 0.84), Vector3(2.2, 0.48, front + 0.815), 0.0, _cut_face(freezer))
	_box(r, "BenchSeat", Vector3(1.4, 0.06, 0.36), Vector3(-1.4, 0.48, front + 1.5), _wood())
	for x: float in [-1.95, -0.85]:
		_box(r, "BenchLeg", Vector3(0.06, 0.45, 0.32), Vector3(x, 0.24, front + 1.5), _wood())
	return {"size": Vector3(sx + 0.6, h + 0.5, sz + 0.6), "target": Vector3(0.0, 1.2, front + 0.3)}

# ── the bowling alley (the user 21. 10.): a 1970s concrete box the camp has tried to
#    brand as its bowling alley. Grok's painted walls (bowling_front, _side_a/_b, _back:
#    the stripes, the mural, the plywood pin, the string of coloured bulbs, which light up
#    at night from bowling_front_glow.png), BOWLING painted on the board over the door,
#    KUŽELKY in red neon tubes on a steel frame on the roof (lettering.py "kuzelky"), and a
#    three-metre fibreglass pin up there with it; scripts/bowling/bowling_sign.gd lights
#    the neon and the bulbs with the camp's lamps.

const PIN_MESH = preload("res://scripts/bowling/pin_mesh.gd")
const BOWLING_SIGN = preload("res://scripts/bowling/bowling_sign.gd")
const TOWN := "res://assets/textury/town/"
## Where things are on bowling_front.png (shares of the front's width from its middle, of
## its height from the ground): the door, and the empty board over it.
const BOWLING_DOOR_X := -0.271
const BOWLING_BOARD := Vector2(-0.263, 0.738)


func _bowling(r: Node3D, _w: float, _d: float) -> Dictionary:
	var sx := 10.4
	var sz := 17.6
	var h := 5.2
	var front := sz * 0.5
	var y0 := 0.1
	var concrete: Material = _camp_or("concrete.png", Color(0.6, 0.59, 0.57), "wall", Vector3(4.0, 1.6, 1.0))
	_plinth(r, sx + 0.3, sz + 0.3)
	_box(r, "Hall", Vector3(sx, h, sz), Vector3(0, h * 0.5 + y0, 0), concrete)
	# The heavy slab of the roof, out over the walls all round.
	var roof_top := y0 + h + 0.4
	_box(r, "Roof", Vector3(sx + 0.7, 0.4, sz + 0.7), Vector3(0, roof_top - 0.2, 0), _camp_or("concrete.png", Color(0.42, 0.41, 0.4), "roof", Vector3(4.0, 1.0, 6.0)))
	var bulbs: Array = []
	if ResourceLoader.exists(CAMP + "bowling_front.png"):
		var fm := _face_mat("bowling_front.png")
		if ResourceLoader.exists(CAMP + "bowling_front_glow.png"):
			# The glow map alone lights (emission added to a black colour, as the town's signs).
			fm.emission_enabled = true
			fm.emission = Color(0, 0, 0)
			fm.emission_texture = load(CAMP + "bowling_front_glow.png")
			fm.emission_energy_multiplier = 0.0
			bulbs.append(fm)
		_quad(r, "BowlingFront", Vector2(sx, h), Vector3(0, h * 0.5 + y0, front + 0.012), 0.0, fm)
	# Each long wall in two pictures: the mural by the front, the plain rear with the
	# cellar's window, where the camp's painted stripe runs out. The left wall has them
	# mirrored, so on both the stripe comes from the front and stops half way.
	for side: float in [-1.0, 1.0]:
		for part in [["bowling_side_a.png", sz * 0.25], ["bowling_side_b.png", -sz * 0.25]]:
			if ResourceLoader.exists(CAMP + str(part[0])):
				var sm := _face_mat(str(part[0]))
				if side < 0.0:
					sm.uv1_scale = Vector3(-1.0, 1.0, 1.0)
				_quad(r, "BowlingSide", Vector2(sz * 0.5, h), Vector3(side * (sx * 0.5 + 0.012), h * 0.5 + y0, float(part[1])), side * PI * 0.5, sm)
	if ResourceLoader.exists(CAMP + "bowling_back.png"):
		_quad(r, "BowlingBack", Vector2(sx, h), Vector3(0, h * 0.5 + y0, -front - 0.012), PI, _face_mat("bowling_back.png"))
	var door_x := sx * BOWLING_DOOR_X
	# BOWLING painted on the board over the door, and the step up to it.
	var board := TOWN + "sign_bowling.png"
	if ResourceLoader.exists(board):
		var bt: Texture2D = load(board)
		var bw := 1.6
		_quad(r, "SignBOWLING", Vector2(bw, bw * float(bt.get_height()) / float(bt.get_width())),
			Vector3(sx * BOWLING_BOARD.x, y0 + h * BOWLING_BOARD.y, front + 0.03), 0.0, _cut_face(board))
	_box(r, "Step", Vector3(1.8, 0.14, 0.7), Vector3(door_x, 0.07, front + 0.35), _psx_mat(Color(0.58, 0.57, 0.55), "stone"))
	# KUŽELKY in red neon tubes on a steel frame along the roof's front edge.
	var neon: StandardMaterial3D = null
	var letters := TOWN + "sign_kuzelky.png"
	var nsz := Vector2(4.6, 1.8)
	if ResourceLoader.exists(letters):
		var lt: Texture2D = load(letters)
		nsz = Vector2(4.6, 4.6 * float(lt.get_height()) / float(lt.get_width()))
		neon = _cut_face(letters)
		neon.cull_mode = BaseMaterial3D.CULL_BACK
		var glow := TOWN + "sign_kuzelky_glow.png"
		if ResourceLoader.exists(glow):
			neon.emission_enabled = true
			neon.emission = Color(0, 0, 0)
			neon.emission_texture = load(glow)
			neon.emission_energy_multiplier = 0.0
		_quad(r, "NeonKUZELKY", nsz, Vector3(1.2, roof_top + 0.25 + nsz.y * 0.5, front - 0.1), 0.0, neon)
	for x: float in [-1.6, 0.0, 1.6]:
		_box(r, "NeonPost", Vector3(0.06, nsz.y + 0.3, 0.06), Vector3(1.2 + x, roof_top + (nsz.y + 0.3) * 0.5, front - 0.22), _metal())
	_box(r, "NeonRail", Vector3(nsz.x - 0.2, 0.06, 0.06), Vector3(1.2, roof_top + 0.22, front - 0.2), _metal())
	var light := OmniLight3D.new()
	light.name = "NeonLight"
	light.light_color = Color(1.0, 0.24, 0.3)
	light.omni_range = 9.0
	light.light_energy = 0.0
	light.visible = false
	light.position = Vector3(1.2, roof_top + 0.4, front + 1.6)
	r.add_child(light)
	# The fibreglass pin on the roof, a little out of true, on its steel stays.
	var pin := MeshInstance3D.new()
	pin.name = "RoofPin"
	pin.mesh = PIN_MESH.mesh(3.0, 12)
	pin.material_override = PIN_MESH.material()
	var px := -sx * 0.5 + 1.4
	pin.position = Vector3(px, roof_top, front - 1.4)
	pin.rotation = Vector3(0.0, 0.4, 0.05)
	r.add_child(pin)
	for x: float in [-0.5, 0.5]:
		_box(r, "PinStay", Vector3(0.06, 1.7, 0.06), Vector3(px + x, roof_top + 0.85, front - 2.05), _metal())
	_box(r, "PinStayBar", Vector3(1.1, 0.06, 0.06), Vector3(px, roof_top + 1.6, front - 2.05), _metal())
	# By the door: a bench and a bin.
	_box(r, "BenchSeat", Vector3(1.4, 0.06, 0.36), Vector3(door_x + 2.6, 0.48, front + 0.9), _wood())
	for x: float in [-0.55, 0.55]:
		_box(r, "BenchLeg", Vector3(0.06, 0.45, 0.32), Vector3(door_x + 2.6 + x, 0.24, front + 0.9), _wood())
	_box(r, "Bin", Vector3(0.4, 0.7, 0.4), Vector3(door_x + 1.3, 0.36, front + 0.5), _psx_mat(Color(0.25, 0.32, 0.26), "metal"))
	# The neon, the bulbs and the hum come and go with the camp's lamps.
	var sign := Node3D.new()
	sign.name = "BowlingSign"
	sign.set_script(BOWLING_SIGN)
	sign.position = Vector3(1.2, roof_top + 0.6, front)
	r.add_child(sign)
	sign.call("setup", neon, bulbs, light)
	return {"size": Vector3(sx + 0.7, h + 0.6, sz + 0.7), "target": Vector3(door_x, 1.2, front + 0.3)}


## A Grok sprite on a quad, its background keyed out.
func _cut_face(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


## A whole wall's face (a Grok picture, not tiled), lit like the walls.
func _face_mat(file: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(CAMP + file)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


## A town texture (assets/textury/town) tiled like the camp's, or a camp one instead.
func _town_or(file: String, tint: Color, fallback: String, uv := Vector3.ONE) -> Material:
	var path := "res://assets/textury/town/" + file
	if not ResourceLoader.exists(path):
		return _camp_or(fallback, tint, "wall", uv)
	var mat := _camp(fallback, tint, uv)
	mat.albedo_texture = load(path)
	return mat


func _camp_or(file: String, tint: Color, category: String, uv := Vector3.ONE) -> Material:
	if ResourceLoader.exists(CAMP + file):
		return _camp(file, tint, uv)
	return _psx_mat(tint, category)


func _psx_mat(color: Color, category: String) -> Material:
	if _psx.is_valid():
		var m = _psx.call(color, 0.008, 24.0, 6.0, 0.05, category)
		if m is StandardMaterial3D and not (m as StandardMaterial3D).has_meta("base_albedo_color"):
			(m as StandardMaterial3D).set_meta("base_albedo_color", (m as StandardMaterial3D).albedo_color)
		return m
	return _flat(color)


func _flat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.set_meta("base_albedo_color", c)
	return mat


func _wood() -> Material:
	return _camp("planks_grey.png", Color(0.82, 0.66, 0.5), Vector3(1.0, 1.0, 1.0))


func _metal() -> Material:
	return _psx_mat(Color(0.6, 0.62, 0.64), "metal")


# ── the reception (playtest 2026-10-17: "make it look like a real camp reception, the
#    windows must match the interior"): a plank cabin built from the rooms' own plan ─

## The render layer of window glass: seen by the player, not by the window views
## (the cameras behind the glass, building_interior.gd), which look through it.
const GLASS_LAYER := 1 << 19

## `r`: origin on the ground at the footprint's middle, front +Z. Returns the glass
## panes so the office can light them at night and show the curtains:
## {office_glass, back_glass}.
func reception(r: Node3D) -> Dictionary:
	var L = load("res://scripts/reception/reception_layout.gd")
	var b: Rect2 = L.local_bounds()
	var x0 := b.position.x
	var x1 := b.end.x
	var z0 := b.position.y
	var z1 := b.end.y
	var h: float = L.WALL_H
	var t := 0.12
	var planks := _camp("planks_red.png", Color(0.98, 0.9, 0.82), Vector3(1.6, 1.6, 1.0))
	var trim := _camp("planks_grey.png", Color(0.95, 0.94, 0.9), Vector3(1.0, 1.0, 1.0))
	_plinth(r, b.size.x + 0.3, b.size.y + 0.3, Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5))

	# The openings, in local space.
	var door_a: Vector3 = L.local(Vector3(L.DOOR_X.y, 0, -2.55))
	var door_b: Vector3 = L.local(Vector3(L.DOOR_X.x, 0, -2.55))
	var dx0 := minf(door_a.x, door_b.x)
	var dx1 := maxf(door_a.x, door_b.x)
	var wc: Vector3 = L.local(L.OFFICE_WINDOW_CENTER)
	var ws: Vector2 = L.OFFICE_WINDOW_SIZE
	var wx0 := wc.x - ws.x * 0.5 - 0.07
	var wx1 := wc.x + ws.x * 0.5 + 0.07
	var wy0 := wc.y - ws.y * 0.5 - 0.07
	var wy1 := wc.y + ws.y * 0.5 + 0.07
	var bc: Vector3 = L.local(L.BACK_WINDOW_CENTER)
	var bs: Vector2 = L.BACK_WINDOW_SIZE
	var bz0 := bc.z - bs.x * 0.5
	var bz1 := bc.z + bs.x * 0.5
	var by0 := bc.y - bs.y * 0.5
	var by1 := bc.y + bs.y * 0.5

	# Front wall (z1), around the door and the office window.
	var fz := z1 + t * 0.5
	_wall_x(r, "FrontA", x0, dx0, 0.0, h, fz, t, planks)
	_wall_x(r, "FrontDoorTop", dx0, dx1, L.DOOR_H, h, fz, t, planks)
	_wall_x(r, "FrontB", dx1, wx0, 0.0, h, fz, t, planks)
	_wall_x(r, "FrontUnder", wx0, wx1, 0.0, wy0, fz, t, planks)
	_wall_x(r, "FrontOver", wx0, wx1, wy1, h, fz, t, planks)
	_wall_x(r, "FrontC", wx1, x1, 0.0, h, fz, t, planks)
	# Back wall, west wall: whole.
	_wall_x(r, "Back", x0 - t, x1 + t, 0.0, h, z0 - t * 0.5, t, planks)
	_wall_z(r, "West", z0, z1, 0.0, h, x0 - t * 0.5, t, planks)
	# East wall (the gate lane side), around the back room's window.
	var ex := x1 + t * 0.5
	_wall_z(r, "EastA", z0, bz0, 0.0, h, ex, t, planks)
	_wall_z(r, "EastUnder", bz0, bz1, 0.0, by0, ex, t, planks)
	_wall_z(r, "EastOver", bz0, bz1, by1, h, ex, t, planks)
	_wall_z(r, "EastB", bz1, z1 + t, 0.0, h, ex, t, planks)
	# Corner posts.
	for cx: float in [x0 - t, x1 + t]:
		for cz: float in [z0 - t, z1 + t]:
			_box(r, "Corner", Vector3(0.16, h, 0.16), Vector3(cx, h * 0.5, cz), _wood())

	# The roof: corrugated tin over the lot, the ridge along the front.
	var tin := _camp("corrugated_roof.png", Color(0.74, 0.7, 0.66), Vector3(1.6, 1.6, 1.0))
	_gable_roof(r, Vector3((x0 + x1) * 0.5, h, (z0 + z1) * 0.5), b.size.x + 0.7, b.size.y + 0.9, L.ROOF_RISE, tin)
	# The stove's pipe out through the roof over the office's back corner, where the
	# stove stands inside (scripts/reception/office_dressing.gd).
	var stove: Vector3 = L.local(Vector3(2.12, 0.0, 2.16))
	var ridge_z := (z0 + z1) * 0.5
	var roof_half := (b.size.y + 0.9) * 0.5
	var roof_y: float = h + L.ROOF_RISE * (1.0 - absf(stove.z - ridge_z) / roof_half)
	_cyl(r, "StovePipe", 0.08, 1.2, Vector3(stove.x, roof_y + 0.4, stove.z), _metal())
	_cyl(r, "StoveCap", 0.15, 0.06, Vector3(stove.x, roof_y + 1.02, stove.z), _metal())

	# The door: planks in a frame, a step and a porch with a lean-to over it.
	var dcx := (dx0 + dx1) * 0.5
	var leaf := _box(r, "DoorLeaf", Vector3(dx1 - dx0 - 0.08, L.DOOR_H - 0.04, 0.05), Vector3(dcx, L.DOOR_H * 0.5, z1 + t + 0.03), _camp("door_wood.png", Color(0.78, 0.66, 0.52)))
	# Like the glass: the office's own door stands in it, and the doorway's view out
	# (building_interior._setup_door_view) must not see this one shut across it.
	leaf.layers = GLASS_LAYER
	_frame(r, "DoorFrame", dx0, dx1, 0.0, L.DOOR_H, z1 + t + 0.02, trim, false)
	var porch_x0 := x0 - 0.1
	var porch_x1 := wx0 - 0.25
	var pcx := (porch_x0 + porch_x1) * 0.5
	var pw := porch_x1 - porch_x0
	_box(r, "PorchDeck", Vector3(pw, 0.12, 1.3), Vector3(pcx, 0.2, z1 + t + 0.65), _wood())
	_box(r, "PorchStep", Vector3(1.2, 0.1, 0.4), Vector3(dcx, 0.07, z1 + t + 1.5), _wood())
	for px: float in [porch_x0 + 0.08, porch_x1 - 0.08]:
		_box(r, "PorchPost", Vector3(0.12, 2.4, 0.12), Vector3(px, 1.4, z1 + t + 1.22), _wood())
	var awn := _box(r, "PorchRoof", Vector3(pw + 0.3, 0.07, 1.6), Vector3(pcx, 2.66, z1 + t + 0.7), tin)
	awn.rotation.x = 0.2
	_box(r, "PorchRail", Vector3(0.08, 0.08, 1.2), Vector3(porch_x0 + 0.08, 0.95, z1 + t + 0.62), _wood())
	# The sign over the door: RECEPCE, white on a dark board.
	_box(r, "SignBoard", Vector3(1.9, 0.38, 0.05), Vector3(dcx + 0.25, L.DOOR_H + 0.42, z1 + t + 0.04), _flat(Color(0.12, 0.2, 0.14)))
	_label(r, "RECEPCE", Vector3(dcx + 0.25, L.DOOR_H + 0.42, z1 + t + 0.075), 0.24, Color(0.95, 0.93, 0.84))
	_box(r, "DoorLamp", Vector3(0.16, 0.2, 0.12), Vector3(dx1 + 0.18, L.DOOR_H + 0.05, z1 + t + 0.08), _flat(Color(0.85, 0.82, 0.62)))

	# The office window: the white frame, the cross, a sill, the glass.
	_frame(r, "OfficeWindowFrame", wx0, wx1, wy0, wy1, z1 + t + 0.02, trim, true)
	_box(r, "OfficeMullionV", Vector3(0.06, ws.y, 0.05), Vector3(wc.x, wc.y, z1 + t * 0.5), trim)
	_box(r, "OfficeMullionH", Vector3(ws.x, 0.06, 0.05), Vector3(wc.x, wc.y, z1 + t * 0.5), trim)
	_box(r, "OfficeSill", Vector3(wx1 - wx0 + 0.1, 0.06, 0.22), Vector3(wc.x, wy0 - 0.02, z1 + t + 0.1), trim)
	var og := _glass(r, "OfficeGlass", Vector3(ws.x, ws.y, 0.02), Vector3(wc.x, wc.y, z1 + 0.04), "recep_office_night.png")
	# The back room's window, east: small, a frame, the glass.
	_frame_z(r, "BackWindowFrame", bz0 - 0.07, bz1 + 0.07, by0 - 0.07, by1 + 0.07, x1 + t + 0.02, trim)
	_box(r, "BackMullion", Vector3(0.05, bs.y, 0.06), Vector3(x1 + t * 0.5, bc.y, bc.z), trim)
	_box(r, "BackSill", Vector3(0.2, 0.06, bs.x + 0.24), Vector3(x1 + t + 0.08, by0 - 0.09, bc.z), trim)
	var bg := _glass(r, "BackGlass", Vector3(0.02, bs.y, bs.x), Vector3(x1 + 0.04, bc.y, bc.z), "recep_back_night.png")

	_reception_store(r, L, z0 - t, tin)
	# Firewood against the west wall.
	for i in 4:
		_cyl(r, "Firewood%d" % i, 0.11, 1.1, Vector3(x0 - t - 0.25, 0.18 + i * 0.2, z0 + 1.0 + (i % 2) * 0.12), _psx_mat(Color(0.52, 0.38, 0.24), "tree_bark"), Vector3(PI * 0.5, 0, 0))
	return {"office_glass": og, "back_glass": bg}


## The lean-to store on the back of the reception (ReceptionLayout.STORE_*): grey boards
## under a tin roof falling away from the building, the glass blocks in its back wall.
## Its only door is the one inside, behind the counter. `back` = the building's back face.
func _reception_store(r: Node3D, L, back: float, tin: Material) -> void:
	var a: Vector3 = L.local(Vector3(L.STORE_X.x, 0.0, L.STORE_Z.y))
	var b: Vector3 = L.local(Vector3(L.STORE_X.y, 0.0, L.STORE_Z.y))
	var sx0 := minf(a.x, b.x)
	var sx1 := maxf(a.x, b.x)
	var far: float = a.z
	var depth := back - far
	var hi: float = L.STORE_ROOF.x
	var lo: float = L.STORE_ROOF.y
	var t := 0.1
	var boards := _camp("planks_grey.png", Color(0.9, 0.86, 0.8), Vector3(1.6, 1.6, 1.0))
	_plinth(r, sx1 - sx0 + 0.2, depth + 0.1, Vector3((sx0 + sx1) * 0.5, 0, (back + far) * 0.5))
	# The side walls up to the low eave, a wedge on each up to the roof line.
	for sx: float in [sx0 + t * 0.5, sx1 - t * 0.5]:
		_box(r, "StoreSide", Vector3(t, lo, depth), Vector3(sx, lo * 0.5, (back + far) * 0.5), boards)
		var wedge := _prism(Vector3(t, hi - lo, depth), boards)
		wedge.name = "StoreGable"
		wedge.position = Vector3(sx, lo, (back + far) * 0.5)
		r.add_child(wedge)
	# The back wall round the glass blocks.
	var gb: Rect2 = L.STORE_BLOCKS
	var g0: Vector3 = L.local(Vector3(gb.position.x, 0.0, L.STORE_Z.y))
	var g1: Vector3 = L.local(Vector3(gb.end.x, 0.0, L.STORE_Z.y))
	var gx0 := minf(g0.x, g1.x)
	var gx1 := maxf(g0.x, g1.x)
	var bz := far + t * 0.5
	_wall_x(r, "StoreBackA", sx0, gx0, 0.0, lo, bz, t, boards)
	_wall_x(r, "StoreBackB", gx1, sx1, 0.0, lo, bz, t, boards)
	_wall_x(r, "StoreBackUnder", gx0, gx1, 0.0, gb.position.y, bz, t, boards)
	_wall_x(r, "StoreBackOver", gx0, gx1, gb.end.y, lo, bz, t, boards)
	var blocks := _camp("glass_blocks.png", Color(0.86, 0.9, 0.92), Vector3(4.0, 1.0, 1.0))
	_box(r, "StoreGlassBlocks", Vector3(gx1 - gx0, gb.size.y, 0.06), Vector3((gx0 + gx1) * 0.5, gb.get_center().y, bz), blocks)
	_frame(r, "StoreBlocksFrame", gx0, gx1, gb.position.y, gb.end.y, far - 0.01, _camp("planks_grey.png", Color(0.95, 0.94, 0.9), Vector3(1.0, 1.0, 1.0)), true)
	# The roof: one slope of tin from under the building's eave down past the back wall.
	var run := depth + 0.3
	var drop := hi - lo
	var slope := atan2(drop, depth)
	var roof := _box(r, "StoreRoof", Vector3(sx1 - sx0 + 0.3, 0.06, Vector2(run, drop * run / depth).length()), Vector3((sx0 + sx1) * 0.5, (hi + lo) * 0.5 + 0.04, (back + far) * 0.5 - 0.15), tin)
	roof.rotation.x = -slope
	# A gutter along the low edge, its downpipe at the corner.
	_box(r, "StoreGutter", Vector3(sx1 - sx0 + 0.3, 0.07, 0.09), Vector3((sx0 + sx1) * 0.5, lo - 0.03, far - 0.33), _metal())
	_box(r, "StoreDownpipe", Vector3(0.07, lo - 0.05, 0.07), Vector3(sx1 + 0.08, (lo - 0.05) * 0.5, far - 0.33), _metal())


## A wall slab along X (front, back) from x a to b, y lo to hi, at depth z.
func _wall_x(r: Node3D, n: String, a: float, b: float, lo: float, hi: float, z: float, t: float, mat: Material) -> void:
	if b - a < 0.01 or hi - lo < 0.01:
		return
	_box(r, n, Vector3(b - a, hi - lo, t), Vector3((a + b) * 0.5, (lo + hi) * 0.5, z), mat)


## A wall slab along Z (the ends) from z a to b, y lo to hi, at x.
func _wall_z(r: Node3D, n: String, a: float, b: float, lo: float, hi: float, x: float, t: float, mat: Material) -> void:
	if b - a < 0.01 or hi - lo < 0.01:
		return
	_box(r, n, Vector3(t, hi - lo, b - a), Vector3(x, (lo + hi) * 0.5, (a + b) * 0.5), mat)


## Four boards round an opening in a front wall (no bottom board for a door).
func _frame(r: Node3D, n: String, a: float, b: float, lo: float, hi: float, z: float, mat: Material, bottom: bool) -> void:
	var w := 0.1
	_box(r, n + "L", Vector3(w, hi - lo + w, 0.05), Vector3(a - w * 0.5 + 0.02, (lo + hi) * 0.5, z), mat)
	_box(r, n + "R", Vector3(w, hi - lo + w, 0.05), Vector3(b + w * 0.5 - 0.02, (lo + hi) * 0.5, z), mat)
	_box(r, n + "T", Vector3(b - a + w * 2.0, w, 0.05), Vector3((a + b) * 0.5, hi + w * 0.5 - 0.02, z), mat)
	if bottom:
		_box(r, n + "B", Vector3(b - a + w * 2.0, w, 0.05), Vector3((a + b) * 0.5, lo - w * 0.5 + 0.02, z), mat)


## The same round an opening in an end wall (facing +X).
func _frame_z(r: Node3D, n: String, a: float, b: float, lo: float, hi: float, x: float, mat: Material) -> void:
	var w := 0.1
	_box(r, n + "L", Vector3(0.05, hi - lo + w, w), Vector3(x, (lo + hi) * 0.5, a - w * 0.5 + 0.02), mat)
	_box(r, n + "R", Vector3(0.05, hi - lo + w, w), Vector3(x, (lo + hi) * 0.5, b + w * 0.5 - 0.02), mat)
	_box(r, n + "T", Vector3(0.05, w, b - a + w * 2.0), Vector3(x, hi + w * 0.5 - 0.02, (a + b) * 0.5), mat)
	_box(r, n + "B", Vector3(0.05, w, b - a + w * 2.0), Vector3(x, lo - w * 0.5 + 0.02, (a + b) * 0.5), mat)


## Glass: dark and a little glossy by day; the office lights it at night
## (building_interior.gd: set_reception_glass): the room behind it, `night` (Grok: the
## office, the back room, seen through the glass with the lamps on; it was a flat lit
## pane, inventory 20. 10.), glows in the lamps' colour. On GLASS_LAYER.
func _glass(r: Node3D, n: String, size: Vector3, pos: Vector3, night := "") -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.2, 0.24)
	m.roughness = 0.12
	m.metallic = 0.3
	m.metallic_specular = 0.8
	m.emission_enabled = true
	m.emission = Color(1.0, 0.78, 0.46)
	m.emission_energy_multiplier = 0.0
	if night != "" and ResourceLoader.exists(CAMP + night):
		m.emission_texture = load(CAMP + night)
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission = Color(1.0, 0.9, 0.76)
		# A box's face is a third by a half of the picture: the whole of it on each.
		m.uv1_scale = Vector3(3.0, 2.0, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var g := _box(r, n, size, pos, m)
	g.layers = GLASS_LAYER
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g
