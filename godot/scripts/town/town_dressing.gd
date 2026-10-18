extends Node3D

## Lesna lived in (playtest 17. 10.: "bring the world to life"), on top of what
## town_lesna.gd builds: concrete-slab pavements along the road, trodden paths up to the
## houses' gates, picket and wire fences, the phone booth by the Jednota and the post box
## on its wall, litter bins, the village loudspeaker on its pole on the square (it plays
## its jingle and the day's notices at seven, noon and five), the notice board, the stone
## shrine at the west end, the pub's hanging sign, wood piles, window boxes, washing on
## the lines flapping in the wind, hens in a yard, a dog on a chain that barks when you
## pass (and at night, far off), a cat on a fence post, gnomes, a wheelbarrow, two old
## Skodas parked, the wooden poles and wires along the road, a television flickering
## blue in a window at night.
##
## Built by town_lesna.gd (build()) in its own local frame; sprites and faces from Grok
## in assets/textury/town/ (tools/artgen/office_art.py).

const TEX := "res://assets/textury/town/"
const TEX_CAMP := "res://assets/textury/camp/"
const SFX := "res://assets/sfx/town/"
const CLOTH := preload("res://materials/cloth_wind.gdshader")

var town: Node3D
var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _hens: Array = []            # {sprite, base, t, peck}
var _dog: Dictionary = {}
var _radio: AudioStreamPlayer3D
var _radio_done := -1
var _hour := 12.0
var _t := 0.0
var _acc := 0.0
var _tv: Array = []              # {mesh, lit (the house's lit material), mat (blue)}
var _far_dog: AudioStreamPlayer3D
var _far_dog_t := 20.0
var _hens_snd: AudioStreamPlayer3D


func build(p_town: Node3D) -> void:
	town = p_town
	name = "Dressing"
	_rng.seed = 1998
	_pavements()
	_houses()
	_street()
	_poles()
	_cars()


# ── helpers ──────────────────────────────────────────────────────────────────

func _tex(name: String) -> Texture2D:
	var p := TEX + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null


