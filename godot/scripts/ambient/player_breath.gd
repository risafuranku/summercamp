extends Node3D

## Your breath (a child of your camera, outdoors in the camp):
##   - in the cold (the nights, the early mornings, and all day as October gets colder) a
##     puff of it in front of you every breath (materials/breath_puff.gdshader: a puff
##     of vapour, Grok camp/breath_puff.png, see-through as Build's translucent sprites
##     were, a hand's breadth across and growing as it drifts up and off with the wind,
##     thinner, gone in a second); as bright as the light it is in: by day pale, at
##     night only in your torch, not seen in the dark without one. Quicker breaths when
##     you walk, a quick run of them when you are out of breath;
##   - run yourself out (the stamina gone) and you hear yourself pant until you have it
##     back; on a cold night now and then a long breath out (ElevenLabs, sfx/player/).
## Moved in steps (twelve a second) like the rest of the Build world.

const PUFF_SHADER = preload("res://materials/breath_puff.gdshader")
const PUFF_TEX := "res://assets/textury/camp/breath_puff.png"
## How big a puff is as it leaves your mouth and when it is gone (m): small and low in the
## view (drawn whole and see-through, at 0.22 to 0.6 m it covered half the screen).
const SIZE_FROM := 0.1
const SIZE_TO := 0.3
const SFX_PANT := "res://assets/sfx/player/panting.mp3"
const SFX_BREATH := "res://assets/sfx/player/breath_cold.mp3"
const FPS := 12.0
const LIFE := 1.3

## The player (scripts/player_controller.gd): its stamina and its speed.
var player: Node

var _puffs: Array = []             # {sprite, t, vel: Vector3}
var _next := 2.0
var _acc := 0.0
var _breaths := 0
var _panting := false
var _pant: AudioStreamPlayer
var _sigh: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "PlayerBreath"
	_rng.randomize()
	for i in 3:
		var s := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		s.mesh = q
		var m := ShaderMaterial.new()
		m.shader = PUFF_SHADER
		m.set_shader_parameter("seed", float(i) * 1.7)
		m.set_shader_parameter("puff", load(PUFF_TEX))
		s.material_override = m
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		_puffs.append({"sprite": s, "mat": m, "t": -1.0, "vel": Vector3.ZERO})
	_pant = AudioStreamPlayer.new()
	_pant.stream = load(SFX_PANT) if ResourceLoader.exists(SFX_PANT) else null
	_pant.volume_db = -10.0
	add_child(_pant)
	_sigh = AudioStreamPlayer.new()
	_sigh.stream = load(SFX_BREATH) if ResourceLoader.exists(SFX_BREATH) else null
	_sigh.volume_db = -22.0
	add_child(_sigh)


func _main() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


## Cold enough to see your breath: the night and the early morning, and the whole day
## once October has turned cold.
func _cold() -> bool:
	var main := _main()
	if main == null:
		return false
	var hour: float = float(main.get("_time_of_day_hours")) if main.get("_time_of_day_hours") != null else 12.0
	var day: int = int(main.get("_day_index")) if main.get("_day_index") != null else 1
	return hour < 8.5 or hour >= 19.5 or Season.progress(day, hour) > 0.55


func _outdoors() -> bool:
	var main := _main()
	# Not the game's main (a harness scene): nowhere to breathe.
	if main == null or main.get("_menu_mode") != false:
		return false
	return not (main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open")))


func _process(delta: float) -> void:
	var out := _outdoors()
	var spent: bool = player != null and bool(player.get("_stamina_locked"))
	# Out of breath: pant until it is back.
	if spent and not _panting and _pant.stream != null:
		_panting = true
		_pant.pitch_scale = _rng.randf_range(0.95, 1.05)
		_pant.play()
	elif not spent and _panting:
		_panting = false
	# The breaths: slow standing, quicker walking, quick when spent.
	var speed := 0.0
	if player is CharacterBody3D:
		var v: Vector3 = (player as CharacterBody3D).velocity
		speed = Vector2(v.x, v.z).length()
	var every := 3.6 if speed < 0.5 else 2.6
	if spent:
		every = 1.1
	_next -= delta
	if _next <= 0.0:
		_next = every * _rng.randf_range(0.85, 1.15)
		if out and _cold():
			_breathe(spent)
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	var light := _light()
	for p in _puffs:
		var s: MeshInstance3D = p["sprite"]
		if float(p["t"]) < 0.0:
			continue
		p["t"] = float(p["t"]) + dt
		var k := float(p["t"]) / LIFE
		if k >= 1.0 or not out:
			p["t"] = -1.0
			s.visible = false
			continue
		s.position += (p["vel"] as Vector3) * dt
		var size := lerpf(SIZE_FROM, SIZE_TO, k)
		s.scale = Vector3(size, size, size)
		(p["mat"] as ShaderMaterial).set_shader_parameter("fade", (1.0 - k) * 0.8)
		(p["mat"] as ShaderMaterial).set_shader_parameter("light", light)


## The light the puff is in: the day's, or your torch's shining out through it.
func _light() -> float:
	var main := _main()
	var day := 0.0
	var wv = main.get("_weather_visuals") if main != null else null
	if wv != null and wv.has_method("compute_daylight_factor"):
		day = float(wv.compute_daylight_factor())
	var torch := 0.7 if player != null and bool(player.get("_flashlight_active")) else 0.0
	return clampf(maxf(day, torch), 0.08, 1.0)


func _breathe(spent: bool) -> void:
	for p in _puffs:
		if float(p["t"]) >= 0.0:
			continue
		var s: MeshInstance3D = p["sprite"]
		# Out from the mouth, a little below the eye and well in front (close up it filled
		# the view), drifting up and away (the wind takes it off to one side).
		s.position = Vector3(_rng.randf_range(-0.04, 0.04), -0.26, -0.7)
		var drift := _rng.randf_range(-0.14, 0.14)
		p["vel"] = Vector3(drift, 0.16, -0.32 if not spent else -0.5)
		p["t"] = 0.0
		s.scale = Vector3.ONE * SIZE_FROM
		(p["mat"] as ShaderMaterial).set_shader_parameter("fade", 0.8)
		(p["mat"] as ShaderMaterial).set_shader_parameter("light", _light())
		(p["mat"] as ShaderMaterial).set_shader_parameter("seed", _rng.randf() * 10.0)
		s.visible = true
		break
	_breaths += 1
	if not spent and _breaths % 4 == 0 and _sigh.stream != null and not _sigh.playing:
		_sigh.pitch_scale = _rng.randf_range(0.94, 1.05)
		_sigh.play()
