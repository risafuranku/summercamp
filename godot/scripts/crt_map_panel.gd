extends Control

signal status_changed(text: String, kind: int)
signal tool_canceled
signal submenu_close_requested
## What is under the cursor, for the status bar ("12:7  Tent").
signal hover_info(text: String)

const T = preload("res://scripts/os98/os_theme.gd")
const SFX_DIR := "res://assets/sfx/builder/"

## Status severity, consumed by builder_module for colour + audio feedback.
const STATUS_INFO := 0
const STATUS_GOOD := 1
const STATUS_DENY := 2

const BG_COLOR := Color(0.03, 0.05, 0.04, 1.0)
const GRID_LINE := Color(0.0, 0.0, 0.0, 0.22)
## Forest floor: moss and needles, varied per tile so the map is not a chessboard.
const GROUND_A := Color(0.25, 0.33, 0.17)
const GROUND_B := Color(0.31, 0.31, 0.18)
const WATER := Color(0.13, 0.27, 0.36)
const DIRT := Color(0.44, 0.37, 0.25)
const EDGE_LEFT := Color(0.30, 0.22, 0.14)
const EDGE_RIGHT := Color(0.22, 0.16, 0.10)
## Buildings that smoke (fire or chimney).
const SMOKERS := {"bonfire": 1.0, "pub": 0.6, "pub_2": 0.6, "restaurant": 0.6, "cabin_2": 0.35, "cabin_3": 0.35}
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
	"tent_2": "res://assets/textury/builder/stan2.png",
	"tent_3": "res://assets/textury/builder/stan3.png",
	"cabin_2": "res://assets/textury/builder/chata2.PNG",
	"cabin_3": "res://assets/textury/builder/chata3.PNG",
	"pub_2": "res://assets/textury/builder/hospoda2.png",
	"caravan_1": "res://assets/textury/builder/iso_caravan.png",
	"bonfire": "res://assets/textury/builder/iso_bonfire.png",
	"sports_field": "res://assets/textury/builder/iso_sports.png",
	"lake_slide": "res://assets/textury/builder/iso_slide.png",
	"vecerka_iso": "res://assets/textury/builder/iso_jednota.png",
	"lamp_iso": "res://assets/textury/builder/iso_lamp.png",
}

const ICON_NO_MIRROR := {
	"main_building": true,
	"tree": true,
	"path": true,
	"lamp_post": true,
	"lamp_iso": true,
	"sports_field": true,
}

var grid_manager
var building_manager

# Guests on the map, RollerCoaster Tycoon style: the camp's real agents, drawn as
# tiny people that walk the paths and vanish into buildings. guest_id -> state.
const GUEST_SHIRTS := {
	"quiet_guy": Color(0.42, 0.56, 0.30),
	"drunk": Color(0.86, 0.72, 0.26),
	"cheap_chick": Color(0.10, 0.09, 0.10),
}
const GUEST_SKIN := Color(0.86, 0.66, 0.50)
var _guests: Dictionary = {}
var _guest_poll: float = 0.0
var _guest_time: float = 0.0
# The extra one. Now and then, in the evening, there is a guest on the map that
# nobody booked: standing still at the edge of the camp, facing the reception.
var _extra_guest_until: float = 0.0
var _extra_guest_cell: Vector2 = Vector2.ZERO
var _extra_guest_rng := RandomNumberGenerator.new()
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

