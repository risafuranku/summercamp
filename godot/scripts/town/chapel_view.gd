extends RefCounted

## Inside the chapel of the Virgin Mary in Liblice (town_room.gd's place "chapel"), built
## to its baroque front (town_lesna._chapel: 6 m across, 7 m deep, the oval windows in
## its sides): the whitewashed nave under its vault, two blocks of pews with carved ends,
## the presbytery a step up behind its communion rail, the altar (its retable on the back
## wall, its table standing before it), St Prokop on his console, the harmonium in the
## corner, the Stations of the Cross between the windows, the bell's rope by the door,
## the stoup, the box for the coins, the stand of votive candles.
##
##   the candles  a coin and a match: one more flame on the stand (they stay lit while you
##                are in Liblice; the other wardens' too, and theirs for you: co-op);
##   the rope     the bell rings over the village, now and then;
##   Mrs Hruba    kneels in the second pew from four to six (town_people.gd has her
##                indoors then), and talks quietly;
##   the rest     looked at closer: the eye goes to it, a click lets it go.
## Nobody narrates.

const K = preload("res://scripts/interior_kit.gd")
const SFX := "res://assets/sfx/"
const CAMP := "res://assets/textury/camp/"
## The nave inside (the walls 0.45 thick in the 6.08 x 7 building): x across, z from the
## altar (-) to the door (+); the vault from the walls' top to its crown.
const W := 5.2
const D := 6.1
const WALL_H := 3.4
const CROWN := 4.55
const STEP := 0.18
const PRESBYTERY_Z := -1.3
## The rows of pews (their seats' middle), the aisle's half width, the pews' length.
const ROWS := [-0.6, 0.35, 1.3]
const AISLE := 0.4
const PEW_L := 2.05
## The oval windows in the side walls (their middle along z, their height).
const WINDOWS_Z := [-0.9, 1.4]
const WINDOW_Y := 2.45
## Where you stand, inside the door.
const STAND := Vector3(0.0, 1.6, 2.1)
const HRUBA_LINES := [
	"Sit down if you want. He does not mind who.",
	"I light one for Karel. And one for Vera, though she would not thank me for it.",
	"They used to ring it for the dead. Now they ring it at noon and at six, and nobody is dead.",
	"Your camp had a priest come up once. In seventy-one. He did not stay the night either.",
]

var room
var parts: Dictionary = {}
var flames: Array = []
var cups: Array = []
var _t := 0.0
var _line := 0
var _looking := ""
var _look_back := {}
var _rope: MeshInstance3D
var _rope_t := 0.0
var _hruba: MeshInstance3D


func _init(p_room) -> void:
	room = p_room


func _exists(tex: String) -> bool:
	return ResourceLoader.exists(CAMP + tex + ".png")


func _size(tex: String, height: float) -> Vector2:
	var path := CAMP + tex + ".png"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		return Vector2(height * float(t.get_width()) / float(t.get_height()), height)
	return Vector2(height, height)


# ── building ─────────────────────────────────────────────────────────────────

