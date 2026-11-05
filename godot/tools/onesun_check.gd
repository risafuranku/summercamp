extends "res://tools/shot_driver.gd"

## The camp's own sun in the reception built in the camp's world (W26, one world): from points
## just inside each of its windows a line back towards the sun, and every shadow caster's box
## it goes through (what keeps the sun out), the sun's own settings. Lines "ONESUN ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/onesun_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('OnesunCheck')"
const RL = preload("res://scripts/reception/reception_layout.gd")


func _bi():
	return _main.get("_interior_manager").get("_building_interior")


func report(tag: String) -> void:
	var sun: DirectionalLight3D = _main.get("sun")
	var root: Node3D = _bi().get("_room_root")
	var fwd := (-sun.global_basis.z).normalized()
	var env: Environment = root.get_world_3d().environment
	print("ONESUN %s sun visible=%s energy=%.2f shadow=%s max_dist=%.0f mask=%d fwd=%s ambient=%.2f %s" % [tag, str(sun.visible), sun.light_energy,
		str(sun.shadow_enabled), sun.directional_shadow_max_distance, sun.light_cull_mask, str(fwd.snapped(Vector3.ONE * 0.01)),
		env.ambient_light_energy if env != null else -1.0, str(env.ambient_light_source) if env != null else "-"])
	var world := root.get_world_3d()
	var casters: Array = []
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_inside_tree() or g.get_world_3d() != world or not g.is_visible_in_tree() or g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		casters.append([g, g.global_transform * g.get_aabb()])
	for w in [["office", RL.OFFICE_WINDOW_CENTER, Vector3(0, 0, 1)], ["side", RL.SIDE_WINDOW_CENTER, Vector3(-1, 0, 0)], ["back", RL.BACK_WINDOW_CENTER, Vector3(1, 0, 0)]]:
		var c: Vector3 = w[1]
		var into: Vector3 = w[2]
		var hits := {}
		var free := 0
		for i in 3:
			for j in 3:
				var off := Vector3(0, (j - 1) * 0.3, 0) + (Vector3(0.3 * (i - 1), 0, 0) if absf(into.z) > 0.5 else Vector3(0, 0, 0.3 * (i - 1)))
				var p := root.global_transform * (c + into * 0.3 + off)
				var a := p
				var b := p - fwd * 40.0
				var any := false
				for cs in casters:
					if (cs[1] as AABB).intersects_segment(a, b) != null:
						var k := str((cs[0] as Node).get_path()).right(60)
						hits[k] = int(hits.get(k, 0)) + 1
						any = true
				if not any:
					free += 1
		print("ONESUN %s window %s: %d of 9 lines free" % [tag, w[0], free])
		var keys := hits.keys()
		keys.sort_custom(func(x, y): return int(hits[x]) > int(hits[y]))
		for k in keys.slice(0, 6):
			print("ONESUN %s   %d %s" % [tag, hits[k], k])


## Which worlds draw what: the room's viewport, the sun's, the camp's.
func ids() -> void:
	var bi = _bi()
	var sun: DirectionalLight3D = _main.get("sun")
	var vp: SubViewport = bi.get("_viewport")
	var cam: Camera3D = bi.get("_interior_camera")
	print("ONESUN worlds room=%d sun=%d camp=%d own=%s sun.layers=%d cam.mask=%d sun.visible=%s energy=%.2f cam.current=%s cam.vp=%s" % [
		vp.find_world_3d().get_rid().get_id(), sun.get_world_3d().get_rid().get_id(), (_main.get("_world_3d") as Node3D).get_world_3d().get_rid().get_id(),
		str(vp.own_world_3d), sun.layers, cam.cull_mask, str(sun.is_visible_in_tree()), sun.light_energy, str(cam.current), str(cam.get_viewport().name)])
	var names := []
	for l in (bi.get("_room_root") as Node).find_children("*", "Light3D", true, false):
		names.append("%s:%s:%.2f" % [l.name, str((l as Light3D).visible), (l as Light3D).light_energy])
	print("ONESUN room lights " + ", ".join(names))


## Every light of the room off and no ambient in it: only the sun left to light it (every
## frame: the room puts its lights back as the hour goes).
var _dark := false


func dark_room() -> void:
	_dark = true


func same_world() -> void:
	var bi = _bi()
	var sun: DirectionalLight3D = _main.get("sun")
	var vp: SubViewport = bi.get("_viewport")
	print("ONESUN same world: room==sun %s, room==camp %s, root==sun %s" % [str(vp.find_world_3d() == sun.get_world_3d()),
		str(vp.find_world_3d() == (_main.get("_world_3d") as Node3D).get_world_3d()), str(get_tree().root.find_world_3d() == sun.get_world_3d())])


