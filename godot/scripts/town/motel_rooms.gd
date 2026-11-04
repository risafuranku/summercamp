extends RefCounted

## The motel's rooms (motel_plan.gd), built the same for the room you stand in (town_room.gd
## draws it in its own world, things to click in it) and for the rooms seen through the
## windows from the car park (motel_block.gd, in the village: no clicks, no street wall,
## the facade is theirs). Build boxes with Grok faces (tools/artgen/prompts_mesto.tsv).
## Behind a bedroom, off the corridor (motel_hall.gd): the little hall and the bathroom.
##
## One star (the user, 4. 11.: "one-star lodging you would rather not go to, like Hotel
## Hell"): the striped wallpaper gone brown with smoke and damp, the carpet worn and
## burnt, the bedspreads stained, the pillows yellow; the headboard wall (face_motel4_wall)
## with its two lamps and its print over two single beds, the bedside cabinet between them
## with the clock radio, the telephone and the ashtray nobody empties; the wardrobe by the
## door, the radiator under the window, the table with the TV in the corner, the lamp on
## the ceiling with the stain spreading round it and the bowl under the drip. Behind the
## back wall the hall and the bathroom: brown tiles black in the grout, the shower behind its mouldy
## curtain, the toilet with its high cistern, the basin under a mirror cabinet whose
## glass is a real mirror (motel_view.gd), hair in the plughole.
## The reception: the counter across it with Simek behind, the key board with a key on
## the hook of every free room, the drinks machine, the plant, the corner with the
## television and the calendar, the flypaper black with flies, the zapper, the fan.

const PLAN = preload("res://scripts/town/motel_plan.gd")
const K = preload("res://scripts/interior_kit.gd")
const FURN = preload("res://scripts/town/motel_furnish.gd")
const CAMP := "res://assets/textury/camp/"
## The TV's screen in its picture (camp/cv_tv.png, 37 x 48): left, top, right, bottom.
const TV_SCREEN := Rect2(6.0 / 37.0, 17.0 / 48.0, 25.0 / 37.0, 17.0 / 48.0)
const TV_SIZE := Vector2(0.46, 0.6)
## The key board's hooks in its picture (camp/motel_keyboard.png): the first hook of the two
## rows and the step between them, as fractions of the picture.
const HOOK_0 := Vector2(0.097, 0.27)
const HOOK_STEP := Vector2(0.1594, 0.39)
const KEYBOARD_SIZE := Vector2(1.3, 0.73)
## The print over the beds (its frame in face_motel4_wall's picture, u and v of its middle)
## and the size it is hung at over the painted one.
const PRINT_UV := Vector2(0.4977, 0.2709)
const PRINT_SIZE := Vector2(0.71, 0.5)
## The bathroom's mirror (its middle over the basin on the bathroom's west wall).
const MIRROR_Y := 1.42
const MIRROR_Z_OFF := 0.82
## Render layers in the room's own world: what is behind the mirror (its camera skips it),
## what only the mirror shows.
const BEHIND_MIRROR := 1 << 17
const ONLY_MIRROR := 1 << 18


static func _exists(tex: String) -> bool:
	return ResourceLoader.exists(CAMP + tex + ".png")


## `tex` if its picture is there, else `old`.
static func _pick(tex: String, old: String) -> String:
	return tex if _exists(tex) else old


## A camp texture on a quad facing `facing` (room space, horizontal): pictures on walls.
static func _quad(root: Node3D, tex: String, size: Vector2, pos: Vector3, facing: Vector3, name := "Face") -> MeshInstance3D:
	var yaw := rad_to_deg(atan2(facing.x, facing.z))
	return K.picture(root, tex, size, pos, yaw, name)


## The room's light inside the shell outside: a lit room's surfaces glow a little (the
## Build way: the sector brighter), no light of its own in the village.
static func _shell_mat(m: Material, lit: bool) -> Material:
	if not lit or m == null:
		return m
	var s := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	s.emission_enabled = true
	s.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	if s.albedo_texture != null:
		s.emission_texture = s.albedo_texture
	s.emission = Color(1.0, 0.78, 0.5)
	s.emission_energy_multiplier = 0.55
	return s


