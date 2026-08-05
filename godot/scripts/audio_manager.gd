extends Node3D

const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")

const SFX_DOOR_OPEN_PATH := "res://assets/sfx/dvereotevrit.mp3"
const SFX_DOOR_CLOSE_PATH := "res://assets/sfx/dverezavrit.mp3"
const SFX_MORNING_CHIME_PATH := "res://assets/sfx/rednecksfx/rrbimbam.wav"
const SFX_CRICKETS_PATH := "res://assets/sfx/cricketi.mp3"
const SFX_BOOT_TEST_PATH := "res://assets/sfx/shust.mp3"
const SFX_AMBIENCE_CALM_PATH := "res://assets/sfx/ost/ambience1A_pcm.wav"
const SFX_AMBIENCE_EERIE_PATH := "res://assets/sfx/ost/ambience2A_pcm.wav"
const SFX_AMBIENCE_LES_PATH := "res://assets/sfx/ost/ambience3A.mp3"
const SFX_BIRD_PATH := "res://assets/sfx/rednecksfx/rrbird.wav"
const SFX_CRICKET_VARIANT_A_PATH := "res://assets/sfx/rednecksfx/rrcvrk.wav"
const SFX_CRICKET_VARIANT_B_PATH := "res://assets/sfx/rednecksfx/rrcricket.wav"
const SFX_REDNECK_WIND_SHORT_PATH := "res://assets/sfx/rednecksfx/rrvitrmild_pcm.wav"
const SFX_REDNECK_FLIES_PATH := "res://assets/sfx/rednecksfx/rrswerambience.wav"
const SFX_REDNECK_FART_1_PATH := "res://assets/sfx/shust.mp3"
const SFX_REDNECK_FART_2_PATH := "res://assets/sfx/shust2.mp3"
const SFX_REDNECK_FART_3_PATH := "res://assets/sfx/dverebubu.mp3"
const SFX_REDNECK_PISS_1_PATH := "res://assets/sfx/shust.mp3"
const SFX_REDNECK_PISS_2_PATH := "res://assets/sfx/shust2.mp3"
const SFX_REDNECK_PISS_3_PATH := "res://assets/sfx/dverebubu.mp3"
const SFX_REDNECK_OWL_PATH := "res://assets/sfx/rednecksfx/rrbird.wav"
const SFX_REDNECK_ZABASCARY_PATH := "res://assets/sfx/rednecksfx/rrcricket.wav"
const SFX_WEATHER_WIND_PATH := "res://assets/sfx/weather/wind.mp3"
const SFX_WEATHER_CALM_RAIN_PATH := "res://assets/sfx/weather/calmrain.mp3"
const SFX_WEATHER_RAIN_PATH := "res://assets/sfx/weather/rain.mp3"
const SFX_WEATHER_RAIN_INSIDE_PATH := "res://assets/sfx/weather/raininside.mp3"
const SFX_WEATHER_RAIN_STORM_PATH := "res://assets/sfx/weather/rainstorm.mp3"
const SFX_WEATHER_WIND_STORM_PATH := "res://assets/sfx/weather/windstorm.mp3"
const SFX_AMBIENCE_DAY_PATH := "res://assets/sfx/ambiencesfx/dayambience.mp3"
const SFX_AMBIENCE_DUSK_BIRDS_PATH := "res://assets/sfx/ambiencesfx/duskbirds.mp3"
const SFX_AMBIENCE_LAKE_INSECTS_PATH := "res://assets/sfx/ambiencesfx/lakeinsects.mp3"
const SFX_AMBIENCE_PIPES_PATH := "res://assets/sfx/ambiencesfx/pipesambience.mp3"
# redneckblesk.wav is used as "blesk1" variant in current asset pack.
const SFX_WEATHER_THUNDER_NEAR_A_PATH := "res://assets/sfx/rednecksfx/rrgeneratorpowerup.wav"
const SFX_WEATHER_THUNDER_NEAR_B_PATH := "res://assets/sfx/rednecksfx/rrtick.wav"
const SFX_WEATHER_THUNDER_FAR_PATH := "res://assets/sfx/rednecksfx/rrvitrmild.wav"
const WEATHER_CLEAR: int = 0
const WEATHER_WINDY: int = 1
const WEATHER_FOG: int = 2
const WEATHER_LIGHT_RAIN: int = 3
const WEATHER_RAIN: int = 4
const WEATHER_STORM: int = 5
const WEATHER_EVENT: int = 6
const MORNING_CHIME_HOUR: float = BALANCE_CONFIG.DAY_START_HOUR
const MORNING_CHIME_VOLUME_DB: float = -8.0
const CRICKETS_ACTIVE_DB: float = 2.0
const CRICKETS_SILENT_DB: float = -48.0
const CRICKETS_FADE_SECONDS: float = 15.0
const AMBIENCE_NIGHT_START_HOUR: float = 18.0
const CRICKETS_START_HOUR: float = AMBIENCE_NIGHT_START_HOUR
const CRICKETS_END_HOUR: float = BALANCE_CONFIG.DAY_START_HOUR
const CRICKET_VARIANT_VOLUME_DB: float = -2.5
const CRICKET_VARIANT_MIN_INTERVAL_SECONDS: float = 24.0
const CRICKET_VARIANT_MAX_INTERVAL_SECONDS: float = 38.0
const CRICKET_VARIANT_PITCH_MIN: float = 0.98
const CRICKET_VARIANT_PITCH_MAX: float = 1.02
const CRICKET_VARIANT_MIN_RADIUS: float = 2.8
const CRICKET_VARIANT_MAX_RADIUS: float = 8.0
const CRICKET_VARIANT_MIN_HEIGHT: float = 0.1
const CRICKET_VARIANT_MAX_HEIGHT: float = 1.1
const BIRD_START_HOUR: float = BALANCE_CONFIG.DAY_START_HOUR
const BIRD_END_HOUR: float = AMBIENCE_NIGHT_START_HOUR
const BIRD_VOLUME_DB: float = -8.0
const BIRD_MIN_INTERVAL_SECONDS: float = 20.0
const BIRD_MAX_INTERVAL_SECONDS: float = 42.0
const BIRD_PITCH_MIN: float = 0.98
const BIRD_PITCH_MAX: float = 1.02
const REDNECK_WIND_SHORT_VOLUME_DB: float = -24.0
const REDNECK_WIND_SHORT_MIN_INTERVAL_SECONDS: float = 22.0
const REDNECK_WIND_SHORT_MAX_INTERVAL_SECONDS: float = 46.0
const REDNECK_WIND_SHORT_INITIAL_MIN_INTERVAL_SECONDS: float = 7.0
const REDNECK_WIND_SHORT_INITIAL_MAX_INTERVAL_SECONDS: float = 15.0
const REDNECK_WIND_SHORT_MIN_RADIUS: float = 7.0
const REDNECK_WIND_SHORT_MAX_RADIUS: float = 20.0
const REDNECK_WIND_SHORT_MIN_HEIGHT: float = 0.5
const REDNECK_WIND_SHORT_MAX_HEIGHT: float = 3.2
const REDNECK_WIND_SHORT_PITCH_MIN: float = 0.97
const REDNECK_WIND_SHORT_PITCH_MAX: float = 1.03
const TOILET_FLIES_VOLUME_DB: float = -34.5
const TOILET_MISC_VOLUME_DB: float = -33.0
const TOILET_MISC_MIN_INTERVAL_SECONDS: float = 112.0
const TOILET_MISC_MAX_INTERVAL_SECONDS: float = 132.0
const TOILET_MISC_INITIAL_MIN_INTERVAL_SECONDS: float = 38.0
const TOILET_MISC_INITIAL_MAX_INTERVAL_SECONDS: float = 65.0
const TOILET_MISC_MIN_RADIUS: float = 0.35
const TOILET_MISC_MAX_RADIUS: float = 1.4
const TOILET_MISC_MIN_HEIGHT: float = 0.1
const TOILET_MISC_MAX_HEIGHT: float = 0.8
const TOILET_MISC_PITCH_MIN: float = 0.98
const TOILET_MISC_PITCH_MAX: float = 1.04
const NIGHT_WILDLIFE_VOLUME_DB: float = -12.0
const NIGHT_WILDLIFE_MIN_INTERVAL_SECONDS: float = 165.0
const NIGHT_WILDLIFE_MAX_INTERVAL_SECONDS: float = 195.0
const NIGHT_WILDLIFE_INITIAL_MIN_INTERVAL_SECONDS: float = 60.0
const NIGHT_WILDLIFE_INITIAL_MAX_INTERVAL_SECONDS: float = 100.0
const NIGHT_WILDLIFE_MIN_RADIUS: float = 7.0
const NIGHT_WILDLIFE_MAX_RADIUS: float = 19.0
const NIGHT_WILDLIFE_MIN_HEIGHT: float = 0.6
const NIGHT_WILDLIFE_MAX_HEIGHT: float = 3.5
const NIGHT_WILDLIFE_PITCH_MIN: float = 0.97
const NIGHT_WILDLIFE_PITCH_MAX: float = 1.03
const AMBIENT_MUSIC_TRIGGER_HOUR: float = AMBIENCE_NIGHT_START_HOUR
const AMBIENT_MUSIC_TRIGGER_CHANCE: float = 0.55
const AMBIENT_MUSIC_VOLUME_DB: float = -18.0
const AMBIENT_MUSIC_SILENT_DB: float = -52.0
const AMBIENT_MUSIC_FADE_SECONDS: float = 18.0
const WEATHER_LOOP_SILENT_DB: float = -48.0
const WEATHER_LOOP_FADE_SECONDS: float = 1.25
const WEATHER_WIND_ACTIVE_DB: float = -17.0
const WEATHER_CALM_RAIN_ACTIVE_DB: float = -18.5
const WEATHER_RAIN_ACTIVE_DB: float = -12.5
const WEATHER_RAIN_INSIDE_ACTIVE_DB: float = -22.0
const WEATHER_RAIN_STORM_ACTIVE_DB: float = -14.0
const WEATHER_WIND_STORM_ACTIVE_DB: float = -15.0
const WEATHER_INTERIOR_DUCK_DB: float = -6.0
const WEATHER_RAIN_INSIDE_INTERIOR_BOOST_DB: float = 1.5
const WEATHER_THUNDER_NEAR_VOLUME_DB: float = -13.5
const WEATHER_THUNDER_FAR_VOLUME_DB: float = -18.0
const WEATHER_THUNDER_MIN_INTERVAL_SECONDS: float = 6.5
const WEATHER_THUNDER_MAX_INTERVAL_SECONDS: float = 14.0
const WEATHER_THUNDER_INITIAL_MIN_INTERVAL_SECONDS: float = 1.3
const WEATHER_THUNDER_INITIAL_MAX_INTERVAL_SECONDS: float = 4.2
const WEATHER_THUNDER_MIN_RADIUS: float = 14.0
const WEATHER_THUNDER_MAX_RADIUS: float = 130.0
const WEATHER_THUNDER_NEAR_RADIUS_THRESHOLD: float = 58.0
const WEATHER_THUNDER_MIN_HEIGHT: float = 3.0
const WEATHER_THUNDER_MAX_HEIGHT: float = 14.0
const WEATHER_THUNDER_PITCH_MIN: float = 0.97
const WEATHER_THUNDER_PITCH_MAX: float = 1.03
const WEATHER_THUNDER_FLASH_NEAR_MIN: float = 0.72
const WEATHER_THUNDER_FLASH_NEAR_MAX: float = 1.00
const WEATHER_THUNDER_FLASH_FAR_MIN: float = 0.22
const WEATHER_THUNDER_FLASH_FAR_MAX: float = 0.52
const AMBIENCE_LOOP_SILENT_DB: float = -56.0
const AMBIENCE_LOOP_FADE_SECONDS: float = 2.8
const DAY_AMBIENCE_ACTIVE_DB: float = -12.0
const DUSK_BIRDS_ACTIVE_DB: float = -10.5
const LAKE_INSECTS_ACTIVE_DB: float = -8.5
const PIPES_AMBIENCE_ACTIVE_DB: float = -7.5
const DUSK_BIRDS_START_HOUR: float = 18.0
const DUSK_BIRDS_END_HOUR: float = 19.5
const LAKE_INSECTS_START_HOUR: float = 18.0
const LAKE_INSECTS_END_HOUR: float = BALANCE_CONFIG.DAY_START_HOUR
const LAKE_INSECTS_TILE_RADIUS: int = 2
const LAKE_INSECTS_CHECK_INTERVAL_SECONDS: float = 0.35
const GRID_TILE_TYPE_LAKE: int = 1
const INTERIOR_AUDIO_DUCK_DB: float = -10.0
const INTERIOR_AUDIO_DUCK_FADE_SECONDS: float = 0.35
const OUTDOOR_AMBIENCE_BUS_NAME := "OutdoorAmbience"
const MASTER_BUS_NAME := "Master"
const MASTER_BUS_DEFAULT_DB: float = 3.0
const OUTDOOR_AMBIENCE_BUS_DEFAULT_DB: float = 1.0
const MAX_STREAM_SOURCE_BYTES: int = 8 * 1024 * 1024

