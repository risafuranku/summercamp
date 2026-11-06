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


func rich() -> void:
	CoreRoot.get_state().money = 1000000


## The camp's structures by type (what a new game has).
func structures() -> void:
	var bm = _main.get("building_manager")
	var st: Node = bm.get_node_or_null("Structures") if bm != null else null
	var types := {}
	if st != null:
		for c in st.get_children():
			var t := str(c.get_meta("building_type", "?"))
			types[t] = int(types.get(t, 0)) + 1
	print("ONESUN structures ", types)


## A camera round the first structure of `type`: `angle` 0 = its +z (front), `dist` m off.
func around(type: String, angle: float, dist: float, h: float) -> void:
	var st: Node3D = _main.debug_structure_of_type(type)
	if st == null:
		print("ONESUN no ", type)
		return
	var c := st.global_position + Vector3(0, 1.3, 0)
	var a := deg_to_rad(angle) + st.global_rotation.y
	var cam := Camera3D.new()
	(_main.get("_world_3d") as Node3D).add_child(cam)
	cam.fov = 62.0
	cam.far = 400.0
	cam.cull_mask = (_main.get("_player").get("_camera") as Camera3D).cull_mask
	cam.global_position = c + Vector3(sin(a), 0.0, cos(a)) * dist + Vector3(0, h, 0)
	cam.look_at(c, Vector3.UP)
	var old = _main.get("debug_camera")
	if old != null and is_instance_valid(old):
		old.queue_free()
	_main.set("debug_camera", cam)
	cam.current = true


## What each viewport drew last frame: the camp's (main) and the rooms' (draw calls, objects).
func vp_info(tag: String) -> void:
	var out := []
	var main_vp := (_main.get("_world_3d") as Node3D).get_viewport()
	var vps: Array = [["camp", main_vp]]
	var im = _main.get("_interior_manager")
	vps.append(["reception", im.get("_building_interior").get("_viewport")])
	vps.append(["cabin", im.get("_cabin_interior").get("_viewport")])
	for v in vps:
		var vp: Viewport = v[1]
		if vp == null:
			continue
		var rid := vp.get_viewport_rid()
		var dc := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var ob := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		var sh := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		out.append("%s dc=%d obj=%d shadow_dc=%d" % [v[0], dc, ob, sh])
	print("ONESUN vp %s: %s  fps=%.0f" % [tag, ", ".join(out), Engine.get_frames_per_second()])


func cellar_meshes(tag: String) -> void:
	var bi = _main.get("_interior_manager").get("_bowling_interior")
	var cr: Node3D = bi.get("_cellar_root")
	var cam: Camera3D = bi.get("_interior_camera")
	var n := 0
	for m in cr.find_children("*", "GeometryInstance3D", true, false):
		var g := m as GeometryInstance3D
		if n < 14:
			var mat = g.material_override if g.material_override != null else (g.get("mesh").surface_get_material(0) if g.get("mesh") != null and g.get("mesh").get_surface_count() > 0 else null)
			print("ONESUN %s cm %s vis=%s L=%d mat=%s tr=%s" % [tag, str(g.name), str(g.is_visible_in_tree()), g.layers, mat.get_class() if mat != null else "-",
				str((mat as BaseMaterial3D).transparency) if mat is BaseMaterial3D else "-"])
		n += 1
	print("ONESUN %s cellar meshes=%d cam_mask=%d cam_far=%.1f cam_near=%.2f env=%s attrs=%s" % [tag, n, cam.cull_mask, cam.far, cam.near, str(cam.environment), str(cam.attributes)])


func env_state(tag: String) -> void:
	var env: Environment = (_main.get("_world_3d") as Node3D).get_world_3d().environment
	print("ONESUN %s env fog=%s mode=%d dens=%.4f h=%.1f hdens=%.3f aerial=%.2f sky_affect=%.2f vol=%s bg=%d" % [tag, str(env.fog_enabled), env.fog_mode, env.fog_density,
		env.fog_height, env.fog_height_density, env.fog_aerial_perspective, env.fog_sky_affect, str(env.volumetric_fog_enabled), env.background_mode])


func bowl_state(tag: String) -> void:
	var bi = _main.get("_interior_manager").get("_bowling_interior")
	var cam: Camera3D = bi.get("_interior_camera")
	var cr: Node3D = bi.get("_cellar_root")
	var root: Node3D = bi.get("_root")
	var dark := cr.get_node_or_null("CellarDark") as MeshInstance3D
	var st = bi.get("_stations").get("cellar")
	print("ONESUN %s bowl cam=%s cur=%s cellar=%s root=%s root_vis=%s dark=%s/%s station=%s vp_world_same=%s" % [tag, str(cam.global_position.snapped(Vector3.ONE * 0.1)), str(cam.current),
		str(cr.global_position.snapped(Vector3.ONE * 0.1)), str(root.global_position.snapped(Vector3.ONE * 0.1)), str(root.is_visible_in_tree()),
		str(dark.global_position.snapped(Vector3.ONE * 0.1)) if dark != null else "-", str(dark.is_visible_in_tree()) if dark != null else "-",
		str((st as Node3D).global_position.snapped(Vector3.ONE * 0.1)) if st != null else "-", str(cam.get_world_3d() == (_main.get("_world_3d") as Node3D).get_world_3d())])
	var vp := cam.get_viewport()
	print("ONESUN %s bowl viewport=%s cams: %s" % [tag, str(vp.get_path()).right(60), str(vp.get_camera_3d().get_path()).right(80) if vp.get_camera_3d() != null else "-"])


## Tents of the three tiers side by side (the second and third put up straight, as an
## upgrade would): `around` then finds them by type.
func tents() -> void:
	var bm = _main.get("building_manager")
	bm.place_tent_at(Vector2i(15, 12), 2)
	bm.place_tent_at(Vector2i(17, 12), 3)


func tent_door(type: String, open: bool) -> void:
	var st: Node3D = _main.debug_structure_of_type(type)
	var im = _main.get("_interior_manager")
	im.set_tent_door(im._room_key_for(st), open)


## The cabins' first tier's cube as drawn (its six faces as PNGs in the out folder).
func save_cubes() -> void:
	var ci = _main.get("_interior_manager").get("_cabin_interior")
	var cubes: Dictionary = ci.get("cubes")
	print("ONESUN cubes tiers=", cubes.keys())
	if not cubes.has(1):
		return
	var i := 0
	for t in cubes[1]:
		var img: Image = (t as Texture2D).get_image()
		if img != null:
			img.save_png(_out_dir + "/cube1_%d.png" % i)
			var sum := 0.0
			for y in range(0, img.get_height(), 8):
				for x in range(0, img.get_width(), 8):
					sum += img.get_pixel(x, y).get_luminance()
			print("ONESUN cube1 face %d mean %.3f" % [i, sum / float((img.get_height() / 8) * (img.get_width() / 8))])
		i += 1


## Everything drawn in the doorway of the first `type` (a box round its middle, from the
## leaf's plane half a metre in): name, layers, whether the player's camera draws it.
func door_probe(type: String, tag: String) -> void:
	var st: Node3D = _main.debug_structure_of_type(type)
	if st == null:
		print("ONESUN %s door_probe no %s" % [tag, type])
		return
	var da = load("res://scripts/attractions/door_anim.gd")
	var way: Dictionary = da.entry_points(st, 0)
	var o: Vector3 = way["outside"]
	var i: Vector3 = way["inside"]
	var into := (i - o)
	into.y = 0.0
	into = into.normalized()
	var sill: Vector3 = way["sill"]
	var c := Vector3(sill.x, sill.y + 1.0, sill.z) + into * 0.25
	var box := AABB(c - Vector3(0.25, 0.4, 0.25), Vector3(0.5, 0.8, 0.5))
	var cam := get_viewport().get_camera_3d()
	var mask := cam.cull_mask if cam != null else 0
	var door = way.get("door")
	print("ONESUN %s door_probe %s sill=%s into=%s leaf_rot=%s cam=%s" % [tag, type, str(sill.snapped(Vector3.ONE * 0.01)), str(into.snapped(Vector3.ONE * 0.01)),
		str((door as Node3D).get_parent().rotation_degrees.snapped(Vector3.ONE)) if door is Node3D else "-", str(cam.get_path()).right(50) if cam != null else "-"])
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_inside_tree() or not g.is_visible_in_tree():
			continue
		var gb: AABB = g.global_transform * g.get_aabb()
		if gb.intersects(box):
			print("ONESUN %s   in_door %s L=%d drawn=%s size=%s" % [tag, str(g.get_path()).right(96), g.layers, str((g.layers & mask) != 0), str(gb.size.snapped(Vector3.ONE * 0.01))])


## Out on foot by the door of `type`: the room `prop` of interior_manager, closed by `close`.
func walk_out2(prop: String, close: String, type: String) -> void:
	var im = _main.get("_interior_manager")
	var st: Node3D = _main.debug_structure_of_type(type)
	var room = im.get(prop)
	print("ONESUN walk_out2 ", type, " -> ", im.leave_on_foot(room, st, Callable(room, close)) if st != null and room != null else "no " + type)


