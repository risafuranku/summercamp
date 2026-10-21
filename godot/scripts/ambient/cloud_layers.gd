extends Node3D

## Clouds over the world in layers, under the panorama (DESIGN.md "the sky"): high thin
## streaks lying flat up high; in the middle the cloud deck, a thick body of cloud with a
## belly, sides and a top; low dark scud under rain, each piece a cluster of puffs at
## different depths. All by the weather, drifting with the wind, wrapped round whichever
## camera is looking (the bus's and the car's too), faded before the horizon.
##
## The deck (the user 20. 10.: "chtel bych je nejak vic prostorovy, nejen sprites") is a
## stack of wide planes, one over another, each reading Grok's cloud cover seen from below
## (materials/cloud_deck.gdshader): a slice higher up shows only thicker cloud, so from
## under it and toward the horizon the clouds have depth, and move against each other and
## against the scud as you walk. How much of the sky it covers, how dark its belly is and
## how fast it goes are agent B's own cloud targets (weather_visuals
## set_cloud_targets_from_weather, eased in update_sky_runtime), its light B's tint for the
## hour and the weather; with the sun low its belly takes the sun's colour from below
## (rose at dawn, red-orange at sunset), after sunset it is dark against the red.
## A storm (the user 21. 10.: "crazy mraky pri bouri"): the deck comes down low and thick,
## churns and wheels overhead, its belly a sick green and its top violet; lightning lights
## it from inside, now at a bolt, now deep in the cloud with no bolt at all, flickering;
## the scud races lower. The rain has a little of it.
## Made by weather_visuals.gd (setup_weather_particles), which it reads.

const DECK_SHADER := preload("res://materials/cloud_deck.gdshader")
const COVER_A := "res://assets/textury/skybox/cloud_cover_a.png"
const COVER_B := "res://assets/textury/skybox/cloud_cover_b.png"
## The deck: slices, the lowest's height, the gap between them, how far round the camera.
const DECK_SLICES := 6
const DECK_BASE := 95.0
const DECK_GAP := 5.5
const DECK_RADIUS := 950.0
## The weather (weather_visuals WEATHER_*: clear, windy, fog, light rain, rain, storm, the
## red anomaly) -> the deck's cover: 0 scattered fair-weather clouds .. 1 torn overcast.
const COVER_MIX := {0: 0.0, 1: 0.25, 2: 0.5, 3: 0.6, 4: 0.9, 5: 1.0, 6: 0.3}
## How much of the storm's ways the weather has (light rain, rain, the storm).
const STORMY := {3: 0.15, 4: 0.45, 5: 1.0}
## The deck in a storm: lower and thicker.
const STORM_BASE := 58.0
const STORM_GAP := 9.0
## The storm's colours: a sick olive belly, a bruised grey top. Kept near grey: any more
## green or blue and the palette dithered the whole deck into teal (21. 10.).
const STORM_BELLY := Color(0.27, 0.29, 0.24)
const STORM_TOP := Color(0.43, 0.41, 0.44)
## Flashes deep in the cloud: the wait between them (s) in a storm, and in the rain.
const FLASH_WAIT_STORM := Vector2(1.2, 5.0)
const FLASH_WAIT_RAIN := Vector2(18.0, 45.0)