# Feedback and life on the map.
var _time := 0.0
var _fx: Array = []            # {kind, cell: Vector2, t, life, text, color}
var _dropped: Dictionary = {}  # structure origin -> time placed (it drops in)
var _last_hover := Vector2i(-2, -2)
var _sfx_players: Array = []
var _night := 0.0              # 0 day .. 1 deep night, for the tint and the lamps


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
	_time += delta
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i]["t"] = float(_fx[i]["t"]) + delta
		if float(_fx[i]["t"]) >= float(_fx[i]["life"]):
			_fx.remove_at(i)
	_night = _night_amount()
	_update_guests(delta)
	var local = get_local_mouse_position()
	if local.x >= 0.0 and local.y >= 0.0 and local.x <= size.x and local.y <= size.y:
		hover_coord = _local_to_grid(local)
	elif not _path_drag_active and not _demolish_drag_active:
		hover_coord = Vector2i(-1, -1)
	if hover_coord != _last_hover:
		_last_hover = hover_coord
		hover_info.emit(_describe(hover_coord))
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

	# One click builds, as in every tycoon game since 1994; the preview under the
	# cursor already says where, which way and whether it fits.
	var footprint = _get_footprint(selected_building)
	if not _can_place(coord, footprint, selected_building):
		_emit_status("%s does not fit here." % _display_name(selected_building), STATUS_DENY)
		_deny_fx(coord, "Blocked")
		return
	if not _has_money(selected_building):
		_emit_status("Not enough money: %s costs $%d." % [_display_name(selected_building), _get_cost(selected_building)], STATUS_DENY)
		_deny_fx(coord, "$%d" % _get_cost(selected_building))
		return
	_send_build_request(selected_building, coord, _rotation_steps)


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
	var fp := _get_footprint(building_type)
	var mid := Vector2(pos) + Vector2(fp - Vector2i.ONE) * 0.5
	var cost := _get_cost(building_type)
	if building_type == "path":
		# Keep drag status calm while drawing roads.
		if not _path_drag_active:
			_emit_status("Path built at [%d,%d]." % [pos.x, pos.y], STATUS_GOOD)
		_add_fx("dust", mid, 0.45)
		_play("path", -14.0)
	else:
		_emit_status("Built: %s" % _display_name(building_type), STATUS_GOOD)
		_dropped[pos] = _time
		for k in 5:
			_add_fx("dust", mid + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)), 0.7)
		var snd := "place"
		if building_type.begins_with("tent"):
			snd = "tent"
		elif building_type == "lamp_post":
			snd = "lamp"
		_play(snd, -6.0)
	if cost > 0:
		_add_fx("pop", mid, 1.3, "-$%d" % cost, Color8(255, 220, 80))
	queue_redraw()


func _on_build_rejected(building_type: String, pos: Vector2i, rot: int, reason: String) -> void:
	if _pending_build_wait and building_type == _pending_build_type and pos == _pending_build_coord and wrapi(rot, 0, 4) == _pending_build_rot:
		_pending_build_wait = false
		_pending_build_type = ""
		_pending_build_coord = Vector2i(-1, -1)
	_emit_status("Build rejected: %s" % _reason_text(reason), STATUS_DENY)
	_deny_fx(pos, "No")
	queue_redraw()


func _on_demolish_confirmed(area: Rect2i, removed_count: int, fee_paid: int, refund_total: int) -> void:
	if _pending_demolish_wait and _rect_equals(area, _pending_demolish_rect):
		_pending_demolish_wait = false
	_demolish_selection_active = false
	_emit_status("Cleared %d. Refund +$%d, bulldozer -$%d." % [removed_count, refund_total, fee_paid], STATUS_GOOD)
	var n := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if n < 12:
				_add_fx("dust", Vector2(x, y), 0.8)
				n += 1
	var mid := Vector2(area.position) + Vector2(area.size - Vector2i.ONE) * 0.5
	if refund_total > 0:
		_add_fx("pop", mid + Vector2(0, -0.3), 1.4, "+$%d" % refund_total, Color8(120, 255, 120))
	if fee_paid > 0:
		_add_fx("pop", mid, 1.3, "-$%d" % fee_paid, Color8(255, 220, 80))
	_play("bulldoze", -6.0)
	queue_redraw()