func build(hour: float, candles: int) -> void:
	var root: Node3D = room._root
	var lime := K.surface("chapel_lime" if _exists("chapel_lime") else "chapel_wall", 2.4, Color(0.97, 0.96, 0.94))
	var stone := K.surface("chapel_floor", 1.4)
	# The floor, the walls up to the vault, the vault in six planks, the ends' lunettes.
	K.slab(root, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), stone, "Floor")
	K.slab(root, Vector3(0.1, WALL_H, D), Vector3(-W * 0.5 - 0.05, WALL_H * 0.5, 0), lime, "WallWest")
	K.slab(root, Vector3(0.1, WALL_H, D), Vector3(W * 0.5 + 0.05, WALL_H * 0.5, 0), lime, "WallEast")
	K.slab(root, Vector3(W, CROWN + 0.1, 0.1), Vector3(0, (CROWN + 0.1) * 0.5, -D * 0.5 - 0.05), lime, "WallBack")
	K.slab(root, Vector3(W, CROWN + 0.1, 0.1), Vector3(0, (CROWN + 0.1) * 0.5, D * 0.5 + 0.05), lime, "WallFront")
	var vault := K.surface("chapel_vault" if _exists("chapel_vault") else "chapel_wall", 2.0)
	var n := 6
	for i in n:
		var a0 := PI * float(i) / float(n)
		var a1 := PI * float(i + 1) / float(n)
		var p0 := Vector2(-cos(a0) * W * 0.5, WALL_H + sin(a0) * (CROWN - WALL_H))
		var p1 := Vector2(-cos(a1) * W * 0.5, WALL_H + sin(a1) * (CROWN - WALL_H))
		var mid := (p0 + p1) * 0.5
		var plank := K.slab(root, Vector3(p0.distance_to(p1) + 0.04, 0.08, D + 0.1), Vector3(mid.x, mid.y + 0.04, 0), vault, "Vault")
		plank.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)
	# The painted plinth round the nave.
	if _exists("chapel_plinth"):
		for side in [-1.0, 1.0]:
			var pl := _quad("chapel_plinth", Vector2(D, 0.85), Vector3(float(side) * (W * 0.5 - 0.004), 0.425, 0), Vector3(-float(side), 0, 0), "Plinth")
			(pl.material_override as StandardMaterial3D).uv1_scale = Vector3(roundf(D / 2.2), 1, 1)
		var pb := _quad("chapel_plinth", Vector2(W, 0.85), Vector3(0, 0.425, D * 0.5 - 0.004), Vector3(0, 0, -1), "Plinth")
		(pb.material_override as StandardMaterial3D).uv1_scale = Vector3(roundf(W / 2.2), 1, 1)
	_presbytery()
	_pews()
	_windows(hour)
	_by_the_door()
	_on_the_walls()
	_light(hour, candles)
	if hour >= 16.0 and hour < 18.0:
		_mrs_hruba()
	room._cam.position = STAND
	room._base_rot = Vector3(deg_to_rad(-3.0), 0.0, 0.0)
	room._look.yaw_limit_deg = 160.0
	room._look.pitch_up_deg = 42.0
	room._look.pitch_down_deg = 30.0
	var door_y := 1.3
	room._hot_box("door", Vector3(0, door_y, D * 0.5 - 0.05), Vector3(1.6, 2.6, 0.12), [])


## A camp texture on a quad facing `facing`, its material its own (to scale its repeat).
func _quad(tex: String, size: Vector2, pos: Vector3, facing: Vector3, name := "Face") -> MeshInstance3D:
	var mi: MeshInstance3D = K.picture(room._root, tex, size, pos, rad_to_deg(atan2(facing.x, facing.z)), name)
	mi.material_override = (mi.material_override as StandardMaterial3D).duplicate()
	return mi


