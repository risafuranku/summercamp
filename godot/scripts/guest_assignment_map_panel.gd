extends Control

signal accommodation_selected(accommodation_key: String)

const COLOR_BG := Color(0.14, 0.14, 0.15, 0.98)
const COLOR_FRAME := Color(0.42, 0.42, 0.46, 1.0)
const COLOR_GRID := Color(0.24, 0.24, 0.26, 0.70)
const COLOR_NON_HOUSING := Color(0.20, 0.20, 0.22, 0.95)
const COLOR_AVAILABLE_TENT := Color(0.30, 0.64, 0.36, 1.0)
const COLOR_AVAILABLE_CABIN := Color(0.24, 0.50, 0.74, 1.0)
const COLOR_AVAILABLE_OTHER := Color(0.56, 0.52, 0.24, 1.0)
const COLOR_UNAVAILABLE := Color(0.44, 0.44, 0.46, 1.0)
const COLOR_UNAVAILABLE_DIRTY := Color(0.46, 0.34, 0.34, 1.0)
const COLOR_SELECTED := Color(0.95, 0.86, 0.34, 1.0)

var _grid_size: Vector2i = Vector2i(1, 1)
var _building_roots: Dictionary = {}
var _accommodations: Dictionary = {}
var _selected_key: String = ""
var _hitboxes: Dictionary = {}
var _hover_key: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(420.0, 260.0)


func set_snapshot(snapshot: Dictionary) -> void:
	_grid_size = _parse_grid_size(snapshot.get("grid_size", Vector2i.ONE))
	_building_roots = _copy_dict(snapshot.get("building_roots", {}))
	_accommodations = _copy_dict(snapshot.get("accommodations", {}))
	if not _selected_key.is_empty() and not _accommodations.has(_selected_key):
		_selected_key = ""
	queue_redraw()


func get_selected_accommodation_key() -> String:
	return _selected_key


func select_accommodation_key(acc_key: String) -> bool:
	if acc_key.is_empty() or not _accommodations.has(acc_key):
		return false
	_selected_key = acc_key
	queue_redraw()
	accommodation_selected.emit(_selected_key)
	return true


func clear_selection() -> void:
	if _selected_key.is_empty():
		return
	_selected_key = ""
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_key = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion = event as InputEventMouseMotion
		var new_hover = _hit_key_at_point(motion.position)
		if new_hover != _hover_key:
			_hover_key = new_hover
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _hover_key.is_empty() else Control.CURSOR_ARROW
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		var clicked_key = _hit_key_at_point(mouse_event.position)
		if clicked_key.is_empty():
			return
		_selected_key = clicked_key
		queue_redraw()
		accommodation_selected.emit(_selected_key)
		accept_event()


func _draw() -> void:
	var content_size = size - Vector2(12.0, 12.0)
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		return

	var content_rect = Rect2(Vector2(6.0, 6.0), content_size)
	draw_rect(content_rect, COLOR_BG, true)
	draw_rect(content_rect, COLOR_FRAME, false, 2.0)

	if _grid_size.x <= 0 or _grid_size.y <= 0:
		return

	var cell_size = minf(
		(content_rect.size.x - 10.0) / float(_grid_size.x),
		(content_rect.size.y - 10.0) / float(_grid_size.y)
	)
	if cell_size <= 2.0:
		return

	var map_size = Vector2(cell_size * float(_grid_size.x), cell_size * float(_grid_size.y))
	var map_origin = content_rect.position + (content_rect.size - map_size) * 0.5
	var map_rect = Rect2(map_origin, map_size)
	_draw_grid(map_rect, cell_size)

	_hitboxes.clear()
	_draw_non_housing(map_rect, cell_size)
	_draw_accommodations(map_rect, cell_size)
	_draw_legend(content_rect)


func _draw_grid(map_rect: Rect2, cell_size: float) -> void:
	for x in range(_grid_size.x + 1):
		var px = map_rect.position.x + float(x) * cell_size
		draw_line(Vector2(px, map_rect.position.y), Vector2(px, map_rect.position.y + map_rect.size.y), COLOR_GRID, 1.0)
	for y in range(_grid_size.y + 1):
		var py = map_rect.position.y + float(y) * cell_size
		draw_line(Vector2(map_rect.position.x, py), Vector2(map_rect.position.x + map_rect.size.x, py), COLOR_GRID, 1.0)


func _draw_non_housing(map_rect: Rect2, cell_size: float) -> void:
	for root_key_any in _building_roots.keys():
		var root_key = str(root_key_any)
		var entry_any = _building_roots[root_key]
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		if bool(entry.get("is_housing", false)):
			continue
		var coord = _coord_from_key(root_key)
		if not _is_coord_in_bounds(coord):
			continue
		var cell_rect = _coord_to_rect(map_rect, cell_size, coord)
		var inner = cell_rect.grow(-2.0)
		draw_rect(inner, COLOR_NON_HOUSING, true)
		draw_rect(inner, Color(0.12, 0.12, 0.13, 1.0), false, 1.0)


