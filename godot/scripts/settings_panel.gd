extends VBoxContainer

const MODE_IDS := ["windowed", "fullscreen", "borderless"]
const MODE_LABELS := [
	"Windowed",
	"Fullscreen (Exclusive)",
	"Fullscreen (Borderless)",
]

## [label, keys] pairs. Kept in sync by hand with `main._ensure_input_actions()`,
## `player_controller.gd` and the interior scripts.
const CONTROL_REFERENCE := [
	["Move", "W A S D"],
	["Sprint", "Shift"],
	["Jump", "Space"],
	["Look", "Mouse"],
	["Interact / use", "E  or  Left Mouse"],
	["Back / close", "Esc"],
	["Office lights (reception)", "L"],
	["Service room: previous / next", "A / D"],
	["Builder: rotate", "Q / E"],
	["Builder: pan", "W A S D  or  Right-drag"],
	["Builder: zoom", "Mouse wheel  or  + / -"],
]

const DEBUG_CONTROL_REFERENCE := [
	["Skip one hour", "T / U"],
	["Cycle weather", "Y"],
	["Damage player", "P"],
	["Add money", "K"],
	["Liminal forecast window", "L"],
]

var _mode_option: OptionButton
var _resolution_option: OptionButton
var _volume_slider: HSlider
var _volume_label: Label
var _resolutions: Array[Vector2i] = []
var _refreshing: bool = false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_build_ui()
	_reload_options()
	if GameSettings.has_signal("settings_changed"):
		var cb := Callable(self, "_on_settings_changed")
		if not GameSettings.settings_changed.is_connected(cb):
			GameSettings.settings_changed.connect(cb)


func _build_ui() -> void:
	var display_title := Label.new()
	display_title.text = "Display"
	display_title.add_theme_font_size_override("font_size", 15)
	add_child(display_title)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	add_child(mode_row)

	var mode_label := Label.new()
	mode_label.text = "Window Mode"
	mode_label.custom_minimum_size = Vector2(150.0, 0.0)
	mode_row.add_child(mode_label)

	_mode_option = OptionButton.new()
	_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in MODE_LABELS.size():
		_mode_option.add_item(MODE_LABELS[i], i)
	_mode_row_add(mode_row, _mode_option)
	_mode_option.item_selected.connect(_on_mode_selected)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	add_child(res_row)

	var res_label := Label.new()
	res_label.text = "Resolution"
	res_label.custom_minimum_size = Vector2(150.0, 0.0)
	res_row.add_child(res_label)

	_resolution_option = OptionButton.new()
	_resolution_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_row_add(res_row, _resolution_option)
	_resolution_option.item_selected.connect(_on_resolution_selected)

	var audio_title := Label.new()
	audio_title.text = "Audio"
	audio_title.add_theme_font_size_override("font_size", 15)
	add_child(audio_title)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 8)
	add_child(volume_row)

	var volume_title := Label.new()
	volume_title.text = "Master Volume"
	volume_title.custom_minimum_size = Vector2(150.0, 0.0)
	volume_row.add_child(volume_title)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = -40.0
	_volume_slider.max_value = 6.0
	_volume_slider.step = 0.5
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_row_add(volume_row, _volume_slider)
	_volume_slider.value_changed.connect(_on_volume_changed)

	_volume_label = Label.new()
	_volume_label.custom_minimum_size = Vector2(64.0, 0.0)
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(_volume_label)

	_build_controls_section()

	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 8)
	add_child(buttons_row)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Defaults"
	reset_btn.pressed.connect(func() -> void:
		GameSettings.reset_defaults()
	)
	buttons_row.add_child(reset_btn)


## Reference list of the game's controls.
##
## Bindings are registered at runtime in `main._ensure_input_actions()`, so they never
## appear in the project input map. Without this panel a player has no way at all to
## discover them. Rebinding is not supported yet -- this is read-only reference.
func _build_controls_section() -> void:
	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	add_child(grid)

	for entry in CONTROL_REFERENCE:
		var action := Label.new()
		action.text = str(entry[0])
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(action)

		var keys := Label.new()
		keys.text = str(entry[1])
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		keys.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58, 1.0))
		grid.add_child(keys)

	if OS.is_debug_build():
		var debug_title := Label.new()
		debug_title.text = "Debug (debug builds only)"
		debug_title.add_theme_font_size_override("font_size", 12)
		debug_title.add_theme_color_override("font_color", Color(0.70, 0.55, 0.32, 1.0))
		add_child(debug_title)

		var debug_grid := GridContainer.new()
		debug_grid.columns = 2
		debug_grid.add_theme_constant_override("h_separation", 18)
		debug_grid.add_theme_constant_override("v_separation", 3)
		add_child(debug_grid)

		for entry in DEBUG_CONTROL_REFERENCE:
			var d_action := Label.new()
			d_action.text = str(entry[0])
			d_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			debug_grid.add_child(d_action)

			var d_keys := Label.new()
			d_keys.text = str(entry[1])
			d_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			d_keys.add_theme_color_override("font_color", Color(0.70, 0.55, 0.32, 1.0))
			debug_grid.add_child(d_keys)


func _mode_row_add(row: HBoxContainer, control: Control) -> void:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _reload_options() -> void:
	_refreshing = true
	_resolutions = GameSettings.get_supported_resolutions()
	_resolution_option.clear()
	var selected_res_index := 0
	var target := GameSettings.get_resolution()
	for i in _resolutions.size():
		var res := _resolutions[i]
		_resolution_option.add_item("%d x %d" % [res.x, res.y], i)
		if res == target:
			selected_res_index = i
	if _resolutions.is_empty():
		_resolution_option.add_item("%d x %d" % [target.x, target.y], 0)
		_resolutions.append(target)
		selected_res_index = 0
	_resolution_option.select(selected_res_index)

	var mode = GameSettings.get_window_mode()
	var mode_index := 0
	for i in MODE_IDS.size():
		if MODE_IDS[i] == mode:
			mode_index = i
			break
	_mode_option.select(mode_index)

	_volume_slider.value = GameSettings.get_master_volume_db()
	_volume_label.text = "%.1f dB" % _volume_slider.value
	_refreshing = false


func _on_mode_selected(index: int) -> void:
	if _refreshing:
		return
	if index < 0 or index >= MODE_IDS.size():
		return
	GameSettings.set_window_mode(MODE_IDS[index], true, true)


func _on_resolution_selected(index: int) -> void:
	if _refreshing:
		return
	if index < 0 or index >= _resolutions.size():
		return
	GameSettings.set_resolution(_resolutions[index], true, true)


func _on_volume_changed(value: float) -> void:
	if _refreshing:
		return
	_volume_label.text = "%.1f dB" % value
	GameSettings.set_master_volume_db(value, true, true)


func _on_settings_changed(_snapshot: Dictionary) -> void:
	_reload_options()
