extends CanvasLayer

## Going into a building and out of it: the last frame freezes, takes a step closer
## (in) or back (out) twelve times a second and breaks up in an ordered dither of game
## pixels (materials/step_dissolve.gdshader), the new view showing through, half a second
## in all. InteriorManager calls play() just before it opens a room (the frame still
## shows the camp) and when a room has closed (the frame still shows the room).
## Over the rooms, the HUD and the minigames, under the pause menu.

const SHADER := preload("res://materials/step_dissolve.gdshader")
const FPS := 12.0
const STEPS := 6
## How much closer (in) or further (out) the frozen frame gets per step.
const ZOOM_IN := 0.035
const ZOOM_OUT := -0.02

var _rect: TextureRect
var _mat: ShaderMaterial
var _step := -1
var _acc := 0.0
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


## going_in: through the door into a room; else out of one.
func play(going_in: bool) -> void:
	if _rect == null or DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport()
	var img: Image = vp.get_texture().get_image() if vp != null else null
	if img == null or img.is_empty():
		return
	_rect.texture = ImageTexture.create_from_image(img)
	_zoom = ZOOM_IN if going_in else ZOOM_OUT
	_step = 0
	_acc = 0.0
	visible = true
	_apply()


func is_playing() -> bool:
	return _step >= 0


func _process(delta: float) -> void:
	if _step < 0:
		return
	# A room that takes a moment to build must not eat the steps: one at most a frame.
	_acc += minf(delta, 1.0 / FPS)
	if _acc < 1.0 / FPS:
		return
	_acc -= 1.0 / FPS
	_step += 1
	if _step >= STEPS:
		_step = -1
		visible = false
		_rect.texture = null
		return
	_apply()


func _apply() -> void:
	var size := get_viewport().get_visible_rect().size
	_rect.size = size
	_rect.position = Vector2.ZERO
	_rect.pivot_offset = size * 0.5
	var s := 1.0 + _zoom * float(_step)
	_rect.scale = Vector2(s, s)
	_mat.set_shader_parameter("progress", float(_step) / float(STEPS))
	# Whole game pixels: the world is drawn ~240 lines high.
	_mat.set_shader_parameter("cell", float(maxi(2, int(round(float(DisplayServer.window_get_size().y) / 240.0)))))
