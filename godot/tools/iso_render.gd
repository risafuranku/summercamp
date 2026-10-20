extends "res://tools/shot_driver.gd"

## The Builder's pictures of the buildings from the camp's own 3D models: each one is
## built in the real camp, alone on a layer of its own, and drawn by an orthographic
## camera from the four corners the map can be turned to (crt_map_panel.VIEW_DIRS), at
## the map's angle (2:1, 30 degrees up) and one scale for all (ISO_PX_PER_TILE across a
## tile's width). The light comes from the camera's upper left whichever way it looks,
## as on the old pictures. Writes <out>/<type>_v<view>.png (magenta-free, alpha) and
## <out>/anchors.json (where the middle of the footprint's ground is in each picture).
##   godot --path godot --resolution 1280x720 res://tools/iso_render.tscn -- --out=<dir> [--only=pub,tent_1]

## (Bit 19 is the glass layer: every window in the camp would come along.)
const LAYER := 1 << 18
const ISO_PX_PER_TILE := 128.0          # pixels across a 4 m tile's diagonal on the map
const TILE_M := 4.0
const PX_PER_M := ISO_PX_PER_TILE / (TILE_M * 1.4142136)
const ELEV_DEG := 30.0
## The camera's side for each of the map's turns (as crt_map_panel draws the grid:
## the screen's bottom is towards these grid directions).
const VIEW_DIRS := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
const TYPES := ["tent_1", "tent_2", "tent_3", "cabin_1", "cabin_2", "cabin_3", "caravan_1", "caravan_2", "caravan_3",
	"toilet_block", "shower_block", "restaurant", "pub", "corn_stand", "vecerka", "bonfire", "sports_field", "lake_slide",
	"playground", "ping_pong", "hammock", "bench", "picnic_table", "flower_bed", "gnome", "mega_gnome", "flagpole", "sewer",
	"lamp_post", "power_generator", "main_building"]
const AT := Vector2i(9, 5)
## Things drawn again a few times, their own motion going on between (frames for the map).
const ANIMATED := {"flagpole": 4}
## Levels 2 and 3 are not built but upgraded from the first (the room's own replace).
const UPGRADED := {"tent_2": "tent_1", "tent_3": "tent_1", "cabin_2": "cabin_1", "cabin_3": "cabin_1", "caravan_2": "caravan_1", "caravan_3": "caravan_1"}

var _vp: SubViewport
var _cam: Camera3D
var _light: DirectionalLight3D
var _anchors: Dictionary = {}
var _hidden_lights: Array = []
var _layers: Array = []          # [node, old layers]


func _ready() -> void:
	super._ready()
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, 12.0)"], ["money", 90000], ["clear", AT.x - 1, AT.y - 1, 6, 6], ["wait", 1.0],
	]
	for t in TYPES:
		if not only.is_empty() and not only.has(t):
			continue
		if UPGRADED.has(t):
			s.append_array([["build", UPGRADED[t], AT.x, AT.y, 0], ["wait", 1.0],
				["eval", "_interior_manager._handle_replace_upgrade(Vector2i(%d, %d), '%s', '%s', 0)" % [AT.x, AT.y, UPGRADED[t], t]], ["wait", 1.2]])
		elif t != "main_building":
			s.append_array([["build", t, AT.x, AT.y, 0], ["wait", 1.2]])
		for v in 4:
			s.append_array([["iso_setup", t, v], ["wait", 0.35], ["iso_save", t, v],
				["iso_win", t], ["wait", 0.25], ["iso_save_win", t, v], ["iso_unwin"]])
			# What moves on its own in the camp (the flag in the wind): a few frames of it.
			if ANIMATED.has(t):
				for f in int(ANIMATED[t]):
					s.append_array([["wait", 0.17], ["iso_save", t, v, "_f%d" % f]])
		if t != "main_building":
			s.append_array([["clear", AT.x - 1, AT.y - 1, 6, 6], ["wait", 0.8]])
	s.append(["iso_done"])
	_steps = s


func _structure(t: String) -> Node3D:
	var bm = _main.get("building_manager")
	var root = bm.get_node_or_null("Structures")
	for c in root.get_children():
		if str(c.get_meta("building_type", "")) == t:
			return c
	return null


