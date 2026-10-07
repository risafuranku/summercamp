extends Node

## Headless layout check for the world HUD (Build-engine status bar).
##
## Run it as a SCENE, not with --script: hud_manager.gd references the EmailManager /
## GuestManager / CoreRoot autoloads, and --script mode does not register autoloads,
## so the HUD would fail to compile and the check would report a false pass.
##
##   godot --headless --path godot res://tools/hud_layout_check.tscn
##
## For each logical viewport size (the project stretches canvas_items with aspect
## "expand", so the logical size is what matters) it builds the HUD, feeds it sample
## data, forces layout synchronously and asserts: every status-bar cell fits the bar
## height, the row of cells fits the viewport width, and the readouts render.

const HUD_MANAGER_SCRIPT = preload("res://scripts/hud_manager.gd")

const TEST_SIZES := [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(1280, 960), Vector2i(1280, 800), Vector2i(1680, 720)]
const EXPECTED_CAPTIONS := ["HEALTH", "STAMINA", "LIGHT", "CASH", "DAY 3", "EVENING", "GUESTS", "MAIL", "NIGHT RISK"]
const EXPECTED_READOUTS := ["62", "$1,234", "18:42", "RAIN", "DRUNK 27%"]

const SAMPLE_FORECAST := {
	"ok": true,
	"hud_level": 2,
	"safe_count": 3,
	"totals": {"guests": 9, "expected_spawns": 0.41, "guaranteed_spawns": 0},
	"archetypes": [{
		"archetype": "drunk", "label": "Drunk", "count": 7,
		"guaranteed_spawns": 0, "chance_tier": "small",
		"chance_probability": 0.27, "expected_spawns": 0.27,
		"next_thresholds": {"small_at": 6, "medium_at": 12, "large_at": 18, "guaranteed_at": 24},
	}],
}


func _ready() -> void:
	var failures: Array[String] = []
	# A script that fails to compile still loads as a GDScript resource; without this the
	# per-size checks error out silently and the harness would report a false PASS.
	var hud_script: Script = load("res://scripts/hud_manager.gd")
	if not hud_script.can_instantiate():
		print("HUD LAYOUT CHECK: FAILED - hud_manager.gd does not compile")
		get_tree().quit(1)
		return
	for size in TEST_SIZES:
		failures.append_array(await _check_size(size))
	print("")
	if failures.is_empty():
		print("HUD LAYOUT CHECK: PASS")
		get_tree().quit(0)
	else:
		print("HUD LAYOUT CHECK: %d FAILURE(S)" % failures.size())
		for f in failures:
			print("  - %s" % f)
		get_tree().quit(1)


