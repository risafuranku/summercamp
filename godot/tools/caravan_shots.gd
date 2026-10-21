extends "res://tools/shot_driver.gd"

## The caravan (scripts/caravan_interior.gd, caravan_life.gd, building_models.caravan):
## its three levels from outside, walking in, looking round, the things to play with,
## the dinette made up, the camp looking in through its windows by day and by night,
## walking out. Debug tooling only.
##   godot --path godot --resolution 1280x720 res://tools/caravan_shots.tscn -- --out=<dir>

const CI := "_interior_manager._caravan_interior"
const VANS := [[8, 12, "caravan_1"], [13, 12, "caravan_2"], [18, 12, "caravan_3"]]


func _ready() -> void:
	super._ready()
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 900000],
		["clear", 5, 9, 18, 8], ["wait", 1.0],
	]
	for v in VANS:
		s.append(["build", "caravan_1", v[0], v[1], 0])
		s.append(["wait", 0.3])
		if str(v[2]) != "caravan_1":
			s.append(["eval", "_interior_manager._handle_replace_upgrade(Vector2i(%d, %d), 'caravan_1', '%s', 0)" % [v[0], v[1], v[2]]])
			s.append(["wait", 0.3])
	s.append(["wait", 1.5])
	# Outside, each level, the door side and the towing end.
	for i in VANS.size():
		var v: Array = VANS[i]
		s.append_array([["van_front", v[0], v[1], 7.5, 0.0], ["wait", 0.6], ["shot", "ext%d_front" % (i + 1)]])
		s.append_array([["van_front", v[0], v[1], 6.0, 55.0], ["wait", 0.5], ["shot", "ext%d_end" % (i + 1)]])
	# Looking in through the windows by day (the real room behind the glass).
	s.append_array([["van_front", 18, 12, 3.2, 10.0], ["wait", 1.2], ["shot", "in_view_day"]])
	# In: the walk up the step, the door shutting behind.
	s.append_array([["van_front", 8, 12, 2.4, 0.0], ["wait", 0.4], ["enter_van", 8, 12]])
	for k in 10:
		s.append_array([["wait", 0.16], ["shot", "walkin_%02d" % k]])
	s.append(["wait", 0.8])
	for look in [["dinette", -0.12, -90.0], ["kitchen", -0.22, 0.0], ["door", -0.1, 180.0], ["back_end", -0.12, 90.0], ["ceiling", 0.7, -20.0]]:
		s.append_array([["van_look", look[1], look[2]], ["wait", 0.35], ["shot", "lv1_" + str(look[0])]])
	# The things, each looked at.
	for th in [["fridge", Vector3(1.0, 1.35, 0.4), Vector3(0.87, 0.5, -0.46)], ["locker", Vector3(0.05, 1.42, 0.25), Vector3(0.05, 1.72, -0.7)],
			["tap", Vector3(-0.2, 1.4, 0.05), Vector3(-0.275, 0.92, -0.75)], ["gas", Vector3(0.45, 1.4, 0.05), Vector3(0.405, 0.92, -0.77)],
			["radio", Vector3(-0.05, 1.35, 0.05), Vector3(0.03, 0.98, -0.9)]]:
		s.append_array([["van_eye", th[1], th[2]], ["wait", 0.3], ["shot", "thing_%s_0" % th[0]], ["eval", CI + "._life._toggle('%s')" % th[0]], ["wait", 0.9], ["shot", "thing_" + str(th[0])]])
	s.append_array([["van_eye", Vector3(0.45, 1.4, 0.05), Vector3(0.405, 0.95, -0.77)], ["wait", 6.0], ["shot", "thing_kettle_boiling"]])
	s.append_array([["van_eye", Vector3(-0.74, 1.35, 0.35), Vector3(-0.74, 1.95, 0.0)], ["eval", CI + "._life._toggle('vent')"], ["wait", 1.4], ["shot", "thing_vent"]])
	s.append_array([["van_eye", Vector3(1.1, 1.25, 0.2), Vector3(1.96, 0.55, -0.7)], ["eval", CI + "._life._things['cat']['root'].set('position', Vector3(1.96, 0.52, -0.7))"],
		["eval", CI + "._life._things['cat']['root'].set('visible', true)"],
		["eval", CI + "._life._cat_show('sleep')"], ["wait", 0.3], ["shot", "cat_asleep"],
		["eval", CI + "._life._poke_cat()"], ["wait", 0.4], ["shot", "cat_awake"]])
	# The dinette made up into the bed.
	s.append_array([["eval", CI + "._life._things['cat']['root'].set('visible', false)"], ["van_look", -0.2, -90.0], ["wait", 0.3], ["shot", "bed_0_unmade"], ["eval", CI + "._make_up_bed()"]])
	for k in 8:
		s.append_array([["wait", 0.14], ["shot", "bed_%d" % (k + 1)]])
	# Out by the door.
	s.append_array([["wait", 0.6], ["eval", CI + ".walk_out()"]])
	for k in 10:
		s.append_array([["wait", 0.15], ["shot", "walkout_%02d" % k]])
	s.append(["wait", 1.5])
	s.append(["shot", "walkout_camp"])
	# The done-up one: the telly, the heater, the bunks, the papered walls.
	s.append_array([["van_front", 18, 12, 2.4, 0.0], ["wait", 0.4], ["enter_van", 18, 12], ["wait", 2.6]])
	for look in [["dinette", -0.12, -90.0], ["back_end", -0.12, 90.0], ["door", -0.15, 180.0]]:
		s.append_array([["van_look", look[1], look[2]], ["wait", 0.35], ["shot", "lv3_" + str(look[0])]])
	s.append_array([["van_eye", Vector3(0.62, 1.3, -0.45), Vector3(0.62, 1.0, 0.76)], ["eval", CI + "._life._toggle('tv')"], ["wait", 0.5], ["shot", "lv3_tv_snow"], ["wait", 2.0], ["shot", "lv3_tv_card"]])
	s.append_array([["van_eye", Vector3(0.95, 1.2, 0.35), Vector3(1.28, 0.25, -0.76)], ["eval", CI + "._life._toggle('heater')"], ["wait", 3.5], ["shot", "lv3_heater"]])
	s.append_array([["van_eye", Vector3(-1.4, 1.2, 0.1), Vector3(-2.36, 0.6, -0.55)], ["eval", CI + "._life._toggle('teddy')"], ["wait", 0.25], ["shot", "lv3_teddy"]])
	s.append_array([["van_eye", Vector3(1.0, 1.3, 0.3), Vector3(2.48, 1.1, 0.28)], ["wait", 0.3], ["shot", "lv3_flowers"]])
	s.append_array([["eval", CI + ".walk_out()"], ["wait", 2.5]])
	# By night: the camp looking in at the lit one.
	s.append_array([["eval", "debug_jump_to(1, 21.8)"], ["wait", 2.0], ["van_front", 18, 12, 3.4, 10.0], ["wait", 1.2], ["shot", "in_view_night"]])
	_steps = s