const LAYERS := [
	# High: flat streaks, seen from below, foreshortened toward the horizon.
	{"tex": "res://assets/textury/skybox/cloud_hi_%d.png", "n": 16, "alt": Vector2(160.0, 220.0),
		"extent": 650.0, "w": Vector2(120.0, 220.0), "speed": 0.45, "shade": 1.04, "alpha": 0.62, "flat": true, "puffs": 1},
	# Low scud: dark, torn, fast in the wind; each a cluster of puffs, the belly darker and
	# nearer, a lighter top (agent B's ragged cloud) above and behind it.
	{"tex": "res://assets/textury/skybox/cloud_lo_%d.png", "n": 22, "alt": Vector2(30.0, 46.0),
		"extent": 320.0, "w": Vector2(30.0, 56.0), "speed": 2.4, "shade": 0.66, "alpha": 0.86, "flat": false, "puffs": 3},
]
## The puffs of a cluster: [size, shade, rise (of the width), depth spread (of the width)].
const PUFFS := [[1.0, 0.82, 0.0, 0.0], [0.78, 1.0, 0.16, 0.32], [0.62, 1.22, 0.30, 0.38]]
const TOP_PUFF_TEX := "res://assets/textury/skybox/cloud_%d.png"
## The weather -> how much of each sprite layer is out [high, low], 0..1.
const AMOUNT := {
	0: [0.40, 0.0], 1: [0.55, 0.30], 2: [0.0, 0.45], 3: [0.10, 0.55],
	4: [0.0, 0.90], 5: [0.0, 1.0], 6: [0.0, 0.0],
}
## In fog the clouds are hardly there (the fog is the sky).
const SEEN := {2: 0.35}
## How much darker the weather makes them (their bellies in the rain), 0..1.
const DARK := {1: 0.10, 2: 0.20, 3: 0.35, 4: 0.55, 5: 0.68}
## A late autumn day under the grey lid (weather_visuals._late_grey_day): the deck's cover
## at least this, no high streaks, a little scud.
const GREY_DAY_COVER := 0.72
const GREY_DAY_AMOUNT := [0.0, 0.20]
## How fast the amounts follow the weather (per second; a cloud fades over FADE of it).
const AMOUNT_RATE := 0.025
const FADE := 0.10
## Metres a second at the deck's pace, by the wind (weather_visuals._wind_now 0..1).
const DRIFT_CALM := 0.5
const DRIFT_GALE := 6.0
const SEED := 19980919

var visuals: Node = null

var _clouds: Array = []   # {puffs: [{node, mat, off: Vector3, shade}], layer, at, r, alpha_j}
var _amount := [0.0, 0.0]
var _deck: Array = []     # MeshInstance3D, lowest first
var _deck_mats: Array = []
var _deck_scroll := Vector2.ZERO
var _cover := 0.3
var _cover_mix := 0.0
var _storm := 0.0
var _churn_time := 0.0
## The flash in the cloud: where, how long it has been, how long it goes, how strong,
## how many times it flickers; and the wait for the next.
var _flash_pos := Vector3.ZERO
var _flash_t := -1.0
var _flash_len := 0.3
var _flash_peak := 0.0
var _flash_pulses := 2
var _flash_wait := 3.0
var _bolt_was := false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_build_deck()
	var tops: Array = []
	for k in 4:
		if ResourceLoader.exists(TOP_PUFF_TEX % k):
			tops.append(load(TOP_PUFF_TEX % k))
	for li in LAYERS.size():
		var layer: Dictionary = LAYERS[li]
		var texs: Array = []
		for k in 4:
			var path := str(layer["tex"]) % k
			if ResourceLoader.exists(path):
				texs.append(load(path))
		if texs.is_empty():
			continue
		var n := int(layer["n"])
		for i in n:
			var w := rng.randf_range(float(layer["w"].x), float(layer["w"].y))
			var puffs: Array = []
			for pi in int(layer["puffs"]):
				var p: Array = PUFFS[pi]
				var tex: Texture2D = texs[(i + pi) % texs.size()]
				if pi == 2 and not tops.is_empty():
					tex = tops[i % tops.size()]
				var pw := w * float(p[0])
				var mi := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(pw, pw * float(tex.get_height()) / float(tex.get_width()))
				mi.mesh = q
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.set_meta("retro_skip", true)
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_texture = tex
				# Smooth, as the panorama is (the post pass gives them the game's pixel).
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.disable_fog = true
				if not bool(layer["flat"]):
					m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				# Over the sun (8) and the moon (1); the high streaks (9) behind the deck
				# (10..15), the scud in front of it, a cluster's belly over its top.
				m.render_priority = 9 if li == 0 else 18 - pi
				mi.material_override = m
				if bool(layer["flat"]):
					mi.rotation = Vector3(PI * 0.5, rng.randf_range(-0.25, 0.25), 0.0)
				mi.visible = false
				add_child(mi)
				var spread := float(p[3]) * w
				puffs.append({"node": mi, "mat": m, "shade": float(p[1]),
					"off": Vector3(rng.randf_range(-spread, spread), float(p[2]) * w, rng.randf_range(-spread, spread))})
			var ext := float(layer["extent"])
			_clouds.append({"puffs": puffs, "layer": li,
				"at": Vector3(rng.randf_range(-ext, ext), rng.randf_range(float(layer["alt"].x), float(layer["alt"].y)), rng.randf_range(-ext, ext)),
				# Its place in the order the layer's clouds come out (spread evenly, shuffled).
				"r": (float(i) + rng.randf()) / float(n), "alpha_j": rng.randf_range(0.8, 1.1)})
	_amount = _target()


