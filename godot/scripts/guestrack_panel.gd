extends Panel

const TAB_OVERVIEW := "overview"
const TAB_STAYS := "stays"
const TAB_COMPLIANCE := "compliance"

const COL_FRAME_BG := Color(0.63, 0.58, 0.48, 1.0)
const COL_FRAME_BORDER := Color(0.29, 0.23, 0.16, 1.0)
const COL_TEXT_DARK := Color(0.11, 0.08, 0.06, 1.0)
const COL_TEXT_LIGHT := Color(0.95, 0.91, 0.80, 1.0)
const COL_TITLE_BG := Color(0.34, 0.20, 0.12, 1.0)
const COL_TITLE_TEXT := Color(0.98, 0.95, 0.86, 1.0)
const COL_BODY_BG := Color(0.71, 0.67, 0.56, 1.0)
const COL_PANEL_BG := Color(0.79, 0.75, 0.66, 1.0)
const COL_PANEL_BORDER := Color(0.34, 0.28, 0.20, 1.0)
const COL_TABLE_HEAD_BG := Color(0.46, 0.41, 0.31, 1.0)
const COL_TABLE_HEAD_TEXT := Color(0.97, 0.94, 0.85, 1.0)
const COL_ROW_ODD := Color(0.82, 0.79, 0.70, 1.0)
const COL_ROW_EVEN := Color(0.76, 0.72, 0.63, 1.0)
const COL_TAB_ACTIVE_BG := Color(0.83, 0.79, 0.69, 1.0)
const COL_TAB_IDLE_BG := Color(0.66, 0.62, 0.53, 1.0)

var _active_tab: String = TAB_OVERVIEW
var _cached_guests: Array = []
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}

var _runtime_label: Label
var _summary_beds_value: Label
var _summary_guests_value: Label
var _summary_reviews_value: Label
var _status_label: Label
var _record_count_label: Label
var _overview_header_row: HBoxContainer
var _overview_rows_box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _panel_style(COL_FRAME_BG, COL_FRAME_BORDER, 2))
	_build_ui()
	_wire_events()
	_set_active_tab(TAB_OVERVIEW)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 8.0
	margin.offset_top = 8.0
	margin.offset_right = -8.0
	margin.offset_bottom = -8.0
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var masthead := Panel.new()
	masthead.custom_minimum_size = Vector2(0.0, 62.0)
	masthead.add_theme_stylebox_override("panel", _panel_style(COL_TITLE_BG, COL_FRAME_BORDER, 2))
	root.add_child(masthead)

	var masthead_margin := MarginContainer.new()
	masthead_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	masthead_margin.offset_left = 10.0
	masthead_margin.offset_top = 8.0
	masthead_margin.offset_right = -10.0
	masthead_margin.offset_bottom = -8.0
	masthead.add_child(masthead_margin)

	var masthead_row := HBoxContainer.new()
	masthead_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead_margin.add_child(masthead_row)

	var masthead_left := VBoxContainer.new()
	masthead_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead_left.add_theme_constant_override("separation", 0)
	masthead_row.add_child(masthead_left)

	var title := Label.new()
	title.text = "GUESTRACK 98"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COL_TITLE_TEXT)
	masthead_left.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Hospitality Occupancy Oversight Console"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", COL_TITLE_TEXT.darkened(0.14))
	masthead_left.add_child(subtitle)

	var masthead_right := VBoxContainer.new()
	masthead_right.alignment = BoxContainer.ALIGNMENT_END
	masthead_right.add_theme_constant_override("separation", 2)
	masthead_row.add_child(masthead_right)

	var runtime_title := Label.new()
	runtime_title.text = "SYSTEM CLOCK"
	runtime_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	runtime_title.add_theme_font_size_override("font_size", 10)
	runtime_title.add_theme_color_override("font_color", COL_TITLE_TEXT.darkened(0.10))
	masthead_right.add_child(runtime_title)

	_runtime_label = Label.new()
	_runtime_label.text = "DAY --  --:--"
	_runtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_runtime_label.add_theme_font_size_override("font_size", 13)
	_runtime_label.add_theme_color_override("font_color", COL_TITLE_TEXT)
	masthead_right.add_child(_runtime_label)

	var tabs_row := HBoxContainer.new()
	tabs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_theme_constant_override("separation", 4)
	root.add_child(tabs_row)

	_tab_buttons[TAB_OVERVIEW] = _make_tab_button("Overview", TAB_OVERVIEW)
	_tab_buttons[TAB_STAYS] = _make_tab_button("Stays", TAB_STAYS)
	_tab_buttons[TAB_COMPLIANCE] = _make_tab_button("Compliance", TAB_COMPLIANCE)
	tabs_row.add_child(_tab_buttons[TAB_OVERVIEW])
	tabs_row.add_child(_tab_buttons[TAB_STAYS])
	tabs_row.add_child(_tab_buttons[TAB_COMPLIANCE])

	var body := Panel.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", _panel_style(COL_BODY_BG, COL_PANEL_BORDER, 2))
	root.add_child(body)

	var body_margin := MarginContainer.new()
	body_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	body_margin.offset_left = 8.0
	body_margin.offset_top = 8.0
	body_margin.offset_right = -8.0
	body_margin.offset_bottom = -8.0
	body.add_child(body_margin)

	var pages_root := Control.new()
	pages_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_child(pages_root)

	_tab_pages[TAB_OVERVIEW] = _build_overview_page()
	_tab_pages[TAB_STAYS] = _build_placeholder_page(
		"STAYS",
		"Segmented stay analytics module reserved for next iteration."
	)
	_tab_pages[TAB_COMPLIANCE] = _build_placeholder_page(
		"COMPLIANCE",
		"Audit and issue tracking tab reserved for next iteration."
	)

	for tab_id in _tab_pages.keys():
		var page = _tab_pages[tab_id] as Control
		if page == null:
			continue
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		pages_root.add_child(page)


