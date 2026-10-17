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

signal finished(task_id: String)
signal closed

const WORK_HAND = preload("res://scripts/ui/work_hand.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
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
var _states: Dictionary = {}     # task id -> {mask: Image, left: float}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	layer = 96
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
	# Loaded here, not in a draw (a texture first loaded inside a draw call comes out white).
	_bowl = load(BOWL) if ResourceLoader.exists(BOWL) else null
	_dirt = load(DIRT) if ResourceLoader.exists(DIRT) else null
	_dirt_rect.texture = _dirt


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
	if st.is_empty() or int(st.get("seed", 0)) != seed:
		_fresh_mask(seed)
	else:
		_mask = (st["mask"] as Image).duplicate()
	_measure()
	_next_squeak = floorf(_left * 12.0) / 12.0
	_mask_tex = ImageTexture.create_from_image(_mask)
	_mat.set_shader_parameter("mask_tex", _mask_tex)
	_mat.set_shader_parameter("flip", Vector2(float(seed & 1), float((seed >> 1) & 1) * 0.0))
	_mat.set_shader_parameter("fade", 1.0)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_layout()
	_scrub.play()
	_hand.start("Scrubbing", get_viewport().get_mouse_position())


func close() -> void:
	if not visible:
		return
	if _done_t < 0.0 and _mask != null:
		_states[_task] = {"mask": _mask.duplicate(), "seed": _rng.seed}
	visible = false
	_scrub.stop()
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
	_left = left / _total


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_k = float(maxi(1, int(floor(minf(vp.x * 0.86 / PIC.x, vp.y * 0.84 / PIC.y)))))
	_origin = ((vp - PIC * _k) * 0.5).floor()
	_dirt_rect.position = _origin + DIRT_RECT.position * _k
	_dirt_rect.size = DIRT_RECT.size * _k
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event.is_action_pressed("ui_cancel"):
		return
	if (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT) \
			or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_S):
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
	var moved := (m - _last_mouse).length()
	_last_mouse = m
	_speed = lerpf(_speed, moved / maxf(delta, 0.001), clampf(delta * 12.0, 0.0, 1.0))
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_hand.aim(m)
	var scrubbing := held and _done_t < 0.0 and _over_dirt(m)
	if scrubbing:
		_wear(m, delta)
	# The rasp of the bristles follows the brush: loud when it goes, gone when it stops.
	var want_db := -6.0 + clampf(_speed / 900.0, 0.0, 1.0) * 6.0 if scrubbing and _speed > 40.0 else -60.0
	_scrub.volume_db = move_toward(_scrub.volume_db, want_db, delta * 120.0)
	_scrub.pitch_scale = lerpf(0.9, 1.12, clampf(_speed / 1400.0, 0.0, 1.0))
	for s in _suds:
		s["p"] = Vector2(s["p"]) + Vector2(s["v"]) * delta
		s["v"] = Vector2(s["v"]) * 0.9 + Vector2(0, 40.0) * delta
		s["t"] = float(s["t"]) - delta
	_suds = _suds.filter(func(s): return float(s["t"]) > 0.0)
	for s in _sparkles:
		s["t"] = float(s["t"]) - delta
	_sparkles = _sparkles.filter(func(s): return float(s["t"]) > 0.0)
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
	var taken := 0.0
	for y in range(maxi(0, int(c.y - r)), mini(MASK.y, int(c.y + r) + 1)):
		for x in range(maxi(0, int(c.x - r)), mini(MASK.x, int(c.x + r) + 1)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
			if d > 1.0:
				continue
			var fall := 1.0 if d < 0.55 else (1.0 - (d - 0.55) / 0.45)
			var v := _mask.get_pixel(x, y).r
			if v <= 0.0:
				continue
			var nv := maxf(0.0, v - rate * fall)
			_mask.set_pixel(x, y, Color(nv, 0, 0))
			taken += (v - nv) * _weight[y * MASK.x + x]
	if taken <= 0.0:
		return
	_mask_tex.update(_mask)
	_left = maxf(0.0, _left - taken / _total)
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


func _draw_view() -> void:
	var r := Rect2(_origin, PIC * _k)
	_view.draw_rect(r.grow(2 * _k), Color(0.05, 0.04, 0.03))
	if _bowl != null:
		_view.draw_texture_rect(_bowl, r, false)
	else:
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
	# How clean: a small enamel gauge in the corner of the picture.
	var clean := int(round((1.0 - _left) * 100.0))
	var font: Font = RETRO_UI.FONT_BIG
	var fs := RETRO_UI.SIZE_BIG * int(_k)
	var txt := "SPOTLESS" if _done_t >= 0.0 else "CLEAN %d%%" % clean
	var col := Color(0.6, 1.0, 0.65) if _done_t >= 0.0 else Color(0.95, 0.9, 0.7)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := (_origin + Vector2(PIC.x * _k - w - 8 * _k, PIC.y * _k + 14 * _k)).floor()
	if _done_t >= 0.0:
		at = (_origin + Vector2((PIC.x * _k - w) * 0.5, PIC.y * _k * 0.5)).floor()
		var band := Rect2(at - Vector2(10 * _k, fs * 0.9), Vector2(w + 20 * _k, fs * 1.3))
		c.draw_rect(band, Color(0.04, 0.16, 0.06, 0.86))
		c.draw_rect(band, Color(0.45, 0.95, 0.5), false, _k)
	c.draw_string(font, at + Vector2(_k, _k), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
	c.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var bar := Rect2(_origin + Vector2(8 * _k, PIC.y * _k + 8 * _k), Vector2(PIC.x * _k * 0.5, 6 * _k))
	c.draw_rect(bar, Color(0.1, 0.09, 0.08))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - _left), bar.size.y)), Color(0.55, 0.85, 0.95))
	c.draw_rect(bar, Color(0.6, 0.56, 0.48), false, maxf(1.0, _k * 0.5))
