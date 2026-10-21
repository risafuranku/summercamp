extends Node3D

## The forest lake behind the camp (DESIGN §14). The last row of the grid is the camp's
## shore (TILE_LAKE: guests stand at it, the slide goes into it); from there the water
## opens out beyond the north fence into a real lake: an irregular sheet of panning water,
## a muddy shore, reeds, a jetty with a rowing boat tied to it, the forest around, and
## mist on the water in the early morning.
##
## You can walk out on the jetty; the water itself is fenced off by invisible walls along
## the shore (you do not swim at night).

const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
const WATER_SHADER = preload("res://materials/lake_water.gdshader")
const REEDS := "res://assets/textury/world/reeds.png"
const SHORE_TEX := "res://assets/textury/camp/lake_shore.png"
const WATER_TEX := "res://assets/textury/camp/lake_water.png"

const WATER_Y := 0.06
const JETTY_LEN := 9.0
const JETTY_W := 1.6
const JETTY_Y := 0.42

var _main: Node
## For the trip across (scripts/lake/lake_trip.gd): the boat, where it is tied up, the
## water you can row on, and the far jetty by the keeper's boathouse.
var boat: Node3D
var boat_home := Transform3D()
var water_poly := PackedVector2Array()
var far_jetty_end := Vector3.ZERO
var far_view := Vector3.ZERO
## The two jetties' decks on the water (world x, z): the boat does not row through them.
var jetty_rects: Array[Rect2] = []
var hut_window: OmniLight3D
var hut_window_mesh: MeshInstance3D
## Fish: now and then by day a ring spreads on the water (in steps, 10 a second) with a plop.
const PLOP_SFX := "res://assets/sfx/world/fish_plop.mp3"
var _water_poly := PackedVector2Array()
## The water's outline as it is drawn, the camp shore's z, the jetty's x (body_world.gd:
## your boots in the water, the ducks on the shore).
var _poly_raw := PackedVector2Array()
var _shore_z := 0.0
var _jetty_x := 0.0
var _ripple_tex: ImageTexture
var _ripple_timer := 5.0
var _ripples: Array = []   # {node, frame}
var _ripple_acc := 0.0
var _rng_fx := RandomNumberGenerator.new()
var _mist: Array[MeshInstance3D] = []  # mist puffs over the water
var _mist_t := 0.0
## The water's material, and how often it is told the world's light and weather.
var _water_mat: ShaderMaterial
## The mirror: the world drawn from under the water (the camera's mirror image) into a
## small view the water reads (lake_water.gdshader refl_tex); only while a camera is near.
## The water itself is on its own layer, which the mirror's camera does not see.
const REFL_LAYER := 1 << 18
const REFL_NEAR := 95.0
var _refl_vp: SubViewport
var _refl_cam: Camera3D
var _water_node: MeshInstance3D
## The mirror on or off (the settings, tests).
var mirror := true
var _look_t := 0.0


## `shore_z`: world z of the camp-side edge of the lake row; `north_z`: the map's north
## edge; `west`/`east`: the map's x edges. `rng` keeps it the same for a seed.
static func water_polygon(shore_z: float, north_z: float, west: float, east: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(west + 0.2, shore_z))
	pts.append(Vector2(east - 0.2, shore_z))
	# Up the east side, round the far shore, back down the west side (kept clear of the
	# corn field, which reaches 8 m past the north fence west of the camp).
	var cx := (west + east) * 0.5
	var rx := (east - west) * 0.5 + 16.0
	var rz := 46.0
	var n := 22
	for i in n + 1:
		var a := PI * float(i) / float(n)
		var wob := rng.randf_range(-4.5, 4.5)
		var x := cx + cos(a) * (rx + wob)
		var z := north_z + 6.0 + sin(a) * (rz + wob)
		if a > PI * 0.82:
			x = maxf(x, west - 1.0 - (z - north_z) * 0.4)
		pts.append(Vector2(x, z))
	pts.append(Vector2(west - 0.5, north_z + 9.0))
	pts.append(Vector2(west + 0.2, north_z))
	return pts


