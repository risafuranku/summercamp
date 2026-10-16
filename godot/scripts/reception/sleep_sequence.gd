extends CanvasLayer

## Going to bed in the room behind the office (scripts/reception/back_room.gd).
##
## You lie down, the lamp goes off and the little set at the foot of the bed is the only
## light; you watch it for a moment, your eyes close (a couple of heavy blinks first),
## the night passes in the dark with the clock ticking, and you wake to the alarm: the
## clock's green digits in the dark until you stop it, then the room again.
## Any key or click skips ahead: during the falling asleep straight to the alarm, at
## the alarm to waking up, while waking to standing.
##
## The host gives it the camera and the poses, and callables for the room and the clock:
##   lamp(on: bool), tv_focus(on: bool), fast_forward() (start), fast_forward_done() -> bool,
##   wake_text() -> String ("06:30"), finished()

signal finished

const SEVEN_SEG = preload("res://scripts/ui/seven_seg.gd")
const SFX := "res://assets/sfx/backroom/"
const VFD_LIT := Color(0.56, 1.0, 0.86)
const VFD_GHOST := Color(0.16, 0.3, 0.26, 0.35)

enum { IDLE, LIE, WATCH, LIDS, DARK, ALARM, WAKE }

var camera: Camera3D
var lie_pos: Vector3
var lie_rot: Vector3
var stand_pos: Vector3
var stand_rot: Vector3
var lamp: Callable
var tv_focus: Callable
var fast_forward: Callable
var fast_forward_done: Callable
var wake_text: Callable

var _phase := IDLE
var _t := 0.0
var _lids := 0.0            # 0 open .. 1 shut
var _from_pos: Vector3
var _from_rot: Vector3
var _overlay: Control
var _alarm_fade := 0.0
var _tick: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _one: AudioStreamPlayer
var _ff_started := false


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw)
	add_child(_overlay)
	_tick = _player(SFX + "clock_tick.wav", -16.0, true)
	_alarm = _player(SFX + "alarm.wav", -9.0, true)
	_one = AudioStreamPlayer.new()
	add_child(_one)
	visible = false