func _mat(path: String, tint := Color.WHITE, uv := Vector2.ONE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [path, tint.to_html(), uv]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	_mats[key] = m
	return m


func _plane(pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _solid(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	b.add_child(cs)
	b.position = pos
	add_child(b)


## A Grok sprite `h` tall standing at `pos` (its feet), as wide as its art; turned to
## face you (billboard) or flat, facing `yaw`.
func _sprite(name: String, h: float, pos: Vector3, billboard := true, yaw := 0.0) -> MeshInstance3D:
	var t := _tex(name)
	if t == null:
		return null
	var w := h * float(t.get_width()) / float(t.get_height())
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	q.center_offset = Vector3(0, h * 0.5, 0)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	return mi


## A face on a box side: a quad of `size` at `pos` facing `yaw` (0 = +z).
func _face(name: String, size: Vector2, pos: Vector3, yaw: float) -> MeshInstance3D:
	var t := _tex(name)
	if t == null:
		return null
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := _mat(TEX + name + ".png")
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	return mi


## A run of fence sprite repeated along a line from a to b (local x/z), `h` tall.
func _fence(name: String, a: Vector3, b: Vector3, h: float) -> void:
	var t := _tex(name)
	if t == null:
		return
	var len := a.distance_to(b)
	if len < 0.2:
		return
	var seg := h * float(t.get_width()) / float(t.get_height())
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(len, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.uv1_scale = Vector3(maxf(1.0, roundf(len / seg)), 1.0, 1.0)
	mi.material_override = m
	mi.position = (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
	mi.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
	add_child(mi)
	_solid_line(a, b)


func _solid_line(a: Vector3, b: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(a.distance_to(b), 1.2, 0.12)
	cs.shape = bx
	body.add_child(cs)
	body.position = (a + b) * 0.5 + Vector3(0, 0.6, 0)
	body.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
	add_child(body)


func _audio3d(path: String, db: float, pos: Vector3, loop := false, dist := 40.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if ResourceLoader.exists(path):
		var s = load(path)
		if loop and s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			s.loop = true
		p.stream = s
	p.volume_db = db
	p.unit_size = 6.0
	p.max_distance = dist
	p.position = pos
	add_child(p)
	return p


# ── the ground ───────────────────────────────────────────────────────────────

## Pavements of square slabs along both sides of the road (not across the square's
## cobbles or the station's forecourt), a slab platform at each stop.
func _pavements() -> void:
	var slabs := _mat(TEX + "sidewalk.png", Color(0.92, 0.92, 0.9), Vector2(1.0, 1.0))
	var runs := [[-70.0, -19.0, -4.4], [27.0, 80.0, -4.4], [-70.0, 35.0, 4.4], [61.0, 80.0, 4.4]]
	for r in runs:
		var x0: float = r[0]
		var x1: float = r[1]
		var z: float = r[2]
		var m := slabs.duplicate() as StandardMaterial3D
		m.uv1_scale = Vector3((x1 - x0) / 1.8, 1.0, 1.0)
		_plane(Vector3((x0 + x1) * 0.5, 0.03, z), Vector2(x1 - x0, 1.8), m)


## Paths up to the houses, their fences with a gate gap, wood piles, window boxes,
## washing behind, and life in a couple of yards.
func _houses() -> void:
	var dirt := _mat(TEX + "dirt_path.png", Color(0.95, 0.92, 0.88))
	var houses: Array = town.spots.get("houses", [])
	for i in houses.size():
		var hd: Dictionary = houses[i]
		var at: Vector3 = hd["at"]
		var size: Vector3 = hd["size"]
		var f: float = hd["facing"]
		var front := at.z + size.z * 0.5 * f
		var fence_z := front + 3.0 * f
		# The path from the door to the pavement.
		var walk_end := 5.3 * signf(front) if absf(front) > 5.3 else fence_z
		var pm := dirt.duplicate() as StandardMaterial3D
		var plen := absf(walk_end - front)
		pm.uv1_scale = Vector3(1.0, plen / 1.2, 1.0)
		_plane(Vector3(at.x, 0.035, (front + walk_end) * 0.5), Vector2(1.1, plen), pm)
		# The fence along the garden's front, a gap for the gate.
		var fence := "fence_picket" if i % 3 != 1 else "fence_mesh"
		var half := size.x * 0.5 + 1.0
		_fence(fence, Vector3(at.x - half, 0, fence_z), Vector3(at.x - 0.75, 0, fence_z), 1.0)
		_fence(fence, Vector3(at.x + 0.75, 0, fence_z), Vector3(at.x + half, 0, fence_z), 1.0)
		var yaw := 0.0 if f > 0.0 else PI
		# A wood pile by the front corner, a box of geraniums under a window.
		if i % 2 == 0:
			_sprite("woodpile", 1.3, Vector3(at.x + size.x * 0.36, 0, front + 0.4 * f), false, yaw)
		if i % 3 == 0:
			_sprite("flower_box", 0.3, Vector3(at.x - size.x * 0.28, 0.95, front + 0.16 * f), false, yaw)
		# Washing on a line in the back garden.
		if i % 2 == 1:
			_laundry(Vector3(at.x - size.x * 0.1, 0, at.z - (size.z * 0.5 + 3.5) * f), yaw)
		# Things in the front garden.
		match i % 4:
			0:
				_sprite("gnome", 0.42, Vector3(at.x - 2.2, 0, front + 1.6 * f), true)
			1:
				_sprite("wheelbarrow", 0.65, Vector3(at.x + 2.4, 0, front + 1.8 * f), false, yaw + 0.4)
			2:
				_sprite("cat", 0.36, Vector3(at.x + half - 0.1, 1.0, fence_z), true)
		if i == 0:
			_yard_hens(Vector3(at.x + 2.6, 0, front + 1.5 * f))
		if i == 1:
			_yard_dog(Vector3(at.x - 3.0, 0, front + 1.4 * f), yaw)
		# Now and then a television flickering blue through the curtains.
		if i % 3 == 2:
			for wdict in town.spots.get("lit_windows", []):
				var d: Dictionary = wdict
				var mesh := d["mesh"] as MeshInstance3D
				if is_instance_valid(mesh) and mesh.get_parent() == hd["root"]:
					var tv := (d["lit"] as StandardMaterial3D).duplicate() as StandardMaterial3D
					tv.emission = Color(0.55, 0.7, 1.0)
					_tv.append({"mesh": mesh, "lit": d["lit"], "mat": tv})
					break


func _laundry(at: Vector3, yaw: float) -> void:
	var t := _tex("laundry")
	if t == null:
		return
	var h := 1.9
	var w := h * float(t.get_width()) / float(t.get_height())
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	q.subdivide_width = 10
	q.subdivide_depth = 4
	q.center_offset = Vector3(0, h * 0.5, 0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = CLOTH
	m.set_shader_parameter("albedo_tex", t)
	m.set_shader_parameter("strength", 0.16)
	mi.material_override = m
	mi.position = at
	mi.rotation.y = yaw
	add_child(mi)


func _yard_hens(at: Vector3) -> void:
	for k in 3:
		var p := at + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-0.6, 0.6))
		var s := _sprite("hen", 0.34, p, true)
		if s != null:
			_hens.append({"sprite": s, "base": p, "t": _rng.randf() * 3.0, "peck": false})
	_hens_snd = _audio3d(SFX + "hens.mp3", -14.0, at + Vector3(0, 0.3, 0), true, 22.0)
	_hens_snd.autoplay = true


func _yard_dog(at: Vector3, yaw: float) -> void:
	var lie := _sprite("dog_kennel", 1.0, at, false, yaw)
	var bark := _sprite("dog_bark", 0.75, at + Vector3(0.6, 0, 0.5 * cos(yaw)), true)
	if bark != null:
		bark.visible = false
	_dog = {"lie": lie, "bark": bark, "t": 0.0, "cool": 0.0, "at": at,
		"snd": _audio3d(SFX + "dog_bark.mp3", -4.0, at + Vector3(0, 0.6, 0), false, 50.0)}


# ── the street ───────────────────────────────────────────────────────────────

func _street() -> void:
	# The phone booth by the Jednota: a box with the booth on every side.
	var booth := Vector3(-15.6, 0, -8.6)
	_box(booth + Vector3(0, 1.2, 0), Vector3(0.95, 2.4, 0.95), _mat("", Color(0.3, 0.3, 0.32)))
	for k in 4:
		var yaw := k * PI * 0.5
		var off := Vector3(sin(yaw), 0, cos(yaw)) * 0.48
		_face("phone_booth", Vector2(0.95, 2.4), booth + Vector3(0, 1.2, 0) + off, yaw)
	_solid(booth + Vector3(0, 1.2, 0), Vector3(0.95, 2.4, 0.95))
	# The post box on the shop's wall, bins by the stops and the square.
	_sprite("post_box", 0.55, Vector3(-12.2, 1.0, -9.97), false, 0.0)
	for b in [Vector3(-4.8, 0, 4.6), Vector3(8.4, 0, -5.0), Vector3(21.5, 0, -8.6), Vector3(-10.0, 0, -26.0)]:
		_sprite("street_bin", 0.95, b, true)
	# The loudspeaker on its pole at the square's east end, and its voice.
	var radio := Vector3(25.5, 0, -11.6)
	_sprite("village_radio", 7.5, radio, true)
	_radio = _audio3d(SFX + "village_radio.mp3", 2.0, radio + Vector3(0, 7.0, 0), false, 140.0)
	_radio.unit_size = 22.0
	# The notice board by the square, the shrine at the west end of the village.
	_sprite("noticeboard", 1.8, Vector3(27.5, 0, -6.4), false, 0.0)
	_solid(Vector3(27.5, 0.9, -6.4), Vector3(1.6, 1.8, 0.3))
	_sprite("shrine", 3.0, Vector3(-66.0, 0, -6.6), true)
	_solid(Vector3(-66.0, 1.2, -6.6), Vector3(0.7, 2.4, 0.7))
	# The pub's sign, out on its bracket over the door.
	_sprite("pub_sign", 0.8, Vector3(19.6, 2.7, -9.7), false, PI * 0.5)
	# A wood pile by the pub's side, crates of empties at its back door.
	_sprite("woodpile", 1.4, Vector3(23.2, 0, -14.0), false, PI * 0.5)


## Wooden poles along the north side of the road, the wires sagging between them.
func _poles() -> void:
	var wood := _mat(TEX_CAMP + "log_bark.png", Color(0.62, 0.54, 0.46), Vector2(1.0, 3.0))
	var dark := _mat("", Color(0.08, 0.08, 0.08))
	var xs: Array = []
	var x := -68.0
	while x < 80.0:
		xs.append(x)
		x += 26.0
	var z := -6.1
	for px in xs:
		var p := Vector3(px, 0, z)
		_box(p + Vector3(0, 3.6, 0), Vector3(0.22, 7.2, 0.22), wood)
		_box(p + Vector3(0, 6.9, 0), Vector3(0.12, 0.12, 1.4), wood)
		_solid(p + Vector3(0, 3.6, 0), Vector3(0.3, 7.2, 0.3))
	for i in xs.size() - 1:
		for wz in [-0.6, 0.0, 0.6]:
			var a := Vector3(xs[i], 6.95, z + wz)
			var b := Vector3(xs[i + 1], 6.95, z + wz)
			var mid := (a + b) * 0.5 - Vector3(0, 0.55, 0)
			for seg in [[a, mid], [mid, b]]:
				var s0: Vector3 = seg[0]
				var s1: Vector3 = seg[1]
				var wire := _box((s0 + s1) * 0.5, Vector3(s0.distance_to(s1), 0.025, 0.025), dark)
				wire.rotation.z = atan2(s1.y - s0.y, s1.x - s0.x)
				wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Two old Skodas parked: by the pub and in front of a house.
func _cars() -> void:
	for c in [[Vector3(29.5, 0, -8.2), 0.0], [Vector3(-40.0, 0, 6.2), PI]]:
		var root := Node3D.new()
		root.position = c[0]
		root.rotation.y = c[1]
		add_child(root)
		var body := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(4.2, 0.9, 1.6)
		body.mesh = b
		body.material_override = _mat("", Color(0.72, 0.66, 0.52))
		body.position = Vector3(0, 0.75, 0)
		root.add_child(body)
		var cabin := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(2.2, 0.55, 1.5)
		cabin.mesh = cb
		cabin.material_override = _mat("", Color(0.3, 0.34, 0.38))
		cabin.position = Vector3(-0.1, 1.45, 0)
		root.add_child(cabin)
		for side in [-1.0, 1.0]:
			_face_on(root, "car_side", Vector2(4.2, 1.45), Vector3(0, 0.88, side * 0.81), 0.0 if side > 0.0 else PI)
		_face_on(root, "car_front", Vector2(1.6, 1.2), Vector3(2.11, 0.75, 0), PI * 0.5)
		_face_on(root, "car_back", Vector2(1.6, 1.2), Vector3(-2.11, 0.75, 0), -PI * 0.5)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(4.2, 1.5, 1.6)
		cs.shape = bx
		sb.add_child(cs)
		sb.position = Vector3(0, 0.75, 0)
		root.add_child(sb)


func _face_on(root: Node3D, name: String, size: Vector2, pos: Vector3, yaw: float) -> MeshInstance3D:
	var t := _tex(name)
	if t == null:
		return null
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	root.add_child(mi)
	return mi


# ── life ─────────────────────────────────────────────────────────────────────

func set_hour(h: float) -> void:
	_hour = h
	# The loudspeaker at seven, noon and five, once each.
	for slot in [7, 12, 17]:
		if h >= float(slot) and h < float(slot) + 0.25 and _radio_done != slot and _radio != null and _radio.stream != null:
			_radio_done = slot
			_radio.play()


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc < 1.0 / 12.0:
		return
	var dt := _acc
	_acc = 0.0
	# The hens: peck, look up, a little hop now and then.
	for hn in _hens:
		hn["t"] = float(hn["t"]) - dt
		if hn["t"] <= 0.0:
			hn["t"] = _rng.randf_range(0.4, 2.2)
			hn["peck"] = _rng.randf() < 0.55
			var s: MeshInstance3D = hn["sprite"]
			var tex := _tex("hen_peck" if hn["peck"] else "hen")
			if tex != null:
				(s.material_override as StandardMaterial3D).albedo_texture = tex
			if _rng.randf() < 0.3:
				var p: Vector3 = hn["base"]
				hn["base"] = p + Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.15, 0.15))
				s.position = hn["base"]
	_update_dog(dt)
	# The television, after dark, in steps.
	var night := _hour >= 19.0 or _hour < 5.0
	for tv in _tv:
		var mesh: MeshInstance3D = tv["mesh"]
		if not is_instance_valid(mesh):
			continue
		var lit: bool = mesh.material_override == tv["lit"] or mesh.material_override == tv["mat"]
		if lit and night:
			mesh.material_override = tv["mat"]
			(tv["mat"] as StandardMaterial3D).emission_energy_multiplier = _rng.randf_range(0.6, 1.8)
		elif mesh.material_override == tv["mat"]:
			mesh.material_override = tv["lit"]
	# A dog far off across the village at night.
	if night:
		_far_dog_t -= dt
		if _far_dog_t <= 0.0:
			_far_dog_t = _rng.randf_range(25.0, 70.0)
			if _far_dog == null:
				_far_dog = _audio3d(SFX + "dog_far.mp3", -6.0, Vector3(0, 2, 0), false, 400.0)
			_far_dog.position = Vector3(_rng.randf_range(-90.0, 90.0), 3.0, _rng.randf_range(-70.0, 70.0))
			_far_dog.play()


func _update_dog(dt: float) -> void:
	if _dog.is_empty():
		return
	_dog["cool"] = maxf(0.0, float(_dog["cool"]) - dt)
	_dog["t"] = maxf(0.0, float(_dog["t"]) - dt)
	var cam := get_viewport().get_camera_3d()
	if cam != null and float(_dog["cool"]) <= 0.0:
		var d := cam.global_position.distance_to(to_global(_dog["at"]))
		if d < 9.0:
			_dog["cool"] = _rng.randf_range(10.0, 18.0)
			_dog["t"] = 2.4
			var snd: AudioStreamPlayer3D = _dog["snd"]
			if snd.stream != null:
				snd.play()
	var barking := float(_dog["t"]) > 0.0
	if _dog["lie"] != null:
		(_dog["lie"] as MeshInstance3D).visible = not barking
	if _dog["bark"] != null:
		var b: MeshInstance3D = _dog["bark"]
		b.visible = barking
		if barking:
			b.position.y = 0.05 if int(_t * 6.0) % 2 == 0 else 0.0