func _on_demolish_rejected(area: Rect2i, reason: String) -> void:
	if _pending_demolish_wait and _rect_equals(area, _pending_demolish_rect):
		_pending_demolish_wait = false
	_emit_status("Demolish rejected: %s" % _reason_text(reason), STATUS_DENY)
	_deny_fx(area.position, "No")
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
	var dims := _display_grid_dimensions(grid_w, grid_h)

	var draw_entries: Array = []
	var lights: Array = []
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
			_draw_ground_tile(center, tile_w, tile_h, tile, coord)
			_draw_map_edge(center, tile_w, tile_h, _rotate_coord_for_display(coord), dims)

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

	_append_guest_entries(draw_entries, origin, tile_w, tile_h)
	# Painter's order in display space; ties keep the structure tie-breakers.
	draw_entries.sort_custom(func(a, b):
		var ao := float(a.get("order", 0))
		var bo := float(b.get("order", 0))
		if not is_equal_approx(ao, bo):
			return ao < bo
		var ax := int(a.get("anchor_x", 0))
		var bx := int(b.get("anchor_x", 0))
		if ax != bx:
			return ax < bx
		return int(a.get("anchor_y", 0)) < int(b.get("anchor_y", 0))
	)

	for entry in draw_entries:
		if entry.has("guest"):
			_draw_guest(entry, tile_h)
		else:
			_draw_structure(entry, tile_w, tile_h)
			var ty := str(entry.get("type", ""))
			if SMOKERS.has(ty):
				_draw_smoke(entry["center"], tile_h, float(SMOKERS[ty]), int(entry["origin"].x * 7 + entry["origin"].y * 13))
			if ty == "lamp_post" or ty == "bonfire":
				lights.append([entry["center"], ty])
			elif ty == "path" and _path_has_lamp(entry["origin"]):
				lights.append([entry["center"] + Vector2(tile_w * 0.2, -tile_h * 0.05), "lamp_post"])

	_draw_night(lights, tile_w, tile_h)
	_draw_fx(origin, tile_w, tile_h)

	_draw_path_drag_preview(origin, tile_w, tile_h)
	_draw_ghost_preview(origin, tile_w, tile_h)
	_draw_demolish_preview(origin, tile_w, tile_h)

	if _is_valid_coord(hover_coord):
		var hover_center = _grid_to_iso(hover_coord, origin, tile_w, tile_h)
		_draw_diamond(hover_center, tile_w, tile_h, HOVER_FILL, HOVER_LINE, 1.8)

	_draw_rotation_panel()


# ── guests ────────────────────────────────────────────────────────────────────

func _update_guests(delta: float) -> void:
	_guest_time += delta
	_guest_poll -= delta
	if _guest_poll > 0.0:
		return
	_guest_poll = 0.1
	var agents = get_tree().root.find_child("GuestAgents", true, false) if get_tree() != null else null
	if agents == null or not agents.has_method("get_visible_guest_positions") or grid_manager == null:
		_guests.clear()
		return
	var seen := {}
	for g_any in agents.get_visible_guest_positions():
		var g: Dictionary = g_any
		var id := int(g.get("guest_id", -1))
		var cell := _world_to_cell_f(g.get("position", Vector3.ZERO))
		var prev: Dictionary = _guests.get(id, {})
		var moving := not prev.is_empty() and Vector2(prev.get("cell", cell)).distance_to(cell) > 0.004
		_guests[id] = {"cell": cell, "archetype": str(g.get("archetype", "")), "moving": moving, "phase": float(prev.get("phase", randf() * 10.0))}
		seen[id] = true
	for id in _guests.keys():
		if not seen.has(id):
			_guests.erase(id)
	_update_extra_guest()


func _update_extra_guest() -> void:
	if _guest_time < _extra_guest_until or _guests.is_empty():
		return
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null:
		return
	var hour := 0.0
	var tree := get_tree()
	var main = tree.current_scene if tree != null else null
	if main != null:
		hour = float(main.get("_time_of_day_hours")) if main.get("_time_of_day_hours") != null else 0.0
	# Only from late afternoon, rarely (roughly once per in-game evening at the PC).
	if hour < 16.5 or _extra_guest_rng.randf() > 0.0016:
		return
	var gw := float(grid_manager.grid_width)
	var gh := float(grid_manager.grid_height)
	var edge := _extra_guest_rng.randi_range(0, 3)
	var t := _extra_guest_rng.randf_range(0.1, 0.9)
	match edge:
		0: _extra_guest_cell = Vector2(t * gw, 0.4)
		1: _extra_guest_cell = Vector2(gw - 1.4, t * gh)
		2: _extra_guest_cell = Vector2(t * gw, gh - 2.4)
		_: _extra_guest_cell = Vector2(0.4, t * gh)
	_extra_guest_until = _guest_time + _extra_guest_rng.randf_range(14.0, 26.0)


