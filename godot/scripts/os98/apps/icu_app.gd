extends Control

## ICU 98's window (the eye in the tray, scripts/os98/icu_story.gd tells the story): your
## contacts on top, each with its light (green on, red off; one that no longer exists greyed
## and struck through), the conversation with the one picked below, and your two replies
## when she has asked. A contact's line reads as ICU wrote them: who, the time, the line.

const T = preload("res://scripts/os98/os_theme.gd")
const STORY = preload("res://scripts/os98/icu_story.gd")

var _shell
var _win
var _contacts: ItemList
var _log: RichTextLabel
var _status: Label
var _buttons: Array = []
var _who := STORY.NICK
var _shown := -1
var _t := 0.0


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	win.can_maximize = false
	var head := TextureRect.new()
	head.texture = shell.icon("icu")
	head.position = Vector2(8, 6)
	head.size = Vector2(32, 32)
	add_child(head)
	var title := Label.new()
	title.text = "ICU 98"
	title.position = Vector2(46, 6)
	add_child(title)
	var uin := Label.new()
	uin.text = "#1998-0613"
	uin.position = Vector2(46, 22)
	uin.modulate = Color(0.35, 0.35, 0.35)
	add_child(uin)
	_contacts = ItemList.new()
	_contacts.position = Vector2(8, 44)
	_contacts.size = Vector2(size.x - 16, 52)
	_contacts.item_selected.connect(func(i): _who = STORY.NICK if i == 0 else STORY.KAREL; _shown = -1; _refresh())
	add_child(_contacts)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.position = Vector2(8, 102)
	_log.size = Vector2(size.x - 16, size.y - 102 - 62)
	_log.add_theme_stylebox_override("normal", T.box("sunken", Color(1, 1, 1)))
	add_child(_log)
	_status = Label.new()
	_status.position = Vector2(8, size.y - 58)
	_status.modulate = Color(0.35, 0.35, 0.35)
	add_child(_status)
	for i in 2:
		var b := Button.new()
		b.position = Vector2(8 + i * ((size.x - 20) * 0.5 + 4), size.y - 38)
		b.size = Vector2((size.x - 20) * 0.5, 30)
		b.clip_text = true
		b.pressed.connect(_pick.bind(i))
		add_child(b)
		_buttons.append(b)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	_refresh()


func _story():
	return _shell.get("icu") if _shell != null else null


func _refresh() -> void:
	var st = _story()
	if st == null:
		return
	# The list: her light, Karel's, as ICU shows them.
	var her := "%s  %s" % [STORY.NICK, tr("(online)") if st.is_online() else (tr("(not found)") if st.is_gone() else tr("(offline)"))]
	var karel := "%s  %s" % [STORY.KAREL, tr("(offline)")]
	if _contacts.item_count != 2:
		_contacts.clear()
		_contacts.add_item(her)
		_contacts.add_item(karel)
		_contacts.select(0)
	else:
		_contacts.set_item_text(0, her)
	_contacts.set_item_custom_fg_color(0, Color(0.0, 0.5, 0.0) if st.is_online() else (Color(0.55, 0.55, 0.55) if st.is_gone() else Color(0.6, 0.0, 0.0)))
	_contacts.set_item_custom_fg_color(1, Color(0.6, 0.0, 0.0))
	var lines: Array = st.log_lines() if _who == STORY.NICK else st.karel_lines()
	var n := lines.size() + (1000 if _who == STORY.KAREL else 0)
	if n != _shown:
		_shown = n
		var t := ""
		if _who == STORY.KAREL:
			for l in lines:
				t += "[color=#990000][b]%s[/b][/color] [color=#808080]%s[/color]\n%s\n" % [STORY.KAREL, str(l[0]), tr(str(l[1]))]
		else:
			for l in lines:
				var who := str(l[0])
				if who == "*":
					t += "[color=#808080][i]%s[/i][/color]\n" % str(l[1])
				elif who == "you":
					t += "[color=#000099][b]%s[/b][/color] [color=#808080]%s[/color]\n%s\n" % [tr("You"), str(l[2]), str(l[1])]
				else:
					t += "[color=#990000][b]%s[/b][/color] [color=#808080]%s[/color]\n%s\n" % [who, str(l[2]), str(l[1])]
		_log.text = t
		if _who == STORY.NICK:
			st.read_all()
	_status.text = (tr("%s is typing...") % STORY.NICK) if (_who == STORY.NICK and st.typing()) else ""
	var ch: Array = st.choices() if _who == STORY.NICK else []
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.visible = i < ch.size()
		if b.visible:
			b.text = tr(str(ch[i]))


func _pick(i: int) -> void:
	var st = _story()
	if st != null:
		st.choose(i)
		_shell.play("key", -12.0)
		_shown = -1
		_refresh()
