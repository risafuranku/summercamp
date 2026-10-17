extends Control

## The studio splash: neon signs on a camp cabin wall at night. UNDO LABS (the 3x3
## brand mosaic and the name in tubes) lights up, the view slides down the wall along its
## cable to a second sign, POWERED BY GODOT (the Godot robot in the same tubes and glass),
## then the power goes. It is the project's first scene (run/main_scene) and plays while
## main.tscn loads on a thread, then cuts to it. The engine's boot splash is this scene's
## first frame, baked by tools/studio_splash_bake.gd into assets/boot/undo_labs_boot.png,
## so the hand-over from the engine does not show.
##
##   0.0   dark: the coated glass in moonlight, crickets             (= the boot image)
##   0.4   the tiles strike one diagonal after another, starters ticking
##   1.3   UNDO, then "labs", which hesitates; the hum, a bad tube, moths
##   ~3    the view slides down the wall (in whole pixels, like the engine would)
##   ~3.6  the robot strikes, then POWERED BY, then GODOT; the owl on the transformer
##         box turns to it and hoots
##   cut   once main.tscn is loaded: a brownout, a breath, the camp's own power-out
##         sound; the tubes die out, the owl's eyes still catch the moon, it lifts off;
##         the wall fades slowly to black through the palette, the title card fades in
##         and main.tscn takes over showing the same card (it covers the world
##         generation). One launch in UNCANNY_ODDS something stays lit a moment too long.
## All the while: crickets, a light gusty wind (the game's own) with autumn leaves
## blowing through the light, a tawny owl further off.
##
## Drawn at 320x180 in a SubViewport: the sign layer (_Sign, its own transparent
## viewport) draws the tubes, the studio_neon shader lights the wall with them and puts
## the frame through a Build palette (tools/gen_splash_palette.py) with grain and the
## game's dither, the moths fly over that. Shown like the engine's boot splash:
## kept aspect, nearest. Any key or click goes straight to the cut. Headless runs go
## straight to main.

const MAIN_SCENE := "res://scenes/main.tscn"
## main.WINDOW_TITLE (preloading main.gd here would load the whole game up front).
const WINDOW_TITLE := "Cursed Camp Manager Simulator"
const SHADER := preload("res://materials/studio_neon.gdshader")
const FONT: FontFile = preload("res://assets/fonts/jersey10.fnt")
const WALL_TEXTURE := "res://assets/textury/camp/planks_grey.png"
const PALETTE_LUT := preload("res://assets/boot/splash_palette_lut.png")
const SFX_DIR := "res://assets/sfx/splash/"
const SFX_POWER_OUT := "res://assets/sfx/power/power_out.mp3"
const SFX_CRICKETS := "res://assets/sfx/cricketi.mp3"
const SFX_WIND := "res://assets/sfx/weather/wind.mp3"
## main's title card: faded in here, then main shows the same one.
const BOOT_SCREEN := preload("res://scripts/ui/boot_screen.gd")

const RES := Vector2i(320, 180)
## How far the view slides down from UNDO LABS to POWERED BY GODOT (pixels).
const PAN := 104
const TILE := 16
const TEXT_SIZE := 20
const SMALL_SIZE := 10
## The brand mosaic (undocollective brand/mosaic.svg) row by row: colours run along the diagonals.
const TILE_COLORS := [
	Color("ff1694"), Color("dd16c8"), Color("8d24ff"),
	Color("dd16c8"), Color("8d24ff"), Color("315cff"),
	Color("8d24ff"), Color("315cff"), Color("19bceb"),
]
const WORD_A := "UNDO"
const WORD_B := "labs"
## UNDO is a white tube with a pink coat, "labs" runs down the mosaic's gradient.
const WORD_A_COAT := Color("ff4fb8")
const WORD_B_COATS := [Color("dd16c8"), Color("8d24ff"), Color("315cff"), Color("19bceb")]
## The second sign takes up where the mosaic ends: a cyan robot, GODOT in white on
## blue, POWERED BY in the pink of UNDO.
const ROBOT_COAT := Color("19bceb")
const POWERED := "POWERED BY"
const POWERED_COAT := Color("ff4fb8")
const GODOT := "GODOT"
const GODOT_COAT := Color("315cff")
## The Godot robot, 16x15 (B body, W white line, K pupil); drawn at 2x. Its edge is the
## tube, the body a panel of glass, the white lines tubes of their own.
const ROBOT := [
	"....BBB..BBB....",
	"....BBBBBBBB....",
	"...BBBBBBBBBB...",
	"BBBBBBBBBBBBBBBB",
	"BBBBBBBBBBBBBBBB",
	"BBBBBBBBBBBBBBBB",
	".BBWWBBBBBBWWBB.",
	".BWKKWBWWBWKKWB.",
	".BBWKBBWWBBKWBB.",
	".BBBBBBBBBBBBBB.",
	".WWBBBBBBBBBBWW.",
	".BBWBBWBBWBBWBB.",
	".BBWWWWBBWWWWBB.",
	"..BBBBBBBBBBBB..",
	"...BBBBBBBBBB...",
]
## Elements (one light level each): 0..8 the tiles, the letters of UNDO, the letters of
## labs, the robot, its eyes, POWERED BY, GODOT.
const FIRST_A := 9
const FIRST_B := 13
const EL_ROBOT := 17
const EL_EYES := 18
const EL_POWERED := 19
const EL_GODOT := 20
const ELEMENTS := 21
const CENTER_TILE := 4
## Tubes of UNDO LABS that may be the bad one (a corner, the middle, the "a").
const BAD_CANDIDATES := [0, 2, 6, 8, 4, 14]

const IGNITE_AT := 0.4
const DIAGONAL_STEP := 0.15
## From "labs" lit to the view starting down, and how long the slide takes.
const PAN_DELAY := 0.7
const PAN_TIME := 1.1
## From the slide starting to the robot's first blink.
const GODOT_AT := 0.65
## How long POWERED BY GODOT burns before the power may go.
const GODOT_HOLD := 1.5
## From the first dip of the brownout to the dark.
const BROWNOUT := 0.3
## How fast a dead tube's glow goes.
const AFTERGLOW := 0.08
## After the dark: the owl lifts off; the picture fades to black; the title card fades
## in and stays a moment before main takes over.
const OWL_FLIES := 0.4
const FADE_DELAY := 0.25
const FADE_SLOW := 1.1
const TITLE_IN := 0.45
const TITLE_HOLD := 0.15
## One launch in N, something stays lit a moment after the power is gone: the robot's
## eyes, or the mosaic's middle tile if the power went before the view slid down.
const UNCANNY_ODDS := 8
const UNCANNY_HOLD := 0.75

