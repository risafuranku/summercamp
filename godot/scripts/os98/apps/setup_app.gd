extends Control

## The setup wizard every program came with, cut to three steps (playtest 18. 10.:
## players did not know what to click through five pages): Welcome with the licence
## under it and one Install button, Installing (the billboard of photos while it
## copies), Finish (launch it now). The button to press is always the default one (the
## black frame of Okna's default button; Enter presses it). A blue gradient strip on the
## left with the product name. Behind it, over the whole desktop, the installer's own
## screen: the blue that runs down to black and the product's name in big letters, the
## way every setup of the time took over the machine; a moment of "Setup is preparing
## the wizard" before it.

const T = preload("res://scripts/os98/os_theme.gd")
const PROGRESS = preload("res://scripts/os98/os_progress.gd")
const FILES = preload("res://scripts/os98/os_files.gd")

const PRODUCTS := {
	"pub_app": {"name": "Hostinsky 98", "vendor": "SoftSklad Jihlava", "licence": "SOFTSKLAD JIHLAVA - LICENCE\n\nThis copy is licensed to one operator for one recreational facility. The licence was paid for on www.softsklad.cz and is not transferable.\n\nThe program keeps the books of the operator's pubs: stock, orders to the wholesaler, staff and takings. The figures are the operator's responsibility. SoftSklad is not responsible for goods that are not delivered, for staff, or for what the guests do after the bar closes.", "files": ["HOSPOD98.EXE", "SKLAD.DBF", "POKLADNA.DBF", "CENIK.DBF", "PIVO.ICO"]},
	"bistro_app": {"name": "Kuchar 98", "vendor": "SoftSklad Jihlava", "licence": "SOFTSKLAD JIHLAVA - LICENCE\n\nThis copy is licensed to one operator for one recreational facility. The licence was paid for on www.softsklad.cz and is not transferable.\n\nThe program keeps the books of the operator's bistros: stock, orders to the wholesaler, staff and takings. The figures are the operator's responsibility. SoftSklad is not responsible for goods that are not delivered, for staff, or for what the guests do after the bar closes.", "files": ["KUCHAR98.EXE", "SKLAD.DBF", "RECEPTY.DBF", "NORMY.DBF"]},
	"shop_app": {"name": "Pult 98", "vendor": "SoftSklad Jihlava", "licence": "SOFTSKLAD JIHLAVA - LICENCE\n\nThis copy is licensed to one operator for one recreational facility. The licence was paid for on www.softsklad.cz and is not transferable.\n\nThe program keeps the books of the operator's shops: stock, orders to the wholesaler, staff and takings. The figures are the operator's responsibility. SoftSklad is not responsible for goods that are not delivered, for staff, or for what the guests do after the bar closes.", "files": ["PULT98.EXE", "SKLAD.DBF", "CENIK.DBF", "DPH98.DAT"]},
	"corn_app": {"name": "Klasek 98", "vendor": "SoftSklad Jihlava", "licence": "SOFTSKLAD JIHLAVA - LICENCE\n\nThis copy is licensed to one operator for one recreational facility. The licence was paid for on www.softsklad.cz and is not transferable.\n\nThe program keeps the books of the operator's corn stands: stock, orders to the wholesaler, staff and takings. The figures are the operator's responsibility. SoftSklad is not responsible for goods that are not delivered, for staff, or for what the guests do after the bar closes.", "files": ["KLASEK98.EXE", "SKLAD.DBF"]},
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
	"datapunch": {
		"name": "DataPunch 98",
		"vendor": "Okresni urad Hlubocany",
		"licence": "DISTRICT OFFICE HLUBOCANY - HOME TRANSCRIPTION\n\nThe District Office is putting the register of persons accommodated in the district (1961-1989) on computer. Citizens with a computer may transcribe register cards at home.\n\nPAYMENT. Each card filed without mistakes is paid at the rate in force. Cards with mistakes are paid in part or not at all. The office accepts a limited number of cards per night.\n\nCards that are not on the batch list are to be filed in the ordinary way. Do not contact the office about them.",
		"files": ["DATAPNCH.EXE", "DAVKA61.DBF", "DAVKA62.DBF", "FORM.FRM", "OKRES.DAT"],
	},
	"guestrack": {
		"name": "GuestRack 98",
		"vendor": "Okres Hlubocany",
		"licence": "DISTRICT OFFICE HLUBOCANY - GUEST REGISTER\n\nAccommodation facilities in the district are required to keep a register of every person who stays overnight (Act 135/1993, par. 9).\n\nGuestRack 98 keeps the register for you. Every person in the facility must be entered. Persons who are not entered are not the responsibility of the District Office.\n\nThe register cannot be deleted.",
		"files": ["GUESTRAK.EXE", "EVIDENCE.DBF", "EVIDENCE.NDX", "OKRES.DAT"],
	},
}

