extends Node

## A month of a sandbox camp on the real rules, without 3D and without the nights: the
## bookings from EmailManager (as many as the free beds draw), every party accepted, let in
## and every room made up at once (a diligent warden), the guests paying through
## GuestManager, the electricity bill (scripts/electricity_billing.gd) paid the day it comes,
## and the camp built from what it earns:
##   --play=careful  beds and what the guests need (toilets, showers, the sewer, fun)
##   --play=lazy     beds and one toilet block
## Prints the money day by day: the cash at midnight, what the guests paid, the electricity,
## what was built, the beds, how full, the mood. The balance's measure (24. 11. 2026,
## Richard: "a tight start, then calm"); not a check, it asserts nothing.
##   godot --headless --path godot --audio-driver Dummy res://tools/economy_sim.tscn -- --play=careful --days=31

const BILLING = preload("res://scripts/electricity_billing.gd")
const ECONOMY = preload("res://scripts/economy_manager.gd")
const BALANCE = preload("res://core/balance/balance_config.gd")

## What the warden buys next, in order, when the cash allows (with a reserve for the bills).
## [type, footprint, beds it adds (0 = a facility), when: beds at least].
const CAREFUL := [
	["tent_2", Vector2i(1, 1), 2, 0], ["tent_2", Vector2i(1, 1), 2, 0], ["toilet_block", Vector2i(1, 1), 0, 0],
	["sewer", Vector2i(1, 1), 0, 0], ["shower_block", Vector2i(1, 1), 0, 4], ["bonfire", Vector2i(1, 1), 0, 4],
	["tent_3", Vector2i(1, 1), 3, 0], ["cabin_2", Vector2i(2, 2), 3, 0], ["playground", Vector2i(2, 2), 0, 8],
	["tent_3", Vector2i(1, 1), 3, 0], ["toilet_block", Vector2i(1, 1), 0, 12], ["cabin_2", Vector2i(2, 2), 3, 0],
	["sports_field", Vector2i(3, 2), 0, 14], ["shower_block", Vector2i(1, 1), 0, 14], ["cabin_2", Vector2i(2, 2), 3, 0],
	["lake_slide", Vector2i(2, 1), 0, 18], ["cabin_3", Vector2i(2, 2), 4, 0], ["cabin_3", Vector2i(2, 2), 4, 0],
	["toilet_block", Vector2i(1, 1), 0, 24], ["shower_block", Vector2i(1, 1), 0, 24], ["cabin_3", Vector2i(2, 2), 4, 0],
	["cabin_3", Vector2i(2, 2), 4, 0], ["ping_pong", Vector2i(1, 1), 0, 28], ["cabin_3", Vector2i(2, 2), 4, 0],
]
const LAZY := [
	["tent_3", Vector2i(1, 1), 3, 0], ["toilet_block", Vector2i(1, 1), 0, 0], ["sewer", Vector2i(1, 1), 0, 0],
]
const LAZY_REPEAT := ["tent_3", Vector2i(1, 1), 3, 0]
const RESERVE := 150

var _day := 1
var _hour := 6
var _minute := 0
var _plan: Array = []
var _next := 0
var _lazy := false
var _cursor := Vector2i(2, 2)
var _billing
var _paid_today := 0
var _power_today := 0
var _built_today: Array = []
var _beds := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var days := 31
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a == "--play=lazy":
			_lazy = true
	_plan = (LAZY if _lazy else CAREFUL).duplicate()
	seed(2411)
	var state = CoreRoot.get_state()
	state.grid.cells.clear()
	state.guests.clear()
	state.guest_reviews.clear()
	state.failures.clear()
	state.day = 1
	state.money = BALANCE.STARTING_MONEY
	GuestManager.reset_runtime_state()
	EmailManager.reset_runtime(true)
	EmailManager._rng.seed = 2411
	var econ = ECONOMY.new()
	add_child(econ)
	_billing = BILLING.new()
	_billing.setup(econ)
	_billing.reset(1)
	EventBus.guest_payment_received.connect(func(amount: int, _id: int) -> void: _paid_today += amount)
	EmailManager.sandbox_start("06:00")
	print("economy_sim: %s, %d days, start $%d" % ["lazy" if _lazy else "careful", days, state.money])
	print("day   cash  guests  power  beds  full  mood review  built")
	_buy()
	for d in days:
		for m in 24 * 60:
			_tick_minute()
		# The day's end as main._on_day_tick does it.
		EmailManager.settle_reputation()
		var beds: Dictionary = GuestManager.get_bed_metrics()
		var cap := int(beds.get("capacity", 0))
		var used := cap - int(beds.get("free", 0))
		var mood: Dictionary = GuestManager.get_camp_mood_summary()
		print("%3d %6d %7d %6d %5d %4d%% %5.0f %6.1f  %s" % [_day - 1, CoreRoot.get_state().money, _paid_today, _power_today,
			cap, int(round(100.0 * used / maxf(1.0, cap))), float(mood.get("avg_mood", 0.0)), _review_avg(),
			", ".join(_built_today)])
		_paid_today = 0
		_power_today = 0
		_built_today.clear()
	print("economy_sim: done, cash $%d" % CoreRoot.get_state().money)
	get_tree().quit()


