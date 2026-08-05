# install_wizard.gd
# Win98-style install wizard.
# Desktop nastaví `app_id` před add_child, wizard se sám zobrazí.
# Po dokončení emituje EventBus.program_installed(app_id).
# Signal close_requested: desktop zavře okno.

extends Panel

signal close_requested

var app_id: String = ""

const WIN_SIZE    := Vector2(420, 302)
const C_WIN_BG    := Color(0.63, 0.58, 0.48, 1.0)
const C_TITLE_BAR := Color(0.35, 0.19, 0.12, 1.0)
const C_BORDER    := Color(0.31, 0.24, 0.16, 1.0)
const C_TEXT_DARK := Color(0.12, 0.08, 0.06, 1.0)
const C_TEXT_LT   := Color(0.93, 0.89, 0.74, 1.0)
const C_ACCENT    := Color(0.45, 0.51, 0.30, 1.0)
const PROGRESS_SEGMENT_COUNT := 26

var _step: int = 0
var _agreed: bool = false
var _progress_val: float = 0.0
var _progress_track: Panel = null
var _progress_segments: Array[ColorRect] = []
var _progress_lbl: Label = null
var _progress_status: Label = null

var _content_box: VBoxContainer = null
var _nav_box: HBoxContainer = null
var _nav_div: ColorRect = null

const APP_TITLES := {
	"builder": "Builder",
	"guestrack": "GuestRack",
	"camp_status": "Camp Status",
	"finance": "Finance",
	"minesweeper": "Minesweeper",
	"campmail": "CampMail",
}


func _ready() -> void:
	if size.x < 10.0 or size.y < 10.0:
		size = WIN_SIZE
	mouse_filter = MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _sb(C_WIN_BG, C_BORDER, 1))

	_content_box = VBoxContainer.new()
	_content_box.position = Vector2(0, 0)
	_content_box.size = Vector2(size.x, maxf(120.0, size.y - 34.0))
	_content_box.clip_contents = true
	_content_box.add_theme_constant_override("separation", 0)
	add_child(_content_box)

	_nav_div = ColorRect.new()
	_nav_div.color = C_BORDER
	_nav_div.position = Vector2(0, size.y - 34.0)
	_nav_div.size = Vector2(size.x, 1)
	add_child(_nav_div)

	_nav_box = HBoxContainer.new()
	_nav_box.position = Vector2(8, size.y - 30.0)
	_nav_box.size = Vector2(maxf(120.0, size.x - 16.0), 26)
	_nav_box.add_theme_constant_override("separation", 4)
	add_child(_nav_box)

	_render_step()
	_layout_module()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_module()


func _layout_module() -> void:
	var w := maxf(320.0, size.x)
	var h := maxf(240.0, size.y)
	if _content_box != null:
		_content_box.position = Vector2(0.0, 0.0)
		_content_box.size = Vector2(w, maxf(120.0, h - 34.0))
	if _nav_div != null:
		_nav_div.position = Vector2(0.0, h - 34.0)
		_nav_div.size = Vector2(w, 1.0)
	if _nav_box != null:
		_nav_box.position = Vector2(8.0, h - 30.0)
		_nav_box.size = Vector2(maxf(120.0, w - 16.0), 26.0)


func _app_title() -> String:
	return str(APP_TITLES.get(app_id, "Program Module"))


func _app_install_folder() -> String:
	return "C:\\Program Files\\%s\\" % _app_title().replace(" ", "")


# ── STEP RENDERING ───────────────────────────────────────────────────────────

func _clear_boxes() -> void:
	for c in _content_box.get_children():
		_content_box.remove_child(c)
		c.queue_free()
	for c in _nav_box.get_children():
		_nav_box.remove_child(c)
		c.queue_free()
	_progress_track = null
	_progress_segments.clear()
	_progress_lbl = null
	_progress_status = null


func _render_step() -> void:
	_clear_boxes()
	match _step:
		0: _step_welcome()
		1: _step_license()
		2: _step_location()
		3: _step_progress()
		4: _step_finish()


# ── STEP 0: WELCOME ──────────────────────────────────────────────────────────

