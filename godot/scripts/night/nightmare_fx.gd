extends CanvasLayer

## What the night does to the picture and the sound when something is near or has you:
## one layer every night enemy uses (DESIGN §5), over the world, the HUD and the rooms,
## under the door transition and the pause menu.
##
##   var fx := NIGHTMARE_FX.get_for(node)        # finds or makes the one layer
##   fx.set_dread("girl", 0.6)                    # each tick: how close it is (0-1)
##   fx.set_presence("silent_man", 0.7)          # each tick: the sixth sense: a drone in the
##                                                # ears, the heart, the edges closing in
##   fx.glitch(1.0, 1.2)                          # a hit: tears, split channels, roar
##   fx.subliminal(tex, 2)                        # a face for two frames, then gone
##   fx.freeze(0.15)                              # the frame stops dead for a beat
##   fx.red_flash(0.8)
##   fx.tinnitus(4.0)                             # a ring, the world muffled under it
##   fx.set_eyes("girl", head, cam, open, tilt)   # each tick: its eyes, drawn on the screen
##   fx.close_up(tex, scale, stretch_y, shake, rot, off) # each tick of a strike: its face on you
##   fx.close_up_off(); fx.set_black(a)
##
## Eyes are drawn here, not in the world: crisp whole game pixels with a glow, the same
## size however far (a 3D sprite of two pixels shimmered under the PS1 snap and was lost
## at distance; playtest 18. 10.). The thing decides whether they can be seen at all.
##
## The dread is the largest any source has set this frame, eased; a source that stops
## setting it lets it fall. Nothing here is drawn while all of it is at rest.

const SHADER := preload("res://materials/nightmare_screen.gdshader")
const NODE_NAME := "NightmareFX"
const TINNITUS_HZ := 5600.0

var _screen: ColorRect
var _mat: ShaderMaterial
var _flash: ColorRect
var _sub: TextureRect
var _frozen: TextureRect
var _sub_frames := 0
var _freeze_t := 0.0
var _amount := 0.0
var _amount_fall := 1.0
var _dread := 0.0
var _dread_src := {}
var _time := 0.0
var _ring: AudioStreamPlayer
var _ring_pb: AudioStreamGeneratorPlayback
var _ring_t := 0.0
var _ring_len := 0.0
var _ring_phase := 0.0
var _lowpass: AudioEffectLowPassFilter
var _lowpass_idx := -1
var _eyes_layer: Control
var _eyes := {}                    # source -> {pos: Vector2 (window), spread, open, tilt, near}
var _close: TextureRect
var _black: ColorRect
## The sixth sense: the largest presence any source set this frame, eased; a generated
## drone (two low tones beating, a pressure whine over them) and the heart, faster as it
## rises; the picture's edges close in with it.
var _presence := 0.0
var _presence_src := {}
var _sense: AudioStreamPlayer
var _sense_pb: AudioStreamGeneratorPlayback
var _sense_ph := [0.0, 0.0, 0.0]
var _beat_t := 0.0
var _beat_env := 0.0
var _beat_n := 0
const SENSE_RATE := 22050.0


