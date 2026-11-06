extends "res://tools/shot_driver.gd"

## Where the game catches (the polish pass of 4. 11.): every frame over 40 ms from the
## new camp's first frame on, with the time it came; then the second night and every
## thing that comes for the camp made one after another, the head turned to it, the cost
## of making it and the worst frame of its first seconds in sight. Lines "TRHNUTI ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/trhnuti_check.tscn -- --out=DIR [--part=start|night]

const C := "get_tree().root.get_node('TrhnutiCheck')"
const THINGS := ["silent_man", "tourist", "girl", "stalker", "whistler", "child", "basket"]

var _log := false
var _t0 := 0
var _last := 0
var _worst := 0.0
var _long: Array = []
var _look := false


func pl() -> Node3D:
	return _main.get("_player")


func log_frames(on: bool, tag := "") -> void:
	if on:
		_log = true
		_t0 = Time.get_ticks_usec()
		_last = _t0
		_worst = 0.0
		_long.clear()
		return
	_log = false
	print("TRHNUTI %s: worst %.0f ms, %d frames over 40 ms" % [tag, _worst / 1000.0, _long.size()])
	for l in _long:
		print("TRHNUTI   at %.2f s: %.0f ms  %s" % [l[0], l[1], l[2]])


## What the last frame did: script time, physics, the pipelines compiled (shaders).
func _monitors() -> String:
	var pc := 0
	for m in [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE,
			Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		pc += int(Performance.get_monitor(m))
	return "process %.0f ms, physics %.0f ms, pipelines %d, objects %d, video %.0f MB, started %s crt %s" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		pc, int(Performance.get_monitor(Performance.OBJECT_COUNT)), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		str(_main.get("_gameplay_started")) if _main != null else "-", str(_main.call("_is_crt_desktop_active")) if _main != null and _main.has_method("_is_crt_desktop_active") else "-"]


func _frame() -> void:
	var now := Time.get_ticks_usec()
	if _log:
		var d := float(now - _last)
		_worst = maxf(_worst, d)
		if d > 40000.0:
			_long.append([float(now - _t0) / 1000000.0, d / 1000.0, _monitors() + " at " + str(_main.get("time_system").call("get_time_string")) if _main != null and _main.get("time_system") != null else _monitors()])
	_last = now
	if _look:
		_turn_to_thing()


func _turn_to_thing() -> void:
	var brains: Array = _main.get("_enemy_brains")
	var p := pl()
	if brains.is_empty() or p == null:
		return
	var body = brains.back().get("_body")
	if body == null or not is_instance_valid(body):
		return
	var to: Vector3 = (body as Node3D).global_position - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)


## One thing made now: what making it costs, then the worst frame of its first 4 s with
## the head on it.
func thing(id: String) -> void:
	_main.call("_stop_active_enemy_brain")
	var t := Time.get_ticks_usec()
	_main.call("debug_spawn_enemy", id, 3)
	print("TRHNUTI %s made in %.0f ms" % [id, float(Time.get_ticks_usec() - t) / 1000.0])
	_look = true
	log_frames(true)


func thing_done(id: String) -> void:
	_look = false
	log_frames(false, id + " first seconds")


func brains() -> void:
	var ids := []
	for b in _main.get("_enemy_brains"):
		ids.append(str(b.get_enemy_id()))
	print("TRHNUTI out tonight: %s" % str(ids))


## A party of every kind of guest in (each brings its thing).
func guests() -> void:
	var gm = get_node_or_null("/root/GuestManager")
	for k in ["quiet_guy", "drunk", "cheap_chick", "tramp", "family", "picker"]:
		gm.call("debug_check_in_party", "Test " + k, k, 2, 4)


## What getting a business's room ready at its door costs.
func make_up(ty: String, round: int) -> void:
	var si = _main.get("_interior_manager").get("_service_interior")
	var st: Node3D = _main.call("debug_structure_of_type", ty)
	var o0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var v0 := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var before := _cached()
	var t := Time.get_ticks_usec()
	si.call("door_ready", st)
	var ms := float(Time.get_ticks_usec() - t) / 1000.0
	var fresh := PackedStringArray()
	for p in _cached():
		if not before.has(p):
			fresh.append(p)
	print("TRHNUTI make up %s, round %d: %.0f ms, %d objects, %.0f MB, %d files loaded" % [ty, round, ms,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)) - o0, (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) - v0) / 1048576.0, fresh.size()])
	for p in fresh:
		print("LOADED %s %s" % [ty, p])


