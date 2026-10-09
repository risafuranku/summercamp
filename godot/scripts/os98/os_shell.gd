extends Control

## The camp computer: "Okna 98" on a Camptronics Fieldware PC, at 640x480.
##
## A forgotten office machine in a forest camp, used for the real work (bookings, the
## power bill, the guest register, planning the site in Builder) and, slowly, for finding
## out where you are (the web, Vera's files, what is in the Recycle Bin).
##
## It is deliberately empty: CampMail, Beeternet, Notepad, Mines, My Computer and the
## Recycle Bin. Builder 98, CampStat and GuestRack have to be downloaded from period web
## sites and installed with their setup programs.
##
## Contract with the rest of the game (kept from the old shell, building_interior.gd and
## quest_manager.gd call it): setup(), open_panel(), close_panel(), is_open(),
## is_desktop_ready(), power_off(), set_is_day(), refresh_from_state(),
## export_persistent_state(), import_persistent_state(), signal desktop_ready,
## _is_program_unlocked(), _on_program_installed(), _open_email_app(),
## _open_guestrack_app(), wants_keyboard().

signal desktop_ready

const T = preload("res://scripts/os98/os_theme.gd")
const WINDOW = preload("res://scripts/os98/os_window.gd")
const FILES = preload("res://scripts/os98/os_files.gd")
const ICON_DIR := "res://assets/textury/os98/icons/"
const SFX_DIR := "res://assets/sfx/os98/"
const SCREEN := Vector2(640, 480)
const TASKBAR_H := 28
const DESKTOP_SIZE := Vector2(640, 452)
const WALLPAPER := "res://assets/textury/crt/UI/bios/wallpaper.png"
const OEM_SPLASH := "res://assets/textury/crt/UI/bios/ChatGPT Image 15. 2. 2026 14_22_04.png"
const BIOS_FONT: FontFile = preload("res://assets/fonts/pomono.fnt")

## Programs: title, icon, window size, app script, whether it is there from the start.
const APPS := {
	"mycomputer": {"title": "My Computer", "icon": "computer", "size": Vector2(430, 300), "script": "folder_app", "base": true},
	"folder": {"title": "Exploring", "icon": "folder", "size": Vector2(430, 300), "script": "folder_app", "base": true},
	"bin": {"title": "Recycle Bin", "icon": "bin", "size": Vector2(400, 260), "script": "folder_app", "base": true},
	"mail": {"title": "CampMail", "icon": "mail", "size": Vector2(612, 420), "script": "mail_app", "base": true, "max": true},
	"browser": {"title": "Beeternet Explorer", "icon": "browser", "size": Vector2(620, 436), "script": "browser_app", "base": true, "max": true},
	"notepad": {"title": "Notepad", "icon": "notepad", "size": Vector2(452, 320), "script": "notepad_app", "base": true, "max": true},
	"mines": {"title": "Mines", "icon": "mines", "size": Vector2(180, 248), "script": "mines_app", "base": true},
	"builder": {"title": "Builder 98", "icon": "builder", "size": Vector2(640, 452), "script": "builder_app", "base": false, "max": true},
	"camp_status": {"title": "CampStat 98", "icon": "campstat", "size": Vector2(600, 410), "script": "campstat_app", "base": false, "max": true},
	"guestrack": {"title": "GuestRack 98", "icon": "guestrack", "size": Vector2(620, 420), "script": "guestrack_app", "base": false, "max": true},
	"setup": {"title": "Setup", "icon": "setup", "size": Vector2(470, 330), "script": "setup_app", "base": true},
	"download": {"title": "File Download", "icon": "browser", "size": Vector2(360, 196), "script": "download_app", "base": true},
	"imageview": {"title": "Image Viewer", "icon": "image", "size": Vector2(360, 300), "script": "image_app", "base": true},
}
const PROGRAM_MENU := ["browser", "mail", "notepad", "mines", "builder", "camp_status", "guestrack"]
const DESKTOP_ICONS := [
	["mycomputer", "My Computer", "computer"],
	["bin", "Recycle Bin", "bin"],
	["mail", "CampMail", "mail"],
	["browser", "Beeternet", "browser"],
	["vera", "Documents", "documents"],
	["downloads", "Download", "folder"],
	["builder", "Builder 98", "builder"],
	["camp_status", "CampStat", "campstat"],
	["guestrack", "GuestRack", "guestrack"],
]
const DOWNLOAD_SIZES_KB := {"BLDR98SW.EXE": 96, "CAMPSTAT.EXE": 48, "GUESTRAK.EXE": 72}
const INSTALLERS := {"BLDR98SW.EXE": "builder", "CAMPSTAT.EXE": "camp_status", "GUESTRAK.EXE": "guestrack"}

enum Boot { OFF, BIOS, SPLASH, DESKTOP, SAFE_OFF }

var _state := Boot.OFF
var _open := false
var _is_day := true
var _unlocked: Dictionary = {}
var _downloads: Array = []
var _bin: Array = FILES.BIN_START.duplicate()
var _restored: Array = []
var _online := false
var _grid_mgr
var _building_mgr
var _host: Node

var _desktop: Control
var _icons_layer: Control
var _windows: Control
var _taskbar: Control
var _start_btn: Button
var _task_box: HBoxContainer
var _clock: Label
var _tray_mail: TextureRect
var _tray_net: TextureRect
var _start_menu: Control
var _boot: Control
var _cursor: Control
var _ups: Control
var _ups_label: Label
var _boot_t := 0.0
var _boot_lines: Array[String] = []
var _icon_cache: Dictionary = {}
var _task_buttons: Dictionary = {}   # window -> Button
var _selected_icon: Control
var _busy := 0
var _sfx: AudioStreamPlayer
var _sfx_loop: AudioStreamPlayer
var _poll := 0.0
var _mouse := SCREEN * 0.5
var _flash_mail := 0.0
# Held here: a texture loaded inside a draw callback is freed before it is drawn.
var _wallpaper_tex: Texture2D = load(WALLPAPER) if ResourceLoader.exists(WALLPAPER) else null
var _splash_tex: Texture2D = load(OEM_SPLASH) if ResourceLoader.exists(OEM_SPLASH) else null


