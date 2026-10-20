extends Control

## GuestRack 98, the district's guest register (okres-hlubocany.cz, free for registered
## facilities). A banner with the district's crest, four counters, then three lists:
## who is staying (with a card for the one you pick: mood, needs, room, what they said),
## who is on the way or waiting at the barrier and whether their room is ready, and every
## room with what is still to do beside a plan of the camp (camp_plan.gd): every "show me"
## in the office (CampStat's dirty rooms and upkeep, the guest card, a double-click) opens
## the plan on that building; Builder stays for building.
##
## On some evenings the register has one row more than the camp has guests.

const T = preload("res://scripts/os98/os_theme.gd")
const PLAN = preload("res://scripts/os98/apps/camp_plan.gd")
const NEEDS = preload("res://core/systems/guest_needs_system.gd")
const UNBOOKED_FROM_HOUR := 18
const UNBOOKED_TO_HOUR := 20
const ARCHETYPES := {"quiet_guy": "Quiet Guest", "drunk": "Party Crew", "cheap_chick": "Bargain Group", "tramp": "Tramps", "family": "Family", "picker": "Mushroom Pickers"}
const ROW_A := Color8(255, 255, 255)
const ROW_B := Color8(236, 240, 248)
const RED := Color8(170, 0, 0)
const GREEN := Color8(0, 120, 0)
const AMBER := Color8(150, 100, 0)
const BANNER_H := 34
const COUNTERS_H := 40

var _shell
var _win
var _banner: Control
var _counters: Control
var _counter_values: Array = ["", "", "", ""]
var _tabs: TabContainer
var _guests: Tree
var _arrivals: Tree
var _rooms: Tree
var _card: Control
var _card_guest: Dictionary = {}
var _status: Label
var _tick := 0.0
var _guest_rows: Dictionary = {}   # TreeItem instance id -> snapshot dict
## The guest list's sort: the column (0 mood, 1 name, 2 kind, 3 room, 4 leaving) and the way.
var _sort_col := 4
var _sort_desc := false
var _map_btn: Button
var _empty_guests: Label
var _empty_arrivals: Label
var _plan: Control
var _room_page: Control


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_banner = Control.new()
	_banner.draw.connect(_draw_banner)
	add_child(_banner)
	_counters = Control.new()
	_counters.draw.connect(_draw_counters)
	add_child(_counters)
	_tabs = TabContainer.new()
	add_child(_tabs)
	var guests_page := Control.new()
	guests_page.name = "Guests"
	_tabs.add_child(guests_page)
	_guests = _make_tree(guests_page, ["", "Name", "Kind", "Room", "Leaves in", "Needs"], [22, 112, 84, 72, 58, 96])
	_guests.item_selected.connect(_on_guest_selected)
	_empty_guests = _empty_label(_guests)
	# A click on a column's head sorts by it; again, the other way.
	_guests.column_title_clicked.connect(func(col: int, _b: int):
		if _sort_col == col:
			_sort_desc = not _sort_desc
		else:
			_sort_col = col
			_sort_desc = col == 0
		_shell.play("click", -14.0)
		refresh.call_deferred())
	_card = Control.new()
	_card.draw.connect(_draw_card)
	guests_page.add_child(_card)
	_map_btn = Button.new()
	_map_btn.text = "Show the room on the plan"
	_map_btn.focus_mode = Control.FOCUS_NONE
	_map_btn.visible = false
	_map_btn.pressed.connect(func():
		if _card_guest.get("coord", null) is Vector2i:
			focus(_card_guest["coord"]))
	_card.add_child(_map_btn)
	_card.resized.connect(func(): _map_btn.position = Vector2(6, maxf(0.0, _card.size.y - 28)))
	var arr_page := Control.new()
	arr_page.name = "Arrivals"
	_tabs.add_child(arr_page)
	_arrivals = _make_tree(arr_page, ["", "Name", "Party", "Where", "Room(s)", "Ready", "Still to do"], [22, 110, 38, 120, 90, 44, 120])
	_empty_arrivals = _empty_label(_arrivals)
	_arrivals.item_activated.connect(func():
		var it := _arrivals.get_selected()
		if it != null and it.get_metadata(0) is Vector2i:
			focus(it.get_metadata(0)))
	_room_page = Control.new()
	_room_page.name = "Rooms"
	_tabs.add_child(_room_page)
	_plan = PLAN.new()
	var m = _shell.main_node() if _shell != null else null
	_plan.grid_manager = m.get("grid_manager") if m != null else null
	_room_page.add_child(_plan)
	_rooms = _make_tree(_room_page, ["", "Room", "State", "Still to do"], [22, 70, 84, 120])
	# A room picked in the list blinks on the plan; a building picked on the plan is
	# picked in the list (a room) or told in the status line (anything else).
	_rooms.item_selected.connect(func():
		var it := _rooms.get_selected()
		if it != null and it.get_metadata(0) is Vector2i:
			_plan.focus = it.get_metadata(0)
			_plan.queue_redraw()
			_tell(it.get_metadata(0)))
	_plan.picked.connect(func(c: Vector2i):
		_shell.play("click", -14.0)
		_select_room(c)
		_tell(c))
	_guests.item_activated.connect(func():
		var it := _guests.get_selected()
		var info: Dictionary = _guest_rows.get(it.get_instance_id(), {}) if it != null else {}
		if info.get("coord", null) is Vector2i:
			focus(info["coord"]))
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


