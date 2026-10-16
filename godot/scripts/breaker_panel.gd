extends CanvasLayer

## The distribution board at the generator: a night job (scripts/night_jobs.gd).
##
## The main breaker has tripped and the camp is dark. One of the six circuits has a
## fault: whenever the main is on with that circuit up, the main throws itself again
## (a crack, a flash, dark). The way to find it is the electrician's way, and Vera's
## note taped inside the door says it: everything down, main up, then the circuits one
## at a time; the one that throws it stays down. Power is back when the main holds
## with the other five up. The faulty circuit stays off for the rest of the night.
##
## Drawn in virtual pixels on an integer scale like the HUD; mouse to flip, Esc to
## leave (the job stays open).

signal fixed(fault_index: int)
signal closed

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const SFX := "res://assets/sfx/power/"
const CIRCUITS := ["LAMPS N", "LAMPS S", "OFFICE", "FOOD", "WASH", "PUMP"]
## Two-line labels under the switches (the one-line ones ran into each other).
const LABELS := [["LAMPS", "NORTH"], ["LAMPS", "SOUTH"], ["OFFICE", ""], ["FOOD", ""], ["WASH", "BLOCK"], ["WATER", "PUMP"]]
const CIRCUIT_NAMES := ["LAMPS NORTH", "LAMPS SOUTH", "OFFICE", "FOOD", "WASH BLOCK", "PUMP"]
const TRIP_DELAY := 0.45
const HOLD_TO_FIX := 1.4

var _board: Control
var _scale := 3
var _main_on := false
var _up: Array[bool] = [true, true, true, true, true, true]
var _fault := 0
var _trip_timer := -1.0
var _hold_timer := -1.0
var _flash := 0.0
var _done := false
var _status := "The main has tripped. The camp is dark."
var _hum: AudioStreamPlayer
var _one: AudioStreamPlayer
var _hit_main := Rect2()
var _hit_breakers: Array[Rect2] = []
var _hover := -2            # -1 the main, 0..5 a circuit, -2 nothing
var _lever := 0.0           # 0 down .. 1 up, eased toward _main_on
var _needle := 0.0          # ammeter, 0..1 (1 = red, it is about to throw)
var _trips := 0             # how often it has thrown tonight: scorch shows on the bad one
var _sparks: Array = []     # {p: Vector2 (virtual px), v: Vector2, t: float}
var _mouse := Vector2.ZERO
var _torch: Texture2D


func _ready() -> void:
	layer = 90
	visible = false
	_hum = AudioStreamPlayer.new()
	_hum.volume_db = -10.0
	add_child(_hum)
	_one = AudioStreamPlayer.new()
	add_child(_one)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	add_child(_board)


func is_open() -> bool:
	return visible


func open(fault_index: int) -> void:
	_fault = clampi(fault_index, 0, CIRCUITS.size() - 1)
	_main_on = false
	for i in _up.size():
		_up[i] = true
	_trip_timer = -1.0
	_hold_timer = -1.0
	_done = false
	_trips = 0
	_sparks.clear()
	_lever = 0.0
	_needle = 0.0
	_status = "The main has tripped. The camp is dark."
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_board.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	_hum.stop()
	closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_scale = RETRO_UI.ui_scale(get_viewport().get_visible_rect().size.y)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
	_lever = move_toward(_lever, 1.0 if _main_on else 0.0, delta * 7.0)
	# The ammeter: load from the circuits that are up; the bad one pins it before it throws.
	var load := float(_count_up()) / float(CIRCUITS.size()) * 0.55 if _main_on else 0.0
	if _main_on and _up[_fault] and not _done:
		load = 0.75 + 0.25 * (1.0 - clampf(_trip_timer / TRIP_DELAY, 0.0, 1.0))
	_needle = lerpf(_needle, load + (randf_range(-0.02, 0.02) if _main_on else 0.0), clampf(delta * 9.0, 0.0, 1.0))
	for sp in _sparks:
		sp["t"] = float(sp["t"]) - delta
		sp["v"] = Vector2(sp["v"]) + Vector2(0, 160.0) * delta
		sp["p"] = Vector2(sp["p"]) + Vector2(sp["v"]) * delta
	_sparks = _sparks.filter(func(sp): return float(sp["t"]) > 0.0)
	if _main_on and _up[_fault] and not _done:
		if _trip_timer < 0.0:
			_trip_timer = TRIP_DELAY
		_trip_timer -= delta
		if _trip_timer <= 0.0:
			_trip()
	else:
		_trip_timer = -1.0
	if _main_on and not _up[_fault] and _count_up() == CIRCUITS.size() - 1 and not _done:
		if _hold_timer < 0.0:
			_hold_timer = HOLD_TO_FIX
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_finish()
	else:
		_hold_timer = -1.0
	_board.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		_hover = -2
		if _hit_main.has_point(_mouse):
			_hover = -1
		for i in _hit_breakers.size():
			if _hit_breakers[i].has_point(_mouse):
				_hover = i
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _done:
		var p: Vector2 = event.position
		if _hit_main.has_point(p):
			_main_on = not _main_on
			_play("main_switch.mp3")
			if _main_on:
				_hum.stream = load(SFX + "power_hum.mp3")
				if _hum.stream is AudioStreamMP3:
					(_hum.stream as AudioStreamMP3).loop = true
				_hum.play()
				_status = "Main on..."
			else:
				_hum.stop()
				_status = "Main off."
		else:
			for i in _hit_breakers.size():
				if _hit_breakers[i].has_point(p):
					_up[i] = not _up[i]
					_play("breaker_click.mp3")
					break
		get_viewport().set_input_as_handled()


