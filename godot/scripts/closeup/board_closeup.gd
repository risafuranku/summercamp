extends "res://scripts/closeup/closeup_view.gd"

## The cork noticeboard in the office, close up (Grok, assets/textury/closeup/board.png):
## Vera's notes pinned up over the years. Click a note and it is held up to the light,
## big enough to read: the phone numbers the office runs on (phone_book.gd), the bus,
## the shop. An old tag for the lake keeper is crossed out. A key hangs on a string:
## the generator shed's back room (where the fuses are) is locked, and this opens it.
## Taken, it is in your bag (scripts/ui/inventory.gd); click the bare pin with it in the
## bag and it hangs there again.

## Paper rectangles on the picture (px), and the text written on each.
const NOTES := {
	"phones": {"rect": Rect2(26, 17, 89, 83), "paper": Color(0.86, 0.84, 0.78), "ink": Color(0.1, 0.1, 0.12), "font": "label",
		"text": "TELEPHONE   (4/96)\n\nElectrician Novotny\n      0663 22 418\nVet, Liblice    0663 21 007\nDistrict office\n      0663 30 112\nWater board   0663 30 150\nBus station   0663 21 333\nJednota       0663 21 090\nU Jezera (pub)\n      0663 21 515\nPower, faults 0663 30 199\nPolice 158   Ambulance 155"},
	"novotny": {"rect": Rect2(132, 23, 68, 74), "paper": Color(0.86, 0.74, 0.42), "ink": Color(0.1, 0.12, 0.3),
		"text": "NOVOTNY !!\n0663 22 418\n\nthe main, the lamps,\nthe pump. He comes\nout in the van.\n\nNOT after 9 - he will\ncome but he will moan\nand it is double.\n\nCash.  V."},
	"private": {"rect": Rect2(224, 21, 70, 74), "paper": Color(0.86, 0.66, 0.64), "ink": Color(0.3, 0.06, 0.1),
		"text": "Time  14 112\n\nNela (mobile)\n  0602 618 247\n\nme, the flat\n  02 / 6731 4420\nonly if it is\nREALLY bad.\n\nV."},
	"photo": {"rect": Rect2(24, 109, 78, 85), "paper": Color(0.86, 0.84, 0.78), "ink": Color(0.14, 0.12, 0.2),
		"text": "Hruby, '91\n\n(the lake from the\njetty. Somebody has\npressed a thumbnail\ninto the water, in\nthe middle, hard\nenough to dent it.)"},
	"bus": {"rect": Rect2(110, 126, 70, 81), "paper": Color(0.62, 0.7, 0.78), "ink": Color(0.08, 0.1, 0.22),
		"text": "BUS  380\nLiblice - camp\n 5:30  13:05  18:30\n\nback to Liblice:\n 6:15   13:50\nlast one 19:15.\nthe 23:46 does not\nstop. do not wave.\n\nJednota van:\nTue + Fri, at the gate."},
	"hruby": {"rect": Rect2(188, 130, 36, 71), "paper": Color(0.74, 0.7, 0.62), "ink": Color(0.14, 0.12, 0.12),
		"text": "Hruby - lake\nkeeper - boats,\nthe sluice\n\n0663 21 224\n\n-- no longer --", "struck": [0, 4]},
	"card": {"rect": Rect2(254, 157, 47, 55), "paper": Color(0.84, 0.78, 0.6), "ink": Color(0.12, 0.1, 0.08), "font": "label",
		"text": "KEMP\nCERNE JEZERO\n\nreception\n0663 21 404\n\nopen May-Sept"},
}
const KEY_RECT := Rect2(232, 102, 21, 94)
const KEY_PATCH_FROM := Rect2(258, 102, 21, 50)
const PIC := "res://assets/textury/closeup/board.png"
const SFX_PAPER := "res://assets/sfx/rooms/task_litter.mp3"
const SFX_KEY := "res://assets/sfx/rednecksfx/rrtick.wav"

## Callable() -> bool: is the shed key still on the board?
var key_present: Callable
## Callable() -> bool: take the key (false: no room for it in the bag).
var on_key_taken: Callable
## Callable() -> bool: hang the key back (false: it is not in your bag).
var on_key_returned: Callable

var _reading := ""
var _read_t := 0.0


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


func _opened() -> void:
	_reading = ""
	say("", "", false)


func _has_key() -> bool:
	return key_present.call() if key_present.is_valid() else false


