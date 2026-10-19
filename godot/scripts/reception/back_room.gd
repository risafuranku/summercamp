extends RefCounted

## The warden's room behind the office: through the door in the office's left wall, a
## small cottage bedroom. A pine bed under a window shut behind heavy velvet drapes,
## a nightstand with the alarm clock and a lamp, a little black-and-white set on a
## chest of drawers at the foot of the bed, a wardrobe and the coats on their hooks.
## Built into the reception's own 3D (it really is behind that wall: the door opens and
## you walk through), so it shares the office's viewport and look-around.
##
## Things to use: the bed (sleep, only when nothing is out there: the host asks main),
## the set (on/off; after midnight only the test card and its tone), the lamp.

const K = preload("res://scripts/interior_kit.gd")
const ROOM_WEATHER = preload("res://scripts/ambient/room_weather.gd")
const RL = preload("res://scripts/reception/reception_layout.gd")
const CURTAIN = preload("res://scripts/reception/curtain.gd")
const TV_SHADER = preload("res://materials/tv_screen.gdshader")
const SEVEN_SEG = preload("res://scripts/ui/seven_seg.gd")
const SFX := "res://assets/sfx/backroom/"
const TESTCARD := "res://assets/textury/camp/tv_testcard.png"
const PROGRAMME := "res://assets/textury/camp/tv_programme.png"

## The room: x from -5.6 to -2.6, z from -0.2 to 2.6 (the office's left wall is x -2.55).
const CENTRE := Vector3(-4.1, 0.05, 1.2)
const SIZE := Vector3(3.0, 2.5, 2.8)
const DOOR_Z := 1.28
## Where you stand just inside the door, and the view from there (toward the bed).
const STAND := Vector3(-3.15, 1.48, 1.32)
const BED := Vector3(-5.1, 0.05, 0.85)
const TV := Vector3(-5.0, 0.81, 2.36)
const CLOCK := Vector3(-4.38, 0.61, -0.02)

var root: Node3D
## The window over the bed (out onto the gate lane): its view quad, its velvet drapes.
var window_quad: MeshInstance3D
var curtain
var hot: Dictionary = {}     # id -> {body, meshes}
var tv_on := true
var lamp_on := true
var lamp: OmniLight3D
var tv_light: OmniLight3D
var bulb: OmniLight3D
var _tv_mat: ShaderMaterial
var _tv_power := 1.0
var _tv_hiss: AudioStreamPlayer3D
var _tv_tone: AudioStreamPlayer3D
var _clock_vp: SubViewport
var _clock_canvas: Control
var _clock_text := ""
var _one: AudioStreamPlayer
var _t := 0.0
var _late := false
var _ceiling_lamp: MeshInstance3D


