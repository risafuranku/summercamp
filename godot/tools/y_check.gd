extends "res://tools/onesun_check.gd"

## The playtest of 5. 11., afternoon (TODO Y1-Y24): each point reproduced and checked in the
## game. --y=<part>. Lines "Y ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/y_check.tscn -- --out=DIR --y=builder

const LANG_S = preload("res://scripts/lang.gd")
const NIGHTMARE = preload("res://scripts/night/nightmare_fx.gd")
const UI := "_interior_manager._building_interior._crt_ui"
const MAP := "debug_builder_map()"
const BI := "_interior_manager._building_interior"
const BOOT: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0]]


func say(text: String) -> void:
	print("Y ", text)


## The faces of a room's meshes lying in one plane with the meshes round it and facing the
## same way, overlapping (Y2): the two fight, whichever wins from where you stand. `room`
## a node in the scene, what is round it anything in `around` not under it.
func fights(tag: String, room: Node3D, around: Node3D) -> void:
	var a := _faces(room, null)
	var b := _faces(around, room)
	var row: Array = []
	for fa in a:
		for fb in b:
			if int(fa[0]) != int(fb[0]) or int(fa[1]) != int(fb[1]) or absf(float(fa[2]) - float(fb[2])) > 0.006:
				continue
			var w := minf(float(fa[4]), float(fb[4])) - maxf(float(fa[3]), float(fb[3]))
			var h := minf(float(fa[6]), float(fb[6])) - maxf(float(fa[5]), float(fb[5]))
			if w <= 0.03 or h <= 0.03 or w * h < 0.02:
				continue
			row.append("%s / %s %.2f m2" % [str(fa[7]), str(fb[7]), w * h])
	say("FIGHTS %s %d (%d faces, %d round): %s" % [tag, row.size(), a.size(), b.size(), "; ".join(row.slice(0, 24))])


func _faces(under: Node3D, leave: Node3D) -> Array:
	var out: Array = []
	for n in under.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or not mi.is_visible_in_tree() or mi.mesh == null or (leave != null and (leave == mi or leave.is_ancestor_of(mi))):
			continue
		if not (mi.mesh is BoxMesh or mi.mesh is QuadMesh or mi.mesh is PlaneMesh):
			continue
		var bs := mi.global_basis.orthonormalized()
		var square := true
		for v: Vector3 in [bs.x, bs.y, bs.z]:
			if maxf(absf(v.x), maxf(absf(v.y), absf(v.z))) < 0.999:
				square = false
		if not square:
			continue
		var b := mi.global_transform * mi.get_aabb()
		for ax in 3:
			var u := (ax + 1) % 3
			var v := (ax + 2) % 3
			out.append([ax, -1, b.position[ax], b.position[u], b.end[u], b.position[v], b.end[v], mi.name])
			out.append([ax, 1, b.end[ax], b.position[u], b.end[u], b.position[v], b.end[v], mi.name])
	return out


## What of the camp's world stands inside this room's box (Y2): the outside poking in.
func intruders(root_path: String, lo: Vector3, hi: Vector3) -> void:
	var bi = _bi()
	var room: Node3D = bi.get(root_path)
	var box := room.global_transform * AABB(lo, hi - lo)
	var row: Array = []
	var seen := 0
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g == null or not g.is_inside_tree() or not g.is_visible_in_tree() or room.is_ancestor_of(g) or g.get_world_3d() != room.get_world_3d():
			continue
		seen += 1
		var mmi := g as MultiMeshInstance3D
		if mmi != null and mmi.multimesh != null:
			var hits := 0
			for i in mmi.multimesh.visible_instance_count if mmi.multimesh.visible_instance_count >= 0 else mmi.multimesh.instance_count:
				var at: Vector3 = mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin
				if box.has_point(at):
					hits += 1
			if hits > 0:
				row.append("%s multimesh x%d %s" % [mmi.name, hits, str(mmi.get_path()).right(60)])
			continue
		var b := g.global_transform * g.get_aabb()
		if b.size.length() < 60.0 and b.intersects(box):
			row.append("%s %s %s" % [g.name, str(b.position.snapped(Vector3.ONE * 0.1)) + str(b.size.snapped(Vector3.ONE * 0.1)), str(g.get_path()).right(60)])
	say("INTRUDERS %d of %d: %s" % [row.size(), seen, "
".join(row)])


## The lights lit round the warden, and the sun and the ambient, at this moment.
func lights_round() -> void:
	var p: Node3D = _main.get("_player")
	var sun: DirectionalLight3D = _main.get("sun")
	var env: Environment = _main.get("world_environment").environment
	var row: Array = []
	for n in get_tree().root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l == null or not l.is_visible_in_tree() or l.light_energy <= 0.001 or l is DirectionalLight3D:
			continue
		if l.global_position.distance_to(p.global_position) < 30.0:
			row.append("%s %.2f %s" % [l.name, l.light_energy, str(l.global_position.snapped(Vector3.ONE))])
	say("LIGHTS h=%.2f sun=%.2f col=%s sh=%s dir=%s amb=%.2f %s near=%s" % [float(_main.get("_time_of_day_hours")), sun.light_energy, str(sun.light_color), str(sun.shadow_enabled), str((-sun.global_basis.z).snapped(Vector3.ONE * 0.01)), env.ambient_light_energy, str(env.ambient_light_color), str(row)])


func _ready() -> void:
	super._ready()
	var y := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--y="):
			y = str(a).substr(4)
	match y:
		"builder":
			_steps = _builder()
		"pc":
			_steps = _pc()
		"torch":
			_steps = _torch()
		"trees":
			_steps = _trees()
		"stand":
			_steps = _stand()
		"marks":
			_steps = _marks()
		"wc":
			_steps = _wc()
		"dusk":
			_steps = _dusk()
		"clip":
			_steps = _clip()
		"rooms":
			_steps = _rooms()
		"tent":
			_steps = _tent()
		"maze":
			_steps = _maze()
		"midge":
			_steps = _midge()
		"letters":
			_steps = _letters()
		"bench":
			_steps = _bench()
		"rooms2":
			_steps = _rooms2()
		"silent":
			_steps = _silent()
		"curtains":
			_steps = _curtains()
		"curtains2":
			_steps = _curtains2()
		"sound":
			_steps = _sound_trail()
		"call":
			_steps = _call()
		"music":
			_steps = _music()
		"girlout":
			_steps = _girl_out()
		"girlring":
			_steps = _girl_ring()


## R turns what you are about to build, with the pointer anywhere (Y14).
func _builder() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "debug_jump_to(1, 11.0)"], ["money", 90000],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", UI + ".open_app('builder') != null"], ["wait", 4.5],
		["eval", "debug_close_msgboxes()"], ["wait", 0.5],
		["eval", MAP + ".set_selected_building('cabin_1')"], ["wait", 0.5], ["eval", "['Y rot before', " + MAP + "._rotation_steps]"],
		["key", "R"], ["wait", 0.4], ["eval", "['Y rot after R', " + MAP + "._rotation_steps]"],
		["key", "R"], ["wait", 0.4], ["eval", "['Y rot after R R', " + MAP + "._rotation_steps]"],
		["crt_screen", "builder_r"], ["eval", "get_tree().quit()"]]
	return s


