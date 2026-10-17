extends Control

## Small dotted rings down the right edge of the screen, one per party on the way (the
## bookings you accepted): the ring fills dash by dash as they come nearer, the number in
## it is how many they are, the dot under it their kind. When they reach the barrier the
## ring turns green and breathes, and a thin red ring inside it runs down their patience.
## The full list (names, rooms, times) stays on TAB. Fed by hud_manager.set_arrivals().

const DASHES := 18
const MAX_RINGS := 6
const AMBER := Color(0.96, 0.72, 0.24)
const DIM := Color(0.94, 0.88, 0.72, 0.28)
const GREEN := Color(0.44, 0.9, 0.42)
const RED := Color(0.94, 0.3, 0.22)
const KIND := {
	"quiet_guy": Color(0.62, 0.72, 0.56), "drunk": Color(0.96, 0.56, 0.2), "cheap_chick": Color(0.96, 0.46, 0.7),
	"tramp": Color(0.72, 0.52, 0.32), "family": Color(0.4, 0.62, 0.96), "picker": Color(0.7, 0.5, 0.86),
}

var font: Font
var _rows: Array = []
## The longest wait seen for each party (its whole journey; its whole patience).
var _trip: Dictionary = {}
var _patience: Dictionary = {}
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_rows(rows: Array) -> void:
	_rows = rows.duplicate(true)
	var seen := {}
	for r in _rows:
		var id := int(r.get("id", -1))
		seen[id] = true
		if bool(r.get("at_gate", false)):
			_patience[id] = maxf(float(_patience.get(id, 0.0)), float(r.get("patience_left", 0)))
		else:
			_trip[id] = maxf(float(_trip.get(id, 0.0)), float(r.get("minutes", 0)))
	for d in [_trip, _patience]:
		for id in d.keys():
			if not seen.has(id):
				d.erase(id)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not _rows.is_empty():
		queue_redraw()


func _draw() -> void:
	if _rows.is_empty():
		return
	var s := size
	var r := maxf(10.0, s.y * 0.025)
	var gap := r * 2.9
	var n := mini(_rows.size(), MAX_RINGS)
	var x := s.x - r * 2.0
	var y0 := s.y * 0.42 - gap * float(n - 1) * 0.5
	var f: Font = font if font != null else get_theme_default_font()
	var fs := int(maxf(10.0, r * 1.05))
	for i in n:
		var row: Dictionary = _rows[i]
		var id := int(row.get("id", -1))
		var c := Vector2(x, y0 + gap * float(i))
		var at_gate := bool(row.get("at_gate", false))
		var minutes := float(row.get("minutes", 0))
		# A dark disc so the ring reads over sky and grass alike.
		draw_circle(c, r * 1.18, Color(0, 0, 0, 0.32))
		var lit := 0
		var col := AMBER
		if at_gate:
			lit = DASHES
			col = Color(GREEN.r, GREEN.g, GREEN.b, 0.6 + 0.4 * absf(sin(_t * 3.0)))
		else:
			var whole := maxf(1.0, float(_trip.get(id, minutes)))
			lit = clampi(int(round((1.0 - minutes / whole) * float(DASHES))), 0, DASHES)
		for k in DASHES:
			var a0 := -PI * 0.5 + TAU * float(k) / float(DASHES)
			var a1 := a0 + TAU / float(DASHES) * 0.55
			draw_arc(c, r, a0, a1, 3, col if k < lit else DIM, maxf(2.0, r * 0.2))
		if at_gate:
			# Their patience, running down on a ring inside.
			var whole_p := maxf(1.0, float(_patience.get(id, 1.0)))
			var left := clampf(float(row.get("patience_left", 0)) / whole_p, 0.0, 1.0)
			var pk := int(ceil(left * float(DASHES)))
			for k in pk:
				var b0 := -PI * 0.5 + TAU * float(k) / float(DASHES)
				draw_arc(c, r * 0.72, b0, b0 + TAU / float(DASHES) * 0.5, 2, RED, maxf(1.0, r * 0.11))
		var txt := str(int(row.get("party_size", 1)))
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-tw * 0.5 + 1, fs * 0.36 + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
		draw_string(f, c + Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.94, 0.84))
		draw_circle(c + Vector2(0, r * 0.62), maxf(1.5, r * 0.13), KIND.get(str(row.get("archetype", "")), DIM))
		# How long, small, beside it (minutes on the way; minutes they will still wait).
		var m := int(row.get("patience_left", 0)) if at_gate else int(minutes)
		var t2 := ("%dh" % int(m / 60.0)) if m >= 90 else ("%d'" % m)
		var fs2 := int(maxf(8.0, fs * 0.7))
		var w2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(f, c + Vector2(-r * 1.35 - w2, fs2 * 0.36), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.94, 0.88, 0.72, 0.55))
