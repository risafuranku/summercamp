extends Control

## GuestRack 98, the district's guest register (okres-hlubocany.cz, free for registered
## facilities). Three lists: who is staying and until when, who is on the way or waiting
## at the barrier and whether their room is ready, and every room with its state.
##
## On some evenings the register has one row more than the camp has guests.

const T = preload("res://scripts/os98/os_theme.gd")
const UNBOOKED_FROM_HOUR := 18
const UNBOOKED_TO_HOUR := 20
const ARCHETYPES := {"quiet_guy": "Quiet Guest", "drunk": "Party Crew", "cheap_chick": "Bargain Group"}

var _shell
var _win
var _tabs: TabContainer
var _guests: Tree
var _arrivals: Tree
var _rooms: Tree
var _summary: Label
var _status: Label
var _tick := 0.0


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_summary = Label.new()
	_summary.position = Vector2(4, 3)
	_summary.add_theme_font_override("font", T.FONT_BOLD)
	add_child(_summary)
	_tabs = TabContainer.new()
	_tabs.position = Vector2(0, 22)
	add_child(_tabs)
	_guests = _make_tree("Guests", ["#", "Name", "Kind", "Beds", "$/day", "Room", "Leaves in"], [36, 130, 100, 40, 54, 90, 80])
	_arrivals = _make_tree("Arrivals", ["Name", "Party", "Kind", "Where", "Room(s)", "Ready"], [130, 44, 100, 150, 120, 60])
	_rooms = _make_tree("Rooms", ["Room", "State", "Guests", "Still to do"], [110, 90, 60, 240])
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4.ZERO))
	bar.name = "StatusBar"
	add_child(bar)
	_status = Label.new()
	_status.position = Vector2(4, 2)
	bar.add_child(_status)
	_tabs.tab_changed.connect(func(_i): refresh())
	resized.connect(_layout)
	_layout()
	refresh()


func reopen(_args: Dictionary) -> void:
	refresh()


func _make_tree(title: String, cols: Array, widths: Array) -> Tree:
	var tr := Tree.new()
	tr.name = title
	tr.columns = cols.size()
	tr.column_titles_visible = true
	tr.hide_root = true
	tr.select_mode = Tree.SELECT_ROW
	for c in cols.size():
		tr.set_column_title(c, str(cols[c]))
		tr.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		tr.set_column_custom_minimum_width(c, int(widths[c]))
		tr.set_column_expand(c, c == cols.size() - 1 or c == 1)
		tr.set_column_clip_content(c, true)
	_tabs.add_child(tr)
	return tr


func _layout() -> void:
	if _tabs == null:
		return
	_tabs.size = Vector2(size.x, size.y - 22 - 20)
	var bar: Panel = get_node("StatusBar")
	bar.position = Vector2(0, size.y - 18)
	bar.size = Vector2(size.x, 18)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0 and is_visible_in_tree():
		_tick = 2.0
		refresh()


func refresh() -> void:
	if _tabs == null or GuestManager == null:
		return
	var data: Dictionary = GuestManager.get_guestrack_overview_data()
	if not bool(data.get("ok", false)):
		_summary.text = "GuestRack: the register is not available."
		return
	var day := int(data.get("day", 1))
	var hour := int(data.get("hour", 0))
	var ov: Dictionary = data.get("overview", {}) if data.get("overview", {}) is Dictionary else {}
	var arrivals: Array = GuestManager.get_arrivals()
	_summary.text = "Day %d  %02d:%02d     Beds %d / %d (free %d)     In camp %d     On the way %d" % [
		day, hour, int(data.get("minute", 0)), int(ov.get("occupied", 0)), int(ov.get("capacity", 0)), int(ov.get("free", 0)),
		int(ov.get("active", 0)) + int(ov.get("sleep", 0)), arrivals.size()]
	match _tabs.current_tab:
		0:
			_fill_guests(data.get("guests", []) if data.get("guests", []) is Array else [], day, hour)
		1:
			_fill_arrivals(arrivals)
		2:
			_fill_rooms()