func build(main_node: Node, shore_z: float, north_z: float, west: float, east: float, texture_seed: int) -> void:
	_main = main_node
	name = "CampLake"
	var rng := RandomNumberGenerator.new()
	rng.seed = texture_seed
	var poly := water_polygon(shore_z, north_z, west, east, rng)
	_poly_raw = poly
	_shore_z = shore_z
	var far_z := north_z + 52.0
	_water_poly = Geometry2D.offset_polygon(poly, -4.0)[0]
	_rng_fx.randomize()

	# The shore: the water outline grown by 3 m, mud and sand, just under the water.
	var shore_poly: PackedVector2Array = Geometry2D.offset_polygon(poly, 3.2)[0]
	var shore := _flat_mesh(shore_poly, 0.02, "LakeShore")
	var shore_mat := StandardMaterial3D.new()
	shore_mat.albedo_texture = load(SHORE_TEX)
	shore_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shore_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	shore_mat.uv1_triplanar = true
	shore_mat.uv1_world_triplanar = true
	shore_mat.uv1_scale = Vector3.ONE / 2.5
	shore.material_override = shore_mat
	shore.position.z = 0.0

	# The water.
	var water := _flat_mesh(poly, WATER_Y, "LakeWater")
	var wmat := ShaderMaterial.new()
	wmat.shader = WATER_SHADER
	wmat.set_shader_parameter("water_tex", load(WATER_TEX))
	wmat.set_shader_parameter("shore_z", Vector2(shore_z, far_z))
	water.material_override = wmat
	_water_mat = wmat
	water.layers = REFL_LAYER
	_water_node = water
	call_deferred("_build_reflection")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Reeds along the shore (not in front of the jetty), thick at the corners.
	var jetty_x := (west + east) * 0.5 + 9.0
	_jetty_x = jetty_x
	var reeds_tex: Texture2D = load(REEDS) if ResourceLoader.exists(REEDS) else null
	if reeds_tex != null:
		var outline := Geometry2D.offset_polygon(poly, -0.6)[0] as PackedVector2Array
		for i in outline.size():
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[(i + 1) % outline.size()]
			var steps := int(a.distance_to(b) / 2.2)
			for k in steps:
				var p := a.lerp(b, (float(k) + rng.randf()) / float(maxi(1, steps)))
				if absf(p.x - jetty_x) < 3.0 and p.y < shore_z + 2.0:
					continue
				if rng.randf() < 0.45:
					continue
				_reed_clump(Vector3(p.x, WATER_Y, p.y), rng, reeds_tex)

	# The jetty: planks on posts, from the camp shore out over the water, and the boat.
	_build_jetty(Vector3(jetty_x, 0.0, shore_z - 1.0))
	boat = INTERIOR_KIT.prop(self, "rowboat", Vector3(jetty_x + 1.6, WATER_Y - 0.12, shore_z + JETTY_LEN * 0.55), 12.0)
	if boat != null:
		boat.name = "RowBoat"
		boat_home = boat.transform
	water_poly = Geometry2D.offset_polygon(poly, -2.5)[0]
	# The far shore: the keeper's boathouse and its jetty, across the water from the camp.
	var far := poly[2 + 11]
	_build_far_shore(Vector3(far.x, 0.0, far.y))

	# You cannot walk into the lake: a wall along the camp shore with a gap for the jetty,
	# a stride out in the shallows (the brief of 21. 10.: wade in a step and splash; it
	# stood 0.3 m in, so you never reached the water).
	var gap_l := jetty_x - JETTY_W * 0.5
	var gap_r := jetty_x + JETTY_W * 0.5
	_wall(Vector3((west + gap_l) * 0.5, 1.0, shore_z + WADE), Vector3(gap_l - west, 2.0, 0.3))
	_wall(Vector3((gap_r + east) * 0.5, 1.0, shore_z + WADE), Vector3(east - gap_r, 2.0, 0.3))

	# Morning mist: soft banks standing over the water (camera-facing puffs: flat sheets
	# vanish edge-on at eye height), drifting slowly along the lake.
	var puff := _mist_texture(rng)
	var shrunk: PackedVector2Array = Geometry2D.offset_polygon(poly, -3.0)[0]
	var box := Rect2(shrunk[0], Vector2.ZERO)
	for v in shrunk:
		box = box.expand(v)
	var tries := 0
	while _mist.size() < 26 and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		if not Geometry2D.is_point_in_polygon(p, shrunk):
			continue
		var m := MeshInstance3D.new()
		m.name = "LakeMist"
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(9.0, 16.0), rng.randf_range(2.0, 3.4))
		m.mesh = q
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_texture = puff
		mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mm.albedo_color = Color(0.82, 0.85, 0.84, 0.0)
		mm.disable_receive_shadows = true
		mm.proximity_fade_enabled = true
		mm.proximity_fade_distance = 1.5
		m.material_override = mm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(p.x, WATER_Y + q.size.y * 0.42, p.y)
		m.set_meta("x0", p.x)
		m.set_meta("speed", rng.randf_range(0.15, 0.45))
		m.set_meta("span", box.size.x)
		m.set_meta("left", box.position.x)
		add_child(m)
		_mist.append(m)


