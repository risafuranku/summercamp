extends RefCounted
class_name WeatherSystem

## Pure weather state machine. No nodes: main.gd ticks it and applies the result.
##
## Time is in game minutes (TIME_SCALE 1.0 makes one real second one game minute, so
## `process(delta)` with real seconds advances game minutes). Each state lasts a
## random span from STATE_MINUTES, then moves along TRANSITIONS. Time of day bends the
## odds: fog gathers around dawn, storms build in the late afternoon and evening.
##
## The anomaly (WEATHER_EVENT) is never part of the ordinary cycle. It can only roll
## at night, its odds rise with the camp's weirdness (`set_anomaly_pressure`, fed from
## hrotfaktor), it is short, and it does not repeat within ANOMALY_COOLDOWN_MINUTES.
## A strange red haze over a quiet camp means something; it must stay rare.

const WEATHER_CLEAR: int = 0
const WEATHER_WINDY: int = 1
const WEATHER_FOG: int = 2
const WEATHER_LIGHT_RAIN: int = 3
const WEATHER_RAIN: int = 4
const WEATHER_STORM: int = 5
const WEATHER_EVENT: int = 6
const WEATHER_STATE_COUNT: int = 7

## [min, max] game minutes per state.
const STATE_MINUTES := {
	WEATHER_CLEAR: [240.0, 540.0],
	WEATHER_WINDY: [90.0, 240.0],
	WEATHER_FOG: [90.0, 180.0],
	WEATHER_LIGHT_RAIN: [80.0, 170.0],
	WEATHER_RAIN: [90.0, 220.0],
	WEATHER_STORM: [50.0, 110.0],
	WEATHER_EVENT: [30.0, 75.0],
}

## Base weights of the next state. Staying put is handled by the duration roll.
const TRANSITIONS := {
	WEATHER_CLEAR: {WEATHER_WINDY: 42.0, WEATHER_FOG: 16.0, WEATHER_LIGHT_RAIN: 24.0},
	WEATHER_WINDY: {WEATHER_CLEAR: 45.0, WEATHER_LIGHT_RAIN: 35.0, WEATHER_RAIN: 10.0, WEATHER_FOG: 10.0},
	WEATHER_FOG: {WEATHER_CLEAR: 60.0, WEATHER_LIGHT_RAIN: 25.0, WEATHER_WINDY: 15.0},
	WEATHER_LIGHT_RAIN: {WEATHER_CLEAR: 35.0, WEATHER_RAIN: 40.0, WEATHER_WINDY: 15.0, WEATHER_FOG: 10.0},
	WEATHER_RAIN: {WEATHER_LIGHT_RAIN: 55.0, WEATHER_STORM: 30.0, WEATHER_CLEAR: 15.0},
	WEATHER_STORM: {WEATHER_RAIN: 75.0, WEATHER_LIGHT_RAIN: 25.0},
	WEATHER_EVENT: {WEATHER_FOG: 60.0, WEATHER_CLEAR: 40.0},
}

const ANOMALY_NIGHT_START := 21.0
const ANOMALY_NIGHT_END := 4.5
const ANOMALY_BASE_CHANCE := 0.02
const ANOMALY_PRESSURE_CHANCE := 0.25
const ANOMALY_MAX_CHANCE := 0.22
const ANOMALY_COOLDOWN_MINUTES := 1440.0

var current_weather: int = WEATHER_CLEAR
var auto_cycle_enabled: bool = false
var _state_minutes: float = 0.0
var _target_minutes: float = 300.0
var _hour: float = 9.0
var _anomaly_pressure: float = 0.0
var _anomaly_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	current_weather = WEATHER_CLEAR
	_target_minutes = _roll_minutes(WEATHER_CLEAR)


## `delta` in game minutes (main passes real seconds x GAME_MINUTES_PER_SECOND).
## `hour` 0..24 when known.
func process(delta: float, hour: float = -1.0) -> void:
	if hour >= 0.0:
		_hour = fposmod(hour, 24.0)
	if not auto_cycle_enabled:
		return
	_anomaly_cooldown = maxf(0.0, _anomaly_cooldown - delta)
	_state_minutes += delta
	if _state_minutes >= _target_minutes:
		_transition_weather()


## 0..1, the camp's weirdness (hrotfaktor). Only affects the night anomaly roll.
func set_anomaly_pressure(value: float) -> void:
	_anomaly_pressure = clampf(value, 0.0, 1.0)


func set_seed(value: int) -> void:
	_rng.seed = value


func _transition_weather() -> void:
	var next := _pick_next(current_weather)
	_enter(next)


func _pick_next(from_state: int) -> int:
	if from_state != WEATHER_EVENT and _is_anomaly_hour() and _anomaly_cooldown <= 0.0:
		var chance := minf(ANOMALY_MAX_CHANCE, ANOMALY_BASE_CHANCE + _anomaly_pressure * ANOMALY_PRESSURE_CHANCE)
		if _rng.randf() < chance:
			return WEATHER_EVENT
	var weights: Dictionary = (TRANSITIONS.get(from_state, {WEATHER_CLEAR: 1.0}) as Dictionary).duplicate()
	if weights.has(WEATHER_FOG) and _is_hour_between(3.0, 8.5):
		weights[WEATHER_FOG] = float(weights[WEATHER_FOG]) * 3.0
	if weights.has(WEATHER_STORM) and (_hour >= 16.0 or _hour < 2.0):
		weights[WEATHER_STORM] = float(weights[WEATHER_STORM]) * 1.6
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var roll := _rng.randf() * total
	for key in weights.keys():
		roll -= float(weights[key])
		if roll <= 0.0:
			return int(key)
	return WEATHER_CLEAR


func _enter(state: int) -> void:
	current_weather = clampi(state, 0, WEATHER_STATE_COUNT - 1)
	_state_minutes = 0.0
	_target_minutes = _roll_minutes(current_weather)
	if current_weather == WEATHER_EVENT:
		_anomaly_cooldown = ANOMALY_COOLDOWN_MINUTES


func _roll_minutes(state: int) -> float:
	var span: Array = STATE_MINUTES.get(state, [120.0, 240.0])
	return _rng.randf_range(float(span[0]), float(span[1]))


func _is_anomaly_hour() -> bool:
	return _hour >= ANOMALY_NIGHT_START or _hour < ANOMALY_NIGHT_END


func _is_hour_between(a: float, b: float) -> bool:
	return _hour >= a and _hour < b


## Forces a state (debug key, save load, new game) and restarts its duration.
func set_weather(weather_type: int) -> void:
	_enter(posmod(weather_type, WEATHER_STATE_COUNT))


func set_auto_cycle_enabled(enabled: bool) -> void:
	auto_cycle_enabled = enabled


## Minutes left in the current state (for the forecast line in Camp Status).
func get_minutes_left() -> float:
	return maxf(0.0, _target_minutes - _state_minutes)


func is_raining() -> bool:
	return current_weather == WEATHER_LIGHT_RAIN or current_weather == WEATHER_RAIN or current_weather == WEATHER_STORM


func get_weather_name() -> String:
	match current_weather:
		WEATHER_CLEAR: return "Clear"
		WEATHER_WINDY: return "Windy"
		WEATHER_FOG: return "Fog"
		WEATHER_LIGHT_RAIN: return "Drizzle"
		WEATHER_RAIN: return "Rain"
		WEATHER_STORM: return "Storm"
		WEATHER_EVENT: return "Anomaly"
	return "Unknown"
