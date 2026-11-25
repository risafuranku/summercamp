extends RefCounted

## A camp as a save holds it, both ways (out of main.gd 15. 11.; the file format is
## main.SAVE_VERSION's, written by SaveManager): build() takes the camp as it stands (the
## state, the clock and the weather, the grid with its buildings, trees and seed, the mode
## and its rules, the office PC's desktop, the mail's and the guests' own state, every
## system's export_state, the player) and apply() puts a camp back from one: the world
## regenerated from its seed with the saved tiles and buildings on it, the state, the
## systems' states (those not made yet are kept as main._pending_* until they are), the
## mail and the guests. preview_only: the title's look at a camp, not a game going on.
## reset_for_new_game(): every system and the state as a camp starts, before a new one.

const INSTANCE = preload("res://scripts/instance/instance.gd")
var main: Node


func _init(main_node: Node) -> void:
	main = main_node


func build(slot_name: String, kind: String) -> Dictionary:
	var state = INSTANCE.core(main).get_state()
	if state == null or state.grid == null:
		return {}
	main._structures.sync_guest_counts()

	var tile_types: Array[Dictionary] = []
	for key_any in state.grid.tile_types.keys():
		if not (key_any is Vector2i):
			continue
		var coord := key_any as Vector2i
		tile_types.append({
			"x": coord.x,
			"y": coord.y,
			"type": int(state.grid.tile_types[key_any])
		})

	var buildings := _structures()
	var crt_desktop_state := _crt_desktop()
	var email_runtime_state := _email_runtime()
	var guest_runtime_state := _guest_runtime()
	var snapshot := {
		"save_version": main.SAVE_VERSION,
		"meta": {
			"slot_name": slot_name,
			"kind": kind,
			"created_unix": int(Time.get_unix_time_from_system()),
			"camp_name": main.camp_name(),
		},
		"state": {
			"money": int(state.money),
			"day": int(state.day),
			"is_night": bool(state.is_night),
			"karma": float(state.karma),
			"satisfaction": float(state.satisfaction),
			"hrotfaktor": float(state.hrotfaktor),
			"night_swell": float(state.night_swell),
			"last_night_kinds": main._night_roll.last_night_kinds.duplicate(),
			"night_lost": main._night_roll.night_lost,
			"night_swell_moved": main._night_roll.swell_moved,
			"energy_load": float(state.energy_load),
			"infra_load": float(state.infra_load),
			"guests": main.SAVE_CODEC.serialize_guests(state.guests),
			"accommodation_states": main.SAVE_CODEC.serialize_accommodation_states(state.accommodation_states),
			"failures": main.SAVE_CODEC.serialize_failures(state.failures),
			"guest_reviews": main.SAVE_CODEC.duplicate_dict_array(state.guest_reviews),
			"guest_transactions": main.SAVE_CODEC.duplicate_dict_array(state.guest_transactions),
			"next_guest_id": max(1, int(state.next_guest_id)),
			"biz": (state.biz as Dictionary).duplicate(true),
			"sites": (state.sites as Dictionary).duplicate(true),
			"lost_guests": main.SAVE_CODEC.duplicate_dict_array(state.lost_guests),
			"electricity": main._billing.export_state()
		},
		"runtime": {
			"time_of_day_hours": main._time_of_day_hours,
			"time_state": main._time_state,
			"weather_state": main._weather_state,
			"day_index": main._day_index
		},
		"grid": {
			"width": int(state.grid.grid_width),
			"height": int(state.grid.grid_height),
			"tile_size": float(state.grid.tile_size),
			"tile_types": tile_types,
			"buildings": buildings,
			"seed": main.world_generator.world_seed if main.world_generator != null else 0,
			"nature": main.world_generator.nature_snapshot() if main.world_generator != null and main.world_generator.has_method("nature_snapshot") else []
		},
		"mode": "sandbox" if main._sandbox else "campaign",
		"rules": main._camp_rules.duplicate(),
		"coop": INSTANCE.coop(main).is_host(),
		"crt_desktop": crt_desktop_state,
		"email_runtime": email_runtime_state,
		"guest_runtime": guest_runtime_state,
		"quests": main._quest_manager.export_state() if main._quest_manager != null else {},
		"night_jobs": main._night_jobs.export_state() if main._night_jobs != null else {},
		"day_events": main._day_events.export_state() if main._day_events != null else {},
		"week_ledger": main._week_ledger.export_state() if main._week_ledger != null else {},
		"omens": main._omens.export_state() if main._omens != null else {},
		"director": main._director.export_state() if main._director != null else {},
		"bazaar": main._bazaar.export_state(),
		"goggle": main._goggle.export_state(),
		"graph": main._day_graph.export_state(),
		"ruined_cabin": main._ruin.key,
		"camp_office": main.camp_office.export_state() if main.camp_office != null else {},
		"town_trip": main._interior_manager.town_trip().export_state() if main._interior_manager != null and main._interior_manager.has_method("town_trip") and main._interior_manager.town_trip() != null else {},
	}
	if main._player != null and is_instance_valid(main._player):
		snapshot["player"] = {
			"position": {
				"x": main._player.global_position.x,
				"y": main._player.global_position.y,
				"z": main._player.global_position.z
			},
			"yaw": main._player.rotation.y,
			"health": main._player_health
		}
	return snapshot


