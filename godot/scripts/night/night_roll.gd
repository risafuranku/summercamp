extends RefCounted

## The night's roll (out of main.gd 15. 11.): the NIGHT RISK forecast from the guests
## (GuestManager.get_liminal_forecast_data, its lamps capped by the fear: night_swell), the
## roll when the night starts (each kind's guaranteed things and its chance), then the
## things themselves: the fear moves toward what the guests are like tonight and shapes
## what comes (night_swell.shape), a brain started for each (main._enemy_brains: the
## guest of that kind who turned, the difficulty from the camp and the nights before, up
## to three Silent Men, the Antlered Man on a packed camp or three kinds at once), out
## one after another as the night goes on. At dawn the guests whose turned self got you
## are gone. The first night is quiet; a sandbox camp can have them all quiet. The
## brains' lines are kept for the log only (on_enemy_notice): no text tells you what is
## out there. The forecast window (scripts/debug/liminal_window.gd) reads this state.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const NIGHT_SWELL = preload("res://core/systems/night_swell.gd")
## The boss night: three kinds turned at once, or a camp this full.
const ANTLERED_GUESTS := 16
## Silent Men at once at most (one for each Quiet Guy turned).
const SILENT_MEN_MAX := 3

var main: Node
var rng := RandomNumberGenerator.new()
## The forecast as the HUD has it, and its lamps (0..4).
var forecast: Dictionary = {}
var hud_level := 0
## The last night's roll, the last eight, how many rolled things have no brain yet.
var roll_snapshot: Dictionary = {}
var spawn_history: Array[Dictionary] = []
var virtual_count := 0
var last_despawn_day := 0
var last_despawn_count := 0
## The night rolled last (a night is rolled once), what came of it.
var last_rolled_night_id := -99999
var spawned_this_night := 0
var last_night_kinds: Array = []
## Guests the night has taken since the fear last moved; the night it last moved.
var night_lost := 0
var swell_moved := -1
var last_enemy_line := ""


func _init(main_node: Node) -> void:
	main = main_node
	rng.randomize()


## A new camp, the title: no forecast, no roll, nothing out.
func reset() -> void:
	forecast.clear()
	hud_level = 0
	roll_snapshot.clear()
	spawn_history.clear()
	virtual_count = 0
	last_despawn_day = 0
	last_despawn_count = 0
	last_rolled_night_id = -99999
	spawned_this_night = 0


func sync_forecast(force: bool = false) -> void:
	if GuestManager == null or not GuestManager.has_method("get_liminal_forecast_data") or not main.camp_rule("threats"):
		if force or not forecast.is_empty():
			forecast.clear()
			hud_level = 0
			if main._hud_manager != null and main._hud_manager.has_method("set_liminal_forecast_count"):
				main._hud_manager.set_liminal_forecast_count(0)
			main._refresh_liminal_debug_window()
		return

	var payload_any = GuestManager.call("get_liminal_forecast_data")
	if not (payload_any is Dictionary):
		return
	var payload: Dictionary = payload_any
	var hud_level := clampi(int(payload.get("hud_level", 0)), 0, 4)
	var lamps := _lamps(payload, hud_level)
	if lamps != hud_level:
		hud_level = lamps
		payload = payload.duplicate(true)
		payload["hud_level"] = lamps
	if not force and payload == forecast and hud_level == hud_level:
		return

	forecast = payload.duplicate(true)
	hud_level = hud_level
	if main._hud_manager != null and main._hud_manager.has_method("set_liminal_forecast"):
		main._hud_manager.set_liminal_forecast(payload)
	elif main._hud_manager != null and main._hud_manager.has_method("set_liminal_forecast_count"):
		main._hud_manager.set_liminal_forecast_count(hud_level)
	main._refresh_liminal_debug_window()


## The NIGHT RISK lamps say what the night may have (night_swell): somebody in the camp to turn,
## a lamp; no more of them than the fear will have got to tonight.
func _lamps(forecast: Dictionary, level: int) -> int:
	var kinds := kinds_in_camp(forecast.get("archetypes", []))
	if level == 0 and kinds > 0 and main._day_index > main.QUIET_NIGHTS:
		return 1
	if level <= 1 or not main.camp_rule("threats"):
		return level
	return mini(level, NIGHT_SWELL.lamps_cap(NIGHT_SWELL.next(float(CoreRoot.get_state().night_swell), guests_reading(kinds))))


