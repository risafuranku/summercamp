extends Control

## CampMail 2.1: the inbox (newest first, unread in bold), the reader, and for booking
## requests the booking card: who, how many, how long, what they pay, when they would
## arrive, whether there are beds, and what they do to tonight's risk. Accept or refuse.

const T = preload("res://scripts/os98/os_theme.gd")

var _shell
var _win
var _list: Tree
var _header: RichTextLabel
var _body: RichTextLabel
var _card: RichTextLabel
var _accept: Button
var _refuse: Button
var _status: Label
var _current: Dictionary = {}
var _rows: Array = []


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_build()
	refresh()


func reopen(_args: Dictionary) -> void:
	refresh()


func _build() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(2, 2)
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)
	var get_mail := Button.new()
	get_mail.text = "Get Mail"
	get_mail.pressed.connect(func():
		_shell.play("hdd", -10.0)
		refresh()
	)
	bar.add_child(get_mail)
	_status = Label.new()
	_status.custom_minimum_size = Vector2(300, 0)
	bar.add_child(_status)

	_list = Tree.new()
	_list.columns = 4
	_list.column_titles_visible = true
	_list.hide_root = true
	_list.select_mode = Tree.SELECT_ROW
	for c in 4:
		_list.set_column_title(c, ["", "From", "Subject", "Received"][c])
		_list.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		_list.set_column_expand(c, c == 2)
		_list.set_column_custom_minimum_width(c, [14, 150, 200, 92][c])
		_list.set_column_clip_content(c, true)
	_list.item_selected.connect(_on_selected)
	add_child(_list)

	_header = RichTextLabel.new()
	_header.bbcode_enabled = true
	_header.scroll_active = false
	_header.add_theme_stylebox_override("normal", T.box("thin_raised", T.FACE, Vector4(6, 3, 6, 3)))
	add_child(_header)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.selection_enabled = true
	add_child(_body)
	_card = RichTextLabel.new()
	_card.bbcode_enabled = true
	_card.add_theme_stylebox_override("normal", T.box("field", Color8(255, 255, 238), Vector4(6, 4, 6, 4)))
	add_child(_card)
	_accept = Button.new()
	_accept.text = "Accept"
	_accept.pressed.connect(_on_accept)
	add_child(_accept)
	_refuse = Button.new()
	_refuse.text = "Refuse"
	_refuse.pressed.connect(_on_refuse)
	add_child(_refuse)
	resized.connect(_layout)
	_layout()
	_show_message({})


func _layout() -> void:
	if _list == null:
		return
	var w := size.x
	var h := size.y
	var list_h := floorf((h - 28) * 0.36)
	_list.position = Vector2(0, 26)
	_list.size = Vector2(w, list_h)
	var y := 26 + list_h + 3
	_header.position = Vector2(0, y)
	_header.size = Vector2(w, 46)
	y += 48
	var booking := not _current.is_empty() and _is_booking(_current)
	_card.visible = booking
	_accept.visible = booking and not bool(_current.get("_actioned", false))
	_refuse.visible = _accept.visible
	if booking:
		var cw := floorf(w * 0.44)
		_body.position = Vector2(0, y)
		_body.size = Vector2(w - cw - 3, h - y)
		_card.position = Vector2(w - cw, y)
		_card.size = Vector2(cw, h - y - (30 if _accept.visible else 0))
		_accept.position = Vector2(w - cw, h - 26)
		_accept.size = Vector2(cw * 0.5 - 2, 24)
		_refuse.position = Vector2(w - cw * 0.5 + 2, h - 26)
		_refuse.size = Vector2(cw * 0.5 - 2, 24)
	else:
		_body.position = Vector2(0, y)
		_body.size = Vector2(w, h - y)


func refresh() -> void:
	if _list == null or EmailManager == null:
		return
	var selected_id := int(_current.get("_runtime_id", -1))
	_rows = EmailManager.inbox.duplicate()
	_rows.sort_custom(func(a, b): return _sort_key(a) > _sort_key(b))
	_list.clear()
	var root := _list.create_item()
	var reselect: TreeItem = null
	for mail in _rows:
		var it := _list.create_item(root)
		var unread := not bool(mail.get("_read", false))
		it.set_text(0, "*" if _is_booking(mail) and not bool(mail.get("_actioned", false)) else "")
		it.set_text(1, _short_sender(str(mail.get("from", "?"))))
		it.set_text(2, str(mail.get("subject", "(no subject)")))
		it.set_text(3, _date_label(mail))
		if unread:
			for c in 4:
				it.set_custom_font(c, T.FONT_BOLD)
		it.set_metadata(0, int(mail.get("_runtime_id", -1)))
		if int(mail.get("_runtime_id", -2)) == selected_id:
			reselect = it
	var unread_n := EmailManager.get_unread_count()
	_status.text = "Inbox: %d message(s), %d unread" % [_rows.size(), unread_n]
	_win.title = "CampMail - Inbox" + (" (%d)" % unread_n if unread_n > 0 else "")
	if reselect != null:
		reselect.select(0)


