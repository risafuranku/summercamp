extends Node3D

## Your breath (a child of your camera, outdoors in the camp):
##   - in the cold (the nights, the early mornings, and all day as October gets colder) a
##     puff of it in front of you every breath (Grok, world/breath_puff.png), drifting
##     up and off with the wind, gone in a second; lit like everything else, so at night
##     you see it in your torch or under a lamp. Quicker breaths when you walk, a quick
##     run of them when you are out of breath;
##   - run yourself out (the stamina gone) and you hear yourself pant until you have it
##     back; on a cold night now and then a long breath out (ElevenLabs, sfx/player/).
## Moved in steps (twelve a second) like the rest of the Build world.

const PUFF_TEX := "res://assets/textury/world/breath_puff.png"
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
var _tex: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "PlayerBreath"
	_rng.randomize()
	_tex = load(PUFF_TEX) if ResourceLoader.exists(PUFF_TEX) else null
	for i in 3:
		var s := Sprite3D.new()
		s.texture = _tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = true
		s.transparency = 0.0
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		_puffs.append({"sprite": s, "t": -1.0, "vel": Vector3.ZERO})
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
	if main == null or bool(main.get("_menu_mode")):
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
	for p in _puffs:
		var s: Sprite3D = p["sprite"]
		if float(p["t"]) < 0.0:
			continue
		p["t"] = float(p["t"]) + dt
		var k := float(p["t"]) / LIFE
		if k >= 1.0 or not out:
			p["t"] = -1.0
			s.visible = false
			continue
		s.position += (p["vel"] as Vector3) * dt
		var size := lerpf(0.0022, 0.0062, k)
		s.pixel_size = size
		s.modulate = Color(1.15, 1.15, 1.2, (1.0 - k) * 0.38)


func _breathe(spent: bool) -> void:
	if _tex == null:
		return
	for p in _puffs:
		if float(p["t"]) >= 0.0:
			continue
		var s: Sprite3D = p["sprite"]
		# Out from the mouth, a little below the eye and in front, drifting up and away
		# (the wind takes it off to one side).
		s.position = Vector3(_rng.randf_range(-0.03, 0.03), -0.17, -0.38)
		var drift := _rng.randf_range(-0.12, 0.12)
		p["vel"] = Vector3(drift, 0.14, -0.3 if not spent else -0.45)
		p["t"] = 0.0
		s.pixel_size = 0.0022
		s.modulate = Color(1.15, 1.15, 1.2, 0.38)
		s.visible = true
		break
	_breaths += 1
	if not spent and _breaths % 4 == 0 and _sigh.stream != null and not _sigh.playing:
		_sigh.pitch_scale = _rng.randf_range(0.94, 1.05)
		_sigh.play()
