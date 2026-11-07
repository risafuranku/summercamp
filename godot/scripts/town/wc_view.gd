extends RefCounted

## The toilet of Liblice's Benzina (the door on the kiosk's east side, town_lesna._station;
## town_room.gd's place "wc"), a room the size of a cupboard: tiles to above your head gone
## yellow, black in the grout, brown under the rust, flaking paint over them, a bare bulb
## on a frayed cord with flies round it, a window nobody can see through, the stained bowl
## with its seat off one hinge, the iron cistern high on the wall that drips, a basin, a
## mirror gone black, a hand dryer that coughs and does nothing, a roll holder with nothing
## on it, a mop in its bucket, things scratched into the tiles.
##
## Clicks: the bowl and the mop are the warden's own remark and nothing else; the chain
## rattles and chokes; the tap squeaks and gives two drops; the dryer coughs; the holder
## rattles; the switch is the bulb's and nothing else's (the window's light stays). Now
## and then, the worse you are (the hidden sanity), somebody outside tries the handle, once.
## Room space: the middle of the floor, the door at +z behind you, the bowl at -z.

const K = preload("res://scripts/interior_kit.gd")
const SFX := "res://assets/sfx/"
const CAMP := "res://assets/textury/camp/"
const ROOM := Vector3(2.0, 2.45, 2.7)
## How high the tiles go; the paint over them.
const TILE_H := 1.8
const STAND := Vector3(0.05, 1.58, 0.72)
const BULB := Vector3(0.0, 2.03, -0.2)
const BOWL := Vector3(-0.1, 0.0, -0.98)
const CISTERN := Vector3(-0.1, 1.8, -1.3)
const MATE_SPOTS := [Vector3(0.48, 0.0, 1.0), Vector3(-0.5, 0.0, 0.95)]
const BULB_ON := 0.95
const QUIP := "Not my job, this one."
## How long the remark stays under the room.
const QUIP_SEC := 3.5

var room
var parts: Dictionary = {}
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _players: Array = []
var _fx: AudioStreamPlayer
var _drip_snd: AudioStreamPlayer
var _buzz: AudioStreamPlayer
var _flies_snd: AudioStreamPlayer
## The bulb: on or off, its light, its picture, the switch's picture, the stutter as it
## comes on, the buzz's dropouts.
var _on := false
var _bulb: MeshInstance3D
var _bulb_light: OmniLight3D
var _switch: MeshInstance3D
var _catch_t := -1.0
var _dip := 0.0
var _dip_wait := 7.0
## The drop off the cistern's lip: its countdown, its fall.
var _drop: MeshInstance3D
var _drop_t := -1.0
var _drip_wait := 1.2
## The flies: {node, phase, r, y}.
var _flies: Array = []
var _fly_tex: Array = []
## What jumps when it is pulled or coughs: {node, base, t}.
var _shakes: Array = []
## The roach that goes when the light comes on.
var _roach: MeshInstance3D
var _roach_tex: Array = []
var _roach_t := -1.0
var _roach_wait := 20.0
var _roach_way: Array = []
## Somebody at the door: the next roll, tried already.
var _handle_roll := 8.0
var _handle_done := false
var _quip_t := -1.0


func _init(p_room, _anchor: Node3D = null, _shell: Node3D = null) -> void:
	room = p_room
	_rng.randomize()


func _exists(tex: String) -> bool:
	return ResourceLoader.exists(CAMP + tex + ".png")


func _size(tex: String, height: float) -> Vector2:
	if _exists(tex):
		var t: Texture2D = load(CAMP + tex + ".png")
		return Vector2(height * float(t.get_width()) / float(t.get_height()), height)
	return Vector2(height, height)


