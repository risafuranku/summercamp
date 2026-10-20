extends CanvasLayer

## The reception desk, close up: checking a party in, the way Papers Please did it at its
## border booth. A 480x270 picture drawn at its own resolution (Grok art in
## assets/textury/desk/, the game's pixel fonts) and scaled up by a whole number.
##
## Across the counter at the top stands whoever is next (scripts/reception/desk_room.gd
## brings them from GuestManager.get_desk_queue()). They slide their papers across: the
## identity card and the CampMail booking slip. On your side of the counter:
##   - the guest register, open at today: drop the card on it and you write the name and
##     the card number, drop the slip on it and you write persons, nights and lodging;
##   - the key board: a brass key on a hook for every tent, cabin and caravan built,
##     its name on a strip of Dymo tape stuck above the hook (green tents, red cabins,
##     blue caravans) and a pin beside it, green when the room is made up. Take the key
##     for their lodging and drop it on the counter (up there, where they stand). A key
##     for a room that is not made up comes back; so does somebody else's. New lodgings
##     get the first free hook; the label maker on the desk peels the labels off to stick
##     them elsewhere (the key moves with its label), click it again to put it down;
##   - two rubber stamps, CHECKED IN and REFUSED: pick one up, press it on the slip (or on
##     the card, for someone who has no slip);
##   - give the papers back (drop them on the counter) and they go. With CHECKED IN on
##     them only once they are written in and have their keys.
## Everything is dragged with the mouse: papers lift with a shadow, slide, drop with a
## sound. Esc or the right button stands you up; whoever is waiting keeps waiting.
##
## Across the counter is the room as it is now: a picture for the morning, the day, the
## evening and the night, for rain, fog and snow (desk_view_*.png), turning from one to
## the next in steps. At night, now and then, the night picture is wrong: something is in
## the room or at the window (desk_scare_*.png), more often the worse the night is (the
## radio's dread), until the bulb flickers and it is gone.
##
## At night someone who is not booked may come to the desk (desk_room.gd decides). He
## has no slip, and his card is not right. Writing him in and giving him a key lets him
## stay; stamping him REFUSED and giving him his card back sends him away.

signal closed
signal checked_in(guest_id: int)
signal refused(guest_id: int)
signal stranger_admitted
signal stranger_refused

const TEX := "res://assets/textury/desk/"
const SEASON = preload("res://core/systems/season.gd")
const SFX_FLICKER := "res://assets/sfx/splash/neon_sputter.mp3"
## The night scares by how bad tonight is (pressure below 0.3, below 0.6, above).
const SCARES := [["forest", "bench"], ["window", "ceiling", "bench"], ["door", "counter", "window", "ceiling"]]
const SFX := "res://assets/sfx/desk/"
const F_TYPE: FontFile = preload("res://assets/fonts/w95.fnt")
const F_TINY: FontFile = preload("res://assets/fonts/tiny5.fnt")
const F_SILK: FontFile = preload("res://assets/fonts/silkscreen.fnt")
const F_STAMP: FontFile = preload("res://assets/fonts/jersey10.fnt")

const W := 480
const H := 270
const COUNTER_Y := 104.0
const GIVE := Rect2(0, 0, 480, 116)
const DESK := Rect2(0, 116, 480, 154)
const BOOK := Rect2(4, 118, 226, 150)
const RACK := Rect2(298, 120, 178, 100)
const STAMP_SIZE := Vector2(42, 38)
const STAMP_HOME := {"in": Vector2(304, 222), "out": Vector2(360, 222)}
const CARD_SIZE := Vector2(108, 70)
const SLIP_SIZE := Vector2(88, 118)
## The key board (RACK): 8 x 3 hooks, one cell each: the label at the top, the hook
## under it, the key hanging from the hook.
const CELL := Vector2(20.5, 30)
const CELL0 := Vector2(7, 6)
const HOOK_IN_CELL := Vector2(10, 10)
## Where a key is picked up, round its hook.
const KEY_HIT := Rect2(-6, -2, 13, 24)
## Dymo tape colours by lodging kind.
const TAPE := {"tent": Color8(40, 104, 52), "cabin": Color8(170, 34, 30), "caravan": Color8(36, 66, 150)}
## The label maker on the desk, by the stamps.
const DYMO := Rect2(422, 222, 52, 42)
## The keys on their rings (Grok, assets/textury/camp/key_*.png): a brass bit key for a
## cabin, a little nickel one for a tent's padlock, a Yale with a black head for a caravan.
const KEY_TEX := {
	"cabin": "res://assets/textury/camp/key_cabin.png",
	"tent": "res://assets/textury/camp/key_tent.png",
	"caravan": "res://assets/textury/camp/key_caravan.png",
}
const ROW_Y0 := 144.0
const ROW_H := 12.0
const ROWS := 10
const HOOK_COLS := 8
const HOOK_ROWS := 3
## A board holds 24 keys; a camp with more turns pages (hook numbers run on: hook 30 is the
## second board's seventh). The tabs hang down the board's left edge.
const HOOKS_PER_PAGE := HOOK_COLS * HOOK_ROWS
const TAB_SIZE := Vector2(11, 15)
const INK := Color(0.10, 0.14, 0.46)
const INK_RED := Color(0.62, 0.06, 0.05)
const STAMP_GREEN := Color(0.12, 0.46, 0.20, 0.86)
const STAMP_RED := Color(0.70, 0.08, 0.08, 0.86)
const PAPER_TEXT := Color(0.12, 0.11, 0.10)
const OPEN_SEC := 0.22
## The register's handwriting: a 3x5 pixel hand, so a name fits its column.
const HAND := {
	"A": "010101111101101",
	"B": "110101110101110",
	"C": "011100100100011",
	"D": "110101101101110",
	"E": "111100110100111",
	"F": "111100110100100",
	"G": "011100101101011",
	"H": "101101111101101",
	"I": "111010010010111",
	"J": "001001001101010",
	"K": "101101110101101",
	"L": "100100100100111",
	"M": "101111111101101",
	"N": "110101101101101",
	"O": "010101101101010",
	"P": "110101110100100",
	"Q": "010101101110011",
	"R": "110101110101101",
	"S": "011100010001110",
	"T": "111010010010010",
	"U": "101101101101111",
	"V": "101101101101010",
	"W": "101101111111101",
	"X": "101101010101101",
	"Y": "101101010010010",
	"Z": "111001010100111",
	"0": "111101101101111",
	"1": "010110010010111",
	"2": "110001010100111",
	"3": "110001010001110",
	"4": "101101111001001",
	"5": "111100110001110",
	"6": "011100110101010",
	"7": "111001010010010",
	"8": "010101010101010",
	"9": "010101011001110",
	".": "000000000000010",
	":": "000010000010000",
	",": "000000000010100",
	"-": "000000111000000",
	"/": "001001010100100",
}

## Callable() -> Array: the key board (GuestManager.get_key_board()).
var key_board_provider: Callable
## Callable(guest_id) -> Dictionary: {ok, reason} (GuestManager.request_check_in).
var check_in_call: Callable
## Callable() -> Dictionary: the next party in the queue, or {}.
var next_guest_provider: Callable
## How bad tonight is, 0..1 (desk_room.gd: the radio's dread).
var pressure_provider: Callable

var _vp: SubViewport
var _canvas: Control
var _view: TextureRect
var _backdrop: ColorRect
var _k := 2
var _mouse := Vector2(-1, -1)
var _open_t := 0.0
var _closing_t := -1.0
var _tex: Dictionary = {}
var _audio: Array = []
var _audio_i := 0

