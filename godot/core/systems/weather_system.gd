extends RefCounted
class_name WeatherSystem

# Dependencies
# We might need direct references to Scene nodes for pure logic if they drive visual state heavily.
# But ideally we just expose state and Main.gd applies it.

const WEATHER_CLEAR: int = 0
const WEATHER_WINDY: int = 1
const WEATHER_FOG: int = 2
const WEATHER_LIGHT_RAIN: int = 3
const WEATHER_RAIN: int = 4
const WEATHER_STORM: int = 5
const WEATHER_EVENT: int = 6
const WEATHER_STATE_COUNT: int = 7

var current_weather: int = WEATHER_CLEAR
var _state_duration: float = 0.0
var _target_duration: float = 300.0 # Default 5 mins
var auto_cycle_enabled: bool = false

func _init() -> void:
    _pick_initial_weather()

func process(delta: float) -> void:
    if not auto_cycle_enabled:
        return
    _state_duration += delta
    if _state_duration >= _target_duration:
        _transition_weather()

func _pick_initial_weather() -> void:
    current_weather = WEATHER_CLEAR
    _target_duration = randf_range(120.0, 300.0)

func _transition_weather() -> void:
    var old_weather = current_weather
    
    # Simple Markov chain or random pick logic extracted from original main.gd if it existed, 
    # or just random for now.
    # Logic from main.gd was manual toggle mostly, but let's implement basic flow.
    
    var roll = randf()
    if current_weather == WEATHER_CLEAR:
        if roll < 0.3: current_weather = WEATHER_WINDY
        elif roll < 0.4: current_weather = WEATHER_FOG
        elif roll < 0.45: current_weather = WEATHER_LIGHT_RAIN
    elif current_weather == WEATHER_WINDY:
        if roll < 0.4: current_weather = WEATHER_CLEAR
        elif roll < 0.6: current_weather = WEATHER_LIGHT_RAIN
    elif current_weather == WEATHER_LIGHT_RAIN:
        if roll < 0.4: current_weather = WEATHER_RAIN
        elif roll < 0.8: current_weather = WEATHER_CLEAR
    elif current_weather == WEATHER_RAIN:
        if roll < 0.3: current_weather = WEATHER_STORM
        elif roll < 0.8: current_weather = WEATHER_LIGHT_RAIN
    elif current_weather == WEATHER_STORM:
        if roll < 0.7: current_weather = WEATHER_RAIN
    else:
        current_weather = WEATHER_CLEAR
        
    if current_weather != old_weather:
        _state_duration = 0.0
        _target_duration = randf_range(120.0, 400.0)
        # Notify
        # EventBus.weather_changed.emit(current_weather) # If we add this signal
        pass

func set_weather(weather_type: int) -> void:
    current_weather = weather_type % WEATHER_STATE_COUNT
    _state_duration = 0.0

func set_auto_cycle_enabled(enabled: bool) -> void:
    auto_cycle_enabled = enabled

func get_weather_name() -> String:
    match current_weather:
        WEATHER_CLEAR: return "Clear"
        WEATHER_WINDY: return "Windy"
        WEATHER_FOG: return "Fog"
        WEATHER_LIGHT_RAIN: return "Light Rain"
        WEATHER_RAIN: return "Rain"
        WEATHER_STORM: return "Storm"
        WEATHER_EVENT: return "Event"
    return "Unknown"