## The step, the rail, the altar's table before its retable, the crucifix, St Prokop.
func _presbytery() -> void:
	var root: Node3D = room._root
	var depth := PRESBYTERY_Z + D * 0.5
	K.slab(root, Vector3(W, STEP, depth), Vector3(0, STEP * 0.5, -D * 0.5 + depth * 0.5), K.surface("chapel_floor", 1.4, Color(0.86, 0.84, 0.8)), "Step")
	if _exists("communion_rail"):
		for side in [-1.0, 1.0]:
			var half := (W * 0.5 - 0.15 - 0.45)
			var rx := float(side) * (0.45 + half * 0.5)
			var rail := K.cutout(root, "communion_rail", Vector2(half, 0.82), Vector3(rx, STEP, PRESBYTERY_Z + 0.04), 0.0, false, "Rail")
			(rail.mesh as QuadMesh).size = Vector2(half, 0.82)
	# The altar: its table standing on the step against the retable on the wall.
	var table := Vector3(2.3, 0.98, 0.72)
	var tpos := Vector3(0, STEP + table.y * 0.5, -D * 0.5 + table.z * 0.5 + 0.02)
	K.slab(root, table, tpos, K.surface("veneer_dark", 0.6), "AltarTable")
	if _exists("chapel_altar_front"):
		_quad("chapel_altar_front", Vector2(table.x + 0.06, table.y), tpos + Vector3(0, 0, table.z * 0.5 + 0.006), Vector3(0, 0, 1), "AltarFront")
	K.slab(root, Vector3(table.x + 0.1, 0.03, table.z + 0.06), tpos + Vector3(0, table.y * 0.5 + 0.015, 0), K.surface("paper_old", 0.4, Color(0.95, 0.93, 0.88)), "AltarCloth")
	var rs := _size("chapel_retable", 2.25) if _exists("chapel_retable") else Vector2(3.2, 2.4)
	var retable := _quad("chapel_retable" if _exists("chapel_retable") else "chapel_altar", rs, Vector3(0, STEP + table.y + rs.y * 0.5, -D * 0.5 + 0.004), Vector3(0, 0, 1), "Retable")
	parts["altar"] = retable
	room._hot_box("altar", Vector3(0, STEP + table.y + 0.9, -D * 0.5 + 0.3), Vector3(rs.x, rs.y, 0.4), [retable])
	K.cutout(root, "crucifix", Vector2(0.4, 0.8), Vector3(1.95, 1.55, -D * 0.5 + 0.02), 0.0, false, "Crucifix")
	# St Prokop on his console on the back wall, west of the altar.
	var con_y := 1.25
	if _exists("wall_console"):
		K.cutout(root, "wall_console", _size("wall_console", 0.3), Vector3(-1.9, con_y - 0.3, -D * 0.5 + 0.03), 0.0, false, "Console")
	var saint := K.cutout(root, "saint_statue", _size("saint_statue", 1.15), Vector3(-1.9, con_y, -D * 0.5 + 0.12), 0.0, false, "Saint")
	room._hot_box("saint", Vector3(-1.9, con_y + 0.55, -D * 0.5 + 0.2), Vector3(0.5, 1.2, 0.3), [saint])
	# The harmonium in the presbytery's east corner, under the crucifix.
	if _exists("harmonium"):
		var hm := K.cutout(root, "harmonium", _size("harmonium", 1.15), Vector3(2.0, STEP, -2.1), 0.0, true, "Harmonium")
		room._hot_box("harmonium", Vector3(2.0, STEP + 0.55, -2.1), Vector3(0.9, 1.1, 0.6), [hm])


