extends Control

## What wants you in the camp, as plates down the right edge under the arrivals' (the
## user 20. 10.: the camp's troubles were lines of text; make them notifications you see at
## once, each its own picture, like a party on the way). A plate for each: its picture
## (Grok, assets/textury/ui/trouble_<kind>.png: the rubbish bag, the raccoon, the van, the
## boy, the loudspeaker, the branch, the door ajar, the fuse box, the dead lamp, the sewer,
## the toilet, the corn, the frozen pipe, the beer, the sausage, the basket, the cob), its
## word, and the stripe on the left whose it is (the day's amber, the night's red, the
## businesses' green). A day's trouble has its time running out under the word (amber,
## then red, blinking at the end); a business the number waiting (on the picture's corner).
## New ones blink their
## frame a moment. The detail (where, what to do) stays on TAB. Fed by
## hud_manager.set_troubles(), the same rows on every co-op machine (the day's events, the
## night's jobs and the businesses' queues are all the host's).

const MAX_ROWS := 7
## In the HUD's virtual pixels (ui_scale screen pixels each).
const PLATE := Vector2(66, 14)
const GAP := 3
const ICON_AT := Vector2(2, 1)
const ICON_BOX := Vector2(14, 12)
const WORD_AT := Vector2(17, 8)
const BAR := Rect2(17, 10, 44, 2)
const FILL := Color(0.07, 0.06, 0.05, 0.86)
const LIGHT := Color(0.45, 0.36, 0.20, 0.95)
const DARK := Color(0.02, 0.02, 0.02, 0.95)
const SLOT := Color(0.0, 0.0, 0.0, 0.55)
const AMBER := Color(1.0, 0.72, 0.22)
const GREEN := Color(0.46, 0.86, 0.36)
const RED := Color(1.0, 0.42, 0.34)
const BONE := Color(0.93, 0.89, 0.78)
## The housework's stripe (an empty lodging to clean or make up, a block to clean): blue.
const WORK := Color(0.5, 0.72, 0.96)
const CAT := {"day": AMBER, "night": RED, "biz": GREEN, "work": WORK}
const TEX := "res://assets/textury/ui/trouble_%s.png"
const NEW_SEC := 3.0

var font: Font
var ui_scale := 2
## How many arrival plates stand above (the stack goes on under them).
var arrivals := 0
var _rows: Array = []
var _seen: Dictionary = {}    # row id -> when it first showed (s)
var _icons: Dictionary = {}
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_FULL_RECT)


## [{id, kind, word, cat: day|night|biz|work, left: 0..1 or -1, n}]
func set_rows(rows: Array) -> void:
	_rows = rows.duplicate(true)
	var now := {}
	for r in _rows:
		var id := str(r.get("id", ""))
		now[id] = true
		if not _seen.has(id):
			_seen[id] = _t
	for id in _seen.keys():
		if not now.has(id):
			_seen.erase(id)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not _rows.is_empty():
		queue_redraw()


func _draw() -> void:
	if _rows.is_empty():
		return
	# At a business's station its own frame says what waits (the plates sat over its
	# ticket and SERVE).
	for frame in get_tree().get_nodes_in_group("station_frame"):
		if (frame as CanvasLayer).visible:
			return
	var u := float(maxi(1, ui_scale))
	var n := mini(_rows.size(), MAX_ROWS)
	var step := (PLATE.y + GAP) * u
	var x := floorf(size.x - (PLATE.x + 4.0) * u)
	# Under the arrivals' plates (they stand round 42 % of the height), or a little higher.
	var y0 := floorf(size.y * 0.42 + step * float(arrivals) * 0.5 + 6.0 * u) if arrivals > 0 else floorf(size.y * 0.3)
	y0 = minf(y0, size.y - step * float(n) - 70.0 * u)
	var f: Font = font if font != null else get_theme_default_font()
	var fs := int(8.0 * u)
	for i in n:
		_plate(_rows[i], Vector2(x, y0 + step * float(i)), u, f, fs)
	if _rows.size() > n:
		var more := "+%d" % (_rows.size() - n)
		var at := Vector2(x + (PLATE.x - 1.0) * u - f.get_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, y0 + step * float(n) + 7.0 * u)
		_text(f, more, at, fs, u, Color(BONE, 0.7))


func _plate(row: Dictionary, at: Vector2, u: float, f: Font, fs: int) -> void:
	var box := Rect2(at, PLATE * u)
	var fresh := _t - float(_seen.get(str(row.get("id", "")), _t)) < NEW_SEC
	var flash := fresh and int(_t * 4.0) % 2 == 0
	draw_rect(box, FILL)
	var lt := BONE if flash else LIGHT
	draw_rect(Rect2(box.position, Vector2(box.size.x, u)), lt)
	draw_rect(Rect2(box.position, Vector2(u, box.size.y)), lt)
	draw_rect(Rect2(box.position + Vector2(0, box.size.y - u), Vector2(box.size.x, u)), BONE if flash else DARK)
	draw_rect(Rect2(box.position + Vector2(box.size.x - u, 0), Vector2(u, box.size.y)), BONE if flash else DARK)
	var cat_col: Color = CAT.get(str(row.get("cat", "day")), AMBER)
	draw_rect(Rect2(box.position + Vector2(u, u), Vector2(u, box.size.y - 2.0 * u)), cat_col)
	# The picture nods now and then (a pixel), so the eye goes to it.
	var nod := -1.0 if int(_t * 2.0 + float(hash(str(row.get("id", ""))) % 7)) % 6 == 0 else 0.0
	_icon(TEX % str(row.get("kind", "")), at + (ICON_AT + Vector2(0, nod)) * u, u)
	var word := str(row.get("word", "")).to_upper()
	var room := (PLATE.x - WORD_AT.x - 2.0) * u
	while word.length() > 1 and f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		word = word.substr(0, word.length() - 1)
	_text(f, word, at + WORD_AT * u, fs, u, BONE)
	var n := int(row.get("n", 0))
	if n > 0:
		# How many wait: a badge on the picture's lower right corner.
		var num := str(n)
		var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var nb := Rect2(at + Vector2(ICON_AT.x + ICON_BOX.x, ICON_AT.y + ICON_BOX.y) * u - Vector2(nw + 2.0 * u, 7.0 * u), Vector2(nw + 2.0 * u, 7.0 * u))
		draw_rect(nb, DARK)
		_text(f, num, nb.position + Vector2(u, 6.0 * u), fs, u, cat_col)
	var left := float(row.get("left", -1.0))
	if left >= 0.0:
		var col := AMBER if left > 0.3 else RED
		var bar := Rect2(at + BAR.position * u, BAR.size * u)
		draw_rect(bar.grow(u * 0.5), SLOT)
		if not (left <= 0.15 and int(_t * 3.0) % 2 == 1):
			draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * clampf(left, 0.0, 1.0) / u) * u, bar.size.y)), col)


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