## A keyed picture flat on a surface, `normal` out into the room, its middle at `pos`.
func _decal(tex: String, size: Vector2, pos: Vector3, normal: Vector3, spin := 0.0, tint := Color(1, 1, 1)) -> MeshInstance3D:
	if not _exists(tex):
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Grime"
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := K._base(tint)
	m.albedo_texture = load(CAMP + tex + ".png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	mi.material_override = m
	var z := normal.normalized()
	var up := Vector3.UP if absf(z.y) < 0.9 else Vector3(0, 0, -1)
	var x := up.cross(z).normalized()
	mi.transform = Transform3D(Basis(x, z.cross(x), z).rotated(z, spin), pos + z * 0.006)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room._root.add_child(mi)
	return mi


# ── building ─────────────────────────────────────────────────────────────────

func build_inside(hour: float) -> void:
	var root: Node3D = room._root
	_shell(root)
	_things(root)
	_wall_things(root)
	_grime()
	_make_flies(root)
	_make_roach(root)
	_light(root, hour)
	_sounds()
	room._cam.position = STAND
	# The bowl ahead, the switch on the wall at the edge of your eye.
	room._base_rot = Vector3(deg_to_rad(-9.0), deg_to_rad(15.0), 0.0)
	room._look.yaw_limit_deg = 180.0
	room._look.pitch_up_deg = 52.0
	room._look.pitch_down_deg = 50.0
	_play("town/wc_door.mp3", -7.0)


func _shell(root: Node3D) -> void:
	var w := ROOM.x
	var h := ROOM.y
	var d := ROOM.z
	var tiles := K.surface("wc_tiles", 1.1, Color(0.76, 0.73, 0.64))
	var paint := K.surface("wc_ceiling", 1.3, Color(0.74, 0.74, 0.68))
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), K.surface("wc_floor", 1.0), "Floor")
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, h + 0.05, 0), K.surface("wc_ceiling", 1.2), "Ceiling")
	var up := h - TILE_H
	for wall in [[Vector3(w, 1.0, 0.1), Vector3(0, 0, -d * 0.5 - 0.05)], [Vector3(w, 1.0, 0.1), Vector3(0, 0, d * 0.5 + 0.05)],
			[Vector3(0.1, 1.0, d), Vector3(-w * 0.5 - 0.05, 0, 0)], [Vector3(0.1, 1.0, d), Vector3(w * 0.5 + 0.05, 0, 0)]]:
		var size: Vector3 = wall[0]
		var at: Vector3 = wall[1]
		K.slab(root, Vector3(size.x, TILE_H, size.z), at + Vector3(0, TILE_H * 0.5, 0), tiles, "Tiles")
		K.slab(root, Vector3(size.x, up, size.z), at + Vector3(0, TILE_H + up * 0.5, 0), paint, "Paint")
	# The top row of tiles' edge, a pipe along the wall from the cistern to the corner.
	var rust := K.surface("galvanized", 0.35, Color(0.62, 0.42, 0.3))
	var pipe_from := CISTERN.x + 0.26
	K.slab(root, Vector3(w * 0.5 - pipe_from, 0.05, 0.05), Vector3((w * 0.5 + pipe_from) * 0.5, 2.18, -d * 0.5 + 0.05), rust, "Pipe")
	K.slab(root, Vector3(0.05, 0.05, d), Vector3(w * 0.5 - 0.05, 2.18, 0), rust, "Pipe")
	# The door you came in by, behind you.
	var door := K.picture(root, "wc_door_in", Vector2(1.14, 2.03), Vector3(0, 1.015, d * 0.5 - 0.01), 180.0, "Door")
	parts["door"] = door
	room._hot_box("door", Vector3(0, 1.02, d * 0.5 - 0.05), Vector3(1.1, 2.05, 0.1), [door])


