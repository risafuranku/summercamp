extends Control

## A photo sent with a mail, held up (CampMail: a click on one of Vera's polaroids; the
## noticeboard holds hers up the same way, board_closeup.gd): the picture three times its
## size on the window's dark well, as a 1998 imaging program showed one. os_shell.open_photo
## opens it, or shows another photo in it when it is open.

const T = preload("res://scripts/os98/os_theme.gd")
const ZOOM := 3

var _pic: TextureRect


func setup(_shell, win, args: Dictionary) -> void:
	win.can_maximize = false
	var well := Panel.new()
	well.add_theme_stylebox_override("panel", T.box("field", T.DARK, Vector4(2, 2, 2, 2)))
	well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	well.offset_left = 6
	well.offset_top = 6
	well.offset_right = -6
	well.offset_bottom = -6
	add_child(well)
	_pic = TextureRect.new()
	_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(_pic)
	show_photo(str(args.get("path", "")))


func show_photo(path: String) -> void:
	if _pic == null or not ResourceLoader.exists(path):
		return
	var img: Image = (load(path) as Texture2D).get_image()
	img.resize(img.get_width() * ZOOM, img.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	_pic.texture = ImageTexture.create_from_image(img)