## A keyed picture flat on a surface: `normal` out of it into the room, its middle at `pos`.
static func decal(root: Node3D, tex: String, size: Vector2, pos: Vector3, normal: Vector3, spin := 0.0, name := "Grime") -> MeshInstance3D:
	if not _exists(tex):
		return null
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := K._base(Color(1, 1, 1))
	m.albedo_texture = load(CAMP + tex + ".png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	mi.material_override = m
	var z := normal.normalized()
	var up := Vector3.UP if absf(z.y) < 0.9 else Vector3(0, 0, -1)
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	mi.transform = Transform3D(Basis(x, y, z).rotated(z, spin), pos + z * 0.005)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


# ── a guest room ─────────────────────────────────────────────────────────────

## Room `n` under `root` (room space). `inside`: the room you stand in (the street wall with
## its door and window, the bathroom behind the back wall, the things to click through
## motel_view.gd); else the shell behind a window in the village. `state`: {"lit": the
## lamps on, "made": the beds made, "curtain": 0 drawn .. 1 open (the shell's), "glow",
## "painting": which print (0 nobody .. 2), "stain": the ceiling's (0, 1), "prints": wet
## footprints from the bathroom to the bed}. Returns what changes later.
static func build_room(root: Node3D, n: int, inside: bool, state: Dictionary = {}) -> Dictionary:
	var out := {"lamps": [], "lights": [], "tv": {}, "key": null, "door": null, "curtains": []}
	var w := PLAN.ROOM_W
	var d := PLAN.ROOM_D
	var h := PLAN.ROOM_H
	var lit := bool(state.get("lit", false)) and not inside
	var wall := K.surface(_pick("motel_wall_dirty", "motel_wall"), 1.4, Color(0.88, 0.8, 0.66))
	var carpet := K.surface(_pick("motel_carpet_dirty", "motel_carpet"), 1.6)
	var ceil := K.surface("ceiling_board", 1.0, Color(0.88, 0.84, 0.74))
	if FURN.has(n):
		wall = FURN.wall(n)
		carpet = FURN.floor_mat(n)
		ceil = FURN.ceiling(n)
		out["tile"] = FURN.tile(n)
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), _shell_mat(carpet, lit), "Floor")
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, h + 0.05, 0), _shell_mat(ceil, lit), "Ceiling")
	var back := K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, d * 0.5 + 0.05), _shell_mat(wall, lit), "WallBack")
	K.slab(root, Vector3(0.1, h, d), Vector3(-w * 0.5 - 0.05, h * 0.5, 0), _shell_mat(wall, lit), "WallWest")
	K.slab(root, Vector3(0.1, h, d), Vector3(w * 0.5 + 0.05, h * 0.5, 0), _shell_mat(wall, lit), "WallEast")
	var win: Vector3 = PLAN.room_windows(n)[0]
	var ws := PLAN.window_size()
	if inside:
		var front := K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, -d * 0.5 - 0.05), wall, "WallFront")
		K.cut_wall(front, [[win.x - ws.x * 0.5, win.x + ws.x * 0.5, PLAN.WIN_Y.x, PLAN.WIN_Y.y]])
		K.cut_wall(back, [[PLAN.BATH_DOOR.x, PLAN.BATH_DOOR.y, 0.0, PLAN.BATH_DOOR_H]])
		K.skirting(root, Vector3(w, h, d), "planks_dark")
	if FURN.has(n):
		FURN.furnish(root, n, lit, state, out)
	else:
		_twin(root, n, lit, state, out)
	if not inside:
		# The curtains in the window: two halves, drawn or open.
		var open := float(state.get("curtain", 1.0))
		var cm: Material = K.surface("motel_curtain", 0.9) if _exists("motel_curtain") else K.surface("curtain_floral", 0.9)
		cm = _shell_mat(cm, lit or bool(state.get("glow", false)))
		var half := ws.x * 0.5
		for side in [-1.0, 1.0]:
			var cw := lerpf(half + 0.08, 0.22, open)
			var cx: float = win.x + float(side) * (ws.x * 0.5 + 0.1 - cw * 0.5)
			var c := K.slab(root, Vector3(cw, ws.y + 0.25, 0.03), Vector3(cx, win.y + 0.05, -d * 0.5 + 0.08), cm, "Curtain")
			out["curtains"].append(c)
		# The dark of the little hall through the opening in the back wall.
		var hole := K.slab(root, Vector3(PLAN.BATH_DOOR.y - PLAN.BATH_DOOR.x, PLAN.BATH_DOOR_H, 0.02), Vector3((PLAN.BATH_DOOR.x + PLAN.BATH_DOOR.y) * 0.5, PLAN.BATH_DOOR_H * 0.5, d * 0.5 - 0.004), _shell_mat(K.surface("veneer_dark", 0.6, Color(0.2, 0.18, 0.16)), lit), "Opening")
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return out
	# Inside: behind the back wall the little hall and the bathroom, the room's door from
	# the corridor at the end of the hall; the corridor outside it, for the peephole.
	_back(root, out, wall, carpet)
	return out


