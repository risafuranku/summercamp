extends "res://tools/coop_check.gd"

## Seen from the camp, for two (interior_manager._coop_rooms_from_camp, coop_door): the host
## walks up to a cabin's door and in, goes from window to window in it; the joining warden
## outside sees the door open before the host has gone through it, and the host's figure in
## the room going where the host goes. Each round writes ROOMS_TAG lines for
## tools/rooms_coop.py and a picture.
##   python godot/tools/rooms_coop.py [OUT_DIR]

const ROOMS_PORT := 24998
const BI := "_interior_manager._building_interior"
const CAB := "_interior_manager._cabin_interior"
var _door_ms := -1
var _in_ms := -1
var _was_in := false


func _process(delta: float) -> void:
	super._process(delta)
	if _main == null or _role != "client" or not Coop.has_partner():
		return
	var s: Dictionary = Coop.state_of(Coop.others()[0])
	var inside := bool(s.get("in", false))
	if inside and not _was_in and _in_ms < 0:
		_in_ms = Time.get_ticks_msec()
	_was_in = inside
	if _door_ms < 0 and not (_main.get("_coop_door_told") as Dictionary).is_empty():
		_door_ms = Time.get_ticks_msec()


func _ready() -> void:
	super._ready()
	var open := [["eval", BI + "._exit_crt_view()"], ["wait", 1.0], ["eval", BI + ".close_interior()"], ["wait", 1.0]]
	if _role == "host":
		_steps = [["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0]]
		_steps.append_array(open)
		_steps.append_array([["money", 9000], ["clear", 16, 3, 4, 4], ["build", "cabin_1", 17, 4, 0], ["wait", 1.0], ["prep_all"], ["wait", 0.5],
			["coop_signal", "host_up"], ["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			["rooms_at_door"], ["wait", 0.6], ["eval", "_try_interact()"], ["wait", 3.0],
			["eval", "_is_any_interior_open()"], ["coop_signal", "host_in"], ["coop_wait_file", "client_saw_in"],
			["rooms_walk", 0], ["wait", 3.5], ["rooms_host", "s0"], ["coop_signal", "host_s0"], ["coop_wait_file", "client_s0"],
			["rooms_walk", -1], ["wait", 3.5], ["rooms_host", "s1"], ["coop_signal", "host_s1"], ["coop_wait_file", "client_s1"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"]])
	else:
		_steps = [["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]], ["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0]]
		_steps.append_array(open)
		_steps.append_array([["rooms_outside"], ["wait", 2.0], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_in"], ["wait", 1.0], ["rooms_door"], ["coop_signal", "client_saw_in"],
			["coop_wait_file", "host_s0"], ["wait", 1.0], ["rooms_see", "s0"], ["shot", "c_s0"], ["coop_signal", "client_s0"],
			["coop_wait_file", "host_s1"], ["wait", 1.0], ["rooms_see", "s1"], ["shot", "c_s1"], ["coop_signal", "client_s1"],
			["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"]])


func _cabin() -> Node3D:
	return load("res://scripts/attractions/door_anim.gd").structure_at(Vector2i(17, 4))


func _run_step(step: Array) -> void:
	match str(step[0]):
		"coop_port":
			Coop.port = ROOMS_PORT
		"coop_join":
			_main.call("_on_menu_coop_join", "%s:%d" % [str(step[1]), ROOMS_PORT])
		"rooms_at_door":
			# Before its door, looking at it.
			var way: Dictionary = load("res://scripts/attractions/door_anim.gd").entry_points(_cabin(), 0)
			var pl: Node3D = _main._player
			var at: Vector3 = way["outside"]
			pl.global_position = Vector3(at.x, pl.global_position.y, at.z) + (at - (way["inside"] as Vector3)).normalized() * 0.9
			var inn: Vector3 = way["inside"]
			pl.look_at(Vector3(inn.x, pl.global_position.y, inn.z), Vector3.UP)
			print("ROOMS at the door: %s" % _main._interaction_controller.build_hint_text(_main.INTERACT_DISTANCE, false))
		"rooms_walk":
			var c = _main._interior_manager._cabin_interior
			var spots: Array = c._spots_of(c._cabin_level)
			var s: Dictionary = spots[int(step[1]) if int(step[1]) >= 0 else spots.size() + int(step[1]) - 1]
			print("ROOMS host walks to %s, %d spots" % [s["id"], spots.size()])
			c._walk_spot(str(s["id"]))
		"rooms_host":
			var c = _main._interior_manager._cabin_interior
			var at: Vector3 = c._cabin_root.to_local(c._interior_camera.global_position)
			print("ROOMS_TAG [\"host %s\", %.2f, %.2f]" % [str(step[1]), at.x, at.z])
		"rooms_outside":
			# Before one of the cabin's windows, looking in.
			var c = _main._interior_manager._cabin_interior
			var cabin := _cabin()
			var panes: Array = c._panes_of(cabin)
			var p: Node3D = panes[0]
			var pl: Node3D = _main._player
			var at: Vector3 = p.global_position + p.global_basis.z.normalized() * 2.6
			pl.global_position = Vector3(at.x, pl.global_position.y, at.z)
			pl.look_at(Vector3(p.global_position.x, pl.global_position.y, p.global_position.z), Vector3.UP)
			print("ROOMS panes %d" % panes.size())
		"rooms_door":
			print("ROOMS_DOOR door told %d ms, in flag %d ms" % [_door_ms, _in_ms])
		"rooms_see":
			var figs: Dictionary = _main._interior_manager._room_figs
			var c = _main._interior_manager._cabin_interior
			var n := figs.size()
			var at2 := Vector3.INF
			var vis := false
			for id in figs:
				var f = figs[id]["fig"]
				vis = (f as Node3D).is_visible_in_tree()
				at2 = c._cabin_root.to_local((f as Node3D).global_position)
			print("ROOMS_TAG [\"client %s\", %.2f, %.2f, %d, %s, %s]" % [str(step[1]), at2.x, at2.z, n, str(vis).to_lower(), str(c.get("_inview_cabin") != null).to_lower()])
		_:
			super._run_step(step)
