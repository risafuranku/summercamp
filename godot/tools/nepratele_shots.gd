extends "res://tools/shot_driver.gd"

## Everything that comes at night held still and looked at, the way you meet it: at 5, 12 and
## 25 m, in the torch, without it, and under a lamp. The brain is stopped and its body put in
## front of you. Debug tooling only. Lines "NEPRATELE ...".
##   godot --path godot --audio-driver Dummy --resolution 1366x768 res://tools/nepratele_shots.tscn -- --out=DIR [--who=girl,stalker]

const C := "get_tree().root.get_node('NepriteleShots')"
const WHO := ["silent_man", "tourist", "girl", "stalker", "whistler", "child", "basket"]


func pl() -> Node3D:
	return _main.get("_player")


func hold(dist: float) -> void:
	var list: Array = _main.get("_enemy_brains")
	if list.is_empty():
		print("NEPRATELE nothing came")
		return
	var b = list[0]
	b.set("_night_active", false)
	var body = b.get("_body")
	if body == null:
		print("NEPRATELE %s has no body yet" % str(b.get_enemy_id()))
		return
	var p := pl()
	var fwd: Vector3 = -p.global_transform.basis.z
	fwd.y = 0.0
	var at: Vector3 = b.call("_ground", p.global_position + fwd.normalized() * dist)
	body.global_position = at
	body.visible = true
	print("NEPRATELE %s body at %s ground %.2f, height %.2f, player y %.2f, shaded %s" % [str(b.get_enemy_id()), str(at), at.y, float(body.pixel_size) * float(body.texture.get_height()) if body.texture != null else 0.0, p.global_position.y, str(body.shaded)])


func torch(on: bool) -> void:
	var p := pl()
	if p.has_method("set_flashlight_enabled"):
		p.call("set_flashlight_enabled", on)
	elif p.get("_flashlight") != null:
		(p.get("_flashlight") as SpotLight3D).visible = on


func _ready() -> void:
	super._ready()
	var who: Array = WHO
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--who="):
			who = a.substr(6).split(",")
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_camp", ["Tour", 4242, false, true, {"threats": true, "weather": false, "events": false, "wear": false, "money": 20000}]],
		["wait_gameplay"], ["wait", 3.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["player", 12, 12, 0.0],
		["eval", "debug_jump_to(2, 22.5)"], ["wait", 3.0],
		["eval", "_stop_active_enemy_brain()"], ["wait", 0.5],
	]
	for id in who:
		s.append_array([["eval", "debug_spawn_enemy('%s', 3)" % id], ["wait", 1.2]])
		for d in [5.0, 12.0, 25.0]:
			s.append_array([["eval", C + ".hold(%f)" % d], ["eval", C + ".torch(true)"], ["wait", 0.5], ["shot", "%s_torch_%d" % [id, int(d)]]])
		s.append_array([["eval", C + ".hold(5.0)"], ["eval", C + ".torch(false)"], ["wait", 0.5], ["shot", "%s_dark_5" % id]])
		s.append_array([["eval", "_stop_active_enemy_brain()"], ["wait", 0.5]])
	s.append(["eval", "get_tree().quit()"])
	_steps = s
