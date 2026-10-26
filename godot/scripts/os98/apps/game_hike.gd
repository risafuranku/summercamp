extends Control

## Vylet 98 (shareware, bohemia-online.cz/hry): the camp's hiking group in the woods.
## You lead (the arrow keys); the children follow in a line. Children who wandered off
## stand about waving: walk into one and they join the end of the line. A mushroom is a
## bonus while it lasts. Walk into a tree or into your own group and the hike is over.
## Faster as the group grows. The best five are kept with their names
## (os_shell.scores("hike")).
##
## After dark the count at the top is one more than the line.

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const OS_KEYS = preload("res://scripts/os98/os_keys.gd")
const BOARD = preload("res://scripts/os98/apps/score_board.gd")
const HEAD_H := 40
const CELL := 20
const GW := 22
const GH := 18
const SHIRTS := [Color8(220, 60, 50), Color8(60, 120, 220), Color8(250, 200, 40), Color8(160, 80, 200), Color8(240, 140, 40), Color8(70, 180, 90), Color8(240, 240, 240)]
const NAMES := ["Pepik", "Anicka", "Ondra", "Marketka", "Tonda", "Bara", "Kuba", "Verunka", "Honzik", "Lucka", "Filip", "Terezka"]
const DEATHS_TREE := ["You led them into a pine.", "That was a spruce.", "The tree did not move."]
const DEATHS_SELF := ["You tripped over %s.", "You walked into %s. %s cried.", "%s is not a path."]

var _shell
var _win
var _state := "ready"           # ready, play, over
var _body: Array = []           # [Vector2i], head first
var _shirts: Array = []
var _dir := Vector2i.RIGHT
var _next_dir := Vector2i.RIGHT
var _trees: Dictionary = {}
var _kid := Vector2i(-1, -1)
var _kid_shirt := 0
var _shroom := Vector2i(-1, -1)
var _shroom_t := 0.0
var _step := 0.0
var _score := 0
var _msg := ""
var _msg_t := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _start: Button
var _origin := Vector2.ZERO
var _rank := -1


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_start = Button.new()
	_start.text = "Start the hike"
	_start.add_theme_font_override("font", T.FONT_BOLD)
	_start.focus_mode = Control.FOCUS_NONE
	_start.pressed.connect(_begin)
	add_child(_start)
	resized.connect(_layout)
	_layout()
	_make_woods()


func page_hidden() -> void:
	if _state == "play":
		_state = "ready"
		_start.visible = true
		_start.text = "Carry on"


func _layout() -> void:
	_origin = Vector2(floorf((size.x - GW * CELL) * 0.5), HEAD_H + floorf((size.y - HEAD_H - GH * CELL) * 0.5))
	_start.size = Vector2(150, 26)
	_start.position = Vector2(floorf((size.x - 150) * 0.5), _origin.y + 276)


func _make_woods() -> void:
	_trees.clear()
	for x in GW:
		_trees[Vector2i(x, 0)] = true
		_trees[Vector2i(x, GH - 1)] = true
	for y in GH:
		_trees[Vector2i(0, y)] = true
		_trees[Vector2i(GW - 1, y)] = true
	for i in 16:
		var c := Vector2i(_rng.randi_range(2, GW - 3), _rng.randi_range(2, GH - 3))
		# The path out of the camp stays clear: the hike does not start in a tree.
		if absi(c.y - GH / 2) <= 2 and c.x < 17:
			continue
		_trees[c] = true
	_body = [Vector2i(5, GH / 2), Vector2i(4, GH / 2), Vector2i(3, GH / 2)]
	_shirts = [Color8(40, 110, 60), SHIRTS[0], SHIRTS[1]]
	queue_redraw()


func _begin() -> void:
	_shell.play("click", -10.0)
	if _state != "ready" or _start.text != "Carry on":
		_make_woods()
		_score = 0
		_dir = Vector2i.RIGHT
		_next_dir = Vector2i.RIGHT
		_kid = Vector2i(-1, -1)
		_shroom = Vector2i(-1, -1)
		_place_kid()
	_state = "play"
	_rank = -1
	# A moment to find the arrow keys before they set off.
	_step = -0.9
	_say(tr("Off we go!"))
	_start.visible = false


func _free_cell() -> Vector2i:
	for attempt in 200:
		var c := Vector2i(_rng.randi_range(1, GW - 2), _rng.randi_range(1, GH - 2))
		if not _trees.has(c) and not _body.has(c) and c != _kid and c != _shroom:
			return c
	return Vector2i(-1, -1)


