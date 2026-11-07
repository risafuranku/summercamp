extends Node3D

## The Liblice motel in the village (the user, 3. 11. 2026: "the whole gallery of rooms";
## 4. 11.: "it should work like in some RPG", a corridor inside), built from its one plan
## (motel_plan.gd) by town_lesna._motel: two floors of rooms along the front with only
## their windows on the car park (their doors are on the corridor inside, motel_hall.gd),
## the reception's door at the west end, MOTEL in tubes on the roof. The windows are holes
## with glass and the rooms behind them (motel_rooms.gd, the same rooms you go into): by
## day the empty ones made up, at night the taken ones lit behind their curtains till
## their lamps go out; the reception keeps its light on. Yours is lit while a warden is in
## it awake; number six some nights though nobody is (motel_plan.six_lit). The car park
## before it: its sodium lamps, a couple of old cars, the bins: what you see out of the
## windows at night.
##
## Its own space is motel space (the block's middle on the ground, the front to -z); it
## stands in the village's frame unturned.

const TOWN_CAR := preload("res://scripts/town/town_car.gd")
const PLAN = preload("res://scripts/town/motel_plan.gd")
const ROOMS = preload("res://scripts/town/motel_rooms.gd")
const K = preload("res://scripts/interior_kit.gd")
const TEX_TOWN := "res://assets/textury/town/"
const TEX_CAMP := "res://assets/textury/camp/"
## The glass in the window frame's picture (town/motel_window.png): its share of the
## picture across and down, its middle's height in it from the top.
const FRAME_GLASS := Vector2(0.696, 0.739)
const FRAME_GLASS_MID := 0.4715

## town_lesna.gd: its materials, lettering and click boxes.
var town
## n (0 the reception) -> {"root": Node3D, "key": the state it was built for}.
var shells: Dictionary = {}
## n -> the door's leaf (Node3D), opened when you go in.
var leaves: Dictionary = {}
var neon: StandardMaterial3D
var _plaster: StandardMaterial3D
var _lobby_light: OmniLight3D
## The car park's lamps (on after dark).
var _yard_lights: Array = []
## Who is in which room now and awake (n -> true), set by town_trip each second.
var awake_in: Dictionary = {}
## The keys on the board (the reception's shell shows them).
var keys_on_board: Array = []
## The night six's door was tried (its light, if on, went out for the rest of it).
var six_dark_night := -999
## What the nights left in a room (motel_view.marks: n -> {"painting", "stain"}): its shell
## shows it too.
var marks: Dictionary = {}
var _last_state := ""


func build(p_town) -> void:
	town = p_town
	name = "Motel"
	_plaster = _triplanar(TEX_TOWN + "motel_plaster.png", 2.4, Color(0.97, 0.94, 0.88))
	_walls()
	_front()
	_roof()
	_doors_and_windows()
	_lights()
	_car_park()
	_clicks()
	set_state(12.0, 1)


