extends Control

## Boss 98 (Sef 98 in Czech), tab 7 of the camp computer (the user 8. 11.: "completely redo the
## program on the seven, the bowling alley is missing, it is unreadable through those tabs
## along the top, do it all from scratch, just a manager's program"). It takes the place of
## SoftSklad's five programs: one window, the boss's desk down the left, nothing along the top.
##
## The desk: four pages (Overview, The order, People, Accounts) and under them a key for every
## place in the camp with its lamp and what it has made today. One click anywhere gets to
## anything; nothing scrolls (long lists turn over in pages).
##   Overview    the money of the day, the places in rows, what wants you, the week
##   The order   the goods of every place on one sheet, what runs out first at the top;
##               Fill up for all of them, one van, Send
##   People      everybody, their card (where they work, the post, the shift, let go), and
##               who is asking today
##   Accounts    every place side by side: today, yesterday, seven days, all told
##   a place     its goods with the order on them (or its menu, or its gear), its day against
##               yesterday, the hands on it, the hours
##   Staffroom   what the camp's hands did today, the lockers, the armchair
## One licence, bought here or on softsklad.cz (biz.licences "boss"; any of the five old ones
## counts). The frame's leather and the armchair are Grok's (tools/artgen/boss_art.py), the
## tables the system's own chrome. The same books as on the places' counters
## (scripts/business/ledger_closeup.gd) and in the staffroom (scripts/staff/staff_ledger.gd).

