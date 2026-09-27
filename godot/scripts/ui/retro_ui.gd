extends RefCounted

## Shared 90s / Build-engine UI kit: pixel fonts, the palette, bevelled plates.
##
## Everything is sized in "virtual pixels" (vp) and multiplied by an integer UI scale so
## pixel fonts and bevels stay crisp: 720p -> 3x, 1080p -> 4x (see ui_scale()).
## Fonts are OFL-licensed (assets/fonts/*-OFL.txt).

const FONT_LABEL: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf")
const FONT_TEXT: FontFile = preload("res://assets/fonts/PixelifySans-Medium.ttf")
const FONT_TITLE: FontFile = preload("res://assets/fonts/EricaOne-Regular.ttf")

const PLATE_TEXTURE_PATH := "res://assets/textury/redneck/RRTX0192.png"
const INSET_TEXTURE_PATH := "res://assets/textury/redneck/RRTX0187.png"

# Palette (picked from the Build palette ramps so UI and world agree).
const C_BLACK := Color(0.02, 0.02, 0.02, 1.0)
const C_LCD := Color(0.05, 0.045, 0.035, 0.96)
const C_PLATE := Color(0.26, 0.23, 0.20, 1.0)
const C_PLATE_LIGHT := Color(0.52, 0.47, 0.40, 1.0)
const C_PLATE_DARK := Color(0.09, 0.08, 0.07, 1.0)
const C_AMBER := Color(1.0, 0.72, 0.22, 1.0)
const C_AMBER_DIM := Color(0.62, 0.42, 0.14, 1.0)
const C_BONE := Color(0.93, 0.89, 0.78, 1.0)
const C_BONE_DIM := Color(0.62, 0.58, 0.50, 1.0)
const C_RED := Color(0.90, 0.16, 0.12, 1.0)
const C_RED_DARK := Color(0.42, 0.05, 0.04, 1.0)
const C_GREEN := Color(0.46, 0.86, 0.36, 1.0)
const C_BLUE := Color(0.46, 0.64, 0.95, 1.0)
const C_SHADOW := Color(0.0, 0.0, 0.0, 0.85)

static var _tex_cache: Dictionary = {}


## Integer UI scale for a viewport: 240 vertical virtual pixels, like the world, but
## never wider than `min_width_vp` virtual pixels fit (4:3 windows get a smaller scale).
static func ui_scale(viewport_height: float, viewport_width: float = 0.0, min_width_vp: float = 420.0) -> int:
	var s := int(floor(viewport_height / 240.0))
	if viewport_width > 0.0:
		s = mini(s, int(floor(viewport_width / min_width_vp)))
	return maxi(2, s)


static func texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex := load(path) as Texture2D
	_tex_cache[path] = tex
	return tex


## Label in one of the kit fonts. `size_vp` is in virtual pixels (8 = one Silkscreen line).
static func label(text: String, font: Font, size_vp: int, color: Color, scale: int, shadow: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(l, font, size_vp, color, scale, shadow)
	return l


static func style_label(l: Label, font: Font, size_vp: int, color: Color, scale: int, shadow: bool = true) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_vp * scale)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", C_SHADOW)
		l.add_theme_constant_override("shadow_offset_x", scale)
		l.add_theme_constant_override("shadow_offset_y", scale)
	else:
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("line_spacing", scale)


## Button styled as a bevelled plate with a pixel font.
static func style_button(b: Button, font: Font, size_vp: int, scale: int, accent: Color = C_AMBER) -> void:
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size_vp * scale)
	b.add_theme_color_override("font_color", C_BONE)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_pressed_color", accent.darkened(0.2))
	b.add_theme_color_override("font_focus_color", accent)
	b.add_theme_color_override("font_disabled_color", C_BONE_DIM.darkened(0.3))
	b.add_theme_stylebox_override("normal", flat_box(Color(0.10, 0.09, 0.08, 0.92), C_PLATE_DARK, scale))
	b.add_theme_stylebox_override("hover", flat_box(Color(0.20, 0.13, 0.08, 0.96), accent.darkened(0.3), scale))
	b.add_theme_stylebox_override("pressed", flat_box(Color(0.06, 0.05, 0.04, 0.96), accent, scale))
	b.add_theme_stylebox_override("focus", flat_box(Color(0.20, 0.13, 0.08, 0.0), accent, scale))
	b.add_theme_stylebox_override("disabled", flat_box(Color(0.08, 0.08, 0.08, 0.8), C_PLATE_DARK, scale))


## Square, hard-edged box: the only StyleBox shape the design lock allows.
static func flat_box(bg: Color, border: Color, scale: int, border_vp: int = 1, pad_vp: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_vp * scale)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = pad_vp * scale
	sb.content_margin_right = pad_vp * scale
	sb.content_margin_top = pad_vp * scale
	sb.content_margin_bottom = pad_vp * scale
	return sb


