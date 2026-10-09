extends Control

## The setup wizard every program came with: Welcome, Licence (you have to agree),
## Destination, Copying files, Finish. A blue gradient strip on the left with the
## product name, Back / Next / Cancel at the bottom.

const T = preload("res://scripts/os98/os_theme.gd")
const FILES = preload("res://scripts/os98/os_files.gd")

const PRODUCTS := {
	"builder": {
		"name": "Builder 98",
		"vendor": "Stavitel software",
		"licence": "STAVITEL SOFTWARE - LICENCE AGREEMENT\n\nBuilder 98 is shareware. You may use it for 30 days to plan one site. After that you must register it or remove it from your computer.\n\nRECREATIONAL FACILITIES. If Builder 98 is used to plan a camp, a holiday site or any facility where people sleep, it may be used only between 06:30 and 20:00. Builder 98 will not start outside these hours. Stavitel software is not responsible for anything that is built, or for anything that comes to a site after dark.\n\nStavitel software makes no warranty that the program is fit for any purpose.",
		"files": ["BUILDER.EXE", "BLDR32.DLL", "TERRAIN.DAT", "TILES.PAL", "FENCE.SPR", "TENT.SPR", "CABIN.SPR", "LAMP.SPR", "README98.TXT"],
	},
	"camp_status": {
		"name": "CampStat 98",
		"vendor": "CampGrid s.r.o.",
		"licence": "CAMPGRID S.R.O. - CONDITIONS OF USE\n\nCampStat 98 is supplied free of charge to customers of Hlubocany District Power. It reads your meter and your bills over the telephone line.\n\nCampGrid s.r.o. collects the readings of your meter. Bills not paid within the period on the bill may lead to the supply being cut off without further notice.\n\nThe NIGHT page is supplied by the previous operator of your facility and is not part of the product.",
		"files": ["CAMPSTAT.EXE", "METER.DRV", "TARIF96.DAT", "NOCNI.TXT"],
	},
	"guestrack": {
		"name": "GuestRack 98",
		"vendor": "Okres Hlubocany",
		"licence": "DISTRICT OFFICE HLUBOCANY - GUEST REGISTER\n\nAccommodation facilities in the district are required to keep a register of every person who stays overnight (Act 135/1993, par. 9).\n\nGuestRack 98 keeps the register for you. Every person in the facility must be entered. Persons who are not entered are not the responsibility of the District Office.\n\nThe register cannot be deleted.",
		"files": ["GUESTRAK.EXE", "EVIDENCE.DBF", "EVIDENCE.NDX", "OKRES.DAT"],
	},
}

var _shell
var _win
var _program := ""
var _file := ""
var _page := 0
var _agree := false
var _launch := true
var _copy_t := 0.0
var _banner: Control
var _body: Control
var _back: Button
var _next: Button
var _cancel: Button


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	_program = str(args.get("program", "builder"))
	_file = str(args.get("file", ""))
	win.can_maximize = false
	win.title = "%s Setup" % _info()["name"]
	_banner = Control.new()
	_banner.position = Vector2(8, 8)
	_banner.size = Vector2(110, size.y - 52)
	_banner.draw.connect(_draw_banner)
	add_child(_banner)
	_body = Control.new()
	_body.position = Vector2(128, 8)
	_body.size = Vector2(size.x - 136, size.y - 52)
	add_child(_body)
	var line := ColorRect.new()
	line.color = T.SHADOW
	line.position = Vector2(8, size.y - 40)
	line.size = Vector2(size.x - 16, 1)
	add_child(line)
	var line2 := ColorRect.new()
	line2.color = T.WHITE
	line2.position = Vector2(8, size.y - 39)
	line2.size = Vector2(size.x - 16, 1)
	add_child(line2)
	_back = _button("< Back", Vector2(size.x - 258, size.y - 31))
	_back.pressed.connect(func(): _go(_page - 1))
	_next = _button("Next >", Vector2(size.x - 183, size.y - 31))
	_next.pressed.connect(_on_next)
	_cancel = _button("Cancel", Vector2(size.x - 91, size.y - 31))
	_cancel.pressed.connect(_on_cancel)
	if _shell._is_program_unlocked(_program):
		_page = 5
	_go(_page)


func _info() -> Dictionary:
	return PRODUCTS.get(_program, PRODUCTS["builder"])


func _button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(75, 23)
	add_child(b)
	return b


func _on_next() -> void:
	if _page == 4:
		if _launch:
			var app := _program
			_shell.close_app_window(_win)
			_shell.open_app(app)
		else:
			_shell.close_app_window(_win)
		return
	if _page == 5:
		_shell.close_app_window(_win)
		return
	_go(_page + 1)


func _on_cancel() -> void:
	if _page >= 4:
		_shell.close_app_window(_win)
		return
	_shell.message_box("Exit Setup", "Setup is not complete. If you quit now, %s will not be installed.\n\nExit Setup?" % _info()["name"], "question", ["Yes", "No"], func(b: String):
		if b == "Yes":
			_shell.close_app_window(_win)
	)


