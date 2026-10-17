extends RefCounted

## The interiors' building kit: Build-engine rooms and the Blender props.
##
## Surfaces: every wall, floor and ceiling is a camp texture (assets/textury/camp, 128 px
## on the game palette) mapped in world space at a fixed texel density, nearest filter,
## no specular: like Build's sector walls, a texture flows across a room without seams
## or stretching whatever the size of the box.
##
## Props: low-poly models built by tools/blender/build_props.py, exported without
## images. Their materials are put back here by name from materials.json, so every prop
## shares the same few textures and filtering as the rooms.
##
##   var K = INTERIOR_KIT
##   K.room(root, Vector3(3, 2.6, 3), "parquet", "knotty_pine", "ceiling_board")
##   K.prop(root, "bed_wood", Vector3(-1.0, 0, -0.5), 90.0)

const TEX := "res://assets/textury/camp/"
const MODELS := "res://assets/models/interior/"

static var _surfaces: Dictionary = {}
static var _prop_mats: Dictionary = {}
static var _manifest: Dictionary = {}
static var _scenes: Dictionary = {}


## A world-mapped surface: `tex` = camp texture name (no extension), `metres` = how much
## one texture repeat covers, `tint` multiplies it.
static func surface(tex: String, metres: float = 1.0, tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	var key := "%s|%.3f|%s" % [tex, metres, tint.to_html()]
	if _surfaces.has(key):
		return _surfaces[key]
	var m := _base(tint)
	var path := TEX + tex + ".png"
	if not ResourceLoader.exists(path):
		path = "res://assets/textury/pipes/" + tex + ".png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE / maxf(0.05, metres)
	_surfaces[key] = m
	return m


static func _base(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


## A box of `size` at `pos` (centre) in `parent`, with material `mat`.
static func slab(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, name: String = "Slab") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A closed room `size` (width x, height y, depth z) with its floor at y = 0 centred on
## the origin of `parent`. `wall` may be one texture or an Array of four (back, front,
## left, right). Returns {floor, ceiling, back, front, left, right}.
static func room(parent: Node3D, size: Vector3, floor_tex: String, wall, ceiling_tex: String,
		wall_metres: float = 1.2, floor_metres: float = 1.0, y0: float = 0.0) -> Dictionary:
	var w := size.x
	var h := size.y
	var d := size.z
	var walls: Array = wall if wall is Array else [wall, wall, wall, wall]
	var t := 0.1
	var out := {}
	out["floor"] = slab(parent, Vector3(w, t, d), Vector3(0, -t * 0.5, 0), surface(floor_tex, floor_metres), "Floor")
	out["ceiling"] = slab(parent, Vector3(w, t, d), Vector3(0, h + t * 0.5, 0), surface(ceiling_tex, 1.0), "Ceiling")
	out["back"] = slab(parent, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5 - t * 0.5), surface(str(walls[0]), wall_metres), "WallBack")
	out["front"] = slab(parent, Vector3(w, h, t), Vector3(0, h * 0.5, d * 0.5 + t * 0.5), surface(str(walls[1]), wall_metres), "WallFront")
	out["left"] = slab(parent, Vector3(t, h, d), Vector3(-w * 0.5 - t * 0.5, h * 0.5, 0), surface(str(walls[2]), wall_metres), "WallLeft")
	out["right"] = slab(parent, Vector3(t, h, d), Vector3(w * 0.5 + t * 0.5, h * 0.5, 0), surface(str(walls[3]), wall_metres), "WallRight")
	if y0 != 0.0:
		for key in out.keys():
			(out[key] as Node3D).position.y += y0
	return out


## Wood skirting along the four walls of a `size` room with its floor at `y0`.
static func skirting(parent: Node3D, size: Vector3, tex: String = "planks_dark", y0: float = 0.0) -> void:
	var m := surface(tex, 0.6)
	var w := size.x
	var d := size.z
	slab(parent, Vector3(w, 0.1, 0.03), Vector3(0, y0 + 0.05, -d * 0.5 + 0.015), m, "Skirting")
	slab(parent, Vector3(w, 0.1, 0.03), Vector3(0, y0 + 0.05, d * 0.5 - 0.015), m, "Skirting")
	slab(parent, Vector3(0.03, 0.1, d), Vector3(-w * 0.5 + 0.015, y0 + 0.05, 0), m, "Skirting")
	slab(parent, Vector3(0.03, 0.1, d), Vector3(w * 0.5 - 0.015, y0 + 0.05, 0), m, "Skirting")


## A wall painted the Czech institutional way (oil_wall: green dado, red line, whitewash):
## one texture repeat is exactly the wall's height, so the line runs at mid height.
static func oil_wall_metres(height: float) -> float:
	return height


## A picture on a wall: camp texture `tex` (a panel: poster, painting, view) on a quad of
## `size` metres at `pos`, facing +Z turned `yaw_deg` (90 = faces +X, -90 = faces -X).
static func picture(parent: Node3D, tex: String, size: Vector2, pos: Vector3, yaw_deg: float = 0.0, name: String = "Picture") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := _base(Color(1, 1, 1))
	var path := TEX + tex + ".png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	parent.add_child(mi)
	return mi


## A Build sprite with see-through edges (camp texture `tex`, keyed): a quad of `size`
## metres, its bottom edge at `pos`, facing +Z turned `yaw_deg`; `billboard` turns it to
## face you about Y (things standing on the floor), else it is flat on its wall.
static func cutout(parent: Node3D, tex: String, size: Vector2, pos: Vector3, yaw_deg: float = 0.0, billboard := false, name: String = "Cutout") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0, size.y * 0.5, 0)
	mi.mesh = q
	var m := _base(Color(1, 1, 1))
	var path := TEX + tex + ".png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	parent.add_child(mi)
	return mi


## Instance a Blender prop at `pos` in `parent`, turned `yaw_deg` about Y.
static func prop(parent: Node3D, prop_name: String, pos: Vector3, yaw_deg: float = 0.0, scale: float = 1.0) -> Node3D:
	var scn: PackedScene = _scenes.get(prop_name)
	if scn == null:
		var path := MODELS + prop_name + ".glb"
		if not ResourceLoader.exists(path):
			push_warning("interior_kit: no prop %s" % prop_name)
			return null
		scn = load(path)
		_scenes[prop_name] = scn
	var n: Node3D = scn.instantiate()
	n.name = prop_name.to_pascal_case()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	if scale != 1.0:
		n.scale = Vector3.ONE * scale
	_skin(n)
	parent.add_child(n)
	return n


## Put the shared camp materials on a prop's surfaces (by the material names Blender gave).
static func _skin(n: Node) -> void:
	if _manifest.is_empty():
		var f := FileAccess.open(MODELS + "materials.json", FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			_manifest = parsed if parsed is Dictionary else {}
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			var mat_name := src.resource_name if src != null else ""
			(mi as MeshInstance3D).set_surface_override_material(i, _prop_material(mat_name))


static func _prop_material(mat_name: String) -> StandardMaterial3D:
	if _prop_mats.has(mat_name):
		return _prop_mats[mat_name]
	var entry: Dictionary = _manifest.get(mat_name, {})
	var tint_a: Array = entry.get("tint", [1, 1, 1])
	var m := _base(Color(float(tint_a[0]), float(tint_a[1]), float(tint_a[2])))
	var tex := str(entry.get("tex", ""))
	if tex != "" and ResourceLoader.exists(TEX + tex):
		m.albedo_texture = load(TEX + tex)
	if mat_name in ["bulb", "glow"]:
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 1.5
	_prop_mats[mat_name] = m
	return m
