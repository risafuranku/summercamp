extends "res://tools/shot_driver.gd"

## The glints at the corn stand (the user 4. 11.: "the hovers clip badly while making the
## corn"): the stand built, opened, the pointer (station3d.debug_mouse) walked over the
## counter's and the husking's things; a picture at each point.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/kukurice_hover.tscn -- --out=DIR

const C := "get_tree().root.get_node('KukuriceHover')"
const STATION3D = preload("res://scripts/business/station3d.gd")


func open_stand() -> String:
	var bm = _main.get("building_manager")
	for c in bm.get_node("Structures").get_children():
		if str(c.get_meta("building_type", "")) == "corn_stand":
			_main.get("_interior_manager").call("handle_structure_interact", c)
			return "opened"
	return "no stand"


## The pointer on the n-th thing of the open station (its sprites, as the camera sees them).
func on_thing(n: int) -> String:
	var stand = _main.get("_interior_manager").get("_corn_stand")
	var cam: Camera3D = stand.get("_cam")
	var vp: SubViewport = stand.get("_view")
	var things: Array = []
	for st in (stand.get("_stations") as Dictionary).values():
		if not (st as Node).get("_open"):
			continue
		for c in (st as Node).find_children("*", "Sprite3D", true, false):
			if (c as Node3D).is_visible_in_tree() and not cam.is_position_behind((c as Node3D).global_position):
				things.append(c)
	if things.is_empty():
		return "nothing"
	var s: Node3D = things[n % things.size()]
	var p := cam.unproject_position(s.global_position)
	var win := Vector2(DisplayServer.window_get_size())
	var box: Control = stand.get("_box")
	var r := box.get_global_rect() if box != null else Rect2(Vector2.ZERO, win)
	STATION3D.debug_mouse = r.position + p / Vector2(vp.size) * r.size
	print("KUK on %s at %s" % [s.name, STATION3D.debug_mouse])
	return "on %s" % s.name


func pointer(x: float, y: float) -> String:
	var size := Vector2(DisplayServer.window_get_size())
	STATION3D.debug_mouse = Vector2(x, y) * size
	return "pointer %s" % STATION3D.debug_mouse


func _ready() -> void:
	super._ready()
	var steps: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.4],
		["key", "Escape"], ["wait", 2.0],
		["money", 200000], ["clear", 6, 10, 10, 8], ["build", "corn_stand", 8, 12, 0], ["prep_all"], ["wait", 2.0],
		["eval", C + ".open_stand()"], ["wait", 3.0], ["shot", "k0_open"],
	]
	var i := 1
	for t in 8:
		steps.append_array([["eval", C + ".on_thing(%d)" % t], ["wait", 0.6], ["shot", "k%d_counter" % i]])
		i += 1
	steps.append_array([["key", "2"], ["wait", 1.5], ["shot", "k_husk0"]])
	for p2 in [[0.35, 0.7], [0.5, 0.75], [0.62, 0.72]]:
		steps.append_array([["eval", C + ".pointer(%.2f, %.2f)" % [p2[0], p2[1]]], ["wait", 0.5], ["shot", "k%d_husk" % i]])
		i += 1
	_steps = steps
