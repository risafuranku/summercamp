extends Control

## CampStat 98: the camp's back office. Power draw, the electricity bills (pay them here
## or the grid goes off), tonight's risk with the staff night procedures, the condition
## of the buildings (call the crew), the money, and what guests wrote.
##
## Downloaded from campgrid.cz and installed; one page per tab, links inside the pages
## (pay://<bill>, crew://all) do the work.

const T = preload("res://scripts/os98/os_theme.gd")
const TABS := [["power", "Power"], ["bills", "Bills"], ["night", "Night"], ["upkeep", "Upkeep"], ["money", "Money"], ["reviews", "Reviews"]]
const RED := "#a00000"
const AMBER := "#806000"
const GREEN := "#006000"
const GREY := "#606060"
const LINKC := "#0000ee"

## Staff guidance, in the voice of a camp operator that has clearly done this before.
## It never says what these things are. It only says what to do.
const NIGHT_PROCEDURES := [
	["Quiet Guy", "SILENT MAN", "Footsteps on the gravel behind you that stop when you stop. Do not stand still in the dark. Turn round and put a light on him. If he whispers, turn round at once."],
	["Drunk", "THE PHOTOGRAPHER", "A red light blinking in the trees, beeping faster. Turn your back or get behind something before the flash. Do not pose."],
	["Cheap Chick", "THE GIRL", "She stays where the light ends. Keep her in sight, keep moving, keep to the lamps. Batteries are not covered by the camp."],
	["Two or more", "THE ANTLERED MAN", "Walks the fence. Stay off the fence line after dark. He does not enter lamp light."],
]

var _shell
var _win
var _tabs: TabContainer
var _pages: Dictionary = {}
var _notice: Label
var _head: Label
var _tick := 0.0


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	_head = Label.new()
	_head.position = Vector2(4, 2)
	_head.add_theme_font_override("font", T.FONT_BOLD)
	add_child(_head)
	_notice = Label.new()
	_notice.position = Vector2(4, 18)
	_notice.clip_text = true
	add_child(_notice)
	_tabs = TabContainer.new()
	_tabs.position = Vector2(0, 36)
	add_child(_tabs)
	for t in TABS:
		var page := RichTextLabel.new()
		page.name = str(t[1])
		page.bbcode_enabled = true
		page.selection_enabled = true
		page.meta_underlined = true
		page.meta_clicked.connect(_on_link)
		_tabs.add_child(page)
		_pages[str(t[0])] = page
	_tabs.tab_changed.connect(func(_i): refresh())
	resized.connect(_layout)
	_layout()
	refresh()


func reopen(_args: Dictionary) -> void:
	refresh()


func _layout() -> void:
	if _tabs == null:
		return
	_tabs.size = Vector2(size.x, size.y - 36)
	_notice.size = Vector2(size.x - 8, 16)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0 and is_visible_in_tree():
		_tick = 2.0
		refresh()


func _active() -> String:
	return str(TABS[clampi(_tabs.current_tab, 0, TABS.size() - 1)][0])


func refresh() -> void:
	if _tabs == null:
		return
	var snap := _snapshot()
	_refresh_head(snap)
	var page: RichTextLabel = _pages[_active()]
	var scroll := page.get_v_scroll_bar().value
	match _active():
		"power":
			page.text = _power_text(snap)
		"bills":
			page.text = _bills_text(snap)
		"night":
			page.text = _night_text()
		"upkeep":
			page.text = _upkeep_text()
		"money":
			page.text = _money_text()
		"reviews":
			page.text = _reviews_text()
	page.get_v_scroll_bar().value = scroll


func _snapshot() -> Dictionary:
	var m: Node = _shell.main_node()
	if m == null or not m.has_method("get_electricity_ui_snapshot"):
		return {}
	var s = m.get_electricity_ui_snapshot()
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}


