extends Control

const MAP_PANEL_SCRIPT = preload("res://scripts/guest_assignment_map_panel.gd")

signal panel_closed

var _guest_manager: Node
var _active: bool = false

var _root: Control
var _panel: PanelContainer
var _title_label: Label
var _time_label: Label
var _status_label: Label
var _waiting_list: ItemList
var _selection_label: Label
var _map_panel
var _assign_btn: Button
var _clean_btn: Button
var _clean_all_btn: Button
var _refresh_btn: Button
var _close_btn: Button

var _snapshot: Dictionary = {}
var _last_selected_guest_id: int = -1
var _last_selected_accommodation_key: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()


func setup(guest_manager: Node) -> void:
	_guest_manager = guest_manager


func is_open() -> bool:
	return _active


func open_panel() -> void:
	_active = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_snapshot()


func close_panel() -> void:
	if not _active:
		return
	_active = false
	visible = false
	panel_closed.emit()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(margin)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.13, 0.98)
	panel_style.border_color = Color(0.40, 0.40, 0.46, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 2
	panel_style.corner_radius_top_right = 2
	panel_style.corner_radius_bottom_left = 2
	panel_style.corner_radius_bottom_right = 2
	_panel.add_theme_stylebox_override("panel", panel_style)
	margin.add_child(_panel)

	var panel_margin = MarginContainer.new()
	panel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_theme_constant_override("margin_left", 12)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_right", 12)
	panel_margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(panel_margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 8)
	panel_margin.add_child(root_vbox)

	var header_row = HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(header_row)

	_title_label = Label.new()
	_title_label.text = "Recepcni zapisnik"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.97, 1.0))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_title_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.add_theme_font_size_override("font_size", 16)
	_time_label.add_theme_color_override("font_color", Color(0.78, 0.80, 0.88, 1.0))
	header_row.add_child(_time_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.76, 0.78, 0.84, 1.0))
	root_vbox.add_child(_status_label)

	var body_split = HBoxContainer.new()
	body_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.add_theme_constant_override("separation", 10)
	root_vbox.add_child(body_split)

	var guest_column = VBoxContainer.new()
	guest_column.custom_minimum_size = Vector2(300.0, 0.0)
	guest_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guest_column.add_theme_constant_override("separation", 6)
	body_split.add_child(guest_column)

	var waiting_title = Label.new()
	waiting_title.text = "Hoste cekajici na recepci"
	waiting_title.add_theme_font_size_override("font_size", 16)
	waiting_title.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94, 1.0))
	guest_column.add_child(waiting_title)

	_waiting_list = ItemList.new()
	_waiting_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waiting_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_waiting_list.allow_reselect = true
	_waiting_list.select_mode = ItemList.SELECT_SINGLE
	_waiting_list.item_selected.connect(_on_waiting_guest_selected)
	guest_column.add_child(_waiting_list)

	var map_column = VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_column.add_theme_constant_override("separation", 6)
	body_split.add_child(map_column)

	var map_title = Label.new()
	map_title.text = "Mapa kempu"
	map_title.add_theme_font_size_override("font_size", 16)
	map_title.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94, 1.0))
	map_column.add_child(map_title)

	_map_panel = MAP_PANEL_SCRIPT.new()
	_map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _map_panel.has_signal("accommodation_selected"):
		_map_panel.accommodation_selected.connect(_on_accommodation_selected)
	map_column.add_child(_map_panel)

	_selection_label = Label.new()
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_label.add_theme_font_size_override("font_size", 14)
	_selection_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92, 1.0))
	root_vbox.add_child(_selection_label)

	var button_row = HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(button_row)

	_assign_btn = Button.new()
	_assign_btn.text = "Priradit hosta"
	_assign_btn.pressed.connect(_on_assign_pressed)
	button_row.add_child(_assign_btn)

	_clean_btn = Button.new()
	_clean_btn.text = "Uklidit vybrane"
	_clean_btn.pressed.connect(_on_clean_pressed)
	button_row.add_child(_clean_btn)

	_clean_all_btn = Button.new()
	_clean_all_btn.text = "Uklidit vse spinave"
	_clean_all_btn.pressed.connect(_on_clean_all_pressed)
	button_row.add_child(_clean_all_btn)

	_refresh_btn = Button.new()
	_refresh_btn.text = "Obnovit"
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	button_row.add_child(_refresh_btn)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)

	_close_btn = Button.new()
	_close_btn.text = "Zavrit"
	_close_btn.pressed.connect(close_panel)
	button_row.add_child(_close_btn)