func _build_overview_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)

	var summary_row := HBoxContainer.new()
	summary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_theme_constant_override("separation", 6)
	page.add_child(summary_row)

	var beds_card = _make_summary_card("Beds Occupied")
	var guests_card = _make_summary_card("Active Guests")
	var reviews_card = _make_summary_card("Reviews Logged")
	_summary_beds_value = beds_card.get("value") as Label
	_summary_guests_value = guests_card.get("value") as Label
	_summary_reviews_value = reviews_card.get("value") as Label
	summary_row.add_child(beds_card.get("panel") as Control)
	summary_row.add_child(guests_card.get("panel") as Control)
	summary_row.add_child(reviews_card.get("panel") as Control)

	var status_row := HBoxContainer.new()
	status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(status_row)

	_status_label = Label.new()
	_status_label.text = "Overview standby."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_color_override("font_color", COL_TEXT_DARK)
	_status_label.add_theme_font_size_override("font_size", 11)
	status_row.add_child(_status_label)

	_record_count_label = Label.new()
	_record_count_label.text = "0 RECORDS"
	_record_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_record_count_label.add_theme_color_override("font_color", COL_TEXT_DARK.darkened(0.12))
	_record_count_label.add_theme_font_size_override("font_size", 10)
	status_row.add_child(_record_count_label)

	var table_shell := Panel.new()
	table_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_shell.add_theme_stylebox_override("panel", _panel_style(COL_PANEL_BG, COL_PANEL_BORDER, 1))
	page.add_child(table_shell)

	var table_margin := MarginContainer.new()
	table_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	table_margin.offset_left = 4.0
	table_margin.offset_top = 4.0
	table_margin.offset_right = -4.0
	table_margin.offset_bottom = -4.0
	table_shell.add_child(table_margin)

	var table_root := VBoxContainer.new()
	table_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_root.add_theme_constant_override("separation", 2)
	table_margin.add_child(table_root)

	var head_panel := Panel.new()
	head_panel.add_theme_stylebox_override("panel", _panel_style(COL_TABLE_HEAD_BG, COL_PANEL_BORDER, 1))
	head_panel.custom_minimum_size = Vector2(0.0, 28.0)
	table_root.add_child(head_panel)

	_overview_header_row = HBoxContainer.new()
	_overview_header_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overview_header_row.offset_left = 6.0
	_overview_header_row.offset_top = 3.0
	_overview_header_row.offset_right = -6.0
	_overview_header_row.offset_bottom = -3.0
	_overview_header_row.add_theme_constant_override("separation", 6)
	head_panel.add_child(_overview_header_row)

	_add_row_cell(_overview_header_row, "ID", 44.0, false, COL_TABLE_HEAD_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 10)
	_add_row_cell(_overview_header_row, "Guest", 140.0, true, COL_TABLE_HEAD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, 10)
	_add_row_cell(_overview_header_row, "Archetype", 126.0, false, COL_TABLE_HEAD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, 10)
	_add_row_cell(_overview_header_row, "Beds", 48.0, false, COL_TABLE_HEAD_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 10)
	_add_row_cell(_overview_header_row, "Income / Day", 104.0, false, COL_TABLE_HEAD_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 10)
	_add_row_cell(_overview_header_row, "Leaves In", 108.0, false, COL_TABLE_HEAD_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 10)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	table_root.add_child(scroll)

	_overview_rows_box = VBoxContainer.new()
	_overview_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_rows_box.add_theme_constant_override("separation", 2)
	scroll.add_child(_overview_rows_box)

	return page


