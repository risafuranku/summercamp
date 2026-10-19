extends Control

## When the raccoon in the sewer gets you (DESIGN §8): a short staged sequence over the
## crawl's own view, in steps, twelve a second, like everything that moves on its own.
## It is meant to be the worst thing in the game. Five of them, picked by what was going
## on (stuck in its snare: the flood; looking back: the ankle; else a draw, never the same
## twice running):
##   rope   a rope of its guts shoots out of the dark, wraps your free hand, and drags you
##          down the pipe to it; it stands there with its belly open like a mouth; it eats
##   ankle  it has your ankle: dragged backwards, your hands clawing at the floor; it
##          stops; it climbs over you onto your face
##   face   the torch dies; the dark; one wet click; the torch comes back and its face is
##          right there; the jaw opens too far, further; it bites
##   flood  a wall of guts comes up the pipe at you, your hands sink, it closes over
##   hand   small black fingers take your free hand down out of sight; the torch drops;
##          in its light on the floor it is hunched over your glove, eating; it looks up
## The host (sewer_pipe_minigame.gd) gives it the camera, the hands and the splatter, takes
## the hit when it comes (`hit`) and puts you back at the ladder after (`finished`).

signal hit
signal finished

const SFX := "res://assets/sfx/pipes/"
const STEP := 1.0 / 12.0
const KINDS := ["rope", "ankle", "face", "flood", "hand"]
const TEX_BELLY := "res://assets/textury/pipes/rac/rac_7.png"
const TEX_FACE := "res://assets/textury/npc/rac_face.png"
const TEX_WAVE := "res://assets/textury/pipes/rac/rac_hpile.png"
const TEX_CRAWL := "res://assets/textury/pipes/rac/rac_0.png"
const TEX_STAND := "res://assets/textury/pipes/rac/rac_0.png"
const TEX_PEEK := "res://assets/textury/pipes/rac/rac_0.png"
const TEX_FALLBACK := "res://assets/textury/npc/pipe_thing_close.png"
const TEX_GLOVE := "res://assets/textury/hands/open.png"
const N := "res://assets/textury/npc/"
const BELLY := ["res://assets/textury/pipes/rac/rac_3.png", "res://assets/textury/pipes/rac/rac_5.png", "res://assets/textury/pipes/rac/rac_7.png"]
const FACE := [N + "rac_face_1.png", N + "rac_face_2.png", N + "rac_face.png"]
const EAT := ["res://assets/textury/pipes/rac/rac_attack.png", "res://assets/textury/pipes/rac/rac_spell.png"]
const TEX_CLIMB := N + "rac_climb.png"
const TEX_LUNGE := "res://assets/textury/pipes/rac/rac_attack.png"
const TEX_GUT_TIP := "res://assets/textury/pipes/rac/rac_arm.png"

var host
var kind := ""
var last_kind := ""
var _t := 0.0
var _st := 0.0                     # time stepped to 1/12 s
var _hit_done := false
var _marks := {}                   # one-shot cues already played
var _rig_from := Vector3.ZERO
var _rig_dir := Vector3.ZERO
var _rush := 0.0
var _hand_from := Vector2.ZERO

var _rope: Line2D
var _rope_edge: Line2D
var _folds: Control
var _big: TextureRect              # the belly, the face, the wave, the thing eating
var _glove: TextureRect
var _tip: TextureRect              # the end of the rope: its little fingers
var _red: ColorRect
var _black: ColorRect
var _rng := RandomNumberGenerator.new()
var _sounds: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_rope_edge = Line2D.new()
	_rope_edge.default_color = Color(0.16, 0.03, 0.04)
	_rope_edge.joint_mode = Line2D.LINE_JOINT_ROUND
	_rope_edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rope_edge.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_rope_edge)
	_rope = Line2D.new()
	_rope.default_color = Color(0.62, 0.42, 0.42)
	_rope.joint_mode = Line2D.LINE_JOINT_ROUND
	_rope.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rope.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.set_color(0, Color(0.46, 0.22, 0.24))
	grad.set_color(1, Color(0.70, 0.50, 0.48))
	_rope.gradient = grad
	add_child(_rope)
	_folds = Control.new()
	_folds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folds.set_anchors_preset(Control.PRESET_FULL_RECT)
	_folds.draw.connect(_draw_folds)
	add_child(_folds)
	_tip = TextureRect.new()
	_tip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tip.stretch_mode = TextureRect.STRETCH_SCALE
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	_big = TextureRect.new()
	_big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_big.stretch_mode = TextureRect.STRETCH_SCALE
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_big)
	_glove = TextureRect.new()
	_glove.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glove.stretch_mode = TextureRect.STRETCH_SCALE
	_glove.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glove)
	_red = ColorRect.new()
	_red.color = Color(0.45, 0.0, 0.0, 0.0)
	_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_red)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)