func _check_size(size: Vector2i) -> Array[String]:
	var failures: Array[String] = []
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.size = size
	await get_tree().process_frame

	CoreRoot.apply_changes({"money": 1234})
	var hud = HUD_MANAGER_SCRIPT.new()
	add_child(hud)
	hud.setup_money_hud()
	hud.update_time("18:42", 3)
	hud.update_weather(4)
	hud.on_money_changed(1234)
	hud.set_bed_metrics(4, 9)
	hud.set_health_ratio(0.62)
	hud.set_liminal_forecast(SAMPLE_FORECAST)
	hud.push_status("Build rejected: insufficient funds", 3)
	hud.set_objective({"title": "Vera's checklist", "text": "Guests get hungry. Build a Jednota Mart, a Bistro or a Pub so nobody has to walk to the village.", "hint": "Builder: Services. Food needs power.", "reward": "$150"})
	hud.show_guest_card({"name": "Pepa", "archetype": "drunk", "party_size": 2, "mood": 48.0, "mood_label": "Grumpy", "needs": {"energy": 80.0, "hunger": 30.0}, "thought": "One more beer. Just one, I promise."})
	hud.show_banner("TASK COMPLETE", "+$150", Color(0.46, 0.86, 0.36), 5.0)
	for i in 4:
		await get_tree().process_frame

	var root := hud.get_node_or_null("RetroHudLayer/RetroHudRoot") as Control
	if root == null:
		hud.free()
		return ["%s: HUD root was never built" % size] as Array[String]
	var bar := root.get_node_or_null("StatusBar") as Control
	var cells := bar.get_node_or_null("Cells") as Control if bar != null else null
	if bar == null or cells == null:
		hud.free()
		return ["%s: status bar missing" % size] as Array[String]

	var scale := int(hud.get("_scale"))
	var bar_h := float(HUD_MANAGER_SCRIPT.BAR_HEIGHT_VP * scale)
	var inner_h := bar_h - 6.0 * scale
	var total_w := 0.0
	print("")
	print("=== logical %d x %d  (ui scale %d) ===" % [size.x, size.y, scale])
	for child in cells.get_children():
		var cell := child as Control
		if cell == null:
			continue
		var have := cell.custom_minimum_size
		total_w += have.x
		print("  %-14s cell %4dx%3d" % [cell.name, have.x, have.y])
		if have.y > inner_h + 0.5:
			failures.append("%s: %s taller than the bar" % [size, cell.name])
		var content := cell.get_node_or_null("Content") as Control
		if content == null:
			failures.append("%s: %s has no content" % [size, cell.name])
			continue
		var inner_w := have.x - 4.0 * scale
		for item in content.get_children():
			var l := item as Label
			if l == null:
				continue
			var font := l.get_theme_font("font")
			var fsize := l.get_theme_font_size("font_size")
			var text_w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			var baseline := l.offset_top + font.get_ascent(fsize)
			var avail_w := inner_w - l.offset_left
			if text_w > avail_w + 0.5:
				failures.append("%s: %s '%s' is %.0fpx wide, room %.0fpx" % [size, cell.name, l.text, text_w, avail_w])
			if baseline > have.y - 1.0 * scale:
				failures.append("%s: %s '%s' baseline %.0f below cell %.0f" % [size, cell.name, l.text, baseline, have.y])
	total_w += float(cells.get_theme_constant("separation")) * float(cells.get_child_count() - 1)
	print("  cells total width %.0f of %d" % [total_w, size.x])
	if total_w > float(size.x):
		failures.append("%s: status bar needs %.0fpx, viewport is %d" % [size, total_w, size.x])
	# The clock caption ("DAY 12") and the weather word share one row.
	var clock_content := cells.get_node_or_null("Cell_clock/Content") as Control
	if clock_content != null:
		var cap_font := clock_content.get_child(0).get_theme_font("font") as Font
		var fsize := (clock_content.get_child(0) as Label).get_theme_font_size("font_size")
		var need := cap_font.get_string_size("DAY 12", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + cap_font.get_string_size("ANOMALY", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + float(scale) * 3.0
		if need > clock_content.size.x + 0.5:
			failures.append("%s: 'DAY 12' + 'ANOMALY' need %.0fpx, clock row has %.0fpx" % [size, need, clock_content.size.x])

	var labels := _collect_labels(root)
	for expected in EXPECTED_CAPTIONS:
		if not labels.has(expected):
			failures.append("%s: caption '%s' missing" % [size, expected])
	for expected_value in EXPECTED_READOUTS:
		if not labels.has(expected_value):
			failures.append("%s: readout '%s' missing (labels: %s)" % [size, expected_value, ", ".join(labels)])
	var objective := root.get_node_or_null("Objective") as Control
	var card := root.get_node_or_null("GuestCard") as Control
	var feed := root.get_node_or_null("MessageFeed") as Control
	var banner := root.get_node_or_null("Banner") as Control
	if objective == null or not objective.visible:
		failures.append("%s: objective tracker not shown" % size)
	else:
		var o_rect := objective.get_global_rect()
		print("  tracker %s" % o_rect)
		if o_rect.end.x > float(size.x) + 0.5 or o_rect.position.x < 0.0:
			failures.append("%s: objective tracker off-screen" % size)
		if card != null and card.visible:
			var c_rect := card.get_global_rect()
			print("  card    %s" % c_rect)
			if c_rect.intersects(o_rect):
				failures.append("%s: guest card overlaps the tracker" % size)
			if c_rect.end.y > float(size.y) - bar_h:
				failures.append("%s: guest card runs into the status bar" % size)
		if feed != null and feed.get_global_rect().intersects(o_rect):
			failures.append("%s: message feed runs under the tracker" % size)
	if banner == null or not banner.visible:
		failures.append("%s: banner not shown" % size)
	hud.free()
	return failures


func _collect_labels(node: Node, out: Array[String] = []) -> Array[String]:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_collect_labels(child, out)
	return out