func _trip() -> void:
	_main_on = false
	_trip_timer = -1.0
	_flash = 1.0
	_hum.stop()
	_play("main_trip.mp3")
	_trips += 1
	for k in 14:
		_sparks.append({"p": Vector2(25, 50), "v": Vector2(randf_range(-90, 90), randf_range(-140, -30)), "t": randf_range(0.3, 0.8)})
	_status = "It threw the main again. Something on one of these circuits." if _trips < 3 else "It threw again. Something smells burnt in here."


func _finish() -> void:
	_done = true
	_play("power_back.mp3")
	_status = "The main holds. %s stays off until Novotny has looked at it: his number is on the office noticeboard." % CIRCUIT_NAMES[_fault]
	fixed.emit(_fault)
	get_tree().create_timer(2.2).timeout.connect(close)


func _count_up() -> int:
	var n := 0
	for i in _up.size():
		if _up[i]:
			n += 1
	return n


func _play(file: String) -> void:
	if ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.play()


# ── drawing: the Grok picture of the board, the states painted onto it ───────

const PIC := "res://assets/textury/closeup/breaker.png"
const PIC_SIZE := Vector2(320, 240)
const STRIP := 30.0
## Where things are on the picture (px).
const TOGGLE_X := [113.0, 135.0, 157.5, 180.0, 202.0, 224.5]
const TOGGLE_Y := 115.0
const LED_Y := 108.0
const LABEL_Y := 144.0
const SHORT := ["L-N", "L-S", "OFC", "KIT", "WSH", "PMP"]
const LEVER_RECT := Rect2(46, 74, 34, 104)
const LEVER_COVER_SRC := Rect2(80, 74, 12, 104)
const LEVER_PIVOT := Vector2(65, 84)
const DIAL := Vector2(216, 63)
const NOTE_RECT := Rect2(281, 101, 30, 51)
const NOTE := "Vera's note, taped inside the door: \"main keeps jumping? all down, main up, then one at a time. the one that throws it stays down. - V.\""

var _pic: Texture2D


