extends Node
## Bottom skeuomorphic HUD bar inspired by vintage brass/wood instrument panels.
## Module order: CASH (left) | CLOCK (center) | HEALTH (right)

const HUD_LAYER_INDEX := 65
const HINT_LAYER_INDEX := 70

const COL_WOOD_A := Color(0.30, 0.18, 0.09, 0.98)
const COL_WOOD_B := Color(0.24, 0.14, 0.07, 0.98)
const COL_WOOD_BORDER := Color(0.09, 0.05, 0.03, 1.0)
const COL_BRASS_DARK := Color(0.21, 0.15, 0.08, 1.0)
const COL_BRASS_MID := Color(0.45, 0.34, 0.20, 1.0)
const COL_BRASS_LIGHT := Color(0.75, 0.63, 0.41, 1.0)
const COL_TEXT := Color(0.95, 0.88, 0.72, 1.0)
const COL_TEXT_DARK := Color(0.13, 0.08, 0.05, 1.0)


class WoodBarBackdrop:
	extends Control

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.19, 0.11, 0.06, 1.0), true)
		var plank_h: float = 34.0
		var y: float = 0.0
		while y < size.y:
			var h: float = minf(plank_h, size.y - y)
			var t := clampf(y / maxf(size.y, 1.0), 0.0, 1.0)
			var plank_col := COL_WOOD_A.lerp(COL_WOOD_B, fmod(t * 3.2, 1.0))
			draw_rect(Rect2(0.0, y, size.x, h), plank_col, true)
			draw_rect(Rect2(0.0, y, size.x, 2.0), Color(0.72, 0.53, 0.34, 0.15), true)
			draw_rect(Rect2(0.0, y + h - 2.0, size.x, 2.0), Color(0.05, 0.03, 0.02, 0.30), true)
			y += plank_h
		var rail_h := 12.0
		draw_rect(Rect2(0.0, 0.0, size.x, rail_h), Color(0.12, 0.07, 0.04, 0.85), true)
		draw_rect(Rect2(0.0, size.y - rail_h, size.x, rail_h), Color(0.11, 0.06, 0.04, 0.88), true)
		draw_rect(rect, COL_WOOD_BORDER, false, 2.0)
		draw_line(Vector2(0.0, 2.0), Vector2(size.x, 2.0), Color(0.67, 0.48, 0.31, 0.20), 2.0, false)


class ScrewHead:
	extends Control

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var r := minf(size.x, size.y) * 0.48
		draw_circle(center, r, COL_BRASS_DARK)
		draw_circle(center, r * 0.80, COL_BRASS_MID)
		draw_arc(center, r, 0.0, TAU, 32, COL_BRASS_LIGHT, 1.1, true)
		draw_line(center + Vector2(-r * 0.40, -r * 0.16), center + Vector2(r * 0.40, r * 0.16), Color(0.13, 0.10, 0.08, 1.0), 1.2, false)


