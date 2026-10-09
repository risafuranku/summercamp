extends RefCounted

## The look of the camp computer: a 1998 desktop OS at 640x480, drawn the way the real
## ones were (two-pixel bevels in four greys, a navy title gradient, a bitmap system
## font), built as a Godot Theme so ordinary Buttons, Trees and LineEdits look right.
##
## Everything here is generated at runtime (tiny nine-patch images), nothing to import.

const FONT: FontFile = preload("res://assets/fonts/w95.fnt")
const FONT_BOLD: FontFile = preload("res://assets/fonts/w95b.fnt")
const FONT_SIZE := 12
## Tables in reports ([code] in rich text): Pixel Operator Mono, 8 px a column.
const FONT_MONO: FontFile = preload("res://assets/fonts/pomono.fnt")
const FONT_MONO_SIZE := 16

const FACE := Color8(192, 192, 192)
const WHITE := Color8(255, 255, 255)
const LIGHT := Color8(223, 223, 223)
const SHADOW := Color8(128, 128, 128)
const DARK := Color8(10, 10, 10)
const NAVY := Color8(0, 0, 128)
const TITLE_A := Color8(0, 0, 128)
const TITLE_B := Color8(16, 132, 208)
const TITLE_IDLE_A := Color8(128, 128, 128)
const TITLE_IDLE_B := Color8(181, 181, 181)
const DESKTOP := Color8(0, 128, 128)
const TEXT := Color8(0, 0, 0)
const TEXT_DISABLED := Color8(128, 128, 128)
const TOOLTIP := Color8(255, 255, 225)
const LINK := Color8(0, 0, 238)

static var _theme: Theme
static var _cache: Dictionary = {}


## Raised (buttons, panels), pressed, sunken field (white), window frame, status well.
static func box(kind: String, fill: Color = FACE, pad := Vector4(4, 3, 4, 3)) -> StyleBoxTexture:
	var key := "%s|%s|%s" % [kind, fill.to_html(), pad]
	if _cache.has(key):
		return _cache[key]
	var rings: Array
	match kind:
		"raised":
			rings = [[WHITE, DARK], [LIGHT, SHADOW]]
		"pressed":
			rings = [[DARK, WHITE], [SHADOW, LIGHT]]
		"field":
			rings = [[SHADOW, WHITE], [DARK, LIGHT]]
		"window":
			rings = [[LIGHT, DARK], [WHITE, SHADOW]]
		"well":
			rings = [[SHADOW, WHITE]]
		"thin_raised":
			rings = [[WHITE, SHADOW]]
		_:
			rings = []
	var border := rings.size()
	# A wide centre: stretched with filtering, a 1 px centre would smear the bevel.
	var n := border * 2 + 8
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for r in border:
		var lo := r
		var hi := n - 1 - r
		for i in range(lo, hi + 1):
			img.set_pixel(i, lo, rings[r][0])
			img.set_pixel(lo, i, rings[r][0])
		for i in range(lo, hi + 1):
			img.set_pixel(i, hi, rings[r][1])
			img.set_pixel(hi, i, rings[r][1])
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = border
	sb.texture_margin_top = border
	sb.texture_margin_right = border
	sb.texture_margin_bottom = border
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	_cache[key] = sb
	return sb