var _guest: Dictionary = {}       # the desk row of whoever is at the counter, or {}
var _p: Dictionary = {}           # their progress (see _new_progress)
var _progress: Dictionary = {}    # guest id -> progress, kept while they wait
var _history: Array = []          # register rows: {no, name, card, persons, nights, lodging, key, day, red}
var _keys: Array = []             # the key board, refreshed while open
var _slots: Dictionary = {}       # key -> hook (0.., 24 a page): where its label and key are
var _page := 0                    # which board of keys is showing
var _labels_mode := false         # the label maker is in your hand
var _swing: Dictionary = {}       # key -> seconds it still swings on its hook
var _drag := ""                   # "card", "slip", "key:<key>"
var _drag_off := Vector2.ZERO
var _holding_stamp := ""          # "in" / "out"
var _guest_y := 0.0               # 0 = at the counter, 1 = gone below the counter
var _guest_target := 0.0
var _leave_then := ""             # what happens when the guest has walked off
var _say := ""
var _say_shown := 0.0
var _shake := 0.0
var _pen: Dictionary = {}         # {field: progress 0..1}
var _day := 1
var _t := 0.0
var _empty_t := 0.0
var _view_name := "desk_view"     # the picture across the counter
var _view_prev := ""              # the one it is turning from
var _view_mix := 1.0
var _view_poll := 0.0
var _scare := ""                  # a desk_scare_* shown instead of the night, or ""
var _scare_left := 0.0
var _flicker := 0.0               # the bulb flickering (seconds left)
var _scare_cool_until := -INF     # (day * 24 + hour) before another may show


func _init() -> void:
	layer = 140
	add_to_group("closeup")  # the hands are on it (pockets.gd)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_canvas = Control.new()
	_canvas.size = Vector2(W, H)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_all)
	_vp.add_child(_canvas)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	for i in 4:
		var a := AudioStreamPlayer.new()
		a.volume_db = -6.0
		add_child(a)
		_audio.append(a)
	for n in ["desk_top", "desk_view", "register", "id_card", "booking", "key_board", "desk_dymo", "stamp"]:
		var path: String = TEX + n + ".png"
		_tex[n] = load(path) if ResourceLoader.exists(path) else null
	get_tree().root.size_changed.connect(_layout)


# ── the outside: open, close, save ───────────────────────────────────────────

func is_open() -> bool:
	return visible and _closing_t < 0.0


func current_guest_id() -> int:
	return int(_guest.get("id", -999)) if not _guest.is_empty() else -999


## Opens at the counter with `guest` (a GuestManager desk row, or a stranger) or empty.
func open_desk(guest: Dictionary, day: int) -> void:
	_day = day
	if not visible:
		visible = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_open_t = 0.0
		_closing_t = -1.0
		_layout()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_play("book", -10.0)
		_view_name = _pick_view()
		_view_prev = ""
		_view_mix = 1.0
		_scare = ""
		_flicker = 0.0
		_refresh_keys()
		if guest.is_empty():
			_set_guest({})
		elif int(guest.get("id", -999)) != current_guest_id():
			_set_guest(guest)
		_roll_scare()
		return
	_refresh_keys()
	if guest.is_empty():
		_set_guest({})
	elif int(guest.get("id", -999)) != current_guest_id():
		_set_guest(guest)


func close_desk() -> void:
	if not visible or _closing_t >= 0.0:
		return
	_drop_everything()
	_labels_mode = false
	if not _guest.is_empty():
		_progress[current_guest_id()] = _p
	_closing_t = 0.0


func export_state() -> Dictionary:
	return {"history": _history.duplicate(true), "hooks": _slots.duplicate()}


func import_state(d: Dictionary) -> void:
	_history = (d.get("history", []) as Array).duplicate(true) if d.get("history", []) is Array else []
	_slots.clear()
	var hooks = d.get("hooks", {})
	if hooks is Dictionary:
		for k in (hooks as Dictionary).keys():
			_slots[str(k)] = int((hooks as Dictionary)[k])


func history() -> Array:
	return _history


## Co-op: the other machine's register and hooks taken in with yours (each desk wrote
## only its own check-ins). Rows go by the day, then the number each was written under,
## and are numbered again, so the two registers end the same; a hook is as either last
## put it.
func coop_merge(d: Dictionary) -> void:
	var seen := {}
	var rows: Array = []
	for r in _history + (d.get("history", []) as Array):
		if not (r is Dictionary):
			continue
		var id := "%s|%s|%s" % [str(r.get("card", "")), str(r.get("day", "")), str(r.get("name", ""))]
		if seen.has(id):
			continue
		seen[id] = true
		rows.append((r as Dictionary).duplicate())
	rows.sort_custom(func(a, b):
		if int(a.get("day", 0)) != int(b.get("day", 0)):
			return int(a.get("day", 0)) < int(b.get("day", 0))
		if int(a.get("no", 0)) != int(b.get("no", 0)):
			return int(a.get("no", 0)) < int(b.get("no", 0))
		return str(a.get("name", "")) < str(b.get("name", "")))
	for i in rows.size():
		rows[i]["no"] = i + 1
	_history = rows
	var hooks = d.get("hooks", {})
	if hooks is Dictionary:
		for k in (hooks as Dictionary).keys():
			_slots[str(k)] = int((hooks as Dictionary)[k])
	if is_open():
		_refresh_keys()


func _layout() -> void:
	if _view == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_k = maxi(1, int(floor(minf(vp.x / float(W), vp.y / float(H)))))
	_view.size = Vector2(W * _k, H * _k)
	_view.position = ((vp - _view.size) * 0.5).floor()


# ── who is at the counter ────────────────────────────────────────────────────

func _new_progress(guest: Dictionary) -> Dictionary:
	var stranger := bool(guest.get("stranger", false))
	return {
		"card_pos": Vector2(222, 186),
		"slip_pos": Vector2(206, 126),
		"card_on_desk": false,
		"slip_on_desk": false,
		"slide": 0.0,                      # 0..1 papers coming across
		"has_slip": not stranger,
		"written_card": false,
		"written_slip": false,
		"keys_given": [],
		"stamp": "",                      # "in" / "out"
		"stamp_on": "",                   # "slip" / "card"
		"stamp_at": Vector2.ZERO,         # on the paper, px
		"stamp_rot": 0.0,
		"card_back": false,
		"slip_back": false,
		"row": _history.size() + 1,
		"greeted": false,
	}


func _set_guest(guest: Dictionary) -> void:
	_guest = guest
	_drag = ""
	_holding_stamp = ""
	_pen.clear()
	if guest.is_empty():
		_p = {}
		_guest_y = 1.0
		_guest_target = 1.0
		_say_line("")
		return
	var id := int(guest.get("id", -999))
	_p = _progress.get(id, _new_progress(guest))
	_progress[id] = _p
	# The board with their key on it.
	for r in guest.get("rooms", []):
		var rk := str((r as Dictionary).get("key", ""))
		if _slots.has(rk):
			_page = _page_of(int(_slots[rk]))
			break
	_guest_y = 1.0
	_guest_target = 0.0
	if not bool(_p.get("greeted", false)):
		_p["greeted"] = true
		_say_line(_greeting())
	else:
		_say_line("We are still here.")


func _greeting() -> String:
	if bool(_guest.get("stranger", false)):
		return "..."
	var rooms: Array = _guest.get("rooms", [])
	var lodging := str((rooms[0] as Dictionary).get("label", "a tent")) if not rooms.is_empty() else "a tent"
	var n := int(_guest.get("party_size", 1))
	var lines := [
		"Good evening. %s, we booked %s." % [str(_guest.get("name", "")), lodging.to_lower()] if not _is_day() else "Hello. %s, we have a booking. %s." % [str(_guest.get("name", "")), lodging],
		"%s. %s, %d of us." % [str(_guest.get("name", "")), lodging, n],
	]
	return lines[absi(int(_guest.get("id", 0))) % lines.size()]


func _is_day() -> bool:
	var h := _hour()
	return h >= 6.0 and h < 20.0


func _hour() -> float:
	var main := get_tree().current_scene if get_tree() != null else null
	if main != null and main.get("_time_of_day_hours") != null:
		return float(main.get("_time_of_day_hours"))
	return 12.0


# ── across the counter: the hour, the weather, the night ─────────────────────

func _weather() -> Object:
	var main := get_tree().current_scene if get_tree() != null else null
	return main.get("weather_system") if main != null else null