func _place_kid() -> void:
	_kid = _free_cell()
	_kid_shirt = _rng.randi_range(0, SHIRTS.size() - 1)


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or not (e is InputEventKey) or not e.pressed or not OS_KEYS.here(self):
		return
	var d := Vector2i.ZERO
	match e.keycode:
		KEY_UP: d = Vector2i.UP
		KEY_DOWN: d = Vector2i.DOWN
		KEY_LEFT: d = Vector2i.LEFT
		KEY_RIGHT: d = Vector2i.RIGHT
		KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
			if _state != "play" and not e.echo:
				_begin()
				get_viewport().set_input_as_handled()
			return
	if d == Vector2i.ZERO:
		return
	get_viewport().set_input_as_handled()
	if _state != "play":
		return
	# No turning back on yourself.
	if d != -_dir:
		_next_dir = d


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	if _state == "play":
		if _shroom.x >= 0:
			_shroom_t -= delta
			if _shroom_t <= 0.0:
				_shroom = Vector2i(-1, -1)
		elif _rng.randf() < delta * 0.08:
			_shroom = _free_cell()
			_shroom_t = 6.0
		_step += delta
		var every := maxf(0.07, 0.2 - float(_body.size()) * 0.006)
		if _step >= every:
			_step = 0.0
			_move()
	queue_redraw()


func _move() -> void:
	_dir = _next_dir
	var head: Vector2i = _body[0] + _dir
	if _trees.has(head):
		_end(tr(DEATHS_TREE[_rng.randi_range(0, DEATHS_TREE.size() - 1)]))
		return
	var hit := _body.find(head)
	if hit >= 0 and hit < _body.size() - 1:
		var who: String = NAMES[hit % NAMES.size()]
		var line: String = DEATHS_SELF[_rng.randi_range(0, DEATHS_SELF.size() - 1)]
		_end(LANG.f(line, [who, who] if line.count("%s") == 2 else [who]))
		return
	_body.insert(0, head)
	if head == _kid:
		_score += 10
		_shirts.append(SHIRTS[_kid_shirt])
		_say(LANG.f("%s joined the group.", NAMES[(_body.size() - 2) % NAMES.size()]))
		_shell.play("click", -12.0)
		_place_kid()
	else:
		_body.pop_back()
	if head == _shroom:
		_score += 5
		_shroom = Vector2i(-1, -1)
		_say(tr("A cep! +5"))
		_shell.play("click", -14.0)


func _say(s: String) -> void:
	_msg = s
	_msg_t = 2.0


func _end(why: String) -> void:
	_state = "over"
	_shell.play("ding", -8.0)
	var kids := _body.size() - 1
	var counted := kids + (1 if _night() else 0)
	_msg = LANG.f("%s  You brought %d back.", [why, kids])
	if counted != kids:
		_msg = LANG.f("%s  You counted %d. You brought %d back.", [why, counted, kids])
	_msg_t = 999.0
	_rank = _shell.add_score("hike", _score) if _score > 0 else -1
	_start.visible = true
	_start.text = "Another hike"


