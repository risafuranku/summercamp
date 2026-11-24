extends "res://scripts/pda/apps/pda_app.gd"

## Snake (Richard 24. 11.: "one little game to pass the time"): the old one, on the glass.
## The stylus turns it (a tap ahead-left or ahead-right of its head), the arrow keys too (W A
## S D keep walking you). Faster with every apple; into a wall or itself and it is over: the
## best score stays while the game runs.

const CELL := 4
const STEP_SEC := 0.2
const STEP_MIN := 0.08

var best := 0
var _body: Array = []
var _dir := Vector2i(1, 0)
var _next := Vector2i(1, 0)
var _apple := Vector2i(-1, -1)
var _score := 0
var _t := 0.0
var _state := "ready"   # ready, play, over
var _grid := Vector2i(24, 40)
var _field := Rect2()
var _rng := RandomNumberGenerator.new()


func opened() -> void:
	_rng.randomize()
	if _state == "play":
		_state = "ready"


func closed() -> void:
	if _state == "play":
		_state = "ready"


func wants_tick() -> bool:
	return _state == "play"


func _start() -> void:
	var mid := _grid / 2
	_body = [mid, mid - Vector2i(1, 0), mid - Vector2i(2, 0)]
	_dir = Vector2i(1, 0)
	_next = _dir
	_score = 0
	_t = 0.0
	_state = "play"
	_place_apple()


func _place_apple() -> void:
	for i in 200:
		var c := Vector2i(_rng.randi_range(0, _grid.x - 1), _rng.randi_range(0, _grid.y - 1))
		if not _body.has(c):
			_apple = c
			return


func tick(delta: float) -> void:
	_t += delta
	var step := maxf(STEP_MIN, STEP_SEC - 0.006 * float(_score))
	while _t >= step and _state == "play":
		_t -= step
		_dir = _next
		var head: Vector2i = _body[0] + _dir
		if head.x < 0 or head.y < 0 or head.x >= _grid.x or head.y >= _grid.y or _body.slice(0, _body.size() - 1).has(head):
			_state = "over"
			best = maxi(best, _score)
			os.play("buzz_short")
			return
		_body.push_front(head)
		if head == _apple:
			_score += 1
			os.play("beep")
			_place_apple()
		else:
			_body.pop_back()


func draw(r: Rect2) -> void:
	os.text(r.position.x + 2, r.position.y + 1, os.tr("Score %d") % _score)
	os.text_r(r.end.x - 2, r.position.y + 1, os.tr("Best %d") % maxi(best, _score), os.mid())
	var area := Rect2(r.position.x + 2, r.position.y + 11, r.size.x - 4, r.size.y - 13)
	_grid = Vector2i(int(area.size.x) / CELL, int(area.size.y) / CELL)
	_field = Rect2(area.position + ((area.size - Vector2(_grid * CELL)) * 0.5).floor(), Vector2(_grid * CELL))
	os.frame(_field.grow(1))
	if _state == "ready" or _state == "over":
		var msg: String = os.tr("Game over") if _state == "over" else os.tr("Snake")
		os.text_c(Rect2(_field.position.x, _field.get_center().y - 20, _field.size.x, 10), msg)
		os.button(Rect2(_field.get_center().x - 22, _field.get_center().y - 4, 44, 13), os.tr("Play"), "play")
		return
	if _apple.x >= 0:
		var a := _cell_rect(_apple)
		os.frame(a)
		os.fill(Rect2(a.position + Vector2(1, 1), Vector2(2, 2)))
	for i in _body.size():
		var c := _cell_rect(_body[i])
		# The head whole, the body with a seam between its pieces.
		os.fill(c if i == 0 else Rect2(c.position, c.size - Vector2.ONE))


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_field.position + Vector2(c * CELL), Vector2(CELL, CELL))


func press(id: String) -> void:
	if id == "play":
		_start()


## A tap: the snake turns toward it (only across its way, never back on itself).
func tap(p: Vector2) -> void:
	if _state != "play" or _body.is_empty():
		return
	var head := _cell_rect(_body[0]).get_center()
	var d := p - head
	var want := Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(int(d.y)))
	_turn(want)


func key(event: InputEventKey) -> bool:
	if _state != "play" or not event.pressed:
		return false
	match event.physical_keycode:
		KEY_LEFT:
			_turn(Vector2i(-1, 0))
		KEY_RIGHT:
			_turn(Vector2i(1, 0))
		KEY_UP:
			_turn(Vector2i(0, -1))
		KEY_DOWN:
			_turn(Vector2i(0, 1))
		_:
			return false
	return true


func _turn(want: Vector2i) -> void:
	if want == Vector2i.ZERO or want == -_dir:
		return
	_next = want
