extends Node

## The title screen's camera: a slow first-person drift through the camp along a
## Catmull-Rom loop through the placed structures (or a zig-zag over an empty map),
## banking into turns with a little head bob. Extracted from main.gd.

const MENU_FPV_SPEED := 9.2
const MENU_FPV_HEIGHT := 2.9
const MENU_FPV_LOOK_HEIGHT := 2.8
const MENU_FPV_BOB_AMPLITUDE := 0.22
const MENU_FPV_BANK_MAX_RAD := 0.16
const MENU_FPV_DRIFT_STRENGTH := 1.25
const MENU_FPV_LOOK_AHEAD := 0.18
const MENU_FPV_STEER_LERP := 3.2
const MENU_FPV_REFRESH_SEC := 9.0

var fallback_camera: Camera3D
var grid_manager: Node3D
var building_manager: Node3D

var _menu_flythrough_points: Array[Vector3] = []
var _menu_flythrough_segment: int = 0
var _menu_flythrough_segment_t: float = 0.0
var _menu_flythrough_refresh: float = 0.0
var _menu_camera_heading: Vector3 = Vector3.FORWARD
var _menu_camera_bank: float = 0.0


func setup(camera: Camera3D, grid: Node3D, buildings: Node3D) -> void:
	fallback_camera = camera
	grid_manager = grid
	building_manager = buildings


## One frame of the drift (menu only).
func update(delta: float) -> void:
	_update_menu_cinematic_camera(delta)


## Re-plans the loop (after the preview camp changed).
func rebuild() -> void:
	_rebuild_menu_flythrough_path()


func _update_menu_cinematic_camera(delta: float) -> void:
	if fallback_camera == null or grid_manager == null:
		return
	fallback_camera.current = true
	fallback_camera.fov = move_toward(fallback_camera.fov, 63.0, maxf(7.0 * delta, 0.0))

	_menu_flythrough_refresh -= maxf(delta, 0.0)
	if _menu_flythrough_points.size() < 2 or _menu_flythrough_refresh <= 0.0:
		_rebuild_menu_flythrough_path()

	if _menu_flythrough_points.size() < 2:
		var center: Vector3 = grid_manager.get_map_center_world()
		fallback_camera.global_position = center + Vector3(0.0, MENU_FPV_HEIGHT + 0.4, -12.0)
		fallback_camera.look_at(center + Vector3(0.0, MENU_FPV_LOOK_HEIGHT, 0.0), Vector3.UP)
		return

	var point_count := _menu_flythrough_points.size()
	var from_idx := clampi(_menu_flythrough_segment, 0, point_count - 1)
	var p0 := _menu_flythrough_points[(from_idx - 1 + point_count) % point_count]
	var p1 := _menu_flythrough_points[from_idx]
	var p2 := _menu_flythrough_points[(from_idx + 1) % point_count]
	var p3 := _menu_flythrough_points[(from_idx + 2) % point_count]
	var segment_len := maxf(p1.distance_to(p2), 1.0)
	_menu_flythrough_segment_t += (MENU_FPV_SPEED / segment_len) * maxf(delta, 0.0)
	while _menu_flythrough_segment_t >= 1.0:
		_menu_flythrough_segment_t -= 1.0
		_menu_flythrough_segment = (_menu_flythrough_segment + 1) % point_count
		from_idx = clampi(_menu_flythrough_segment, 0, point_count - 1)
		p0 = _menu_flythrough_points[(from_idx - 1 + point_count) % point_count]
		p1 = _menu_flythrough_points[from_idx]
		p2 = _menu_flythrough_points[(from_idx + 1) % point_count]
		p3 = _menu_flythrough_points[(from_idx + 2) % point_count]

	var t := _menu_flythrough_segment_t
	var flat_pos := _menu_catmull_position(p0, p1, p2, p3, t)
	var tangent := _menu_catmull_tangent(p0, p1, p2, p3, t)
	var forward_flat := Vector3(tangent.x, 0.0, tangent.z).normalized()
	if forward_flat.length_squared() < 0.001:
		forward_flat = _menu_camera_heading
	else:
		_menu_camera_heading = _menu_camera_heading.slerp(forward_flat, clampf(delta * MENU_FPV_STEER_LERP, 0.0, 1.0)).normalized()
		forward_flat = _menu_camera_heading

	var tangent_ahead := _menu_catmull_tangent(p0, p1, p2, p3, minf(1.0, t + 0.06))
	var ahead_dir := Vector3(tangent_ahead.x, 0.0, tangent_ahead.z).normalized()
	var turn := clampf(forward_flat.cross(ahead_dir).y * 3.2, -1.0, 1.0)
	var target_bank := -turn * MENU_FPV_BANK_MAX_RAD
	_menu_camera_bank = lerpf(_menu_camera_bank, target_bank, clampf(delta * 2.9, 0.0, 1.0))

	var right := forward_flat.cross(Vector3.UP).normalized()
	var drift := right * (_menu_camera_bank * MENU_FPV_DRIFT_STRENGTH)
	var bob := sin((Time.get_ticks_msec() * 0.001) * 1.35 + float(_menu_flythrough_segment) * 0.58) * MENU_FPV_BOB_AMPLITUDE
	var cam_pos := Vector3(flat_pos.x, MENU_FPV_HEIGHT + bob, flat_pos.z) + drift
	fallback_camera.global_position = cam_pos

	var look_t := minf(1.0, t + MENU_FPV_LOOK_AHEAD)
	var look_flat := _menu_catmull_position(p0, p1, p2, p3, look_t)
	var look_pos := Vector3(look_flat.x, MENU_FPV_LOOK_HEIGHT + bob * 0.16, look_flat.z) + (right * (_menu_camera_bank * 0.75))
	fallback_camera.look_at(look_pos, Vector3.UP)
	fallback_camera.rotation.z = lerpf(fallback_camera.rotation.z, _menu_camera_bank, clampf(delta * 4.4, 0.0, 1.0))