func _on_selected() -> void:
	var it := _list.get_selected()
	if it == null:
		return
	var id := int(it.get_metadata(0))
	for mail in _rows:
		if int(mail.get("_runtime_id", -1)) == id:
			EmailManager.mark_read(mail)
			_show_message(mail)
			for c in 4:
				it.set_custom_font(c, T.FONT)
			_status.text = "Inbox: %d message(s), %d unread" % [_rows.size(), EmailManager.get_unread_count()]
			return


func _show_message(mail: Dictionary) -> void:
	_current = mail
	if mail.is_empty():
		_header.text = ""
		_body.text = "[color=#808080]Select a message to read it.[/color]"
		_layout()
		return
	_header.text = "[b]From:[/b] %s\n[b]Subject:[/b] %s\n[b]Date:[/b] %s" % [
		_esc(str(mail.get("from", "?"))), _esc(str(mail.get("subject", ""))), _date_label(mail)]
	_body.text = _esc(str(mail.get("body", "")).strip_edges())
	_body.scroll_to_line(0)
	if _is_booking(mail):
		_card.text = _booking_card(mail)
		var can := EmailManager.can_accept_customer_booking(mail)
		_accept.disabled = not can
		_accept.text = "Accept" if can else "No free beds"
	_layout()


func _on_accept() -> void:
	if _current.is_empty():
		return
	var name := str(EmailManager.get_customer_panel_data(_current).get("guest_name", ""))
	if not EmailManager.confirm_customer_booking(_current):
		_shell.message_box("CampMail", "The booking could not be accepted.\nThere are not enough free beds.", "error")
		return
	_shell.play("click")
	refresh()
	# No popup (playtest): the arrival shows in the HUD and in GuestRack. A line here.
	for row in GuestManager.get_arrivals():
		if str(row.get("name", "")) == name:
			var mins := int(row.get("minutes", 60))
			_status.text = "Accepted. %s arrives in about %d:%02d - make up the room." % [name, mins / 60, mins % 60]
	_show_message(_current)


func _on_refuse() -> void:
	if _current.is_empty():
		return
	EmailManager.reject_customer_booking(_current)
	_current = {}
	refresh()
	_show_message({})


func _booking_card(mail: Dictionary) -> String:
	var p: Dictionary = EmailManager.get_customer_panel_data(mail)
	var party: int = maxi(1, int(p.get("party_size", mail.get("guests", 1))))
	var nights: int = maxi(1, int(p.get("stay_nights", mail.get("nights", 1))))
	var pay: int = maxi(0, int(p.get("daily_total", mail.get("daily_total", 0))))
	var beds: Dictionary = GuestManager.get_bed_metrics()
	var t := "[b]BOOKING REQUEST[/b]\n"
	t += "%s, party of %d\n" % [_esc(str(p.get("guest_name", "Guest"))), party]
	t += "%s\n" % _esc(str(p.get("archetype_label", p.get("archetype", ""))))
	t += "%d night(s), $%d a day ([b]$%d[/b])\n" % [nights, pay, pay * nights]
	t += "Arrives about 1-2 hours after you accept.\n"
	t += "Free beds: %d of %d (needs %d)\n" % [int(beds.get("free", 0)), int(beds.get("capacity", 0)), party]
	if bool(mail.get("_actioned", false)):
		t += "\n[b]Already answered.[/b]\n"
	t += "\n" + _risk_lines(str(p.get("archetype", mail.get("archetype", ""))), party)
	return t


## The risk half of the trade: without it the player sees only the money.
func _risk_lines(archetype: String, party: int) -> String:
	if archetype.is_empty():
		return ""
	var impact: Dictionary = GuestManager.get_liminal_booking_impact(archetype, party)
	var label := str(impact.get("label", archetype))
	var t := "[b]NIGHT RISK[/b]\n%s in camp: %d -> %d (safe up to %d)\n" % [label, int(impact.get("current_count", 0)), int(impact.get("after_count", 0)), int(impact.get("safe_count", 3))]
	var after: Dictionary = impact.get("after", {}) if impact.get("after", {}) is Dictionary else {}
	if int(after.get("guaranteed_spawns", 0)) > 0:
		return t + "[color=#a00000][b]Something comes tonight. Certainly.[/b][/color]"
	var tier := str(after.get("chance_tier", "none"))
	if tier == "none" or tier.is_empty():
		return t + "[color=#006000]Still a quiet night.[/color]"
	var pct := int(round(float(after.get("chance_probability", 0.0)) * 100.0))
	return t + "[color=#a00000]%s chance of trouble tonight (~%d%%).[/color]" % [tier.capitalize(), pct]


func _is_booking(mail: Dictionary) -> bool:
	var ty := str(mail.get("type", "")).to_lower()
	return ty == "customer" or ty == "guest"


func _sort_key(mail: Dictionary) -> int:
	var day := int(mail.get("day", 0)) + int(mail.get("stamp_day_offset", 0))
	var parts := str(mail.get("time", "00:00")).split(":")
	var minutes := int(parts[0]) * 60 + (int(parts[1]) if parts.size() > 1 else 0)
	return day * 1440 + minutes


func _date_label(mail: Dictionary) -> String:
	return "Day %d  %s" % [int(mail.get("day", 0)) + int(mail.get("stamp_day_offset", 0)), str(mail.get("time", "??:??"))]


func _short_sender(s: String) -> String:
	var i := s.find("<")
	return s.substr(0, i).strip_edges() if i > 0 else s


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")
