extends Control

## Mines: 9x9, ten mines. The thing every office computer was used for at night.
## Left click opens, right click flags, the face restarts.

const T = preload("res://scripts/os98/os_theme.gd")
const W := 9
const H := 9
const MINES := 10
const CELL := 16
const NUM_COLORS := [Color8(0, 0, 255), Color8(0, 128, 0), Color8(255, 0, 0), Color8(0, 0, 128), Color8(128, 0, 0), Color8(0, 128, 128), Color8(0, 0, 0), Color8(128, 128, 128)]

var _shell
var _mine: Array = []
var _open: Array = []
var _flag: Array = []
var _state := "ready"   # ready, play, won, lost
var _t := 0.0
var _board: Control
var _top: Control
var _boom := -1
var _rng := RandomNumberGenerator.new()


func setup(shell, _win, _args: Dictionary) -> void:
	_shell = shell
	_rng.randomize()
	_top = Control.new()
	_top.position = Vector2(6, 6)
	_top.size = Vector2(W * CELL + 6, 34)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.draw.connect(_draw_top)
	_top.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and Rect2(_top.size.x * 0.5 - 12, 5, 24, 24).has_point(e.position):
			_reset()
	)
	add_child(_top)
	_board = Control.new()
	_board.position = Vector2(6, 46)
	_board.size = Vector2(W * CELL + 6, H * CELL + 6)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_on_board_input)
	add_child(_board)
	_reset()


func _reset() -> void:
	_mine.clear()
	_open.clear()
	_flag.clear()
	for i in W * H:
		_mine.append(false)
		_open.append(false)
		_flag.append(false)
	_state = "ready"
	_t = 0.0
	_boom = -1
	_board.queue_redraw()
	_top.queue_redraw()


func _place(avoid: int) -> void:
	var placed := 0
	while placed < MINES:
		var i := _rng.randi_range(0, W * H - 1)
		if i == avoid or _mine[i]:
			continue
		_mine[i] = true
		placed += 1


func _process(delta: float) -> void:
	if _state == "play":
		_t = minf(999.0, _t + delta)
		_top.queue_redraw()


func _count(i: int) -> int:
	var x := i % W
	var y := i / W
	var n := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx: int = x + dx
			var ny: int = y + dy
			if (dx != 0 or dy != 0) and nx >= 0 and ny >= 0 and nx < W and ny < H and _mine[ny * W + nx]:
				n += 1
	return n


func _reveal(i: int) -> void:
	var stack := [i]
	while not stack.is_empty():
		var k: int = stack.pop_back()
		if _open[k] or _flag[k]:
			continue
		_open[k] = true
		if _count(k) == 0 and not _mine[k]:
			var x := k % W
			var y := k / W
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and ny >= 0 and nx < W and ny < H:
						stack.append(ny * W + nx)


func _on_board_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	if _state == "won" or _state == "lost":
		return
	var cx := int((e.position.x - 3) / CELL)
	var cy := int((e.position.y - 3) / CELL)
	if cx < 0 or cy < 0 or cx >= W or cy >= H:
		return
	var i := cy * W + cx
	if e.button_index == MOUSE_BUTTON_RIGHT:
		if not _open[i]:
			_flag[i] = not _flag[i]
	elif e.button_index == MOUSE_BUTTON_LEFT and not _flag[i]:
		if _state == "ready":
			_place(i)
			_state = "play"
		if _mine[i]:
			_boom = i
			_state = "lost"
			for k in W * H:
				if _mine[k]:
					_open[k] = true
			_shell.play("ding")
		else:
			_reveal(i)
			var closed := 0
			for k in W * H:
				if not _open[k]:
					closed += 1
			if closed == MINES:
				_state = "won"
	_board.queue_redraw()
	_top.queue_redraw()


func _draw_top() -> void:
	_top.draw_style_box(T.box("field", T.FACE, Vector4.ZERO), Rect2(Vector2.ZERO, _top.size))
	var flags := 0
	for f in _flag:
		if f:
			flags += 1
	_digits(Vector2(6, 6), MINES - flags)
	_digits(Vector2(_top.size.x - 45, 6), int(_t))
	var face := Rect2(_top.size.x * 0.5 - 12, 5, 24, 24)
	_top.draw_style_box(T.box("raised", T.FACE, Vector4.ZERO), face)
	var c := face.position + Vector2(12, 12)
	_top.draw_circle(c, 8, Color8(255, 255, 0))
	_top.draw_arc(c, 8, 0, TAU, 20, T.DARK)
	if _state == "lost":
		for s in [-1, 1]:
			_top.draw_line(c + Vector2(s * 3 - 1, -4), c + Vector2(s * 3 + 1, -2), T.DARK)
			_top.draw_line(c + Vector2(s * 3 + 1, -4), c + Vector2(s * 3 - 1, -2), T.DARK)
		_top.draw_arc(c + Vector2(0, 5), 3, PI, TAU, 8, T.DARK)
	else:
		_top.draw_rect(Rect2(c + Vector2(-4, -3), Vector2(2, 2)), T.DARK)
		_top.draw_rect(Rect2(c + Vector2(2, -3), Vector2(2, 2)), T.DARK)
		if _state == "won":
			_top.draw_rect(Rect2(c + Vector2(-6, -4), Vector2(12, 2)), T.DARK)
		_top.draw_arc(c + Vector2(0, 1), 4, 0.3, PI - 0.3, 8, T.DARK)


func _digits(at: Vector2, value: int) -> void:
	_top.draw_rect(Rect2(at, Vector2(39, 23)), Color.BLACK)
	var txt := "%03d" % clampi(value, -99, 999)
	_top.draw_string(T.FONT_BOLD, at + Vector2(4, 18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color8(255, 0, 0))


func _draw_board() -> void:
	_board.draw_style_box(T.box("field", T.FACE, Vector4.ZERO), Rect2(Vector2.ZERO, _board.size))
	for i in W * H:
		var r := Rect2(Vector2(3 + (i % W) * CELL, 3 + (i / W) * CELL), Vector2(CELL, CELL))
		if _open[i]:
			_board.draw_rect(r, Color8(255, 0, 0) if i == _boom else T.FACE)
			_board.draw_rect(Rect2(r.position, Vector2(CELL, 1)), T.SHADOW)
			_board.draw_rect(Rect2(r.position, Vector2(1, CELL)), T.SHADOW)
			if _mine[i]:
				_board.draw_circle(r.get_center(), 4, T.DARK)
				_board.draw_rect(Rect2(r.get_center() - Vector2(2, 2), Vector2(2, 2)), T.WHITE)
			else:
				var n := _count(i)
				if n > 0:
					_board.draw_string(T.FONT_BOLD, r.position + Vector2(4, 13), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, NUM_COLORS[n - 1])
		else:
			_board.draw_style_box(T.box("raised", T.FACE, Vector4.ZERO), r)
			if _flag[i]:
				_board.draw_rect(Rect2(r.position + Vector2(7, 3), Vector2(1, 9)), T.DARK)
				_board.draw_rect(Rect2(r.position + Vector2(4, 3), Vector2(4, 4)), Color8(255, 0, 0))
				_board.draw_rect(Rect2(r.position + Vector2(4, 11), Vector2(7, 2)), T.DARK)
