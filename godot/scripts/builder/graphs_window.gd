extends Control

## Builder 98's Graphs window (DESIGN §5j), Transport Tycoon's in a 1998 dress: one page
## at a time (Cash, Guests, Mood, Goggle, Takings), the last two weeks, a line per thing,
## the grid and the numbers along the sides; on Takings a line per kind of business,
## each one's name in the legend turning it off and on. The days come from main's
## _day_graph (scripts/builder/day_graph.gd), today's point live.

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const SIZE := Vector2(440, 268)
const PAGES := [["money", "Cash"], ["guests", "Guests"], ["mood", "Mood"], ["rating", "Goggle"], ["takings", "Takings"]]
const KINDS := [["pub", "Pub", Color8(150, 80, 30)], ["rest", "Bistro", Color8(190, 30, 30)], ["vecerka", "Jednota", Color8(30, 70, 190)], ["corn", "Corn stand", Color8(200, 160, 0)]]
const LINE := {"money": Color8(0, 140, 40), "guests": Color8(30, 70, 190), "mood": Color8(220, 120, 0), "rating": Color8(200, 150, 0)}

var page := "money"
var _hidden: Dictionary = {}
var _hits: Array = []
signal closed


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var close := Button.new()
	close.text = "x"
	close.focus_mode = Control.FOCUS_NONE
	close.position = Vector2(SIZE.x - 21, 4)
	close.size = Vector2(16, 14)
	close.pressed.connect(func(): closed.emit())
	add_child(close)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for h in _hits:
			if (h[0] as Rect2).has_point(e.position):
				var a := str(h[1])
				if a.begins_with("page:"):
					page = a.get_slice(":", 1)
				elif a.begins_with("kind:"):
					var k := a.get_slice(":", 1)
					_hidden[k] = not bool(_hidden.get(k, false))
				queue_redraw()
				accept_event()
				return


func _main() -> Node:
	return get_tree().current_scene if get_tree() != null else null


## The page's lines: [[label, colour, [[day, value]...]], ...] and the value's look.
func _lines() -> Array:
	var m := _main()
	var g = m.get("_day_graph") if m != null else null
	if g == null:
		return []
	var today := CoreRoot.get_day() if CoreRoot != null else 1
	match page:
		"money":
			return [["Cash", LINE["money"], g.series("money", today, CoreRoot.get_money())]]
		"guests":
			var people := 0
			if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
				for x in GuestManager.get_guest_life_snapshot():
					people += int((x as Dictionary).get("party_size", 1)) if x is Dictionary else 0
			return [["People staying", LINE["guests"], g.series("guests", today, people)]]
		"mood":
			var mood := 0.0
			if GuestManager != null and GuestManager.has_method("get_camp_mood_summary"):
				mood = float((GuestManager.get_camp_mood_summary() as Dictionary).get("avg_mood", 0.0))
			return [["Mood", LINE["mood"], g.series("mood", today, mood)]]
		"rating":
			var gg = m.get("_goggle")
			return [["Goggle", LINE["rating"], g.series("rating", today, gg.rating(today) if gg != null else null)]]
		"takings":
			var out: Array = []
			var st = CoreRoot.get_state()
			var sites: Dictionary = st.biz.get("sites", {}) if st != null and st.biz is Dictionary else {}
			for k in KINDS:
				var live := 0
				var have := false
				for key in sites:
					var site: Dictionary = sites[key] if sites[key] is Dictionary else {}
					if str(site.get("kind", "")) == str(k[0]):
						have = true
						live += int((site.get("today", {}) as Dictionary).get("takings", 0))
				if have or _any(g.series("takings:" + str(k[0]), today)):
					out.append([str(k[1]), k[2], g.series("takings:" + str(k[0]), today, live if have else null), str(k[0])])
			return out
	return []


static func _any(series: Array) -> bool:
	for p in series:
		if p[1] != null:
			return true
	return false


