extends Control

## Komar 98 (shareware, bohemia-online.cz/hry): a camper asleep in his tent, lit by the
## torch he left on, and the mosquitoes that come in for him from the dark. Click one to
## swat it. One that reaches his face settles, and bites unless you get it first; five
## bites and he is awake. Slap him by mistake (a click on his face with nothing there)
## three times and he is awake too. They come faster as you go. The best five are kept
## with their names (os_shell.scores("mosquito")).

const T = preload("res://scripts/os98/os_theme.gd")
const BOARD = preload("res://scripts/os98/apps/score_board.gd")
const HEAD_H := 40
const BITES := 5
const SLAPS := 3
const SKIN := Color8(232, 184, 140)
const HIT_R := 12.0

var _shell
var _win
var _state := "ready"           # ready, play, over
var _bugs: Array = []           # {p, v, phase, land: float (<0 flying), spot}
var _bumps: Array = []          # face-relative points
var _splats: Array = []         # {p, t}
var _slap := {}                 # {p, t}
var _score := 0
var _bites := 0
var _slaps := 0
var _t := 0.0
var _spawn := 1.0
var _twitch := 0.0
var _mumble := ""
var _rng := RandomNumberGenerator.new()
var _start: Button
var _rank := -1


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_start = Button.new()
	_start.text = "Start"
	_start.add_theme_font_override("font", T.FONT_BOLD)
	_start.focus_mode = Control.FOCUS_NONE
	_start.pressed.connect(_begin)
	add_child(_start)
	resized.connect(func():
		_start.size = Vector2(120, 26)
		_start.position = Vector2(floorf((size.x - 120) * 0.5), size.y - 60))
	_start.size = Vector2(120, 26)
	_start.position = Vector2(floorf((size.x - 120) * 0.5), size.y - 60)


func page_hidden() -> void:
	if _state == "play":
		_over("You looked away. He woke up anyway.")


func _face() -> Vector2:
	return Vector2(size.x * 0.5, HEAD_H + (size.y - HEAD_H) * 0.47)


func _begin() -> void:
	_shell.play("click", -10.0)
	_state = "play"
	_bugs.clear()
	_bumps.clear()
	_splats.clear()
	_score = 0
	_bites = 0
	_slaps = 0
	_t = 0.0
	_spawn = 0.8
	_mumble = ""
	_rank = -1
	_start.visible = false


