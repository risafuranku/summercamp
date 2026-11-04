extends "res://tools/shot_driver.gd"

## The sun in the reception (TODO W26): what in the room's world stands in the windows'
## openings and casts a shadow (it would keep the sun out); pictures with the sun in it
## and without, at a few hours. Lines "SUNCHECK ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/sun_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('SunCheck')"
const BI := "_interior_manager._building_interior"

var _cam: Camera3D


func _bi():
	return _main.get("_interior_manager").get("_building_interior")


## Rays from the floor back out through the front window toward the sun: what (by its
## box) stands in their way.
func occluders(tag: String) -> void:
	var bi = _bi()
	var root: Node3D = bi.get("_room_root")
	var world := root.get_world_3d()
	var sun: DirectionalLight3D = bi.get("_room_sun")
	var inv := root.global_transform.affine_inverse()
	var fwd: Vector3 = (inv.basis * -sun.global_basis.z).normalized()
	var casters: Array = []
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_inside_tree() or g.get_world_3d() != world or not g.is_visible_in_tree() or g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		casters.append([g, (inv * g.global_transform) * g.get_aabb()])
	var hits := {}
	var rays := 0
	var free := 0
	for i in 7:
		for j in 5:
			var o := Vector3(lerpf(-1.3, 0.5, i / 6.0), lerpf(1.05, 2.3, j / 4.0), -2.5)
			var t := o.y / maxf(-fwd.y, 0.05)
			var p := o + fwd * t
			var a := p - fwd * 0.04
			var b := o - fwd * 25.0
			rays += 1
			var any := false
			for c in casters:
				var ab: AABB = c[1]
				if ab.intersects_segment(a, b) != null:
					var k := str((c[0] as Node).get_path()).right(70)
					hits[k] = int(hits.get(k, 0)) + 1
					any = true
			if not any:
				free += 1
	print("SUNCHECK %s occluders fwd=%s rays=%d free=%d casters=%d" % [tag, str(fwd), rays, free, casters.size()])
	for k in hits:
		print("SUNCHECK %s occ %d %s" % [tag, hits[k], k])


func topdown(on: bool) -> void:
	var bi = _bi()
	var root: Node3D = bi.get("_room_root")
	if on:
		_cam = Camera3D.new()
		_cam.name = "SunCheckCam"
		root.add_child(_cam)
		_cam.position = Vector3(-0.3, 2.6, -0.6)
		_cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_cam.fov = 110.0
		_cam.near = 0.05
		_cam.far = 22.0
		_cam.current = true
	elif _cam != null:
		_cam.queue_free()
		_cam = null
		(bi.get("_interior_camera") as Camera3D).current = true


func shadows(on: bool) -> void:
	var sun: DirectionalLight3D = _bi().get("_room_sun")
	sun.shadow_enabled = on
	print("SUNCHECK shadows=%s" % str(on))


func sun_on(on: bool) -> void:
	var sun: DirectionalLight3D = _bi().get("_room_sun")
	sun.visible = on


func force_sun(pitch_deg: float, energy: float) -> void:
	var bi = _bi()
	bi.set("_room_sun_debug", true)
	var sun: DirectionalLight3D = bi.get("_room_sun")
	sun.visible = true
	var fwd := Vector3(0, -sin(deg_to_rad(pitch_deg)), cos(deg_to_rad(pitch_deg)))
	sun.global_basis = Basis.looking_at(fwd, Vector3.UP)
	sun.light_energy = energy
	print("SUNCHECK forced forward=%s cam_current=%s" % [str(-sun.global_basis.z), str(_cam.current if _cam != null else false)])


func report(tag: String) -> void:
	var bi = _bi()
	var sun: DirectionalLight3D = bi.get("_room_sun")
	var camp = _main.get("sun")
	var env: Environment = bi.get("_room_environment")
	print("SUNCHECK %s hour=%.2f weather=%s camp_sun=%.2f vis=%s room_sun=%.2f vis=%s fwd=%s col=%s ambient=%.2f ceiling=%.2f window=%.2f" % [tag,
		float(_main.get("_time_of_day_hours")), str(_main.get("_weather_state")), float(camp.light_energy) if camp != null else -1.0, str(camp.visible if camp != null else false),
		sun.light_energy, str(sun.visible), str(-sun.global_basis.z), str(sun.light_color), env.ambient_light_energy,
		float((bi.get("_ceiling_light") as Light3D).light_energy), float((bi.get("_window_light") as Light3D).light_energy)])