func _menu_catmull_position(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var tt := t * t
	var ttt := tt * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * tt
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * ttt
	)


func _menu_catmull_tangent(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var tt := t * t
	return 0.5 * (
		(-p0 + p2)
		+ (4.0 * p0 - 10.0 * p1 + 8.0 * p2 - 2.0 * p3) * t
		+ (-3.0 * p0 + 9.0 * p1 - 9.0 * p2 + 3.0 * p3) * tt
	)


func _rebuild_menu_flythrough_path() -> void:
	if grid_manager == null:
		_menu_flythrough_points.clear()
		return
	var center: Vector3 = grid_manager.get_map_center_world()
	var map_size: Vector2 = grid_manager.get_map_size_world()
	var half_x := maxf(7.5, map_size.x * 0.5 - 7.0)
	var half_z := maxf(7.5, map_size.y * 0.5 - 7.0)
	var points: Array[Vector3] = []

	var structures_root := building_manager.get_node_or_null("Structures") if building_manager != null else null
	if structures_root != null:
		for child in structures_root.get_children():
			var structure := child as Node3D
			if structure == null:
				continue
			var pos := structure.global_position
			var offset := Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))
			points.append(_clamp_menu_fly_point(pos + offset, center, half_x, half_z))

	if points.size() < 6:
		var rows := 8
		for i in range(rows):
			var t := float(i) / float(max(1, rows - 1))
			var z := lerpf(center.z - half_z * 0.76, center.z + half_z * 0.76, t) + randf_range(-3.0, 3.0)
			var x_amp := half_x * (0.68 + randf_range(-0.06, 0.06))
			var x := center.x + (x_amp if i % 2 == 0 else -x_amp) + randf_range(-3.2, 3.2)
			points.append(_clamp_menu_fly_point(Vector3(x, 0.0, z), center, half_x, half_z))

	if points.size() >= 2:
		points.append(points[0])

	_menu_flythrough_points = points
	_menu_flythrough_segment = 0
	_menu_flythrough_segment_t = 0.0
	_menu_flythrough_refresh = MENU_FPV_REFRESH_SEC
	_menu_camera_bank = 0.0
	if points.size() >= 2:
		var init_dir := Vector3(points[1].x - points[0].x, 0.0, points[1].z - points[0].z).normalized()
		if init_dir.length_squared() >= 0.001:
			_menu_camera_heading = init_dir


func _clamp_menu_fly_point(point: Vector3, center: Vector3, half_x: float, half_z: float) -> Vector3:
	return Vector3(
		clampf(point.x, center.x - half_x, center.x + half_x),
		0.0,
		clampf(point.z, center.z - half_z, center.z + half_z)
	)
