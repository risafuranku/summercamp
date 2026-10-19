extends Control

## A small bevelled plate down the right edge of the screen for each party you booked,
## in the order they will need you. The plate's picture says where they are: a car on the
## road (on the way to the camp), the desk bell (at the reception, waiting to be checked
## in). The bar beside it is the time: on the road it fills as they come nearer; at the
## desk it is their patience running down, amber and then red, blinking at the end. The
## number is how many they are, the stripe on the left their kind. The full list (names,
## rooms, times) stays on TAB. Fed by hud_manager.set_arrivals().

const MAX_ROWS := 6
const SEGMENTS := 8
## In the HUD's virtual pixels (ui_scale screen pixels each).
const PLATE := Vector2(50, 14)
const GAP := 3
const ICON_AT := Vector2(3, 3)
const BAR := Rect2(18, 5, 23, 4)
const FILL := Color(0.07, 0.06, 0.05, 0.86)
const LIGHT := Color(0.45, 0.36, 0.20, 0.95)
const DARK := Color(0.02, 0.02, 0.02, 0.95)
const SLOT := Color(0.0, 0.0, 0.0, 0.55)
const AMBER := Color(1.0, 0.72, 0.22)
const GREEN := Color(0.46, 0.86, 0.36)
const RED := Color(1.0, 0.42, 0.34)
const BONE := Color(0.93, 0.89, 0.78)
const KIND := {
	"quiet_guy": Color(0.62, 0.72, 0.56), "drunk": Color(0.96, 0.56, 0.2), "cheap_chick": Color(0.96, 0.46, 0.7),
	"tramp": Color(0.72, 0.52, 0.32), "family": Color(0.4, 0.62, 0.96), "picker": Color(0.7, 0.5, 0.86),
}
## The pictures (Grok, assets/textury/ui/): an old car on the road, the desk bell; in the
## 12 x 9 pixels left of the bar.
const CAR_TEX := "res://assets/textury/ui/arrive_car.png"
const BELL_TEX := "res://assets/textury/ui/arrive_bell.png"
const ICON_BOX := Vector2(13, 9)

var font: Font
var ui_scale := 2
var _rows: Array = []
## The longest wait seen for each party (its whole journey; its whole patience).
var _trip: Dictionary = {}
var _patience: Dictionary = {}
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var u := float(maxi(1, ui_scale))
	var n := mini(_rows.size(), MAX_ROWS)
	var step := (PLATE.y + GAP) * u
	var x := floorf(size.x - (PLATE.x + 4.0) * u)
	var y0 := floorf(size.y * 0.42 - step * float(n) * 0.5)
	var f: Font = font if font != null else get_theme_default_font()
	var fs := int(8.0 * u)
	for i in n:
		_plate(_rows[i], Vector2(x, y0 + step * float(i)), u, f, fs)
	if _rows.size() > n:
		var more := "+%d" % (_rows.size() - n)
		var at := Vector2(x + (PLATE.x - 1.0) * u - f.get_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, y0 + step * float(n) + 7.0 * u)
		_text(f, more, at, fs, u, Color(BONE, 0.7))


func _plate(row: Dictionary, at: Vector2, u: float, f: Font, fs: int) -> void:
	var id := int(row.get("id", -1))
	var at_desk := bool(row.get("at_gate", false))
	var box := Rect2(at, PLATE * u)
	draw_rect(box, FILL)
	draw_rect(Rect2(box.position, Vector2(box.size.x, u)), LIGHT)
	draw_rect(Rect2(box.position, Vector2(u, box.size.y)), LIGHT)
	draw_rect(Rect2(box.position + Vector2(0, box.size.y - u), Vector2(box.size.x, u)), DARK)
	draw_rect(Rect2(box.position + Vector2(box.size.x - u, 0), Vector2(u, box.size.y)), DARK)
	draw_rect(Rect2(box.position + Vector2(u, u), Vector2(u, box.size.y - 2.0 * u)), KIND.get(str(row.get("archetype", "")), Color(BONE, 0.3)))
	var left := 1.0
	var col := AMBER
	if at_desk:
		left = clampf(float(row.get("patience_left", 0)) / maxf(1.0, float(_patience.get(id, 1.0))), 0.0, 1.0)
		col = GREEN if left > 0.5 else (AMBER if left > 0.25 else RED)
	else:
		var whole := maxf(1.0, float(_trip.get(id, row.get("minutes", 0))))
		left = clampf(1.0 - float(row.get("minutes", 0)) / whole, 0.0, 1.0)
	# The bell rings (a pixel either way, twice a second) while they wait; the car drives.
	var wiggle := 0.0
	if at_desk:
		wiggle = (1.0 if int(_t * 4.0) % 2 == 0 else -1.0) if int(_t * 0.5) % 3 == 0 else 0.0
	else:
		wiggle = 0.0 if int(_t * 3.0) % 2 == 0 else -1.0
	_icon(BELL_TEX if at_desk else CAR_TEX, at + (ICON_AT + Vector2(wiggle if at_desk else 0.0, wiggle if not at_desk else 0.0)) * u, u)
	var bar := Rect2(at + BAR.position * u, BAR.size * u)
	draw_rect(bar.grow(u), SLOT)
	var seg_w := floorf((BAR.size.x + 1.0) / float(SEGMENTS)) - 1.0
	var lit := int(ceil(left * float(SEGMENTS))) if at_desk else int(floor(left * float(SEGMENTS)))
	var blink := at_desk and left <= 0.15 and int(_t * 3.0) % 2 == 1
	for k in SEGMENTS:
		var r := Rect2(bar.position + Vector2(float(k) * (seg_w + 1.0) * u, 0), Vector2(seg_w * u, bar.size.y))
		if k < lit and not blink:
			draw_rect(r, col)
			draw_rect(Rect2(r.position, Vector2(r.size.x, u)), col.lightened(0.35))
		else:
			draw_rect(r, Color(col, 0.16))
	var txt := str(int(row.get("party_size", 1)))
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(f, txt, at + Vector2((PLATE.x - 2.0) * u - tw, 10.0 * u), fs, u, BONE)


var _icons: Dictionary = {}


## The picture at its own pixels (u screen pixels each), in the middle of its box.
func _icon(path: String, at: Vector2, u: float) -> void:
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	var t: Texture2D = _icons[path]
	if t == null:
		return
	var sz := t.get_size()
	var off := ((ICON_BOX - sz) * 0.5).floor()
	draw_texture_rect(t, Rect2(at + off * u, sz * u), false)


func _text(f: Font, s: String, at: Vector2, fs: int, u: float, c: Color) -> void:
	draw_string(f, at + Vector2(u, u), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
	draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
