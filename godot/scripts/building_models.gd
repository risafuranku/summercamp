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
const FONT := "res://assets/fonts/w95b.fnt"
const MODELS := ["toilet_block", "shower_block", "pub", "restaurant", "power_generator", "sewer",
	"bonfire", "sports_field", "lake_slide", "dumpsters"]

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
		_label(r, "M" if i == 0 else "Z", Vector3(x, 1.32, sz * 0.5 + 0.08), 0.2, Color(0.12, 0.1, 0.08))
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


# ── showers (sprchy.PNG): an open row of cubicles under tin, a tank on the roof ─

func _showers(r: Node3D, _w: float, _d: float) -> Dictionary:
	var sx := 3.4
	var sz := 2.2
	var h := 2.35
	_plinth(r, sx + 0.3, sz + 0.5)
	# Duckboard deck in front.
	_box(r, "Deck", Vector3(sx, 0.08, 0.7), Vector3(0, 0.14, sz * 0.5 + 0.3), _wood())
	var tiles := _camp("tiles_bathroom.png", Color(0.95, 0.95, 0.92), Vector3(3.0, 2.0, 1.0))
	var planks := _camp("planks_grey.png", Color(0.82, 0.86, 0.8), Vector3(2.0, 1.0, 1.0))
	_box(r, "Back", Vector3(sx, h, 0.12), Vector3(0, h * 0.5 + 0.1, -sz * 0.5), tiles)
	_box(r, "SideL", Vector3(0.12, h, sz), Vector3(-sx * 0.5, h * 0.5 + 0.1, 0), _camp("planks_grey.png", Color(0.52, 0.66, 0.46), Vector3(1.0, 1.0, 1.0)))
	_box(r, "SideR", Vector3(0.12, h, sz), Vector3(sx * 0.5, h * 0.5 + 0.1, 0), planks)
	_box(r, "Floor", Vector3(sx, 0.06, sz), Vector3(0, 0.13, 0), _camp("tiles_bathroom.png", Color(0.7, 0.72, 0.72), Vector3(3.0, 2.0, 1.0)))
	# Three cubicles: white partitions, the doors half open.
	var panel := _flat(Color(0.86, 0.86, 0.82))
	for i in 4:
		var x := -sx * 0.5 + 0.06 + float(i) * (sx - 0.12) / 3.0
		if i > 0 and i < 3:
			_box(r, "Partition%d" % i, Vector3(0.05, 1.9, sz - 0.2), Vector3(x, 1.1, 0.0), panel)
	for i in 3:
		var cx := -sx * 0.5 + (sx / 3.0) * (float(i) + 0.5)
		var dr := _box(r, "CubicleDoor%d" % i, Vector3(0.8, 1.7, 0.04), Vector3(0, 0, 0), panel)
		dr.position = Vector3(cx - 0.4 + cos(0.6 + i * 0.3) * 0.4, 1.0, sz * 0.5 - 0.05 + sin(0.6 + i * 0.3) * 0.4)
		dr.rotation.y = -(0.6 + i * 0.3)
		_cyl(r, "Head%d" % i, 0.06, 0.04, Vector3(cx, 2.1, -sz * 0.5 + 0.2), _metal())
		_box(r, "Drain%d" % i, Vector3(0.2, 0.01, 0.2), Vector3(cx, 0.165, -0.1), _flat(Color(0.18, 0.2, 0.22)))
	# Roof, the water tank, the pipe along the front.
	_lean_roof(r, sx + 0.4, sz + 0.5, h + 0.1, 0.3, _camp("corrugated_roof.png", Color(0.8, 0.8, 0.76), Vector3(2.0, 2.0, 1.0)))
	_cyl(r, "Tank", 0.42, 1.2, Vector3(-sx * 0.25, h + 0.75, -0.4), _psx_mat(Color(0.56, 0.4, 0.28), "metal"), Vector3(0, 0, PI * 0.5))
	for x: float in [-sx * 0.25 - 0.4, -sx * 0.25 + 0.4]:
		_box(r, "TankCradle", Vector3(0.1, 0.4, 0.7), Vector3(x, h + 0.42, -0.4), _wood())
	_cyl(r, "Pipe", 0.04, sx, Vector3(0, h - 0.05, sz * 0.5 - 0.05), _metal(), Vector3(0, 0, PI * 0.5))
	_cyl(r, "Boiler", 0.22, 0.7, Vector3(sx * 0.5 + 0.3, 0.6, -0.4), _flat(Color(0.86, 0.86, 0.84)))
	_label(r, "SPRCHY", Vector3(0, h - 0.35, -sz * 0.5 + 0.08), 0.28, Color(0.15, 0.25, 0.4))
	return {"size": Vector3(sx + 0.4, h + 0.4, sz + 0.4), "target": Vector3(0, 1.1, sz * 0.5 + 0.2)}


