extends RefCounted

## The reception office as it is lived in (playtest 17. 10.: "a total polish of the
## reception and the back room"), on top of the room building_interior.gd builds:
##   - the cast-iron stove in the back corner behind the counter, its pipe up through
##     the ceiling (the building's chimney outside stands over it): lit from late
##     afternoon to the morning, the embers glowing in its little window, the room's
##     light flickering orange off it, the crackle; click it to open the door and stoke;
##     a box of firewood beside it;
##   - the electric wall clock over the store door, its hands on the camp's time
##     (stepping a minute at a time), ticking;
##   - the 1998 calendar, the district's certificate, the fire extinguisher by the door,
##     the dried plants on the sill, the milk-glass ceiling light, the runner rug.
## Faces and sprites from Grok (assets/textury/camp, tools/artgen/prompts.tsv).

const K = preload("res://scripts/interior_kit.gd")
const SFX_CRACKLE := "res://assets/sfx/life/fire_crackle.mp3"
const SFX_STOVE := "res://assets/sfx/rooms/stove_door.mp3"
const SFX_TICK := "res://assets/sfx/rooms/clock_tick_wall.mp3"

const STOVE := Vector3(2.06, 0.05, 2.1)
const STOVE_YAW := -135.0
const CLOCK := Vector3(0.0, 2.42, 2.485)

var root: Node3D
var hot: Dictionary = {}
var fire_lit := false
var _fire_light: OmniLight3D
var _glow_mat: StandardMaterial3D
var _crackle: AudioStreamPlayer3D
var _one: AudioStreamPlayer3D
var _hour_hand: Node3D
var _minute_hand: Node3D
var _lamp_mat: StandardMaterial3D
var _t := 0.0
var _stoke := 0.0
var _flick := 1.0
var _flick_t := 0.0
var _shown_minute := -1
## The district's diplomas for the camp (Builder 98's Courier, DESIGN §5j: the PC's store
## "courier"), framed in a row under the key board as they come; each one held up to read
## with a click (reception/diploma_view.gd; the eye over it, reception_extras.gd).
const DIPLOMA_VIEW = preload("res://scripts/reception/diploma_view.gd")
const COURIER = preload("res://scripts/builder/courier_news.gd")
## New things to click came up (a diploma hung): building_interior hands them on.
var hot_changed := false
var _diploma_view: CanvasLayer
const DIPLOMA_AT := [Vector3(2.488, 1.1, 0.3), Vector3(2.488, 1.1, 0.7), Vector3(2.488, 1.1, 1.1)]
var _diplomas_hung := 0
var _diploma_t := 0.0


