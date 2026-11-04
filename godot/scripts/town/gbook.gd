extends CanvasLayer

## The Hruska gBook, the laptop on the desk in the motel's room eleven (the user, 4. 11.: "a
## notebook with no camp programs, you cannot even install them, you have no admin rights;
## another OS look than the camp's, a gBook, a wannabe MacBook of the nineties"). Clicked,
## the close-up comes up: the open machine (Grok, tools/artgen/gbook_art.py) with its own
## system gOS behind the hole in the picture, drawn small in a SubViewport (gbook_os.gd)
## and scaled by whole numbers, the picture's pixels the screen's.
##
##     var book = load("res://scripts/town/gbook.gd").new()
##     room.add_child(book)
##     book.closed.connect(...)
##     book.open_for(room)        # room: town_room.gd, open
##
## Keep the one node: left with Esc, a right click off the screen or a click on the bottom
## edge, it sleeps with its windows open and wakes at once. Esc goes a step at a time, as
## everywhere (AGENTS.md): an open menu or one of the system's boxes first, then the
## machine. Shut Down in the pear menu ends the close-up and the next open starts it from
## cold. P and F10 are the pause menu's, P a letter while gOS takes words (_typing), and
## the room's closing ends this whichever way it goes.

signal closed

const OS_SCRIPT = preload("res://scripts/town/gbook_os.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const PIC := "res://assets/textury/gbook/laptop.png"
const SFX := "res://assets/sfx/gbook/"
## The hole in the picture: exactly the screen's pixels at scale 1 (gbook_art.py).
const HOLE_AT := Vector2i(140, 36)
const PIC_SIZE := Vector2i(680, 383)
## The screen's middle in the window: a little over the window's, for the bezel under it.
const SCREEN_MID := Vector2(0.5, 0.455)
## file, dB, through the speaker (the Sound panel's volume) or the case's own.
const SOUNDS := {
	"chord": ["chord.mp3", -7.0, true],
	"alert_clonk": ["alert_clonk.mp3", -7.0, true],
	"alert_drip": ["alert_drip.mp3", -7.0, true],
	"alert_pip": ["alert_pip.mp3", -7.0, true],
	"click_down": ["click_down.wav", -16.0, false],
	"click_up": ["click_up.wav", -18.0, false],
	"key_down": ["key_down.wav", -15.0, false],
	"key_up": ["key_up.wav", -19.0, false],
	"power": ["power.wav", -10.0, false],
	"spinup": ["spinup.wav", -12.0, false],
	"seek_a": ["seek_a.mp3", -16.0, false],
	"seek_b": ["seek_b.mp3", -16.0, false],
}
const FAN := "fan.ogg"
const FAN_DB := -27.0
const LCD := """
shader_type canvas_item;
uniform vec2 os_size = vec2(400.0, 270.0);
uniform float px = 2.0;
uniform float lit = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * os_size;
	vec2 cell = floor(p);
	vec3 c = texture(TEXTURE, (cell + 0.5) / os_size).rgb;
	// A cheap passive panel of the nineties: the black never quite black, the white cold.
	c = mix(vec3(0.07, 0.08, 0.085), c, 0.9) * vec3(0.93, 0.965, 0.98);
	// The gap round every pixel of it, its uneven columns and grain (fixed: nothing moves).
	vec2 f = fract(p);
	float edge = 1.0 - 1.0 / max(px, 1.0);
	float gap = (px >= 2.0 && (f.x >= edge || f.y >= edge)) ? 0.87 : 1.0;
	float grain = (hash(cell) - 0.5) * 0.03 + (hash(vec2(cell.x, 3.0)) - 0.5) * 0.02;
	// The tube behind it runs along the bottom, the corners stay dimmer.
	vec2 q = UV - 0.5;
	float tube = 1.0 - dot(q, q) * 0.38 + (UV.y - 0.5) * 0.07;
	vec3 o = (c + grain) * gap * tube;
	COLOR = vec4(mix(vec3(0.028, 0.032, 0.03), o, lit), 1.0);
}
"""

var _room
var _back: ColorRect
var _pic: TextureRect
var _screen: TextureRect
var _lcd: ShaderMaterial
var _vp: SubViewport
var _os
var _scale := 2
var _open_t := 0.0
var _lit := 0.0
var _held := false
var _idle := 30.0
var _speaker: AudioStreamPlayer
var _case: Array = []
var _next_case := 0
var _fan: AudioStreamPlayer
var _fan_on := false
var _streams: Dictionary = {}
## gOS's fields are only drawn: while it takes words this one, off the window, holds the
## focus, so main._keyboard_taken() leaves the letter P to them.
var _typing: LineEdit


func _init() -> void:
	# Where the close-ups are (closeup_view): over the HUD's strips, under the pause menu.
	layer = 95
	visible = false


func _ready() -> void:
	add_to_group("closeup")
	_back = ColorRect.new()
	_back.color = Color(0, 0, 0)
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_vp = SubViewport.new()
	_vp.size = Vector2i(OS_SCRIPT.W, OS_SCRIPT.H)
	_vp.disable_3d = true
	_vp.gui_disable_input = true
	_vp.snap_2d_transforms_to_pixel = true
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_os = OS_SCRIPT.new()
	_os.host = self
	_vp.add_child(_os)
	_lcd = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LCD
	_lcd.shader = sh
	_lcd.set_shader_parameter("os_size", Vector2(OS_SCRIPT.W, OS_SCRIPT.H))
	_screen = TextureRect.new()
	_screen.texture = _vp.get_texture()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.material = _lcd
	add_child(_screen)
	_pic = TextureRect.new()
	_pic.texture = load(PIC) if ResourceLoader.exists(PIC) else null
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pic)
	_speaker = AudioStreamPlayer.new()
	add_child(_speaker)
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_case.append(p)
	_fan = AudioStreamPlayer.new()
	add_child(_fan)
	# All of it now, nothing at the first click.
	for k in SOUNDS:
		var path: String = SFX + str(SOUNDS[k][0])
		if ResourceLoader.exists(path):
			_streams[k] = load(path)
	if ResourceLoader.exists(SFX + FAN):
		_fan.stream = load(SFX + FAN)
	_fan.volume_db = FAN_DB
	_typing = LineEdit.new()
	_typing.position = Vector2(-64, -64)
	_typing.size = Vector2(8, 8)
	_typing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_typing.context_menu_enabled = false
	add_child(_typing)
	get_tree().root.size_changed.connect(_layout)