func _refresh_head(snap: Dictionary) -> void:
	if snap.is_empty():
		_head.text = "CampStat 98   -   no connection to the meter"
		_set_notice("", T.TEXT)
		return
	var grid_on := not bool(snap.get("power_cut_active", false))
	_head.text = "Day %d  %s     Grid: %s     Unpaid bills: %d     Overdue: %d" % [
		int(snap.get("day", 0)), str(snap.get("time", "--:--")), "ON" if grid_on else "OFF",
		int(snap.get("unpaid_count", 0)), int(snap.get("overdue_count", 0))]
	if not grid_on:
		var warn := "POWER CUT: pay every overdue bill to get the grid back."
		if bool(snap.get("ups_active", false)):
			var sec := maxi(0, int(ceil(float(snap.get("ups_seconds_left", 0.0)))))
			warn += "  UPS %02d:%02d left." % [sec / 60, sec % 60]
		_set_notice(warn, Color8(160, 0, 0))
	elif int(snap.get("overdue_count", 0)) > 0:
		_set_notice("Overdue bills: %d. The utility cuts the power for overdue bills." % int(snap.get("overdue_count", 0)), Color8(160, 0, 0))
	elif int(snap.get("unpaid_count", 0)) > 0:
		_set_notice("Bills waiting to be paid: %d (see Bills)." % int(snap.get("unpaid_count", 0)), Color8(128, 96, 0))
	else:
		_set_notice("Bills are issued every day at %02d:%02d for the day before." % [clampi(int(snap.get("bill_issue_hour", 20)), 0, 23), clampi(int(snap.get("bill_issue_minute", 0)), 0, 59)], T.SHADOW)


func _set_notice(text: String, color: Color) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)


func _on_link(meta) -> void:
	var s := str(meta)
	if s.begins_with("pay://"):
		_pay(s.trim_prefix("pay://"))
	elif s == "crew://all":
		_crew()


# ── power ────────────────────────────────────────────────────────────────────

func _power_text(snap: Dictionary) -> String:
	if snap.is_empty():
		return "[b]POWER[/b]\n\n[color=%s]No reading from the meter.[/color]" % RED
	var t := "[b]POWER DRAW[/b]\n"
	t += "Tariff $%.2f per kWh, standing charge $%d a day.\n\n" % [float(snap.get("rate_per_kwh", 0.0)), int(snap.get("base_fee", 0))]
	t += "Load today: [b]%.1f kWh[/b]   Energy: $%d   Bill tomorrow: [b]$%d[/b]\n\n" % [
		float(snap.get("daily_kwh_total", 0.0)), int(snap.get("daily_cost_energy", 0)), int(snap.get("daily_cost_total", 0))]
	var lines: Array = snap.get("consumption_lines", []) if snap.get("consumption_lines", []) is Array else []
	if lines.is_empty():
		return t + "[color=%s]Nothing on the grid yet.[/color]" % GREY
	t += "[code] #  building               where   units   kWh/day   $/day[/code]\n"
	var i := 1
	for l_any in lines:
		if not (l_any is Dictionary):
			continue
		var l: Dictionary = l_any
		var label := str(l.get("label", "?")).strip_edges()
		t += "[code]%2d  %-20s %6s  %5d  %8.1f  %6d[/code]\n" % [i, label.substr(0, 20), _coord(l.get("coord", Vector2i.ZERO)),
			maxi(0, int(l.get("power_units", 0))), maxf(0.0, float(l.get("kwh_per_day", 0.0))), maxi(0, int(l.get("cost_per_day", 0)))]
		i += 1
	return t


# ── bills ────────────────────────────────────────────────────────────────────

