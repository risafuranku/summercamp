extends Control

## Pexeso 98 (shareware, bohemia-online.cz/hry): the memory game every Czech child knew,
## twelve pairs of pictures from the Builder 98 catalogue face down. Turn two; a pair
## stays up (and the catalogue's line about it comes up), two that differ go back.
## Fewest turns wins; the best five are kept with their names (os_shell.scores("pexeso")).

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const BOARD = preload("res://scripts/os98/apps/score_board.gd")
const BUILDER = preload("res://scripts/builder_module.gd")
const HEAD_H := 40
const COLS := 6
const ROWS := 4
const CARD := Vector2(64, 78)
const GAP := 6
const PICS := ["tent_1", "cabin_1", "caravan_1", "toilet_block", "shower_block", "pub", "restaurant", "bonfire", "lake_slide", "gnome", "flagpole", "hammock", "ping_pong", "playground", "picnic_table", "bench"]

var _shell
var _win
var _cards: Array = []          # {pic, up, done}
var _tex: Dictionary = {}
var _first := -1
var _second := -1
var _wait := 0.0
var _turns := 0
var _pairs := 0
var _line := ""
var _origin := Vector2.ZERO
var _hover := -1
var _rng := RandomNumberGenerator.new()
var _rank := -1


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The pictures now, not in the draw (a texture first loaded in a draw comes out white).
	for id in PICS:
		var path := str(BUILDER.ITEM_ICONS.get(id, ""))
		if path != "" and ResourceLoader.exists(path):
			_tex[id] = load(path)
	resized.connect(_layout)
	_layout()
	_deal()


func _layout() -> void:
	var w := COLS * CARD.x + (COLS - 1) * GAP
	var h := ROWS * CARD.y + (ROWS - 1) * GAP
	_origin = Vector2(floorf((size.x - w) * 0.5), HEAD_H + floorf((size.y - HEAD_H - h - 28) * 0.5))


