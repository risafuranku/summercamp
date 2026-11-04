extends RefCounted

## The rooms Simek lets that are not like number four (the user, 4. 11.: "each of the four
## rooms looks different inside and has other quirks, features and interactions"): their
## walls and floors, their furniture, the same for the room you stand in and for its shell
## behind the window in the village (motel_rooms.gd). What the things do: motel_two.gd,
## motel_nine.gd, motel_eleven.gd.
##
##   two     the hunters' room: pine panelling and planks, a double bed under an army
##           blanket, antlers, the tiled stove, the cuckoo clock, the gun cabinet with the
##           owl on it, the boar skin, the valve radio;
##   nine    the apartment: flock wallpaper and parquet, the satin bed, the scratched wedding
##           photograph, the minibar, the radiogram, the set with its recorder, the armchair,
##           the chandelier;
##   eleven  Mr Hora's, who took the room by the month: yellowed walls and lino, a single bed
##           as he left it, the desk under the window with his notebook on it, the hot plate
##           and the dishes, the aquarium, the washing on its line, the map, the calendar,
##           the slippers, the mattress on the floor.

const PLAN = preload("res://scripts/town/motel_plan.gd")
const ROOMS = preload("res://scripts/town/motel_rooms.gd")
const K = preload("res://scripts/interior_kit.gd")

## The middle of the table in the street corner (as in four), the armchair, the stove.
const TABLE_AT := Vector3(PLAN.ROOM_W * 0.5 - 0.42, 0.0, -PLAN.ROOM_D * 0.5 + 0.62)
const ARMCHAIR_AT := Vector3(-0.22, 0.0, -0.55)
const STOVE_AT := Vector3(-1.12, 0.0, -1.1)
const STOVE_SIZE := Vector3(0.75, 1.75, 1.0)
## The notebook on Mr Hora's desk, the one who walks the night in his washing.
const DESK_AT := Vector3(0.68, 0.74, -1.82)


static func has(n: int) -> bool:
	return n == 2 or n == 9 or n == 11


static func wall(n: int) -> Material:
	match n:
		2:
			return K.surface("motel_panel_wood", 1.3, Color(0.92, 0.88, 0.8))
		9:
			return K.surface("motel_floral_wall", 1.15, Color(0.86, 0.8, 0.72))
	return K.surface(ROOMS._pick("motel_wall_dirty", "motel_wall"), 1.4, Color(0.8, 0.7, 0.46))


static func floor_mat(n: int) -> Material:
	match n:
		2:
			return K.surface("planks_dark", 1.3, Color(0.82, 0.74, 0.64))
		9:
			return K.surface("parquet", 1.1, Color(0.78, 0.68, 0.58))
	return K.surface("cv_lino_worn", 1.5, Color(0.82, 0.8, 0.68))


static func ceiling(n: int) -> Material:
	match n:
		2:
			return K.surface("ceiling_board", 1.0, Color(0.56, 0.48, 0.38))
		9:
			return K.surface("ceiling_board", 1.0, Color(0.9, 0.82, 0.72))
	return K.surface("ceiling_board", 1.0, Color(0.72, 0.66, 0.46))


## The bathroom's tiles (their tint): green with two, pink with nine, nicotine with eleven.
static func tile(n: int) -> Color:
	match n:
		2:
			return Color(0.62, 0.74, 0.62)
		9:
			return Color(0.92, 0.7, 0.68)
	return Color(0.82, 0.76, 0.5)


static func furnish(root: Node3D, n: int, lit: bool, state: Dictionary, out: Dictionary) -> void:
	out["beds"] = []
	out["lamp_points"] = []
	match n:
		2:
			_two(root, lit, state, out)
		9:
			_nine(root, lit, state, out)
		11:
			_eleven(root, lit, state, out)


# ── what they all use ────────────────────────────────────────────────────────

static func _m(mat: Material, lit: bool) -> Material:
	return ROOMS._shell_mat(mat, lit)