func reopen(args: Dictionary) -> void:
	if args.get("focus", null) is Vector2i:
		focus(args["focus"])
	else:
		refresh()


## The plan on one building (a room's origin or any cell of a building): the Rooms tab
## comes forward, the building blinks, a room is picked in the list.
func focus(coord: Vector2i) -> void:
	if _tabs == null:
		return
	_tabs.current_tab = _room_page.get_index()
	refresh()
	var b: Dictionary = _plan.building_at(coord)
	var og: Vector2i = b.get("origin", coord)
	_plan.focus = og
	_plan.rebuild()
	_select_room(og)
	_tell(og)


func _select_room(c: Vector2i) -> void:
	var root := _rooms.get_root()
	var it := root.get_first_child() if root != null else null
	while it != null:
		if it.get_metadata(0) == c:
			if _rooms.get_selected() != it:
				it.select(0)
			_rooms.scroll_to_item(it)
			return
		it = it.get_next()
	_rooms.deselect_all()


## The status line about the building picked on the plan.
func _tell(c: Vector2i) -> void:
	var b: Dictionary = _plan.building_at(c)
	if b.is_empty():
		return
	var rs: Dictionary = b.get("room", {})
	if rs.is_empty():
		var def = CoreRoot.registry.get_def(StringName(str(b["type"]))) if CoreRoot != null and CoreRoot.registry != null else null
		var nm := str(def.display_name).split(" (")[0] if def != null else str(b["type"]).capitalize()
		var cond := float(b.get("condition", -1.0))
		_status.text = "%s: BROKEN, it serves no one until it is repaired." % nm if bool(b["broken"]) else ("%s: %d%% condition." % [nm, int(round(cond * 100.0))] if cond >= 0.0 else nm + ".")
		return
	var names: Array = []
	for t in rs.get("remaining", []):
		names.append(str(t.get("label", t.get("id", ""))))
	var st := str(rs.get("status", ""))
	var word := "occupied" if bool(rs.get("occupied", false)) else {"ready": "ready", "dirty": "DIRTY", "unprepared": "not made up"}.get(st, st) as String
	_status.text = "%s: %s%s" % [str(rs.get("label", "")), word, (". Still to do: " + ", ".join(names)) if not names.is_empty() else "."]


## The grey line in the middle of an empty list.
func _empty_label(tree: Tree) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_top = 24
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", T.SHADOW)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	tree.add_child(l)
	return l


func _make_tree(parent: Control, cols: Array, widths: Array) -> Tree:
	var tr := Tree.new()
	tr.columns = cols.size()
	tr.column_titles_visible = true
	tr.hide_root = true
	tr.select_mode = Tree.SELECT_ROW
	for c in cols.size():
		tr.set_column_title(c, str(cols[c]))
		tr.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		tr.set_column_custom_minimum_width(c, int(widths[c]))
		tr.set_column_expand(c, c == cols.size() - 1)
		tr.set_column_clip_content(c, true)
	parent.add_child(tr)
	# The stripes would paint over the picked row: it goes navy like any list's.
	tr.item_selected.connect(_restripe.bind(tr))
	return tr


