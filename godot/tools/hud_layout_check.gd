extends Node

## Headless layout check for the world HUD.
##
## Run it as a SCENE, not with --script: hud_manager.gd references the EmailManager /
## GuestManager / CoreRoot autoloads, and --script mode does not register autoloads,
## so the HUD would fail to compile and the check would report a false pass.
##
##   godot --headless --path godot res://tools/hud_layout_check.tscn
##
## Layout is forced synchronously (sort + combined minimum sizes) rather than by
## waiting for frames, so the check is deterministic and cannot hang.

const HUD_MANAGER_SCRIPT = preload("res://scripts/hud_manager.gd")

const TEST_WIDTHS := [1280, 1600, 1920]
const EXPECTED_CAPTIONS := [
	"CASH", "UNREAD MAIL", "CAMP CLOCK", "CONDITIONS", "HEALTH", "NIGHT RISK",
]
const EXPECTED_READOUTS := ["DAY 3", "18:42", "EVENING", "RAIN", "BEDS 4/9", "RAISED"]

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
	for width in TEST_WIDTHS:
		failures.append_array(_check_width(width))

	print("")
	if failures.is_empty():
		print("HUD LAYOUT CHECK: PASS")
		get_tree().quit(0)
	else:
		print("HUD LAYOUT CHECK: %d FAILURE(S)" % failures.size())
		for f in failures:
			print("  - %s" % f)
		get_tree().quit(1)


func _check_width(width: int) -> Array[String]:
	var failures: Array[String] = []

	var hud = HUD_MANAGER_SCRIPT.new()
	if hud == null:
		return ["width %d: HudManager script failed to instantiate" % width] as Array[String]
	add_child(hud)
	hud.setup_money_hud()

	hud.update_time("18:42", 3)
	hud.update_weather(4)
	hud.set_bed_metrics(4, 9)
	hud.set_health_ratio(0.62)
	hud.set_liminal_forecast(SAMPLE_FORECAST)
	hud.push_status("Build rejected: insufficient funds", 3)

	var hud_root := hud.get_node_or_null("RetroHudLayer/RetroHudRoot") as Control
	if hud_root == null:
		hud.free()
		return ["width %d: HUD root was never built" % width] as Array[String]

	_force_layout(hud_root, Rect2(Vector2.ZERO, Vector2(float(width), 720.0)))

	var bar := hud_root.get_node_or_null("BottomBar") as Control
	if bar == null or bar.get_child_count() == 0:
		hud.free()
		return ["width %d: bottom bar missing" % width] as Array[String]
	var modules := bar.get_child(0).get_child(0) as Control

	print("")
	print("=== viewport %d x 720 ===" % width)
	var total := 0.0
	for child in modules.get_children():
		var module := child as Control
		if module == null:
			continue
		var min_size := module.get_combined_minimum_size()
		print("  %-20s min_w=%6.1f  min_h=%6.1f" % [module.name, min_size.x, min_size.y])
		total += min_size.x

	var tallest := 0.0
	var tallest_name := ""
	for child in modules.get_children():
		var module := child as Control
		if module == null:
			continue
		var h := module.get_combined_minimum_size().y
		if h > tallest:
			tallest = h
			tallest_name = str(module.name)
	var inner_height: float = HUD_MANAGER_SCRIPT.BAR_HEIGHT 		- float(HUD_MANAGER_SCRIPT.BAR_MARGIN_TOP) 		- float(HUD_MANAGER_SCRIPT.BAR_MARGIN_BOTTOM)
	print("  tallest module: %s at %.1f   bar inner height = %.1f" % [tallest_name, tallest, inner_height])
	if tallest > inner_height:
		failures.append("width %d: '%s' is %.1f px tall, bar allows %.1f (overflow %.1f)" % [
			width, tallest_name, tallest, inner_height, tallest - inner_height])

	var separation := float(modules.get_theme_constant("separation"))
	var module_count := modules.get_child_count()
	var needed: float = total + (separation * float(maxi(0, module_count - 1))) + 28.0
	print("  modules: %d   content+gaps+margins = %.1f   available = %d" % [module_count, needed, width])

	if module_count < 4:
		failures.append("width %d: expected 4 HUD modules, found %d" % [width, module_count])
	if needed > float(width):
		failures.append("width %d: HUD needs %.1f px, overflows by %.1f" % [width, needed, needed - float(width)])

	var labels := _collect_labels(hud_root)
	for expected in EXPECTED_CAPTIONS:
		var found := false
		for text in labels:
			if text.begins_with(expected):
				found = true
				break
		if not found:
			failures.append("width %d: caption '%s' missing" % [width, expected])

	if width == TEST_WIDTHS[0]:
		var rendered: Array[String] = []
		for expected_value in EXPECTED_READOUTS:
			if labels.has(expected_value):
				rendered.append(expected_value)
			else:
				failures.append("readout '%s' not rendered" % expected_value)
		print("  readouts: %s" % ", ".join(rendered))
		print("  risk detail: '%s'" % _find_label_containing(labels, "Drunk"))
		print("  status strip: '%s'" % _find_label_containing(labels, "rejected"))

	hud.free()
	return failures


## Sort containers recursively so minimum sizes settle without waiting for frames.
func _force_layout(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		var control := child as Control
		if control == null:
			continue
		if control.size == Vector2.ZERO:
			control.size = control.get_combined_minimum_size()
		_force_layout(control, Rect2(control.position, control.size))


func _collect_labels(node: Node, out: Array[String] = []) -> Array[String]:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_collect_labels(child, out)
	return out


func _find_label_containing(labels: Array[String], needle: String) -> String:
	for text in labels:
		if text.contains(needle):
			return text
	return "(none)"
