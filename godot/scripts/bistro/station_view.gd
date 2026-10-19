extends CanvasLayer

## A station of the bistro played full screen, like a Papa's Burgeria station or a Sierra
## close-up the size of the screen (DESIGN.md §7b): one hand-painted 640x360 picture (Grok,
## assets/textury/bistro/st_*.png) drawn at its own resolution and scaled up by a whole
## number (2 at 1280x720, 3 at 1920x1080: the whole screen), the things on it drawn over
## it as Grok sprites, the game's pixel fonts.
##
## Every station has the same frame round it:
##   the rail      the open tickets across the top, oldest at the left: who, what, how
##                 many, and a bar for how long they have waited (green, amber, red);
##   the sentence  over the bottom bar, what a click would do now ("Flip the slice"),
##                 like the verb line of an old adventure game;
##   the bar       back to the room (S, the right button), the other stations of the room
##                 you are in, and the plates.
## Things you can use glint under the pointer and the cursor turns to the finger.
## Subclasses override:
##   _spots() -> Array of {id, rect: Rect2, verb: String}   what can be clicked now
##   _paint(c)            draw the station's things over the picture
##   _press(id) / _release(id) / _drag(at)   the mouse on a spot (held: _drag each frame)
##   _tick(delta)
##   _opened() / _closing()

signal closed
## The bar's tab for another station of this room was clicked (service_interior opens it).
signal switch_to(station: String)

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RULES = preload("res://core/systems/bistro_rules.gd")
const KITCHEN = preload("res://scripts/bistro/kitchen.gd")
const W := 640
const H := 360
const TEX := "res://assets/textury/bistro/"
const SFX_DIR := "res://assets/sfx/bistro/"
const RAIL_H := 62
## The station's picture and the things on it are drawn two canvas pixels to one of theirs
## (320x180 Build-engine textures, playtest 19. 10.); the frame (tickets, text) is not.
const PIX := 2
const BAR_H := 22
const TICKET := Vector2(40, 56)
const OPEN_SEC := 0.2
const OPEN_STEPS := 5
## The stations of each room, in the order their tabs stand on the bar.
const ROOM_STATIONS := {
	"kitchen": [["stove", "STOVE"], ["pot", "POT"], ["pass", "PASS"], ["sink", "SINK"]],
	"basement": [["potatoes", "POTATOES"], ["breading", "BREADING"]],
}
## The little pictures on the tickets (assets/textury/closeup/food/icon_*.png, Grok).
const ICONS := {"goulash": "icon_goulash", "dumpling": "icon_dumpling", "cheese": "icon_cheese", "fries": "icon_fries", "tartar": "icon_tartar", "onion": "icon_onion"}

var building_key := ""
var station := ""
var room := "kitchen"
var kitchen: KITCHEN
var picture: Texture2D

var _vp: SubViewport
var _canvas: Control
var _view: TextureRect
var _backdrop: ColorRect
var _k := 2
var _mouse := Vector2(-1, -1)
var _hover := ""
var _hover_verb := ""
var _held := ""
var _open_t := 0.0
var _closing_t := -1.0
var _t := 0.0
var _msg := ""
var _msg_who := ""
var _msg_t := 0.0
var _pops: Array = []
var _tex: Dictionary = {}
var _audio: Array = []
var _audio_i := 0
## The ticket picked on the rail (its id; "" none): the pass plates for it.
var picked := ""
## Others at the stations of this room (co-op): station -> name, to grey their tabs.
var taken: Dictionary = {}


func _init() -> void:
	layer = 96
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Your hands are on the station (scripts/town/pockets.gd keeps them down).
	add_to_group("closeup")


func _ready() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.disable_3d = true
	_vp.transparent_bg = false
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
		a.volume_db = -8.0
		add_child(a)
		_audio.append(a)
	for n in ["ticket", "ticket_old"]:
		tex(n)
	for k in ICONS:
		var p := "res://assets/textury/closeup/food/%s.png" % str(ICONS[k])
		_tex["icon:" + str(k)] = load(p) if ResourceLoader.exists(p) else null
	get_tree().root.size_changed.connect(_layout)