func _restripe(tr: Tree) -> void:
	var root := tr.get_root()
	var it := root.get_first_child() if root != null else null
	var i := 0
	while it != null:
		for c in tr.columns:
			if it.is_selected(0) or i % 2 == 0:
				it.clear_custom_bg_color(c)
			else:
				it.set_custom_bg_color(c, ROW_B)
		it = it.get_next()
		i += 1


func _layout() -> void:
	if _tabs == null:
		return
	_banner.position = Vector2.ZERO
	_banner.size = Vector2(size.x, BANNER_H)
	_counters.position = Vector2(0, BANNER_H + 2)
	_counters.size = Vector2(size.x, COUNTERS_H)
	var top := BANNER_H + COUNTERS_H + 4
	_tabs.position = Vector2(0, top)
	_tabs.size = Vector2(size.x, size.y - top - 20)
	var bar: Panel = get_node("StatusBar")
	bar.position = Vector2(0, size.y - 18)
	bar.size = Vector2(size.x, 18)
	var card_w := 176.0
	_guests.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_guests.offset_right = -card_w - 4
	_card.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_card.offset_left = -card_w
	_map_btn.size = Vector2(card_w - 12, 22)
	_map_btn.position = Vector2(6, maxf(0.0, _card.size.y - 28))
	_arrivals.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The plan as big as the page is tall, the list beside it.
	var page_h := maxf(80.0, _tabs.size.y - 30.0)
	var plan_w := clampf(page_h, 120.0, size.x * 0.5)
	_plan.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_plan.offset_right = plan_w
	_rooms.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rooms.offset_left = plan_w + 4


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
		_status.text = "The register is not available."
		return
	var day := int(data.get("day", 1))
	var hour := int(data.get("hour", 0))
	var ov: Dictionary = data.get("overview", {}) if data.get("overview", {}) is Dictionary else {}
	var arrivals: Array = GuestManager.get_arrivals()
	var to_do := 0
	for key in GuestManager.get_accommodation_states():
		var rs: Dictionary = GuestManager.get_room_state(str(key))
		if not rs.is_empty() and str(rs.get("status", "")) != "ready":
			to_do += 1
	_counter_values = [
		"%d / %d" % [int(ov.get("occupied", 0)), int(ov.get("capacity", 0))],
		str(int(ov.get("active", 0)) + int(ov.get("sleep", 0))),
		str(arrivals.size()),
		str(to_do),
	]
	_counters.queue_redraw()
	_tabs.set_tab_title(0, "Guests (%d)" % (int(ov.get("active", 0)) + int(ov.get("sleep", 0))))
	_tabs.set_tab_title(1, "Arrivals (%d)" % arrivals.size() if not arrivals.is_empty() else "Arrivals")
	_tabs.set_tab_title(2, "Rooms (%d to do)" % to_do if to_do > 0 else "Rooms")
	_banner.set_meta("clock", "Day %d  %02d:%02d" % [day, hour, int(data.get("minute", 0))])
	_banner.queue_redraw()
	match _tabs.current_tab:
		0:
			_fill_guests(data.get("guests", []) if data.get("guests", []) is Array else [], day, hour)
		1:
			_fill_arrivals(arrivals)
		2:
			_fill_rooms()
			_plan.rebuild()


# ── lists ────────────────────────────────────────────────────────────────────