func build(parent: Node3D, audio_parent: Node) -> void:
	root = Node3D.new()
	root.name = "BackRoom"
	root.position = CENTRE
	parent.add_child(root)
	var walls := K.room(root, SIZE, "planks_dark", "wallpaper_70s", "ceiling_pine", 1.1, 1.0)
	# The wall shared with the office has the doorway in it: replace the solid slab.
	(walls["right"] as Node3D).queue_free()
	# A paper-thin lining just behind the office wall (which is x -2.6..-2.5): sharing the
	# office wall's volume would z-fight with its pine boards.
	var t := 0.01
	var x := SIZE.x * 0.5 - t * 0.5
	var dz := DOOR_Z - CENTRE.z
	var wall := K.surface("wallpaper_70s", 1.1)
	var near_end := -SIZE.z * 0.5
	var far_end := SIZE.z * 0.5
	var a1 := dz - 0.5
	var b1 := dz + 0.5
	K.slab(root, Vector3(t, SIZE.y, a1 - near_end), Vector3(x, SIZE.y * 0.5, (near_end + a1) * 0.5), wall, "WallDoorA")
	K.slab(root, Vector3(t, SIZE.y, far_end - b1), Vector3(x, SIZE.y * 0.5, (b1 + far_end) * 0.5), wall, "WallDoorB")
	K.slab(root, Vector3(t, SIZE.y - 2.1, 1.0), Vector3(x, 2.1 + (SIZE.y - 2.1) * 0.5, dz), wall, "WallDoorTop")
	_cut_window(walls)
	K.skirting(root, SIZE)
	_flat("rug_rag", Vector2(1.25, 1.0), Vector3(-0.2, 0.007, 0.6), false, "Rug")

	var o := -CENTRE
	_prop("bed", "bed_wood", BED + o, 0.0)
	K.prop(root, "pillow", BED + o + Vector3(0, 0.55, -0.72))
	K.slab(root, Vector3(0.86, 0.06, 1.25), BED + o + Vector3(0, 0.57, 0.28), K.surface("blanket_check", 0.6), "Blanket")
	K.slab(root, Vector3(0.05, 0.36, 1.25), BED + o + Vector3(-0.44, 0.42, 0.28), K.surface("blanket_check", 0.6), "BlanketSide")
	K.prop(root, "nightstand", Vector3(-4.38, 0.05, -0.02) + o, 0.0)
	_prop("lamp", "lantern", Vector3(-4.24, 0.6, -0.08) + o, 0.0)
	_prop("tv", "tv_small", TV + o, 180.0)
	K.prop(root, "dresser", Vector3(-5.0, 0.05, 2.36) + o, 180.0)
	K.prop(root, "wardrobe", Vector3(-3.15, 0.05, 0.12) + o, 0.0)
	K.prop(root, "coat_hooks", Vector3(-2.66, 1.55, 2.2) + o, -90.0)
	K.cutout(root, "coat_hook", Vector2(0.42, 0.62), Vector3(-2.64, 0.86, 2.2) + o, -90.0, false, "Coat")
	# The chair with yesterday's clothes thrown over it (a Grok sprite, turned to you).
	K.cutout(root, "chair_clothes", Vector2(0.62, 0.98), Vector3(-3.42, 0.0, 2.18) + o, 0.0, true, "ChairClothes")
	K.picture(root, "picture_deer", Vector2(0.36, 0.48), Vector3(-5.0, 1.62, 2.54) + o, 180.0, "BackPicture")
	# Lived in: Vera and Karel at the lake over the nightstand, the shelf of old books,
	# the slippers by the bed, the light on the ceiling.
	K.picture(root, "photo_family", Vector2(0.3, 0.4), Vector3(-4.42, 1.44, -0.188) + o, 0.0, "FamilyPhoto")
	K.slab(root, Vector3(0.64, 0.64, 0.1), Vector3(-3.95, 1.56, 2.55) + o, K.surface("planks_dark", 0.5), "BookShelfBack")
	K.picture(root, "bookshelf", Vector2(0.62, 0.62), Vector3(-3.95, 1.56, 2.498) + o, 180.0, "BookShelf")
	_flat("slippers", Vector2(0.36, 0.36), Vector3(-4.48, 0.008, 1.5) + o, false, "Slippers")
	_ceiling_lamp = _flat("ceiling_lamp", Vector2(0.38, 0.38), Vector3(0.0, SIZE.y - 0.005, 0.0), true, "CeilingLamp")

	_build_tv_screen()
	_build_clock()

	lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.48)
	lamp.light_energy = 0.9
	lamp.omni_range = 3.6
	lamp.omni_attenuation = 1.3
	lamp.position = Vector3(-4.24, 0.95, -0.02) + o
	lamp.shadow_enabled = true
	root.add_child(lamp)
	bulb = OmniLight3D.new()
	bulb.light_color = Color(0.95, 0.88, 0.7)
	bulb.light_energy = 0.35
	bulb.omni_range = 4.2
	bulb.position = Vector3(-4.1, 2.3, 1.2) + o
	root.add_child(bulb)
	tv_light = OmniLight3D.new()
	tv_light.light_color = Color(0.62, 0.72, 1.0)
	tv_light.light_energy = 0.5
	tv_light.omni_range = 3.0
	tv_light.omni_attenuation = 1.6
	tv_light.position = TV + o + Vector3(0, 0.22, -0.45)
	root.add_child(tv_light)

	_tv_hiss = _loop3d(SFX + "tv_hiss.wav", -22.0)
	_tv_tone = _loop3d(SFX + "tv_tone.wav", -30.0)
	_one = AudioStreamPlayer.new()
	audio_parent.add_child(_one)
	_set_tv(true, false)


