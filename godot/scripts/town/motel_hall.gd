extends RefCounted

## The Liblice motel's corridor (town_room.gd's place "motel_hall", the user 4. 11.: "it
## should work like in some RPG; I see him go off into the corridor, I follow him; we can
## go to any door, but we go to the one he has just taken"). The whole length of the block
## behind the rooms on both floors, from the passage off the reception to the far end,
## the stairs up along its south side at the east end: worn carpet, smoke-brown wallpaper,
## lamps of which not all work, every room's door with its number.
##
##   you walk     along it to what you click (room_walk.gd), up and down the stairs;
##   a door       yours opens with your key (or for you when another warden is in there);
##                the others do not: the handle goes down and that is all, and now and
##                then, behind a taken room's door, a set, a cough;
##   six          some nights a line of light under its door (motel_plan.six_lit); never
##                explained;
##   the others   stand and walk where they are on their machines (`mate_walk`: each warden's
##                spot comes by Coop.send_place "town" "motel" "walk"); you see them go
##                in at a door (`mate_leaves`).
## Its space is motel space: the block's middle on the ground, x east, z south.

const PLAN = preload("res://scripts/town/motel_plan.gd")
const ROOMS = preload("res://scripts/town/motel_rooms.gd")
const K = preload("res://scripts/interior_kit.gd")
const WALK = preload("res://scripts/town/room_walk.gd")
const MATES = preload("res://scripts/town/room_mates.gd")
const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
const SFX := "res://assets/sfx/"
const CAMP := "res://assets/textury/camp/"
const TOWN := "res://assets/textury/town/"
const H := 2.7
const NORTH := PLAN.CORRIDOR_Z.x
const SOUTH := PLAN.CORRIDOR_Z.y
const MID := (PLAN.CORRIDOR_Z.x + PLAN.CORRIDOR_Z.y) * 0.5
const HALF := PLAN.SIZE.x * 0.5 - PLAN.WALL
## A door's width, a walker's line along the corridor (north of the stairs where they are).
const DOOR_W := 0.64
const LINE_Z := 2.42
## The eye, walking.
const EYE := 1.6
## At the passage's door to the reception, facing it (the spot's own look is out of it).
const TO_LOBBY := Vector3(-0.035, 0.0, 0.0)

var room
var block: Node3D
var parts: Dictionary = {}
var windows: Array = []
var _walker
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _doors: Dictionary = {}          # n -> pivot
var _lamps: Array = []               # {"light", "mesh", "dying", "phase"}
var _six_gap: MeshInstance3D
var _six_light: OmniLight3D
var _players: Array = []
var _amb: AudioStreamPlayer
var _behind: AudioStreamPlayer
var _wall_snd: AudioStreamPlayer
var _fx: AudioStreamPlayer
var _busy_door := false
## The other wardens here: id -> {"fig", "at": feet, "path": [feet...], "gone": bool}.
var _crew


func _init(p_room, p_block: Node3D) -> void:
	room = p_room
	block = p_block


func _exists(tex: String) -> bool:
	return ResourceLoader.exists(CAMP + tex + ".png")


func _size(tex: String, height: float) -> Vector2:
	var path := CAMP + tex + ".png"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		return Vector2(height * float(t.get_width()) / float(t.get_height()), height)
	return Vector2(height, height)


## room space -> the village.
func _xform() -> Transform3D:
	if block == null or not is_instance_valid(block) or not block.is_inside_tree():
		return Transform3D()
	return block.global_transform


static func spot_of(n: int) -> String:
	return "r%d" % n