func _fill_guests(guests: Array, day: int, hour: int) -> void:
	var rooms := _rooms_by_guest()
	var life := {}
	for g in GuestManager.get_guest_life_snapshot():
		life[int(g.get("id", -1))] = g
	var keep_id := int(_card_guest.get("id", -1))
	_guests.clear()
	_guest_rows.clear()
	var root := _guests.create_item()
	var shown := 0
	var reselect: TreeItem = null
	# In the order asked for (the register comes sorted by departure).
	var rows: Array = []
	for i in guests.size():
		var g_any = guests[i]
		if not (g_any is Dictionary):
			continue
		var st0 := str((g_any as Dictionary).get("status", ""))
		if st0 == "expected" or st0 == "waiting":
			continue
		rows.append([g_any, i])
	rows.sort_custom(func(a, b) -> bool:
		var ga: Dictionary = a[0]
		var gb: Dictionary = b[0]
		var ka: Variant = a[1]
		var kb: Variant = b[1]
		match _sort_col:
			0:
				ka = float(life.get(int(ga.get("id", -1)), {}).get("mood", 60.0))
				kb = float(life.get(int(gb.get("id", -1)), {}).get("mood", 60.0))
			1:
				ka = str(ga.get("name", "")).to_lower()
				kb = str(gb.get("name", "")).to_lower()
			2:
				ka = _kind(str(ga.get("archetype", "")))
				kb = _kind(str(gb.get("archetype", "")))
			3:
				ka = str(rooms.get(int(ga.get("id", -1)), ""))
				kb = str(rooms.get(int(gb.get("id", -1)), ""))
			5:
				ka = _worst_need(life.get(int(ga.get("id", -1)), {}).get("needs", {}))[1]
				kb = _worst_need(life.get(int(gb.get("id", -1)), {}).get("needs", {}))[1]
		if ka == kb:
			return int(a[1]) < int(b[1])
		return (ka > kb) if _sort_desc else (ka < kb))
	for row in rows:
		var g: Dictionary = row[0]
		var st := str(g.get("status", ""))
		var id := int(g.get("id", -1))
		var snap: Dictionary = life.get(id, {})
		var it := _guests.create_item(root)
		var mood := float(snap.get("mood", 60.0))
		it.set_icon(0, _face_icon(mood))
		it.set_text(1, str(g.get("name", "Guest")) + ("  (asleep)" if st == "sleep" else ""))
		it.set_text(2, _kind(str(g.get("archetype", ""))))
		it.set_text(3, str(rooms.get(id, "")))
		it.set_text(4, str(g.get("remaining_label", "")))
		# What they are short of: the worst one's plate (as over their head in the camp)
		# and the words for all they would go and look for.
		var needs: Dictionary = snap.get("needs", {}) if snap.get("needs", {}) is Dictionary else {}
		var worst: Array = _worst_need(needs)
		if str(worst[0]) != "" and float(worst[1]) < NEEDS.SEEK_THRESHOLD:
			it.set_icon(5, _need_icon(str(worst[0])))
			it.set_icon_max_width(5, 14)
			it.set_text(5, _short_of(needs))
			it.set_custom_color(5, RED if float(worst[1]) < 30.0 else AMBER)
		_stripe(it, shown, 6)
		var info := snap.duplicate()
		info["room"] = rooms.get(id, "")
		info["coord"] = _room_coord_of(g)
		info["leaves"] = str(g.get("remaining_label", ""))
		_guest_rows[it.get_instance_id()] = info
		if id == keep_id:
			reselect = it
		shown += 1
	# One row more than there are guests. Nobody booked it.
	if shown > 0 and day >= 2 and day % 3 == 2 and hour >= UNBOOKED_FROM_HOUR and hour < UNBOOKED_TO_HOUR:
		var it := _guests.create_item(root)
		it.set_icon(0, _face_icon(-1.0))
		for c in range(1, 5):
			it.set_text(c, "-")
		_stripe(it, shown, 6)
	if reselect != null:
		reselect.select(0)
	elif shown == 0:
		_card_guest = {}
	_card.queue_redraw()
	_map_btn.visible = _card_guest.get("coord", null) is Vector2i
	_empty_guests.visible = shown == 0
	_empty_guests.text = "Nobody is staying in the camp.\nAccept a booking in CampMail; check the guests in at the desk."
	var by: String = ["mood", "name", "kind", "room", "departure", "needs"][clampi(_sort_col, 0, 5)]
	_status.text = "%d record(s). Sorted by %s. Pick one for the card; double-click for the map." % [shown, by] if shown > 0 else "Nobody is staying in the camp."