func _tick_minute() -> void:
	_minute += 1
	if _minute >= 60:
		_minute = 0
		_hour += 1
		if _hour >= 24:
			_hour = 0
			_day += 1
			CoreRoot.get_state().day = _day
			EventBus.day_tick.emit(_day)
	EventBus.time_tick.emit(_hour, _minute)
	_billing.set_clock(_day, _hour * 60 + _minute)
	_billing.tick(0.0)
	for bill in _billing.bills.duplicate():
		var res: Dictionary = _billing.pay(str(bill.get("id", "")))
		if bool(res.get("ok", false)):
			_power_today += int(res.get("amount", 0))
	if _minute % 10 == 0 and _hour >= 7 and _hour < 22:
		_warden()
	if _minute == 0 and _hour == 8:
		_buy()


## The diligent warden: every booking taken, every party let in, every room made up.
func _warden() -> void:
	for mail in EmailManager.inbox.duplicate():
		if EmailManager.can_accept_customer_booking(mail):
			EmailManager.confirm_customer_booking(mail)
	for g_any in CoreRoot.get_state().guests:
		GuestManager.request_check_in(int((g_any as Dictionary).get("id", -1)))
	for key in GuestManager.get_accommodation_states().keys():
		var room: Dictionary = GuestManager.get_room_state(str(key))
		for t in room.get("tasks", []):
			GuestManager.complete_room_task(str(key), str(t["id"]))


## Mornings: what the plan has next, while the cash allows.
func _buy() -> void:
	while true:
		var item: Array = _plan[_next] if _next < _plan.size() else (LAZY_REPEAT if _lazy else [])
		if item.is_empty():
			return
		if _beds < int(item[3]):
			# A facility waiting on beds: buy the next beds instead.
			var j := _next + 1
			while j < _plan.size() and int(_plan[j][2]) == 0:
				j += 1
			if j >= _plan.size():
				return
			item = _plan[j]
			if not _place(item):
				return
			_plan.remove_at(j)
			continue
		if not _place(item):
			return
		_next += 1


func _place(item: Array) -> bool:
	var def = CoreRoot.registry.get_def(str(item[0]))
	if def == null or CoreRoot.get_state().money < int(def.cost) + RESERVE:
		return false
	var fp: Vector2i = item[1]
	var at := _free_spot(fp)
	if not CoreRoot.actions.place_building(str(item[0]), at, fp):
		return false
	GuestManager._life.refresh_world(CoreRoot.get_state(), CoreRoot.registry)
	_beds += int(item[2])
	_built_today.append(str(item[0]))
	return true


## Left to right in rows, a tile between things.
func _free_spot(fp: Vector2i) -> Vector2i:
	var grid = CoreRoot.get_state().grid
	while true:
		var ok := true
		for y in fp.y + 1:
			for x in fp.x + 1:
				if not grid.is_cell_free(_cursor + Vector2i(x, y)):
					ok = false
		if ok:
			var at := _cursor
			_cursor.x += fp.x + 1
			if _cursor.x > 40:
				_cursor = Vector2i(2, _cursor.y + 4)
			return at
		_cursor.x += 1
		if _cursor.x > 40:
			_cursor = Vector2i(2, _cursor.y + 4)
	return _cursor


## The guest book so far: the average of every review's stars (0 before the first).
func _review_avg() -> float:
	var reviews: Array = CoreRoot.get_state().guest_reviews
	var sum := 0.0
	for r in reviews:
		sum += float((r as Dictionary).get("rating", 0))
	return sum / reviews.size() if not reviews.is_empty() else 0.0