func _van(x: int, y: int) -> Node3D:
	var bm = _main.get("building_manager")
	for c in bm.get_node("Structures").get_children():
		if c.get_meta("grid_origin", Vector2i(-99, -99)) == Vector2i(x, y):
			return c
	return null


func _run_step(step: Array) -> void:
	match str(step[0]):
		"van_front":
			# The warden `dist` m off the van's door side (turned `angle` deg round it
			# towards its towing end), looking at it.
			var van := _van(int(step[1]), int(step[2]))
			var pl: Node3D = _main.get("_player")
			if van == null or pl == null:
				print("CARAVAN SHOTS: no van at %s" % [step.slice(1, 3)])
				return
			_main.set("debug_camera", null)
			var out := van.global_basis.z.normalized().rotated(Vector3.UP, deg_to_rad(float(step[4])))
			var at := van.global_position + out * float(step[3])
			pl.global_position = Vector3(at.x, van.global_position.y + 0.2, at.z)
			var to := van.global_position - pl.global_position
			pl.rotation.y = atan2(-to.x, -to.z)
			var head := pl.get_node_or_null("Head") as Node3D
			if head != null:
				head.rotation.x = -0.12
		"enter_van":
			var van2 := _van(int(step[1]), int(step[2]))
			if van2 != null:
				_main.get("_interior_manager").call("_on_caravan_interact", van2)
		"van_eye":
			# The room's eye stood at a point, looking at another.
			var ci3 = _main.get("_interior_manager").get("_caravan_interior")
			var cam3: Camera3D = ci3.get("_interior_camera")
			cam3.position = step[1]
			var d3: Vector3 = (step[2] as Vector3) - cam3.position
			ci3.set("_cam_base_rot", Vector3(atan2(d3.y, Vector2(d3.x, d3.z).length()), atan2(-d3.x, -d3.z), 0.0))
			ci3.get("_look").call("reset")
		"van_aim":
			# The room's eye turned to look at a point of the room.
			var ci2 = _main.get("_interior_manager").get("_caravan_interior")
			var cam: Camera3D = ci2.get("_interior_camera")
			var d: Vector3 = (step[1] as Vector3) - cam.position
			var yaw := atan2(-d.x, -d.z)
			var pitch := atan2(d.y, Vector2(d.x, d.z).length())
			ci2.set("_cam_base_rot", Vector3(pitch, yaw, 0.0))
			ci2.get("_look").call("reset")
		"van_look":
			var ci = _main.get("_interior_manager").get("_caravan_interior")
			ci.set("_cam_base_rot", Vector3(float(step[1]), deg_to_rad(float(step[2])), 0.0))
			ci.get("_look").call("reset")
		_:
			super._run_step(step)