## Number four and the rooms like it: two single beds under the painted headboard wall,
## the cabinet between them, the wardrobe, the table with the set, the bowl under the leak.
static func _twin(root: Node3D, n: int, lit: bool, state: Dictionary, out: Dictionary) -> void:
	var w := PLAN.ROOM_W
	var d := PLAN.ROOM_D
	var h := PLAN.ROOM_H
	var win: Vector3 = PLAN.room_windows(n)[0]
	var r := func(a: float, b: float) -> Vector3: return Vector3(deg_to_rad(a), deg_to_rad(b), 0.0)
	out["digits"] = true
	out["radio_at"] = "clock"
	out["lie"] = {"at": PLAN.LIE, "rot": r.call(6.0, -25.0)}
	out["sleeper"] = {"head": Vector3(PLAN.BED_X[1], 0.55, d * 0.5 - 0.35), "along": Vector3(0, 0, 1)}
	var la := PLAN.headwall_at(0.845, 0.54)
	var lb := PLAN.headwall_at(0.155, 0.54)
	out["lamp_points"] = [Vector3(la.x, la.y, d * 0.5 - 0.25), Vector3(lb.x, lb.y, d * 0.5 - 0.25)]
	# The headboard wall: its picture on the back wall (the part of it west of the
	# bathroom's door), a picture rail along its top.
	var hr := PLAN.headwall_rect()
	var hw_h := w * 9.0 / 16.0
	if _exists("motel4_wall"):
		var hw := _quad(root, "motel4_wall", Vector2(hr.y, hw_h), Vector3(hr.x, PLAN.HEADWALL_Y + hw_h * 0.5, d * 0.5 - 0.004), Vector3(0, 0, -1), "Headwall")
		var hm := (hw.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		hm.uv1_scale = Vector3(PLAN.HEADWALL_CROP.y - PLAN.HEADWALL_CROP.x, 1, 1)
		# The quad faces -z (turned): its u runs from the room's +x to -x, as the whole
		# picture's did.
		hm.uv1_offset = Vector3(PLAN.HEADWALL_CROP.x, 0, 0)
		hm.albedo_color = Color(0.86, 0.82, 0.74)
		hw.material_override = _shell_mat(hm, lit)
		K.slab(root, Vector3(hr.y, 0.04, 0.03), Vector3(hr.x, PLAN.HEADWALL_Y + hw_h + 0.02, d * 0.5 - 0.015), _shell_mat(K.surface("veneer_dark", 0.5), lit), "PictureRail")
		# Its two lamps' shades, lit at night: a glow over each.
		for u in [0.155, 0.845]:
			var at := PLAN.headwall_at(float(u), 0.54)
			var shade := _glow_patch(root, Vector3(at.x, at.y, d * 0.5 - 0.008), Vector2(0.17, 0.13))
			out["lamps"].append(shade)
			shade.visible = lit or bool(state.get("lit", false))
		# The print over the beds, hung over the painted one: what is by the river changes.
		var k := int(state.get("painting", 0))
		var ptex := "motel_painting_%d" % clampi(k, 0, 2)
		if _exists(ptex):
			var pa := PLAN.headwall_at(PRINT_UV.x, PRINT_UV.y)
			var pr := _quad(root, ptex, PRINT_SIZE, Vector3(pa.x, pa.y, d * 0.5 - 0.009), Vector3(0, 0, -1), "Print")
			pr.material_override = _shell_mat(pr.material_override, lit)
			out["print"] = pr
	# The two beds either side of the cabinet: veneer frames, the stained spreads, the pillows.
	var spread := K.surface(_pick("motel_bedspread_dirty", "motel_bedspread"), 0.7)
	var pillow_m := K.surface(_pick("motel_pillow_dirty", "mattress"), 0.5, Color(0.96, 0.93, 0.86))
	var frame := K.surface("veneer_dark", 0.6)
	for i in PLAN.BED_X.size():
		var bx: float = PLAN.BED_X[i]
		var bs := PLAN.BED_SIZE
		K.slab(root, Vector3(bs.x, 0.3, bs.z), Vector3(bx, 0.15, PLAN.BED_Z), _shell_mat(frame, lit), "BedFrame")
		var top := K.slab(root, Vector3(bs.x + 0.04, 0.2, bs.z + 0.02), Vector3(bx, 0.4, PLAN.BED_Z - 0.01), _shell_mat(spread, lit), "Bedspread")
		top.set_meta("bed", i)
		if bool(state.get("made", true)):
			var hump := K.slab(root, Vector3(bs.x + 0.02, 0.12, 0.42), Vector3(bx, 0.55, d * 0.5 - 0.27), _shell_mat(spread, lit), "PillowHump")
			hump.rotation.x = -0.12
		else:
			var pillow := K.slab(root, Vector3(0.6, 0.12, 0.34), Vector3(bx + 0.05, 0.56, d * 0.5 - 0.3), _shell_mat(pillow_m, lit), "Pillow")
			pillow.rotation = Vector3(-0.2, 0.15, 0.0)
	# The bedside cabinet between them: the clock radio, the telephone, the ashtray, a glass.
	var ns := PLAN.NIGHTSTAND
	var nsz := Vector3(0.4, 0.52, 0.38)
	K.slab(root, nsz, Vector3(ns.x, nsz.y * 0.5, ns.z), _shell_mat(frame, lit), "Nightstand")
	if _exists("motel_nightstand"):
		var nf := _quad(root, "motel_nightstand", Vector2(nsz.x, nsz.y), Vector3(ns.x, nsz.y * 0.5, ns.z - nsz.z * 0.5 - 0.005), Vector3(0, 0, -1), "NightstandFront")
		nf.material_override = _shell_mat(nf.material_override, lit)
	var top_y := nsz.y
	if _exists("clock_radio"):
		out["clock"] = K.cutout(root, "clock_radio", _sprite_size("clock_radio", 0.11), Vector3(ns.x - 0.07, top_y, ns.z - 0.03), 215.0, false, "ClockRadio")
	if _exists("phone_on"):
		out["phone"] = K.cutout(root, "phone_on", _sprite_size("phone_on", 0.13), Vector3(ns.x + 0.09, top_y, ns.z - 0.06), 200.0, false, "Phone")
	var ash := _pick("ashtray_full", "motel_ashtray")
	if _exists(ash):
		K.cutout(root, ash, _sprite_size(ash, 0.07), Vector3(ns.x + 0.02, top_y, ns.z + 0.1), 180.0, false, "Ashtray")
	if _exists("water_glass"):
		K.cutout(root, "water_glass", _sprite_size("water_glass", 0.1), Vector3(ns.x - 0.13, top_y, ns.z + 0.09), 180.0, false, "Glass")
	# The wardrobe built in by the door, shallow: a veneer box, its doors' picture to the room.
	var wd := Vector3(0.42, 1.9, 1.0)
	var wpos := Vector3(-w * 0.5 + wd.x * 0.5, wd.y * 0.5, PLAN.WARDROBE_Z)
	K.slab(root, wd, wpos, _shell_mat(K.surface("veneer_dark", 0.6), lit), "Wardrobe")
	if _exists("motel_wardrobe"):
		var wf := _quad(root, "motel_wardrobe", Vector2(wd.z, wd.y), wpos + Vector3(wd.x * 0.5 + 0.006, 0, 0), Vector3(1, 0, 0), "WardrobeFront")
		wf.material_override = _shell_mat(wf.material_override, lit)
		out["wardrobe"] = wf
	# A print of a stag on the east wall where the basin was (it is in the bathroom now).
	if _exists("picture_deer"):
		var dp := _quad(root, "picture_deer", Vector2(0.38, 0.5), Vector3(w * 0.5 - 0.004, 1.55, -0.55), Vector3(-1, 0, 0), "Deer")
		dp.material_override = _shell_mat(dp.material_override, lit)
	# The radiator under the window.
	if _exists("motel_radiator"):
		var rad := K.cutout(root, "motel_radiator", _sprite_size("motel_radiator", 0.55), Vector3(win.x, 0.12, -d * 0.5 + 0.06), 0.0, false, "Radiator")
		rad.material_override = _shell_mat(rad.material_override, lit)
	# The table and chair in the front corner, the TV on the table.
	var table_at := Vector3(w * 0.5 - 0.42, 0.0, -d * 0.5 + 0.62)
	if _exists("motel_table"):
		var tb := K.cutout(root, "motel_table", _sprite_size("motel_table", 0.95), table_at, -135.0, true, "Table")
		tb.material_override = _shell_mat(tb.material_override, lit)
	var tv := K.cutout(root, "cv_tv", TV_SIZE, table_at + Vector3(0.05, 0.72, 0.05), 0.0, true, "TV")
	tv.material_override = _shell_mat(tv.material_override, lit)
	out["tv"] = {"node": tv, "at": table_at + Vector3(0.05, 0.72, 0.05)}
	# The lamp on the ceiling, the stain spreading over the east side, the bowl under its drip.
	var cl := K.cutout(root, "ceiling_lamp", Vector2(0.42, 0.42), Vector3(0, h - 0.43, 0.2), 0.0, true, "CeilingLamp")
	cl.material_override = _shell_mat(cl.material_override, lit)
	var stain := "ceiling_stain_%d" % clampi(int(state.get("stain", 0)), 0, 1)
	decal(root, stain, Vector2(1.1, 0.95), Vector3(0.95, h - 0.002, 0.45), Vector3.DOWN, 0.6, "CeilingStain")
	out["drip_at"] = Vector3(0.95, h - 0.05, 0.45)
	if _exists("plastic_bowl"):
		K.cutout(root, "plastic_bowl", _sprite_size("plastic_bowl", 0.17), Vector3(0.95, 0.0, 0.45), 0.0, true, "Bowl")
	# What the last ones left: the carpet's stains and burns, the bottle, the tissue, a roach.
	decal(root, "carpet_stain", Vector2(0.75, 0.5), Vector3(0.45, 0.0, -0.55), Vector3.UP, 0.4, "CarpetStain")
	decal(root, "carpet_stain", Vector2(0.5, 0.35), Vector3(-1.1, 0.0, -1.6), Vector3.UP, 2.2, "CarpetStain")
	decal(root, "rum_bottle", Vector2(0.3, 0.1), Vector3(-0.42, 0.0, 0.05), Vector3.UP, 1.9, "Bottle")
	decal(root, "tissue", Vector2(0.12, 0.1), Vector3(1.2, 0.0, -1.05), Vector3.UP, 0.3, "Tissue")
	decal(root, "roach_dead", Vector2(0.06, 0.06), Vector3(win.x - 0.5, 0.0, -d * 0.5 + 0.12), Vector3.UP, 1.0, "DeadRoach")
	if bool(state.get("prints", false)):
		# Wet bare feet from the bathroom's door to the first bed, the morning after.
		for i in 4:
			var t := float(i + 1) / 5.0
			var p: Vector3 = Vector3(1.12, 0.0, 1.95).lerp(Vector3(-0.5, 0.0, 0.45), t)
			decal(root, "wet_footprints", Vector2(0.3, 0.22), p, Vector3.UP, -0.8 + 0.1 * float(i), "WetPrints")


## Behind the bedroom (inside only): the little hall from the corridor's door to the
## opening in the back wall, its coat hooks, the switches; the door with its key, chain
## and peephole; the stretch of the corridor the peephole looks out on.
static func _back(root: Node3D, out: Dictionary, wall: Material, carpet: Material) -> void:
	var z0 := PLAN.BACK_Z
	var z1 := z0 + PLAN.BACK_D
	var x0 := PLAN.HALL_X.x
	var x1 := PLAN.HALL_X.y
	var h := PLAN.BATH_H
	var xm := (x0 + x1) * 0.5
	var zm := (z0 + z1) * 0.5
	K.slab(root, Vector3(x1 - x0, 0.1, z1 - z0), Vector3(xm, -0.05, zm), carpet, "HallFloor")
	K.slab(root, Vector3(x1 - x0, 0.1, z1 - z0), Vector3(xm, h + 0.05, zm), K.surface("ceiling_board", 1.0, Color(0.8, 0.78, 0.7)), "HallCeiling")
	K.slab(root, Vector3(0.1, h, z1 - z0), Vector3(x1 + 0.05, h * 0.5, zm), wall, "HallEast")
	# The wall to the bathroom with the bathroom's door in it.
	var dz0 := PLAN.INNER_DOOR_Z.x
	var dz1 := PLAN.INNER_DOOR_Z.y
	var dh := PLAN.BATH_DOOR_H
	var mid := K.slab(root, Vector3(x0 - PLAN.BATH_X.y, h, z1 - z0), Vector3((x0 + PLAN.BATH_X.y) * 0.5, h * 0.5, zm), wall, "HallWest")
	K.cut_wall(mid, [[dz0 - zm, dz1 - zm, 0.0, dh]])
	# The south wall with the door to the corridor.
	var ex0 := PLAN.ENTRY_X.x
	var ex1 := PLAN.ENTRY_X.y
	var w := PLAN.ROOM_W
	var south := K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, z1 + 0.05), wall, "South")
	K.cut_wall(south, [[ex0, ex1, 0.0, PLAN.DOOR_H]])
	var door := PLAN.room_door(1)
	var leaf := K.slab(root, Vector3(ex1 - ex0, PLAN.DOOR_H, 0.05), Vector3(door.x, PLAN.DOOR_H * 0.5, z1 + 0.05), K.surface("veneer_dark", 0.6), "DoorLeaf")
	out["door"] = leaf
	if _exists("motel_door_in"):
		_quad(root, "motel_door_in", Vector2(ex1 - ex0, PLAN.DOOR_H), Vector3(door.x, PLAN.DOOR_H * 0.5, z1 + 0.018), Vector3(0, 0, -1), "DoorInside")
	if _exists("motel_key"):
		out["key"] = K.cutout(root, "motel_key", Vector2(0.075, 0.2), Vector3(door.x + 0.24, 0.72, z1 + 0.01), 180.0, false, "KeyInLock")
	if _exists("chain_loose"):
		out["chain"] = K.cutout(root, "chain_loose", _sprite_size("chain_loose", 0.2), Vector3(door.x + 0.22, 1.34, z1 + 0.01), 180.0, false, "Chain")
	var brass := K.surface("galvanized", 0.3, Color(0.62, 0.52, 0.3))
	out["peephole"] = K.slab(root, Vector3(0.035, 0.035, 0.02), Vector3(door.x, 1.55, z1 + 0.012), brass, "Peephole")
	var plastic := K.surface("plastic", 0.3, Color(0.86, 0.82, 0.72))
	out["switch"] = K.slab(root, Vector3(0.02, 0.12, 0.08), Vector3(x1 - 0.01, 1.1, z1 - 0.3), plastic, "Switch")
	out["bath_switch"] = K.slab(root, Vector3(0.02, 0.12, 0.08), Vector3(x0 + 0.01, 1.1, dz1 + 0.14), plastic, "BathSwitch")
	if _exists("coat_hook"):
		K.cutout(root, "coat_hook", _sprite_size("coat_hook", 0.6), Vector3(x1 - 0.02, 1.2, z0 + 0.55), -90.0, false, "CoatHook")
	# Its bulb over the door, on the same switch as the room's.
	K.cutout(root, "ceiling_lamp", Vector2(0.28, 0.28), Vector3(xm, h - 0.29, z1 - 0.5), 0.0, true, "HallLamp")
	out["hall_at"] = Vector3(xm, h - 0.34, z1 - 0.5)
	_bathroom(root, out)
	_corridor_stub(root, door, z1)