## A picture of the bistro's (assets/textury/bistro/<n>.png), loaded once (never inside a
## draw callback: it would come out white).
func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		var p := TEX + n + ".png"
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
	return _tex[n]


func is_open() -> bool:
	return visible and _closing_t < 0.0


func open_view() -> void:
	if visible and _closing_t < 0.0:
		return
	kitchen = get_tree().get_first_node_in_group("kitchens") as KITCHEN
	visible = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_open_t = 0.0
	_closing_t = -1.0
	_hover = ""
	_held = ""
	_layout()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_opened()


func close_view() -> void:
	if not visible or _closing_t >= 0.0:
		return
	_release_held()
	_closing()
	_closing_t = 0.0


## Shut at once (the room closing under it, another station opening).
func close_now() -> void:
	if not visible:
		return
	_release_held()
	if _closing_t < 0.0:
		_closing()
	visible = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_closing_t = -1.0


func say(who: String, text: String) -> void:
	_msg_who = who
	_msg = text
	_msg_t = 0.0


## A number or a word that floats up from `at` and fades (+$9, BURNT...).
func pop(text: String, at: Vector2, col: Color = RETRO_UI.C_AMBER_LIGHT, big := false) -> void:
	_pops.append({"text": text, "at": at, "t": 0.0, "col": col, "big": big})


func sfx(n: String, db := -8.0, pitch := 1.0) -> void:
	var path := SFX_DIR + n + ".mp3"
	if not ResourceLoader.exists(path):
		path = SFX_DIR + n + ".wav"
		if not ResourceLoader.exists(path):
			return
	var a: AudioStreamPlayer = _audio[_audio_i]
	_audio_i = (_audio_i + 1) % _audio.size()
	a.stream = load(path)
	a.volume_db = db
	a.pitch_scale = pitch
	a.play()


func _layout() -> void:
	if _view == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_k = maxi(1, int(floor(minf(vp.x / float(W), vp.y / float(H)))))
	_view.size = Vector2(W * _k, H * _k)
	_view.position = ((vp - _view.size) * 0.5).floor()


func _process(delta: float) -> void:
	if not visible:
		return
	if _closing_t >= 0.0:
		_closing_t += delta
		var f := 1.0 - clampf(_closing_t / (OPEN_SEC * 0.7), 0.0, 1.0)
		_set_open(f)
		if f <= 0.0:
			visible = false
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			closed.emit()
		return
	_t += delta
	_msg_t += delta
	_open_t += delta
	_set_open(clampf(_open_t / OPEN_SEC, 0.0, 1.0))
	if get_tree().paused:
		return
	var m := (get_viewport().get_mouse_position() - _view.position) / float(_k)
	_mouse = m if Rect2(Vector2.ZERO, Vector2(W, H)).has_point(m) else Vector2(-1, -1)
	_find_hover()
	if _hover != "" or _held != "":
		HandCursor.want(HandCursor.GRAB if _held != "" else HandCursor.POINT)
	if _held != "":
		_drag(_mouse)
	for p in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 1.3)
	_tick(delta)
	_canvas.queue_redraw()


func _set_open(f: float) -> void:
	var step := ceilf(f * OPEN_STEPS) / OPEN_STEPS
	_view.pivot_offset = _view.size * 0.5
	_view.scale = Vector2(1.0, maxf(0.02, step))
	_backdrop.color = Color(0, 0, 0, 0.85 * f)


# ── what is under the pointer ────────────────────────────────────────────────

func _all_spots() -> Array:
	var out: Array = []
	# The bar: back, the other stations of the room.
	out.append({"id": "#back", "rect": Rect2(4, H - BAR_H + 3, 64, BAR_H - 6), "verb": "Back to the %s" % ("cellar" if room == "basement" else room)})
	var tabs: Array = _room_tabs()
	for i in tabs.size():
		var st := str(tabs[i][0])
		if st == station:
			continue
		var who := str(taken.get(st, ""))
		out.append({"id": "#tab:" + st, "rect": _tab_rect(i), "verb": ("%s is at the %s" % [who, str(tabs[i][1]).to_lower()]) if who != "" else "Go to the %s" % str(tabs[i][1]).to_lower()})
	var tix := _tickets()
	for i in mini(tix.size(), _rail_slots()):
		out.append({"id": "#ticket:" + str(tix[i]["id"]), "rect": _ticket_rect(i), "verb": _ticket_verb(tix[i])})
	out.append_array(_spots())
	return out


