extends Control

## A window on the camp computer: bevelled frame, a title bar with the navy gradient
## (grey when inactive), the app icon and the three caption buttons. Drag by the title
## bar; a click anywhere brings it to the front. The app's UI goes in `content`.

signal close_requested
signal minimize_requested
signal activated

const T = preload("res://scripts/os98/os_theme.gd")
const FRAME := 4
const TITLE_H := 18
const BTN := Vector2(16, 14)

var app_id := ""
var title := "Window":
	set(v):
		title = v
		queue_redraw()
var icon: Texture2D
var active := true:
	set(v):
		active = v
		queue_redraw()
var can_maximize := false
var can_minimize := true
var content: Control

var _dragging := false
var _drag_from := Vector2.ZERO
var _maximized := false
var _restore_rect := Rect2()
var _pressed_btn := ""
var _hover_btn := ""
var _desktop_size := Vector2(640, 452)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = T.get_theme()
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content)
	resized.connect(_layout)


func setup(p_app_id: String, p_title: String, p_icon: Texture2D, rect: Rect2, desktop_size: Vector2) -> void:
	app_id = p_app_id
	title = p_title
	icon = p_icon
	_desktop_size = desktop_size
	position = rect.position.floor()
	size = rect.size.floor()
	_layout()


func client_size() -> Vector2:
	return size - Vector2(FRAME * 2, FRAME * 2 + TITLE_H + 2)


func set_maximized(on: bool) -> void:
	if on == _maximized:
		return
	_maximized = on
	if on:
		_restore_rect = Rect2(position, size)
		position = Vector2.ZERO
		size = _desktop_size
	else:
		position = _restore_rect.position
		size = _restore_rect.size
	_layout()
	queue_redraw()


func _layout() -> void:
	if content == null:
		return
	content.position = Vector2(FRAME, FRAME + TITLE_H + 2)
	content.size = client_size()


func _title_rect() -> Rect2:
	return Rect2(3, 3, size.x - 6, TITLE_H)


func _button_rects() -> Dictionary:
	var r := {}
	var x := size.x - 5 - BTN.x
	var y := 5.0
	r["close"] = Rect2(x, y, BTN.x, BTN.y)
	x -= BTN.x + 2
	if can_maximize:
		r["max"] = Rect2(x, y, BTN.x, BTN.y)
		x -= BTN.x
	if can_minimize:
		r["min"] = Rect2(x, y, BTN.x, BTN.y)
	return r


func _draw() -> void:
	draw_style_box(T.box("window", T.FACE), Rect2(Vector2.ZERO, size))
	var tr := _title_rect()
	var a := T.TITLE_A if active else T.TITLE_IDLE_A
	var b := T.TITLE_B if active else T.TITLE_IDLE_B
	# Gradient in 8-pixel bands, the way 16-bit colour drew it.
	var bands := int(ceil(tr.size.x / 8.0))
	for i in bands:
		var t := float(i) / float(maxi(1, bands - 1))
		draw_rect(Rect2(tr.position.x + i * 8, tr.position.y, minf(8.0, tr.size.x - i * 8), tr.size.y), a.lerp(b, t))
	var text_x := tr.position.x + 3
	if icon != null:
		draw_texture_rect(icon, Rect2(tr.position.x + 2, tr.position.y + 1, 16, 16), false)
		text_x += 18
	var fg := T.WHITE if active else Color8(212, 208, 200)
	draw_string(T.FONT_BOLD, Vector2(text_x, tr.position.y + 13), title, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x - 70, T.FONT_SIZE, fg)
	for id in _button_rects():
		_draw_caption_button(id, _button_rects()[id])


func _draw_caption_button(id: String, r: Rect2) -> void:
	var pressed := _pressed_btn == id and _hover_btn == id
	draw_style_box(T.box("pressed" if pressed else "raised", T.FACE, Vector4.ZERO), r)
	var o := Vector2(1, 1) if pressed else Vector2.ZERO
	var c := r.position + o
	match id:
		"close":
			for i in 6:
				for w in 2:
					draw_rect(Rect2(c + Vector2(4 + i + w, 3 + i), Vector2(1, 1)), T.DARK)
					draw_rect(Rect2(c + Vector2(10 - i + w, 3 + i), Vector2(1, 1)), T.DARK)
		"min":
			draw_rect(Rect2(c + Vector2(4, 9), Vector2(6, 2)), T.DARK)
		"max":
			draw_rect(Rect2(c + Vector2(3, 2), Vector2(9, 9)), T.DARK, false)
			draw_rect(Rect2(c + Vector2(3, 2), Vector2(9, 2)), T.DARK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if event.pressed:
			activated.emit()
			for id in _button_rects():
				if _button_rects()[id].has_point(p):
					_pressed_btn = id
					_hover_btn = id
					queue_redraw()
					accept_event()
					return
			if _title_rect().has_point(p):
				if event.double_click and can_maximize:
					set_maximized(not _maximized)
				elif not _maximized:
					_dragging = true
					_drag_from = p
			accept_event()
		else:
			if not _pressed_btn.is_empty():
				var id := _pressed_btn
				_pressed_btn = ""
				queue_redraw()
				if _button_rects().has(id) and _button_rects()[id].has_point(p):
					match id:
						"close":
							close_requested.emit()
						"min":
							minimize_requested.emit()
						"max":
							set_maximized(not _maximized)
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			var np: Vector2 = position + event.position - _drag_from
			np.x = clampf(np.x, -size.x + 40, _desktop_size.x - 40)
			np.y = clampf(np.y, 0, _desktop_size.y - TITLE_H)
			position = np.floor()
			accept_event()
		elif not _pressed_btn.is_empty():
			var over := ""
			for id in _button_rects():
				if _button_rects()[id].has_point(event.position):
					over = id
			if over != _hover_btn:
				_hover_btn = over
				queue_redraw()
