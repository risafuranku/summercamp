extends Control

## SectiTo 98: the District Office counts what it owns and what it taxes from the air. A
## photograph comes up (drawn here, seeded, so the same number is always the same
## picture) with a question: how many tents, how many cows, how many boats. Things that
## are nearly the thing are in the picture too (caravans, sheep, logs). Type the number,
## Enter. The right count pays $3, one out pays $1. The answer shows where they all were;
## Enter again brings the next photograph, the field keeps the cursor (playtest 25. 10.:
## "Enter to the next photo, the field ready, so the hand stays on the touchpad"). As
## many photographs as you like (the same playtest: "nonstop, no limit").
##
## Some photographs the district counted one more on than there is.

const T = preload("res://scripts/os98/os_theme.gd")
const PAY := 3
const HEAD_H := 46
const PHOTO := Vector2(420, 262)
const SUBJECTS := {
	"tents": {"ask": "TENTS", "where": "camp field, Cerne jezero"},
	"cows": {"ask": "COWS", "where": "pasture, Agrostroj Hlubocany"},
	"boats": {"ask": "BOATS", "where": "reservoir, west shore"},
}

var _shell
var _win
var _photo: Control
var _input: LineEdit
var _go: Button
var _next: Button
var _msg: Label
var _state := "idle"            # idle, ask, shown
var _subject := "tents"
var _items: Array = []          # {k: kind, p: Vector2, r: rot, c: colour, target: bool}
var _trees: Array = []
var _lake := PackedVector2Array()
var _extra := Vector2(-1, -1)    # the one the district counted that is not there
var _answer := 0
var _said := -1
var _time := 0.0
var _limit := 20.0
var _photo_no := 0
var _rng := RandomNumberGenerator.new()


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	mouse_filter = Control.MOUSE_FILTER_STOP
	_photo = Control.new()
	_photo.draw.connect(_draw_photo)
	add_child(_photo)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var l := Label.new()
	l.name = "Ask"
	l.text = "How many?"
	l.add_theme_font_override("font", T.FONT_BOLD)
	row.add_child(l)
	_input = LineEdit.new()
	_input.custom_minimum_size = Vector2(56, 22)
	_input.max_length = 3
	_input.keep_editing_on_text_submit = true
	_input.text_submitted.connect(func(_t): _submit())
	row.add_child(_input)
	_go = Button.new()
	_go.text = "Submit"
	_go.custom_minimum_size = Vector2(76, 22)
	_go.focus_mode = Control.FOCUS_NONE
	_go.pressed.connect(_submit)
	row.add_child(_go)
	_next = Button.new()
	_next.text = "First photograph"
	_next.custom_minimum_size = Vector2(130, 22)
	_next.focus_mode = Control.FOCUS_NONE
	_next.add_theme_font_override("font", T.FONT_BOLD)
	_next.pressed.connect(_new_photo)
	row.add_child(_next)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_msg)
	resized.connect(_layout)
	_layout()
	_set_state("idle")
	_msg.text = "Count what the photograph asks for. Type the number and press Enter."


func _layout() -> void:
	if _photo == null:
		return
	_photo.position = Vector2(floorf((size.x - PHOTO.x) * 0.5), HEAD_H + 8)
	_photo.size = PHOTO + Vector2(8, 30)
	var row: Control = get_node("Row")
	row.position = Vector2(_photo.position.x, _photo.position.y + _photo.size.y + 8)
	row.size = Vector2(PHOTO.x, 24)
	_msg.position = Vector2(_photo.position.x, row.position.y + 30)
	_msg.size = Vector2(PHOTO.x, 48)


## The field takes the keys whenever the program is up (Enter starts, answers, goes on).
func shown() -> void:
	if _input != null:
		_input.grab_focus.call_deferred()


func _set_state(s: String) -> void:
	_state = s
	_go.disabled = s != "ask"
	_next.visible = s != "ask"
	(get_node("Row/Ask") as Label).text = "How many %s?" % SUBJECTS[_subject]["ask"] if s != "idle" else "How many?"
	_photo.queue_redraw()
	queue_redraw()


func _new_photo() -> void:
	_shell.play("hdd", -14.0)
	_photo_no = 400 + _shell.job_done("census") * 7 + (CoreRoot.get_day() if CoreRoot != null else 1) * 31
	_rng.seed = hash("census%d" % _photo_no)
	_subject = ["tents", "cows", "boats"][_rng.randi_range(0, 2)]
	_build_photo()
	_said = -1
	_time = 0.0
	_limit = 14.0 + _answer * 0.6
	_input.text = ""
	_set_state("ask")
	_input.grab_focus.call_deferred()
	_msg.text = "Photograph %04d, %s." % [_photo_no, SUBJECTS[_subject]["where"]]


func _submit() -> void:
	if _state != "ask":
		_new_photo()
		return
	_said = int(_input.text) if _input.text.strip_edges().is_valid_int() else -1
	_finish()


