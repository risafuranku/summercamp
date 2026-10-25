extends CanvasLayer

## Being hurt, seen, heard and felt (the user, 21. 10.: "polishnout efekty když hráč
## dostává damage. krev, vizuál, zvuky, efekty když má málo HP"). main.gd makes it and
## tells it every hit (hit()); the health it reads itself every frame.
## No voice: no cries, no groaning ("moc uhekaný"); morbid instead ("víc morbidní brutální
## unhinged NSFW", both the user, 21. 10.).
##   a hit       the view's palette into red for a few steps (materials/hurt_screen.gdshader),
##               blood on the lens (Grok splats in the game's pixels and palette, running
##               down in steps and drying off), on a hard one gore: flesh, hair and bone
##               splinters on it; the blow, flesh tearing, a bone going; on a hard one the
##               frame stops and for two frames you see your own arm ripped open, and the
##               ring in the ears.
##   low health  below ~45 % the colour drains to rust, the edges close in dark red and
##               pulse with your heart, which you hear, louder and quicker the worse it
##               is; burst veins creep in from the edges with each beat; you limp and the
##               view sways (player_controller.hurt). Worse, blood runs down over your eyes
##               from your head, your boots squelch, you leave a trail of it behind you,
##               and the flies find you: on the lens, crawling, buzzing at your ears.
##               Under ~20 % now and then you black out, the world muffled, and in the
##               dark for a few frames your own face torn, in a puddle.
## All of it goes in the morning with the wounds (main heals at dawn).

const NIGHTMARE_FX = preload("res://scripts/night/nightmare_fx.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const SCREEN_SHADER = preload("res://materials/hurt_screen.gdshader")
const D := "res://assets/sfx/player/hurt/"
const U := "res://assets/textury/ui/"
const SPLATS := [U + "blood_lens_a.png", U + "blood_lens_b.png", U + "blood_lens_c.png"]
const GORE := [U + "gore_lens_a.png"]
const VEINS := U + "hurt_veins.png"
const STREAMS := U + "hurt_streams.png"
const FLY := U + "hurt_fly.png"
const WOUND := U + "hurt_wound.png"
## How fast the hit's red goes (per second), light .. lethal: a hard one stays longer.
const FLASH_FALL := [2.0, 1.7, 1.3, 1.0, 0.8]
const HALLU := U + "hurt_hallu.png"
const FPS := 12.0
## Health (0..1) where it starts to tell, and where it is at its worst.
const HURT_FROM := 0.45
const HURT_FULL := 0.1
## By the hit's tier (small .. lethal): the flash, how many splats, how big (of the
## screen's height), how long they stay (s).
const FLASH := [0.45, 0.6, 0.8, 1.0, 1.0]
const SPLAT_N := [1, 1, 2, 3, 4]
const SPLAT_SIZE := [Vector2(0.22, 0.32), Vector2(0.28, 0.4), Vector2(0.34, 0.5), Vector2(0.4, 0.6), Vector2(0.5, 0.7)]
const SPLAT_LIFE := [2.5, 3.5, 4.5, 6.0, 8.0]

var main: Node
var _screen: ColorRect
var _mat: ShaderMaterial
var _splat_root: Control
var _splats: Array = []   # {node, life, age, drip}
var _tex: Array = []
var _flash := 0.0
var _flash_fall := 1.6
var _hurt := 0.0
var _beat_t := 0.0
var _pulse := 0.0
var _dark := 0.0
var _dark_next := 8.0
var _dark_t := -1.0
var _acc := 0.0
var _heart: AudioStreamPlayer
var _flies_snd: AudioStreamPlayer
var _squelch: AudioStreamPlayer
var _gore: Array = []
var _veins: TextureRect
var _streams_clip: Control
var _streams: TextureRect
var _stream_t := 0.0
## The run-down blood's strength: 1 while you are hurt, falling to 0 once healed.
var _stream_fade := 0.0
const STREAM_FADE_SEC := 2.5
var _flies: Array = []    # {node, vel, wait}
var _fly_tex: Texture2D
var _wound_tex: Texture2D
var _hallu_tex: Texture2D
var _trail_t := 0.0
var _one: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Over the PC's crisp screen too (building_interior's _crt_sharp_layer, 64): the blood is
	# on your eyes, not behind the monitor's glass (playtest 25. 10.).
	layer = 65
	name = "HurtFx"
	_rng.randomize()
	_screen = ColorRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SCREEN_SHADER
	_screen.material = _mat
	_screen.visible = false
	add_child(_screen)
	# Burst veins from the edges, and the blood running down from your head: under the
	# splats, in the game's pixels.
	_veins = _overlay(VEINS)
	_streams_clip = Control.new()
	_streams_clip.clip_contents = true
	_streams_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_streams_clip)
	_streams = _overlay(STREAMS, _streams_clip)
	_splat_root = Control.new()
	_splat_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splat_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_splat_root)
	for path in SPLATS:
		if ResourceLoader.exists(path):
			_tex.append(load(path))
	for path in GORE:
		if ResourceLoader.exists(path):
			_gore.append(load(path))
	_fly_tex = load(FLY) if ResourceLoader.exists(FLY) else null
	_wound_tex = load(WOUND) if ResourceLoader.exists(WOUND) else null
	_hallu_tex = load(HALLU) if ResourceLoader.exists(HALLU) else null
	_heart = _loop(D + "heart.mp3")
	_flies_snd = _loop(D + "flies.mp3")
	_squelch = _loop(D + "squelch.mp3")
	_one = AudioStreamPlayer.new()
	add_child(_one)