func _crt_desktop() -> Dictionary:
	var captured: Dictionary = {}
	if main._interior_manager != null and main._interior_manager.has_method("export_crt_desktop_state"):
		var data_any = main._interior_manager.export_crt_desktop_state()
		if data_any is Dictionary:
			captured = (data_any as Dictionary).duplicate(true)
	if captured.is_empty():
		if not main._pending_loaded_crt_state.is_empty():
			captured = main._pending_loaded_crt_state.duplicate(true)
		elif not main._last_known_crt_desktop_state.is_empty():
			captured = main._last_known_crt_desktop_state.duplicate(true)
	if not captured.is_empty():
		main._last_known_crt_desktop_state = captured.duplicate(true)
	return captured


func _email_runtime() -> Dictionary:
	if EmailManager == null or not INSTANCE.mail(main).has_method("export_runtime_state"):
		return {}
	var data_any = INSTANCE.mail(main).export_runtime_state()
	if data_any is Dictionary:
		return (data_any as Dictionary).duplicate(true)
	return {}


func _guest_runtime() -> Dictionary:
	if GuestManager == null or not INSTANCE.guests(main).has_method("export_runtime_state"):
		return {}
	var data_any = INSTANCE.guests(main).export_runtime_state()
	if data_any is Dictionary:
		return (data_any as Dictionary).duplicate(true)
	return {}


func _structures() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if main.building_manager == null:
		return out
	var structures_root: Node = main.building_manager.get_node_or_null("Structures")
	if structures_root == null:
		return out
	for child in structures_root.get_children():
		var structure := child as Node3D
		if structure == null:
			continue
		var building_id := str(structure.get_meta("building_type", "")).strip_edges()
		if building_id.is_empty():
			continue
		# A lamp or a bench standing on a path is saved too: loaded after its path (the
		# sort in apply), it goes back onto it. Left out, every lamp on a
		# path was gone after a load (found 1. 11. with the benches on paths).
		var origin_any = structure.get_meta("grid_origin", Vector2i.ZERO)
		var footprint_any = structure.get_meta("grid_footprint", Vector2i.ONE)
		var origin := origin_any as Vector2i if origin_any is Vector2i else Vector2i.ZERO
		var footprint := footprint_any as Vector2i if footprint_any is Vector2i else Vector2i.ONE
		out.append({
			"building_id": building_id,
			"origin": {"x": origin.x, "y": origin.y},
			"footprint": {"x": footprint.x, "y": footprint.y},
			"rotation": int(structure.get_meta("build_rotation", 0)),
			"condition": float(structure.get_meta("condition", 1.0)),
			"is_permanent": bool(structure.get_meta("is_permanent", false))
		})
	return out