func _build_deck() -> void:
	if not ResourceLoader.exists(COVER_A):
		return
	var a: Texture2D = load(COVER_A)
	var b: Texture2D = load(COVER_B) if ResourceLoader.exists(COVER_B) else a
	var plane := PlaneMesh.new()
	plane.size = Vector2(DECK_RADIUS * 2.0, DECK_RADIUS * 2.0)
	for i in DECK_SLICES:
		var m := ShaderMaterial.new()
		m.shader = DECK_SHADER
		m.set_shader_parameter("cover_a", a)
		m.set_shader_parameter("cover_b", b)
		m.set_shader_parameter("slice", float(i) / float(DECK_SLICES - 1))
		m.set_shader_parameter("radius", DECK_RADIUS)
		# Drawn top first: from under it the lowest slice is the nearest.
		m.render_priority = 15 - i
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("retro_skip", true)
		# Never culled away by its bounds: it is always round the camera.
		mi.extra_cull_margin = 400.0
		add_child(mi)
		_deck.append(mi)
		_deck_mats.append(m)


func _target() -> Array:
	var ws := int(_v("_weather_state", 0))
	var out: Array = (AMOUNT.get(ws, AMOUNT[0]) as Array).duplicate()
	if _target_is_grey():
		out[0] = GREY_DAY_AMOUNT[0]
		out[1] = maxf(float(out[1]), float(GREY_DAY_AMOUNT[1]))
	return out


func _target_is_grey() -> bool:
	var ws := int(_v("_weather_state", 0))
	return (ws == 0 or ws == 1) and visuals != null and visuals.has_method("_late_grey_day") and bool(visuals.call("_late_grey_day"))


