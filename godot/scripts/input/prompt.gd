extends RefCounted

## How a prompt names the button it means (TODO.md D3): "[E]" while the keyboard and the
## mouse are in use, the pad's button ("[A]") once the pad is (scripts/input/pad.gd says
## which, and which button stands for which key). The hints keep their keys in their
## words ("[E] Put a log on", the catalogue's too); the HUD shows them through swap(),
## after the lookup, so "[E]" becomes "[A]" when the pad is in hand.

## A key's button on the pad: [out in the camp, with a pointer] ("" where it has none).
const PAD := {
	"E": ["A", "A"], "LMB": ["RT", "A"], "SPACE": ["B", "B"], "R": ["X", "X"], "F": ["Y", "Y"],
	"G": ["LB", ""], "V": ["RB", ""], "A": ["", "LB"], "D": ["", "RB"], "SHIFT": ["LT", ""],
	"RMB": ["", "LT"], "CTRL": ["L3", "L3"], "ESC": ["MENU", "B"], "TAB": ["VIEW", "VIEW"],
	"X": ["R3", ""], "C": ["UP", ""], "B": ["DOWN", ""], "L": ["LEFT", ""], "Q": ["RIGHT", ""],
	"W": ["LS", "UP"], "S": ["LS", "DOWN"],
}
## The pad's buttons by name (a screen's own keys, pad.gd screen_keys).
const NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_START: "MENU", JOY_BUTTON_BACK: "VIEW",
	JOY_BUTTON_DPAD_UP: "UP", JOY_BUTTON_DPAD_DOWN: "DOWN",
	JOY_BUTTON_DPAD_LEFT: "LEFT", JOY_BUTTON_DPAD_RIGHT: "RIGHT",
}
const PAD_SCRIPT = preload("res://scripts/input/pad.gd")


static func pad() -> bool:
	var p := PAD_SCRIPT.node()
	return p != null and bool(p.using_pad)


## The button's name: the key's ("E", "LMB") or the pad's ("A", "RT"); a key of the screen
## shown now (pad.gd screen_keys) by its button there.
static func button(key: String) -> String:
	var k := key.to_upper()
	if not pad():
		return k
	var own: Dictionary = PAD_SCRIPT.node().shown_screen_keys()
	if not own.is_empty():
		var code := OS.find_keycode_from_string(k)
		for btn in own:
			if typeof(own[btn]) == TYPE_INT and int(own[btn]) == code and NAMES.has(btn):
				return str(NAMES[btn])
	var pointer := Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	# A key the warden changed (the megaphone's, the radio's): its button out in the camp.
	if not pointer:
		for action in PAD_SCRIPT.ACTIONS:
			if OS.get_keycode_string(GameSettings.get_key(action)).to_upper() == k:
				return str(NAMES[PAD_SCRIPT.ACTIONS[action]])
	if not PAD.has(k):
		return k
	var pair: Array = PAD[k]
	var b := str(pair[1 if pointer else 0])
	return b if b != "" else k


## `item` drawn again when the hand goes from the keys to the pad or back (its words name
## the buttons); let go with it.
static func redraw_on_change(item: CanvasItem) -> void:
	var p := PAD_SCRIPT.node()
	if p != null:
		p.device_changed.connect(item.queue_redraw.unbind(1))


## "[E]" or "[A]".
static func tag(key: String) -> String:
	return "[%s]" % button(key)


## Every "[KEY]" in a line (a hint, already in the warden's language) as the pad's button
## while the pad is in hand; the line as it is otherwise.
static func swap(text: String) -> String:
	if not pad() or text.find("[") < 0:
		return text
	var out := ""
	var i := 0
	while i < text.length():
		var open := text.find("[", i)
		if open < 0:
			out += text.substr(i)
			break
		var close := text.find("]", open)
		if close < 0:
			out += text.substr(i)
			break
		out += text.substr(i, open - i)
		var key := text.substr(open + 1, close - open - 1)
		var b := button(key)
		out += ("[%s]" % b) if b != key.to_upper() else text.substr(open, close - open + 1)
		i = close + 1
	return out
