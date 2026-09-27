extends Node

signal settings_changed(current: Dictionary)

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const SETTINGS_PATH := "user://settings.cfg"
const MODE_WINDOWED := "windowed"
const MODE_FULLSCREEN := "fullscreen"
const MODE_BORDERLESS := "borderless"
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DEFAULT_MASTER_DB := 0.0
const DEFAULT_RETRO_PRESET := "build"
const RETRO_PRESETS: Array[String] = ["chunky", "build", "crisp", "svga", "native"]

var _window_mode: String = MODE_WINDOWED
var _resolution: Vector2i = DEFAULT_RESOLUTION
var _master_db: float = DEFAULT_MASTER_DB
var _retro_preset: String = DEFAULT_RETRO_PRESET
var _retro_palette_enabled: bool = true


func _ready() -> void:
	load_settings()
	apply_settings()


func get_supported_resolutions() -> Array[Vector2i]:
	return [
		Vector2i(1024, 576),
		Vector2i(1152, 648),
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]


func get_window_mode() -> String:
	return _window_mode


func get_resolution() -> Vector2i:
	return _resolution


func get_master_volume_db() -> float:
	return _master_db


## Build-engine render preset (see RETRO_RENDER.PRESET_LINES).
func get_retro_preset() -> String:
	return _retro_preset


func get_retro_palette_enabled() -> bool:
	return _retro_palette_enabled


func set_retro_preset(preset: String, persist: bool = true) -> void:
	var normalized := preset.strip_edges().to_lower()
	if not RETRO_PRESETS.has(normalized):
		normalized = DEFAULT_RETRO_PRESET
	_retro_preset = normalized
	_apply_retro()
	if persist:
		save_settings()
	_emit_changed()


func set_retro_palette_enabled(enabled: bool, persist: bool = true) -> void:
	_retro_palette_enabled = enabled
	_apply_retro()
	if persist:
		save_settings()
	_emit_changed()


func set_window_mode(mode: String, apply_now: bool = true, persist: bool = true) -> void:
	var normalized := mode.strip_edges().to_lower()
	if normalized != MODE_WINDOWED and normalized != MODE_FULLSCREEN and normalized != MODE_BORDERLESS:
		normalized = MODE_WINDOWED
	_window_mode = normalized
	if apply_now:
		_apply_window()
	if persist:
		save_settings()
	_emit_changed()


func set_resolution(resolution: Vector2i, apply_now: bool = true, persist: bool = true) -> void:
	_resolution = Vector2i(max(640, resolution.x), max(360, resolution.y))
	if apply_now:
		_apply_window()
	if persist:
		save_settings()
	_emit_changed()


func set_master_volume_db(volume_db: float, apply_now: bool = true, persist: bool = true) -> void:
	_master_db = clampf(volume_db, -40.0, 6.0)
	if apply_now:
		_apply_audio()
	if persist:
		save_settings()
	_emit_changed()


func reset_defaults() -> void:
	_window_mode = MODE_WINDOWED
	_resolution = DEFAULT_RESOLUTION
	_master_db = DEFAULT_MASTER_DB
	_retro_preset = DEFAULT_RETRO_PRESET
	_retro_palette_enabled = true
	apply_settings()
	save_settings()
	_emit_changed()


func apply_settings() -> void:
	_apply_window()
	_apply_audio()
	_apply_retro()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		_window_mode = MODE_WINDOWED
		_resolution = DEFAULT_RESOLUTION
		_master_db = DEFAULT_MASTER_DB
		return

	var mode = str(cfg.get_value("video", "window_mode", MODE_WINDOWED))
	var w = int(cfg.get_value("video", "width", DEFAULT_RESOLUTION.x))
	var h = int(cfg.get_value("video", "height", DEFAULT_RESOLUTION.y))
	var master = float(cfg.get_value("audio", "master_db", DEFAULT_MASTER_DB))
	var retro = str(cfg.get_value("video", "retro_preset", DEFAULT_RETRO_PRESET))
	_retro_preset = retro if RETRO_PRESETS.has(retro) else DEFAULT_RETRO_PRESET
	_retro_palette_enabled = bool(cfg.get_value("video", "retro_palette", true))

	set_window_mode(mode, false, false)
	set_resolution(Vector2i(w, h), false, false)
	set_master_volume_db(master, false, false)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "window_mode", _window_mode)
	cfg.set_value("video", "width", _resolution.x)
	cfg.set_value("video", "height", _resolution.y)
	cfg.set_value("video", "retro_preset", _retro_preset)
	cfg.set_value("video", "retro_palette", _retro_palette_enabled)
	cfg.set_value("audio", "master_db", _master_db)
	cfg.save(SETTINGS_PATH)


func get_snapshot() -> Dictionary:
	return {
		"window_mode": _window_mode,
		"resolution": {"x": _resolution.x, "y": _resolution.y},
		"master_db": _master_db,
		"retro_preset": _retro_preset,
		"retro_palette": _retro_palette_enabled,
	}


func _apply_window() -> void:
	match _window_mode:
		MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(_resolution)


func _apply_audio() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, _master_db)


func _apply_retro() -> void:
	if not is_inside_tree():
		return
	RETRO_RENDER.refresh_all(get_tree())


func _emit_changed() -> void:
	settings_changed.emit(get_snapshot())
