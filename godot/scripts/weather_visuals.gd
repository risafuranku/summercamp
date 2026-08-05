extends Node
## Weather, sky, celestial bodies, clouds and particles visual system.
## Extrahováno z main.gd. Main inicializuje přes setup() + setup_*() volání.

const SKY_TRANSITION_SHADER = preload("res://materials/sky_transition.gdshader")

# ── Time/Weather state constants (mirror main.gd) ─────────────────────────────
const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const WEATHER_CLEAR: int = 0
const WEATHER_WINDY: int = 1
const WEATHER_FOG: int = 2
const WEATHER_LIGHT_RAIN: int = 3
const WEATHER_RAIN: int = 4
const WEATHER_STORM: int = 5
const WEATHER_EVENT: int = 6

# ── Sky texture paths ──────────────────────────────────────────────────────────
const SKY_TEX_CLEAR_PATHS := ["res://assets/textury/skybox/sky1.png"]
const SKY_TEX_WINDY_PATHS := ["res://assets/textury/skybox/sky1.png"]
const SKY_TEX_FOG_PATHS := [
	"res://assets/textury/skybox/skydusk.png",
	"res://assets/textury/skybox/skyeve.png",
	"res://assets/textury/skybox/sky2.png",
	"res://assets/textury/skybox/RRSKY_02.png"
]
const SKY_TEX_LIGHT_RAIN_PATHS := ["res://assets/textury/skybox/sky3.png"]
const SKY_TEX_RAIN_PATHS := [
	"res://assets/textury/skybox/rrsky4.png",
	"res://assets/textury/skybox/RRSKY_04.png"
]
const SKY_TEX_STORM_PATHS := [
	"res://assets/textury/skybox/RRSKY_05.png",
	"res://assets/textury/skybox/rrsky5.png"
]
const SKY_TEX_EVE_PATHS := [
	"res://assets/textury/skybox/skyeve.png",
	"res://assets/textury/skybox/skydusk.png"
]
const SKY_TEX_DUSK_PATHS := [
	"res://assets/textury/skybox/skydusk.png",
	"res://assets/textury/skybox/skyeve.png"
]
const SKY_TEX_NIGHT_PATHS := ["res://assets/textury/skybox/skynight.png"]
const SKY_TEX_EVENT_PATHS := [
	"res://assets/textury/skybox/skydusk.png",
	"res://assets/textury/skybox/skyeve.png",
	"res://assets/textury/skybox/sky1.png"
]
const SKY_TEX_FALLBACK_PATHS := [
	"res://assets/textury/skybox/sky1.png",
	"res://assets/textury/skybox/skydusk.png",
	"res://assets/textury/skybox/skynight.png"
]

# ── Tunable constants ──────────────────────────────────────────────────────────
const SKY_TRANSITION_DURATION: float = 60.0
const SKY_TRANSITION_DURATION_NIGHT: float = 105.0
const SKY_TRANSITION_STEPS: int = 14
const SKY_PHASE_BLEND_HOURS: float = 0.5
const SKY_PHASE_HALF_BLEND_HOURS: float = SKY_PHASE_BLEND_HOURS * 0.5
const DAY_MID_HOUR: float = 6.5
const EVENING_MID_HOUR: float = 18.0
const DUSK_MID_HOUR: float = 19.0
const DAY_SKY_FADE_START_HOUR: float = DAY_MID_HOUR - SKY_PHASE_HALF_BLEND_HOURS
const EVENING_SKY_FADE_START_HOUR: float = EVENING_MID_HOUR - SKY_PHASE_HALF_BLEND_HOURS
const DUSK_SKY_FADE_START_HOUR: float = DUSK_MID_HOUR - SKY_PHASE_HALF_BLEND_HOURS
const NIGHT_SKY_FADE_START_HOUR: float = 19.5
const DAY_SKY_FADE_END_HOUR: float = DAY_MID_HOUR + SKY_PHASE_HALF_BLEND_HOURS
const NIGHT_SKY_FADE_END_HOUR: float = 21.25
const STAR_FADE_IN_START_HOUR: float = 20.5
const NIGHT_MID_HOUR: float = (NIGHT_SKY_FADE_START_HOUR + NIGHT_SKY_FADE_END_HOUR) * 0.5
const SUNRISE_HOUR: float = 6.5
const SUNSET_HOUR: float = 18.5
const SUN_HORIZON_FADE_START_Y: float = 0.02
const SUN_HORIZON_FADE_END_Y: float = -0.16
const SKY_PHASE_DAY: int = 0
const SKY_PHASE_EVENING: int = 1
const SKY_PHASE_DUSK: int = 2
const SKY_PHASE_NIGHT: int = 3
const STARFIELD_COUNT: int = 10
const CLOUD_LAYER_COUNT: int = 8
const CLOUD_WORLD_HALF_EXTENT: float = 170.0
const CLOUD_ALTITUDE_MIN: float = 24.0
const CLOUD_ALTITUDE_MAX: float = 42.0
const CLOUD_DRIFT_BASE_UNITS_PER_SEC: float = 1.25
const GLOBAL_WORLD_COLOR_DARKEN: float = 0.74
const GLOBAL_WORLD_ENERGY_DARKEN: float = 0.66
const GLOBAL_WORLD_NIGHT_FACTOR_BOOST: float = 0.08
const GLOBAL_WORLD_RETRO_TINT_BOOST: float = 0.04
const GLOBAL_NIGHT_COLOR_DARKEN: float = 0.68
const GLOBAL_NIGHT_AMBIENT_COLOR_DARKEN: float = 0.62
const GLOBAL_NIGHT_FOG_COLOR_DARKEN: float = 0.70
const GLOBAL_NIGHT_SUN_COLOR_DARKEN: float = 0.64
const GLOBAL_NIGHT_AMBIENT_ENERGY_DARKEN: float = 0.78
const GLOBAL_NIGHT_SUN_ENERGY_DARKEN: float = 0.60
const GLOBAL_NIGHT_FACTOR_EXTRA: float = 0.04
const GLOBAL_POST_BARREL_MULTIPLIER: float = 1.95
const GLOBAL_POST_GRAIN_MULTIPLIER: float = 2.40
const SUN_SHADOW_MODE: int = 1
const SUN_SHADOW_SPLIT_1: float = 0.18
const SUN_SHADOW_SPLIT_2: float = 0.42
const SUN_SHADOW_SPLIT_3: float = 0.72
const SUN_SHADOW_MAX_DISTANCE: float = 140.0
const SUN_SHADOW_FADE_START: float = 0.58
const SUN_SHADOW_PANCAKE_SIZE: float = 28.0
const CELESTIAL_PATH_ALTITUDE_FACTOR: float = 0.84
const CELESTIAL_PATH_DEFAULT_HALF_SPAN: float = 56.0
const CELESTIAL_SPRITE_REFERENCE_DISTANCE: float = 36.0
const CELESTIAL_SPRITE_MIN_DISTANCE: float = 96.0
const CELESTIAL_SPRITE_MAP_DISTANCE_FACTOR: float = 2.4
const CELESTIAL_SPRITE_CAMERA_FAR_FACTOR: float = 0.92
const SUN_SPRITE_BASE_SIZE: float = 4.4
const MOON_SPRITE_BASE_SIZE: float = 3.8
const SUN_GLOW_BASE_SIZE: float = 8.6
const SUN_FLARE_BASE_SIZE: float = 5.4

# ── Injected references (set via setup()) ─────────────────────────────────────
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _world_3d: Node3D
var _psx_post_mat: ShaderMaterial
var _player_getter: Callable
var _fallback_cam: Camera3D
var _audio_mgr: Node
var _grid_mgr: Node

# ── Runtime state (aktualizuje main každý frame přes update_state()) ───────────
var _time_state: int = TIME_DAY
var _time_of_day_hours: float = 9.0
var _weather_state: int = WEATHER_CLEAR

# ── Celestial nodes ────────────────────────────────────────────────────────────
var _celestial_root: Node3D
var _sun_sprite_3d: MeshInstance3D
var _moon_sprite_3d: MeshInstance3D
var _sun_glow_sprite_3d: MeshInstance3D
var _sun_flare_sprite_3d: MeshInstance3D
var _star_sprites: Array = []
var _star_directions: Array = []
var _star_twinkle_phases: Array = []
var _star_alpha_variation: Array = []
var _cloud_sprites: Array = []
var _cloud_world_positions: Array = []
var _cloud_world_drift_vectors: Array = []
var _cloud_phase_offsets: Array = []
var _cloud_speed_jitter: Array = []
var _cloud_alpha_jitter: Array = []
var _cloud_presence_threshold: Array = []
var _cloud_world_center: Vector3 = Vector3.ZERO
var _sun_direction_to_source: Vector3 = Vector3(0.0, 1.0, 0.0)
var _moon_direction_to_source: Vector3 = Vector3(0.0, -1.0, 0.0)
var _sky_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sky_anim_time: float = 0.0

# ── Cloud targets ──────────────────────────────────────────────────────────────
var _cloud_density_target: float = 0.24
var _cloud_density_current: float = 0.24
var _cloud_alpha_target: float = 0.26
var _cloud_alpha_current: float = 0.26
var _cloud_speed_target: float = 0.20
var _cloud_speed_current: float = 0.20

# ── Cached base env values (před weather override) ────────────────────────────
var _base_sun_energy: float = 1.0
var _base_ambient_energy: float = 1.0
var _base_fog_enabled: bool = false
var _base_fog_density: float = 0.004
var _base_fog_sky_affect: float = 0.10
var _base_fog_light_color: Color = Color(0.76, 0.84, 0.90)
var _base_vhs_grain_strength: float = 0.006
var _base_horror_vignette_strength: float = 0.0
var _storm_flash_strength: float = 0.0
var _storm_flash_cooldown: float = 0.0

# ── Sky texture cache / transition ─────────────────────────────────────────────
var _sky_texture_cache: Dictionary = {}
var _active_sky_texture_path: String = ""
var _sky_display_texture: Texture2D
var _sky_transition_from_texture: Texture2D
var _sky_transition_to_texture: Texture2D
var _sky_transition_progress: float = 1.0
var _sky_transition_last_step: int = -1
var _sky_transition_active: bool = false
var _sky_transition_material: ShaderMaterial
var _sky_transition_duration_seconds: float = SKY_TRANSITION_DURATION
var _rain_particles: GPUParticles3D


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(
	world_env: WorldEnvironment,
	sun_light: DirectionalLight3D,
	world_3d: Node3D,
	_psx_post_mat_unused: ShaderMaterial,
	player_getter: Callable,
	fallback_cam: Camera3D,
	audio_mgr: Node,
	grid_mgr: Node
) -> void:
	_world_env = world_env
	_sun = sun_light
	_world_3d = world_3d
	_psx_post_mat = null
	_player_getter = player_getter
	_fallback_cam = fallback_cam
	_audio_mgr = audio_mgr
	_grid_mgr = grid_mgr


