extends Control

signal link_hover_entered
signal link_hover_exited

const PAGE_ENGINE_SCRIPT_PATH := "res://scripts/beeternet_pages/page_engine.gd"
const HOME_URL := "home://start"

const MASTHEAD_H := 30.0
const TOOLBAR_H := 36.0
const RULE_H := 2.0
const STATUS_H := 22.0

const C_WIN_BG := Color(0.64, 0.58, 0.46, 1.0)
const C_MASTHEAD_BG := Color(0.29, 0.22, 0.14, 1.0)
const C_MASTHEAD_TEXT := Color(0.97, 0.94, 0.84, 1.0)
const C_BORDER := Color(0.32, 0.24, 0.16, 1.0)
const C_TEXT_DARK := Color(0.12, 0.08, 0.06, 1.0)
const C_ACCENT := Color(0.44, 0.50, 0.30, 1.0)
const C_CONTENT_BG := Color(0.95, 0.93, 0.86, 1.0)

const INSTALLER_FILES := {
	"builder": "_builder98_setup.exe",
	"guestrack": "_guestrack98_setup.exe",
	"camp_status": "_campstatus98_setup.exe",
	"finance": "_finance98_setup.exe",
	"minesweeper": "_minesweeper98_setup.exe",
	"campmail": "_campmail98_setup.exe",
}

const APP_CATALOG := [
	{
		"id": "builder",
		"title": "Builder",
		"summary": "Core camp construction module",
		"size": "4.1 MB",
	},
	{
		"id": "guestrack",
		"title": "GuestRack",
		"summary": "Guest records and assignment tracker",
		"size": "2.8 MB",
	},
	{
		"id": "camp_status",
		"title": "Camp Status",
		"summary": "Live telemetry, day stats and load overview",
		"size": "1.9 MB",
	},
	{
		"id": "finance",
		"title": "Finance",
		"summary": "Budget log and revenue monitor",
		"size": "2.3 MB",
	},
	{
		"id": "minesweeper",
		"title": "Minesweeper",
		"summary": "Certified stress recovery module",
		"size": "0.7 MB",
	},
	{
		"id": "campmail",
		"title": "CampMail",
		"summary": "Inbox and booking confirmation client",
		"size": "1.6 MB",
	},
]

var _history: Array[String] = []
var _history_pos: int = -1

var _downloads: Array[String] = []
var _unlock_registry: Dictionary = {}

var _page_engine: RefCounted = null
var _page_engine_load_attempted := false

var _masthead: Panel = null
var _toolbar: Panel = null
var _rule: ColorRect = null
var _status_bar: Panel = null

var _addr_input: LineEdit = null
var _content: RichTextLabel = null
var _status_lbl: Label = null
var _back_btn: Button = null
var _fwd_btn: Button = null
var _go_btn: Button = null


func set_desktop_context(downloads_items: Array, unlock_registry: Dictionary) -> void:
	_downloads.clear()
	for item in downloads_items:
		_downloads.append(str(item))
	_unlock_registry = unlock_registry.duplicate(true)
	if is_inside_tree():
		_refresh_page()


func _ready() -> void:
	_ensure_page_engine()
	_build_masthead()
	_build_toolbar()
	_build_rule()
	_build_content_area()
	_build_status_bar()
	_layout_ui()
	if EventBus.has_signal("file_downloaded"):
		EventBus.file_downloaded.connect(_on_file_downloaded)
	if EventBus.has_signal("program_installed"):
		EventBus.program_installed.connect(_on_program_installed)
	_navigate(HOME_URL)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_ui()


func _exit_tree() -> void:
	if EventBus.has_signal("file_downloaded") and EventBus.file_downloaded.is_connected(_on_file_downloaded):
		EventBus.file_downloaded.disconnect(_on_file_downloaded)
	if EventBus.has_signal("program_installed") and EventBus.program_installed.is_connected(_on_program_installed):
		EventBus.program_installed.disconnect(_on_program_installed)


func _on_file_downloaded(fname: String) -> void:
	if not fname in _downloads:
		_downloads.append(fname)
	_refresh_page()


func _on_program_installed(app_id: String) -> void:
	_unlock_registry[app_id] = true
	_refresh_page()


