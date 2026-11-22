extends CanvasLayer

## The title's pages as the counter's own things close up (main_menu.gd's sub-pages,
## playtest 14. 11.: "the reception at dusk", the camps as keys with Dymo labels on the key
## board, a new camp a booking form, the warden their ID card). The counter's top
## (assets/textury/desk/desk_top.png, 480 x 270) drawn at its own pixels with the game's
## pixel letters and scaled up by a whole number, the office dimmed round it, as the
## check-in's close-up is. What lies on it is the page's (a page object: paint, hotspots,
## click, key). Esc, the right button or a click on the office round it goes back.

signal back

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const LANG = preload("res://scripts/lang.gd")
const CAMP_TEXT = preload("res://scripts/ui/title/camp_text.gd")
const WARDEN_LOOKS = preload("res://scripts/coop/warden_looks.gd")
## The ID card (108 x 70): its grey photograph ground (10, 16, 35, 38) behind a warden's
## photograph (face()).
const ID_CARD := "res://assets/textury/desk/id_card.png"
const PHOTO_GROUND := Rect2(11, 17, 33, 36)
const TOP := "res://assets/textury/desk/desk_top.png"
## The striped tractor-feed paper (88 x 118): holed margins 7 px each side, the stripes
## every 6 rows (a sheet of any size is cut from it: paper()).
const SHEET := "res://assets/textury/desk/booking.png"
const W := 480
const H := 270
const INK := Color(0.14, 0.16, 0.32)
const PENCIL := Color(0.32, 0.3, 0.28)
const RED := Color(0.66, 0.12, 0.1)
const PAPER := Color(0.93, 0.9, 0.82)
const FONT_PX := 8

## The page on it now: an object with paint(desk, c), hotspots() -> [{id, rect}],
## click(id), key(event) -> bool, opened(), and if it likes closed().
var page
var _vp: SubViewport
var _canvas: Control
var _view: TextureRect
var _shade: ColorRect
var _top: Texture2D
var _k := 2
var _mouse := Vector2(-1, -1)
var _hover := ""
var _audio: AudioStreamPlayer
var _tex: Dictionary = {}


func _init() -> void:
	layer = 121
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_top = load(TOP) if ResourceLoader.exists(TOP) else null
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.0, 0.62)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(_on_shade_input)
	add_child(_shade)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.transparent_bg = false
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
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	add_child(_view)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_audio)
	get_viewport().size_changed.connect(_layout)
	_layout()


func open_page(p) -> void:
	_closed()
	clear_fields()
	page = p
	visible = true
	_hover = ""
	_layout()
	if page != null and page.has_method("opened"):
		page.opened()
	redraw()


func close() -> void:
	_closed()
	visible = false
	page = null
	clear_fields()


func _closed() -> void:
	if page != null and page.has_method("closed"):
		page.closed()


func redraw() -> void:
	if _canvas == null:
		return
	_canvas.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func play(path: String, db := -8.0) -> void:
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.volume_db = db
		_audio.play()


func hovered() -> String:
	return _hover


func mouse() -> Vector2:
	return _mouse


## A picture by path (cached), null when it is not there.
func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


func _layout() -> void:
	if _view == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_k = maxi(1, mini(int(vp.x / float(W)), int(vp.y / float(H))))
	_view.size = Vector2(W, H) * float(_k)
	_view.position = ((vp - _view.size) * 0.5).floor()
	for f in _fields:
		_place_field(f)


## Fields typed into (a LineEdit over the picture): put over `rect` (native px), in the ink
## and letters the page is written in, as big as the picture is.
var _fields: Array = []


func field(rect: Rect2, placeholder := "") -> LineEdit:
	var e := LineEdit.new()
	e.set_meta("rect", rect)
	e.placeholder_text = placeholder
	var flat := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(s, flat)
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(PENCIL, 0.6))
	e.add_theme_color_override("caret_color", RED)
	e.add_theme_color_override("selection_color", Color(RED, 0.25))
	e.add_theme_font_override("font", RETRO_UI.FONT_TEXT)
	e.context_menu_enabled = false
	add_child(e)
	_fields.append(e)
	_place_field(e)
	return e


func clear_fields() -> void:
	for f in _fields:
		if is_instance_valid(f):
			f.queue_free()
	_fields.clear()