func _find_hover() -> void:
	_hover = ""
	_hover_verb = ""
	if _mouse.x < 0.0:
		return
	var spots := _all_spots()
	# Last drawn on top: the station's own spots before the chrome's are tested last.
	for i in range(spots.size() - 1, -1, -1):
		var s: Dictionary = spots[i]
		if (s["rect"] as Rect2).has_point(_mouse):
			_hover = str(s["id"])
			_hover_verb = str(s.get("verb", ""))
			return


func hovered() -> String:
	return _hover


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	# Esc goes on to the pause menu (main).
	if event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _closing_t >= 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.physical_keycode == KEY_S:
			close_view()
			return
		_key(ke)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			close_view()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _hover == "":
				return
			if _hover == "#back":
				close_view()
			elif _hover.begins_with("#tab:"):
				var st := _hover.get_slice(":", 1)
				if str(taken.get(st, "")) == "":
					switch_to.emit(st)
				else:
					sfx("tick", -14.0, 0.7)
			elif _hover.begins_with("#ticket:"):
				_ticket_clicked(_hover.substr(8))
			else:
				_held = _hover
				_press(_hover)
		else:
			_release_held()


func _release_held() -> void:
	if _held == "":
		return
	var was := _held
	_held = ""
	_release(was)


# ── tickets ──────────────────────────────────────────────────────────────────

func _tickets() -> Array:
	return kitchen.tickets(building_key) if kitchen != null and building_key != "" else []


func _rail_slots() -> int:
	return 12


func _ticket_rect(i: int) -> Rect2:
	return Rect2(8 + i * (TICKET.x + 4), 6, TICKET.x, TICKET.y)


func _ticket_verb(t: Dictionary) -> String:
	var bits: Array = []
	var parts: Dictionary = t["parts"]
	bits.append(RULES.dish_label(str(t["dish"])))
	if str(t["dish"]) == "goulash":
		bits.append("%d dumplings" % int(parts.get("dumpling", 4)))
		if parts.has("onion"):
			bits.append("onion")
	elif not parts.has("tartar"):
		bits.append("no tartar")
	return "%s: %s" % [ORDERS_first(str(t["name"])), ", ".join(bits)]


static func ORDERS_first(full: String) -> String:
	var p := full.split(" ")
	return p[0] if p.size() > 0 else full