func _build_toolbar() -> void:
	_toolbar = Panel.new()
	_toolbar.position = Vector2(0, MASTHEAD_H)
	_toolbar.size = Vector2(size.x, TOOLBAR_H)
	_toolbar.add_theme_stylebox_override("panel", _sb(C_WIN_BG.darkened(0.04), C_BORDER, 0))
	add_child(_toolbar)

	var bh := 22.0
	var by := (TOOLBAR_H - bh) * 0.5
	var bw := 26.0

	_back_btn = _nav_btn("<", Vector2(4, by), Vector2(bw, bh))
	_back_btn.disabled = true
	_back_btn.pressed.connect(_nav_back)
	_toolbar.add_child(_back_btn)

	_fwd_btn = _nav_btn(">", Vector2(32, by), Vector2(bw, bh))
	_fwd_btn.disabled = true
	_fwd_btn.pressed.connect(_nav_forward)
	_toolbar.add_child(_fwd_btn)

	var refresh := _nav_btn("R", Vector2(60, by), Vector2(bw, bh))
	refresh.pressed.connect(func():
		if _history_pos >= 0:
			_render_page(_history[_history_pos])
	)
	_toolbar.add_child(refresh)

	var home_b := _nav_btn("H", Vector2(88, by), Vector2(bw, bh))
	home_b.pressed.connect(func(): _navigate(HOME_URL))
	_toolbar.add_child(home_b)

	var addr_lbl := Label.new()
	addr_lbl.text = "Address:"
	addr_lbl.position = Vector2(118, by + 2)
	addr_lbl.size = Vector2(54, bh)
	addr_lbl.add_theme_font_size_override("font_size", 11)
	addr_lbl.add_theme_color_override("font_color", C_TEXT_DARK)
	addr_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	_toolbar.add_child(addr_lbl)

	_addr_input = LineEdit.new()
	_addr_input.position = Vector2(174, by)
	_addr_input.size = Vector2(size.x - 174 - 44, bh)
	_addr_input.add_theme_font_size_override("font_size", 11)
	_addr_input.add_theme_color_override("font_color", Color(0.72, 0.88, 0.72, 1.0))
	var addr_style := _sb(Color(0.05, 0.06, 0.08, 1.0), C_BORDER.darkened(0.3), 1)
	_addr_input.add_theme_stylebox_override("normal", addr_style)
	_addr_input.add_theme_stylebox_override("focus", addr_style)
	_addr_input.text_submitted.connect(func(url: String): _navigate(url.strip_edges()))
	_toolbar.add_child(_addr_input)

	_go_btn = Button.new()
	_go_btn.text = "Go"
	_go_btn.position = Vector2(size.x - 42, by)
	_go_btn.size = Vector2(38, bh)
	_go_btn.focus_mode = FOCUS_NONE
	_go_btn.add_theme_font_size_override("font_size", 11)
	_apply_btn_style(_go_btn, C_ACCENT)
	_go_btn.pressed.connect(func(): _navigate(_addr_input.text.strip_edges()))
	_toolbar.add_child(_go_btn)


func _build_rule() -> void:
	_rule = ColorRect.new()
	_rule.position = Vector2(0, MASTHEAD_H + TOOLBAR_H)
	_rule.size = Vector2(size.x, RULE_H)
	_rule.color = C_BORDER
	add_child(_rule)


func _build_content_area() -> void:
	var cy := MASTHEAD_H + TOOLBAR_H + RULE_H
	var ch := maxf(60.0, size.y - cy - STATUS_H)
	_content = RichTextLabel.new()
	_content.position = Vector2(0, cy)
	_content.size = Vector2(size.x, ch)
	_content.bbcode_enabled = true
	_content.scroll_active = true
	_content.fit_content = false
	_content.add_theme_stylebox_override("normal", _sb(C_CONTENT_BG, C_BORDER.darkened(0.1), 1))
	_content.add_theme_color_override("default_color", Color(0.04, 0.04, 0.06, 1.0))
	_content.add_theme_font_size_override("normal_font_size", 12)
	_content.add_theme_constant_override("line_separation", 2)
	_content.meta_clicked.connect(func(meta: Variant): _on_link(str(meta)))
	_content.meta_hover_started.connect(func(_m: Variant): link_hover_entered.emit())
	_content.meta_hover_ended.connect(func(_m: Variant): link_hover_exited.emit())
	add_child(_content)


func _build_status_bar() -> void:
	_status_bar = Panel.new()
	_status_bar.position = Vector2(0, size.y - STATUS_H)
	_status_bar.size = Vector2(size.x, STATUS_H)
	_status_bar.add_theme_stylebox_override("panel", _sb(C_WIN_BG.darkened(0.06), C_BORDER, 1))
	add_child(_status_bar)

	_status_lbl = Label.new()
	_status_lbl.text = "  Ready."
	_status_lbl.position = Vector2(4, 2)
	_status_lbl.size = Vector2(size.x - 8, STATUS_H - 4.0)
	_status_lbl.add_theme_font_size_override("font_size", 10)
	_status_lbl.add_theme_color_override("font_color", C_TEXT_DARK)
	_status_bar.add_child(_status_lbl)