func _ready() -> void:
	theme = T.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# Pixels stay pixels: bevels, icons and the bitmap fonts are drawn 1:1.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in APPS:
		_unlocked[id] = bool(APPS[id].get("base", false))
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_sfx_loop = AudioStreamPlayer.new()
	add_child(_sfx_loop)
	_build_desktop()
	_build_taskbar()
	_build_start_menu()
	_build_ups()
	_boot = Control.new()
	_boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot.mouse_filter = Control.MOUSE_FILTER_STOP
	_boot.draw.connect(_draw_boot)
	add_child(_boot)
	_cursor = Control.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cursor.draw.connect(_draw_cursor)
	_cursor.z_index = 100
	add_child(_cursor)
	# Installed from elsewhere (tools, the old wizard): show it here too.
	EventBus.program_installed.connect(func(id: String):
		if APPS.has(id) and not _is_program_unlocked(id):
			install_program(id, false)
	)
	if EmailManager != null:
		EmailManager.email_received.connect(_on_email_received)
		EmailManager.unread_count_changed.connect(func(_c): _refresh_tray())
	_apply_state()


# ── contract with the game ───────────────────────────────────────────────────

func setup(grid_mgr, building_mgr, _ui_adapter = null, interior_host: Node = null) -> void:
	_grid_mgr = grid_mgr
	_building_mgr = building_mgr
	_host = interior_host


func open_panel() -> bool:
	_open = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if _state == Boot.OFF or _state == Boot.SAFE_OFF:
		_start_boot()
	elif _state == Boot.DESKTOP:
		desktop_ready.emit.call_deferred()
	return true


func close_panel() -> void:
	_open = false
	_close_start_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_open() -> bool:
	return _open


func is_desktop_ready() -> bool:
	return _state == Boot.DESKTOP


func power_off() -> void:
	for w in _windows.get_children():
		_close_window(w)
	_state = Boot.OFF
	_online = false
	_apply_state()


func set_is_day(is_day: bool) -> void:
	var nightfall := _is_day and not is_day
	_is_day = is_day
	if nightfall and _windows != null:
		for w in _windows.get_children():
			if w.app_id == "builder":
				_close_window(w)
				message_box("Builder 98", "Builder 98 has been closed.\n\nThe site licence permits use between 06:30 and 20:00 only.", "warning")


func refresh_from_state(_state_dict: Dictionary = {}) -> void:
	for w in _windows.get_children():
		var app = w.content.get_child(0) if w.content.get_child_count() > 0 else null
		if app != null and app.has_method("refresh"):
			app.refresh()


## A text field has focus: keys (including S) belong to the computer.
func wants_keyboard() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func export_persistent_state() -> Dictionary:
	return {
		"os": "okna98",
		"unlock_registry": _unlocked.duplicate(),
		"downloads": _downloads.duplicate(),
		"bin": _bin.duplicate(),
		"restored": _restored.duplicate(),
		"monitor_powered": _state == Boot.DESKTOP,
	}


func import_persistent_state(data: Dictionary) -> void:
	for id in APPS:
		_unlocked[id] = bool(APPS[id].get("base", false))
	_downloads.clear()
	_bin = FILES.BIN_START.duplicate()
	_restored.clear()
	if not data.is_empty():
		var reg: Dictionary = data.get("unlock_registry", {}) if data.get("unlock_registry", {}) is Dictionary else {}
		for id in ["builder", "camp_status", "guestrack"]:
			if bool(reg.get(id, false)):
				_unlocked[id] = true
		if str(data.get("os", "")) == "okna98":
			for f in data.get("downloads", []):
				_downloads.append(str(f))
			_bin = []
			for f in data.get("bin", []):
				_bin.append(str(f))
			for f in data.get("restored", []):
				_restored.append(str(f))
	for w in _windows.get_children():
		_close_window(w)
	_state = Boot.OFF
	_apply_state()
	_refresh_desktop_icons()


func _is_program_unlocked(app_id: String) -> bool:
	return bool(_unlocked.get(app_id, false))


## Installs straight away (tools, old saves); the player goes through setup_app.
func _on_program_installed(app_id: String) -> void:
	install_program(app_id, false)


func _open_email_app() -> void:
	open_app("mail")


func _open_guestrack_app() -> void:
	open_app("guestrack")


func _open_builder_app() -> void:
	open_app("builder")


# ── services for the apps ─────────────────────────────────────────────────────

func main_node() -> Node:
	var cur: Node = _host
	while cur != null:
		if cur.has_method("get_electricity_ui_snapshot"):
			return cur
		cur = cur.get_parent()
	return get_tree().current_scene if get_tree() != null else null


func is_day() -> bool:
	return _is_day


func icon(name: String, small := false) -> Texture2D:
	var key := name + ("_16" if small else "")
	if _icon_cache.has(key):
		return _icon_cache[key]
	var path := ICON_DIR + key + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		tex = _fallback_icon(16 if small else 32)
	_icon_cache[key] = tex
	return tex


func play(name: String, volume_db := 0.0) -> void:
	var path := SFX_DIR + name + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db + _distance_db()
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Heard from across the room or outside: the computer is a place too.
func _distance_db() -> float:
	if _open:
		return 0.0
	if _host != null and _host.has_method("get_radio_notification_volume_db"):
		return clampf(float(_host.get_radio_notification_volume_db()) + 8.0, -60.0, 0.0)
	return -20.0


func set_busy(on: bool) -> void:
	_busy = maxi(0, _busy + (1 if on else -1))
	_cursor.queue_redraw()


func is_online() -> bool:
	return _online


func set_online(on: bool) -> void:
	_online = on
	_refresh_tray()


func downloads() -> Array:
	return _downloads


func bin_items() -> Array:
	return _bin