## The one layer under the tree's root (made the first time).
static func get_for(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null
	var root := node.get_tree().root
	var fx := root.get_node_or_null(NODE_NAME)
	if fx == null:
		fx = (load("res://scripts/night/nightmare_fx.gd") as GDScript).new()
		root.add_child.call_deferred(fx)
	return fx


func _init() -> void:
	name = NODE_NAME
	layer = 104
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## Its parts are made with it, not on entering the tree: it is added deferred, and the
## first calls can come before that.
func _build() -> void:
	_screen = ColorRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_screen.material = _mat
	_screen.visible = false
	add_child(_screen)
	_frozen = TextureRect.new()
	_frozen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frozen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frozen.stretch_mode = TextureRect.STRETCH_SCALE
	_frozen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frozen.visible = false
	add_child(_frozen)
	_sub = TextureRect.new()
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sub.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sub.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sub.visible = false
	add_child(_sub)
	_close = TextureRect.new()
	_close.set_anchors_preset(Control.PRESET_FULL_RECT)
	_close.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_close.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_close.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_close.visible = false
	add_child(_close)
	_eyes_layer = Control.new()
	_eyes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_eyes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eyes_layer.draw.connect(_draw_eyes)
	add_child(_eyes_layer)
	# The screen effect goes over the close-up (it tears with the rest); the eyes go over
	# the screen effect, or its split channels turn the two white points into a rainbow.
	move_child(_screen, get_child_count() - 1)
	move_child(_eyes_layer, get_child_count() - 1)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.5, 0.0, 0.0, 0.0)
	_flash.visible = false
	add_child(_flash)
	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.color = Color(0, 0, 0, 0)
	_black.visible = false
	add_child(_black)
	_ring = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	_ring.stream = gen
	_ring.volume_db = -14.0
	add_child(_ring)


## How close a thing is (0 far, 1 on you), set every tick by whatever is out there.
func set_dread(source: String, level: float) -> void:
	_dread_src[source] = clampf(level, 0.0, 1.0)


## The sixth sense of something near you in the dark (0 nothing .. 1 at your neck).
func set_presence(source: String, level: float) -> void:
	_presence_src[source] = clampf(level, 0.0, 1.0)


func presence() -> float:
	return _presence


## Its eyes this frame at world point `head` (the middle between them) seen by `cam`:
## `open` 0-1 (a blink), `tilt` radians (the head going over), `half_gap` metres from the
## middle to each eye. Not drawn behind the camera; the caller checks the line of sight.
func set_eyes(source: String, head: Vector3, cam: Camera3D, open: float = 1.0, tilt: float = 0.0, half_gap: float = 0.035, open2: float = -1.0) -> void:
	if not is_inside_tree():
		return
	if cam == null or not is_instance_valid(cam) or cam.is_position_behind(head):
		return
	var vp := cam.get_viewport()
	if vp == null:
		return
	var k := get_viewport().get_visible_rect().size / vp.get_visible_rect().size
	var c := cam.unproject_position(head) * k
	var right := cam.global_transform.basis.x
	var e := cam.unproject_position(head + right * half_gap) * k
	var dist := cam.global_position.distance_to(head)
	_eyes[source] = {"pos": c, "spread": (e - c).length(), "open": clampf(open, 0.0, 1.0), "open2": clampf(open if open2 < 0.0 else open2, 0.0, 1.0), "tilt": tilt, "near": clampf(1.0 - dist / 30.0, 0.0, 1.0)}


## A face on you for this frame (call every frame of the strike; `close_up_off` ends it).
## `scale` 1 = the screen's height; `stretch_y` pulls it taller (a jaw going); `shake` in
## screen heights.
func close_up(tex: Texture2D, scale: float, stretch_y: float = 1.0, shake: float = 0.0, rot: float = 0.0, off: Vector2 = Vector2.ZERO) -> void:
	if not is_inside_tree():
		return
	if tex == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_close.texture = tex
	_close.visible = true
	_close.pivot_offset = vp * 0.5
	_close.scale = Vector2(scale, scale * stretch_y)
	_close.rotation = rot
	var j := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * vp.y
	_close.position = (j + off * vp).floor()


func close_up_off() -> void:
	_close.visible = false
	_close.texture = null


func set_black(alpha: float) -> void:
	_black.color.a = clampf(alpha, 0.0, 1.0)
	_black.visible = _black.color.a > 0.0


## A hit to the picture: `amount` 0-1, falling away over `seconds`.
func glitch(amount: float, seconds: float) -> void:
	_amount = maxf(_amount, clampf(amount, 0.0, 1.0))
	_amount_fall = maxf(0.05, seconds)


