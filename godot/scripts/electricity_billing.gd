extends RefCounted

## Electricity billing: the game's administrative fail state. Extracted from main.gd.
##
## Every evening at ISSUE_HOUR:ISSUE_MINUTE the previous service day is billed from the
## camp's power draw (EconomyManager.get_power_draw_breakdown) and a notice mail is
## sent. A bill is due GRACE_DAYS later. Any overdue bill cuts grid power: the UPS
## starts a UPS_DURATION_SEC countdown, and when it runs dry the game is over. Paying
## every overdue bill restores the grid.
##
## Pure state + rules; no nodes. main.gd feeds the clock (`set_clock`), ticks it during
## play, listens to the signals and exposes `ui_snapshot` / `pay` to the CRT terminal.

signal state_changed
signal power_cut_changed(cut: bool)
signal ups_expired

const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")
const ISSUE_HOUR: int = BALANCE_CONFIG.NIGHT_START_HOUR
const ISSUE_MINUTE: int = 0
const GRACE_DAYS: int = 3
const PRICE_PER_KWH: float = 2.2
const KWH_PER_POWER_UNIT: float = 3.0
const DAILY_BASE_FEE: int = 12
const UPS_DURATION_SEC: float = 360.0
const NOTICE_SENDER := "CampGrid Energy Billing <billing@campgrid.local>"
const NOTICE_TEMPLATES: Array[Dictionary] = [
	{
		"subject": "Electricity invoice {bill_id} issued - due Day {due_day}",
		"body": "Hello reception,\n\nYour electricity invoice {bill_id} for service day {service_day} is now posted.\nAmount due: {amount_usd}.\nPayment deadline: Day {due_day} before {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Payment reminder: {amount_usd} due for {bill_id}",
		"body": "Billing notice,\n\nWe generated invoice {bill_id}.\nOutstanding amount: {amount_usd}.\nPlease settle by Day {due_day} before {issue_time} to avoid interruption.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Camp power account update - invoice {bill_id}",
		"body": "Reception team,\n\nService day {service_day} usage has been billed under {bill_id}.\nTotal due now: {amount_usd}.\nDue date: Day {due_day} ({grace_days}-day window).\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Billing alert: Day {service_day} electricity charge ready",
		"body": "Automated advisory,\n\nInvoice {bill_id} is available in your camp account.\nAmount: {amount_usd}.\nPlease pay before Day {due_day} at {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Utility invoice {bill_id} now open",
		"body": "Hello,\n\nA new utility invoice has been posted.\nInvoice ID: {bill_id}\nAmount due: {amount_usd}\nDeadline: Day {due_day} before {issue_time}\n\nCampGrid Energy Billing",
	},
	{
		"subject": "CampGrid notice: electricity due on Day {due_day}",
		"body": "Reception,\n\nThis is a scheduled evening billing notice.\nInvoice {bill_id} totals {amount_usd} for service day {service_day}.\nPlease process payment no later than Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Invoice queued: {bill_id} ({amount_usd})",
		"body": "System message,\n\nInvoice {bill_id} was queued to your mailbox.\nCurrent amount payable: {amount_usd}.\nGrace period ends on Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Evening utility statement - {bill_id}",
		"body": "Hello reception,\n\nYour evening electricity statement has been finalized.\nReference: {bill_id}\nService day: {service_day}\nDue amount: {amount_usd}\nPay by Day {due_day} before {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Action required: settle electricity invoice {bill_id}",
		"body": "Camp operations,\n\nPlease review and pay invoice {bill_id}.\nBalance due: {amount_usd}.\nDeadline for payment: Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Grid account billing event - {bill_id}",
		"body": "Automated account event,\n\nElectricity billing for day {service_day} has posted.\nInvoice number: {bill_id}\nAmount due: {amount_usd}\nPayment due: Day {due_day} ({issue_time}).\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Power service invoice posted ({bill_id})",
		"body": "Reception desk,\n\nWe posted a new power service invoice.\nID: {bill_id}\nTotal: {amount_usd}\nPlease settle before Day {due_day} to keep account current.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Outstanding utility balance notice: {amount_usd}",
		"body": "Reminder,\n\nInvoice {bill_id} entered unpaid status.\nAmount currently due: {amount_usd}.\nLast day to pay without penalty: Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Service day {service_day} consumption invoiced",
		"body": "Hello,\n\nConsumption for service day {service_day} has been converted to invoice {bill_id}.\nBalance: {amount_usd}.\nDue date: Day {due_day} before {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Camp energy billing cycle closed - invoice ready",
		"body": "Operations update,\n\nThe latest billing cycle is closed.\nInvoice: {bill_id}\nAmount due: {amount_usd}\nGrace period: {grace_days} day(s), ending Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Notice of payable electricity charges ({bill_id})",
		"body": "Reception,\n\nThis notice confirms payable electricity charges.\nInvoice ID: {bill_id}\nService day: {service_day}\nTotal due: {amount_usd}\nPayment deadline: Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Invoice {bill_id}: utility payment window active",
		"body": "Billing center notice,\n\nYour payment window is now active for invoice {bill_id}.\nAmount: {amount_usd}.\nPlease complete payment by Day {due_day} at {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "CampGrid account message - new electricity amount due",
		"body": "Hello camp reception,\n\nA new electricity amount is due under invoice {bill_id}.\nCurrent balance: {amount_usd}.\nPlease pay by Day {due_day}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Utility debt prevention reminder ({bill_id})",
		"body": "Preventive reminder,\n\nInvoice {bill_id} is pending in your account.\nTotal due: {amount_usd}.\nSettle by Day {due_day} to avoid overdue status.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Electricity ledger entry created for Day {service_day}",
		"body": "Ledger update,\n\nA new ledger entry has been created as invoice {bill_id}.\nPayable amount: {amount_usd}.\nDue on Day {due_day} before {issue_time}.\n\nCampGrid Energy Billing",
	},
	{
		"subject": "Final evening notice: invoice {bill_id} awaiting payment",
		"body": "Evening dispatch,\n\nInvoice {bill_id} was added to your unpaid list.\nAmount due now: {amount_usd}.\nDeadline remains Day {due_day}.\n\nCampGrid Energy Billing",
	},
]