func is_playing() -> bool:
	return kind != ""


## Picks the catch for what was going on and starts it.
func play_for(stuck: bool, looking_back: bool) -> void:
	var k := ""
	if stuck:
		k = "flood"
	elif looking_back:
		k = "ankle"
	else:
		var pool: Array = ["rope", "face", "hand", "rope", "ankle", "flood"].filter(func(x): return x != last_kind)
		k = pool[_rng.randi() % pool.size()]
	play(k)


func play(k: String) -> void:
	_rng.randomize()
	kind = k
	last_kind = k
	_t = 0.0
	_st = 0.0
	_hit_done = false
	_marks.clear()
	_rush = 0.0
	visible = true
	_rope.visible = false
	_rope_edge.visible = false
	_folds.queue_redraw()
	_tip.visible = false
	_big.visible = false
	_glove.visible = false
	_red.color.a = 0.0
	_black.color.a = 0.0
	_big.rotation = 0.0
	_big.modulate = Color.WHITE
	_rig_from = host._rig.position
	var yaw: float = host._rig.rotation.y
	_rig_dir = Vector3(-sin(yaw), 0, -cos(yaw))
	_hand_from = host._crawl_hand.position
	_sz()


func _sz() -> void:
	var vp := get_viewport_rect().size
	_red.size = vp
	_black.size = vp
	_rope.width = vp.y * 0.10
	_rope_edge.width = vp.y * 0.125


func _process(delta: float) -> void:
	if kind == "":
		return
	_sz()
	_t += delta
	var prev := _st
	_st = floorf(_t / STEP) * STEP
	var stepped := _st != prev
	match kind:
		"rope":
			_rope_seq(stepped)
		"ankle":
			_ankle_seq(stepped)
		"face":
			_face_seq(stepped)
		"flood":
			_flood_seq(stepped)
		"hand":
			_hand_seq(stepped)
	_red.color.a = maxf(0.0, _red.color.a - delta * 3.0)


func _end_at(t: float) -> void:
	if _t >= t:
		for p in _sounds:
			if is_instance_valid(p):
				p.queue_free()
		_sounds.clear()
		kind = ""
		visible = false
		finished.emit()


## A cue once: true the first time `t` is passed.
func _at(t: float, id: String) -> bool:
	if _t >= t and not _marks.has(id):
		_marks[id] = true
		return true
	return false


func _snd(file: String, db: float, pitch: float = 1.0) -> AudioStreamPlayer:
	if not ResourceLoader.exists(SFX + file):
		return null
	var p := AudioStreamPlayer.new()
	p.bus = host.audio_bus()
	p.stream = load(SFX + file)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	_sounds.append(p)
	return p


func _tex(path: String, fallback: String = TEX_FALLBACK) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return load(TEX_FALLBACK) if ResourceLoader.exists(TEX_FALLBACK) else null


## Frame `i` of a sequence (clamped), or the nearest earlier one that exists, or `fallback`.
func _frame(paths: Array, i: int, fallback: String = TEX_FALLBACK) -> Texture2D:
	for j in range(clampi(i, 0, paths.size() - 1), -1, -1):
		if ResourceLoader.exists(paths[j]):
			return load(paths[j])
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	return _tex(fallback)


## Puts a picture centred at `c` (fraction of the screen), `h` of the screen's height tall.
func _show_big(tex: Texture2D, c: Vector2, h: float, stretch_y: float = 1.0) -> void:
	if tex == null:
		return
	var vp := get_viewport_rect().size
	_big.texture = tex
	_big.visible = true
	var hh := vp.y * h
	var ww := hh * float(tex.get_width()) / float(tex.get_height())
	_big.size = Vector2(ww, hh * stretch_y)
	_big.pivot_offset = _big.size * 0.5
	_big.position = (vp * c - _big.size * 0.5).floor()


func _shake(amount: float) -> void:
	host._camera.position = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0) * amount


## Down the pipe you face (or back up it): as far as it runs straight, at most `cells`.
func _rush_to(k: float, cells: float, back: bool) -> void:
	var dir := -_rig_dir if back else _rig_dir
	host._rig.position = _rig_from + dir * host.CELL * cells * k