## Which picture of the room fits the hour and the weather.
func _pick_view() -> String:
	var h := _hour()
	var name := "desk_view"
	var ws = _weather()
	var season_day := int(ws.get("season_day")) if ws != null and ws.get("season_day") != null else _day
	if h >= 20.5 or h < 5.5:
		name = "desk_view_night"
	elif SEASON.snow_cover(season_day, h) > 0.35 or (ws != null and ws.has_method("is_snowing") and ws.is_snowing()):
		name = "desk_view_snow"
	elif ws != null and ws.has_method("is_raining") and ws.is_raining():
		name = "desk_view_rain"
	elif ws != null and int(ws.get("current_weather")) == 2:
		name = "desk_view_fog"
	elif h < 8.5:
		name = "desk_view_morning"
	elif h >= 17.5:
		name = "desk_view_evening"
	return name if _view_tex(name) != null else "desk_view"


func _view_tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := TEX + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


func _update_view(delta: float) -> void:
	_view_mix = minf(1.0, _view_mix + delta * 1.2)
	_view_poll -= delta
	if _view_poll <= 0.0:
		_view_poll = 0.5
		var want := _pick_view()
		if want != _view_name and _scare == "":
			_view_prev = _view_name
			_view_name = want
			_view_mix = 0.0
	if _scare != "":
		_scare_left -= delta
		# Someone at the counter, or its time is up: the bulb flickers and it is gone.
		if _scare_left <= 0.0 or not _guest.is_empty():
			_scare = ""
			_flicker = 0.42
			_play_path(SFX_FLICKER, -14.0)
	_flicker = maxf(0.0, _flicker - delta)


## Opening the desk at night: now and then the room is not empty. The worse tonight is
## (the radio's dread: the NIGHT RISK lamps, what came tonight and how close), the likelier
## and the worse.
func _roll_scare() -> void:
	_scare = ""
	if _view_name != "desk_view_night" or not _guest.is_empty():
		return
	var now := float(_day) * 24.0 + _hour()
	if now < _scare_cool_until:
		return
	var pressure := 0.0
	if pressure_provider.is_valid():
		pressure = clampf(float(pressure_provider.call()), 0.0, 1.0)
	if randf() >= 0.04 + 0.5 * pressure:
		return
	var tier: Array = SCARES[0 if pressure < 0.3 else (1 if pressure < 0.6 else 2)]
	var pool: Array = tier.filter(func(n): return _view_tex("desk_scare_" + str(n)) != null)
	if pool.is_empty():
		return
	_scare = "desk_scare_" + str(pool.pick_random())
	_scare_left = randf_range(2.2, 4.5)
	_scare_cool_until = now + 1.5


func _say_line(text: String) -> void:
	_say = text
	_say_shown = 0.0


func _refresh_keys() -> void:
	_keys = key_board_provider.call() if key_board_provider.is_valid() else []
	# Labels follow what is built: a demolished lodging's label comes off, a new one gets
	# the first free hook (the rest stay where you stuck them).
	var present := {}
	for k in _keys:
		present[str((k as Dictionary)["key"])] = true
	for key in _slots.keys():
		if not present.has(key) or int(_slots[key]) < 0:
			_slots.erase(key)
	var taken := {}
	for key in _slots.keys():
		taken[int(_slots[key])] = true
	var free := 0
	for k in _keys:
		var key := str((k as Dictionary)["key"])
		if _slots.has(key):
			continue
		while taken.has(free):
			free += 1
		_slots[key] = free
		taken[free] = true
	_page = clampi(_page, 0, _page_count() - 1)


## Boards in use: as many as the hooks taken need (one more while labels are being moved,
## to take some over to a fresh board).
func _page_count() -> int:
	var top := 0
	for key in _slots.keys():
		top = maxi(top, int(_slots[key]))
	var n := floori(float(top) / HOOKS_PER_PAGE) + 1
	if _labels_mode:
		n += 1
	return maxi(1, n)


func _page_of(i: int) -> int:
	return floori(float(i) / HOOKS_PER_PAGE)


func _tab_rect(page: int) -> Rect2:
	return Rect2(RACK.position + Vector2(-TAB_SIZE.x + 1, 4 + page * (TAB_SIZE.y + 1)), TAB_SIZE)


func _tab_at(p: Vector2) -> int:
	if _page_count() < 2:
		return -1
	for i in mini(_page_count(), 6):
		if _tab_rect(i).has_point(p):
			return i
	return -1


func _turn_page(page: int) -> void:
	page = clampi(page, 0, _page_count() - 1)
	if page == _page:
		return
	_page = page
	_play("paper_slide", -14.0)


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# A label carried over a tab: that board comes up, to stick it there.
	if _drag.begins_with("label:") and _mouse.x >= 0.0:
		var tab := _tab_at(_mouse)
		if tab >= 0:
			_turn_page(tab)
	if not _labels_mode and _page >= _page_count():
		_page = _page_count() - 1
	if _closing_t >= 0.0:
		_closing_t += delta
		var f := 1.0 - clampf(_closing_t / (OPEN_SEC * 0.6), 0.0, 1.0)
		_set_open_fraction(f)
		if f <= 0.0:
			visible = false
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			closed.emit()
		return
	_open_t += delta
	_set_open_fraction(clampf(_open_t / OPEN_SEC, 0.0, 1.0))
	var m := (get_viewport().get_mouse_position() - _view.position) / float(_k)
	_mouse = m if Rect2(Vector2.ZERO, Vector2(W, H)).has_point(m) else Vector2(-1, -1)
	# The guest steps up to the counter, or away from it (in steps, like the sprites).
	var gspeed := 3.2
	if absf(_guest_y - _guest_target) > 0.001:
		_guest_y = move_toward(_guest_y, _guest_target, delta * gspeed)
		if _guest_y >= 1.0 and _guest_target >= 1.0 and _leave_then != "":
			_finish_leaving()
	if not _guest.is_empty() and _guest_y <= 0.05 and float(_p.get("slide", 0.0)) < 1.0:
		var was := float(_p["slide"])
		_p["slide"] = minf(1.0, was + delta * 2.4)
		if was == 0.0:
			_play("paper_slide", -6.0)
		if float(_p["slide"]) >= 1.0:
			_p["card_on_desk"] = true
			_p["slip_on_desk"] = bool(_p["has_slip"])
			_play("card_drop", -8.0)
	_say_shown = minf(float(_say.length()), _say_shown + delta * 40.0)
	_shake = maxf(0.0, _shake - delta * 6.0)
	for f in _pen.keys():
		_pen[f] = minf(1.0, float(_pen[f]) + delta * 1.4)
	_update_view(delta)
	for key in _swing.keys():
		_swing[key] = float(_swing[key]) - delta
		if float(_swing[key]) <= 0.0:
			_swing.erase(key)
	if _guest.is_empty():
		_empty_t += delta
		if _empty_t > 0.8 and next_guest_provider.is_valid():
			_empty_t = 0.0
			var nxt: Dictionary = next_guest_provider.call()
			if not nxt.is_empty():
				_set_guest(nxt)
	_cursor()
	_canvas.queue_redraw()


func _set_open_fraction(f: float) -> void:
	var step := ceilf(f * 6.0) / 6.0
	_view.scale = Vector2(1.0, maxf(0.02, step))
	_view.pivot_offset = _view.size * 0.5
	_backdrop.color = Color(0, 0, 0, 0.8 * f)


func _cursor() -> void:
	if _mouse.x < 0.0:
		return
	if _drag != "" or _holding_stamp != "":
		HandCursor.want(HandCursor.GRAB)
	elif _thing_at(_mouse) != "":
		HandCursor.want(HandCursor.POINT)