## The torch by F in rain and storm, by day (Y6): it does not come on by itself, stays on
## after the rain till you switch it off, F sleeps in the dry; every switch heard (Y3).
func _torch() -> Array:
	var look := func(what: String) -> Array:
		return ["eval", "['Y %s', 'on', _player.is_flashlight_active(), 'click', _player.get_node_or_null('TorchClick') != null and _player.get_node('TorchClick').playing]" % what]
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.5],
		["eval", "debug_jump_to(1, 11.0)"], ["eval", "_player.set('torch_carried', true)"], ["wait", 0.5],
		look.call("day dry"), ["key", "F"], ["wait", 0.05], look.call("day dry F"),
		["eval", "weather_system.set_weather(4)"], ["eval", "_set_weather_state(4)"], ["wait", 0.5], look.call("day rain, by itself"),
		["key", "F"], ["wait", 0.05], look.call("day rain F"), ["wait", 0.8], ["key", "F"], ["wait", 0.05], look.call("day rain F F"), ["wait", 0.8],
		["key", "F"], ["wait", 0.05], look.call("day rain F F F"), ["wait", 0.8],
		["eval", "weather_system.set_weather(5)"], ["eval", "_set_weather_state(5)"], ["wait", 0.5], look.call("storm, kept on"),
		["eval", "weather_system.set_weather(0)"], ["eval", "_set_weather_state(0)"], ["wait", 0.5], look.call("rain over, kept on"),
		["key", "F"], ["wait", 0.05], look.call("rain over F off"), ["wait", 0.8], ["key", "F"], ["wait", 0.05], look.call("dry again F sleeps"),
		["eval", "weather_system.set_weather(5)"], ["eval", "_set_weather_state(5)"], ["wait", 0.5], look.call("storm by day, by itself"),
		["key", "F"], ["wait", 0.3], ["shot", "storm_day_torch"],
		["eval", "debug_jump_to(1, 20.5)"], ["wait", 1.0], look.call("evening storm"),
		["eval", "weather_system.set_weather(0)"], ["eval", "_set_weather_state(0)"], ["wait", 0.5], look.call("evening dry"),
		["eval", "debug_jump_to(2, 7.5)"], ["wait", 1.0], look.call("morning dry, out by itself"),
		["eval", "get_tree().quit()"]]
	return s


## Both kinds of tree planted (Y14): on the ground, on the Builder's map, in the catalogue.
func _trees() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 90000], ["clear", 12, 10, 8, 5],
		["build", "tree_spruce", 13, 11, 0], ["build", "tree_birch", 15, 11, 0], ["build", "tree_birch", 17, 11, 0], ["build", "tree_spruce", 19, 11, 0], ["wait", 1.0],
		["eval", "['Y money', CoreRoot.get_money()]"],
		["player", 16, 14, 0.0], ["wait", 0.5], ["shot", "trees_ground_a"], ["player", 16, 14, 180.0], ["wait", 0.5], ["shot", "trees_ground_b"],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", UI + ".open_app('builder') != null"], ["wait", 4.5],
		["eval", "debug_close_msgboxes()"], ["wait", 0.5], ["crt_screen", "trees_map"],
		["eval", UI + ".app_of('builder')._module._open_category('decor')"], ["wait", 0.4], ["crt_screen", "trees_catalogue"],
		["eval", MAP + ".focus_camp(2.6)"], ["wait", 0.5], ["crt_screen", "trees_zoom"], ["eval", MAP + ".set_selected_building('tree_birch')"], ["wait", 0.5], ["crt_screen", "trees_ghost"],
		["eval", "get_tree().quit()"]]
	return s


## Guests in the queue at the corn stand (Y5): looking at one of them, E is the stand's.
func _stand() -> Array:
	var look := "['Y guest', _find_guest_in_view().get('name', ''), 'hint', _interaction_controller.build_hint_text(INTERACT_DISTANCE, false)]"
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 90000], ["clear", 4, 9, 8, 7],
		["build", "corn_stand", 6, 11, 0], ["build", "cabin_1", 9, 10, 0], ["build", "cabin_1", 9, 13, 0], ["wait", 1.0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["eval", "['Y sent', debug_send_guests_to('corn_stand', 240)]"], ["wait", 6.0],
		["eval", "set('debug_camera', null)"],
		["door_front", "corn_stand", 1.0], ["wait", 0.4],
		["eval", look], ["shot", "stand_front"],
		["eval", "['Y guests at', _guest_agents.get_visible_guest_positions().size()]"]]
	for k in 8:
		s += [["eval", "_player.rotate_y(0.35)"], ["wait", 0.15], ["eval", look]]
	s += [["eval", "get_tree().quit()"]]
	return s