func _world_to_cell_f(p: Vector3) -> Vector2:
	var mc: Vector3 = grid_manager.get_map_min_corner() if grid_manager.has_method("get_map_min_corner") else Vector3.ZERO
	var ts: float = float(grid_manager.tile_size)
	return Vector2((p.x - mc.x) / ts - 0.5, (p.z - mc.z) / ts - 0.5)


## Display-space cell (the map is drawn rotated), fractional.
func _display_cell_f(c: Vector2) -> Vector2:
	var gw := float(grid_manager.grid_width)
	var gh := float(grid_manager.grid_height)
	match wrapi(MAP_ROTATION_STEPS, 0, 4):
		1: return Vector2(c.y, gw - 1.0 - c.x)
		2: return Vector2(gw - 1.0 - c.x, gh - 1.0 - c.y)
		3: return Vector2(gh - 1.0 - c.y, c.x)
	return c


## Same projection as _grid_to_iso, for fractional cells.
func _cell_to_iso_f(c: Vector2, origin: Vector2, tile_w: float, tile_h: float) -> Vector2:
	var d := _display_cell_f(c)
	return origin + Vector2((d.x - d.y) * tile_w * 0.5, (d.x + d.y) * tile_h * 0.5)


func _append_guest_entries(entries: Array, origin: Vector2, tile_w: float, tile_h: float) -> void:
	for id in _guests.keys():
		var g: Dictionary = _guests[id]
		var p := _cell_to_iso_f(g["cell"], origin, tile_w, tile_h)
		var dc := _display_cell_f(g["cell"])
		entries.append({"guest": true, "pos": p, "order": dc.x + dc.y + 0.6, "archetype": g["archetype"], "moving": g["moving"], "phase": g["phase"], "facing": 0})
	if _guest_time < _extra_guest_until:
		var p2 := _cell_to_iso_f(_extra_guest_cell, origin, tile_w, tile_h)
		var dc2 := _display_cell_f(_extra_guest_cell)
		entries.append({"guest": true, "pos": p2, "order": dc2.x + dc2.y + 0.6, "archetype": "", "moving": false, "phase": 0.0, "extra": true})


## A guest as RCT drew them: a few pixels tall, shirt colour by archetype, head,
## legs that scissor when walking. Sized to the tile so zoom keeps proportions.
func _draw_guest(e: Dictionary, tile_h: float) -> void:
	var u := maxf(2.0, roundf(tile_h * 0.12))
	var p: Vector2 = (Vector2(e["pos"]) / u).floor() * u
	var shirt: Color = GUEST_SHIRTS.get(str(e["archetype"]), Color(0.55, 0.52, 0.48))
	var skin := GUEST_SKIN
	if e.has("extra"):
		# Greyer, darker, too tall by one pixel, perfectly still.
		shirt = Color(0.20, 0.21, 0.22)
		skin = Color(0.62, 0.64, 0.66)
	var step := 0.0
	if bool(e["moving"]):
		step = 1.0 if fmod(_guest_time * 6.0 + float(e["phase"]), 2.0) < 1.0 else -1.0
	var legs := Color(0.20, 0.20, 0.26)
	var h := 7.0 if e.has("extra") else 6.0
	# shadow
	draw_rect(Rect2(p + Vector2(-1.5 * u, -0.5 * u), Vector2(3.0 * u, u)), Color(0, 0, 0, 0.35))
	# legs
	draw_rect(Rect2(p + Vector2(-u, -2.0 * u), Vector2(u, 2.0 * u + (step if step > 0 else 0.0) * 0.0)), legs)
	draw_rect(Rect2(p + Vector2(0.0, -2.0 * u), Vector2(u, 2.0 * u)), legs)
	if step != 0.0:
		draw_rect(Rect2(p + Vector2(-u + step * u, -u), Vector2(u, u)), legs)
	# body
	draw_rect(Rect2(p + Vector2(-u, -(h - 2.0) * u), Vector2(2.0 * u, (h - 4.0) * u)), shirt)
	# head
	draw_rect(Rect2(p + Vector2(-u, -h * u), Vector2(2.0 * u, 2.0 * u)), skin)
	if e.has("extra"):
		# Two dots for eyes, which none of the others have.
		draw_rect(Rect2(p + Vector2(-u, -(h - 1.0) * u), Vector2(u * 0.5, u * 0.5)), Color(0, 0, 0))
		draw_rect(Rect2(p + Vector2(0.5 * u, -(h - 1.0) * u), Vector2(u * 0.5, u * 0.5)), Color(0, 0, 0))


