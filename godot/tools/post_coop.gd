extends "res://tools/coop_check.gd"

## The second monitor for two (scripts/reception/post_delivery.gd): the joining warden
## orders it on the PC, the host's clock brings the van and the postman, the joining
## warden signs for the parcel; each side prints what it sees, tagged
## ["POST <role> <tag>", stage, second monitor, money] for tools/post_coop.py.
##   godot --path godot res://tools/post_coop.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"
func _see(tag: String) -> Array:
	return ["post_see", tag]


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0],
			["eval", "debug_jump_to(2, 9.0)"], ["wait", 1.0],
			["coop_signal", "host_up"], ["coop_wait_file", "client_ordered"], ["wait", 2.0],
			_see("ordered"),
			["post_due"], ["wait", 2.0], _see("arriving"),
			["post_walked"], ["wait", 2.0], _see("at_desk"),
			["coop_signal", "host_at_desk"], ["coop_wait_file", "client_signed"], ["wait", 3.0],
			_see("delivered"), ["shot", "ph_after"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0],
			_see("before"),
			["eval", BI + "._post.order()"], ["wait", 2.5], _see("ordered"),
			["coop_signal", "client_ordered"],
			["coop_wait_file", "host_at_desk"], ["wait", 2.0], _see("at_desk"),
			["eval", BI + "._post.click_postman()"], ["wait", 1.0],
			["eval", BI + "._post._closeup._clicked('parcel')"], ["wait", 2.0],
			_see("delivered"), ["shot", "pc_after"],
			["coop_signal", "client_signed"],
			["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	if not str(step[0]).begins_with("post_"):
		super._run_step(step)
		return
	var bi = _main._interior_manager._building_interior
	match str(step[0]):
		"post_see":
			print("POST_TAG [\"POST %s %s\", \"%s\", %s, %d]" % [_role, str(step[1]), bi._post.stage(), str(bi._dual).to_lower(), CoreRoot.get_money()])
		"post_due":
			var d: Dictionary = bi._post.state()
			d["due"] = _main._now_abs_minutes_float()
			bi._post._set_state(d)
		"post_walked":
			var d: Dictionary = bi._post.state()
			d["t0"] = _main._now_abs_minutes_float() - 500.0
			bi._post._set_state(d)
