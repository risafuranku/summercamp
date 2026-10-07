extends RefCounted

## Shared 90s / Build-engine UI kit: pixel fonts, the palette, bevelled plates, meters,
## the status face and big outlined titles. Used by the world HUD, the main menu, the
## pause menu, loading screens and the game-over screen.
##
## Everything is sized in "virtual pixels" (vp) and multiplied by an integer UI scale so
## pixel fonts and bevels stay crisp: 720p -> 3x, 1080p -> 4x (see ui_scale()).
##
## The fonts are BMFont bitmaps baked on their native pixel grid by
## tools/gen_pixel_fonts.py and imported with integer-only scaling, so a font pixel is
## always exactly `scale` x `scale` screen pixels. Ask for `size_vp` = the font's
## nominal size (8 for LABEL/TEXT, 10 for BIG) or a whole multiple of it; anything else
## snaps down to the previous whole multiple. OFL licences: assets/fonts/*-OFL.txt.
##
## Inner classes cannot call this script's static functions, only read its constants,
## which is why a few small computations are repeated inside them.

## Silkscreen, 8 px em, caps only: captions, labels, hints.
const FONT_LABEL: FontFile = preload("res://assets/fonts/silkscreen.fnt")
## Tiny5, 8 px em, mixed case: body text, message feed, tracker, quotes.
const FONT_TEXT: FontFile = preload("res://assets/fonts/tiny5.fnt")
## Jersey 10, 10 px caps: big readouts, titles, banners (use 20 / 30 for 2x / 3x).
const FONT_BIG: FontFile = preload("res://assets/fonts/jersey10.fnt")
const FONT_TITLE: FontFile = FONT_BIG

const SIZE_LABEL := 8
const SIZE_TEXT := 8
const SIZE_BIG := 10

const PLATE_TEXTURE_PATH := "res://assets/textury/redneck/RRTX0192.png"
const INSET_TEXTURE_PATH := "res://assets/textury/redneck/RRTX0187.png"

# Palette (picked from the Build palette ramps so UI and world agree).
const C_BLACK := Color(0.02, 0.02, 0.02, 1.0)
const C_LCD := Color(0.05, 0.045, 0.035, 0.96)
const C_PLATE := Color(0.26, 0.23, 0.20, 1.0)
const C_PLATE_LIGHT := Color(0.52, 0.47, 0.40, 1.0)
const C_PLATE_DARK := Color(0.09, 0.08, 0.07, 1.0)
const C_PANEL := Color(0.07, 0.06, 0.05, 0.86)
const C_PANEL_LIGHT := Color(0.45, 0.36, 0.20, 0.95)
const C_AMBER := Color(1.0, 0.72, 0.22, 1.0)
const C_AMBER_LIGHT := Color(1.0, 0.88, 0.52, 1.0)
const C_AMBER_DIM := Color(0.62, 0.42, 0.14, 1.0)
const C_BONE := Color(0.93, 0.89, 0.78, 1.0)
const C_BONE_DIM := Color(0.62, 0.58, 0.50, 1.0)
const C_RED := Color(0.90, 0.16, 0.12, 1.0)
const C_RED_LIGHT := Color(1.0, 0.42, 0.34, 1.0)
const C_RED_DARK := Color(0.42, 0.05, 0.04, 1.0)
const C_GREEN := Color(0.46, 0.86, 0.36, 1.0)
const C_GREEN_LIGHT := Color(0.74, 0.98, 0.58, 1.0)
const C_BLUE := Color(0.46, 0.64, 0.95, 1.0)
const C_NIGHT := Color(0.72, 0.80, 1.0, 1.0)
const C_QUOTE := Color(0.98, 0.88, 0.62, 1.0)
const C_SHADOW := Color(0.0, 0.0, 0.0, 0.85)
const C_OUTLINE := Color(0.10, 0.03, 0.02, 1.0)

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


## Label in one of the kit fonts. `size_vp` is the font's nominal size or a multiple of
## it (see the header). The drop shadow is one font pixel.
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
	var px := font_pixel(font, size_vp) * scale
	if shadow:
		l.add_theme_color_override("font_shadow_color", C_SHADOW)
		l.add_theme_constant_override("shadow_offset_x", px)
		l.add_theme_constant_override("shadow_offset_y", px)
	else:
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("line_spacing", scale)