var bills: Array[Dictionary] = []
var last_billed_service_day: int = 0
var notice_cursor: int = 0
var power_cut_active: bool = false
var ups_active: bool = false
var ups_seconds_left: float = UPS_DURATION_SEC

var _economy: Node
var _day: int = 1
var _minute_of_day: int = 540


func setup(economy_manager: Node) -> void:
	_economy = economy_manager


func set_clock(day_index: int, minute_of_day: int) -> void:
	_day = maxi(1, day_index)
	_minute_of_day = minute_of_day


## New game: nothing billed, no debt.
func reset(day_index: int) -> void:
	bills.clear()
	last_billed_service_day = maxi(0, day_index - 1)
	notice_cursor = 0
	power_cut_active = false
	ups_active = false
	ups_seconds_left = UPS_DURATION_SEC


## One gameplay frame: issue due bills, update the power cut, run the UPS.
func tick(delta: float) -> void:
	_issue_pending_bills()
	refresh_power_cut()
	if power_cut_active:
		if not ups_active:
			ups_active = true
			ups_seconds_left = UPS_DURATION_SEC
		var before := ups_seconds_left
		ups_seconds_left = maxf(0.0, ups_seconds_left - maxf(delta, 0.0))
		if ups_seconds_left <= 0.0 and before > 0.0:
			ups_expired.emit()
		return
	if ups_active or ups_seconds_left < UPS_DURATION_SEC:
		ups_active = false
		ups_seconds_left = UPS_DURATION_SEC


func refresh_power_cut(force_apply: bool = false) -> void:
	var now_cut := count_overdue() > 0
	var changed := now_cut != power_cut_active
	power_cut_active = now_cut
	if power_cut_active:
		if changed:
			ups_active = true
			ups_seconds_left = UPS_DURATION_SEC
	else:
		ups_active = false
		ups_seconds_left = UPS_DURATION_SEC
	if changed or force_apply:
		power_cut_changed.emit(power_cut_active)
		state_changed.emit()


func count_overdue() -> int:
	var count := 0
	for bill in bills:
		if str(bill.get("status", "unpaid")) == "paid":
			continue
		if days_left_until_due(int(bill.get("due_day", _day))) < 0:
			count += 1
	return count