## The marks over the rooms that want doing (Y22): how high over each kind of lodging.
func _marks() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 900000], ["clear", 4, 9, 14, 7],
		["build", "tent_1", 5, 10, 0], ["build", "tent_2", 8, 10, 0], ["build", "tent_3", 11, 10, 0], ["build", "cabin_1", 14, 10, 0], ["build", "caravan_1", 5, 13, 0], ["wait", 3.0]]
	for ty in ["tent_1", "tent_2", "tent_3", "cabin_1", "caravan_1"]:
		s += [["eval", "['Y mark', '%s', debug_structure_of_type('%s').get_node('RoomMarker').position, debug_structure_of_type('%s').global_position.y]" % [ty, ty, ty]]]
	# A tent somebody slept in keeps its night's light (window_lights: range 3.2 m, hidden by
	# day), and the mark went by the light's reach.
	s += [["eval", "debug_structure_of_type('tent_1').add_child(ClassDB.instantiate('OmniLight3D'))"], ["wait", 1.6],
		["eval", "['Y mark over a tent with a light', debug_structure_of_type('tent_1').get_node('RoomMarker').position]"],
		["eval", "get_tree().quit()"]]
	return s


## Each toilet its own (Y7, Y21): one bowl dirty, the hint at each door and the plates on the
## right; the goods running out on a plate of their own (Y11).
func _wc() -> Array:
	var st := "get_tree().root.get_node('CoreRoot').get_state()"
	var wc := "debug_structure_of_type('toilet_block')"
	var cell := st + ".grid.cells[" + wc + ".get_meta('grid_origin')]"
	var hint := "['Y hint', _interaction_controller.build_hint_text(INTERACT_DISTANCE, false), 'door', _interior_manager._toilet_door_of(" + wc + ")]"
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 90000], ["clear", 4, 9, 8, 7],
		["build", "toilet_block", 5, 10, 0], ["build", "corn_stand", 9, 10, 0], ["build", "pub", 5, 13, 0], ["wait", 1.5],
		["eval", cell + ".set('maint_r', 1.0)"], ["eval", cell + ".set('maint_l', 0.4)"], ["eval", cell + ".set('maintenance', 0.4)"],
		["eval", st + ".biz['sites'].values()[0]['stock'].set('cobs', 2)"], ["eval", st + ".biz['sites'].values()[1]['stock'].set('beer', 0)"], ["wait", 2.5],
		["eval", "_trouble_rows(_interior_manager.business)"],
		["eval", "['Y widths', _hud_manager._trouble_strip.font.get_string_size('KUKUŘIČNÉ KLASY', 0, -1, 8).x, _hud_manager._trouble_strip.font.get_string_size('OVOCE A ZELENINA', 0, -1, 8).x, _hud_manager._trouble_strip.font.get_string_size('KONZERVY POLÉVKY', 0, -1, 8).x, _hud_manager._trouble_strip.font.get_string_size('WC 2 PRAVÝ', 0, -1, 8).x]"],
		["eval", "set('debug_camera', null)"], ["door_front", "toilet_block", 1.4], ["wait", 0.5],
		["eval", "_player.look_at(" + wc + ".find_child('Door0', true, false).global_position, Vector3(0, 1, 0))"], ["wait", 0.4], ["eval", hint], ["shot", "wc_door0"],
		["eval", "_player.look_at(" + wc + ".find_child('Door1', true, false).global_position, Vector3(0, 1, 0))"], ["wait", 0.4], ["eval", hint], ["shot", "wc_door1"],
		["eval", cell + ".set('maint_r', 0.2)"], ["eval", cell + ".set('maintenance', 0.2)"], ["wait", 1.0], ["eval", hint],
		["eval", cell + ".set('maint_l', 1.0)"], ["eval", cell + ".set('maintenance', 0.2)"], ["wait", 2.5], ["eval", "_trouble_rows(_interior_manager.business)"], ["eval", hint], ["shot", "wc_right_only"],
		["eval", "get_tree().quit()"]]
	return s


## The paths round 18:50 (Y17): the camp from above while the low sun goes down.
func _dusk() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 18.45)"], ["wait", 0.5], ["topdown", 2, 2, 22, 20], ["wait", 0.5]]
	for i in 60:
		s += [["wait", 0.28], ["shot", "top_%02d" % i]]
	s += [["eval", "get_tree().quit()"]]
	return s


## Behind the bed in the back room, the reception's skirting boards (Y2).
func _clip() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["wait", 2.0], ["eval", BI + "._exit_crt_view()"], ["wait", 2.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.0], ["mouse", 0.5, 0.5]]
	var k := 0
	for p in ["Vector3(0.0, 0.1, 2.3)", "Vector3(2.4, 0.1, 2.0)", "Vector3(2.4, 0.1, -1.0)", "Vector3(0.0, 0.1, -2.3)", "Vector3(-2.4, 0.1, -1.0)", "Vector3(-2.4, 0.1, 1.5)"]:
		s += [["eval", C + ".rec_face(%s)" % p], ["wait", 1.2], ["shot", "rec_%d" % k]]
		k += 1
	s += [["eval", C + ".intruders('_room_root', Vector3(-5.6, 0.05, -2.6), Vector3(2.6, 2.6, 2.6))"],
		["eval", C + ".fights('reception', " + BI + "._room_root, debug_structure_of_type('main_building'))"]]
	s += [["eval", BI + "._extras.go_back_room()"], ["wait", 3.0]]
	k = 0
	for m in [[0.1, 0.6], [0.5, 0.75], [0.9, 0.6], [0.5, 0.95]]:
		s += [["mouse", m[0], m[1]], ["wait", 1.0], ["shot", "back_%d" % k]]
		k += 1
	s += [["eval", BI + "._extras.go_back_window(true)"], ["wait", 3.0]]
	for m in [[0.1, 0.6], [0.5, 0.75], [0.9, 0.6], [0.5, 0.95]]:
		s += [["mouse", m[0], m[1]], ["wait", 1.0], ["shot", "back_%d" % k]]
		k += 1
	s += [["eval", "get_tree().quit()"]]
	return s


