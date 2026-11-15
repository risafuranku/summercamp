extends CanvasLayer

## Scrubbing a toilet bowl, close up (playtest 2026-10-17: "a satisfying minigame where
## the dirt fades away exactly where you move the cursor"). The bowl is a painting
## (textury/closeup/wc_bowl.png), the filth a second one laid over it
## (textury/closeup/wc_dirt.png) through a mask, one value a few picture pixels, that the
## brush wears down wherever you drag it with the button held: the faster you go the more
## it takes, the centre of the brush more than its edge. Suds fly, the brush rasps while it
## moves, each patch you finish squeaks; when the bowl is spotless it flushes, SPOTLESS is
## stamped over it and you are done. S or a right click puts the brush down: what you did
## stays done, the bowl waits for you.
##
## Worked through (playtest 14. 11.: "polish and work out the scrubbing of the bowl"): round
## the water line a crust of scale (the same filth, its own ring mask, yellowed) that long
## strokes hardly touch: it comes off with short hard strokes to and fro, each turn of the
## brush biting at it, and grits as it does; the water at the bottom goes murky with what
## comes off; the flush at the end swirls it round and away, clear. How clean stands over the
## picture's top left, out from under the hand.

const INSTANCE = preload("res://scripts/instance/instance.gd")
signal finished(task_id: String)
signal closed