const P_WELCOME := 0
const P_COPY := 1
const P_DONE := 2
const P_ALREADY := 3
## How long the copying takes: long enough to see the billboard go round once.
const COPY_SECONDS := 6.5
const PREP_SECONDS := 0.9

var _shell
var _win
var _program := ""
var _file := ""
var _page := 0
var _launch := true
var _default_frame: Control
var _copy_t := 0.0
var _banner: Control
var _body: Control
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
	_next = _button("Install", Vector2(size.x - 183, size.y - 31))
	_next.pressed.connect(_on_next)
	_cancel = _button("Cancel", Vector2(size.x - 91, size.y - 31))
	_cancel.pressed.connect(_on_cancel)
	# Okna's default button: a black frame round it (the one Enter presses).
	_default_frame = Control.new()
	_default_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_default_frame.position = _next.position - Vector2(1, 1)
	_default_frame.size = _next.size + Vector2(2, 2)
	_default_frame.draw.connect(func(): _default_frame.draw_rect(Rect2(Vector2.ZERO, _default_frame.size), Color.BLACK, false, 1.0))
	add_child(_default_frame)
	if _shell._is_program_unlocked(_program):
		_page = P_ALREADY
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
		var p := clampf(_prep_t / (PREP_SECONDS * 0.9), 0.0, 1.0)
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
	match _page:
		P_WELCOME:
			_go(P_COPY)
		P_DONE:
			_shell.close_app_window(_win)
			if _launch:
				_shell.open_app(_program)
		_:
			_shell.close_app_window(_win)


func _on_cancel() -> void:
	if _page >= P_DONE:
		_shell.close_app_window(_win)
		return
	_shell.message_box("Exit Setup", "Setup is not complete. If you quit now, %s will not be installed.\n\nExit Setup?" % _info()["name"], "question", ["Yes", "No"], func(b: String):
		if b == "Yes":
			_shell.close_app_window(_win)
	)