func _ticket_clicked(tid: String) -> void:
	picked = "" if picked == tid else tid
	sfx("tick", -12.0, 1.2)


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw_all() -> void:
	var c := _canvas
	c.draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.03, 0.03))
	if picture != null:
		c.draw_texture_rect(picture, Rect2(0, 0, W, H), false)
	_paint(c)
	_draw_glint(c)
	_draw_rail(c)
	_draw_bar(c)
	for p in _pops:
		var k := float(p["t"]) / 1.3
		var at: Vector2 = (p["at"] as Vector2) + Vector2(0, -22.0 * k)
		var col: Color = p["col"]
		col.a = 1.0 - k * k
		var font: Font = RETRO_UI.FONT_BIG if bool(p["big"]) else RETRO_UI.FONT_LABEL
		var size := 20 if bool(p["big"]) else 8
		var w := font.get_string_size(str(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := (at - Vector2(w * 0.5, 0)).floor()
		c.draw_string(font, pos + Vector2(1, 1), str(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a))
		c.draw_string(font, pos, str(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## The thing under the pointer: its corners lit, in steps.
func _draw_glint(c: Control) -> void:
	if _hover == "" or _hover.begins_with("#") or _held != "":
		return
	for s in _spots():
		if str(s["id"]) != _hover:
			continue
		var r: Rect2 = (s["rect"] as Rect2).grow(2.0)
		var on := int(_t * 6.0) % 2 == 0
		var col := Color(1.0, 0.86, 0.45, 0.95 if on else 0.6)
		var L := 6.0
		for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var sx := 1.0 if corner.x <= r.position.x else -1.0
			var sy := 1.0 if corner.y <= r.position.y else -1.0
			var p := (corner as Vector2).floor()
			c.draw_rect(Rect2(p.x if sx > 0 else p.x - L, p.y if sy > 0 else p.y - 1, L, 1), col)
			c.draw_rect(Rect2(p.x if sx > 0 else p.x - 1, p.y if sy > 0 else p.y - L, 1, L), col)
		return


func _draw_rail(c: Control) -> void:
	# The steel rail the tickets are clipped to.
	c.draw_rect(Rect2(0, 0, W, 4), Color(0.16, 0.16, 0.17, 0.92))
	c.draw_rect(Rect2(0, 4, W, 1), Color(0.55, 0.55, 0.58, 0.9))
	c.draw_rect(Rect2(0, 5, W, 1), Color(0.05, 0.05, 0.05, 0.9))
	var tix := _tickets()
	var shown := mini(tix.size(), _rail_slots())
	for i in shown:
		_draw_ticket(c, tix[i], _ticket_rect(i))
	if tix.size() > shown:
		ink(c, Vector2(_ticket_rect(shown).position.x + 2, 30), "+%d" % (tix.size() - shown), RETRO_UI.C_AMBER_LIGHT)
	if tix.is_empty():
		ink(c, Vector2(10, 18), "NO ORDERS", Color(0.75, 0.72, 0.64, 0.8))


func _draw_ticket(c: Control, t: Dictionary, r: Rect2) -> void:
	var is_picked := str(t["id"]) == picked
	if is_picked:
		r.position.y += 4.0
	var age := int(t.get("age", 0))
	var band := RULES.patience_band(age)
	if tex("ticket") != null:
		c.draw_texture_rect(tex("ticket"), r, false)
	else:
		c.draw_rect(r, Color(0.92, 0.88, 0.76))
	if band == 2 and tex("ticket_old") != null:
		c.draw_texture_rect(tex("ticket_old"), r, false, Color(1, 1, 1, clampf(float(age - RULES.PATIENCE_LATE) / 40.0, 0.0, 1.0)))
	var x0 := r.position.x
	var ink_col := Color(0.16, 0.12, 0.10)
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x0 + 3, r.position.y + 14), ORDERS_first(str(t["name"])).substr(0, 7).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.1, 0.08))
	# The dish, big; under it what is different about this one.
	var main_ic: Texture2D = _tex.get("icon:" + {"goulash": "goulash", "smazak": "cheese", "fries": "fries"}.get(str(t["dish"]), "goulash"), null)
	if main_ic != null:
		var sz := main_ic.get_size() * 2.0
		c.draw_texture_rect(main_ic, Rect2(Vector2(floorf(x0 + (r.size.x - sz.x) * 0.5), r.position.y + 17), sz), false)
	var parts: Dictionary = t["parts"]
	var notes: Array = []
	match str(t["dish"]):
		"goulash":
			notes.append(["dumpling", "x%d" % int(parts.get("dumpling", 4))])
			if parts.has("onion"):
				notes.append(["onion", "+"])
		"smazak", "fries":
			if not parts.has("tartar"):
				notes.append(["tartar", "NO"])
			elif str(t["dish"]) == "fries":
				notes.append(["tartar", "+"])
	var nx := x0 + 3
	for n in notes:
		var ic: Texture2D = _tex.get("icon:" + str(n[0]), null)
		if ic != null:
			c.draw_texture_rect(ic, Rect2(nx, r.position.y + 40, ic.get_width(), ic.get_height()), false)
			nx += ic.get_width() + 1
		var col := Color(0.6, 0.08, 0.05) if str(n[1]) == "NO" else ink_col
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(nx, r.position.y + 49), str(n[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		nx += RETRO_UI.FONT_TEXT.get_string_size(str(n[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 2
	# How long they have waited: a bar along the bottom, green, amber, red.
	var left := 1.0 - clampf(float(age) / float(RULES.PATIENCE_GONE), 0.0, 1.0)
	var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
	var bar := Rect2(x0 + 3, r.end.y - 6, r.size.x - 6, 3)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	if band < 2 or int(_t * 4.0) % 2 == 0:
		c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * left), bar.size.y)), col)
	if is_picked:
		c.draw_rect(Rect2(r.position - Vector2(1, 1), Vector2(r.size.x + 2, 1)), RETRO_UI.C_AMBER)
		c.draw_rect(Rect2(Vector2(r.position.x - 1, r.end.y), Vector2(r.size.x + 2, 1)), RETRO_UI.C_AMBER)
		c.draw_rect(Rect2(r.position - Vector2(1, 1), Vector2(1, r.size.y + 2)), RETRO_UI.C_AMBER)
		c.draw_rect(Rect2(Vector2(r.end.x, r.position.y - 1), Vector2(1, r.size.y + 2)), RETRO_UI.C_AMBER)


func _tab_rect(i: int) -> Rect2:
	return Rect2(78 + i * 70, H - BAR_H + 3, 66, BAR_H - 6)


func _draw_bar(c: Control) -> void:
	var y0 := float(H - BAR_H)
	# The sentence: what a click does now, or what was last said.
	var line := _hover_verb
	var who := ""
	var col := RETRO_UI.C_BONE
	if line == "" and _msg != "" and _msg_t < 6.0:
		line = _msg
		who = _msg_who
		col = RETRO_UI.C_QUOTE
	if line != "":
		var full := (who.to_upper() + "  " if who != "" else "") + line
		var w := RETRO_UI.FONT_TEXT.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var x := floorf((W - w) * 0.5)
		c.draw_rect(Rect2(x - 5, y0 - 15, w + 10, 13), Color(0.03, 0.025, 0.02, 0.82))
		if who != "":
			c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y0 - 5), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_AMBER)
			x += RETRO_UI.FONT_TEXT.get_string_size(who.to_upper() + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			full = line
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y0 - 5), full, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	# The bar itself: a bevelled plate.
	c.draw_rect(Rect2(0, y0, W, BAR_H), RETRO_UI.C_PLATE)
	c.draw_rect(Rect2(0, y0, W, 1), RETRO_UI.C_PLATE_LIGHT)
	c.draw_rect(Rect2(0, H - 1, W, 1), RETRO_UI.C_PLATE_DARK)
	_button(c, Rect2(4, y0 + 3, 64, BAR_H - 6), "< BACK", _hover == "#back", false)
	var tabs: Array = _room_tabs()
	for i in tabs.size():
		var st := str(tabs[i][0])
		var label := str(tabs[i][1])
		var busy := str(taken.get(st, "")) != ""
		_button(c, _tab_rect(i), label if not busy else str(taken[st]).to_upper().substr(0, 8), _hover == "#tab:" + st, st == station, busy)
	_paint_bar(c, Rect2(78 + tabs.size() * 70 + 6, y0 + 3, W - (78 + tabs.size() * 70 + 6) - 4, BAR_H - 6))


