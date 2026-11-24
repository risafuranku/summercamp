extends "res://tools/coop_check.gd"

## The reception's counter for two (scripts/reception/desk_room.gd, coop_camp.sync "drawer"):
## both wardens in the office. The host sits down at the check-in desk and pulls the drawer
## out, then pushes it in; the other, standing behind the counter, sees it go both ways.
## The other goes out, the host pulls it out again: it is out (not coming out) as they come
## back in. Then the other sits down and pulls it out: the host sees that. Last, two changes with
## the same number (both at once) go the host's way. Tagged ["DESK <role> <tag>", open,
## how far out 0..1, number] for tools/desk_coop.py, a picture at each.
##   godot --path godot res://tools/desk_coop.tscn -- --role=host --out=DIR

const BI := "_interior_manager._building_interior"
const DR := BI + "._desk_room"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", BI + "._exit_crt_view()"], ["wait", 1.0],
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 1.0],
			["eval", BI + ".open_checkin_desk()"], ["wait", 2.4],
			["eval", DR + "._set_drawer(true)"], ["wait", 1.6], ["desk_tag", "host_out"], ["shot", "dc1_host_out"],
			["coop_signal", "host_drawer_out"], ["coop_wait_file", "client_saw_out"],
			["eval", DR + "._set_drawer(false)"], ["wait", 1.6], ["desk_tag", "host_in"],
			["coop_signal", "host_drawer_in"], ["coop_wait_file", "client_saw_in"],
			# Out again while the other is outside: it is out when they come in, not coming out.
			["coop_wait_file", "client_outside"],
			["eval", DR + "._set_drawer(true)"], ["wait", 1.6],
			["coop_signal", "host_drawer_out2"], ["coop_wait_file", "client_back_in"],
			["eval", DR + "._set_drawer(false)"], ["wait", 1.2],
			["eval", DR + ".desk.close_desk()"], ["wait", 2.4],
			["coop_signal", "host_left_desk"], ["coop_wait_file", "client_drawer_out"], ["wait", 1.6],
			["desk_tag", "host_sees_out"], ["shot", "dc5_host_sees_out"],
			["coop_signal", "host_saw_client"], ["coop_wait_file", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._on_crt_interact()"], ["wait", 4.0],
			["eval", BI + "._look.set('pitch_deg', -22.0)"], ["wait", 1.5], ["desk_tag", "client_before"], ["shot", "dc0_client_before"],
			["coop_signal", "client_in"],
			["coop_wait_file", "host_drawer_out"], ["wait", 1.6], ["desk_tag", "client_sees_out"], ["shot", "dc2_client_sees_out"],
			["coop_signal", "client_saw_out"],
			["coop_wait_file", "host_drawer_in"], ["wait", 1.6], ["desk_tag", "client_sees_in"], ["shot", "dc3_client_sees_in"],
			["coop_signal", "client_saw_in"],
			["eval", BI + ".close_interior()"], ["wait", 3.0], ["coop_signal", "client_outside"],
			["coop_wait_file", "host_drawer_out2"], ["wait", 1.0], ["desk_tag", "client_unseen_out"],
			["eval", "_interior_manager._on_crt_interact()"], ["wait", 0.2], ["desk_tag", "client_back_in"],
			["wait", 2.5], ["eval", BI + "._look.set('pitch_deg', -22.0)"], ["wait", 1.0], ["shot", "dc4_client_back_in"],
			["coop_signal", "client_back_in"],
			["coop_wait_file", "host_left_desk"], ["wait", 1.0],
			["eval", BI + ".open_checkin_desk()"], ["wait", 2.4],
			["eval", DR + "._set_drawer(true)"], ["wait", 1.6], ["desk_tag", "client_out"],
			["coop_signal", "client_drawer_out"], ["coop_wait_file", "host_saw_client"],
			["desk_tie"],
			["coop_signal", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _run_step(step: Array) -> void:
	match str(step[0]):
		"desk_tag":
			var d = _main._interior_manager._building_interior._desk_room
			print("DESK_TAG [\"DESK %s %s\", %s, %.2f, %d]" % [_role, str(step[1]), str(d._drawer_open).to_lower(), float(d._drawer_t), int(d._drawer_seq)])
		"desk_tie":
			# Two changes with one number: the host's wins; an older one changes nothing.
			var d = _main._interior_manager._building_interior._desk_room
			var s: int = d._drawer_seq
			var was: bool = d._drawer_open
			d.coop_take_drawer([not was, s], false)
			var kept: bool = d._drawer_open == was
			d.coop_take_drawer([not was, s], true)
			var host_won: bool = d._drawer_open != was
			d.coop_take_drawer([was, s - 1], true)
			var old_ignored: bool = d._drawer_open != was
			d.coop_take_drawer([was, s + 1], false)
			var newer_taken: bool = d._drawer_open == was
			print("DESK_TIE [%s, %s, %s, %s]" % [str(kept).to_lower(), str(host_won).to_lower(), str(old_ignored).to_lower(), str(newer_taken).to_lower()])
		_:
			super._run_step(step)
