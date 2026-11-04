extends Control

## gOS, the Hruska gBook's own system, drawn at its small resolution in the close-up's
## SubViewport (gbook.gd scales it up by whole numbers). All of it is one Control's _draw:
## the pattern, the desktop's icons, the windows back to front, the menu bar, the open
## menu, the system's boxes, the outline of what is being dragged, the pointer. The
## machine round it (sounds, the mouse, the screen's light) is `host`.
##
## A classic desktop of its own: menus that stay down while the button is held or open
## with a click, windows that zoom out of their icons, moved by an outline, the active
## one striped. What would change the machine asks for an administrator (gbook_apps.gd
## Auth) and fails; the words are a real system's, it never knows where it stands.

const APPS = preload("res://scripts/town/gbook_apps.gd")
const FILES = preload("res://scripts/town/gbook_files.gd")
const WIN = preload("res://scripts/town/gbook_win.gd")
const LANG = preload("res://scripts/lang.gd")

const W := 400
const H := 270
const MENU_H := 15
const ROW_H := 14
const DIR := "res://assets/textury/gbook/"
const TEXTURES := ["desktop", "dither", "pointer", "pointer_busy", "pointer_beam", "pear_menu", "pear_menu_inv", "pear_face", "pear_key",
	"hd", "trash_full", "folder", "folder_system", "panels", "doc", "key", "app_reader", "app_calc", "app_puzzle", "app_installer", "app_dialer",
	"cp_sound", "cp_date", "about", "alert_caution", "alert_stop"]

## [label, command, the key with the pear key]; [] a line.
const MENUS := [
	{"t": "", "items": [["About This gBook...", "about"], [], ["Calculator", "calc"], ["Puzzle", "puzzle"], ["Control Panels", "panels"], [], ["Restart", "restart"], ["Shut Down", "shutdown"]]},
	{"t": "File", "items": [["New Folder", "new_folder", "N"], ["Open", "open", "O"], ["Print...", "print", "P"], ["Close Window", "close", "W"], [], ["Get Info", "info", "I"]]},
	{"t": "Edit", "items": [["Undo", "undo", "Z"], [], ["Cut", "cut", "X"], ["Copy", "copy", "C"], ["Paste", "paste", "V"], ["Clear", "clear"], ["Select All", "select_all", "A"]]},
	{"t": "View", "items": [["by Icon", "by_icon"], ["by Name", "by_name"]]},
	{"t": "Special", "items": [["Clean Up", "clean_up"], ["Empty Trash...", "empty_trash"], [], ["Eject", "eject", "E"], ["Erase Disk...", "erase"], [], ["Restart", "restart"], ["Shut Down", "shutdown"]]},
]

enum { OFF, BOOT, READY, DOWN }

## The start: [second, sound]. The bar under the pear goes in uneven steps.
const BOOT_CUES := [[0.5, "chord"], [1.3, "spinup"], [2.9, "seek_b"], [3.6, "seek_a"], [4.7, "seek_b"], [5.4, "seek_a"], [6.2, "seek_b"]]
const BOOT_BAR := [[2.6, 0.04], [3.0, 0.18], [3.5, 0.26], [3.9, 0.47], [4.6, 0.52], [5.1, 0.74], [5.8, 0.91], [6.3, 1.0]]
const BOOT_PARADE := ["cp_sound", "cp_date", "app_dialer", "key"]
const BOOT_END := 6.8
const ZOOM_SEC := 0.15

## gbook.gd: sound(kind), hour(), day(), powered_down(), restarted().
var host
var state := OFF
var dirty := true
var pointer := Vector2i(W / 2, H / 2)
var windows: Array = []
var dialogs: Array = []
var desktop
## 0..7, its own sounds only: the speaker. The fan and the buttons are the case's.
var volume := 5
var alert_sound := "alert_clonk"

