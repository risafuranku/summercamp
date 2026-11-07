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
const STEP_MOTION := preload("res://scripts/ambient/step_motion.gd")
const TRODDEN := preload("res://scripts/town/trodden.gd")
const WIRES := preload("res://scripts/ambient/wire_ribbons.gd")
const TOWN_CAR := preload("res://scripts/town/town_car.gd")

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
var _pub_murmur: AudioStreamPlayer3D
var _pub_glow: StandardMaterial3D
var _wire_mat: ShaderMaterial
var _pub_dark: Material


func build(p_town: Node3D) -> void:
	town = p_town
	name = "Dressing"
	_rng.seed = 1998
	for job: Callable in [_pavements, _houses, _back_gardens, _street, _jednota_back, _poles, _cars]:
		job.call()
		await town.breath()


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
## A picture from another folder of the pictures, as `_sprite`.
func _flat_sprite(name: String, h: float, pos: Vector3, yaw := 0.0) -> void:
	var path := "res://assets/textury/" + name + ".png"
	if not ResourceLoader.exists(path):
		return
	var t: Texture2D = load(path)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(h * float(t.get_width()) / float(t.get_height()), h)
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
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)


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
	var dirt := _mat(TEX + "dirt_path.png", TRODDEN.TINT)
	var houses: Array = town.spots.get("houses", [])
	for i in houses.size():
		var hd: Dictionary = houses[i]
		var at: Vector3 = hd["at"]
		var size: Vector3 = hd["size"]
		var f: float = hd["facing"]
		var front := at.z + size.z * 0.5 * f
		# (The side street's houses stand close to it, and it has no pavement: from them the paths
		# ran fifty metres over the asphalt and the gardens to the main street's.)
		var far := absf(front) > 12.0
		var fence_z := front + (2.0 if far else 3.0) * f
		# The path from the door to the pavement.
		var walk_end := fence_z if far or absf(front) <= 5.3 else 5.3 * signf(front)
		TRODDEN.lay(self, Vector3(at.x, 0.035, front), Vector3(at.x, 0.035, walk_end), 1.05, dirt, TRODDEN.dice(i), 0.05)
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
			_flower_box(hd, front, f, yaw)
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


## On the sill of the house's first window at the ground floor, its width: it hung 60 cm under
## the window on the bare wall, on a kostka on the garage door. (A kostka's windows are upstairs.)
func _flower_box(hd: Dictionary, front: float, f: float, yaw: float) -> void:
	var meta: Dictionary = town._front_meta(str(hd.get("front", "")))
	if meta.is_empty():
		return
	var pic: Vector2 = Vector2(float(meta["m"][0]), float(meta["m"][1]))
	for win in meta.get("windows", []):
		var bottom := pic.y * (1.0 - float(win[3]))
		if bottom < 0.5 or bottom > 2.4:
			continue
		var x: float = (hd["at"] as Vector3).x + f * ((float(win[0]) + float(win[2])) * 0.5 - 0.5) * pic.x
		var wide := (float(win[2]) - float(win[0])) * pic.x
		_sprite("flower_box", wide * 0.8 * 40.0 / 69.0, Vector3(x, bottom - 0.04, front + 0.2 * f), false, yaw)
		return


## The back gardens (L16, walk-through of 6. 11.: behind the houses the fields started
## straight away, the pub's and the street's backs on bare ground): behind each house its
## garden fifteen metres deep to a wire fence, two or three fruit trees in its far half and
## now and then a spruce, a plank shed with a tin lean-to behind every other house (the
## washing hangs behind the rest).
const GARDEN_DEEP := 15.0


## And the pub's yard behind it (pub_view.gd: 11.5 x 10 m round (16, -15.5)).
const YARDS := [[Vector3(16.0, 0, -15.5), Vector3(11.5, 5.3, 10.0), 1.0]]