## Every room in its building: anything of it in one plane with the building's own (Y2).
func _rooms() -> Array:
	var IM := "_interior_manager."
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["money", 900000],
		["clear", 5, 4, 5, 7], ["build", "bowling", 6, 5, 0], ["wait", 0.5],
		["clear", 12, 11, 7, 3], ["build", "tent_1", 13, 12, 0], ["wait", 0.5],
		["clear", 12, 14, 4, 3], ["build", "caravan_1", 13, 15, 0], ["wait", 0.5],
		["clear", 4, 9, 5, 5], ["clear", 9, 9, 3, 5], ["clear", 9, 14, 3, 5], ["build", "pub", 5, 10, 0], ["wait", 0.5], ["clear", 4, 14, 5, 5], ["build", "staffroom", 5, 15, 0],
		["clear", 16, 14, 5, 5], ["build", "restaurant", 17, 15, 0], ["clear", 21, 9, 5, 5], ["build", "vecerka", 22, 10, 0], ["wait", 2.0],
		["eval", "debug_repair_ruined()"], ["eval", "debug_jump_to(1, 13.0)"], ["wait", 2.0]]
	for rr in [["cabin_1", "_cabin_interior", "_cabin_root", "close_cabin"], ["caravan_1", "_caravan_interior", "_root", "close_caravan"], ["bowling", "_bowling_interior", "_root", "close_bowling"], ["tent_1", "_tent_interior", "_tent_root", "close_tent"],
			["pub", "_service_interior", "_room_root", "close_service"], ["restaurant", "_service_interior", "_room_root", "close_service"], ["vecerka", "_service_interior", "_room_root", "close_service"], ["staffroom", "_service_interior", "_room_root", "close_service"]]:
		var ty: String = rr[0]
		s += [["eval", "set('debug_camera', null)"], ["door_front", ty, 2.0], ["wait", 0.5],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('%s'))" % ty], ["wait", 5.0],
			["shot", "room_%s" % ty],
			["eval", C + ".fights('%s', %s%s.%s, debug_structure_of_type('%s'))" % [ty, IM, rr[1], rr[2], ty]],
			["eval", IM + rr[1] + "." + rr[3] + "()"], ["wait", 2.5]]
	s += [["eval", "get_tree().quit()"]]
	return s


## The tent's unzipped doorway from outside (Y13): the rolled flaps along its edges.
func rolls() -> void:
	var st: Node3D = _main.debug_structure_of_type("tent_1")
	for n in st.find_children("*", "MeshInstance3D", true, false):
		var g := n as MeshInstance3D
		if g.is_visible_in_tree():
			var mesh_name: String = g.mesh.get_class() if g.mesh != null else "-"
			say("PART %s %s %s size %s rot %s" % [g.name, mesh_name, str(g.position.snapped(Vector3.ONE * 0.01)), str(g.get_aabb().size.snapped(Vector3.ONE * 0.01)), str(g.rotation.snapped(Vector3.ONE * 0.01))])
	for r in st.find_children("TentDoorRoll*", "MeshInstance3D", true, false):
		var m := r as MeshInstance3D
		var par := m.get_parent() as Node3D
		say("ROLL %s local pos=%s rot.z=%.2f top_dir_local=%s parent_basis_det=%.2f parent_yaw=%.2f size=%s visible=%s" % [m.name, str(m.position.snapped(Vector3.ONE * 0.01)), m.rotation.z, str(m.basis.y.normalized().snapped(Vector3.ONE * 0.01)), par.global_basis.determinant(), par.rotation.y, str((m.mesh as BoxMesh).size), str(m.visible)])


func _tent() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["money", 90000],
		["clear", 12, 11, 7, 3], ["build", "tent_1", 13, 12, 0], ["wait", 1.0], ["eval", "debug_jump_to(1, 13.0)"], ["wait", 1.0],
		["door_front", "tent_1", 2.4], ["wait", 0.5],
		["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('tent_1'))"], ["wait", 4.0],
		["eval", C + ".rolls()"], ["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 2.5], ["eval", "set('debug_camera', null)"], ["door_front", "tent_1", 2.4], ["wait", 0.6], ["shot", "tent_open"],
		["eval", C + ".rolls()"], ["eval", "get_tree().quit()"]]
	return s


## The corn maze's ground and ways (Y10): along a way by day, further off, in the torch.
func _maze() -> Array:
	var cf := "_corn_field()"
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.0],
		["eval", "set('debug_camera', null)"],
		["eval", "_player.set_controls_enabled(false)"],
		["eval", "_player.set('global_position', %s.tile_world(%s.entrance) + Vector3(0, 1.0, 0))" % [cf, cf]], ["wait", 0.5],
		["eval", "_player.look_at(%s.tile_world(%s.exit_tile) + Vector3(0, 1.0, 0), Vector3(0, 1, 0))" % [cf, cf]], ["eval", "_player.set('_pitch', -0.45)"], ["eval", "_player.set('_pitch_target', -0.45)"], ["wait", 0.6], ["shot", "maze_0"],
		["eval", "_player.rotate_y(1.57)"], ["wait", 0.4], ["shot", "maze_1"], ["eval", "_player.rotate_y(1.57)"], ["wait", 0.4], ["shot", "maze_2"], ["eval", "_player.rotate_y(1.57)"], ["wait", 0.4], ["shot", "maze_3"],
		["topdown", 2, 2, 22, 20], ["wait", 0.3], ["eval", "debug_camera.set('global_position', %s.tile_world(%s.entrance) + Vector3(-4, 16, 6))" % [cf, cf]], ["eval", "debug_camera.look_at(%s.tile_world(%s.entrance) + Vector3(-16, 0, 0), Vector3(0, 1, 0))" % [cf, cf]], ["wait", 0.5], ["shot", "maze_above"],
		["eval", "set('debug_camera', null)"], ["eval", "debug_jump_to(1, 22.0)"], ["wait", 1.5], ["shot", "maze_night"],
		["eval", "get_tree().quit()"]]
	return s


