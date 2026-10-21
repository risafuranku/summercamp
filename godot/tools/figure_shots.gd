extends "res://tools/shot_driver.gd"

## People seen from eight sides, as in Doom (scripts/figures/doom_figure.gd): the other
## warden (a co-op figure fed made-up states) from eight sides standing, then walking and
## running round a ring as the camera stands still, all nine jacket colours from the front
## and the side, and a camp full of guests at noon and in the evening.
##   godot --path godot --resolution 1280x720 res://tools/figure_shots.tscn -- --out=<dir> [--part=warden|colors|guests|all] [--model=0..3]

const REMOTE = preload("res://scripts/coop/remote_player.gd")
## The body's origin is this far under the feet (remote_player.FEET_Y).
const FEET := 0.35

var _figs: Array = []
var _cam: Camera3D
var _centre := Vector3.ZERO
var _mode := "stand"
var _t := 0.0
var _speed := 0.0
var _yaw := 0.0
var _model := 0


func _burst(name: String, n: int, dt: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(["shot", "%s_%d" % [name, i]])
		out.append(["wait", dt])
	return out


func _ready() -> void:
	super._ready()
	var part := "all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--part="):
			part = arg.get_slice("=", 1)
		elif arg.begins_with("--model="):
			_model = int(arg.get_slice("=", 1))
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "debug_jump_to(1, 11.0)"], ["wait", 3.0],
		["money", 90000], ["clear", 6, 1, 9, 8], ["wait", 0.5],
	]
	if part in ["warden", "all"]:
		s.append_array([["self", "_spawn", [[0]], ], ["wait", 0.5]])
		for i in 8:
			s.append_array([["self", "_orbit", [i * 45.0, 3.2]], ["wait", 0.35], ["shot", "w_stand_%d" % i], ["self", "_dump", []]])
		# Walking round a ring (the camera still): every side passes by.
		s.append_array([["self", "_orbit", [0.0, 6.5]], ["self", "_go", ["ring", 1.3]], ["wait", 0.6]])
		s.append_array(_burst("w_walk", 24, 0.2))
		s.append_array([["self", "_go", ["ring", 5.0]], ["wait", 0.6]])
		s.append_array(_burst("w_run", 16, 0.12))
		# Along a line past the camera from the side, close: the feet on the ground.
		s.append_array([["self", "_orbit", [90.0, 3.0]], ["self", "_go", ["line", 1.3]], ["wait", 0.3]])
		s.append_array(_burst("w_side", 12, 0.1))
		s.append_array([["self", "_go", ["stand", 0.0]], ["self", "_clear", []]])
	if part in ["colors", "all"]:
		for m in 4:
			s.append_array([["self", "_colours", [m]], ["self", "_orbit", [0.0, 6.0]], ["wait", 0.5], ["shot", "c_%d_front" % m],
				["self", "_orbit", [135.0, 6.0]], ["wait", 0.5], ["shot", "c_%d_back" % m],
				["self", "_go", ["march", 1.3]], ["self", "_orbit", [0.0, 7.0]], ["wait", 0.7], ["shot", "c_%d_walk_front" % m],
				["self", "_orbit", [90.0, 7.0]], ["wait", 0.5], ["shot", "c_%d_walk_side" % m], ["self", "_clear", []]])
	if part in ["guests", "all"]:
		# A full camp: thirty-two tents and four cabins on cleared land, the parties let in at
		# once (GuestManager.debug_check_in_party), then all sent walking to the fire.
		s.append_array([["money", 90000], ["clear", 1, 3, 18, 12], ["wait", 0.5]])
		for x in range(2, 10):
			for y in [4, 6, 8, 10]:
				s.append(["build", "tent_1", x, y, 0])
		for c in [[12, 4], [15, 4], [12, 8], [15, 8]]:
			s.append(["build", "cabin_1", c[0], c[1], 0])
		for y in range(4, 13):
			s.append(["build", "path", 10, y, 0])
		s.append_array([["build", "toilet_block", 4, 12, 0], ["build", "shower_block", 6, 12, 0], ["build", "bonfire", 13, 12, 0],
			["build", "picnic_table", 8, 13, 0], ["build", "bench", 11, 13, 0], ["build", "lamp_post", 11, 7, 0], ["wait", 0.5], ["prep_all"]])
		var who := [["quiet_guy", 2], ["drunk", 2], ["cheap_chick", 2], ["tramp", 2], ["family", 4], ["picker", 2], ["drunk", 2], ["quiet_guy", 2],
			["tramp", 2], ["family", 4], ["picker", 2], ["cheap_chick", 2], ["family", 4], ["drunk", 2], ["tramp", 2], ["family", 4]]
		for i in who.size():
			s.append_array([["prep_all"], ["gm", "debug_check_in_party", "Guest %d" % i, who[i][0], who[i][1], 2]])
		s.append_array([["wait", 1.0], ["player", 10, 2, 180.0], ["timescale", 3.0], ["wait", 25.0], ["timescale", 1.0], ["wait", 2.0],
			["self", "_perf", ["noon, walking to the fire"]], ["wait", 2.5], ["self", "_crowd", [7.0, 2.2]], ["wait", 0.3], ["shot", "g_noon_0"], ["wait", 1.5], ["shot", "g_noon_1"],
			["wait", 6.0], ["self", "_crowd", [6.0, 1.8]], ["wait", 0.3], ["shot", "g_noon_2"], ["wait", 1.0], ["shot", "g_noon_3"], ["self", "_drop_cam", []],
			["topdown", 10, 8, 10.0, 45.0], ["wait", 1.0], ["shot", "g_noon_top"], ["self", "_drop_cam", []],
			["eval", "debug_jump_to(1, 19.5)"], ["wait", 3.0], ["player", 10, 3, 180.0], ["timescale", 3.0], ["wait", 15.0], ["timescale", 1.0], ["wait", 2.0],
			["self", "_perf", ["evening, walking"]], ["wait", 2.5], ["self", "_crowd", [7.0, 2.2]], ["wait", 0.3], ["shot", "g_evening_0"], ["wait", 1.5], ["shot", "g_evening_1"], ["self", "_drop_cam", []],
			["topdown", 10, 8, 10.0, 45.0], ["wait", 1.0], ["shot", "g_evening_top"]])
	_steps = s