## Files in a folder of the disk, including what was downloaded and installed.
func list_dir(path: String) -> Array:
	if path == "My Computer":
		return ["3 1/2 Floppy (A:)", "(C:)"]
	if path == "BIN":
		return _bin.duplicate()
	var out: Array = (FILES.DIRS.get(path, []) as Array).duplicate()
	if path == "C:\\DOWNLOAD":
		out.append_array(_downloads)
	if path == "C:\\VERA":
		out.append_array(_restored)
	if path == "C:\\PROGRAM FILES":
		for id in FILES.PROGRAM_DIRS:
			if _is_program_unlocked(id):
				out.append(FILES.PROGRAM_DIRS[id][0])
	for id in FILES.PROGRAM_DIRS:
		if path == "C:\\PROGRAM FILES\\" + FILES.PROGRAM_DIRS[id][0] and _is_program_unlocked(id):
			out.append_array(FILES.PROGRAM_DIRS[id][1])
	return out


func is_dir(path: String) -> bool:
	if FILES.is_dir(path):
		return true
	for id in FILES.PROGRAM_DIRS:
		if path == "C:\\PROGRAM FILES\\" + FILES.PROGRAM_DIRS[id][0] and _is_program_unlocked(id):
			return true
	return false


## Double-click on a file anywhere.
func open_file(dir: String, name: String) -> void:
	var full := dir.trim_suffix("\\") + "\\" + name
	if dir == "My Computer":
		if name.begins_with("3 1/2"):
			play("ding")
			message_box("A:\\", "A:\\ is not accessible.\n\nThe device is not ready.", "error", ["Retry", "Cancel"])
		else:
			open_app("folder", {"path": "C:\\"})
		return
	if dir == "BIN":
		message_box("Recycle Bin", "%s is in the Recycle Bin.\nRestore it to its original place (C:\\VERA)?" % name, "question", ["Yes", "No"], func(b: String):
			if b == "Yes":
				_bin.erase(name)
				_restored.append(name)
				_refresh_desktop_icons()
				_refresh_folders()
		)
		return
	if is_dir(full):
		open_app("folder", {"path": full})
		return
	if INSTALLERS.has(name):
		open_app("setup", {"program": INSTALLERS[name], "file": name})
		return
	match FILES.file_kind(name):
		"text":
			open_app("notepad", {"file": name})
		"exe":
			var app := str(FILES.EXE_APPS.get(name, ""))
			if app.is_empty():
				message_box(name, "This program cannot be run in Okna mode.", "error")
			else:
				open_app(app)
		"image":
			open_app("imageview", {"file": name})
		_:
			message_box(name, "This file is used by the system or another program\nand cannot be opened.", "warning")


## The browser asks for a file: a download window runs, the file lands in C:\DOWNLOAD.
func start_download(file: String, from_url: String) -> void:
	if _downloads.has(file):
		message_box("File Download", "%s already exists in C:\\DOWNLOAD.\n\nOpen the Download folder?" % file, "question", ["Yes", "No"], func(b: String):
			if b == "Yes":
				open_app("folder", {"path": "C:\\DOWNLOAD"})
		)
		return
	open_app("download", {"file": file, "url": from_url, "kb": int(DOWNLOAD_SIZES_KB.get(file, 40))}, true)


func finish_download(file: String) -> void:
	if not _downloads.has(file):
		_downloads.append(file)
	if EventBus.has_signal("file_downloaded"):
		EventBus.file_downloaded.emit(file)
	_refresh_folders()


func install_program(app_id: String, from_setup := true) -> void:
	if _is_program_unlocked(app_id):
		return
	_unlocked[app_id] = true
	# The setup file goes in the bin, like everyone did.
	for f in INSTALLERS:
		if INSTALLERS[f] == app_id and _downloads.has(f) and from_setup:
			_downloads.erase(f)
			if not _bin.has(f):
				_bin.append(f)
	_refresh_desktop_icons()
	_refresh_folders()
	if EventBus.has_signal("program_installed"):
		EventBus.program_installed.emit(app_id)


## A small dialog. kind: info / warning / error / question. `cb` gets the button text.
func message_box(p_title: String, text: String, kind := "info", buttons := ["OK"], cb: Callable = Callable()) -> void:
	var lines := text.split("\n")
	var w := 0.0
	for l in lines:
		w = maxf(w, T.FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x)
	var box_size := Vector2(clampf(w + 90, 220, 520), clampf(lines.size() * 14 + 92, 120, 400))
	var win = _make_window("msg", p_title, null, Rect2((SCREEN - box_size) * 0.5 - Vector2(0, 20), box_size))
	win.can_minimize = false
	var c: Control = win.content
	var ic := TextureRect.new()
	ic.texture = _dialog_icon(kind)
	ic.position = Vector2(12, 12)
	c.add_child(ic)
	var label := Label.new()
	label.text = text
	label.position = Vector2(56, 14)
	label.size = Vector2(box_size.x - 70, box_size.y - 80)
	c.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(0, win.client_size().y - 32)
	row.size = Vector2(win.client_size().x, 24)
	c.add_child(row)
	for b in buttons:
		var btn := Button.new()
		btn.text = b
		btn.custom_minimum_size = Vector2(75, 23)
		btn.pressed.connect(func():
			_close_window(win)
			if cb.is_valid():
				cb.call(b)
		)
		row.add_child(btn)
	win.close_requested.connect(func():
		_close_window(win)
		if cb.is_valid():
			cb.call(buttons[buttons.size() - 1])
	)
	_activate(win)
	if kind == "error" or kind == "warning":
		play("ding")


# ── windows ──────────────────────────────────────────────────────────────────

