extends "res://tools/shot_driver.gd"

## Builder 98 on the camp computer, for looking at: a few buildings of each kind turned
## each of the four ways, the map in its four views (crt_screen), and the camp from the
## same four corners in 3D (an orthographic camera at the map's angle), so a door on the
## map can be checked against the door in the camp.
##   godot --path godot --resolution 1280x720 res://tools/builder_shots.tscn -- --out=<dir> [--part=rot|life]

const UI := "_interior_manager._building_interior._crt_ui"
const MAP := "debug_builder_map()"
const VIEW_DIRS := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]

var _part := "rot"


func _ready() -> void:
	super._ready()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			_part = a.substr(7)
	if _part == "all":
		_steps = _every_building()
		return
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 90000],
		["clear", 3, 3, 16, 12], ["wait", 1.0],
	]
	# The buildings, each kind in each of its turns, in rows.
	var row := [["pub", 2], ["restaurant", 2], ["cabin_1", 2], ["toilet_block", 1], ["shower_block", 1], ["tent_1", 1]]
	var y := 4
	for r in row:
		var t: String = r[0]
		var w: int = r[1]
		for k in 4:
			s.append(["build", t, 4 + k * (w + 1), y, k])
		y += w + 1
	s.append_array([["build", "caravan_1", 14, 4, 0], ["build", "caravan_1", 14, 6, 2], ["build", "corn_stand", 14, 8, 1],
		["build", "vecerka", 15, 10, 3], ["build", "bonfire", 17, 4, 0], ["build", "flagpole", 17, 6, 0]])
	for x in range(4, 18):
		s.append(["build", "path", x, 3, 0])
	s.append_array([["build", "lamp_post", 6, 3, 0], ["build", "lamp_post", 10, 3, 0], ["wait", 1.5],
		["prep_all"], ["book", "Novak family", "family", 2, 2], ["prep_all"], ["book", "Pepa", "drunk", 1, 2], ["prep_all"],
		["book", "Kristyna", "cheap_chick", 1, 1], ["prep_all"], ["book", "Vlasta", "picker", 1, 2], ["prep_all"],
		["book", "Mirek", "quiet_guy", 1, 2], ["prep_all"], ["book", "Franta", "tramp", 1, 2],
		["timescale", 3.0], ["wait", 8.0], ["timescale", 1.0]])
	s.append_array([
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", UI + ".open_app('builder') != null"], ["wait", 4.5],
		["eval", "debug_close_msgboxes()"], ["wait", 0.5],
		["eval", MAP + ".set('_zoom_target', 1.9)"], ["eval", MAP + ".set('_zoom_level', 1.9)"], ["wait", 0.3],
		["eval", MAP + ".debug_center_on(Vector2i(10, 9))"], ["wait", 1.2],
	])
	for v in 4:
		s.append_array([["eval", MAP + ".set('view_rot', %d)" % v], ["eval", MAP + ".set('_static_dirty', true)"],
			["eval", MAP + ".debug_center_on(Vector2i(10, 9))"], ["wait", 0.8], ["crt_screen", "v%d_map" % v]])
	# The T key turns the view; the music plays; a site going up and a demolition.
	s.append_array([["key", "T"], ["wait", 0.6], ["eval", "[" + MAP + ".view_rot, " + MAP + ".get_parent()._music != null and " + MAP + ".get_parent()._music.playing]"],
		["key", "T"], ["key", "T"], ["key", "T"], ["wait", 0.6], ["eval", MAP + ".view_rot"],
		["eval", MAP + ".debug_center_on(Vector2i(10, 9))"], ["eval", MAP + ".set('_zoom_target', 2.6)"],
		["build", "cabin_1", 11, 12, 0], ["wait", 0.8], ["crt_screen", "s0_site_found"], ["wait", 1.0], ["crt_screen", "s1_site_walls"],
		["wait", 1.0], ["crt_screen", "s2_site_roof"], ["wait", 2.0],
		["eval", MAP + "._send_demolish_request(Rect2i(11, 12, 2, 2))"], ["wait", 0.5], ["crt_screen", "s3_dozer"], ["wait", 0.6], ["crt_screen", "s4_dozer"]])
	# Close to the guests, and the evening with its lit windows.
	s.append_array([["eval", MAP + ".set('_zoom_target', 3.6)"], ["eval", MAP + ".set('_zoom_level', 3.6)"], ["eval", MAP + ".set('_static_dirty', true)"],
		["eval", MAP + ".debug_center_on(Vector2i(9, 7))"], ["wait", 0.6], ["crt_screen", "w0_guests"], ["wait", 0.5], ["crt_screen", "w1_guests"],
		["hours", 7.6], ["wait", 2.5], ["crt_screen", "w2_dusk"], ["eval", MAP + ".set('_zoom_target', 1.9)"], ["eval", MAP + ".set('_zoom_level', 1.9)"],
		["eval", MAP + ".set('_static_dirty', true)"], ["eval", MAP + ".debug_center_on(Vector2i(10, 9))"], ["wait", 0.8], ["crt_screen", "w3_dusk_wide"]])
	s.append_array([["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0]])
	for v in 4:
		s.append_array([["iso_cam", 10, 9, v], ["wait", 0.6], ["shot", "v%d_camp" % v]])
	_steps = s


## --part=all: every kind of building in each of its turns, a few kinds at a time; for
## each lot the map in its four views and the camp from the same four corners
## (<lot>_v<view>_map.png beside <lot>_v<view>_camp.png). Levels 2 and 3 are upgraded
## in place from the first.
const LOTS := [
	["tent_1", "tent_2", "tent_3", "toilet_block", "shower_block", "corn_stand"],
	["cabin_1", "cabin_2", "cabin_3"],
	["pub", "restaurant", "caravan_1", "caravan_2", "caravan_3"],
	["vecerka", "sports_field", "lake_slide", "playground"],
	["bonfire", "ping_pong", "hammock", "bench", "picnic_table", "flower_bed", "gnome", "flagpole", "sewer", "lamp_post", "power_generator", "mega_gnome"],
]
const UPGRADED := {"tent_2": "tent_1", "tent_3": "tent_1", "cabin_2": "cabin_1", "cabin_3": "cabin_1", "caravan_2": "caravan_1", "caravan_3": "caravan_1"}


func _every_building() -> Array:
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, 11.0)"], ["money", 900000],
		["clear", 3, 3, 20, 16], ["wait", 1.0],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", UI + ".open_app('builder') != null"], ["wait", 4.5], ["eval", "debug_close_msgboxes()"], ["wait", 0.5],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 0.5],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0]]
	for li in LOTS.size():
		var lot: Array = LOTS[li]
		s.append(["clear", 3, 3, 20, 16])
		var y := 4
		for t in lot:
			var fp: Vector2i = _fp(str(t))
			var step := maxi(fp.x, fp.y) + 1
			for k in 4:
				var x := 4 + k * (step + 1)
				var base := str(UPGRADED.get(t, t))
				s.append(["build", base, x, y, k])
				if UPGRADED.has(t):
					s.append(["wait", 0.2])
					s.append(["eval", "_interior_manager._handle_replace_upgrade(Vector2i(%d, %d), '%s', '%s', 0)" % [x, y, base, t]])
			y += maxi(fp.x, fp.y) + 1
		s.append(["wait", 1.5])
		s.append_array([["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 3.0],
			["eval", UI + ".open_app('builder') != null"], ["wait", 1.5], ["eval", "debug_close_msgboxes()"],
			["eval", MAP + ".set('_zoom_target', 1.7)"], ["eval", MAP + ".set('_zoom_level', 1.7)"]])
		for v in 4:
			s.append_array([["eval", MAP + ".set('view_rot', %d)" % v], ["eval", MAP + ".set('_static_dirty', true)"],
				["eval", MAP + ".debug_center_on(Vector2i(12, %d))" % (4 + y / 2)], ["wait", 0.7], ["crt_screen", "l%d_v%d_map" % [li, v]]])
		s.append_array([["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 0.5],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0]])
		for v in 4:
			s.append_array([["iso_cam", 12, 4 + y / 2, v], ["wait", 0.6], ["shot", "l%d_v%d_camp" % [li, v]]])
		s.append(["eval", "set('debug_camera', null)"])
	return s


func _fp(t: String) -> Vector2i:
	var def = CoreRoot.registry.get_def(StringName(t)) if CoreRoot != null and CoreRoot.registry != null else null
	return def.footprint if def != null else Vector2i.ONE


func _run_step(step: Array) -> void:
	if str(step[0]) == "iso_cam":
		# The camp from the map's corner for view [3], looking at grid ([1], [2]).
		var gm = _main.get("grid_manager")
		var world3d: Node3D = _main.get("_world_3d")
		var cam := Camera3D.new()
		world3d.add_child(cam)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 52.0
		cam.far = 600.0
		var at: Vector3 = gm.grid_to_world(Vector2i(int(step[1]), int(step[2])))
		var d: Vector2 = (VIEW_DIRS[int(step[3])] as Vector2).normalized()
		var el := deg_to_rad(30.0)
		cam.global_position = at + Vector3(d.x * cos(el), sin(el), d.y * cos(el)) * 90.0
		cam.look_at(at, Vector3.UP)
		var we = _main.find_child("WorldEnvironment", true, false)
		if we != null and we.environment != null:
			var env: Environment = we.environment.duplicate()
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
			cam.environment = env
		var old = _main.get("debug_camera")
		if old != null and is_instance_valid(old):
			old.queue_free()
		_main.set("debug_camera", cam)
		return
	super._run_step(step)