## The swarm of midges near you (Y16): from a few metres, from close to, walking off.
func midge_near(d: float) -> void:
	var wv = _main.get("_weather_visuals")
	var air: Node = null
	for n in get_tree().root.find_children("AirLife", "", true, false):
		air = n
	if air == null:
		say("no AirLife")
		return
	var sw: Dictionary = (air.get("_swarms") as Array)[0]
	var c: Vector3 = sw["centre"]
	var p: Node3D = _main.get("_player")
	say("SWARM on=%s centre=%s from you %.1f" % [str(air.get("_midges_on")), str(c), c.distance_to(p.global_position)])
	if c == Vector3.INF:
		return
	var at := Vector3(c.x + d, p.global_position.y, c.z)
	p.global_position = at
	p.look_at(Vector3(c.x, p.global_position.y, c.z), Vector3.UP)


func _midge() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "weather_system.set_weather(0)"], ["eval", "_set_weather_state(0)"],
		["eval", "debug_jump_to(1, 17.0)"], ["eval", "set('debug_camera', null)"], ["eval", "_player.set_controls_enabled(false)"], ["wait", 3.5]]
	for d in [6.0, 3.0, 1.5, 0.7, 0.3]:
		s += [["eval", C + ".midge_near(%s)" % d], ["wait", 0.5], ["shot", "midge_%d" % int(d * 10.0)]]
	s += [["eval", "get_tree().quit()"]]
	return s


## The toilets' M and Z once their doors have been used (Y16): how far off their doors they
## are, you standing elsewhere.
func letters(tag: String) -> void:
	var st: Node3D = _main.debug_structure_of_type("toilet_block")
	var p: Node3D = _main.get("_player")
	var row: Array = []
	for n in st.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if l.name == "Bold" or not (l.text in ["M", "Z"]):
			continue
		if not (l.get_parent() is Label3D):
			var door := st.find_child("Door0" if l.text == "M" else "Door1", true, false) as Node3D
			row.append("%s under %s: %.2f m off the door, %.1f m from you" % [l.text, l.get_parent().name, l.global_position.distance_to(door.global_position), l.global_position.distance_to(p.global_position)])
	say("LETTERS %s %s" % [tag, str(row)])


func _letters() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 12.0)"], ["money", 90000], ["clear", 12, 10, 8, 5],
		["build", "toilet_block", 13, 11, 0], ["wait", 1.5], ["player", 17, 14, 180.0], ["wait", 0.5], ["eval", C + ".letters('before')"],
		["eval", "set('debug_camera', null)"], ["door_front", "toilet_block", 1.5], ["wait", 0.5],
		["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('toilet_block'))"], ["wait", 4.0], ["eval", "_interior_manager._service_interior.close_service()"], ["wait", 2.0], ["eval", C + ".letters('used')"],
		["player", 17, 14, 180.0], ["wait", 0.5], ["eval", C + ".letters('walked off')"], ["wait", 2.0], ["eval", C + ".letters('2 s')"], ["wait", 3.0], ["eval", C + ".letters('5 s')"], ["wait", 5.0], ["eval", C + ".letters('10 s')"], ["shot", "letters"],
		["eval", "get_tree().quit()"]]
	return s


## The reception's bench (Y18): the light switch from there, Space back behind the counter.
func bench_look(yaw: float, pitch: float) -> void:
	var ex = _bi().get("_extras")
	var look = ex.get("look_bench")
	look.set("yaw_deg", yaw)
	look.set("pitch_deg", pitch)


func bench_state(tag: String) -> void:
	var bi = _bi()
	var ex = bi.get("_extras")
	var vp: Viewport = bi.get("_viewport")
	var m := vp.get_mouse_position()
	var hit: Dictionary = bi.call("_raycast_room", m)
	var c = hit.get("collider", null)
	say("BENCH %s where=%s hover=%s hit=%s lights=%s cam=%s" % [tag, str(ex.get("where")), str(ex.get("_hover")), str((c as Node).name if c != null else "-"), str(bi.get("_office_lights_on")), str((bi.get("_interior_camera") as Camera3D).position.snapped(Vector3.ONE * 0.01))])


func _bench() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["wait", 2.0], ["eval", BI + "._exit_crt_view()"], ["wait", 2.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.0], ["mouse", 0.5, 0.5],
		["eval", C + ".bench_state('at the desk')"], ["eval", BI + "._extras.go_bench()"], ["wait", 3.0], ["eval", C + ".bench_state('at the bench')"]]
	for yaw in [40.0, 50.0, 60.0, 70.0]:
		s += [["eval", C + ".bench_look(%s, -14.0)" % yaw], ["wait", 0.6], ["eval", C + ".bench_state('yaw %s')" % yaw], ["shot", "bench_%d" % int(yaw + 100.0)]]
	s += [["eval", C + ".bench_look(37.3, -8.4)"], ["wait", 0.8], ["eval", C + ".bench_state('on the switch')"], ["shot", "bench_switch"], ["lmb", true], ["wait", 0.08], ["lmb", false], ["wait", 0.6], ["eval", C + ".bench_state('clicked')"], ["shot", "bench_clicked"],
		["lmb", true], ["wait", 0.08], ["lmb", false], ["wait", 0.6], ["eval", C + ".bench_state('clicked again')"]]
	s += [["key", "SPACE"], ["wait", 3.0], ["eval", C + ".bench_state('after Space')"], ["eval", "get_tree().quit()"]]
	return s