const T = preload("res://scripts/os98/os_theme.gd")
const LANG = preload("res://scripts/lang.gd")
const RULES := preload("res://core/systems/business_rules.gd")
const STAFF := preload("res://core/systems/staff_rules.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const LEDGER := preload("res://scripts/staff/staff_ledger.gd")

const PROGRAM := "boss_app"
const SIDE_W := 126.0
const TOP_H := 36.0
const STATUS_H := 20.0
const ROW_H := 18.0
const SHEET_ROW := 16.0
const LEATHER := "res://assets/textury/os98/boss_leather.png"
const ICONS := "res://assets/textury/os98/icons/"
const PHOTOS := "res://assets/textury/os98/photos/"
const CARDS := "res://assets/textury/closeup/parts/"
const BOARD := Color8(24, 44, 36)
const GOLD := Color8(226, 192, 110)
const GOLD_DIM := Color8(156, 134, 84)
const IVORY := Color8(236, 230, 212)
const RED := Color8(176, 0, 0)
const GREEN := Color8(0, 112, 0)
const AMBER := Color8(176, 116, 0)
const BAR_A := T.NAVY
const BAR_B := Color8(220, 160, 20)
const LCD_BG := Color8(8, 24, 12)
const LCD_ON := Color8(80, 255, 120)
const LCD_DIM := Color8(40, 128, 64)
const LCD_RED := Color8(255, 90, 70)
const ON_LEATHER_UP := Color8(150, 226, 150)
const ON_LEATHER_DOWN := Color8(255, 150, 130)
const LAMPS := {-1: Color8(96, 104, 98), 0: Color8(70, 214, 92), 1: Color8(236, 170, 40), 2: Color8(240, 56, 40)}
const KINDS_SHOWN := ["pub", "rest", "vecerka", "corn", "bowl"]
const PLACE_COL := {"pub": Color8(120, 60, 20), "rest": Color8(150, 40, 30), "vecerka": Color8(30, 90, 50), "corn": Color8(150, 110, 0), "bowl": Color8(36, 70, 140), "staff": Color8(70, 54, 30)}
const PLACE_PIC := {"pub": "hospoda1.PNG", "rest": "restaurace.PNG", "vecerka": "iso_jednota.png", "corn": "iso_corn_stand.png", "bowl": "iso_bowling.png", "staff": "iso_staffroom.png"}
const NAV := [["overview", "Overview", "campstat_16"], ["order", "The order", "tb_order"], ["people", "People", "tb_staff"], ["books", "Accounts", "tb_books"]]
const OLD_PROGRAMS := {"pub_app": "pub", "bistro_app": "rest", "shop_app": "vecerka", "corn_app": "corn"}
const PERIODS := [["today", "Today"], ["yesterday", "Yesterday"], ["week", "7 days"], ["all", "All told"]]

var _shell
var _win
var _nav := "overview"
var _place := ""
var _sub := "goods"              # a place's left half: goods, menu, gear
var _who := "crew"               # People: crew, hire
var _pick := ""
var _candidate := 0
var _period := "week"
var _order: Dictionary = {}      # site key -> {good: packs}
var _sheet: Array = []           # The order's rows as they stood when it was opened
var _sheet_page := 0
var _people_page := 0
var _hits: Array = []            # [[id, Rect2]], rebuilt each draw
var _hover := ""
var _down := ""
var _notice := ""
var _notice_col := T.TEXT
var _tick := 0.0
var _tex: Dictionary = {}


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_exited.connect(func():
		_hover = ""
		queue_redraw())
	_open(args)
	refresh()


func reopen(args: Dictionary) -> void:
	_open(args)
	refresh()


func refresh() -> void:
	queue_redraw()


func shown() -> void:
	refresh()


func install_tick() -> void:
	queue_redraw()


func program_installed(_id: String) -> void:
	refresh()


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 1.0:
		_tick = 0.0
		if is_visible_in_tree():
			queue_redraw()


## Where another program sends you: Hire and Order out of CampStat, the old programs' names.
func _open(args: Dictionary) -> void:
	var prog := str(args.get("program", ""))
	match prog:
		"boss_order":
			_show_order()
		"boss_hire":
			_nav = "people"
			_who = "hire"
		"staff_app":
			_nav = "people"
			_who = "crew"
		_:
			if OLD_PROGRAMS.has(prog):
				for key in _biz_places():
					if _kind_of(str(key)) == str(OLD_PROGRAMS[prog]):
						_nav = "place"
						_place = str(key)
						_sub = "goods"
						break


## The number on the taskbar: the places on fire.
func badge() -> Array:
	if CoreRoot == null or not _shell._is_program_unlocked(PROGRAM):
		return []
	var n := 0
	for key in _biz_places():
		if _level(str(key)) == 2:
			n += 1
	return [str(n), Color8(200, 0, 0)] if n > 0 else []


# ── who and what there is ────────────────────────────────────────────────────

func _biz() -> Dictionary:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	return state.biz if state != null and state.biz is Dictionary else {}


func _st() -> Dictionary:
	return CoreRoot.actions.staff_state() if CoreRoot != null and CoreRoot.actions != null else {}


func _crew() -> Array:
	return _st().get("crew", [])


func _has_room() -> bool:
	var tree := get_tree()
	return tree != null and not tree.get_nodes_in_group("staffroom").is_empty()


## The businesses standing in the camp: their keys, by kind.
func _biz_places() -> Array:
	var out: Array = []
	if CoreRoot == null or CoreRoot.get_state() == null:
		return out
	var state = CoreRoot.get_state()
	var sites: Dictionary = state.biz.get("sites", {})
	var keys := sites.keys()
	keys.sort()
	for kind in KINDS_SHOWN:
		for k in keys:
			if str((sites[k] as Dictionary).get("kind", "")) != kind:
				continue
			var p := str(k).split(":")
			if p.size() != 2:
				continue
			var cell: Dictionary = state.grid.cells.get(Vector2i(int(p[0]), int(p[1])), {})
			if RULES.is_business(str(cell.get("type", ""))):
				out.append(str(k))
	return out


## Those and the staffroom ("staff") when there is one.
func _places() -> Array:
	var out := _biz_places()
	if _has_room():
		out.append("staff")
	return out


func _kind_of(place: String) -> String:
	return "staff" if place == "staff" else str(BUSINESS.site(place).get("kind", ""))


func _name_of(kind: String, short: bool) -> String:
	if kind == "staff":
		return tr("Staffroom")
	if kind == "corn" and short:
		return tr("Corn")
	return tr(str(RULES.info(kind).get("name", "")))


func _label(place: String, short := false) -> String:
	var kind := _kind_of(place)
	var name := _name_of(kind, short)
	var same: Array = _places().filter(func(k): return _kind_of(str(k)) == kind)
	return name if same.size() <= 1 else "%s %d" % [name, same.find(place) + 1]


func _short(place: String) -> String:
	return _label(place, true)


## Everybody: [{p, at}], the businesses' first, the staffroom's after.
func _everyone() -> Array:
	var out: Array = []
	for place in _biz_places():
		for p in BUSINESS.site(str(place)).get("crew", []):
			out.append({"p": p, "at": str(place)})
	for p in _crew():
		out.append({"p": p, "at": "staff"})
	return out


func _entry(slug: String) -> Dictionary:
	for e in _everyone():
		if str((e["p"] as Dictionary).get("slug", "")) == slug:
			return e
	return {}


func _taken() -> Array:
	var out: Array = []
	for e in _everyone():
		out.append(str((e["p"] as Dictionary).get("slug", "")))
	# (Somebody's whose place was pulled down is still on its books.)
	var sites: Dictionary = _biz().get("sites", {})
	for k in sites:
		for p in (sites[k] as Dictionary).get("crew", []):
			if not out.has(str(p.get("slug", ""))):
				out.append(str(p.get("slug", "")))
	return out


## Who is asking today: anybody not working in the camp, five a day (the same on every machine).
func _applicants() -> Array:
	return RULES.applicants("camp", "camp", CoreRoot.get_day(), _taken(), BUSINESS.camp_seed())


## The businesses anybody; the staffroom (its brooms, its lounge) those who ask for it.
func _would(slug: String, place: String) -> bool:
	if place != "staff":
		return true
	return (RULES.PEOPLE.get(slug, {}).get("asks", []) as Array).has("staff")


func _wage_at(slug: String, place: String) -> int:
	return int(RULES.person(slug, _kind_of(place), BUSINESS.camp_seed()).get("wage", 25))


func _status(e: Dictionary) -> String:
	var p: Dictionary = e["p"]
	var day: int = CoreRoot.get_day()
	if int(p.get("since", 0)) > day:
		return "From tomorrow"
	if int(p.get("absent", -1)) == day:
		return "Away today"
	if str(e["at"]) == "staff":
		return LEDGER.whereabouts(p, (_st().get("act", {}) as Dictionary).get(str(p.get("slug", "")), {}))
	for q in BUSINESS.crew_now(str(e["at"])):
		if str(q.get("slug", "")) == str(p.get("slug", "")):
			return "At work"
	return "Off"


func _waiting(key: String) -> int:
	var m: Node = _shell.main_node()
	var im = m.get("_interior_manager") if m != null else null
	var runtime = im.get("business") if im != null else null
	return int(runtime.waiting_at(key)) if runtime != null and runtime.has_method("waiting_at") else 0


## What a place runs out of first with nothing coming for it: {label, n, days}; {} when its
## shelves stand.
func _worst(key: String) -> Dictionary:
	var s := BUSINESS.site(key)
	var kind := str(s.get("kind", ""))
	var best := {}
	var best_u := INF
	for g in RULES.goods(kind):
		if not RULES.kept(kind, g) or not RULES.menu_on(kind, s, str(g)) or BUSINESS.on_order(key, str(g)) > 0:
			continue
		var n := int((s.get("stock", {}) as Dictionary).get(g, 0))
		var days := RULES.days_left(s, str(g))
		if not RULES.is_low(kind, str(g), n) and (days < 0 or days > 2):
			continue
		var u := -1.0 if n <= 0 else (float(days) if days >= 0 else 5.0)
		if u < best_u:
			best_u = u
			best = {"label": tr(str(RULES.goods(kind)[g]["label"])), "n": n, "days": days}
	return best


func _low_count() -> int:
	var n := 0
	for key in _biz_places():
		var s := BUSINESS.site(str(key))
		var kind := str(s.get("kind", ""))
		for g in RULES.goods(kind):
			if RULES.kept(kind, g) and RULES.menu_on(kind, s, str(g)) and BUSINESS.on_order(str(key), str(g)) <= 0 and RULES.is_low(kind, str(g), int((s.get("stock", {}) as Dictionary).get(g, 0))):
				n += 1
	return n


## How a place stands, its lamp: -1 shut, 0 running, 1 wants a look, 2 on fire.
func _level(key: String) -> int:
	if key == "staff":
		return 0 if not _crew().is_empty() else -1
	var s := BUSINESS.site(key)
	var w := _worst(key)
	var gone := not w.is_empty() and int(w["n"]) <= 0
	if BUSINESS.shift_now(s) == "closed":
		return 1 if gone else -1
	var on_now := BUSINESS.crew_now(key)
	if gone or (_waiting(key) > 0 and on_now.is_empty()):
		return 2
	if not w.is_empty() or on_now.is_empty():
		return 1
	return 0


## A place that has made a loss three closed days running.
func _losing(s: Dictionary) -> bool:
	var h: Array = (s.get("history", []) as Array).slice(-3)
	if h.size() < 3:
		return false
	for d in h:
		if int(RULES.day_money(d)["profit"]) >= 0:
			return false
	return true


## What wants you, the worst first: [text, lamp, where a click goes].
func _wants() -> Array:
	var out: Array = []
	for place in _biz_places():
		var key := str(place)
		var s := BUSINESS.site(key)
		var name := _short(key)
		var wait := _waiting(key)
		if wait > 0 and BUSINESS.crew_now(key).is_empty():
			out.append([LANG.f("%s: %d waiting, nobody there", [name, wait]), 2, "place:" + key])
		var w := _worst(key)
		if not w.is_empty() and not RULES.orders_itself(s):
			if int(w["n"]) <= 0:
				out.append([LANG.f("%s: %s, none left", [name, str(w["label"])]), 2, "nav:order"])
			else:
				out.append([LANG.f("%s: %s running out", [name, str(w["label"])]), 1, "nav:order"])
		if _losing(s):
			out.append([LANG.f("%s: a loss three days running", name), 1, "nav:books"])
	var day: int = CoreRoot.get_day()
	for e in _everyone():
		var p: Dictionary = e["p"]
		var who := tr(str(p.get("name", "")))
		if int(p.get("owed", 0)) > 0:
			out.append([LANG.f("%s is owed $%d", [who, int(p["owed"])]), 2, "crew:" + str(p.get("slug", ""))])
		elif int(p.get("absent", -1)) == day:
			out.append([LANG.f("%s is away today", who), 1, "crew:" + str(p.get("slug", ""))])
	out.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	return out


# ── doing ────────────────────────────────────────────────────────────────────

func _room(key: String, g: String) -> int:
	var s := BUSINESS.site(key)
	var kind := str(s.get("kind", ""))
	var d: Dictionary = RULES.goods(kind).get(g, {})
	return maxi(0, (RULES.cap_of(kind, g, s) - int(s["stock"].get(g, 0)) - BUSINESS.on_order(key, g)) / maxi(1, int(d.get("pack", 1))))


func _order_goods() -> int:
	var total := 0
	for key in _order:
		total += RULES.goods_cost(_kind_of(str(key)), _order[key])
	return total


func _van_fee() -> int:
	return CoreRoot.actions.van_fee(BUSINESS.van_day())


func _order_total() -> int:
	var goods := _order_goods()
	return goods + (_van_fee() if goods > 0 else 0)


func _bump(key: String, g: String, by: int) -> void:
	var o: Dictionary = _order.get(key, {})
	var n := int(o.get(g, 0)) + by
	var room := _room(key, g)
	if n > room:
		_say(LANG.f("No room on the shelves for more %s.", tr(str(RULES.goods(_kind_of(key))[g]["label"])).to_lower()), RED)
		_shell.play("ding", -8.0)
		return
	n = clampi(n, 0, room)
	if n > 0:
		o[g] = n
	else:
		o.erase(g)
	if o.is_empty():
		_order.erase(key)
	else:
		_order[key] = o
	_shell.play("click", -12.0)


## Every place's shelves written in for a few days of what it goes through.
func _fill(only := "") -> void:
	for place in _biz_places():
		var key := str(place)
		if only != "" and key != only:
			continue
		var s := BUSINESS.site(key)
		var kind := str(s.get("kind", ""))
		var coming := {}
		for g in RULES.goods(kind):
			coming[g] = BUSINESS.on_order(key, str(g))
		var wanted: Dictionary = RULES.fill_order(kind, s, coming)
		if wanted.is_empty():
			_order.erase(key)
		else:
			_order[key] = wanted
	if _order.is_empty():
		_say(tr("The shelves are full."), GREEN)
	else:
		_say(LANG.f("Written in: $%d with the van.", _order_total()), GREEN)
	_shell.play("click", -12.0)


func _send() -> void:
	if _order_goods() <= 0:
		return
	var cost := _order_total()
	var van_day: int = BUSINESS.van_day()
	if not CoreRoot.actions.biz_order_all(_order, van_day):
		_shell.message_box(tr("Boss 98"), LANG.f("The order of $%d could not be sent.\n\nThe camp has $%d.", [cost, CoreRoot.get_money()]), "error")
		return
	_order.clear()
	_sheet = []
	_say(LANG.f("Order sent: $%d. It goes on today's van." if van_day <= CoreRoot.get_day() else "Order sent: $%d. The van comes tomorrow.", cost), GREEN)
	_shell.play("ding", -10.0)


func _show_order() -> void:
	_nav = "order"
	_sheet = []
	_sheet_page = 0


func _take_on(person: Dictionary, place: String) -> bool:
	var slug := str(person.get("slug", ""))
	var day: int = CoreRoot.get_day() + 1
	if place == "staff":
		if not STAFF.can_hire(_st()):
			_shell.message_box(tr("Boss 98"), tr("No locker is free. One locker, one hand."), "error")
			return false
		return CoreRoot.actions.staff_hire(RULES.person(slug, "staff", BUSINESS.camp_seed()), day)
	return CoreRoot.actions.biz_hire(place, RULES.person(slug, _kind_of(place), BUSINESS.camp_seed()), day)


## Somebody working here moved to `place` (at once: they are in the camp already).
func _move(slug: String, place: String) -> void:
	var e := _entry(slug)
	if e.is_empty() or str(e["at"]) == place:
		return
	if place == "staff" and not STAFF.can_hire(_st()):
		_shell.message_box(tr("Boss 98"), tr("No locker is free. One locker, one hand."), "error")
		return
	var p: Dictionary = e["p"]
	var since := int(p.get("since", CoreRoot.get_day()))
	var person := RULES.person(slug, _kind_of(place), BUSINESS.camp_seed())
	if str(e["at"]) == "staff":
		CoreRoot.actions.staff_fire(slug)
	else:
		CoreRoot.actions.biz_fire(str(e["at"]), slug)
	var ok: bool = CoreRoot.actions.staff_hire(person, since) if place == "staff" else CoreRoot.actions.biz_hire(place, person, since)
	if ok:
		_say(LANG.f("Moved: %s -> %s.", [tr(str(p.get("name", ""))), _label(place)]), GREEN)
		_shell.play("ding", -10.0)


func _buy_licence() -> void:
	_shell.play("click", -10.0)
	if CoreRoot.actions.biz_has_licence("boss"):
		_shell.install_program(PROGRAM, false)
		queue_redraw()
		return
	var price: int = RULES.licence_price("boss")
	_shell.message_box("SoftSklad", LANG.f("Buy a licence for %s for $%d?\n\nThe money is taken from the camp's account.", [tr("Boss 98"), price]), "question", ["Buy", "Cancel"], func(b: String):
		if b != "Buy" or not is_instance_valid(self):
			return
		if CoreRoot.actions.biz_buy_licence("boss"):
			_shell.play("ding", -8.0)
			_shell.install_program(PROGRAM, false)
			queue_redraw()
		else:
			_shell.message_box("SoftSklad", LANG.f("The payment was refused.\n\nThe camp has $%d.", CoreRoot.get_money()), "error")
	)


func _say(text: String, col: Color) -> void:
	_notice = text
	_notice_col = col
	queue_redraw()


# ── input ────────────────────────────────────────────────────────────────────

func _hit_at(p: Vector2) -> String:
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i][1] as Rect2).has_point(p):
			return str(_hits[i][0])
	return ""


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := _hit_at((e as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_down = _hit_at(mb.position)
		else:
			var h := _hit_at(mb.position)
			if h != "" and h == _down:
				_click(h)
			_down = ""
		queue_redraw()
		accept_event()


func _click(id: String) -> void:
	if id == "buy_licence":
		_buy_licence()
		return
	if id.begins_with("nav:"):
		var to := id.substr(4)
		if to == "order":
			_show_order()
		else:
			_nav = to
		_shell.play("click", -10.0)
		return
	if id.begins_with("place:"):
		_nav = "place"
		_place = id.substr(6)
		_sub = "goods"
		_shell.play("click", -10.0)
		return
	if id.begins_with("sub:"):
		_sub = id.substr(4)
		_shell.play("click", -12.0)
		return
	if id.begins_with("who:"):
		_who = id.substr(4)
		_shell.play("click", -12.0)
		return
	if id.begins_with("period:"):
		_period = id.substr(7)
		_shell.play("click", -12.0)
		return
	if id.begins_with("plus:") or id.begins_with("minus:"):
		var p := id.split(":")
		_bump("%s:%s" % [p[1], p[2]], p[3], 1 if p[0] == "plus" else -1)
		return
	if id.begins_with("crew:"):
		_pick = id.substr(5)
		_nav = "people"
		_who = "crew"
		return
	if id.begins_with("cand:"):
		_candidate = int(id.substr(5))
		return
	if id.begins_with("move:"):
		_move(_pick, id.substr(5))
		return
	if id.begins_with("take:"):
		var ap := _applicants()
		if ap.is_empty():
			return
		var p2: Dictionary = ap[_candidate % ap.size()]
		var where := id.substr(5)
		if _take_on(p2, where):
			_pick = str(p2["slug"])
			_who = "crew"
			_say(LANG.f("Taken on: %s, from tomorrow (%s).", [tr(str(p2["name"])), _label(where)]), GREEN)
			_shell.play("ding", -10.0)
		return
	if id.begins_with("job:"):
		var e := _entry(_pick)
		if e.is_empty() or str(e["at"]) != "staff":
			return
		CoreRoot.actions.staff_set_job(_pick, id.substr(4), not STAFF.does(e["p"], id.substr(4)))
		_shell.play("click", -12.0)
		return
	if id.begins_with("role:") or id == "late_shift":
		var e3 := _entry(_pick)
		if e3.is_empty() or str(e3["at"]) == "staff":
			return
		var p3: Dictionary = e3["p"]
		var shift3 := str(p3.get("shift", "day"))
		if id == "late_shift":
			shift3 = "late" if shift3 == "day" else "day"
		CoreRoot.actions.biz_set_job(str(e3["at"]), _pick, id.substr(5) if id != "late_shift" else str(p3.get("role", "")), shift3)
		_shell.play("click", -12.0)
		return
	if id.begins_with("menu:"):
		var kind := _kind_of(_place)
		var s := BUSINESS.site(_place)
		var item := id.substr(5)
		CoreRoot.actions.biz_set_menu(_place, item, not RULES.menu_on(kind, s, item))
		_shell.play("click", -12.0)
		return
	if id.begins_with("gear:"):
		_buy_gear(id.substr(5))
		return
	if id.begins_with("sgear:"):
		_buy_staff_gear(id.substr(6))
		return
	match id:
		"fill":
			_fill()
			_sheet = []
		"fill_here":
			_fill(_place)
		"clear":
			_order.clear()
			_shell.play("click", -12.0)
		"send":
			_send()
		"sheet_back":
			_sheet_page = maxi(0, _sheet_page - 1)
		"sheet_on":
			_sheet_page += 1
		"people_back":
			_people_page = maxi(0, _people_page - 1)
		"people_on":
			_people_page += 1
		"auto":
			CoreRoot.actions.biz_set_auto(_place, not bool(BUSINESS.site(_place).get("auto_order", true)))
			_shell.play("click", -12.0)
		"late":
			CoreRoot.actions.biz_set_late(_place, not bool(BUSINESS.site(_place).get("late", false)))
			_shell.play("click", -12.0)
		"hire_here":
			_nav = "people"
			_who = "hire"
			_shell.play("click", -10.0)
		"fire":
			_fire()


func _fire() -> void:
	var e := _entry(_pick)
	if e.is_empty():
		return
	var slug := _pick
	var name := tr(str((e["p"] as Dictionary).get("name", "")))
	var at := str(e["at"])
	_shell.message_box(tr("Boss 98"), LANG.f("Let %s go?", name), "question", [tr("Yes"), tr("No")], func(b: String):
		if b == tr("Yes"):
			if at == "staff":
				CoreRoot.actions.staff_fire(slug)
			else:
				CoreRoot.actions.biz_fire(at, slug)
			_pick = ""
			_say(LANG.f("%s has been let go.", name), T.TEXT_DISABLED)
			queue_redraw())


func _buy_gear(gid: String) -> void:
	var kind := _kind_of(_place)
	var gd: Dictionary = RULES.gear_list(kind).get(gid, {})
	var key := _place
	_shell.message_box(tr("Boss 98"), LANG.f("Buy %s for $%d?", [tr(str(gd.get("label", ""))), int(gd.get("price", 0))]), "question", [tr("Yes"), tr("No")], func(b: String):
		if b != tr("Yes"):
			return
		if CoreRoot.actions.biz_buy_gear(key, gid):
			_say(LANG.f("%s bought.", tr(str(gd.get("label", "")))), GREEN)
			_shell.play("ding", -10.0)
		else:
			_shell.message_box(tr("Boss 98"), LANG.f("The purchase of $%d could not be made.\n\nThe camp has $%d.", [int(gd.get("price", 0)), CoreRoot.get_money()]), "error")
		queue_redraw())


func _buy_staff_gear(gid: String) -> void:
	var price := STAFF.gear_price(_st(), gid)
	var label := tr(str(STAFF.GEAR[gid]["label"]))
	_shell.message_box(tr("Boss 98"), LANG.f("Buy a %s for $%d?", [label.to_lower(), price]), "question", [tr("Yes"), tr("No")], func(b: String):
		if b != tr("Yes"):
			return
		if CoreRoot.actions.staff_buy_gear(gid):
			_say(LANG.f("%s bought: it is in the staffroom.", label), GREEN)
			_shell.play("ding", -10.0)
		else:
			_shell.message_box(tr("Boss 98"), LANG.f("The purchase of $%d could not be made.\n\nThe camp has $%d.", [price, CoreRoot.get_money()]), "error")
		queue_redraw())


# ── drawing helpers ──────────────────────────────────────────────────────────

func _hit(id: String, r: Rect2) -> void:
	_hits.append([id, r])


func _w(s: String, bold := false) -> float:
	return (T.FONT_BOLD if bold else T.FONT).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x


func _t(p: Vector2, s: String, col := T.TEXT, bold := false) -> void:
	draw_string(T.FONT_BOLD if bold else T.FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)


func _tr(x: float, y: float, s: String, col := T.TEXT, bold := false) -> void:
	_t(Vector2(x - _w(s, bold), y), s, col, bold)


func _tc(r: Rect2, s: String, col := T.TEXT, bold := false) -> void:
	_t(Vector2(r.get_center().x - _w(s, bold) * 0.5, r.position.y + r.size.y * 0.5 + 4), s, col, bold)


func _clip(s: String, room: float, bold := false) -> String:
	var out := s
	while out.length() > 4 and _w(out, bold) > room:
		out = out.substr(0, out.length() - 4) + "..."
	return out


func _amount(v: int) -> String:
	return LANG.money("$" + _shell._group(absi(v))).replace("$", "").replace(" Kč", "")


func _num(v: int) -> String:
	return "-" if v == 0 else ("-" if v < 0 else "") + _amount(v)


func _signed(v: int) -> String:
	return "-" if v == 0 else ("+" if v > 0 else "-") + _amount(v)


func _money(v: int) -> String:
	return ("-" if v < 0 else "") + LANG.money("$" + _shell._group(absi(v)))


func _signed_money(v: int) -> String:
	return ("+" if v > 0 else "") + _money(v)


func _button(r: Rect2, label: String, id: String, enabled := true) -> void:
	var pushed := enabled and _down == id and _hover == id
	draw_style_box(T.box("pressed" if pushed else "raised", T.FACE, Vector4.ZERO), r)
	var off := Vector2(1, 1) if pushed else Vector2.ZERO
	if enabled:
		_tc(Rect2(r.position + off, r.size), label)
		_hit(id, r)
	else:
		_tc(Rect2(r.position + Vector2(1, 1), r.size), label, T.WHITE)
		_tc(r, label, T.SHADOW)


## One of a row of buttons of which one is down.
func _switch(r: Rect2, label: String, id: String, on: bool) -> void:
	draw_style_box(T.box("pressed" if on else "raised", T.LIGHT if on else T.FACE, Vector4.ZERO), r)
	_tc(Rect2(r.position + (Vector2(1, 1) if on else Vector2.ZERO), r.size), label, T.TEXT, on)
	_hit(id, r)


func _header(r: Rect2, label: String, right := false) -> void:
	draw_style_box(T.box("thin_raised", T.FACE, Vector4.ZERO), r)
	if right:
		_tr(r.end.x - 5, r.position.y + 13, _clip(label, r.size.x - 8.0))
	else:
		_t(r.position + Vector2(5, 13), _clip(label, r.size.x - 8.0))


## The list view: a white well with its column headers.
func _list(m: Rect2, cols: Array) -> void:
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), m)
	var x := m.position.x + 2
	for c in cols:
		_header(Rect2(x, m.position.y + 2, float(c[1]), 18), tr(str(c[0])), bool(c[2]) if c.size() > 2 else false)
		x += float(c[1])
	if x < m.end.x - 2:
		_header(Rect2(x, m.position.y + 2, m.end.x - 2 - x, 18), "")