func _resolve_guest_manager() -> Node:
	if _guest_manager != null and is_instance_valid(_guest_manager):
		return _guest_manager
	_guest_manager = get_node_or_null("/root/GuestManager")
	return _guest_manager


func _refresh_snapshot() -> void:
	var guest_manager = _resolve_guest_manager()
	if guest_manager == null or not guest_manager.has_method("get_assignment_snapshot"):
		_snapshot = {}
		_waiting_list.clear()
		if _map_panel != null and _map_panel.has_method("set_snapshot"):
			_map_panel.set_snapshot({})
		_status_label.text = "GuestManager neni dostupny."
		_time_label.text = ""
		_selection_label.text = "Vyber hosta a ubytovani."
		_update_button_states()
		return

	var raw_snapshot = guest_manager.get_assignment_snapshot()
	_snapshot = raw_snapshot.duplicate(true) if raw_snapshot is Dictionary else {}
	if _map_panel != null and _map_panel.has_method("set_snapshot"):
		_map_panel.set_snapshot(_snapshot)
	if not _last_selected_accommodation_key.is_empty() and _map_panel.has_method("select_accommodation_key"):
		_map_panel.select_accommodation_key(_last_selected_accommodation_key)
	_populate_waiting_list()
	_update_time_label()
	_status_label.text = _build_overview_text()
	_update_selection_label()
	_update_button_states()


func _populate_waiting_list() -> void:
	_waiting_list.clear()
	var waiting_any = _snapshot.get("waiting_guests", [])
	if not (waiting_any is Array):
		_last_selected_guest_id = -1
		return

	var waiting: Array = waiting_any
	for guest_any in waiting:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var guest_id = int(guest.get("id", -1))
		if guest_id <= 0:
			continue
		var guest_name = str(guest.get("name", "Host"))
		var stay_nights = max(1, int(guest.get("stay_nights", 1)))
		var item_text = "#%d  %s  (%d noci)" % [guest_id, guest_name, stay_nights]
		var item_index = _waiting_list.item_count
		_waiting_list.add_item(item_text)
		_waiting_list.set_item_metadata(item_index, guest_id)
		if guest_id == _last_selected_guest_id:
			_waiting_list.select(item_index)

	if _waiting_list.item_count == 0:
		_last_selected_guest_id = -1
		return

	if _waiting_list.get_selected_items().is_empty():
		_waiting_list.select(0)
		_last_selected_guest_id = int(_waiting_list.get_item_metadata(0))


func _update_time_label() -> void:
	var day = max(1, int(_snapshot.get("day", 1)))
	var hour = clampi(int(_snapshot.get("hour", 9)), 0, 23)
	var minute = clampi(int(_snapshot.get("minute", 0)), 0, 59)
	_time_label.text = "Den %d   %02d:%02d" % [day, hour, minute]


func _build_overview_text() -> String:
	var waiting_count = 0
	var waiting_any = _snapshot.get("waiting_guests", [])
	if waiting_any is Array:
		waiting_count = (waiting_any as Array).size()

	var clean_count := 0
	var occupied_count := 0
	var dirty_count := 0
	var accommodations_any = _snapshot.get("accommodations", {})
	if accommodations_any is Dictionary:
		for acc_any in (accommodations_any as Dictionary).values():
			if not (acc_any is Dictionary):
				continue
			var status = str((acc_any as Dictionary).get("status", "clean"))
			if status == "occupied":
				occupied_count += 1
			elif status == "dirty":
				dirty_count += 1
			else:
				clean_count += 1

	return "Cekajici hoste: %d | Ubytovani clean:%d occupied:%d dirty:%d" % [
		waiting_count,
		clean_count,
		occupied_count,
		dirty_count,
	]


