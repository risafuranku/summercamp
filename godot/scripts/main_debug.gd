extends "res://scripts/main.gd"

## The game's root as the screenshot driver, the harnesses and the debug menu drive it (out
## of main.gd 15. 11.): the debug_* hooks they call by name (put the player somewhere, jump
## the clock, spawn a night's thing, click, read the camp's state). It is main.gd itself
## with these on top (scenes/main.tscn runs this script): main.gd stays the game, this file
## the hooks. Nothing in the game calls them.


## Debug/test entry: stand `dx` metres east of the wicket gate into the corn (negative:
## west, in the corn), facing west.
func debug_goto_corn_gate(dx: float) -> void:
	var corn = find_child("CornField", true, false)
	if corn == null or _player == null:
		return
	_player.global_position = Vector3(corn.fence_x + dx, 0.3, corn.gate_z)
	_player.rotation.y = deg_to_rad(90.0)


## Debug/test entry: stand on the maze path `dist` tiles before `at` (along the way from
## the entrance), facing it.
func debug_corn_face(at: Vector3, dist: float) -> void:
	var corn := _corn_field()
	if corn == null or _player == null:
		return
	var path: Array = corn.path_between(corn.entrance, corn.world_tile(at))
	var stand: Vector3 = corn.tile_world(path[maxi(0, path.size() - 1 - int(dist))]) if not path.is_empty() else at + Vector3(2, 0, 0)
	_player.global_position = stand + Vector3(0, 0.3, 0)
	var to := at - stand
	_player.rotation.y = atan2(-to.x, -to.z)


## Debug/test entry: stand at a spot of the corn walk: "exit" (the maze's far way out,
## facing west), "strip" (on the strip under the wires, facing the hut), "hut" (at its
## door). Returns where.
func debug_corn_spot(which: String) -> Vector3:
	var corn = find_child("CornField", true, false)
	if corn == null or _player == null:
		return Vector3.INF
	var p: Vector3
	var look: Vector3
	match which:
		"exit":
			p = corn.tile_world(corn.exit_tile) + Vector3(-0.2, 0, 0)
			look = p + Vector3(-10, 0, 0)
		"strip":
			p = Vector3(corn.line_x + 5.0, 0, corn.tile_world(corn.exit_tile).z)
			look = corn.booth_door
		_:
			p = corn.booth_door + Vector3(2.5, 0, 1.5)
			look = corn.booth_door
	_player.global_position = p + Vector3(0, 0.3, 0)
	var to := look - p
	_player.rotation.y = atan2(-to.x, -to.z)
	return p


func debug_player_y() -> float:
	return _player.global_position.y if _player != null else 0.0


## Debug/test entry: a camera high over the maze, looking down.
func debug_corn_overview() -> void:
	var corn = find_child("CornField", true, false)
	if corn == null:
		return
	var cam := Camera3D.new()
	_world_3d.add_child(cam)
	cam.fov = 62.0
	var c: Vector2 = corn.maze_rect.get_center()
	cam.global_position = Vector3(c.x + 16.0, 38.0, c.y)
	cam.look_at(Vector3(c.x, 0.0, c.y), Vector3.UP)
	if debug_camera != null and is_instance_valid(debug_camera):
		debug_camera.queue_free()
	debug_camera = cam


## Debug/test entry: a camera high over a grid tile, looking down at it (shot driver).
func debug_overview_tile(tile: Vector2i, height: float = 26.0) -> void:
	var cam := Camera3D.new()
	_world_3d.add_child(cam)
	cam.fov = 62.0
	var c: Vector3 = grid_manager.grid_to_world(tile)
	cam.global_position = Vector3(c.x, height, c.z - height * 0.45)
	cam.look_at(Vector3(c.x, 0.0, c.z), Vector3.UP)
	if debug_camera != null and is_instance_valid(debug_camera):
		debug_camera.queue_free()
	debug_camera = cam


## Debug/test entry: the render style (GameSettings is an autoload the shot driver can't reach).
func debug_render_preset(preset: String) -> void:
	GameSettings.set_retro_preset(preset, false)