func _bills_text(snap: Dictionary) -> String:
	if snap.is_empty():
		return "[b]BILLS[/b]\n\n[color=%s]No connection to the utility.[/color]" % RED
	var grace: int = maxi(1, int(snap.get("bill_grace_days", 3)))
	var issue := "%02d:%02d" % [clampi(int(snap.get("bill_issue_hour", 20)), 0, 23), clampi(int(snap.get("bill_issue_minute", 0)), 0, 59)]
	var t := "[b]ELECTRICITY BILLS[/b]   Hlubocany District Power\n"
	t += "A bill comes every day at %s for the day before. Pay it within [b]%d days[/b].\n" % [issue, grace]
	t += "Unpaid: $%d     Overdue: [b]$%d[/b]\n" % [maxi(0, int(snap.get("unpaid_total", 0))), maxi(0, int(snap.get("overdue_total", 0)))]
	if bool(snap.get("power_cut_active", false)):
		t += "[color=%s][b]The grid is off until every overdue bill is paid.[/b][/color]\n" % RED
	var bills: Array = snap.get("bills", []) if snap.get("bills", []) is Array else []
	if bills.is_empty():
		return t + "\n[color=%s]No bills yet. The first one comes on day 2 at %s.[/color]" % [GREY, issue]
	t += "\n"
	for b_any in bills:
		if not (b_any is Dictionary):
			continue
		var b: Dictionary = b_any
		var id := str(b.get("id", "")).strip_edges()
		var paid := str(b.get("status", "unpaid")).to_lower().strip_edges() == "paid"
		var overdue := bool(b.get("is_overdue", false))
		var word := "PAID"
		var col := GREEN
		if not paid:
			word = "OVERDUE" if overdue else "UNPAID"
			col = RED if overdue else AMBER
		t += "[b]Day %d[/b]  %.1f kWh  [b]$%d[/b]   [color=%s][b]%s[/b][/color]   due day %d (%s)" % [
			int(b.get("service_day", 0)), maxf(0.0, float(b.get("kwh_total", 0.0))), maxi(0, int(b.get("amount", 0))),
			col, word, int(b.get("due_day", 0)), _due(int(b.get("days_left", 0)), paid, overdue)]
		if not paid and not id.is_empty():
			t += "   [url=pay://%s][color=%s]%s[/color][/url]" % [id, RED if overdue else LINKC, "PAY NOW" if overdue else "Pay"]
		t += "\n"
	t += "\n[color=%s]An overdue bill cuts the power to the lamps and the buildings.\nThis computer then runs on its UPS for six minutes.[/color]" % GREY
	return t


func _due(days_left: int, paid: bool, overdue: bool) -> String:
	if paid:
		return "paid"
	if overdue:
		return "%d day(s) late" % absi(days_left)
	if days_left <= 0:
		return "today"
	return "1 day left" if days_left == 1 else "%d days left" % days_left


func _pay(bill_id: String) -> void:
	var m: Node = _shell.main_node()
	if m == null or not m.has_method("request_pay_electricity_bill"):
		_set_notice("The utility does not answer.", Color8(160, 0, 0))
		return
	var r = m.request_pay_electricity_bill(bill_id)
	var res: Dictionary = r if r is Dictionary else {}
	refresh()
	if bool(res.get("ok", false)):
		_shell.play("click")
		_set_notice("Paid. -$%d" % maxi(0, int(res.get("amount", 0))), Color8(0, 96, 0))
		return
	var msg := "The payment did not go through."
	match str(res.get("reason", "")):
		"already_paid":
			msg = "That bill is already paid."
		"insufficient_funds":
			msg = "Not enough money. You need $%d." % maxi(0, int(res.get("amount", 0)))
		"not_found":
			msg = "The utility has no record of that bill."
	_shell.message_box("CampStat 98", msg, "error")


# ── night ────────────────────────────────────────────────────────────────────

