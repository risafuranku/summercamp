extends RefCounted

## A box with its corners rounded a little, in whole pixels (Richard 24. 11.: „všem
## čtvercovým highlightům a hoverům udělej lehce zaoblené hrany“): the hover hints and the
## highlights (retro_ui.draw_round_box, BevelPanel.rounded); the plates and buttons keep their
## square bevels (the design lock). `p` is one of the UI's pixels on the screen. Two steps:
## each corner's outer three pixels off. (Its own script: retro_ui's inner classes cannot
## call that script's static functions.)


static func round_fill(ci: CanvasItem, r: Rect2, p: float, fill: Color) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	ci.draw_rect(Rect2(x + 2.0 * p, y, w - 4.0 * p, p), fill)
	ci.draw_rect(Rect2(x + p, y + p, w - 2.0 * p, p), fill)
	ci.draw_rect(Rect2(x, y + 2.0 * p, w, h - 4.0 * p), fill)
	ci.draw_rect(Rect2(x + p, y + h - 2.0 * p, w - 2.0 * p, p), fill)
	ci.draw_rect(Rect2(x + 2.0 * p, y + h - p, w - 4.0 * p, p), fill)


## Its edge, a pixel wide: `top_left` along the top and the left, `bottom_right` along the
## bottom and the right, the corner steps with them.
static func round_edge(ci: CanvasItem, r: Rect2, p: float, top_left: Color, bottom_right: Color) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	ci.draw_rect(Rect2(x + 2.0 * p, y, w - 4.0 * p, p), top_left)
	ci.draw_rect(Rect2(x, y + 2.0 * p, p, h - 4.0 * p), top_left)
	ci.draw_rect(Rect2(x + p, y + p, p, p), top_left)
	ci.draw_rect(Rect2(x + w - 2.0 * p, y + p, p, p), top_left)
	ci.draw_rect(Rect2(x + p, y + h - 2.0 * p, p, p), top_left)
	ci.draw_rect(Rect2(x + 2.0 * p, y + h - p, w - 4.0 * p, p), bottom_right)
	ci.draw_rect(Rect2(x + w - p, y + 2.0 * p, p, h - 4.0 * p), bottom_right)
	ci.draw_rect(Rect2(x + w - 2.0 * p, y + h - 2.0 * p, p, p), bottom_right)


## One step: the corner pixel off (a small box: a PDA button).
static func round1_fill(ci: CanvasItem, r: Rect2, p: float, fill: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + p, r.position.y, r.size.x - 2.0 * p, r.size.y), fill)
	ci.draw_rect(Rect2(r.position.x, r.position.y + p, p, r.size.y - 2.0 * p), fill)
	ci.draw_rect(Rect2(r.end.x - p, r.position.y + p, p, r.size.y - 2.0 * p), fill)


static func round1_edge(ci: CanvasItem, r: Rect2, p: float, col: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + p, r.position.y, r.size.x - 2.0 * p, p), col)
	ci.draw_rect(Rect2(r.position.x + p, r.end.y - p, r.size.x - 2.0 * p, p), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + p, p, r.size.y - 2.0 * p), col)
	ci.draw_rect(Rect2(r.end.x - p, r.position.y + p, p, r.size.y - 2.0 * p), col)