func _bite(eat_db: float = 0.0) -> void:
	_red.color.a = 0.85
	_snd("rac_crunch.mp3", eat_db, _rng.randf_range(0.85, 1.1))
	host.splatter(2)
	if not _hit_done:
		_hit_done = true
		hit.emit()


func _eat_jerk(stepped: bool, amount: float) -> void:
	if stepped:
		_shake(amount)
		if _rng.randf() < 0.35:
			host.splatter(1)
		if _rng.randf() < 0.3:
			_red.color.a = maxf(_red.color.a, 0.5)


# ── rope: its guts come for you ───────────────────────────────────────────────

func _rope_seq(stepped: bool) -> void:
	var vp := get_viewport_rect().size
	var centre := vp * Vector2(0.5, 0.47)
	if _at(0.0, "giggle"):
		_snd("rac_giggle.mp3", -6.0)
		host._director.flicker = 0.8
	if _t >= 0.55 and _t < 1.35:
		if _at(0.55, "whip"):
			_snd("gut_whip.mp3", 2.0)
		# It shoots out of the dark to your hand and wraps it.
		var k := clampf((_st - 0.55) / 0.3, 0.0, 1.0)
		var target: Vector2 = host._crawl_hand.position + host._crawl_hand.size * Vector2(0.45, 0.4)
		if _t >= 0.85:
			host._crawl_hand.visible = true
			var pull := clampf((_st - 0.85) / 0.5, 0.0, 1.0)
			host._crawl_hand.position = _hand_from.lerp(centre - host._crawl_hand.size * 0.5, pull * pull)
			host._crawl_hand.scale = Vector2.ONE * lerpf(1.0, 0.4, pull)
			target = host._crawl_hand.position + host._crawl_hand.size * host._crawl_hand.scale * 0.45
		_draw_rope(centre, centre.lerp(target, k), 1.0)
	if _t >= 1.35 and _t < 2.7:
		# Dragged down the pipe to it, in jerks, torch flailing.
		if _at(1.35, "drag"):
			_snd("drag_fast.mp3", 3.0)
			_snd("man_choke.mp3", -2.0)
		var k2 := clampf((_st - 1.35) / 1.3, 0.0, 1.0)
		_rush_to(k2, 1.6, false)
		_draw_rope(centre, centre + Vector2(0, vp.y * 0.18), 0.6)
		host._crawl_hand.visible = false
		if stepped:
			_shake(0.05)
			host._camera.rotation.z = _rng.randf_range(-0.25, 0.25)
			if _rng.randf() < 0.4:
				host.splatter(1)
			host._director.flicker = _rng.randf()
	if _t >= 2.7:
		_rope.visible = false
		_rope_edge.visible = false
		_tip.visible = false
		_folds.queue_redraw()
		host._camera.rotation.z = 0.0
		# It stands there, belly open like a mouth, and the mouth opens wider.
		var open := clampf((_st - 2.7) / 0.9, 0.0, 1.0)
		var near := clampf((_st - 3.6) / 0.8, 0.0, 1.0)
		_show_big(_frame(BELLY, int(open * 3.0), TEX_STAND), Vector2(0.5, 0.5 + 0.05 * near), lerpf(0.75, 1.9, near * near), lerpf(1.0, 1.15, open))
		if _at(2.7, "eat"):
			_snd("rac_eat.mp3", 2.0)
		if _at(3.6, "bite1"):
			_bite()
		if _at(4.0, "bite2"):
			_bite(-2.0)
		if _t >= 3.6:
			_eat_jerk(stepped, 0.06)
		_black.color.a = clampf((_t - 4.6) / 0.4, 0.0, 1.0)
	_end_at(5.6)


func _draw_rope(from: Vector2, to: Vector2, wiggle: float) -> void:
	# Its arm of guts (the original art): the shoulder in the dark of the pipe, the clawed
	# hand at your hand, stretched between them, writhing a little.
	_rope.visible = false
	_rope_edge.visible = false
	_folds.queue_redraw()
	if not ResourceLoader.exists(TEX_GUT_TIP):
		return
	var tex: Texture2D = load(TEX_GUT_TIP)
	var d := maxf(8.0, (to - from).length())
	var h := maxf(get_viewport_rect().size.y * 0.08, d * float(tex.get_height()) / float(tex.get_width()))
	_tip.texture = tex
	_tip.visible = true
	_tip.size = Vector2(d, h)
	_tip.pivot_offset = Vector2(d, h * 0.5)
	_tip.position = (from - _tip.pivot_offset).floor()
	_tip.rotation = (to - from).angle() + PI + sin(_st * 22.0) * 0.035 * wiggle


