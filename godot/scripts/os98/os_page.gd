extends Control

## A program's place on the camp computer's panel (scripts/os98/os_shell.gd): the whole
## area above the taskbar, no frame, no dragging, nothing to minimise. It keeps the
## window's contract so the programs did not have to change: `app_id`, `title`, `icon`,
## `content` (the program is its first child), `client_size()`, the three signals.
##
## A program that is not installed yet, or Builder after 20:00, gets a cover page over it
## (`cover`): what it is, and the one button that sorts it out.

signal close_requested
signal minimize_requested
signal activated
signal title_changed

const T = preload("res://scripts/os98/os_theme.gd")

var app_id := ""
var title := "":
	set(v):
		if v != title:
			title = v
			title_changed.emit()
var icon: Texture2D
var active := true
var can_maximize := false
var can_minimize := false
var content: Control
## The page drawn over the program (install, licence), or null.
var cover: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = T.get_theme()
	clip_contents = true
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content)
	resized.connect(_layout)


func setup(p_app_id: String, p_title: String, p_icon: Texture2D, rect: Rect2, _desktop_size := Vector2.ZERO) -> void:
	app_id = p_app_id
	title = p_title
	icon = p_icon
	position = rect.position.floor()
	size = rect.size.floor()
	_layout()


func client_size() -> Vector2:
	return size


## Pages are always the whole area.
func set_maximized(_on: bool) -> void:
	pass


## The window's face under the program: a program that leaves some of itself undrawn
## shows grey there, not the wallpaper.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), T.FACE)


func set_cover(c: Control) -> void:
	if cover != null and is_instance_valid(cover):
		cover.queue_free()
	cover = c
	if c != null:
		c.position = Vector2.ZERO
		c.size = size
		add_child(c)
	content.visible = c == null


func _layout() -> void:
	if content == null:
		return
	content.position = Vector2.ZERO
	content.size = size
	if cover != null and is_instance_valid(cover):
		cover.size = size