func _run_step(step: Array) -> void:
	if str(step[0]) == "self":
		callv(str(step[1]), step[2] if step.size() > 2 else [])
		return
	super._run_step(step)


func _world() -> Node3D:
	return _main.get("_world_3d") as Node3D


func _spawn(models: Array) -> void:
	var gm = _main.get("grid_manager")
	_centre = gm.grid_to_world(Vector2i(10, 4))
	for m in models:
		var f: Node3D = REMOTE.new()
		_world().add_child(f)
		f.setup(int(m), 0)
		f.set_meta("coop_id", 99)
		_figs.append(f)
	_mode = "stand"
	_t = 0.0
	_yaw = 0.0


## Nine of warden `m` side by side in the nine colours, facing you.
func _colours(m: int) -> void:
	var gm = _main.get("grid_manager")
	_centre = gm.grid_to_world(Vector2i(10, 4))
	for c in 9:
		var f: Node3D = REMOTE.new()
		_world().add_child(f)
		f.setup(m, c)
		f.set_meta("coop_id", 99)
		f.set_meta("slot", c)
		_figs.append(f)
	_mode = "row"


func _clear() -> void:
	for f in _figs:
		if is_instance_valid(f):
			f.queue_free()
	_figs.clear()


## The camera `dist` from the centre at `deg` round it (0: in front of a figure facing -Z,
## i.e. on its -Z side), at eye height, looking at it.
func _orbit(deg: float, dist: float) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 60.0
		_world().add_child(_cam)
		_main.set("debug_camera", _cam)
	var a := deg_to_rad(deg)
	_cam.global_position = _centre + Vector3(sin(a), 0.0, -cos(a)) * dist + Vector3(0, 1.5, 0)
	_cam.look_at(_centre + Vector3(0, 0.95, 0), Vector3.UP)


## A camera `dist` back from the middle of the guests out (the most of them), `up` high,
## looking at them from the south-east.
func _crowd(dist: float, up: float) -> void:
	var ga = _main.get("_guest_agents")
	var sum := Vector3.ZERO
	var pts: Array = []
	for p in ga.get("_parties").values():
		for m in p["members"]:
			if (m as Node3D).is_visible_in_tree():
				pts.append((m as Node3D).global_position)
				sum += (m as Node3D).global_position
	if pts.is_empty():
		return
	var mid: Vector3 = sum / float(pts.size())
	# The densest spot: the member with the most others within 4 m.
	var best := 0
	for q in pts:
		var c := 0
		for r in pts:
			if (q as Vector3).distance_to(r) < 4.0:
				c += 1
		if c > best:
			best = c
			mid = q
	_centre = mid
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 60.0
		_world().add_child(_cam)
		_main.set("debug_camera", _cam)
	_cam.global_position = mid + Vector3(dist * 0.7, up, dist * 0.7)
	_cam.look_at(mid + Vector3(0, 0.9, 0), Vector3.UP)


