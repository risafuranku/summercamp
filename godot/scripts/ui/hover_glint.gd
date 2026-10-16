extends RefCounted

## The hover highlight for things in a room you can use (doors, the phone, the bed...):
## one shared overlay material (materials/hover_glint.gdshader) laid over the hovered
## object's meshes and taken off again. The glints come from a Grok texture
## (assets/textury/ui/hover_glint.png); without it the object only warms up.
##
##   var glint = HOVER_GLINT.new()
##   glint.show_on(meshes)    # every frame or on change; [] clears it

const SHADER := preload("res://materials/hover_glint.gdshader")
const GLINT_TEX := "res://assets/textury/ui/hover_glint.png"

static var _mat: ShaderMaterial

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
		if is_instance_valid(m) and (m as MeshInstance3D).material_overlay == _mat:
			(m as MeshInstance3D).material_overlay = null
	_meshes = meshes
	var mat := material()
	for m in _meshes:
		(m as MeshInstance3D).material_overlay = mat


func clear() -> void:
	show_on([])


static func _collect(n, out: Array) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is MeshInstance3D:
		out.append(n)
	for c in (n as Node).get_children():
		_collect(c, out)