func _col_x(m: Rect2, cols: Array, i: int) -> float:
	var x := m.position.x + 2
	for k in i:
		x += float(cols[k][1])
	return x


func _group(r: Rect2, caption: String) -> void:
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size), T.WHITE, false, 1.0)
	draw_rect(r, T.SHADOW, false, 1.0)
	var w := _w(caption) + 6
	draw_rect(Rect2(r.position + Vector2(7, -6), Vector2(w, 12)), T.FACE)
	_t(r.position + Vector2(10, 4), caption)


## A 98 check box (the sunken white square, the tick when on) with its label.
func _check(at: Vector2, label: String, on: bool, id: String, enabled := true) -> void:
	var box := Rect2(at, Vector2(13, 13))
	draw_style_box(T.box("field", T.WHITE if enabled else T.LIGHT, Vector4.ZERO), box)
	if on:
		for k in 3:
			draw_line(box.position + Vector2(3, 5 + k), box.position + Vector2(5, 7 + k), T.TEXT)
			draw_line(box.position + Vector2(5, 7 + k), box.position + Vector2(9, 3 + k), T.TEXT)
	_t(at + Vector2(19, 11), label)
	if not enabled:
		return
	var r := Rect2(at - Vector2(2, 2), Vector2(_w(label) + 26, 17))
	if _hover == id:
		draw_rect(r, Color(T.NAVY, 0.12))
	_hit(id, r)


func _lamp(at: Vector2, level: int) -> void:
	var col: Color = LAMPS[level]
	draw_circle(at, 4.0, col.darkened(0.6))
	draw_circle(at, 3.0, col)
	draw_rect(Rect2(at + Vector2(-2, -2), Vector2(2, 2)), col.lightened(0.6))


func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


func _icon(name: String, at: Vector2) -> void:
	var t := _load(ICONS + name + ".png")
	if t == null:
		return
	var sz := Vector2(t.get_size())
	var k := minf(16.0 / sz.x, 16.0 / sz.y)
	draw_texture_rect(t, Rect2(at + (Vector2(16, 16) - sz * k) * 0.5, sz * k), false)


func _photo(r: Rect2, slug: String) -> void:
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), r)
	var t := _load(PHOTOS + BUSINESS.photo_of(slug) + ".png")
	if t != null:
		draw_texture_rect(t, r.grow(-2), false)


func _leather(r: Rect2) -> void:
	var t := _load(LEATHER)
	if t != null:
		draw_texture_rect_region(t, r, Rect2(r.position, r.size))
	else:
		draw_rect(r, BOARD)