var _time_of_day_hours: float = 6.0
var _sfx_bus: Node
var _sfx_door_open: AudioStreamPlayer
var _sfx_door_close: AudioStreamPlayer
var _sfx_morning_chime: AudioStreamPlayer
var _sfx_crickets: AudioStreamPlayer
var _spatial_sfx_root: Node3D
var _sfx_cricket_variant_a: AudioStreamPlayer3D
var _sfx_cricket_variant_b: AudioStreamPlayer3D
var _sfx_ambient_music: AudioStreamPlayer
var _sfx_bird: AudioStreamPlayer
var _sfx_redneck_wind_short: AudioStreamPlayer3D
var _sfx_toilet_flies: AudioStreamPlayer3D
var _sfx_toilet_misc: AudioStreamPlayer3D
var _sfx_night_owl: AudioStreamPlayer3D
var _sfx_night_zabascary: AudioStreamPlayer3D
var _sfx_weather_wind: AudioStreamPlayer
var _sfx_weather_calm_rain: AudioStreamPlayer
var _sfx_weather_rain: AudioStreamPlayer
var _sfx_weather_rain_inside: AudioStreamPlayer
var _sfx_weather_rain_storm: AudioStreamPlayer
var _sfx_weather_wind_storm: AudioStreamPlayer
var _sfx_day_ambience: AudioStreamPlayer
var _sfx_dusk_birds: AudioStreamPlayer
var _sfx_lake_insects: AudioStreamPlayer
var _sfx_pipes_ambience: AudioStreamPlayer
var _sfx_thunder_near_a: AudioStreamPlayer3D
var _sfx_thunder_near_b: AudioStreamPlayer3D
var _sfx_thunder_far: AudioStreamPlayer3D
var _ambient_music_tracks: Array = []
var _ambient_music_track_names: Array = []
var _toilet_misc_tracks: Array = []
var _ambient_music_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ambient_music_roll_day: int = -1
var _crickets_fade_tween: Tween
var _ambient_music_fade_tween: Tween
var _interior_audio_duck_tween: Tween
var _interior_audio_is_ducked: bool = false
var _outdoor_ambience_bus_index: int = -1
var _interior_audio_base_db: float = 0.0
var _bird_call_cooldown_seconds: float = 0.0
var _cricket_variant_a_cooldown_seconds: float = 0.0
var _cricket_variant_b_cooldown_seconds: float = 0.0
var _cricket_variants_were_active: bool = false
var _redneck_wind_short_cooldown_seconds: float = 0.0
var _redneck_wind_short_active: bool = false
var _toilet_misc_cooldown_seconds: float = 0.0
var _toilet_misc_active: bool = false
var _night_wildlife_cooldown_seconds: float = 0.0
var _night_wildlife_active: bool = false
var _storm_thunder_cooldown_seconds: float = 0.0
var _storm_thunder_active: bool = false
var _pending_storm_flash_strength: float = 0.0
var _stream_source_size_cache: Dictionary = {}
var _oversized_stream_warned: Dictionary = {}
var _grid_manager_ref: Node
var _lake_proximity_is_active: bool = false
var _lake_proximity_check_cooldown_seconds: float = 0.0


func _ready() -> void:
	_ambient_music_rng.randomize()


