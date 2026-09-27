class_name RetroRender
extends RefCounted

## Build-engine presentation for every 3D view in the game.
##
## A registered SubViewportContainer renders its 3D scene at a low internal resolution
## (integer `stretch_shrink`, nearest upscale) and runs the result through the 256-colour
## palette shader (`materials/build_post.gdshader`). The world view, the interiors and the
## sewer crawl all register here, so one setting changes the look everywhere.
##
## Containers that set their SubViewport size by hand (stretch = false) only get the
## palette pass; their owners can ask `internal_scale()` to size the viewport themselves.

const SHADER := preload("res://materials/build_post.gdshader")
const LUT := preload("res://assets/textury/palette/build_palette_lut.png")
const GROUP := "retro_render_targets"

## Target vertical resolution per preset. 0 = native (palette only).
const PRESET_LINES := {
	"chunky": 200,
	"build": 240,
	"crisp": 360,
	"svga": 480,
	"native": 0,
}
const PRESET_ORDER: Array[String] = ["chunky", "build", "crisp", "svga", "native"]
const PRESET_LABELS := {
	"chunky": "320x200 CHUNKY",
	"build": "BUILD 240p",
	"crisp": "CRISP 360p",
	"svga": "SVGA 480p",
	"native": "NATIVE (palette only)",
}


## Registers a container and applies the current look immediately.
static func register(container: SubViewportContainer) -> void:
	if container == null:
		return
	if not container.is_in_group(GROUP):
		container.add_to_group(GROUP)
	apply_to(container)


## Re-applies the current settings to every registered container.
static func refresh_all(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group(GROUP):
		var container := node as SubViewportContainer
		if container != null and is_instance_valid(container):
			apply_to(container)


static func apply_to(container: SubViewportContainer) -> void:
	if container == null:
		return
	var preset := current_preset()
	var palette_on := palette_enabled()
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if container.stretch:
		container.stretch_shrink = internal_scale(container.get_viewport_rect().size.y, preset)
	if palette_on:
		var mat := container.material as ShaderMaterial
		if mat == null or mat.shader != SHADER:
			mat = ShaderMaterial.new()
			mat.shader = SHADER
			container.material = mat
		mat.set_shader_parameter("palette_lut", LUT)
		mat.set_shader_parameter("palette_mix", 1.0)
	else:
		var existing := container.material as ShaderMaterial
		if existing != null and existing.shader == SHADER:
			container.material = null
	for child in container.get_children():
		var vp := child as SubViewport
		if vp != null:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST


## Integer upscale factor that brings `screen_height` closest to the preset's line count.
static func internal_scale(screen_height: float, preset: String = "") -> int:
	if preset.is_empty():
		preset = current_preset()
	var lines := int(PRESET_LINES.get(preset, 240))
	if lines <= 0 or screen_height <= 0.0:
		return 1
	return maxi(1, int(round(screen_height / float(lines))))


static func current_preset() -> String:
	var settings := _settings()
	if settings != null and settings.has_method("get_retro_preset"):
		var value := str(settings.call("get_retro_preset"))
		if PRESET_LINES.has(value):
			return value
	return "build"


static func palette_enabled() -> bool:
	var settings := _settings()
	if settings != null and settings.has_method("get_retro_palette_enabled"):
		return bool(settings.call("get_retro_palette_enabled"))
	return true


static func _settings() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return null
	return loop.root.get_node_or_null("GameSettings")