## A bevelled plate (raised or recessed), optionally textured with a tiled Build
## texture. Draws itself; children are laid out by the caller.
class BevelPanel:
	extends Control

	var ui_scale: int = 3
	var fill: Color = Color(0.26, 0.23, 0.20, 1.0)
	var light: Color = Color(0.52, 0.47, 0.40, 1.0)
	var dark: Color = Color(0.09, 0.08, 0.07, 1.0)
	var recessed: bool = false
	var bevel_vp: int = 1
	var tile_texture: Texture2D
	var tile_tint: Color = Color(0.8, 0.78, 0.74, 1.0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, fill)
		if tile_texture != null:
			var ts := tile_texture.get_size() * float(ui_scale) * 0.5
			var y := 0.0
			while y < size.y:
				var x := 0.0
				while x < size.x:
					var w := minf(ts.x, size.x - x)
					var h := minf(ts.y, size.y - y)
					var src := Rect2(Vector2.ZERO, Vector2(w, h) / (float(ui_scale) * 0.5))
					draw_texture_rect_region(tile_texture, Rect2(x, y, w, h), src, tile_tint)
					x += ts.x
				y += ts.y
		var b := float(bevel_vp * ui_scale)
		var top_left := dark if recessed else light
		var bottom_right := light if recessed else dark
		draw_rect(Rect2(0, 0, size.x, b), top_left)
		draw_rect(Rect2(0, 0, b, size.y), top_left)
		draw_rect(Rect2(0, size.y - b, size.x, b), bottom_right)
		draw_rect(Rect2(size.x - b, 0, b, size.y), bottom_right)


## Horizontal segmented meter (Build-era health/ammo bars).
class SegmentBar:
	extends Control

	var ui_scale: int = 3
	var value: float = 1.0
	var segments: int = 10
	var color_full: Color = Color(0.46, 0.86, 0.36, 1.0)
	var color_low: Color = Color(0.90, 0.16, 0.12, 1.0)
	var color_off: Color = Color(0.12, 0.11, 0.10, 1.0)
	var blink: bool = false
	var _t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		var nv := clampf(v, 0.0, 1.0)
		if not is_equal_approx(nv, value):
			value = nv
			queue_redraw()

	func _process(delta: float) -> void:
		if blink:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var gap := float(ui_scale)
		var seg_w := (size.x - gap * float(segments - 1)) / float(segments)
		var lit := int(ceil(value * float(segments) - 0.001))
		var col := color_low.lerp(color_full, clampf(value * 1.4 - 0.2, 0.0, 1.0))
		if blink and value < 0.3 and fmod(_t, 0.5) < 0.25:
			col = col.darkened(0.6)
		for i in segments:
			var x := float(i) * (seg_w + gap)
			draw_rect(Rect2(x, 0, seg_w, size.y), col if i < lit else color_off)


## Doom-style status face drawn in pixels. `mood` 0-100 bends the mouth and colours the
## skin; `fear` 0-1 widens the eyes. Used for the camp mood (and guest cards).
class PixelFace:
	extends Control

	var ui_scale: int = 3
	var mood: float = 60.0
	var fear: float = 0.0
	var empty: bool = false
	var _blink_t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(m: float, f: float, is_empty: bool = false) -> void:
		mood = m
		fear = f
		empty = is_empty
		queue_redraw()

	func _process(delta: float) -> void:
		_blink_t += delta
		if fmod(_blink_t, 3.7) < delta * 1.5 or fmod(_blink_t, 3.7) > 3.58:
			queue_redraw()

	func _px(x: int, y: int, w: int, h: int, c: Color) -> void:
		var s := float(ui_scale)
		var origin := (size - Vector2(16, 16) * s) * 0.5
		draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(w, h) * s), c)

	func _draw() -> void:
		var skin := Color(0.92, 0.76, 0.40)
		if empty:
			skin = Color(0.35, 0.33, 0.30)
		elif mood < 35.0:
			skin = Color(0.90, 0.46, 0.30)
		elif mood >= 70.0:
			skin = Color(0.96, 0.84, 0.44)
		var ink := Color(0.10, 0.06, 0.04)
		# head
		_px(4, 1, 8, 1, ink)
		_px(2, 2, 12, 1, ink)
		_px(1, 3, 14, 10, ink)
		_px(2, 13, 12, 1, ink)
		_px(4, 14, 8, 1, ink)
		_px(4, 2, 8, 1, skin)
		_px(2, 3, 12, 10, skin)
		_px(4, 13, 8, 1, skin)
		# eyes (blink every few seconds, wide when afraid)
		var blinking := fmod(_blink_t, 3.7) > 3.58
		var eye_h := 1 if blinking else (3 if fear > 0.5 else 2)
		_px(4, 5, 2, eye_h, ink)
		_px(10, 5, 2, eye_h, ink)
		if fear > 0.5 and not blinking:
			_px(5, 5, 1, 1, Color(1, 1, 1))
			_px(11, 5, 1, 1, Color(1, 1, 1))
		# mouth
		if empty:
			_px(5, 10, 6, 1, ink)
		elif mood >= 62.0:
			_px(4, 9, 1, 1, ink)
			_px(11, 9, 1, 1, ink)
			_px(5, 10, 6, 1, ink)
		elif mood >= 35.0:
			_px(5, 10, 6, 1, ink)
		else:
			_px(5, 9, 6, 1, ink)
			_px(4, 10, 1, 1, ink)
			_px(11, 10, 1, 1, ink)
			# angry brows
			_px(3, 4, 3, 1, ink)
			_px(10, 4, 3, 1, ink)