## Two blocks of four pews either side of the aisle: seat, back (its back to the door with
## the hymn books' shelf), kneeler, the carved end to the aisle.
func _pews() -> void:
	var root: Node3D = room._root
	var wood := K.surface("pew_wood" if _exists("pew_wood") else "veneer_dark", 0.7, Color(0.92, 0.86, 0.8))
	for z in ROWS:
		for side in [-1.0, 1.0]:
			var cx: float = float(side) * (AISLE + PEW_L * 0.5)
			var zz: float = z
			K.slab(root, Vector3(PEW_L, 0.06, 0.4), Vector3(cx, 0.45, zz), wood, "PewSeat")
			K.slab(root, Vector3(PEW_L, 0.5, 0.05), Vector3(cx, 0.8, zz + 0.2), wood, "PewBack")
			K.slab(root, Vector3(PEW_L, 0.06, 0.06), Vector3(cx, 0.48, zz + 0.2), wood, "PewRail")
			K.slab(root, Vector3(PEW_L, 0.08, 0.12), Vector3(cx, 0.14, zz + 0.48), wood, "Kneeler")
			if _exists("pew_back"):
				_quad("pew_back", Vector2(PEW_L, 0.56), Vector3(cx, 0.78, zz + 0.228), Vector3(0, 0, 1), "PewBackFace")
			# The ends: carved to the aisle, plain against the wall.
			var ax: float = float(side) * AISLE
			K.slab(root, Vector3(0.05, 0.95, 0.62), Vector3(ax, 0.475, zz + 0.08), wood, "PewEnd")
			K.slab(root, Vector3(0.05, 0.95, 0.62), Vector3(float(side) * (AISLE + PEW_L), 0.475, zz + 0.08), wood, "PewEnd")
			if _exists("pew_end"):
				var face := K.picture(root, "pew_end", Vector2(0.62, 0.95), Vector3(ax - float(side) * 0.03, 0.475, zz + 0.08), -90.0 * float(side), "PewEndFace")
				var m := (face.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.5
				face.material_override = m
	room._hot_box("pews", Vector3(-AISLE - PEW_L * 0.5, 0.7, 1.0), Vector3(PEW_L, 0.6, 0.6), [])


## The oval windows, bright with the day, and their light.
func _windows(hour: float) -> void:
	var root: Node3D = room._root
	var day := hour >= 7.0 and hour < 18.5
	for side in [-1.0, 1.0]:
		for wz in WINDOWS_Z:
			var size := _size("chapel_oval", 1.1) if _exists("chapel_oval") else Vector2(0.7, 1.1)
			var win := K.cutout(root, "chapel_oval" if _exists("chapel_oval") else "stained_window", size, Vector3(float(side) * (W * 0.5 - 0.01), WINDOW_Y - size.y * 0.5, float(wz)), -90.0 * float(side), false, "Oval")
			var m := win.material_override as StandardMaterial3D
			m.emission_enabled = true
			m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			m.emission_texture = m.albedo_texture
			m.emission = Color(1.0, 0.96, 0.86)
			m.emission_energy_multiplier = 1.4 if day else 0.15
			if day:
				# Cold daylight through the leaded glass, soft: a whitewashed room evenly lit,
				# not pools of warm light (the walls went blotchy pink in the palette).
				var l := OmniLight3D.new()
				l.light_color = Color(0.96, 0.96, 0.98)
				l.light_energy = 0.32
				l.omni_range = 4.5
				l.position = Vector3(float(side) * 1.6, 2.3, float(wz))
				root.add_child(l)
	room._hot_box("window", Vector3(-W * 0.5 + 0.1, WINDOW_Y, WINDOWS_Z[0]), Vector3(0.2, 1.1, 0.8), [])


## The door from inside, the stoup by it, the box on its post, the votive stand, the rope.
func _by_the_door() -> void:
	var root: Node3D = room._root
	var dz := D * 0.5 - 0.01
	if _exists("chapel_door_in"):
		var ds := _size("chapel_door_in", 2.75)
		K.cutout(root, "chapel_door_in", ds, Vector3(0, 0.0, dz), 180.0, false, "Door")
	else:
		K.picture(root, "door_interior", Vector2(1.2, 2.2), Vector3(0, 1.1, dz), 180.0, "Door")
	if _exists("holy_water"):
		K.cutout(root, "holy_water", _size("holy_water", 0.4), Vector3(1.15, 0.9, dz - 0.02), 180.0, false, "Stoup")
	if _exists("collection_box"):
		var box := K.cutout(root, "collection_box", _size("collection_box", 1.0), Vector3(-1.75, 0.0, 2.35), 0.0, true, "OfferBox")
		room._hot_box("box", Vector3(-1.75, 0.8, 2.35), Vector3(0.4, 0.5, 0.4), [box])
	# The votive candles on the east side, turned to the nave.
	var stand_tex := "votive_stand" if _exists("votive_stand") else "candles_rack"
	var ss := _size(stand_tex, 1.1)
	var sx := W * 0.5 - 0.35
	var sz := 2.05
	var stand := K.cutout(root, stand_tex, ss, Vector3(sx, 0.0, sz), -90.0, false, "Votive")
	parts["stand"] = {"node": stand, "size": ss, "at": Vector3(sx, 0.0, sz)}
	room._hot_box("candles", Vector3(sx, 0.75, sz), Vector3(0.4, 0.7, ss.x), [stand])
	cups = _cup_spots(stand_tex, ss, Vector3(sx, 0.0, sz))
	# The bell's rope down from the vault by the door, its grip within reach.
	var rope_tex := "bell_rope" if _exists("bell_rope") else ""
	if rope_tex != "":
		var rs := _size(rope_tex, 3.3)
		_rope = K.cutout(root, rope_tex, rs, Vector3(-1.05, CROWN - 3.3 - 0.05, 2.8), 0.0, true, "Rope")
		room._hot_box("rope", Vector3(-1.05, 1.4, 2.8), Vector3(0.3, 1.2, 0.3), [_rope])


## The cups of the stand (its picture's red glass, found once), as spots in the room for
## the flames: in the top half of the picture the two rows with the most runs of red (its
## two tiers), each run a cup. The stand faces -X (yaw -90): the picture's left edge is
## towards +Z.
func _cup_spots(tex: String, size: Vector2, at: Vector3) -> Array:
	var out: Array = []
	var path := CAMP + tex + ".png"
	if not ResourceLoader.exists(path):
		return out
	var img: Image = (load(path) as Texture2D).get_image()
	if img == null:
		return out
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var best := [[-1, []], [-1, []]]
	for ry in int(h * 0.5):
		var runs: Array = []
		var run_start := -1
		for x in w + 1:
			var red := false
			if x < w:
				var c := img.get_pixel(x, ry)
				red = c.a > 0.5 and c.r > c.g * 1.5 and c.r > c.b * 1.4 and c.r > 0.3
			if red and run_start < 0:
				run_start = x
			elif not red and run_start >= 0:
				if x - run_start >= 1:
					runs.append((float(run_start + x) * 0.5) / float(w))
				run_start = -1
		# The upper tier in the top fifth of the picture, the lower one below it.
		var tier := 0 if ry < int(h * 0.2) else 1
		if runs.size() > (best[tier][1] as Array).size():
			best[tier] = [ry, runs]
	for b in best:
		var ry: int = b[0]
		if ry < 0:
			continue
		for u in b[1]:
			var v := float(ry) / float(h)
			out.append(at + Vector3(-0.03, (1.0 - v) * size.y + 0.02, (0.5 - float(u)) * size.x))
	return out


## The Stations of the Cross between the windows, three each side.
func _on_the_walls() -> void:
	var root: Node3D = room._root
	var spots := [-0.15, 0.6, 2.2]
	var i := 1
	for side in [-1.0, 1.0]:
		for z in spots:
			var tex := "station_%d" % i
			if _exists(tex):
				var st := K.cutout(root, tex, _size(tex, 0.42), Vector3(float(side) * (W * 0.5 - 0.02), 1.5, float(z)), -90.0 * float(side), false, "Station")
				if i == 1:
					room._hot_box("stations", Vector3(float(side) * (W * 0.5 - 0.05), 1.7, float(z)), Vector3(0.1, 0.45, 0.4), [st])
			i += 1


# ── light ────────────────────────────────────────────────────────────────────

func _light(hour: float, candles: int) -> void:
	var env: Environment = room._env
	var day := hour >= 7.0 and hour < 18.5
	env.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.ambient_light_energy = 0.52 if day else 0.1
	for i in candles:
		add_flame()


## One more flame on the stand, at the next empty cup (a small light with it).
func add_flame() -> bool:
	if flames.size() >= maxi(1, cups.size()):
		return false
	var root: Node3D = room._root
	var at: Vector3 = cups[flames.size()] if flames.size() < cups.size() else Vector3(W * 0.5 - 0.4, 1.0, 2.05)
	var tex := "votive_flame_0"
	var f := K.cutout(root, tex if _exists(tex) else "candles_rack", Vector2(0.05, 0.08), at, 0.0, true, "Flame")
	var m := f.material_override as StandardMaterial3D
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	f.set_meta("retro_skip", true)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.68, 0.34)
	l.light_energy = 0.22
	l.omni_range = 2.2
	l.position = at + Vector3(-0.15, 0.1, 0)
	root.add_child(l)
	flames.append({"node": f, "light": l, "phase": randf() * 4.0})
	return true


