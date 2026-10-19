extends Control

## The sentence under a room, like the verb line of an old point-and-click adventure: what
## the thing under the pointer is and what a click does ("Use the stove", "Look at the
## deer", "Go down to the cellar"), and a line about something you clicked to look at,
## typed out and left a few seconds. Drawn at the game's 2D pixel, just over the room's
## way out (the bottom band).

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const HOLD := 5.0

var _hover := ""
var _line := ""
var _shown := 0.0
var _line_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## What the pointer is over now ("" nothing).
func hover(text: String) -> void:
	if text != _hover:
		_hover = text
		queue_redraw()


## A line said about something: typed out, then gone after a while.
func say(text: String) -> void:
	_line = text
	_shown = 0.0
	_line_t = 0.0
	queue_redraw()


func clear() -> void:
	_hover = ""
	_line = ""
	queue_redraw()


func _process(delta: float) -> void:
	if _line == "":
		return
	_line_t += delta
	if _shown < float(_line.length()):
		_shown = minf(float(_line.length()), _shown + delta * 50.0)
	if _line_t > HOLD + float(_line.length()) / 50.0:
		_line = ""
	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var k := maxi(1, int(floor(minf(screen.x / 640.0, screen.y / 360.0))))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var s := screen / float(k)
	var y := floorf(s.y * 0.88)
	if _hover != "":
		_centred(Vector2(s.x * 0.5, y), _hover, RETRO_UI.C_AMBER_LIGHT)
		y -= 12.0
	if _line != "":
		_centred(Vector2(s.x * 0.5, y), _line.substr(0, int(_shown)), RETRO_UI.C_QUOTE, _line)


func _centred(at: Vector2, text: String, col: Color, full := "") -> void:
	var f: Font = RETRO_UI.FONT_TEXT
	var w := f.get_string_size(full if full != "" else text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := Vector2(floorf(at.x - w * 0.5), floorf(at.y))
	draw_rect(Rect2(p.x - 4, p.y - 9, w + 8, 12), Color(0.03, 0.025, 0.02, 0.7))
	draw_string(f, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.9))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
