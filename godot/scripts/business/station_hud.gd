extends CanvasLayer

## The frame round the room while you are at a station (scripts/business/station3d.gd), the
## same in all four places (the brief of 21. 10.: "the minigames consistent and the same
## across the places"; Papa's games), at the game's 2D pixel (640 x 360 to the screen, a
## whole number of times):
##   the rail       the order tickets across the top (ticket_rail.gd, in the room): each
##                  with the guest's face, what they want and their patience;
##   the ticket     the one picked, big, in the top right corner: a checklist of the order
##                  (ticked when done, red when wrong); under it SERVE (Space, Enter), lit
##                  when something is made and ready to hand over; under that the counts;
##   the bar        at the bottom: BACK (S, the right button), the place's stations as tabs
##                  (their picture, their key 1-9, their name; one where something waits
##                  blinks, amber, red when it burns), the shift's mark so far (A-E, the
##                  average stars, the run of good orders), the clock to last orders, the
##                  BOOKS (B) always in the same place;
##   the sentence   over the bar, what a click would do now ("Turn the slice"), or what was
##                  just said, like the verb line of an old adventure game;
##   the timers     what is cooking at the other stations of the room, small columns at the
##                  left, so you can mind the stove from the pass;
##   the score      after a serve, nothing that stops you: the stars, the score and the tip
##                  fly up over the guest (or their ticket), the run of good ones, and the
##                  small slip drops in for a moment (`serve_card`), a sound by how it went;
##   the hint       the next step lit (a pulsing frame round it), and when you stand still
##                  a while a see-through gloved hand shows the gesture (Options: Work
##                  hints, the warden's);
##   last orders    the bell and a word across the view when the time comes.
## One per business room (scripts/service_interior.gd, scripts/corn/stand_view.gd); shown
## while a station is open.

signal back
signal tab(station: String)
signal button(id: String)

const RETRO_UI := preload("res://scripts/ui/retro_ui.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const PROFILES := preload("res://scripts/profiles.gd")
const LANG := preload("res://scripts/lang.gd")
const W := 640
const H := 360
const BAR_H := 24
const BIG := Vector2(92, 118)
const CARD_SEC := 2.4
const CARD := Vector2(112, 86)
const POP_SEC := 1.7
const IDLE_GHOST := 3.5

## The station open now (station3d), set by the room.
var station: Node
## The place's stations for the tabs: [[id, LABEL, icon path (or "")], ...].
var tabs: Array = []
## Other wardens at this place's stations: id -> name.
var taken: Dictionary = {}
## station id -> the name of the hand working it now (shown on its tab; you may still go
## there, they make way: cornstand.crew_places).
var hands: Dictionary = {}
## -> [{icon: Texture2D, fill, zone: Vector2, col: Color, blink: bool}] (the timers).
var mirror_of: Callable
## (station id) -> 0, 1 (something waits there), 2 (it burns): the tabs blink.
var alert_of: Callable
## Callable(dir: int) -> String: the station beside the open one on that side (A, D), by
## the host; without it the next tab that way.
var side_of: Callable
## The room's picture's size (its viewport px): the station's points are in it.
var view_size := Vector2(640, 360)
## The work hints on (Options, the warden's).
static var hints_on := true

var _c: Control
var _k := 2
var _hover := ""
var _msg := ""
var _msg_who := ""
var _msg_t := 99.0
var _t := 0.0
## The score slip up now ({} none) and how long it has been up.
var _card: Dictionary = {}
var _card_t := 99.0
## What flies up over the guest after a serve: [{v, at (ui px), t}].
var _pops: Array = []
var _paper: Texture2D
var _star: Texture2D
var _star_dim: Texture2D
var _bell: Texture2D
var _ghost_tex: Dictionary = {}
var _icons: Dictionary = {}
var _sfx: AudioStreamPlayer
## The hint now ({} none), where it is on the frame (ui px), how long the pointer has stood.
var _hint: Dictionary = {}
var _hint_rect := Rect2()
var _hint_t := 0.0
var _idle := 0.0
var _mouse_was := Vector2(-99, -99)
var _alerts: Dictionary = {}
var _alert_t := 0.0
## Last orders: the word across the view, and whether this place's were called (a bell).
var _banner := ""
var _banner_t := 99.0
var _last_was := 99999
var _key_was := ""


func _ready() -> void:
	layer = 96
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Your hands are on the station (scripts/town/pockets.gd keeps them down).
	add_to_group("closeup")
	add_to_group("station_frame")
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw)
	add_child(_c)
	for pair in [["_paper", "res://assets/textury/bistro/ticket.png"], ["_star", "res://assets/textury/bistro/star.png"], ["_star_dim", "res://assets/textury/bistro/star_dim.png"], ["_bell", "res://assets/textury/ui/mark_bell.png"]]:
		if ResourceLoader.exists(str(pair[1])):
			set(str(pair[0]), load(str(pair[1])))
	for g in ["st_press", "st_open", "st_grab"]:
		var p := "res://assets/textury/hands_lo/%s.png" % g
		_ghost_tex[g] = load(p) if ResourceLoader.exists(p) else null
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -9.0
	add_child(_sfx)
	visibility_changed.connect(func() -> void:
		if visible:
			hints_on = PROFILES.profile_hints()
			_idle = 0.0)