func is_open() -> bool:
	return visible


## Up from the desk: `room` the open place (town_room.gd), whose input stops while this is
## visible. The first time it starts up; asleep, it wakes.
func open_for(room) -> void:
	if visible:
		return
	_room = room
	if room != null and is_instance_valid(room):
		if room.has_method("add_overlay"):
			room.add_overlay(self)
		if room.has_signal("closed") and not room.closed.is_connected(_on_room_closed):
			room.closed.connect(_on_room_closed)
	visible = true
	_open_t = 0.0
	_lit = 0.0
	_held = false
	_layout()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_fan_start()
	sound("power")
	if _os.state != OS_SCRIPT.READY:
		_os.power_on()
	_os.dirty = true


func _on_room_closed() -> void:
	if visible:
		leave()


## The lid left up and the machine asleep (or, while it was still starting, off).
func leave() -> void:
	if not visible:
		return
	visible = false
	_typing.release_focus()
	_os.power_cut()
	_fan.stop()
	_fan_on = false
	_speaker.stop()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	closed.emit()


func _fan_start() -> void:
	if not _fan_on and _fan.stream != null:
		_fan_on = true
		_fan.play()


# ── what gOS asks of its machine ─────────────────────────────────────────────

func sound(kind: String) -> void:
	if not _streams.has(kind):
		return
	var row: Array = SOUNDS[kind]
	var db := float(row[1])
	if bool(row[2]):
		if int(_os.volume) <= 0:
			return
		_speaker.stream = _streams[kind]
		_speaker.volume_db = db + linear_to_db(float(_os.volume) / 7.0)
		_speaker.play()
		return
	var p: AudioStreamPlayer = _case[_next_case]
	_next_case = (_next_case + 1) % _case.size()
	p.stream = _streams[kind]
	p.volume_db = db
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()


func hour() -> float:
	if _room != null and is_instance_valid(_room):
		var trip = _room.get_parent()
		if trip != null and trip.has_method("hour"):
			return float(trip.hour())
	return 12.0


func day() -> int:
	return CoreRoot.get_day()


## Shut Down: the drive stops, the fan with it, then the close-up ends.
func powered_down() -> void:
	leave()


func going_down() -> void:
	sound("power")
	_fan.stop()
	_fan_on = false


func restarted() -> void:
	_fan_start()
	sound("power")
	_os.power_on()


# ── every frame ──────────────────────────────────────────────────────────────

func _layout() -> void:
	if get_viewport() == null or _pic == null:
		return
	var win := get_viewport().get_visible_rect().size
	if win.x <= 0.0:
		return
	var os_px := Vector2(OS_SCRIPT.W, OS_SCRIPT.H)
	_scale = maxi(1, int(floorf(minf(win.y * 0.9 / os_px.y, win.x * 0.9 / os_px.x))))
	var size := os_px * float(_scale)
	var at := ((win * SCREEN_MID) - size * 0.5).round()
	_screen.position = at
	_screen.size = size
	_pic.size = Vector2(PIC_SIZE) * float(_scale)
	_pic.position = at - Vector2(HOLE_AT) * float(_scale)
	_lcd.set_shader_parameter("px", float(_scale))


