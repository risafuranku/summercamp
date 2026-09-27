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
##   ["money", amount]          set cash
##   ["clear", x, y, w, h]      bulldoze trees/buildings in a rect (<= 5x5, real builder path)
##   ["build", type, x, y, rot] request a build through the real builder authority
##   ["book", name, archetype, party, nights]  confirm a booking (GuestManager path)
##   ["player", x, y, yaw_deg]  put the player on a grid tile facing yaw
##   ["timescale", k]           Engine.time_scale
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
	"guests": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 20000],
		["clear", 2, 3, 5, 5], ["clear", 7, 3, 5, 5], ["clear", 12, 3, 5, 5],
		["clear", 2, 8, 5, 5], ["clear", 7, 8, 5, 5], ["clear", 12, 8, 5, 5],
		["build", "path", 9, 3, 0], ["build", "path", 9, 4, 0], ["build", "path", 9, 5, 0], ["build", "path", 9, 6, 0],
		["build", "path", 10, 3, 0], ["build", "path", 8, 4, 0], ["build", "path", 7, 4, 0], ["build", "path", 11, 4, 0],
		["build", "tent_1", 4, 5, 0], ["build", "tent_1", 5, 5, 0], ["build", "tent_1", 6, 6, 0],
		["build", "cabin_1", 12, 6, 0], ["build", "toilet_block", 7, 7, 0], ["build", "shower_block", 8, 8, 0],
		["build", "vecerka", 12, 9, 0], ["build", "bonfire", 5, 10, 0], ["build", "lamp_post", 10, 7, 0],
		["wait", 0.5],
		["book", "Novak family", "quiet_guy", 2, 2], ["book", "Pepa", "drunk", 1, 2], ["book", "Kristyna", "cheap_chick", 1, 1],
		["player", 9, 2, 180.0], ["timescale", 3.0],
		["wait", 3.0], ["shot", "20_arrivals"],
		["wait", 10.0], ["shot", "21_camp_life"],
		["hours", 3.0], ["wait", 4.0], ["shot", "22_camp_later"],
		["player", 10, 6, 90.0], ["wait", 2.0], ["shot", "23_close"],
		["player", 8, 4, 150.0], ["wait", 2.0], ["shot", "24_close2"],
		["timescale", 1.0],
	],
	"hud": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 5000], ["clear", 7, 3, 5, 5], ["build", "tent_1", 8, 5, 0], ["build", "tent_1", 9, 5, 0],
		["build", "toilet_block", 10, 5, 0],
		["book", "Pepa", "drunk", 2, 2],
		["player", 9, 2, 180.0], ["wait", 2.0],
		["eval", "_hud_manager.push_status('Build confirmed: Toilet Block', 1)"],
		["eval", "_hud_manager.show_quote('Pepa', 'One more beer. Just one.', 70.0)"],
		["eval", "_hud_manager.set_objective({'title': \"Vera's checklist\", 'text': 'Build a toilet block so guests stop using the bushes.', 'progress': '0/1', 'reward': '$150'})"],
		["eval", "_hud_manager.set_hint_text('[E] Enter reception')"],
		["eval", "_hud_manager.show_banner('NIGHT 1', 'BUILDER LOCKED. SURVIVE UNTIL 06:30.', Color(1.0, 0.3, 0.24), 6.0)"],
		["wait", 1.0], ["shot", "30_hud"],
		["guest_card"],
		["wait", 0.5], ["shot", "31_hud_card"],
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
		"money":
			CoreRoot.apply_changes({"money": int(step[1])})
		"clear":
			EventBus.RequestDemolish.emit(Rect2i(int(step[1]), int(step[2]), int(step[3]), int(step[4])))
		"build":
			EventBus.RequestBuild.emit(str(step[1]), Vector2i(int(step[2]), int(step[3])), int(step[4]))
		"book":
			EventBus.customer_booking_confirmed.emit({
				"guest_name": str(step[1]), "archetype": str(step[2]),
				"guests": int(step[3]), "nights": int(step[4]), "from": "%s <guest@mail>" % step[1],
			})
		"player":
			var player = _main.get("_player")
			var gm = _main.get("grid_manager")
			if player != null and gm != null:
				player.global_position = gm.grid_to_world(Vector2i(int(step[1]), int(step[2]))) + Vector3(0, 0.2, 0)
				player.rotation.y = deg_to_rad(float(step[3]))
		"guest_card":
			var snap: Array = GuestManager.get_guest_life_snapshot()
			if not snap.is_empty():
				_main.get("_hud_manager").show_guest_card(snap[0])
		"timescale":
			Engine.time_scale = float(step[1])
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