## Where you can stand along the corridor, and how you look there.
static func spots() -> Dictionary:
	var r := func(p: float, y: float) -> Vector3: return Vector3(deg_to_rad(p), deg_to_rad(y), 0.0)
	var out := {
		"lobby": {"at": Vector3(PLAN.passage_x(), EYE, 0.75), "rot": r.call(-2.0, 180.0)},
		"junction": {"at": Vector3(PLAN.passage_x(), EYE, LINE_Z + 0.1), "rot": r.call(-2.0, -90.0)},
		"west": {"at": Vector3(-HALF + 1.2, EYE, LINE_Z + 0.2), "rot": r.call(-2.0, 90.0)},
		"s0": {"at": Vector3(PLAN.STAIRS_X.y + 0.1, EYE, 3.25), "rot": r.call(10.0, 90.0)},
		"s1": {"at": Vector3(PLAN.STAIRS_X.x - 0.1, PLAN.UPPER_Y + EYE, 3.25), "rot": r.call(-2.0, 90.0)},
		"top": {"at": Vector3(PLAN.STAIRS_X.x - 0.6, PLAN.UPPER_Y + EYE, LINE_Z + 0.2), "rot": r.call(-2.0, 90.0)},
		"up_east": {"at": Vector3(HALF - 0.9, PLAN.UPPER_Y + EYE, LINE_Z), "rot": r.call(-2.0, -90.0)},
		"up_west": {"at": Vector3(-HALF + 1.2, PLAN.UPPER_Y + EYE, LINE_Z + 0.2), "rot": r.call(-2.0, 90.0)},
	}
	for n in PLAN.ROOMS:
		var d := PLAN.hall_door(int(n))
		out[spot_of(int(n))] = {"at": Vector3(d.x, d.y + EYE, LINE_Z + 0.1), "rot": r.call(-4.0, 0.0)}
	return out


## The spots you can walk straight between: along each floor in order of x, the stairs.
static func ways() -> Array:
	var sp := spots()
	var down: Array = ["west", "junction"]
	var up: Array = ["up_west", "top", "up_east"]
	for n in PLAN.ROOMS:
		if bool(PLAN.ROOMS[n]["up"]):
			up.append(spot_of(int(n)))
		else:
			down.append(spot_of(int(n)))
	var by_x := func(a, b) -> bool: return (sp[a]["at"] as Vector3).x < (sp[b]["at"] as Vector3).x
	down.sort_custom(by_x)
	up.sort_custom(by_x)
	var out: Array = [["lobby", "junction"], [spot_of(5), "s0"], ["s0", "s1"], ["s1", "top"]]
	for i in down.size() - 1:
		out.append([down[i], down[i + 1]])
	for i in up.size() - 1:
		out.append([up[i], up[i + 1]])
	return out


# ── building ─────────────────────────────────────────────────────────────────

func build(hour: float, arrive: String) -> void:
	_rng.randomize()
	var root: Node3D = room._root
	_floors(root)
	_passage(root)
	_stairs(root)
	_room_doors(root)
	_lamp_row(root, 0.0)
	_lamp_row(root, PLAN.UPPER_Y)
	_things(root)
	_windows(root)
	_six()
	_light(hour)
	_sounds()
	_walker = WALK.new(room, spots(), ways(), "lobby", SFX + "rooms/steps_wood.mp3", -17.0)
	_walker.on_go = func(to: String): Coop.send_place("town", "motel", "walk", [to])
	_crew = MATES.new(room, spots(), ways(), "lobby")
	var at := arrive if spots().has(arrive) else "lobby"
	_walker.put(at)
	# Out of a room you come through its door still going that way and turn along the corridor
	# (the spot's own look is at the door behind you: the user 9. 11., "all at once facing
	# backwards").
	if at != "lobby":
		var d := PLAN.hall_door(int(at.substr(1)))
		var along: float = spots()["top" if bool(PLAN.ROOMS[int(at.substr(1))]["up"]) else "junction"]["at"].x - d.x
		room._cam.position = Vector3(d.x, d.y + EYE, NORTH + 0.22)
		room._base_rot = Vector3(deg_to_rad(-4.0), PI, 0.0)
		_walker.here = "out"
		room.get_tree().create_timer(0.12).timeout.connect(func():
			if _walker != null and room.is_open() and str(_walker.here) == "out":
				_walker.go(at, Callable(), Vector3(deg_to_rad(-2.0), deg_to_rad(-90.0 if along >= 0.0 else 90.0), 0.0)))
	# The corridor's ends and the stairs lit on the floor under the pointer; the stair's foot takes
	# you up, its top down (the user 6. 11.: "I could only get about by knocking on doors, upstairs
	# only by clicking a door through the ceiling"); a room's door walks you to it by its own click
	# (7. 11.: "far too many places to stand").
	_walker.floor_spots(["junction", "west", "s0", "s1", "top", "up_east", "up_west"], Vector2(0.8, 0.8), {"s0": "top", "s1": "junction"})
	Coop.send_place("town", "motel", "walk", [at])
	room._look.yaw_limit_deg = 180.0
	room._look.pitch_up_deg = 34.0
	room._look.pitch_down_deg = 40.0
	room._hot_box("lobby", Vector3(PLAN.passage_x(), 1.0, 0.16), Vector3(1.0, 2.1, 0.14), [])
	# Down the passage and out into the corridor as you come through from the reception.
	if at == "lobby":
		room.get_tree().create_timer(0.3).timeout.connect(func():
			if _walker != null and room.is_open() and str(_walker.here) == "lobby":
				_walker.go("junction"))