## Days until `due_day`; on the due day itself the bill turns overdue at issue time.
func days_left_until_due(due_day: int) -> int:
	var days_left := due_day - _day
	if days_left == 0 and _minute_of_day >= issue_minute_of_day():
		return -1
	return days_left


func issue_minute_of_day() -> int:
	return (ISSUE_HOUR * 60) + ISSUE_MINUTE


func issue_time_string() -> String:
	return "%02d:%02d" % [ISSUE_HOUR, ISSUE_MINUTE]


## Pays one bill. {ok, amount} or {ok:false, reason[, amount]}.
func pay(bill_id: String) -> Dictionary:
	var trimmed_id := bill_id.strip_edges()
	if trimmed_id.is_empty():
		return {"ok": false, "reason": "invalid_bill"}
	for i in bills.size():
		var bill: Dictionary = bills[i]
		if str(bill.get("id", "")) != trimmed_id:
			continue
		if str(bill.get("status", "unpaid")) == "paid":
			return {"ok": false, "reason": "already_paid"}
		var amount: int = maxi(0, int(bill.get("amount", 0)))
		if amount > 0:
			if CoreRoot.actions == null or not CoreRoot.actions.has_method("spend_money"):
				return {"ok": false, "reason": "money_system_missing"}
			if not CoreRoot.actions.spend_money(amount):
				return {"ok": false, "reason": "insufficient_funds", "amount": amount}
		bills.remove_at(i)
		refresh_power_cut(true)
		return {"ok": true, "amount": amount}
	return {"ok": false, "reason": "not_found"}


## Everything the CRT Camp Status app shows.
func ui_snapshot(time_string: String) -> Dictionary:
	var lines := consumption_lines()
	var total_kwh := 0.0
	var energy_charge := 0
	for line in lines:
		total_kwh += float(line.get("kwh_per_day", 0.0))
		energy_charge += int(line.get("cost_per_day", 0))
	var base_fee := DAILY_BASE_FEE if total_kwh > 0.001 else 0
	var listed: Array[Dictionary] = []
	var unpaid_total := 0
	var overdue_total := 0
	var unpaid_count := 0
	var overdue_count := 0
	for i in range(bills.size() - 1, -1, -1):
		var bill: Dictionary = bills[i]
		var status := str(bill.get("status", "unpaid")).to_lower().strip_edges()
		if status == "paid":
			continue
		var amount: int = maxi(0, int(bill.get("amount", 0)))
		var due_day := int(bill.get("due_day", _day))
		var days_left := days_left_until_due(due_day)
		var is_overdue := days_left < 0
		unpaid_total += amount
		unpaid_count += 1
		if is_overdue:
			overdue_total += amount
			overdue_count += 1
		var line_items: Array = []
		for item in bill.get("line_items", []):
			if item is Dictionary:
				line_items.append((item as Dictionary).duplicate(true))
		listed.append({
			"id": str(bill.get("id", "")),
			"service_day": int(bill.get("service_day", 0)),
			"issued_day": int(bill.get("issued_day", 0)),
			"issued_time": str(bill.get("issued_time", issue_time_string())),
			"due_day": due_day,
			"status": status,
			"amount": amount,
			"kwh_total": snappedf(float(bill.get("kwh_total", 0.0)), 0.1),
			"days_left": days_left,
			"is_overdue": is_overdue,
			"line_items": line_items,
		})
	return {
		"day": _day,
		"time": time_string,
		"rate_per_kwh": PRICE_PER_KWH,
		"kwh_per_power_unit": KWH_PER_POWER_UNIT,
		"base_fee": base_fee,
		"daily_kwh_total": snappedf(total_kwh, 0.1),
		"daily_cost_energy": energy_charge,
		"daily_cost_total": maxi(0, energy_charge + base_fee),
		"consumption_lines": lines,
		"bills": listed,
		"unpaid_total": unpaid_total,
		"overdue_total": overdue_total,
		"unpaid_count": unpaid_count,
		"overdue_count": overdue_count,
		"power_cut_active": power_cut_active,
		"ups_active": ups_active and power_cut_active,
		"ups_seconds_left": snappedf(ups_seconds_left, 0.1),
		"bill_grace_days": GRACE_DAYS,
		"bill_issue_hour": ISSUE_HOUR,
		"bill_issue_minute": ISSUE_MINUTE,
	}