## Debug/test entry: the first structure of a building type (e.g. the pre-placed generator).
## Tools: frame timing (ms) and fps, for the performance scenarios.
## Shot driver: what stands in the camp within r metres of the reception window's view.
func debug_near_window(r: float = 4.0) -> Array:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	if bi == null:
		return []
	var xf: Transform3D = bi.get("_portal_xform")
	var at: Vector3 = xf * Vector3(-0.4, 1.0, -4.0)
	var out := []
	for n in find_children("*", "Node3D", true, false):
		var n3 := n as Node3D
		if n3.is_visible_in_tree() and (n3 is MeshInstance3D or n3 is StaticBody3D) and n3.global_position.distance_to(at) < r:
			out.append("%s<%s> %s" % [n3.name, n3.get_parent().name, n3.global_position.snapped(Vector3.ONE * 0.1)])
	return [at, out.slice(0, 30)]


## Shot driver: press and release a key through the real input path.
func debug_tap_key(key: int) -> void:
	for pressed in [true, false]:
		Input.parse_input_event(debug_key_event(key, pressed))


## Shot driver: the pointer mode (0 visible, 1 hidden, 2 captured).
func debug_mouse_mode() -> int:
	return Input.mouse_mode


## Shot driver: 2D drawn inside the small world view (it is scaled up with it).
func debug_world_2d() -> Array:
	var out := []
	var svc := get_node_or_null("SubViewportContainer")
	if svc == null:
		return out
	for n in svc.find_children("*", "CanvasItem", true, false):
		if n is Control or n is Node2D:
			var par := n.get_parent()
			if par is Control or par is Node2D:
				continue
			out.append(str(n.get_path()).replace("/root/Main/SubViewportContainer/SubViewport/", ""))
	for n in svc.find_children("*", "CanvasLayer", true, false):
		out.append("LAYER " + str(n.get_path()).replace("/root/Main/SubViewportContainer/SubViewport/", ""))
	return out