## The reception's eye now (one line): where, which way, open, walking, the frame.
func rec_cam(tag: String) -> void:
	var bi = _bi()
	var cam: Camera3D = bi.get("_interior_camera")
	var ex = bi.get("_extras")
	var main_vp := (_main.get("_world_3d") as Node3D).get_viewport() as SubViewport
	print("ONESUN %s rec frame=%d open=%s cam=%s rot=%s walking=%s camp_upd=%d room_upd=%d player=%s" % [tag, Engine.get_process_frames(), str(bi.is_open()),
		str(cam.position.snapped(Vector3.ONE * 0.01)), str((cam.rotation * 57.3).snapped(Vector3.ONE)), str(ex.call("_walking")) if ex != null and ex.has_method("_walking") else "-",
		main_vp.render_target_update_mode if main_vp != null else -1, (bi.get("_viewport") as SubViewport).render_target_update_mode,
		str((_main.get("_player") as Node3D).global_position.snapped(Vector3.ONE * 0.01))])


## The reception room's meshes that reach out of its shell (out of its walls' outer faces,
## under the ground, over the walls' top): name, how far (X2 of 5. 11.).
func rec_poke(tag: String) -> void:
	var bi = _bi()
	var shell: Node3D = bi.call("_reception_shell")
	var room: Node3D = bi.get("_room_root")
	if shell == null or room == null:
		print("ONESUN %s rec_poke no shell/room" % tag)
		return
	var RLs = load("res://scripts/reception/reception_layout.gd")
	var b: Rect2 = RLs.local_bounds()
	var t := 0.12
	var lo := Vector3(b.position.x - t, -0.02, b.position.y - t)
	var hi := Vector3(b.end.x + t, float(RLs.WALL_H) + 0.02, b.end.y + t)
	var inv := shell.global_transform.affine_inverse()
	var n := 0
	for m in room.find_children("*", "GeometryInstance3D", true, false):
		var g := m as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var box: AABB = (inv * g.global_transform) * g.get_aabb()
		var side := maxf(maxf(lo.x - box.position.x, box.end.x - hi.x), maxf(lo.z - box.position.z, box.end.z - hi.z))
		var up := box.end.y - hi.y
		var down := lo.y - box.position.y
		if side > 0.004 or up > 0.004 or down > 0.004:
			n += 1
			print("ONESUN %s poke %s side=%.3f up=%.3f down=%.3f box=%s" % [tag, str(g.get_path()).right(70), side, up, down, str(box)])
	print("ONESUN %s rec_poke %d out of lo=%s hi=%s" % [tag, n, str(lo), str(hi)])


## The reception's eye turned to look at `p` (room space) and held there.
func rec_face(p: Vector3) -> void:
	var bi = _bi()
	var cam: Camera3D = bi.get("_interior_camera")
	var parent := cam.get_parent() as Node3D
	var from := parent.global_transform * cam.position
	var target := (bi.get("_room_root") as Node3D).global_transform * p
	var t := Transform3D(Basis(), from).looking_at(target, Vector3.UP)
	var local := parent.global_transform.affine_inverse() * t
	bi.set("_idle_cam_base_rot", local.basis.get_euler())
	bi.get("_look").reset()


## The rooms' dry boxes and the rain (X1 of 5. 11.): where, how big, drawn, the eye in it.
func dry_state(tag: String) -> void:
	var eye := get_viewport().get_camera_3d()
	for n in get_tree().root.find_children("*", "GPUParticlesCollisionBox3D", true, false):
		var d := n as GPUParticlesCollisionBox3D
		var box := AABB(d.global_position - d.size * 0.5, d.size)
		print("ONESUN %s dry %s vis=%s at=%s size=%s world_same=%s" % [tag, str(d.get_path()).right(60), str(d.is_visible_in_tree()), str(d.global_position.snapped(Vector3.ONE * 0.01)),
			str(d.size.snapped(Vector3.ONE * 0.01)), str(d.get_world_3d() == (_main.get("_world_3d") as Node3D).get_world_3d())])
	for n in get_tree().root.find_children("Rain*", "GPUParticles3D", true, false):
		var p := n as GPUParticles3D
		print("ONESUN %s rain %s at=%s emitting=%s fps=%d interp=%s ratio=%.2f" % [tag, str(p.name), str(p.global_position.snapped(Vector3.ONE * 0.1)), str(p.emitting), p.fixed_fps, str(p.interpolate), p.amount_ratio])
	var ci = _main.get("_interior_manager").get("_cabin_interior")
	var cam: Camera3D = ci.get("_interior_camera")
	print("ONESUN %s cabin eye at %s" % [tag, str(cam.global_position.snapped(Vector3.ONE * 0.01))])


## Everything drawn round a point of the reception's room space (a box `half` each way).
func rec_probe(tag: String, at: Vector3, half: float) -> void:
	var room: Node3D = _bi().get("_room_root")
	var c := room.global_transform * at
	var box := AABB(c - Vector3.ONE * half, Vector3.ONE * half * 2.0)
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_inside_tree() or not g.is_visible_in_tree():
			continue
		var gb: AABB = g.global_transform * g.get_aabb()
		if gb.size.length() > 60.0 or not gb.intersects(box):
			continue
		var mat = g.material_override
		var tex := ""
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
			tex = (mat as StandardMaterial3D).albedo_texture.resource_path.get_file()
		print("ONESUN %s at %s %s L=%d tex=%s box=%s" % [tag, str(at), str(g.get_path()).right(64), g.layers, tex, str(gb)])


## The reception's room shown or not (a shot with and without it: whatever differs but in its
## windows and doorway is the room seen from outside, X2 of 5. 11.).
func rec_room(on: bool) -> void:
	(_bi().get("_room_root") as Node3D).visible = on


## The room standing in a building of `type` (roomsgraze): kept hidden every frame while
## room_hidden(true), the room's own code showing it otherwise.
var _room_node: Node3D
var _room_hide := false


func room_target(type: String) -> void:
	var im = _main.get("_interior_manager")
	_room_node = null
	if type.begins_with("cabin"):
		_room_node = im.get("_cabin_interior").get("_cabin_root")
	elif type.begins_with("tent"):
		_room_node = im.get("_tent_interior").get("_tent_root")
	elif type.begins_with("caravan"):
		_room_node = im.get("_caravan_interior").get("_root")
	else:
		var st: Node3D = _main.debug_structure_of_type(type)
		for n in ["PubRoom", "BistroRoom", "JednotaRoom", "StaffRooms"]:
			var c = st.find_child(n, true, false) if st != null else null
			if c != null:
				_room_node = c
	print("ONESUN room_target %s -> %s" % [type, str(_room_node.get_path()) if _room_node != null else "-"])


## The first building of `from` is `to` now, as the upgrade menu does it.
func tier_up(from: String, to: String) -> void:
	var st: Node3D = _main.debug_structure_of_type(from)
	if st != null:
		_main.get("_interior_manager").call("_handle_replace_upgrade", st.get_meta("grid_origin"), from, to, 0)
	print("ONESUN tier_up %s -> %s: %s" % [from, to, str(_main.debug_structure_of_type(to) != null)])


func room_hidden(on: bool) -> void:
	_room_hide = on
	if not on and _room_node != null:
		_room_node.visible = true


## The camp's eye by a wall of the first building of `type`, looking along it (wall 0 +z,
## 1 -z, 2 +x, 3 -x of its box; `end` which end it looks from; `back` m short of that end,
## `off` m off the wall).
func room_view(type: String, wall: int, end: int, back: float, off: float) -> void:
	var st: Node3D = _main.debug_structure_of_type(type)
	if st == null:
		print("ONESUN no ", type)
		return
	var inv := st.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for m in st.find_children("*", "MeshInstance3D", true, false):
		var g := m as MeshInstance3D
		if not g.is_visible_in_tree():
			continue
		var b: AABB = (inv * g.global_transform) * g.get_aabb()
		if b.size.length() > 40.0:
			continue
		box = b if first else box.merge(b)
		first = false
	var lo := box.position
	var hi := box.end
	var ends: Array = [[Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z), Vector3(0, 0, 1)], [Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(0, 0, -1)],
		[Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z), Vector3(1, 0, 0)], [Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), Vector3(-1, 0, 0)]]
	var p0: Vector3 = ends[wall][0]
	var p1: Vector3 = ends[wall][1]
	var out: Vector3 = ends[wall][2]
	var along := (p1 - p0).normalized()
	var from: Vector3 = p0 if end == 0 else p1
	var dir: Vector3 = along if end == 0 else -along
	var far_end: Vector3 = p1 if end == 0 else p0
	var at: Vector3 = from - dir * back + out * off + Vector3(0, lo.y + 1.6, 0)
	var look: Vector3 = far_end + Vector3(0, lo.y + 1.5, 0)
	_camp_eye(st.global_transform * at, st.global_transform * look)


func _camp_eye(at: Vector3, look: Vector3) -> Camera3D:
	var eye := _main.get("_player").get("_camera") as Camera3D
	var cam := Camera3D.new()
	(_main.get("_world_3d") as Node3D).add_child(cam)
	cam.fov = eye.fov
	cam.near = eye.near
	cam.far = eye.far
	cam.cull_mask = eye.cull_mask
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	var old = _main.get("debug_camera")
	if old != null and is_instance_valid(old):
		old.queue_free()
	_main.set("debug_camera", cam)
	cam.current = true
	return cam