func tune(fill: float, tube: float, window: float, exposure: float) -> void:
	var bi = _bi()
	bi.day_fill = fill
	bi.day_tube = tube
	bi.day_window = window
	bi.day_exposure = exposure
	bi._apply_room_time_profile()


## The picture's brightness: the whole of it, the sunlit door's patch, the shaded wall.
func measure(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var regions := {"door_left": Rect2i(int(w * 0.05), int(h * 0.3), int(w * 0.2), int(h * 0.3)), "wall_mid": Rect2i(int(w * 0.45), int(h * 0.15), int(w * 0.1), int(h * 0.3)),
		"floor": Rect2i(int(w * 0.3), int(h * 0.8), int(w * 0.4), int(h * 0.15))}
	var out := []
	for k in regions:
		var r: Rect2i = regions[k]
		var sum := 0.0
		var n := 0
		for y in range(r.position.y, r.end.y, 4):
			for x in range(r.position.x, r.end.x, 4):
				sum += img.get_pixel(x, y).get_luminance()
				n += 1
		out.append("%s %.2f" % [k, sum / maxf(n, 1)])
	print("ONESUN measure %s: %s" % [tag, ", ".join(out)])


## A light of nobody's straight down through everything, no shadow: does the room's eye
## draw directional lights at all?
func test_light() -> void:
	var d := DirectionalLight3D.new()
	d.name = "TestDown"
	d.light_energy = 3.0
	d.light_color = Color(1.0, 0.2, 0.2)
	d.shadow_enabled = false
	(_main.get("_world_3d") as Node3D).add_child(d)
	d.rotation_degrees = Vector3(-90, 0, 0)
	print("ONESUN red light straight down added")


## A plain white box on the counter and one out on the grass by the porch.
func cubes() -> void:
	var bi = _bi()
	var root: Node3D = bi.get("_room_root")
	for spot in [[root, Vector3(0.6, 1.25, -1.2), "CubeIn"], [root, Vector3(1.7, 0.4, -4.4), "CubeOut"]]:
		var m := MeshInstance3D.new()
		m.name = spot[2]
		var b := BoxMesh.new()
		b.size = Vector3(0.3, 0.3, 0.3)
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.9, 0.9)
		m.material_override = mat
		m.set_meta("retro_skip", true)
		(spot[0] as Node3D).add_child(m)
		m.position = spot[1]
		m.rotation_degrees.y = 30.0
	print("ONESUN cubes in the room and out by the porch")


var _green := false
var _no_env_ambient := false
var _nosun := false
var _hold := Vector2(INF, INF)


func sun_state(tag: String) -> void:
	var sun: DirectionalLight3D = _main.get("sun")
	var bi = _bi()
	var tube: Light3D = bi.get("_ceiling_light")
	var pr = bi.get("_room_probe")
	print("ONESUN %s sun e=%.2f vis=%s shining=%.2f daylight=%.2f tube=%.2f probe=%.2f eye=%.2f" % [tag, sun.light_energy, str(sun.visible), bi._camp_sun_shining(),
		bi.get("_daylight_factor"), tube.light_energy, pr.ambient_color_energy if pr != null else -1.0, bi.get("_room_eye").exposure_multiplier])


## A camera round the reception from the camp: `angle` 0 = the shell's +z side, `dist` m off
## its middle, `h` m over the eye's 1.4 m.
func outside(angle: float, dist: float, h: float) -> void:
	var shell: Node3D = _bi()._reception_shell()
	if shell == null:
		print("ONESUN no shell")
		return
	var c := shell.global_position + Vector3(0, 1.4, 0)
	var a := deg_to_rad(angle) + shell.global_rotation.y
	var cam := Camera3D.new()
	(_main.get("_world_3d") as Node3D).add_child(cam)
	cam.fov = 62.0
	cam.far = 400.0
	cam.cull_mask = (_main.get("_player").get("_camera") as Camera3D).cull_mask
	cam.global_position = c + Vector3(sin(a), 0.0, cos(a)) * dist + Vector3(0, h, 0)
	cam.look_at(c + Vector3(0, 0.2, 0), Vector3.UP)
	var old = _main.get("debug_camera")
	if old != null and is_instance_valid(old):
		old.queue_free()
	_main.set("debug_camera", cam)
	cam.current = true