func _back_gardens() -> void:
	var lane_end := _mat(TEX + "dirt_path.png", TRODDEN.TINT)
	# Wider than the asphalt where it gives out, so no straight cut shows; then a field track.
	TRODDEN.lay(self, Vector3(32.8, 0.07, -50.0), Vector3(39.0, 0.07, -50.2), 6.6, lane_end, TRODDEN.dice(78), 0.1)
	TRODDEN.lay(self, Vector3(37.0, 0.036, -50.1), Vector3(66.0, 0.036, -51.5), 3.4, lane_end, TRODDEN.dice(77), 0.12)
	var houses: Array = (town.spots.get("houses", []) as Array).duplicate()
	for y in YARDS:
		houses.append({"at": y[0], "size": y[1], "facing": y[2]})
	var fruit: Array[Transform3D] = []
	var spruce: Array[Transform3D] = []
	var planks := _mat(TEX_CAMP + "planks_grey.png", Color(0.74, 0.66, 0.54), Vector2(3.0, 2.0))
	var tin := _mat(TEX_CAMP + "corrugated_roof.png", Color(0.66, 0.64, 0.6), Vector2(3.0, 2.0))
	var door := _mat(TEX_CAMP + "door_wood.png", Color(0.62, 0.52, 0.42))
	for i in houses.size():
		var hd: Dictionary = houses[i]
		var at: Vector3 = hd["at"]
		var size: Vector3 = hd["size"]
		var f: float = hd["facing"]
		var back := at.z - size.z * 0.5 * f
		var half := size.x * 0.5 + 1.0
		var n := 3 if i % 3 == 0 else 2
		for k in n:
			var x := at.x + lerpf(-half + 1.4, half - 1.4, (float(k) + 0.5) / float(n)) + _rng.randf_range(-0.5, 0.5)
			var z := back - f * _rng.randf_range(7.5, GARDEN_DEEP - 1.8)
			var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.85, 1.12)), Vector3(x, 0, z))
			if _rng.randf() < 0.14:
				spruce.append(xf.scaled_local(Vector3(0.7, 0.85, 0.7)))
			else:
				# Apple and plum trees: small and round (geo_world's gardens' size).
				fruit.append(xf.scaled_local(Vector3(0.45, 0.38, 0.45)))
		if i % 2 == 0:
			_shed(Vector3(at.x + size.x * 0.28, 0, back - f * 3.4), f, planks, tin, door)
		_fence("fence_mesh", Vector3(at.x - half, 0, back - f * GARDEN_DEEP), Vector3(at.x + half, 0, back - f * GARDEN_DEEP), 1.0)
	_garden_trees(fruit, "linden")
	_garden_trees(spruce, "spruce")


## A plank shed 2.6 x 2.2 m, its door to the house (f: the house's facing), the tin
## lean-to falling away from it.
func _shed(at: Vector3, f: float, planks: Material, tin: Material, door: Material) -> void:
	_box(at + Vector3(0, 1.0, 0), Vector3(2.6, 2.0, 2.2), planks)
	_solid(at + Vector3(0, 1.0, 0), Vector3(2.6, 2.0, 2.2))
	var roof := _box(at + Vector3(0, 2.16, 0), Vector3(2.95, 0.06, 2.65), tin)
	roof.rotation.x = -0.14 * f
	_quad(door, Vector2(0.86, 1.75), at + Vector3(-0.4, 0.88, f * 1.115), 0.0 if f > 0.0 else PI)


## Trees from the world's kit (world_generator.gd, as geo_world's gardens), one multimesh
## a part.
func _garden_trees(xforms: Array[Transform3D], species: String) -> void:
	var wg = town.get("worldgen")
	if xforms.is_empty() or wg == null or not wg.has_method("_tree_mesh"):
		return
	var parts: Array = [["%s_trunk" % species, "bark", 0], ["%s_crown" % species, "needles" if species == "spruce" else "leaf", 0]]
	if species != "spruce":
		parts.append(["%s_cards" % species, "leaf_cards", 1])
	for part in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = wg._tree_mesh(str(part[0]))
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Garden_" + str(part[0])
		mmi.multimesh = mm
		mmi.material_override = wg._tree_material(str(part[1]), int(part[2]))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


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


func _yard_dog(at: Vector3, yaw: float) -> void:
	var lie := _sprite("dog_kennel", 1.0, at, false, yaw)
	var bark := _sprite("dog_bark", 0.75, at + Vector3(0.6, 0, 0.5 * cos(yaw)), true)
	if bark != null:
		bark.visible = false
	_dog = {"lie": lie, "bark": bark, "t": 0.0, "cool": 0.0, "at": at,
		"snd": _audio3d(SFX + "dog_bark.mp3", -4.0, at + Vector3(0, 0.6, 0), false, 50.0)}