func look(yaw: float, pitch: float) -> void:
	var lk = _bi().get("_look")
	lk.set("yaw_deg", yaw)
	lk.set("pitch_deg", pitch)


## Where the sun lands: from points in the front window inward along the light, the first
## box hit (by name), and how many of the window's rays land there.
func landing(tag: String) -> void:
	var bi = _bi()
	var root: Node3D = bi.get("_room_root")
	var world := root.get_world_3d()
	var sun: DirectionalLight3D = bi.get("_room_sun")
	var inv := root.global_transform.affine_inverse()
	var fwd: Vector3 = (inv.basis * -sun.global_basis.z).normalized()
	var boxes: Array = []
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_inside_tree() or g.get_world_3d() != world or not g.is_visible_in_tree():
			continue
		boxes.append([g.name, (inv * g.global_transform) * g.get_aabb()])
	var land := {}
	for i in 7:
		for j in 5:
			var o := Vector3(lerpf(-1.3, 0.5, i / 6.0), lerpf(1.05, 2.3, j / 4.0), -2.42)
			var best := 99.0
			var who := "-"
			for bx in boxes:
				var ab: AABB = bx[1]
				if ab.has_point(o):
					continue
				var hit = ab.intersects_segment(o, o + fwd * 12.0)
				if hit != null and o.distance_to(hit) < best:
					best = o.distance_to(hit)
					who = "%s@%s" % [str(bx[0]), str(Vector3(snappedf(hit.x, 0.1), snappedf(hit.y, 0.1), snappedf(hit.z, 0.1)))] if j == 2 and i == 3 else str(bx[0])
			land[who] = int(land.get(who, 0)) + 1
	print("SUNCHECK %s landing fwd=%s %s" % [tag, str(fwd), str(land)])


func pancake(v: float) -> void:
	var sun: DirectionalLight3D = _bi().get("_room_sun")
	print("SUNCHECK pancake was %.1f max=%.1f" % [sun.directional_shadow_pancake_size, sun.directional_shadow_max_distance])
	sun.directional_shadow_pancake_size = v


func mode(m: int) -> void:
	var sun: DirectionalLight3D = _bi().get("_room_sun")
	sun.directional_shadow_mode = m


func bias(b: float, nb: float) -> void:
	var sun: DirectionalLight3D = _bi().get("_room_sun")
	sun.shadow_bias = b
	sun.shadow_normal_bias = nb


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", BI + "._exit_crt_view()"], ["wait", 1.5],
	]
	# Morning: the sun behind the building, none in.
	_steps += [["eval", "debug_jump_to(2, 10.5)"], ["wait", 1.6], ["eval", C + ".report('morning')"]]
	# The afternoon's patch on the floor before the counter (from above), the evening's on
	# the wall and the door behind the desk (where the warden turns to).
	_steps += [
		["eval", "debug_jump_to(2, 14.5)"], ["wait", 1.6], ["eval", C + ".report('h1450')"], ["eval", C + ".landing('h1450')"],
		["eval", C + ".topdown(true)"], ["wait", 0.6], ["shot", "h1450_top"],
		["eval", C + ".sun_on(false)"], ["eval", BI + ".set('_room_sun_debug', true)"], ["wait", 0.4], ["shot", "h1450_top_off"],
		["eval", BI + ".set('_room_sun_debug', false)"], ["eval", C + ".topdown(false)"],
	]
	for h in [17.0, 17.75, 18.4]:
		var tag := "h%d" % int(h * 100)
		_steps += [
			["eval", "debug_jump_to(2, %.2f)" % h], ["wait", 1.6], ["eval", C + ".report('%s')" % tag], ["eval", C + ".landing('%s')" % tag],
			["eval", C + ".look(150.0, -8.0)"], ["wait", 0.5], ["shot", tag + "_back"],
			["eval", C + ".look(0.0, -10.0)"], ["wait", 0.5], ["shot", tag + "_win"],
		]
	# Rain: no sun to throw in.
	_steps += [
		["eval", "debug_jump_to(2, 17.75)"], ["wait", 0.5], ["eval", "weather_system.set_weather(4)"], ["wait", 1.6], ["eval", C + ".report('rain')"],
		["eval", C + ".look(150.0, -8.0)"], ["wait", 0.5], ["shot", "rain_back"],
	]
	_steps.append(["eval", "get_tree().quit()"])