## The stretch of the corridor outside the room's door: only the peephole sees it.
static func _corridor_stub(root: Node3D, door: Vector3, z1: float) -> void:
	var zc := z1 + 0.1
	var depth := PLAN.CORRIDOR_Z.y - PLAN.CORRIDOR_Z.x
	var runner := K.surface(_pick("corridor_carpet", "motel_carpet_dirty"), 1.6)
	var wall := K.surface(_pick("motel_wall_dirty", "motel_wall"), 1.4, Color(0.88, 0.8, 0.66))
	var hh := PLAN.ROOM_H
	var x := door.x
	K.slab(root, Vector3(9.0, 0.1, depth), Vector3(x, -0.05, zc + depth * 0.5), runner, "StubFloor")
	K.slab(root, Vector3(9.0, 0.1, depth), Vector3(x, hh + 0.05, zc + depth * 0.5), K.surface("ceiling_board", 1.0, Color(0.8, 0.78, 0.7)), "StubCeiling")
	K.slab(root, Vector3(9.0, hh, 0.1), Vector3(x, hh * 0.5, zc + depth + 0.05), wall, "StubFar")
	for sx in [-1.0, 1.0]:
		K.slab(root, Vector3(0.1, hh, depth), Vector3(x + float(sx) * 4.5, hh * 0.5, zc + depth * 0.5), wall, "StubEnd")
	K.cutout(root, "ceiling_lamp", Vector2(0.36, 0.36), Vector3(x, hh - 0.37, zc + depth * 0.5), 0.0, true, "StubLamp")
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.56)
	l.light_energy = 0.9
	l.omni_range = 4.0
	l.position = Vector3(x, hh - 0.5, zc + depth * 0.5)
	root.add_child(l)