## Opens (or brings forward) a program. Returns the window, or null if refused.
func open_app(app_id: String, args: Dictionary = {}, new_instance := false) -> Control:
	if _state != Boot.DESKTOP:
		return null
	_close_start_menu()
	match app_id:
		"downloads":
			return open_app("folder", {"path": "C:\\DOWNLOAD"})
		"vera":
			return open_app("folder", {"path": "C:\\VERA"})
	if not APPS.has(app_id):
		return null
	if not _is_program_unlocked(app_id):
		message_box("Okna", "Cannot find '%s'.\nMake sure the program is installed." % APPS[app_id]["title"], "error")
		return null
	if app_id == "builder" and not _is_day:
		message_box("Builder 98", "Builder 98 cannot be started now.\n\nThe site licence for recreational facilities permits\nuse between 06:30 and 20:00 only.", "warning")
		return null
	var single := app_id in ["mail", "browser", "builder", "camp_status", "guestrack", "mines", "bin", "mycomputer"]
	if single and not new_instance:
		for w in _windows.get_children():
			if w.app_id == app_id:
				_restore(w)
				var a = w.content.get_child(0) if w.content.get_child_count() > 0 else null
				if a != null and a.has_method("reopen"):
					a.reopen(args)
				return w
	var info: Dictionary = APPS[app_id]
	var sz: Vector2 = info["size"]
	var n := _windows.get_child_count()
	var pos := Vector2(40 + (n % 6) * 22, 24 + (n % 6) * 18)
	if pos.x + sz.x > SCREEN.x:
		pos.x = maxf(0.0, SCREEN.x - sz.x)
	if pos.y + sz.y > DESKTOP_SIZE.y:
		pos.y = maxf(0.0, DESKTOP_SIZE.y - sz.y)
	var win = _make_window(app_id, str(info["title"]), icon(str(info["icon"]), true), Rect2(pos, sz))
	win.can_maximize = bool(info.get("max", false))
	var script: Script = load("res://scripts/os98/apps/%s.gd" % info["script"])
	var app = script.new()
	win.content.add_child(app)
	app.size = win.client_size()
	win.resized.connect(func(): app.size = win.client_size())
	if app.has_method("setup"):
		app.setup(self, win, args)
	if app_id == "builder":
		win.set_maximized(true)
	_add_task_button(win)
	_activate(win)
	play("click", -8.0)
	return win


func close_app_window(win: Control) -> void:
	_close_window(win)


func _make_window(app_id: String, p_title: String, p_icon: Texture2D, rect: Rect2) -> Control:
	var win = WINDOW.new()
	_windows.add_child(win)
	win.setup(app_id, p_title, p_icon, rect, DESKTOP_SIZE)
	win.close_requested.connect(func(): _close_window(win))
	win.minimize_requested.connect(func(): _minimize(win))
	win.activated.connect(func(): _activate(win))
	return win


func _close_window(win: Control) -> void:
	if win == null or not is_instance_valid(win):
		return
	var app = win.content.get_child(0) if win.content.get_child_count() > 0 else null
	if app != null and app.has_method("closing"):
		app.closing()
	if _task_buttons.has(win):
		_task_buttons[win].queue_free()
		_task_buttons.erase(win)
	win.queue_free()
	_activate_top.call_deferred()


func _minimize(win: Control) -> void:
	win.visible = false
	_activate_top()


func _restore(win: Control) -> void:
	win.visible = true
	_activate(win)


func _activate(win: Control) -> void:
	if win == null or not is_instance_valid(win):
		return
	win.move_to_front()
	for w in _windows.get_children():
		w.active = (w == win)
	for w in _task_buttons:
		if is_instance_valid(w):
			_task_buttons[w].button_pressed = (w == win and w.visible)


func _activate_top() -> void:
	var kids := _windows.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var w = kids[i]
		if is_instance_valid(w) and w.visible and not w.is_queued_for_deletion():
			_activate(w)
			return
	for w in _task_buttons:
		_task_buttons[w].button_pressed = false


func _add_task_button(win: Control) -> void:
	if win.app_id == "msg":
		return
	var b := Button.new()
	b.toggle_mode = true
	b.text = win.title
	b.icon = win.icon
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(150, 22)
	b.add_theme_font_override("font", T.FONT_BOLD)
	b.pressed.connect(func():
		if win.visible and win.active:
			_minimize(win)
		else:
			_restore(win)
	)
	_task_box.add_child(b)
	_task_buttons[win] = b
	_fit_task_buttons()


func _fit_task_buttons() -> void:
	var n := maxi(1, _task_buttons.size())
	var room := _task_box.size.x if _task_box.size.x > 0 else 470.0
	var w := clampf((room - (n - 1) * 3) / n, 40, 150)
	for win in _task_buttons:
		_task_buttons[win].custom_minimum_size = Vector2(w, 22)


func _refresh_folders() -> void:
	for w in _windows.get_children():
		var app = w.content.get_child(0) if w.content.get_child_count() > 0 else null
		if app != null and app.has_method("refresh_listing"):
			app.refresh_listing()


# ── boot ─────────────────────────────────────────────────────────────────────

func _start_boot() -> void:
	_state = Boot.BIOS
	_boot_t = 0.0
	_boot_lines.clear()
	_apply_state()
	play("power_on", -4.0)


func _process(delta: float) -> void:
	match _state:
		Boot.BIOS:
			_tick_bios(delta)
		Boot.SPLASH:
			_boot_t += delta
			_boot.queue_redraw()
			if _boot_t >= 3.2:
				_enter_desktop()
		Boot.DESKTOP:
			_tick_desktop(delta)
	_cursor.queue_redraw()


func _tick_bios(delta: float) -> void:
	_boot_t += delta
	var script := [
		[0.0, "Camptronics FieldBIOS v2.03 (C) 1994-97 Camptronics Fieldware"],
		[0.1, ""],
		[0.2, "CPU : Pentium-S 133 MHz"],
		[0.3, "MEMTEST"],
		[1.6, ""],
		[1.7, "Detecting IDE Primary Master ... QUANTUM FIREBALL 1080A"],
		[2.1, "Detecting IDE Primary Slave  ... None"],
		[2.3, "Detecting IDE Secondary Master... CAMPCD 24X"],
		[2.6, "Detecting COM3 ... no response"],
		[2.9, ""],
		[3.0, "Starting Okna 98..."],
	]
	var lines: Array[String] = []
	for row in script:
		if _boot_t >= float(row[0]):
			if str(row[1]) == "MEMTEST":
				var kb := mini(16384, int((_boot_t - 0.3) / 1.2 * 16384.0))
				lines.append("Memory Test : %6dK %s" % [kb, "OK" if kb >= 16384 else ""])
			else:
				lines.append(str(row[1]))
	_boot_lines = lines
	_boot.queue_redraw()
	if _boot_t > 1.7 and _boot_t - delta <= 1.7:
		play("hdd", -6.0)
	if _boot_t >= 3.6:
		_state = Boot.SPLASH
		_boot_t = 0.0
		_apply_state()