## PSX post-process je dočasně vypnutý (no-op).
## Pokud je na containeru starý materiál, explicitně ho odstraníme.
func setup_psx_post_process(container: SubViewportContainer) -> void:
	_psx_post_mat = null
	if container != null:
		container.material = null


func setup_static_lighting() -> void:
	if _world_env.environment == null:
		_world_env.environment = Environment.new()
	var env = _world_env.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.66, 0.78, 0.90)
	_try_apply_skybox(env)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.80)
	env.ambient_light_energy = 1.24
	env.fog_enabled = false
	env.fog_light_color = Color(0.66, 0.74, 0.82)
	env.fog_density = 0.005
	env.fog_sky_affect = 0.12
	env.volumetric_fog_enabled = false
	_sun.light_energy = 1.18
	_sun.light_color = Color(1.0, 0.95, 0.80)
	_sun.shadow_enabled = true
	_apply_sun_shadow_profile()


func setup_celestial_bodies() -> void:
	if _celestial_root != null and is_instance_valid(_celestial_root):
		return
	_celestial_root = Node3D.new()
	_celestial_root.name = "CelestialBodies"
	_world_3d.add_child(_celestial_root)
	_sky_rng.randomize()
	_sun_sprite_3d = _create_pixel_celestial_sprite("PixelSun", _create_pixel_sun_texture(), SUN_SPRITE_BASE_SIZE, 8)
	_moon_sprite_3d = _create_pixel_celestial_sprite("PixelMoon", _create_pixel_moon_texture(), MOON_SPRITE_BASE_SIZE, 8)
	_sun_glow_sprite_3d = _create_pixel_celestial_sprite("PixelSunGlow", _create_pixel_sun_glow_texture(), SUN_GLOW_BASE_SIZE, 2)
	_sun_flare_sprite_3d = _create_pixel_celestial_sprite("PixelSunFlare", _create_pixel_sun_flare_texture(), SUN_FLARE_BASE_SIZE, 2)
	_celestial_root.add_child(_sun_sprite_3d)
	_celestial_root.add_child(_moon_sprite_3d)
	_celestial_root.add_child(_sun_glow_sprite_3d)
	_celestial_root.add_child(_sun_flare_sprite_3d)
	_sun_sprite_3d.visible = true
	_moon_sprite_3d.visible = false
	_sun_glow_sprite_3d.visible = false
	_sun_flare_sprite_3d.visible = false
	_setup_star_field()
	_setup_cloud_layers()
	set_cloud_targets_from_weather()
	_cloud_density_current = _cloud_density_target
	_cloud_alpha_current = _cloud_alpha_target
	_cloud_speed_current = _cloud_speed_target


func setup_weather_particles() -> void:
	if _world_3d.has_node("RainParticles"):
		_rain_particles = _world_3d.get_node("RainParticles")
		return
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "RainParticles"
	_world_3d.add_child(_rain_particles)
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(20.0, 10.0, 20.0)
	process_mat.direction = Vector3(0.0, -1.0, 0.0)
	process_mat.spread = 0.0
	process_mat.gravity = Vector3(0.0, 0.0, 0.0)
	process_mat.initial_velocity_min = 20.0
	process_mat.initial_velocity_max = 24.0
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.035, 0.52)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.albedo_color = Color(0.84, 0.88, 0.92, 0.24)
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = false
	mesh.material = mat
	_rain_particles.process_material = process_mat
	_rain_particles.draw_pass_1 = mesh
	_rain_particles.amount = 4000
	_rain_particles.lifetime = 1.6
	_rain_particles.visibility_aabb = AABB(Vector3(-30, -15, -30), Vector3(60, 30, 60))
	_rain_particles.emitting = false
	_rain_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — volá main každý frame nebo při změně stavu
# ═══════════════════════════════════════════════════════════════════════════════

## Uloží aktuální env/sun hodnoty jako base pro weather overlay.
## Volat z main po nastavení env/sun (uvnitř _apply_time_from_clock).
func cache_base_weather_values() -> void:
	var env = _world_env.environment
	if env == null:
		return
	_base_sun_energy = _sun.light_energy
	_base_ambient_energy = env.ambient_light_energy
	_base_fog_enabled = env.fog_enabled
	_base_fog_density = env.fog_density
	_base_fog_sky_affect = env.fog_sky_affect
	_base_fog_light_color = env.fog_light_color
	if _psx_post_mat != null:
		_base_vhs_grain_strength = float(_psx_post_mat.get_shader_parameter("vhs_grain_strength"))
		_base_horror_vignette_strength = float(_psx_post_mat.get_shader_parameter("horror_vignette_strength"))


## Aktualizuje runtime stav + přepočítá směry slunce/měsíce.
## Volat z main každý frame PŘED update_sky_runtime / update_celestial_bodies.
func update_state(time_state: int, hours: float, weather: int) -> void:
	_time_state = time_state
	_time_of_day_hours = hours
	_weather_state = weather
	_sun_direction_to_source = direction_to_source_from_hour(hours)
	_moon_direction_to_source = direction_to_source_from_hour(hours - 12.0)


## Animace oblohy, pohyb mraků, sky transition, particles. Volat z main _process.
func update_sky_runtime(delta: float) -> void:
	if delta <= 0.0:
		return
	_sky_anim_time += delta
	_update_sky_transition(delta)
	_cloud_density_current = move_toward(_cloud_density_current, _cloud_density_target, delta * 0.36)
	_cloud_alpha_current = move_toward(_cloud_alpha_current, _cloud_alpha_target, delta * 0.42)
	_cloud_speed_current = move_toward(_cloud_speed_current, _cloud_speed_target, delta * 0.55)
	_update_cloud_world_motion(delta)
	_update_weather_particles(delta)


## Pozice slunce, měsíce, hvězd, mraků. Volat z main _process.
func update_celestial_bodies() -> void:
	if _sun_sprite_3d == null or _moon_sprite_3d == null:
		return
	var cam = _get_active_world_camera()
	if cam == null:
		return
	var cam_pos = cam.global_position
	var sun_dir = _sun_direction_to_source.normalized()
	if sun_dir.length_squared() < 0.001:
		sun_dir = Vector3(0.0, 1.0, 0.0)
	var moon_dir = _moon_direction_to_source.normalized()
	if moon_dir.length_squared() < 0.001:
		moon_dir = direction_to_source_from_hour(_time_of_day_hours - 12.0)
	var sky_distance = _resolve_celestial_sprite_distance(cam.far)
	var sprite_scale = sky_distance / CELESTIAL_SPRITE_REFERENCE_DISTANCE
	_sun_sprite_3d.global_position = cam_pos + sun_dir * sky_distance
	_moon_sprite_3d.global_position = cam_pos + moon_dir * sky_distance
	_sun_sprite_3d.look_at(cam_pos, Vector3.UP)
	_moon_sprite_3d.look_at(cam_pos, Vector3.UP)
	_set_sprite_size(_sun_sprite_3d, SUN_SPRITE_BASE_SIZE * sprite_scale)
	_set_sprite_size(_moon_sprite_3d, MOON_SPRITE_BASE_SIZE * sprite_scale)
	var sun_horizon_visibility = _sun_horizon_visibility(sun_dir.y)
	var moon_above_horizon = moon_dir.y > -0.03
	var sky_phase = _current_sky_phase()
	var sun_alpha = sun_horizon_visibility
	if sky_phase == SKY_PHASE_NIGHT:
		sun_alpha = 0.0
	_sun_sprite_3d.visible = sun_alpha > 0.01
	_set_sprite_tint(_sun_sprite_3d, Color(1.0, 1.0, 1.0), sun_alpha)
	# Měsíc: postupný fade přes celé okno rozbřesku místo binárního přepínání
	var h_now = _normalized_hour(_time_of_day_hours)
	var moon_alpha: float
	if h_now >= NIGHT_SKY_FADE_END_HOUR or h_now <= DAY_SKY_FADE_START_HOUR:
		moon_alpha = 1.0
	elif h_now > DAY_SKY_FADE_START_HOUR and h_now <= DAY_SKY_FADE_END_HOUR:
		moon_alpha = 1.0 - (h_now - DAY_SKY_FADE_START_HOUR) / max(DAY_SKY_FADE_END_HOUR - DAY_SKY_FADE_START_HOUR, 0.001)
	elif h_now >= NIGHT_SKY_FADE_START_HOUR and h_now < NIGHT_SKY_FADE_END_HOUR:
		moon_alpha = (h_now - NIGHT_SKY_FADE_START_HOUR) / max(NIGHT_SKY_FADE_END_HOUR - NIGHT_SKY_FADE_START_HOUR, 0.001)
	else:
		moon_alpha = 0.0
	_moon_sprite_3d.visible = moon_above_horizon and (moon_alpha > 0.001)
	if moon_above_horizon:
		_set_sprite_tint(_moon_sprite_3d, Color(1.0, 1.0, 1.0), moon_alpha)
	_update_sun_flare(cam, cam_pos, sun_dir, sky_distance)
	_update_star_field(cam_pos, sky_distance * 0.98)
	_update_cloud_layers(cam_pos)


## Storm flash efekt. Volat z main _process.
func update_weather_runtime(delta: float) -> void:
	if _weather_state != WEATHER_STORM:
		if _storm_flash_strength > 0.0 or _storm_flash_cooldown > 0.0:
			_storm_flash_strength = 0.0
			_storm_flash_cooldown = 0.0
			apply_weather_profile()
		return
	var should_refresh = false
	var synced_flash = 0.0
	var has_audio_flash_sync = false
	if _audio_mgr != null and _audio_mgr.has_method("consume_storm_flash_strength"):
		has_audio_flash_sync = true
		synced_flash = float(_audio_mgr.consume_storm_flash_strength())
	if synced_flash > 0.0:
		var boosted = max(_storm_flash_strength, synced_flash)
		if not is_equal_approx(boosted, _storm_flash_strength):
			_storm_flash_strength = boosted
			should_refresh = true
	if _storm_flash_strength > 0.0:
		var next_strength = max(_storm_flash_strength - (delta * 3.2), 0.0)
		if not is_equal_approx(next_strength, _storm_flash_strength):
			_storm_flash_strength = next_strength
			should_refresh = true
	if not has_audio_flash_sync:
		_storm_flash_cooldown -= delta
		if _storm_flash_cooldown <= 0.0:
			_storm_flash_strength = randf_range(0.40, 0.85)
			_storm_flash_cooldown = randf_range(2.4, 5.0)
			should_refresh = true
	if should_refresh:
		apply_weather_profile()


