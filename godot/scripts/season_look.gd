extends Node3D

## The autumn on the camp (core/systems/season.gd says how far it has gone): the
## birches turn gold, then rust, and lose their leaves; the grass dries and goes grey;
## leaves blow about in the wind; on the last nights it snows and the snow stays on the
## ground and on the tops of the spruces.
##
## World nodes opt in by group (world_generator.gd, cornfield.gd):
##   "season_ground"  MeshInstance3D: its material_override is tinted (grass, then snow);
##                    meta "season_keep_texture" keeps its own picture (road verges)
##   "season_crop"    MeshInstance3D / MultiMeshInstance3D: corn, dries to straw
## Trees read global shader parameters (materials/tree_wind.gdshader): season_leaf_tint,
## season_leaves, season_snow. The snow falls here too: when it is raining and
## Season.precip_is_snow, weather_visuals.gd stops the rain and this lets it snow.

const SEASON = preload("res://core/systems/season.gd")
const REFRESH_SEC := 2.0
## The ground's picture by the stage of the autumn (Grok, tools/artgen): dry grass with
## fallen leaves from AUTUMN_DAY (it changes overnight), snow once it has settled.
const AUTUMN_TEX := "res://assets/textury/world/grass_autumn.png"
const SNOW_TEX := "res://assets/textury/world/snow_ground.png"
const AUTUMN_DAY := 10
const SNOW_SETTLED := 0.2

var day := 1
var hour := 12.0
## Main sets these from the weather: precipitation 0 none, 1 light, 2 steady, 3 storm.
var precip := 0
var wind := Vector2(0.94, 0.34)

var _t := 0.0
var _leaves: GPUParticles3D
var _snow: GPUParticles3D
var _follow: Callable
var _autumn_tex: Texture2D
var _snow_tex: Texture2D


func setup(follow: Callable) -> void:
	_follow = follow
	name = "SeasonLook"
	_autumn_tex = load(AUTUMN_TEX) if ResourceLoader.exists(AUTUMN_TEX) else null
	_snow_tex = load(SNOW_TEX) if ResourceLoader.exists(SNOW_TEX) else null
	_leaves = _make_particles("FallingLeaves", 360, 7.0, Vector3(16, 6, 16), _leaf_mesh())
	_snow = _make_particles("Snowfall", 2600, 8.0, Vector3(20, 9, 20), _flake_mesh())
	apply(true)


func _process(delta: float) -> void:
	_t += delta
	var c: Node3D = _follow.call() if _follow.is_valid() else null
	if c != null:
		_leaves.global_position = c.global_position + Vector3(0, 5.5, 0)
		_snow.global_position = c.global_position + Vector3(0, 8.0, 0)
	if _t >= REFRESH_SEC:
		_t = 0.0
		apply(false)


func is_snowing() -> bool:
	return precip > 0 and SEASON.precip_is_snow(day, hour)