func _enter_desktop() -> void:
	_state = Boot.DESKTOP
	_apply_state()
	_refresh_desktop_icons()
	play("startup", -6.0)
	desktop_ready.emit()
	# CampMail is in the startup group (OKNA.INI: run=CAMPMAIL.EXE).
	if EmailManager != null and EmailManager.get_unread_count() > 0:
		get_tree().create_timer(0.8).timeout.connect(func():
			if _state == Boot.DESKTOP:
				open_app("mail")
		)


func _apply_state() -> void:
	var desk := _state == Boot.DESKTOP
	_desktop.visible = desk
	_windows.visible = desk
	_taskbar.visible = desk
	_boot.visible = not desk
	_boot.queue_redraw()


func _draw_boot() -> void:
	_boot.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color.BLACK)
	match _state:
		Boot.BIOS:
			var y := 24.0
			for l in _boot_lines:
				_boot.draw_string(BIOS_FONT, Vector2(16, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(170, 170, 170))
				y += 16
			_boot.draw_string(BIOS_FONT, Vector2(16, 462), "Press DEL to enter SETUP", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(170, 170, 170))
			# Energy star style badge, top right: two words in a box.
			_boot.draw_rect(Rect2(520, 16, 104, 40), Color8(0, 120, 60), false, 2.0)
			_boot.draw_string(BIOS_FONT, Vector2(530, 34), "FIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(0, 170, 90))
			_boot.draw_string(BIOS_FONT, Vector2(530, 50), "  STAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(0, 170, 90))
		Boot.SPLASH:
			var tex := _splash_tex
			if tex != null:
				var s := tex.get_size()
				var k := minf(SCREEN.x / s.x, SCREEN.y / s.y)
				var d := s * k
				_boot.draw_texture_rect(tex, Rect2((SCREEN - d) * 0.5, d), false)
				# The bar inside the splash art's own frame; it moves in fits and starts.
				var p := clampf(_boot_t / 3.0, 0.0, 1.0)
				p = floorf(p * 12.0) / 12.0
				var origin := (SCREEN - d) * 0.5
				var bar := Rect2(origin + Vector2(329, 693) * k, Vector2(590, 24) * k)
				_boot.draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)).abs(), Color8(230, 160, 50))
		Boot.SAFE_OFF:
			var msg := "It is now safe to turn off\n     your computer."
			var y2 := 220.0
			for l in msg.split("\n"):
				_boot.draw_string(T.FONT_BOLD, Vector2(220, y2), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 * 2, Color8(255, 140, 0))
				y2 += 30


# ── desktop ──────────────────────────────────────────────────────────────────

func _build_desktop() -> void:
	_desktop = Control.new()
	_desktop.size = SCREEN
	_desktop.mouse_filter = Control.MOUSE_FILTER_STOP
	_desktop.draw.connect(func():
		_desktop.draw_rect(Rect2(Vector2.ZERO, SCREEN), T.DESKTOP)
		var tex := _wallpaper_tex
		if tex != null:
			var s := tex.get_size()
			var k := maxf(SCREEN.x / s.x, DESKTOP_SIZE.y / s.y)
			var d := s * k
			_desktop.draw_texture_rect(tex, Rect2((DESKTOP_SIZE - d) * 0.5, d), false, Color(0.92, 0.92, 0.92))
	)
	_desktop.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_select_icon(null)
			_close_start_menu()
	)
	add_child(_desktop)
	_icons_layer = Control.new()
	_icons_layer.size = DESKTOP_SIZE
	_icons_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop.add_child(_icons_layer)
	_windows = Control.new()
	_windows.size = DESKTOP_SIZE
	_windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_windows)


func _refresh_desktop_icons() -> void:
	for c in _icons_layer.get_children():
		c.queue_free()
	var i := 0
	for row in DESKTOP_ICONS:
		var id := str(row[0])
		if APPS.has(id) and not _is_program_unlocked(id):
			continue
		var ic_name := str(row[2])
		if id == "bin" and not _bin.is_empty():
			ic_name = "bin_full"
		var col := int(i / 6)
		var pos := Vector2(8 + col * 76, 8 + (i % 6) * 70)
		_icons_layer.add_child(_make_desktop_icon(id, str(row[1]), icon(ic_name), pos))
		i += 1


