extends Node3D

## What the wind carries, and how it sounds (the user 21. 10.: "polishnout vitr huste"):
## in its gusts (weather_visuals.wind_gust) straw and dust go past you on dry days, twigs,
## a scrap of newspaper or a sweet wrapper now and then; in the storm the twigs fly thick
## and fast (the leaves are wind_life.gd's, on the same gusts). They come in from upwind,
## tumble (turned over in steps, as Build turned its sprites), the light ones bob, the
## heavy ones drop; the dust puffs grow and thin out as they go; none drawn right in your
## face, no dust or straw off the snow (Grok sprites in world/). The gusts are heard as the
## wind's own loop swelling (audio_manager.wind_gust), never a whoosh of their own (the
## user 21. 10.: "vítr by měl být kontinuální ambience na pozadí, ne jednorázový swoosh");
## the trees creak in the strong wind. Outdoors only, and not out of a moving bus.
## Made by weather_visuals.gd (setup_weather_particles), which it reads.

const FPS := 12.0
const POOL := 40
## Not drawn nearer the eye than this (wind_life.gd's NEAR: a thing across the lens is a blot).
const NEAR := 2.2
## The bits (tools/artgen/cloud_sprites.py wind): a twig, straw, newspaper, a wrapper.
const BIT_TEX := "res://assets/textury/world/wind_bit_%d.png"
const BIT_KINDS := ["twig", "straw", "paper", "wrapper"]
const DUST_TEX := "res://assets/textury/world/dust_puff_%d.png"
## The dust drawn as the breath is, a scatter of dots in the puff's shape (blended as a
## plain sprite it came out as grey blocks in the post: wind shots 21. 10.).
const DUST_SHADER := preload("res://materials/breath_puff.gdshader")
## Metres across.
const SIZE := {"twig": 0.4, "straw": 0.34, "paper": 0.5, "wrapper": 0.17, "dust": 1.7}
## Which falls (heavy) and which bobs (light).
const HEAVY := {"twig": 1.6, "paper": 0.5, "wrapper": 0.3, "straw": 0.4, "dust": 0.0}
const CREAK_SFX := "res://assets/sfx/weather/tree_creak.mp3"
## Weather (weather_visuals WEATHER_*) where it is dry enough for dust and straw.
const DRY := [0, 1]
const WET := [3, 4, 5]
const EYE := 1.6

var visuals: Node = null

var _items: Array = []       # {sprite, kind, vel: Vector3, age, life, spin, size, on}
var _tex := {}               # kind -> [Texture2D]
var _acc := 0.0
var _spawn := 0.0
var _creak_wait := 8.0
var _players: Array = []
var _next_player := 0
var _last_cam := Vector3.ZERO
var _cam_speed := 0.0
## Snow lying (Season.snow_cover), read every couple of seconds.
var _snow := 0.0
var _poll := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in BIT_KINDS.size():
		_tex[BIT_KINDS[i]] = _load_all([BIT_TEX % i])
	var dust: Array = []
	for i in 4:
		dust.append(DUST_TEX % i)
	_tex["dust"] = _load_all(dust)
	for i in POOL:
		var s := Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		s.set_meta("retro_skip", true)
		add_child(s)
		_items.append({"sprite": s, "on": false})
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "OutdoorAmbience"
		add_child(p)
		_players.append(p)


func _load_all(paths: Array) -> Array:
	var out: Array = []
	for p in paths:
		if ResourceLoader.exists(p):
			out.append(load(p))
	return out


func _v(prop: String, fallback: Variant) -> Variant:
	if visuals == null:
		return fallback
	var x = visuals.get(prop)
	return fallback if x == null else x


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null or not cam.is_inside_tree():
		return
	var cp := cam.global_position
	if delta > 0.0:
		_cam_speed = lerpf(_cam_speed, cp.distance_to(_last_cam) / delta, 0.2)
	_last_cam = cp
	var main := get_tree().current_scene
	var indoors: bool = main != null and main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open"))
	_poll -= delta
	if _poll <= 0.0:
		_poll = 2.0
		_snow = 0.0
		if main != null and main.get("_day_index") != null:
			_snow = Season.snow_cover(int(main.get("_day_index")), float(main.get("_time_of_day_hours")))
	var ws := int(_v("_weather_state", 0))
	var wind := float(_v("_wind_now", 0.15))
	var gust := float(_v("wind_gust", 0.0))
	_sounds(delta, ws, wind, gust, indoors)
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	var wd: Vector2 = _v("wind_dir", Vector2(0.94, 0.34))
	var w3 := Vector3(wd.x, 0.0, wd.y).normalized()
	# How hard it carries things: the wind over a breeze, and the gust.
	var carry := clampf(wind - 0.3, 0.0, 1.5) + gust * 1.2
	var outside := not indoors and _cam_speed < 4.0
	if outside and carry > 0.05:
		_spawn += dt * carry * (22.0 if ws == 5 else 13.0)
		while _spawn >= 1.0:
			_spawn -= 1.0
			_launch(cp, w3, carry, ws)
	else:
		_spawn = 0.0
	_step(dt, cp, w3, carry, not outside)