# ── the pub (hospoda1.PNG): a plastered village house, porch, barrels ─────────

func _pub(r: Node3D, w: float, d: float) -> Dictionary:
	var sx := w * 0.62
	var sz := d * 0.5
	var h := 3.1
	var plaster := _camp_or("plaster_stone.png", Color(0.86, 0.84, 0.78), "wall", Vector3(2.0, 1.2, 1.0))
	_plinth(r, sx + 0.3, sz + 0.3, Vector3(-0.6, 0, -0.4))
	_box(r, "House", Vector3(sx, h, sz), Vector3(-0.6, h * 0.5 + 0.1, -0.4), plaster)
	_gable_roof(r, Vector3(-0.6, h + 0.1, -0.4), sx + 0.5, sz + 0.6, 1.5, _camp("corrugated_roof.png", Color(0.62, 0.6, 0.56), Vector3(3.0, 2.0, 1.0)))
	_box(r, "Chimney", Vector3(0.45, 1.4, 0.45), Vector3(sx * 0.25 - 0.6, h + 1.2, -0.7), _camp_or("brick_red.png", Color(0.7, 0.42, 0.34), "brick"))
	# The lower annex on the right with a lean-to roof.
	var ax := sx * 0.5 - 0.6 + 1.4
	_box(r, "Annex", Vector3(2.6, 2.3, sz * 0.8), Vector3(ax, 1.25, -0.6), plaster)
	_lean_roof(r, 2.9, sz * 0.8 + 0.5, 2.4, 0.35, _camp("corrugated_roof.png", Color(0.5, 0.48, 0.44), Vector3(2.0, 2.0, 1.0)), Vector3(ax, 0, -0.6))
	# Porch: a green awning on two posts over the door.
	var front := -0.4 + sz * 0.5
	_box(r, "Door", Vector3(0.95, 2.0, 0.06), Vector3(-1.4, 1.1, front + 0.03), _camp("door_wood.png", Color(0.7, 0.62, 0.5)))
	var awning := _box(r, "Awning", Vector3(1.9, 0.08, 1.2), Vector3(-1.4, 2.45, front + 0.6), _flat(Color(0.28, 0.42, 0.26)))
	awning.rotation.x = 0.18
	for x: float in [-2.25, -0.55]:
		_box(r, "Post", Vector3(0.1, 2.35, 0.1), Vector3(x, 1.27, front + 1.1), _wood())
	_box(r, "Step", Vector3(1.6, 0.18, 0.6), Vector3(-1.4, 0.09, front + 0.4), _psx_mat(Color(0.6, 0.6, 0.58), "stone"))
	_window(r, Vector3(0.6, 1.7, front + 0.02), Vector2(1.0, 0.8))
	_window(r, Vector3(1.9, 1.7, front + 0.02), Vector2(1.0, 0.8))
	_window(r, Vector3(-0.6, 1.9, -0.4 - sz * 0.5 - 0.02), Vector2(0.9, 0.7), PI)
	# The sign, barrels, a crate of empties, a satellite dish and the aerial.
	_box(r, "SignBoard", Vector3(1.6, 0.42, 0.05), Vector3(0.9, 2.65, front + 0.05), _flat(Color(0.2, 0.14, 0.1)))
	_label(r, "HOSPODA", Vector3(0.9, 2.65, front + 0.085), 0.24, Color(0.96, 0.84, 0.5))
	for i in 3:
		_cyl(r, "Barrel%d" % i, 0.28, 0.75, Vector3(-3.0 + i * 0.62, 0.48, front + 0.5 + (i % 2) * 0.2), _psx_mat(Color(0.5, 0.36, 0.22), "decor_wood"))
	_box(r, "Crate", Vector3(0.5, 0.3, 0.36), Vector3(2.5, 0.25, front + 0.5), _flat(Color(0.7, 0.5, 0.2)))
	_cyl(r, "Dish", 0.32, 0.06, Vector3(sx * 0.5 - 0.6 + 0.05, 2.6, front - 0.6), _flat(Color(0.82, 0.82, 0.8)), Vector3(0.4, 0.0, PI * 0.5))
	_cyl(r, "Aerial", 0.02, 1.6, Vector3(-1.6, h + 1.8, -0.4), _metal())
	_box(r, "AerialBar", Vector3(0.9, 0.03, 0.03), Vector3(-1.6, h + 2.3, -0.4), _metal())
	return {"size": Vector3(sx + 2.4, h + 1.0, sz + 0.6), "target": Vector3(-1.4, 1.2, front + 0.2)}


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
	_box(r, "Door", Vector3(0.9, 2.0, 0.06), Vector3(-0.4, 1.1, front + 0.03), _camp("door_wood.png", Color(0.6, 0.66, 0.6)))
	var awn := _box(r, "Awning", Vector3(1.4, 0.07, 0.8), Vector3(-0.4, 2.35, front + 0.4), _flat(Color(0.86, 0.66, 0.16)))
	awn.rotation.x = 0.25
	for x: float in [-2.2, 1.0, 2.0]:
		_window(r, Vector3(x, 1.75, front + 0.02), Vector2(0.85, 0.8))
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
	return {"size": Vector3(sx + 1.6, h + 0.9, sz + 0.6), "target": Vector3(-0.4, 1.2, front + 0.2)}


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
	# Three log benches: a half log, flat side up, on two stumps; two seats each.
	var top := _camp_or("knotty_pine.png", Color(0.86, 0.76, 0.62), "wood", Vector3(2.0, 0.5, 1.0))
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


