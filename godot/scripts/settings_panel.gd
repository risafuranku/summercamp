extends VBoxContainer

const MODE_IDS := ["windowed", "fullscreen", "borderless"]
const MODE_LABELS := [
	"Windowed",
	"Fullscreen (Exclusive)",
	"Fullscreen (Borderless)",
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

	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 8)
	add_child(buttons_row)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Defaults"
	reset_btn.pressed.connect(func() -> void:
		GameSettings.reset_defaults()
	)
	buttons_row.add_child(reset_btn)


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