## The bathroom behind the bedroom (inside only): tiled, its door swinging in off the hall,
## the basin under the mirror cabinet on its west wall, the toilet on the south wall, the
## shower in the north-east corner behind its curtain; its light and the line of it under
## the door.
static func _bathroom(root: Node3D, out: Dictionary) -> void:
	var z0 := PLAN.BACK_Z
	var z1 := z0 + PLAN.BACK_D
	var x0 := PLAN.BATH_X.x
	var x1 := PLAN.BATH_X.y
	var h := PLAN.BATH_H
	var zm := (z0 + z1) * 0.5
	var xm := (x0 + x1) * 0.5
	var tiles := K.surface(_pick("motel_bath_tiles", "tiles_bathroom"), 1.1, out.get("tile", Color(0.84, 0.8, 0.7)))
	K.slab(root, Vector3(x1 - x0, 0.1, z1 - z0), Vector3(xm, -0.05, zm), K.surface(_pick("tiles_brown", "kitchen_tiles"), 0.7, Color(0.8, 0.76, 0.7)), "BathFloor")
	K.slab(root, Vector3(x1 - x0, 0.1, z1 - z0), Vector3(xm, h + 0.05, zm), K.surface("ceiling_board", 1.0, Color(0.8, 0.78, 0.7)), "BathCeiling")
	var west := K.slab(root, Vector3(0.1, h, z1 - z0), Vector3(x0 - 0.05, h * 0.5, zm), tiles, "BathWest")
	west.layers = BEHIND_MIRROR
	# Tiles over the walls it shares: the bedroom's back wall, the south wall, the wall to
	# the hall round its door.
	K.slab(root, Vector3(x1 - x0, h, 0.02), Vector3(xm, h * 0.5, z0 + 0.01), tiles, "BathNorth")
	K.slab(root, Vector3(x1 - x0, h, 0.02), Vector3(xm, h * 0.5, z1 - 0.01), tiles, "BathSouth")
	var dz0 := PLAN.INNER_DOOR_Z.x
	var dz1 := PLAN.INNER_DOOR_Z.y
	var dh := PLAN.BATH_DOOR_H
	for seg in [[z0, dz0, 0.0, h], [dz1, z1, 0.0, h], [dz0, dz1, dh, h]]:
		var a0: float = seg[0]
		var a1: float = seg[1]
		K.slab(root, Vector3(0.02, float(seg[3]) - float(seg[2]), a1 - a0), Vector3(x1 - 0.01, (float(seg[2]) + float(seg[3])) * 0.5, (a0 + a1) * 0.5), tiles, "BathEast")
	# The door, on its hinges at the south jamb, opening into the bathroom.
	var pivot := Node3D.new()
	pivot.name = "BathDoorPivot"
	pivot.position = Vector3(PLAN.WALL_X, 0.0, dz1)
	root.add_child(pivot)
	var dw := dz1 - dz0 - 0.02
	var leaf := K.slab(pivot, Vector3(0.04, dh - 0.02, dw), Vector3(0, (dh - 0.02) * 0.5, -dw * 0.5 - 0.01), K.surface("plastic", 0.5, Color(0.86, 0.84, 0.78)), "BathDoorLeaf")
	if _exists("motel_bath_door"):
		for f in [-1.0, 1.0]:
			var face := K.picture(pivot, "motel_bath_door", Vector2(dw, dh - 0.02), Vector3(float(f) * 0.022, (dh - 0.02) * 0.5, -dw * 0.5 - 0.01), 90.0 * float(f), "BathDoorFace")
			face.name = "BathDoorFace"
	out["bath_door"] = pivot
	out["bath_leaf"] = leaf
	# The basin and the mirror cabinet over it on the west wall (facing east), the real
	# mirror behind the cabinet's glass.
	var bz := z0 + MIRROR_Z_OFF
	if _exists("bath_basin"):
		K.cutout(root, "bath_basin", _sprite_size("bath_basin", 0.92), Vector3(x0 + 0.03, 0.0, bz), 90.0, false, "Basin")
	var mirror := MeshInstance3D.new()
	mirror.name = "Mirror"
	var mq := QuadMesh.new()
	mq.size = Vector2(0.42, 0.46)
	mirror.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.1, 0.11, 0.12)
	mirror.material_override = mm
	mirror.position = Vector3(x0 + 0.012, MIRROR_Y, bz)
	mirror.rotation.y = PI * 0.5
	mirror.layers = BEHIND_MIRROR
	mirror.set_meta("retro_skip", true)
	root.add_child(mirror)
	out["mirror"] = mirror
	if _exists("mirror_cabinet"):
		var cab := K.cutout(root, "mirror_cabinet", _sprite_size("mirror_cabinet", 0.66), Vector3(x0 + 0.025, MIRROR_Y - 0.36, bz), 90.0, false, "MirrorCabinet")
		cab.layers = BEHIND_MIRROR
	if _exists("mirror_crack"):
		var cr := K.cutout(root, "mirror_crack", Vector2(0.14, 0.26), Vector3(x0 + 0.018, MIRROR_Y - 0.02, bz - 0.08), 90.0, false, "MirrorCrack")
		cr.layers = BEHIND_MIRROR
	# The toilet against the south wall, its cistern high on the wall.
	if _exists("motel_toilet"):
		K.cutout(root, "motel_toilet", _sprite_size("motel_toilet", 1.35), Vector3(-0.4, 0.0, z1 - 0.04), 180.0, false, "Toilet")
	# The shower in the north-east corner: its tray, its curtain on the rod along its south side.
	var sx := -0.25
	var sz := z0 + 0.72
	var tray := Vector3(x1 - sx, 0.12, sz - z0)
	K.slab(root, tray, Vector3((sx + x1) * 0.5, 0.06, (z0 + sz) * 0.5), K.surface("enamel_white", 0.6, Color(0.82, 0.8, 0.74)), "ShowerTray")
	K.slab(root, Vector3(tray.x, 0.02, 0.02), Vector3((sx + x1) * 0.5, 2.05, sz), K.surface("galvanized", 0.3), "ShowerRod")
	if _exists("shower_curtain"):
		var sc := K.cutout(root, "shower_curtain", Vector2(tray.x, 1.9), Vector3((sx + x1) * 0.5, 0.13, sz), 0.0, false, "ShowerCurtain")
		out["shower_curtain"] = sc
		out["shower_span"] = Vector2(sx, x1)
	_bath_grime(root, x0, x1, z0, z1, sx, sz, bz)
	# Its lamp, the light, the line under the door.
	var lamp := K.cutout(root, "ceiling_lamp", Vector2(0.3, 0.3), Vector3(xm, h - 0.31, zm), 0.0, true, "BathLamp")
	out["bath_lamp"] = lamp
	var l := OmniLight3D.new()
	l.name = "BathLight"
	l.light_color = Color(1.0, 0.92, 0.72)
	l.light_energy = 1.1
	l.omni_range = 3.4
	l.omni_attenuation = 1.2
	l.shadow_enabled = true
	l.position = Vector3(xm, h - 0.45, zm)
	l.visible = false
	root.add_child(l)
	out["bath_light"] = l
	var gap := MeshInstance3D.new()
	gap.name = "DoorGap"
	var gq := QuadMesh.new()
	gq.size = Vector2(dz1 - dz0 - 0.04, 0.014)
	gap.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.86, 0.58)
	gap.material_override = gm
	gap.position = Vector3(PLAN.HALL_X.x + 0.006, 0.007, (dz0 + dz1) * 0.5)
	gap.rotation.y = PI * 0.5
	gap.visible = false
	gap.set_meta("retro_skip", true)
	root.add_child(gap)
	out["gap"] = gap
	var gl := OmniLight3D.new()
	gl.name = "GapLight"
	gl.light_color = Color(1.0, 0.86, 0.58)
	gl.light_energy = 0.4
	gl.omni_range = 1.5
	gl.position = Vector3(PLAN.HALL_X.x + 0.2, 0.08, (dz0 + dz1) * 0.5)
	gl.visible = false
	root.add_child(gl)
	out["gap_light"] = gl