## What the reception's panes and curtains are now.
func rec_state(tag: String) -> void:
	var bi = _bi()
	var cache: Dictionary = bi.get("_glass_cache")
	var out := []
	for k in cache:
		var g = cache[k]
		if g is MeshInstance3D and is_instance_valid(g):
			var mo := (g as MeshInstance3D).material_override
			out.append("%s vis=%s L=%d over=%s" % [k, str((g as MeshInstance3D).is_visible_in_tree()), (g as MeshInstance3D).layers, mo.get_class() if mo != null else "-"])
	print("ONESUN %s panes %s room_vis=%s open=%s hour=%.2f" % [tag, str(out), str((bi.get("_room_root") as Node3D).is_visible_in_tree()), str(bi.visible), float(bi.call("_hour_now"))])
	for n in ["_curtains_open", "_office_curtain", "_side_curtain", "_office_lights_on", "_desk_lamp_on", "_inview_live"]:
		print("ONESUN %s   %s = %s" % [tag, n, str(bi.get(n))])


## A step's Vector3 for an eval.
func _v3(v: Vector3) -> String:
	return "Vector3(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]


## The camp's eye at `at`, looking at `look`, both in the reception's own space (front +Z),
## with the player's lens. `shot`: what the walls and openings are on the screen in that shot
## goes in views.json (room_diff.py counts only the walls: nothing of the room may be on them).
func rec_cam_at(at: Vector3, look: Vector3, shot := "") -> void:
	var shell: Node3D = _bi().call("_reception_shell")
	var cam := _camp_eye(shell.global_transform * at, shell.global_transform * look)
	if shot != "":
		_rec_views[shot] = _rec_polys(cam, shell)


var _rec_views := {}