## The far wall (over the bed) with the window in it: ReceptionLayout.BACK_WINDOW_*,
## the same opening the building has outside. A frame, a sill, the view, the drapes.
func _cut_window(walls: Dictionary) -> void:
	var far := walls.get("left") as Node3D
	if far != null:
		far.queue_free()
	var t := 0.1
	var x := -SIZE.x * 0.5 - t * 0.5
	var c: Vector3 = RL.BACK_WINDOW_CENTER - CENTRE
	var half_w: float = RL.BACK_WINDOW_SIZE.x * 0.5
	var half_h: float = RL.BACK_WINDOW_SIZE.y * 0.5
	var z0 := c.z - half_w
	var z1 := c.z + half_w
	var y0 := c.y - half_h
	var y1 := c.y + half_h
	var wall := K.surface("wallpaper_70s", 1.1)
	var near := -SIZE.z * 0.5
	var far_z := SIZE.z * 0.5
	K.slab(root, Vector3(t, SIZE.y, z0 - near), Vector3(x, SIZE.y * 0.5, (near + z0) * 0.5), wall, "WallFarA")
	K.slab(root, Vector3(t, SIZE.y, far_z - z1), Vector3(x, SIZE.y * 0.5, (z1 + far_z) * 0.5), wall, "WallFarB")
	K.slab(root, Vector3(t, y0, z1 - z0), Vector3(x, y0 * 0.5, c.z), wall, "WallFarUnder")
	K.slab(root, Vector3(t, SIZE.y - y1, z1 - z0), Vector3(x, (y1 + SIZE.y) * 0.5, c.z), wall, "WallFarOver")
	var frame := K.surface("planks_grey", 0.5, Color(0.92, 0.9, 0.86))
	var fx := -SIZE.x * 0.5 + 0.02
	K.slab(root, Vector3(0.05, y1 - y0 + 0.16, 0.08), Vector3(fx, c.y, z0 - 0.04), frame, "BackWinFrameA")
	K.slab(root, Vector3(0.05, y1 - y0 + 0.16, 0.08), Vector3(fx, c.y, z1 + 0.04), frame, "BackWinFrameB")
	K.slab(root, Vector3(0.05, 0.08, z1 - z0 + 0.16), Vector3(fx, y1 + 0.04, c.z), frame, "BackWinFrameT")
	K.slab(root, Vector3(0.2, 0.05, z1 - z0 + 0.22), Vector3(fx + 0.07, y0 - 0.02, c.z), frame, "BackWinSill")
	K.slab(root, Vector3(0.04, y1 - y0, 0.04), Vector3(fx - 0.03, c.y, c.z), frame, "BackWinBar")
	window_quad = MeshInstance3D.new()
	window_quad.name = "BackWindowView"
	var q := QuadMesh.new()
	q.size = RL.BACK_WINDOW_SIZE
	window_quad.mesh = q
	window_quad.position = Vector3(x + 0.01, c.y, c.z)
	window_quad.rotation_degrees.y = 90.0
	root.add_child(window_quad)
	# Rain on its glass and lightning through it (the office's room_weather has the rest).
	var rw = ROOM_WEATHER.new()
	rw.gloom = false
	rw.sounds = false
	rw.is_open = func(): return is_instance_valid(window_quad) and window_quad.is_visible_in_tree()
	root.add_child(rw)
	rw.add_window(window_quad)
	# The heavy drapes: drawn back (playtest 18. 10.); click to shut them.
	curtain = CURTAIN.new()
	curtain.build(root, Vector3(fx + 0.12, c.y, c.z), RL.BACK_WINDOW_SIZE.x, RL.BACK_WINDOW_SIZE.y + 0.3, 90.0, "velvet", 0.6, root, true)
	var body := StaticBody3D.new()
	body.name = "Hot_back_curtain"
	body.set_meta("extra_hot", "back_curtain")
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.2, RL.BACK_WINDOW_SIZE.y + 0.4, RL.BACK_WINDOW_SIZE.x + 0.5)
	cs.shape = bx
	body.add_child(cs)
	body.position = Vector3(fx + 0.1, c.y, c.z)
	root.add_child(body)
	hot["back_curtain"] = {"body": body, "meshes": curtain.meshes}


