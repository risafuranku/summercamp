extends Control

## The camp computer: "Okna 98" on a Camptronics Fieldware PC, at 640x480.
##
## Not a desktop to keep tidy: a panel (playtest 19. 10.: "not a full-size OS but a game
## panel that is a parody of one; above all practical, quick switching between Builder,
## CampStat and GuestRack"). The programs fill the screen above the taskbar, one at a
## time, and stay running behind it; the taskbar is a row of tabs, each with its key
## (1-9) and a badge when it wants you (unread mail, bills, a guest at the desk). The OS
## is in the look and the jokes: the boot, the Start button, the message boxes, the
## screen saver.
##
## Builder 98 and GuestRack 98 are not on the machine at first: their tab says where they
## come from and installs them with one click (the shareware sites on the web still offer
## them, and Vera's mail links to them). Jobs and Games take their programs the same way.
##
## Contract with the rest of the game (building_interior.gd, quest_manager.gd, main.gd,
## the tools): setup(), open_panel(), close_panel(), is_open(), is_desktop_ready(),
## power_off(), set_is_day(), refresh_from_state(), export_persistent_state(),
## import_persistent_state(), coop_pc_state(), coop_take_pc(), signal desktop_ready,
## _is_program_unlocked(), _on_program_installed(), install_program(), open_app() (returns
## the page; the program is `page.content.get_child(0)`), app_of(), _open_email_app(),
## _open_guestrack_app(), wants_keyboard(), play(), extras().

signal desktop_ready

const T = preload("res://scripts/os98/os_theme.gd")
const WINDOW = preload("res://scripts/os98/os_window.gd")
const PAGE = preload("res://scripts/os98/os_page.gd")
const FILES = preload("res://scripts/os98/os_files.gd")
const EXTRAS = preload("res://scripts/os98/os_extras.gd")
const PROGRESS = preload("res://scripts/os98/os_progress.gd")
const ICON_DIR := "res://assets/textury/os98/icons/"
const SFX_DIR := "res://assets/sfx/os98/"
const SCREEN := Vector2(640, 480)
## The taskbar is big and plain (playtest 19. 10.: "zvětšit taskbar, zjednodušit look ale
## zachovat vibe"): the programs' big icons, each tab only its icon, its key and its badge.
const TASKBAR_H := 46
const DESKTOP_SIZE := Vector2(640, 434)
## A new machine shows the autumn lake (the season the game is in).
const WALLPAPER := "res://assets/textury/os98/wall_autumn.png"
const OEM_SPLASH := "res://assets/textury/crt/UI/bios/ChatGPT Image 15. 2. 2026 14_22_04.png"
const BIOS_FONT: FontFile = preload("res://assets/fonts/pomono.fnt")

## The tabs, in key order: id, label, icon, wide (a label beside the icon).
const TABS := [
	["builder", "Builder", "builder", true],
	["camp_status", "CampStat", "campstat", true],
	["guestrack", "GuestRack", "guestrack", true],
	["mail", "Mail", "mail", true],
	["reviews", "Reviews", "goggle", true],
	["browser", "Web", "browser", false],
	["shops", "Shops", "shop_app", false],
	["jobs", "Jobs", "money", false],
	["games", "Games", "games", false],
	["files", "Files", "folder", false],
]
const TAB_SCRIPTS := {
	"builder": "builder_app", "camp_status": "campstat_app", "guestrack": "guestrack_app", "mail": "mail_app",
	"reviews": "goggle_app", "browser": "browser_app", "shops": "shops_app", "jobs": "jobs_app", "games": "games_app", "files": "files_app",
}
const TAB_TITLES := {
	"builder": "Builder 98", "camp_status": "CampStat 98", "guestrack": "GuestRack 98", "mail": "CampMail",
	"reviews": "Goggle Reviews - Beeternet Explorer", "browser": "Beeternet Explorer", "shops": "SoftSklad programs", "jobs": "Jobs from home", "games": "Games", "files": "Files",
}

## Everything that can be installed: its title, icon, the file it comes as, its size, the
## site it is from, and whether the machine has it from the start. The tab or program
## (jobs and games) that runs it is in HOST.
const PROGRAMS := {
	"builder": {"title": "Builder 98", "icon": "builder", "file": "BLDR98SW.EXE", "kb": 96, "site": "stavitel98.cz", "base": false,
		"blurb": "Plan the camp tile by tile: tents, cabins, toilets, paths, lamps.\nShareware from Stavitel software, Jihlava."},
	"camp_status": {"title": "CampStat 98", "icon": "campstat", "file": "CAMPSTAT.EXE", "kb": 48, "site": "campgrid.cz", "base": true,
		"blurb": "The power bills, the upkeep, tonight's risk and the money.\nFree for customers of Hlubocany District Power."},
	"guestrack": {"title": "GuestRack 98", "icon": "guestrack", "file": "GUESTRAK.EXE", "kb": 72, "site": "okres-hlubocany.cz/register", "base": false,
		"blurb": "The district's register of guests: who is staying, who is on\nthe way, which rooms are still to make up. Free of charge."},
	"datapunch": {"title": "DataPunch 98", "icon": "documents", "file": "DATAPNCH.EXE", "kb": 40, "site": "kuryr-hlubocany.cz", "base": false},
	"adclick": {"title": "KlikBanka 98", "icon": "klikbank", "file": "KLIKBANK.EXE", "kb": 36, "site": "bohemia-online.cz/prace", "base": false},
	"census": {"title": "SectiTo 98", "icon": "sectito", "file": "SECTITO.EXE", "kb": 44, "site": "bohemia-online.cz/prace", "base": false},
	"pub_app": {"title": "Hostinsky 98", "icon": "pub_app", "file": "HOSPOD98.EXE", "kb": 64, "site": "softsklad.cz", "base": false},
	"bistro_app": {"title": "Kuchar 98", "icon": "bistro_app", "file": "KUCHAR98.EXE", "kb": 64, "site": "softsklad.cz", "base": false},
	"shop_app": {"title": "Pult 98", "icon": "shop_app", "file": "PULT98.EXE", "kb": 56, "site": "softsklad.cz", "base": false},
	"corn_app": {"title": "Klasek 98", "icon": "corn_app", "file": "KLASEK98.EXE", "kb": 32, "site": "softsklad.cz", "base": false},
	# The games are on the machine already: the evenings at the office before this one.
	"mines": {"title": "Mines", "icon": "mines", "file": "", "kb": 24, "site": "", "base": true},
	"mosquito": {"title": "Komar 98", "icon": "komar", "file": "KOMAR98.EXE", "kb": 28, "site": "bohemia-online.cz/hry", "base": true},
	"hike": {"title": "Vylet 98", "icon": "vylet", "file": "VYLET98.EXE", "kb": 24, "site": "bohemia-online.cz/hry", "base": true},
	"pexeso": {"title": "Pexeso 98", "icon": "pexeso", "file": "PEXESO98.EXE", "kb": 52, "site": "bohemia-online.cz/hry", "base": true},
}
## What a program's file says about itself (Properties: the maker, the version, when the
## file was last written).
const PROGRAM_INFO := {
	"datapunch": ["Okresni urad Hlubocany", "1.0", "14.9.1998"],
	"adclick": ["Bohemia Online s.r.o.", "2.1", "1.10.1998"],
	"census": ["Okresni urad Hlubocany", "1.02", "8.9.1998"],
	"pub_app": ["SoftSklad s.r.o.", "3.1", "20.4.1998"],
	"bistro_app": ["SoftSklad s.r.o.", "3.1", "20.4.1998"],
	"shop_app": ["SoftSklad s.r.o.", "2.0", "11.3.1998"],
	"corn_app": ["SoftSklad s.r.o.", "1.0", "2.7.1998"],
	"mines": ["Okna 98 accessory", "4.10", "11.5.1998"],
	"mosquito": ["Bohemia Soft, shareware", "1.0", "3.8.1998"],
	"hike": ["Bohemia Soft, shareware", "1.1", "17.7.1998"],
	"pexeso": ["Pixel Pardubice, shareware", "2.0", "9.6.1998"],
}

## The games' best results, kept with the names typed in. What was on the machine before.
const SCORE_SEEDS := {
	"mines": [["Vera", 74], ["Vera", 96], ["Karel", 141], ["Vera", 163], ["Nela", 212]],
	"mosquito": [["Vera", 188], ["Nela", 140], ["Vera", 121], ["Karel", 64], ["Vera", 59]],
	"hike": [["Vera", 340], ["Vera", 260], ["Nela", 190], ["Karel", 150], ["jana", 110]],
	"pexeso": [["Vera", 19], ["Nela", 23], ["Vera", 24], ["Karel", 31], ["Vera", 33]],
}
## Where the smaller number is the better one (seconds, turns).
const LOWER_IS_BETTER := ["mines", "pexeso"]
const SCORE_ROWS := 5
const HOST := {
	"builder": "builder", "camp_status": "camp_status", "guestrack": "guestrack",
	"datapunch": "jobs", "adclick": "jobs", "census": "jobs",
	"pub_app": "shops", "bistro_app": "shops", "shop_app": "shops", "corn_app": "shops",
	"mines": "games", "mosquito": "games", "hike": "games", "pexeso": "games",
}
## The tabs that are a program of their own and must be installed first.
const INSTALL_TABS := ["builder", "camp_status", "guestrack"]
## Seconds a one-click install takes (the modem, the bytes, the setup).
const INSTALL_SEC := 2.8
## Old window ids (saves, tools, mail links) to where they live now.
const APP_ALIASES := {
	"folder": "files", "mycomputer": "files", "bin": "files", "downloads": "files", "vera": "files",
	"notepad": "files", "imageview": "files",
}

enum Boot { OFF, WARMUP, BIOS, SPLASH, OKNA, DESKTOP, SHUTTING, SAFE_OFF }

