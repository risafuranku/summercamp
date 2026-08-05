extends Node

var _world_3d: Node3D
var _player_getter: Callable
var _interior_manager: Node
var _building_manager: Node
var _economy_manager: Node


func setup(
	world_3d: Node3D,
	player_getter: Callable,
	interior_manager: Node,
	building_manager: Node,
	economy_manager: Node
) -> void:
	_world_3d = world_3d
	_player_getter = player_getter
	_interior_manager = interior_manager
	_building_manager = building_manager
	_economy_manager = economy_manager


func update_refs(interior_manager: Node, building_manager: Node, economy_manager: Node) -> void:
	_interior_manager = interior_manager
	_building_manager = building_manager
	_economy_manager = economy_manager


func resolve_interactable_structure(node: Node) -> Node3D:
	if _interior_manager == null or not _interior_manager.has_method("resolve_interactable_structure"):
		return null
	return _interior_manager.resolve_interactable_structure(node)


func resolve_interactable_target(max_distance: float = 8.0) -> Node:
	var direct = _get_interactable_in_view(max_distance)
	if direct != null and _is_interactable_node(direct):
		return direct
	return _find_interactable_fallback(max_distance)


func find_failed_utility_target(max_distance: float) -> Dictionary:
	var player = _get_player()
	if _economy_manager == null or player == null:
		return {}
	if not _economy_manager.has_method("has_failed_utility_at"):
		return {}
	var camera = player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return {}
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z.normalized()
	var groups = ["utilities", "services"]
	var best_score = 1.0e20
	var best: Dictionary = {}
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var n3d = node as Node3D
			if n3d == null:
				continue
			var structure = _resolve_failed_utility_structure(n3d)
			if structure == null:
				continue
			if not structure.has_meta("grid_origin"):
				continue
			var coord = structure.get_meta("grid_origin", Vector2i.ZERO)
			if not _economy_manager.has_failed_utility_at(coord):
				continue
			var to_target = _interaction_target_point(structure, origin) - origin
			var dist = to_target.length()
			if dist <= 0.001 or dist > max_distance:
				continue
			var dir = to_target / dist
			var front_dot = dir.dot(forward)
			if front_dot < 0.45:
				continue
			var score = dist + ((1.0 - front_dot) * 4.4)
			if score < best_score:
				best_score = score
				best = {
					"coord": coord,
					"type": str(structure.get_meta("building_type", "")),
					"node": structure,
				}
	return best


func resolve_interaction(interact_distance: float, utility_repairs_enabled: bool) -> Dictionary:
	if utility_repairs_enabled:
		var failed_target = find_failed_utility_target(interact_distance + 0.8)
		if not failed_target.is_empty():
			return {
				"type": "repair",
				"coord": failed_target.get("coord", Vector2i.ZERO),
				"building_type": str(failed_target.get("type", ""))
			}
	var collider = resolve_interactable_target(interact_distance)
	if collider == null:
		return {}
	var structure = resolve_interactable_structure(collider)
	if structure == null:
		return {}
	return {
		"type": "structure",
		"structure": structure,
	}


func build_hint_text(interact_distance: float, utility_repairs_enabled: bool) -> String:
	if utility_repairs_enabled:
		var failed_target = find_failed_utility_target(interact_distance + 0.8)
		if not failed_target.is_empty():
			var failed_type = str(failed_target.get("type", ""))
			var label = failed_type
			if _economy_manager != null and _economy_manager.has_method("get_label"):
				label = str(_economy_manager.get_label(failed_type))
			return "[E] Opravit: %s" % label

	var collider = resolve_interactable_target(interact_distance)
	if collider == null:
		return ""
	var structure = resolve_interactable_structure(collider)
	if structure == null:
		return ""
	var building_type = str(structure.get_meta("building_type", ""))
	var hint = ""
	if _interior_manager != null and _interior_manager.has_method("get_hint_for_building_type"):
		hint = str(_interior_manager.get_hint_for_building_type(building_type))
	if hint == "":
		return ""
	return "[E] %s" % hint


func _get_player() -> Node:
	if _player_getter.is_valid():
		return _player_getter.call()
	return null