func _draw() -> void:
	_hits.clear()
	var s := size
	draw_style_box(T.box("window", T.FACE), Rect2(Vector2.ZERO, s))
	var band := Rect2(3, 3, s.x - 6, 17)
	for i in int(ceil(band.size.x / 8.0)):
		draw_rect(Rect2(band.position.x + i * 8, band.position.y, minf(8.0, band.size.x - i * 8), band.size.y), T.TITLE_A.lerp(T.TITLE_B, float(i * 8) / band.size.x))
	draw_string(T.FONT_BOLD, band.position + Vector2(4, 13), tr("Graphs"), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	# The pages.
	var tx := 8.0
	for p in PAGES:
		var pname := tr(str(p[1]))
		var tw := T.FONT.get_string_size(pname, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x + 14
		var tab := Rect2(tx, 24, tw, 18)
		var on := page == str(p[0])
		draw_style_box(T.box("pressed" if on else "raised", Color8(232, 232, 232) if on else T.FACE, Vector4.ZERO), tab)
		draw_string(T.FONT, Vector2(tx + 7, 37), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
		_hits.append([tab, "page:" + str(p[0])])
		tx += tw + 3
	var chart := Rect2(46, 52, s.x - 60, s.y - 52 - 44)
	draw_rect(chart, T.WHITE)
	draw_rect(chart, T.SHADOW, false, 1.0)
	var lines := _lines()
	# The scale: from nought (or the lowest) to the highest, rounded to a nice step.
	var lo := 0.0
	var hi := 1.0
	if page == "rating":
		lo = 1.0
		hi = 5.0
	else:
		for l in lines:
			if l.size() > 3 and bool(_hidden.get(str(l[3]), false)):
				continue
			for p in l[2]:
				if p[1] != null:
					hi = maxf(hi, float(p[1]))
					lo = minf(lo, float(p[1]))
		var step := _nice(maxf(1.0, (hi - lo) / 4.0))
		hi = ceilf(hi / step) * step
		lo = floorf(lo / step) * step
		if hi <= lo:
			hi = lo + step
	for i in 5:
		var gy := chart.end.y - chart.size.y * float(i) / 4.0
		draw_line(Vector2(chart.position.x, gy), Vector2(chart.end.x, gy), Color8(220, 220, 220), 1.0)
		var v := lo + (hi - lo) * float(i) / 4.0
		var label := _fmt(v)
		var lw := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		draw_string(T.FONT, Vector2(chart.position.x - lw - 4, gy + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	# The days along the bottom.
	var n := 0
	if not lines.is_empty():
		n = (lines[0][2] as Array).size()
	for i in n:
		var dx := chart.position.x + (chart.size.x * (float(i) + 0.5) / float(n))
		if i % 2 == (n - 1) % 2:
			var d := str(int(lines[0][2][i][0]))
			var dw := T.FONT.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			draw_string(T.FONT, Vector2(dx - dw * 0.5, chart.end.y + 13), d, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	# The lines, a dot on each day (two pixels thick, like the old ones).
	for l in lines:
		if l.size() > 3 and bool(_hidden.get(str(l[3]), false)):
			continue
		var col: Color = l[1]
		var prev := Vector2.INF
		var pts: Array = l[2]
		for i in pts.size():
			if pts[i][1] == null:
				prev = Vector2.INF
				continue
			var px := chart.position.x + chart.size.x * (float(i) + 0.5) / float(pts.size())
			var py := chart.end.y - chart.size.y * clampf((float(pts[i][1]) - lo) / (hi - lo), 0.0, 1.0)
			var p := Vector2(px, py).floor()
			if prev != Vector2.INF:
				draw_line(prev, p, col, 2.0)
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col)
			prev = p
	# The legend: each line's name (on Takings a click turns it off and on).
	var lx := chart.position.x
	var ly := s.y - 14.0
	if lines.is_empty():
		draw_string(T.FONT, Vector2(lx, ly), tr("Nothing to draw yet."), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.SHADOW)
	for l in lines:
		var off: bool = l.size() > 3 and bool(_hidden.get(str(l[3]), false))
		var nm := tr(str(l[0]))
		var nw := T.FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		draw_rect(Rect2(lx, ly - 8, 10, 8), l[1] if not off else Color8(200, 200, 200))
		draw_string(T.FONT, Vector2(lx + 14, ly), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT if not off else T.SHADOW)
		if l.size() > 3:
			_hits.append([Rect2(lx, ly - 11, nw + 16, 14), "kind:" + str(l[3])])
		lx += nw + 30


static func _nice(step: float) -> float:
	var e := pow(10.0, floorf(log(step) / log(10.0)))
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if step <= m * e:
			return m * e
	return 10.0 * e


func _fmt(v: float) -> String:
	if page == "rating":
		return "%.1f" % v
	if page == "money" or page == "takings":
		if absf(v) >= 1000.0:
			return LANG.f("$%dk", int(round(v / 1000.0)))
		return LANG.money("$%d" % int(round(v)))
	return str(int(round(v)))
