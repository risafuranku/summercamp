extends Control

## The setup wizard every program came with: Welcome, Licence (you have to agree),
## Destination, Copying files, Finish. A blue gradient strip on the left with the
## product name, Back / Next / Cancel at the bottom. Behind it, over the whole desktop,
## the installer's own screen: the blue that runs down to black and the product's name
## in big letters, the way every setup of the time took over the machine. Before the
## wizard, "Setup is preparing the wizard" with its own little bar.

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
var _backdrop: Control
var _prep_t := -1.0


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
		return
	_build_backdrop()
	# First the preparing box: the wizard comes up when its bar is full.
	_prep_t = 0.0
	_win.visible = false
	_shell.play("hdd_long", -14.0)


func _build_backdrop() -> void:
	_backdrop = Control.new()
	_backdrop.name = "SetupBackdrop"
	_backdrop.size = _shell.DESKTOP_SIZE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.draw.connect(_draw_backdrop)
	_shell.add_child(_backdrop)
	_shell.move_child(_backdrop, _shell._windows.get_index())


func _draw_backdrop() -> void:
	var b := _backdrop
	var s: Vector2 = b.size
	# Blue to black in bands of four lines: 256 colours made it banded.
	var y := 0.0
	while y < s.y:
		var k := y / s.y
		b.draw_rect(Rect2(0, y, s.x, 4), Color8(0, 0, int(255 * (1.0 - k) + 20 * k)))
		y += 4.0
	var pname := str(_info()["name"])
	var vendor := str(_info()["vendor"])
	b.draw_string(T.FONT_BOLD, Vector2(26, 64), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 3, Color(0, 0, 0))
	b.draw_string(T.FONT_BOLD, Vector2(22, 60), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 3, T.WHITE)
	b.draw_string(T.FONT_BOLD, Vector2(24, 88), vendor, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(200, 210, 255))
	b.draw_string(T.FONT, Vector2(22, s.y - 12), "SetupWizard 3.0  (c) 1990-1997 InstallBox Corp.", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(110, 120, 200))
	if _prep_t >= 0.0:
		var r := Rect2((s - Vector2(300, 96)) * 0.5, Vector2(300, 96))
		b.draw_style_box(T.box("window", T.FACE), r)
		for i in int(r.size.x - 6):
			b.draw_rect(Rect2(r.position.x + 3 + i, r.position.y + 3, 1, 18), T.TITLE_A.lerp(T.TITLE_B, float(i) / r.size.x))
		b.draw_string(T.FONT_BOLD, r.position + Vector2(8, 16), "%s Setup" % pname, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
		b.draw_string(T.FONT, r.position + Vector2(48, 44), "Setup is preparing the SetupWizard, which", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
		b.draw_string(T.FONT, r.position + Vector2(48, 58), "will guide you through the installation.", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
		var tex: Texture2D = _shell.icon("setup")
		if tex != null:
			b.draw_texture(tex, r.position + Vector2(10, 34))
		var bar := Rect2(r.position + Vector2(48, 68), Vector2(240, 14))
		b.draw_style_box(T.box("field", T.WHITE), bar)
		var p := clampf(_prep_t / 2.2, 0.0, 1.0)
		var blocks := int(p * 26.0)
		for i in blocks:
			b.draw_rect(Rect2(bar.position.x + 3 + i * 9, bar.position.y + 3, 7, 8), T.NAVY)


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
	if _prep_t >= 0.0:
		# Asked for a page while still preparing: the wizard is up now.
		_prep_t = -1.0
		_win.visible = true
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
			box.selection_enabled = false
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
			# The billboard: what you get, in panels that change while it copies.
			var board := Control.new()
			board.name = "Billboard"
			board.position = Vector2(0, 108)
			board.size = Vector2(_body.size.x, _body.size.y - 112)
			board.draw.connect(func(): _draw_billboard(board))
			_body.add_child(board)
			_next.disabled = true
			_copy_t = 0.0
			_shell.set_busy(true)
			_shell.play("hdd_long", -12.0)
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
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_redraw()
	if _prep_t >= 0.0:
		_prep_t += delta
		if _prep_t >= 2.4:
			_prep_t = -1.0
			_win.visible = true
			_go(_page)
			_shell._activate(_win)
		return
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
	var board: Control = _body.get_node_or_null("Billboard")
	if board != null:
		board.queue_redraw()
	if p >= 1.0:
		_shell.set_busy(false)
		_shell.install_program(_program, true)
		_go(4)


const BILLBOARD := {
	"builder": [["Plan the whole site", "Tents, chalets, toilets, the pub: tile by tile.", "res://assets/textury/web/web_camp.png"], ["Know what it costs", "Running costs before you build. No surprises.", "res://assets/textury/web/web_campfire.png"], ["Register for 990 Kc", "Your key comes by post. Stavitel, Jihlava.", ""]],
	"camp_status": [["CampStat 98", "What every building draws, live, in kWh.", ""], ["Pay in the program", "Bills issued daily at 20:00. Payable within 3 days.", ""], ["Hlubocany District Power", "We keep the lights on. Up to the reservoir fence.", ""]],
	"guestrack": [["GuestRack 98", "Every person who stays the night, in one register.", ""], ["Act no. 135/1993", "Keeping the register is the operator's duty.", ""], ["The register cannot be deleted.", "Persons not in the register are not the District's responsibility.", ""]],
}


## While it copies: a panel about the program, changing every few seconds, the way
## every installer of the time sold you what you had already bought.
func _draw_billboard(c: Control) -> void:
	var slides: Array = BILLBOARD.get(_program, [["Thank you", "for choosing %s." % str(_info()["vendor"]), ""]])
	var i := int(_copy_t / 2.6) % slides.size()
	var sl: Array = slides[i]
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color8(0, 0, 96))
	c.draw_rect(Rect2(Vector2.ZERO, s), T.DARK, false, 1.0)
	var x := 8.0
	var path := str(sl[2])
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var h := s.y - 12.0
		var w := h * tex.get_width() / float(tex.get_height())
		c.draw_texture_rect(tex, Rect2(6, 6, w, h), false)
		c.draw_rect(Rect2(6, 6, w, h), T.WHITE, false, 1.0)
		x = 14.0 + w
	c.draw_string(T.FONT_BOLD, Vector2(x, 24), str(sl[0]), HORIZONTAL_ALIGNMENT_LEFT, s.x - x - 6, T.FONT_SIZE, Color8(255, 255, 120))
	c.draw_multiline_string(T.FONT, Vector2(x, 44), str(sl[1]), HORIZONTAL_ALIGNMENT_LEFT, s.x - x - 6, T.FONT_SIZE, -1, T.WHITE)


func closing() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_free()
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