func _wall() -> StandardMaterial3D:
	return K.surface("motel_wall_dirty" if _exists("motel_wall_dirty") else "motel_wall", 1.4, Color(0.8, 0.72, 0.58))


func _floors(root: Node3D) -> void:
	var runner := K.surface("corridor_carpet" if _exists("corridor_carpet") else "motel_carpet_dirty", 1.65)
	var ceil := K.surface("ceiling_board", 1.0, Color(0.74, 0.7, 0.6))
	var wall := _wall()
	var depth := SOUTH - NORTH
	var len := HALF * 2.0
	var hole0 := PLAN.STAIRS_X.x
	var hole1 := PLAN.STAIRS_X.y
	var z_hole := PLAN.STAIRS_Z.x
	for y0 in [0.0, PLAN.UPPER_Y]:
		var y := float(y0)
		var up := y > 0.0
		# The floor: upstairs open over the stairs.
		if not up:
			K.slab(root, Vector3(len, 0.1, depth), Vector3(0, -0.05, MID), runner, "Floor")
		else:
			_open_slab(root, y - 0.05, runner, hole0, hole1, z_hole)
		# The ceiling: downstairs open under the stairwell.
		if up:
			K.slab(root, Vector3(len, 0.1, depth), Vector3(0, y + H + 0.05, MID), ceil, "Ceiling")
		else:
			_open_slab(root, y + H + 0.05, ceil, hole0, hole1, z_hole)
		# The north wall, cut for the doors (downstairs for the passage too), the south wall.
		var holes: Array = []
		for n in PLAN.ROOMS:
			if bool(PLAN.ROOMS[n]["up"]) == up:
				var d := PLAN.hall_door(int(n))
				holes.append([d.x - DOOR_W * 0.5, d.x + DOOR_W * 0.5, 0.0, PLAN.DOOR_H])
		if not up:
			holes.append([PLAN.passage_x() - 0.5, PLAN.passage_x() + 0.5, 0.0, 2.2])
		var north := K.slab(root, Vector3(len, H, 0.1), Vector3(0, y + H * 0.5, NORTH - 0.05), wall, "WallNorth")
		K.cut_wall(north, holes)
		K.slab(root, Vector3(len, H, 0.1), Vector3(0, y + H * 0.5, SOUTH + 0.05), wall, "WallSouth")
		# The ends, each with its window cut.
		for sx in [-1.0, 1.0]:
			var end := K.slab(root, Vector3(0.1, H, depth), Vector3(float(sx) * (HALF + 0.05), y + H * 0.5, MID), wall, "WallEnd")
			K.cut_wall(end, [[-0.55, 0.55, 0.95, 2.05]])
		# Skirting along both walls.
		var sk := K.surface("planks_dark", 0.6)
		K.slab(root, Vector3(len, 0.1, 0.03), Vector3(0, y + 0.05, SOUTH - 0.015), sk, "Skirting")
	# The stairwell's sides between the floors (the slab's thickness).
	K.slab(root, Vector3(hole1 - hole0, PLAN.UPPER_Y - H, 0.1), Vector3((hole0 + hole1) * 0.5, H + (PLAN.UPPER_Y - H) * 0.5, z_hole - 0.05), wall, "WellSide")