func _night_text() -> String:
	var t := ""
	if GuestManager == null or not GuestManager.has_method("get_liminal_forecast_data"):
		t = "[b]TONIGHT[/b]\n\n[color=%s]No guest data.[/color]\n\n" % RED
	else:
		var p_any = GuestManager.get_liminal_forecast_data()
		var p: Dictionary = p_any if p_any is Dictionary else {}
		if not bool(p.get("ok", false)):
			t = "[b]TONIGHT[/b]\n\n[color=%s]No forecast.[/color]\n\n" % RED
		else:
			var totals: Dictionary = p.get("totals", {}) if p.get("totals", {}) is Dictionary else {}
			var safe := int(p.get("safe_count", 3))
			t = "[b]TONIGHT[/b]\n"
			t += "Guests in camp: %d.   Each kind of guest is quiet up to %d in the camp.\n" % [int(totals.get("guests", 0)), safe]
			t += "Expected visits tonight: [b]%.2f[/b]   Certain: [b]%d[/b]\n\n" % [float(totals.get("expected_spawns", 0.0)), int(totals.get("guaranteed_spawns", 0))]
			var entries: Array = p.get("archetypes", []) if p.get("archetypes", []) is Array else []
			for e_any in entries:
				if not (e_any is Dictionary):
					continue
				var e: Dictionary = e_any
				var count := int(e.get("count", 0))
				var tier := str(e.get("chance_tier", "none"))
				var pct := int(round(float(e.get("chance_probability", 0.0)) * 100.0))
				var verdict := "quiet"
				var col := GREEN
				if int(e.get("guaranteed_spawns", 0)) > 0:
					verdict = "CERTAIN x%d" % int(e.get("guaranteed_spawns", 0))
					col = RED
				elif not (tier == "none" or tier.is_empty()):
					verdict = "%s ~%d%%" % [tier.to_upper(), pct]
					col = AMBER if pct < 40 else RED
				t += "[code]%-14s %2d in camp  [/code][color=%s]%s[/color]\n" % [str(e.get("label", "?")), count, col, verdict]
			t += "\n[color=%s]More guests of one kind raise that kind's odds.\nA mixed camp is a quieter camp.[/color]\n\n" % GREY
	t += "[b]STAFF PROCEDURES (NIGHT)[/b]  [color=%s]rev. 3, do not remove from terminal[/color]\n" % GREY
	for row in NIGHT_PROCEDURES:
		t += "[b]%s[/b] -> [color=%s]%s[/color]\n    %s\n" % [row[0], RED, row[1], row[2]]
	t += "[color=%s]Incidents are not to be reported to guests. Incidents are not to be reported.[/color]" % GREY
	return t


# ── upkeep ───────────────────────────────────────────────────────────────────

## Worst first. Below 50% a building can break; broken ones serve nobody.
func _upkeep_text() -> String:
	var m: Node = _shell.main_node()
	if m == null or not m.has_method("get_upkeep_snapshot"):
		return "[b]UPKEEP[/b]\n\n[color=%s]No maintenance data.[/color]" % RED
	var snap: Dictionary = m.get_upkeep_snapshot()
	var rows: Array = snap.get("rows", [])
	var t := "[b]UPKEEP[/b]\n[color=%s]Below 50%% a building can break down. Broken buildings serve no one.\nWalk up to it and hold [b]R[/b] to service or repair it.[/color]\n\n" % GREY
	if rows.is_empty():
		return t + "[color=%s]Nothing built that needs looking after yet.[/color]" % GREY
	for r_any in rows:
		var r: Dictionary = r_any
		var cond := float(r.get("condition", 1.0))
		var broken := bool(r.get("broken", false))
		var cells := int(round(cond * 10.0))
		var bar := "#".repeat(cells) + ".".repeat(10 - cells)
		var col := GREEN
		var word := "GOOD"
		if broken:
			col = RED
			word = "BROKEN"
			bar = "XXXXXXXXXX"
		elif cond < 0.5:
			col = RED
			word = "POOR"
		elif cond < 0.75:
			col = AMBER
			word = "WORN"
		t += "[code][color=%s]%s %3d%% %-6s[/color][/code]  %s  [color=%s]%s $%d[/color]\n" % [col, bar, int(round(cond * 100.0)), word,
			str(r.get("label", "?")), GREY, "repair" if broken else "service", int(r.get("cost", 0))]
	var jobs := int(snap.get("crew_jobs", 0))
	t += "\n"
	if jobs <= 0:
		t += "[color=%s]Everything is in working order.[/color]" % GREEN
	elif bool(snap.get("night", false)):
		t += "[color=%s]Maintenance crew: %d job(s), $%d. The crew does not come out after dark.[/color]" % [GREY, jobs, int(snap.get("crew_cost", 0))]
	else:
		t += "[url=crew://all][color=%s][b]Call the maintenance crew[/b][/color][/url]  [color=%s]%d job(s), $%d[/color]" % [LINKC, GREY, jobs, int(snap.get("crew_cost", 0))]
	return t