## A guest with more rooms than one at the desk (Y9): all of them said, in both languages.
func desk_lines() -> void:
	var keys: Array = GuestManager.get_accommodation_states().keys()
	var rooms: Array = []
	for k in keys:
		if str(GuestManager.get_room_state(str(k)).get("building_type", "")).begins_with("tent"):
			rooms.append({"key": str(k), "label": GuestManager.room_label(str(k)), "ready": true})
	var q: Array = [{"id": 0, "name": "Novak family", "party_size": 5, "rooms": rooms}]
	var desk = _bi().get("_desk_room").get("desk")
	desk.call("_set_guest", q[0])
	say("DESK rooms %s" % str(q[0].get("rooms", [])))
	for i in 2:
		q[0]["id"] = i
		desk.set("_guest", q[0])
		say("DESK en: %s | %s" % [desk.call("_greeting"), LANG_S.f("That is not ours. We booked %s.", desk.call("_rooms_said"))])
	var was: String = LANG_S.current
	LANG_S.current = "cs"
	TranslationServer.set_locale("cs")
	for i in 2:
		q[0]["id"] = i
		desk.set("_guest", q[0])
		say("DESK cs: %s | %s" % [desk.call("_greeting"), LANG_S.f("That is not ours. We booked %s.", desk.call("_rooms_said"))])
	LANG_S.current = was
	TranslationServer.set_locale("en")


func _rooms2() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["money", 90000], ["clear", 12, 10, 8, 5],
		["build", "tent_1", 13, 11, 0], ["build", "tent_1", 15, 11, 0], ["build", "tent_1", 17, 11, 0], ["wait", 1.0], ["prep_all"],
		["book", "Novak family", "family", 5, 2, 0], ["hours", 0.5], ["wait", 2.0], ["eval", C + ".desk_lines()"], ["eval", "get_tree().quit()"]]
	return s


## The Silent Man's night (Y19, Y23): the torch shorting out frame by frame, the fever in
## the ears as you run.
func torch_energy(tag: String) -> void:
	var p: Node = _main.get("_player")
	var f = p.get("_flashlight")
	say("TORCH %s energy %.2f fill %.2f dark %s" % [tag, float(f.light_energy), float(p.get("_flashlight_fill").light_energy), str(p.call("torch_dark"))])


func fever_state(tag: String) -> void:
	var fx: Node = NIGHTMARE.get_for(_main)
	var fv: Node = fx.get("_fever")
	var playing := 0
	for c in fv.get_children():
		if c is AudioStreamPlayer and c.name != "FeverRing" and (c as AudioStreamPlayer).playing:
			playing += 1
	say("FEVER %s presence %.2f level %.2f ring %s %.1f dB splinters %d" % [tag, float(fx.get("_presence")), float(fv.call("amount")), str((fv.get("_ring") as AudioStreamPlayer).playing), float((fv.get("_ring") as AudioStreamPlayer).volume_db), playing])


var _fever_presence := 0.0


func fever_try(presence: float, running: float) -> void:
	_fever_presence = presence
	for a in ["move_sprint", "move_forward"]:
		if running > 0.0:
			Input.action_press(a)
		else:
			Input.action_release(a)


func _process(delta: float) -> void:
	super._process(delta)
	if _fever_presence > 0.0:
		NIGHTMARE.get_for(_main).set_presence("y_check", _fever_presence)


func _silent() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 22.0)"], ["eval", "_player.set('torch_carried', true)"], ["wait", 1.2],
		["eval", C + ".torch_energy('before')"], ["eval", "_player.torch_blackout(3.0, 1.1)"]]
	for i in 12:
		s += [["wait", 0.06], ["eval", C + ".torch_energy('t%d')" % i]]
	s += [["wait", 1.0], ["eval", C + ".torch_energy('dead')"], ["shot", "torch_dead"], ["wait", 2.4], ["eval", C + ".torch_energy('catching')"], ["wait", 1.2], ["eval", C + ".torch_energy('back')"]]
	s += [["eval", C + ".fever_state('still')"], ["eval", C + ".fever_try(0.9, 0.0)"], ["wait", 2.0], ["eval", C + ".fever_state('stood, it near')"],
		["eval", C + ".fever_try(0.95, 1.0)"], ["wait", 2.0], ["eval", C + ".fever_state('running')"], ["wait", 2.0], ["eval", C + ".fever_state('running on')"],
		["eval", C + ".fever_try(0.0, 0.0)"], ["wait", 4.0], ["eval", C + ".fever_state('over')"], ["eval", "get_tree().quit()"]]
	return s


## Guests and their curtains (Y20): you come near a lit cabin and go away, again and again; a
## tent's light.
func wl_state(tag: String) -> void:
	var wl := get_tree().root.find_child("WindowLights", true, false)
	var lod: Dictionary = wl.get("_lodgings")
	var row: Array = []
	for k in lod:
		var r: Dictionary = lod[k]
		if str(k) == "10:2":
			continue
		var shuts: Array = []
		for w in r["windows"]:
			shuts.append(snappedf(float((w as Node).get_meta("wl_shut", 0.0)), 0.1))
		row.append("%s %s on=%s near=%s spied=%s stay=%s hiding=%s shut=%s" % [str(r["kind"]), str(k), str(r.get("on")), str(r.get("near")), str(r.get("spied")), str(r.get("stay")), str(r.get("hiding")), str(shuts)])
	say("WL %s %s" % [tag, " | ".join(row)])


func lit_all(on: bool) -> void:
	var wl := get_tree().root.find_child("WindowLights", true, false)
	for k in wl.get("_lodgings"):
		wl.call("set_forced", str(k), "on" if on else "")