## The Jednota's other walls (town_lesna._jednota_hollow: 12 x 10 m round (-6, -15), its
## front to the street): they were bare concrete all round, a blank slab beside the chapel
## (playtest 6. 11., L15: "the whole town is broken"). Glass-block windows of the store
## rooms high in the sides and the back, the delivery door at the back on its concrete
## ramp with the bread crates out and the bin by it, downpipes at the back corners.
func _jednota_back() -> void:
	var c := Vector3(-6.0, 0, -15.0)
	var hw := 6.0
	var back := c.z - 5.0
	var blocks := _mat(TEX_CAMP + "wc_window.png")
	var tin := _mat("", Color(0.44, 0.46, 0.45))
	for side in [-1.0, 1.0]:
		var x: float = c.x + side * hw
		var yaw: float = side * PI * 0.5
		for z in ([-13.0, -17.0] if side < 0.0 else [-16.5]):
			_quad(blocks, Vector2(1.1, 1.1), Vector3(x + side * 0.03, 2.9, z), yaw)
		_box(Vector3(x + side * 0.08, 2.45, back + 0.12), Vector3(0.1, 4.9, 0.1), tin)
	_quad(blocks, Vector2(1.1, 1.1), Vector3(c.x - 3.0, 2.9, back - 0.03), PI)
	# The delivery door, up its ramp.
	var ramp := Vector3(c.x + 2.8, 0.25, back - 0.8)
	_box(ramp, Vector3(3.6, 0.5, 1.6), _mat(TEX_CAMP + "concrete.png", Color(0.74, 0.73, 0.7), Vector2(3.0, 1.0)))
	_solid(ramp, Vector3(3.6, 0.5, 1.6))
	_box(Vector3(ramp.x, 1.5, back - 0.02), Vector3(2.9, 2.2, 0.04), _mat("", Color(0.25, 0.25, 0.25)))
	_quad(_mat(TEX + "garage_door.png"), Vector2(2.6, 1.95), Vector3(ramp.x, 1.49, back - 0.05), PI)
	_sprite("crates_bread", 0.85, Vector3(ramp.x - 1.15, 0.5, back - 0.75), false, PI)
	_sprite("crates_bread", 0.85, Vector3(ramp.x - 0.55, 0.5, back - 1.15), false, PI + 0.3)
	_sprite("street_bin", 0.95, Vector3(ramp.x + 2.6, 0, back - 0.7), true)


## A quad of `mat` (`size`) at `pos` facing `yaw` (0 = +z).
func _quad(mat: Material, size: Vector2, pos: Vector3, yaw: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	return mi


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
	_sprite("post_box", 0.55, Vector3(-10.6, 1.0, -9.9), false, 0.0)
	for b in [Vector3(-4.8, 0, 5.7), Vector3(8.4, 0, -5.0), Vector3(21.5, 0, -8.6), Vector3(16.0, 0, 11.5)]:
		_sprite("street_bin", 0.95, b, true)
	# The loudspeaker on its pole at the square's east end, and its voice.
	var radio := Vector3(24.2, 0, -11.6)
	_sprite("village_radio", 7.5, radio, true)
	_radio = _audio3d(SFX + "village_radio.mp3", 2.0, radio + Vector3(0, 7.0, 0), false, 140.0)
	_radio.unit_size = 22.0
	# The notice board on the green by the stop, the shrine at the west end of the village.
	_sprite("noticeboard", 1.8, Vector3(-7.0, 0, 8.4), false, PI)
	_solid(Vector3(-7.0, 0.9, 8.4), Vector3(1.6, 1.8, 0.3))
	_sprite("shrine", 3.0, Vector3(-69.3, 0, -6.4), true)
	_solid(Vector3(-69.3, 1.2, -6.4), Vector3(0.7, 2.4, 0.7))
	# The pub's sign, out on its bracket over the door: hung from its top edge, it swings in
	# the wind and knocks about, in steps (step_motion.gd).
	var pub_sign := _sprite("pub_sign", 0.8, Vector3(19.6, 2.7, -10.25), false, PI * 0.5)
	if pub_sign != null:
		STEP_MOTION.attach(pub_sign, "swing", Vector3.RIGHT, 0.32, {"pivot": Vector3(0, 0.8, 0), "near": 80.0})
	# A wood pile by the pub's side, crates of empties at its back door (Mr Kubat: "come round
	# the back", and the back was a bare wall).
	_sprite("woodpile", 1.4, Vector3(23.2, 0, -14.0), false, PI * 0.5)
	var pub_back := -20.5
	_box(Vector3(19.0, 0.08, pub_back - 0.5), Vector3(1.6, 0.16, 1.0), _mat(TEX_CAMP + "concrete.png", Color(0.74, 0.73, 0.7)))
	_quad(_mat(TEX_CAMP + "door_wood.png", Color(0.62, 0.5, 0.4)), Vector2(1.0, 2.1), Vector3(19.0, 1.21, pub_back - 0.03), PI)
	_quad(_mat(TEX_CAMP + "planks_dark.png"), Vector2(1.16, 0.1), Vector3(19.0, 2.3, pub_back - 0.025), PI)
	for c: Array in [["camp/beer_crate_full", Vector3(17.6, 0, pub_back - 0.5), 0.5], ["camp/beer_crate", Vector3(17.5, 0.5, pub_back - 0.52), 0.5], ["camp/beer_crate", Vector3(16.95, 0, pub_back - 0.6), 0.5], ["pub/keg_empty", Vector3(20.4, 0, pub_back - 0.55), 0.72]]:
		_flat_sprite(str(c[0]), float(c[2]), c[1], PI)
	_solid(Vector3(17.3, 0.45, pub_back - 0.5), Vector3(1.4, 0.9, 0.6))
	_solid(Vector3(20.4, 0.36, pub_back - 0.55), Vector3(0.5, 0.72, 0.5))


## Wooden poles along the north side of the road, the wires sagging between them.
func _poles() -> void:
	var wood := _mat(TEX_CAMP + "log_bark.png", Color(0.62, 0.54, 0.46), Vector2(1.0, 3.0))
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
	# Ribbons a pixel across (wire_ribbons.gd): boxes in a V went under a pixel a few metres off
	# and broke into dashes.
	var spans := PackedVector3Array()
	for i in xs.size() - 1:
		for wz in [-0.6, 0.0, 0.6]:
			spans.append_array(WIRES.hang(Vector3(xs[i], 6.95, z + wz), Vector3(xs[i + 1], 6.95, z + wz), 0.55, 4))
	var wires := MeshInstance3D.new()
	wires.mesh = WIRES.mesh(spans)
	_wire_mat = WIRES.material(Color(0.16, 0.16, 0.17), 0.01)
	wires.material_override = _wire_mat
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wires)