## The rope's folds: dark creases across it every so often, so it reads as gut, not hose.
func _draw_folds() -> void:
	if not _rope.visible or _rope.points.size() < 2:
		return
	var pts := _rope.points
	var crease := Color(0.22, 0.05, 0.06)
	var hi := Color(0.86, 0.70, 0.66)
	for i in range(1, pts.size() - 1):
		var dir := (pts[i + 1] - pts[i - 1]).normalized()
		var n := dir.orthogonal() * _rope.width * 0.42
		_folds.draw_line(pts[i] - n, pts[i] + n, crease, maxf(2.0, _rope.width * 0.08))
		_folds.draw_line(pts[i] - n * 0.7 + dir * _rope.width * 0.2, pts[i] - n * 0.2 + dir * _rope.width * 0.22, hi, maxf(1.0, _rope.width * 0.05))


# ── ankle: dragged back, it climbs onto you ─────────────────────────────────────

func _ankle_seq(stepped: bool) -> void:
	var vp := get_viewport_rect().size
	if _at(0.0, "grab"):
		_snd("grab.mp3", 2.0)
		_snd("drag_fast.mp3", 3.0)
		host.glancing = false
	if _t < 2.2:
		var k := clampf(_st / 2.1, 0.0, 1.0)
		_rush_to(k, 1.4, true)
		host._camera.rotation.x = lerpf(0.0, -0.55, minf(1.0, _st * 3.0))
		# Your hands clawing at the floor as it goes away from you.
		host._crawl_hand.visible = true
		var claw := fmod(_st * 3.0, 1.0)
		host._crawl_hand.position = Vector2(vp.x * 0.3, vp.y * (0.25 + 0.7 * claw)).floor()
		host._torch_hand.position.y = vp.y * (0.45 + 0.3 * fmod(_st * 3.0 + 0.5, 1.0))
		if stepped:
			_shake(0.04)
			if _rng.randf() < 0.3:
				host.splatter(1)
		if _at(0.7, "choke"):
			_snd("man_choke.mp3", -3.0)
	if _t >= 2.2 and _t < 2.8:
		host._crawl_hand.visible = false
		if _at(2.2, "still"):
			_snd("rac_giggle.mp3", -2.0)
	if _t >= 2.8:
		# Down onto your face from above, upside down.
		var k2 := clampf((_st - 2.8) / 0.5, 0.0, 1.0)
		if ResourceLoader.exists(TEX_CLIMB) and _t < 3.3:
			_show_big(load(TEX_CLIMB), Vector2(0.5, lerpf(-0.45, 0.35, k2)), 1.4)
		else:
			_show_big(_frame(FACE, 2 if _t >= 3.3 else 0, TEX_PEEK), Vector2(0.5, lerpf(-0.4, 0.42, k2)), 1.5)
			_big.rotation = 0.0 if ResourceLoader.exists(TEX_CLIMB) else PI
		if _at(2.8, "screech"):
			_snd("rac_screech.mp3", 3.0)
		if _at(3.3, "bite"):
			_bite()
			_snd("rac_eat.mp3", 2.0)
		if _t >= 3.3:
			_eat_jerk(stepped, 0.07)
		_black.color.a = clampf((_t - 4.4) / 0.4, 0.0, 1.0)
	_end_at(5.3)


# ── face: in the dark, right in front of you ─────────────────────────────────────

func _face_seq(stepped: bool) -> void:
	if _at(0.0, "dark"):
		host._flashlight.visible = false
		_snd("hiss.mp3", -12.0)
	if _t < 1.7:
		host._director.flicker = 0.0
		_black.color.a = 0.75
		if _at(1.1, "click"):
			_snd("rac_chitter.mp3", -14.0, 0.8)
	if _t >= 1.7:
		if _at(1.7, "on"):
			host._flashlight.visible = true
			_black.color.a = 0.0
			_snd("rac_screech.mp3", 4.0)
		# The jaw: too far, and further, in steps.
		var open := clampf((_st - 1.7) / 0.9, 0.0, 1.0)
		var lunge := clampf((_st - 2.6) / 0.25, 0.0, 1.0)
		var jaw := 0 if open < 0.3 else (1 if open < 0.75 else 2)
		_show_big(_frame(FACE, jaw, TEX_PEEK), Vector2(0.5, 0.5), lerpf(0.72, 2.6, lunge), lerpf(1.0, 1.25, open))
		if _at(2.85, "bite"):
			_bite(3.0)
			_snd("rac_eat.mp3", 2.0)
		if _t >= 2.85:
			_eat_jerk(stepped, 0.08)
		_black.color.a = clampf((_t - 3.7) / 0.4, 0.0, 1.0)
	_end_at(4.6)