func build(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "OfficeDressing"
	parent.add_child(root)
	_build_stove()
	_build_clock()
	# The walls.
	K.picture(root, "calendar", Vector2(0.42, 0.56), Vector3(-2.488, 1.62, -1.56), 90.0, "Calendar1998")
	K.picture(root, "certificate", Vector2(0.36, 0.48), Vector3(2.488, 1.62, -0.05), -90.0, "Certificate")
	K.slab(root, Vector3(0.05, 0.05, 0.16), Vector3(2.475, 1.16, -2.1), K.surface("galvanized", 0.2, Color(0.3, 0.3, 0.3)), "ExtinguisherBracket")
	K.cutout(root, "extinguisher", Vector2(0.27, 0.54), Vector3(2.47, 0.62, -2.1), -90.0, false, "Extinguisher")
	# The warden's jacket on its hook by the store door, the mat inside the front door.
	K.cutout(root, "coat_hook", Vector2(0.46, 0.68), Vector3(1.36, 1.04, 2.488), 180.0, false, "Jacket")
	_floor_sprite("doormat", Vector2(0.86, 0.58), Vector3(1.72, 0.058, -2.12))
	# The dried plants on the window sill.
	K.cutout(root, "plant_dry", Vector2(0.3, 0.47), Vector3(-1.18, 0.99, -2.38), 0.0, true, "PlantL")
	K.cutout(root, "plant_dry", Vector2(0.25, 0.39), Vector3(0.36, 0.99, -2.38), 0.0, true, "PlantR")
	# The runner along the counter's front, where the guests stand.
	var rug := MeshInstance3D.new()
	rug.name = "RunnerRug"
	var rq := QuadMesh.new()
	rq.size = Vector2(0.66, 1.8)
	rq.orientation = PlaneMesh.FACE_Y
	rug.mesh = rq
	rug.material_override = _cut_mat("rug_runner")
	rug.position = Vector3(0.62, 0.057, -0.95)
	rug.rotation_degrees.y = 90.0
	root.add_child(rug)
	# The ceiling light: a milk-glass dome on a brass ring, seen from below.
	var lamp := MeshInstance3D.new()
	lamp.name = "CeilingLamp"
	var lq := QuadMesh.new()
	lq.size = Vector2(0.44, 0.44)
	lq.orientation = PlaneMesh.FACE_Y
	lq.flip_faces = true
	lamp.mesh = lq
	_lamp_mat = _cut_mat("ceiling_lamp")
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_lamp_mat.emission_texture = _lamp_mat.albedo_texture
	_lamp_mat.emission = Color(1.0, 0.96, 0.86)
	lamp.material_override = _lamp_mat
	lamp.position = Vector3(0.0, 2.735, 0.2)
	root.add_child(lamp)


func _floor_sprite(tex: String, size: Vector2, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = tex.to_pascal_case()
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.material_override = _cut_mat(tex)
	mi.position = pos
	root.add_child(mi)
	return mi


func _cut_mat(tex: String) -> StandardMaterial3D:
	var m := K._base(Color(1, 1, 1))
	if ResourceLoader.exists(K.TEX + tex + ".png"):
		m.albedo_texture = load(K.TEX + tex + ".png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_stove() -> void:
	var st := Node3D.new()
	st.name = "Stove"
	st.position = STOVE
	st.rotation_degrees.y = STOVE_YAW
	root.add_child(st)
	var iron := K.surface("planks_dark", 0.4, Color(0.34, 0.24, 0.18))
	var body := K.slab(st, Vector3(0.46, 0.9, 0.42), Vector3(0, 0.45, 0), iron, "StoveBody")
	var top := K.slab(st, Vector3(0.5, 0.035, 0.46), Vector3(0, 0.915, 0), K.surface("galvanized", 0.3, Color(0.22, 0.2, 0.2)), "StoveTop")
	var face := K.picture(st, "stove", Vector2(0.46, 0.9), Vector3(0, 0.45, 0.212), 0.0, "StoveFace")
	# The embers: only the glowing pixels of the face (stove_glow.png, a mask of the
	# orange in the fire window) light up.
	_glow_mat = face.material_override as StandardMaterial3D
	if _glow_mat != null and ResourceLoader.exists(K.TEX + "stove_glow.png"):
		_glow_mat.emission_enabled = true
		_glow_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		_glow_mat.emission_texture = load(K.TEX + "stove_glow.png")
		_glow_mat.emission = Color(1.0, 0.55, 0.2)
		_glow_mat.emission_energy_multiplier = 0.0
	# The pipe up into the ceiling.
	var pipe := MeshInstance3D.new()
	pipe.name = "StovePipe"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.065
	cm.bottom_radius = 0.065
	cm.height = 2.75 - 0.93
	cm.radial_segments = 8
	pipe.mesh = cm
	pipe.material_override = K.surface("galvanized", 0.3, Color(0.18, 0.17, 0.17))
	pipe.position = Vector3(0, 0.93 + cm.height * 0.5, -0.08)
	st.add_child(pipe)
	K.slab(st, Vector3(0.2, 0.05, 0.2), Vector3(0, 2.72, -0.08), K.surface("galvanized", 0.3, Color(0.4, 0.38, 0.36)), "StovePipeCollar")
	# A tin sheet under it on the floor, the firewood box beside it.
	K.slab(st, Vector3(0.7, 0.008, 0.72), Vector3(0, 0.004, 0.12), K.surface("galvanized", 0.5, Color(0.55, 0.52, 0.48)), "StoveSheet")
	var box := K.slab(root, Vector3(0.52, 0.28, 0.32), Vector3(1.42, 0.19, 2.3), K.surface("planks_grey", 0.5, Color(0.8, 0.72, 0.62)), "WoodBox")
	var bark := K.surface("log_bark", 0.4)
	for i in 5:
		var lg := MeshInstance3D.new()
		lg.name = "Log%d" % i
		var lm := CylinderMesh.new()
		lm.top_radius = 0.045 + (i % 2) * 0.01
		lm.bottom_radius = lm.top_radius
		lm.height = 0.46
		lm.radial_segments = 6
		lg.mesh = lm
		lg.material_override = bark
		lg.rotation_degrees = Vector3(0, 0, 90)
		lg.position = Vector3(1.42 + (i % 2) * 0.03, 0.36 + floorf(i / 3.0) * 0.08, 2.2 + (i % 3) * 0.1)
		root.add_child(lg)
	_fire_light = OmniLight3D.new()
	_fire_light.name = "StoveFire"
	_fire_light.light_color = Color(1.0, 0.56, 0.24)
	# Out in the room, soft: a near, sharp light burnt the stove's face flat and drew
	# rings on the walls through the palette.
	_fire_light.omni_range = 3.6
	_fire_light.omni_attenuation = 0.85
	_fire_light.position = Vector3(0, 0.38, 0.85)
	_fire_light.light_energy = 0.0
	st.add_child(_fire_light)
	_crackle = AudioStreamPlayer3D.new()
	if ResourceLoader.exists(SFX_CRACKLE):
		var s = load(SFX_CRACKLE)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			s.loop = true
		_crackle.stream = s
	_crackle.volume_db = -26.0
	_crackle.unit_size = 1.6
	_crackle.max_distance = 9.0
	_crackle.position = Vector3(0, 0.45, 0.25)
	st.add_child(_crackle)
	_one = AudioStreamPlayer3D.new()
	_one.unit_size = 2.0
	_one.position = Vector3(0, 0.45, 0.25)
	st.add_child(_one)
	var body3 := StaticBody3D.new()
	body3.name = "Hot_stove"
	body3.set_meta("extra_hot", "stove")
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.5, 0.95, 0.46)
	cs.shape = bx
	body3.add_child(cs)
	body3.position = Vector3(0, 0.47, 0)
	st.add_child(body3)
	hot["stove"] = {"body": body3, "meshes": [body, top, face]}


func _build_clock() -> void:
	var c := Node3D.new()
	c.name = "WallClock"
	c.position = CLOCK
	c.rotation_degrees.y = 180.0
	root.add_child(c)
	K.cutout(c, "wall_clock", Vector2(0.32, 0.32), Vector3(0, -0.16, 0), 0.0, false, "ClockDial")
	var black := K._base(Color(0.08, 0.07, 0.06))
	_hour_hand = _hand(c, 0.085, 0.016, black, 0.006)
	_minute_hand = _hand(c, 0.125, 0.011, black, 0.009)
	var tick := AudioStreamPlayer3D.new()
	if ResourceLoader.exists(SFX_TICK):
		var s = load(SFX_TICK)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			s.loop = true
		tick.stream = s
	tick.volume_db = -30.0
	tick.unit_size = 1.2
	tick.max_distance = 6.0
	tick.autoplay = true
	c.add_child(tick)


func _hand(parent: Node3D, length: float, width: float, mat: Material, z: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, z)
	parent.add_child(pivot)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, length)
	q.mesh = qm
	q.material_override = mat
	q.position = Vector3(0, length * 0.38, 0)
	pivot.add_child(q)
	return pivot


## Every frame: the clock, the fire (in steps, twelve a second, like the campfire), the
## ceiling light's glass.
func _hang_diplomas() -> void:
	if root == null or not root.is_inside_tree():
		return
	var main = root.get_tree().current_scene
	var im = main.get("_interior_manager") if main != null else null
	var bi = im.get("_building_interior") if im != null else null
	var pc = bi.get("_crt_ui") if bi != null else null
	if pc == null or not pc.has_method("stored"):
		return
	var c = pc.stored("courier", {})
	var n := mini(DIPLOMA_AT.size(), ((c as Dictionary).get("diplomas", []) as Array).size() if c is Dictionary else 0)
	while _diplomas_hung < n:
		var at: Vector3 = DIPLOMA_AT[_diplomas_hung]
		var frame := K.slab(root, Vector3(0.02, 0.44, 0.34), at + Vector3(0.012, 0, 0), K.surface("galvanized", 0.2, Color(0.22, 0.15, 0.09)), "DiplomaFrame%d" % _diplomas_hung)
		var pic := K.picture(root, "diploma_frame", Vector2(0.3, 0.4), at - Vector3(0.002, 0, 0), -90.0, "Diploma%d" % _diplomas_hung)
		var id := "diploma%d" % _diplomas_hung
		var body := StaticBody3D.new()
		body.name = "Hot_" + id
		body.set_meta("extra_hot", id)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.08, 0.46, 0.36)
		cs.shape = bx
		body.add_child(cs)
		body.position = at
		root.add_child(body)
		hot[id] = {"body": body, "meshes": [frame, pic]}
		hot_changed = true
		_diplomas_hung += 1


