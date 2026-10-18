extends CanvasLayer

## The torch in your hand, held out in front of you like a Build-engine weapon sprite
## (assets/textury/hands_lo/torch.png, the beam going away from you): low at the right,
## above the HUD bar, swinging with your step and trailing a turn with the beam
## (outdoors: player_controller.get_beam_lag(); in a room: toward the cursor,
## interior_torch.gd). It comes up when the torch goes on and drops when it goes off.
## Moved in steps (12 a second) and on the coarse pixel grid of the hands (hands.gd),
## lit by the place you stand in like any sprite.
##
## The right hand is the torch's unless it works or holds a bottle (hands.gd): then the
## torch drops, changes hands and comes up in the left (the sprite mirrored, as Build
## mirrored its sprites); with both hands busy it is in your pocket and dark.

const HANDS = preload("res://scripts/ui/hands.gd")
const TEX := "res://assets/textury/hands_lo/torch.png"
const FPS := 12.0
## How much of the sprite is up above the bottom edge (or the HUD bar): the torch head
## low in the view, the rest of the arm out of it (playtest: "too high, lower and smaller").
const SHOWN := 0.5

## Set by the owner each frame.
var bar_px := 0.0
var lag := Vector2.ZERO      # radians: yaw right +, pitch up +
var bob := Vector2.ZERO      # pixels
var dim := false             # the cell is dying / the beam is off for a blink

var _rect: TextureRect
var _up := 0.0
var _want := false
var _acc := 0.0
var _side := "right"
var _hands: Node


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


## The player's sprint_lower (0..1), in whole steps of a sixth.
func _run_lower() -> float:
	var main := get_tree().current_scene if get_tree() != null else null
	var p = main.get("_player") if main != null else null
	var v = p.get("sprint_lower") if p != null else null
	return floorf(float(v) * 6.0) / 6.0 if v != null else 0.0


func _process(delta: float) -> void:
	if _hands == null or not is_instance_valid(_hands):
		_hands = HANDS.of(self)
	var side := "right"
	if _hands != null:
		if _want:
			_hands.claim("right", "torch#%d" % get_instance_id())
		else:
			_hands.release("right", "torch#%d" % get_instance_id())
		side = _hands.torch_hand()
	# Changing hands: down out of view first, then up in the other.
	var up_want := _want and side != "" and side == _side
	_up = move_toward(_up, 1.0 if up_want else 0.0, delta * 4.5)
	if _up <= 0.0 and side != "" and side != _side:
		_side = side
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
	var k := HANDS.px(vp.y)
	_rect.size = _rect.texture.get_size() * k
	var raise := 1.0 - (1.0 - _up) * (1.0 - _up)
	# The lens just right of the middle, where the beam comes out (player_controller
	# BEAM_YAW_DEG); lower while running.
	var x := vp.x * 0.47 + clampf(lag.x, -0.5, 0.5) * vp.x * 0.55 + bob.x * k
	# Never off the edge: at most the sleeve goes out of the view.
	x = clampf(x, vp.x * 0.28, vp.x - _rect.size.x * 0.82)
	var run := _run_lower()
	var y := vp.y - bar_px - _rect.size.y * SHOWN * raise + _rect.size.y * 0.04 * (1.0 - raise) - clampf(lag.y, -0.4, 0.4) * vp.y * 0.3 + bob.y * k + _rect.size.y * 0.12 * run
	_rect.flip_h = _side == "left"
	if _side == "left":
		# The same hold mirrored, further out: the middle is the other hand's.
		x = vp.x - x - _rect.size.x - vp.x * 0.12
	# On the hands' own pixel grid: whole sprite pixels, no turning (a turned sprite is
	# not pixel art any more).
	var mo: Vector2 = _hands.motion if _hands != null else Vector2.ZERO
	_rect.position = ((Vector2(x, y) + mo * k * 0.5) / k).floor() * k
	_rect.rotation = 0.0
	var l: Color = _hands.light if _hands != null else Color.WHITE
	_rect.modulate = l * (Color(0.72, 0.7, 0.66) if dim else Color.WHITE)
	_rect.modulate.a = 1.0