func _draw_board() -> void:
	if _pic == null and ResourceLoader.exists(PIC):
		_pic = load(PIC)
	var screen := _board.size
	var k := float(maxi(1, int(floor(minf(screen.x * 0.94 / PIC_SIZE.x, screen.y * 0.9 / (PIC_SIZE.y + STRIP))))))
	var origin := ((screen - Vector2(PIC_SIZE.x, PIC_SIZE.y + STRIP) * k) * 0.5).floor()
	var P := func(x: float, y: float) -> Vector2:
		return origin + Vector2(x, y) * k
	var R := func(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(origin + Vector2(x, y) * k, Vector2(w, h) * k)
	_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_board.draw_rect(R.call(-2, -2, PIC_SIZE.x + 4, PIC_SIZE.y + STRIP + 4), Color(0.05, 0.05, 0.04))
	if _pic != null:
		_board.draw_texture_rect(_pic, R.call(0, 0, PIC_SIZE.x, PIC_SIZE.y), false)

	# The main: the picture shows it down (off). Up, the painted lever is covered with
	# the housing beside it and the lever drawn swung up, in two steps.
	if _lever > 0.34 and _pic != null:
		_board.draw_texture_rect_region(_pic, R.call(LEVER_RECT.position.x, LEVER_RECT.position.y, LEVER_RECT.size.x, LEVER_RECT.size.y), LEVER_COVER_SRC)
		var up := 1.0 if _lever > 0.67 else 0.55
		var ang := lerpf(PI * 0.5, -PI * 0.58, up)
		var tip := LEVER_PIVOT + Vector2(cos(ang), sin(ang)) * 30.0
		var side := Vector2(-sin(ang), cos(ang)) * 4.5
		var poly := PackedVector2Array([P.call(LEVER_PIVOT.x + side.x, LEVER_PIVOT.y + side.y), P.call(LEVER_PIVOT.x - side.x, LEVER_PIVOT.y - side.y), P.call(tip.x - side.x * 0.8, tip.y - side.y * 0.8), P.call(tip.x + side.x * 0.8, tip.y + side.y * 0.8)])
		_board.draw_colored_polygon(poly, Color(0.55, 0.1, 0.07))
		_board.draw_line(P.call(LEVER_PIVOT.x - side.x * 0.4, LEVER_PIVOT.y - side.y * 0.4), P.call(tip.x - side.x * 0.4, tip.y - side.y * 0.4), Color(0.82, 0.3, 0.2), k)
		_board.draw_rect(R.call(LEVER_PIVOT.x - 4, LEVER_PIVOT.y - 3, 8, 6), Color(0.1, 0.1, 0.1))
	if _hover == -1:
		_board.draw_rect(R.call(LEVER_RECT.position.x - 1, LEVER_RECT.position.y - 1, LEVER_RECT.size.x + 2, LEVER_RECT.size.y + 2), Color(1.0, 0.85, 0.3, 0.8), false, k)
	_hit_main = R.call(LEVER_RECT.position.x, LEVER_RECT.position.y - 20, LEVER_RECT.size.x, LEVER_RECT.size.y + 20)

	# The six breakers: the toggle up or down, the lamp above, the label strip.
	_hit_breakers.clear()
	for i in CIRCUITS.size():
		var x: float = TOGGLE_X[i]
		var powered: bool = _main_on and _up[i]
		if i == _fault and _trips >= 3:
			_board.draw_rect(R.call(x - 10, 102, 20, 46), Color(0.1, 0.06, 0.02, 0.5))
		_board.draw_rect(R.call(x - 3, TOGGLE_Y, 6, 15), Color(0.05, 0.05, 0.05))
		if _up[i]:
			_board.draw_rect(R.call(x - 3, TOGGLE_Y, 6, 7), Color(0.58, 0.58, 0.55))
			_board.draw_rect(R.call(x - 3, TOGGLE_Y, 6, 1), Color(0.85, 0.85, 0.8))
		else:
			_board.draw_rect(R.call(x - 3, TOGGLE_Y + 8, 6, 7), Color(0.5, 0.12, 0.08))
			_board.draw_rect(R.call(x - 3, TOGGLE_Y + 8, 6, 1), Color(0.75, 0.3, 0.2))
		var led := Color(0.45, 1.0, 0.4) if powered else Color(0.12, 0.14, 0.1)
		_board.draw_rect(R.call(x - 1.5, LED_Y - 1.5, 3, 3), led)
		if powered:
			_board.draw_rect(R.call(x - 3, LED_Y - 3, 6, 6), Color(0.5, 1.0, 0.4, 0.22))
		var lw: float = RETRO_UI.FONT_TEXT.get_string_size(SHORT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * int(k)).x
		_board.draw_string(RETRO_UI.FONT_TEXT, (P.call(x, LABEL_Y) - Vector2(lw * 0.5, 0)).floor(), SHORT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * int(k), Color(0.15, 0.13, 0.12))
		if _hover == i:
			_board.draw_rect(R.call(x - 9, 103, 18, 31), Color(1.0, 0.85, 0.3, 0.8), false, k)
		_hit_breakers.append(R.call(x - 9, 103, 18, 31))

	# The ammeter: a fresh dial face over the picture's, ticks green, amber, red.
	_board.draw_circle(P.call(DIAL.x, DIAL.y), 14.0 * k, Color(0.86, 0.82, 0.7))
	var pivot: Vector2 = P.call(DIAL.x, DIAL.y + 8)
	for t in 11:
		var a0 := PI + PI * float(t) / 10.0
		var col := Color(0.2, 0.5, 0.2) if t < 6 else (Color(0.8, 0.6, 0.1) if t < 8 else Color(0.8, 0.15, 0.1))
		_board.draw_line(pivot + Vector2(cos(a0), sin(a0)) * 10.0 * k, pivot + Vector2(cos(a0), sin(a0)) * 12.5 * k, col, k)
	var an := PI + PI * clampf(_needle, 0.0, 1.0)
	_board.draw_line(pivot, pivot + Vector2(cos(an), sin(an)) * 12.0 * k, Color(0.08, 0.08, 0.08), k)
	_board.draw_rect(Rect2(pivot - Vector2(k, k), Vector2(2, 2) * k), Color(0.1, 0.1, 0.1))

	# Vera's note: scribbles you can read by pointing at it.
	for li in 6:
		_board.draw_rect(R.call(NOTE_RECT.position.x + 4, NOTE_RECT.position.y + 8 + li * 6, NOTE_RECT.size.x - 8 - (li % 3) * 3, 1), Color(0.2, 0.18, 0.3, 0.7))
	var over_note: bool = R.call(NOTE_RECT.position.x, NOTE_RECT.position.y, NOTE_RECT.size.x, NOTE_RECT.size.y).has_point(_mouse)

	# The strip under the picture: what is happening, or the note when you point at it.
	_board.draw_rect(R.call(0, PIC_SIZE.y, PIC_SIZE.x, STRIP), Color(0.06, 0.05, 0.04))
	_board.draw_rect(R.call(0, PIC_SIZE.y, PIC_SIZE.x, 1), RETRO_UI.C_PLATE_LIGHT * Color(1, 1, 1, 0.5))
	var lines := _wrap(NOTE if over_note else _status, 74)
	for li in mini(lines.size(), 3):
		_board.draw_string(RETRO_UI.FONT_TEXT, P.call(6, PIC_SIZE.y + 10 + li * 8).floor(), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * int(k), RETRO_UI.C_BONE if over_note else Color(0.95, 0.85, 0.5))

	for sp in _sparks:
		var pp: Vector2 = P.call(LEVER_PIVOT.x + float(sp["p"].x) - 25.0, LEVER_PIVOT.y + float(sp["p"].y) - 50.0)
		_board.draw_rect(Rect2(pp, Vector2(k, k)), Color(1.0, 0.9, 0.5, clampf(float(sp["t"]) * 2.0, 0.0, 1.0)))

	# Torchlight: the box is lit where you point the torch, dark elsewhere.
	if not (_main_on and not _done) and _torch_texture() != null:
		var r := 120.0 * k
		var m := _mouse if _mouse != Vector2.ZERO else screen * 0.5
		var rect := Rect2(m - Vector2(r, r), Vector2(r, r) * 2.0)
		var dark := Color(0, 0, 0, 0.7)
		_board.draw_rect(Rect2(0, 0, screen.x, rect.position.y), dark)
		_board.draw_rect(Rect2(0, rect.end.y, screen.x, screen.y - rect.end.y), dark)
		_board.draw_rect(Rect2(0, rect.position.y, rect.position.x, rect.size.y), dark)
		_board.draw_rect(Rect2(rect.end.x, rect.position.y, screen.x - rect.end.x, rect.size.y), dark)
		_board.draw_texture_rect(_torch, rect, false, Color(1, 1, 1, 0.7))
	if _flash > 0.0:
		_board.draw_rect(Rect2(Vector2.ZERO, screen), Color(1, 1, 0.9, _flash * 0.75))
	if _hover != -2:
		HandCursor.want(HandCursor.POINT)


## A disc of light: transparent in the middle, black at the rim.
func _torch_texture() -> Texture2D:
	if _torch != null:
		return _torch
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			img.set_pixel(x, y, Color(0, 0, 0, clampf((d - 0.45) / 0.55, 0.0, 1.0)))
	_torch = ImageTexture.create_from_image(img)
	return _torch


func _wrap(t: String, width: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for w in t.split(" "):
		if line.length() + w.length() + 1 > width and not line.is_empty():
			out.append(line)
			line = w
		else:
			line = w if line.is_empty() else line + " " + w
	if not line.is_empty():
		out.append(line)
	return out


func _text(t: String, pos: Vector2, font: Font, size_vp: int, color: Color) -> void:
	var size_px := size_vp * _scale
	var shadow := float(RETRO_UI.font_pixel(font, size_vp) * _scale)
	_board.draw_string(font, pos.floor() + Vector2(shadow, shadow), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, 0.7))
	_board.draw_string(font, pos.floor(), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