func _draw_ground_tile(center: Vector2, tile_w: float, tile_h: float, tile, coord := Vector2i.ZERO) -> void:
	var h := _hash01(coord)
	var fill := GROUND_A.lerp(GROUND_B, h)
	var line := GRID_LINE
	if tile.tile_type == grid_manager.TILE_LAKE:
		fill = WATER.lightened(h * 0.05)
		line = Color(0.0, 0.0, 0.0, 0.10)
		_draw_diamond(center, tile_w, tile_h, fill, line, 1.0)
		# Light on the water, moving.
		var ph := _time * 1.3 + h * 6.28
		var a := 0.18 + 0.14 * sin(ph)
		var off := Vector2(sin(ph * 0.7) * tile_w * 0.12, cos(ph * 0.5) * tile_h * 0.10)
		draw_line(center + off - Vector2(tile_w * 0.12, 0), center + off + Vector2(tile_w * 0.12, 0), Color(0.7, 0.85, 1.0, a), 1.0)
		return
	elif tile.tile_type == grid_manager.TILE_RESERVED:
		fill = DIRT.lerp(DIRT.darkened(0.1), h)
	_draw_diamond(center, tile_w, tile_h, fill, line, 1.0)
	# A few darker specks: needles, stones.
	if tile_w >= 18.0:
		var sp := Vector2((h - 0.5) * tile_w * 0.4, (_hash01(coord + Vector2i(7, 3)) - 0.5) * tile_h * 0.4)
		draw_rect(Rect2((center + sp).floor(), Vector2(2, 1)), Color(0, 0, 0, 0.18))


## The cut edge of the land along the two front sides of the map, like RCT.
func _draw_map_edge(center: Vector2, tile_w: float, tile_h: float, d: Vector2i, dims: Vector2i) -> void:
	var depth := tile_h * 0.9
	var bottom := center + Vector2(0, tile_h * 0.5)
	if d.y == dims.y - 1:
		var left := center + Vector2(-tile_w * 0.5, 0)
		draw_colored_polygon(PackedVector2Array([left, bottom, bottom + Vector2(0, depth), left + Vector2(0, depth)]), EDGE_LEFT)
	if d.x == dims.x - 1:
		var right := center + Vector2(tile_w * 0.5, 0)
		draw_colored_polygon(PackedVector2Array([bottom, right, right + Vector2(0, depth), bottom + Vector2(0, depth)]), EDGE_RIGHT)


