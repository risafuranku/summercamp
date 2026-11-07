extends RefCounted

## The kiosk of Liblice's Benzina (town_lesna._station outside, town_room.gd's place
## "kiosk" inside), built to its front (kiosk_front.png: the shop window and the glazed
## door in the tiled wall). The window and the door's glass are real holes now
## (`kiosk_front_glass.png`, mesto_art.py): behind them the window display and the little
## shop, the same room you stand in: the counter with Mrs Lojzova, the shelves of oil,
## maps and cigarettes behind her, the calendar. Lit from six to nine in the evening.
## Inside, the window and the door look out at the pumps under the canopy.
## It sells what a petrol station sells: Start at three dollars out of the little rack,
## Kofola out of the crate at the counter's end, matches and the paper on the counter. What
## you point at she puts on the counter, the till rings it up (counter_shop.gd, the goods
## and her lines counter_goods.gd).
##
## Room space: the middle of the kiosk's floor, x east, z towards the pumps (the front).
## The kiosk's own node in the station faces -z: room space is turned half round in it.

const K = preload("res://scripts/interior_kit.gd")
const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
const GOODS = preload("res://scripts/town/counter_goods.gd")
const WALL_CLOCK = preload("res://scripts/town/wall_clock.gd")
const SFX_TICK := "res://assets/sfx/rooms/clock_tick_wall.mp3"
const CAMP := "res://assets/textury/camp/"
## The front's picture: metres, pixels a metre; the box it is on.
const W := 5.7
const H := 3.2
const PX_M := 45.0
const BOX := Vector3(10.0, 3.2, 6.0)
## The holes (px: x0, y0, x1, y1): the shop window, the door's glass.
const PANES := [[22, 42, 154, 103]]
const DOOR_GLASS := [[183, 47, 218, 133]]
const FLOOR_Y := 0.2
const ROOM := Vector3(5.4, 2.7, 4.0)
const STAND := Vector3(1.45, 1.58, 1.15)
## The counter's top; where she puts what you take (the near end first), what the others buy.
const TOP_Y := 1.0
const SLOTS := [
	Vector3(0.5, TOP_Y, -0.36), Vector3(0.25, TOP_Y, -0.38), Vector3(0.0, TOP_Y, -0.36), Vector3(-0.25, TOP_Y, -0.38),
	Vector3(-0.5, TOP_Y, -0.36), Vector3(-0.75, TOP_Y, -0.38), Vector3(-1.0, TOP_Y, -0.36), Vector3(-1.25, TOP_Y, -0.38),
]
const MATE_SLOTS := [
	Vector3(-1.5, TOP_Y, -0.36), Vector3(-1.75, TOP_Y, -0.38), Vector3(-1.95, TOP_Y, -0.36),
	Vector3(-1.5, TOP_Y, -0.58), Vector3(-1.75, TOP_Y, -0.6), Vector3(-1.95, TOP_Y, -0.58),
]
## The till stands turned to you, and its display: a share of its picture.
const TILL_YAW := 40.0
const TILL_WINDOW := Rect2(0.53, 0.055, 0.3, 0.125)


## The room's middle on its floor in the kiosk node's frame (its front at -BOX.z/2, the room
## turned: room +z is the node's -z).
static func origin() -> Vector3:
	return Vector3(0.0, FLOOR_Y, -BOX.z * 0.5 + 0.15 + ROOM.z * 0.5)


static func basis() -> Basis:
	return Basis(Vector3.UP, PI)


## A hole as a pane in room space. The picture faces the node's -z (its left edge at the
## node's +x, the room's -x): a picture's x from its left is the room's x from -W/2.
static func pane(r: Array) -> Dictionary:
	var x0 := float(r[0]) / PX_M - W * 0.5
	var x1 := float(r[2]) / PX_M - W * 0.5
	var top := H - float(r[1]) / PX_M
	var bottom := H - float(r[3]) / PX_M
	return {"at": Vector3((x0 + x1) * 0.5, (top + bottom) * 0.5 - FLOOR_Y, ROOM.z * 0.5), "size": Vector2(x1 - x0, top - bottom)}


static func _exists(tex: String) -> bool:
	return ResourceLoader.exists(CAMP + tex + ".png")


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


## A sprite of the shop's own (counter_goods.gd), lit with the rest of the shell.
static func _spr(root: Node3D, file: String, height: float, pos: Vector3, yaw: float, lit: bool, billboard := false, name := "Good") -> MeshInstance3D:
	var s := GOODS.sprite(root, GOODS.SHOP + file, height, pos, yaw, billboard, name)
	s.material_override = _lit(s.material_override, lit)
	return s


