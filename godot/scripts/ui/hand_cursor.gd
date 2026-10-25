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
## Anything may ask for a shape every frame with `HandCursor.want(kind)`; the strongest
## request of the frame wins, and this node (added once by main, processed last)
## applies it. Nothing asked = the arrow. The picture is scaled by a whole number to
## the window, like the rest of the 2D, and swapped into the system cursor (hardware,
## so it never lags behind the mouse).

enum { ARROW, LOOK, POINT, WALK, GRAB, RUB }

const DIR := "res://assets/textury/ui/"
const FILES := {ARROW: "cursor_arrow.png", LOOK: "cursor_look.png", POINT: "cursor_point.png", WALK: "cursor_walk.png", GRAB: "cursor_grab.png", RUB: "cursor_rub.png"}
## Where the click lands, as a share of the picture (the fingertip, the arrow's tip).
const HOT := {ARROW: Vector2(0.06, 0.04), LOOK: Vector2(0.5, 0.5), POINT: Vector2(0.12, 0.03), WALK: Vector2(0.5, 0.3), GRAB: Vector2(0.5, 0.45), RUB: Vector2(0.5, 0.5)}

static var _wanted := ARROW
static var _shown := -1
static var _scale := 0
static var _cache: Dictionary = {}   # kind -> Image at the current scale


## The strongest shape asked for this frame wins (RUB > GRAB > WALK > POINT > LOOK > ARROW).
static func want(kind: int) -> void:
	if kind > _wanted:
		_wanted = kind


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	get_tree().root.size_changed.connect(_rescale)
	_rescale()


func _process(_delta: float) -> void:
	var kind := _wanted
	_wanted = ARROW
	if kind != _shown:
		_apply(kind)


func _rescale() -> void:
	# Window pixels, not the logical 2D size: the system cursor is drawn unscaled.
	var h := float(get_tree().root.size.y)
	var k := clampi(int(h / 540.0), 1, 4)
	if k == _scale:
		return
	_scale = k
	_cache.clear()
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
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return
	var hot: Vector2 = HOT.get(kind, Vector2.ZERO)
	var spot := Vector2(floorf(hot.x * img.get_width()), floorf(hot.y * img.get_height()))
	# Every Control shows the arrow shape, so the arrow's picture is what changes.
	Input.set_custom_mouse_cursor(img, Input.CURSOR_ARROW, spot)
	Input.set_custom_mouse_cursor(img, Input.CURSOR_POINTING_HAND, spot)