## The bathroom's filth: hair in the shower's plughole, a rusty blade and the soap on the
## basin's ledge, mould in the grout along the floor and the shower.
static func _bath_grime(root: Node3D, x0: float, x1: float, z0: float, z1: float, sx: float, sz: float, bz: float) -> void:
	decal(root, "hair_clump", Vector2(0.14, 0.12), Vector3((sx + x1) * 0.5, 0.121, (z0 + sz) * 0.5), Vector3.UP, 0.5, "Hair")
	decal(root, "soap_hair", Vector2(0.1, 0.07), Vector3(x1 - 0.14, 0.121, z0 + 0.14), Vector3.UP, 1.2, "Soap")
	decal(root, "mould_grout", Vector2(0.7, 0.35), Vector3((sx + x1) * 0.5, 0.32, z0 + 0.022), Vector3.BACK, 0.0, "Mould")
	decal(root, "mould_grout", Vector2(0.6, 0.3), Vector3(x0 + 0.5, 0.25, z1 - 0.022), Vector3.FORWARD, 0.0, "Mould")
	decal(root, "mould_grout", Vector2(0.5, 0.28), Vector3(x1 - 0.022, 0.3, z1 - 0.2), Vector3.LEFT, 3.1, "Mould")
	decal(root, "razor", Vector2(0.06, 0.03), Vector3(x0 + 0.004, 0.86, bz + 0.2), Vector3.RIGHT, 0.2, "Razor")