## A floor or a ceiling at `y` with the stairwell's hole in it.
func _open_slab(root: Node3D, y: float, mat: Material, x0: float, x1: float, z_hole: float) -> void:
	var depth := SOUTH - NORTH
	var west := x0 + HALF
	K.slab(root, Vector3(west, 0.1, depth), Vector3(-HALF + west * 0.5, y, MID), mat, "Slab")
	K.slab(root, Vector3(HALF - x0, 0.1, z_hole - NORTH), Vector3((x0 + HALF) * 0.5, y, (NORTH + z_hole) * 0.5), mat, "Slab")
	if HALF > x1:
		K.slab(root, Vector3(HALF - x1, 0.1, SOUTH - z_hole), Vector3((x1 + HALF) * 0.5, y, (z_hole + SOUTH) * 0.5), mat, "Slab")


## The short passage up from the corridor to the reception's door.
func _passage(root: Node3D) -> void:
	var x := PLAN.passage_x()
	var wall := _wall()
	var z0 := 0.1
	var z1 := NORTH - 0.1
	var zm := (z0 + z1) * 0.5
	K.slab(root, Vector3(1.0, 0.1, z1 - z0 + 0.2), Vector3(x, -0.05, zm), K.surface("corridor_carpet" if _exists("corridor_carpet") else "motel_carpet_dirty", 1.65), "PassageFloor")
	K.slab(root, Vector3(1.0, 0.1, z1 - z0 + 0.2), Vector3(x, 2.25, zm), K.surface("ceiling_board", 1.0, Color(0.74, 0.7, 0.6)), "PassageCeiling")
	for sx in [-1.0, 1.0]:
		K.slab(root, Vector3(0.1, 2.3, z1 - z0 + 0.2), Vector3(x + float(sx) * 0.55, 1.15, zm), wall, "PassageWall")
	K.slab(root, Vector3(1.2, 2.3, 0.1), Vector3(x, 1.15, z0 - 0.05), wall, "PassageEnd")
	K.picture(root, "door_interior", Vector2(0.9, 2.05), Vector3(x, 1.025, z0 + 0.006), 0.0, "ToLobby")


## The stairs up along the south wall: the foot at the east end, rising west.
func _stairs(root: Node3D) -> void:
	var wood := K.surface("pew_wood" if _exists("pew_wood") else "veneer_dark", 0.7, Color(0.6, 0.54, 0.48))
	var x1 := PLAN.STAIRS_X.y
	var run := PLAN.STAIRS_X.y - PLAN.STAIRS_X.x
	var n := PLAN.STEPS
	var tread := run / float(n)
	var rise := PLAN.UPPER_Y / float(n)
	var z0 := PLAN.STAIRS_Z.x
	var z1 := PLAN.STAIRS_Z.y
	for i in n:
		var top := rise * float(i + 1)
		var x := x1 - tread * (float(i) + 0.5)
		K.slab(root, Vector3(tread + 0.01, top, z1 - z0), Vector3(x, top * 0.5, (z0 + z1) * 0.5), wood, "Step")
	# The stairs' side along the corridor papered like its walls, up the line of the steps,
	# and a lamp's spill on it: bare wood at a grazing light it stood there as a black wall.
	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	side.set_normal(Vector3(0.0, 0.0, -1.0))
	side.add_vertex(Vector3(x1, 0.0, z0 - 0.012))
	side.add_vertex(Vector3(PLAN.STAIRS_X.x, PLAN.UPPER_Y, z0 - 0.012))
	side.add_vertex(Vector3(PLAN.STAIRS_X.x, 0.0, z0 - 0.012))
	var panel := MeshInstance3D.new()
	panel.name = "StairSide"
	panel.mesh = side.commit()
	panel.material_override = _wall()
	root.add_child(panel)
	var spill := OmniLight3D.new()
	spill.light_color = Color(1.0, 0.82, 0.56)
	spill.light_energy = 0.42
	spill.omni_range = 4.2
	spill.omni_attenuation = 1.1
	spill.position = Vector3(7.8, 1.5, 2.2)
	root.add_child(spill)
	# The rail on the open side, up the slope, and round the well upstairs.
	var len := sqrt(run * run + PLAN.UPPER_Y * PLAN.UPPER_Y)
	var rail := K.slab(root, Vector3(len, 0.05, 0.05), Vector3((PLAN.STAIRS_X.x + x1) * 0.5, PLAN.UPPER_Y * 0.5 + 0.95, z0 + 0.03), wood, "Rail")
	rail.rotation.z = -atan2(PLAN.UPPER_Y, run)
	K.slab(root, Vector3(run + 0.1, 0.05, 0.05), Vector3((PLAN.STAIRS_X.x + x1) * 0.5, PLAN.UPPER_Y + 0.95, z0 - 0.02), wood, "WellRail")
	for k in 5:
		var px := lerpf(PLAN.STAIRS_X.x, x1, float(k) / 4.0)
		K.slab(root, Vector3(0.04, 0.95, 0.04), Vector3(px, PLAN.UPPER_Y + 0.475, z0 - 0.02), wood, "Baluster")


