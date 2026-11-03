extends RefCounted

## The Jednota u Marku in Liblice (town_lesna._jednota outside, town_room.gd's place
## "jednota" inside), built to its front: the 1970s shop's twelve metres of plaster with
## two shop windows and the glazed double door between them (lib_jednota_front.png). The
## windows and the door are real holes now (`lib_jednota_front_glass.png`, made by
## tools/artgen/mesto_art.py): behind the glass the window displays and the whole sales
## room, the same room you stand in: the counter across its back with Mrs Novotna and the
## shelf of cigarettes and spirits behind her, the long goods shelf on the west wall, the
## fridge, the bread and the freezer on the east, the tubes on the ceiling (one dying).
## Inside, the windows look out at the street and the green (window_portal.gd).
##
## Room space: the middle of the sales room's floor, x east, z towards the street.

const K = preload("res://scripts/interior_kit.gd")
const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
const CAMP := "res://assets/textury/camp/"
## The front's picture: metres, its pixels a metre.
const W := 12.0
const H := 5.0
const PX_M := 32.0
const DEPTH := 10.0
## The holes in the picture (px: x0, y0, x1, y1): the four panes of the two shop windows,
## the two glazed leaves of the door. mesto_art.py cuts the same.
const PANES := [[38, 58, 93, 120], [98, 58, 150, 120], [232, 58, 288, 120], [293, 58, 346, 120]]
const DOOR_GLASS := [[159, 59, 190, 134], [193, 59, 224, 134]]
## The shop's floor over the street (the front's plinth); the sales room inside.
const FLOOR_Y := 0.66
const ROOM := Vector3(11.6, 3.1, 6.0)
const STAND := Vector3(0.0, 1.58, 1.75)
const DISPLAYS := ["jednota_display_a", "jednota_display_b"]


## The sales room's middle on its floor, in the building's own frame (its front at +z).
static func origin() -> Vector3:
	return Vector3(0.0, FLOOR_Y, DEPTH * 0.5 - 0.15 - ROOM.z * 0.5)


## A hole of the picture as a pane in room space: its middle (on the front wall) and size.
static func pane(r: Array) -> Dictionary:
	var x0 := float(r[0]) / PX_M - W * 0.5
	var x1 := float(r[2]) / PX_M - W * 0.5
	var top := H - float(r[1]) / PX_M
	var bottom := H - float(r[3]) / PX_M
	return {"at": Vector3((x0 + x1) * 0.5, (top + bottom) * 0.5 - FLOOR_Y, ROOM.z * 0.5), "size": Vector2(x1 - x0, top - bottom)}


static func _exists(tex: String) -> bool:
	return ResourceLoader.exists(CAMP + tex + ".png")


static func _size(tex: String, height: float) -> Vector2:
	var path := CAMP + tex + ".png"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		return Vector2(height * float(t.get_width()) / float(t.get_height()), height)
	return Vector2(height, height)


## Outside, a lit shop: its surfaces a little self-lit (the Build way).
static func _lit(m: Material, lit: bool) -> Material:
	if not lit or m == null:
		return m
	var s := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	s.emission_enabled = true
	s.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	if s.albedo_texture != null:
		s.emission_texture = s.albedo_texture
	s.emission = Color(0.92, 0.96, 1.0)
	s.emission_energy_multiplier = 0.5
	return s


static func _quad(root: Node3D, tex: String, size: Vector2, pos: Vector3, yaw: float, lit: bool, name := "Face") -> MeshInstance3D:
	var q := K.picture(root, tex, size, pos, yaw, name)
	q.material_override = _lit(q.material_override, lit)
	return q


