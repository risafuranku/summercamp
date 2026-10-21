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
## A second picture over the close-up (hands round your head while the face is there).
var _over: TextureRect
var _black: ColorRect
## Blood on the lens (`blood`): splats of game pixels and the drips running down from
## them, drying darker and fading. Drawn only while there is some.
var _blood_layer: Control
var _splats: Array = []            # {cells: [[Vector2 cell, shade]], a}
var _drips: Array = []             # {x, y, v, len, w, shade}
var _blood_a := 0.0
var _white: ColorRect
var _white_t := 0.0
## A face split down the middle (`split`): its two halves pulled apart, and between them
## the wet dark inside, rows of teeth along both edges, strings across. One frame.
var _halves: Array = []            # two TextureRects
var _gap_layer: Control
var _gap := {}                     # {cx, w, top, bottom, t}
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
## The world muffled under the presence (a low-pass on Master, its own, found by itself).
var _muffle: AudioEffectLowPassFilter
const SENSE_RATE := 22050.0
## The ears in a tight spot (the user 21. 10.: "the whistling and hissing when you are in
## trouble is a good one, work it out more"): what the presence, or your own wounds, do to
## your hearing. `_ears` is the larger of the presence and the strain (low health, from
## main's `_player_health`). A ringing that will not hold still (two high tones beating,
## wandering in pitch, one ear louder than the other, a third, sour one at the worst),
## the blood whooshing in your ears a moment after each beat of the heart, a hiss under
## it all; your own breathing, faster; a dry swallow now and then; and at the worst the
## ears give out for a moment (the world gone, then the pop).
var _strain := 0.0
var _ears := 0.0
var _noise_lp := 0.0
var _noise_hp := 0.0
var _ear_ph := [0.0, 0.0]
var _ear_t := 0.0
var _breath: AudioStreamPlayer
var _swallow_wait := 9.0
var _drop_left := 0.0
var _drop_wait := 4.0
var _deaf: AudioEffectAmplify
var _ring_t2 := 0.0
var _ring_ph2 := 0.0
var _ring_lp := 0.0
const SFX_BREATH := "res://assets/sfx/night/ears_breath.mp3"
const SFX_SWALLOW := "res://assets/sfx/night/ears_swallow.mp3"
const SFX_POP := "res://assets/sfx/night/ears_pop.mp3"


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


## The close-ups in the world's game pixels and palette (materials/closeup_retro.gdshader):
## one material for every picture laid over the screen at night (here, the boy's face over
## the board and in the pipes), its game pixel the world's (RetroRender.internal_scale).
const CLOSEUP_SHADER = preload("res://materials/closeup_retro.gdshader")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
static var _retro_mat: ShaderMaterial
const CLOSEUP_LINES := 100.0


static func retro_material() -> ShaderMaterial:
	if _retro_mat == null:
		_retro_mat = ShaderMaterial.new()
		_retro_mat.shader = CLOSEUP_SHADER
		_retro_mat.set_shader_parameter("palette_lut", RETRO_RENDER.LUT)
	return _retro_mat


## The game pixel for a screen this high, and the palette as the settings have it.
static func update_retro(screen_height: float) -> void:
	var m := retro_material()
	# About CLOSEUP_LINES of them down the screen, a whole number of the world's pixels: a
	# sprite this near the eye has its texels blown up, as Build drew a face in yours (at
	# the world's own pixel it read as a painting).
	var world_px := float(RETRO_RENDER.internal_scale(screen_height))
	var px := maxf(world_px * 2.0, roundf(screen_height / CLOSEUP_LINES / world_px) * world_px)
	m.set_shader_parameter("px_size", px)
	var lines := int(RETRO_RENDER.PRESET_LINES.get(RETRO_RENDER.current_preset(), 240))
	m.set_shader_parameter("dither_strength", float(RETRO_RENDER.DITHER_BY_LINES.get(lines, 0.3)))
	m.set_shader_parameter("palette_mix", 1.0 if RETRO_RENDER.palette_enabled() else 0.0)


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
	_over = TextureRect.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_over.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_over.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_over.visible = false
	add_child(_over)
	_gap_layer = Control.new()
	_gap_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gap_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gap_layer.draw.connect(_draw_gap)
	_gap_layer.visible = false
	add_child(_gap_layer)
	for i in 2:
		var h := TextureRect.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.stretch_mode = TextureRect.STRETCH_SCALE
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.visible = false
		add_child(h)
		_halves.append(h)
	# The hands go over the split face.
	move_child(_over, get_child_count() - 1)
	# Every picture in the world's pixels and palette.
	for n in [_sub, _close, _over] + _halves:
		(n as CanvasItem).material = retro_material()
	_eyes_layer = Control.new()
	_eyes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_eyes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eyes_layer.draw.connect(_draw_eyes)
	add_child(_eyes_layer)
	# The screen effect goes over the close-up (it tears with the rest); the eyes go over
	# the screen effect, or its split channels turn the two white points into a rainbow.
	move_child(_screen, get_child_count() - 1)
	move_child(_eyes_layer, get_child_count() - 1)
	_blood_layer = Control.new()
	_blood_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blood_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blood_layer.draw.connect(_draw_blood)
	_blood_layer.visible = false
	add_child(_blood_layer)
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
	_white = ColorRect.new()
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.color = Color(1, 1, 1, 0)
	_white.visible = false
	add_child(_white)
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
	overlay_off()
	split_off()


