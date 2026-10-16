extends RefCounted

## Seven-segment digits like the alarm clock's vacuum-fluorescent display: bevelled bar
## segments, the unlit ones faintly visible (a VFD never goes fully dark), the lit ones
## with a soft phosphor bloom drawn as wider, fainter copies (no shader, no blur).
##
##   SEVEN_SEG.draw_text(canvas_item, Vector2(x, y), 40.0, "06:30", lit, ghost, true)

## Segment order a b c d e f g; which are lit for each digit.
const DIGITS := {
	"0": [1, 1, 1, 1, 1, 1, 0], "1": [0, 1, 1, 0, 0, 0, 0], "2": [1, 1, 0, 1, 1, 0, 1],
	"3": [1, 1, 1, 1, 0, 0, 1], "4": [0, 1, 1, 0, 0, 1, 1], "5": [1, 0, 1, 1, 0, 1, 1],
	"6": [1, 0, 1, 1, 1, 1, 1], "7": [1, 1, 1, 0, 0, 0, 0], "8": [1, 1, 1, 1, 1, 1, 1],
	"9": [1, 1, 1, 1, 0, 1, 1], "-": [0, 0, 0, 0, 0, 0, 1], " ": [0, 0, 0, 0, 0, 0, 0],
}


## Width of one digit cell for height `h` (the colon is a third of it).
static func digit_width(h: float) -> float:
	return h * 0.62


static func text_width(text: String, h: float) -> float:
	var w := 0.0
	for ch in text:
		w += (digit_width(h) * 0.42 if ch == ":" else digit_width(h)) + h * 0.12
	return w


## Draws `text` (digits, '-', ' ', ':') with its top-left at `pos`. `colon_on` lets
## the colon blink.
static func draw_text(ci: CanvasItem, pos: Vector2, h: float, text: String, lit: Color, ghost: Color, colon_on := true, glow := true) -> void:
	var x := pos.x
	for ch in text:
		if ch == ":":
			var cw := digit_width(h) * 0.42
			var s := maxf(1.0, h * 0.1)
			for yy in [0.32, 0.68]:
				var r := Rect2(Vector2(x + cw * 0.5 - s * 0.5, pos.y + h * yy - s * 0.5), Vector2(s, s))
				if glow and colon_on:
					ci.draw_rect(r.grow(s * 0.6), Color(lit, lit.a * 0.18))
				ci.draw_rect(r, lit if colon_on else ghost)
			x += cw + h * 0.12
			continue
		var on: Array = DIGITS.get(ch, DIGITS[" "])
		for i in 7:
			var poly := _segment(i, Vector2(x, pos.y), h)
			if on[i] == 1:
				if glow:
					ci.draw_colored_polygon(_grow(poly, h * 0.05), Color(lit, lit.a * 0.22))
				ci.draw_colored_polygon(poly, lit)
			else:
				ci.draw_colored_polygon(poly, ghost)
		x += digit_width(h) + h * 0.12


## One bevelled segment as a hexagon, slanted a little like real VFD digits.
static func _segment(i: int, o: Vector2, h: float) -> PackedVector2Array:
	var w := digit_width(h)
	var t := h * 0.11           # thickness
	var g := t * 0.18           # gap between segments
	var slant := h * 0.08
	var half := h * 0.5
	var pts: Array
	match i:
		0: pts = _hbar(Vector2(t * 0.5 + g, 0), w - t - g * 2.0, t)
		3: pts = _hbar(Vector2(t * 0.5 + g, h - t), w - t - g * 2.0, t)
		6: pts = _hbar(Vector2(t * 0.5 + g, half - t * 0.5), w - t - g * 2.0, t)
		1: pts = _vbar(Vector2(w - t, t * 0.5 + g), half - t * 0.5 - g * 2.0, t)
		2: pts = _vbar(Vector2(w - t, half + g), half - t * 0.5 - g * 2.0, t)
		4: pts = _vbar(Vector2(0, half + g), half - t * 0.5 - g * 2.0, t)
		_: pts = _vbar(Vector2(0, t * 0.5 + g), half - t * 0.5 - g * 2.0, t)
	var out := PackedVector2Array()
	for p in pts:
		var q: Vector2 = p
		out.append(o + Vector2(q.x + slant * (1.0 - q.y / h), q.y))
	return out


static func _hbar(p: Vector2, length: float, t: float) -> Array:
	return [p + Vector2(0, t * 0.5), p + Vector2(t * 0.5, 0), p + Vector2(length - t * 0.5, 0), p + Vector2(length, t * 0.5), p + Vector2(length - t * 0.5, t), p + Vector2(t * 0.5, t)]


static func _vbar(p: Vector2, length: float, t: float) -> Array:
	return [p + Vector2(t * 0.5, 0), p + Vector2(t, t * 0.5), p + Vector2(t, length - t * 0.5), p + Vector2(t * 0.5, length), p + Vector2(0, length - t * 0.5), p + Vector2(0, t * 0.5)]


static func _grow(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + (p - c).normalized() * by)
	return out
