class_name HandCursor
extends Node

## The game's mouse pointer (DESIGN §10): no system arrow anywhere in the world, but
## the player's own gloved hand, drawn like the work-hand sprites (Grok, tools/artgen,
## cursor.py adds the outline). A carved camp-sign arrow when there is nothing to do,
## the pointing finger over anything you can use, the fist while you hold a job, the
## flat palm where you can walk through (a door, the way out), the carved double arrow
## where the work wants the mouse moved to and fro (scrubbing the bowl: playtest 25. 10.
## "where the cleaning wants the cursor moved, show arrows of the motion expected").
##
## Anything may ask for a shape every frame with `HandCursor.want(kind, self)`; the
## strongest request of the frame in that game wins, and this node (added once by each
## main, processed last) applies it. Nothing asked = the arrow. The picture is scaled by a
## whole number to the window, like the rest of the 2D, and swapped into the system cursor
## (hardware, so it never lags behind the mouse). The split screen's second game
## (scripts/instance/local_client.gd) has no mouse of its own: its hand is drawn on its own
## half where its pad puts its pointer (instance_input.pointer), in the shape its game asks
## for (one shape for the whole program till 22. 11., and no pointer to be seen there).

const INSTANCE = preload("res://scripts/instance/instance.gd")
enum { ARROW, LOOK, POINT, WALK, GRAB, RUB }

const DIR := "res://assets/textury/ui/"
const FILES := {ARROW: "cursor_arrow.png", LOOK: "cursor_look.png", POINT: "cursor_point.png", WALK: "cursor_walk.png", GRAB: "cursor_grab.png", RUB: "cursor_rub.png"}
## Where the click lands, as a share of the picture (the fingertip, the arrow's tip).
const HOT := {ARROW: Vector2(0.06, 0.04), LOOK: Vector2(0.5, 0.5), POINT: Vector2(0.12, 0.03), WALK: Vector2(0.5, 0.3), GRAB: Vector2(0.5, 0.45), RUB: Vector2(0.5, 0.5)}

## The shape asked for this frame, by game (its instance's root; 0 a lone game's).
static var _wanted_by := {}
var _shown := -1
static var _scale := 0
static var _cache: Dictionary = {}   # kind -> Image at the current scale
## A menu over the whole view (the pause menu): the arrow whatever the room under it
## asks, and nothing under it is aimed at (playtest 1. 11.: in a co-op camp, where Esc
## pauses nothing, the room under the menu went on taking its clicks).
static var menu_over := false


## The strongest shape asked for this frame wins (RUB > GRAB > WALK > POINT > LOOK > ARROW),
## in the game of `who` (the node asking).
static func want(kind: int, who: Node) -> void:
	var k := _key(who)
	if kind > int(_wanted_by.get(k, ARROW)):
		_wanted_by[k] = kind


static func _key(who: Node) -> int:
	return INSTANCE.root_of(who).get_instance_id() if INSTANCE.count > 1 and who != null else 0


## The second game's hand, drawn on its half (null in the host's or a lone game).
var _drawn: TextureRect
var _drawn_tex := {}   # kind -> ImageTexture at the current scale


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	get_tree().root.size_changed.connect(_rescale)
	_rescale()


func _process(_delta: float) -> void:
	var k := _key(self)
	var kind := ARROW if menu_over else int(_wanted_by.get(k, ARROW))
	_wanted_by.erase(k)
	if INSTANCE.root_of(self).is_in_group(INSTANCE.GROUP):
		_draw_hand(kind)
	elif kind != _shown:
		_apply(kind)


## The second game's hand at its pointer, while its game shows a pointer at all.
func _draw_hand(kind: int) -> void:
	if _drawn == null:
		var layer := CanvasLayer.new()
		layer.layer = 128
		add_child(layer)
		_drawn = TextureRect.new()
		_drawn.visible = false
		_drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drawn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(_drawn)
	var inp = INSTANCE.input(self)
	var mode: int = inp.get_mouse_mode()
	var was := _drawn.visible
	_drawn.visible = mode == Input.MOUSE_MODE_VISIBLE or mode == Input.MOUSE_MODE_CONFINED
	if not _drawn.visible:
		return
	if not was:
		# Let go of the look (a room, the PC): the hand from the middle, as the mouse is.
		inp.warp_mouse((get_viewport().get_visible_rect().size * 0.5).floor())
	if kind != _shown or not _drawn_tex.has(kind):
		_shown = kind
		if not _drawn_tex.has(kind):
			var img := _image(kind)
			_drawn_tex[kind] = ImageTexture.create_from_image(img) if img != null else null
		_drawn.texture = _drawn_tex[kind]
		if _drawn.texture != null:
			_drawn.size = _drawn.texture.get_size()
	var hot: Vector2 = HOT.get(kind, Vector2.ZERO)
	_drawn.position = (inp.pointer - (hot * _drawn.size).floor()).floor()


func _rescale() -> void:
	# Window pixels, not the logical 2D size: the system cursor is drawn unscaled.
	var h := float(get_tree().root.size.y)
	var k := clampi(int(h / 540.0), 1, 4)
	if k == _scale:
		return
	_scale = k
	_cache.clear()
	_drawn_tex.clear()
	_shown = -1


static func _image(kind: int) -> Image:
	if _cache.has(kind):
		return _cache[kind]
	var img: Image = null
	var path: String = DIR + str(FILES.get(kind, ""))
	if not ResourceLoader.exists(path) and kind != ARROW:
		path = DIR + str(FILES[POINT])
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			img = tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(img.get_width() * maxi(1, _scale), img.get_height() * maxi(1, _scale), Image.INTERPOLATE_NEAREST)
	_cache[kind] = img
	return img


func _apply(kind: int) -> void:
	_shown = kind
	var img := _image(kind)
	if img == null:
		INSTANCE.input(self).set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return
	var hot: Vector2 = HOT.get(kind, Vector2.ZERO)
	var spot := Vector2(floorf(hot.x * img.get_width()), floorf(hot.y * img.get_height()))
	# Every Control shows the arrow shape, so the arrow's picture is what changes.
	INSTANCE.input(self).set_custom_mouse_cursor(img, Input.CURSOR_ARROW, spot)
	INSTANCE.input(self).set_custom_mouse_cursor(img, Input.CURSOR_POINTING_HAND, spot)
