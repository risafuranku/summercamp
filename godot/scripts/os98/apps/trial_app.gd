extends Control

## The demo's end on the reception PC (scripts/demo/demo_end.gd opens it): a 1998
## shareware nag. The camp's camera still on the left, the game's name and version, the
## thanks, an order form filled in with this camp's own numbers, and where the order
## would be sent the Steam Wishlist; Quit goes back to the title. Closed, it comes again.

const T = preload("res://scripts/os98/os_theme.gd")
const WEBCAM = preload("res://scripts/os98/camp_webcam.gd")
const DEMO = preload("res://scripts/demo/demo.gd")
const PIC := Vector2(160, 120)
const RED := Color8(128, 0, 0)

var _shell
var _win
var _pic: TextureRect
var _cam: Node
var _name_w := 0.0


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	win.can_maximize = false
	var main: Node = shell.main_node()
	var demo = main.get("_demo_end") if main != null else null
	var form: Dictionary = demo.form() if demo != null else {}
	# The camp's camera, this morning.
	var well := Panel.new()
	well.add_theme_stylebox_override("panel", T.box("field", T.DARK, Vector4(2, 2, 2, 2)))
	well.position = Vector2(10, 10)
	well.size = PIC + Vector2(4, 4)
	add_child(well)
	_pic = TextureRect.new()
	_pic.position = Vector2(2, 2)
	_pic.size = PIC
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_child(_pic)
	_cam = WEBCAM.of(main)
	if _cam != null:
		if _cam.image != null:
			_show((_cam.image as Image).duplicate())
		_cam.request()
	var x := PIC.x + 26
	var w := size.x - x - 10
	_label(DEMO.GAME_NAME, Vector2(x, 12), w, T.FONT_BOLD)
	_label("Shareware version 1.0", Vector2(x, 28), w, T.FONT, T.SHADOW)
	_label("Thank you for playing!", Vector2(x, 56), w, T.FONT_BOLD)
	var told := _label("This trial ends with day 3.\nThe full version has the whole month.", Vector2(x, 74), w, T.FONT)
	told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	told.size.y = 60
	# The order form, filled in.
	var group := Panel.new()
	group.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4(2, 2, 2, 2)))
	group.position = Vector2(10, 148)
	group.size = Vector2(size.x - 20, 104)
	add_child(group)
	var head := _label("Order form", Vector2(18, 141), 0, T.FONT)
	head.add_theme_stylebox_override("normal", T.flat(T.FACE, Vector4(3, 0, 3, 0)))
	head.size = Vector2.ZERO
	var half := (group.size.x - 20) * 0.5
	# The names' column as wide as the longest in the warden's language.
	for name in ["Warden:", "Camp:", "Days:", "Guests:", "Missing:"]:
		_name_w = maxf(_name_w, T.FONT.get_string_size(tr(name), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 6.0)
	_field("Warden:", str(form.get("warden", "")), Vector2(20, 162), half - 8)
	_field("Camp:", str(form.get("camp", "")), Vector2(20 + half, 162), half - 8)
	_field("Days:", tr("%d of %d") % [int(form.get("days", DEMO.DAYS)), Season.CAMPAIGN_DAYS], Vector2(20, 190), half - 8)
	_field("Guests:", str(int(form.get("guests", 0))), Vector2(20 + half, 190), half - 8)
	var missing := _field("Missing:", str(int(form.get("lost", 0))), Vector2(20, 218), half - 8)
	if int(form.get("lost", 0)) > 0:
		missing.add_theme_color_override("font_color", RED)
	# Where the order would be sent.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.position = Vector2(0, size.y - 34)
	row.size = Vector2(size.x, 24)
	add_child(row)
	var wish := _button(row, "Wishlist on Steam", 150.0)
	wish.add_theme_stylebox_override("normal", T.box("default", T.FACE, Vector4(6, 3, 6, 3)))
	wish.add_theme_stylebox_override("hover", T.box("default", T.FACE, Vector4(6, 3, 6, 3)))
	wish.add_theme_stylebox_override("pressed", T.box("default_pressed", T.FACE, Vector4(7, 4, 5, 2)))
	wish.add_theme_stylebox_override("hover_pressed", T.box("default_pressed", T.FACE, Vector4(7, 4, 5, 2)))
	wish.pressed.connect(func():
		if demo != null:
			demo.wishlist()
	)
	wish.grab_focus.call_deferred()
	var quit := _button(row, "Quit", 75.0)
	quit.pressed.connect(func():
		if demo != null:
			demo.quit_to_title()
	)
	_shell.play("ding")


func _process(_delta: float) -> void:
	if _cam != null and is_instance_valid(_cam) and bool(_cam.fresh):
		_cam.fresh = false
		_show((_cam.image as Image).duplicate())


func _show(img: Image) -> void:
	if img == null:
		return
	_pic.texture = ImageTexture.create_from_image(img)


func _label(text: String, at: Vector2, w: float, font: Font, color: Color = T.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	if w > 0.0:
		l.size = Vector2(w, 16)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", T.FONT_SIZE)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


## A line of the form: its name, then the value in a white field. The value's label.
func _field(name: String, value: String, at: Vector2, w: float) -> Label:
	_label(name, at + Vector2(0, 3), _name_w, T.FONT)
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", T.box("field", T.WHITE, Vector4(2, 2, 2, 2)))
	box.position = at + Vector2(_name_w, 0)
	box.size = Vector2(w - _name_w, 20)
	add_child(box)
	var v := Label.new()
	v.text = value
	v.position = Vector2(4, 2)
	v.size = Vector2(box.size.x - 8, 16)
	v.clip_text = true
	v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_theme_font_override("font", T.FONT)
	v.add_theme_font_size_override("font_size", T.FONT_SIZE)
	v.add_theme_color_override("font_color", T.TEXT)
	box.add_child(v)
	return v


func _button(row: Control, text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 23)
	row.add_child(b)
	return b