func _step_welcome() -> void:
	var app_name := _app_title()
	_content_box.add_child(_make_header(
		"%s — Setup Wizard" % app_name,
		"Installation v1.0.4 for Camp Territory"
	))
	_content_box.add_child(_make_body(
		"Welcome to the %s setup wizard.\n\n" % app_name +
		"This wizard will install %s on your\n" % app_name +
		"computer. Please close all other applications\n" +
		"before continuing.\n\n" +
		"Click  Next  to continue, or  Cancel  to exit setup."
	))

	_nav_spacer()
	_nav_box.add_child(_make_btn("Cancel",  func(): _request_close()))
	_nav_box.add_child(_make_btn("Next >",  func(): _request_step(1), true))


# ── STEP 1: LICENSE ──────────────────────────────────────────────────────────

func _step_license() -> void:
	var app_name := _app_title()
	_content_box.add_child(_make_header(
		"License Agreement",
		"Please read the following terms carefully."
	))

	# Divider
	var div1 := ColorRect.new()
	div1.color = C_BORDER.lightened(0.1)
	div1.custom_minimum_size = Vector2(0, 1)
	_content_box.add_child(div1)

	# License text — FIXED height, no SIZE_EXPAND_FILL on the container
	var txt_wrap := _margin(8, 6, 8, 4)
	txt_wrap.custom_minimum_size = Vector2(0, 150)
	_content_box.add_child(txt_wrap)

	var txt := TextEdit.new()
	txt.editable = false
	txt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	txt.caret_blink = false
	txt.selecting_enabled = false
	txt.size_flags_horizontal = SIZE_EXPAND_FILL
	txt.size_flags_vertical   = SIZE_EXPAND_FILL
	var lic_bg := _sb(Color(0.05, 0.05, 0.08, 0.97), Color(0.28, 0.30, 0.38, 1.0), 1)
	txt.add_theme_stylebox_override("normal",    lic_bg)
	txt.add_theme_stylebox_override("read_only", lic_bg)
	txt.add_theme_color_override("default_color",       Color(0.76, 0.80, 0.72, 1.0))
	txt.add_theme_color_override("font_readonly_color", Color(0.76, 0.80, 0.72, 1.0))
	txt.add_theme_font_size_override("font_size", 10)
	txt.text = (
		"CURSED CAMP INDUSTRIES — END USER LICENSE AGREEMENT\n"
		+ "Version 2.1 — Camp Territory Only\n"
		+ "────────────────────────────────────────\n\n"
		+ "READ CAREFULLY before installing this software.\n\n"
		+ "By installing %s you agree to:\n" % app_name
		+ "  (a) Accept all risk of anomalous events.\n"
		+ "  (b) Waive liability for static voices, temporal\n"
		+ "      drift, or unexplained structural growth.\n"
		+ "  (c) Permit operational telemetry to CAMP-CONTROL.\n"
		+ "  (d) Not power off mid-installation under any\n"
		+ "      circumstances.\n\n"
		+ "Section 4.7 — In the event of total facility loss,\n"
		+ "all software licences revert to Cursed Camp Industries.\n"
		+ "Camp counsellor remains responsible for all data artifacts.\n\n"
		+ "This software is provided AS-IS, with no warranty of\n"
		+ "structural integrity, temporal consistency, or\n"
		+ "personal survivability.\n"
	)
	txt_wrap.add_child(txt)

	# Divider above agree row
	var div2 := ColorRect.new()
	div2.color = C_BORDER
	div2.custom_minimum_size = Vector2(0, 1)
	_content_box.add_child(div2)

	# Agree row — no nested Panel, just margin + HBox with fixed height
	var agree_mg := _margin(12, 5, 12, 5)
	agree_mg.custom_minimum_size = Vector2(0, 28)
	_content_box.add_child(agree_mg)

	var agree_row := HBoxContainer.new()
	agree_row.add_theme_constant_override("separation", 8)
	agree_mg.add_child(agree_row)

	var chk_btn := Button.new()
	chk_btn.text = "[x]" if _agreed else "[ ]"
	chk_btn.focus_mode = FOCUS_NONE
	chk_btn.custom_minimum_size = Vector2(32, 22)
	chk_btn.add_theme_font_size_override("font_size", 11)
	chk_btn.add_theme_stylebox_override("normal",
		_sb(Color(0.10, 0.10, 0.14, 1.0), Color(0.50, 0.50, 0.60, 1.0), 1))
	chk_btn.add_theme_stylebox_override("hover",
		_sb(Color(0.18, 0.18, 0.24, 1.0), Color(0.70, 0.70, 0.80, 1.0), 1))
	chk_btn.add_theme_color_override("font_color", Color(0.72, 0.88, 0.72, 1.0))
	agree_row.add_child(chk_btn)

	var agree_lbl := Label.new()
	agree_lbl.text = "I agree to the licence terms"
	agree_lbl.add_theme_font_size_override("font_size", 11)
	agree_lbl.add_theme_color_override("font_color", C_TEXT_DARK)
	agree_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	agree_row.add_child(agree_lbl)

	var next_btn := _make_btn("Next >", func(): _request_step(2), true)
	next_btn.disabled = not _agreed

	chk_btn.pressed.connect(func():
		_agreed = not _agreed
		chk_btn.text = "[x]" if _agreed else "[ ]"
		next_btn.disabled = not _agreed
	)

	_nav_spacer()
	_nav_box.add_child(_make_btn("< Back",  func(): _request_step(0)))
	_nav_box.add_child(_make_btn("Cancel",  func(): _request_close()))
	_nav_box.add_child(next_btn)


