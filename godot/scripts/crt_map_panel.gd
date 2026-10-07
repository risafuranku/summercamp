extends Control

signal status_changed(text: String, kind: int)
signal tool_canceled
signal submenu_close_requested

## Status severity, consumed by builder_module for colour + audio feedback.
const STATUS_INFO := 0
const STATUS_GOOD := 1
const STATUS_DENY := 2

const BG_COLOR := Color(0.09, 0.09, 0.08, 1.0)
const GRID_LINE := Color(0.20, 0.20, 0.18, 0.95)
const HOVER_FILL := Color(0.34, 0.64, 0.94, 0.22)
const HOVER_LINE := Color(0.72, 0.88, 1.0, 0.96)
const GHOST_OK_FILL := Color(0.20, 0.58, 0.96, 0.28)
const GHOST_OK_LINE := Color(0.60, 0.82, 1.0, 0.96)
const GHOST_BAD_FILL := Color(0.76, 0.24, 0.24, 0.24)
const GHOST_BAD_LINE := Color(0.98, 0.48, 0.48, 0.94)

const ZOOM_MIN := 0.50
const ZOOM_MAX := 3.00
const KEYBOARD_PAN_SPEED := 360.0
const KEYBOARD_PAN_SPRINT_MULT := 1.7
const MAP_VISUAL_PADDING := 0.28
const MAP_ROTATION_STEPS := 1

const DEMOLISH_MAX_SIZE := 5
const ROTATION_LABELS: Array[String] = ["SOUTH", "EAST", "NORTH", "WEST"]

const ICON_PATHS := {
	"main_building": "res://assets/textury/builder/base.png",
	"tent_1": "res://assets/textury/builder/stan1.png",
	"cabin_1": "res://assets/textury/builder/chata1.PNG",
	"toilet_block": "res://assets/textury/builder/hajzly.PNG",
	"shower_block": "res://assets/textury/builder/sprchy.PNG",
	"pub": "res://assets/textury/builder/hospoda1.PNG",
	"restaurant": "res://assets/textury/builder/restaurace.PNG",
	"vecerka": "res://assets/textury/builder/vecerka.jpg",
	"sewer": "res://assets/textury/builder/sewer.PNG",
	"power_generator": "res://assets/textury/builder/gen.PNG",
	"path": "res://assets/textury/builder/parking.PNG",
	"lamp_post": "res://assets/textury/builder/gen.PNG",
	"tree": "res://assets/textury/builder/strom.png",
}

const ICON_NO_MIRROR := {
	"main_building": true,
	"tree": true,
	"path": true,
	"lamp_post": true,
}

var grid_manager
var building_manager
var selected_building: String = ""
var hover_coord: Vector2i = Vector2i(-1, -1)

var _zoom_level: float = 1.16
var _pan_offset: Vector2 = Vector2.ZERO
var _pan_dragging: bool = false
var _pan_drag_moved: bool = false
var _rmb_pressed_without_selection: bool = false

var _rotation_steps: int = 0

var _ghost_locked: bool = false
var _ghost_coord: Vector2i = Vector2i(-1, -1)

var _pending_build_wait: bool = false
var _pending_build_type: String = ""
var _pending_build_coord: Vector2i = Vector2i(-1, -1)
var _pending_build_rot: int = 0

var _path_drag_active: bool = false
var _path_last_coord: Vector2i = Vector2i(-999, -999)
var _path_requested: Dictionary = {}
var _path_preview: Dictionary = {}

var _demolish_drag_active: bool = false
var _demolish_drag_start: Vector2i = Vector2i(-1, -1)
var _demolish_drag_end: Vector2i = Vector2i(-1, -1)
var _demolish_selection_active: bool = false
var _demolish_selection_rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
var _pending_demolish_wait: bool = false
var _pending_demolish_rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)

var _icon_cache: Dictionary = {}
var _economy_manager: Node = null
var _last_status: String = ""


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	mouse_exited.connect(_on_mouse_exited)
	_preload_icons()
	_connect_event_bus()
	_emit_status("Select a tool to begin.")


func setup(new_grid_manager, new_building_manager) -> void:
	grid_manager = new_grid_manager
	building_manager = new_building_manager
	queue_redraw()


func set_selected_building(new_type: String) -> void:
	var normalized = new_type.strip_edges()
	selected_building = normalized
	_ghost_locked = false
	_ghost_coord = Vector2i(-1, -1)
	_pending_build_wait = false
	_pending_build_type = ""
	_pending_build_coord = Vector2i(-1, -1)
	_path_drag_active = false
	_path_requested.clear()
	_path_preview.clear()
	_path_last_coord = Vector2i(-999, -999)
	_demolish_drag_active = false
	_pending_demolish_wait = false
	if selected_building != "demolish":
		_demolish_selection_active = false
	if selected_building == "":
		_emit_status("Selection cleared.")
	else:
		_emit_status("Selected: %s" % _display_name(selected_building))
	queue_redraw()


func rotate_selected_building(step: int) -> void:
	_rotate_building(step)


func apply_zoom_step(direction: int) -> void:
	if direction > 0:
		_set_zoom(_zoom_level * 1.10)
	elif direction < 0:
		_set_zoom(_zoom_level * 0.90)
	queue_redraw()


func _process(delta: float) -> void:
	_update_keyboard_pan(delta)
	if not is_visible_in_tree():
		return
	var local = get_local_mouse_position()
	if local.x >= 0.0 and local.y >= 0.0 and local.x <= size.x and local.y <= size.y:
		hover_coord = _local_to_grid(local)
	elif not _path_drag_active and not _demolish_drag_active:
		hover_coord = Vector2i(-1, -1)
	queue_redraw()