## Every room's door on the north wall: its leaf on a hinge (opening into the room), its
## number's picture to the corridor, the dark of its little hall behind.
func _room_doors(root: Node3D) -> void:
	for n in PLAN.ROOMS:
		var i := int(n)
		var d := PLAN.hall_door(i)
		var dark := K.slab(root, Vector3(DOOR_W + 0.1, PLAN.DOOR_H, 0.05), Vector3(d.x, d.y + PLAN.DOOR_H * 0.5, NORTH - 0.32), K.surface("veneer_dark", 0.6, Color(0.1, 0.09, 0.08)), "Dark")
		dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pivot := Node3D.new()
		pivot.name = "Door%d" % i
		pivot.position = Vector3(d.x + DOOR_W * 0.5, d.y, NORTH - 0.03)
		root.add_child(pivot)
		K.slab(pivot, Vector3(DOOR_W, PLAN.DOOR_H, 0.04), Vector3(-DOOR_W * 0.5, PLAN.DOOR_H * 0.5, 0.0), K.surface("veneer_dark", 0.6), "Leaf")
		var path := TOWN + "motel_door_%d.png" % i
		if not ResourceLoader.exists(path):
			path = TOWN + "motel_door_out.png"
		if ResourceLoader.exists(path):
			var face := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(DOOR_W, PLAN.DOOR_H)
			face.mesh = q
			var m := K._base(Color(0.82, 0.78, 0.72))
			m.albedo_texture = load(path)
			face.material_override = m
			face.position = Vector3(-DOOR_W * 0.5, PLAN.DOOR_H * 0.5, 0.023)
			face.name = "Face"
			pivot.add_child(face)
		_doors[i] = pivot
		room._hot_box("door%d" % i, Vector3(d.x, d.y + 1.0, NORTH + 0.04), Vector3(DOOR_W + 0.1, 2.05, 0.1), [])


## The lamps along the ceiling, not all of them working.
func _lamp_row(root: Node3D, y: float) -> void:
	var xs := [-9.0, -4.6, -0.2, 4.2, 8.6]
	var k := 0
	for x in xs:
		var at := Vector3(float(x), y + H - 0.37, MID)
		var lamp := K.cutout(root, "ceiling_lamp", Vector2(0.36, 0.36), at, 0.0, true, "Lamp")
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.56)
		l.light_energy = 0.85
		l.omni_range = 5.4
		l.omni_attenuation = 1.15
		l.position = at + Vector3(0, -0.1, 0)
		root.add_child(l)
		# One dead, one dying on each floor.
		var dead := k == (1 if y > 0.0 else 3)
		l.visible = not dead
		(lamp.material_override as StandardMaterial3D).albedo_color = Color(0.5, 0.48, 0.44) if dead else Color(1, 1, 1)
		_lamps.append({"light": l, "dying": k == (3 if y > 0.0 else 0), "phase": float(k) * 1.7})
		k += 1


