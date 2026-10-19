extends Node3D

## The air round you outdoors on still days (Build sprites from Grok, world/, moved in
## steps, twelve a second):
##   - midges: in the still mornings and evenings (not in the wind or the rain, not once
##     the October nights have turned to frost), a few swarms hang at head height near
##     you, each a cloud of gnats dancing in place; walk into one and they whine round
##     your ears;
##   - babi leto: on calm sunny autumn days threads of spider silk and thistle down drift
##     past on the breeze, glinting when they catch the sun.
## Made by weather_visuals.gd in the camp's world.

const FPS := 12.0
const SWARMS := 3
const PER_SWARM := 14
const FLOATERS := 12
const MIDGE_TEX := "res://assets/textury/world/midge.png"
const SILK_TEX := "res://assets/textury/world/gossamer.png"
const DOWN_TEX := "res://assets/textury/world/thistle_down.png"
const WHINE := "res://assets/sfx/world/midges_whine.mp3"

var player_getter: Callable

var _swarms: Array = []            # {centre: Vector3, gnats: [{sprite, off}], on}
var _floaters: Array = []          # {sprite, vel, glint}
var _whine: AudioStreamPlayer3D
var _acc := 0.0
var _poll := 0.0
var _midges_on := false
var _floaters_on := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "AirLife"
	_rng.randomize()
	var midge := _tex(MIDGE_TEX)
	for i in SWARMS:
		var gnats: Array = []
		for k in PER_SWARM:
			# Bigger than life: a gnat smaller than a pixel would be no swarm at all.
			var s := _sprite(midge, 0.016)
			gnats.append({"sprite": s, "off": Vector3.ZERO})
		_swarms.append({"centre": Vector3.INF, "gnats": gnats})
	var silk := _tex(SILK_TEX)
	var down := _tex(DOWN_TEX)
	for i in FLOATERS:
		var s2 := _sprite(silk if i % 3 != 2 else down, 0.03 if i % 3 != 2 else 0.022)
		s2.shaded = false
		_floaters.append({"sprite": s2, "vel": Vector3.ZERO, "glint": _rng.randf() * TAU, "live": false})
	_whine = AudioStreamPlayer3D.new()
	_whine.bus = "OutdoorAmbience"
	_whine.unit_size = 0.8
	_whine.max_distance = 5.0
	_whine.volume_db = -8.0
	if ResourceLoader.exists(WHINE):
		var st = load(WHINE)
		if st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			(st as AudioStreamMP3).loop = true
		_whine.stream = st
	add_child(_whine)


func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _sprite(t: Texture2D, px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = t
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.visible = false
	add_child(s)
	return s


func _process(delta: float) -> void:
	var player: Node3D = player_getter.call() if player_getter.is_valid() else null
	var main := get_tree().current_scene
	if player == null or main == null:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 2.0
		_read_conditions(main)
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	var indoors: bool = main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open"))
	var here := player.global_position
	_step_swarms(dt, here, _midges_on and not indoors)
	_step_floaters(dt, here, _floaters_on and not indoors)


## Still, dry and not too cold for midges; calm, sunny and autumn for the silk.
func _read_conditions(main: Node) -> void:
	var w := int(main.get("_weather_state")) if main.get("_weather_state") != null else 0
	var hour: float = float(main.get("_time_of_day_hours")) if main.get("_time_of_day_hours") != null else 12.0
	var day := int(main.get("_day_index")) if main.get("_day_index") != null else 1
	var autumn := Season.progress(day, hour)
	var still := w == 0 or w == 2
	_midges_on = still and autumn < 0.75 and ((hour >= 6.0 and hour < 9.5) or (hour >= 16.5 and hour < 20.5))
	_floaters_on = w == 0 and hour >= 9.0 and hour < 17.0 and autumn > 0.15 and autumn < 0.85


func _step_swarms(dt: float, here: Vector3, on: bool) -> void:
	var nearest := INF
	var nearest_c := Vector3.INF
	for sw in _swarms:
		var c: Vector3 = sw["centre"]
		if on and (c == Vector3.INF or c.distance_to(here) > 26.0):
			# A new place for it, not on top of you.
			var a := _rng.randf() * TAU
			c = here + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 10.0)
			c.y = _rng.randf_range(1.3, 2.3)
			sw["centre"] = c
		for g in sw["gnats"]:
			var s: Sprite3D = g["sprite"]
			s.visible = on and s.texture != null
			if not s.visible:
				continue
			# Each gnat dances about the swarm's middle, in steps.
			var off: Vector3 = g["off"] + Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.12, 0.12))
			if off.length() > 0.55:
				off *= 0.6
			g["off"] = off
			s.global_position = c + off
		if on and c != Vector3.INF:
			var d := c.distance_to(here + Vector3(0, 1.6, 0))
			if d < nearest:
				nearest = d
				nearest_c = c
	# Their whine when you are in one.
	if _whine.stream != null:
		var close := on and nearest < 4.0
		if close:
			_whine.global_position = nearest_c
			if not _whine.playing:
				_whine.play()
		elif _whine.playing:
			_whine.stop()


func _step_floaters(dt: float, here: Vector3, on: bool) -> void:
	var wv = get_tree().current_scene.get("_weather_visuals")
	var wd: Vector2 = wv.wind_dir if wv != null else Vector2(0.94, 0.34)
	var wind := Vector3(wd.x, 0, wd.y).normalized()
	var gust: float = float(wv.get("_wind_now")) if wv != null else 0.15
	for f in _floaters:
		var s: Sprite3D = f["sprite"]
		if not on or s.texture == null:
			s.visible = false
			f["live"] = false
			continue
		if not bool(f["live"]) or s.global_position.distance_to(here) > 16.0:
			# In again from upwind.
			var side := wind.cross(Vector3.UP)
			s.global_position = here - wind * _rng.randf_range(3.0, 9.0) + side * _rng.randf_range(-6.0, 6.0) + Vector3(0, _rng.randf_range(0.8, 2.8), 0)
			f["vel"] = wind * _rng.randf_range(0.35, 0.8) * (0.6 + gust)
			f["live"] = true
		var v: Vector3 = f["vel"]
		f["glint"] = float(f["glint"]) + dt * 3.0
		s.global_position += (v + Vector3(0, sin(float(f["glint"]) * 0.7) * 0.08, 0)) * dt
		# It catches the sun now and then.
		var g := sin(float(f["glint"]))
		s.modulate = Color(1, 1, 1, 0.55 + 0.45 * maxf(0.0, g))
		s.visible = true