func _player(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	if ResourceLoader.exists(path):
		var s = load(path)
		if loop and s is AudioStreamWAV:
			s = (s as AudioStreamWAV).duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		p.stream = s
	add_child(p)
	return p


func _sfx(file: String, db := -8.0) -> void:
	if ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.volume_db = db
		_one.play()


func is_running() -> bool:
	return _phase != IDLE


func start() -> void:
	if camera == null:
		return
	visible = true
	_from_pos = camera.position
	_from_rot = camera.rotation
	_ff_started = false
	_lids = 0.0
	_enter(LIE)
	_sfx("bed_creak.wav", -6.0)


func _enter(p: int) -> void:
	_phase = p
	_t = 0.0
	match p:
		WATCH:
			if lamp.is_valid():
				lamp.call(false)
			_sfx("lamp_click.wav", -6.0)
			if tv_focus.is_valid():
				tv_focus.call(true)
		DARK:
			_tick.play()
			if not _ff_started and fast_forward.is_valid():
				_ff_started = true
				fast_forward.call()
		ALARM:
			_lids = 1.0
			camera.position = lie_pos
			camera.rotation = lie_rot
			if not _ff_started and fast_forward.is_valid():
				_ff_started = true
				fast_forward.call()
			_tick.stop()
			_alarm_fade = 0.0
		WAKE:
			_alarm.stop()
			_tick.stop()
			if tv_focus.is_valid():
				tv_focus.call(false)
			_sfx("lamp_click.wav", -10.0)


func _process(delta: float) -> void:
	if _phase == IDLE:
		return
	_t += delta
	match _phase:
		LIE:
			# Sit on the edge, then lie back, eyes on the set at the foot of the bed.
			var k := clampf(_t / 1.6, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			var mid := _from_pos.lerp(lie_pos, 0.5) + Vector3(0, -0.35, 0)
			camera.position = _from_pos.lerp(mid, e).lerp(mid.lerp(lie_pos, e), e)
			camera.rotation = Vector3(lerp_angle(_from_rot.x, lie_rot.x, e), lerp_angle(_from_rot.y, lie_rot.y, e), lerpf(_from_rot.z, lie_rot.z, e))
			if k >= 1.0:
				_enter(WATCH)
		WATCH:
			# Breathing: the view settles and drifts a hair.
			camera.rotation.x = lie_rot.x + sin(_t * 1.3) * 0.006
			if _t >= 2.8:
				_enter(LIDS)
		LIDS:
			# Heavy blinks, each closer to shut, then shut.
			var keys := [[0.0, 0.0], [0.5, 0.62], [0.8, 0.3], [1.5, 0.85], [1.85, 0.55], [2.7, 1.0]]
			_lids = _keyframes(keys, _t)
			if _t >= 3.1:
				_enter(DARK)
		DARK:
			_lids = 1.0
			var done: bool = fast_forward_done.call() if fast_forward_done.is_valid() else true
			if done and _t >= 2.4:
				_enter(ALARM)
		ALARM:
			_alarm_fade = minf(1.0, _alarm_fade + delta * 3.0)
			if _t >= 0.5 and not _alarm.playing and _t < 12.0:
				_alarm.play()
			if _t >= 12.0:
				_enter(WAKE)
		WAKE:
			# Eyes open in steps, then up off the bed.
			_lids = 1.0 - _keyframes([[0.0, 0.0], [0.4, 0.35], [0.6, 0.2], [1.0, 0.75], [1.3, 1.0]], _t)
			var k := clampf((_t - 1.1) / 1.0, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			camera.position = lie_pos.lerp(stand_pos, e)
			camera.rotation = Vector3(lerp_angle(lie_rot.x, stand_rot.x, e), lerp_angle(lie_rot.y, stand_rot.y, e), 0.0)
			if _t >= 2.2:
				_finish()
	_overlay.queue_redraw()


func _finish() -> void:
	_phase = IDLE
	_lids = 0.0
	visible = false
	camera.position = stand_pos
	camera.rotation = stand_rot
	finished.emit()


static func _keyframes(keys: Array, t: float) -> float:
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t <= float(b[0]):
			var k := clampf((t - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
			return lerpf(float(a[1]), float(b[1]), k * k * (3.0 - 2.0 * k))
	return float(keys.back()[1])


func _input(event: InputEvent) -> void:
	if _phase == IDLE:
		return
	var press: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	get_viewport().set_input_as_handled()
	if not press:
		return
	match _phase:
		LIE, WATCH, LIDS, DARK:
			_enter(ALARM)
		ALARM:
			if _t > 0.25:
				_sfx("lamp_click.wav", -4.0)
				_enter(WAKE)
		WAKE:
			_finish()


func _draw() -> void:
	var s := _overlay.size
	if _phase == ALARM or _phase == DARK:
		_overlay.draw_rect(Rect2(Vector2.ZERO, s), Color.BLACK)
		if _phase == ALARM:
			_draw_clock(s)
		return
	if _lids <= 0.001:
		return
	# Eyelids: two dark curtains with a soft (dithered) curved edge.
	var half := s.y * 0.5 * _lids
	var bulge := s.y * 0.06 * _lids
	_lid(s, half, bulge, true)
	_lid(s, half, bulge, false)


func _lid(s: Vector2, half: float, bulge: float, top: bool) -> void:
	var steps := 16
	var poly := PackedVector2Array()
	var edge := PackedVector2Array()
	for i in steps + 1:
		var x := s.x * float(i) / float(steps)
		var curve := sin(PI * float(i) / float(steps)) * bulge
		edge.append(Vector2(x, half + curve if top else s.y - half - curve))
	if top:
		poly.append(Vector2(0, 0))
		poly.append(Vector2(s.x, 0))
		for i in range(steps, -1, -1):
			poly.append(edge[i])
	else:
		poly.append(Vector2(0, s.y))
		for i in steps + 1:
			poly.append(edge[i])
		poly.append(Vector2(s.x, s.y))
	_overlay.draw_colored_polygon(poly, Color(0.02, 0.01, 0.01))
	# A thin warm band at the edge: light through the lashes.
	for i in steps:
		var a := edge[i]
		var b := edge[i + 1]
		var dy := 3.0 if top else -3.0
		_overlay.draw_line(a + Vector2(0, dy), b + Vector2(0, dy), Color(0.1, 0.04, 0.03, 0.6), 4.0)


func _draw_clock(s: Vector2) -> void:
	var text: String = wake_text.call() if wake_text.is_valid() else "06:30"
	var h := floorf(s.y * 0.2)
	var w := SEVEN_SEG.text_width(text, h)
	var pos := ((s - Vector2(w, h)) * 0.5).floor()
	# The clock's smoked window in the dark, lit only by its own digits.
	var a := _alarm_fade
	var pad := Vector2(h * 0.5, h * 0.4)
	_overlay.draw_rect(Rect2(pos - pad, Vector2(w, h) + pad * 2.0), Color(0.03, 0.05, 0.05, a))
	_overlay.draw_rect(Rect2(pos - pad, Vector2(w, h) + pad * 2.0).grow(-2), Color(0.05, 0.08, 0.075, a))
	var blink := fmod(_t, 1.0) < 0.6
	var lit := Color(VFD_LIT, a * (1.0 if blink or _t < 0.5 else 0.25))
	SEVEN_SEG.draw_text(_overlay, pos, h, text, lit, Color(VFD_GHOST, VFD_GHOST.a * a), true)
	# AL and the PM dot, small.
	var small := floorf(h * 0.12)
	_overlay.draw_rect(Rect2(pos + Vector2(-pad.x * 0.6, h * 0.1), Vector2(small, small)), Color(VFD_LIT, a * 0.9))
	var font := _overlay.get_theme_default_font()
	_overlay.draw_string(font, pos + Vector2(-pad.x * 0.6 + small * 1.6, h * 0.1 + small), "AL", HORIZONTAL_ALIGNMENT_LEFT, -1, int(small * 1.4), Color(VFD_LIT, a * 0.8))