## How many virtual pixels one font pixel covers at `size_vp` (2 for Jersey at 20).
static func font_pixel(font: Font, size_vp: int) -> int:
	var nominal := SIZE_BIG if font == FONT_BIG else SIZE_LABEL
	return maxi(1, size_vp / nominal)


## Capital height in screen pixels (font pixels: Jersey 10, Silkscreen 5, Tiny5 5).
static func cap_height_px(font: Font, size_vp: int, scale: int) -> float:
	var cap := 10 if font == FONT_BIG else 5
	return float(cap * font_pixel(font, size_vp) * scale)


## Puts `l` so its first baseline sits at `baseline_vp` inside its parent.
static func place_on_baseline(l: Label, baseline_vp: float, scale: int) -> void:
	var font := l.get_theme_font("font")
	var size := l.get_theme_font_size("font_size")
	var top := baseline_vp * float(scale) - font.get_ascent(size)
	l.offset_top = top
	l.offset_bottom = top + font.get_height(size)


## Width of `text` in screen pixels.
static func text_width(text: String, font: Font, size_vp: int, scale: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_vp * scale).x


## Button styled as a bevelled plate with a pixel font.
static func style_button(b: Button, font: Font, size_vp: int, scale: int, accent: Color = C_AMBER) -> void:
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size_vp * scale)
	b.add_theme_color_override("font_color", C_BONE)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_pressed_color", accent.darkened(0.2))
	b.add_theme_color_override("font_focus_color", accent)
	b.add_theme_color_override("font_hover_pressed_color", accent)
	b.add_theme_color_override("font_disabled_color", C_BONE_DIM.darkened(0.3))
	b.add_theme_color_override("font_shadow_color", C_SHADOW)
	b.add_theme_constant_override("shadow_offset_x", scale)
	b.add_theme_constant_override("shadow_offset_y", scale)
	b.add_theme_stylebox_override("normal", bevel_box(Color(0.12, 0.10, 0.09, 0.94), C_PLATE_LIGHT.darkened(0.3), C_BLACK, scale))
	b.add_theme_stylebox_override("hover", bevel_box(Color(0.22, 0.14, 0.08, 0.96), accent.darkened(0.15), C_BLACK, scale))
	b.add_theme_stylebox_override("pressed", bevel_box(Color(0.06, 0.05, 0.04, 0.96), C_BLACK, accent.darkened(0.2), scale))
	b.add_theme_stylebox_override("hover_pressed", bevel_box(Color(0.06, 0.05, 0.04, 0.96), C_BLACK, accent.darkened(0.2), scale))
	b.add_theme_stylebox_override("focus", flat_box(Color(0, 0, 0, 0), accent, scale))
	b.add_theme_stylebox_override("disabled", bevel_box(Color(0.08, 0.08, 0.08, 0.8), C_PLATE_DARK, C_BLACK, scale))


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


## Bevel as a StyleBox: `light` on the top/left edge, `dark` on the bottom/right, one
## virtual pixel thick (swap the colours for a pressed/recessed look). A nine-patch
## texture, because StyleBoxFlat only has one border colour.
static func bevel_box(bg: Color, light: Color, dark: Color, scale: int, pad_vp: int = 3) -> StyleBoxTexture:
	var key := "%s|%s|%s|%d" % [bg.to_html(), light.to_html(), dark.to_html(), scale]
	var tex: Texture2D = _tex_cache.get(key, null)
	if tex == null:
		var n := scale * 2 + 2
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(bg)
		for i in n:
			for t in scale:
				img.set_pixel(i, t, light)
				img.set_pixel(t, i, light)
				img.set_pixel(i, n - 1 - t, dark)
				img.set_pixel(n - 1 - t, i, dark)
		tex = ImageTexture.create_from_image(img)
		_tex_cache[key] = tex
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(scale)
	sb.content_margin_left = pad_vp * scale
	sb.content_margin_right = pad_vp * scale
	sb.content_margin_top = pad_vp * scale
	sb.content_margin_bottom = pad_vp * scale
	return sb