## A flat Grok sprite on the floor (or the ceiling, seen from below): a rug, slippers.
func _flat(tex: String, size: Vector2, pos: Vector3, ceiling: bool, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := K._base(Color(1, 1, 1))
	if ResourceLoader.exists(K.TEX + tex + ".png"):
		m.albedo_texture = load(K.TEX + tex + ".png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ceiling:
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = m.albedo_texture
		m.emission = Color(1.0, 0.92, 0.78)
		m.emission_energy_multiplier = 0.7
	mi.material_override = m
	mi.position = pos
	root.add_child(mi)
	return mi


func _prop(id: String, prop_name: String, pos: Vector3, yaw: float) -> Node3D:
	var n := K.prop(root, prop_name, pos, yaw)
	if n == null:
		return null
	var body := StaticBody3D.new()
	body.name = "Hot_" + id
	body.set_meta("extra_hot", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var aabb := _aabb_of(n)
	box.size = aabb.size.max(Vector3(0.2, 0.2, 0.2))
	shape.shape = box
	body.add_child(shape)
	body.position = n.position + aabb.get_center().rotated(Vector3.UP, deg_to_rad(yaw))
	body.rotation_degrees.y = yaw
	root.add_child(body)
	hot[id] = {"body": body, "meshes": [n]}
	return n


static func _aabb_of(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse() if n.is_inside_tree() else Transform3D.IDENTITY
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a := m.get_aabb()
		a = (inv * m.global_transform if n.is_inside_tree() else m.transform) * a
		out = a if first else out.merge(a)
		first = false
	return out


func _loop3d(path: String, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStreamWAV:
			s = (s as AudioStreamWAV).duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		p.stream = s
	p.volume_db = db
	p.unit_size = 1.5
	p.max_distance = 8.0
	p.position = TV - CENTRE + Vector3(0, 0.2, 0)
	root.add_child(p)
	return p


func _build_tv_screen() -> void:
	var tv: Node3D = hot.get("tv", {}).get("meshes", [null])[0]
	_tv_mat = ShaderMaterial.new()
	_tv_mat.shader = TV_SHADER
	var q := MeshInstance3D.new()
	q.name = "TvScreen"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.235, 0.195)
	q.mesh = qm
	q.material_override = _tv_mat
	# The prop faces -Z here (turned 180): the screen sits on its front, slightly left.
	# (The prop's origin is its footprint centre: the tube behind pushes the front 6.5 cm out.)
	q.position = TV - CENTRE + Vector3(0.04, 0.16, -0.224)
	q.rotation_degrees.y = 180.0
	root.add_child(q)
	if tv != null:
		hot["tv"]["meshes"].append(q)


func _build_clock() -> void:
	_clock_vp = SubViewport.new()
	_clock_vp.size = Vector2i(96, 36)
	_clock_vp.transparent_bg = false
	_clock_vp.disable_3d = true
	_clock_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(_clock_vp)
	_clock_canvas = Control.new()
	_clock_canvas.size = Vector2(96, 36)
	_clock_canvas.draw.connect(func():
		_clock_canvas.draw_rect(Rect2(0, 0, 96, 36), Color(0.02, 0.035, 0.03))
		SEVEN_SEG.draw_text(_clock_canvas, Vector2(9, 6), 24.0, _clock_text, Color(0.56, 1.0, 0.86), Color(0.16, 0.3, 0.26, 0.3), true, true)
	)
	_clock_vp.add_child(_clock_canvas)
	K.prop(root, "alarm_clock", CLOCK - CENTRE, -35.0)
	var face := MeshInstance3D.new()
	face.name = "ClockFace"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.115, 0.043)
	face.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _clock_vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	face.material_override = m
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(-35.0))
	face.position = CLOCK - CENTRE + Vector3(0, 0.04, 0) + fwd * 0.043
	face.rotation_degrees.y = -35.0
	root.add_child(face)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 1.0, 0.8)
	glow.light_energy = 0.12
	glow.omni_range = 0.8
	glow.position = face.position + fwd * 0.08
	root.add_child(glow)


## Called every frame with the camp's clock (hours, 0-24).
func update(delta: float, hour: float) -> void:
	if curtain != null:
		curtain.update(delta)
	_t += delta
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0)
	var text := "%2d:%02d" % [h, m]
	if text != _clock_text:
		_clock_text = text
		if _clock_canvas != null:
			_clock_canvas.queue_redraw()
			_clock_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# After midnight the station has closed down: the test card and its tone.
	var late := hour >= 0.0 and hour < 5.5
	if late != _late:
		_late = late
		_apply_programme()
	var target := 1.0 if tv_on else 0.0
	_tv_power = move_toward(_tv_power, target, delta * (1.6 if tv_on else 3.0))
	if _tv_mat != null:
		_tv_mat.set_shader_parameter("power", _tv_power)
	if tv_light != null:
		var flicker := 0.75 + 0.25 * sin(floorf(_t * 12.0) * 2.7) * sin(floorf(_t * 12.0) * 1.3)
		tv_light.light_energy = 0.55 * _tv_power * (flicker if not _late else 0.95)