## Every flat thing standing in the camp within `r` m of the reception (quads, planes,
## thin boxes) that the player's eye could see: where, how big, its layers.
func flats(tag: String, r: float) -> void:
	var shell: Node3D = _bi()._reception_shell()
	var mask: int = (_main.get("_player").get("_camera") as Camera3D).cull_mask
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_inside_tree() or not g.is_visible_in_tree() or g.get_world_3d() != shell.get_world_3d():
			continue
		var bb := g.global_transform * g.get_aabb()
		var c := bb.get_center()
		if c.distance_to(shell.global_position) > r:
			continue
		var sz := bb.size
		var dims := [sz.x, sz.y, sz.z]
		dims.sort()
		if dims[0] > 0.06 or dims[1] < 0.8 or dims[2] < 0.8:
			continue
		var mat := g.material_override
		var unshaded := mat is BaseMaterial3D and (mat as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		print("ONESUN %s flat %s seen=%s layers=%d size=%s at=%s unshaded=%s" % [tag, str(g.get_path()).right(90), str((g.layers & mask) != 0), g.layers,
			str(sz.snapped(Vector3.ONE * 0.01)), str((c - shell.global_position).snapped(Vector3.ONE * 0.1)), str(unshaded)])


## Every light that is on within 14 m of the room, the room's own and the camp's.
func lights_near(tag: String) -> void:
	var root: Node3D = _bi().get("_room_root")
	var c := root.global_transform * Vector3(0, 1.5, 0)
	for n in get_tree().root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if not l.is_inside_tree() or not l.is_visible_in_tree() or l.light_energy <= 0.001:
			continue
		var d := l.global_position.distance_to(c)
		if l is DirectionalLight3D or d < 14.0:
			var rng := (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else 0.0)
			print("ONESUN %s light %s e=%.2f d=%.1f r=%.1f mask=%d sh=%s %s" % [tag, l.get_class(), l.light_energy, d, rng, l.light_cull_mask, str(l.shadow_enabled), str(l.get_path()).right(70)])
	var pr = _bi().get("_room_probe")
	if pr != null:
		print("ONESUN %s probe ambient %s x%.2f" % [tag, str(pr.ambient_color), pr.ambient_color_energy])
	var eye = _bi().get("_room_eye")
	if eye != null:
		print("ONESUN %s eye exposure %.2f" % [tag, eye.exposure_multiplier])


## The room's eye held still at a yaw and pitch (the mouse and the breath move it otherwise).
func hold_view(yaw: float, pitch: float) -> void:
	_hold = Vector2(yaw, pitch)


## The camp's sun out for a picture (what the room is without it), then back.
func nosun(on: bool) -> void:
	_nosun = on
	if not on:
		(_main.get("sun") as DirectionalLight3D).visible = true


func green_probe() -> void:
	_green = true


func no_env_ambient() -> void:
	_no_env_ambient = true


func _process(delta: float) -> void:
	super._process(delta)
	if _main == null:
		return
	var bi0 = _bi() if _main.get("_interior_manager") != null else null
	if _green and bi0 != null and bi0.get("_room_probe") != null:
		var pr0 = bi0.get("_room_probe")
		pr0.ambient_color = Color(0.0, 1.0, 0.0)
		pr0.ambient_color_energy = 3.0
	if _nosun:
		(_main.get("sun") as DirectionalLight3D).visible = false
	if _hold.x != INF and bi0 != null and bi0.get("_interior_camera") != null:
		var cam: Camera3D = bi0.get("_interior_camera")
		cam.rotation = bi0.get("_idle_cam_base_rot") + Vector3(deg_to_rad(_hold.y), deg_to_rad(_hold.x), 0.0)
	if _no_env_ambient:
		var env: Environment = (_main.get("_world_3d") as Node3D).get_world_3d().environment
		env.ambient_light_energy = 0.0
	if not _dark:
		return
	var bi = _bi()
	for l in (bi.get("_room_root") as Node).find_children("*", "Light3D", true, false):
		(l as Light3D).visible = false
	var pr = bi.get("_room_probe")
	if pr != null:
		pr.ambient_color_energy = 0.0


func _ready() -> void:
	super._ready()
	# Last of all every frame: what the test sets is what is drawn (the room and the hour
	# put their lights and ambient back every frame).
	process_priority = 1000
	for a in OS.get_cmdline_user_args():
		if a == "--part=times":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5],
				["eval", C + ".dark_room()"]]
			for h in [7.5, 8.5, 15.5, 16.5, 17.5]:
				st += [["eval", "debug_jump_to(1, %s)" % h], ["wait", 1.0], ["eval", C + ".report('%s')" % h]]
				for v in [[0.0, -20.0, "front"], [-84.0, -20.0, "right"], [150.0, -15.0, "back"], [62.0, -25.0, "left"]]:
					st += [["eval", "_interior_manager._building_interior._look.set('yaw_deg', %s)" % v[0]], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', %s)" % v[1]],
						["wait", 0.5], ["shot", "h%04d_%s" % [int(h * 100), v[2]]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=tune2":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5]]
			var sets := [[0.3, 0.5, 0.55, 1.8, "a"], [0.15, 0.3, 0.4, 1.8, "b"], [0.1, 0.2, 0.3, 2.0, "c"], [0.08, 0.15, 0.25, 2.4, "d"], [0.12, 0.25, 0.35, 1.5, "e"]]
			for view in [[16.8, 0.0, -25.0, "counter"], [17.5, 150.0, -15.0, "door"], [12.0, 0.0, -10.0, "noon"], [9.0, 62.0, -25.0, "morning"]]:
				st += [["eval", "debug_jump_to(1, %s)" % view[0]], ["wait", 1.0]]
				for v in sets:
					st += [["eval", C + ".tune(%s, %s, %s, %s)" % [v[0], v[1], v[2], v[3]]],
						["eval", "_interior_manager._building_interior._look.set('yaw_deg', %s)" % view[1]], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', %s)" % view[2]],
						["wait", 0.6], ["shot", "%s_%s_sun" % [view[3], v[4]]],
						["eval", C + ".nosun(true)"], ["wait", 0.4], ["shot", "%s_%s_dark" % [view[3], v[4]]], ["eval", C + ".nosun(false)"]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=tune3":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5]]
			var sets := [[0.3, 0.5, 0.55, 1.8, "a"], [0.15, 0.25, 0.35, 1.6, "b"], [0.1, 0.2, 0.3, 1.4, "c"], [0.08, 0.15, 0.25, 1.25, "d"], [0.06, 0.1, 0.2, 1.1, "e"]]
			for view in [[16.2, 0.0, -25.0, "c162"], [16.8, 0.0, -25.0, "c168"], [17.5, 150.0, -15.0, "door175"], [12.0, 0.0, -10.0, "noon"], [9.0, 62.0, -20.0, "morn"]]:
				st += [["eval", "debug_jump_to(1, %s)" % view[0]], ["wait", 1.0], ["eval", C + ".hold_view(%s, %s)" % [view[1], view[2]]]]
				for v in sets:
					st += [["eval", C + ".tune(%s, %s, %s, %s)" % [v[0], v[1], v[2], v[3]]],
						["wait", 0.5], ["shot", "%s_%s_sun" % [view[3], v[4]]],
						["eval", C + ".nosun(true)"], ["wait", 0.4], ["shot", "%s_%s_dark" % [view[3], v[4]]], ["eval", C + ".nosun(false)"]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=sweep":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5]]
			for h in [9.0, 12.0, 15.5, 16.5, 17.5, 18.5, 19.25, 20.0, 22.0]:
				st += [["eval", "debug_jump_to(1, %s)" % h], ["wait", 1.2], ["eval", C + ".sun_state('%s')" % h]]
				for v in [[0.0, -22.0, "front"], [150.0, -15.0, "back"], [62.0, -22.0, "left"]]:
					st += [["eval", C + ".hold_view(%s, %s)" % [v[0], v[1]]], ["wait", 0.4], ["shot", "s%04d_%s" % [int(h * 100), v[2]]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=weather":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5]]
			for w in [[1, "clear"], [3, "rain"], [5, "storm"]]:
				for h in [12.0, 17.5]:
					st += [["eval", "debug_jump_to(1, %s)" % h], ["wait", 0.5], ["eval", "weather_system.set_weather(%d)" % w[0]], ["eval", "_set_weather_state(%d)" % w[0]], ["wait", 3.0],
						["eval", C + ".sun_state('%s_%s')" % [w[1], h]], ["eval", "print('ONESUN weather main=', _weather_state, ' room=', _interior_manager._building_interior._weather_state)"]]
					for v in [[0.0, -22.0, "front"], [150.0, -15.0, "back"]]:
						st += [["eval", C + ".hold_view(%s, %s)" % [v[0], v[1]]], ["wait", 0.4], ["shot", "%s_%04d_%s" % [w[1], int(h * 100), v[2]]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=rain":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5],
				["eval", "debug_jump_to(1, 12.0)"], ["wait", 0.5], ["eval", "weather_system.set_weather(4)"], ["eval", "_set_weather_state(4)"], ["wait", 35.0],
				["eval", "print('ONESUN player at ', _player.global_position, ' shell ', _interior_manager._building_interior._reception_shell().global_position)"]]
			for v in [[0.0, -22.0, "front"], [150.0, -15.0, "back"], [62.0, -22.0, "left"], [-84.0, -20.0, "right"], [0.0, -60.0, "floor"]]:
				st += [["eval", C + ".hold_view(%s, %s)" % [v[0], v[1]]], ["wait", 0.5], ["shot", "r_%s" % v[2]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=glass":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
				["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 2.0]]
			for h in [12.0, 17.5, 22.0]:
				st += [["eval", "debug_jump_to(1, %s)" % h], ["wait", 2.0]]
				for pane in [["office_glass", 2.2], ["office_glass", 4.5], ["back_glass", 2.2], ["side_glass", 2.2]]:
					st += [["glass", pane[0], pane[1]], ["wait", 0.6], ["shot", "g%04d_%s_%d" % [int(h * 100), pane[0], int(pane[1] * 10)]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=out":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
				["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 2.0]]
			for h in [22.0, 12.0]:
				st += [["eval", "debug_jump_to(1, %s)" % h], ["wait", 2.0]]
				st += [["eval", C + ".flats('%s', 9.0)" % h]]
				for ang in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]:
					st += [["eval", C + ".outside(%s, 7.0, 0.2)" % ang], ["wait", 0.6], ["shot", "o%04d_%03d" % [int(h * 100), int(ang)]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=lights":
			_steps = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
				["eval", "debug_jump_to(1, 17.5)"], ["wait", 1.0], ["eval", C + ".tune(0.06, 0.1, 0.2, 1.1)"], ["wait", 0.5], ["eval", C + ".lights_near('1730')"],
				["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.0], ["eval", C + ".lights_near('1200')"],
				["eval", "get_tree().quit()"]]
			return
		if a == "--part=tune":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5],
				["eval", "debug_jump_to(1, 17.5)"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior._look.set('yaw_deg', 150.0)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', -15.0)"]]
			var sets := [[1.0, 1.0, 1.0, 1.0, "old"], [0.3, 0.5, 0.55, 1.8, "now"], [0.15, 0.3, 0.5, 1.4, "low"], [0.1, 0.2, 0.4, 1.6, "lower"], [0.12, 0.0, 0.45, 1.6, "no_tube"]]
			for v in sets:
				st += [["eval", C + ".tune(%s, %s, %s, %s)" % [v[0], v[1], v[2], v[3]]], ["wait", 0.8], ["shot", "t_%s" % v[4]], ["eval", C + ".measure('%s')" % v[4]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=probe":
			_steps = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
				["mouse", 0.5, 0.5], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.5],
				["eval", "_interior_manager._building_interior._look.set('yaw_deg', 0.0)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', -10.0)"],
				["wait", 0.8], ["shot", "a_noon"],
				["eval", C + ".green_probe()"], ["wait", 0.8], ["shot", "b_green_probe"],
				["eval", C + ".dark_room()"], ["wait", 0.8], ["shot", "c_green_probe_lights_off"],
				["eval", C + ".no_env_ambient()"], ["wait", 0.8], ["shot", "d_no_env_ambient"],
				["eval", "get_tree().quit()"],
			]
			return
		if a == "--part=dark":
			_steps = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
				["eval", "debug_jump_to(1, 16.8)"], ["wait", 1.5], ["eval", C + ".ids()"], ["eval", C + ".same_world()"],
				["eval", "_interior_manager._building_interior._look.set('yaw_deg', 0.0)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', -25.0)"],
				["eval", C + ".cubes()"], ["wait", 0.8], ["shot", "a_lit"],
				["eval", C + ".dark_room()"], ["wait", 0.8], ["shot", "b_dark_room"], ["eval", C + ".ids()"],
				["eval", "sun.set('shadow_enabled', false)"], ["wait", 0.6], ["shot", "c_dark_noshadow"],
				["eval", C + ".test_light()"], ["wait", 0.6], ["shot", "d_red_down"],
				["eval", "_interior_manager._building_interior._look.set('yaw_deg', 30.0)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', -10.0)"], ["wait", 0.8], ["shot", "e_red_to_window"],
				["eval", "get_tree().quit()"],
			]
			return
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
		["eval", "debug_jump_to(1, 9.0)"], ["wait", 1.0], ["eval", C + ".report('09:00')"],
		["eval", "debug_jump_to(1, 14.5)"], ["wait", 1.0], ["eval", C + ".report('14:30')"],
		["eval", "debug_jump_to(1, 16.8)"], ["wait", 1.0], ["eval", C + ".report('16:48')"],
		["eval", "get_tree().quit()"],
	]