## The room under `root` (room space). `room` (town_room.gd) when you stand in it: the
## front wall cut round its glass, the things to click, the people; null for the shell
## behind the glass in the village, `lit` then for its tubes on.
static func build(root: Node3D, room = null, lit := false) -> Dictionary:
	var out := {"tubes": []}
	var inside: bool = room != null
	var l := lit and not inside
	var w := ROOM.x
	var d := ROOM.z
	var h := ROOM.y
	var oil := K.surface("oil_wall", K.oil_wall_metres(h))
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), _lit(K.surface("shop_floor", 2.6), l), "Floor")
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, h + 0.05, 0), _lit(K.surface("ceiling_board", 1.0), l), "Ceiling")
	K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, -d * 0.5 - 0.05), _lit(oil, l), "WallBack")
	K.slab(root, Vector3(0.1, h, d), Vector3(-w * 0.5 - 0.05, h * 0.5, 0), _lit(oil, l), "WallWest")
	K.slab(root, Vector3(0.1, h, d), Vector3(w * 0.5 + 0.05, h * 0.5, 0), _lit(oil, l), "WallEast")
	if inside:
		var front := K.slab(root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, d * 0.5 + 0.05), oil, "WallFront")
		var holes: Array = []
		for r in PANES + DOOR_GLASS:
			var p := pane(r)
			var at: Vector3 = p["at"]
			var sz: Vector2 = p["size"]
			holes.append([at.x - sz.x * 0.5, at.x + sz.x * 0.5, at.y - sz.y * 0.5, at.y + sz.y * 0.5])
		# The door's leaves reach down to the floor: their glass, and the panel under it.
		var dl: Dictionary = pane(DOOR_GLASS[0])
		var dr: Dictionary = pane(DOOR_GLASS[1])
		var door_x0: float = (dl["at"] as Vector3).x - (dl["size"] as Vector2).x * 0.5
		var door_x1: float = (dr["at"] as Vector3).x + (dr["size"] as Vector2).x * 0.5
		holes.append([door_x0, door_x1, 0.0, (dl["at"] as Vector3).y - (dl["size"] as Vector2).y * 0.5])
		K.cut_wall(front, holes)
		K.skirting(root, ROOM, "planks_dark")
		# The door's kick panel under its glass (aluminium).
		var kick_h: float = (dl["at"] as Vector3).y - (dl["size"] as Vector2).y * 0.5
		K.slab(root, Vector3(door_x1 - door_x0, kick_h, 0.04), Vector3((door_x0 + door_x1) * 0.5, kick_h * 0.5, d * 0.5 + 0.02), K.surface("galvanized", 0.5, Color(0.7, 0.72, 0.7)), "DoorKick")
	# The window displays behind the glass of each shop window, both ways.
	for i in 2:
		var a: Dictionary = pane(PANES[i * 2])
		var b: Dictionary = pane(PANES[i * 2 + 1])
		var x0: float = (a["at"] as Vector3).x - (a["size"] as Vector2).x * 0.5
		var x1: float = (b["at"] as Vector3).x + (b["size"] as Vector2).x * 0.5
		var sill: float = (a["at"] as Vector3).y - (a["size"] as Vector2).y * 0.5
		K.slab(root, Vector3(x1 - x0, sill, 0.6), Vector3((x0 + x1) * 0.5, sill * 0.5, d * 0.5 - 0.3), _lit(K.surface("veneer_dark", 0.6, Color(0.7, 0.3, 0.26)), l), "DisplayBase")
		var tex: String = DISPLAYS[i]
		if _exists(tex):
			var sz := Vector2(x1 - x0 - 0.1, (x1 - x0 - 0.1) * _size(tex, 1.0).y / maxf(0.01, _size(tex, 1.0).x))
			var disp := K.cutout(root, tex, sz, Vector3((x0 + x1) * 0.5, sill, d * 0.5 - 0.32), 0.0, false, "Display")
			disp.material_override = _lit(disp.material_override, l)
	# The counter across the back third, its goods.
	var counter := Vector3(4.2, 0.9, 0.62)
	var cpos := Vector3(0.0, 0.45, -0.95)
	K.slab(root, counter, cpos, _lit(K.surface("veneer_dark", 0.8), l), "Counter")
	_quad(root, "shop_counter", Vector2(counter.x, counter.y), cpos + Vector3(0, 0, counter.z * 0.5 + 0.005), 0.0, l, "CounterFront")
	K.slab(root, Vector3(counter.x + 0.1, 0.05, counter.z + 0.08), cpos + Vector3(0, counter.y * 0.5 + 0.025, 0), _lit(K.surface("plastic", 0.5, Color(0.56, 0.52, 0.46)), l), "CounterTop")
	var top := counter.y + 0.05
	K.cutout(root, "shop_till", Vector2(0.5, 0.46), Vector3(1.2, top, -1.05), 0.0, false, "Till")
	K.cutout(root, "shop_scales", Vector2(0.42, 0.42), Vector3(-1.3, top, -1.0), 0.0, false, "Scales")
	var cards := K.cutout(root, "card_box", Vector2(0.26, 0.26), Vector3(0.55, top, -0.82), 0.0, false, "CardBox")
	var batt := K.slab(root, Vector3(0.3, 0.16, 0.2), Vector3(-0.55, top + 0.08, -0.82), K.surface("cardboard", 0.3), "BatteryBox")
	# Behind it the shelf of cigarettes and spirits on the back wall.
	K.slab(root, Vector3(3.4, 1.6, 0.3), Vector3(0.0, 1.6, -d * 0.5 + 0.15), _lit(K.surface("planks_dark", 0.6), l), "BackShelf")
	var cigs := _quad(root, "shop_shelf_cigs", Vector2(3.3, 1.55), Vector3(0.0, 1.6, -d * 0.5 + 0.305), 0.0, l, "Cigarettes")
	_quad(root, "shop_poster", Vector2(0.6, 0.8), Vector3(2.4, 1.8, -d * 0.5 + 0.005), 0.0, l, "Poster")
	_quad(root, "calendar", Vector2(0.36, 0.48), Vector3(-2.3, 1.75, -d * 0.5 + 0.005), 0.0, l, "Calendar")
	# The west wall: the long shelf of tins and jars, twice; the baskets by the door.
	for z in [-1.4, 1.25]:
		K.slab(root, Vector3(0.45, 2.0, 2.4), Vector3(-w * 0.5 + 0.23, 1.0, z), _lit(K.surface("galvanized", 0.6, Color(0.7, 0.7, 0.68)), l), "GoodsShelf")
		_quad(root, "shop_shelf_goods", Vector2(2.3, 1.86), Vector3(-w * 0.5 + 0.46, 1.0, z), 90.0, l, "Goods")
	K.cutout(root, "shop_baskets", Vector2(0.5, 0.5), Vector3(-1.6, 0.0, 2.2), 0.0, true, "Baskets")
	# The east wall: the fridge humming blue, the bread, the freezer.
	K.slab(root, Vector3(0.7, 1.9, 0.7), Vector3(w * 0.5 - 0.36, 0.95, -1.2), _lit(K.surface("enamel_white", 0.6, Color(0.85, 0.86, 0.84)), l), "Fridge")
	var fglass := K.picture(root, "shop_fridge", Vector2(0.66, 1.84), Vector3(w * 0.5 - 0.715, 0.97, -1.2), -90.0, "FridgeDoor")
	var fm := fglass.material_override as StandardMaterial3D
	fm.emission_enabled = true
	fm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	fm.emission_texture = fm.albedo_texture
	fm.emission = Color(0.7, 0.85, 1.0)
	fm.emission_energy_multiplier = 0.5
	K.slab(root, Vector3(0.4, 1.6, 0.9), Vector3(w * 0.5 - 0.22, 0.8, 0.2), _lit(K.surface("planks_grey", 0.5, Color(0.8, 0.7, 0.55)), l), "BreadRack")
	_quad(root, "shop_bread", Vector2(0.86, 1.15), Vector3(w * 0.5 - 0.425, 0.95, 0.2), -90.0, l, "Bread")
	K.cutout(root, "shop_freezer", Vector2(1.0, 0.75), Vector3(w * 0.5 - 0.7, 0.0, 1.5), -90.0, false, "Freezer")
	# The beer crates by the counter's end.
	var crate := K.cutout(root, "beer_crate_full", Vector2(0.56, 0.42), Vector3(-2.6, 0.0, -0.55), 0.0, true, "BeerCrate")
	K.cutout(root, "beer_crate_full", Vector2(0.56, 0.42), Vector3(-2.64, 0.42, -0.6), 0.0, true, "BeerCrate2")
	# The tubes on the ceiling.
	for t in [[Vector3(-2.6, h - 0.06, -0.8), false], [Vector3(1.6, h - 0.06, -0.8), true], [Vector3(-1.0, h - 0.06, 1.4), false], [Vector3(3.2, h - 0.06, 1.4), false]]:
		if inside:
			room._tube(t[0], t[1])
		else:
			var tm := K._base(Color(0.95, 0.97, 0.98))
			if l:
				tm.emission_enabled = true
				tm.emission = Color(0.9, 0.96, 1.0)
				tm.emission_energy_multiplier = 1.4
			var tube := K.slab(root, Vector3(1.2, 0.05, 0.1), t[0], tm, "Tube")
			tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			out["tubes"].append(tube)
	if not inside:
		# Mrs Novotna behind the counter through the glass while it is open.
		if l:
			var path := "res://assets/textury/npc/town_shopgirl.png"
			if ResourceLoader.exists(path):
				var t: Texture2D = load(path)
				var sp := Sprite3D.new()
				sp.name = "Novotna"
				sp.texture = t
				sp.pixel_size = 1.62 / float(t.get_height())
				sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				sp.offset = Vector2(0, t.get_height() * 0.5)
				sp.position = Vector3(0.1, 0.0, -1.8)
				root.add_child(sp)
		for g in root.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return out
	# Inside: what you click, who serves, where you stand.
	room._hot_box("card", Vector3(0.55, top + 0.13, -0.82), Vector3(0.3, 0.28, 0.2), [cards])
	room._hot_box("batteries", Vector3(-0.55, top + 0.08, -0.82), Vector3(0.32, 0.2, 0.22), [batt])
	room._hot_box("cigs", Vector3(0.0, 1.6, -d * 0.5 + 0.3), Vector3(3.3, 1.55, 0.3), [cigs])
	room._hot_box("beer", Vector3(-2.6, 0.42, -0.55), Vector3(0.6, 0.84, 0.5), [crate])
	room._npc_sprite("town_shopgirl", 1.62, Vector3(0.1, 0.0, -1.8), "her")
	room._omni(Vector3(w * 0.5 - 1.1, 1.2, -1.2), Color(0.7, 0.85, 1.0), 0.25, 1.8)
	var dl_at: Vector3 = pane(DOOR_GLASS[0])["at"]
	var dr_at: Vector3 = pane(DOOR_GLASS[1])["at"]
	var dc: Vector3 = (dl_at + dr_at) * 0.5
	room._hot_box("door", Vector3(dc.x, 1.1, d * 0.5 - 0.05), Vector3(2.1, 2.2, 0.12), [])
	room._cam.position = STAND
	room._base_rot = Vector3(deg_to_rad(-6.0), 0.0, 0.0)
	room._look.yaw_limit_deg = 150.0
	return out


