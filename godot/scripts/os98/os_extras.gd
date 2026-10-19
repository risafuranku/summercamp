extends Control

## The screen saver of the camp computer (scripts/os98/os_shell.gd owns the panel):
## after the wait with nobody at the keyboard, Flying Okna (the logo coming at you out of
## the dark) or Starfield. You see it from across the office, too. Any key or the mouse
## wakes the panel. Display Properties (scripts/os98/apps/display_app.gd) picks it.

const T = preload("res://scripts/os98/os_theme.gd")
const LOGO := "res://assets/textury/os98/okna_logo_small.png"
const SAVERS := ["Flying Okna", "Starfield", "Blank Screen", "(None)"]

var shell
var saver := "Flying Okna"
## Seconds of nobody at the computer. It never comes on while you sit at it (playtest
## 2026-10-17: it came on while reading and got in the way); only an empty desk gets it.
var saver_wait := 120.0
var _idle := 0.0
var _saving := false
var _stars: Array = []
var _logos: Array = []
var _logo_tex: Texture2D
var _drawn := false


func setup(shell_node) -> void:
	shell = shell_node
	size = shell.SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_tex = load(LOGO) if ResourceLoader.exists(LOGO) else null
	_reset_saver_field()


func export_state() -> Dictionary:
	return {"saver": saver, "saver_wait": saver_wait}


func import_state(d: Dictionary) -> void:
	saver = str(d.get("saver", saver))
	saver_wait = maxf(60.0, float(d.get("saver_wait", saver_wait)))


## Somebody touched the keyboard or the mouse.
func poke() -> void:
	_idle = 0.0
	if _saving:
		_saving = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()


func is_saving() -> bool:
	return _saving


func _process(delta: float) -> void:
	if shell == null:
		return
	if shell.is_desktop_ready():
		# Somebody is at it: no saver, and the wait starts again when they get up.
		_idle = 0.0 if shell.is_open() else _idle + delta
		# Never while somebody sits at it, however they got there (playtest 2026-10-17:
		# it blocked the game a second time): sitting down is touching the mouse.
		if _saving and shell.is_open():
			poke()
		if not _saving and saver != "(None)" and _idle >= saver_wait:
			_saving = true
			mouse_filter = Control.MOUSE_FILTER_STOP
			_reset_saver_field()
	if _saving:
		_tick_saver(delta)
		move_to_front()
		queue_redraw()
		_drawn = true
	elif _drawn:
		# One more frame to wipe the last picture.
		_drawn = false
		queue_redraw()


func _draw() -> void:
	if _saving:
		_draw_saver()


func _reset_saver_field() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 98
	_stars.clear()
	for i in 90:
		_stars.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(0.1, 1.0)))
	_logos.clear()
	for i in 14:
		_logos.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(0.1, 1.0)))


func _tick_saver(delta: float) -> void:
	var speed := 0.32 if saver == "Flying Okna" else 0.5
	var field: Array = _logos if saver == "Flying Okna" else _stars
	for i in field.size():
		var p: Vector3 = field[i]
		p.z -= delta * speed
		if p.z <= 0.02:
			p = Vector3(randf_range(-1, 1), randf_range(-1, 1), 1.0)
		field[i] = p


func _draw_saver() -> void:
	var s: Vector2 = shell.SCREEN
	draw_rect(Rect2(Vector2.ZERO, s), Color.BLACK)
	if saver == "Blank Screen":
		return
	var c := s * 0.5
	if saver == "Starfield":
		for p: Vector3 in _stars:
			var q := c + Vector2(p.x, p.y) / p.z * 220.0
			var b := clampf(1.2 - p.z, 0.2, 1.0)
			var px := 2.0 if p.z < 0.35 else 1.0
			draw_rect(Rect2(q.floor(), Vector2(px, px)), Color(b, b, b))
		return
	# Flying Okna: the four-pane window logo coming out of the dark, far ones first.
	var sorted := _logos.duplicate()
	sorted.sort_custom(func(a, b): return a.z > b.z)
	for p: Vector3 in sorted:
		var q := c + Vector2(p.x, p.y) / p.z * 200.0
		var sz := 26.0 / p.z
		var a := clampf((1.0 - p.z) * 1.6, 0.0, 1.0)
		if _logo_tex != null:
			draw_texture_rect(_logo_tex, Rect2(q - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, a))
		else:
			var cols := [Color8(220, 40, 30), Color8(40, 170, 60), Color8(40, 90, 220), Color8(240, 200, 30)]
			for k in 4:
				var o: Vector2 = Vector2(k % 2, k / 2) * sz * 0.5
				draw_rect(Rect2(q - Vector2(sz, sz) * 0.5 + o, Vector2(sz, sz) * 0.46), Color(cols[k], a))
