extends "res://scripts/closeup/closeup_view.gd"

## The postman across the counter with the parcel for the second monitor (scripts/
## reception/post_delivery.gd), close up: his clipboard with the green delivery slip and
## an empty box at its foot. You sign it with the mouse, really: hold the button and
## write, the ballpoint's line follows the hand in the picture's own pixels. Enough ink
## and he stamps it, the picture becomes the parcel pushed over the counter; a click on
## it and it is yours, the close-up shuts and the monitor is on the desk.

const PIC_SIGN := "res://assets/textury/closeup/post_sign.png"
const PIC_PARCEL := "res://assets/textury/closeup/post_parcel.png"
const SFX_PEN := "res://assets/sfx/post/pen_scribble.mp3"
const SFX_STAMP := "res://assets/sfx/post/stamp.mp3"
const SFX_PARCEL := "res://assets/sfx/post/parcel.mp3"
const SFX_LIFT := "res://assets/sfx/post/parcel_lift.mp3"
## The slip's signature box and the parcel, in picture pixels (on the Grok pictures).
const SIGN_BOX := Rect2(98, 158, 96, 24)
const PARCEL_BOX := Rect2(80, 72, 185, 135)
## Ink enough to count as a name (picture pixels of line).
const INK_ENOUGH := 55.0
const INK := Color(0.10, 0.12, 0.42)

var post
## The parcel taken: the close-up is closing on its own, not shut by the stage changing.
var done := false

var _pic_sign: Texture2D
var _pic_parcel: Texture2D
var _phase := "sign"
var _strokes: Array = []
var _drawing := false
var _ink := 0.0
var _wait := -1.0
var _pen: AudioStreamPlayer


func _ready() -> void:
	super._ready()
	_pic_sign = load(PIC_SIGN) if ResourceLoader.exists(PIC_SIGN) else null
	_pic_parcel = load(PIC_PARCEL) if ResourceLoader.exists(PIC_PARCEL) else null
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
	picture = _pic_sign
	say(tr("Postman"), tr("Parcel for the camp, order %d. Sign here, please.") % (post.order_no() if post != null else 417))


func _closing() -> void:
	_drawing = false
	_pen.stop()


func _hotspots() -> Array:
	match _phase:
		"sign":
			return [{"id": "sign", "rect": SIGN_BOX}]
		"parcel":
			return [{"id": "parcel", "rect": PARCEL_BOX}]
	return []


func _clicked(id: String) -> void:
	match id:
		"sign":
			# The pen down: a new stroke where you pressed.
			_drawing = true
			_strokes.append(PackedVector2Array([_mouse.floor()]))
			_wait = -1.0
			if not _pen.playing:
				_pen.play(randf() * 1.5)
		"parcel":
			done = true
			play(SFX_LIFT, -4.0)
			var pts: Array = []
			for s in _strokes:
				var row: Array = []
				for p in s:
					row.append([int(p.x), int(p.y)])
				pts.append(row)
			if post != null:
				post.signed(pts)
			close_view()


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
			# He looks it over, stamps it and pushes the parcel across.
			_phase = "stamp"
			play(SFX_STAMP, -2.0)
			say(tr("Postman"), tr("Right. Thank you."))
			_wait = 0.9
	elif _phase == "stamp":
		_wait -= delta
		if _wait < 0.0:
			_phase = "parcel"
			picture = _pic_parcel if _pic_parcel != null else _pic_sign
			play(SFX_PARCEL, -2.0)
			say(tr("Postman"), tr("Heavy one. Mind your back."))
	if _phase == "sign" and _hover == "sign":
		HandCursor.want(HandCursor.GRAB if _drawing else HandCursor.POINT)


func _paint(c: Control) -> void:
	if _phase == "parcel":
		return
	# The ballpoint's line: one picture pixel wide, a little blot where it stopped.
	for s in _strokes:
		var pts: PackedVector2Array = s
		if pts.size() == 1:
			c.draw_rect(Rect2(pts[0], Vector2.ONE), INK)
			continue
		for i in range(1, pts.size()):
			_line(c, pts[i - 1], pts[i])
	if _phase == "stamp":
		# The post office's round stamp over the corner of the box.
		var at := SIGN_BOX.end - Vector2(18, 16)
		c.draw_arc(at, 11.0, 0.0, TAU, 20, Color(0.55, 0.12, 0.16, 0.85), 1.0)
		c.draw_arc(at, 8.0, 0.0, TAU, 16, Color(0.55, 0.12, 0.16, 0.6), 1.0)


## A line in whole pixels (the picture's own, scaled up with it).
func _line(c: Control, a: Vector2, b: Vector2) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for k in n + 1:
		var p := a.lerp(b, float(k) / maxf(1.0, float(n))).floor()
		c.draw_rect(Rect2(p, Vector2.ONE), INK)