func _crew() -> void:
	var m: Node = _shell.main_node()
	if m == null or not m.has_method("request_maintenance_crew"):
		return
	var res: Dictionary = m.request_maintenance_crew()
	refresh()
	if bool(res.get("ok", false)):
		_set_notice("The crew did %d job(s). -$%d" % [int(res.get("jobs", 0)), int(res.get("amount", 0))], Color8(0, 96, 0))
		return
	match str(res.get("reason", "")):
		"night":
			_shell.message_box("CampStat 98", "The crew does not come out after dark.", "info")
		"insufficient_funds":
			_shell.message_box("CampStat 98", "Not enough money for the crew ($%d)." % int(res.get("amount", 0)), "error")
		_:
			_set_notice("Nothing for the crew to do.", T.SHADOW)


# ── money ────────────────────────────────────────────────────────────────────

func _money_text() -> String:
	var t := "[b]MONEY[/b]\n"
	t += "Day %d.   Cash: [b]$%d[/b]\n\n" % [CoreRoot.get_day(), CoreRoot.get_money()]
	var passive := 0
	var breakdown: Array = []
	var m: Node = _shell.main_node()
	var eco: Node = m.get_node_or_null("EconomyManager") if m != null else null
	if eco != null:
		if eco.has_method("calculate_day_income"):
			passive = int(eco.calculate_day_income())
		if eco.has_method("get_income_breakdown"):
			breakdown = eco.get_income_breakdown()
	var guests_income := 0
	var guests := 0
	var state = CoreRoot.get_state()
	if state != null:
		for g_any in state.guests:
			if g_any is Dictionary and str(g_any.get("status", "")).to_lower() in ["active", "sleep"]:
				guests += 1
				guests_income += maxi(1, int(g_any.get("daily_income", 1)))
	t += "[code]Guests (%2d)      $%5d a day[/code]\n" % [guests, guests_income]
	t += "[code]Facilities       $%5d a day[/code]\n" % passive
	t += "[code]                 ------[/code]\n"
	t += "[code]Total            $%5d a day[/code]\n\n" % (guests_income + passive)
	if not breakdown.is_empty():
		t += "[b]Facilities[/b]\n"
		for l in breakdown:
			t += "  %s\n" % str(l)
	t += "\n[color=%s]Electricity is billed separately (see Bills).[/color]" % GREY
	return t


# ── reviews ──────────────────────────────────────────────────────────────────

func _reviews_text() -> String:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	var reviews: Array = state.guest_reviews if state != null else []
	var t := "[b]GUEST REVIEWS[/b]\n\n"
	if reviews.is_empty():
		return t + "[color=%s]No reviews yet. Guests write one when they leave.[/color]" % GREY
	var total := 0.0
	for r in reviews:
		if r is Dictionary:
			total += float(r.get("rating", 0))
	t += "Average [b]%.1f / 5[/b] from %d review(s)\n\n" % [total / float(reviews.size()), reviews.size()]
	for i in range(reviews.size() - 1, maxi(-1, reviews.size() - 31), -1):
		var r: Dictionary = reviews[i] if reviews[i] is Dictionary else {}
		var rating := clampi(int(r.get("rating", 0)), 0, 5)
		var col := GREEN if rating >= 4 else (AMBER if rating == 3 else RED)
		t += "[code][color=%s]%s[/color][/code]  [b]%s[/b]  [color=%s]day %d[/color]\n    %s\n" % [
			col, "*".repeat(rating) + "-".repeat(5 - rating), str(r.get("name", "Guest")), GREY, int(r.get("day", 0)), str(r.get("text", ""))]
	return t


func _coord(v: Variant) -> String:
	if v is Vector2i:
		return "%d:%d" % [v.x, v.y]
	if v is Vector2:
		return "%d:%d" % [int(v.x), int(v.y)]
	if v is Dictionary:
		return "%d:%d" % [int(v.get("x", 0)), int(v.get("y", 0))]
	return "-"
