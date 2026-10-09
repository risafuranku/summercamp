extends Control

## The image viewer. There is one picture on this computer, restored from the bin.

const T = preload("res://scripts/os98/os_theme.gd")
const IMAGES := {"IMG0043.JPG": "res://assets/textury/os98/img0043.png"}

var _shell
var _win


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	var file := str(args.get("file", ""))
	win.title = "%s - Image Viewer" % file
	var well := Panel.new()
	well.add_theme_stylebox_override("panel", T.box("field", Color8(64, 64, 64), Vector4.ZERO))
	well.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(well)
	var path := str(IMAGES.get(file, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4
		tr.offset_top = 4
		tr.offset_right = -4
		tr.offset_bottom = -4
		well.add_child(tr)
	else:
		var l := Label.new()
		l.text = "Cannot read %s.\nThe file is damaged or the format is not supported." % file
		l.add_theme_color_override("font_color", T.WHITE)
		l.position = Vector2(12, 12)
		well.add_child(l)