func _play(name: String, db := -9.0, pitch := 1.0) -> void:
	var path := "res://assets/sfx/bistro/%s.mp3" % name
	if not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.volume_db = db
	_sfx.pitch_scale = pitch
	_sfx.play()


## Papa's slip for an order just served: `v` is the verdict (speed, build, cook (-1: no
## cooking), stars, tip, amount, ok, combo, bonus; notes when sent back), `what` the thing.
func serve_card(v: Dictionary, what := "") -> void:
	_card = v.duplicate()
	_card["what"] = what
	_card_t = 0.0
	var stars := int(v.get("stars", 0))
	var ok := bool(v.get("ok", true))
	if ok and stars >= 3:
		_play("guest_happy", -7.0)
	elif ok and stars == 2:
		_play("bell_ding", -10.0)
	else:
		_play("guest_grumble", -7.0)
	if ok and int(v.get("combo", 0)) >= RULES.COMBO_FROM:
		# The run of good ones: a bright ding on top, higher the longer the run.
		var a := AudioStreamPlayer.new()
		add_child(a)
		var p := "res://assets/sfx/bistro/bell_ding.mp3"
		if ResourceLoader.exists(p):
			a.stream = load(p)
			a.volume_db = -11.0
			a.pitch_scale = 1.2 + 0.08 * float(mini(int(v["combo"]), 8))
			a.play()
			a.finished.connect(a.queue_free)


## What flies up over the guest (`at`: the room's viewport px, (-1, -1) not on the picture:
## over their ticket on the rail instead, else the middle).
func serve_pop(v: Dictionary, at: Vector2, _tid := "") -> void:
	var ui := Vector2(W * 0.5 - 60, 110)
	if at.x >= 0.0:
		ui = to_ui(_view_to_screen(at))
	# Kept on the view, under the rail and clear of the big ticket.
	ui = Vector2(clampf(ui.x, 50.0, W - BIG.x - 60.0), clampf(ui.y, 92.0, H - BAR_H - 40.0))
	_pops.append({"v": v.duplicate(), "at": ui, "t": 0.0})


func say(who: String, text: String) -> void:
	_msg_who = who
	_msg = text
	_msg_t = 0.0


func clear_say() -> void:
	_msg = ""
	_msg_t = 99.0


## Something was clicked or pressed (the ghost hand goes, the idle starts again).
func poke() -> void:
	_idle = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_msg_t += delta
	_card_t += delta
	_banner_t += delta
	for p in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p) -> bool: return float(p["t"]) < POP_SEC)
	var m := _c.get_viewport().get_mouse_position()
	if m.distance_to(_mouse_was) > 2.0:
		_idle = 0.0
		_mouse_was = m
	else:
		_idle += delta
	_alert_t -= delta
	if _alert_t <= 0.0:
		_alert_t = 0.25
		_alerts.clear()
		if alert_of.is_valid():
			for tb in tabs:
				_alerts[str(tb[0])] = int(alert_of.call(str(tb[0])))
		_refresh_hint()
	_watch_last_orders()
	_c.queue_redraw()


## The next step, a few times a second: the station says what it is, the frame finds it.
func _refresh_hint() -> void:
	var h: Dictionary = station.call("next_hint") if hints_on and station != null and is_instance_valid(station) and station.has_method("next_hint") else {}
	if str(h) != str(_hint):
		_hint_t = 0.0
	_hint = h
	_hint_rect = Rect2()
	if station != null and is_instance_valid(station) and station.has_method("show_hint"):
		station.call("show_hint", h)
	if h.is_empty():
		return
	if h.has("tab"):
		for i in tabs.size():
			if str(tabs[i][0]) == str(h["tab"]):
				_hint_rect = _tab_rect(i)
		return
	match str(h.get("ui", "")):
		"serve":
			_hint_rect = _serve_rect()
			return
		"books":
			_hint_rect = _books_rect()
			return
	var vr: Rect2 = station.call("hint_view_rect", h)
	if vr.size == Vector2.ZERO and vr.position == Vector2.ZERO:
		return
	var a := to_ui(_view_to_screen(vr.position))
	var b := to_ui(_view_to_screen(vr.end))
	_hint_rect = Rect2(a, b - a).abs()
	if h.has("to"):
		var tp: Vector2 = station.call("view_point", h["to"], 0.0)
		_hint["to_ui"] = to_ui(_view_to_screen(tp))


## Last orders at this place: the bell and the word, once.
func _watch_last_orders() -> void:
	var key := _key()
	if key == "":
		return
	var left := BUSINESS.to_last_orders(key)
	if key != _key_was:
		_key_was = key
		_last_was = left
		return
	if _last_was > 0 and left <= 0 and left > -30:
		_banner = tr("LAST ORDERS")
		_banner_t = 0.0
		_play("bell_ding", -4.0, 0.8)
	_last_was = left