func apply(snapshot: Dictionary, preview_only: bool) -> bool:
	if snapshot.is_empty():
		return false
	if not preview_only:
		main._test_night = ""
	var grid_data_any = snapshot.get("grid", {})
	if not (grid_data_any is Dictionary):
		return false
	var grid_data := grid_data_any as Dictionary
	var width: int = max(6, int(grid_data.get("width", 28)))
	var height: int = max(6, int(grid_data.get("height", 28)))
	var tile_size: float = maxf(0.5, float(grid_data.get("tile_size", 4.0)))

	if main.grid_manager == null or main.building_manager == null or main.world_generator == null:
		return false
	main.grid_manager.initialize_grid(Vector2i(width, height), tile_size)
	main.building_manager.setup(main.grid_manager)
	main.world_generator.setup(main.grid_manager, main.building_manager)
	# The camp's own seed: the same lake, fences, corn and horizon as when it was saved
	# (and as on the host's machine in co-op). Old saves have none: a new one is drawn.
	main.world_generator.world_seed = int(grid_data.get("seed", 0))
	# The host's camp's name before the board by the gate is built with it: it was read after,
	# the board had the name of this machine's own last camp and kept it (the user 7. 11.).
	var host_meta = snapshot.get("meta", {})
	if not preview_only and host_meta is Dictionary and INSTANCE.coop(main).is_client():
		main._coop_camp_name = str((host_meta as Dictionary).get("camp_name", ""))
	if main.world_generator.has_method("generate_base_world"):
		main.world_generator.generate_base_world(false, false)
	else:
		main._generate_grid_world()

	var state = INSTANCE.core(main).get_state()
	if state == null or state.grid == null:
		return false
	state.grid.cells.clear()
	state.grid.tile_types.clear()
	state.grid.occupants.clear()

	main.grid_manager.reset_tiles(main.grid_manager.TILE_GRASS)
	var tile_types_any = grid_data.get("tile_types", [])
	if tile_types_any is Array:
		for entry_any in tile_types_any:
			if not (entry_any is Dictionary):
				continue
			var entry := entry_any as Dictionary
			var coord := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
			if not main.grid_manager.is_in_bounds(coord):
				continue
			main.grid_manager.set_tile_type(coord, int(entry.get("type", 0)))

	var buildings_any = grid_data.get("buildings", [])
	var buildings: Array = []
	if buildings_any is Array:
		buildings = (buildings_any as Array).duplicate()
	buildings.sort_custom(func(a: Variant, b: Variant) -> bool:
		var aa := a as Dictionary
		var bb := b as Dictionary
		var aid := str(aa.get("building_id", ""))
		var bid := str(bb.get("building_id", ""))
		if aid == "main_building" and bid != "main_building":
			return true
		if aid != "main_building" and bid == "main_building":
			return false
		# Paths before lamps and benches: one saved on a path needs its path first.
		if aid == "path" and bid in ["lamp_post", "bench"]:
			return true
		if aid in ["lamp_post", "bench"] and bid == "path":
			return false
		return aid < bid
	)

	# The sites going up (construction_rules) before their structures: each one's picture
	# reads what it will be.
	var state_any = snapshot.get("state", {})
	var sites_any = (state_any as Dictionary).get("sites", {}) if state_any is Dictionary else {}
	state.sites = (sites_any as Dictionary).duplicate(true) if sites_any is Dictionary else {}
	for entry_any in buildings:
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var building_id := str(entry.get("building_id", "")).strip_edges()
		if building_id.is_empty():
			continue
		var origin_dict_any = entry.get("origin", {})
		var origin_dict := origin_dict_any as Dictionary if origin_dict_any is Dictionary else {}
		var origin := Vector2i(int(origin_dict.get("x", 0)), int(origin_dict.get("y", 0)))
		var rotation := int(entry.get("rotation", 0))
		if building_id == main.building_manager.CONSTRUCTION.TYPE:
			var fp_any = entry.get("footprint", {})
			var fp_d := fp_any as Dictionary if fp_any is Dictionary else {}
			main.building_manager.place_site_at(origin, Vector2i(int(fp_d.get("x", 1)), int(fp_d.get("y", 1))), rotation)
			continue
		main.building_manager.place_building_at_visual_only(origin, building_id, rotation)
		var root: Node3D = main._structures.root_at(origin)
		if root == null:
			continue
		var condition := clampf(float(entry.get("condition", 1.0)), 0.0, 1.0)
		if main.building_manager.has_method("set_structure_condition"):
			main.building_manager.set_structure_condition(root, condition)
		else:
			root.set_meta("condition", condition)
		if bool(entry.get("is_permanent", false)):
			root.set_meta("is_permanent", true)

	main._structures.ensure_landmarks()

	# The trees and the corn where they stood (what was cleared stays cleared); saves
	# from before they were kept grow a new wood.
	var nature_any = grid_data.get("nature", null)
	if nature_any is Array and main.world_generator.has_method("restore_nature"):
		main.world_generator.restore_nature(nature_any as Array)
	elif main.world_generator.has_method("populate_trees"):
		main.world_generator.populate_trees()
	main._sandbox = str(snapshot.get("mode", "")) == "sandbox"
	var rules_any = snapshot.get("rules", {})
	main._camp_rules = main.CAMP_RULES.merged(rules_any if rules_any is Dictionary and main._sandbox else {}, true)

	main._structures.rebuild_cells()
	var crt_any = snapshot.get("crt_desktop", {})
	var loaded_crt_state: Dictionary = {}
	if crt_any is Dictionary:
		loaded_crt_state = (crt_any as Dictionary).duplicate(true)
	if not loaded_crt_state.is_empty():
		main._last_known_crt_desktop_state = loaded_crt_state.duplicate(true)

	if preview_only:
		main._pending_loaded_player_state.clear()
		main._pending_loaded_crt_state.clear()
	else:
		var player_any = snapshot.get("player", {})
		if player_any is Dictionary:
			main._pending_loaded_player_state = (player_any as Dictionary).duplicate(true)
		else:
			main._pending_loaded_player_state.clear()
		if not loaded_crt_state.is_empty():
			main._pending_loaded_crt_state = loaded_crt_state.duplicate(true)
		elif not main._last_known_crt_desktop_state.is_empty():
			main._pending_loaded_crt_state = main._last_known_crt_desktop_state.duplicate(true)
		else:
			main._pending_loaded_crt_state.clear()

	var state_data_any = snapshot.get("state", {})
	if state_data_any is Dictionary:
		var state_data := state_data_any as Dictionary
		INSTANCE.core(main).apply_changes({
			"money": int(state_data.get("money", INSTANCE.core(main).get_money())),
			"day": max(1, int(state_data.get("day", INSTANCE.core(main).get_day()))),
			"is_night": bool(state_data.get("is_night", INSTANCE.core(main).is_night())),
			"karma": float(state_data.get("karma", state.karma)),
			"satisfaction": float(state_data.get("satisfaction", state.satisfaction)),
			"hrotfaktor": float(state_data.get("hrotfaktor", state.hrotfaktor)),
			"energy_load": float(state_data.get("energy_load", state.energy_load)),
			"infra_load": float(state_data.get("infra_load", state.infra_load)),
			"guests": main.SAVE_CODEC.deserialize_guests(state_data.get("guests", [])),
			"accommodation_states": main.SAVE_CODEC.deserialize_accommodation_states(state_data.get("accommodation_states", {})),
			"failures": main.SAVE_CODEC.deserialize_failures(state_data.get("failures", {})),
			"guest_reviews": main.SAVE_CODEC.duplicate_dict_array(state_data.get("guest_reviews", [])),
			"guest_transactions": main.SAVE_CODEC.duplicate_dict_array(state_data.get("guest_transactions", [])),
			"lost_guests": main.SAVE_CODEC.duplicate_dict_array(state_data.get("lost_guests", [])),
			"next_guest_id": max(1, int(state_data.get("next_guest_id", 1))),
			"biz": (state_data.get("biz", {}) as Dictionary).duplicate(true) if state_data.get("biz", {}) is Dictionary else {},
			"sites": (state_data.get("sites", {}) as Dictionary).duplicate(true) if state_data.get("sites", {}) is Dictionary else {}
		})
		# (A camp saved before there was a swell: what the ledger says has come so far.)
		var ledger_any = snapshot.get("week_ledger", {})
		var nights_any = (ledger_any as Dictionary).get("nights", {}) if ledger_any is Dictionary else {}
		var visited_old: int = (nights_any as Dictionary).size() if nights_any is Dictionary else 0
		INSTANCE.core(main).actions.set_night_swell(float(state_data.get("night_swell", main.NIGHT_SWELL.from_nights_visited(visited_old))))
		var kinds_any = state_data.get("last_night_kinds", [])
		main._night_roll.last_night_kinds = (kinds_any as Array).duplicate() if kinds_any is Array else []
		main._night_roll.night_lost = int(state_data.get("night_lost", 0))
		main._night_roll.swell_moved = int(state_data.get("night_swell_moved", -1))
		var electricity_any = state_data.get("electricity", {})
		main._billing.import_state(electricity_any if electricity_any is Dictionary else {}, main._day_index, preview_only)
		main._refresh_electricity_power_cut_state(true)
	else:
		main._billing.reset(main._day_index)
		main._refresh_electricity_power_cut_state(true)

	var runtime_any = snapshot.get("runtime", {})
	if runtime_any is Dictionary:
		var runtime := runtime_any as Dictionary
		if main.time_system != null and main.time_system.has_method("set_time_hours"):
			main.time_system.set_time_hours(float(runtime.get("time_of_day_hours", 9.0)))
		if main.weather_system != null and main.weather_system.has_method("set_weather"):
			main.weather_system.set_weather(int(runtime.get("weather_state", main.WEATHER_CLEAR)))

	if main.weather_system != null and main.weather_system.has_method("set_auto_cycle_enabled"):
		main.weather_system.set_auto_cycle_enabled(true)
	if not preview_only:
		var jobs_any = snapshot.get("night_jobs", {})
		main._pending_night_jobs = (jobs_any as Dictionary).duplicate(true) if jobs_any is Dictionary else {}
		if main._night_jobs != null and main._gameplay_started:
			main._night_jobs.import_state(main._pending_night_jobs)
			main._pending_night_jobs.clear()
		var trip_any = snapshot.get("town_trip", {})
		main._loaded_away = trip_any is Dictionary and bool((trip_any as Dictionary).get("in_town", false))
		if trip_any is Dictionary and main._interior_manager != null and main._interior_manager.has_method("town_trip") and main._interior_manager.town_trip() != null:
			main._interior_manager.town_trip().import_state(trip_any)
		elif trip_any is Dictionary:
			main._pending_town_trip = (trip_any as Dictionary).duplicate(true)
		var office_any = snapshot.get("camp_office", {})
		main._pending_camp_office = (office_any as Dictionary).duplicate(true) if office_any is Dictionary else {}
		if main.camp_office != null and main._gameplay_started:
			main.camp_office.import_state(main._pending_camp_office)
			main._pending_camp_office.clear()
		var day_any = snapshot.get("day_events", {})
		main._pending_day_events = (day_any as Dictionary).duplicate(true) if day_any is Dictionary else {}
		if main._day_events != null and main._gameplay_started:
			main._day_events.import_state(main._pending_day_events)
			main._pending_day_events.clear()
		var week_any = snapshot.get("week_ledger", {})
		main._pending_week_ledger = (week_any as Dictionary).duplicate(true) if week_any is Dictionary else {}
		if main._pending_week_ledger.is_empty():
			# Saves from before the ledger: the week is counted from the load on.
			main._pending_week_ledger = {"start_money": int(INSTANCE.core(main).get_state().money) if INSTANCE.core(main).get_state() != null else 0}
		if main._week_ledger != null and main._gameplay_started:
			main._week_ledger.import_state(main._pending_week_ledger)
			main._pending_week_ledger.clear()
		var dir_any = snapshot.get("director", {})
		main._pending_director = (dir_any as Dictionary).duplicate(true) if dir_any is Dictionary else {}
		if main._director != null and main._gameplay_started:
			main._director.import_state(main._pending_director)
			main._pending_director.clear()
		main._ruin.key = str(snapshot.get("ruined_cabin", ""))
		main._ruin.call_deferred("dress")
		var gog_any = snapshot.get("goggle", {})
		main._pending_goggle = (gog_any as Dictionary).duplicate(true) if gog_any is Dictionary else {}
		var graph_any = snapshot.get("graph", {})
		main._pending_graph = (graph_any as Dictionary).duplicate(true) if graph_any is Dictionary else {}
		main._goggle_fresh = true
		if main._gameplay_started:
			main._online.setup_goggle()
		var baz_any = snapshot.get("bazaar", {})
		main._bazaar.reset()
		main._pending_bazaar = (baz_any as Dictionary).duplicate(true) if baz_any is Dictionary else {}
		if main._gameplay_started:
			main._bazaar.import_state(main._pending_bazaar)
			main._pending_bazaar.clear()
		var omens_any = snapshot.get("omens", {})
		main._pending_omens = (omens_any as Dictionary).duplicate(true) if omens_any is Dictionary else {}
		if main._omens != null and main._gameplay_started:
			main._omens.import_state(main._pending_omens)
			main._pending_omens.clear()
		var quests_any = snapshot.get("quests", {})
		main._pending_quest_state = (quests_any as Dictionary).duplicate(true) if quests_any is Dictionary else {}
		main._pending_quest_state_loaded = true
		if main._quest_manager != null and main._gameplay_started:
			main._import_quests(main._pending_quest_state)
			main._pending_quest_state_loaded = false
	var email_runtime_any = snapshot.get("email_runtime", {})
	if email_runtime_any is Dictionary and EmailManager != null and INSTANCE.mail(main).has_method("import_runtime_state"):
		INSTANCE.mail(main).import_runtime_state((email_runtime_any as Dictionary).duplicate(true))
	elif EmailManager != null and INSTANCE.mail(main).has_method("reset_runtime"):
		INSTANCE.mail(main).reset_runtime(not preview_only)
	var guest_runtime_any = snapshot.get("guest_runtime", {})
	if guest_runtime_any is Dictionary and GuestManager != null and INSTANCE.guests(main).has_method("import_runtime_state"):
		INSTANCE.guests(main).import_runtime_state((guest_runtime_any as Dictionary).duplicate(true))
	elif GuestManager != null:
		if INSTANCE.guests(main).has_method("reset_runtime_state"):
			INSTANCE.guests(main).reset_runtime_state()
		elif INSTANCE.guests(main).has_method("import_runtime_state"):
			INSTANCE.guests(main).import_runtime_state({})
	main._structures.sync_guest_counts()
	main._sync_runtime_state_from_systems(true)
	if not preview_only:
		main._refresh_camp_sign()
	return true