class AnalogClockControl:
	extends Control

	var _minute_of_day: int = 9 * 60
	var _phase_pulse: float = 0.0
	var _phase_color: Color = Color(1.0, 0.86, 0.48, 1.0)

	func set_minute_of_day(value: int) -> void:
		var normalized := value % 1440
		if normalized < 0:
			normalized += 1440
		if normalized == _minute_of_day:
			return
		_minute_of_day = normalized
		queue_redraw()

	func trigger_phase_pulse(color: Color) -> void:
		_phase_color = color
		_phase_pulse = 1.0
		set_process(true)
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _process(delta: float) -> void:
		if _phase_pulse <= 0.0:
			set_process(false)
			return
		_phase_pulse = maxf(0.0, _phase_pulse - (delta * 1.45))
		queue_redraw()
		if _phase_pulse <= 0.0:
			set_process(false)

	func _draw() -> void:
		var center := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.46
		draw_circle(center, radius * 1.11, Color(0.15, 0.11, 0.07, 1.0))
		draw_circle(center, radius, Color(0.36, 0.28, 0.17, 1.0))
		draw_circle(center, radius * 0.90, Color(0.50, 0.40, 0.24, 1.0))
		for ring in range(7):
			var rr := lerpf(radius * 0.20, radius * 0.86, float(ring) / 6.0)
			var alpha := 0.07 if ring % 2 == 0 else 0.03
			draw_arc(center, rr, 0.0, TAU, 64, Color(0.16, 0.12, 0.08, alpha), 1.0, true)
		for tick in range(60):
			var angle: float = (float(tick) / 60.0) * TAU - (PI * 0.5)
			var outer := center + Vector2(cos(angle), sin(angle)) * radius * 0.82
			var inner_scale: float = 0.62 if tick % 5 == 0 else 0.74
			var inner := center + Vector2(cos(angle), sin(angle)) * radius * inner_scale
			var width := 3.0 if tick % 5 == 0 else 1.0
			draw_line(inner, outer, Color(0.22, 0.16, 0.10, 0.92), width, false)

		var minute_angle := (float(_minute_of_day % 60) / 60.0) * TAU - (PI * 0.5)
		var hour_angle := (fposmod(float(_minute_of_day) / 60.0, 12.0) / 12.0) * TAU - (PI * 0.5)
		var hour_tip := center + Vector2(cos(hour_angle), sin(hour_angle)) * radius * 0.42
		var minute_tip := center + Vector2(cos(minute_angle), sin(minute_angle)) * radius * 0.68
		draw_line(center, hour_tip, Color(0.17, 0.11, 0.07, 1.0), 5.0, false)
		draw_line(center, minute_tip, Color(0.19, 0.13, 0.08, 1.0), 3.0, false)
		draw_circle(center, radius * 0.08, Color(0.23, 0.16, 0.10, 1.0))
		if _phase_pulse > 0.0:
			var pulse := _phase_pulse * _phase_pulse
			var pulse_col := Color(_phase_color.r, _phase_color.g, _phase_color.b, 0.30 * pulse)
			draw_arc(center, radius * 1.12, 0.0, TAU, 84, pulse_col, 4.0, true)
			draw_circle(center, radius * 1.05, Color(_phase_color.r, _phase_color.g, _phase_color.b, 0.05 * pulse))