const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const WORK_HAND = preload("res://scripts/ui/work_hand.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const LANG = preload("res://scripts/lang.gd")
const BOWL := "res://assets/textury/closeup/wc_bowl.png"
const DIRT := "res://assets/textury/closeup/wc_dirt.png"
const SFX := "res://assets/sfx/rooms/"
const PIC := Vector2(320, 240)
## Where the filth lies on the bowl painting (picture pixels).
const DIRT_RECT := Rect2(87, 40, 148, 137)
const MASK := Vector2i(96, 96)
## The brush, in picture pixels: a hard core and a soft edge.
const BRUSH_R := 15.0
const DONE_AT := 0.035
## The water in the bowl and the scale round its line (picture pixels: centre, radii; the
## ring's thickness), the scale's share of the whole job, how much a turn of the brush takes
## of it, and how little a plain stroke does.
const WATER_C := Vector2(160, 144)
const WATER_R := Vector2(25, 12)
const RING_C := Vector2(160, 139)
const RING_R := Vector2(40, 23)
const RING_T := 5.0
const RING_SHARE := 0.3
const RING_TURN := 0.32
const RING_RUB := 0.04
const FLUSH_SEC := 1.4
const BOWL_SHADER := """
shader_type canvas_item;
uniform vec2 water_c;
uniform vec2 water_r;
uniform float murk = 0.0;
uniform float swirl = 0.0;
void fragment() {
	vec2 d = (UV - water_c) / water_r;
	float r = length(d);
	float inside = 1.0 - smoothstep(0.8, 1.0, r);
	vec2 uv = UV;
	if (inside > 0.0 && swirl != 0.0) {
		float a = swirl * (1.15 - r);
		vec2 rd = vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
		uv = mix(UV, water_c + rd * water_r, inside);
	}
	vec4 c = texture(TEXTURE, uv);
	c.rgb = mix(c.rgb, c.rgb * vec3(0.6, 0.48, 0.28), murk * inside);
	COLOR = c;
}
"""
const SHADER := """
shader_type canvas_item;
uniform sampler2D mask_tex : filter_linear;
uniform vec2 flip = vec2(0.0);
uniform float fade = 1.0;
void fragment() {
	vec2 uv = mix(UV, 1.0 - UV, flip);
	vec4 c = texture(TEXTURE, uv);
	c.a *= texture(mask_tex, UV).r * fade;
	COLOR = c;
}
"""

var _task := ""
var _bowl: Texture2D
var _dirt: Texture2D
var _mask: Image
var _mask_tex: ImageTexture
var _weight := PackedFloat32Array()
var _total := 1.0
var _left := 1.0
var _view: Control
var _dirt_rect: TextureRect
var _mat: ShaderMaterial
var _hand: Control
var _k := 3.0
var _origin := Vector2.ZERO
var _scrub: AudioStreamPlayer
var _one: AudioStreamPlayer
var _last_mouse := Vector2.ZERO
var _speed := 0.0
var _suds: Array = []
var _sparkles: Array = []
var _done_t := -1.0
var _next_squeak := 0.92
var _states: Dictionary = {}     # task id -> {mask: Image, ring: Image, seed}
var _ring: Image
var _ring_tex: ImageTexture
var _ring_weight := PackedFloat32Array()
var _ring_total := 1.0
var _ring_left := 1.0
## How much there was to do when this bowl's filth came (the gauge starts at 0 %).
var _left0 := 1.0
var _dirt_left := 1.0
var _ring_rect: TextureRect
var _ring_mat: ShaderMaterial
var _bowl_rect: TextureRect
var _bowl_mat: ShaderMaterial
## The brush's way to and fro: its last direction, and a turn just made (the scale's bite).
var _last_dir := Vector2.ZERO
var _turned := 0.0
var _grit: AudioStreamPlayer
var _grit_t := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	layer = 96
	add_to_group("closeup")  # the hands are on it (pockets.gd)
	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	add_child(_view)
	# The bowl: its water goes murky and swirls at the flush (BOWL_SHADER).
	_bowl_rect = TextureRect.new()
	_bowl_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bowl_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bowl_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bowl_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bowl_mat = ShaderMaterial.new()
	var bsh := Shader.new()
	bsh.code = BOWL_SHADER
	_bowl_mat.shader = bsh
	_bowl_mat.set_shader_parameter("water_c", WATER_C / PIC)
	_bowl_mat.set_shader_parameter("water_r", WATER_R / PIC)
	_bowl_rect.material = _bowl_mat
	add_child(_bowl_rect)
	# The scale round the water line: the filth's picture yellowed, through its ring's mask.
	_ring_rect = TextureRect.new()
	_ring_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_ring_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ring_rect.modulate = Color(1.0, 0.82, 0.46)
	_ring_mat = ShaderMaterial.new()
	var rsh := Shader.new()
	rsh.code = SHADER
	_ring_mat.shader = rsh
	_ring_rect.material = _ring_mat
	add_child(_ring_rect)
	_dirt_rect = TextureRect.new()
	_dirt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dirt_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dirt_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_dirt_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_dirt_rect.material = _mat
	add_child(_dirt_rect)
	var over := Control.new()
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.draw.connect(func(): _draw_over(over))
	over.name = "Over"
	add_child(over)
	_hand = WORK_HAND.new()
	add_child(_hand)
	_scrub = AudioStreamPlayer.new()
	_scrub.volume_db = -60.0
	if ResourceLoader.exists(SFX + "scrub_loop.mp3"):
		var st := (load(SFX + "scrub_loop.mp3") as AudioStreamMP3).duplicate() as AudioStreamMP3
		st.loop = true
		_scrub.stream = st
	add_child(_scrub)
	_one = AudioStreamPlayer.new()
	add_child(_one)
	# The scale's grit under the bristles: the rasp, lower and harder.
	_grit = AudioStreamPlayer.new()
	_grit.volume_db = -60.0
	_grit.pitch_scale = 0.7
	if _scrub.stream != null:
		_grit.stream = _scrub.stream
	add_child(_grit)
	# Loaded here, not in a draw (a texture first loaded inside a draw call comes out white).
	_bowl = load(BOWL) if ResourceLoader.exists(BOWL) else null
	_dirt = load(DIRT) if ResourceLoader.exists(DIRT) else null
	_dirt_rect.texture = _dirt
	_ring_rect.texture = _dirt
	_bowl_rect.texture = _bowl


func is_open() -> bool:
	return visible


## `task_id` names the bowl (the same bowl comes back as it was left); `seed` varies the
## filth from one dirty day to the next.
func open(task_id: String, seed: int) -> void:
	_task = task_id
	_rng.seed = seed
	_done_t = -1.0
	_suds.clear()
	_sparkles.clear()
	var st: Dictionary = _states.get(task_id, {})
	var fresh: bool = st.is_empty() or int(st.get("seed", 0)) != seed or not st.has("ring")
	if fresh:
		_fresh_mask(seed)
		_fresh_ring(seed)
	else:
		_mask = (st["mask"] as Image).duplicate()
		_ring = (st["ring"] as Image).duplicate()
	_measure()
	_left0 = _left if fresh else maxf(0.001, float(st.get("left0", _left)))
	_next_squeak = floorf(_left * 12.0) / 12.0
	_mask_tex = ImageTexture.create_from_image(_mask)
	_mat.set_shader_parameter("mask_tex", _mask_tex)
	_ring_tex = ImageTexture.create_from_image(_ring)
	_ring_mat.set_shader_parameter("mask_tex", _ring_tex)
	_ring_mat.set_shader_parameter("fade", 1.0)
	_bowl_mat.set_shader_parameter("swirl", 0.0)
	_last_dir = Vector2.ZERO
	_turned = 0.0
	_mat.set_shader_parameter("flip", Vector2(float(seed & 1), float((seed >> 1) & 1) * 0.0))
	_mat.set_shader_parameter("fade", 1.0)
	visible = true
	INSTANCE.input(self).set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_layout()
	_scrub.play()
	if _grit.stream != null:
		_grit.play()
	_hand.start("Scrubbing", get_viewport().get_mouse_position())


func close() -> void:
	if not visible:
		return
	if _done_t < 0.0 and _mask != null:
		_states[_task] = {"mask": _mask.duplicate(), "ring": _ring.duplicate(), "seed": _rng.seed, "left0": _left0}
	visible = false
	_scrub.stop()
	_grit.stop()
	_hand.stop()
	closed.emit()


## How the filth lies this time: the painting's own blots, some of them thinner, a few
## streaks the brush already took off last time (seeded).
func _fresh_mask(seed: int) -> void:
	_mask = Image.create(MASK.x, MASK.y, false, Image.FORMAT_L8)
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.06
	for y in MASK.y:
		for x in MASK.x:
			var v := 0.62 + 0.55 * n.get_noise_2d(x, y)
			_mask.set_pixel(x, y, Color(clampf(v, 0.18, 1.0), 0, 0))


## The scale round the water line: a band of the ring's ellipse in the mask's cells, thicker
## and thinner along it (seeded).
func _fresh_ring(seed: int) -> void:
	_ring = Image.create(MASK.x, MASK.y, false, Image.FORMAT_L8)
	var n := FastNoiseLite.new()
	n.seed = seed + 17
	n.frequency = 0.12
	for y in MASK.y:
		for x in MASK.x:
			var b := _ring_band(x, y)
			if b <= 0.0:
				_ring.set_pixel(x, y, Color(0, 0, 0))
				continue
			var v := b * clampf(0.75 + 0.5 * n.get_noise_2d(x, y), 0.25, 1.0)
			_ring.set_pixel(x, y, Color(v, 0, 0))


## How much a mask cell lies in the scale's band (0 off it .. 1 in its middle).
func _ring_band(x: int, y: int) -> float:
	var p := DIRT_RECT.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(MASK) * DIRT_RECT.size
	var d := ((p - RING_C) / RING_R).length()
	var t := absf(d - 1.0) * RING_R.y / RING_T
	# Only its near half shows (the far side is in the rim's shadow).
	if p.y < RING_C.y - RING_R.y * 0.35:
		return 0.0
	return clampf(1.0 - t, 0.0, 1.0)


## The share of the filth still there (weighted by how much dirt the painting has there).
func _measure() -> void:
	_weight.resize(MASK.x * MASK.y)
	var img: Image = _dirt.get_image() if _dirt != null else null
	if img != null and img.is_compressed():
		img.decompress()
	var total := 0.0
	var left := 0.0
	for y in MASK.y:
		for x in MASK.x:
			var a := 1.0
			if img != null:
				a = img.get_pixel(int((x + 0.5) / MASK.x * img.get_width()), int((y + 0.5) / MASK.y * img.get_height())).a
			_weight[y * MASK.x + x] = a
			total += a
			left += a * _mask.get_pixel(x, y).r
	_total = maxf(total, 0.001)
	_dirt_left = left / _total
	_ring_weight.resize(MASK.x * MASK.y)
	var rt := 0.0
	var rl := 0.0
	for y in MASK.y:
		for x in MASK.x:
			var w := _ring_band(x, y)
			_ring_weight[y * MASK.x + x] = w
			rt += w
			rl += w * _ring.get_pixel(x, y).r
	_ring_total = maxf(rt, 0.001)
	_ring_left = rl / _ring_total
	_sum_left()


## The whole job's share still to do: the filth and the scale.
func _sum_left() -> void:
	_left = _dirt_left * (1.0 - RING_SHARE) + _ring_left * RING_SHARE


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_k = float(maxi(1, int(floor(minf(vp.x * 0.86 / PIC.x, vp.y * 0.84 / PIC.y)))))
	_origin = ((vp - PIC * _k) * 0.5).floor()
	_dirt_rect.position = _origin + DIRT_RECT.position * _k
	_dirt_rect.size = DIRT_RECT.size * _k
	_ring_rect.position = _dirt_rect.position
	_ring_rect.size = _dirt_rect.size
	_bowl_rect.position = _origin
	_bowl_rect.size = PIC * _k
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT) \
			or event.is_action_pressed("ui_cancel") or INTERIOR_LOOK.is_space(event):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport().get_visible_rect().size
	if not is_equal_approx(_k, float(maxi(1, int(floor(minf(vp.x * 0.86 / PIC.x, vp.y * 0.84 / PIC.y)))))):
		_layout()
	var m := get_viewport().get_mouse_position()
	var mv := m - _last_mouse
	var moved := mv.length()
	_last_mouse = m
	# A turn of the brush (to and fro): what bites the scale.
	if moved > 2.0 * _k:
		var dir := mv / moved
		if _last_dir != Vector2.ZERO and _last_dir.dot(dir) < -0.3:
			_turned = 1.0
		_last_dir = dir
	_speed = lerpf(_speed, moved / maxf(delta, 0.001), clampf(delta * 12.0, 0.0, 1.0))
	# Not under the pause menu (a co-op camp is not paused).
	var held = INSTANCE.input(self).is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not HandCursor.menu_over
	_hand.aim(m)
	var scrubbing = held and _done_t < 0.0 and _over_dirt(m)
	if scrubbing:
		_wear(m, delta)
	# Over the filth the pointer is the double arrow: to and fro is what it wants.
	if _done_t < 0.0 and _over_dirt(m):
		HandCursor.want(HandCursor.RUB)
	# The rasp of the bristles follows the brush: loud when it goes, gone when it stops.
	var want_db := -6.0 + clampf(_speed / 900.0, 0.0, 1.0) * 6.0 if scrubbing and _speed > 40.0 else -60.0
	_scrub.volume_db = move_toward(_scrub.volume_db, want_db, delta * 120.0)
	_grit.volume_db = move_toward(_grit.volume_db, -4.0 if _grit_t > 0.0 else -60.0, delta * 160.0)
	_grit_t = maxf(0.0, _grit_t - delta)
	_turned = 0.0
	_scrub.pitch_scale = lerpf(0.9, 1.12, clampf(_speed / 1400.0, 0.0, 1.0))
	for s in _suds:
		s["p"] = Vector2(s["p"]) + Vector2(s["v"]) * delta
		s["v"] = Vector2(s["v"]) * 0.9 + Vector2(0, 40.0) * delta
		s["t"] = float(s["t"]) - delta
	_suds = _suds.filter(func(s): return float(s["t"]) > 0.0)
	for s in _sparkles:
		s["t"] = float(s["t"]) - delta
	_sparkles = _sparkles.filter(func(s): return float(s["t"]) > 0.0)
	# The water murky with what came off; at the flush swirled round and away, in steps.
	var murk := clampf((1.0 - _left / maxf(0.001, _left0)) * 0.85, 0.0, 0.7)
	if _done_t >= 0.0:
		var k := clampf(floorf(_done_t * 12.0) / 12.0 / FLUSH_SEC, 0.0, 1.0)
		_bowl_mat.set_shader_parameter("swirl", 11.0 * k * (1.0 - k * 0.5))
		murk *= 1.0 - k
		_ring_mat.set_shader_parameter("fade", clampf(1.0 - _done_t / 0.5, 0.0, 1.0))
	_bowl_mat.set_shader_parameter("murk", murk)
	if _done_t >= 0.0:
		_done_t += delta
		_mat.set_shader_parameter("fade", clampf(1.0 - _done_t / 0.5, 0.0, 1.0))
		if _done_t >= 2.0:
			var id := _task
			_states.erase(id)
			close()
			finished.emit(id)
	_view.queue_redraw()
	var over := get_node_or_null("Over") as Control
	if over != null:
		over.queue_redraw()