static func _slab(root: Node3D, size: Vector3, at: Vector3, mat: Material, lit: bool, name: String) -> MeshInstance3D:
	return K.slab(root, size, at, _m(mat, lit), name)


## A sprite `height` tall standing at `at`, the room's shell light on it; null without art.
static func _spr(root: Node3D, tex: String, height: float, at: Vector3, yaw: float, billboard: bool, lit: bool, name: String) -> MeshInstance3D:
	if not ROOMS._exists(tex):
		return null
	var c := K.cutout(root, tex, ROOMS._sprite_size(tex, height), at, yaw, billboard, name)
	c.material_override = _m(c.material_override, lit)
	return c


static func _pic(root: Node3D, tex: String, size: Vector2, at: Vector3, facing: Vector3, lit: bool, name: String) -> MeshInstance3D:
	if not ROOMS._exists(tex):
		return null
	var q := ROOMS._quad(root, tex, size, at, facing, name)
	q.material_override = _m(q.material_override, lit)
	return q


## A bed: its frame, the cover, the pillows at the `head` end (a unit along the floor).
static func _bed(root: Node3D, at: Vector3, size: Vector3, cover: Material, head: Vector3, pillows: int, lit: bool, out: Dictionary) -> void:
	_slab(root, Vector3(size.x, 0.3, size.z), at + Vector3(0, 0.15, 0), K.surface("veneer_dark", 0.6), lit, "BedFrame")
	_slab(root, Vector3(size.x + 0.04, 0.2, size.z + 0.02), at + Vector3(0, 0.4, 0), cover, lit, "Bedspread")
	var along: float = absf(head.dot(Vector3(size.x, 0, size.z)))
	var across := Vector3(head.z, 0, head.x).abs()
	var wide: float = absf(across.dot(Vector3(size.x, 0, size.z)))
	var pm := K.surface(ROOMS._pick("motel_pillow_dirty", "mattress"), 0.5, Color(0.96, 0.93, 0.86))
	for i in pillows:
		var k := (float(i) + 0.5) / float(pillows) - 0.5
		var pos := at + Vector3(0, 0.56, 0) + head * (along * 0.5 - 0.3) + across * k * wide
		var ps := Vector3(0.36, 0.12, 0.6) if absf(head.x) > 0.5 else Vector3(0.6, 0.12, 0.36)
		var pl := _slab(root, ps, pos, pm, lit, "Pillow")
		pl.rotation = Vector3(-0.08, 0.1 * (k + 0.2), 0.0)
	(out["beds"] as Array).append({"at": at + Vector3(0, 0.35, 0), "size": Vector3(size.x, 0.4, size.z)})


## A bedside cabinet with its front to `facing`; its top's height.
static func _cabinet(root: Node3D, at: Vector3, facing: Vector3, lit: bool) -> float:
	var nsz := Vector3(0.4, 0.52, 0.38)
	_slab(root, nsz, at + Vector3(0, nsz.y * 0.5, 0), K.surface("veneer_dark", 0.6), lit, "Nightstand")
	_pic(root, "motel_nightstand", Vector2(nsz.x, nsz.y), at + Vector3(0, nsz.y * 0.5, 0) + facing * (nsz.z * 0.5 + 0.005), facing, lit, "NightstandFront")
	return nsz.y


static func _phone(root: Node3D, at: Vector3, yaw: float, lit: bool, out: Dictionary) -> void:
	var ph := _spr(root, "phone_on", 0.13, at, yaw, false, lit, "Phone")
	if ph != null:
		out["phone"] = ph


static func _ceiling_lamp(root: Node3D, lit: bool, out: Dictionary) -> void:
	var h := PLAN.ROOM_H
	var cl := K.cutout(root, "ceiling_lamp", Vector2(0.42, 0.42), Vector3(0, h - 0.43, 0.2), 0.0, true, "CeilingLamp")
	cl.material_override = _m(cl.material_override, lit)
	out["ceiling_at"] = Vector3(0, h - 0.55, 0.2)