class HealthGaugeControl:
	extends Control

	var _target_value: float = 1.0
	var _display_value: float = 1.0
	var _velocity: float = 0.0
	var _wobble_phase: float = 0.0

	func set_value(value: float) -> void:
		var clamped := clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, _target_value):
			return
		_target_value = clamped
		set_process(true)
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _process(delta: float) -> void:
		var diff := _target_value - _display_value
		var spring_accel := (diff * 31.0) - (_velocity * 9.6)
		_velocity += spring_accel * delta
		_display_value += _velocity * delta
		_wobble_phase += delta * (6.0 + absf(_velocity) * 18.0)
		if absf(diff) < 0.0007 and absf(_velocity) < 0.0007:
			_display_value = _target_value
			_velocity = 0.0
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.64, 0.60, 0.54, 0.32), true)

		var view := Rect2(8.0, 4.0, size.x - 16.0, size.y * 0.73)
		draw_rect(view, Color(0.84, 0.82, 0.77, 0.95), true)
		draw_rect(view, Color(0.43, 0.37, 0.29, 1.0), false, 2.0)

		var center := Vector2(size.x * 0.5, view.position.y + view.size.y * 0.92)
		var outer_r: float = minf(view.size.x * 0.52, view.size.y * 1.35)
		var color_inner_r: float = outer_r * 0.67
		var dial_r: float = outer_r * 0.60

		var seg_colors := [
			Color(0.76, 0.64, 0.15, 1.0),
			Color(0.42, 0.60, 0.28, 1.0),
			Color(0.63, 0.36, 0.18, 1.0),
			Color(0.68, 0.15, 0.14, 1.0)
		]
		var seg_count := seg_colors.size()
		for i in range(seg_count):
			var start_angle := -PI + (PI * float(i) / float(seg_count))
			var end_angle := -PI + (PI * float(i + 1) / float(seg_count))
			_draw_ring_segment(center, outer_r, color_inner_r, start_angle, end_angle, seg_colors[i], 12)

		draw_circle(center, dial_r, Color(0.94, 0.91, 0.84, 1.0))
		draw_arc(center, dial_r, -PI, 0.0, 56, Color(0.40, 0.35, 0.28, 1.0), 2.0, true)
		for tick in range(0, 31):
			var ratio := float(tick) / 30.0
			var angle := -PI + (ratio * PI)
			var outer := center + Vector2(cos(angle), sin(angle)) * dial_r
			var inner_len := 0.18 if tick % 5 == 0 else 0.10
			var inner := center + Vector2(cos(angle), sin(angle)) * dial_r * (1.0 - inner_len)
			draw_line(inner, outer, Color(0.19, 0.17, 0.14, 0.95), 1.0, false)

		var wobble := sin(_wobble_phase) * minf(0.035, absf(_velocity) * 0.10)
		var animated_value := clampf(_display_value + wobble, 0.0, 1.0)
		var needle_angle := -PI + (animated_value * PI)
		var needle_tip := center + Vector2(cos(needle_angle), sin(needle_angle)) * dial_r * 0.94
		draw_line(center, needle_tip, Color(0.16, 0.12, 0.10, 1.0), 3.5, false)
		draw_circle(center, 4.8, Color(0.42, 0.32, 0.24, 1.0))
		var motion_glow := clampf(absf(_velocity) * 1.6, 0.0, 1.0)
		if motion_glow > 0.01:
			draw_arc(center, dial_r * 1.03, -PI, 0.0, 72, Color(1.0, 0.94, 0.72, 0.22 * motion_glow), 2.0, true)
		var glare := PackedVector2Array([
			Vector2(size.x * 0.12, size.y * 0.16),
			Vector2(size.x * 0.72, size.y * 0.08),
			Vector2(size.x * 0.64, size.y * 0.30),
			Vector2(size.x * 0.18, size.y * 0.38)
		])
		draw_polygon(glare, PackedColorArray([Color(1.0, 1.0, 1.0, 0.14)]))

	func _draw_ring_segment(center: Vector2, outer_r: float, inner_r: float, start_angle: float, end_angle: float, color: Color, steps: int) -> void:
		var points := PackedVector2Array()
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var angle := lerpf(start_angle, end_angle, t)
			points.append(center + Vector2(cos(angle), sin(angle)) * outer_r)
		for i in range(steps, -1, -1):
			var t := float(i) / float(steps)
			var angle := lerpf(start_angle, end_angle, t)
			points.append(center + Vector2(cos(angle), sin(angle)) * inner_r)
		draw_polygon(points, PackedColorArray([color]))


