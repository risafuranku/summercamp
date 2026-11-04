extends RefCounted

## The pub U Jezera in Liblice (town_lesna._pub outside, town_room.gd's place "pub"
## inside), built to its front: the old inn's eleven and a half metres with four windows
## and the wooden double door between them (lib_pub_front.png). The windows are real
## holes now (`lib_pub_front_glass.png`, mesto_art.py): behind the glass the taproom, the
## same room you stand in: tables under their lamps by the windows, the bar across the
## back with Mr Kubat and the back bar behind him, the regulars, the LUCKY 7 on the east
## wall, the dartboard, smoke in the air. Lit from ten till eleven at night. Inside, the
## windows look out at the street and the Jednota's corner (window_portal.gd).
##
## Room space: the middle of the taproom's floor, x east, z towards the street.

const K = preload("res://scripts/interior_kit.gd")
const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
const WALL_CLOCK = preload("res://scripts/town/wall_clock.gd")
const CAMP := "res://assets/textury/camp/"
const W := 11.5
const H := 5.344
const PX_M := 32.0
const DEPTH := 10.0
## The four windows in the picture (px: x0, y0, x1, y1; lib_facades.json's own rectangles).
const PANES := [[22, 83, 58, 127], [93, 83, 129, 127], [237, 83, 273, 127], [308, 83, 344, 127]]
## The taproom's floor over the street, the room inside.
const FLOOR_Y := 0.25
const ROOM := Vector3(11.1, 3.2, 6.4)
const STAND := Vector3(0.0, 1.6, 1.7)
const TABLES := [Vector3(-4.45, 0, 1.75), Vector3(-2.25, 0, 1.75), Vector3(2.2, 0, 1.75), Vector3(4.4, 0, 1.75)]


static func origin() -> Vector3:
	return Vector3(0.0, FLOOR_Y, DEPTH * 0.5 - 0.15 - ROOM.z * 0.5)


static func pane(r: Array) -> Dictionary:
	var x0 := float(r[0]) / PX_M - W * 0.5
	var x1 := float(r[2]) / PX_M - W * 0.5
	var top := H - float(r[1]) / PX_M
	var bottom := H - float(r[3]) / PX_M
	return {"at": Vector3((x0 + x1) * 0.5, (top + bottom) * 0.5 - FLOOR_Y, ROOM.z * 0.5), "size": Vector2(x1 - x0, top - bottom)}


static func _lit(m: Material, lit: bool) -> Material:
	if not lit or m == null:
		return m
	var s := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	s.emission_enabled = true
	s.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	if s.albedo_texture != null:
		s.emission_texture = s.albedo_texture
	s.emission = Color(1.0, 0.76, 0.48)
	s.emission_energy_multiplier = 0.55
	return s


static func _quad(root: Node3D, tex: String, size: Vector2, pos: Vector3, yaw: float, lit: bool, name := "Face") -> MeshInstance3D:
	var q := K.picture(root, tex, size, pos, yaw, name)
	q.material_override = _lit(q.material_override, lit)
	return q


static func _cut(root: Node3D, tex: String, size: Vector2, pos: Vector3, yaw: float, bill: bool, lit: bool, name := "Cutout") -> MeshInstance3D:
	var c := K.cutout(root, tex, size, pos, yaw, bill, name)
	c.material_override = _lit(c.material_override, lit)
	return c


