extends CanvasLayer

## The frame under the room while you are at a station (scripts/business/station3d.gd),
## at the game's 2D pixel (640 x 360 to the screen, a whole number of times):
##   the sentence   over the bar, what a click would do now ("Turn the slice"), or what
##                  was just said (a guest at the hatch, "The pan is full."), like the verb
##                  line of an old adventure game;
##   the bar        BACK (S, the right button), the room's other stations (1-4, Tab), the
##                  station's own buttons (SCRAPE) and its counts at the right end;
##   the ticket     the one you picked on the rail, big, at the right (Papa's), ticking off
##                  what is on the plate;
##   the timers     what is cooking at the other stations of the room (the pan, the
##                  basket, the pot), small columns at the left, so you can mind the stove
##                  from the pass.
## One per business room, made by scripts/service_interior.gd; shown while a station is
## open. Nothing here explains anything: the things in the room do.

signal back
signal tab(station: String)
signal button(id: String)

const RETRO_UI := preload("res://scripts/ui/retro_ui.gd")
const W := 640
const H := 360
const BAR_H := 22
const BIG := Vector2(84, 112)

## The station open now (station3d), set by the room.
var station: Node
## The room's stations for the tabs: [[id, LABEL], ...].
var tabs: Array = []
## Other wardens at this room's stations: id -> name.
var taken: Dictionary = {}
## -> [{icon: Texture2D, fill, zone: Vector2, col: Color, blink: bool}] (the timers).
var mirror_of: Callable

var _c: Control
var _k := 2
var _hover := ""
var _msg := ""
var _msg_who := ""
var _msg_t := 99.0
var _t := 0.0


func _ready() -> void:
	layer = 96
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Your hands are on the station (scripts/town/pockets.gd keeps them down).
	add_to_group("closeup")
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw)
	add_child(_c)


func say(who: String, text: String) -> void:
	_msg_who = who
	_msg = text
	_msg_t = 0.0


func clear_say() -> void:
	_msg = ""
	_msg_t = 99.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_msg_t += delta
	_c.queue_redraw()


## The frame's own pixel under a point of the screen.
func to_ui(screen: Vector2) -> Vector2:
	var s := _c.get_viewport_rect().size
	_k = maxi(1, int(floor(minf(s.x / float(W), s.y / float(H)))))
	var off := ((s - Vector2(W, H) * float(_k)) * 0.5).floor()
	return (screen - off) / float(_k)


## What of the frame is under the screen point ("" none): "#back", "#tab:<id>",
## "#btn:<id>" (the station's buttons), "#ticket" (the big one: nothing to do).
func hit(screen: Vector2) -> String:
	if not visible:
		return ""
	var m := to_ui(screen)
	if Rect2(4, H - BAR_H + 3, 64, BAR_H - 6).has_point(m):
		return "#back"
	for i in tabs.size():
		if _tab_rect(i).has_point(m):
			return "#tab:" + str(tabs[i][0])
	var btns := _buttons()
	for i in btns.size():
		if _btn_rect(i, btns.size()).has_point(m):
			return "#btn:" + str(btns[i]["id"])
	if m.y >= H - BAR_H:
		return "#bar"
	if _big_rect().has_point(m) and station != null and not (station.call("big_ticket") as Dictionary).is_empty():
		return "#ticket"
	return ""


func set_hover(id: String) -> void:
	_hover = id


func _buttons() -> Array:
	return station.call("bar_buttons") if station != null and station.has_method("bar_buttons") else []


func _tab_rect(i: int) -> Rect2:
	return Rect2(78 + i * 70, H - BAR_H + 3, 66, BAR_H - 6)


func _btn_rect(i: int, n: int) -> Rect2:
	return Rect2(W - 4 - (n - i) * 76, H - BAR_H + 3, 72, BAR_H - 6)