const NEED_WORDS := {"hunger": "Food", "thirst": "Drink", "bladder": "WC", "hygiene": "Wash", "fun": "Fun", "energy": "Sleep"}


## The need a guest is shortest of that they would go and see to: [need, value] (["", 100]
## when none).
func _worst_need(needs: Dictionary) -> Array:
	var worst := ""
	var v := 100.0
	for k in NEEDS.SEEKABLE_NEEDS:
		var x := float(needs.get(k, 100.0))
		if x < v:
			v = x
			worst = k
	return [worst, v]


## The words for every need they are short of, the worst first ("Drink, Fun").
func _short_of(needs: Dictionary) -> String:
	var rows: Array = []
	for k in NEEDS.SEEKABLE_NEEDS:
		if float(needs.get(k, 100.0)) < NEEDS.SEEK_THRESHOLD:
			rows.append([float(needs[k]), str(NEED_WORDS.get(k, k))])
	rows.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
	return ", ".join(rows.map(func(r) -> String: return str(r[1])))


var _need_icons: Dictionary = {}


## The plate over a guest's head for `need` (npc/need_<need>.png).
func _need_icon(need: String) -> Texture2D:
	if not _need_icons.has(need):
		var p := "res://assets/textury/npc/need_%s.png" % need
		_need_icons[need] = load(p) if ResourceLoader.exists(p) else null
	return _need_icons[need]


func _on_guest_selected() -> void:
	var it := _guests.get_selected()
	_card_guest = _guest_rows.get(it.get_instance_id(), {}) if it != null else {}
	_map_btn.visible = _card_guest.get("coord", null) is Vector2i
	_card.queue_redraw()


func _fill_arrivals(rows: Array) -> void:
	_arrivals.clear()
	var root := _arrivals.create_item()
	var i := 0
	for r_any in rows:
		var r: Dictionary = r_any
		var it := _arrivals.create_item(root)
		var at_gate := bool(r.get("at_gate", false))
		var mins := int(r.get("minutes", 0))
		it.set_icon(0, _dot_icon(RED if at_gate else Color8(80, 110, 200)))
		it.set_text(1, str(r.get("name", "Guest")))
		it.set_text(2, str(int(r.get("party_size", 1))))
		if at_gate:
			it.set_text(3, "AT RECEPTION %d:%02d" % [mins / 60, mins % 60])
			it.set_custom_color(3, RED)
		else:
			it.set_text(3, "on the road, %d:%02d" % [mins / 60, mins % 60])
		var labels: Array = []
		var todo: Array = []
		var ready := true
		for room in r.get("rooms", []):
			labels.append(str(room.get("label", "")))
			var ok := bool(room.get("ready", false))
			ready = ready and ok
			if it.get_metadata(0) == null:
				var kp := str(room.get("key", "")).split(":")
				if kp.size() == 2 and kp[0].is_valid_int() and kp[1].is_valid_int():
					it.set_metadata(0, Vector2i(int(kp[0]), int(kp[1])))
			if not ok:
				# What is still to do in it, as the room's own list has it.
				for t in GuestManager.get_room_state(str(room.get("key", ""))).get("remaining", []):
					todo.append(str(t.get("label", t.get("id", ""))))
		it.set_text(4, ", ".join(labels))
		it.set_text(5, "yes" if ready else "NO")
		it.set_custom_color(5, GREEN if ready else RED)
		it.set_text(6, ", ".join(todo) if not todo.is_empty() else ("-" if ready else "make it up"))
		if not todo.is_empty():
			it.set_custom_color(6, AMBER)
		_stripe(it, i, 7)
		i += 1
	_empty_arrivals.visible = rows.is_empty()
	_empty_arrivals.text = "Nobody is on the way.\nAccepted bookings show here until the guests are checked in."
	_status.text = "Nobody is on the way." if rows.is_empty() else "Make up the room, then check them in at the desk. Double-click for the map."