## The sign layer's alpha for the clear glass panels (the shader reads >= 0.95 as
## coated tube, >= 0.5 as glass at all).
const PANEL_GLASS := 0.8

## Moths round UNDO LABS, and round POWERED BY GODOT once it is lit.
const MOTHS := 5
const GODOT_MOTHS := 4
const HUM_DB := -15.0
const CRICKETS_DB := 2.0
const WIND_DB := -21.0

## The bake tool: no audio, no loading, the clock is set with seek().
var preview := false

var _viewport: SubViewport
var _sign: _Sign
var _moths: _Moths
var _owl: _Owl
var _leaves: _Leaves
var _title: CanvasLayer
var _title_veil: ColorRect
var _post_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
## Per element: Vector2(time, level) sorted by time; strike times for the flash.
var _keys: Array = []
var _strikes: Array = []
## [time, sound, dB] sorted by time.
var _events: Array = []
var _next_event := 0
var _bad := 0
var _pan_at := INF
var _earliest_cut := 0.0
var _cut_at := -1.0
var _off_at := INF
var _leave_at := INF
var _uncanny := -1
var _t := 0.0
var _done := false
var _levels := PackedFloat32Array()
var _flashes := PackedFloat32Array()
## Where the owl sits (top-left of its sprite, wall pixels), when the robot catches its
## eye and when it hoots.
var _owl_perch := Vector2.ZERO
var _robot_lit := INF
var _owl_hoot := INF

var _hum: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _streams: Dictionary = {}
var _tap_cooldown := 0.0


func _ready() -> void:
	DisplayServer.window_set_title(WINDOW_TITLE)
	if not preview and DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if preview:
		_rng.seed = 7
	else:
		_rng.randomize()
	_build()
	_plan()
	_apply(0.0)
	if preview:
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_apply_integer_canvas_scale()
	_build_audio()
	ResourceLoader.load_threaded_request(MAIN_SCENE)


## The same whole-number 2D scale main sets up (main._apply_integer_canvas_scale), so the
## title card faded in here is pixel for pixel the one main shows next.
func _apply_integer_canvas_scale() -> void:
	var root := get_tree().root
	var win := root.size
	if win.x <= 0 or win.y <= 0:
		return
	var k := maxi(1, int(floor(minf(float(win.x) / 1280.0, float(win.y) / 720.0))))
	root.content_scale_size = Vector2i(int(ceil(float(win.x) / float(k))), int(ceil(float(win.y) / float(k))))


# ── preview (tools/studio_splash_bake.gd) ─────────────────────────────────────

func seek(t: float) -> void:
	_t = t
	_apply(t)


## When the power goes at the earliest (the bake tool's default cut).
func earliest_cut() -> float:
	return _earliest_cut


func preview_cut(at: float, uncanny: bool = false) -> void:
	_cut(at)
	if uncanny:
		_uncanny = EL_EYES if _pan(at) >= PAN * 0.5 else CENTER_TILE


func frame_image() -> Image:
	return _viewport.get_texture().get_image()


# ── the picture ───────────────────────────────────────────────────────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_viewport = SubViewport.new()
	_viewport.size = RES
	_viewport.disable_3d = true
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	# The tubes get a transparent viewport of their own (alpha = where the glass is),
	# nested so it is drawn before the picture that reads it.
	var sign_vp := SubViewport.new()
	sign_vp.size = RES
	sign_vp.disable_3d = true
	sign_vp.transparent_bg = true
	sign_vp.snap_2d_transforms_to_pixel = true
	sign_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	sign_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.add_child(sign_vp)
	_sign = _Sign.new()
	sign_vp.add_child(_sign)
	_sign.layout()

	var post := ColorRect.new()
	post.size = Vector2(RES)
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = SHADER
	var wall := _compose_wall()
	_post_mat.set_shader_parameter("sign_tex", sign_vp.get_texture())
	_post_mat.set_shader_parameter("palette_lut", PALETTE_LUT)
	_post_mat.set_shader_parameter("wall_tex", ImageTexture.create_from_image(wall))
	_post_mat.set_shader_parameter("fade", 1.0)
	_post_mat.set_shader_parameter("wall_size", Vector2(wall.get_size()))
	_post_mat.set_shader_parameter("res", Vector2(RES))
	_post_mat.set_shader_parameter("rects", _sign.rects())
	post.material = _post_mat
	_viewport.add_child(post)

	_moths = _Moths.new()
	_moths.setup(_rng, _sign)
	_viewport.add_child(_moths)
	_owl = _Owl.new()
	_owl.perch = _owl_perch
	_viewport.add_child(_owl)
	_leaves = _Leaves.new()
	_leaves.setup()
	_viewport.add_child(_leaves)

	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)


## The cabin wall, tall enough for the slide: grey planks, the cable from UNDO LABS
## down to POWERED BY GODOT and on to the transformer box under it.
func _compose_wall() -> Image:
	var src := (load(WALL_TEXTURE) as Texture2D).get_image()
	src.convert(Image.FORMAT_RGBA8)
	var size := Vector2i(RES.x, RES.y + PAN)
	var wall := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var tw := src.get_width()
	var th := src.get_height()
	var y := -37
	while y < size.y:
		var x := -21
		while x < size.x:
			wall.blit_rect(src, Rect2i(0, 0, tw, th), Vector2i(x, y))
			x += tw
		y += th
	var cable := Color(0.05, 0.045, 0.05)
	var from := Vector2i(_sign.text_end()) + Vector2i(2, -7)
	var godot := Rect2i(_sign.godot_box)
	var run_x := maxi(from.x, godot.end.x) + 9
	var into := Vector2i(godot.end.x + 2, godot.position.y + godot.size.y / 2)
	wall.fill_rect(Rect2i(from.x, from.y, run_x - from.x + 1, 1), cable)
	wall.fill_rect(Rect2i(run_x, from.y, 1, into.y - from.y), cable)
	wall.fill_rect(Rect2i(into.x, into.y, run_x - into.x + 1, 1), cable)
	var box := Rect2i(run_x - 7, godot.end.y + 9, 15, 11)
	# The owl sits on it (its feet on the lid).
	_owl_perch = Vector2(float(box.position.x + box.size.x / 2 - 4), float(box.position.y - 13))
	wall.fill_rect(Rect2i(run_x, into.y, 1, box.position.y - into.y), cable)
	wall.fill_rect(Rect2i(run_x, box.end.y, 1, size.y - box.end.y), cable)
	wall.fill_rect(box, Color(0.30, 0.29, 0.27))
	wall.fill_rect(Rect2i(box.position, Vector2i(box.size.x, 1)), Color(0.52, 0.50, 0.46))
	wall.fill_rect(Rect2i(box.position.x, box.end.y - 1, box.size.x, 1), Color(0.07, 0.06, 0.06))
	wall.fill_rect(Rect2i(box.end.x - 1, box.position.y, 1, box.size.y), Color(0.09, 0.08, 0.08))
	wall.fill_rect(Rect2i(box.position.x + 4, box.position.y + 4, 6, 3), Color(0.58, 0.52, 0.30))
	for p in [box.position + Vector2i(1, 1), box.position + Vector2i(box.size.x - 2, 1), box.position + Vector2i(1, box.size.y - 2), box.end - Vector2i(2, 2)]:
		wall.set_pixelv(p, Color(0.48, 0.46, 0.42))
	return wall