## A picture over the close-up for this frame (hands gripping your head): as close_up.
func overlay(tex: Texture2D, scale: float, shake: float = 0.0, off: Vector2 = Vector2.ZERO, rot: float = 0.0) -> void:
	if not is_inside_tree() or tex == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_over.texture = tex
	_over.visible = true
	_over.pivot_offset = vp * 0.5
	_over.scale = Vector2(scale, scale)
	_over.rotation = rot
	var j := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * vp.y
	_over.position = (j + off * vp).floor()


## Her face split open for this frame: `tex` cut down the middle, the halves `open`
## (0 shut .. 1 a third of the screen apart) and a little turned away from the split,
## `scale` 1 = the screen's height. Call every frame; `split_off` ends it.
func split(tex: Texture2D, scale: float, open: float, shake: float = 0.0) -> void:
	if not is_inside_tree() or tex == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var cell := float(maxi(2, int(round(float(DisplayServer.window_get_size().y) / 240.0))))
	var h := vp.y * scale
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var gap := floorf(vp.x * 0.42 * clampf(open, 0.0, 1.0) / cell) * cell
	var j := (Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * vp.y).floor()
	var top := (vp.y - h) * 0.5 + j.y
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(float(i) * tex.get_width() * 0.5, 0, tex.get_width() * 0.5, tex.get_height())
		var r: TextureRect = _halves[i]
		r.texture = at
		r.size = Vector2(w * 0.5, h)
		var x := vp.x * 0.5 - w * 0.5 - gap * 0.5 if i == 0 else vp.x * 0.5 + gap * 0.5
		r.position = Vector2(x, top) + Vector2(j.x, 0)
		r.pivot_offset = Vector2(w * 0.5 if i == 0 else 0.0, h * 0.5)
		r.rotation = (-0.16 if i == 0 else 0.16) * open
		r.visible = true
	_gap = {"cx": vp.x * 0.5 + j.x, "w": gap, "top": top + h * 0.08, "bottom": top + h * 0.97}
	_gap_layer.visible = gap > 0.0
	_gap_layer.queue_redraw()


func split_off() -> void:
	for r in _halves:
		(r as TextureRect).visible = false
		(r as TextureRect).texture = null
	_gap_layer.visible = false
	_gap = {}


