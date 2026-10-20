extends CanvasLayer

## The one debug menu (debug builds only; the user 20. 10.: no stray debug keys, one tidy
## menu on L). L opens it, the letters in it do their thing while it is open, L shuts it.
## Closed, none of those letters does anything. In a room L is the room's light, so the
## menu opens outdoors (or is shut from anywhere). The time, the weather and the money
## are read live at the top.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const WEATHER := ["Clear", "Windy", "Fog", "Light rain", "Rain", "Storm", "Event"]
## Key, what it says, what it calls (a method of this script).
const ITEMS := [
	[KEY_T, "+1 hour", "_hour"],
	[KEY_N, "Night / morning", "_night_or_day"],
	[KEY_P, "Next weather", "_weather"],
	[KEY_K, "+$500", "_money"],
	[KEY_H, "Hurt me", "_hurt"],
	[KEY_J, "Night log", "_night_log"],
	[KEY_O, "Night director", "_director"],
	[KEY_M, "Frame time", "_perf"],
]

var main: Node
var _open := false
var _scale := 3
var _panel: Control
var _box: VBoxContainer
var _status: Label
var _perf_on := false
var _tick := 0.0


func _ready() -> void:
	layer = 120
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_box)
	_build()
	get_viewport().size_changed.connect(_build)


func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	_scale = RETRO_UI.ui_scale(vp.y, vp.x)
	_panel.add_theme_stylebox_override("panel", RETRO_UI.flat_box(RETRO_UI.C_PANEL, RETRO_UI.C_AMBER_DIM, _scale, 1, 4))
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_box.add_theme_constant_override("separation", _scale * 2)
	_box.add_child(RETRO_UI.label("DEBUG", RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG, RETRO_UI.C_AMBER, _scale))
	_status = RETRO_UI.label("", RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE_DIM, _scale)
	_box.add_child(_status)
	for it in ITEMS:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", _scale * 4)
		var k := RETRO_UI.label(OS.get_keycode_string(int(it[0])), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER_LIGHT, _scale)
		k.custom_minimum_size.x = _scale * 10
		row.add_child(k)
		row.add_child(RETRO_UI.label(str(it[1]).to_upper(), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE, _scale))
		_box.add_child(row)
	var close := RETRO_UI.label("L  CLOSE", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, _scale)
	_box.add_child(close)
	_panel.position = Vector2(_scale * 6, _scale * 30)
	_refresh()


func _playing() -> bool:
	return main != null and is_instance_valid(main) and main.get("_gameplay_started") == true \
		and main.get("_menu_mode") != true and main.get("_game_over_active") != true and not get_tree().paused


func _in_room() -> bool:
	return main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open"))


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not _playing():
		return
	if key.physical_keycode == KEY_L:
		if _open:
			_set_open(false)
			get_viewport().set_input_as_handled()
		elif not _in_room():
			_set_open(true)
			get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	for it in ITEMS:
		if key.physical_keycode == int(it[0]):
			call(str(it[2]))
			_refresh()
			get_viewport().set_input_as_handled()
			return


func _set_open(on: bool) -> void:
	_open = on
	_panel.visible = on
	_refresh()


func _process(delta: float) -> void:
	if not _open:
		return
	if not _playing():
		_set_open(false)
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_refresh()


func _refresh() -> void:
	if _status == null or main == null or not is_instance_valid(main):
		return
	var h := float(main.get("_time_of_day_hours")) if main.get("_time_of_day_hours") != null else 0.0
	var w := int(main.get("_weather_state")) if main.get("_weather_state") != null else 0
	var money: int = CoreRoot.get_money() if CoreRoot != null else 0
	var line := "%02d:%02d  %s  $%d" % [int(h) % 24, int(fposmod(h, 1.0) * 60.0), str(WEATHER[clampi(w, 0, WEATHER.size() - 1)]).to_upper(), money]
	if _perf_on and main.has_method("debug_perf"):
		var p: Array = main.call("debug_perf")
		line += "\n%d FPS  %.1f MS  %d DRAWS" % [int(p[0]), float(p[1]), int(p[3])]
	_status.text = line


# ── what the letters do ──────────────────────────────────────────────────────

func _hour() -> void:
	_step_hours(1.0)


## To 21:00 by day, to 07:00 by night.
func _night_or_day() -> void:
	var h := fposmod(float(main.get("_time_of_day_hours")), 24.0)
	var to := 21.0 if h >= 7.0 and h < 21.0 else 7.0
	_step_hours(fposmod(to - h, 24.0))


func _step_hours(hours: float) -> void:
	var ts = main.get("time_system")
	if ts != null and ts.has_method("step_time_hours"):
		ts.step_time_hours(hours)
		main.call("_sync_runtime_state_from_systems", true)


func _weather() -> void:
	var ws = main.get("weather_system")
	if ws == null:
		return
	var next := (int(main.get("_weather_state")) + 1) % WEATHER.size()
	ws.set_weather(next)
	main.call("_sync_runtime_state_from_systems")


func _money() -> void:
	main.call("_debug_add_money")


func _hurt() -> void:
	main.call("_debug_damage_player")


func _night_log() -> void:
	main.call("_toggle_liminal_debug_window")


func _director() -> void:
	var fx = main.get("_director_fx")
	if fx != null and fx.has_method("toggle_debug"):
		fx.toggle_debug()


func _perf() -> void:
	_perf_on = not _perf_on