# ── input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	# Esc goes on to the pause menu (main).
	if event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _closing_t >= 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_S:
		close_desk()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and mb.pressed:
			if _mouse.x >= 0.0 and RACK.grow_individual(TAB_SIZE.x, 0, 0, 0).has_point(_mouse):
				_turn_page(_page + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _labels_mode:
				_set_labels_mode(false)
			elif _holding_stamp != "":
				_holding_stamp = ""
				_play("ink", -12.0)
			else:
				close_desk()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if _mouse.x < 0.0:
			if mb.pressed:
				close_desk()
			return
		if mb.pressed:
			_press(_mouse)
		else:
			_release(_mouse)


func _press(p: Vector2) -> void:
	if _holding_stamp != "":
		_stamp_at(p)
		return
	var hit := _thing_at(p)
	if hit == "":
		return
	if hit.begins_with("tab:"):
		_turn_page(int(hit.trim_prefix("tab:")))
		return
	if hit == "dymo":
		_set_labels_mode(not _labels_mode)
		return
	if hit.begins_with("stamp:"):
		_holding_stamp = hit.trim_prefix("stamp:")
		_play("ink", -10.0)
		return
	_drag = hit
	_drag_off = p - _thing_pos(hit)
	if hit.begins_with("label:"):
		_play("label_peel", -8.0)
	else:
		_play("paper_pick" if not hit.begins_with("key:") else "keys", -10.0)


func _release(p: Vector2) -> void:
	if _drag == "":
		return
	var what := _drag
	_drag = ""
	var pos := p - _drag_off
	if what.begins_with("label:"):
		_stick_label(what.trim_prefix("label:"), pos)
		return
	if what.begins_with("key:"):
		_drop_key(what.trim_prefix("key:"), p)
		return
	var size := CARD_SIZE if what == "card" else SLIP_SIZE
	var rect := Rect2(pos, size)
	if p.y < GIVE.end.y - 4.0:
		_give_back(what)
		return
	pos.x = clampf(pos.x, -size.x * 0.4, W - size.x * 0.6)
	pos.y = clampf(pos.y, DESK.position.y - 6.0, H - size.y * 0.35)
	_p[what + "_pos"] = pos
	_play("paper_slide", -12.0)
	if BOOK.intersects(rect) and BOOK.has_point(p):
		_write_from(what)


func _drop_everything() -> void:
	_drag = ""
	_holding_stamp = ""


## What is under the mouse, topmost first: the dragged paper, papers, keys, stamps.
func _thing_at(p: Vector2) -> String:
	var tab := _tab_at(p)
	if tab >= 0 and _drag == "":
		return "tab:%d" % tab
	# With the label maker in hand only the labels (and putting it down) answer.
	if _labels_mode:
		if DYMO.has_point(p):
			return "dymo"
		var on := _label_at(p)
		return "label:" + on if on != "" else ""
	if not (_guest.is_empty() or float(_p.get("slide", 0.0)) < 1.0):
		var order: Array = ["slip", "card"] if _top_paper() == "slip" else ["card", "slip"]
		for d in order:
			if bool(_p.get(d + "_on_desk", false)) and Rect2(_paper_pos(d), CARD_SIZE if d == "card" else SLIP_SIZE).has_point(p):
				return d
		for k in _keys:
			var kd: Dictionary = k
			if _key_on_rack(kd) and _slots.has(str(kd["key"])) and _page_of(int(_slots[str(kd["key"])])) == _page:
				var hit := KEY_HIT
				hit.position += _key_pos(str(kd["key"]))
				if hit.has_point(p):
					return "key:" + str(kd["key"])
	var stamp := _stamp_under(p)
	if stamp != "":
		return stamp
	return "dymo" if DYMO.has_point(p) else ""


func _stamp_under(p: Vector2) -> String:
	for s in STAMP_HOME.keys():
		if Rect2(STAMP_HOME[s], STAMP_SIZE).has_point(p):
			return "stamp:" + str(s)
	return ""


var _last_moved := "card"


func _top_paper() -> String:
	if _drag == "card" or _drag == "slip":
		_last_moved = _drag
	return _last_moved


func _thing_pos(id: String) -> Vector2:
	if id == "card" or id == "slip":
		return _paper_pos(id)
	if id.begins_with("key:"):
		return _key_pos(id.trim_prefix("key:"))
	if id.begins_with("label:"):
		return _key_pos(id.trim_prefix("label:"))
	return Vector2.ZERO


func _paper_pos(d: String) -> Vector2:
	if _drag == d and _mouse.x >= 0.0:
		return _mouse - _drag_off
	var at: Vector2 = _p.get(d + "_pos", Vector2.ZERO)
	var slide := float(_p.get("slide", 1.0))
	if slide < 1.0:
		# Pushed across the counter from where they stand.
		var from := Vector2(at.x + 10.0, 30.0)
		return from.lerp(at, slide).floor()
	return at


# ── the register ─────────────────────────────────────────────────────────────

func _write_from(what: String) -> void:
	var field := "written_" + what
	if bool(_p.get(field, false)):
		return
	_p[field] = true
	_pen[what] = 0.0
	_play("pen", -6.0)
	if bool(_guest.get("stranger", false)) and what == "card":
		# Nobody else is in the room. The pen is cold.
		_say_line("...")


func _row_for_current() -> Dictionary:
	var card: Dictionary = _guest.get("card", {})
	var rooms: Array = _guest.get("rooms", [])
	var labels: Array = []
	for r in rooms:
		labels.append(str((r as Dictionary).get("label", "")).to_upper().replace("TENT ", "T").replace("CABIN ", "C").replace("CARAVAN ", "V"))
	return {
		"no": int(_p.get("row", _history.size() + 1)),
		"name": "%s %s." % [str(card.get("surname", "")), str(card.get("first", "")).substr(0, 1)],
		"card": str(card.get("number", "")),
		"surname": str(card.get("surname", "")),
		"first": str(card.get("first", "")),
		"persons": str(int(_guest.get("party_size", 1))) if bool(_p.get("has_slip", true)) else "",
		"nights": str(int(_guest.get("stay_nights", 1))) if bool(_p.get("has_slip", true)) else "",
		"lodging": ", ".join(labels),
		"key": "",
		"day": _day,
		"red": bool(_guest.get("stranger", false)),
	}


# ── keys ─────────────────────────────────────────────────────────────────────

func _key_on_rack(k: Dictionary) -> bool:
	if bool(k.get("held", false)):
		return false
	if _p.is_empty():
		return true
	return not (_p.get("keys_given", []) as Array).has(str(k["key"])) and _drag != "key:" + str(k["key"])


func _key_index(key: String) -> int:
	for i in _keys.size():
		if str((_keys[i] as Dictionary)["key"]) == key:
			return i
	return -1


func _hook_pos(i: int) -> Vector2:
	return _cell_pos(i) + HOOK_IN_CELL


func _cell_pos(i: int) -> Vector2:
	var col := i % HOOK_COLS
	var row := floori(float(i) / HOOK_COLS) % HOOK_ROWS
	return (RACK.position + CELL0 + Vector2(col * CELL.x, row * CELL.y)).floor()


## Where a key hangs (its ring on the hook), or where it is being carried.
func _key_pos(key: String) -> Vector2:
	if (_drag == "key:" + key or _drag == "label:" + key) and _mouse.x >= 0.0:
		return (_mouse - _drag_off).floor()
	return _hook_pos(int(_slots.get(key, 0)))


## The key goes back on its hook (and swings there a moment).
func _hang_back(key: String, db: float) -> void:
	_swing[key] = 0.9
	_play("key_hang", db)


func _drop_key(key: String, p: Vector2) -> void:
	if p.y >= GIVE.end.y - 4.0 or _guest.is_empty():
		_hang_back(key, -8.0)
		return
	var k: Dictionary = _keys[_key_index(key)] if _key_index(key) >= 0 else {}
	if bool(_guest.get("stranger", false)):
		if not bool(k.get("ready", false)):
			_say_line("...")
			_hang_back(key, -8.0)
			return
		(_p["keys_given"] as Array).append(key)
		_play("keys", -6.0)
		return
	var wanted: Array = []
	for r in _guest.get("rooms", []):
		wanted.append(str((r as Dictionary).get("key", "")))
	if not wanted.has(key):
		var mine := str(((_guest.get("rooms", []) as Array)[0] as Dictionary).get("label", "")) if not (_guest.get("rooms", []) as Array).is_empty() else "something else"
		_say_line("That is not ours. We booked %s." % mine)
		_play("wrong", -4.0)
		_hang_back(key, -10.0)
		_shake = 1.0
		return
	if not bool(k.get("ready", false)):
		_say_line("Is it made up? We will wait until it is.")
		_play("wrong", -4.0)
		_hang_back(key, -10.0)
		return
	(_p["keys_given"] as Array).append(key)
	_play("keys", -6.0)
	if _all_keys_given():
		_say_line("Thank you.")
	else:
		_say_line("And the other one?")


# ── the labels ──────────────────────────────────────────────────────────────

func _set_labels_mode(on: bool) -> void:
	if on == _labels_mode:
		return
	_labels_mode = on
	_drag = ""
	_holding_stamp = ""
	_play("dymo" if on else "key_hang", -8.0 if on else -12.0)


## The label (or the key under it) at `p`, by its key.
func _label_at(p: Vector2) -> String:
	for key in _slots.keys():
		if _page_of(int(_slots[key])) != _page:
			continue
		var cell := Rect2(_cell_pos(int(_slots[key])), CELL)
		if cell.has_point(p):
			return str(key)
	return ""


## Sticks a label (and its key) on the hook nearest to where it was let go; a label
## already there swaps places with it. Away from the board it goes back where it was.
func _stick_label(key: String, at: Vector2) -> void:
	var best := -1
	var best_d := 15.0
	for i in range(_page * HOOKS_PER_PAGE, (_page + 1) * HOOKS_PER_PAGE):
		var d := _hook_pos(i).distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		_play("label_stick", -12.0)
		return
	var from := int(_slots.get(key, -1))
	for other in _slots.keys():
		if str(other) != key and int(_slots[other]) == best:
			_slots[other] = from
	_slots[key] = best
	_swing[key] = 0.9
	_play("label_stick", -6.0)


func _all_keys_given() -> bool:
	var given: Array = _p.get("keys_given", [])
	for r in _guest.get("rooms", []):
		if not given.has(str((r as Dictionary).get("key", ""))):
			return false
	return not (_guest.get("rooms", []) as Array).is_empty()


# ── stamps ───────────────────────────────────────────────────────────────────

func _stamp_at(p: Vector2) -> void:
	var kind := _holding_stamp
	_holding_stamp = ""
	if _guest.is_empty():
		_play("ink", -12.0)
		return
	# On the slip if it is under the stamp, else on the card.
	var target := ""
	var order: Array = [_top_paper(), "slip" if _top_paper() == "card" else "card"]
	for d in order:
		if bool(_p.get(d + "_on_desk", false)) and Rect2(_paper_pos(d), CARD_SIZE if d == "card" else SLIP_SIZE).has_point(p):
			target = d
			break
	if target == "":
		_play("ink", -12.0)
		return
	if str(_p.get("stamp", "")) != "":
		# One stamp per booking; the second goes on top, crooked.
		pass
	_p["stamp"] = kind
	_p["stamp_on"] = target
	_p["stamp_at"] = p - _paper_pos(target)
	_p["stamp_rot"] = randf_range(-0.22, 0.12)
	_shake = 1.4
	_play("stamp", -2.0)


# ── giving back ──────────────────────────────────────────────────────────────

func _give_back(what: String) -> void:
	_p[what + "_back"] = true
	_p[what + "_on_desk"] = false
	_play("paper_slide", -8.0)
	var need_slip := bool(_p.get("has_slip", true))
	var all_back := bool(_p.get("card_back", false)) and (not need_slip or bool(_p.get("slip_back", false)))
	if not all_back:
		return
	var stamp := str(_p.get("stamp", ""))
	if stamp == "":
		_bounce("Is that it? You have not stamped anything.")
		return
	if stamp == "out":
		_say_line("..." if bool(_guest.get("stranger", false)) else "We drove four hours. Fine.")
		_leave("refused")
		return
	if not bool(_p.get("written_card", false)) or (need_slip and not bool(_p.get("written_slip", false))):
		_bounce("Do you not write us in the book?")
		return
	if bool(_guest.get("stranger", false)):
		if (_p.get("keys_given", []) as Array).is_empty():
			_bounce("...")
			return
		_leave("stranger_in")
		return
	if not _all_keys_given():
		_bounce("And our key?")
		return
	var res: Dictionary = check_in_call.call(int(_guest.get("id", -1))) if check_in_call.is_valid() else {"ok": true}
	if not bool(res.get("ok", false)):
		_bounce("The room is not ready?")
		return
	_say_line("Thank you. Good night." if not _is_day() else "Thank you.")
	_leave("in")


func _bounce(line: String) -> void:
	# They push the papers back across the counter.
	_say_line(line)
	_play("wrong", -4.0)
	for d in ["card", "slip"]:
		if bool(_p.get(d + "_back", false)):
			_p[d + "_back"] = false
			_p[d + "_on_desk"] = d == "card" or bool(_p.get("has_slip", true))
			_p[d + "_pos"] = Vector2(230 + (0 if d == "card" else 22), 122)
	_play("paper_slide", -8.0)


func _leave(how: String) -> void:
	_leave_then = how
	_guest_target = 1.0
	if how == "in" or how == "stranger_in":
		var row := _row_for_current()
		var given: Array = _p.get("keys_given", [])
		row["key"] = "OK" if not given.is_empty() else ""
		_history.append(row)
	if how == "refused" and bool(_guest.get("stranger", false)):
		# He does not walk away. He is not there.
		_guest_y = 1.0
		_finish_leaving()


func _finish_leaving() -> void:
	var how := _leave_then
	_leave_then = ""
	var id := int(_guest.get("id", -999))
	var stranger := bool(_guest.get("stranger", false))
	_progress.erase(id)
	_set_guest({})
	_refresh_keys()
	match how:
		"in":
			checked_in.emit(id)
		"refused":
			if stranger:
				stranger_refused.emit()
			else:
				refused.emit(id)
		"stranger_in":
			stranger_admitted.emit()


func _play_path(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var a: AudioStreamPlayer = _audio[_audio_i]
	_audio_i = (_audio_i + 1) % _audio.size()
	a.stream = load(path)
	a.volume_db = db
	a.pitch_scale = 1.0
	a.play()


func _play(sfx: String, db: float) -> void:
	var path := SFX + sfx + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var a: AudioStreamPlayer = _audio[_audio_i]
	_audio_i = (_audio_i + 1) % _audio.size()
	a.stream = load(path)
	a.volume_db = db
	a.pitch_scale = randf_range(0.95, 1.05)
	a.play()


## Harnesses and the shot driver: do a step of a check-in as the player would.
func debug_do(step: String) -> void:
	if _guest.is_empty():
		return
	_p["slide"] = 1.0
	_p["card_on_desk"] = not bool(_p.get("card_back", false))
	_p["slip_on_desk"] = bool(_p.get("has_slip", true)) and not bool(_p.get("slip_back", false))
	match step:
		"write":
			_write_from("card")
			_write_from("slip")
		"key":
			for r in _guest.get("rooms", []):
				_drop_key(str((r as Dictionary).get("key", "")), Vector2(200, 50))
		"wrong_key":
			for k in _keys:
				var kd: Dictionary = k
				var mine := false
				for r in _guest.get("rooms", []):
					mine = mine or str((r as Dictionary).get("key", "")) == str(kd["key"])
				if not mine and not bool(kd.get("held", false)):
					_drop_key(str(kd["key"]), Vector2(200, 50))
					return
		"stamp_in", "stamp_out":
			_holding_stamp = step.trim_prefix("stamp_")
			var on := "slip" if bool(_p.get("has_slip", true)) else "card"
			_stamp_at(_paper_pos(on) + Vector2(44, 70) if on == "slip" else _paper_pos(on) + Vector2(70, 40))
		"give":
			_give_back("card")
			if bool(_p.get("has_slip", true)):
				_give_back("slip")


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw_all() -> void:
	var c := _canvas
	var sh := Vector2(roundf(sin(_t * 70.0) * _shake), 0) if _shake > 0.05 else Vector2.ZERO
	c.draw_set_transform(sh)
	_draw_booth(c)
	_draw_desk(c)
	_draw_book(c)
	_draw_rack(c)
	_draw_dymo(c)
	_draw_stamps(c)
	# Papers: the one not on top first.
	var top := _top_paper()
	var order: Array = ["slip", "card"] if top == "card" else ["card", "slip"]
	for d in order:
		_draw_paper(c, d)
	_draw_dragged_key(c)
	if _holding_stamp != "" and _mouse.x >= 0.0:
		_draw_stamp_tool(c, _holding_stamp, _mouse - STAMP_SIZE * 0.5 + Vector2(0, -6), true)
	c.draw_set_transform(Vector2.ZERO)


func _draw_booth(c: Control) -> void:
	var dark := not _is_day()
	var name := _scare if _scare != "" else _view_name
	var view: Texture2D = _view_tex(name)
	if view != null:
		# Only the night picture is dark of itself; the day one stands in tinted.
		var tint := Color(0.5, 0.5, 0.62) if dark and name == "desk_view" else Color.WHITE
		_draw_view(c, view, tint)
		# Turning from the last picture: it gives way in six steps.
		var k := floorf(_view_mix * 6.0) / 6.0
		if _view_prev != "" and k < 1.0 and _scare == "":
			var prev: Texture2D = _view_tex(_view_prev)
			if prev != null:
				_draw_view(c, prev, Color(1, 1, 1, 1.0 - k))
	else:
		c.draw_rect(Rect2(0, 0, W, COUNTER_Y + 2), Color8(92, 70, 48))
	# The bulb flickering: dark on every other step.
	if _flicker > 0.0 and int(floorf(_t * 12.0)) % 2 == 0:
		c.draw_rect(Rect2(0, 0, W, COUNTER_Y + 2), Color(0, 0, 0, 0.82))
	# Whoever is at the counter, from the chest up, big.
	if not _guest.is_empty():
		var tex: Texture2D = _guest_tex()
		if tex != null:
			var zoom := 1.75
			var gw := tex.get_width() * zoom
			var gh := tex.get_height() * zoom
			var x := floorf(176.0 - gw * 0.5)
			var y := floorf(14.0 + _guest_y * 120.0)
			var col := Color.WHITE
			if bool(_guest.get("stranger", false)):
				col = Color(0.16, 0.15, 0.16)
			elif dark:
				col = Color(0.72, 0.72, 0.82)
			# Clip at the counter: draw only what is above it.
			var vis := minf(gh, COUNTER_Y - y)
			if vis > 0.0:
				c.draw_texture_rect_region(tex, Rect2(x, y, gw, vis), Rect2(0, 0, tex.get_width(), vis / zoom), col)
		if _say != "" and _guest_y < 0.3:
			_draw_bubble(c, _say.substr(0, int(_say_shown)))
	# The counter's edge.
	c.draw_rect(Rect2(0, COUNTER_Y, W, 12), Color8(58, 36, 22))
	c.draw_rect(Rect2(0, COUNTER_Y, W, 1), Color8(120, 84, 52))
	c.draw_rect(Rect2(0, COUNTER_Y + 11, W, 1), Color8(24, 14, 8))
	if _drag != "":
		# Where the papers go back: a lighter strip along the counter.
		c.draw_rect(Rect2(0, COUNTER_Y, W, 12), Color(1, 0.9, 0.6, 0.12 + 0.06 * sin(_t * 8.0)))


func _draw_view(c: Control, view: Texture2D, tint: Color) -> void:
	var src_h := float(view.get_height()) * COUNTER_Y / float(H) * 1.6
	var src := Rect2(0, (view.get_height() - src_h) * 0.45, view.get_width(), src_h)
	c.draw_texture_rect_region(view, Rect2(0, 0, W, COUNTER_Y + 2), src, tint)


func _guest_tex() -> Texture2D:
	var path := str(_guest.get("sprite_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


func _draw_bubble(c: Control, text: String) -> void:
	var r := Rect2(262, 12, 206, 44)
	c.draw_rect(r, Color8(244, 238, 220))
	c.draw_rect(r, Color8(40, 30, 24), false, 1.0)
	for i in 6:
		c.draw_rect(Rect2(r.position.x - 6 + i, r.position.y + 18 + i, 6 - i, 1), Color8(244, 238, 220))
	c.draw_rect(Rect2(r.position.x - 6, r.position.y + 18, 1, 1), Color8(40, 30, 24))
	F_TYPE.draw_multiline_string(c.get_canvas_item(), r.position + Vector2(6, 14), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 12, 3, Color8(30, 24, 20))


func _draw_desk(c: Control) -> void:
	var top: Texture2D = _tex.get("desk_top")
	if top != null:
		var src := Rect2(0, top.get_height() * 0.38, top.get_width(), top.get_height() * 0.62)
		c.draw_texture_rect_region(top, Rect2(0, COUNTER_Y + 12, W, H - COUNTER_Y - 12), src)
	else:
		c.draw_rect(Rect2(0, COUNTER_Y + 12, W, H - COUNTER_Y - 12), Color8(70, 46, 30))


func _draw_book(c: Control) -> void:
	var tex: Texture2D = _tex.get("register")
	if tex != null:
		c.draw_texture_rect(tex, BOOK, false)
	else:
		c.draw_rect(BOOK, Color8(232, 222, 196))
	var left := BOOK.position.x + 8.0
	var right := BOOK.position.x + BOOK.size.x * 0.5 + 6.0
	var hy := BOOK.position.y + 17.0
	var head := Color(0.42, 0.18, 0.14)
	for h in [[left, "NO"], [left + 10, "NAME"], [right, "CARD NO"], [right + 38, "PERS"], [right + 56, "NTS"], [right + 70, "ROOM"], [right + 89, "KEY"]]:
		_print3(c, Vector2(float(h[0]), hy), str(h[1]), head)
	_print3(c, Vector2(BOOK.position.x + BOOK.size.x - 44, BOOK.position.y + 10), Season.date_str(_day), head)
	# The rows: the last ones written, then the one being written now.
	var rows: Array = []
	var start := maxi(0, _history.size() - (ROWS - 1))
	for i in range(start, _history.size()):
		rows.append(_history[i])
	var current := {}
	# Walking off, their line is in the history already (_leave): not a second time.
	var at_desk := not _guest.is_empty() and _leave_then == ""
	if at_desk and (bool(_p.get("written_card", false)) or bool(_p.get("written_slip", false))):
		current = _row_for_current()
	for i in rows.size():
		_draw_row(c, i, rows[i], 1.0, 1.0)
	if not current.is_empty():
		var a := float(_pen.get("card", 1.0)) if bool(_p.get("written_card", false)) else 0.0
		var b := float(_pen.get("slip", 1.0)) if bool(_p.get("written_slip", false)) else 0.0
		_draw_row(c, rows.size(), current, a, b)
	elif at_desk:
		# The empty line waiting for them.
		var y := ROW_Y0 + rows.size() * ROW_H
		c.draw_rect(Rect2(BOOK.position.x + 6, y - 9, BOOK.size.x - 12, ROW_H - 1), Color(1.0, 0.95, 0.4, 0.10 + 0.05 * sin(_t * 4.0)))


func _draw_row(c: Control, i: int, row: Dictionary, left_k: float, right_k: float) -> void:
	var y := ROW_Y0 + i * ROW_H
	var red := bool(row.get("red", false)) and int(row.get("day", 0)) < _day
	var ink := INK_RED if red else INK
	var left := BOOK.position.x + 8.0
	var right := BOOK.position.x + BOOK.size.x * 0.5 + 6.0
	_hand(c, Vector2(left, y), str(row.get("no", "")), ink, 1.0, i * 31)
	if left_k > 0.0:
		_hand(c, Vector2(left + 10, y), str(row.get("name", "")), ink, left_k, i * 31 + 3)
		_hand(c, Vector2(right, y), str(row.get("card", "")), ink, left_k, i * 31 + 7)
	if right_k > 0.0:
		_hand(c, Vector2(right + 42, y), str(row.get("persons", "")), ink, right_k, i * 31 + 11)
		_hand(c, Vector2(right + 58, y), str(row.get("nights", "")), ink, right_k, i * 31 + 13)
		_hand(c, Vector2(right + 70, y), str(row.get("lodging", "")), ink, right_k, i * 31 + 17)
	if str(row.get("key", "")) != "":
		# A tick in the key column.
		var tx := right + 92.0
		for k in 3:
			c.draw_rect(Rect2(tx + k, y - 3 + k, 1, 1), ink)
		for k in 5:
			c.draw_rect(Rect2(tx + 3 + k, y - 1 - k, 1, 1), ink)


## Handwriting: the 3x5 hand (HAND), every letter nudged a pixel up or down, revealed
## left to right as the pen goes. `at.y` is the baseline.
func _hand(c: Control, at: Vector2, text: String, col: Color, k: float, salt: int) -> void:
	var n := int(ceilf(float(text.length()) * clampf(k, 0.0, 1.0)))
	var x := at.x
	for i in n:
		var ch := text.substr(i, 1).to_upper()
		var dy := -1.0 if ((salt + i * 3) % 5) == 0 else 0.0
		x += _glyph3(c, Vector2(x, at.y - 5.0 + dy), ch, col)


## The same face, upright: the printed column heads.
func _print3(c: Control, at: Vector2, text: String, col: Color) -> void:
	var x := at.x
	for i in text.length():
		x += _glyph3(c, Vector2(x, at.y - 5.0), text.substr(i, 1).to_upper(), col)


## Draws one 3x5 letter with its top-left at `top`; returns the advance.
func _glyph3(c: Control, top: Vector2, ch: String, col: Color) -> float:
	if ch == " ":
		return 3.0
	var bits := str(HAND.get(ch, ""))
	if bits.is_empty():
		return 2.0
	for b in 15:
		if bits[b] == "1":
			c.draw_rect(Rect2(top.x + float(b % 3), top.y + floorf(float(b) / 3.0), 1, 1), col)
	return 4.0


func _draw_rack(c: Control) -> void:
	var board: Texture2D = _tex.get("key_board")
	if board != null:
		c.draw_texture_rect(board, RACK, false)
	else:
		c.draw_rect(RACK, Color8(58, 34, 20))
		c.draw_rect(RACK.grow(-3), Color8(84, 52, 30))
	# The label maker in hand: the board catches the light from the window (in steps).
	if _labels_mode:
		var pulse := 0.06 + 0.04 * float(int(_t * 4.0) % 2)
		c.draw_rect(RACK.grow(-2), Color(1.0, 0.92, 0.7, pulse))
	var by_slot := {}
	for k in _keys:
		var key := str((k as Dictionary)["key"])
		if _slots.has(key):
			by_slot[int(_slots[key])] = k
	var dragged_label := _drag.trim_prefix("label:") if _drag.begins_with("label:") else ""
	_draw_tabs(c)
	for i in range(_page * HOOKS_PER_PAGE, (_page + 1) * HOOKS_PER_PAGE):
		var hook := _hook_pos(i)
		var cell := _cell_pos(i)
		# The brass cup hook, screwed into the board.
		c.draw_rect(Rect2(hook + Vector2(-1, -2), Vector2(2, 1)), Color8(96, 66, 24))
		c.draw_rect(Rect2(hook + Vector2(-1, -1), Vector2(1, 3)), Color8(214, 176, 82))
		c.draw_rect(Rect2(hook + Vector2(0, 1), Vector2(2, 1)), Color8(150, 112, 44))
		if not by_slot.has(i):
			if _labels_mode:
				# Where a label could go: the old glue's outline.
				c.draw_rect(Rect2(cell + Vector2(3, 0), Vector2(15, 7)), Color(0, 0, 0, 0.18), false, 1.0)
			continue
		var k: Dictionary = by_slot[i]
		var key := str(k["key"])
		if key == dragged_label:
			c.draw_rect(Rect2(cell + Vector2(3, 0), Vector2(15, 7)), Color(0, 0, 0, 0.18), false, 1.0)
			continue
		var lift := _labels_mode and _mouse.x >= 0.0 and Rect2(cell, CELL).has_point(_mouse) and _drag == ""
		_draw_label(c, hook, k, lift)
		# The pin beside the hook: green, the room is made up; red, it is not.
		var pin := Color8(70, 200, 86) if bool(k.get("ready", false)) else Color8(224, 52, 40)
		var pp := hook + Vector2(6, -2)
		c.draw_rect(Rect2(pp + Vector2(1, 1), Vector2(2, 2)), Color(0, 0, 0, 0.45))
		c.draw_rect(Rect2(pp, Vector2(2, 2)), pin)
		c.draw_rect(Rect2(pp, Vector2(1, 1)), pin.lightened(0.55))
		if _key_on_rack(k) and _drag != "key:" + key:
			_draw_key(c, hook, k)


## Card tabs down the board's left edge, one a board, its number on it; the one showing
## sits out against the board, a board holding a key that is not made up has a red pin.
func _draw_tabs(c: Control) -> void:
	var n := _page_count()
	if n < 2:
		return
	var unready := {}
	for k in _keys:
		var key := str((k as Dictionary)["key"])
		if _slots.has(key) and not bool((k as Dictionary).get("ready", false)):
			unready[_page_of(int(_slots[key]))] = true
	for i in mini(n, 6):
		var r := _tab_rect(i)
		var on := i == _page
		if not on:
			r.position.x += 2
		c.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.4))
		var face := Color8(226, 214, 180) if on else Color8(176, 160, 124)
		if _mouse.x >= 0.0 and r.has_point(_mouse) and not on:
			face = face.lightened(0.15)
		c.draw_rect(r, face)
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), face.lightened(0.3))
		c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), face.darkened(0.35))
		c.draw_string(F_TINY, r.position + Vector2(3, 10), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PAPER_TEXT)
		if unready.has(i):
			c.draw_rect(Rect2(r.position + Vector2(7, 2), Vector2(2, 2)), Color8(224, 52, 40))