func _key() -> String:
	return str(station.get("building_key")) if station != null and is_instance_valid(station) else ""


## A point of the room's picture on the screen.
func _view_to_screen(vp: Vector2) -> Vector2:
	var s := _c.get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return vp
	return vp * s / view_size


## The frame's own pixel under a point of the screen.
func to_ui(screen: Vector2) -> Vector2:
	var s := _c.get_viewport_rect().size
	_k = maxi(1, int(floor(minf(s.x / float(W), s.y / float(H)))))
	var off := ((s - Vector2(W, H) * float(_k)) * 0.5).floor()
	return (screen - off) / float(_k)


## A key pressed at a station, as the frame reads it: "serve" (Space, Enter), "books" (B),
## "back" (S), "next" (Tab), "tab:<id>" (1-9, 0), "" anything else (the station's own).
func key_action(e: InputEventKey) -> String:
	_idle = 0.0
	match e.physical_keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			return "serve"
		KEY_B:
			return "books"
		KEY_S:
			return "back"
		KEY_TAB:
			return "next"
		# The station on the left, the station on the right, as A and D go between a
		# place's rooms (playtest 25. 10.: "let me move between the corn's stations by A and
		# D"): the one beside it in the room, a quick step; nothing past the last (not round
		# from the fourth to the first, nor down to the cellar).
		KEY_A, KEY_D:
			var to := _side(-1 if e.physical_keycode == KEY_A else 1)
			return "tab:" + to if to != "" else "none"
	var n := -1
	if e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_9:
		n = e.physical_keycode - KEY_1
	elif e.physical_keycode == KEY_0:
		n = 9
	if n >= 0 and n < tabs.size():
		return "tab:" + str(tabs[n][0])
	return ""


## The tab after the open one (Tab).
func next_tab() -> String:
	return _tab_by(1)


## The station beside the open one on that side (-1 left, 1 right): the host's say
## (`side_of`, by where they stand in the room), else the next tab that way, not round.
func _side(dir: int) -> String:
	if side_of.is_valid():
		return str(side_of.call(dir))
	if tabs.size() < 2:
		return ""
	var cur := str(station.get("station")) if station != null else ""
	for j in tabs.size():
		if str(tabs[j][0]) == cur:
			var k := j + dir
			return str(tabs[k][0]) if k >= 0 and k < tabs.size() else ""
	return ""


## The tab `step` along from the open one, round the ends.
func _tab_by(step: int) -> String:
	if tabs.is_empty():
		return ""
	var cur := str(station.get("station")) if station != null else ""
	var i := 0
	for j in tabs.size():
		if str(tabs[j][0]) == cur:
			i = j
	return str(tabs[posmod(i + step, tabs.size())][0])


## What of the frame is under the screen point ("" none): "#back", "#tab:<id>",
## "#btn:<id>" (the station's buttons), "#serve", "#books", "#bar", "#ticket".
func hit(screen: Vector2) -> String:
	if not visible:
		return ""
	var m := to_ui(screen)
	if _back_rect().has_point(m):
		return "#back"
	if _books_rect().has_point(m):
		return "#books"
	for i in tabs.size():
		if _tab_rect(i).has_point(m):
			return "#tab:" + str(tabs[i][0])
	var btns := _buttons()
	for i in btns.size():
		if _btn_rect(i, btns.size()).has_point(m):
			return "#btn:" + str(btns[i]["id"])
	if m.y >= H - BAR_H:
		return "#bar"
	if station != null and station.has_method("serve_ready") and bool(station.call("has_rail")) and _serve_rect().has_point(m):
		return "#serve"
	if _big_rect().has_point(m) and station != null and not (station.call("big_ticket") as Dictionary).is_empty():
		return "#ticket"
	return ""


func set_hover(id: String) -> void:
	_hover = id


func _buttons() -> Array:
	var out: Array = station.call("bar_buttons") if station != null and station.has_method("bar_buttons") else []
	# BOOKS is the frame's own now (always in the same place).
	return out.filter(func(b) -> bool: return str(b.get("id", "")) != "books")


# ── where things are on the frame ────────────────────────────────────────────

func _back_rect() -> Rect2:
	return Rect2(4, H - BAR_H + 3, 54, BAR_H - 6)


func _books_rect() -> Rect2:
	return Rect2(W - 4 - 62, H - BAR_H + 3, 62, BAR_H - 6)


func _clock_rect() -> Rect2:
	return Rect2(_books_rect().position.x - 4 - 52, H - BAR_H + 3, 52, BAR_H - 6)


func _shift_rect() -> Rect2:
	return Rect2(_clock_rect().position.x - 4 - 70, H - BAR_H + 3, 70, BAR_H - 6)