func _update_ripples(delta: float, hour: float) -> void:
	if _water_poly.is_empty():
		return
	_ripple_timer -= delta
	if _ripple_timer <= 0.0 and hour > 6.0 and hour < 21.0:
		_ripple_timer = _rng_fx.randf_range(4.0, 13.0)
		_spawn_ripple()
	_ripple_acc += delta
	if _ripple_acc < 0.1:
		return
	_ripple_acc = 0.0
	for r in _ripples:
		var n: MeshInstance3D = r["node"]
		r["frame"] += 1
		var f := int(r["frame"])
		n.scale = Vector3.ONE * (0.4 + 0.28 * f)
		(n.material_override as StandardMaterial3D).albedo_color.a = clampf(0.75 - 0.08 * f, 0.0, 1.0)
		if f >= 9:
			n.queue_free()
	_ripples = _ripples.filter(func(r): return int(r["frame"]) < 9)


func _spawn_ripple() -> void:
	var box := Rect2(_water_poly[0], Vector2.ZERO)
	for v in _water_poly:
		box = box.expand(v)
	for _try in 20:
		var p := Vector2(_rng_fx.randf_range(box.position.x, box.end.x), _rng_fx.randf_range(box.position.y, box.end.y))
		if not Geometry2D.is_point_in_polygon(p, _water_poly):
			continue
		if _ripple_tex == null:
			var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			for y in 32:
				for x in 32:
					var d := Vector2(x - 15.5, y - 15.5).length()
					var a := 1.0 if (d > 12.0 and d < 15.0) or (d > 6.0 and d < 7.5) else 0.0
					img.set_pixel(x, y, Color(0.85, 0.9, 0.92, a))
			_ripple_tex = ImageTexture.create_from_image(img)
		var n := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 1.6)
		n.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _ripple_tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.albedo_color = Color(1, 1, 1, 0.75)
		n.material_override = m
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.rotation.x = -PI * 0.5
		n.position = Vector3(p.x, WATER_Y + 0.02, p.y)
		add_child(n)
		_ripples.append({"node": n, "frame": 0})
		if ResourceLoader.exists(PLOP_SFX):
			var a := AudioStreamPlayer3D.new()
			a.stream = load(PLOP_SFX)
			a.unit_size = 5.0
			a.max_distance = 50.0
			n.add_child(a)
			a.play()
		return


## A soft lumpy blob of mist, transparent at the edges (64 x 32, palette-friendly steps).
func _mist_texture(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var bumps: Array = []
	for i in 7:
		bumps.append(Vector3(rng.randf_range(0.15, 0.85), rng.randf_range(0.35, 0.7), rng.randf_range(0.14, 0.3)))
	for y in 32:
		for x in 64:
			var u := float(x) / 63.0
			var v := float(y) / 31.0
			var a := 0.0
			for b: Vector3 in bumps:
				var d := Vector2((u - b.x) * 0.55, v - b.y).length() / b.z
				a = maxf(a, 1.0 - d)
			a = clampf(a, 0.0, 1.0) * clampf((1.0 - v) * 3.0, 0.0, 1.0)
			a = floorf(a * 5.0) / 5.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _build_reflection() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	_refl_vp = SubViewport.new()
	_refl_vp.name = "LakeMirror"
	_refl_vp.size = Vector2i(160, 90)
	_refl_vp.world_3d = get_viewport().find_world_3d()
	_refl_vp.msaa_3d = Viewport.MSAA_DISABLED
	_refl_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_refl_vp.positional_shadow_atlas_size = 0
	_refl_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_refl_vp)
	_refl_cam = Camera3D.new()
	_refl_cam.cull_mask = 0xFFFFF & ~REFL_LAYER
	_refl_cam.near = 0.3
	_refl_cam.far = 350.0
	_refl_vp.add_child(_refl_cam)
	_water_mat.set_shader_parameter("refl_tex", _refl_vp.get_texture())