var _state := Boot.OFF
## The newest Goggle review the Reviews tab has shown (its badge counts the ones after).
var _reviews_seen := -1
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

var _pages_layer: Control
var _pages: Dictionary = {}        # tab id -> page
var _tab := ""
var _last_tab := "camp_status"
var _dialogs: Control
var _dialog_catch: Control
var _taskbar: Control
var _start_btn: Control
var _tab_buttons: Dictionary = {}  # tab id -> Control
var _clock: Label
var _money: Label
var _tray_net: TextureRect
var _start_menu: Control
var _boot: Control
var _cursor: Control
## Over a link: the cursor is the pointing hand.
var pointer_hand := false:
	set(v):
		if v != pointer_hand:
			pointer_hand = v
			if _cursor != null:
				_cursor.queue_redraw()
var _ups: Control
var _ups_label: Label
var _boot_t := 0.0
var _boot_lines: Array[String] = []
var _icon_cache: Dictionary = {}
var _busy := 0
var _poll := 0.0
var _mouse := SCREEN * 0.5
## Tabs flashing for attention: id -> seconds left.
var _flash: Dictionary = {}
const FLASH_SEC := 3.0
## The boot's last part: the panel filling in (seconds since, -1 when done).
var _reveal_t := -1.0
## The Start menu sliding up out of the taskbar.
var _menu_slide := {}
## The modem's two little screens lighting with the traffic.
var _net_t := 0.0
var _net_lit := 0
var _badges: Dictionary = {}       # tab id -> [text, colour]
## program id -> seconds into its one-click install.
var _installing: Dictionary = {}
## Small things the programs keep between sittings and saves (scores, jobs done).
var _store: Dictionary = {}
# Held here: a texture loaded inside a draw callback is freed before it is drawn.
var _wallpaper_tex: Texture2D = load(WALLPAPER) if ResourceLoader.exists(WALLPAPER) else null
## The maker's boot screen, set at 640x480 with its text (tools/artgen/os_art.py); the
## old picture only if it is missing.
const OEM_SPLASH_2 := "res://assets/textury/os98/oem_splash.png"
const OEM_BAR := Rect2(190, 410, 260, 14)
var _splash_tex: Texture2D = load(OEM_SPLASH_2) if ResourceLoader.exists(OEM_SPLASH_2) else (load(OEM_SPLASH) if ResourceLoader.exists(OEM_SPLASH) else null)
var _splash_is_new := ResourceLoader.exists(OEM_SPLASH_2)
var _wallpaper_path := WALLPAPER
## The operating system's own screens (tools/artgen/okna_splash.py).
const OKNA_SPLASH := "res://assets/textury/os98/okna_splash.png"
const OKNA_SHUTDOWN := "res://assets/textury/os98/okna_shutdown.png"
const OKNA_START := "res://assets/textury/os98/okna_logo_start.png"
var _okna_tex: Texture2D = load(OKNA_SPLASH) if ResourceLoader.exists(OKNA_SPLASH) else null
var _okna_off_tex: Texture2D = load(OKNA_SHUTDOWN) if ResourceLoader.exists(OKNA_SHUTDOWN) else null
var _start_logo_tex: Texture2D
## The screen saver (scripts/os98/os_extras.gd).
var _extras


func _ready() -> void:
	theme = T.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# Pixels stay pixels: bevels, icons and the bitmap fonts are drawn 1:1.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in PROGRAMS:
		_unlocked[id] = bool(PROGRAMS[id].get("base", false))
	_start_logo_tex = _start_logo()
	_build_pages()
	_build_taskbar()
	_build_dialogs()
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
	# Installed from elsewhere (tools, the quest's debug): show it here too.
	EventBus.program_installed.connect(func(id: String):
		if PROGRAMS.has(id) and not _is_program_unlocked(id):
			install_program(id, false)
	)
	if EmailManager != null:
		EmailManager.email_received.connect(_on_email_received)
		EmailManager.unread_count_changed.connect(func(_c): _refresh_badges())
		if EmailManager.has_signal("coop_synced"):
			EmailManager.coop_synced.connect(_refresh_mail_windows)
	_apply_state()


# ── contract with the game ───────────────────────────────────────────────────

func setup(grid_mgr, building_mgr, _ui_adapter = null, interior_host: Node = null) -> void:
	_grid_mgr = grid_mgr
	_building_mgr = building_mgr
	_host = interior_host
	_extras = EXTRAS.new()
	_extras.name = "Extras"
	add_child(_extras)
	_extras.setup(self)


func open_panel() -> bool:
	_open = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if _state == Boot.OFF or _state == Boot.SAFE_OFF:
		_start_boot()
	elif _state == Boot.DESKTOP:
		_refresh_page(_tab)
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
	_close_dialogs()
	_state = Boot.OFF
	_online = false
	_apply_state()


func set_is_day(is_day: bool) -> void:
	var changed := is_day != _is_day
	_is_day = is_day
	if changed and _pages.has("builder"):
		# Builder's licence: the page is covered at 20:00 and uncovered at 06:30.
		_refresh_cover("builder")
	if changed:
		_refresh_badges()


func refresh_from_state(_state_dict: Dictionary = {}) -> void:
	for id in _pages:
		_refresh_page(id)


## A text field has focus: keys (including S and the tab keys) belong to the computer.
func wants_keyboard() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	if f is LineEdit:
		return (f as LineEdit).editable and f.is_visible_in_tree()
	if f is TextEdit:
		return (f as TextEdit).editable and f.is_visible_in_tree()
	return false


func export_persistent_state() -> Dictionary:
	return {
		"os": "okna98",
		"unlock_registry": _unlocked.duplicate(),
		"downloads": _downloads.duplicate(),
		"bin": _bin.duplicate(),
		"restored": _restored.duplicate(),
		"monitor_powered": _state == Boot.DESKTOP,
		"wallpaper": _wallpaper_path,
		"display": _extras.export_state() if _extras != null else {},
		"datapunch_nights": get_meta("datapunch_nights", {}),
		"tab": _tab if _tab != "" else _last_tab,
		"store": _store.duplicate(true),
	}


## Co-op: the one PC in the office is the same on both machines: what is installed, the
## downloads, the bin, the wallpaper and the screen saver (main._coop_sync_things "pc",
## both ways when it changes; the monitor's power and the open tab are each warden's own).
func coop_pc_state() -> Dictionary:
	var out := export_persistent_state()
	out.erase("monitor_powered")
	out.erase("tab")
	return out


## The other machine's PC, taken in without closing anything open here.
func coop_take_pc(data: Dictionary) -> void:
	var reg: Dictionary = data.get("unlock_registry", {}) if data.get("unlock_registry", {}) is Dictionary else {}
	for id in PROGRAMS:
		_unlocked[id] = bool(PROGRAMS[id].get("base", false)) or bool(reg.get(id, false))
	_downloads.clear()
	for f in data.get("downloads", []):
		_downloads.append(str(f))
	_bin.clear()
	for f in data.get("bin", []):
		_bin.append(str(f))
	_restored.clear()
	for f in data.get("restored", []):
		_restored.append(str(f))
	if data.has("wallpaper") and str(data["wallpaper"]) != _wallpaper_path:
		set_wallpaper(str(data["wallpaper"]))
	if _extras != null and data.get("display", {}) is Dictionary:
		_extras.import_state(data.get("display", {}))
	if data.get("datapunch_nights", {}) is Dictionary:
		set_meta("datapunch_nights", (data.get("datapunch_nights", {}) as Dictionary).duplicate())
	if data.get("store", {}) is Dictionary:
		_store = (data.get("store", {}) as Dictionary).duplicate(true)
	for id in _pages:
		_refresh_cover(id)
	_refresh_folders()
	_refresh_badges()


func import_persistent_state(data: Dictionary) -> void:
	for id in PROGRAMS:
		_unlocked[id] = bool(PROGRAMS[id].get("base", false))
	_downloads.clear()
	_bin = FILES.BIN_START.duplicate()
	_restored.clear()
	_store = {}
	_installing.clear()
	_last_tab = "camp_status"
	if not data.is_empty():
		var reg: Dictionary = data.get("unlock_registry", {}) if data.get("unlock_registry", {}) is Dictionary else {}
		for id in reg:
			if PROGRAMS.has(str(id)) and bool(reg[id]):
				_unlocked[str(id)] = true
		if data.get("datapunch_nights", {}) is Dictionary:
			set_meta("datapunch_nights", (data.get("datapunch_nights", {}) as Dictionary).duplicate())
		if str(data.get("os", "")) == "okna98":
			for f in data.get("downloads", []):
				_downloads.append(str(f))
			_bin = []
			for f in data.get("bin", []):
				_bin.append(str(f))
			for f in data.get("restored", []):
				_restored.append(str(f))
			if data.has("wallpaper"):
				set_wallpaper(str(data["wallpaper"]))
			if _extras != null and data.get("display", {}) is Dictionary:
				_extras.import_state(data.get("display", {}))
			if data.get("store", {}) is Dictionary:
				_store = (data.get("store", {}) as Dictionary).duplicate(true)
			if _tab_index(str(data.get("tab", ""))) >= 0:
				_last_tab = str(data["tab"])
	# Another camp: every program starts again from its first screen.
	_close_dialogs()
	for id in _pages.keys():
		_free_page(id)
	_tab = ""
	_state = Boot.OFF
	_apply_state()
	# A save loaded while the screen is in front of you (game over -> Load): open_panel
	# will not come again, so the machine starts here.
	if _open:
		_start_boot()


func _is_program_unlocked(app_id: String) -> bool:
	if PROGRAMS.has(app_id):
		return bool(_unlocked.get(app_id, false))
	return TAB_SCRIPTS.has(app_id) or APP_ALIASES.has(app_id) or app_id == "display"


## Installs straight away (tools, old saves).
func _on_program_installed(app_id: String) -> void:
	install_program(app_id, false)