# ── STEP 2: LOCATION ─────────────────────────────────────────────────────────

func _step_location() -> void:
	var app_name := _app_title()
	_content_box.add_child(_make_header(
		"Install Location",
		"Choose where %s will be installed." % app_name
	))

	var wrap = _margin(14, 12, 14, 0)
	_content_box.add_child(wrap)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	wrap.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "%s will be installed in the following\nfolder. Click  Install  to begin." % app_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_TEXT_DARK)
	vbox.add_child(lbl)

	var path_row = Panel.new()
	path_row.custom_minimum_size = Vector2(390, 26)
	path_row.add_theme_stylebox_override("panel",
		_sb(Color(0.05, 0.05, 0.08, 0.96), Color(0.28, 0.30, 0.38, 1.0), 1))
	var path_lbl = Label.new()
	path_lbl.text = _app_install_folder()
	path_lbl.position = Vector2(6, 4)
	path_lbl.size = Vector2(378, 18)
	path_lbl.add_theme_font_size_override("font_size", 11)
	path_lbl.add_theme_color_override("font_color", Color(0.72, 0.88, 0.72, 1.0))
	path_row.add_child(path_lbl)
	vbox.add_child(path_row)

	var info = Label.new()
	info.text = "Required space:   3.2 MB\nAvailable space:  847.6 MB"
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", C_TEXT_DARK.lightened(0.2))
	vbox.add_child(info)

	_nav_spacer()
	_nav_box.add_child(_make_btn("< Back",  func(): _request_step(1)))
	_nav_box.add_child(_make_btn("Cancel",  func(): _request_close()))
	_nav_box.add_child(_make_btn("Install", func(): _request_step(3), true))


# ── STEP 3: PROGRESS ─────────────────────────────────────────────────────────