## The green LCD of the desk: cells of [label, value, the sum that colours it].
func _lcd(r: Rect2, cells: Array) -> void:
	draw_style_box(T.box("field", LCD_BG, Vector4.ZERO), r)
	var cw := (r.size.x - 8) / float(cells.size())
	for i in cells.size():
		var x := r.position.x + 6 + cw * i
		if i > 0:
			draw_rect(Rect2(x - 4, r.position.y + 6, 1, r.size.y - 12), LCD_DIM)
		draw_string(T.FONT, Vector2(x + 2, r.position.y + 14), tr(str(cells[i][0])).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, cw - 6, T.FONT_SIZE, LCD_DIM)
		var col: Color = LCD_RED if cells[i].size() > 2 and int(cells[i][2]) < 0 else LCD_ON
		draw_string(T.FONT_MONO, Vector2(x + 2, r.position.y + 33), str(cells[i][1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 6, T.FONT_MONO_SIZE, col)


# ── the desk ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	_hits.clear()
	if not _shell._is_program_unlocked(PROGRAM):
		_draw_buy()
		return
	if _nav == "place" and not _places().has(_place):
		_nav = "overview"
	_draw_top()
	_draw_side()
	var m := Rect2(SIDE_W, TOP_H, size.x - SIDE_W, size.y - TOP_H - STATUS_H)
	draw_rect(m, T.FACE)
	if _places().is_empty():
		_tc(Rect2(m.position, Vector2(m.size.x, m.size.y * 0.5)), tr("Nowhere to work in the camp yet."), T.SHADOW)
	else:
		match _nav:
			"overview":
				_draw_overview(m)
			"order":
				_draw_order(m)
			"people":
				_draw_people(m)
			"books":
				_draw_books(m)
			"place":
				_draw_place(m)
	_draw_status()


## The brass-and-leather head: the program's name, the day, the till.
func _draw_top() -> void:
	var r := Rect2(0, 0, size.x, TOP_H)
	_leather(r)
	draw_rect(Rect2(0, TOP_H - 2, size.x, 1), GOLD_DIM)
	draw_rect(Rect2(0, TOP_H - 1, size.x, 1), Color8(10, 20, 16))
	var chair := _load(ICONS + "boss_app.png")
	if chair != null:
		draw_texture_rect(chair, Rect2(4, 2, 32, 32), false)
	draw_string(T.FONT_BOLD, Vector2(41, 26), tr("Boss 98"), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(8, 18, 12))
	draw_string(T.FONT_BOLD, Vector2(40, 25), tr("Boss 98"), HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, GOLD)
	var cash := _money(CoreRoot.get_money())
	var cw := T.FONT_MONO.get_string_size(cash, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_MONO_SIZE).x + 14.0
	var box := Rect2(size.x - cw - 6, 5, cw, 25)
	draw_style_box(T.box("field", LCD_BG, Vector4.ZERO), box)
	draw_string(T.FONT_MONO, box.position + Vector2(7, 18), cash, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_MONO_SIZE, LCD_ON)
	_tr(box.position.x - 10, 22, LANG.f("Day %d", CoreRoot.get_day()), GOLD)
	var guests := 0
	for g_any in CoreRoot.get_state().guests:
		if g_any is Dictionary and str(g_any.get("status", "")).to_lower() in ["active", "sleep"]:
			guests += 1
	_t(Vector2(SIDE_W + 8, 22), LANG.f("Guests in the camp: %d", guests), IVORY)


func _badge(id: String) -> Array:
	match id:
		"order":
			var n := _low_count()
			if n > 0:
				return [str(n), Color8(190, 40, 30)]
		"people":
			var bad := 0
			var day: int = CoreRoot.get_day()
			for e in _everyone():
				if int((e["p"] as Dictionary).get("owed", 0)) > 0 or int((e["p"] as Dictionary).get("absent", -1)) == day:
					bad += 1
			if bad > 0:
				return [str(bad), Color8(190, 40, 30)]
	return []


func _draw_side() -> void:
	_leather(Rect2(0, TOP_H, SIDE_W, size.y - TOP_H - STATUS_H))
	draw_rect(Rect2(SIDE_W - 2, TOP_H, 1, size.y - TOP_H - STATUS_H), GOLD_DIM)
	draw_rect(Rect2(SIDE_W - 1, TOP_H, 1, size.y - TOP_H - STATUS_H), Color8(10, 20, 16))
	var y := TOP_H + 6.0
	for n in NAV:
		var id := str(n[0])
		var r := Rect2(4, y, SIDE_W - 10, 26)
		var on := _nav == id
		_key_back(r, "nav:" + id, on)
		var off := Vector2(1, 1) if on else Vector2.ZERO
		_icon(str(n[2]), r.position + Vector2(5, 5) + off)
		_t(r.position + Vector2(26, 17) + off, tr(str(n[1])), Color8(30, 26, 12) if on else IVORY, true)
		var b := _badge(id)
		if not b.is_empty():
			var bw := _w(str(b[0]), true) + 8.0
			var br := Rect2(r.end.x - bw - 3, r.position.y + 6, bw, 14)
			draw_rect(br, b[1])
			_tc(br, str(b[0]), T.WHITE, true)
		y += 28.0
	y += 6.0
	_t(Vector2(8, y + 8), tr("PLACES"), GOLD)
	draw_rect(Rect2(8 + _w(tr("PLACES")) + 6, y + 4, SIDE_W - 22 - _w(tr("PLACES")) - 6, 1), GOLD_DIM)
	y += 14.0
	var places := _places()
	var rh := minf(25.0, floorf((size.y - STATUS_H - y - 4.0) / maxf(1.0, float(places.size()))))
	var day: int = CoreRoot.get_day()
	for place in places:
		var key := str(place)
		var r2 := Rect2(4, y, SIDE_W - 10, rh - 1)
		var on2 := _nav == "place" and _place == key
		_key_back(r2, "place:" + key, on2)
		_lamp(Vector2(r2.position.x + 9, r2.position.y + floorf(r2.size.y * 0.5)), _level(key))
		var base := r2.position.y + floorf(r2.size.y * 0.5) + 4
		var profit_w := 0.0
		if key != "staff":
			var p := int(RULES.today_money(BUSINESS.site(key), day)["profit"])
			var txt := _signed(p)
			profit_w = _w(txt) + 4.0
			_tr(r2.end.x - 4, base, txt, Color8(30, 26, 12) if on2 else (ON_LEATHER_DOWN if p < 0 else (ON_LEATHER_UP if p > 0 else GOLD_DIM)))
		_t(Vector2(r2.position.x + 18, base), _clip(_short(key), r2.size.x - 22.0 - profit_w), Color8(30, 26, 12) if on2 else IVORY, on2)
		y += rh


## A key on the desk: a brass plate when it is the one down.
func _key_back(r: Rect2, id: String, on: bool) -> void:
	if on:
		draw_rect(r, GOLD)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color8(250, 228, 160))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color8(120, 94, 40))
	elif _hover == id:
		draw_rect(r, Color(1, 1, 1, 0.1))
	_hit(id, r)


func _draw_status() -> void:
	var y := size.y - STATUS_H
	draw_rect(Rect2(0, y, size.x, STATUS_H), T.FACE)
	var orders := 0
	for o in _biz().get("orders", []):
		orders += 1
	var at_work := 0
	var wages := 0
	for e in _everyone():
		wages += int((e["p"] as Dictionary).get("wage", 0))
		if _status(e) == "At work":
			at_work += 1
	var cells := [[_notice if _notice != "" else tr("Ready"), size.x - 4 - 112 - 92 - 130], [LANG.f("On the van: %d", orders), 110], [LANG.f("%d at work", at_work), 90], [LANG.f("Wages $%d", wages), 128]]
	var x := 2.0
	for i in cells.size():
		var r := Rect2(x, y + 1, float(cells[i][1]), STATUS_H - 2)
		draw_style_box(T.box("well", T.FACE, Vector4.ZERO), r)
		_t(r.position + Vector2(4, 13), _clip(str(cells[i][0]), r.size.x - 8.0), _notice_col if i == 0 and _notice != "" else T.TEXT)
		x += r.size.x + 2


# ── not bought yet ───────────────────────────────────────────────────────────

func _draw_buy() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_leather(r)
	var frame := r.grow(-14)
	draw_rect(frame, GOLD_DIM, false, 1.0)
	draw_rect(frame.grow(-3), GOLD_DIM, false, 1.0)
	var chair := _load(ICONS + "boss_app.png")
	var mid := floorf(size.x * 0.5)
	if chair != null:
		draw_texture_rect(chair, Rect2(mid - 32, 66, 64, 64), false)
	var title := tr("Boss 98")
	var tw := T.FONT_BOLD.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 3).x
	draw_string(T.FONT_BOLD, Vector2(mid - tw * 0.5 + 2, 182), title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 3, Color8(8, 18, 12))
	draw_string(T.FONT_BOLD, Vector2(mid - tw * 0.5, 180), title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 3, GOLD)
	var licensed: bool = CoreRoot != null and CoreRoot.actions != null and CoreRoot.actions.biz_has_licence("boss")
	var line: String = tr("Every place you run and everybody who works there, at one desk.")
	_t(Vector2(mid - _w(line) * 0.5, 210), line, IVORY)
	var b := Rect2(mid - 120, 240, 240, 28)
	var price: int = RULES.licence_price("boss")
	_button(b, tr("Install") if licensed else LANG.f("Buy the licence  ($%d)", price), "buy_licence")
	draw_string(T.FONT, Vector2(mid - _w("SoftSklad s.r.o., Jihlava") * 0.5, size.y - 32), "SoftSklad s.r.o., Jihlava", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, GOLD_DIM)


# ── Overview ─────────────────────────────────────────────────────────────────

func _costs(d: Dictionary) -> int:
	return int(d["goods"]) + int(d["wages"]) + int(d["van"]) + int(d["short"])


## The last seven days of all the businesses, oldest first.
func _week_rows() -> Array:
	var biz := _biz()
	var day: int = CoreRoot.get_day()
	var out: Array = []
	for back in range(6, -1, -1):
		if day - back >= 1:
			out.append(RULES.camp_day(biz, back, day))
	return out