func _open_email_app() -> void:
	open_app("mail")


func _open_guestrack_app() -> void:
	open_app("guestrack")


func _open_builder_app() -> void:
	open_app("builder")


# ── services for the programs ────────────────────────────────────────────────

## main.gd: billing, upkeep and the clock. (The interior proxies some of these, so the
## clock is what tells main apart.)
func main_node() -> Node:
	var cur: Node = _host
	while cur != null:
		if cur.has_method("_time_of_day_string") and cur.has_method("get_electricity_ui_snapshot"):
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


## Money earned at this desk (the jobs from home) into the camp's till; in co-op the
## till is the host's.
func earn(amount: int) -> void:
	if amount <= 0:
		return
	if Coop.is_client():
		Coop.send_request("money", [amount])
	elif CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.add_money(amount)


## The day a job's count belongs to: before noon the night is still the day before's.
func work_day() -> int:
	var day := CoreRoot.get_day() if CoreRoot != null else 1
	var m := main_node()
	var h := float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 14.0
	return day - (1 if h < 6.0 else 0)


## How much of a job was done on this work day (and add to it).
func job_done(job: String) -> int:
	return int(stored("job_%s_%d" % [job, work_day()], 0))


func job_add(job: String, n: int) -> void:
	store("job_%s_%d" % [job, work_day()], job_done(job) + n)
	var a = app_of("jobs")
	if a != null and a.has_method("refresh"):
		a.refresh()


## A game's best results: [[name, value]], best first.
func scores(game: String) -> Array:
	var s = _store.get("scores_" + game, null)
	if s is Array and not (s as Array).is_empty():
		return s
	return (SCORE_SEEDS.get(game, []) as Array).duplicate(true)


## A result in: on the table under the player's name if it is good enough. Returns its
## place (0 = the best) or -1.
func add_score(game: String, value: int) -> int:
	var rows := scores(game)
	var low := game in LOWER_IS_BETTER
	var at := rows.size()
	for i in rows.size():
		var v := int(rows[i][1])
		if (value < v) if low else (value > v):
			at = i
			break
	if at >= SCORE_ROWS:
		return -1
	rows.insert(at, [player_name(), value])
	rows = rows.slice(0, SCORE_ROWS)
	_store["scores_" + game] = rows
	return at


## The name a new best result goes under: the warden's own.
func player_name() -> String:
	var n := ""
	if Coop != null and Coop.has_method("my_look"):
		n = str((Coop.my_look() as Dictionary).get("n", ""))
	return n if n != "" else "Warden"


## A program's small memory between sittings and saves (high scores, jobs done today).
func stored(key: String, default: Variant = null) -> Variant:
	return _store.get(key, default)


func store(key: String, value: Variant) -> void:
	_store[key] = value


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


## Out of the bin, back to C:\VERA where it came from.
func restore_from_bin(name: String) -> void:
	_bin.erase(name)
	if not _restored.has(name):
		_restored.append(name)
	_refresh_folders()


## The setup file a program comes as -> its id.
func installer_of(file: String) -> String:
	for id in PROGRAMS:
		if str(PROGRAMS[id]["file"]) == file and file != "":
			return id
	return ""


## Open a file anywhere (the Files tab, Run, the bin).
func open_file(dir: String, name: String) -> void:
	var full := dir.trim_suffix("\\") + "\\" + name
	if dir == "My Computer":
		if name.begins_with("3 1/2"):
			play("ding")
			message_box("A:\\", "A:\\ is not accessible.\n\nThe device is not ready.", "error", ["Retry", "Cancel"])
		else:
			open_app("files", {"path": "C:\\"})
		return
	if dir == "BIN":
		message_box("Recycle Bin", "%s is in the Recycle Bin.\nRestore it to its original place (C:\\VERA)?" % name, "question", ["Yes", "No"], func(b: String):
			if b == "Yes":
				restore_from_bin(name)
		)
		return
	if is_dir(full):
		open_app("files", {"path": full})
		return
	var prog := installer_of(name)
	if prog != "":
		start_download(name, str(PROGRAMS[prog]["site"]))
		return
	match FILES.file_kind(name):
		"text", "image":
			open_app("files", {"path": dir, "file": name})
		"exe":
			var app := str(FILES.EXE_APPS.get(name, ""))
			if app.is_empty():
				message_box(name, "This program cannot be run in Okna mode.", "error")
			else:
				open_app(app)
		_:
			message_box(name, "This file is used by the system or another program\nand cannot be opened.", "warning")


## The web or a mail asks for a file. A program's setup file installs it there and then
## on the tab it runs in (one click, a short wait); anything else lands in C:\DOWNLOAD.
func start_download(file: String, _from_url: String = "") -> void:
	var prog := installer_of(file)
	if prog == "":
		finish_download(file)
		message_box("File Download", "%s was saved in C:\\DOWNLOAD." % file, "info")
		return
	if _is_program_unlocked(prog):
		message_box("File Download", "%s is already installed on this computer." % PROGRAMS[prog]["title"], "info")
		open_app(prog)
		return
	begin_install(prog)
	open_app(prog)


func finish_download(file: String) -> void:
	if not _downloads.has(file):
		_downloads.append(file)
	if EventBus.has_signal("file_downloaded"):
		EventBus.file_downloaded.emit(file)
	_refresh_folders()


## The one-click install: the modem, the file, the setup, in a few seconds.
func begin_install(prog: String) -> void:
	if not PROGRAMS.has(prog) or _is_program_unlocked(prog) or _installing.has(prog):
		return
	_installing[prog] = 0.0
	set_busy(true)
	play("modem" if not _online else "hdd", -10.0)


## -1 when not installing, else 0..1.
func install_progress(prog: String) -> float:
	return clampf(float(_installing[prog]) / INSTALL_SEC, 0.0, 1.0) if _installing.has(prog) else -1.0


## What the install is doing now, for its progress line.
func install_status(prog: String) -> String:
	var p := install_progress(prog)
	if p < 0.0:
		return ""
	var info: Dictionary = PROGRAMS[prog]
	if p < 0.25:
		return "Connecting to www.%s..." % str(info["site"]).split("/")[0]
	if p < 0.7:
		return "Downloading %s  (%d of %d KB)" % [info["file"], int(float(info["kb"]) * (p - 0.25) / 0.45), int(info["kb"])]
	if p < 0.9:
		return "Installing %s..." % info["title"]
	return "Installation complete."


func _tick_installs(delta: float) -> void:
	if _installing.is_empty():
		return
	for prog in _installing.keys():
		var before := float(_installing[prog])
		_installing[prog] = before + delta
		if before < INSTALL_SEC * 0.75 and before + delta >= INSTALL_SEC * 0.75:
			play("hdd", -12.0)
		if float(_installing[prog]) >= INSTALL_SEC:
			_installing.erase(prog)
			set_busy(false)
			install_program(prog, true)
			play("ding", -8.0)
	for id in _pages:
		var a = app_of(id)
		if a != null and a.has_method("install_tick"):
			a.install_tick()
		var p: Control = _pages[id]
		if p.cover != null and is_instance_valid(p.cover):
			_update_cover(p.cover)


func install_program(app_id: String, from_setup := true) -> void:
	if not PROGRAMS.has(app_id) or _is_program_unlocked(app_id):
		return
	_unlocked[app_id] = true
	# The setup file goes in the bin, like everyone did.
	var file := str(PROGRAMS[app_id]["file"])
	if from_setup and file != "":
		_downloads.erase(file)
		if not _bin.has(file):
			_bin.append(file)
	var tab := str(HOST.get(app_id, ""))
	if _pages.has(tab):
		_refresh_cover(tab)
		var a = app_of(tab)
		if a != null and a.has_method("program_installed"):
			a.program_installed(app_id)
	_refresh_folders()
	_refresh_badges()
	if EventBus.has_signal("program_installed"):
		EventBus.program_installed.emit(app_id)


## A small dialog. kind: info / warning / error / question. `cb` gets the button text.
func message_box(p_title: String, text: String, kind := "info", buttons := ["OK"], cb: Callable = Callable()) -> void:
	var lines := text.split("\n")
	var w := 0.0
	for l in lines:
		w = maxf(w, T.FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x)
	var box_size := Vector2(clampf(w + 90, 220, 560), clampf(lines.size() * 14 + 92, 120, 420))
	var win = _make_dialog("msg", p_title, null, Rect2((SCREEN - box_size) * 0.5 - Vector2(0, 20), box_size))
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
	var first := true
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
		if first:
			# The default button: a black frame round it, and Enter presses it.
			btn.add_theme_stylebox_override("normal", T.box("default", T.FACE, Vector4(6, 3, 6, 3)))
			btn.add_theme_stylebox_override("hover", T.box("default", T.FACE, Vector4(6, 3, 6, 3)))
			btn.add_theme_stylebox_override("pressed", T.box("default_pressed", T.FACE, Vector4(7, 4, 5, 2)))
			btn.add_theme_stylebox_override("hover_pressed", T.box("default_pressed", T.FACE, Vector4(7, 4, 5, 2)))
			btn.grab_focus.call_deferred()
			first = false
	win.close_requested.connect(func():
		_close_window(win)
		if cb.is_valid():
			cb.call(buttons[buttons.size() - 1])
	)
	if kind == "error" or kind == "warning":
		play("ding")


# ── the pages ────────────────────────────────────────────────────────────────

