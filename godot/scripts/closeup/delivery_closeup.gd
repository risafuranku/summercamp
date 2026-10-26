extends "res://scripts/closeup/closeup_view.gd"

## The wholesaler's delivery note in the folder on the reception desk, close up (the user
## 25. 10.: "the goods signed for the way the postman's slip is, but not his picture: it
## is the folder on the desk inside the reception"). While the van stands at the gate
## (scripts/day_events.gd, "delivery") the driver's note lies in the folder; you sign it
## with the mouse as the postman's slip is signed (scripts/closeup/post_closeup.gd: hold
## the button and write, the ballpoint's line in the picture's own pixels). Enough ink and
## it is stamped, the driver unloads what was ordered onto the businesses' shelves.

const PIC := "res://assets/textury/closeup/delivery_sign.png"
const SFX_PEN := "res://assets/sfx/post/pen_scribble.mp3"
const SFX_STAMP := "res://assets/sfx/desk/stamp.mp3"
const SFX_PAPER := "res://assets/sfx/desk/paper_slide.mp3"
## The note's empty box at its foot (picture px, on the Grok picture).
const SIGN_BOX := Rect2(170, 144, 78, 28)
const INK_ENOUGH := 55.0
const INK := Color(0.10, 0.12, 0.42)
## The camp's own stamp, square, as the office's other papers have it.
const STAMP_INK := Color(0.2, 0.26, 0.5, 0.85)

## Called once the note is signed and stamped (day_events.sign_delivery).
var on_signed: Callable
## How many orders the van has brought (said by the driver).
var orders := 0
var done := false

var _phase := "sign"
var _strokes: Array = []
var _drawing := false
var _ink := 0.0
var _wait := -1.0
var _pen: AudioStreamPlayer


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_pen = AudioStreamPlayer.new()
	_pen.volume_db = -6.0
	if ResourceLoader.exists(SFX_PEN):
		_pen.stream = load(SFX_PEN)
	add_child(_pen)


func _opened() -> void:
	done = false
	_phase = "sign"
	_strokes.clear()
	_drawing = false
	_ink = 0.0
	_wait = -1.0
	play(SFX_PAPER, -6.0)
	if orders > 0:
		say(tr("Driver"), tr("Wholesale for the camp, %d order(s). Sign it and I'll unload.") % orders)
	else:
		say(tr("Driver"), tr("Wholesale for the camp. Sign it and I'll unload."))


func _closing() -> void:
	_drawing = false
	_pen.stop()


func _hotspots() -> Array:
	return [{"id": "sign", "rect": SIGN_BOX}] if _phase == "sign" else []


func _clicked(id: String) -> void:
	if id != "sign":
		return
	# The pen down: a new stroke where you pressed.
	_drawing = true
	_strokes.append(PackedVector2Array([_mouse.floor()]))
	_wait = -1.0
	if not _pen.playing:
		_pen.play(randf() * 1.5)


func _tick(delta: float) -> void:
	if _drawing:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drawing = false
			_pen.stop()
			if _ink >= INK_ENOUGH:
				_wait = 0.7
		elif _mouse.x >= 0.0:
			var p := Vector2(clampf(_mouse.x, SIGN_BOX.position.x, SIGN_BOX.end.x - 1.0), clampf(_mouse.y, SIGN_BOX.position.y, SIGN_BOX.end.y - 1.0)).floor()
			var s: PackedVector2Array = _strokes.back()
			var last := s[s.size() - 1]
			if p.distance_to(last) >= 1.0:
				_ink += p.distance_to(last)
				s.append(p)
				_strokes[_strokes.size() - 1] = s
	if _phase == "sign" and _wait >= 0.0:
		_wait -= delta
		if _wait < 0.0:
			# Stamped: the van's goods are the camp's.
			_phase = "stamp"
			play(SFX_STAMP, -2.0)
			say(tr("Driver"), tr("Right. It's going on the shelves."))
			_wait = 1.4
			if on_signed.is_valid():
				on_signed.call()
	elif _phase == "stamp":
		_wait -= delta
		if _wait < 0.0:
			done = true
			close_view()
	if _phase == "sign" and _hover == "sign":
		HandCursor.want(HandCursor.GRAB if _drawing else HandCursor.POINT)


func _paint(c: Control) -> void:
	# The ballpoint's line: one picture pixel wide.
	for s in _strokes:
		var pts: PackedVector2Array = s
		if pts.size() == 1:
			c.draw_rect(Rect2(pts[0], Vector2.ONE), INK)
			continue
		for i in range(1, pts.size()):
			_line(c, pts[i - 1], pts[i])
	if _phase == "stamp":
		# The camp's square stamp over the box's corner.
		var r := Rect2(SIGN_BOX.end - Vector2(30, 20), Vector2(26, 15))
		c.draw_rect(r, STAMP_INK, false, 1.0)
		c.draw_rect(r.grow(-2.0), Color(STAMP_INK, 0.55), false, 1.0)


## A line in whole pixels (the picture's own, scaled up with it).
func _line(c: Control, a: Vector2, b: Vector2) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for k in n + 1:
		var p := a.lerp(b, float(k) / maxf(1.0, float(n))).floor()
		c.draw_rect(Rect2(p, Vector2.ONE), INK)