func _things(root: Node3D) -> void:
	var back := -ROOM.z * 0.5
	var bs := _size("wc_toilet", 0.86)
	var bowl := K.cutout(root, "wc_toilet", bs, BOWL, 0.0, false, "Toilet")
	room._hot_box("toilet", BOWL + Vector3(0, 0.42, 0), Vector3(maxf(0.6, bs.x), 0.86, 0.5), [bowl])
	# The cistern high on the wall, its pipe down behind the bowl.
	K.slab(root, Vector3(0.05, 1.12, 0.05), Vector3(CISTERN.x, 1.0, back + 0.06), K.surface("galvanized", 0.35, Color(0.6, 0.42, 0.3)), "DownPipe")
	var cs := _size("wc_cistern", 0.56)
	var cistern := K.cutout(root, "wc_cistern", cs, CISTERN, 0.0, false, "Cistern")
	parts["cistern"] = cistern
	room._hot_box("cistern", CISTERN + Vector3(0, 0.1, 0.1), Vector3(cs.x, 0.76, 0.24), [cistern])
	# The mop and its bucket in the corner by the bowl.
	var ms := _size("wc_mop", 0.98)
	var mop := K.cutout(root, "wc_mop", ms, Vector3(ROOM.x * 0.5 - 0.32, 0.0, back + 0.3), -18.0, false, "Mop")
	room._hot_box("mop", Vector3(ROOM.x * 0.5 - 0.32, 0.45, back + 0.3), Vector3(0.5, 0.95, 0.4), [mop])
	# The drop that falls off the cistern's lip.
	_drop = MeshInstance3D.new()
	_drop.name = "Drop"
	var q := QuadMesh.new()
	q.size = Vector2(0.014, 0.05)
	_drop.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.56, 0.5, 0.42)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_drop.material_override = m
	_drop.visible = false
	_drop.set_meta("retro_skip", true)
	root.add_child(_drop)


## The basin and the mirror, the dryer, the holder, the switch, the window.
func _wall_things(root: Node3D) -> void:
	var ex := ROOM.x * 0.5
	var wx := -ROOM.x * 0.5
	var basin := K.cutout(root, "wc_basin", _size("wc_basin", 0.5), Vector3(ex - 0.06, 0.68, -0.3), -90.0, false, "Basin")
	room._hot_box("basin", Vector3(ex - 0.1, 0.92, -0.3), Vector3(0.3, 0.5, 0.56), [basin])
	K.cutout(root, "wc_mirror", _size("wc_mirror", 0.46), Vector3(ex - 0.02, 1.26, -0.3), -90.0, false, "Mirror")
	var ds := _size("wc_dryer", 0.34)
	var dryer := K.cutout(root, "wc_dryer", ds, Vector3(ex - 0.02, 1.16, 0.46), -90.0, false, "Dryer")
	parts["dryer"] = dryer
	room._hot_box("dryer", Vector3(ex - 0.05, 1.33, 0.46), Vector3(0.14, 0.36, 0.4), [dryer])
	var holder := K.cutout(root, "wc_roll", _size("wc_roll", 0.13), Vector3(wx + 0.02, 0.74, -0.72), 90.0, false, "Holder")
	room._hot_box("roll", Vector3(wx + 0.05, 0.8, -0.72), Vector3(0.12, 0.2, 0.34), [holder])
	var ss := _size("wc_switch_off", 0.1)
	_switch = K.cutout(root, "wc_switch_off", ss, Vector3(wx + 0.02, 1.3, 0.34), 90.0, false, "Switch")
	room._hot_box("switch", Vector3(wx + 0.05, 1.35, 0.34), Vector3(0.1, 0.18, 0.18), [_switch])
	var win := K.picture(root, "wc_window", Vector2(0.56, 0.56), Vector3(wx + 0.015, 2.04, -0.4), 90.0, "Window")
	parts["window"] = win