# ── the sports field (iso_sports): a pitch, lines, goals, the nohejbal net ────

func _sports(r: Node3D, w: float, d: float) -> Dictionary:
	var px := w * 0.92
	var pz := d * 0.86
	_box(r, "Pitch", Vector3(px, 0.08, pz), Vector3(0, 0.04, 0), _flat(Color(0.34, 0.5, 0.24)))
	# Worn patches in the goal mouths and the middle.
	for x: float in [-px * 0.5 + 0.8, 0.0, px * 0.5 - 0.8]:
		_box(r, "Worn", Vector3(1.0, 0.085, 0.9), Vector3(x, 0.042, 0), _flat(Color(0.44, 0.38, 0.24)))
	var line := _flat(Color(0.92, 0.92, 0.88))
	_box(r, "LineN", Vector3(px - 0.4, 0.02, 0.06), Vector3(0, 0.09, -pz * 0.5 + 0.2), line)
	_box(r, "LineS", Vector3(px - 0.4, 0.02, 0.06), Vector3(0, 0.09, pz * 0.5 - 0.2), line)
	_box(r, "LineW", Vector3(0.06, 0.02, pz - 0.4), Vector3(-px * 0.5 + 0.2, 0.09, 0), line)
	_box(r, "LineE", Vector3(0.06, 0.02, pz - 0.4), Vector3(px * 0.5 - 0.2, 0.09, 0), line)
	_box(r, "LineMid", Vector3(0.06, 0.02, pz - 0.4), Vector3(0, 0.09, 0), line)
	for i in 16:
		var a := TAU * float(i) / 16.0
		var seg := _box(r, "Circle%d" % i, Vector3(0.24, 0.02, 0.05), Vector3(cos(a) * 0.6, 0.09, sin(a) * 0.6), line)
		seg.rotation.y = -a + PI * 0.5
	# Goals at the ends.
	for side: float in [-1.0, 1.0]:
		var gx := side * (px * 0.5 - 0.25)
		for z: float in [-0.75, 0.75]:
			_box(r, "GoalPost", Vector3(0.07, 1.1, 0.07), Vector3(gx, 0.6, z), line)
		_box(r, "GoalBar", Vector3(0.07, 0.07, 1.57), Vector3(gx, 1.15, 0), line)
	# The nohejbal net across the middle.
	for z: float in [-pz * 0.5 + 0.1, pz * 0.5 - 0.1]:
		_box(r, "NetPost", Vector3(0.06, 1.1, 0.06), Vector3(0, 0.6, z), _metal())
	var net := StandardMaterial3D.new()
	net.albedo_color = Color(0.1, 0.1, 0.1, 0.55)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.set_meta("base_albedo_color", net.albedo_color)
	_box(r, "Net", Vector3(0.02, 0.5, pz - 0.2), Vector3(0, 0.82, 0), net)
	return {"size": Vector3(px, 0.3, pz), "target": Vector3(0, 0.3, pz * 0.4)}