## The folders open when it went down: they stand open again after the start, as the man
## in eleven left his.
var _left_open: Array = ["docs"]
var _boot_t := 0.0
var _cue := 0
var _down_t := 0.0
var _restart := false
var _t := 0.0
var _tex: Dictionary = {}
var _menu := -1
var _menu_item := -1
var _menu_sticky := false
var _menu_moved := false
## Where the last clicks fell: the icons are for desktop or the front folder.
var _focus
var _held
var _drag := {}
var _busy := 0.0
var _busy_then: Callable
var _busy_seek := 0.0
var _zooms: Array = []
var _last_click := 0
var _last_at := Vector2i(-99, -99)
var _clock := ""
var _caret := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, H)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for name in TEXTURES:
		tex(str(name))
		tex(str(name) + "_16")
	desktop = APPS.Folder.new(self, "hd")
	desktop.desktop = true
	desktop.ident = "desktop"
	desktop.rect = Rect2i(0, MENU_H, W, H - MENU_H)
	desktop.items = ["hd", "trash"]
	desktop.spots = {"hd": Vector2i(W - 77, 8), "trash": Vector2i(W - 77, H - MENU_H - 52)}
	_focus = desktop


func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


func icon(c: CanvasItem, name: String, at: Vector2i, col: Color) -> void:
	var t := tex(name)
	if t != null:
		c.draw_texture(t, Vector2(at), col)


func caret_on() -> bool:
	return _caret


func changed_of(id: String) -> String:
	return FILES.changed_of(id, _day())


func date_text() -> String:
	return "%s %d" % [Season.date_long(_day()), int(Season.date_of(_day())["y"])]


func time_text() -> String:
	var h: float = host.hour() if host != null else 12.0
	return "%d:%02d" % [int(h) % 24, int((h - floorf(h)) * 60.0)]


func _day() -> int:
	return int(host.day()) if host != null else 1


func sound(kind: String) -> void:
	if host != null:
		host.sound(kind)


## The alert the Sound panel chose, as loud as the speaker is set.
func beep() -> void:
	sound(alert_sound)


# ── on and off ───────────────────────────────────────────────────────────────

func power_on() -> void:
	state = BOOT
	_boot_t = 0.0
	_cue = 0
	dirty = true


## The lid put down or the room left: whatever was held is let go; while it was still
## starting it starts over.
func power_cut() -> void:
	_menu = -1
	_drag = {}
	if _held != null:
		_held.close_held = false
		_held.zoom_held = false
		_held.held_button = -1
		_held = null
	if state != READY:
		state = OFF
	dirty = true


## The lamp behind the panel: dark until the chord, dark again going down.
func panel_lit() -> bool:
	match state:
		BOOT:
			return _boot_t >= 0.5
		READY:
			return true
	return false


func _shut_down(restart: bool) -> void:
	_restart = restart
	state = DOWN
	if host != null:
		host.going_down()
	_left_open.clear()
	for w in windows:
		if w is APPS.Folder:
			_left_open.append(w.folder)
	_down_t = 0.0
	dialogs.clear()
	windows.clear()
	_zooms.clear()
	_menu = -1
	_drag = {}
	_held = null
	dirty = true


func tick(delta: float) -> void:
	_t += delta
	match state:
		BOOT:
			var before := int(_boot_t * 8.0)
			_boot_t += delta
			while _cue < BOOT_CUES.size() and _boot_t >= float(BOOT_CUES[_cue][0]):
				sound(str(BOOT_CUES[_cue][1]))
				_cue += 1
			if int(_boot_t * 8.0) != before:
				dirty = true
			if _boot_t >= BOOT_END:
				state = READY
				busy(0.5, _reopen)
				dirty = true
			return
		DOWN:
			_down_t += delta
			if _down_t >= 0.7:
				state = OFF
				dirty = true
				if _restart:
					host.restarted()
				else:
					host.powered_down()
			return
		OFF:
			return
	if _busy > 0.0:
		_busy -= delta
		_busy_seek -= delta
		if _busy_seek <= 0.0:
			_busy_seek = 1.0
			sound("seek_b")
		if _busy <= 0.0:
			dirty = true
			if _busy_then.is_valid():
				var then := _busy_then
				_busy_then = Callable()
				then.call()
	if not _zooms.is_empty():
		dirty = true
		for z in _zooms.duplicate():
			z["t"] = float(z["t"]) + delta
			if float(z["t"]) >= ZOOM_SEC:
				_zooms.erase(z)
				if z.has("then"):
					(z["then"] as Callable).call()
	var caret := int(_t * 2.0) % 2 == 0
	if caret != _caret:
		_caret = caret
		if wants_keys():
			dirty = true
	var clock := time_text()
	if clock != _clock:
		_clock = clock
		dirty = true
	for w in windows:
		w.tick(delta)
	for d in dialogs:
		d.tick(delta)


