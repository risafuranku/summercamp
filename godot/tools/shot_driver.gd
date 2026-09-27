extends Node

## Scripted screenshot driver for visual verification.
##
## Boots the real main scene, walks it through a named scenario and writes PNGs.
## It re-parents itself to the SceneTree root before swapping scenes, so it survives
## the change to `main.tscn` and can keep poking the live game.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 \
##       res://tools/shot_driver.tscn -- --scenario=tour --out=/tmp/shots
##
## Scenarios are plain step lists (see SCENARIOS). Steps:
##   ["wait", seconds]          real-time wait
##   ["shot", "name"]           save <out>/<name>.png
##   ["call", "method", args]   call a method on Main
##   ["call_on", "prop", "method", args]  call a method on one of Main's members
##   ["hours", h]               advance the in-game clock by h hours
##   ["eval", "expr"]           evaluate a GDScript Expression with Main as base
##
## Debug tooling only; never referenced by the game itself.

const MAIN_SCENE := "res://scenes/main.tscn"

const SCENARIOS := {
	"boot": [
		["wait", 0.4], ["shot", "00_loading"],
		["wait_menu"], ["wait", 2.5], ["shot", "01_menu"],
	],
	"views": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_player.rotate_y(PI)"], ["wait", 1.0], ["shot", "10_day_camp"],
		["eval", "_player.rotate_y(PI * 0.5)"], ["wait", 1.0], ["shot", "11_day_side"],
		["hours", 9.5], ["wait", 2.0], ["eval", "_player.rotate_y(PI * 0.5)"], ["wait", 1.0], ["shot", "12_dusk"],
		["hours", 3.0], ["wait", 3.0], ["shot", "13_night"],
	],
	"tour": [
		["wait_menu"], ["wait", 2.0], ["shot", "01_menu"],
		["call", "_on_menu_new_game_pressed", []],
		["wait", 0.25], ["shot", "02_loading_new"],
		["wait_gameplay"], ["wait", 2.5], ["shot", "03_gameplay"],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 6.0], ["shot", "04_crt"],
	],
}

var _main: Node
var _out_dir := "user://shots"
var _steps: Array = []
var _step_index := 0
var _wait_left := 0.0
var _waiting_for := ""


func _ready() -> void:
	var scenario := "boot"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			_out_dir = arg.get_slice("=", 1)
	_steps = SCENARIOS.get(scenario, SCENARIOS["boot"]).duplicate(true)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_detach_and_boot")


func _detach_and_boot() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	get_tree().change_scene_to_file(MAIN_SCENE)


func _process(delta: float) -> void:
	if _main == null or not is_instance_valid(_main):
		_main = get_tree().current_scene
		if _main == null or _main == self:
			return
	if _wait_left > 0.0:
		_wait_left -= delta
		return
	if not _waiting_for.is_empty():
		if not _condition_met(_waiting_for):
			return
		_waiting_for = ""
	if _step_index >= _steps.size():
		print("SHOT DRIVER: done")
		get_tree().quit(0)
		set_process(false)
		return
	var step: Array = _steps[_step_index]
	_step_index += 1
	_run_step(step)


func _condition_met(what: String) -> bool:
	match what:
		"menu":
			return bool(_main.get("_startup_bootstrap_complete")) and bool(_main.get("_menu_mode"))
		"gameplay":
			return bool(_main.get("_gameplay_started")) and not bool(_main.get("_menu_mode"))
	return true


func _run_step(step: Array) -> void:
	var kind := str(step[0])
	match kind:
		"wait":
			_wait_left = float(step[1])
		"wait_menu":
			_waiting_for = "menu"
		"wait_gameplay":
			_waiting_for = "gameplay"
		"shot":
			_save_shot(str(step[1]))
		"call":
			var args: Array = step[2] if step.size() > 2 else []
			if _main.has_method(str(step[1])):
				_main.callv(str(step[1]), args)
			else:
				push_warning("SHOT DRIVER: Main has no method %s" % step[1])
		"call_on":
			var target = _main.get(str(step[1]))
			var args2: Array = step[3] if step.size() > 3 else []
			if target != null and target.has_method(str(step[2])):
				target.callv(str(step[2]), args2)
			else:
				push_warning("SHOT DRIVER: %s has no method %s" % [step[1], step[2]])
		"hours":
			var ts = _main.get("time_system")
			if ts != null:
				ts.step_time_hours(float(step[1]))
				_main.call("_sync_runtime_state_from_systems", true)
		"eval":
			var expr := Expression.new()
			if expr.parse(str(step[1])) == OK:
				var result = expr.execute([], _main)
				if expr.has_execute_failed():
					push_warning("SHOT DRIVER: eval failed: %s" % step[1])
				else:
					print("SHOT DRIVER eval: %s -> %s" % [step[1], str(result)])
			else:
				push_warning("SHOT DRIVER: eval parse error: %s" % expr.get_error_text())


func _save_shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	print("SHOT DRIVER: %s -> %s (%s)" % [shot_name, path, error_string(err)])