## What the place left on its walls and floor: the scratches, the damp, the stains.
func _grime() -> void:
	var ex := ROOM.x * 0.5
	var wx := -ROOM.x * 0.5
	var back := -ROOM.z * 0.5
	var cut := Color(0.34, 0.3, 0.26)
	var mould := Color(0.7, 0.72, 0.66)
	_decal("wc_scratch_0", Vector2(0.34, 0.4), Vector3(wx, 1.34, -0.12), Vector3(1, 0, 0), 0.0, cut)
	_decal("wc_scratch_1", Vector2(0.3, 0.3), Vector3(wx, 0.98, 0.1), Vector3(1, 0, 0), 0.0, cut)
	_decal("wc_scratch_2", Vector2(0.28, 0.28), Vector3(ex, 1.02, 0.82), Vector3(-1, 0, 0), 0.0, cut)
	_decal("wc_scratch_3", Vector2(0.4, 0.4), Vector3(0.5, 1.34, back), Vector3(0, 0, 1), 0.0, cut)
	_decal("wc_scratch_1", Vector2(0.26, 0.26), Vector3(-0.62, 1.4, back), Vector3(0, 0, 1), 0.3, cut)
	_decal("decay_stain", Vector2(0.74, 0.58), Vector3(0.66, 2.22, back), Vector3(0, 0, 1), 0.4, Color(0.62, 0.6, 0.54))
	_decal("decay_mould", Vector2(0.5, 0.42), Vector3(ex, 2.1, -0.95), Vector3(-1, 0, 0), 0.8, mould)
	_decal("decay_mould", Vector2(0.42, 0.36), Vector3(wx, 2.12, 0.72), Vector3(1, 0, 0), 2.1, mould)
	_decal("decay_mould", Vector2(0.7, 0.5), Vector3(-0.66, 0.26, back), Vector3(0, 0, 1), 0.3, mould)
	_decal("decay_mould", Vector2(0.62, 0.46), Vector3(wx, 0.24, 0.46), Vector3(1, 0, 0), 1.2, mould)
	_decal("decay_mould", Vector2(0.56, 0.42), Vector3(ex, 0.22, -1.02), Vector3(-1, 0, 0), 2.4, mould)
	_decal("decay_crack", Vector2(0.4, 0.8), Vector3(0.74, 0.7, back), Vector3(0, 0, 1), 0.2, Color(0.5, 0.46, 0.4))
	_decal("ceiling_stain_1", Vector2(1.1, 0.9), Vector3(-0.3, ROOM.y, -0.7), Vector3(0, -1, 0), 0.6)
	_decal("ceiling_stain_0", Vector2(0.7, 0.6), Vector3(0.5, ROOM.y, 0.6), Vector3(0, -1, 0), 2.2)
	var up := Vector3.UP
	_decal("floor_puddle", Vector2(0.95, 0.66), Vector3(-0.06, 0.002, -0.72), up, 0.3, Color(0.72, 0.66, 0.5))
	_decal("floor_puddle", Vector2(0.5, 0.36), Vector3(0.56, 0.002, -0.2), up, 1.9, Color(0.6, 0.6, 0.56))
	_decal("tissue", Vector2(0.16, 0.14), Vector3(-0.6, 0.004, -0.6), up, 0.7)
	_decal("tissue", Vector2(0.12, 0.1), Vector3(0.28, 0.004, -0.4), up, 2.3)
	_decal("roach_dead", Vector2(0.07, 0.07), Vector3(-0.72, 0.004, 0.32), up, 1.2)
	_decal("hair_clump", Vector2(0.12, 0.1), Vector3(0.74, 0.004, 0.34), up, 0.4)
	_decal("wet_footprints", Vector2(0.4, 0.3), Vector3(0.1, 0.003, 0.16), up, 0.1)


## Four or five flies, round the bulb, stepping about; their wings in two pictures.
func _make_flies(root: Node3D) -> void:
	for t in ["wc_fly_0", "wc_fly_1"]:
		if _exists(t):
			_fly_tex.append(load(CAMP + t + ".png"))
	if _fly_tex.is_empty():
		return
	for i in 5:
		var s := Sprite3D.new()
		s.name = "Fly"
		s.texture = _fly_tex[0]
		s.pixel_size = 0.0034
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = false
		s.modulate = Color(0.34, 0.32, 0.3)
		s.set_meta("retro_skip", true)
		root.add_child(s)
		_flies.append({"node": s, "phase": float(i) * 1.3, "r": _rng.randf_range(0.12, 0.42), "y": _rng.randf_range(-0.2, 0.22), "k": _rng.randf_range(0.8, 1.6)})


func _make_roach(root: Node3D) -> void:
	for t in ["roach_0", "roach_1"]:
		if _exists(t):
			_roach_tex.append(load(CAMP + t + ".png"))
	if _roach_tex.size() < 2:
		return
	_roach = MeshInstance3D.new()
	_roach.name = "Roach"
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	_roach.mesh = q
	var m := K._base(Color(1, 1, 1))
	m.albedo_texture = _roach_tex[0]
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	_roach.material_override = m
	_roach.visible = false
	root.add_child(_roach)


