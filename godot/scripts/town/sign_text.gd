extends MeshInstance3D

## Words on a board out in the world: a stop's name, the bus's destination and its plate.
## Drawn by the 2D renderer (scripts/bowling/board_text.gd): a Label3D leaves out the pixel
## fonts' one-stroke letters (AGENTS.md), and the stops read L BL CE, the bus LST BOR.
##   var s = SIGN_TEXT.new(); parent.add_child(s); s.setup("LIBLICE", Vector2(1.08, 0.2), 32, 0.0027, colour)
##   s.position = ...; s.show_text("..."); s.set_colour(...)

const BOARD_TEXT := preload("res://scripts/bowling/board_text.gd")
const FONT := "res://assets/fonts/jersey10.fnt"

var _board
var _mat: StandardMaterial3D


## `px_m`: metres of the board to a pixel of the words (a Label3D's pixel_size).
func setup(text: String, size_m: Vector2, font_size: int, px_m: float, col: Color) -> void:
	_board = BOARD_TEXT.new()
	add_child(_board)
	var px := Vector2i(maxi(8, roundi(size_m.x / px_m)), maxi(8, roundi(size_m.y / px_m)))
	_board.setup(px, load(FONT), font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_board.show_text(text)
	var q := QuadMesh.new()
	q.size = size_m
	mesh = q
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = _board.get_texture()
	_mat.albedo_color = col
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat.alpha_scissor_threshold = 0.5
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("retro_text", true)


func show_text(text: String) -> void:
	if _board != null:
		_board.show_text(text)


func set_colour(col: Color) -> void:
	if _mat != null:
		_mat.albedo_color = col
