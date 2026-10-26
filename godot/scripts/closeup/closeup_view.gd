extends CanvasLayer

## A close-up of a thing in a room, like the event screens of early-90s DOS games
## (SimAnt's spider, a Sierra inset): one hand-painted 320x240 picture (Grok, keyed to
## the game palette), drawn at its native resolution with the game's pixel fonts and
## scaled up by a whole number, with a text strip under it for what is said or read.
## Things in the picture are hotspots: the gloved finger over them, click to use.
## Esc, the right mouse button or the back of the picture closes it.
##
## Subclasses (phone_closeup, board_closeup, fuse_closeup) override:
##   _hotspots() -> Array of {id, rect: Rect2 in picture px}
##   _paint(c: Control)    draw on top of the picture (picture px, native fonts)
##   _clicked(id)          a hotspot was clicked
##   _key(event) -> bool   a key while open (true = used)
##   _tick(delta)
##   _opened() / _closing()

signal closed

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const W := 320
const PIC_H := 240
const STRIP_H := 36
const H := PIC_H + STRIP_H
const SFX_OPEN := "res://assets/sfx/rooms/task_done.mp3"
## The picture opens like a blind, in steps (the game animates at 8-12 fps).
const OPEN_STEPS := 6
const OPEN_SEC := 0.22

var picture: Texture2D
var strip_who := ""
var strip_text := ""
## How much of strip_text is shown (typewriter); -1 = all.
var strip_shown := -1

var _vp: SubViewport
var _canvas: Control
var _backdrop: ColorRect
var _view: TextureRect
var _k := 2
var _hover := ""
var _mouse := Vector2(-1, -1)   # picture px, or -1 outside
var _open_t := 0.0
var _closing_t := -1.0
var _type_acc := 0.0
var _audio: AudioStreamPlayer


func _init() -> void:
	layer = 95
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# While one is up your hands are on it (scripts/town/pockets.gd hides the cigarette).
	add_to_group("closeup")


func _ready() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_canvas = Control.new()
	_canvas.size = Vector2(W, H)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_all)
	_vp.add_child(_canvas)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -8.0
	add_child(_audio)
	get_tree().root.size_changed.connect(_layout)


func is_open() -> bool:
	return visible and _closing_t < 0.0


func open_view() -> void:
	if visible:
		return
	visible = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_open_t = 0.0
	_closing_t = -1.0
	_hover = ""
	_layout()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_opened()


func close_view() -> void:
	if not visible or _closing_t >= 0.0:
		return
	_closing()
	_closing_t = 0.0


func say(who: String, text: String, typewriter := true) -> void:
	strip_who = tr(who)
	strip_text = tr(text)
	strip_shown = 0 if typewriter else -1
	_type_acc = 0.0


func play(path: String, db := -8.0) -> void:
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.volume_db = db
		_audio.play()


func _layout() -> void:
	if _view == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_k = maxi(1, int(floor(minf(vp.x * 0.94 / float(W), vp.y * 0.94 / float(H)))))
	_view.size = Vector2(W * _k, H * _k)
	_view.position = ((vp - _view.size) * 0.5).floor()


func _process(delta: float) -> void:
	if not visible:
		return
	if _closing_t >= 0.0:
		_closing_t += delta
		var f := 1.0 - clampf(_closing_t / (OPEN_SEC * 0.6), 0.0, 1.0)
		_set_open_fraction(f)
		if f <= 0.0:
			visible = false
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			closed.emit()
		return
	_open_t += delta
	_set_open_fraction(clampf(_open_t / OPEN_SEC, 0.0, 1.0))
	var m := (get_viewport().get_mouse_position() - _view.position) / float(_k)
	_mouse = m if Rect2(Vector2.ZERO, Vector2(W, H)).has_point(m) else Vector2(-1, -1)
	_hover = _hotspot_at(_mouse)
	if _hover != "":
		HandCursor.want(HandCursor.POINT)
	if strip_shown >= 0 and strip_shown < strip_text.length():
		_type_acc += delta * 48.0
		while _type_acc >= 1.0 and strip_shown < strip_text.length():
			_type_acc -= 1.0
			strip_shown += 1
	_tick(delta)
	_canvas.queue_redraw()