# ── the timeline ──────────────────────────────────────────────────────────────

func _plan() -> void:
	_keys.clear()
	_strikes.clear()
	for i in ELEMENTS:
		_keys.append([])
		_strikes.append([])
	_levels.resize(ELEMENTS)
	_flashes.resize(ELEMENTS)
	var struck_diagonals := {}
	var last := 0.0
	for i in 9:
		var d: int = i / 3 + i % 3
		var at := IGNITE_AT + float(d) * DIAGONAL_STEP + _rng.randf_range(0.0, 0.07)
		var lit := _ignite(i, at, _rng.randi_range(1, 3), 0.04, 0.11)
		if not struck_diagonals.has(d):
			struck_diagonals[d] = true
			_event(lit, "neon_strike", -15.0)
		last = maxf(last, lit)
	# UNDO is one tube: all four letters share its blinks.
	var a_lit := _ignite(FIRST_A, last + 0.25, 2, 0.05, 0.12)
	_event(a_lit, "neon_strike", -11.0)
	_share(FIRST_A, [FIRST_A + 1, FIRST_A + 2, FIRST_A + 3])
	# "labs" hesitates: more blinks, longer gaps.
	var b_lit := _ignite(FIRST_B, a_lit + 0.2, _rng.randi_range(2, 3), 0.08, 0.18)
	_event(b_lit, "neon_strike", -11.0)
	_share(FIRST_B, [FIRST_B + 1, FIRST_B + 2, FIRST_B + 3])
	# Down the wall to the second sign: the robot (eyes on the same circuit), then the words.
	_pan_at = b_lit + PAN_DELAY
	var r_lit := _ignite(EL_ROBOT, _pan_at + GODOT_AT, 2, 0.05, 0.12)
	_event(r_lit, "neon_strike", -12.0)
	_robot_lit = r_lit
	_share(EL_ROBOT, [EL_EYES])
	var p_lit := _ignite(EL_POWERED, r_lit + 0.14, 1, 0.05, 0.1)
	var g_lit := _ignite(EL_GODOT, p_lit + 0.12, 2, 0.06, 0.14)
	_event(g_lit, "neon_strike", -11.0)
	_earliest_cut = g_lit + GODOT_HOLD
	# The night: an owl further off while UNDO LABS burns, then the one on the box.
	_event(b_lit + 0.45, "owl_far", -15.0)
	_owl_hoot = g_lit + 0.6
	_event(_owl_hoot, "owl_near", -9.0)
	# POWERED BY catches once while it burns.
	var catch_at := g_lit + _rng.randf_range(0.35, 0.6)
	(_keys[EL_POWERED] as Array).append_array([Vector2(catch_at, 0.0), Vector2(catch_at + 0.04, 0.7), Vector2(catch_at + 0.07, 1.0)])
	_event(catch_at, "neon_tick_1", -16.0)
	# The bad tube up in UNDO LABS drops out now and then for as long as it is on.
	_bad = BAD_CANDIDATES[_rng.randi() % BAD_CANDIDATES.size()]
	var t := maxf(b_lit, _last_key(_bad)) + _rng.randf_range(0.3, 0.55)
	while t < 90.0:
		var drop: Array = _keys[_bad]
		drop.append(Vector2(t, 0.0))
		drop.append(Vector2(t + 0.05, 0.65))
		drop.append(Vector2(t + 0.08, 0.0))
		drop.append(Vector2(t + _rng.randf_range(0.14, 0.3), 1.0))
		_event(t, "neon_sputter", -17.0 if t < _pan_at + PAN_TIME * 0.5 else -24.0)
		t += _rng.randf_range(1.1, 2.6)
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


## Starter blinks, then the strike. Returns when the tube is lit for good.
func _ignite(i: int, at: float, blinks: int, gap_min: float, gap_max: float) -> float:
	var keys: Array = _keys[i]
	var t := at
	for b in blinks:
		keys.append(Vector2(t, _rng.randf_range(0.3, 0.75)))
		_event(t, "neon_tick_%d" % _rng.randi_range(1, 3), -14.0 if i < 9 else -10.0)
		t += _rng.randf_range(0.03, 0.07)
		keys.append(Vector2(t, 0.0))
		t += _rng.randf_range(gap_min, gap_max)
	keys.append(Vector2(t, 1.0))
	(_strikes[i] as Array).append(t)
	return t


## Letters of one word are one tube: they share its blinks.
func _share(from: int, to: Array) -> void:
	for i in to:
		_keys[i] = (_keys[from] as Array).duplicate()
		_strikes[i] = (_strikes[from] as Array).duplicate()


func _last_key(i: int) -> float:
	var keys: Array = _keys[i]
	return (keys.back() as Vector2).x if not keys.is_empty() else 0.0


func _event(t: float, sound: String, db: float) -> void:
	_events.append([t, sound, db])


