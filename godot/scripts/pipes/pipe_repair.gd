extends Control

## The kinds of hole down there and the work each one takes (DESIGN §8). The clamp (hold E)
## stays in the crawl itself; these come up as a close-up over the pipe when you reach
## their hole, and every bit of them is noise the raccoon hears (pipe_director.heard):
##   bolts  a flange gone at its joint: four bolts, each turned three notches with the
##          ratchet. It swings by itself; press E (or click) when it is up at the bolt
##          (the bolt glints). Too early or late, it slips and bangs on the iron, loud.
##   valve  a stuck gate valve to shut: the wheel goes round only by heaving one way then
##          the other (A, D, A, D... or the two mouse buttons), and it creeps back when you
##          stop.
##   tar    a long crack to paint shut: hold E (or the mouse button) and drag the brush
##          along the crack (or A/D to work along it) till all of it is black.
##   clog   a side pipe jammed with hair, rags and fat: tear it out a handful at a time
##          (E or click, again and again). Now and then something on the other side of it
##          chitters and the dark in the middle moves: pull your hand back (S or the
##          right button) at once, or it bites.
## No words: a key cap where the key is wanted, nothing else.

signal done

const C := "res://assets/textury/closeup/"
const SFX := "res://assets/sfx/pipes/"
const GLINT := "res://assets/textury/ui/hover_glint.png"
const HAND := "res://assets/textury/hands/crawl_reach.png"
const CHUNKS := ["res://assets/textury/pipes/spr_hair.png", "res://assets/textury/pipes/rac/rac_hblood.png", "res://assets/textury/pipes/rac/rac_hpile.png"]
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const BG := {"bolts": "repair_flange.png", "valve": "repair_valve.png", "tar": "repair_crack.png", "clog": "repair_clog.png"}
## Where the work is on each close-up, as fractions of it.
const BOLTS := [Vector2(0.31, 0.27), Vector2(0.69, 0.27), Vector2(0.69, 0.73), Vector2(0.31, 0.73)]
const SPINDLE := Vector2(0.5, 0.45)
const CRACK_Y := 0.48
const CLOG_AT := Vector2(0.5, 0.5)
const TURNS := 3
const VALVE_TURNS := 26
const TAR_SEGMENTS := 14

var host
var kind := ""
var _rng := RandomNumberGenerator.new()
var _bg: TextureRect
var _tool: TextureRect
var _glint: TextureRect
var _wheel: TextureRect
var _key: Label
var _key2: Label
var _shade: ColorRect
var _stamps: Control
var _chunks: Array = []
var _t := 0.0
# bolts
var _bolt := 0
var _notch := 0
var _swing := 0.0
var _swing_speed := 1.4
# valve
var _turns := 0.0
var _last_side := 0
var _idle := 0.0
# tar
var _painted: Array = []
var _brush := Vector2(0.15, CRACK_Y)
var _painting := false
# clog
var _pulled := 0
var _need := 10
var _warn_t := -1.0
var _warn_next := 4.0
var _hand_in := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.55)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_bg = _rect()
	_stamps = Control.new()
	_stamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamps)
	_wheel = _rect()
	_glint = _rect()
	_tool = _rect()
	_key = _keycap()
	_key2 = _keycap()


func _rect() -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	add_child(r)
	return r


func _keycap() -> Label:
	var l := Label.new()
	l.visible = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func is_active() -> bool:
	return kind != ""


## The work for one hole starts (`k` one of BG's keys).
func begin(k: String, seed_value: int) -> void:
	kind = k
	_rng.seed = seed_value
	_t = 0.0
	visible = true
	for c in _stamps.get_children():
		c.queue_free()
	_clear_chunks()
	for r in [_tool, _glint, _wheel]:
		r.visible = false
		r.rotation = 0.0
	_key.visible = false
	_key2.visible = false
	var path: String = C + str(BG.get(k, ""))
	_bg.texture = load(path) if ResourceLoader.exists(path) else null
	_bg.visible = true
	match k:
		"bolts":
			_bolt = 0
			_notch = 0
			_swing = 0.0
			_swing_speed = 1.4 + 0.25 * float(host.raccoon_level - 1)
			_tool.texture = _tex("repair_ratchet.png")
			_glint.texture = load(GLINT) if ResourceLoader.exists(GLINT) else null
		"valve":
			_turns = 0.0
			_last_side = 0
			_idle = 0.0
			_wheel.texture = _tex("repair_wheel.png")
			_wheel.visible = true
		"tar":
			_painted.clear()
			for _i in TAR_SEGMENTS:
				_painted.append(false)
			_brush = Vector2(0.12, CRACK_Y)
			_tool.texture = _tex("repair_brush.png")
		"clog":
			_pulled = 0
			_need = 8 + 2 * int(host.raccoon_level)
			_warn_t = -1.0
			_warn_next = _rng.randf_range(2.5, 4.5)
			_hand_in = 0.0
			_tool.texture = load(HAND) if ResourceLoader.exists(HAND) else null
	_layout()