## Shot driver: hold or let go of the left button where the mouse is.
func debug_press_mouse(pressed: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = pressed
	b.position = get_viewport().get_mouse_position()
	b.global_position = b.position
	Input.parse_input_event(b)


## Shot driver: the mouse over a room task's mess (its first visible mesh).
func debug_aim_task(tasks: Node, task_id: String) -> Vector2:
	var t: Dictionary = tasks.get("_targets").get(task_id, {})
	if t.is_empty():
		return Vector2(-1, -1)
	var at: Vector3 = (t["body"] as Node3D).global_position
	for mm in t["meshes"]:
		if mm is MeshInstance3D and is_instance_valid(mm) and (mm as Node3D).is_visible_in_tree():
			at = (mm as Node3D).global_position
			break
	var cam: Camera3D = tasks.get("_camera")
	var p := debug_screen_of_cam(cam, at)
	get_viewport().warp_mouse(p)
	return p


## Shot driver: start a day event and say where its props stand ([pos, cell, what is
## on that cell]).
func debug_event_spot(kind: String) -> Array:
	var ev: Dictionary = _day_events.debug_start(kind)
	if ev.is_empty():
		return ["no event"]
	var pos: Vector3 = _day_events._event_pos(ev)
	var cell: Vector2i = grid_manager.world_to_grid(pos)
	var tile = grid_manager.get_tile(cell)
	var what := "free"
	if tile != null and tile.occupied and tile.occupant != null:
		what = str(tile.occupant.get_meta("building_type", tile.occupant.name))
	return [pos, cell, what, ev.get("coord")]


## Shot driver: the open Builder's map panel (or null).
## Shot driver: the Builder 98 window's module (catalogue, toolbar), or null.
func debug_builder_module() -> Node:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var ui = bi.get("_crt_ui") if bi != null else null
	if ui == null:
		return null
	for n in ui.find_children("*", "Control", true, false):
		if n.get_script() == load("res://scripts/builder_module.gd"):
			return n
	return null


func debug_builder_map() -> Node:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var ui = bi.get("_crt_ui") if bi != null else null
	if ui == null:
		return null
	for n in ui.find_children("*", "Control", true, false):
		if n.get_script() == load("res://scripts/crt_map_panel.gd"):
			return n
	return null


## Shot driver: close the OS's message boxes (the shareware nag).
func debug_close_msgboxes() -> int:
	var bi = _interior_manager.get("_building_interior") if _interior_manager != null else null
	var ui = bi.get("_crt_ui") if bi != null else null
	if ui == null or not ui.has_method("close_message_boxes"):
		return 0
	return int(ui.close_message_boxes())


## Shot driver: the mouse over a Builder cell (the OS draws the map on the monitor).
func debug_mouse_to_builder_cell(cell: Vector2i) -> Vector2:
	var m := debug_builder_map()
	var bi = _interior_manager.get("_building_interior")
	if m == null or bi == null:
		return Vector2(-1, -1)
	var local: Vector2 = m.call("_cell_iso", Vector2(cell))
	var crt_pos: Vector2 = (m as Control).get_global_transform() * local
	var win: Vector2 = bi.call("debug_crt_to_window", crt_pos)
	get_viewport().warp_mouse(win)
	return win


## Shot driver: the till, and what the state says stands on a cell (autoloads are out of
## the driver's reach).
func debug_money() -> int:
	return int(INSTANCE.core(self).get_state().money)


func debug_cell_type(c: Vector2i) -> String:
	return str((INSTANCE.core(self).get_state().grid.cells.get(c, {}) as Dictionary).get("type", "-"))


## Shot driver: one line of how the night stands (time, director, place, health).
func debug_director_line() -> String:
	var sn: Dictionary = _director.snapshot()
	var last := ""
	if not (sn["recent"] as Array).is_empty():
		last = str((sn["recent"] as Array).back()["id"])
	var aw: Array = _director.arch_weights
	return "%s %s t=%.2f b=%.1f place=%s last=%s hp=%d hunters=%d near=%.0f p=%.2f arch=[%.2f %.2f %.2f %.2f] guests=%s" % [_time_of_day_string(), sn["state"], sn["tension"], sn["budget"], _night_feed.place(), last, int(_player_health), _enemy_brains.size(), float(_senses.nearest),
		float(_night_feed.slow.get("pressure", 0.0)), aw[0], aw[1], aw[2], aw[3], str(_night_feed.slow.get("by_arch", {}))]


## Shot driver: how many guests are in the camp, and set the day.
func debug_guest_count() -> int:
	return INSTANCE.guests(self).get_guest_life_snapshot().size()


func debug_guest_statuses() -> Array:
	var out: Array = []
	for g in INSTANCE.core(self).get_state().guests:
		if g is Dictionary:
			out.append([str(g.get("name", "")), str(g.get("status", "")), str(g.get("archetype", "")), int(g.get("party_size", 0))])
	return out


## What stands on these grid cells (the visual occupants), for blocked builds.
func debug_occupants(coords: Array) -> Array:
	var out: Array = []
	var g = INSTANCE.core(self).get_state().grid
	for c in coords:
		var o = g.occupants.get(c, null)
		out.append(str((o as Node).get_path()).right(70) + ":" + str((o as Node).get_child(0).name if (o as Node).get_child_count() > 0 else "") if o is Node else "-")
	return out


## Shot driver: move the player `frac` of the way to a node under the world (on the ground).
func debug_player_toward(node_name: String, frac: float) -> float:
	var n := _world_3d.get_node_or_null(node_name) as Node3D
	if n == null or _player == null:
		return -1.0
	var to := n.global_position
	to.y = _player.global_position.y
	_player.global_position = _player.global_position.lerp(to, frac)
	return _player.global_position.distance_to(to)


## Shot driver, save round trip: mark the newer state (the director's memory and log, the
## reputation, a reported cabin, DataPunch's nights), save, scramble it in memory, and load
## the save through the main menu as a player would. `debug_saved_bits` reads it back.
func debug_mark_saved_bits() -> void:
	_director.ever["knock"] = 3
	_director.last_log = [{"time": "01:12", "id": "guest_out", "who": "Pepa"}]
	INSTANCE.mail(self).reputation = 0.17
	_day_events.haunted["10:6"] = 3
	var os = _interior_manager._building_interior.get("_crt_ui")
	if os != null:
		os.set_meta("datapunch_nights", {"3": 12})
	# The office's lights off, the back room's lamp off (kept with the save).
	_interior_manager._building_interior.coop_take_office_state({"lights": false, "lamp": false})


func debug_saved_bits() -> Array:
	var os = _interior_manager._building_interior.get("_crt_ui")
	var office: Dictionary = _interior_manager._building_interior.coop_office_state()
	return [int(_director.ever.get("knock", 0)), _director.last_log.duplicate(true), snappedf(INSTANCE.mail(self).reputation, 0.01), _day_events.haunted.duplicate(),
		os.get_meta("datapunch_nights", {}) if os != null else "no os", {"lights": office.get("lights"), "lamp": office.get("lamp")}]


func debug_save_and_reload() -> String:
	var path := request_manual_save("Roundtrip")
	_director.ever.clear()
	_director.last_log = []
	INSTANCE.mail(self).reputation = 0.0
	_day_events.haunted.clear()
	var os = _interior_manager._building_interior.get("_crt_ui")
	if os != null:
		os.set_meta("datapunch_nights", {})
	_interior_manager._building_interior.coop_take_office_state({"lights": true, "lamp": true})
	_enter_main_menu()
	_on_menu_load_requested(path)
	return path


## Shot driver, the bazaar: things in the lost and found, the browser on a page, a link.
func debug_bazaar_fill(n: int) -> int:
	var guard := 0
	while _bazaar.in_box().size() < n and guard < 200:
		_bazaar.on_checkout(["Pepa", "Vlasta", "Novak family"][guard % 3], ["Cabin 10:6", "Tent 16:6", "Cabin 13:6"][guard % 3], _day_index)
		guard += 1
	return _bazaar.in_box().size()


var _debug_browser: Control = null


func debug_browser(url: String) -> bool:
	var w = _interior_manager._building_interior._crt_ui.open_app("browser")
	if w == null or w.content.get_child_count() == 0:
		return false
	_debug_browser = w.content.get_child(0)
	_debug_browser.navigate(url)
	return true


func debug_browser_link(target: String) -> void:
	if _debug_browser != null:
		_debug_browser._on_link(target)


func debug_bazaar() -> Array:
	return [_bazaar.in_box().map(func(i): return [i["id"], i["short"]]), _bazaar.listed().map(func(i): return i["short"]), _bazaar.sold().map(func(i): return [i["short"], i["price"]]), int(INSTANCE.core(self).get_state().money)]


## Shot driver: interior meshes whose box corners land in a screen rect of `cam`
## (fractions of the screen), with their global AABB, to hunt z-fighting.
func debug_meshes_in_rect(cam: Camera3D, rect: Rect2, root: Node) -> Array:
	var out: Array = []
	var vp := cam.get_viewport()
	var size := vp.get_visible_rect().size
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if not m.is_visible_in_tree():
			continue
		var bb := m.global_transform * m.get_aabb()
		var hit := false
		for i in 8:
			var c := bb.get_endpoint(i)
			if cam.is_position_behind(c):
				continue
			var sp := cam.unproject_position(c) / size
			if rect.has_point(sp):
				hit = true
				break
		if hit:
			out.append([str(m.get_path()).right(60), bb.position.snapped(Vector3.ONE * 0.001), bb.size.snapped(Vector3.ONE * 0.001)])
	return out


## Shot driver: a node's mesh children, names and global centres (model debugging).
func debug_parts(n: Node) -> Array:
	var out: Array = []
	if n == null:
		return out
	for m in n.find_children("*", "VisualInstance3D", true, false):
		var v := m as VisualInstance3D
		out.append([str(v.name), (v as Node3D).global_position.snapped(Vector3.ONE * 0.01), v.visible])
	return out


## Shot driver: every checked-in party goes to the first `building_type` now and stays
## `minutes` there (the sim's own visit activity, already arrived).
func debug_send_guests_to(building_type: String, minutes: int = 120, walk := false) -> int:
	var life = INSTANCE.guests(self).get("_life")
	if life == null:
		return 0
	life.refresh_world(INSTANCE.core(self).get_state(), INSTANCE.core(self).registry)
	var fs: Array = (life.get("_facilities") as Array).filter(func(f): return str(f["type"]) == building_type)
	if fs.is_empty():
		return 0
	var f: Dictionary = fs[0]
	var now: int = INSTANCE.guests(self)._absolute_minutes(maxi(1, INSTANCE.guests(self)._last_known_day), INSTANCE.guests(self)._last_known_hour, INSTANCE.guests(self)._last_known_minute)
	var n := 0
	var state = INSTANCE.core(self).get_state()
	for i in state.guests.size():
		var g: Dictionary = state.guests[i]
		if not str(g.get("status", "")) in ["active", "sleep"]:
			continue
		var here: Vector2i = life._parse_key(str(g.get("tile", "")))
		var act: Dictionary = life._make_activity("visit", here, life._door_tile(f, here), now if walk else now - 20, minutes, "fun", f)
		if not walk:
			act["arrive"] = now - 1
			act["end"] = now + minutes
		g["activity"] = act
		g["status"] = "active"
		state.guests[i] = g
		n += 1
	return n


func debug_guest_thoughts() -> Array:
	var out: Array = []
	for g in INSTANCE.core(self).get_state().guests:
		if g is Dictionary:
			out.append([str(g.get("name", "")), str(g.get("thought", ""))])
	return out


func debug_set_day(day: int) -> void:
	INSTANCE.core(self).apply_changes({"day": maxi(1, day)})
	_sync_runtime_state_from_systems(true)


## Shot driver: play a director event now, as the director would ([where, place]).
func debug_director(id: String) -> Array:
	var ctx := _director_context()
	var at: Vector3 = _director_fx.run(id, ctx)
	return [at, ctx.get("place", "")]


## Shot driver: CampStat on one of its tabs.
func debug_campstat_tab(id: String) -> void:
	var bi = _interior_manager.get("_building_interior")
	var ui = bi.get("_crt_ui") if bi != null else null
	if ui == null:
		return
	for n in ui.find_children("*", "Control", true, false):
		if n.get_script() == load("res://scripts/os98/apps/campstat_app.gd"):
			n.select_page(id)


## Shot driver: a key press or release for Input.parse_input_event.
func debug_key_event(key: int, pressed: bool) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = key
	k.physical_keycode = key
	k.pressed = pressed
	return k


## Shot driver: a real click (press and release) at a window point.
func debug_click_at(x: float, y: float, button := MOUSE_BUTTON_LEFT) -> void:
	get_viewport().warp_mouse(Vector2(x, y))
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = button
		b.pressed = pressed
		b.position = Vector2(x, y)
		b.global_position = b.position
		Input.parse_input_event(b)


## Shot driver: the Control under the mouse (what eats a click), as a path.
func debug_hovered_control() -> String:
	var c := get_viewport().gui_get_hovered_control()
	return str(c.get_path()) if c != null else "<none>"


## Shot driver: where a 3D point is on the window through a camera that may render
## into the small retro viewport.
func debug_screen_of_cam(cam: Camera3D, p: Vector3) -> Vector2:
	if cam == null:
		return Vector2(-1, -1)
	var own := cam.get_viewport().get_visible_rect().size
	return cam.unproject_position(p) * get_viewport().get_visible_rect().size / own


## Shot driver: where a 3D point is on the window through the current camera.
func debug_screen_of(p: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(p) if cam != null else Vector2(-1, -1)


func debug_perf() -> Array:
	return [Engine.get_frames_per_second(), snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01), snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


## Tools: real input through the whole pipeline (a small mouse move, a click, a key).
func debug_input(kind: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	match kind:
		"move":
			var m := InputEventMouseMotion.new()
			m.position = vp * 0.5 + Vector2(randf_range(-3, 3), 1)
			m.global_position = m.position
			m.relative = Vector2(1.5, 0.5)
			Input.parse_input_event(m)
		"click":
			for pressed in [true, false]:
				var b := InputEventMouseButton.new()
				b.button_index = MOUSE_BUTTON_LEFT
				b.pressed = pressed
				b.position = vp * 0.5
				b.global_position = b.position
				Input.parse_input_event(b)
		"key":
			for pressed in [true, false]:
				var k := InputEventKey.new()
				k.physical_keycode = KEY_SHIFT
				k.keycode = KEY_SHIFT
				k.pressed = pressed
				Input.parse_input_event(k)


## Parties on the way or at reception, and who waits at the desk (shot driver).
func debug_arrivals() -> Array:
	return [INSTANCE.guests(self).get_arrivals(), INSTANCE.guests(self).get_desk_queue().size(), INSTANCE.guests(self).get_key_board()]


## What the core grid holds at these cells, and the money (shot driver).
func debug_cells(coords: Array) -> Array:
	var out: Array = []
	for c in coords:
		out.append(str(INSTANCE.core(self).get_state().grid.get_cell_data(c).get("type", "-")))
	out.append(INSTANCE.core(self).get_money())
	return out


## The bulldozer over a rect, as the Builder would (shot driver, harnesses).
func debug_demolish_rect(rect: Rect2i) -> void:
	EventBus.RequestDemolish.emit(rect)


## Tools: the frames a second now (the shot driver's eval cannot reach Engine).
func debug_fps() -> float:
	return Engine.get_frames_per_second()


## Tools: today's first applicant taken on at the staffroom (its slug, "" none).
func debug_hire_hand() -> String:
	var app: Array = load("res://core/systems/staff_rules.gd").applicants(_day_index, [], 7)
	if app.is_empty() or INSTANCE.core(self).actions == null or not INSTANCE.core(self).actions.staff_hire(app[0], _day_index):
		return ""
	return str(app[0].get("slug", ""))


func debug_structure_of_type(building_type: String) -> Node3D:
	var root = building_manager.get_node_or_null("Structures") if building_manager != null else null
	if root == null:
		return null
	for child in root.get_children():
		if str(child.get_meta("building_type", "")) == building_type:
			return child
	return null


## Debug/test entry: put the clock on `day` at `hours` (no nights are played in between).
func debug_jump_to(day: int, hours: float) -> void:
	INSTANCE.core(self).apply_changes({"day": maxi(1, day)})
	if time_system != null:
		time_system.set_time_hours(hours)
	_sync_runtime_state_from_systems(true)


## Debug/test entry: start one enemy now regardless of the night roll.
func debug_spawn_enemy(enemy_id: String, difficulty: int = 3) -> void:
	var scripts := {"silent_man": SILENT_MAN_BRAIN_SCRIPT, "tourist": TOURIST_BRAIN_SCRIPT, "girl": GIRL_BRAIN_SCRIPT, "stalker": STALKER_BRAIN_SCRIPT,
		"whistler": ENEMY_FOR_ARCHETYPE["tramp"], "child": ENEMY_FOR_ARCHETYPE["family"], "basket": ENEMY_FOR_ARCHETYPE["picker"]}
	if scripts.has(enemy_id):
		# A second of the same (the Silent Men): its own name for the night's picture.
		var nth := 0
		for b in _enemy_brains:
			if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == enemy_id:
				nth += 1
		_night_roll.start_brain(scripts[enemy_id], _day_index, difficulty, {"nth": nth} if nth > 0 else {})


func _debug_damage_player() -> void:
	if not _gameplay_started or _menu_mode or _game_over_active:
		return
	damage_player(DEBUG_DAMAGE_AMOUNT)


func _debug_add_money() -> void:
	if not _gameplay_started or _menu_mode or _game_over_active:
		return
	if CoreRoot == null or INSTANCE.core(self).actions == null or not INSTANCE.core(self).actions.has_method("add_money"):
		return
	INSTANCE.core(self).actions.add_money(DEBUG_MONEY_AMOUNT)
	_refresh_liminal_debug_window()


## Shot driver: patch the old cabin up as hold R would (no charge).
func debug_repair_ruined() -> bool:
	return _ruin.debug_repair()


## Lambdas hooked to the autoloads' signals (the title after a game logged "Lambda capture
## at index 0 was freed": a lambda left connected after what it holds was freed): the
## autoload, the signal and the lambda as Godot names it.
func debug_lambda_hooks() -> Array:
	var out: Array = []
	for auto in ["EventBus", "CoreRoot", "GuestManager", "EmailManager", "Coop", "GameSettings", "SaveManager"]:
		var n := get_node_or_null("/root/" + auto)
		if n == null:
			continue
		for sig in n.get_signal_list():
			for c in n.get_signal_connection_list(str(sig["name"])):
				var cb: Callable = c["callable"]
				if cb.is_custom():
					out.append("%s.%s %s" % [auto, str(sig["name"]), str(cb)])
	return out


## Harnesses: a split screen's second warden started in this program (a co-op client on the
## loopback line, scripts/instance/local_client.gd), with pad `device`; its node.
func debug_local_client(device: int) -> Node:
	return load("res://scripts/instance/local_client.gd").start(self, device)