## A Grok sprite's size in metres for its height (its picture's aspect).
static func _sprite_size(tex: String, height: float) -> Vector2:
	var path := CAMP + tex + ".png"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		return Vector2(height * float(t.get_width()) / float(t.get_height()), height)
	return Vector2(height, height)


## A warm glow over a painted lamp shade: a small additive quad, shown when the lamp is on.
static func _glow_patch(root: Node3D, pos: Vector3, size: Vector2) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.55, 0.4, 0.2)
	m.set_meta("retro_skip", true)
	var mi := MeshInstance3D.new()
	mi.name = "LampGlow"
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = PI
	mi.set_meta("retro_skip", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


# ── the reception ───────────────────────────────────────────────────────────

## The reception under `root` (its own space: PLAN.lobby_origin()). `keys`: the numbers of
## the rooms whose key hangs on the board. Returns {"keys": {n: node}, "lamp": node,
## "counter_top": y, "simek": Vector3 (where he stands), "bell": node, "book": node}.
static func build_lobby(root: Node3D, inside: bool, keys: Array, state: Dictionary = {}) -> Dictionary:
	var out := {"keys": {}, "lamp": null, "simek": Vector3.ZERO, "bell": null, "book": null}
	var size := PLAN.lobby_size()
	var w := size.x
	var d := size.z
	var h := size.y
	var lit := bool(state.get("lit", false)) and not inside
	var wall := K.surface(_pick("motel_wall_dirty", "motel_wall"), 1.4, Color(0.88, 0.8, 0.66))
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), _shell_mat(K.surface(_pick("motel_carpet_dirty", "motel_carpet"), 1.6), lit), "Floor")
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, h + 0.05, 0), _shell_mat(K.surface("ceiling_board", 1.0, Color(0.88, 0.84, 0.74)), lit), "Ceiling")
	K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, d * 0.5 + 0.05), _shell_mat(wall, lit), "WallBack")
	K.slab(root, Vector3(0.1, h, d), Vector3(-w * 0.5 - 0.05, h * 0.5, 0), _shell_mat(wall, lit), "WallWest")
	K.slab(root, Vector3(0.1, h, d), Vector3(w * 0.5 + 0.05, h * 0.5, 0), _shell_mat(wall, lit), "WallEast")
	var door := PLAN.room_door(0)
	var wins: Array = PLAN.room_windows(0)
	var ws := PLAN.window_size()
	if inside:
		var holes: Array = [[door.x - 0.45, door.x + 0.45, 0.0, PLAN.DOOR_H]]
		for wv in wins:
			holes.append([(wv as Vector3).x - ws.x * 0.5, (wv as Vector3).x + ws.x * 0.5, PLAN.WIN_Y.x, PLAN.WIN_Y.y])
		var front := K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, -d * 0.5 - 0.05), wall, "WallFront")
		K.cut_wall(front, holes)
		K.skirting(root, size, "planks_dark")
	# The counter across the room, a little left of the door; its front to you.
	var cx := door.x - 0.65
	var counter := Vector3(2.8, 1.05, 0.6)
	var cpos := Vector3(cx, counter.y * 0.5, 0.55)
	var veneer := _shell_mat(K.surface("veneer_dark", 0.6), lit)
	K.slab(root, counter, cpos, veneer, "Counter")
	K.slab(root, Vector3(counter.x + 0.1, 0.05, counter.z + 0.1), cpos + Vector3(0, counter.y * 0.5 + 0.025, 0), veneer, "CounterTop")
	if _exists("motel_counter"):
		var cf := _quad(root, "motel_counter", Vector2(counter.x, counter.y), cpos + Vector3(0, 0, -counter.z * 0.5 - 0.006), Vector3(0, 0, -1), "CounterFront")
		cf.material_override = _shell_mat(cf.material_override, lit)
	out["counter"] = cpos + Vector3(0, counter.y * 0.5 + 0.05, 0)
	# To one side, so the board behind the counter is yours to look at.
	out["simek"] = Vector3(cx - 0.95, 0.0, 1.32)
	# On the counter: the bell, the guest book, the ashtray, his lamp, the fan.
	var top_y := counter.y + 0.05
	if _exists("motel_bell"):
		out["bell"] = K.cutout(root, "motel_bell", _sprite_size("motel_bell", 0.11), Vector3(cx + 0.95, top_y, 0.4), 0.0, true, "Bell")
	if _exists("motel_guestbook"):
		var bk := K.slab(root, Vector3(0.42, 0.012, 0.3), Vector3(cx - 0.55, top_y + 0.006, 0.42), K.surface("paper_old", 0.3, Color(0.95, 0.92, 0.84)), "GuestBook")
		out["book"] = bk
		var pic := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.42, 0.3)
		pic.mesh = pm
		var bm := K._base(Color(1, 1, 1))
		bm.albedo_texture = load(CAMP + "motel_guestbook.png")
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		bm.alpha_scissor_threshold = 0.5
		pic.material_override = bm
		pic.position = Vector3(cx - 0.55, top_y + 0.014, 0.42)
		pic.rotation.y = PI
		root.add_child(pic)
	var ash := _pick("ashtray_full", "motel_ashtray")
	if _exists(ash):
		K.cutout(root, ash, _sprite_size(ash, 0.07), Vector3(cx + 0.45, top_y, 0.62), 0.0, true, "Ashtray")
	var lamp := K.cutout(root, "desk_lamp", Vector2(0.3, 0.31), Vector3(cx - 1.05, top_y, 0.7), 0.0, true, "DeskLamp")
	lamp.material_override = _shell_mat(lamp.material_override, lit)
	out["lamp"] = lamp
	if _exists("desk_fan"):
		out["fan"] = K.cutout(root, "desk_fan", _sprite_size("desk_fan", 0.3), Vector3(cx + 1.25, top_y, 0.7), 0.0, true, "DeskFan")
	# The key board on the back wall behind him, a key on the hook of every free room.
	var kb_at := Vector3(cx + 0.25, 1.62, d * 0.5 - 0.004)
	if _exists("motel_keyboard"):
		var kb := _quad(root, "motel_keyboard", KEYBOARD_SIZE, kb_at, Vector3(0, 0, -1), "KeyBoard")
		kb.material_override = _shell_mat(kb.material_override, lit)
		if _exists("motel_key"):
			for n in range(1, 13):
				if not keys.has(n):
					continue
				var col := (n - 1) % 6
				var row := (n - 1) / 6
				# The picture faces -Z (turned PI): its left edge is at +x.
				var fx := HOOK_0.x + HOOK_STEP.x * col
				var fy := HOOK_0.y + HOOK_STEP.y * row
				var at := kb_at + Vector3((0.5 - fx) * KEYBOARD_SIZE.x, (0.5 - fy) * KEYBOARD_SIZE.y - 0.12, -0.01)
				var key := K.cutout(root, "motel_key", Vector2(0.075, 0.14), at, 180.0, false, "Key%d" % n)
				out["keys"][n] = key
	# The drinks machine and the plant at the west end, the TV corner and the calendar at the east.
	if _exists("vending_machine"):
		var vm := K.cutout(root, "vending_machine", _sprite_size("vending_machine", 1.8), Vector3(-w * 0.5 + 0.35, 0.0, -0.6), 90.0, false, "Vending")
		out["vending"] = vm
	K.cutout(root, "plastic_plant", _sprite_size("plastic_plant", 0.95), Vector3(-w * 0.5 + 0.4, 0.0, d * 0.5 - 0.45), 0.0, true, "Plant")
	var tv_at := Vector3(w * 0.5 - 0.55, 0.0, -d * 0.5 + 0.75)
	K.slab(root, Vector3(0.6, 0.62, 0.45), tv_at + Vector3(0, 0.31, 0), veneer, "TvStand")
	var tv := K.cutout(root, "staff_tv", Vector2(0.62, 0.465), tv_at + Vector3(0, 0.62, 0), 0.0, true, "TV")
	out["tv"] = {"node": tv, "at": tv_at + Vector3(0, 0.62, 0)}
	if _exists("calendar"):
		_quad(root, "calendar", Vector2(0.36, 0.48), Vector3(w * 0.5 - 0.004, 1.55, 0.4), Vector3(-1, 0, 0), "Calendar")
	# The flypaper over the counter black with flies, the zapper's blue tube on the wall.
	if _exists("flypaper"):
		K.cutout(root, "flypaper", _sprite_size("flypaper", 0.62), Vector3(cx - 0.2, h - 0.64, 0.2), 0.0, true, "Flypaper")
	if _exists("fly_zapper"):
		var z := K.cutout(root, "fly_zapper", _sprite_size("fly_zapper", 0.32), Vector3(w * 0.5 - 0.02, 1.9, -0.6), -90.0, false, "Zapper")
		out["zapper"] = z
	decal(root, "carpet_stain", Vector2(0.8, 0.55), Vector3(door.x + 0.2, 0.0, -0.9), Vector3.UP, 0.8, "CarpetStain")
	decal(root, "roach_dead", Vector2(0.06, 0.06), Vector3(-w * 0.5 + 0.7, 0.0, 0.1), Vector3.UP, 2.0, "DeadRoach")
	# The door to his room at the back, west of the board; the door to the corridor past the
	# counter's east end.
	_quad(root, "door_interior", Vector2(0.85, 2.0), Vector3(cx - 1.3, 1.0, d * 0.5 - 0.006), Vector3(0, 0, -1), "BackDoor")
	out["hall_door"] = _quad(root, "door_interior", Vector2(0.9, 2.05), Vector3(PLAN.LOBBY_HALL_X, 1.025, d * 0.5 - 0.006), Vector3(0, 0, -1), "HallDoor")
	if inside:
		var leaf := K.slab(root, Vector3(0.9, PLAN.DOOR_H, 0.05), Vector3(door.x, PLAN.DOOR_H * 0.5, -d * 0.5 - 0.02), K.surface("galvanized", 0.5, Color(0.7, 0.72, 0.7)), "DoorLeaf")
		out["door"] = leaf
		if ResourceLoader.exists("res://assets/textury/town/motel_lobby_door.png"):
			var m := K._base(Color(1, 1, 1))
			m.albedo_texture = load("res://assets/textury/town/motel_lobby_door.png")
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.9, PLAN.DOOR_H)
			q.mesh = qm
			q.material_override = m
			q.position = Vector3(door.x, PLAN.DOOR_H * 0.5, -d * 0.5 + 0.007)
			q.name = "DoorInside"
			root.add_child(q)
	return out
