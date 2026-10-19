extends Control

## A progress bar the way 1998 drew them (the one-click installs in os_shell.gd and the
## program shelves, Builder's title picture):
##   "blocks"   the system's own: a sunken white well, navy blocks with a pixel of gap,
##              each new block blinks in brighter and settles; it never moves back
##   "install"  InstallShield's: a navy-to-blue fill over a sunken well, the percentage
##              in the middle, white where the fill is under it and black where not
## `value` 0..1. The shown value follows it in steps, so a bar never slides smoothly.

const T = preload("res://scripts/os98/os_theme.gd")

var style := "blocks"
var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var show_percent := false
var _shown := 0.0
var _flash := 0.0
var _last_blocks := 0


func _init(p_style := "blocks") -> void:
	style = p_style
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 16)


func _process(delta: float) -> void:
	# Catch up in hops of a few percent, the way the real ones jumped.
	if _shown < value:
		_shown = minf(value, _shown + maxf(0.02, (value - _shown) * 0.5) * clampf(delta * 18.0, 0.0, 1.0))
		queue_redraw()
	elif _shown > value + 0.001 and value <= 0.001:
		_shown = 0.0
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	var inner := r.grow(-3)
	if style == "install":
		_draw_install(inner)
	else:
		_draw_blocks(inner)


func _draw_blocks(inner: Rect2) -> void:
	var bw := 8.0
	var gap := 2.0
	var count := int(floor((inner.size.x + gap) / (bw + gap)))
	var n := int(floor(_shown * float(count) + 0.0001))
	if n > _last_blocks:
		_flash = 1.0
	_last_blocks = n
	for i in n:
		var x := inner.position.x + float(i) * (bw + gap)
		var col := T.NAVY
		if i == n - 1 and _flash > 0.0:
			col = T.NAVY.lerp(Color8(60, 110, 240), _flash)
		draw_rect(Rect2(x, inner.position.y, bw, inner.size.y), col)
		# A brighter top row on each block: the shine they had.
		draw_rect(Rect2(x, inner.position.y, bw, 1), col.lightened(0.35))


func _draw_install(inner: Rect2) -> void:
	var w := floorf(inner.size.x * _shown)
	var steps := 24
	for i in steps:
		var x0 := inner.position.x + w * float(i) / steps
		var x1 := inner.position.x + w * float(i + 1) / steps
		draw_rect(Rect2(x0, inner.position.y, ceilf(x1 - x0), inner.size.y), T.NAVY.lerp(Color8(16, 132, 208), float(i) / steps))
	if w > 0:
		draw_rect(Rect2(inner.position.x, inner.position.y, w, 1), Color(1, 1, 1, 0.25))
	if not show_percent:
		return
	var txt := "%d%%" % int(round(_shown * 100.0))
	var tw := T.FONT_BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var pos := Vector2(floorf(inner.get_center().x - tw * 0.5), floorf(inner.get_center().y + 4))
	var fill_end := inner.position.x + w
	# Black over the empty part, white over the fill: drawn twice, clipped by halves.
	draw_string(T.FONT_BOLD, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	if fill_end > pos.x:
		var clip_w := minf(tw, fill_end - pos.x)
		# Godot has no per-draw clip: paint the white copy glyph by glyph where filled.
		var x := pos.x
		for ch in txt:
			var cw := T.FONT_BOLD.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			if x + cw * 0.5 <= pos.x + clip_w:
				draw_rect(Rect2(x, inner.position.y, cw, inner.size.y), T.NAVY.lerp(Color8(16, 132, 208), clampf((x - inner.position.x) / maxf(1.0, w), 0.0, 1.0)))
				draw_string(T.FONT_BOLD, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
			x += cw