## Waiting: the pointer is the watch, the drive ticks, clicks go nowhere; `then` after it.
func busy(seconds: float, then: Callable) -> void:
	_busy = seconds
	_busy_then = then
	_busy_seek = 0.0
	dirty = true


# ── windows ──────────────────────────────────────────────────────────────────

func front():
	return windows.back() if not windows.is_empty() else null


func is_open(id: String) -> bool:
	for w in windows:
		if w.ident == id:
			return true
	return false


func _window(id: String):
	for w in windows:
		if w.ident == id:
			return w
	return null


func _window_at(p: Vector2i):
	for i in range(windows.size() - 1, -1, -1):
		if windows[i].rect.has_point(p):
			return windows[i]
	return null


func _raise(w) -> void:
	windows.erase(w)
	windows.append(w)
	if w is APPS.Folder:
		_focus = w
	dirty = true


## A new window a step down and right of the last, kept on the screen.
func _place(w) -> void:
	var n := windows.size()
	var at := Vector2i(16 + (n % 6) * 16, MENU_H + 14 + (n % 6) * 13)
	at.x = mini(at.x, W - w.rect.size.x - 4)
	at.y = mini(at.y, H - w.rect.size.y - 4)
	w.rect.position = at


func _show(w, from_r: Rect2i) -> void:
	_place(w)
	w.from = from_r
	if from_r.size.x > 0:
		_zooms.append({"a": from_r, "b": w.rect, "t": 0.0, "opens": w.ident, "then": func() -> void: _add(w)})
	else:
		_add(w)
	dirty = true


func _add(w) -> void:
	windows.append(w)
	if w is APPS.Folder:
		_focus = w
	dirty = true


func close_window(w) -> void:
	w.closing()
	windows.erase(w)
	if _focus == w:
		_focus = desktop
	if w.from.size.x > 0:
		_zooms.append({"a": w.rect, "b": w.from, "t": 0.0})
	dirty = true


func alert(kind: String, message: String, choices: Array = [["OK", null]]) -> void:
	beep()
	dialogs.append(APPS.Alert.new(self, kind, message, choices))
	dirty = true


func ask_admin(who: String) -> void:
	dialogs.append(APPS.Auth.new(self, who))
	dirty = true


func close_dialog(d) -> void:
	dialogs.erase(d)
	dirty = true


## Keys are words now: P is a letter, not the pause menu.
func wants_keys() -> bool:
	if state != READY:
		return false
	if not dialogs.is_empty():
		return dialogs.back().focus >= 0
	var f = front()
	return f is APPS.Reader and f.editable


func open_item(id: String, from_r := Rect2i()) -> void:
	var it: Dictionary = FILES.ITEMS[id]
	var shown = _window(id)
	if shown != null:
		_raise(shown)
		return
	for z in _zooms:
		if str(z.get("opens", "")) == id:
			return
	match str(it["kind"]):
		"locked":
			alert("stop", LANG.f("The folder “%s” could not be opened, because you do not have enough access privileges.", [LANG.t(str(it["name"]))]))
		"folder":
			sound("seek_b")
			_show(APPS.Folder.new(self, id), from_r)
		"doc":
			var words := FILES.text_of(id, _day())
			busy(0.45, func() -> void: _show(APPS.Reader.new(self, id, str(it["name"]), words), from_r))
		_:
			busy(0.4, func() -> void: _show(_app(id), from_r))


func _reopen() -> void:
	for id in _left_open:
		_show(APPS.Folder.new(self, str(id)), Rect2i())


