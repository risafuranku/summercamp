extends CanvasLayer

## The board by the gate up close, its name being painted anew (playtest 25. 10.: "change
## the camp's name with E on the sign before the camp"; camp_gate.gd's board, main.gd
## open_camp_sign()). The grey planks on their two posts fill the middle of the screen,
## the name in the board's black paint, a wet brush mark blinking where the next letter
## goes; type it, Enter paints it (the brush's sound), Esc leaves the board as it was.
## Nothing else on the screen.

signal painted(name: String)
signal closed

const PLANKS := "res://assets/textury/camp/planks_grey.png"
const POSTS := "res://assets/textury/camp/planks_dark.png"
const FONT := "res://assets/fonts/jersey10.fnt"
const BRUSH := "res://assets/sfx/director/wall_brush.mp3"
const PAINT := Color(0.1, 0.08, 0.06)
const MAX_LEN := 24
## The board's shape (1.7 x 0.6 m) and how much of the screen's width it takes.
const ASPECT := 1.7 / 0.6
const WIDTH_SHARE := 0.62
## The planks' pixels this many screen pixels each (per 1080 of height).
const TEX_SCALE := 4.0

var text := ""
var _board: Control
var _t := 0.0
var _opened_at := 0.0


func _ready() -> void:
	layer = 70
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_board.draw.connect(_draw_board)
	add_child(_board)
	_opened_at = Time.get_ticks_msec() / 1000.0


func open(current: String) -> void:
	text = current.strip_edges().left(MAX_LEN)
	_board.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	# The brush mark blinks in steps.
	if int(_t * 2.5) != int((_t - delta) * 2.5):
		_board.queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			_close(false)
		return
	get_viewport().set_input_as_handled()
	var k := event as InputEventKey
	if not k.pressed:
		return
	# The E that opened the board, still held.
	if k.echo and Time.get_ticks_msec() / 1000.0 - _opened_at < 0.4:
		return
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_close(text.strip_edges() != "")
			return
		KEY_ESCAPE:
			_close(false)
			return
		KEY_BACKSPACE:
			if not text.is_empty():
				text = text.left(text.length() - 1)
				_board.queue_redraw()
			return
	if k.unicode >= 32 and text.length() < MAX_LEN:
		text += String.chr(k.unicode)
		_board.queue_redraw()


func _close(paint: bool) -> void:
	if paint:
		_sound(BRUSH)
		painted.emit(text.strip_edges())
	closed.emit()
	queue_free()


func _sound(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = -6.0
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	# Plays on after the board is gone.
	get_tree().root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _draw_board() -> void:
	var vs := _board.size
	var u := maxf(1.0, roundf(vs.y / 1080.0 * TEX_SCALE))
	var bw := floorf(vs.x * WIDTH_SHARE / u) * u
	var bh := floorf(bw / ASPECT / u) * u
	var at := ((vs - Vector2(bw, bh)) * 0.5 - Vector2(0, vs.y * 0.06)).floor()
	# The posts down from under it, to the bottom of the screen.
	var posts: Texture2D = load(POSTS) if ResourceLoader.exists(POSTS) else null
	var pw := floorf(bw * 0.053 / u) * u
	for side in [-1.0, 1.0]:
		var px: float = at.x + bw * 0.5 + float(side) * bw * 0.41 - pw * 0.5
		var r := Rect2(Vector2(floorf(px), at.y + bh * 0.5), Vector2(pw, vs.y - at.y - bh * 0.5))
		_tiled(posts, r, u, Color(0.3, 0.24, 0.18))
	var planks: Texture2D = load(PLANKS) if ResourceLoader.exists(PLANKS) else null
	var board := Rect2(at, Vector2(bw, bh))
	_tiled(planks, board, u, Color(0.55, 0.52, 0.46))
	# A dark edge under and on the right: the board's thickness.
	_board.draw_rect(Rect2(board.position + Vector2(0, bh), Vector2(bw, u * 2.0)), Color(0.08, 0.07, 0.06))
	_board.draw_rect(Rect2(board.position + Vector2(bw, u * 2.0), Vector2(u * 2.0, bh)), Color(0.08, 0.07, 0.06))
	var font: Font = load(FONT) if ResourceLoader.exists(FONT) else _board.get_theme_default_font()
	var name_line := text.to_upper()
	var sub := tr("RECEPTION - STOP")
	# The same proportions as on the board out there (camp_gate.set_camp_name): the name
	# at most as big as the line under it, smaller when long.
	var fs := int(bh * 0.30)
	var room := bw * 0.88
	var nw := font.get_string_size(name_line + "_", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if nw > room:
		fs = maxi(8, int(float(fs) * room / nw))
	var sub_fs := int(bh * 0.30)
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs).x
	if sw > room:
		sub_fs = int(float(sub_fs) * room / sw)
	var name_w := font.get_string_size(name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := at.y + bh * 0.44
	var nx := floorf(at.x + (bw - name_w) * 0.5)
	_board.draw_string(font, Vector2(nx, base), name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PAINT)
	# The wet brush where the next letter goes.
	if int(_t * 2.5) % 2 == 0 and text.length() < MAX_LEN:
		var cw := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_board.draw_rect(Rect2(Vector2(nx + name_w + u, base - u * 2.0), Vector2(cw * 0.8, u * 2.0)), Color(PAINT, 0.85))
	sw = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs).x
	_board.draw_string(font, Vector2(floorf(at.x + (bw - sw) * 0.5), at.y + bh * 0.82), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs, PAINT)


## A texture over a rect at `u` screen pixels a texel, or its colour without it.
func _tiled(tex: Texture2D, r: Rect2, u: float, fallback: Color) -> void:
	if tex == null:
		_board.draw_rect(r, fallback)
		return
	_board.draw_set_transform(r.position, 0.0, Vector2(u, u))
	_board.draw_texture_rect(tex, Rect2(Vector2.ZERO, r.size / u), true)
	_board.draw_set_transform(Vector2.ZERO)
