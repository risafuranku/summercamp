extends "res://tools/shot_driver.gd"

## The gamepad (scripts/input/pad.gd; TODO.md D3): a new camp played with pad events sent
## as a pad would (device 0). At the desk the left stick moves the pointer and B stands you
## up; out in the camp the right stick turns the head, the left stick walks, Y lights the
## torch, Menu opens the pause menu and B shuts it; the prompts show the pad's buttons
## after it is touched and the keys' after a key; a screen with keys of its own (a station's,
## the pipes': pad.gd screen_keys) has the cross as its keys while shown, and its prompts
## name them by their buttons; a hit shakes the pad. Prints "PAD ok|FAIL ..." and "PAD: PASS".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/pad_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('PadCheck')"

var _fails := 0
var _mark: Dictionary = {}
## The keys the pad made, as they came.
var _made: Array = []
var _screen: CanvasLayer


func _ready() -> void:
	super._ready()
	name = "PadCheck"
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 12.0],
		# The desk: the pointer on the left stick.
		["eval", C + ".mark_pointer()"], ["pad_axis", JOY_AXIS_LEFT_X, 1.0], ["wait", 0.6], ["pad_axis", JOY_AXIS_LEFT_X, 0.0], ["wait", 0.2],
		["eval", C + ".check_pointer_moved()"], ["shot", "p0_desk_pointer"],
		["pad_button", JOY_BUTTON_B], ["wait", 2.0], ["eval", C + ".check('B stands you up from the PC', not _is_crt_desktop_active())"],
		["eval", "_interior_manager.close_everything(true)"], ["wait", 1.5],
		# Out in the camp.
		["eval", C + ".mark_player()"], ["pad_axis", JOY_AXIS_RIGHT_X, 1.0], ["wait", 0.5], ["pad_axis", JOY_AXIS_RIGHT_X, 0.0], ["wait", 0.2],
		["eval", C + ".check_turned()"],
		["eval", C + ".mark_player()"], ["pad_axis", JOY_AXIS_LEFT_Y, -1.0], ["wait", 1.0], ["pad_axis", JOY_AXIS_LEFT_Y, 0.0], ["wait", 0.3],
		["eval", C + ".check_walked()"], ["shot", "p1_walked"],
		["eval", C + ".check('the pad is the device', get_node('/root/GameSettings/Pad').using_pad)"],
		["eval", C + ".check_prompt(true)"], ["eval", C + ".check_hint(true)"],
		["eval", C + ".mark_torch()"], ["pad_button", JOY_BUTTON_Y], ["wait", 0.5], ["eval", C + ".check_torch()"],
		# A screen's own keys: the cross's left is its Q while it is up, the camp's L after.
		["eval", C + ".screen_up(true)"], ["eval", C + ".clear_made()"], ["pad_button", JOY_BUTTON_DPAD_LEFT, 0.4], ["wait", 0.1],
		["eval", C + ".check_made(%d, 'the cross is a shown screen own key (Q)')" % KEY_Q], ["wait", 0.8],
		["eval", C + ".check_swap('[Q] Station', '[LEFT] Station')"],
		["eval", C + ".screen_up(false)"], ["eval", C + ".clear_made()"], ["pad_button", JOY_BUTTON_DPAD_LEFT, 0.4], ["wait", 0.1],
		["eval", C + ".check_made(%d, 'the screen gone, the cross is the camp again (L)')" % KEY_L], ["wait", 0.8],
		["eval", C + ".check_swap('Back   [Esc]', 'Back   [MENU]')"],
		# A hit: the pad shakes.
		["eval", "_set_player_health(_player_health - 12)"], ["eval", C + ".check_rumble()"], ["wait", 1.0],
		["pad_button", JOY_BUTTON_START], ["wait", 1.0], ["eval", C + ".check('Menu opens the pause menu', _pause_menu != null and _pause_menu.is_open())"], ["shot", "p2_pause"],
		["pad_button", JOY_BUTTON_START], ["wait", 1.0], ["eval", C + ".check('Menu again shuts it', _pause_menu == null or not _pause_menu.is_open())"],
		["key_tap", KEY_W], ["wait", 0.3], ["eval", C + ".check('a key makes the keyboard the device', not get_node('/root/GameSettings/Pad').using_pad)"],
		["eval", C + ".check_prompt(false)"], ["eval", C + ".check_hint(false)"],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]


