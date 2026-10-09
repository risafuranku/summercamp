extends Control

## Beeternet Explorer 4: toolbar, address bar, the page, the status bar. The first page
## of the session dials the modem. Typing a word that is not an address searches the
## Czech web (the portal's index). Download links ask, then hand the file to the shell.

const T = preload("res://scripts/os98/os_theme.gd")
const WEB = preload("res://scripts/os98/web_pages.gd")
const LINK_RE := "\\{([^{}|]+)\\|([^{}]+)\\}"

var _shell
var _win
var _address: LineEdit
var _page: RichTextLabel
var _status: Label
var _throbber: Control
var _back: Button
var _fwd: Button
var _history: Array[String] = []
var _hist_i := -1
var _url := ""
var _loading := 0.0
var _pending := ""
var _dial: Control
var _dial_label: Label
var _dial_t := -1.0
var _dial_then := ""
var _anim := 0.0
var _counters: Dictionary = {}
var _link_re := RegEx.new()


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	_link_re.compile(LINK_RE)
	_build()
	navigate(str(args.get("url", WEB.HOME)))


func reopen(args: Dictionary) -> void:
	if args.has("url"):
		navigate(str(args["url"]))


func closing() -> void:
	# Hang up when the browser closes: the call costs money by the minute.
	_shell.set_online(false)
	if _loading > 0.0 or _dial_t >= 0.0:
		_shell.set_busy(false)


func _build() -> void:
	var tools := HBoxContainer.new()
	tools.position = Vector2(2, 2)
	tools.add_theme_constant_override("separation", 2)
	add_child(tools)
	_back = _tool(tools, "Back", func(): _go_history(-1))
	_fwd = _tool(tools, "Forward", func(): _go_history(1))
	_tool(tools, "Stop", _stop)
	_tool(tools, "Refresh", func(): _load(_url, false))
	_tool(tools, "Home", func(): navigate(WEB.HOME))
	_tool(tools, "Search", func(): navigate(WEB.HOME))
	_throbber = Control.new()
	_throbber.size = Vector2(36, 26)
	_throbber.draw.connect(_draw_throbber)
	add_child(_throbber)

	var row := HBoxContainer.new()
	row.position = Vector2(2, 32)
	row.add_theme_constant_override("separation", 4)
	row.name = "AddressRow"
	add_child(row)
	var lab := Label.new()
	lab.text = "Address"
	row.add_child(lab)
	_address = LineEdit.new()
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text_submitted.connect(func(t): navigate(t))
	row.add_child(_address)
	var go := Button.new()
	go.text = "Go"
	go.custom_minimum_size = Vector2(32, 20)
	go.pressed.connect(func(): navigate(_address.text))
	row.add_child(go)

	_page = RichTextLabel.new()
	_page.bbcode_enabled = true
	_page.selection_enabled = true
	_page.meta_underlined = true
	_page.meta_clicked.connect(func(m): _on_link(str(m)))
	_page.position = Vector2(0, 56)
	add_child(_page)

	var bar := Panel.new()
	bar.name = "StatusBar"
	bar.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4.ZERO))
	add_child(bar)
	_status = Label.new()
	_status.position = Vector2(4, 2)
	_status.clip_text = true
	bar.add_child(_status)

	_build_dialer()
	resized.connect(_layout)
	_layout()


func _tool(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 26)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _layout() -> void:
	if _page == null:
		return
	_throbber.position = Vector2(size.x - 38, 2)
	var row: Control = get_node("AddressRow")
	row.size = Vector2(size.x - 4, 22)
	_page.size = Vector2(size.x, size.y - 56 - 20)
	var bar: Panel = get_node("StatusBar")
	bar.position = Vector2(0, size.y - 18)
	bar.size = Vector2(size.x, 18)
	_status.size = Vector2(size.x - 8, 14)
	_dial.position = ((size - _dial.size) * 0.5).floor()


# ── navigation ───────────────────────────────────────────────────────────────