func _draw_accommodations(map_rect: Rect2, cell_size: float) -> void:
	var keys: Array = _accommodations.keys().duplicate()
	keys.sort()
	for key_any in keys:
		var acc_key = str(key_any)
		var acc_any = _accommodations[acc_key]
		if not (acc_any is Dictionary):
			continue
		var acc: Dictionary = acc_any
		var coord = _coord_from_key(acc_key)
		if not _is_coord_in_bounds(coord):
			continue

		var cell_rect = _coord_to_rect(map_rect, cell_size, coord)
		var inner = cell_rect.grow(-2.4)
		var fill_color = _fill_color_for_accommodation(acc)
		var border_color = _border_color_for_accommodation(acc)

		draw_rect(inner, fill_color, true)
		draw_rect(inner, border_color, false, 2.0)

		if acc_key == _selected_key:
			draw_rect(cell_rect.grow(-0.6), COLOR_SELECTED, false, 3.0)

		_hitboxes[acc_key] = cell_rect
		_draw_accommodation_text(inner, acc)


func _draw_legend(content_rect: Rect2) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	var legend_text = "Barevne = dostupne | Sede = nedostupne"
	draw_string(font, content_rect.position + Vector2(10.0, 18.0), legend_text, HORIZONTAL_ALIGNMENT_LEFT, content_rect.size.x - 20.0, 13, Color(0.86, 0.86, 0.90, 1.0))


func _draw_accommodation_text(rect: Rect2, acc: Dictionary) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	var building_type = str(acc.get("building_type", ""))
	var occupancy = _guest_count(acc)
	var capacity = max(1, int(acc.get("capacity", 1)))
	var status = str(acc.get("status", "clean"))
	var line = "%s %d/%d" % [_building_short_label(building_type), occupancy, capacity]
	var text_color = Color(0.09, 0.09, 0.10, 1.0) if _is_available(acc) else Color(0.92, 0.92, 0.94, 1.0)
	draw_string(font, rect.position + Vector2(5.0, rect.size.y * 0.58), line, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8.0, 13, text_color)
	if status == "dirty":
		draw_string(font, rect.position + Vector2(5.0, rect.size.y - 4.0), "DIRTY", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8.0, 11, Color(0.96, 0.72, 0.70, 1.0))


func _fill_color_for_accommodation(acc: Dictionary) -> Color:
	if not _is_available(acc):
		if str(acc.get("status", "clean")) == "dirty":
			return COLOR_UNAVAILABLE_DIRTY
		return COLOR_UNAVAILABLE
	var building_type = str(acc.get("building_type", ""))
	if building_type.begins_with("tent"):
		return COLOR_AVAILABLE_TENT
	if building_type.begins_with("cabin"):
		return COLOR_AVAILABLE_CABIN
	return COLOR_AVAILABLE_OTHER


func _border_color_for_accommodation(acc: Dictionary) -> Color:
	var status = str(acc.get("status", "clean"))
	if status == "dirty":
		return Color(0.82, 0.34, 0.30, 1.0)
	if _is_available(acc):
		return Color(0.10, 0.10, 0.12, 1.0)
	return Color(0.24, 0.24, 0.26, 1.0)


func _is_available(acc: Dictionary) -> bool:
	var status = str(acc.get("status", "clean"))
	if status == "dirty":
		return false
	var capacity = max(1, int(acc.get("capacity", 1)))
	return _guest_count(acc) < capacity


func _guest_count(acc: Dictionary) -> int:
	var ids_any = acc.get("guest_ids", [])
	if ids_any is Array:
		return (ids_any as Array).size()
	return 0


func _building_short_label(building_type: String) -> String:
	if building_type.begins_with("tent"):
		var parts = building_type.split("_")
		return "S%s" % (parts[1] if parts.size() >= 2 else "")
	if building_type.begins_with("cabin"):
		var parts = building_type.split("_")
		return "C%s" % (parts[1] if parts.size() >= 2 else "")
	if building_type.begins_with("caravan"):
		var parts = building_type.split("_")
		return "K%s" % (parts[1] if parts.size() >= 2 else "")
	if building_type.is_empty():
		return "A"
	return building_type.left(1).to_upper()


func _coord_to_rect(map_rect: Rect2, cell_size: float, coord: Vector2i) -> Rect2:
	var cell_pos = map_rect.position + Vector2(float(coord.x) * cell_size, float(coord.y) * cell_size)
	return Rect2(cell_pos, Vector2(cell_size, cell_size))


func _hit_key_at_point(point: Vector2) -> String:
	for key_any in _hitboxes.keys():
		var key = str(key_any)
		var rect_any = _hitboxes[key]
		if rect_any is Rect2 and (rect_any as Rect2).has_point(point):
			return key
	return ""


func _is_coord_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < _grid_size.x and coord.y < _grid_size.y


func _coord_from_key(key: String) -> Vector2i:
	var parts = key.split(",")
	if parts.size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func _parse_grid_size(grid_size_any) -> Vector2i:
	if grid_size_any is Vector2i:
		return Vector2i(max(1, int((grid_size_any as Vector2i).x)), max(1, int((grid_size_any as Vector2i).y)))
	if grid_size_any is Dictionary:
		var d: Dictionary = grid_size_any
		return Vector2i(max(1, int(d.get("x", 1))), max(1, int(d.get("y", 1))))
	if grid_size_any is Array:
		var arr: Array = grid_size_any
		if arr.size() >= 2:
			return Vector2i(max(1, int(arr[0])), max(1, int(arr[1])))
	return Vector2i(1, 1)


func _copy_dict(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
