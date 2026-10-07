extends CanvasLayer

## Shown while main.gd builds the runtime before the title screen exists: the logo on
## black, a filling segment bar and a status line.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")

var _status: Label
var _bar
var _t: float = 0.0


func _init() -> void:
	name = "BootScreen"
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := RETRO_UI.ui_scale(vp.y, vp.x, 400.0)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.015, 0.012, 0.01, 1.0)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4 * s)
	bg.add_child(box)
	var logo := RETRO_UI.PixelTitle.new()
	logo.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 3, s)
	logo.set_colors(Color(1.0, 0.86, 0.46), Color(0.96, 0.46, 0.10))
	logo.set_text("CURSED CAMP")
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(logo)
	var sub := RETRO_UI.PixelTitle.new()
	sub.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG, s)
	sub.set_colors(Color(1.0, 0.52, 0.42), Color(0.78, 0.12, 0.08))
	sub.set_text("MANAGER SIMULATOR")
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10 * s)
	box.add_child(gap)
	_bar = RETRO_UI.SegmentBar.new()
	_bar.ui_scale = s
	_bar.segments = 24
	_bar.color_full = RETRO_UI.C_AMBER
	_bar.color_low = RETRO_UI.C_AMBER
	_bar.custom_minimum_size = Vector2(160 * s, 4 * s)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.set_value(0.0)
	box.add_child(_bar)
	_status = RETRO_UI.label("LOADING SYSTEMS...", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, s, false)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func set_status(text: String, progress: float) -> void:
	if _status != null:
		_status.text = text.to_upper()
	if _bar != null:
		_bar.set_value(progress)
