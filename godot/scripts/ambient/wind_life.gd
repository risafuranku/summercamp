extends Node3D

## The wind you can see, outdoors round you (the camp, the road, Lesna): autumn leaves
## blown along in steps (12 a second, like the rest of the Build sprites), tumbling (face
## on, edge on, flipped) and turning round as they go (each its own way and speed, faster
## in a gust: they only ever flew tip up, the user 20. 10.), coming down, lying a moment,
## picked up again by the next gust.
## Oak, maple and birch leaves (Grok, assets/textury/world/leaf_*.png), big leaves' size,
## and none right in your face (one that drifts that close is not drawn).
## How many and how fast goes with the weather (a breeze on a clear day, a gale in a
## storm, still in the fog) and the season (more as the trees go bare, none under the
## snow). Their colours are the season's (Season.leaf_tint). Not while you are in a room.
## Made by InteriorManager.setup() in the camp's world, like sky_life.gd.

const FPS := 12.0
const POOL := 72
const RADIUS := 15.0
const LEAVES := ["leaf_oak", "leaf_maple", "leaf_birch"]
const TEX_DIR := "res://assets/textury/world/"
## Not drawn nearer the eye than this (a leaf across the lens is a blot, not a leaf; at
## 0.9 m one in a storm still filled a corner of the 240-line screen: inventory 20. 10.).
const NEAR := 2.2

var player_getter: Callable
var indoors: Callable
## Callable() -> int: the weather (weather_system.gd WEATHER_*).
var weather_getter: Callable
## Callable() -> Vector2: (season day, hour).
var season_getter: Callable
## Callable() -> Vector3: the weather's wind (x, z the way it blows, y the gust 0..1;
## weather_visuals.gd), so the leaves go the trees' way and come in the same gusts as
## wind_things.gd's straw and twigs. Without it the leaves have a wind of their own.
var wind_getter: Callable

var _rng := RandomNumberGenerator.new()
var _frames: Array = []          # one texture per leaf shape
var _leaves: Array = []          # {sprite, vel: Vector3, rest: float, shape, spin}
var _acc := 0.0
var _t := 0.0
var _dir := 0.0                  # radians, the way the wind blows
var _gust := 0.0
var _gust_t := 4.0
var _strength := 0.3
var _tint := Color(0.8, 0.5, 0.2)
var _poll := 0.0


func _ready() -> void:
	name = "WindLife"
	_rng.randomize()
	_dir = _rng.randf() * TAU
	for n in LEAVES:
		var path: String = TEX_DIR + n + ".png"
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	for i in POOL:
		var s := Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		s.pixel_size = 0.04
		s.visible = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		_leaves.append({"sprite": s, "vel": Vector3.ZERO, "rest": 0.0, "shape": i % maxi(1, _frames.size()), "spin": _rng.randf() * 4.0, "live": false,
			"roll": _rng.randf() * TAU, "roll_v": 0.0})


func _player() -> Node3D:
	return player_getter.call() if player_getter.is_valid() else null


func _process(delta: float) -> void:
	var p := _player()
	var inside: bool = indoors.is_valid() and indoors.call()
	visible = p != null and not inside and not _frames.is_empty()
	if not visible:
		return
	_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 2.0
		_read_weather()
	# The wind turns slowly; gusts come and go.
	var shared: Vector3 = wind_getter.call() if wind_getter.is_valid() else Vector3.ZERO
	if shared != Vector3.ZERO:
		_dir = atan2(shared.z, shared.x)
		_gust = maxf(move_toward(_gust, 0.0, delta * 0.35), shared.y * 1.4)
	else:
		_dir += sin(_t * 0.05) * delta * 0.08
		_gust_t -= delta
		if _gust_t <= 0.0:
			_gust_t = _rng.randf_range(3.0, 9.0) / maxf(0.4, _strength)
			_gust = _rng.randf_range(0.6, 1.4)
		_gust = move_toward(_gust, 0.0, delta * 0.35)
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	var centre := p.global_position
	var cam = p.get("_camera")
	var eye: Vector3 = (cam as Node3D).global_position if cam is Node3D else centre + Vector3.UP * 1.6
	var wind := Vector3(cos(_dir), 0, sin(_dir)) * (1.2 + 4.5 * _strength) * (1.0 + _gust)
	var want := int(round(float(POOL) * clampf(_strength * 0.9, 0.0, 1.0)))
	var live := 0
	for lf in _leaves:
		if lf["live"]:
			live += 1
	for lf in _leaves:
		var s: Sprite3D = lf["sprite"]
		if not lf["live"]:
			if live < want and _rng.randf() < 0.5:
				_spawn(lf, centre, wind)
				live += 1
			continue
		var pos := s.global_position
		if lf["rest"] > 0.0:
			# On the ground: only a strong gust lifts it again.
			lf["rest"] -= dt
			if _gust > 0.9 and _rng.randf() < 0.3:
				lf["rest"] = 0.0
				lf["vel"] = wind * 0.6 + Vector3(0, _rng.randf_range(1.0, 2.4), 0)
				_lie(s, false)
			elif lf["rest"] <= 0.0 and _rng.randf() < 0.5:
				lf["live"] = false
				s.visible = false
				continue
		else:
			var v: Vector3 = lf["vel"]
			v = v.lerp(wind + Vector3(0, -0.9, 0), clampf(dt * 1.6, 0.0, 1.0))
			v.y += sin(_t * 3.0 + float(lf["spin"]) * 7.0) * 1.2 * dt * 6.0
			lf["vel"] = v
			pos += v * dt
			lf["spin"] = float(lf["spin"]) + dt * (3.0 + v.length())
			# Tumbling: face on, turning, edge on, turning back (a step each), flipped
			# every other turn.
			var phase := int(lf["spin"] * 2.0) % 4
			s.flip_h = int(lf["spin"] * 0.5) % 2 == 0
			lf["roll"] = float(lf["roll"]) + dt * float(lf["roll_v"]) * (0.6 + v.length() * 0.25)
			# The camp, the road and Lesna all lie at y 0.
			var ground := 0.04
			if pos.y <= ground + 0.02:
				pos.y = ground + 0.02
				lf["rest"] = _rng.randf_range(2.0, 7.0)
				_lie(s, true)
		# Gone too far from you: back in round the edge upwind.
		var off := pos - centre
		off.y = 0.0
		if off.length() > RADIUS:
			_spawn(lf, centre, wind)
			continue
		s.global_position = pos
		if lf["rest"] <= 0.0:
			_face(s, eye, float(lf["roll"]), [1.0, 0.6, 0.25, 0.6][int(lf["spin"] * 2.0) % 4])
		s.visible = pos.distance_to(eye) > NEAR


