extends CanvasLayer

## Shown while main.gd builds the runtime before the title screen exists (and by the
## studio splash as its title card): the logo on black in a dithered frame, the line
## under it spaced out, a stepped bar that fills as the boot goes (a glint running along
## what is filled) and the step it is on. Everything moves sixteen times a second.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_MENU = preload("res://scripts/ui/retro_menu.gd")
const FPS := 16.0

var _status: Label
var _bar
var _t: float = 0.0


## The bar of the boot and of the loading plates: chunky segments, amber where filled, a
## brighter one running along the filled part a step a tick, the empty ones dark.
class StepBar:
	extends Control

	var ui_scale: int = 3
	var segments: int = 24
	var value: float = 0.0
	## Indeterminate: a block of lit segments sweeps along instead.
	var sweep := false
	var _tick := 0.0
	var _step := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _process(delta: float) -> void:
		_tick += delta
		if _tick >= 1.0 / FPS:
			_tick = 0.0
			_step += 1
			queue_redraw()

	func _draw() -> void:
		var s := float(ui_scale)
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0, 0, 0, 1))
		draw_rect(Rect2(Vector2(s, s), Vector2(w - 2 * s, h - 2 * s)), Color(0.08, 0.06, 0.05, 1))
		var gap := s
		var seg_w := floorf((w - 2 * s - gap * float(segments - 1)) / float(segments) / s) * s
		var lit := int(round(value * float(segments)))
		var head := _step % (segments + 4)
		for i in segments:
			var x := s + float(i) * (seg_w + gap)
			var r := Rect2(Vector2(x, 2 * s), Vector2(seg_w, h - 4 * s))
			var on := (i >= head - 4 and i < head) if sweep else i < lit
			var c := RETRO_UI.C_AMBER if on else Color(0.18, 0.12, 0.08, 1)
			if on and not sweep and i == _step % maxi(1, lit + 3):
				c = RETRO_UI.C_AMBER_LIGHT
			draw_rect(r, c)
			if on:
				draw_rect(Rect2(r.position, Vector2(r.size.x, s)), c.lightened(0.3))


func _init() -> void:
	name = "BootScreen"
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := RETRO_UI.ui_scale(vp.y, vp.x, 400.0)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.012, 0.01, 0.008, 1.0)
	add_child(bg)
	var frame = RETRO_MENU.DitherShade.new()
	frame.ui_scale = s
	frame.mode = "frame"
	frame.band = 0.16
	frame.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.add_child(frame)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3 * s)
	bg.add_child(box)
	var logo := RETRO_UI.PixelTitle.new()
	logo.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 3, s)
	logo.set_colors(Color(1.0, 0.84, 0.44), Color(0.92, 0.38, 0.08))
	logo.set_text("CURSED CAMP")
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(logo)
	var sub := RETRO_UI.label("M A N A G E R   S I M U L A T O R", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, s)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14 * s)
	box.add_child(gap)
	_bar = StepBar.new()
	_bar.ui_scale = s
	_bar.segments = 24
	_bar.custom_minimum_size = Vector2(150 * s, 7 * s)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_bar)
	_status = RETRO_UI.label("WAKING THE CAMP", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, s, false)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func set_status(text: String, progress: float) -> void:
	if _status != null:
		_status.text = text.to_upper()
	if _bar != null:
		_bar.set_value(progress)