func _make_desktop_icon(id: String, label: String, tex: Texture2D, pos: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = Vector2(72, 62)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("selected", false)
	c.draw.connect(func():
		var sel := bool(c.get_meta("selected"))
		c.draw_texture(tex, Vector2(20, 2), Color(0.6, 0.6, 1.0) if sel else Color.WHITE)
		var tw := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var tx := floorf((72 - tw) * 0.5)
		if sel:
			c.draw_rect(Rect2(tx - 2, 38, tw + 4, 14), T.NAVY)
		else:
			c.draw_string(T.FONT, Vector2(tx + 1, 50), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color(0, 0, 0, 0.8))
		c.draw_string(T.FONT, Vector2(tx, 49), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_start_menu()
			_select_icon(c)
			if e.double_click:
				play("click", -10.0)
				open_app(id)
			c.accept_event()
	)
	return c


func _select_icon(c: Control) -> void:
	if _selected_icon != null and is_instance_valid(_selected_icon):
		_selected_icon.set_meta("selected", false)
		_selected_icon.queue_redraw()
	_selected_icon = c
	if c != null:
		c.set_meta("selected", true)
		c.queue_redraw()


func _tick_desktop(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 1.0
		var m := main_node()
		if m != null and m.has_method("_time_of_day_string"):
			_clock.text = str(m.call("_time_of_day_string"))
		_refresh_ups(m)
	for w in _task_buttons:
		if is_instance_valid(w) and _task_buttons[w].text != w.title:
			_task_buttons[w].text = w.title
	if _flash_mail > 0.0:
		_flash_mail -= delta
		_tray_mail.modulate = Color.WHITE if fmod(_flash_mail, 0.6) > 0.3 else Color(1, 1, 1, 0.2)


# ── taskbar and start menu ───────────────────────────────────────────────────

func _build_taskbar() -> void:
	_taskbar = Panel.new()
	_taskbar.position = Vector2(0, SCREEN.y - TASKBAR_H)
	_taskbar.size = Vector2(SCREEN.x, TASKBAR_H)
	_taskbar.add_theme_stylebox_override("panel", T.box("thin_raised", T.FACE, Vector4.ZERO))
	add_child(_taskbar)
	_start_btn = Button.new()
	_start_btn.text = "Start"
	_start_btn.icon = _start_logo()
	_start_btn.toggle_mode = true
	_start_btn.add_theme_font_override("font", T.FONT_BOLD)
	_start_btn.position = Vector2(2, 3)
	_start_btn.size = Vector2(56, 22)
	_start_btn.pressed.connect(func():
		if _start_menu.visible:
			_close_start_menu()
		else:
			_open_start_menu()
	)
	_taskbar.add_child(_start_btn)
	_task_box = HBoxContainer.new()
	_task_box.position = Vector2(64, 3)
	_task_box.size = Vector2(470, 22)
	_task_box.add_theme_constant_override("separation", 3)
	_taskbar.add_child(_task_box)
	var tray := Panel.new()
	tray.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4.ZERO))
	tray.position = Vector2(SCREEN.x - 96, 3)
	tray.size = Vector2(94, 22)
	_taskbar.add_child(tray)
	_clock = Label.new()
	_clock.text = "09:00"
	_clock.position = Vector2(54, 4)
	tray.add_child(_clock)
	_tray_mail = TextureRect.new()
	_tray_mail.position = Vector2(6, 3)
	_tray_mail.texture = icon("mail", true)
	_tray_mail.tooltip_text = "You have new mail."
	_tray_mail.visible = false
	_tray_mail.mouse_filter = Control.MOUSE_FILTER_STOP
	_tray_mail.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.double_click:
			open_app("mail")
	)
	tray.add_child(_tray_mail)
	_tray_net = TextureRect.new()
	_tray_net.position = Vector2(28, 3)
	_tray_net.texture = _net_icon()
	_tray_net.tooltip_text = "Connected to Bohemia Online at 33,600 bps"
	_tray_net.visible = false
	tray.add_child(_tray_net)


func _refresh_tray() -> void:
	var unread := EmailManager.get_unread_count() if EmailManager != null else 0
	_tray_mail.visible = unread > 0
	_tray_mail.tooltip_text = "You have %d unread message(s)." % unread
	_tray_net.visible = _online


func _on_email_received(_mail: Dictionary) -> void:
	_refresh_tray()
	_flash_mail = 4.0
	play("mail", -6.0)
	for w in _windows.get_children():
		if w.app_id == "mail":
			var app = w.content.get_child(0)
			if app != null and app.has_method("refresh"):
				app.refresh()


func _build_start_menu() -> void:
	_start_menu = Control.new()
	_start_menu.visible = false
	_start_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_start_menu)


func _open_start_menu() -> void:
	for c in _start_menu.get_children():
		c.queue_free()
	var entries := [
		["programs", "Programs", "folder", true],
		["documents", "Documents", "documents", true],
		["-", "", "", false],
		["help", "Help", "help", false],
		["run", "Run...", "run", false],
		["-", "", "", false],
		["shutdown", "Shut Down...", "shutdown", false],
	]
	var h := 6
	for e in entries:
		h += 8 if e[0] == "-" else 30
	var panel := _menu_panel(Vector2(0, SCREEN.y - TASKBAR_H - h), Vector2(166, h), true)
	_start_menu.add_child(panel)
	var y := 3
	for e in entries:
		if e[0] == "-":
			var sep := ColorRect.new()
			sep.color = T.SHADOW
			sep.position = Vector2(26, y + 3)
			sep.size = Vector2(136, 1)
			panel.add_child(sep)
			var sep2 := ColorRect.new()
			sep2.color = T.WHITE
			sep2.position = Vector2(26, y + 4)
			sep2.size = Vector2(136, 1)
			panel.add_child(sep2)
			y += 8
			continue
		var item := _menu_item(str(e[1]), icon(str(e[2])), Vector2(24, y), Vector2(139, 30), bool(e[3]), 32)
		panel.add_child(item)
		var id := str(e[0])
		item.mouse_entered.connect(func():
			_close_submenu()
			if id == "programs":
				_open_submenu(_program_entries(), Vector2(166, item.global_position.y - 3))
			elif id == "documents":
				_open_submenu(_document_entries(), Vector2(166, item.global_position.y - 3))
		)
		item.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_start_action(id)
		)
		y += 30
	_start_menu.visible = true
	_start_btn.button_pressed = true
	_start_menu.move_to_front()
	_cursor.move_to_front()


func _close_start_menu() -> void:
	if _start_menu == null:
		return
	_start_menu.visible = false
	if _start_btn != null:
		_start_btn.button_pressed = false
	_close_submenu()


var _submenu: Control


func _open_submenu(entries: Array, at: Vector2) -> void:
	_close_submenu()
	var h := entries.size() * 20 + 6
	at.y = minf(at.y, SCREEN.y - TASKBAR_H - h)
	_submenu = _menu_panel(at, Vector2(170, h), false)
	_start_menu.add_child(_submenu)
	var y := 3
	for e in entries:
		var item := _menu_item(str(e[1]), icon(str(e[2]), true), Vector2(3, y), Vector2(164, 20), false, 16)
		_submenu.add_child(item)
		var action: Callable = e[0]
		item.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_close_start_menu()
				action.call()
		)
		y += 20


func _close_submenu() -> void:
	if _submenu != null and is_instance_valid(_submenu):
		_submenu.queue_free()
	_submenu = null