# ── the lake slide (iso_slide): a timber tower, a yellow chute, a splash pool ──

func _slide(r: Node3D, w: float, d: float) -> Dictionary:
	var wood := _wood()
	var tx := -w * 0.3
	var th := 3.2
	for x: float in [-0.45, 0.45]:
		for z: float in [-0.45, 0.45]:
			_box(r, "Leg", Vector3(0.12, th, 0.12), Vector3(tx + x, th * 0.5, z), wood)
	for y: float in [0.9, 1.9]:
		_box(r, "Brace", Vector3(1.0, 0.08, 0.08), Vector3(tx, y, 0.45), wood)
		_box(r, "Brace", Vector3(1.0, 0.08, 0.08), Vector3(tx, y, -0.45), wood)
	_box(r, "Platform", Vector3(1.1, 0.1, 1.1), Vector3(tx, th, 0), wood)
	for z: float in [-0.5, 0.5]:
		_box(r, "Rail", Vector3(1.1, 0.06, 0.06), Vector3(tx, th + 0.8, z), wood)
		_box(r, "RailPost", Vector3(0.06, 0.8, 0.06), Vector3(tx - 0.5, th + 0.4, z), wood)
	# The ladder up the back.
	for z: float in [-0.25, 0.25]:
		_box(r, "LadderRail", Vector3(0.06, th + 0.2, 0.06), Vector3(tx - 0.75, th * 0.5, z), wood)
	for i in 7:
		_box(r, "Rung", Vector3(0.06, 0.05, 0.5), Vector3(tx - 0.75, 0.4 + i * 0.42, 0), wood)
	# The chute: tilted segments falling to the pool, sides raised.
	var yellow := _flat(Color(0.95, 0.74, 0.16))
	var segs := 6
	var run := w * 0.62
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := lerpf(th, 0.35, t0 * t0 * 0.4 + t0 * 0.6)
		var y1 := lerpf(th, 0.35, t1 * t1 * 0.4 + t1 * 0.6)
		var x0 := tx + 0.55 + run * t0
		var x1 := tx + 0.55 + run * t1
		var len := Vector2(x1 - x0, y1 - y0).length()
		var seg := _box(r, "Chute%d" % i, Vector3(len + 0.02, 0.06, 0.62), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0), yellow)
		seg.rotation.z = atan2(y1 - y0, x1 - x0)
		for z: float in [-0.33, 0.33]:
			var side := _box(r, "ChuteSide%d" % i, Vector3(len + 0.02, 0.16, 0.04), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5 + 0.08, z), yellow)
			side.rotation.z = seg.rotation.z
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.18, 0.34, 0.42, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	water.set_meta("base_albedo_color", water.albedo_color)
	if ResourceLoader.exists(CAMP + "lake_water.png"):
		water.albedo_texture = load(CAMP + "lake_water.png")
	_cyl(r, "Pool", 0.95, 0.06, Vector3(tx + 0.55 + run + 0.3, 0.05, 0), water)
	return {"size": Vector3(w * 0.9, th + 0.8, 1.3), "target": Vector3(tx, 1.0, 0.7)}


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
func cabin(r: Node3D, level: int, w: float, d: float, wall_h: float, roof_h: float) -> Vector3:
	var lv := clampi(level, 1, 3)
	var plank_file := ["planks_grey.png", "planks_red.png", "planks_dark.png"][lv - 1] as String
	var tint := [Color(0.92, 0.9, 0.86), Color(0.95, 0.85, 0.82), Color(0.9, 0.86, 0.82)][lv - 1] as Color
	var walls := _camp(plank_file, tint, Vector3(1.4, 1.4, 1.0))
	_plinth(r, w + 0.2, d + 0.2)
	_box(r, "Walls", Vector3(w, wall_h, d), Vector3(0, wall_h * 0.5 + 0.1, 0), walls)
	# Corner posts.
	for x: float in [-w * 0.5, w * 0.5]:
		for z: float in [-d * 0.5, d * 0.5]:
			_box(r, "Corner", Vector3(0.14, wall_h, 0.14), Vector3(x, wall_h * 0.5 + 0.1, z), _wood())
	var tin := _camp("corrugated_roof.png", Color(0.78, 0.74, 0.7), Vector3(1.6, 1.6, 1.0))
	_gable_roof(r, Vector3(0, wall_h + 0.1, 0), w + 0.5, d + 0.7, roof_h, tin)
	# Rust patches on the tin: Lv1 has the most.
	var rust := _camp("corrugated_roof.png", Color(0.62, 0.36, 0.22), Vector3(1.6, 1.6, 1.0))
	var ang := atan2(roof_h, (d + 0.7) * 0.5)
	for i in 4 - lv:
		var side := 1.0 if i % 2 == 0 else -1.0
		var p := _box(r, "Rust%d" % i, Vector3(0.9 + 0.3 * i, 0.03, 0.7), Vector3(-w * 0.25 + i * w * 0.22, wall_h + 0.1 + roof_h * 0.56 + 0.06, side * (d + 0.7) * 0.22), rust)
		p.rotation.x = side * ang
	var front := d * 0.5
	_box(r, "Door", Vector3(0.82, 1.9, 0.06), Vector3(0, 1.05, front + 0.03), _camp("door_wood.png", Color(0.8, 0.72, 0.6)))
	_box(r, "DoorFrame", Vector3(1.0, 2.05, 0.04), Vector3(0, 1.1, front + 0.01), _wood())
	_box(r, "Step", Vector3(1.1, 0.16, 0.45), Vector3(0, 0.12, front + 0.3), _wood())
	_window(r, Vector3(-w * 0.3, wall_h * 0.62, front + 0.02), Vector2(0.62, 0.56))
	_window(r, Vector3(w * 0.3, wall_h * 0.62, front + 0.02), Vector2(0.62, 0.56))
	_window(r, Vector3(w * 0.5 + 0.02, wall_h * 0.62, 0), Vector2(0.62, 0.56), PI * 0.5)
	match lv:
		1:
			# A stack of firewood and an old bucket.
			for i in 3:
				_cyl(r, "Firewood", 0.1, 0.8, Vector3(-w * 0.5 - 0.3, 0.12 + i * 0.18, -0.4 + (i % 2) * 0.1), _psx_mat(Color(0.5, 0.36, 0.24), "tree_bark"), Vector3(PI * 0.5, 0, 0))
		2:
			# A porch board and a flower box under a window.
			_box(r, "Porch", Vector3(w * 0.7, 0.1, 0.8), Vector3(0, 0.15, front + 0.45), _wood())
			_box(r, "FlowerBox", Vector3(0.7, 0.16, 0.2), Vector3(w * 0.3, wall_h * 0.62 - 0.38, front + 0.12), _wood())
			for i in 4:
				_box(r, "Flower", Vector3(0.08, 0.12, 0.08), Vector3(w * 0.3 - 0.24 + i * 0.16, wall_h * 0.62 - 0.24, front + 0.12), _flat([Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.2)][i % 2]))
		3:
			_box(r, "Chimney", Vector3(0.4, 1.2, 0.4), Vector3(w * 0.28, wall_h + roof_h * 0.6, -d * 0.18), _camp_or("brick_red.png", Color(0.6, 0.42, 0.36), "brick"))
			_box(r, "Porch", Vector3(w * 0.8, 0.1, 0.9), Vector3(0, 0.15, front + 0.5), _wood())
			_box(r, "Bench", Vector3(1.1, 0.06, 0.3), Vector3(-w * 0.28, 0.5, front + 0.55), _wood())
	return Vector3(w + 0.4, wall_h + roof_h + 0.3, d + 0.4)


