extends "res://tools/shot_driver.gd"

## The lodgings' windows from far off (the user 4. 11.: "the interiors must show through the
## windows from far off too; now you see them pop in when you come near"): a cabin and a
## caravan built, the warden walks up to each from 60 m, pictures at 60, 45, 41 (just
## outside the live view), 39 (it fading in), 30, 15 m, by day and at night. Prints whether
## the panes have their room's cube and how far the live view has faded in ("OKNA ...").
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/okna_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('OknaCheck')"
var _target: Node3D


## A long lens for a look at the panes from far: a camera of its own where the warden's eye
## is, on the building's first pane (fov 0: the warden's own again).
var _lens: Camera3D


func lens(fov: float) -> String:
	if fov <= 0.0:
		if _lens != null:
			_lens.current = false
			_main.get("_player").get_node("Head/Camera3D").current = true
		return "lens off"
	var eye: Camera3D = _main.get("_player").get_node("Head/Camera3D")
	if _lens == null:
		_lens = Camera3D.new()
		eye.get_parent().get_parent().get_parent().add_child(_lens)
	var pane: Node3D = null
	for m in _target.find_children("*", "MeshInstance3D", true, false):
		if (m as Node).has_meta("lit_window") and ((m as Node3D).global_basis.z.dot(eye.global_position - (m as Node3D).global_position) > 0.0):
			pane = m
			break
	_lens.global_position = eye.global_position
	_lens.look_at(pane.global_position if pane != null else _target.global_position + Vector3(0, 1.4, 0))
	_lens.fov = fov
	_lens.current = true
	return "lens %.0f on %s" % [fov, pane.name if pane != null else "?"]


## The room's cube alone in its panes (the live view stopped and faded out), or the live
## view back.
func cube_only(on: bool) -> String:
	var im = _main.get("_interior_manager")
	for it in [im.get("_cabin_interior"), im.get("_caravan_interior")]:
		it.set_process(not on)
		if on:
			it.call("_release_inview")
	return "cube only %s" % on


## The cubes' pictures saved, for a look.
func dump_cubes() -> String:
	var im = _main.get("_interior_manager")
	var n := 0
	for pair in [["cabin", im.get("_cabin_interior")], ["van", im.get("_caravan_interior")]]:
		var cubes: Dictionary = pair[1].get("cubes")
		for lv in cubes.keys():
			var tex: Array = cubes[lv]
			for i in tex.size():
				var img: Image = (tex[i] as Texture2D).get_image()
				if img != null and _out_dir != "":
					img.save_png("%s/cube_%s%d_%d.png" % [_out_dir, pair[0], int(lv), i])
					n += 1
	return "saved %d" % n


func probe_ray() -> String:
	var im = _main.get("_interior_manager")
	var spec: Dictionary = im.get("_cabin_interior").call("cube_spec", _target)
	var w2r: Transform3D = spec["world_to_room"]
	var cam: Camera3D = _main.get_viewport().get_camera_3d()
	var cam2: Camera3D = _main.get("_player").get_node("Head/Camera3D")
	var out := []
	for m in _target.find_children("*", "MeshInstance3D", true, false):
		if not (m as Node).has_meta("lit_window"):
			continue
		var p: Vector3 = (m as Node3D).global_position
		var ro: Vector3 = w2r * p
		var co: Vector3 = w2r * cam2.global_position
		out.append("%s pane_room=%s cam_room=%s pane_basis_z=%s" % [m.name, ro, co, (m as Node3D).global_basis.z])
	var line := "OKNA ray: vpcam=%s headcam=%s spec_box=%s | %s" % [cam.global_position if cam != null else Vector3.INF, cam2.global_position, spec["box"], " ; ".join(out)]
	print(line)
	return line


func debug_mode(v: int) -> String:
	var n := 0
	for m in _target.find_children("*", "MeshInstance3D", true, false):
		var mat = (m as MeshInstance3D).material_override
		if mat is ShaderMaterial and str((mat as ShaderMaterial).shader.resource_path).ends_with("window_cube.gdshader"):
			(mat as ShaderMaterial).set_shader_parameter("debug", v)
			n += 1
	return "debug %d on %d" % [v, n]


