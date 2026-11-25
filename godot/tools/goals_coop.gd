extends "res://tools/coop_check.gd"

## A camp's goals for two (core/systems/goal_rules.gd, 25. 11.): the host's camp with the till's
## goal; the till filled on the host, the goal met there: on the other machine the books say so
## (CampStat's GOALS page reads them) and the banner and the fanfare came there too.
## Tagged "GOAL_TAG [tag, ...]" for tools/goals_coop.py.
##   godot --path godot res://tools/goals_coop.tscn -- --role=host --out=DIR


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "get_node('/root/CoreRoot').actions.set_goals(['money', 'guests'])"], ["money", 0],
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 2.0], ["goal_tag", "host_before"],
			["eval", "get_node('/root/CoreRoot').apply_changes({'money': 12000})"], ["wait", 4.0], ["goal_tag", "host_met"],
			["coop_signal", "host_met"], ["coop_wait_file", "client_ended"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["goal_tag", "client_before"], ["coop_signal", "client_in"],
			["coop_wait_file", "host_met"], ["wait", 3.0], ["goal_tag", "client_met"],
			["coop_signal", "client_ended"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	if str(step[0]) == "goal_tag":
		var g: Dictionary = CoreRoot.get_state().goals
		var w = _main.get("_goal_watch")
		print("GOAL_TAG %s" % JSON.stringify([str(step[1]), g.get("chosen", []), (g.get("done", {}) as Dictionary).keys(), int(w.get("celebrated")) if w != null else -1]))
		return
	super._run_step(step)
