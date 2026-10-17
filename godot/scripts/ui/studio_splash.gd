extends Control

## The studio splash: UNDO LABS as a neon sign on a camp cabin wall at night, the 3x3
## brand mosaic and the name in tubes. It is the project's first scene (run/main_scene)
## and plays while main.tscn loads on a thread, then cuts to it. The engine's boot splash
## is this scene's first frame, baked by tools/studio_splash_bake.gd into
## assets/boot/undo_labs_boot.png, so the hand-over from the engine does not show.
##
##   0.0   dark: the coated glass in moonlight, crickets             (= the boot image)
##   0.45  the tiles strike one diagonal after another, starters ticking
##   1.4   UNDO, then "labs", which hesitates
##   ...   alive: the hum, a shimmer, one bad tube, moths, until main.tscn is loaded
##   cut   a brownout, a breath, then the camp's own power-out sound; black, crickets
##   then  main.tscn, whose title card covers the world generation
##
## Drawn at 320x180 in a SubViewport: the sign layer (_Sign) draws the tubes, the
## studio_neon shader lights the wall with them and adds glow, grain and dither, the
## moths fly over that. Shown like the engine's boot splash: kept aspect, nearest.
## Any key or click goes straight to the cut. Headless runs go straight to main.

const MAIN_SCENE := "res://scenes/main.tscn"
## main.WINDOW_TITLE (preloading main.gd here would load the whole game up front).
const WINDOW_TITLE := "Cursed Camp Manager Simulator"
const SHADER := preload("res://materials/studio_neon.gdshader")
const FONT: FontFile = preload("res://assets/fonts/jersey10.fnt")
const WALL_TEXTURE := "res://assets/textury/camp/planks_grey.png"
const SFX_DIR := "res://assets/sfx/splash/"
const SFX_POWER_OUT := "res://assets/sfx/power/power_out.mp3"
const SFX_CRICKETS := "res://assets/sfx/cricketi.mp3"

const RES := Vector2i(320, 180)
const TILE := 16
const TEXT_SIZE := 20
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
## Elements: 0..8 the tiles, then the letters of UNDO, then the letters of labs.
const FIRST_A := 9
const FIRST_B := 13
const ELEMENTS := 17
const CENTER_TILE := 4
## Tubes that may be the bad one (a corner, the middle, the "a").
const BAD_CANDIDATES := [0, 2, 6, 8, 4, 14]

const IGNITE_AT := 0.45
const DIAGONAL_STEP := 0.16
const EARLIEST_CUT := 3.6
## From the first dip of the brownout to the dark.
const BROWNOUT := 0.5
const DARK_HOLD := 0.85
const FADE_OUT := 0.3
## One launch in N, the middle tile goes on glowing a moment after the power is gone.
const UNCANNY_ODDS := 8
const UNCANNY_HOLD := 0.75

const MOTHS := 5
const HUM_DB := -15.0
const CRICKETS_DB := 2.0

## The bake tool: no audio, no loading, the clock is set with seek().
var preview := false

var _viewport: SubViewport
var _sign: _Sign
var _moths: _Moths
var _post_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
## Per element: Vector2(time, level) sorted by time; strike times for the flash.
var _keys: Array = []
var _strikes: Array = []
## [time, sound, dB] sorted by time.
var _events: Array = []
var _next_event := 0
var _bad := 0
var _cut_at := -1.0
var _off_at := INF
var _leave_at := INF
var _uncanny := false
var _t := 0.0
var _start_usec := -1
var _done := false
var _levels := PackedFloat32Array()
var _flashes := PackedFloat32Array()

var _hum: AudioStreamPlayer
var _crickets: AudioStreamPlayer
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
	_build_audio()
	ResourceLoader.load_threaded_request(MAIN_SCENE)


# ── preview (tools/studio_splash_bake.gd) ─────────────────────────────────────

func seek(t: float) -> void:
	_t = t
	_apply(t)


func preview_cut(at: float, uncanny: bool = false) -> void:
	_cut(at)
	_uncanny = uncanny


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
	_viewport.transparent_bg = true
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_sign = _Sign.new()
	_viewport.add_child(_sign)
	_sign.layout()

	var post := ColorRect.new()
	post.size = Vector2(RES)
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = SHADER
	_post_mat.set_shader_parameter("wall_tex", ImageTexture.create_from_image(_compose_wall()))
	post.material = _post_mat
	_viewport.add_child(post)

	_moths = _Moths.new()
	_moths.setup(_rng, _sign)
	_viewport.add_child(_moths)

	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)


