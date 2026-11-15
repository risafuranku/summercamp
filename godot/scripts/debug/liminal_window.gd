extends CanvasLayer

## The night forecast's debug window (the debug menu's "Liminal forecast window"; out of
## main.gd 15. 11.): what tonight's guests make likely, the night's roll, the last nights,
## the enemies out and the active brain's state, written out in plain lines over the game.
## It reads main's night state (the forecast, the roll, the history, the brain) and is
## refreshed by main when that changes and every 0.35 s while it is shown.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const REFRESH_SEC := 0.35

var main: Node
var shown := false
var _text: RichTextLabel
var _accum := 0.0


func _init(main_node: Node) -> void:
	main = main_node
	name = "LiminalDebugLayer"
	layer = 90
	visible = false


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.name = "LiminalDebugPanel"
	panel.offset_left = 14.0
	panel.offset_top = 14.0
	panel.offset_right = 640.0
	panel.offset_bottom = 420.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", RETRO_UI.flat_box(Color(0.05, 0.05, 0.05, 0.84), Color(0.52, 0.10, 0.10, 0.95), 2, 1, 3))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	_text = RichTextLabel.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.bbcode_enabled = false
	_text.scroll_active = true
	_text.fit_content = false
	_text.selection_enabled = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 14)
	_text.add_theme_color_override("default_color", Color(0.94, 0.94, 0.94, 1.0))
	margin.add_child(_text)
	visible = shown


func toggle() -> void:
	show_window(not shown)


func show_window(on: bool) -> void:
	shown = on
	_accum = 0.0
	visible = on
	if on:
		refresh()


## Every frame from main: written again now and then while shown.
func tick(delta: float) -> void:
	if not shown:
		return
	_accum += maxf(delta, 0.0)
	if _accum >= REFRESH_SEC:
		_accum = 0.0
		refresh()


func refresh() -> void:
	if _text == null or not shown:
		return
	var lines: Array[String] = []
	var state_name := "day"
	if int(main._time_state) == int(main.TIME_EVENING):
		state_name = "evening"
	elif int(main._time_state) == int(main.TIME_NIGHT):
		state_name = "night"
	lines.append("Liminal Forecast Debug [L]")
	lines.append("Day %d | %s | phase=%s" % [int(main._day_index), main._time_of_day_string(), state_name])
	_forecast_lines(lines, main._night_roll.forecast)
	_roll_lines(lines, main._night_roll.roll_snapshot)
	var active_enemy_count := get_tree().get_nodes_in_group("enemies").size() if get_tree() != null else 0
	var virtual_count := int(main._night_roll.virtual_count)
	lines.append("")
	lines.append("Runtime Enemies Active=%d (virtual=%d, scene=%d)" % [virtual_count + active_enemy_count, virtual_count, active_enemy_count])
	lines.append("Runtime target this night (quiet guy): %d" % int(main._night_roll.spawned_this_night))
	var brain = main._active_enemy_brain
	if brain != null and is_instance_valid(brain) and brain.has_method("get_debug_snapshot"):
		var snap_any = brain.get_debug_snapshot()
		var snap: Dictionary = snap_any if snap_any is Dictionary else {}
		lines.append("Active brain: %s | state=%s" % [str(main._active_enemy_brain_id), str(snap.get("state", "unknown"))])
		lines.append("- scares=%d (recent=%d) | peeks=%d | attack_hits=%d" % [
			int(snap.get("successful_scares", 0)), int(snap.get("recent_successes", 0)),
			int(snap.get("close_peeks", 0)), int(snap.get("damage_hits", 0))])
		lines.append("- footsteps=%d | visual_spawns=%d | entity_visible=%s" % [
			int(snap.get("footstep_bursts", 0)), int(snap.get("visual_spawns", 0)), str(bool(snap.get("entity_visible", false)))])
	if int(main._night_roll.last_despawn_day) > 0:
		lines.append("Last day-start despawn: day %d -> removed %d enemies" % [int(main._night_roll.last_despawn_day), int(main._night_roll.last_despawn_count)])
	_text.text = "\n".join(lines)


func _forecast_lines(lines: Array[String], forecast: Dictionary) -> void:
	lines.append("")
	if forecast.is_empty():
		lines.append("Forecast: unavailable")
		return
	var totals: Dictionary = forecast.get("totals", {}) if forecast.get("totals", {}) is Dictionary else {}
	lines.append("Forecast Summary:")
	lines.append("Guests=%d | expected transforms=%.2f | guaranteed=%d | pressure archetypes=%d | HUD=%d/4" % [
		int(totals.get("guests", 0)), float(totals.get("expected_spawns", 0.0)), int(totals.get("guaranteed_spawns", 0)),
		int(totals.get("pressure_archetypes", 0)), int(main._night_roll.hud_level)])
	lines.append("Archetypes:")
	var entries: Array = forecast.get("archetypes", []) if forecast.get("archetypes", []) is Array else []
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		lines.append("- %s | guests=%d (+%d over safe) | should transform=%.2f | guaranteed=%d | chance=%d%% (%s)" % [
			str(entry.get("label", "Unknown")), int(entry.get("count", 0)), int(entry.get("over_safe", 0)),
			float(entry.get("expected_spawns", 0.0)), int(entry.get("guaranteed_spawns", 0)),
			int(round(clampf(float(entry.get("chance_probability", 0.0)), 0.0, 1.0) * 100.0)), str(entry.get("chance_tier", "none"))])


func _roll_lines(lines: Array[String], roll: Dictionary) -> void:
	lines.append("")
	lines.append("Night Roll:")
	if roll.is_empty():
		lines.append("No night roll yet.")
		return
	lines.append("Night #%d at %s | spawned=%d (guaranteed=%d + chance=%d/%d) | expected=%.2f" % [
		int(roll.get("night_id", 0)), str(roll.get("rolled_time", "--:--")), int(roll.get("spawned_total", 0)),
		int(roll.get("spawned_guaranteed", 0)), int(roll.get("spawned_from_chance", 0)), int(roll.get("chance_checks", 0)),
		float(roll.get("expected_total", 0.0))])
	var rolled_entries: Array = roll.get("entries", []) if roll.get("entries", []) is Array else []
	for rolled_any in rolled_entries:
		if not (rolled_any is Dictionary):
			continue
		var rolled: Dictionary = rolled_any
		var roll_value := float(rolled.get("chance_roll", -1.0))
		lines.append("- %s | spawned=%d | guaranteed=%d | chance=%d%% | roll=%s" % [
			str(rolled.get("label", "Unknown")), int(rolled.get("spawned", 0)), int(rolled.get("guaranteed_spawns", 0)),
			int(round(clampf(float(rolled.get("chance_probability", 0.0)), 0.0, 1.0) * 100.0)),
			"-" if roll_value < 0.0 else "%.3f" % roll_value])
	var history: Array = main._night_roll.spawn_history
	if not history.is_empty():
		lines.append("Recent nights:")
		for i in range(history.size() - 1, maxi(history.size() - 4, -1), -1):
			var hist = history[i]
			lines.append("- night #%d: spawned %d (expected %.2f)" % [int(hist.get("night_id", 0)), int(hist.get("spawned_total", 0)), float(hist.get("expected_total", 0.0))])