func _draw_overview(m: Rect2) -> void:
	var rows := _week_rows()
	var d0: Dictionary = rows[rows.size() - 1] if not rows.is_empty() else RULES.camp_day(_biz(), 0, CoreRoot.get_day())
	var week := 0
	for d in rows:
		week += int(d["takings"]) - _costs(d)
	var profit := int(d0["takings"]) - _costs(d0)
	var top := Rect2(m.position + Vector2(6, 6), Vector2(m.size.x - 12, 42))
	_lcd(top, [["Takings today", _money(int(d0["takings"]))], ["Costs today", _money(_costs(d0))], ["Profit today", _signed_money(profit), profit], ["Profit, 7 days", _signed_money(week), week]])
	# The places in rows.
	var places := _biz_places()
	var cols := [["", 14], ["Place", 86], ["State", 62], ["Hands", 38, true], ["Waiting", 40, true], ["Takings", 56, true], ["Profit", 56, true], ["7 days", 60, true], ["Goods", 84]]
	var rh := minf(ROW_H, floorf(144.0 / maxf(1.0, float(places.size()))))
	var tm := Rect2(m.position.x + 6, top.end.y + 6, m.size.x - 12, 22 + maxf(1.0, float(places.size())) * rh + 4)
	_list(tm, cols)
	var day: int = CoreRoot.get_day()
	if places.is_empty():
		_t(Vector2(tm.position.x + 20, tm.position.y + 35), tr("No business in the camp yet."), T.SHADOW)
	for i in places.size():
		var key := str(places[i])
		var s := BUSINESS.site(key)
		var y := tm.position.y + 22 + i * rh
		var r := Rect2(tm.position.x + 2, y, tm.size.x - 4, rh)
		if _hover == "place:" + key:
			draw_rect(r, Color(T.NAVY, 0.1))
		var base := y + floorf(rh * 0.5) + 4
		_lamp(Vector2(_col_x(tm, cols, 0) + 7, y + floorf(rh * 0.5)), _level(key))
		_t(Vector2(_col_x(tm, cols, 1) + 4, base), _clip(_short(key), 80.0, true), T.TEXT, true)
		var shift: String = BUSINESS.shift_now(s)
		_t(Vector2(_col_x(tm, cols, 2) + 4, base), tr("Closed") if shift == "closed" else tr("Open now"), T.SHADOW if shift == "closed" else T.TEXT)
		var on_now := BUSINESS.crew_now(key).size()
		var all_hands := (s.get("crew", []) as Array).size()
		_tr(_col_x(tm, cols, 4) - 6, base, "%d/%d" % [on_now, all_hands], RED if all_hands == 0 else T.TEXT)
		var wait := _waiting(key)
		_tr(_col_x(tm, cols, 5) - 6, base, str(wait) if wait > 0 else "-", RED if wait > 0 else T.SHADOW)
		var money: Dictionary = RULES.today_money(s, day)
		_tr(_col_x(tm, cols, 6) - 6, base, _num(int(money["takings"])))
		var p := int(money["profit"])
		_tr(_col_x(tm, cols, 7) - 6, base, _signed(p), RED if p < 0 else (GREEN if p > 0 else T.SHADOW))
		var wk := int(RULES.week_money(s, day)["profit"])
		_tr(_col_x(tm, cols, 8) - 6, base, _signed(wk), RED if wk < 0 else (GREEN if wk > 0 else T.SHADOW))
		var w := _worst(key)
		if w.is_empty():
			_t(Vector2(_col_x(tm, cols, 8) + 5, base), tr("Shelves full"), GREEN)
		else:
			var line := LANG.f("%s: none left", str(w["label"])) if int(w["n"]) <= 0 else (LANG.f("%s: %d days", [str(w["label"]), int(w["days"])]) if int(w["days"]) >= 0 else LANG.f("%s: low", str(w["label"])))
			_t(Vector2(_col_x(tm, cols, 8) + 5, base), _clip(line, 76.0), RED if int(w["n"]) <= 0 or int(w["days"]) <= 1 else AMBER)
		_hit("place:" + key, r)
	# What wants you, and the week.
	var by := tm.end.y + 12
	var bh := m.end.y - by - 6
	var wr := Rect2(m.position.x + 6, by, 262, bh)
	_group(wr, tr("Wants you"))
	var wants := _wants()
	if wants.is_empty():
		_t(wr.position + Vector2(12, 26), tr("Nothing is on fire."), GREEN, true)
	var fit := int((bh - 12.0) / 16.0)
	for i in mini(wants.size(), fit):
		var row: Array = wants[i]
		var rr := Rect2(wr.position.x + 4, wr.position.y + 9 + i * 16.0, wr.size.x - 8, 16)
		if _hover == str(row[2]):
			draw_rect(rr, Color(T.NAVY, 0.12))
		_lamp(Vector2(rr.position.x + 7, rr.position.y + 8), int(row[1]))
		_t(Vector2(rr.position.x + 16, rr.position.y + 12), _clip(str(row[0]), rr.size.x - 18.0))
		_hit(str(row[2]), rr)
	var pairs: Array = []
	var d_no: int = day - rows.size() + 1
	for i in rows.size():
		var d: Dictionary = rows[i]
		pairs.append([int(d["takings"]), _costs(d), tr(Season.weekday_short(d_no + i)) if d_no + i != day else tr("today")])
	_pairs_chart(Rect2(wr.end.x + 6, by - 6, m.end.x - wr.end.x - 12, bh + 6), pairs)


## What came in and what it cost: two bars a day.
func _pairs_chart(ch: Rect2, pairs: Array) -> void:
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), ch)
	var costs_w := _w(tr("Costs"))
	var takings_w := _w(tr("Takings"))
	var lx := ch.end.x - 6.0 - costs_w
	_t(Vector2(lx, ch.position.y + 14), tr("Costs"), T.SHADOW)
	draw_rect(Rect2(lx - 11, ch.position.y + 6, 8, 8), BAR_B)
	lx -= 22.0 + takings_w
	_t(Vector2(lx, ch.position.y + 14), tr("Takings"), T.SHADOW)
	draw_rect(Rect2(lx - 11, ch.position.y + 6, 8, 8), BAR_A)
	var top := 10
	for p in pairs:
		top = maxi(top, maxi(int(p[0]), int(p[1])))
	top = int(ceil(top / 10.0)) * 10
	var plot := Rect2(ch.position.x + 40, ch.position.y + 22, ch.size.x - 46, ch.size.y - 40)
	for k in 3:
		var gy := plot.end.y - plot.size.y * k / 2.0
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), T.LIGHT)
		_tr(plot.position.x - 3, gy + 4, _amount(int(top * k / 2.0)), T.SHADOW)
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), T.TEXT)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, T.TEXT)
	var bw := plot.size.x / 7.0
	for i in pairs.size():
		var x := plot.position.x + (7 - pairs.size() + i) * bw
		var ha := plot.size.y * float(int(pairs[i][0])) / float(top)
		var hb := plot.size.y * float(int(pairs[i][1])) / float(top)
		draw_rect(Rect2(x + bw * 0.14, plot.end.y - ha, bw * 0.34, ha), BAR_A)
		draw_rect(Rect2(x + bw * 0.52, plot.end.y - hb, bw * 0.34, hb), BAR_B)
		_tc(Rect2(x, plot.end.y + 2, bw, 14), str(pairs[i][2]), T.SHADOW)


# ── The order ────────────────────────────────────────────────────────────────

func _urgency(key: String, s: Dictionary, kind: String, g: String) -> float:
	var have := int((s.get("stock", {}) as Dictionary).get(g, 0)) + BUSINESS.on_order(key, g)
	if have <= 0:
		return -1.0
	var use: float = RULES.use_per_day(s, g)
	if use > 0.0:
		return float(have) / use
	if RULES.is_low(kind, g, have):
		return 10.0
	return 30.0 + 30.0 * float(have) / float(maxi(1, RULES.cap_of(kind, g, s)))


## Every good kept anywhere, what runs out first at the top (as things stand when the sheet is
## opened: rows do not jump about under the mouse).
func _sheet_rows() -> Array:
	var out: Array = []
	for place in _biz_places():
		var key := str(place)
		var s := BUSINESS.site(key)
		var kind := str(s.get("kind", ""))
		for g in RULES.goods(kind):
			if RULES.kept(kind, g) and RULES.menu_on(kind, s, str(g)):
				out.append([key, str(g), _urgency(key, s, kind, str(g))])
	out.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	return out


func _draw_order(m: Rect2) -> void:
	if _sheet.is_empty():
		_sheet = _sheet_rows()
	var cols := [["Place", 84], ["Item", 128], ["Shelf", 40, true], ["Days", 32, true], ["Coming", 38, true], ["Packs", 66], ["Price", 46, true], ["Total", 56, true]]
	var foot_h := 56.0
	var lm := Rect2(m.position + Vector2(6, 6), Vector2(m.size.x - 12, m.size.y - 12 - foot_h - 8))
	_list(lm, cols)
	var per := maxi(1, int((lm.size.y - 44.0) / SHEET_ROW))
	var pages := maxi(1, ceili(float(_sheet.size()) / float(per)))
	_sheet_page = clampi(_sheet_page, 0, pages - 1)
	var rows: Array = _sheet.slice(_sheet_page * per, (_sheet_page + 1) * per)
	for i in rows.size():
		var key := str(rows[i][0])
		var g := str(rows[i][1])
		var s := BUSINESS.site(key)
		if s.is_empty():
			continue
		var kind := str(s.get("kind", ""))
		var d: Dictionary = RULES.goods(kind)[g]
		var y := lm.position.y + 22 + i * SHEET_ROW
		var base := y + 12
		var n := int(s["stock"].get(g, 0))
		var low: bool = RULES.is_low(kind, g, n)
		var col: Color = RED if low else T.TEXT
		if i % 2 == 1:
			draw_rect(Rect2(lm.position.x + 2, y, lm.size.x - 4, SHEET_ROW), Color8(240, 240, 246))
		draw_rect(Rect2(_col_x(lm, cols, 0) + 4, y + 4, 7, 8), PLACE_COL.get(kind, T.NAVY))
		_t(Vector2(_col_x(lm, cols, 0) + 15, base), _clip(_short(key), 66.0), T.SHADOW)
		_t(Vector2(_col_x(lm, cols, 1) + 5, base), _clip(tr(str(d["label"])), 118.0), col)
		_tr(_col_x(lm, cols, 3) - 6, base, str(n), col)
		var last: int = RULES.days_left(s, g)
		_tr(_col_x(lm, cols, 4) - 6, base, str(last) if last >= 0 else "-", (RED if last <= 1 else T.TEXT) if last >= 0 else T.SHADOW)
		var due: int = BUSINESS.on_order(key, g)
		_tr(_col_x(lm, cols, 5) - 6, base, "+%d" % due if due > 0 else "-", GREEN if due > 0 else T.SHADOW)
		var packs := int((_order.get(key, {}) as Dictionary).get(g, 0))
		_spinner(_col_x(lm, cols, 5) + 3, y, SHEET_ROW - 1.0, key, g, packs)
		_tr(_col_x(lm, cols, 7) - 6, base, _amount(int(d["pack_cost"])), T.SHADOW)
		_tr(_col_x(lm, cols, 8) - 6, base, _amount(packs * int(d["pack_cost"])) if packs > 0 else "-", T.TEXT if packs > 0 else T.SHADOW)
	_pager(Vector2(lm.end.x - 4, lm.end.y - 20), _sheet_page, pages, "sheet")
	_order_foot(Rect2(m.position.x + 6, lm.end.y + 12, m.size.x - 12, foot_h - 2))


func _spinner(x: float, y: float, h: float, key: String, g: String, packs: int) -> void:
	var room := _room(key, g)
	_button(Rect2(x, y, 16, h), "-", "minus:%s:%s" % [key, g], packs > 0)
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), Rect2(x + 18, y, 26, h))
	_tc(Rect2(x + 18, y + 1, 26, h), str(packs), T.TEXT if packs > 0 else T.SHADOW, packs > 0)
	_button(Rect2(x + 46, y, 16, h), "+", "plus:%s:%s" % [key, g], room > packs)


## The turning of a long list, at the right of its header.
func _pager(right_top: Vector2, page: int, pages: int, what: String) -> void:
	if pages <= 1:
		return
	var label := "%d/%d" % [page + 1, pages]
	var x := right_top.x - 40.0
	_button(Rect2(x, right_top.y + 1, 19, 16), "<", what + "_back", page > 0)
	_button(Rect2(x + 20, right_top.y + 1, 19, 16), ">", what + "_on", page < pages - 1)
	_tr(x - 5, right_top.y + 13, label, T.TEXT, true)


## What is written in, one van, what it comes to, and the buttons.
func _order_foot(foot: Rect2) -> void:
	_group(foot, tr("Order for the camp"))
	var parts: Array = []
	for key in _order:
		var c2 := RULES.goods_cost(_kind_of(str(key)), _order[key])
		if c2 > 0:
			parts.append("%s %s" % [_short(str(key)), _money(c2)])
	var text: String = ", ".join(parts) if not parts.is_empty() else tr("Nothing yet")
	_t(foot.position + Vector2(12, 21), _clip(text, foot.size.x - 288.0), T.SHADOW)
	var cost := _order_total()
	var fee := _van_fee() if cost > 0 else 0
	_t(foot.position + Vector2(12, 40), _clip(LANG.f("One van $%d   Total $%d", [fee, cost]), foot.size.x - 288.0, true), RED if cost > CoreRoot.get_money() else T.TEXT, true)
	var by := foot.position.y + 16
	_button(Rect2(foot.end.x - 272, by, 86, 26), tr("Fill up"), "fill")
	_button(Rect2(foot.end.x - 182, by, 82, 26), tr("Clear"), "clear", cost > 0)
	_button(Rect2(foot.end.x - 96, by, 88, 26), tr("Send order"), "send", cost > fee)