# ── light ────────────────────────────────────────────────────────────────────

func _light(root: Node3D, hour: float) -> void:
	var day := hour >= 7.0 and hour < 18.5
	var dusk := (hour >= 18.5 and hour < 20.5) or (hour >= 5.5 and hour < 7.0)
	var col := Color(0.82, 0.88, 0.84) if day else (Color(0.62, 0.46, 0.4) if dusk else Color(0.36, 0.44, 0.62))
	var env: Environment = room._env
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = col
	env.ambient_light_energy = 0.13 if day else (0.09 if dusk else 0.07)
	var win = parts.get("window")
	if win != null:
		var m := (win as MeshInstance3D).material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = m.albedo_texture
		m.emission = col
		m.emission_energy_multiplier = 1.25 if day else (0.9 if dusk else 1.0)
	# By night the window's grey is all there is till you find the switch.
	room._omni(Vector3(-ROOM.x * 0.5 + 0.6, 1.9, -0.4), col, 0.5 if day else (0.3 if dusk else 0.3), 4.0)
	# The bulb on its cord.
	var bs := _size("wc_bulb_off", 0.42)
	_bulb = K.cutout(root, "wc_bulb_off", bs, Vector3(BULB.x, ROOM.y - bs.y, BULB.z), 0.0, true, "Bulb")
	_bulb_light = room._omni(BULB, Color(1.0, 0.8, 0.5), 0.0, 5.0, true)
	_show_bulb(false)


func _show_bulb(lit: bool) -> void:
	var tex := "wc_bulb_on" if lit else "wc_bulb_off"
	if _bulb != null and _exists(tex):
		var m := _bulb.material_override as StandardMaterial3D
		m.albedo_texture = load(CAMP + tex + ".png")
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if lit else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if _bulb_light != null:
		_bulb_light.light_energy = BULB_ON if lit else 0.0


func _flip() -> void:
	_on = not _on
	_play("town/wc_switch.mp3", -6.0)
	var tex := "wc_switch_on" if _on else "wc_switch_off"
	if _switch != null and _exists(tex):
		(_switch.material_override as StandardMaterial3D).albedo_texture = load(CAMP + tex + ".png")
	if _on:
		# It thinks about it, stutters, stays; whatever was out on the floor goes.
		_catch_t = 0.0
		if _roach != null and _roach_t < 0.0:
			_roach_wait = _rng.randf_range(0.2, 0.7)
	else:
		_catch_t = -1.0
		_show_bulb(false)
		if _buzz != null:
			_buzz.stop()


# ── sound ────────────────────────────────────────────────────────────────────

func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	room.add_child(p)
	_players.append(p)
	return p


func _loop(p: AudioStreamPlayer, path: String) -> void:
	if not ResourceLoader.exists(SFX + path):
		return
	var s = load(SFX + path)
	if s is AudioStreamOggVorbis:
		s = (s as AudioStreamOggVorbis).duplicate()
		s.loop = true
	elif s is AudioStreamMP3:
		s = (s as AudioStreamMP3).duplicate()
		s.loop = true
	p.stream = s
	p.play()


func _sounds() -> void:
	_fx = _player(-8.0)
	_drip_snd = _player(-15.0)
	_loop(_player(-24.0), "town/wc_room.ogg")
	_flies_snd = _player(-23.0)
	_loop(_flies_snd, "motel/flies.ogg")
	_buzz = _player(-27.0)


func _play(path: String, db: float) -> void:
	room._play(SFX + path, db)


func _fx_play(path: String, db: float) -> void:
	if _fx != null and ResourceLoader.exists(SFX + path):
		_fx.stream = load(SFX + path)
		_fx.volume_db = db
		_fx.play()