func _resolve_failed_utility_structure(node: Node) -> Node3D:
	var current = node
	while current != null:
		if current is Node3D and current.has_meta("grid_origin"):
			return current as Node3D
		current = current.get_parent()
	return null


func _get_interactable_in_view(max_distance: float = 8.0) -> Node:
	var player = _get_player()
	if player == null:
		return null
	var camera = player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return null

	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return null
	var center = viewport_size * 0.5
	var probe = clamp(min(viewport_size.x, viewport_size.y) * 0.020, 10.0, 28.0)
	var sample_points = [
		center,
		center + Vector2(probe, 0.0),
		center + Vector2(-probe, 0.0),
		center + Vector2(0.0, probe),
		center + Vector2(0.0, -probe),
		center + Vector2(probe, probe),
		center + Vector2(-probe, probe),
		center + Vector2(probe, -probe),
		center + Vector2(-probe, -probe)
	]

	var fallback_hit: Node = null
	for point in sample_points:
		var hit = _raycast_from_screen(camera, point, max_distance)
		if hit.is_empty():
			continue
		var collider = hit["collider"] as Node
		if collider == null:
			continue
		if fallback_hit == null:
			fallback_hit = collider
		if _is_interactable_node(collider):
			return collider

	return fallback_hit


func _find_interactable_fallback(max_distance: float = 8.0) -> Node:
	var player = _get_player()
	if player == null:
		return null
	var camera = player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return null
	if _building_manager == null:
		return null
	var structures_root = _building_manager.get_node_or_null("Structures") as Node3D
	if structures_root == null:
		return null
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z.normalized()

	var best_node: Node3D = null
	var best_score = 1.0e20
	for child in structures_root.get_children():
		var structure = child as Node3D
		if structure == null:
			continue
		var resolved = resolve_interactable_structure(structure)
		if resolved == null:
			continue
		var distance_limit = max_distance + 0.55
		var min_front_dot = 0.42
		if str(structure.get_meta("building_type", "")) == "main_building":
			distance_limit = max_distance + 0.10
			min_front_dot = 0.58
		var to_target = _interaction_target_point(structure, origin) - origin
		var dist = to_target.length()
		if dist <= 0.001 or dist > distance_limit:
			continue
		var dir = to_target / dist
		var front_dot = dir.dot(forward)
		if front_dot < min_front_dot:
			continue
		var score = dist + ((1.0 - front_dot) * 5.2)
		if score < best_score:
			best_score = score
			best_node = structure
	return best_node


func _interaction_target_point(structure: Node3D, listener_origin: Vector3 = Vector3(INF, INF, INF)) -> Vector3:
	if structure == null:
		return Vector3.ZERO
	if structure.has_meta("interaction_target_local"):
		var local_target = structure.get_meta("interaction_target_local", Vector3.ZERO)
		if local_target is Vector3:
			var local_point: Vector3 = local_target
			return structure.global_transform * local_point
	var building_type = str(structure.get_meta("building_type", ""))
	if building_type == "toilet_block" or building_type == "shower_block":
		return structure.global_transform * Vector3(0.0, 1.0, 0.48)
	for child in structure.get_children():
		var collider = child as CollisionShape3D
		if collider != null:
			var box_shape = collider.shape as BoxShape3D
			if box_shape != null and is_finite(listener_origin.x):
				var local_listener = structure.to_local(listener_origin)
				var half = box_shape.size * 0.5
				var local_target = Vector3(
					clampf(local_listener.x, -half.x, half.x),
					clampf(local_listener.y, 0.6, max(0.6, half.y)),
					clampf(local_listener.z, -half.z, half.z)
				)
				return structure.to_global(local_target)
			return collider.global_position
	return structure.global_position + Vector3(0.0, 0.9, 0.0)


func _raycast_from_screen(camera: Camera3D, screen_pos: Vector2, max_distance: float) -> Dictionary:
	if _world_3d == null:
		return {}
	var player = _get_player()
	var origin = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	var end = origin + dir * max_distance
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if player != null:
		query.exclude = [player.get_rid()]
	return _world_3d.get_world_3d().direct_space_state.intersect_ray(query)


func _is_interactable_node(node: Node) -> bool:
	return resolve_interactable_structure(node) != null
