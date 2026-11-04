extends CanvasLayer

## A match struck out of the bag (the Jednota has had no batteries for years): your left
## hand comes up with it like the lighter (hands.gd, drawn on the hands' coarse pixels and in
## their light), the flame in its steps, a small warm light round you in the world for the few
## seconds it burns. Wind takes it sooner and rain sooner still; it goes out by itself.
## inventory.gd strikes it; the box's count is the bag's.

const HANDS = preload("res://scripts/ui/hands.gd")
const TEX := "res://assets/textury/shop/hand_match.png"
const FLAMES := ["res://assets/textury/camp/votive_flame_0.png", "res://assets/textury/camp/votive_flame_1.png", "res://assets/textury/camp/votive_flame_2.png", "res://assets/textury/camp/votive_flame_3.png"]
const SFX_STRIKE := "res://assets/sfx/shop/match_strike.mp3"
const SFX_OUT := "res://assets/sfx/shop/match_out.mp3"
const FPS := 12.0
const BURN_SEC := 11.0
## On the hand's picture: the match's head, where the flame sits.
const HEAD := Vector2(71, 3)
## How much of the picture shows above the bottom edge.
const SHOWN := 0.8

static var _burning: Node

var player: Node3D
var pockets
var _hands: Node
var _rect: TextureRect
var _flame: TextureRect
var _flames: Array = []
var _light: OmniLight3D
var _audio: AudioStreamPlayer
var _left := BURN_SEC
var _up := 0.0
var _acc := 0.0
var _step := 0
var _rng := RandomNumberGenerator.new()


## `bag`: the inventory (it has the player and the pockets).
static func strike(bag: Node) -> void:
	if _burning != null and is_instance_valid(_burning):
		_burning.queue_free()
	var m: Node = load("res://scripts/town/counter_match.gd").new()
	m.player = bag._player()
	m.pockets = bag.pockets
	bag.add_child(m)
	_burning = m


func _init() -> void:
	layer = 59


func _ready() -> void:
	_rng.randomize()
	_hands = HANDS.of(self)
	if _hands != null:
		_hands.claim("left", "lighter#match")
	_rect = TextureRect.new()
	_rect.texture = load(TEX) if ResourceLoader.exists(TEX) else null
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_flame = TextureRect.new()
	_flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flame.stretch_mode = TextureRect.STRETCH_SCALE
	_flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flame)
	for f in FLAMES:
		if ResourceLoader.exists(f):
			_flames.append(load(f))
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_sound(SFX_STRIKE, -3.0)
	if player != null:
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.72, 0.38)
		_light.light_energy = 2.2
		_light.omni_range = 7.0
		_light.omni_attenuation = 1.2
		_light.shadow_enabled = false
		_light.position = Vector3(-0.2, 1.35, -0.45)
		player.add_child(_light)
	if pockets != null and pockets.has_method("_env"):
		var env: Dictionary = pockets._env()
		if not bool(env.get("indoors", false)):
			_left = BURN_SEC * (1.0 - 0.7 * minf(1.0, float(env.get("wind", 0.0)))) * (0.35 if float(env.get("rain", 0.0)) > 0.0 else 1.0)


func _exit_tree() -> void:
	if _hands != null:
		_hands.release("left", "lighter#match")
	if _light != null and is_instance_valid(_light):
		_light.queue_free()


func _sound(path: String, db: float) -> void:
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.volume_db = db
		_audio.play()


func _process(delta: float) -> void:
	_left -= delta
	_acc += delta
	if _left <= -0.7:
		queue_free()
		return
	if _acc < 1.0 / FPS:
		return
	_acc = fmod(_acc, 1.0 / FPS)
	_step += 1
	var lit := _left > 0.0
	if not lit and _light != null and is_instance_valid(_light):
		_sound(SFX_OUT, -4.0)
		_light.queue_free()
		_light = null
	_up = move_toward(_up, 1.0 if lit else 0.0, 0.25)
	if lit and _hands != null:
		_hands.glow("flame", Color(0.95, 0.66, 0.3) * (0.85 + 0.15 * float(_step % 3 == 0)))
	if _light != null:
		# It burns down, and shakes as it goes.
		_light.light_energy = (2.2 + _rng.randf_range(-0.3, 0.3)) * clampf(_left / 2.0, 0.35, 1.0)
	_place(lit)


func _place(lit: bool) -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := HANDS.px(vp.y)
	var tex := _rect.texture
	if tex == null:
		return
	# Held by the pause menu, a close-up, a room's own view: out of sight, still burning.
	var hide_it := get_tree().paused or _covered()
	_rect.visible = not hide_it
	_flame.visible = lit and not hide_it and not _flames.is_empty()
	var size := Vector2(tex.get_size()) * s
	_rect.size = size
	var motion: Vector2 = _hands.motion if _hands != null else Vector2.ZERO
	var at := Vector2(vp.x * 0.34 - size.x * 0.5, vp.y - size.y * SHOWN * _up + (1.0 - _up) * size.y * 0.2) + motion * s
	_rect.position = at.floor()
	if _hands != null:
		_rect.material = _hands.material
		_flame.material = null
	if _flame.visible:
		var f: Texture2D = _flames[_step % _flames.size()]
		_flame.texture = f
		var fs := Vector2(f.get_size()) * s
		_flame.size = fs
		_flame.position = (at + HEAD * s - Vector2(fs.x * 0.5, fs.y * 0.92)).floor()


func _covered() -> bool:
	for n in get_tree().get_nodes_in_group("closeup"):
		if n is CanvasLayer and (n as CanvasLayer).visible:
			return true
	return false
