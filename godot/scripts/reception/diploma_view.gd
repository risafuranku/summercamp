extends CanvasLayer

## A diploma off the office wall held up to read (playtest 25. 10.: "let me look at the
## diploma on the wall with a click, the eye for a cursor"; office_dressing.gd hangs them,
## reception_extras.gd gives them the eye): the district's paper as Builder 98's Courier
## brought it (scripts/builder/news_paper.gd: the award typed on it, the camp's name, the
## day it came), big in the middle of the screen, the room dimmed behind it. A click, Esc
## or the right button puts it back.

signal closed

const NEWS_PAPER := preload("res://scripts/builder/news_paper.gd")
const SFX := "res://assets/sfx/rooms/task_litter.mp3"

var _paper: Control
var _k := 2.0


func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("closeup")


func open(item: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	add_child(dim)
	_paper = NEWS_PAPER.new()
	_paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_paper)
	_paper.setup(item, null)
	_paper.done.connect(close)
	_layout()
	get_viewport().size_changed.connect(_layout)
	_sound()


func _layout() -> void:
	if _paper == null:
		return
	var vs := get_viewport().get_visible_rect().size
	# A whole number of times its size, as tall as fits in most of the screen.
	_k = maxf(1.0, floorf(vs.y * 0.86 / _paper.size.y))
	_paper.scale = Vector2(_k, _k)
	_paper.position = ((vs - _paper.size * _k) * 0.5).floor()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		get_viewport().set_input_as_handled()
		if (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_S, KEY_E, KEY_SPACE, KEY_ENTER]:
			close()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _sound() -> void:
	if not ResourceLoader.exists(SFX):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(SFX)
	p.volume_db = -10.0
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(p)
	p.play()
