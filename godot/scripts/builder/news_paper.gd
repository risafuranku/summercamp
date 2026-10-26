extends Control

## One of the Courier's extra editions in Builder 98, or the district's diploma
## (DESIGN §5j), Transport Tycoon's news window in the district's paper: the masthead,
## the date, the headline, a halftone of what it is about, the story; the diploma is
## the district's paper (Grok, no words) with the award typed on it. A click puts it
## away (the next one, if there is one, comes up).

const T = preload("res://scripts/os98/os_theme.gd")
const DIPLOMA := "res://assets/textury/builder/diploma.png"
const INK := Color8(24, 22, 20)
const PAPER := Color8(240, 234, 214)

signal done

var item: Dictionary = {}
var picture: Texture2D = null
var _halftone: Texture2D = null
var _diploma: Texture2D = load(DIPLOMA) if ResourceLoader.exists(DIPLOMA) else null


func setup(p_item: Dictionary, p_picture: Texture2D) -> void:
	item = p_item
	picture = p_picture
	size = Vector2(260, 342) if str(item.get("kind", "")) == "diploma" else Vector2(400, 250)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if picture != null:
		_halftone = _make_halftone(picture)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		accept_event()
		done.emit()


func _day() -> int:
	return CoreRoot.get_day() if CoreRoot != null else 1


func _draw() -> void:
	if str(item.get("kind", "")) == "diploma":
		_draw_diploma()
	else:
		_draw_news()


func _draw_news() -> void:
	var s := size
	draw_rect(Rect2(Vector2(3, 3), s), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2.ZERO, s), PAPER)
	draw_rect(Rect2(Vector2.ZERO, s), INK, false, 1.0)
	_center(T.FONT_BOLD, tr("HLUBOCANY COURIER"), 26, 30)
	draw_rect(Rect2(10, 38, s.x - 20, 1), INK)
	draw_string(T.FONT, Vector2(12, 50), tr(Season.date_long(_day())), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	var ex := tr("EXTRA  -  50 hal")
	draw_string(T.FONT, Vector2(s.x - 12 - T.FONT.get_string_size(ex, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 50), ex, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	draw_rect(Rect2(10, 54, s.x - 20, 2), INK)
	var y := 74.0
	for l in _wrap(tr(str(item.get("title", ""))), T.FONT_BOLD, 16, s.x - 24):
		_center(T.FONT_BOLD, l, 16, y)
		y += 18.0
	y += 4.0
	var pic := Rect2(12, y, 120, 96)
	draw_rect(pic, Color8(210, 204, 186))
	if _halftone != null:
		var tsz := _halftone.get_size()
		var k := minf(pic.size.x / tsz.x, pic.size.y / tsz.y)
		var d := (tsz * k).floor()
		draw_texture_rect(_halftone, Rect2(pic.position + ((pic.size - d) * 0.5).floor(), d), false)
	draw_rect(pic, INK, false, 1.0)
	var ty := y + 10.0
	for l in _wrap(tr(str(item.get("text", ""))), T.FONT, T.FONT_SIZE, s.x - 160):
		draw_string(T.FONT, Vector2(142, ty), l, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, INK)
		ty += 13.0


func _draw_diploma() -> void:
	var s := size
	draw_rect(Rect2(Vector2(3, 3), s), Color(0, 0, 0, 0.35))
	if _diploma != null:
		draw_texture_rect(_diploma, Rect2(Vector2(10, 11), Vector2(240, 320)), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, s), PAPER)
	draw_rect(Rect2(Vector2.ZERO, s), Color8(90, 80, 60), false, 2.0)
	var y := 70.0
	_center(T.FONT_BOLD, tr("DIPLOMA"), 24, y)
	y += 34.0
	for l in _wrap(tr(str(item.get("title", ""))), T.FONT_BOLD, 14, s.x - 60):
		_center(T.FONT_BOLD, l, 14, y)
		y += 17.0
	y += 10.0
	_center(T.FONT, tr("awarded to"), 12, y)
	y += 18.0
	_center(T.FONT_BOLD, _camp_title(), 14, y)
	y += 22.0
	for l in _wrap(tr(str(item.get("text", ""))), T.FONT, 12, s.x - 70):
		_center(T.FONT, l, 12, y)
		y += 14.0
	_center(T.FONT, tr("District Office Pelhrimov"), 10, s.y - 64)
	_center(T.FONT, tr(Season.date_long(int(item.get("day", _day())))), 10, s.y - 52)


## The camp's name as painted on its board by the gate (main.camp_name()).
func _camp_title() -> String:
	var main := get_tree().current_scene if is_inside_tree() else null
	var n := str(main.call("camp_name")) if main != null and main.has_method("camp_name") else ""
	return n if n != "" else "Camp Cerne Jezero"


func _center(f: Font, text: String, fs: int, y: float) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(floorf((size.x - w) * 0.5), y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


func _wrap(s: String, f: Font, fs: int, w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in s.split(" "):
		var test := word if line == "" else line + " " + word
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out


## The picture as the paper printed it: grey, then an ordered dither of ink on paper.
static func _make_halftone(tex: Texture2D) -> Texture2D:
	var img := tex.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var bayer := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.4:
				img.set_pixel(x, y, Color(PAPER, 0.0))
				continue
			var v := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			var thr := (float(bayer[y % 4][x % 4]) + 0.5) / 16.0
			img.set_pixel(x, y, INK if v < thr else PAPER)
	return ImageTexture.create_from_image(img)