func _process(delta: float) -> void:
	if not visible:
		return
	_open_t += delta
	var k := clampf(floorf(_open_t / 0.05) / 4.0, 0.0, 1.0)
	_pic.modulate = Color(k, k, k)
	_os.tick(delta)
	_lit = move_toward(_lit, 1.0 if _os.panel_lit() else 0.0, delta * 6.0)
	_lcd.set_shader_parameter("lit", floorf(_lit * 5.0) / 5.0)
	if _os.dirty:
		_os.dirty = false
		_os.queue_redraw()
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Now and then the drive by itself, as they do.
	_idle -= delta
	if _idle <= 0.0:
		_idle = randf_range(18.0, 55.0)
		if _os.state == OS_SCRIPT.READY:
			sound("seek_b")
	var words: bool = _os.wants_keys()
	if words != _typing.has_focus():
		if words:
			_typing.grab_focus()
		else:
			_typing.release_focus()
	# The machine's pointer over its screen, the glove off it.
	if HandCursor.menu_over or get_tree().paused:
		return
	var m := get_viewport().get_mouse_position()
	if _on_screen(m) or _held:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		HandCursor.want(HandCursor.WALK if _in_exit_band(m) else HandCursor.ARROW)


func _on_screen(p: Vector2) -> bool:
	return Rect2(_screen.position, _screen.size).has_point(p)


func _in_exit_band(p: Vector2) -> bool:
	return p.y >= get_viewport().get_visible_rect().size.y * (1.0 - INTERIOR_LOOK.EXIT_BAND)


## A window point to the screen's pixel, kept on the screen.
func _to_os(p: Vector2) -> Vector2i:
	var q := (p - _screen.position) / float(_scale)
	return Vector2i(clampi(int(q.x), 0, OS_SCRIPT.W - 1), clampi(int(q.y), 0, OS_SCRIPT.H - 1))


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused or HandCursor.menu_over:
		return
	# Esc leaves, a step at a time: what is open on the screen, then the machine.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _os.escape():
			leave()
		return
	if event is InputEventMouse:
		_mouse(event as InputEventMouse)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		_key(event as InputEventKey)
		get_viewport().set_input_as_handled()


func _mouse(event: InputEventMouse) -> void:
	var at := _to_os(event.position)
	var inside := _on_screen(event.position)
	if event is InputEventMouseMotion:
		if inside or _held:
			_os.move_to(at)
		return
	var mb := event as InputEventMouseButton
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_os.wheel(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		MOUSE_BUTTON_LEFT:
			if mb.pressed and not inside:
				if _in_exit_band(event.position):
					leave()
				return
			if not mb.pressed and not _held:
				return
			_held = mb.pressed
			_os.move_to(at)
			_os.mouse(at, mb.pressed)
		MOUSE_BUTTON_RIGHT:
			if mb.pressed and not inside:
				leave()


func _key(ev: InputEventKey) -> void:
	if not ev.echo:
		sound("key_down" if ev.pressed else "key_up")
	_os.key(ev)


# ── for the shot driver's steps (no real mouse there) ────────────────────────

func debug_at(x: int, y: int) -> void:
	_os.move_to(Vector2i(x, y))


func debug_click(x: int, y: int) -> void:
	var p := Vector2i(x, y)
	_os.move_to(p)
	_os.mouse(p, true)
	_os.mouse(p, false)


func debug_double(x: int, y: int) -> void:
	debug_click(x, y)
	debug_click(x, y)


func debug_press(x: int, y: int, down: bool) -> void:
	var p := Vector2i(x, y)
	_os.move_to(p)
	_os.mouse(p, down)


## The front window's corner pulled to (x, y).
func debug_grow(x: int, y: int) -> void:
	var g: Vector2i = _os.front().grow_box().position + Vector2i(4, 4)
	debug_press(g.x, g.y, true)
	_os.move_to(Vector2i(x, y))
	debug_press(x, y, false)


func debug_type(text: String) -> void:
	for ch in text:
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = ch.unicode_at(0)
		_os.key(ev)


func debug_key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code as Key
	_os.key(ev)


func debug_cmd(cmd: String) -> void:
	_os._run(cmd)


func debug_open(id: String) -> void:
	_os.open_item(id)


func debug_skip_boot() -> void:
	_os._boot_t = OS_SCRIPT.BOOT_END - 0.01
	_os._cue = OS_SCRIPT.BOOT_CUES.size()