func _fill_rooms() -> void:
	_rooms.clear()
	var root := _rooms.create_item()
	var states: Dictionary = GuestManager.get_accommodation_states()
	var keys := states.keys()
	keys.sort()
	var to_do := 0
	var i := 0
	for key in keys:
		var rs: Dictionary = GuestManager.get_room_state(str(key))
		if rs.is_empty():
			continue
		var it := _rooms.create_item(root)
		var kp := str(key).split(":")
		if kp.size() == 2 and kp[0].is_valid_int() and kp[1].is_valid_int():
			it.set_metadata(0, Vector2i(int(kp[0]), int(kp[1])))
		var st := str(rs.get("status", ""))
		var occupied := bool(rs.get("occupied", false))
		var col := GREEN if st == "ready" else (AMBER if st == "unprepared" else RED)
		if occupied:
			col = Color8(80, 110, 200)
		it.set_icon(0, _dot_icon(col))
		it.set_text(1, str(rs.get("label", key)))
		it.set_text(2, "occupied" if occupied else {"ready": "ready", "dirty": "DIRTY", "unprepared": "not made up"}.get(st, st))
		it.set_custom_color(2, col)
		if st != "ready":
			to_do += 1
		var names: Array = []
		for t in rs.get("remaining", []):
			names.append(str(t.get("label", t.get("id", ""))))
		it.set_text(3, ", ".join(names))
		it.set_tooltip_text(3, ", ".join(names))
		_stripe(it, i, 4)
		i += 1
	var sel = _plan.focus if _plan != null else Vector2i(-1, -1)
	_select_room(sel)
	if sel.x >= 0 and _rooms.get_selected() == null:
		(func(): _tell(_plan.focus)).call_deferred()
	elif sel.x < 0:
		_status.text = "%d room(s), %d to make up." % [keys.size(), to_do]


func _stripe(it: TreeItem, i: int, cols: int) -> void:
	if i % 2 == 1:
		for c in cols:
			it.set_custom_bg_color(c, ROW_B)


# ── drawing ──────────────────────────────────────────────────────────────────

func _draw_banner() -> void:
	var s := _banner.size
	for x in int(ceil(s.x / 8.0)):
		var k := float(x * 8) / maxf(1.0, s.x)
		_banner.draw_rect(Rect2(x * 8, 0, 8, s.y), Color8(0, 64, 0).lerp(Color8(70, 140, 70), k))
	# The district crest: a shield with a pine and a wavy line of water.
	var o := Vector2(8, 3)
	var shield := PackedVector2Array([o, o + Vector2(24, 0), o + Vector2(24, 16), o + Vector2(12, 28), o + Vector2(0, 16)])
	_banner.draw_colored_polygon(shield, Color8(200, 30, 30))
	var outline := shield.duplicate()
	outline.append(o)
	_banner.draw_polyline(outline, T.WHITE, 1.0)
	_banner.draw_colored_polygon(PackedVector2Array([o + Vector2(12, 3), o + Vector2(19, 15), o + Vector2(5, 15)]), Color8(255, 220, 60))
	_banner.draw_rect(Rect2(o + Vector2(11, 15), Vector2(2, 4)), Color8(255, 220, 60))
	for k in 3:
		_banner.draw_rect(Rect2(o + Vector2(5 + k * 5, 21 + (k % 2)), Vector2(4, 1)), T.WHITE)
	_banner.draw_string(T.FONT_BOLD, Vector2(40, 15), "GuestRack 98", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)
	_banner.draw_string(T.FONT, Vector2(40, 28), "District Office Hlubocany - register of persons staying overnight", HORIZONTAL_ALIGNMENT_LEFT, s.x - 140, T.FONT_SIZE, Color8(210, 240, 210))
	var clock := str(_banner.get_meta("clock", ""))
	var w := T.FONT_BOLD.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	_banner.draw_string(T.FONT_BOLD, Vector2(s.x - w - 8, 15), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE)


