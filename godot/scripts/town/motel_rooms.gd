extends RefCounted

## The motel's rooms (motel_plan.gd), built the same for the room you stand in (town_room.gd
## draws it in its own world, things to click in it) and for the rooms seen through the
## windows from the car park (motel_block.gd, in the village: no clicks, no street wall,
## the facade is theirs). Build boxes with Grok faces (tools/artgen/prompts_mesto.tsv).
##
## A room: the striped wallpaper, the headboard wall (face_motel4_wall) with its two lamps
## over two single beds pushed together, the wardrobe by the door, the basin with its
## mirror, the radiator under the window, the table with the TV in the corner, the lamp on
## the ceiling. The reception: the counter across it with Simek behind, the key board
## with a key on the hook of every free room, the drinks machine, the plant, the corner
## with the television and the calendar.

const PLAN = preload("res://scripts/town/motel_plan.gd")
const K = preload("res://scripts/interior_kit.gd")
const CAMP := "res://assets/textury/camp/"
## The TV's screen in its picture (camp/cv_tv.png, 37 x 48): left, top, right, bottom.
const TV_SCREEN := Rect2(6.0 / 37.0, 17.0 / 48.0, 25.0 / 37.0, 17.0 / 48.0)
const TV_SIZE := Vector2(0.46, 0.6)
## The key board's hooks in its picture (camp/motel_keyboard.png): the first hook of the two
## rows and the step between them, as fractions of the picture.
const HOOK_0 := Vector2(0.097, 0.27)
const HOOK_STEP := Vector2(0.1594, 0.39)
const KEYBOARD_SIZE := Vector2(1.3, 0.73)


static func _exists(tex: String) -> bool:
	return ResourceLoader.exists(CAMP + tex + ".png")


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


# ── a guest room ─────────────────────────────────────────────────────────────