func _run_step(step: Array) -> void:
	match str(step[0]):
		"pad_axis":
			var m := InputEventJoypadMotion.new()
			m.device = 0
			m.axis = int(step[1])
			m.axis_value = float(step[2])
			Input.parse_input_event(m)
		"pad_button":
			# Held a moment, as a thumb holds it (pressed and let go in one frame, an action
			# polled each frame never sees it).
			var b := InputEventJoypadButton.new()
			b.device = 0
			b.button_index = int(step[1])
			b.pressed = true
			Input.parse_input_event(b)
			get_tree().create_timer(float(step[2]) if step.size() > 2 else 0.15).timeout.connect(func() -> void:
				var up := b.duplicate() as InputEventJoypadButton
				up.pressed = false
				Input.parse_input_event(up))
		"key_tap":
			for pressed in [true, false]:
				var k := InputEventKey.new()
				k.keycode = int(step[1])
				k.physical_keycode = int(step[1])
				k.pressed = pressed
				Input.parse_input_event(k)
		_:
			super._run_step(step)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.has_meta("pad"):
		_made.append((event as InputEventKey).keycode)


func clear_made() -> void:
	_made.clear()


## (What the pad holds down now, its made keys; what reached this node too: a key the game
## answers, L a room's light, is taken before it comes here.)
func check_made(key: int, what: String) -> void:
	var held: Array = (get_node("/root/GameSettings/Pad").get("_held") as Dictionary).values()
	check("%s %s" % [what, held.map(func(k): return OS.get_keycode_string(k) if typeof(k) == TYPE_INT else str(k))], _made.has(key) or held.has(key))


## A screen with keys of its own, up or gone (shown and hidden as a station's is).
func screen_up(up: bool) -> void:
	if _screen == null:
		_screen = CanvasLayer.new()
		_screen.name = "PadProbeScreen"
		get_tree().root.add_child(_screen)
		get_node("/root/GameSettings/Pad").screen_keys(_screen, {JOY_BUTTON_DPAD_LEFT: KEY_Q})
	_screen.visible = up


func check_rumble() -> void:
	var w := Input.get_joy_vibration_strength(0)
	check("a hit shakes the pad (%s)" % w, w.length() > 0.2)


## A prompt with the pad in hand, as the HUD shows it.
func check_swap(text: String, want: String) -> void:
	var got: String = load("res://scripts/input/prompt.gd").swap(text)
	check("%s reads %s (%s)" % [text, want, got], got == want)


func check(what: String, ok: bool) -> void:
	print("PAD %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


## (Where the pad put the pointer, pad.gd pointer_at: the PC's own mouse over the window
## moved the window's pointer under the test and failed it now and then.)
func mark_pointer() -> void:
	get_node("/root/GameSettings/Pad").pointer_at = Vector2(-1, -1)
	_mark["pointer"] = get_viewport().get_final_transform() * get_viewport().get_mouse_position()


func check_pointer_moved() -> void:
	var from: Vector2 = _mark.get("pointer", Vector2.ZERO)
	var to: Vector2 = get_node("/root/GameSettings/Pad").pointer_at
	var right_edge := float(DisplayServer.window_get_size().x) - 2.0
	check("the left stick moves the pointer at the desk (%s -> %s)" % [from, to], to.x >= 0.0 and (to.x > from.x + 40.0 or to.x >= right_edge))


func mark_player() -> void:
	var pl: Node3D = _main.get("_player")
	_mark["yaw"] = pl.rotation.y
	_mark["at"] = pl.global_position


func check_turned() -> void:
	var pl: Node3D = _main.get("_player")
	var d := absf(wrapf(pl.rotation.y - float(_mark["yaw"]), -PI, PI))
	check("the right stick turns the head (%.2f rad)" % d, d > 0.3)


func check_walked() -> void:
	var pl: Node3D = _main.get("_player")
	var d: float = ((pl.global_position - (_mark["at"] as Vector3)) * Vector3(1, 0, 1)).length()
	check("the left stick walks (%.2f m)" % d, d > 1.0)


func mark_torch() -> void:
	var pl = _main.get("_player")
	_mark["torch"] = bool(pl.get("torch_switch"))


func check_torch() -> void:
	var pl = _main.get("_player")
	check("Y switches the torch", bool(pl.get("torch_switch")) != bool(_mark["torch"]))


func check_prompt(pad: bool) -> void:
	var P = load("res://scripts/input/prompt.gd")
	var t: String = P.tag("E")
	check("the prompt for E is %s (%s)" % ["[A]" if pad else "[E]", t], t == ("[A]" if pad else "[E]"))


## The HUD's hint line: its key as the pad's button after the lookup.
func check_hint(pad: bool) -> void:
	var hud = _main.get("_hud_manager")
	hud.set_hint_text("[E] Put a log on")
	var shown := str(hud.get("_hint_label").text)
	check("the hint shows %s (%s)" % ["[A]" if pad else "[E]", shown], shown.begins_with("[A]" if pad else "[E]") and shown.length() > 6)
	hud.set_hint_text("")


func verdict() -> void:
	print("PAD: %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