func _app(id: String):
	match id:
		"reader":
			var page = APPS.Reader.new(self, "reader", "untitled", "")
			page.editable = true
			return page
		"calc":
			return APPS.Calc.new(self)
		"puzzle":
			return APPS.Puzzle.new(self)
		"installer":
			return APPS.Installer.new(self)
		"dialer":
			return APPS.Dialer.new(self)
		"sound":
			return APPS.SoundPanel.new(self)
		"date":
			return APPS.DatePanel.new(self)
	return APPS.About.new(self)


func _selected() -> String:
	if _focus != null and not _focus.sel.is_empty():
		return str(_focus.sel[0])
	return ""


## An icon let go: moved within its own ground, nowhere else.
func drop_icon(w, id: String, by: Vector2i, p: Vector2i) -> void:
	var under = _window_at(p)
	var ground = under if under != null else desktop
	var name := LANG.t(str(FILES.ITEMS[id]["name"]))
	if under == null and desktop.item_at(p) == "trash" and id != "trash":
		alert("stop", LANG.f("The item “%s” could not be moved to the Trash, because you do not have enough access privileges.", [name]))
	elif ground == w:
		w.move_item(id, by)
	else:
		alert("stop", LANG.f("The item “%s” could not be moved, because you do not have enough access privileges.", [name]))


## Esc: the open menu or the box on top goes first (a box as by its Cancel). False when
## there is neither and it is the machine that is left.
func escape() -> bool:
	if _menu >= 0:
		_menu = -1
		dirty = true
		return true
	if dialogs.is_empty():
		return false
	if _busy <= 0.0:
		close_dialog(dialogs.back())
	return true


func _enabled(cmd: String) -> bool:
	match cmd:
		"open", "info":
			return _selected() != ""
		"close":
			return not windows.is_empty()
		"select_all", "clean_up":
			return _focus != null
		"by_icon", "by_name":
			return front() is APPS.Folder
		"print", "undo", "cut", "copy", "paste", "clear", "eject":
			return false
	return true


func _ticked(cmd: String) -> bool:
	var f = front()
	if not f is APPS.Folder:
		return false
	return (cmd == "by_name") == f.by_name and cmd in ["by_icon", "by_name"]


func _run(cmd: String) -> void:
	dirty = true
	match cmd:
		"about":
			open_item("about")
		"calc", "puzzle":
			open_item(cmd)
		"panels":
			open_item("panels")
		"new_folder":
			alert("stop", LANG.t("The folder could not be created, because you do not have enough access privileges."))
		"open":
			var id := _selected()
			if id != "":
				open_item(id, _focus.icon_rect(id) if not _focus.by_name else Rect2i())
		"close":
			if front() != null:
				close_window(front())
		"info":
			var item := _selected()
			var shown = _window("info:" + item)
			if shown != null:
				_raise(shown)
			elif item != "":
				_show(APPS.Info.new(self, item), Rect2i())
		"select_all":
			_focus.select_all()
		"by_icon", "by_name":
			front().list_view(cmd == "by_name")
		"clean_up":
			if _focus.desktop:
				_desktop_home()
			else:
				_focus.clean_up()
		"empty_trash":
			alert("caution", LANG.t("The Trash contains 1 item. It uses 4K of disk space. Are you sure you want to permanently remove it?"), [["Cancel", null], ["OK", func() -> void: busy(0.5, _trash_refused)]])
		"erase":
			ask_admin("Erase Disk")
		"restart":
			_shut_down(true)
		"shutdown":
			_shut_down(false)


func _trash_refused() -> void:
	alert("stop", LANG.f("The item “%s” could not be deleted, because you do not have enough access privileges.", [LANG.t(str(FILES.ITEMS["letter_old"]["name"]))]))


func _desktop_home() -> void:
	desktop.spots = {"hd": Vector2i(W - 77, 8), "trash": Vector2i(W - 77, H - MENU_H - 52)}


# ── the mouse and the keys (from gbook.gd, in the screen's pixels) ───────────

func move_to(p: Vector2i) -> void:
	if p == pointer:
		return
	pointer = p
	dirty = true
	if state != READY:
		return
	if _menu >= 0:
		_menu_track(p)
		return
	if not _drag.is_empty():
		return
	if _held != null:
		_held.drag_widget(p)
		_held.drag(p)