# ── each frame ───────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_t += delta
	var step := floorf(_t * 12.0) / 12.0
	_tick_bulb(delta)
	_tick_drip(delta)
	_tick_roach(delta)
	_tick_handle(delta)
	if _quip_t >= 0.0:
		_quip_t -= delta
		if _quip_t < 0.0:
			room._text = ""
	# The flies, twelve steps a second, round the bulb while it burns, over the bowl when not.
	var centre := BULB if _on else BOWL + Vector3(0, 0.7, 0.1)
	for i in _flies.size():
		var f: Dictionary = _flies[i]
		var n: Sprite3D = f["node"]
		var a := step * float(f["k"]) * 2.4 + float(f["phase"])
		var r := float(f["r"]) * (1.0 + 0.3 * sin(a * 1.7))
		n.position = centre + Vector3(cos(a) * r, float(f["y"]) + sin(a * 2.3) * 0.06, sin(a) * r)
		n.texture = _fly_tex[int(step * 12.0 + float(i)) % _fly_tex.size()]
	for s in _shakes.duplicate():
		var node: Node3D = s["node"]
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.position = s["base"]
			_shakes.erase(s)
			continue
		var kick := Vector3(float(s["x"]), float(s["y"]), 0.0) * sin(floorf(float(s["t"]) * 12.0) * 2.0) * minf(1.0, float(s["t"]) * 2.0)
		node.position = (s["base"] as Vector3) + kick


## The bulb coming on in stutters; lit, now and then it dips and the buzz with it.
func _tick_bulb(delta: float) -> void:
	if _catch_t >= 0.0:
		_catch_t += delta
		var k := int(_catch_t * 12.0)
		_show_bulb(k in [1, 2, 5, 8, 9] or k >= 11)
		if k >= 11:
			_catch_t = -1.0
			_loop(_buzz, "motel/neon_buzz.ogg")
		return
	if not _on or _bulb_light == null:
		return
	if _dip > 0.0:
		_dip -= delta
		_bulb_light.light_energy = BULB_ON * (0.3 if int(_t * 12.0) % 2 == 0 else 0.8)
		if _dip <= 0.0:
			_bulb_light.light_energy = BULB_ON
		return
	_dip_wait -= delta
	if _dip_wait <= 0.0:
		_dip_wait = _rng.randf_range(6.0, 20.0)
		_dip = _rng.randf_range(0.15, 0.5)


func _tick_drip(delta: float) -> void:
	if _drop == null:
		return
	if _drop_t >= 0.0:
		_drop_t += delta
		var top := CISTERN.y + 0.02
		var fall := 0.5 * 9.8 * _drop_t * _drop_t
		_drop.position = Vector3(CISTERN.x + 0.2, top - floorf(fall * 5.0) / 5.0, -ROOM.z * 0.5 + 0.2)
		if top - fall <= 0.72:
			_drop_t = -1.0
			_drop.visible = false
			if _drip_snd != null and ResourceLoader.exists(SFX + "pipes/drip.mp3"):
				_drip_snd.stream = load(SFX + "pipes/drip.mp3")
				_drip_snd.pitch_scale = _rng.randf_range(0.9, 1.1)
				_drip_snd.play()
		return
	_drip_wait -= delta
	if _drip_wait <= 0.0:
		_drip_wait = _rng.randf_range(1.6, 3.8)
		_drop_t = 0.0
		_drop.visible = true