func _v(prop: String, fallback: Variant) -> Variant:
	if visuals == null:
		return fallback
	var x = visuals.get(prop)
	return fallback if x == null else x


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null or not cam.is_inside_tree():
		return
	var ws := int(_v("_weather_state", 0))
	var target := _target()
	for i in 2:
		_amount[i] = move_toward(float(_amount[i]), float(target[i]), delta * AMOUNT_RATE)
	var seen := float(SEEN.get(ws, 1.0))
	var dark := float(DARK.get(ws, 0.0))
	var wind := float(_v("_wind_now", 0.15))
	var wd: Vector2 = _v("wind_dir", Vector2(0.94, 0.34))
	if wd.length() < 0.01:
		wd = Vector2(1, 0)
	wd = wd.normalized()
	var pace := lerpf(DRIFT_CALM, DRIFT_GALE, clampf(wind, 0.0, 1.0))
	pace *= 0.6 + float(_v("_cloud_speed_current", 0.4))
	# The light on them: the hour's and the weather's tint, darker as the sun goes down
	# (dark against the red after sunset, hardly there at night).
	var tint := Color(0.94, 0.95, 0.94)
	if visuals != null and visuals.has_method("_cloud_tint_for_time_weather") and visuals.has_method("_cloud_daylight_profile"):
		tint = (visuals.call("_cloud_tint_for_time_weather") as Color).lerp((visuals.call("_cloud_daylight_profile") as Dictionary)["tint"] as Color, 0.42)
	var sun: Vector3 = _v("_sun_direction_to_source", Vector3.UP)
	var day := clampf((sun.y + 0.10) / 0.35, 0.0, 1.0)
	var bright := lerpf(0.30, 1.0, day)
	var flash := float(_v("_storm_flash_strength", 0.0))
	var cp := cam.global_position
	_update_deck(delta, cp, wd, pace, tint, bright, dark, seen, flash, sun)
	for c in _clouds:
		var li := int(c["layer"])
		var layer: Dictionary = LAYERS[li]
		var ext := float(layer["extent"])
		var at: Vector3 = c["at"]
		var fast := 1.0 + (_storm if li == 1 else 0.0)
		at.x += wd.x * pace * float(layer["speed"]) * fast * delta
		at.z += wd.y * pace * float(layer["speed"]) * fast * delta
		c["at"] = at
		var amt := float(_amount[li])
		var a := clampf((amt - float(c["r"])) / FADE + 1.0, 0.0, 1.0) if amt > 0.001 else 0.0
		# Round the camera: the world's place wrapped into the square about it.
		var x := cp.x + fposmod(at.x - cp.x + ext, ext * 2.0) - ext
		var z := cp.z + fposmod(at.z - cp.z + ext, ext * 2.0) - ext
		var far := Vector2(x - cp.x, z - cp.z).length() / ext
		a *= 1.0 - smoothstep(0.55, 0.95, far)
		a *= float(layer["alpha"]) * float(c["alpha_j"]) * seen
		for p in c["puffs"]:
			var mi: MeshInstance3D = p["node"]
			if a < 0.02:
				mi.visible = false
				continue
			mi.visible = true
			var y := at.y * (1.0 - 0.3 * _storm) if li == 1 else at.y
			mi.global_position = Vector3(x, y, z) + (p["off"] as Vector3)
			var col := tint * float(layer["shade"]) * float(p["shade"]) * bright * (1.0 - dark * (0.5 if li == 0 else 0.75))
			col = col.lerp(Color(0.92, 0.95, 1.0), flash * 0.35)
			col.a = clampf(a, 0.0, 0.95)
			(p["mat"] as StandardMaterial3D).albedo_color = col