func _hash01(c: Vector2i) -> float:
	var n := (c.x * 73856093) ^ (c.y * 19349663)
	return float(absi(n) % 1000) / 1000.0


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
		if _path_has_lamp(entry.get("origin", Vector2i.ZERO)):
			var lc := center + Vector2(tile_w * 0.2, -tile_h * 0.05)
			_draw_icon(lc, Vector2(tile_w * 0.6, tile_h * 1.5), _icon_key_for_type("lamp_post"), 0, Color.WHITE)
		return

	var icon_key = _icon_key_for_type(building_type)
	if icon_key != "":
		var scale_xy = maxf(1.0, (float(footprint.x) + float(footprint.y)) * 0.5)
		var draw_size = Vector2(tile_w * scale_xy * 1.24, tile_h * scale_xy * 1.70)
		# Freshly built: it drops in from above and settles with a little bounce.
		var origin_c: Vector2i = entry.get("origin", Vector2i.ZERO)
		if _dropped.has(origin_c):
			var age := _time - float(_dropped[origin_c])
			if age > 0.5:
				_dropped.erase(origin_c)
			else:
				var k := clampf(age / 0.35, 0.0, 1.0)
				center.y -= (1.0 - k) * (1.0 - k) * tile_h * 2.5
				if k >= 1.0:
					draw_size.y *= 1.0 - 0.08 * sin((age - 0.35) / 0.15 * PI)
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
	# The price on a little tag, red when it does not fit or you cannot pay.
	var tag := "$%d" % _get_cost(selected_building)
	if not can_fit:
		tag = "Blocked"
	elif not can_afford:
		tag = "$%d - no money" % _get_cost(selected_building)
	var tw := T.FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var tp := (center + Vector2(tile_w * 0.45, -tile_h * 1.4)).floor()
	draw_rect(Rect2(tp, Vector2(tw + 6, 14)), T.TOOLTIP if can_place else Color8(255, 210, 210))
	draw_rect(Rect2(tp, Vector2(tw + 6, 14)), T.DARK, false, 1.0)
	draw_string(T.FONT, tp + Vector2(3, 11), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)


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
	if selected_building == "" or not _supports_rotation(selected_building):
		return
	var panel_size = Vector2(70.0, 76.0)
	var panel_pos = Vector2(size.x - panel_size.x - 6.0, 6.0)
	var panel_rect = Rect2(panel_pos, panel_size)
	draw_style_box(T.box("window", T.FACE, Vector4.ZERO), panel_rect)

	var center = panel_rect.position + panel_rect.size * 0.5
	var active = _rotation_steps
	var arrows = [
		{"id": 2, "pos": center + Vector2(0.0, -24.0), "dir": Vector2(0.0, -1.0)},
		{"id": 1, "pos": center + Vector2(20.0, -6.0), "dir": Vector2(1.0, 0.0)},
		{"id": 0, "pos": center + Vector2(0.0, 12.0), "dir": Vector2(0.0, 1.0)},
		{"id": 3, "pos": center + Vector2(-20.0, -6.0), "dir": Vector2(-1.0, 0.0)},
	]
	for arrow in arrows:
		var arrow_id = int(arrow.get("id", -1))
		var color = T.SHADOW
		if arrow_id == active:
			color = T.NAVY
		_draw_panel_arrow(arrow.get("pos", center), arrow.get("dir", Vector2.RIGHT), color)

	var label = ROTATION_LABELS[active]
	var lw := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	draw_string(T.FONT, panel_rect.position + Vector2((panel_size.x - lw) * 0.5, panel_size.y - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)


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
		"tent_1":
			return "tent_1"
		"tent_2", "tent_3", "cabin_2", "cabin_3":
			return building_type
		"cabin", "cabin_1":
			return "cabin_1"
		"caravan_1", "bonfire", "sports_field", "lake_slide":
			return building_type
		"toilet_block":
			return "toilet_block"
		"shower_block":
			return "shower_block"
		"pub":
			return "pub"
		"pub_2":
			return "pub_2"
		"restaurant":
			return "restaurant"
		"vecerka":
			return "vecerka_iso" if _get_icon("vecerka_iso") != null else "vecerka"
		"sewer", "water_pump", "sewage_tank":
			return "sewer"
		"power_generator":
			return "power_generator"
		"lamp_post":
			return "lamp_iso" if _get_icon("lamp_iso") != null else "lamp_post"
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
	# A lamp may go on a path tile; it stands at the edge.
	if _building_type == "lamp_post" and _path_cell(coord) and not _path_has_lamp(coord):
		return true
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
		# "Tent Lv1 (1x1)" -> "Tent Lv1": the footprint is the catalogue's business.
		var label := str(econ.get_label(building_type))
		var cut := label.find(" (")
		return label.substr(0, cut) if cut > 0 else label
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



# ── feedback and life ────────────────────────────────────────────────────────

func _add_fx(kind: String, cell: Vector2, life: float, text := "", color := Color.WHITE) -> void:
	_fx.append({"kind": kind, "cell": cell, "t": 0.0, "life": life, "text": text, "color": color, "seed": randf()})


func _deny_fx(coord: Vector2i, text: String) -> void:
	if _is_valid_coord(coord):
		_add_fx("pop", Vector2(coord), 0.9, text, Color8(255, 90, 80))


func _draw_fx(origin: Vector2, tile_w: float, tile_h: float) -> void:
	for f in _fx:
		var k := float(f["t"]) / float(f["life"])
		var p := _cell_to_iso_f(f["cell"], origin, tile_w, tile_h)
		match str(f["kind"]):
			"dust":
				var sd := float(f["seed"])
				for i in 4:
					var a := sd * TAU + i * 1.7
					var r := tile_h * (0.15 + k * 0.55)
					var q := p + Vector2(cos(a) * r * 1.6, sin(a) * r * 0.7 - k * tile_h * 0.4)
					draw_circle(q, tile_h * (0.14 + k * 0.18), Color(0.62, 0.56, 0.46, 0.55 * (1.0 - k)))
			"pop":
				var txt := str(f["text"])
				var q := (p + Vector2(0, -tile_h * (1.2 + k * 1.6))).floor()
				var col: Color = f["color"]
				col.a = 1.0 - maxf(0.0, k - 0.6) / 0.4
				var w := T.FONT_BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
				draw_string(T.FONT_BOLD, q + Vector2(-w * 0.5 + 1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color(0, 0, 0, col.a))
				draw_string(T.FONT_BOLD, q + Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)


## Grey puffs rising from a fire or a chimney.
func _draw_smoke(center: Vector2, tile_h: float, strength: float, seed: int) -> void:
	for i in 4:
		var ph := fmod(_time * 0.35 + float(i) * 0.25 + float(seed % 17) * 0.06, 1.0)
		var q := center + Vector2(sin(ph * 5.0 + seed) * tile_h * 0.25 + ph * tile_h * 0.4, -tile_h * (1.0 + ph * 2.4))
		draw_circle(q, tile_h * (0.10 + ph * 0.22), Color(0.72, 0.72, 0.70, 0.42 * strength * (1.0 - ph)))


## Dusk and night: the map darkens, lamps and fires make pools of light.
func _draw_night(lights: Array, tile_w: float, tile_h: float) -> void:
	if _night <= 0.01:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.10, 0.55 * _night))
	for l in lights:
		var c: Vector2 = l[0]
		var fire: bool = l[1] == "bonfire"
		var col := Color(1.0, 0.55, 0.15) if fire else Color(1.0, 0.86, 0.45)
		var flick := 1.0 + (0.12 * sin(_time * 11.0 + c.x) if fire else 0.0)
		for r in 3:
			var rr := tile_w * (0.9 - r * 0.25) * flick
			col.a = (0.10 + r * 0.07) * _night
			draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, rr, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not fire:
			draw_circle(c + Vector2(-tile_h * 0.15, -tile_h * 0.65), maxf(1.5, tile_h * 0.12), Color(1.0, 0.95, 0.7, _night))