func _overlay(path: String, parent: Node = null) -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.texture = load(path) if ResourceLoader.exists(path) else null
	t.material = NIGHTMARE_FX.retro_material()
	t.visible = false
	(parent if parent != null else self).add_child(t)
	return t


func _loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path) if ResourceLoader.exists(path) else null
	if p.stream is AudioStreamMP3:
		(p.stream as AudioStreamMP3).loop = true
	p.volume_db = -60.0
	add_child(p)
	return p


## A hit of `amount` (its tier as main's DAMAGE_TIER_*), fatal or not.
func hit(amount: int, tier: int, fatal: bool) -> void:
	tier = clampi(tier, 0, 4)
	_flash = maxf(_flash, float(FLASH[tier]))
	_flash_fall = float(FLASH_FALL[tier])
	for i in int(SPLAT_N[tier]):
		_add_splat(tier)
	_play(D + "hit_%d.mp3" % _rng.randi_range(1, 3), -2.0 + float(tier), _rng.randf_range(0.92, 1.05))
	# The meat of it: flesh tearing, and on a hard one a bone and the gore hitting the lens.
	if tier >= 1:
		_play(D + "rip_%d.mp3" % _rng.randi_range(1, 2), -4.0 + float(tier), _rng.randf_range(0.9, 1.05))
	if tier >= 2:
		_play(D + "bone.mp3", -3.0 + float(tier), _rng.randf_range(0.85, 1.05))
		_play(D + "splat.mp3", -2.0, _rng.randf_range(0.9, 1.1))
	var fx = NIGHTMARE_FX.get_for(self)
	if tier >= 2 and fx != null:
		fx.freeze(0.08)
		fx.glitch(0.7, 0.35)
		# Your own arm, ripped open, for two frames.
		if _wound_tex != null and _rng.randf() < 0.75:
			fx.subliminal(_wound_tex, 2, 1.1)
		if not fatal:
			fx.tinnitus(1.2 + 0.6 * float(tier))
	if amount >= 10:
		_play_at(D + "drip.mp3", -10.0)


