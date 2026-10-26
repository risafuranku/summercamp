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


# ── shared by the rooms and their buildings in the camp (one plan) ─────────────

## An enamel plate with its words on a wall at `pos` (its face toward +Z): "enamel", the
## yellow "danger" or a grey "plate".
static func wall_sign(parent: Node3D, text: String, pos: Vector3, font_size: int, style: String = "enamel") -> Node3D:
	var root := Node3D.new()
	root.name = "Sign"
	root.position = pos
	parent.add_child(root)
	var lines := text.split("\n")
	var longest := 0
	for line in lines:
		longest = maxi(longest, line.length())
	var char_h := float(font_size) * 0.005
	var size := Vector2(longest * char_h * 0.62 + 0.16, lines.size() * char_h * 1.15 + 0.1)
	var plate := Color(0.92, 0.9, 0.82)
	var ink := Color(0.12, 0.12, 0.16)
	var rim := Color(0.16, 0.2, 0.36)
	if style == "danger":
		plate = Color(0.95, 0.8, 0.2)
		ink = Color(0.6, 0.06, 0.04)
		rim = Color(0.1, 0.08, 0.06)
	elif style == "plate":
		plate = Color(0.62, 0.64, 0.66)
		ink = Color(0.06, 0.06, 0.06)
		rim = Color(0.3, 0.3, 0.32)
	slab(root, Vector3(size.x + 0.05, size.y + 0.05, 0.015), Vector3(0, 0, -0.012), _flat(rim), "SignRim")
	slab(root, Vector3(size.x, size.y, 0.02), Vector3(0, 0, -0.004), _flat(plate), "SignPlate")
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = 0
	label.modulate = ink
	label.position = Vector3(0, 0, 0.008)
	label.shaded = true
	root.add_child(label)
	return root


## A pub's lamp hung over `at` from the ceiling at 2.85: its chain, the shade glowing, its
## light (returned).
static func pub_lamp(parent: Node3D, at: Vector3) -> OmniLight3D:
	slab(parent, Vector3(0.015, 2.85 - at.y, 0.015), Vector3(at.x, (2.85 + at.y) * 0.5, at.z), surface("galvanized", 0.3, Color(0.3, 0.3, 0.3)), "LampChain")
	var shade := cutout(parent, "pub_lamp", Vector2(0.24, 0.42), at - Vector3(0, 0.42, 0), 0.0, true, "PubLamp")
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := shade.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_texture = m.albedo_texture
	m.emission = Color(1.0, 0.8, 0.5)
	m.emission_energy_multiplier = 0.7
	var l := OmniLight3D.new()
	l.name = "PubLampLight"
	l.light_color = Color(1.0, 0.76, 0.45)
	l.light_energy = 0.55
	l.omni_range = 2.8
	l.position = at - Vector3(0, 0.45, 0)
	parent.add_child(l)
	return l


static func _flat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


## The pieces of a wall round its openings: [[a0, a1, y0, y1]] across (from its middle,
## -half..half) and up (0..h), round `holes` given the same way.
static func wall_pieces(half: float, h: float, holes: Array) -> Array:
	var cuts: Array = [-half, half]
	for hl in holes:
		cuts.append(clampf(float(hl[0]), -half, half))
		cuts.append(clampf(float(hl[1]), -half, half))
	cuts.sort()
	var out: Array = []
	for i in cuts.size() - 1:
		var a0: float = cuts[i]
		var a1: float = cuts[i + 1]
		if a1 - a0 < 0.002:
			continue
		var mid := (a0 + a1) * 0.5
		var lo := 0.0
		var spans: Array = []
		for hl in holes:
			if mid > float(hl[0]) and mid < float(hl[1]):
				spans.append([float(hl[2]), float(hl[3])])
		spans.sort_custom(func(p, q) -> bool: return float(p[0]) < float(q[0]))
		for sp in spans:
			if float(sp[0]) - lo > 0.002:
				out.append([a0, a1, lo, float(sp[0])])
			lo = maxf(lo, float(sp[1]))
		if h - lo > 0.002:
			out.append([a0, a1, lo, h])
	return out


## A wall `room()` made (a slab along X: the back and the front; along Z: the sides) cut
## round `holes` ([[a0, a1, y0, y1]]: across in the room's own X or Z, up from the wall's
## foot): the slab gives way to its pieces.
static func cut_wall(wall: MeshInstance3D, holes: Array) -> void:
	var s: Vector3 = (wall.mesh as BoxMesh).size
	var along_x := s.x >= s.z
	var half := (s.x if along_x else s.z) * 0.5
	var foot := wall.position - Vector3(0, s.y * 0.5, 0)
	var parent := wall.get_parent()
	for p in wall_pieces(half, s.y, holes):
		var mid := (float(p[0]) + float(p[1])) * 0.5
		var y := (float(p[2]) + float(p[3])) * 0.5
		var size := Vector3(float(p[1]) - float(p[0]), float(p[3]) - float(p[2]), s.z) if along_x else Vector3(s.x, float(p[3]) - float(p[2]), float(p[1]) - float(p[0]))
		var at := foot + (Vector3(mid, y, 0) if along_x else Vector3(0, y, mid))
		slab(parent, size, at, wall.material_override, String(wall.name))
	parent.remove_child(wall)
	wall.free()


## What only the room inside wants, out of a room built again in its building in the camp:
## the click boxes (the looks, the stations), the rain on the glass.
static func strip_for_outside(root: Node) -> void:
	for n in root.find_children("*", "CollisionObject3D", true, false):
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	for n in root.find_children("*", "Node", true, false):
		if is_instance_valid(n) and n.has_method("add_window"):
			n.get_parent().remove_child(n)
			n.free()