## Enter presses the default button, as it did.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not is_visible_in_tree():
		return
	if (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and not _next.disabled and _prep_t < 0.0:
		_on_next()
		get_viewport().set_input_as_handled()


func _go(page: int) -> void:
	if _prep_t >= 0.0:
		# Asked for a page while still preparing: the wizard is up now.
		_prep_t = -1.0
		_win.visible = true
	_page = clampi(page, P_WELCOME, P_ALREADY)
	for c in _body.get_children():
		c.queue_free()
	var info := _info()
	_next.disabled = false
	_cancel.disabled = _page != P_WELCOME
	match _page:
		P_WELCOME:
			_title("Welcome to %s Setup" % info["name"])
			_text("Setup will install %s on this computer. It takes a few seconds." % info["name"], 22)
			var box := RichTextLabel.new()
			box.text = str(info["licence"])
			box.position = Vector2(0, 52)
			box.size = Vector2(_body.size.x, _body.size.y - 94)
			box.selection_enabled = false
			_body.add_child(box)
			_text("Click Install to accept the licence and install.", _body.size.y - 36)
			_next.text = "Install"
		P_COPY:
			_title("Installing %s" % info["name"])
			# The billboard first and big: what you get, in photos that change while it
			# copies; the file and the bar under it.
			var board := Control.new()
			board.name = "Billboard"
			board.position = Vector2(0, 22)
			board.size = Vector2(_body.size.x, _body.size.y - 70)
			# Loaded here, not in the draw (a texture first loaded inside a draw call
			# comes out white).
			for sl in BILLBOARD.get(_program, []):
				var bp := str(sl[2])
				if bp != "" and ResourceLoader.exists(bp):
					_board_tex[bp] = load(bp)
			board.draw.connect(func(): _draw_billboard(board))
			_body.add_child(board)
			var file_l := Label.new()
			file_l.name = "File"
			file_l.clip_text = true
			file_l.size = Vector2(_body.size.x, 14)
			file_l.position = Vector2(0, _body.size.y - 44)
			_body.add_child(file_l)
			var bar = PROGRESS.new("install")
			bar.name = "Bar"
			bar.show_percent = true
			bar.position = Vector2(0, _body.size.y - 26)
			bar.size = Vector2(_body.size.x, 20)
			_body.add_child(bar)
			_next.text = "Install"
			_next.disabled = true
			_copy_t = 0.0
			_shell.set_busy(true)
			_shell.play("hdd_long", -12.0)
		P_DONE:
			_title("%s is installed" % info["name"])
			_text("Its icon is on the desktop, and in Start > Programs.\n\nClick Finish to start it now.", 22)
			var run := CheckBox.new()
			run.text = "Start %s now" % info["name"]
			run.button_pressed = _launch
			run.position = Vector2(0, 92)
			run.toggled.connect(func(on: bool): _launch = on)
			_body.add_child(run)
			_next.text = "Finish"
		P_ALREADY:
			_title("Already installed")
			_text("%s is already installed on this computer. Its icon is on the desktop." % info["name"], 22)
			_next.text = "OK"
	_default_frame.visible = not _next.disabled
	_default_frame.queue_redraw()


func _process(delta: float) -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_redraw()
	if _prep_t >= 0.0:
		_prep_t += delta
		if _prep_t >= PREP_SECONDS:
			_prep_t = -1.0
			_win.visible = true
			_go(_page)
			_shell._activate(_win)
		return
	if _page != P_COPY:
		return
	_copy_t += delta
	var files: Array = _info()["files"]
	var p := clampf(_copy_t / COPY_SECONDS, 0.0, 1.0)
	var bar = _body.get_node_or_null("Bar")
	var fl: Label = _body.get_node_or_null("File")
	if bar != null:
		bar.value = p
	if fl != null:
		fl.text = "Copying C:\\PROGRAM FILES\\%s\\%s" % [FILES.PROGRAM_DIRS[_program][0], files[mini(files.size() - 1, int(p * files.size()))]]
	if fmod(_copy_t, 1.3) < delta:
		_shell.play("hdd", -12.0)
	var board: Control = _body.get_node_or_null("Billboard")
	if board != null:
		board.queue_redraw()
	if p >= 1.0:
		_shell.set_busy(false)
		_shell.install_program(_program, true)
		_shell.play("ding", -8.0)
		_go(P_DONE)


var _board_tex := {}
const BILLBOARD := {
	"builder": [["Plan the whole site", "Tents, chalets, toilets, the pub: tile by tile.", "res://assets/textury/web/web_camp.png"], ["Know what it costs", "Running costs before you build. No surprises.", "res://assets/textury/web/web_campfire.png"], ["Paths down to the water", "Lamps, fences and the shore, from above.", "res://assets/textury/web/web_lake_photo.png"]],
	"camp_status": [["CampStat 98", "What every building draws, live, in kWh.", ""], ["Pay in the program", "Bills issued daily at 20:00. Payable within 3 days.", ""], ["Hlubocany District Power", "We keep the lights on. Up to the reservoir fence.", ""]],
	"guestrack": [["GuestRack 98", "Every person who stays the night, in one register.", ""], ["Act no. 135/1993", "Keeping the register is the operator's duty.", ""], ["The register cannot be deleted.", "Persons not in the register are not the District's responsibility.", ""]],
	"pub_app": [["Hostinsky 98", "Every keg, every shot, every mug. In one program.", ""], ["Order from the office", "The van brings it in the morning.", ""], ["Your barman's day", "Wages, takings, who went away dry.", ""]],
	"bistro_app": [["Kuchar 98", "Goulash, cheese, dumplings: what is in the kitchen.", ""], ["Order from the office", "The van brings it in the morning.", ""], ["Your cook's day", "Wages, takings, who went away hungry.", ""]],
	"shop_app": [["Pult 98", "Bread, rolls, salami, milk, beer. On the shelf or not.", ""], ["Order from the office", "The van brings it in the morning.", ""], ["The till's day", "Wages, takings, who left with nothing.", ""]],
	"corn_app": [["Klasek 98", "Cobs and butter, counted.", ""], ["Order from the office", "The van brings it in the morning.", ""], ["The stand's day", "Wages, takings.", ""]],
	"datapunch": [["Earn at home", "Type the old register in your own time. Paid per card.", ""], ["1961 - 1989", "Every person who stayed by the reservoir.", ""], ["Accuracy pays", "A card without mistakes pays in full.", ""]],
}


## While it copies: a panel about the program, changing every few seconds, the way
## every installer of the time sold you what you had already bought.
func _draw_billboard(c: Control) -> void:
	var slides: Array = BILLBOARD.get(_program, [["Thank you", "for choosing %s." % str(_info()["vendor"]), ""]])
	# Every slide once while it copies.
	var i := mini(int(_copy_t / (COPY_SECONDS / float(slides.size()))), slides.size() - 1)
	var sl: Array = slides[i]
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color8(0, 0, 96))
	c.draw_rect(Rect2(Vector2.ZERO, s), T.DARK, false, 1.0)
	var cap_y := 18.0
	var tex: Texture2D = _board_tex.get(str(sl[2]))
	if tex != null:
		# The photo across the panel, cut to fit (not squashed), the caption under it.
		var area := Rect2(4, 4, s.x - 8, s.y - 42)
		var ts := Vector2(tex.get_size())
		var k := maxf(area.size.x / ts.x, area.size.y / ts.y)
		var src := Rect2((ts - area.size / k) * 0.5, area.size / k)
		c.draw_texture_rect_region(tex, area, src)
		c.draw_rect(area, T.WHITE, false, 1.0)
		cap_y = area.end.y + 14.0
	c.draw_string(T.FONT_BOLD, Vector2(8, cap_y), str(sl[0]), HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, Color8(255, 255, 120))
	c.draw_multiline_string(T.FONT, Vector2(8, cap_y + 14), str(sl[1]), HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, -1, T.WHITE)


func closing() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_free()
	if _page == P_COPY:
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
