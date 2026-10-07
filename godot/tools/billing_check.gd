extends Node

## Headless check for electricity billing (scripts/electricity_billing.gd).
##
##   godot --headless --path godot res://tools/billing_check.tscn
##
## Scene (CoreRoot / EmailManager autoloads). Drives the clock by hand and asserts the
## whole loop: bill issued at 20:00 for the previous day -> due three days later ->
## overdue cuts power -> UPS counts down to game over -> paying restores the grid ->
## state survives an export/import round trip.

const BILLING = preload("res://scripts/electricity_billing.gd")

var _failures: Array[String] = []


class FakeEconomy:
	extends Node
	func get_power_draw_breakdown() -> Array:
		return [{"type": "pub", "label": "Pub (2x2)", "coord": Vector2i(3, 3), "power_use": 3},
			{"type": "lamp_post", "label": "Lamp Post (1x1)", "coord": Vector2i(5, 5), "power_use": 1}]


func _ready() -> void:
	await get_tree().process_frame
	var econ := FakeEconomy.new()
	add_child(econ)
	var b = BILLING.new()
	b.setup(econ)
	b.reset(1)
	var cuts: Array = []
	var expired := [false]
	b.power_cut_changed.connect(func(cut: bool) -> void: cuts.append(cut))
	b.ups_expired.connect(func() -> void: expired[0] = true)

	# Day 1: nothing to bill yet (no previous day).
	b.set_clock(1, 20 * 60 + 5)
	b.tick(1.0)
	_expect(b.bills.is_empty(), "no bill on day 1")
	# Day 2 before 20:00: still nothing; at 20:00 the day-1 bill appears.
	b.set_clock(2, 19 * 60)
	b.tick(1.0)
	_expect(b.bills.is_empty(), "no bill before issue time")
	b.set_clock(2, 20 * 60)
	b.tick(1.0)
	_expect(b.bills.size() == 1, "day 1 billed on day 2 at 20:00 (got %d)" % b.bills.size())
	var bill: Dictionary = b.bills[0] if not b.bills.is_empty() else {}
	var expected := int(round(3.0 * BILLING.KWH_PER_POWER_UNIT * BILLING.PRICE_PER_KWH)) + int(round(1.0 * BILLING.KWH_PER_POWER_UNIT * BILLING.PRICE_PER_KWH)) + BILLING.DAILY_BASE_FEE
	_expect(int(bill.get("amount", 0)) == expected, "bill amount %d (expected %d)" % [int(bill.get("amount", 0)), expected])
	_expect(int(bill.get("due_day", 0)) == 2 + BILLING.GRACE_DAYS, "due three days after issue")
	_expect(not b.power_cut_active, "grid on while the bill is not overdue")

	# Due day at issue time -> overdue -> power cut + UPS.
	b.set_clock(5, 20 * 60)
	b.tick(0.0)
	_expect(b.power_cut_active, "overdue bill cuts the grid")
	_expect(cuts.has(true), "power_cut_changed(true) emitted")
	_expect(b.ups_active, "UPS starts on the cut")

	# Round trip while cut.
	var saved: Dictionary = b.export_state()
	var b2 = BILLING.new()
	b2.setup(econ)
	b2.import_state(saved, 5, false)
	b2.set_clock(5, 20 * 60)
	_expect(b2.bills.size() == b.bills.size(), "bills survive save/load")
	_expect(b2.count_overdue() == 1, "overdue survives save/load")

	# UPS drains to game over.
	for i in int(BILLING.UPS_DURATION_SEC) + 2:
		b.tick(1.0)
	_expect(expired[0], "UPS expiry emitted after %d s" % int(BILLING.UPS_DURATION_SEC))

	# Paying restores the grid (fresh instance, the old one is "dead").
	CoreRoot.get_state().money = 10000
	b2.refresh_power_cut(true)
	var result: Dictionary = b2.pay(str(b2.bills[0]["id"])) if not b2.bills.is_empty() else {}
	_expect(bool(result.get("ok", false)), "paying succeeds with cash")
	_expect(not b2.power_cut_active, "paying restores the grid")
	_expect(CoreRoot.get_state().money == 10000 - int(result.get("amount", 0)), "payment charged")

	# Not enough cash.
	b2.set_clock(6, 20 * 60)
	b2.tick(0.0)
	CoreRoot.get_state().money = 0
	if not b2.bills.is_empty():
		var r2: Dictionary = b2.pay(str(b2.bills[0]["id"]))
		_expect(str(r2.get("reason", "")) == "insufficient_funds", "payment refused without cash")

	print("")
	if _failures.is_empty():
		print("BILLING CHECK: PASS")
		get_tree().quit(0)
	else:
		print("BILLING CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