func mouse(p: Vector2i, down: bool) -> void:
	pointer = p
	dirty = true
	sound("click_down" if down else "click_up")
	if state != READY or _busy > 0.0:
		return
	if down:
		_press(p)
	else:
		_release(p)


func wheel(dir: int) -> void:
	if state != READY or _busy > 0.0 or not dialogs.is_empty():
		return
	var w = _window_at(pointer)
	if w != null:
		w.wheel(dir)
		dirty = true


func _press(p: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	var twice := now - _last_click < 450 and Vector2(p - _last_at).length() < 5.0
	_last_click = 0 if twice else now
	_last_at = p
	if _menu >= 0:
		# A menu left open by a click: the next click ends it or picks from it.
		var m := _title_at(p)
		if m == _menu or (m < 0 and _item_at(p) < 0):
			_menu = -1
		elif m >= 0:
			_menu = m
			_menu_item = -1
		_menu_sticky = false
		_menu_moved = true
		return
	if p.y < MENU_H:
		var t := _title_at(p)
		if t >= 0 and dialogs.is_empty():
			_menu = t
			_menu_item = -1
			_menu_moved = false
		return
	if not dialogs.is_empty():
		var d = dialogs.back()
		if d.rect.has_point(p):
			_held = d
			if not d.press_widget(p):
				d.press(p, twice)
		else:
			beep()
		return
	var w = _window_at(p)
	if w == null:
		_focus = desktop
		_held = desktop
		desktop.press(p, twice)
		return
	if w != front():
		_raise(w)
		if w.on_title(p):
			_drag = {"kind": "move", "win": w, "grab": p - w.rect.position}
		return
	if w.on_title(p):
		if w.closable and w.close_box().grow(1).has_point(p):
			w.close_held = true
			_held = w
			return
		if w.zoomable and w.zoom_box().grow(1).has_point(p):
			w.zoom_held = true
			_held = w
			return
		_drag = {"kind": "move", "win": w, "grab": p - w.rect.position}
		return
	if w.growable and w.grow_box().has_point(p):
		_drag = {"kind": "grow", "win": w, "grab": w.rect.end - p}
		return
	if w is APPS.Folder:
		_focus = w
	_held = w
	if not w.press_widget(p):
		w.press(p, twice)


func _release(p: Vector2i) -> void:
	if _menu >= 0:
		if _menu_sticky:
			return
		var i := _item_at(p)
		if i >= 0 and _item_on(_menu, i):
			var cmd := str(MENUS[_menu]["items"][i][1])
			_menu = -1
			_run(cmd)
		elif _title_at(p) == _menu and not _menu_moved:
			_menu_sticky = true
		else:
			_menu = -1
		return
	if not _drag.is_empty():
		var w = _drag["win"]
		if str(_drag["kind"]) == "move":
			w.rect.position = _moved_to(w, p)
		else:
			var r := _grown_to(w, p)
			w.rect = r
			w.resized()
		_drag = {}
		return
	if _held == null:
		return
	var h = _held
	_held = null
	if h.close_held:
		h.close_held = false
		if h.close_box().grow(1).has_point(p):
			close_window(h)
		return
	if h.zoom_held:
		h.zoom_held = false
		if h.zoom_box().grow(1).has_point(p):
			_toggle_zoom(h)
		return
	h.release_widget(p)
	h.release(p)


func _toggle_zoom(w) -> void:
	if w.zoom_back.size.x > 0:
		w.rect = w.zoom_back
		w.zoom_back = Rect2i()
	else:
		w.zoom_back = w.rect
		var want: Vector2i = w.best_size()
		want = Vector2i(mini(want.x, W - 8), mini(want.y, H - MENU_H - 8))
		var at := Vector2i(mini(w.rect.position.x, W - want.x - 4), mini(w.rect.position.y, H - want.y - 4))
		w.rect = Rect2i(at, want)
	w.resized()


func _moved_to(w, p: Vector2i) -> Vector2i:
	var at: Vector2i = p - (_drag["grab"] as Vector2i)
	return Vector2i(clampi(at.x, 24 - w.rect.size.x, W - 24), clampi(at.y, MENU_H, H - 12))


func _grown_to(w, p: Vector2i) -> Rect2i:
	var end: Vector2i = p + (_drag["grab"] as Vector2i)
	var s: Vector2i = end - w.rect.position
	s = Vector2i(clampi(s.x, w.min_size.x, W - w.rect.position.x - 2), clampi(s.y, w.min_size.y, H - w.rect.position.y - 2))
	return Rect2i(w.rect.position, s)


func key(ev: InputEventKey) -> void:
	if state != READY or _busy > 0.0 or not ev.pressed:
		return
	dirty = true
	var letter := OS.get_keycode_string(ev.physical_keycode)
	if ev.ctrl_pressed and letter.length() == 1:
		for m in MENUS:
			for it in m["items"]:
				if it.size() > 2 and str(it[2]) == letter and dialogs.is_empty():
					if _enabled(str(it[1])):
						_run(str(it[1]))
					else:
						beep()
					return
	if not dialogs.is_empty():
		var d = dialogs.back()
		if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			d.press_default()
		else:
			d.key_field(ev)
		return
	var f = front()
	if f != null:
		if f.key(ev):
			return
	if (ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER) and _enabled("open"):
		_run("open")


# ── menus ────────────────────────────────────────────────────────────────────

func _title_rect(i: int) -> Rect2i:
	var x := 4
	for k in i:
		x += _title_w(k)
	return Rect2i(x, 0, _title_w(i), MENU_H - 1)


func _title_w(i: int) -> int:
	if i == 0:
		return 22
	return WIN.text_w(_title(i), true) + 13


## A word that means another thing elsewhere in the game: its own line in the catalogue.
func _title(i: int) -> String:
	return TranslationServer.translate(str(MENUS[i]["t"]), "gbook")


func _title_at(p: Vector2i) -> int:
	if p.y >= MENU_H:
		return -1
	for i in MENUS.size():
		if _title_rect(i).has_point(p):
			return i
	return -1


func _item_on(m: int, i: int) -> bool:
	var it: Array = MENUS[m]["items"][i]
	return not it.is_empty() and _enabled(str(it[1]))


func _menu_rect(m: int) -> Rect2i:
	var w := 40
	for it in MENUS[m]["items"]:
		if it.is_empty():
			continue
		var iw: int = WIN.text_w(LANG.t(str(it[0])), true) + 26
		if it.size() > 2:
			iw += 30
		w = maxi(w, iw)
	var t := _title_rect(m)
	var x := mini(t.position.x, W - w - 3)
	var h := 3
	for it in MENUS[m]["items"]:
		h += 7 if it.is_empty() else ROW_H
	return Rect2i(x, MENU_H - 1, w, h)


func _item_rect(m: int, i: int) -> Rect2i:
	var r := _menu_rect(m)
	var y: int = r.position.y + 2
	for k in i:
		y += 7 if (MENUS[m]["items"][k] as Array).is_empty() else ROW_H
	return Rect2i(r.position.x + 1, y, r.size.x - 2, ROW_H)


func _item_at(p: Vector2i) -> int:
	if _menu < 0 or not _menu_rect(_menu).has_point(p):
		return -1
	var items: Array = MENUS[_menu]["items"]
	for i in items.size():
		if not (items[i] as Array).is_empty() and _item_rect(_menu, i).has_point(p):
			return i
	return -1


func _menu_track(p: Vector2i) -> void:
	var t := _title_at(p)
	if t >= 0 and t != _menu:
		_menu = t
		_menu_moved = true
	var i := _item_at(p)
	if i >= 0:
		_menu_moved = true
	_menu_item = i if i >= 0 and _item_on(_menu, i) else -1


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	WIN.fill(self, Rect2i(0, 0, W, H), Color.BLACK)
	match state:
		BOOT:
			_draw_boot()
			_draw_corners()
			return
		DOWN, OFF:
			return
	var pattern := tex("desktop")
	if pattern != null:
		draw_texture_rect(pattern, Rect2(0, 0, W, H), true)
	desktop.draw_body(self, desktop.body(), true)
	var f = front()
	for w in windows:
		w.draw(self, w == f and dialogs.is_empty())
	_draw_menu_bar()
	_draw_held()
	for d in dialogs:
		d.draw(self, d == dialogs.back())
	if _menu >= 0:
		_draw_menu(_menu)
	for z in _zooms:
		_draw_zoom(z)
	_draw_corners()
	_draw_pointer()


func _draw_menu_bar() -> void:
	WIN.fill(self, Rect2i(0, 0, W, MENU_H - 1), WIN.C_WHITE)
	WIN.fill(self, Rect2i(0, MENU_H - 1, W, 1), WIN.C_BLACK)
	for i in MENUS.size():
		var r := _title_rect(i)
		var open_now := _menu == i
		if open_now:
			WIN.fill(self, r, WIN.C_BLACK)
		if i == 0:
			icon(self, "pear_menu_inv" if open_now else "pear_menu", r.position + Vector2i(5, 1), Color.WHITE)
		else:
			WIN.text(self, r.position.x + 6, 1, _title(i), WIN.C_WHITE if open_now else WIN.C_BLACK, true)
	var clock := time_text()
	WIN.text(self, W - 8 - WIN.text_w(clock, true), 1, clock, WIN.C_BLACK, true)


func _draw_menu(m: int) -> void:
	var r := _menu_rect(m)
	WIN.fill(self, r, WIN.C_WHITE)
	WIN.frame(self, r, WIN.C_BLACK)
	WIN.fill(self, Rect2i(r.end.x, r.position.y + 2, 1, r.size.y - 1), WIN.C_BLACK)
	WIN.fill(self, Rect2i(r.position.x + 2, r.end.y, r.size.x - 1, 1), WIN.C_BLACK)
	var items: Array = MENUS[m]["items"]
	for i in items.size():
		var it: Array = items[i]
		var row := _item_rect(m, i)
		if it.is_empty():
			WIN.dots(self, Vector2i(row.position.x + 1, row.position.y + 3), Vector2i(row.end.x - 1, row.position.y + 3), WIN.C_GREY)
			continue
		var on := _enabled(str(it[1]))
		var hot := _menu_item == i
		if hot:
			WIN.fill(self, row, WIN.C_BLACK)
		var ink := WIN.C_WHITE if hot else (WIN.C_BLACK if on else WIN.C_MID)
		if _ticked(str(it[1])):
			WIN.fill(self, Rect2i(row.position.x + 4, row.position.y + 5, 4, 4), ink)
		WIN.text(self, row.position.x + 12, row.position.y + 1, LANG.t(str(it[0])), ink, true)
		if it.size() > 2:
			var x: int = row.end.x - 27
			icon(self, "pear_key", Vector2i(x, row.position.y + 2), ink if on or hot else WIN.C_MID)
			WIN.text(self, x + 10, row.position.y + 1, str(it[2]), ink, true)


func _draw_held() -> void:
	if not _drag.is_empty():
		var w = _drag["win"]
		var r: Rect2i = w.rect
		if str(_drag["kind"]) == "move":
			r.position = _moved_to(w, pointer)
		else:
			r = _grown_to(w, pointer)
		WIN.dotted_frame(self, r, WIN.C_BLACK)
		WIN.dots(self, Vector2i(r.position.x, r.position.y + WIN.TITLE_H), Vector2i(r.end.x, r.position.y + WIN.TITLE_H), WIN.C_BLACK)
		return
	if _held is APPS.Folder and _held.moved:
		var o: Rect2i = _held.held_outline(pointer)
		if o.size.x > 0:
			WIN.dotted_frame(self, o, WIN.C_BLACK)


func _draw_zoom(z: Dictionary) -> void:
	var k := clampf(float(z["t"]) / ZOOM_SEC, 0.0, 1.0)
	var a: Rect2i = z["a"]
	var b: Rect2i = z["b"]
	for i in 3:
		var q := clampf(k - float(i) * 0.14, 0.0, 1.0)
		var r := Rect2i(Vector2i(Vector2(a.position).lerp(Vector2(b.position), q)), Vector2i(Vector2(a.size).lerp(Vector2(b.size), q)))
		WIN.dotted_frame(self, r, WIN.C_BLACK)


func _draw_pointer() -> void:
	var name := "pointer"
	var hot := Vector2i(1, 1)
	if _busy > 0.0:
		name = "pointer_busy"
		hot = Vector2i(7, 7)
	elif not dialogs.is_empty() and _over_field():
		name = "pointer_beam"
		hot = Vector2i(3, 7)
	icon(self, name, pointer - hot, Color.WHITE)


func _over_field() -> bool:
	var d = dialogs.back()
	var q: Vector2i = pointer - d.body().position
	for f in d.fields:
		if (f["r"] as Rect2i).has_point(q):
			return true
	return false


## The panel's rounded corners, black like the menu bar's on the real ones.
func _draw_corners() -> void:
	for y in 3:
		var n: int = [3, 2, 1][y]
		WIN.fill(self, Rect2i(0, y, n, 1), Color.BLACK)
		WIN.fill(self, Rect2i(W - n, y, n, 1), Color.BLACK)
		WIN.fill(self, Rect2i(0, H - 1 - y, n, 1), Color.BLACK)
		WIN.fill(self, Rect2i(W - n, H - 1 - y, n, 1), Color.BLACK)
	# One dead pixel: a cheap panel, used.
	WIN.fill(self, Rect2i(317, 196, 1, 1), Color.BLACK)


func _draw_boot() -> void:
	var t := _boot_t
	if t < 0.6:
		return
	var grey := tex("dither")
	if grey != null:
		draw_texture_rect(grey, Rect2(0, 0, W, H), true)
	if t < 1.4:
		return
	if t >= BOOT_END - 0.5:
		var pattern := tex("desktop")
		if pattern != null:
			draw_texture_rect(pattern, Rect2(0, 0, W, H), true)
		WIN.fill(self, Rect2i(0, 0, W, MENU_H - 1), WIN.C_WHITE)
		WIN.fill(self, Rect2i(0, MENU_H - 1, W, 1), WIN.C_BLACK)
		icon(self, "pear_menu", Vector2i(9, 1), Color.WHITE)
		icon(self, "pointer_busy", pointer - Vector2i(7, 7), Color.WHITE)
		return
	var face := tex("pear_face")
	var fh: int = face.get_height() if face != null else 48
	var fw: int = face.get_width() if face != null else 48
	var top := 62 if t >= 2.4 else (H - fh) / 2
	icon(self, "pear_face", Vector2i((W - fw) / 2, top), Color.WHITE)
	if t < 2.4:
		return
	var box := Rect2i((W - 196) / 2, top + fh + 10, 196, 50)
	WIN.fill(self, box, WIN.C_PALE)
	WIN.frame(self, box, WIN.C_BLACK)
	WIN.frame(self, box.grow(-2), WIN.C_BLACK)
	WIN.fill(self, Rect2i(box.end.x, box.position.y + 2, 1, box.size.y - 1), WIN.C_BLACK)
	WIN.fill(self, Rect2i(box.position.x + 2, box.end.y, box.size.x - 1, 1), WIN.C_BLACK)
	var hello := LANG.t("Welcome to gOS.")
	WIN.text(self, box.position.x + (box.size.x - WIN.text_w(hello, true)) / 2, box.position.y + 10, hello, WIN.C_BLACK, true)
	var bar := Rect2i(box.position.x + 16, box.position.y + 29, box.size.x - 32, 9)
	WIN.fill(self, bar, WIN.C_WHITE)
	WIN.frame(self, bar, WIN.C_BLACK)
	var k := 0.0
	for s in BOOT_BAR:
		if t >= float(s[0]):
			k = float(s[1])
	WIN.fill(self, Rect2i(bar.position.x + 1, bar.position.y + 1, int(float(bar.size.x - 2) * k), bar.size.y - 2), WIN.C_DARK)
	for i in BOOT_PARADE.size():
		if t >= 3.0 + float(i) * 0.7:
			icon(self, str(BOOT_PARADE[i]), Vector2i(10 + i * 38, H - 42), Color.WHITE)