## Everything the loader holds now, of what is in the project.
var _all_files := PackedStringArray()


func _cached() -> Dictionary:
	if _all_files.is_empty():
		for r in ["res://assets", "res://scripts", "res://data", "res://materials"]:
			_walk(r)
	var out := {}
	for p in _all_files:
		if ResourceLoader.has_cached(p):
			out[p] = true
	return out


func _walk(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		_walk(dir + "/" + d)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import"):
			_all_files.append(dir + "/" + f.trim_suffix(".import"))
		elif not f.ends_with(".uid"):
			_all_files.append(dir + "/" + f)


## Which rooms' eyes are open now (each room's viewport, 0 shut, 4 drawing).
func eyes(tag: String) -> void:
	var im: Node = _main.get("_interior_manager")
	var out := []
	for k in ["_building_interior", "_cabin_interior", "_tent_interior", "_caravan_interior", "_service_interior", "_bowling_interior"]:
		var it = im.get(k)
		var vp = it.get("_viewport") if it != null else null
		out.append("%s %s" % [k.replace("_interior", "").trim_prefix("_"), str(vp.render_target_update_mode) if vp != null else "-"])
	print("TRHNUTI eyes %s: %s" % [tag, ", ".join(out)])


## What one autosave costs on its own, its parts apart.
func time_save() -> void:
	var t := Time.get_ticks_usec()
	var snap: Dictionary = _main.call("_build_save_snapshot", "Autosave", "autosave")
	var t1 := Time.get_ticks_usec()
	var path: String = SaveManager.write_save(snap, "Autosave", "autosave")
	var t2 := Time.get_ticks_usec()
	_main.call("_after_save", snap)
	var t3 := Time.get_ticks_usec()
	print("TRHNUTI autosave: snapshot %.0f ms, write %.0f ms (%s), after %.0f ms, %d KB" % [float(t1 - t) / 1000.0, float(t2 - t1) / 1000.0, path,
		float(t3 - t2) / 1000.0, (FileAccess.get_file_as_bytes(path).size() / 1024) if path != "" else -1])


## The line's parts apart: the course, its stretches, a round's plan, one bus.
func time_line() -> void:
	var trip = _main.get("_interior_manager").get("_town_trip")
	var LINE = load("res://scripts/town/bus_line.gd")
	var t := Time.get_ticks_usec()
	var l = LINE.new()
	l.build(trip._road())
	var t1 := Time.get_ticks_usec()
	for pair in [["start", "l_down"], ["l_down", "p_down"], ["p_down", "camp"], ["l_down", "camp"], ["camp", "p_up"], ["p_up", "l_up"], ["camp", "l_up"], ["l_up", "end"]]:
		l.hours(pair[0], pair[1])
	var t2 := Time.get_ticks_usec()
	var n: int = l.on_road(trip.abs_hour()).size()
	var t3 := Time.get_ticks_usec()
	var bus = trip._new_bus()
	var t4 := Time.get_ticks_usec()
	bus.queue_free()
	print("TRHNUTI line: course %.0f ms, stretches %.0f ms, on_road %.0f ms (%d), one bus %.0f ms" % [float(t1 - t) / 1000.0, float(t2 - t1) / 1000.0,
		float(t3 - t2) / 1000.0, n, float(t4 - t3) / 1000.0])


## The land's build, step by step, a second one off the tree (its parts' cost).
func time_geo() -> void:
	var trip = _main.get("_interior_manager").get("_town_trip")
	var G = load("res://scripts/geo/geo_world.gd")
	var g = G.new()
	var wg = trip._worldgen()
	var out := []
	var t := Time.get_ticks_usec()
	g.worldgen = wg
	g._data = load("res://scripts/geo/geo_data.gd").data()
	for step in ["_make_index", "_keep_lake_clear", "_hide_horizon_hills", "_ground", "_land", "_water", "_roads", "_benzina", "_village_signs"]:
		var t0 := Time.get_ticks_usec()
		g.call(step)
		out.append("%s %.0f" % [step, float(Time.get_ticks_usec() - t0) / 1000.0])
	print("TRHNUTI geo build parts (ms): " + ", ".join(out) + " total %.0f" % (float(Time.get_ticks_usec() - t) / 1000.0))
	var t1 := Time.get_ticks_usec()
	trip._place_towns()
	print("TRHNUTI place_towns %.0f ms" % (float(Time.get_ticks_usec() - t1) / 1000.0))
	g.free()


func time_call(method: String, args: Array) -> void:
	var t := Time.get_ticks_usec()
	_main.callv(method, args)
	print("TRHNUTI %s took %.0f ms" % [method, float(Time.get_ticks_usec() - t) / 1000.0])


func _ready() -> void:
	super._ready()
	get_tree().process_frame.connect(_frame)
	var part := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.substr(7)
	var steps: Array = [["wait_menu"], ["wait", 1.0]]
	if part == "bizrooms":
		# The businesses, each room built the first time and the second: what it costs at the
		# door (door_ready), then each walked into. "TRHNUTI make up ...".
		var bt: Array = ["pub", "restaurant", "vecerka", "staffroom", "toilet_block", "shower_block"]
		var st: Array = steps + [["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 8.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0],
			["money", 400000], ["clear", 4, 9, 5, 5], ["clear", 9, 9, 5, 5], ["clear", 9, 14, 5, 5], ["clear", 4, 14, 5, 5], ["clear", 14, 9, 5, 5], ["clear", 14, 14, 5, 5],
			["build", "pub", 5, 10, 0], ["build", "restaurant", 10, 10, 0], ["build", "vecerka", 10, 15, 0], ["build", "staffroom", 5, 15, 0], ["build", "toilet_block", 15, 10, 0], ["build", "shower_block", 15, 15, 0],
			["wait", 2.0], ["eval", "debug_jump_to(1, 13.0)"], ["wait", 2.0]]
		for round in 2:
			for ty in bt:
				st += [["eval", C + ".make_up('%s', %d)" % [ty, round + 1]], ["wait", 1.0]]
		for ty in bt:
			st += [["door_front", ty, 2.0], ["wait", 1.5], ["eval", C + ".log_frames(true)"],
				["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('%s'))" % ty], ["wait", 5.0],
				["eval", C + ".log_frames(false, '%s in')" % ty], ["shot", ty], ["eval", C + ".eyes('%s')" % ty],
				["eval", C + ".log_frames(true)"], ["eval", "_interior_manager._service_interior.close_service()"], ["wait", 3.0],
				["eval", C + ".log_frames(false, '%s out')" % ty], ["eval", C + ".eyes('%s out')" % ty]]
		_steps = st + [["eval", "get_tree().quit()"]]
		return
	if part == "firstrooms":
		# Every kind of room walked into by its door, the first time and the second, its eye
		# shut till then (interior_manager._tick_eyes): the worst frames in and out, a picture.
		var st: Array = steps + [["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 8.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0],
			["money", 400000], ["clear", 4, 9, 5, 5], ["clear", 9, 9, 5, 5], ["clear", 9, 14, 5, 5], ["clear", 4, 14, 5, 5],
			["build", "caravan_1", 5, 10, 0], ["build", "pub", 10, 10, 0], ["build", "restaurant", 10, 15, 0], ["build", "toilet_block", 5, 15, 0],
			["eval", "_build_test_camp('')"], ["wait", 1.0], ["eval", "debug_repair_ruined()"], ["wait", 2.0], ["eval", "debug_jump_to(1, 13.0)"], ["wait", 2.0]]
		var rooms := [["tent_1", 1.4, "_tent_interior.close_tent()"], ["cabin_1", 1.6, "_cabin_interior.close_cabin()"], ["caravan_1", 1.6, "_caravan_interior.close_caravan()"],
			["pub", 2.0, "_service_interior.close_service()"], ["restaurant", 2.0, "_service_interior.close_service()"], ["toilet_block", 2.0, "_service_interior.close_service()"]]
		for r in rooms:
			for visit in 2:
				var tag := "%s %d" % [r[0], visit + 1]
				st += [["door_front", r[0], r[1]], ["wait", 1.5], ["eval", C + ".log_frames(true)"],
					["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('%s'))" % r[0]], ["wait", 5.0],
					["eval", C + ".log_frames(false, '%s in')" % tag], ["shot", "%s_%d" % [r[0], visit + 1]],
					["eval", C + ".eyes('%s')" % tag],
					["eval", C + ".log_frames(true)"], ["eval", "_interior_manager." + str(r[2])], ["wait", 3.0],
					["eval", C + ".log_frames(false, '%s out')" % tag], ["eval", C + ".eyes('%s out')" % tag]]
		_steps = st + [["eval", "get_tree().quit()"]]
		return
	if part == "walkout":
		# The way everybody first leaves: up from the PC, out by the door, in and out again.
		var bi := "_interior_manager._building_interior"
		_steps = steps + [["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 10.0],
			["eval", C + ".log_frames(true)"], ["eval", bi + "._exit_crt_view()"], ["wait", 3.0], ["eval", C + ".log_frames(false, 'up from the pc')"],
			["eval", C + ".log_frames(true)"], ["eval", bi + "._extras.handle_exit()"], ["wait", 6.0], ["eval", C + ".log_frames(false, 'out by the door')"],
			["eval", C + ".log_frames(true)"], ["door_front", "main_building", 2.0], ["wait", 0.5],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('main_building'))"], ["wait", 6.0], ["eval", C + ".log_frames(false, 'in by the door')"],
			["eval", C + ".log_frames(true)"], ["eval", bi + "._extras.handle_exit()"], ["wait", 6.0], ["eval", C + ".log_frames(false, 'out again')"],
			["eval", "get_tree().quit()"]]
		return
	if part != "night" and part != "nightstart" and part != "latenight":
		steps += [
			["eval", C + ".log_frames(true)"],
			["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 12.0],
			["eval", C + ".log_frames(false, 'new camp')"],
			["eval", C + ".log_frames(true)"],
			["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 2.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 3.0],
			["eval", C + ".log_frames(false, 'up and out')"],
			["eval", C + ".time_save()"], ["wait", 0.5], ["eval", C + ".time_line()"], ["wait", 0.5], ["eval", C + ".time_line()"],
			["wait", 0.5], ["eval", C + ".time_geo()"],
		]
	else:
		steps += [["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0]]
	if part == "latenight":
		# The small hours of the second night at the real clock, a thing out: every frame
		# over 40 ms with the clock's time (the fast-clock soak had 150-216 ms at 2-3 am).
		steps += [
			["eval", "_build_test_camp('')"], ["wait", 1.0],
			["eval", C + ".guests()"], ["wait", 1.0],
			["eval", "debug_jump_to(2, 19.95)"], ["until", "_enemy_brains.size() > 0", 30.0],
			["eval", "debug_jump_to(3, 1.6)"], ["wait", 3.0],
			["eval", C + ".log_frames(true)"], ["wait", 150.0],
			["eval", C + ".log_frames(false, 'the small hours, 1:36 to 4:40')"],
			["eval", "get_tree().quit()"],
		]
		_steps = steps
		return
	if part == "nightstart":
		# The second night's start with a guest of every kind in: every thing made at 20:00.
		steps += [
			["eval", "_build_test_camp('')"], ["wait", 1.0],
			["eval", C + ".guests()"], ["wait", 1.0],
			["eval", "debug_jump_to(2, 19.9)"], ["wait", 3.0],
			["eval", C + ".log_frames(true)"],
			["until", "_enemy_brains.size() > 0", 30.0], ["wait", 3.0],
			["eval", C + ".log_frames(false, 'night 2 begins, every kind in')"],
			["eval", C + ".brains()"],
			["eval", "get_tree().quit()"],
		]
		_steps = steps
		return
	if part != "start":
		steps += [
			["eval", C + ".log_frames(true)"],
			["eval", "debug_jump_to(2, 20.05)"], ["wait", 6.0],
			["eval", C + ".log_frames(false, 'the second night begins')"],
		]
		for id in THINGS:
			steps += [["eval", C + ".thing('%s')" % id], ["wait", 4.0], ["eval", C + ".thing_done('%s')" % id], ["wait", 1.0]]
	steps += [["eval", "get_tree().quit()"]]
	_steps = steps