func _launch(cp: Vector3, w3: Vector3, carry: float, ws: int) -> void:
	var it: Dictionary = {}
	for x in _items:
		if not bool(x["on"]):
			it = x
			break
	if it.is_empty():
		return
	var kind := _pick(ws)
	if kind == "":
		return
	var texs: Array = _tex.get(kind, [])
	if texs.is_empty():
		return
	var s: Sprite3D = it["sprite"]
	var tex: Texture2D = texs[_rng.randi() % texs.size()]
	s.texture = tex
	var size := float(SIZE[kind]) * _rng.randf_range(0.8, 1.25)
	s.pixel_size = size / float(maxi(tex.get_width(), 1))
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.modulate = Color.WHITE
	if kind == "dust":
		var m := ShaderMaterial.new()
		m.shader = DUST_SHADER
		m.set_shader_parameter("puff", tex)
		m.set_shader_parameter("seed", _rng.randf() * 10.0)
		m.set_shader_parameter("fade", 0.0)
		m.set_shader_parameter("light", clampf(float(visuals.call("compute_daylight_factor")) if visuals != null else 1.0, 0.0, 1.0))
		s.material_override = m
	else:
		s.material_override = null
	var side := w3.cross(Vector3.UP)
	var ground := cp.y - EYE
	var up := _rng.randf_range(0.6, 1.4) if kind == "dust" else _rng.randf_range(0.15, 3.6)
	s.global_position = cp - w3 * _rng.randf_range(7.0, 18.0) + side * _rng.randf_range(-12.0, 12.0) + Vector3(0, 0, 0)
	s.global_position.y = ground + up
	var speed := (4.5 + 8.5 * carry) * _rng.randf_range(0.7, 1.3) * (0.55 if kind == "dust" else 1.0)
	it["vel"] = w3 * speed + side * _rng.randf_range(-0.8, 0.8) + Vector3(0, _rng.randf_range(-0.3, 1.4), 0)
	it["kind"] = kind
	it["age"] = 0.0
	it["life"] = _rng.randf_range(2.5, 4.5)
	it["spin"] = _rng.randf_range(4.0, 11.0)
	it["size"] = s.pixel_size
	it["on"] = true
	s.scale = Vector3.ONE
	s.visible = true


## What this one is ("" for nothing: the rate is the leaves' and theirs together, the
## leaves being wind_life.gd's).
func _pick(ws: int) -> String:
	var r := _rng.randf()
	if ws in DRY:
		if _snow > 0.3:
			return "twig" if r < 0.06 else ("paper" if r < 0.08 else "")
		if r < 0.16:
			return "dust"
		if r < 0.30:
			return "straw"
		if r < 0.36:
			return "twig"
		if r < 0.40:
			return "paper" if ws == 1 else "wrapper"
		if r < 0.43:
			return "wrapper"
		return ""
	if ws == 5:
		if r < 0.28:
			return "twig"
		if r < 0.32:
			return "paper"
		return ""
	if ws in WET:
		return "twig" if r < 0.12 else ""
	return ""


func _step(dt: float, cp: Vector3, w3: Vector3, carry: float, fade_all: bool) -> void:
	var ground := cp.y - EYE
	for it in _items:
		if not bool(it["on"]):
			continue
		var s: Sprite3D = it["sprite"]
		var kind := str(it["kind"])
		it["age"] = float(it["age"]) + dt
		var age := float(it["age"])
		var life := float(it["life"])
		var vel: Vector3 = it["vel"]
		# Heavy things drop, light ones bob up and down in the stream.
		vel.y -= float(HEAVY[kind]) * 4.0 * dt
		if kind == "straw":
			vel.y += sin(age * float(it["spin"]) * 0.7) * 2.2 * dt
		# The wind keeps pushing (a gust overtakes them).
		vel = vel.lerp(w3 * (4.5 + 8.5 * carry) + Vector3(0, vel.y, 0), dt * 0.8)
		it["vel"] = vel
		var p := s.global_position + vel * dt
		if p.y < ground + 0.05 and kind != "dust":
			# Along the ground, skittering.
			p.y = ground + 0.05
			vel.y = absf(vel.y) * 0.3
			it["vel"] = vel * 0.85
		s.global_position = p
		if kind == "dust":
			# Grows and thins out.
			var u := age / life
			s.scale = Vector3.ONE * (0.8 + u * 0.8)
			var m := s.material_override as ShaderMaterial
			if m != null:
				m.set_shader_parameter("fade", smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.5, 1.0, u)))
		else:
			# Tumbling: turned over and edge-on in steps.
			var turn := cos(age * float(it["spin"]))
			s.scale = Vector3(signf(turn) if absf(turn) > 0.05 else 1.0, maxf(absf(sin(age * float(it["spin"]) * 0.6)), 0.25), 1.0)
		var away := Vector2(p.x - cp.x, p.z - cp.z).length()
		if age >= life or away > 30.0 or fade_all:
			it["on"] = false
			s.visible = false
		else:
			s.visible = p.distance_to(cp) > (NEAR if kind != "dust" else NEAR * 0.6)


func _sounds(delta: float, ws: int, wind: float, gust: float, indoors: bool) -> void:
	# A gust: the wind's loop swells with it (audio_manager.wind_gust).
	var am = visuals.get("_audio_mgr") if visuals != null else null
	if am != null:
		am.set("wind_gust", 0.0 if indoors else gust)
	# The trees creak in a strong wind.
	if wind > 0.7 and not indoors:
		_creak_wait -= delta
		if _creak_wait <= 0.0:
			_creak_wait = _rng.randf_range(7.0, 18.0) / clampf(wind, 0.7, 2.0)
			_play(CREAK_SFX, _rng.randf_range(-16.0, -9.0), _rng.randf_range(0.8, 1.15))


func _play(path: String, db: float, pitch: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