## A picture over everything for `frames` rendered frames (a face, then nothing).
func subliminal(tex: Texture2D, frames: int = 2, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	if not is_inside_tree():
		return
	if tex == null:
		return
	_sub.texture = tex
	_sub.modulate = tint
	_sub.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_sub.scale = Vector2.ONE * scale
	_sub.visible = true
	_sub_frames = maxi(1, frames)


## The frame stops dead for `seconds` (the world goes on under it).
func freeze(seconds: float) -> void:
	if not is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	_frozen.texture = ImageTexture.create_from_image(img)
	_frozen.visible = true
	_freeze_t = seconds


func red_flash(alpha: float) -> void:
	_flash.color.a = maxf(_flash.color.a, clampf(alpha, 0.0, 1.0))
	_flash.visible = true


## A high ring in the ears that fades over `seconds`, the world muffled under it.
func tinnitus(seconds: float) -> void:
	if not is_inside_tree():
		return
	_ring_len = maxf(0.5, seconds)
	_ring_t = 0.0
	if not _ring.playing:
		_ring.play()
		_ring_pb = _ring.get_stream_playback() as AudioStreamGeneratorPlayback
	var master := AudioServer.get_bus_index("Master")
	if _lowpass == null:
		_lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(master, _lowpass)
		_lowpass_idx = AudioServer.get_bus_effect_count(master) - 1
	_lowpass.cutoff_hz = 500.0


func _process(delta: float) -> void:
	_time += delta
	# Dread: the largest source, eased; sources forget themselves each frame.
	var want := 0.0
	for k in _dread_src:
		want = maxf(want, float(_dread_src[k]))
	_dread_src.clear()
	_dread = move_toward(_dread, want, delta * (0.8 if want > _dread else 0.35))
	_amount = maxf(0.0, _amount - delta / _amount_fall)
	var want_p := 0.0
	for k in _presence_src:
		want_p = maxf(want_p, float(_presence_src[k]))
	_presence_src.clear()
	_presence = move_toward(_presence, want_p, delta * (0.5 if want_p > _presence else 0.3))
	_update_sense(delta)
	var on := _dread > 0.01 or _amount > 0.01 or _presence > 0.01
	_screen.visible = on
	if on:
		_mat.set_shader_parameter("amount", _amount)
		_mat.set_shader_parameter("dread", _dread)
		_mat.set_shader_parameter("time_s", _time)
		_mat.set_shader_parameter("squeeze", _presence)
		_mat.set_shader_parameter("beat", _beat_env)
		var ws := DisplayServer.window_get_size()
		_mat.set_shader_parameter("aspect", float(ws.x) / maxf(1.0, float(ws.y)))
		_mat.set_shader_parameter("cell", float(maxi(2, int(round(float(DisplayServer.window_get_size().y) / 240.0)))))
	if _sub_frames > 0:
		_sub_frames -= 1
		if _sub_frames <= 0:
			_sub.visible = false
	if _freeze_t > 0.0:
		_freeze_t -= delta
		if _freeze_t <= 0.0:
			_frozen.visible = false
			_frozen.texture = null
	_eyes_layer.queue_redraw()
	if _flash.visible:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.6)
		_flash.visible = _flash.color.a > 0.0
	_update_ring(delta)


## Two pale points, one game pixel each, close together; nothing round them. Each eye
## its own `open` (they need not blink together). Whole game pixels, so they never
## shimmer. (A glow and a glint read as a star, playtest 18. 10.: minimal is worse.)
func _draw_eyes() -> void:
	var cell := float(maxi(2, int(round(float(DisplayServer.window_get_size().y) / 240.0))))
	for src in _eyes:
		var e: Dictionary = _eyes[src]
		var gap := maxf(float(e["spread"]), cell)
		var dir := Vector2(cos(float(e["tilt"])), sin(float(e["tilt"])))
		var c: Vector2 = e["pos"]
		var i := 0
		for side in [-1.0, 1.0]:
			var open: float = e["open"] if i == 0 else e["open2"]
			i += 1
			if open <= 0.2:
				continue
			var p: Vector2 = (c + dir * gap * side - Vector2(cell, cell) * 0.5).snapped(Vector2(cell, cell))
			_eyes_layer.draw_rect(Rect2(p, Vector2(cell, cell)), Color(0.86, 0.84, 0.74, 0.85 * open))
	_eyes.clear()