func _things(root: Node3D) -> void:
	# On the south wall between the doors' lamps: sconces, the extinguisher, a print, the
	# cleaner's cart left in the way, a dead plant by the stairs.
	for x in [-6.8, -2.3, 2.1]:
		if _exists("wall_lamp"):
			K.cutout(root, "wall_lamp", _size("wall_lamp", 0.3), Vector3(float(x), 1.75, SOUTH - 0.02), 180.0, false, "Sconce")
			K.cutout(root, "wall_lamp", _size("wall_lamp", 0.3), Vector3(float(x), PLAN.UPPER_Y + 1.75, SOUTH - 0.02), 180.0, false, "Sconce")
	if _exists("fire_extinguisher"):
		K.cutout(root, "fire_extinguisher", _size("fire_extinguisher", 0.6), Vector3(-3.6, 0.7, SOUTH - 0.02), 180.0, false, "Extinguisher")
		K.cutout(root, "fire_extinguisher", _size("fire_extinguisher", 0.6), Vector3(3.2, PLAN.UPPER_Y + 0.7, SOUTH - 0.02), 180.0, false, "Extinguisher")
	if _exists("picture_deer"):
		K.picture(root, "picture_deer", Vector2(0.42, 0.56), Vector3(-0.6, 1.5, SOUTH - 0.006), 180.0, "Deer")
	if _exists("cleaning_cart"):
		K.cutout(root, "cleaning_cart", _size("cleaning_cart", 1.15), Vector3(2.9, 0.0, 3.2), 0.0, true, "Cart")
	if _exists("plastic_plant"):
		K.cutout(root, "plastic_plant", _size("plastic_plant", 0.95), Vector3(5.9, 0.0, 3.3), 0.0, true, "Plant")
	if _exists("hall_plant"):
		K.cutout(root, "hall_plant", _size("hall_plant", 1.05), Vector3(-HALF + 0.55, 0.0, 3.25), 0.0, true, "DeadPlant")
		K.cutout(root, "hall_plant", _size("hall_plant", 1.0), Vector3(-HALF + 0.55, PLAN.UPPER_Y, 3.25), 0.0, true, "DeadPlant")
	if _exists("hall_rubbish"):
		K.cutout(root, "hall_rubbish", _size("hall_rubbish", 0.55), Vector3(3.55, 0.0, 3.32), 0.0, true, "Rubbish")
		K.cutout(root, "hall_rubbish", _size("hall_rubbish", 0.5), Vector3(-4.3, PLAN.UPPER_Y, 3.3), 0.0, true, "Rubbish")
	# The house telephone by the passage, its receiver gone.
	if _exists("hall_phone"):
		var px := PLAN.passage_x() + 1.35
		K.cutout(root, "hall_phone", _size("hall_phone", 0.72), Vector3(px, 1.02, SOUTH - 0.02), 180.0, false, "HousePhone")
		room._hot_box("housephone", Vector3(px, 1.38, SOUTH - 0.06), Vector3(0.42, 0.72, 0.1), [])
	# What the ones in tonight's rooms left out by their doors.
	var taken: Array = PLAN.taken(_night_index())
	for i in taken.size():
		var d := PLAN.hall_door(int(taken[i]))
		var tex := "hall_shoes" if i % 2 == 0 else "hall_tray"
		if _exists(tex):
			K.cutout(root, tex, _size(tex, 0.17 if i % 2 == 0 else 0.24), Vector3(d.x + 0.62, d.y, NORTH + 0.16), 0.0, true, "LeftOut")
	ROOMS.decal(root, "carpet_stain", Vector2(0.8, 0.55), Vector3(-1.4, 0.0, MID), Vector3.UP, 0.7, "Stain")
	ROOMS.decal(root, "carpet_stain", Vector2(0.6, 0.4), Vector3(0.4, PLAN.UPPER_Y, 2.6), Vector3.UP, 2.3, "Stain")
	ROOMS.decal(root, "roach_dead", Vector2(0.06, 0.06), Vector3(-7.2, 0.0, SOUTH - 0.1), Vector3.UP, 0.9, "DeadRoach")


## The windows at the corridor's ends, real views out of the block's end walls.
func _windows(root: Node3D) -> void:
	for y0 in [0.0, PLAN.UPPER_Y]:
		for sx in [-1.0, 1.0]:
			var at := Vector3(float(sx) * (HALF + 0.03), float(y0) + 1.5, MID)
			var w = WINDOW_PORTAL.make(room, root, at, Vector3(float(sx), 0, 0), Vector2(1.1, 1.1), "")
			windows.append(w)