static func flat(c: Color, pad := Vector4(2, 1, 2, 1)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = FONT_SIZE

	for type in ["Label", "Button", "LineEdit", "TextEdit", "CheckBox", "CheckButton", "ItemList", "Tree", "PopupMenu", "TabBar", "TabContainer", "OptionButton", "ProgressBar", "TooltipLabel"]:
		t.set_font("font", type, FONT)
		t.set_font_size("font_size", type, FONT_SIZE)
	t.set_color("font_color", "Label", TEXT)

	# Buttons
	t.set_stylebox("normal", "Button", box("raised", FACE, Vector4(6, 3, 6, 3)))
	t.set_stylebox("hover", "Button", box("raised", FACE, Vector4(6, 3, 6, 3)))
	t.set_stylebox("pressed", "Button", box("pressed", FACE, Vector4(7, 4, 5, 2)))
	t.set_stylebox("hover_pressed", "Button", box("pressed", FACE, Vector4(7, 4, 5, 2)))
	t.set_stylebox("disabled", "Button", box("raised", FACE, Vector4(6, 3, 6, 3)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)

	# Text fields
	for type in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type, box("field", WHITE, Vector4(4, 3, 4, 3)))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_stylebox("read_only", type, box("field", WHITE, Vector4(4, 3, 4, 3)))
		t.set_color("font_color", type, TEXT)
		t.set_color("font_readonly_color", type, TEXT)
		t.set_color("selection_color", type, NAVY)
		t.set_color("font_selected_color", type, WHITE)
		t.set_color("caret_color", type, TEXT)
	t.set_color("background_color", "TextEdit", WHITE)

	# Rich text (mail bodies, web pages, reports): white field by default.
	t.set_stylebox("normal", "RichTextLabel", box("field", WHITE, Vector4(6, 4, 6, 4)))
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", FONT)
	t.set_font("bold_font", "RichTextLabel", FONT_BOLD)
	t.set_font("italics_font", "RichTextLabel", FONT)
	t.set_font("mono_font", "RichTextLabel", FONT_MONO)
	for f in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		t.set_font_size(f, "RichTextLabel", FONT_SIZE)
	t.set_font_size("mono_font_size", "RichTextLabel", FONT_MONO_SIZE)
	t.set_color("selection_color", "RichTextLabel", NAVY)
	t.set_constant("line_separation", "RichTextLabel", 1)

	# Lists and trees (mail list, folders)
	for type in ["ItemList", "Tree"]:
		t.set_stylebox("panel", type, box("field", WHITE, Vector4(2, 2, 2, 2)))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_stylebox("selected", type, flat(NAVY))
		t.set_stylebox("selected_focus", type, flat(NAVY))
		t.set_stylebox("cursor", type, StyleBoxEmpty.new())
		t.set_stylebox("cursor_unfocused", type, StyleBoxEmpty.new())
		t.set_stylebox("hovered", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_selected_color", type, WHITE)
		t.set_color("font_hovered_color", type, TEXT)
		t.set_color("guide_color", type, Color(0, 0, 0, 0))
	t.set_stylebox("title_button_normal", "Tree", box("raised", FACE, Vector4(4, 2, 4, 2)))
	t.set_stylebox("title_button_hover", "Tree", box("raised", FACE, Vector4(4, 2, 4, 2)))
	t.set_stylebox("title_button_pressed", "Tree", box("pressed", FACE, Vector4(4, 2, 4, 2)))
	t.set_color("title_button_color", "Tree", TEXT)
	t.set_font("title_button_font", "Tree", FONT)
	t.set_font_size("title_button_font_size", "Tree", FONT_SIZE)
	t.set_constant("v_separation", "Tree", 1)
	t.set_constant("item_margin", "Tree", 2)
	t.set_constant("h_separation", "Tree", 4)
	t.set_constant("draw_guides", "Tree", 0)
	t.set_constant("draw_relationship_lines", "Tree", 0)

	# Panels
	t.set_stylebox("panel", "Panel", flat(FACE, Vector4.ZERO))
	t.set_stylebox("panel", "PanelContainer", flat(FACE, Vector4(4, 4, 4, 4)))

	# Scrollbars: dithered track, raised thumb, raised arrow buttons.
	var track := StyleBoxTexture.new()
	track.texture = _dither_texture()
	track.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	track.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, box("raised", FACE, Vector4(7, 7, 7, 7)))
		t.set_stylebox("grabber_highlight", type, box("raised", FACE, Vector4(7, 7, 7, 7)))
		t.set_stylebox("grabber_pressed", type, box("raised", FACE, Vector4(7, 7, 7, 7)))
	t.set_icon("increment", "VScrollBar", _arrow_button(Vector2i(0, 1)))
	t.set_icon("increment_highlight", "VScrollBar", _arrow_button(Vector2i(0, 1)))
	t.set_icon("increment_pressed", "VScrollBar", _arrow_button(Vector2i(0, 1), true))
	t.set_icon("decrement", "VScrollBar", _arrow_button(Vector2i(0, -1)))
	t.set_icon("decrement_highlight", "VScrollBar", _arrow_button(Vector2i(0, -1)))
	t.set_icon("decrement_pressed", "VScrollBar", _arrow_button(Vector2i(0, -1), true))
	t.set_icon("increment", "HScrollBar", _arrow_button(Vector2i(1, 0)))
	t.set_icon("increment_highlight", "HScrollBar", _arrow_button(Vector2i(1, 0)))
	t.set_icon("increment_pressed", "HScrollBar", _arrow_button(Vector2i(1, 0), true))
	t.set_icon("decrement", "HScrollBar", _arrow_button(Vector2i(-1, 0)))
	t.set_icon("decrement_highlight", "HScrollBar", _arrow_button(Vector2i(-1, 0)))
	t.set_icon("decrement_pressed", "HScrollBar", _arrow_button(Vector2i(-1, 0), true))

	# Tabs
	t.set_stylebox("tab_selected", "TabContainer", box("thin_raised", FACE, Vector4(8, 3, 8, 3)))
	t.set_stylebox("tab_unselected", "TabContainer", box("thin_raised", Color8(184, 184, 184), Vector4(6, 2, 6, 2)))
	t.set_stylebox("tab_hovered", "TabContainer", box("thin_raised", Color8(184, 184, 184), Vector4(6, 2, 6, 2)))
	t.set_stylebox("panel", "TabContainer", box("raised", FACE, Vector4(4, 4, 4, 4)))
	for c in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		t.set_color(c, "TabContainer", TEXT)

	# Progress (downloads, setup)
	t.set_stylebox("background", "ProgressBar", box("field", WHITE, Vector4(2, 2, 2, 2)))
	t.set_stylebox("fill", "ProgressBar", _blocks_fill())
	t.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))

	# Check boxes
	t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_icon("radio_checked", "CheckBox", _radio_icon(true))
	t.set_icon("radio_unchecked", "CheckBox", _radio_icon(false))
	for s in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
		t.set_stylebox(s, "CheckBox", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckBox", TEXT)

	# Menus
	t.set_stylebox("panel", "PopupMenu", box("window", FACE, Vector4(3, 3, 3, 3)))
	t.set_stylebox("hover", "PopupMenu", flat(NAVY))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", WHITE)

	# Tooltips
	var tip := StyleBoxFlat.new()
	tip.bg_color = TOOLTIP
	tip.border_color = DARK
	tip.set_border_width_all(1)
	tip.content_margin_left = 3
	tip.content_margin_right = 3
	tip.content_margin_top = 1
	tip.content_margin_bottom = 1
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)

	_theme = t
	return t