## Two old Skodas parked: half on the pavement by a farm gate, and in front of the motel.
func _cars() -> void:
	for c in [[Vector3(47.0, 0, -4.4), 0.0, Color.WHITE], [Vector3(-26.5, 0, 7.4), PI, Color(0.74, 0.78, 0.82)]]:
		var car: Node3D = TOWN_CAR.make(c[2])
		car.position = c[0]
		car.rotation.y = float(c[1]) + PI * 0.5
		add_child(car)
		TOWN_CAR.parked(car)


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
	# They are drawn unlit: dark by day, and in the dark as dark as the night round them.
	if _wire_mat != null:
		var dusk := clampf((h - 18.0) / 2.0, 0.0, 1.0) if h >= 12.0 else clampf((7.0 - h) / 2.0, 0.0, 1.0)
		_wire_mat.set_shader_parameter("light", lerpf(1.0, 0.1, dusk))
	_pub_evening(h)
	# The loudspeaker at seven, noon and five, once each.
	for slot in [7, 12, 17]:
		if h >= float(slot) and h < float(slot) + 0.25 and _radio_done != slot and _radio != null and _radio.stream != null:
			_radio_done = slot
			_radio.play()


## The pub of an evening: its windows warm, the talk inside heard at the door.
func _pub_evening(h: float) -> void:
	var open := h >= 10.0 and h < 23.0
	var lit := open and (h >= 18.0 or h < 7.0)
	# The talk at the door, whatever the front is made of (it waited on a face the hollow front
	# has not got, and the pub was silent from the street). The hens by day.
	if _pub_murmur == null:
		_pub_murmur = _audio3d("res://assets/sfx/pub/pub_room.mp3", -10.0, Vector3(16.0, 1.6, -9.6), true, 26.0)
	if open and not _pub_murmur.playing and _pub_murmur.stream != null and _pub_murmur.is_inside_tree():
		_pub_murmur.play()
	elif not open and _pub_murmur.playing:
		_pub_murmur.stop()
	if _hens_snd != null and _hens_snd.is_inside_tree():
		var awake := h >= 6.5 and h < 19.0
		if awake and not _hens_snd.playing:
			_hens_snd.play()
		elif not awake and _hens_snd.playing:
			_hens_snd.stop()
	var face = town.spots.get("pub_face", null)
	if face == null or not is_instance_valid(face):
		return
	if _pub_glow == null:
		_pub_dark = (face as MeshInstance3D).material_override
		# The front's own windows lit (town_lesna "pub_lit"), or the old picture warmed.
		_pub_glow = town.spots.get("pub_lit", null)
		if _pub_glow == null:
			_pub_glow = (_pub_dark as StandardMaterial3D).duplicate() as StandardMaterial3D
			_pub_glow.emission_enabled = true
			_pub_glow.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			_pub_glow.emission_texture = _pub_glow.albedo_texture
			_pub_glow.emission = Color(1.0, 0.72, 0.4)
			_pub_glow.emission_energy_multiplier = 0.55
	(face as MeshInstance3D).material_override = _pub_glow if lit else _pub_dark


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
