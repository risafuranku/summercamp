extends RefCounted
class_name TimeSystem

const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")
const DAY_START_HOUR: float = BALANCE_CONFIG.DAY_START_HOUR
const EVENING_START_HOUR: float = 18.0
const NIGHT_START_HOUR: float = BALANCE_CONFIG.NIGHT_START_HOUR

# Dependencies
var _state

# Configuration
# Derived from BalanceConfig
# TIME_SCALE = Real seconds per game minute
# Game Hours per Real Second = (1 / TIME_SCALE) / 60
var game_hours_per_real_second: float = (1.0 / BALANCE_CONFIG.TIME_SCALE) / 60.0
const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2

# State
var time_of_day_hours: float = 9.0
var time_state: int = TIME_DAY

func _init(state) -> void:
	_state = state
	# Initialize from state if possible, or set defaults
	_state.day = max(1, _state.day)
	time_of_day_hours = 9.0 # Default start time
	_update_time_state()

func process(delta: float) -> void:
	_advance_time(delta)

func _advance_time(delta: float) -> void:
	var hours_passed = maxf(delta, 0.0) * game_hours_per_real_second
	if hours_passed <= 0.0:
		return
	time_of_day_hours += hours_passed
	
	# Check for day rollover
	while time_of_day_hours >= 24.0:
		time_of_day_hours -= 24.0
		_advance_day()
		
	_update_time_state()
	
	# Emit Tick for UI
	var minute = int((time_of_day_hours - floor(time_of_day_hours)) * 60.0)
	EventBus.time_tick.emit(int(time_of_day_hours), minute)

func _advance_day() -> void:
	_state.day += 1
	EventBus.day_tick.emit(_state.day)

func _update_time_state() -> void:
	var is_night = false
	
	if time_of_day_hours >= NIGHT_START_HOUR or time_of_day_hours < DAY_START_HOUR:
		time_state = TIME_NIGHT
		is_night = true
	elif time_of_day_hours >= EVENING_START_HOUR:
		time_state = TIME_EVENING
		is_night = false
	else:
		time_state = TIME_DAY
		is_night = false
		
	if _state.is_night != is_night:
		_state.is_night = is_night
		if is_night:
			EventBus.night_tick.emit(_state.day)

# Debug/Control methods
func step_time_hours(hours: float) -> void:
	var hours_passed = maxf(hours, 0.0)
	if hours_passed <= 0.0:
		return
	time_of_day_hours += hours_passed
	while time_of_day_hours >= 24.0:
		time_of_day_hours -= 24.0
		_advance_day()
	_update_time_state()
	var minute = int((time_of_day_hours - floor(time_of_day_hours)) * 60.0)
	EventBus.time_tick.emit(int(time_of_day_hours), minute)
	
func set_time_hours(hours: float) -> void:
	time_of_day_hours = fposmod(hours, 24.0)
	if time_of_day_hours < 0.0:
		time_of_day_hours += 24.0
	_update_time_state()

func get_time_string() -> String:
	var h = int(time_of_day_hours)
	var m = int((time_of_day_hours - h) * 60.0)
	return "%02d:%02d" % [h, m]
