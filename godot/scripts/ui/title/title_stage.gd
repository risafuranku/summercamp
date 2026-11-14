extends Node

## The title screen's stage (playtest 14. 11.: Richard picked "the reception at dusk", the
## menu in the game itself): the camp's office, the eye behind the counter by the PC, the
## window over the counter with the camp outside in the last of the light. The building
## interior shows its room in its title view (building_interior.set_title_view: the tube
## off, the desk lamp on, the game's title on the CRT); this holds the hour and the weather
## and moves the eye a little, as somebody standing there breathes. The menu
## (scripts/ui/main_menu.gd) is drawn over it, its pages the counter's own things.

const WEATHER_SYSTEM = preload("res://core/systems/weather_system.gd")
## The last of the light: the sky still red over the trees, the camp's lamps coming on.
const HOURS := 19.45
## The eye in the office's room space (ReceptionLayout: the front wall's window over the
## counter at z -2.5, the PC's desk on the left) and the point it looks at.
const EYE := Vector3(-0.2, 1.32, 1.7)
const LOOK := Vector3(-1.2, 1.3, -0.6)
const FOV := 50.0
## The shot as it is (the shot driver tries others).
var eye := EYE
var look := LOOK
var fov := FOV
## The breathing: how far the eye drifts (m) and how long a breath is (s).
const SWAY := Vector3(0.018, 0.01, 0.0)
const SWAY_SEC := 9.0

var main: Node
var _bi
var _open := false
var _t := 0.0
var _snap := 0


func setup(main_node: Node) -> void:
	main = main_node


func is_open() -> bool:
	return _open


## The office as the title: the light set, the room shown, the eye placed.
func open() -> void:
	var im = main.get("_interior_manager") if main != null else null
	_bi = im.get("_building_interior") if im != null else null
	if _bi == null or not _bi.has_method("set_title_view"):
		return
	_hold_light()
	# The clock stopped there (a jump back of it burnt the bonfire's whole day away).
	main.set("clock_scale", 0.0)
	_bi.set_title_view(true)
	_open = true
	_t = 0.0
	_place(0.0)


func close() -> void:
	if not _open:
		return
	_open = false
	main.set("clock_scale", 1.0)
	if _bi != null and is_instance_valid(_bi):
		_bi.set_title_view(false)
	var weather_system = main.get("weather_system")
	if weather_system != null and weather_system.has_method("set_auto_cycle_enabled"):
		weather_system.set_auto_cycle_enabled(true)


## One frame of the title (main calls it in menu mode).
func update(delta: float) -> void:
	if not _open or _bi == null or not is_instance_valid(_bi):
		return
	_t += delta
	var ts = main.get("time_system")
	if ts != null and absf(float(ts.time_of_day_hours) - HOURS) > 0.02:
		_hold_light()
	if _snap > 0:
		_snap -= 1
		if _snap == 0:
			var visuals = main.get("_weather_visuals")
			if visuals != null and visuals.has_method("apply_time_from_clock"):
				visuals.apply_time_from_clock(true)
	_place(_t)


## Dusk, clear: the clock and the weather held there (snapped, not crossfaded).
func _hold_light() -> void:
	var ts = main.get("time_system")
	var ws = main.get("weather_system")
	if ts != null:
		ts.set_time_hours(HOURS)
	if ws != null:
		ws.set_auto_cycle_enabled(false)
		ws.set_weather(WEATHER_SYSTEM.WEATHER_CLEAR)
	if main.has_method("_sync_runtime_state_from_systems"):
		main.call("_sync_runtime_state_from_systems", true)
	_snap = 2


func _place(t: float) -> void:
	var cam: Camera3D = _bi.title_camera()
	if cam == null:
		return
	var s := Vector3(sin(t * TAU / SWAY_SEC) * SWAY.x, sin(t * TAU / (SWAY_SEC * 1.7)) * SWAY.y, 0.0)
	var at := eye + s
	cam.position = at
	cam.rotation = Basis.looking_at(look - at, Vector3.UP).get_euler()
	cam.fov = fov