func apply(_force: bool) -> void:
	var leaves := SEASON.leaves_on(day, hour)
	var snow := SEASON.snow_cover(day, hour)
	var tint := SEASON.leaf_tint(day, hour)
	RenderingServer.global_shader_parameter_set("season_leaf_tint", Vector3(tint.r, tint.g, tint.b))
	RenderingServer.global_shader_parameter_set("season_leaves", leaves)
	RenderingServer.global_shader_parameter_set("season_snow", snow)
	var grass := SEASON.grass_tint(day, hour)
	var white := Color(1.55, 1.58, 1.65)
	for n in get_tree().get_nodes_in_group("season_ground"):
		var mi := n as GeometryInstance3D
		if mi == null or not (mi.material_override is BaseMaterial3D):
			continue
		var m := mi.material_override as BaseMaterial3D
		if not mi.has_meta("season_base"):
			mi.set_meta("season_base", m.albedo_color)
			mi.set_meta("season_tex", m.albedo_texture)
		var base: Color = mi.get_meta("season_base")
		var c := Color(base.r * grass.r, base.g * grass.g, base.b * grass.b, base.a)
		var tex: Texture2D = mi.get_meta("season_tex")
		if mi.has_meta("season_keep_texture"):
			c = c.lerp(Color(white.r * base.r, white.g * base.g, white.b * base.b, base.a), snow * 0.85)
		elif snow >= SNOW_SETTLED and _snow_tex != null:
			# The snow picture carries the white; the tint only evens it out.
			tex = _snow_tex
			c = Color(base.r, base.g, base.b, base.a).lerp(Color(1.0, 1.0, 1.0, base.a), 0.5)
		elif day >= AUTUMN_DAY and _autumn_tex != null:
			tex = _autumn_tex
			# The picture is brighter than the summer grass: bring it down, and grey it
			# as October goes on.
			var late := SEASON._smooth(0.6, 0.95, SEASON.progress(day, hour))
			c = Color(base.r * 0.74, base.g * 0.72, base.b * 0.7, base.a).lerp(Color(base.r * 0.6, base.g * 0.6, base.b * 0.62, base.a), late)
		else:
			c = c.lerp(Color(white.r * base.r, white.g * base.g, white.b * base.b, base.a), snow * 0.85)
		if tex != null and m.albedo_texture != tex:
			m.albedo_texture = tex
		m.albedo_color = c
	var straw := Color(1.0, 1.0, 1.0).lerp(Color(1.05, 0.86, 0.62), SEASON._smooth(0.2, 0.7, SEASON.progress(day, hour)))
	for n in get_tree().get_nodes_in_group("season_crop"):
		var gi := n as GeometryInstance3D
		if gi == null or not (gi.material_override is BaseMaterial3D):
			continue
		var m2 := gi.material_override as BaseMaterial3D
		if not gi.has_meta("season_base"):
			gi.set_meta("season_base", m2.albedo_color)
		var b2: Color = gi.get_meta("season_base")
		m2.albedo_color = Color(b2.r * straw.r, b2.g * straw.g, b2.b * straw.b, b2.a).lerp(Color(1.3, 1.32, 1.38), snow * 0.45)
	# Leaves in the air: from the first gold until the trees are bare, more in the wind.
	var turn := SEASON.leaf_turn(day, hour)
	var falling := turn > 0.25 and leaves > 0.04
	_leaves.emitting = falling
	if falling:
		var gust := clampf(wind.length(), 0.15, 1.6)
		_leaves.amount_ratio = clampf((1.0 - absf(leaves - 0.55) * 1.4) * (0.35 + gust * 0.6), 0.1, 1.0)
		var pm := _leaves.process_material as ParticleProcessMaterial
		pm.gravity = Vector3(wind.x * 1.6 * gust, -0.9, wind.y * 1.6 * gust)
		var mat := (_leaves.draw_pass_1 as QuadMesh).material as StandardMaterial3D
		mat.albedo_color = Color(0.86, 0.62, 0.20).lerp(Color(0.62, 0.30, 0.14), clampf((turn - 0.5) * 2.0, 0.0, 1.0))
	var snowing := is_snowing()
	_snow.emitting = snowing
	if snowing:
		_snow.amount_ratio = [0.0, 0.35, 0.7, 1.0][clampi(precip, 0, 3)]
		var pm2 := _snow.process_material as ParticleProcessMaterial
		var blow := 0.6 + (2.5 if precip >= 3 else 0.0)
		pm2.gravity = Vector3(wind.x * blow, -1.4, wind.y * blow)


func _make_particles(n: String, amount: int, life: float, box: Vector3, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, -1.2, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 3.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(-box * 1.6, box * 3.2)
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _leaf_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.08)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.albedo_color = Color(0.86, 0.62, 0.2)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = m
	return q


func _flake_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.032, 0.032)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.albedo_color = Color(0.95, 0.96, 1.0, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	return q