func _deal() -> void:
	var pool: Array = []
	for id in PICS:
		if _tex.has(id):
			pool.append(id)
	pool.shuffle()
	pool = pool.slice(0, COLS * ROWS / 2)
	var deck: Array = []
	for id in pool:
		deck.append(id)
		deck.append(id)
	# Shuffle with our own dice.
	for i in range(deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	_cards.clear()
	for id in deck:
		_cards.append({"pic": id, "up": false, "done": false})
	_first = -1
	_second = -1
	_turns = 0
	_pairs = 0
	_rank = -1
	_line = tr("Turn two cards. Find the pairs.")
	queue_redraw()


func _rect(i: int) -> Rect2:
	return Rect2(_origin + Vector2((i % COLS) * (CARD.x + GAP), (i / COLS) * (CARD.y + GAP)), CARD)


func _at(p: Vector2) -> int:
	for i in _cards.size():
		if _rect(i).has_point(p):
			return i
	return -1


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := _at(e.position)
		if h != _hover:
			_hover = h
			queue_redraw()
		return
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _pairs * 2 >= _cards.size():
		_deal()
		return
	var i := _at(e.position)
	if i < 0 or bool(_cards[i]["up"]) or bool(_cards[i]["done"]):
		return
	if _second >= 0:
		# Two already up and not a pair: the click turns them back now.
		_turn_back()
	_cards[i]["up"] = true
	_shell.play("click", -14.0)
	if _first < 0:
		_first = i
	else:
		_second = i
		_turns += 1
		if str(_cards[_first]["pic"]) == str(_cards[_second]["pic"]):
			_cards[_first]["done"] = true
			_cards[_second]["done"] = true
			_pairs += 1
			var id := str(_cards[i]["pic"])
			_line = "%s!  %s" % [tr(str(BUILDER.SHORT_NAMES.get(id, id))), tr(str(BUILDER.BLURBS.get(id, "")))]
			_first = -1
			_second = -1
			if _pairs * 2 >= _cards.size():
				_won()
		else:
			_wait = 0.9
	queue_redraw()


func _turn_back() -> void:
	for k in [_first, _second]:
		if k >= 0:
			_cards[k]["up"] = false
	_first = -1
	_second = -1
	_wait = 0.0


func _won() -> void:
	_rank = _shell.add_score("pexeso", _turns)
	_line = LANG.f("All %d pairs in %d turns.%s  Click for a new game.", [_pairs, _turns, tr("  On the Best Games table!") if _rank >= 0 else ""])
	_shell.play("ding", -8.0)


func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_turn_back()
			queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(0, HEAD_H, s.x, s.y - HEAD_H), Color8(0, 96, 64))
	for i in _cards.size():
		var r := _rect(i)
		var c: Dictionary = _cards[i]
		if bool(c["up"]) or bool(c["done"]):
			draw_style_box(T.box("raised", Color8(255, 252, 236), Vector4.ZERO), r)
			var tex: Texture2D = _tex.get(str(c["pic"]))
			if tex != null:
				var ts := tex.get_size()
				var k := minf((CARD.x - 10) / ts.x, (CARD.y - 22) / ts.y)
				var d := (ts * k).floor()
				draw_texture_rect(tex, Rect2(r.position + Vector2(floorf((CARD.x - d.x) * 0.5), 5 + floorf((CARD.y - 22 - d.y) * 0.5)), d), false)
			draw_string(T.FONT, r.position + Vector2(0, CARD.y - 6), tr(str(BUILDER.TINY_NAMES.get(str(c["pic"]), BUILDER.SHORT_NAMES.get(str(c["pic"]), "")))), HORIZONTAL_ALIGNMENT_CENTER, CARD.x, T.FONT_SIZE, T.TEXT)
			if bool(c["done"]):
				draw_rect(r.grow(-2), Color8(0, 140, 0), false, 2.0)
		else:
			# The back: the camp's own pattern, navy and a pine.
			draw_style_box(T.box("raised", Color8(40, 60, 150) if i == _hover else Color8(24, 40, 120), Vector4.ZERO), r)
			var inner := r.grow(-6)
			draw_rect(inner, Color8(200, 200, 230), false, 1.0)
			var m := inner.get_center()
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -16), m + Vector2(11, 8), m + Vector2(-11, 8)]), Color8(60, 150, 80))
			draw_rect(Rect2(m + Vector2(-2, 8), Vector2(4, 6)), Color8(120, 80, 40))
	if _pairs * 2 >= _cards.size() and not _cards.is_empty():
		BOARD.draw(self, ((s - BOARD.SIZE) * 0.5).floor(), "Best Games", _shell.scores("pexeso"), "turns", _rank)
	var lr := Rect2(8, s.y - 26, s.x - 16, 20)
	draw_style_box(T.box("well", T.FACE, Vector4.ZERO), lr)
	draw_string(T.FONT, lr.position + Vector2(6, 14), _line, HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 12, T.FONT_SIZE, T.TEXT)
	var w := s.x
	draw_rect(Rect2(0, 0, w, HEAD_H), Color8(0, 60, 40))
	draw_rect(Rect2(0, HEAD_H - 2, w, 2), Color8(250, 220, 90))
	draw_string(T.FONT_BOLD, Vector2(10, 26), "PEXESO 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(250, 220, 90))
	var top: Array = _shell.scores("pexeso")
	var tx := 26.0 + T.FONT_BOLD.get_string_size("PEXESO 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2).x
	draw_string(T.FONT, Vector2(tx, 25), LANG.f("PAIRS %d / %d     TURNS %d     BEST %s", [_pairs, _cards.size() / 2, _turns, str(top[0][1]) if not top.is_empty() else "-"]), HORIZONTAL_ALIGNMENT_LEFT, w - tx - 6, T.FONT_SIZE, Color8(210, 240, 220))