## Six: some nights a line of light under its door.
func _six() -> void:
	var d := PLAN.hall_door(PLAN.NEVER)
	_six_gap = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(DOOR_W - 0.04, 0.014)
	_six_gap.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.86, 0.58)
	_six_gap.material_override = m
	_six_gap.position = Vector3(d.x, d.y + 0.008, NORTH + 0.012)
	_six_gap.set_meta("retro_skip", true)
	_six_gap.visible = false
	room._root.add_child(_six_gap)
	_six_light = OmniLight3D.new()
	_six_light.light_color = Color(1.0, 0.86, 0.58)
	_six_light.light_energy = 0.3
	_six_light.omni_range = 1.1
	_six_light.position = Vector3(d.x, d.y + 0.06, NORTH + 0.14)
	_six_light.visible = false
	room._root.add_child(_six_light)


func _night_index() -> int:
	var trip = room.get_parent()
	return int(trip._night_index(_now())) if trip != null and trip.has_method("_night_index") else 1


func _now() -> float:
	var trip = room.get_parent()
	return float(trip.hour()) if trip != null and trip.has_method("hour") else float(room.hour)


func _light(hour: float) -> void:
	var env: Environment = room._env
	env.ambient_light_color = Color(0.82, 0.78, 0.66)
	env.ambient_light_energy = 0.14
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.26, 0.2)
	env.fog_light_energy = 1.0
	env.fog_density = 0.03
	env.fog_sky_affect = 0.0
	var six: bool = PLAN.six_lit(_night_index(), hour) and (block == null or int(block.get("six_dark_night")) != _night_index())
	_six_gap.visible = six
	_six_light.visible = six


# ── sound ────────────────────────────────────────────────────────────────────

func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	room.add_child(p)
	_players.append(p)
	return p


func _loop(p: AudioStreamPlayer, path: String, db: float) -> void:
	if not ResourceLoader.exists(SFX + path):
		return
	if p.stream == null or p.stream.resource_path != SFX + path:
		var s = load(SFX + path)
		if s is AudioStreamOggVorbis:
			s = (s as AudioStreamOggVorbis).duplicate()
			s.loop = true
		p.stream = s
	p.volume_db = db
	if not p.playing:
		p.play()


func _sounds() -> void:
	_amb = _player(-24.0)
	_behind = _player(-40.0)
	_fx = _player(-8.0)
	_loop(_amb, "motel/room_night.ogg", -24.0)
	_loop(_behind, "motel/neighbour_tv.ogg", -60.0)
	# Somebody's music, faint along the corridor at night (motel_view: through the wall).
	if room.hour >= 19.0 or room.hour < 6.0:
		_wall_snd = _player(-30.0)
		_loop(_wall_snd, "motel/wall_music.ogg", -30.0)


func _fx_play(path: String, db: float) -> void:
	if not ResourceLoader.exists(SFX + path):
		return
	_fx.stream = load(SFX + path)
	_fx.volume_db = db
	_fx.play()


# ── each frame ───────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_t += delta
	var world: World3D = block.get_world_3d() if block != null and is_instance_valid(block) and block.is_inside_tree() else null
	var xf := _xform()
	for w in windows:
		w.update(room._root, room._cam, xf, world != null, world, delta, block)
	for lp in _lamps:
		if bool(lp["dying"]):
			var k := fmod(floorf(_t * 12.0) * 0.37 + float(lp["phase"]), 7.3)
			(lp["light"] as OmniLight3D).visible = k > 0.9 and not (k > 3.1 and k < 3.5)
	_tick_behind()
	if _crew != null:
		_crew.tick(delta)


## Behind a taken room's door as you pass: its set, muffled.
func _tick_behind() -> void:
	var night := _night_index()
	var taken: Array = PLAN.taken(night)
	var eye: Vector3 = room._cam.position
	var near := 99.0
	for n in taken:
		var d := PLAN.hall_door(int(n))
		if absf(d.y + EYE - eye.y) > 1.0:
			continue
		near = minf(near, absf(d.x - eye.x))
	_behind.volume_db = lerpf(-22.0, -60.0, clampf(near / 3.0, 0.0, 1.0))
	if _wall_snd != null:
		_wall_snd.volume_db = lerpf(-23.0, -32.0, clampf(near / 7.0, 0.0, 1.0))


