extends SubViewport

## Words drawn by the 2D renderer onto a picture for a surface in the 3D rooms: the lanes'
## chalkboards and score screens, the pinsetter's plate in the cellar (scripts/bowling/).
## A Label3D leaves out the pixel fonts' one-stroke letters (the I, the dash, the bar: whole
## solid rectangles in the font's page, gone in 3D), the 2D labels draw them; the picture is
## drawn again only when the words change.
##   var t := BOARD_TEXT.new(); parent.add_child(t); t.setup(size, font, font_size, colour)
##   t.show_text("PEPA 3 6|X  |   9"); quad material: albedo_texture = t.get_texture()

var _label: Label
var _colour := Color(1, 1, 1)


func setup(px: Vector2i, font: Font, font_size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, valign := VERTICAL_ALIGNMENT_TOP) -> void:
	size = px
	transparent_bg = true
	disable_3d = true
	gui_disable_input = true
	render_target_update_mode = SubViewport.UPDATE_ONCE
	_label = Label.new()
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", col)
	_colour = col
	_label.add_theme_constant_override("line_spacing", 0)
	_label.horizontal_alignment = align
	_label.vertical_alignment = valign
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.position = Vector2(2, 1)
	_label.size = Vector2(px) - Vector2(4, 2)
	add_child(_label)


func show_text(t: String) -> void:
	if _label == null or _label.text == t:
		return
	_label.text = t
	render_target_update_mode = SubViewport.UPDATE_ONCE


func set_colour(col: Color) -> void:
	if _label == null or col == _colour:
		return
	_colour = col
	_label.add_theme_color_override("font_color", col)
	render_target_update_mode = SubViewport.UPDATE_ONCE


## A quad of `metres` showing the words (see-through round them), for `parent` at `pos`.
static func quad(parent: Node3D, words: SubViewport, metres: Vector2, pos: Vector3, lit := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Words"
	var q := QuadMesh.new()
	q.size = metres
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = words.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if not lit:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	# Its own material (the retro look would not keep the viewport's picture live).
	mi.set_meta("retro_skip", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi
