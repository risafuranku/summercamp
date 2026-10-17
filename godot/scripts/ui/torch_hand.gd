extends CanvasLayer

## The torch in your hand, held out in front of you like a Build-engine weapon sprite
## (assets/textury/hands/torch.png, the beam going away from you): low at the right,
## above the HUD bar, swinging with your step and trailing a turn with the beam
## (outdoors: player_controller.get_beam_lag(); in a room: toward the cursor,
## interior_torch.gd). It comes up when the torch goes on and drops when it goes off.
## Moved in steps (12 a second), like everything else.

const TEX := "res://assets/textury/hands/torch.png"
const FPS := 12.0

## Set by the owner each frame.
var bar_px := 0.0
var lag := Vector2.ZERO      # radians: yaw right +, pitch up +
var bob := Vector2.ZERO      # pixels
var dim := false             # the cell is dying / the beam is off for a blink

var _rect: TextureRect
var _up := 0.0
var _want := false
var _acc := 0.0


func _init() -> void:
	layer = 59
	visible = false


func _ready() -> void:
	_rect = TextureRect.new()
	_rect.texture = load(TEX) if ResourceLoader.exists(TEX) else null
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func show_torch(on: bool) -> void:
	_want = on


## Drawn inside another layer instead (a room's: just above its 3D view, under its hints
## and panels), at child `index` of `parent`.
func embed(parent: Node, index: int) -> void:
	if _rect == null:
		return
	_rect.get_parent().remove_child(_rect)
	parent.add_child(_rect)
	parent.move_child(_rect, clampi(index, 0, parent.get_child_count() - 1))


func _process(delta: float) -> void:
	_up = move_toward(_up, 1.0 if _want else 0.0, delta * 4.5)
	visible = _up > 0.0 and _rect != null and _rect.texture != null
	if _rect != null:
		_rect.visible = visible
	if not visible:
		return
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	var vp := get_viewport().get_visible_rect().size
	var k := float(maxi(1, int(round(vp.y / 300.0))))
	_rect.size = _rect.texture.get_size() * k
	var raise := 1.0 - (1.0 - _up) * (1.0 - _up)
	var x := vp.x * 0.6 + clampf(lag.x, -0.5, 0.5) * vp.x * 0.55 + bob.x * k
	# Never off the edge: at most the sleeve goes out of the view.
	x = clampf(x, vp.x * 0.28, vp.x - _rect.size.x * 0.82)
	var y := vp.y - bar_px - _rect.size.y * 0.8 * raise + _rect.size.y * 0.12 - clampf(lag.y, -0.4, 0.4) * vp.y * 0.45 + bob.y * k
	_rect.position = Vector2(x, y).floor()
	_rect.rotation = clampf(lag.x, -0.5, 0.5) * 0.35
	_rect.pivot_offset = _rect.size * Vector2(0.7, 1.0)
	_rect.modulate = Color(0.72, 0.7, 0.66) if dim else Color.WHITE