func reset_for_new_game() -> void:
	main._sandbox = false
	main._camp_rules = main.CAMP_RULES.duplicate()
	main._pending_loaded_player_state.clear()
	main._pending_night_jobs.clear()
	if main._night_jobs != null:
		main._night_jobs.reset()
	main._pending_camp_office.clear()
	main._pending_town_trip.clear()
	if main.camp_office != null:
		main.camp_office.reset()
	main._pending_day_events.clear()
	if main._day_events != null:
		main._day_events.reset()
	# The bag: the torch again, nothing on the ground (scripts/ui/inventory.gd).
	var trip = main._interior_manager.town_trip() if main._interior_manager != null and main._interior_manager.has_method("town_trip") else null
	if trip != null and trip.get("inventory") != null:
		trip.inventory.new_camp()
	main._pending_loaded_crt_state.clear()
	main._last_known_crt_desktop_state.clear()
	main._billing.reset(1)
	main._lamp_grid_power_available = true
	main._active_save_path = ""
	main._clear_blood_fx()
	var state = INSTANCE.core(main).get_state()
	if state == null:
		return
	main._pending_week_ledger.clear()
	if main._week_ledger != null:
		main._week_ledger.reset(main.BALANCE_CONFIG.STARTING_MONEY)
	main._pending_omens.clear()
	if main._omens != null:
		main._omens.reset()
	if main._director != null:
		main._director.begin_night(-1)
		main._director.ever.clear()
		# Not the last game's night on CampStat's NIGHT page.
		main._director.last_log.clear()
	main._pending_bazaar.clear()
	main._bazaar.reset()
	main._pending_goggle.clear()
	main._pending_graph.clear()
	main._goggle_fresh = true
	if main._director_fx != null:
		main._director_fx.clear()
	INSTANCE.core(main).apply_changes({
		"money": main.BALANCE_CONFIG.STARTING_MONEY,
		"day": 1,
		"is_night": false,
		"karma": 0.0,
		"satisfaction": 50.0,
		"hrotfaktor": 0.0,
		"night_swell": 0.0,
		"energy_load": 0.0,
		"infra_load": 0.0
	})
	main._night_roll.last_night_kinds = []
	main._night_roll.night_lost = 0
	main._night_roll.swell_moved = -1
	if state.grid != null:
		state.grid.cells.clear()
		state.grid.tile_types.clear()
		state.grid.occupants.clear()
	state.failures.clear()
	state.guests.clear()
	state.accommodation_states.clear()
	state.guest_reviews.clear()
	state.guest_transactions.clear()
	state.next_guest_id = 1
	# The businesses' books too (the menu's preview of the last save left them in: its
	# places, stock, orders and licences); actions._biz starts them anew with a new stamp.
	state.biz = {}
	state.sites = {}
	if EmailManager != null and INSTANCE.mail(main).has_method("reset_runtime"):
		INSTANCE.mail(main).reset_runtime(true)
	if GuestManager != null and INSTANCE.guests(main).has_method("reset_runtime_state"):
		INSTANCE.guests(main).reset_runtime_state()
	if main._guest_agents != null:
		main._guest_agents.clear_agents()
	if main.time_system != null and main.time_system.has_method("set_time_hours"):
		main.time_system.set_time_hours(9.0)
	if main.weather_system != null and main.weather_system.has_method("set_weather"):
		main.weather_system.set_weather(main.WEATHER_CLEAR)
	main._day_index = 1
	main._time_of_day_hours = 9.0
	main._time_state = main.TIME_DAY
	main._weather_state = main.WEATHER_CLEAR
