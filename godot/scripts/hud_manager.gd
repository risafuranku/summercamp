extends Node
## Bottom skeuomorphic HUD bar inspired by vintage brass/wood instrument panels.
##
## Module order:
##   CASH + MAIL | CLOCK + DAY/PHASE | CONDITIONS (weather + beds) | HEALTH + NIGHT RISK
##
## Every meter carries a caption. An unlabelled row of bulbs is not information --
## the NIGHT RISK meter in particular encodes the game's central risk/reward trade
## (see DESIGN.md) and previously shipped with no legend at all.
##
## A status strip sits directly above the bar for transient feedback (build rejected,
## booking accepted, phase change). See `push_status()`.

const HUD_LAYER_INDEX := 65
const HINT_LAYER_INDEX := 70

const BAR_HEIGHT := 132.0

# Status strip kinds.
const STATUS_INFO := 0
const STATUS_GOOD := 1
const STATUS_WARN := 2
const STATUS_DENY := 3

const STATUS_HOLD_SEC := 3.2
const STATUS_FADE_SEC := 0.7

# Time phases, mirroring main.gd / TimeSystem.
const PHASE_DAY := 0
const PHASE_EVENING := 1
const PHASE_NIGHT := 2

const PHASE_LABELS := ["DAY", "EVENING", "NIGHT"]

const WEATHER_LABELS := [
	"CLEAR", "WINDY", "FOG", "LIGHT RAIN", "RAIN", "STORM", "ANOMALY"
]

## NIGHT RISK legend. Index matches the HUD level derived from expected spawns
## (`GuestManager.LIMINAL_HUD_EXPECTED_THRESHOLDS`).
const RISK_LEVEL_LABELS := ["CLEAR", "LOW", "RAISED", "HIGH", "CRITICAL"]

const RISK_TIER_LABELS := {
	"none": "clear",
	"tiny": "tiny",
	"small": "small",
	"medium": "medium",
	"large": "large",
}

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


class WeatherGlyphControl:
	extends Control

	## Hand-drawn weather pictogram. Drawn rather than textured so it matches the
	## etched-instrument register of the rest of the bar and scales cleanly.

	var _state: int = 0
	var _anim_phase: float = 0.0

	func set_weather_state(value: int) -> void:
		var safe := clampi(value, 0, 6)
		if safe == _state:
			return
		_state = safe
		set_process(_state != 0)
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _process(delta: float) -> void:
		_anim_phase = fmod(_anim_phase + delta, TAU)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.40
		var ink := Color(0.14, 0.09, 0.05, 1.0)
		var accent := Color(0.30, 0.22, 0.13, 1.0)

		match _state:
			0:  # CLEAR - sun
				draw_arc(c, r * 0.52, 0.0, TAU, 28, ink, 2.0, true)
				for i in range(8):
					var a := (float(i) / 8.0) * TAU + (_anim_phase * 0.12)
					var dir := Vector2(cos(a), sin(a))
					draw_line(c + dir * r * 0.72, c + dir * r * 0.98, ink, 1.6, false)
			1:  # WINDY - streaks
				for i in range(3):
					var y := c.y + (float(i) - 1.0) * r * 0.46
					var wobble := sin(_anim_phase * 1.6 + float(i)) * r * 0.10
					draw_line(Vector2(c.x - r, y), Vector2(c.x + r * 0.55 + wobble, y), ink, 1.8, false)
					draw_arc(Vector2(c.x + r * 0.55 + wobble, y), r * 0.22, -PI * 0.5, PI * 0.85, 14, ink, 1.8, true)
			2:  # FOG - stacked bands
				for i in range(4):
					var y2 := c.y + (float(i) - 1.5) * r * 0.40
					var off := sin(_anim_phase * 0.8 + float(i) * 0.9) * r * 0.16
					draw_line(Vector2(c.x - r + off, y2), Vector2(c.x + r + off, y2), accent, 2.4, false)
			_:  # rain family - cloud plus drops
				_draw_cloud(c + Vector2(0.0, -r * 0.30), r, ink)
				var drop_count := 2
				if _state == 4:
					drop_count = 3
				elif _state >= 5:
					drop_count = 4
				for i in range(drop_count):
					var dx := c.x + (float(i) - (float(drop_count) - 1.0) * 0.5) * r * 0.44
					var fall := fmod(_anim_phase * 0.9 + float(i) * 0.6, 1.0)
					var y0 := c.y + r * 0.26 + fall * r * 0.44
					draw_line(Vector2(dx, y0), Vector2(dx - r * 0.07, y0 + r * 0.26), accent, 1.8, false)
				if _state >= 5:
					var bolt := PackedVector2Array([
						c + Vector2(r * 0.10, r * 0.16),
						c + Vector2(-r * 0.16, r * 0.60),
						c + Vector2(r * 0.02, r * 0.58),
						c + Vector2(-r * 0.10, r * 0.98),
						c + Vector2(r * 0.30, r * 0.46),
						c + Vector2(r * 0.10, r * 0.48),
					])
					var flash: float = 0.55 + 0.45 * absf(sin(_anim_phase * 2.4))
					draw_polygon(bolt, PackedColorArray([Color(0.86, 0.66, 0.18, flash)]))
				if _state == 6:
					draw_arc(c, r * 1.02, 0.0, TAU, 30, Color(0.55, 0.10, 0.10, 0.75), 2.0, true)

	func _draw_cloud(center: Vector2, r: float, ink: Color) -> void:
		draw_circle(center + Vector2(-r * 0.34, 0.0), r * 0.34, ink)
		draw_circle(center + Vector2(r * 0.30, r * 0.04), r * 0.30, ink)
		draw_circle(center + Vector2(-r * 0.02, -r * 0.20), r * 0.40, ink)
		draw_rect(Rect2(center.x - r * 0.36, center.y - r * 0.02, r * 0.70, r * 0.34), ink, true)


