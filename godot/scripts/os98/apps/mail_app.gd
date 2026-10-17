extends Control

## CampMail 3.0, in the manner of Outlook Express 4: the folders on the left (Inbox,
## Sent Items, Deleted Items, with what is unread), the cool toolbar (New Mail, Reply,
## Forward, Delete, Get Mail, Print), the message list (an envelope shut or open, the
## paperclip, From, Subject, Received; click a column head to sort by it), and the
## preview: the full header (From with the address, To, the date from the calendar,
## the attachment), the text, and for spam the picture it carries. Booking requests
## have the booking card: who, how many, how long, what they pay, whether there are
## beds, what they do to tonight's risk; Accept or Refuse.
##
## Keys: Up/Down in the list, Delete deletes, Ctrl+R replies, Ctrl+N is a new message,
## F5 gets mail. New / Reply / Forward open the composer over the reader; what you send
## goes to Sent Items.

const T = preload("res://scripts/os98/os_theme.gd")
const ICONS = preload("res://scripts/os98/apps/browser_icons.gd")
const IMG_DIR := "res://assets/textury/mail/"
const MY_ADDRESS := "kemp.cj@bohemia-online.cz"
const FOLDERS := [["inbox", "Inbox"], ["sent", "Sent Items"], ["deleted", "Deleted Items"]]
const TOOL_H := 42
const FOLDER_W := 132

var _shell
var _win
var _folder := "inbox"
var _folders: Tree
var _list: Tree
var _header: Control
var _body: RichTextLabel
var _card: RichTextLabel
## Guest book entries: the three ways to answer (EmailManager.REVIEW_REPLIES).
var _reply_btns: Array = []
var _accept: Button
var _refuse: Button
var _status: Label
var _tools: Array = []
var _current: Dictionary = {}
var _rows: Array = []
var _sort_col := 3
var _sort_desc := true
var _compose: Control
var _c_to: LineEdit
var _c_subject: LineEdit
var _c_body: TextEdit
var _icon_cache: Dictionary = {}


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_build()
	refresh()


func reopen(_args: Dictionary) -> void:
	refresh()


# ── building ─────────────────────────────────────────────────────────────────

func _build() -> void:
	var chrome := Control.new()
	chrome.name = "Chrome"
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.draw.connect(func():
		chrome.draw_rect(Rect2(0, TOOL_H, size.x, 1), T.SHADOW)
		chrome.draw_rect(Rect2(0, TOOL_H + 1, size.x, 1), T.WHITE)
	)
	add_child(chrome)
	var defs := [
		["newmail", "New Mail", func(): _open_compose("", "", "")],
		["reply", "Reply", _reply],
		["forwardmail", "Forward", _forward],
		["delete", "Delete", _delete_current],
		["|"],
		["getmail", "Get Mail", _get_mail],
		["print", "Print", func(): _shell.message_box("Print", "There is no printer installed.\n\nTo install a printer, open the Printers folder in My Computer.", "warning")],
	]
	var x := 4.0
	for d in defs:
		if d[0] == "|":
			x += 8.0
			continue
		var b := _cool(str(d[0]), str(d[1]), d[2], Vector2(x, 1), Vector2(52, TOOL_H - 2))
		add_child(b)
		_tools.append(b)
		x += 52.0

	_folders = Tree.new()
	_folders.hide_root = true
	_folders.select_mode = Tree.SELECT_ROW
	_folders.item_selected.connect(func():
		var it := _folders.get_selected()
		if it != null and str(it.get_metadata(0)) != _folder:
			_folder = str(it.get_metadata(0))
			_current = {}
			refresh()
			_show_message({})
	)
	add_child(_folders)

	_list = Tree.new()
	_list.columns = 4
	_list.column_titles_visible = true
	_list.hide_root = true
	_list.select_mode = Tree.SELECT_ROW
	for c in 4:
		_list.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		_list.set_column_expand(c, c == 2)
		_list.set_column_custom_minimum_width(c, [36, 140, 180, 106][c])
		_list.set_column_clip_content(c, true)
	_list.item_selected.connect(_on_selected)
	_list.column_title_clicked.connect(func(col: int, _button: int):
		if col == 0:
			return
		if _sort_col == col:
			_sort_desc = not _sort_desc
		else:
			_sort_col = col
			_sort_desc = col == 3
		_shell.play("click", -14.0)
		refresh()
	)
	_list.gui_input.connect(_on_list_key)
	add_child(_list)

	_header = Control.new()
	_header.draw.connect(_draw_header)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	# Links in a mail (Vera's to the programs): a click downloads the file.
	_body.meta_clicked.connect(_on_link)
	_body.selection_enabled = false
	_body.add_theme_stylebox_override("normal", T.box("field", T.WHITE, Vector4(8, 6, 8, 6)))
	add_child(_body)
	_card = RichTextLabel.new()
	_card.bbcode_enabled = true
	_card.selection_enabled = false
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
	for opt in EmailManager.REVIEW_REPLIES:
		var rb := Button.new()
		rb.text = str(opt["label"])
		rb.visible = false
		var rid := str(opt["id"])
		rb.pressed.connect(func(): _answer_review(rid))
		add_child(rb)
		_reply_btns.append(rb)

	var bar := Panel.new()
	bar.name = "StatusBar"
	bar.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4.ZERO))
	add_child(bar)
	_status = Label.new()
	_status.position = Vector2(4, 1)
	_status.clip_text = true
	bar.add_child(_status)

	_build_compose()
	resized.connect(_layout)
	_layout()
	_show_message({})