## The taproom under `root` (room space); `room` (town_room.gd) when you stand in it, else
## the room behind the glass in the village (`lit` while the pub is open).
static func build(root: Node3D, room = null, lit := false) -> Dictionary:
	var out := {}
	var inside: bool = room != null
	var l := lit and not inside
	var w := ROOM.x
	var d := ROOM.z
	var h := ROOM.y
	var wall := K.surface("pub_wall", 1.6)
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), _lit(K.surface("pub_floor", 1.6), l), "Floor")
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, h + 0.05, 0), _lit(K.surface("ceiling_pine", 1.0), l), "Ceiling")
	K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, -d * 0.5 - 0.05), _lit(wall, l), "WallBack")
	K.slab(root, Vector3(0.1, h, d), Vector3(-w * 0.5 - 0.05, h * 0.5, 0), _lit(wall, l), "WallWest")
	K.slab(root, Vector3(0.1, h, d), Vector3(w * 0.5 + 0.05, h * 0.5, 0), _lit(wall, l), "WallEast")
	var wain := _lit(K.surface("pub_wainscot", 1.0), l)
	K.slab(root, Vector3(w, 1.1, 0.04), Vector3(0, 0.55, -d * 0.5 + 0.02), wain, "WainBack")
	K.slab(root, Vector3(0.04, 1.1, d), Vector3(-w * 0.5 + 0.02, 0.55, 0), wain, "WainW")
	K.slab(root, Vector3(0.04, 1.1, d), Vector3(w * 0.5 - 0.02, 0.55, 0), wain, "WainE")
	if inside:
		var front := K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, d * 0.5 + 0.05), wall, "WallFront")
		var holes: Array = []
		for r in PANES:
			var p := pane(r)
			var at: Vector3 = p["at"]
			var sz: Vector2 = p["size"]
			holes.append([at.x - sz.x * 0.5, at.x + sz.x * 0.5, at.y - sz.y * 0.5, at.y + sz.y * 0.5])
		K.cut_wall(front, holes)
		# The wainscot along the front, under the windows.
		K.slab(root, Vector3(w, 1.1, 0.04), Vector3(0, 0.55, d * 0.5 - 0.02), wain, "WainFront")
	# The bar across the back, the taps, the back bar, Mr Kubat.
	var bar := Vector3(4.0, 1.05, 0.6)
	var bpos := Vector3(0.5, 0.525, -1.4)
	K.slab(root, bar, bpos, _lit(K.surface("pub_wainscot", 0.8), l), "Bar")
	_quad(root, "pub_bar", Vector2(bar.x, bar.y), bpos + Vector3(0, 0, bar.z * 0.5 + 0.005), 0.0, l, "BarFront")
	K.slab(root, Vector3(bar.x + 0.1, 0.06, bar.z + 0.12), bpos + Vector3(0, bar.y * 0.5 + 0.03, 0), _lit(K.surface("veneer_dark", 0.6), l), "BarTop")
	var top := bar.y + 0.06
	var taps := _cut(root, "pub_taps", Vector2(0.5, 0.42), Vector3(1.4, top, -1.5), 0.0, false, l, "Taps")
	K.slab(root, Vector3(4.4, 1.7, 0.35), Vector3(0.5, 1.6, -d * 0.5 + 0.18), _lit(K.surface("pub_wainscot", 0.8), l), "BackBar")
	_quad(root, "pub_backbar", Vector2(4.3, 1.6), Vector3(0.5, 1.6, -d * 0.5 + 0.36), 0.0, l, "BackBarFace")
	_cut(root, "ashtray", Vector2(0.16, 0.16), Vector3(-0.3, top, -1.2), 0.0, true, l, "Ashtray")
	# The LUCKY 7 on the east wall, its lights.
	K.slab(root, Vector3(0.55, 1.75, 0.7), Vector3(w * 0.5 - 0.3, 0.875, -0.6), K.surface("galvanized", 0.5, Color(0.3, 0.25, 0.3)), "Machine")
	var mface := K.picture(root, "fruit_machine", Vector2(0.68, 1.72), Vector3(w * 0.5 - 0.58, 0.875, -0.6), -90.0, "MachineFace")
	var mm := mface.material_override as StandardMaterial3D
	mm.emission_enabled = true
	mm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mm.emission_texture = mm.albedo_texture
	mm.emission = Color(1.0, 0.85, 0.7)
	mm.emission_energy_multiplier = 0.6 if (inside or l) else 0.0
	# The tables by the windows, checked cloths, chairs, an ashtray, a lamp over each.
	var cloth := _lit(K.surface("tablecloth", 0.5), l)
	var wood := _lit(K.surface("veneer_dark", 0.6), l)
	var lamps: Array = []
	for t in TABLES:
		var tz: float = (t as Vector3).z
		var tx: float = (t as Vector3).x
		K.slab(root, Vector3(1.0, 0.04, 0.8), Vector3(tx, 0.76, tz), cloth, "Table")
		K.slab(root, Vector3(0.08, 0.74, 0.08), Vector3(tx, 0.37, tz), wood, "TableLeg")
		for cx in [-0.75, 0.75]:
			K.slab(root, Vector3(0.42, 0.05, 0.42), Vector3(tx + float(cx), 0.46, tz), wood, "Seat")
			K.slab(root, Vector3(0.05, 0.5, 0.42), Vector3(tx + float(cx) * 1.24, 0.72, tz), wood, "SeatBack")
		_cut(root, "ashtray", Vector2(0.14, 0.14), Vector3(tx + 0.1, 0.78, tz + 0.1), 0.0, true, l, "TableAshtray")
		lamps.append(Vector3(tx, 2.4, tz))
	# The walls: antlers and the brewery sign west, the dartboard east, the clock.
	_cut(root, "antlers", Vector2(0.5, 0.5), Vector3(-w * 0.5 + 0.03, 1.75, -0.3), 90.0, false, l, "Antlers")
	_quad(root, "pub_sign", Vector2(0.8, 0.6), Vector3(-w * 0.5 + 0.025, 1.75, -1.8), 90.0, l, "BrewerySign")
	_cut(root, "dartboard", Vector2(0.5, 0.5), Vector3(w * 0.5 - 0.03, 1.45, 1.4), -90.0, false, l, "Dartboard")
	if inside:
		# Inside it keeps the time (wall_clock.gd).
		var clock = WALL_CLOCK.new()
		clock.make(root, Vector3(-1.9, 2.26, -d * 0.5 + 0.02), 0.0, 0.32)
		out["clock"] = clock
	else:
		_cut(root, "wall_clock", Vector2(0.32, 0.32), Vector3(-1.9, 2.1, -d * 0.5 + 0.02), 0.0, false, l, "Clock")
	var door := _quad(root, "door_interior", Vector2(1.6, 2.2), Vector3(0.0, 1.1, d * 0.5 - 0.005), 180.0, false, "Door")
	# By the door the coat stand and a jacket and cap on a hook; fly paper over a table.
	_cut(root, "bistro_coatstand", Vector2(0.65, 1.7), Vector3(1.25, 0.0, d * 0.5 - 0.35), 180.0, true, l, "CoatStand")
	_cut(root, "coat_hook", Vector2(0.45, 0.67), Vector3(-1.25, 1.0, d * 0.5 - 0.03), 180.0, false, l, "Coat")
	_cut(root, "flypaper", Vector2(0.09, 0.24), Vector3(TABLES[2].x, h - 0.25, TABLES[2].z), 0.0, true, l, "FlyPaper")
	if not inside:
		if l:
			for lp in lamps:
				var s := K.cutout(root, "pub_lamp", Vector2(0.42, 0.42), (lp as Vector3) - Vector3(0, 0.2, 0), 0.0, true, "Lamp")
				var sm := s.material_override as StandardMaterial3D
				sm.emission_enabled = true
				sm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				sm.emission_texture = sm.albedo_texture
				sm.emission = Color(1.0, 0.8, 0.5)
				sm.emission_energy_multiplier = 0.9
			# Mr Kubat at his taps, the regulars, seen through the glass.
			for who in [["town_landlord", Vector3(0.3, 0.0, -2.1), 1.7], ["regular_track", Vector3(-1.9, 0.0, -0.85), 1.75], ["regular_cap", Vector3(TABLES[1].x - 0.15, 0.0, TABLES[1].z), 1.45]]:
				var path: String = ("res://assets/textury/npc/%s.png" if who[0] == "town_landlord" else CAMP + "%s.png") % who[0]
				if ResourceLoader.exists(path):
					var tex: Texture2D = load(path)
					var sp := Sprite3D.new()
					sp.texture = tex
					sp.pixel_size = float(who[2]) / float(tex.get_height())
					sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
					sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
					sp.offset = Vector2(0, tex.get_height() * 0.5)
					sp.position = who[1]
					root.add_child(sp)
		for g in root.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return out
	# Inside: the lamps lit, the people, what you click, where you stand.
	for lp in lamps:
		room._hang_lamp(lp)
	room._hang_lamp(Vector3(0.5, 2.5, -1.4))
	room._hot_box("tap", Vector3(1.4, top + 0.2, -1.5), Vector3(0.5, 0.4, 0.3), [taps])
	room._npc_sprite("town_landlord", 1.7, Vector3(0.3, 0.0, -2.1), "him")
	room._mug_tex = {"full": load(K.TEX + "mug_full.png") if ResourceLoader.exists(K.TEX + "mug_full.png") else null,
		"empty": load(K.TEX + "mug_empty.png") if ResourceLoader.exists(K.TEX + "mug_empty.png") else null}
	room._mug_node = K.cutout(root, "mug_full", Vector2(0.2, 0.2), Vector3(0.35, top, -1.2), 0.0, true, "Mug")
	room._mug_node.visible = false
	room._hot_box("mug", Vector3(0.35, top + 0.1, -1.2), Vector3(0.26, 0.24, 0.24), [room._mug_node])
	room._regular("regular_track", Vector2(0.95, 1.75), Vector3(-1.9, 0.0, -0.85), "track")
	room._regular("regular_cap", Vector2(1.1, 1.45), Vector3(TABLES[1].x - 0.15, 0.0, TABLES[1].z), "cap")
	room._hot_box("machine", Vector3(w * 0.5 - 0.6, 0.9, -0.6), Vector3(0.2, 1.75, 0.7), [mface])
	room._omni(Vector3(w * 0.5 - 1.0, 1.5, -0.6), Color(1.0, 0.5, 0.6), 0.35, 2.0)
	room._hot_box("door", Vector3(0.0, 1.1, d * 0.5 - 0.05), Vector3(1.6, 2.2, 0.12), [door])
	room._light_profile(true)
	var env: Environment = room._env
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.42, 0.32)
	env.fog_density = 0.035
	room._cam.position = STAND
	room._base_rot = Vector3(deg_to_rad(-6.0), 0.0, 0.0)
	room._look.yaw_limit_deg = 150.0
	return out


