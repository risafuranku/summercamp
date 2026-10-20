extends "res://tools/coop_check.gd"

## The office building for two (interior_manager.coop_partner: one space): the host sits at
## the PC, the other warden goes into the back room and looks back through its doorway;
## then they swap (the host in the back room, the other at the reception counter).
## Each side prints the figures it sees, tagged ["OFFICE <role> <tag>", ...], for
## tools/office_coop.py.
##   godot --path godot res://tools/office_coop.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_up"],
			["coop_wait_file", "client_joined"], ["wait", 2.0],
			["coop_open_office"], ["wait", 1.5], ["eval", BI + ".enter_crt_view()"], ["wait", 2.5],
			["coop_signal", "host_at_pc"], ["coop_wait_file", "client_saw_pc"], ["wait", 0.5],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0],
			["eval", BI + "._extras.go_back_room()"], ["wait", 3.0],
			["coop_signal", "host_in_back"], ["coop_wait_file", "client_at_desk"], ["wait", 2.0],
			["eval", BI + "._extras.look_back.set('yaw_deg', -60.0)"], ["wait", 1.0], ["shot", "oh1_back_sees_office"],
			["office_figs", "figs"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0],
			["coop_place", 12, 14, -1.0], ["coop_signal", "client_joined"],
			["coop_wait_file", "host_at_pc"], ["coop_open_office"], ["wait", 1.5],
			["eval", BI + "._extras.go_back_room()"], ["wait", 3.5],
			["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"],
			["eval", BI + "._extras.look_back.set('yaw_deg', -60.0)"], ["wait", 2.0], ["shot", "oc1_back_sees_pc"],
			["office_figs", "figs"],
			["coop_signal", "client_saw_pc"],
			["coop_wait_file", "host_in_back"], ["eval", BI + "._extras.go_office()"], ["wait", 3.0],
			["coop_signal", "client_at_desk"], ["wait", 2.0], ["shot", "oc2_office_sees_back"],
			["office_figs", "figs2"],
			["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


## The other wardens' figures in the room you are in: [visible, where] each, printed
## tagged for the runner.
func _run_step(step: Array) -> void:
	if str(step[0]) != "office_figs":
		super._run_step(step)
		return
	var out: Array = []
	var im = _main.get("_interior_manager")
	for e in (im.get("_coop_figs") as Dictionary).values():
		var fig = e.get("fig")
		var ok: bool = fig != null and is_instance_valid(fig) and fig.visible
		out.append([ok, fig.global_position if ok else Vector3.ZERO])
	print("SHOT DRIVER eval: figs -> [\"OFFICE %s %s\", %s]" % [_role, str(step[1]), str(out).replace("true", "true").to_lower()])