func _run_step(step: Array) -> void:
	match str(step[0]):
		"iso_setup":
			_setup(str(step[1]), int(step[2]))
		"iso_save":
			_save(str(step[1]), int(step[2]), str(step[3]) if step.size() > 3 else "")
		"iso_win":
			_windows_only(str(step[1]))
		"iso_save_win":
			_save(str(step[1]), int(step[2]), "_win")
		"iso_unwin":
			_windows_back()
		"iso_done":
			_restore()
			var f := FileAccess.open(_out_dir.path_join("anchors.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify(_anchors, "\t"))
			f.close()
			print("ISO RENDER done: %d types" % _anchors.size())
		_:
			super._run_step(step)


func _ensure_rig() -> void:
	if _vp != null:
		return
	var world: Node3D = _main.get("_world_3d")
	_vp = SubViewport.new()
	_vp.size = Vector2i(768, 768)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.world_3d = world.get_world_3d()
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.size = float(_vp.size.y) / PX_PER_M
	_cam.cull_mask = LAYER
	_cam.near = 1.0
	_cam.far = 400.0
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.80)
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_cam.environment = env
	_vp.add_child(_cam)
	_cam.current = true
	_light = DirectionalLight3D.new()
	_light.light_cull_mask = LAYER
	_light.light_energy = 1.35
	_light.shadow_enabled = false
	world.add_child(_light)
	# The camp's own lights stay off this layer while it renders.
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		if l != _light and (l as Light3D).light_cull_mask & LAYER:
			_hidden_lights.append(l)
			(l as Light3D).light_cull_mask &= ~LAYER


func _isolate(node: Node) -> void:
	for n in node.find_children("*", "VisualInstance3D", true, false) + [node]:
		if n is VisualInstance3D:
			_layers.append([n, (n as VisualInstance3D).layers])
			(n as VisualInstance3D).layers = LAYER


func _unisolate() -> void:
	for e in _layers:
		if is_instance_valid(e[0]):
			(e[0] as VisualInstance3D).layers = int(e[1])
	_layers.clear()


func _restore() -> void:
	_unisolate()
	for l in _hidden_lights:
		if is_instance_valid(l):
			(l as Light3D).light_cull_mask |= LAYER
	_hidden_lights.clear()


func _setup(t: String, v: int) -> void:
	_ensure_rig()
	_unisolate()
	var s := _structure(t)
	if s == null:
		print("ISO RENDER no structure for %s" % t)
		return
	_isolate(s)
	var gm = _main.get("grid_manager")
	var o: Vector2i = s.get_meta("grid_origin", AT)
	var fp: Vector2i = s.get_meta("grid_footprint", Vector2i.ONE)
	var center: Vector3 = gm.get_footprint_center(o, fp)
	var d: Vector2 = (VIEW_DIRS[v] as Vector2).normalized()
	var el := deg_to_rad(ELEV_DEG)
	var dist := 40.0
	_cam.global_position = center + Vector3(d.x * cos(el), sin(el), d.y * cos(el)) * dist
	_cam.look_at(center, Vector3.UP)
	# The light from the camera's upper left, a little in front.
	var b := _cam.global_transform.basis
	var from := (-b.x * 0.75 + b.y * 1.1 + b.z * 0.55).normalized()
	_light.look_at_from_position(center + from * 10.0, center, Vector3.UP)
	_anchors["%s_v%d" % [t, v]] = {"anchor": [_vp.size.x * 0.5, _vp.size.y * 0.5], "footprint": [fp.x, fp.y], "size": [_vp.size.x, _vp.size.y]}


func _save(t: String, v: int, suffix := "") -> void:
	if _vp == null:
		return
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	var key := "%s_v%d" % [t, v]
	if _anchors.has(key) and suffix == "":
		_anchors[key]["used"] = [used.position.x, used.position.y, used.size.x, used.size.y]
	if suffix != "" and used.size == Vector2i.ZERO:
		return
	img.save_png(_out_dir.path_join(key + suffix + ".png"))
	print("ISO RENDER %s%s used %s" % [key, suffix, used])


## The windows that light at night (meta lit_window, scripts/ambient/window_lights.gd)
## alone in white: the map's lit windows (crt_map_panel), the same view, the same place.
var _win_keep: Array = []
var _white: StandardMaterial3D


func _windows_only(t: String) -> void:
	var s := _structure(t)
	if s == null:
		return
	if _white == null:
		_white = StandardMaterial3D.new()
		_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_white.albedo_color = Color.WHITE
	for e in _layers:
		var n: VisualInstance3D = e[0]
		if not is_instance_valid(n):
			continue
		var lit := n.has_meta("lit_window")
		_win_keep.append([n, n.layers, (n as GeometryInstance3D).material_override if n is GeometryInstance3D else null])
		n.layers = LAYER if lit else 0
		if lit and n is GeometryInstance3D:
			(n as GeometryInstance3D).material_override = _white


func _windows_back() -> void:
	for e in _win_keep:
		if is_instance_valid(e[0]):
			(e[0] as VisualInstance3D).layers = int(e[1])
			if e[0] is GeometryInstance3D:
				(e[0] as GeometryInstance3D).material_override = e[2]
	_win_keep.clear()
