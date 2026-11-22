extends Control

## The guest book open on the counter: the title screen's own menu (main_menu.gd's main
## page, playtest 14. 11.: "the items in the guest book"). The reception's register
## (assets/textury/desk/register.png) drawn at its own pixels with the game's pixel letters
## in ink and scaled up by a whole number, as the counter's close-ups are, in the corner of
## the office at dusk (title_stage.gd). On the left page what you can do, a line each; on
## the right the last entry: the camp CONTINUE goes back to, its photograph glued in, its
## day, till and warden in pencil. The line under the pointer (or chosen with the keys)
## is underlined in red with a red mark before it. Nothing moves while nothing is done.

signal activated(id: String)
signal hovered(id: String)

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const LANG = preload("res://scripts/lang.gd")
const BOOK := "res://assets/textury/desk/register.png"
const SFX_PAGE := "res://assets/sfx/desk/paper_slide.mp3"
const W := 226
const H := 150
const INK := Color(0.14, 0.16, 0.32)
const PENCIL := Color(0.32, 0.3, 0.28)
const RED := Color(0.66, 0.12, 0.1)
const OFF := Color(0.52, 0.5, 0.46)
## The left page: where the lines start, the first baseline, one every PITCH (native px).
const LEFT_X := 22
const ROW0 := 37
const PITCH := 12
const LEFT_W := 84
## The right page.
const RIGHT_X := 124
const RIGHT_W := 86
const FONT_PX := 8

var items: Array[Dictionary] = []
## The last entry: {name, lines: [String], thumb: Texture2D}; {} none.
var entry: Dictionary = {}
var _sel := 0
var _hover := -1
var _k := 2
var _vp: SubViewport
var _canvas: Control
var _view: TextureRect
var _tex: Texture2D
var _audio: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tex = load(BOOK) if ResourceLoader.exists(BOOK) else null
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_canvas = Control.new()
	_canvas.size = Vector2(W, H)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_paint)
	_vp.add_child(_canvas)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_audio)


## In the lower right of a `vp`-sized screen, as big as a whole number lets it be.
func layout(vp: Vector2) -> void:
	_k = clampi(int(vp.y / 330.0), 2, 8)
	size = Vector2(W, H) * float(_k)
	var margin := float(_k) * 6.0
	position = Vector2(vp.x - size.x - margin, vp.y - size.y - margin)
	if _view != null:
		_view.size = size


func set_items(new_items: Array[Dictionary], select_id := "") -> void:
	items = new_items
	_sel = 0
	for i in items.size():
		if str(items[i].get("id", "")) == select_id:
			_sel = i
	if not _enabled(_sel):
		_sel = _next_enabled(_sel, 1)
	_redraw()


func set_entry(d: Dictionary) -> void:
	entry = d
	_redraw()


func select_id(id: String) -> void:
	for i in items.size():
		if str(items[i].get("id", "")) == id and _enabled(i):
			_sel = i
	_redraw()


## Keys and pad on the main page (main_menu._unhandled_input): true when used.
func handle_input(event: InputEvent) -> bool:
	if items.is_empty():
		return false
	if event.is_action_pressed("ui_down"):
		_move(1)
		return true
	if event.is_action_pressed("ui_up"):
		_move(-1)
		return true
	if event.is_action_pressed("ui_accept"):
		_activate(_sel)
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var row := _row_at(_native((event as InputEventMouseMotion).position))
		if row != _hover:
			_hover = row
			if row >= 0:
				_sel = row
				hovered.emit(str(items[row].get("id", "")))
			_redraw()
		HandCursor.want(HandCursor.POINT if row >= 0 else HandCursor.ARROW, self)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var row := _row_at(_native(mb.position))
			if row >= 0:
				_activate(row)
				accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover >= 0:
		_hover = -1
		_redraw()


func _native(p: Vector2) -> Vector2:
	return p / float(_k)


## The left page's line under `p` (native px), -1 none.
func _row_at(p: Vector2) -> int:
	if p.x < LEFT_X - 10 or p.x > LEFT_X + LEFT_W:
		return -1
	for i in items.size():
		var base := float(ROW0 + PITCH * i)
		if p.y >= base - PITCH + 3.0 and p.y < base + 3.0:
			return i if _enabled(i) else -1
	return -1


func _enabled(i: int) -> bool:
	return i >= 0 and i < items.size() and bool(items[i].get("enabled", true))


func _next_enabled(from: int, dir: int) -> int:
	var i := from
	for _n in items.size():
		i = posmod(i + dir, items.size())
		if _enabled(i):
			return i
	return from


func _move(dir: int) -> void:
	_sel = _next_enabled(_sel, dir)
	_hover = -1
	hovered.emit(str(items[_sel].get("id", "")))
	_redraw()


func _activate(i: int) -> void:
	if not _enabled(i):
		return
	_sel = i
	_redraw()
	if ResourceLoader.exists(SFX_PAGE):
		_audio.stream = load(SFX_PAGE)
		_audio.volume_db = -8.0
		_audio.play()
	activated.emit(str(items[i].get("id", "")))


func _redraw() -> void:
	if _canvas == null:
		return
	_canvas.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# ── drawing (native px) ──────────────────────────────────────────────────────

func _paint() -> void:
	var c := _canvas
	if _tex != null:
		c.draw_texture(_tex, Vector2.ZERO)
	_text(c, Vector2(LEFT_X, 16), tr("GUEST BOOK"), RED)
	for i in items.size():
		var base := float(ROW0 + PITCH * i)
		var on := i == _sel
		var col := INK if _enabled(i) else OFF
		var s := tr(str(items[i].get("text", ""))).to_upper()
		_text(c, Vector2(LEFT_X, base), s, col)
		if on and _enabled(i):
			var w := RETRO_UI.FONT_TEXT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
			c.draw_rect(Rect2(LEFT_X - 1, base + 1, w + 2, 1), RED)
			# The red mark before it, a small pencilled arrow.
			for d in 3:
				c.draw_rect(Rect2(LEFT_X - 8 + d, base - 5 + d, 1, 5 - d * 2), RED)
	_paint_entry(c)


func _paint_entry(c: Control) -> void:
	if entry.is_empty():
		_text(c, Vector2(RIGHT_X, 16), "1998", PENCIL)
		return
	_text(c, Vector2(RIGHT_X, 16), str(entry.get("name", "")).to_upper(), INK)
	var thumb: Texture2D = entry.get("thumb")
	var y := 26.0
	if thumb != null:
		# Glued in, a white edge round it, a strip of tape over its top.
		var pr := Rect2(RIGHT_X + 4, y, 70, 40)
		c.draw_rect(pr.grow(2), Color(0.94, 0.92, 0.86))
		c.draw_texture_rect(thumb, pr, false)
		c.draw_rect(Rect2(pr.position.x + pr.size.x * 0.5 - 9, pr.position.y - 4, 18, 6), Color(0.92, 0.88, 0.7, 0.62))
		y = pr.end.y + 12.0
	else:
		y = 37.0
	for line in entry.get("lines", []):
		# (Drawn, not a Label: the dollars to crowns by hand, LANG.money.)
		_text(c, Vector2(RIGHT_X, y), LANG.money(str(line)).to_upper(), PENCIL)
		y += float(PITCH)


func _text(c: Control, pos: Vector2, s: String, col: Color) -> void:
	c.draw_string(RETRO_UI.FONT_TEXT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, col)