func _add_splat(tier: int) -> void:
	if _tex.is_empty():
		return
	var vs := get_viewport().get_visible_rect().size
	var t := TextureRect.new()
	t.texture = _tex[_rng.randi() % _tex.size()]
	# A hard hit: gore, not just blood.
	if tier >= 2 and not _gore.is_empty() and _rng.randf() < 0.75:
		t.texture = _gore[_rng.randi() % _gore.size()]
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.material = NIGHTMARE_FX.retro_material()
	var sz: Vector2 = SPLAT_SIZE[tier]
	var side := vs.y * _rng.randf_range(sz.x, sz.y)
	t.size = Vector2(side, side)
	t.pivot_offset = t.size * 0.5
	t.rotation = _rng.randf_range(-0.5, 0.5)
	t.flip_h = _rng.randf() < 0.5
	# Mostly towards the edges: the middle of the view stays yours.
	var edge := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 0.6))
	if edge.length() < 0.55:
		edge = edge.normalized() * _rng.randf_range(0.55, 0.95)
	t.position = vs * 0.5 + edge * vs * 0.5 - t.size * 0.5
	_splat_root.add_child(t)
	_splats.append({"node": t, "life": float(SPLAT_LIFE[tier]) * _rng.randf_range(0.8, 1.2), "age": 0.0, "drip": _rng.randf_range(4.0, 12.0)})


func _process(delta: float) -> void:
	if main == null or not is_instance_valid(main):
		return
	var playing: bool = bool(main.get("_gameplay_started")) and not bool(main.get("_menu_mode"))
	var hp := float(main.get("_player_health")) / 100.0 if playing else 1.0
	var want := clampf((HURT_FROM - hp) / (HURT_FROM - HURT_FULL), 0.0, 1.0) if hp > 0.0 else 1.0
	_hurt = move_toward(_hurt, want, delta * 0.8)
	var player = main.get("_player")
	if player != null and is_instance_valid(player) and player.get("hurt") != null:
		player.set("hurt", _hurt)
	# The heart: a lub-dub, quicker the worse it is.
	if _hurt > 0.0:
		_beat_t += delta / lerpf(1.05, 0.5, _hurt)
		var ph := fmod(_beat_t, 1.0)
		_pulse = maxf(1.0 - absf(ph - 0.05) / 0.07, 0.0) + 0.6 * maxf(1.0 - absf(ph - 0.22) / 0.07, 0.0)
	else:
		_pulse = 0.0
	_tick_sound(delta)
	_tick_blackout(delta)
	_tick_trail(delta, player)
	# In steps, as everything that moves on its own.
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var step := _acc
	_acc = 0.0
	_flash = maxf(0.0, _flash - step * _flash_fall)
	_tick_splats(step)
	_tick_veins()
	_tick_streams(step)
	_tick_flies(step)
	_screen.visible = _flash > 0.01 or _hurt > 0.01 or _dark > 0.01
	if _screen.visible:
		_mat.set_shader_parameter("flash", _flash)
		_mat.set_shader_parameter("hurt", _hurt)
		_mat.set_shader_parameter("pulse", clampf(_pulse, 0.0, 1.0))
		_mat.set_shader_parameter("dark", _dark)
		_mat.set_shader_parameter("px_size", float(RETRO_RENDER.internal_scale(get_viewport().get_visible_rect().size.y)))
		NIGHTMARE_FX.update_retro(get_viewport().get_visible_rect().size.y)
	# Low: a drop of blood stays at the edge of the view.
	if _hurt > 0.55 and _splats.size() < 1:
		_add_splat(0)


func _tick_splats(step: float) -> void:
	for s in _splats:
		s["age"] = float(s["age"]) + step
		var t: TextureRect = s["node"]
		# Running down, a pixel or two at a time, slower as it dries.
		var k := 1.0 - clampf(float(s["age"]) / float(s["life"]), 0.0, 1.0)
		t.position.y += float(s["drip"]) * step * k
		# Drying off in Build's see-through steps.
		var a := 1.0 if k > 0.5 else (0.66 if k > 0.25 else (0.33 if k > 0.0 else 0.0))
		if _hurt > 0.55 and s == _splats.front():
			a = maxf(a, 0.66)
			s["age"] = minf(float(s["age"]), float(s["life"]) * 0.6)
		t.modulate.a = a
	for s in _splats.duplicate():
		if (s["node"] as Control).modulate.a <= 0.0:
			(s["node"] as Node).queue_free()
			_splats.erase(s)


