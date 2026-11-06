extends RefCounted

## The hover highlight for things in a room you can use (doors, the phone, the bed...):
## one shared overlay material (materials/hover_glint.gdshader) laid over the hovered
## object's meshes and taken off again. The glints come from a Grok texture
## (assets/textury/ui/hover_glint.png); without it the object only warms up. A sprite (a
## cut-out picture, maybe turned to you) gets a copy that keeps its shape and its turn.
##
##   var glint = HOVER_GLINT.new()
##   glint.show_on(meshes)    # every frame or on change; [] clears it

const SHADER := preload("res://materials/hover_glint.gdshader")
const GLINT_TEX := "res://assets/textury/ui/hover_glint.png"

static var _mat: ShaderMaterial
## The camp's own (its surfaces snap: retro_materials.SNAP_LINES; a room's do not).
static var _mat_camp: ShaderMaterial
const SNAP_LINES := 150.0
## The sprites' copies, by picture and turn.
static var _sprite_mats: Dictionary = {}

var _meshes: Array = []


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		if ResourceLoader.exists(GLINT_TEX):
			_mat.set_shader_parameter("glint", load(GLINT_TEX))
			_mat.set_shader_parameter("has_glint", true)
	return _mat


## Puts the glint on these meshes (MeshInstance3D or nodes holding them) and takes it
## off whatever had it before.
func show_on(nodes: Array) -> void:
	var meshes: Array = []
	for n in nodes:
		_collect(n, meshes)
	if meshes == _meshes:
		return
	for m in _meshes:
		if is_instance_valid(m) and ((m as MeshInstance3D).material_overlay == _mat or (m as MeshInstance3D).material_overlay == _mat_camp or _sprite_mats.values().has((m as MeshInstance3D).material_overlay)):
			(m as MeshInstance3D).material_overlay = null
	_meshes = meshes
	var mat := material()
	for m in _meshes:
		(m as MeshInstance3D).material_overlay = _for_mesh(m as MeshInstance3D, mat if _in_room(m) else camp_material())


## The glint for the camp's world (the corn stand, the pipes, the lake): snapped as it is.
static func camp_material() -> ShaderMaterial:
	if _mat_camp == null:
		_mat_camp = material().duplicate() as ShaderMaterial
		_mat_camp.set_shader_parameter("snap_lines", SNAP_LINES)
	return _mat_camp


## In a room (retro_materials._in_room: its own world, or built in the camp's): nothing
## snaps there, and a glint that did slid off what it lay on.
static func _in_room(n: Node) -> bool:
	var vp := n.get_viewport()
	return vp is SubViewport and ((vp as SubViewport).own_world_3d or vp.has_meta("retro_room"))


## The overlay for this mesh: the shared one, or for a sprite its own copy.
static func _for_mesh(mi: MeshInstance3D, shared: ShaderMaterial) -> ShaderMaterial:
	var base := mi.material_override as BaseMaterial3D
	if base == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		base = mi.mesh.surface_get_material(0) as BaseMaterial3D
	if base == null or base.albedo_texture == null:
		return shared
	var cut := base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var bb := 0
	match base.billboard_mode:
		BaseMaterial3D.BILLBOARD_ENABLED:
			bb = 1
		BaseMaterial3D.BILLBOARD_FIXED_Y:
			bb = 2
	if not cut and bb == 0:
		return shared
	var key := "%d|%d|%d" % [base.albedo_texture.get_instance_id(), bb, shared.get_instance_id()]
	if not _sprite_mats.has(key):
		var m := shared.duplicate() as ShaderMaterial
		m.set_shader_parameter("sprite_tex", base.albedo_texture)
		m.set_shader_parameter("use_sprite", cut)
		m.set_shader_parameter("sprite_billboard", bb)
		_sprite_mats[key] = m
	return _sprite_mats[key]


func clear() -> void:
	show_on([])


static func _collect(n, out: Array) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is MeshInstance3D:
		out.append(n)
	for c in (n as Node).get_children():
		_collect(c, out)
