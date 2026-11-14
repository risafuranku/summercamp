extends Control

## The camp's guest book form (cerne-jezero.cz/guestbook, the browser's "guestbook://sign"):
## your name and a line, Send. The entry is kept in the PC's store ("guestbook_mine": every
## warden's PC the same in co-op) and stays on the page; what comes after it answers you by
## name (browser_app._guestbook).

var _shell
var _win
var _name: LineEdit
var _text: LineEdit


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	win.can_maximize = false
	var l1 := Label.new()
	l1.text = tr("Your name:")
	l1.position = Vector2(10, 10)
	add_child(l1)
	_name = LineEdit.new()
	_name.position = Vector2(10, 28)
	_name.size = Vector2(size.x - 20, 22)
	_name.max_length = 24
	add_child(_name)
	var l2 := Label.new()
	l2.text = tr("Your message:")
	l2.position = Vector2(10, 58)
	add_child(l2)
	_text = LineEdit.new()
	_text.position = Vector2(10, 76)
	_text.size = Vector2(size.x - 20, 22)
	_text.max_length = 140
	add_child(_text)
	var send := Button.new()
	send.text = tr("Send")
	send.position = Vector2(size.x - 170, size.y - 36)
	send.size = Vector2(76, 26)
	send.pressed.connect(_send)
	add_child(send)
	var cancel := Button.new()
	cancel.text = tr("Cancel")
	cancel.position = Vector2(size.x - 88, size.y - 36)
	cancel.size = Vector2(76, 26)
	cancel.pressed.connect(func(): _shell._close_window(_win))
	add_child(cancel)
	_name.grab_focus.call_deferred()


func _send() -> void:
	var who := _name.text.strip_edges()
	var line := _text.text.strip_edges()
	if who == "" or line == "":
		_shell.play("ding", -8.0)
		return
	var rows: Array = (_shell.stored("guestbook_mine", []) as Array).duplicate(true)
	rows.append({"name": who, "text": line, "day": CoreRoot.get_day() if CoreRoot != null else 1, "time": _clock()})
	_shell.store("guestbook_mine", rows)
	_shell.play("click", -8.0)
	_shell._close_window(_win)
	var br = _shell.app_of("browser")
	if br != null and br.has_method("navigate"):
		br.navigate("cerne-jezero.cz/guestbook")


func _clock() -> String:
	var m = _shell.main_node()
	var h := float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 12.0
	return "%02d:%02d" % [int(h) % 24, int(fmod(h, 1.0) * 60.0)]
