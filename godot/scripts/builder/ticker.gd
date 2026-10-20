extends Control

## Builder 98's message line, RollerCoaster Tycoon's: along the foot of the map what goes
## on in the camp as it happens ("Pepa: The toilets are filthy.", "The pub has broken
## down.", "Your camp won a diploma"), each with its little picture, the newest sliding in
## from the right; a click on it takes the map there (to the building, or after the
## guest). What matters more pops up a moment as a small window in the map's corner too.
## The camp's own news, read from the camp (EventBus, GuestManager, the grid), never made
## up here. builder_module.gd owns it and lays it out.

signal go_to(coord: Vector2i)
signal follow(guest_id: int)

const T = preload("res://scripts/os98/os_theme.gd")
const ICON_DIR := "res://assets/textury/builder/news/"
## The icons by kind (Grok bld_icons, cut by tools/artgen: guest, toilet, medal, coins,
## rain, cabin, warning, tree); the line works without them.
const ICONS := ["guest", "toilet", "medal", "coins", "rain", "cabin", "warning", "tree"]
const KEEP := 30
const SHOW_SEC := 9.0
const POP_SEC := 6.0
const SCROLL_PX := 40.0
const SFX := "res://assets/sfx/builder/ticker.mp3"

var _items: Array = []        # {text, icon, coord, guest, bad, t}
var _shown := -1
var _shown_t := 0.0
var _scroll := 0.0
var _icons: Dictionary = {}
var _pop: Dictionary = {}
var _pop_t := 0.0
var _thoughts: Dictionary = {}   # guest id -> last thought seen
var _dirt: Dictionary = {}       # block origin -> filthy last look
var _poll := 1.0
var _snd: AudioStreamPlayer
## The corner window for what matters (a breakdown, a diploma, guests driving off).
var popup: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	for k in ICONS:
		var p: String = ICON_DIR + str(k) + ".png"
		_icons[k] = load(p) if ResourceLoader.exists(p) else null
	popup = Control.new()
	popup.size = Vector2(196, 44)
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.draw.connect(_draw_popup)
	popup.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_jump(_pop)
			popup.visible = false)
	EventBus.guest_at_gate.connect(func(g: Dictionary): add("%s %s at the gate." % [_first(g), "is" if int(g.get("party_size", 1)) <= 1 else "and party are"], "guest"))
	EventBus.guest_checked_in.connect(func(g: Dictionary): add("%s moved into %s." % [_first(g), _room_of(g)], "cabin", _lodging(g)))
	EventBus.guest_gave_up.connect(func(g: Dictionary): add("%s gave up waiting and drove off." % _first(g), "warning", Vector2i(-1, -1), -1, true, true))
	EventBus.guest_review_posted.connect(func(r: Dictionary):
		var stars := int(r.get("stars", r.get("rating", 0)))
		add("%s wrote a review: %d out of 5." % [str(r.get("name", r.get("author", "A guest"))).split(" ")[0], stars], "guest", Vector2i(-1, -1), -1, stars <= 2, stars <= 1 or stars >= 5))
	EventBus.accommodation_state_changed.connect(func(key: String, status: String, _n: int):
		if status == "dirty" and key.contains(":"):
			add("%s needs cleaning." % _room_label(key), "cabin", _coord(key)))
	EventBus.building_failed.connect(func(c: Vector2i, t: String): add("The %s has broken down." % _name(t), "warning", c, -1, true, true))
	EventBus.building_serviced.connect(func(c: Vector2i, t: String, was_broken: bool, _cost: int):
		if was_broken:
			add("The %s works again." % _name(t), "warning", c))
	_snd = AudioStreamPlayer.new()
	_snd.stream = load(SFX) if ResourceLoader.exists(SFX) else null
	add_child(_snd)


## A message: what, its picture, where (a cell, or a guest to follow); `bad` reds it,
## `pop` puts it in the corner window too.
func add(text: String, icon := "", coord := Vector2i(-1, -1), guest := -1, bad := false, pop := false) -> void:
	if not _items.is_empty() and str(_items.back()["text"]) == text:
		return
	_items.append({"text": text, "icon": icon, "coord": coord, "guest": guest, "bad": bad, "t": Time.get_ticks_msec()})
	while _items.size() > KEEP:
		_items.pop_front()
	if pop:
		_pop = _items.back()
		_pop_t = POP_SEC
		popup.visible = is_visible_in_tree()
		popup.queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 2.0
		_poll_camp()
	# The next message in when the one up has been read (or at once, a newer one waiting).
	_shown_t -= delta
	if _shown < _items.size() - 1 and (_shown_t <= 0.0 or _shown_t < SHOW_SEC - 3.0):
		_shown += 1
		_shown_t = SHOW_SEC
		_scroll = -size.x
		if _snd.stream != null:
			_snd.volume_db = -14.0 + _shell_db()
			_snd.play()
	var was := floorf(_scroll)
	_scroll += delta * SCROLL_PX * 4.0 if _scroll < 0.0 else delta * SCROLL_PX
	if floorf(_scroll) != was:
		queue_redraw()
	if popup.visible:
		_pop_t -= delta
		if _pop_t <= 0.0:
			popup.visible = false


