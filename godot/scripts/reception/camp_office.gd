extends Node

## The camp side of the office (the room side is scripts/reception/reception_extras.gd):
##   - sleeping: only at night, and only while nothing is out there; the night then
##     passes quickly in the dark (the clock stepped in quarter hours, so the night's
##     jobs, the dawn and the bills all still happen in order) until 06:30. In co-op
##     only when both wardens are in bed: you lie awake till the other lies down too, the
##     host's machine passes the night, and either getting up stops it;
##   - the phone: what the camp looks like to whoever you ring (phone_book.gd ctx) and
##     what a call sets going: the electrician (scripts/reception/electrician_visit.gd);
##   - the shed key from the noticeboard (the generator shed's back room).
## Saved with the game (export_state / import_state).

const ELECTRICIAN_VISIT = preload("res://scripts/reception/electrician_visit.gd")
const BOOK = preload("res://scripts/closeup/phone_book.gd")
const WAKE_HOUR := 6.5
## Hours of game time passed per real second while you sleep.
const SLEEP_RATE := 9.0

## The shed key is off the noticeboard (in a bag, scripts/ui/inventory.gd, or on the ground).
var has_shed_key := false
## Times you have been down the sewer (scripts/pipes/pipe_director.gd: what you meet).
var pipe_visits := 0
## The junk shoved away from the generator shed's back door (scripts/shed/generator_shed.gd).
var shed_moved: Array = []
var electrician                      # electrician_visit.gd, or null
var _main: Node
var _sleep_left := 0.0               # hours still to pass
## In bed (lying down, asleep, or awake waiting for the other warden).
var _in_bed := false
## The night has begun to pass since you lay down (the host's machine passes it; the
## other one sees it in the host's clock, coop_clock "sl").
var _night_started := false


func setup(main_node: Node) -> void:
	_main = main_node


func reset() -> void:
	has_shed_key = false
	pipe_visits = 0
	shed_moved = []
	_sleep_left = 0.0
	_in_bed = false
	_night_started = false
	if electrician != null and is_instance_valid(electrician):
		electrician.queue_free()
	electrician = null


func _process(delta: float) -> void:
	_coop_bed()
	if _sleep_left > 0.0:
		var step := minf(_sleep_left, delta * SLEEP_RATE)
		_sleep_left -= step
		var ts = _main.get("time_system")
		if ts != null:
			ts.step_time_hours(step)
			_main._sync_runtime_state_from_systems(false)
		if _sleep_left <= 0.0001:
			_sleep_left = 0.0
			if ts != null:
				ts.set_time_hours(WAKE_HOUR)
			_main._sync_runtime_state_from_systems(true)
			_in_bed = false
			var night = _main.get("_coop_night")
			if night != null and night.has_method("slept"):
				night.slept()


# ── sleep ─────────────────────────────────────────────────────────────────────

func _hour() -> float:
	return float(_main.get("_time_of_day_hours")) if _main != null else 12.0


## From the evening on a bed is for lying down in; by day it is only furniture (a lodging's
## bed took the click meant for the tent's upgrade catalog).
func bedtime() -> bool:
	var h := _hour()
	return h >= 18.0 or h < WAKE_HOUR - 0.25


## "" when you may sleep, otherwise what goes through your head instead.
func sleep_refusal() -> String:
	var h := _hour()
	var night := h >= 20.0 or h < WAKE_HOUR - 0.25
	if not night:
		if h >= 18.0:
			return "Not yet. The camp isn't shut for the night."
		return "In broad daylight? The camp won't run itself."
	var brains = _main.get("_enemy_brains")
	if brains is Array and not (brains as Array).is_empty():
		return "You lie down and get straight back up. Something is out there tonight."
	return ""


## You lie down (the bed): in co-op the other machine hears of it (coop_local_warden "z").
func lie_down() -> void:
	_in_bed = true
	_night_started = false


func in_bed() -> bool:
	return _in_bed


## Your eyes may close: alone, at once; in co-op once the other warden is in bed too.
func may_sleep() -> bool:
	return not Coop.has_partner() or _partner_in_bed()


func start_sleep() -> void:
	if not _in_bed:
		lie_down()
	# Co-op: the host's machine passes the night once both are in bed (_coop_bed); the
	# other machine waits for the host's clock to do it.
	if Coop.has_partner():
		return
	_pass_night()


func _pass_night() -> void:
	_night_started = true
	var h := _hour()
	_sleep_left = (WAKE_HOUR - h) if h < WAKE_HOUR else (24.0 - h + WAKE_HOUR)
	_sleep_left = maxf(0.0, _sleep_left)


## The night is passing on this machine (the host's clock tells the other one).
func is_fast_forwarding() -> bool:
	return _sleep_left > 0.0


func is_sleeping_through() -> bool:
	if not _in_bed:
		return _sleep_left > 0.0
	return _sleep_left > 0.0 or not _night_started