## Kombinovaný per-frame visual update. Volat z main._process() po update_state().
func update_frame(delta: float) -> void:
	# Drive time/light profile every frame so color and energy transitions stay fully continuous.
	apply_time_from_clock(false)
	update_sky_runtime(delta)
	update_celestial_bodies()
	update_weather_runtime(delta)


## Weather vizuální overlay (fog, sky darkening, grain, sun mult).
## Volat z main po cache_base_weather_values().
func apply_weather_profile(force_sky_snap: bool = false) -> void:
	var env = _world_env.environment
	if env == null:
		return
	_apply_weather_skybox(force_sky_snap)
	set_cloud_targets_from_weather()

	var fog_enabled = _base_fog_enabled
	var fog_density = _base_fog_density
	var fog_sky_affect = _base_fog_sky_affect
	var fog_color = _base_fog_light_color
	var sun_multiplier = 1.0
	var ambient_multiplier = 1.0
	var sky_desaturation = 0.0
	var sky_darkening = 0.0
	var grain_boost = 0.0
	var vignette_boost = 0.0

	match _weather_state:
		WEATHER_WINDY:
			fog_enabled = true
			fog_density = max(_base_fog_density, 0.0065)
			fog_sky_affect = max(_base_fog_sky_affect, 0.12)
			fog_color = _weather_fog_color(0.16)
			sun_multiplier = 0.90; ambient_multiplier = 0.88
			sky_desaturation = 0.14; sky_darkening = 0.10; grain_boost = 0.0007
		WEATHER_FOG:
			fog_enabled = true
			fog_density = max(_base_fog_density, 0.016)
			fog_sky_affect = max(_base_fog_sky_affect, 0.28)
			fog_color = _weather_fog_color(0.54)
			sun_multiplier = 0.70; ambient_multiplier = 0.84
			sky_desaturation = 0.34; sky_darkening = 0.22; grain_boost = 0.0012
		WEATHER_LIGHT_RAIN:
			fog_enabled = true
			fog_density = max(_base_fog_density, 0.015)
			fog_sky_affect = max(_base_fog_sky_affect, 0.22)
			fog_color = _weather_fog_color(0.68)
			sun_multiplier = 0.56; ambient_multiplier = 0.72
			sky_desaturation = 0.46; sky_darkening = 0.34; grain_boost = 0.0023
		WEATHER_RAIN:
			fog_enabled = true
			fog_density = max(_base_fog_density, 0.026)
			fog_sky_affect = max(_base_fog_sky_affect, 0.32)
			fog_color = _weather_fog_color(0.84)
			sun_multiplier = 0.34; ambient_multiplier = 0.54
			sky_desaturation = 0.68; sky_darkening = 0.56
			grain_boost = 0.0054; vignette_boost = 0.015
		WEATHER_STORM:
			fog_enabled = true
			fog_density = max(_base_fog_density, 0.036)
			fog_sky_affect = max(_base_fog_sky_affect, 0.40)
			fog_color = _weather_fog_color(0.93)
			sun_multiplier = 0.18; ambient_multiplier = 0.34
			sky_desaturation = 0.88; sky_darkening = 0.72
			grain_boost = 0.0076; vignette_boost = 0.055
		_:
			pass

	var sky_phase = _current_sky_phase()
	if sky_phase == SKY_PHASE_DUSK:
		ambient_multiplier *= 0.88
		sky_darkening = min(0.92, sky_darkening + 0.08)
	if sky_phase == SKY_PHASE_NIGHT:
		sun_multiplier *= 0.58; ambient_multiplier *= 0.52
		sky_darkening = min(0.94, sky_darkening + 0.18)
		sky_desaturation = min(1.0, sky_desaturation + 0.10)
		fog_sky_affect = min(fog_sky_affect, 0.14)
		match _weather_state:
			WEATHER_LIGHT_RAIN:
				ambient_multiplier *= 0.90
				sky_darkening = min(0.95, sky_darkening + 0.06)
				fog_sky_affect = min(fog_sky_affect, 0.12)
			WEATHER_RAIN:
				ambient_multiplier *= 0.82; sun_multiplier *= 0.88
				sky_darkening = min(0.96, sky_darkening + 0.10)
				fog_sky_affect = min(fog_sky_affect, 0.11)
			WEATHER_STORM:
				ambient_multiplier *= 0.74; sun_multiplier *= 0.78
				sky_darkening = min(0.97, sky_darkening + 0.14)
				fog_density = max(fog_density, 0.042)
				fog_sky_affect = min(fog_sky_affect, 0.10)
				vignette_boost += 0.06
			_:
				pass

	var flash = _storm_flash_strength if _weather_state == WEATHER_STORM else 0.0
	var base_profile = sample_time_profile(_time_of_day_hours)
	var sky_color: Color = base_profile["sky_color"]
	var sky_luma = (sky_color.r * 0.2126) + (sky_color.g * 0.7152) + (sky_color.b * 0.0722)
	var sky_gray = Color(sky_luma, sky_luma, sky_luma, sky_color.a)
	var weather_sky = sky_color.lerp(sky_gray, clampf(sky_desaturation, 0.0, 1.0))
	var dark_target = Color(0.06, 0.07, 0.09, sky_color.a)
	if sky_phase == SKY_PHASE_NIGHT:
		dark_target = Color(0.035, 0.042, 0.060, sky_color.a)
	weather_sky = weather_sky.lerp(dark_target, clampf(sky_darkening, 0.0, 0.999))
	env.background_color = weather_sky
	var ambient_col: Color = base_profile["ambient_color"]
	var ambient_luma = (ambient_col.r * 0.2126) + (ambient_col.g * 0.7152) + (ambient_col.b * 0.0722)
	var ambient_gray = Color(ambient_luma, ambient_luma, ambient_luma, ambient_col.a)
	env.ambient_light_color = ambient_col.lerp(ambient_gray, clampf(sky_desaturation * 0.75, 0.0, 1.0))
	env.fog_enabled = fog_enabled
	env.fog_density = fog_density
	env.fog_sky_affect = fog_sky_affect
	env.fog_light_color = fog_color.lerp(Color(0.90, 0.92, 1.0), flash * 0.85)
	_sun.light_energy = (_base_sun_energy * sun_multiplier) + (0.9 * flash)
	env.ambient_light_energy = (_base_ambient_energy * ambient_multiplier) + (0.35 * flash)
	if _psx_post_mat != null:
		_psx_post_mat.set_shader_parameter("vhs_grain_strength", _base_vhs_grain_strength + grain_boost + (0.003 * flash))
		_psx_post_mat.set_shader_parameter("horror_vignette_strength", _base_horror_vignette_strength + vignette_boost + (0.03 * flash))


func set_cloud_targets_from_weather() -> void:
	match _weather_state:
		WEATHER_WINDY:
			_cloud_density_target = 0.52; _cloud_alpha_target = 0.40; _cloud_speed_target = 0.64
		WEATHER_FOG:
			_cloud_density_target = 0.56; _cloud_alpha_target = 0.48; _cloud_speed_target = 0.14
		WEATHER_LIGHT_RAIN:
			_cloud_density_target = 0.66; _cloud_alpha_target = 0.50; _cloud_speed_target = 0.34
		WEATHER_RAIN:
			_cloud_density_target = 0.94; _cloud_alpha_target = 0.72; _cloud_speed_target = 0.60
		WEATHER_STORM:
			_cloud_density_target = 1.00; _cloud_alpha_target = 0.86; _cloud_speed_target = 0.82
		_:
			_cloud_density_target = 0.20; _cloud_alpha_target = 0.22; _cloud_speed_target = 0.22


## Vrací faktor 0..1 jak moc je vidět denní světlo (pro interiory).
func compute_daylight_factor() -> float:
	var sun_height_factor = clampf((_sun_direction_to_source.y + 0.08) / 1.08, 0.0, 1.0)
	var sun_energy_factor = clampf(_sun.light_energy / 1.70, 0.0, 1.0)
	var weather_factor = 1.0
	match _weather_state:
		WEATHER_WINDY: weather_factor = 0.92
		WEATHER_FOG: weather_factor = 0.82
		WEATHER_LIGHT_RAIN: weather_factor = 0.72
		WEATHER_RAIN: weather_factor = 0.58
		WEATHER_STORM: weather_factor = 0.40
		_: weather_factor = 1.0
	return clampf(((sun_height_factor * 0.70) + (sun_energy_factor * 0.30)) * weather_factor, 0.0, 1.0)