## The inside of the split: wet dark red going black at the middle, a row of long pale
## teeth along each edge pointing in, strings of drool across. Whole game pixels.
func _draw_gap() -> void:
	if _gap.is_empty():
		return
	var cell := float(maxi(2, int(round(float(DisplayServer.window_get_size().y) / 240.0))))
	var cx: float = _gap["cx"]
	var w: float = _gap["w"]
	var top: float = _gap["top"]
	var bottom: float = _gap["bottom"]
	var cols := int(w / cell)
	for c in cols:
		var u := absf((float(c) + 0.5) / float(maxi(1, cols)) - 0.5) * 2.0
		var col := Color(lerpf(0.05, 0.42, u * u), 0.0, lerpf(0.02, 0.05, u), 1.0)
		_gap_layer.draw_rect(Rect2(Vector2(cx - w * 0.5 + float(c) * cell, top), Vector2(cell, bottom - top)), col)
	# Wet glints on the flesh.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for _i in int(cols * (bottom - top) / cell * 0.01):
		var p := Vector2(cx - w * 0.5 + floorf(rng.randf() * float(cols)) * cell, top + floorf(rng.randf() * (bottom - top) / cell) * cell)
		_gap_layer.draw_rect(Rect2(p, Vector2(cell, cell)), Color(0.75, 0.2, 0.2, 0.8))
	# Teeth along both edges, pointing in: long, uneven, yellowed.
	var tooth_h := cell * 10.0
	var y := top
	var k := 0
	while y < bottom - tooth_h * 0.5:
		var tlen := cell * float(6 + (k * 7) % 7) * (1.0 + 1.4 * clampf(w / 300.0, 0.0, 1.0))
		for side in [-1.0, 1.0]:
			var edge: float = cx + side * w * 0.5
			var rows := int(tooth_h / cell)
			for r in rows:
				var t := 1.0 - absf(float(r) / float(maxi(1, rows - 1)) - 0.5) * 2.0
				var l := floorf(tlen * t / cell) * cell
				var x0: float = edge - l if side > 0.0 else edge
				_gap_layer.draw_rect(Rect2(Vector2(x0, y + float(r) * cell), Vector2(maxf(cell, l), cell)), Color(0.86, 0.8, 0.62, 1.0) if r != 0 else Color(0.6, 0.52, 0.38, 1.0))
		y += tooth_h + cell
		k += 1
	# Strings of drool across the gap.
	for i in 5:
		var sy := top + (bottom - top) * (0.15 + 0.17 * float(i)) + sin(_time * 3.0 + float(i)) * cell * 2.0
		var sag := cell * float(2 + i % 3)
		var steps := maxi(2, int(w / cell))
		for s in steps:
			var u2 := float(s) / float(steps - 1)
			var yy := floorf((sy + sin(u2 * PI) * sag) / cell) * cell
			_gap_layer.draw_rect(Rect2(Vector2(cx - w * 0.5 + float(s) * cell, yy), Vector2(cell, cell)), Color(0.85, 0.82, 0.78, 0.55))


func overlay_off() -> void:
	_over.visible = false
	_over.texture = null


## Blood on the lens: `amount` 0..1 of a splatter (a few splats, more and bigger with
## more), each running down in drips. It dries darker and goes over some seconds.
func blood(amount: float, at: Vector2 = Vector2(-1, -1)) -> void:
	if not is_inside_tree():
		return
	var cell := float(maxi(2, int(round(float(DisplayServer.window_get_size().y) / 240.0))))
	var vp := get_viewport().get_visible_rect().size
	var cols := int(vp.x / cell)
	var rows := int(vp.y / cell)
	var n := 1 + int(round(clampf(amount, 0.0, 1.0) * 6.0))
	for _i in n:
		var c := Vector2(randi_range(0, cols - 1), randi_range(0, int(rows * 0.7)))
		if at.x >= 0.0:
			c = (at * Vector2(cols, rows) + Vector2(randf_range(-30, 30), randf_range(-20, 20))).floor()
		var r := randf_range(3.0, 6.0 + 10.0 * amount)
		var cells: Array = []
		for y in range(-int(r), int(r) + 1):
			for x in range(-int(r * 1.3), int(r * 1.3) + 1):
				var d := Vector2(x / 1.3, y).length()
				# A ragged edge, and flecks thrown off round it.
				if d <= r * randf_range(0.6, 1.0) or (d <= r * 1.8 and randf() < 0.06):
					cells.append([c + Vector2(x, y), randf_range(0.0, 1.0)])
		_splats.append({"cells": cells})
		for _k in randi_range(1, 3):
			_drips.append({"x": c.x + float(randi_range(-int(r), int(r))), "y": c.y + r * 0.5, "v": randf_range(4.0, 14.0), "len": 0.0,
				"max": randf_range(12.0, 60.0) * (0.5 + amount), "w": randi_range(1, 2), "shade": randf()})
	_blood_a = 1.0
	_blood_layer.visible = true


func _tick_blood(delta: float) -> void:
	if _blood_a <= 0.0:
		return
	for d in _drips:
		if float(d["len"]) < float(d["max"]):
			d["len"] = float(d["len"]) + float(d["v"]) * delta
			d["v"] = maxf(1.5, float(d["v"]) - delta * 2.0)
	_blood_a = maxf(0.0, _blood_a - delta / 7.0)
	if _blood_a <= 0.0:
		_splats.clear()
		_drips.clear()
		_blood_layer.visible = false
	_blood_layer.queue_redraw()


