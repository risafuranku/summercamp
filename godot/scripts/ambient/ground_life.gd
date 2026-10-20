extends Node3D

## The weather on the ground round you, outdoors (the camp, the road, Lesna):
##   - rain: puddles gather where you are (they grow the longer it rains and dry up after,
##     slowly), rings spread on them as the drops hit, in steps;
##   - night, the morning and fog: low mist lies along the ground and creeps with the wind,
##     thicker in the small hours, the most at first light (in the hollows, over the lake),
##     gone by half past eight, and in the fog all day: banks of it (Grok world/mist_bank.png,
##     see-through in four steps like Blood's smoke) in the fog's colour for the hour;
## The puddle and the rings on it are Grok pictures (world/puddle.png, world/rain_ring.png). Not while you are in a room. Made by
## InteriorManager.setup() in the camp's world, like sky_life.gd and wind_life.gd.

const FPS := 12.0
const PUDDLES := 26
const MIST := 18
const RADIUS := 22.0
const MIST_TEX := "res://assets/textury/world/mist_bank.png"
## A raindrop's ripple, four frames of 16 px side by side (tools/artgen/light_sprites.py).
const RING_TEX := "res://assets/textury/world/rain_ring.png"

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
var _ring_frames: Array = []     # the ripple's frames: regions of RING_TEX
var _ring_tex: Texture2D
var _acc := 0.0
var _t := 0.0
var _anchor := Vector3.INF
var _rain := 0.0


func _ready() -> void:
	name = "GroundLife"
	_rng.randomize()
	var puddle_tex := _puddle_texture()
	_ring_tex = load(RING_TEX) if ResourceLoader.exists(RING_TEX) else null
	for i in 4:
		_ring_frames.append(Rect2(i * 16, 0, 16, 16))
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
		# The sky in it: the water shows the light of the sky over it (lit only by the rain's
		# dull light it was as dark as the wet grass and did not read), set every step.
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = puddle_tex
		m.emission_energy_multiplier = 0.0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.y = _rng.randf() * TAU
		mi.visible = false
		add_child(mi)
		var rings: Array = []
		for k in 2:
			var r := Sprite3D.new()
			r.axis = Vector3.AXIS_Y
			r.texture = _ring_tex
			r.region_enabled = true
			r.region_rect = _ring_frames[0]
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
		sp.pixel_size = _rng.randf_range(0.11, 0.16)
		sp.modulate = Color(0.75, 0.78, 0.82, 0.0)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(12.0, 36.0)
		_mist.append({"sprite": sp, "off": Vector3(cos(ang) * d, 0, sin(ang) * d), "drift": _rng.randf_range(0.2, 0.6)})


# ── pixel art ────────────────────────────────────────────────────────────────

## The puddle (Grok, assets/textury/world/puddle.png); the old pixel one if it is missing.
func _puddle_texture() -> Texture2D:
	if ResourceLoader.exists("res://assets/textury/world/puddle.png"):
		return load("res://assets/textury/world/puddle.png")
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


## A long low bank of mist (Grok `spr_mist_bank`, tools/artgen/light_sprites.py: white,
## see-through in four steps as Blood's translucent sprites; it was drawn here in code).
func _mist_texture() -> Texture2D:
	return load(MIST_TEX) if ResourceLoader.exists(MIST_TEX) else null


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
	var night := h >= 21.0 or h < 5.0
	var small_hours := h >= 1.0 and h < 5.0
	var want_mist := 0.0
	if wtr == 2:
		want_mist = 1.0
	elif h >= 5.0 and h < 8.5:
		# First light: the mist at its thickest, lifting from half past six (the dawn was
		# flat and bare: inventory 20. 10.).
		want_mist = 0.75 * clampf((8.5 - h) / 2.0, 0.0, 1.0)
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
			# More of them near you: flat on the ground, the far ones are a line at most.
			var d := lerpf(2.0, RADIUS, pow(_rng.randf(), 1.8))
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
			r.region_rect = _ring_frames[mini(3, int(float(rg["t"]) / 0.15))]
	# The mist drifts round you, low, dimmer the further. It is the fog's own colour for
	# the hour (it stood out pale blue-grey in a dark red evening: playtest 18. 10.).
	var wind := Vector3(cos(_t * 0.01), 0, sin(_t * 0.013))
	var tint := Color(0.72, 0.76, 0.82)
	var env := get_world_3d().environment if get_world_3d() != null else null
	if env != null and env.fog_enabled:
		tint = env.fog_light_color
	# The puddles mirror the sky's light (the fog's colour for the hour is the sky's).
	var sky_k := 1.3 if env != null and env.fog_enabled else 0.0
	for pd2 in _puddles:
		var pm := (pd2["mesh"] as MeshInstance3D).material_override as StandardMaterial3D
		if pm != null:
			pm.emission = tint
			pm.emission_energy_multiplier = sky_k
	for ms in _mist:
		var sp: Sprite3D = ms["sprite"]
		var off: Vector3 = ms["off"]
		off += wind * float(ms["drift"]) / FPS
		if off.length() > 38.0 or off.length() < 10.0:
			off = -off.normalized() * 30.0 if off.length() > 38.0 else off.normalized() * 12.0
		ms["off"] = off
		sp.global_position = Vector3(centre.x + off.x, 0.6 + sin(_t * 0.2 + off.x) * 0.15, centre.z + off.z)
		var a := _mist_amount * 0.9 * clampf((off.length() - 10.0) / 10.0, 0.2, 1.0)
		sp.modulate = Color(tint.r, tint.g, tint.b, a)
		sp.visible = a > 0.01