# ── generated pixel art ──────────────────────────────────────────────────────

static func _dither_texture() -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, WHITE)
	img.set_pixel(1, 1, WHITE)
	img.set_pixel(1, 0, FACE)
	img.set_pixel(0, 1, FACE)
	return ImageTexture.create_from_image(img)


static func _arrow_button(dir: Vector2i, pressed := false) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(FACE)
	var rings := [[DARK, WHITE], [SHADOW, LIGHT]] if pressed else [[WHITE, DARK], [LIGHT, SHADOW]]
	for r in 2:
		for i in range(r, 16 - r):
			img.set_pixel(i, r, rings[r][0])
			img.set_pixel(r, i, rings[r][0])
			img.set_pixel(i, 15 - r, rings[r][1])
			img.set_pixel(15 - r, i, rings[r][1])
	var o := 1 if pressed else 0
	# A small solid triangle, 7 wide, 4 tall.
	for k in 4:
		for j in range(-3 + k, 4 - k):
			var x := 0
			var y := 0
			if dir.y != 0:
				x = 7 + j + o
				y = (6 + k if dir.y > 0 else 9 - k) + o
			else:
				y = 7 + j + o
				x = (6 + k if dir.x > 0 else 9 - k) + o
			img.set_pixel(x, y, DARK)
	return ImageTexture.create_from_image(img)


static func _blocks_fill() -> StyleBoxTexture:
	var img := Image.create(10, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(0, 12):
		for x in range(0, 8):
			img.set_pixel(x, y, NAVY)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func _check_icon(checked: bool) -> Texture2D:
	var img := Image.create(13, 13, false, Image.FORMAT_RGBA8)
	img.fill(WHITE)
	for i in 13:
		img.set_pixel(i, 0, SHADOW)
		img.set_pixel(0, i, SHADOW)
		img.set_pixel(i, 12, WHITE)
		img.set_pixel(12, i, WHITE)
	for i in range(1, 12):
		img.set_pixel(i, 1, DARK)
		img.set_pixel(1, i, DARK)
		img.set_pixel(i, 11, LIGHT)
		img.set_pixel(11, i, LIGHT)
	if checked:
		var pts := [[3, 5], [3, 6], [3, 7], [4, 6], [4, 7], [4, 8], [5, 7], [5, 8], [5, 9], [6, 6], [6, 7], [6, 8], [7, 5], [7, 6], [7, 7], [8, 4], [8, 5], [8, 6], [9, 3], [9, 4], [9, 5]]
		for p in pts:
			img.set_pixel(p[0], p[1], DARK)
	return ImageTexture.create_from_image(img)


static func _radio_icon(checked: bool) -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		for x in 12:
			var d := Vector2(x - 5.5, y - 5.5).length()
			if d <= 5.8:
				img.set_pixel(x, y, WHITE)
			if d > 4.6 and d <= 5.8:
				img.set_pixel(x, y, SHADOW if (x + y) < 12 else LIGHT)
			if checked and d <= 1.9:
				img.set_pixel(x, y, DARK)
	return ImageTexture.create_from_image(img)