## How many kinds of guest are in the camp, in the forecast's rows or the roll's.
func kinds_in_camp(rows: Array) -> int:
	var kinds := 0
	for e in rows:
		if e is Dictionary and int((e as Dictionary).get("count", (e as Dictionary).get("guest_count", 0))) > 0:
			kinds += 1
	return kinds


## What the guests are like tonight, for the fear to move toward (night_swell.reading).
func guests_reading(kinds: int) -> float:
	var mood: Dictionary = GuestManager.get_camp_mood_summary() if GuestManager != null and GuestManager.has_method("get_camp_mood_summary") else {}
	return NIGHT_SWELL.reading(int(mood.get("guests", 0)), int(mood.get("unhappy", 0)), kinds, night_lost)


## A camp loaded in the dark: the night goes on. What starts it is the clock passing 20:00
## (time_system), and a save comes back at night already: no tick, nothing out there till
## morning and a death undone for free. After midnight it is still yesterday's night.
func resume_after_load() -> void:
	if CoreRoot.is_night():
		on_night_tick(main._day_index if main._time_of_day_hours >= 12.0 else main._day_index - 1)


func on_night_tick(night_index: int) -> void:
	if not main._gameplay_started or main._menu_mode or main._game_over_active or not INSTANCE.coop(main).sim_here():
		return
	if night_index == last_rolled_night_id:
		return
	sync_forecast(true)
	roll(night_index)
	activate(night_index)
	if main._director != null:
		main._director.begin_night(night_index)
	main._refresh_liminal_debug_window()


func roll(night_index: int) -> void:
	var forecast: Dictionary = forecast.duplicate(true)
	if forecast.is_empty():
		sync_forecast(true)
		forecast = forecast.duplicate(true)

	var totals_any = forecast.get("totals", {})
	var totals: Dictionary = totals_any if totals_any is Dictionary else {}
	var entries_any = forecast.get("archetypes", [])
	var entries: Array = entries_any if entries_any is Array else []
	var rolled_entries: Array[Dictionary] = []
	var total_spawned := 0
	var total_guaranteed := 0
	var total_chance_spawns := 0
	var total_chance_checks := 0

	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var guaranteed = max(0, int(entry.get("guaranteed_spawns", 0)))
		var chance_probability = clampf(float(entry.get("chance_probability", 0.0)), 0.0, 1.0)
		var chance_roll := -1.0
		var chance_success := false
		var chance_spawn := 0
		if chance_probability > 0.0001:
			total_chance_checks += 1
			chance_roll = rng.randf()
			chance_success = chance_roll <= chance_probability
			chance_spawn = 1 if chance_success else 0
			if chance_success:
				total_chance_spawns += 1
		var spawned = guaranteed + chance_spawn
		total_spawned += spawned
		total_guaranteed += guaranteed
		rolled_entries.append({
			"archetype": str(entry.get("archetype", "")),
			"label": str(entry.get("label", "Unknown")),
			"guest_count": int(entry.get("count", 0)),
			"expected_spawns": float(entry.get("expected_spawns", 0.0)),
			"chance_tier": str(entry.get("chance_tier", "none")),
			"chance_probability": chance_probability,
			"chance_roll": chance_roll,
			"chance_success": chance_success,
			"guaranteed_spawns": guaranteed,
			"spawned": spawned,
		})

	roll_snapshot = {
		"night_id": night_index,
		"rolled_day": main._day_index,
		"rolled_time": main._time_of_day_string(),
		"expected_total": float(totals.get("expected_spawns", 0.0)),
		"spawned_total": total_spawned,
		"spawned_guaranteed": total_guaranteed,
		"spawned_from_chance": total_chance_spawns,
		"chance_checks": total_chance_checks,
		"entries": rolled_entries,
	}
	virtual_count += total_spawned
	last_rolled_night_id = night_index
	spawn_history.append(roll_snapshot.duplicate(true))
	while spawn_history.size() > 8:
		spawn_history.remove_at(0)