func _over(why: String) -> void:
	_state = "over"
	_mumble = why
	_start.visible = true
	_start.text = "Again"
	_rank = _shell.add_score("mosquito", _score) if _score > 0 else -1
	_shell.play("ding", -8.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_twitch = maxf(0.0, _twitch - delta)
	for s in _splats:
		s["t"] = float(s["t"]) + delta
	_splats = _splats.filter(func(s): return float(s["t"]) < 3.0)
	if not _slap.is_empty():
		_slap["t"] = float(_slap["t"]) + delta
		if float(_slap["t"]) > 0.14:
			_slap = {}
	if _state == "play":
		_tick_play(delta)
	queue_redraw()


func _tick_play(delta: float) -> void:
	var level := float(_score) / 10.0
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = maxf(0.45, 1.5 - level * 0.12) * _rng.randf_range(0.7, 1.2)
		_add_bug(level)
	var face := _face()
	for i in range(_bugs.size() - 1, -1, -1):
		var b: Dictionary = _bugs[i]
		b["phase"] = float(b["phase"]) + delta
		if float(b["land"]) >= 0.0:
			b["land"] = float(b["land"]) + delta
			if float(b["land"]) >= maxf(0.6, 1.3 - level * 0.07):
				# The bite: a bump where it sat, and it is off, full.
				_bites += 1
				_bumps.append((b["p"] as Vector2) - face)
				_twitch = 0.4
				_mumble = ["Mm... itchy...", "Nngh.", "...stop it, Pepa...", "*scratch scratch*", "Mmph!"][_rng.randi_range(0, 4)]
				_bugs.remove_at(i)
				if _bites >= BITES:
					_over("He is awake. He is not happy. Score %d." % _score)
					return
			continue
		var p: Vector2 = b["p"]
		var to := (b["spot"] as Vector2) + face - p
		var speed := float(b["speed"])
		if to.length() < 4.0:
			b["land"] = 0.0
			continue
		var dir := to.normalized()
		var side := Vector2(-dir.y, dir.x) * sin(float(b["phase"]) * float(b["wob"])) * 0.9
		b["p"] = p + (dir + side).normalized() * speed * delta


func _add_bug(level: float) -> void:
	var s := size
	var edge := _rng.randi_range(0, 3)
	var p := Vector2.ZERO
	match edge:
		0: p = Vector2(_rng.randf_range(0, s.x), HEAD_H + 2)
		1: p = Vector2(s.x - 2, _rng.randf_range(HEAD_H, s.y))
		2: p = Vector2(_rng.randf_range(0, s.x), s.y - 2)
		_: p = Vector2(2, _rng.randf_range(HEAD_H, s.y))
	var a := _rng.randf_range(0, TAU)
	var spot := Vector2(cos(a), sin(a) * 0.8) * _rng.randf_range(8, 40)
	_bugs.append({"p": p, "phase": _rng.randf_range(0, 6), "wob": _rng.randf_range(4, 9), "speed": minf(140.0, 42.0 + level * 9.0) * _rng.randf_range(0.85, 1.15), "land": -1.0, "spot": spot})


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or _state != "play":
		return
	var p: Vector2 = e.position
	_slap = {"p": p, "t": 0.0}
	var best := -1
	var best_d := HIT_R
	for i in _bugs.size():
		var d := (_bugs[i]["p"] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_splats.append({"p": _bugs[best]["p"], "t": 0.0})
		_bugs.remove_at(best)
		_score += 1
		_shell.play("click", -6.0)
		accept_event()
		return
	if p.distance_to(_face()) < 50.0:
		# A slap on the cheek.
		_slaps += 1
		_twitch = 0.6
		_mumble = ["OW!", "Wha-?", "Who did that?!"][mini(_slaps - 1, 2)]
		_shell.play("ding", -12.0)
		if _slaps >= SLAPS:
			_over("You slapped him awake. Score %d." % _score)
	accept_event()


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var s := size
	var face := _face()
	# The tent at night: canvas in two slopes, the torch's pool on him.
	draw_rect(Rect2(0, HEAD_H, s.x, s.y - HEAD_H), Color8(26, 34, 44))
	draw_colored_polygon(PackedVector2Array([Vector2(0, HEAD_H), Vector2(s.x * 0.5, HEAD_H), Vector2(0, s.y)]), Color8(32, 42, 52))
	draw_colored_polygon(PackedVector2Array([Vector2(s.x, HEAD_H), Vector2(s.x * 0.5, HEAD_H), Vector2(s.x, s.y)]), Color8(30, 38, 48))
	draw_line(Vector2(s.x * 0.5, HEAD_H), Vector2(s.x * 0.5, s.y), Color8(44, 54, 64), 2.0)
	for k in 6:
		draw_circle(face + Vector2(0, 40), 200.0 - k * 30.0, Color(1.0, 0.85, 0.5, 0.05))
	# The sleeping bag, quilted.
	var bag := Rect2(face.x - 92, face.y + 30, 184, s.y - face.y - 30)
	draw_rect(bag, Color8(40, 92, 52))
	for k in range(1, 6):
		draw_rect(Rect2(bag.position.x, bag.position.y + k * 22, bag.size.x, 1), Color8(28, 66, 38))
	draw_rect(Rect2(bag.position.x, bag.position.y, bag.size.x, 8), Color8(60, 120, 70))
	# The pillow, the head.
	draw_rect(Rect2(face.x - 70, face.y - 46, 140, 70), Color8(200, 196, 180))
	var tw := Vector2(sin(_t * 50.0) * 2.0, 0) if _twitch > 0.0 else Vector2.ZERO
	var f := face + tw
	draw_circle(f + Vector2(0, -24), 40.0, Color8(90, 56, 30))
	draw_circle(f, 38.0, SKIN)
	draw_circle(f + Vector2(-37, 2), 7.0, SKIN.darkened(0.08))
	draw_circle(f + Vector2(37, 2), 7.0, SKIN.darkened(0.08))
	var awake := _state == "over" and (_bites >= BITES or _slaps >= SLAPS)
	for side in [-1, 1]:
		var e := f + Vector2(14 * side, -6)
		if awake:
			draw_circle(e, 6.0, T.WHITE)
			draw_circle(e + Vector2(0, 1), 3.0, Color8(20, 20, 20))
			draw_line(e + Vector2(-8, -9 + side * 2), e + Vector2(8, -9 - side * 2), Color8(60, 36, 20), 2.0)
		else:
			draw_arc(e + Vector2(0, -2), 6.0, 0.2, PI - 0.2, 8, Color8(80, 50, 30), 2.0)
	draw_rect(Rect2(f + Vector2(-3, 0), Vector2(6, 10)), SKIN.darkened(0.15))
	if awake:
		draw_rect(Rect2(f + Vector2(-10, 20), Vector2(20, 3)), Color8(90, 30, 20))
	else:
		var open := 4.0 + 2.0 * sin(_t * 2.0)
		draw_circle(f + Vector2(0, 22), open, Color8(90, 30, 20))
	for b in _bumps:
		draw_circle(f + (b as Vector2), 4.0, Color8(220, 70, 60))
		draw_circle(f + (b as Vector2) - Vector2(1, 1), 1.5, Color8(255, 150, 140))
	if _state != "over" or not awake:
		# The snore.
		var z := fmod(_t * 0.6, 1.0)
		draw_string(T.FONT_BOLD, f + Vector2(44 + z * 20, -40 - z * 40), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color(1, 1, 1, 1.0 - z))
		draw_string(T.FONT_BOLD, f + Vector2(36 + z * 10, -24 - z * 20), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color(1, 1, 1, 0.8 - z * 0.8))
	for sp in _splats:
		var a := clampf(1.0 - float(sp["t"]) / 3.0, 0.0, 1.0)
		draw_circle(sp["p"], 3.0, Color(0.5, 0.05, 0.05, a))
		draw_rect(Rect2((sp["p"] as Vector2) + Vector2(2, -3), Vector2(2, 1)), Color(0.1, 0.1, 0.1, a))
	for b in _bugs:
		_draw_bug(b)
	if not _slap.is_empty():
		_draw_hand(_slap["p"])
	if _mumble != "":
		var mw := T.FONT_BOLD.get_string_size(_mumble, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var mr := Rect2(f + Vector2(-mw * 0.5 - 6, -92), Vector2(mw + 12, 18))
		if _state == "over":
			mr = Rect2(Vector2(floorf((s.x - mw) * 0.5) - 6, s.y - 92), Vector2(mw + 12, 18))
		draw_rect(mr, T.WHITE)
		draw_rect(mr, T.DARK, false, 1.0)
		draw_string(T.FONT_BOLD, mr.position + Vector2(6, 13), _mumble, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	if _state == "ready":
		var msg := "Swat the mosquitoes. Do not slap the camper."
		var w := T.FONT_BOLD.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		draw_rect(Rect2(floorf((s.x - w) * 0.5) - 8, s.y - 96, w + 16, 22), Color(0, 0, 0, 0.6))
		draw_string(T.FONT_BOLD, Vector2(floorf((s.x - w) * 0.5), s.y - 80), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(255, 230, 120))
	if _state != "play":
		BOARD.draw(self, Vector2(s.x - BOARD.SIZE.x - 10, HEAD_H + 10), "Best Swatters", _shell.scores("mosquito"), "", _rank)
	_draw_head()


## A mosquito, drawn at twice its pixels so it can be hit: wings a-blur when flying, the
## body pulsing red while it drinks.
func _draw_bug(b: Dictionary) -> void:
	var p: Vector2 = (b["p"] as Vector2).floor()
	var landed := float(b["land"]) >= 0.0
	var flap := int(float(b["phase"]) * 30.0) % 2 == 0
	draw_set_transform(p, 0.0, Vector2(2, 2))
	draw_rect(Rect2(Vector2(-3, 3), Vector2(8, 1)), Color(0, 0, 0, 0.35))
	if not landed:
		draw_rect(Rect2(Vector2(-4, -4 if flap else -3), Vector2(3, 2)), Color(0.85, 0.9, 1.0, 0.75))
		draw_rect(Rect2(Vector2(2, -4 if flap else -3), Vector2(3, 2)), Color(0.85, 0.9, 1.0, 0.75))
	var body := Color8(30, 26, 22) if not landed else (Color8(170, 20, 20) if int(float(b["land"]) * 8.0) % 2 == 0 else Color8(30, 26, 22))
	draw_rect(Rect2(Vector2(-3, -1), Vector2(6, 2)), body)
	draw_rect(Rect2(Vector2(3, -2), Vector2(2, 2)), body)
	draw_rect(Rect2(Vector2(5, -1), Vector2(2, 1)), body)
	for k in 3:
		draw_rect(Rect2(Vector2(-2 + k * 2, 1), Vector2(1, 2)), body)
	draw_set_transform(Vector2.ZERO)


func _draw_hand(p: Vector2) -> void:
	var c := Color8(220, 170, 120)
	draw_rect(Rect2(p + Vector2(-9, -4), Vector2(18, 16)), c)
	for k in 4:
		draw_rect(Rect2(p + Vector2(-9 + k * 5, -16), Vector2(4, 13)), c)
	draw_rect(Rect2(p + Vector2(-15, 0), Vector2(7, 4)), c)
	draw_rect(Rect2(p + Vector2(-9, -4), Vector2(18, 16)), Color8(120, 80, 50), false, 1.0)


func _draw_head() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, HEAD_H), Color8(16, 24, 40))
	draw_rect(Rect2(0, HEAD_H - 2, w, 2), Color8(250, 200, 40))
	draw_string(T.FONT_BOLD, Vector2(10, 26), "KOMAR 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(250, 200, 40))
	var top: Array = _shell.scores("mosquito")
	var info := "SWATTED %d     BITES %d/%d     SLAPS %d/%d     BEST %s" % [_score, _bites, BITES, _slaps, SLAPS, str(top[0][1]) if not top.is_empty() else "-"]
	var tx := 26.0 + T.FONT_BOLD.get_string_size("KOMAR 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2).x
	draw_string(T.FONT, Vector2(tx, 25), info, HORIZONTAL_ALIGNMENT_LEFT, w - tx - 6, T.FONT_SIZE, Color8(200, 210, 230))