## The cabin wall: grey planks, and the sign's cable running to its transformer box.
func _compose_wall() -> Image:
	var src := (load(WALL_TEXTURE) as Texture2D).get_image()
	src.convert(Image.FORMAT_RGBA8)
	var wall := Image.create(RES.x, RES.y, false, Image.FORMAT_RGBA8)
	var tw := src.get_width()
	var th := src.get_height()
	var y := -37
	while y < RES.y:
		var x := -21
		while x < RES.x:
			wall.blit_rect(src, Rect2i(0, 0, tw, th), Vector2i(x, y))
			x += tw
		y += th
	var cable := Color(0.05, 0.045, 0.05)
	var end := _sign.text_end()
	var box := Rect2i(int(end.x) + 14, int(end.y) + 12, 15, 11)
	var run_x := box.position.x + 7
	wall.fill_rect(Rect2i(int(end.x) + 2, int(end.y) - 7, run_x - int(end.x) - 2, 1), cable)
	wall.fill_rect(Rect2i(run_x, int(end.y) - 7, 1, box.position.y - int(end.y) + 7), cable)
	wall.fill_rect(Rect2i(run_x, box.end.y, 1, RES.y - box.end.y), cable)
	wall.fill_rect(box, Color(0.21, 0.20, 0.18))
	wall.fill_rect(Rect2i(box.position, Vector2i(box.size.x, 1)), Color(0.36, 0.34, 0.30))
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
	var a_lit := _ignite(FIRST_A, last + 0.28, 2, 0.05, 0.12)
	_event(a_lit, "neon_strike", -11.0)
	for k in range(1, 4):
		_keys[FIRST_A + k] = _keys[FIRST_A].duplicate()
		_strikes[FIRST_A + k] = _strikes[FIRST_A].duplicate()
	# "labs" hesitates: more blinks, longer gaps.
	var b_lit := _ignite(FIRST_B, a_lit + 0.22, _rng.randi_range(3, 4), 0.09, 0.2)
	_event(b_lit, "neon_strike", -11.0)
	for k in range(1, 4):
		_keys[FIRST_B + k] = _keys[FIRST_B].duplicate()
		_strikes[FIRST_B + k] = _strikes[FIRST_B].duplicate()
	# The bad tube drops out now and then for as long as the sign is on.
	_bad = BAD_CANDIDATES[_rng.randi() % BAD_CANDIDATES.size()]
	var t := maxf(b_lit, _last_key(_bad)) + _rng.randf_range(0.35, 0.7)
	while t < 90.0:
		var drop: Array = _keys[_bad]
		drop.append(Vector2(t, 0.0))
		drop.append(Vector2(t + 0.05, 0.65))
		drop.append(Vector2(t + 0.08, 0.0))
		drop.append(Vector2(t + _rng.randf_range(0.14, 0.3), 1.0))
		_event(t, "neon_sputter", -17.0)
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
	_uncanny = not preview and _rng.randi() % UNCANNY_ODDS == 0
	var pending: Array = _events.slice(_next_event)
	_events = _events.slice(0, _next_event)
	for e in pending:
		if e[0] < at:
			_events.append(e)
	_event(at, "neon_sputter", -10.0)
	_event(at + 0.13, "neon_tick_2", -12.0)
	_event(_off_at, "power_out", -3.0)
	if _uncanny:
		_event(_off_at + UNCANNY_HOLD, "neon_tick_3", -20.0)
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


## Voltage on the sign: the brownout dips, stutters, comes back for a breath, goes.
func _power(t: float) -> float:
	if _cut_at < 0.0 or t < _cut_at:
		return 1.0
	var d := t - _cut_at
	if d < 0.07:
		return 0.42
	if d < 0.11:
		return 0.1
	if d < 0.28:
		return 0.45 + 0.35 * _hash(97, floor(t * 40.0))
	if d < BROWNOUT:
		return 1.0
	return 0.0