func activate(night_index: int) -> void:
	main._stop_active_enemy_brain()
	# The first night is quiet: nobody has been in the camp long enough to bring anything
	# with them. You read the mail, plan tomorrow and go to bed (DESIGN §3). A sandbox
	# camp can have every night quiet.
	if night_index <= main.QUIET_NIGHTS or not main.camp_rule("threats"):
		spawned_this_night = 0
		return
	var entries_any = roll_snapshot.get("entries", [])
	var rolled: Array = entries_any if entries_any is Array else []
	# The fear in the camp moves on toward what the guests are like tonight, and it says what the
	# night may have of what they bring (the nights follow on: night_swell.gd). Once a night.
	var swell := float(CoreRoot.get_state().night_swell)
	if night_index != swell_moved:
		swell_moved = night_index
		swell = NIGHT_SWELL.next(swell, guests_reading(kinds_in_camp(rolled)))
		CoreRoot.actions.set_night_swell(swell)
		night_lost = 0
	var entries: Array = NIGHT_SWELL.shape(rolled, swell, last_night_kinds, main.ENEMY_FOR_ARCHETYPE, rng.randf())
	var came: Array = []
	var total_spawned := 0
	var kinds := 0
	var worst := 1
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var spawned := int(entry.get("spawned", 0))
		var script = main.ENEMY_FOR_ARCHETYPE.get(str(entry.get("archetype", "")), null)
		if spawned <= 0 or script == null:
			continue
		var difficulty: int = mini(maxi(maxi(_silent_man_difficulty(entry), _difficulty_floor()), NIGHT_SWELL.difficulty_floor(swell)), NIGHT_SWELL.difficulty_cap(swell))
		worst = maxi(worst, difficulty)
		came.append(str(entry.get("archetype", "")))
		var turned := entry.duplicate()
		turned["guest"] = pick_turned_guest(str(entry.get("archetype", "")))
		start_brain(script, night_index, difficulty, turned)
		# More Quiet Guys turned, more Silent Men (playtest 25. 10.: "more of them = you have
		# to choose whom to light"), each one of them, up to three.
		if script == main.SILENT_MAN_BRAIN_SCRIPT and spawned >= 2:
			var taken: Array = [int((turned["guest"] as Dictionary).get("id", -1))]
			for nth in range(1, mini(mini(spawned, SILENT_MEN_MAX), NIGHT_SWELL.silent_cap(swell))):
				var more := entry.duplicate()
				more["nth"] = nth
				more["guest"] = pick_turned_guest(str(entry.get("archetype", "")), taken)
				taken.append(int((more["guest"] as Dictionary).get("id", -1)))
				start_brain(script, night_index, difficulty, more)
		total_spawned += spawned
		kinds += 1
	if swell >= NIGHT_SWELL.ANTLERED_FROM and _antlered_comes(kinds):
		start_brain(main.STALKER_BRAIN_SCRIPT, night_index, mini(5, worst + 1), {})
	# Nobody comes out at dusk, one after the other as the night goes on (night_swell.arrival).
	var out_in_turn: Array = main._enemy_brains.duplicate()
	for i in out_in_turn.size():
		var at: int = i + rng.randi_range(0, out_in_turn.size() - 1 - i)
		var who = out_in_turn[at]
		out_in_turn[at] = out_in_turn[i]
		out_in_turn[i] = who
		if who.has_method("hold_until"):
			who.hold_until(NIGHT_SWELL.arrival(swell, i, rng.randf()))
	last_night_kinds = came
	spawned_this_night = total_spawned
	var claimed_virtual = mini(total_spawned, virtual_count)
	virtual_count = maxi(0, virtual_count - claimed_virtual)


func _antlered_comes(kinds_turned: int) -> bool:
	if kinds_turned >= 3:
		return true
	var guests := 0
	for g in CoreRoot.get_state().guests:
		if g is Dictionary and str((g as Dictionary).get("status", "")) in ["active", "sleep"]:
			guests += 1
	return kinds_turned >= 1 and guests >= ANTLERED_GUESTS


## The guest of `archetype` who turns tonight: one of them in the camp, by chance
## ({id, name}; empty when none is there, as in a debug spawn).
func pick_turned_guest(archetype: String, not_these: Array = []) -> Dictionary:
	var pool: Array = []
	for g in CoreRoot.get_state().guests:
		if not (g is Dictionary) or not_these.has(int((g as Dictionary).get("id", -1))):
			continue
		if str((g as Dictionary).get("archetype", "")) == archetype and str((g as Dictionary).get("status", "")) in ["active", "sleep"]:
			pool.append(g)
	if pool.is_empty():
		return {}
	var g: Dictionary = pool[rng.randi() % pool.size()]
	return {"id": int(g.get("id", -1)), "name": str(g.get("name", ""))}