func _build_masthead() -> void:
	_masthead = Panel.new()
	_masthead.position = Vector2.ZERO
	_masthead.size = Vector2(size.x, MASTHEAD_H)
	_masthead.add_theme_stylebox_override("panel", _sb(C_MASTHEAD_BG, C_BORDER.darkened(0.2), 0))
	add_child(_masthead)

	var title := Label.new()
	title.text = "BEETERNET CORPORATE TERMINAL"
	title.position = Vector2(8, 5)
	title.size = Vector2(maxf(120.0, size.x - 16.0), 20)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", C_MASTHEAD_TEXT)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	_masthead.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "CAMP-NET / SOFTWARE REPOSITORY NODE"
	subtitle.position = Vector2(8, 17)
	subtitle.size = Vector2(maxf(120.0, size.x - 16.0), 14)
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", C_MASTHEAD_TEXT.darkened(0.18))
	subtitle.mouse_filter = MOUSE_FILTER_IGNORE
	_masthead.add_child(subtitle)


func _layout_ui() -> void:
	if _masthead != null:
		_masthead.size.x = size.x
	if _toolbar != null:
		_toolbar.position.y = MASTHEAD_H
		_toolbar.size.x = size.x
	if _addr_input != null:
		_addr_input.size.x = maxf(120.0, size.x - 174.0 - 44.0)
	if _go_btn != null:
		_go_btn.position.x = size.x - 42.0
	if _rule != null:
		_rule.position.y = MASTHEAD_H + TOOLBAR_H
		_rule.size.x = size.x
	if _content != null:
		var cy := MASTHEAD_H + TOOLBAR_H + RULE_H
		_content.position = Vector2(0.0, cy)
		_content.size = Vector2(size.x, maxf(60.0, size.y - cy - STATUS_H))
	if _status_bar != null:
		_status_bar.position.y = size.y - STATUS_H
		_status_bar.size.x = size.x
	if _status_lbl != null:
		_status_lbl.size.x = maxf(0.0, size.x - 8.0)


func _navigate(url: String) -> void:
	var target := url.strip_edges()
	if target.is_empty():
		target = HOME_URL
	if _history_pos < _history.size() - 1:
		_history = _history.slice(0, _history_pos + 1)
	_history.append(target)
	_history_pos = _history.size() - 1
	_render_page(target)


func _nav_back() -> void:
	if _history_pos > 0:
		_history_pos -= 1
		_render_page(_history[_history_pos])


func _nav_forward() -> void:
	if _history_pos < _history.size() - 1:
		_history_pos += 1
		_render_page(_history[_history_pos])


func _render_page(url: String) -> void:
	if _addr_input:
		_addr_input.text = url
	if _back_btn:
		_back_btn.disabled = _history_pos <= 0
	if _fwd_btn:
		_fwd_btn.disabled = _history_pos >= _history.size() - 1
	_set_status("  Connecting to %s..." % url)
	var page := _get_page(url)
	var resolved_url := str(page.get("url", url))
	if _history_pos >= 0 and _history_pos < _history.size():
		_history[_history_pos] = resolved_url
	if _addr_input != null:
		_addr_input.text = resolved_url
	if _content != null:
		_content.text = str(page.get("body", ""))
		_content.scroll_to_line(0)
	var title := str(page.get("title", "Done"))
	_set_status("  %s loaded." % title)


func _refresh_page() -> void:
	if _history_pos >= 0 and _history_pos < _history.size():
		_render_page(_history[_history_pos])


func _get_page(url: String) -> Dictionary:
	var guest_reviews: Array = []
	var guest_manager = get_node_or_null("/root/GuestManager")
	if guest_manager != null and guest_manager.has_method("get_recent_reviews"):
		guest_reviews = guest_manager.get_recent_reviews(6)

	var ctx := {
		"url": url,
		"downloads_items": _downloads.duplicate(),
		"unlock_registry": _unlock_registry.duplicate(true),
		"installer_files": INSTALLER_FILES,
		"app_catalog": APP_CATALOG,
		"guest_reviews": guest_reviews,
	}
	_ensure_page_engine()
	if _page_engine != null and _page_engine.has_method("render"):
		return _page_engine.call("render", url, ctx)
	return _render_fallback_page(url, ctx)