func _fill_guests(guests: Array, day: int, hour: int) -> void:
	var rooms := _rooms_by_guest()
	_guests.clear()
	var root := _guests.create_item()
	var shown := 0
	for g_any in guests:
		if not (g_any is Dictionary):
			continue
		var g: Dictionary = g_any
		var st := str(g.get("status", ""))
		if st == "expected" or st == "waiting":
			continue
		var it := _guests.create_item(root)
		var name := str(g.get("name", "Guest"))
		it.set_text(0, str(int(g.get("id", -1))))
		it.set_text(1, name + ("  (asleep)" if st == "sleep" else ""))
		it.set_text(2, _kind(str(g.get("archetype", ""))))
		it.set_text(3, str(int(g.get("beds_used", 1))))
		it.set_text(4, "$%d" % int(g.get("daily_income", 0)))
		it.set_text(5, str(rooms.get(int(g.get("id", -1)), "")))
		it.set_text(6, str(g.get("remaining_label", "")))
		shown += 1
	# One row more than there are guests. Nobody booked it.
	if shown > 0 and day >= 2 and day % 3 == 2 and hour >= UNBOOKED_FROM_HOUR and hour < UNBOOKED_TO_HOUR:
		var it := _guests.create_item(root)
		it.set_text(0, "0")
		for c in range(1, 7):
			it.set_text(c, "-")
	_status.text = "%d record(s). Sorted by departure." % shown if shown > 0 else "Nobody is staying in the camp."


func _fill_arrivals(rows: Array) -> void:
	_arrivals.clear()
	var root := _arrivals.create_item()
	for r_any in rows:
		var r: Dictionary = r_any
		var it := _arrivals.create_item(root)
		it.set_text(0, str(r.get("name", "Guest")))
		it.set_text(1, str(int(r.get("party_size", 1))))
		it.set_text(2, _kind(str(r.get("archetype", ""))))
		var mins := int(r.get("minutes", 0))
		if bool(r.get("at_gate", false)):
			it.set_text(3, "AT THE BARRIER %d:%02d" % [mins / 60, mins % 60])
			it.set_custom_color(3, Color8(160, 0, 0))
		else:
			it.set_text(3, "arrives in %d:%02d" % [mins / 60, mins % 60])
		var labels: Array = []
		var ready := true
		for room in r.get("rooms", []):
			labels.append(str(room.get("label", "")))
			ready = ready and bool(room.get("ready", false))
		it.set_text(4, ", ".join(labels))
		it.set_text(5, "yes" if ready else "NO")
		it.set_custom_color(5, Color8(0, 110, 0) if ready else Color8(160, 0, 0))
	_status.text = "Nobody is on the way." if rows.is_empty() else "Rooms must be made up before the guests reach the barrier."


func _fill_rooms() -> void:
	_rooms.clear()
	var root := _rooms.create_item()
	var states: Dictionary = GuestManager.get_accommodation_states()
	var keys := states.keys()
	keys.sort()
	var to_do := 0
	for key in keys:
		var rs: Dictionary = GuestManager.get_room_state(str(key))
		if rs.is_empty():
			continue
		var it := _rooms.create_item(root)
		it.set_text(0, str(rs.get("label", key)))
		var st := str(rs.get("status", ""))
		it.set_text(1, {"ready": "ready", "dirty": "DIRTY", "unprepared": "not made up"}.get(st, st))
		if st != "ready":
			it.set_custom_color(1, Color8(160, 0, 0))
			to_do += 1
		it.set_text(2, "occupied" if bool(rs.get("occupied", false)) else "-")
		var names: Array = []
		for t in rs.get("remaining", []):
			names.append(str(t.get("label", t.get("id", ""))))
		it.set_text(3, ", ".join(names))
	_status.text = "%d room(s), %d to make up. Go to the room and do it by hand." % [keys.size(), to_do]


## Guest id -> "Tent 4:7" (the first room they sleep in).
func _rooms_by_guest() -> Dictionary:
	var out := {}
	var state = CoreRoot.get_state()
	if state == null:
		return out
	for g_any in state.guests:
		if not (g_any is Dictionary):
			continue
		var slots: Array = g_any.get("lodging_slots", []) if g_any.get("lodging_slots", []) is Array else []
		for s in slots:
			if s is Dictionary and not str(s.get("accommodation_key", "")).is_empty():
				out[int(g_any.get("id", -1))] = GuestManager.room_label(str(s["accommodation_key"]))
				break
	return out


func _kind(raw: String) -> String:
	var k := raw.strip_edges().to_lower()
	if ARCHETYPES.has(k):
		return ARCHETYPES[k]
	return k.replace("_", " ").capitalize() if not k.is_empty() else "-"