## The tabs fill the bar between BACK and the shift's mark: each its picture, its key and
## its name; when they do not all fit, the others shrink to the picture and the key.
func _tab_widths() -> Array:
	var f: Font = RETRO_UI.FONT_LABEL
	var full: Array = []
	var total := 0.0
	for i in tabs.size():
		var w := 20.0 + f.get_string_size(_tab_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6.0
		full.append(w)
		total += w + 2.0
	var room := _shift_rect().position.x - 4.0 - 62.0
	if total <= room:
		return full
	var cur := str(station.get("station")) if station != null else ""
	var out: Array = []
	for i in tabs.size():
		out.append(full[i] if str(tabs[i][0]) == cur else 30.0)
	return out


func _tab_text(i: int) -> String:
	var id := str(tabs[i][0])
	if str(taken.get(id, "")) != "":
		return str(taken[id]).to_upper().substr(0, 8)
	if str(hands.get(id, "")) != "":
		return str(hands[id]).to_upper().substr(0, 8)
	return tr(str(tabs[i][1])).to_upper()


func _tab_rect(i: int) -> Rect2:
	var ws := _tab_widths()
	var x := 62.0
	for j in i:
		x += float(ws[j]) + 2.0
	return Rect2(x, H - BAR_H + 3, float(ws[i]) if i < ws.size() else 30.0, BAR_H - 6)


func _btn_rect(i: int, n: int) -> Rect2:
	# The station's own buttons (BIN, SCRAPE) sit over the bar at the right, under SERVE.
	return Rect2(W - 6 - BIG.x, _serve_rect().end.y + 14 + i * 20, BIG.x, 17)


## The picked ticket hangs at the right end of the rail, big.
func _big_rect() -> Rect2:
	return Rect2(W - BIG.x - 6, 8, BIG.x, BIG.y)


func _serve_rect() -> Rect2:
	return Rect2(W - BIG.x - 6, 8 + BIG.y + 3, BIG.x, 20)


func _icon(path: String) -> Texture2D:
	if path == "":
		return null
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var s := _c.get_viewport_rect().size
	_k = maxi(1, int(floor(minf(s.x / float(W), s.y / float(H)))))
	var off := ((s - Vector2(W, H) * float(_k)) * 0.5).floor()
	_c.draw_set_transform(off, 0.0, Vector2(_k, _k))
	# The bar runs the whole width of the screen, whatever is left over the 16:9.
	var full_w := s.x / float(_k)
	var x0 := -off.x / float(_k)
	_c.draw_rect(Rect2(x0, H - BAR_H, full_w, BAR_H), RETRO_UI.C_PLATE)
	_c.draw_rect(Rect2(x0, H - BAR_H, full_w, 1), RETRO_UI.C_PLATE_LIGHT)
	_c.draw_rect(Rect2(x0, H - 1, full_w, 1), RETRO_UI.C_PLATE_DARK)
	_button(_back_rect(), tr("< BACK"), _hover == "#back", false, false, "S")
	var cur := str(station.get("station")) if station != null else ""
	for i in tabs.size():
		_draw_tab(i, cur)
	var btns := _buttons()
	for i in btns.size():
		_button(_btn_rect(i, btns.size()), tr(str(btns[i]["label"])), _hover == "#btn:" + str(btns[i]["id"]), false)
	_draw_shift()
	_draw_clock()
	_button(_books_rect(), tr("BOOKS"), _hover == "#books", false, false, "B")
	_draw_sentence()
	_draw_big()
	_draw_serve()
	_draw_counts()
	_draw_mirror()
	_draw_hint()
	_draw_card()
	_draw_pops()
	_draw_banner()


func _draw_tab(i: int, cur: String) -> void:
	var id := str(tabs[i][0])
	var r := _tab_rect(i)
	var busy := str(taken.get(id, "")) != ""
	var lit := int(_alerts.get(id, 0))
	var down := id == cur
	var bg := RETRO_UI.C_PLATE_DARK if down else (Color(0.36, 0.31, 0.24) if _hover == "#tab:" + id else Color(0.2, 0.18, 0.15))
	if not down and _hint.has("tab") and str(_hint["tab"]) == id:
		bg = bg.lerp(Color(0.6, 0.42, 0.1), 0.5 + 0.5 * sin(_t * 5.0))
	if lit == 2 and not down and int(_t * 5.0) % 2 == 0:
		# Something burns there: it blinks red.
		bg = Color(0.55, 0.12, 0.06)
	_c.draw_rect(r, bg)
	_bevel(r, down)
	if lit == 1 and not down:
		# Something waits there: a steady amber light in its corner, breathing a little.
		var a := 0.75 + 0.25 * sin(_t * 3.0)
		_c.draw_rect(Rect2(r.end.x - 6, r.position.y + 2, 4, 4), Color(1.0, 0.7, 0.15, a))
	var ic := _icon(str(tabs[i][2]) if (tabs[i] as Array).size() > 2 else "")
	var x := r.position.x + 3
	if ic != null:
		var sc := minf(1.0, 12.0 / maxf(ic.get_width(), ic.get_height()))
		var isz := (ic.get_size() * sc).floor()
		_c.draw_texture_rect(ic, Rect2(Vector2(x, r.position.y + floorf((r.size.y - isz.y) * 0.5)), isz), false, Color(1, 1, 1, 0.5) if busy else Color.WHITE)
	x += 13
	var key := str(i + 1) if i < 9 else "0"
	_c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, r.position.y + 8), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_AMBER if not busy else RETRO_UI.C_BONE_DIM)
	if r.size.x > 34.0:
		var col := RETRO_UI.C_AMBER if down else (RETRO_UI.C_AMBER_LIGHT if _hover == "#tab:" + id else RETRO_UI.C_BONE)
		if busy:
			col = RETRO_UI.C_BONE_DIM
		_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x + 6, r.position.y + 12), _tab_text(i), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - (x + 6 - r.position.x) - 2, 8, col)