## Caught or gone up the ladder: the work is left (it starts again from nothing).
func cancel() -> void:
	kind = ""
	visible = false
	_clear_chunks()


func _tex(file: String) -> Texture2D:
	return load(C + file) if ResourceLoader.exists(C + file) else null


# ── layout ───────────────────────────────────────────────────────────────────

var _panel := Rect2()


func _layout() -> void:
	var vp := get_viewport_rect().size
	_shade.size = vp
	var tex := _bg.texture
	var aspect := float(tex.get_width()) / float(tex.get_height()) if tex != null else 4.0 / 3.0
	var h := vp.y * 0.78
	var w := h * aspect
	if w > vp.x * 0.92:
		w = vp.x * 0.92
		h = w / aspect
	_panel = Rect2((vp - Vector2(w, h)) * 0.5, Vector2(w, h))
	_bg.position = _panel.position
	_bg.size = _panel.size
	_stamps.position = Vector2.ZERO
	_stamps.size = vp
	var k := _scale()
	for l in [_key, _key2]:
		RETRO_UI.style_label(l, RETRO_UI.FONT_BIG, 10, RETRO_UI.C_AMBER_LIGHT, k, true)


func _scale() -> int:
	return maxi(1, int(round(get_viewport_rect().size.y / 240.0)))


func _at(f: Vector2) -> Vector2:
	return _panel.position + _panel.size * f


func _place(r: TextureRect, center: Vector2, height_frac: float) -> void:
	if r.texture == null:
		r.visible = false
		return
	var h := _panel.size.y * height_frac
	r.size = Vector2(h * float(r.texture.get_width()) / float(r.texture.get_height()), h)
	r.pivot_offset = r.size * 0.5
	r.position = (center - r.size * 0.5).floor()
	r.visible = true


func _cap(l: Label, text: String, at: Vector2) -> void:
	l.text = text
	l.visible = true
	l.reset_size()
	l.position = (at - l.size * 0.5).floor()


# ── input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if kind == "" or not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		return
	var press := false
	var side := 0
	var back := false
	var hold_change := 0
	var k := event as InputEventKey
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	if k != null and not k.echo:
		match k.physical_keycode:
			KEY_E, KEY_SPACE:
				if k.pressed:
					press = true
				hold_change = 1 if k.pressed else -1
			KEY_A, KEY_LEFT:
				side = -1 if k.pressed else 0
			KEY_D, KEY_RIGHT:
				side = 1 if k.pressed else 0
			KEY_S, KEY_DOWN:
				back = k.pressed
			_:
				return
	elif mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			press = mb.pressed
			hold_change = 1 if mb.pressed else -1
			if kind == "valve" and mb.pressed:
				side = -1
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			back = mb.pressed
			if kind == "valve" and mb.pressed:
				side = 1
		else:
			return
	elif mm != null:
		if kind == "tar":
			var f := (mm.position - _panel.position) / _panel.size
			_brush = Vector2(clampf(f.x, 0.0, 1.0), clampf(f.y, 0.0, 1.0))
		return
	else:
		return
	get_viewport().set_input_as_handled()
	match kind:
		"bolts":
			if press:
				_ratchet()
		"valve":
			if side != 0:
				_heave(side)
		"tar":
			if hold_change != 0:
				_painting = hold_change > 0
			if side != 0:
				_brush.x = clampf(_brush.x + 0.06 * float(side), 0.0, 1.0)
				_brush.y = CRACK_Y
		"clog":
			if back:
				_snatch_back()
			elif press:
				_tear()


# ── per frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if kind == "":
		return
	_t += delta
	_layout()
	_update_chunks(delta)
	match kind:
		"bolts":
			_update_bolts(delta)
		"valve":
			_update_valve(delta)
		"tar":
			_update_tar(delta)
		"clog":
			_update_clog(delta)