func _on_link(meta: String) -> void:
	if meta.begins_with("download://"):
		_handle_download(meta.substr(11))
	elif not meta.strip_edges().is_empty():
		_navigate(meta)


func _ensure_page_engine() -> void:
	if _page_engine_load_attempted:
		return
	_page_engine_load_attempted = true
	var script_any: Variant = load(PAGE_ENGINE_SCRIPT_PATH)
	if script_any is Script:
		var script_ref: Script = script_any
		_page_engine = script_ref.new()


func _render_fallback_page(url: String, ctx: Dictionary) -> Dictionary:
	var lowered := url.strip_edges().to_lower()
	if lowered.is_empty():
		lowered = HOME_URL

	if lowered == HOME_URL or lowered == "camp://downloads" or lowered == "camp://programs" or lowered == "camp://software":
		var b := ""
		b += "[color=#22344f][b]BEETERNET CORPORATE TERMINAL[/b][/color]\n"
		b += "[color=#5a5e63]Fallback mode active (page engine unavailable).[/color]\n\n"
		b += "[url=home://start][color=#274072]Portal home[/color][/url]  |  "
		b += "[url=camp://downloads][color=#274072]Software downloads[/color][/url]\n\n"
		b += "[color=#5e6474]------------------------------------------------[/color]\n"
		b += "[b]PROGRAM REPOSITORY[/b]\n"
		b += "[color=#5e6474]------------------------------------------------[/color]\n\n"

		for app_data in APP_CATALOG:
			var app_id := str(app_data.get("id", ""))
			var title := str(app_data.get("title", app_id))
			var summary := str(app_data.get("summary", ""))
			var size_label := str(app_data.get("size", "unknown"))
			var installer_file := str(INSTALLER_FILES.get(app_id, ""))
			var downloads: Array = ctx.get("downloads_items", [])
			var unlocked: Dictionary = ctx.get("unlock_registry", {})
			var is_installed := bool(unlocked.get(app_id, false))
			var is_downloaded := not installer_file.is_empty() and installer_file in downloads

			b += "[b]%s[/b]\n" % title
			b += "%s\n" % summary
			b += "[color=#5a5e63]size: %s | package: %s[/color]\n" % [size_label, installer_file]
			if is_installed:
				b += "[color=#2b6b2d]Installed on this workstation.[/color]\n\n"
			elif is_downloaded:
				b += "[color=#8c6219]Downloaded. Run installer from Downloads.[/color]\n\n"
			else:
				b += "[url=download://%s][color=#274072][ DOWNLOAD ][/color][/url]\n\n" % app_id
		return {
			"title": "Beeternet (Fallback)",
			"url": lowered,
			"body": b,
		}

	return {
		"title": "404 Not Found",
		"url": lowered,
		"body": "[color=#8a2f2f][b]Error 404[/b][/color]\nRequested page is not available.\n\n[url=home://start][color=#274072]Return to Beeternet home[/color][/url]",
	}


func _handle_download(app_id: String) -> void:
	if not INSTALLER_FILES.has(app_id):
		return
	if bool(_unlock_registry.get(app_id, false)):
		_set_status("  Program already installed.")
		return
	var fname: String = str(INSTALLER_FILES.get(app_id, ""))
	if fname in _downloads:
		_set_status("  Already downloaded.")
		return
	_set_status("  Downloading %s..." % fname)
	get_tree().create_timer(1.2).timeout.connect(func():
		if not is_instance_valid(self):
			return
		if not fname in _downloads:
			_downloads.append(fname)
		EventBus.file_downloaded.emit(fname)
		_set_status("  Done. File saved to Downloads.")
		_refresh_page()
	)


func _set_status(text: String) -> void:
	if _status_lbl and is_instance_valid(_status_lbl):
		_status_lbl.text = text


func _sb(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	return s


func _apply_btn_style(btn: Button, base: Color) -> void:
	btn.add_theme_stylebox_override("normal", _sb(base, base.darkened(0.34), 2))
	btn.add_theme_stylebox_override("hover", _sb(base.lightened(0.08), base.darkened(0.26), 2))
	btn.add_theme_stylebox_override("pressed", _sb(base.darkened(0.14), base.darkened(0.42), 2))
	btn.add_theme_color_override("font_color", C_TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", C_TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", C_TEXT_DARK)


func _nav_btn(label: String, pos: Vector2, btn_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.position = pos
	btn.size = btn_size
	btn.focus_mode = FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	_apply_btn_style(btn, C_WIN_BG)
	return btn