var _key_tex: Dictionary = {}


func _draw_key(c: Control, ring: Vector2, k: Dictionary, lifted := false) -> void:
	# Just the key, its ring on the hook.
	var kind := str(k.get("kind", ""))
	if not _key_tex.has(kind):
		var path: String = KEY_TEX.get(kind, KEY_TEX["cabin"])
		_key_tex[kind] = load(path) if ResourceLoader.exists(path) else null
	var t: Texture2D = _key_tex[kind]
	if t == null:
		return
	var w := t.get_width()
	var h := t.get_height()
	var top := (ring - Vector2(floorf(w * 0.5), 1)).floor()
	if lifted:
		c.draw_texture(t, top + Vector2(3, 4), Color(0, 0, 0, 0.3))
		c.draw_texture(t, top)
		return
	# Swinging: below the ring the key leans a pixel one way, then the other (a row at a
	# time, the further down the more).
	var lean := _lean(str(k.get("key", "")))
	for y in h:
		var dx := roundf(lean * minf(1.0, float(y - 3) / 8.0)) if y >= 4 else 0.0
		c.draw_texture_rect_region(t, Rect2(top + Vector2(dx, y), Vector2(w, 1)), Rect2(0, y, w, 1))


func _draw_dragged_key(c: Control) -> void:
	if _drag.begins_with("label:"):
		var lk := _drag.trim_prefix("label:")
		var li := _key_index(lk)
		if li >= 0:
			var at := _key_pos(lk)
			_draw_label(c, at, _keys[li], true)
			if _key_on_rack(_keys[li]):
				_draw_key(c, at, _keys[li], true)
		return
	if not _drag.begins_with("key:"):
		return
	var key := _drag.trim_prefix("key:")
	var i := _key_index(key)
	if i >= 0:
		_draw_key(c, _key_pos(key), _keys[i], true)