func _curtains() -> Array:
	var st: Node3D = null
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["money", 90000], ["clear", 12, 10, 8, 5], ["build", "cabin_1", 13, 11, 0], ["build", "tent_1", 17, 11, 0], ["wait", 2.0],
		["eval", "debug_repair_ruined()"], ["eval", "debug_jump_to(1, 21.0)"], ["wait", 3.5], ["eval", C + ".lit_all(true)"], ["wait", 1.0], ["eval", "set('debug_camera', null)"], ["eval", "_player.set_controls_enabled(false)"]]
	for i in 5:
		s += [["player", 13, 19, 0.0], ["wait", 1.0], ["eval", C + ".wl_state('far %d')" % i], ["player", 14, 13, 180.0], ["wait", 0.5], ["shot", "curt_%d_near0" % i], ["wait", 3.0], ["eval", C + ".wl_state('near %d')" % i], ["shot", "curt_%d_near" % i], ["player", 13, 19, 0.0], ["wait", 11.0], ["eval", C + ".wl_state('gone %d')" % i]]
	s += [["door_front", "tent_1", 1.8], ["wait", 2.0], ["eval", C + ".wl_state('by the tent')"], ["shot", "curt_tent"], ["eval", "get_tree().quit()"]]
	return s


func wl_walker(key: String) -> void:
	var wl := get_tree().root.find_child("WindowLights", true, false)
	var r: Dictionary = (wl.get("_lodgings") as Dictionary)[key]
	r["walk_next"] = 0.0


func wl_pane(key: String, i: int) -> void:
	var wl := get_tree().root.find_child("WindowLights", true, false)
	var r: Dictionary = (wl.get("_lodgings") as Dictionary)[key]
	var cube: ShaderMaterial = r.get("cube", null)
	var w0 := (r["windows"] as Array)[0] as MeshInstance3D
	var row := []
	for w in r["windows"]:
		row.append("%.1f" % float((w as Node).get_meta("wl_shut", 0.0)) + (" live" if (w as Node).has_meta("inview_live") else ""))
	say("PANE %d on=%s tv=%s candle=%s energy=%s livepar=%s bright=%s mat=%s shut=%s" % [i, str(r.get("on")), str(r.get("tv")), str(r.get("candle")), str(cube.get_shader_parameter("energy")) if cube != null else "-", str(cube.get_shader_parameter("live")) if cube != null else "-", str(cube.get_shader_parameter("bright")) if cube != null else "-", str(w0.material_override.get_class()), str(row)])


func stand_before(key: String, d: float) -> void:
	var wl := get_tree().root.find_child("WindowLights", true, false)
	var r: Dictionary = (wl.get("_lodgings") as Dictionary)[key]
	var root: Node3D = r["root"]
	var p: Node3D = _main.get("_player")
	var at: Vector3 = root.global_position + root.global_basis.z.normalized() * d
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.look_at(Vector3(root.global_position.x, p.global_position.y, root.global_position.z), Vector3.UP)


func _lodge() -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--lodge="):
			return str(a).substr(8)
	return "cabin_1"


func _curtains2() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["money", 90000], ["clear", 12, 10, 8, 5], ["build", _lodge(), 13, 11, 0], ["build", "power_generator", 17, 11, 0], ["wait", 2.0],
		["eval", "debug_repair_ruined()"], ["eval", "debug_jump_to(1, 21.0)"], ["wait", 3.5], ["eval", C + ".lit_all(true)"], ["wait", 1.0], ["eval", "set('debug_camera', null)"], ["eval", "_player.set_controls_enabled(false)"],
		["eval", "_player.set('torch_carried', false)"], ["eval", "_player._refresh_flashlight_state()"],
		["eval", "['Y power', _is_grid_powered()]"], ["eval", C + ".stand_before('13:11', 13.5)"], ["wait", 1.0], ["shot", "c2_far"]]
	s += [["eval", C + ".stand_before('13:11', 10.0)"]]
	for i in 6:
		s += [["eval", C + ".wl_walker('13:11')"], ["wait", 0.9], ["shot", "c2_life_%02d" % i], ["wait", 2.8]]
	s += [["eval", C + ".stand_before('13:11', 6.5)"]]
	for i in 8:
		s += [["wait", 0.35], ["eval", C + ".wl_pane('13:11', %d)" % i], ["shot", "c2_pull_%d" % i]]
	s += [["wait", 2.0], ["shot", "c2_shut"], ["eval", "get_tree().quit()"]]
	return s


## What is heard, for --write-movie (Y3): the marks print the clock; in by the reception's
## door, out, the torch on and off in the dark.
func mark(tag: String) -> void:
	say("MARK %s %.2f" % [tag, float(Time.get_ticks_msec()) / 1000.0])


func _sound_trail() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 3.0], ["eval", "debug_jump_to(1, 12.0)"], ["eval", "set('debug_camera', null)"],
		["door_front", "main_building", 2.0], ["wait", 2.0], ["eval", C + ".mark('door')"],
		["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('main_building'))"], ["wait", 5.0],
		["eval", BI + "._exit_crt_view()"], ["wait", 3.0], ["eval", "get_tree().quit()"]]
	return s


## His call from outside while you sit in the reception (Y24): called by hand, and left to it.
func call_state(tag: String) -> void:
	var brains: Array = _main.get("_enemy_brains")
	if brains.is_empty():
		say("CALL %s no brain" % tag)
		return
	var b = brains.back()
	var w: AudioStreamPlayer = b.get("_wall2d")
	say("CALL %s indoors=%s calls=%s next_in=%.1f playing=%s stream=%s db=%.1f" % [tag, str(b.get("_indoors")), str(b.get("_calls")), float(b.get("_call_next")) - float(Time.get_ticks_msec()) / 1000.0, str(w.playing) if w != null else "-", str(w.stream.resource_path).get_file() if w != null and w.stream != null else "-", float(w.volume_db) if w != null else 0.0])


func _call() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["wait", 2.0], ["eval", "debug_jump_to(2, 22.0)"], ["wait", 1.0], ["call", "debug_spawn_enemy", ["silent_man", 3]], ["wait", 2.0],
		["eval", "['Y brains', _enemy_brains.size()]"], ["eval", C + ".call_state('started')"],
		["eval", "_enemy_brains.back().set('_call_next', 0.0)"], ["wait", 0.5], ["eval", C + ".call_state('called')"], ["wait", 1.0], ["eval", C + ".call_state('a second on')"],
		["eval", "_enemy_brains.back().set('_call_next', 0.0)"], ["wait", 0.5], ["eval", C + ".call_state('again')"], ["eval", "get_tree().quit()"]]
	return s