## Per-building daily power draw, priced. Biggest consumers first.
func consumption_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if _economy == null or not _economy.has_method("get_power_draw_breakdown"):
		return lines
	var raw_any = _economy.get_power_draw_breakdown()
	if not (raw_any is Array):
		return lines
	for line_any in raw_any:
		if not (line_any is Dictionary):
			continue
		var raw_line := line_any as Dictionary
		var power_units: int = maxi(0, int(raw_line.get("power_use", 0)))
		if power_units <= 0:
			continue
		var kwh := float(power_units) * KWH_PER_POWER_UNIT
		lines.append({
			"building_type": str(raw_line.get("type", "")),
			"label": str(raw_line.get("label", "Unknown")),
			"coord": _coord(raw_line.get("coord", Vector2i.ZERO)),
			"power_units": power_units,
			"kwh_per_day": snappedf(kwh, 0.1),
			"cost_per_day": int(round(kwh * PRICE_PER_KWH)),
		})
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := int(a.get("power_units", 0))
		var bp := int(b.get("power_units", 0))
		if ap == bp:
			return str(a.get("label", "")) < str(b.get("label", ""))
		return ap > bp
	)
	return lines


# ── save ──────────────────────────────────────────────────────────────────────

func export_state() -> Dictionary:
	return {
		"last_billed_service_day": maxi(0, last_billed_service_day),
		"notice_template_cursor": _cursor(notice_cursor),
		"power_cut_active": power_cut_active,
		"ups_active": ups_active,
		"ups_seconds_left": clampf(ups_seconds_left, 0.0, UPS_DURATION_SEC),
		"bills": _normalize_bills(bills, true),
	}


## `data` may be empty (old saves): then nothing is owed and billing resumes today.
## The menu preview never runs a UPS countdown.
func import_state(data: Dictionary, day_index: int, preview_only: bool) -> void:
	_day = maxi(1, day_index)
	if data.is_empty():
		reset(day_index)
	else:
		last_billed_service_day = maxi(0, int(data.get("last_billed_service_day", maxi(0, day_index - 1))))
		notice_cursor = _cursor(int(data.get("notice_template_cursor", last_billed_service_day)))
		bills = _normalize_bills(data.get("bills", []), false)
		ups_seconds_left = clampf(float(data.get("ups_seconds_left", UPS_DURATION_SEC)), 0.0, UPS_DURATION_SEC)
		ups_active = bool(data.get("ups_active", false))
	if preview_only:
		ups_active = false
		ups_seconds_left = UPS_DURATION_SEC


