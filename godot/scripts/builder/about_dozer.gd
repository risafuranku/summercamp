extends Control

## Builder 98's About box has a toy under its credits (DESIGN §5j): a little bulldozer on
## a strip of grass flattening the tents that pop up, in steps; it drives itself until
## an arrow key takes it, then it is yours (a snake that eats tents, never longer).
## The pictures are Builder's own (its toolbar bulldozer, the map's tent).

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const OS_KEYS = preload("res://scripts/os98/os_keys.gd")
const CELL := 14.0
const DOZER := "res://assets/textury/builder/tb2_bulldoze.png"
const TENT := "res://assets/textury/builder/stan1.png"

var _dozer: Texture2D = load(DOZER) if ResourceLoader.exists(DOZER) else null
var _tent: Texture2D = load(TENT) if ResourceLoader.exists(TENT) else null
var _pos := Vector2i(2, 2)
var _dir := Vector2i(1, 0)
var _tents: Array = []
var _flat := 0
var _step := 0.0
var _manual := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 1998
	for i in 3:
		_add_tent()


func _cols() -> int:
	return maxi(4, int(size.x / CELL))


func _rows() -> int:
	return maxi(3, int((size.y - 14.0) / CELL))


func _add_tent() -> void:
	for i in 20:
		var c := Vector2i(_rng.randi_range(0, _cols() - 1), _rng.randi_range(0, _rows() - 1))
		if c != _pos and not _tents.has(c):
			_tents.append(c)
			return


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or not is_visible_in_tree() or not OS_KEYS.here(self):
		return
	var d := {KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0), KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1)}.get(e.keycode, Vector2i.ZERO) as Vector2i
	if d != Vector2i.ZERO:
		_manual = true
		_dir = d
		accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_step += delta
	if _step < 1.0 / 8.0:
		return
	_step = 0.0
	if not _manual and not _tents.is_empty():
		# By itself: toward the nearest tent, the longer way first.
		var t: Vector2i = _tents[0]
		for c in _tents:
			if (c - _pos).length_squared() < (t - _pos).length_squared():
				t = c
		var dv := t - _pos
		_dir = Vector2i(signi(dv.x), 0) if absi(dv.x) >= absi(dv.y) and dv.x != 0 else Vector2i(0, signi(dv.y))
	_pos = Vector2i(posmod(_pos.x + _dir.x, _cols()), posmod(_pos.y + _dir.y, _rows()))
	if _tents.has(_pos):
		_tents.erase(_pos)
		_flat += 1
		_add_tent()
		if _tents.size() < 3:
			_add_tent()
	queue_redraw()


func _draw() -> void:
	var field := Rect2(Vector2.ZERO, Vector2(_cols() * CELL, _rows() * CELL))
	draw_rect(field, Color8(86, 120, 60))
	draw_rect(field, T.SHADOW, false, 1.0)
	for c in _tents:
		var r := Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))
		if _tent != null:
			draw_texture_rect(_tent, r, false)
		else:
			draw_rect(r.grow(-2.0), Color8(230, 190, 40))
	var dr := Rect2(Vector2(_pos) * CELL - Vector2(1, 1), Vector2(CELL + 2, CELL + 2))
	if _dozer != null:
		if _dir.x < 0:
			draw_set_transform(Vector2(dr.end.x, dr.position.y), 0.0, Vector2(-1, 1))
			draw_texture_rect(_dozer, Rect2(Vector2.ZERO, dr.size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(_dozer, dr, false)
	else:
		draw_rect(dr, Color8(230, 160, 0))
	draw_string(T.FONT, Vector2(0, field.end.y + 12), LANG.f("Tents flattened: %d", _flat), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