# ── tents (stan1/2/3.png): pegs, guy ropes, the door flap ─────────────────────

## Details for one A-frame tent of `w` x `h` x `d` (ridge along Z) placed at `at`.
func tent_details(r: Node3D, w: float, h: float, d: float, at: Vector3, yaw: float, color: Color) -> void:
	var t := Node3D.new()
	t.position = at
	t.rotation.y = yaw
	r.add_child(t)
	var flap := _prism_flap(w * 0.55, h * 0.8, color.darkened(0.45))
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

func caravan(r: Node3D, w: float, d: float) -> Vector3:
	var lx := w * 0.62
	var lz := d * 0.5
	var h := 1.9
	var cream := _flat(Color(0.9, 0.86, 0.74))
	var brown := _flat(Color(0.5, 0.34, 0.22))
	var y0 := 0.42
	_box(r, "Body", Vector3(lx, h * 0.62, lz), Vector3(0, y0 + h * 0.31 + h * 0.38, 0), cream)
	_box(r, "Lower", Vector3(lx, h * 0.38, lz), Vector3(0, y0 + h * 0.19, 0), brown)
	# Rounded ends: half cylinders.
	for side: float in [-1.0, 1.0]:
		var cap := _cyl(r, "End", lz * 0.5, h, Vector3(side * lx * 0.5, y0 + h * 0.5, 0), cream)
		cap.scale = Vector3(0.45, 1.0, 1.0)
		var capl := _cyl(r, "EndLow", lz * 0.5 + 0.005, h * 0.38, Vector3(side * lx * 0.5, y0 + h * 0.19, 0), brown)
		capl.scale = Vector3(0.45, 1.0, 1.0)
	_box(r, "RoofVent", Vector3(0.5, 0.12, 0.4), Vector3(-lx * 0.15, y0 + h + 0.06, 0), _flat(Color(0.95, 0.94, 0.9)))
	_box(r, "Door", Vector3(0.6, 1.5, 0.05), Vector3(-lx * 0.25, y0 + 0.82, lz * 0.5 + 0.03), _flat(Color(0.86, 0.82, 0.7)))
	_window(r, Vector3(lx * 0.12, y0 + h * 0.66, lz * 0.5 + 0.02), Vector2(0.8, 0.45))
	_window(r, Vector3(lx * 0.36, y0 + h * 0.66, lz * 0.5 + 0.02), Vector2(0.5, 0.45))
	# The striped awning over the door.
	for i in 6:
		var stripe := _box(r, "Awning%d" % i, Vector3(0.22, 0.04, 1.0), Vector3(-lx * 0.25 - 0.55 + i * 0.22, y0 + h + 0.0, lz * 0.5 + 0.45), _flat(Color(0.86, 0.2, 0.16) if i % 2 == 0 else Color(0.95, 0.94, 0.88)))
		stripe.rotation.x = 0.22
	for x: float in [-lx * 0.25 - 0.62, -lx * 0.25 + 0.62]:
		_box(r, "AwningPole", Vector3(0.04, y0 + h - 0.1, 0.04), Vector3(x, (y0 + h - 0.1) * 0.5, lz * 0.5 + 0.92), _metal())
	# Wheels, the drawbar, a gas bottle, a jack stand, two folding chairs.
	for side: float in [-1.0, 1.0]:
		_cyl(r, "Wheel", 0.32, 0.2, Vector3(0, 0.32, side * (lz * 0.5 + 0.02)), _flat(Color(0.08, 0.08, 0.08)), Vector3(PI * 0.5, 0, 0))
	var bar := _box(r, "Drawbar", Vector3(1.0, 0.08, 0.08), Vector3(lx * 0.5 + 0.7, 0.42, 0), _metal())
	bar.rotation.z = 0.08
	_cyl(r, "Gas", 0.15, 0.5, Vector3(lx * 0.5 + 0.55, 0.7, 0), _flat(Color(0.72, 0.22, 0.12)))
	_box(r, "Jack", Vector3(0.06, 0.42, 0.06), Vector3(lx * 0.5 + 1.1, 0.21, 0), _metal())
	for i in 2:
		var cx := lx * 0.1 + i * 0.7
		_box(r, "ChairSeat", Vector3(0.45, 0.04, 0.45), Vector3(cx, 0.42, lz * 0.5 + 1.1), _flat(Color(0.2, 0.36, 0.62)))
		var back := _box(r, "ChairBack", Vector3(0.45, 0.5, 0.04), Vector3(cx, 0.68, lz * 0.5 + 1.32), _flat(Color(0.2, 0.36, 0.62)))
		back.rotation.x = -0.2
	return Vector3(lx + lz * 0.5, y0 + h + 0.2, lz)


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


