extends Node3D

## Layers of cloud over the world, under the panorama (DESIGN.md "the sky"): high thin
## streaks lying flat up high, the ragged clouds in the middle, low dark scud under rain.
## Each layer's amount, shade and speed by the weather (fading in and out one cloud at a
## time as the weather turns), all drifting with the wind, the slow high ones the least;
## wrapped round whichever camera is looking (the bus's and the car's too: the clouds were
## pinned round the camp). A cloud far off fades into the sky, before the horizon.
## It goes on from agent B's drifting clouds (the four ragged Grok clouds, cloud_0..3, eight
## of them round the camp): those are the middle layer, as many out, as solid and as fast
## as weather_visuals' own cloud targets say (set_cloud_targets_from_weather, eased in
## update_sky_runtime), with the same tint for the hour and the weather.
## Made by weather_visuals.gd (setup_weather_particles), which it reads: the weather, the
## wind, its cloud targets, the sun's height, the clouds' tint, the lightning.

const LAYERS := [
	# High: flat streaks, seen from below, foreshortened toward the horizon.
	{"tex": "res://assets/textury/skybox/cloud_hi_%d.png", "n": 16, "alt": Vector2(160.0, 220.0),
		"extent": 650.0, "w": Vector2(120.0, 220.0), "speed": 0.45, "shade": 1.04, "alpha": 0.62, "flat": true},
	# The ragged clouds of the sky's own look (cloud_0..3).
	{"tex": "res://assets/textury/skybox/cloud_%d.png", "n": 30, "alt": Vector2(70.0, 120.0),
		"extent": 480.0, "w": Vector2(40.0, 90.0), "speed": 1.0, "shade": 0.94, "alpha": 0.9, "flat": false},
	# Low scud: dark, torn, fast in the wind.
	{"tex": "res://assets/textury/skybox/cloud_lo_%d.png", "n": 26, "alt": Vector2(28.0, 45.0),
		"extent": 300.0, "w": Vector2(30.0, 60.0), "speed": 2.4, "shade": 0.66, "alpha": 0.86, "flat": false},
]
## The weather (weather_visuals WEATHER_*: clear, windy, fog, light rain, rain, storm, the
## red anomaly) -> how much of each layer is out [high, middle, low], 0..1 (the middle one
## is weather_visuals' _cloud_density_current when it has it).
const AMOUNT := {
	0: [0.40, 0.30, 0.0], 1: [0.55, 0.55, 0.30], 2: [0.0, 0.30, 0.45], 3: [0.10, 0.70, 0.55],
	4: [0.0, 0.92, 0.90], 5: [0.0, 1.0, 1.0], 6: [0.0, 0.30, 0.0],
}
## In fog the clouds are hardly there (the fog is the sky).
const SEEN := {2: 0.35}
## How much darker the weather makes them (their bellies in the rain), 0..1.
const DARK := {1: 0.10, 2: 0.20, 3: 0.35, 4: 0.55, 5: 0.68}
## A late autumn day under the grey lid (weather_visuals._late_grey_day): more of the middle.
const GREY_DAY_AMOUNT := [0.0, 0.70, 0.20]
## How fast the amounts follow the weather (per second; a cloud fades over FADE of it).
const AMOUNT_RATE := 0.025
const FADE := 0.10
## Metres a second at the middle layer's pace, by the wind (weather_visuals._wind_now 0..1).
const DRIFT_CALM := 0.5
const DRIFT_GALE := 6.0
const SEED := 19980919

var visuals: Node = null