func _normalize_bills(value: Variant, for_save: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for bill_any in value:
		if not (bill_any is Dictionary):
			continue
		var bill := (bill_any as Dictionary).duplicate(true)
		var line_items: Array[Dictionary] = []
		var line_items_any = bill.get("line_items", [])
		if line_items_any is Array:
			for line_any in line_items_any:
				if not (line_any is Dictionary):
					continue
				var line := (line_any as Dictionary).duplicate(true)
				var c := _coord(line.get("coord", Vector2i.ZERO))
				line["coord"] = {"x": c.x, "y": c.y} if for_save else c
				line["power_units"] = maxi(0, int(line.get("power_units", 0)))
				line["kwh_per_day"] = snappedf(maxf(0.0, float(line.get("kwh_per_day", 0.0))), 0.1)
				line["cost_per_day"] = maxi(0, int(line.get("cost_per_day", 0)))
				line_items.append(line)
		bill["service_day"] = maxi(1, int(bill.get("service_day", 1)))
		bill["issued_day"] = maxi(1, int(bill.get("issued_day", 1)))
		bill["due_day"] = maxi(1, int(bill.get("due_day", 1)))
		bill["amount"] = maxi(0, int(bill.get("amount", 0)))
		bill["status"] = "paid" if str(bill.get("status", "unpaid")) == "paid" else "unpaid"
		bill["kwh_total"] = snappedf(maxf(0.0, float(bill.get("kwh_total", 0.0))), 0.1)
		bill["base_fee"] = maxi(0, int(bill.get("base_fee", 0)))
		bill["rate_per_kwh"] = maxf(0.0, float(bill.get("rate_per_kwh", PRICE_PER_KWH)))
		bill["line_items"] = line_items
		out.append(bill)
	return out


# ── issuing ───────────────────────────────────────────────────────────────────

func _issue_pending_bills() -> void:
	if _minute_of_day < issue_minute_of_day():
		return
	var target_service_day := _day - 1
	while last_billed_service_day < target_service_day:
		var service_day := last_billed_service_day + 1
		if service_day > 0:
			_create_bill(service_day)
		last_billed_service_day = service_day
		state_changed.emit()


func _create_bill(service_day: int) -> void:
	var lines := consumption_lines()
	var total_kwh := 0.0
	var energy_charge := 0
	var bill_lines: Array[Dictionary] = []
	for line in lines:
		total_kwh += float(line.get("kwh_per_day", 0.0))
		energy_charge += int(line.get("cost_per_day", 0))
		var c: Vector2i = line.get("coord", Vector2i.ZERO)
		bill_lines.append({
			"building_type": str(line.get("building_type", "")),
			"label": str(line.get("label", "Unknown")),
			"coord": {"x": c.x, "y": c.y},
			"power_units": int(line.get("power_units", 0)),
			"kwh_per_day": snappedf(float(line.get("kwh_per_day", 0.0)), 0.1),
			"cost_per_day": int(line.get("cost_per_day", 0)),
		})
	var base_fee := DAILY_BASE_FEE if total_kwh > 0.001 else 0
	var bill := {
		"id": "elec_day_%d" % service_day,
		"service_day": service_day,
		"issued_day": _day,
		"issued_time": issue_time_string(),
		"due_day": _day + GRACE_DAYS,
		"status": "unpaid",
		"amount": maxi(0, energy_charge + base_fee),
		"rate_per_kwh": PRICE_PER_KWH,
		"base_fee": base_fee,
		"kwh_total": snappedf(total_kwh, 0.1),
		"line_items": bill_lines,
	}
	bills.append(bill)
	_send_notice(bill)


func _send_notice(bill: Dictionary) -> void:
	if EmailManager == null or not EmailManager.has_method("push_system_mail") or NOTICE_TEMPLATES.is_empty():
		return
	notice_cursor = _cursor(notice_cursor)
	var template: Dictionary = NOTICE_TEMPLATES[notice_cursor]
	notice_cursor = _cursor(notice_cursor + 1)
	var issue_day: int = maxi(1, int(bill.get("issued_day", _day)))
	var service_day: int = maxi(1, int(bill.get("service_day", issue_day)))
	var due_day: int = maxi(issue_day, int(bill.get("due_day", issue_day + GRACE_DAYS)))
	var issue_time := str(bill.get("issued_time", issue_time_string()))
	var amount := maxi(0, int(bill.get("amount", 0)))
	var bill_id := str(bill.get("id", "elec_day_%d" % service_day))
	var placeholders := {
		"bill_id": bill_id,
		"service_day": str(service_day),
		"issued_day": str(issue_day),
		"issue_time": issue_time,
		"due_day": str(due_day),
		"grace_days": str(GRACE_DAYS),
		"amount": str(amount),
		"amount_usd": "$%d" % amount,
	}
	EmailManager.push_system_mail({
		"sender": NOTICE_SENDER,
		"from": NOTICE_SENDER,
		"subject": _fill(str(template.get("subject", "Electricity invoice {bill_id} issued")), placeholders),
		"body": _fill(str(template.get("body", "Invoice {bill_id} is due on Day {due_day}.")), placeholders),
		"day": issue_day,
		"time": issue_time,
		"type": "system",
		"category": "electricity_billing",
		"bill_id": bill_id,
		"amount": amount,
		"due_day": due_day,
	})


func _fill(text: String, placeholders: Dictionary) -> String:
	var out := text
	for key in placeholders.keys():
		out = out.replace("{%s}" % str(key), str(placeholders[key]))
	return out


func _cursor(value: int) -> int:
	return 0 if NOTICE_TEMPLATES.is_empty() else posmod(value, NOTICE_TEMPLATES.size())


func _coord(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