func _hotspots() -> Array:
	if _reading != "":
		return [{"id": "put_back", "rect": Rect2(0, 0, W, PIC_H)}]
	var out: Array = []
	for id in NOTES.keys():
		out.append({"id": id, "rect": NOTES[id]["rect"]})
	out.append({"id": "key" if _has_key() else "pin", "rect": KEY_RECT})
	return out


func _clicked(id: String) -> void:
	if id == "put_back":
		_reading = ""
		play(SFX_PAPER, -16.0)
		return
	if id == "key":
		if on_key_taken.is_valid() and not bool(on_key_taken.call()):
			say("", "There is no room for it in your bag.")
			return
		play(SFX_KEY, -4.0)
		say("", "A key on a loop of string, warm from the lamp. On the tag, in pen: SHED - BACK.")
		return
	if id == "pin":
		if on_key_returned.is_valid() and bool(on_key_returned.call()):
			play(SFX_KEY, -4.0)
			say("", "Back on its pin.")
		else:
			say("", "The pin the shed key hangs on. Nothing on it.")
		return
	_reading = id
	_read_t = 0.0
	play(SFX_PAPER, -14.0)
	say("", "", false)


func _key(event: InputEventKey) -> bool:
	if _reading != "" and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_BACKSPACE]:
		_reading = ""
		return true
	return false


func _tick(delta: float) -> void:
	_read_t += delta


func _paint(c: Control) -> void:
	if picture == null:
		return
	if not _has_key():
		# Where the key hung: bare cork and the pin.
		c.draw_texture_rect_region(picture, Rect2(KEY_RECT.position + Vector2(0, 40), Vector2(KEY_RECT.size.x, 54)), Rect2(KEY_PATCH_FROM.position, Vector2(KEY_RECT.size.x, 54)))
	# Writing too small to read from here: a few grey scribbles per note.
	for id in NOTES.keys():
		var n: Dictionary = NOTES[id]
		var r: Rect2 = n["rect"]
		if id == "photo":
			continue
		var col: Color = n["ink"]
		col.a = 0.45
		var lines := str(n["text"]).split("\n")
		for i in mini(lines.size(), int((r.size.y - 12.0) / 5.0)):
			var w := minf(r.size.x - 10.0, float(lines[i].length()) * 2.2)
			if w > 1.0:
				c.draw_rect(Rect2(r.position.x + 5, r.position.y + 8 + i * 5, w, 1), col)
		if hovered() == id:
			c.draw_rect(r, Color(1.0, 0.92, 0.6, 0.14))
	if hovered() == "key" or hovered() == "pin":
		c.draw_rect(KEY_RECT, Color(1.0, 0.92, 0.6, 0.12))
	if _reading != "":
		_paint_held(c, NOTES[_reading])


## The note held up close: the paper drawn big in the middle, the board dimmed behind.
func _paint_held(c: Control, n: Dictionary) -> void:
	c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0, 0, 0, 0.62))
	var src: Rect2 = n["rect"]
	var lines := str(n["text"]).split("\n")
	var font: Font = RETRO_UI.FONT_LABEL if str(n.get("font", "")) == "label" else RETRO_UI.FONT_TEXT
	var widest := 0.0
	for l in lines:
		widest = maxf(widest, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var size := Vector2(maxf(widest + 24.0, 120.0), maxf(float(lines.size()) * 9.0 + 24.0, 100.0))
	size = size.min(Vector2(W - 20, PIC_H - 12))
	var at := ((Vector2(W, PIC_H) - size) * 0.5).floor()
	# Lifted toward you in two steps.
	var grow := 0.86 if _read_t < 0.06 else 1.0
	var r := Rect2(at + size * (1.0 - grow) * 0.5, size * grow).abs()
	c.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.5))
	if picture != null:
		c.draw_texture_rect_region(picture, r, src.grow(-3))
	c.draw_rect(r, Color(n["paper"], 0.55))
	if grow < 1.0:
		return
	var ink_col: Color = n["ink"]
	var struck: Array = n.get("struck", [])
	for i in lines.size():
		var p := Vector2(r.position.x + 10, r.position.y + 16 + i * 9)
		c.draw_string(font, p, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink_col)
		if struck.has(i):
			var lw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			c.draw_rect(Rect2(p.x - 1, p.y - 3, lw + 2, 1), ink_col)