# ── the room you stand in ────────────────────────────────────────────────────

var room
## The building in the village (town_lesna._jednota) and the room built in it behind the
## glass (hidden from the windows' own view while you are inside).
var anchor: Node3D
var shell: Node3D
var windows: Array = []


func _init(p_room = null, p_anchor: Node3D = null, p_shell: Node3D = null) -> void:
	room = p_room
	anchor = p_anchor
	shell = p_shell


func build_inside(hour: float) -> void:
	build(room._root, room, false)
	room._light_profile(false)
	for r in PANES + DOOR_GLASS:
		var p := pane(r)
		var w = WINDOW_PORTAL.make(room, room._root, (p["at"] as Vector3) - Vector3(0, 0, 0.02), Vector3(0, 0, 1), p["size"], "", 224, false)
		windows.append(w)
	if hour >= 7.0 and hour < 18.5:
		# The day through the shop windows.
		for x in [-3.0, 3.0]:
			room._omni(Vector3(x, 1.8, ROOM.z * 0.5 - 0.8), Color(0.92, 0.95, 1.0), 0.7, 5.5)


func tick(delta: float) -> void:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var xf := anchor.global_transform * Transform3D(Basis(), origin())
	var world := anchor.get_world_3d()
	for w in windows:
		w.update(room._root, room._cam, xf, true, world, delta, shell)


## The shop's own clicks are town_room's (_shop_click): nothing here.
func click(_id: String, _hour: float) -> bool:
	return false


func wants_out() -> bool:
	return true


## The other wardens at the counter beside you.
func place_mates(mates: Dictionary, ids: Array) -> void:
	var k := 0
	for id in ids:
		var fig = mates.get(int(id))
		if fig == null:
			continue
		fig.visible = true
		fig.show_at(Vector3(0.9 if k % 2 == 0 else -0.9, 0.0, 0.4 + 0.5 * float(k / 2)), "stand")
		k += 1


func close() -> void:
	for w in windows:
		w.free_all()
	windows.clear()
