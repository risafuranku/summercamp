extends "res://tools/shot_driver.gd"

## The walk's feel in numbers (the user 4. 11.: "the walk is floaty, I want to feel the
## steps", after GREED's): the warden walks, then runs, on open ground; per footfall the
## head's drop (cm), nod (deg, nose down) and roll (deg), and the steps a second ("KROKY ...").
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/kroky_check.tscn

const C := "get_tree().root.get_node('KrokyCheck')"
var _rec := false
var _t := 0.0
var _y: Array = []
var _pitch: Array = []
var _roll: Array = []
var _n := 0


func _process(delta: float) -> void:
	super._process(delta)
	if not _rec or _main == null:
		return
	_t += delta
	var head: Node3D = _main.get("_player").get_node("Head")
	_y.append(head.position.y)
	_pitch.append(rad_to_deg(float(_main.get("_player").get("_step_nod")) + float(_main.get("_player").get("_run_nod"))))
	_roll.append(rad_to_deg(head.rotation.z))


func start(label: String) -> String:
	_rec = true
	_t = 0.0
	_y.clear()
	_pitch.clear()
	_roll.clear()
	if not _main.get("_player").is_connected("foot_fell", _on_foot):
		_main.get("_player").connect("foot_fell", _on_foot)
	_n = 0
	return "rec " + label


func _on_foot(_left: bool) -> void:
	_n += 1


func stop(label: String) -> String:
	_rec = false
	var line := "KROKY %s: %.2f steps/s, head y %.1f cm range, nod %.2f..%.2f deg, roll %.2f..%.2f deg" % [label, float(_n) / maxf(_t, 0.01), (_y.max() - _y.min()) * 100.0, _pitch.min(), _pitch.max(), _roll.min(), _roll.max()]
	print(line)
	return line


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.4],
		["key", "Escape"], ["wait", 2.5],
		["player", 14, 6, 90.0], ["wait", 1.0],
		["keyhold", "W", true], ["wait", 0.8], ["eval", C + ".start('walk')"], ["wait", 3.0], ["eval", C + ".stop('walk')"],
		["keyhold", "Shift", true], ["wait", 0.8], ["eval", C + ".start('run')"], ["wait", 2.5], ["eval", C + ".stop('run')"],
		["keyhold", "Shift", false], ["keyhold", "W", false], ["wait", 0.5],
	]