func _shell_db() -> float:
	var n: Node = self
	while n != null and not n.has_method("sound_db"):
		n = n.get_parent()
	return float(n.call("sound_db")) if n != null else 0.0


## What the camp says without a signal for it: the guests' new thoughts, a block gone
## filthy.
func _poll_camp() -> void:
	if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			if not (g is Dictionary):
				continue
			var id := int(g.get("id", -1))
			var th := str(g.get("thought", ""))
			var was = _thoughts.get(id, null)
			_thoughts[id] = th
			if was == null or th == "" or th == str(was) or int(g.get("thought_age", 9999)) > 30:
				continue
			var mood := float(g.get("mood", 50.0))
			add("%s: %s" % [str(g.get("name", "Guest")).split(" ")[0], th], "guest", Vector2i(-1, -1), id, mood < 35.0)
	var st = CoreRoot.get_state() if CoreRoot != null else null
	if st == null:
		return
	for c in st.grid.cells:
		var d: Dictionary = st.grid.cells[c]
		var t := str(d.get("type", ""))
		if (t != "toilet_block" and t != "shower_block") or d.get("root_coord", c) != c:
			continue
		var filthy := float(d.get("maintenance", 1.0)) < 0.35
		if filthy and not bool(_dirt.get(c, true)):
			add("The %s are filthy." % ("toilets" if t == "toilet_block" else "showers"), "toilet", c, -1, true)
		_dirt[c] = filthy


func _jump(item: Dictionary) -> void:
	if item.is_empty():
		return
	if int(item.get("guest", -1)) >= 0:
		follow.emit(int(item["guest"]))
	elif (item.get("coord", Vector2i(-1, -1)) as Vector2i).x >= 0:
		go_to.emit(item["coord"])


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _shown >= 0 and _shown < _items.size():
		_jump(_items[_shown])
		accept_event()


func _draw() -> void:
	draw_style_box(T.box("well", Color8(16, 22, 18), Vector4.ZERO), Rect2(Vector2.ZERO, size))
	if _shown < 0 or _shown >= _items.size():
		return
	var it: Dictionary = _items[_shown]
	var text := str(it["text"])
	var tw := T.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var room := size.x - 26.0
	# In from the right, then, longer than the line, creeping along to its end.
	var x := 22.0 + maxf(0.0, -_scroll)
	if _scroll > 1.5 * SCROLL_PX and tw > room:
		x -= minf(tw - room + 8.0, floorf(_scroll - 1.5 * SCROLL_PX))
	var col: Color = Color8(255, 120, 100) if bool(it["bad"]) else Color8(130, 255, 130)
	draw_string(T.FONT, Vector2(floorf(x), 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)
	# Its picture over the start of the line.
	draw_rect(Rect2(2, 1, 18, size.y - 2), Color8(16, 22, 18))
	var tex: Texture2D = _icons.get(str(it["icon"]))
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2(4, 1), Vector2(14, 14)), false)


func _draw_popup() -> void:
	if _pop.is_empty():
		return
	var s := popup.size
	popup.draw_style_box(T.box("window", T.FACE), Rect2(Vector2.ZERO, s))
	var tex: Texture2D = _icons.get(str(_pop["icon"]))
	popup.draw_rect(Rect2(5, 5, 34, 34), Color8(40, 56, 40))
	if tex != null:
		popup.draw_texture_rect(tex, Rect2(7, 7, 30, 30), false)
	T.FONT.draw_multiline_string(popup.get_canvas_item(), Vector2(44, 15), str(_pop["text"]), HORIZONTAL_ALIGNMENT_LEFT, s.x - 50, T.FONT_SIZE, 2, Color8(150, 0, 0) if bool(_pop["bad"]) else T.TEXT)


func _first(g: Dictionary) -> String:
	return str(g.get("name", "A guest")).split(" ")[0]


func _lodging(g: Dictionary) -> Vector2i:
	for s in g.get("lodging_slots", []):
		if s is Dictionary and str(s.get("accommodation_key", "")).contains(":"):
			return _coord(str(s["accommodation_key"]))
	return Vector2i(-1, -1)


func _room_of(g: Dictionary) -> String:
	var c := _lodging(g)
	return _room_label("%d:%d" % [c.x, c.y]) if c.x >= 0 else "the camp"


func _room_label(key: String) -> String:
	if GuestManager != null and GuestManager.has_method("room_label"):
		var l := str(GuestManager.room_label(key))
		if l != "":
			return l
	return "a room"


func _coord(key: String) -> Vector2i:
	return Vector2i(int(key.get_slice(":", 0)), int(key.get_slice(":", 1))) if key.contains(":") else Vector2i(-1, -1)


func _name(t: String) -> String:
	var names := {"toilet_block": "toilets", "shower_block": "showers", "restaurant": "bistro", "vecerka": "Jednota", "main_building": "office",
		"lamp_post": "lamp", "power_generator": "generator", "sewer": "sewage pump", "corn_stand": "corn stand", "lake_slide": "slide"}
	return str(names.get(t, t.get_slice("_", 0)))