func _draw_blood() -> void:
	var cell := float(maxi(2, int(round(float(DisplayServer.window_get_size().y) / 240.0))))
	# Fresh it is bright and wet; drying it goes brown-black.
	var dry := 1.0 - _blood_a
	var a := clampf(_blood_a * 1.6, 0.0, 0.92)
	for s in _splats:
		for c in s["cells"]:
			var k: float = c[1]
			var col := Color(lerpf(0.55, 0.22, dry) * (0.7 + 0.3 * k), 0.02 * k, 0.02, a * (0.75 + 0.25 * k))
			_blood_layer.draw_rect(Rect2((c[0] as Vector2) * cell, Vector2(cell, cell)), col)
	for d in _drips:
		var k2: float = d["shade"]
		var col2 := Color(lerpf(0.5, 0.2, dry) * (0.7 + 0.3 * k2), 0.01, 0.01, a)
		var h := floorf(float(d["len"]))
		_blood_layer.draw_rect(Rect2(Vector2(float(d["x"]), float(d["y"])) * cell, Vector2(cell * float(d["w"]), cell * maxf(1.0, h))), col2)
		# The bead at its end.
		_blood_layer.draw_rect(Rect2(Vector2(float(d["x"]) - 0.0, float(d["y"]) + h) * cell, Vector2(cell * (float(d["w"]) + 1.0), cell * 2.0)), col2)


## No blood left on the lens (a new night, the menu).
func blood_off() -> void:
	_splats.clear()
	_drips.clear()
	_blood_a = 0.0
	_blood_layer.visible = false


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


## A camera flash in your eyes (the Photographer): white over everything, falling off
## over a second.
func white_blast(strength: float = 1.0) -> void:
	_white_t = maxf(_white_t, clampf(strength, 0.0, 1.0))
	_white.visible = true


func red_flash(alpha: float) -> void:
	_flash.color.a = maxf(_flash.color.a, clampf(alpha, 0.0, 1.0))
	_flash.visible = true