## A bevelled plate (raised or recessed), optionally textured with a tiled Build
## texture. With `fit_children` it behaves like a PanelContainer: children are fitted
## inside `pad_vp` and the plate grows to their minimum size. Without it, children keep
## the positions the caller gives them (status-bar cells).
class BevelPanel:
	extends Container

	var ui_scale: int = 3
	var fill: Color = Color(0.26, 0.23, 0.20, 1.0)
	var light: Color = Color(0.52, 0.47, 0.40, 1.0)
	var dark: Color = Color(0.09, 0.08, 0.07, 1.0)
	var recessed: bool = false
	var bevel_vp: int = 1
	var tile_texture: Texture2D
	var tile_tint: Color = Color(0.8, 0.78, 0.74, 1.0)
	var fit_children: bool = false
	var pad_vp: Vector4 = Vector4(4, 3, 4, 3) # left, top, right, bottom

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
		elif what == NOTIFICATION_SORT_CHILDREN and fit_children:
			var s := float(ui_scale)
			var r := Rect2(Vector2(pad_vp.x, pad_vp.y) * s, size - Vector2(pad_vp.x + pad_vp.z, pad_vp.y + pad_vp.w) * s)
			for child in get_children():
				var c := child as Control
				if c != null and c.visible and not c.top_level:
					fit_child_in_rect(c, r)

	func _get_minimum_size() -> Vector2:
		if not fit_children:
			return Vector2.ZERO
		var m := Vector2.ZERO
		for child in get_children():
			var c := child as Control
			if c != null and c.visible and not c.top_level:
				m = m.max(c.get_combined_minimum_size())
		var s := float(ui_scale)
		return m + Vector2(pad_vp.x + pad_vp.z, pad_vp.y + pad_vp.w) * s

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
	var blink: bool = false:
		set(v):
			blink = v
			set_process(v)
			queue_redraw()
	var _t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func set_value(v: float) -> void:
		var nv := clampf(v, 0.0, 1.0)
		if not is_equal_approx(nv, value):
			value = nv
			queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var gap := float(ui_scale)
		var seg_w := floorf((size.x - gap * float(segments - 1)) / float(segments))
		var used := seg_w * float(segments) + gap * float(segments - 1)
		var x0 := floorf((size.x - used) * 0.5)
		var lit := int(ceil(value * float(segments) - 0.001))
		var col := color_low.lerp(color_full, clampf(value * 1.4 - 0.2, 0.0, 1.0))
		if blink and value < 0.3 and fmod(_t, 0.5) < 0.25:
			col = col.darkened(0.6)
		for i in segments:
			var x := x0 + float(i) * (seg_w + gap)
			draw_rect(Rect2(x, 0, seg_w, size.y), col if i < lit else color_off)
			if i < lit:
				# One-pixel highlight on lit segments, like a backlit LCD bar.
				draw_rect(Rect2(x, 0, seg_w, float(ui_scale)), col.lightened(0.35))


## Doom-style status face drawn in pixels. `mood` 0-100 bends the mouth and colours the
## skin; `fear` 0-1 widens the eyes. Used for the camp mood (and guest cards).
class PixelFace:
	extends Control

	var ui_scale: int = 3
	var mood: float = 60.0
	var fear: float = 0.0
	var empty: bool = false
	var _blink_t: float = 0.0
	var _was_blinking: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(m: float, f: float, is_empty: bool = false) -> void:
		if is_equal_approx(m, mood) and is_equal_approx(f, fear) and is_empty == empty:
			return
		mood = m
		fear = f
		empty = is_empty
		queue_redraw()

	func _process(delta: float) -> void:
		_blink_t += delta
		var blinking := fmod(_blink_t, 3.7) > 3.58
		if blinking != _was_blinking:
			_was_blinking = blinking
			queue_redraw()

	func _px(x: int, y: int, w: int, h: int, c: Color) -> void:
		var s := float(ui_scale)
		var origin := ((size - Vector2(16, 16) * s) * 0.5).floor()
		draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(w, h) * s), c)

	func _draw() -> void:
		var skin := Color(0.92, 0.76, 0.40)
		if empty:
			skin = Color(0.35, 0.33, 0.30)
		elif mood < 35.0:
			skin = Color(0.90, 0.46, 0.30)
		elif mood >= 70.0:
			skin = Color(0.96, 0.84, 0.44)
		var shade := skin.darkened(0.28)
		var ink := Color(0.10, 0.06, 0.04)
		# head
		_px(4, 1, 8, 1, ink)
		_px(2, 2, 12, 1, ink)
		_px(1, 3, 14, 10, ink)
		_px(2, 13, 12, 1, ink)
		_px(4, 14, 8, 1, ink)
		_px(4, 2, 8, 1, skin)
		_px(2, 3, 12, 10, skin)
		_px(4, 13, 8, 1, shade)
		_px(11, 3, 3, 10, shade)
		_px(2, 12, 12, 1, shade)
		# eyes (blink every few seconds, wide when afraid)
		var blinking := _was_blinking
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