## A gable roof, ridge along X: two slabs and the end triangles.
func _gable_roof(r: Node3D, at: Vector3, sx: float, sz: float, rise: float, mat: Material) -> void:
	var half := sz * 0.5
	var slope := Vector2(half, rise).length()
	var ang := atan2(rise, half)
	for side: float in [-1.0, 1.0]:
		var slab := _box(r, "RoofSlab", Vector3(sx, 0.08, slope + 0.05), at + Vector3(0, rise * 0.5, side * half * 0.5), mat)
		slab.rotation.x = side * ang
	for side: float in [-1.0, 1.0]:
		var gable := _gable_triangle(sz - 0.5, rise - 0.05, (mat as StandardMaterial3D) if mat is StandardMaterial3D else null)
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


## The triangle at a gable end (in the YZ plane), filled with the wall below it.
func _gable_triangle(base: float, rise: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := base * 0.5
	for p in [Vector3(0, 0, -hz), Vector3(0, 0, hz), Vector3(0, rise, 0)]:
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


func _window(r: Node3D, pos: Vector3, size: Vector2, yaw := 0.0) -> void:
	var frame := _box(r, "WindowFrame", Vector3(size.x + 0.12, size.y + 0.12, 0.05), pos, _wood())
	frame.rotation.y = yaw
	var glass_mat := _camp("window_curtain.png", Color(0.8, 0.84, 0.86))
	var glass := _box(r, "Window", Vector3(size.x, size.y, 0.06), pos + Vector3(0, 0, 0.01 * (1.0 if yaw == 0.0 else -1.0)), glass_mat)
	glass.rotation.y = yaw
	var bar := _box(r, "WindowBar", Vector3(0.04, size.y, 0.07), pos, _wood())
	bar.rotation.y = yaw


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
	_cyl(r, "StovePipe", 0.09, 1.3, Vector3(x1 - 1.4, h + L.ROOF_RISE * 0.55, z0 + 1.2), _metal())
	_cyl(r, "StoveCap", 0.16, 0.06, Vector3(x1 - 1.4, h + L.ROOF_RISE * 0.55 + 0.68, z0 + 1.2), _metal())

	# The door: planks in a frame, a step and a porch with a lean-to over it.
	var dcx := (dx0 + dx1) * 0.5
	_box(r, "DoorLeaf", Vector3(dx1 - dx0 - 0.08, L.DOOR_H - 0.04, 0.05), Vector3(dcx, L.DOOR_H * 0.5, z1 + t + 0.03), _camp("door_wood.png", Color(0.78, 0.66, 0.52)))
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
	var og := _glass(r, "OfficeGlass", Vector3(ws.x, ws.y, 0.02), Vector3(wc.x, wc.y, z1 + 0.04))
	# The back room's window, east: small, a frame, the glass.
	_frame_z(r, "BackWindowFrame", bz0 - 0.07, bz1 + 0.07, by0 - 0.07, by1 + 0.07, x1 + t + 0.02, trim)
	_box(r, "BackMullion", Vector3(0.05, bs.y, 0.06), Vector3(x1 + t * 0.5, bc.y, bc.z), trim)
	_box(r, "BackSill", Vector3(0.2, 0.06, bs.x + 0.24), Vector3(x1 + t + 0.08, by0 - 0.09, bc.z), trim)
	var bg := _glass(r, "BackGlass", Vector3(0.02, bs.y, bs.x), Vector3(x1 + 0.04, bc.y, bc.z))

	# The store at the east end of the front: a low plank door, padlocked.
	var store_x := (wx1 + x1) * 0.5 + 0.6
	_box(r, "StoreDoor", Vector3(0.9, 1.7, 0.05), Vector3(store_x, 0.95, z1 + t + 0.03), _camp("planks_grey.png", Color(0.62, 0.56, 0.5)))
	_frame(r, "StoreFrame", store_x - 0.47, store_x + 0.47, 0.1, 1.82, z1 + t + 0.02, _wood(), false)
	_box(r, "Padlock", Vector3(0.06, 0.09, 0.04), Vector3(store_x + 0.34, 1.0, z1 + t + 0.08), _metal())
	# Firewood against the west wall.
	for i in 4:
		_cyl(r, "Firewood%d" % i, 0.11, 1.1, Vector3(x0 - t - 0.25, 0.18 + i * 0.2, z0 + 1.0 + (i % 2) * 0.12), _psx_mat(Color(0.52, 0.38, 0.24), "tree_bark"), Vector3(PI * 0.5, 0, 0))
	return {"office_glass": og, "back_glass": bg}


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
## (building_interior.gd: set_reception_glass). On GLASS_LAYER.
func _glass(r: Node3D, n: String, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.2, 0.24)
	m.roughness = 0.12
	m.metallic = 0.3
	m.metallic_specular = 0.8
	m.emission_enabled = true
	m.emission = Color(1.0, 0.78, 0.46)
	m.emission_energy_multiplier = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var g := _box(r, n, size, pos, m)
	g.layers = GLASS_LAYER
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g
