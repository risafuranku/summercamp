extends RefCounted

## What grows and lies under the camp's trees (playtest 17. 10.: "interesting details,
## bring the world to life"): bracken, fly agarics and boletes, nettles, blueberries,
## a mossy stone, a stump, a molehill, an anthill, a dead branch, a heap of leaves, a
## thistle. Build sprites from Grok (assets/textury/world/, tools/artgen/office_art.py),
## one to three at the foot of each tree, turned to face you. They are the tree's own
## children: bulldoze the tree and they go with it. Each tree's are always the same
## (seeded by where it stands), so a loaded camp looks as it did.
##
##   FOREST_FLOOR.dress(tree)      (world_generator.gd _create_tree)

const DIR := "res://assets/textury/world/"
## name, height (m), weight, how far out from the trunk (min, max).
const KINDS := [
	["fern", 0.75, 5.0, 0.6, 1.8],
	["fly_agaric", 0.22, 1.2, 0.5, 1.6],
	["boletus", 0.2, 1.5, 0.5, 1.6],
	["nettles", 0.9, 1.5, 0.9, 1.9],
	["blueberry", 0.38, 2.5, 0.6, 1.8],
	["rock_moss", 0.5, 1.0, 0.9, 1.9],
	["stump", 0.42, 0.8, 1.0, 1.9],
	["molehill", 0.22, 0.7, 1.0, 1.9],
	["anthill", 0.55, 0.4, 1.0, 1.8],
	["branch", 0.22, 1.2, 0.6, 1.7],
	["leaf_pile", 0.25, 2.0, 0.4, 1.4],
	["thistle", 0.7, 0.8, 1.0, 1.9],
]

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _total := -1.0


static func dress(tree: Node3D) -> void:
	if tree == null:
		return
	if _total < 0.0:
		_total = 0.0
		for k in KINDS:
			_total += float(k[2])
	var r := RandomNumberGenerator.new()
	r.seed = hash("%.2f|%.2f" % [tree.position.x, tree.position.z])
	var n := r.randi_range(0, 3)
	for i in n:
		var kind: Array = _pick(r.randf() * _total)
		var name := str(kind[0])
		var mesh := _mesh(name, float(kind[1]))
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Floor_" + name
		mi.mesh = mesh
		mi.material_override = _mat(name)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := r.randf() * TAU
		var d := r.randf_range(float(kind[3]), float(kind[4]))
		# In the tree's frame (it is turned): undo the turn so the spot is round the trunk.
		var world_off := Vector3(cos(ang) * d, 0.02, sin(ang) * d)
		# ...and its size (trees are scaled): the sprite keeps its own.
		var ts := tree.scale
		mi.position = world_off.rotated(Vector3.UP, -tree.rotation.y) / ts
		var s := r.randf_range(0.8, 1.2)
		mi.scale = Vector3(s / ts.x, s / ts.y, s / ts.z)
		tree.add_child(mi)


static func _pick(v: float) -> Array:
	for k in KINDS:
		v -= float(k[2])
		if v <= 0.0:
			return k
	return KINDS[0]


static func _mesh(name: String, h: float) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var path := DIR + name + ".png"
	if not ResourceLoader.exists(path):
		_meshes[name] = null
		return null
	var t: Texture2D = load(path)
	var q := QuadMesh.new()
	q.size = Vector2(h * float(t.get_width()) / float(t.get_height()), h)
	q.center_offset = Vector3(0, h * 0.5, 0)
	_meshes[name] = q
	return q


static func _mat(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + name + ".png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	_mats[name] = m
	return m
