extends Node

const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")

const DEMOLISH_FEE_PER_TILE: int = 4
const DEMOLISH_MAX_SIZE: int = 5
const ALLOWED_BUILD_TYPES: Dictionary = {
	"tent_1": true,
	"cabin_1": true,
	"caravan_1": true,
	"bonfire": true,
	"sports_field": true,
	"lake_slide": true,
	"toilet_block": true,
	"shower_block": true,
	"pub": true,
	"restaurant": true,
	"vecerka": true,
	"sewer": true,
	"lamp_post": true,
	"path": true,
}

var _state
var _actions
var _registry
var _economy_manager: Node = null


func setup(state, actions, registry) -> void:
	_state = state
	_actions = actions
	_registry = registry
	_connect_event_bus()


func _ready() -> void:
	_connect_event_bus()


func _connect_event_bus() -> void:
	if not EventBus.has_signal("RequestBuild"):
		return
	var build_cb := Callable(self, "_on_request_build")
	if not EventBus.RequestBuild.is_connected(build_cb):
		EventBus.RequestBuild.connect(build_cb)
	var demolish_cb := Callable(self, "_on_request_demolish")
	if EventBus.has_signal("RequestDemolish") and not EventBus.RequestDemolish.is_connected(demolish_cb):
		EventBus.RequestDemolish.connect(demolish_cb)
	var rotate_cb := Callable(self, "_on_request_rotate")
	if EventBus.has_signal("RequestRotate") and not EventBus.RequestRotate.is_connected(rotate_cb):
		EventBus.RequestRotate.connect(rotate_cb)


func _on_request_build(building_type: String, pos: Vector2i, rot: int) -> void:
	var normalized_type = building_type.strip_edges()
	var normalized_rot = wrapi(rot, 0, 4)
	if _state == null or _actions == null or _state.grid == null:
		EventBus.BuildRejected.emit(normalized_type, pos, normalized_rot, "authority_not_ready")
		return
	if not ALLOWED_BUILD_TYPES.has(normalized_type):
		EventBus.BuildRejected.emit(normalized_type, pos, normalized_rot, "not_buildable")
		return

	var footprint = _resolve_footprint(normalized_type)
	if not _state.grid.can_place_footprint(pos, footprint):
		EventBus.BuildRejected.emit(normalized_type, pos, normalized_rot, "blocked_or_out_of_bounds")
		return

	var cost = _get_build_cost(normalized_type)
	if CoreRoot.get_money() < cost:
		EventBus.BuildRejected.emit(normalized_type, pos, normalized_rot, "insufficient_funds")
		return

	var success = _actions.place_building(normalized_type, pos, footprint, normalized_rot)
	if success:
		EventBus.BuildConfirmed.emit(normalized_type, pos, normalized_rot)
	else:
		EventBus.BuildRejected.emit(normalized_type, pos, normalized_rot, "placement_denied")


func _on_request_demolish(area: Rect2i) -> void:
	if _state == null or _actions == null or _state.grid == null:
		EventBus.DemolishRejected.emit(area, "authority_not_ready")
		return

	var rect = _normalize_rect(area)
	if rect.size.x <= 0 or rect.size.y <= 0:
		EventBus.DemolishRejected.emit(rect, "invalid_area")
		return
	if rect.size.x > DEMOLISH_MAX_SIZE or rect.size.y > DEMOLISH_MAX_SIZE:
		EventBus.DemolishRejected.emit(rect, "area_too_large")
		return

	var bounds = _state.grid.get_grid_size()
	if rect.position.x < 0 or rect.position.y < 0:
		EventBus.DemolishRejected.emit(rect, "out_of_bounds")
		return
	if rect.position.x + rect.size.x > bounds.x or rect.position.y + rect.size.y > bounds.y:
		EventBus.DemolishRejected.emit(rect, "out_of_bounds")
		return

	var summary = _collect_demolish_targets(rect)
	var removable_count = int(summary.get("removable_count", 0))
	var blocked_count = int(summary.get("blocked_count", 0))
	if removable_count <= 0:
		var reason = "protected_structure" if blocked_count > 0 else "empty_selection"
		EventBus.DemolishRejected.emit(rect, reason)
		return

	var fee = rect.size.x * rect.size.y * DEMOLISH_FEE_PER_TILE
	if CoreRoot.get_money() < fee:
		EventBus.DemolishRejected.emit(rect, "insufficient_funds")
		return

	var removed_count = 0
	var refund_total = 0
	var building_targets: Array = summary.get("building_targets", [])
	for target in building_targets:
		var origin: Vector2i = target.get("origin", Vector2i.ZERO)
		var building_type: String = str(target.get("type", ""))
		if _actions.remove_building(origin):
			removed_count += 1
			refund_total += _get_build_refund(building_type)

	var tree_targets: Array = summary.get("tree_targets", [])
	for coord in tree_targets:
		if _actions.remove_building(coord):
			removed_count += 1

	if removed_count <= 0:
		EventBus.DemolishRejected.emit(rect, "demolish_failed")
		return

	if fee > 0 and not _actions.spend_money(fee):
		EventBus.DemolishRejected.emit(rect, "fee_payment_failed")
		return

	EventBus.DemolishConfirmed.emit(rect, removed_count, fee, refund_total)