func _over_dirt(m: Vector2) -> bool:
	var r := Rect2(_dirt_rect.position, _dirt_rect.size).grow(BRUSH_R * _k)
	return r.has_point(m)


## The brush takes the filth off under it: more at its middle, more the faster it moves.
func _wear(m: Vector2, delta: float) -> void:
	var cell := Vector2(MASK) / _dirt_rect.size
	var c := (m - _dirt_rect.position) * cell
	var r := BRUSH_R * _k * cell.x
	var rate := (0.25 + 2.6 * clampf(_speed / 700.0, 0.0, 1.0)) * delta
	# The scale: a plain stroke hardly, a turn of the brush a bite.
	var ring_rate := RING_RUB * clampf(_speed / 700.0, 0.0, 1.0) * delta + RING_TURN * _turned
	var ring_taken := 0.0
	var taken := 0.0
	for y in range(maxi(0, int(c.y - r)), mini(MASK.y, int(c.y + r) + 1)):
		for x in range(maxi(0, int(c.x - r)), mini(MASK.x, int(c.x + r) + 1)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
			if d > 1.0:
				continue
			var fall := 1.0 if d < 0.55 else (1.0 - (d - 0.55) / 0.45)
			var rv := _ring.get_pixel(x, y).r
			if rv > 0.0 and ring_rate > 0.0:
				var nrv := maxf(0.0, rv - ring_rate * fall)
				_ring.set_pixel(x, y, Color(nrv, 0, 0))
				ring_taken += (rv - nrv) * _ring_weight[y * MASK.x + x]
			var v := _mask.get_pixel(x, y).r
			if v <= 0.0:
				continue
			var nv := maxf(0.0, v - rate * fall)
			_mask.set_pixel(x, y, Color(nv, 0, 0))
			taken += (v - nv) * _weight[y * MASK.x + x]
	if ring_taken > 0.0:
		_ring_tex.update(_ring)
		_ring_left = maxf(0.0, _ring_left - ring_taken / _ring_total)
		_grit_t = 0.15
	if taken <= 0.0 and ring_taken <= 0.0:
		return
	if taken > 0.0:
		_mask_tex.update(_mask)
		_dirt_left = maxf(0.0, _dirt_left - taken / _total)
	_sum_left()
	# Suds off the bristles.
	if _rng.randf() < 0.6:
		_suds.append({"p": m + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-6, 6)) * _k * 0.4, "v": Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-90, -20)) * _k * 0.4, "t": _rng.randf_range(0.3, 0.7), "s": _rng.randf_range(1.0, 2.5)})
	# Every twelfth of the bowl that comes clean squeaks.
	if _left < _next_squeak:
		_next_squeak -= 1.0 / 12.0
		_play("scrub_squeak.mp3", -8.0, _rng.randf_range(0.9, 1.25))
		_sparkles.append({"p": m, "t": 0.5})
	if _left <= DONE_AT and _done_t < 0.0:
		_finish()