## Mrs Hruba on her knees in the second pew on the left, her back to you.
func _mrs_hruba() -> void:
	var path := "res://assets/textury/npc/town_hruba_kneel.png"
	if not ResourceLoader.exists(path):
		return
	var t: Texture2D = load(path)
	var h := 1.05
	var size := Vector2(h * float(t.get_width()) / float(t.get_height()), h)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0, h * 0.5, 0)
	mi.mesh = q
	var m := K._base(Color(1, 1, 1))
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	var z: float = ROWS[0] + 0.62
	mi.position = Vector3(-AISLE - 0.7, 0.05, z)
	mi.name = "MrsHruba"
	room._root.add_child(mi)
	_hruba = mi
	room._hot_box("her", mi.position + Vector3(0, 0.55, 0), Vector3(0.5, 1.0, 0.5), [mi])


# ── each frame ───────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_t += delta
	var step := floorf(_t * 12.0)
	for i in flames.size():
		var f: Dictionary = flames[i]
		var node: MeshInstance3D = f["node"]
		if not is_instance_valid(node):
			continue
		var k := int(step + float(f["phase"]) * 3.0) % 4
		var tex := CAMP + "votive_flame_%d.png" % k
		if ResourceLoader.exists(tex):
			(node.material_override as StandardMaterial3D).albedo_texture = load(tex)
		(f["light"] as OmniLight3D).light_energy = 0.18 + 0.06 * float(k % 2)
	if _rope != null and _rope_t > 0.0:
		_rope_t -= delta
		# The rope jerks up and down with the strokes, in steps.
		var swing := sin(floorf(_rope_t * 12.0) / 12.0 * 9.0) * 0.12
		_rope.position.y = CROWN - 3.35 + swing