## Aplikuje time profile na environment, sun a PSX post materiál.
## Přesunuto z main._apply_time_from_clock(). Volat po update_state().
func apply_time_from_clock(force_sky_snap: bool = false) -> void:
	if _world_env == null:
		return
	var env = _world_env.environment
	if env == null:
		return
	var profile = sample_time_profile(_time_of_day_hours)
	if profile.is_empty():
		return
	var sky_color: Color = profile["sky_color"]
	var ambient_color: Color = profile["ambient_color"]
	var ambient_energy: float = profile["ambient_energy"]
	var fog_color: Color = profile["fog_color"]
	var fog_density: float = profile["fog_density"]
	var fog_sky_affect: float = profile["fog_sky_affect"]
	var sun_color: Color = profile["sun_color"]
	var sun_energy: float = profile["sun_energy"]
	var night_factor: float = profile["night_factor"]
	var retro_tint: Vector3 = profile["retro_tint"]
	var retro_tint_strength: float = profile["retro_tint_strength"]
	var grain_strength: float = profile["grain_strength"]
	var dither_strength: float = profile["dither_strength"]
	var barrel_distortion: float = profile["barrel_distortion"]
	env.background_color = sky_color
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.fog_enabled = fog_density > 0.0001
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = fog_sky_affect
	if _sun != null:
		var sun_source_dir = direction_to_source_from_hour(_time_of_day_hours)
		var sun_height = sun_source_dir.y
		var light_forward = -sun_source_dir
		var look_up = Vector3.UP
		if abs(light_forward.dot(look_up)) > 0.98:
			look_up = Vector3.FORWARD
		_sun.look_at(_sun.global_position + light_forward, look_up)
		_sun.light_energy = sun_energy
		_sun.light_color = sun_color
		var h = _normalized_hour(_time_of_day_hours)
		var shadows_time_window = _is_hour_in_window(h, DAY_SKY_FADE_START_HOUR, NIGHT_SKY_FADE_START_HOUR)
		_sun.shadow_enabled = shadows_time_window and (sun_height > -0.20)
	if _psx_post_mat != null:
		_psx_post_mat.set_shader_parameter("night_factor", night_factor)
		_psx_post_mat.set_shader_parameter("virtual_height", lerpf(132.0, 164.0, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("pixel_size", 1.0)
		_psx_post_mat.set_shader_parameter("color_steps", lerpf(3.2, 4.4, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("dither_strength", dither_strength * 1.45)
		_psx_post_mat.set_shader_parameter("scanline_strength", lerpf(0.075, 0.055, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("vhs_jitter_strength", lerpf(0.085, 0.050, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("vhs_grain_strength", (grain_strength * GLOBAL_POST_GRAIN_MULTIPLIER) + 0.004)
		_psx_post_mat.set_shader_parameter("vignette_strength", lerpf(0.11, 0.065, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("upscale_softness", lerpf(0.04, 0.02, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("contrast_strength", lerpf(0.88, 0.93, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("retro_tint", retro_tint)
		_psx_post_mat.set_shader_parameter("retro_tint_strength", retro_tint_strength)
		_psx_post_mat.set_shader_parameter("night_black_lift", lerpf(0.006, 0.0, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("texel_space_quantize", lerpf(0.70, 0.54, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("ordered_dither_strength", lerpf(0.080, 0.060, 1.0 - night_factor))
		_psx_post_mat.set_shader_parameter("dot_matrix_strength", 0.0)
		_psx_post_mat.set_shader_parameter("horror_vignette_strength", 0.02 + (night_factor * 0.06))
		_psx_post_mat.set_shader_parameter("barrel_distortion", barrel_distortion * GLOBAL_POST_BARREL_MULTIPLIER)
	cache_base_weather_values()
	apply_weather_profile(force_sky_snap)


## Vrací dict s barvami/energiemi pro danou hodinu.
## Public — main volá z _apply_time_from_clock, interně i apply_weather_profile.
func sample_time_profile(hour: float) -> Dictionary:
	var h = _normalized_hour(hour)

	var night_profile = _make_time_profile(
		Color(0.090, 0.110, 0.170),
		Color(0.160, 0.176, 0.224),
		0.42,
		Color(0.170, 0.188, 0.240),
		0.0108,
		0.22,
		Color(0.44, 0.50, 0.62),
		0.12,
		0.74,
		Vector3(0.78, 0.84, 0.96),
		0.12,
		0.0102,
		0.058,
		0.074
	)
	var dawn_profile = _make_time_profile(
		Color(0.52, 0.62, 0.70),
		Color(0.52, 0.55, 0.58),
		0.62,
		Color(0.66, 0.70, 0.73),
		0.0130,
		0.34,
		Color(1.0, 0.78, 0.58),
		0.74,
		0.50,
		Vector3(0.94, 0.91, 0.85),
		0.10,
		0.0096,
		0.050,
		0.072
	)
	var hot_day_profile = _make_time_profile(
		Color(0.54, 0.79, 0.95),
		Color(0.86, 0.83, 0.69),
		2.30,
		Color(0.90, 0.88, 0.74),
		0.0026,
		0.05,
		Color(1.0, 0.97, 0.78),
		2.85,
		0.03,
		Vector3(1.0, 0.98, 0.90),
		0.02,
		0.0050,
		0.034,
		0.054
	)
	var late_day_profile = _make_time_profile(
		Color(0.78, 0.70, 0.52),
		Color(0.84, 0.72, 0.54),
		1.55,
		Color(0.88, 0.72, 0.56),
		0.0048,
		0.11,
		Color(1.0, 0.84, 0.56),
		1.58,
		0.10,
		Vector3(1.0, 0.93, 0.76),
		0.06,
		0.0064,
		0.040,
		0.062
	)
	var evening_profile = _make_time_profile(
		Color(0.94, 0.44, 0.22),
		Color(0.55, 0.35, 0.29),
		0.80,
		Color(0.78, 0.44, 0.30),
		0.0078,
		0.20,
		Color(1.0, 0.54, 0.30),
		0.58,
		0.34,
		Vector3(1.0, 0.82, 0.70),
		0.12,
		0.0082,
		0.048,
		0.071
	)
	var dusk_profile = _make_time_profile(
		Color(0.58, 0.14, 0.20),
		Color(0.28, 0.18, 0.24),
		0.34,
		Color(0.44, 0.16, 0.20),
		0.0116,
		0.26,
		Color(0.95, 0.30, 0.24),
		0.10,
		0.72,
		Vector3(0.96, 0.72, 0.76),
		0.16,
		0.0108,
		0.058,
		0.078
	)

	var profile = night_profile
	if h < DAY_SKY_FADE_START_HOUR:
		profile = night_profile
	elif h < DAY_SKY_FADE_END_HOUR:
		var t_day = (h - DAY_SKY_FADE_START_HOUR) / SKY_PHASE_BLEND_HOURS
		profile = _lerp_time_profile(night_profile, dawn_profile, t_day)
	elif h < 10.5:
		var t_morning = (h - DAY_SKY_FADE_END_HOUR) / max(10.5 - DAY_SKY_FADE_END_HOUR, 0.001)
		profile = _lerp_time_profile(dawn_profile, hot_day_profile, t_morning)
	elif h < 16.0:
		var t_day_heat = (h - 10.5) / max(16.0 - 10.5, 0.001)
		profile = _lerp_time_profile(hot_day_profile, late_day_profile, t_day_heat)
	elif h < EVENING_SKY_FADE_START_HOUR:
		# Keep late-day stable until evening transition start.
		# Avoids a visible brightness reset exactly at EVENING_SKY_FADE_START_HOUR.
		profile = late_day_profile
	elif h < (EVENING_MID_HOUR + SKY_PHASE_HALF_BLEND_HOURS):
		var t_evening = (h - EVENING_SKY_FADE_START_HOUR) / SKY_PHASE_BLEND_HOURS
		profile = _lerp_time_profile(late_day_profile, evening_profile, t_evening)
	elif h < DUSK_SKY_FADE_START_HOUR:
		profile = evening_profile
	elif h < (DUSK_MID_HOUR + SKY_PHASE_HALF_BLEND_HOURS):
		var t_dusk = (h - DUSK_SKY_FADE_START_HOUR) / SKY_PHASE_BLEND_HOURS
		profile = _lerp_time_profile(evening_profile, dusk_profile, t_dusk)
	elif h < NIGHT_SKY_FADE_START_HOUR:
		profile = dusk_profile
	elif h < NIGHT_SKY_FADE_END_HOUR:
		var t_night = (h - NIGHT_SKY_FADE_START_HOUR) / max(NIGHT_SKY_FADE_END_HOUR - NIGHT_SKY_FADE_START_HOUR, 0.001)
		profile = _lerp_time_profile(dusk_profile, night_profile, t_night)
	else:
		profile = night_profile

	var sky_color: Color = profile["sky_color"]
	var ambient_color: Color = profile["ambient_color"]
	var ambient_energy: float = profile["ambient_energy"]
	var fog_color: Color = profile["fog_color"]
	var fog_density: float = profile["fog_density"]
	var fog_sky_affect: float = profile["fog_sky_affect"]
	var sun_color: Color = profile["sun_color"]
	var sun_energy: float = profile["sun_energy"]
	var night_factor: float = profile["night_factor"]
	var retro_tint: Vector3 = profile["retro_tint"]
	var retro_tint_strength: float = profile["retro_tint_strength"]
	var grain_strength: float = profile["grain_strength"]
	var dither_strength: float = profile["dither_strength"]
	var barrel_distortion: float = profile["barrel_distortion"]

	sky_color = _scale_color_rgb(sky_color, GLOBAL_WORLD_COLOR_DARKEN)
	ambient_color = _scale_color_rgb(ambient_color, GLOBAL_WORLD_COLOR_DARKEN)
	fog_color = _scale_color_rgb(fog_color, GLOBAL_WORLD_COLOR_DARKEN)
	sun_color = _scale_color_rgb(sun_color, GLOBAL_WORLD_COLOR_DARKEN)
	ambient_energy *= GLOBAL_WORLD_ENERGY_DARKEN
	sun_energy *= GLOBAL_WORLD_ENERGY_DARKEN
	night_factor = clampf(night_factor + GLOBAL_WORLD_NIGHT_FACTOR_BOOST, 0.0, 1.0)
	retro_tint_strength = clampf(retro_tint_strength + GLOBAL_WORLD_RETRO_TINT_BOOST, 0.0, 0.30)

	var night_overlay = _night_overlay_factor(h)
	if night_overlay > 0.0001:
		sky_color = _scale_color_rgb(sky_color, lerpf(1.0, GLOBAL_NIGHT_COLOR_DARKEN, night_overlay))
		ambient_color = _scale_color_rgb(ambient_color, lerpf(1.0, GLOBAL_NIGHT_AMBIENT_COLOR_DARKEN, night_overlay))
		fog_color = _scale_color_rgb(fog_color, lerpf(1.0, GLOBAL_NIGHT_FOG_COLOR_DARKEN, night_overlay))
		sun_color = _scale_color_rgb(sun_color, lerpf(1.0, GLOBAL_NIGHT_SUN_COLOR_DARKEN, night_overlay))
		ambient_energy *= lerpf(1.0, GLOBAL_NIGHT_AMBIENT_ENERGY_DARKEN, night_overlay)
		sun_energy *= lerpf(1.0, GLOBAL_NIGHT_SUN_ENERGY_DARKEN, night_overlay)
		night_factor = clampf(night_factor + (GLOBAL_NIGHT_FACTOR_EXTRA * night_overlay), 0.0, 1.0)
		retro_tint_strength = clampf(retro_tint_strength + (0.06 * night_overlay), 0.0, 0.36)

	return _make_time_profile(
		sky_color,
		ambient_color,
		ambient_energy,
		fog_color,
		fog_density,
		fog_sky_affect,
		sun_color,
		sun_energy,
		night_factor,
		retro_tint,
		retro_tint_strength,
		grain_strength,
		dither_strength,
		barrel_distortion
	)


func _make_time_profile(
	sky_color: Color,
	ambient_color: Color,
	ambient_energy: float,
	fog_color: Color,
	fog_density: float,
	fog_sky_affect: float,
	sun_color: Color,
	sun_energy: float,
	night_factor: float,
	retro_tint: Vector3,
	retro_tint_strength: float,
	grain_strength: float,
	dither_strength: float,
	barrel_distortion: float
) -> Dictionary:
	return {
		"sky_color": sky_color,
		"ambient_color": ambient_color,
		"ambient_energy": ambient_energy,
		"fog_color": fog_color,
		"fog_density": fog_density,
		"fog_sky_affect": fog_sky_affect,
		"sun_color": sun_color,
		"sun_energy": sun_energy,
		"night_factor": night_factor,
		"retro_tint": retro_tint,
		"retro_tint_strength": retro_tint_strength,
		"grain_strength": grain_strength,
		"dither_strength": dither_strength,
		"barrel_distortion": barrel_distortion,
	}


func _lerp_time_profile(from_profile: Dictionary, to_profile: Dictionary, t: float) -> Dictionary:
	var blend = clampf(t, 0.0, 1.0)
	var from_sky: Color = from_profile["sky_color"]
	var to_sky: Color = to_profile["sky_color"]
	var from_ambient: Color = from_profile["ambient_color"]
	var to_ambient: Color = to_profile["ambient_color"]
	var from_fog: Color = from_profile["fog_color"]
	var to_fog: Color = to_profile["fog_color"]
	var from_sun: Color = from_profile["sun_color"]
	var to_sun: Color = to_profile["sun_color"]
	var from_tint: Vector3 = from_profile["retro_tint"]
	var to_tint: Vector3 = to_profile["retro_tint"]
	return _make_time_profile(
		from_sky.lerp(to_sky, blend),
		from_ambient.lerp(to_ambient, blend),
		lerpf(float(from_profile["ambient_energy"]), float(to_profile["ambient_energy"]), blend),
		from_fog.lerp(to_fog, blend),
		lerpf(float(from_profile["fog_density"]), float(to_profile["fog_density"]), blend),
		lerpf(float(from_profile["fog_sky_affect"]), float(to_profile["fog_sky_affect"]), blend),
		from_sun.lerp(to_sun, blend),
		lerpf(float(from_profile["sun_energy"]), float(to_profile["sun_energy"]), blend),
		lerpf(float(from_profile["night_factor"]), float(to_profile["night_factor"]), blend),
		from_tint.lerp(to_tint, blend),
		lerpf(float(from_profile["retro_tint_strength"]), float(to_profile["retro_tint_strength"]), blend),
		lerpf(float(from_profile["grain_strength"]), float(to_profile["grain_strength"]), blend),
		lerpf(float(from_profile["dither_strength"]), float(to_profile["dither_strength"]), blend),
		lerpf(float(from_profile["barrel_distortion"]), float(to_profile["barrel_distortion"]), blend)
	)


## Public utility — main volá pro positioning sun DirectionalLight3D.
func direction_to_source_from_hour(hour: float) -> Vector3:
	var h = _normalized_hour(hour)
	var center = _get_celestial_map_center_world()
	var half_span = _get_celestial_path_half_span()
	var max_altitude = half_span * 0.92
	var source_pos = Vector3(center.x - half_span, 0.0, center.z)

	if _is_hour_in_window(h, SUNRISE_HOUR, SUNSET_HOUR):
		var day_mid = (SUNRISE_HOUR + SUNSET_HOUR) * 0.5
		if h <= day_mid:
			var t_rise = inverse_lerp(SUNRISE_HOUR, day_mid, h)
			source_pos = Vector3(
				lerpf(center.x - half_span, center.x, t_rise),
				lerpf(0.0, max_altitude, t_rise),
				center.z
			)
		else:
			var t_set = inverse_lerp(day_mid, SUNSET_HOUR, h)
			source_pos = Vector3(
				lerpf(center.x, center.x + half_span, t_set),
				lerpf(max_altitude, 0.0, t_set),
				center.z
			)
	else:
		var night_span = (24.0 - SUNSET_HOUR) + SUNRISE_HOUR
		var night_progress = _hour_distance_forward(SUNSET_HOUR, h) / max(night_span, 0.001)
		night_progress = clampf(night_progress, 0.0, 1.0)
		if night_progress <= 0.5:
			var t_night_fall = night_progress / 0.5
			source_pos = Vector3(
				lerpf(center.x + half_span, center.x, t_night_fall),
				lerpf(0.0, -max_altitude * 0.88, t_night_fall),
				center.z
			)
		else:
			var t_night_rise = (night_progress - 0.5) / 0.5
			source_pos = Vector3(
				lerpf(center.x, center.x - half_span, t_night_rise),
				lerpf(-max_altitude * 0.88, 0.0, t_night_rise),
				center.z
			)

	var dir = source_pos - center
	if dir.length_squared() < 0.001:
		return Vector3(0.0, 1.0, 0.0) if source_pos.y >= 0.0 else Vector3(0.0, -1.0, 0.0)
	return dir.normalized()


func _normalized_hour(hour: float) -> float:
	var h = fposmod(hour, 24.0)
	if h < 0.0:
		h += 24.0
	return h


func _is_hour_in_window(hour: float, start_hour: float, end_hour: float) -> bool:
	var h = _normalized_hour(hour)
	var start = _normalized_hour(start_hour)
	var end = _normalized_hour(end_hour)
	if is_equal_approx(start, end):
		return true
	if start < end:
		return h >= start and h < end
	return h >= start or h < end


func _hour_distance_forward(start_hour: float, end_hour: float) -> float:
	var start = _normalized_hour(start_hour)
	var end = _normalized_hour(end_hour)
	var delta = end - start
	if delta < 0.0:
		delta += 24.0
	return delta


func _night_overlay_factor(hour: float) -> float:
	var h = _normalized_hour(hour)
	# Full night darkness plateau.
	if h >= NIGHT_SKY_FADE_END_HOUR or h < DAY_SKY_FADE_START_HOUR:
		return 1.0
	# Evening -> night ramp.
	if h >= NIGHT_SKY_FADE_START_HOUR and h < NIGHT_SKY_FADE_END_HOUR:
		return clampf(
			(h - NIGHT_SKY_FADE_START_HOUR) / max(NIGHT_SKY_FADE_END_HOUR - NIGHT_SKY_FADE_START_HOUR, 0.001),
			0.0,
			1.0
		)
	# Night -> day ramp.
	if h >= DAY_SKY_FADE_START_HOUR and h < DAY_SKY_FADE_END_HOUR:
		return clampf(
			1.0 - ((h - DAY_SKY_FADE_START_HOUR) / max(DAY_SKY_FADE_END_HOUR - DAY_SKY_FADE_START_HOUR, 0.001)),
			0.0,
			1.0
		)
	return 0.0


func _current_sky_phase() -> int:
	var h = _normalized_hour(_time_of_day_hours)
	if h >= NIGHT_SKY_FADE_START_HOUR or h < DAY_SKY_FADE_START_HOUR:
		return SKY_PHASE_NIGHT
	if h >= DUSK_SKY_FADE_START_HOUR:
		return SKY_PHASE_DUSK
	if h >= EVENING_SKY_FADE_START_HOUR:
		return SKY_PHASE_EVENING
	return SKY_PHASE_DAY


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _scale_color_rgb(color: Color, factor: float) -> Color:
	var f = clampf(factor, 0.0, 1.0)
	return Color(color.r * f, color.g * f, color.b * f, color.a)


func _apply_sun_shadow_profile() -> void:
	var overrides := {
		"directional_shadow_mode": SUN_SHADOW_MODE,
		"directional_shadow_blend_splits": true,
		"directional_shadow_split_1": SUN_SHADOW_SPLIT_1,
		"directional_shadow_split_2": SUN_SHADOW_SPLIT_2,
		"directional_shadow_split_3": SUN_SHADOW_SPLIT_3,
		"directional_shadow_max_distance": SUN_SHADOW_MAX_DISTANCE,
		"directional_shadow_fade_start": SUN_SHADOW_FADE_START,
		"directional_shadow_pancake_size": SUN_SHADOW_PANCAKE_SIZE,
		"shadow_bias": 0.05, "shadow_normal_bias": 0.90, "shadow_blur": 1.0
	}
	for property_name in overrides.keys():
		_set_object_property_if_exists(_sun, property_name, overrides[property_name])


func _set_object_property_if_exists(target: Object, property_name: String, value: Variant) -> bool:
	if target == null:
		return false
	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return true
	return false


func _try_apply_skybox(env: Environment) -> void:
	if env != null:
		_apply_weather_skybox(true)


func _apply_panorama_sky(env: Environment, texture: Texture2D) -> void:
	if env == null or texture == null:
		return
	var sky_mat = PanoramaSkyMaterial.new()
	sky_mat.panorama = texture
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	_sky_display_texture = texture


func _resolve_sky_transition_duration_seconds(from_path: String, to_path: String) -> float:
	if _is_path_in_list(from_path, SKY_TEX_DUSK_PATHS) and _is_path_in_list(to_path, SKY_TEX_NIGHT_PATHS):
		return SKY_TRANSITION_DURATION_NIGHT
	return SKY_TRANSITION_DURATION


func _is_path_in_list(path: String, candidates: Array) -> bool:
	if path.is_empty():
		return false
	for candidate in candidates:
		if str(candidate) == path:
			return true
	return false


func _current_sky_candidates() -> Array:
	if _weather_state == WEATHER_EVENT: return SKY_TEX_DUSK_PATHS
	var sky_phase = _current_sky_phase()
	if sky_phase == SKY_PHASE_NIGHT: return SKY_TEX_NIGHT_PATHS
	if _weather_state == WEATHER_FOG: return SKY_TEX_FOG_PATHS
	if _weather_state == WEATHER_LIGHT_RAIN: return SKY_TEX_LIGHT_RAIN_PATHS
	if _weather_state == WEATHER_RAIN: return SKY_TEX_RAIN_PATHS
	if _weather_state == WEATHER_STORM: return SKY_TEX_STORM_PATHS
	if sky_phase == SKY_PHASE_DUSK: return SKY_TEX_DUSK_PATHS
	if sky_phase == SKY_PHASE_EVENING: return SKY_TEX_EVE_PATHS
	if _weather_state == WEATHER_WINDY: return SKY_TEX_WINDY_PATHS
	return SKY_TEX_CLEAR_PATHS


func _first_existing_path(paths: Array) -> String:
	for path in paths:
		if _resource_or_file_exists(str(path)):
			return path
	return ""


func _resource_or_file_exists(path: String) -> bool:
	if path == "": return false
	if ResourceLoader.exists(path): return true
	if path.begins_with("res://") or path.begins_with("user://"):
		return FileAccess.file_exists(ProjectSettings.globalize_path(path))
	return FileAccess.file_exists(path)


func _load_cached_sky_texture(path: String) -> Texture2D:
	if path == "": return null
	if _sky_texture_cache.has(path):
		var cached = _sky_texture_cache[path] as Texture2D
		if cached != null: return cached
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var image = Image.new()
		var image_err = image.load(ProjectSettings.globalize_path(path))
		if image_err == OK and not image.is_empty():
			tex = ImageTexture.create_from_image(image)
	if tex != null:
		_sky_texture_cache[path] = tex
	return tex


func _apply_weather_skybox(force: bool = false) -> void:
	var env = _world_env.environment
	if env == null: return
	var selected_path = _first_existing_path(_current_sky_candidates())
	if selected_path == "":
		selected_path = _first_existing_path(SKY_TEX_FALLBACK_PATHS)
	if selected_path == "": return
	var texture = _load_cached_sky_texture(selected_path)
	if texture == null: return
	if force:
		_sky_transition_active = false
		_sky_transition_from_texture = null; _sky_transition_to_texture = null
		_sky_transition_progress = 1.0; _sky_transition_last_step = -1
		_sky_transition_duration_seconds = SKY_TRANSITION_DURATION
		if _sky_transition_material != null:
			_sky_transition_material.set_shader_parameter("blend", 1.0)
		_apply_panorama_sky(env, texture)
		_active_sky_texture_path = selected_path
		return
	if selected_path == _active_sky_texture_path: return
	var from_texture = _sky_display_texture
	var from_path = _active_sky_texture_path
	if from_texture == null or from_texture == texture:
		_apply_panorama_sky(env, texture)
		_active_sky_texture_path = selected_path
		return
	if _sky_transition_active:
		if _sky_transition_to_texture == texture: return
		if _sky_transition_to_texture != null:
			_apply_panorama_sky(env, _sky_transition_to_texture)
		from_texture = _sky_display_texture
		from_path = _active_sky_texture_path
	_sky_transition_duration_seconds = _resolve_sky_transition_duration_seconds(from_path, selected_path)
	_sky_transition_from_texture = from_texture
	_sky_transition_to_texture = texture
	_sky_transition_progress = 0.0; _sky_transition_last_step = -1
	_sky_transition_active = true
	_active_sky_texture_path = selected_path
	_setup_shader_sky(env, _sky_transition_from_texture, _sky_transition_to_texture)
	_update_sky_transition(0.0)


func _update_sky_transition(delta: float) -> void:
	if not _sky_transition_active: return
	var env = _world_env.environment
	if env == null: return
	if _sky_transition_to_texture == null:
		_sky_transition_active = false; return
	if delta > 0.0:
		var transition_duration = max(_sky_transition_duration_seconds, 0.001)
		_sky_transition_progress = min(1.0, _sky_transition_progress + (delta / transition_duration))
	var blend_t = clampf(_sky_transition_progress, 0.0, 1.0)
	if env.sky != null and env.sky.sky_material is ShaderMaterial:
		env.sky.sky_material.set_shader_parameter("blend", blend_t)
	if blend_t >= 0.999:
		_apply_panorama_sky(env, _sky_transition_to_texture)
		_sky_transition_active = false
		_sky_transition_from_texture = null; _sky_transition_to_texture = null
		_sky_transition_progress = 1.0; _sky_transition_last_step = -1
		_sky_transition_duration_seconds = SKY_TRANSITION_DURATION


func _setup_shader_sky(env: Environment, from_tex: Texture2D, to_tex: Texture2D) -> void:
	if env == null: return
	if _sky_transition_material == null:
		_sky_transition_material = ShaderMaterial.new()
		_sky_transition_material.shader = SKY_TRANSITION_SHADER
	_sky_transition_material.set_shader_parameter("panorama_from", from_tex)
	_sky_transition_material.set_shader_parameter("panorama_to", to_tex)
	_sky_transition_material.set_shader_parameter("blend", 0.0)
	if env.sky == null: env.sky = Sky.new()
	env.sky.sky_material = _sky_transition_material
	env.background_mode = Environment.BG_SKY


func _get_active_world_camera() -> Camera3D:
	if _player_getter.is_valid():
		var player = _player_getter.call()
		if player != null:
			var cam = player.get_node_or_null("Head/Camera3D") as Camera3D
			if cam != null: return cam
	return _fallback_cam


func _get_celestial_map_center_world() -> Vector3:
	if _grid_mgr != null and _grid_mgr.has_method("get_map_center_world"):
		return _grid_mgr.get_map_center_world()
	return Vector3.ZERO


func _get_celestial_path_half_span() -> float:
	if _grid_mgr != null and _grid_mgr.has_method("get_map_size_world"):
		var map_size = _grid_mgr.get_map_size_world()
		if map_size is Vector2:
			return max((map_size as Vector2).x * 0.5, 1.0)
	return CELESTIAL_PATH_DEFAULT_HALF_SPAN


func _create_pixel_celestial_sprite(
	node_name: String, texture: Texture2D, size: float,
	render_priority: int = 0, always_on_top: bool = false
) -> MeshInstance3D:
	var sprite = MeshInstance3D.new()
	sprite.name = node_name
	var quad = QuadMesh.new()
	quad.size = Vector2(size, size)
	sprite.mesh = quad
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = always_on_top
	mat.render_priority = render_priority
	sprite.material_override = mat
	return sprite


func _create_pixel_sun_texture() -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(16):
		for x in range(16):
			var d = Vector2(float(x) - 7.5, float(y) - 7.5).length()
			if d > 6.2: continue
			var col = Color(0.98, 0.66, 0.15, 1.0)
			if d < 4.2: col = Color(1.0, 0.86, 0.28, 1.0)
			if d < 2.2: col = Color(1.0, 0.95, 0.56, 1.0)
			image.set_pixel(x, y, col)
	return ImageTexture.create_from_image(image)


func _create_pixel_moon_texture() -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(16):
		for x in range(16):
			var d_outer = Vector2(float(x) - 7.5, float(y) - 7.5).length()
			if d_outer > 6.1: continue
			var d_cut = Vector2(float(x) - 10.2, float(y) - 7.5).length()
			if d_cut < 5.4: continue
			var col = Color(0.74, 0.82, 0.95, 1.0)
			if d_outer < 3.4: col = Color(0.90, 0.94, 1.0, 1.0)
			image.set_pixel(x, y, col)
	return ImageTexture.create_from_image(image)


func _create_pixel_sun_glow_texture() -> Texture2D:
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center = Vector2(15.5, 15.5)
	for y in range(32):
		for x in range(32):
			var d = Vector2(float(x), float(y)).distance_to(center)
			if d > 15.6: continue
			var t = clampf(1.0 - (d / 15.6), 0.0, 1.0)
			var alpha = pow(t, 1.65) * 0.72
			image.set_pixel(x, y, Color(1.0, 0.88 + (0.10 * t), 0.58 + (0.24 * t), alpha))
	return ImageTexture.create_from_image(image)


func _create_pixel_sun_flare_texture() -> Texture2D:
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center = Vector2i(15, 15)
	for y in range(32):
		for x in range(32):
			var dx = abs(x - center.x); var dy = abs(y - center.y)
			var ray_strength = 0.0
			if dy <= 1: ray_strength = max(ray_strength, 1.0 - (float(dx) / 15.0))
			if dx <= 1: ray_strength = max(ray_strength, 1.0 - (float(dy) / 15.0))
			if dx == dy and dx <= 10: ray_strength = max(ray_strength, 1.0 - (float(dx) / 10.0))
			if abs(dx - (dy * 2)) <= 1 and dy <= 7: ray_strength = max(ray_strength, 1.0 - (float(dy) / 7.0))
			var d = Vector2(float(dx), float(dy)).length()
			var radial = (1.0 - (d / 5.0)) if d <= 5.0 else 0.0
			var alpha = max(radial * 0.80, ray_strength * 0.36)
			if alpha <= 0.0: continue
			image.set_pixel(x, y, Color(1.0, 0.92, 0.74, clampf(alpha, 0.0, 0.90)))
	return ImageTexture.create_from_image(image)


func _setup_star_field() -> void:
	_star_sprites.clear(); _star_directions.clear()
	_star_twinkle_phases.clear(); _star_alpha_variation.clear()
	if _celestial_root == null: return
	for i in range(STARFIELD_COUNT):
		var star = _create_pixel_celestial_sprite(
			"PixelStar%02d" % i, _create_pixel_star_texture(i % 3),
			_sky_rng.randf_range(0.34, 0.56), 1)
		_celestial_root.add_child(star)
		star.visible = false
		_star_sprites.append(star)
		var azimuth = deg_to_rad(_sky_rng.randf_range(-180.0, 180.0))
		var elevation = deg_to_rad(_sky_rng.randf_range(8.0, 76.0))
		_star_directions.append(Vector3(
			cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth)
		).normalized())
		_star_twinkle_phases.append(_sky_rng.randf_range(0.0, TAU))
		_star_alpha_variation.append(_sky_rng.randf_range(0.56, 0.96))


func _setup_cloud_layers() -> void:
	_cloud_sprites.clear(); _cloud_world_positions.clear()
	_cloud_world_drift_vectors.clear(); _cloud_phase_offsets.clear()
	_cloud_speed_jitter.clear(); _cloud_alpha_jitter.clear(); _cloud_presence_threshold.clear()
	if _celestial_root == null: return
	var origin = Vector3.ZERO
	var cam = _get_active_world_camera()
	if cam != null: origin = cam.global_position
	origin.y = 0.0
	_cloud_world_center = origin
	for i in range(CLOUD_LAYER_COUNT):
		var cloud = _create_pixel_celestial_sprite(
			"PixelCloud%02d" % i, _create_pixel_cloud_texture(i % 4),
			_sky_rng.randf_range(6.2, 10.4), 3)
		_celestial_root.add_child(cloud)
		cloud.visible = false
		_cloud_sprites.append(cloud)
		_cloud_world_positions.append(Vector3(
			_sky_rng.randf_range(origin.x - CLOUD_WORLD_HALF_EXTENT, origin.x + CLOUD_WORLD_HALF_EXTENT),
			_sky_rng.randf_range(CLOUD_ALTITUDE_MIN, CLOUD_ALTITUDE_MAX),
			_sky_rng.randf_range(origin.z - CLOUD_WORLD_HALF_EXTENT, origin.z + CLOUD_WORLD_HALF_EXTENT)
		))
		var yaw = deg_to_rad(_sky_rng.randf_range(-180.0, 180.0))
		var drift = Vector3(cos(yaw), 0.0, sin(yaw)).normalized()
		if drift.length_squared() < 0.001: drift = Vector3(1.0, 0.0, 0.0)
		_cloud_world_drift_vectors.append(drift)
		_cloud_phase_offsets.append(_sky_rng.randf_range(0.0, TAU))
		_cloud_speed_jitter.append(_sky_rng.randf_range(0.65, 1.35))
		_cloud_alpha_jitter.append(_sky_rng.randf_range(0.74, 1.16))
		_cloud_presence_threshold.append(_sky_rng.randf())


func _create_pixel_star_texture(variant: int) -> Texture2D:
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center = Vector2i(3, 3)
	for y in range(8):
		for x in range(8):
			var dx = abs(x - center.x); var dy = abs(y - center.y)
			var alpha = 0.0
			if dx == 0 and dy == 0: alpha = 1.0
			elif dx + dy == 1: alpha = 0.86 if variant != 2 else 0.72
			elif dx == 1 and dy == 1 and variant == 1: alpha = 0.52
			elif (dx == 2 and dy == 0) or (dx == 0 and dy == 2): alpha = 0.36 if variant == 0 else 0.28
			if alpha > 0.0: image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _create_pixel_cloud_texture(variant: int) -> Texture2D:
	var image = Image.create(28, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var blobs: Array = []
	match variant % 4:
		0: blobs = [Vector3(6.0,9.0,4.8),Vector3(13.0,7.0,5.8),Vector3(20.0,9.0,4.8),Vector3(24.0,10.0,3.2)]
		1: blobs = [Vector3(5.0,8.0,4.6),Vector3(11.0,6.4,5.0),Vector3(17.5,8.2,4.6),Vector3(23.0,9.4,4.0)]
		2: blobs = [Vector3(6.5,9.5,4.4),Vector3(12.5,7.3,5.2),Vector3(18.0,7.6,4.4),Vector3(23.5,9.2,3.8)]
		_: blobs = [Vector3(5.5,8.6,4.2),Vector3(10.8,6.8,4.8),Vector3(16.6,7.2,4.6),Vector3(22.8,9.0,4.2)]
	for y in range(16):
		for x in range(28):
			var fill = 0.0
			for blob in blobs:
				var d = Vector2(float(x) - blob.x, float(y) - blob.y).length()
				if d < blob.z: fill = max(fill, 1.0 - (d / blob.z))
			if fill <= 0.0: continue
			var alpha = clampf(0.40 + (fill * 0.58), 0.0, 0.96)
			var shade = clampf((float(y) / 15.0) * 0.12, 0.0, 0.12)
			image.set_pixel(x, y, Color(1.0-shade, 1.0-shade, 1.0-(shade*0.8), alpha))
	return ImageTexture.create_from_image(image)


func _update_star_field(cam_pos: Vector3, sky_distance: float) -> void:
	if _star_sprites.is_empty(): return
	var visibility = _star_visibility_factor()
	for i in range(_star_sprites.size()):
		var star = _star_sprites[i] as MeshInstance3D
		if star == null: continue
		var dir = (_star_directions[i] as Vector3).normalized()
		star.global_position = cam_pos + (dir * sky_distance)
		star.look_at(cam_pos, Vector3.UP)
		var twinkle = 0.82 + (0.18 * sin((_sky_anim_time * 1.7) + float(_star_twinkle_phases[i])))
		var alpha = clampf(visibility * float(_star_alpha_variation[i]) * twinkle, 0.0, 0.95)
		if dir.y < -0.01: alpha = 0.0
		star.visible = alpha > 0.02
		_set_sprite_tint(star, Color(0.93, 0.95, 1.0), alpha)


func _update_sun_flare(cam: Camera3D, cam_pos: Vector3, sun_dir: Vector3, sky_distance: float) -> void:
	if _sun_glow_sprite_3d == null or _sun_flare_sprite_3d == null: return
	if _sun_sprite_3d == null:
		_sun_glow_sprite_3d.visible = false; _sun_flare_sprite_3d.visible = false; return
	var cam_forward = -cam.global_transform.basis.z.normalized()
	var focus = pow(clampf(cam_forward.dot(sun_dir), 0.0, 1.0), 10.0)
	var horizon_visibility = _sun_horizon_visibility(sun_dir.y)
	var intensity = focus * _sun_flare_weather_multiplier() * horizon_visibility
	if intensity <= 0.008:
		_sun_glow_sprite_3d.visible = false; _sun_flare_sprite_3d.visible = false; return
	var sun_pos = cam_pos + (sun_dir * sky_distance)
	var sprite_scale = sky_distance / CELESTIAL_SPRITE_REFERENCE_DISTANCE
	var glow_offset = max(0.18, sky_distance * 0.0018)
	var flare_offset = max(0.12, sky_distance * 0.0012)
	_sun_glow_sprite_3d.global_position = sun_pos - (sun_dir * glow_offset)
	_sun_flare_sprite_3d.global_position = sun_pos - (sun_dir * flare_offset)
	_sun_glow_sprite_3d.look_at(cam_pos, Vector3.UP)
	_sun_flare_sprite_3d.look_at(cam_pos, Vector3.UP)
	_set_sprite_size(_sun_glow_sprite_3d, lerpf(7.4, 11.8, intensity) * sprite_scale)
	_set_sprite_size(_sun_flare_sprite_3d, lerpf(4.8, 8.6, intensity) * sprite_scale)
	_set_sprite_tint(_sun_glow_sprite_3d, Color(1.0, 0.86, 0.50), clampf(0.08 + (intensity * 0.58), 0.0, 0.78))
	_set_sprite_tint(_sun_flare_sprite_3d, Color(1.0, 0.92, 0.72), clampf(intensity * 0.64, 0.0, 0.72))
	_sun_glow_sprite_3d.visible = true; _sun_flare_sprite_3d.visible = true


func _sun_flare_weather_multiplier() -> float:
	match _weather_state:
		WEATHER_WINDY: return 0.82
		WEATHER_FOG: return 0.46
		WEATHER_LIGHT_RAIN: return 0.34
		WEATHER_RAIN: return 0.24
		WEATHER_STORM: return 0.08
		_: return 1.0


func _sun_horizon_visibility(sun_height: float) -> float:
	var fade_span = max(SUN_HORIZON_FADE_START_Y - SUN_HORIZON_FADE_END_Y, 0.001)
	var t = clampf((sun_height - SUN_HORIZON_FADE_END_Y) / fade_span, 0.0, 1.0)
	return t * t * (3.0 - (2.0 * t))


func _resolve_celestial_sprite_distance(camera_far: float) -> float:
	var map_half_span = _get_celestial_path_half_span()
	var map_target = max(map_half_span * CELESTIAL_SPRITE_MAP_DISTANCE_FACTOR, CELESTIAL_SPRITE_MIN_DISTANCE)
	var far_limit = max(camera_far * CELESTIAL_SPRITE_CAMERA_FAR_FACTOR, 1.0)
	return min(map_target, far_limit)


func _update_cloud_layers(cam_pos: Vector3) -> void:
	if _cloud_sprites.is_empty(): return
	var active_density = clampf(_cloud_density_current, 0.0, 1.0)
	var alpha_base = clampf(_cloud_alpha_current, 0.0, 1.0)
	var dp = _cloud_daylight_profile()
	var tint = _cloud_tint_for_time_weather().lerp(dp["tint"] as Color, 0.42)
	var flash_tint = tint.lerp(Color(0.92, 0.95, 1.0), _storm_flash_strength * 0.35)
	var time_alpha_mul = dp["alpha_mul"] as float
	var sky_phase = _current_sky_phase()
	if sky_phase == SKY_PHASE_EVENING: time_alpha_mul *= 0.94
	elif sky_phase == SKY_PHASE_DUSK: time_alpha_mul *= 0.90
	elif sky_phase == SKY_PHASE_NIGHT: time_alpha_mul *= 0.86
	var denom = max(1.0, float(_cloud_sprites.size() - 1))
	for i in range(_cloud_sprites.size()):
		var cloud = _cloud_sprites[i] as MeshInstance3D
		if cloud == null: continue
		if i >= _cloud_world_positions.size(): cloud.visible = false; continue
		var presence = 1.0
		if i < _cloud_presence_threshold.size(): presence = float(_cloud_presence_threshold[i])
		if presence > (active_density + 0.03): cloud.visible = false; continue
		var phase = float(_cloud_phase_offsets[i]) if i < _cloud_phase_offsets.size() else 0.0
		var alpha_j = float(_cloud_alpha_jitter[i]) if i < _cloud_alpha_jitter.size() else 1.0
		var base_pos = _cloud_world_positions[i] as Vector3
		var bob = sin((_sky_anim_time * 0.18 * max(_cloud_speed_current, 0.05)) + phase) * 1.25
		cloud.global_position = Vector3(
			base_pos.x,
			clampf(base_pos.y + bob, CLOUD_ALTITUDE_MIN - 1.5, CLOUD_ALTITUDE_MAX + 1.5),
			base_pos.z)
		cloud.look_at(cam_pos, Vector3.UP)
		var alpha = clampf(alpha_base * alpha_j * time_alpha_mul * (0.86 + 0.14 * (float(i) / denom)), 0.0, 0.90)
		cloud.visible = alpha > 0.02
		_set_sprite_tint(cloud, flash_tint, alpha)


func _wrap_world_xz(pos: Vector3, center: Vector3, half_extent: float) -> Vector3:
	var span = half_extent * 2.0
	if span <= 0.0: return pos
	var w = pos
	w.x = center.x + fposmod((w.x - center.x) + half_extent, span) - half_extent
	w.z = center.z + fposmod((w.z - center.z) + half_extent, span) - half_extent
	return w


func _update_cloud_world_motion(delta: float) -> void:
	if _cloud_world_positions.is_empty(): return
	var base_speed = CLOUD_DRIFT_BASE_UNITS_PER_SEC * max(_cloud_speed_current, 0.04)
	for i in range(_cloud_world_positions.size()):
		var pos = _cloud_world_positions[i] as Vector3
		var drift = Vector3(1.0, 0.0, 0.0)
		if i < _cloud_world_drift_vectors.size():
			drift = (_cloud_world_drift_vectors[i] as Vector3).normalized()
		if drift.length_squared() < 0.001: drift = Vector3(1.0, 0.0, 0.0)
		var jitter = float(_cloud_speed_jitter[i]) if i < _cloud_speed_jitter.size() else 1.0
		pos += drift * (base_speed * jitter * delta)
		pos.y = clampf(pos.y, CLOUD_ALTITUDE_MIN, CLOUD_ALTITUDE_MAX)
		_cloud_world_positions[i] = _wrap_world_xz(pos, _cloud_world_center, CLOUD_WORLD_HALF_EXTENT)


func _cloud_daylight_profile() -> Dictionary:
	var sun_height = clampf(_sun_direction_to_source.y, -1.0, 1.0)
	var daylight_factor = clampf((sun_height + 0.08) / 1.08, 0.0, 1.0)
	var sunset_band = clampf(1.0 - abs(sun_height) * 4.0, 0.0, 1.0)
	var tint = Color(0.62, 0.70, 0.86).lerp(Color(1.0, 0.98, 0.94), daylight_factor)
	tint = tint.lerp(Color(1.0, 0.72, 0.50), sunset_band * daylight_factor)
	return {"tint": tint, "alpha_mul": lerpf(0.74, 1.06, daylight_factor)}


func _star_visibility_factor() -> float:
	var h = _normalized_hour(_time_of_day_hours)
	var time_factor = 0.0
	if h >= STAR_FADE_IN_START_HOUR and h < NIGHT_SKY_FADE_END_HOUR:
		time_factor = lerpf(
			0.0,
			0.92,
			(h - STAR_FADE_IN_START_HOUR) / max(NIGHT_SKY_FADE_END_HOUR - STAR_FADE_IN_START_HOUR, 0.001)
		)
	elif h >= NIGHT_SKY_FADE_END_HOUR or h < DAY_SKY_FADE_START_HOUR:
		time_factor = 0.92
	elif h < DAY_SKY_FADE_END_HOUR:
		time_factor = lerpf(0.92, 0.0, (h - DAY_SKY_FADE_START_HOUR) / max(DAY_SKY_FADE_END_HOUR - DAY_SKY_FADE_START_HOUR, 0.001))
	return clampf(time_factor * _weather_star_visibility_multiplier(), 0.0, 1.0)


func _weather_star_visibility_multiplier() -> float:
	match _weather_state:
		WEATHER_WINDY: return 0.80
		WEATHER_FOG: return 0.40
		WEATHER_LIGHT_RAIN: return 0.30
		WEATHER_RAIN: return 0.20
		WEATHER_STORM: return 0.06
		_: return 1.0


func _cloud_tint_for_time_weather() -> Color:
	var time_tint = Color(0.94, 0.95, 0.94)
	var sky_phase = _current_sky_phase()
	if sky_phase == SKY_PHASE_EVENING:
		time_tint = Color(0.98, 0.76, 0.60)
	elif sky_phase == SKY_PHASE_DUSK:
		time_tint = Color(0.84, 0.42, 0.40)
	elif sky_phase == SKY_PHASE_NIGHT:
		time_tint = Color(0.52, 0.58, 0.72)
	var dark_mix = 0.0
	match _weather_state:
		WEATHER_WINDY: dark_mix = 0.10
		WEATHER_FOG: dark_mix = 0.16
		WEATHER_LIGHT_RAIN: dark_mix = 0.26
		WEATHER_RAIN: dark_mix = 0.48
		WEATHER_STORM: dark_mix = 0.58
	return time_tint.lerp(Color(0.24, 0.27, 0.32), dark_mix)


func _set_sprite_tint(sprite: MeshInstance3D, tint: Color, alpha: float) -> void:
	if sprite == null: return
	var mat = sprite.material_override as StandardMaterial3D
	if mat == null: return
	mat.albedo_color = Color(tint.r, tint.g, tint.b, clampf(alpha, 0.0, 1.0))


func _set_sprite_size(sprite: MeshInstance3D, size: float) -> void:
	if sprite == null: return
	var quad = sprite.mesh as QuadMesh
	if quad == null: return
	quad.size = Vector2(max(size, 0.1), max(size, 0.1))


func _weather_fog_color(dark_mix: float) -> Color:
	var weather_tint = Color(0.36, 0.40, 0.46)
	match _weather_state:
		WEATHER_WINDY: weather_tint = Color(0.46, 0.48, 0.54)
		WEATHER_FOG: weather_tint = Color(0.62, 0.66, 0.72)
		WEATHER_LIGHT_RAIN: weather_tint = Color(0.50, 0.56, 0.64)
		WEATHER_RAIN: weather_tint = Color(0.42, 0.48, 0.58)
		WEATHER_STORM: weather_tint = Color(0.30, 0.36, 0.46)
	var sky_phase = _current_sky_phase()
	if sky_phase == SKY_PHASE_EVENING or sky_phase == SKY_PHASE_DUSK:
		weather_tint = weather_tint.lerp(Color(0.56, 0.40, 0.34), 0.22)
	elif sky_phase == SKY_PHASE_NIGHT:
		match _weather_state:
			WEATHER_LIGHT_RAIN: weather_tint = Color(0.09, 0.11, 0.16)
			WEATHER_RAIN: weather_tint = Color(0.06, 0.08, 0.12)
			WEATHER_STORM: weather_tint = Color(0.03, 0.04, 0.07)
			_: weather_tint = weather_tint.lerp(Color(0.14, 0.18, 0.24), 0.65)
	return _base_fog_light_color.lerp(weather_tint, clampf(dark_mix, 0.0, 1.0))


func _rain_weather_wind() -> Vector2:
	var base = Vector2.ZERO
	var sway_s = 0.0; var gust_s = 0.0
	match _weather_state:
		WEATHER_LIGHT_RAIN: base = Vector2(0.12, 0.05); sway_s = 0.04; gust_s = 0.03
		WEATHER_RAIN:       base = Vector2(0.22, 0.10); sway_s = 0.07; gust_s = 0.06
		WEATHER_STORM:      base = Vector2(0.34, 0.14); sway_s = 0.10; gust_s = 0.09
		_: return Vector2.ZERO
	var sway = Vector2(sin((_sky_anim_time * 0.42) + 0.9), cos((_sky_anim_time * 0.35) - 0.6)) * sway_s
	var gust = Vector2(sin((_sky_anim_time * 1.45) + 2.1), sin((_sky_anim_time * 1.12) - 0.7)) * gust_s
	return base + sway + gust


func _rain_tilt_strength_bounds() -> Vector2:
	match _weather_state:
		WEATHER_LIGHT_RAIN: return Vector2(0.20, 0.38)
		WEATHER_RAIN:       return Vector2(0.30, 0.58)
		WEATHER_STORM:      return Vector2(0.40, 0.86)
		_: return Vector2.ZERO


func _update_weather_particles(_delta: float) -> void:
	if _rain_particles == null: return
	var center_node: Node3D = null
	if _player_getter.is_valid(): center_node = _player_getter.call() as Node3D
	if center_node == null: center_node = _fallback_cam
	if center_node != null:
		_rain_particles.global_position = center_node.global_position + Vector3(0.0, 12.0, 0.0)
	var is_raining = (_weather_state == WEATHER_LIGHT_RAIN
		or _weather_state == WEATHER_RAIN or _weather_state == WEATHER_STORM)
	_rain_particles.emitting = is_raining
	if not is_raining: return

	var intensity = 1.0; var rain_speed = 22.0
	if _weather_state == WEATHER_LIGHT_RAIN: intensity = 0.4
	elif _weather_state == WEATHER_RAIN: intensity = 0.8
	elif _weather_state == WEATHER_STORM: intensity = 2.5; rain_speed = 35.0

	var draw_mesh = _rain_particles.draw_pass_1 as QuadMesh
	if draw_mesh != null:
		var rain_mat = draw_mesh.material as StandardMaterial3D
		if rain_mat != null:
			var daylight = clampf(compute_daylight_factor(), 0.0, 1.0)
			var tint = Color(0.30, 0.34, 0.40).lerp(Color(0.84, 0.88, 0.92), daylight)
			if _world_env != null and _world_env.environment != null:
				tint = tint.lerp(_world_env.environment.ambient_light_color, 0.30)
			var rain_alpha = 0.17
			if _weather_state == WEATHER_RAIN: rain_alpha = 0.20
			elif _weather_state == WEATHER_STORM: rain_alpha = 0.24
			rain_mat.albedo_color = Color(tint.r, tint.g, tint.b, rain_alpha)

	var wind = _rain_weather_wind()
	var tilt_bounds = _rain_tilt_strength_bounds()
	var tilted_wind = wind
	var wind_len = tilted_wind.length()
	if wind_len > 0.001:
		if wind_len < tilt_bounds.x: tilted_wind = tilted_wind.normalized() * tilt_bounds.x
		elif wind_len > tilt_bounds.y: tilted_wind = tilted_wind.normalized() * tilt_bounds.y
	elif tilt_bounds.x > 0.0:
		tilted_wind = Vector2(0.94, 0.34).normalized() * tilt_bounds.x

	_rain_particles.amount_ratio = min(1.0, intensity * 0.5)
	var p_mat = _rain_particles.process_material as ParticleProcessMaterial
	if p_mat != null:
		p_mat.initial_velocity_min = rain_speed * 0.9
		p_mat.initial_velocity_max = rain_speed * 1.1
		p_mat.direction = Vector3(tilted_wind.x, -1.0, tilted_wind.y).normalized()
		var spread_t = 0.0
		if tilt_bounds.y > tilt_bounds.x:
			spread_t = clampf((tilted_wind.length() - tilt_bounds.x) / (tilt_bounds.y - tilt_bounds.x), 0.0, 1.0)
		p_mat.spread = lerpf(0.8, 2.6, spread_t)