func _cut(at: float) -> void:
	if _cut_at >= 0.0:
		return
	_cut_at = at
	_off_at = at + BROWNOUT
	if not preview and _rng.randi() % UNCANNY_ODDS == 0:
		_uncanny = EL_EYES if _pan(at) >= PAN * 0.5 else CENTER_TILE
	var pending: Array = _events.slice(_next_event)
	_events = _events.slice(0, _next_event)
	for e in pending:
		if e[0] < at:
			_events.append(e)
	_event(at, "neon_sputter", -10.0)
	_event(at + 0.13, "neon_tick_2", -12.0)
	_event(_off_at, "power_out", -3.0)
	_event(_off_at + OWL_FLIES, "owl_flap", -7.0)
	if _uncanny >= 0:
		_event(_off_at + UNCANNY_HOLD, "neon_tick_3", -20.0)
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


## Voltage on the signs: the brownout dips, stutters, comes back for a breath, goes.
func _power(t: float) -> float:
	if _cut_at < 0.0 or t < _cut_at:
		return 1.0
	var d := t - _cut_at
	if d < 0.05:
		return 0.42
	if d < 0.08:
		return 0.1
	if d < 0.2:
		return 0.45 + 0.35 * _hash(97, floor(t * 40.0))
	if d < BROWNOUT:
		return 1.0
	return 0.0


## How far the view has slid down the wall (whole pixels, eased).
func _pan(t: float) -> float:
	var k := clampf((t - _pan_at) / PAN_TIME, 0.0, 1.0)
	return roundf(k * k * (3.0 - 2.0 * k) * float(PAN))


func _level(i: int, t: float) -> float:
	var v := 0.0
	for k in _keys[i]:
		if (k as Vector2).x > t:
			break
		v = (k as Vector2).y
	var flash := 0.0
	for s in _strikes[i]:
		if s <= t:
			flash = 0.2 * exp(-(t - s) / 0.1)
	_flashes[i] = flash if v > 0.0 else 0.0
	if v > 0.0:
		v *= 1.0 + 0.06 * (_hash(i, floor(t * 50.0)) - 0.5) + _flashes[i]
	if t >= _off_at:
		var glow := v * 0.45 * exp(-(t - _off_at) / AFTERGLOW)
		if i == _uncanny and t > _off_at + 0.06 and t < _off_at + UNCANNY_HOLD:
			glow = 0.22 + 0.04 * _hash(i, floor(t * 12.0))
		_flashes[i] = 0.0
		return glow
	return v * _power(t)


func _hash(i: int, n: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + n * 78.233) * 43758.5453, 1.0)


func _apply(t: float) -> void:
	var pan := _pan(t)
	var lit := 0.0
	var weight := 0.0
	var flash := 0.0
	var lights := PackedVector4Array()
	lights.resize(ELEMENTS)
	for i in ELEMENTS:
		_levels[i] = _level(i, t)
		var w := _sign.glow_weight(i)
		lit += _levels[i] * w
		weight += w
		flash = maxf(flash, _flashes[i])
		var c := _sign.glow_color(i)
		lights[i] = Vector4(c.r * _levels[i], c.g * _levels[i], c.b * _levels[i], w)
	lit /= weight
	_sign.levels = _levels
	_sign.flashes = _flashes
	_sign.position.y = -pan
	_sign.queue_redraw()
	var fade := _fade(t)
	var godot_lit := (_levels[EL_ROBOT] * 1.6 + _levels[EL_GODOT] * 0.7) / 2.3
	var undo_lit := 0.0
	for i in EL_ROBOT:
		undo_lit += _levels[i] * (1.0 if i < FIRST_A else 0.4)
	undo_lit /= 9.0 + 8.0 * 0.4
	_moths.update_to(t, _levels, Vector2(undo_lit, godot_lit), pan, _robot_lit)
	_owl.update_to(t, pan, godot_lit, fade, _robot_lit, _owl_hoot, _off_at + OWL_FLIES if _cut_at >= 0.0 else INF)
	var light_at := (_sign.mosaic.get_center() + Vector2(0.0, 22.0)).lerp(_sign.godot_box.get_center(), pan / float(PAN)) - Vector2(0.0, pan)
	_leaves.update_to(t, lit, light_at, fade, pan)
	_moths.modulate = Color(fade, fade, fade)
	_post_mat.set_shader_parameter("fade", fade)
	_update_title(t)
	_post_mat.set_shader_parameter("lights", lights)
	_post_mat.set_shader_parameter("pan", pan)
	_post_mat.set_shader_parameter("frame", floor(t * 24.0))
	_post_mat.set_shader_parameter("bloom", 1.0 + flash * 0.5)
	_post_mat.set_shader_parameter("spill", 1.0 + flash * 0.3)
	if _hum != null:
		_hum.volume_db = maxf(-80.0, linear_to_db(maxf(lit, 0.0001)) + HUM_DB) if t < _off_at else -80.0
		_hum.pitch_scale = lerpf(0.9, 1.0, _power(t)) if t < _off_at else 1.0


# ── running ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if preview or _done or _viewport == null:
		return
	# Frame time, not the wall clock: a loading hitch slows the picture down instead of
	# skipping it, and --write-movie records it at its own pace.
	_t += minf(delta, 0.1)
	var loaded := _main_loaded()
	if _cut_at < 0.0 and loaded and _t >= _earliest_cut:
		_cut(_t)
	if _leave_at == INF and loaded and _t >= _title_at() + TITLE_IN + TITLE_HOLD:
		_leave_at = _t
	_fire_events()
	_apply(_t)
	# The night's sounds fade out with the picture.
	var night := clampf(_t / 0.6, 0.001, 1.0) * maxf(_fade(_t), 0.001)
	_crickets.volume_db = linear_to_db(night) + CRICKETS_DB
	_wind.volume_db = linear_to_db(night) + WIND_DB + 6.0 * (_Leaves.gust(_t) - 1.0)
	_tap_cooldown -= delta
	if _moths.tapped and _tap_cooldown <= 0.0:
		_play("moth_tap", -21.0, _rng.randf_range(0.85, 1.25))
		_tap_cooldown = 0.6
	_moths.tapped = false
	if _t >= _leave_at:
		_go()


func _input(event: InputEvent) -> void:
	if preview or _done or _cut_at >= 0.0 or _t < 0.25:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_cut(_t)
		get_viewport().set_input_as_handled()


## 1 until a moment after the power goes, then slowly to 0 (the palette walks it down
## shade by shade, like a Build fade).
func _fade(t: float) -> float:
	if t < _off_at + FADE_DELAY:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (t - _off_at - FADE_DELAY) / FADE_SLOW)