class OccupancyBarControl:
	extends Control

	## Bed occupancy as a segmented brass slide gauge. Reads at a glance whether
	## there is room to accept the booking currently open in CampMail.

	var _occupied: int = 0
	var _capacity: int = 0

	func set_metrics(occupied: int, capacity: int) -> void:
		var o := maxi(0, occupied)
		var c := maxi(0, capacity)
		if o == _occupied and c == _capacity:
			return
		_occupied = o
		_capacity = c
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var track := Rect2(0.0, size.y * 0.20, size.x, size.y * 0.60)
		draw_rect(track, Color(0.16, 0.11, 0.07, 1.0), true)
		draw_rect(track, Color(0.44, 0.33, 0.20, 1.0), false, 1.5)

		if _capacity <= 0:
			return

		var seg_count: int = mini(_capacity, 24)
		var gap := 2.0
		var seg_w: float = maxf(2.0, (track.size.x - gap * float(seg_count + 1)) / float(seg_count))
		# Occupied segments are proportional when capacity exceeds the segment budget.
		var filled: int = int(round((float(_occupied) / float(_capacity)) * float(seg_count)))
		if _occupied > 0:
			filled = maxi(1, filled)
		for i in range(seg_count):
			var x := track.position.x + gap + float(i) * (seg_w + gap)
			var seg := Rect2(x, track.position.y + 3.0, seg_w, track.size.y - 6.0)
			var col := Color(0.24, 0.20, 0.14, 1.0)
			if i < filled:
				var ratio := float(i + 1) / float(seg_count)
				col = Color(0.36, 0.62, 0.30, 1.0)
				if ratio > 0.85:
					col = Color(0.78, 0.24, 0.16, 1.0)
				elif ratio > 0.60:
					col = Color(0.88, 0.70, 0.20, 1.0)
			draw_rect(seg, col, true)


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _hud_layer: CanvasLayer
var _hud_root: Control
var _hint_layer: CanvasLayer

var _interaction_hint_label: Label
var _clock_widget: AnalogClockControl
var _health_gauge: HealthGaugeControl
var _forecast_lights: BulbMeterControl
var _email_lights: BulbMeterControl
var _weather_glyph: WeatherGlyphControl
var _occupancy_bar: OccupancyBarControl

var _cash_value_label: Label
var _cash_glow_overlay: ColorRect
var _day_label: Label
var _phase_label: Label
var _digital_time_label: Label
var _weather_label: Label
var _occupancy_label: Label
var _risk_level_label: Label
var _risk_detail_label: Label
var _mail_caption_label: Label

