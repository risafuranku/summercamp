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


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--part=tent"):
		_steps = TENT_STEPS.duplicate(true)
		return
	_steps = STEPS.duplicate(true)