# ── clicks ───────────────────────────────────────────────────────────────────

func click(id: String, hour: float) -> bool:
	if _looking != "":
		_unlook()
		return true
	match id:
		"candles":
			if CoreRoot.get_money() < 1 or not CoreRoot.actions.spend_money(1):
				_play("director/knock_wrong.mp3", -14.0)
				return true
			_play("chapel/coin_box.mp3", -6.0)
			if add_flame():
				room._candles = flames.size()
				room.get_tree().create_timer(0.45).timeout.connect(func(): _play("chapel/match.mp3", -6.0))
				if room.has_signal("candle_lit"):
					room.candle_lit.emit(flames.size())
		"box":
			if CoreRoot.get_money() >= 1 and CoreRoot.actions.spend_money(1):
				_play("chapel/coin_box.mp3", -4.0)
		"rope":
			_ring()
		"her":
			_line += 1
			room.say("Mrs Hruba", HRUBA_LINES[_line % HRUBA_LINES.size()])
		"harmonium":
			_play("chapel/harmonium.mp3", -8.0)
			_look_at("harmonium")
		"pews":
			_play("chapel/pew_creak.mp3", -8.0)
			_look_at(id)
		"altar", "saint", "stations", "window":
			_look_at(id)
		_:
			return false
	return true


func _ring() -> void:
	if _rope_t > 0.0:
		return
	_rope_t = 2.4
	room.wants_closeup.emit("bell")


## The eye goes to the thing (narrower, turned to it); any click lets it go.
func _look_at(id: String) -> void:
	var body = room._hot.get(id, {}).get("body")
	if body == null:
		return
	var target: Vector3 = (body as Node3D).position
	var eye: Vector3 = room._cam.position
	var d := target - eye
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	_looking = id
	_look_back = {"rot": room._base_rot, "fov": room._cam.fov}
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room, "_base_rot", Vector3(pitch, yaw, 0.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room._cam, "fov", clampf(66.0 * 1.6 / maxf(1.6, d.length()), 22.0, 44.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _unlook() -> void:
	_looking = ""
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room, "_base_rot", _look_back.get("rot", Vector3.ZERO), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room._cam, "fov", float(_look_back.get("fov", 66.0)), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## S or the door: looking at something, let it go first.
func wants_out() -> bool:
	if _looking != "":
		_unlook()
		return false
	return true


func place_mates(mates: Dictionary, ids: Array) -> void:
	var k := 0
	for id in ids:
		var fig = mates.get(int(id))
		if fig == null:
			continue
		fig.visible = true
		fig.show_at(Vector3(0.05 if k % 2 == 0 else -0.05, 0.0, 1.35 - 0.7 * float(k)), "stand")
		k += 1


func close() -> void:
	if _looking != "":
		room._cam.fov = float(_look_back.get("fov", 66.0))
	_looking = ""


func _play(path: String, db: float) -> void:
	room._play(SFX + path, db)