func _step_progress() -> void:
	_progress_val = 0.0
	var app_name := _app_title()

	_content_box.add_child(_make_header(
		"Installing...",
		"Please wait while %s is installed." % app_name
	))

	var wrap = _margin(14, 14, 14, 0)
	_content_box.add_child(wrap)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	wrap.add_child(vbox)

	_progress_lbl = Label.new()
	_progress_lbl.text = "■ Installing...  0%"
	_progress_lbl.add_theme_font_size_override("font_size", 12)
	_progress_lbl.add_theme_color_override("font_color", C_TEXT_DARK)
	vbox.add_child(_progress_lbl)

	var bar_track = Panel.new()
	bar_track.custom_minimum_size = Vector2(0, 24)
	bar_track.size_flags_horizontal = SIZE_EXPAND_FILL
	bar_track.add_theme_stylebox_override("panel",
		_sb(Color(0.04, 0.04, 0.06, 1.0), Color(0.28, 0.30, 0.38, 1.0), 1))
	vbox.add_child(bar_track)
	_progress_track = bar_track

	var seg_margin = MarginContainer.new()
	seg_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	seg_margin.add_theme_constant_override("margin_left", 3)
	seg_margin.add_theme_constant_override("margin_top", 3)
	seg_margin.add_theme_constant_override("margin_right", 3)
	seg_margin.add_theme_constant_override("margin_bottom", 3)
	bar_track.add_child(seg_margin)

	var seg_row = HBoxContainer.new()
	seg_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	seg_row.add_theme_constant_override("separation", 2)
	seg_margin.add_child(seg_row)

	_progress_segments.clear()
	for i in range(PROGRESS_SEGMENT_COUNT):
		var seg = ColorRect.new()
		seg.mouse_filter = MOUSE_FILTER_IGNORE
		seg.color = Color(0.11, 0.11, 0.14, 1.0)
		seg.size_flags_horizontal = SIZE_EXPAND_FILL
		seg.custom_minimum_size = Vector2(6, 0)
		seg_row.add_child(seg)
		_progress_segments.append(seg)
	_set_progress_visual()

	_progress_status = Label.new()
	_progress_status.text = "Copying core files..."
	_progress_status.add_theme_font_size_override("font_size", 10)
	_progress_status.add_theme_color_override("font_color", C_TEXT_DARK.lightened(0.15))
	vbox.add_child(_progress_status)

	_nav_spacer()
	# Žádná navigace během instalace

	get_tree().create_timer(0.4).timeout.connect(_progress_tick)


func _set_progress_visual() -> void:
	var filled_segments: int = int(ceil(_progress_val * float(PROGRESS_SEGMENT_COUNT)))
	filled_segments = clampi(filled_segments, 0, PROGRESS_SEGMENT_COUNT)
	for i in range(_progress_segments.size()):
		var seg = _progress_segments[i]
		if seg == null or not is_instance_valid(seg):
			continue
		if i < filled_segments:
			seg.color = C_ACCENT.lightened(0.12)
		else:
			seg.color = Color(0.11, 0.11, 0.14, 1.0)


func _progress_tick() -> void:
	if not is_instance_valid(self) or _step != 3:
		return

	var msgs := [
		"Copying core files...",
		"Extracting CampLogic.dll...",
		"Registering system modules...",
		"Writing registry entries...",
		"Verifying file integrity...",
		"Configuring camp subsystems...",
		"Finalizing installation..."
	]

	var stall := randf() < 0.18
	var delay: float

	if stall:
		delay = randf_range(0.9, 2.6)
		if _progress_status and is_instance_valid(_progress_status):
			_progress_status.text = "Please wait..."
	else:
		_progress_val = minf(_progress_val + randf_range(0.02, 0.08), 1.0)
		_set_progress_visual()
		var pct := int(_progress_val * 100)
		if _progress_lbl and is_instance_valid(_progress_lbl):
			_progress_lbl.text = "■ Installing...  %d%%" % pct
		var idx: int = clampi(int(_progress_val * msgs.size()), 0, msgs.size() - 1)
		if _progress_status and is_instance_valid(_progress_status):
			_progress_status.text = msgs[idx]
		delay = randf_range(0.12, 0.44)

	if _progress_val >= 1.0:
		if _progress_status and is_instance_valid(_progress_status):
			_progress_status.text = "Installation complete."
		get_tree().create_timer(0.7).timeout.connect(func():
			if is_instance_valid(self) and _step == 3:
				_request_step(4)
		)
		return

	get_tree().create_timer(delay).timeout.connect(_progress_tick)


# ── STEP 4: FINISH ───────────────────────────────────────────────────────────