## Room `n` under `root` (room space). `inside`: the room you stand in (the street wall with
## its door and window, the things to click through `host`, town_room.gd); else the shell
## behind a window in the village. `state`: {"lit": the lamps on, "made": the beds made,
## "curtain": 0 drawn .. 1 open (the shell's), "taken": somebody's things}. Returns what
## changes later: {"lamps": [materials of the lamp shades], "lights": [OmniLight3D],
## "tv": {"screen": MeshInstance3D}, "key": Node3D, "door": MeshInstance3D}.
static func build_room(root: Node3D, n: int, inside: bool, state: Dictionary = {}, host = null) -> Dictionary:
	var out := {"lamps": [], "lights": [], "tv": {}, "key": null, "door": null, "curtains": []}
	var w := PLAN.ROOM_W
	var d := PLAN.ROOM_D
	var h := PLAN.ROOM_H
	var lit := bool(state.get("lit", false)) and not inside
	var wall := K.surface("motel_wall", 1.4)
	var carpet := K.surface("motel_carpet", 1.6)
	var ceil := K.surface("ceiling_board", 1.0)
	# Floor, ceiling, the back wall, the side walls (the partitions); the street wall only
	# inside (outside it is the facade's).
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), _shell_mat(carpet, lit), "Floor")
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, h + 0.05, 0), _shell_mat(ceil, lit), "Ceiling")
	K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, d * 0.5 + 0.05), _shell_mat(wall, lit), "WallBack")
	K.slab(root, Vector3(0.1, h, d), Vector3(-w * 0.5 - 0.05, h * 0.5, 0), _shell_mat(wall, lit), "WallWest")
	K.slab(root, Vector3(0.1, h, d), Vector3(w * 0.5 + 0.05, h * 0.5, 0), _shell_mat(wall, lit), "WallEast")
	var door := PLAN.room_door(n)
	var win: Vector3 = PLAN.room_windows(n)[0]
	var ws := PLAN.window_size()
	if inside:
		var front := K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, -d * 0.5 - 0.05), wall, "WallFront")
		K.cut_wall(front, [
			[door.x - 0.45, door.x + 0.45, 0.0, PLAN.DOOR_H],
			[win.x - ws.x * 0.5, win.x + ws.x * 0.5, PLAN.WIN_Y.x, PLAN.WIN_Y.y],
		])
		K.skirting(root, Vector3(w, h, d), "planks_dark")
	# The headboard wall: its picture on the back wall, a picture rail along its top.
	if _exists("motel4_wall"):
		var hw_h := w * 9.0 / 16.0
		var hw := _quad(root, "motel4_wall", Vector2(w, hw_h), Vector3(0, PLAN.HEADWALL_Y + hw_h * 0.5, d * 0.5 - 0.004), Vector3(0, 0, -1), "Headwall")
		hw.material_override = _shell_mat(hw.material_override, lit)
		K.slab(root, Vector3(w, 0.04, 0.03), Vector3(0, PLAN.HEADWALL_Y + hw_h + 0.02, d * 0.5 - 0.015), _shell_mat(K.surface("veneer_dark", 0.5), lit), "PictureRail")
		# Its two lamps' shades, lit at night: a glow over each (the shades in the picture
		# are at about a seventh and six sevenths across, a little over the board).
		for sx in [-0.345, 0.345]:
			var shade := _glow_patch(root, Vector3(sx * w, PLAN.HEADWALL_Y + hw_h * 0.46, d * 0.5 - 0.008), Vector2(0.17, 0.13))
			out["lamps"].append(shade)
			shade.visible = lit or bool(state.get("lit", false))
	# The two beds: veneer frames, the bedspread over the mattresses, the pillows.
	var spread := K.surface("motel_bedspread", 0.7) if _exists("motel_bedspread") else K.surface("blanket_check", 0.7)
	var frame := K.surface("veneer_dark", 0.6)
	for i in PLAN.BED_X.size():
		var bx: float = PLAN.BED_X[i]
		var bs := PLAN.BED_SIZE
		K.slab(root, Vector3(bs.x, 0.3, bs.z), Vector3(bx, 0.15, PLAN.BED_Z), _shell_mat(frame, lit), "BedFrame")
		var top := K.slab(root, Vector3(bs.x + 0.04, 0.2, bs.z + 0.02), Vector3(bx, 0.4, PLAN.BED_Z - 0.01), _shell_mat(spread, lit), "Bedspread")
		top.set_meta("bed", i)
		# The pillow under the spread at the head: made, a rounded hump of the same cloth;
		# slept in, the spread thrown back and the pillow out on top of it.
		if bool(state.get("made", true)):
			var hump := K.slab(root, Vector3(bs.x + 0.02, 0.12, 0.42), Vector3(bx, 0.55, d * 0.5 - 0.27), _shell_mat(spread, lit), "PillowHump")
			hump.rotation.x = -0.12
		else:
			var pillow := K.slab(root, Vector3(0.6, 0.12, 0.34), Vector3(bx + 0.05, 0.56, d * 0.5 - 0.3), _shell_mat(K.surface("mattress", 0.5, Color(0.96, 0.93, 0.86)), lit), "Pillow")
			pillow.rotation = Vector3(-0.2, 0.15, 0.0)
	# The wardrobe built in by the door, shallow: a veneer box, its doors' picture to the room.
	var wd := Vector3(0.42, 1.9, 1.0)
	var wpos := Vector3(-w * 0.5 + wd.x * 0.5, wd.y * 0.5, PLAN.WARDROBE_Z)
	K.slab(root, wd, wpos, _shell_mat(K.surface("veneer_dark", 0.6), lit), "Wardrobe")
	if _exists("motel_wardrobe"):
		var wf := _quad(root, "motel_wardrobe", Vector2(wd.z, wd.y), wpos + Vector3(wd.x * 0.5 + 0.006, 0, 0), Vector3(1, 0, 0), "WardrobeFront")
		wf.material_override = _shell_mat(wf.material_override, lit)
	# The basin and its mirror on the east wall, between the corner table and the bed.
	if _exists("motel_basin"):
		var basin := K.cutout(root, "motel_basin", _sprite_size("motel_basin", 1.45), Vector3(w * 0.5 - 0.02, 0.62, -0.62), -90.0, false, "Basin")
		basin.material_override = _shell_mat(basin.material_override, lit)
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
	# The lamp on the ceiling.
	var cl := K.cutout(root, "ceiling_lamp", Vector2(0.42, 0.42), Vector3(0, h - 0.43, 0.2), 0.0, true, "CeilingLamp")
	cl.material_override = _shell_mat(cl.material_override, lit)
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
		return out
	# Inside: the door's leaf in its frame (its inside to the room), the key's place in its
	# lock; the lights; the things to click.
	var leaf := K.slab(root, Vector3(0.9, PLAN.DOOR_H, 0.05), Vector3(door.x, PLAN.DOOR_H * 0.5, -d * 0.5 - 0.02), K.surface("veneer_dark", 0.6), "DoorLeaf")
	out["door"] = leaf
	if _exists("motel_door_in"):
		_quad(root, "motel_door_in", Vector2(0.9, PLAN.DOOR_H), Vector3(door.x, PLAN.DOOR_H * 0.5, -d * 0.5 + 0.007), Vector3(0, 0, 1), "DoorInside")
	if _exists("motel_key"):
		# In the keyhole under the handle (the door's picture: its lock at a seventh across,
		# two thirds down), the tag hanging from it.
		var key := K.cutout(root, "motel_key", Vector2(0.075, 0.2), Vector3(door.x - 0.32, 0.5, -d * 0.5 + 0.03), 0.0, false, "KeyInLock")
		out["key"] = key
	return out


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
	var wall := K.surface("motel_wall", 1.4)
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), _shell_mat(K.surface("motel_carpet", 1.6), lit), "Floor")
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, h + 0.05, 0), _shell_mat(K.surface("ceiling_board", 1.0), lit), "Ceiling")
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
	out["simek"] = Vector3(cx + 0.25, 0.0, 1.35)
	# On the counter: the bell, the guest book, the ashtray, his lamp.
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
	if _exists("motel_ashtray"):
		K.cutout(root, "motel_ashtray", _sprite_size("motel_ashtray", 0.07), Vector3(cx + 0.45, top_y, 0.62), 0.0, true, "Ashtray")
	var lamp := K.cutout(root, "desk_lamp", Vector2(0.3, 0.31), Vector3(cx - 1.05, top_y, 0.7), 0.0, true, "DeskLamp")
	lamp.material_override = _shell_mat(lamp.material_override, lit)
	out["lamp"] = lamp
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
	# The door to his room at the back, west of the board.
	_quad(root, "door_interior", Vector2(0.85, 2.0), Vector3(cx - 1.3, 1.0, d * 0.5 - 0.006), Vector3(0, 0, -1), "BackDoor")
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