## The mirror camera: the looking camera reflected in the water, at half its pixels; off
## when no camera is near the water (and in rooms: the world's own camera is elsewhere).
func _update_reflection() -> void:
	if _refl_vp == null or _water_node == null:
		return
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var on := mirror and cam != null and cam.is_inside_tree() and _near_water(cam.global_position)
	_refl_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_water_mat.set_shader_parameter("refl_on", 1.0 if on else 0.0)
	if not on:
		return
	var vs := get_viewport().get_visible_rect().size
	var want := Vector2i(maxi(80, int(vs.x * 0.5)), maxi(45, int(vs.y * 0.5)))
	if _refl_vp.size != want:
		_refl_vp.size = want
	_refl_cam.fov = cam.fov
	_refl_cam.keep_aspect = cam.keep_aspect
	var p := cam.global_position
	var f := -cam.global_transform.basis.z
	var mp := Vector3(p.x, 2.0 * WATER_Y - p.y, p.z)
	var mf := Vector3(f.x, -f.y, f.z)
	if absf(mf.normalized().dot(Vector3.UP)) > 0.999:
		mf += Vector3(0.001, 0, 0.001)
	_refl_cam.global_position = mp
	_refl_cam.look_at(mp + mf, Vector3.UP)


func _near_water(at: Vector3) -> bool:
	if _water_poly.is_empty():
		return false
	var p := Vector2(at.x, at.z)
	if Geometry2D.is_point_in_polygon(p, _water_poly):
		return true
	for i in _water_poly.size():
		var a: Vector2 = _water_poly[i]
		var b: Vector2 = _water_poly[(i + 1) % _water_poly.size()]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < REFL_NEAR:
			return true
	return false


func _process(delta: float) -> void:
	_update_reflection()
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = 0.25
		_water_look()
	if _mist.is_empty() or _main == null:
		return
	_mist_t += delta
	var h := float(_main.get("_time_of_day_hours")) if _main.get("_time_of_day_hours") != null else 12.0
	# Thick at dawn (04:30-08:30), a breath of it at night, gone by day.
	var dawn := clampf(1.0 - absf(h - 6.3) / 2.2, 0.0, 1.0)
	var night := 0.3 if (h >= 21.5 or h < 4.5) else 0.0
	var amount := maxf(dawn, night)
	_update_ripples(delta, h)
	for m in _mist:
		var mm := m.material_override as StandardMaterial3D
		mm.albedo_color.a = amount * 0.55
		m.visible = amount > 0.01
		if m.visible:
			var span: float = m.get_meta("span")
			m.position.x = float(m.get_meta("left")) + fposmod(float(m.get_meta("x0")) - float(m.get_meta("left")) + _mist_t * float(m.get_meta("speed")), span)