static func build(root: Node3D, room = null, lit := false) -> Dictionary:
	var out := {}
	var inside: bool = room != null
	var l := lit and not inside
	var w := ROOM.x
	var d := ROOM.z
	var h := ROOM.y
	var oil := K.surface("oil_wall", K.oil_wall_metres(h))
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), _lit(K.surface("shop_floor", 2.4), l), "Floor")
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
		K.cut_wall(front, holes)
		K.skirting(root, ROOM, "planks_dark")
	# The window display behind the shop window: oil cans, maps, cigarettes on a low stand.
	var wp := pane(PANES[0])
	var wat: Vector3 = wp["at"]
	var wsz: Vector2 = wp["size"]
	var sill := wat.y - wsz.y * 0.5
	K.slab(root, Vector3(wsz.x, sill, 0.5), Vector3(wat.x, sill * 0.5, d * 0.5 - 0.25), _lit(K.surface("veneer_dark", 0.6), l), "DisplayBase")
	if _exists("jednota_display_a"):
		var t: Texture2D = load(CAMP + "jednota_display_a.png")
		var dw := wsz.x - 0.1
		var disp := K.cutout(root, "jednota_display_a", Vector2(dw, dw * float(t.get_height()) / float(t.get_width())), Vector3(wat.x, sill, d * 0.5 - 0.27), 0.0, false, "Display")
		disp.material_override = _lit(disp.material_override, l)
	# The counter across the middle, the shelves behind it, the calendar.
	var counter := Vector3(3.0, 0.95, 0.55)
	var cpos := Vector3(-0.6, 0.475, -0.55)
	K.slab(root, counter, cpos, _lit(K.surface("veneer_dark", 0.6), l), "Counter")
	var cf := K.picture(root, "kiosk_counter", Vector2(counter.x, counter.y), cpos + Vector3(0, 0, counter.z * 0.5 + 0.005), 0.0, "CounterFront")
	var front := GOODS.SHOP + "kiosk_front.png"
	if ResourceLoader.exists(front):
		(cf.material_override as StandardMaterial3D).albedo_texture = load(front)
	cf.material_override = _lit(cf.material_override, l)
	K.slab(root, Vector3(counter.x + 0.1, 0.05, counter.z + 0.07), cpos + Vector3(0, counter.y * 0.5 + 0.025, 0), _lit(GOODS.laminate(), l), "CounterTop")
	# What stands on the counter: the till, the cigarettes' little rack, the paper, the matches.
	var top := counter.y + 0.05
	var till := _spr(root, "kiosk_till.png", 0.42, Vector3(0.45, top, -0.66), TILL_YAW, l, false, "Till")
	var rack := _spr(root, "kiosk_rack.png", 0.34, Vector3(-0.15, top, -0.68), TILL_YAW, l, false, "CigRack")
	var papers := _spr(root, "kiosk_papers.png", 0.15, Vector3(-0.75, top, -0.66), TILL_YAW, l, false, "Newspapers")
	var matches := _spr(root, "matches_tray.png", 0.16, Vector3(-1.3, top, -0.64), TILL_YAW, l, false, "Matches")
	# Kofola in a crate on the floor at the counter's end.
	var crate := _spr(root, "kofola_crate.png", 0.42, Vector3(1.35, 0.0, -0.75), 0.0, l, true, "KofolaCrate")
	_spr(root, "kofola_crate.png", 0.42, Vector3(1.32, 0.42, -0.8), 0.0, l, true, "KofolaCrate2")
	K.slab(root, Vector3(3.8, 1.6, 0.3), Vector3(-0.4, 1.4, -d * 0.5 + 0.15), _lit(K.surface("planks_dark", 0.6), l), "Shelves")
	var shelves := K.picture(root, "kiosk_shelves", Vector2(3.7, 1.55), Vector3(-0.4, 1.4, -d * 0.5 + 0.305), 0.0, "ShelvesFace")
	shelves.material_override = _lit(shelves.material_override, l)
	K.cutout(root, "kiosk_calendar", Vector2(0.4, 0.55), Vector3(w * 0.5 - 0.02, 1.3, 0.2), -90.0, false, "Calendar")
	# Fly paper over the counter, the extinguisher by the door, the safety poster on the
	# west wall (the camp's own pictures).
	var fly := K.cutout(root, "flypaper", Vector2(0.09, 0.22), Vector3(-1.4, h - 0.23, -0.2), 0.0, true, "FlyPaper")
	fly.material_override = _lit(fly.material_override, l)
	var ext := K.cutout(root, "fire_extinguisher", Vector2(0.24, 0.46), Vector3(w * 0.5 - 0.06, 0.55, 1.5), -90.0, false, "Extinguisher")
	ext.material_override = _lit(ext.material_override, l)
	var poster := K.cutout(root, "bozp_poster", Vector2(0.42, 0.56), Vector3(-w * 0.5 + 0.02, 1.25, 0.9), 90.0, false, "Poster")
	poster.material_override = _lit(poster.material_override, l)
	if not inside:
		if l:
			var tm := K._base(Color(0.95, 0.97, 0.98))
			tm.emission_enabled = true
			tm.emission = Color(0.9, 0.96, 1.0)
			tm.emission_energy_multiplier = 1.4
			K.slab(root, Vector3(1.2, 0.05, 0.1), Vector3(-0.4, h - 0.06, -0.4), tm, "Tube")
			var path := "res://assets/textury/npc/town_lojzova.png"
			if ResourceLoader.exists(path):
				var tx: Texture2D = load(path)
				var sp := Sprite3D.new()
				sp.texture = tx
				sp.pixel_size = 1.6 / float(tx.get_height())
				sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				sp.offset = Vector2(0, tx.get_height() * 0.5)
				sp.position = Vector3(-0.8, 0.0, -1.15)
				root.add_child(sp)
		for g in root.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return out
	room._tube(Vector3(-0.4, h - 0.06, -0.4))
	# The clock over the shelves keeps the time (wall_clock.gd).
	var clock = WALL_CLOCK.new()
	clock.make(root, Vector3(0.9, 2.44, -d * 0.5 + 0.03), 0.0, 0.3)
	out["clock"] = clock
	room._hot_box("cigs", Vector3(-0.15, top + 0.17, -0.68), Vector3(0.3, 0.36, 0.3), [rack])
	room._hot_box("till", Vector3(0.45, top + 0.2, -0.66), Vector3(0.5, 0.44, 0.34), [till])
	room._hot_box("newspaper", Vector3(-0.75, top + 0.08, -0.66), Vector3(0.44, 0.2, 0.34), [papers])
	room._hot_box("matches", Vector3(-1.3, top + 0.08, -0.64), Vector3(0.34, 0.2, 0.3), [matches])
	room._hot_box("kofola", Vector3(1.34, 0.42, -0.78), Vector3(0.6, 0.84, 0.5), [crate])
	room._npc_sprite("town_lojzova", 1.6, Vector3(-0.8, 0.0, -1.15), "her")
	out["till"] = till
	# What it all costs, on little cards by the goods.
	GOODS.tag(root, 3, Vector3(0.06, top, -0.6), TILL_YAW, 0.11)
	GOODS.tag(root, 1, Vector3(-0.5, top, -0.58), TILL_YAW, 0.11)
	GOODS.tag(root, 1, Vector3(-1.08, top, -0.56), TILL_YAW, 0.11)
	GOODS.tag(root, 2, Vector3(1.22, 0.8, -0.66), 20.0, 0.15)
	var dp := pane(DOOR_GLASS[0])
	room._hot_box("door", Vector3((dp["at"] as Vector3).x, 1.0, d * 0.5 - 0.05), Vector3(0.9, 2.0, 0.12), [])
	room._light_profile(false)
	room._cam.position = STAND
	# Turned to the counter and Mrs Lojzova behind it, the door at your back.
	room._base_rot = Vector3(deg_to_rad(-6.0), deg_to_rad(40.0), 0.0)
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
	# Quiet in here: the clock is what you hear.
	room._loop(SFX_TICK, -28.0)
	room.counter().begin("kiosk", {"slots": SLOTS, "mate_slots": MATE_SLOTS, "till": built["till"], "window": TILL_WINDOW, "billboard": true})
	for r in PANES + DOOR_GLASS:
		var p := pane(r)
		windows.append(WINDOW_PORTAL.make(room, room._root, (p["at"] as Vector3) - Vector3(0, 0, 0.02), Vector3(0, 0, 1), p["size"], "", 224, false))
	if hour >= 7.0 and hour < 18.5:
		room._omni(Vector3(-0.8, 1.8, ROOM.z * 0.5 - 0.7), Color(0.92, 0.95, 1.0), 0.6, 4.5)