func _draw_counters() -> void:
	var labels := ["Beds taken", "In the camp", "On the way", "Rooms to make up"]
	var cols := [T.TEXT, Color8(0, 0, 160), Color8(0, 0, 160), RED]
	var n := labels.size()
	var w := (_counters.size.x - (n - 1) * 4) / n
	for i in n:
		var r := Rect2(i * (w + 4), 0, w, _counters.size.y)
		_counters.draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
		_counters.draw_string(T.FONT, r.position + Vector2(6, 14), labels[i], HORIZONTAL_ALIGNMENT_LEFT, w - 8, T.FONT_SIZE, T.SHADOW)
		var v := str(_counter_values[i])
		var col: Color = cols[i]
		if i == 3 and v == "0":
			col = GREEN
		_counters.draw_string(T.FONT_BOLD, r.position + Vector2(6, 34), v, HORIZONTAL_ALIGNMENT_LEFT, w - 8, T.FONT_SIZE * 2, col)
		# A little picture of what is counted, at the right of its box.
		_pix(_counters, COUNTER_PIX[i], Vector2(r.end.x - 30, r.position.y + 12), 2)


## The counters' pictures: a bed, people, a car, a broom (12x10, drawn at 2x).
const COUNTER_PIX := [
	["............", "K...........", "K.wwwKKKKKK.", "KwwwwKbbbbbK", "KKKKKKKKKKKK", "KbbbbbbbbbbK", "KKKKKKKKKKKK", "K..........K", "K..........K", "............"],
	["...KK...KK..", "..KssK.KssK.", "..KssK.KssK.", "...KK...KK..", "..KbbK.KrrK.", ".KbbbbKrrrrK", ".KbbbbKrrrrK", ".KbbbbKrrrrK", "..K..K.K..K.", "..K..K.K..K."],
	["............", "...KKKKK....", "..KwwKwwK...", ".KwwwKwwwK..", "KrrrrrrrrrrK", "KrrrrrrrrrrK", "KKKKKKKKKKKK", ".KK.....KK..", ".KK.....KK..", "............"],
	["........KK..", ".......KK...", "......KK....", ".....KK.....", "....KK......", "..KyyyK.....", ".KyyyyyK....", "KyyyyyyyK...", "KyKyKyKyK...", "............"],
]
const PIX_COL := {"K": Color8(30, 30, 30), "w": Color8(240, 240, 240), "b": Color8(70, 110, 200), "r": Color8(200, 60, 40), "s": Color8(232, 184, 140), "y": Color8(220, 180, 60)}


func _pix(c: Control, rows: Array, at: Vector2, k: int) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if PIX_COL.has(row[x]):
				c.draw_rect(Rect2(at + Vector2(x * k, y * k), Vector2(k, k)), PIX_COL[row[x]])