func _layout() -> void:
	if _list == null:
		return
	var w := size.x
	var h := size.y - 18
	var top := float(TOOL_H + 3)
	_folders.position = Vector2(0, top)
	_folders.size = Vector2(FOLDER_W - 3, h - top)
	var x0 := float(FOLDER_W)
	var rw := w - x0
	var list_h := floorf((h - top) * 0.38)
	_list.position = Vector2(x0, top)
	_list.size = Vector2(rw, list_h)
	var y := top + list_h + 3
	var hh := _header_height()
	_header.position = Vector2(x0, y)
	_header.size = Vector2(rw, hh)
	y += hh + 2
	var booking := not _current.is_empty() and _is_booking(_current)
	var review := not _current.is_empty() and _is_review(_current)
	_card.visible = booking or review
	_accept.visible = booking and not bool(_current.get("_actioned", false)) and _folder == "inbox"
	_refuse.visible = _accept.visible
	var answering := review and not bool(_current.get("_actioned", false)) and _folder == "inbox"
	for i in _reply_btns.size():
		(_reply_btns[i] as Button).visible = answering
	if review:
		var cw2 := floorf(rw * 0.44)
		_body.position = Vector2(x0, y)
		_body.size = Vector2(rw - cw2 - 3, h - y)
		_card.position = Vector2(x0 + rw - cw2, y)
		_card.size = Vector2(cw2, h - y - (84 if answering else 0))
		for i in _reply_btns.size():
			var b: Button = _reply_btns[i]
			b.position = Vector2(x0 + rw - cw2, h - 82 + i * 27)
			b.size = Vector2(cw2, 24)
	elif booking:
		var cw := floorf(rw * 0.44)
		_body.position = Vector2(x0, y)
		_body.size = Vector2(rw - cw - 3, h - y)
		_card.position = Vector2(x0 + rw - cw, y)
		_card.size = Vector2(cw, h - y - (30 if _accept.visible else 0))
		_accept.position = Vector2(x0 + rw - cw, h - 26)
		_accept.size = Vector2(cw * 0.5 - 2, 24)
		_refuse.position = Vector2(x0 + rw - cw * 0.5 + 2, h - 26)
		_refuse.size = Vector2(cw * 0.5 - 2, 24)
	else:
		_body.position = Vector2(x0, y)
		_body.size = Vector2(rw, h - y)
	var bar: Panel = get_node("StatusBar")
	bar.position = Vector2(0, size.y - 17)
	bar.size = Vector2(size.x, 17)
	_status.size = Vector2(size.x - 8, 14)
	if _compose != null:
		_compose.position = Vector2(x0 + 10, top + 10)
		_compose.size = Vector2(rw - 20, h - top - 20)
		_layout_compose()


# ── the toolbar ──────────────────────────────────────────────────────────────

