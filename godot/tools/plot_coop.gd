extends "res://tools/coop_check.gd"

## A sandbox camp's land for two (core/systems/plot_rules.gd, 25. 11.): the host's camp on the
## small plot; the other warden has the same plot, buys the west strip in their Builder 98
## (the host pays, the plot grows on both), and a cabin they put down off the plot is turned
## down. Tagged "PLOT_TAG [tag, ...]" for tools/plot_coop.py.
##   godot --path godot res://tools/plot_coop.tscn -- --role=host --out=DIR


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["money", 40000], ["eval", "get_node('/root/CoreRoot').actions.set_plot([9, 0, 21, 12])"], ["wait", 1.0],
			["plot_tag", "host_start"], ["coop_signal", "host_up"],
			["coop_wait_file", "client_bought"], ["wait", 2.0], ["plot_tag", "host_bought"],
			["coop_signal", "host_seen"], ["coop_wait_file", "client_built"], ["wait", 2.0], ["plot_tag", "host_end"],
			["coop_signal", "host_done"], ["coop_wait_file", "client_ended"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["plot_tag", "client_start"],
			["eval", "get_node('/root/EventBus').RequestPlot.emit('west')"], ["wait", 2.5], ["plot_tag", "client_bought"],
			["coop_signal", "client_bought"], ["coop_wait_file", "host_seen"],
			["eval", "get_node('/root/EventBus').RequestBuild.emit('cabin_1', Vector2i(1, 6), 0)"], ["wait", 2.5],
			["coop_signal", "client_built"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["plot_tag", "client_end"],
			["coop_signal", "client_ended"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	if str(step[0]) == "plot_tag":
		var st = CoreRoot.get_state()
		print("PLOT_TAG %s" % JSON.stringify([str(step[1]), CoreRoot.actions.plot_rect(), int(st.plot.get("bought", 0)) if st.plot is Dictionary else 0,
			int(CoreRoot.get_money()), str(st.grid.get_cell_data(Vector2i(1, 6)).get("type", ""))]))
		return
	super._run_step(step)