## Back to the warden's own eyes.
func _drop_cam() -> void:
	var c = _main.get("debug_camera")
	if c != null and is_instance_valid(c):
		c.queue_free()
	_main.set("debug_camera", null)
	_cam = null


func _go(mode: String, speed: float) -> void:
	_mode = mode
	_speed = speed
	_t = 0.0


func _dump() -> void:
	for f in _figs:
		var sp: Sprite3D = f.get_node("Sprite")
		print("FIGURE SHOTS fig vis=%s inside=%s pos=%s tex=%s region=%s %s off=%s px=%s cam=%s cur=%s" % [f.visible, f.is_inside_tree(), f.global_position, sp.texture, sp.region_enabled, sp.region_rect, sp.offset, sp.pixel_size, _cam.global_position if _cam else null, get_viewport().get_camera_3d()])


## Frames a second (the project caps them at 50) and the main thread's time a frame,
## averaged over two seconds, with how many guest figures are out.
func _perf(label: String) -> void:
	# Uncapped for the measure (the project's 50 and the vsync would hide the cost).
	var cap := Engine.max_fps
	var vs := DisplayServer.window_get_vsync_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(0.5).timeout
	var t := 0.0
	var n := 0
	var t_end := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		t += Performance.get_monitor(Performance.TIME_PROCESS)
		n += 1
	var figs := 0
	var ga = _main.get("_guest_agents")
	if ga != null:
		for p in ga.get("_parties").values():
			for m in p["members"]:
				if (m as Node3D).is_visible_in_tree():
					figs += 1
	var fps := Engine.get_frames_per_second()
	Engine.max_fps = cap
	DisplayServer.window_set_vsync_mode(vs)
	print("FIGURE SHOTS perf %s: fps %d, process %.2f ms a frame, %d frames, %d guest figures out" % [label, fps, t / maxf(1.0, float(n)) * 1000.0, n, figs])


func _report_fps(label: String) -> void:
	var n := 0
	var ga = _main.get("_guest_agents")
	if ga != null:
		for p in ga.get("_parties").values():
			n += (p["members"] as Array).size()
	print("FIGURE SHOTS fps %s: %d (figures %d)" % [label, Engine.get_frames_per_second(), n])


func _physics_process(delta: float) -> void:
	if _figs.is_empty():
		return
	_t += delta
	for i in _figs.size():
		var f = _figs[i]
		if not is_instance_valid(f):
			continue
		var p := _centre
		var yaw := _yaw
		var v := 0.0
		match _mode:
			"ring":
				var r := 2.2
				var a := _t * _speed / r
				p = _centre + Vector3(cos(a), 0.0, sin(a)) * r
				# Going round anticlockwise seen from above: facing along the ring.
				var d := Vector3(-sin(a), 0.0, cos(a))
				yaw = atan2(-d.x, -d.z)
				v = _speed
			"line":
				var span := 5.0
				var k := fposmod(_t * _speed, span * 2.0)
				var x := k - span * 0.5 if k < span else span * 1.5 - k
				var dir := 1.0 if k < span else -1.0
				p = _centre + Vector3(0.0, 0.0, x)
				yaw = atan2(0.0, -dir)
				v = _speed
			"row":
				p = _centre + Vector3((float(int(f.get_meta("slot", 0))) - 4.0) * 0.8, 0.0, 0.0)
				yaw = 0.0
			"march":
				# The row walking toward -Z (the camera at 0 degrees), 3 m and back to the start.
				p = _centre + Vector3((float(int(f.get_meta("slot", 0))) - 4.0) * 0.8, 0.0, 1.5 - fposmod(_t * _speed, 3.0))
				yaw = 0.0
				v = _speed
		f.push_state({"p": p - Vector3(0, FEET, 0), "y": yaw, "v": v, "t": false, "in": false})