func _program_entries() -> Array:
	var out: Array = []
	for id in PROGRAM_MENU:
		if _is_program_unlocked(id):
			var app_id: String = id
			out.append([func(): open_app(app_id), APPS[id]["title"], APPS[id]["icon"]])
	return out


func _document_entries() -> Array:
	var out: Array = []
	for f in list_dir("C:\\VERA"):
		var name: String = f
		out.append([func(): open_file("C:\\VERA", name), name, "txt"])
	return out


func _start_action(id: String) -> void:
	match id:
		"help":
			_close_start_menu()
			message_box("Okna Help", "Help is not installed.\n\nInsert the Okna 98 CD-ROM and try again.", "info")
		"run":
			_close_start_menu()
			_open_run_dialog()
		"shutdown":
			_close_start_menu()
			message_box("Shut Down Okna", "Are you sure you want to shut down the computer?", "question", ["Yes", "No"], func(b: String):
				if b == "Yes":
					_shutdown()
			)


func _open_run_dialog() -> void:
	var win = _make_window("run", "Run", null, Rect2(Vector2(20, 300), Vector2(330, 130)))
	win.can_minimize = false
	var c: Control = win.content
	var ic := TextureRect.new()
	ic.texture = icon("run")
	ic.position = Vector2(8, 8)
	c.add_child(ic)
	var l := Label.new()
	l.text = "Type the name of a program, folder or document,\nand Okna will open it for you."
	l.position = Vector2(48, 8)
	c.add_child(l)
	var edit := LineEdit.new()
	edit.position = Vector2(48, 42)
	edit.size = Vector2(260, 22)
	c.add_child(edit)
	var ok := Button.new()
	ok.text = "OK"
	ok.position = Vector2(150, 72)
	ok.size = Vector2(75, 23)
	c.add_child(ok)
	var go := func():
		var cmd := edit.text.strip_edges().to_upper()
		_close_window(win)
		_run_command(cmd)
	ok.pressed.connect(go)
	edit.text_submitted.connect(func(_t): go.call())
	_activate(win)
	edit.grab_focus.call_deferred()


func _run_command(cmd: String) -> void:
	match cmd:
		"", "CANCEL":
			return
		"NOTEPAD", "NOTEPAD.EXE":
			open_app("notepad")
		"MINES", "MINES.EXE", "WINMINE":
			open_app("mines")
		"CAMPMAIL", "CAMPMAIL.EXE":
			open_app("mail")
		"BEETER", "BEETER.EXE", "BEETERNET":
			open_app("browser")
		"C:", "C:\\":
			open_app("folder", {"path": "C:\\"})
		"COMMAND", "COMMAND.COM", "CMD":
			message_box("COMMAND.COM", "Not enough memory to run COMMAND.COM.\n\nClose some programs and try again.", "error")
		_:
			if FILES.TEXTS.has(cmd):
				open_app("notepad", {"file": cmd})
			else:
				message_box(cmd, "Cannot find the file '%s' (or one of its components).\nMake sure the path and filename are correct." % cmd.to_lower(), "error")


func _shutdown() -> void:
	for w in _windows.get_children():
		_close_window(w)
	_online = false
	play("shutdown", -6.0)
	_state = Boot.SAFE_OFF
	_apply_state()


func _menu_panel(pos: Vector2, sz: Vector2, banner: bool) -> Control:
	var p := Control.new()
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.draw.connect(func():
		p.draw_style_box(T.box("window", T.FACE), Rect2(Vector2.ZERO, sz))
		if banner:
			for i in int(sz.y - 6):
				p.draw_rect(Rect2(3, 3 + i, 20, 1), T.SHADOW.lerp(T.NAVY, float(i) / sz.y))
			p.draw_set_transform(Vector2(18, sz.y - 8), -PI * 0.5)
			p.draw_string(T.FONT_BOLD, Vector2.ZERO, "Okna", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
			p.draw_string(T.FONT, Vector2(36, 0), "98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.LIGHT)
			p.draw_set_transform(Vector2.ZERO)
	)
	return p


func _menu_item(text: String, tex: Texture2D, pos: Vector2, sz: Vector2, arrow: bool, icon_px: int) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("hover", false)
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		c.queue_redraw()
	)
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		c.queue_redraw()
	)
	c.draw.connect(func():
		var hov := bool(c.get_meta("hover"))
		if hov:
			c.draw_rect(Rect2(Vector2.ZERO, sz), T.NAVY)
		if tex != null:
			c.draw_texture_rect(tex, Rect2(Vector2(4, (sz.y - icon_px) * 0.5), Vector2(icon_px, icon_px)), false)
		c.draw_string(T.FONT, Vector2(icon_px + 12, sz.y * 0.5 + 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE if hov else T.TEXT)
		if arrow:
			var ax := sz.x - 10
			var ay := sz.y * 0.5
			for k in 4:
				c.draw_rect(Rect2(ax + k, ay - 3 + k, 1, 7 - k * 2), T.WHITE if hov else T.TEXT)
	)
	return c


# ── UPS monitor (unpaid power bill) ──────────────────────────────────────────

func _build_ups() -> void:
	_ups = Panel.new()
	_ups.add_theme_stylebox_override("panel", T.box("window", T.FACE, Vector4(6, 4, 6, 4)))
	_ups.position = Vector2(170, 8)
	_ups.size = Vector2(300, 46)
	_ups.visible = false
	_ups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ups)
	_ups_label = Label.new()
	_ups_label.position = Vector2(10, 6)
	_ups_label.add_theme_color_override("font_color", Color8(160, 0, 0))
	_ups.add_child(_ups_label)


func _refresh_ups(m: Node) -> void:
	if m == null or not m.has_method("get_electricity_ui_snapshot"):
		_ups.visible = false
		return
	var snap: Dictionary = m.get_electricity_ui_snapshot()
	var on := bool(snap.get("power_cut_active", false)) and bool(snap.get("ups_active", false))
	_ups.visible = on
	if on:
		var sec := maxi(0, int(ceil(float(snap.get("ups_seconds_left", 0.0)))))
		_ups_label.text = "UPS MONITOR: mains power lost (bill overdue).\nBattery: %02d:%02d left. Pay the bill in CampStat." % [sec / 60, sec % 60]
		_ups.move_to_front()