## The water as the world is now (lake_water.gdshader): the horizon it gives back (the
## sky's colour, which the time of day and the weather set), where the sun or the moon is
## and how bright, how much light there is, the wind and the rain.
func _water_look() -> void:
	var scene := get_tree().current_scene if get_tree() != null else null
	if _water_mat == null or scene == null:
		return
	var env_node = scene.get("world_environment")
	var env: Environment = env_node.environment if env_node != null else null
	if env == null and get_viewport() != null and get_viewport().world_3d != null:
		env = get_viewport().world_3d.environment
	var sun: DirectionalLight3D = scene.get("sun")
	var sky := Color(0.55, 0.62, 0.7)
	var ambient := 0.4
	if env != null:
		# The sky behind the clouds (weather_visuals sets it by the hour), hazed as the fog
		# hazes the sky itself.
		sky = env.background_color
		if env.fog_enabled:
			sky = sky.lerp(env.fog_light_color, clampf(env.fog_sky_affect, 0.0, 1.0) * 0.5)
		ambient = clampf(env.ambient_light_color.get_luminance() * env.ambient_light_energy * 1.6, 0.0, 1.0)
	var sun_lum := 0.0
	if sun != null and sun.visible:
		var dir := -sun.global_transform.basis.z
		_water_mat.set_shader_parameter("sun_dir", -dir)
		var col := sun.light_color * clampf(sun.light_energy, 0.0, 1.4)
		_water_mat.set_shader_parameter("sun_col", col)
		sun_lum = clampf(col.get_luminance() * (1.0 if -dir.y > 0.0 else 0.0), 0.0, 1.0)
	_water_mat.set_shader_parameter("sky_col", sky)
	_water_mat.set_shader_parameter("light_level", clampf(maxf(sun_lum, ambient), 0.0, 1.0))
	var w := int(scene.get("_weather_state")) if scene.get("_weather_state") != null else 0
	# Clear, windy, fog, light rain, rain, storm, the night's own.
	var wind: float = [0.15, 0.65, 0.05, 0.3, 0.45, 1.0, 0.25][clampi(w, 0, 6)]
	var rain: float = [0.0, 0.0, 0.0, 0.35, 0.7, 1.0, 0.0][clampi(w, 0, 6)]
	_water_mat.set_shader_parameter("wind", wind)
	_water_mat.set_shader_parameter("rain", rain)


func _build_jetty(start: Vector3) -> void:
	var K := INTERIOR_KIT
	var planks := K.surface("planks_grey", 1.2)
	var posts := K.surface("planks_dark", 0.6)
	var body := StaticBody3D.new()
	body.name = "Jetty"
	add_child(body)
	var deck_center := start + Vector3(0, JETTY_Y, JETTY_LEN * 0.5)
	K.slab(body, Vector3(JETTY_W, 0.08, JETTY_LEN), deck_center, planks, "Deck")
	jetty_rects.append(Rect2(start.x - JETTY_W * 0.5 - 0.15, start.z - 0.3, JETTY_W + 0.3, JETTY_LEN + 0.45))
	var n := int(JETTY_LEN / 1.6)
	for i in n + 1:
		var z := start.z + float(i) * JETTY_LEN / float(n)
		for side: float in [-1.0, 1.0]:
			K.slab(body, Vector3(0.14, 1.1, 0.14), Vector3(start.x + side * (JETTY_W * 0.5 - 0.07), JETTY_Y - 0.45, z), posts, "Post")
	# A low rail on one side and a mooring post with a rope at the end.
	K.slab(body, Vector3(0.08, 0.08, JETTY_LEN), start + Vector3(-JETTY_W * 0.5 + 0.04, JETTY_Y + 0.55, JETTY_LEN * 0.5), posts, "Rail")
	for i in 4:
		K.slab(body, Vector3(0.08, 0.55, 0.08), start + Vector3(-JETTY_W * 0.5 + 0.04, JETTY_Y + 0.28, JETTY_LEN * float(i) / 3.0), posts, "RailPost")
	# Steps down from the shore, and the walking surfaces.
	K.slab(body, Vector3(JETTY_W, 0.2, 0.6), start + Vector3(0, 0.12, -0.3), planks, "Step")
	_collider(body, deck_center + Vector3(0, -0.04, 0), Vector3(JETTY_W, 0.1, JETTY_LEN))
	_collider(body, start + Vector3(0, 0.12, -0.3), Vector3(JETTY_W, 0.24, 0.6))
	# Invisible sides and end, so you stay on the planks.
	for side: float in [-1.0, 1.0]:
		_collider(body, deck_center + Vector3(side * (JETTY_W * 0.5 + 0.1), 1.0, 0), Vector3(0.2, 2.0, JETTY_LEN))
	_collider(body, start + Vector3(0, JETTY_Y + 1.0, JETTY_LEN + 0.1), Vector3(JETTY_W + 0.4, 2.0, 0.2))