func _night_amount() -> float:
	var tree := get_tree()
	var main = tree.current_scene if tree != null else null
	if main == null or main.get("_time_of_day_hours") == null:
		return 0.0
	var h := float(main.get("_time_of_day_hours"))
	if h >= 7.0 and h <= 18.5:
		return 0.0
	if h > 18.5 and h < 21.0:
		return (h - 18.5) / 2.0 if h < 20.5 else 1.0
	if h > 5.0 and h < 7.0:
		return (7.0 - h) / 2.0
	return 1.0


func _play(name: String, db := 0.0) -> void:
	var path := SFX_DIR + name + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = randf_range(0.94, 1.06)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## "12:7  Tent", "4:3  Forest", "20:1  Lake", for the status bar.
func _describe(coord: Vector2i) -> String:
	if not _is_valid_coord(coord):
		return ""
	var tile = grid_manager.get_tile(coord)
	var what := "Forest floor"
	if tile != null:
		if tile.tile_type == grid_manager.TILE_LAKE:
			what = "Lake"
		elif tile.tile_type == grid_manager.TILE_RESERVED:
			what = "Camp entrance"
		if tile.occupied and tile.occupant != null:
			var root = _resolve_occupant_root(tile.occupant)
			if root != null and root.is_in_group("trees"):
				what = "Pine tree"
			elif root != null:
				what = _display_name(str(root.get_meta("building_type", "")))
	return "%d:%d  %s" % [coord.x, coord.y, what]



func _path_cell(coord: Vector2i) -> bool:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	return state != null and str((state.grid.cells.get(coord, {}) as Dictionary).get("type", "")) == "path"


func _path_has_lamp(coord: Vector2i) -> bool:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	return state != null and bool((state.grid.cells.get(coord, {}) as Dictionary).get("lamp", false))