## A high ring in the ears that fades over `seconds`, the world muffled under it.
func tinnitus(seconds: float) -> void:
	if not is_inside_tree():
		return
	_ring_len = maxf(0.5, seconds)
	_ring_t = 0.0
	_ring_t2 = 0.0
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
	if is_inside_tree():
		update_retro(get_viewport().get_visible_rect().size.y)
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
	_strain = move_toward(_strain, _strain_target(), delta * 0.25)
	_ears = maxf(_presence, _strain * 0.65)
	_update_sense(delta)
	_update_ears(delta)
	_update_muffle()
	var on := _dread > 0.01 or _amount > 0.01 or _presence > 0.01 or _strain > 0.05
	_screen.visible = on
	if on:
		_mat.set_shader_parameter("amount", _amount)
		_mat.set_shader_parameter("dread", _dread)
		_mat.set_shader_parameter("time_s", _time)
		# Hurt, the edges close in a little too.
		_mat.set_shader_parameter("squeeze", maxf(_presence, _strain * 0.35))
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
	if _white.visible:
		_white_t = maxf(0.0, _white_t - delta * 0.9)
		_white.color.a = pow(_white_t, 1.5) * 0.95
		_white.visible = _white_t > 0.0
	_update_ring(delta)
	_tick_blood(delta)


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
	if _ears <= 0.01:
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
	var e := _ears
	var bpm := lerpf(56.0, 140.0, e * e)
	var period := 60.0 / bpm
	var frames := _sense_pb.get_frames_available()
	if frames <= 0:
		return
	var dt := 1.0 / SENSE_RATE
	var f1 := lerpf(48.0, 62.0, p)
	var f2 := f1 + lerpf(1.5, 6.0, p)
	var fw0 := lerpf(2900.0, 4300.0, e)
	var beat_hz := lerpf(0.8, 3.5, e)
	var a_drone := 0.10 * clampf(p * 1.6, 0.0, 1.0)
	var a_heart := 0.5 * clampf((e - 0.15) / 0.5, 0.0, 1.0)
	var a_whine := 0.034 * clampf((e - 0.25) / 0.6, 0.0, 1.0)
	var a_sour := 0.014 * clampf((e - 0.7) / 0.3, 0.0, 1.0)
	var a_whoosh := 0.5 * clampf((e - 0.2) / 0.6, 0.0, 1.0)
	var a_hiss := 0.012 * clampf((e - 0.1) / 0.7, 0.0, 1.0)
	# The ears gone for a moment (_update_ears): nothing from here either.
	var gone := 0.0 if _drop_left > 0.0 else 1.0
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		_beat_t += dt
		if _beat_t >= period:
			_beat_t -= period
		_ear_t += dt
		# Lub-dub: a thump, and a softer one a short way after.
		var tb := _beat_t
		var env := 0.0
		if tb < 0.12:
			env = exp(-tb * 38.0)
		elif tb > 0.2 and tb < 0.32:
			env = 0.6 * exp(-(tb - 0.2) * 40.0)
		_beat_env = env
		# The blood in your ears: a dull whoosh swelling a moment after each beat.
		var tw := tb - 0.04
		var whoosh_env := (1.0 - exp(-tw * 30.0)) * exp(-tw * 6.0) if tw > 0.0 else 0.0
		var n := randf() * 2.0 - 1.0
		_noise_lp += (n - _noise_lp) * 0.12
		_noise_hp += (n - _noise_hp) * 0.55
		# The ring: wandering, two tones beating, the sour third at the worst.
		var drift := 1.0 + 0.012 * sin(TAU * 0.13 * _ear_t) + 0.005 * sin(TAU * 0.71 * _ear_t)
		var fw := fw0 * drift
		_sense_ph[0] = fmod(_sense_ph[0] + f1 * dt, 1.0)
		_sense_ph[1] = fmod(_sense_ph[1] + f2 * dt, 1.0)
		_sense_ph[2] = fmod(_sense_ph[2] + fw * dt, 1.0)
		_ear_ph[0] = fmod(_ear_ph[0] + (fw + beat_hz) * dt, 1.0)
		_ear_ph[1] = fmod(_ear_ph[1] + fw * 1.414 * dt, 1.0)
		var ring := (sin(TAU * _sense_ph[2]) + sin(TAU * _ear_ph[0])) * 0.5 * a_whine + sin(TAU * _ear_ph[1]) * a_sour
		# Which ear rings louder, slowly changing.
		var pan := 0.5 + 0.5 * sin(TAU * 0.045 * _ear_t)
		var heart := sin(TAU * 52.0 * tb) * env * a_heart
		var mid := (sin(TAU * _sense_ph[0]) + sin(TAU * _sense_ph[1])) * 0.5 * a_drone + heart + _noise_lp * whoosh_env * a_whoosh + (n - _noise_hp) * a_hiss
		buf[i] = Vector2(mid + ring * lerpf(1.0, 0.4, pan), mid + ring * lerpf(0.4, 1.0, pan)) * gone
	_sense_pb.push_buffer(buf)


## Your own wounds: low on health the ears go too (from under about half, all of it near
## none). Main's `_player_health` on this machine; nothing in the menu.
func _strain_target() -> float:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return 0.0
	var started = scene.get("_gameplay_started")
	var menu = scene.get("_menu_mode")
	var hp = scene.get("_player_health")
	if started == null or not bool(started) or (menu != null and bool(menu)) or hp == null or int(hp) <= 0:
		return 0.0
	return clampf((48.0 - float(hp)) / 38.0, 0.0, 1.0)


## The ears' recorded part: your breathing (faster and nearer the worse it is), a dry
## swallow while it builds; at the worst a moment with nothing at all (the Master bus
## down with the generator), and the pop as it comes back.
func _update_ears(delta: float) -> void:
	var e := _ears
	if e > 0.3:
		if _breath == null and ResourceLoader.exists(SFX_BREATH):
			_breath = AudioStreamPlayer.new()
			var st := load(SFX_BREATH) as AudioStream
			if st is AudioStreamMP3:
				st = (st as AudioStreamMP3).duplicate()
				(st as AudioStreamMP3).loop = true
			_breath.stream = st
			add_child(_breath)
		if _breath != null:
			if not _breath.playing:
				_breath.play()
			_breath.volume_db = lerpf(-30.0, -9.0, clampf((e - 0.3) / 0.6, 0.0, 1.0))
			_breath.pitch_scale = lerpf(0.94, 1.12, e)
	elif _breath != null and _breath.playing:
		_breath.stop()
	if e > 0.3 and e < 0.8:
		_swallow_wait -= delta
		if _swallow_wait <= 0.0:
			_swallow_wait = randf_range(8.0, 16.0)
			_one_shot(SFX_SWALLOW, -10.0)
	if _drop_left > 0.0:
		_drop_left -= delta
		if _drop_left <= 0.0:
			_set_deaf(false)
			_one_shot(SFX_POP, -6.0)
	elif e > 0.78:
		_drop_wait -= delta
		if _drop_wait <= 0.0:
			_drop_wait = randf_range(3.0, 8.0)
			_drop_left = randf_range(0.09, 0.18)
			_set_deaf(true)
	else:
		_drop_wait = maxf(_drop_wait, 2.0)
		if _deaf != null:
			_set_deaf(false)


