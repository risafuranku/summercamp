extends Node

## The gamepad (the Steam Deck; TODO.md D3, the Q&A of 15. 11.: "a translator and one way
## to write the prompts"). The game is played with keys and the mouse, and this turns a
## pad into them, so every place that takes keys and clicks takes the pad too: the one
## way a pad comes in (the engine's own pad events are taken off the ui_* actions, or a
## press would count twice). GameSettings makes it (its child "Pad").
##
## Out in the camp (the pointer captured): the left stick walks (the move actions carry it
## as an axis), the right stick turns the head as the mouse does; A use (E), B jump and
## leave (Space), X repair (R), Y the torch (F), LT run (Shift), RT the left button, L3
## crouch (Ctrl), R3 drop what is in hand (X), LB the megaphone (G), RB the radio (V), the
## cross a cigarette (C), the bottle (B), a room's light (L), Q (the guitar, a variant).
## With a pointer (the PC, the close-ups, the minigames, the menus): the left stick moves
## it, the right stick scrolls; A clicks where it points, or is Enter when the cross picked
## a row last; B is Esc, LT the right button, X still R (a room's repairs), LB/RB A and D
## (a room's last and next).
## Either way: Menu is Esc, View is Tab. With a pointer the cross is the arrows.
## `using_pad`: the last thing touched was the pad (prompt.gd shows its buttons then).

signal device_changed(using_pad: bool)

## Events made here are marked so (meta), not to be taken for the keyboard's; their device
## is the keyboard's and the mouse's (0): the actions made in code answer only that one.
const MADE := "pad"
const DEAD := 0.2
## Mouse pixels a second at full tilt (the head), window pixels a second (the pointer).
const LOOK_PX := 1300.0
const POINTER_PX := 760.0
const SCROLL_SEC := 0.11
const TRIGGER := 0.5
## What walks: the move actions and their stick axis and side.
const WALK := {"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_backward": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0]}
## A button as a key or a mouse button: [in the camp, with a pointer]. Ints are keys,
## "lmb"/"rmb" the buttons, "accept" A with a pointer (a click, or Enter after the cross).
const BUTTONS := {
	JOY_BUTTON_A: [KEY_E, "accept"],
	JOY_BUTTON_B: [KEY_SPACE, KEY_ESCAPE],
	JOY_BUTTON_X: [KEY_R, KEY_R],
	JOY_BUTTON_Y: [KEY_F, KEY_F],
	JOY_BUTTON_LEFT_SHOULDER: [KEY_G, KEY_A],
	JOY_BUTTON_RIGHT_SHOULDER: [KEY_V, KEY_D],
	JOY_BUTTON_LEFT_STICK: [KEY_CTRL, KEY_CTRL],
	JOY_BUTTON_RIGHT_STICK: [KEY_X, KEY_X],
	JOY_BUTTON_START: [KEY_ESCAPE, KEY_ESCAPE],
	JOY_BUTTON_BACK: [KEY_TAB, KEY_TAB],
	JOY_BUTTON_DPAD_UP: [KEY_C, KEY_UP],
	JOY_BUTTON_DPAD_DOWN: [KEY_B, KEY_DOWN],
	JOY_BUTTON_DPAD_LEFT: [KEY_L, KEY_LEFT],
	JOY_BUTTON_DPAD_RIGHT: [KEY_Q, KEY_RIGHT],
}
## The triggers as buttons: [in the camp, with a pointer].
const TRIGGERS := {JOY_AXIS_TRIGGER_LEFT: [KEY_SHIFT, "rmb"], JOY_AXIS_TRIGGER_RIGHT: ["lmb", "lmb"]}

var using_pad := false
## The pad that spoke last (its sticks are read).
var pad_device := -1
## What each held button or trigger was made into, released with it.
var _held: Dictionary = {}
## The cross picked a row since the pointer last moved: A is Enter.
var _rows := false
var _scroll_t := 0.0
var _look_rest := Vector2.ZERO


func _ready() -> void:
	name = "Pad"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_take_pad_off_ui()
	_walk_on_stick()


## The engine's ui_* actions answer the pad themselves (A accept, B cancel, the cross):
## with this they would answer twice.
func _take_pad_off_ui() -> void:
	for a in InputMap.get_actions():
		if not str(a).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(a, ev)


## The left stick on the move actions (their keys are the player's: player_controller).
func _walk_on_stick() -> void:
	for action in WALK:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventJoypadMotion.new()
		ev.axis = int(WALK[action][0])
		ev.axis_value = float(WALK[action][1])
		ev.device = -1
		InputMap.action_add_event(action, ev)
		InputMap.action_set_deadzone(action, DEAD)


func _set_using(on: bool) -> void:
	if on == using_pad:
		return
	using_pad = on
	device_changed.emit(on)


