extends "res://tools/shot_driver.gd"

## The keys as the user wants them (4. 11.): Esc leaves step by step (the PC, the room) and
## only outdoors is the pause menu; P and F10 pause anywhere; the pause menu has no way out
## of the room; W A S D look in a room. Each step prints what it found ("OVLADANI ...").
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/ovladani_check.tscn

const C := "get_tree().root.get_node('OvladaniCheck')"


func state(label: String) -> String:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var pm = _main.get("_pause_menu")
	var look = bi.get("_look")
	var line := "OVLADANI %s: crt=%s room_open=%s pause=%s yaw=%.1f pitch=%.1f" % [label, bi.get("_crt_active"), _main.call("_is_any_interior_open"), pm != null and pm.is_open(), float(look.get("yaw_deg")), float(look.get("pitch_deg"))]
	print(line)
	return line


const STEPS := [
	["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 7.0],
	["eval", C + ".state('start')"],
	["key", "Escape"], ["wait", 1.6], ["eval", C + ".state('esc_from_pc')"],
	["key", "P"], ["wait", 0.3], ["eval", C + ".state('p_in_room')"],
	["key", "P"], ["wait", 0.3], ["eval", C + ".state('p_again')"],
	["key", "F10"], ["wait", 0.3], ["eval", C + ".state('f10_in_room')"],
	["key", "Escape"], ["wait", 0.3], ["eval", C + ".state('esc_closes_menu')"],
	["keyhold", "W", true], ["wait", 0.5], ["keyhold", "W", false], ["eval", C + ".state('w_up')"],
	["keyhold", "D", true], ["wait", 0.5], ["keyhold", "D", false], ["eval", C + ".state('d_right')"],
	["keyhold", "S", true], ["wait", 0.5], ["keyhold", "S", false], ["wait", 0.3], ["eval", C + ".state('s_down_still_in')"],
	["key", "Escape"], ["wait", 3.0], ["eval", C + ".state('esc_from_room')"],
	["key", "Escape"], ["wait", 0.4], ["eval", C + ".state('esc_outdoors')"],
	["shot", "o0_pause_outdoors"],
]


func into_tent() -> String:
	var im = _main.get("_interior_manager")
	var bm = _main.get("building_manager")
	for child in bm.get_node("Structures").get_children():
		if str(child.get_meta("building_type", "")).contains("tent"):
			im._on_tent_interact(child)
			return "tent"
	return "no tent"


func tent(label: String) -> String:
	var t = _main.get("_interior_manager").get("_tent_interior")
	var look = t.get("_look")
	var line := "OVLADANI %s: yaw=%.1f facing_door=%s door_open=%s open=%s" % [label, float(look.get("yaw_deg")), t.get("_facing_door"), t.get("_door_open"), t.get("_is_open")]
	print(line)
	return line


## The pointer over the door's middle, whatever the head's turn, and a click there.
func click_tent_door() -> String:
	var t = _main.get("_interior_manager").get("_tent_interior")
	var cam: Camera3D = t.get("_interior_camera")
	var root: Node3D = t.get("_tent_root")
	var vp: SubViewport = t.get("_viewport")
	var p := cam.unproject_position(root.to_global(Vector3(0.0, 0.6, 1.16)))
	var norm := p / Vector2(vp.size)
	Input.warp_mouse(Vector2(DisplayServer.window_get_size()) * norm)
	return "at %s hit %s" % [norm, t._door_under(norm)]


const TENT_STEPS := [
	["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 5.0],
	["key", "Escape"], ["wait", 1.6], ["key", "Escape"], ["wait", 3.0], ["money", 40000], ["build", "tent_1", 13, 12, 0], ["wait", 1.0],
	["eval", C + ".into_tent()"], ["wait", 3.0], ["eval", C + ".tent('in')"], ["shot", "t0_in"],
	["keyhold", "D", true], ["wait", 1.6], ["keyhold", "D", false], ["wait", 0.2], ["eval", C + ".tent('d_held')"], ["shot", "t1_d_held"],
	["eval", C + ".click_tent_door()"], ["wait", 0.2], ["lmb", true], ["wait", 0.05], ["lmb", false], ["wait", 0.4], ["eval", C + ".tent('clicked')"], ["shot", "t2_clicked"],
	["key", "E"], ["wait", 0.4], ["eval", C + ".tent('e_closes')"],
	["key", "Escape"], ["wait", 2.0], ["eval", C + ".tent('esc')"],
]


## The card in hand at the counter, the pointer on the guest (above the counter's far edge).
func card_over_guest() -> String:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var dr = bi.get("_desk_room")
	var d = dr.get("desk")
	d.set("_drag", "card")
	d.set("_drag_off", Vector2(40, 30))
	var cam: Camera3D = bi.get("_interior_camera")
	# Up off the work to the guest first, as the stick would.
	dr.get("look").set("pitch_deg", 26.0)
	var vp: SubViewport = bi.get("_viewport")
	var size: Vector2 = Vector2(vp.size) if vp != null else cam.get_viewport().get_visible_rect().size
	dr.set("debug_pointer", size * Vector2(0.55, 0.42))
	return "pointer on guest, viewport %s" % size


func desk_state(label: String) -> String:
	var dr = _main.get("_interior_manager").get("_building_interior").get("_desk_room")
	var air = dr.get("_air")
	var line := "OVLADANI %s: in_air=%s air_visible=%s drag=%s rect=%s pos=%s size=%s" % [label, dr.get("desk").get("in_air"), air != null and air.visible, dr.get("desk").get("_drag"), dr.get("desk").held_rect(), air.position if air != null else "-", (air.mesh as QuadMesh).size if air != null else "-"]
	if _out_dir != "":
		dr.get("desk").picture().get_image().save_png(_out_dir + "/picture_" + label + ".png")
	print(line)
	return line


## The reception's walks: to the bench, then out of the front door from it.
func walk_log(label: String) -> String:
	var bi = _main.get("_interior_manager").get("_building_interior")
	var ex = bi.get("_extras")
	var line := "OVLADANI %s: where=%s walking=%s room_open=%s eye=%s" % [label, ex.get("where"), ex._walking(), _main.call("_is_any_interior_open"), bi.get("_interior_camera").position]
	print(line)
	return line


const DESK_STEPS := [
	["auto_checkin", false],
	["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
	["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.4],
	["money", 9000], ["clear", 8, 5, 6, 5], ["build", "tent_1", 9, 6, 0], ["build", "cabin_1", 11, 6, 0], ["prep_all"],
	["book", "Pepa", "drunk", 1, 2, 0], ["hours", 0.05], ["eval", "debug_arrivals()"], ["hours", 1.6], ["eval", "debug_arrivals()"], ["wait", 20.0],
	["eval", "_interior_manager._building_interior.open_checkin_desk()"], ["wait", 2.2], ["shot", "d0_desk"],
	["eval", C + ".card_over_guest()"], ["wait", 0.4], ["eval", C + ".desk_state('card_over_guest')"], ["shot", "d1_card_in_air"],
	["lmb", false], ["wait", 0.08], ["shot", "d2_handing"], ["wait", 0.5], ["eval", C + ".desk_state('let_go')"], ["shot", "d3_given"],
	["key", "Escape"], ["wait", 0.25], ["shot", "d4_step_down_mid"], ["wait", 1.2], ["eval", C + ".walk_log('at_counter')"], ["shot", "d5_back"],
]

const WALK_STEPS := [
	["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
	["key", "Escape"], ["wait", 1.6],
	["eval", "_interior_manager._building_interior._extras.go_bench()"], ["wait", 0.8], ["eval", C + ".walk_log('w1')"], ["shot", "w1"], ["wait", 0.8], ["eval", C + ".walk_log('w2')"], ["shot", "w2"], ["wait", 0.8], ["eval", C + ".walk_log('w3')"], ["shot", "w3"], ["wait", 1.2], ["eval", C + ".walk_log('bench')"], ["shot", "w4_bench"],
	["eval", "_interior_manager._building_interior._extras.go_store()"], ["wait", 5.6], ["eval", C + ".walk_log('store')"], ["shot", "w5_store"],
	["key", "Escape"], ["wait", 2.4], ["eval", C + ".walk_log('office')"],
	["eval", "_interior_manager._building_interior._extras.go_bench()"], ["wait", 3.6], ["eval", C + ".walk_log('bench2')"],
	["key", "Escape"], ["wait", 0.9], ["eval", C + ".walk_log('leaving')"], ["shot", "w6_leaving"], ["wait", 3.0], ["eval", C + ".walk_log('out')"], ["shot", "w7_out"],
]


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--part=desk"):
		_steps = DESK_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=walk"):
		_steps = WALK_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=tent"):
		_steps = TENT_STEPS.duplicate(true)
		return
	_steps = STEPS.duplicate(true)