func _level(i: int, t: float) -> float:
	var v := 0.0
	for k in _keys[i]:
		if (k as Vector2).x > t:
			break
		v = (k as Vector2).y
	var flash := 0.0
	for s in _strikes[i]:
		if s <= t:
			flash = 0.5 * exp(-(t - s) / 0.12)
	_flashes[i] = flash if v > 0.0 else 0.0
	if v > 0.0:
		v *= 1.0 + 0.06 * (_hash(i, floor(t * 50.0)) - 0.5) + _flashes[i]
	if t >= _off_at:
		var glow := v * 0.45 * exp(-(t - _off_at) / 0.05)
		if _uncanny and i == CENTER_TILE and t > _off_at + 0.06 and t < _off_at + UNCANNY_HOLD:
			glow = 0.2 + 0.03 * _hash(i, floor(t * 12.0))
		_flashes[i] = 0.0
		return glow
	return v * _power(t)


func _hash(i: int, n: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + n * 78.233) * 43758.5453, 1.0)


func _apply(t: float) -> void:
	var lit := 0.0
	var flash := 0.0
	for i in ELEMENTS:
		_levels[i] = _level(i, t)
		lit += _levels[i] * (1.5 if i < 9 else 0.4)
		flash = maxf(flash, _flashes[i])
	lit /= 9.0 * 1.5 + 8.0 * 0.4
	_sign.levels = _levels
	_sign.flashes = _flashes
	_sign.queue_redraw()
	_moths.update_to(t, _levels, lit)
	_post_mat.set_shader_parameter("frame", floor(t * 24.0))
	_post_mat.set_shader_parameter("bloom", 1.0 + flash * 0.8)
	_post_mat.set_shader_parameter("spill", 1.0 + flash * 0.4)
	if _hum != null:
		_hum.volume_db = maxf(-80.0, linear_to_db(maxf(lit, 0.0001)) + HUM_DB) if t < _off_at else -80.0
		_hum.pitch_scale = lerpf(0.9, 1.0, _power(t)) if t < _off_at else 1.0


# ── running ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if preview or _done or _viewport == null:
		return
	var now := Time.get_ticks_usec()
	if _start_usec < 0:
		_start_usec = now
	_t = float(now - _start_usec) / 1000000.0
	var loaded := _main_loaded()
	if _cut_at < 0.0 and loaded and _t >= EARLIEST_CUT:
		_cut(_t)
	var dark_until := _off_at + DARK_HOLD + (UNCANNY_HOLD if _uncanny else 0.0)
	if _leave_at == INF and loaded and _t >= dark_until:
		_leave_at = _t + FADE_OUT
	_fire_events()
	_apply(_t)
	_crickets.volume_db = linear_to_db(clampf(_t / 0.6, 0.001, 1.0) * clampf((_leave_at - _t) / FADE_OUT, 0.001, 1.0)) + CRICKETS_DB
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


# ── the sign layer: rgb = light, a = glass ────────────────────────────────────