func _input(event: InputEvent) -> void:
	if event.has_meta(MADE):
		return
	if event is InputEventJoypadButton:
		pad_device = event.device
		_set_using(true)
		var b := event as InputEventJoypadButton
		_button(b.button_index, b.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) > DEAD:
			pad_device = event.device
			_set_using(true)
		if TRIGGERS.has(m.axis):
			_trigger(m.axis, m.axis_value)
		# (The sticks are read each frame; the walk takes its axis off the action.)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_using(false)
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 3.0:
		_set_using(false)


func _pointer_mode() -> bool:
	return Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED


func _button(index: int, pressed: bool) -> void:
	var id := "b%d" % index
	if pressed:
		if not BUTTONS.has(index):
			return
		if _pointer_mode() and index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			_rows = true
		var what = BUTTONS[index][1 if _pointer_mode() else 0]
		if typeof(what) == TYPE_STRING and what == "accept":
			what = KEY_ENTER if _rows else "lmb"
		_press(id, what)
	else:
		_release(id)


func _trigger(axis: int, value: float) -> void:
	var id := "t%d" % axis
	if value >= TRIGGER and not _held.has(id):
		_press(id, TRIGGERS[axis][1 if _pointer_mode() else 0])
	elif value < TRIGGER * 0.6 and _held.has(id):
		_release(id)


func _press(id: String, what) -> void:
	var ev := _make(what, true)
	if ev == null:
		return
	_held[id] = what
	Input.parse_input_event(ev)


func _release(id: String) -> void:
	if not _held.has(id):
		return
	var ev := _make(_held[id], false)
	_held.erase(id)
	if ev != null:
		Input.parse_input_event(ev)


## A key (an int) or a mouse button ("lmb"/"rmb") pressed or let go, where the pointer is.
func _make(what, pressed: bool) -> InputEvent:
	if typeof(what) == TYPE_INT:
		var k := InputEventKey.new()
		k.keycode = what
		k.physical_keycode = what
		k.pressed = pressed
		k.set_meta(MADE, true)
		return k
	if typeof(what) == TYPE_STRING and (what == "lmb" or what == "rmb"):
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT if what == "lmb" else MOUSE_BUTTON_RIGHT
		mb.pressed = pressed
		mb.set_meta(MADE, true)
		_place(mb)
		return mb
	return null


## A mouse event where the pointer is, in the window's pixels.
func _place(ev: InputEventMouse) -> void:
	var vp := get_viewport()
	var at := vp.get_mouse_position()
	var win := vp.get_final_transform() * at
	ev.position = win
	ev.global_position = win


func _process(delta: float) -> void:
	if pad_device < 0:
		return
	var left := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var right := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if _pointer_mode():
		_look_rest = Vector2.ZERO
		if left != Vector2.ZERO:
			_move_pointer(left * POINTER_PX * delta)
		if absf(right.y) > 0.0:
			_scroll_t -= delta
			if _scroll_t <= 0.0:
				_scroll_t = SCROLL_SEC / maxf(0.35, absf(right.y))
				_wheel(MOUSE_BUTTON_WHEEL_DOWN if right.y > 0.0 else MOUSE_BUTTON_WHEEL_UP)
		else:
			_scroll_t = 0.0
	elif right != Vector2.ZERO:
		# The head turned as the mouse turns it (whole pixels; the rest carried on).
		var rel := right * LOOK_PX * delta + _look_rest
		var whole := rel.round()
		_look_rest = rel - whole
		if whole != Vector2.ZERO:
			var mm := InputEventMouseMotion.new()
			mm.relative = whole
			mm.screen_relative = whole
			mm.set_meta(MADE, true)
			Input.parse_input_event(mm)


## A stick past its dead zone, the rest eased in (a square curve: fine near the middle).
func _stick(ax: int, ay: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(pad_device, ax), Input.get_joy_axis(pad_device, ay))
	var l := v.length()
	if l < DEAD:
		return Vector2.ZERO
	var t := clampf((l - DEAD) / (1.0 - DEAD), 0.0, 1.0)
	return v / l * t * t


func _move_pointer(by_window_px: Vector2) -> void:
	_rows = false
	var vp := get_viewport()
	var xf := vp.get_final_transform()
	var win := xf * vp.get_mouse_position() + by_window_px
	var size := Vector2(DisplayServer.window_get_size())
	win = win.clamp(Vector2.ZERO, size - Vector2.ONE)
	var at := xf.affine_inverse() * win
	vp.warp_mouse(at)
	var mm := InputEventMouseMotion.new()
	mm.position = win
	mm.global_position = win
	mm.relative = by_window_px
	mm.screen_relative = by_window_px
	mm.set_meta(MADE, true)
	Input.parse_input_event(mm)


func _wheel(button: int) -> void:
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		mb.pressed = pressed
		mb.factor = 1.0
		mb.set_meta(MADE, true)
		_place(mb)
		Input.parse_input_event(mb)