# ── the room you stand in ────────────────────────────────────────────────────

var room
var anchor: Node3D
var shell: Node3D
var windows: Array = []
var _clock


func _init(p_room = null, p_anchor: Node3D = null, p_shell: Node3D = null) -> void:
	room = p_room
	anchor = p_anchor
	shell = p_shell


func build_inside(hour: float) -> void:
	var built := build(room._root, room, false)
	_clock = built.get("clock")
	if _clock != null:
		_clock.show_time(hour)
	var i := 0
	for r in PANES:
		var p := pane(r)
		var w = WINDOW_PORTAL.make(room, room._root, (p["at"] as Vector3) - Vector3(0, 0, 0.02), Vector3(0, 0, 1), p["size"], "curtain_floral")
		if w.body != null:
			w.body.set_meta("room_hot", "curtain%d" % i)
			room._hot["curtain%d" % i] = {"body": w.body, "meshes": []}
		windows.append(w)
		i += 1


func tick(delta: float) -> void:
	var trip = room.get_parent() if room != null else null
	if _clock != null and trip != null and trip.has_method("hour"):
		_clock.show_time(float(trip.hour()))
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var xf := anchor.global_transform * Transform3D(Basis(), origin())
	var world := anchor.get_world_3d()
	for w in windows:
		w.update(room._root, room._cam, xf, true, world, delta, shell)


## The curtains are the view's; the pub's own clicks are town_room's (_pub_click).
func click(id: String, _hour: float) -> bool:
	if id.begins_with("curtain"):
		var i := int(id.substr(7))
		if i >= 0 and i < windows.size():
			var w = windows[i]
			var opening: bool = w.curtain_open() < 0.5
			w.toggle_curtain()
			room._play("res://assets/sfx/backroom/curtain_open.mp3" if opening else "res://assets/sfx/backroom/curtain_shut.mp3", -8.0)
		return true
	return false


func wants_out() -> bool:
	return true


func place_mates(mates: Dictionary, ids: Array) -> void:
	var k := 0
	for id in ids:
		var fig = mates.get(int(id))
		if fig == null:
			continue
		fig.visible = true
		fig.show_at(Vector3(0.9 if k % 2 == 0 else -0.6, 0.0, -0.6 + 0.4 * float(k / 2)), "stand")
		k += 1


func close() -> void:
	for w in windows:
		w.free_all()
	windows.clear()