func _button(c: Control, r: Rect2, text: String, hot: bool, down: bool, dim := false) -> void:
	var bg := RETRO_UI.C_PLATE_DARK if down else (Color(0.36, 0.31, 0.24) if hot else Color(0.2, 0.18, 0.15))
	c.draw_rect(r, bg)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), RETRO_UI.C_PLATE_DARK if down else RETRO_UI.C_PLATE_LIGHT)
	c.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), RETRO_UI.C_PLATE_DARK if down else RETRO_UI.C_PLATE_LIGHT)
	c.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(r.size.x, 1)), RETRO_UI.C_PLATE_LIGHT if down else RETRO_UI.C_PLATE_DARK)
	c.draw_rect(Rect2(Vector2(r.end.x - 1, r.position.y), Vector2(1, r.size.y)), RETRO_UI.C_PLATE_LIGHT if down else RETRO_UI.C_PLATE_DARK)
	var col := RETRO_UI.C_AMBER if down else (RETRO_UI.C_AMBER_LIGHT if hot else RETRO_UI.C_BONE)
	if dim:
		col = RETRO_UI.C_BONE_DIM
	var w := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(floorf(r.position.x + (r.size.x - w) * 0.5), r.position.y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## The right end of the bar: the station's own counts (plates, trays). Subclasses add.
func _paint_bar(c: Control, r: Rect2) -> void:
	if kitchen == null:
		return
	var pl: Dictionary = kitchen.plates(building_key)
	var text := "PLATES %d" % int(pl["clean"])
	if int(pl["dirty"]) > 0:
		text += "   DIRTY %d" % int(pl["dirty"])
	var w := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(r.end.x - w - 2, r.position.y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_RED_LIGHT if int(pl["clean"]) == 0 else RETRO_UI.C_BONE_DIM)


## Text with a one-pixel shadow, at `at` (the baseline).
func ink(c: Control, at: Vector2, text: String, col: Color, font: Font = null, size := 8) -> void:
	var f: Font = font if font != null else RETRO_UI.FONT_LABEL
	c.draw_string(f, at.floor() + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.9))
	c.draw_string(f, at.floor(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A sprite of the bistro's centred on `at` at its own size (`k` whole times bigger).
func blit(c: Control, n: String, at: Vector2, alpha := 1.0, k := 1, flip := false, tint := Color(1, 1, 1)) -> void:
	var t := tex(n)
	if t == null or alpha <= 0.0:
		return
	var sz := t.get_size() * float(k * PIX)
	var r := Rect2((at - sz * 0.5).floor(), sz)
	if flip:
		r = Rect2(Vector2(r.end.x, r.position.y), Vector2(-r.size.x, r.size.y))
	c.draw_texture_rect(t, r, false, Color(tint.r, tint.g, tint.b, alpha))


## A picture's size on the canvas (its own size, PIX times).
func tsize(n: String) -> Vector2:
	var t := tex(n)
	return t.get_size() * float(PIX) if t != null else Vector2.ZERO


## A meter: a frame and a fill (0..1), with a marked zone (the golden window).
func meter(c: Control, r: Rect2, fill: float, zone := Vector2(-1, -1), col := RETRO_UI.C_AMBER, vertical := false) -> void:
	c.draw_rect(r.grow(1.0), Color(0.02, 0.02, 0.02, 0.85))
	c.draw_rect(r, Color(0.16, 0.13, 0.1, 0.9))
	if zone.x >= 0.0:
		if vertical:
			c.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * zone.y, r.size.x, r.size.y * (zone.y - zone.x)), Color(0.3, 0.55, 0.22, 0.75))
		else:
			c.draw_rect(Rect2(r.position.x + r.size.x * zone.x, r.position.y, r.size.x * (zone.y - zone.x), r.size.y), Color(0.3, 0.55, 0.22, 0.75))
	var f := clampf(fill, 0.0, 1.0)
	if vertical:
		var h := floorf(r.size.y * f)
		c.draw_rect(Rect2(r.position.x + 1, r.end.y - h, r.size.x - 2, h), col)
	else:
		c.draw_rect(Rect2(r.position.x, r.position.y + 1, floorf(r.size.x * f), r.size.y - 2), col)


# ── for subclasses ───────────────────────────────────────────────────────────

## The tabs on the bar: the stations of the room you are in, [[id, LABEL], ...].
func _room_tabs() -> Array:
	return ROOM_STATIONS.get(room, [])


func _spots() -> Array:
	return []


func _paint(_c: Control) -> void:
	pass


func _press(_id: String) -> void:
	pass


func _release(_id: String) -> void:
	pass


func _drag(_at: Vector2) -> void:
	pass


func _key(_e: InputEventKey) -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _opened() -> void:
	pass


func _closing() -> void:
	pass
