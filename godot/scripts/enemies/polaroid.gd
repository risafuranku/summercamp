extends CanvasLayer

## The Photographer's pictures of you (scripts/enemies/tourist_brain.gd). They are real:
## a camera where his head is renders the place, and you in it (your warden's own figure,
## stood where you are for that one frame, from behind or from the side as he saw you).
## Now and then something is in the picture that was not there: him, right behind you,
## grinning into the lens, though he was across the field when it was taken.
##
## On the screen the picture slides in at the lower right in its white frame and develops
## (grey, then a ghost of it, then all of it) with the chemical hum, sits there a moment,
## and slides off. The last one of a night, when the flash kills you, fills the screen
## instead: your own face, close, his grin at the edge of it.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const FIGURE = preload("res://scripts/coop/remote_player.gd")
const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const FRAME := "res://assets/textury/npc/ph_polaroid_frame.png"
const SFX_DEVELOP := "res://assets/sfx/npc/ph_develop.mp3"
const PX := 112
const DEVELOP := 3.4
const HOLD := 2.6

var _vp: SubViewport
var _cam: Camera3D
var _rect: TextureRect
var _frame_rect: TextureRect
var _shown: Control
var _t := -1.0
var _big := false
var _img: ImageTexture
var _audio: AudioStreamPlayer
var _frame_tex: Texture2D


func _init() -> void:
	layer = 118
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.far = 120.0
	_vp.add_child(_cam)
	_shown = Control.new()
	_shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown.visible = false
	add_child(_shown)
	_frame_tex = load(FRAME) if ResourceLoader.exists(FRAME) else null
	_frame_rect = TextureRect.new()
	_frame_rect.texture = _frame_tex
	_frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown.add_child(_frame_rect)
	_rect = TextureRect.new()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown.add_child(_rect)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -6.0
	add_child(_audio)


## Takes the picture: from `from` (his lens) at `target` (your head), in `world`; `you`
## stands your warden there for the frame (facing `face`); `extra` a Texture2D of him
## to stand right behind you in it (or null). `big`: the last one, full screen.
func take(world: World3D, from: Vector3, target: Vector3, you: Vector3, face: Vector3, extra: Texture2D, big := false) -> void:
	if world == null or DisplayServer.get_name() == "headless":
		return
	_vp.world_3d = world
	var holder := Node3D.new()
	holder.name = "PolaroidStandIns"
	_vp.add_child(holder)
	var look: Dictionary = Coop.my_look() if Coop != null else {"m": 1, "c": 0}
	var fig = FIGURE.new()
	holder.add_child(fig)
	fig.setup(int(look.get("m", 1)), int(look.get("c", 0)), true)
	fig.show_at(you, "stand", false, face)
	if extra != null:
		# Him, behind you, much too close, flash-lit.
		var s := Sprite3D.new()
		s.texture = extra
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = false
		s.pixel_size = 1.95 / float(extra.get_height())
		s.offset = Vector2(0, extra.get_height() * 0.5)
		holder.add_child(s)
		var away := (you - from)
		away.y = 0.0
		s.global_position = you + away.normalized() * 0.55 + Vector3(0.18, 0, 0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.95, 0.97, 1.0)
	# A room is small: the same flash would only be white.
	var reach := from.distance_to(target)
	flash.light_energy = 6.0 if reach > 6.0 else 1.2
	flash.omni_range = clampf(reach * 2.5, 4.0, 18.0)
	holder.add_child(flash)
	flash.global_position = from
	# Where it lands: you, white, the dark round you (a flash does not reach that far,
	# but in the picture it always has).
	var land := OmniLight3D.new()
	land.light_color = Color(0.95, 0.97, 1.0)
	land.light_energy = 2.4 if reach > 6.0 else 0.6
	land.omni_range = 4.5
	holder.add_child(land)
	land.global_position = target + (from - target).normalized() * 1.4
	_cam.global_position = from
	_cam.look_at(target, Vector3.UP)
	_cam.fov = 24.0 if big else 52.0
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	holder.queue_free()
	if img == null or img.is_empty():
		return
	_wash(img)
	_img = ImageTexture.create_from_image(img)
	_show(big)


## Flash-blown, yellowed, the corners dark: an instant photo.
func _wash(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			c = c.lerp(Color(l, l, l), 0.35)
			c = Color(c.r * 1.08 + 0.05, c.g * 1.0 + 0.03, c.b * 0.82, 1.0)
			var d := Vector2(float(x) / w - 0.5, float(y) / h - 0.5).length()
			c = c.darkened(clampf((d - 0.32) * 1.6, 0.0, 0.7))
			img.set_pixel(x, y, c)


func _show(big: bool) -> void:
	_big = big
	_t = 0.0
	_rect.texture = _img
	_shown.visible = true
	if ResourceLoader.exists(SFX_DEVELOP):
		_audio.stream = load(SFX_DEVELOP)
		_audio.play()
	_layout()


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var k := maxi(1, int(floor(vp.y / 240.0)))
	var fw := 70.0 * k
	if _big:
		fw = floorf(vp.y * 0.78 / 1.22)
	var fh := fw * 1.22
	_shown.size = Vector2(fw, fh)
	_frame_rect.size = Vector2(fw, fh)
	var inset := fw * 0.07
	_rect.position = Vector2(inset, inset)
	_rect.size = Vector2(fw - inset * 2.0, fw - inset * 2.0)
	_shown.pivot_offset = _shown.size * 0.5
	if _big:
		_shown.position = ((vp - _shown.size) * 0.5).floor()
		_shown.rotation = -0.03
	else:
		_shown.rotation = 0.08


func showing() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var vp := get_viewport().get_visible_rect().size
	# Developing: from flat grey through a ghost of it to all of it, in steps.
	var dev := clampf(_t / DEVELOP, 0.0, 1.0)
	var stepped := floorf(dev * 8.0) / 8.0
	_rect.modulate = Color(0.32, 0.31, 0.3).lerp(Color(1, 1, 1), stepped)
	_rect.self_modulate.a = 0.15 + 0.85 * stepped
	if not _big:
		var slide := clampf(_t / 0.35, 0.0, 1.0)
		var out := clampf((_t - DEVELOP - HOLD) / 0.4, 0.0, 1.0)
		var x := vp.x - _shown.size.x - 24.0
		_shown.position = Vector2(x + (1.0 - slide) * (_shown.size.x + 40.0) + out * (_shown.size.x + 60.0), vp.y - _shown.size.y - 90.0 - (1.0 - slide) * 30.0).floor()
		if out >= 1.0:
			_shown.visible = false
			_t = -1.0
	elif _t > DEVELOP + HOLD + 1.5:
		_shown.visible = false
		_t = -1.0