## Mr Hruby's boathouse on the far shore: tarred planks, a tin roof, the door ajar, a
## short jetty out from it, a bench, a rod left leaning, the sluice's warning board. Its
## window is dark. Some nights it is not.
func _build_far_shore(shore: Vector3) -> void:
	var K := INTERIOR_KIT
	var root := Node3D.new()
	root.name = "FarShore"
	add_child(root)
	var planks := K.surface("hut_planks", 1.0) if ResourceLoader.exists("res://assets/textury/camp/hut_planks.png") else K.surface("planks_dark", 1.0)
	var grey := K.surface("planks_grey", 1.2)
	var posts := K.surface("planks_dark", 0.6)
	# Ground behind the shore (the forest floor round the boathouse).
	var ground := _flat_mesh(PackedVector2Array([Vector2(shore.x - 9, shore.z - 1), Vector2(shore.x + 9, shore.z - 1), Vector2(shore.x + 9, shore.z + 12), Vector2(shore.x - 9, shore.z + 12)]), 0.04, "FarGround")
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load(SHORE_TEX)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gm.uv1_triplanar = true
	gm.uv1_world_triplanar = true
	gm.uv1_scale = Vector3.ONE / 2.5
	gm.albedo_color = Color(0.7, 0.68, 0.6)
	ground.material_override = gm
	# The jetty: out from the shore toward the camp.
	var jlen := 7.0
	var start := shore + Vector3(0, 0, 1.0)
	K.slab(root, Vector3(JETTY_W, 0.08, jlen), start + Vector3(0, JETTY_Y, -jlen * 0.5), grey, "FarDeck")
	for i in 5:
		var z := start.z - float(i) * jlen / 4.0
		for side: float in [-1.0, 1.0]:
			K.slab(root, Vector3(0.14, 1.1, 0.14), Vector3(start.x + side * (JETTY_W * 0.5 - 0.07), JETTY_Y - 0.45, z), posts, "FarPost")
	far_jetty_end = start + Vector3(0, JETTY_Y, -jlen)
	far_view = start + Vector3(0, JETTY_Y + 1.45, -jlen + 1.4)
	jetty_rects.append(Rect2(start.x - JETTY_W * 0.5 - 0.15, start.z - jlen - 0.15, JETTY_W + 0.3, jlen + 0.3))
	# The boathouse.
	var hut := shore + Vector3(2.6, 0.0, 5.0)
	var w := 3.4
	var d := 3.0
	var h := 2.4
	K.slab(root, Vector3(w, h, 0.12), hut + Vector3(0, h * 0.5, d * 0.5), planks, "HutBack")
	K.slab(root, Vector3(0.12, h, d), hut + Vector3(-w * 0.5, h * 0.5, 0), planks, "HutLeft")
	K.slab(root, Vector3(0.12, h, d), hut + Vector3(w * 0.5, h * 0.5, 0), planks, "HutRight")
	K.slab(root, Vector3(1.1, h, 0.12), hut + Vector3(-w * 0.5 + 0.55, h * 0.5, -d * 0.5), planks, "HutFrontL")
	K.slab(root, Vector3(1.4, h, 0.12), hut + Vector3(w * 0.5 - 0.7, h * 0.5, -d * 0.5), planks, "HutFrontR")
	K.slab(root, Vector3(0.9, 0.3, 0.12), hut + Vector3(-0.15, h - 0.15, -d * 0.5), planks, "HutLintel")
	var roof := K.slab(root, Vector3(w + 0.5, 0.06, d + 0.6), hut + Vector3(0, h + 0.2, 0), K.surface("corrugated_roof", 1.0), "HutRoof")
	roof.rotation_degrees.x = -8.0
	var door := K.slab(root, Vector3(0.9, 2.0, 0.05), hut + Vector3(-0.55, 1.0, -d * 0.5 - 0.3), K.surface("door_wood", 2.0, Color(0.6, 0.6, 0.6)), "HutDoor")
	door.rotation_degrees.y = -55.0
	# Inside it is black; the window beside the door.
	K.slab(root, Vector3(w - 0.3, h - 0.1, 0.05), hut + Vector3(0, h * 0.5, d * 0.5 - 0.1), K.surface("planks_dark", 1.0, Color(0.05, 0.05, 0.05)), "HutDark")
	hut_window_mesh = K.slab(root, Vector3(0.6, 0.5, 0.06), hut + Vector3(1.0, 1.45, -d * 0.5 - 0.02), K.surface("planks_dark", 1.0, Color(0.04, 0.04, 0.05)), "HutWindow")
	hut_window = OmniLight3D.new()
	hut_window.light_color = Color(1.0, 0.75, 0.4)
	hut_window.light_energy = 0.9
	hut_window.omni_range = 4.0
	hut_window.position = hut + Vector3(1.0, 1.45, -d * 0.5 - 0.4)
	hut_window.visible = false
	root.add_child(hut_window)
	K.prop(root, "bench_slatted", shore + Vector3(-1.8, 0.04, 3.2), 90.0)
	K.prop(root, "oil_drum", hut + Vector3(w * 0.5 + 0.5, 0.04, -0.6), 20.0)
	# A fishing rod left leaning on the hut.
	var rod := K.slab(root, Vector3(0.025, 2.6, 0.025), hut + Vector3(-w * 0.5 - 0.25, 1.25, -0.6), posts, "Rod")
	rod.rotation_degrees.z = 14.0
	var board := Label3D.new()
	board.text = "STAVIDLO\nsluice - no entry\nP. Hruby, keeper"
	board.font_size = 26
	board.pixel_size = 0.006
	board.modulate = Color(0.85, 0.82, 0.7)
	board.outline_size = 0
	board.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	board.position = shore + Vector3(-3.4, 1.4, 1.2)
	board.rotation_degrees.y = 180.0
	root.add_child(board)
	K.slab(root, Vector3(1.4, 0.8, 0.05), shore + Vector3(-3.4, 1.4, 1.24), posts, "SluiceBoard")
	K.slab(root, Vector3(0.1, 1.6, 0.1), shore + Vector3(-3.4, 0.8, 1.3), posts, "SluicePost")