func rec_views_save() -> void:
	var f := FileAccess.open(_out_dir + "/views.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_rec_views))
	f.close()


## The reception's walls that face the eye and its openings as parts of the screen.
func _rec_polys(cam: Camera3D, shell: Node3D) -> Dictionary:
	var b: Rect2 = RL.local_bounds()
	var x0 := b.position.x - 0.12
	var x1 := b.end.x + 0.12
	var z0 := b.position.y - 0.12
	var z1 := b.end.y + 0.12
	var h := float(RL.WALL_H)
	var lo := 0.25
	var walls := [
		[Vector3(0, 0, 1), [Vector3(x0, lo, z1), Vector3(x1, lo, z1), Vector3(x1, h, z1), Vector3(x0, h, z1)]],
		[Vector3(0, 0, -1), [Vector3(x0, lo, z0), Vector3(x1, lo, z0), Vector3(x1, h, z0), Vector3(x0, h, z0)]],
		[Vector3(1, 0, 0), [Vector3(x1, lo, z0), Vector3(x1, lo, z1), Vector3(x1, h, z1), Vector3(x1, h, z0)]],
		[Vector3(-1, 0, 0), [Vector3(x0, lo, z0), Vector3(x0, lo, z1), Vector3(x0, h, z1), Vector3(x0, h, z0)]]]
	var eye: Vector3 = shell.global_transform.affine_inverse() * cam.global_position
	var out := {"walls": [], "holes": []}
	for w in walls:
		if (w[0] as Vector3).dot(eye - (w[1] as Array)[0]) > 0.0:
			out["walls"].append(_rec_poly(cam, shell, w[1]))
	var d0: Vector3 = RL.local(Vector3(RL.DOOR_X.x, 0, -2.55))
	var d1: Vector3 = RL.local(Vector3(RL.DOOR_X.y, 0, -2.55))
	var holes: Array = [[Vector3(d0.x, 0, z1), Vector3(d1.x, 0, z1), Vector3(d1.x, RL.DOOR_H, z1), Vector3(d0.x, RL.DOOR_H, z1)]]
	# (The walls' holes are the frames' size, a little over the glass.)
	var c: Vector3 = RL.local(RL.OFFICE_WINDOW_CENTER)
	var s: Vector2 = RL.OFFICE_WINDOW_SIZE * 0.5 + Vector2(0.1, 0.1)
	holes.append([Vector3(c.x - s.x, c.y - s.y, z1), Vector3(c.x + s.x, c.y - s.y, z1), Vector3(c.x + s.x, c.y + s.y, z1), Vector3(c.x - s.x, c.y + s.y, z1)])
	c = RL.local(RL.SIDE_WINDOW_CENTER)
	s = RL.SIDE_WINDOW_SIZE * 0.5 + Vector2(0.1, 0.1)
	holes.append([Vector3(x0, c.y - s.y, c.z - s.x), Vector3(x0, c.y - s.y, c.z + s.x), Vector3(x0, c.y + s.y, c.z + s.x), Vector3(x0, c.y + s.y, c.z - s.x)])
	c = RL.local(RL.BACK_WINDOW_CENTER)
	s = RL.BACK_WINDOW_SIZE * 0.5 + Vector2(0.1, 0.1)
	holes.append([Vector3(x1, c.y - s.y, c.z - s.x), Vector3(x1, c.y - s.y, c.z + s.x), Vector3(x1, c.y + s.y, c.z + s.x), Vector3(x1, c.y + s.y, c.z - s.x)])
	for p in holes:
		out["holes"].append(_rec_poly(cam, shell, p))
	return out


## A polygon of the building's space cut at the eye's near plane, as shares of the screen.
func _rec_poly(cam: Camera3D, shell: Node3D, pts: Array) -> Array:
	var inv := cam.global_transform.affine_inverse()
	var cut: Array = []
	for i in pts.size():
		var a: Vector3 = inv * (shell.global_transform * (pts[i] as Vector3))
		var b: Vector3 = inv * (shell.global_transform * (pts[(i + 1) % pts.size()] as Vector3))
		if a.z < -0.2:
			cut.append(a)
		if (a.z < -0.2) != (b.z < -0.2):
			cut.append(a.lerp(b, (-0.2 - a.z) / (b.z - a.z)))
	var size := cam.get_viewport().get_visible_rect().size
	var out: Array = []
	for p in cut:
		var sp := cam.unproject_position(cam.global_transform * (p as Vector3))
		out.append([sp.x / size.x, sp.y / size.y])
	return out


## What a ray through the picture's pixel `px` (of 1280 x 720) meets, nearest first, by box.
func ray_list(tag: String, px: Vector2) -> void:
	var cam := _main.get("debug_camera") as Camera3D
	if cam == null:
		cam = get_viewport().get_camera_3d()
	var size := cam.get_viewport().get_visible_rect().size
	var at := Vector2(px.x / 1280.0, px.y / 720.0) * size
	var o := cam.project_ray_origin(at)
	var d := cam.project_ray_normal(at)
	var hits: Array = []
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_inside_tree() or not g.is_visible_in_tree():
			continue
		var b: AABB = g.global_transform * g.get_aabb()
		if b.size.length() > 80.0:
			continue
		var h = b.grow(0.005).intersects_ray(o, d)
		if h != null:
			hits.append([o.distance_to(h), g])
	hits.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	print("ONESUN %s ray at %s from %s dir %s" % [tag, str(px), str(o.snapped(Vector3.ONE * 0.01)), str(d.snapped(Vector3.ONE * 0.01))])
	for i in mini(hits.size(), 14):
		var g := hits[i][1] as GeometryInstance3D
		print("ONESUN %s   %.2f m %s L=%d" % [tag, float(hits[i][0]), str(g.get_path()).right(70), g.layers])


## The reception's interior probe on or off (what it does to the walls outside).
func rec_probe_on(on: bool) -> void:
	(_bi().get("_room_probe") as Node3D).visible = on


## The buildings of a part turned by --rot=N quarters.
func _rot() -> int:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--rot="):
			return int(str(a).substr(6))
	return 0


## The new Jednota's rack, stock and books now (a line).
func jed_state(tag: String) -> void:
	var j := get_tree().get_first_node_in_group("jednotas")
	var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
	var found := false
	for key in sites:
		var rec: Dictionary = sites[key]
		if str(rec.get("kind", "")) != "vecerka":
			continue
		found = true
		var stock := 0
		for g in rec.get("stock", {}):
			stock += int(rec["stock"][g])
		var kept = rec.get("jednota", null)
		var kept_sum := -1
		if kept is Dictionary and kept.has("shelf"):
			kept_sum = 0
			for g in kept["shelf"]:
				kept_sum += int(kept["shelf"][g])
		print("ONESUN %s jed key=%s stock=%d kept_shelf=%d counts=%s in_sites=%s" % [tag, str(key), stock, kept_sum, str(j.debug_counts(key)) if j != null else "-", str(j.get("_sites").has(key)) if j != null else "-"])
	if not found:
		print("ONESUN %s jed no record (jednotas node: %s)" % [tag, str(j != null)])


## The shelves station as the shop has it now: made, shown, its goods standing (a line).
func jed_rack(tag: String) -> void:
	var si = _main.get("_interior_manager").get("_service_interior")
	var sts: Dictionary = si.get("_stations")
	var st = sts.get("shelves", null)
	if st == null or not is_instance_valid(st):
		print("ONESUN %s rack: no station (stations %s, key %s)" % [tag, str(sts.keys()), str(si.get("_upkeep_key"))])
		return
	var shown := 0
	var units: Dictionary = st.get("_units")
	var one: Sprite3D = null
	for g in units:
		for sp in units[g]:
			if (sp as Sprite3D).is_visible_in_tree():
				shown += 1
				one = sp
	print("ONESUN %s rack: station vis=%s open=%s key=%s shown=%d one=%s L=%d cam_mask=%d" % [tag, str((st as Node3D).is_visible_in_tree()), str(st.get("_open")), str(st.get("building_key")), shown,
		str(one.global_position.snapped(Vector3.ONE * 0.01)) if one != null else "-", one.layers if one != null else 0, (si.get("_interior_camera") as Camera3D).cull_mask])
	if one == null:
		return
	var cam := si.get("_interior_camera") as Camera3D
	var o := cam.global_position
	var target := one.global_transform * one.get_aabb().get_center()
	var d := (target - o).normalized()
	var dist := o.distance_to(target)
	var hits: Array = []
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_inside_tree() or not g.is_visible_in_tree():
			continue
		var b: AABB = g.global_transform * g.get_aabb()
		if b.size.length() > 80.0:
			continue
		var h = b.grow(0.01).intersects_ray(o, d)
		if h != null and o.distance_to(h) < dist + 0.3:
			hits.append([o.distance_to(h), g])
	hits.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	print("ONESUN %s rack: eye %s sprite at %.2f m, aabb %s tex %s px %.4f alpha %s" % [tag, str(o.snapped(Vector3.ONE * 0.01)), dist, str(one.get_aabb()), str(one.texture.get_size()) if one.texture != null else "-", one.pixel_size, str(one.modulate)])
	for i in mini(hits.size(), 12):
		var g := hits[i][1] as GeometryInstance3D
		print("ONESUN %s rack:   %.2f m %s L=%d" % [tag, float(hits[i][0]), str(g.get_path()).right(64), g.layers])


## Where the player is, what room is open (one line).
func where(tag: String) -> void:
	var p: Node3D = _main.get("_player")
	var im = _main.get("_interior_manager")
	var open := []
	for k in ["_building_interior", "_cabin_interior", "_tent_interior", "_caravan_interior", "_bowling_interior"]:
		var r = im.get(k)
		if r != null and r.has_method("is_open") and bool(r.call("is_open")):
			open.append(k)
	print("ONESUN %s where player=%s open=%s" % [tag, str(p.global_position.snapped(Vector3.ONE * 0.1)) if p != null else "-", str(open)])


## Out on foot as the rooms' own exits go (interior_manager.leave_on_foot).
func walk_out(kind: String, type: String) -> void:
	var im = _main.get("_interior_manager")
	var st: Node3D = _main.debug_structure_of_type(type)
	var room = im.get("_%s_interior" % kind)
	var close := Callable(room, "close_%s" % kind)
	print("ONESUN walk_out ", kind, " ", type, " -> ", im.leave_on_foot(room, st, close))


func cab_state(tag: String) -> void:
	var ci = _main.get("_interior_manager").get("_cabin_interior")
	var cab: Node3D = _main.debug_structure_of_type("cabin_1")
	var root: Node3D = ci.get("_cabin_root")
	var panes: Array = ci.get("_inview_panes")
	var mats := []
	for p in panes:
		mats.append((p as MeshInstance3D).material_override.get_class() + ("/vis" if (p as MeshInstance3D).is_visible_in_tree() else "/hid"))
	var model_panes := []
	if cab != null:
		for m in cab.find_children("*", "MeshInstance3D", true, false):
			if (m as Node).has_meta("lit_window"):
				var mo := (m as MeshInstance3D).material_override
				var desc := "-"
				if mo is StandardMaterial3D:
					desc = "std a=%.2f tr=%d tex=%s" % [(mo as StandardMaterial3D).albedo_color.a, (mo as StandardMaterial3D).transparency, str((mo as StandardMaterial3D).albedo_texture != null)]
				elif mo != null:
					desc = mo.get_class()
				model_panes.append(str((m as Node).name) + ":" + desc + (" live" if (m as Node).has_meta("inview_live") else "") + (" vis" if (m as MeshInstance3D).is_visible_in_tree() else " hid") + " L%d" % (m as MeshInstance3D).layers)
	print("ONESUN %s cab baking=%s open=%s inview=%s panes=%d %s root_vis=%s root_at=%s cabin_at=%s model_panes=%s cam=%s" % [tag, str(ci.get("_cube_baking")), str(ci.get("_is_open")),
		str(ci.get("_inview_cabin")), panes.size(), str(mats), str(root.visible), str(root.global_position.snapped(Vector3.ONE * 0.1)),
		str(cab.global_position.snapped(Vector3.ONE * 0.1)) if cab != null else "-", str(model_panes), str(ci._camp_camera())])


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


var _dump := 0
var _dump_i := 0


## Every frame for the next `n` frames: the picture (dNNN.png) and the reception's eye.
func dump_frames(n: int) -> void:
	_dump = n


func _process(delta: float) -> void:
	super._process(delta)
	if _main == null:
		return
	if _dump > 0:
		_dump -= 1
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(_out_dir + "/d%03d.png" % _dump_i)
		rec_cam("d%03d" % _dump_i)
		_dump_i += 1
	if _room_hide and _room_node != null:
		_room_node.visible = false
	var bi0 = _bi() if _main.get("_interior_manager") != null else null
	if _green and bi0 != null and bi0.get("_room_probe") != null:
		var pr0 = bi0.get("_room_probe")
		pr0.ambient_color = Color(0.0, 1.0, 0.0)
		pr0.ambient_color_energy = 3.0
	if _nosun:
		(_main.get("sun") as DirectionalLight3D).visible = false
	if _hold.x != INF and bi0 != null and bi0.get("_interior_camera") != null and bi0.visible:
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
		if a == "--part=ratio":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5]]
			for view in [[16.8, 0.0, -25.0, "c168"], [17.5, 150.0, -15.0, "door175"]]:
				st += [["eval", "debug_jump_to(1, %s)" % view[0]], ["wait", 1.5], ["eval", C + ".hold_view(%s, %s)" % [view[1], view[2]]],
					["wait", 0.5], ["shot", "%s_now_sun" % view[3]], ["eval", C + ".nosun(true)"], ["wait", 0.4], ["shot", "%s_now_dark" % view[3]], ["eval", C + ".nosun(false)"]]
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
		if a == "--part=cabins":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
				["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 1.5], ["eval", C + ".rich()"],
				["build", "cabin_2", 14, 3, 0], ["build", "cabin_3", 18, 3, 0], ["build", "cabin_2", 14, 12, 0], ["build", "cabin_3", 18, 12, 0],
				["wait", 2.0], ["eval", C + ".structures()"]]
			for h in [12.0, 22.0]:
				st += [["eval", "debug_jump_to(1, %s)" % h], ["wait", 2.0]]
				for ty in ["cabin_1", "cabin_2", "cabin_3"]:
					for ang in [0.0, 50.0, 140.0, 230.0]:
						st += [["eval", C + ".around('%s', %s, 6.5, 0.2)" % [ty, ang]], ["wait", 0.5], ["shot", "%s_%04d_%03d" % [ty, int(h * 100), int(ang)]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=cabin":
			var CI := "_interior_manager._cabin_interior"
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
				["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 1.5], ["mouse", 0.5, 0.5],
				["eval", "debug_repair_ruined()"], ["wait", 2.0]]
			for h in ([12.0] if "--quick" in OS.get_cmdline_user_args() else [9.0, 12.0, 16.0, 17.5, 22.0]):
				st += [["eval", "debug_jump_to(1, %s)" % h], ["wait", 1.0],
					["eval", CI + ".set_world_anchor(debug_structure_of_type('cabin_1'))"], ["eval", CI + ".open_cabin(1)"], ["wait", 0.5],
					["eval", CI + ".take_curtains([true, true, true, true])"], ["wait", 1.0], ["mouse", 0.5, 0.5]]
				for v in [[0.0, -8.0, "c"], [72.0, -5.0, "l"], [-72.0, -5.0, "r"], [0.0, -30.0, "d"], [150.0, -10.0, "b"]]:
					st += [["eval", CI + "._look.set('yaw_deg', %s)" % v[0]], ["eval", CI + "._look.set('pitch_deg', %s)" % v[1]], ["wait", 0.6], ["shot", "in%04d_%s" % [int(h * 100), v[2]]]]
				st += [["eval", CI + ".close_cabin()"], ["wait", 0.6], ["eval", C + ".around('cabin_1', 0.0, 3.2, 0.2)"], ["wait", 0.3], ["eval", CI + ".take_curtains([true, true, true, true])"], ["wait", 1.0]]
				for ang in [0.0, 30.0, 90.0, 180.0]:
					st += [["eval", C + ".around('cabin_1', %s, 3.2, 0.2)" % ang], ["wait", 0.8], ["shot", "out%04d_%03d" % [int(h * 100), int(ang)]], ["eval", C + ".cab_state('%s_%s')" % [h, ang]]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=perf":
			var CI := "_interior_manager._cabin_interior"
			_steps = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 2.0], ["eval", C + ".vp_info('in_reception')"],
				["eval", "_interior_manager._cabin_interior._viewport.set('render_target_update_mode', 0)"], ["wait", 2.0], ["eval", C + ".vp_info('in_reception_no_cabin_vp')"],
				["eval", "_sub_viewport_container.get_child(0).set('render_target_update_mode', 0)"], ["wait", 2.0], ["eval", C + ".vp_info('in_reception_no_camp_vp')"],
				["eval", "_sub_viewport_container.get_child(0).set('render_target_update_mode', 3)"], ["eval", "_interior_manager._cabin_interior._viewport.set('render_target_update_mode', 3)"],
				["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 2.0], ["eval", C + ".vp_info('outside')"],
				["eval", "debug_repair_ruined()"], ["wait", 1.0],
				["eval", CI + ".set_world_anchor(debug_structure_of_type('cabin_1'))"], ["eval", CI + ".open_cabin(1)"], ["wait", 2.0], ["eval", C + ".vp_info('in_cabin')"],
				["eval", "get_tree().quit()"]]
			return
		if a == "--part=bowl":
			var BI := "_interior_manager._bowling_interior"
			_steps = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"],
				["money", 40000], ["clear", 4, 4, 16, 12], ["build", "bowling", 6, 5, 0], ["wait", 2.0],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('bowling'))"], ["wait", 3.0],
				["shot", "w0_in"], ["eval", C + ".bowl_state('in')"],
				["eval", BI + "._switch_station('cellar')"], ["wait", 2.5], ["shot", "w1_cellar"], ["eval", C + ".bowl_state('cellar')"],
				["eval", C + ".env_state('cellar')"], ["eval", C + ".cellar_meshes('cellar')"],
				["eval", "_world_3d.get_world_3d().environment.set('fog_enabled', false)"], ["wait", 0.3], ["shot", "w2_cellar_no_fog"],
				["eval", BI + "._interior_camera.set('rotation_degrees', Vector3(0, 0, 0))"], ["wait", 0.3], ["shot", "w3_cellar_back"],
				["eval", BI + "._interior_camera.set('rotation_degrees', Vector3(0, 180, 0))"], ["wait", 0.3], ["shot", "w4_cellar_front"],
				["eval", "get_tree().quit()"]]
			return
		if a == "--part=tents":
			var TI := "_interior_manager._tent_interior"
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"],
				["money", 40000], ["clear", 12, 10, 8, 5], ["build", "tent_1", 13, 12, 0], ["wait", 1.0], ["eval", C + ".tents()"], ["wait", 2.0],
				["eval", "debug_jump_to(1, 13.0)"], ["wait", 1.5]]
			for ty in ["tent_1", "tent_2", "tent_3"]:
				st += [["eval", C + ".around('%s', 20.0, 5.0, 0.4)" % ty], ["wait", 0.6], ["shot", "a_%s_closed" % ty]]
				st += [["eval", C + ".tent_door('%s', true)" % ty], ["wait", 1.0], ["eval", C + ".around('%s', 0.0, 3.2, -0.2)" % ty], ["wait", 1.2], ["shot", "b_%s_open" % ty],
					["eval", C + ".around('%s', 160.0, 4.0, 0.3)" % ty], ["wait", 0.6], ["shot", "c_%s_back" % ty]]
			st += [["eval", "set('debug_camera', null)"], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('tent_1'))"], ["wait", 4.0], ["mouse", 0.5, 0.5]]
			for v in [[0.0, -7.5, "c"], [48.0, 0.0, "l"], [-48.0, 0.0, "r"], [178.0, 0.0, "door"]]:
				st += [["eval", TI + "._look.set('yaw_deg', %s)" % v[0]], ["eval", TI + "._look.set('pitch_deg', %s)" % v[1]], ["wait", 0.7], ["shot", "d_in_%s" % v[2]]]
			st += [["eval", "debug_jump_to(1, 22.0)"], ["wait", 1.5], ["eval", TI + "._look.set('yaw_deg', 0.0)"], ["wait", 0.7], ["shot", "e_night_in"],
				["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=cubes":
			_steps = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 8.0],
				["eval", C + ".save_cubes()"], ["eval", "get_tree().quit()"]]
			return
		if a == "--part=van":
			var VI := "_interior_manager._caravan_interior"
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"],
				["money", 40000], ["clear", 12, 10, 8, 5], ["build", "caravan_1", 13, 12, 0], ["wait", 2.0],
				["eval", "debug_jump_to(1, 12.5)"], ["wait", 2.0]]
			for ang in [0.0, 30.0, 180.0, 90.0]:
				st += [["eval", C + ".around('caravan_1', %s, 3.6, 0.2)" % ang], ["wait", 1.0], ["shot", "a_out_%03d" % int(ang)]]
			st += [["eval", "set('debug_camera', null)"], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('caravan_1'))"], ["wait", 5.0], ["mouse", 0.5, 0.5]]
			for v in [[0.0, -8.0, "c"], [70.0, -5.0, "l"], [-70.0, -5.0, "r"], [150.0, -5.0, "b"]]:
				st += [["eval", VI + "._look.set('yaw_deg', %s)" % v[0]], ["eval", VI + "._look.set('pitch_deg', %s)" % v[1]], ["wait", 0.7], ["shot", "b_in_%s" % v[2]]]
			st += [["eval", "debug_jump_to(1, 22.0)"], ["wait", 1.5], ["eval", VI + "._look.set('yaw_deg', 0.0)"], ["wait", 0.7], ["shot", "c_night_in"],
				["eval", VI + ".close_caravan()"], ["wait", 1.0], ["eval", C + ".around('caravan_1', 0.0, 3.6, 0.2)"], ["wait", 1.2], ["shot", "d_night_out"],
				["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=walks":
			var IM := "_interior_manager."
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
				["money", 400000],
				["clear", 5, 4, 5, 7], ["build", "bowling", 6, 5, 0], ["wait", 0.5],
				["clear", 12, 11, 7, 3], ["build", "tent_1", 13, 12, 0], ["wait", 0.5], ["eval", C + ".tents()"],
				["clear", 12, 14, 4, 3], ["build", "caravan_1", 13, 15, 0], ["wait", 1.0],
				["eval", "debug_repair_ruined()"], ["eval", "debug_jump_to(1, 13.0)"], ["wait", 3.0], ["eval", C + ".structures()"]]
			var rooms := [["main_building", "_building_interior", "close_interior", 2.0], ["cabin_1", "_cabin_interior", "close_cabin", 1.6],
				["tent_1", "_tent_interior", "close_tent", 1.4], ["tent_3", "_tent_interior", "close_tent", 1.4],
				["caravan_1", "_caravan_interior", "close_caravan", 1.6], ["bowling", "_bowling_interior", "close_bowling", 2.0]]
			var only := ""
			for a2 in OS.get_cmdline_user_args():
				if str(a2).begins_with("--rooms="):
					only = str(a2).substr(8)
			for rr in rooms:
				var ty: String = rr[0]
				if only != "" and not ty in only.split(","):
					continue
				st += [["eval", "set('debug_camera', null)"], ["door_front", ty, rr[3]], ["wait", 0.6], ["eval", C + ".where('%s_at')" % ty], ["shot", "%s_0_at" % ty],
					["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('%s'))" % ty]]
				for k in 16:
					st += [["wait", 0.15], ["shot", "%s_1_in_%02d" % [ty, k]]]
				st += [["wait", 1.5], ["eval", C + ".where('%s_in')" % ty], ["shot", "%s_2_inside" % ty],
					["eval", IM + rr[1] + "._look.set('yaw_deg', 178.0)"], ["wait", 0.9], ["shot", "%s_3_door_from_inside" % ty],
					["eval", IM + rr[1] + "._look.set('yaw_deg', 0.0)"], ["wait", 0.5],
					["eval", {"main_building": "_interior_manager._building_interior._extras.handle_exit()", "caravan_1": "_interior_manager._caravan_interior.walk_out()"}.get(ty, C + ".walk_out2('%s', '%s', '%s')" % [rr[1], rr[2], ty])]]
				for k in 14:
					st += [["wait", 0.15], ["shot", "%s_4_out_%02d" % [ty, k]]]
				st += [["wait", 2.0], ["eval", C + ".where('%s_out')" % ty], ["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 0.5],
					["eval", C + ".around('%s', 25.0, %s, 0.3)" % [ty, 16.0 if ty == "bowling" else 7.0]], ["wait", 0.8], ["shot", "%s_5_ext" % ty],
					["eval", C + ".around('%s', 0.0, %s, 0.0)" % [ty, 11.5 if ty == "bowling" else 3.0]], ["wait", 0.8], ["shot", "%s_6_ext_door" % ty]]
			st += [["eval", "set('debug_camera', null)"], ["wait", 1.0], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=unpair":
			# What is built before the quit (--build=bowling,tents,caravan,cabin_walk): which of
			# them leaves "BUG, indexing did not unpair geometries from light" at exit.
			var b := ""
			for a2 in OS.get_cmdline_user_args():
				if str(a2).begins_with("--build="):
					b = str(a2).substr(8)
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["money", 400000]]
			if "bowling" in b:
				st += [["clear", 5, 4, 5, 7], ["build", "bowling", 6, 5, 0], ["wait", 0.5]]
			if "tents" in b:
				st += [["clear", 12, 11, 7, 3], ["build", "tent_1", 13, 12, 0], ["wait", 0.5], ["eval", C + ".tents()"]]
			if "caravan" in b:
				st += [["clear", 12, 14, 4, 3], ["build", "caravan_1", 13, 15, 0]]
			st += [["eval", "debug_jump_to(1, 13.0)"], ["wait", 3.0]]
			if "cabin_walk" in b:
				st += [["eval", "debug_repair_ruined()"], ["door_front", "cabin_1", 1.6], ["wait", 0.5],
					["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('cabin_1'))"], ["wait", 4.0],
					["eval", C + ".walk_out2('_cabin_interior', 'close_cabin', 'cabin_1')"], ["wait", 4.0]]
			if "tent_walk" in b:
				st += [["door_front", "tent_1", 1.4], ["wait", 0.5],
					["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('tent_1'))"], ["wait", 4.0],
					["eval", C + ".walk_out2('_tent_interior', 'close_tent', 'tent_1')"], ["wait", 4.0]]
			st += [["wait", 2.0], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=recdoor":
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 13.0)"], ["wait", 2.0],
				["door_front", "main_building", 2.0], ["wait", 0.6], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('main_building'))"],
				["eval", C + ".dump_frames(90)"]]
			for k in 0:
				st += [["wait", 0.03], ["eval", C + ".rec_cam('f%02d')" % k], ["shot", "f%02d" % k]]
			st += [["wait", 2.0], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=rainin":
			# Rain, in by the front door (the lobby, the office, the back room), then the cabin's
			# room and the reception from round the back (X1, X2 of 5. 11.).
			var BI := "_interior_manager._building_interior"
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", BI + ".close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 0.5],
				["eval", "weather_system.set_weather(4)"], ["eval", "_set_weather_state(4)"], ["wait", 30.0],
				["door_front", "main_building", 2.0], ["wait", 0.6], ["shot", "a_at_door"],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('main_building'))"], ["wait", 4.0], ["mouse", 0.5, 0.5]]
			for v in [[0.0, -10.0, "b_office"], [90.0, -10.0, "b_office_l"], [-90.0, -10.0, "b_office_r"], [180.0, -10.0, "b_office_back"]]:
				st += [["eval", C + ".hold_view(%s, %s)" % [v[0], v[1]]], ["wait", 0.6], ["shot", v[2]]]
			st += [["eval", C + ".hold_view(INF, INF)"], ["eval", BI + "._extras.go_back_room()"], ["wait", 3.0], ["shot", "c_back_room"]]
			for v in [[0.0, -10.0, "c_back_0"], [90.0, -10.0, "c_back_90"], [180.0, -10.0, "c_back_180"], [-90.0, -10.0, "c_back_270"]]:
				st += [["eval", C + ".hold_view(%s, %s)" % [v[0], v[1]]], ["wait", 0.6], ["shot", v[2]]]
			st += [["eval", C + ".hold_view(INF, INF)"], ["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 2.0]]
			for ang in [90.0, 135.0, 180.0, 225.0, 270.0]:
				st += [["eval", C + ".around('main_building', %s, 9.0, 0.5)" % ang], ["wait", 0.7], ["shot", "d_rec_%03d" % int(ang)]]
			st += [["eval", "set('debug_camera', null)"], ["eval", "debug_repair_ruined()"], ["door_front", "cabin_1", 1.6], ["wait", 0.5],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('cabin_1'))"], ["wait", 4.0], ["mouse", 0.5, 0.5]]
			st += [["eval", C + ".dry_state('cabin')"]]
			for v in [[0.0, -15.0, "e_cab_c"], [70.0, -15.0, "e_cab_l"], [-70.0, -15.0, "e_cab_r"]]:
				st += [["eval", "_interior_manager._cabin_interior._look.set('yaw_deg', %s)" % v[0]], ["eval", "_interior_manager._cabin_interior._look.set('pitch_deg', %s)" % v[1]], ["wait", 0.6], ["shot", v[2]]]
			for k in 8:
				st += [["wait", 0.11], ["shot", "f_cab_%d" % k]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=recround":
			# The reception from all round in a clear noon, near and further (X2 of 5. 11.: the
			# back room's inside seen through its outer walls).
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 2.0]]
			st += [["eval", C + ".rec_poke('noon')"]]
			for d in [5.5, 8.0]:
				for ang in range(0, 360, 30):
					st += [["eval", C + ".around('main_building', %s, %s, 0.4)" % [ang, d]], ["wait", 0.5], ["shot", "r%02d_%03d" % [int(d), ang]]]
			st += [["eval", "set('debug_camera', null)"], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=keys":
			# The keys on the reception's wall off the counter, at it, off it again (X4 of 5. 11.).
			var BI := "_interior_manager._building_interior"
			var board := "Vector3(2.462, 1.52, 0.435)"
			_steps = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 3.0],
				["eval", BI + "._exit_crt_view()"], ["wait", 2.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.0], ["mouse", 0.5, 0.5],
				["eval", C + ".rec_face(%s)" % board], ["wait", 1.5], ["shot", "k0_board"],
				["eval", BI + "._desk_room._step_up()"], ["wait", 1.5], ["shot", "k1_desk"],
				["eval", BI + "._desk_room._step_down()"], ["wait", 1.5],
				["eval", C + ".rec_face(%s)" % board], ["wait", 1.5], ["shot", "k2_board_after"],
				["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 1.0],
				["glass", "side_glass", 1.4], ["wait", 1.0], ["shot", "k3_from_outside"],
				["eval", "get_tree().quit()"]]
			return
		if a == "--part=bizwalks":
			# The businesses in the camp's one world: in by the door, round the room, into the
			# room behind it and back, out by the door, from outside (W26).
			var SI := "_interior_manager._service_interior"
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
				["money", 400000], ["clear", 4, 9, 5, 5], ["clear", 9, 9, 5, 5], ["clear", 9, 14, 5, 5],
				["build", "pub", 5, 10, _rot()], ["build", "restaurant", 10, 10, _rot()], ["build", "vecerka", 10, 15, _rot()], ["wait", 2.0],
				["clear", 4, 14, 5, 5], ["build", "staffroom", 5, 15, _rot()], ["wait", 1.0],
				["eval", "debug_jump_to(1, 12.0)"], ["wait", 3.0], ["eval", C + ".structures()"]]
			var only := ""
			for a2 in OS.get_cmdline_user_args():
				if str(a2).begins_with("--rooms="):
					only = str(a2).substr(8)
			for rr in [["pub", "p_cellar", "pc_main"], ["restaurant", "d_kitchen", "k_dining"], ["vecerka", "s_store", "st_shop"], ["staffroom", "", ""]]:
				var ty: String = rr[0]
				if only != "" and not ty in only.split(","):
					continue
				st += [["eval", "set('debug_camera', null)"], ["eval", C + ".around('%s', 0.0, 9.0, 0.3)" % ty], ["wait", 0.8], ["shot", "%s_0_ext" % ty],
					["eval", "set('debug_camera', null)"], ["door_front", ty, 2.0], ["wait", 0.6], ["shot", "%s_1_at" % ty],
					["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('%s'))" % ty]]
				for k in 14:
					st += [["wait", 0.15], ["shot", "%s_2_in_%02d" % [ty, k]]]
				st += [["wait", 1.5], ["mouse", 0.5, 0.5], ["shot", "%s_3_inside" % ty]]
				for v in [[60.0, "l"], [-60.0, "r"], [175.0, "door"]]:
					st += [["eval", SI + "._look.set('yaw_deg', %s)" % v[0]], ["wait", 0.7], ["shot", "%s_4_look_%s" % [ty, v[1]]]]
				st += [["eval", SI + "._look.set('yaw_deg', 0.0)"], ["wait", 0.4],
					["eval", (SI + "._go_door('%s')" % rr[1]) if rr[1] != "" else SI + "._staff_room.walk_to('boiler')"], ["wait", 3.0], ["shot", "%s_5_back_room" % ty],
					["eval", (SI + "._go_door('%s')" % rr[2]) if rr[2] != "" else SI + "._staff_room.walk_to('lounge')"], ["wait", 3.0], ["shot", "%s_6_front_again" % ty],
					["eval", SI + "._leave_on_foot()"]]
				for k in 12:
					st += [["wait", 0.15], ["shot", "%s_7_out_%02d" % [ty, k]]]
				st += [["wait", 2.0], ["eval", "_interior_manager.close_service_if_open()" if false else "set('debug_camera', null)"],
					["eval", C + ".around('%s', 20.0, 7.5, 0.3)" % ty], ["wait", 0.8], ["shot", "%s_8_ext_after" % ty]]
			st += [["eval", "set('debug_camera', null)"], ["wait", 1.0], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=recdiff":
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 2.0]]
			for h in [0.3, 3.5]:
				for d in [6.5, 12.0, 25.0, 50.0]:
					for ang in range(0, 360, 30):
						var n := "%02d_%03d_%03d" % [int(h * 10.0), int(d), ang]
						st += [["eval", C + ".around('main_building', %s, %s, %s)" % [ang, d, h]], ["wait", 0.25], ["shot", "a_" + n],
							["eval", C + ".rec_room(false)"], ["wait", 0.12], ["shot", "b_" + n], ["eval", C + ".rec_room(true)"], ["wait", 0.05]]
			st += [["eval", "set('debug_camera', null)"], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=rechis":
			# Somebody's own last camp (copied into this run's APPDATA with their settings.cfg),
			# as it was left: the reception from where they stood, then at each window.
			var st: Array = [["wait_menu"], ["call", "_on_menu_continue_pressed", []], ["wait_gameplay"], ["wait", 3.0], ["shot", "h0_as_left"],
				["eval", C + ".rec_state('loaded')"], ["eval", C + ".structures()"]]
			for pane in ["office_glass", "side_glass", "back_glass"]:
				for d in [1.2, 3.5, 9.0, 16.0]:
					st += [["glass", pane, d], ["wait", 0.5], ["shot", "h1_%s_%02d" % [pane.substr(0, 4), int(d)]]]
			# Whatever else stands in it, with its windows, as it was left.
			for ty in ["cabin_1", "cabin_2", "cabin_3", "caravan_1", "caravan_2", "caravan_3", "tent_1", "tent_2", "tent_3", "pub", "restaurant", "vecerka", "bowling", "staffroom"]:
				for ang in [0.0, 120.0, 240.0]:
					st += [["eval", C + ".around('%s', %s, 7.0, 0.3)" % [ty, ang]], ["wait", 0.5], ["shot", "h2_%s_%03d" % [ty, int(ang)]]]
			st += [["eval", C + ".rec_state('after')"], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=recwin":
			# Into the reception through its windows from outside, out of it on foot as a player
			# goes (the user 6. 11.: "you cannot see in through the windows"), by the hour.
			var BI := "_interior_manager._building_interior"
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 3.0],
				["eval", BI + "._exit_crt_view()"], ["wait", 2.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.0],
				["eval", BI + "._extras.go_back_room()"], ["wait", 3.0], ["eval", BI + "._extras.go_office()"], ["wait", 3.0],
				["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 2.0]]
			for hour in [12.0, 17.0, 19.6, 21.0, 0.5]:
				var day := 1 if hour > 1.0 else 2
				st += [["eval", "debug_jump_to(%d, %s)" % [day, hour]], ["wait", 2.0]]
				for pane in ["office_glass", "side_glass", "back_glass"]:
					for d in [1.2, 3.5, 9.0, 22.0]:
						st += [["glass", pane, d], ["wait", 0.4], ["shot", "w_%02d_%s_%02d" % [int(hour), pane.substr(0, 4), int(d)]]]
				st += [["eval", C + ".lights_near('h%02d')" % int(hour)]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=roomsgraze":
			# Every other building a room stands in, seen along its walls, with its room and
			# without (the reception's --part=recgraze): python tools/room_diff.py DIR <type>_
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
				["money", 900000], ["clear", 4, 9, 5, 5], ["clear", 9, 9, 5, 5], ["clear", 9, 14, 5, 5],
				["build", "pub", 5, 10, 0], ["build", "restaurant", 10, 10, 0], ["build", "vecerka", 10, 15, 0], ["wait", 2.0],
				["clear", 4, 14, 5, 5], ["build", "staffroom", 5, 15, 0], ["wait", 1.0],
				["clear", 15, 9, 10, 9], ["build", "tent_1", 16, 11, 0], ["build", "caravan_1", 20, 11, 0], ["wait", 1.0],
				["eval", "debug_repair_ruined()"], ["wait", 2.0],
				["eval", "debug_jump_to(1, 12.0)"], ["wait", 3.0], ["eval", C + ".structures()"]]
			var only := ""
			for a2 in OS.get_cmdline_user_args():
				if str(a2).begins_with("--rooms="):
					only = str(a2).substr(8)
			var from_tier := {"cabin_2": "cabin_1", "cabin_3": "cabin_2", "caravan_2": "caravan_1", "caravan_3": "caravan_2", "tent_2": "tent_1", "tent_3": "tent_2"}
			for ty in ["cabin_1", "cabin_2", "cabin_3", "caravan_1", "caravan_2", "caravan_3", "tent_1", "tent_2", "tent_3", "pub", "restaurant", "vecerka", "staffroom"]:
				if from_tier.has(ty):
					st += [["eval", C + ".tier_up('%s', '%s')" % [from_tier[ty], ty]], ["wait", 2.0]]
				if only != "" and not ty in only.split(","):
					continue
				st += [["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.5], ["eval", C + ".room_target('%s')" % ty]]
				for wall in 4:
					for end in 2:
						for back in [1.0, 6.0]:
							for off in [0.6, 2.5]:
								var n := "%s_%d_%d_%d_%d" % [ty, wall, end, int(back), int(off * 10.0)]
								st += [["eval", C + ".room_view('%s', %d, %d, %s, %s)" % [ty, wall, end, back, off]], ["wait", 0.45], ["shot", "a_" + n],
									["eval", C + ".room_hidden(true)"], ["wait", 0.12], ["shot", "b_" + n], ["eval", C + ".room_hidden(false)"], ["wait", 0.05]]
			st += [["eval", "set('debug_camera', null)"], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=recwalk":
			# Along every wall at a walking pace, close and a little off, a pair every half a
			# metre: the wall seen slide by as you go.
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 7.0]]
			var hx := 4.25
			var fz := 2.72
			var bz := -2.78
			for w in [["front", Vector3(-hx, 0, fz), Vector3(hx, 0, fz), Vector3(0, 0, 1)], ["back", Vector3(-hx, 0, bz), Vector3(hx, 0, bz), Vector3(0, 0, -1)],
					["east", Vector3(hx, 0, bz), Vector3(hx, 0, fz), Vector3(1, 0, 0)], ["west", Vector3(-hx, 0, bz), Vector3(-hx, 0, fz), Vector3(-1, 0, 0)]]:
				var p0: Vector3 = w[1]
				var p1: Vector3 = w[2]
				var out: Vector3 = w[3]
				var along := (p1 - p0).normalized()
				var length := p0.distance_to(p1)
				for off in [1.1, 2.6]:
					for k in 14:
						var at: Vector3 = p0 - along * 3.0 + along * (length + 6.0) * float(k) / 13.0 + out * off + Vector3(0, 1.6, 0)
						var look: Vector3 = at + along * 6.0 - out * off * 0.9
						look.y = 1.5
						var n := "%s_%02d_%02d" % [w[0], int(off * 10.0), k]
						st += [["eval", C + ".rec_cam_at(%s, %s, '%s')" % [_v3(at), _v3(look), n]], ["wait", 0.2], ["shot", "a_" + n],
							["eval", C + ".rec_room(false)"], ["wait", 0.1], ["shot", "b_" + n], ["eval", C + ".rec_room(true)"], ["wait", 0.04]]
			st += [["eval", C + ".rec_views_save()"], ["eval", "set('debug_camera', null)"], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=recgraze":
			# The reception from along its walls, as you walk by it (the user 6. 11.: the back
			# room's textures seen from outside; --part=recdiff only ever looked straight at
			# it): pairs with and without the room, tools/room_diff.py compares them.
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 2.0]]
			var hx := 4.25
			var fz := 2.72
			var bz := -2.78
			# Each wall: a line along it, `s` the side it faces.
			for w in [["front", Vector3(-hx, 0, fz), Vector3(hx, 0, fz), Vector3(0, 0, 1)], ["back", Vector3(-hx, 0, bz), Vector3(hx, 0, bz), Vector3(0, 0, -1)],
					["east", Vector3(hx, 0, bz), Vector3(hx, 0, fz), Vector3(1, 0, 0)], ["west", Vector3(-hx, 0, bz), Vector3(-hx, 0, fz), Vector3(-1, 0, 0)]]:
				var p0: Vector3 = w[1]
				var p1: Vector3 = w[2]
				var out: Vector3 = w[3]
				var along := (p1 - p0).normalized()
				for end in [0, 1]:
					var from: Vector3 = p0 - along * 1.0 if end == 0 else p1 + along * 1.0
					var dir := along if end == 0 else -along
					var far_end: Vector3 = p1 if end == 0 else p0
					for back in [0.0, 3.0, 8.0, 18.0, 40.0]:
						for off in [0.25, 0.7, 1.6, 3.5]:
							var at: Vector3 = from - dir * back + out * off + Vector3(0, 1.6, 0)
							var look: Vector3 = far_end + Vector3(0, 1.5, 0)
							var n := "%s_%d_%02d_%02d" % [w[0], end, int(back), int(off * 10.0)]
							st += [["eval", C + ".rec_cam_at(%s, %s, '%s')" % [_v3(at), _v3(look), n]], ["wait", 0.2], ["shot", "a_" + n],
								["eval", C + ".rec_room(false)"], ["wait", 0.1], ["shot", "b_" + n], ["eval", C + ".rec_room(true)"], ["wait", 0.04]]
			st += [["eval", C + ".rec_views_save()"], ["eval", "set('debug_camera', null)"], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=recray":
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 2.0],
				["eval", C + ".around('main_building', 180, 6.5, 0.3)"], ["wait", 0.6], ["shot", "a_room"],
				["eval", C + ".ray_list('sliver', Vector2(472, 460))"],
				["eval", C + ".rec_probe_on(false)"], ["wait", 0.3], ["shot", "b_no_probe"], ["eval", C + ".rec_probe_on(true)"], ["wait", 0.2],
				["eval", C + ".rec_room(false)"], ["wait", 0.3], ["shot", "c_no_room"], ["eval", C + ".rec_room(true)"], ["wait", 0.2],
				["eval", "set('debug_camera', null)"], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=bizsun":
			# The camp's sun in the businesses: inside, looking back at the windows and down at
			# the floor, through the day, at a station by day, in rain (W26).
			var SI := "_interior_manager._service_interior"
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
				["money", 400000], ["clear", 4, 9, 5, 5], ["clear", 9, 9, 5, 5], ["clear", 9, 14, 5, 5], ["clear", 4, 14, 5, 5],
				["build", "pub", 5, 10, _rot()], ["build", "restaurant", 10, 10, _rot()], ["build", "vecerka", 10, 15, _rot()], ["build", "staffroom", 5, 15, _rot()], ["wait", 2.0],
				["eval", "debug_jump_to(1, 10.0)"], ["wait", 2.0]]
			for ty in ["pub", "restaurant", "vecerka", "staffroom"]:
				st += [["eval", "set('debug_camera', null)"], ["door_front", ty, 2.0], ["wait", 0.6],
					["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('%s'))" % ty], ["wait", 5.0], ["mouse", 0.5, 0.5]]
				for hr in [9.0, 11.0, 13.0, 15.0, 16.5, 17.5]:
					st += [["eval", "debug_jump_to(1, %s)" % hr], ["wait", 1.5], ["eval", SI + "._look.set('yaw_deg', 178.0)"], ["eval", SI + "._look.set('pitch_deg', -30.0)"], ["wait", 0.8],
						["shot", "%s_%04d" % [ty, int(hr * 100.0)]]]
				st += [["eval", "debug_jump_to(1, 10.0)"], ["wait", 1.0], ["eval", SI + "._look.set('yaw_deg', 0.0)"], ["eval", SI + "._look.set('pitch_deg', 0.0)"], ["wait", 0.8],
					["shot", "%s_ahead" % ty], ["eval", SI + ".close_service()"], ["wait", 1.5]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=jedshelf":
			# A new Jednota's rack from the moment it is built (the shop opens with full shelves).
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
				["money", 400000], ["clear", 9, 14, 5, 5], ["eval", C + ".jed_state('before')"], ["build", "vecerka", 10, 15, 0]]
			for k in 8:
				st += [["wait", 0.5], ["eval", C + ".jed_state('t%d')" % k]]
			st += [["eval", "debug_jump_to(1, 11.0)"], ["wait", 2.0], ["eval", C + ".jed_state('at11')"],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('vecerka'))"], ["wait", 4.0], ["eval", C + ".jed_state('inside')"], ["eval", C + ".jed_rack('inside')"], ["mouse", 0.5, 0.5], ["shot", "a_shop"],
				["eval", "_interior_manager._service_interior._open_station('shelves')"], ["wait", 1.5], ["eval", C + ".jed_rack('station')"], ["shot", "b_shelves"],
				["eval", "_interior_manager._service_interior._stations['shelves'].close_station()"], ["wait", 2.0], ["eval", C + ".jed_rack('after')"], ["shot", "c_shop_after"],
				["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=bizlife":
			# Guests in the pub and the Jednota: are they there through the open door, and the
			# goods on the rack, as you walk in (W26)?
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
				["money", 400000], ["clear", 4, 9, 5, 5], ["clear", 9, 14, 5, 5], ["clear", 4, 14, 5, 5],
				["build", "pub", 5, 10, 0], ["build", "vecerka", 10, 15, 0], ["build", "cabin_1", 5, 15, 0], ["build", "cabin_1", 7, 15, 0], ["wait", 1.0],
				["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3],
				["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0]]
			for ty in ["pub", "vecerka"]:
				st += [["eval", "debug_send_guests_to('%s', 240)" % ty], ["wait", 6.0], ["eval", "set('debug_camera', null)"], ["door_front", ty, 2.0], ["wait", 0.6], ["shot", "%s_0_at" % ty],
					["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('%s'))" % ty]]
				for k in 12:
					st += [["wait", 0.13], ["shot", "%s_1_in_%02d" % [ty, k]]]
				st += [["wait", 1.5], ["shot", "%s_2_inside" % ty], ["eval", "_interior_manager._service_interior._leave_on_foot()"], ["wait", 4.0]]
			st += [["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=storein":
			# The store behind the office from inside (its walls under the lean-to's roof, X2).
			var BI := "_interior_manager._building_interior"
			var st: Array = [["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 3.0],
				["eval", BI + "._exit_crt_view()"], ["wait", 2.0], ["eval", "debug_jump_to(1, 12.0)"], ["wait", 1.0], ["mouse", 0.5, 0.5],
				["eval", BI + "._extras.go_store()"], ["wait", 3.0]]
			for v in [[0.0, 10.0, "s_ahead_up"], [60.0, 15.0, "s_left_up"], [-60.0, 15.0, "s_right_up"], [0.0, -10.0, "s_ahead"]]:
				st += [["eval", BI + "._extras.look_store.set('yaw_deg', %s)" % v[0]], ["eval", BI + "._extras.look_store.set('pitch_deg', %s)" % v[1]], ["wait", 0.7], ["shot", v[2]]]
			st += [["eval", C + ".rec_probe('wallL', Vector3(-1.3, 1.2, 3.4), 0.12)"], ["eval", C + ".rec_probe('wallR', Vector3(1.3, 1.2, 3.4), 0.12)"],
				["eval", C + ".rec_probe('inL', Vector3(-1.15, 1.2, 3.4), 0.05)"], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=cabdoor":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"],
				["eval", "debug_repair_ruined()"], ["eval", "debug_jump_to(1, 13.0)"], ["wait", 2.0],
				["door_front", "cabin_1", 1.6], ["wait", 0.6], ["shot", "a_at_door"], ["eval", C + ".door_probe('cabin_1', 'before')"],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('cabin_1'))"], ["wait", 0.05], ["eval", C + ".door_probe('cabin_1', 'go')"]]
			for k in 12:
				st += [["wait", 0.12], ["shot", "b_in_%02d" % k]]
				if k == 3 or k == 6:
					st += [["eval", C + ".door_probe('cabin_1', 'k%d')" % k]]
			st += [["wait", 2.0], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=doors":
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
				["eval", "_interior_manager._building_interior.close_interior()"],
				["money", 40000], ["clear", 12, 10, 8, 5], ["build", "tent_1", 13, 12, 0], ["wait", 1.0], ["eval", C + ".tents()"], ["wait", 1.0],
				["eval", "debug_repair_ruined()"], ["eval", "debug_jump_to(1, 13.0)"], ["wait", 2.0],
				# In and out of the big tent first: the room stands there after.
				["door_front", "tent_3", 1.4], ["wait", 0.6],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('tent_3'))"], ["wait", 6.0], ["shot", "a_in_tent3"],
				["eval", C + ".walk_out('tent', 'tent_3')"]]
			for k in 14:
				st += [["wait", 0.15], ["shot", "b_out_tent3_%02d" % k]]
			st += [["wait", 2.0], ["door_front", "tent_1", 1.4], ["wait", 0.6], ["shot", "c_at_tent1_door"], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('tent_1'))"]]
			for k in 30:
				st += [["wait", 0.15], ["shot", "c_in_tent1_%02d" % k]]
			st += [["wait", 2.0], ["eval", C + ".walk_out('tent', 'tent_1')"], ["wait", 4.0],
				["door_front", "cabin_1", 1.6], ["wait", 0.6], ["shot", "d_at_cabin_door"],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('cabin_1'))"]]
			for k in 30:
				st += [["wait", 0.15], ["shot", "d_in_cabin_%02d" % k]]
			st += [["wait", 2.0], ["eval", "_interior_manager._cabin_interior._look.set('yaw_deg', 178.0)"], ["wait", 1.0], ["shot", "e_cabin_door_from_inside"],
				["eval", "_interior_manager._cabin_interior._look.set('yaw_deg', 0.0)"], ["wait", 0.5],
				["eval", C + ".walk_out('cabin', 'cabin_1')"]]
			for k in 20:
				st += [["wait", 0.15], ["shot", "f_out_cabin_%02d" % k]]
			st += [["wait", 2.0], ["eval", "get_tree().quit()"]]
			_steps = st
			return
		if a == "--part=floors":
			var CI := "_interior_manager._cabin_interior"
			var TI := "_interior_manager._tent_interior"
			var st: Array = [
				["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
				["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["mouse", 0.5, 0.5],
				["eval", "debug_jump_to(1, 12.5)"], ["wait", 1.0]]
			for v in [[0.0, -60.0, "rec_floor_front"], [150.0, -50.0, "rec_floor_back"], [62.0, -55.0, "rec_floor_left"]]:
				st += [["eval", C + ".hold_view(%s, %s)" % [v[0], v[1]]], ["wait", 0.5], ["shot", v[2]]]
			st += [["eval", C + ".hold_view(INF, INF)"], ["eval", "_interior_manager.close_main_interior_if_open()"], ["wait", 1.0],
				["money", 40000], ["clear", 12, 10, 8, 5], ["build", "tent_1", 13, 12, 0], ["wait", 1.0], ["eval", "debug_repair_ruined()"], ["wait", 1.5],
				["door_front", "cabin_1", 1.6], ["wait", 0.5], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('cabin_1'))"], ["wait", 5.0], ["mouse", 0.5, 0.5]]
			for v in [[0.0, -40.0, "cab_floor_c"], [72.0, -40.0, "cab_floor_l"], [-72.0, -40.0, "cab_floor_r"]]:
				st += [["eval", CI + "._look.set('yaw_deg', %s)" % v[0]], ["eval", CI + "._look.set('pitch_deg', %s)" % v[1]], ["wait", 0.7], ["shot", v[2]]]
			st += [["eval", CI + ".close_cabin()"], ["wait", 1.0],
				["door_front", "tent_1", 1.4], ["wait", 0.5], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('tent_1'))"], ["wait", 5.0], ["mouse", 0.5, 0.5]]
			for v in [[0.0, -30.0, "tent_floor_c"], [40.0, -25.0, "tent_floor_l"]]:
				st += [["eval", TI + "._look.set('yaw_deg', %s)" % v[0]], ["eval", TI + "._look.set('pitch_deg', %s)" % v[1]], ["wait", 0.7], ["shot", v[2]]]
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