## The shift's mark so far: the letter in its box, the average stars, the run.
func _draw_shift() -> void:
	var r := _shift_rect()
	_c.draw_rect(r, Color(0.12, 0.1, 0.08))
	_bevel(r, true)
	var key := _key()
	var s := BUSINESS.site(key) if key != "" else {}
	var mark := RULES.shift_mark(s.get("shift", {}) if s.get("shift", {}) is Dictionary else {})
	var grade := str(mark["grade"])
	var gcol: Color = {"A": RETRO_UI.C_GREEN, "B": RETRO_UI.C_GREEN, "C": RETRO_UI.C_AMBER, "D": RETRO_UI.C_RED, "E": RETRO_UI.C_RED}.get(grade, RETRO_UI.C_BONE_DIM)
	var box := Rect2(r.position.x + 3, r.position.y + 2, 14, 14)
	_c.draw_rect(box, Color(0.05, 0.04, 0.03))
	_c.draw_rect(box, gcol, false, 1.0)
	var gw := RETRO_UI.FONT_LABEL.get_string_size(grade, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(box.position.x + floorf((14 - gw) * 0.5), box.position.y + 11), grade, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, gcol)
	if _star != null:
		_c.draw_texture_rect(_star, Rect2(Vector2(r.position.x + 20, r.position.y + 3), Vector2(10, 10)), false)
	_c.draw_string(RETRO_UI.FONT_TEXT, Vector2(r.position.x + 32, r.position.y + 12), "%.1f" % float(mark["stars"]) if int(mark["orders"]) > 0 else "-", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_BONE)
	var run := BUSINESS.combo(key) if key != "" else 0
	if run >= 2:
		var col := RETRO_UI.C_AMBER_LIGHT if run >= RULES.COMBO_FROM else RETRO_UI.C_BONE_DIM
		_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(r.position.x + 50, r.position.y + 12), "x%d" % run, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## The clock to last orders: the bell and the hours and minutes left; after them, the
## kitchen still serving who ordered (red); shut.
func _draw_clock() -> void:
	var r := _clock_rect()
	_c.draw_rect(r, Color(0.12, 0.1, 0.08))
	_bevel(r, true)
	var key := _key()
	if key == "":
		return
	var left := BUSINESS.to_last_orders(key)
	var shut := BUSINESS.shift_now(BUSINESS.site(key)) == "closed"
	var text := ""
	var col := RETRO_UI.C_BONE
	if shut:
		text = tr("CLOSED")
		col = RETRO_UI.C_BONE_DIM
	elif left <= 0:
		text = tr("LAST")
		col = RETRO_UI.C_RED if int(_t * 2.0) % 2 == 0 else RETRO_UI.C_AMBER
	else:
		text = "%d:%02d" % [left / 60, left % 60]
		col = RETRO_UI.C_AMBER if left <= 60 else RETRO_UI.C_BONE
	if _bell != null:
		var sc := minf(1.0, 12.0 / maxf(_bell.get_width(), _bell.get_height()))
		_c.draw_texture_rect(_bell, Rect2(r.position + Vector2(3, 3), (_bell.get_size() * sc).floor()), false)
	_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(r.position.x + 17, r.position.y + 12), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 19, 8, col)