## Some nights a lamp burns in the keeper's window. Nobody lives there.
func set_hut_lit(lit: bool) -> void:
	if hut_window != null:
		hut_window.visible = lit
	if hut_window_mesh != null:
		var m := (hut_window_mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.emission_enabled = lit
		m.emission = Color(1.0, 0.7, 0.35)
		m.emission_energy_multiplier = 1.2
		hut_window_mesh.material_override = m


func _reed_clump(at: Vector3, rng: RandomNumberGenerator, tex: Texture2D) -> void:
	for i in rng.randi_range(1, 3):
		var s := Sprite3D.new()
		s.texture = tex
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		var height := rng.randf_range(1.2, 2.0)
		s.pixel_size = height / float(tex.get_height())
		s.offset = Vector2(0, tex.get_height() * 0.5)
		s.flip_h = rng.randf() < 0.5
		s.position = at + Vector3(rng.randf_range(-0.6, 0.6), -0.1, rng.randf_range(-0.6, 0.6))
		add_child(s)


func _flat_mesh(poly: PackedVector2Array, y: float, node_name: String) -> MeshInstance3D:
	var idx := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(0, idx.size(), 3):
		# Wind the triangles so they face up.
		for j in [0, 2, 1]:
			var p: Vector2 = poly[idx[i + j]]
			st.set_uv(p * 0.25)
			st.add_vertex(Vector3(p.x, y, p.y))
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	add_child(mi)
	return mi


## How far out into the shallows the camp shore lets you wade (m).
const WADE := 1.3


## Whether `p` is in the lake's water (your boots: body_world.gd).
func in_water(p: Vector3) -> bool:
	return not _poly_raw.is_empty() and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _poly_raw)


## Where the ducks sit on the camp shore by day: two or three spots off the jetty's sides,
## the same every time for a camp.
func duck_spots() -> Array:
	var out: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = hash("ducks %d" % roundi(_jetty_x * 10.0))
	for i in r.randi_range(2, 3):
		var x := _jetty_x + (r.randf_range(4.0, 11.0) * (1.0 if i % 2 == 0 else -1.0))
		out.append(Vector3(x, 0.0, _shore_z - r.randf_range(0.3, 1.0)))
	return out


func _wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "ShoreWall"
	add_child(body)
	_collider(body, center, size)


func _collider(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = center
	body.add_child(cs)
