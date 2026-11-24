extends "res://tools/shot_driver.gd"

## The corn stand's eyes (playtest 24. 11., P9 P14 P15): into the stand from where you stood,
## a picture every few frames of the way in (it starts at your own eyes); W held and let go
## (the look stays up); E to the husking (the look goes with you); Space tapped (serves, the
## stand stays) and held (you step away). Tagged "STAND_LOOK [tag, open, station, yaw, pitch]".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/stand_look.tscn -- --out=DIR

const IM := "_interior_manager"
const STATION3D = preload("res://scripts/business/station3d.gd")


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", IM + "._building_interior._exit_crt_view()"], ["wait", 1.4],
		["key", "Escape"], ["wait", 2.0],
		["money", 200000], ["clear", 6, 10, 10, 8], ["build", "corn_stand", 8, 12, 0], ["prep_all"], ["wait", 2.0],
		["stand_front"], ["wait", 1.5], ["shot", "s0_before"],
		["stand_open"], ["wait", 0.03], ["shot", "s1_enter_a"], ["wait", 0.3], ["shot", "s1_enter_b"],
		["wait", 0.3], ["shot", "s1_enter_c"], ["wait", 0.3], ["shot", "s1_enter_d"], ["wait", 0.4], ["shot", "s1_enter_e"],
		["wait", 1.0], ["shot", "s1_enter_f"], ["look_tag", "entered"],
		["keyhold", "W", true], ["wait", 0.7], ["keyhold", "W", false], ["look_tag", "w_let_go"],
		["wait", 1.5], ["look_tag", "w_after"], ["shot", "s2_looked_up"],
		["key", "E"], ["wait", 0.15], ["shot", "s3_switching"], ["wait", 0.8], ["look_tag", "husk"], ["shot", "s3_husk"],
		["key", "Space"], ["wait", 0.8], ["look_tag", "space_tap"],
		["keyhold", "Space", true], ["wait", 0.3], ["shot", "s4_space_held"], ["wait", 0.6], ["keyhold", "Space", false],
		["wait", 0.5], ["look_tag", "space_held"],
	]


func _stand():
	return _main.get(IM).get("_corn_stand")


func _structure() -> Node3D:
	var bm = _main.get("building_manager")
	for c in bm.get_node("Structures").get_children():
		if str(c.get_meta("building_type", "")) == "corn_stand":
			return c
	return null


func _run_step(step: Array) -> void:
	match str(step[0]):
		"stand_front":
			# Three metres out in front of it, a little to the side, turned to it.
			var s := _structure()
			var p: Node3D = _main.get("_player")
			if s == null or p == null:
				print("STAND_LOOK no stand")
				return
			_main.set("debug_camera", null)
			var at := s.global_transform * Vector3(0.8, 0.0, 3.2)
			p.global_position = Vector3(at.x, p.global_position.y, at.z)
			var aim := s.global_transform * Vector3(0, 0, 0)
			p.look_at(Vector3(aim.x, p.global_position.y, aim.z), Vector3.UP)
			var head := p.get_node_or_null("Head") as Node3D
			if head != null:
				head.rotation.x = 0.0
		"stand_open":
			# The pointer still in the middle (the hidden desktop's own is anywhere: at an edge
			# it is the look's stick, and the look turned on its own).
			STATION3D.debug_mouse = Vector2(DisplayServer.window_get_size()) * 0.5
			var s := _structure()
			_main.get(IM).call("handle_structure_interact", s)
		"look_tag":
			var stand = _stand()
			var open := ""
			var yaw := 0.0
			var pitch := 0.0
			for id in (stand.get("_stations") as Dictionary).keys():
				var st = stand.get("_stations")[id]
				if bool(st.call("is_open")):
					open = str(id)
					var a: Array = st.call("look_angles")
					yaw = float(a[0])
					pitch = float(a[1])
			print("STAND_LOOK [\"%s\", %s, \"%s\", %.1f, %.1f]" % [str(step[1]), str(bool(stand.get("_open"))).to_lower(), open, yaw, pitch])
		_:
			super._run_step(step)