## How far (px) a key that was just hung back leans, twelve steps a second.
func _lean(key: String) -> float:
	var left := float(_swing.get(key, 0.0))
	if left <= 0.0:
		return 0.0
	var step := floorf(_t * 12.0)
	return (1.0 if int(step) % 2 == 0 else -1.0) * minf(1.0, left * 1.6)


## A strip of Dymo tape above the hook: the lodging's short name punched into it, the
## letters stretched white.
func _draw_label(c: Control, hook: Vector2, k: Dictionary, lifted := false) -> void:
	var text := str(k.get("short", k.get("key", ""))).to_upper()
	var tw := F_TINY.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := maxf(11.0, tw + 4.0)
	var r := Rect2((hook + Vector2(-floorf(w * 0.5), -HOOK_IN_CELL.y)).floor(), Vector2(w, 7))
	if lifted:
		c.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.3))
		r.position += Vector2(-1, -1)
	var tape: Color = TAPE.get(str(k.get("kind", "")), Color8(30, 30, 30))
	c.draw_rect(r, tape)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), tape.lightened(0.3))
	c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), tape.darkened(0.4))
	var tp := r.position + Vector2(floorf((w - tw) * 0.5), 6)
	F_TINY.draw_string(c.get_canvas_item(), tp + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, tape.darkened(0.45))
	F_TINY.draw_string(c.get_canvas_item(), tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(240, 238, 230))


