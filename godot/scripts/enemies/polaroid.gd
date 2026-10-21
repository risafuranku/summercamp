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
const DEVELOP := 2.6
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


## The picture of `player` (a warden: its Head/Camera3D) from his lens at `lens`, in
## `world` (by tourist_brain.gd here; in co-op by coop_night.gd on the hunted warden's
## own machine, of them): as he saw them, from behind or the side; through a window `w`
## (photo_windows: its room's world, the glass, the eye in the room), them in their room
## from the glass once the room's own flash has died down (else it is only white); `big`,
## the last one: their face from right in front of it, looking at him.
func take_of(world: World3D, lens: Vector3, player: Node3D, extra: Texture2D, w: Dictionary = {}, big := false) -> void:
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D if player != null else null
	if cam == null:
		return
	if w.get("room_world") != null:
		var eye: Vector3 = w["eye"]
		var glass: Vector3 = w["glass"]
		var face := eye - glass
		face.y = 0.0
		var room_world: World3D = w["room_world"]
		await get_tree().create_timer(0.7).timeout
		take(room_world, glass + (eye - glass).normalized() * 0.3, eye + Vector3(0, -0.25, 0), Vector3(eye.x, eye.y - 1.55, eye.z), face.normalized(), extra)
		return
	if big:
		var at := cam.global_position
		var toward := lens - at
		toward.y = 0.0
		take(world, at + (lens - at).normalized() * 1.1, at + Vector3(0, -0.15, 0), player.global_position, toward.normalized(), null, true)
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	take(world, lens, cam.global_position + Vector3(0, -0.3, 0), player.global_position, fwd.normalized(), extra)


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
		# Just behind you and to one side: over your shoulder, into the lens.
		s.global_position = you + away.normalized() * 0.6 + away.normalized().cross(Vector3.UP) * 0.42
	# Out of his own body (the lens is where his head is), towards you; and in front of
	# whatever is between (a tree, a wall): he got the shot, so the picture has it clear.
	if from.distance_to(target) > 3.0:
		from += (target - from).normalized() * 0.8
	var space := world.direct_space_state
	if space != null:
		# From you out towards him: the first thing in the way (the ray starts inside you).
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(target, from))
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(target) > 0.8:
			from = (hit["position"] as Vector3) + (target - from).normalized() * 0.3
	var flash := OmniLight3D.new()
	flash.light_volumetric_fog_energy = 0.0
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
	land.light_volumetric_fog_energy = 0.0
	land.light_energy = 2.4 if reach > 6.0 else 0.6
	land.omni_range = 4.5
	holder.add_child(land)
	land.global_position = target + (from - target).normalized() * 1.4
	_cam.global_position = from
	_cam.look_at(target, Vector3.UP)
	# A long lens: you fill the picture, however far off he was.
	_cam.fov = 24.0 if big else clampf(rad_to_deg(2.0 * atan(1.7 / maxf(reach, 0.1))), 14.0, 52.0)
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
	var stepped := floorf(sqrt(dev) * 8.0) / 8.0
	_rect.modulate = Color(0.45, 0.44, 0.42).lerp(Color(1, 1, 1), stepped)
	_rect.self_modulate.a = 0.3 + 0.7 * stepped
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