## The drone and the heart, made here (no file): two low tones a few hertz apart so they
## beat, a thin whine over them like pressure in the ears, rising with the presence; the
## heart a double thump, 56 a minute at first, 140 at the end.
func _update_sense(delta: float) -> void:
	if _presence <= 0.01:
		if _sense != null and _sense.playing:
			_sense.stop()
			_sense_pb = null
		return
	if _sense == null:
		_sense = AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = SENSE_RATE
		gen.buffer_length = 0.25
		_sense.stream = gen
		_sense.volume_db = -4.0
		add_child(_sense)
	if not _sense.playing:
		_sense.play()
		_sense_pb = _sense.get_stream_playback() as AudioStreamGeneratorPlayback
	if _sense_pb == null:
		return
	var p := _presence
	var bpm := lerpf(56.0, 140.0, p * p)
	var period := 60.0 / bpm
	var frames := _sense_pb.get_frames_available()
	var dt := 1.0 / SENSE_RATE
	var f1 := lerpf(48.0, 62.0, p)
	var f2 := f1 + lerpf(1.5, 6.0, p)
	var fw := lerpf(2600.0, 3900.0, p)
	var a_drone := 0.10 * clampf(p * 1.6, 0.0, 1.0)
	var a_whine := 0.018 * clampf((p - 0.35) / 0.65, 0.0, 1.0)
	var a_heart := 0.5 * clampf((p - 0.15) / 0.5, 0.0, 1.0)
	for _i in frames:
		_beat_t += dt
		if _beat_t >= period:
			_beat_t -= period
		# Lub-dub: a thump, and a softer one a short way after.
		var tb := _beat_t
		var env := 0.0
		if tb < 0.12:
			env = exp(-tb * 38.0)
		elif tb > 0.2 and tb < 0.32:
			env = 0.6 * exp(-(tb - 0.2) * 40.0)
		_beat_env = env
		_sense_ph[0] = fmod(_sense_ph[0] + f1 * dt, 1.0)
		_sense_ph[1] = fmod(_sense_ph[1] + f2 * dt, 1.0)
		_sense_ph[2] = fmod(_sense_ph[2] + fw * dt, 1.0)
		var heart := sin(TAU * 52.0 * tb) * env * a_heart
		var v := (sin(TAU * _sense_ph[0]) + sin(TAU * _sense_ph[1])) * 0.5 * a_drone + sin(TAU * _sense_ph[2]) * a_whine + heart
		_sense_pb.push_frame(Vector2(v, v))


func _update_ring(delta: float) -> void:
	if _ring_len <= 0.0:
		return
	_ring_t += delta
	var k := clampf(_ring_t / _ring_len, 0.0, 1.0)
	if _lowpass != null:
		_lowpass.cutoff_hz = lerpf(500.0, 20000.0, k * k)
	if _ring_pb != null:
		var amp := 0.22 * (1.0 - k)
		var frames := _ring_pb.get_frames_available()
		var step := TINNITUS_HZ / 22050.0
		for _i in frames:
			var v := sin(_ring_phase * TAU) * amp
			_ring_pb.push_frame(Vector2(v, v))
			_ring_phase = fmod(_ring_phase + step, 1.0)
	if k >= 1.0:
		_ring_len = 0.0
		_ring.stop()
		_ring_pb = null
		var master := AudioServer.get_bus_index("Master")
		if _lowpass != null and _lowpass_idx >= 0 and _lowpass_idx < AudioServer.get_bus_effect_count(master):
			AudioServer.remove_bus_effect(master, _lowpass_idx)
		_lowpass = null
		_lowpass_idx = -1