func setup_audio() -> void:
	_ensure_outdoor_ambience_bus()
	_apply_default_bus_levels()

	_sfx_bus = Node.new()
	_sfx_bus.name = "SfxBus"
	add_child(_sfx_bus)
	_spatial_sfx_root = Node3D.new()
	_spatial_sfx_root.name = "SpatialSfxRoot"
	add_child(_spatial_sfx_root)

	_sfx_door_open = _create_sfx_player("DoorOpenSfx", SFX_DOOR_OPEN_PATH, false, -1.0, MASTER_BUS_NAME)
	_sfx_door_close = _create_sfx_player("DoorCloseSfx", SFX_DOOR_CLOSE_PATH, false, -1.0, MASTER_BUS_NAME)
	_sfx_morning_chime = _create_sfx_player("MorningChimeSfx", SFX_MORNING_CHIME_PATH, false, MORNING_CHIME_VOLUME_DB, MASTER_BUS_NAME)
	_sfx_crickets = _create_sfx_player("CricketsSfx", SFX_CRICKETS_PATH, true, CRICKETS_SILENT_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_cricket_variant_a = _create_spatial_sfx_player("CricketVariantA", SFX_CRICKET_VARIANT_A_PATH, CRICKET_VARIANT_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_cricket_variant_b = _create_spatial_sfx_player("CricketVariantB", SFX_CRICKET_VARIANT_B_PATH, CRICKET_VARIANT_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_setup_ambient_music()
	_setup_weather_layers()
	_setup_dynamic_ambience_layers()
	_setup_redneck_ambience_layers()
	_sfx_bird = _create_sfx_player("BirdSfx", SFX_BIRD_PATH, false, BIRD_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	if _sfx_crickets != null:
		_sfx_crickets.volume_db = CRICKETS_SILENT_DB
	_schedule_next_bird_call(true)
	var boot = _create_sfx_player("BootSfx", SFX_BOOT_TEST_PATH, false, -8.0, MASTER_BUS_NAME)
	print("Audio streams: open=%s close=%s crickets=%s weather_loops=%s thunder=%s ambient_tracks=%d boot=%s" % [
		str(_sfx_door_open != null and _sfx_door_open.stream != null),
		str(_sfx_door_close != null and _sfx_door_close.stream != null),
		str(_sfx_crickets != null and _sfx_crickets.stream != null),
		str(
			_sfx_weather_wind != null and _sfx_weather_wind.stream != null
			and _sfx_weather_calm_rain != null and _sfx_weather_calm_rain.stream != null
			and _sfx_weather_rain != null and _sfx_weather_rain.stream != null
			and _sfx_weather_rain_storm != null and _sfx_weather_rain_storm.stream != null
			and _sfx_weather_wind_storm != null and _sfx_weather_wind_storm.stream != null
		),
		str(
			_sfx_thunder_near_a != null and _sfx_thunder_near_a.stream != null
			and _sfx_thunder_near_b != null and _sfx_thunder_near_b.stream != null
			and _sfx_thunder_far != null and _sfx_thunder_far.stream != null
		),
		_ambient_music_tracks.size(),
		str(boot != null and boot.stream != null),
	])
	_play_sfx(boot)


func process_runtime(
	delta: float,
	weather_state: int,
	should_duck_outdoor_ambience: bool,
	should_play_rain_inside: bool = false,
	is_service_sewer_active: bool = false
) -> void:
	_update_weather_layers(delta, weather_state, should_play_rain_inside, should_duck_outdoor_ambience)
	_update_storm_thunder(delta, weather_state)
	_update_redneck_wind_short(delta, weather_state)
	_update_toilet_ambience(delta)
	_update_dynamic_ambience_layers(delta, should_duck_outdoor_ambience, is_service_sewer_active)
	_update_night_wildlife(delta)
	_update_random_bird_calls(delta, weather_state, should_duck_outdoor_ambience)
	_update_random_cricket_variants(delta)
	_update_interior_audio_ducking(should_duck_outdoor_ambience)


func consume_storm_flash_strength() -> float:
	var strength = _pending_storm_flash_strength
	_pending_storm_flash_strength = 0.0
	return strength


func refresh_ambient_audio(hour_of_day: float, allow_morning_chime: bool = true) -> void:
	var previous_hour = _time_of_day_hours
	_time_of_day_hours = _normalize_hour(hour_of_day)
	_update_ambient_audio()
	if allow_morning_chime:
		_try_play_morning_chime(previous_hour, _time_of_day_hours)


func try_roll_evening_ambient_music(day_index: int, time_of_day_label: String) -> void:
	if _ambient_music_roll_day == day_index:
		return
	_ambient_music_roll_day = day_index
	if _sfx_ambient_music == null or _ambient_music_tracks.is_empty():
		print("Ambient OST roll skipped (missing player/tracks) day=%d time=%s" % [day_index, time_of_day_label])
		return

	var roll = _ambient_music_rng.randf()
	if roll > AMBIENT_MUSIC_TRIGGER_CHANCE:
		print("Ambient OST roll FAIL day=%d time=%s roll=%.3f chance=%.2f" % [
			day_index,
			time_of_day_label,
			roll,
			AMBIENT_MUSIC_TRIGGER_CHANCE
		])
		return

	var track_index = _ambient_music_rng.randi_range(0, _ambient_music_tracks.size() - 1)
	var selected_track = _ambient_music_tracks[track_index] as AudioStream
	if selected_track == null:
		print("Ambient OST roll PASS but selected track is null (idx=%d)." % track_index)
		return

	if _sfx_ambient_music.playing:
		_sfx_ambient_music.stop()
	_sfx_ambient_music.stream = selected_track
	_sfx_ambient_music.volume_db = AMBIENT_MUSIC_SILENT_DB
	_sfx_ambient_music.play()
	_fade_ambient_music_to(AMBIENT_MUSIC_VOLUME_DB, false)
	var track_name = "unknown"
	if track_index >= 0 and track_index < _ambient_music_track_names.size():
		track_name = str(_ambient_music_track_names[track_index])
	print("Ambient OST roll PASS day=%d time=%s roll=%.3f track=%s" % [
		day_index,
		time_of_day_label,
		roll,
		track_name
	])


func play_door_open() -> void:
	if _sfx_door_open == null:
		_sfx_door_open = _create_sfx_player("DoorOpenSfx", SFX_DOOR_OPEN_PATH, false, -1.0, MASTER_BUS_NAME)
	_play_one_shot_sfx(_sfx_door_open, SFX_DOOR_OPEN_PATH)


func play_door_close() -> void:
	if _sfx_door_close == null:
		_sfx_door_close = _create_sfx_player("DoorCloseSfx", SFX_DOOR_CLOSE_PATH, false, -1.0, MASTER_BUS_NAME)
	_play_one_shot_sfx(_sfx_door_close, SFX_DOOR_CLOSE_PATH)


func get_ambient_music_trigger_hour() -> float:
	return AMBIENT_MUSIC_TRIGGER_HOUR


func get_crickets_start_hour() -> float:
	return CRICKETS_START_HOUR


func get_crickets_end_hour() -> float:
	return CRICKETS_END_HOUR


func _setup_ambient_music() -> void:
	_sfx_ambient_music = AudioStreamPlayer.new()
	_sfx_ambient_music.name = "AmbientMusicSfx"
	_sfx_ambient_music.volume_db = AMBIENT_MUSIC_SILENT_DB
	# Keep OST level stable indoors/outdoors; only ambience SFX should be ducked in interiors.
	_sfx_ambient_music.bus = MASTER_BUS_NAME
	if _sfx_bus != null:
		_sfx_bus.add_child(_sfx_ambient_music)
	else:
		add_child(_sfx_ambient_music)

	_ambient_music_tracks.clear()
	_ambient_music_track_names.clear()
	var seen_paths: Dictionary = {}
	var preferred_paths: Array[String] = [
		SFX_AMBIENCE_CALM_PATH,
		SFX_AMBIENCE_EERIE_PATH,
		SFX_AMBIENCE_LES_PATH,
	]
	for path in preferred_paths:
		_append_ambient_track(path, seen_paths)
	for discovered in _collect_audio_paths_in_dir("res://assets/sfx/ost"):
		_append_ambient_track(discovered, seen_paths)

	if _ambient_music_tracks.is_empty():
		push_warning("Ambient OST disabled: no tracks loaded.")
	else:
		print("Ambient OST loaded tracks: %d" % _ambient_music_tracks.size())


func _append_ambient_track(res_path: String, seen_paths: Dictionary) -> void:
	if res_path.is_empty() or seen_paths.has(res_path):
		return
	seen_paths[res_path] = true
	var track = _load_stream_with_fallback(res_path)
	if track == null:
		push_warning("Ambient OST track not loaded: %s" % res_path)
		return
	_ambient_music_tracks.append(track)
	_ambient_music_track_names.append(res_path.get_file())


func _collect_audio_paths_in_dir(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result

	var normalized_dir = dir_path.trim_suffix("/")
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		var lower = file_name.to_lower()
		if not (lower.ends_with(".mp3") or lower.ends_with(".wav") or lower.ends_with(".ogg")):
			continue
		result.append("%s/%s" % [normalized_dir, file_name])
	dir.list_dir_end()
	result.sort()
	return result


func _setup_weather_layers() -> void:
	_sfx_weather_wind = _create_sfx_player("WeatherWindLoop", SFX_WEATHER_WIND_PATH, true, WEATHER_LOOP_SILENT_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_weather_calm_rain = _create_sfx_player("WeatherCalmRainLoop", SFX_WEATHER_CALM_RAIN_PATH, true, WEATHER_LOOP_SILENT_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_weather_rain = _create_sfx_player("WeatherRainLoop", SFX_WEATHER_RAIN_PATH, true, WEATHER_LOOP_SILENT_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_weather_rain_inside = _create_sfx_player("WeatherRainInsideLoop", SFX_WEATHER_RAIN_INSIDE_PATH, true, WEATHER_LOOP_SILENT_DB, MASTER_BUS_NAME)
	_sfx_weather_rain_storm = _create_sfx_player("WeatherRainStormLoop", SFX_WEATHER_RAIN_STORM_PATH, true, WEATHER_LOOP_SILENT_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_weather_wind_storm = _create_sfx_player("WeatherWindStormLoop", SFX_WEATHER_WIND_STORM_PATH, true, WEATHER_LOOP_SILENT_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_thunder_near_a = _create_spatial_sfx_player("ThunderNearA", SFX_WEATHER_THUNDER_NEAR_A_PATH, WEATHER_THUNDER_NEAR_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_thunder_near_b = _create_spatial_sfx_player("ThunderNearB", SFX_WEATHER_THUNDER_NEAR_B_PATH, WEATHER_THUNDER_NEAR_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_thunder_far = _create_spatial_sfx_player("ThunderFar", SFX_WEATHER_THUNDER_FAR_PATH, WEATHER_THUNDER_FAR_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	if _sfx_weather_rain != null and _sfx_weather_rain.stream == null and _sfx_weather_calm_rain != null and _sfx_weather_calm_rain.stream != null:
		push_warning("Weather rain loop missing, using calmrain fallback.")
		_sfx_weather_rain.stream = _sfx_weather_calm_rain.stream

	var weather_loops: Array = [
		_sfx_weather_wind,
		_sfx_weather_calm_rain,
		_sfx_weather_rain,
		_sfx_weather_rain_inside,
		_sfx_weather_rain_storm,
		_sfx_weather_wind_storm,
	]
	for p in weather_loops:
		var player = p as AudioStreamPlayer
		if player != null:
			player.volume_db = WEATHER_LOOP_SILENT_DB

	_configure_thunder_player(_sfx_thunder_near_a, 120.0, 7.0)
	_configure_thunder_player(_sfx_thunder_near_b, 120.0, 7.0)
	_configure_thunder_player(_sfx_thunder_far, 260.0, 12.0)


func _setup_dynamic_ambience_layers() -> void:
	_sfx_day_ambience = _create_sfx_player(
		"DayAmbienceLoop",
		SFX_AMBIENCE_DAY_PATH,
		true,
		AMBIENCE_LOOP_SILENT_DB,
		OUTDOOR_AMBIENCE_BUS_NAME
	)
	_sfx_dusk_birds = _create_sfx_player(
		"DuskBirdsLoop",
		SFX_AMBIENCE_DUSK_BIRDS_PATH,
		true,
		AMBIENCE_LOOP_SILENT_DB,
		OUTDOOR_AMBIENCE_BUS_NAME
	)
	_sfx_lake_insects = _create_sfx_player(
		"LakeInsectsLoop",
		SFX_AMBIENCE_LAKE_INSECTS_PATH,
		true,
		AMBIENCE_LOOP_SILENT_DB,
		OUTDOOR_AMBIENCE_BUS_NAME
	)
	_sfx_pipes_ambience = _create_sfx_player(
		"PipesAmbienceLoop",
		SFX_AMBIENCE_PIPES_PATH,
		true,
		AMBIENCE_LOOP_SILENT_DB,
		MASTER_BUS_NAME
	)
	var ambience_loops: Array[AudioStreamPlayer] = [
		_sfx_day_ambience,
		_sfx_dusk_birds,
		_sfx_lake_insects,
		_sfx_pipes_ambience,
	]
	for player in ambience_loops:
		if player == null or player.stream == null:
			continue
		player.volume_db = AMBIENCE_LOOP_SILENT_DB
		if player.playing:
			player.stop()


func _setup_redneck_ambience_layers() -> void:
	_sfx_redneck_wind_short = _create_spatial_sfx_player("RedneckWindShort", SFX_REDNECK_WIND_SHORT_PATH, REDNECK_WIND_SHORT_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_toilet_flies = _create_spatial_sfx_player("ToiletFliesLoop", SFX_REDNECK_FLIES_PATH, TOILET_FLIES_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME, true)
	_sfx_toilet_misc = _create_spatial_sfx_player("ToiletMiscRandom", SFX_REDNECK_FART_1_PATH, TOILET_MISC_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_night_owl = _create_spatial_sfx_player("NightOwlRandom", SFX_REDNECK_OWL_PATH, NIGHT_WILDLIFE_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)
	_sfx_night_zabascary = _create_spatial_sfx_player("NightZabaScaryRandom", SFX_REDNECK_ZABASCARY_PATH, NIGHT_WILDLIFE_VOLUME_DB, OUTDOOR_AMBIENCE_BUS_NAME)

	_configure_spatial_player(_sfx_redneck_wind_short, 26.0, 4.2)
	_configure_spatial_player(_sfx_toilet_flies, 7.4, 1.75)
	_configure_spatial_player(_sfx_toilet_misc, 8.2, 1.85)
	_configure_spatial_player(_sfx_night_owl, 22.0, 3.8)
	_configure_spatial_player(_sfx_night_zabascary, 22.0, 3.8)

	_toilet_misc_tracks.clear()
	var toilet_misc_paths = [
		SFX_REDNECK_FART_1_PATH,
		SFX_REDNECK_FART_2_PATH,
		SFX_REDNECK_FART_3_PATH,
		SFX_REDNECK_PISS_1_PATH,
		SFX_REDNECK_PISS_2_PATH,
		SFX_REDNECK_PISS_3_PATH,
	]
	for res_path in toilet_misc_paths:
		var track = _load_stream_with_fallback(res_path)
		if track == null:
			push_warning("Toilet ambience track not loaded: %s" % res_path)
			continue
		_toilet_misc_tracks.append(track)

	if _toilet_misc_tracks.is_empty():
		push_warning("Toilet random ambience disabled: no fart/piss tracks loaded.")


func _configure_thunder_player(player: AudioStreamPlayer3D, max_distance: float, unit_size: float) -> void:
	_configure_spatial_player(player, max_distance, unit_size)


func _configure_spatial_player(player: AudioStreamPlayer3D, max_distance: float, unit_size: float) -> void:
	if player == null:
		return
	player.max_distance = max_distance
	player.unit_size = unit_size


func _create_sfx_player(
	node_name: String,
	stream_path: String,
	looping: bool,
	volume_db: float,
	bus_name: String
) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = volume_db
	p.bus = bus_name
	var stream = _load_stream_with_fallback(stream_path)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = looping
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looping
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	p.stream = stream
	if _sfx_bus != null:
		_sfx_bus.add_child(p)
	else:
		add_child(p)
	return p


func _create_spatial_sfx_player(
	node_name: String,
	stream_path: String,
	volume_db: float,
	bus_name: String,
	looping: bool = false
) -> AudioStreamPlayer3D:
	var p = AudioStreamPlayer3D.new()
	p.name = node_name
	p.volume_db = volume_db
	p.bus = bus_name
	p.max_distance = 22.0
	p.unit_size = 3.6
	var stream = _load_stream_with_fallback(stream_path)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = looping
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looping
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	p.stream = stream
	if _spatial_sfx_root != null:
		_spatial_sfx_root.add_child(p)
	else:
		add_child(p)
	return p


func _load_stream_with_fallback(primary_path: String) -> AudioStream:
	var primary = _try_load_stream(primary_path)
	if primary != null:
		return primary

	var base = primary_path.get_basename()
	var fallback_exts = ["ogg", "wav", "mp3"]
	for ext in fallback_exts:
		var candidate = "%s.%s" % [base, ext]
		var alt = _try_load_stream(candidate)
		if alt != null:
			return alt
	return null


func _try_load_stream(res_path: String) -> AudioStream:
	if res_path.is_empty():
		return null
	# Avoid noisy engine errors on missing resources.
	var abs_path = ProjectSettings.globalize_path(res_path)
	var has_imported_resource = ResourceLoader.exists(res_path, "AudioStream")
	var has_source_file = FileAccess.file_exists(abs_path)
	if not has_imported_resource and not has_source_file:
		return null
	# Prefer Godot-imported resources first. This supports large streams without raw fallback.
	if has_imported_resource:
		var stream = load(res_path) as AudioStream
		if stream != null:
			return stream
	if _is_stream_source_oversized(res_path):
		_warn_oversized_stream_once(res_path)
		return null
	return _load_audio_raw(res_path)


func _is_stream_source_oversized(res_path: String) -> bool:
	if MAX_STREAM_SOURCE_BYTES <= 0:
		return false
	if _stream_source_size_cache.has(res_path):
		return int(_stream_source_size_cache[res_path]) > MAX_STREAM_SOURCE_BYTES
	var abs_path = ProjectSettings.globalize_path(res_path)
	var source_size := -1
	if FileAccess.file_exists(abs_path):
		var file := FileAccess.open(abs_path, FileAccess.READ)
		if file != null:
			source_size = file.get_length()
			file.close()
	_stream_source_size_cache[res_path] = source_size
	return source_size > MAX_STREAM_SOURCE_BYTES


func _warn_oversized_stream_once(res_path: String) -> void:
	if _oversized_stream_warned.has(res_path):
		return
	_oversized_stream_warned[res_path] = true
	var source_size = int(_stream_source_size_cache.get(res_path, -1))
	push_warning(
		"Skipping oversized audio stream on startup: %s (%d MB > %d MB)." % [
			res_path,
			int(source_size / (1024 * 1024)),
			int(MAX_STREAM_SOURCE_BYTES / (1024 * 1024))
		]
	)


func _load_audio_raw(res_path: String) -> AudioStream:
	var ext = res_path.get_extension().to_lower()
	var abs_path = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null

	if ext == "mp3":
		var bytes = FileAccess.get_file_as_bytes(abs_path)
		if bytes.is_empty():
			return null
		var mp3 = AudioStreamMP3.new()
		mp3.data = bytes
		return mp3

	if ext == "wav":
		return _load_wav_stream(abs_path)

	return null


func _load_wav_stream(abs_path: String) -> AudioStreamWAV:
	var bytes = FileAccess.get_file_as_bytes(abs_path)
	if bytes.size() < 44:
		return null
	if not _bytes_match_tag(bytes, 0, [0x52, 0x49, 0x46, 0x46]): # RIFF
		return null
	if not _bytes_match_tag(bytes, 8, [0x57, 0x41, 0x56, 0x45]): # WAVE
		return null

	var audio_format := 0
	var channels := 1
	var sample_rate := 44100
	var bits_per_sample := 16
	var data_offset := -1
	var data_size := 0
	var fmt_found := false
	var data_found := false
	var cursor := 12

	while cursor + 8 <= bytes.size():
		var chunk_size = _read_u32_le(bytes, cursor + 4)
		var chunk_data_start = cursor + 8
		var chunk_data_end = chunk_data_start + chunk_size
		if chunk_data_end > bytes.size():
			break

		if _bytes_match_tag(bytes, cursor, [0x66, 0x6D, 0x74, 0x20]) and chunk_size >= 16: # fmt
			audio_format = _read_u16_le(bytes, chunk_data_start)
			channels = max(_read_u16_le(bytes, chunk_data_start + 2), 1)
			sample_rate = max(_read_u32_le(bytes, chunk_data_start + 4), 8000)
			bits_per_sample = _read_u16_le(bytes, chunk_data_start + 14)
			fmt_found = true
		elif _bytes_match_tag(bytes, cursor, [0x64, 0x61, 0x74, 0x61]): # data
			data_offset = chunk_data_start
			data_size = chunk_size
			data_found = true

		cursor = chunk_data_end + (chunk_size % 2)

	if not fmt_found or not data_found or data_offset < 0 or data_size <= 0:
		return null

	var pcm16 = PackedByteArray()

	if audio_format == 1: # PCM integer
		if bits_per_sample == 16:
			pcm16 = _copy_bytes_range(bytes, data_offset, data_size)
		elif bits_per_sample == 8:
			pcm16.resize(data_size * 2)
			for i in range(data_size):
				var centered = int(bytes[data_offset + i]) - 128
				var s16 = centered << 8
				var encoded = s16 if s16 >= 0 else s16 + 65536
				pcm16[(i * 2)] = encoded & 0xFF
				pcm16[(i * 2) + 1] = (encoded >> 8) & 0xFF
		else:
			return null
	elif audio_format == 3 and bits_per_sample == 32: # IEEE float
		var float_bytes = _copy_bytes_range(bytes, data_offset, data_size)
		var reader = StreamPeerBuffer.new()
		reader.big_endian = false
		reader.data_array = float_bytes
		reader.seek(0)
		var sample_count = int(floor(float(data_size) / 4.0))
		pcm16.resize(sample_count * 2)
		for i in range(sample_count):
			var f = clamp(reader.get_float(), -1.0, 1.0)
			var s16 = int(round(f * 32767.0))
			var encoded = s16 if s16 >= 0 else s16 + 65536
			pcm16[(i * 2)] = encoded & 0xFF
			pcm16[(i * 2) + 1] = (encoded >> 8) & 0xFF
	else:
		return null

	var wav = AudioStreamWAV.new()
	wav.mix_rate = sample_rate
	wav.stereo = (channels >= 2)
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.data = pcm16
	return wav


func _copy_bytes_range(bytes: PackedByteArray, start: int, count: int) -> PackedByteArray:
	if start < 0 or count <= 0 or start >= bytes.size():
		return PackedByteArray()
	var safe_end = min(start + count, bytes.size())
	var out = PackedByteArray()
	out.resize(safe_end - start)
	for i in range(safe_end - start):
		out[i] = bytes[start + i]
	return out


func _bytes_match_tag(bytes: PackedByteArray, offset: int, tag: Array) -> bool:
	if offset < 0 or offset + tag.size() > bytes.size():
		return false
	for i in range(tag.size()):
		if int(bytes[offset + i]) != tag[i]:
			return false
	return true


func _read_u16_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 2 > bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


func _read_u32_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > bytes.size():
		return 0
	return (
		int(bytes[offset])
		| (int(bytes[offset + 1]) << 8)
		| (int(bytes[offset + 2]) << 16)
		| (int(bytes[offset + 3]) << 24)
	)


func _play_sfx(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.play()


func _play_one_shot_sfx(player: AudioStreamPlayer, fallback_stream_path: String) -> void:
	if player == null:
		return
	if player.stream == null and not fallback_stream_path.is_empty():
		player.stream = _load_stream_with_fallback(fallback_stream_path)
	if player.stream == null:
		push_warning("One-shot SFX missing stream: %s" % fallback_stream_path)
		return
	# Restart even if the previous one-shot is still finishing, so repeated door
	# interactions always produce a deterministic click/open-close response.
	if player.playing:
		player.stop()
	player.seek(0.0)
	player.play()


func _update_ambient_audio() -> void:
	var should_play = _is_hour_in_window(_time_of_day_hours, CRICKETS_START_HOUR, CRICKETS_END_HOUR)
	if _sfx_crickets != null and _sfx_crickets.stream != null:
		if should_play:
			if not _sfx_crickets.playing:
				_sfx_crickets.play()
			_fade_crickets_to(CRICKETS_ACTIVE_DB, false)
		else:
			if _sfx_crickets.playing:
				_fade_crickets_to(CRICKETS_SILENT_DB, true)
	if _sfx_ambient_music != null and _sfx_ambient_music.stream != null:
		if should_play and _sfx_ambient_music.playing:
			_fade_ambient_music_to(AMBIENT_MUSIC_VOLUME_DB, false)
		elif not should_play and _sfx_ambient_music.playing:
			_fade_ambient_music_to(AMBIENT_MUSIC_SILENT_DB, true)


func _update_random_bird_calls(delta: float, weather_state: int, should_duck_outdoor_ambience: bool) -> void:
	if _sfx_bird == null or _sfx_bird.stream == null:
		return
	if _is_weather_sound_hostile_for_birds(weather_state) or should_duck_outdoor_ambience:
		return
	if not _is_hour_in_window(_time_of_day_hours, BIRD_START_HOUR, BIRD_END_HOUR):
		return
	_bird_call_cooldown_seconds = max(0.0, _bird_call_cooldown_seconds - max(delta, 0.0))
	if _bird_call_cooldown_seconds > 0.0:
		return
	if _sfx_bird.playing:
		return
	_sfx_bird.pitch_scale = _ambient_music_rng.randf_range(BIRD_PITCH_MIN, BIRD_PITCH_MAX)
	_sfx_bird.play()
	_schedule_next_bird_call(false)


func _is_weather_sound_hostile_for_birds(weather_state: int) -> bool:
	return (
		weather_state == WEATHER_WINDY
		or weather_state == WEATHER_LIGHT_RAIN
		or weather_state == WEATHER_RAIN
		or weather_state == WEATHER_STORM
		or weather_state == WEATHER_EVENT
	)


func _update_redneck_wind_short(delta: float, weather_state: int) -> void:
	if _sfx_redneck_wind_short == null or _sfx_redneck_wind_short.stream == null:
		return
	var windy_active = (weather_state == WEATHER_WINDY)
	if not windy_active:
		_redneck_wind_short_active = false
		_redneck_wind_short_cooldown_seconds = 0.0
		return

	if not _redneck_wind_short_active:
		_redneck_wind_short_active = true
		_schedule_next_redneck_wind_short_call(true)

	_redneck_wind_short_cooldown_seconds = max(0.0, _redneck_wind_short_cooldown_seconds - max(delta, 0.0))
	if _redneck_wind_short_cooldown_seconds > 0.0:
		return
	if _sfx_redneck_wind_short.playing:
		return

	_sfx_redneck_wind_short.pitch_scale = _ambient_music_rng.randf_range(REDNECK_WIND_SHORT_PITCH_MIN, REDNECK_WIND_SHORT_PITCH_MAX)
	_place_spatial_player_around_listener(
		_sfx_redneck_wind_short,
		REDNECK_WIND_SHORT_MIN_RADIUS,
		REDNECK_WIND_SHORT_MAX_RADIUS,
		REDNECK_WIND_SHORT_MIN_HEIGHT,
		REDNECK_WIND_SHORT_MAX_HEIGHT
	)
	_sfx_redneck_wind_short.play()
	_schedule_next_redneck_wind_short_call(false)


func _schedule_next_redneck_wind_short_call(initial: bool) -> void:
	var min_interval = REDNECK_WIND_SHORT_MIN_INTERVAL_SECONDS
	var max_interval = REDNECK_WIND_SHORT_MAX_INTERVAL_SECONDS
	if initial:
		min_interval = REDNECK_WIND_SHORT_INITIAL_MIN_INTERVAL_SECONDS
		max_interval = REDNECK_WIND_SHORT_INITIAL_MAX_INTERVAL_SECONDS
	_redneck_wind_short_cooldown_seconds = _ambient_music_rng.randf_range(min_interval, max_interval)


func _update_toilet_ambience(delta: float) -> void:
	if _sfx_toilet_flies == null or _sfx_toilet_flies.stream == null:
		return
	var toilet_info = _find_nearest_toilet_world_position()
	if not bool(toilet_info.get("found", false)):
		_toilet_misc_active = false
		_toilet_misc_cooldown_seconds = 0.0
		if _sfx_toilet_flies.playing:
			_sfx_toilet_flies.stop()
		if _sfx_toilet_misc != null and _sfx_toilet_misc.playing:
			_sfx_toilet_misc.stop()
		return

	var toilet_pos = toilet_info.get("position", Vector3.ZERO) as Vector3
	_sfx_toilet_flies.global_position = toilet_pos + Vector3(0.0, 0.42, 0.0)
	if not _sfx_toilet_flies.playing:
		_sfx_toilet_flies.play()

	if _sfx_toilet_misc == null or _sfx_toilet_misc.stream == null or _toilet_misc_tracks.is_empty():
		return
	if not _toilet_misc_active:
		_toilet_misc_active = true
		_schedule_next_toilet_misc_call(true)

	_toilet_misc_cooldown_seconds = max(0.0, _toilet_misc_cooldown_seconds - max(delta, 0.0))
	if _toilet_misc_cooldown_seconds > 0.0:
		return
	if _sfx_toilet_misc.playing:
		return

	_play_toilet_misc_call(toilet_pos)
	_schedule_next_toilet_misc_call(false)


func _schedule_next_toilet_misc_call(initial: bool) -> void:
	var min_interval = TOILET_MISC_MIN_INTERVAL_SECONDS
	var max_interval = TOILET_MISC_MAX_INTERVAL_SECONDS
	if initial:
		min_interval = TOILET_MISC_INITIAL_MIN_INTERVAL_SECONDS
		max_interval = TOILET_MISC_INITIAL_MAX_INTERVAL_SECONDS
	_toilet_misc_cooldown_seconds = _ambient_music_rng.randf_range(min_interval, max_interval)


func _play_toilet_misc_call(toilet_pos: Vector3) -> void:
	if _sfx_toilet_misc == null or _toilet_misc_tracks.is_empty():
		return
	var track_index = _ambient_music_rng.randi_range(0, _toilet_misc_tracks.size() - 1)
	var track = _toilet_misc_tracks[track_index] as AudioStream
	if track == null:
		return
	_sfx_toilet_misc.stream = track
	_sfx_toilet_misc.pitch_scale = _ambient_music_rng.randf_range(TOILET_MISC_PITCH_MIN, TOILET_MISC_PITCH_MAX)
	var angle = _ambient_music_rng.randf_range(0.0, TAU)
	var radius = _ambient_music_rng.randf_range(TOILET_MISC_MIN_RADIUS, TOILET_MISC_MAX_RADIUS)
	var height = _ambient_music_rng.randf_range(TOILET_MISC_MIN_HEIGHT, TOILET_MISC_MAX_HEIGHT)
	_sfx_toilet_misc.global_position = toilet_pos + Vector3(cos(angle) * radius, height, sin(angle) * radius)
	_sfx_toilet_misc.play()


func _update_dynamic_ambience_layers(
	delta: float,
	should_duck_outdoor_ambience: bool,
	is_service_sewer_active: bool
) -> void:
	var outside_active = not should_duck_outdoor_ambience
	var day_ambience_active = (
		outside_active
		and _is_hour_in_window(_time_of_day_hours, BALANCE_CONFIG.DAY_START_HOUR, AMBIENCE_NIGHT_START_HOUR)
	)
	var dusk_birds_active = outside_active and _is_hour_in_window(_time_of_day_hours, DUSK_BIRDS_START_HOUR, DUSK_BIRDS_END_HOUR)
	var lake_window_active = outside_active and _is_hour_in_window(_time_of_day_hours, LAKE_INSECTS_START_HOUR, LAKE_INSECTS_END_HOUR)
	if not lake_window_active:
		_lake_proximity_is_active = false
		_lake_proximity_check_cooldown_seconds = 0.0
	else:
		_lake_proximity_check_cooldown_seconds = max(0.0, _lake_proximity_check_cooldown_seconds - max(delta, 0.0))
		if _lake_proximity_check_cooldown_seconds <= 0.0:
			_lake_proximity_is_active = _is_listener_near_lake_tiles(LAKE_INSECTS_TILE_RADIUS)
			_lake_proximity_check_cooldown_seconds = LAKE_INSECTS_CHECK_INTERVAL_SECONDS
	var lake_insects_active = (
		lake_window_active
		and _lake_proximity_is_active
	)
	var pipes_active = is_service_sewer_active

	_update_ambience_loop(_sfx_day_ambience, day_ambience_active, DAY_AMBIENCE_ACTIVE_DB, delta)
	_update_ambience_loop(_sfx_dusk_birds, dusk_birds_active, DUSK_BIRDS_ACTIVE_DB, delta)
	_update_ambience_loop(_sfx_lake_insects, lake_insects_active, LAKE_INSECTS_ACTIVE_DB, delta)
	_update_ambience_loop(_sfx_pipes_ambience, pipes_active, PIPES_AMBIENCE_ACTIVE_DB, delta)


func _update_ambience_loop(player: AudioStreamPlayer, should_be_active: bool, target_db: float, delta: float) -> void:
	if player == null or player.stream == null:
		return
	if not player.playing:
		if not should_be_active:
			return
		player.volume_db = AMBIENCE_LOOP_SILENT_DB
		player.play()
	var fade_step = _ambience_loop_fade_db_per_second() * max(delta, 0.016)
	if should_be_active:
		player.volume_db = move_toward(player.volume_db, target_db, fade_step)
		return
	player.volume_db = move_toward(player.volume_db, AMBIENCE_LOOP_SILENT_DB, fade_step)
	if player.volume_db <= AMBIENCE_LOOP_SILENT_DB + 0.4:
		player.stop()


func _ambience_loop_fade_db_per_second() -> float:
	var span = abs(PIPES_AMBIENCE_ACTIVE_DB - AMBIENCE_LOOP_SILENT_DB)
	if AMBIENCE_LOOP_FADE_SECONDS <= 0.001:
		return span
	return span / AMBIENCE_LOOP_FADE_SECONDS


func _find_nearest_toilet_world_position() -> Dictionary:
	var scene_tree = get_tree()
	if scene_tree == null:
		return {"found": false}
	var listener = _resolve_listener_origin()
	var nearest_dist_sq = INF
	var nearest_pos = Vector3.ZERO
	for node in scene_tree.get_nodes_in_group("services"):
		var structure = node as Node3D
		if structure == null or not is_instance_valid(structure):
			continue
		var building_type = str(structure.get_meta("building_type", ""))
		if building_type != "toilet_block":
			continue
		var dist_sq = listener.distance_squared_to(structure.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_pos = structure.global_position
	if nearest_dist_sq == INF:
		return {"found": false}
	return {
		"found": true,
		"position": nearest_pos,
	}


func _update_night_wildlife(delta: float) -> void:
	var night_active = _is_night_window_active()
	if not night_active:
		_night_wildlife_active = false
		_night_wildlife_cooldown_seconds = 0.0
		return

	if not _night_wildlife_active:
		_night_wildlife_active = true
		_schedule_next_night_wildlife_call(true)

	_night_wildlife_cooldown_seconds = max(0.0, _night_wildlife_cooldown_seconds - max(delta, 0.0))
	if _night_wildlife_cooldown_seconds > 0.0:
		return

	_play_night_wildlife_call()
	_schedule_next_night_wildlife_call(false)


func _schedule_next_night_wildlife_call(initial: bool) -> void:
	var min_interval = NIGHT_WILDLIFE_MIN_INTERVAL_SECONDS
	var max_interval = NIGHT_WILDLIFE_MAX_INTERVAL_SECONDS
	if initial:
		min_interval = NIGHT_WILDLIFE_INITIAL_MIN_INTERVAL_SECONDS
		max_interval = NIGHT_WILDLIFE_INITIAL_MAX_INTERVAL_SECONDS
	_night_wildlife_cooldown_seconds = _ambient_music_rng.randf_range(min_interval, max_interval)


func _play_night_wildlife_call() -> void:
	var candidates: Array = []
	if _sfx_night_owl != null and _sfx_night_owl.stream != null:
		candidates.append(_sfx_night_owl)
	if _sfx_night_zabascary != null and _sfx_night_zabascary.stream != null:
		candidates.append(_sfx_night_zabascary)
	if candidates.is_empty():
		return
	var selected = candidates[_ambient_music_rng.randi_range(0, candidates.size() - 1)] as AudioStreamPlayer3D
	if selected == null:
		return
	selected.pitch_scale = _ambient_music_rng.randf_range(NIGHT_WILDLIFE_PITCH_MIN, NIGHT_WILDLIFE_PITCH_MAX)
	_place_spatial_player_around_listener(
		selected,
		NIGHT_WILDLIFE_MIN_RADIUS,
		NIGHT_WILDLIFE_MAX_RADIUS,
		NIGHT_WILDLIFE_MIN_HEIGHT,
		NIGHT_WILDLIFE_MAX_HEIGHT
	)
	if selected.playing:
		selected.stop()
	selected.play()


func _is_night_window_active() -> bool:
	return _is_hour_in_window(_time_of_day_hours, CRICKETS_START_HOUR, CRICKETS_END_HOUR)


func _update_random_cricket_variants(delta: float) -> void:
	if _sfx_cricket_variant_a == null or _sfx_cricket_variant_a.stream == null:
		return
	if _sfx_cricket_variant_b == null or _sfx_cricket_variant_b.stream == null:
		return

	if not _is_night_window_active():
		_cricket_variants_were_active = false
		_cricket_variant_a_cooldown_seconds = 0.0
		_cricket_variant_b_cooldown_seconds = 0.0
		return
	if _sfx_crickets != null and _sfx_crickets.stream != null and not _sfx_crickets.playing:
		_sfx_crickets.play()

	if not _cricket_variants_were_active:
		_schedule_next_cricket_variant_call(true, true)
		_schedule_next_cricket_variant_call(false, true)
		_cricket_variants_were_active = true

	_cricket_variant_a_cooldown_seconds = max(0.0, _cricket_variant_a_cooldown_seconds - max(delta, 0.0))
	if _cricket_variant_a_cooldown_seconds <= 0.0 and not _sfx_cricket_variant_a.playing:
		_play_cricket_variant(_sfx_cricket_variant_a)
		_schedule_next_cricket_variant_call(true, false)

	_cricket_variant_b_cooldown_seconds = max(0.0, _cricket_variant_b_cooldown_seconds - max(delta, 0.0))
	if _cricket_variant_b_cooldown_seconds <= 0.0 and not _sfx_cricket_variant_b.playing:
		_play_cricket_variant(_sfx_cricket_variant_b)
		_schedule_next_cricket_variant_call(false, false)


func _schedule_next_cricket_variant_call(is_variant_a: bool, initial: bool) -> void:
	var min_interval = CRICKET_VARIANT_MIN_INTERVAL_SECONDS
	var max_interval = CRICKET_VARIANT_MAX_INTERVAL_SECONDS
	if initial:
		min_interval *= 0.6
		max_interval *= 0.7
	var next_call = _ambient_music_rng.randf_range(min_interval, max_interval)
	if is_variant_a:
		_cricket_variant_a_cooldown_seconds = next_call
	else:
		_cricket_variant_b_cooldown_seconds = next_call


func _play_cricket_variant(player: AudioStreamPlayer3D) -> void:
	if player == null or player.stream == null:
		return
	player.pitch_scale = _ambient_music_rng.randf_range(CRICKET_VARIANT_PITCH_MIN, CRICKET_VARIANT_PITCH_MAX)
	_place_cricket_variant_in_world(player)
	player.play()


func _resolve_listener_origin() -> Vector3:
	var cam = get_viewport().get_camera_3d()
	if cam != null:
		return cam.global_position
	return global_position


func _resolve_grid_manager() -> Node:
	if _grid_manager_ref != null and is_instance_valid(_grid_manager_ref):
		return _grid_manager_ref
	var tree = get_tree()
	if tree == null:
		return null
	var root = tree.current_scene
	if root == null:
		return null
	_grid_manager_ref = _find_node_by_name(root, "GridManager")
	return _grid_manager_ref


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root == null or target_name.is_empty():
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.name == target_name:
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func _is_listener_near_lake_tiles(tile_radius: int) -> bool:
	var gm = _resolve_grid_manager()
	if gm == null:
		return false
	if not gm.has_method("world_to_grid") or not gm.has_method("is_in_bounds") or not gm.has_method("get_tile"):
		return false
	var listener_pos = _resolve_listener_origin()
	var center_coord_variant = gm.call("world_to_grid", listener_pos)
	if typeof(center_coord_variant) != TYPE_VECTOR2I:
		return false
	var center_coord: Vector2i = center_coord_variant
	if not bool(gm.call("is_in_bounds", center_coord)):
		return false
	var radius = max(tile_radius, 0)
	for y in range(center_coord.y - radius, center_coord.y + radius + 1):
		for x in range(center_coord.x - radius, center_coord.x + radius + 1):
			var coord = Vector2i(x, y)
			if not bool(gm.call("is_in_bounds", coord)):
				continue
			var tile = gm.call("get_tile", coord)
			if tile == null:
				continue
			var tile_type = int(tile.tile_type)
			if tile_type == GRID_TILE_TYPE_LAKE:
				return true
	return false


func _place_cricket_variant_in_world(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	_place_spatial_player_around_listener(
		player,
		CRICKET_VARIANT_MIN_RADIUS,
		CRICKET_VARIANT_MAX_RADIUS,
		CRICKET_VARIANT_MIN_HEIGHT,
		CRICKET_VARIANT_MAX_HEIGHT
	)


func _place_spatial_player_around_listener(
	player: AudioStreamPlayer3D,
	min_radius: float,
	max_radius: float,
	min_height: float,
	max_height: float
) -> void:
	if player == null:
		return
	var origin = _resolve_listener_origin()
	var angle = _ambient_music_rng.randf_range(0.0, TAU)
	var radius = _ambient_music_rng.randf_range(max(0.01, min_radius), max(max_radius, min_radius + 0.01))
	var height = _ambient_music_rng.randf_range(min_height, max(max_height, min_height))
	var offset = Vector3(cos(angle) * radius, height, sin(angle) * radius)
	player.global_position = origin + offset


func _schedule_next_bird_call(initial: bool) -> void:
	var min_interval = BIRD_MIN_INTERVAL_SECONDS
	var max_interval = BIRD_MAX_INTERVAL_SECONDS
	if initial:
		min_interval *= 0.75
		max_interval *= 0.75
	_bird_call_cooldown_seconds = _ambient_music_rng.randf_range(min_interval, max_interval)


func _update_weather_layers(
	delta: float,
	weather_state: int,
	should_play_rain_inside: bool,
	should_duck_for_interior: bool
) -> void:
	var windy_active = (weather_state == WEATHER_WINDY or weather_state == WEATHER_RAIN)
	var calm_rain_active = (weather_state == WEATHER_LIGHT_RAIN)
	var rain_active = (weather_state == WEATHER_RAIN)
	var rain_inside_active = (
		should_play_rain_inside
		and (weather_state == WEATHER_LIGHT_RAIN or weather_state == WEATHER_RAIN or weather_state == WEATHER_STORM)
	)
	var storm_rain_active = (weather_state == WEATHER_STORM)
	var storm_wind_active = (weather_state == WEATHER_STORM)
	var interior_weather_duck_db = WEATHER_INTERIOR_DUCK_DB if should_duck_for_interior else 0.0
	var rain_inside_target_db = WEATHER_RAIN_INSIDE_ACTIVE_DB
	if rain_inside_active:
		rain_inside_target_db += WEATHER_RAIN_INSIDE_INTERIOR_BOOST_DB

	_update_weather_loop(_sfx_weather_wind, windy_active, WEATHER_WIND_ACTIVE_DB + interior_weather_duck_db, delta)
	_update_weather_loop(_sfx_weather_calm_rain, calm_rain_active, WEATHER_CALM_RAIN_ACTIVE_DB + interior_weather_duck_db, delta)
	_update_weather_loop(_sfx_weather_rain, rain_active, WEATHER_RAIN_ACTIVE_DB + interior_weather_duck_db, delta)
	_update_weather_loop(_sfx_weather_rain_inside, rain_inside_active, rain_inside_target_db, delta)
	_update_weather_loop(_sfx_weather_rain_storm, storm_rain_active, WEATHER_RAIN_STORM_ACTIVE_DB + interior_weather_duck_db, delta)
	_update_weather_loop(_sfx_weather_wind_storm, storm_wind_active, WEATHER_WIND_STORM_ACTIVE_DB + interior_weather_duck_db, delta)


func _update_weather_loop(player: AudioStreamPlayer, should_be_active: bool, target_db: float, delta: float) -> void:
	if player == null or player.stream == null:
		return
	var fade_step = _weather_loop_fade_db_per_second() * max(delta, 0.016)
	if should_be_active:
		if not player.playing:
			player.play()
		player.volume_db = move_toward(player.volume_db, target_db, fade_step)
		return

	if not player.playing:
		return
	player.volume_db = move_toward(player.volume_db, WEATHER_LOOP_SILENT_DB, fade_step)
	if player.volume_db <= WEATHER_LOOP_SILENT_DB + 0.4:
		player.stop()


func _weather_loop_fade_db_per_second() -> float:
	var span = abs(WEATHER_WIND_STORM_ACTIVE_DB - WEATHER_LOOP_SILENT_DB)
	if WEATHER_LOOP_FADE_SECONDS <= 0.001:
		return span
	return span / WEATHER_LOOP_FADE_SECONDS


func _update_storm_thunder(delta: float, weather_state: int) -> void:
	var storm_active = (weather_state == WEATHER_STORM)
	if not storm_active:
		_storm_thunder_active = false
		_storm_thunder_cooldown_seconds = 0.0
		_pending_storm_flash_strength = 0.0
		return

	if not _storm_thunder_active:
		_storm_thunder_active = true
		_schedule_next_thunder_strike(true)

	_storm_thunder_cooldown_seconds = max(0.0, _storm_thunder_cooldown_seconds - max(delta, 0.0))
	if _storm_thunder_cooldown_seconds > 0.0:
		return

	_play_random_thunder_strike()
	_schedule_next_thunder_strike(false)


func _schedule_next_thunder_strike(initial: bool) -> void:
	var min_interval = WEATHER_THUNDER_MIN_INTERVAL_SECONDS
	var max_interval = WEATHER_THUNDER_MAX_INTERVAL_SECONDS
	if initial:
		min_interval = WEATHER_THUNDER_INITIAL_MIN_INTERVAL_SECONDS
		max_interval = WEATHER_THUNDER_INITIAL_MAX_INTERVAL_SECONDS
	_storm_thunder_cooldown_seconds = _ambient_music_rng.randf_range(min_interval, max_interval)


func _play_random_thunder_strike() -> void:
	var origin = _resolve_listener_origin()
	var angle = _ambient_music_rng.randf_range(0.0, TAU)
	var radius = _ambient_music_rng.randf_range(WEATHER_THUNDER_MIN_RADIUS, WEATHER_THUNDER_MAX_RADIUS)
	var height = _ambient_music_rng.randf_range(WEATHER_THUNDER_MIN_HEIGHT, WEATHER_THUNDER_MAX_HEIGHT)
	var offset = Vector3(cos(angle) * radius, height, sin(angle) * radius)

	var player: AudioStreamPlayer3D = _sfx_thunder_far
	var is_near = radius <= WEATHER_THUNDER_NEAR_RADIUS_THRESHOLD
	if is_near:
		player = _sfx_thunder_near_a if _ambient_music_rng.randf() < 0.5 else _sfx_thunder_near_b

	if player == null or player.stream == null:
		return

	player.global_position = origin + offset
	player.pitch_scale = _ambient_music_rng.randf_range(WEATHER_THUNDER_PITCH_MIN, WEATHER_THUNDER_PITCH_MAX)
	if player.playing:
		player.stop()
	player.play()
	var flash_strength = _thunder_flash_strength_from_distance(radius, is_near)
	_pending_storm_flash_strength = max(_pending_storm_flash_strength, flash_strength)


func _thunder_flash_strength_from_distance(radius: float, is_near: bool) -> float:
	if is_near:
		var near_strength = _ambient_music_rng.randf_range(WEATHER_THUNDER_FLASH_NEAR_MIN, WEATHER_THUNDER_FLASH_NEAR_MAX)
		return clampf(near_strength, 0.0, 1.0)

	var far_strength = _ambient_music_rng.randf_range(WEATHER_THUNDER_FLASH_FAR_MIN, WEATHER_THUNDER_FLASH_FAR_MAX)
	var far_mix = clampf(
		(radius - WEATHER_THUNDER_NEAR_RADIUS_THRESHOLD) / max(WEATHER_THUNDER_MAX_RADIUS - WEATHER_THUNDER_NEAR_RADIUS_THRESHOLD, 0.001),
		0.0,
		1.0
	)
	far_strength = lerpf(far_strength, WEATHER_THUNDER_FLASH_FAR_MIN, far_mix)
	return clampf(far_strength, 0.0, 1.0)


func _is_hour_in_window(hour: float, start_hour: float, end_hour: float) -> bool:
	var h = _normalize_hour(hour)
	var start = _normalize_hour(start_hour)
	var end = _normalize_hour(end_hour)
	if is_equal_approx(start, end):
		return true
	if start < end:
		return h >= start and h < end
	return h >= start or h < end


func _try_play_morning_chime(previous_hour: float, current_hour: float) -> void:
	if not _is_after_first_night():
		return
	if _sfx_morning_chime == null:
		return
	if _sfx_morning_chime.stream == null:
		_sfx_morning_chime.stream = _load_stream_with_fallback(SFX_MORNING_CHIME_PATH)
	if _sfx_morning_chime.stream == null:
		return
	if _has_crossed_hour(previous_hour, current_hour, MORNING_CHIME_HOUR):
		_play_one_shot_sfx(_sfx_morning_chime, SFX_MORNING_CHIME_PATH)


func _is_after_first_night() -> bool:
	if CoreRoot != null and CoreRoot.has_method("get_day"):
		return int(CoreRoot.get_day()) > 1
	return true


func _has_crossed_hour(previous_hour: float, current_hour: float, target_hour: float) -> bool:
	var prev = _normalize_hour(previous_hour)
	var curr = _normalize_hour(current_hour)
	var target = _normalize_hour(target_hour)
	if is_equal_approx(prev, curr):
		return false
	if prev < curr:
		return prev < target and curr >= target
	return prev < target or curr >= target


func _normalize_hour(hour: float) -> float:
	var normalized = fposmod(hour, 24.0)
	if normalized < 0.0:
		normalized += 24.0
	return normalized


func _fade_crickets_to(target_db: float, stop_after: bool) -> void:
	if _sfx_crickets == null:
		return
	if _crickets_fade_tween != null and is_instance_valid(_crickets_fade_tween):
		_crickets_fade_tween.kill()

	_crickets_fade_tween = create_tween()
	_crickets_fade_tween.set_trans(Tween.TRANS_SINE)
	_crickets_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_crickets_fade_tween.tween_property(_sfx_crickets, "volume_db", target_db, CRICKETS_FADE_SECONDS)
	if stop_after:
		_crickets_fade_tween.tween_callback(func():
			if _sfx_crickets == null:
				return
			if _sfx_crickets.playing and _sfx_crickets.volume_db <= CRICKETS_SILENT_DB + 0.5:
				_sfx_crickets.stop()
		)


func _fade_ambient_music_to(target_db: float, stop_after: bool) -> void:
	if _sfx_ambient_music == null:
		return
	if not _sfx_ambient_music.playing and stop_after:
		return
	if _ambient_music_fade_tween != null and is_instance_valid(_ambient_music_fade_tween):
		_ambient_music_fade_tween.kill()
	_ambient_music_fade_tween = create_tween()
	_ambient_music_fade_tween.set_trans(Tween.TRANS_SINE)
	_ambient_music_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_ambient_music_fade_tween.tween_property(_sfx_ambient_music, "volume_db", target_db, AMBIENT_MUSIC_FADE_SECONDS)
	if stop_after:
		_ambient_music_fade_tween.tween_callback(func():
			if _sfx_ambient_music == null:
				return
			if _sfx_ambient_music.playing and _sfx_ambient_music.volume_db <= AMBIENT_MUSIC_SILENT_DB + 0.5:
				_sfx_ambient_music.stop()
		)


func _update_interior_audio_ducking(should_duck: bool) -> void:
	if should_duck == _interior_audio_is_ducked:
		return
	_interior_audio_is_ducked = should_duck
	_ensure_outdoor_ambience_bus()
	if _outdoor_ambience_bus_index < 0 or _outdoor_ambience_bus_index >= AudioServer.get_bus_count():
		return

	if _interior_audio_duck_tween != null and is_instance_valid(_interior_audio_duck_tween):
		_interior_audio_duck_tween.kill()

	var current_db = AudioServer.get_bus_volume_db(_outdoor_ambience_bus_index)
	var target_db = current_db
	if should_duck:
		_interior_audio_base_db = current_db
		target_db = _interior_audio_base_db + INTERIOR_AUDIO_DUCK_DB
	else:
		target_db = _interior_audio_base_db

	_interior_audio_duck_tween = create_tween()
	_interior_audio_duck_tween.set_trans(Tween.TRANS_SINE)
	_interior_audio_duck_tween.set_ease(Tween.EASE_IN_OUT)
	_interior_audio_duck_tween.tween_method(
		Callable(self, "_set_outdoor_ambience_bus_volume_db"),
		current_db,
		target_db,
		INTERIOR_AUDIO_DUCK_FADE_SECONDS
	)


func _set_outdoor_ambience_bus_volume_db(volume_db: float) -> void:
	if _outdoor_ambience_bus_index < 0 or _outdoor_ambience_bus_index >= AudioServer.get_bus_count():
		return
	AudioServer.set_bus_volume_db(_outdoor_ambience_bus_index, volume_db)


func _apply_default_bus_levels() -> void:
	var master_bus_index = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_index >= 0 and master_bus_index < AudioServer.get_bus_count():
		AudioServer.set_bus_volume_db(master_bus_index, MASTER_BUS_DEFAULT_DB)
	if _outdoor_ambience_bus_index >= 0 and _outdoor_ambience_bus_index < AudioServer.get_bus_count():
		AudioServer.set_bus_volume_db(_outdoor_ambience_bus_index, OUTDOOR_AMBIENCE_BUS_DEFAULT_DB)
		_interior_audio_base_db = OUTDOOR_AMBIENCE_BUS_DEFAULT_DB


func _ensure_outdoor_ambience_bus() -> void:
	_outdoor_ambience_bus_index = AudioServer.get_bus_index(OUTDOOR_AMBIENCE_BUS_NAME)
	if _outdoor_ambience_bus_index < 0:
		var insert_index = AudioServer.get_bus_count()
		AudioServer.add_bus(insert_index)
		AudioServer.set_bus_name(insert_index, OUTDOOR_AMBIENCE_BUS_NAME)
		AudioServer.set_bus_send(insert_index, MASTER_BUS_NAME)
		_outdoor_ambience_bus_index = insert_index
		print("Audio bus created: %s (index=%d)" % [OUTDOOR_AMBIENCE_BUS_NAME, insert_index])