func _title_at() -> float:
	return _off_at + FADE_DELAY + FADE_SLOW


## main's title card, fading in out of the black (not in preview: the bake tool reads
## the 320x180 picture only).
func _update_title(t: float) -> void:
	var a := clampf((t - _title_at()) / TITLE_IN, 0.0, 1.0)
	if a <= 0.0 or preview:
		return
	if _title == null:
		_title = BOOT_SCREEN.new()
		add_child(_title)
		var veil_layer := CanvasLayer.new()
		veil_layer.layer = _title.layer + 1
		add_child(veil_layer)
		_title_veil = ColorRect.new()
		_title_veil.color = Color.BLACK
		_title_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil_layer.add_child(_title_veil)
	_title_veil.color.a = 1.0 - a


func _main_loaded() -> bool:
	return ResourceLoader.load_threaded_get_status(MAIN_SCENE) != ResourceLoader.THREAD_LOAD_IN_PROGRESS


func _go() -> void:
	_done = true
	var scene := ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
	if scene != null:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(MAIN_SCENE)


# ── sound ─────────────────────────────────────────────────────────────────────

func _build_audio() -> void:
	for name in ["neon_tick_1", "neon_tick_2", "neon_tick_3", "neon_strike", "neon_sputter", "moth_tap"]:
		_streams[name] = load(SFX_DIR + name + ".wav")
	_streams["power_out"] = load(SFX_POWER_OUT)
	for name in ["owl_far", "owl_near", "owl_flap"]:
		_streams[name] = load(SFX_DIR + name + ".mp3")
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	_hum = AudioStreamPlayer.new()
	_hum.stream = load(SFX_DIR + "neon_hum.wav")
	_hum.volume_db = -80.0
	add_child(_hum)
	_hum.play()
	_crickets = AudioStreamPlayer.new()
	_crickets.stream = load(SFX_CRICKETS)
	_crickets.volume_db = -80.0
	add_child(_crickets)
	_crickets.play(_rng.randf_range(0.0, maxf(0.0, _crickets.stream.get_length() - 30.0)))
	_wind = AudioStreamPlayer.new()
	_wind.stream = load(SFX_WIND)
	_wind.volume_db = -80.0
	add_child(_wind)
	_wind.play(_rng.randf_range(0.0, maxf(0.0, _wind.stream.get_length() - 30.0)))


func _fire_events() -> void:
	while _next_event < _events.size() and _events[_next_event][0] <= _t:
		var e: Array = _events[_next_event]
		_next_event += 1
		# A hitch must not fire a burst of stale ticks at once.
		if _t - float(e[0]) > 0.25 and e[1] != "power_out":
			continue
		_play(e[1], e[2], _rng.randf_range(0.94, 1.06) if e[1] != "power_out" else 1.0)
		if e[1] == "power_out":
			_hum.stop()


func _play(sound: String, db: float, pitch: float = 1.0) -> void:
	if not _streams.has(sound) or _sfx.is_empty():
		return
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = _streams[sound]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


# ── the sign layer: rgb = light, a = glass (world coordinates, slid by the pan) ──

