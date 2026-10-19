extends RefCounted

## The games' table of best results, drawn the way their own dialogs drew it (Mines'
## "Best Times"): a small window, a title band, five rows of a name and a number, the
## new one picked out. Rows come from os_shell.scores(game).

const T = preload("res://scripts/os98/os_theme.gd")
const SIZE := Vector2(176, 118)


static func draw(ci: CanvasItem, at: Vector2, title: String, rows: Array, unit: String, highlight := -1) -> void:
	var r := Rect2(at.floor(), SIZE)
	ci.draw_style_box(T.box("window", T.FACE), r)
	var band := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 16))
	for i in int(ceil(band.size.x / 8.0)):
		ci.draw_rect(Rect2(band.position.x + i * 8, band.position.y, minf(8.0, band.size.x - i * 8), band.size.y), T.TITLE_A.lerp(T.TITLE_B, float(i * 8) / band.size.x))
	ci.draw_string(T.FONT_BOLD, band.position + Vector2(4, 12), title, HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 8, T.FONT_SIZE, T.WHITE)
	var well := Rect2(r.position + Vector2(8, 24), Vector2(r.size.x - 16, r.size.y - 32))
	ci.draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), well)
	for i in rows.size():
		var y := well.position.y + 4 + i * 16
		var row: Array = rows[i]
		var on := i == highlight
		if on:
			ci.draw_rect(Rect2(well.position.x + 2, y, well.size.x - 4, 15), T.NAVY)
		var col := T.WHITE if on else T.TEXT
		ci.draw_string(T.FONT, Vector2(well.position.x + 6, y + 12), "%d." % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE if on else T.SHADOW)
		ci.draw_string(T.FONT_BOLD if on else T.FONT, Vector2(well.position.x + 22, y + 12), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, 80, T.FONT_SIZE, col)
		ci.draw_string(T.FONT, Vector2(well.position.x, y + 12), "%d %s" % [int(row[1]), unit], HORIZONTAL_ALIGNMENT_RIGHT, well.size.x - 6, T.FONT_SIZE, col)
