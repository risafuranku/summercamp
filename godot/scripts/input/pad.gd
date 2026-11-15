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
## A screen with keys of its own (a business's stations, the pipes) says which buttons
## stand for them while it is shown: screen_keys().
## `using_pad`: the last thing touched was the pad (prompt.gd shows its buttons then).
## rumble(): the body's knocks in the hands (the player's hurt and the ground shaking).
## A split screen (scripts/seats/seats.gd): another pad's Menu out in the camp asks
## `join_handler` for seat 2; that pad is then the seat's own (read straight from it,
## scripts/seats/seat_pad.gd) and this translator leaves it alone till release().

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
	JOY_BUTTON_LEFT_SHOULDER: ["@megaphone_talk", KEY_A],
	JOY_BUTTON_RIGHT_SHOULDER: ["@radio_talk", KEY_D],
	JOY_BUTTON_LEFT_STICK: [KEY_CTRL, KEY_CTRL],
	JOY_BUTTON_RIGHT_STICK: [KEY_X, KEY_X],
	JOY_BUTTON_START: [KEY_ESCAPE, KEY_ESCAPE],
	JOY_BUTTON_BACK: [KEY_TAB, KEY_TAB],
	JOY_BUTTON_DPAD_UP: [KEY_C, KEY_UP],
	JOY_BUTTON_DPAD_DOWN: [KEY_B, KEY_DOWN],
	JOY_BUTTON_DPAD_LEFT: [KEY_L, KEY_LEFT],
	JOY_BUTTON_DPAD_RIGHT: [KEY_Q, KEY_RIGHT],
}
## The keys the warden may change (GameSettings.REBINDABLE), "@action" above: the button
## stands for whatever key it has now.
const ACTIONS := {"megaphone_talk": JOY_BUTTON_LEFT_SHOULDER, "radio_talk": JOY_BUTTON_RIGHT_SHOULDER}
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
## [[screen, {JOY_BUTTON_*: KEY_*}]], the newest last.
var _screens: Array = []
var _rumble_at := -99.0
var _rumble_power := 0.0
## A pad another seat has: {device: seat}.
var _claimed: Dictionary = {}
## The walk's stick events on the move actions (their device follows pad_device).
var _walk_events: Array = []
## Asked when a pad not seat 1's presses Menu: (device) -> true when it took a seat.
var join_handler: Callable


## The pad is nobody's seat any more (it left): seat 1's translator may have it again.
func release(device: int) -> void:
	_claimed.erase(device)


func claimed(device: int) -> bool:
	return _claimed.has(device)


## The pad's node (GameSettings makes it); null before.
static func node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameSettings/Pad") if tree != null else null


## The pad shaken in the hands, while it is the pad in use: the light and the heavy motor
## (0..1) for `sec`. A stronger one cuts over a weaker one still going.
func rumble(weak: float, strong: float, sec: float) -> void:
	if not using_pad or pad_device < 0 or maxf(weak, strong) < 0.05:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var left := Input.get_joy_vibration_duration(pad_device) - (now - _rumble_at)
	if left > 0.0 and maxf(weak, strong) < _rumble_power:
		return
	_rumble_at = now
	_rumble_power = maxf(weak, strong)
	Input.start_joy_vibration(pad_device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), sec)


## While `screen` is in the tree and shown, these buttons stand for its keys (the rest as
## everywhere). Called once (its _ready); it is let go when it is freed.
func screen_keys(screen: Node, keys: Dictionary) -> void:
	for i in range(_screens.size() - 1, -1, -1):
		if not is_instance_valid(_screens[i][0]) or _screens[i][0] == screen:
			_screens.remove_at(i)
	_screens.append([screen, keys])


## The keys of the screen shown now (the newest), {} for none.
func shown_screen_keys() -> Dictionary:
	for i in range(_screens.size() - 1, -1, -1):
		var screen = _screens[i][0]
		if not is_instance_valid(screen):
			_screens.remove_at(i)
			continue
		if _shown(screen):
			return _screens[i][1]
	return {}


func _shown(screen: Node) -> bool:
	if not screen.is_inside_tree() or not bool(screen.get("visible")):
		return false
	return not (screen is CanvasItem) or (screen as CanvasItem).is_visible_in_tree()


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


## The left stick on the move actions (their keys are the player's: player_controller):
## any pad's until one is used, then that pad's alone (a second pad is another seat's).
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
		_walk_events.append(ev)


## The pad that speaks for the window's warden now: its sticks, its walk.
func _set_pad_device(device: int) -> void:
	if device == pad_device:
		return
	pad_device = device
	for ev in _walk_events:
		(ev as InputEventJoypadMotion).device = device


func _set_using(on: bool) -> void:
	if on == using_pad:
		return
	using_pad = on
	device_changed.emit(on)


func _input(event: InputEvent) -> void:
	if event.has_meta(MADE):
		return
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and _claimed.has(event.device):
		return
	if event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		if b.pressed and b.button_index == JOY_BUTTON_START and pad_device >= 0 and event.device != pad_device 				and join_handler.is_valid() and bool(join_handler.call(event.device)):
			_claimed[event.device] = 2
			get_viewport().set_input_as_handled()
			return
		_set_pad_device(event.device)
		_set_using(true)
		_button(b.button_index, b.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) > DEAD:
			_set_pad_device(event.device)
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
		var own: Dictionary = shown_screen_keys()
		if not BUTTONS.has(index) and not own.has(index):
			return
		var what = own[index] if own.has(index) else BUTTONS[index][1 if _pointer_mode() else 0]
		if _pointer_mode() and typeof(what) == TYPE_INT and what in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_rows = true
		if typeof(what) == TYPE_STRING and what.begins_with("@"):
			what = GameSettings.get_key(what.substr(1))
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
	# (Never two keys down for one button: what it held goes up first.)
	_release(id)
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


## Where the stick last put the pointer, in the window's pixels (tools/pad_check reads it:
## the PC's own mouse moving over the window is not the pad's doing).
var pointer_at := Vector2(-1, -1)


func _move_pointer(by_window_px: Vector2) -> void:
	_rows = false
	var vp := get_viewport()
	var xf := vp.get_final_transform()
	var win := xf * vp.get_mouse_position() + by_window_px
	var size := Vector2(DisplayServer.window_get_size())
	win = win.clamp(Vector2.ZERO, size - Vector2.ONE)
	pointer_at = win
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