# ── bolts ────────────────────────────────────────────────────────────────────

## The ratchet's swing: up at the bolt (the window) once a cycle.
func _in_window() -> bool:
	return absf(fposmod(_swing, 1.0) - 0.5) < 0.09


func _update_bolts(delta: float) -> void:
	_swing += delta * _swing_speed
	var bolt: Vector2 = _at(BOLTS[_bolt])
	# The hand with the ratchet swings back and forth on the bolt, in steps.
	var ph := floorf(fposmod(_swing, 1.0) * 12.0) / 12.0
	_place(_tool, bolt + Vector2(_panel.size.y * 0.16, _panel.size.y * 0.18), 0.5)
	_tool.rotation = lerpf(-0.55, 0.35, sin(ph * PI))
	var lit := _in_window()
	_place(_glint, bolt, 0.16)
	_glint.visible = _glint.texture != null and lit
	_cap(_key, "E", bolt + Vector2(0, -_panel.size.y * 0.16))
	_key.modulate.a = 1.0 if lit else 0.45


func _ratchet() -> void:
	if _in_window():
		_notch += 1
		_sound("bolt.mp3", -2.0, _rng.randf_range(0.92, 1.08))
		_noise(1)
		if _notch >= TURNS:
			_notch = 0
			_bolt += 1
			if _bolt >= BOLTS.size():
				_finish()
				return
	else:
		# It slips off and bangs on the iron: loud, and the swing quickens.
		_sound("slip.mp3", 2.0, _rng.randf_range(0.9, 1.1))
		_noise(2)
		_swing_speed = minf(_swing_speed + 0.12, 3.0)
		host._bump_t = 0.0


# ── valve ────────────────────────────────────────────────────────────────────

func _update_valve(delta: float) -> void:
	_idle += delta
	if _idle > 1.2 and _turns > 0.0:
		# Let go and it creeps back.
		_turns = maxf(0.0, _turns - delta * 1.5)
	var c: Vector2 = _at(SPINDLE)
	_place(_wheel, c, 0.62)
	_wheel.rotation = floorf(_turns) * deg_to_rad(13.0)
	var want := -_last_side if _last_side != 0 else -1
	_cap(_key, "A" if want < 0 else "D", c + Vector2(-_panel.size.x * 0.36 if want < 0 else _panel.size.x * 0.36, 0))
	_key2.visible = false


func _heave(side: int) -> void:
	if side == _last_side:
		return
	_last_side = side
	_idle = 0.0
	_turns += 1.0
	_sound("valve.mp3", -4.0, _rng.randf_range(0.85, 1.12))
	_noise(1)
	host._bump_t = 0.0 if _rng.randf() < 0.25 else host._bump_t
	if _turns >= float(VALVE_TURNS):
		_finish()


# ── tar ──────────────────────────────────────────────────────────────────────

func _update_tar(delta: float) -> void:
	var tip := _at(_brush)
	_place(_tool, tip + Vector2(_panel.size.y * 0.13, _panel.size.y * 0.14), 0.42)
	_cap(_key, "E", tip + Vector2(0, -_panel.size.y * 0.12))
	_key.modulate.a = 0.4 if _painting else 1.0
	if not _painting:
		return
	# The brush covers the crack where it is near it.
	if absf(_brush.y - CRACK_Y) < 0.1:
		var i := clampi(int(_brush.x * float(TAR_SEGMENTS)), 0, TAR_SEGMENTS - 1)
		if not _painted[i]:
			_painted[i] = true
			_stamp(Vector2((float(i) + 0.5) / float(TAR_SEGMENTS), CRACK_Y + _rng.randf_range(-0.02, 0.02)))
			_sound("tar.mp3", -6.0, _rng.randf_range(0.9, 1.1))
			_noise(1)
	var left := _painted.count(false)
	if left == 0:
		_finish()


func _stamp(f: Vector2) -> void:
	var tex := _tex("repair_tar.png")
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := _panel.size.x / float(TAR_SEGMENTS) * 1.6
	r.size = Vector2(w, w * 0.6)
	r.position = (_at(f) - r.size * 0.5).floor()
	if tex == null:
		r.modulate = Color(0.02, 0.02, 0.02)
	_stamps.add_child(r)


# ── clog ─────────────────────────────────────────────────────────────────────