## In the air: turned to you (by hand, so it can turn round as well), its tip wherever its
## turn has got to, narrowed as it tumbles edge on.
func _face(s: Sprite3D, eye: Vector3, roll: float, width: float) -> void:
	var to_eye := eye - s.global_position
	if to_eye.length() < 0.01:
		return
	to_eye = to_eye.normalized()
	var up := Vector3.UP if absf(to_eye.y) < 0.98 else Vector3.FORWARD
	# The sprite's face is +Z: looking away from the eye puts it towards it.
	var b := Basis.looking_at(-to_eye, up)
	b = b * Basis(Vector3(0, 0, 1), roll) * Basis.from_scale(Vector3(width, 1.0, 1.0))
	s.global_transform = Transform3D(b, s.global_position)


## Down on the ground it lies flat, any way round; up in the air it faces you again.
func _lie(s: Sprite3D, flat: bool) -> void:
	s.scale = Vector3.ONE
	if flat:
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.rotation = Vector3(-PI * 0.5, _rng.randf() * TAU, 0.0)
	else:
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.rotation = Vector3.ZERO


func _spawn(lf: Dictionary, centre: Vector3, wind: Vector3) -> void:
	var s: Sprite3D = lf["sprite"]
	_lie(s, false)
	var up := -wind.normalized() if wind.length() > 0.01 else Vector3.FORWARD
	var side := up.cross(Vector3.UP)
	var at := centre + up * _rng.randf_range(RADIUS * 0.15, RADIUS * 0.95) + side * _rng.randf_range(-RADIUS * 0.7, RADIUS * 0.7)
	at.y = _rng.randf_range(0.6, 6.0)
	s.global_position = at
	lf["vel"] = wind * _rng.randf_range(0.7, 1.1)
	lf["rest"] = 0.0
	lf["live"] = true
	lf["roll"] = _rng.randf() * TAU
	lf["roll_v"] = _rng.randf_range(1.2, 4.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	# The leaf's own colours, a touch of the season's tint, each a little lighter or darker.
	lf["shape"] = _rng.randi() % _frames.size()
	var tex: Texture2D = _frames[lf["shape"]]
	s.texture = tex
	s.scale = Vector3.ONE
	s.modulate = Color.WHITE.lerp(_tint * 1.25, 0.2) * _rng.randf_range(0.85, 1.08)
	# A big leaf's size, 12 to 17 cm across (smaller would be lost in the low resolution).
	s.pixel_size = _rng.randf_range(0.12, 0.17) / float(maxi(1, tex.get_width()))
	s.visible = true


func _read_weather() -> void:
	var wtr := int(weather_getter.call()) if weather_getter.is_valid() else 0
	var base: float = [0.28, 1.0, 0.08, 0.4, 0.6, 1.25, 0.5][clampi(wtr, 0, 6)]
	var fall := 0.6
	var snow := false
	if season_getter.is_valid():
		var sd: Vector2 = season_getter.call()
		var day := int(sd.x)
		fall = clampf(Season.leaf_turn(day, sd.y) * 1.3, 0.45, 1.0) * clampf(Season.leaves_on(day, sd.y) + 0.35, 0.2, 1.0)
		_tint = Season.leaf_tint(day, sd.y)
		snow = Season.precip_is_snow(day, sd.y) and wtr >= 3 and wtr <= 5
	if _tint.r + _tint.g + _tint.b < 0.6 or _tint.g > _tint.r * 1.1:
		_tint = Color(0.78, 0.48, 0.18)
	_strength = 0.0 if snow else base * fall