# ── People ───────────────────────────────────────────────────────────────────

func _draw_people(m: Rect2) -> void:
	var all := _everyone()
	var ap := _applicants()
	_switch(Rect2(m.position.x + 6, m.position.y + 6, 121, 22), LANG.f("Working here (%d)", all.size()), "who:crew", _who == "crew")
	_switch(Rect2(m.position.x + 129, m.position.y + 6, 121, 22), LANG.f("Asking today (%d)", ap.size()), "who:hire", _who == "hire")
	var left := Rect2(m.position.x + 6, m.position.y + 32, 244, m.size.y - 38)
	var right := Rect2(left.end.x + 8, m.position.y + 12, m.end.x - left.end.x - 14, m.size.y - 18)
	if _who == "hire":
		_draw_hire(left, right, ap)
		return
	var cols := [["", 14], ["Name", 90], ["Place", 66], ["", 70]]
	_list(left, cols)
	var per := maxi(1, int((left.size.y - 44.0) / ROW_H))
	var pages := maxi(1, ceili(float(all.size()) / float(per)))
	_people_page = clampi(_people_page, 0, pages - 1)
	if all.is_empty():
		_t(Vector2(left.position.x + 8, left.position.y + 38), tr("Nobody. You do it all yourself."), RED)
	if _entry(_pick).is_empty() and not all.is_empty():
		_pick = str((all[0]["p"] as Dictionary).get("slug", ""))
	var rows: Array = all.slice(_people_page * per, (_people_page + 1) * per)
	for i in rows.size():
		var e: Dictionary = rows[i]
		var p: Dictionary = e["p"]
		var slug := str(p.get("slug", ""))
		var r := Rect2(left.position.x + 2, left.position.y + 22 + i * ROW_H, left.size.x - 4, ROW_H)
		var sel := slug == _pick
		if sel:
			draw_rect(r, T.NAVY)
		elif _hover == "crew:" + slug:
			draw_rect(r, Color(T.NAVY, 0.1))
		var fg := T.WHITE if sel else T.TEXT
		draw_rect(Rect2(r.position + Vector2(4, 5), Vector2(8, 8)), PLACE_COL.get(_kind_of(str(e["at"])), T.NAVY))
		_t(r.position + Vector2(16, 13), _clip(tr(str(p.get("name", ""))), 86.0), fg)
		_t(r.position + Vector2(105, 13), _clip(_short(str(e["at"])), 62.0), fg)
		var status := _status(e)
		var owed := int(p.get("owed", 0))
		var warn := status in ["Away today", "In a guest bed"] or owed > 0
		_tr(r.end.x - 4, r.position.y + 13, _clip(LANG.f("Owed $%d", owed) if owed > 0 else tr(status), 66.0), (RED if warn and not sel else (GREEN if status == "From tomorrow" and not sel else fg)))
		_hit("crew:" + slug, r)
	_pager(Vector2(left.end.x - 4, left.end.y - 20), _people_page, pages, "people")
	_draw_card(right)


## The one picked: where they work, their post, their shift, letting them go.
func _draw_card(right: Rect2) -> void:
	_group(right, tr("Works at"))
	var e := _entry(_pick)
	if e.is_empty():
		_t(right.position + Vector2(12, 30), tr("Nobody yet."), T.SHADOW)
		return
	var who: Dictionary = e["p"]
	var at := str(e["at"])
	var pr := Rect2(right.position + Vector2(12, 14), Vector2(52, 66))
	_photo(pr, _pick)
	var tx := pr.end.x + 8
	var room := right.end.x - tx - 6
	_t(Vector2(tx, pr.position.y + 12), _clip(tr(str(who.get("name", ""))), room, true), T.TEXT, true)
	var late_hand := at != "staff" and str(who.get("shift", "day")) == "late"
	_t(Vector2(tx, pr.position.y + 28), _clip(LANG.f("$%d a late shift" if late_hand else "$%d a day", RULES.shift_pay(who) if at != "staff" else int(who.get("wage", 0))), room))
	var ways := [RULES.SPEED_WORD[clampi(int(who.get("speed", 1)), 0, 2)], str(RULES.TEMPER_WORD.get(str(who.get("temper", "flat")), ""))]
	var wy := pr.position.y + 44
	for w in ways:
		_t(Vector2(tx, wy), _clip(tr(str(w)), room), T.SHADOW)
		wy += 14
	# A button for each place: where they are now pressed in, a click moves them.
	var places := _places()
	var bw := floorf((right.size.x - 28) * 0.5)
	var by := pr.end.y + 8
	for i in places.size():
		var place := str(places[i])
		var br := Rect2(right.position.x + 10 + (i % 2) * (bw + 4), by + (i / 2) * 23, bw, 21)
		if place == at:
			draw_style_box(T.box("pressed", T.LIGHT, Vector4.ZERO), br)
			draw_rect(Rect2(br.position + Vector2(5, 7), Vector2(7, 8)), PLACE_COL.get(_kind_of(place), T.NAVY))
			_t(br.position + Vector2(15, 15), _clip(_short(place), bw - 18.0, true), T.TEXT, true)
		else:
			_place_button(br, place, "move:" + place, _would(_pick, place))
	var jy := by + ((places.size() + 1) / 2) * 23 + 4
	if at == "staff":
		for i in STAFF.JOBS.size():
			var id := str(STAFF.JOBS[i][0])
			_check(Vector2(right.position.x + 10 + (i % 2) * (bw + 4), jy + (i / 2) * 18), _clip(tr(str(STAFF.JOBS[i][1])), bw - 16.0), STAFF.does(who, id), "job:" + id)
	else:
		var roles: Array = RULES.ROLES.get(_kind_of(at), [])
		for i in roles.size():
			var rid := str(roles[i][0])
			_check(Vector2(right.position.x + 10 + (i % 2) * (bw + 4), jy + (i / 2) * 18), _clip(tr(str(roles[i][1])), bw - 16.0), str(who.get("role", "")) == rid, "role:" + rid)
		_check(Vector2(right.position.x + 10, right.end.y - 24), tr("Late shift"), late_hand, "late_shift")
	_button(Rect2(right.end.x - 90, right.end.y - 28, 80, 22), tr("Let go"), "fire")


func _place_button(r: Rect2, place: String, id: String, enabled: bool, wage := -1) -> void:
	var pushed := enabled and _down == id and _hover == id
	draw_style_box(T.box("pressed" if pushed else "raised", T.FACE, Vector4.ZERO), r)
	var off := Vector2(1, 1) if pushed else Vector2.ZERO
	draw_rect(Rect2(r.position + Vector2(5, 7) + off, Vector2(7, 8)), PLACE_COL.get(_kind_of(place), T.NAVY) if enabled else T.SHADOW)
	var pay := ""
	var pay_w := 0.0
	if wage >= 0:
		pay = _amount(wage)
		pay_w = _w(pay) + 6.0
		_tr(r.end.x - 5 + off.x, r.position.y + 15 + off.y, pay, T.TEXT if enabled else T.SHADOW)
	_t(r.position + Vector2(15, 15) + off, _clip(_short(place), r.size.x - 18.0 - pay_w), T.TEXT if enabled else T.SHADOW)
	if enabled:
		_hit(id, r)


func _draw_hire(left: Rect2, right: Rect2, ap: Array) -> void:
	_list(left, [["Name", left.size.x - 4]])
	if ap.is_empty():
		_t(Vector2(left.position.x + 8, left.position.y + 38), tr("Nobody."), T.SHADOW)
		_group(right, tr("Papers"))
		return
	for i in ap.size():
		var r2 := Rect2(left.position.x + 2, left.position.y + 22 + i * ROW_H, left.size.x - 4, ROW_H)
		var sel := i == _candidate % ap.size()
		if sel:
			draw_rect(r2, T.NAVY)
		elif _hover == "cand:%d" % i:
			draw_rect(r2, Color(T.NAVY, 0.1))
		_t(r2.position + Vector2(6, 13), tr(str(ap[i]["name"])), T.WHITE if sel else T.TEXT)
		_hit("cand:%d" % i, r2)
	var free: int = STAFF.gear_count(_st(), "locker") - _crew().size()
	_t(Vector2(left.position.x + 8, left.end.y - 10), LANG.f("Lockers free: %d", maxi(0, free)), GREEN if free > 0 else RED)
	_group(right, tr("Papers"))
	var p2: Dictionary = ap[_candidate % ap.size()]
	var slug := str(p2["slug"])
	var pr := Rect2(right.position + Vector2(12, 14), Vector2(52, 66))
	_photo(pr, slug)
	var tx := pr.end.x + 8
	var room := right.end.x - tx - 6
	_t(Vector2(tx, pr.position.y + 12), _clip(tr(str(p2["name"])), room, true), T.TEXT, true)
	var ty := pr.position.y + 28
	for line in p2.get("refs", []):
		_t(Vector2(tx, ty), _clip(tr(str(line)), room), T.TEXT)
		ty += 15
	ty = maxf(ty, pr.end.y + 4)
	_t(Vector2(right.position.x + 12, ty + 12), tr("Take on at:"), T.TEXT, true)
	var places := _places()
	var bw := floorf((right.size.x - 28) * 0.5)
	var by := ty + 20
	for i in places.size():
		var place := str(places[i])
		var ok := _would(slug, place) and (place != "staff" or free > 0)
		_place_button(Rect2(right.position.x + 10 + (i % 2) * (bw + 4), by + (i / 2) * 23, bw, 21), place, "take:" + place, ok, _wage_at(slug, place))


# ── Accounts ─────────────────────────────────────────────────────────────────

func _period_money(key: String) -> Dictionary:
	var s := BUSINESS.site(key)
	var day: int = CoreRoot.get_day()
	match _period:
		"today":
			return RULES.today_money(s, day)
		"yesterday":
			return RULES.day_money(s.get("yesterday", {}))
		"week":
			return RULES.week_money(s, day)
	var t: Dictionary = RULES.today_money(s, day)
	var tot: Dictionary = s.get("total", {}) if s.get("total", {}) is Dictionary else {}
	for k in t:
		t[k] = int(t[k]) + int(tot.get(k, 0))
	return t


func _staff_wages() -> int:
	var biz := _biz()
	var day: int = CoreRoot.get_day()
	match _period:
		"today":
			return int(RULES.camp_day(biz, 0, day)["staff_wages"])
		"yesterday":
			return int(RULES.camp_day(biz, 1)["staff_wages"])
		"week":
			var n := int(RULES.camp_day(biz, 0, day)["staff_wages"])
			for back in range(1, 7):
				n += int(RULES.camp_day(biz, back)["staff_wages"])
			return n
	var camp: Dictionary = biz.get("camp", {}) if biz.get("camp", {}) is Dictionary else {}
	return int(camp.get("staff_total", 0)) + int(RULES.camp_day(biz, 0, day)["staff_wages"])