## 0 = a closed slit across the middle, 1 = open; drawn in whole steps.
func _set_open_fraction(f: float) -> void:
	var step := ceilf(f * OPEN_STEPS) / OPEN_STEPS
	_view.scale = Vector2(1.0, maxf(0.02, step))
	_view.pivot_offset = _view.size * 0.5
	_backdrop.color = Color(0, 0, 0, 0.72 * f)


func _hotspot_at(p: Vector2) -> String:
	if p.x < 0.0:
		return ""
	for h in _hotspots():
		if (h["rect"] as Rect2).has_point(p):
			return str(h["id"])
	return ""


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	# Esc goes on to the pause menu (main).
	if event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _closing_t >= 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_S:
		close_view()
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			close_view()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# A click while text is still typing shows it all first.
			if strip_shown >= 0 and strip_shown < strip_text.length() and _hover == "":
				strip_shown = -1
				return
			if _hover != "":
				_clicked(_hover)
			elif _mouse.x < 0.0:
				close_view()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event as InputEventKey)


func _draw_all() -> void:
	var c := _canvas
	c.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.02))
	if picture != null:
		c.draw_texture_rect(picture, Rect2(0, 0, W, PIC_H), false)
	_paint(c)
	_draw_strip(c)
	# A one-pixel bevel round the whole plate, like the HUD's.
	c.draw_rect(Rect2(0, 0, W, 1), RETRO_UI.C_PLATE_LIGHT)
	c.draw_rect(Rect2(0, 0, 1, H), RETRO_UI.C_PLATE_LIGHT)
	c.draw_rect(Rect2(0, H - 1, W, 1), RETRO_UI.C_PLATE_DARK)
	c.draw_rect(Rect2(W - 1, 0, 1, H), RETRO_UI.C_PLATE_DARK)


func _draw_strip(c: Control) -> void:
	var y0 := float(PIC_H)
	c.draw_rect(Rect2(0, y0, W, STRIP_H), Color(0.06, 0.05, 0.04))
	c.draw_rect(Rect2(0, y0, W, 1), RETRO_UI.C_PLATE_DARK)
	c.draw_rect(Rect2(0, y0 + 1, W, 1), RETRO_UI.C_PLATE_LIGHT * Color(1, 1, 1, 0.5))
	var font: Font = RETRO_UI.FONT_TEXT
	var x := 6.0
	var text := strip_text if strip_shown < 0 else strip_text.substr(0, strip_shown)
	var lines := _wrap(text, font, 8, W - 12 - (_who_width(font) if strip_who != "" else 0.0))
	var y := y0 + 11.0
	if strip_who != "":
		c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, y), strip_who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_AMBER)
		x += _who_width(font)
	for i in mini(lines.size(), 3):
		c.draw_string(font, Vector2(x, y + i * 9.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_BONE)


func _who_width(_font: Font) -> float:
	return RETRO_UI.FONT_LABEL.get_string_size(strip_who.to_upper() + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 2.0


static func _wrap(text: String, font: Font, size: int, width: float) -> Array:
	var out: Array = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out


## Draws `text` with a one-pixel dark shadow (for things written onto the picture).
static func ink(c: Control, font: Font, pos: Vector2, text: String, col: Color, shadow := Color(0, 0, 0, 0.0), size := 8) -> void:
	if shadow.a > 0.0:
		c.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func hovered() -> String:
	return _hover


# ── for subclasses ────────────────────────────────────────────────────────────

func _hotspots() -> Array:
	return []


func _paint(_c: Control) -> void:
	pass


func _clicked(_id: String) -> void:
	pass


func _key(_event: InputEventKey) -> bool:
	return false


func _tick(_delta: float) -> void:
	pass


func _opened() -> void:
	pass


func _closing() -> void:
	pass