func _build_placeholder_page(title: String, description: String) -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)

	var p := Panel.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _panel_style(COL_PANEL_BG, COL_PANEL_BORDER, 1))
	page.add_child(p)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 16.0
	margin.offset_top = 16.0
	margin.offset_right = -16.0
	margin.offset_bottom = -16.0
	p.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", COL_TEXT_DARK)
	col.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = description
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 12)
	body_lbl.add_theme_color_override("font_color", COL_TEXT_DARK.darkened(0.18))
	col.add_child(body_lbl)

	return page


func _make_summary_card(label: String) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0.0, 62.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COL_PANEL_BG, COL_PANEL_BORDER, 1))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 8.0
	margin.offset_top = 6.0
	margin.offset_right = -8.0
	margin.offset_bottom = -6.0
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	margin.add_child(col)

	var title := Label.new()
	title.text = label
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", COL_TEXT_DARK.darkened(0.18))
	col.add_child(title)

	var value := Label.new()
	value.text = "--"
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", COL_TEXT_DARK)
	col.add_child(value)

	return {
		"panel": panel,
		"value": value,
	}


func _make_tab_button(label: String, tab_id: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(112.0, 28.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void:
		_set_active_tab(tab_id)
	)
	_apply_tab_button_style(btn, false)
	return btn


func _set_active_tab(tab_id: String) -> void:
	_active_tab = tab_id
	for key_any in _tab_pages.keys():
		var key = str(key_any)
		var page = _tab_pages[key] as Control
		if page != null:
			page.visible = key == _active_tab
	for key_any in _tab_buttons.keys():
		var key = str(key_any)
		var btn = _tab_buttons[key] as Button
		if btn == null:
			continue
		var is_active = key == _active_tab
		btn.set_pressed_no_signal(is_active)
		_apply_tab_button_style(btn, is_active)


func _apply_tab_button_style(btn: Button, active: bool) -> void:
	if btn == null:
		return
	var base = COL_TAB_ACTIVE_BG if active else COL_TAB_IDLE_BG
	var text_col = COL_TEXT_DARK if active else COL_TEXT_DARK.darkened(0.12)
	var normal = _panel_style(base, COL_PANEL_BORDER, 2)
	var hover = _panel_style(base.lightened(0.05), COL_PANEL_BORDER.darkened(0.10), 2)
	var pressed = _panel_style(base.darkened(0.08), COL_PANEL_BORDER.darkened(0.16), 2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)


func _wire_events() -> void:
	if EventBus == null:
		return
	if EventBus.has_signal("time_tick"):
		var tick_cb := Callable(self, "_on_time_tick")
		if not EventBus.time_tick.is_connected(tick_cb):
			EventBus.time_tick.connect(tick_cb)
	if EventBus.has_signal("guest_created"):
		var create_cb := Callable(self, "_on_guest_data_changed")
		if not EventBus.guest_created.is_connected(create_cb):
			EventBus.guest_created.connect(create_cb)
	if EventBus.has_signal("guest_state_changed"):
		var state_cb := Callable(self, "_on_guest_state_changed")
		if not EventBus.guest_state_changed.is_connected(state_cb):
			EventBus.guest_state_changed.connect(state_cb)
	if EventBus.has_signal("guest_review_posted"):
		var review_cb := Callable(self, "_on_guest_data_changed")
		if not EventBus.guest_review_posted.is_connected(review_cb):
			EventBus.guest_review_posted.connect(review_cb)
	if EventBus.has_signal("state_changed"):
		var root_state_cb := Callable(self, "_on_state_changed")
		if not EventBus.state_changed.is_connected(root_state_cb):
			EventBus.state_changed.connect(root_state_cb)


func _on_time_tick(_hour: int, _minute: int) -> void:
	refresh()


func _on_guest_data_changed(_payload: Variant = null) -> void:
	refresh()


func _on_guest_state_changed(_guest_id: int, _old_state: String, _new_state: String) -> void:
	refresh()


func _on_state_changed(changes: Dictionary) -> void:
	if changes.has("guests") or changes.has("time"):
		refresh()


func refresh() -> void:
	var guest_manager = get_node_or_null("/root/GuestManager")
	if guest_manager == null:
		_apply_unavailable_state("GuestRack backend unavailable.")
		return
	if not guest_manager.has_method("get_guestrack_overview_data"):
		_apply_unavailable_state("GuestRack backend is outdated.")
		return

	var payload_any = guest_manager.call("get_guestrack_overview_data")
	var payload: Dictionary = payload_any if payload_any is Dictionary else {}
	if not bool(payload.get("ok", false)):
		_apply_unavailable_state(str(payload.get("error", "GuestRack unavailable.")))
		return

	var day = int(payload.get("day", 1))
	var hour = clampi(int(payload.get("hour", 0)), 0, 23)
	var minute = clampi(int(payload.get("minute", 0)), 0, 59)
	_runtime_label.text = "DAY %d  %02d:%02d" % [day, hour, minute]

	var overview_any = payload.get("overview", {})
	var overview: Dictionary = overview_any if overview_any is Dictionary else {}
	var capacity = int(overview.get("capacity", 0))
	var occupied = int(overview.get("occupied", 0))
	var free = int(overview.get("free", 0))
	_summary_beds_value.text = "%d / %d  (free %d)" % [occupied, capacity, free]
	_summary_guests_value.text = "%d total  |  %d active  |  %d sleep" % [
		int(overview.get("total", 0)),
		int(overview.get("active", 0)),
		int(overview.get("sleep", 0)),
	]
	_summary_reviews_value.text = "%d entries" % int(overview.get("reviews", 0))

	var guests_any = payload.get("guests", [])
	_cached_guests = guests_any if guests_any is Array else []
	_status_label.text = "Overview synced. Guests sorted by nearest checkout."
	_render_overview_rows()


func _apply_unavailable_state(message: String) -> void:
	_runtime_label.text = "DAY --  --:--"
	_summary_beds_value.text = "--"
	_summary_guests_value.text = "--"
	_summary_reviews_value.text = "--"
	_status_label.text = message
	_cached_guests = []
	_render_overview_rows()


func _render_overview_rows() -> void:
	if _overview_rows_box == null:
		return
	for child in _overview_rows_box.get_children():
		child.queue_free()

	var compact_mode = size.x < 760.0
	if _overview_header_row != null:
		_overview_header_row.visible = not compact_mode

	if _cached_guests.is_empty():
		_record_count_label.text = "0 RECORDS"
		var empty := Label.new()
		empty.text = "No active stays."
		empty.custom_minimum_size = Vector2(0.0, 44.0)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", COL_TEXT_DARK.darkened(0.20))
		_overview_rows_box.add_child(empty)
		return

	_record_count_label.text = "%d RECORDS" % _cached_guests.size()
	var idx := 0
	for guest_any in _cached_guests:
		if not (guest_any is Dictionary):
			continue
		var guest: Dictionary = guest_any
		var row = _make_compact_row(guest, idx) if compact_mode else _make_table_row(guest, idx)
		_overview_rows_box.add_child(row)
		idx += 1


func _make_table_row(guest: Dictionary, row_idx: int) -> Control:
	var row_bg = COL_ROW_EVEN if row_idx % 2 == 0 else COL_ROW_ODD
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0.0, 28.0)
	row.add_theme_stylebox_override("panel", _panel_style(row_bg, COL_PANEL_BORDER.darkened(0.08), 1))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 6.0
	margin.offset_top = 3.0
	margin.offset_right = -6.0
	margin.offset_bottom = -3.0
	row.add_child(margin)

	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 6)
	margin.add_child(cells)

	var status = str(guest.get("status", "active")).to_upper()
	var guest_name = str(guest.get("name", "Guest"))
	if status == "SLEEP":
		guest_name = "%s  [SLEEP]" % guest_name

	_add_row_cell(cells, "#%d" % int(guest.get("id", -1)), 44.0, false, COL_TEXT_DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_row_cell(cells, guest_name, 140.0, true, COL_TEXT_DARK, HORIZONTAL_ALIGNMENT_LEFT)
	_add_row_cell(cells, _pretty_archetype(str(guest.get("archetype", ""))), 126.0, false, COL_TEXT_DARK, HORIZONTAL_ALIGNMENT_LEFT)
	_add_row_cell(cells, str(int(guest.get("beds_used", 1))), 48.0, false, COL_TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	_add_row_cell(cells, "$%d" % int(guest.get("daily_income", 0)), 104.0, false, COL_TEXT_DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_row_cell(cells, str(guest.get("remaining_label", "0m")), 108.0, false, COL_TEXT_DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	return row


func _make_compact_row(guest: Dictionary, row_idx: int) -> Control:
	var row_bg = COL_ROW_EVEN if row_idx % 2 == 0 else COL_ROW_ODD
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0.0, 56.0)
	row.add_theme_stylebox_override("panel", _panel_style(row_bg, COL_PANEL_BORDER.darkened(0.08), 1))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 8.0
	margin.offset_top = 6.0
	margin.offset_right = -8.0
	margin.offset_bottom = -6.0
	row.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	margin.add_child(col)

	var top := Label.new()
	var guest_name = str(guest.get("name", "Guest"))
	var status = str(guest.get("status", "active")).to_upper()
	top.text = "#%d  %s%s" % [
		int(guest.get("id", -1)),
		guest_name,
		"  [SLEEP]" if status == "SLEEP" else "",
	]
	top.clip_text = true
	top.add_theme_font_size_override("font_size", 12)
	top.add_theme_color_override("font_color", COL_TEXT_DARK)
	col.add_child(top)

	var bottom := Label.new()
	bottom.text = "%s | beds:%d | income:$%d/day | leaves:%s" % [
		_pretty_archetype(str(guest.get("archetype", ""))),
		int(guest.get("beds_used", 1)),
		int(guest.get("daily_income", 0)),
		str(guest.get("remaining_label", "0m")),
	]
	bottom.clip_text = true
	bottom.add_theme_font_size_override("font_size", 10)
	bottom.add_theme_color_override("font_color", COL_TEXT_DARK.darkened(0.10))
	col.add_child(bottom)
	return row


func _add_row_cell(
	row: HBoxContainer,
	text: String,
	min_width: float,
	expand: bool,
	color: Color,
	align: HorizontalAlignment,
	font_size: int = 11
) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)


func _pretty_archetype(raw: String) -> String:
	var key = raw.strip_edges().to_lower()
	match key:
		"quiet_guy":
			return "Quiet Guest"
		"drunk":
			return "Party Crew"
		"cheap_chick":
			return "Bargain Group"
		_:
			if key.is_empty():
				return "Unknown"
			var words = key.replace("_", " ").split(" ")
			for i in range(words.size()):
				var token = str(words[i])
				if token.is_empty():
					continue
				words[i] = token.substr(0, 1).to_upper() + token.substr(1)
			return " ".join(words)


func _panel_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	return style


func _relayout() -> void:
	if _active_tab == TAB_OVERVIEW:
		_render_overview_rows()