func _draw_books(m: Rect2) -> void:
	var sw := 76.0
	for i in PERIODS.size():
		_switch(Rect2(m.position.x + 6 + i * (sw + 2), m.position.y + 6, sw, 22), tr(str(PERIODS[i][1])), "period:" + str(PERIODS[i][0]), _period == str(PERIODS[i][0]))
	var places := _biz_places()
	var cols := [["Place", 96], ["Takings", 60, true], ["Goods", 56, true], ["Wages", 56, true], ["Van", 56, true], ["Short", 50, true], ["Profit", 62, true]]
	var rows: Array = []
	var total := {"takings": 0, "goods": 0, "wages": 0, "van": 0, "short": 0, "profit": 0}
	for place in places:
		var key := str(place)
		var mo := _period_money(key)
		rows.append([_short(key), mo, "place:" + key, _kind_of(key)])
		for k in total:
			total[k] = int(total[k]) + int(mo[k])
	if _has_room():
		var sw_w := _staff_wages()
		var st_mo := {"takings": 0, "goods": 0, "wages": sw_w, "van": 0, "short": 0, "profit": -sw_w}
		rows.append([tr("Staffroom"), st_mo, "place:staff", "staff"])
		total["wages"] = int(total["wages"]) + sw_w
		total["profit"] = int(total["profit"]) - sw_w
	var rh := minf(ROW_H, floorf(162.0 / maxf(1.0, float(rows.size()))))
	var tm := Rect2(m.position.x + 6, m.position.y + 34, m.size.x - 12, 22 + rows.size() * rh + 24)
	_list(tm, cols)
	var biggest := 1
	for r0 in rows:
		biggest = maxi(biggest, absi(int(r0[1]["profit"])))
	var keys := ["takings", "goods", "wages", "van", "short"]
	var signs := [1, -1, -1, -1, -1]
	for i in rows.size():
		var row: Array = rows[i]
		var mo2: Dictionary = row[1]
		var y := tm.position.y + 22 + i * rh
		var base := y + floorf(rh * 0.5) + 4
		var r := Rect2(tm.position.x + 2, y, tm.size.x - 4, rh)
		if _hover == str(row[2]):
			draw_rect(r, Color(T.NAVY, 0.1))
		draw_rect(Rect2(_col_x(tm, cols, 0) + 4, y + floorf(rh * 0.5) - 4, 7, 8), PLACE_COL.get(str(row[3]), T.NAVY))
		_t(Vector2(_col_x(tm, cols, 0) + 15, base), _clip(str(row[0]), 82.0), T.TEXT, true)
		for c in keys.size():
			var v := int(mo2[keys[c]]) * int(signs[c])
			_tr(_col_x(tm, cols, c + 2) - 6, base, _num(v), RED if keys[c] == "short" and v != 0 else (T.TEXT if v != 0 else T.SHADOW))
		var p := int(mo2["profit"])
		_tr(_col_x(tm, cols, 7) - 6, base, _signed(p), RED if p < 0 else (GREEN if p > 0 else T.SHADOW), true)
		# A bar beside it, from the middle of its column: who makes it and who loses it.
		var barx := _col_x(tm, cols, 7) + 4
		var bar_w := tm.end.x - 6 - barx
		var mid := barx + bar_w * 0.5
		draw_rect(Rect2(mid, y + 1, 1, rh - 2), T.LIGHT)
		var len_ := bar_w * 0.5 * float(absi(p)) / float(biggest)
		if p > 0:
			draw_rect(Rect2(mid + 1, y + 3, len_, rh - 6), GREEN)
		elif p < 0:
			draw_rect(Rect2(mid - len_, y + 3, len_, rh - 6), RED)
		_hit(str(row[2]), r)
	# All of it together.
	var fy := tm.position.y + 22 + rows.size() * rh + 2
	draw_line(Vector2(tm.position.x + 4, fy), Vector2(tm.end.x - 4, fy), T.SHADOW)
	var fbase := fy + 15
	_t(Vector2(_col_x(tm, cols, 0) + 15, fbase), tr("All"), T.TEXT, true)
	for c2 in keys.size():
		_tr(_col_x(tm, cols, c2 + 2) - 6, fbase, _num(int(total[keys[c2]]) * int(signs[c2])), T.TEXT, true)
	var tp := int(total["profit"])
	_tr(_col_x(tm, cols, 7) - 6, fbase, _signed(tp), RED if tp < 0 else (GREEN if tp > 0 else T.SHADOW), true)
	# The profit of the last days.
	var ch := Rect2(m.position.x + 6, tm.end.y + 6, m.size.x - 12, m.end.y - tm.end.y - 12)
	var days := _week_rows()
	var values: Array = []
	var labels: Array = []
	var day: int = CoreRoot.get_day()
	var d_no: int = day - days.size() + 1
	for i in days.size():
		values.append(int(days[i]["takings"]) - _costs(days[i]))
		labels.append(tr(Season.weekday_short(d_no + i)) if d_no + i != day else tr("today"))
	_updown_chart(ch, tr("Profit, 7 days"), values, labels)


## Bars up from the line and down from it: a day's profit or loss.
func _updown_chart(ch: Rect2, title: String, values: Array, labels: Array) -> void:
	draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), ch)
	_t(ch.position + Vector2(8, 15), title, T.TEXT, true)
	var hi := 10
	var lo := 0
	for v in values:
		hi = maxi(hi, int(v))
		lo = mini(lo, int(v))
	var plot := Rect2(ch.position.x + 8, ch.position.y + 22, ch.size.x - 16, ch.size.y - 40)
	var zero := plot.position.y + plot.size.y * float(hi) / float(hi - lo)
	draw_line(Vector2(plot.position.x, zero), Vector2(plot.end.x, zero), T.TEXT)
	var bw := plot.size.x / 7.0
	for i in values.size():
		var v := int(values[i])
		var x := plot.position.x + (7 - values.size() + i) * bw
		var h := plot.size.y * float(absi(v)) / float(hi - lo)
		var bar := Rect2(x + bw * 0.2, zero - h if v >= 0 else zero + 1.0, bw * 0.6, h)
		draw_rect(bar, GREEN if v >= 0 else RED)
		if h >= 13.0:
			_tc(Rect2(bar.position, Vector2(bar.size.x, minf(bar.size.y, 14.0))), _signed(v), T.WHITE)
		else:
			_tc(Rect2(bar.position.x, (zero - 15.0 if v < 0 else zero - h - 15.0), bar.size.x, 14.0), _signed(v), GREEN if v >= 0 else RED)
		_tc(Rect2(x, plot.end.y + 2, bw, 14), str(labels[i]), T.SHADOW)


# ── a place ──────────────────────────────────────────────────────────────────