## Shows a program (its tab comes forward). Returns its page, or null if it cannot run
## (not installed, Builder at night: its tab shows why).
func open_app(app_id: String, args: Dictionary = {}, _new_instance := false) -> Control:
	if _state != Boot.DESKTOP:
		return null
	_close_start_menu()
	var a := args.duplicate()
	var tab := app_id
	match app_id:
		"display":
			return _open_dialog_app("display", "Display Properties", Vector2(360, 330))
		"setup", "download":
			var prog := str(a.get("program", installer_of(str(a.get("file", "")))))
			if prog != "":
				begin_install(prog)
				return open_app(prog)
			return null
		"downloads":
			a["path"] = "C:\\DOWNLOAD"
		"vera":
			a["path"] = "C:\\VERA"
		"bin":
			a["path"] = "BIN"
		"mycomputer":
			a["path"] = "My Computer"
	if APP_ALIASES.has(app_id):
		tab = str(APP_ALIASES[app_id])
	elif HOST.has(app_id) and HOST[app_id] != app_id:
		tab = str(HOST[app_id])
		a["program"] = app_id
	if not TAB_SCRIPTS.has(tab):
		return null
	_select_tab(tab)
	var page: Control = _pages.get(tab)
	var app = app_of(tab)
	if app != null and app.has_method("reopen"):
		app.reopen(a)
	if page == null or app == null or (page.cover != null and is_instance_valid(page.cover)):
		return null
	return page


## Builder's map on a building (GuestRack's rooms, CampStat's upkeep): the tab comes
## forward, the map centres on it and its card opens. Night or not installed: the
## Builder tab says why.
func show_on_map(coord: Vector2i) -> void:
	if open_app("builder") == null:
		return
	var a = app_of("builder")
	if a != null and a.has_method("focus_building"):
		a.focus_building(coord)


## The program on a tab (or the tab that hosts it), or null.
func app_of(app_id: String) -> Control:
	var tab := str(APP_ALIASES.get(app_id, HOST.get(app_id, app_id)))
	var page: Control = _pages.get(tab)
	if page == null or not is_instance_valid(page) or page.content.get_child_count() == 0:
		return null
	return page.content.get_child(0)


## A program asked to close (File > Exit): the tab starts again from its first screen
## next time; the panel goes back to the tab before it.
func close_app_window(win: Control) -> void:
	if win == null or not is_instance_valid(win):
		return
	if win.get_parent() == _pages_layer:
		var id := str(win.app_id)
		var back := _last_tab if _last_tab != id else "camp_status"
		_free_page(id)
		if _tab == id:
			_tab = ""
			_select_tab(back)
		return
	_close_window(win)


func current_tab() -> String:
	return _tab


func _build_pages() -> void:
	_pages_layer = Control.new()
	_pages_layer.name = "Pages"
	_pages_layer.size = DESKTOP_SIZE
	_pages_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pages_layer.draw.connect(func():
		_pages_layer.draw_rect(Rect2(Vector2.ZERO, DESKTOP_SIZE), T.DESKTOP)
		if _wallpaper_tex != null:
			var s := _wallpaper_tex.get_size()
			var k := maxf(SCREEN.x / s.x, DESKTOP_SIZE.y / s.y)
			_pages_layer.draw_texture_rect(_wallpaper_tex, Rect2((DESKTOP_SIZE - s * k) * 0.5, s * k), false, Color(0.8, 0.8, 0.8))
	)
	add_child(_pages_layer)


func _tab_index(id: String) -> int:
	for i in TABS.size():
		if str(TABS[i][0]) == id:
			return i
	return -1


## The page of a tab, made the first time it is wanted.
func _page(id: String) -> Control:
	if _pages.has(id) and is_instance_valid(_pages[id]):
		return _pages[id]
	var page = PAGE.new()
	_pages_layer.add_child(page)
	var i := _tab_index(id)
	page.setup(id, str(TAB_TITLES.get(id, id)), icon(str(TABS[i][2]) if i >= 0 else "folder", true), Rect2(Vector2.ZERO, DESKTOP_SIZE))
	page.visible = false
	page.title_changed.connect(func():
		if _tab_buttons.has(id):
			(_tab_buttons[id] as Control).tooltip_text = _tab_tip(id))
	_pages[id] = page
	_refresh_cover(id)
	return page


## The program itself goes in when it can run; a cover says why it cannot.
func _refresh_cover(id: String) -> void:
	var page: Control = _pages.get(id)
	if page == null:
		return
	var want := ""
	if id in INSTALL_TABS and not _is_program_unlocked(id):
		want = "install"
	elif id == "builder" and not _is_day:
		want = "licence"
	var has: String = str(page.cover.get_meta("kind", "")) if page.cover != null and is_instance_valid(page.cover) else ""
	if want != has:
		page.set_cover(_make_cover(id, want) if want != "" else null)
	if want == "" and page.content.get_child_count() == 0:
		_start_program(page, id)


func _start_program(page: Control, id: String) -> void:
	var script: Script = load("res://scripts/os98/apps/%s.gd" % TAB_SCRIPTS[id])
	var app = script.new()
	page.content.add_child(app)
	app.size = page.client_size()
	page.resized.connect(func(): app.size = page.client_size())
	if app.has_method("setup"):
		app.setup(self, page, {})


func _free_page(id: String) -> void:
	var page: Control = _pages.get(id)
	_pages.erase(id)
	if page == null or not is_instance_valid(page):
		return
	var app = page.content.get_child(0) if page.content.get_child_count() > 0 else null
	if app != null and app.has_method("closing"):
		app.closing()
	page.queue_free()


func _select_tab(id: String) -> void:
	if _state != Boot.DESKTOP or not TAB_SCRIPTS.has(id):
		return
	var page := _page(id)
	if _tab == id and page.visible:
		return
	if _tab != "" and _tab != id and _pages.has(_tab):
		var oa = app_of(_tab)
		if oa != null and oa.has_method("page_hidden"):
			oa.page_hidden()
		_last_tab = _tab
	var was := _tab
	_tab = id
	for k in _pages:
		(_pages[k] as Control).visible = k == id
	pointer_hand = false
	# The program comes up from its taskbar button (outlines over it; it never waits).
	if was != "" and _extras != null and _tab_buttons.has(id):
		var b: Control = _tab_buttons[id]
		_extras.zoom(Rect2(b.global_position - global_position, b.size), Rect2(Vector2.ZERO, DESKTOP_SIZE))
	_refresh_page(id)
	var app = app_of(id)
	if app != null and app.has_method("shown"):
		app.shown()
	for k in _tab_buttons:
		(_tab_buttons[k] as Control).queue_redraw()


func _refresh_page(id: String) -> void:
	_refresh_cover(id)
	var app = app_of(id)
	if app != null and app.has_method("refresh"):
		app.refresh()


func _refresh_folders() -> void:
	var a = app_of("files")
	if a != null and a.has_method("refresh_listing"):
		a.refresh_listing()


# ── covers: not installed, not now ───────────────────────────────────────────

func _make_cover(id: String, kind: String) -> Control:
	var c := Control.new()
	c.set_meta("kind", kind)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var btn := Button.new()
	btn.name = "Do"
	btn.custom_minimum_size = Vector2(230, 26)
	btn.add_theme_font_override("font", T.FONT_BOLD)
	c.add_child(btn)
	var bar = PROGRESS.new("install")
	bar.name = "Bar"
	bar.show_percent = true
	bar.visible = false
	c.add_child(bar)
	if kind == "install":
		var info: Dictionary = PROGRAMS[id]
		btn.text = "Download and install  (%d KB)" % int(info["kb"])
		btn.pressed.connect(func():
			play("click", -8.0)
			begin_install(id))
	else:
		btn.text = "Open CampStat instead"
		btn.pressed.connect(func(): _select_tab("camp_status"))
	c.set_meta("id", id)
	c.resized.connect(func(): _layout_cover(c))
	c.draw.connect(func(): _draw_cover(c, id, kind))
	_layout_cover.call_deferred(c)
	_update_cover(c)
	return c