func _finish() -> void:
	var off := absi(_said - _answer) if _said >= 0 else 99
	var pay := PAY if off == 0 else (1 if off == 1 else 0)
	_shell.job_add("census", 1)
	if pay > 0:
		_shell.earn(pay)
	_shell.play("click" if pay > 0 else "ding", -8.0)
	_input.text = ""
	_set_state("shown")
	var said_txt := ("you said %d" % _said) if _said >= 0 else "no answer"
	_msg.text = "The district counted %d (%s). %s" % [_answer, said_txt, ("Paid $%d." % pay) if pay > 0 else "Not paid."]
	_next.text = "Next photograph"


func _process(delta: float) -> void:
	if _state != "ask":
		return
	_time += delta
	if _time >= _limit:
		_said = -1
		_finish()
		_msg.text = "Time is up. " + _msg.text
	queue_redraw()


# ── the photograph ───────────────────────────────────────────────────────────

func _build_photo() -> void:
	_items.clear()
	_trees.clear()
	_lake = PackedVector2Array()
	_extra = Vector2(-1, -1)
	var w := PHOTO.x
	var h := PHOTO.y
	# The water: a blob along one side (boats need a lot of it).
	var water_side := w * (0.55 if _subject == "boats" else 0.82)
	var pts := PackedVector2Array()
	for i in 14:
		var y := h * float(i) / 13.0
		pts.append(Vector2(water_side + _rng.randf_range(-18, 18), y))
	pts.append(Vector2(w, h))
	pts.append(Vector2(w, 0))
	_lake = pts
	# Trees round the edges, thick at the top: the forest.
	for i in 70:
		var p := Vector2(_rng.randf_range(0, water_side - 10), _rng.randf_range(0, h))
		if p.y > 40 and p.x > 30 and _rng.randf() < 0.75:
			continue
		_trees.append([p, _rng.randf_range(6, 11)])
	var target_n := _rng.randi_range(4, 11)
	var near_n := _rng.randi_range(2, 5)
	var kinds: Array = {"tents": ["tent", "caravan"], "cows": ["cow", "sheep"], "boats": ["boat", "log"]}[_subject]
	for i in target_n:
		_place(str(kinds[0]), true, water_side)
	for i in near_n:
		_place(str(kinds[1]), false, water_side)
	_answer = target_n
	# Once the day's batch is under way, a photograph now and then has one more counted.
	if _shell.job_done("census") >= 3 and _rng.randf() < 0.14 and _subject != "boats":
		_answer += 1
		_extra = Vector2(_rng.randf_range(20, water_side - 30), _rng.randf_range(42, 60))