## The picked ticket hangs at the right end of the rail, big.
func _big_rect() -> Rect2:
	return Rect2(W - BIG.x - 6, 8, BIG.x, BIG.y)


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
	_button(Rect2(4, H - BAR_H + 3, 64, BAR_H - 6), "< BACK", _hover == "#back", false)
	var cur := str(station.get("station")) if station != null else ""
	for i in tabs.size():
		var id := str(tabs[i][0])
		var busy := str(taken.get(id, "")) != ""
		var text := ("%d %s" % [i + 1, str(tabs[i][1])]) if not busy else str(taken[id]).to_upper().substr(0, 8)
		_button(_tab_rect(i), text, _hover == "#tab:" + id, id == cur, busy)
	var btns := _buttons()
	for i in btns.size():
		_button(_btn_rect(i, btns.size()), str(btns[i]["label"]), _hover == "#btn:" + str(btns[i]["id"]), false)
	if station != null:
		var counts := str(station.call("bar_text"))
		if counts != "":
			var right := W - 6 - btns.size() * 76
			var w := RETRO_UI.FONT_LABEL.get_string_size(counts, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var lx := maxf(78.0 + tabs.size() * 70.0 + 6.0, right - w)
			_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(lx, H - BAR_H + 14), counts, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_BONE_DIM)
	_draw_sentence()
	_draw_big()
	_draw_mirror()


func _draw_sentence() -> void:
	var line := str(station.call("hover_verb")) if station != null else ""
	var who := ""
	var col := RETRO_UI.C_AMBER_LIGHT
	if _msg != "" and _msg_t < 4.5 and (line == "" or _msg_t < 1.6):
		line = _msg
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
	var cw := 14.0
	var w := 6.0 + rows.size() * cw
	var h := 40.0
	var r := Rect2(6, H - BAR_H - h - 22, w, h)
	_c.draw_rect(r.grow(1.0), Color(0.03, 0.025, 0.02, 0.9))
	_c.draw_rect(r, Color(0.14, 0.12, 0.1, 0.9))
	for i in rows.size():
		var row: Dictionary = rows[i]
		var x := r.position.x + 4 + i * cw
		var ic: Texture2D = row.get("icon", null)
		if ic != null:
			var isz := ic.get_size()
			var sc := minf(1.0, 12.0 / maxf(isz.x, isz.y))
			_c.draw_texture_rect(ic, Rect2(Vector2(x, r.position.y + 2), (isz * sc).floor()), false)
		var bar := Rect2(x + 3, r.position.y + 16, 5, h - 19)
		_c.draw_rect(bar.grow(1.0), Color(0.02, 0.02, 0.02))
		_c.draw_rect(bar, Color(0.2, 0.17, 0.13))
		var zone: Vector2 = row.get("zone", Vector2(-1, -1))
		if zone.x >= 0.0:
			_c.draw_rect(Rect2(bar.position.x, bar.end.y - bar.size.y * zone.y, bar.size.x, bar.size.y * (zone.y - zone.x)), Color(0.24, 0.42, 0.18))
		var fill := clampf(float(row.get("fill", 0.0)), 0.0, 1.0)
		if not bool(row.get("blink", false)) or int(_t * 4.0) % 2 == 0:
			var fh := floorf(bar.size.y * fill)
			_c.draw_rect(Rect2(bar.position.x, bar.end.y - fh, bar.size.x, fh), row.get("col", RETRO_UI.C_AMBER))


func _button(r: Rect2, text: String, hot: bool, down: bool, dim := false) -> void:
	var bg := RETRO_UI.C_PLATE_DARK if down else (Color(0.36, 0.31, 0.24) if hot else Color(0.2, 0.18, 0.15))
	_c.draw_rect(r, bg)
	_c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), RETRO_UI.C_PLATE_DARK if down else RETRO_UI.C_PLATE_LIGHT)
	_c.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), RETRO_UI.C_PLATE_DARK if down else RETRO_UI.C_PLATE_LIGHT)
	_c.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(r.size.x, 1)), RETRO_UI.C_PLATE_LIGHT if down else RETRO_UI.C_PLATE_DARK)
	_c.draw_rect(Rect2(Vector2(r.end.x - 1, r.position.y), Vector2(1, r.size.y)), RETRO_UI.C_PLATE_LIGHT if down else RETRO_UI.C_PLATE_DARK)
	var col := RETRO_UI.C_AMBER if down else (RETRO_UI.C_AMBER_LIGHT if hot else RETRO_UI.C_BONE)
	if dim:
		col = RETRO_UI.C_BONE_DIM
	var w := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_c.draw_string(RETRO_UI.FONT_LABEL, Vector2(floorf(r.position.x + (r.size.x - w) * 0.5), r.position.y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