## The band over a place: its colour, its picture, its name.
func _band(m: Rect2, kind: String, title: String, line: String) -> Rect2:
	var band := Rect2(m.position, Vector2(m.size.x, 46))
	var c0: Color = PLACE_COL.get(kind, T.NAVY)
	for x in int(band.size.x / 4.0) + 1:
		draw_rect(Rect2(band.position.x + x * 4, band.position.y, 4, band.size.y), c0.lerp(c0.lightened(0.42), float(x * 4) / band.size.x))
	draw_rect(Rect2(band.position.x, band.end.y - 1, band.size.x, 1), Color8(20, 20, 20))
	var pic := _load("res://assets/textury/builder/" + str(PLACE_PIC.get(kind, "")))
	var tx := band.position.x + 8
	if pic != null:
		var sz := Vector2(pic.get_size())
		var k := minf(50.0 / sz.x, 42.0 / sz.y)
		draw_texture_rect(pic, Rect2(band.position + Vector2(4, 2) + (Vector2(50, 42) - sz * k) * 0.5, sz * k), false)
		tx = band.position.x + 60
	draw_string(T.FONT_BOLD, Vector2(tx + 1, band.position.y + 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, Color8(10, 10, 10, 160))
	draw_string(T.FONT_BOLD, Vector2(tx, band.position.y + 23), title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE * 2, T.WHITE)
	_t(Vector2(tx, band.position.y + 39), line, Color8(240, 236, 220))
	return band


func _draw_place(m: Rect2) -> void:
	if _place == "staff":
		_draw_staffroom(m)
		return
	var s := BUSINESS.site(_place)
	if s.is_empty():
		_nav = "overview"
		return
	var kind := str(s.get("kind", ""))
	var late := bool(s.get("late", false))
	var on_now := BUSINESS.crew_now(_place).size()
	var hands := (s.get("crew", []) as Array).size()
	var shut: bool = BUSINESS.shift_now(s) == "closed"
	var line := "%s   %s   %s" % [tr("Closed") if shut else LANG.f("Open till %s", "23:00" if late else "20:00"), LANG.f("%d of %d at work", [on_now, hands]), LANG.f("%d waiting", _waiting(_place))]
	var band := _band(m, kind, _label(_place), line)
	_button(Rect2(band.end.x - 104, band.position.y + 11, 96, 24), tr("Shut at 20:00") if late else tr("Open late"), "late")
	var y0 := band.end.y + 5
	var left := Rect2(m.position.x + 6, y0, 314, m.end.y - y0 - 6)
	for i in 3:
		var sub: Array = [["goods", "Goods"], ["menu", "Menu"], ["gear", "Gear"]][i]
		_switch(Rect2(left.position.x + i * 78, left.position.y, 76, 21), tr(str(sub[1])), "sub:" + str(sub[0]), _sub == str(sub[0]))
	var body := Rect2(left.position.x, left.position.y + 24, left.size.x, left.size.y - 24)
	match _sub:
		"goods":
			_draw_goods(body, s, kind)
		"menu":
			_draw_menu(body, s, kind)
		"gear":
			_draw_gear(body, s, kind)
	var right := Rect2(left.end.x + 6, y0, m.end.x - left.end.x - 12, m.end.y - y0 - 6)
	_draw_place_day(right, s, kind)


func _draw_goods(r: Rect2, s: Dictionary, kind: String) -> void:
	var gd: Dictionary = RULES.goods(kind)
	var cols := [["Item", 106], ["Shelf", 40, true], ["Days", 28, true], ["Coming", 36, true], ["Packs", 66], ["Price", 34, true]]
	var foot_h := 46.0
	var lm := Rect2(r.position, Vector2(r.size.x, r.size.y - foot_h))
	_list(lm, cols)
	var rh := minf(ROW_H, floorf((lm.size.y - 24.0) / float(maxi(1, gd.size()))))
	var i := 0
	for g0 in gd:
		var g := str(g0)
		var d: Dictionary = gd[g]
		var y := lm.position.y + 22 + i * rh
		var base := y + floorf(rh * 0.5) + 4
		var n := int(s["stock"].get(g, 0))
		var low: bool = RULES.is_low(kind, g, n) and RULES.kept(kind, g)
		var col: Color = RED if low else T.TEXT
		_t(Vector2(_col_x(lm, cols, 0) + 4, base), _clip(tr(str(d["label"])), 100.0), col)
		_tr(_col_x(lm, cols, 2) - 5, base, str(n), col)
		var last: int = RULES.days_left(s, g)
		_tr(_col_x(lm, cols, 3) - 5, base, str(last) if last >= 0 else "-", (RED if last <= 1 else T.TEXT) if last >= 0 else T.SHADOW)
		var due: int = BUSINESS.on_order(_place, g)
		_tr(_col_x(lm, cols, 4) - 5, base, "+%d" % due if due > 0 else "-", GREEN if due > 0 else T.SHADOW)
		var packs := int((_order.get(_place, {}) as Dictionary).get(g, 0))
		_spinner(_col_x(lm, cols, 4) + 2, y, rh - 1.0, _place, g, packs)
		_tr(_col_x(lm, cols, 6) - 5, base, _amount(int(d["pack_cost"])), T.SHADOW)
		i += 1
	var fy := lm.end.y + 4
	_check(Vector2(r.position.x + 2, fy + 1), tr("Hands order"), bool(s.get("auto_order", true)), "auto")
	var cost := _order_total()
	var fee := _van_fee() if cost > 0 else 0
	_t(Vector2(r.position.x + 2, fy + 34), _clip(LANG.f("Total $%d", cost), r.size.x - 172.0, true), RED if cost > CoreRoot.get_money() else T.TEXT, true)
	_button(Rect2(r.end.x - 164, fy + 16, 80, 24), tr("Fill up"), "fill_here")
	_button(Rect2(r.end.x - 80, fy + 16, 80, 24), tr("Send order"), "send", cost > fee)


func _draw_menu(r: Rect2, s: Dictionary, kind: String) -> void:
	var rows: Array = RULES.MENU.get(kind, [])
	_list(r, [["What we sell", r.size.x - 4]])
	var rh := minf(ROW_H, floorf((r.size.y - 26.0) / float(maxi(1, rows.size()))))
	for i in rows.size():
		var id := str(rows[i][0])
		var locked := bool(rows[i][2])
		var y := r.position.y + 23 + i * rh
		_check(Vector2(r.position.x + 8, y + floorf((rh - 13.0) * 0.5)), tr(str(rows[i][1])), RULES.menu_on(kind, s, id), "menu:" + id, not locked)


func _draw_gear(r: Rect2, s: Dictionary, kind: String) -> void:
	var gear: Dictionary = RULES.gear_list(kind)
	_list(r, [["Gear", r.size.x - 4]])
	var rh := minf(54.0, floorf((r.size.y - 26.0) / float(maxi(1, gear.size()))))
	var i := 0
	for id0 in gear:
		var id := str(id0)
		var g: Dictionary = gear[id]
		var owned := RULES.has_gear(s, id)
		var y := r.position.y + 23 + i * rh
		if i > 0:
			draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), T.LIGHT)
		_t(Vector2(r.position.x + 8, y + 15), _clip(tr(str(g["label"])), 150.0, true), T.SHADOW if owned else T.TEXT, true)
		draw_multiline_string(T.FONT, Vector2(r.position.x + 8, y + 32), tr(str(g["what"])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, T.FONT_SIZE, 2, T.SHADOW if owned else T.TEXT)
		if owned:
			_tr(r.end.x - 8, y + 15, tr("Installed"), GREEN)
		else:
			var needs := RULES.gear_needs(kind, id)
			var blocked := needs != "" and not RULES.has_gear(s, needs)
			_tr(r.end.x - 66, y + 15, _money(int(g["price"])), T.TEXT)
			_button(Rect2(r.end.x - 60, y + 2, 54, 18), tr("Buy"), "gear:" + id, not blocked and CoreRoot.get_money() >= int(g["price"]))
		i += 1


## The right half of a place: its day against yesterday, the last shift's mark, who works there.
func _draw_place_day(r: Rect2, s: Dictionary, kind: String) -> void:
	var day: int = CoreRoot.get_day()
	var a: Dictionary = RULES.today_money(s, day)
	var b: Dictionary = RULES.day_money(s.get("yesterday", {}))
	var cols := [["", 64], ["Today", 54, true], ["Yesterday", r.size.x - 4 - 64 - 54, true]]
	var rows := [["Takings", "takings", 1], ["Goods", "goods", -1], ["Wages", "wages", -1], ["Van", "van", -1], ["Short", "short", -1]]
	var lh := 14.0
	var tm := Rect2(r.position, Vector2(r.size.x, 22 + (rows.size() + 1) * lh + 6))
	_list(tm, cols)
	var y := tm.position.y + 22
	for row in rows:
		_t(Vector2(tm.position.x + 6, y + 11), tr(str(row[0])))
		var va := int(a[row[1]]) * int(row[2])
		var vb := int(b[row[1]]) * int(row[2])
		_tr(_col_x(tm, cols, 2) - 5, y + 11, _num(va), T.TEXT if va != 0 else T.SHADOW)
		_tr(_col_x(tm, cols, 3) - 5, y + 11, _num(vb), T.TEXT if vb != 0 else T.SHADOW)
		y += lh
	draw_line(Vector2(tm.position.x + 4, y + 1), Vector2(tm.end.x - 4, y + 1), T.SHADOW)
	_t(Vector2(tm.position.x + 6, y + 14), tr("Profit"), T.TEXT, true)
	var pa := int(a["profit"])
	var pb := int(b["profit"])
	_tr(_col_x(tm, cols, 2) - 5, y + 14, _signed(pa), RED if pa < 0 else (GREEN if pa > 0 else T.SHADOW), true)
	_tr(_col_x(tm, cols, 3) - 5, y + 14, _signed(pb), RED if pb < 0 else (GREEN if pb > 0 else T.SHADOW), true)
	# The last shift's mark and the one thing to mend.
	var my := tm.end.y + 16
	var z: Dictionary = s.get("zreport", {}) if s.get("zreport", {}) is Dictionary else {}
	if not z.is_empty():
		var mark: Dictionary = {"grade": z["grade"], "advice": z.get("advice", "")} if z.has("grade") else RULES.day_grade(z)
		var gr := str(mark["grade"])
		var gr_col: Color = GREEN if gr in ["A", "B"] else (RED if gr in ["D", "E"] else T.TEXT)
		_t(Vector2(r.position.x + 4, my), LANG.f("Last shift: %s", gr), gr_col, true)
		draw_multiline_string(T.FONT, Vector2(r.position.x + 4, my + 15), tr(str(mark["advice"])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8.0, T.FONT_SIZE, 2, T.SHADOW)
		my += 39.0
	var n := int(s.get("all_orders", 0))
	if n > 0:
		_tr(r.end.x - 4, tm.end.y + 16, LANG.f("Average %d%%", int(round(float(s.get("all_score", 0)) / float(n)))), T.TEXT)
	# Who works here.
	var cy := my + 6
	var crew: Array = s.get("crew", [])
	var ch := minf(r.end.y - cy, 22.0 + maxf(1.0, float(crew.size())) * 16.0 + 4.0)
	var lm := Rect2(r.position.x, cy, r.size.x, ch)
	_list(lm, [["Working here", r.size.x - 4]])
	if crew.is_empty():
		_t(Vector2(lm.position.x + 6, lm.position.y + 35), tr("Nobody. You serve by hand."), RED)
	var fit := int((ch - 24.0) / 16.0)
	var now := BUSINESS.crew_now(_place)
	for i in mini(crew.size(), fit):
		var p: Dictionary = crew[i]
		var slug := str(p.get("slug", ""))
		var row_r := Rect2(lm.position.x + 2, lm.position.y + 22 + i * 16.0, lm.size.x - 4, 16)
		if _hover == "crew:" + slug:
			draw_rect(row_r, Color(T.NAVY, 0.1))
		var here := false
		for q in now:
			here = here or str(q.get("slug", "")) == slug
		_lamp(Vector2(row_r.position.x + 7, row_r.position.y + 8), 0 if here else -1)
		_t(row_r.position + Vector2(16, 12), _clip(tr(str(p.get("name", ""))), 82.0))
		_tr(row_r.end.x - 4, row_r.position.y + 12, _clip(tr(RULES.role_label(kind, str(p.get("role", "")))), 62.0), T.SHADOW)
		_hit("crew:" + slug, row_r)
	_button(Rect2(r.end.x - 74, r.end.y - 22, 74, 22), tr("Hire"), "hire_here")


func _draw_staffroom(m: Rect2) -> void:
	var st := _st()
	var crew: Array = _crew()
	var band := _band(m, "staff", tr("Staffroom"), LANG.f("Lockers %d / %d", [crew.size(), STAFF.gear_count(st, "locker")]))
	var y0 := band.end.y + 6
	var left := Rect2(m.position.x + 6, y0, 304, m.end.y - y0 - 6)
	var day: int = CoreRoot.get_day()
	_list(left, [["At", 50], ["Today", left.size.x - 54]])
	var rows: Array = []
	for e in st.get("log", []):
		if int(e.get("day", 0)) == day:
			rows.append(e)
	var fit := maxi(1, int((left.size.y - 46.0) / 15.0))
	rows = rows.slice(maxi(0, rows.size() - fit))
	var y := left.position.y + 34
	if rows.is_empty():
		_t(Vector2(left.position.x + 8, y), tr("Nothing done yet today."), T.SHADOW)
	for e in rows:
		var mm := int(e.get("t", 0)) % 1440
		_t(Vector2(left.position.x + 8, y), "%d:%02d" % [mm / 60, mm % 60], T.SHADOW)
		_t(Vector2(left.position.x + 56, y), _clip(tr(str(e.get("text", ""))), left.size.x - 62.0))
		y += 15
	_t(Vector2(left.position.x + 8, left.end.y - 8), LANG.f("Jobs today: %d   yesterday: %d", [int(st.get("done_n", 0)), int(st.get("done_y", 0))]), T.TEXT, true)
	var right := Rect2(left.end.x + 6, y0, m.end.x - left.end.x - 12, m.end.y - y0 - 6)
	var i := 0
	var gh := minf(116.0, right.size.y * 0.5 - 4.0)
	for id in ["locker", "armchair"]:
		var d: Dictionary = STAFF.GEAR[id]
		var r := Rect2(right.position.x, right.position.y + 6 + i * (gh + 10), right.size.x, gh)
		_group(r, tr(str(d["label"])))
		var pic := Rect2(r.position + Vector2(8, 12), Vector2(46, 58))
		draw_style_box(T.box("field", T.WHITE, Vector4.ZERO), pic)
		var t := _load(CARDS + "card_%s.png" % id)
		if t != null:
			var sz := Vector2(t.get_size())
			var k := minf((pic.size.x - 6) / sz.x, (pic.size.y - 6) / sz.y)
			draw_texture_rect(t, Rect2(pic.position + (pic.size - sz * k) * 0.5, sz * k), false)
		var tx := pic.end.x + 8
		_t(Vector2(tx, r.position.y + 26), LANG.f("%d of %d", [STAFF.gear_count(st, id), int(d["max"])]), T.TEXT, true)
		var price := STAFF.gear_price(st, id)
		if price > 0:
			_t(Vector2(tx, r.position.y + 44), _money(price), T.TEXT)
			_button(Rect2(tx, r.position.y + 52, 66, 22), tr("Buy"), "sgear:" + id, CoreRoot.get_money() >= price and _has_room())
		else:
			_t(Vector2(tx, r.position.y + 44), tr("No room for more."), GREEN)
		i += 1