class _Sign:
	extends Node2D

	var levels := PackedFloat32Array()
	var flashes := PackedFloat32Array()
	var mosaic := Rect2()
	var text_box := Rect2()
	## [element, char, baseline position, coat colour]
	var letters: Array = []

	func layout() -> void:
		var w := float(TILE * 3 - 1)
		var text := WORD_A + " " + WORD_B
		var text_w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		mosaic = Rect2(Vector2(roundf((float(RES.x) - w) * 0.5), 40.0), Vector2(w, w))
		var baseline := mosaic.end.y + 14.0 + float(TEXT_SIZE)
		var left := roundf((float(RES.x) - text_w) * 0.5)
		letters.clear()
		for k in text.length():
			var ch := text[k]
			if ch == " ":
				continue
			var x := left + FONT.get_string_size(text.substr(0, k), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
			var in_b := k > WORD_A.length()
			var el := FIRST_B + (k - WORD_A.length() - 1) if in_b else FIRST_A + k
			var coat: Color = WORD_B_COATS[k - WORD_A.length() - 1] if in_b else WORD_A_COAT
			letters.append([el, ch, Vector2(x, baseline), coat])
		text_box = Rect2(Vector2(left - 1.0, baseline - float(TEXT_SIZE) - 1.0), Vector2(text_w + 2.0, float(TEXT_SIZE) + 2.0))

	func text_end() -> Vector2:
		return Vector2(text_box.end.x, text_box.end.y - 1.0)

	func tile_rect(i: int) -> Rect2:
		return Rect2(mosaic.position + Vector2(i % 3, i / 3) * TILE, Vector2(TILE - 1, TILE - 1))

	func _draw() -> void:
		if levels.size() < ELEMENTS:
			return
		for i in 9:
			var r := tile_rect(i)
			var c: Color = TILE_COLORS[i]
			var v := levels[i]
			draw_rect(r, _light(c, v * 0.82))
			draw_rect(r.grow(-2.0), _light(c.lerp(Color.WHITE, 0.18 + 0.3 * flashes[i]), v))
			draw_rect(r.grow(-4.0), _light(c.lerp(Color.WHITE, 0.42 + 0.4 * flashes[i]), v))
		for l in letters:
			var v := levels[l[0]]
			var coat: Color = l[3]
			var pos: Vector2 = l[2]
			var tube := _light(coat, v * 0.85)
			for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_string(FONT, pos + o, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, tube)
			draw_string(FONT, pos, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, _light(coat.lerp(Color.WHITE, 0.62 + 0.3 * flashes[l[0]]), v))

	func _light(c: Color, v: float) -> Color:
		return Color(clampf(c.r * v, 0.0, 1.0), clampf(c.g * v, 0.0, 1.0), clampf(c.b * v, 0.0, 1.0), 1.0)


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
	var _levels := PackedFloat32Array()
	var _lit := 0.0

	func setup(rng: RandomNumberGenerator, sign) -> void:
		_sign = sign
		for m in MOTHS:
			var p := {
				"off": Vector2(rng.randf_range(-46.0, 46.0), rng.randf_range(-30.0, 20.0)),
				"arrive": 1.0 + float(m) * 0.4 + rng.randf_range(0.0, 0.3),
				"from": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * 220.0,
				"flap": rng.randf_range(0.0, 10.0),
				"ax": [rng.randf_range(18.0, 38.0), rng.randf_range(6.0, 14.0), rng.randf_range(1.5, 4.0)],
				"ay": [rng.randf_range(10.0, 24.0), rng.randf_range(5.0, 12.0), rng.randf_range(1.5, 4.0)],
				"w": [rng.randf_range(0.6, 1.3), rng.randf_range(2.0, 4.2), rng.randf_range(7.0, 13.0)],
				"wy": [rng.randf_range(0.5, 1.2), rng.randf_range(2.2, 4.6), rng.randf_range(8.0, 14.0)],
				"ph": [rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)],
			}
			_params.append(p)
			_pos.append(Vector2.ZERO)
			_was_on_tile.append(false)

	func update_to(t: float, levels: PackedFloat32Array, lit: float) -> void:
		_t = t
		_levels = levels
		_lit = lit
		var centre: Vector2 = _sign.mosaic.get_center() + Vector2(0.0, 22.0)
		for m in _params.size():
			var p: Dictionary = _params[m]
			var ax: Array = p.ax
			var ay: Array = p.ay
			var w: Array = p.w
			var wy: Array = p.wy
			var ph: Array = p.ph
			var path: Vector2 = centre + p.off
			for k in 3:
				path += Vector2(ax[k] * sin(w[k] * t + ph[k]), ay[k] * sin(wy[k] * t + ph[k + 3]))
			var a := smoothstep(p.arrive, p.arrive + 1.4, t)
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
		if _lit < 0.02:
			return
		var centre: Vector2 = _sign.mosaic.get_center() + Vector2(0.0, 22.0)
		for m in _params.size():
			var p: Vector2 = _pos[m]
			var col: Color
			if _tile_under(p) >= 0:
				col = Color(0.03, 0.02, 0.04)
			else:
				var k := _lit * exp(-p.distance_to(centre) / 75.0) * 1.3
				if k < 0.03:
					continue
				col = Color(0.72 * k, 0.62 * k, 0.70 * k)
			var open := int(_t * 22.0 + _params[m].flap) % 2 == 0
			draw_rect(Rect2(p, Vector2.ONE), col)
			if open:
				draw_rect(Rect2(p + Vector2(-1, -1), Vector2.ONE), col)
				draw_rect(Rect2(p + Vector2(1, -1), Vector2.ONE), col)
			else:
				draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), col)
