extends RefCounted

## A seat's own pad (TODO.md SPLITSCREEN): a warden whose input is not the window's (the
## keys, the mouse and the translator in scripts/input/pad.gd are seat 1's) reads its pad
## straight from the device. Out in the camp, as pad.gd has it: the left stick walks, the
## right stick turns the head, B jumps, LT runs, L3 crouches, Y the torch, A uses, RT the
## hands, Menu the menu (held: leave the seat).
##   var pad = SEAT_PAD.new(device); pad.poll() once a physics frame; pad.just_pressed(...)

const DEAD := 0.2
## The head's turn at full tilt, in mouse pixels a second (pad.gd LOOK_PX: the same feel).
const LOOK_PX := 1300.0
const TRIGGER := 0.5
const BUTTONS := {
	"move_jump": JOY_BUTTON_B,
	"toggle_flashlight": JOY_BUTTON_Y,
	"move_crouch": JOY_BUTTON_LEFT_STICK,
	"interact": JOY_BUTTON_A,
	"menu": JOY_BUTTON_START,
	"drop": JOY_BUTTON_RIGHT_STICK,
}
const TRIGGERS := {"move_sprint": JOY_AXIS_TRIGGER_LEFT, "use": JOY_AXIS_TRIGGER_RIGHT}

var device := -1
var _down: Dictionary = {}
var _was: Dictionary = {}
var _polled := -1
var _look_rest := Vector2.ZERO


func _init(pad_device: int) -> void:
	device = pad_device


## What is held now and what was held the step before (once a physics frame; a second call
## in the same frame changes nothing).
func poll() -> void:
	var f := Engine.get_physics_frames()
	if f == _polled:
		return
	_polled = f
	_was = _down.duplicate()
	for a in BUTTONS:
		_down[a] = Input.is_joy_button_pressed(device, BUTTONS[a])
	for a in TRIGGERS:
		var v := Input.get_joy_axis(device, TRIGGERS[a])
		_down[a] = v >= TRIGGER or (bool(_was.get(a, false)) and v >= TRIGGER * 0.6)


func held(action: String) -> bool:
	return bool(_down.get(action, false))


func just_pressed(action: String) -> bool:
	return bool(_down.get(action, false)) and not bool(_was.get(action, false))


func just_released(action: String) -> bool:
	return not bool(_down.get(action, false)) and bool(_was.get(action, false))


## The walk: the left stick past its dead zone, eased in (as the move actions are read).
func move_vector() -> Vector2:
	return _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, false)


## The head's turn this frame, in mouse pixels (the player turns by it as by the mouse).
func look(delta: float) -> Vector2:
	var right := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, true)
	if right == Vector2.ZERO:
		_look_rest = Vector2.ZERO
		return Vector2.ZERO
	var rel := right * LOOK_PX * delta + _look_rest
	var whole := rel.round()
	_look_rest = rel - whole
	return whole


func _stick(ax: int, ay: int, curved: bool) -> Vector2:
	var v := Vector2(Input.get_joy_axis(device, ax), Input.get_joy_axis(device, ay))
	var l := v.length()
	if l < DEAD:
		return Vector2.ZERO
	var t := clampf((l - DEAD) / (1.0 - DEAD), 0.0, 1.0)
	return v / l * (t * t if curved else t)