## The world gone (an Amplify on Master far down) or back (taken off again).
func _set_deaf(on: bool) -> void:
	var master := AudioServer.get_bus_index("Master")
	if on:
		if _deaf == null:
			_deaf = AudioEffectAmplify.new()
			_deaf.volume_db = -40.0
			AudioServer.add_bus_effect(master, _deaf)
		return
	if _deaf == null:
		return
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) == _deaf:
			AudioServer.remove_bus_effect(master, i)
			break
	_deaf = null
	_drop_left = 0.0


func _one_shot(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var a := AudioStreamPlayer.new()
	a.stream = load(path)
	a.volume_db = db
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


## Never leave the camp's sound down or muffled behind (the menu, a new scene).
func _exit_tree() -> void:
	_set_deaf(false)


## Your ears close over: the camp's sounds go far away as the presence rises, till
## there is the drone, the heart and him.
func _update_muffle() -> void:
	var master := AudioServer.get_bus_index("Master")
	var want := _presence > 0.25
	if want and _muffle == null:
		_muffle = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(master, _muffle)
	if _muffle == null:
		return
	if not want:
		for i in AudioServer.get_bus_effect_count(master):
			if AudioServer.get_bus_effect(master, i) == _muffle:
				AudioServer.remove_bus_effect(master, i)
				break
		_muffle = null
		return
	var k := clampf((_presence - 0.25) / 0.75, 0.0, 1.0)
	_muffle.cutoff_hz = lerpf(14000.0, 1600.0, k * k)


func _update_ring(delta: float) -> void:
	if _ring_len <= 0.0:
		return
	_ring_t += delta
	var k := clampf(_ring_t / _ring_len, 0.0, 1.0)
	if _lowpass != null:
		_lowpass.cutoff_hz = lerpf(500.0, 20000.0, k * k)
	if _ring_pb != null:
		# The ring after a blast: two tones a hair apart (it beats), a slight tremble
		# in it, the hiss of the blast under it going first, a crackle at the start;
		# louder in one ear, both by the end. It hangs on and fades slowly.
		var amp := 0.22 * pow(1.0 - k, 1.4)
		var hiss_amp := 0.05 * pow(1.0 - k, 3.0)
		var frames := _ring_pb.get_frames_available()
		var dt := 1.0 / 22050.0
		var buf := PackedVector2Array()
		buf.resize(frames)
		var right := lerpf(0.55, 1.0, k)
		for i in frames:
			_ring_t2 += dt
			var vib := 1.0 + 0.003 * sin(TAU * 5.5 * _ring_t2)
			_ring_phase = fmod(_ring_phase + TINNITUS_HZ * vib * dt, 1.0)
			_ring_ph2 = fmod(_ring_ph2 + TINNITUS_HZ * 1.0021 * dt, 1.0)
			var tone := (sin(_ring_phase * TAU) * 0.7 + sin(_ring_ph2 * TAU) * 0.3) * amp
			var n := randf() * 2.0 - 1.0
			_ring_lp += (n - _ring_lp) * 0.6
			var rest := (n - _ring_lp) * hiss_amp + n * 0.25 * exp(-_ring_t2 * 25.0)
			buf[i] = Vector2(tone + rest, tone * right + rest)
		_ring_pb.push_buffer(buf)
	if k >= 1.0:
		_ring_len = 0.0
		_ring.stop()
		_ring_pb = null
		var master := AudioServer.get_bus_index("Master")
		for i in AudioServer.get_bus_effect_count(master):
			if _lowpass != null and AudioServer.get_bus_effect(master, i) == _lowpass:
				AudioServer.remove_bus_effect(master, i)
				break
		_lowpass = null
		_lowpass_idx = -1