func _selected_guest_id() -> int:
	if _waiting_list == null:
		return -1
	var selected = _waiting_list.get_selected_items()
	if selected.is_empty():
		return -1
	var idx = int(selected[0])
	if idx < 0 or idx >= _waiting_list.item_count:
		return -1
	return int(_waiting_list.get_item_metadata(idx))


func _selected_accommodation_key() -> String:
	if _map_panel != null and _map_panel.has_method("get_selected_accommodation_key"):
		var key = str(_map_panel.get_selected_accommodation_key())
		if not key.is_empty():
			_last_selected_accommodation_key = key
	return _last_selected_accommodation_key


func _update_selection_label() -> void:
	var guest_id = _selected_guest_id()
	var guest_text = "Host: nevybran"
	if guest_id > 0:
		guest_text = _guest_brief(guest_id)

	var acc_key = _selected_accommodation_key()
	var accommodation_text = "Ubytovani: nevybrano"
	if not acc_key.is_empty():
		accommodation_text = _accommodation_brief(acc_key)

	_selection_label.text = "%s | %s" % [guest_text, accommodation_text]


func _guest_brief(guest_id: int) -> String:
	var waiting_any = _snapshot.get("waiting_guests", [])
	if waiting_any is Array:
		for guest_any in waiting_any:
			if not (guest_any is Dictionary):
				continue
			var guest: Dictionary = guest_any
			if int(guest.get("id", -1)) != guest_id:
				continue
			return "Host: #%d %s" % [guest_id, str(guest.get("name", "Host"))]
	return "Host: #%d" % guest_id


func _accommodation_brief(acc_key: String) -> String:
	var accommodations_any = _snapshot.get("accommodations", {})
	if not (accommodations_any is Dictionary):
		return "Ubytovani: %s" % acc_key
	var accommodations: Dictionary = accommodations_any
	if not accommodations.has(acc_key):
		return "Ubytovani: %s" % acc_key
	var acc_any = accommodations[acc_key]
	if not (acc_any is Dictionary):
		return "Ubytovani: %s" % acc_key
	var acc: Dictionary = acc_any
	var occupancy = _guest_count(acc)
	var capacity = max(1, int(acc.get("capacity", 1)))
	var status = str(acc.get("status", "clean"))
	return "Ubytovani: %s (%s) %d/%d [%s]" % [
		_acc_type_label(str(acc.get("building_type", ""))),
		acc_key,
		occupancy,
		capacity,
		status,
	]


func _update_button_states() -> void:
	var guest_id = _selected_guest_id()
	var acc_key = _selected_accommodation_key()
	var accommodations_any = _snapshot.get("accommodations", {})
	var can_assign = false
	var can_clean = false
	if guest_id > 0 and not acc_key.is_empty() and accommodations_any is Dictionary and (accommodations_any as Dictionary).has(acc_key):
		var acc_any = (accommodations_any as Dictionary)[acc_key]
		if acc_any is Dictionary:
			can_assign = _is_accommodation_available(acc_any)
			can_clean = str((acc_any as Dictionary).get("status", "clean")) == "dirty" and _guest_count(acc_any) == 0

	_assign_btn.disabled = not can_assign
	_clean_btn.disabled = not can_clean

	var dirty_exists = false
	if accommodations_any is Dictionary:
		for acc_any in (accommodations_any as Dictionary).values():
			if acc_any is Dictionary and str((acc_any as Dictionary).get("status", "clean")) == "dirty":
				dirty_exists = true
				break
	_clean_all_btn.disabled = not dirty_exists


func _on_waiting_guest_selected(index: int) -> void:
	if index < 0 or index >= _waiting_list.item_count:
		_last_selected_guest_id = -1
	else:
		_last_selected_guest_id = int(_waiting_list.get_item_metadata(index))
	_update_selection_label()
	_update_button_states()


func _on_accommodation_selected(acc_key: String) -> void:
	_last_selected_accommodation_key = acc_key
	_update_selection_label()
	_update_button_states()