var _status_panel: PanelContainer
var _status_label: Label
var _status_timer: float = 0.0
var _status_text: String = ""

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

var _current_day: int = 1
var _current_phase: int = PHASE_DAY
var _current_weather: int = 0
var _bed_capacity: int = 0
var _bed_occupied: int = 0
var _bed_poll_accum: float = 0.0
var _bed_poll_interval_sec: float = 2.0


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC SETUP API  (called from main.gd)
# ═══════════════════════════════════════════════════════════════════════════════

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
	_ensure_world_hud()


func setup_time_hud() -> void:
	_ensure_world_hud()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC UPDATE API
# ═══════════════════════════════════════════════════════════════════════════════

func update_weather(state: int) -> void:
	_ensure_world_hud()
	_current_weather = clampi(state, 0, WEATHER_LABELS.size() - 1)
	if _weather_glyph != null:
		_weather_glyph.set_weather_state(_current_weather)
	if _weather_label != null:
		_weather_label.text = str(WEATHER_LABELS[_current_weather])


func update_time(time_str: String, day: int) -> void:
	_ensure_world_hud()
	var minute := _parse_time_to_minutes(time_str)
	if _clock_widget != null:
		_clock_widget.set_minute_of_day(minute)
		_try_trigger_clock_phase(minute)
	if _digital_time_label != null:
		_digital_time_label.text = time_str
	_set_day(day)
	_set_phase(_phase_for_minute(minute))


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


## Legacy entry point: bulb count only. Prefer `set_liminal_forecast()`.
func set_liminal_forecast_count(value: int) -> void:
	_forecast_count = clampi(value, 0, 4)
	if _forecast_lights != null:
		_forecast_lights.set_active_count(_forecast_count)
	if _risk_level_label != null:
		_risk_level_label.text = str(RISK_LEVEL_LABELS[_forecast_count])
		_risk_level_label.add_theme_color_override("font_color", _risk_level_color(_forecast_count))


## Full forecast payload from `GuestManager.get_liminal_forecast_data()`.
## Drives the bulb meter, the level caption and the "which archetype" detail line.
func set_liminal_forecast(payload: Dictionary) -> void:
	_ensure_world_hud()
	set_liminal_forecast_count(int(payload.get("hud_level", 0)))
	if _risk_detail_label == null:
		return
	_risk_detail_label.text = _compose_risk_detail(payload)


## Transient feedback line above the bar. `kind` is one of the STATUS_* constants.
func push_status(text: String, kind: int = STATUS_INFO) -> void:
	_ensure_world_hud()
	if _status_label == null or _status_panel == null:
		return
	_status_text = text
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", _status_color(kind))
	_status_panel.modulate.a = 1.0
	_status_panel.visible = not text.is_empty()
	_status_timer = STATUS_HOLD_SEC + STATUS_FADE_SEC if not text.is_empty() else 0.0


func set_bed_metrics(occupied: int, capacity: int) -> void:
	_ensure_world_hud()
	_bed_occupied = maxi(0, occupied)
	_bed_capacity = maxi(0, capacity)
	if _occupancy_bar != null:
		_occupancy_bar.set_metrics(_bed_occupied, _bed_capacity)
	if _occupancy_label != null:
		_occupancy_label.text = "BEDS %d/%d" % [_bed_occupied, _bed_capacity]


func cycle_item_slot(_step: int) -> void:
	# Slot system removed by design request.
	pass


func set_selected_slot(_index: int) -> void:
	# Slot system removed by design request.
	pass


func _process(delta: float) -> void:
	_cash_poll_accum += delta
	if _cash_poll_accum >= _cash_poll_interval_sec:
		_cash_poll_accum = 0.0
		_poll_money_from_core()
	_bed_poll_accum += delta
	if _bed_poll_accum >= _bed_poll_interval_sec:
		_bed_poll_accum = 0.0
		_poll_bed_metrics()
	_update_cash_glow(delta)
	_update_status_strip(delta)


