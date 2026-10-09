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
	var bw := 300.0
	var bh := 190.0
	var origin := ((screen - Vector2(bw, bh) * s) * 0.5).floor()
	var R := func(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(origin + Vector2(x, y) * s, Vector2(w, h) * s)
	var metal := Color(0.30, 0.32, 0.30)
	# Box with a bevel, rivets and a few scratches.
	_board.draw_rect(R.call(-3, -3, bw + 6, bh + 6), Color(0.06, 0.06, 0.05))
	_board.draw_rect(R.call(0, 0, bw, bh), metal)
	for k in 9:
		var sx := fmod(float(k) * 37.0, bw - 20.0) + 6.0
		_board.draw_rect(R.call(sx, 30 + fmod(float(k) * 53.0, bh - 40.0), 8 + k % 5, 1), metal.lightened(0.12))
	_board.draw_rect(R.call(0, 0, bw, 1), metal.lightened(0.3))
	_board.draw_rect(R.call(0, 0, 1, bh), metal.lightened(0.2))
	_board.draw_rect(R.call(0, bh - 1, bw, 1), metal.darkened(0.5))
	_board.draw_rect(R.call(bw - 1, 0, 1, bh), metal.darkened(0.5))
	for c in [Vector2(4, 4), Vector2(bw - 6, 4), Vector2(4, bh - 6), Vector2(bw - 6, bh - 6)]:
		_board.draw_rect(R.call(c.x, c.y, 2, 2), metal.darkened(0.45))
	_text("DISTRIBUTION BOARD 2", origin + Vector2(8, 13) * s, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, Color(0.86, 0.84, 0.7))
	_text("CAMP CIRCUITS  230 V  ~   ELEKTROMONT 1979", origin + Vector2(8, 23) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.62, 0.62, 0.55))

	# Ammeter, top right: green, amber, red.
	var gx := bw - 62.0
	var gy := 6.0
	_board.draw_rect(R.call(gx, gy, 54, 30), Color(0.12, 0.12, 0.11))
	_board.draw_rect(R.call(gx + 2, gy + 2, 50, 26), Color(0.88, 0.86, 0.76))
	var pivot := origin + Vector2(gx + 27, gy + 26) * s
	for k in 11:
		var a0 := PI + PI * float(k) / 10.0
		var col := Color(0.2, 0.5, 0.2) if k < 6 else (Color(0.8, 0.6, 0.1) if k < 8 else Color(0.8, 0.15, 0.1))
		_board.draw_line(pivot + Vector2(cos(a0), sin(a0)) * 18.0 * s, pivot + Vector2(cos(a0), sin(a0)) * 21.0 * s, col, s)
	var an := PI + PI * clampf(_needle, 0.0, 1.0)
	_board.draw_line(pivot, pivot + Vector2(cos(an), sin(an)) * 20.0 * s, Color(0.1, 0.1, 0.1), maxf(1.0, s * 0.7))
	_text("A", origin + Vector2(gx + 4, gy + 12) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.2, 0.2, 0.2))

	# MAIN lever, sliding.
	var mx := 10.0
	var my := 36.0
	_board.draw_rect(R.call(mx, my, 30, 70), Color(0.16, 0.16, 0.15))
	if _hover == -1:
		_board.draw_rect(R.call(mx - 1, my - 1, 32, 72), Color(1.0, 0.85, 0.3, 0.9), false, s)
	_board.draw_rect(R.call(mx + 12, my + 6, 6, 58), Color(0.06, 0.06, 0.06))
	var lever_y := lerpf(my + 46.0, my + 8.0, ease(_lever, 0.6))
	_board.draw_rect(R.call(mx + 6, lever_y, 18, 12), Color(0.72, 0.12, 0.08))
	_board.draw_rect(R.call(mx + 6, lever_y, 18, 2), Color(0.95, 0.35, 0.25))
	_text("MAIN", origin + Vector2(mx + 4, my + 82) * s, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, Color(0.9, 0.88, 0.75))
	_text("ON" if _main_on else "OFF", origin + Vector2(mx + 8, my + 92) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.5, 0.95, 0.4) if _main_on else Color(0.95, 0.4, 0.3))
	_hit_main = R.call(mx, my, 30, 70)

	# The six circuits.
	_hit_breakers.clear()
	for i in CIRCUITS.size():
		var x := 60.0 + float(i) * 38.0
		var y := 44.0
		var powered: bool = _main_on and _up[i]
		_board.draw_rect(R.call(x + 6, y - 8, 6, 4), Color(0.95, 0.85, 0.3) if powered else Color(0.22, 0.2, 0.14))
		if powered:
			_board.draw_rect(R.call(x + 4, y - 10, 10, 8), Color(1.0, 0.9, 0.4, 0.18))
		if i == _fault and _trips >= 3:
			# Scorched: the plastic has browned around the bad one.
			_board.draw_rect(R.call(x - 3, y - 2, 24, 30), Color(0.12, 0.08, 0.04, 0.55))
		_board.draw_rect(R.call(x, y, 18, 40), Color(0.84, 0.82, 0.76))
		_board.draw_rect(R.call(x, y, 18, 1), Color(1, 1, 1))
		if _hover == i:
			_board.draw_rect(R.call(x - 1, y - 1, 20, 42), Color(1.0, 0.85, 0.3, 0.9), false, s)
		_board.draw_rect(R.call(x + 5, y + 6, 8, 28), Color(0.2, 0.2, 0.2))
		var ty := y + 7.0 if _up[i] else y + 21.0
		_board.draw_rect(R.call(x + 5, ty, 8, 12), Color(0.12, 0.12, 0.12) if _up[i] else Color(0.55, 0.1, 0.08))
		for li in 2:
			var word: String = LABELS[i][li]
			if word.is_empty():
				continue
			var lw: float = RETRO_UI.FONT_TEXT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, RETRO_UI.SIZE_TEXT * _scale).x
			_text(word, origin + Vector2(x + 9, y + 52 + li * 9) * s - Vector2(lw * 0.5, 0), RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.86, 0.84, 0.72))
		_hit_breakers.append(R.call(x, y, 18, 40))

	# The note taped inside the door.
	_board.draw_rect(R.call(200, 124, 92, 56), Color(0.92, 0.88, 0.72))
	_board.draw_rect(R.call(232, 122, 22, 4), Color(0.8, 0.78, 0.6, 0.8))
	var note := ["main keeps jumping?", "all down, main up,", "then one at a time.", "the one that throws", "it stays down. - V."]
	for li in note.size():
		_text(note[li], origin + Vector2(204, 134 + li * 9) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.18, 0.16, 0.25))

	var lines := _wrap(_status, 36)
	for li in lines.size():
		_text(lines[li], origin + Vector2(8, 146 + li * 9) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.95, 0.85, 0.5))
	_text("[CLICK] flip   [ESC] leave", origin + Vector2(8, 182) * s, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, Color(0.6, 0.6, 0.55))
	for sp in _sparks:
		var pp: Vector2 = origin + Vector2(sp["p"]) * s
		_board.draw_rect(Rect2(pp, Vector2(s, s)), Color(1.0, 0.9, 0.5, clampf(float(sp["t"]) * 2.0, 0.0, 1.0)))

	# Torchlight: the box is lit where you point the torch, dark elsewhere.
	if not (_main_on and not _done) and _torch_texture() != null:
		var r := 150.0 * s
		var m := _mouse if _mouse != Vector2.ZERO else screen * 0.5
		var rect := Rect2(m - Vector2(r, r), Vector2(r, r) * 2.0)
		var dark := Color(0, 0, 0, 0.72)
		_board.draw_rect(Rect2(0, 0, screen.x, rect.position.y), dark)
		_board.draw_rect(Rect2(0, rect.end.y, screen.x, screen.y - rect.end.y), dark)
		_board.draw_rect(Rect2(0, rect.position.y, rect.position.x, rect.size.y), dark)
		_board.draw_rect(Rect2(rect.end.x, rect.position.y, screen.x - rect.end.x, rect.size.y), dark)
		_board.draw_texture_rect(_torch, rect, false, Color(1, 1, 1, 0.72))
	if _flash > 0.0:
		_board.draw_rect(Rect2(Vector2.ZERO, screen), Color(1, 1, 0.9, _flash * 0.75))


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