## The cover's button and bar follow the install (outside the draw: a draw callback may
## not change other nodes).
func _update_cover(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		return
	var id := str(c.get_meta("id", ""))
	var bar: Control = c.get_node_or_null("Bar")
	var btn: Button = c.get_node_or_null("Do")
	if str(c.get_meta("kind", "")) == "install" and PROGRAMS.has(id):
		var p := install_progress(id)
		if bar != null:
			bar.visible = p >= 0.0
			if p >= 0.0:
				bar.value = p
		if btn != null:
			btn.disabled = p >= 0.0
			btn.text = install_status(id) if p >= 0.0 else "Download and install  (%d KB)" % int(PROGRAMS[id]["kb"])
	c.queue_redraw()


const COVER_BOX := Vector2(420, 210)


func _layout_cover(c: Control) -> void:
	if not is_instance_valid(c):
		return
	var box := Rect2(((c.size - COVER_BOX) * 0.5).floor(), COVER_BOX)
	var btn: Button = c.get_node("Do")
	btn.position = Vector2(box.position.x + floorf((COVER_BOX.x - 230) * 0.5), box.end.y - 40)
	btn.size = Vector2(230, 26)
	var bar: Control = c.get_node("Bar")
	bar.position = Vector2(box.position.x + 24, box.end.y - 66)
	bar.size = Vector2(COVER_BOX.x - 48, 18)


func _draw_cover(c: Control, id: String, kind: String) -> void:
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), T.DESKTOP)
	if _wallpaper_tex != null:
		var ts := _wallpaper_tex.get_size()
		var k := maxf(s.x / ts.x, s.y / ts.y)
		c.draw_texture_rect(_wallpaper_tex, Rect2((s - ts * k) * 0.5, ts * k), false, Color(0.55, 0.55, 0.6))
	var box := Rect2(((s - COVER_BOX) * 0.5).floor(), COVER_BOX)
	c.draw_style_box(T.box("window", T.FACE), box)
	var band := Rect2(box.position + Vector2(3, 3), Vector2(box.size.x - 6, 18))
	for i in int(ceil(band.size.x / 8.0)):
		c.draw_rect(Rect2(band.position.x + i * 8, band.position.y, minf(8.0, band.size.x - i * 8), band.size.y), T.TITLE_A.lerp(T.TITLE_B, float(i * 8) / band.size.x))
	var title := str(PROGRAMS.get(id, {}).get("title", TAB_TITLES.get(id, id)))
	c.draw_string(T.FONT_BOLD, band.position + Vector2(5, 13), title if kind == "install" else title + " - site licence", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	var ic := icon(str(PROGRAMS.get(id, {}).get("icon", "setup")))
	c.draw_texture(ic, box.position + Vector2(18, 34))
	var x := box.position.x + 64
	var y := box.position.y + 44
	if kind == "install":
		var info: Dictionary = PROGRAMS[id]
		c.draw_string(T.FONT_BOLD, Vector2(x, y), "%s is not installed on this computer." % title, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 80, T.FONT_SIZE, T.TEXT)
		y += 20
		for line in str(info.get("blurb", "")).split("\n"):
			c.draw_string(T.FONT, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 80, T.FONT_SIZE, T.TEXT)
			y += 14
		y += 6
		c.draw_string(T.FONT, Vector2(x, y), "From: http://www.%s/   %s, %d KB" % [info["site"], info["file"], int(info["kb"])], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 80, T.FONT_SIZE, T.SHADOW)
	else:
		c.draw_string(T.FONT_BOLD, Vector2(x, y), "Builder 98 cannot be used now.", HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 80, T.FONT_SIZE, T.TEXT)
		y += 20
		for line in ["The site licence for recreational facilities permits", "use between 06:30 and 20:00 only (Act no. 455/1991,", "schedule 3). Your plan is kept. It opens again", "in the morning."]:
			c.draw_string(T.FONT, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 80, T.FONT_SIZE, T.TEXT)
			y += 14
		y += 6
		c.draw_string(T.FONT, Vector2(x, y), "Now: %s" % _clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.SHADOW)


# ── dialogs (message boxes, Run, Display) ────────────────────────────────────

func _build_dialogs() -> void:
	_dialogs = Control.new()
	_dialogs.name = "Dialogs"
	_dialogs.size = SCREEN
	_dialogs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dialogs)
	# Behind the dialogs: a click on the panel while one is up rings and shows it.
	_dialog_catch = Control.new()
	_dialog_catch.size = SCREEN
	_dialog_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_catch.visible = false
	_dialog_catch.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			play("ding", -8.0)
			var top := _top_dialog()
			if top != null:
				_flash_dialog(top)
	)
	_dialogs.add_child(_dialog_catch)


func _make_dialog(app_id: String, p_title: String, p_icon: Texture2D, rect: Rect2) -> Control:
	var win = WINDOW.new()
	_dialogs.add_child(win)
	win.setup(app_id, p_title, p_icon, rect, SCREEN)
	win.close_requested.connect(func(): _close_window(win))
	win.activated.connect(func(): win.move_to_front())
	_refresh_dialog_catch()
	return win


func _open_dialog_app(id: String, p_title: String, sz: Vector2) -> Control:
	for w in _dialogs.get_children():
		if w != _dialog_catch and str(w.get("app_id")) == id and not w.is_queued_for_deletion():
			w.move_to_front()
			return w
	var win := _make_dialog(id, p_title, icon("computer", true), Rect2(((SCREEN - sz) * 0.5).floor() - Vector2(0, 14), sz))
	win.can_minimize = false
	var script: Script = load("res://scripts/os98/apps/%s_app.gd" % id)
	var app = script.new()
	win.content.add_child(app)
	app.size = win.client_size()
	if app.has_method("setup"):
		app.setup(self, win, {})
	play("click", -8.0)
	return win


func _close_window(win: Control) -> void:
	if win == null or not is_instance_valid(win):
		return
	if win.get_parent() == _pages_layer:
		close_app_window(win)
		return
	var app = win.content.get_child(0) if win.content.get_child_count() > 0 else null
	if app != null and app.has_method("closing"):
		app.closing()
	win.queue_free()
	_refresh_dialog_catch.call_deferred()


func _close_dialogs() -> void:
	for w in _dialogs.get_children():
		if w != _dialog_catch:
			_close_window(w)


func _top_dialog() -> Control:
	var kids := _dialogs.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var w = kids[i]
		if w != _dialog_catch and not w.is_queued_for_deletion():
			return w
	return null


func has_dialog() -> bool:
	return _top_dialog() != null


## Tools: shut every message box (the shareware nag). Returns how many.
func close_message_boxes() -> int:
	var n := 0
	for w in _dialogs.get_children():
		if w != _dialog_catch and str(w.get("app_id")) == "msg" and not w.is_queued_for_deletion():
			_close_window(w)
			n += 1
	return n


func _refresh_dialog_catch() -> void:
	var top := _top_dialog()
	_dialog_catch.visible = top != null
	if top != null:
		_dialog_catch.move_to_front()
		top.move_to_front()
		for w in _dialogs.get_children():
			if w != _dialog_catch:
				w.active = w == top


func _flash_dialog(w: Control) -> void:
	var ref: WeakRef = weakref(w)
	for i in 4:
		get_tree().create_timer(0.08 * i).timeout.connect(func():
			var d = ref.get_ref()
			if d != null:
				d.active = i % 2 == 1)


# ── boot ─────────────────────────────────────────────────────────────────────

func _start_boot() -> void:
	# The tube first: the thunk of the degauss coil, a line, then the picture.
	_state = Boot.WARMUP
	_boot_t = 0.0
	_boot_lines.clear()
	_apply_state()
	play("power_on", -4.0)
	play("degauss", -6.0)


func _process(delta: float) -> void:
	match _state:
		Boot.WARMUP:
			_boot_t += delta
			_boot.queue_redraw()
			if _boot_t >= 0.6:
				_state = Boot.BIOS
				_boot_t = 0.0
		Boot.BIOS:
			_tick_bios(delta)
		Boot.SPLASH:
			_boot_t += delta
			_boot.queue_redraw()
			if _boot_t >= 1.8:
				# The machine's maker, then the operating system's own screen.
				_state = Boot.OKNA if _okna_tex != null else Boot.DESKTOP
				_boot_t = 0.0
				if _state == Boot.DESKTOP:
					_enter_desktop()
				else:
					play("hdd", -8.0)
		Boot.OKNA:
			_boot_t += delta
			_boot.queue_redraw()
			if _boot_t >= 1.9:
				_enter_desktop()
		Boot.SHUTTING:
			_boot_t += delta
			_boot.queue_redraw()
			if _boot_t >= 2.0:
				_state = Boot.SAFE_OFF
				_apply_state()
		Boot.DESKTOP:
			_tick_desktop(delta)
	_cursor.queue_redraw()


const BIOS_END := 3.1


func _tick_bios(delta: float) -> void:
	_boot_t += delta
	var script := [
		[0.0, "Camptronics FieldBIOS v2.03 (C) 1994-97 Camptronics Fieldware"],
		[0.05, ""],
		[0.1, "CPU : Pentium-S 133 MHz"],
		[0.15, "MEMTEST"],
		[0.9, ""],
		[0.95, "Detecting IDE Primary Master ... QUANTUM FIREBALL 1080A"],
		[1.2, "Detecting IDE Primary Slave  ... None"],
		[1.35, "Detecting IDE Secondary Master... CAMPCD 24X"],
		[1.5, "Detecting COM3 ... no response"],
		[1.65, "Floppy drive A: ... 1.44M, 3.5 in."],
		[1.8, "TABLE"],
		[2.5, "Verifying DMI Pool Data ............ Update Success"],
		[2.75, "Starting Okna 98..."],
	]
	var lines: Array[String] = []
	for row in script:
		if _boot_t >= float(row[0]):
			if str(row[1]) == "MEMTEST":
				var kb := mini(16384, int((_boot_t - 0.15) / 0.7 * 16384.0))
				lines.append("Memory Test : %6dK %s" % [kb, "OK" if kb >= 16384 else ""])
			else:
				lines.append(str(row[1]))
	_boot_lines = lines
	_boot.queue_redraw()
	if _boot_t > 0.85 and _boot_t - delta <= 0.85:
		play("post_beep", -10.0)
	if _boot_t > 0.95 and _boot_t - delta <= 0.95:
		play("hdd", -6.0)
	if _boot_t > 1.65 and _boot_t - delta <= 1.65:
		play("floppy", -8.0)
	if _boot_t >= BIOS_END:
		_state = Boot.SPLASH
		_boot_t = 0.0
		_apply_state()


func _enter_desktop() -> void:
	_state = Boot.DESKTOP
	_apply_state()
	_refresh_badges()
	_refresh_tray()
	play("hdd_long", -14.0)
	play("startup", -6.0)
	# CampMail is in the startup group (OKNA.INI: run=CAMPMAIL.EXE): with unread mail the
	# panel opens on it, else where you left it.
	var first := _last_tab
	if EmailManager != null and EmailManager.get_unread_count() > 0:
		first = "mail"
	_tab = ""
	_select_tab(first)
	# The panel fills in as the disk catches up: the wallpaper, the taskbar, the buttons
	# one by one, then the program (it all takes clicks at once).
	_reveal_t = 0.0
	_tick_reveal(0.0)
	desktop_ready.emit()


const REVEAL_BAR := 0.12
const REVEAL_TAB := 0.035
const REVEAL_PAGE := 0.45


func _tick_reveal(delta: float) -> void:
	if _reveal_t < 0.0:
		return
	_reveal_t += delta
	_taskbar.visible = _reveal_t >= REVEAL_BAR
	var i := 0
	for id in _tab_buttons:
		(_tab_buttons[id] as Control).visible = _reveal_t >= REVEAL_BAR + 0.06 + REVEAL_TAB * i
		i += 1
	var p: Control = _pages.get(_tab)
	if p != null:
		p.visible = _reveal_t >= REVEAL_PAGE
	if _reveal_t >= REVEAL_PAGE:
		_reveal_t = -1.0
		for id in _tab_buttons:
			(_tab_buttons[id] as Control).visible = true
		_taskbar.visible = true


