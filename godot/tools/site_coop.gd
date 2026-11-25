extends "res://tools/coop_check.gd"

## Building takes time, for two (core/systems/construction_rules.gd, 25. 11.): the host orders
## a cabin in Builder 98, the other orders the pub in theirs (it goes to the host); both sites
## stand on both machines (the grid's "site", GameState.sites, the scaffold), the work goes on
## the host's clock and when it is done the cabin and the pub stand on both (the host's fact
## "site_done"). Tagged "SITE_TAG [tag, ...]" for tools/site_coop.py.
##   godot --path godot res://tools/site_coop.tscn -- --role=host --out=DIR

const RULES := preload("res://core/systems/construction_rules.gd")


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 40000], ["clear", 9, 8, 9, 9], ["wait", 0.5],
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 1.0],
			["eval", "get_node('/root/EventBus').RequestOrder.emit('cabin_1', Vector2i(10, 10), 0)"], ["wait", 1.0],
			["site_tag", "host_cabin"], ["coop_signal", "host_ordered"],
			["coop_wait_file", "client_ordered"], ["wait", 2.0], ["site_tag", "host_pub"],
			["player", 13, 16, 0.0], ["wait", 1.0], ["shot", "sc1_host_sites"],
			["coop_signal", "host_saw_pub"], ["coop_wait_file", "client_saw_both"],
			# Four hours of the workers' day on the host's clock: both done.
			["hours", 4.0], ["wait", 2.0], ["site_tag", "host_done"], ["shot", "sc3_host_done"],
			["coop_signal", "host_done"], ["coop_wait_file", "client_saw_done"],
			["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_signal", "client_in"], ["coop_wait_file", "host_ordered"], ["wait", 2.0],
			["site_tag", "client_cabin"],
			# Ordered in this machine's Builder: it goes to the host.
			["eval", "get_node('/root/EventBus').RequestOrder.emit('pub', Vector2i(14, 10), 0)"], ["wait", 2.0],
			["coop_signal", "client_ordered"], ["coop_wait_file", "host_saw_pub"], ["wait", 0.5],
			["site_tag", "client_pub"], ["player", 13, 16, 0.0], ["wait", 1.0], ["shot", "sc2_client_sites"],
			["coop_signal", "client_saw_both"], ["coop_wait_file", "host_done"], ["wait", 2.5],
			["site_tag", "client_done"], ["player", 13, 16, 0.0], ["wait", 1.0], ["shot", "sc4_client_done"],
			["coop_signal", "client_saw_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	if str(step[0]) == "site_tag":
		print("SITE_TAG %s" % JSON.stringify([str(step[1])] + _tag()))
		return
	super._run_step(step)


## The cabin's and the pub's cells (their types), the sites' keys, how many scaffolds stand.
func _tag() -> Array:
	var st = CoreRoot.get_state()
	var keys: Array = st.sites.keys()
	keys.sort()
	return [str(st.grid.get_cell_data(Vector2i(10, 10)).get("type", "")), str(st.grid.get_cell_data(Vector2i(14, 10)).get("type", "")),
		keys, get_tree().get_nodes_in_group("sites").size()]