## A bedside lamp: its picture, its glow when lit (motel_view's "lamps").
static func _bedside_lamp(root: Node3D, at: Vector3, lit: bool, out: Dictionary) -> void:
	_spr(root, "desk_lamp", 0.34, at, 180.0, true, lit, "BedsideLamp")
	var shade := ROOMS._glow_patch(root, at + Vector3(0, 0.24, 0.0), Vector2(0.16, 0.13))
	shade.visible = lit
	(out["lamps"] as Array).append(shade)
	(out["lamp_points"] as Array).append(at + Vector3(0, 0.3, 0))


# ── two: the hunters' room ───────────────────────────────────────────────────

static func _two(root: Node3D, lit: bool, _state: Dictionary, out: Dictionary) -> void:
	var w := PLAN.ROOM_W
	var d := PLAN.ROOM_D
	var h := PLAN.ROOM_H
	var r := func(a: float, b: float) -> Vector3: return Vector3(deg_to_rad(a), deg_to_rad(b), 0.0)
	# The double bed under the army blanket, the plank headboard, antlers over it.
	var bed := Vector3(-0.62, 0.0, d * 0.5 - 0.98)
	_bed(root, bed, Vector3(1.5, 0.5, 1.95), K.surface("motel_blanket_wool", 0.8), Vector3(0, 0, 1), 2, lit, out)
	_slab(root, Vector3(1.62, 1.05, 0.06), Vector3(bed.x, 0.52, d * 0.5 - 0.03), K.surface("pew_wood", 0.8, Color(0.7, 0.6, 0.5)), lit, "Headboard")
	_spr(root, "antlers", 0.62, Vector3(bed.x, 1.28, d * 0.5 - 0.02), 180.0, false, lit, "Antlers")
	for z in [-0.1, 0.6, 1.3]:
		_spr(root, "antlers", 0.34, Vector3(-w * 0.5 + 0.02, 1.72, float(z)), 90.0, false, lit, "Trophy")
	out["lie"] = {"at": Vector3(-0.9, 0.8, 1.55), "rot": r.call(6.0, -22.0)}
	out["sleeper"] = {"head": Vector3(-0.3, 0.55, d * 0.5 - 0.35), "along": Vector3(0, 0, 1)}
	# The cabinet by the bed: the telephone, the lamp, the glass, the ashtray.
	var ns := Vector3(0.42, 0.0, d * 0.5 - 0.22)
	var top := _cabinet(root, ns, Vector3(0, 0, -1), lit)
	_phone(root, ns + Vector3(0.08, top, -0.06), 200.0, lit, out)
	_bedside_lamp(root, ns + Vector3(-0.08, top, 0.08), lit, out)
	_spr(root, ROOMS._pick("ashtray_full", "motel_ashtray"), 0.07, ns + Vector3(0.1, top, 0.1), 180.0, false, lit, "Ashtray")
	# The tiled stove in the street corner, its pipe into the ceiling: its front the picture
	# (the middle of it), its sides the picture's upper tiles, two to a side.
	var sz := STOVE_SIZE
	var sa := STOVE_AT
	_slab(root, sz, sa + Vector3(0, sz.y * 0.5, 0), K.surface("veneer_dark", 0.6, Color(0.2, 0.22, 0.18)), lit, "Stove")
	var front := _pic(root, "tiled_stove", Vector2(sz.z, sz.y), sa + Vector3(sz.x * 0.5 + 0.004, sz.y * 0.5, 0), Vector3(1, 0, 0), lit, "StoveFront")
	if front != null:
		var fm := (front.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		fm.uv1_scale = Vector3(0.76, 1, 1)
		fm.uv1_offset = Vector3(0.12, 0, 0)
		front.material_override = fm
	for side in [-1.0, 1.0]:
		for i in 2:
			var q := _pic(root, "tiled_stove", Vector2(sz.x, sz.y * 0.5), sa + Vector3(0, sz.y * (0.25 + 0.5 * float(i)), float(side) * (sz.z * 0.5 + 0.004)), Vector3(0, 0, float(side)), lit, "StoveSide")
			if q != null:
				var sm := (q.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				sm.uv1_scale = Vector3(sz.x / sz.z * 0.76, 0.5, 1)
				sm.uv1_offset = Vector3(0.12, 0.02, 0)
				q.material_override = sm
	_slab(root, Vector3(0.16, h - sz.y, 0.16), Vector3(sa.x - 0.1, sz.y + (h - sz.y) * 0.5, sa.z), K.surface("galvanized", 0.4, Color(0.2, 0.19, 0.18)), lit, "StovePipe")
	out["flame_at"] = sa + Vector3(sz.x * 0.5 + 0.012, sz.y * 0.24, 0)
	# The gun cabinet on the east wall with the owl on it, the cuckoo clock nearer the bed.
	out["guns"] = _spr(root, "gun_cabinet", 1.9, Vector3(w * 0.5 - 0.05, 0.0, -0.4), -90.0, false, lit, "GunCabinet")
	out["owl"] = _spr(root, "stuffed_owl", 0.5, Vector3(w * 0.5 - 0.14, 1.88, -0.4), 0.0, true, lit, "Owl")
	out["cuckoo"] = _spr(root, "cuckoo_clock", 0.78, Vector3(w * 0.5 - 0.02, 1.1, 0.92), -90.0, false, lit, "Cuckoo")
	out["clock"] = out["cuckoo"]
	# The table in the street corner with the valve radio; the boar's skin on the planks.
	_spr(root, "motel_table", 0.95, TABLE_AT, -135.0, true, lit, "Table")
	out["radio"] = _spr(root, "tube_radio", 0.3, TABLE_AT + Vector3(0.0, 0.73, 0.0), 0.0, true, lit, "TubeRadio")
	if ROOMS._exists("boar_rug"):
		ROOMS.decal(root, "boar_rug", Vector2(1.9, 1.07), Vector3(0.28, 0.0, -0.7), Vector3.UP, 0.32, "BoarRug")
	_ceiling_lamp(root, lit, out)
	ROOMS.decal(root, "roach_dead", Vector2(0.06, 0.06), Vector3(0.9, 0.0, -1.9), Vector3.UP, 1.0, "DeadRoach")
	ROOMS.decal(root, "rum_bottle", Vector2(0.3, 0.1), Vector3(0.28, 0.0, 1.2), Vector3.UP, 1.1, "Bottle")


# ── nine: the apartment ──────────────────────────────────────────────────────

static func _nine(root: Node3D, lit: bool, _state: Dictionary, out: Dictionary) -> void:
	var w := PLAN.ROOM_W
	var d := PLAN.ROOM_D
	var h := PLAN.ROOM_H
	var r := func(a: float, b: float) -> Vector3: return Vector3(deg_to_rad(a), deg_to_rad(b), 0.0)
	var win: Vector3 = PLAN.room_windows(9)[0]
	# The rug under it all, the satin bed with its head on the west wall, the photograph.
	_slab(root, Vector3(2.0, 0.012, 1.5), Vector3(0.28, 0.006, -0.55), K.surface("armchair_fabric", 0.8, Color(0.62, 0.34, 0.3)), lit, "Rug")
	var bed := Vector3(-0.5, 0.0, 1.06)
	var satin := K.surface("satin_spread", 0.7)
	_bed(root, bed, Vector3(2.0, 0.5, 1.5), satin, Vector3(-1, 0, 0), 2, lit, out)
	_slab(root, Vector3(0.08, 1.2, 1.64), Vector3(-w * 0.5 + 0.04, 0.6, bed.z), K.surface("satin_spread", 0.5, Color(0.7, 0.56, 0.54)), lit, "Headboard")
	out["photo"] = _pic(root, "wedding_photo", Vector2(0.5, 0.66), Vector3(-w * 0.5 + 0.012, 1.62, bed.z), Vector3(1, 0, 0), lit, "WeddingPhoto")
	out["lie"] = {"at": Vector3(-1.05, 0.8, 1.28), "rot": r.call(6.0, -105.0)}
	out["sleeper"] = {"head": Vector3(-1.15, 0.55, 0.72), "along": Vector3(-1, 0, 0)}
	# The cabinets either side: the telephone and a lamp, the clock radio.
	var a := Vector3(-1.26, 0.0, 0.1)
	var ta := _cabinet(root, a, Vector3(0, 0, -1), lit)
	_phone(root, a + Vector3(0.1, ta, 0.02), 170.0, lit, out)
	_bedside_lamp(root, a + Vector3(-0.08, ta, 0.08), lit, out)
	var b := Vector3(-1.26, 0.0, d * 0.5 - 0.22)
	var tb := _cabinet(root, b, Vector3(0, 0, -1), lit)
	var ck := _spr(root, "clock_radio", 0.11, b + Vector3(0.02, tb, -0.02), 200.0, false, lit, "ClockRadio")
	if ck != null:
		out["clock"] = ck
		out["digits"] = true
	_spr(root, "water_glass", 0.1, b + Vector3(-0.1, tb, 0.08), 180.0, false, lit, "Glass")
	# The minibar on the east wall.
	out["minibar"] = _spr(root, "minibar", 0.95, Vector3(w * 0.5 - 0.3, 0.0, 0.72), -90.0, false, lit, "Minibar")
	# The set on the table in the street corner, the recorder under it.
	_spr(root, "motel_table", 0.95, TABLE_AT, -135.0, true, lit, "Table")
	var tv_at := TABLE_AT + Vector3(0.05, 0.8, 0.05)
	var tv := K.cutout(root, "cv_tv", ROOMS.TV_SIZE, tv_at, 0.0, true, "TV")
	tv.material_override = _m(tv.material_override, lit)
	out["tv"] = {"node": tv, "at": tv_at}
	out["vcr"] = _spr(root, "vcr", 0.09, TABLE_AT + Vector3(0.05, 0.72, 0.1), 0.0, true, lit, "VCR")
	# The radiogram along the west wall, the armchair turned to the set.
	out["radio"] = _spr(root, "radiogram", 0.82, Vector3(-w * 0.5 + 0.24, 0.0, -1.05), 90.0, false, lit, "Radiogram")
	out["armchair"] = _spr(root, "armchair", 1.02, ARMCHAIR_AT, 0.0, true, lit, "Armchair")
	# The radiator under the window, a print, the chandelier that came from somewhere better.
	if ROOMS._exists("motel_radiator"):
		var rad := K.cutout(root, "motel_radiator", ROOMS._sprite_size("motel_radiator", 0.55), Vector3(win.x, 0.12, -d * 0.5 + 0.06), 0.0, false, "Radiator")
		rad.material_override = _m(rad.material_override, lit)
	_pic(root, "picture_deer", Vector2(0.42, 0.56), Vector3(w * 0.5 - 0.004, 1.55, -0.45), Vector3(-1, 0, 0), lit, "Print")
	if ROOMS._exists("chapel_chandelier"):
		var ch := K.cutout(root, "chapel_chandelier", ROOMS._sprite_size("chapel_chandelier", 0.66), Vector3(0.1, h - 0.68, 0.1), 0.0, true, "Chandelier")
		ch.material_override = _m(ch.material_override, lit)
		out["ceiling_at"] = Vector3(0.1, h - 0.62, 0.1)
	else:
		_ceiling_lamp(root, lit, out)
	ROOMS.decal(root, "carpet_stain", Vector2(0.7, 0.48), Vector3(0.45, 0.014, -0.25), Vector3.UP, 0.7, "CarpetStain")
	ROOMS.decal(root, "tissue", Vector2(0.12, 0.1), Vector3(0.82, 0.0, 1.5), Vector3.UP, 0.3, "Tissue")


# ── eleven: Mr Hora's ────────────────────────────────────────────────────────

static func _eleven(root: Node3D, lit: bool, _state: Dictionary, out: Dictionary) -> void:
	var w := PLAN.ROOM_W
	var d := PLAN.ROOM_D
	var r := func(a: float, b: float) -> Vector3: return Vector3(deg_to_rad(a), deg_to_rad(b), 0.0)
	# His bed as he got out of it: the sheet thrown back, the blanket in a heap.
	var bed := Vector3(-1.05, 0.0, 0.55)
	var cover := K.surface(ROOMS._pick("motel_bedspread_dirty", "motel_bedspread"), 0.7, Color(0.8, 0.76, 0.66))
	_bed(root, bed, Vector3(0.85, 0.5, 1.95), cover, Vector3(0, 0, 1), 1, lit, out)
	var heap := K.surface("motel_blanket_wool", 0.6, Color(0.82, 0.78, 0.7))
	for v in [[0.0, 0.54, -0.42, 0.72, 0.16, 0.7, 0.2], [0.05, 0.62, -0.5, 0.56, 0.12, 0.5, -0.3], [-0.06, 0.56, -0.04, 0.5, 0.1, 0.34, 0.5]]:
		var lump := _slab(root, Vector3(float(v[3]), float(v[4]), float(v[5])), bed + Vector3(float(v[0]), float(v[1]), float(v[2])), heap, lit, "Heap")
		lump.rotation = Vector3(0.1, float(v[6]), 0.08)
	out["lie"] = {"at": Vector3(-1.05, 0.76, 1.15), "rot": r.call(6.0, -14.0)}
	# The map over the bed, the mattress on the floor for whoever comes with you.
	out["map"] = _pic(root, "district_map", Vector2(1.3, 0.97), Vector3(-w * 0.5 + 0.012, 1.62, 0.2), Vector3(1, 0, 0), lit, "Map")
	var mat := Vector3(0.05, 0.0, -0.3)
	_slab(root, Vector3(0.8, 0.14, 1.7), mat + Vector3(0, 0.07, 0), K.surface("mattress", 0.6, Color(0.76, 0.72, 0.6)), lit, "FloorMattress")
	_slab(root, Vector3(0.5, 0.1, 0.3), mat + Vector3(0, 0.19, 0.62), K.surface(ROOMS._pick("motel_pillow_dirty", "mattress"), 0.5), lit, "FloorPillow")
	out["sleeper"] = {"head": mat + Vector3(0, 0.2, 0.68), "along": Vector3(0, 0, 1)}
	(out["beds"] as Array).append({"at": mat + Vector3(0, 0.1, 0), "size": Vector3(0.8, 0.2, 1.7)})
	# The cupboard by the back wall: the hot plate and what he ate off it.
	var cup := Vector3(-0.9, 0.0, d * 0.5 - 0.24)
	var cup_h := 0.82
	_slab(root, Vector3(1.15, cup_h, 0.44), cup + Vector3(0, cup_h * 0.5, 0), K.surface("veneer_dark", 0.6, Color(0.62, 0.56, 0.5)), lit, "Cupboard")
	_pic(root, "motel_nightstand", Vector2(1.15, cup_h), cup + Vector3(0, cup_h * 0.5, -0.226), Vector3(0, 0, -1), lit, "CupboardFront")
	out["plate"] = _spr(root, "hot_plate", 0.2, cup + Vector3(-0.32, cup_h, -0.02), 180.0, true, lit, "HotPlate")
	out["plate_at"] = cup + Vector3(-0.32, cup_h + 0.1, -0.02)
	_spr(root, "dishes_plates", 0.24, cup + Vector3(0.1, cup_h, 0.02), 180.0, true, lit, "Plates")
	_spr(root, "dishes_mug", 0.13, cup + Vector3(0.34, cup_h, -0.05), 180.0, true, lit, "Mug")
	_spr(root, "dishes_pan", 0.14, cup + Vector3(-0.08, cup_h, -0.1), 190.0, true, lit, "Pan")
	# The desk under the window, his notebook, the chair with his clothes on it.
	var top := K.surface("pew_wood", 0.7, Color(1.0, 0.92, 0.8))
	var da := DESK_AT
	_slab(root, Vector3(1.4, 0.05, 0.62), da, top, lit, "Desk")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_slab(root, Vector3(0.05, 0.72, 0.05), Vector3(da.x + 0.64 * float(sx), 0.36, da.z + 0.26 * float(sz)), top, lit, "DeskLeg")
	out["gbook"] = _spr(root, "gbook_desk", 0.3, da + Vector3(0.0, 0.03, -0.04), 0.0, false, lit, "GBook")
	out["gbook_at"] = da + Vector3(0.0, 0.2, -0.05)
	out["radio"] = _spr(root, "portable_radio", 0.2, da + Vector3(-0.5, 0.03, -0.08), 0.0, false, lit, "PortableRadio")
	_spr(root, "newspaper_stack", 0.16, da + Vector3(0.5, 0.03, -0.06), 0.0, false, lit, "DeskPapers")
	_spr(root, "chair_clothes", 1.0, Vector3(0.02, 0.0, -1.42), 0.0, true, lit, "Chair")
	_phone(root, da + Vector3(0.36, 0.03, 0.14), 170.0, lit, out)
	out["phone_spot"] = "desk"
	# The aquarium on its cabinet on the east wall, the calendar, the newspapers.
	_slab(root, Vector3(0.42, 0.7, 1.0), Vector3(w * 0.5 - 0.22, 0.35, 0.42), K.surface("veneer_dark", 0.6, Color(0.6, 0.54, 0.48)), lit, "TankCabinet")
	out["tank"] = _spr(root, "aquarium", 0.52, Vector3(w * 0.5 - 0.24, 0.7, 0.42), -90.0, false, lit, "Aquarium")
	out["tank_at"] = Vector3(w * 0.5 - 0.3, 0.98, 0.42)
	out["calendar"] = _pic(root, "crossed_calendar", Vector2(0.42, 0.56), Vector3(w * 0.5 - 0.012, 1.55, -0.72), Vector3(-1, 0, 0), lit, "Calendar")
	out["papers"] = _spr(root, "newspaper_stack", 0.42, Vector3(w * 0.5 - 0.3, 0.0, -1.0), 0.0, true, lit, "Newspapers")
	# The washing on its line in the corner, the suitcase under it.
	out["washing"] = _spr(root, "clothesline", 0.95, Vector3(-0.42, 1.28, -1.28), 90.0, false, lit, "Washing")
	out["suitcase"] = _spr(root, "suitcase", 0.42, Vector3(-1.1, 0.0, -1.62), 0.0, true, lit, "Suitcase")
	for v in [[-0.5, -1.5, 0.3], [-0.38, -0.95, 1.3]]:
		if ROOMS._exists("floor_puddle"):
			ROOMS.decal(root, "floor_puddle", Vector2(0.34, 0.24), Vector3(float(v[0]), 0.0, float(v[1])), Vector3.UP, float(v[2]), "Drips")
	_ceiling_lamp(root, lit, out)
	ROOMS.decal(root, "roach_dead", Vector2(0.06, 0.06), Vector3(0.3, 0.0, 1.8), Vector3.UP, 2.0, "DeadRoach")
	ROOMS.decal(root, "tissue", Vector2(0.12, 0.1), Vector3(-0.3, 0.0, 1.45), Vector3.UP, 0.9, "Tissue")