static func normalize(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	for p in ["http://", "https://", "www."]:
		s = s.trim_prefix(p)
	s = s.trim_suffix("/")
	for suffix in ["/index.htm", "/index.html"]:
		s = s.trim_suffix(suffix)
	return s


func navigate(raw: String) -> void:
	var s := raw.strip_edges()
	if s.is_empty():
		return
	var key := normalize(s)
	# A word, not an address: search.
	if key.find(".") < 0 and not key.begins_with("search?"):
		key = "search?q=" + key.uri_encode()
	if _hist_i < _history.size() - 1:
		_history.resize(_hist_i + 1)
	_history.append(key)
	_hist_i = _history.size() - 1
	_load(key, true)


func _go_history(step: int) -> void:
	var i := _hist_i + step
	if i < 0 or i >= _history.size():
		return
	_hist_i = i
	_load(_history[i], false)


func _load(key: String, _fresh: bool) -> void:
	if key.is_empty():
		return
	_address.text = _address_for(key)
	if not _shell.is_online():
		_dial_then = key
		_open_dialer()
		return
	_pending = key
	if _loading <= 0.0:
		_shell.set_busy(true)
	_loading = randf_range(0.5, 1.3) + (0.6 if not _shell.is_day() else 0.0)
	_status.text = "Opening page http://www.%s ..." % key
	_back.disabled = _hist_i <= 0
	_fwd.disabled = _hist_i >= _history.size() - 1


func _address_for(key: String) -> String:
	if key.begins_with("search?"):
		return "http://www.bohemia-online.cz/" + key
	return "http://www." + key + ("/" if key.find("/") < 0 else "")


func _stop() -> void:
	if _loading > 0.0:
		_loading = 0.0
		_shell.set_busy(false)
		_status.text = "Stopped."


func _process(delta: float) -> void:
	if _loading > 0.0:
		_anim += delta
		_throbber.queue_redraw()
		_loading -= delta
		if _loading <= 0.0:
			_shell.set_busy(false)
			_show(_pending)
	if _dial_t >= 0.0:
		_tick_dialer(delta)


func _show(key: String) -> void:
	_url = key
	_address.text = _address_for(key)
	var page := _page_for(key)
	var bg := Color.html(str(page.get("bg", "#ffffff")))
	_page.add_theme_stylebox_override("normal", T.box("field", bg, Vector4(8, 6, 8, 6)))
	_page.add_theme_color_override("default_color", Color.html(str(page.get("fg", "#000000"))))
	_page.text = _expand(str(page.get("body", "")), str(page.get("link", "#0000ee")), key)
	_page.scroll_to_line(0)
	_win.title = "%s - Beeternet Explorer" % str(page.get("title", key))
	_status.text = "Done"
	_throbber.queue_redraw()
	_counters[key] = int(_counters.get(key, 0)) + 1


func _page_for(key: String) -> Dictionary:
	if key.begins_with("search?q="):
		return _search_page(key.trim_prefix("search?q=").uri_decode())
	if WEB.PAGES.has(key):
		return WEB.PAGES[key]
	return {
		"title": "Cannot find server",
		"bg": "#ffffff", "fg": "#000000", "link": "#0000ee",
		"body": "[font_size=18][b]The page cannot be displayed[/b][/font_size]\n\nThe page you are looking for is currently unavailable. The Web site might be experiencing technical difficulties, or you may need to adjust your browser settings.\n\n[b]Cannot find server or DNS Error[/b]\nhttp://www.%s\n\n{%s|Go to the Bohemia Online start page}" % [key, WEB.HOME],
	}


func _on_link(target: String) -> void:
	if target.begins_with("download://"):
		var file := target.trim_prefix("download://")
		_shell.message_box("File Download", "You have chosen to download a file from this location.\n\n%s from www.%s\n\nSave this program to disk (C:\\DOWNLOAD)?" % [file, _url.split("/")[0]], "question", ["Save", "Cancel"], func(b: String):
			if b == "Save":
				_shell.start_download(file, "http://www." + _url)
		)
		return
	navigate(target)


# ── page content ─────────────────────────────────────────────────────────────

func _expand(body: String, link: String, key: String) -> String:
	var t := body
	if t.find("{{") >= 0:
		t = t.replace("{{search}}", "\n[center][bgcolor=#e0e8ff] [b]Search the Czech web:[/b] type a word in the Address bar and press Go. [/bgcolor][/center]\n")
		t = t.replace("{{day}}", str(_day()))
		t = t.replace("{{time}}", _time())
		t = t.replace("{{counter}}", _counter(key))
		t = t.replace("{{weather}}", _weather())
		t = t.replace("{{guestbook}}", _guestbook())
	return _link_re.sub(t, "[url=$1][color=%s]$2[/color][/url]" % link, true)


func _day() -> int:
	return CoreRoot.get_day() if CoreRoot != null else 1


func _time() -> String:
	var m: Node = _shell.main_node()
	return str(m.call("_time_of_day_string")) if m != null and m.has_method("_time_of_day_string") else "--:--"


## The game's first day is Saturday 4 July 1998.
func _date(day: int) -> String:
	return "%d.7.1998" % (3 + day)


func _counter(key: String) -> String:
	var base := 1000 + (absi(key.hash()) % 7000)
	if key == "cerne-jezero.cz" and not _shell.is_day():
		# At night the camp's counter counts something else.
		return "%06d" % (_in_camp() + 1)
	return "%06d" % (base + _day() * 3 + int(_counters.get(key, 0)))


func _in_camp() -> int:
	var n := 0
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state != null:
		for g in state.guests:
			if g is Dictionary and str(g.get("status", "")) in ["active", "sleep"]:
				n += maxi(1, int(g.get("party_size", 1)))
	return n


func _weather() -> String:
	var m: Node = _shell.main_node()
	var w := int(m.get("_weather_state")) if m != null and m.get("_weather_state") != null else 0
	var now: String = ["clear", "windy", "fog", "light rain", "rain", "thunderstorms", "fog"][clampi(w, 0, 6)]
	var t := "[b]Now, Vysocina:[/b] %s\n" % now
	t += "[b]Tonight:[/b] %s, 9 to 12 degrees.\n" % ("fog in the valleys" if w == 2 or w == 6 else "mostly clear, cool")
	t += "[b]Tomorrow:[/b] partly cloudy, 21 to 24 degrees.\n"
	if w == 6:
		t += "\n[color=#cc0000]The reservoir station reports. Reading: 0 0 0 0 0 0[/color]\n"
	return t


## Old entries, then new ones as the week goes on. Some are written tonight.
func _guestbook() -> String:
	var rows: Array = [
		["Petr & Jitka", "12.7.1997", "Great week!! The lake is freezing but beautiful. The night game with Karel was SO scary :-)"],
		["Tomas", "2.8.1997", "who was the man in the hat at the disco? he stood by the door the whole time and didnt dance. nobody knew him"],
		["Lucie (mum of Ondra)", "16.8.1997", "Ondra came back with only one shoe. Not red, I checked, ha ha. Thank you Vera for everything."],
		["Honza", "21.8.1997", "the photos from the night game came out all black except one. who is that by the fence"],
		["-", "1.1.1998", "1987"],
		["Martina", "15.6.1998", "Is the camp open this year? Nobody answers the phone."],
	]
	var day := _day()
	var guests := _in_camp()
	var night: bool = not _shell.is_day()
	if day >= 2:
		rows.append(["karel", _date(day - 1) + "  23:58", "whoever is minding the camp now: count them at ten and at midnight. write it down. dont stay up past one"])
	if day >= 3:
		rows.append(["Jana", _date(day - 1) + "  02:10", "has anyone seen my shoe"])
	if day >= 4:
		rows.append(["(no name)", _date(day - 1) + "  03:33", "smile :)"])
	if day >= 5:
		rows.append(["Vera", _date(day - 1) + "  21:15", "I am at my sister's. Please do not write here any more. The district reads it."])
	if night and guests > 0:
		rows.append(["(no name)", _date(day) + "  " + _time(), "you have %d in the camp tonight. we counted %d" % [guests, guests + 1]])
	var t := ""
	for i in range(rows.size() - 1, -1, -1):
		var r: Array = rows[i]
		t += "[color=#808080]________________________________________[/color]\n"
		t += "[b][color=#66ff66]%s[/color][/b]  [color=#aaaaaa]%s[/color]\n%s\n" % [r[0], r[1], r[2]]
	return t + "[color=#808080]________________________________________[/color]\n[color=#aaaaaa]The guest book is full. New entries cannot be added.[/color]\n"


func _search_page(q: String) -> Dictionary:
	var words := q.to_lower().replace("+", " ").split(" ", false)
	var hits: Array = []
	for key in WEB.INDEX:
		var idx := str(WEB.INDEX[key])
		for w in words:
			if idx.find(w) >= 0 or str(key).find(w) >= 0:
				hits.append(key)
				break
	var body := "[b]Bohemia Online search[/b]   [color=#666666]you searched for:[/color] [b]%s[/b]\n\n" % q.replace("[", "")
	if hits.is_empty():
		body += "No pages were found. Check the spelling, or try fewer words.\n"
	else:
		body += "%d page(s) found:\n\n" % hits.size()
		for k in hits:
			var p: Dictionary = WEB.PAGES.get(k, {})
			body += "{%s|%s}\n[color=#008000]http://www.%s/[/color]\n\n" % [k, str(p.get("title", k)), k]
	body += WEB.HR + "\n{%s|Bohemia Online}" % WEB.HOME
	return {"title": "Bohemia Online - search", "bg": "#ffffff", "fg": "#000000", "link": "#0000ee", "body": body}


# ── dial-up ──────────────────────────────────────────────────────────────────

func _build_dialer() -> void:
	_dial = Panel.new()
	_dial.add_theme_stylebox_override("panel", T.box("window", T.FACE, Vector4.ZERO))
	_dial.size = Vector2(300, 150)
	_dial.visible = false
	add_child(_dial)
	var title := Panel.new()
	title.add_theme_stylebox_override("panel", T.flat(T.NAVY))
	title.position = Vector2(3, 3)
	title.size = Vector2(294, 18)
	_dial.add_child(title)
	var tl := Label.new()
	tl.text = "Dial-up Connection"
	tl.add_theme_font_override("font", T.FONT_BOLD)
	tl.add_theme_color_override("font_color", T.WHITE)
	tl.position = Vector2(4, 2)
	title.add_child(tl)
	var info := Label.new()
	info.text = "Connect to:     Bohemia Online\nUser name:      kemp.cj\nPassword:       ********\nPhone number:   0638 41 41 00"
	info.position = Vector2(12, 28)
	_dial.add_child(info)
	_dial_label = Label.new()
	_dial_label.position = Vector2(12, 90)
	_dial_label.size = Vector2(276, 14)
	_dial.add_child(_dial_label)
	var ok := Button.new()
	ok.name = "Connect"
	ok.text = "Connect"
	ok.position = Vector2(126, 116)
	ok.size = Vector2(80, 23)
	ok.pressed.connect(_start_dial)
	_dial.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.position = Vector2(212, 116)
	cancel.size = Vector2(80, 23)
	cancel.pressed.connect(func():
		_dial.visible = false
		if _dial_t >= 0.0:
			_shell.set_busy(false)
		_dial_t = -1.0
		_status.text = "Not connected. Click Refresh to dial again."
		_page.text = "[b]You are working offline.[/b]\n\nBeeternet Explorer could not open the page because the computer is not connected to the Internet."
	)
	_dial.add_child(cancel)


func _open_dialer() -> void:
	_dial.visible = true
	_dial.move_to_front()
	_dial_label.text = "Ready."
	(_dial.get_node("Connect") as Button).disabled = false
	_status.text = "Not connected."


func _start_dial() -> void:
	(_dial.get_node("Connect") as Button).disabled = true
	_dial_t = 0.0
	_shell.set_busy(true)
	_shell.play("modem", -6.0)


func _tick_dialer(delta: float) -> void:
	_dial_t += delta
	var steps := [[0.0, "Dialing 0638 41 41 00..."], [2.6, "Waiting for the other computer..."], [4.6, "Verifying user name and password..."], [6.2, "Logging on to network..."], [7.2, "Connected at 33,600 bps."]]
	for s in steps:
		if _dial_t >= float(s[0]):
			_dial_label.text = str(s[1])
	if _dial_t >= 7.8:
		_dial_t = -1.0
		_dial.visible = false
		_shell.set_busy(false)
		_shell.set_online(true)
		_load(_dial_then, false)


func _draw_throbber() -> void:
	var s := _throbber.size
	_throbber.draw_style_box(T.box("field", Color8(0, 0, 0), Vector4.ZERO), Rect2(Vector2.ZERO, s))
	var c := s * 0.5
	var spin := _anim * 4.0 if _loading > 0.0 else 0.0
	for k in 6:
		var a := spin + k * TAU / 6.0
		_throbber.draw_circle(c + Vector2(cos(a), sin(a) * 0.5) * 9.0, 2.0, Color8(255, 200, 0) if k == 0 else Color8(90, 140, 255))
	_throbber.draw_string(T.FONT_BOLD, c + Vector2(-4, 5), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