func _update_clog(delta: float) -> void:
	var c: Vector2 = _at(CLOG_AT)
	_hand_in = maxf(0.0, _hand_in - delta * 4.0)
	# The hand: deep in the clog after a tear, coming back out.
	_place(_tool, c + Vector2(_panel.size.y * (0.22 - 0.14 * _hand_in), _panel.size.y * (0.3 - 0.2 * _hand_in)), 0.55)
	_cap(_key, "E", c + Vector2(0, -_panel.size.y * 0.3))
	if _warn_t >= 0.0:
		_warn_t += delta
		_cap(_key2, "S", c + Vector2(0, _panel.size.y * 0.3))
		_key2.modulate = Color(1, 0.3, 0.25) if int(_t * 10.0) % 2 == 0 else Color(1, 1, 1)
		_shade.color = Color(0.25, 0.0, 0.0, 0.55)
		if _warn_t >= 0.7:
			# Too slow: it has your hand.
			_warn_t = -1.0
			_key2.visible = false
			_shade.color = Color(0, 0, 0, 0.55)
			host.bitten(12)
			_pulled = maxi(0, _pulled - 3)
		return
	_key2.visible = false
	_shade.color = Color(0, 0, 0, 0.55)
	_warn_next -= delta
	if _warn_next <= 0.0 and _pulled > 1:
		_warn_next = _rng.randf_range(3.0, 6.0) / (1.0 + 0.3 * float(host.raccoon_level - 1))
		_warn_t = 0.0
		_sound("rac_chitter.mp3", 2.0, _rng.randf_range(0.95, 1.1))


func _tear() -> void:
	if _warn_t >= 0.0:
		# Pulling while it is there: it has you.
		_warn_t = 0.7
		return
	_pulled += 1
	_hand_in = 1.0
	_sound("pullclog.mp3", -2.0, _rng.randf_range(0.9, 1.1))
	_noise(1)
	_chunk()
	if _pulled >= _need:
		_finish()


func _snatch_back() -> void:
	if _warn_t < 0.0:
		return
	_warn_t = -1.0
	_key2.visible = false
	_shade.color = Color(0, 0, 0, 0.55)
	_hand_in = 0.0
	_sound("rac_screech.mp3", -4.0, 1.2)


## A handful torn out: it comes at the view and drops away.
func _chunk() -> void:
	var path: String = CHUNKS[_rng.randi() % CHUNKS.size()]
	if not ResourceLoader.exists(path):
		return
	var r := TextureRect.new()
	r.texture = load(path)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _panel.size.y * 0.16
	r.size = Vector2(h * float(r.texture.get_width()) / float(r.texture.get_height()), h)
	r.pivot_offset = r.size * 0.5
	r.position = (_at(CLOG_AT) - r.size * 0.5).floor()
	add_child(r)
	_chunks.append({"node": r, "t": 0.0, "v": Vector2(_rng.randf_range(-1.0, 1.0), -0.6) * _panel.size.y, "spin": _rng.randf_range(-4.0, 4.0)})


func _update_chunks(delta: float) -> void:
	for i in range(_chunks.size() - 1, -1, -1):
		var c: Dictionary = _chunks[i]
		c["t"] = float(c["t"]) + delta
		var r: TextureRect = c["node"]
		c["v"] = (c["v"] as Vector2) + Vector2(0, _panel.size.y * 3.0) * delta
		r.position += (c["v"] as Vector2) * delta
		r.rotation += float(c["spin"]) * delta
		r.scale = Vector2.ONE * (1.0 + float(c["t"]) * 1.5)
		if float(c["t"]) > 0.9:
			r.queue_free()
			_chunks.remove_at(i)


func _clear_chunks() -> void:
	for c in _chunks:
		if is_instance_valid(c["node"]):
			(c["node"] as Node).queue_free()
	_chunks.clear()


# ── shared ───────────────────────────────────────────────────────────────────

func _finish() -> void:
	kind = ""
	visible = false
	_clear_chunks()
	done.emit()


func _noise(loud: int) -> void:
	if host._director != null:
		host._director.heard(host._node, loud)


func _sound(file: String, db: float, pitch: float) -> void:
	if not ResourceLoader.exists(SFX + file):
		return
	var p := AudioStreamPlayer.new()
	p.bus = host.audio_bus()
	p.stream = load(SFX + file)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
