extends Control

## Builder 98's new blueprints, shown when the camp has had more guests at once than ever
## and a tier opens (goggle.TIERS; the user 25. 10.: "an animation of unlocking new things
## in the Builder and a few previews of the best of them, so the player knows they made
## it"). The program's own window as the tycoons of 1998 had it for a new ride: its title
## bar, NEW BLUEPRINTS and the guests that opened them, then the best of what opened, a
## picture each, coming up one after another out of the dark in steps (twelve a second)
## with the card's sound; OK (a click, Enter, Space) puts it away. builder_module then
## takes the padlocks off their cards in the catalogue.

const T = preload("res://scripts/os98/os_theme.gd")
const PIC := Vector2(96, 72)
const GAP := 10.0
const STEP := 1.0 / 12.0
const EACH_SEC := 0.45

signal done

## [{type, name, price, icon: Texture2D}], the best first.
var items: Array = []
var guests := 0
var more := 0
## Plays the program's sounds (builder_module._ui).
var play: Callable

var _t := 0.0
var _shown := -1


func setup(p_items: Array, p_guests: int, p_more: int) -> void:
	items = p_items
	guests = p_guests
	more = p_more
	var n := maxi(1, items.size())
	size = Vector2(maxf(260.0, 24.0 + n * PIC.x + (n - 1) * GAP), 66.0 + PIC.y + 76.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	grab_focus.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	var now := clampi(int(floorf((_t - 0.25) / EACH_SEC)), -1, items.size())
	if now != _shown:
		if now >= 0 and now < items.size() and play.is_valid():
			play.call("card")
		elif now == items.size() and play.is_valid():
			play.call("diploma")
		_shown = now
	queue_redraw()


func _ok_rect() -> Rect2:
	return Rect2(floorf((size.x - 76.0) * 0.5), size.y - 30.0, 76.0, 22.0)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_close()
	elif e is InputEventKey and e.pressed and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_SPACE):
		accept_event()
		_close()


func _close() -> void:
	# Not before they are all up (the first click hurries them).
	if _shown < items.size():
		_t = 0.25 + EACH_SEC * float(items.size())
		return
	done.emit()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2(3, 3), s), Color(0, 0, 0, 0.35))
	draw_style_box(T.box("window", T.FACE, Vector4.ZERO), Rect2(Vector2.ZERO, s))
	# The title bar.
	var bar := Rect2(3, 3, s.x - 6, 18)
	for i in int(bar.size.x):
		draw_rect(Rect2(bar.position.x + i, bar.position.y, 1, bar.size.y), T.TITLE_A.lerp(T.TITLE_B, float(i) / bar.size.x))
	draw_string(T.FONT_BOLD, Vector2(8, 16), "Builder 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	var head := tr("NEW BLUEPRINTS")
	var hw := T.FONT_BOLD.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(T.FONT_BOLD, Vector2(floorf((s.x - hw) * 0.5), 42), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, T.NAVY)
	var sub := tr("%d guests in the camp at once") % guests
	var sw := T.FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	draw_string(T.FONT, Vector2(floorf((s.x - sw) * 0.5), 57), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	var n := items.size()
	var x0 := floorf((s.x - (n * PIC.x + (n - 1) * GAP)) * 0.5)
	for i in n:
		var it: Dictionary = items[i]
		var r := Rect2(x0 + i * (PIC.x + GAP), 66, PIC.x, PIC.y)
		draw_style_box(T.box("field", Color8(32, 40, 30), Vector4.ZERO), r)
		# Up out of the dark: the picture's rows from the bottom, in steps.
		var k := clampf((_t - 0.25 - float(i) * EACH_SEC) / 0.35, 0.0, 1.0)
		if k < 1.0:
			k = floorf(k / (STEP / 0.35)) * (STEP / 0.35)
		var ic: Texture2D = it.get("icon", null)
		if ic != null and k > 0.0:
			var isz := ic.get_size()
			var sc := minf((r.size.x - 6.0) / isz.x, (r.size.y - 6.0) / isz.y)
			var d := (isz * sc).floor()
			var at := r.position + ((r.size - d) * 0.5).floor()
			var shown_h := floorf(d.y * minf(1.0, k))
			draw_texture_rect_region(ic, Rect2(at + Vector2(0, d.y - shown_h), Vector2(d.x, shown_h)), Rect2(Vector2(0, isz.y * (1.0 - shown_h / d.y)), Vector2(isz.x, isz.y * shown_h / d.y)))
		if k >= 1.0:
			var nm := str(it.get("name", ""))
			var nw := T.FONT_BOLD.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			draw_string(T.FONT_BOLD, Vector2(floorf(r.position.x + (r.size.x - nw) * 0.5), r.end.y + 13), nm, HORIZONTAL_ALIGNMENT_LEFT, r.size.x + GAP, T.FONT_SIZE, T.TEXT)
			var pr := "$%d" % int(it.get("price", 0))
			var pw := T.FONT.get_string_size(pr, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			draw_string(T.FONT, Vector2(floorf(r.position.x + (r.size.x - pw) * 0.5), r.end.y + 25), pr, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(70, 70, 90))
	if more > 0 and _shown >= n:
		var m := tr("and %d more in the catalogue") % more
		var mw := T.FONT.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		draw_string(T.FONT, Vector2(floorf((s.x - mw) * 0.5), 66.0 + PIC.y + 41.0), m, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.SHADOW)
	if _shown >= n:
		var ok := _ok_rect()
		draw_style_box(T.box("default", T.FACE, Vector4.ZERO), ok)
		var ow := T.FONT.get_string_size("OK", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		draw_string(T.FONT, Vector2(floorf(ok.position.x + (ok.size.x - ow) * 0.5), ok.position.y + 15), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