## Burst veins from the edges, more of them the worse it is, swelling with each beat (in
## Build's see-through steps).
func _tick_veins() -> void:
	if _veins.texture == null:
		return
	var a := (_hurt - 0.15) / 0.85 * (0.75 + 0.25 * clampf(_pulse, 0.0, 1.0))
	a = floorf(clampf(a, 0.0, 1.0) * 3.0 + 0.5) / 3.0
	_veins.visible = a > 0.0
	_veins.modulate.a = a


## Blood running down over your eyes from your head: it runs from the top in steps once,
## and there it stays, run down, till you are healed; then it fades off (it ran, dried off
## and ran again on a loop: playtest 25. 10.).
func _tick_streams(step: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	if _streams.texture == null:
		_streams.visible = false
		return
	if _hurt >= 0.4:
		if _stream_fade <= 0.0:
			# A fresh run.
			_stream_t = 0.0
			_streams.flip_h = _rng.randf() < 0.5
		_stream_fade = 1.0
		_stream_t += step
	elif _stream_fade > 0.0:
		_stream_fade = maxf(0.0, _stream_fade - step / STREAM_FADE_SEC)
	if _stream_fade <= 0.0:
		_streams.visible = false
		return
	var run_sec := lerpf(6.0, 3.5, clampf((_hurt - 0.4) / 0.6, 0.0, 1.0))
	var run := clampf(_stream_t / run_sec, 0.0, 1.0)
	_streams_clip.position = Vector2.ZERO
	_streams_clip.size = Vector2(vs.x, vs.y * floorf(run * 12.0) / 12.0)
	_streams.size = vs
	_streams.visible = true
	# Fading in steps, as the rest of it moves.
	_streams.modulate.a = ceilf(_stream_fade * 4.0) / 4.0


## The flies: on the lens when it is bad, crawling in jerks, stopping, flying off.
func _tick_flies(step: float) -> void:
	var want := 0 if _hurt < 0.6 or _fly_tex == null else (1 if _hurt < 0.8 else 3)
	var vs := get_viewport().get_visible_rect().size
	while _flies.size() < want:
		var f := TextureRect.new()
		f.texture = _fly_tex
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_SCALE
		f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		f.material = NIGHTMARE_FX.retro_material()
		var side := vs.y * _rng.randf_range(0.05, 0.08)
		f.size = Vector2(side, side)
		f.pivot_offset = f.size * 0.5
		var edge := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() * _rng.randf_range(0.6, 0.9)
		f.position = vs * 0.5 + edge * vs * 0.5 - f.size * 0.5
		_splat_root.add_child(f)
		_flies.append({"node": f, "vel": Vector2.ZERO, "wait": _rng.randf_range(0.2, 1.0)})
	while _flies.size() > want:
		(_flies.pop_back()["node"] as Node).queue_free()
	for fl in _flies:
		var n: TextureRect = fl["node"]
		fl["wait"] = float(fl["wait"]) - step
		if float(fl["wait"]) <= 0.0:
			# A few jerky steps somewhere, then still, rubbing its legs.
			fl["wait"] = _rng.randf_range(0.3, 1.6)
			fl["vel"] = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() * vs.y * _rng.randf_range(0.0, 0.25)
			n.rotation = (fl["vel"] as Vector2).angle() + PI * 0.5 if (fl["vel"] as Vector2).length() > 1.0 else n.rotation
		var v: Vector2 = fl["vel"]
		n.position += v * step
		fl["vel"] = v * 0.6
		n.position = n.position.clamp(Vector2.ZERO, vs - n.size)


## Low: drops of your blood behind you as you go (blood_fx, the world's own drops).
func _tick_trail(delta: float, player) -> void:
	if _hurt < 0.5 or player == null or not is_instance_valid(player):
		return
	var moving: bool = Vector2(player.velocity.x, player.velocity.z).length() > 0.6
	_trail_t -= delta
	if moving and _trail_t <= 0.0:
		_trail_t = lerpf(1.6, 0.7, (_hurt - 0.5) / 0.5)
		if main.has_method("_spawn_blood_damage_fx"):
			main.call("_spawn_blood_damage_fx", 0, false)


func _tick_sound(delta: float) -> void:
	var on := _hurt > 0.01
	if on:
		if not _heart.playing and _heart.stream != null:
			_heart.play()
	_heart.volume_db = move_toward(_heart.volume_db, lerpf(-30.0, -3.0, _hurt) if on else -60.0, delta * 30.0)
	# The flies at your ears when it is bad; your boots squelching as you go.
	var flies_on := _hurt > 0.6
	if flies_on and not _flies_snd.playing and _flies_snd.stream != null:
		_flies_snd.play()
	_flies_snd.volume_db = move_toward(_flies_snd.volume_db, lerpf(-22.0, -6.0, (_hurt - 0.6) / 0.4) if flies_on else -60.0, delta * 25.0)
	if not flies_on and _flies_snd.volume_db <= -59.0:
		_flies_snd.stop()
	var player = main.get("_player")
	var walking: bool = player != null and is_instance_valid(player) and Vector2(player.velocity.x, player.velocity.z).length() > 0.6
	var sq := _hurt > 0.5 and walking
	if sq and not _squelch.playing and _squelch.stream != null:
		_squelch.play()
	_squelch.volume_db = move_toward(_squelch.volume_db, -10.0 if sq else -60.0, delta * 40.0)
	if not sq and _squelch.volume_db <= -59.0:
		_squelch.stop()
	_heart.pitch_scale = lerpf(0.95, 1.45, _hurt)
	if not on and _heart.volume_db <= -59.0:
		_heart.stop()


## Under about a fifth of your health, now and then, the world goes for a moment.
func _tick_blackout(delta: float) -> void:
	if _dark_t >= 0.0:
		_dark_t += delta
		_dark = 1.0 - absf(_dark_t - 0.45) / 0.45 if _dark_t < 0.9 else 0.0
		_dark = clampf(_dark, 0.0, 0.95)
		if _dark_t >= 0.9:
			_dark_t = -1.0
			_dark = 0.0
		return
	if _hurt < 0.75:
		_dark_next = maxf(_dark_next, 6.0)
		return
	_dark_next -= delta
	if _dark_next <= 0.0:
		_dark_next = _rng.randf_range(7.0, 14.0) * lerpf(1.0, 0.6, (_hurt - 0.75) / 0.25)
		_dark_t = 0.0
		var fx = NIGHTMARE_FX.get_for(self)
		if fx != null:
			fx.tinnitus(1.4)
			# In the dark, for a few frames: your own face, torn, in a puddle.
			if _hallu_tex != null and _rng.randf() < 0.6:
				get_tree().create_timer(0.35).timeout.connect(func(): fx.subliminal(_hallu_tex, 3, 1.0, Color(0.7, 0.6, 0.6)))


## Everything off (a new game, the menu, the morning's healing is gradual anyway).
func clear() -> void:
	_flash = 0.0
	_dark = 0.0
	_dark_t = -1.0
	for s in _splats:
		(s["node"] as Node).queue_free()
	_splats.clear()
	for fl in _flies:
		(fl["node"] as Node).queue_free()
	_flies.clear()


func _play(path: String, db: float, pitch: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := _one
	if p.playing:
		p = AudioStreamPlayer.new()
		add_child(p)
		p.finished.connect(p.queue_free)
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func _play_at(path: String, db: float) -> void:
	_play(path, db, _rng.randf_range(0.9, 1.1))
