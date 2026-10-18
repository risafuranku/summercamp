extends Node3D

## The weather on the ground round you, outdoors (the camp, the road, Lesna):
##   - rain: puddles gather where you are (they grow the longer it rains and dry up after,
##     slowly), rings spread on them as the drops hit, in steps;
##   - night and fog: low mist lies along the ground and creeps with the wind, thicker in
##     the small hours and in the fog, a Build-style dithered sprite (see-through in a
##     checker of pixels, like Blood's smoke);
## Pixel art made here (no files). Not while you are in a room. Made by
## InteriorManager.setup() in the camp's world, like sky_life.gd and wind_life.gd.

const FPS := 12.0
const PUDDLES := 26
const MIST := 18
const RADIUS := 22.0

var player_getter: Callable
var indoors: Callable
var weather_getter: Callable
## Callable() -> float: the hour.
var hour_getter: Callable

var _rng := RandomNumberGenerator.new()
var _puddles: Array = []         # {mesh, mat, size, rings: [Sprite3D]}
var _wet := 0.0                  # 0 dry .. 1 soaked
var _mist: Array = []            # {sprite, off: Vector3, drift}
var _mist_amount := 0.0
var _ring_frames: Array = []
var _acc := 0.0
var _t := 0.0
var _anchor := Vector3.INF
var _rain := 0.0


func _ready() -> void:
	name = "GroundLife"
	_rng.randomize()
	var puddle_tex := _puddle_texture()
	for i in 4:
		_ring_frames.append(_ring_texture(i))
	for i in PUDDLES:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		var s := _rng.randf_range(0.7, 2.2)
		q.size = Vector2(s, s * _rng.randf_range(0.5, 0.8))
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = puddle_tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.roughness = 0.45
		m.metallic_specular = 0.25
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.y = _rng.randf() * TAU
		mi.visible = false
		add_child(mi)
		var rings: Array = []
		for k in 2:
			var r := Sprite3D.new()
			r.axis = Vector3.AXIS_Y
			r.texture = _ring_frames[0]
			r.pixel_size = 0.03
			r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			r.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			r.shaded = true
			r.visible = false
			add_child(r)
			rings.append({"sprite": r, "t": _rng.randf() * 0.6})
		_puddles.append({"mesh": mi, "size": s, "rings": rings, "spot": Vector3.ZERO})
	var mist_tex := _mist_texture()
	for i in MIST:
		var sp := Sprite3D.new()
		sp.texture = mist_tex
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sp.transparent = true
		sp.shaded = false
		sp.pixel_size = _rng.randf_range(0.16, 0.24)
		sp.modulate = Color(0.75, 0.78, 0.82, 0.0)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(12.0, 36.0)
		_mist.append({"sprite": sp, "off": Vector3(cos(ang) * d, 0, sin(ang) * d), "drift": _rng.randf_range(0.2, 0.6)})


# ── pixel art ────────────────────────────────────────────────────────────────

func _puddle_texture() -> ImageTexture:
	var w := 32
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var d := Vector2((x - w * 0.5 + 0.5) / (w * 0.5), (y - h * 0.5 + 0.5) / (h * 0.5))
			var wob := 0.86 + 0.14 * sin(atan2(d.y, d.x) * 3.0 + 1.3) * cos(atan2(d.y, d.x) * 2.0)
			if d.length() < wob:
				var edge := d.length() > wob - 0.16
				var c := Color(0.09, 0.1, 0.11) if not edge else Color(0.17, 0.15, 0.12)
				# The sky caught in it, in streaks.
				if not edge and (y % 5 == 1) and (x + y) % 7 < 3:
					c = Color(0.26, 0.29, 0.32)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _ring_texture(stage: int) -> ImageTexture:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := 2.0 + stage * 1.8
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, (y - n * 0.5 + 0.5) * 1.4).length()
			if absf(d - r) < 0.7:
				img.set_pixel(x, y, Color(0.62, 0.66, 0.7, 1.0))
	return ImageTexture.create_from_image(img)