func _place_field(e: LineEdit) -> void:
	var r: Rect2 = e.get_meta("rect")
	e.position = _view.position + r.position * float(_k)
	e.size = r.size * float(_k)
	e.add_theme_font_size_override("font_size", FONT_PX * _k)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = ((event as InputEventMouseMotion).position / float(_k)).floor()
		var h := _hit(_mouse)
		if h != _hover:
			_hover = h
			redraw()
		HandCursor.want(HandCursor.POINT if h != "" else HandCursor.ARROW, self)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			back.emit()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var h := _hit((mb.position / float(_k)).floor())
			if h != "" and page != null:
				page.click(h)
				redraw()


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		back.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		back.emit()
		get_viewport().set_input_as_handled()
		return
	if page != null and page.has_method("key") and page.key(event):
		redraw()
		get_viewport().set_input_as_handled()


func _hit(p: Vector2) -> String:
	if page == null:
		return ""
	for h in page.hotspots():
		if (h["rect"] as Rect2).has_point(p):
			return str(h["id"])
	return ""


func _paint() -> void:
	if _top != null:
		_canvas.draw_texture(_top, Vector2.ZERO)
	if page != null:
		page.paint(self, _canvas)


# ── what pages draw with (native px) ─────────────────────────────────────────

func text(c: Control, pos: Vector2, s: String, col := INK, size := FONT_PX, font: Font = null) -> void:
	c.draw_string(font if font != null else RETRO_UI.FONT_TEXT, pos, LANG.money(s), HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func text_w(s: String, size := FONT_PX, font: Font = null) -> float:
	return (font if font != null else RETRO_UI.FONT_TEXT).get_string_size(LANG.money(s), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## An ink line you can click: underlined in red with a mark before it while hovered.
func link(c: Control, pos: Vector2, s: String, id: String, col := INK) -> Rect2:
	var w := text_w(s)
	text(c, pos, s, col)
	var r := Rect2(pos + Vector2(-2, -8), Vector2(w + 4, 11))
	if _hover == id:
		mark(c, pos, w)
	return r


## The red pencil's mark on the line written at `pos` (`w` long): under it and before it.
func mark(c: Control, pos: Vector2, w: float) -> void:
	c.draw_rect(Rect2(pos.x - 1, pos.y + 1, w + 2, 1), RED)
	for d in 3:
		c.draw_rect(Rect2(pos.x - 7 + d, pos.y - 5 + d, 1, 5 - d * 2), RED)


## Computer paper of any size cut from the tractor-feed sheet (SHEET): its holed margins
## down both sides, its stripes going on, a shadow under it. `r` in native px.
func paper(c: Control, r: Rect2) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	c.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
	var t := tex(SHEET)
	if t == null:
		c.draw_rect(r, PAPER)
		return
	var y := 0.0
	while y < r.size.y:
		# The first band from the sheet's top (its torn edge), the rest from row 6 on: 108
		# rows, a whole number of stripes, so they run on.
		var sy := 0.0 if y == 0.0 else 6.0
		var sh := minf(114.0 - sy, r.size.y - y)
		var at := r.position + Vector2(0, y)
		c.draw_texture_rect_region(t, Rect2(at, Vector2(7, sh)), Rect2(0, sy, 7, sh))
		c.draw_texture_rect_region(t, Rect2(at + Vector2(r.size.x - 7, 0), Vector2(7, sh)), Rect2(81, sy, 7, sh))
		var x := 7.0
		while x < r.size.x - 7.0:
			var tw := minf(74.0, r.size.x - 7.0 - x)
			c.draw_texture_rect_region(t, Rect2(at + Vector2(x, 0), Vector2(tw, sh)), Rect2(7, sy, tw, sh))
			x += tw
		y += sh


## A camp's card as the key board lays it beside the board (the booking card: the camp's
## photograph glued on, its name in ink, its mode and day, till and guests in pencil).
func camp_card(c: Control, at: Vector2, camp: Dictionary) -> void:
	var card := tex(SHEET)
	var cr := Rect2(at, card.get_size() if card != null else Vector2(88, 118))
	c.draw_rect(Rect2(cr.position + Vector2(2, 3), cr.size), Color(0, 0, 0, 0.35))
	if card != null:
		c.draw_texture(card, cr.position)
	else:
		c.draw_rect(cr, PAPER)
	if camp.is_empty():
		return
	photo(c, Rect2(cr.position + Vector2(8, 10), Vector2(72, 40)), CAMP_TEXT.thumb(str(camp.get("thumb", ""))))
	var x := cr.position.x + 12
	text(c, Vector2(x, cr.position.y + 66), str(camp.get("name", "Camp")).to_upper(), INK)
	text(c, Vector2(x, cr.position.y + 78), (tr("SANDBOX") if bool(camp.get("sandbox", false)) else tr("STORY")) + "  " + tr("DAY %d") % int(camp.get("day", 1)), PENCIL)
	text(c, Vector2(x, cr.position.y + 89), "$" + CAMP_TEXT.money(int(camp.get("money", 0))), PENCIL)
	text(c, Vector2(x, cr.position.y + 100), tr("%d GUESTS") % int(camp.get("guests", 0)), PENCIL)


## A warden's photograph as on an ID: their figure (warden_looks.gd, in their jacket),
## head and shoulders (35 x 38 of it) at `k` times its pixels; with `edge`, glued on in a
## white edge on the ID card's grey ground (without: into a frame already there).
const FACE := Vector2i(35, 38)


func face(c: Control, at: Vector2, model: int, color: int, k := 1, edge := true) -> Rect2:
	var r := Rect2(at.floor(), Vector2(FACE) * float(k))
	if edge:
		c.draw_rect(Rect2(r.position + Vector2(2, 2), r.size + Vector2(4, 4)), Color(0, 0, 0, 0.35))
		c.draw_rect(r.grow(2), Color(0.94, 0.92, 0.86))
		var ground := tex(ID_CARD)
		if ground != null:
			c.draw_texture_rect_region(ground, r, PHOTO_GROUND)
	var t := WARDEN_LOOKS.texture(model, color, "stand")
	if t != null:
		c.draw_texture_rect_region(t, r, Rect2(t.get_width() / 2 - FACE.x / 2, 0, FACE.x, FACE.y))
	return r


## `s` broken into lines no wider than `width` (whole words).
func wrap(s: String, width: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in s.split(" ", false):
		var next := word if line == "" else line + " " + word
		if line != "" and text_w(next) > width:
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


## A strip of tape you can click (dymo): its id hovered, a pale line under it.
func tape(c: Control, center: Vector2, s: String, id: String, col := Color8(24, 24, 26)) -> Rect2:
	var r := dymo(c, center, s, col)
	if _hover == id:
		c.draw_rect(Rect2(r.position.x, r.end.y + 1, r.size.x, 1), Color(0.95, 0.85, 0.5))
	return r


## Where a tape of `s` centred on `center` lies (for hotspots, before it is drawn).
func tape_rect(center: Vector2, s: String) -> Rect2:
	var w := maxf(14.0, text_w(s.to_upper()) + 6.0)
	return Rect2((center - Vector2(w * 0.5, 4)).floor() + Vector2(-2, -2), Vector2(w + 4, 13))


## A photograph glued in: a white edge, a strip of tape over its top.
func photo(c: Control, r: Rect2, t: Texture2D) -> void:
	c.draw_rect(Rect2(r.position + Vector2(2, 2), r.size + Vector2(4, 4)), Color(0, 0, 0, 0.35))
	c.draw_rect(r.grow(2), Color(0.94, 0.92, 0.86))
	if t != null:
		c.draw_texture_rect(t, r, false)
	else:
		c.draw_rect(r, Color(0.2, 0.2, 0.2))
	c.draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 9, r.position.y - 4, 18, 6), Color(0.92, 0.88, 0.7, 0.62))


## A strip of Dymo tape with `s` punched into it, white on `col`.
func dymo(c: Control, center: Vector2, s: String, col := Color8(24, 24, 26)) -> Rect2:
	var t := s.to_upper()
	var w := maxf(14.0, text_w(t) + 6.0)
	var r := Rect2((center - Vector2(w * 0.5, 4)).floor(), Vector2(w, 9))
	c.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.4))
	c.draw_rect(r, col)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), col.lightened(0.25))
	text(c, r.position + Vector2(3, 7), t, Color(0.92, 0.92, 0.9))
	return r