# ═══════════════════════════════════════════════════════════════════════════════
# LAYOUT
# ═══════════════════════════════════════════════════════════════════════════════

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

	_build_status_strip(_hud_root)

	var bar := WoodBarBackdrop.new()
	bar.name = "BottomBar"
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -BAR_HEIGHT
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
	_build_clock_cluster(modules)
	_build_conditions_cluster(modules)
	_build_health_cluster(modules)

	_set_control_mouse_passthrough(_hud_root)
	_ensure_email_binding()
	_on_unread_count_changed(_get_unread_count())
	set_liminal_forecast_count(_forecast_count)
	_poll_money_from_core()
	_poll_bed_metrics()
	set_process(true)


func _build_status_strip(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "StatusStrip"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = -(BAR_HEIGHT + 40.0)
	panel.offset_bottom = -(BAR_HEIGHT + 10.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _status_panel_style())
	parent.add_child(panel)
	_status_panel = panel

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_top", 3)
	inner.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(inner)

	var label := Label.new()
	label.text = ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COL_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.01, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	inner.add_child(label)
	_status_label = label


func _build_cash_cluster(parent: BoxContainer) -> void:
	var cluster := VBoxContainer.new()
	cluster.name = "CashCluster"
	cluster.custom_minimum_size = Vector2(178.0, 110.0)
	cluster.add_theme_constant_override("separation", 3)
	parent.add_child(cluster)

	var panel := PanelContainer.new()
	panel.name = "CashModule"
	panel.custom_minimum_size = Vector2(178.0, 72.0)
	panel.add_theme_stylebox_override("panel", _brass_panel_style(10))
	cluster.add_child(panel)
	_decorate_module_panel(panel, 15.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	box.add_child(_make_module_caption("CASH"))

	var display := PanelContainer.new()
	display.custom_minimum_size = Vector2(0.0, 40.0)
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
	value.add_theme_font_size_override("font_size", 30)
	value.add_theme_color_override("font_color", Color(0.97, 0.67, 0.14, 1.0))
	value.add_theme_color_override("font_shadow_color", Color(0.18, 0.08, 0.02, 0.98))
	value.add_theme_constant_override("shadow_offset_x", 2)
	value.add_theme_constant_override("shadow_offset_y", 2)
	display.add_child(value)
	_cash_value_label = value

	var bulbs := BulbMeterControl.new()
	bulbs.name = "EmailBulbs"
	bulbs.custom_minimum_size = Vector2(178.0, 16.0)
	bulbs.configure(3, [
		Color(0.72, 0.12, 0.12, 1.0),
		Color(0.95, 0.78, 0.20, 1.0),
		Color(0.28, 0.72, 0.30, 1.0)
	], true)
	cluster.add_child(bulbs)
	_email_lights = bulbs

	_mail_caption_label = _make_meter_caption("UNREAD MAIL")
	cluster.add_child(_mail_caption_label)


func _build_clock_cluster(parent: BoxContainer) -> void:
	var cluster := VBoxContainer.new()
	cluster.name = "ClockCluster"
	cluster.custom_minimum_size = Vector2(172.0, 110.0)
	cluster.add_theme_constant_override("separation", 3)
	parent.add_child(cluster)

	var panel := PanelContainer.new()
	panel.name = "ClockModule"
	panel.custom_minimum_size = Vector2(172.0, 72.0)
	panel.add_theme_stylebox_override("panel", _brass_panel_style(14))
	cluster.add_child(panel)
	_decorate_module_panel(panel, 15.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var clock := AnalogClockControl.new()
	clock.custom_minimum_size = Vector2(62.0, 62.0)
	row.add_child(clock)
	_clock_widget = clock

	var readout := VBoxContainer.new()
	readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	readout.add_theme_constant_override("separation", 1)
	row.add_child(readout)

	_day_label = _make_readout_label("DAY 1", 19, Color(0.13, 0.08, 0.05, 1.0))
	readout.add_child(_day_label)

	_digital_time_label = _make_readout_label("09:00", 22, Color(0.10, 0.06, 0.03, 1.0))
	readout.add_child(_digital_time_label)

	_phase_label = _make_readout_label("DAY", 15, Color(0.32, 0.24, 0.13, 1.0))
	readout.add_child(_phase_label)

	cluster.add_child(_make_meter_caption("CAMP CLOCK"))


func _build_conditions_cluster(parent: BoxContainer) -> void:
	var cluster := VBoxContainer.new()
	cluster.name = "ConditionsCluster"
	cluster.custom_minimum_size = Vector2(186.0, 110.0)
	cluster.add_theme_constant_override("separation", 3)
	parent.add_child(cluster)

	var panel := PanelContainer.new()
	panel.name = "ConditionsModule"
	panel.custom_minimum_size = Vector2(186.0, 72.0)
	panel.add_theme_stylebox_override("panel", _brass_panel_style(10))
	cluster.add_child(panel)
	_decorate_module_panel(panel, 15.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var weather_row := HBoxContainer.new()
	weather_row.add_theme_constant_override("separation", 7)
	box.add_child(weather_row)

	var glyph := WeatherGlyphControl.new()
	glyph.custom_minimum_size = Vector2(34.0, 34.0)
	weather_row.add_child(glyph)
	_weather_glyph = glyph

	_weather_label = _make_readout_label("CLEAR", 17, Color(0.12, 0.07, 0.04, 1.0))
	_weather_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weather_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	weather_row.add_child(_weather_label)

	var bar := OccupancyBarControl.new()
	bar.custom_minimum_size = Vector2(0.0, 14.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(bar)
	_occupancy_bar = bar

	_occupancy_label = _make_readout_label("BEDS 0/0", 14, Color(0.14, 0.09, 0.05, 1.0))
	box.add_child(_occupancy_label)

	cluster.add_child(_make_meter_caption("CONDITIONS"))


func _build_health_cluster(parent: BoxContainer) -> void:
	var cluster := VBoxContainer.new()
	cluster.name = "HealthCluster"
	cluster.custom_minimum_size = Vector2(232.0, 110.0)
	cluster.add_theme_constant_override("separation", 3)
	parent.add_child(cluster)

	var panel := PanelContainer.new()
	panel.name = "HealthModule"
	panel.custom_minimum_size = Vector2(232.0, 72.0)
	panel.add_theme_stylebox_override("panel", _brass_panel_style(10))
	cluster.add_child(panel)
	_decorate_module_panel(panel, 15.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 3)
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

	box.add_child(_make_module_caption("HEALTH"))

	var risk_row := HBoxContainer.new()
	risk_row.add_theme_constant_override("separation", 6)
	cluster.add_child(risk_row)

	var bulbs := BulbMeterControl.new()
	bulbs.name = "ForecastBulbs"
	bulbs.custom_minimum_size = Vector2(118.0, 16.0)
	bulbs.configure(4, [
		Color(0.32, 0.74, 0.34, 1.0),
		Color(0.95, 0.80, 0.24, 1.0),
		Color(0.83, 0.18, 0.16, 1.0),
		Color(0.48, 0.07, 0.07, 1.0)
	], false, [3])
	risk_row.add_child(bulbs)
	_forecast_lights = bulbs

	_risk_level_label = _make_readout_label("RAISED", 14, Color(0.90, 0.80, 0.55, 1.0))
	_risk_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_risk_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	risk_row.add_child(_risk_level_label)

	cluster.add_child(_make_meter_caption("NIGHT RISK"))

	_risk_detail_label = _make_meter_caption("")
	_risk_detail_label.add_theme_color_override("font_color", Color(0.83, 0.72, 0.50, 0.92))
	cluster.add_child(_risk_detail_label)


# ═══════════════════════════════════════════════════════════════════════════════
# LABEL / STYLE HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Engraved caption sitting inside a brass module (dark on brass).
func _make_module_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.11, 0.07, 0.04, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.95, 0.84, 0.58, 0.22))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


## Small caption under a meter, painted on the wood itself (light on dark).
func _make_meter_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.74, 0.62, 0.42, 0.94))
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.02, 0.01, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _make_readout_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.92, 0.81, 0.55, 0.18))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _brass_panel_style(corner: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COL_BRASS_MID
	style.border_color = COL_BRASS_DARK
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner)
	style.shadow_color = Color(0.02, 0.01, 0.01, 0.45)
	style.shadow_size = 3
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	return style