# ── clicks ───────────────────────────────────────────────────────────────────

func click(id: String, _hour: float) -> bool:
	if _walker == null:
		return false
	if _walker.busy or _busy_door:
		return true
	if id == "lobby":
		_walker.go("lobby", func(): _to_lobby(), TO_LOBBY)
		return true
	if id == "housephone":
		_walker.go("junction", func(): _fx_play("phone/dead.mp3", -13.0), Vector3(deg_to_rad(-8.0), deg_to_rad(-140.0), 0.0))
		return true
	if id.begins_with("door"):
		var n := int(id.substr(4))
		_walker.go(spot_of(n), func(): _try(n))
		return true
	return false


func _to_lobby() -> void:
	_fx_play("backroom/room_door_open.mp3", -8.0)
	room.go_to("motel", 0, "hall")


## At door `n`: yours opens; the others do not.
func _try(n: int) -> void:
	var trip = room.get_parent()
	if trip != null and trip.has_method("may_enter") and bool(trip.may_enter(n)):
		_busy_door = true
		_fx_play("motel/lock_turn.mp3", -4.0)
		var pv: Node3D = _doors[n]
		var tw: Tween = room.create_tween()
		tw.tween_interval(0.25)
		tw.tween_property(pv, "rotation:y", deg_to_rad(82.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			_busy_door = false
			room.go_to("motel_room", n, ""))
		return
	_fx_play("director/knock_wrong.mp3", -9.0)
	if n == PLAN.NEVER and block != null and is_instance_valid(block):
		# Six's light, if it is on, goes out.
		block.set("six_dark_night", _night_index())
		_six_gap.visible = false
		_six_light.visible = false


## Esc or the corridor's way out: back to the reception, on foot.
func wants_out() -> bool:
	if _walker != null:
		_walker.stop()
	_to_lobby()
	return false


func walk_out() -> void:
	if _walker == null or _walker.busy:
		return
	_walker.go("lobby", func(): _to_lobby(), TO_LOBBY)


# ── co-op ────────────────────────────────────────────────────────────────────

## The other wardens in the corridor: standing where they last went (town_trip keeps each
## one's spot), walking when they walk (room_mates.gd).
func place_mates(mates: Dictionary, ids: Array) -> void:
	var trip = room.get_parent()
	for id in ids:
		var i := int(id)
		var fig = mates.get(i)
		if fig != null:
			_crew.put(i, fig, str(trip.mate_spot(i)) if trip != null and trip.has_method("mate_spot") else "lobby")


## Warden `id` has set off to `spot`: along the corridor's ways.
func mate_walk(id: int, spot: String) -> void:
	_crew.walk(id, spot)


## Warden `id` is gone from the corridor: through their room's door, or to the reception.
## Their figure is this view's to end.
func mate_leaves(id: int, fig: Node, where: String) -> bool:
	if not _crew.mates.has(id):
		return false
	var gone := func():
		if is_instance_valid(fig):
			fig.queue_free()
	var n := int(where.substr(11)) if where.begins_with("motel_room:") else 0
	if n > 0 and _doors.has(n):
		var pv: Node3D = _doors[n]
		var tw: Tween = room.create_tween()
		tw.tween_property(pv, "rotation:y", deg_to_rad(82.0), 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.9)
		tw.tween_property(pv, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
		var d := PLAN.hall_door(n)
		_crew.leave(id, [Vector3(d.x, d.y, NORTH + 0.5), Vector3(d.x, d.y, NORTH - 0.3)], gone)
		_fx_play("motel/lock_turn.mp3", -12.0)
		return true
	# Back to the reception, along the corridor.
	var path: Array = []
	for sp in WALK.route(spots(), ways(), _crew._nearest(_crew.mates[id]["at"]), "lobby"):
		path.append(_crew.feet(str(sp)))
	_crew.leave(id, path, gone)
	return true


func close() -> void:
	for w in windows:
		w.free_all()
	windows.clear()
	if _walker != null:
		_walker.stop()
		_walker.free_all()
	for p in _players:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_players.clear()
	room._env.fog_enabled = false