func _update_keyboard_pan(delta: float) -> void:
	if delta <= 0.0:
		return
	if not has_focus() and not _mouse_inside():
		return
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.y += 1.0
	if move.length_squared() <= 0.0001:
		return
	move = move.normalized()
	var speed = KEYBOARD_PAN_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= KEYBOARD_PAN_SPRINT_MULT
	_pan_offset -= move * speed * delta
	_clamp_pan_offset_for_current_map()


func _gui_input(event: InputEvent) -> void:
	if grid_manager == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_rotate_building(1)
				get_viewport().set_input_as_handled()
				return
			KEY_E:
				_rotate_building(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_EQUAL, KEY_KP_ADD:
				apply_zoom_step(1)
				get_viewport().set_input_as_handled()
				return
			KEY_MINUS, KEY_KP_SUBTRACT:
				apply_zoom_step(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_W, KEY_A, KEY_S, KEY_D:
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion:
		if _pan_dragging:
			if event.relative.length_squared() > 0.08:
				_pan_drag_moved = true
			_pan_offset += event.relative
			_clamp_pan_offset_for_current_map()
		if _path_drag_active:
			_request_path_at(event.position)
		if _demolish_drag_active:
			_update_demolish_drag(event.position)
		hover_coord = _local_to_grid(event.position)
		queue_redraw()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			apply_zoom_step(1)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			apply_zoom_step(-1)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_pan_dragging = true
				_pan_drag_moved = false
				_rmb_pressed_without_selection = selected_building == ""
				if selected_building != "":
					_cancel_tool_selection()
			else:
				if not _pan_drag_moved and _rmb_pressed_without_selection and selected_building == "" and not _any_pending_interaction():
					submenu_close_requested.emit()
					_emit_status("Submenu closed.")
				_pan_dragging = false
				_rmb_pressed_without_selection = false
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				_handle_left_press(event.position)
			else:
				if _path_drag_active:
					_end_path_drag()
				if _demolish_drag_active:
					_finish_demolish_drag()
			queue_redraw()
			get_viewport().set_input_as_handled()
			return


func _handle_left_press(local_pos: Vector2) -> void:
	if selected_building == "":
		return
	if selected_building == "path":
		_begin_path_drag(local_pos)
		return
	if selected_building == "demolish":
		_begin_demolish_press(local_pos)
		return
	_handle_structure_press(local_pos)


func _handle_structure_press(local_pos: Vector2) -> void:
	if _pending_build_wait:
		_emit_status("Awaiting build confirmation...")
		return
	var coord = _local_to_grid(local_pos)
	if not _is_valid_coord(coord):
		if _ghost_locked:
			_ghost_locked = false
			_emit_status("Placement canceled.")
		return

	var footprint = _get_footprint(selected_building)
	if _ghost_locked and coord != _ghost_coord:
		_ghost_locked = false
		_emit_status("Placement canceled.")
		return

	if not _can_place(coord, footprint, selected_building):
		_ghost_locked = false
		_emit_status("Cannot place %s here." % _display_name(selected_building), STATUS_DENY)
		return

	if not _ghost_locked:
		_ghost_locked = true
		_ghost_coord = coord
		_emit_status("Ghost fixed at [%d,%d]. Click again to confirm." % [coord.x, coord.y])
		return

	_send_build_request(selected_building, _ghost_coord, _rotation_steps)
	_ghost_locked = false


func _begin_path_drag(local_pos: Vector2) -> void:
	_path_drag_active = true
	_path_last_coord = Vector2i(-999, -999)
	_path_requested.clear()
	_path_preview.clear()
	_request_path_at(local_pos)
	_emit_status("Path drag active.")


func _request_path_at(local_pos: Vector2) -> void:
	if not _path_drag_active:
		return
	var coord = _local_to_grid(local_pos)
	if not _is_valid_coord(coord):
		return
	if coord == _path_last_coord:
		return
	_path_last_coord = coord
	if _path_requested.has(coord):
		return
	if not _can_place(coord, Vector2i.ONE, "path"):
		return
	_path_requested[coord] = true
	_path_preview[coord] = true
	if EventBus.has_signal("RequestBuild"):
		EventBus.RequestBuild.emit("path", coord, 0)


func _end_path_drag() -> void:
	if not _path_drag_active:
		return
	var requested_count = _path_requested.size()
	_path_drag_active = false
	_path_requested.clear()
	_path_last_coord = Vector2i(-999, -999)
	_path_preview.clear()
	if requested_count > 0:
		_emit_status("Path requests sent: %d" % requested_count)
	else:
		_emit_status("Path drag finished.")


func _begin_demolish_press(local_pos: Vector2) -> void:
	if _pending_demolish_wait:
		_emit_status("Awaiting demolish confirmation...")
		return
	var coord = _local_to_grid(local_pos)
	if not _is_valid_coord(coord):
		if _demolish_selection_active:
			_demolish_selection_active = false
			_emit_status("Demolish selection canceled.")
		return

	if _demolish_selection_active and _rect_contains_coord(_demolish_selection_rect, coord):
		_send_demolish_request(_demolish_selection_rect)
		return

	_demolish_selection_active = false
	_demolish_drag_active = true
	_demolish_drag_start = coord
	_demolish_drag_end = coord


func _update_demolish_drag(local_pos: Vector2) -> void:
	if not _demolish_drag_active:
		return
	var coord = _local_to_grid(local_pos)
	if not _is_valid_coord(coord):
		return
	var max_delta = DEMOLISH_MAX_SIZE - 1
	var dx = clampi(coord.x - _demolish_drag_start.x, -max_delta, max_delta)
	var dy = clampi(coord.y - _demolish_drag_start.y, -max_delta, max_delta)
	_demolish_drag_end = _demolish_drag_start + Vector2i(dx, dy)


func _finish_demolish_drag() -> void:
	if not _demolish_drag_active:
		return
	_demolish_drag_active = false
	var rect = _rect_from_points(_demolish_drag_start, _demolish_drag_end)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	_demolish_selection_rect = rect
	_demolish_selection_active = true
	_emit_status("Demolish area %dx%d selected. Click again to confirm." % [rect.size.x, rect.size.y])


func _send_build_request(building_type: String, coord: Vector2i, rot: int) -> void:
	_pending_build_wait = true
	_pending_build_type = building_type
	_pending_build_coord = coord
	_pending_build_rot = wrapi(rot, 0, 4)
	if EventBus.has_signal("RequestBuild"):
		EventBus.RequestBuild.emit(building_type, coord, _pending_build_rot)
		_emit_status("Build request: %s [%d,%d]" % [_display_name(building_type), coord.x, coord.y])
	else:
		_pending_build_wait = false
		_emit_status("Build request channel unavailable.", STATUS_DENY)


func _send_demolish_request(rect: Rect2i) -> void:
	_pending_demolish_wait = true
	_pending_demolish_rect = rect
	if EventBus.has_signal("RequestDemolish"):
		EventBus.RequestDemolish.emit(rect)
		_emit_status("Demolish request: %dx%d" % [rect.size.x, rect.size.y])
	else:
		_pending_demolish_wait = false
		_emit_status("Demolish request channel unavailable.", STATUS_DENY)


func _rotate_building(step: int) -> void:
	if selected_building == "" or selected_building == "path" or selected_building == "demolish":
		_emit_status("Select a structure to rotate.", STATUS_DENY)
		return
	_rotation_steps = wrapi(_rotation_steps + step, 0, 4)
	_ghost_locked = false
	if EventBus.has_signal("RequestRotate"):
		EventBus.RequestRotate.emit(1 if step >= 0 else -1)
	_emit_status("Direction: %s" % ROTATION_LABELS[_rotation_steps])
	queue_redraw()


func _cancel_tool_selection() -> void:
	selected_building = ""
	_ghost_locked = false
	_path_drag_active = false
	_demolish_drag_active = false
	_demolish_selection_active = false
	_path_requested.clear()
	_path_preview.clear()
	tool_canceled.emit()
	_emit_status("Selection canceled.")


func _set_zoom(new_zoom: float) -> void:
	var old_zoom = _zoom_level
	_zoom_level = clamp(new_zoom, ZOOM_MIN, ZOOM_MAX)
	if absf(old_zoom - _zoom_level) < 0.001:
		return
	_pan_offset *= (_zoom_level / old_zoom)
	_clamp_pan_offset_for_current_map()
	_ghost_locked = false
	_emit_status("Zoom: %d%%" % int(round(_zoom_level * 100.0)))


func _connect_event_bus() -> void:
	if EventBus.has_signal("BuildConfirmed"):
		var ok_cb := Callable(self, "_on_build_confirmed")
		if not EventBus.BuildConfirmed.is_connected(ok_cb):
			EventBus.BuildConfirmed.connect(ok_cb)
	if EventBus.has_signal("BuildRejected"):
		var rej_cb := Callable(self, "_on_build_rejected")
		if not EventBus.BuildRejected.is_connected(rej_cb):
			EventBus.BuildRejected.connect(rej_cb)
	if EventBus.has_signal("DemolishConfirmed"):
		var dem_ok_cb := Callable(self, "_on_demolish_confirmed")
		if not EventBus.DemolishConfirmed.is_connected(dem_ok_cb):
			EventBus.DemolishConfirmed.connect(dem_ok_cb)
	if EventBus.has_signal("DemolishRejected"):
		var dem_rej_cb := Callable(self, "_on_demolish_rejected")
		if not EventBus.DemolishRejected.is_connected(dem_rej_cb):
			EventBus.DemolishRejected.connect(dem_rej_cb)


func _on_build_confirmed(building_type: String, pos: Vector2i, rot: int) -> void:
	if _pending_build_wait and building_type == _pending_build_type and pos == _pending_build_coord and wrapi(rot, 0, 4) == _pending_build_rot:
		_pending_build_wait = false
		_pending_build_type = ""
		_pending_build_coord = Vector2i(-1, -1)
	if building_type == "path":
		# Keep drag status calm while drawing roads.
		if not _path_drag_active:
			_emit_status("Path built at [%d,%d]." % [pos.x, pos.y], STATUS_GOOD)
	else:
		_emit_status("Built: %s" % _display_name(building_type), STATUS_GOOD)
	queue_redraw()


func _on_build_rejected(building_type: String, pos: Vector2i, rot: int, reason: String) -> void:
	if _pending_build_wait and building_type == _pending_build_type and pos == _pending_build_coord and wrapi(rot, 0, 4) == _pending_build_rot:
		_pending_build_wait = false
		_pending_build_type = ""
		_pending_build_coord = Vector2i(-1, -1)
	_emit_status("Build rejected: %s" % _reason_text(reason), STATUS_DENY)
	queue_redraw()


func _on_demolish_confirmed(area: Rect2i, removed_count: int, fee_paid: int, refund_total: int) -> void:
	if _pending_demolish_wait and _rect_equals(area, _pending_demolish_rect):
		_pending_demolish_wait = false
	_demolish_selection_active = false
	_emit_status("Demolished %d target(s). Refund +$%d, fee -$%d." % [removed_count, refund_total, fee_paid], STATUS_GOOD)
	queue_redraw()


func _on_demolish_rejected(area: Rect2i, reason: String) -> void:
	if _pending_demolish_wait and _rect_equals(area, _pending_demolish_rect):
		_pending_demolish_wait = false
	_emit_status("Demolish rejected: %s" % _reason_text(reason), STATUS_DENY)
	queue_redraw()


func _draw() -> void:
	if grid_manager == null:
		return
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	if grid_w <= 0 or grid_h <= 0:
		return

	var iso = _compute_iso_layout(grid_w, grid_h)
	var tile_w: float = iso.tile_w
	var tile_h: float = iso.tile_h
	var origin: Vector2 = iso.origin

	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)

	var draw_entries: Array = []
	var drawn_roots: Dictionary = {}

	for diagonal in range(grid_w + grid_h):
		for y in range(grid_h):
			var x = diagonal - y
			if x < 0 or x >= grid_w:
				continue
			var coord = Vector2i(x, y)
			var tile = grid_manager.get_tile(coord)
			if tile == null:
				continue
			var center = _grid_to_iso(coord, origin, tile_w, tile_h)
			_draw_ground_tile(center, tile_w, tile_h, tile)

			if not tile.occupied or tile.occupant == null:
				continue
			var root = _resolve_occupant_root(tile.occupant)
			if root == null:
				continue
			var root_id = int(root.get_instance_id())
			if drawn_roots.has(root_id):
				continue
			drawn_roots[root_id] = true

			var structure_origin = coord
			if root.has_meta("grid_origin"):
				structure_origin = root.get_meta("grid_origin", coord)
			var footprint = Vector2i.ONE
			if root.has_meta("grid_footprint"):
				footprint = root.get_meta("grid_footprint", Vector2i.ONE)
			var anchor = _rotate_coord_for_display(structure_origin + Vector2i(max(0, footprint.x - 1), max(0, footprint.y - 1)))
			var center_iso = _footprint_center_iso(structure_origin, footprint, origin, tile_w, tile_h)
			draw_entries.append({
				"root": root,
				"type": str(root.get_meta("building_type", "")),
				"rotation": wrapi(int(root.get_meta("build_rotation", 0)), 0, 4),
				"origin": structure_origin,
				"footprint": footprint,
				"center": center_iso,
				"order": anchor.x + anchor.y,
				"anchor_x": anchor.x,
				"anchor_y": anchor.y,
			})

	draw_entries.sort_custom(func(a, b):
		var ao = int(a.get("order", 0))
		var bo = int(b.get("order", 0))
		if ao == bo:
			var ax = int(a.get("anchor_x", 0))
			var bx = int(b.get("anchor_x", 0))
			if ax == bx:
				return int(a.get("anchor_y", 0)) < int(b.get("anchor_y", 0))
			return ax < bx
		return ao < bo
	)

	for entry in draw_entries:
		_draw_structure(entry, tile_w, tile_h)

	_draw_path_drag_preview(origin, tile_w, tile_h)
	_draw_ghost_preview(origin, tile_w, tile_h)
	_draw_demolish_preview(origin, tile_w, tile_h)

	if _is_valid_coord(hover_coord):
		var hover_center = _grid_to_iso(hover_coord, origin, tile_w, tile_h)
		_draw_diamond(hover_center, tile_w, tile_h, HOVER_FILL, HOVER_LINE, 1.8)

	_draw_rotation_panel()


func _draw_ground_tile(center: Vector2, tile_w: float, tile_h: float, tile) -> void:
	var fill = Color(0.32, 0.28, 0.22, 1.0)
	var line = GRID_LINE
	if tile.tile_type == grid_manager.TILE_LAKE:
		fill = Color(0.20, 0.28, 0.34, 1.0)
		line = Color(0.14, 0.20, 0.24, 1.0)
	elif tile.tile_type == grid_manager.TILE_RESERVED:
		fill = Color(0.36, 0.34, 0.28, 1.0)
		line = Color(0.24, 0.24, 0.20, 1.0)
	_draw_diamond(center, tile_w, tile_h, fill, line, 1.0)


func _draw_structure(entry: Dictionary, tile_w: float, tile_h: float) -> void:
	var root = entry.get("root", null)
	if root == null:
		return
	var center: Vector2 = entry.get("center", Vector2.ZERO)
	var footprint: Vector2i = entry.get("footprint", Vector2i.ONE)
	var rotation_steps: int = wrapi(int(entry.get("rotation", 0)), 0, 4)
	var building_type = str(entry.get("type", ""))

	if root.is_in_group("trees"):
		if not _draw_icon(center, Vector2(maxf(12.0, tile_w * 1.22), maxf(12.0, tile_h * 1.85)), "tree", 0, Color(1.0, 1.0, 1.0, 0.98)):
			_draw_tree_fallback(center, tile_w, tile_h)
		return

	if building_type == "path":
		_draw_path(center, entry.get("origin", Vector2i.ZERO), tile_w, tile_h)
		return

	var icon_key = _icon_key_for_type(building_type)
	if icon_key != "":
		var scale_xy = maxf(1.0, (float(footprint.x) + float(footprint.y)) * 0.5)
		var draw_size = Vector2(tile_w * scale_xy * 1.24, tile_h * scale_xy * 1.70)
		if _draw_icon(center, draw_size, icon_key, rotation_steps, Color(1.0, 1.0, 1.0, 0.98)):
			return

	_draw_placeholder(center, tile_w, tile_h, building_type)


func _draw_path(center: Vector2, coord: Vector2i, tile_w: float, tile_h: float) -> void:
	var link_w = maxf(2.2, tile_h * 0.28)
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _is_path_at(coord + offset):
			continue
		var step = _path_screen_step(offset, tile_w, tile_h)
		var tip = center + step * 0.56
		draw_line(center, tip, Color(0.22, 0.16, 0.10, 0.90), link_w + 1.5)
		draw_line(center, tip, Color(0.64, 0.52, 0.34, 0.95), link_w)
	_draw_diamond(center, tile_w * 0.42, tile_h * 0.42, Color(0.58, 0.46, 0.30, 0.96), Color(0.24, 0.18, 0.12, 1.0), 1.1)


func _draw_tree_fallback(center: Vector2, tile_w: float, tile_h: float) -> void:
	var trunk = Rect2(center.x - tile_w * 0.07, center.y - tile_h * 0.16, tile_w * 0.14, tile_h * 0.36)
	draw_rect(trunk, Color(0.30, 0.22, 0.14), true)
	var canopy = PackedVector2Array([
		Vector2(center.x, center.y - tile_h * 0.92),
		Vector2(center.x + tile_w * 0.34, center.y - tile_h * 0.22),
		Vector2(center.x - tile_w * 0.34, center.y - tile_h * 0.22),
	])
	draw_colored_polygon(canopy, Color(0.20, 0.50, 0.22))


func _draw_placeholder(center: Vector2, tile_w: float, tile_h: float, building_type: String) -> void:
	var fill = Color(0.54, 0.52, 0.50)
	if building_type == "power_generator":
		fill = Color(0.48, 0.50, 0.44)
	var top_center = center + Vector2(0.0, -tile_h * 0.14)
	var top = _diamond_points(top_center, tile_w * 0.56, tile_h * 0.36)
	draw_colored_polygon(top, fill)
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), Color(0.14, 0.14, 0.14), 1.0)