## No music at night: the song of the hour, one left playing into the dusk, none starting.
func music_state(tag: String) -> void:
	var m: Node = _main.get("_music_director")
	var p: AudioStreamPlayer = m.get("_player")
	say("MUSIC %s h=%.2f cue_for=%s cue=%s phase=%s going_out=%s playing=%s" % [tag, float(_main.get("_time_of_day_hours")), str(m.call("_cue_for")), str(m.get("_cue")), str(m.get("_phase")), str(m.get("_going_out")), str(p.playing)])


func _music() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0]]
	for h in [7.0, 12.0, 17.0, 19.4, 19.6, 22.0, 23.5, 3.0, 5.5, 6.1]:
		s += [["eval", "debug_jump_to(%d, %s)" % [2 if h > 6.0 and h < 19.6 else 3, h]], ["wait", 0.2], ["eval", C + ".music_state('hour')"]]
	# A piece going at dusk; out and about at night with the rest over.
	s += [["eval", "debug_jump_to(2, 18.0)"], ["wait", 0.3], ["eval", "_music_director.set('_rest', 0.0)"], ["eval", "_music_director.set('_drive', 1.0)"],
		["eval", "_music_director._start(_music_director._cue_for(), 0.0)"], ["wait", 6.0], ["eval", C + ".music_state('a piece on')"],
		["eval", "debug_jump_to(2, 20.0)"], ["wait", 1.0], ["eval", C + ".music_state('dusk')"], ["wait", 8.0], ["eval", C + ".music_state('8 s on')"],
		["eval", "_music_director.set('_rest', 0.0)"], ["eval", "_music_director.set('_drive', 1.0)"], ["wait", 3.0], ["eval", C + ".music_state('free to start')"], ["eval", "get_tree().quit()"]]
	return s


## Out of a building with the Girl hunting (Y30, Y31): where she is while you are in, what
## comes through the walls, how far she is second by second out there; her laughs at once (Y29).
func girl_state(tag: String) -> void:
	var brains: Array = _main.get("_enemy_brains")
	if brains.is_empty():
		say("GIRL %s none" % tag)
		return
	var b = brains.back()
	var body: Node3D = b.get("_body")
	var laughs := 0
	for n in (b.get("_root") as Node).get_children():
		if n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).playing and (n as AudioStreamPlayer3D).stream != null and str((n as AudioStreamPlayer3D).stream.resource_path).contains("girl_laugh"):
			laughs += 1
	var out: Vector3 = b.get("_out_pos")
	var door: Vector3 = b.get("_door_at")
	var hum: AudioStreamPlayer = b.get("_wall_hum")
	var at := "-" if out == Vector3.INF else "%.1f" % Vector2(out.x - door.x, out.z - door.z).length()
	var seen: bool = body.visible and b.call("_is_seen", body.global_position + Vector3(0, 1.5, 0), -4.0)
	var torch: bool = b.call("_in_flashlight", body.global_position + Vector3(0, 1.5, 0))
	say("GIRL %s phase=%s d=%.1f visible=%s seen=%s torch=%s/%s out=%s hum=%s laughs=%d health=%s" % [tag, str(b.get("_phase")), body.global_position.distance_to((_main.get("_player") as Node3D).global_position), str(body.visible), str(seen), str(b.call("_flashlight_on")), str(torch), at, ("%.0f" % hum.volume_db) if hum.playing else "off", laughs, str(_main.get("_player_health"))])


func _stay() -> float:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--stay="):
			return float(str(a).trim_prefix("--stay="))
	return 1.0


func _girl_out() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["wait", 2.0], ["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(2, 22.0)"], ["wait", 1.0], ["call", "debug_spawn_enemy", ["girl", 3]], ["wait", 2.0],
		["eval", C + ".girl_state('spawned')"], ["eval", "_enemy_brains.back().set('_round', 2)"], ["door_front", "main_building", 2.0], ["wait", 2.0], ["eval", C + ".girl_state('at the door')"],
		["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('main_building'))"], ["wait", 0.5]]
	var t := 0.0
	while t < _stay():
		s += [["eval", C + ".girl_state('in %.0f s')" % t], ["wait", 2.0]]
		t += 2.0
	s += [["eval", C + ".girl_state('going out')"], ["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["eval", "_interior_manager._building_interior._extras.handle_exit()"], ["wait", 1.5]]
	if OS.get_cmdline_user_args().has("--torch"):
		s += [["wait", 0.6], ["eval", "_player.toggle_flashlight()"]]
	s += [["shot", "girl_out_0"]]
	for i in 44:
		s += [["eval", C + ".girl_state('out %d')" % i], ["wait", 1.0]]
		if i == 1:
			s += [["shot", "girl_out_2"]]
	s += [["eval", "get_tree().quit()"]]
	return s


## The ring round the lamp: nine pairs of eyes, and how many of her laughs at a time (Y29).
func _girl_ring() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["wait", 2.0], ["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(2, 22.0)"], ["wait", 1.0], ["call", "debug_spawn_enemy", ["girl", 3]], ["wait", 2.0],
		["eval", "_enemy_brains.back()._start_ring()"]]
	for i in 30:
		s += [["eval", C + ".girl_state('ring %d')" % i], ["wait", 0.25]]
	s += [["eval", "get_tree().quit()"]]
	return s


## Space stands you up from the PC (Y15), and not from a line you are typing in.
func _pc() -> Array:
	var s: Array = BOOT.duplicate(true)
	s += [["wait", 4.0], ["eval", "['Y at the PC', " + BI + "._crt_active]"], ["key", "SPACE"], ["wait", 1.5], ["eval", "['Y after Space', " + BI + "._crt_active]"], ["eval", "get_tree().quit()"]]
	return s