# ── flood: a wall of it up the pipe ─────────────────────────────────────────────

func _flood_seq(stepped: bool) -> void:
	if _at(0.0, "flood"):
		_snd("gut_flood.mp3", 4.0)
	var k := clampf(_st / 2.0, 0.0, 1.0)
	_show_big(_tex(TEX_WAVE, TEX_FALLBACK), Vector2(0.5, 0.52), lerpf(0.05, 2.4, k * k))
	_big.modulate = Color(1, 1, 1, 1)
	# Your hands going under.
	host._crawl_hand.visible = true
	host._crawl_hand.position.y = _hand_from.y + host._crawl_hand.size.y * 0.8 * k
	host._crawl_hand.self_modulate = Color(1.0, 0.4, 0.4)
	if stepped and _t > 0.8:
		_shake(0.03 + 0.05 * k)
	if _at(1.6, "choke"):
		_snd("man_choke.mp3", -6.0, 0.9)
	if _at(2.1, "under"):
		_bite(-6.0)
		_snd("rac_eat.mp3", -4.0)
		host.splatter(4)
	if _t >= 2.1:
		_eat_jerk(stepped, 0.03)
	_black.color.a = clampf((_t - 2.6) / 0.6, 0.0, 1.0)
	_end_at(4.0)


# ── hand: it takes the hand, then the rest ──────────────────────────────────────

func _hand_seq(stepped: bool) -> void:
	var vp := get_viewport_rect().size
	if _t < 0.6:
		host._crawl_hand.visible = true
		var k := clampf(_st / 0.5, 0.0, 1.0)
		host._crawl_hand.position.y = _hand_from.y + vp.y * 0.7 * k * k
		if _at(0.05, "snatch"):
			_snd("rac_bite.mp3", 3.0)
			host.splatter(2)
			_red.color.a = 0.6
	if _t >= 0.6 and _t < 2.6:
		host._crawl_hand.visible = false
		# The torch drops and lies pointing along the floor; in its light, it eats.
		host._torch_hand.position.y = vp.y * 1.2
		host._camera.rotation = Vector3(-0.5, 0.35, 0.3)
		if _at(0.6, "drop"):
			_snd("bump.mp3", -2.0, 1.4)
			_snd("rac_eat.mp3", 1.0)
		var eat_i := int(_st * 4.0) % 2
		if ResourceLoader.exists(EAT[0]):
			_show_big(_frame(EAT, eat_i), Vector2(0.46, 0.7), 0.42)
			_glove.visible = false
		else:
			_show_big(_tex(TEX_CRAWL, TEX_FALLBACK), Vector2(0.42, 0.66), 0.45)
			_big.scale.x = -1.0 if eat_i == 0 else 1.0
			_glove.visible = true
		if stepped and eat_i == 1 and _rng.randf() < 0.3:
			_snd("rac_crunch.mp3", -8.0, _rng.randf_range(0.9, 1.2))
	if _t >= 0.6 and _t < 2.6 and not ResourceLoader.exists(EAT[0]):
		_glove.texture = _tex(TEX_GLOVE)
		if _glove.texture != null:
			_glove.size = _glove.texture.get_size() * maxf(1.0, floorf(vp.y / 360.0))
			_glove.position = Vector2(vp.x * 0.52, vp.y * 0.7).floor()
			_glove.self_modulate = Color(0.75, 0.25, 0.22)
			_glove.rotation = 1.2 + sin(_st * 30.0) * 0.08
		if stepped and _rng.randf() < 0.25:
			_shake(0.01)
	if _t >= 2.6:
		_glove.visible = false
		_big.scale.x = 1.0
		# It looks up from the glove. Then it is on you.
		var k3 := clampf((_st - 2.9) / 0.25, 0.0, 1.0)
		var tex3: Texture2D = _frame(FACE, 0, TEX_PEEK)
		if k3 > 0.0 and ResourceLoader.exists(TEX_LUNGE):
			tex3 = load(TEX_LUNGE)
		_show_big(tex3, Vector2(0.45, lerpf(0.62, 0.5, k3)), lerpf(0.4, 2.4, k3 * k3))
		if _at(2.6, "look"):
			_snd("rac_giggle.mp3", 0.0)
		if _at(3.15, "bite"):
			_bite(3.0)
		if _t >= 3.15:
			_eat_jerk(stepped, 0.07)
		_black.color.a = clampf((_t - 3.9) / 0.4, 0.0, 1.0)
	_end_at(4.8)