func _update_deck(delta: float, cp: Vector3, wd: Vector2, pace: float, tint: Color, bright: float,
		dark: float, seen: float, flash: float, sun: Vector3) -> void:
	if _deck.is_empty():
		return
	var ws := int(_v("_weather_state", 0))
	# How much of the sky: B's cloud density, eased (clear some, the storm all of it).
	var want := lerpf(0.04, 0.97, clampf(float(_v("_cloud_density_current", 0.2)), 0.0, 1.0))
	if _target_is_grey():
		want = maxf(want, GREY_DAY_COVER)
	if ws == 6:
		want = 0.2
	_cover = move_toward(_cover, want, delta * AMOUNT_RATE)
	_storm = move_toward(_storm, float(STORMY.get(ws, 0.0)), delta * AMOUNT_RATE)
	_churn_time += delta * (1.0 + float(_v("_wind_now", 0.15)))
	_update_flash(delta, cp, ws)
	_cover_mix = move_toward(_cover_mix, float(COVER_MIX.get(ws, 0.0)), delta * AMOUNT_RATE)
	# The cover moves with the wind (the picture's place goes the other way).
	_deck_scroll -= wd * pace * delta
	_deck_scroll = Vector2(fposmod(_deck_scroll.x, 11000.0), fposmod(_deck_scroll.y, 11000.0))
	var top := tint * bright * 1.04 * (1.0 - dark * 0.5)
	var belly := tint * bright * 0.6 * (1.0 - dark * 0.8)
	# The sun low: its light on the belly from below, the top in shade (rose at dawn,
	# red-orange at sunset).
	var low := clampf(1.0 - absf(sun.y + 0.02) / 0.16, 0.0, 1.0) * (1.0 - dark)
	if low > 0.0:
		var morning := float(_v("_time_of_day_hours", 18.0)) < 12.0
		var warm := Color(1.0, 0.58, 0.62) if morning else Color(1.0, 0.46, 0.26)
		belly = belly.lerp(warm * 0.95, low * 0.7)
		top = top.lerp(top * 0.72, low * 0.5)
	# The sun's side: lit white by day, the low sun's colour at dawn and sunset, none once
	# it is down.
	var rim := (tint * bright * 1.22).lerp(Color(1.0, 0.58, 0.62) if float(_v("_time_of_day_hours", 18.0)) < 12.0 else Color(1.0, 0.5, 0.28), low)
	rim.a = clampf((sun.y + 0.04) / 0.12, 0.0, 1.0) * (1.0 - dark * 0.8) * 0.8
	# The storm's colours, lit as the hour is.
	belly = belly.lerp(STORM_BELLY * lerpf(0.4, 1.0, bright), _storm * 0.65)
	top = top.lerp(STORM_TOP * lerpf(0.35, 1.0, bright), _storm * 0.55)
	top = top.lerp(Color(0.92, 0.95, 1.0), flash * 0.4)
	belly = belly.lerp(Color(0.80, 0.84, 0.95), flash * 0.4)
	for i in _deck.size():
		var mi: MeshInstance3D = _deck[i]
		var base := lerpf(DECK_BASE, STORM_BASE, _storm)
		var gap := lerpf(DECK_GAP, STORM_GAP, _storm)
		mi.global_position = Vector3(cp.x, base + gap * float(i), cp.z)
		var m: ShaderMaterial = _deck_mats[i]
		m.set_shader_parameter("coverage", _cover)
		m.set_shader_parameter("cover_mix", _cover_mix)
		m.set_shader_parameter("scroll", _deck_scroll)
		m.set_shader_parameter("top_color", top)
		m.set_shader_parameter("belly_color", belly)
		m.set_shader_parameter("alpha_max", 0.92 * seen)
		m.set_shader_parameter("sun_dir", sun.normalized() if sun.length() > 0.01 else Vector3.UP)
		m.set_shader_parameter("rim_color", rim)
		m.set_shader_parameter("churn", _storm)
		m.set_shader_parameter("churn_time", _churn_time)
		m.set_shader_parameter("flash_pos", _flash_pos)
		m.set_shader_parameter("flash_strength", _flash_now())


## The flash in the cloud: a bolt's (weather_visuals strikes it where you can see it), or
## one of the storm's own deep in the cloud with no bolt, now near, now far off.
func _update_flash(delta: float, cp: Vector3, ws: int) -> void:
	var bolt = _v("_bolt", null)
	var bolt_on: bool = bolt != null and is_instance_valid(bolt) and (bolt as Node3D).visible
	if bolt_on and not _bolt_was:
		_start_flash(Vector3((bolt as Node3D).global_position.x, 0.0, (bolt as Node3D).global_position.z), randf_range(0.85, 1.0), 2)
	_bolt_was = bolt_on
	if _flash_t >= 0.0:
		_flash_t += delta
		if _flash_t >= _flash_len:
			_flash_t = -1.0
	var wait := FLASH_WAIT_STORM if ws == 5 else (FLASH_WAIT_RAIN if ws == 4 else Vector2.ZERO)
	if wait == Vector2.ZERO:
		return
	_flash_wait -= delta
	if _flash_wait <= 0.0:
		_flash_wait = randf_range(wait.x, wait.y)
		var ang := randf() * TAU
		var r := randf_range(60.0, 650.0)
		_start_flash(cp + Vector3(cos(ang), 0.0, sin(ang)) * r, randf_range(0.45, 0.95), randi_range(1, 4))


func _start_flash(at: Vector3, peak: float, pulses: int) -> void:
	_flash_pos = at
	_flash_t = 0.0
	_flash_peak = peak
	_flash_pulses = pulses
	_flash_len = randf_range(0.18, 0.5) * float(pulses)


## How bright the flash is now: it flickers (`pulses` times), in steps of twelve a second.
func _flash_now() -> float:
	if _flash_t < 0.0:
		return 0.0
	var t := floorf(_flash_t * 12.0) / 12.0
	var u := t / _flash_len
	var flick := absf(sin(u * PI * float(_flash_pulses)))
	return _flash_peak * flick * (1.0 - u * 0.5)