## Dawn: every guest whose turned self got you in the night is gone (their things go to
## the lost and found, their bed was not slept in).
func claim_turned_guests() -> void:
	_claim_rings()
	for brain in main._enemy_brains:
		if brain == null or brain.get("claimed") != true:
			continue
		var entry = brain.get("_night_entry")
		var guest: Dictionary = (entry as Dictionary).get("guest", {}) if entry is Dictionary else {}
		var id := int(guest.get("id", -1))
		if id < 0:
			continue
		if GuestManager.vanish_guest(id):
			night_lost += 1
			if main._hud_manager != null:
				main._hud_manager.push_status("Morning: %s is gone. The bed was not slept in." % str(guest.get("name", "a guest")), 2)


## Dawn: the mushroom granny's night (basket_brain.gd dawn()): those who lived through her
## leave, their relatives write, and the morning says who is gone.
func _claim_rings() -> void:
	for brain in main._enemy_brains:
		if brain == null or not brain.has_method("dawn"):
			continue
		for line in brain.dawn():
			if main._hud_manager != null:
				main._hud_manager.push_status(str(line), 2)


## What has come before comes back harder: every third night something came for the
## camp raises the floor (state, not the calendar).
func _difficulty_floor() -> int:
	var visited: int = main._week_ledger.nights_visited() if main._week_ledger != null else 0
	return clampi(1 + visited / 3, 1, 3)


func _silent_man_difficulty(entry: Dictionary) -> int:
	var guest_count = max(0, int(entry.get("guest_count", 0)))
	var chance_tier = str(entry.get("chance_tier", "none"))
	var spawned = max(0, int(entry.get("spawned", 0)))
	var difficulty := 1
	if guest_count >= 24:
		difficulty = 5
	elif guest_count >= 18:
		difficulty = 4
	elif guest_count >= 12:
		difficulty = 3
	elif guest_count >= 6:
		difficulty = 2
	if chance_tier == "medium":
		difficulty = maxi(difficulty, 3)
	elif chance_tier == "large":
		difficulty = maxi(difficulty, 4)
	if spawned >= 2:
		difficulty = mini(5, difficulty + 1)
	return clampi(difficulty, 1, 5)


func start_brain(script: Script, night_index: int, difficulty: int, night_entry: Dictionary) -> void:
	var brain = script.new()
	if brain == null:
		return
	var seed = int(rng.randi()) ^ (night_index * 7919) ^ (main._day_index * 104729) ^ int(Time.get_ticks_msec()) ^ main._enemy_brains.size()
	var refs := {
		"world_root": main._world_3d,
		"player": main._player,
		"grid_manager": main.grid_manager,
		"building_manager": main.building_manager,
		"audio_manager": main._audio_manager,
		"damage_callable": Callable(main, "damage_player"),
		"is_night_callable": Callable(main, "_is_enemy_night_active"),
		"hour_callable": Callable(main, "_enemy_hour"),
		"allow_actions_callable": Callable(main, "_can_enemy_runtime_actions"),
		"notify_callable": Callable(self, "on_enemy_notice"),
		"night_entry": night_entry.duplicate(true),
	}
	if brain.has_method("start_night"):
		brain.start_night(seed, difficulty, refs)
	main._enemy_brains.append(brain)
	main._prewarm_hurt()
	if main._week_ledger != null and brain.has_method("get_enemy_id"):
		main._week_ledger.note_enemy(str(brain.get_enemy_id()), night_index)
	if main._active_enemy_brain == null:
		main._active_enemy_brain = brain
		main._active_enemy_brain_id = str(brain.get_enemy_id()) if brain.has_method("get_enemy_id") else "?"


## An enemy's first sign of the night, as one feed line.
## The night things' lines (enemy_base._announce/_feed) are not shown: no text tells
## you what is out there or what just happened (Richard, 20. 10.: it kills the vibe).
## The sounds, the eyes and the sixth sense say it. Kept for the log only.


func on_enemy_notice(text: String) -> void:
	last_enemy_line = text