func tick(delta: float) -> void:
	_show_time()
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var xf := anchor.global_transform * Transform3D(basis(), origin())
	var world := anchor.get_world_3d()
	# (Built anew at closing time: the one we were given is gone, and each frame was an error
	# and the windows dead.)
	shell = anchor.get_node_or_null("Shop") as Node3D
	for w in windows:
		w.update(room._root, room._cam, xf, true, world, delta, shell)


func _show_time() -> void:
	var trip = room.get_parent() if room != null else null
	if _clock != null and trip != null and trip.has_method("hour"):
		_clock.show_time(float(trip.hour()))


func click(_id: String, _hour: float) -> bool:
	return false


func wants_out() -> bool:
	return true


## The other wardens: at the counter's end beside you, by the window display, by the calendar
## (out of the line from where you stand to Mrs Lojzova).
const MATE_SPOTS := [Vector3(1.3, 0.0, -0.55), Vector3(-0.6, 0.0, 0.75), Vector3(1.9, 0.0, 0.3)]


func place_mates(mates: Dictionary, ids: Array) -> void:
	var k := 0
	for id in ids:
		var fig = mates.get(int(id))
		if fig == null:
			continue
		fig.visible = true
		fig.show_at(MATE_SPOTS[k % MATE_SPOTS.size()], "stand")
		k += 1
	room.counter().mates_here(ids)


func close() -> void:
	room.counter().end()
	for w in windows:
		w.free_all()
	windows.clear()