func _go(page: int) -> void:
	_page = clampi(page, 0, 5)
	for c in _body.get_children():
		c.queue_free()
	var info := _info()
	_back.disabled = _page == 0 or _page >= 3
	_next.disabled = false
	_cancel.disabled = _page == 3
	_next.text = "Next >"
	match _page:
		0:
			_title("Welcome")
			_text("This program will install %s on your computer.\n\nIt is strongly recommended that you exit all Okna programs before running this Setup program.\n\nClick Cancel to quit Setup. Click Next to continue." % info["name"], 30)
		1:
			_title("Licence Agreement")
			var box := RichTextLabel.new()
			box.text = str(info["licence"])
			box.position = Vector2(0, 26)
			box.size = Vector2(_body.size.x, _body.size.y - 70)
			box.selection_enabled = true
			_body.add_child(box)
			var yes := CheckBox.new()
			yes.text = "I accept the agreement"
			yes.button_pressed = _agree
			yes.position = Vector2(0, _body.size.y - 40)
			yes.toggled.connect(func(on: bool):
				_agree = on
				_next.disabled = not on
			)
			_body.add_child(yes)
			_next.disabled = not _agree
		2:
			_title("Choose Destination Location")
			_text("Setup will install %s in the following folder.\n\nTo install to this folder, click Next." % info["name"], 30)
			var field := Panel.new()
			field.add_theme_stylebox_override("panel", T.box("field", T.WHITE, Vector4.ZERO))
			field.position = Vector2(0, 110)
			field.size = Vector2(_body.size.x - 84, 22)
			_body.add_child(field)
			var l := Label.new()
			l.text = "C:\\PROGRAM FILES\\%s" % FILES.PROGRAM_DIRS[_program][0]
			l.position = Vector2(5, 4)
			field.add_child(l)
			var browse := Button.new()
			browse.text = "Browse..."
			browse.position = Vector2(_body.size.x - 78, 110)
			browse.size = Vector2(78, 23)
			browse.pressed.connect(func(): _shell.message_box("Setup", "There is only one disk in this computer.", "info"))
			_body.add_child(browse)
			_text("Space required: %d KB\nSpace available: 6 112 KB" % (int(_shell.DOWNLOAD_SIZES_KB.get(_file, 60)) * 3), 150)
			_next.text = "Install"
		3:
			_title("Installing")
			_text("Copying files...", 30)
			var file_l := Label.new()
			file_l.name = "File"
			file_l.position = Vector2(0, 60)
			_body.add_child(file_l)
			var bar := ProgressBar.new()
			bar.name = "Bar"
			bar.position = Vector2(0, 80)
			bar.size = Vector2(_body.size.x, 18)
			bar.max_value = 1.0
			bar.step = 0.0
			bar.show_percentage = false
			_body.add_child(bar)
			_next.disabled = true
			_copy_t = 0.0
			_shell.set_busy(true)
		4:
			_title("Setup Complete")
			_text("Setup has finished installing %s on your computer.\n\nThe program can be started from the icon on the desktop or from Start > Programs." % info["name"], 30)
			var run := CheckBox.new()
			run.text = "Launch %s now" % info["name"]
			run.button_pressed = _launch
			run.position = Vector2(0, 130)
			run.toggled.connect(func(on: bool): _launch = on)
			_body.add_child(run)
			_next.text = "Finish"
			_cancel.disabled = true
		5:
			_title("Already installed")
			_text("%s is already installed on this computer." % info["name"], 30)
			_next.text = "OK"
			_back.disabled = true


func _process(delta: float) -> void:
	if _page != 3:
		return
	_copy_t += delta
	var files: Array = _info()["files"]
	var dur := 2.0 + files.size() * 0.55
	var p := clampf(_copy_t / dur, 0.0, 1.0)
	var bar: ProgressBar = _body.get_node_or_null("Bar")
	var fl: Label = _body.get_node_or_null("File")
	if bar != null:
		bar.value = p
	if fl != null:
		fl.text = "C:\\PROGRAM FILES\\%s\\%s" % [FILES.PROGRAM_DIRS[_program][0], files[mini(files.size() - 1, int(p * files.size()))]]
	if fmod(_copy_t, 1.3) < delta:
		_shell.play("hdd", -12.0)
	if p >= 1.0:
		_shell.set_busy(false)
		_shell.install_program(_program, true)
		_go(4)


func closing() -> void:
	if _page == 3:
		_shell.set_busy(false)


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.FONT_BOLD)
	l.position = Vector2(0, 2)
	_body.add_child(l)


func _text(text: String, y: float) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.position = Vector2(0, y)
	l.size = Vector2(_body.size.x, 80)
	_body.add_child(l)


func _draw_banner() -> void:
	var s := _banner.size
	for y in int(s.y):
		_banner.draw_rect(Rect2(0, y, s.x, 1), Color8(0, 0, 128).lerp(Color8(0, 120, 200), float(y) / s.y))
	_banner.draw_rect(Rect2(Vector2.ZERO, s), T.DARK, false, 1.0)
	var tex: Texture2D = _shell.icon(str(_shell.APPS[_program]["icon"]))
	_banner.draw_texture(tex, Vector2(s.x * 0.5 - 16, 16))
	var name := str(_info()["name"])
	var y2 := 70.0
	for word in name.split(" "):
		var w := T.FONT_BOLD.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2).x
		_banner.draw_string(T.FONT_BOLD, Vector2((s.x - w) * 0.5, y2), word, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, T.WHITE)
		y2 += 26
	var v := str(_info()["vendor"])
	var vw := T.FONT.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	_banner.draw_string(T.FONT, Vector2((s.x - vw) * 0.5, s.y - 10), v, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(200, 220, 255))