func _digital_display_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.03, 1.0)
	style.border_color = Color(0.30, 0.22, 0.12, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _status_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.04, 0.90)
	style.border_color = COL_BRASS_DARK
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	return style


## Brass screw heads in the module corners. Purely decorative.
func _decorate_module_panel(panel: Control, inset: float) -> void:
	for i in range(4):
		var screw := ScrewHead.new()
		screw.custom_minimum_size = Vector2(7.0, 7.0)
		screw.size = Vector2(7.0, 7.0)
		screw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screw.anchor_left = 0.0 if i % 2 == 0 else 1.0
		screw.anchor_right = screw.anchor_left
		screw.anchor_top = 0.0 if i < 2 else 1.0
		screw.anchor_bottom = screw.anchor_top
		var dx: float = inset * 0.32 if i % 2 == 0 else -inset * 0.32 - 7.0
		var dy: float = 4.0 if i < 2 else -11.0
		screw.offset_left = dx
		screw.offset_top = dy
		screw.offset_right = dx + 7.0
		screw.offset_bottom = dy + 7.0
		panel.add_child(screw)


func _set_control_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_control_mouse_passthrough(child)


# ═══════════════════════════════════════════════════════════════════════════════
# RUNTIME BINDINGS + DERIVED VALUES
# ═══════════════════════════════════════════════════════════════════════════════

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
	var safe := maxi(0, count)
	if _email_lights != null:
		_email_lights.set_active_count(safe)
	if _mail_caption_label != null:
		_mail_caption_label.text = "UNREAD MAIL" if safe == 0 else "UNREAD MAIL %d" % safe