## A roach along the foot of the wall, now and then, and always when the light comes on.
func _tick_roach(delta: float) -> void:
	if _roach == null:
		return
	if _roach_t < 0.0:
		_roach_wait -= delta
		if _roach_wait > 0.0:
			return
		_roach_wait = _rng.randf_range(35.0, 80.0)
		var w := ROOM.x * 0.5 - 0.06
		var ways := [
			[Vector3(-0.2, 0.004, -0.3), Vector3(-0.7, 0.004, -0.9), Vector3(-w, 0.004, -1.32)],
			[Vector3(0.24, 0.004, 0.2), Vector3(0.62, 0.004, -0.5), Vector3(w, 0.004, -1.2)],
			[Vector3(-0.5, 0.004, 0.6), Vector3(-w, 0.004, 0.1), Vector3(-w, 0.004, -0.8)],
		]
		_roach_way = ways[_rng.randi_range(0, ways.size() - 1)]
		_roach_t = 0.0
		_roach.visible = true
		_fx_play("motel/cockroach.mp3", -18.0)
	_roach_t += delta
	var k := _roach_t / 1.5
	if k >= 1.0:
		_roach_t = -1.0
		_roach.visible = false
		return
	var seg := mini(int(k * 2.0), 1)
	var a: Vector3 = _roach_way[seg]
	var b: Vector3 = _roach_way[seg + 1]
	var along := (b - a).normalized()
	var at := a.lerp(b, floorf(clampf(k * 2.0 - float(seg), 0.0, 1.0) * 12.0) / 12.0)
	var x := along.cross(Vector3.UP).normalized()
	_roach.transform = Transform3D(Basis(x, along, Vector3.UP), at)
	(_roach.material_override as StandardMaterial3D).albedo_texture = _roach_tex[int(_roach_t * 16.0) % 2]


## The hidden sanity of this machine's warden (coop_night.gd keeps it, 0..100).
func _low() -> float:
	var trip = room.get_parent()
	var main = trip._main() if trip != null and trip.has_method("_main") else null
	var night = main.get("_coop_night") if main != null else null
	if night == null or not is_instance_valid(night) or not (night.get("sanity") is Dictionary):
		return 0.0
	var s: Dictionary = night.get("sanity")
	return clampf((100.0 - float(s.get("own" if Coop.is_client() else "host", 100.0))) / 100.0, 0.0, 1.0)


## Somebody outside tries the handle: the door shifts in its frame, nobody says anything.
func _tick_handle(delta: float) -> void:
	_handle_roll -= delta
	if _handle_roll > 0.0 or _handle_done:
		return
	_handle_roll = 6.0
	if _t < 12.0 or _rng.randf() > 0.015 + 0.16 * _low():
		return
	_try_handle()


func _try_handle() -> void:
	_handle_done = true
	_fx_play("director/knock_wrong.mp3", -14.0)
	_shake(parts.get("door"), 0.0, 0.004, 0.45)


# ── clicks ───────────────────────────────────────────────────────────────────

func _shake(node, x: float, y: float, seconds: float) -> void:
	if node == null:
		return
	for s in _shakes:
		if s["node"] == node:
			s["t"] = seconds
			return
	_shakes.append({"node": node, "base": (node as Node3D).position, "t": seconds, "x": x, "y": y})


func click(id: String, _hour: float) -> bool:
	match id:
		"toilet":
			_fx_play("town/wc_seat.mp3", -11.0)
			_quip()
		"mop":
			_fx_play("town/wc_mop.mp3", -10.0)
			_quip()
		"cistern":
			_fx_play("town/wc_chain.mp3", -7.0)
			_shake(parts.get("cistern"), 0.0, 0.012, 0.5)
		"dryer":
			_fx_play("town/wc_dryer.mp3", -7.0)
			_shake(parts.get("dryer"), 0.006, 0.0, 1.0)
		"basin":
			_fx_play("town/wc_tap.mp3", -8.0)
		"roll":
			_fx_play("town/wc_roll.mp3", -9.0)
		"switch":
			_flip()
		_:
			return false
	return true


func _quip() -> void:
	room.say("", QUIP)
	_quip_t = QUIP_SEC


func wants_out() -> bool:
	_play("town/wc_door.mp3", -9.0)
	return true


## The other wardens: by the door (there is no other room for them).
func place_mates(mates: Dictionary, ids: Array) -> void:
	var k := 0
	for id in ids:
		var fig = mates.get(int(id))
		if fig == null:
			continue
		fig.visible = true
		fig.show_at(MATE_SPOTS[k % MATE_SPOTS.size()], "stand")
		k += 1


func close() -> void:
	for p in _players:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_players.clear()


## Debug (shots): the handle now.
func debug_handle() -> void:
	_try_handle()


## Debug (shots): the light on at once.
func debug_light(on: bool) -> void:
	if _on != on:
		_flip()
	if on:
		_catch_t = -1.0
		_show_bulb(true)