func _night() -> bool:
	return not _shell.is_day() and _body.size() - 1 >= 5


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var s := size
	var night: bool = not _shell.is_day()
	draw_rect(Rect2(0, HEAD_H, s.x, s.y - HEAD_H), Color8(20, 30, 20) if night else Color8(44, 62, 34))
	var field := Rect2(_origin, Vector2(GW * CELL, GH * CELL))
	draw_rect(field, Color8(46, 66, 36) if night else Color8(96, 128, 64))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 180:
		var p := _origin + Vector2(rng.randf() * field.size.x, rng.randf() * field.size.y)
		draw_rect(Rect2(p.floor(), Vector2(2, 1)), Color8(40, 58, 32) if night else Color8(84, 116, 56))
	for c in _trees:
		_draw_tree(_cell(c), night)
	if _shroom.x >= 0:
		var m := _cell(_shroom)
		draw_rect(Rect2(m + Vector2(8, 10), Vector2(4, 6)), Color8(230, 220, 200))
		draw_circle(m + Vector2(10, 9), 6.0, Color8(120, 70, 30))
		draw_circle(m + Vector2(8, 7), 1.5, Color8(160, 110, 60))
	if _kid.x >= 0 and _state != "ready":
		var wave := int(_t * 4.0) % 2 == 0
		_draw_person(_cell(_kid), SHIRTS[_kid_shirt], false, wave)
	for i in range(_body.size() - 1, -1, -1):
		_draw_person(_cell(_body[i]), _shirts[mini(i, _shirts.size() - 1)], i == 0, false)
	if night:
		# The torch the leader carries: the rest is dark.
		var hp := _cell(_body[0]) + Vector2(10, 10)
		for k in 4:
			draw_arc(hp, 70.0 + k * 40.0, 0, TAU, 32, Color(0, 0, 0, 0.18), 40.0)
	draw_rect(field, Color8(20, 30, 16), false, 2.0)
	if _msg != "" and _msg_t > 0.0:
		var w := T.FONT_BOLD.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var r := Rect2(Vector2(floorf((s.x - w) * 0.5) - 8, _origin.y + 8), Vector2(w + 16, 20))
		draw_rect(r, Color(0, 0, 0, 0.65))
		draw_string(T.FONT_BOLD, r.position + Vector2(8, 14), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(255, 230, 120))
	if _state == "ready" and _start.text != "Carry on":
		var hint := tr("Arrow keys lead the group. Pick up the children who wandered off.")
		var hw := T.FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		draw_rect(Rect2(floorf((s.x - hw) * 0.5) - 8, _origin.y + 240, hw + 16, 22), Color(0, 0, 0, 0.6))
		draw_string(T.FONT, Vector2(floorf((s.x - hw) * 0.5), _origin.y + 255), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	if _state == "over" or (_state == "ready" and _start.text != "Carry on"):
		BOARD.draw(self, Vector2(floorf((s.x - BOARD.SIZE.x) * 0.5), _origin.y + 32), "Best Hikes", _shell.scores("hike"), "pts", _rank)
	_draw_head()


func _cell(c: Vector2i) -> Vector2:
	return _origin + Vector2(c.x * CELL, c.y * CELL)


func _draw_tree(p: Vector2, night: bool) -> void:
	var dark := Color8(14, 34, 18) if night else Color8(30, 70, 34)
	var mid := Color8(22, 48, 26) if night else Color8(44, 96, 46)
	draw_rect(Rect2(p + Vector2(8, 13), Vector2(4, 6)), Color8(70, 46, 26))
	draw_colored_polygon(PackedVector2Array([p + Vector2(10, 0), p + Vector2(19, 14), p + Vector2(1, 14)]), dark)
	draw_colored_polygon(PackedVector2Array([p + Vector2(10, 2), p + Vector2(16, 11), p + Vector2(4, 11)]), mid)


func _draw_person(p: Vector2, shirt: Color, leader: bool, wave: bool) -> void:
	var skin := Color8(232, 184, 140)
	draw_rect(Rect2(p + Vector2(6, 9), Vector2(8, 7)), shirt)
	draw_rect(Rect2(p + Vector2(6, 16), Vector2(3, 3)), Color8(40, 40, 70))
	draw_rect(Rect2(p + Vector2(11, 16), Vector2(3, 3)), Color8(40, 40, 70))
	draw_circle(p + Vector2(10, 6), 4.0, skin)
	if leader:
		# The warden: a cap and a rucksack.
		draw_rect(Rect2(p + Vector2(5, 1), Vector2(10, 3)), Color8(30, 60, 30))
		draw_rect(Rect2(p + Vector2(14, 9), Vector2(3, 6)), Color8(120, 80, 40))
	if wave:
		draw_rect(Rect2(p + Vector2(14, 3), Vector2(2, 7)), skin)


func _draw_head() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, HEAD_H), Color8(40, 60, 30))
	draw_rect(Rect2(0, HEAD_H - 2, w, 2), Color8(200, 170, 80))
	draw_string(T.FONT_BOLD, Vector2(10, 26), "VYLET 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(230, 210, 120))
	var kids := _body.size() - 1
	var shown := kids + (1 if _night() and _state != "ready" else 0)
	var top: Array = _shell.scores("hike")
	var tx := 26.0 + T.FONT_BOLD.get_string_size("VYLET 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2).x
	draw_string(T.FONT, Vector2(tx, 25), LANG.f("GROUP %d     SCORE %d     BEST %s", [shown, _score, str(top[0][1]) if not top.is_empty() else "-"]), HORIZONTAL_ALIGNMENT_LEFT, w - tx - 6, T.FONT_SIZE, Color8(220, 230, 200))