class _Sign:
	extends Node2D

	var levels := PackedFloat32Array()
	var flashes := PackedFloat32Array()
	var mosaic := Rect2()
	var text_box := Rect2()
	## The POWERED BY GODOT lockup's bounds.
	var godot_box := Rect2()
	## [element, char, baseline position, coat colour, font size]
	var letters: Array = []
	## The robot at 2x as rectangles per kind of glass.
	var _robot_tube: Array[Rect2] = []
	var _robot_panel: Array[Rect2] = []
	var _robot_line: Array[Rect2] = []
	var _robot_eye: Array[Rect2] = []
	var _robot_pupil: Array[Rect2] = []
	var _robot_rect := Rect2()
	var _eyes_rect := Rect2()

	func layout() -> void:
		letters.clear()
		var w := float(TILE * 3 - 1)
		mosaic = Rect2(Vector2(roundf((float(RES.x) - w) * 0.5), 46.0), Vector2(w, w))
		var text := WORD_A + " " + WORD_B
		var text_w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		var baseline := mosaic.end.y + 14.0 + float(TEXT_SIZE)
		var left := roundf((float(RES.x) - text_w) * 0.5)
		for k in text.length():
			if text[k] == " ":
				continue
			var in_b := k > WORD_A.length()
			var el := FIRST_B + (k - WORD_A.length() - 1) if in_b else FIRST_A + k
			var coat: Color = WORD_B_COATS[k - WORD_A.length() - 1] if in_b else WORD_A_COAT
			letters.append([el, text[k], Vector2(left + _x_of(text, k, TEXT_SIZE), baseline), coat, TEXT_SIZE])
		text_box = Rect2(Vector2(left - 1.0, baseline - float(TEXT_SIZE) - 1.0), Vector2(text_w + 2.0, float(TEXT_SIZE) + 2.0))

		# POWERED BY GODOT: the robot, and the two lines beside it, centred one view down.
		var robot_size := Vector2(32.0, 30.0)
		var words_w := maxf(FONT.get_string_size(POWERED, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x, FONT.get_string_size(GODOT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x)
		var total := robot_size.x + 8.0 + words_w
		var top := roundf(float(RES.y) * 0.5 + float(PAN) - robot_size.y * 0.5 + 2.0)
		var x0 := roundf((float(RES.x) - total) * 0.5)
		_robot_rect = Rect2(Vector2(x0, top), robot_size)
		var wx := x0 + robot_size.x + 8.0
		for k in POWERED.length():
			if POWERED[k] != " ":
				letters.append([EL_POWERED, POWERED[k], Vector2(wx + _x_of(POWERED, k, SMALL_SIZE), top + 10.0), POWERED_COAT, SMALL_SIZE])
		for k in GODOT.length():
			letters.append([EL_GODOT, GODOT[k], Vector2(wx + _x_of(GODOT, k, TEXT_SIZE), top + 32.0), GODOT_COAT, TEXT_SIZE])
		godot_box = Rect2(Vector2(x0, top), Vector2(total, 32.0))
		_layout_robot()

	func _x_of(text: String, k: int, size: int) -> float:
		return FONT.get_string_size(text.substr(0, k), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

	func _layout_robot() -> void:
		var rows: Array = ROBOT
		var h := rows.size()
		var w: int = (rows[0] as String).length()
		var eyes := Rect2()
		for y in h:
			var row: String = rows[y]
			for x in w:
				var c := row[x]
				if c == ".":
					continue
				var r := Rect2(_robot_rect.position + Vector2(x, y) * 2.0, Vector2(2, 2))
				if c == "K":
					_robot_pupil.append(r)
				elif c == "W":
					# The white rings around the pupils are the eyes; the rest is the
					# nose and the jaw line.
					var eye := y >= 6 and y <= 8 and (x <= 5 or x >= 10)
					(_robot_eye if eye else _robot_line).append(r)
					if eye:
						eyes = r if eyes.size == Vector2.ZERO else eyes.merge(r)
				elif _edge(rows, x, y):
					_robot_tube.append(r)
				else:
					_robot_panel.append(r)
		_eyes_rect = eyes

	func _edge(rows: Array, x: int, y: int) -> bool:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if ny < 0 or ny >= rows.size() or nx < 0 or nx >= (rows[ny] as String).length():
				return true
			if (rows[ny] as String)[nx] == ".":
				return true
		return false

	func text_end() -> Vector2:
		return Vector2(text_box.end.x, text_box.end.y - 1.0)

	## Each element's rectangle for the glow, in element order (world coordinates).
	func rects() -> PackedVector4Array:
		var out := PackedVector4Array()
		out.resize(ELEMENTS)
		var boxes := {}
		for i in 9:
			boxes[i] = tile_rect(i)
		boxes[EL_ROBOT] = _robot_rect.grow(-2.0)
		boxes[EL_EYES] = _eyes_rect
		for l in letters:
			var pos: Vector2 = l[2]
			var ch: String = l[1]
			var size: int = l[4]
			var cw := FONT.get_char_size(ch.unicode_at(0), size).x
			var h := float(size) * (0.8 if ch == "a" or ch == "s" else 1.0)
			var r := Rect2(pos.x - 1.0, pos.y - h - 1.0, cw + 1.0, h + 2.0)
			boxes[l[0]] = boxes[l[0]].merge(r) if boxes.has(l[0]) else r
		for i in boxes:
			var r: Rect2 = boxes[i]
			out[i] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
		return out

	## The colour an element lights its surroundings with.
	func glow_color(i: int) -> Color:
		if i < FIRST_A:
			return TILE_COLORS[i]
		if i == EL_ROBOT:
			return ROBOT_COAT
		if i == EL_EYES:
			return ROBOT_COAT.lerp(Color.WHITE, 0.5)
		for l in letters:
			if l[0] == i:
				return (l[3] as Color).lerp(Color.WHITE, 0.3)
		return Color.BLACK

	## How much an element lights the wall (a full tile 1; a word's thin strokes less).
	func glow_weight(i: int) -> float:
		if i < FIRST_A:
			return 1.0
		if i < EL_ROBOT:
			return 0.4
		match i:
			EL_ROBOT:
				return 1.6
			EL_EYES:
				return 0.25
			EL_POWERED:
				return 0.35
		return 0.7

	func tile_rect(i: int) -> Rect2:
		return Rect2(mosaic.position + Vector2(i % 3, i / 3) * TILE, Vector2(TILE - 1, TILE - 1))

	func _draw() -> void:
		if levels.size() < ELEMENTS:
			return
		for i in 9:
			var r := tile_rect(i)
			var c: Color = TILE_COLORS[i]
			var v := levels[i]
			var f := flashes[i]
			# A tube bent into a square (round corners) around a panel of coloured glass
			# it lights from inside. Alpha tells the shader which glass is which: the
			# tube is coated (1), the panel clear (PANEL_GLASS).
			draw_rect(r, _light(c, v * 0.5, PANEL_GLASS))
			var tube := _light(c.lerp(Color.WHITE, 0.4 + 0.3 * f), v)
			var q := r.grow(-1.0)
			draw_rect(Rect2(q.position + Vector2(1, 0), Vector2(q.size.x - 2, 2)), tube)
			draw_rect(Rect2(Vector2(q.position.x + 1, q.end.y - 2), Vector2(q.size.x - 2, 2)), tube)
			draw_rect(Rect2(q.position + Vector2(0, 1), Vector2(2, q.size.y - 2)), tube)
			draw_rect(Rect2(Vector2(q.end.x - 2, q.position.y + 1), Vector2(2, q.size.y - 2)), tube)
		# The robot: the same glass and tubes as the tiles.
		var v := levels[EL_ROBOT]
		var f := flashes[EL_ROBOT]
		for r in _robot_panel:
			draw_rect(r, _light(ROBOT_COAT, v * 0.5, PANEL_GLASS))
		for r in _robot_pupil:
			draw_rect(r, _light(ROBOT_COAT, v * 0.05, PANEL_GLASS))
		var tube := _light(ROBOT_COAT.lerp(Color.WHITE, 0.4 + 0.3 * f), v)
		for r in _robot_tube:
			draw_rect(r, tube)
		var line := _light(ROBOT_COAT.lerp(Color.WHITE, 0.72 + 0.25 * f), v)
		for r in _robot_line:
			draw_rect(r, line)
		var eye := _light(ROBOT_COAT.lerp(Color.WHITE, 0.72 + 0.25 * flashes[EL_EYES]), levels[EL_EYES])
		for r in _robot_eye:
			draw_rect(r, eye)
		for l in letters:
			var lv := levels[l[0]]
			var coat: Color = l[3]
			var pos: Vector2 = l[2]
			var size: int = l[4]
			# Big letters get a coat around a white-hot core; the small line is one thin tube.
			if size >= TEXT_SIZE:
				var halo := _light(coat, lv * 0.85)
				for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
					draw_string(FONT, pos + o, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, halo)
				draw_string(FONT, pos, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, _light(coat.lerp(Color.WHITE, 0.55 + 0.3 * flashes[l[0]]), lv))
			else:
				draw_string(FONT, pos, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, _light(coat.lerp(Color.WHITE, 0.45 + 0.3 * flashes[l[0]]), lv))

	func _light(c: Color, v: float, glass: float = 1.0) -> Color:
		return Color(clampf(c.r * v, 0.0, 1.0), clampf(c.g * v, 0.0, 1.0), clampf(c.b * v, 0.0, 1.0), glass)


# ── moths: drawn over the finished picture ────────────────────────────────────

class _Moths:
	extends Node2D

	## Set when a moth flies into a lit tile (the splash plays a tap and clears it).
	var tapped := false
	var _sign
	var _params: Array = []
	var _pos: Array = []
	var _was_on_tile: Array = []
	var _t := 0.0
	var _pan := 0.0
	var _levels := PackedFloat32Array()
	var _lits := Vector2.ZERO

	func setup(rng: RandomNumberGenerator, sign) -> void:
		_sign = sign
		for m in MOTHS + GODOT_MOTHS:
			var godot := m >= MOTHS
			var spread := Vector2(30.0, 14.0) if godot else Vector2(46.0, 25.0)
			var p := {
				"home": 1 if godot else 0,
				"off": Vector2(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y, spread.y)),
				"arrive": float(m - MOTHS) * 0.5 + rng.randf_range(0.2, 0.6) if godot else 1.0 + float(m) * 0.4 + rng.randf_range(0.0, 0.3),
				"from": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * 220.0,
				"flap": rng.randf_range(0.0, 10.0),
				"ax": [rng.randf_range(18.0, 38.0) * (0.7 if godot else 1.0), rng.randf_range(6.0, 14.0), rng.randf_range(1.5, 4.0)],
				"ay": [rng.randf_range(10.0, 24.0) * (0.6 if godot else 1.0), rng.randf_range(5.0, 12.0), rng.randf_range(1.5, 4.0)],
				"w": [rng.randf_range(0.6, 1.3), rng.randf_range(2.0, 4.2), rng.randf_range(7.0, 13.0)],
				"wy": [rng.randf_range(0.5, 1.2), rng.randf_range(2.2, 4.6), rng.randf_range(8.0, 14.0)],
				"ph": [rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)],
			}
			_params.append(p)
			_pos.append(Vector2.ZERO)
			_was_on_tile.append(false)

	## Where a swarm gathers, in the wall (it does not follow the view).
	func _centre(home: int) -> Vector2:
		return _sign.godot_box.get_center() if home == 1 else _sign.mosaic.get_center() + Vector2(0.0, 22.0)

	## lits: how bright UNDO LABS (x) and POWERED BY GODOT (y) burn; godot_at: when the
	## robot strikes (its moths come then).
	func update_to(t: float, levels: PackedFloat32Array, lits: Vector2, pan: float, godot_at: float) -> void:
		_t = t
		_levels = levels
		_lits = lits
		_pan = pan
		for m in _params.size():
			var p: Dictionary = _params[m]
			var home: int = p.home
			var centre := _centre(home)
			var ax: Array = p.ax
			var ay: Array = p.ay
			var w: Array = p.w
			var wy: Array = p.wy
			var ph: Array = p.ph
			var path: Vector2 = centre + p.off
			for k in 3:
				path += Vector2(ax[k] * sin(w[k] * t + ph[k]), ay[k] * sin(wy[k] * t + ph[k + 3]))
			var arrive: float = float(p.arrive) + (godot_at if home == 1 else 0.0)
			var a := smoothstep(arrive, arrive + 1.4, t)
			var pos: Vector2 = (centre + p.from).lerp(path, a)
			_pos[m] = pos.round()
			var on := _tile_under(_pos[m]) >= 0
			if on and not _was_on_tile[m]:
				tapped = true
			_was_on_tile[m] = on
		queue_redraw()

	func _tile_under(p: Vector2) -> int:
		for i in 9:
			if _sign.tile_rect(i).has_point(p) and _levels.size() > i and _levels[i] > 0.3:
				return i
		return -1

	func _draw() -> void:
		var view := Vector2(0.0, -_pan)
		for m in _params.size():
			var p: Vector2 = _pos[m]
			var home: int = _params[m].home
			var lit: float = _lits.y if home == 1 else _lits.x
			if lit < 0.02:
				continue
			var col: Color
			if _tile_under(p) >= 0:
				col = Color(0.03, 0.02, 0.04)
			else:
				var k := lit * exp(-p.distance_to(_centre(home)) / 75.0) * 1.3
				if k < 0.03:
					continue
				col = Color(0.72 * k, 0.62 * k, 0.70 * k)
			var s := p + view
			var open := int(_t * 22.0 + _params[m].flap) % 2 == 0
			draw_rect(Rect2(s, Vector2.ONE), col)
			if open:
				draw_rect(Rect2(s + Vector2(-1, -1), Vector2.ONE), col)
				draw_rect(Rect2(s + Vector2(1, -1), Vector2.ONE), col)
			else:
				draw_rect(Rect2(s + Vector2(0, -1), Vector2.ONE), col)


# ── the owl on the transformer box ───────────────────────────────────────────

## A tawny owl: a silhouette the neon lights from the front, eyes that catch any light
## going (amber eyeshine, the moon is enough), a blink now and then, the head turning;
## it turns to the robot when it strikes and hoots (rises a pixel twice). When the power
## goes it sits on a moment in the dark, then lifts off up the wall and away.
class _Owl:
	extends Node2D

	## B body, L face disc and breast, E eye, k beak, F feet; 9x13. The face rows are built
	## per frame (the head turns).
	const BODY := [
		"B.......B",
		"BB.....BB",
		"BBBBBBBBB",
		"BLLLLLLLB",
		"",
		"",
		"BBLLLLLBB",
		"BBLBLBLBB",
		"BBBLBLBBB",
		"BBBBLBBBB",
		".BBBBBBB.",
		"..BBBBB..",
		"..F...F..",
	]
	const WINGS_UP := [
		"BBB.......BBB",
		".BBB.....BBB.",
		"..BBB...BBB..",
		"...BBBBBBB...",
		".....BBB.....",
		".....B.B.....",
	]
	const WINGS_DOWN := [
		".....BBB.....",
		"...BBBBBBB...",
		".BBB.BBB.BBB.",
		"BB...BBB...BB",
		".....B.B.....",
	]

	var perch := Vector2.ZERO
	var _t := 0.0
	var _pan := 0.0
	var _light := 0.0
	var _fade := 1.0
	var _turned_at := INF
	var _hoot_at := INF
	var _fly_at := INF

	func update_to(t: float, pan: float, light: float, fade: float, turned_at: float, hoot_at: float, fly_at: float) -> void:
		_t = t
		_pan = pan
		_light = light
		_fade = fade
		_turned_at = turned_at
		_hoot_at = hoot_at
		_fly_at = fly_at
		queue_redraw()

	func _draw() -> void:
		var at := perch - Vector2(0.0, _pan)
		if at.y > float(RES.y) + 2.0:
			return
		var k := clampf(_light, 0.0, 1.0)
		var f := _fade
		var body := Color((0.08 + 0.10 * k) * f, (0.07 + 0.16 * k) * f, (0.06 + 0.20 * k) * f)
		if _t >= _fly_at:
			var dt := _t - _fly_at
			var pos := at + Vector2(dt * 46.0, -dt * 30.0 - dt * dt * 14.0)
			var frame: Array = WINGS_UP if int(dt / 0.09) % 2 == 0 else WINGS_DOWN
			_blit(frame, pos - Vector2(2.0, -4.0), {"B": body})
			return
		var light_face := Color((0.20 + 0.30 * k) * f, (0.16 + 0.34 * k) * f, (0.12 + 0.36 * k) * f)
		var eye_k := 0.35 + 0.65 * k
		var eye := Color(1.0 * eye_k * f, 0.72 * eye_k * f, 0.22 * eye_k * f)
		# Where it looks: about, then at the robot once it strikes (the sign is to its left).
		var turn := 0
		if _t >= _turned_at and _t < _turned_at + 2.6:
			turn = -1
		else:
			var n := int(floor((_t + 0.7) / 1.7))
			turn = [0, -1, 0, 1, 0, 0, -1][n % 7]
		var blink := fposmod(_t + 0.9, 2.8) < 0.12
		var e := "L" if blink else "E"
		var face := ["B", "L", "L", "L", "L", "L", "L", "L", "B"]
		var beak := ["B", "L", "L", "L", "L", "L", "L", "L", "B"]
		for i in [2, 3, 5, 6]:
			face[i + turn] = e
		beak[4 + turn] = "k"
		var rows: Array = BODY.duplicate()
		rows[4] = "".join(face)
		rows[5] = "".join(beak)
		# A hoot: it rises a pixel, twice.
		var lift := 0.0
		var h := _t - _hoot_at
		if (h >= 0.0 and h < 0.22) or (h >= 0.42 and h < 0.7):
			lift = -1.0
		_blit(rows, at + Vector2(0.0, lift), {
			"B": body, "L": light_face, "E": eye,
			"k": Color(0.30 * f * (0.5 + k), 0.26 * f * (0.5 + k), 0.18 * f * (0.5 + k)),
			"F": Color(0.30 * f * (0.5 + k), 0.24 * f * (0.5 + k), 0.12 * f * (0.5 + k)),
		})
		# The neon is to its left: a cyan rim down that side.
		if k > 0.05:
			var rim := Color(0.10 * k * f, 0.55 * k * f, 0.70 * k * f)
			for y in rows.size() - 1:
				var row: String = rows[y]
				var x := 0
				while x < row.length() and row[x] == ".":
					x += 1
				if x < row.length():
					draw_rect(Rect2(at + Vector2(x, y + lift), Vector2.ONE), rim)

	func _blit(rows: Array, at: Vector2, colors: Dictionary) -> void:
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				var c := row[x]
				if colors.has(c):
					draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), colors[c])