class BulbMeterControl:
	extends Control

	var _lamp_count: int = 4
	var _active_count: int = 0
	var _lit_palette: Array[Color] = []
	var _fill_from_right: bool = false
	var _blink_indices: PackedInt32Array = PackedInt32Array()
	var _blink_interval_ms: int = 360
	var _intensities: PackedFloat32Array = PackedFloat32Array()
	var _target_intensities: PackedFloat32Array = PackedFloat32Array()

	func configure(lamp_count: int, lit_palette: Array[Color], fill_from_right: bool = false, blink_indices: Array[int] = []) -> void:
		_lamp_count = maxi(1, lamp_count)
		_lit_palette.clear()
		for color in lit_palette:
			_lit_palette.append(color)
		_fill_from_right = fill_from_right
		_blink_indices.clear()
		for idx in blink_indices:
			_blink_indices.append(idx)
		_ensure_intensity_buffers()
		_rebuild_target_intensities()
		_refresh_process_state()
		queue_redraw()

	func set_active_count(value: int) -> void:
		var safe := maxi(0, value)
		if safe == _active_count:
			return
		_active_count = safe
		_rebuild_target_intensities()
		_refresh_process_state()
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _process(delta: float) -> void:
		var changed := false
		for i in range(_lamp_count):
			var current := _intensities[i]
			var target := _target_intensities[i]
			var next := move_toward(current, target, delta * 4.8)
			if not is_equal_approx(next, current):
				_intensities[i] = next
				changed = true
		var has_active_blink := false
		for idx in _blink_indices:
			if idx >= 0 and idx < _lamp_count and _target_intensities[idx] > 0.01:
				has_active_blink = true
				break
		if changed or has_active_blink:
			queue_redraw()
		_refresh_process_state()

	func _draw() -> void:
		if _lamp_count <= 0:
			return
		var spacing: float = size.x / float(_lamp_count + 1)
		var center_y: float = size.y * 0.5
		var ring_r: float = minf(spacing * 0.33, size.y * 0.44)
		var inner_r: float = ring_r * 0.72
		for i in range(_lamp_count):
			var x := spacing * float(i + 1)
			var center := Vector2(x, center_y)
			draw_circle(center, ring_r, Color(0.19, 0.13, 0.08, 1.0))
			draw_arc(center, ring_r, 0.0, TAU, 32, Color(0.54, 0.40, 0.25, 1.0), 1.2, true)
			var lit_color := _lamp_color(i)
			var off_color := lit_color.darkened(0.76).lerp(Color(0.12, 0.11, 0.10, 1.0), 0.55)
			var lit_strength := clampf(_intensities[i], 0.0, 1.0)
			if _blink_indices.has(i) and _target_intensities[i] > 0.01:
				var blink_wave := 0.5 + (0.5 * sin((float(Time.get_ticks_msec()) / float(_blink_interval_ms)) * PI))
				lit_strength *= lerpf(0.18, 1.0, blink_wave)
			var bulb := off_color.lerp(lit_color, lit_strength)
			draw_circle(center, inner_r, bulb)
			if lit_strength > 0.02:
				draw_circle(center + Vector2(-inner_r * 0.18, -inner_r * 0.18), inner_r * 0.42, Color(1.0, 0.93, 0.70, 0.78 * lit_strength))
				draw_circle(center, inner_r * 1.10, Color(lit_color.r, lit_color.g, lit_color.b, 0.16 * lit_strength))

	func _lamp_color(index: int) -> Color:
		if _lit_palette.is_empty():
			return Color(0.91, 0.75, 0.25, 1.0)
		var safe_idx := mini(index, _lit_palette.size() - 1)
		return _lit_palette[safe_idx]

	func _refresh_process_state() -> void:
		var has_active_blink := false
		for idx in _blink_indices:
			if idx >= 0 and idx < _lamp_count and _target_intensities[idx] > 0.01:
				has_active_blink = true
				break
		var has_fade_motion := false
		for i in range(_lamp_count):
			if not is_equal_approx(_intensities[i], _target_intensities[i]):
				has_fade_motion = true
				break
		set_process(has_active_blink or has_fade_motion)

	func _ensure_intensity_buffers() -> void:
		_intensities.resize(_lamp_count)
		_target_intensities.resize(_lamp_count)
		for i in range(_lamp_count):
			if _intensities[i] < 0.0 or _intensities[i] > 1.0:
				_intensities[i] = 0.0

	func _rebuild_target_intensities() -> void:
		var lit_count: int = mini(_active_count, _lamp_count)
		for i in range(_lamp_count):
			var is_lit := i < lit_count if not _fill_from_right else i >= (_lamp_count - lit_count)
			_target_intensities[i] = 1.0 if is_lit else 0.0


var _hud_layer: CanvasLayer
var _hud_root: Control
var _hint_layer: CanvasLayer

var _interaction_hint_label: Label
var _clock_widget: AnalogClockControl
var _health_gauge: HealthGaugeControl
var _forecast_lights: BulbMeterControl
var _email_lights: BulbMeterControl
var _cash_value_label: Label
var _cash_glow_overlay: ColorRect

var _health_ratio: float = 1.0
var _forecast_count: int = 2
var _mail_bound: bool = false
var _last_clock_marker_minute: int = -1
var _cash_known: bool = false
var _cash_amount: int = 0
var _cash_glow_time: float = 0.0
var _cash_glow_duration: float = 1.0
var _cash_poll_accum: float = 0.0
var _cash_poll_interval_sec: float = 10.0


# -- Public setup API --