func face(kind: String, dist: float) -> String:
	var bm = _main.get("building_manager")
	_target = null
	for c in bm.get_node("Structures").get_children():
		if str(c.get_meta("building_type", "")) == kind:
			_target = c
	if _target == null:
		return "no " + kind
	var door_anim = load("res://scripts/attractions/door_anim.gd")
	var way: Dictionary = door_anim.entry_points(_target, 0)
	var out: Vector3 = (way["outside"] - way["inside"]).normalized()
	var p: Node3D = _main.get("_player")
	var mid: Vector3 = (way["inside"] as Vector3) - out * 1.2
	var at: Vector3 = mid + out * dist
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.rotation.y = atan2(out.x, out.z)
	p.set("_pitch", deg_to_rad(-3.0))
	p.set("_pitch_target", deg_to_rad(-3.0))
	return "%s at %.0f m" % [kind, dist]


func state(label: String) -> String:
	var panes: Array = []
	for m in _target.find_children("*", "MeshInstance3D", true, false):
		if (m as Node).has_meta("lit_window"):
			panes.append(m)
	var cubes := 0
	var live := -1.0
	for p in panes:
		var mat = (p as MeshInstance3D).material_override
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null and str((mat as ShaderMaterial).shader.resource_path).ends_with("window_cube.gdshader"):
			cubes += 1
			var lv = (mat as ShaderMaterial).get_shader_parameter("live")
			live = maxf(live, float(lv) if lv != null else 0.0)
	var line := "OKNA %s: panes=%d cube=%d live=%.2f" % [label, panes.size(), cubes, live]
	print(line)
	return line


func _ready() -> void:
	super._ready()
	var steps: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.4],
		["key", "Escape"], ["wait", 2.0],
		["money", 200000], ["clear", 6, 10, 20, 14],
		["build", "cabin_1", 10, 14, 0], ["build", "caravan_1", 18, 14, 0], ["prep_all"], ["wait", 4.0],
		["eval", C + ".dump_cubes()"],
	]
	if OS.get_cmdline_user_args().has("--part=debug"):
		steps.append_array([["eval", C + ".face('cabin_1', 6.0)"], ["eval", C + ".cube_only(true)"], ["wait", 0.6], ["eval", C + ".probe_ray()"]])
		for v in [0, 1, 2, 3]:
			steps.append_array([["eval", C + ".debug_mode(%d)" % v], ["wait", 0.3], ["shot", "dbg_%d" % v]])
		steps.append(["eval", "get_tree().quit()"])
		_steps = steps
		return
	if OS.get_cmdline_user_args().has("--part=dump"):
		steps.append(["eval", "get_tree().quit()"])
		_steps = steps
		return
	for night in [false, true]:
		if night:
			steps.append_array([["eval", "debug_jump_to(_day_index, 22.2)"], ["wait", 2.0]])
		for kind in ["cabin_1", "caravan_1"]:
			var tag := "%s_%s" % [kind, "noc" if night else "den"]
			for d in [60.0, 45.0, 41.0, 39.0, 30.0, 15.0]:
				steps.append_array([
					["eval", C + ".face('%s', %.1f)" % [kind, d]], ["wait", 0.7],
					["eval", C + ".state('%s_%d')" % [tag, int(d)]], ["shot", "%s_%02d" % [tag, int(d)]],
				])
			# Close: the room's cube alone, then the live room over it, from the same spot.
			for d2 in [12.0, 6.0]:
				steps.append_array([
					["eval", C + ".face('%s', %.1f)" % [kind, d2]], ["eval", C + ".cube_only(true)"], ["wait", 0.6],
					["shot", "%s_cube_%02d" % [tag, int(d2)]],
					["eval", C + ".cube_only(false)"], ["wait", 1.0],
					["eval", C + ".state('%s_live_%d')" % [tag, int(d2)]], ["shot", "%s_live_%02d" % [tag, int(d2)]],
				])
	_steps = steps
