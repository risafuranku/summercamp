extends RefCounted

## A local client's input (TODO.md SPLITSCREEN I5): Godot's Input is one per program, the
## host's. A local client's instance keeps its own: the keys, the mouse buttons and the
## actions its own pad's made events said (scripts/input/pad.gd pushes them into the
## client's screen and feeds them here), its mouse mode and its pointer (drawn on its screen,
## the window's mouse is the host's). The same calls as Input's, so code asks
## INSTANCE.input(self) and gets either.

var mouse_mode := Input.MOUSE_MODE_VISIBLE
## The pointer on the client's screen, in its pixels.
var pointer := Vector2.ZERO
## The pad that is this instance's (its sticks are read from Input by device: per pad).
var device := -1
var _physical: Dictionary = {}
var _keys: Dictionary = {}
var _buttons: Dictionary = {}
var _actions: Dictionary = {}
var _pressed_frame: Dictionary = {}
var _released_frame: Dictionary = {}


## One of its events (pushed into its screen as well): what is held now.
func feed(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null:
		if key.physical_keycode != KEY_NONE:
			_hold(_physical, key.physical_keycode, key.pressed)
		if key.keycode != KEY_NONE:
			_hold(_keys, key.keycode, key.pressed)
	var mb := event as InputEventMouseButton
	if mb != null:
		_hold(_buttons, mb.button_index, mb.pressed)
		pointer = mb.position
	var mm := event as InputEventMouseMotion
	if mm != null and mouse_mode != Input.MOUSE_MODE_CAPTURED:
		pointer = mm.position
	if key == null and mb == null:
		return
	if key != null and key.echo:
		return
	for action in InputMap.get_actions():
		if InputMap.event_is_action(event, action, true):
			var was := bool(_actions.get(action, false))
			var now := event.is_pressed()
			_actions[action] = now
			if now and not was:
				_pressed_frame[action] = Engine.get_process_frames()
			elif was and not now:
				_released_frame[action] = Engine.get_process_frames()


func _hold(d: Dictionary, k: int, on: bool) -> void:
	if on:
		d[k] = true
	else:
		d.erase(k)


func set_mouse_mode(mode: Input.MouseMode) -> void:
	mouse_mode = mode


func get_mouse_mode() -> Input.MouseMode:
	return mouse_mode


func is_physical_key_pressed(key: Key) -> bool:
	return _physical.has(key)


func is_key_pressed(key: Key) -> bool:
	return _keys.has(key)


func is_mouse_button_pressed(button: MouseButton) -> bool:
	return _buttons.has(button)


func is_action_pressed(action: StringName, _exact := false) -> bool:
	return bool(_actions.get(action, false))


func is_action_just_pressed(action: StringName, _exact := false) -> bool:
	return int(_pressed_frame.get(action, -1)) == Engine.get_process_frames()


func is_action_just_released(action: StringName, _exact := false) -> bool:
	return int(_released_frame.get(action, -1)) == Engine.get_process_frames()


func get_action_strength(action: StringName, exact := false) -> float:
	return 1.0 if is_action_pressed(action, exact) else 0.0


func get_axis(negative: StringName, positive: StringName) -> float:
	return get_action_strength(positive) - get_action_strength(negative)


## The walk: its pad's left stick (the move actions' keys are the host's keyboard).
func get_vector(negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName, deadzone := -1.0) -> Vector2:
	var v := Vector2(get_axis(negative_x, positive_x), get_axis(negative_y, positive_y))
	if device >= 0:
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		var dz := deadzone if deadzone >= 0.0 else 0.2
		if stick.length() > dz:
			v = stick.limit_length(1.0)
	return v.limit_length(1.0)


func get_joy_axis(pad: int, axis: JoyAxis) -> float:
	return Input.get_joy_axis(pad if pad >= 0 else device, axis)


func is_joy_button_pressed(pad: int, button: JoyButton) -> bool:
	return Input.is_joy_button_pressed(pad if pad >= 0 else device, button)


func warp_mouse(position: Vector2) -> void:
	pointer = position