## A long low bank of mist: soft clouds of pixels in four steps of see-through (Blood's
## translucent sprites; a checker of pixels read as a fault up close).
func _mist_texture() -> ImageTexture:
	var w := 64
	var h := 14
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var seed := _rng.randf() * 10.0
	for y in h:
		for x in w:
			var dx := absf(x - w * 0.5) / (w * 0.5)
			var dy := absf(y - h * 0.6) / (h * 0.5)
			var n := 0.5 + 0.25 * sin(x * 0.37 + seed) * cos(y * 0.9 + seed * 0.7) + 0.25 * sin(x * 0.13 + y * 0.4 + seed * 1.3)
			var dens := clampf((1.0 - dx * dx) * (1.0 - dy * dy) * n * 1.6, 0.0, 1.0)
			var a := floorf(dens * 4.0) / 4.0 * 0.5
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var p: Node3D = player_getter.call() if player_getter.is_valid() else null
	var inside: bool = indoors.is_valid() and indoors.call()
	visible = p != null and not inside
	if not visible:
		return
	_t += delta
	var wtr := int(weather_getter.call()) if weather_getter.is_valid() else 0
	var h := float(hour_getter.call()) if hour_getter.is_valid() else 12.0
	# 3 light rain, 4 rain, 5 storm.
	_rain = [0.0, 0.0, 0.0, 0.45, 0.8, 1.0, 0.0][clampi(wtr, 0, 6)]
	_wet = clampf(_wet + delta * (_rain * 0.012 if _rain > 0.0 else -0.004), 0.0, 1.0)
	var night := h >= 21.0 or h < 6.0
	var small_hours := h >= 1.0 and h < 6.0
	var want_mist := 0.0
	if wtr == 2:
		want_mist = 1.0
	elif night:
		want_mist = 0.55 if small_hours else 0.35
	if _rain > 0.6:
		want_mist *= 0.4
	_mist_amount = move_toward(_mist_amount, want_mist, delta * 0.03)
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	var centre := p.global_position
	# The puddles stay where they formed while you are near; far off they form anew round you.
	if _anchor == Vector3.INF or Vector2(_anchor.x - centre.x, _anchor.z - centre.z).length() > RADIUS * 0.7:
		_anchor = centre
		for pd in _puddles:
			var ang := _rng.randf() * TAU
			var d := _rng.randf_range(2.0, RADIUS)
			pd["spot"] = Vector3(centre.x + cos(ang) * d, 0.045, centre.z + sin(ang) * d)
	for i in _puddles.size():
		var pd: Dictionary = _puddles[i]
		var mi: MeshInstance3D = pd["mesh"]
		# The wetter it is the more there are, the bigger.
		var share := float(i) / float(_puddles.size())
		var on := _wet > share * 0.9 + 0.05
		mi.visible = on
		var k := clampf((_wet - share * 0.9) * 3.0, 0.3, 1.0)
		mi.scale = Vector3(k, 1.0, k)
		mi.global_position = pd["spot"]
		for rg in pd["rings"]:
			var r: Sprite3D = rg["sprite"]
			r.visible = on and _rain > 0.0
			if not r.visible:
				continue
			rg["t"] = float(rg["t"]) + 1.0 / FPS * (0.8 + _rain)
			if rg["t"] > 0.6:
				rg["t"] = 0.0
				var spot: Vector3 = pd["spot"]
				var rr := float(pd["size"]) * 0.3 * k
				r.global_position = spot + Vector3(_rng.randf_range(-rr, rr), 0.01, _rng.randf_range(-rr, rr))
			r.texture = _ring_frames[mini(3, int(float(rg["t"]) / 0.15))]
	# The mist drifts round you, low, dimmer the further.
	var wind := Vector3(cos(_t * 0.01), 0, sin(_t * 0.013))
	for ms in _mist:
		var sp: Sprite3D = ms["sprite"]
		var off: Vector3 = ms["off"]
		off += wind * float(ms["drift"]) / FPS
		if off.length() > 38.0 or off.length() < 10.0:
			off = -off.normalized() * 30.0 if off.length() > 38.0 else off.normalized() * 12.0
		ms["off"] = off
		sp.global_position = Vector3(centre.x + off.x, 0.6 + sin(_t * 0.2 + off.x) * 0.15, centre.z + off.z)
		var a := _mist_amount * 0.9 * clampf((off.length() - 10.0) / 10.0, 0.2, 1.0)
		sp.modulate = Color(0.72, 0.76, 0.82, a)
		sp.visible = a > 0.01