## The diploma `i` on the wall as the Courier brought it: its award, the camp, its day.
func _diploma_item(i: int) -> Dictionary:
	var main = root.get_tree().current_scene if root != null and root.is_inside_tree() else null
	var im = main.get("_interior_manager") if main != null else null
	var bi = im.get("_building_interior") if im != null else null
	var pc = bi.get("_crt_ui") if bi != null else null
	var c = pc.stored("courier", {}) if pc != null and pc.has_method("stored") else {}
	var ids: Array = (c as Dictionary).get("diplomas", []) if c is Dictionary else []
	if i >= ids.size() or not COURIER.DIPLOMAS.has(str(ids[i])):
		return {}
	var d: Array = COURIER.DIPLOMAS[str(ids[i])]
	var item := {"kind": "diploma", "id": str(ids[i]), "title": str(d[0]), "text": str(d[1])}
	var days = (c as Dictionary).get("days", {})
	if days is Dictionary and (days as Dictionary).has(str(ids[i])):
		item["day"] = int(days[str(ids[i])])
	return item


func diploma_open() -> bool:
	return _diploma_view != null and is_instance_valid(_diploma_view)


func update(delta: float, hour: float, lights_on: bool) -> void:
	_diploma_t -= delta
	if _diploma_t <= 0.0:
		_diploma_t = 2.0
		_hang_diplomas()
	_t += delta
	var minute := int(floor(hour * 60.0)) % (24 * 60)
	if minute != _shown_minute:
		_shown_minute = minute
		var m := float(minute % 60)
		var h := float(int(minute / 60.0) % 12) + m / 60.0
		if _minute_hand != null:
			_minute_hand.rotation.z = -m / 60.0 * TAU
		if _hour_hand != null:
			_hour_hand.rotation.z = -h / 12.0 * TAU
	var lit := hour >= 16.0 or hour < 9.0
	if lit != fire_lit:
		fire_lit = lit
		if _crackle != null and _crackle.stream != null:
			if lit:
				_crackle.play()
			else:
				_crackle.stop()
	if _stoke > 0.0:
		_stoke = maxf(0.0, _stoke - delta)
	_flick_t -= delta
	if _flick_t <= 0.0:
		_flick_t = 1.0 / 12.0
		_flick = randf_range(0.72, 1.0)
	var fire := (1.0 if fire_lit else 0.0) * _flick * (1.0 + _stoke * 0.9)
	if _fire_light != null:
		_fire_light.light_energy = 0.36 * fire
		_fire_light.visible = fire > 0.01
	if _glow_mat != null:
		_glow_mat.emission_energy_multiplier = 1.6 * fire
	if _lamp_mat != null:
		_lamp_mat.emission_energy_multiplier = 0.9 if lights_on else 0.0


## Clicked: open the little door, stoke it (the fire flares), shut it.
func click(id: String) -> bool:
	if id.begins_with("diploma"):
		var item := _diploma_item(int(id.substr(7)))
		if item.is_empty() or diploma_open():
			return true
		_diploma_view = DIPLOMA_VIEW.new()
		root.get_tree().root.add_child(_diploma_view)
		_diploma_view.open(item)
		return true
	if id != "stove":
		return false
	if _one != null and ResourceLoader.exists(SFX_STOVE):
		_one.stream = load(SFX_STOVE)
		_one.volume_db = -8.0
		_one.play()
	if fire_lit:
		_stoke = 1.2
	return true