func _draw_serve() -> void:
	# Only where something is handed over (the keg in the cellar has no orders).
	if station == null or not is_instance_valid(station) or not station.has_method("serve_ready") or not bool(station.call("has_rail")):
		return
	var ready := bool(station.call("serve_ready"))
	var r := _serve_rect()
	var bg := Color(0.18, 0.15, 0.12)
	var col := RETRO_UI.C_BONE_DIM
	if ready:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		bg = Color(0.42, 0.28, 0.06).lerp(Color(0.62, 0.42, 0.1), pulse)
		col = RETRO_UI.C_AMBER_LIGHT
		if _hover == "#serve":
			bg = Color(0.7, 0.5, 0.14)
	_c.draw_rect(r, bg)
	_bevel(r, false)
	if _bell != null:
		var sc := minf(1.0, 12.0 / maxf(_bell.get_width(), _bell.get_height()))
		_c.draw_texture_rect(_bell, Rect2(r.position + Vector2(4, 4), (_bell.get_size() * sc).floor()), false, Color.WHITE if ready else Color(1, 1, 1, 0.4))
	var label := tr("SERVE")
	var w := RETRO_UI.FONT_LABEL.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(floorf(r.position.x + (r.size.x - w) * 0.5) + 4, r.position.y + 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## The station's counts (the crate, the bowl, the butter) under SERVE.
func _draw_counts() -> void:
	if station == null:
		return
	var counts := tr(str(station.call("bar_text")))
	if counts == "":
		return
	var f: Font = RETRO_UI.FONT_TEXT
	var y := _serve_rect().end.y + 10
	var w := f.get_string_size(counts, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x := W - 6 - w
	_c.draw_rect(Rect2(x - 3, y - 8, w + 6, 11), Color(0.03, 0.025, 0.02, 0.7))
	_c.draw_string(f, Vector2(x, y), counts, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_BONE_DIM)


## The next step: a frame round it that breathes; standing still a while, the see-through
## glove shows the gesture.
func _draw_hint() -> void:
	if _hint.is_empty() or _hint_rect.size == Vector2.ZERO and _hint_rect.position == Vector2.ZERO:
		return
	# (No frame drawn round it: the thing itself breathes warm in its own shape in the
	# room, station3d.show_hint, and a button or a tab glows as SERVE does; the corner
	# brackets read as a web page's, playtest 25. 10.)
	if _idle < IDLE_GHOST or _hint.has("tab") or _hint.has("ui"):
		return
	# The ghost glove: where to click, what to drag where, what to hold or rub.
	var g := str(_hint.get("gesture", "click"))
	var k := fmod(_idle - IDLE_GHOST, 1.4) / 1.4
	var at := _hint_rect.get_center()
	var tex: Texture2D = _ghost_tex.get("st_press")
	match g:
		"drag":
			var to: Vector2 = _hint.get("to_ui", at + Vector2(0, -40))
			at = at.lerp(to, clampf((k - 0.15) / 0.7, 0.0, 1.0))
			tex = _ghost_tex.get("st_grab") if k > 0.15 else _ghost_tex.get("st_open")
		"hold":
			tex = _ghost_tex.get("st_grab") if k > 0.2 else _ghost_tex.get("st_open")
			at.y += 3.0 if k > 0.2 else 0.0
		"rub":
			at.x += sin(k * TAU * 2.0) * 16.0
			tex = _ghost_tex.get("st_grab")
		"shake":
			at.y += sin(k * TAU * 4.0) * 5.0
		_:
			at.y += 4.0 if k > 0.4 and k < 0.6 else 0.0
	if tex == null:
		return
	var sz := tex.get_size() * 0.5
	_c.draw_texture_rect(tex, Rect2((at - Vector2(sz.x * 0.35, 2)).floor(), sz.floor()), false, Color(1, 1, 1, 0.42))


## The score slip: drops in from the top (smooth), hangs a moment, goes.
func _draw_card() -> void:
	if _card.is_empty() or _card_t > CARD_SEC:
		return
	# At the left under the rail (what flies up over the guest is in the middle): it slides
	# in from the edge, smooth, and back out.
	var k_in := clampf(_card_t / 0.25, 0.0, 1.0)
	k_in = 1.0 - pow(1.0 - k_in, 3.0)
	var x0 := -CARD.x + (CARD.x + 8.0) * k_in
	if _card_t > CARD_SEC - 0.3:
		var k_out := clampf((_card_t - (CARD_SEC - 0.3)) / 0.3, 0.0, 1.0)
		x0 -= k_out * k_out * (CARD.x + 8.0)
	var r := Rect2(floorf(x0), 92, CARD.x, CARD.y)
	_c.draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.03, 0.9))
	if _paper != null:
		_c.draw_texture_rect(_paper, r, false)
	else:
		_c.draw_rect(r, Color(0.92, 0.88, 0.76))
	var ink := Color(0.16, 0.12, 0.1)
	var f: Font = RETRO_UI.FONT_TEXT
	var x := r.position.x + 7
	var ok := bool(_card.get("ok", true))
	var title := tr(str(_card.get("what", ""))).to_upper()
	if not ok:
		_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, r.position.y + 14), (LANG.f("%s SENT BACK", title)) if title != "" else tr("SENT BACK"), HORIZONTAL_ALIGNMENT_LEFT, CARD.x - 12, 8, Color(0.62, 0.08, 0.05))
		var notes: Array = _card.get("notes", [])
		var ly := r.position.y + 30
		for n in notes.slice(0, 3):
			_c.draw_string(f, Vector2(x, ly), tr(str(n)), HORIZONTAL_ALIGNMENT_LEFT, CARD.x - 12, 8, ink)
			ly += 12
		return
	_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, r.position.y + 14), title if title != "" else tr("SERVED"), HORIZONTAL_ALIGNMENT_LEFT, CARD.x - 12, 8, Color(0.55, 0.1, 0.08))
	var rows: Array = [["WAIT", float(_card.get("speed", -1.0))], ["MADE", float(_card.get("build", -1.0))], ["COOKING", float(_card.get("cook", -1.0))]]
	var ry := r.position.y + 24
	for row in rows:
		if float(row[1]) < 0.0:
			continue
		var v := clampf(float(row[1]), 0.0, 1.0)
		_c.draw_string(f, Vector2(x, ry + 7), tr(str(row[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		var bar := Rect2(x + 44, ry + 1, CARD.x - 58, 5)
		var col: Color = RETRO_UI.C_GREEN if v >= 0.8 else (RETRO_UI.C_AMBER if v >= 0.5 else RETRO_UI.C_RED)
		RETRO_UI.draw_segments(_c, bar, v, 10, col)
		ry += 11
	var stars := int(_card.get("stars", 1))
	var shown := clampi(int((_card_t - 0.2) * 7.0), 0, 3)
	for i in 3:
		var tex: Texture2D = _star if i < stars and i < shown else _star_dim
		if tex == null:
			continue
		_c.draw_texture_rect(tex, Rect2(Vector2(x + i * 14, r.end.y - 30), Vector2(12, 12)), false)
	_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x + 46, r.end.y - 20), LANG.money("+$%d" % int(_card.get("amount", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.1, 0.4, 0.12))
	var tip := int(_card.get("tip", 0)) + int(_card.get("bonus", 0))
	if tip > 0:
		_c.draw_string(f, Vector2(x + 76, r.end.y - 20), LANG.f("TIP $%d", tip), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, r.end.y - 6), _word(_card), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.1, 0.08) if stars >= 3 else ink)


static func _word(v: Dictionary) -> String:
	var stars := int(v.get("stars", 1))
	var word: String = ["", "POOR", "GOOD", "PERFECT!"][clampi(stars, 0, 3)]
	if int(v.get("score", 0)) < 50:
		word = "POOR"
	return load("res://scripts/lang.gd").t(word)


## Over the guest: the stars, the score, the money and the tip, the run, rising and
## fading (smooth), nothing to click away.
func _draw_pops() -> void:
	for p in _pops:
		var v: Dictionary = p["v"]
		var t := float(p["t"])
		var k := t / POP_SEC
		var rise := (1.0 - pow(1.0 - minf(1.0, t / 0.9), 2.0)) * 26.0
		var a := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
		var at: Vector2 = (p["at"] as Vector2) - Vector2(0, rise)
		var ok := bool(v.get("ok", true))
		var lines: Array = []
		if not ok:
			lines.append([tr("SENT BACK"), RETRO_UI.C_RED, RETRO_UI.FONT_LABEL])
		else:
			lines.append([_word(v) + "  %d%%" % int(v.get("score", 0)), RETRO_UI.C_AMBER_LIGHT if int(v.get("stars", 0)) >= 3 else RETRO_UI.C_BONE, RETRO_UI.FONT_LABEL])
			var money := LANG.money("+$%d" % int(v.get("amount", 0)))
			var tip := int(v.get("tip", 0)) + int(v.get("bonus", 0))
			if tip > 0:
				money += "  " + LANG.f("TIP $%d", tip)
			lines.append([money, RETRO_UI.C_GREEN, RETRO_UI.FONT_TEXT])
			var run := int(v.get("combo", 0))
			if run >= RULES.COMBO_FROM:
				lines.append([LANG.f("x%d IN A ROW", run), Color(1.0, 0.86, 0.36), RETRO_UI.FONT_LABEL])
		# The stars over it all.
		var stars := int(v.get("stars", 0)) if ok else 0
		var sw := 3 * 13
		var sx := floorf(at.x - sw * 0.5)
		var y := floorf(at.y - 12.0 * lines.size() - 14.0)
		var shown := clampi(int(t * 9.0), 0, 3)
		for i in 3:
			var tex: Texture2D = _star if i < stars and i < shown else _star_dim
			if tex != null:
				_c.draw_texture_rect(tex, Rect2(Vector2(sx + i * 13, y), Vector2(12, 12)), false, Color(1, 1, 1, a))
		y += 22
		for ln in lines:
			var f: Font = ln[2]
			var text := str(ln[0])
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var x := floorf(at.x - w * 0.5)
			var col: Color = ln[1]
			col.a = a
			_c.draw_string(f, Vector2(x + 1, y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.85 * a))
			_c.draw_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
			y += 12


func _draw_banner() -> void:
	if _banner == "" or _banner_t > 2.6:
		return
	var a := 1.0 if _banner_t < 2.0 else 1.0 - (_banner_t - 2.0) / 0.6
	var f: Font = RETRO_UI.FONT_BIG
	var w := f.get_string_size(_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var r := Rect2(floorf((W - w) * 0.5) - 10, 150, w + 20, 22)
	_c.draw_rect(r, Color(0.05, 0.03, 0.02, 0.85 * a))
	_c.draw_rect(r, Color(0.62, 0.42, 0.08, a), false, 1.0)
	_c.draw_string(f, Vector2(r.position.x + 10, r.position.y + 15), _banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.82, 0.36, a))


func _draw_sentence() -> void:
	var line := str(station.call("hover_verb")) if station != null else ""
	if line != "":
		line = tr(line)
	var who := ""
	var col := RETRO_UI.C_AMBER_LIGHT
	if _msg != "" and _msg_t < 4.5 and (line == "" or _msg_t < 1.6):
		line = tr(_msg)
		who = _msg_who
		col = RETRO_UI.C_QUOTE
	if line == "":
		return
	var f: Font = RETRO_UI.FONT_TEXT
	var full := (who.to_upper() + "  " if who != "" else "") + line
	var w := f.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x := floorf((W - w) * 0.5)
	var y := float(H - BAR_H - 6)
	_c.draw_rect(Rect2(x - 5, y - 10, w + 10, 13), Color(0.03, 0.025, 0.02, 0.84))
	if who != "":
		_c.draw_string(f, Vector2(x, y), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_AMBER)
		x += f.get_string_size(who.to_upper() + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		full = line
	_c.draw_string(f, Vector2(x + 1, y + 1), full, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.9))
	_c.draw_string(f, Vector2(x, y), full, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _draw_big() -> void:
	if station == null:
		return
	var t: Dictionary = station.call("big_ticket")
	if t.is_empty():
		return
	station.call("draw_big_ticket", _c, _big_rect(), t)


## The timers of the room: a small plate at the bottom left, a column per thing cooking.
func _draw_mirror() -> void:
	var rows: Array = mirror_of.call() if mirror_of.is_valid() else []
	if rows.is_empty():
		return
	# A plate of the frame's own (bevelled as its buttons), a column of the HUD's LED
	# segments a thing (the done window lit dim green to aim at).
	var cw := 15.0
	var w := 7.0 + rows.size() * cw
	var h := 44.0
	var r := Rect2(6, H - BAR_H - h - 22, w, h)
	_c.draw_rect(r, Color(0.2, 0.18, 0.15))
	_bevel(r, false)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var x := r.position.x + 4 + i * cw
		var ic: Texture2D = row.get("icon", null)
		if ic != null:
			var isz := ic.get_size()
			var sc := minf(1.0, 12.0 / maxf(isz.x, isz.y))
			var isz2 := (isz * sc).floor()
			_c.draw_texture_rect(ic, Rect2(Vector2(x + floorf((cw - 2.0 - isz2.x) * 0.5), r.position.y + 3), isz2), false)
		var bar := Rect2(x + 3, r.position.y + 18, 6, h - 22)
		var fill := clampf(float(row.get("fill", 0.0)), 0.0, 1.0)
		var on := not bool(row.get("blink", false)) or int(_t * 4.0) % 2 == 0
		RETRO_UI.draw_segments(_c, bar, fill if on else 0.0, 6, row.get("col", RETRO_UI.C_AMBER), true, Color(0.12, 0.11, 0.10), row.get("zone", Vector2(-1, -1)))


func _bevel(r: Rect2, down: bool) -> void:
	_c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), RETRO_UI.C_PLATE_DARK if down else RETRO_UI.C_PLATE_LIGHT)
	_c.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), RETRO_UI.C_PLATE_DARK if down else RETRO_UI.C_PLATE_LIGHT)
	_c.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(r.size.x, 1)), RETRO_UI.C_PLATE_LIGHT if down else RETRO_UI.C_PLATE_DARK)
	_c.draw_rect(Rect2(Vector2(r.end.x - 1, r.position.y), Vector2(1, r.size.y)), RETRO_UI.C_PLATE_LIGHT if down else RETRO_UI.C_PLATE_DARK)


func _button(r: Rect2, text: String, hot: bool, down: bool, dim := false, key := "") -> void:
	var bg := RETRO_UI.C_PLATE_DARK if down else (Color(0.36, 0.31, 0.24) if hot else Color(0.2, 0.18, 0.15))
	if _hint_rect == r and not _hint.is_empty():
		bg = bg.lerp(Color(0.6, 0.42, 0.1), 0.5 + 0.5 * sin(_t * 5.0))
	_c.draw_rect(r, bg)
	_bevel(r, down)
	var col := RETRO_UI.C_AMBER if down else (RETRO_UI.C_AMBER_LIGHT if hot else RETRO_UI.C_BONE)
	if dim:
		col = RETRO_UI.C_BONE_DIM
	var w := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var tx := floorf(r.position.x + (r.size.x - w) * 0.5)
	if key != "":
		tx = maxf(r.position.x + 9, tx + 3)
		_c.draw_string(RETRO_UI.FONT_TEXT, Vector2(r.position.x + 3, r.position.y + 8), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_AMBER)
	_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(tx, r.position.y + 12), text, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 2, 8, col)