func _cool(id: String, text: String, cb: Callable, pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("id", id)
	c.set_meta("hover", false)
	c.set_meta("down", false)
	c.set_meta("disabled", false)
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		c.queue_redraw()
	)
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		c.set_meta("down", false)
		c.queue_redraw()
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not bool(c.get_meta("disabled")):
			if e.pressed:
				c.set_meta("down", true)
			elif bool(c.get_meta("down")):
				c.set_meta("down", false)
				_shell.play("click", -14.0)
				cb.call()
			c.queue_redraw()
	)
	c.draw.connect(func():
		var hov := bool(c.get_meta("hover"))
		var down := bool(c.get_meta("down"))
		var dis := bool(c.get_meta("disabled"))
		if not dis and down:
			c.draw_style_box(T.box("well", T.FACE), Rect2(Vector2.ZERO, sz))
		elif not dis and hov:
			c.draw_style_box(T.box("thin_raised", T.FACE), Rect2(Vector2.ZERO, sz))
		var o := Vector2(1, 1) if down else Vector2.ZERO
		var ip := Vector2(floorf((sz.x - ICONS.S) * 0.5), 3) + o
		var tw := T.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var tp := Vector2(floorf((sz.x - tw) * 0.5), sz.y - 5) + o
		if dis:
			c.draw_texture(ICONS.get_icon(id, false), ip + Vector2(1, 1), Color(1, 1, 1, 0.9))
			c.draw_texture(ICONS.get_icon(id, false), ip, Color(0.55, 0.55, 0.55, 0.6))
			c.draw_string(T.FONT, tp + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
			c.draw_string(T.FONT, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.SHADOW)
		else:
			c.draw_texture(ICONS.get_icon(id, hov), ip)
			c.draw_string(T.FONT, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	)
	return c


func _set_tool_enabled(id: String, on: bool) -> void:
	for b in _tools:
		if str(b.get_meta("id")) == id and bool(b.get_meta("disabled")) == on:
			b.set_meta("disabled", not on)
			b.queue_redraw()


# ── the lists ────────────────────────────────────────────────────────────────

func refresh() -> void:
	if _list == null or EmailManager == null:
		return
	_refresh_folders()
	var selected_id := int(_current.get("_runtime_id", -1))
	_rows = _folder_rows(_folder)
	_rows.sort_custom(func(a, b):
		var ka = _sort_value(a, _sort_col)
		var kb = _sort_value(b, _sort_col)
		return ka > kb if _sort_desc else ka < kb
	)
	for c in 4:
		var title: String = ["", "From" if _folder != "sent" else "To", "Subject", "Received" if _folder != "sent" else "Sent"][c]
		if c == _sort_col and c > 0:
			title += "  v" if _sort_desc else "  ^"
		_list.set_column_title(c, title)
	_list.clear()
	var root := _list.create_item()
	var reselect: TreeItem = null
	for mail in _rows:
		var it := _list.create_item(root)
		var unread := not bool(mail.get("_read", true if _folder == "sent" else false))
		it.set_icon(0, _row_icon(mail, unread))
		if str(mail.get("attachment", "")) != "" or str(mail.get("image", "")) != "":
			it.set_text(0, "  @")
		it.set_text(1, _short_sender(str(mail.get("from", mail.get("to", "?")))))
		it.set_text(2, str(mail.get("subject", "(no subject)")))
		it.set_text(3, _date_label(mail))
		if unread:
			for c in 4:
				it.set_custom_font(c, T.FONT_BOLD)
		it.set_metadata(0, int(mail.get("_runtime_id", -1)) if _folder != "sent" else _rows.find(mail))
		if int(mail.get("_runtime_id", -2)) == selected_id and _folder != "sent":
			reselect = it
	_update_status()
	if reselect != null:
		reselect.select(0)
	_set_tool_enabled("reply", not _current.is_empty() and _folder != "sent")
	_set_tool_enabled("forwardmail", not _current.is_empty())
	_set_tool_enabled("delete", not _current.is_empty() and _folder != "sent")


func _refresh_folders() -> void:
	_folders.clear()
	var root := _folders.create_item()
	for f in FOLDERS:
		var it := _folders.create_item(root)
		var n := 0
		for m in _folder_rows(str(f[0])):
			if str(f[0]) != "sent" and not bool(m.get("_read", false)):
				n += 1
		it.set_text(0, str(f[1]) + ("  (%d)" % n if n > 0 else ""))
		if n > 0:
			it.set_custom_font(0, T.FONT_BOLD)
		it.set_icon(0, _shell.icon("folder" if str(f[0]) != "deleted" else "bin", true))
		it.set_metadata(0, str(f[0]))
		if str(f[0]) == _folder:
			it.select(0)


func _folder_rows(folder: String) -> Array:
	if folder == "sent":
		return EmailManager.sent.duplicate()
	var out: Array = []
	for m in EmailManager.inbox:
		var f := str(m.get("_folder", "inbox"))
		if f == folder:
			out.append(m)
	return out


func _sort_value(mail: Dictionary, col: int):
	match col:
		1:
			return _short_sender(str(mail.get("from", mail.get("to", "")))).to_lower()
		2:
			return str(mail.get("subject", "")).to_lower().trim_prefix("re: ").trim_prefix("fw: ")
	return _sort_key(mail)


func _update_status() -> void:
	var unread_n := EmailManager.get_unread_count()
	var label: String = {"inbox": "Inbox", "sent": "Sent Items", "deleted": "Deleted Items"}.get(_folder, "Inbox")
	_status.text = "%s: %d message(s), %d unread        Working Online" % [label, _rows.size(), unread_n if _folder == "inbox" else 0]
	_win.title = "%s - CampMail" % label + (" (%d)" % unread_n if unread_n > 0 and _folder == "inbox" else "")


func _on_selected() -> void:
	var it := _list.get_selected()
	if it == null:
		return
	if _folder == "sent":
		var i := int(it.get_metadata(0))
		if i >= 0 and i < _rows.size():
			_show_message(_rows[i])
		return
	var id := int(it.get_metadata(0))
	for mail in _rows:
		if int(mail.get("_runtime_id", -1)) == id:
			EmailManager.mark_read(mail)
			_show_message(mail)
			for c in 4:
				it.set_custom_font(c, T.FONT)
			it.set_icon(0, _row_icon(mail, false))
			_refresh_folders()
			_update_status()
			return


func _on_list_key(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := e as InputEventKey
	if k.keycode == KEY_DELETE:
		_delete_current()
		_list.accept_event()
	elif k.keycode == KEY_R and k.ctrl_pressed:
		_reply()
		_list.accept_event()
	elif k.keycode == KEY_N and k.ctrl_pressed:
		_open_compose("", "", "")
		_list.accept_event()
	elif k.keycode == KEY_F5:
		_get_mail()
		_list.accept_event()


# ── the preview ──────────────────────────────────────────────────────────────

func _header_height() -> float:
	if _current.is_empty():
		return 0.0
	return 74.0 if _attachment_name(_current) != "" else 54.0


func _draw_header() -> void:
	if _current.is_empty():
		return
	var c := _header
	c.draw_style_box(T.box("thin_raised", T.FACE), Rect2(Vector2.ZERO, c.size))
	var sent := _current.has("to") and not _current.has("from")
	var rows := [
		["From:", MY_ADDRESS if sent else str(_current.get("from", "?"))],
		["To:", str(_current.get("to", "")) if sent else MY_ADDRESS],
		["Date:", _long_date(_current)],
		["Subject:", str(_current.get("subject", ""))],
	]
	var y := 12.0
	for r in rows:
		c.draw_string(T.FONT_BOLD, Vector2(6, y), str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
		c.draw_string(T.FONT, Vector2(60, y), str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 66, T.FONT_SIZE, T.TEXT)
		y += 12.0
	var att := _attachment_name(_current)
	if att != "":
		c.draw_rect(Rect2(4, y - 8, c.size.x - 8, 1), T.SHADOW)
		var icon: Texture2D = _shell.icon("image" if att.ends_with(".GIF") else "txt", true)
		if icon != null:
			c.draw_texture_rect(icon, Rect2(60, y - 5, 16, 16), false)
		c.draw_string(T.FONT_BOLD, Vector2(6, y + 7), "Attach:", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
		c.draw_string(T.FONT, Vector2(80, y + 7), "%s (%d KB)" % [att, 4 + absi(att.hash()) % 18], HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(0, 0, 160))


func _show_message(mail: Dictionary) -> void:
	_current = mail
	_header.queue_redraw()
	if mail.is_empty():
		_body.text = "[color=#808080]There are no messages selected.[/color]" if _rows.size() > 0 else "[color=#808080]There are no items in this view.[/color]"
		_layout()
		refresh_tools()
		return
	_body.clear()
	var text := _esc(str(mail.get("body", "")).strip_edges())
	# Quoted lines in the colour CampMail gave them.
	var lines := text.split("\n")
	var out := ""
	for l in lines:
		out += ("[color=#000080]%s[/color]" % l if l.begins_with(">") else l) + "\n"
	for link in mail.get("links", []):
		if link is Dictionary:
			var lt := _esc(str(link.get("text", "")))
			out = out.replace(lt, "[url=dl:%s|%s][color=#0000c0][u]%s[/u][/color][/url]" % [str(link.get("file", "")), str(link.get("text", "")), lt])
	_body.append_text(out)
	var img := str(mail.get("image", ""))
	if img != "" and ResourceLoader.exists(IMG_DIR + img + ".png"):
		var tex: Texture2D = load(IMG_DIR + img + ".png")
		_body.append_text("\n")
		_body.add_image(tex, mini(tex.get_width(), 280), 0)
		_body.append_text("\n")
	_body.scroll_to_line(0)
	if _is_review(mail):
		_card.text = _review_card(mail)
	if _is_booking(mail):
		_card.text = _booking_card(mail)
		var can := EmailManager.can_accept_customer_booking(mail)
		_accept.disabled = not can
		_accept.text = "Accept" if can else "No free beds"
	_layout()
	refresh_tools()


func refresh_tools() -> void:
	_set_tool_enabled("reply", not _current.is_empty() and _folder != "sent")
	_set_tool_enabled("forwardmail", not _current.is_empty())
	_set_tool_enabled("delete", not _current.is_empty() and _folder != "sent")


func _on_link(meta) -> void:
	var m := str(meta)
	if not m.begins_with("dl:"):
		return
	var parts := m.substr(3).split("|")
	if parts.size() >= 1 and _shell != null and _shell.has_method("start_download"):
		_shell.play("click", -10.0)
		_shell.start_download(parts[0], parts[1] if parts.size() > 1 else parts[0])


func _attachment_name(mail: Dictionary) -> String:
	return str(mail.get("attachment", ""))


# ── actions ──────────────────────────────────────────────────────────────────

func _get_mail() -> void:
	_shell.play("hdd", -10.0)
	_status.text = "Checking for new messages on mail.bohemia-online.cz..."
	get_tree().create_timer(0.7).timeout.connect(func():
		if is_instance_valid(self):
			refresh()
	)


func _delete_current() -> void:
	if _current.is_empty() or _folder == "sent":
		return
	EmailManager.delete_mail(_current)
	_shell.play("click", -12.0)
	_current = {}
	refresh()
	_show_message({})


func _reply() -> void:
	if _current.is_empty() or _folder == "sent":
		return
	var to := str(_current.get("from", ""))
	var subj := str(_current.get("subject", ""))
	if not subj.to_lower().begins_with("re:"):
		subj = "Re: " + subj
	_open_compose(to, subj, _quote(_current))


func _forward() -> void:
	if _current.is_empty():
		return
	var subj := str(_current.get("subject", ""))
	_open_compose("", "Fw: " + subj, "\n\n----- Original Message -----\nFrom: %s\nSent: %s\nSubject: %s\n\n%s" % [str(_current.get("from", MY_ADDRESS)), _long_date(_current), subj, str(_current.get("body", ""))])


func _quote(mail: Dictionary) -> String:
	var q := "\n\n%s wrote:\n" % _short_sender(str(mail.get("from", "")))
	for l in str(mail.get("body", "")).strip_edges().split("\n"):
		q += "> " + l + "\n"
	return q


func _review_card(mail: Dictionary) -> String:
	var r: Dictionary = mail.get("review", {})
	var stars := int(r.get("rating", 3))
	var s := "[b]Guest book[/b]\n%s\n%s\n\n" % [str(r.get("name", "")), "[color=#c08000]" + "*".repeat(stars) + "[/color][color=#a0a0a0]" + "*".repeat(5 - stars) + "[/color]"]
	if bool(mail.get("_actioned", false)):
		for opt in EmailManager.REVIEW_REPLIES:
			if str(opt["id"]) == str(mail.get("reply", "")):
				s += "[color=#606060]You answered:[/color]\n[i]%s[/i]" % str(opt["text"])
	else:
		s += "[color=#606060]People read the answers before they book.[/color]"
	return s


func _answer_review(reply_id: String) -> void:
	if _current.is_empty():
		return
	var change := EmailManager.reply_to_review(_current, reply_id)
	_shell.play("click")
	_status.text = "Reply posted to the guest book." + (" It goes down well." if change > 0.015 else (" It will not win anyone over." if change < 0.0 else ""))
	refresh()
	_show_message(_current)


func _on_accept() -> void:
	if _current.is_empty():
		return
	var guest_name := str(EmailManager.get_customer_panel_data(_current).get("guest_name", ""))
	if not EmailManager.confirm_customer_booking(_current):
		_shell.message_box("CampMail", "The booking could not be accepted.\nThere are not enough free beds.", "error")
		return
	_shell.play("click")
	refresh()
	for row in GuestManager.get_arrivals():
		if str(row.get("name", "")) == guest_name:
			var mins := int(row.get("minutes", 60))
			_status.text = "Accepted. %s arrives in about %d:%02d - make up the room." % [guest_name, mins / 60, mins % 60]
	_show_message(_current)


func _on_refuse() -> void:
	if _current.is_empty():
		return
	EmailManager.reject_customer_booking(_current)
	_current = {}
	refresh()
	_show_message({})


# ── the composer ─────────────────────────────────────────────────────────────

func _build_compose() -> void:
	_compose = Panel.new()
	_compose.add_theme_stylebox_override("panel", T.box("window", T.FACE, Vector4.ZERO))
	_compose.visible = false
	add_child(_compose)
	var title := Panel.new()
	title.name = "Title"
	title.add_theme_stylebox_override("panel", T.flat(T.NAVY))
	_compose.add_child(title)
	var tl := Label.new()
	tl.name = "TitleText"
	tl.add_theme_font_override("font", T.FONT_BOLD)
	tl.add_theme_color_override("font_color", T.WHITE)
	tl.position = Vector2(4, 2)
	title.add_child(tl)
	for f in [["To:", "ToLabel"], ["Subject:", "SubjectLabel"]]:
		var l := Label.new()
		l.name = str(f[1])
		l.text = str(f[0])
		_compose.add_child(l)
	_c_to = LineEdit.new()
	_compose.add_child(_c_to)
	_c_subject = LineEdit.new()
	_compose.add_child(_c_subject)
	_c_body = TextEdit.new()
	_c_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_compose.add_child(_c_body)
	var send := Button.new()
	send.name = "Send"
	send.text = "Send"
	send.pressed.connect(_send)
	_compose.add_child(send)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): _compose.visible = false)
	_compose.add_child(cancel)


func _layout_compose() -> void:
	var s := _compose.size
	var title: Panel = _compose.get_node("Title")
	title.position = Vector2(3, 3)
	title.size = Vector2(s.x - 6, 18)
	(_compose.get_node("ToLabel") as Label).position = Vector2(10, 30)
	(_compose.get_node("SubjectLabel") as Label).position = Vector2(10, 56)
	_c_to.position = Vector2(64, 26)
	_c_to.size = Vector2(s.x - 74, 22)
	_c_subject.position = Vector2(64, 52)
	_c_subject.size = Vector2(s.x - 74, 22)
	_c_body.position = Vector2(10, 80)
	_c_body.size = Vector2(s.x - 20, s.y - 116)
	var send: Button = _compose.get_node("Send")
	send.position = Vector2(s.x - 178, s.y - 30)
	send.size = Vector2(80, 23)
	var cancel: Button = _compose.get_node("Cancel")
	cancel.position = Vector2(s.x - 92, s.y - 30)
	cancel.size = Vector2(80, 23)


func _open_compose(to: String, subject: String, body: String) -> void:
	(_compose.get_node("Title/TitleText") as Label).text = (subject if subject != "" else "New Message")
	_c_to.text = to
	_c_subject.text = subject
	_c_body.text = body
	_compose.visible = true
	_compose.move_to_front()
	_layout()
	if to == "":
		_c_to.grab_focus()
	else:
		_c_body.grab_focus()
		_c_body.set_caret_line(0)
		_c_body.set_caret_column(0)


func _send() -> void:
	if _c_to.text.strip_edges() == "":
		_shell.message_box("CampMail", "There must be at least one name in the To box.", "warning")
		return
	var m: Node = _shell.main_node()
	var day: int = CoreRoot.get_day() if CoreRoot != null else 1
	var time := str(m.call("_time_of_day_string")) if m != null and m.has_method("_time_of_day_string") else "--:--"
	EmailManager.send_mail(_c_to.text.strip_edges(), _c_subject.text.strip_edges(), _c_body.text, day, time)
	_compose.visible = false
	_shell.play("modem", -14.0)
	_status.text = "Message sent."
	_refresh_folders()


# ── bits ─────────────────────────────────────────────────────────────────────

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


## A 16 px envelope (shut, unread; open, read), a booking card, a reply.
func _row_icon(mail: Dictionary, unread: bool) -> Texture2D:
	var kind := "booking" if _is_booking(mail) and not bool(mail.get("_actioned", false)) else ("shut" if unread else "open")
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var out := Color8(20, 20, 20)
	match kind:
		"booking":
			_box16(img, Rect2i(2, 2, 12, 12), Color8(255, 255, 230), out)
			_box16(img, Rect2i(2, 2, 12, 3), Color8(200, 30, 30), out)
			for p in [Vector2i(5, 8), Vector2i(8, 8), Vector2i(11, 8), Vector2i(5, 11), Vector2i(8, 11)]:
				img.set_pixel(p.x, p.y, out)
		"shut":
			_box16(img, Rect2i(1, 4, 14, 9), Color8(250, 230, 120), out)
			for k in 7:
				img.set_pixel(1 + k, 4 + k * 4 / 7, out)
				img.set_pixel(14 - k, 4 + k * 4 / 7, out)
		_:
			_box16(img, Rect2i(1, 6, 14, 8), Color8(240, 240, 240), out)
			for k in 7:
				img.set_pixel(1 + k, 6 - k * 4 / 7, out)
				img.set_pixel(14 - k, 6 - k * 4 / 7, out)
			_box16(img, Rect2i(4, 2, 8, 6), Color8(255, 255, 255), out)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[kind] = tex
	return tex


static func _box16(img: Image, r: Rect2i, fill: Color, out: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var edge := x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			img.set_pixel(x, y, out if edge else fill)


func _is_review(mail: Dictionary) -> bool:
	return str(mail.get("type", "")).to_lower() == "review"


func _is_booking(mail: Dictionary) -> bool:
	var ty := str(mail.get("type", "")).to_lower()
	return ty == "customer" or ty == "guest"


func _sort_key(mail: Dictionary) -> int:
	var day := int(mail.get("day", 0)) + int(mail.get("stamp_day_offset", 0))
	var parts := str(mail.get("time", "00:00")).split(":")
	var minutes := int(parts[0]) * 60 + (int(parts[1]) if parts.size() > 1 else 0)
	return day * 1440 + minutes


## "Sun 20.9.  03:00": the date from the calendar (core/systems/season.gd).
func _date_label(mail: Dictionary) -> String:
	var d := int(mail.get("day", 0)) + int(mail.get("stamp_day_offset", 0))
	return "%s %s  %s" % [Season.weekday_short(d), Season.date_short(d), str(mail.get("time", "??:??"))]


func _long_date(mail: Dictionary) -> String:
	var d := int(mail.get("day", 0)) + int(mail.get("stamp_day_offset", 0))
	return "%s 1998 %s" % [Season.date_long(d), str(mail.get("time", "??:??"))]


func _short_sender(s: String) -> String:
	var i := s.find("<")
	return s.substr(0, i).strip_edges() if i > 0 else s


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")