func setup_interaction_hint() -> void:
	if _hint_layer != null:
		return
	_hint_layer = CanvasLayer.new()
	_hint_layer.name = "InteractionHintLayer"
	_hint_layer.layer = HINT_LAYER_INDEX
	add_child(_hint_layer)

	var label := Label.new()
	label.name = "InteractionHint"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = ""
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.position = Vector2(0.0, 18.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COL_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.01, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	_hint_layer.add_child(label)
	_interaction_hint_label = label


func setup_money_hud() -> void:
	_ensure_world_hud()


func setup_weather_hud() -> void:
	# Kept for main.gd compatibility.
	_ensure_world_hud()


func setup_time_hud() -> void:
	_ensure_world_hud()


# -- Public update API --

func update_weather(_state: int) -> void:
	# No standalone weather widget in this layout.
	pass


func update_time(time_str: String, _day: int) -> void:
	_ensure_world_hud()
	if _clock_widget == null:
		return
	var minute := _parse_time_to_minutes(time_str)
	_clock_widget.set_minute_of_day(minute)
	_try_trigger_clock_phase(minute)


func on_money_changed(new_amount: int) -> void:
	_ensure_world_hud()
	_apply_money_amount(new_amount)


func set_world_hud_visible(visible: bool) -> void:
	if _hud_layer != null:
		_hud_layer.visible = visible
	if _hint_layer != null:
		_hint_layer.visible = visible


func set_hint_text(text: String) -> void:
	if _interaction_hint_label != null:
		_interaction_hint_label.text = text


func set_health_ratio(value: float) -> void:
	_health_ratio = clampf(value, 0.0, 1.0)
	if _health_gauge != null:
		_health_gauge.set_value(_health_ratio)


func set_liminal_forecast_count(value: int) -> void:
	_forecast_count = maxi(0, value)
	if _forecast_lights != null:
		_forecast_lights.set_active_count(_forecast_count)


func _process(delta: float) -> void:
	_cash_poll_accum += delta
	if _cash_poll_accum >= _cash_poll_interval_sec:
		_cash_poll_accum = 0.0
		_poll_money_from_core()
	_update_cash_glow(delta)


func cycle_item_slot(_step: int) -> void:
	# Slot system removed by design request.
	pass


func set_selected_slot(_index: int) -> void:
	# Slot system removed by design request.
	pass


# -- Private layout --

func _ensure_world_hud() -> void:
	if _hud_layer != null:
		_ensure_email_binding()
		return

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "RetroHudLayer"
	_hud_layer.layer = HUD_LAYER_INDEX
	add_child(_hud_layer)

	_hud_root = Control.new()
	_hud_root.name = "RetroHudRoot"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(_hud_root)

	var bar := WoodBarBackdrop.new()
	bar.name = "BottomBar"
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -126.0
	bar.offset_bottom = 0.0
	_hud_root.add_child(bar)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	bar.add_child(margin)

	var modules := HBoxContainer.new()
	modules.alignment = BoxContainer.ALIGNMENT_CENTER
	modules.add_theme_constant_override("separation", 10)
	margin.add_child(modules)

	_build_cash_cluster(modules)
	_build_clock_module(modules)
	_build_health_cluster(modules)

	_set_control_mouse_passthrough(_hud_root)
	_ensure_email_binding()
	_on_unread_count_changed(_get_unread_count())
	if _forecast_lights != null:
		_forecast_lights.set_active_count(_forecast_count)
	_poll_money_from_core()
	set_process(true)


func _build_cash_cluster(parent: BoxContainer) -> void:
	var cluster := VBoxContainer.new()
	cluster.name = "CashCluster"
	cluster.custom_minimum_size = Vector2(176.0, 104.0)
	cluster.add_theme_constant_override("separation", 5)
	parent.add_child(cluster)

	var panel := PanelContainer.new()
	panel.name = "CashModule"
	panel.custom_minimum_size = Vector2(176.0, 76.0)
	panel.add_theme_stylebox_override("panel", _brass_panel_style(10))
	cluster.add_child(panel)
	_decorate_module_panel(panel, 15.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var title := Label.new()
	title.text = "CASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.11, 0.07, 0.04, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.95, 0.84, 0.58, 0.22))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(title)

	var display := PanelContainer.new()
	display.custom_minimum_size = Vector2(0.0, 42.0)
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display.add_theme_stylebox_override("panel", _digital_display_style())
	box.add_child(display)

	var glow := ColorRect.new()
	glow.name = "CashGlow"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(1.0, 0.82, 0.25, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(glow)
	_cash_glow_overlay = glow

	var value := Label.new()
	value.text = "$500"
	value.set_anchors_preset(Control.PRESET_FULL_RECT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 32)
	value.add_theme_color_override("font_color", Color(0.97, 0.67, 0.14, 1.0))
	value.add_theme_color_override("font_shadow_color", Color(0.18, 0.08, 0.02, 0.98))
	value.add_theme_constant_override("shadow_offset_x", 2)
	value.add_theme_constant_override("shadow_offset_y", 2)
	display.add_child(value)
	_cash_value_label = value

	var bulbs := BulbMeterControl.new()
	bulbs.name = "EmailBulbs"
	bulbs.custom_minimum_size = Vector2(176.0, 20.0)
	bulbs.configure(3, [
		Color(0.72, 0.12, 0.12, 1.0),
		Color(0.95, 0.78, 0.20, 1.0),
		Color(0.28, 0.72, 0.30, 1.0)
	], true)
	cluster.add_child(bulbs)
	_email_lights = bulbs


func _build_clock_module(parent: BoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "ClockModule"
	panel.custom_minimum_size = Vector2(196.0, 104.0)
	panel.add_theme_stylebox_override("panel", _brass_panel_style(18))
	parent.add_child(panel)
	_decorate_module_panel(panel, 18.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var clock := AnalogClockControl.new()
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(clock)
	_clock_widget = clock


func _build_health_cluster(parent: BoxContainer) -> void:
	var cluster := VBoxContainer.new()
	cluster.name = "HealthCluster"
	cluster.custom_minimum_size = Vector2(226.0, 104.0)
	cluster.add_theme_constant_override("separation", 5)
	parent.add_child(cluster)

	var panel := PanelContainer.new()
	panel.name = "HealthModule"
	panel.custom_minimum_size = Vector2(226.0, 76.0)
	panel.add_theme_stylebox_override("panel", _brass_panel_style(10))
	cluster.add_child(panel)
	_decorate_module_panel(panel, 15.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	margin.add_child(box)

	var gauge := HealthGaugeControl.new()
	gauge.custom_minimum_size = Vector2(0.0, 40.0)
	gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(gauge)
	_health_gauge = gauge
	_health_gauge.set_value(_health_ratio)

	var health_label := Label.new()
	health_label.text = "HEALTH"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 16)
	health_label.add_theme_color_override("font_color", Color(0.11, 0.08, 0.05, 1.0))
	health_label.add_theme_color_override("font_shadow_color", Color(0.83, 0.71, 0.47, 0.16))
	health_label.add_theme_constant_override("shadow_offset_x", 1)
	health_label.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(health_label)

	var bulbs := BulbMeterControl.new()
	bulbs.name = "ForecastBulbs"
	bulbs.custom_minimum_size = Vector2(226.0, 20.0)
	bulbs.configure(4, [
		Color(0.32, 0.74, 0.34, 1.0),
		Color(0.95, 0.80, 0.24, 1.0),
		Color(0.83, 0.18, 0.16, 1.0),
		Color(0.48, 0.07, 0.07, 1.0)
	], false, [3])
	cluster.add_child(bulbs)
	_forecast_lights = bulbs
	_forecast_lights.set_active_count(_forecast_count)


# -- Runtime bindings --

func _ensure_email_binding() -> void:
	if _mail_bound:
		return
	if EmailManager == null:
		return
	if EmailManager.has_signal("unread_count_changed"):
		var callback := Callable(self, "_on_unread_count_changed")
		if not EmailManager.unread_count_changed.is_connected(callback):
			EmailManager.unread_count_changed.connect(callback)
		_mail_bound = true


func _on_unread_count_changed(count: int) -> void:
	if _email_lights == null:
		return
	_email_lights.set_active_count(maxi(0, count))


func _try_trigger_clock_phase(minute: int) -> void:
	if _clock_widget == null:
		return
	if minute == 390 and _last_clock_marker_minute != 390:
		_clock_widget.trigger_phase_pulse(Color(1.0, 0.83, 0.33, 1.0))
	elif minute == 1200 and _last_clock_marker_minute != 1200:
		_clock_widget.trigger_phase_pulse(Color(0.42, 0.58, 0.95, 1.0))
	_last_clock_marker_minute = minute


func _poll_money_from_core() -> void:
	if CoreRoot == null or not CoreRoot.has_method("get_money"):
		return
	_apply_money_amount(int(CoreRoot.get_money()))


func _apply_money_amount(amount: int) -> void:
	if not _cash_known:
		_cash_known = true
		_cash_amount = amount
		_set_cash_label(amount)
		return
	if amount == _cash_amount:
		return
	if amount > _cash_amount:
		_cash_glow_time = _cash_glow_duration
	_cash_amount = amount
	_set_cash_label(amount)


func _set_cash_label(amount: int) -> void:
	if _cash_value_label == null:
		return
	_cash_value_label.text = "$%s" % _format_money(amount)


func _update_cash_glow(delta: float) -> void:
	if _cash_glow_time <= 0.0:
		_apply_cash_glow_visual(0.0, 0.0, 0.0)
		return
	_cash_glow_time = maxf(0.0, _cash_glow_time - delta)
	var life := _cash_glow_time / _cash_glow_duration
	var progress := 1.0 - life
	var pulse := sin(progress * PI)
	var wobble := sin(progress * TAU * 2.4) * life * 0.45
	var intensity := clampf((pulse * 0.88) + wobble, 0.0, 1.0)
	_apply_cash_glow_visual(intensity, progress, life)
	if _cash_glow_time <= 0.0:
		_apply_cash_glow_visual(0.0, 0.0, 0.0)


func _apply_cash_glow_visual(intensity: float, progress: float, life: float) -> void:
	if _cash_glow_overlay != null:
		_cash_glow_overlay.color = Color(1.0, 0.82, 0.25, 0.30 * intensity)
	if _cash_value_label != null:
		var base := Color(0.97, 0.67, 0.14, 1.0)
		var bright := Color(1.0, 0.92, 0.47, 1.0)
		_cash_value_label.add_theme_color_override("font_color", base.lerp(bright, intensity * 0.78))
		_cash_value_label.pivot_offset = _cash_value_label.size * 0.5
		var bump := 1.0 + (0.08 * sin(progress * PI * 2.0) * life)
		_cash_value_label.scale = Vector2.ONE * bump


# -- Helpers --

func _brass_panel_style(corner_radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.49, 0.37, 0.22, 0.97)
	style.border_color = Color(0.69, 0.56, 0.33, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0.05, 0.03, 0.02, 0.60)
	style.shadow_size = 3
	return style


func _digital_display_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.07, 0.96)
	style.border_color = Color(0.33, 0.31, 0.28, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.68)
	style.shadow_size = 2
	return style


func _decorate_module_panel(panel: PanelContainer, screw_size: float = 12.0) -> void:
	if panel == null:
		return
	var highlight := ColorRect.new()
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.anchor_left = 0.0
	highlight.anchor_right = 1.0
	highlight.anchor_top = 0.0
	highlight.anchor_bottom = 0.0
	highlight.offset_top = 1.0
	highlight.offset_bottom = 18.0
	highlight.color = Color(1.0, 0.95, 0.83, 0.12)
	panel.add_child(highlight)
	_add_screw(panel, 0.0, 0.0, screw_size)
	_add_screw(panel, 1.0, 0.0, screw_size)
	_add_screw(panel, 0.0, 1.0, screw_size)
	_add_screw(panel, 1.0, 1.0, screw_size)


func _add_screw(panel: PanelContainer, ax: float, ay: float, screw_size: float) -> void:
	var screw := ScrewHead.new()
	var half := maxf(4.0, screw_size * 0.5)
	screw.custom_minimum_size = Vector2(screw_size, screw_size)
	screw.anchor_left = ax
	screw.anchor_right = ax
	screw.anchor_top = ay
	screw.anchor_bottom = ay
	screw.offset_left = -half
	screw.offset_right = half
	screw.offset_top = -half
	screw.offset_bottom = half
	panel.add_child(screw)


func _set_control_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_control_mouse_passthrough(child)


func _parse_time_to_minutes(time_str: String) -> int:
	var parts := time_str.split(":")
	if parts.size() < 2:
		return 0
	var hour := clampi(int(parts[0]), 0, 23)
	var minute := clampi(int(parts[1]), 0, 59)
	return (hour * 60) + minute


func _format_money(amount: int) -> String:
	return str(amount)


func _get_unread_count() -> int:
	if EmailManager == null or not EmailManager.has_method("get_unread_count"):
		return 0
	return int(EmailManager.get_unread_count())