# ── leaves on the wind ────────────────────────────────────────────────────────

## A few autumn leaves blowing across in front of the wall on a gusty breeze, tumbling,
## lit by the neon when they pass near it. Positions are a function of time (the bake
## tool seeks) from a fixed seed, so the first frame matches the boot image.
class _Leaves:
	extends Node2D

	const COUNT := 12
	const COLORS := [Color(0.55, 0.30, 0.08), Color(0.62, 0.45, 0.12), Color(0.45, 0.18, 0.06), Color(0.50, 0.38, 0.10)]
	var _p: Array = []
	var _t := 0.0
	var _light := 0.0
	var _centre := Vector2.ZERO
	var _fade := 1.0
	var _pan := 0.0

	## The breeze: 1 on average, gusting to ~2.
	static func gust(t: float) -> float:
		return 1.0 + 0.6 * sin(t * 0.9) + 0.35 * sin(t * 2.3 + 1.0)

	## How far the breeze has carried things by t (the integral of gust()).
	static func carried(t: float) -> float:
		return t - 0.667 * cos(t * 0.9) - 0.152 * cos(t * 2.3 + 1.0)

	func setup() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in COUNT:
			_p.append({
				"x": rng.randf_range(0.0, float(RES.x) + 40.0), "y": rng.randf_range(0.0, float(RES.y) + 20.0),
				"speed": rng.randf_range(16.0, 30.0), "fall": rng.randf_range(4.0, 11.0),
				"amp": rng.randf_range(2.0, 6.0), "w": rng.randf_range(1.5, 3.5), "ph": rng.randf_range(0.0, TAU),
				"spin": rng.randf_range(5.0, 11.0), "c": rng.randi() % COLORS.size(),
			})

	func update_to(t: float, light: float, centre: Vector2, fade: float, pan: float) -> void:
		_t = t
		_light = light
		_centre = centre
		_fade = fade
		_pan = pan
		queue_redraw()

	func _draw() -> void:
		var travel := carried(_t)
		for p: Dictionary in _p:
			var x: float = fposmod(float(p.x) + float(p.speed) * travel, float(RES.x) + 40.0) - 20.0
			var y: float = fposmod(float(p.y) + float(p.fall) * _t - _pan, float(RES.y) + 20.0) - 10.0 + float(p.amp) * sin(float(p.w) * _t + float(p.ph))
			var at := Vector2(x, y).round()
			var k := 0.32 + _light * exp(-at.distance_to(_centre) / 80.0) * 1.5
			var base: Color = COLORS[int(p.c)]
			var col := Color(base.r * k * _fade, base.g * k * _fade, base.b * k * _fade)
			draw_rect(Rect2(at, Vector2.ONE), col)
			# Tumbling: flat, edge on, turning over.
			match int(_t * float(p.spin) + float(p.ph)) % 4:
				0:
					draw_rect(Rect2(at + Vector2(1, 0), Vector2.ONE), col)
					draw_rect(Rect2(at + Vector2(0, 1), Vector2(2, 1)), col)
				1:
					draw_rect(Rect2(at + Vector2(0, 1), Vector2.ONE), col)
				2:
					draw_rect(Rect2(at + Vector2(1, 1), Vector2(1, 1)), col)
					draw_rect(Rect2(at + Vector2(-1, 0), Vector2.ONE), col)
				_:
					draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 1)), col)