## The label maker on the desk; picked up, it is lifted off with its shadow.
func _draw_dymo(c: Control) -> void:
	var r := DYMO
	var tex: Texture2D = _tex.get("desk_dymo")
	if _labels_mode:
		c.draw_rect(Rect2(r.position + Vector2(5, 6), r.size - Vector2(6, 8)), Color(0, 0, 0, 0.3))
		r.position += Vector2(-2, -3)
	if tex != null:
		c.draw_texture_rect(tex, r, false)
	else:
		c.draw_rect(Rect2(r.position + Vector2(6, 10), Vector2(40, 18)), Color8(60, 62, 66))
		c.draw_rect(Rect2(r.position + Vector2(10, 4), Vector2(16, 16)), Color8(24, 24, 28))
		c.draw_rect(Rect2(r.position + Vector2(44, 16), Vector2(8, 5)), TAPE["cabin"])


func _draw_stamps(c: Control) -> void:
	for s in STAMP_HOME.keys():
		if _holding_stamp == s:
			continue
		_draw_stamp_tool(c, str(s), STAMP_HOME[s], false)


func _draw_stamp_tool(c: Control, kind: String, pos: Vector2, lifted: bool) -> void:
	pos = pos.floor()
	if lifted:
		c.draw_rect(Rect2(pos + Vector2(6, 10), STAMP_SIZE - Vector2(6, 6)), Color(0, 0, 0, 0.28))
	var tex: Texture2D = _tex.get("stamp")
	var tint := Color(0.75, 1.0, 0.78) if kind == "in" else Color(1.0, 0.72, 0.7)
	if tex != null:
		c.draw_texture_rect(tex, Rect2(pos, STAMP_SIZE), false, tint)
	else:
		c.draw_rect(Rect2(pos + Vector2(14, 0), Vector2(14, 22)), Color8(90, 60, 40))
		c.draw_rect(Rect2(pos + Vector2(4, 22), Vector2(34, 12)), Color8(40, 40, 40))
	var label := "CHECKED IN" if kind == "in" else "REFUSED"
	var w := F_TINY.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	F_TINY.draw_string(c.get_canvas_item(), pos + Vector2(floorf((STAMP_SIZE.x - w) * 0.5), STAMP_SIZE.y + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(240, 230, 200))


func _draw_paper(c: Control, d: String) -> void:
	if _guest.is_empty():
		return
	var slide := float(_p.get("slide", 0.0))
	if slide <= 0.0 or (slide >= 1.0 and not bool(_p.get(d + "_on_desk", false))):
		return
	if d == "slip" and not bool(_p.get("has_slip", true)):
		return
	var pos := _paper_pos(d).floor()
	var size := CARD_SIZE if d == "card" else SLIP_SIZE
	var lifted := _drag == d
	c.draw_rect(Rect2(pos + (Vector2(5, 6) if lifted else Vector2(2, 2)), size), Color(0, 0, 0, 0.34 if lifted else 0.22))
	if d == "card":
		_draw_card(c, pos)
	else:
		_draw_slip(c, pos)
	if str(_p.get("stamp_on", "")) == d:
		_draw_stamp_mark(c, pos + (_p.get("stamp_at", Vector2.ZERO) as Vector2), str(_p.get("stamp", "")), float(_p.get("stamp_rot", 0.0)))


func _draw_card(c: Control, pos: Vector2) -> void:
	var tex: Texture2D = _tex.get("id_card")
	if tex != null:
		c.draw_texture_rect(tex, Rect2(pos, CARD_SIZE), false)
	else:
		c.draw_rect(Rect2(pos, CARD_SIZE), Color8(206, 222, 196))
		c.draw_rect(Rect2(pos, CARD_SIZE), Color8(120, 130, 110), false, 1.0)
	var card: Dictionary = _guest.get("card", {})
	var ci := c.get_canvas_item()
	F_SILK.draw_string(ci, pos + Vector2(50, 11), "IDENTITY CARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(60, 70, 60))
	# The photo: the guest's own face, washed out, or nothing at all.
	var photo := Rect2(pos + Vector2(12, 18), Vector2(33, 35))
	var tex2 := _guest_tex()
	if bool(_guest.get("stranger", false)):
		c.draw_rect(photo.grow(-1), Color8(18, 16, 16))
	elif tex2 != null:
		var src := Rect2(tex2.get_width() * 0.14, 0, tex2.get_width() * 0.72, tex2.get_width() * 0.72 * 35.0 / 33.0)
		c.draw_texture_rect_region(tex2, photo.grow(-2), src, Color(0.86, 0.84, 0.78))
	var lab := Color8(90, 100, 90)
	var val := PAPER_TEXT
	var x := pos.x + 52.0
	F_TINY.draw_string(ci, Vector2(x, pos.y + 20), "SURNAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, lab)
	F_SILK.draw_string(ci, Vector2(x, pos.y + 27), str(card.get("surname", "")), HORIZONTAL_ALIGNMENT_LEFT, 54, 8, val)
	F_TINY.draw_string(ci, Vector2(x, pos.y + 34), "NAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, lab)
	F_SILK.draw_string(ci, Vector2(x, pos.y + 41), str(card.get("first", "")), HORIZONTAL_ALIGNMENT_LEFT, 54, 8, val)
	F_TINY.draw_string(ci, Vector2(x, pos.y + 49), "BORN %s" % str(card.get("born", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, val)
	F_TINY.draw_string(ci, Vector2(x, pos.y + 56), "VALID %s" % str(card.get("valid", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, val)
	F_TINY.draw_string(ci, Vector2(pos.x + 12, pos.y + 61), str(card.get("town", "")), HORIZONTAL_ALIGNMENT_LEFT, 38, 8, val)
	F_TINY.draw_string(ci, Vector2(x, pos.y + 64), str(card.get("number", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(150, 30, 30))


func _draw_slip(c: Control, pos: Vector2) -> void:
	var tex: Texture2D = _tex.get("booking")
	if tex != null:
		c.draw_texture_rect(tex, Rect2(pos, SLIP_SIZE), false)
	else:
		c.draw_rect(Rect2(pos, SLIP_SIZE), Color8(236, 240, 226))
	var ci := c.get_canvas_item()
	var x := pos.x + 12.0
	var y := pos.y + 14.0
	var ink := Color8(40, 40, 52)
	var lines := [
		"CAMPMAIL 98",
		"BOOKING CONFIRMED",
		"",
		"NAME     %s" % str(_guest.get("name", "")).to_upper(),
		"PERSONS  %d" % int(_guest.get("party_size", 1)),
		"NIGHTS   %d" % int(_guest.get("stay_nights", 1)),
	]
	var rooms: Array = _guest.get("rooms", [])
	for i in rooms.size():
		lines.append(("LODGING  " if i == 0 else "         ") + str((rooms[i] as Dictionary).get("label", "")).to_upper())
	lines.append("")
	lines.append("KEMP CERNE JEZERO")
	lines.append("HLUBOCANY DISTRICT")
	for l in lines:
		F_TINY.draw_string(ci, Vector2(x, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, SLIP_SIZE.x - 22, 8, ink)
		y += 9.0


func _draw_stamp_mark(c: Control, at: Vector2, kind: String, rot: float) -> void:
	var col := STAMP_GREEN if kind == "in" else STAMP_RED
	var label := "CHECKED IN" if kind == "in" else "REFUSED"
	var w := F_STAMP.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
	var hgt := 18.0
	c.draw_set_transform(at, rot)
	c.draw_rect(Rect2(-w * 0.5, -hgt * 0.5, w, hgt), col, false, 2.0)
	F_STAMP.draw_string(c.get_canvas_item(), Vector2(-w * 0.5 + 5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	# Where the rubber did not take: specks of paper through the ink.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 13.0 + at.y * 7.0)
	for i in 14:
		c.draw_rect(Rect2(Vector2(rng.randf_range(-w * 0.5, w * 0.5), rng.randf_range(-hgt * 0.5, hgt * 0.5)).floor(), Vector2.ONE), Color(0.93, 0.9, 0.82, 0.8))
	c.draw_set_transform(Vector2(roundf(sin(_t * 70.0) * _shake), 0) if _shake > 0.05 else Vector2.ZERO)