## Shot driver: wipe what is left and finish (the drag itself is tested by hand).
func debug_finish() -> void:
	if _done_t < 0.0:
		_finish()


func _finish() -> void:
	_done_t = 0.0
	_left = 0.0
	_dirt_left = 0.0
	_ring_left = 0.0
	_hand.stop()
	_play("toilet_flush.mp3", -6.0, 1.0)
	for i in 7:
		_sparkles.append({"p": _dirt_rect.position + Vector2(_rng.randf(), _rng.randf()) * _dirt_rect.size, "t": _rng.randf_range(0.7, 1.6)})


func _play(file: String, db: float, pitch: float) -> void:
	if ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.volume_db = db
		_one.pitch_scale = pitch
		_one.play()


## The picture's frame (the bowl itself is _bowl_rect, its water under BOWL_SHADER).
func _draw_view() -> void:
	var r := Rect2(_origin, PIC * _k)
	_view.draw_rect(r.grow(2 * _k), Color(0.05, 0.04, 0.03))
	if _bowl == null:
		_view.draw_rect(r, Color(0.7, 0.7, 0.68))


func _draw_over(c: Control) -> void:
	for s in _suds:
		var a := clampf(float(s["t"]) / 0.4, 0.0, 1.0)
		var sz := float(s["s"]) * _k
		c.draw_rect(Rect2((Vector2(s["p"]) - Vector2(sz, sz) * 0.5).floor(), Vector2(sz, sz)), Color(0.95, 0.97, 1.0, 0.85 * a))
	for s in _sparkles:
		var a := clampf(float(s["t"]) / 0.5, 0.0, 1.0)
		var p: Vector2 = s["p"]
		var l := (3.0 + 5.0 * a) * _k
		c.draw_rect(Rect2(p - Vector2(l, _k * 0.5), Vector2(l * 2.0, _k)), Color(1, 1, 0.9, a))
		c.draw_rect(Rect2(p - Vector2(_k * 0.5, l), Vector2(_k, l * 2.0)), Color(1, 1, 0.9, a))
	# How clean: a small enamel gauge over the picture's top left (out from under the hand).
	var done := clampf(1.0 - _left / maxf(0.001, _left0), 0.0, 1.0) if _done_t < 0.0 else 1.0
	var clean := int(round(done * 100.0))
	var font: Font = RETRO_UI.FONT_BIG
	var fs := RETRO_UI.SIZE_BIG * int(_k)
	var txt := tr("SPOTLESS") if _done_t >= 0.0 else LANG.f("CLEAN %d%%", clean)
	var col := Color(0.6, 1.0, 0.65) if _done_t >= 0.0 else Color(0.95, 0.9, 0.7)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bar := Rect2(_origin + Vector2(2 * _k, -12 * _k), Vector2(PIC.x * _k * 0.36, 6 * _k))
	var at := (Vector2(bar.end.x + 8 * _k, _origin.y - 5 * _k)).floor()
	if _done_t >= 0.0:
		at = (_origin + Vector2((PIC.x * _k - w) * 0.5, PIC.y * _k * 0.5)).floor()
		var band := Rect2(at - Vector2(10 * _k, fs * 0.9), Vector2(w + 20 * _k, fs * 1.3))
		c.draw_rect(band, Color(0.04, 0.16, 0.06, 0.86))
		c.draw_rect(band, Color(0.45, 0.95, 0.5), false, _k)
	c.draw_string(font, at + Vector2(_k, _k), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
	c.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	c.draw_rect(bar, Color(0.1, 0.09, 0.08))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * done, bar.size.y)), Color(0.55, 0.85, 0.95))
	c.draw_rect(bar, Color(0.6, 0.56, 0.48), false, maxf(1.0, _k * 0.5))