func _apply_state() -> void:
	var desk := _state == Boot.DESKTOP
	_pages_layer.visible = desk
	_dialogs.visible = desk
	_taskbar.visible = desk
	_boot.visible = not desk
	_boot.queue_redraw()


func _draw_boot() -> void:
	_boot.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color.BLACK)
	match _state:
		Boot.WARMUP:
			# A bright line that opens into a grey frame, the way a cold tube comes up.
			var k := clampf(_boot_t / 0.5, 0.0, 1.0)
			var h := maxf(2.0, SCREEN.y * k * k)
			var bright := 1.0 - k * 0.8
			_boot.draw_rect(Rect2(0, (SCREEN.y - h) * 0.5, SCREEN.x * clampf(k * 3.0, 0.1, 1.0), h).abs(), Color(bright, bright, bright * 1.05, 1.0))
		Boot.BIOS:
			var y := 24.0
			for l in _boot_lines:
				if l == "TABLE":
					y = _draw_config_table(y)
					continue
				_boot.draw_string(BIOS_FONT, Vector2(16, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(170, 170, 170))
				y += 16
			_boot.draw_string(BIOS_FONT, Vector2(16, 462), "Press DEL to enter SETUP.  Any other key: get on with it.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(170, 170, 170))
			# Energy star style badge, top right: two words in a box.
			_boot.draw_rect(Rect2(520, 16, 104, 40), Color8(0, 120, 60), false, 2.0)
			_boot.draw_string(BIOS_FONT, Vector2(530, 34), "FIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(0, 170, 90))
			_boot.draw_string(BIOS_FONT, Vector2(530, 50), "  STAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(0, 170, 90))
		Boot.SPLASH:
			var tex := _splash_tex
			if tex != null and _splash_is_new:
				_boot.draw_texture_rect(tex, Rect2(Vector2.ZERO, SCREEN), false)
				_draw_oem_bar(clampf(_boot_t / 1.7, 0.0, 1.0))
			elif tex != null:
				var s := tex.get_size()
				var k := minf(SCREEN.x / s.x, SCREEN.y / s.y)
				var d := s * k
				_boot.draw_texture_rect(tex, Rect2((SCREEN - d) * 0.5, d), false)
				_draw_oem_bar(clampf(_boot_t / 1.7, 0.0, 1.0))
		Boot.OKNA, Boot.SHUTTING:
			var tex2: Texture2D = _okna_tex if _state == Boot.OKNA else _okna_off_tex
			if tex2 != null:
				_boot.draw_texture_rect(tex2, Rect2(Vector2.ZERO, SCREEN), false)
			if _state == Boot.OKNA:
				# The band along the bottom that never stops sliding: a rainbow of blues.
				var band := Rect2(0, SCREEN.y - 10, SCREEN.x, 10)
				var off := fmod(_boot_t * 260.0, SCREEN.x * 2.0)
				var step := 8.0
				var x := 0.0
				while x < SCREEN.x:
					var u := fmod((x + off) / (SCREEN.x * 2.0), 1.0)
					var col := Color.from_hsv(0.55 + 0.12 * sin(u * TAU), 0.75, 0.55 + 0.45 * absf(sin(u * PI * 2.0)))
					_boot.draw_rect(Rect2(x, band.position.y, step, band.size.y), col)
					x += step
		Boot.SAFE_OFF:
			var msg := "It is now safe to turn off\n     your computer."
			var y2 := 220.0
			for l in msg.split("\n"):
				_boot.draw_string(T.FONT_BOLD, Vector2(220, y2), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 * 2, Color8(255, 140, 0))
				y2 += 30
			_boot.draw_string(T.FONT, Vector2(214, 300), "(click to start it again)", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(140, 90, 0))


## The maker's loading bar: a dark sunken slot, amber blocks that come in fits and
## starts (the disk was doing something between them), the newest one brighter.
func _draw_oem_bar(p: float) -> void:
	var r := OEM_BAR
	_boot.draw_rect(r.grow(2), Color8(60, 40, 20))
	_boot.draw_rect(r.grow(1), Color8(8, 6, 4))
	_boot.draw_rect(Rect2(r.position.x - 2, r.end.y + 1, r.size.x + 4, 1), Color8(150, 110, 60))
	# Uneven: quick at first, a long wait in the middle, a rush at the end.
	var q := p * p * (3.0 - 2.0 * p)
	if p > 0.35 and p < 0.62:
		q = lerpf(0.33, 0.42, (p - 0.35) / 0.27)
	var bw := 8.0
	var gap := 2.0
	var count := int((r.size.x + gap) / (bw + gap))
	var n := int(floor(q * count))
	for i in n:
		var col := Color8(232, 160, 48) if i < n - 1 else Color8(255, 220, 120)
		_boot.draw_rect(Rect2(r.position.x + i * (bw + gap), r.position.y + 2, bw, r.size.y - 4), col)
		_boot.draw_rect(Rect2(r.position.x + i * (bw + gap), r.position.y + 2, bw, 1), Color8(255, 236, 170))


## The BIOS summary every machine of the time printed before the operating system: a
## double-lined box of what was found.
func _draw_config_table(y: float) -> float:
	var rows := [
		["CPU Type    : Pentium-S", "Base Memory     :    640K"],
		["CPU Clock   : 133MHz", "Extended Memory :  15360K"],
		["Diskette A  : 1.44M, 3.5 in.", "Display Type    : EGA/VGA"],
		["Pri. Master : LBA, Mode 4, 1080MB", "Serial Port(s)  : 3F8 2F8"],
		["Sec. Master : CDROM, Mode 4", "Parallel Port   : 378"],
	]
	var top := y + 4.0
	var box := Rect2(16, top, SCREEN.x - 32, 16.0 * rows.size() + 30.0)
	var cyan := Color8(0, 170, 170)
	_boot.draw_rect(box, cyan, false, 1.0)
	_boot.draw_rect(box.grow(-3), cyan, false, 1.0)
	var title := "System Configurations"
	var tw := BIOS_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_boot.draw_rect(Rect2((SCREEN.x - tw) * 0.5 - 6, top - 7, tw + 12, 14), Color.BLACK)
	_boot.draw_string(BIOS_FONT, Vector2((SCREEN.x - tw) * 0.5, top + 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(255, 255, 255))
	var ry := top + 24.0
	for r in rows:
		_boot.draw_string(BIOS_FONT, Vector2(28, ry), str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(170, 170, 170))
		_boot.draw_string(BIOS_FONT, Vector2(330, ry), str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(170, 170, 170))
		ry += 16.0
	return box.end.y + 18.0


func _tick_desktop(delta: float) -> void:
	_tick_installs(delta)
	_poll -= delta
	if _poll <= 0.0:
		_poll = 1.0
		var m := main_node()
		_clock.text = _clock_text()
		_clock.tooltip_text = "%s 1998" % Season.date_long(CoreRoot.get_day()) if CoreRoot != null else ""
		_money.text = "$%s" % _group(CoreRoot.get_money() if CoreRoot != null else 0)
		_refresh_ups(m)
		_refresh_badges()
		var p: Control = _pages.get(_tab)
		if p != null and p.cover != null and is_instance_valid(p.cover):
			_update_cover(p.cover)
	# Tabs that want you flash, as the taskbar did: half a second on, half off.
	for id in _flash.keys():
		var before := float(_flash[id])
		var now := before - delta
		if now <= 0.0 or id == _tab:
			_flash.erase(id)
		else:
			_flash[id] = now
		if _tab_buttons.has(id) and (now <= 0.0 or int(before * 2.0) != int(now * 2.0)):
			(_tab_buttons[id] as Control).queue_redraw()
	_tick_reveal(delta)
	_tick_menu_slide(delta)
	if _net_t > 0.0:
		_net_t -= delta
		var lit := 0 if _net_t <= 0.0 else (1 + int(_net_t * 8.0) % 2)
		if lit != _net_lit:
			_net_lit = lit
			_tray_net.texture = _net_icon(lit)


func _clock_text() -> String:
	var m := main_node()
	if m != null and m.has_method("_time_of_day_string"):
		return str(m.call("_time_of_day_string"))
	return "--:--"


# ── the taskbar: Start, the tabs, the tray ───────────────────────────────────

const START_W := 76
const WIDE_W := 42
const NARROW_W := 42
const TAB_GAP := 2
const TAB_X := 84
const TRAY_W := 112
const TAB_H := 40


func _build_taskbar() -> void:
	_taskbar = Panel.new()
	_taskbar.name = "Taskbar"
	_taskbar.position = Vector2(0, SCREEN.y - TASKBAR_H)
	_taskbar.size = Vector2(SCREEN.x, TASKBAR_H)
	_taskbar.add_theme_stylebox_override("panel", T.box("thin_raised", T.FACE, Vector4.ZERO))
	add_child(_taskbar)
	_start_btn = Control.new()
	_start_btn.position = Vector2(3, 3)
	_start_btn.size = Vector2(START_W, TAB_H)
	_start_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_start_btn.tooltip_text = "Start"
	_start_btn.draw.connect(func():
		var on := _start_menu != null and _start_menu.visible
		_start_btn.draw_style_box(T.box("pressed" if on else "raised", T.FACE, Vector4.ZERO), Rect2(Vector2.ZERO, _start_btn.size))
		var o := Vector2(1, 1) if on else Vector2.ZERO
		if _start_logo_tex != null:
			_start_btn.draw_texture_rect(_start_logo_tex, Rect2(Vector2(6, 4) + o, Vector2(32, 32)), false)
		_start_btn.draw_string(T.FONT_BOLD, Vector2(40, 25) + o, "Start", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	)
	_start_btn.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _start_menu.visible:
				_close_start_menu()
			else:
				_open_start_menu()
			_start_btn.accept_event()
	)
	_taskbar.add_child(_start_btn)
	var x := float(TAB_X)
	for i in TABS.size():
		var id := str(TABS[i][0])
		var w := WIDE_W if bool(TABS[i][3]) else NARROW_W
		var b := _make_tab_button(i, Vector2(x, 3), Vector2(w, TAB_H))
		_taskbar.add_child(b)
		_tab_buttons[id] = b
		x += w + TAB_GAP
	# The tray: the line, the till, the clock.
	var tray := Panel.new()
	tray.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4.ZERO))
	tray.position = Vector2(SCREEN.x - TRAY_W - 3, 3)
	tray.size = Vector2(TRAY_W, TAB_H)
	_taskbar.add_child(tray)
	_tray_net = TextureRect.new()
	_tray_net.position = Vector2(4, 12)
	_tray_net.texture = _net_icon()
	_tray_net.tooltip_text = "Connected to Bohemia Online at 33,600 bps"
	_tray_net.visible = false
	tray.add_child(_tray_net)
	_money = Label.new()
	_money.position = Vector2(20, 4)
	_money.size = Vector2(88, 14)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money.add_theme_color_override("font_color", Color8(0, 100, 0))
	_money.add_theme_font_override("font", T.FONT_BOLD)
	_money.tooltip_text = "The camp's money"
	_money.mouse_filter = Control.MOUSE_FILTER_PASS
	tray.add_child(_money)
	_clock = Label.new()
	_clock.text = "09:00"
	# The till over the clock, both right-aligned.
	_clock.position = Vector2(20, 21)
	_clock.size = Vector2(88, 14)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.mouse_filter = Control.MOUSE_FILTER_PASS
	tray.add_child(_clock)


func _make_tab_button(i: int, pos: Vector2, sz: Vector2) -> Control:
	var id := str(TABS[i][0])
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("hover", false)
	c.set_meta("down", false)
	c.tooltip_text = _tab_tip(id)
	c.mouse_entered.connect(func():
		c.set_meta("hover", true)
		c.queue_redraw())
	c.mouse_exited.connect(func():
		c.set_meta("hover", false)
		c.set_meta("down", false)
		c.queue_redraw())
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_close_start_menu()
			if _tab != id:
				play("click", -12.0)
			_select_tab(id)
			c.accept_event()
	)
	var tex := icon(str(TABS[i][2]), false)
	c.draw.connect(func(): _draw_tab(c, i, tex))
	return c


func _tab_tip(id: String) -> String:
	var i := _tab_index(id)
	var name := str(TAB_TITLES.get(id, id))
	var page: Control = _pages.get(id)
	if page != null and is_instance_valid(page) and str(page.title) != "" and str(page.title) != name:
		name = str(page.title)
	return "%s   (key %d)" % [name, (i + 1) % 10]


func _tab_available(id: String) -> bool:
	if id in INSTALL_TABS and not _is_program_unlocked(id):
		return false
	if id == "builder" and not _is_day:
		return false
	return true


func _draw_tab(c: Control, i: int, tex: Texture2D) -> void:
	var id := str(TABS[i][0])
	var on := id == _tab
	var hov := bool(c.get_meta("hover"))
	var r := Rect2(Vector2.ZERO, c.size)
	# Plain: raised, lit when the mouse is on it, pressed in when it is the one open.
	var flashing := _flash.has(id) and int(float(_flash[id]) * 2.0) % 2 == 1
	if on:
		c.draw_style_box(T.box("pressed", Color8(232, 232, 232), Vector4.ZERO), r)
	elif flashing:
		# Wants you: the button in the title bar's colour.
		c.draw_style_box(T.box("raised", T.NAVY, Vector4.ZERO), r)
	else:
		c.draw_style_box(T.box("raised", Color8(214, 220, 236) if hov else T.FACE, Vector4.ZERO), r)
	var o := Vector2(1, 1) if on else Vector2.ZERO
	var avail := _tab_available(id)
	var ix := floorf((r.size.x - 32) * 0.5)
	c.draw_texture_rect(tex, Rect2(Vector2(ix, 4) + o, Vector2(32, 32)), false, Color.WHITE if avail else Color(1, 1, 1, 0.4))
	# The key, in the icon's corner.
	_pixel_text(c, str((i + 1) % 10), Vector2(3, r.size.y - 8) + o, T.WHITE, T.NAVY if avail else T.SHADOW)
	if id == "builder" and not _is_day and _is_program_unlocked("builder"):
		# The moon: closed for the night.
		var m := Vector2(r.size.x - 9, 7) + o
		c.draw_circle(m, 4.0, Color8(250, 220, 90))
		c.draw_circle(m + Vector2(2, -1), 3.5, T.FACE if not on else Color8(232, 232, 232))
	var badge: Array = _badges.get(id, [])
	if not badge.is_empty():
		var txt := str(badge[0])
		var bw := txt.length() * 4 + 3
		var br := Rect2(r.size.x - bw - 1, 0, bw, 9)
		c.draw_rect(br, T.DARK)
		c.draw_rect(br.grow(-1), badge[1])
		_pixel_text(c, txt, br.position + Vector2(2, 2), T.WHITE, Color(0, 0, 0, 0))


## Digits (and a few marks) 3x5, for the keys and the badges.
const PIX_GLYPHS := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
	"4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001010010010",
	"8": "111101111101111", "9": "111101111001111", "!": "010010010000010", "+": "000010111010000",
	"$": "011110010011110",
}


func _pixel_text(c: CanvasItem, s: String, at: Vector2, fg: Color, bg: Color) -> void:
	if bg.a > 0.0:
		c.draw_rect(Rect2(at - Vector2(1, 1), Vector2(s.length() * 4 + 1, 7)), bg)
	var x := at.x
	for ch in s:
		var g := str(PIX_GLYPHS.get(ch, ""))
		for k in g.length():
			if g[k] == "1":
				c.draw_rect(Rect2(x + k % 3, at.y + k / 3, 1, 1), fg)
		x += 4


## What each tab wants of you, polled once a second.
func _refresh_badges() -> void:
	var b := {}
	var unread := EmailManager.get_unread_count() if EmailManager != null else 0
	if unread > 0:
		b["mail"] = [str(mini(unread, 99)), Color8(200, 0, 0)]
	var m := main_node()
	if m != null and m.has_method("get_electricity_ui_snapshot") and _is_program_unlocked("camp_status"):
		var snap: Dictionary = m.get_electricity_ui_snapshot()
		var od := int(snap.get("overdue_count", 0))
		var un := int(snap.get("unpaid_count", 0))
		if bool(snap.get("power_cut_active", false)) or od > 0:
			b["camp_status"] = [str(maxi(1, od)), Color8(200, 0, 0)]
		elif un > 0:
			b["camp_status"] = [str(un), Color8(176, 112, 0)]
	if GuestManager != null and GuestManager.has_method("get_arrivals"):
		var at_gate := 0
		var coming := 0
		for r in GuestManager.get_arrivals():
			if r is Dictionary:
				if bool(r.get("at_gate", false)):
					at_gate += 1
				else:
					coming += 1
		if at_gate > 0:
			b["guestrack"] = [str(at_gate), Color8(200, 0, 0)]
		elif coming > 0:
			b["guestrack"] = [str(coming), Color8(0, 0, 160)]
	for id in INSTALL_TABS:
		if not _is_program_unlocked(id) and not b.has(id):
			b[id] = ["+", Color8(0, 120, 0)]
	# Goggle: reviews posted since the Reviews tab was last looked at.
	var g = m.get("_goggle") if m != null else null
	if g != null:
		var newest := 0
		for e in g.reviews:
			newest = maxi(newest, int(e["id"]))
		if _tab == "reviews":
			_reviews_seen = newest
		elif _reviews_seen >= 0 and newest > _reviews_seen:
			var fresh := 0
			var low := false
			for e in g.reviews:
				if int(e["id"]) > _reviews_seen:
					fresh += 1
					low = low or int(e["stars"]) <= 2
			b["reviews"] = [str(mini(fresh, 99)), Color8(200, 0, 0) if low else Color8(0, 120, 0)]
		elif _reviews_seen < 0:
			_reviews_seen = newest
	var a = app_of("jobs")
	if a != null and a.has_method("badge"):
		var jb: Array = a.badge()
		if not jb.is_empty():
			b["jobs"] = jb
	if b != _badges:
		# A count that went up (or a new one) flashes its tab, unless it is the open one.
		for id in b:
			var was: Array = _badges.get(id, [])
			var now_n := int(str(b[id][0])) if str(b[id][0]).is_valid_int() else 0
			var was_n := int(str(was[0])) if not was.is_empty() and str(was[0]).is_valid_int() else 0
			if now_n > was_n and id != _tab and _state == Boot.DESKTOP and _reveal_t < 0.0:
				_flash[id] = FLASH_SEC
		_badges = b
		for k in _tab_buttons:
			(_tab_buttons[k] as Control).queue_redraw()


func _refresh_tray() -> void:
	if _tray_net != null:
		_tray_net.visible = _online


func _on_email_received(_mail: Dictionary) -> void:
	_refresh_badges()
	if _tab != "mail":
		_flash["mail"] = FLASH_SEC
	play("mail", -6.0)
	_refresh_mail_windows()


func _refresh_mail_windows() -> void:
	var a = app_of("mail")
	if a != null and a.has_method("refresh"):
		a.refresh()


const MENU_SLIDE_SEC := 0.12
const MENU_SLIDE_STEPS := 5


func _tick_menu_slide(delta: float) -> void:
	if _menu_slide.is_empty():
		return
	var panel = _menu_slide.get("panel")
	if panel == null or not is_instance_valid(panel):
		_menu_slide = {}
		return
	_menu_slide["t"] = float(_menu_slide["t"]) + delta
	var k := floorf(clampf(float(_menu_slide["t"]) / MENU_SLIDE_SEC, 0.0, 1.0) * MENU_SLIDE_STEPS) / MENU_SLIDE_STEPS
	(panel as Control).position.y = floorf(float(_menu_slide["h"]) * (1.0 - k))
	if k >= 1.0:
		_menu_slide = {}


func _build_start_menu() -> void:
	_start_menu = Control.new()
	_start_menu.visible = false
	_start_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_start_menu)