func _on_assign_pressed() -> void:
	var guest_id = _selected_guest_id()
	if guest_id <= 0:
		_status_label.text = "Nejdriv vyber hosta z BOOK fronty."
		return
	var acc_key = _selected_accommodation_key()
	if acc_key.is_empty():
		_status_label.text = "Nejdriv vyber ubytovani na mape."
		return

	var guest_manager = _resolve_guest_manager()
	if guest_manager == null or not guest_manager.has_method("request_assignment_by_key"):
		_status_label.text = "Prirazeni selhalo: GuestManager API chybi."
		return

	var result_any = guest_manager.request_assignment_by_key(guest_id, acc_key, "player_notebook")
	if result_any is Dictionary and bool((result_any as Dictionary).get("ok", false)):
		_status_label.text = "Host #%d byl prirazen do %s." % [guest_id, acc_key]
	else:
		_status_label.text = "Prirazeni selhalo: %s" % _reason_text(result_any)
	_refresh_snapshot()


func _on_clean_pressed() -> void:
	var acc_key = _selected_accommodation_key()
	if acc_key.is_empty():
		_status_label.text = "Nejdriv vyber ubytovani na mape."
		return

	var guest_manager = _resolve_guest_manager()
	if guest_manager == null or not guest_manager.has_method("request_cleaning_by_key"):
		_status_label.text = "Uklid selhal: GuestManager API chybi."
		return

	var result_any = guest_manager.request_cleaning_by_key(acc_key, "player_notebook")
	if result_any is Dictionary and bool((result_any as Dictionary).get("ok", false)):
		_status_label.text = "Ubytovani %s je uklizene a ciste." % acc_key
	else:
		_status_label.text = "Uklid selhal: %s" % _reason_text(result_any)
	_refresh_snapshot()


func _on_clean_all_pressed() -> void:
	var guest_manager = _resolve_guest_manager()
	if guest_manager == null or not guest_manager.has_method("request_clean_all_dirty"):
		_status_label.text = "Uklid selhal: GuestManager API chybi."
		return

	var result_any = guest_manager.request_clean_all_dirty("player_notebook")
	if result_any is Dictionary:
		var result: Dictionary = result_any
		var cleaned = max(0, int(result.get("cleaned_count", 0)))
		if cleaned > 0:
			_status_label.text = "Uklizeno spinavych ubytovani: %d" % cleaned
		else:
			_status_label.text = "Neni co uklizet."
	else:
		_status_label.text = "Uklid selhal."
	_refresh_snapshot()


func _on_refresh_pressed() -> void:
	_refresh_snapshot()


func _reason_text(result_any) -> String:
	if not (result_any is Dictionary):
		return "neznama chyba"
	var reason = str((result_any as Dictionary).get("reason", ""))
	match reason:
		"guest_not_found":
			return "host nebyl nalezen"
		"guest_not_waiting":
			return "host uz neceka na recepci"
		"invalid_accommodation":
			return "neplatne ubytovani"
		"accommodation_unavailable":
			return "ubytovani neni dostupne"
		"not_dirty_or_occupied":
			return "ubytovani neni spinave nebo je obsazene"
		"state_unavailable":
			return "stav hry neni dostupny"
		"":
			return "neuspesna akce"
		_:
			return reason


func _is_accommodation_available(acc_any) -> bool:
	if not (acc_any is Dictionary):
		return false
	var acc: Dictionary = acc_any
	if str(acc.get("status", "clean")) == "dirty":
		return false
	var capacity = max(1, int(acc.get("capacity", 1)))
	return _guest_count(acc) < capacity


func _guest_count(acc_any) -> int:
	if not (acc_any is Dictionary):
		return 0
	var ids_any = (acc_any as Dictionary).get("guest_ids", [])
	if ids_any is Array:
		return (ids_any as Array).size()
	return 0


func _acc_type_label(building_type: String) -> String:
	if building_type.begins_with("tent"):
		var parts = building_type.split("_")
		if parts.size() >= 2:
			return "Stan %s" % parts[1]
		return "Stan"
	if building_type.begins_with("cabin"):
		var parts = building_type.split("_")
		if parts.size() >= 2:
			return "Chatka %s" % parts[1]
		return "Chatka"
	if building_type.begins_with("caravan"):
		return "Karavan"
	return building_type if not building_type.is_empty() else "Ubytovani"