func _apply_programme() -> void:
	if _tv_mat == null:
		return
	var path := TESTCARD if _late else PROGRAMME
	if not ResourceLoader.exists(path):
		path = TESTCARD if ResourceLoader.exists(TESTCARD) else ""
	_tv_mat.set_shader_parameter("has_picture", path != "")
	if path != "":
		_tv_mat.set_shader_parameter("picture", load(path))
	_tv_mat.set_shader_parameter("signal", 0.92 if _late else 0.68)
	if tv_on:
		_tv_hiss.volume_db = -30.0 if _late else -22.0
		if _late and not _tv_tone.playing:
			_tv_tone.play()
		elif not _late:
			_tv_tone.stop()


func toggle_tv() -> void:
	_set_tv(not tv_on, true)


func _set_tv(on: bool, sound: bool) -> void:
	tv_on = on
	if sound:
		_play("tv_on.wav" if on else "tv_off.wav", -8.0)
	if on:
		_tv_hiss.play()
		_apply_programme()
	else:
		_tv_hiss.stop()
		_tv_tone.stop()


func set_lamp(on: bool) -> void:
	lamp_on = on
	if lamp != null:
		lamp.visible = on
	if bulb != null:
		bulb.visible = on
	if _ceiling_lamp != null:
		(_ceiling_lamp.material_override as StandardMaterial3D).emission_energy_multiplier = 0.7 if on else 0.0


func toggle_lamp() -> void:
	set_lamp(not lamp_on)
	_play("lamp_click.wav", -6.0)


func _play(file: String, db: float) -> void:
	if _one != null and ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.volume_db = db
		_one.play()


## Lying on the pillow, eyes on the set (absolute room coordinates).
func lie_pose() -> Array:
	var head := BED + Vector3(0.05, 0.82, -0.62)
	var look := Transform3D(Basis.IDENTITY, head).looking_at(TV + Vector3(0, 0.2, 0), Vector3.UP)
	return [head, look.basis.get_euler()]