var _clouds: Array = []   # {node, mat, layer, at: Vector3 (world xz, altitude), r, alpha_j}
var _amount := [0.0, 0.0, 0.0]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
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
			var tex: Texture2D = texs[i % texs.size()]
			var w := rng.randf_range(float(layer["w"].x), float(layer["w"].y))
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(w, w * float(tex.get_height()) / float(tex.get_width()))
			mi.mesh = q
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_meta("retro_skip", true)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_texture = tex
			# Smooth, as the panorama is (the post pass gives them the game's pixel): drawn
			# nearest, a cloud overhead showed its texels as steps metres wide.
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.disable_fog = true
			if not bool(layer["flat"]):
				m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			# Over the sun (8) and the moon (1), far behind them all: the cloud goes over
			# the moon. Higher layers drawn first, the scud over them.
			m.render_priority = 9 + li
			mi.material_override = m
			if bool(layer["flat"]):
				# Lying flat, its picture seen from below.
				mi.rotation = Vector3(PI * 0.5, rng.randf_range(-0.25, 0.25), 0.0)
			mi.visible = false
			add_child(mi)
			var ext := float(layer["extent"])
			_clouds.append({"node": mi, "mat": m, "layer": li,
				"at": Vector3(rng.randf_range(-ext, ext), rng.randf_range(float(layer["alt"].x), float(layer["alt"].y)), rng.randf_range(-ext, ext)),
				# Its place in the order the layer's clouds come out (spread evenly, shuffled).
				"r": (float(i) + rng.randf()) / float(n), "alpha_j": rng.randf_range(0.8, 1.1)})
	_amount = _target()


func _target() -> Array:
	var ws := int(_v("_weather_state", 0))
	var out: Array = (AMOUNT.get(ws, AMOUNT[0]) as Array).duplicate()
	if _target_is_grey():
		# No high streaks under the lid; more of the others.
		out[0] = GREY_DAY_AMOUNT[0]
		for i in [1, 2]:
			out[i] = maxf(float(out[i]), float(GREY_DAY_AMOUNT[i]))
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
	if _clouds.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null or not cam.is_inside_tree():
		return
	var target := _target()
	for i in 3:
		_amount[i] = move_toward(float(_amount[i]), float(target[i]), delta * AMOUNT_RATE)
	# The middle layer: agent B's own cloud targets, eased there.
	var b_density = _v("_cloud_density_current", null)
	if b_density != null:
		_amount[1] = maxf(float(b_density), float(_amount[1]))
	var solid := clampf(0.45 + float(_v("_cloud_alpha_current", 0.4)), 0.0, 1.0)
	var seen := float(SEEN.get(int(_v("_weather_state", 0)), 1.0))
	var dark := float(DARK.get(int(_v("_weather_state", 0)), 0.0))
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
	for c in _clouds:
		var layer: Dictionary = LAYERS[int(c["layer"])]
		var ext := float(layer["extent"])
		var at: Vector3 = c["at"]
		at.x += wd.x * pace * float(layer["speed"]) * delta
		at.z += wd.y * pace * float(layer["speed"]) * delta
		c["at"] = at
		var mi: MeshInstance3D = c["node"]
		var amt := float(_amount[int(c["layer"])])
		var a := clampf((amt - float(c["r"])) / FADE + 1.0, 0.0, 1.0) if amt > 0.001 else 0.0
		# Round the camera: the world's place wrapped into the square about it.
		var x := cp.x + fposmod(at.x - cp.x + ext, ext * 2.0) - ext
		var z := cp.z + fposmod(at.z - cp.z + ext, ext * 2.0) - ext
		var far := Vector2(x - cp.x, z - cp.z).length() / ext
		a *= 1.0 - smoothstep(0.55, 0.95, far)
		a *= float(layer["alpha"]) * float(c["alpha_j"]) * seen
		if int(c["layer"]) == 1:
			a *= solid
		if a < 0.02:
			mi.visible = false
			continue
		mi.visible = true
		mi.global_position = Vector3(x, at.y, z)
		var col := tint * float(layer["shade"]) * bright * (1.0 - dark * (0.5 if int(c["layer"]) == 0 else 0.75))
		col = col.lerp(Color(0.92, 0.95, 1.0), flash * 0.35)
		col.a = clampf(a, 0.0, 0.95)
		(c["mat"] as StandardMaterial3D).albedo_color = col