## The record card of the picked guest: mood face, needs as bars, room, words.
func _draw_card() -> void:
	var s := _card.size
	_card.draw_style_box(T.box("field", Color8(255, 255, 238), Vector4.ZERO), Rect2(Vector2.ZERO, s))
	if _card_guest.is_empty():
		_card.draw_string(T.FONT, Vector2(8, 20), "Pick a guest.", HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, T.SHADOW)
		return
	var g := _card_guest
	var mood := float(g.get("mood", 60.0))
	_card.draw_texture_rect(_face_icon(mood, 32), Rect2(8, 8, 32, 32), false)
	_card.draw_string(T.FONT_BOLD, Vector2(46, 20), str(g.get("name", "Guest")), HORIZONTAL_ALIGNMENT_LEFT, s.x - 52, T.FONT_SIZE, T.TEXT)
	_card.draw_string(T.FONT, Vector2(46, 34), "%s, %s" % [_kind(str(g.get("archetype", ""))), str(g.get("mood_label", "")).to_lower()], HORIZONTAL_ALIGNMENT_LEFT, s.x - 52, T.FONT_SIZE, T.SHADOW)
	var y := 52.0
	_card.draw_string(T.FONT, Vector2(8, y), "Room: %s" % str(g.get("room", "-")), HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, T.TEXT)
	y += 14
	_card.draw_string(T.FONT, Vector2(8, y), "Leaves in: %s" % str(g.get("leaves", "-")), HORIZONTAL_ALIGNMENT_LEFT, s.x - 16, T.FONT_SIZE, T.TEXT)
	y += 10
	var needs: Dictionary = g.get("needs", {})
	for k in NEEDS.NEEDS:
		y += 14
		var v := clampf(float(needs.get(k, 50.0)) / 100.0, 0.0, 1.0)
		_card.draw_string(T.FONT, Vector2(8, y), str(NEEDS.NEED_LABELS.get(k, k)), HORIZONTAL_ALIGNMENT_LEFT, 64, T.FONT_SIZE, T.TEXT)
		var bar := Rect2(74, y - 9, s.x - 84, 9)
		_card.draw_rect(bar, Color8(220, 220, 220))
		_card.draw_rect(Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)), GREEN if v > 0.55 else (AMBER if v > 0.3 else RED))
		_card.draw_rect(bar, T.SHADOW, false, 1.0)
	var thought := str(g.get("thought", "")).strip_edges()
	if not thought.is_empty() and int(g.get("thought_age", 9999)) < 240:
		y += 22
		var lines := _wrap("\"%s\"" % thought, s.x - 16)
		for l in lines.slice(0, 5):
			_card.draw_string(T.FONT, Vector2(8, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(60, 60, 120))
			y += 13


func _wrap(text: String, width: float) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var cand := word if line.is_empty() else line + " " + word
		if T.FONT.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x > width and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = cand
	if not line.is_empty():
		out.append(line)
	return out


var _icons: Dictionary = {}


## A small smiley by mood (green / yellow / red); mood < 0 is the grey one nobody booked.
func _face_icon(mood: float, px := 16) -> Texture2D:
	var tier := 3 if mood < 0.0 else (0 if mood >= 65.0 else (1 if mood >= 40.0 else 2))
	var key := "face%d_%d" % [tier, px]
	if _icons.has(key):
		return _icons[key]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill: Color = [Color8(90, 200, 60), Color8(250, 210, 40), Color8(230, 60, 40), Color8(140, 140, 140)][tier]
	var c := Vector2(px, px) * 0.5 - Vector2(0.5, 0.5)
	var r := px * 0.5 - 1.0
	var k := px / 16.0
	for y in px:
		for x in px:
			var d := Vector2(x, y).distance_to(c)
			if d <= r:
				img.set_pixel(x, y, Color8(20, 20, 20) if d > r - k else fill)
	var ink := Color8(20, 20, 20)
	for e in [Vector2(5, 5), Vector2(10, 5)]:
		img.fill_rect(Rect2i(int(e.x * k), int(e.y * k), maxi(1, int(k)), maxi(1, int(2 * k))), ink)
	for x in range(5, 11):
		var yy: int
		match tier:
			0: yy = 10 + int(abs(x - 7.5) < 2.0)
			1: yy = 10
			2: yy = 11 - int(abs(x - 7.5) < 2.0)
			_: yy = 10
		img.fill_rect(Rect2i(int(x * k), int(yy * k), maxi(1, int(k)), maxi(1, int(k))), ink)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


func _dot_icon(col: Color) -> Texture2D:
	var key := "dot" + col.to_html()
	if _icons.has(key):
		return _icons[key]
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(2, 2, 8, 8), Color8(20, 20, 20))
	img.fill_rect(Rect2i(3, 3, 6, 6), col)
	img.fill_rect(Rect2i(3, 3, 2, 2), col.lightened(0.5))
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


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


## Where a guest sleeps, as a map cell (the first of their rooms), or null.
func _room_coord_of(g: Dictionary) -> Variant:
	var slots: Array = g.get("lodging_slots", []) if g.get("lodging_slots", []) is Array else []
	for s in slots:
		if s is Dictionary:
			var kp := str(s.get("accommodation_key", "")).split(":")
			if kp.size() == 2 and kp[0].is_valid_int() and kp[1].is_valid_int():
				return Vector2i(int(kp[0]), int(kp[1]))
	return null


## Shown with someone at the desk: the Arrivals list first (that is why you came).
func shown() -> void:
	if _tabs == null or GuestManager == null:
		return
	for r in GuestManager.get_arrivals():
		if r is Dictionary and bool(r.get("at_gate", false)):
			_tabs.current_tab = 1
			break
	refresh()


func _kind(raw: String) -> String:
	var k := raw.strip_edges().to_lower()
	if ARCHETYPES.has(k):
		return ARCHETYPES[k]
	return k.replace("_", " ").capitalize() if not k.is_empty() else "-"