## Big title in the Build/Duke manner: pixel font, one-font-pixel dark outline, a drop
## shadow and a two-tone fill (light upper half, darker lower half). Bitmap fonts have
## no outline support, so the outline is stamped in eight directions.
## Sizes itself (custom_minimum_size) from the text, so containers can centre it.
class PixelTitle:
	extends Control

	var ui_scale: int = 3
	var font: Font
	var size_vp: int = 20
	var text: String = ""
	var color_top: Color = Color(1.0, 0.88, 0.52, 1.0)
	var color_bottom: Color = Color(1.0, 0.62, 0.16, 1.0)
	var outline_color: Color = Color(0.10, 0.03, 0.02, 1.0)
	var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.7)
	## Fraction of the cap height (from the top) drawn in color_top.
	var split: float = 0.5
	var _base: _Stamp
	var _clip: Control
	var _top: _Stamp

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_base = _Stamp.new()
		add_child(_base)
		_clip = Control.new()
		_clip.clip_contents = true
		_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_clip)
		_top = _Stamp.new()
		_clip.add_child(_top)

	func configure(p_font: Font, p_size_vp: int, p_scale: int) -> void:
		font = p_font
		size_vp = p_size_vp
		ui_scale = p_scale
		_relayout()

	func set_text(value: String) -> void:
		if value == text:
			return
		text = value
		_relayout()

	func set_colors(top: Color, bottom: Color) -> void:
		color_top = top
		color_bottom = bottom
		_relayout()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_relayout()

	func _font_px() -> float:
		var nominal := SIZE_BIG if font == FONT_BIG else SIZE_LABEL
		return float(maxi(1, size_vp / nominal) * ui_scale)

	func _relayout() -> void:
		if font == null:
			return
		var fsize := size_vp * ui_scale
		var px := _font_px()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var cap_px := (10.0 if font == FONT_BIG else 5.0) * px
		# Tight box: outline above, cap height, outline + 2px shadow below. Titles are
		# set in capitals; descenders may hang below the box.
		custom_minimum_size = Vector2(w + px * 3.0, cap_px + px * 4.0)
		var origin_x := floorf(maxf(px, (size.x - w) * 0.5) / px) * px
		var baseline := px + cap_px
		var cap_top := px
		for stamp in [_base, _top]:
			stamp.font = font
			stamp.font_size = fsize
			stamp.text = text
			stamp.px = px
			stamp.origin = Vector2(origin_x, baseline)
			stamp.position = Vector2.ZERO
			stamp.size = size
		_base.fill = color_bottom
		_base.outline = outline_color
		_base.shadow = shadow_color
		_top.fill = color_top
		_top.outline = Color(0, 0, 0, 0)
		_top.shadow = Color(0, 0, 0, 0)
		var split_y := cap_top + floorf(cap_px * split / px) * px
		_clip.position = Vector2.ZERO
		_clip.size = Vector2(size.x, maxf(0.0, split_y))
		_base.queue_redraw()
		_top.queue_redraw()

	class _Stamp:
		extends Control

		var font: Font
		var font_size: int = 16
		var text: String = ""
		var px: float = 3.0
		var origin: Vector2 = Vector2.ZERO
		var fill: Color = Color.WHITE
		var outline: Color = Color.BLACK
		var shadow: Color = Color(0, 0, 0, 0)

		func _init() -> void:
			mouse_filter = Control.MOUSE_FILTER_IGNORE

		func _draw() -> void:
			if font == null or text.is_empty():
				return
			if shadow.a > 0.0:
				draw_string(font, origin + Vector2(px * 2.0, px * 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
			if outline.a > 0.0:
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx == 0 and dy == 0:
							continue
						draw_string(font, origin + Vector2(dx, dy) * px, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline)
			draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)