func _open_start_menu() -> void:
	for c in _start_menu.get_children():
		c.queue_free()
	var entries := [
		["files", "Documents", "documents"],
		["display", "Display...", "computer"],
		["help", "Help", "help"],
		["run", "Run...", "run"],
		["-", "", ""],
		["shutdown", "Shut Down...", "shutdown"],
	]
	var h := 6
	for e in entries:
		h += 8 if e[0] == "-" else 30
	# It slides up out of the taskbar in a few steps (the menu animation of the time);
	# the clip is the menu's whole place, so clicks are caught there from the start.
	var clip := Control.new()
	clip.position = Vector2(0, SCREEN.y - TASKBAR_H - h)
	clip.size = Vector2(166, h)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_PASS
	_start_menu.add_child(clip)
	var panel := _menu_panel(Vector2(0, h), Vector2(166, h), true)
	clip.add_child(panel)
	_menu_slide = {"panel": panel, "h": float(h), "t": 0.0}
	play("click", -18.0)
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
		var item := _menu_item(str(e[1]), icon(str(e[2])), Vector2(24, y), Vector2(139, 30), false, 32)
		panel.add_child(item)
		var id := str(e[0])
		item.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_start_action(id)
		)
		y += 30
	_start_menu.visible = true
	_start_btn.queue_redraw()
	_start_menu.move_to_front()
	_cursor.move_to_front()


