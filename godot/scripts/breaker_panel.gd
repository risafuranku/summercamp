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
	_status = "It threw the main again. Something on one of these circuits."


func _finish() -> void:
	_done = true
	_play("power_back.mp3")
	_status = "The main holds. %s stays off until the electrician comes." % CIRCUIT_NAMES[_fault]
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


# ── drawing (virtual pixels x scale) ─────────────────────────────────────────

func _draw_board() -> void:
	var s := float(_scale)
	var screen := _board.size
	var bw := 268.0
	var bh := 176.0
	var origin := ((screen - Vector2(bw, bh) * s) * 0.5).floor()
	var R := func(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(origin + Vector2(x, y) * s, Vector2(w, h) * s)
	var metal := Color(0.30, 0.32, 0.30)
	# Box with a bevel and rivets.
	_board.draw_rect(R.call(-2, -2, bw + 4, bh + 4), Color(0.08, 0.08, 0.07))
	_board.draw_rect(R.call(0, 0, bw, bh), metal)
	_board.draw_rect(R.call(0, 0, bw, 1), metal.lightened(0.3))
	_board.draw_rect(R.call(0, 0, 1, bh), metal.lightened(0.2))
	_board.draw_rect(R.call(0, bh - 1, bw, 1), metal.darkened(0.5))
	_board.draw_rect(R.call(bw - 1, 0, 1, bh), metal.darkened(0.5))
	for c in [Vector2(4, 4), Vector2(bw - 6, 4), Vector2(4, bh - 6), Vector2(bw - 6, bh - 6)]:
		_board.draw_rect(R.call(c.x, c.y, 2, 2), metal.darkened(0.45))
	_text("DISTRIBUTION BOARD 2", origin + Vector2(8, 13) * s, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, Color(0.86, 0.84, 0.7))
	_text("CAMP CIRCUITS  230 V  ~", origin + Vector2(8, 23) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.62, 0.62, 0.55))
	# Danger sticker.
	_board.draw_rect(R.call(bw - 26, 6, 20, 16), Color(0.9, 0.72, 0.1))
	_text("!", origin + Vector2(bw - 18, 19) * s, RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG, Color(0.1, 0.08, 0.05))

	# MAIN lever.
	var mx := 10.0
	var my := 34.0
	_board.draw_rect(R.call(mx, my, 30, 64), Color(0.16, 0.16, 0.15))
	_board.draw_rect(R.call(mx + 12, my + 6, 6, 52), Color(0.06, 0.06, 0.06))
	var lever_y := my + 8.0 if _main_on else my + 40.0
	_board.draw_rect(R.call(mx + 6, lever_y, 18, 12), Color(0.72, 0.12, 0.08))
	_board.draw_rect(R.call(mx + 6, lever_y, 18, 2), Color(0.95, 0.35, 0.25))
	_text("MAIN", origin + Vector2(mx + 4, my + 76) * s, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, Color(0.9, 0.88, 0.75))
	_text("ON" if _main_on else "OFF", origin + Vector2(mx + 8, my + 86) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.5, 0.95, 0.4) if _main_on else Color(0.95, 0.4, 0.3))
	_hit_main = R.call(mx, my, 30, 64)

	# The six circuits.
	_hit_breakers.clear()
	for i in CIRCUITS.size():
		var x := 58.0 + float(i) * 34.0
		var y := 40.0
		var powered: bool = _main_on and _up[i]
		_board.draw_rect(R.call(x + 6, y - 8, 6, 4), Color(0.95, 0.85, 0.3) if powered else Color(0.22, 0.2, 0.14))
		_board.draw_rect(R.call(x, y, 18, 40), Color(0.84, 0.82, 0.76))
		_board.draw_rect(R.call(x, y, 18, 1), Color(1, 1, 1))
		_board.draw_rect(R.call(x + 5, y + 6, 8, 28), Color(0.2, 0.2, 0.2))
		var ty := y + 7.0 if _up[i] else y + 21.0
		_board.draw_rect(R.call(x + 5, ty, 8, 12), Color(0.12, 0.12, 0.12) if _up[i] else Color(0.55, 0.1, 0.08))
		var label_w: float = RETRO_UI.FONT_TEXT.get_string_size(CIRCUITS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, RETRO_UI.SIZE_TEXT * _scale).x
		_text(CIRCUITS[i], origin + Vector2(x + 9, y + 52) * s - Vector2(label_w * 0.5, 0), RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.86, 0.84, 0.72))
		_hit_breakers.append(R.call(x, y, 18, 40))

	# Vera's note, taped inside the door.
	_board.draw_rect(R.call(172, 112, 88, 54), Color(0.92, 0.88, 0.72))
	_board.draw_rect(R.call(204, 110, 22, 4), Color(0.8, 0.78, 0.6, 0.8))
	var note := ["main keeps jumping?", "all down, main up,", "then one at a time.", "the one that throws", "it stays down. - V."]
	for li in note.size():
		_text(note[li], origin + Vector2(176, 122 + li * 9) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.18, 0.16, 0.25))

	var lines := _wrap(_status, 34)
	for li in lines.size():
		_text(lines[li], origin + Vector2(8, 132 + li * 9) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.95, 0.85, 0.5))
	_text("[CLICK] flip   [ESC] leave", origin + Vector2(8, 168) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.6, 0.6, 0.55))
	if _flash > 0.0:
		_board.draw_rect(Rect2(Vector2.ZERO, screen), Color(1, 1, 0.9, _flash * 0.75))


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