## A wall material mapped by the world (pieces of any size join up), like K.surface for a
## texture outside the camp folder.
func _triplanar(path: String, metres: float, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE / metres
	return m


func _flat(path: String, tint := Color(1, 1, 1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	return m


# ── the shell ───────────────────────────────────────────────────────────────

## The back and the ends (the back's rooms are the old painted front), the floors between,
## one solid box inside so nobody walks in through a door or a window.
func _walls() -> void:
	var s := PLAN.SIZE
	var painted := _flat(TEX_TOWN + "motel_front.png", Color(0.82, 0.76, 0.68))
	painted.uv1_scale = Vector3(2.0, 1.0, 1.0)
	var back := K.slab(self, Vector3(s.x, s.y, 0.2), Vector3(0, s.y * 0.5, s.z * 0.5 - 0.1), _plaster, "WallBack")
	back.set_meta("no_wear", true)
	var bq := _quad(painted, Vector2(s.x, s.y), Vector3(0, s.y * 0.5, s.z * 0.5 + 0.01), Vector3(0, 0, 1))
	bq.name = "BackFront"
	for sx in [-1.0, 1.0]:
		K.slab(self, Vector3(0.2, s.y, s.z), Vector3(sx * (s.x * 0.5 - 0.1), s.y * 0.5, 0), _plaster, "WallEnd")
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(s.x, s.y, s.z - 0.15)
	cs.shape = bx
	solid.add_child(cs)
	solid.position = Vector3(0, s.y * 0.5, 0.075)
	add_child(solid)


## The front: two storeys of plaster cut round every window and the reception's door, a
## concrete band between them, the parapet over the top.
func _front() -> void:
	var s := PLAN.SIZE
	var half := s.x * 0.5
	var band := 0.2
	for up in [false, true]:
		var y0 := PLAN.UPPER_Y if up else 0.0
		var hgt := (s.y - 0.2 - PLAN.UPPER_Y) if up else (PLAN.UPPER_Y - band)
		var holes: Array = []
		for b in PLAN.BAYS:
			var x0 := PLAN.bay_x0(b)
			if not up and b == PLAN.LOBBY_DOOR_BAY:
				holes.append([x0 + PLAN.DOOR.x, x0 + PLAN.DOOR.y, 0.0, PLAN.DOOR_H])
			holes.append([x0 + PLAN.WIN.x, x0 + PLAN.WIN.y, PLAN.WIN_Y.x, PLAN.WIN_Y.y])
		for p in K.wall_pieces(half, hgt, holes):
			var a0: float = p[0]
			var a1: float = p[1]
			var b0: float = p[2]
			var b1: float = p[3]
			var piece := K.slab(self, Vector3(a1 - a0, b1 - b0, PLAN.WALL), Vector3((a0 + a1) * 0.5, y0 + (b0 + b1) * 0.5, PLAN.FRONT_Z + PLAN.WALL * 0.5), _plaster, "Front")
			piece.set_meta("no_wear", true)
	# The band between the storeys and the parapet.
	var concrete := _triplanar(TEX_CAMP + "concrete.png", 2.0, Color(0.86, 0.84, 0.8))
	K.slab(self, Vector3(s.x, band, PLAN.WALL), Vector3(0, PLAN.UPPER_Y - band * 0.5, PLAN.FRONT_Z + PLAN.WALL * 0.5), concrete, "Band")
	K.slab(self, Vector3(s.x + 0.3, 0.25, PLAN.WALL + 0.25), Vector3(0, s.y - 0.075, PLAN.FRONT_Z + PLAN.WALL * 0.5 - 0.05), concrete, "Parapet")


## A quad of `mat` facing `facing` (motel space).
func _quad(mat: Material, size: Vector2, pos: Vector3, facing: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = atan2(facing.x, facing.z)
	add_child(mi)
	return mi


func _solid(at: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	body.add_child(cs)
	body.position = at
	body.rotation = rot
	add_child(body)
	return body


## The flat roof and its things: MOTEL in tubes on brackets over the reception, LIBLICE
## in white metal beside it.
func _roof() -> void:
	var s := PLAN.SIZE
	K.slab(self, Vector3(s.x + 0.3, 0.2, s.z + 0.3), Vector3(0, s.y + 0.1, 0), _flat("", Color(0.32, 0.3, 0.28)), "Roof")
	var dark := _flat("", Color(0.16, 0.16, 0.17))
	var fz := PLAN.FRONT_Z + 0.35
	for x in [-8.2, -5.4, -1.9]:
		K.slab(self, Vector3(0.08, 1.5, 0.08), Vector3(x, s.y + 0.75, fz + 0.12), dark, "Bracket")
	K.slab(self, Vector3(7.2, 0.08, 0.08), Vector3(-5.0, s.y + 0.3, fz + 0.12), dark, "Bracket")
	if town != null:
		var sign_mesh = town._letters(self, "motel", Vector3(-6.6, s.y + 0.7, fz), Vector3(0, 0, -1))
		town._letters(self, "motel_lesna", Vector3(-2.4, s.y + 0.45, fz), Vector3(0, 0, -1))
		if sign_mesh != null:
			sign_mesh.name = "MotelSign"
			neon = sign_mesh.material_override
		# RECEPCE over its door.
		var d := PLAN.door_at(PLAN.LOBBY_DOOR_BAY, false)
		town._letters(self, "recepce", Vector3(d.x, PLAN.DOOR_H + 0.32, PLAN.FRONT_Z - 0.01), Vector3(0, 0, -1))


# ── doors and windows ───────────────────────────────────────────────────────

func _doors_and_windows() -> void:
	var ws := PLAN.window_size()
	var frame_mat := _flat(TEX_TOWN + "motel_window.png")
	frame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	frame_mat.alpha_scissor_threshold = 0.5
	frame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.24, 0.29, 0.32, 0.14)
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.set_meta("retro_skip", true)
	var size := Vector2(ws.x / FRAME_GLASS.x, ws.y / FRAME_GLASS.y)
	for b in PLAN.BAYS:
		for up in [false, true]:
			var wc := PLAN.window_at(b, up)
			# The glass's middle in the picture is a little over the picture's own.
			var fr := _quad(frame_mat, size, Vector3(wc.x, wc.y - (0.5 - FRAME_GLASS_MID) * size.y, PLAN.FRONT_Z - 0.012), Vector3(0, 0, -1))
			fr.name = "WindowFrame"
			var g := _quad(glass, ws, Vector3(wc.x, wc.y, PLAN.FRONT_Z + 0.07), Vector3(0, 0, -1))
			g.name = "Glass"
			g.set_meta("retro_skip", true)
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The one door on the front: the reception's glass one.
	leaves[0] = _leaf(PLAN.door_at(PLAN.LOBBY_DOOR_BAY, false), TEX_TOWN + "motel_lobby_door.png")


## A door's leaf in its hole, hinged on its west side (a pivot node at the hinge): its
## picture to the car park, plain veneer inside.
func _leaf(at: Vector3, tex: String) -> Node3D:
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(at.x - 0.45, at.y, PLAN.FRONT_Z + 0.12)
	add_child(hinge)
	K.slab(hinge, Vector3(0.9, PLAN.DOOR_H, 0.04), Vector3(0.45, PLAN.DOOR_H * 0.5, 0.0), K.surface("veneer_dark", 0.6), "Leaf")
	var face := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, PLAN.DOOR_H)
	face.mesh = q
	face.material_override = _flat(tex)
	face.position = Vector3(0.45, PLAN.DOOR_H * 0.5, -0.025)
	face.rotation.y = PI
	face.name = "Face"
	hinge.add_child(face)
	return hinge


## Swing door `n`'s leaf open (inwards) or shut, in the camp's twelve steps a second.
func swing(n: int, open: bool) -> void:
	var h: Node3D = leaves.get(n)
	if h == null:
		return
	var tw := create_tween()
	tw.tween_property(h, "rotation:y", -1.35 if open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)


# ── light ───────────────────────────────────────────────────────────────────

func _lights() -> void:
	var d := PLAN.door_at(PLAN.LOBBY_DOOR_BAY, false)
	_lobby_light = OmniLight3D.new()
	_lobby_light.light_color = Color(1.0, 0.78, 0.5)
	_lobby_light.light_energy = 0.9
	_lobby_light.omni_range = 7.0
	_lobby_light.position = Vector3(d.x, 2.6, PLAN.FRONT_Z - 0.6)
	_lobby_light.visible = false
	add_child(_lobby_light)


## The click box on the reception's door (town_lesna._click: "town_door", "motel"), in the
## village's frame.
func _clicks() -> void:
	if town == null:
		return
	var d := PLAN.door_at(PLAN.LOBBY_DOOR_BAY, false)
	town._click(position + d + Vector3(0, 1.1, -0.25), Vector3(1.1, 2.2, 0.5), "town_door", "motel")


## Where you stand at the reception's door outside (village frame), facing it.
func door_spot(_n := 0) -> Vector3:
	return position + PLAN.door_at(PLAN.LOBBY_DOOR_BAY, false) + Vector3(0, 0, -1.0)


## Before the windows: the car park's sodium lamps and what stands under them, a couple of
## old cars, the bins. Sprites on the ground, what the rooms look out on at night.
func _car_park() -> void:
	var fz := PLAN.FRONT_Z
	for at in [Vector3(-1.2, 0.0, fz - 7.2), Vector3(7.4, 0.0, fz - 7.2)]:
		_yard_sprite("sodium_lamp", 6.2, at)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 4.4
		l.omni_range = 15.0
		l.omni_attenuation = 1.1
		l.position = (at as Vector3) + Vector3(0.6, 5.7, 0.4)
		l.visible = false
		add_child(l)
		_yard_lights.append(l)
	# The yard is asphalt; the cars stand on it, not pictures turning after you; you go round
	# them, the bin and the lamps.
	var yard := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20.0, 6.4)
	yard.mesh = pm
	var ym := StandardMaterial3D.new()
	ym.albedo_texture = load("res://assets/textury/town/asphalt.png")
	ym.albedo_color = Color(0.7, 0.7, 0.7)
	ym.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ym.uv1_scale = Vector3(6.0, 2.0, 1.0)
	ym.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	yard.material_override = ym
	yard.position = Vector3(3.0, 0.015, fz - 4.4)
	yard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(yard)
	for c in [["parked_car_a", Vector3(2.8, 0.0, fz - 3.6), 1.46], ["parked_car_b", Vector3(9.3, 0.0, fz - 4.4), 1.68]]:
		var car: Node3D = TOWN_CAR.make(Color.WHITE, str(c[0]))
		car.position = c[1]
		car.rotation.y = float(c[2])
		add_child(car)
		TOWN_CAR.parked(car)
	_yard_sprite("dumpster", 1.5, Vector3(-3.6, 0.0, fz - 1.5))
	_solid(Vector3(-3.6, 0.75, fz - 1.5), Vector3(1.8, 1.5, 1.2))
	for at in [Vector3(-1.2, 0.0, fz - 7.2), Vector3(7.4, 0.0, fz - 7.2)]:
		_solid(at + Vector3(0, 2.6, 0), Vector3(0.3, 5.2, 0.3))


func _yard_sprite(tex: String, height: float, at: Vector3) -> Sprite3D:
	var path := "res://assets/textury/town/" + tex + ".png"
	if not ResourceLoader.exists(path):
		return null
	var t: Texture2D = load(path)
	var sp := Sprite3D.new()
	sp.name = "Yard"
	sp.texture = t
	sp.pixel_size = height / float(t.get_height())
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.shaded = true
	sp.offset = Vector2(0, t.get_height() * 0.5)
	sp.position = at
	add_child(sp)
	return sp


# ── the rooms behind the windows ────────────────────────────────────────────

## What each room looks like now: the hour, the night's index (the taken rooms, six).
## Rebuilds only the rooms whose look changed.
func set_state(hour: float, night: int) -> void:
	var is_night := hour >= 19.5 or hour < 6.5
	if neon != null:
		neon.emission_energy_multiplier = 1.8 if (hour >= 19.0 or hour < 6.0) else 0.0
	if _lobby_light != null:
		_lobby_light.visible = hour >= 19.0 or hour < 6.5
		for l in _yard_lights:
			(l as Node3D).visible = _lobby_light.visible
	var taken: Array = PLAN.taken(night)
	var hrs := hour if hour >= 12.0 else hour + 24.0
	var states := {}
	for n in PLAN.ROOMS:
		var st := {"lit": false, "curtain": 1.0, "made": true, "glow": false}
		if n == PLAN.NEVER:
			st["curtain"] = 0.0
			st["glow"] = PLAN.six_lit(night, hour) and night != six_dark_night
		elif awake_in.get(n, false) and is_night:
			st["lit"] = true
			st["curtain"] = 0.0
		elif taken.has(n):
			st["made"] = false
			if is_night:
				st["curtain"] = 0.0
				st["lit"] = hrs < PLAN.lights_out(night, n) and hrs >= 19.5
			else:
				st["curtain"] = 0.6
		st.merge(marks.get(n, {}), true)
		states[n] = st
	states[0] = {"lit": hour >= 18.0 or hour < 7.0, "keys": keys_on_board.duplicate()}
	for n in states:
		var key := str(states[n])
		var cur: Dictionary = shells.get(n, {})
		if cur.get("key", "") == key:
			continue
		if cur.has("root") and is_instance_valid(cur["root"]):
			(cur["root"] as Node3D).queue_free()
		var root := Node3D.new()
		root.name = "Room%d" % n
		root.position = PLAN.lobby_origin() if n == 0 else PLAN.room_origin(n)
		add_child(root)
		if n == 0:
			var lob: Dictionary = ROOMS.build_lobby(root, false, states[n].get("keys", []), states[n])
			_simek_in(root, lob.get("simek", Vector3.ZERO), bool(states[n].get("lit", false)))
		else:
			ROOMS.build_room(root, n, false, states[n])
		for g in root.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shells[n] = {"root": root, "key": key}


## Simek behind his counter, seen from the car park (lit with his room at night).
func _simek_in(root: Node3D, at: Vector3, lit: bool) -> void:
	var path := "res://assets/textury/npc/town_motel.png"
	if not ResourceLoader.exists(path):
		return
	var t: Texture2D = load(path)
	var sp := Sprite3D.new()
	sp.name = "Simek"
	sp.texture = t
	sp.pixel_size = 1.7 / float(t.get_height())
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.shaded = not lit
	sp.modulate = Color(1.0, 0.86, 0.66) if lit else Color(1, 1, 1)
	sp.offset = Vector2(0, t.get_height() * 0.5)
	sp.position = at
	root.add_child(sp)


## A room's shell (hidden from its own windows' view while you are in it).
func shell(n: int) -> Node3D:
	var cur: Dictionary = shells.get(n, {})
	return cur.get("root") as Node3D if cur.has("root") and is_instance_valid(cur["root"]) else null