func _on_request_rotate(dir: int) -> void:
	# Rotation is local UI state for now; keep this signal consumed and validated.
	if dir != -1 and dir != 1:
		return


func _collect_demolish_targets(rect: Rect2i) -> Dictionary:
	var building_targets: Array = []
	var tree_targets: Array[Vector2i] = []
	var blocked_count = 0

	var seen_roots: Dictionary = {}
	var seen_instances: Dictionary = {}
	var seen_trees: Dictionary = {}
	var seen_blocked: Dictionary = {}

	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var coord = Vector2i(x, y)

			if _state.grid.cells.has(coord):
				var data: Dictionary = _state.grid.cells[coord]
				var instance_id = str(data.get("id", ""))
				var origin: Vector2i = data.get("root_coord", coord)
				var building_type = str(data.get("type", ""))
				var target_key = "%s@%d:%d" % [instance_id, origin.x, origin.y]
				if not seen_instances.has(target_key):
					seen_instances[target_key] = true
					if _is_permanent_type(building_type):
						if not seen_blocked.has(target_key):
							seen_blocked[target_key] = true
							blocked_count += 1
					else:
						building_targets.append({
							"origin": origin,
							"type": building_type,
						})

			var occupant_root = _resolve_occupant_root(_state.grid.get_occupant(coord))
			if occupant_root == null:
				continue
			var root_id = int(occupant_root.get_instance_id())
			if seen_roots.has(root_id):
				continue
			seen_roots[root_id] = true

			var root_type = str(occupant_root.get_meta("building_type", ""))
			if _is_permanent_type(root_type):
				var blocked_key = "root_%d" % root_id
				if not seen_blocked.has(blocked_key):
					seen_blocked[blocked_key] = true
					blocked_count += 1
				continue

			if occupant_root.is_in_group("trees"):
				if not seen_trees.has(root_id):
					seen_trees[root_id] = true
					tree_targets.append(coord)

	return {
		"building_targets": building_targets,
		"tree_targets": tree_targets,
		"removable_count": building_targets.size() + tree_targets.size(),
		"blocked_count": blocked_count,
	}


func _resolve_occupant_root(occupant: Variant) -> Node:
	if occupant == null:
		return null
	var node = occupant as Node
	if node == null:
		return null
	if node.has_meta("grid_origin"):
		return node
	var current = node.get_parent()
	while current != null:
		if current.has_meta("grid_origin"):
			return current
		current = current.get_parent()
	return node


func _is_permanent_type(building_type: String) -> bool:
	return building_type == "main_building" or building_type == "power_generator"


func _resolve_footprint(building_type: String) -> Vector2i:
	var econ = _resolve_economy_manager()
	if econ != null:
		var all_data = econ.get("BUILDING_DATA")
		if all_data is Dictionary and all_data.has(building_type):
			var row = all_data[building_type]
			if row is Dictionary:
				var row_fp = row.get("footprint", Vector2i.ONE)
				if row_fp is Vector2i:
					return row_fp
	return Vector2i.ONE


func _get_build_cost(building_type: String) -> int:
	if _registry != null and _registry.has_method("get_def"):
		var def = _registry.get_def(building_type)
		if def != null:
			return int(def.cost)
	var econ = _resolve_economy_manager()
	if econ != null and econ.has_method("get_cost"):
		return int(econ.get_cost(building_type))
	return 0


func _get_build_refund(building_type: String) -> int:
	var cost = _get_build_cost(building_type)
	if cost <= 0:
		return 0
	return int(round(float(cost) * BALANCE_CONFIG.REFUND_RATIO))


func _resolve_economy_manager() -> Node:
	if _economy_manager != null and is_instance_valid(_economy_manager):
		return _economy_manager
	var scene_tree = get_tree()
	if scene_tree == null or scene_tree.root == null:
		return null
	_economy_manager = scene_tree.root.find_child("EconomyManager", true, false)
	return _economy_manager


func _normalize_rect(area: Rect2i) -> Rect2i:
	if area.size.x <= 0 or area.size.y <= 0:
		return Rect2i(area.position, Vector2i.ZERO)
	var x0 = min(area.position.x, area.position.x + area.size.x - 1)
	var y0 = min(area.position.y, area.position.y + area.size.y - 1)
	var x1 = max(area.position.x, area.position.x + area.size.x - 1)
	var y1 = max(area.position.y, area.position.y + area.size.y - 1)
	return Rect2i(Vector2i(x0, y0), Vector2i(x1 - x0 + 1, y1 - y0 + 1))