func _get_unread_count() -> int:
	if EmailManager == null:
		return 0
	if EmailManager.has_method("get_unread_count"):
		return int(EmailManager.call("get_unread_count"))
	return 0


func _set_day(day: int) -> void:
	var safe := maxi(1, day)
	if safe == _current_day and _day_label != null and not _day_label.text.is_empty():
		return
	_current_day = safe
	if _day_label != null:
		_day_label.text = "DAY %d" % _current_day


func _set_phase(phase: int) -> void:
	var safe := clampi(phase, 0, PHASE_LABELS.size() - 1)
	if safe == _current_phase and _phase_label != null and not _phase_label.text.is_empty():
		return
	_current_phase = safe
	if _phase_label == null:
		return
	_phase_label.text = str(PHASE_LABELS[_current_phase])
	# Night is the phase the player must read instantly -- the builder is locked and
	# whatever was rolled at nightfall is already out there.
	var col := Color(0.32, 0.24, 0.13, 1.0)
	if _current_phase == PHASE_EVENING:
		col = Color(0.52, 0.31, 0.10, 1.0)
	elif _current_phase == PHASE_NIGHT:
		col = Color(0.60, 0.13, 0.11, 1.0)
	_phase_label.add_theme_color_override("font_color", col)


## Mirrors TimeSystem thresholds: day 06:30, evening 18:00, night 20:00.
func _phase_for_minute(minute: int) -> int:
	if minute >= 20 * 60 or minute < 390:
		return PHASE_NIGHT
	if minute >= 18 * 60:
		return PHASE_EVENING
	return PHASE_DAY


func _risk_level_color(level: int) -> Color:
	match clampi(level, 0, 4):
		0:
			return Color(0.58, 0.80, 0.55, 0.95)
		1:
			return Color(0.86, 0.83, 0.55, 0.95)
		2:
			return Color(0.93, 0.72, 0.32, 0.98)
		3:
			return Color(0.92, 0.42, 0.26, 1.0)
		_:
			return Color(0.96, 0.28, 0.24, 1.0)


## One line naming the archetype closest to tipping, so the meter is actionable
## rather than merely ominous.
func _compose_risk_detail(payload: Dictionary) -> String:
	var entries_any = payload.get("archetypes", [])
	if not (entries_any is Array):
		return ""
	var entries: Array = entries_any

	var worst: Dictionary = {}
	var worst_score := -1.0
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var score := float(entry.get("expected_spawns", 0.0))
		if int(entry.get("guaranteed_spawns", 0)) > 0:
			score += 10.0
		if score > worst_score:
			worst_score = score
			worst = entry

	if worst.is_empty():
		return ""

	var label := str(worst.get("label", "?"))
	var count := int(worst.get("count", 0))
	var guaranteed := int(worst.get("guaranteed_spawns", 0))
	if guaranteed > 0:
		return "%s x%d - SPAWN GUARANTEED" % [label, count]

	var tier := str(worst.get("chance_tier", "none"))
	if tier == "none" or tier.is_empty():
		var thresholds_any = worst.get("next_thresholds", {})
		if thresholds_any is Dictionary:
			var small_at := int((thresholds_any as Dictionary).get("small_at", 0))
			if small_at > count:
				return "safe - %s risk starts at %d" % [label, small_at]
		return "all archetypes within safe count"

	var pct := int(round(float(worst.get("chance_probability", 0.0)) * 100.0))
	return "%s x%d - %s risk %d%%" % [label, count, str(RISK_TIER_LABELS.get(tier, tier)).to_upper(), pct]


