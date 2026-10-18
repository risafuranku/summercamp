extends CanvasLayer

## Going into a building and out of it: the last frame freezes, comes a little closer
## (in) or goes back (out) and breaks up in an ordered dither of game pixels
## (materials/step_dissolve.gdshader), the new view showing through, half a second in
## all, smoothly at the full frame rate (it went in steps, twelve a second, until the
## playtest of 18. 10.: "choppy"). InteriorManager calls play() just before it opens a
## room (the frame still shows the camp) and when a room has closed (the frame still
## shows the room). Over the rooms, the HUD and the minigames, under the pause menu.

const SHADER := preload("res://materials/step_dissolve.gdshader")
const DURATION := 0.5
## How much closer (in) or further (out) the frozen frame gets over the whole of it.
const ZOOM_IN := 0.18
const ZOOM_OUT := -0.10
## The frame that builds the room (and reads this still back) is long: no single frame
## may move it on by more than this.
const MAX_STEP := 1.0 / 30.0

var _rect: TextureRect
var _mat: ShaderMaterial
var _t := -1.0
var _zoom := 0.0


func _init() -> void:
	name = "DoorTransition"
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)


## going_in: through the door into a room; else out of one. forward: the frame comes
## closer going out too (walked out through the door, not stepped back from the room).
func play(going_in: bool, forward := false) -> void:
	if _rect == null or DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport()
	var img: Image = vp.get_texture().get_image() if vp != null else null
	if img == null or img.is_empty():
		return
	_rect.texture = ImageTexture.create_from_image(img)
	_zoom = ZOOM_IN if going_in or forward else ZOOM_OUT
	_t = 0.0
	visible = true
	_apply()


func is_playing() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += minf(delta, MAX_STEP)
	if _t >= DURATION:
		_t = -1.0
		visible = false
		_rect.texture = null
		return
	_apply()


func _apply() -> void:
	var size := get_viewport().get_visible_rect().size
	_rect.size = size
	_rect.position = Vector2.ZERO
	_rect.pivot_offset = size * 0.5
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var s := 1.0 + _zoom * (1.0 - (1.0 - k) * (1.0 - k))
	_rect.scale = Vector2(s, s)
	_mat.set_shader_parameter("progress", k * k * (3.0 - 2.0 * k))
	# Whole game pixels: the world is drawn ~240 lines high.
	_mat.set_shader_parameter("cell", float(maxi(2, int(round(float(DisplayServer.window_get_size().y) / 240.0)))))