# ── input, cursor ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = event.position
	# A click anywhere in a window brings it forward (children eat the event).
	if event is InputEventMouseButton and event.pressed and _state == Boot.DESKTOP:
		var kids := _windows.get_children()
		for i in range(kids.size() - 1, -1, -1):
			var w = kids[i]
			if w.visible and Rect2(w.position, w.size).has_point(event.position):
				if not w.active:
					_activate(w)
				break
		if _start_menu.visible and not _point_in_start_menu(event.position) and not Rect2(_start_btn.global_position, _start_btn.size).has_point(event.position):
			_close_start_menu()


func _point_in_start_menu(p: Vector2) -> bool:
	for c in _start_menu.get_children():
		if c is Control and Rect2(c.position, c.size).has_point(p):
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	# Clicks during boot do nothing (keys either).
	if _state != Boot.DESKTOP:
		accept_event()


const ARROW := [
	"X           ",
	"XX          ",
	"X.X         ",
	"X..X        ",
	"X...X       ",
	"X....X      ",
	"X.....X     ",
	"X......X    ",
	"X.......X   ",
	"X........X  ",
	"X.....XXXXX ",
	"X..X..X     ",
	"X.X X..X    ",
	"XX  X..X    ",
	"X    X..X   ",
	"     X..X   ",
	"      XX    ",
]
const HOURGLASS := [
	"XXXXXXXXXXX",
	"X.........X",
	" X.......X ",
	" X.XXXXX.X ",
	"  X.XXX.X  ",
	"   X.X.X   ",
	"    X.X    ",
	"   X...X   ",
	"  X..X..X  ",
	" X...X...X ",
	" X..XXX..X ",
	"X.XXXXXXX.X",
	"XXXXXXXXXXX",
]


func _draw_cursor() -> void:
	if not _open or _state != Boot.DESKTOP:
		return
	var pat: Array = HOURGLASS if (_busy > 0 or _state != Boot.DESKTOP) else ARROW
	var o := _mouse.floor()
	for y in pat.size():
		var row: String = pat[y]
		for x in row.length():
			var ch := row[x]
			if ch == "X":
				_cursor.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), T.DARK)
			elif ch == ".":
				_cursor.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), T.WHITE)


# ── small generated art ──────────────────────────────────────────────────────

func _start_logo() -> Texture2D:
	# A small pine tree in a window frame: the camp's "start" mark.
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var green := Color8(0, 128, 0)
	var dark := Color8(0, 80, 0)
	for y in range(2, 13):
		var half := int((y - 1) * 0.55)
		for x in range(8 - half, 8 + half + 1):
			img.set_pixel(x, y, green if (x + y) % 3 else dark)
	for y in range(13, 15):
		img.set_pixel(7, y, Color8(120, 70, 20))
		img.set_pixel(8, y, Color8(120, 70, 20))
	return ImageTexture.create_from_image(img)


func _net_icon() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for k in 2:
		var ox := 1 + k * 6
		var oy := 6 - k * 4
		for x in range(ox, ox + 8):
			for y in range(oy, oy + 6):
				var edge := x == ox or x == ox + 7 or y == oy or y == oy + 5
				img.set_pixel(x, y, T.DARK if edge else Color8(0, 128, 128))
		img.set_pixel(ox + 3, oy + 6, T.DARK)
		img.set_pixel(ox + 4, oy + 6, T.DARK)
	return ImageTexture.create_from_image(img)


func _dialog_icon(kind: String) -> Texture2D:
	var key := "dlg_" + kind
	if _icon_cache.has(key):
		return _icon_cache[key]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill := Color8(0, 0, 200)
	var glyph := "i"
	match kind:
		"error":
			fill = Color8(200, 0, 0)
			glyph = "x"
		"warning":
			fill = Color8(240, 210, 0)
			glyph = "!"
		"question":
			fill = Color8(0, 0, 200)
			glyph = "?"
	for y in 32:
		for x in 32:
			var inside := false
			if kind == "warning":
				inside = y >= 3 and y <= 28 and absf(x - 15.5) <= (y - 3) * 0.55
			else:
				inside = Vector2(x - 15.5, y - 15.5).length() <= 13.5
			if inside:
				img.set_pixel(x, y, fill)
	var ink := T.DARK if kind == "warning" else T.WHITE
	match glyph:
		"x":
			for i in range(9, 23):
				for w in 3:
					img.set_pixel(i + w - 1, i, ink)
					img.set_pixel(31 - i + w - 1, i, ink)
		"!":
			for y in range(11, 21):
				img.set_pixel(15, y, ink)
				img.set_pixel(16, y, ink)
			for y in range(23, 25):
				img.set_pixel(15, y, ink)
				img.set_pixel(16, y, ink)
		"?":
			var pts := [[13, 9], [14, 8], [15, 8], [16, 8], [17, 8], [18, 9], [19, 10], [19, 11], [18, 12], [17, 13], [16, 14], [16, 15], [16, 16], [16, 17]]
			for p in pts:
				img.set_pixel(p[0], p[1], ink)
				img.set_pixel(p[0] - 1, p[1], ink)
			for y in range(20, 22):
				img.set_pixel(15, y, ink)
				img.set_pixel(16, y, ink)
		_:
			for y in range(13, 24):
				img.set_pixel(15, y, ink)
				img.set_pixel(16, y, ink)
			for y in range(8, 10):
				img.set_pixel(15, y, ink)
				img.set_pixel(16, y, ink)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex


func _fallback_icon(px: int) -> Texture2D:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var m := px / 8
	for y in range(m, px - m):
		for x in range(m * 2, px - m * 2):
			var edge := x == m * 2 or x == px - m * 2 - 1 or y == m or y == px - m - 1
			img.set_pixel(x, y, T.DARK if edge else T.WHITE)
	return ImageTexture.create_from_image(img)