func _partner_in_bed() -> bool:
	return bool(Coop.partner_state.get("z", false))


## Co-op, each frame: the host starts the night once both lie down and stops it if
## either gets up; the other machine follows the host's clock to the morning.
func _coop_bed() -> void:
	if not _in_bed or not Coop.has_partner():
		return
	if Coop.is_client():
		var host_passing := bool(Coop.last_clock.get("sl", false))
		if host_passing:
			_night_started = true
		elif _night_started:
			_in_bed = false
		return
	if not _night_started and _sleep_left <= 0.0 and _partner_in_bed() and _sleeping_eyes():
		_pass_night()
	elif _sleep_left > 0.0 and not _partner_in_bed():
		_sleep_left = 0.0
		_in_bed = false
		_main._sync_runtime_state_from_systems(true)


## Lying with the eyes shut (the sleep in the back room is past its blinks, or the
## motel's dark), not just lying there.
func _sleeping_eyes() -> bool:
	var ext = _main.get("_interior_manager")
	var bi = ext.get("_building_interior") if ext != null else null
	var extras = bi.get("_extras") if bi != null else null
	var seq = extras.get("sleep") if extras != null else null
	if seq != null and seq.has_method("eyes_shut") and seq.is_running():
		return seq.eyes_shut()
	return true


## Co-op: up again before the night was through (a key in the dark): it stops for both.
func get_up() -> void:
	if not Coop.has_partner():
		return
	_in_bed = false
	if _sleep_left > 0.0:
		_sleep_left = 0.0
		_main._sync_runtime_state_from_systems(true)


func clock_text() -> String:
	var h := _hour()
	return "%02d:%02d" % [int(h) % 24, int((h - floor(h)) * 60.0)]


func on_woke() -> void:
	var slept := _night_started
	_in_bed = false
	_night_started = false
	if not slept:
		return
	say("Morning. You slept through it.")
	if _main.has_method("request_manual_save"):
		_main.call_deferred("_write_autosave", "autosave")


func say(text: String, kind := 1) -> void:
	var hud = _main.get("_hud_manager") if _main != null else null
	if hud != null:
		hud.push_status(text, kind)


# ── the phone ────────────────────────────────────────────────────────────────

func phone_context() -> Dictionary:
	var jobs = _main.get("_night_jobs")
	var fault := false
	if jobs != null:
		fault = bool(jobs.breaker_tripped) or int(jobs.dead_circuit) >= 0
	var ledger = _main.get("_week_ledger")
	var hunted := false
	var brains = _main.get("_enemy_brains")
	if brains is Array:
		for b in brains:
			if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "stalker":
				hunted = true
	return {
		"hour": _hour(),
		"day": int(_main.get("_day_index")),
		"power_fault": fault,
		"electrician_coming": electrician != null and is_instance_valid(electrician),
		"hunted": hunted,
		"nights_visited": ledger.nights_visited() if ledger != null and ledger.has_method("nights_visited") else 0,
	}


func on_phone_effect(effect: String, _number: String) -> void:
	# Co-op: whoever you ring comes to the host's camp.
	if Coop.is_client():
		Coop.send_request("phone", [effect, _number])
		return
	if effect == "electrician" and (electrician == null or not is_instance_valid(electrician)):
		var night := BOOK.is_night(_hour())
		electrician = ELECTRICIAN_VISIT.new()
		electrician.name = "ElectricianVisit"
		add_child(electrician)
		electrician.begin(_main, night, 0.0)
		electrician.finished.connect(func(): electrician = null)


# ── the shed key ─────────────────────────────────────────────────────────────

## Whether the key is off the board (a method: reception_extras reaches the office only
## through calls, and reading the variable that way always said "on the board").
func shed_key_out() -> bool:
	return has_shed_key


func take_shed_key() -> void:
	if Coop.is_client():
		Coop.send_request("shed_key", [])
	has_shed_key = true


## Hung back on the board (out of a bag: scripts/ui/inventory.gd).
func return_shed_key() -> void:
	if Coop.is_client():
		Coop.send_inv("key_back", [])
	has_shed_key = false


func export_state() -> Dictionary:
	var out := {"has_shed_key": has_shed_key, "pipe_visits": pipe_visits, "shed_moved": shed_moved.duplicate()}
	if electrician != null and is_instance_valid(electrician):
		out["electrician"] = electrician.export_state()
	return out


func import_state(data: Dictionary) -> void:
	reset()
	has_shed_key = bool(data.get("has_shed_key", false))
	pipe_visits = int(data.get("pipe_visits", 0))
	var moved = data.get("shed_moved", [])
	shed_moved = (moved as Array).duplicate() if moved is Array else []
	var e = data.get("electrician", null)
	if e is Dictionary:
		electrician = ELECTRICIAN_VISIT.new()
		electrician.name = "ElectricianVisit"
		add_child(electrician)
		electrician.import_state(_main, e)
		electrician.finished.connect(func(): electrician = null)
