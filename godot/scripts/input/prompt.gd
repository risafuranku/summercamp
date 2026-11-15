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
}


static func pad() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var p = tree.root.get_node_or_null("GameSettings/Pad") if tree != null else null
	return p != null and bool(p.using_pad)


## The button's name: the key's ("E", "LMB") or the pad's ("A", "RT").
static func button(key: String) -> String:
	var k := key.to_upper()
	if not pad() or not PAD.has(k):
		return k
	var pair: Array = PAD[k]
	var b := str(pair[1 if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED else 0])
	return b if b != "" else k


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
		out += tag(key) if PAD.has(key.to_upper()) else text.substr(open, close - open + 1)
		i = close + 1
	return out