func _status_color(kind: int) -> Color:
	match kind:
		STATUS_GOOD:
			return Color(0.55, 0.86, 0.52, 1.0)
		STATUS_WARN:
			return Color(0.96, 0.80, 0.36, 1.0)
		STATUS_DENY:
			return Color(0.96, 0.42, 0.34, 1.0)
		_:
			return COL_TEXT


func _update_status_strip(delta: float) -> void:
	if _status_panel == null or not _status_panel.visible:
		return
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_panel.visible = false
		_status_panel.modulate.a = 1.0
		return
	if _status_timer < STATUS_FADE_SEC:
		_status_panel.modulate.a = clampf(_status_timer / STATUS_FADE_SEC, 0.0, 1.0)


func _poll_bed_metrics() -> void:
	if GuestManager == null or not GuestManager.has_method("get_bed_metrics"):
		return
	var metrics_any = GuestManager.call("get_bed_metrics")
	if not (metrics_any is Dictionary):
		return
	var metrics: Dictionary = metrics_any
	set_bed_metrics(int(metrics.get("occupied", 0)), int(metrics.get("capacity", 0)))


func _poll_money_from_core() -> void:
	if CoreRoot == null or not CoreRoot.has_method("get_money"):
		return
	_apply_money_amount(int(CoreRoot.get_money()))


func _apply_money_amount(amount: int) -> void:
	if _cash_value_label == null:
		return
	if _cash_known and amount == _cash_amount:
		return
	var delta := amount - _cash_amount if _cash_known else 0
	_cash_amount = amount
	_cash_known = true
	_cash_value_label.text = "$%s" % _format_money(amount)
	if delta != 0:
		_trigger_cash_glow(delta)


func _trigger_cash_glow(delta: int) -> void:
	if _cash_glow_overlay == null:
		return
	_cash_glow_duration = 0.85
	_cash_glow_time = _cash_glow_duration
	_cash_glow_overlay.color = Color(0.35, 1.0, 0.45, 0.0) if delta > 0 else Color(1.0, 0.32, 0.22, 0.0)


func _update_cash_glow(delta: float) -> void:
	if _cash_glow_overlay == null or _cash_glow_time <= 0.0:
		return
	_cash_glow_time = maxf(0.0, _cash_glow_time - delta)
	var t := _cash_glow_time / maxf(_cash_glow_duration, 0.0001)
	_cash_glow_overlay.color.a = 0.30 * t * t


func _format_money(amount: int) -> String:
	var negative := amount < 0
	var digits := str(absi(amount))
	var out := ""
	var counter := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		counter += 1
		if counter % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if negative else out


func _parse_time_to_minutes(time_str: String) -> int:
	var parts := time_str.strip_edges().split(":")
	if parts.size() < 2:
		return 9 * 60
	return (int(parts[0]) * 60) + int(parts[1])


func _try_trigger_clock_phase(minute: int) -> void:
	if _clock_widget == null:
		return
	if minute == 390 and _last_clock_marker_minute != 390:
		_clock_widget.trigger_phase_pulse(Color(1.0, 0.83, 0.33, 1.0))
		push_status("DAY MODE - builder unlocked", STATUS_GOOD)
	elif minute == 1200 and _last_clock_marker_minute != 1200:
		_clock_widget.trigger_phase_pulse(Color(0.42, 0.58, 0.95, 1.0))
		push_status("NIGHT MODE - builder locked", STATUS_WARN)
	_last_clock_marker_minute = minute