func _place(kind: String, target: bool, water_side: float) -> void:
	for attempt in 30:
		var on_water := kind == "boat" or kind == "log"
		var p := Vector2(_rng.randf_range(water_side + 26, PHOTO.x - 14) if on_water else _rng.randf_range(16, water_side - 22), _rng.randf_range(54, PHOTO.y - 12))
		var free := true
		for it in _items:
			if (it["p"] as Vector2).distance_to(p) < 17.0:
				free = false
				break
		if not free:
			continue
		var cols := {"tent": [Color8(230, 120, 30), Color8(40, 90, 200), Color8(40, 150, 60), Color8(200, 40, 40)], "caravan": [Color8(236, 236, 228)],
			"cow": [Color8(240, 240, 236)], "sheep": [Color8(226, 222, 210)], "boat": [Color8(130, 80, 40), Color8(210, 210, 200)], "log": [Color8(80, 56, 36)]}
		var pal: Array = cols[kind]
		_items.append({"k": kind, "p": p, "r": _rng.randf_range(-0.6, 0.6), "c": pal[_rng.randi_range(0, pal.size() - 1)], "target": target})
		return


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, HEAD_H), Color8(70, 90, 50))
	draw_rect(Rect2(0, HEAD_H - 2, w, 2), Color8(30, 40, 20))
	draw_string(T.FONT_BOLD, Vector2(10, 20), "SectiTo 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(240, 230, 170))
	draw_string(T.FONT, Vector2(12, 38), "District Office Hlubocany - survey of property from the air", HORIZONTAL_ALIGNMENT_LEFT, w - 170, T.FONT_SIZE, Color8(210, 220, 190))
	var cells := [["TODAY", "%d" % _shell.job_done("census")], ["TIME", ("%d s" % int(ceil(_limit - _time))) if _state == "ask" else "-"]]
	var x := w - 4.0
	for i in range(cells.size() - 1, -1, -1):
		x -= 70.0
		var r := Rect2(x, 6, 70, HEAD_H - 14)
		draw_style_box(T.box("field", Color8(20, 20, 20), Vector4.ZERO), r)
		draw_string(T.FONT, r.position + Vector2(5, 12), str(cells[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(120, 200, 120))
		draw_string(T.FONT_BOLD, r.position + Vector2(5, 26), str(cells[i][1]), HORIZONTAL_ALIGNMENT_LEFT, 62, T.FONT_SIZE, Color8(90, 255, 120))
		x -= 4.0


func _draw_photo() -> void:
	var c := _photo
	# The print on the light box: a white border, the number written on it.
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color8(250, 250, 246))
	c.draw_rect(Rect2(Vector2.ZERO, c.size), T.SHADOW, false, 1.0)
	var o := Vector2(4, 4)
	var pr := Rect2(o, PHOTO)
	if _state == "idle":
		c.draw_rect(pr, Color8(40, 40, 40))
		c.draw_string(T.FONT, o + Vector2(PHOTO.x * 0.5 - 90, PHOTO.y * 0.5), "No photograph on the light box.", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(170, 170, 170))
		return
	c.draw_rect(pr, Color8(84, 110, 52))
	var rng := RandomNumberGenerator.new()
	rng.seed = _photo_no * 13 + 1
	for i in 260:
		var p := o + Vector2(rng.randf() * PHOTO.x, rng.randf() * PHOTO.y)
		c.draw_rect(Rect2(p.floor(), Vector2(2, 1)), Color8(70, 96, 44) if i % 2 else Color8(100, 124, 60))
	var lake := PackedVector2Array()
	for p in _lake:
		lake.append(p + o)
	c.draw_colored_polygon(lake, Color8(40, 70, 96))
	c.draw_polyline(lake, Color8(110, 100, 70), 2.0)
	for t in _trees:
		var tp: Vector2 = (t[0] as Vector2) + o
		var tr := float(t[1])
		c.draw_circle(tp + Vector2(3, 3), tr, Color8(30, 40, 20))
		c.draw_circle(tp, tr, Color8(36, 70, 30))
		c.draw_circle(tp - Vector2(2, 2), tr * 0.5, Color8(56, 96, 40))
	for it in _items:
		_draw_item(c, it, o)
	if _state == "shown":
		# Where the district's counters marked them.
		var n := 0
		for it in _items:
			if bool(it["target"]):
				n += 1
				var p: Vector2 = (it["p"] as Vector2) + o
				c.draw_arc(p, 9.0, 0, TAU, 16, Color8(255, 240, 0), 1.0)
				c.draw_string(T.FONT, p + Vector2(8, -6), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(255, 240, 0))
		if _extra.x >= 0.0:
			n += 1
			c.draw_arc(_extra + o, 9.0, 0, TAU, 16, Color8(255, 240, 0), 1.0)
			c.draw_string(T.FONT, _extra + o + Vector2(8, -6), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(255, 240, 0))
	c.draw_string(T.FONT, Vector2(6, c.size.y - 8), "No. %04d   %s   scale 1:2000" % [_photo_no, SUBJECTS[_subject]["where"]], HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(60, 60, 140))


func _draw_item(c: Control, it: Dictionary, o: Vector2) -> void:
	var p: Vector2 = (it["p"] as Vector2) + o
	var col: Color = it["c"]
	c.draw_set_transform(p, float(it["r"]))
	match str(it["k"]):
		"tent":
			c.draw_rect(Rect2(-4, -3, 11, 9), Color(0, 0, 0, 0.35))
			c.draw_rect(Rect2(-6, -5, 11, 9), col)
			c.draw_rect(Rect2(-6, -1, 11, 1), col.darkened(0.45))
			c.draw_rect(Rect2(-6, -5, 11, 2), col.lightened(0.25))
		"caravan":
			c.draw_rect(Rect2(-6, -3, 16, 8), Color(0, 0, 0, 0.35))
			c.draw_rect(Rect2(-8, -5, 16, 8), col)
			c.draw_rect(Rect2(-8, -5, 16, 8), Color8(120, 120, 120), false, 1.0)
			c.draw_rect(Rect2(-6, -3, 3, 2), Color8(90, 130, 170))
		"cow":
			c.draw_rect(Rect2(-5, -2, 11, 6), Color(0, 0, 0, 0.3))
			c.draw_rect(Rect2(-6, -3, 11, 6), col)
			c.draw_rect(Rect2(-3, -3, 3, 3), Color8(20, 20, 20))
			c.draw_rect(Rect2(2, 0, 2, 3), Color8(20, 20, 20))
			c.draw_rect(Rect2(5, -2, 3, 4), Color8(40, 30, 26))
		"sheep":
			c.draw_circle(Vector2(1, 1), 4.5, Color(0, 0, 0, 0.3))
			c.draw_circle(Vector2.ZERO, 4.5, col)
			c.draw_rect(Rect2(4, -1, 2, 2), Color8(30, 30, 30))
		"boat":
			c.draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(-4, -3), Vector2(5, -3), Vector2(8, 0), Vector2(5, 3), Vector2(-4, 3)]), col)
			c.draw_rect(Rect2(-2, -1, 4, 2), col.darkened(0.4))
		"log":
			c.draw_rect(Rect2(-8, -1, 16, 3), col)
			c.draw_rect(Rect2(-8, -1, 16, 1), col.lightened(0.3))
	c.draw_set_transform(Vector2.ZERO)