func _draw_ghost_preview(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if selected_building == "" or selected_building == "path" or selected_building == "demolish":
		return
	var coord = _ghost_coord if _ghost_locked else hover_coord
	if not _is_valid_coord(coord):
		return
	var footprint = _get_footprint(selected_building)
	var can_fit = _can_place(coord, footprint, selected_building)
	var can_afford = _has_money(selected_building)
	var can_place = can_fit and can_afford
	var fill = GHOST_OK_FILL if can_place else GHOST_BAD_FILL
	var line = GHOST_OK_LINE if can_place else GHOST_BAD_LINE
	for oy in range(footprint.y):
		for ox in range(footprint.x):
			var c = coord + Vector2i(ox, oy)
			if not _is_valid_coord(c):
				continue
			var c_center = _grid_to_iso(c, origin, tile_w, tile_h)
			_draw_diamond(c_center, tile_w, tile_h, fill, line, 1.8)

	var center = _footprint_center_iso(coord, footprint, origin, tile_w, tile_h)
	var icon_key = _icon_key_for_type(selected_building)
	if icon_key != "":
		var scale_xy = maxf(1.0, (float(footprint.x) + float(footprint.y)) * 0.5)
		_draw_icon(center, Vector2(tile_w * scale_xy * 1.24, tile_h * scale_xy * 1.70), icon_key, _rotation_steps, Color(0.62, 0.82, 1.0, 0.76))

	if _supports_rotation(selected_building):
		var dir = _rotation_to_screen_dir(_rotation_steps, tile_w, tile_h)
		_draw_direction_arrow(center + Vector2(0.0, -tile_h * 0.10), dir, tile_h, Color(0.66, 0.90, 1.0, 0.98))


func _draw_path_drag_preview(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if _path_preview.is_empty():
		return
	for coord in _path_preview.keys():
		if not (coord is Vector2i):
			continue
		if not _is_valid_coord(coord):
			continue
		var center = _grid_to_iso(coord, origin, tile_w, tile_h)
		_draw_diamond(center, tile_w, tile_h, Color(0.24, 0.56, 0.96, 0.22), Color(0.58, 0.82, 1.0, 0.90), 1.4)


func _draw_demolish_preview(origin: Vector2, tile_w: float, tile_h: float) -> void:
	if _demolish_drag_active:
		var drag_rect = _rect_from_points(_demolish_drag_start, _demolish_drag_end)
		_draw_demolish_cells(drag_rect, origin, tile_w, tile_h, Color(0.20, 0.52, 1.0, 0.28), Color(0.62, 0.84, 1.0, 0.96))
	if _demolish_selection_active:
		_draw_demolish_cells(_demolish_selection_rect, origin, tile_w, tile_h, Color(0.18, 0.46, 0.96, 0.34), Color(0.56, 0.80, 1.0, 0.98))


func _draw_demolish_cells(rect: Rect2i, origin: Vector2, tile_w: float, tile_h: float, fill: Color, line: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var coord = Vector2i(x, y)
			if not _is_valid_coord(coord):
				continue
			var center = _grid_to_iso(coord, origin, tile_w, tile_h)
			_draw_diamond(center, tile_w, tile_h, fill, line, 1.8)


func _draw_rotation_panel() -> void:
	var panel_size = Vector2(86.0, 86.0)
	var panel_pos = Vector2(size.x - panel_size.x - 10.0, 10.0)
	var panel_rect = Rect2(panel_pos, panel_size)
	draw_rect(panel_rect, Color(0.14, 0.14, 0.12, 0.92), true)
	draw_rect(panel_rect, Color(0.32, 0.30, 0.24, 1.0), false, 1.0)

	var center = panel_rect.position + panel_rect.size * 0.5
	var active = _rotation_steps
	var arrows = [
		{"id": 2, "pos": center + Vector2(0.0, -26.0), "dir": Vector2(0.0, -1.0)},
		{"id": 1, "pos": center + Vector2(26.0, 0.0), "dir": Vector2(1.0, 0.0)},
		{"id": 0, "pos": center + Vector2(0.0, 26.0), "dir": Vector2(0.0, 1.0)},
		{"id": 3, "pos": center + Vector2(-26.0, 0.0), "dir": Vector2(-1.0, 0.0)},
	]
	for arrow in arrows:
		var arrow_id = int(arrow.get("id", -1))
		var color = Color(0.42, 0.44, 0.40, 1.0)
		if arrow_id == active:
			color = Color(0.52, 0.84, 1.0, 1.0)
		_draw_panel_arrow(arrow.get("pos", center), arrow.get("dir", Vector2.RIGHT), color)

	var label = ROTATION_LABELS[active]
	var font = get_theme_default_font()
	if font != null:
		draw_string(font, panel_rect.position + Vector2(8.0, panel_rect.size.y - 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 16.0, 10, Color(0.76, 0.80, 0.74, 0.94))


func _draw_panel_arrow(pos: Vector2, direction: Vector2, color: Color) -> void:
	var dir = direction.normalized()
	var perp = Vector2(-dir.y, dir.x)
	var len = 8.0
	var wing = 4.0
	var tip = pos + dir * len
	var left = pos - dir * len * 0.25 + perp * wing
	var right = pos - dir * len * 0.25 - perp * wing
	var tri = PackedVector2Array([tip, left, right])
	draw_colored_polygon(tri, color)


func _draw_direction_arrow(anchor: Vector2, dir: Vector2, tile_h: float, color: Color) -> void:
	var safe_dir = dir
	if safe_dir.length_squared() < 0.001:
		safe_dir = Vector2(0.0, 1.0)
	safe_dir = safe_dir.normalized()
	var perp = Vector2(-safe_dir.y, safe_dir.x)
	var len = maxf(8.0, tile_h * 1.06)
	var wing = maxf(5.0, len * 0.46)
	var start = anchor - safe_dir * len * 0.5
	var tip = anchor + safe_dir * len * 0.5
	draw_line(start, tip, Color(0.0, 0.0, 0.0, 0.85), 3.9)
	draw_line(tip, tip - safe_dir * wing + perp * wing * 0.58, Color(0.0, 0.0, 0.0, 0.85), 3.9)
	draw_line(tip, tip - safe_dir * wing - perp * wing * 0.58, Color(0.0, 0.0, 0.0, 0.85), 3.9)
	draw_line(start, tip, color, 2.5)
	draw_line(tip, tip - safe_dir * wing + perp * wing * 0.58, color, 2.5)
	draw_line(tip, tip - safe_dir * wing - perp * wing * 0.58, color, 2.5)


func _draw_icon(center: Vector2, draw_size: Vector2, icon_key: String, rotation_steps: int, tint: Color) -> bool:
	var tex = _get_icon(icon_key)
	if tex == null:
		return false
	var target_h = maxf(10.0, draw_size.y)
	var aspect = float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
	var target_w = target_h * aspect
	var max_w = maxf(10.0, draw_size.x)
	if target_w > max_w:
		target_w = max_w
		target_h = target_w / maxf(0.001, aspect)
	var rect = Rect2(center.x - target_w * 0.5, center.y - target_h * 0.58, target_w, target_h)
	var mirror = _should_mirror_icon(icon_key, rotation_steps)
	if mirror:
		draw_set_transform(Vector2(rect.position.x + rect.size.x, rect.position.y), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(tex, Rect2(Vector2.ZERO, rect.size), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, rect, false, tint)
	return true


func _should_mirror_icon(icon_key: String, rotation_steps: int) -> bool:
	if ICON_NO_MIRROR.has(icon_key):
		return false
	var normalized = wrapi(rotation_steps, 0, 4)
	# Requested mapping:
	# - arrow down-left / up-right => normal
	# - arrow down-right / up-left => mirrored
	return normalized == 0 or normalized == 2


func _preload_icons() -> void:
	_icon_cache.clear()
	for key in ICON_PATHS.keys():
		_icon_cache[key] = _load_texture(str(ICON_PATHS[key]))


func _get_icon(icon_key: String) -> Texture2D:
	if _icon_cache.has(icon_key):
		return _icon_cache[icon_key] as Texture2D
	var path = str(ICON_PATHS.get(icon_key, ""))
	if path.is_empty():
		return null
	var tex = _load_texture(path)
	_icon_cache[icon_key] = tex
	return tex


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _icon_key_for_type(building_type: String) -> String:
	match building_type:
		"main_building":
			return "main_building"
		"tent_1", "tent_2", "tent_3":
			return "tent_1"
		"cabin", "cabin_1", "cabin_2", "cabin_3":
			return "cabin_1"
		"toilet_block":
			return "toilet_block"
		"shower_block":
			return "shower_block"
		"pub", "pub_2":
			return "pub"
		"restaurant":
			return "restaurant"
		"vecerka":
			return "vecerka"
		"sewer", "water_pump", "sewage_tank":
			return "sewer"
		"power_generator":
			return "power_generator"
		"lamp_post":
			return "lamp_post"
		"path":
			return "path"
		_:
			return ""


func _is_path_at(coord: Vector2i) -> bool:
	if not _is_valid_coord(coord):
		return false
	var tile = grid_manager.get_tile(coord)
	if tile == null or not tile.occupied or tile.occupant == null:
		return false
	var root = _resolve_occupant_root(tile.occupant)
	if root == null:
		return false
	if root.is_in_group("paths"):
		return true
	return str(root.get_meta("building_type", "")) == "path"


func _path_screen_step(offset: Vector2i, tile_w: float, tile_h: float) -> Vector2:
	var base = _grid_to_iso(Vector2i.ZERO, Vector2.ZERO, tile_w, tile_h)
	var shifted = _grid_to_iso(offset, Vector2.ZERO, tile_w, tile_h)
	return shifted - base


func _rotation_to_screen_dir(rotation_steps: int, tile_w: float, tile_h: float) -> Vector2:
	var world_offset = Vector2i(0, 1)
	match wrapi(rotation_steps, 0, 4):
		1:
			world_offset = Vector2i(1, 0)
		2:
			world_offset = Vector2i(0, -1)
		3:
			world_offset = Vector2i(-1, 0)
	var dir = _path_screen_step(world_offset, tile_w, tile_h)
	if dir.length_squared() < 0.001:
		return Vector2(0.0, 1.0)
	return dir.normalized()


func _is_valid_coord(coord: Vector2i) -> bool:
	return grid_manager != null and grid_manager.is_in_bounds(coord)


func _can_place(coord: Vector2i, footprint: Vector2i, _building_type: String) -> bool:
	if grid_manager == null:
		return false
	if not _is_valid_coord(coord):
		return false
	return grid_manager.can_place_footprint(coord, footprint)


func _has_money(building_type: String) -> bool:
	if building_type == "" or building_type == "demolish":
		return true
	var cost = _get_cost(building_type)
	if cost <= 0:
		return true
	var core = get_node_or_null("/root/CoreRoot")
	if core == null or not core.has_method("get_money"):
		return true
	return int(core.get_money()) >= cost


func _get_cost(building_type: String) -> int:
	var econ = _resolve_economy_manager()
	if econ != null and econ.has_method("get_cost"):
		return int(econ.get_cost(building_type))
	return 0


func _resolve_economy_manager() -> Node:
	if _economy_manager != null and is_instance_valid(_economy_manager):
		return _economy_manager
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	_economy_manager = tree.root.find_child("EconomyManager", true, false)
	return _economy_manager


func _get_footprint(building_type: String) -> Vector2i:
	if building_manager != null and building_manager.has_method("get_footprint_for_building"):
		return building_manager.get_footprint_for_building(building_type)
	var def = CoreRoot.registry.get_def(StringName(building_type)) if CoreRoot != null and CoreRoot.registry != null else null
	if def != null:
		return def.footprint
	return Vector2i.ONE


func _supports_rotation(building_type: String) -> bool:
	if building_type == "" or building_type == "path" or building_type == "demolish":
		return false
	return true


func _display_name(building_type: String) -> String:
	var econ = _resolve_economy_manager()
	if econ != null and econ.has_method("get_label"):
		return str(econ.get_label(building_type))
	return building_type


func _reason_text(reason: String) -> String:
	match reason:
		"insufficient_funds":
			return "insufficient funds"
		"blocked_or_out_of_bounds", "placement_denied":
			return "blocked or out of bounds"
		"not_buildable":
			return "tool is not buildable"
		"area_too_large":
			return "max area is 5x5"
		"protected_structure":
			return "protected structures cannot be removed"
		"empty_selection":
			return "selection has no removable targets"
		"demolish_failed":
			return "nothing was removed"
		"authority_not_ready":
			return "authority not ready"
		"out_of_bounds":
			return "selection out of bounds"
		_:
			if reason.is_empty():
				return "request denied"
			return reason


## Push a status line to the builder window.
##
## Repeats are NOT suppressed. Retrying the same failing action is exactly when the
## player most needs confirmation that the click registered -- swallowing the second
## identical message made the UI look frozen.
func _emit_status(text: String, kind: int = STATUS_INFO) -> void:
	_last_status = text
	status_changed.emit(text, kind)


func _any_pending_interaction() -> bool:
	return _pending_build_wait or _pending_demolish_wait or _ghost_locked or _path_drag_active or _demolish_drag_active


func _on_mouse_exited() -> void:
	hover_coord = Vector2i(-1, -1)
	if _path_drag_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_path_drag()
	if _demolish_drag_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_demolish_drag()
	queue_redraw()


func _mouse_inside() -> bool:
	var local = get_local_mouse_position()
	return local.x >= 0.0 and local.y >= 0.0 and local.x <= size.x and local.y <= size.y


func _compute_iso_layout(grid_w: int, grid_h: int) -> Dictionary:
	var draw_dims = _display_grid_dimensions(grid_w, grid_h)
	var draw_w = max(1, draw_dims.x)
	var draw_h = max(1, draw_dims.y)
	var margin = clamp(min(size.x, size.y) * 0.018, 2.0, 16.0)
	var available_w = max(40.0, size.x - (margin * 2.0))
	var available_h = max(40.0, size.y - (margin * 2.0))

	var tile_w_by_width = (available_w * 2.0) / float(draw_w + draw_h)
	var tile_w_by_height = (available_h * 4.0) / float(draw_w + draw_h)
	var tile_w = max(7.0, min(tile_w_by_width, tile_w_by_height))
	tile_w = clamp(tile_w * _zoom_level, 6.0, 120.0)
	var tile_h = tile_w * 0.5

	var map_w = float(draw_w + draw_h) * tile_w * 0.5
	var map_h = float(draw_w + draw_h) * tile_h * 0.5
	var visual_w = map_w + tile_w * MAP_VISUAL_PADDING
	var visual_h = map_h + tile_h * MAP_VISUAL_PADDING * 1.35
	var max_pan_x = max(0.0, (visual_w - size.x) * 0.5)
	var max_pan_y = max(0.0, (visual_h - size.y) * 0.5)
	_pan_offset.x = clamp(_pan_offset.x, -max_pan_x, max_pan_x)
	_pan_offset.y = clamp(_pan_offset.y, -max_pan_y, max_pan_y)
	var map_top_left = Vector2((size.x - map_w) * 0.5, (size.y - map_h) * 0.5)
	var origin = map_top_left + Vector2(float(draw_h) * tile_w * 0.5, tile_h * 0.5) + _pan_offset
	return {
		"tile_w": tile_w,
		"tile_h": tile_h,
		"origin": origin,
	}


func _clamp_pan_offset_for_current_map() -> void:
	if grid_manager == null:
		return
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	if grid_w <= 0 or grid_h <= 0:
		return
	var draw_dims = _display_grid_dimensions(grid_w, grid_h)
	var draw_w = max(1, draw_dims.x)
	var draw_h = max(1, draw_dims.y)
	var margin = clamp(min(size.x, size.y) * 0.018, 2.0, 16.0)
	var available_w = max(40.0, size.x - (margin * 2.0))
	var available_h = max(40.0, size.y - (margin * 2.0))
	var tile_w_by_width = (available_w * 2.0) / float(draw_w + draw_h)
	var tile_w_by_height = (available_h * 4.0) / float(draw_w + draw_h)
	var tile_w = max(7.0, min(tile_w_by_width, tile_w_by_height))
	tile_w = clamp(tile_w * _zoom_level, 6.0, 120.0)
	var tile_h = tile_w * 0.5
	var map_w = float(draw_w + draw_h) * tile_w * 0.5
	var map_h = float(draw_w + draw_h) * tile_h * 0.5
	var visual_w = map_w + tile_w * MAP_VISUAL_PADDING
	var visual_h = map_h + tile_h * MAP_VISUAL_PADDING * 1.35
	var max_pan_x = max(0.0, (visual_w - size.x) * 0.5)
	var max_pan_y = max(0.0, (visual_h - size.y) * 0.5)
	_pan_offset.x = clamp(_pan_offset.x, -max_pan_x, max_pan_x)
	_pan_offset.y = clamp(_pan_offset.y, -max_pan_y, max_pan_y)


func _display_grid_dimensions(grid_w: int, grid_h: int) -> Vector2i:
	if wrapi(MAP_ROTATION_STEPS, 0, 4) % 2 == 1:
		return Vector2i(grid_h, grid_w)
	return Vector2i(grid_w, grid_h)


func _rotate_coord_for_display(coord: Vector2i) -> Vector2i:
	var rot = wrapi(MAP_ROTATION_STEPS, 0, 4)
	if rot == 0 or grid_manager == null:
		return coord
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	match rot:
		1:
			return Vector2i(coord.y, grid_w - 1 - coord.x)
		2:
			return Vector2i(grid_w - 1 - coord.x, grid_h - 1 - coord.y)
		3:
			return Vector2i(grid_h - 1 - coord.y, coord.x)
		_:
			return coord


func _grid_to_iso(coord: Vector2i, origin: Vector2, tile_w: float, tile_h: float) -> Vector2:
	var draw_coord = _rotate_coord_for_display(coord)
	return origin + Vector2((draw_coord.x - draw_coord.y) * tile_w * 0.5, (draw_coord.x + draw_coord.y) * tile_h * 0.5)


func _local_to_grid(local_pos: Vector2) -> Vector2i:
	if grid_manager == null:
		return Vector2i(-1, -1)
	var grid_w: int = int(grid_manager.grid_width)
	var grid_h: int = int(grid_manager.grid_height)
	if grid_w <= 0 or grid_h <= 0:
		return Vector2i(-1, -1)
	var iso = _compute_iso_layout(grid_w, grid_h)
	var tile_w: float = iso.tile_w
	var tile_h: float = iso.tile_h
	var origin: Vector2 = iso.origin
	if tile_w <= 0.0 or tile_h <= 0.0:
		return Vector2i(-1, -1)

	for diagonal in range(grid_w + grid_h):
		for y in range(grid_h):
			var x = diagonal - y
			if x < 0 or x >= grid_w:
				continue
			var coord = Vector2i(x, y)
			var center = _grid_to_iso(coord, origin, tile_w, tile_h)
			if _point_in_diamond(local_pos, center, tile_w, tile_h):
				return coord
	return Vector2i(-1, -1)


func _footprint_center_iso(coord: Vector2i, footprint: Vector2i, origin: Vector2, tile_w: float, tile_h: float) -> Vector2:
	var sum = Vector2.ZERO
	var count = 0
	for oy in range(max(1, footprint.y)):
		for ox in range(max(1, footprint.x)):
			sum += _grid_to_iso(coord + Vector2i(ox, oy), origin, tile_w, tile_h)
			count += 1
	if count <= 0:
		return _grid_to_iso(coord, origin, tile_w, tile_h)
	return sum / float(count)


func _diamond_points(center: Vector2, tile_w: float, tile_h: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	points.push_back(center + Vector2(0.0, -tile_h * 0.5))
	points.push_back(center + Vector2(tile_w * 0.5, 0.0))
	points.push_back(center + Vector2(0.0, tile_h * 0.5))
	points.push_back(center + Vector2(-tile_w * 0.5, 0.0))
	return points


func _draw_diamond(center: Vector2, tile_w: float, tile_h: float, fill: Color, outline: Color, outline_width: float) -> void:
	var points = _diamond_points(center, tile_w, tile_h)
	draw_colored_polygon(points, fill)
	if outline.a > 0.0:
		for i in range(4):
			var a = points[i]
			var b = points[(i + 1) % 4]
			draw_line(a, b, outline, outline_width)


func _point_in_diamond(point: Vector2, center: Vector2, tile_w: float, tile_h: float) -> bool:
	var dx = abs(point.x - center.x) / max(tile_w * 0.5, 0.001)
	var dy = abs(point.y - center.y) / max(tile_h * 0.5, 0.001)
	return (dx + dy) <= 1.0


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


func _rect_from_points(a: Vector2i, b: Vector2i) -> Rect2i:
	var min_x = mini(a.x, b.x)
	var min_y = mini(a.y, b.y)
	var max_x = maxi(a.x, b.x)
	var max_y = maxi(a.y, b.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


func _rect_contains_coord(rect: Rect2i, coord: Vector2i) -> bool:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return false
	return coord.x >= rect.position.x and coord.y >= rect.position.y and coord.x < rect.position.x + rect.size.x and coord.y < rect.position.y + rect.size.y


func _rect_equals(a: Rect2i, b: Rect2i) -> bool:
	return a.position == b.position and a.size == b.size