func _close_start_menu() -> void:
	if _start_menu == null:
		return
	_start_menu.visible = false
	if _start_btn != null:
		_start_btn.queue_redraw()


func _start_action(id: String) -> void:
	_close_start_menu()
	match id:
		"files":
			open_app("files", {"path": "C:\\VERA"})
		"display":
			open_app("display")
		"help":
			message_box("Okna Help", "Help is not installed.\n\nThe keys 1 to 9 switch between your programs.\nInsert the Okna 98 CD-ROM for the rest.", "info")
		"run":
			_open_run_dialog()
		"shutdown":
			message_box("Shut Down Okna", "Are you sure you want to shut down the computer?", "question", ["Yes", "No"], func(b: String):
				if b == "Yes":
					_shutdown()
			)


func _open_run_dialog() -> void:
	var win = _make_dialog("run", "Run", null, Rect2(Vector2(20, 300), Vector2(330, 130)))
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
	edit.grab_focus.call_deferred()


func _run_command(cmd: String) -> void:
	match cmd:
		"", "CANCEL":
			return
		"NOTEPAD", "NOTEPAD.EXE", "EXPLORER", "EXPLORER.EXE":
			open_app("files")
		"MINES", "MINES.EXE", "WINMINE":
			open_app("mines")
		"CAMPMAIL", "CAMPMAIL.EXE":
			open_app("mail")
		"BEETER", "BEETER.EXE", "BEETERNET":
			open_app("browser")
		"BUILDER", "BUILDER.EXE":
			open_app("builder")
		"CAMPSTAT", "CAMPSTAT.EXE":
			open_app("camp_status")
		"GUESTRAK", "GUESTRAK.EXE", "GUESTRACK":
			open_app("guestrack")
		"C:", "C:\\":
			open_app("files", {"path": "C:\\"})
		"COMMAND", "COMMAND.COM", "CMD":
			message_box("COMMAND.COM", "Not enough memory to run COMMAND.COM.\n\nClose some programs and try again.", "error")
		"REGEDIT", "REGEDIT.EXE":
			message_box("Registry Editor", "Registry editing has been disabled by your administrator.", "error")
		_:
			if FILES.TEXTS.has(cmd):
				open_app("files", {"path": _dir_of_text(cmd), "file": cmd})
			else:
				message_box(cmd, "Cannot find the file '%s' (or one of its components).\nMake sure the path and filename are correct." % cmd.to_lower(), "error")


func _dir_of_text(file: String) -> String:
	for d in FILES.DIRS:
		if (FILES.DIRS[d] as Array).has(file):
			return str(d)
	for id in FILES.PROGRAM_DIRS:
		if (FILES.PROGRAM_DIRS[id][1] as Array).has(file):
			return "C:\\PROGRAM FILES\\" + str(FILES.PROGRAM_DIRS[id][0])
	return "C:\\VERA"


func _shutdown() -> void:
	_close_dialogs()
	_online = false
	play("shutdown", -6.0)
	_state = Boot.SHUTTING
	_boot_t = 0.0
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


func extras():
	return _extras


func wallpaper_path() -> String:
	return _wallpaper_path


func set_wallpaper(path: String) -> void:
	_wallpaper_path = path
	_wallpaper_tex = load(path) if path != "" and ResourceLoader.exists(path) else null
	if _pages_layer != null:
		_pages_layer.queue_redraw()


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
	# Any touch wakes the screen saver. (The room scales mouse motion down to the
	# monitor's pixels, so a slow move is under a pixel here: no threshold.)
	if _extras != null and (event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event.relative != Vector2.ZERO or event.position != _mouse))):
		var was: bool = _extras.is_saving()
		_extras.poke()
		if was:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouse:
		_mouse = event.position
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	# Any key or click during the boot hurries it on.
	if pressed:
		match _state:
			Boot.BIOS:
				_boot_t = maxf(_boot_t, BIOS_END - 0.3)
			Boot.SPLASH:
				_boot_t = maxf(_boot_t, 1.5)
			Boot.OKNA:
				_boot_t = maxf(_boot_t, 1.6)
			Boot.SAFE_OFF:
				if event is InputEventMouseButton:
					_start_boot()
	if _state != Boot.DESKTOP:
		return
	# The tabs' keys: 1-9 (and the keypad), unless you are typing or a dialog waits.
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.alt_pressed and not wants_keyboard() and not has_dialog():
		# The physical key: on a Czech keyboard the top row types +ěščřžýáí.
		var k: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		var n := -1
		if k >= KEY_1 and k <= KEY_9:
			n = k - KEY_1
		elif k == KEY_0 or event.keycode == KEY_KP_0:
			n = 9
		elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
			n = event.keycode - KEY_KP_1
		if n >= 0 and n < TABS.size():
			_close_start_menu()
			if _tab != str(TABS[n][0]):
				play("click", -12.0)
			_select_tab(str(TABS[n][0]))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and _start_menu.visible and not _point_in_start_menu(event.position) and not Rect2(_start_btn.global_position - global_position, _start_btn.size).has_point(event.position):
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
## The pointing hand over a link (the browser sets pointer_hand).
const HAND := [
	"     XX         ",
	"    X..X        ",
	"    X..X        ",
	"    X..X        ",
	"    X..XXX      ",
	"    X..X..XXX   ",
	" XX X..X..X..XX ",
	"X..XX........X.X",
	"X...X..........X",
	" X.............X",
	"  X............X",
	"  X...........X ",
	"   X..........X ",
	"   X.........X  ",
	"    X........X  ",
	"    XXXXXXXXXX  ",
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


## The text cursor over a field you can type in.
const IBEAM := [
	"XXX.XXX",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"...X...",
	"XXX.XXX",
]
## The small hourglass beside the arrow: working, but you can go on clicking.
const MINI_GLASS := [
	"XXXXXXX",
	"X.....X",
	" X...X ",
	"  X.X  ",
	" X.X.X ",
	"X..X..X",
	"XXXXXXX",
]


func _draw_cursor() -> void:
	if not _open or _state != Boot.DESKTOP:
		return
	var o := _mouse.floor()
	if _hovered_text_field():
		_draw_pattern(IBEAM, o - Vector2(3, 7), true)
		return
	if pointer_hand:
		_draw_pattern(HAND, o - Vector2(5, 0))
	else:
		_draw_pattern(ARROW, o)
	if _busy > 0:
		_draw_pattern(MINI_GLASS, o + Vector2(9, 11))


func _draw_pattern(pat: Array, o: Vector2, ink_only := false) -> void:
	for y in pat.size():
		var row: String = pat[y]
		for x in row.length():
			var ch := row[x]
			if ch == "X":
				_cursor.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), T.DARK)
			elif ch == "." and not ink_only:
				_cursor.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), T.WHITE)


func _hovered_text_field() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var c := vp.gui_get_hovered_control()
	if c is LineEdit:
		return (c as LineEdit).editable
	if c is TextEdit:
		return (c as TextEdit).editable
	return false


## Data on the line (the browser loading, the modem): the tray's two screens light up.
func net_activity() -> void:
	_net_t = 0.4


# ── small generated art ──────────────────────────────────────────────────────

static func _group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _start_logo() -> Texture2D:
	if ResourceLoader.exists(OKNA_START):
		return load(OKNA_START)
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


## The dial-up connection's two little screens; `lit` 1 or 2 lights one of them (data).
func _net_icon(lit := 0) -> Texture2D:
	var key := "net%d" % lit
	if _icon_cache.has(key):
		return _icon_cache[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for k in 2:
		var ox := 1 + k * 6
		var oy := 6 - k * 4
		var face := Color8(80, 255, 255) if lit == k + 1 else Color8(0, 128, 128)
		for x in range(ox, ox + 8):
			for y in range(oy, oy + 6):
				var edge := x == ox or x == ox + 7 or y == oy or y == oy + 5
				img.set_pixel(x, y, T.DARK if edge else face)
		img.set_pixel(ox + 3, oy + 6, T.DARK)
		img.set_pixel(ox + 4, oy + 6, T.DARK)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex


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