func _step_finish() -> void:
	var app_name := _app_title()
	_content_box.add_child(_make_header(
		"Installation Complete",
		"%s has been installed successfully." % app_name
	))

	var wrap = _margin(14, 12, 14, 0)
	_content_box.add_child(wrap)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	wrap.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "Setup has finished installing %s.\nThe application is ready to use." % app_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_TEXT_DARK)
	vbox.add_child(lbl)

	var chk_desktop = CheckBox.new()
	chk_desktop.text = "Create desktop shortcut"
	chk_desktop.button_pressed = true
	chk_desktop.focus_mode = FOCUS_NONE
	chk_desktop.add_theme_font_size_override("font_size", 11)
	chk_desktop.add_theme_color_override("font_color", C_TEXT_DARK)
	vbox.add_child(chk_desktop)

	var chk_menu = CheckBox.new()
	chk_menu.text = "Add to Start Menu"
	chk_menu.button_pressed = true
	chk_menu.focus_mode = FOCUS_NONE
	chk_menu.add_theme_font_size_override("font_size", 11)
	chk_menu.add_theme_color_override("font_color", C_TEXT_DARK)
	vbox.add_child(chk_menu)

	_nav_spacer()
	_nav_box.add_child(_make_btn("Finish", func(): _request_finish(), true))


# ── HELPERS ───────────────────────────────────────────────────────────────────

func _go(step: int) -> void:
	_step = step
	_render_step()


func _request_step(step: int) -> void:
	call_deferred("_go", step)


func _request_close() -> void:
	call_deferred("_emit_close_requested")


func _emit_close_requested() -> void:
	close_requested.emit()


func _request_finish() -> void:
	call_deferred("_finish_installation")


func _finish_installation() -> void:
	EventBus.program_installed.emit(app_id)
	close_requested.emit()


func _make_header(title: String, subtitle: String = "") -> Control:
	var full_w := maxf(320.0, size.x)
	var hdr = Panel.new()
	hdr.custom_minimum_size = Vector2(full_w, 52)
	hdr.add_theme_stylebox_override("panel",
		_sb(C_TITLE_BAR.lightened(0.04), C_BORDER.darkened(0.1), 0))

	var t = Label.new()
	t.text = title
	t.position = Vector2(14, 8)
	t.size = Vector2(full_w - 28, 18)
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", C_TEXT_LT)
	hdr.add_child(t)

	if not subtitle.is_empty():
		var s = Label.new()
		s.text = subtitle
		s.position = Vector2(14, 28)
		s.size = Vector2(full_w - 28, 16)
		s.add_theme_font_size_override("font_size", 10)
		s.add_theme_color_override("font_color", C_TEXT_LT.darkened(0.25))
		hdr.add_child(s)
	return hdr


func _make_body(text: String) -> Control:
	var wrap = _margin(14, 10, 14, 0)
	var lbl = Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_TEXT_DARK)
	wrap.add_child(lbl)
	return wrap


func _make_btn(label: String, cb: Callable, primary: bool = false) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(80, 24)
	btn.focus_mode = FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	if primary:
		_apply_btn_style(btn, C_ACCENT.lightened(0.06))
	else:
		var base := C_WIN_BG
		btn.add_theme_stylebox_override("normal",  _sb(base, C_BORDER.darkened(0.08), 2))
		btn.add_theme_stylebox_override("hover",   _sb(base.lightened(0.06), C_BORDER, 2))
		btn.add_theme_stylebox_override("pressed", _sb(base.darkened(0.10), C_BORDER.darkened(0.14), 2))
		btn.add_theme_color_override("font_color", C_TEXT_DARK)
	btn.pressed.connect(cb)
	return btn


func _nav_spacer() -> void:
	var sp = Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	_nav_box.add_child(sp)


func _margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m


func _sb(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(0)
	return s


func _apply_btn_style(btn: Button, base: Color) -> void:
	btn.add_theme_stylebox_override("normal",  _sb(base, base.darkened(0.34), 2))
	btn.add_theme_stylebox_override("hover",   _sb(base.lightened(0.08), base.darkened(0.26), 2))
	btn.add_theme_stylebox_override("pressed", _sb(base.darkened(0.14), base.darkened(0.42), 2))
	btn.add_theme_color_override("font_color",         C_TEXT_DARK)
	btn.add_theme_color_override("font_hover_color",   C_TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", C_TEXT_DARK)
